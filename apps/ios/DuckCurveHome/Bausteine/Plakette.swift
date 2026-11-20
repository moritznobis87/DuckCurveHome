import DuckCurveKit
import SwiftUI

/// Eine gefüllte Plakette: ein Wort in Versalien, auf eigener Fläche, mit Rand.
///
/// Vorlage ist `Pill` (`apps/web/src/components/ui/Pill.tsx:1-11`) - Mono, 12 px, Versalien,
/// Sperrung 0,08em, `rounded-[2px]`, `px-[10px] py-[4px]`, `whitespace-nowrap`.
///
/// **Warum sie neben ``Abzeichen`` steht und nicht darin.** ``Abzeichen``
/// (`Seiten/Haus/Raumkachel.swift:334-352`) ist ein Umriss: 10,5 Punkte Sans, kein Grund, die
/// Randfarbe ist die Schriftfarbe. Das ist richtig für die Stelle, für die es gebaut wurde -
/// ein Beiwort neben einer 34 Punkte großen Zahl auf einer Raumkachel, das die Zahl nicht
/// bedrängen darf. Diese hier ist das Gegenteil: sie ist der Zustand einer Protokollzeile und
/// soll in einer Spalte aus achtzig Zeilen von weitem erkennbar sein. Dafür füllt die Vorlage
/// mit 14 Prozent der Farbe und umrandet mit 35 bis 40 - eine Fläche liest man am Rand des
/// Blickfelds, einen Umriss nicht. ``Abzeichen`` um eine Fläche und eine Mono-Schriftwahl zu
/// erweitern hieße, einen Baustein mit zwei Gestalten zu bauen, von denen jede Aufrufstelle nur
/// eine benutzt.
///
/// **Die drei Töne sind die der Vorlage und keine Semantik.** `Pill` kennt `neutral`, `amber`
/// und `alert`; was welcher Fall bedeutet, entscheidet die Stelle, die die Plakette setzt - im
/// Türprotokoll die Unterscheidung von Ablehnung und Defekt (`DoorLog.tsx:68-70`), in der
/// Prognose der Unterschied zwischen „lernt“ und „aktiv“ (`ForecastPage.tsx:247`). Eine
/// Plakette, die `Tuerprotokoll.Zustandston` nimmt, wäre für die zweite Stelle nicht zu
/// gebrauchen.
struct Plakette: View {
    let wort: String
    var ton: Ton = .neutral

    @Environment(\.horizontalSizeClass) private var breite

    /// Die drei Töne von `Pill` (`Pill.tsx:2-6`).
    enum Ton {
        /// Weder gut noch schlecht: gedämpfte Schrift auf einer Spur Weiß.
        case neutral
        /// Bernstein - das Wort, das die Seite sucht.
        case amber
        /// Rot. In der Vorlage ausdrücklich nur für einen Defekt und nicht für ein Nein
        /// (`DoorLog.tsx:68-69`).
        case alarm
    }

    var body: some View {
        Text(wort.uppercased())
            .font(Schrift.mono(groesse, relativeTo: .caption))
            .tracking(groesse * 0.08)
            .foregroundStyle(schrift)
            // `whitespace-nowrap`: der Zustand bricht nicht um, er rutscht lieber in die
            // nächste Zeile.
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(flaeche, in: huelle)
            .overlay { huelle.strokeBorder(rand, lineWidth: 1) }
    }

    /// 12 Punkte, am Telefon 13,5.
    ///
    /// `handy.css:189-192` hebt jede 12-Punkt-Schrift um eine Stufe an, mit der Begründung im
    /// Kommentar dort: „Am Rechner liest man 12 Punkt aus sechzig Zentimetern, am Handy aus
    /// dreißig, aber im Gehen.“ Die Regel trifft `Pill` an jeder Stelle, an der sie steht, und
    /// darum steht die Umrechnung hier und nicht bei den Aufrufern.
    private var groesse: CGFloat { breite == .compact ? 13.5 : 12 }

    private var schrift: Color {
        switch ton {
        case .neutral: return Farbe.text2
        case .amber: return Farbe.amber
        case .alarm: return Farbe.alarm
        }
    }

    /// 14 Prozent der Farbe, wie die Vorlage; beim neutralen Ton eine Spur Weiß
    /// (`rgba(255,255,255,.06)`).
    private var flaeche: Color {
        switch ton {
        case .neutral: return Color.white.opacity(0.06)
        case .amber: return Farbe.amber.opacity(0.14)
        case .alarm: return Farbe.alarm.opacity(0.14)
        }
    }

    /// Der Rand: 35 Prozent bei Bernstein, 40 bei Rot - und beim neutralen Ton `line-2`, die
    /// vorhandene Marke, die genau diese Linie ist (`tokens.css:28`).
    private var rand: Color {
        switch ton {
        case .neutral: return Farbe.linie2
        case .amber: return Farbe.amber.opacity(0.35)
        case .alarm: return Farbe.alarm.opacity(0.40)
        }
    }

    /// `rounded-[2px]`, also ``Marken/radius1``. Eigene Eigenschaft, weil Fläche und Rand
    /// dieselbe Form brauchen und `strokeBorder` nur an einer `InsettableShape` steht.
    private var huelle: RoundedRectangle {
        RoundedRectangle(cornerRadius: Marken.radius1)
    }
}
