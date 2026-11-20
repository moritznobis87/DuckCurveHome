import DuckCurveKit
import SwiftUI

/// Die Marken aus `DuckCurveKit` als SwiftUI-Farben.
///
/// Das ist die ganze Uebersetzung: eine Zeile je Marke. Die Werte, ihre Begruendungen und die
/// Palettenpruefung stehen in `Marken.swift` im Kern, weil sie dort unter Linux getestet werden
/// koennen. Hier wird nur umgerechnet.
///
/// **Warum kein Asset-Katalog.** Farben in `Assets.xcassets` sind ein zweiter Ort fuer dieselbe
/// Wahrheit: sie lassen sich in Xcode anklicken und verschieben, ohne dass ein Test es merkt,
/// und sie tauchen im Diff als Zahlenbrei auf. `tokens.css` ist die Quelle, `Marken.swift` ihre
/// Uebersetzung, und das hier die letzte Meile.
extension Color {
    init(_ marke: Farbwert) {
        self.init(
            .sRGB,
            red: marke.rot,
            green: marke.gruen,
            blue: marke.blau,
            opacity: marke.deckung
        )
    }
}

/// Die Farben der Anwendung, unter ihren Namen aus `tokens.css`.
public enum Farbe {
    // Marke
    public static let petrol = Color(Marken.petrol)
    public static let deep = Color(Marken.deep)
    public static let amber = Color(Marken.amber)
    public static let amberWeich = Color(Marken.amberWeich)
    public static let mist = Color(Marken.mist)
    /// Das Weiss der Marke - die helle Kachel, auf der das Maskottchen steht.
    public static let papier = Color(Marken.papier)

    // Flaechen
    public static let grund = Color(Marken.grund)
    public static let flaeche1 = Color(Marken.flaeche1)
    public static let flaeche2 = Color(Marken.flaeche2)
    public static let flaeche3 = Color(Marken.flaeche3)
    public static let flaecheGlas = Color(Marken.flaecheGlas)
    public static let linie1 = Color(Marken.linie1)
    public static let linie2 = Color(Marken.linie2)
    public static let rasterlinie = Color(Marken.rasterlinie)
    /// Die Spur der Tagesuhr - schwächer als jede Linie, Begründung an ``Marken/spur``.
    public static let spur = Color(Marken.spur)

    /// Die hervorgehobene Zeile einer anklickbaren Tabelle.
    ///
    /// **Heller und nicht dunkler als die Karte, anders als in der Vorlage** - weil die App
    /// ihre Kartenflächen umgekehrt belegt. Dort steht die Karte auf `--surface-2` (#123544)
    /// und die gewählte Zeile auf dem dunkleren `--surface-1` (#0F2E3D)
    /// (`reports/InvoiceCheck.tsx:279`). ``Karte`` nimmt am iPad `flaeche1` und am Telefon
    /// `flaeche2`; `flaeche1` als Hervorhebung wäre am iPad die Kartenfläche selbst und damit
    /// unsichtbar. `flaeche3` hebt sich von **beiden** ab (1,26:1 auf `flaeche1`, 1,15:1 auf
    /// `flaeche2`) und liegt damit in seinem schlechtesten Fall noch über dem, was die Vorlage
    /// selbst erreicht (`--surface-1` auf `--surface-2`: 1,09:1). Der Unterschied zur Vorlage
    /// ist die Richtung, nicht die Sache.
    ///
    /// Eigener Name und nicht `flaeche3` an der Stelle: dieselbe Fläche trägt in der App
    /// zwanzig Kacheln, Kapseln und Felder, und eine Hervorhebung, die nachgezogen werden
    /// muss, findet man nur unter ihrem Namen.
    public static let zeileGewaehlt = flaeche3

    // Text
    public static let text1 = Color(Marken.text1)
    public static let text2 = Color(Marken.text2)
    public static let text3 = Color(Marken.text3)
    public static let kicker = Color(Marken.textKicker)

    // Energie
    public static let pv = Color(Marken.pv)
    public static let netzBezug = Color(Marken.netzBezug)
    public static let netzEinspeisung = Color(Marken.netzEinspeisung)
    public static let batterie = Color(Marken.batterie)
    public static let waermepumpe = Color(Marken.waermepumpe)
    public static let ofen = Color(Marken.ofen)
    public static let haus = Color(Marken.haus)
    public static let warmwasser = Color(Marken.warmwasser)
    public static let puffer = Color(Marken.puffer)
    public static let wallbox = Color(Marken.wallbox)
    public static let preis = Color(Marken.preis)
    public static let last = Color(Marken.last)

    // Status
    public static let gut = Color(Marken.gut)
    public static let achtung = Color(Marken.achtung)
    public static let alarm = Color(Marken.alarm)

    // Thermisch
    public static let ventilOffen = Color(Marken.ventilOffen)

    /// Die Farben der gestapelten Diagramme - andere als die des Flussbilds, weil sie
    /// uebereinander liegen. Begruendung an `Marken`.
    public static let diagrammNetz = Color(Marken.diagrammNetz)
    public static let diagrammWallbox = Color(Marken.diagrammWallbox)
    public static let diagrammSpeicher = Color(Marken.diagrammSpeicher)
    public static let diagrammHaushalt = Color(Marken.diagrammHaushalt)
    /// Die Grundgebühr und die Mehrwertsteuer im gestapelten Rechnungsbetrag.
    public static let grundgebuehr = Color(Marken.grundgebuehr)
    public static let umsatzsteuer = Color(Marken.umsatzsteuer)
    /// Die Sonne des Vortags.
    public static let pvSchatten = Color(Marken.pvSchatten)
    public static let waerme = Marken.waerme.map(Color.init)
    public static let pufferschichten = Marken.pufferschichten.map(Color.init)

    /// Die Farbe einer Pufferschicht, von oben (0) nach unten. Ausserhalb der vier: die
    /// unterste - lieber dieselbe Farbe zweimal als eine weisse Linie ohne Bedeutung.
    public static func pufferschicht(_ stelle: Int) -> Color {
        pufferschichten[min(max(0, stelle), pufferschichten.count - 1)]
    }
    public static let abweichung = Marken.abweichung.map(Color.init)

    /// Die Farbe zu einer Abweichung vom Sollwert, in Kelvin.
    /// Der Ton einer Kachel, wie die Vorlage ihn nennt (`tone` in `Stat`).
    ///
    /// Im Dashboard steht an jeder Kachel ein Wort dafuer, nicht eine Farbe - damit dieselbe
    /// Rolle auf allen Seiten dieselbe Farbe bekommt. Die Zuordnung steht hier und nur hier.
    public static func ton(_ t: Kennzahl.Ton) -> Color {
        switch t {
        case .normal: return text1
        case .sonne: return pv
        case .glut: return waermepumpe
        case .bernstein: return amber
        case .gedaempft: return text3
        case .nebel: return mist
        }
    }

    public static func abweichung(kelvin: Double?) -> Color {
        Color(Marken.abweichungsfarbe(kelvin: kelvin))
    }

    /// Der Verlauf des Hintergrunds, 130 Grad wie im Dashboard.
    ///
    /// SwiftUI kennt keinen Winkel fuer `LinearGradient`, sondern Anfangs- und Endpunkt. 130 Grad
    /// aus CSS - gemessen von oben, im Uhrzeigersinn - entsprechen einem Verlauf von links oben
    /// nach rechts unten, leicht zur Seite gekippt.
    public static let grundVerlauf = LinearGradient(
        stops: Marken.grundVerlauf.map { .init(color: Color($0.farbe), location: $0.stelle) },
        startPoint: UnitPoint(x: 0.08, y: 0),
        endPoint: UnitPoint(x: 0.92, y: 1)
    )

    /// Der Hintergrund einer Seite: der Verlauf, nicht die flache Farbe.
    public static let seitengrund = grundVerlauf

    /// Die Fläche der Anlagenbühne, oben nach unten - Begründung an ``Marken/buehneOben``.
    public static let buehneFlaeche = LinearGradient(
        colors: [Color(Marken.buehneOben), Color(Marken.buehneUnten)],
        startPoint: .top, endPoint: .bottom
    )

    /// Ihr Rand: die Lichtkante oben, Begründung an ``Marken/buehneRand``.
    public static let buehneRand = LinearGradient(
        stops: Marken.buehneRand.map { .init(color: Color($0.farbe), location: $0.stelle) },
        startPoint: .top, endPoint: .bottom
    )
}

/// Die Guete eines Messwerts als Farbe.
///
/// Was eine Guete *bedeutet* - ob der Wert traegt, wie er heisst, wie alt er ist - steht im Kern
/// (`Zustand/Guete.swift`), weil es eine Entscheidung ist und keine Formatierung. Hier bleibt nur
/// die Farbe.
extension Quality {
    public var farbe: Color {
        switch stufe {
        case .gut: return Farbe.text1
        case .alt: return Farbe.achtung
        case .fehlt: return Farbe.text3
        case .falsch: return Farbe.alarm
        }
    }
}
