import Foundation

/// Die Worte der Seite „Einstellen“, im Wortlaut des Dashboards
/// (`apps/web/src/components/einstellen/Einstellen.tsx`).
public enum Einstellworte {
    public static let suchfeld = "Einstellung suchen, etwa „Heizkurve“"
    public static let nichtsGefunden = "Dazu gibt es keine Einstellung."
    public static let vonHand = "Gerade von Hand gestellt"
    public static let nichtAbrufbar = "Was gerade von Hand gestellt ist, lässt sich gerade nicht abfragen."
    public static let allesZurueck = "Alles zurück auf Automatik"
    public static let rueckfrage = "Zurück auf Automatik gehen:"
    public static let raeumeBleiben = "Räume, die jemand von Hand gestellt hat, bleiben, wie sie sind."
    public static let zurueckstellen = "Zurückstellen"
    public static let stelltZurueck = "Stelle zurück…"
    public static let abbrechen = "Abbrechen"
    public static let nichtDurch = "Das Zurückstellen ging nicht durch."
    public static let system = "System"
    public static let systemWort = "was das Haus am Laufen hält"

    /// Titel und Satz der Zustandskarte oben auf der Seite (`Einstellen.tsx`, `zustandssatz`).
    /// Ohne Anzahl ist der Stand noch nicht da.
    public static func zustand(_ anzahl: Int?) -> (titel: String, satz: String) {
        guard let anzahl else { return ("Automatik", "Der Stand wird abgefragt.") }
        if anzahl == 0 { return ("Alles auf Automatik", "Nichts ist gerade von Hand gestellt.") }
        return (
            anzahl == 1 ? "1 Eingriff von Hand" : "\(anzahl) Eingriffe von Hand",
            "Jeder endet von selbst, wenn seine Frist abläuft."
        )
    }
}
