import DuckCurveKit
import SwiftUI

/// Das Blatt eines Raums: den Sollwert stellen, und sehen, was das kostet.
///
/// **Die Wirkung steht dabei, bevor man stellt.** Der Dienst rechnet auf Anfrage, was ein Grad
/// mehr in diesem Raum an Waerme, Strom und Geld bedeutet (`/rooms/{id}/wirkung`). Ein Sollwert
/// ohne diese Zahl ist ein Schieberegler; mit ihr ist es eine Entscheidung.
struct Raumblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    let raum: RoomLiveOut
    /// Wird gerufen, wenn gestellt wurde - die Liste dahinter soll den neuen Wert zeigen.
    let danach: () async -> Void

    @State private var soll: Double
    @State private var wirkung: RoomEffectOut?
    @State private var laeuft = false
    @State private var rueckmeldung: String?
    @State private var fehler: ApiFehler?
    @State private var protokoll: RoomLogOut?

    init(raum: RoomLiveOut, danach: @escaping () async -> Void) {
        self.raum = raum
        self.danach = danach
        // Der Griff beginnt beim gestellten Sollwert, nicht bei der Temperatur: gestellt wird
        // der Sollwert, und wer ihn verschiebt, verschiebt ihn von dort, wo er steht.
        self._soll = State(initialValue: raum.setpointC ?? raum.targetC ?? 21)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    jetztzustand
                    regler
                    if let w = wirkung {
                        wirkungskarte(w)
                    }
                    if let p = protokoll {
                        protokollkarte(p)
                    }
                    if let r = rueckmeldung {
                        Text(r).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    }
                    if let f = fehler {
                        Stoerung(fehler: f)
                    }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle(raum.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stellen") { stelle() }
                        .disabled(laeuft || !haus.darfSchalten || abs(soll - (raum.setpointC ?? 0)) < 0.05)
                }
            }
        }
        .task(id: soll) { await holeWirkung() }
        .task { protokoll = try? await haus.api.raumProtokoll(raum.id, stunden: 48) }
    }

    private var jetztzustand: some View {
        Karte(kicker: raum.floor) {
            VStack(spacing: 0) {
                Zeile(wort: "jetzt", wert: Formate.celsius(raum.tempC, stellen: 1))
                Zeile(wort: "Sollwert am Regler", wert: Formate.celsius(raum.setpointC, stellen: 1))
                if let z = raum.targetC, let s = raum.setpointC, abs(z - s) >= 0.05 {
                    Zeile(
                        wort: "wirksamer Sollwert", wert: Formate.celsius(z, stellen: 1),
                        dazu: "mit Versatz der Automatik"
                    )
                }
                Zeile(
                    wort: "Abweichung",
                    wert: raum.deviationK.map { Formate.zahl($0, stellen: 1) } ?? Formate.leer,
                    einheit: "K",
                    farbe: Farbe.abweichung(kelvin: raum.deviationK)
                )
                Zeile(wort: "Ventil", wert: Formate.prozent(raum.valve))
                Zeile(wort: "Heizkreise", wert: String(raum.circuits))
                if let f = raum.humidityPct {
                    Zeile(wort: "Luftfeuchte", wert: Formate.prozent(f / 100))
                }
                if let hinweis = raum.hinweisZeile(jetzt: haus.jetzt) {
                    Zeile(wort: "Messwert", wert: hinweis, farbe: Farbe.achtung)
                }
            }
        }
    }

    /// Der Regler: in Schritten von einem halben Grad.
    ///
    /// **Nicht stufenlos.** Ein Fussbodenheizkreis reagiert in Stunden; ein Zehntelgrad ist eine
    /// Genauigkeit, die die Anlage nicht hat, und ein Schieber, der sie anbietet, verspricht zu
    /// viel. Halbe Grade sind die Stufen, die Controme selbst kennt.
    private var regler: some View {
        Karte(kicker: "Sollwert stellen") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Zahl(wert: Formate.celsius(soll, stellen: 1), schrift: Schrift.zahlFuehrend)
                    Spacer(minLength: 8)
                    if abs(soll - (raum.setpointC ?? soll)) >= 0.05 {
                        Text(
                            "\(soll > (raum.setpointC ?? soll) ? "+" : "−")"
                                + Formate.zahl(abs(soll - (raum.setpointC ?? soll)), stellen: 1) + " K"
                        )
                        .font(Schrift.zahlKlein)
                        .foregroundStyle(Farbe.amber)
                    }
                }
                Slider(value: $soll, in: 15...26, step: 0.5)
                    .tint(Farbe.amber)
                    .disabled(!haus.darfSchalten)
                HStack {
                    Text("15 °C").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    Spacer()
                    Text("26 °C").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                if !haus.darfSchalten {
                    Text("Gastzugang: nur Ansicht.")
                        .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private func wirkungskarte(_ w: RoomEffectOut) -> some View {
        Karte(kicker: "Was das bedeutet", titel: "Pro Tag, bei \(Formate.celsius(w.outdoorC)) draußen") {
            VStack(spacing: 0) {
                Zeile(
                    wort: "Wärme", wert: Formate.zahl(w.dailyKwhTh, stellen: 1), einheit: "kWh",
                    farbe: Farbe.waermepumpe
                )
                Zeile(wort: "Strom", wert: Formate.zahl(w.dailyKwhEl, stellen: 1), einheit: "kWh")
                Zeile(
                    wort: "Geld", wert: Formate.euro(w.dailyEur),
                    farbe: w.dailyEur > 0 ? Farbe.achtung : Farbe.mist
                )
                Zeile(
                    wort: "Anteil am Haus", wert: Formate.prozent(w.share),
                    dazu: "dieser Raum an der ganzen Heizlast"
                )
                Zeile(
                    wort: "Halbwertszeit", wert: Formate.zahl(w.halfLifeH, stellen: 1), einheit: "h",
                    dazu: "wie lange der Raum die Änderung hält"
                )
                Zeile(wort: "Arbeitszahl", wert: Formate.zahl(w.cop, stellen: 2))
                if let s = w.shiftSavingEur, abs(s) >= 0.005 {
                    Zeile(
                        wort: "mit Vorheizen", wert: Formate.euro(-s),
                        dazu: "wenn die Wärme in ein Preistief gelegt wird", farbe: Farbe.mist
                    )
                }
            }
            if !w.noteDe.isEmpty {
                Text(w.noteDe)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }

    /// Was in diesem Raum in den letzten 48 Stunden geschah.
    ///
    /// **Wer gestellt hat, steht dabei.** Das ist der Zweck des Protokolls: eine Temperatur, die
    /// nicht stimmt, hat meistens einen Grund, und der ist oft ein Griff von jemandem. Der
    /// Urheber kommt aus denselben Kopfzeilen, die auch diese App mitschickt - und er nennt ein
    /// Gerät, keinen Menschen.
    private func protokollkarte(_ p: RoomLogOut) -> some View {
        Karte(kicker: "Was geschah", titel: "48 Stunden") {
            if p.entries.isEmpty {
                Leer(satz: "In diesen zwei Tagen wurde hier nichts gestellt.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(p.entries.enumerated()), id: \.offset) { i, e in
                        if i > 0 { Divider().overlay(Farbe.linie1) }
                        protokollzeile(e)
                    }
                }
            }
        }
    }

    private func protokollzeile(_ e: RoomLogEntryOut) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(e.text)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    [Formate.hhmm(iso: e.at), e.quelle, e.urheber]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 8)
            if let von = e.fromC, let nach = e.toC {
                Text("\(Formate.celsius(von, stellen: 1)) → \(Formate.celsius(nach, stellen: 1))")
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text2)
            }
        }
        .padding(.vertical, 6)
    }

    private func holeWirkung() async {
        let delta = soll - (raum.setpointC ?? soll)
        guard abs(delta) >= 0.05 else {
            wirkung = nil
            return
        }
        // Kurz warten: beim Ziehen am Regler sonst eine Anfrage je Zwischenschritt.
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        wirkung = try? await haus.api.raumWirkung(raum.id, deltaK: delta)
    }

    private func stelle() {
        laeuft = true
        Task {
            do {
                let a = try await haus.api.stelleRaum(raum.id, sollwertC: soll)
                rueckmeldung = a.messageDe
                fehler = nil
                await danach()
                schliessen()
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
            laeuft = false
        }
    }
}

extension RoomLiveOut {
    /// Der Hinweis zum Messwert dieses Raums - alt, fehlt, widerspruechlich.
    func hinweisZeile(jetzt: Date) -> String? {
        var teile: [String] = []
        if let w = quality.wort { teile.append(w) }
        if !quality.traegt, let roh = observedAt, let z = Zeit.ausIso(roh),
           let alter = Formate.alter(beobachtetAm: z, jetzt: jetzt)
        {
            teile.append(alter)
        }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }
}

/// Das Blatt der Waermepumpe: Auto, An fuer eine Frist, Aus fuer eine Frist.
///
/// **Warum ein Blatt und kein Schalter.** Die Waermepumpe kann mehr als an und aus, und die
/// Fristen sind der Grund: ein „An" ohne Frist an einer Waermepumpe ist eine Entscheidung, die
/// niemand zuruecknimmt, weil sie niemandem auffaellt. Mit Frist faellt sie von selbst zurueck
/// in die Automatik.
struct Waermepumpenblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    /// Die Fristen in Minuten. 30 Minuten ist ein Lauf, zwei Stunden ein Vormittag, sechs
    /// Stunden eine Nacht.
    private static let fristen = [30, 120, 360]

    @State private var laeuft = false
    @State private var rueckmeldung: String?
    @State private var fehler: ApiFehler?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    zustand
                    if haus.darfSchalten {
                        griffe
                    } else {
                        Karte { Leer(satz: "Gastzugang: nur Ansicht.") }
                    }
                    if let d = haus.zustand?.decision {
                        begruendung(d)
                    }
                    if let r = rueckmeldung {
                        Text(r).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    }
                    if let f = fehler { Stoerung(fehler: f) }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Wärmepumpe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }

    private var zustand: some View {
        Karte {
            VStack(spacing: 0) {
                Zeile(
                    wort: "Zustand",
                    wert: (haus.zustand?.heatPump.running ?? false) ? "läuft" : "aus",
                    farbe: (haus.zustand?.heatPump.running ?? false) ? Farbe.waermepumpe : Farbe.text2
                )
                Zeile(
                    wort: "Leistung",
                    wert: Formate.kw(haus.augenblick?.heatPumpPowerKw.belastbar), einheit: "kW"
                )
                if let seit = haus.zustand?.heatPump.runningSince, let d = Zeit.ausIso(seit) {
                    Zeile(wort: "läuft seit", wert: Formate.hhmm(d))
                }
                if let seit = haus.zustand?.heatPump.stoppedSince, let d = Zeit.ausIso(seit) {
                    Zeile(wort: "aus seit", wert: Formate.hhmm(d))
                }
                Zeile(wort: "Starts heute", wert: String(haus.zustand?.heatPump.startsToday ?? 0))
                Zeile(wort: "Freigabekontakt K1", wert: (haus.zustand?.heatPump.releaseContactOn ?? false) ? "zu" : "offen")
                Zeile(wort: "Sperrkontakt K2", wert: (haus.zustand?.heatPump.blockContactOn ?? false) ? "zu" : "offen")
                Zeile(wort: "Betrieb", wert: haus.betriebswort)
                if let hinweis = haus.zustand?.system.hpActuationDe {
                    Zeile(wort: "Schalten", wert: haus.zustand?.system.hpActuation == true ? "freigegeben" : "gesperrt", dazu: hinweis)
                }
            }
        }
    }

    private var griffe: some View {
        Karte(kicker: "Stellen") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    stelle(.auto, frist: 120)
                } label: {
                    griffbeschriftung("Automatik", "Duck Curve entscheidet")
                }
                .buttonStyle(.plain)

                ForEach([("An", "manual"), ("Aus", "off")], id: \.0) { wort, zustand in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                        HStack(spacing: 8) {
                            ForEach(Self.fristen, id: \.self) { minuten in
                                Button {
                                    stelle(zustand == "manual" ? .manuellAn : .manuellAus, frist: minuten)
                                } label: {
                                    Text(Formate.dauer(minuten: minuten))
                                        .font(Schrift.klein)
                                        .foregroundStyle(Farbe.text1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Farbe.flaeche3)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Text("Jeder Griff von Hand fällt nach seiner Frist in die Automatik zurück.")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
            .disabled(laeuft)
            .opacity(laeuft ? 0.6 : 1)
        }
    }

    private func griffbeschriftung(_ wort: String, _ dazu: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(wort).font(Schrift.karte).foregroundStyle(Farbe.text1)
                Text(dazu).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
            Spacer()
        }
        .padding(12)
        .background(Farbe.flaeche3)
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    /// Was der Regler zuletzt entschieden hat, und warum.
    private func begruendung(_ d: Decision) -> some View {
        Karte(kicker: "Die letzte Entscheidung") {
            VStack(alignment: .leading, spacing: 8) {
                Text(d.explanationDe)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                if !d.reasons.isEmpty {
                    gruende("Dafür", d.reasons, Farbe.mist)
                }
                if !d.blockedBy.isEmpty {
                    gruende("Dagegen", d.blockedBy, Farbe.achtung)
                }
                Text("Stand \(Formate.hhmm(iso: d.at)) · gilt bis \(Formate.hhmm(iso: d.validUntil))")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    private func gruende(_ wort: String, _ codes: [ReasonCode], _ farbe: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            ForEach(codes, id: \.self) { c in
                HStack(spacing: 6) {
                    Circle().fill(farbe).frame(width: 4, height: 4)
                    Text(Grundwort.text(c)).font(Schrift.winzig).foregroundStyle(Farbe.text2)
                }
            }
        }
    }

    private func stelle(_ was: Griff, frist: Int) {
        laeuft = true
        Task {
            do {
                let befehl: HeatPumpModeIn =
                    switch was {
                    case .auto:
                        HeatPumpModeIn(systemMode: .auto, durationMin: frist)
                    case .manuellAn:
                        HeatPumpModeIn(systemMode: .manual, manualState: .on, durationMin: frist)
                    case .manuellAus:
                        HeatPumpModeIn(systemMode: .manual, manualState: .off, durationMin: frist)
                    }
                _ = try await haus.api.stelleWaermepumpe(befehl)
                rueckmeldung = "Gestellt. Der nächste Rahmen zeigt es."
                fehler = nil
                await haus.ersteLadung()
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
            laeuft = false
        }
    }

    private enum Griff { case auto, manuellAn, manuellAus }
}

/// Die Reason-Codes des Reglers in Worten.
///
/// Der Dienst schickt Kennungen (`pv_surplus`, `min_runtime_hold`), weil sie stabil sein muessen.
/// Fuer die Anzeige werden daraus Saetze - eine Kennung an der Wand ist keine Begruendung.
/// Unbekannte Kennungen werden gezeigt, wie sie sind: besser eine Kennung als nichts.
enum Grundwort {
    static func text(_ c: ReasonCode) -> String {
        switch c {
        case .pvSurplus: return "Überschuss aus der Sonne"
        case .pvSurplusFading: return "der Überschuss geht zurück"
        case .priceNegative: return "der Strompreis ist negativ"
        case .priceCheapWindow: return "günstiges Preisfenster"
        case .plannedWindow: return "so steht es im Fahrplan"
        case .heatDemandForced: return "die Wärme wird gebraucht"
        case .hpRunningOwnControl: return "die Pumpe läuft nach eigenem Regler"
        case .minRuntimeHold: return "Mindestlaufzeit noch nicht erreicht"
        case .minOfftimePending: return "Mindestpause noch nicht vorbei"
        case .onDelayPending: return "Einschaltverzögerung läuft"
        case .offDelayPending: return "Ausschaltverzögerung läuft"
        case .bufferFull: return "der Puffer ist voll"
        case .bufferNoHeadroom: return "im Puffer ist kein Platz"
        case .maxStartsReached: return "genug Starts für heute"
        default: return c.rawValue.replacingOccurrences(of: "_", with: " ")
        }
    }
}
