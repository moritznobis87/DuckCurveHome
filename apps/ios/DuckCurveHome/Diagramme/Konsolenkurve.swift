import DuckCurveKit
import SwiftUI

/// Die Tageskurve der Wärmepumpe im Konsolenfenster: eine Linie, zwei Zahlen an der Achse.
///
/// Vorlage: `house/Konsole.tsx:111-131` - ein SVG von 280 × 46 mit
/// `preserveAspectRatio="none"`, einer Grundlinie in `--line-1`, einem Pfad je
/// zusammenhängendem Stück in `--heat-pump` und darunter der Achse „00 · N kW · 24“
/// (`globals.css:538-540`).
///
/// **Warum ein `Canvas` und nicht Swift Charts.** Die Reihe hat Lücken, und Charts zieht über
/// `nil` hinweg, wenn man die Stücke nicht einzeln malt. Derselbe Weg wie beim Tagesverlauf der
/// Raumkachel (`Seiten/Haus/Raumkachel.swift`): der Kern rechnet die Stücke vor
/// (``Hauskonsolenfenster/sparklinie(_:hoechst:)``), hier wird nur gemalt.
struct Konsolenkurve: View {
    /// Zusammenhängende Stücke in Einheitskoordinaten, aus dem Kern.
    let stuecke: [[Raumkarte.Punkt]]
    /// Was oben an der Achse steht, in kW.
    let hoechst: Double
    var farbe: Color = Farbe.waermepumpe

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Canvas { g, groesse in male(in: &g, groesse: groesse) }
                .frame(height: 46)
                .accessibilityLabel("Leistung der Wärmepumpe über den Tag")
            achse
        }
    }

    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        let hoehe = groesse.height
        let breite = groesse.width
        var grund = Path()
        grund.move(to: CGPoint(x: 0, y: hoehe - 0.5))
        grund.addLine(to: CGPoint(x: breite, y: hoehe - 0.5))
        g.stroke(grund, with: .color(Farbe.linie1), lineWidth: 1)
        for stueck in stuecke {
            g.stroke(
                pfad(stueck, breite: breite, hoehe: hoehe), with: .color(farbe),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }

    /// Ein Stück als Pfad. **Der Rand bleibt frei**: eine Kurve, die die Unterkante berührt,
    /// verschwindet in der Grundlinie, und eine, die die Oberkante berührt, sieht abgeschnitten
    /// aus - deshalb dieselbe halbe Punktbreite Luft wie in der Vorlage (`insights.ts:215`).
    private func pfad(_ stueck: [Raumkarte.Punkt], breite: Double, hoehe: Double) -> Path {
        var p = Path()
        for (i, punkt) in stueck.enumerated() {
            let stelle = CGPoint(
                x: punkt.x * breite, y: punkt.y * (hoehe - 1) + 0.5)
            if i == 0 { p.move(to: stelle) } else { p.addLine(to: stelle) }
        }
        return p
    }

    private var achse: some View {
        HStack(spacing: 6) {
            Text("00").font(Schrift.mono(9)).foregroundStyle(Farbe.text3)
            Spacer(minLength: 0)
            Text(spitze).font(Schrift.mono(9)).foregroundStyle(Farbe.text3)
            Spacer(minLength: 0)
            Text("24").font(Schrift.mono(9)).foregroundStyle(Farbe.text3)
        }
        .accessibilityHidden(true)
    }

    private var spitze: String {
        hoechst > 0 ? Formate.zahl(hoechst, stellen: 0) + " kW" : ""
    }
}
