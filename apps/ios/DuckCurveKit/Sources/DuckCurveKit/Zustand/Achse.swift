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

    /// Die Spanne einer Werteachse: so eng wie möglich, so weit wie nötig.
    ///
    /// **Ohne Vorgabe nimmt Swift Charts die Null dazu.** Zehn Räume zwischen 18 und 21 Grad
    /// landen dann auf einer Achse von 0 bis 30, und die Kurven, auf die es ankommt,
    /// verschmelzen zu einem flachen Band im oberen Drittel. Bei Raumtemperaturen ist die
    /// Null keine Bezugsgröße – niemand fragt, ob ein Zimmer wärmer als Eis ist.
    ///
    /// `mindestens` verhindert das Gegenteil: ein Tag, an dem sich nichts rührt, bekäme sonst
    /// eine Achse über ein Zehntelgrad, auf der jedes Messrauschen wie ein Ereignis aussieht.
    public static func spanne(
        werte: [Double?], rand: Double = 1, mindestens: Double = 4
    ) -> ClosedRange<Double>? {
        let da = werte.compactMap { $0 }.filter { $0.isFinite }
        guard let klein = da.min(), let gross = da.max() else { return nil }
        var von = (klein - rand).rounded(.down)
        var bis = (gross + rand).rounded(.up)
        let fehlt = mindestens - (bis - von)
        if fehlt > 0 {
            von -= (fehlt / 2).rounded(.up)
            bis += (fehlt / 2).rounded(.up)
        }
        return von...bis
    }
}
