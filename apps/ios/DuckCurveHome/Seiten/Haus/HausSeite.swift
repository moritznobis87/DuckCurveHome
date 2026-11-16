import DuckCurveKit
import SwiftUI

/// Das Haus: die Raeume als Liste zum Stellen oder als Glasmodell.
///
/// **Ein Schalter in der Seite, kein Reiter.** `areas.ts` haelt das fest: es sind zwei Ansichten
/// derselben Sache, und die Liste ist die zum Arbeiten. Wer einen Sollwert stellen will, tippt
/// ihn in der Liste; wer wissen will, ob irgendwo ein Fenster offen ist, sieht das Modell an.
///
/// **Der Alarm steht oben und nicht im Modell.** Scharf oder nicht ist eine Auskunft, die man
/// lesen will, ohne das Haus zu drehen.
struct HausSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @State private var ansicht: Ansichtswahlart = .liste
    @State private var raeume: RoomsLiveOut?
    @State private var hausplan: HouseOut?
    @State private var fehler: ApiFehler?

    private enum Ansichtswahlart: String { case liste, modell }

    var body: some View {
        Seite {
            kopf
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let alarm = haus.zustand?.alarm {
                Alarmkarte(alarm: alarm)
            }
            switch ansicht {
            case .liste:
                raumliste
            case .modell:
                modell
            }
        }
        .task { await lade() }
        // Die Raumtemperaturen kommen nicht im Ereignisstrom - sie werden nachgeholt, aber nicht
        // im Sekundentakt: ein Fussbodenheizkreis bewegt sich in Stunden, nicht in Sekunden.
        .task { await haltFrisch() }
        .sheet(item: raumblatt) { id in
            if let r = raeume?.rooms.first(where: { $0.id == id }) {
                Raumblatt(raum: r) { await lade() }
            }
        }
    }

    private var raumblatt: Binding<Int?> {
        Binding(
            get: {
                if case .raum(let id) = wegweiser.blatt { return id }
                return nil
            },
            set: { neu in
                wegweiser.blatt = neu.map { Blatt.raum($0) }
            }
        )
    }

    private var kopf: some View {
        HStack {
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "liste", name: "Liste"),
                    Ansicht(weg: "modell", name: "Modell"),
                ],
                aktiv: Ansicht(weg: ansicht.rawValue, name: "")
            ) { a in
                ansicht = Ansichtswahlart(rawValue: a.weg) ?? .liste
            }
            Spacer(minLength: 8)
            if let r = raeume, let at = Zeit.ausIso(r.at) {
                Text("Stand \(Formate.hhmm(at))")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    // MARK: - Liste

    private var raumliste: some View {
        Group {
            if let r = raeume, !r.rooms.isEmpty {
                ForEach(geschosse(r.rooms), id: \.name) { gruppe in
                    Karte(kicker: gruppe.name) {
                        VStack(spacing: 0) {
                            ForEach(Array(gruppe.raeume.enumerated()), id: \.offset) { i, raum in
                                if i > 0 { Divider().overlay(Farbe.linie1) }
                                Raumzeile(raum: raum) {
                                    wegweiser.blatt = .raum(raum.id)
                                }
                            }
                        }
                    }
                }
            } else if fehler == nil {
                Karte { Leer(satz: "Keine Räume gemeldet.") }
            }
        }
    }

    private struct Geschoss: Identifiable {
        let name: String
        let raeume: [RoomLiveOut]
        var id: String { name }
    }

    /// Nach Geschoss gruppiert, in der Reihenfolge, in der sie im Haus liegen.
    private func geschosse(_ alle: [RoomLiveOut]) -> [Geschoss] {
        var reihenfolge: [String] = []
        var nach: [String: [RoomLiveOut]] = [:]
        for r in alle {
            if nach[r.floor] == nil {
                nach[r.floor] = []
                reihenfolge.append(r.floor)
            }
            nach[r.floor]?.append(r)
        }
        return reihenfolge.map { Geschoss(name: $0, raeume: nach[$0] ?? []) }
    }

    // MARK: - Modell

    private var modell: some View {
        Karte {
            if let plan = hausplan?.plan {
                Glasmodell(
                    plan: plan,
                    raeume: Dictionary(
                        (raeume?.rooms ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }
                    ),
                    kontakte: Dictionary(
                        (hausplan?.contacts ?? []).map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a }
                    ),
                    alarmScharf: haus.zustand?.alarm?.state == "armed_away"
                        || haus.zustand?.alarm?.state == "armed_home"
                )
                .frame(height: 420)
            } else if let fehlertext = hausplan?.errorDe, !fehlertext.isEmpty {
                Leer(satz: "Der Hausplan ist nicht lesbar.", dazu: fehlertext)
            } else if hausplan?.present == false {
                Leer(
                    satz: "Für dieses Haus liegt kein Plan vor.",
                    dazu: "Der Plan kommt von der Brücke (haus.yaml)."
                )
            } else {
                Leer(satz: "Wird geholt …")
            }
        }
    }

    // MARK: - Laden

    private func lade() async {
        async let r = try? haus.api.raeume()
        async let p = try? haus.api.haus()
        raeume = await r
        hausplan = await p
        if raeume == nil, hausplan == nil {
            fehler = .netz("Räume und Hausplan nicht erreichbar.")
        } else {
            fehler = nil
        }
    }

    private func haltFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard !Task.isCancelled else { return }
            if let r = try? await haus.api.raeume() { raeume = r }
            if let p = try? await haus.api.haus() { hausplan = p }
        }
    }
}

/// Eine Zeile der Raumliste: Name, Temperatur, Abweichung, Ventil.
struct Raumzeile: View {
    let raum: RoomLiveOut
    let tippen: () -> Void

    var body: some View {
        Button(action: tippen) {
            HStack(spacing: 12) {
                // Der Punkt in der Farbe der Abweichung: die Spalte, die man von oben nach unten
                // liest, ohne Zahlen zu vergleichen.
                Circle()
                    .fill(Farbe.abweichung(kelvin: raum.deviationK))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(raum.name).font(Schrift.klein).foregroundStyle(Farbe.text1)
                    if let hinweis = unterzeile {
                        Text(hinweis).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Zahl(
                        wert: Formate.celsius(raum.tempC, stellen: 1),
                        schrift: Schrift.zahl,
                        farbe: raum.quality.traegt ? Farbe.text1 : Farbe.text3
                    )
                    if let soll = raum.targetC {
                        Text("Soll \(Formate.celsius(soll, stellen: 1))")
                            .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vorlesen)
        .accessibilityAddTraits(.isButton)
    }

    /// Was unter dem Namen steht: offenes Fenster, offenes Ventil, Versatz.
    private var unterzeile: String? {
        var teile: [String] = []
        if raum.window ?? 0 > 0.5 { teile.append("Fenster offen") }
        if let v = raum.valve, v > 0.02 {
            teile.append(v >= 0.98 ? "Ventil offen" : "Ventil \(Formate.prozent(v))")
        }
        if let o = raum.offsetK, abs(o) >= 0.05 {
            teile.append("Versatz \(Formate.zahl(o, stellen: 1)) K")
        }
        if let f = raum.humidityPct { teile.append("\(Formate.prozent(f / 100)) feucht") }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    private var vorlesen: String {
        var s = "\(raum.name): \(Formate.celsius(raum.tempC, stellen: 1))"
        if let soll = raum.targetC { s += ", Sollwert \(Formate.celsius(soll, stellen: 1))" }
        if let a = raum.deviationK, abs(a) >= 0.1 {
            s += ", \(Formate.zahl(abs(a), stellen: 1)) Kelvin \(a > 0 ? "zu warm" : "zu kalt")"
        }
        if let u = unterzeile { s += ", \(u)" }
        return s + ". Antippen zum Stellen."
    }
}

/// Der Alarm: scharf oder nicht, und ob er scharf gestellt werden kann.
///
/// **Einen Weg zum Entschaerfen gibt es hier nicht, und das ist Absicht.** Wer das Haus
/// entschaerfen will, tut das an der Anlage selbst - eine App, die das kann, ist der Schluessel
/// unter der Fussmatte.
struct Alarmkarte: View {
    @Environment(Hauszustand.self) private var haus
    let alarm: AlarmOut

    @State private var laeuft = false
    @State private var rueckmeldung: String?

    var body: some View {
        Karte(kicker: "Alarm", titel: alarm.stateDe) {
            VStack(alignment: .leading, spacing: 10) {
                if let r = rueckmeldung {
                    Text(r).font(Schrift.winzig).foregroundStyle(Farbe.text2)
                }
                if alarm.canArm, haus.darfSchalten {
                    HStack(spacing: 10) {
                        knopf("Zu Hause scharf", .daheim)
                        knopf("Abwesend scharf", .fort)
                    }
                    Text("Entschärft wird an der Anlage, nicht hier.")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private func knopf(_ wort: String, _ art: Api.AlarmArt) -> some View {
        Button {
            schaerfe(art)
        } label: {
            Text(wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.deep)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Farbe.amberWeich)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(laeuft)
        .opacity(laeuft ? 0.6 : 1)
    }

    private func schaerfe(_ art: Api.AlarmArt) {
        laeuft = true
        Task {
            do {
                let a = try await haus.api.schaerfeAlarm(art)
                rueckmeldung = a.messageDe
            } catch let f as ApiFehler {
                rueckmeldung = f.rat
            } catch {
                rueckmeldung = error.localizedDescription
            }
            laeuft = false
        }
    }
}

extension View {
    /// `sheet(item:)` mit einem `Binding<Int?>` - SwiftUI will dafuer einen `Identifiable`.
    func sheet<Inhalt: View>(
        item: Binding<Int?>, @ViewBuilder inhalt: @escaping (Int) -> Inhalt
    ) -> some View {
        sheet(
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            )
        ) {
            if let wert = item.wrappedValue {
                inhalt(wert)
            }
        }
    }
}
