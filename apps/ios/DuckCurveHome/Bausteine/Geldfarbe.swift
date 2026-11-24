import DuckCurveKit
import SwiftUI

/// Die Töne der Kostenseite als Farben - die einzige Stelle, an der das geschieht.
///
/// **Warum nicht `Farbe.ton`.** Das nimmt ``Kennzahl/Ton``, und dem fehlt der Wert für
/// `--alert` (#E0533D), mit dem die Vorlage den bezahlten Betrag und das „gekostet“ des
/// Vergleichslaufs setzt (`CostReport.tsx:112`, `:103`). ``Kennzahl/Ton`` zu erweitern hieße,
/// den vollständigen `switch` in `Gestalt/Farben.swift` zu erweitern, und der gehört allen
/// Seiten. Darum trägt ``Gelduebersicht/Ton`` die sieben Rollen dieser Seite, und hier stehen
/// ihre Farben.
///
/// Welche Rolle eine Zahl hat, entscheidet der Kern; welche Farbe eine Rolle bekommt, steht
/// hier. Keine Ansicht dieser Seite wählt selbst eine Farbe.
enum Geldfarbe {
    static func zu(_ ton: Gelduebersicht.Ton) -> Color {
        switch ton {
        case .alarm: return Farbe.alarm
        case .netz: return Farbe.netzBezug
        case .nebel: return Farbe.mist
        case .bernstein: return Farbe.amber
        case .einspeisung: return Farbe.netzEinspeisung
        case .text: return Farbe.text1
        case .ofen: return Farbe.ofen
        case .leise: return Farbe.text3
        }
    }
}
