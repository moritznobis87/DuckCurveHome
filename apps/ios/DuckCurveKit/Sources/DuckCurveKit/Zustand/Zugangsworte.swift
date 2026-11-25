import Foundation

/// Die Worte der Seite „Zugang und Sicherung“ und von „Mein Zugang“, dazu die Jahre, für die es
/// eine Sicherung gibt.
///
/// **Kurz, seit dem 25.11.2026.** Der Hausherr hat entschieden, dass die langen Erklärtexte der
/// Seite wegfallen („der Text muss weg“). Bis dahin standen hier sechs Abschnitte mit Absätzen
/// über alte Kopplungslinks, Sichtbarkeit für Suchmaschinen, Konfiguration und eine zugeklappte
/// Methode. Die Karten tragen jetzt nur noch Titel und einen Satz (``Kontoworte/Kartenart``),
/// wie im Dashboard (`apps/web/src/app/system/zugang/page.tsx`).
public enum Zugangsworte {

    // MARK: - Mein Zugang

    public static let meinZugangUeberschrift = "Mein Zugang"

    /// Was auf „Mein Zugang“ steht, wenn keine Person angemeldet ist (`MeinZugang.tsx`).
    public static let keinePerson =
        "Hier ist keine Person angemeldet. Darum gibt es an dieser Stelle weder eigene Passkeys noch ein eigenes Passwort. Wer einen eigenen Zugang möchte, lässt sich vom Hausherrn einladen."

    /// Die Zeile über dem eigenen Zugang (`MeinZugang.tsx`): wer angemeldet ist.
    public static func angemeldetAls(_ email: String) -> String {
        "Angemeldet als \(email)."
    }

    public static let abmelden = "Abmelden"

    // MARK: - Sicherung

    /// Die Zeile unter jedem Jahr, wie im Dashboard: was die Datei ist und was sie wiegt.
    public static let sicherungszeile = "gzip-komprimiertes CSV, Minutenwerte rund 20 MB im Jahr"

    /// Der eine Satz der App zum Herunterladen, ohne Gegenstück im Dashboard.
    ///
    /// Der Verweis gibt die Adresse an den Browser des Geräts (``Zugang/export(art:jahr:)``), und
    /// dort fehlt die Anmeldung, die nur diese App aus dem Schlüsselbund setzt. Ohne den Satz sähe
    /// man eine leere Seite und hielte das Programm für kaputt.
    public static let herunterladen =
        "Die Datei lädt im Browser dieses Geräts. Ist man dort nicht angemeldet, holt man sie im Dashboard."

    /// Für welche Jahre eine Sicherung angeboten wird: das laufende und das davor
    /// (`page.tsx:135`: `[year, year - 1]`).
    ///
    /// **Gerechnet im Kalender des Hauses und nicht in dem des Geräts.** `new Date().getFullYear()`
    /// im Web-Dienst läuft in der Zeitzone des Servers; die App liest die Uhr des Hauses
    /// (``Kalender/haus``). Am 1. Januar um 00:30 Ortszeit sind das zwei verschiedene Jahre -
    /// und wer in der Neujahrsnacht die Sicherung des abgelaufenen Jahres holen will, bekäme
    /// sonst die von vorletztem.
    ///
    /// **Zwei und nicht mehr.** Ein Archiv baut man einmal im Jahr auf;
    /// was älter ist, liegt schon woanders, und eine Liste aus zehn Jahren wäre eine Liste von
    /// Dateien, die der Dienst vielleicht nicht mehr hat.
    public static func sicherungsjahre(jetzt: Date) -> [Int] {
        let jahr = Kalender.haus.component(.year, from: jetzt)
        return [jahr, jahr - 1]
    }
}
