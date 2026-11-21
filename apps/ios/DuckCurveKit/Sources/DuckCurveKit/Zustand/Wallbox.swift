import Foundation

/// Die Wallboxseite: was geladen wurde, woraus es kam und was es gekostet hat.
///
/// **Warum die Seite rechnen muss und nicht nur anzeigen.** Drei der sechs Kopfzahlen der
/// Vorlage stehen in keiner Antwort des Dienstes: der Sonnenanteil des Zeitraums, der im
/// Mittel bezahlte Netzpreis und der effektive Preis je Kilowattstunde
/// (`EvReport.tsx:28-30`). Jede davon hängt an einer Schwelle, unter der ein Strich steht und
/// nicht eine Null – und eine Schwelle, die in einer `View` steht, prüft niemand nach.
///
/// **Die Batterie als Quelle der Ladung fehlte in der App ganz.** `ev_battery_kwh` trägt in
/// der Vorlage eine Diagrammreihe, den Sonnenanteil und einen Kachelhinweis
/// (`EvReport.tsx:16,28,40`); in der App wurde das Feld nirgends gelesen. „aus der Sonne“ plus
/// „aus dem Netz“ ergab deshalb nicht die geladene Menge, und die Differenz stand nirgends.
public enum Wallbox {

    // MARK: - Die sechs Kopfzahlen

    /// Die sechs Kennzahlen der Vorlage, in ihrer Reihenfolge (`EvReport.tsx:38-45`).
    ///
    /// **Die Zahl der Ladevorgänge ist keine Kachel.** Sie stand in der App als eigene und
    /// verdrängte damit „Effektiv je kWh“ – die einzige Zahl, die Bezahltes und Entgangenes
    /// zusammenrechnet. In der Vorlage steht sie dreimal, aber nie als Kachel: als Hinweis
    /// unter „Geladen“, im Kopf der Ladevorgangskarte und als Zeile des Spannenstreifens.
    ///
    /// **„Aus dem Netz“ und „Bezahlt“ tragen den Alarmton** (`EvReport.tsx:41-42`, beide
    /// `tone="ember"`). Sie standen auf ``Kennzahl/Ton/glut``, weil der Kern damals kein
    /// Alarmrot kannte; jetzt gibt es ``Kennzahl/Ton/alarm``, und `glut` war hier nicht nur
    /// ungenau, sondern falsch: `glut` ist die Wärmepumpe, und die Wallboxseite zeigt keine.
    public static func kacheln(_ b: EvReportOut) -> [Kennzahl] {
        let t = b.summary.totals
        return [
            Kennzahl(
                wort: "Geladen", wert: Formate.zahl(t.evKwh, stellen: 1), einheit: "kWh",
                dazu: "\(b.sessions.count) Ladevorgänge", ton: .nebel),
            Kennzahl(
                wort: "Sonnenanteil", wert: Formate.prozent(sonnenanteil(t)),
                dazu: herkunftssatz(t), ton: .bernstein),
            Kennzahl(
                wort: "Aus dem Netz", wert: Formate.zahl(t.evGridKwh, stellen: 1), einheit: "kWh",
                dazu: netzsatz(t), ton: .alarm),
            Kennzahl(
                wort: "Bezahlt", wert: Formate.euro(t.evCostEur),
                dazu: "Netzanteil × Strompreis", ton: .alarm),
            Kennzahl(
                wort: "Entgangene Vergütung", wert: Formate.euro(t.evOpportunityEur),
                dazu: "nicht eingespeister PV-Strom", ton: .gedaempft),
            Kennzahl(
                wort: "Effektiv je kWh",
                wert: effektivCt(t).map { Formate.zahl($0, stellen: 1) } ?? Formate.leer,
                einheit: "ct", dazu: "bezahlt + entgangen", ton: .normal),
        ]
    }

    /// Woraus der Sonnenanteil entstanden ist – Sonne direkt und Speicher getrennt
    /// (`EvReport.tsx:40`).
    ///
    /// Die Aufteilung steht im Hinweis und nicht als zwei weitere Kacheln: sie erklärt eine
    /// Zahl, die darüber steht, und ist selbst keine.
    static func herkunftssatz(_ t: EnergyTotalsOut) -> String {
        let pv = Formate.zahl(t.evPvKwh ?? 0, stellen: 1)
        let batterie = Formate.zahl(t.evBatteryKwh ?? 0, stellen: 1)
        return "PV \(pv) · Batt. \(batterie)\(Formate.schmalesLeerzeichen)kWh"
    }

    /// Was die Netzkilowattstunden im Mittel gekostet haben – oder dass es keine gab.
    ///
    /// **„kein Netzbezug“ ist eine Auskunft, ein Strich wäre keine** (`EvReport.tsx:41`). Ein
    /// Tag, an dem die Wallbox nur aus der Sonne geladen hat, ist der gute Fall und soll als
    /// solcher dastehen.
    static func netzsatz(_ t: EnergyTotalsOut) -> String {
        guard let ct = bezahltCt(t) else { return "kein Netzbezug" }
        return "Ø \(Formate.zahl(ct, stellen: 1)) ct/kWh bezahlt"
    }

    /// Der Sonnenanteil des **Zeitraums**: Sonne und Speicher gegen alles Geladene.
    ///
    /// **Nicht zu verwechseln mit der Spalte gleichen Namens.** `pvShare` je Ladevorgang
    /// (`Schema.swift:3237-3241`) ist eine andere Zahl; die Vorlage nennt beide
    /// „Sonnenanteil“ und meint es so (`EvReport.tsx:28` gegen `:78`). Beim Umbau durfte
    /// daraus nicht eine werden.
    ///
    /// Ohne geladene Kilowattstunde gibt es keinen Anteil, nur eine Division durch Null.
    public static func sonnenanteil(_ t: EnergyTotalsOut) -> Double? {
        let geladen = t.evKwh ?? 0
        guard geladen > 0 else { return nil }
        return ((t.evPvKwh ?? 0) + (t.evBatteryKwh ?? 0)) / geladen
    }

    /// Der mittlere Preis der Netzladung in ct/kWh (`EvReport.tsx:29`).
    ///
    /// **Die Schwelle 0,01 kWh ist keine Zierde.** Darunter teilt die Rechnung durch fast
    /// nichts: zwei Cent auf 0,002 kWh ergeben tausend ct/kWh, und das stünde dann als
    /// Mittelwert unter einer Kachel.
    public static func bezahltCt(_ t: EnergyTotalsOut) -> Double? {
        let netz = t.evGridKwh ?? 0
        guard netz > 0.01 else { return nil }
        return (t.evCostEur ?? 0) / netz * 100
    }

    /// Bezahltes und entgangene Vergütung zusammen, je geladene Kilowattstunde
    /// (`EvReport.tsx:30`).
    ///
    /// **Die eigentliche Antwort der Seite.** Wer mit der eigenen Anlage lädt, bezahlt nichts
    /// und verzichtet doch auf die Einspeisevergütung; erst diese Zahl sagt, was eine Ladung
    /// wirklich kostet.
    public static func effektivCt(_ t: EnergyTotalsOut) -> Double? {
        let geladen = t.evKwh ?? 0
        guard geladen > 0.01 else { return nil }
        return ((t.evCostEur ?? 0) + (t.evOpportunityEur ?? 0)) / geladen * 100
    }

    // MARK: - Die Ladevorgänge

    /// Ein Ladevorgang, fertig für die Tabelle.
    ///
    /// **Warum fertige Zeichenketten und nicht die Antwort selbst.** Beginn und Dauer sind
    /// gerechnet: der Beginn aus Tag und Uhrzeit, die Dauer aus der Differenz zweier
    /// Zeitstempel mit einer Untergrenze. Beides in der Tabelle zu rechnen hieße, es nicht zu
    /// prüfen – und die Dauer ist die Spalte, die in der App ganz fehlte.
    public struct Vorgangszeile: Sendable, Hashable, Identifiable {
        /// Der Zeitstempel des Beginns, unverändert – der Schlüssel der Zeile
        /// (`EvReport.tsx:73`: `key={s.start}`).
        public let start: String
        /// „Di, 10.11. 18:42“.
        public let beginn: String
        /// „10.11. 18:42“ – am Telefon, wo der Zeilenname die einzige immer sichtbare Spalte ist.
        public let kurzerBeginn: String
        public let dauer: String
        public let energie: String
        public let leistung: String
        public let sonnenanteil: String
        public let netz: String
        public let bezahlt: String
        /// Ob für diesen Vorgang überhaupt Geld geflossen ist (`EvReport.tsx:80`).
        public let bezahltAuffaellig: Bool

        public var id: String { start }
    }

    /// Die Ladevorgänge des Zeitraums, neueste zuerst.
    ///
    /// **Absteigend nach Beginn** (`EvReport.tsx:32`). Die App nahm die Reihenfolge der
    /// Antwort; in einem Monat mit dreißig Vorgängen steht damit der heutige unten. ISO-Zeiten
    /// derselben Form ordnen sich als Zeichenketten wie als Zeitpunkte, und die Vorlage
    /// vergleicht genauso.
    public static func vorgaenge(_ b: EvReportOut) -> [Vorgangszeile] {
        b.sessions
            .sorted { $0.start > $1.start }
            .map { s in
                Vorgangszeile(
                    start: s.start,
                    beginn: beginnwort(s.start, kurz: false),
                    kurzerBeginn: beginnwort(s.start, kurz: true),
                    dauer: Formate.dauer(minuten: minuten(von: s.start, bis: s.end)),
                    energie: Formate.kwh(s.kwh),
                    leistung: Formate.kwMitEinheit(s.avgKw),
                    sonnenanteil: Formate.prozent(s.pvShare),
                    netz: Formate.kwh(s.gridKwh),
                    bezahlt: Formate.euro(s.costEur),
                    bezahltAuffaellig: s.costEur > 0.005
                )
            }
    }

    /// Wie lange geladen wurde, in Minuten – mindestens eine.
    ///
    /// **Mindestens eine Minute** (`EvReport.tsx:71`): ein Vorgang, der innerhalb derselben
    /// Minute beginnt und endet, hieße sonst „0 min“ und sähe aus wie ein Messfehler. Ein
    /// unlesbarer Zeitstempel gibt keine Dauer her, auch keine von einer Minute.
    public static func minuten(von: String, bis: String) -> Int? {
        guard let anfang = Zeit.ausIso(von), let ende = Zeit.ausIso(bis) else { return nil }
        return max(1, Int((ende.timeIntervalSince(anfang) / 60).rounded()))
    }

    /// „Di, 10.11. 18:42“ – der Tag gehört dazu.
    ///
    /// **Ohne ihn steht eine Woche voller „18:42“ untereinander.** Der Zeilenname der App war
    /// „18:42 – 21:05“; bei Spanne Woche oder Monat sagt er nicht, welcher Tag gemeint ist,
    /// und das Ende verlangt vom Leser, die Dauer selbst auszurechnen (`EvReport.tsx:74`).
    ///
    /// **Der Wochentag fällt am Telefon weg.** Dort ist der Zeilenname die einzige Spalte, die
    /// immer dasteht (`Bericht.swift:206-244`), und „Di, 10.11. 18:42“ neben einer Zahl ist
    /// auf 390 Punkten zu breit. Die Vorlage löst dasselbe Problem mit waagerechtem Rollen,
    /// das es hier nicht gibt.
    static func beginnwort(_ iso: String, kurz: Bool) -> String {
        guard let d = Zeit.ausIso(iso) else { return Formate.leer }
        let tag = Tag.iso(d)
        return (kurz ? Tag.tagMonat(tag) : Tag.kurz(tag)) + " " + Formate.hhmm(d)
    }

    /// Was rechts im Kopf der Ladevorgangskarte steht (`EvReport.tsx:54`).
    ///
    /// Die Zahl gehört dorthin und nicht auf eine Kachel: sie sagt, wie viele Zeilen die
    /// Tabelle hat, und beantwortet damit, ob eine kurze Liste kurz ist oder abgeschnitten.
    public static func kopfzeile(anzahl: Int) -> String {
        anzahl > 0 ? "\(anzahl) im Zeitraum" : "keine im Zeitraum"
    }

    // MARK: - Wallbox im Überblick

    /// Dieselben vier Größen für Tag, Woche, Monat und Jahr zum selben Anker
    /// (`EvReport.tsx:94-99`).
    ///
    /// **Ohne sie sagt die Seite nicht, ob eine Zahl groß ist.** Ob zwölf Kilowattstunden an
    /// diesem Tag viel sind, sagt erst der Monat daneben. Die App holte genau eine Spanne.
    ///
    /// Fehlt eine Spanne, steht in ihrer Spalte ein Strich (`EvReport.tsx:33`): die vier
    /// Abfragen laufen einzeln, und eine gescheiterte darf die Karte nicht mitnehmen.
    public static func spannenzeilen(_ je: [Spanne: EvReportOut]) -> [Streifenzeile] {
        let folge = Spanne.allCases
        func reihe(
            _ wort: String, _ ton: Kennzahl.Ton, _ wert: (EvReportOut) -> String
        ) -> Streifenzeile {
            Streifenzeile(wort: wort, werte: folge.map { je[$0].map(wert) ?? Formate.leer }, ton: ton)
        }
        return [
            reihe("Geladen · kWh", .nebel) { geladenKurz($0.summary.totals) },
            reihe("Sonnenanteil", .bernstein) { Formate.prozent(sonnenanteil($0.summary.totals)) },
            // `EvReport.tsx:97` traegt hier dasselbe `ember` wie die Kachel darueber. Zwei
            // Toene fuer dieselbe Zahl auf derselben Seite waeren zwei Aussagen.
            reihe("Bezahlt", .alarm) { Formate.euro($0.summary.totals.evCostEur) },
            reihe("Ladevorgänge", .normal) { String($0.sessions.count) },
        ]
    }

    /// Die geladene Menge für eine Spalte des Streifens.
    ///
    /// **Ab hundert Kilowattstunden ohne Nachkommastelle** (`EvReport.tsx:95`). Eine
    /// Jahresspalte zeigt „1284“ und nicht „1284,3“: das Zehntel einer Jahressumme ist
    /// Rauschen, und vier Zahlenspalten nebeneinander haben für Rauschen keinen Platz.
    static func geladenKurz(_ t: EnergyTotalsOut) -> String {
        guard let kwh = t.evKwh else { return Formate.leer }
        return Formate.zahl(kwh, stellen: kwh >= 100 ? 0 : 1)
    }

    // MARK: - Was die Seite über sich selbst sagt

    /// Was ein Ladevorgang ist (`EvReport.tsx:102`).
    ///
    /// **Ohne diesen Satz ist „4 Ladevorgänge“ nicht prüfbar.** Die Zahl hängt an drei
    /// Schwellen des Dienstes, und keine davon steht in der Antwort. Die App hatte an dieser
    /// Stelle stattdessen einen Satz über die Herkunft der Ladung – der gehört zur
    /// Speicherseite und stand hier doppelt.
    public static let ladevorgangssatz =
        "Ein Ladevorgang beginnt ab 0,3 kW Wallboxleistung und endet nach 5 Minuten Pause; "
        + "Vorgänge unter 0,2 kWh werden nicht gezählt."

    /// Die Zeile, die auch zugeklappt dasteht: wie lückenlos die Daten des Zeitraums sind
    /// (`ReportShell.tsx:165-168`).
    ///
    /// **Sie darf nicht unter den Deckel.** Eine Seite mit 61 Prozent Abdeckung sieht aus wie
    /// eine mit hundert; was eine Zahl *an diesem Tag* einschränkt, steht neben der Zahl und
    /// nicht in der zugeklappten Methode (`ui/Methode.tsx:11-13`).
    ///
    /// **`nil` und Null sind hier nicht dasselbe.** Fehlt das Feld, hat niemand gemessen; eine
    /// Abdeckung von Null ist eine Messung, die nichts gefunden hat.
    /// ``Waermeuebersicht/abdeckungssatz(_:)`` wirft beides zusammen und schreibt zudem das
    /// kurze Datum – die Vorlage schreibt das volle Jahr, weil „Aufzeichnung seit Di, 10.11.“
    /// offenlässt, welches.
    public static func abdeckung(_ m: EnergyMetaOut) -> String {
        var teile: [String] = []
        if let anteil = m.coverage {
            teile.append("Datenabdeckung \(Formate.prozent(anteil))")
        } else {
            teile.append("noch keine Messdaten im Zeitraum")
        }
        let seit = m.dataSince.map { String($0.prefix(10)) }
        if let seit, Tag.istTag(seit) {
            teile.append("Aufzeichnung seit \(Spannenworte.zifferndatum(seit))")
        }
        return teile.joined(separator: " · ")
    }
}

/// Eine Zeile des Spannenstreifens: ein Wort, vier Werte, ein Ton.
///
/// **Warum der Typ keiner Seite gehört.** Die Vorlage benutzt den Streifen auf sieben
/// Berichtsseiten (`PeriodStrip` in `HouseReport`, `PvReport`, `EvReport`, `PvAccounting`,
/// `BatteryReport`, `CostReport`, `HeatOverview`), und jede füllt ihn mit eigenen Zeilen. Dass
/// er in dieser Datei liegt, ist vorläufig: die Wallbox ist die erste Seite, die ihn braucht.
public struct Streifenzeile: Sendable, Hashable, Identifiable {
    public let wort: String
    /// Die Werte in der Reihenfolge von ``Spanne/allCases``.
    public let werte: [String]
    public let ton: Kennzahl.Ton

    public var id: String { wort }

    public init(wort: String, werte: [String], ton: Kennzahl.Ton = .normal) {
        self.wort = wort
        self.werte = werte
        self.ton = ton
    }
}

/// Die Wörter über und neben dem Spannenstreifen.
///
/// **Die Spalten folgen der Blätterleiste, und der Kopf muss das sagen** – sonst stehen die
/// Zahlen eines vergangenen Tages unter einer Überschrift, die „Heute“ heißt
/// (`PeriodStrip.tsx:11-16,34-38`).
public enum Spannenworte {

    /// Der Kopf einer Spalte.
    ///
    /// Die Tagesspalte heißt nur „Heute“, wenn der Anker auch heute ist; sonst steht dort das
    /// Datum des Ankers. Die drei anderen Spalten brauchen das nicht: ihre Lage sagt der
    /// Hinweis „jeweils bis …“ im Kartenkopf.
    public static func kopf(_ spanne: Spanne, anker: String, jetzt: Date) -> String {
        guard spanne == .tag else { return spanne.name }
        if anker == Tag.heute(jetzt: jetzt) { return "Heute" }
        return Tag.tagMonat(anker)
    }

    /// Worauf sich die vier Spalten beziehen (`PeriodStrip.tsx:34-38`).
    public static func bis(anker: String, jetzt: Date) -> String {
        anker == Tag.heute(jetzt: jetzt)
            ? "jeweils bis jetzt"
            : "jeweils bis \(zifferndatum(anker))"
    }

    /// „10.11.2026“ – Tag, Monat und Jahr in Ziffern.
    ///
    /// **Nicht ``Tag/lang(_:)``.** Das schreibt „Dienstag, 10. November 2026“ und ist für eine
    /// Blätterleiste gedacht, die eine ganze Zeile hat. Hier steht das Datum rechts in einer
    /// Kopfzeile neben einer Überschrift und soll nicht umbrechen
    /// (`PeriodStrip.tsx:37`, `ReportShell.tsx:165`).
    public static func zifferndatum(_ tag: String) -> String {
        guard let d = Tag.date(tag) else { return tag }
        let t = Kalender.haus.dateComponents([.day, .month, .year], from: d)
        return String(format: "%02d.%02d.%04d", t.day ?? 0, t.month ?? 0, t.year ?? 0)
    }
}
