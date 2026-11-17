import Foundation

/// Werte des Dienstes als deutsche Wörter.
///
/// **Warum das im Kern steht und nicht in der Oberfläche.** Es ist Logik mit genau einer
/// richtigen Antwort je Eingabe – also prüfbar, und zwar hier auf jedem Rechner. In einer
/// SwiftUI-Datei wäre dasselbe nur auf einem Mac übersetzbar und gar nicht getestet. Dazu
/// kommt ein zweiter Grund, der sich erst beim Bauen gezeigt hat: eine Hilfsfunktion, die als
/// `private func` in einer Ansicht liegt, ist aus der Nachbaransicht nicht erreichbar. Genau
/// daran ist `wertAlsText` gescheitert, nachdem es eine zweite Stelle brauchte.
extension ReglerEinstellungOut {
    /// Einen Wert dieser Einstellung als Text, so wie der Regler ihn meint.
    ///
    /// Drei Formen: eine Auswahl (dann steht das Wort dazu in `wahl`), eine Zahl mit Einheit,
    /// oder eine nackte Zahl. Fehlt der Wert, steht der Strich.
    public func wertAlsText(_ zahl: Double?) -> String {
        guard let zahl else { return Formate.leer }
        if let wort = wahl[String(Int(zahl))] { return wort }
        let text = Formate.zahl(zahl, stellen: stellen ?? 1)
        return einheit.map { "\(text)\(Formate.schmalesLeerzeichen)\($0)" } ?? text
    }
}

extension CyclingStatsVerdictWahl {
    /// Die Einordnung der Taktung als Wort.
    ///
    /// Wortgleich mit dem Dashboard (`reports/HeatOverview.tsx`, `TAKTUNG`) und bewusst
    /// zurückhaltend: das ist ein Hinweis und keine Diagnose. Eine Wärmepumpe, die häufig
    /// taktet, kann dafür gute Gründe haben.
    public var wort: String {
        switch self {
        case .ok: return "unauffällig"
        case .watch: return "grenzwertig"
        case .shortCycling: return "taktet häufig"
        case .unknown, .unbekannt: return "zu wenig Daten"
        }
    }
}
