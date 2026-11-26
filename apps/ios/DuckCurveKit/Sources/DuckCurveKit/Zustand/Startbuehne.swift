import Foundation

/// Die Rechnung der Bühne: wo die Sonne steht, wo die Sachen stehen und wie breit ein Band ist.
///
/// Gezeichnet wird in `Buehnenbild.swift` und im Dashboard in `Buehne.tsx`; gerechnet wird hier
/// und im Dashboard in `buehne.ts`, mit denselben Prüfwerten in beiden Tests.
public enum Startbuehne {

    /// Ab dieser Leistung fließt etwas; darunter ist ein Band nur eine gestrichelte Linie.
    public static let flussAbKw = 0.05

    /// Wie breit ein Band bei dieser Leistung ist, in Punkten.
    ///
    /// **Mit der Wurzel, nicht geradeaus, und höchstens 16 Punkte.** Bis zum 25.11.2026 wuchs das
    /// Band mit 4,5 Punkten je Kilowatt bis 30 Punkte. Im Haus zieht die Wärmepumpe über 8 kW:
    /// Kabel und Rohr füllten den ganzen Boden unter dem Haus, und das Kabel ragte in den Mast
    /// (Bild des Hausherrn vom 25.11.2026). Mit der Wurzel bleibt ein Kilowatt gut von vier zu
    /// unterscheiden, und neun sind immer noch ein Band und kein Balken.
    public static func bandbreite(_ kw: Double) -> Double {
        min(16, 4 + 4 * max(0, kw).squareRoot())
    }

    /// Wie weit die runde Kappe eines Bandes über sein Ende hinausragt: die halbe Breite. Ein
    /// Kabel, das an einer Sache beginnt, setzt um so viel tiefer an, damit die Kappe sie nicht
    /// überdeckt.
    public static func bandkappe(_ kw: Double) -> Double {
        kw < flussAbKw ? 1 : bandbreite(kw) / 2
    }

    /// Wie weit die Sonne auf ihrem Bogen ist: 0 beim Aufgang, 1 beim Untergang. `nil` heißt: sie
    /// steht nicht am Himmel oder der Fahrplan kennt den Tag nicht.
    public static func sonnenanteil(von: Date?, bis: Date?, jetzt: Date) -> Double? {
        guard let von, let bis, bis > von, jetzt >= von, jetzt <= bis else { return nil }
        return jetzt.timeIntervalSince(von) / bis.timeIntervalSince(von)
    }

    public static func sonnenanteil(_ lauf: Ruhebild.Sonnenlauf?, jetzt: Date) -> Double? {
        sonnenanteil(von: lauf?.von, bis: lauf?.bis, jetzt: jetzt)
    }

    // MARK: - Die Kraft der Sonne

    /// Bei dieser Erzeugung steht die Sonne in voller Kraft im Bild.
    ///
    /// Eine feste Zahl wie bei den Bändern: die Oberfläche kennt die Größe der Anlage nicht. Acht
    /// Kilowatt sind ein voller Sommermittag dieses Hauses; ein klarer Wintermittag bleibt
    /// darunter und soll im Bild auch so aussehen.
    public static let volleSonneKw = 8.0

    /// Wie kräftig die Sonne wirkt, von 0 bis 1.
    ///
    /// Mit der Wurzel der Erzeugung, wie die Breite der Bänder: ein halbes Kilowatt ist ein
    /// Viertel der Kraft und zwei Kilowatt die Hälfte. Geradeaus wäre die Sonne an jedem
    /// Wintertag ein Punkt.
    public static func sonnenkraft(_ kw: Double) -> Double {
        min(1, (max(0, kw) / volleSonneKw).squareRoot())
    }

    /// Wie die Sonne gezeichnet wird. Alle Längen in Punkten, alle Deckungen von 0 bis 1.
    public struct Sonnenbild: Sendable, Equatable {
        /// Die Scheibe: ihr Halbmesser und wie viel Bernstein auf dem blassen Grund liegt.
        public let radius: Double
        public let deckung: Double
        /// Wie weit die Scheibe leuchtet.
        public let glanz: Double
        /// Der weiche Schein um die Scheibe: sein Halbmesser und seine Deckung in der Mitte.
        public let schein: Double
        public let scheinDeckung: Double
        /// Der Strahlenkranz: Länge der langen Strahlen und ihre Deckung. Bei 0 gibt es keinen.
        public let strahl: Double
        public let strahlDeckung: Double
        /// Wie deckend der Lichtkegel zum Dach ist, als Anteil seiner vollen Deckung.
        public let kegel: Double
        /// Wie stark der warme Schein des Himmels in der Ecke ist.
        public let himmel: Double
    }

    /// So deckend liegt das blasse Weiß unter dem Bernstein der Scheibe. Eine schwache Sonne wird
    /// damit hell und fahl wie hinter Dunst; nur mit dem dunklen Himmel gemischt wurde sie oliv.
    public static let scheibeBlass = 0.6
    /// Ab diesem Anteil der Kraft trägt die Sonne Strahlen.
    public static let strahlenAb = 0.3
    /// So viele Strahlen hat der Kranz; jeder zweite ist kürzer.
    public static let strahlen = 12

    /// Die Sonne nach ihrer Erzeugung: bei wenig klein und blass, bei viel groß und strahlend
    /// (Hausherr am 26.11.2026). Vorher war sie immer gleich groß, und ein trüber Morgen mit
    /// 0,1 kW sah aus wie ein Sommermittag.
    public static func sonnenbild(_ kw: Double, schmal: Bool) -> Sonnenbild {
        let k = sonnenkraft(kw)
        func zwischen(_ wenig: Double, _ viel: Double) -> Double { wenig + (viel - wenig) * k }
        let radius = schmal ? zwischen(6, 18) : zwischen(7, 22)
        let kranz = max(0, (k - strahlenAb) / (1 - strahlenAb))
        return Sonnenbild(
            radius: radius,
            deckung: zwischen(0.45, 1),
            glanz: zwischen(0, 22),
            schein: radius * zwischen(2.4, schmal ? 5.2 : 6),
            scheinDeckung: zwischen(0.14, 0.6),
            strahl: kranz * (schmal ? 12 : 16),
            strahlDeckung: kranz * 0.85,
            kegel: zwischen(0.4, 1),
            himmel: zwischen(0.06, 0.26))
    }

    // MARK: - Die Maße

    public struct Mass: Sendable, Equatable {
        /// Das Telefon: Wallbox und Wärmepumpe stehen dann als Kacheln unter der Bühne.
        public let schmal: Bool
        /// Die Höhe des Bodens und die Mitte des Hauses.
        public let boden: Double
        public let mitte: Double
        public let hausHalb: Double
        public let hausHoch: Double
        public let dach: Double
        public let ueber: Double
        /// Der Sonnenbogen: Abstand vom Rand und die beiden Halbachsen.
        public let bogenRand: Double
        public let rx: Double
        public let ry: Double
        public let netzX: Double
        public let wallboxX: Double
        public let speicherX: Double
        public let pumpeX: Double
        /// So tief liegen Kabel und Rohr unter der Erde.
        public let tief: Double
        /// Die Grundlinie der Zahlen über den Sachen.
        public let schildY: Double
    }

    /// Die Maße der Bühne aus ihrer Breite und Höhe. Unter 520 Punkten ist sie schmal.
    public static func mass(breite: Double, hoehe: Double) -> Mass {
        let schmal = breite < 520
        let boden = hoehe - (schmal ? 54 : 60)
        let rand: Double = schmal ? 22 : 36
        return Mass(
            schmal: schmal,
            boden: boden,
            mitte: breite / 2,
            hausHalb: schmal ? 60 : min(88, breite * 0.105),
            hausHoch: schmal ? 76 : 84,
            dach: schmal ? 50 : 62,
            ueber: schmal ? 13 : 18,
            bogenRand: rand,
            rx: (breite - 2 * rand) / 2,
            ry: boden - (schmal ? 64 : 40),
            netzX: schmal ? 40 : max(70, breite * 0.1),
            wallboxX: breite * 0.285,
            speicherX: schmal ? breite - 42 : breite * 0.715,
            pumpeX: breite * 0.89,
            tief: boden + (schmal ? 26 : 30),
            schildY: boden - 96
        )
    }

    public struct Ort: Sendable, Equatable {
        public let x: Double
        public let y: Double
    }

    /// Wo die Sonne auf dem Bogen steht.
    public static func sonnenort(_ m: Mass, anteil: Double) -> Ort {
        let a = Double.pi * max(0, min(1, anteil))
        return Ort(x: m.mitte - m.rx * cos(a), y: m.boden - m.ry * sin(a))
    }
}
