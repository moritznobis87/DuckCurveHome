import DuckCurveKit
import SwiftUI

/// Die Bühne: das Haus unter seinem Himmel.
///
/// Die Sonne steht auf ihrem Bogen an der Stelle, an der sie gerade ist; nachts stehen Mond und
/// Sterne da. Strom fließt als leuchtendes Band, dessen Breite die Leistung zeigt. Das Kabel vom
/// Netz und das Rohr zur Wärmepumpe laufen unter der Erde, und das Haus in der Mitte trägt die
/// Summe. Jede Sache führt auf ihre Seite; die Wärmepumpe öffnet ihre Auswahl.
///
/// Dasselbe Bild wie `Buehne.tsx` im Dashboard. Die Maße kommen aus ``Startbuehne``, die Werte
/// und Wörter aus ``Startfluss``; hier wird nur gezeichnet.
struct Buehnenbild: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.accessibilityReduceMotion) private var ruhig

    /// Mond und Sterne statt der Sonne.
    let nacht: Bool
    /// Wie weit die Sonne auf dem Bogen ist, von 0 bis 1.
    let stand: Double
    /// Aufgang und Untergang des Tages für die Enden des Bogens.
    let lauf: Ruhebild.Sonnenlauf?
    /// Wann die Sonne wiederkommt, als Uhrzeit.
    let sonneAb: String?

    @State private var versatz: CGFloat = 0

    private var wpLaeuft: Bool { haus.zustand?.heatPump.running ?? false }

    var body: some View {
        GeometryReader { raum in
            let m = Startbuehne.mass(breite: raum.size.width, hoehe: raum.size.height)
            let f = Startfluss.aus(haus.augenblick)
            ZStack(alignment: .topLeading) {
                Startbildgrund(nacht: nacht)
                Canvas { g, groesse in
                    zeichneHimmel(&g, groesse, m, f)
                }
                .allowsHitTesting(false)
                baender(m, raum.size, f)
                Canvas { g, _ in
                    zeichneSachen(&g, m, f)
                }
                .allowsHitTesting(false)
                schrift(m, raum.size, f)
                tippfelder(m, f)
            }
            .opacity(haus.gestoert ? 0.5 : 1)
            .saturation(haus.gestoert ? 0.55 : 1)
            .overlay(alignment: .top) {
                Startbildmarke()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Farbe.linie1, lineWidth: 1)
        )
        .onAppear { laufe() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Das Haus unter seinem Himmel: woher der Strom gerade kommt und wohin er fließt")
    }

    /// Die Lichtpunkte auf den Bändern wandern; wer Bewegung abgestellt hat, sieht sie stehen.
    private func laufe() {
        guard !ruhig else { return }
        versatz = 0
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            versatz = -38
        }
    }

    // MARK: - Himmel und Boden

    private func zeichneHimmel(
        _ g: inout GraphicsContext, _ groesse: CGSize, _ m: Startbuehne.Mass, _ f: Startfluss
    ) {
        let w: Double = groesse.width
        let h: Double = groesse.height
        let boden: Double = m.boden
        if nacht {
            for stern in Startbildform.sterne(breite: w, hoehe: boden - 70, zahl: m.schmal ? 34 : 70) {
                let rahmen = CGRect(
                    x: stern.x - stern.r, y: stern.y - stern.r, width: stern.r * 2, height: stern.r * 2)
                g.fill(Path(ellipseIn: rahmen), with: .color(.white.opacity(0.25 + stern.r * 0.35)))
            }
        }
        g.stroke(
            Startbildform.bogen(m, bis: 1),
            with: .color(.white.opacity(nacht ? 0.16 : 0.3)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 7]))
        if nacht {
            let mx: Double = w * (m.schmal ? 0.76 : 0.7)
            let my: Double = m.schmal ? 40 : 54
            let hof = CGRect(x: mx - 62, y: my - 62, width: 124, height: 124)
            g.fill(Path(ellipseIn: hof), with: .color(Farbe.amberWeich.opacity(0.07)))
            let voll = Path(ellipseIn: CGRect(x: mx - 15, y: my - 15, width: 30, height: 30))
            let schatten = Path(ellipseIn: CGRect(x: mx - 6, y: my - 21, width: 30, height: 30))
            g.fill(voll.subtracting(schatten), with: .color(Farbe.amberWeich))
        } else {
            let sonne = Startbuehne.sonnenort(m, anteil: stand)
            let ort = CGPoint(x: sonne.x, y: sonne.y)
            g.stroke(
                Startbildform.bogen(m, bis: stand),
                with: .color(Farbe.amber.opacity(0.85)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round))
            let schein: Double = m.schmal ? 78 : 104
            let scheinfeld = CGRect(
                x: sonne.x - schein, y: sonne.y - schein, width: schein * 2, height: schein * 2)
            g.fill(
                Path(ellipseIn: scheinfeld),
                with: .radialGradient(
                    Gradient(colors: [Farbe.amber.opacity(0.55), Farbe.amber.opacity(0)]),
                    center: ort, startRadius: 0, endRadius: schein))
            if f.pv >= Startbuehne.flussAbKw {
                let dx: Double = m.hausHalb + m.ueber
                let halb: Double = min(dx - 6, 18 + f.pv * 14)
                let spitze: Double = boden - m.hausHoch - m.dach
                let kegelY: Double = boden - m.hausHoch - m.dach * (1 - halb / dx) - 3
                var kegel = Path()
                kegel.move(to: CGPoint(x: sonne.x - 9, y: sonne.y + 6))
                kegel.addLine(to: CGPoint(x: sonne.x + 9, y: sonne.y + 6))
                kegel.addLine(to: CGPoint(x: m.mitte + halb, y: kegelY))
                kegel.addLine(to: CGPoint(x: m.mitte, y: spitze - 3))
                kegel.addLine(to: CGPoint(x: m.mitte - halb, y: kegelY))
                kegel.closeSubpath()
                g.fill(
                    kegel,
                    with: .linearGradient(
                        Gradient(colors: [Farbe.amber.opacity(0.62), Farbe.amber.opacity(0.16)]),
                        startPoint: ort, endPoint: CGPoint(x: m.mitte, y: boden - m.hausHoch)))
            }
            let scheibe = CGRect(x: sonne.x - 16, y: sonne.y - 16, width: 32, height: 32)
            g.fill(Path(ellipseIn: scheibe), with: .color(Farbe.amberWeich))
        }

        // Der Boden: ein flacher Hügel, darunter die Erde, in der Kabel und Rohr liegen.
        var huegel = Path()
        huegel.move(to: CGPoint(x: 0, y: boden - 10))
        huegel.addCurve(
            to: CGPoint(x: w * 0.5, y: boden - 14),
            control1: CGPoint(x: w * 0.18, y: boden - 30),
            control2: CGPoint(x: w * 0.32, y: boden - 4))
        huegel.addCurve(
            to: CGPoint(x: w, y: boden - 8),
            control1: CGPoint(x: w * 0.68, y: boden - 24),
            control2: CGPoint(x: w * 0.82, y: boden - 34))
        huegel.addLine(to: CGPoint(x: w, y: boden))
        huegel.addLine(to: CGPoint(x: 0, y: boden))
        huegel.closeSubpath()
        g.fill(huegel, with: .color(Farbe.deep.opacity(0.45)))
        g.fill(
            Path(CGRect(x: 0, y: boden, width: w, height: h - boden)),
            with: .linearGradient(
                Gradient(colors: [Farbe.deep.opacity(0.9), Farbe.deep.opacity(0.55)]),
                startPoint: CGPoint(x: 0, y: boden), endPoint: CGPoint(x: 0, y: h)))
        var kante = Path()
        kante.move(to: CGPoint(x: 0, y: boden))
        kante.addLine(to: CGPoint(x: w, y: boden))
        g.stroke(kante, with: .color(Farbe.linie2), lineWidth: 1)
    }

    // MARK: - Die Bänder

    @ViewBuilder
    private func baender(_ m: Startbuehne.Mass, _ groesse: CGSize, _ f: Startfluss) -> some View {
        let boden: Double = m.boden
        let hausEin: Double = m.mitte - m.hausHalb * (m.schmal ? 0.8 : 0.5)
        Startband(
            pfad: Startbildform.unterirdisch(
                von: m.netzX, nach: hausEin, boden: boden, tief: m.tief,
                kappe: Startbuehne.bandkappe(f.netz)),
            kw: f.netz, farbe: f.einspeisung ? Farbe.netzEinspeisung : Farbe.netzBezug,
            versatz: f.einspeisung ? -versatz : versatz)
        Startband(
            pfad: Startbildform.gerade(
                von: m.mitte + m.hausHalb, nach: m.speicherX - 20, hoehe: boden - 26),
            kw: f.speicherBand, farbe: Farbe.batterie,
            versatz: f.speicherWort == .laedt ? versatz : -versatz)
        if m.schmal {
            // Am Telefon hängen Wallbox und Wärmepumpe als zwei Kacheln unter der Bühne.
            Startband(
                pfad: Startbildform.hinunter(
                    von: m.mitte - 22, nach: groesse.width * 0.25, boden: boden,
                    fuss: groesse.height),
                kw: f.ev, farbe: Farbe.wallbox, versatz: versatz)
            Startband(
                pfad: Startbildform.hinunter(
                    von: m.mitte + 22, nach: groesse.width * 0.75, boden: boden,
                    fuss: groesse.height),
                kw: f.hp, farbe: Farbe.waermepumpe, versatz: versatz)
        } else {
            Startband(
                pfad: Startbildform.gerade(
                    von: m.mitte - m.hausHalb, nach: m.wallboxX + 26, hoehe: boden - 20),
                kw: f.ev, farbe: Farbe.wallbox, versatz: versatz)
            Startband(
                pfad: Startbildform.unterirdisch(
                    von: m.mitte + m.hausHalb * 0.5, nach: m.pumpeX, boden: boden, tief: m.tief),
                kw: f.hp, farbe: Farbe.waermepumpe, versatz: versatz)
        }
    }

    // MARK: - Speicher, Wärmepumpe und das Haus

    private func zeichneSachen(_ g: inout GraphicsContext, _ m: Startbuehne.Mass, _ f: Startfluss) {
        let boden: Double = m.boden
        // Der Speicher: eine Batterie, gefüllt nach Ladestand.
        let bx: Double = m.speicherX
        let soc: Double = max(0, min(1, f.soc ?? 0))
        g.fill(
            Path(roundedRect: CGRect(x: bx - 7, y: boden - 67, width: 14, height: 6), cornerRadius: 2),
            with: .color(Farbe.batterie))
        let gehaeuse = Path(
            roundedRect: CGRect(x: bx - 19, y: boden - 62, width: 38, height: 60), cornerRadius: 8)
        g.fill(gehaeuse, with: .color(Farbe.flaeche1))
        g.stroke(gehaeuse, with: .color(Farbe.batterie), lineWidth: 2)
        if soc > 0 {
            let fuellung = CGRect(x: bx - 14, y: boden - 7 - 50 * soc, width: 28, height: 50 * soc)
            g.fill(Path(roundedRect: fuellung, cornerRadius: 4), with: .color(Farbe.batterie))
        }

        if !m.schmal {
            // Die Wärmepumpe: das Außengerät mit Lüfter und Lamellen.
            let px: Double = m.pumpeX
            let ton: Color = wpLaeuft ? Farbe.waermepumpe : Farbe.text3
            let kasten = Path(
                roundedRect: CGRect(x: px - 31, y: boden - 50, width: 62, height: 48), cornerRadius: 8)
            g.fill(kasten, with: .color(Farbe.flaeche1))
            g.stroke(kasten, with: .color(ton), lineWidth: 2)
            let luefter = CGRect(x: px - 24, y: boden - 41, width: 30, height: 30)
            g.stroke(Path(ellipseIn: luefter), with: .color(ton), lineWidth: 1.6)
            var kreuz = Path()
            kreuz.move(to: CGPoint(x: px - 9, y: boden - 37))
            kreuz.addLine(to: CGPoint(x: px - 9, y: boden - 15))
            kreuz.move(to: CGPoint(x: px - 20, y: boden - 26))
            kreuz.addLine(to: CGPoint(x: px + 2, y: boden - 26))
            g.stroke(kreuz, with: .color(ton), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            var lamellen = Path()
            for versatzY in [38.0, 30.0, 22.0, 14.0] {
                lamellen.move(to: CGPoint(x: px + 15, y: boden - versatzY))
                lamellen.addLine(to: CGPoint(x: px + 24, y: boden - versatzY))
            }
            g.stroke(lamellen, with: .color(ton), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        // Das Haus: Dach mit zwei Solarplatten, darunter der Körper, der die Summe trägt.
        let cx: Double = m.mitte
        let dx: Double = m.hausHalb + m.ueber
        let traufe: Double = boden - m.hausHoch
        let spitze: Double = traufe - m.dach
        var dach = Path()
        dach.move(to: CGPoint(x: cx - dx, y: traufe))
        dach.addLine(to: CGPoint(x: cx, y: spitze))
        dach.addLine(to: CGPoint(x: cx + dx, y: traufe))
        dach.closeSubpath()
        g.fill(dach, with: .color(Farbe.flaeche3))
        g.stroke(dach, with: .color(Farbe.linie2), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        let koerper = Path(CGRect(x: cx - m.hausHalb, y: traufe, width: m.hausHalb * 2, height: m.hausHoch))
        g.fill(koerper, with: .color(Farbe.flaeche2))
        g.stroke(koerper, with: .color(Farbe.linie2), lineWidth: 1.5)

        let ertrag: Bool = !nacht && f.pv >= Startbuehne.flussAbKw
        let lang: Double = (dx * dx + m.dach * m.dach).squareRoot()
        var platten = Path()
        for seite in [-1.0, 1.0] {
            // Um fünf Punkte über die Dachhaut gehoben.
            let nx: Double = seite * m.dach / lang * 5
            let ny: Double = -dx / lang * 5
            platten.move(to: CGPoint(x: cx + seite * dx * 0.16 + nx, y: spitze + m.dach * 0.16 + ny))
            platten.addLine(to: CGPoint(x: cx + seite * dx * 0.88 + nx, y: spitze + m.dach * 0.88 + ny))
        }
        g.stroke(
            platten,
            with: .color(ertrag ? Farbe.amber : Farbe.mist.opacity(0.55)),
            style: StrokeStyle(lineWidth: 6, lineCap: .round))
        let giebel = CGRect(x: cx - 8, y: spitze + m.dach * 0.6 - 8, width: 16, height: 16)
        g.fill(Path(ellipseIn: giebel), with: .color(nacht ? Farbe.amberWeich : Farbe.flaeche1))
        g.stroke(Path(ellipseIn: giebel), with: .color(Farbe.linie2), lineWidth: 1)
    }

    // MARK: - Zahlen, Namen und Zeichen

    @ViewBuilder
    private func schrift(_ m: Startbuehne.Mass, _ groesse: CGSize, _ f: Startfluss) -> some View {
        let s = haus.augenblick
        let boden: Double = m.boden
        let gross: CGFloat = m.schmal ? 26 : 30

        // Die Schrift des Himmels steht links oben.
        Group {
            if nacht {
                if let sonneAb {
                    Text("Die Sonne geht um \(sonneAb) auf.")
                        .font(Schrift.sans(m.schmal ? 14 : 15.5))
                        .foregroundStyle(Farbe.text2)
                }
            } else {
                Zahl(
                    wert: Formate.kw(s?.pvPowerKw.value), einheit: "kW Sonne",
                    schrift: Schrift.mono(m.schmal ? 30 : 40), einheitSchrift: Schrift.sans(14),
                    farbe: s?.pvPowerKw.belastbar == nil ? Farbe.text3 : Farbe.amber)
            }
        }
        .fixedSize()
        .padding(.leading, m.schmal ? 16 : 24)
        .padding(.top, m.schmal ? 14 : 20)

        // Aufgang und Untergang an den Enden des Bogens.
        if let lauf {
            Text(Formate.hhmm(lauf.von))
                .font(Schrift.mono(10.5))
                .foregroundStyle(Farbe.text3)
                .fixedSize()
                .position(x: m.bogenRand + 16, y: groesse.height - 14)
            Text(Formate.hhmm(lauf.bis))
                .font(Schrift.mono(10.5))
                .foregroundStyle(Farbe.text3)
                .fixedSize()
                .position(x: groesse.width - m.bogenRand - 16, y: groesse.height - 14)
        }

        let netzfarbe: Color = f.einspeisung ? Farbe.netzEinspeisung : Farbe.netzBezug
        Zeichen(
            .netz, groesse: m.schmal ? 46 : 53,
            farbe: s?.gridPowerKw.belastbar == nil ? Farbe.text3 : netzfarbe, strich: 1.4
        )
        .position(x: m.netzX, y: boden - (m.schmal ? 20 : 23))
        Startschild(
            zahl: Formate.kw(f.netz), einheit: "kW", name: f.netzName,
            anker: m.schmal ? .leading : .center, gross: gross,
            leise: s?.gridPowerKw.belastbar == nil, hof: true
        )
        .position(x: m.schmal ? 10 + Startschild.breite / 2 : m.netzX, y: m.schildY - 4)

        Startschild(
            zahl: f.socText, einheit: "%", name: f.speicherName,
            anker: m.schmal ? .trailing : .center, gross: gross,
            leise: s?.batterySoc.belastbar == nil, hof: true
        )
        .position(
            x: m.schmal ? groesse.width - 10 - Startschild.breite / 2 : m.speicherX, y: m.schildY - 4)

        if !m.schmal {
            Zeichen(.auto, groesse: 50, farbe: f.wallboxLaedt ? Farbe.wallbox : Farbe.text3, strich: 1.45)
                .position(x: m.wallboxX, y: boden - 20)
            Startschild(
                zahl: Formate.kw(s?.evPowerKw.value), einheit: "kW", name: f.wallboxName,
                anker: .center, gross: gross, leise: !f.wallboxLaedt
            )
            .position(x: m.wallboxX, y: m.schildY - 4)
            Startschild(
                zahl: Formate.kw(s?.heatPumpPowerKw.value), einheit: "kW",
                name: f.pumpenName(laeuft: wpLaeuft), anker: .center, gross: gross,
                farbe: wpLaeuft ? Farbe.waermepumpe : Farbe.text1,
                leise: !wpLaeuft && f.hp < Startbuehne.flussAbKw
            )
            .position(x: m.pumpeX, y: m.schildY - 4)
        }

        // Die Summe im Haus.
        Zahl(
            wert: Formate.kw(s?.housePowerKw.value), einheit: "kW",
            schrift: Schrift.mono(m.schmal ? 34 : 40), einheitSchrift: Schrift.sans(13),
            farbe: s?.housePowerKw.belastbar == nil ? Farbe.text3 : Farbe.text1
        )
        .fixedSize()
        .position(x: m.mitte, y: boden - m.hausHoch / 2 - 6)
        Text(f.hausZeile)
            .font(Schrift.sans(12.5))
            .foregroundStyle(Farbe.text2)
            .lineLimit(1)
            .fixedSize()
            .position(x: m.mitte, y: boden - 15)
    }

    // MARK: - Was sich antippen lässt

    @ViewBuilder
    private func tippfelder(_ m: Startbuehne.Mass, _ f: Startfluss) -> some View {
        let boden: Double = m.boden
        let s = haus.augenblick
        Starttippfeld(
            name: "Sonne: \(Formate.kw(s?.pvPowerKw.value)) kW", breite: m.schmal ? 170 : 220, hoehe: 56
        ) { wegweiser.gehe("/strom/pv") }
            .position(x: (m.schmal ? 170 : 220) / 2 + 10, y: 38)
        Starttippfeld(name: "Netz: \(Formate.kw(f.netz)) kW \(f.netzName)", breite: 84, hoehe: 116) {
            wegweiser.gehe("/strom")
        }
        .position(x: m.schmal ? 46 : m.netzX, y: boden - 58)
        Starttippfeld(name: "Speicher: \(f.socText) %, \(f.speicherWort.rawValue)", breite: 84, hoehe: 116) {
            wegweiser.blatt = .batterie
        }
        .position(x: m.speicherX, y: boden - 58)
        Starttippfeld(
            name: "Haus: \(Formate.kw(s?.housePowerKw.value)) kW", breite: m.hausHalb * 2,
            hoehe: m.hausHoch + m.dach
        ) { wegweiser.gehe("/strom") }
            .position(x: m.mitte, y: boden - (m.hausHoch + m.dach) / 2)
        if !m.schmal {
            Starttippfeld(name: f.wallboxName, breite: 96, hoehe: 116) {
                wegweiser.gehe("/strom/wallbox")
            }
            .position(x: m.wallboxX, y: boden - 58)
            Starttippfeld(name: f.pumpenName(laeuft: wpLaeuft), breite: 100, hoehe: 116, auswahl: true) {
                wegweiser.blatt = .waermepumpenmenue
            }
            .position(x: m.pumpeX, y: boden - 58)
        }
    }
}

// MARK: - Was Bühne und Uhr teilen

/// Der Grund hinter dem Bild: nachts dunkel, am Tag mit einem warmen Schein aus der Ecke.
struct Startbildgrund: View {
    let nacht: Bool
    /// Die Uhr trägt ihren Schein in der Mitte statt in der Ecke.
    var mittig = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(Farbwert(0x0A2A3B)), Color(Farbwert(0x113A4C))],
                startPoint: .top, endPoint: .bottom)
            if mittig {
                RadialGradient(
                    colors: [(nacht ? Farbe.mist : Farbe.amber).opacity(0.16), .clear],
                    center: .center, startRadius: 0, endRadius: 320)
            } else if !nacht {
                RadialGradient(
                    colors: [Farbe.amber.opacity(0.22), .clear],
                    center: UnitPoint(x: 0.12, y: 0.08), startRadius: 0, endRadius: 520)
            }
        }
    }
}

/// „Das Bild ist von 18:26.“ Steht über dem Bild, solange die Verbindung unterbrochen ist.
struct Startbildmarke: View {
    @Environment(Hauszustand.self) private var haus

    var body: some View {
        if haus.gestoert, let von = haus.letzterRahmen {
            HStack(spacing: 8) {
                Zeichen(.uhr, groesse: 16, farbe: Farbe.text1)
                Text("Das Bild ist von \(Formate.hhmm(von)).")
                    .font(Schrift.sans(13.5))
                    .foregroundStyle(Farbe.text1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Farbe.deep.opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Farbe.linie2, lineWidth: 1))
            .padding(.top, 14)
        }
    }
}

/// Ein Band: breit nach Leistung, in der Farbe der Sache, mit Lichtpunkten in Flussrichtung.
/// Unter der Schwelle des Flusses ist es nur eine gestrichelte Linie.
struct Startband: View {
    let pfad: Path
    let kw: Double
    let farbe: Color
    let versatz: CGFloat

    var body: some View {
        if kw < Startbuehne.flussAbKw {
            pfad.stroke(
                Color.white.opacity(0.22),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 6]))
        } else {
            let breite: CGFloat = Startbuehne.bandbreite(kw)
            ZStack {
                pfad.stroke(farbe.opacity(0.92), style: StrokeStyle(lineWidth: breite, lineCap: .round))
                    .shadow(color: farbe.opacity(0.7), radius: 6)
                pfad.stroke(
                    Color.white.opacity(0.85),
                    style: StrokeStyle(
                        lineWidth: max(2, breite * 0.28), lineCap: .round, dash: [8, 30],
                        dashPhase: versatz))
            }
        }
    }
}

/// Zahl und Name über einer Sache. Was ruht oder nicht gemessen ist, steht leiser da.
struct Startschild: View {
    static let breite: Double = 176

    let zahl: String
    let einheit: String
    let name: String
    var anker: HorizontalAlignment = .center
    var gross: CGFloat = 30
    var farbe: Color = Farbe.text1
    var leise = false
    /// Ein dunkler Hof um die Schrift. Der Sonnenbogen läuft durch die Zahlen von Netz und
    /// Speicher; mit dem Hof bleibt die Schrift lesbar (`start.css`, `.bild-hof`).
    var hof = false

    var body: some View {
        let schatten: Color = hof ? Farbe.petrol.opacity(0.9) : .clear
        VStack(alignment: anker, spacing: 0) {
            Zahl(
                wert: zahl, einheit: einheit, schrift: Schrift.mono(gross),
                einheitSchrift: Schrift.sans(13), farbe: leise ? Farbe.text3 : farbe)
            Text(name)
                .font(Schrift.sans(12.5))
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
        }
        .shadow(color: schatten, radius: 2)
        .shadow(color: schatten, radius: 2)
        .shadow(color: schatten, radius: 2)
        .fixedSize()
        .frame(width: Self.breite, alignment: Alignment(horizontal: anker, vertical: .center))
        .allowsHitTesting(false)
    }
}

/// Eine durchsichtige Fläche über einer Sache, groß genug für den Finger.
struct Starttippfeld: View {
    let name: String
    let breite: CGFloat
    let hoehe: CGFloat
    var auswahl = false
    let tippen: () -> Void

    var body: some View {
        Button(action: tippen) {
            Color.clear
                .frame(width: breite, height: hoehe)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityHint(auswahl ? "Auswahl öffnen" : "Details öffnen")
    }
}

/// Die Formen, die sich aus den Maßen ergeben: Sonnenbogen, Leitungen, Sterne.
enum Startbildform {
    /// Der Sonnenbogen vom Aufgang bis zu einem Anteil des Tages, als Linienzug.
    static func bogen(_ m: Startbuehne.Mass, bis anteil: Double) -> Path {
        var p = Path()
        let schritte = 60
        let ende = max(1, Int((Double(schritte) * max(0, min(1, anteil))).rounded()))
        for i in 0...ende {
            let ort = Startbuehne.sonnenort(m, anteil: Double(i) / Double(schritte))
            let punkt = CGPoint(x: ort.x, y: ort.y)
            if i == 0 { p.move(to: punkt) } else { p.addLine(to: punkt) }
        }
        return p
    }

    /// Eine Leitung unter der Erde: hinunter, mit runden Ecken hinüber und wieder hinauf.
    ///
    /// `kappe` ist die halbe Breite des Bandes am Anfang: um so viel tiefer setzt die Leitung
    /// an, damit ihre runde Kappe an der Erdkante endet und nicht in die Sache ragt, die dort
    /// steht. Am Mast war das zu sehen (Bild des Hausherrn vom 25.11.2026).
    static func unterirdisch(
        von: Double, nach: Double, boden: Double, tief: Double, kappe: Double = 0
    ) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: von, y: min(tief - 16, boden + 2 + kappe)))
        p.addLine(to: CGPoint(x: von, y: tief - 16))
        p.addQuadCurve(to: CGPoint(x: von + 16, y: tief), control: CGPoint(x: von, y: tief))
        p.addLine(to: CGPoint(x: nach - 16, y: tief))
        p.addQuadCurve(to: CGPoint(x: nach, y: tief - 16), control: CGPoint(x: nach, y: tief))
        p.addLine(to: CGPoint(x: nach, y: boden + 2))
        return p
    }

    static func gerade(von: Double, nach: Double, hoehe: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: von, y: hoehe))
        p.addLine(to: CGPoint(x: nach, y: hoehe))
        return p
    }

    /// Am Telefon: vom Haus hinunter und zur Seite, bis an den Fuß der Bühne über einer Kachel.
    static func hinunter(von: Double, nach: Double, boden: Double, fuss: Double) -> Path {
        let richtung: Double = nach < von ? -1 : 1
        var p = Path()
        p.move(to: CGPoint(x: von, y: boden + 2))
        p.addLine(to: CGPoint(x: von, y: boden + 16))
        p.addQuadCurve(
            to: CGPoint(x: von + richtung * 14, y: boden + 30), control: CGPoint(x: von, y: boden + 30))
        p.addLine(to: CGPoint(x: nach - richtung * 14, y: boden + 30))
        p.addQuadCurve(to: CGPoint(x: nach, y: boden + 44), control: CGPoint(x: nach, y: boden + 30))
        p.addLine(to: CGPoint(x: nach, y: fuss))
        return p
    }

    struct Stern {
        let x: Double
        let y: Double
        let r: Double
    }

    /// Feste Sterne: derselbe Himmel bei jedem Öffnen, aus einem einfachen Zähler statt aus dem
    /// Zufall. Dieselbe Folge wie im Dashboard.
    static func sterne(breite: Double, hoehe: Double, zahl: Int) -> [Stern] {
        var saat = 7
        func naechste() -> Int {
            saat = (saat * 16807) % 2_147_483_647
            return saat
        }
        var out: [Stern] = []
        for _ in 0..<zahl {
            let x = Double(naechste() % 1000) / 1000 * breite
            let y = Double(naechste() % 1000) / 1000 * max(0, hoehe) + 6
            let r = 0.5 + Double(naechste() % 100) / 100
            out.append(Stern(x: x, y: y, r: r))
        }
        return out
    }
}
