import Foundation

/// Die Worte der Seite „Mein Zugang“, im Wortlaut des Dashboards
/// (`apps/web/src/components/zugang/kontoworte.ts`).
///
/// Seit dem 24.11.2026 trägt die Seite in beiden dieselbe Kopfkarte (Anfangsbuchstabe, Rolle als
/// Marke, drei Zahlen) und je eine Karte für Passkeys, Passwort und Sitzungen mit ihrem Zeichen.
public enum Kontoworte {
    /// Wie eine Rolle auf dieser Seite heißt, und was sie darf.
    public static func rolle(_ rolle: String) -> (name: String, satz: String) {
        switch rolle {
        case "hausherr": return ("Hausherr", "Sieht alles und darf alles einstellen.")
        case "bewohner": return ("Bewohner", "Sieht das Haus und darf dort stellen.")
        case "service": return ("Beratung", "Sieht zu und stellt nichts.")
        case "gast": return ("Gast", "Sieht zu und stellt nichts.")
        default: return (rolle, "")
        }
    }

    /// Eine der drei Karten: Zeichen, Titel und der Satz darunter.
    public enum Kartenart: String, Sendable, CaseIterable {
        case passkeys, passwort, sitzungen
        /// Die Karten von „Zugang und Sicherung“, soweit die App sie zeigt.
        case platz, sicherung

        public var zeichen: Zeichenart {
            switch self {
            case .passkeys: return .schluessel
            case .passwort: return .schloss
            case .sitzungen: return .geraet
            case .platz: return .diagramm
            case .sicherung: return .kalender
            }
        }

        public var titel: String {
            switch self {
            case .passkeys: return "Passkeys"
            case .passwort: return "Passwort"
            case .sitzungen: return "Sitzungen"
            case .platz: return "Platzbedarf"
            case .sicherung: return "Sicherung"
            }
        }

        public var satz: String {
            switch self {
            case .passkeys: return "Anmelden mit Gesicht oder Finger, ohne Passwort."
            case .passwort: return "Der zweite Weg herein, an jedem Gerät."
            case .sitzungen: return "Wo du gerade angemeldet bist."
            case .platz: return "Wie groß die Datenbank ist, Tabelle für Tabelle."
            case .sicherung: return "Einmal im Jahr herunterladen und woanders ablegen."
            }
        }
    }

    public static let zahlPasskeys = "Passkeys"
    public static let zahlSitzungen = "Sitzungen"
    public static let zahlCodes = "Codes übrig"
    public static let gesichert = "in der Wolke gesichert"
    public static let nurHier = "nur auf diesem Gerät"
    public static let diesesGeraet = "dieses Gerät"
    public static let rueckweg =
        "Zwei Passkeys auf zwei Geräten sind der beste Rückweg. Ein in der Wolke gesicherter Passkey "
        + "(iCloud-Schlüsselbund, Google-Passwortmanager) liegt ohnehin auf mehreren."
    /// Was die App noch nicht kann: einen Passkey anlegen. Dafür fehlt ihr die Zuordnung zur
    /// Adresse des Dashboards (`docs/GLEICHSTAND.md`).
    public static let anlegenImDashboard = "Einen neuen Passkey legst du im Dashboard an."
    public static let neueCodes = "Neue Wiederherstellungscodes"
    public static let codesTitel = "Zehn neue Codes ersetzen die alten"
    public static let codesNurJetzt = "Sie stehen nur jetzt hier."
    /// Die Rückfrage vor dem Löschen eines Passkeys, mit seinem Namen (`kontoworte.ts`,
    /// `loeschfrage`). Das Dashboard stellt sie am Knopf, die App in einem Blatt.
    public static func loeschfrage(_ name: String) -> String { "„\(name)“ löschen?" }
    public static let umbenennen = "umbenennen"
    public static let loeschen = "löschen"
    public static let letzterBleibt = "der letzte bleibt"
    public static let beenden = "beenden"
    public static let ueberallAbmelden = "Überall abmelden"
    public static let ueberallFrage = "Überall abmelden, auch hier?"
    public static let nichtGeklappt = "Das hat nicht geklappt."

    /// Aus dem User-Agent ein Wort, an dem man das Gerät wiedererkennt (`MeinZugang.tsx`,
    /// `geraet`).
    public static func geraet(_ ua: String?) -> String {
        guard let ua, !ua.isEmpty else { return "unbekanntes Gerät" }
        for (muster, wort) in [
            ("iPad", "iPad"), ("iPhone", "iPhone"), ("Android", "Android"), ("Macintosh", "Mac"),
            ("Windows", "Windows"), ("Linux", "Linux"),
        ] where ua.range(of: muster, options: .caseInsensitive) != nil {
            return wort
        }
        return "unbekanntes Gerät"
    }

    /// „24.11.26, 22:50“ in der Zeit des Hauses, oder „nie“ (`MeinZugang.tsx`, `datum`).
    public static func datum(_ iso: String?) -> String {
        guard let iso, let d = Zeit.ausIso(iso) else { return "nie" }
        let t = Kalender.haus.dateComponents([.day, .month, .year], from: d)
        return String(format: "%02d.%02d.%02d, ", t.day ?? 0, t.month ?? 0, (t.year ?? 0) % 100)
            + Formate.hhmm(d)
    }

    /// Die Zeile unter einem Passkey: wo er liegt und wann er zuletzt benutzt wurde.
    public static func passkeyzeile(gesichert: Bool, zuletzt: String?) -> String {
        (gesichert ? Kontoworte.gesichert : nurHier) + " · zuletzt " + datum(zuletzt)
    }

    /// Die Zeile unter einer Sitzung: seit wann und wann zuletzt.
    public static func sitzungszeile(seit: String, zuletzt: String?) -> String {
        "seit \(datum(seit)) · zuletzt \(datum(zuletzt))"
    }
}
