import DuckCurveKit
import SwiftUI

/// Die Instrumente der Regelkreis-Seite: Kennbild, Rundinstrument, Pegel, Schieber, Verlauf.
///
/// **Warum Instrumente und nicht Zahlen.** Eine Phasenreserve von 38° ist eine Zahl, die man
/// lesen und einordnen muss; ein Zeiger im roten Feld ist eine Lage, die man sieht. Dieselbe
/// Auskunft, ein Bruchteil der Zeit - und bei einunddreißig Parametern auf einer Seite ist das
/// der Unterschied zwischen einer Tafel, die man überfliegt, und einer, die man liest. Die
/// Vorlage im Dashboard hat dieselben vier (`components/regelkreis/Anzeigen.tsx`), und die
/// Begründung steht dort wortgleich.
///
/// **Jedes Instrument zeigt seinen Maßstab mit.** Ein Pegel ohne Skala ist Dekoration. Der
/// Schieber trägt deshalb seine Plausibilitätsgrenzen, der Zeiger seine Felder, der Pegel seine
/// Schwelle - sonst sagt der Ausschlag nichts darüber, ob er groß ist.
///
/// **Gerechnet wird hier nichts.** Anteile, Kurven, Felder und Sätze kommen aus
/// ``Regelkreisbild`` und dem Dienst; diese Datei malt.

// MARK: - Farben der Herkunft

/// Woher eine Zahl stammt, als Farbe. Dieselbe Zuordnung wie im Dashboard
/// (`Anzeigen.tsx:23-30`), damit derselbe Parameter in beiden Oberflächen dieselbe Farbe hat.
enum Herkunftsfarbe {
    static func farbe(_ h: Regelkreisbild.Herkunftston) -> Color {
        switch h {
        case .gemessen: return Farbe.amber
        case .geschaetzt: return Farbe.amberWeich
        case .annahme, .fest: return Farbe.text3
        case .entwurf: return Farbe.mist
        case .uebersteuert: return Farbe.alarm
        }
    }

    /// Der Ton der Plakette am Parameter: nur eine Übersteuerung ist ein Alarm, nur eine
    /// Messung ist Bernstein.
    static func ton(_ h: Regelkreisbild.Herkunftston) -> Plakette.Ton {
        switch h {
        case .uebersteuert: return .alarm
        case .gemessen, .geschaetzt: return .amber
        case .annahme, .fest, .entwurf: return .neutral
        }
    }
}

/// Das Feld einer Reserve als Farbe.
enum Reservefarbe {
    static func farbe(_ f: Regelkreisbild.Reservefeld) -> Color {
        switch f {
        case .zuKlein: return Farbe.alarm
        case .knapp: return Farbe.amber
        case .gut: return Farbe.mist
        }
    }
}

// MARK: - Kennbild

/// Das Bild eines Übertragungsglieds, wie es seit jeher im Kästchen steht: die Antwort auf
/// einen Sprung, bei statischen Gliedern die Kennlinie.
///
/// Die Kurve kommt gerechnet aus dem Kern (``GliedAnsicht/kurve``, auf das Einheitsquadrat
/// gelegt). Hier wird sie nur in den Rahmen gelegt - zwei Achsen, eine Kurve, und wo ein Glied
/// zwei Zweige hat (Hysterese, Dreipunkt), der zweite blasser dahinter.
struct Kennbild: View {
    let glied: GliedAnsicht
    var breite: CGFloat = 52
    var hoehe: CGFloat = 32
    var farbe: Color = Farbe.amber
    /// Im Kästchen dünn, auf dem Blatt dick.
    var dick: Bool = false

    private var polster: CGFloat { 3 }

    var body: some View {
        Canvas { g, groesse in male(in: &g, groesse: groesse) }
            .frame(width: breite, height: hoehe)
            .background(Farbe.flaeche3.opacity(0.5))
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Farbe.linie1, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .accessibilityLabel("Kennbild: \(glied.erkennen)")
    }

    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        // **Beide Achsen rechnen in `CGFloat`, nicht in `Double`.** Die Kurven kommen als
        // `Double` aus dem Schema, die Fläche als `CGFloat`; gemischt übersetzt es zwar, aber
        // an jeder Stelle anders, und eine davon ist eine Mehrdeutigkeit, die erst der
        // Compiler auf dem Mac meldet.
        let x = { (u: Double) in polster + CGFloat(u) * (groesse.width - 2 * polster) }
        let y = { (v: Double) in
            groesse.height - polster - CGFloat(v) * (groesse.height - 2 * polster)
        }

        // Die Achsen: ohne sie ist eine Kurve nur ein Gekritzel.
        var achsen = Path()
        achsen.move(to: CGPoint(x: x(0), y: y(0)))
        achsen.addLine(to: CGPoint(x: x(1), y: y(0)))
        achsen.move(to: CGPoint(x: x(0), y: y(0)))
        achsen.addLine(to: CGPoint(x: x(0), y: y(1)))
        g.stroke(achsen, with: .color(Farbe.linie2), lineWidth: 0.8)

        if !glied.kurve2.isEmpty {
            g.stroke(
                pfad(glied.kurve2, x: x, y: y), with: .color(farbe.opacity(0.4)),
                style: strich)
        }
        g.stroke(pfad(glied.kurve, x: x, y: y), with: .color(farbe), style: strich)
    }

    private var strich: StrokeStyle {
        StrokeStyle(lineWidth: dick ? 2.0 : 1.4, lineCap: .round, lineJoin: .round)
    }

    /// **Ein Punkt ohne zwei Zahlen wird übersprungen.** Die Kurven kommen als Listen von
    /// Listen durch das Schema (`[[Double]]`); ein Schema kann nicht festlegen, dass genau zwei
    /// drinstehen. Was nicht passt, wird nicht gemalt - lieber eine kürzere Kurve als ein
    /// Absturz an einem Index.
    private func pfad(
        _ punkte: [[Double]], x: (Double) -> CGFloat, y: (Double) -> CGFloat
    ) -> Path {
        var p = Path()
        var erster = true
        for punkt in punkte where punkt.count >= 2 {
            let stelle = CGPoint(x: x(punkt[0]), y: y(punkt[1]))
            if erster {
                p.move(to: stelle)
                erster = false
            } else {
                p.addLine(to: stelle)
            }
        }
        return p
    }
}

// MARK: - Rundinstrument

/// Ein Zeiger über drei Feldern: die Phasenreserve.
///
/// **Warum rund und nicht als Balken.** Die Phasenreserve hat einen Bereich mit Mitte und zwei
/// Rändern, und ein Zeiger über eingefärbten Feldern sagt ohne Zahl, in welchem man steht. Der
/// Bogen umfasst 240° - der Rest unten bleibt frei, damit die Zahl Platz hat.
struct Rundinstrument: View {
    /// Der Ausschlag, 0 bis 1. `nil` heißt: nicht bewertbar, der Zeiger fehlt.
    let anteil: Double?
    let zahl: String
    /// Die Felder von innen nach außen, als Obergrenzen in Anteilen.
    let felder: [Feld]
    var groesse: CGFloat = 66
    var titel: String = "Phasenreserve"

    struct Feld: Hashable {
        let bis: Double
        let farbe: Color
    }

    private static let von: Double = 150
    private static let bis: Double = 390

    var body: some View {
        Canvas { g, flaeche in male(in: &g, flaeche: flaeche) }
            .frame(width: groesse, height: groesse * 0.78)
            .overlay(alignment: .bottom) {
                Text(zahl)
                    .font(Schrift.mono(12, relativeTo: .caption))
                    .foregroundStyle(Farbe.text1)
            }
            .accessibilityLabel("\(titel) \(zahl)")
    }

    private func male(in g: inout GraphicsContext, flaeche: CGSize) {
        let mitte = CGPoint(x: flaeche.width / 2, y: flaeche.height * 0.72)
        let radius = min(flaeche.width, flaeche.height * 1.3) / 2 - 5
        var unten = 0.0
        for feld in felder {
            g.stroke(
                bogen(mitte: mitte, radius: radius, von: unten, bis: feld.bis),
                with: .color(feld.farbe.opacity(0.55)),
                style: StrokeStyle(lineWidth: 5, lineCap: .butt))
            unten = feld.bis
        }
        guard let anteil else { return }
        // Der Zeiger: eine Nadel von der Nabe bis kurz vor den Bogen.
        let ausschlag = min(1.0, max(0.0, anteil))
        let winkel = Angle.degrees(Self.von + (Self.bis - Self.von) * ausschlag)
        var nadel = Path()
        nadel.move(to: mitte)
        nadel.addLine(
            to: CGPoint(
                x: mitte.x + CGFloat(cos(winkel.radians)) * (radius - 4),
                y: mitte.y + CGFloat(sin(winkel.radians)) * (radius - 4)))
        g.stroke(
            nadel, with: .color(Farbe.text1),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        g.fill(
            Path(ellipseIn: CGRect(x: mitte.x - 2.5, y: mitte.y - 2.5, width: 5, height: 5)),
            with: .color(Farbe.text1))
    }

    private func bogen(mitte: CGPoint, radius: CGFloat, von: Double, bis: Double) -> Path {
        var p = Path()
        p.addArc(
            center: mitte, radius: radius,
            startAngle: .degrees(Self.von + (Self.bis - Self.von) * von),
            endAngle: .degrees(Self.von + (Self.bis - Self.von) * bis),
            clockwise: false)
        return p
    }
}

// MARK: - Pegel

/// Ein Pegel wie am Mischpult: ein Balken, eine Skala, und die Schwelle als Strich.
///
/// Der Balken sagt, wie groß; der Strich sagt, ob das groß ist. Ohne den Strich wäre ein
/// halber Ausschlag eine Zahl ohne Urteil.
struct Pegel: View {
    /// Der Ausschlag, 0 bis 1.
    let anteil: Double
    /// Wo die Schwelle liegt, 0 bis 1 - `nil`, wo es keine gibt.
    var schwelle: Double?
    var farbe: Color = Farbe.mist
    var senkrecht: Bool = false
    var laenge: CGFloat = 92
    var dicke: CGFloat = 8
    var titel: String = ""
    /// Die Zahl, die neben dem Pegel steht.
    var zahl: String?

    var body: some View {
        Group {
            if senkrecht {
                VStack(spacing: 4) {
                    balken
                    if let zahl { beschriftung(zahl) }
                }
            } else {
                HStack(spacing: 8) {
                    balken
                    if let zahl { beschriftung(zahl) }
                }
            }
        }
        .accessibilityLabel(titel.isEmpty ? (zahl ?? "") : "\(titel) \(zahl ?? "")")
    }

    private func beschriftung(_ z: String) -> some View {
        Text(z)
            .font(Schrift.mono(12, relativeTo: .caption))
            .foregroundStyle(Farbe.text2)
            .lineLimit(1)
    }

    private var balken: some View {
        Canvas { g, flaeche in male(in: &g, flaeche: flaeche) }
            .frame(
                width: senkrecht ? dicke : laenge,
                height: senkrecht ? laenge : dicke)
    }

    private func male(in g: inout GraphicsContext, flaeche: CGSize) {
        let radius = min(dicke, 4) / 2
        let huelle = Path(
            roundedRect: CGRect(origin: .zero, size: flaeche), cornerRadius: radius)
        g.fill(huelle, with: .color(Farbe.papier.opacity(0.07)))

        let teil = CGFloat(min(1, max(0, anteil)))
        let gefuellt: CGRect = senkrecht
            ? CGRect(
                x: 0, y: flaeche.height * (1 - teil), width: flaeche.width,
                height: flaeche.height * teil)
            : CGRect(x: 0, y: 0, width: flaeche.width * teil, height: flaeche.height)
        g.fill(Path(roundedRect: gefuellt, cornerRadius: radius), with: .color(farbe))

        guard let schwelle else { return }
        let s = CGFloat(min(1, max(0, schwelle)))
        var strich = Path()
        if senkrecht {
            let y = flaeche.height * (1 - s)
            strich.move(to: CGPoint(x: -1, y: y))
            strich.addLine(to: CGPoint(x: flaeche.width + 1, y: y))
        } else {
            let x = flaeche.width * s
            strich.move(to: CGPoint(x: x, y: -1))
            strich.addLine(to: CGPoint(x: x, y: flaeche.height + 1))
        }
        g.stroke(strich, with: .color(Farbe.text1), lineWidth: 1.2)
    }
}

// MARK: - Leuchte

/// Eine Leuchte: ein Punkt, der immer leuchtet, und dessen Farbe die Auskunft trägt.
///
/// **Sie geht nicht aus.** In der ersten Fassung der Dashboard-Seite wurde die Leuchte dunkel,
/// wenn die Reserve zu klein war - und eine dunkle Leuchte liest man als „nicht gemessen“,
/// nicht als „Warnung“. Die Farbe sagt es, nicht das Leuchten.
struct Leuchte: View {
    let farbe: Color
    var kante: CGFloat = 8

    var body: some View {
        Circle()
            .fill(farbe)
            .frame(width: kante, height: kante)
            .overlay { Circle().strokeBorder(farbe.opacity(0.35), lineWidth: 3) }
            .padding(2)
            .accessibilityHidden(true)
    }
}

// MARK: - Parameterschieber

/// Ein Parameter als Schieber über seinem Plausibilitätsbereich - wie der Fader eines Mischpults.
///
/// Zu sehen ist auf einen Blick, was eine Zahl allein nicht sagt: wo der Wert zwischen seinen
/// Grenzen steht, wie weit er vom Startwert fortgewandert ist, und wie breit die Unsicherheit um
/// ihn herum liegt. Ein Wert dicht an der Grenze ist ein Grund, nachzusehen; ein Wert, dessen
/// Unsicherheitsband den Startwert noch enthält, erklärt eine abgelehnte Übernahme ohne Satz.
struct Parameterschieber: View {
    let zeile: Regelkreisbild.Parameterzeile
    var hoehe: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Canvas { g, flaeche in male(in: &g, flaeche: flaeche) }
                .frame(height: hoehe)
            HStack(spacing: 0) {
                Text(zeile.unten)
                Spacer(minLength: 4)
                Text(zeile.oben)
            }
            .font(Schrift.mono(9.5))
            .foregroundStyle(Farbe.text3)
        }
        .accessibilityLabel(
            "\(zeile.name): \(zeile.wert), Bereich \(zeile.unten) bis \(zeile.oben)")
    }

    private func male(in g: inout GraphicsContext, flaeche: CGSize) {
        let farbe = Herkunftsfarbe.farbe(zeile.herkunft)
        let mitte = flaeche.height / 2
        let schiene = CGRect(x: 0, y: mitte - 2, width: flaeche.width, height: 4)
        g.fill(
            Path(roundedRect: schiene, cornerRadius: 2),
            with: .color(Farbe.papier.opacity(0.07)))

        // Das Unsicherheitsband, soweit es eines gibt.
        if zeile.sigmaAnteil > 0 {
            let von = CGFloat(max(0, zeile.anteil - zeile.sigmaAnteil)) * flaeche.width
            let bis = CGFloat(min(1, zeile.anteil + zeile.sigmaAnteil)) * flaeche.width
            g.fill(
                Path(
                    roundedRect: CGRect(x: von, y: mitte - 5, width: max(1, bis - von), height: 10),
                    cornerRadius: 2),
                with: .color(farbe.opacity(0.22)))
        }

        // Der Startwert: die Marke, von der aus gelernt wurde.
        var start = Path()
        let sx = CGFloat(zeile.startAnteil) * flaeche.width
        start.move(to: CGPoint(x: sx, y: mitte - 7))
        start.addLine(to: CGPoint(x: sx, y: mitte + 7))
        g.stroke(
            start, with: .color(Farbe.text3),
            style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

        // Und der Griff.
        let gx = CGFloat(zeile.anteil) * flaeche.width
        let griff = CGRect(
            x: max(0, min(flaeche.width - 4, gx - 2)), y: 0, width: 4,
            height: flaeche.height)
        g.fill(Path(roundedRect: griff, cornerRadius: 2), with: .color(farbe))
    }
}

// MARK: - Lernverlauf

/// Der Weg einer Schätzung über die Zeit, mit ihrem Unsicherheitsband.
///
/// **Das ist das Bild, um das es auf dieser Seite geht**: man sieht, wie eine Zahl einläuft -
/// erst weit und unsicher, dann schmaler. Ein Band, das breiter wird, ist ebenfalls eine
/// Auskunft, nämlich dass die Messungen auseinanderlaufen.
struct Lernverlauf: View {
    let punkte: [Messpunkt]
    /// Der geltende Wert als waagerechte Linie - die Marke, gegen die gelernt wird.
    let geltend: Double
    var farbe: Color = Farbe.amberWeich
    var hoehe: CGFloat = 54

    var body: some View {
        if punkte.count < 2 {
            Text("Noch kein Verlauf: dafür braucht es zwei Schätzungen.")
                .font(Schrift.sans(12, relativeTo: .caption))
                .foregroundStyle(Farbe.text3)
        } else {
            Canvas { g, flaeche in male(in: &g, flaeche: flaeche) }
                .frame(height: hoehe)
                .accessibilityLabel("Verlauf der Schätzung über \(punkte.count) Stände")
        }
    }

    /// Der Wertebereich: alle Schätzungen samt Band, dazu der geltende Wert - sonst läge die
    /// Linie, gegen die verglichen wird, außerhalb des Bildes.
    private func grenzen() -> (unten: Double, oben: Double) {
        var unten = geltend
        var oben = geltend
        for p in punkte {
            let s = p.sigma ?? 0
            unten = min(unten, p.wert - s)
            oben = max(oben, p.wert + s)
        }
        if oben - unten < 1e-9 {
            unten -= 0.5
            oben += 0.5
        }
        let luft = (oben - unten) * 0.08
        return (unten - luft, oben + luft)
    }

    private func male(in g: inout GraphicsContext, flaeche: CGSize) {
        let (unten, oben) = grenzen()
        let spanne = oben - unten
        let x = { (i: Int) in
            CGFloat(i) / CGFloat(max(1, punkte.count - 1)) * flaeche.width
        }
        let y = { (w: Double) in
            flaeche.height - CGFloat((w - unten) / spanne) * flaeche.height
        }

        // Der geltende Wert.
        var marke = Path()
        marke.move(to: CGPoint(x: 0, y: y(geltend)))
        marke.addLine(to: CGPoint(x: flaeche.width, y: y(geltend)))
        g.stroke(
            marke, with: .color(Farbe.text3),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Das Band: oben hin, unten zurück.
        var band = Path()
        for (i, p) in punkte.enumerated() {
            let stelle = CGPoint(x: x(i), y: y(p.wert + (p.sigma ?? 0)))
            if i == 0 { band.move(to: stelle) } else { band.addLine(to: stelle) }
        }
        for (i, p) in punkte.enumerated().reversed() {
            band.addLine(to: CGPoint(x: x(i), y: y(p.wert - (p.sigma ?? 0))))
        }
        band.closeSubpath()
        g.fill(band, with: .color(farbe.opacity(0.18)))

        var linie = Path()
        for (i, p) in punkte.enumerated() {
            let stelle = CGPoint(x: x(i), y: y(p.wert))
            if i == 0 { linie.move(to: stelle) } else { linie.addLine(to: stelle) }
        }
        g.stroke(
            linie, with: .color(farbe),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

        // Der jüngste Stand bekommt einen Punkt: er ist der, der zur Übernahme ansteht.
        if let letzter = punkte.last {
            let stelle = CGPoint(x: x(punkte.count - 1), y: y(letzter.wert))
            g.fill(
                Path(
                    ellipseIn: CGRect(
                        x: stelle.x - 2.5, y: stelle.y - 2.5, width: 5, height: 5)),
                with: .color(farbe))
        }
    }
}

// MARK: - Frequenzkennlinie

/// Das Bode-Diagramm des offenen Kreises, klein: Betrag in dB, Phase in Grad, über der
/// Kreisfrequenz.
///
/// **Warum es auch ans Telefon gehört.** Phasen- und Amplitudenreserve sind zwei Zahlen aus
/// diesem Bild, und sie sagen nicht, **wie** der Kreis dorthin kommt: ob die Phase sanft fällt
/// oder an einer Totzeit abstürzt, ist derselbe Zahlenwert und ein anderer Regelkreis. Die zwei
/// Hilfslinien machen die Reserven ablesbar: 0 dB im oberen Feld, −180° im unteren, und die
/// Durchtrittsfrequenz als Senkrechte durch beide.
///
/// Gerechnet wird nichts: die Punkte kommen aus dem Entwurf im Kern des Dienstes.
struct Frequenzbild: View {
    let punkte: [KennliniePunkt]
    /// Die Durchtrittsfrequenz in rad/min, wo es eine gibt.
    var durchtritt: Double?
    var hoehe: CGFloat = 76

    /// Das untere Feld bekommt mehr Platz: dort liegt die Phasenreserve, und dort wird
    /// abgelesen.
    private let fuge: CGFloat = 4

    var body: some View {
        if punkte.count < 2 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Canvas { g, flaeche in male(in: &g, flaeche: flaeche) }
                    .frame(height: hoehe)
                beschriftung
            }
            .accessibilityLabel("Frequenzkennlinie des offenen Kreises")
        }
    }

    private var beschriftung: some View {
        HStack(spacing: 0) {
            Text("ω klein")
            Spacer(minLength: 4)
            Text("|L| in dB · ∠L in Grad")
            Spacer(minLength: 4)
            Text("ω groß")
        }
        .font(Schrift.mono(9))
        .foregroundStyle(Farbe.text3)
        .accessibilityHidden(true)
    }

    /// Die Frequenzachse ist logarithmisch - die gesuchten Frequenzen liegen über Dekaden, und
    /// linear aufgetragen klebte der ganze Verlauf am linken Rand.
    private func x(_ w: Double, _ breite: CGFloat) -> CGFloat {
        let lo = log10(max(punkte.first?.w ?? 1e-4, 1e-9))
        let hi = log10(max(punkte.last?.w ?? 1.0, 1e-9))
        let spanne = max(hi - lo, 1e-9)
        return CGFloat((log10(max(w, 1e-9)) - lo) / spanne) * breite
    }

    private func male(in g: inout GraphicsContext, flaeche: CGSize) {
        let hoch = (flaeche.height - fuge) / 2
        male(feld: CGRect(x: 0, y: 0, width: flaeche.width, height: hoch), in: &g,
             werte: punkte.map(\.db), unten: -40, oben: 40, hilfslinie: 0,
             farbe: Farbe.amber)
        male(feld: CGRect(x: 0, y: hoch + fuge, width: flaeche.width, height: hoch), in: &g,
             werte: punkte.map(\.grad), unten: -270, oben: 0, hilfslinie: -180,
             farbe: Farbe.mist)
        guard let durchtritt else { return }
        var senkrechte = Path()
        let d = x(durchtritt, flaeche.width)
        senkrechte.move(to: CGPoint(x: d, y: 0))
        senkrechte.addLine(to: CGPoint(x: d, y: flaeche.height))
        g.stroke(
            senkrechte, with: .color(Farbe.papier.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
    }

    /// Ein Feld: Rahmen, Hilfslinie, Kurve. Beschnitten wird nicht gezeichnet, sondern
    /// begrenzt - eine Kurve, die aus dem Feld läuft, legt sich auf seinen Rand und bleibt
    /// damit lesbar.
    private func male(
        feld: CGRect, in g: inout GraphicsContext, werte: [Double], unten: Double, oben: Double,
        hilfslinie: Double, farbe: Color
    ) {
        let spanne = max(oben - unten, 1e-9)
        func y(_ wert: Double) -> CGFloat {
            let teil = min(1.0, max(0.0, (wert - unten) / spanne))
            return feld.maxY - CGFloat(teil) * feld.height
        }
        g.fill(
            Path(roundedRect: feld, cornerRadius: 2),
            with: .color(Farbe.papier.opacity(0.04)))
        var hilfe = Path()
        hilfe.move(to: CGPoint(x: feld.minX, y: y(hilfslinie)))
        hilfe.addLine(to: CGPoint(x: feld.maxX, y: y(hilfslinie)))
        g.stroke(
            hilfe, with: .color(Farbe.papier.opacity(0.3)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        var kurve = Path()
        for (i, wert) in werte.enumerated() where i < punkte.count {
            let stelle = CGPoint(x: x(punkte[i].w, feld.width), y: y(wert))
            if i == 0 { kurve.move(to: stelle) } else { kurve.addLine(to: stelle) }
        }
        g.stroke(
            kurve, with: .color(farbe),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }
}
