import Foundation

/// Eine Raumkachel, vorgerechnet: Zahlen, Abzeichen, Kurve, Ventilstreifen.
///
/// **Warum das nicht in der Ansicht steht.** Die Kachel ist die dichteste Stelle der App – vier
/// Zahlen, ein Abzeichen, eine Kurve mit Lücken und ein Streifen aus 24 Feldern, und jedes davon
/// hat einen Fall „kein Messwert" und einen Fall „noch nicht gewesen". In SwiftUI geschrieben
/// wäre das eine Ansicht, die niemand prüfen kann; hier ist jeder Fall ein Test.
///
/// Dieselben Regeln wie `apps/web/src/components/rooms/RoomsReport.tsx`.
public enum Raumkarte {

    // MARK: - Der Ventilstreifen

    /// Ein Feld des Streifens: ein Anteil, keine Messung, oder noch nicht gewesen.
    public typealias Feld = Raumabweichung.Feld

    /// Die Ventilstellungen auf **Stunden verdichtet**.
    ///
    /// **Warum nicht je Viertelstunde.** In einer Kachel von 160 Punkten Breite sind 96 Fenster
    /// anderthalb Punkte breit, und das ergab einen gesprenkelten Streifen, in dem nichts mehr zu
    /// erkennen war. 24 Felder sagen dasselbe und sind zu lesen.
    ///
    /// Ein Feld, in dem kein Fenster gemessen wurde, ist `keinWert`; eines, das ganz hinter
    /// `gewesen` liegt, ist `nochNicht`. **Ein angebrochenes Feld zählt als gewesen**: die
    /// laufende Stunde ist zur Hälfte Messung, und sie zu schraffieren hieße, die letzte
    /// Auskunft des Tages wegzunehmen.
    public static func ventilstunden(
        _ werte: [Double?], proStunde: Int, gewesen: Int? = nil
    ) -> [Feld] {
        guard proStunde > 0, !werte.isEmpty else { return [] }
        let grenze = gewesen ?? werte.count
        let zahl = Int(ceil(Double(werte.count) / Double(proStunde)))
        return (0..<zahl).map { h in
            let von = h * proStunde
            if von >= grenze { return .nochNicht }
            let bis = min(von + proStunde, werte.count)
            let teil = werte[von..<bis].enumerated()
                .filter { von + $0.offset < grenze }
                .compactMap { $0.element }
            guard !teil.isEmpty else { return .keinWert }
            return .wert(teil.reduce(0, +) / Double(teil.count))
        }
    }

    // MARK: - Die Kurve

    /// Ein Punkt der Kurve in Einheitskoordinaten: `x` von 0 bis 1 über den Tag, `y` von 0 bis 1
    /// von oben nach unten, mit dem Zielwert auf 0,5.
    public struct Punkt: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// Die Kurve eines Raums über den Tag, in Stücken.
    public struct Kurve: Equatable, Sendable {
        /// Die halbe Spanne der Achse in Kelvin – mindestens 2.
        public let spanne: Double
        /// Zusammenhängende Stücke. **Eine durchgezogene Linie über eine Lücke wäre eine
        /// Behauptung über Minuten, in denen nichts gemessen wurde.**
        public let stuecke: [[Punkt]]
    }

    /// Die Kurve aus den Abweichungsfeldern eines Tages.
    ///
    /// **Gleiche Grad je Punkt in allen Kacheln.** Jede Kurve auf ihre eigene Spanne zu dehnen
    /// hätte aus 0,2 K Rauschen im einen Raum dasselbe Bild gemacht wie aus 2 K Unterdeckung im
    /// anderen. Die Spanne ist deshalb fest – ±2 K um den Zielwert – und wächst nur, wenn ein
    /// Raum darüber hinausgeht; dann steht sie an der Achse.
    ///
    /// Ein Stück aus einem einzigen Punkt fällt weg: eine Linie von einem Punkt nach nirgendwo
    /// ist nichts, was man zeichnen könnte.
    public static func kurve(_ felder: [Feld]) -> Kurve {
        var spanne = 2.0
        for f in felder {
            if case .wert(let k) = f { spanne = max(spanne, abs(k).rounded(.up)) }
        }
        var stuecke: [[Punkt]] = []
        var lauf: [Punkt] = []
        let letzte = max(1, felder.count - 1)
        for (i, f) in felder.enumerated() {
            guard case .wert(let k) = f else {
                if lauf.count > 1 { stuecke.append(lauf) }
                lauf = []
                continue
            }
            // Der Rand bleibt frei: eine Kurve, die die Oberkante berührt, sieht abgeschnitten
            // aus, auch wenn sie es nicht ist.
            let y = 0.5 - (k / spanne) * 0.46
            lauf.append(Punkt(x: Double(i) / Double(letzte), y: y))
        }
        if lauf.count > 1 { stuecke.append(lauf) }
        return Kurve(spanne: spanne, stuecke: stuecke)
    }

    // MARK: - Die Diagnose

    /// **An der Grenze**: die Kreise standen fast den ganzen Tag offen, und der Raum ist trotzdem
    /// zu kalt. Dann ist nicht die Einzelraumregelung am Zug, sondern die Vorlauftemperatur –
    /// dieser Raum bestimmt sie für alle anderen mit.
    ///
    /// **Ein offenes Fenster nimmt die Anklage zurück.** Ohne die Kontakte sah ein gelüfteter
    /// Raum genauso aus wie einer, für den die Vorlauftemperatur nicht reicht – und die Seite
    /// schob es auf die Heizkurve.
    public static func anDerGrenze(
        tagesventil: Double?, abweichung: Double?, fensterOffen: Bool
    ) -> Bool {
        guard !fensterOffen, let v = tagesventil, let k = abweichung else { return false }
        return v >= 0.85 && k < -Raumabweichung.band
    }

    /// Das Mittel über die Felder, die einen Wert haben – für „Ventil am Tag".
    public static func mittel(_ felder: [Feld]) -> Double? {
        Raumabweichung.mittel(felder)
    }

    /// Der letzte Platz der Zeitachse, der schon gewesen ist – oder `nil`, wenn keiner.
    ///
    /// Am laufenden Tag steht hinter der Gegenwart noch nichts, und „wie lange steht das Fenster
    /// schon offen" muss von dort rückwärts zählen, nicht vom Ende der Reihe.
    public static func letzterPlatz(_ gewesen: Int?, laenge: Int) -> Int? {
        let g = gewesen ?? laenge
        let i = min(g, laenge) - 1
        return i >= 0 ? i : nil
    }
}
