import Charts
import DuckCurveKit
import SwiftUI

/// Heizkreise: die Räume über einen Tag, als Zeitreihe.
///
/// Die Liste zum Stellen steht im Bereich Haus; hier geht es um den Verlauf. Das ist die Frage,
/// die eine Liste nicht beantwortet: ob ein Raum die Nacht hält, oder ob er morgens von unten
/// anfängt.
struct HeizkreiseSeite: View {
    var body: some View {
        Berichtsseite(spannen: [.tag]) { z, api in
            try await api.raeumeTag(z.anker, schrittMin: 15)
        } inhalt: { verlauf in
            if verlauf.rooms.isEmpty {
                Karte { Leer(satz: "Für diesen Tag sind keine Raumwerte da.") }
            } else {
                Karte(kicker: "Temperaturen", titel: "\(verlauf.rooms.count) Räume") {
                    Raumverlaufsbild(verlauf: verlauf)
                }
                Karte(kicker: "Ventile") {
                    Ventilband(verlauf: verlauf)
                }
                Karte(kicker: "Im Tagesmittel") {
                    Tabelle(
                        zeilennamen: verlauf.rooms.map(\.name),
                        spalten: [
                            .init(
                                name: "Temperatur",
                                zellen: verlauf.rooms.map {
                                    Formate.celsius(mittel($0.tempC), stellen: 1)
                                }
                            ),
                            .init(
                                name: "Sollwert",
                                zellen: verlauf.rooms.map {
                                    Formate.celsius(mittel($0.setpointC), stellen: 1)
                                }
                            ),
                            .init(
                                name: "Ventil offen",
                                zellen: verlauf.rooms.map { Formate.prozent(mittel($0.valve)) }
                            ),
                            .init(
                                name: "Fenster offen",
                                zellen: verlauf.rooms.map {
                                    Formate.dauer(
                                        minuten: Int(
                                            ($0.window.compactMap { $0 }.filter { $0 > 0.5 }.count)
                                                * verlauf.stepMin
                                        )
                                    )
                                }
                            ),
                        ]
                    )
                }
                Methode([
                    "Aufgelöst in \(verlauf.stepMin) Minuten.",
                    "Ein fehlender Messwert wird nicht überbrückt: eine Lücke in der Kurve ist "
                        + "eine Lücke in den Daten.",
                ])
            }
        }
    }

    private func mittel(_ werte: [Double?]) -> Double? {
        let da = werte.compactMap { $0 }.filter(\.isFinite)
        guard !da.isEmpty else { return nil }
        return da.reduce(0, +) / Double(da.count)
    }
}

/// Die Temperaturen aller Räume über den Tag.
private struct Raumverlaufsbild: View {
    let verlauf: RoomHistoryOut

    var body: some View {
        Chart {
            ForEach(verlauf.rooms, id: \.id) { raum in
                ForEach(Array(punkte(raum).enumerated()), id: \.offset) { _, p in
                    LineMark(
                        x: .value("Stunde", p.stunde),
                        y: .value("°C", p.wert),
                        series: .value("Raum", raum.name)
                    )
                    .foregroundStyle(by: .value("Raum", raum.name))
                    .lineStyle(StrokeStyle(lineWidth: 1.3))
                }
            }
        }
        .chartXScale(domain: 0...24)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0.0, through: 24, by: 4))) { w in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel {
                    if let h = w.as(Double.self) {
                        Text(String(format: "%02d", Int(h)))
                            .font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { w in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel {
                    if let d = w.as(Double.self) {
                        Text(Formate.zahl(d, stellen: 0))
                            .font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 6)
        .frame(height: 240)
    }

    /// Die Zeitstempel kommen als Liste, die Werte je Raum als zweite - beide gleich lang.
    private func punkte(_ raum: RoomSeriesOut) -> [(stunde: Double, wert: Double)] {
        zip(verlauf.ts, raum.tempC).compactMap { roh, wert in
            guard let wert, let t = Zeit.ausIso(roh) else { return nil }
            let teile = Kalender.haus.dateComponents([.hour, .minute], from: t)
            return (Double(teile.hour ?? 0) + Double(teile.minute ?? 0) / 60, wert)
        }
    }
}

/// Die Ventile als Band: eine Zeile je Raum, dunkel wo zu, hell wo offen.
///
/// **Das ist die Darstellung, die eine Kurve nicht ersetzt.** Zehn Ventilkurven übereinander sind
/// ein Knäuel; zehn Bänder sind eine Partitur, und man sieht auf einen Blick, ob die Räume
/// gleichzeitig oder nacheinander ziehen.
private struct Ventilband: View {
    let verlauf: RoomHistoryOut

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(verlauf.rooms, id: \.id) { raum in
                HStack(spacing: 8) {
                    Text(raum.name)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .frame(width: 92, alignment: .leading)
                        .lineLimit(1)
                    GeometryReader { r in
                        HStack(spacing: 0) {
                            ForEach(Array(raum.valve.enumerated()), id: \.offset) { _, v in
                                Rectangle()
                                    .fill(farbe(v))
                                    .frame(width: max(1, r.size.width / CGFloat(max(1, raum.valve.count))))
                            }
                        }
                    }
                    .frame(height: 11)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                }
            }
            HStack(spacing: 8) {
                Spacer().frame(width: 92)
                Text("00").font(Schrift.achse).foregroundStyle(Farbe.text3)
                Spacer()
                Text("12").font(Schrift.achse).foregroundStyle(Farbe.text3)
                Spacer()
                Text("24").font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
        }
    }

    /// Ein fehlender Wert bleibt leer und wird nicht als „zu" gezeichnet - „nicht gemessen" und
    /// „zu" sind zwei verschiedene Auskünfte.
    private func farbe(_ v: Double?) -> Color {
        guard let v else { return Farbe.linie1 }
        if v < 0.02 { return Farbe.flaeche3 }
        return Farbe.ventilOffen.opacity(0.35 + 0.65 * min(1, v))
    }
}

/// Anlage · Ein Tag: die Wiedergabe eines vergangenen Ortstags.
///
/// **Dieselben Bilder, über einen Tag abspielbar.** Der Dienst liefert den Tag als Folge von
/// Augenblicken (`frames`); hier läuft ein Schieber darüber, und die Anlagenwerte folgen ihm.
/// Das ist die Antwort auf „was ist an diesem Tag eigentlich passiert" – eine Frage, die keine
/// Tageskurve beantwortet, weil sie nur Leistungen zeigt und keine Temperaturen.
struct WiedergabeSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tag: String = ""
    @State private var wiedergabe: AnlageReplayOut?
    @State private var stelle: Double = 0
    @State private var laeuftAb = false
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            tagwahl
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let w = wiedergabe, !w.frames.isEmpty {
                Karte(kicker: "Wiedergabe", titel: zeitpunkt(w)) {
                    VStack(alignment: .leading, spacing: 12) {
                        schieber(w)
                        werte(w)
                    }
                }
                Methode(
                    (w.hinweiseDe ?? []) + [
                        "Aufgelöst in \(w.stepMin) Minuten, \(w.frames.count) Augenblicke.",
                    ]
                )
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task(id: tag) { await lade() }
        .task(id: laeuftAb) { await spiele() }
        .onAppear { if tag.isEmpty { tag = Tag.plus(haus.heute, -1) } }
    }

    private var tagwahl: some View {
        HStack(spacing: 8) {
            Button { tag = Tag.plus(tag, -1) } label: {
                Text("‹").font(Schrift.karte).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).foregroundStyle(Farbe.text2)
            Text(Tag.kurz(tag)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1).frame(minWidth: 92)
            Button { tag = Tag.plus(tag, 1) } label: {
                Text("›").font(Schrift.karte).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(tag < haus.heute ? Farbe.text2 : Farbe.text3)
            .disabled(tag >= haus.heute)
            Spacer(minLength: 8)
            Button {
                laeuftAb.toggle()
            } label: {
                Text(laeuftAb ? "Anhalten" : "Abspielen")
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.deep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Farbe.amberWeich)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func schieber(_ w: AnlageReplayOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Slider(value: $stelle, in: 0...Double(max(1, w.frames.count - 1)), step: 1)
                .tint(Farbe.amber)
            HStack {
                Text(Formate.hhmm(iso: w.von)).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                Spacer()
                Text(Formate.hhmm(iso: w.bis)).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func zeitpunkt(_ w: AnlageReplayOut) -> String {
        guard let rahmen = aktueller(w) else { return Tag.lang(w.day) }
        return Formate.hhmm(iso: rahmen.at)
    }

    private func aktueller(_ w: AnlageReplayOut) -> AnlageOut? {
        let i = Int(stelle)
        guard i >= 0, i < w.frames.count else { return w.frames.first }
        return w.frames[i]
    }

    private func werte(_ w: AnlageReplayOut) -> some View {
        Group {
            if let a = aktueller(w) {
                VStack(spacing: 0) {
                    Zeile(wort: "Sonne", wert: Formate.kw(a.strom.pvKw), einheit: "kW", farbe: Farbe.pv)
                    Zeile(wort: "Haus", wert: Formate.kw(a.strom.houseKw), einheit: "kW")
                    Zeile(
                        wort: "Wärmepumpe", wert: Formate.kw(a.strom.heatPumpKw), einheit: "kW",
                        farbe: Farbe.waermepumpe
                    )
                    if let aussen = a.outdoorC {
                        Zeile(wort: "draußen", wert: Formate.celsius(aussen, stellen: 1))
                    }
                    Zeile(wort: "Vorlauf", wert: Formate.celsius(a.waermepumpe.flowC, stellen: 1))
                    Zeile(wort: "Puffer", wert: Formate.prozent(a.speicher.soc))
                    Zeile(
                        wort: "Puffer oben",
                        wert: Formate.celsius(a.speicher.tempsC.first?.belastbar, stellen: 1)
                    )
                    Zeile(wort: "offene Kreise", wert: "\(a.heizkreis.roomsOpen) von \(a.heizkreis.roomsTotal)")
                    if let preise = w.preisCtKwh, Int(stelle) < preise.count,
                       let p = preise[Int(stelle)]
                    {
                        Zeile(wort: "Strompreis", wert: Formate.zahl(p, stellen: 1), einheit: "ct/kWh")
                    }
                    if let geplant = w.geplantWp, Int(stelle) < geplant.count,
                       let g = geplant[Int(stelle)]
                    {
                        Zeile(wort: "geplant", wert: g ? "freigegeben" : "nicht freigegeben")
                    }
                }
            }
        }
    }

    /// Abspielen: ein Augenblick je Viertelsekunde. Schnell genug, dass ein Tag in einer Minute
    /// durchläuft, langsam genug, dass man etwas sieht.
    private func spiele() async {
        guard laeuftAb else { return }
        while laeuftAb, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let w = wiedergabe else { return }
            let letzte = Double(max(1, w.frames.count - 1))
            if stelle >= letzte {
                stelle = 0
            } else {
                stelle += 1
            }
        }
    }

    private func lade() async {
        guard Tag.istTag(tag) else { return }
        do {
            wiedergabe = try await haus.api.anlageWiedergabe(tag: tag)
            stelle = 0
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

/// Prognose: wie gut die Vorhersage war.
struct PrognoseSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var bewertung: ForecastEvaluationOut?
    @State private var verlauf: ForecastHistoryOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let b = bewertung {
                Karte(kicker: "Stand", titel: b.stageDe) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !b.nextChangesDe.isEmpty {
                            Text(b.nextChangesDe)
                                .font(Schrift.klein)
                                .foregroundStyle(Farbe.text1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(spacing: 0) {
                            Zeile(
                                wort: "Korrektur aktiv", wert: b.correctionActive ? "ja" : "nein",
                                dazu: "ob die gelernte Korrektur gerade angewendet wird"
                            )
                            Zeile(wort: "aufbewahrte Läufe", wert: String(b.runsKept))
                            Zeile(wort: "gerechnet", wert: Formate.hhmm(iso: b.generatedAt))
                        }
                    }
                }
                if !b.horizons.isEmpty {
                    Karte(kicker: "Nach Vorlaufzeit", titel: "Je weiter voraus, desto schwerer") {
                        Tabelle(
                            zeilennamen: b.horizons.map(\.labelDe),
                            spalten: [
                                .init(
                                    name: "Güte",
                                    zellen: b.horizons.map { Formate.zahl($0.score.maeKw, stellen: 2) }
                                )
                            ]
                        )
                    }
                }
                if !b.daily.isEmpty {
                    Karte(kicker: "Nach Tagen") {
                        Tabelle(
                            zeilennamen: b.daily.map { Tag.kurz($0.day) },
                            spalten: [
                                .init(
                                    name: "erwartet",
                                    zellen: b.daily.map { Formate.zahl($0.energyForecastKwh, stellen: 1) }
                                ),
                                .init(
                                    name: "wirklich",
                                    zellen: b.daily.map { Formate.zahl($0.energyActualKwh, stellen: 1) }
                                ),
                                .init(
                                    name: "Fehler",
                                    zellen: b.daily.map { Formate.prozent($0.energyErrorPct.map { $0 / 100 }) }
                                ),
                                .init(
                                    name: "Abweichung",
                                    zellen: b.daily.map { Formate.zahl($0.maeKw, stellen: 2) }
                                ),
                            ]
                        )
                    }
                }
                Methode(b.notesDe)
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
            if let v = verlauf, !v.reihen.isEmpty {
                Karte(kicker: "Aus dem Archiv", titel: "\(v.tage) Tage") {
                    Tabelle(
                        zeilennamen: v.reihen.map(\.labelDe),
                        spalten: [
                            .init(
                                name: "gesamt",
                                zellen: v.reihen.map { Formate.zahl($0.gesamt.mae, stellen: 2) }
                            ),
                            .init(name: "Einheit", zellen: v.reihen.map(\.einheit)),
                            .init(name: "Läufe", zellen: v.reihen.map { String($0.laeufe) }),
                        ]
                    )
                }
                Methode(v.hinweiseDe)
            }
        }
        .task { await lade() }
    }

    private func lade() async {
        async let b = try? haus.api.prognoseBewertung()
        async let v = try? haus.api.prognoseVerlauf(tage: 7)
        bewertung = await b
        verlauf = await v
        fehler = bewertung == nil ? .netz("Die Prognosebewertung ist nicht erreichbar.") : nil
    }
}

/// Daten prüfen: wie lückenlos die Messwerte sind.
///
/// **Die wichtigste Seite für das Vertrauen in alle anderen.** Jede Zahl dieser App steht auf
/// Minutenwerten; wo die fehlen, rechnet der Dienst mit weniger, als er zu haben scheint. Die
/// längste Lücke je Reihe sagt, wie schlimm es war.
struct DatenSeite: View {
    var body: some View {
        Berichtsseite(spannen: [.tag, .woche, .monat]) { z, api in
            let tage: Int =
                switch z.spanne {
                case .tag: 1
                case .woche: 7
                case .monat: 31
                case .jahr: 365
                }
            return try await api.abdeckung(anker: z.anker, tage: tage)
        } inhalt: { a in
            Karte(kicker: "Abdeckung") {
                if a.series.isEmpty {
                    Leer(satz: "Keine Reihen gemeldet.")
                } else {
                    Tabelle(
                        zeilennamen: a.series.map(\.labelDe),
                        spalten: [
                            .init(name: "vollständig", zellen: a.series.map { Formate.prozent($0.coverage) }),
                            .init(
                                name: "Minuten",
                                zellen: a.series.map {
                                    "\(Formate.zahl(Double($0.minutesSeen), stellen: 0)) / "
                                        + Formate.zahl(Double($0.minutesExpected), stellen: 0)
                                }
                            ),
                            .init(
                                name: "lückige Stunden",
                                zellen: a.series.map { String($0.incompleteHours) }
                            ),
                            .init(
                                name: "längste Lücke",
                                zellen: a.series.map { Formate.zahl($0.longestOutageH, stellen: 1) + " h" }
                            ),
                            .init(
                                name: "zuletzt",
                                zellen: a.series.map { $0.lastAt.map { Formate.hhmm(iso: $0) } ?? Formate.leer }
                            ),
                        ]
                    )
                }
            }
            Methode([
                a.noteDe,
                "Eine Reihe mit 100 Prozent hat in jeder Minute des Zeitraums einen Wert. "
                    + "Alles darunter heißt: die Berichte rechnen mit weniger.",
            ])
        }
    }
}

/// Haustür: wer wann aufgeschlossen hat.
struct HaustuerSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tage = 7
    @State private var protokoll: DoorLogOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            Tagewahl(tage: $tage, moeglich: [7, 30, 90])
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let p = protokoll {
                Kachelfeld(
                    kacheln: [
                        Kacheldaten("Öffnungen", String(p.entries.filter(\.granted).count)),
                        Kacheldaten(
                            "abgewiesen", String(p.entries.filter { !$0.granted }.count),
                            farbe: p.entries.contains { !$0.granted } ? Farbe.achtung : Farbe.text1
                        ),
                        Kacheldaten("Zeitraum", "\(p.days) Tage"),
                    ],
                    kicker: "Haustür"
                )
                Karte(kicker: "Protokoll") {
                    if p.entries.isEmpty {
                        Leer(satz: "In diesem Zeitraum wurde nicht aufgeschlossen.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(p.entries.enumerated()), id: \.offset) { i, e in
                                if i > 0 { Divider().overlay(Farbe.linie1) }
                                eintrag(e)
                            }
                        }
                    }
                }
                Methode([p.noteDe])
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task(id: tage) { await lade() }
    }

    private func eintrag(_ e: DoorEntryOut) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(e.granted ? Farbe.mist : Farbe.alarm)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.actor).font(Schrift.klein).foregroundStyle(Farbe.text1)
                Text([e.door, e.method, e.reason].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Formate.hhmm(iso: e.at)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                Text(e.outcome).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
        .padding(.vertical, 6)
    }

    private func lade() async {
        do {
            protokoll = try await haus.api.haustuer(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

/// Annahmen: die Einstellungen, mit denen der Fahrplan rechnet.
///
/// **Was hier steht, ist nicht gemessen, sondern gesetzt.** Pufferfassung, Verlust je Kelvin,
/// Pelletpreis, die angenommene COP-Kurve. Jede dieser Zahlen geht in jede Euro-Zahl der App
/// ein, und keine davon kommt aus einer Messung.
struct AnnahmenSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var einstellungen: HemsConfig?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let c = einstellungen {
                if let wp = c.heatPump {
                    Karte(kicker: "Wärmepumpe") {
                        Werteliste(werte: wp.alsZeilen)
                    }
                }
                if let puffer = c.buffer {
                    Karte(kicker: "Pufferspeicher") {
                        Werteliste(werte: puffer.alsZeilen)
                    }
                }
                if let waerme = c.heatDemand {
                    Karte(kicker: "Wärmebedarf") {
                        Werteliste(werte: waerme.alsZeilen)
                    }
                }
                if let tarif = c.tariff {
                    Karte(kicker: "Tarif") {
                        Werteliste(werte: tarif.alsZeilen)
                    }
                }
                if let ofen = c.stove {
                    Karte(kicker: "Pelletofen") {
                        Werteliste(werte: ofen.alsZeilen)
                    }
                }
                if let regelung = c.control {
                    Karte(kicker: "Regelung") {
                        Werteliste(werte: regelung.alsZeilen)
                    }
                }
                Methode([
                    "Diese Werte sind gesetzt, nicht gemessen – und sie gehen in jede Euro-Zahl "
                        + "dieser App ein.",
                    "Geändert werden sie im Dashboard oder über die Konfiguration des Dienstes. "
                        + "Diese Seite zeigt sie, damit man weiß, worauf die Zahlen stehen.",
                ])
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task { await lade() }
    }

    private func lade() async {
        do {
            einstellungen = try await haus.api.einstellungen()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

/// Eine Liste aus Schlüssel und Wert, wie sie aus einer Konfiguration kommt.
struct Werteliste: View {
    let werte: [(wort: String, wert: String)]

    var body: some View {
        if werte.isEmpty {
            Leer(satz: "Nichts gesetzt.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(werte.enumerated()), id: \.offset) { i, w in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    HStack(alignment: .firstTextBaseline) {
                        Text(w.wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                        Spacer(minLength: 8)
                        Text(w.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}

/// Eine Konfiguration als Zeilen.
///
/// **Warum über `Encodable` und nicht Feld für Feld.** Die Konfiguration hat neun Gruppen mit
/// zusammen gut siebzig Feldern, und sie wächst - jedes neue Feld müsste hier nachgetragen
/// werden, und wer es vergisst, merkt nichts. Über die Kodierung kommt alles, was da ist, und
/// zwar unter den Namen des Schemas: `cop_curve` statt `copCurve`. Das ist hier richtig, denn
/// wer diese Seite liest, sucht die Zahl aus `hems.yaml`.
protocol AlsZeilen {}

extension AlsZeilen where Self: Encodable {
    var alsZeilen: [(wort: String, wert: String)] {
        guard let roh = try? JSONEncoder().encode(self),
              let buch = try? JSONSerialization.jsonObject(with: roh) as? [String: Any]
        else { return [] }
        return buch.keys.sorted().compactMap { schluessel in
            guard let wert = buch[schluessel] else { return nil }
            let text = textVon(wert)
            guard !text.isEmpty else { return nil }
            return (wort: schluessel.replacingOccurrences(of: "_", with: " "), wert: text)
        }
    }

    private func textVon(_ wert: Any) -> String {
        switch wert {
        case let d as Double: return Formate.zahl(d, stellen: d == d.rounded() ? 0 : 2)
        case let i as Int: return String(i)
        case let b as Bool: return b ? "ja" : "nein"
        case let s as String: return s
        case let liste as [Any]:
            // Eine Stützpunktliste (die COP-Kurve) wird als Paare geschrieben.
            if let paare = liste as? [[Double]] {
                return paare.map { p in
                    p.count >= 2
                        ? "\(Formate.zahl(p[0], stellen: 0))→\(Formate.zahl(p[1], stellen: 2))"
                        : ""
                }
                .filter { !$0.isEmpty }
                .joined(separator: "  ")
            }
            return liste.map { textVon($0) }.joined(separator: ", ")
        case is NSNull: return ""
        default: return ""
        }
    }
}

extension HeatPumpConfig: AlsZeilen {}
extension BufferConfig: AlsZeilen {}
extension HeatDemandConfig: AlsZeilen {}
extension TariffConfig: AlsZeilen {}
extension StoveConfig: AlsZeilen {}
extension ControlConfig: AlsZeilen {}
extension BatteryConfig: AlsZeilen {}
extension BalanceConfig: AlsZeilen {}
