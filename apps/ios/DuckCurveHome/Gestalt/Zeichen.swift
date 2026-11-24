import DuckCurveKit
import SwiftUI

/// Eine Form aus dem Kern als SwiftUI-Pfad.
///
/// Das ist die ganze Uebersetzung - zwanzig Zeilen. Das Lesen der Pfadangaben, die Zerlegung der
/// Boegen und die Pruefung, dass alle Formen der Zeichen lesbar sind, steht in
/// `DuckCurveKit/Gestalt/SvgPfad.swift` und ist dort getestet.
extension Path {
    /// Pfadstuecke zeichnen, umgerechnet vom Raster der Vorlage auf eine Kantenlaenge.
    init(_ stuecke: [Pfadstueck], raster: Double, kante: CGFloat) {
        self.init()
        let f = kante / raster
        func um(_ p: Punkt) -> CGPoint { CGPoint(x: p.x * f, y: p.y * f) }
        for stueck in stuecke {
            switch stueck {
            case .anfang(let p):
                move(to: um(p))
            case .linie(let p):
                addLine(to: um(p))
            case .kurve(let g1, let g2, let nach):
                addCurve(to: um(nach), control1: um(g1), control2: um(g2))
            case .kurveKurz(let g, let nach):
                addQuadCurve(to: um(nach), control: um(g))
            case .schluss:
                closeSubpath()
            }
        }
    }
}

/// Ein Zeichen: eine Strichzeichnung auf dem 24-Punkt-Raster.
///
/// **Der Strich skaliert nicht mit.** `Icon.tsx` haelt das mit `vector-effect="non-scaling-stroke"`
/// fest, und die Begruendung gilt hier genauso: ein Zeichen in 18 Punkten und eines in 44 Punkten
/// sollen gleich dicke Striche haben, sonst sieht die Bereichsleiste neben dem Flussbild
/// zerbrechlich aus. In SwiftUI heisst das: die Strichbreite ist eine feste Zahl und wird nicht
/// mit der Groesse multipliziert.
///
/// **Ein Zeichen ist eine Zeichnung, keine Beschriftung.** Wo eines allein steht - in der
/// Bereichsleiste, im Dock -, traegt das Element um es herum den Namen fuer VoiceOver. Das
/// Zeichen selbst ist `accessibilityHidden`, damit es nicht zweimal vorgelesen wird.
struct Zeichen: View {
    let art: Zeichenart
    var groesse: CGFloat = 24
    var farbe: Color = Farbe.text1
    /// Die Strichbreite. 1,75 wie im Dashboard; bei sehr kleinen Zeichen etwas weniger.
    var strich: CGFloat = 1.75

    init(_ art: Zeichenart, groesse: CGFloat = 24, farbe: Color = Farbe.text1, strich: CGFloat = 1.75) {
        self.art = art
        self.groesse = groesse
        self.farbe = farbe
        self.strich = strich
    }

    var body: some View {
        ZStack {
            ForEach(Array(formen.enumerated()), id: \.offset) { _, form in
                if form.gefuellt {
                    form.pfad.fill(farbe)
                } else {
                    form.pfad.stroke(
                        farbe,
                        style: StrokeStyle(lineWidth: strich, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .frame(width: groesse, height: groesse)
        .accessibilityHidden(true)
    }

    private struct Form {
        let pfad: Path
        let gefuellt: Bool
    }

    /// Die Formen dieses Zeichens, gelesen und umgerechnet.
    ///
    /// Eine Form, die sich nicht lesen laesst, wird weggelassen und nicht als Fleck gezeichnet.
    /// Dass keine dabei ist, prueft `SvgPfadTests.testAlleZeichenLassenSichLesen` - hier ist nur
    /// die Vorsorge dafuer, dass eine neue Zeichnung die Anzeige nicht zerlegt.
    private var formen: [Form] {
        art.formen.compactMap { form in
            guard let stuecke = try? SvgPfad.lies(form.d) else { return nil }
            return Form(
                pfad: Path(stuecke, raster: Zeichenart.raster, kante: groesse),
                gefuellt: form.gefuellt
            )
        }
    }
}

/// Die Marke: die Entenkurve, wie sie im Kopf der Anzeige steht.
///
/// **Sie heisst „Duck Curve"**, nicht „Duck Curve Home" (`AreaNav.tsx:46-51`, `Brand`). Der
/// lange Name steht im App-Symbol und im Fenstertitel; im Kopf nimmt er die Breite, die das
/// Datum braucht. `Schrift.marke` ist eigens dafuer da und war unbenutzt.
struct Marke: View {
    var groesse: CGFloat = 30

    var body: some View {
        HStack(spacing: 10) {
            Zeichen(.ente, groesse: groesse, farbe: Farbe.amber)
            Text("Duck Curve")
                .font(Schrift.marke)
                .foregroundStyle(Farbe.text1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Duck Curve Home")
    }
}

extension Zeichen {
    /// Das Zeichen eines Bereichs.
    ///
    /// `Bereiche` im Kern nennt nur eine Aufzaehlung (`Bereichszeichen.ente`), weil der Kern kein
    /// SwiftUI kennt. Hier wird daraus eine Zeichnung.
    init(bereich: Bereichszeichen, groesse: CGFloat = 24, farbe: Color = Farbe.text1) {
        let art: Zeichenart =
            switch bereich {
            case .ente: .ente
            case .haus: .haus
            case .blitz: .blitz
            case .euro: .euro
            case .waermepumpe: .waermepumpe
            case .zahnrad: .zahnrad
            case .person: .person
            }
        self.init(art, groesse: groesse, farbe: farbe)
    }
}
