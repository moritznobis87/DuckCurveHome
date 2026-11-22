import SwiftUI

/// Mehrere Karten nebeneinander in einem festen Breitenverhältnis.
///
/// **Warum SwiftUI das nicht kann.** Die Vorlage legt das Hauptdiagramm und die
/// Ersparniskarte in eine `report-row` mit `--cols: "8fr 4fr"` (`CostReport.tsx:119`,
/// `globals.css:108`). Ein `HStack` mit `frame(maxWidth: .infinity)` an beiden Kindern teilt
/// gleich, `Grid` richtet seine Spalten nach dem breitesten Inhalt, und
/// `containerRelativeFrame` misst gegen die ``ScrollView`` und nicht gegen den Platz, den
/// diese Reihe hat - die Seite hat ein Seitenpolster, und das fehlte dann. Zwei Drittel gegen
/// ein Drittel ist aber genau die Aussage: links das Bild, rechts die Beilage. Also ein
/// eigenes `Layout`, wie schon bei ``Umbruchzeile``.
///
/// **Alle Kinder bekommen dieselbe Höhe.** Die Vorlage setzt eine Flex-Reihe, in der die
/// Karten gleich hoch stehen; zwei Karten nebeneinander, von denen die eine 30 Punkte höher
/// ist, sehen aus wie ein Fehler im Raster.
struct Spaltenreihe: Layout {
    /// Die Maße in der Reihenfolge der Kinder. `[8, 4]` ist `8fr 4fr`.
    var anteile: [CGFloat]
    var abstand: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let voll = proposal.replacingUnspecifiedDimensions().width
        let breiten = spaltenbreiten(voll, subviews.count)
        var hoehe: CGFloat = 0
        for stelle in subviews.indices {
            let gemessen = subviews[stelle].sizeThatFits(
                ProposedViewSize(width: breiten[stelle], height: nil))
            hoehe = max(hoehe, gemessen.height)
        }
        return CGSize(width: voll, height: hoehe)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let breiten = spaltenbreiten(bounds.width, subviews.count)
        var x = bounds.minX
        for stelle in subviews.indices {
            subviews[stelle].place(
                at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                proposal: ProposedViewSize(width: breiten[stelle], height: bounds.height))
            x += breiten[stelle] + abstand
        }
    }

    /// Die Breiten, nachdem die Abstände abgezogen sind. Ein Kind ohne Maß bekommt `1`: eine
    /// Reihe, die mehr Karten hat als Maße, soll nicht die letzte verschwinden lassen.
    private func spaltenbreiten(_ voll: CGFloat, _ anzahl: Int) -> [CGFloat] {
        guard anzahl > 0 else { return [] }
        let masse = (0..<anzahl).map { stelle in
            stelle < anteile.count ? max(0, anteile[stelle]) : 1
        }
        let frei = max(0, voll - abstand * CGFloat(anzahl - 1))
        let summe = masse.reduce(0, +)
        guard summe > 0 else { return masse.map { _ in frei / CGFloat(anzahl) } }
        return masse.map { frei * $0 / summe }
    }
}
