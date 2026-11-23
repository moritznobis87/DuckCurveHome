import Foundation

/// Wie viele Kennzahlkacheln nebeneinander stehen - gestaffelt nach der Breite.
///
/// **Warum es drei Stufen braucht und nicht zwei.** Die Vorlage schaltet an jeder Kachelreihe
/// zweimal um: `grid-cols-2 md:grid-cols-4 xl:grid-cols-7` (`waerme/Fahrplan.tsx:548`),
/// `grid-cols-2 md:grid-cols-3 xl:grid-cols-5` (`waerme/Wirkung.tsx:171`). Die obere Stufe
/// liegt zwischen einem iPad hochkant und einem quer, und `horizontalSizeClass` kennt nur
/// „schmal“ und „breit“ - sie kann diese Grenze nicht treffen. Darum wird gemessen.
///
/// **Gemessen wird die Breite des Kachelfelds, nicht die des Fensters.** Eine Medienabfrage
/// der Vorlage kennt das Fenster; eine SwiftUI-Ansicht kennt den Platz, den sie bekommt.
/// Dazwischen liegen die beiden Raender der Seite von je 16 Punkten
/// (`App/Seitenwahl.swift`, `padding(.horizontal, 16)`), und die Schwellen stehen deshalb um
/// diese 32 Punkte tiefer. Ist links noch eine Leiste, faellt die Antwort eine Stufe
/// vorsichtiger aus - und eine Stufe zu wenig ist hier der harmlose Fehler.
///
/// **Warum im Kern und nicht in der Ansicht.** Die Schwellen standen in
/// ``Fahrplanraster/spalten(breite:)`` und galten nur fuer die sieben Fahrplankacheln; jede
/// andere Seite rechnete `schmal ? 2 : n` und verlor damit die obere Stufe. Zwei Kopien
/// derselben beiden Zahlen waeren zwei Stellen, an denen die Staffelung auseinanderlaeuft -
/// und nur hier laesst sie sich unter Linux pruefen.
public struct Kachelraster: Sendable, Hashable {
    /// Bis 768 px Fensterbreite - am Telefon und im schmalen Fenster.
    public var schmal: Int
    /// Ab `md` (768 px).
    public var mittel: Int
    /// Ab `xl` (1280 px).
    public var breit: Int

    public init(schmal: Int = 2, mittel: Int, breit: Int) {
        self.schmal = schmal
        self.mittel = mittel
        self.breit = breit
    }

    /// Die Spaltenzahl zu einer gemessenen Breite.
    ///
    /// Eine Breite von null gibt es im ersten Zeichendurchgang, bevor gemessen wurde: dann
    /// gilt die unterste Stufe, mit der die Vorlage ohne Medienabfrage anfaengt.
    public func spalten(breite: Double) -> Int {
        guard breite.isFinite, breite > 0 else { return schmal }
        if breite >= 1280 - 32 { return breit }
        if breite >= 768 - 32 { return mittel }
        return schmal
    }
}
