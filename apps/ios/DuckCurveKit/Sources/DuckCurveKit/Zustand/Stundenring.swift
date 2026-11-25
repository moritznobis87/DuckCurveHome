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
        /// In dieser Stunde soll der Pelletofen brennen.
        public let ofen: Bool
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
            var ofen = false
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
            if z.ofen { summen[i].ofen = true }
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
                ofen: s.ofen,
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

// MARK: - Zeitspannen und Preislage

extension Stundenring {

    /// Eine Zeitspanne der nächsten 24 Stunden: das Preistief, die beste Sonnenzeit oder der
    /// nächste geplante Lauf. Sie stehen als Uhrzeiten da, wo früher Sätze standen.
    public struct Zeitspanne: Sendable, Equatable, Identifiable {
        public enum Art: String, Sendable, Hashable {
            case preistief, sonne, waermepumpe, ofen
        }

        public let art: Art
        public let von: Date
        public let bis: Date

        public var id: String { art.rawValue }

        public var wort: String {
            switch art {
            case .preistief: return "Preistief"
            case .sonne: return "Beste Sonne"
            case .waermepumpe: return "Wärmepumpe"
            case .ofen: return "Pelletofen"
            }
        }

        /// „13:00–15:00“
        public var text: String { "\(Formate.hhmm(von))–\(Formate.hhmm(bis))" }
    }

    /// Die Zeitspannen eines Ausblicks, in fester Reihenfolge. Was der Fahrplan nicht kennt, fehlt.
    public static func zeitspannen(_ a: Ausblick) -> [Zeitspanne] {
        var out: [Zeitspanne] = []
        if let g = a.guenstig { out.append(Zeitspanne(art: .preistief, von: g.von, bis: g.bis)) }
        if let s = a.sonne { out.append(Zeitspanne(art: .sonne, von: s.von, bis: s.bis)) }
        func erster(_ abschnitte: [Range<Int>], _ art: Zeitspanne.Art) {
            guard let r = abschnitte.first, r.lowerBound < a.zellen.count, r.upperBound >= 1 else { return }
            let ende = a.zellen[min(r.upperBound, a.zellen.count) - 1].zeit.addingTimeInterval(Ausblick.schritt)
            out.append(Zeitspanne(art: art, von: a.zellen[r.lowerBound].zeit, bis: ende))
        }
        erster(a.laeufe, .waermepumpe)
        erster(a.braende, .ofen)
        return out
    }
}

extension Ausblick.Preislage {
    /// Die Lage des Preises als ein Wort für die Marke neben der Zahl.
    public var wort: String {
        switch self {
        case .guenstig: return "günstig"
        case .mittel: return "mittel"
        case .teuer: return "teuer"
        case .gleichmaessig: return "gleichmäßig"
        }
    }
}
