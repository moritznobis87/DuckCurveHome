import Foundation

/// Die Rechnungen der PV-Abrechnung: Kennzahlen, Aufstellung, Erlösbild, Sätze.
///
/// Vorlage ist `apps/web/src/components/reports/PvAccounting.tsx`. Diese Seite ist der einzige
/// Bericht des Projekts, der kein Energiebericht ist, sondern ein Beleg: ihre Zahlen gehen in
/// eine Umsatzsteuervoranmeldung. Darum steht hier mehr als sonst - jede Schwelle, jede
/// Rundung, jeder Wortlaut und jede Farbzuordnung, damit sie geprüft werden können und nicht
/// in einer `View` liegen, wo das unter Linux niemand nachrechnet.
///
/// **`PvTaxTotals` ist in Swift durchweg wahlfrei, im Web nicht** (`Schema.swift:6441-6458`
/// gegen `types.ts:5425-5505`). Der Unterschied ist keine Kleinigkeit: im Diagramm ist eine
/// fehlende Zahl kein Balken (`?? 0`), in der Aufstellung ist sie ein Strich
/// (``Formate/leer``) - die Vorlage trennt das über `eur(null) === "-"`
/// (`ReportShell.tsx:15`). Eine Null, die keine Messung ist, wäre auf einem Beleg eine
/// Behauptung.
public enum Pvabrechnung {

    // MARK: - Die sechs Kennzahlen

    /// Die sechs Kopfzahlen in der Reihenfolge der Vorlage (`PvAccounting.tsx:92-97`).
    ///
    /// **Die Seite führt mit der Einspeisung, nicht mit der Zahllast.** Die App hatte
    /// „Umsatzsteuer zu zahlen“ voran; die Vorlage stellt „Eingespeist“ an den Anfang und die
    /// Steuer an das Ende. Das ist die Leserichtung eines Belegs: erst die Menge, dann ihr
    /// Wert, dann die Steuer darauf - und am Schluss, was zu zahlen ist.
    ///
    /// **Der Kleinunternehmerfall kommt aus `meta`, nicht aus `totals`** (`:58`). Beide Felder
    /// gibt es (`Schema.swift:6363`, `:6441`); die App las bisher das in `totals`, und das ist
    /// pro Zeitraum gefüllt - `meta` gilt für die Anlage. Zwei Kacheln werden damit gedämpft:
    /// eine Umsatzsteuer, die niemand schuldet, soll nicht wie eine Zahl aussehen, die
    /// jemand zahlt.
    public static func kennzahlen(_ b: PvTaxReportOut) -> [Kennzahl] {
        let t = b.totals
        let ohneUst = b.meta.smallBusiness
        return [
            Kennzahl(
                wort: "Eingespeist", wert: Formate.kwhNachGroesse(t.exportKwh), einheit: "kWh",
                dazu: verguetungssatz(b.meta.feedInCtKwh), ton: .nebel),
            Kennzahl(
                wort: "Vergütung netto", wert: Formate.euro(t.exportNetEur),
                dazu: ohneUst ? "ohne Umsatzsteuer" : "brutto \(Formate.euro(t.exportGrossEur))"),
            Kennzahl(
                wort: "USt auf Einspeisung", wert: Formate.euro(t.exportVatEur),
                dazu: "ausgezahlt, abzuführen", ton: ohneUst ? .gedaempft : .normal),
            Kennzahl(
                wort: "Eigenverbrauch", wert: Formate.kwhNachGroesse(t.selfConsumptionKwh),
                einheit: "kWh", dazu: speichersatz(t.selfBatteryKwh), ton: .bernstein),
            Kennzahl(
                wort: "Wert des Eigenverbrauchs", wert: Formate.euro(t.selfValueNetEur),
                dazu: mittelwertsatz(t.selfCtKwh)),
            Kennzahl(
                wort: "Umsatzsteuer gesamt", wert: Formate.euro(t.vatPayableEur),
                dazu: ohneUst ? "Kleinunternehmer: keine USt" : "Einspeisung + Wertabgabe",
                ton: ohneUst ? .gedaempft : .bernstein),
        ]
    }

    /// „8,20 ct/kWh netto“ - der Satz, zu dem eingespeist wird (`PvAccounting.tsx:92`).
    ///
    /// **Zwei Nachkommastellen, nicht eine.** ``Formate/ct(_:)`` schreibt eine; ein
    /// Vergütungssatz steht auf fünfzehn Jahre fest und wird im Cent verhandelt - „8,2“ wäre
    /// hier eine gerundete Vertragszahl.
    static func verguetungssatz(_ ctKwh: Double) -> String {
        Formate.zahl(ctKwh, stellen: 2) + Formate.schmalesLeerzeichen + "ct/kWh netto"
    }

    /// „davon 3,2 kWh über den Speicher“ (`PvAccounting.tsx:95`).
    static func speichersatz(_ kwh: Double?) -> String? {
        guard kwh != nil else { return nil }
        return "davon \(Formate.kwhNachGroesse(kwh)) kWh über den Speicher"
    }

    /// „netto, Ø 28,40 ct/kWh“ (`PvAccounting.tsx:96`).
    ///
    /// **Ohne den Mittelwert bleibt „netto“ stehen.** Die Vorlage schreibt dort
    /// `netto, Ø ${ct(self_ct_kwh)}/kWh`, und `ct(null)` ist ein Strich - auf der Seite stünde
    /// dann „netto, Ø -/kWh“. Das ist kein Satz; fehlt der Wert, fehlt die Hälfte des Satzes.
    static func mittelwertsatz(_ ctKwh: Double?) -> String {
        guard let ctKwh, ctKwh.isFinite else { return "netto" }
        return "netto, Ø " + Formate.zahl(ctKwh, stellen: 2) + Formate.schmalesLeerzeichen
            + "ct/kWh"
    }

    // MARK: - Die Aufstellung

    /// Eine Spalte der Aufstellung: zwei Kopfzeilen und ob sie Farbe trägt.
    ///
    /// **Der Kopf hat zwei Ebenen, und ohne sie steht ein Wort zweimal da**
    /// (`PvAccounting.tsx:29-37`, `:116`). „USt darauf“ ist die dritte *und* die sechste
    /// Spalte; erst „erhalten“ gegen „geschuldet“ sagt, welche Seite gemeint ist - die eine
    /// hat das Netz ausgezahlt, die andere ist dem Finanzamt geschuldet.
    public struct Abrechnungsspalte: Sendable, Hashable, Identifiable {
        public let kopf: String
        public let unter: String
        /// Die eine Spalte in Bernstein (`PvAccounting.tsx:126`, `COLUMNS[6].strong`).
        public let betont: Bool

        /// Kopf und Unterzeile zusammen - der Kopf allein ist nicht eindeutig.
        public var id: String { kopf + " · " + unter }
        /// Beide Ebenen in einer Zeile, für den Umschalter am Telefon.
        public var name: String { id }

        public init(kopf: String, unter: String, betont: Bool = false) {
            self.kopf = kopf
            self.unter = unter
            self.betont = betont
        }
    }

    /// Eine Zeile der Aufstellung - dieselbe Gestalt für die Zeiträume und für die Summe
    /// (`PvAccounting.tsx:18-27`: dort heißt der Typ `Row` und trägt beides).
    public struct Abrechnungszeile: Sendable, Hashable, Identifiable {
        public let wort: String
        /// Die sieben Zellen in der Reihenfolge der Spalten.
        public let zellen: [String]

        public var id: String { wort }

        public init(wort: String, zellen: [String]) {
            self.wort = wort
            self.zellen = zellen
        }
    }

    /// Die ganze Aufstellung: Spalten, Zeilen, Summe und die beiden Sätze darum.
    public struct Aufstellung: Sendable, Hashable {
        public let spalten: [Abrechnungsspalte]
        public let zeilen: [Abrechnungszeile]
        /// Die abgesetzte Summenzeile aus `totals` (`PvAccounting.tsx:132-141`).
        public let summe: Abrechnungszeile
        /// Was rechts im Kartenkopf steht (`PvAccounting.tsx:108`).
        public let kopfzeile: String
        /// Warum Summe und Zeilensumme auseinandergehen dürfen (`PvAccounting.tsx:145-148`).
        public let rundungssatz: String
    }

    /// Die sieben Spalten der Aufstellung, in der Reihenfolge der Vorlage
    /// (`PvAccounting.tsx:29-37`).
    public static let aufstellungsspalten: [Abrechnungsspalte] = [
        Abrechnungsspalte(kopf: "Einspeisung", unter: "kWh"),
        Abrechnungsspalte(kopf: "Vergütung", unter: "netto"),
        Abrechnungsspalte(kopf: "USt darauf", unter: "erhalten"),
        Abrechnungsspalte(kopf: "Eigenverbrauch", unter: "kWh"),
        Abrechnungsspalte(kopf: "Wertabgabe", unter: "netto"),
        Abrechnungsspalte(kopf: "USt darauf", unter: "geschuldet"),
        Abrechnungsspalte(kopf: "Zahllast", unter: "USt gesamt", betont: true),
    ]

    /// Die Aufstellung eines Berichts.
    ///
    /// **Drei der sieben Spalten sind der Grund, warum die Seite existiert.** „USt darauf ·
    /// erhalten“, „Wertabgabe · netto“ und „USt darauf · geschuldet“ sind die
    /// Bemessungsgrundlagen; die App zeigte vier Spalten und keine davon
    /// (`GeldSeiten.swift:159-183` vor dem Umbau). Wer die Voranmeldung ausfüllt, braucht
    /// genau diese drei je Monat.
    ///
    /// **Die Summe kommt aus `totals` und nicht aus den Zeilen** (`rowOf`, `:39-50`). Der
    /// Dienst addiert ungerundete Stundenwerte; die Zeilen sind einzeln gerundet. Beides
    /// nebeneinander kann um Cent auseinandergehen, und darum steht der Satz darunter - eine
    /// nachgerechnete Summe wäre falsch und sähe richtig aus.
    public static func aufstellung(_ b: PvTaxReportOut) -> Aufstellung {
        let gefiltert = buckets(b)
        return Aufstellung(
            spalten: aufstellungsspalten,
            zeilen: gefiltert.map { zeile(wort: $0.label, $0.totals) },
            summe: zeile(wort: "Summe", b.totals),
            kopfzeile: "\(gefiltert.count) Zeilen · Beträge in Euro",
            rundungssatz:
                "Die Summe stammt aus den ungerundeten Stundenwerten, die Zeilen sind einzeln "
                + "gerundet: ihre Addition kann um wenige Cent abweichen."
        )
    }

    /// Die Zeitraumstücke, die etwas hergeben (`PvAccounting.tsx:60-63`).
    ///
    /// **Leere Stücke fallen weg, in der Tabelle wie im Bild.** Blättert man im Januar auf das
    /// Jahr, liefert der Dienst zwölf Monate, zehn davon mit Nullen; die Vorlage filtert sie
    /// mit derselben Schwelle für beide Darstellungen heraus. Die Schwelle ist 0,005 kWh und
    /// nicht Null: ein Wechselrichter, der eine Wattstunde meldet, hat keinen Monat
    /// eingespeist.
    static func buckets(_ b: PvTaxReportOut) -> [PvTaxBucketOut] {
        b.buckets.filter {
            ($0.totals.exportKwh ?? 0) > 0.005 || ($0.totals.selfConsumptionKwh ?? 0) > 0.005
        }
    }

    private static func zeile(wort: String, _ t: PvTaxTotals) -> Abrechnungszeile {
        Abrechnungszeile(
            wort: wort,
            zellen: [
                Formate.kwhNachGroesse(t.exportKwh),
                Formate.euro(t.exportNetEur),
                Formate.euro(t.exportVatEur),
                Formate.kwhNachGroesse(t.selfConsumptionKwh),
                Formate.euro(t.selfValueNetEur),
                Formate.euro(t.selfVatEur),
                Formate.euro(t.vatPayableEur),
            ])
    }

    // MARK: - Erlös und Wertabgabe

    /// Eine Reihe des Erlösbildes.
    ///
    /// **Der Ton und nicht die Farbe.** `Farbe` liegt in der Oberfläche, der Kern kennt sie
    /// nicht - und soll sie nicht kennen: die Zuordnung Rolle zu Farbe steht im Projekt an
    /// genau einer Stelle (`Farben.swift:98`). Die Vorlage nimmt `C.mist` für die Vergütung
    /// und `C.pv` für den Eigenverbrauch (`PvAccounting.tsx:69-70`); das sind hier ``nebel``
    /// und ``sonne``.
    public struct Erloesreihe: Sendable {
        public let name: String
        public let ton: Kennzahl.Ton
        public let werte: [(beschriftung: String, wert: Double)]

        public init(
            name: String, ton: Kennzahl.Ton, werte: [(beschriftung: String, wert: Double)]
        ) {
            self.name = name
            self.ton = ton
            self.werte = werte
        }
    }

    /// Die zwei gestapelten Euro-Reihen des Erlösbildes (`charts.ts:367-399`).
    ///
    /// **Hier ist `?? 0` richtig.** Ein Balken ist eine Fläche; fehlt die Zahl, ist die Fläche
    /// Null. Ein Strich lässt sich nicht stapeln, und ein fehlender Monat soll keine Lücke in
    /// der Achse reißen - die Aufstellung darunter sagt, dass dort nichts gemessen wurde.
    ///
    /// Gerundet wird auf Cent (`charts.ts:394`): die Beschriftung des Tooltips und der
    /// gestapelte Balken sollen dieselbe Zahl sein.
    public static func erloesreihen(_ b: PvTaxReportOut) -> [Erloesreihe] {
        let stuecke = buckets(b)
        func reihe(_ name: String, _ ton: Kennzahl.Ton, _ wert: (PvTaxTotals) -> Double?)
            -> Erloesreihe
        {
            Erloesreihe(
                name: name, ton: ton,
                werte: stuecke.map { ($0.label, aufCent(wert($0.totals) ?? 0)) })
        }
        return [
            reihe("Einspeisevergütung netto", .nebel) { $0.exportNetEur },
            reihe("Eigenverbrauch (Wert netto)", .sonne) { $0.selfValueNetEur },
        ]
    }

    private static func aufCent(_ wert: Double) -> Double {
        guard wert.isFinite else { return 0 }
        return (wert * 100).rounded() / 100
    }

    /// Der Satz, der im Bild steht, wenn nichts zu zeigen ist (`PvAccounting.tsx:103`).
    public static let leersatz = "Für diesen Zeitraum liegen keine bewerteten Stunden vor."

    /// Was rechts über dem Bild steht (`PvAccounting.tsx:102`).
    public static let erloeskopf = "Einspeisevergütung · Eigenverbrauch, jeweils netto"

    // MARK: - Zeiträume im Vergleich

    /// Die fünf Zeilen des Spannenstreifens (`PvAccounting.tsx:154-160`).
    ///
    /// **Vier Abfragen zum selben Anker, nicht vier Zeitpunkte.** Die Begründung steht in der
    /// Vorlage (`useReport.ts:48-54`): der Anker war dort einmal fest auf heute verdrahtet,
    /// und wer auf den 3. Januar blätterte, sah oben die Zahlen dieses Tages und daneben
    /// weiterhin die laufende Woche - „zwei Zeiträume in einer Ansicht, ohne dass es dastand“.
    ///
    /// Fehlt eine Spanne, steht in ihrer Spalte ein Strich (`PvAccounting.tsx:76`): die vier
    /// Abfragen laufen einzeln, und eine gescheiterte darf die Karte nicht mitnehmen.
    public static func spannenzeilen(_ je: [Spanne: PvTaxReportOut]) -> [Streifenzeile] {
        let folge = Spanne.allCases
        func reihe(_ wort: String, _ ton: Kennzahl.Ton, _ wert: (PvTaxTotals) -> String)
            -> Streifenzeile
        {
            Streifenzeile(
                wort: wort, werte: folge.map { je[$0].map { wert($0.totals) } ?? Formate.leer },
                ton: ton)
        }
        return [
            reihe("Einspeisung · kWh", .nebel) { Formate.kwhNachGroesse($0.exportKwh) },
            reihe("Vergütung netto", .normal) { Formate.euro($0.exportNetEur) },
            reihe("Eigenverbrauch · kWh", .normal) {
                Formate.kwhNachGroesse($0.selfConsumptionKwh)
            },
            reihe("Wert Eigenverbrauch netto", .normal) { Formate.euro($0.selfValueNetEur) },
            reihe("Umsatzsteuer gesamt", .bernstein) { Formate.euro($0.vatPayableEur) },
        ]
    }

    // MARK: - Was die Seite über sich selbst sagt

    /// Die Schlussnote der Vorlage (`PvAccounting.tsx:163-172`), zerlegt in die Zeile, die
    /// immer dasteht, und den Rumpf darunter.
    ///
    /// **Die Abdeckung darf nicht unter den Deckel.** Die Vorlage hat dort gar keinen Deckel -
    /// ihre Note steht offen. Die App klappt Methodensätze zu (`Bericht.swift:355-357`: „was
    /// immer dasteht, liest niemand“), und darum muss die eine Zeile, die *jede* Zahl dieser
    /// Seite einschränkt, in die Kurzzeile. Dasselbe Muster hat die Stromseite gewählt
    /// (`StromSeite.swift:47-56`).
    ///
    /// **`nil` und Null sind nicht dasselbe.** Fehlt `coverage`, hat niemand gemessen; eine
    /// Abdeckung von Null ist eine Messung, die nichts gefunden hat. Die Vorlage schreibt für
    /// den ersten Fall „Für diesen Zeitraum liegen keine Messdaten vor.“ (`:166`).
    public static func saetze(_ b: PvTaxReportOut) -> (kurz: String, rumpf: [String]) {
        (kurz: abdeckung(b.meta), rumpf: rumpf(b))
    }

    static func abdeckung(_ m: PvTaxMetaOut) -> String {
        guard let anteil = m.coverage else { return "Für diesen Zeitraum liegen keine Messdaten vor." }
        return "Datenabdeckung \(Formate.prozent(anteil))"
    }

    private static func rumpf(_ b: PvTaxReportOut) -> [String] {
        var aus: [String] = []
        if !b.meta.methodDe.isEmpty { aus.append(b.meta.methodDe) }
        aus.append(steuersatz(b.meta))
        if let satz = schaetzsatz(b.totals.selfEstimatedKwh) { aus.append(satz) }
        aus.append("Die Zahlen bereiten die Beträge auf, sie ersetzen keine Steuerberatung.")
        return aus
    }

    /// Welcher Umsatzsteuersatz gilt - oder dass keiner gilt.
    ///
    /// **Den Satz hat die Vorlage nicht, und er bleibt trotzdem.** `vat_rate` kommt dort
    /// nirgends vor (`PvAccounting.tsx:163-171`), die App hatte ihn bisher
    /// (`GeldSeiten.swift:188-190`). Auf einem Beleg ist der angewandte Satz die Zahl, mit der
    /// jeder Betrag daneben nachgerechnet wird; ihn wegzulassen, um der Vorlage zu gleichen,
    /// würde die Seite als Beleg schlechter machen. Er steht im zugeklappten Rumpf und nimmt
    /// darum keinen Platz, den die Vorlage anders nutzt.
    ///
    /// Der Dienst liefert den Satz je nach Quelle als Anteil (0,19) oder als Prozentzahl (19);
    /// über eins gelesen ist es Prozent.
    static func steuersatz(_ m: PvTaxMetaOut) -> String {
        if m.smallBusiness {
            return "Kleinunternehmerregelung: keine Umsatzsteuer ausgewiesen."
        }
        let anteil = m.vatRate > 1 ? m.vatRate / 100 : m.vatRate
        return "Umsatzsteuersatz \(Formate.prozent(anteil))."
    }

    /// „Bei 3,2 kWh der Speicherentladung war die Herkunft nicht bekannt; sie zählen als PV.“
    /// (`PvAccounting.tsx:168`).
    ///
    /// **Der Wortlaut ist der Unterschied.** Die App sagte „Vom Eigenverbrauch sind 3,2 kWh
    /// geschätzt, nicht gemessen.“ Das nennt eine Menge, aber nicht, *welche* kWh und *wie*
    /// sie gezählt werden - und genau das entscheidet, ob eine Wertabgabe zu hoch oder zu
    /// niedrig angesetzt ist.
    ///
    /// Unter 0,05 kWh steht nichts da: eine Zehntel-Wattstunde unbekannter Herkunft ist keine
    /// Nachricht, und ein Vorbehalt, der immer dasteht, wird nicht gelesen.
    static func schaetzsatz(_ kwh: Double?) -> String? {
        guard let kwh, kwh.isFinite, kwh > 0.05 else { return nil }
        return "Bei \(Formate.zahl(kwh, stellen: 1)) kWh der Speicherentladung war die Herkunft "
            + "nicht bekannt; sie zählen als PV."
    }
}
