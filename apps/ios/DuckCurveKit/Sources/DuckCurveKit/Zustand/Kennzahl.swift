import Foundation

/// Eine Zahl mit ihrem Wort: der häufigste Baustein dieser Anwendung.
///
/// **Warum es den Typ gibt.** Er ist das Ergebnis jeder Auswahl, die eine Seite über ihre
/// Kopfzahlen trifft - und diese Auswahl gehört in den Kern, weil sie geprüft werden muss.
/// Die Ansicht setzt daraus eine Kachel und wählt die Farbe; sie entscheidet nicht, welche
/// Zahl dasteht.
///
/// **Es war schon zweimal derselbe Typ unter zwei Namen.** `Tageskacheln.Kennzahl` kannte ein
/// `gelb: Bool`, `Fahrplankacheln.Kachel` ein `ton:` mit vier Werten, und beide hatten sonst
/// dieselben vier Felder. Die Wärmeseite hätte den dritten gebraucht. Drei Typen für eine
/// Sache sind die Art Unordnung, aus der später zwei verschiedene Antworten auf dieselbe
/// Frage werden.
public struct Kennzahl: Sendable, Hashable, Identifiable {
    public let wort: String
    public let wert: String
    public let einheit: String?
    /// Ein zweiter, kleiner Satz unter dem Wort - wo einer nötig ist.
    public let dazu: String?
    public let ton: Ton

    public var id: String { wort }

    public init(
        wort: String, wert: String, einheit: String? = nil, dazu: String? = nil,
        ton: Ton = .normal
    ) {
        self.wort = wort
        self.wert = wert
        self.einheit = einheit
        self.dazu = dazu
        self.ton = ton
    }

    /// Welche Rolle die Zahl hat. Das Dashboard schreibt an jede Kachel ein Wort dafür
    /// (`tone` in `Stat`), keine Farbe - damit dieselbe Rolle überall dieselbe Farbe bekommt.
    public enum Ton: String, Sendable, Hashable {
        /// Die Regel: Text in Textfarbe.
        case normal
        /// Sonne, Gewinn, negativer Preis - alles, was gelb ist.
        case sonne
        /// Die Wärmepumpe und was an ihr hängt.
        case glut
        /// Alarmrot `--alert` #E0533D: was bezahlt wurde, und was eine Warnung ist.
        ///
        /// **Warum dieser Fall nachgetragen wurde.** Die Vorlage nennt den Ton `ember`, und
        /// `Stat.tsx:5` setzt ihn auf `var(--alert)` - in `apps/web/src/styles/tokens.css:64`
        /// ist das #E0533D. Derselbe Ton steht am Spannenstreifen (`PeriodStrip.tsx:19`). Im
        /// Kern fehlte er, und darum wichen mehrere Stellen auf ``glut`` aus: die Kacheln
        /// „Wärmepumpe angefordert“ und „Ofen geplant“ (``Fahrplankacheln/kacheln(_:)``),
        /// die Zeile „Netzkosten“ (``Stromuebersicht/spannenzeilen(_:)``), die Zeile
        /// „Bezahlt (Netzstrom)“ (``Gelduebersicht/spannenzeilen(_:)``) und - zuletzt
        /// nachgezogen - „Aus dem Netz“ und „Bezahlt“ der Wallbox (``Wallbox/kacheln(_:)``,
        /// ``Wallbox/spannenzeilen(_:)``) samt den drei Schwellenkacheln des Speichers
        /// (``Speicherbild/kacheln(_:ladestand:)``).
        ///
        /// **``glut`` war dafür der falsche Ton und nicht nur ein ungenauer.** Er ist
        /// `Marken.waermepumpe` #E0966B, und diese Farbe ist ausdrücklich so gewählt, dass sie
        /// von `alarm` absteht, damit die Wärmepumpe nicht wie eine Störung aussieht
        /// (`Gestalt/Marken.swift:94-97`). Eine bezahlte Rechnung soll genau umgekehrt wie eine
        /// Warnung aussehen. Dazu kam, dass auf der Stromseite die Wärmepumpenkachel zwei
        /// Plätze neben der Netzbezugskachel steht: zwei Kacheln in derselben Farbe für
        /// Verschiedenes.
        case alarm
        /// Der Strom aus dem Netz und was er kostet: das Violett des Netzbezugs.
        ///
        /// Der Ton `netz` der Vorlage (`Stat.tsx`, `PeriodStrip.tsx`), seit dem 24.11.2026. Bis
        /// dahin trugen diese Zahlen ``alarm``, und der Netzbezug sah aus wie eine Störung. Das
        /// Rot gehört jetzt der Störung und dem, was auffällt.
        case netz
        /// Geld und Preis.
        case bernstein
        /// Eine Zahl, die nur Hintergrund ist.
        case gedaempft
        /// Eine abgeleitete Größe.
        case nebel
    }
}
