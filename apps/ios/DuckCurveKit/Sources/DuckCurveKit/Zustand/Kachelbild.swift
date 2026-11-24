import Foundation

/// Was das kleine Bild einer Kachel der Übersicht rechnet, bevor es zeichnet.
///
/// Übersetzt aus `apps/web/src/components/layout/Kachelbild.tsx` (`balkenhoehen`, `laeufe`),
/// mit denselben Zahlen. Es steht im Kern und nicht in der Ansicht, damit sich auf dem
/// Prüfrechner festhalten lässt, dass Dashboard und App dieselben Balken zeichnen.
///
/// Das Bild trägt keine Zahl, die nicht auch als Leitzahl dasteht.
public enum Kachelbild {
    /// So viele Plätze hat der Tag. Eine Stunde, die noch nicht war, bleibt ein leerer Platz.
    public static let stunden = 24

    /// Die Balken eines Tages als Höhen von 0 bis 1, immer ``stunden`` Plätze. Die größte Stunde
    /// ist 1; `nil` heißt, die Stunde war noch nicht. Ohne einen einzigen Wert über null bleiben
    /// alle 0.
    public static func balkenhoehen(_ werte: [Double]) -> [Double?] {
        let gross = max(0, werte.max() ?? 0)
        return (0..<stunden).map { i in
            guard i < werte.count else { return nil }
            return gross > 0 ? max(0, werte[i]) / gross : 0
        }
    }

    /// Ein zusammenhängender Abschnitt eines Streifens, als Anfang und Ende zwischen 0 und 1.
    public struct Lauf: Sendable, Hashable {
        public let von: Double
        public let bis: Double

        public init(von: Double, bis: Double) {
            self.von = von
            self.bis = bis
        }
    }

    /// Die Läufe eines Streifens: zusammenhängende Abschnitte mit einem Wert über null.
    public static func laeufe(_ werte: [Double]) -> [Lauf] {
        var aus: [Lauf] = []
        let n = werte.count
        guard n > 0 else { return [] }
        var anfang: Int?
        for i in 0...n {
            let an = i < n && werte[i] > 0
            if an, anfang == nil { anfang = i }
            if !an, let a = anfang {
                aus.append(Lauf(von: Double(a) / Double(n), bis: Double(i) / Double(n)))
                anfang = nil
            }
        }
        return aus
    }

    /// Ein Anteil, auf seinen Bereich beschnitten: 0 bis 1 für einen Füllstand, -1 bis 1 für
    /// eine Abweichung. Ein Messwert knapp darüber soll nichts zeichnen, was über den Rand ragt.
    public static func beschnitten(_ anteil: Double, unten: Double = 0) -> Double {
        min(1, max(unten, anteil))
    }
}
