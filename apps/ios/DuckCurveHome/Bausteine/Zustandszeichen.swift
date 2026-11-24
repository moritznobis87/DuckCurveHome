import DuckCurveKit
import SwiftUI

/// Das Zeichen eines Zustands: Farbe und Form zugleich.
///
/// Der Hausherr hat am 24.11.2026 entschieden, dass „in Ordnung“ ein eigenes Grün bekommt und
/// jeder Zustand eine eigene Form: ein Haken im Kreis, ein Dreieck für den Hinweis, ein Achteck
/// für die Störung und ein leerer Ring, wo es keine Angabe gibt. Vorher war es ein Punkt in drei
/// Farben. Mit der Form bleibt der Zustand auch ohne Farbsehen lesbar
/// (`docs/design/werkstatt/LIESMICH.md`).
///
/// Die Zeichnung steht in einem Feld von 18 mal 18, mit denselben Zahlen wie im Dashboard
/// (`apps/web/src/components/ui/Zustandszeichen.tsx`). Wer hier eine ändert, ändert sie dort mit.
struct Zustandszeichen: View {
    let ampel: Hausgeraet.Ampel
    /// Das Zeichen über einer ganzen Seite (20 Punkt) statt in einer Zeile (16 Punkt).
    var gross = false

    @ScaledMetric(relativeTo: .body) private var zeile: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var seite: CGFloat = 20

    private var kante: CGFloat { gross ? seite : zeile }

    var body: some View {
        Canvas { g, flaeche in
            g.scaleBy(x: flaeche.width / 18, y: flaeche.height / 18)
            male(in: &g)
        }
        .frame(width: kante, height: kante)
        .accessibilityElement()
        .accessibilityLabel(ampel.wort)
    }

    private static let strich = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

    private func male(in g: inout GraphicsContext) {
        switch ampel {
        case .gut:
            g.fill(Path(ellipseIn: CGRect(x: 1, y: 1, width: 16, height: 16)), with: .color(Farbe.gut))
            var haken = Path()
            haken.move(to: CGPoint(x: 5.2, y: 9.4))
            haken.addLine(to: CGPoint(x: 7.8, y: 11.9))
            haken.addLine(to: CGPoint(x: 12.8, y: 6.5))
            g.stroke(haken, with: .color(Farbe.deep), style: Self.strich)
        case .warn:
            var dreieck = Path()
            dreieck.move(to: CGPoint(x: 9, y: 2.2))
            dreieck.addLine(to: CGPoint(x: 16.4, y: 15))
            dreieck.addLine(to: CGPoint(x: 1.6, y: 15))
            dreieck.closeSubpath()
            g.fill(dreieck, with: .color(Farbe.amberWeich))
            g.stroke(dreieck, with: .color(Farbe.amberWeich), style: Self.strich)
            ausrufezeichen(in: &g, von: 6.6, bis: 10.6, punkt: 13, farbe: Farbe.deep)
        case .schlecht:
            var achteck = Path()
            achteck.move(to: CGPoint(x: 6, y: 1.2))
            achteck.addLine(to: CGPoint(x: 12, y: 1.2))
            achteck.addLine(to: CGPoint(x: 16.8, y: 6))
            achteck.addLine(to: CGPoint(x: 16.8, y: 12))
            achteck.addLine(to: CGPoint(x: 12, y: 16.8))
            achteck.addLine(to: CGPoint(x: 6, y: 16.8))
            achteck.addLine(to: CGPoint(x: 1.2, y: 12))
            achteck.addLine(to: CGPoint(x: 1.2, y: 6))
            achteck.closeSubpath()
            g.fill(achteck, with: .color(Farbe.alarm))
            ausrufezeichen(in: &g, von: 5, bis: 9.6, punkt: 12.6, farbe: Farbe.papier)
        case .aus:
            let ring = Path(ellipseIn: CGRect(x: 2.5, y: 2.5, width: 13, height: 13))
            g.stroke(ring, with: .color(Farbe.text3), lineWidth: 2)
        }
    }

    private func ausrufezeichen(in g: inout GraphicsContext, von: CGFloat, bis: CGFloat, punkt: CGFloat, farbe: Color) {
        var linie = Path()
        linie.move(to: CGPoint(x: 9, y: von))
        linie.addLine(to: CGPoint(x: 9, y: bis))
        g.stroke(linie, with: .color(farbe), style: Self.strich)
        g.fill(Path(ellipseIn: CGRect(x: 9 - 1.1, y: punkt - 1.1, width: 2.2, height: 2.2)), with: .color(farbe))
    }
}

#if DEBUG
    #Preview("Zustandszeichen") {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Hausgeraet.Ampel.allCases, id: \.self) { ampel in
                HStack(spacing: 10) {
                    Zustandszeichen(ampel: ampel)
                    Zustandszeichen(ampel: ampel, gross: true)
                    Text(ampel.wort).foregroundStyle(Farbe.text1)
                }
            }
        }
        .padding(24)
        .background(Farbe.flaeche2)
    }
#endif
