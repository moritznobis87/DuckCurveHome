import SwiftUI

/// Die Rohre des Anlagenschemas: feste Geometrie, einmal gebaut.
///
/// **Warum die Punkte vorgerechnet sind.** Auf jedem laufenden Rohr wandern bis zu sieben
/// Lichtpunkte, und ihre Stelle auf dem Pfad muss dreißigmal in der Sekunde bekannt sein.
/// `Path.trimmedPath(from:to:).currentPoint` liefert sie, ist aber zu teuer, um sie je Bild
/// und je Punkt neu zu ziehen. Die Geometrie hängt an keinem Messwert – sie ändert sich nie –,
/// also wird jedes Rohr einmal in 96 Stützstellen zerlegt, und das Wandern ist danach ein
/// Nachschlagen.
///
/// Die Pfade sind dieselben wie in `apps/web/src/components/anlage/Schema.tsx`, auf derselben
/// Bühne von 1200 × 640.
enum Anlagenrohre {

    /// Die Bühne, in der alle Koordinaten stehen.
    static let buehne = CGSize(width: 1200, height: 640)

    struct Rohr {
        let pfad: Path
        /// 96 Punkte vom Anfang bis zum Ende, gleichmäßig über die Länge.
        let proben: [CGPoint]

        /// Der Punkt bei `anteil` (0 bis 1) auf dem Rohr.
        func punkt(bei anteil: Double) -> CGPoint {
            guard !proben.isEmpty else { return .zero }
            let i = Int((anteil.truncatingRemainder(dividingBy: 1) + 1)
                .truncatingRemainder(dividingBy: 1) * Double(proben.count - 1))
            return proben[min(max(0, i), proben.count - 1)]
        }
    }

    enum Kennung: String, CaseIterable {
        /// Strom: drei Quellen in einen Knoten, von dort zwei Abgänge.
        case pv, netz, batterie, zurWaermepumpe, zumHaushalt
        /// Der Ofenkreis: Vorlauf über das Glas, senkrecht in die oberste Spitze.
        case ofenVorlauf
        /// Der gemeinsame Rücklauf aus der untersten Spitze, dann die Teilung.
        case ruecklauf, ofenRuecklauf, wpRuecklauf
        case wpVorlauf
        /// Trinkwasser: unten kalt nach, ganz oben warm heraus.
        case kaltwasser, warmwasser
        /// Heizkreis: Mitte heraus, unten hinein.
        case heizung, heizungRuecklauf
    }

    static let alle: [Kennung: Rohr] = {
        var aus: [Kennung: Rohr] = [:]
        for (k, pfad) in pfade { aus[k] = Rohr(pfad: pfad, proben: probiere(pfad)) }
        return aus
    }()

    static func rohr(_ k: Kennung) -> Rohr {
        alle[k] ?? Rohr(pfad: Path(), proben: [])
    }

    // MARK: - Die Pfade

    private static func kurve(
        _ von: CGPoint, _ g1: CGPoint, _ g2: CGPoint, _ nach: CGPoint
    ) -> Path {
        var p = Path()
        p.move(to: von)
        p.addCurve(to: nach, control1: g1, control2: g2)
        return p
    }

    private static func punkt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    private static let pfade: [Kennung: Path] = [
        // M160 150 C 220 150, 230 300, 300 300
        .pv: kurve(punkt(160, 150), punkt(220, 150), punkt(230, 300), punkt(300, 300)),
        // M160 300 L 300 300
        .netz: {
            var p = Path()
            p.move(to: punkt(160, 300))
            p.addLine(to: punkt(300, 300))
            return p
        }(),
        // M160 450 C 220 450, 230 300, 300 300
        .batterie: kurve(punkt(160, 450), punkt(220, 450), punkt(230, 300), punkt(300, 300)),
        // M300 300 C 360 300, 370 332, 420 332
        .zurWaermepumpe: kurve(punkt(300, 300), punkt(360, 300), punkt(370, 332), punkt(420, 332)),
        // M300 300 C 300 380, 330 400, 330 432
        .zumHaushalt: kurve(punkt(300, 300), punkt(300, 380), punkt(330, 400), punkt(330, 432)),
        // M680 135 C 740 135, 860 40, 860 92
        .ofenVorlauf: kurve(punkt(680, 135), punkt(740, 135), punkt(860, 40), punkt(860, 92)),
        // M860 562 C 860 584, 816 590, 784 560
        .ruecklauf: kurve(punkt(860, 562), punkt(860, 584), punkt(816, 590), punkt(784, 560)),
        // M784 560 L 784 204 C 784 184, 764 172, 680 172
        .ofenRuecklauf: {
            var p = Path()
            p.move(to: punkt(784, 560))
            p.addLine(to: punkt(784, 204))
            p.addCurve(to: punkt(680, 172), control1: punkt(784, 184), control2: punkt(764, 172))
            return p
        }(),
        // M784 560 C 770 500, 740 420, 680 364
        .wpRuecklauf: kurve(punkt(784, 560), punkt(770, 500), punkt(740, 420), punkt(680, 364)),
        // M680 300 C 740 300, 760 262, 824 262
        .wpVorlauf: kurve(punkt(680, 300), punkt(740, 300), punkt(760, 262), punkt(824, 262)),
        // M980 562 C 950 562, 930 548, 896 548
        .kaltwasser: kurve(punkt(980, 562), punkt(950, 562), punkt(930, 548), punkt(896, 548)),
        // M896 106 C 940 106, 940 180, 980 180
        .warmwasser: kurve(punkt(896, 106), punkt(940, 106), punkt(940, 180), punkt(980, 180)),
        // M896 330 C 940 330, 940 330, 980 330
        .heizung: kurve(punkt(896, 330), punkt(940, 330), punkt(940, 330), punkt(980, 330)),
        // M1070 380 C 1070 470, 960 470, 896 470
        .heizungRuecklauf: kurve(punkt(1070, 380), punkt(1070, 470), punkt(960, 470), punkt(896, 470)),
    ]

    /// Ein Pfad in gleichmäßige Stützstellen zerlegt.
    private static func probiere(_ pfad: Path, stellen: Int = 96) -> [CGPoint] {
        (0...stellen).compactMap { i in
            let t = Double(i) / Double(stellen)
            // `trimmedPath(from: 0, to: 0)` hat keinen Punkt; der Anfang kommt aus `to: .0001`.
            return pfad.trimmedPath(from: 0, to: max(0.0001, t)).currentPoint
        }
    }
}
