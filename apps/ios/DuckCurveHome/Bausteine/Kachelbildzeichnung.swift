import DuckCurveKit
import SwiftUI

/// Das Feld, in dem das Bild gezeichnet wird, wie `viewBox="0 0 96 28"` im Browser.
///
/// **Ein eigener Typ und keine statischen Werte der Ansicht.** Die Zeichnung einer `Canvas` läuft
/// außerhalb des Hauptfadens, und statische Werte eines `View` gehören in Swift 6 zu ihm. Die
/// Mac-Übersetzung lehnte das ab; dieser Typ gehört zu keinem Faden.
private enum Kachelmass {
    static let breite: CGFloat = 96
    static let hoehe: CGFloat = 28
}

/// Das kleine Bild am Fuß einer Kachel der Übersicht.
///
/// Das Gegenstück zu `apps/web/src/components/layout/Kachelbild.tsx`, mit denselben Maßen: ein
/// Feld von 96 mal 28, das in der Breite mit der Kachel mitgeht und in der Höhe fest bleibt, wie
/// `preserveAspectRatio="none"` im Browser. Die Rechnung steht im Kern (``Kachelbild``).
///
/// Für die Vorlesehilfe ist das Bild stumm: es trägt keine Zahl, die nicht auch als Leitzahl
/// dasteht.
struct Kachelbildzeichnung: View {
    let bild: UebersichtBildOut
    /// Die Farbe der Sache, von der die Seite handelt.
    let farbe: Color

    var body: some View {
        Canvas { g, flaeche in
            let sx = flaeche.width / Kachelmass.breite
            let sy = flaeche.height / Kachelmass.hoehe
            func rechteck(_ x: CGFloat, _ y: CGFloat, _ b: CGFloat, _ h: CGFloat, rund: CGFloat) -> Path {
                Path(
                    roundedRect: CGRect(x: x * sx, y: y * sy, width: b * sx, height: h * sy),
                    cornerSize: CGSize(width: rund * sx, height: rund * sy))
            }
            func spur() {
                g.fill(rechteck(0, Kachelmass.hoehe - 8, Kachelmass.breite, 6, rund: 3), with: .color(farbe.opacity(0.16)))
            }
            switch bild.art {
            case .balken:
                let schritt = Kachelmass.breite / CGFloat(Kachelbild.stunden)
                for (i, h) in Kachelbild.balkenhoehen(bild.werte).enumerated() {
                    // Ein Platz ohne Wert und eine Stunde mit null stehen als feiner Strich auf
                    // der Grundlinie: man sieht, dass der Tag 24 Stunden hat und wo er gerade ist.
                    let hoch = h.map { max(1.5, CGFloat($0) * Kachelmass.hoehe) } ?? 1.5
                    let deckung = h == nil ? 0.16 : (h == 0 ? 0.3 : 0.9)
                    g.fill(
                        rechteck(CGFloat(i) * schritt + 0.5, Kachelmass.hoehe - hoch, schritt - 1, hoch, rund: 0.8),
                        with: .color(farbe.opacity(deckung)))
                }
            case .fuellung:
                spur()
                if let anteil = bild.anteil {
                    let a = CGFloat(Kachelbild.beschnitten(anteil))
                    if a > 0 {
                        g.fill(rechteck(0, Kachelmass.hoehe - 8, max(3, a * Kachelmass.breite), 6, rund: 3), with: .color(farbe))
                    }
                }
            case .abweichung:
                spur()
                if let anteil = bild.anteil {
                    let a = CGFloat(Kachelbild.beschnitten(anteil, unten: -1))
                    let mitte = Kachelmass.breite / 2
                    let laenge = abs(a) * mitte
                    if laenge > 0 {
                        g.fill(
                            rechteck(a < 0 ? mitte - laenge : mitte, Kachelmass.hoehe - 8, laenge, 6, rund: 3),
                            with: .color(farbe))
                    }
                    // Die Mitte ist die Vorhersage; der Balken zeigt, wie weit der Ertrag lag.
                    g.fill(rechteck(mitte - 0.6, Kachelmass.hoehe - 12, 1.2, 14, rund: 0.6), with: .color(Farbe.text2))
                }
            case .streifen:
                spur()
                for lauf in Kachelbild.laeufe(bild.werte) {
                    let von = CGFloat(lauf.von) * Kachelmass.breite
                    let laenge = max(1.5, CGFloat(lauf.bis - lauf.von) * Kachelmass.breite)
                    g.fill(rechteck(von, Kachelmass.hoehe - 8, laenge, 6, rund: 1.5), with: .color(farbe))
                }
            case .unbekannt:
                break
            }
        }
        .frame(height: Kachelmass.hoehe)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .accessibilityHidden(true)
    }
}
