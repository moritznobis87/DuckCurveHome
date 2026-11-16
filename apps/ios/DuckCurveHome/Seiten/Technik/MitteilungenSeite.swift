import DuckCurveKit
import SwiftUI

/// Mitteilungen: der Morgenbrief und die Warnungen des Wächters.
///
/// **Warum es Mitteilungen überhaupt gibt**, in den Worten von `push.py`: „Der Wächter sieht,
/// wenn eine Quelle schweigt. Das nützt nur jemandem, der gerade auf die Wandanzeige sieht - und
/// genau das tat im Oktober 2026 zwei Tage lang niemand. Eine Mitteilung geht den Weg umgekehrt:
/// Sie sucht sich den Menschen."
///
/// **Hier wird gefragt und nicht beim Start.** Ein Erlaubnisdialog, den niemand einordnen kann,
/// wird abgelehnt - und danach ist die Tür zu, bis jemand in die Systemeinstellungen geht. Auf
/// dieser Seite steht daneben, wofür.
struct MitteilungenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Mitteilungen.self) private var mitteilungen

    @State private var brief: MorgenbriefOut?
    @State private var geraete: PushGeraeteOut?
    @State private var rueckmeldung: String?
    @State private var laeuft = false

    var body: some View {
        Seite {
            erlaubnis
            if let b = brief {
                morgenbrief(b)
            }
            if let g = geraete, !g.devices.isEmpty {
                Karte(kicker: "Angemeldete Geräte", titel: "\(g.devices.count)") {
                    VStack(spacing: 0) {
                        ForEach(Array(g.devices.enumerated()), id: \.offset) { i, d in
                            if i > 0 { Divider().overlay(Farbe.linie1) }
                            geraet(d)
                        }
                    }
                }
            }
            if let r = rueckmeldung {
                Karte { Text(r).font(Schrift.klein).foregroundStyle(Farbe.text1) }
            }
            Methode([
                "Der Dienst verschickt Mitteilungen auf zwei Wegen: als Web Push an das "
                    + "Dashboard im Browser, und als APNs an diese App. Beide Wege bedienen "
                    + "dieselben Mitteilungen.",
                "Für den App-Weg braucht der Dienst einen Signierschlüssel aus einem "
                    + "Apple-Developer-Konto. Ohne ihn kann kein Dienst eine Mitteilung an eine "
                    + "iOS-App schicken – das ist Apples Entwurf. Wie er eingetragen wird, steht "
                    + "in apps/ios/README.md.",
                "Was ohne ihn trotzdem geht: der Morgenbrief steht hier und lässt sich ansehen. "
                    + "Nur der Weg auf den Sperrbildschirm fehlt.",
            ])
        }
        .task { await lade() }
    }

    // MARK: - Erlaubnis

    private var erlaubnis: some View {
        Karte(kicker: "Dieses Gerät", titel: standsatz) {
            VStack(alignment: .leading, spacing: 10) {
                Text(erklaerung)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                switch mitteilungen.stand {
                case .ungefragt:
                    knopf("Mitteilungen erlauben") {
                        Task { await mitteilungen.frage() }
                    }
                case .abgelehnt:
                    Text(
                        "Abgelehnt. Das lässt sich nur in den Systemeinstellungen ändern: "
                            + "Einstellungen › Duck Curve › Mitteilungen."
                    )
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
                case .erlaubt:
                    Text("Erlaubt, aber der Dienst kennt dieses Gerät noch nicht.")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.achtung)
                case .angemeldet:
                    HStack(spacing: 10) {
                        knopf("Probe senden") { probe() }
                        knopf("Abmelden", hell: false) {
                            Task {
                                await mitteilungen.meldeAb()
                                await lade()
                            }
                        }
                    }
                case .fehler(let satz):
                    Text(satz)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.achtung)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var standsatz: String {
        switch mitteilungen.stand {
        case .ungefragt: return "Noch nicht gefragt"
        case .erlaubt: return "Erlaubt"
        case .abgelehnt: return "Abgelehnt"
        case .angemeldet: return "Angemeldet"
        case .fehler: return "Es klemmt"
        }
    }

    private var erklaerung: String {
        switch mitteilungen.stand {
        case .angemeldet:
            return "Dieses Gerät bekommt den Morgenbrief und die Warnungen des Wächters."
        default:
            return
                "Der Wächter sieht, wenn eine Quelle schweigt oder eine Zahl nicht stimmt. Ohne "
                + "Mitteilung merkt das nur, wer gerade auf die Wandanzeige sieht – und im "
                + "Oktober 2026 tat das zwei Tage lang niemand."
        }
    }

    private func knopf(_ wort: String, hell: Bool = true, tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Text(wort)
                .font(Schrift.klein)
                .foregroundStyle(hell ? Farbe.deep : Farbe.text2)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(hell ? Farbe.amberWeich : Farbe.flaeche3)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(laeuft)
        .opacity(laeuft ? 0.6 : 1)
    }

    // MARK: - Morgenbrief

    private func morgenbrief(_ b: MorgenbriefOut) -> some View {
        Karte(
            kicker: "Morgenbrief",
            titel: b.enabled ? "kommt täglich um \(b.uhrzeit)" : "abgeschaltet"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let titel = b.titel, !titel.isEmpty {
                    Text(titel).font(Schrift.karte).foregroundStyle(Farbe.text1)
                }
                if let zeilen = b.zeilen, !zeilen.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(zeilen.enumerated()), id: \.offset) { _, z in
                            Text(z)
                                .font(Schrift.klein)
                                .foregroundStyle(Farbe.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Leer(satz: "Heute stünde nichts darin.")
                }
                if let fuer = b.fuerDe {
                    Text(fuer).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                if let zuletzt = b.zuletztDe {
                    Text(zuletzt).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                if let hinweis = b.hinweisDe, !hinweis.isEmpty {
                    Text(hinweis)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.achtung)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if haus.darfSchalten {
                    HStack(spacing: 10) {
                        knopf(b.enabled ? "Abschalten" : "Einschalten", hell: !b.enabled) {
                            stelleBrief(!b.enabled)
                        }
                        knopf("Jetzt senden", hell: false) { sendeBrief() }
                    }
                }
            }
        }
    }

    private func geraet(_ d: PushGeraetOut) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(d.label).font(Schrift.klein).foregroundStyle(Farbe.text1)
                Text(
                    [
                        d.seit.map { "seit \(Formate.hhmm(iso: $0))" },
                        d.zuletztOk.map { "zuletzt \(Formate.hhmm(iso: $0))" },
                    ]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 8)
            if let fehler = d.fehlversuche, fehler > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(fehler) Fehlversuche")
                        .font(Schrift.winzig).foregroundStyle(Farbe.achtung)
                    if let satz = d.letzterFehlerDe {
                        Text(satz).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Griffe

    private func probe() {
        laeuft = true
        Task {
            if let a = try? await haus.api.mitteilungProbe() {
                rueckmeldung = a.messageDe
            } else {
                rueckmeldung = "Die Probe ist nicht durchgekommen."
            }
            await lade()
            laeuft = false
        }
    }

    private func stelleBrief(_ an: Bool) {
        laeuft = true
        Task {
            brief = try? await haus.api.stelleMorgenbrief(an: an)
            laeuft = false
        }
    }

    private func sendeBrief() {
        laeuft = true
        Task {
            if let a = try? await haus.api.sendeMorgenbrief() {
                rueckmeldung = a.messageDe
            }
            laeuft = false
        }
    }

    private func lade() async {
        async let b = try? haus.api.morgenbrief()
        async let g = try? haus.api.mitteilungGeraete()
        brief = await b
        geraete = await g
        await mitteilungen.pruefeStand()
    }
}

/// Das Blatt des Pelletofens: Auto, An für eine Frist, Aus für eine Frist.
///
/// **Zwei Stunden sind die kleinste sinnvolle Anforderung.** Darunter verbrennt der Ofen mehr
/// Pellets im Zünden und Ausbrennen, als er nutzbar in den Puffer bringt - darum fängt die
/// Fristenreihe bei 120 Minuten an und nicht bei 30 wie bei der Wärmepumpe.
struct Ofenblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    private static let fristen = [120, 240, 480]

    @State private var laeuft = false
    @State private var rueckmeldung: String?
    @State private var fehler: ApiFehler?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let o = haus.zustand?.stove {
                        zustand(o)
                        if haus.darfSchalten, o.controlEnabled == true {
                            griffe
                        } else {
                            Karte {
                                Leer(
                                    satz: haus.darfSchalten
                                        ? "Der Ofen ist nicht zum Führen freigegeben."
                                        : "Gastzugang: nur Ansicht.",
                                    dazu: haus.darfSchalten
                                        ? "Es braucht beide Freigaben: stove.control_enabled und "
                                            + "mcz_allow_control. Siehe docs/OFEN_OPTIMIERUNG.md."
                                        : nil
                                )
                            }
                        }
                    } else {
                        Karte { Leer(satz: "Dieses Haus hat keinen geführten Ofen.") }
                    }
                    if let r = rueckmeldung {
                        Text(r).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    }
                    if let f = fehler { Stoerung(fehler: f) }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Pelletofen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }

    private func zustand(_ o: StoveLiveOut) -> some View {
        Karte {
            VStack(spacing: 0) {
                Zeile(
                    wort: "Zustand", wert: (o.running ?? false) ? "läuft" : "aus",
                    farbe: (o.running ?? false) ? Farbe.ofen : Farbe.text2
                )
                if let m = o.mode {
                    Zeile(wort: "Betriebsart", wert: m.rawValue)
                }
                if let bis = o.endsAt, let d = Zeit.ausIso(bis) {
                    Zeile(wort: "bis", wert: Formate.hhmm(d))
                }
                if let s = o.powerLevel {
                    Zeile(wort: "Stufe", wert: Formate.zahl(s, stellen: 0))
                }
                if let k = o.boilerTempC {
                    Zeile(wort: "Kessel", wert: Formate.celsius(k, stellen: 1))
                }
                if let r = o.fumeTempC {
                    Zeile(wort: "Rauchgas", wert: Formate.celsius(r, stellen: 0))
                }
                if let geplant = o.plannedOn {
                    Zeile(
                        wort: "im Fahrplan", wert: geplant ? "vorgesehen" : "nicht vorgesehen",
                        dazu: o.planUntil.map { "bis \(Formate.hhmm(iso: $0))" }
                    )
                }
                Zeile(
                    wort: "Führung",
                    wert: o.controlEnabled == true ? "freigegeben" : "gesperrt",
                    farbe: o.controlEnabled == true ? Farbe.text1 : Farbe.achtung
                )
            }
        }
    }

    private var griffe: some View {
        Karte(kicker: "Stellen") {
            VStack(alignment: .leading, spacing: 12) {
                Button { stelle(.auto, frist: 240) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Automatik").font(Schrift.karte).foregroundStyle(Farbe.text1)
                            Text("der Fahrplan entscheidet")
                                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Farbe.flaeche3)
                    .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach([("An", StoveModeInModeWahl.on), ("Aus", .off)], id: \.0) { wort, art in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                        HStack(spacing: 8) {
                            ForEach(Self.fristen, id: \.self) { minuten in
                                Button { stelle(art, frist: minuten) } label: {
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
                Text(
                    "Zwei Stunden sind die kleinste sinnvolle Anforderung: darunter verbrennt der "
                        + "Ofen mehr Pellets im Zünden und Ausbrennen, als er nutzbar in den "
                        + "Puffer bringt."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(laeuft)
            .opacity(laeuft ? 0.6 : 1)
        }
    }

    private func stelle(_ art: StoveModeInModeWahl, frist: Int) {
        laeuft = true
        Task {
            do {
                _ = try await haus.api.stelleOfen(StoveModeIn(mode: art, durationMin: frist))
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
}

/// Das Blatt des Speichers: die Betriebsart der Hausbatterie.
struct Batterieblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    @State private var batterie: BatteryLiveOut?
    @State private var laeuft = false
    @State private var rueckmeldung: String?
    @State private var fehler: ApiFehler?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let b = batterie {
                        Karte {
                            VStack(spacing: 0) {
                                Zeile(wort: "Ladestand", wert: Formate.prozent(b.soc.map { $0 > 1 ? $0 / 100 : $0 }))
                                // Die Leistung kommt aus dem Augenblicksbild - diese Antwort
                                // beschreibt die Betriebsart, nicht die Messung.
                                Zeile(
                                    wort: "Leistung",
                                    wert: Formate.kw(haus.augenblick?.batteryPowerKw.belastbar),
                                    einheit: "kW"
                                )
                                Zeile(
                                    wort: "Führung",
                                    wert: b.controlEnabled == true ? "freigegeben" : "gesperrt",
                                    farbe: b.controlEnabled == true ? Farbe.text1 : Farbe.achtung
                                )
                                if let m = b.mode {
                                    Zeile(wort: "Betriebsart", wert: m.rawValue)
                                }
                                if let c = b.command {
                                    Zeile(wort: "Befehl", wert: c.rawValue)
                                }
                                if let bis = b.endsAt, let d = Zeit.ausIso(bis) {
                                    Zeile(wort: "bis", wert: Formate.hhmm(d))
                                }
                                if let r = b.reserveSoc {
                                    Zeile(wort: "Reserve", wert: Formate.prozent(r > 1 ? r / 100 : r))
                                }
                                if let gesendet = b.sentAt, let d = Zeit.ausIso(gesendet) {
                                    Zeile(wort: "gesendet", wert: Formate.hhmm(d))
                                }
                                if let fehler = b.lastError, !fehler.isEmpty {
                                    Zeile(wort: "letzter Fehler", wert: fehler, farbe: Farbe.achtung)
                                }
                            }
                        }
                        if haus.darfSchalten {
                            griffe
                        } else {
                            Karte { Leer(satz: "Gastzugang: nur Ansicht.") }
                        }
                        Methode([b.noteDe])
                    } else {
                        Karte { Leer(satz: "Wird geholt …") }
                    }
                    if let r = rueckmeldung {
                        Text(r).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    }
                    if let f = fehler { Stoerung(fehler: f) }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Speicher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
        .task { batterie = try? await haus.api.batterie() }
    }

    private var griffe: some View {
        Karte(kicker: "Stellen") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(
                    [
                        ("Automatik", BatteryModeInModeWahl.auto, "der Wechselrichter entscheidet"),
                        ("Halten", .hold, "nicht entladen – für ein Preistief später"),
                        ("Aus", .off, "weder laden noch entladen"),
                    ],
                    id: \.0
                ) { wort, art, dazu in
                    Button { stelle(art) } label: {
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
                    .buttonStyle(.plain)
                }
            }
            .disabled(laeuft)
            .opacity(laeuft ? 0.6 : 1)
        }
    }

    private func stelle(_ art: BatteryModeInModeWahl) {
        laeuft = true
        Task {
            do {
                batterie = try await haus.api.stelleBatterie(
                    BatteryModeIn(mode: art, durationMin: 240)
                )
                rueckmeldung = batterie?.noteDe ?? "Gestellt."
                fehler = nil
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
            laeuft = false
        }
    }
}

/// Die Entscheidungen des Reglers, als Liste.
struct Entscheidungsblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if haus.entscheidungen.isEmpty {
                        Karte { Leer(satz: "Seit dem Verbinden hat der Regler nicht entschieden.") }
                    }
                    ForEach(Array(haus.entscheidungen.enumerated()), id: \.offset) { _, d in
                        Karte {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(Formate.hhmm(iso: d.at))
                                        .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                                    Spacer(minLength: 8)
                                    Text(d.k1Release ? "K1 zu" : "K1 offen")
                                        .font(Schrift.winzig)
                                        .foregroundStyle(d.k1Release ? Farbe.waermepumpe : Farbe.text3)
                                }
                                Text(d.explanationDe)
                                    .font(Schrift.klein)
                                    .foregroundStyle(Farbe.text1)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !d.reasons.isEmpty {
                                    Text(d.reasons.map(Grundwort.text).joined(separator: " · "))
                                        .font(Schrift.winzig)
                                        .foregroundStyle(Farbe.mist)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if !d.blockedBy.isEmpty {
                                    Text(d.blockedBy.map(Grundwort.text).joined(separator: " · "))
                                        .font(Schrift.winzig)
                                        .foregroundStyle(Farbe.achtung)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Entscheidungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }
}
