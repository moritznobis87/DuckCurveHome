import Foundation

/// Die Geometrie der Tagesuhr: reine Rechnungen, keine Zeichnung.
///
/// Getrennt von der Ansicht, weil hier die Fehler sitzen, die man einem Bild nicht ansieht: „ein
/// Ring, der um eine Viertelstunde verdreht ist, sieht genauso plausibel aus wie ein richtiger“
/// (`tagesuhr.ts:3-6`). Deshalb stehen diese Funktionen für sich und haben eigene Prüfungen - in
/// einer `View` wäre keine davon prüfbar, denn die übersetzt nur auf einem Mac.
///
/// **Der Winkel ist der Anteil am Tag, nicht die Uhrzeit** (`tagesuhr.ts:8-10`). Mitternacht
/// steht oben, der Tag läuft im Uhrzeigersinn einmal herum - auch an den beiden Umstellungstagen,
/// die 23 oder 25 Stunden haben. Aus der Uhrzeit gerechnet bliebe dort eine Stunde offen oder
/// läge doppelt.
public enum Tagesuhrgeometrie {

    /// Ein Punkt in den Koordinaten des Zifferblatts: x nach rechts, y nach unten.
    ///
    /// Eigener Typ und nicht `CGPoint`: der Kern baut und prüft auch unter Linux, und
    /// `CoreGraphics` gibt es dort nicht. Die Ansicht rechnet ihn in einer Zeile um.
    public struct Stelle: Sendable, Hashable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    // MARK: - Die Maße des Zifferblatts (`Tagesuhr.tsx:36-51`)

    /// Die Kantenlänge des gezeichneten Quadrats; die Ansicht skaliert es auf ihre Breite.
    public static let groesse: Double = 360
    /// Der Mittelpunkt in beiden Richtungen.
    public static let mitte: Double = 180

    /// Ein Ring: innerer und äußerer Radius.
    ///
    /// **Zwischen je zweien bleiben drei Punkte frei** (`Tagesuhr.tsx:38`): Flächen stoßen nicht
    /// aneinander, sonst liest sich der Übergang als Grenze einer Größe.
    public struct Ring: Sendable, Hashable {
        public let innen: Double
        public let aussen: Double

        public init(innen: Double, aussen: Double) {
            self.innen = innen
            self.aussen = aussen
        }
    }

    public static let ringPreis = Ring(innen: 144, aussen: 158)
    public static let ringSonne = Ring(innen: 126, aussen: 141)
    public static let ringGeplant = Ring(innen: 114, aussen: 123)
    public static let ringGelaufen = Ring(innen: 98, aussen: 111)
    public static let ringOfen = Ring(innen: 84, aussen: 95)

    /// Wo die Stundenstriche anfangen und wo sie enden - jeder sechste reicht weiter.
    public static let strichInnen: Double = 161
    public static let strichAussen: Double = 164
    public static let strichAussenStark: Double = 167
    /// Der Radius, auf dem 0, 6, 12 und 18 stehen.
    public static let zahlenradius: Double = 175

    /// Wie weit der Zeiger nach innen reicht - mit Ofenring kürzer, sonst länger
    /// (`Tagesuhr.tsx:220`).
    public static func zeigerInnen(mitOfen: Bool) -> Double { mitOfen ? 78 : 92 }
    /// Wie weit der Zeiger nach außen reicht.
    public static let zeigerAussen: Double = 160

    /// Die Trefferzone des Griffs, als Abstand vom Mittelpunkt.
    ///
    /// **Die Mitte gehört der Anzeige** (`Tagesuhr.tsx:208`): „Wer dort klickt, will lesen und
    /// nicht springen.“ Außen endet die Zone hinter den Stundenzahlen.
    public static let griffzone: ClosedRange<Double> = 70...178

    // MARK: - Anteil und Winkel

    /// Wo im Tag ein Zeitpunkt liegt, als Zahl von 0 (Beginn) bis 1 (Ende), darauf begrenzt.
    public static func anteil(_ t: Date, von: Date, bis: Date) -> Double {
        let spanne = bis.timeIntervalSince(von)
        guard spanne > 0 else { return 0 }
        let roh = t.timeIntervalSince(von) / spanne
        guard roh.isFinite else { return 0 }
        return min(1, max(0, roh))
    }

    /// Der Winkel zu einem Tagesanteil, in Bogenmaß: Anteil 0 liegt oben, es geht im
    /// Uhrzeigersinn.
    public static func winkel(anteil: Double) -> Double {
        anteil * 2 * Double.pi - Double.pi / 2
    }

    /// Ein Punkt auf dem Kreis um den Mittelpunkt des Zifferblatts.
    public static func punkt(r: Double, anteil a: Double) -> Stelle {
        let w = winkel(anteil: a)
        return Stelle(x: mitte + r * cos(w), y: mitte + r * sin(w))
    }

    /// Der Tagesanteil unter einem Zeiger, aus Punkten relativ zur Mitte der Uhr.
    ///
    /// `dx` nach rechts, `dy` nach unten, wie auf dem Schirm. Oben ist 0, rechts ein Viertel.
    public static func anteilAus(dx: Double, dy: Double) -> Double {
        let w = atan2(dy, dx) + Double.pi / 2
        let a = w / (2 * Double.pi)
        return a < 0 ? a + 1 : a
    }

    /// Ob eine Stelle relativ zur Mitte im Griff liegt.
    public static func imGriff(dx: Double, dy: Double) -> Bool {
        let abstand = (dx * dx + dy * dy).squareRoot()
        return griffzone.contains(abstand)
    }

    // MARK: - Ringstücke

    /// In welche Bögen ein Ringstück zerfällt, als Paare von Tagesanteilen.
    ///
    /// **Ein voller Ring wird in zwei Hälften geteilt** (`tagesuhr.ts:37-42`): „ein einzelner
    /// Bogen von einem Punkt zu demselben Punkt hat für SVG die Länge null“. Dieselbe Teilung
    /// bleibt hier, obwohl `Path.addArc` sie nicht bräuchte - sie kostet nichts, und zwei
    /// Oberflächen, die denselben Ring verschieden zerlegen, lassen sich nicht vergleichen.
    ///
    /// Eine Spanne von null oder weniger ergibt nichts: ein Lauf ohne Dauer ist kein Stück
    /// Ring, und ein gezeichneter Nullbogen wäre ein Strich quer über die Scheibe.
    public static func bogenstuecke(von a0: Double, bis a1: Double) -> [(von: Double, bis: Double)]
    {
        let spanne = a1 - a0
        guard spanne.isFinite, spanne > 0 else { return [] }
        if spanne >= 0.9999 {
            let mitte = a0 + spanne / 2
            return [(a0, mitte), (mitte, a0 + 0.9999)]
        }
        return [(a0, a1)]
    }

    /// Das Bild, dessen Zeit einem Tagesanteil am nächsten liegt. `nil` ohne Bilder.
    ///
    /// Nachgesehen und nicht gerechnet: `frames` ist nicht notwendig gleichmässig
    /// (`schemas.py:1832-1835`), und eine Rechnung aus Anteil mal Anzahl zeigte an einem Tag mit
    /// fehlendem Vormittag etwas anderes als die Stelle, auf die gegriffen wurde.
    public static func indexBei(anteil a: Double, zeiten: [Date], von: Date, bis: Date) -> Int? {
        guard !zeiten.isEmpty else { return nil }
        let ziel = von.addingTimeInterval(a * bis.timeIntervalSince(von))
        var beste = 0
        var abstand = Double.infinity
        for (i, t) in zeiten.enumerated() {
            let d = abs(t.timeIntervalSince(ziel))
            if d < abstand {
                abstand = d
                beste = i
            }
        }
        return beste
    }
}
