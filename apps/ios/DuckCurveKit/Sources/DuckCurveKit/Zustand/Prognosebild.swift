import Foundation

/// Die Prognosebewertung als Bild: eine Tageskurve, fünf Zahlen, drei Säulenbilder.
///
/// **Was die App bisher zeigte.** Vier Textkarten und keine einzige Zeichnung. Die Antwort auf
/// `GET /forecast/evaluation` trägt rund 96 Punkte je Tag (`today.points`, `yesterday.points`),
/// fünf Sonnenhöhenklassen mit ihren Korrekturfaktoren (`corrector.bins`) und die Gewichte der
/// Quellen (`sources`) - nichts davon kam auf den Schirm. Die Vorlage
/// (`apps/web/src/components/forecast/ForecastPage.tsx`) zeigt aus denselben Daten sieben
/// Diagramme. Das war kein Diagrammfehler, sondern eine andere Auskunft.
///
/// **Warum das Rechnen hier steht und nicht in der Zeichnung.** Vier Größen dieser Seite sind
/// stille Fehlerquellen: die Leistungsgrenze der Hochachse (die Achse hat nur drei Marken, eine
/// zu kleine Grenze schneidet die Spitze ab), die Abweichung eines Korrekturfaktors von 1,00 in
/// Prozentpunkten, die symmetrische Spanne der Faktorachse über **drei** Reihen statt nur über
/// die Säulen, und der Umschlag der Abweichungskachel bei 15 %. Jede davon sieht auch falsch
/// gerechnet aus wie ein Diagramm. Hier sind sie prüfbar.
///
/// **Was es nicht ist.** Keine Zeichnung, keine Farbe, keine Höhe in Punkten und keine Legende.
/// Die Ansicht entscheidet, ob eine Reihe gestrichelt ist und wie hoch das Bild wird; sie
/// entscheidet nicht, welcher Wert in ihr steht. Und es ist **nicht** die Wärmelastprognose:
/// ``Tageskurve`` rechnet mit `HeatForecastPoint` und meint die Heizlast, hier geht es um die
/// PV-Prognose gegen das gemessene Ist.
///
/// **„Jetzt" ist `generatedAt` der Antwort, nicht die Uhr des Geräts.** Die Vorlage setzt
/// `nowMs` auf `generated_at` (`ForecastPage.tsx:217`), und das ist der Grund, warum die
/// Jetzt-Linie und der letzte Ist-Punkt zusammenfallen. Mit der Geräteuhr stünde sie bis zu
/// fünf Minuten daneben - an der Wand sichtbar, im Test nicht. Darum nimmt
/// ``tageskurve(_:heute:gerechnetAm:)`` den Zeitpunkt als Argument und greift nie selbst zur Uhr.
public enum Prognosebild {

    // MARK: - Die Konstanten der Vorlage

    /// Jenseits dieser Abweichung in Prozent gilt ein Tag als „zu weit daneben".
    ///
    /// Dieselbe Zahl zählt die Treffer der fünften Kachel und färbt die dritte
    /// (`ForecastPage.tsx:241` und `:262`). Eine Zahl, zwei Stellen - also eine Konstante.
    public static let abweichungsgrenze: Double = 15

    /// Wie viele Tage „7 Tage" sind: die Fenster von Treffern und Bias (`ForecastPage.tsx:238-240`).
    public static let kurzesFenster = 7

    /// Wie viele Tagespaare die Säulenkarte zeigt (`ForecastPage.tsx:91`).
    public static let tagesenergieTage = 14

    /// Die Luft über der höchsten Leistung, bevor auf gerade Kilowatt aufgerundet wird
    /// (`ForecastPage.tsx:49`).
    public static let leistungsluft = 1.1

    /// Die Luft über der größten Abweichung der Faktorachse (`ForecastPage.tsx:146`).
    public static let faktorluft = 1.15

    /// Die Faktorachse ist mindestens so weit - sonst macht ein ruhiger Tag aus einem halben
    /// Prozentpunkt ein Ereignis (`ForecastPage.tsx:146`).
    public static let faktorspanneMindestens: Double = 10

    // MARK: - 1. Die Tageskurve

    /// Ein Tag im Hauptdiagramm: Ist, Day-ahead, der jüngste korrigierte Lauf.
    ///
    /// **Drei Reihen, eine Achse.** Alle drei sind Leistungen in kW am selben Tag, also teilen
    /// sie die Hochachse - und darum rechnet ``leistungsgrenze`` über alle drei und nicht über
    /// das Ist allein. Die Achse hat nur drei Marken (0 / Mitte / oben); eine zu kleine Grenze
    /// schneidet die Mittagsspitze ab, und abgeschnitten sieht eine Spitze aus wie ein Plateau.
    ///
    /// **Was es nicht ist.** Keine Zeitreihe: die Querachse zählt Stunden seit Mitternacht des
    /// gezeigten Tages, damit „gestern" und „heute" aufeinander zu liegen kommen. Das ist
    /// `dayBounds` + `hx` der Vorlage (`ForecastPage.tsx:43-44`) und derselbe Griff wie in
    /// ``Kurvenpunkt``.
    public struct Prognosetag: Sendable, Hashable {
        /// Das gemessene Ist, 15-min-Mittel.
        public var ist: [Kurvenpunkt]
        /// Der Lauf von 06:00, der den Tag angekündigt hat.
        public var dayAhead: [Kurvenpunkt]
        /// Der jüngste Lauf mit angewandter Korrektur - nur am laufenden Tag.
        public var korrigiert: [Kurvenpunkt]
        /// Wo die Jetzt-Linie steht, in Stunden seit Mitternacht. `nil` bei „gestern".
        public var jetztStunde: Double?
        /// Die obere Grenze der Hochachse: gerade, mit 10 % Luft, mindestens 2 kW.
        public var leistungsgrenze: Double
        /// Keine einzige Reihe hat einen Punkt - dann gehört ein Satz hin und kein leeres Gitter.
        public var leer: Bool

        public init(
            ist: [Kurvenpunkt] = [], dayAhead: [Kurvenpunkt] = [],
            korrigiert: [Kurvenpunkt] = [], jetztStunde: Double? = nil,
            leistungsgrenze: Double = 2, leer: Bool = true
        ) {
            self.ist = ist
            self.dayAhead = dayAhead
            self.korrigiert = korrigiert
            self.jetztStunde = jetztStunde
            self.leistungsgrenze = leistungsgrenze
            self.leer = leer
        }
    }

    /// Ein Tag der Antwort als Kurvenbild.
    ///
    /// `heute` entscheidet über zwei Dinge, die es nur am laufenden Tag gibt: den jüngsten
    /// korrigierten Lauf (`ForecastPage.tsx:47`) und die Jetzt-Linie. `gerechnetAm` ist
    /// `generatedAt` der Antwort - nicht `Date()`, nicht `haus.jetzt`.
    ///
    /// **Eine fehlende Messung ist eine Lücke und keine Null.** Ein Punkt ohne `actualKw` fällt
    /// aus der Ist-Reihe heraus; eine Null hieße „die Anlage stand", und nachts um drei stimmt
    /// das zufällig, mittags um zwölf wäre es eine Behauptung.
    public static func tageskurve(_ tag: ForecastDayOut, heute: Bool, gerechnetAm: Date?)
        -> Prognosetag
    {
        guard let anfang = Tag.zeitraum(tag.day)?.von else { return Prognosetag() }

        func stunde(_ iso: String) -> Double? {
            guard let t = Zeit.ausIso(iso) else { return nil }
            return t.timeIntervalSince(anfang) / 3600
        }
        func reihe(_ greife: (ForecastPointOut) -> Double?) -> [Kurvenpunkt] {
            tag.points.compactMap { p in
                guard let wert = greife(p), wert.isFinite, let h = stunde(p.ts) else { return nil }
                return Kurvenpunkt(stunde: h, wert: wert)
            }
        }

        var b = Prognosetag()
        b.ist = reihe { $0.actualKw }
        b.dayAhead = reihe { $0.dayAheadKw }
        b.korrigiert = heute ? reihe { $0.correctedKw } : []
        b.leer = b.ist.isEmpty && b.dayAhead.isEmpty && b.korrigiert.isEmpty
        b.leistungsgrenze = leistungsgrenze(
            (b.ist + b.dayAhead + b.korrigiert).map(\.wert))

        if heute, let jetzt = gerechnetAm {
            let h = jetzt.timeIntervalSince(anfang) / 3600
            // Eine Jetzt-Linie außerhalb des gezeigten Tages ist keine Jetzt-Linie, sondern ein
            // Strich am Rand des Gitters. Dann lieber keine.
            b.jetztStunde = (0...24).contains(h) ? h : nil
        }
        return b
    }

    /// Die obere Grenze der Leistungsachse: gerade, mit 10 % Luft, mindestens 2 kW.
    ///
    /// `ceil(max * 1,1 / 2) * 2` aus `ForecastPage.tsx:49`. Gerade, weil die Achse genau drei
    /// Marken trägt (0, Mitte, oben) und eine ungerade Grenze dort eine Mitte mit Komma ergäbe.
    public static func leistungsgrenze(_ werte: [Double]) -> Double {
        let gross = werte.filter { $0.isFinite }.max() ?? 0
        return (max(1, gross) * leistungsluft / 2).rounded(.up) * 2
    }

    // MARK: - 2. Die fünf Kacheln

    /// Die fünf Zahlen über dem Hauptdiagramm, in der Reihenfolge der Vorlage.
    ///
    /// **Es ist die einzige Stelle, an der die Seite sagt, ob heute gut lief.** `today.score`
    /// wurde von der App gar nicht gelesen. Zwei der fünf Zahlen standen bisher nirgends im
    /// Kern: das MAE der ersten Quelle über sieben Tage und die Zahl der Tage innerhalb
    /// ±15 % (`ForecastPage.tsx:238-241`).
    ///
    /// **Fehlt ein Wert, steht ein Strich.** Keine Null: eine Null wäre eine Messung.
    public static func kacheln(_ b: ForecastEvaluationOut) -> [Kennzahl] {
        let heute = b.today.score
        let letzte = Array(b.daily.suffix(kurzesFenster))
        let treffer = letzte.filter { tag in
            guard let p = tag.energyErrorPct, p.isFinite else { return false }
            return abs(p) <= abweichungsgrenze
        }.count
        let daneben = (heute?.energyErrorPct).map { abs($0) > abweichungsgrenze } ?? false

        return [
            Kennzahl(
                wort: "Heute · Ist bis jetzt",
                wert: Formate.zahl(heute?.energyActualKwh, stellen: 1),
                einheit: "kWh", ton: .sonne),
            Kennzahl(
                wort: "Heute · Day-ahead bis jetzt",
                wert: Formate.zahl(heute?.energyForecastKwh, stellen: 1),
                einheit: "kWh", ton: .normal),
            Kennzahl(
                wort: "Heute · Abweichung",
                wert: Formate.prozentpunkte(heute?.energyErrorPct),
                // Der Ton der Vorlage ist `ember` (`Farbe.alarm`). Den gibt es in
                // ``Kennzahl/Ton`` noch nicht; `.glut` ist der wärmste vorhandene und damit
                // die nächstbeste Warnung. Siehe die Notiz am Ende dieser Datei.
                ton: daneben ? .glut : .normal),
            Kennzahl(
                wort: "MAE · 7 Tage",
                wert: Formate.zahl(b.sources.first?.mae7dKw, stellen: 2),
                einheit: "kW", ton: .normal),
            Kennzahl(
                wort: "Tage innerhalb ±\(Int(abweichungsgrenze)) %",
                wert: "\(treffer) / \(letzte.count)", ton: .gedaempft),
        ]
    }

    // MARK: - 3. Der Bias der kurzen Woche

    /// Das Mittel von `biasKw` über die letzten sieben Tage - `nil`, wenn es keine gibt.
    ///
    /// **Warum nicht über alle Tage.** Der Satz unter „Quellen und Gewichte" nennt den Bias
    /// neben dem MAE der letzten sieben Tage (`ForecastPage.tsx:240`). Zwei Zahlen über zwei
    /// verschiedene Fenster in einem Satz wären eine Falle für den, der sie vergleicht.
    public static func bias7(_ daily: [DailyScoreOut]) -> Double? {
        let werte = daily.suffix(kurzesFenster).map(\.biasKw).filter { $0.isFinite }
        guard !werte.isEmpty else { return nil }
        return werte.reduce(0, +) / Double(werte.count)
    }

    // MARK: - 4. Die Korrekturfaktoren

    /// Die Korrekturfaktoren nach Sonnenhöhe, als Abweichung von 1,00.
    ///
    /// **Gezeichnet wird nicht der Faktor, sondern seine Abweichung von 1,00 in
    /// Prozentpunkten.** Das ist die Entscheidung, auf der die ganze Karte steht (Kommentar in
    /// `ForecastPage.tsx:143`): Faktoren liegen zwischen 0,9 und 1,1, und auf einer Achse von 0
    /// bis 1,1 ist das ein Strich. Als Abweichung wird die Achse symmetrisch um Null, die
    /// Säulen stehen auf der Nulllinie statt auf dem Achsenboden, und „zu wenig" zeigt nach
    /// unten statt nur ein Stück kürzer zu sein.
    ///
    /// **Was es nicht ist.** Keine Bewertung. Ein Faktor unter 1,00 heißt, dass die Prognose zu
    /// hoch lag - ``Klasse/unterEins`` sagt das und sagt nicht, dass es schlecht ist.
    public struct Faktorbild: Sendable, Hashable {

        /// Eine Sonnenhöhenklasse mit ihren drei Reihen.
        public struct Klasse: Sendable, Hashable, Identifiable {
            /// Die Beschriftung der Querachse: „0-10°" bis „über 45°" (`BIN_LABELS_DE`).
            public let name: String
            /// Der Faktor selbst - für die Auskunft, mit drei Nachkommastellen.
            public let faktor: Double?
            /// Die Abweichung von 1,00 in Prozentpunkten: die Höhe der Säule.
            public let abweichung: Double?
            /// Dasselbe für den Stand von gestern - die Raute.
            public let gestern: Double?
            /// Dasselbe für das letzte gemessene Verhältnis Ist zu Prognose - der Kreis.
            public let letztes: Double?
            public let lerntage: Int?
            /// Der Faktor liegt unter 1,00: die Prognose lag zu hoch. Färbt die Säule.
            public let unterEins: Bool

            public var id: String { name }

            public init(
                name: String, faktor: Double?, abweichung: Double?, gestern: Double?,
                letztes: Double?, lerntage: Int?, unterEins: Bool
            ) {
                self.name = name
                self.faktor = faktor
                self.abweichung = abweichung
                self.gestern = gestern
                self.letztes = letztes
                self.lerntage = lerntage
                self.unterEins = unterEins
            }
        }

        public var klassen: [Klasse]
        /// Die Hochachse, symmetrisch um Null, mit fünf Marken.
        public var spanne: ClosedRange<Double>

        public init(klassen: [Klasse] = [], spanne: ClosedRange<Double> = -10...10) {
            self.klassen = klassen
            self.spanne = spanne
        }
    }

    /// Die Abweichung eines Faktors von 1,00, in Prozentpunkten auf ein Zehntel gerundet.
    ///
    /// `round((x - 1) * 1000) / 10` aus `ForecastPage.tsx:144`. Die Rundung ist nicht Zierde:
    /// 1,0734 ergibt 7,3 und nicht 7,340000000000001, und diese Zahl steht sowohl an der Säule
    /// als auch in der Auskunft.
    public static func abweichung(_ faktor: Double?) -> Double? {
        guard let faktor, faktor.isFinite else { return nil }
        return ((faktor - 1) * 1000).rounded() / 10
    }

    /// Das ganze Faktorbild samt seiner Achse.
    ///
    /// **Die Spanne rechnet über alle drei Reihen, nicht nur über die Säulen.** Die Raute von
    /// „gestern" kann weiter außen liegen als jede Säule; eine Spanne nur über `factor`
    /// schneidet sie ab, und abgeschnitten ist sie nicht da (`ForecastPage.tsx:146`).
    public static func faktorbalken(_ st: CorrectorState) -> Faktorbild {
        let klassen = st.bins.map { b in
            Faktorbild.Klasse(
                name: b.labelDe,
                faktor: b.factor,
                abweichung: abweichung(b.factor),
                gestern: abweichung(b.previous),
                letztes: abweichung(b.lastRatio),
                lerntage: b.days,
                // Ein fehlender Faktor ist nicht „unter eins", sondern nicht da. Gezeichnet
                // wird für ihn ohnehin keine Säule.
                unterEins: b.factor.map { $0 < 1 } ?? false)
        }
        let weit = klassen.flatMap { [$0.abweichung, $0.gestern, $0.letztes] }
            .compactMap { $0 }.map(abs).max() ?? 0
        let spanne = max(faktorspanneMindestens, (weit * faktorluft / 10).rounded(.up) * 10)
        return Faktorbild(klassen: klassen, spanne: (-spanne)...spanne)
    }

    // MARK: - 5. Die Fehlerbalken

    /// Zwei Fehlergrößen über einer Wortachse: Horizonte oder Vorlaufklassen.
    ///
    /// **Ein Balken ohne Paare ist `nil` und nicht null.** Eine Null-Säule sagt „kein Fehler",
    /// und das ist der genaue Gegensatz von „nichts gemessen" (`Rueckblick.tsx:37-38`). Darum
    /// sind ``mae`` und ``zweites`` leer, sobald ``paare`` null ist, und die Ansicht zeichnet
    /// dort nichts.
    ///
    /// **Was es nicht ist.** Kein Typ für eine bestimmte Karte. ``zweites`` ist bei den
    /// Horizonten der Betrag des Bias (`ForecastPage.tsx:137`) und im Rückblick der Rand von
    /// 95 % (`Rueckblick.tsx:38`) - zwei verschiedene Größen in derselben Form, weil die
    /// Zeichnung dieselbe ist. Was dort steht, sagt die Legende der Karte.
    public struct Fehlerbalken: Sendable, Hashable, Identifiable {
        /// Die kurze Beschriftung der Querachse: „0-3h", „12-24h".
        public let name: String
        /// Der ganze Satz für die Auskunft: „nächste 3 Stunden".
        public let langname: String
        public let mae: Double?
        public let zweites: Double?
        public let paare: Int

        public var id: String { name }

        public init(name: String, langname: String, mae: Double?, zweites: Double?, paare: Int) {
            self.name = name
            self.langname = langname
            self.mae = mae
            self.zweites = zweites
            self.paare = paare
        }
    }

    /// Die drei Horizontklassen „0-3h", „3-12h", „12-36h" - `zweites` ist der Betrag des Bias.
    ///
    /// Der Betrag, nicht der Bias: zwei Säulen nebeneinander, von denen die eine nach unten
    /// zeigen kann, teilen keine Achse, die bei null beginnt.
    public static func horizonte(_ b: ForecastEvaluationOut) -> [Fehlerbalken] {
        b.horizons.map { h in
            let leer = h.score.n == 0
            return Fehlerbalken(
                name: h.key, langname: h.labelDe,
                mae: leer ? nil : h.score.maeKw,
                zweites: leer ? nil : abs(h.score.biasKw),
                paare: h.score.n)
        }
    }

    /// Die sechs Vorlaufklassen einer Rückblickreihe - `zweites` ist der Rand von 95 %.
    public static func vorlaufbalken(_ r: ReiheOut) -> [Fehlerbalken] {
        r.jeVorlauf.map { v in
            let leer = v.wertung.n == 0
            return Fehlerbalken(
                name: v.key, langname: v.labelDe,
                mae: leer ? nil : v.wertung.mae,
                zweites: leer ? nil : v.wertung.p95,
                paare: v.wertung.n)
        }
    }

    // MARK: - 6. Die Tagesenergie

    /// Ein Tag als Säulenpaar: was angekündigt war und was gekommen ist.
    ///
    /// **Zwei Formate desselben Datums, und beide fertig aus dem Kern.** An der Querachse steht
    /// „Mo", in der Auskunft „Mo, 17.11." (`ForecastPage.tsx:107` gegen `:103`). Das Datum
    /// zweimal zu formatieren ist die Art Kleinigkeit, die in der Ansicht einmal mit und einmal
    /// ohne Zeitzone des Hauses gerechnet wird - und dann steht an der Achse ein anderer Tag
    /// als in der Auskunft.
    public struct Tagespaar: Sendable, Hashable, Identifiable {
        /// Der Kalendertag, wie der Dienst ihn nennt: „2026-11-17".
        public let tag: String
        /// Die Achsenbeschriftung: „Mo".
        public let kurz: String
        /// Der Kopf der Auskunft: „Mo, 17.11.".
        public let wochentag: String
        public let prognose: Double
        public let ist: Double
        public let fehlerProzent: Double?
        public let mae: Double

        public var id: String { tag }

        public init(
            tag: String, kurz: String, wochentag: String, prognose: Double, ist: Double,
            fehlerProzent: Double?, mae: Double
        ) {
            self.tag = tag
            self.kurz = kurz
            self.wochentag = wochentag
            self.prognose = prognose
            self.ist = ist
            self.fehlerProzent = fehlerProzent
            self.mae = mae
        }
    }

    /// Die letzten `hoechstens` Tage als Säulenpaare, nach Tag aufsteigend.
    ///
    /// **Sortiert, und erst dann geschnitten.** Die Vorlage nimmt `daily.slice(-14)` und
    /// verlässt sich darauf, dass der Dienst sortiert liefert. Hier wird sortiert, denn „die
    /// letzten vierzehn Tage" ist eine Aussage über das Datum und nicht über die Reihenfolge im
    /// JSON; eine vertauschte Reihe fiele an der Achse erst auf, wenn jemand die Wochentage
    /// nachliest.
    public static func tagesenergie(_ daily: [DailyScoreOut], hoechstens: Int = tagesenergieTage)
        -> [Tagespaar]
    {
        guard hoechstens > 0 else { return [] }
        let sortiert = daily.sorted { $0.day < $1.day }
        return sortiert.suffix(hoechstens).map { d in
            Tagespaar(
                tag: d.day,
                kurz: wochentagKurz(d.day),
                wochentag: Tag.kurz(d.day),
                prognose: d.energyForecastKwh,
                ist: d.energyActualKwh,
                fehlerProzent: d.energyErrorPct,
                mae: d.maeKw)
        }
    }

    /// „Mo" aus „2026-11-16" - die zwei Zeichen, die an die Querachse passen.
    ///
    /// Ein unbekannter Tag behält seinen eigenen Text: eine erfundene Beschriftung wäre
    /// schlimmer als eine fremde.
    static func wochentagKurz(_ tag: String) -> String {
        guard let d = Tag.date(tag) else { return tag }
        return Namen.wochentag(Kalender.haus.component(.weekday, from: d), kurz: true)
    }
}

/// Prozent mit Vorzeichen und einer Nachkommastelle - das `pct()` der Vorlage.
///
/// **Warum nicht ``Formate/prozent(_:)``.** Das nimmt einen Anteil von 0 bis 1 und rundet
/// ganzzahlig. Die Prognoseseite hat ihre Prozent schon als Prozent (`energy_error_pct`), und
/// sie braucht das Vorzeichen: „+12,4 %" und „−3,0 %" sind zwei verschiedene Nachrichten, „12 %"
/// ist keine. Die App behalf sich bisher mit `Formate.prozent(pct / 100)` und verlor dabei
/// beides (`PrognoseSeite.swift`).
extension Formate {
    /// Ein Prozentwert, wie er schon ankommt, mit Vorzeichen: „+12,4 %", „−3,0 %", „0,0 %".
    ///
    /// Das Plus steht nur über null, wie `pct()` in `ForecastPage.tsx:30`. Das Minus kommt aus
    /// ``zahl(_:stellen:)`` und ist das echte U+2212.
    public static func prozentpunkte(_ wert: Double?, stellen: Int = 1, vorzeichen: Bool = true)
        -> String
    {
        guard let wert, wert.isFinite else { return leer }
        let plus = (vorzeichen && wert > 0) ? "+" : ""
        return plus + zahl(wert, stellen: stellen) + schmalesLeerzeichen + "%"
    }
}
