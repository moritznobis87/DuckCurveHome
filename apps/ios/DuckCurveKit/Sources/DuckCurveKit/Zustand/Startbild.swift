import Foundation

/// Die zwei Bilder für die Mitte der Startseite.
///
/// Der Hausherr hat am 25.11.2026 beide bauen lassen, mit einer Umschaltung auf „Einstellen“. Die
/// Wahl gilt je Gerät, so wie der Platz von Alfreds Ente: die Wand kann die Uhr zeigen und das
/// Telefon die Bühne. Das Dashboard führt dieselbe Liste in `startbild.ts`; die Wörter stehen in
/// beiden Tests.
public enum Startbild: String, CaseIterable, Sendable, Hashable, Identifiable {
    case buehne
    case uhr

    public var id: String { rawValue }

    public static let vorgabe: Startbild = .buehne
    /// Unter diesem Namen liegt die Wahl in `@AppStorage`; das Dashboard nimmt denselben.
    public static let merker = "dch-startbild"

    public static let titel = "Startseite"
    public static let frage = "Welches Bild die Mitte der Startseite auf diesem Gerät trägt."

    public var name: String {
        switch self {
        case .buehne: return "Die Bühne"
        case .uhr: return "Die Uhr"
        }
    }

    public var satz: String {
        switch self {
        case .buehne:
            return "Das Haus steht unter seinem Himmel, und der Strom fließt als leuchtendes Band."
        case .uhr:
            return
                "Ein Ring über 24 Stunden zeigt den Strompreis, die erwartete Sonne und die Läufe der Wärmepumpe."
        }
    }

    /// Was im Speicher steht, als Bild. Alles Unbekannte ist die Vorgabe.
    public static func aus(_ wert: String?) -> Startbild {
        wert.flatMap(Startbild.init(rawValue:)) ?? vorgabe
    }
}
