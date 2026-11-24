import DuckCurveKit
import SwiftUI

/// Das Blockschaltbild der Hausregelung, dieselbe Zeichnung wie im Dashboard (`Karte.tsx`).
///
/// Der Hausherr hat am 24.11.2026 festgelegt, dass der Regelkreis überall als Blockschaltbild
/// steht und nirgends als Liste. Gezeichnet wird aus zwei Quellen wie dort: die Topologie kommt
/// aus der Antwort des Dienstes (welche Blöcke, welche Signale, welche Störgrößen), die
/// Geometrie aus ``Schaltbilddaten``, die aus derselben Datei erzeugt ist wie die des
/// Dashboards. Was im Kästchen steht und wie eine Leitung läuft, rechnet der Kern
/// (``Schaltbild``); hier wird nur gezeichnet.
///
/// **Die Farbe am Parameter ist die Herkunft seiner Zahl** (``Herkunftsfarbe``). Eine Karte, auf
/// der eine Annahme aussieht wie eine Messung, verleitet zu Schlüssen, die die Daten nicht
/// tragen.
///
/// **Eine Zeichenfläche und keine dreihundert Ansichten.** Die Karte hat rund vierzig
/// Kästchen, fünfundfünfzig Leitungen und zweihundert Schriftzüge. Auf einer Fläche gezeichnet
/// bleibt sie beim Hineinzoomen scharf und beim Schieben flüssig. Angetippt wird über den Ort:
/// der Kern sagt, welcher Block dort liegt. Für VoiceOver steht jeder Block als Knopf daneben.
///
/// **Was anders ist als im Browser.** Die Formel im Kästchen steht dort kursiv; die Schrift der
/// App hat keinen kursiven Schnitt, sie steht hier gerade. Und der gewählte Block hat dort einen
/// Lichthof; hier trägt ihn der bernsteinfarbene Rand allein.
struct Regelkreiskarte: View {
    let karte: RegelkreisOut
    let sicht: Schaltbild.Sicht
    let gewaehlt: String?
    let waehle: (String) -> Void

    /// Die Mindestbreite der Zeichnung. Darunter wird geschoben statt gestaucht, wie im
    /// Dashboard (`globals.css`, `.rk-karte`: `min-width: 1080px`).
    static let mindestbreite: CGFloat = 1080

    private var ausschnitt: Schaltbild.Rechteck { sicht.ausschnitt }

    var body: some View {
        Canvas { g, groesse in
            male(in: &g, groesse: groesse)
        }
        .aspectRatio(CGFloat(ausschnitt.w / ausschnitt.h), contentMode: .fit)
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { tipp in
                            let massstab = Double(geo.size.width) / ausschnitt.w
                            guard massstab > 0 else { return }
                            let ort = Schaltbild.Punkt(
                                x: Double(tipp.location.x) / massstab + ausschnitt.x,
                                y: Double(tipp.location.y) / massstab + ausschnitt.y)
                            if let id = Schaltbild.block(bei: ort, bloecke: karte.bloecke.map(\.id)) {
                                waehle(id)
                            }
                        }
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Blockschaltbild der Hausregelung: ökonomische Führung, Pufferladung, Erzeuger, "
                + "Vorlauftemperatur, Einzelraumregelung mit ihren Störgrößen."
        )
        .accessibilityChildren {
            ForEach(karte.bloecke, id: \.id) { block in
                Button(block.name) { waehle(block.id) }
                    .accessibilityAddTraits(block.id == gewaehlt ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Zeichnen

    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        // Alles Weitere steht in den Einheiten der Karte: die Fläche wird auf den Ausschnitt
        // gelegt, wie `viewBox` es im Browser tut.
        let massstab = groesse.width / CGFloat(ausschnitt.w)
        g.scaleBy(x: massstab, y: massstab)
        g.translateBy(x: -CGFloat(ausschnitt.x), y: -CGFloat(ausschnitt.y))

        let rechtecke = Schaltbild.rechtecke(bloecke: karte.bloecke.map(\.id))
        var parameter: [String: [ParameterAnsicht]] = [:]
        for p in karte.parameter { parameter[p.block, default: []].append(p) }
        var glieder: [String: GliedAnsicht] = [:]
        for glied in karte.glieder { glieder[glied.id] = glied }

        for ebene in Schaltbilddaten.ebenen {
            schreibe(
                in: &g, ebene.text, x: ebene.x, y: ebene.y, schrift: mono(10.5), farbe: Farbe.mist,
                sperrung: 0.14 * 10.5)
        }

        // Leitungen zuerst, damit die Kästchen darüber liegen.
        for kante in karte.kanten {
            maleLeitung(in: &g, kante, rechtecke: rechtecke)
        }

        // Die Beschriftungen liegen auf ihrer Leitung; ein Feld in Flächenfarbe darunter hält
        // die Linie von der Schrift ab.
        for b in Schaltbilddaten.beschriftungen {
            let breite = CGFloat(b.text.utf16.count) * 5.35 + 10
            let links: CGFloat
            switch b.anker {
            case .middle: links = CGFloat(b.x) - breite / 2
            case .end: links = CGFloat(b.x) - breite
            case .start: links = CGFloat(b.x) - 5
            }
            g.fill(
                Path(CGRect(x: links, y: CGFloat(b.y) - 9, width: breite, height: 12)),
                with: .color(Farbe.flaeche1))
            schreibe(
                in: &g, b.text, x: b.x, y: b.y, schrift: mono(9.5), farbe: Farbe.text3, anker: b.anker)
        }

        for block in karte.bloecke {
            guard let haupt = rechtecke[block.id] else { continue }
            maleBlock(
                in: &g, block, haupt: haupt, parameter: parameter[block.id] ?? [],
                glied: block.glied.flatMap { glieder[$0] })
        }
    }

    // MARK: - Leitungen

    private struct Strich {
        var farbe: Color
        var breite: CGFloat
        var muster: [CGFloat]
    }

    /// Wie eine Leitung aussieht, nach ihrer Art (`globals.css`, `.rk-kante` und Geschwister).
    private func strich(_ art: KanteAnsichtArtWahl) -> Strich {
        switch art {
        case .stoergroesse: return Strich(farbe: Farbe.alarm, breite: 1.2, muster: [5, 3])
        case .rueckfuehrung: return Strich(farbe: Farbe.mist, breite: 1.3, muster: [])
        case .fuehrung: return Strich(farbe: Farbe.amberWeich, breite: 1.6, muster: [])
        case .parameter: return Strich(farbe: Farbe.amber, breite: 1.2, muster: [1.5, 3])
        case .signal, .unbekannt: return Strich(farbe: Farbe.text2, breite: 1.3, muster: [])
        }
    }

    private func maleLeitung(
        in g: inout GraphicsContext, _ kante: KanteAnsicht, rechtecke: [String: Schaltbild.Rechteck]
    ) {
        guard let weg = Schaltbild.weg(von: kante.von, nach: kante.nach, rechtecke: rechtecke),
            weg.punkte.count >= 2
        else { return }
        var stil = strich(kante.art)
        // Die Leitungen des gewählten Blocks treten hervor (`.rk-hell`).
        if let gewaehlt, kante.von == gewaehlt || kante.nach == gewaehlt { stil.breite = 2.4 }

        var pfad = Path()
        for schritt in Schaltbild.schritte(weg.punkte, bogen: weg.bogen) {
            switch schritt {
            case .beginn(let p): pfad.move(to: ort(p))
            case .linie(let p): pfad.addLine(to: ort(p))
            case .bogen(let ende, let imUhrzeigersinn):
                // Ein Halbkreis um die Kreuzung, auf der Seite, die der Browser wählt.
                let von = pfad.currentPoint ?? ort(ende)
                let mitte = CGPoint(x: (von.x + ort(ende).x) / 2, y: (von.y + ort(ende).y) / 2)
                let radius = CGFloat(Schaltbild.bogenradius)
                let start = Angle(radians: atan2(Double(von.y - mitte.y), Double(von.x - mitte.x)))
                pfad.addArc(
                    center: mitte, radius: radius, startAngle: start,
                    endAngle: start + .degrees(180), clockwise: !imUhrzeigersinn)
            }
        }
        g.stroke(
            pfad, with: .color(stil.farbe),
            style: StrokeStyle(lineWidth: stil.breite, lineJoin: .miter, dash: stil.muster))

        // Die Pfeilspitze: im Browser eine Marke von sieben mal sechs Strichbreiten, deren
        // Spitze ein Zehntel über das Ende hinausragt.
        let ende = ort(weg.punkte[weg.punkte.count - 1])
        let davor = ort(weg.punkte[weg.punkte.count - 2])
        let laenge = hypot(ende.x - davor.x, ende.y - davor.y)
        if laenge > 0 {
            let dx = (ende.x - davor.x) / laenge
            let dy = (ende.y - davor.y) / laenge
            let w = stil.breite
            let spitze = CGPoint(x: ende.x + dx * 0.7 * w, y: ende.y + dy * 0.7 * w)
            let fuss = CGPoint(x: ende.x - dx * 6.3 * w, y: ende.y - dy * 6.3 * w)
            var dreieck = Path()
            dreieck.move(to: spitze)
            dreieck.addLine(to: CGPoint(x: fuss.x - dy * 3 * w, y: fuss.y + dx * 3 * w))
            dreieck.addLine(to: CGPoint(x: fuss.x + dy * 3 * w, y: fuss.y - dx * 3 * w))
            dreieck.closeSubpath()
            g.fill(dreieck, with: .color(stil.farbe))
        }

        if let vorzeichen = kante.vorzeichen, vorzeichen != .unbekannt {
            let letzter = weg.punkte[weg.punkte.count - 1]
            schreibe(
                in: &g, vorzeichen == .minus ? "−" : "+", x: letzter.x + 7, y: letzter.y - 6,
                schrift: mono(11), farbe: Farbe.text1)
        }
    }

    // MARK: - Kästchen

    private func maleBlock(
        in g: inout GraphicsContext, _ block: BlockAnsicht, haupt: Schaltbild.Rechteck,
        parameter: [ParameterAnsicht], glied: GliedAnsicht?
    ) {
        let rechtecke = [haupt] + (Schaltbilddaten.plaetze[block.id]?.wdh ?? [])
        let summe = block.rolle == .summierstelle
        let stoer = block.rolle == .stoergroesse
        let ist = block.id == gewaehlt
        let klein = haupt.h <= 44
        // Das Kennbild steht rechts im Kästchen, wo Platz dafür ist; sonst nur das Kurzzeichen.
        let bild = (haupt.h >= 74 && haupt.w >= 150) ? glied : nil
        let gelernt = parameter.contains {
            $0.herkunft == .gemessen || $0.herkunft == .geschaetzt || $0.herkunft == .annahme
        }
        let uebersteuert = parameter.contains { $0.herkunft == .uebersteuert }

        for (i, r) in rechtecke.enumerated() {
            if summe {
                let mitte = ort(r.mitte)
                let kreis = Path(ellipseIn: CGRect(x: mitte.x - 17, y: mitte.y - 17, width: 34, height: 34))
                g.fill(kreis, with: .color(Farbe.flaeche1))
                g.stroke(kreis, with: .color(ist ? Farbe.amber : Farbe.text2), lineWidth: 1.2)
                schreibe(
                    in: &g, "Σ", x: r.mitte.x, y: r.mitte.y + 4, schrift: mono(11), farbe: Farbe.text1,
                    anker: .middle)
                continue
            }
            if block.rolle == .teilkreise {
                // Zwei blasse Rahmen dahinter: es sind mehrere Kreise derselben Art.
                for versatz in [12.0, 6.0] {
                    maleRahmen(
                        in: &g, block.rolle, Schaltbild.Rechteck(x: r.x + versatz, y: r.y - versatz, w: r.w, h: r.h),
                        gewaehlt: false, deckung: 0.35)
                }
            }
            maleRahmen(in: &g, block.rolle, r, gewaehlt: ist, deckung: 1)
            if i > 0 {
                // Eine Wiederholung: derselbe Block an einer zweiten Stelle, mit seinem Namen.
                schreibe(
                    in: &g, "↗", x: r.x + r.w - 7, y: r.y + 11, schrift: mono(9), farbe: Farbe.text3,
                    anker: .end, sperrung: 0.08 * 9)
                schreibe(
                    in: &g, Schaltbild.kuerze(block.name, breite: r.w - 34, proZeichen: 6.4),
                    x: r.x + 10, y: r.y + 21, schrift: stoer ? sans(11.5) : sans(12.5),
                    farbe: stoer ? Farbe.text2 : Farbe.text1)
            }
        }
        if summe { return }

        let zeilen = Schaltbild.stapel(
            block: block, rect: haupt, parameter: Array(parameter.prefix(3)), stoer: stoer,
            klein: klein, oben: gelernt || !(block.gibtMarke ?? "").isEmpty, rechts: bild == nil ? 0 : 54,
            mitFormel: bild == nil)
        for zeile in zeilen {
            let schrift: Font
            let farbe: Color
            switch zeile.art {
            case .name:
                schrift = sans(12.5)
                farbe = Farbe.text1
            case .nameKlein:
                schrift = sans(11.5)
                farbe = Farbe.text2
            case .formel:
                schrift = mono(10.5)
                farbe = Farbe.mist
            case .wert:
                schrift = mono(10.5)
                farbe = zeile.herkunft.map { Herkunftsfarbe.farbe(Regelkreisbild.ton($0)) } ?? Farbe.text2
            }
            schreibe(in: &g, zeile.text, x: haupt.x + 11, y: zeile.y, schrift: schrift, farbe: farbe)
        }

        let rechts = haupt.x + haupt.w
        let unten = haupt.y + haupt.h
        if let bild {
            maleKennbild(in: &g, bild, x: rechts - 50, y: haupt.y + 22)
            schreibe(
                in: &g, bild.kurz, x: rechts - 50 + 21, y: haupt.y + 22 + 36, schrift: mono(9),
                farbe: Farbe.mist, anker: .middle, sperrung: 0.06 * 9)
        } else if let glied {
            schreibe(
                in: &g, glied.kurz, x: rechts - 8, y: unten - 7, schrift: mono(9), farbe: Farbe.mist,
                anker: .end, sperrung: 0.06 * 9)
        }
        if let kreis = block.kreis, !kreis.isEmpty {
            schreibe(
                in: &g, kreis, x: rechts - 8, y: unten - 8, schrift: mono(9), farbe: Farbe.text3,
                anker: .end, sperrung: 0.08 * 9)
        }
        if let gibt = block.gibtMarke, !gibt.isEmpty {
            schreibe(
                in: &g, "\(gibt) ▸", x: rechts - 8, y: haupt.y + 13, schrift: mono(9),
                farbe: Farbe.text3, anker: .end, sperrung: 0.08 * 9)
        }
        if let marke = block.marke, !marke.isEmpty {
            schreibe(
                in: &g, "◂ \(marke)", x: rechts - 8, y: unten - 8, schrift: mono(9),
                farbe: Farbe.text3, anker: .end, sperrung: 0.08 * 9)
        }
        if gelernt {
            // Die Lernmarke: an diesem Block steht mindestens eine Zahl, die das Haus gelernt
            // hat oder lernen wird. Rot, wenn eine davon von Hand übersteuert ist.
            let mitte = CGPoint(x: CGFloat(rechts) - 11, y: CGFloat(haupt.y) + 11)
            g.fill(
                Path(ellipseIn: CGRect(x: mitte.x - 5.5, y: mitte.y - 5.5, width: 11, height: 11)),
                with: .color(uebersteuert ? Farbe.alarm : Farbe.amber))
            schreibe(
                in: &g, "θ", x: rechts - 11, y: haupt.y + 14.5, schrift: mono(7.5), farbe: Farbe.grund,
                anker: .middle)
        }
    }

    /// Der Rahmen eines Kästchens nach seiner Rolle (`globals.css`, `.rk-rahmen` und Geschwister).
    private func maleRahmen(
        in g: inout GraphicsContext, _ rolle: BlockAnsichtRolleWahl, _ r: Schaltbild.Rechteck,
        gewaehlt: Bool, deckung: Double
    ) {
        let stoer = rolle == .stoergroesse
        let form = Path(
            roundedRect: CGRect(x: CGFloat(r.x), y: CGFloat(r.y), width: CGFloat(r.w), height: CGFloat(r.h)),
            cornerRadius: stoer ? 10 : 4)
        let flaeche: Color
        switch rolle {
        case .regler: flaeche = Farbe.flaeche3
        case .stoergroesse: flaeche = Farbe.flaeche1
        default: flaeche = Farbe.flaeche2
        }
        var rand = Farbe.linie2
        var muster: [CGFloat] = []
        switch rolle {
        case .stoergroesse:
            rand = Farbe.alarm
            muster = [3, 2.5]
        case .beobachter:
            rand = Farbe.abweichung.first ?? Farbe.mist
        case .teilkreise:
            muster = [4, 3]
        default:
            break
        }
        g.fill(form, with: .color(flaeche.opacity(deckung)))
        g.stroke(
            form, with: .color((gewaehlt ? Farbe.amber : rand).opacity(deckung)),
            style: StrokeStyle(lineWidth: gewaehlt ? 2 : 1.1, dash: muster))
    }

    /// Das Kennbild im Kästchen: die Antwort des Glieds auf einen Sprung, 42 mal 26 groß
    /// (`Anzeigen.tsx`, `Sprungantwort`).
    private func maleKennbild(in g: inout GraphicsContext, _ glied: GliedAnsicht, x: Double, y: Double) {
        let breite: CGFloat = 42
        let hoehe: CGFloat = 26
        let polster: CGFloat = 2.5
        let links = CGFloat(x)
        let oben = CGFloat(y)
        let px = { (u: Double) in links + polster + CGFloat(u) * (breite - 2 * polster) }
        let py = { (v: Double) in oben + hoehe - polster - CGFloat(v) * (hoehe - 2 * polster) }

        let feld = Path(
            roundedRect: CGRect(x: links + 0.5, y: oben + 0.5, width: breite - 1, height: hoehe - 1),
            cornerRadius: 2)
        g.fill(feld, with: .color(Color.black.opacity(0.26)))
        g.stroke(feld, with: .color(Farbe.linie1), lineWidth: 1)

        var achsen = Path()
        achsen.move(to: CGPoint(x: px(0), y: py(0)))
        achsen.addLine(to: CGPoint(x: px(1), y: py(0)))
        achsen.move(to: CGPoint(x: px(0), y: py(0)))
        achsen.addLine(to: CGPoint(x: px(0), y: py(1)))
        g.stroke(achsen, with: .color(Farbe.linie2), lineWidth: 0.8)

        let kurve = { (punkte: [[Double]]) -> Path in
            var pfad = Path()
            for (i, p) in punkte.enumerated() where p.count >= 2 {
                let stelle = CGPoint(x: px(p[0]), y: py(p[1]))
                if i == 0 { pfad.move(to: stelle) } else { pfad.addLine(to: stelle) }
            }
            return pfad
        }
        if !glied.kurve2.isEmpty {
            g.stroke(
                kurve(glied.kurve2), with: .color(Farbe.mist.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
        }
        g.stroke(
            kurve(glied.kurve), with: .color(Farbe.amber),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Schrift

    /// Die Schriften der Karte in ihren eigenen Einheiten. Fest und nicht an der Schriftgröße des
    /// Geräts: die Karte wird als Ganzes vergrößert, und ein Name, der mit der Systemschrift
    /// wüchse, liefe aus seinem Kästchen.
    private func sans(_ groesse: CGFloat) -> Font { Font.custom(Schrift.sans, fixedSize: groesse) }
    private func mono(_ groesse: CGFloat) -> Font { Font.custom(Schrift.mono, fixedSize: groesse) }

    private func ort(_ p: Schaltbild.Punkt) -> CGPoint { CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)) }

    /// Einen Schriftzug auf seine Grundlinie setzen, wie `<text x y>` in SVG.
    private func schreibe(
        in g: inout GraphicsContext, _ text: String, x: Double, y: Double, schrift: Font, farbe: Color,
        anker: Schaltbild.Anker = .start, sperrung: CGFloat = 0
    ) {
        let gesetzt = g.resolve(Text(text).font(schrift).kerning(sperrung).foregroundStyle(farbe))
        let platz = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let breite = gesetzt.measure(in: platz).width
        let grundlinie = gesetzt.firstBaseline(in: platz)
        let links: CGFloat
        switch anker {
        case .start: links = CGFloat(x)
        case .middle: links = CGFloat(x) - breite / 2
        case .end: links = CGFloat(x) - breite
        }
        g.draw(gesetzt, at: CGPoint(x: links, y: CGFloat(y) - grundlinie), anchor: .topLeading)
    }
}
