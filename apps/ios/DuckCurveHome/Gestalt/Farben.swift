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

    // Flaechen
    public static let grund = Color(Marken.grund)
    public static let flaeche1 = Color(Marken.flaeche1)
    public static let flaeche2 = Color(Marken.flaeche2)
    public static let flaeche3 = Color(Marken.flaeche3)
    public static let flaecheGlas = Color(Marken.flaecheGlas)
    public static let linie1 = Color(Marken.linie1)
    public static let linie2 = Color(Marken.linie2)
    public static let rasterlinie = Color(Marken.rasterlinie)

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
    public static let wallbox = Color(Marken.wallbox)
    public static let preis = Color(Marken.preis)
    public static let last = Color(Marken.last)

    // Status
    public static let gut = Color(Marken.gut)
    public static let achtung = Color(Marken.achtung)
    public static let alarm = Color(Marken.alarm)

    // Thermisch
    public static let ventilOffen = Color(Marken.ventilOffen)
    public static let waerme = Marken.waerme.map(Color.init)
    public static let abweichung = Marken.abweichung.map(Color.init)

    /// Die Farbe zu einer Abweichung vom Sollwert, in Kelvin.
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
}

/// Die Guete eines Messwerts als Farbe und Wort.
///
/// Jeder Wert aus dem Dienst traegt eine Guete (`ok`, `stale`, `unavailable`, `unknown`,
/// `derived`, `inconsistent`). Die Anzeige muss das zeigen, ohne es zu einer Stoerung
/// aufzublasen: ein Wert, der eine Minute alt ist, ist kein Alarm.
extension Quality {
    /// Ist der Wert gut genug, um als Zahl zu gelten?
    ///
    /// `derived` zaehlt mit: ein aus der Bilanz gerechneter Wert ist kein schlechterer Wert,
    /// sondern ein anderer Weg zur selben Zahl.
    public var traegt: Bool {
        self == .ok || self == .derived
    }

    public var farbe: Color {
        switch self {
        case .ok, .derived: return Farbe.text1
        case .stale: return Farbe.achtung
        case .unavailable, .unknown: return Farbe.text3
        case .inconsistent: return Farbe.alarm
        case .unbekannt: return Farbe.text3
        }
    }

    /// Das Wort, das neben dem Wert stehen kann - oder `nil`, wenn nichts zu sagen ist.
    public var wort: String? {
        switch self {
        case .ok, .derived: return nil
        case .stale: return "alt"
        case .unavailable: return "fehlt"
        case .unknown: return "unbekannt"
        case .inconsistent: return "widersprüchlich"
        case .unbekannt: return nil
        }
    }
}

extension Messwert {
    /// Der Wert, wenn er traegt - sonst `nil`.
    ///
    /// Das ist die Stelle, an der die Anzeige entscheidet, ob eine Zahl dasteht oder ein
    /// Bindestrich. Ein `stale`-Wert wird gezeigt, aber gedaempft: er war einmal richtig.
    public var belastbar: Double? {
        quality.traegt ? value : nil
    }

    public var zeitpunkt: Date? {
        Zeit.ausIso(observedAt)
    }

    /// Wie alt der Wert ist, in Worten - oder `nil`, solange er frisch ist.
    public func alter(jetzt: Date) -> String? {
        guard let z = zeitpunkt else { return nil }
        return Formate.alter(beobachtetAm: z, jetzt: jetzt)
    }
}
