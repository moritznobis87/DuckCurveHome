import DuckCurveKit
import SwiftUI

/// Die Wärmepumpe als Zeichnung: Außengerät, Innengerät, Speicher und die vier Leitungen
/// dazwischen, jeder Messwert an der Stelle, an der er entsteht.
///
/// **Was die Zeichnung zeigt und was nicht.** Sie ist ein Funktionsbild, kein Hydraulikplan:
/// drei Kästen und vier Leitungen, damit die Zahlen einen Ort haben. Heißgas und
/// Flüssigkeitsleitung sind der Kältekreis zwischen Außen- und Innengerät, Vorlauf und
/// Rücklauf der Wasserkreis zum Speicher. Mehr behauptet sie nicht.
///
/// **Bewegung heißt: es fließt.** Die Leitungen des Kältekreises laufen, wenn der Verdichter
/// arbeitet, die des Wasserkreises, wenn die Pumpe etwas meldet. Der Lüfter dreht mit seiner
/// Drehzahl. Steht alles, steht auch die Zeichnung – und dann hält `TimelineView` an, statt
/// sechzigmal in der Sekunde dasselbe Bild zu zeichnen.
///
/// **Farbe ist Temperatur**, mit derselben Skala wie Glas und Anlagenschema
/// (`Marken.wasserfarbe`). Text steht immer in den Textfarben; ein Wert, der fehlt oder
/// veraltet ist, steht blass da und als Fragezeichen.
///
/// **Die Maße stehen im Kern** (`Wpbild`), nicht hier: sie sind reine Rechnung und dort
/// geprüft – unter anderem darauf, dass jede Leitung an einem Gerät endet und nicht in der
/// Luft. Diese Datei zeichnet nur.
struct Waermepumpenbild: View {
    let wp: WaermepumpeOut
    var lage: Wpbild.Lage = .breit

    private var fliesstIrgendwo: Bool { wp.laeuft || wp.pumpeLaeuft == true || Wpbild.luefterLaeuft(wp) }

    var body: some View {
        let p = Wpbild.plan(lage)
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !fliesstIrgendwo)) { takt in
            let t = takt.date.timeIntervalSinceReferenceDate
            Canvas { gestalt, groesse in
                let maß = groesse.width / p.sicht.breite
                gestalt.scaleBy(x: maß, y: maß)
                zeichne(&gestalt, plan: p, zeit: t)
            }
        }
        .aspectRatio(p.sicht.breite / p.sicht.hoehe, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Wpbild.satz(wp)
            + " Vorlauf \(Formate.celsius(wp.vorlaufC.belastbar, stellen: 1)),"
            + " Rücklauf \(Formate.celsius(wp.ruecklaufC.belastbar, stellen: 1)),"
            + " Durchfluss \(Formate.zahl(wp.durchflussLMin.belastbar, stellen: 1)) Liter je Minute.")
    }

    private func zeichne(_ g: inout GraphicsContext, plan p: Wpbild.Plan, zeit t: Double) {
        let kaelte = wp.laeuft
        let wasser = wp.pumpeLaeuft == true
        // Erst die Leitungen, dann die Kaesten: die Enden verschwinden unter den Raendern.
        leitung(&g, p.heissgas, wp.heissgasC, fliesst: kaelte, dicke: 5, zeit: t)
        leitung(&g, p.fluessig, wp.fluessigC, fliesst: kaelte, dicke: 5, zeit: t)
        leitung(&g, Wpbild.speistTiefer(wp) ? p.vorlaufTiefer : p.vorlauf, wp.vorlaufC,
                fliesst: wasser, dicke: 7, zeit: t)
        leitung(&g, p.ruecklauf, wp.ruecklaufC, fliesst: wasser, dicke: 7, zeit: t)

        aussengeraet(&g, bei: p.aussen, zeit: t)
        innengeraet(&g, bei: p.innen, zeit: t)
        speicher(&g, bei: p.speicher)

        schild(&g, p.schilder.heissgas, "Heißgas", wp.heissgasC, "°C")
        schild(&g, p.schilder.fluessig, "Flüssigkeit", wp.fluessigC, "°C")
        schild(&g, p.schilder.vorlauf, "Vorlauf", wp.vorlaufC, "°C")
        schild(&g, p.schilder.ruecklauf, "Rücklauf", wp.ruecklaufC, "°C")
    }

    // MARK: - Leitungen

    private func leitung(
        _ g: inout GraphicsContext, _ punkte: [Wpbild.Punkt], _ m: Messwert,
        fliesst: Bool, dicke: Double, zeit: Double
    ) {
        var pfad = Path()
        for (i, q) in punkte.enumerated() {
            let p = CGPoint(x: q.x, y: q.y)
            if i == 0 { pfad.move(to: p) } else { pfad.addLine(to: p) }
        }
        g.stroke(
            pfad, with: .color(Color(Marken.wasserfarbe(m.belastbar)).opacity(fliesst ? 0.95 : 0.4)),
            style: StrokeStyle(lineWidth: dicke, lineCap: .round, lineJoin: .round)
        )
        guard fliesst else { return }
        // Der helle Strich wandert: das ist die ganze Aussage „hier fliesst etwas".
        g.stroke(
            pfad, with: .color(.white.opacity(0.75)),
            style: StrokeStyle(
                lineWidth: max(2, dicke - 4), lineCap: .round, lineJoin: .round,
                dash: [14, 26], dashPhase: -zeit * 40
            )
        )
    }

    // MARK: - Schilder

    private func schild(
        _ g: inout GraphicsContext, _ bei: Wpbild.Punkt, _ name: String, _ m: Messwert?,
        _ einheit: String, wert: String? = nil, breite: Double = Wpbild.schild.breite,
        hoehe: Double = Wpbild.schild.hoehe, gross: Bool = false
    ) {
        let da = m.map { $0.quality.traegt } ?? (wert != nil && wert != "?")
        let text = wert ?? m?.belastbar.map { Formate.zahl($0, stellen: 1) } ?? "?"
        let kasten = Path(
            roundedRect: CGRect(x: bei.x, y: bei.y, width: breite, height: hoehe),
            cornerRadius: 8
        )
        g.opacity = da ? 1 : 0.55
        g.fill(kasten, with: .color(Farbe.flaeche3))
        g.stroke(kasten, with: .color(Farbe.linie2), lineWidth: 1)
        g.draw(
            Text(name).font(.system(size: 10.5)).foregroundStyle(Farbe.text3),
            at: CGPoint(x: bei.x + 10, y: bei.y + 11), anchor: .leading
        )
        g.draw(
            Text(text).font(.system(size: gross ? 19 : 15, design: .monospaced))
                .foregroundStyle(Farbe.text1)
                + Text(einheit.isEmpty ? "" : " \(einheit)")
                .font(.system(size: 10.5)).foregroundStyle(Farbe.text3),
            at: CGPoint(x: bei.x + 10, y: bei.y + hoehe - 13), anchor: .leading
        )
        g.opacity = 1
    }

    // MARK: - Die drei Bloecke

    private func rahmen(_ g: inout GraphicsContext, _ bei: Wpbild.Punkt,
                        _ groesse: (breite: Double, hoehe: Double), _ titel: String) {
        let kasten = Path(
            roundedRect: CGRect(x: bei.x, y: bei.y, width: groesse.breite, height: groesse.hoehe),
            cornerRadius: 14
        )
        g.fill(kasten, with: .color(Farbe.flaeche2))
        g.stroke(kasten, with: .color(Farbe.linie2), lineWidth: 1)
        g.draw(
            Text(titel).font(.system(size: 13, weight: .semibold)).foregroundStyle(Farbe.text1),
            at: CGPoint(x: bei.x + 16, y: bei.y + 22), anchor: .leading
        )
    }

    private func aussengeraet(_ g: inout GraphicsContext, bei: Wpbild.Punkt, zeit: Double) {
        rahmen(&g, bei, Wpbild.aussenBlock, "Außengerät")
        let o = { (dx: Double, dy: Double) in Wpbild.Punkt(bei.x + dx, bei.y + dy) }
        schild(&g, o(14, 40), "Außenluft", wp.aussenC, "°C", breite: 140)
        schild(&g, o(176, 40), "Sauggas", wp.sauggasC, "°C", breite: 140)

        // Der Luefter: ein Ring und drei Fluegel.
        let nabe = CGPoint(x: bei.x + 95, y: bei.y + 142)
        let an = Wpbild.luefterLaeuft(wp)
        g.fill(Path(ellipseIn: CGRect(x: nabe.x - 50, y: nabe.y - 50, width: 100, height: 100)),
               with: .color(Farbe.deep))
        g.stroke(Path(ellipseIn: CGRect(x: nabe.x - 50, y: nabe.y - 50, width: 100, height: 100)),
                 with: .color(Farbe.linie2), lineWidth: 2)
        var fluegelbild = g
        fluegelbild.translateBy(x: nabe.x, y: nabe.y)
        if an { fluegelbild.rotate(by: .radians(zeit * 3.4)) }
        for winkel in [0.0, 120.0, 240.0] {
            var fluegel = fluegelbild
            fluegel.rotate(by: .degrees(winkel))
            var pfad = Path()
            pfad.move(to: .zero)
            pfad.addCurve(to: CGPoint(x: 41, y: -24), control1: CGPoint(x: 13, y: -20),
                          control2: CGPoint(x: 31, y: -30))
            pfad.addCurve(to: .zero, control1: CGPoint(x: 35, y: -6), control2: CGPoint(x: 19, y: 4))
            pfad.closeSubpath()
            fluegel.fill(pfad, with: .color((an ? Farbe.mist : Farbe.linie2).opacity(0.85)))
        }
        g.fill(Path(ellipseIn: CGRect(x: nabe.x - 7, y: nabe.y - 7, width: 14, height: 14)),
               with: .color(Farbe.flaeche3))
        g.draw(Text(Wpbild.luefterwort(wp)).font(.system(size: 9)).foregroundStyle(Farbe.text3),
               at: CGPoint(x: nabe.x, y: bei.y + 201), anchor: .center)

        // Der Verdichter mit seiner Frequenz.
        let v = CGPoint(x: bei.x + 246, y: bei.y + 136)
        g.fill(Path(ellipseIn: CGRect(x: v.x - 36, y: v.y - 36, width: 72, height: 72)),
               with: .color(Farbe.deep))
        g.stroke(Path(ellipseIn: CGRect(x: v.x - 36, y: v.y - 36, width: 72, height: 72)),
                 with: .color(wp.laeuft ? Farbe.waermepumpe : Farbe.linie2), lineWidth: 2.5)
        g.opacity = wp.verdichterHz.quality.traegt ? 1 : 0.55
        g.draw(
            Text(wp.verdichterHz.belastbar.map { Formate.zahl($0, stellen: 0) } ?? "?")
                .font(.system(size: 20, design: .monospaced)).foregroundStyle(Farbe.text1),
            at: CGPoint(x: v.x, y: v.y - 4), anchor: .center
        )
        g.opacity = 1
        g.draw(Text("Hz").font(.system(size: 10.5)).foregroundStyle(Farbe.text3),
               at: CGPoint(x: v.x, y: v.y + 14), anchor: .center)
        g.draw(Text("Verdichter").font(.system(size: 10.5)).foregroundStyle(Farbe.text3),
               at: CGPoint(x: v.x, y: bei.y + 190), anchor: .center)

        schild(&g, o(14, 204), "Verdampfer", wp.verdampferC, "°C", breite: 140)
        let strom = Wpbild.aufnahme(wp)
        schild(&g, o(176, 204), strom.quelle.isEmpty ? "Strom" : "Strom, \(strom.quelle)", nil,
               "kW", wert: strom.kw.map { Formate.zahl($0, stellen: 2) } ?? "?", breite: 140)
    }

    private func innengeraet(_ g: inout GraphicsContext, bei: Wpbild.Punkt, zeit: Double) {
        rahmen(&g, bei, Wpbild.innenBlock, "Innengerät")
        let o = { (dx: Double, dy: Double) in Wpbild.Punkt(bei.x + dx, bei.y + dy) }
        schild(&g, o(14, 40), "Regler meldet", nil, "", wert: wp.kreisDe ?? "?", breite: 128)
        schild(&g, o(150, 40), "Vorlauf soll", wp.vorlaufSollC, "°C", breite: 136)

        // Der Waermetauscher: hier geht die Waerme vom Kaeltemittel ins Wasser.
        let tausch = Path(roundedRect: CGRect(x: bei.x + 30, y: bei.y + 92, width: 56, height: 84),
                          cornerRadius: 6)
        g.fill(tausch, with: .color(Farbe.deep))
        g.stroke(tausch, with: .color(Farbe.linie2), lineWidth: 1)
        var zacken = Path()
        zacken.move(to: CGPoint(x: bei.x + 38, y: bei.y + 104))
        for (i, y) in stride(from: 114.0, through: 164.0, by: 10.0).enumerated() {
            zacken.addLine(to: CGPoint(x: bei.x + (i.isMultiple(of: 2) ? 78 : 38), y: bei.y + y))
        }
        g.stroke(zacken, with: .color(wp.laeuft ? Farbe.waermepumpe : Farbe.linie2),
                 style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        g.draw(Text("Wärmetauscher").font(.system(size: 10.5)).foregroundStyle(Farbe.text3),
               at: CGPoint(x: bei.x + 58, y: bei.y + 192), anchor: .center)

        schild(&g, o(100, 92), "Wärmeleistung", nil, "kW",
               wert: wp.waermeleistungKw.map { Formate.zahl($0, stellen: 1) } ?? "?",
               breite: 186, hoehe: 56, gross: true)

        // Die Umwaelzpumpe. Sie dreht, wenn die Pumpe etwas meldet.
        let pumpe = CGPoint(x: bei.x + 262, y: bei.y + 176)
        let laeuft = wp.pumpeLaeuft == true
        g.fill(Path(ellipseIn: CGRect(x: pumpe.x - 16, y: pumpe.y - 16, width: 32, height: 32)),
               with: .color(Farbe.deep))
        g.stroke(Path(ellipseIn: CGRect(x: pumpe.x - 16, y: pumpe.y - 16, width: 32, height: 32)),
                 with: .color(laeuft ? Farbe.mist : Farbe.linie2), lineWidth: 2)
        var fluegel = g
        fluegel.translateBy(x: pumpe.x, y: pumpe.y)
        if laeuft { fluegel.rotate(by: .radians(zeit * 5.0)) }
        var dreieck = Path()
        dreieck.move(to: CGPoint(x: -7, y: -8))
        dreieck.addLine(to: CGPoint(x: 10, y: 0))
        dreieck.addLine(to: CGPoint(x: -7, y: 8))
        dreieck.closeSubpath()
        fluegel.fill(dreieck, with: .color(laeuft ? Farbe.mist : Farbe.linie2))
        g.draw(Text("Pumpe").font(.system(size: 10.5)).foregroundStyle(Farbe.text3),
               at: CGPoint(x: bei.x + 238, y: bei.y + 176), anchor: .trailing)

        schild(&g, o(100, 204), "Durchfluss", wp.durchflussLMin, "l/min", breite: 186)
    }

    private func speicher(_ g: inout GraphicsContext, bei: Wpbild.Punkt) {
        let t = Wpbild.tank
        g.draw(Text("Speicher").font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Farbe.text1),
            at: CGPoint(x: bei.x + t.x + t.breite / 2 + 14, y: bei.y + 22), anchor: .leading)
        schild(&g, Wpbild.Punkt(bei.x, bei.y), "Fühler WP", wp.speicherfuehlerC, "°C", breite: 98)

        // Wo er sitzt: eine Linie vom Schild an den Rand des Speichers, auf seine Hoehe.
        let hoehe = bei.y + t.y + t.hoehe * Wpbild.fuehlerWp
        var linie = Path()
        linie.move(to: CGPoint(x: bei.x + 98, y: bei.y + Wpbild.schild.hoehe / 2))
        linie.addLine(to: CGPoint(x: bei.x + 116, y: bei.y + Wpbild.schild.hoehe / 2))
        linie.addLine(to: CGPoint(x: bei.x + t.x - 2, y: hoehe))
        g.stroke(linie, with: .color(Farbe.linie2), lineWidth: 1.5)
        g.fill(Path(ellipseIn: CGRect(x: bei.x + t.x - 3.5, y: hoehe - 3.5, width: 7, height: 7)),
               with: .color(Farbe.text2))

        // Das Glas. **Hier gezeichnet und nicht `Pufferglas` eingesetzt**, weil ein Canvas keine
        // Ansichten aufnimmt - Farben und Fuehlerhoehen muessen darum mit jenem im Gleichschritt
        // bleiben. Die Skala kommt aus dem Kern, also kann nur die Hoehe auseinanderlaufen.
        let glas = Path(roundedRect: CGRect(x: bei.x + t.x, y: bei.y + t.y,
                                            width: t.breite, height: t.hoehe), cornerRadius: 14)
        let hoehen = [0.12, 0.38, 0.62, 0.88]
        var stops: [Gradient.Stop] = []
        for (i, m) in wp.pufferC.enumerated() where i < hoehen.count {
            guard let wert = m.belastbar else { continue }
            stops.append(.init(color: Color(Marken.wasserfarbe(wert)), location: hoehen[i]))
        }
        if stops.isEmpty {
            stops = [.init(color: Farbe.flaeche3, location: 0),
                     .init(color: Farbe.flaeche2, location: 1)]
        } else {
            stops.insert(.init(color: stops[0].color, location: 0), at: 0)
            stops.append(.init(color: stops[stops.count - 1].color, location: 1))
        }
        g.fill(glas, with: .linearGradient(
            Gradient(stops: stops),
            startPoint: CGPoint(x: bei.x + t.x, y: bei.y + t.y),
            endPoint: CGPoint(x: bei.x + t.x, y: bei.y + t.y + t.hoehe)))
        g.stroke(glas, with: .color(Farbe.linie2), lineWidth: 1)

        // Die vier Fuehler links daneben, jeder auf seiner Hoehe.
        for (i, m) in wp.pufferC.enumerated() where i < hoehen.count {
            let y = bei.y + t.y + t.hoehe * hoehen[i]
            var strich = Path()
            strich.move(to: CGPoint(x: bei.x + t.x - 4, y: y))
            strich.addLine(to: CGPoint(x: bei.x + t.x - 14, y: y))
            g.stroke(strich, with: .color(Farbe.linie2), lineWidth: 1)
            g.draw(
                Text(m.belastbar.map { "\(Formate.zahl($0, stellen: 0))°" } ?? Formate.leer)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(m.quality.traegt ? Farbe.text1 : Farbe.text3),
                at: CGPoint(x: bei.x + t.x - 20, y: y), anchor: .trailing
            )
        }
    }
}

#if DEBUG
    #Preview("Wärmepumpe, quer") {
        Waermepumpenbild(wp: Vorschau.waermepumpe(), lage: .breit)
            .padding()
            .background(Farbe.grund)
    }

    #Preview("Wärmepumpe, hochkant") {
        Waermepumpenbild(wp: Vorschau.waermepumpe(einspeisung: .tiefer), lage: .hoch)
            .padding()
            .background(Farbe.grund)
    }

    #Preview("Wärmepumpe, steht") {
        Waermepumpenbild(wp: Vorschau.waermepumpe(laeuft: false, pumpe: false, luefter: 0),
                         lage: .breit)
            .padding()
            .background(Farbe.grund)
    }
#endif
