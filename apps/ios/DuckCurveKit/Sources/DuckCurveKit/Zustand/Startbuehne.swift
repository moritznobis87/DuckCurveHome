import Foundation

/// Die Rechnung der Bühne: wo die Sonne steht, wo die Sachen stehen und wie breit ein Band ist.
///
/// Gezeichnet wird in `Buehnenbild.swift` und im Dashboard in `Buehne.tsx`; gerechnet wird hier
/// und im Dashboard in `buehne.ts`, mit denselben Prüfwerten in beiden Tests.
public enum Startbuehne {

    /// Ab dieser Leistung fließt etwas; darunter ist ein Band nur eine gestrichelte Linie.
    public static let flussAbKw = 0.05

    /// Wie breit ein Band bei dieser Leistung ist, in Punkten.
    public static func bandbreite(_ kw: Double) -> Double {
        min(30, 5 + 4.5 * max(0, kw))
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
