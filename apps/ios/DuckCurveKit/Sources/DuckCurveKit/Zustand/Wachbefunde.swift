import Foundation

/// Die Wache der Startseite: welche Befunde dastehen, in welcher Reihenfolge und in welchem Ton.
///
/// **Warum die Auswahl im Kern steht und nicht in der Zeile, die sie zeichnet.** Die Vorlage
/// nimmt genau zwei Befunde (`Wache.tsx:30`: `befunde.slice(0, 2)`) und begründet das nicht aus
/// der Darstellung, sondern aus der Sortierung des Dienstes (`Wache.tsx:21-24`: „Der Dienst
/// sortiert: Alarm vor Warnung, bei gleicher Schwere der ältere“). Welche zwei von fünf Befunden
/// jemand im Vorbeigehen liest, ist damit eine Entscheidung über Inhalt und nicht über Form -
/// und sie gehört an eine Stelle, an der sie geprüft werden kann. Dieselbe Begründung trägt
/// ``Ruhebild/schwersterBefund(_:)``, die aus der Wache den einen Satz des Ruhebilds nimmt.
///
/// **Die Zwei ist keine Geschmacksfrage.** An der Wand rollt nichts (`JetztSeite.swift`, die
/// Spalte ohne Rollbereich): eine Wache mit fünf Zeilen schiebt Kurve und Fuß aus dem Bild, und
/// was dort unten abgeschnitten wird, ist weg - nicht weggerollt.
///
/// **Der Ton gehört dazu.** `globals.css:205-207` färbt Kante, Grund und Zeichen nach der
/// Schwere: `--alert` auf 10 % `--alert` beim Alarm, `--amber-soft` auf 10 % `--amber-soft` bei
/// einer Warnung. Das ist dieselbe Zuordnung wie die Auswahl - eine Rechnung über dem Befund -
/// und steht deshalb hier und nicht in der `View`.
public enum Wachbefunde {

    /// Wie viele Zeilen höchstens dastehen (`Wache.tsx:30`).
    public static let hoechstens = 2

    /// Die Schwere eines Befunds, auf die drei Fälle des Dienstes gebracht.
    public enum Schwere: Sendable, Hashable {
        case alarm
        case warnung
        /// Eine Schwere, die dieser Fassung unbekannt ist. `Schema.swift` lässt sie ausdrücklich
        /// zu, damit eine neue Stufe im Dienst die App nicht zum Absturz bringt.
        case unbekannt

        /// Kante, Zeichen und Grund dieser Zeile.
        ///
        /// Die unbekannte Schwere nimmt ``Marken/mist`` - die Farbe, mit der die App überall
        /// sagt „das ist eine Auskunft und keine Warnung“. Die Vorlage hat den Fall nicht: ihr
        /// CSS fällt auf `--alert` zurück, und ein roter Balken für eine Stufe, die niemand
        /// kennt, wäre eine Warnung, für die es keinen Grund gibt.
        public var farbe: Farbwert {
            switch self {
            case .alarm: return Marken.alarm
            case .warnung: return Marken.amberWeich
            case .unbekannt: return Marken.mist
            }
        }

        /// Der Grund der Zeile: dieselbe Farbe auf 10 % (`globals.css:205-206`).
        public var grundfarbe: Farbwert {
            farbe.mitDeckung(0.10)
        }
    }

    /// Eine Zeile der Wache - fertig zum Zeichnen.
    public struct Zeile: Sendable, Hashable, Identifiable {
        /// Die Kennung des Dienstes; in der Vorlage der Schlüssel der Liste (`Wache.tsx:31`).
        public let name: String
        /// Der ganze Satz aus dem Dienst (`text_de`).
        ///
        /// **Er wird nicht gekürzt und nicht umgeschrieben.** `Wache.tsx:14-18` nennt den Grund:
        /// „Die Puffertemperaturen seit 2 Tagen still“ ist eine Beobachtung; erst „ohne sie gibt
        /// es keinen Ladezustand“ sagt, warum es einen stören soll.
        public let satz: String
        public let schwere: Schwere

        public var id: String { name }

        public init(name: String, satz: String, schwere: Schwere) {
            self.name = name
            self.satz = satz
            self.schwere = schwere
        }
    }

    /// Die ersten Zeilen der Wache: begrenzt und eingefärbt, in der Reihenfolge des Dienstes.
    ///
    /// **Hier wird nicht sortiert, und das ist eine Entscheidung.** Der Dienst sortiert schon:
    /// „Alarm vor Warnung, bei gleicher Schwere der ältere“ (`Wache.tsx:21-24`). Die Vorlage
    /// schneidet darum nur ab (`:30`: `slice(0, 2)`), und ``Ruhebild/schwersterBefund(_:)``
    /// nimmt aus demselben Grund den ersten und nicht den lautesten: dieselbe Reihenfolge ein
    /// zweites Mal zu behaupten heißt, zwei Wahrheiten darüber zu haben, welcher Befund der
    /// schwerere ist - und die zweite steht dann in einer App, die der Dienst nicht kennt.
    public static func zeilen(
        _ befunde: [WatchFindingOut], hoechstens: Int = Wachbefunde.hoechstens
    ) -> [Zeile] {
        guard hoechstens > 0 else { return [] }
        return befunde.prefix(hoechstens).map { b in
            Zeile(name: b.name, satz: b.textDe, schwere: schwere(b.severity))
        }
    }

    /// Die Schwere des Dienstes in die der Oberfläche.
    public static func schwere(_ wahl: WatchFindingOutSeverityWahl) -> Schwere {
        switch wahl {
        case .alarm: return .alarm
        case .warn: return .warnung
        case .unbekannt: return .unbekannt
        }
    }
}
