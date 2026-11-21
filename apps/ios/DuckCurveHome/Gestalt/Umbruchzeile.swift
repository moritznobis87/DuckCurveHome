import SwiftUI

/// Ein Eintrag einer Legende: ein Klotz in der Farbe und seiner Höhe, dann das Wort.
struct Legendenstueck: Identifiable {
    let wort: String
    let farbe: Color
    let hoehe: CGFloat
    var id: String { wort }
}

/// Eine Zeile, die am Rand umbricht - zwölf Legendenstücke passen auf kein Telefon.
///
/// SwiftUI hat dafür nichts: `HStack` schiebt hinaus, `ViewThatFits` kennt nur fertige
/// Entwürfe, und ein `LazyVGrid` gibt jedem Stück dieselbe Breite, was bei „aus" und
/// „Wärmepumpe angefordert" lächerlich aussieht. Also ein eigenes `Layout`.
struct Umbruchzeile: Layout {
    var abstand: CGFloat = 12
    var zeilenabstand: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let breite = proposal.width ?? .infinity
        let zeilen = umbrechen(subviews, breite: breite)
        let hoehe = zeilen.reduce(0) { $0 + $1.hoehe } + CGFloat(max(0, zeilen.count - 1)) * zeilenabstand
        return CGSize(width: proposal.width ?? zeilen.map(\.breite).max() ?? 0, height: hoehe)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var y = bounds.minY
        for zeile in umbrechen(subviews, breite: bounds.width) {
            var x = bounds.minX
            for i in zeile.indizes {
                let g = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(
                    at: CGPoint(x: x, y: y + (zeile.hoehe - g.height) / 2),
                    proposal: ProposedViewSize(g))
                x += g.width + abstand
            }
            y += zeile.hoehe + zeilenabstand
        }
    }

    private struct Zeile {
        var indizes: [Int] = []
        var breite: CGFloat = 0
        var hoehe: CGFloat = 0
    }

    private func umbrechen(_ subviews: Subviews, breite: CGFloat) -> [Zeile] {
        var zeilen: [Zeile] = []
        var jetzt = Zeile()
        for i in subviews.indices {
            let g = subviews[i].sizeThatFits(.unspecified)
            let dazu = jetzt.indizes.isEmpty ? g.width : jetzt.breite + abstand + g.width
            if !jetzt.indizes.isEmpty, dazu > breite {
                zeilen.append(jetzt)
                jetzt = Zeile()
            }
            jetzt.breite = jetzt.indizes.isEmpty ? g.width : jetzt.breite + abstand + g.width
            jetzt.hoehe = max(jetzt.hoehe, g.height)
            jetzt.indizes.append(i)
        }
        if !jetzt.indizes.isEmpty { zeilen.append(jetzt) }
        return zeilen
    }
}
