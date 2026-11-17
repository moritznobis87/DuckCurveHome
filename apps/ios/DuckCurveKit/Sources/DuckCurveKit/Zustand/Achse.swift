import Foundation

/// Welche Beschriftungen an eine Achse passen.
///
/// **Warum das gerechnet und nicht geschätzt wird.** Swift Charts beschriftet eine Achse aus
/// Wörtern vollständig – bei einem Monat also dreißigmal. Auf 390 Punkten ergibt das einen
/// Streifen aus Ziffern, in dem keine Zahl mehr lesbar ist; genau so stand es auf der
/// Geld-Seite. Welche Beschriftung stehen bleibt, ist eine Auswahl mit genau einer richtigen
/// Antwort je Eingabe, also steht sie hier und nicht in der Ansicht.
public enum Achse {
    /// Höchstens `hoechstens` Beschriftungen, gleichmäßig verteilt.
    ///
    /// Die erste steht immer, damit die Achse einen Anfang hat. Die letzte wird **nicht**
    /// erzwungen: ein Abstand, der am Ende plötzlich kleiner ist, sieht aus wie ein Fehler
    /// und nicht wie eine Entscheidung.
    public static func beschriftungen(_ alle: [String], hoechstens: Int = 8) -> [String] {
        guard hoechstens > 0 else { return [] }
        guard alle.count > hoechstens else { return alle }
        let schritt = Int((Double(alle.count) / Double(hoechstens)).rounded(.up))
        return alle.enumerated().compactMap { i, w in i % schritt == 0 ? w : nil }
    }
}
