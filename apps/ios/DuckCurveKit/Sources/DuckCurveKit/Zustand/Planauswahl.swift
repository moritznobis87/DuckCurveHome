import Foundation

/// Welche Viertelstunden des Plans es wert sind, einzeln dazustehen.
///
/// **Sechs Zeilen, nicht hundertvierzig – die Ränder tragen die Aussage.** Ein Plan über
/// 24 Stunden hat 96 Viertelstunden, und an einem ruhigen Tag steht in fast allen dasselbe.
/// Eine Liste daraus ist keine Auskunft, sondern eine Wand; auf dem Telefon stand sie als
/// zweiunddreißig Zeilen „aus" untereinander.
///
/// Das Dashboard (`waerme/Fahrplan.tsx`, `Tabelle`) wählt stattdessen die drei teuersten und
/// die drei billigsten Viertelstunden aus und zeigt sie in zeitlicher Reihenfolge. Das ist
/// die Entscheidung, um die es geht: Wo ist Strom teuer, wo billig, und was hat der Planer
/// dort vor.
public enum Planauswahl {
    /// Die Viertelstunden an den Preisenden, zeitlich geordnet und ohne Wiederholung.
    ///
    /// Viertelstunden ohne Preis fallen weg: ohne Preis gibt es kein Ende, an dem sie stünde.
    public static func raender(_ intervalle: [PlanIntervalOut], je anzahl: Int = 3)
        -> [PlanIntervalOut]
    {
        let mitPreis = intervalle.filter { $0.priceCtKwh != nil }
        guard !mitPreis.isEmpty, anzahl > 0 else { return [] }
        let nachPreis = mitPreis.sorted { ($0.priceCtKwh ?? 0) > ($1.priceCtKwh ?? 0) }
        let gewaehlt = nachPreis.prefix(anzahl) + nachPreis.suffix(anzahl)
        var gesehen = Set<String>()
        return gewaehlt
            .filter { gesehen.insert($0.ts).inserted }
            .sorted { $0.ts < $1.ts }
    }

    /// Eine Zeile der Entscheidungstabelle.
    ///
    /// **Warum als Wert und nicht als sechs Listen von Zeichenketten.** Die Ansicht hat die
    /// Abbildung `planned_hp_state` → Wort ein zweites Mal geschrieben und dabei vertauscht:
    /// In der Zeile, in der der Plan die Wärmepumpe *anfordert*, stand „frei" – und „frei" ist
    /// der Name eines anderen Zustands. Dieselbe Seite nannte denselben Zustand in der
    /// Zeichnung und in der Tabelle verschieden. Hier liegt das Wort an einer Stelle, und die
    /// Rolle trägt gleich die Farbe mit, die die Vorlage drei Zellen gibt
    /// (`waerme/Fahrplan.tsx:715-721`: Puffer, Wärmepumpe, Ofen).
    public struct Entscheidung: Sendable, Hashable, Identifiable {
        public let zeit: Date
        public let preis: Double?
        public let bedarf: Double?
        public let puffer: Double?
        public let zustandswort: String
        public let zustandsrolle: Fahrplanbild.Rolle
        public let ofenwort: String
        public let ofenrolle: Fahrplanbild.Rolle
        /// Der Satz des Dienstes, sonst sein Schlüssel – irgendetwas sagt er immer.
        public let warum: String

        public var id: Date { zeit }

        public init(
            zeit: Date, preis: Double?, bedarf: Double?, puffer: Double?, zustandswort: String,
            zustandsrolle: Fahrplanbild.Rolle, ofenwort: String, ofenrolle: Fahrplanbild.Rolle,
            warum: String
        ) {
            self.zeit = zeit
            self.preis = preis
            self.bedarf = bedarf
            self.puffer = puffer
            self.zustandswort = zustandswort
            self.zustandsrolle = zustandsrolle
            self.ofenwort = ofenwort
            self.ofenrolle = ofenrolle
            self.warum = warum
        }
    }

    /// Die sechs Zeilen der Entscheidungstabelle, fertig.
    public static func entscheidungen(_ intervalle: [PlanIntervalOut], je anzahl: Int = 3)
        -> [Entscheidung]
    {
        raender(intervalle, je: anzahl).compactMap { iv -> Entscheidung? in
            guard let zeit = Zeit.ausIso(iv.ts) else { return nil }
            let zustand = Fahrplanbild.zustand(iv.plannedHpState)
            let ofen: (wort: String, rolle: Fahrplanbild.Rolle) =
                switch iv.plannedStoveOn {
                case .some(true): ("brennt", .ofenAn)
                case .some(false): ("aus", .ofenAus)
                case .none: (Formate.leer, .neutral)
                }
            return Entscheidung(
                zeit: zeit, preis: iv.priceCtKwh, bedarf: bedarf(iv), puffer: iv.bufferKwh,
                zustandswort: zustand.wort, zustandsrolle: zustand.rolle,
                ofenwort: ofen.wort, ofenrolle: ofen.rolle,
                warum: iv.noteDe ?? Grundwort.text(kennung: iv.reasonCode)
            )
        }
    }

    /// Der Wärmebedarf einer Viertelstunde: Heizung **und** Warmwasser.
    ///
    /// Beides steht getrennt im Plan und gehört in einer Zeile zusammen – wer nur die Heizung
    /// zeigt, lässt an einem Warmwassertag den halben Bedarf weg.
    public static func bedarf(_ iv: PlanIntervalOut) -> Double? {
        guard let heizung = iv.heatDemandKw else { return iv.dhwDemandKw }
        return heizung + (iv.dhwDemandKw ?? 0)
    }
}
