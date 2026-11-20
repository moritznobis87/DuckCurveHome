import Charts
import DuckCurveKit
import SwiftUI

/// Heizkreise: die Räume über einen Tag, als Zeitreihe.
///
/// Die Liste zum Stellen steht im Bereich Haus; hier geht es um den Verlauf. Das ist die Frage,
/// die eine Liste nicht beantwortet: ob ein Raum die Nacht hält, oder ob er morgens von unten
/// anfängt.
struct HeizkreiseSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Die Istwerte neben dem Tagesverlauf.
    ///
    /// **Zwei Abfragen auf einer Seite, und `Berichtsseite` kennt nur eine.** Der Tagesverlauf
    /// kommt aus `/rooms/history`, die heutigen Zahlen der Tabelle aus `/rooms`; die Vorlage
    /// holt letztere am laufenden Tag alle dreissig Sekunden nach (`RoomsReport.tsx:38`).
    /// Darum steht dieser Zustand neben dem Gerüst und nicht darin.
    @State private var live: RoomsLiveOut?
    @State private var fehlerLive: ApiFehler?

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        Berichtsseite { z, api in
            try await api.raeumeTag(z.anker, schrittMin: 15)
        } inhalt: { verlauf in
            if let f = fehlerLive {
                Stoerung(fehler: f) { Task { await holeLive(heute: z.anker == haus.heute) } }
            }
            // **Räume ohne Namen** (`RoomsReport.tsx:431-436`): die Brücke schickt die
            // Namensliste als eigene Meldung; bis dahin stehen die Kennungen da, und das
            // gehört dazugesagt.
            if live?.named == false, !verlauf.rooms.isEmpty {
                Text(
                    "Die Räume heißen hier nach ihrer Kennung in der Heizungsregelung. Die "
                        + "Namensliste kommt als eigene Meldung der Brücke und steht nach ihrem "
                        + "nächsten Start zur Verfügung."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            }
            if verlauf.rooms.isEmpty {
                Karte {
                    Leer(
                        satz: "Keine Räume",
                        dazu: "Es liegen keine Werte der Einzelraumregelung vor. Die Brücke "
                            + "liest sie, sobald in ihrer Konfiguration die Adresse des "
                            + "Controme-Servers eingetragen ist.")
                }
            } else {
                // **Die Hauptkarte, und zwar zuerst.** Nicht die Temperaturen, sondern die
                // Abweichung vom Ziel: zehn Raeume zwischen 18 und 21 Grad sind als Kurven
                // ein flaches Band. So macht es das Dashboard (`rooms/RoomsReport.tsx`), und
                // es beantwortet die Frage, die diese Seite stellt - welcher Raum bestimmt
                // die Vorlauftemperatur.
                Karte(
                    kicker: "Abweichung im Tagesverlauf",
                    beiwerk: AnyView(
                        Text(
                            "Je Raum und Viertelstunde die Abweichung vom Zielwert. Der Raum, "
                                + "der zuerst abfällt, bestimmt die nötige Vorlauftemperatur "
                                + "für alle."
                        )
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                    )
                ) {
                    Abweichungsmatrix(
                        verlauf: verlauf,
                        bisStelle: Raumabweichung.gewesen(tag: z.anker, jetzt: haus.jetzt)
                    )
                }
                Karte(kicker: "Die Räume als Tabelle") {
                    raumtabelle(verlauf, heute: z.anker == haus.heute)
                }
                // **Offen, nicht zugeklappt** (`RoomsReport.tsx:549-557`). Wer nicht weiß,
                // dass auf Sollwert plus Versatz geregelt wird, liest die Spalte „Ziel" als
                // das, was er eingestellt hat - und das ist sie nicht.
                Text(
                    "Geregelt wird auf Sollwert plus Versatz – Controme rechnet das in seiner "
                        + "eigenen Oberfläche vor und zeigt das Ergebnis als Zieltemperatur. "
                        + "Der Versatz ist dabei die Summe mehrerer benannter Anpassungen, "
                        + "nicht nur der Witterung. Die Antriebe am Verteiler sind auf oder zu "
                        + "– ein Zwischenwert im Streifen heißt „ein Teil der Kreise“ oder "
                        + "„einen Teil des Fensters“, nicht „halb offen“. Ein Tippen auf "
                        + "eine Kachel im Bereich Haus stellt den Sollwert dieses Raums, "
                        + "dauerhaft und in halben Grad; die Ventile bleiben Sache des Reglers."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: z.anker) { await holeLive(heute: z.anker == haus.heute) }
    }

    /// Die Tabelle der Vorlage: Raum, Etage, Ist, Ziel, Abweichung, Ventil am Tag, Kreise.
    ///
    /// **Ist und Ziel sind der letzte Messwert, kein Tagesmittel.** Hier stand „Im Tagesmittel"
    /// mit vier anderen Spalten; ein Mittel über einen Tag sagt aber nichts darüber, welcher
    /// Raum gerade abfällt - und genau das ist die Frage dieser Seite.
    private func raumtabelle(_ verlauf: RoomHistoryOut, heute: Bool) -> some View {
        let zeilen = Raumabweichung.tabellenzeilen(live: live, tag: verlauf, istHeute: heute)
        return Tabelle(
            zeilennamen: zeilen.map(\.name),
            spalten: [
                .init(name: "Ist", zellen: zeilen.map { Formate.celsius($0.ist, stellen: 1) }),
                .init(name: "Ziel", zellen: zeilen.map { Formate.celsius($0.ziel, stellen: 1) }),
                .init(
                    name: "Abweichung",
                    zellen: zeilen.map { $0.abweichung.map(Raumabweichung.kelvin) ?? Formate.leer },
                    farben: zeilen.map {
                        $0.abweichung.map { Color(Marken.abweichungsfarbe(kelvin: $0)) }
                    }),
                .init(name: "Etage", zellen: zeilen.map(\.etage)),
                .init(
                    name: "Ventil am Tag",
                    zellen: zeilen.map { Raumabweichung.anteilText($0.tagesventil) }),
                .init(
                    name: "Kreise",
                    zellen: zeilen.map { $0.kreise > 0 ? String($0.kreise) : Formate.leer }),
            ],
            // Ist, Ziel und Abweichung gehören am Telefon nebeneinander: die dritte Zahl ist
            // die Differenz der beiden anderen (`handy.css:377-379`).
            immerSichtbar: 3
        )
    }

    /// Die Istwerte holen und, solange der laufende Tag gezeigt wird, alle dreissig Sekunden
    /// nachziehen.
    private func holeLive(heute: Bool) async {
        while !Task.isCancelled {
            do {
                live = try await haus.api.raeume()
                fehlerLive = nil
            } catch {
                // Nur die Istwerte scheitern hier; der Tagesverlauf hat sein eigenes Gerüst.
                fehlerLive = error as? ApiFehler ?? .netz(error.localizedDescription)
            }
            guard heute else { return }
            try? await Task.sleep(for: Raumabweichung.liveTakt)
        }
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
                    w.hinweiseDe + [
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
                        wert: Formate.celsius(a.speicher.tempsC.first ?? nil, stellen: 1)
                    )
                    Zeile(wort: "offene Kreise", wert: "\(a.heizkreis.roomsOpen) von \(a.heizkreis.roomsTotal)")
                    if Int(stelle) < w.preisCtKwh.count,
                       let p = w.preisCtKwh[Int(stelle)]
                    {
                        Zeile(wort: "Strompreis", wert: Formate.zahl(p, stellen: 1), einheit: "ct/kWh")
                    }
                    if Int(stelle) < w.geplantWp.count,
                       let g = w.geplantWp[Int(stelle)]
                    {
                        Zeile(wort: "w.geplantWp", wert: g ? "freigegeben" : "nicht freigegeben")
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
                        // **Eine Reihe von Saetzen, nicht ein Satz.** Hier stand
                        // `Text(b.nextChangesDe)`. Das Dashboard nummeriert sie
                        // (`forecast/ForecastPage.tsx`), und die Nummer traegt eine Auskunft:
                        // die Reihenfolge ist die, in der es wirkt.
                        if !b.nextChangesDe.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(b.nextChangesDe.enumerated()), id: \.offset) {
                                    i, satz in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(String(format: "%02d", i + 1))
                                            .font(Schrift.zahlKlein)
                                            .foregroundStyle(Farbe.text3)
                                        Text(satz)
                                            .font(Schrift.klein)
                                            .foregroundStyle(Farbe.text1)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
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

/// Daten prüfen: wie lückenlos die Messwerte sind, was der Bestand wiegt, und die Tagesdiagnose.
///
/// **Die wichtigste Seite für das Vertrauen in alle anderen.** Jede Zahl dieser App steht auf
/// Minutenwerten; wo die fehlen, rechnet der Dienst mit weniger, als er zu haben scheint. Die
/// längste Lücke je Reihe sagt, wie schlimm es war.
struct DatenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// „gesehen / erwartet" als ein Feld.
    ///
    /// **Als Ausdruck in der Tabelle gab der Compiler auf** („unable to type-check this
    /// expression in reasonable time"). Zeichenkettenverkettung mit Interpolation und zwei
    /// Umwandlungen darin oeffnet ihm zu viele Moeglichkeiten; als Funktion mit angeschriebenen
    /// Typen ist es eindeutig - und lesbarer.
    private func minutenpaar(_ s: CoverageSeriesOut) -> String {
        let gesehen = Formate.zahl(Double(s.minutesSeen), stellen: 0)
        let erwartet = Formate.zahl(Double(s.minutesExpected), stellen: 0)
        return "\(gesehen) / \(erwartet)"
    }

    @State private var abdeckung: CoverageOut?
    @State private var bestand: StorageReportOut?
    @State private var diagnose: String?
    @State private var fehler: ApiFehler?
    /// Die Minutenwerte des Tages - die Reihen, um die es auf dieser Seite geht.
    @State private var kurve = Pruefkurve()
    @State private var hatMinuten = false

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        // **Keine Spannenwahl** (`DataCheck.tsx:59-68`, `showPeriods={false}`): diese Seite
        // kennt nur Tage. Minutenwerte über eine Woche ergäben ein Bild, in dem man nichts
        // erkennt - und genau zum Erkennen ist sie da.
        Seite(zeitraum: Zeitraumleiste(spannen: [.tag])) {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade(z) } }
            }
            Karte(kicker: "Leistungen über den Tag") {
                if hatMinuten {
                    Pruefkurvenbild(kurve: kurve)
                } else {
                    Leer(satz: Pruefkurve.leersatz)
                }
            }
            Karte(
                kicker: "Quellen",
                beiwerk: AnyView(
                    Text("liefert gerade, was liefern soll?")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3))
            ) {
                Quellenkarte(zeilen: Quellenstand.zeilen(aus: haus.zustand?.system))
            }
            if let a = abdeckung {
                Karte(kicker: "Abdeckung") {
                    if a.series.isEmpty {
                        Leer(satz: "Keine Reihen gemeldet.")
                    } else {
                        Tabelle(
                            zeilennamen: a.series.map(\.labelDe),
                            spalten: [
                                .init(
                                    name: "vollständig",
                                    zellen: a.series.map { Formate.prozent($0.coverage) }
                                ),
                                .init(
                                    name: "Minuten",
                                    zellen: a.series.map(minutenpaar)
                                ),
                                .init(
                                    name: "lückige Stunden",
                                    zellen: a.series.map { String($0.incompleteHours) }
                                ),
                                .init(
                                    name: "längste Lücke",
                                    zellen: a.series.map {
                                        Formate.zahl(Double($0.longestOutageH), stellen: 1) + " h"
                                    }
                                ),
                                .init(
                                    name: "zuletzt",
                                    zellen: a.series.map {
                                        $0.lastAt.map { Formate.hhmm(iso: $0) } ?? Formate.leer
                                    }
                                ),
                            ]
                        )
                    }
                }
            }
            if let b = bestand {
                datenbestand(b)
            }
            if let d = diagnose, !d.isEmpty {
                // **Reiner Text, und das soll er bleiben.** Die Tagesdiagnose ist eine Tabelle
                // zum Lesen, keine Datenstruktur - der Dienst schickt sie darum ohne
                // JSON-Umschlag. Sie in Zeilen zu zerlegen und neu zu setzen hiesse, sie zu
                // interpretieren.
                Karte(kicker: "Tagesdiagnose") {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(d)
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                            .textSelection(.enabled)
                    }
                }
            }
            Methode([
                abdeckung?.noteDe,
                bestand?.noteDe,
                "Eine Reihe mit 100 Prozent hat in jeder Minute des Zeitraums einen Wert. "
                    + "Alles darunter heißt: die Berichte rechnen mit weniger.",
            ])
        }
        .task(id: z) { await lade(z) }
    }

    /// Was der Bestand wiegt - und wie lange Rohwerte bleiben.
    ///
    /// Die Aufbewahrungsfrist steht dabei, weil sie die Antwort auf die Frage ist, die sich an
    /// eine Lücke von vor drei Wochen anschliesst: nachsehen kann man dort nicht mehr.
    private func datenbestand(_ b: StorageReportOut) -> some View {
        Karte(kicker: "Datenbestand", titel: megabyte(b.totalBytes)) {
            VStack(alignment: .leading, spacing: 10) {
                Zeile(
                    wort: "Rohwerte bleiben", wert: "\(b.rawRetentionDays)", einheit: "Tage",
                    dazu: "danach nur noch Minutenmittel"
                )
                if !b.tables.isEmpty {
                    Tabelle(
                        zeilennamen: b.tables.map(\.name),
                        spalten: [
                            .init(name: "gesamt", zellen: b.tables.map { megabyte($0.totalBytes) }),
                            .init(name: "Daten", zellen: b.tables.map { megabyte($0.tableBytes) }),
                            .init(name: "Index", zellen: b.tables.map { megabyte($0.indexBytes) }),
                            .init(
                                name: "Zeilen",
                                zellen: b.tables.map { Formate.zahl(Double($0.rowsEstimate), stellen: 0) }
                            ),
                        ]
                    )
                }
            }
        }
    }

    private func megabyte(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 {
            return Formate.zahl(mb / 1024, stellen: 2) + Formate.schmalesLeerzeichen + "GB"
        }
        return Formate.zahl(mb, stellen: 1) + Formate.schmalesLeerzeichen + "MB"
    }

    private func lade(_ z: Zeitraum) async {
        async let minuten = try? haus.api.verlaufTag(z.anker)
        let historie = await minuten
        kurve = Pruefkurve.baue(tag: z.anker, historie: historie)
        hatMinuten = !kurve.leer

        let tage: Int =
            switch z.spanne {
            case .tag: 1
            case .woche: 7
            case .monat: 31
            case .jahr: 365
            }
        async let a = try? haus.api.abdeckung(anker: z.anker, tage: tage)
        async let b = try? haus.api.datenbestand()
        // Die Tagesdiagnose gibt es nur für einen Tag - für eine Woche wäre sie sieben Tabellen.
        async let d = z.spanne == .tag ? try? haus.api.diagnose(tag: z.anker) : nil
        abdeckung = await a
        bestand = await b
        diagnose = await d
        fehler = abdeckung == nil ? .netz("Die Abdeckung ist nicht erreichbar.") : nil
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
    /// Was in den Feldern steht, als Text - nicht als Zahl.
    ///
    /// **Warum Text und nicht `Double?`.** Wer „0," getippt hat, ist mitten im Tippen; eine
    /// Zahl daraus zu machen hiesse, die Null zu uebernehmen und den Rest zu verwerfen. Der
    /// Entwurf bleibt roh, bis er abgegeben wird (`Annahmenfelder.abgabe`).
    @State private var entwuerfe: [String: String] = [:]
    @State private var kennlinie = ""
    @State private var schickt = false
    @State private var uebernommen = false
    @State private var ansicht = "formular"

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let c = einstellungen {
                if ansicht == "formular" {
                    formular(c)
                } else {
                    werteliste(c)
                }
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task { await lade() }
    }

    // MARK: - Das Formular

    /// **Die Seite stellt, sie zeigt nicht nur.** Hier stand eine Leseliste roher Schlüssel
    /// („hw auto off block s 1200"), und darunter der Satz, geändert werde das im Dashboard.
    /// Die Vorlage (`settings/HeatSettings.tsx`) ist ein Formular: zwölf beschriftete Felder
    /// mit ihren Einheiten und Erklärsätzen, die Kennlinie als Zeile, ein Knopf. Jede Änderung
    /// wirkt sofort und rückwirkend - das steht als Satz darüber, nicht im Kleingedruckten.
    @ViewBuilder private func formular(_ c: HemsConfig) -> some View {
        Karte(kicker: Annahmenfelder.kicker, beiwerk: AnyView(umschalter)) {
            VStack(alignment: .leading, spacing: 18) {
                Text(Annahmenfelder.einleitung)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                spalten(c)
                kennlinienzeile(c)
                abgabezeile
            }
        }
        Methode(Annahmenfelder.methodensaetze.map(Optional.init))
    }

    /// Zwei Spalten an der Wand, eine am Telefon - wie die Vorlage.
    @ViewBuilder private func spalten(_ c: HemsConfig) -> some View {
        let gruppen = Annahmenfelder.spalten()
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                ForEach(Array(gruppen.enumerated()), id: \.offset) { _, felder in
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(felder) { feld in
                            feldzeile(feld, c)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 640)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(gruppen.flatMap { $0 }) { feld in
                    feldzeile(feld, c)
                }
            }
        }
    }

    private func feldzeile(_ feld: Annahmenfeld, _ c: HemsConfig) -> some View {
        let gebunden = Binding(
            get: { entwuerfe[feld.schluessel] ?? "" },
            set: { entwuerfe[feld.schluessel] = $0 }
        )
        let geaendert = Annahmenfelder.abweichend(
            feld, entwurf: gebunden.wrappedValue, gegen: c)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(feld.wort)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                TextField("", text: gebunden)
                    .font(Schrift.zahl)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(feld.darfNegativ ? .numbersAndPunctuation : .decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 92)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Farbe.flaeche2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                            .strokeBorder(
                                geaendert ? Farbe.amber : Farbe.linie2, lineWidth: 1)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                    .disabled(!haus.darfSchalten)
                Text(feld.einheit)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .frame(width: 42, alignment: .leading)
            }
            if let hinweis = feld.hinweis {
                Text(hinweis)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func kennlinienzeile(_ c: HemsConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: Annahmenfelder.kennlinienTitel)
            Text(Annahmenfelder.kennlinienErklaerung)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: $kennlinie)
                .font(Schrift.zahl)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Farbe.flaeche2)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(
                            kennlinie != Annahmenfelder.kurveZuText(c.heatDemand?.copCurve ?? [])
                                ? Farbe.amber : Farbe.linie2,
                            lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                .disabled(!haus.darfSchalten)
        }
    }

    @ViewBuilder private var abgabezeile: some View {
        HStack(spacing: 12) {
            Button {
                Task { await uebernimm() }
            } label: {
                Text(schickt ? Annahmenfelder.knopfLaeuft : Annahmenfelder.knopf)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.petrol)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Farbe.amber)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(schickt || !haus.darfSchalten)
            .opacity(haus.darfSchalten ? 1 : 0.4)
            if uebernommen {
                Text(Annahmenfelder.uebernommenSatz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Die rohen Werte bleiben erreichbar - sie sind mehr als die zwölf Annahmen, und wer eine
    /// Kennung sucht, findet sie nur dort.
    private var umschalter: some View {
        Ansichtswahl(
            ansichten: [
                Ansicht(weg: "formular", name: "Annahmen"),
                Ansicht(weg: "werte", name: "Alle Werte"),
            ],
            aktiv: Ansicht(weg: ansicht, name: "")
        ) { a in ansicht = a.weg }
    }

    @ViewBuilder private func werteliste(_ c: HemsConfig) -> some View {
        Karte(kicker: "Alle Werte", beiwerk: AnyView(umschalter)) {
            VStack(alignment: .leading, spacing: 14) {
                if let wp = c.heatPump {
                    abschnitt("Wärmepumpe", wp.alsZeilen)
                }
                if let puffer = c.buffer {
                    abschnitt("Pufferspeicher", puffer.alsZeilen)
                }
                if let waerme = c.heatDemand {
                    abschnitt("Wärmebedarf", waerme.alsZeilen)
                }
                if let tarif = c.tariff {
                    abschnitt("Tarif", tarif.alsZeilen)
                }
                if let ofen = c.stove {
                    abschnitt("Pelletofen", ofen.alsZeilen)
                }
                if let regelung = c.control {
                    abschnitt("Regelung", regelung.alsZeilen)
                }
            }
        }
    }

    private func abschnitt(_ wort: String, _ zeilen: [(wort: String, wert: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: wort)
            Werteliste(werte: zeilen)
        }
    }

    // MARK: - Laden und Abgeben

    private func lade() async {
        do {
            let c = try await haus.api.einstellungen()
            uebernimmAntwort(c)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(Annahmenfelder.ladefehler)
        }
    }

    private func uebernimm() async {
        guard !schickt else { return }
        schickt = true
        uebernommen = false
        defer { schickt = false }
        switch Annahmenfelder.abgabe(entwuerfe: entwuerfe, kennlinie: kennlinie) {
        case .kennlinieUnlesbar:
            fehler = ApiFehler(code: "kennlinie", meldung: Annahmenfelder.kennlinienFehler, status: 0)
        case .bereit(let patch):
            do {
                let c = try await haus.api.stelleWaerme(patch)
                uebernimmAntwort(c)
                fehler = nil
                uebernommen = true
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(Annahmenfelder.aenderungAbgelehnt)
            }
        }
    }

    /// Nach jedem Laden und nach jedem Übernehmen stehen die Felder auf dem, was der Dienst
    /// wirklich hat - nicht auf dem, was jemand getippt hatte.
    private func uebernimmAntwort(_ c: HemsConfig) {
        einstellungen = c
        entwuerfe = Annahmenfelder.entwuerfe(c)
        kennlinie = Annahmenfelder.kurveZuText(c.heatDemand?.copCurve ?? [])
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


/// Die Automatik für die thermische Masse.
///
/// **Was sie tut.** Sie hebt die Sollwerte der Räume vor einem Preistief an und senkt sie danach:
/// das Haus wird zum Speicher, und die Wärme, die abends gebraucht wird, ist mittags für
/// weniger Geld hineingegangen. Der Versatz ist klein - ein halbes Grad reicht, weil ein Haus
/// viel Masse hat.
///
/// **Sie ist aus, bis jemand sie einschaltet.** Das ist Absicht: eine Automatik, die ohne
/// Zutun an den Sollwerten der Wohnräume dreht, ist etwas, das man ausdrücklich gewollt haben
/// muss.
struct Automatikkarte: View {
    @Environment(Hauszustand.self) private var haus
    let automatik: RoomShiftOut
    let geaendert: (RoomShiftOut) -> Void

    @State private var laeuft = false

    var body: some View {
        Karte(kicker: "Automatik für die thermische Masse", titel: titel) {
            VStack(alignment: .leading, spacing: 10) {
                Text(automatik.reasonDe)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    Zeile(
                        wort: "Anhebung", wert: Formate.zahl(automatik.deltaK, stellen: 1),
                        einheit: "K", dazu: "vor dem Preistief"
                    )
                    Zeile(
                        wort: "Absenkung", wert: Formate.zahl(automatik.drawK, stellen: 1),
                        einheit: "K", dazu: "danach, zum Entladen"
                    )
                    Zeile(
                        wort: "Vorlauf", wert: Formate.zahl(automatik.leadH, stellen: 1),
                        einheit: "h", dazu: "so früh fängt sie an"
                    )
                    Zeile(
                        wort: "lohnt ab", wert: Formate.zahl(automatik.minSpreadCt, stellen: 1),
                        einheit: "ct", dazu: "Preisunterschied im Tag"
                    )
                    if let spanne = automatik.spreadCt {
                        Zeile(
                            wort: "heute", wert: Formate.zahl(spanne, stellen: 1), einheit: "ct",
                            farbe: spanne >= automatik.minSpreadCt ? Farbe.mist : Farbe.text3
                        )
                    }
                    if let von = automatik.windowStart, let bis = automatik.windowEnd {
                        Zeile(
                            wort: "Fenster",
                            wert: "\(Formate.hhmm(iso: von)) – \(Formate.hhmm(iso: bis))"
                        )
                    }
                    Zeile(
                        wort: "Versatz jetzt", wert: Formate.zahl(automatik.offsetK, stellen: 1),
                        einheit: "K",
                        farbe: abs(automatik.offsetK) > 0.05 ? Farbe.amber : Farbe.text1
                    )
                }
                // **`rooms` sind die Raumnummern, `active` sind die Raeume.** Hier stand
                // `rooms` - eine Reihe von `Int`. Die Liste zeigt Namen und geschriebene
                // Werte, also das, was die Automatik wirklich gestellt hat: `active`.
                if !automatik.active.isEmpty {
                    raumliste(automatik.active)
                }
                if !automatik.log.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zuletzt").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        ForEach(Array(automatik.log.prefix(5).enumerated()), id: \.offset) { _, e in
                            Text("\(Formate.hhmm(iso: e.at)) · \(e.textDe)")
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if haus.darfSchalten {
                    Button {
                        schalte(!automatik.enabled)
                    } label: {
                        Text(automatik.enabled ? "Automatik ausschalten" : "Automatik einschalten")
                            .font(Schrift.klein)
                            .foregroundStyle(automatik.enabled ? Farbe.text2 : Farbe.deep)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(automatik.enabled ? Farbe.flaeche3 : Farbe.amberWeich)
                            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(laeuft)
                    .opacity(laeuft ? 0.6 : 1)
                }
                if let hinweis = automatik.noteDe, !hinweis.isEmpty {
                    Text(hinweis)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var titel: String {
        if !automatik.enabled { return "aus" }
        // `active` ist keine Ja/Nein-Angabe, sondern die Reihe der Raeume, an denen gerade
        // geschrieben ist. „Greift gerade" heisst: diese Reihe ist nicht leer.
        if !automatik.active.isEmpty { return "greift gerade · \(automatik.phase.wort)" }
        return "an · \(automatik.phase.wort)"
    }

    /// Welche Räume mitmachen - und was die Automatik an ihnen wirklich geschrieben hat.
    ///
    /// Der geschriebene Sollwert steht neben dem Grundwert, weil sie auseinanderlaufen können:
    /// wer von Hand stellt, während die Automatik läuft, verschiebt den Grundwert, und der
    /// geschriebene folgt erst beim nächsten Schritt.
    private func raumliste(_ raeume: [RoomShiftRoomOut]) -> some View {
        Tabelle(
            zeilennamen: raeume.map(\.name),
            spalten: [
                .init(
                    name: "Grundwert",
                    zellen: raeume.map { Formate.celsius($0.baseSetpointC, stellen: 1) }
                ),
                .init(
                    name: "Versatz",
                    zellen: raeume.map { Formate.zahl($0.offsetK, stellen: 1) + " K" }
                ),
                .init(
                    name: "geschrieben",
                    zellen: raeume.map { Formate.celsius($0.writtenSetpointC, stellen: 1) }
                ),
                .init(
                    name: "wann",
                    zellen: raeume.map { Formate.hhmm(iso: $0.writtenAt) }
                ),
            ]
        )
    }

    private func schalte(_ an: Bool) {
        laeuft = true
        Task {
            if let neu = try? await haus.api.stelleRaumAutomatik(RoomShiftIn(enabled: an)) {
                geaendert(neu)
            }
            laeuft = false
        }
    }
}
