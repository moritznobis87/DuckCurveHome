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

    /// Der Wärmebedarf einer Viertelstunde: Heizung **und** Warmwasser.
    ///
    /// Beides steht getrennt im Plan und gehört in einer Zeile zusammen – wer nur die Heizung
    /// zeigt, lässt an einem Warmwassertag den halben Bedarf weg.
    public static func bedarf(_ iv: PlanIntervalOut) -> Double? {
        guard let heizung = iv.heatDemandKw else { return iv.dhwDemandKw }
        return heizung + (iv.dhwDemandKw ?? 0)
    }
}
