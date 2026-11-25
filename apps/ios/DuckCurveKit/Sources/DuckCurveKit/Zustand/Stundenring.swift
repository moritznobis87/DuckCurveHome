import Foundation

/// Die nächsten 24 Stunden stundenweise, für den Ring der „Uhr“ und für das Bild „Nächste 24
/// Stunden“ der Bühne. Gerechnet wird hier und im Dashboard in `stundenring.ts`, mit denselben
/// Prüfwerten in beiden Tests.
public enum Stundenring {

    public struct Stunde: Sendable, Equatable, Identifiable {
        /// Beginn der Stunde.
        public let start: Date
        /// Die Stunde des Tages, 0 bis 23.
        public let stunde: Int
        /// Der mittlere Preis der Stunde in ct; `nil`, solange es noch keinen gibt.
        public let preis: Double?
        /// Die erwartete Sonne im Mittel der Stunde.
        public let sonneKw: Double
        /// In dieser Stunde ist ein Lauf der Wärmepumpe geplant.
        public let wp: Bool
        /// Die Stunde liegt im Preistief.
        public let tief: Bool

        public var id: Date { start }
    }

    /// Höchstens 24 Stunden ab der laufenden, aus den Viertelstunden des Ausblicks.
    public static func stunden24(
        _ zellen: [Ausblick.Zelle], guenstig: Ausblick.Fenster?, kalender: Calendar = Kalender.haus
    ) -> [Stunde] {
        struct Summe {
            var start: Date
            var stunde: Int
            var preis = 0.0
            var preise = 0
            var sonne = 0.0
            var zellen = 0
            var wp = false
        }
        var summen: [Summe] = []
        for z in zellen {
            let teile = kalender.dateComponents([.year, .month, .day, .hour], from: z.zeit)
            guard let start = kalender.date(from: teile) else { continue }
            if summen.last?.start != start {
                if summen.count == 24 { break }
                summen.append(Summe(start: start, stunde: teile.hour ?? 0))
            }
            let i = summen.count - 1
            if let p = z.preis {
                summen[i].preis += p
                summen[i].preise += 1
            }
            summen[i].sonne += z.pv
            summen[i].zellen += 1
            if z.wp { summen[i].wp = true }
        }
        return summen.map { s in
            let ende = s.start.addingTimeInterval(3600)
            let tief = guenstig.map { s.start < $0.bis && ende > $0.von } ?? false
            return Stunde(
                start: s.start,
                stunde: s.stunde,
                preis: s.preise > 0 ? s.preis / Double(s.preise) : nil,
                sonneKw: s.zellen > 0 ? s.sonne / Double(s.zellen) : 0,
                wp: s.wp,
                tief: tief
            )
        }
    }

    /// Der Winkel einer Uhrzeit auf dem Ring im Bogenmaß: 00 Uhr steht oben, es geht im
    /// Uhrzeigersinn.
    public static func winkel(stunde: Double) -> Double {
        (stunde / 24) * 2 * Double.pi - Double.pi / 2
    }

    /// Wie lang die Speiche oder Säule eines Preises ist, von 0 bis 1. Gemessen wird am höchsten
    /// Preis des Tages, mindestens an 40 ct, damit ein ruhiger Tag nicht wie ein teurer aussieht.
    public static func preislaenge(_ preis: Double, hoechster: Double?) -> Double {
        max(0, min(1, preis / max(40, hoechster ?? 0)))
    }

    public struct Mass: Sendable, Equatable {
        public let mitteX: Double
        public let mitteY: Double
        /// Der äußere Radius; die Speichen beginnen bei `preis`, darunter liegen Sonne und
        /// Wärmepumpe.
        public let radius: Double
        public let preis: Double
        public let sonne: Double
        public let pumpe: Double
        public let zahl: Double
    }

    /// Die Maße des Rings aus der Breite und Höhe seiner Bühne. Am Fuß bleiben 26 Punkte für die
    /// Legende.
    public static func mass(breite: Double, hoehe: Double) -> Mass {
        let schmal = breite < 520
        let radius = max(40, min(schmal ? breite / 2 - 30 : 152, (hoehe - 26) / 2 - 16))
        return Mass(
            mitteX: breite / 2,
            mitteY: (hoehe - 26) / 2 + 2,
            radius: radius,
            preis: radius - 34,
            sonne: radius - 46,
            pumpe: radius - 58,
            zahl: radius - 74
        )
    }
}
