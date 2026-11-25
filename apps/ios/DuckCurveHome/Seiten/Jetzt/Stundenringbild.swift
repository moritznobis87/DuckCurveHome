import DuckCurveKit
import SwiftUI

/// Die Uhr: ein Ring über 24 Stunden mit 00 Uhr oben.
///
/// Außen zeigen Speichen den Strompreis, innen leuchtet ein Bogen, wo Sonne erwartet wird, und
/// kurze Striche zeigen die geplanten Läufe von Wärmepumpe und Ofen. Ein Zeiger steht auf jetzt;
/// vom Zeiger an im Uhrzeigersinn liest man den kommenden Tag. In der Mitte steht, was das Haus
/// gerade braucht. An der Wand stehen links Sonne und Netz und rechts Speicher, Wärmepumpe und
/// Wallbox, jede Sache mit einem Band zum Ring; am Telefon stehen die fünf als Liste darunter
/// (``Startdingliste``).
///
/// Dasselbe Bild wie `Uhr.tsx` im Dashboard. Die Maße kommen aus ``Stundenring``.
struct Stundenringbild: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.accessibilityReduceMotion) private var ruhig

    let nacht: Bool
    let ausblick: Ausblick
    /// Wann die Sonne wiederkommt, als Uhrzeit.
    let sonneAb: String?

    @State private var versatz: CGFloat = 0

    private static let kastenbreite: Double = 166
    private static let kastenhoehe: Double = 62

    var body: some View {
        GeometryReader { raum in
            let m = Stundenring.mass(breite: raum.size.width, hoehe: raum.size.height)
            let f = Startfluss.aus(haus.augenblick)
            let schmal: Bool = raum.size.width < 520
            ZStack(alignment: .topLeading) {
                Startbildgrund(nacht: nacht, mittig: true)
                Canvas { g, _ in
                    zeichneRing(&g, m, schmal)
                }
                .allowsHitTesting(false)
                if !schmal {
                    ForEach(dinge(f)) { ding in
                        seitenband(ding, m, raum.size)
                        kasten(ding, raum.size)
                    }
                }
                mitte(m, f, schmal)
                legende
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, schmal ? 14 : 22)
                    .padding(.bottom, 10)
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
            "Ein Ring über 24 Stunden mit Strompreis, erwarteter Sonne und den Läufen der Wärmepumpe")
    }

    private func laufe() {
        guard !ruhig else { return }
        versatz = 0
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            versatz = -38
        }
    }

    private func dinge(_ f: Startfluss) -> [Startding] {
        Startding.alle(
            fluss: f, augenblick: haus.augenblick, nacht: nacht, sonneAb: sonneAb,
            wpLaeuft: haus.zustand?.heatPump.running ?? false, wegweiser: wegweiser)
    }

    // MARK: - Der Ring

    private func zeichneRing(_ g: inout GraphicsContext, _ m: Stundenring.Mass, _ schmal: Bool) {
        let rand: Double = m.radius + 8
        let aussen = CGRect(x: m.mitteX - rand, y: m.mitteY - rand, width: rand * 2, height: rand * 2)
        g.fill(Path(ellipseIn: aussen), with: .color(Farbe.deep.opacity(0.42)))
        g.stroke(Path(ellipseIn: aussen), with: .color(Farbe.linie1), lineWidth: 1)
        let spur = CGRect(
            x: m.mitteX - m.sonne, y: m.mitteY - m.sonne, width: m.sonne * 2, height: m.sonne * 2)
        g.stroke(Path(ellipseIn: spur), with: .color(.white.opacity(0.07)), lineWidth: 9)

        let sonneMax: Double = max(ausblick.pvMax, 3)
        let speiche: CGFloat = schmal ? 8 : 10
        for st in Stundenring.stunden24(ausblick.zellen, guenstig: ausblick.guenstig) {
            let stunde = Double(st.stunde)
            let a: Double = Stundenring.winkel(stunde: stunde + 0.5)
            if let preis = st.preis {
                let laenge: Double = 6 + Stundenring.preislaenge(preis, hoechster: ausblick.preisMax) * 34
                g.stroke(
                    Ringform.strahl(m, von: m.preis, bis: m.preis + laenge, winkel: a),
                    with: .color(Farbe.mist.opacity(st.tief ? 1 : 0.42)),
                    style: StrokeStyle(lineWidth: speiche, lineCap: .round))
            } else {
                // Für diese Stunde gibt es noch keinen Preis.
                g.stroke(
                    Ringform.strahl(m, von: m.preis, bis: m.preis + 14, winkel: a),
                    with: .color(Farbe.mist.opacity(0.5)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 5]))
            }
            if st.sonneKw > Startbuehne.flussAbKw {
                let deckung: Double = min(1, 0.15 + st.sonneKw / sonneMax * 0.85)
                g.stroke(
                    Ringform.bogen(m, radius: m.sonne, von: stunde - 0.02, bis: stunde + 1.02),
                    with: .color(Farbe.pv.opacity(deckung)), lineWidth: 9)
            }
            if st.wp {
                g.stroke(
                    Ringform.bogen(m, radius: m.pumpe, von: stunde + 0.08, bis: stunde + 0.92),
                    with: .color(Farbe.waermepumpe),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            if st.ofen {
                g.stroke(
                    Ringform.bogen(m, radius: m.pumpe - 8, von: stunde + 0.08, bis: stunde + 0.92),
                    with: .color(Farbe.ofen),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }

        // Der Zeiger für jetzt, in der Zeit des Hauses.
        let teile = Kalender.haus.dateComponents([.hour, .minute], from: haus.jetzt)
        let uhrzeit: Double = Double(teile.hour ?? 0) + Double(teile.minute ?? 0) / 60
        let jetzt: Double = Stundenring.winkel(stunde: uhrzeit)
        g.stroke(
            Ringform.strahl(m, von: m.pumpe - 8, bis: rand, winkel: jetzt),
            with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        let spitze = Ringform.punkt(m, radius: rand, winkel: jetzt)
        let knopf = CGRect(x: spitze.x - 5.5, y: spitze.y - 5.5, width: 11, height: 11)
        g.fill(Path(ellipseIn: knopf), with: .color(.white))
    }

    /// Die Mitte: was das Haus gerade braucht. 00 Uhr steht oben und 12 Uhr unten als Zahl.
    @ViewBuilder
    private func mitte(_ m: Stundenring.Mass, _ f: Startfluss, _ schmal: Bool) -> some View {
        let s = haus.augenblick
        Text("00 Uhr")
            .font(Schrift.mono(11))
            .foregroundStyle(Farbe.text3)
            .fixedSize()
            .position(x: m.mitteX, y: m.mitteY - m.zahl)
        Text("12 Uhr")
            .font(Schrift.mono(11))
            .foregroundStyle(Farbe.text3)
            .fixedSize()
            .position(x: m.mitteX, y: m.mitteY + m.zahl)
        Button {
            wegweiser.gehe("/strom")
        } label: {
            VStack(spacing: 2) {
                Zahl(
                    wert: Formate.kw(s?.housePowerKw.value), einheit: "kW",
                    schrift: Schrift.mono(schmal ? 42 : 48), einheitSchrift: Schrift.sans(14),
                    farbe: s?.housePowerKw.belastbar == nil ? Farbe.text3 : Farbe.text1)
                Text(f.hausZeile)
                    .font(Schrift.sans(12.5))
                    .foregroundStyle(Farbe.text2)
                    .lineLimit(1)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Details öffnen")
        .position(x: m.mitteX, y: m.mitteY + 4)
    }

    private var legende: some View {
        HStack(spacing: 14) {
            legendenwort(Farbe.mist, "Strompreis")
            legendenwort(Farbe.pv, "Sonne erwartet")
            legendenwort(Farbe.waermepumpe, "Wärmepumpe")
        }
        .allowsHitTesting(false)
    }

    private func legendenwort(_ farbe: Color, _ wort: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(farbe).frame(width: 12, height: 5)
            Text(wort)
                .font(Schrift.sans(11.5))
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
        }
        .fixedSize()
    }

    // MARK: - Die Sachen neben dem Ring

    private func kastenmitte(_ ding: Startding, _ groesse: CGSize) -> CGPoint {
        let halb: Double = Self.kastenbreite / 2
        let x: Double = ding.links ? 20 + halb : groesse.width - 20 - halb
        return CGPoint(x: x, y: groesse.height * ding.hoehe)
    }

    /// Das Band zwischen dem Kasten und dem Ring, geschwungen und in Flussrichtung belebt.
    private func seitenband(_ ding: Startding, _ m: Stundenring.Mass, _ groesse: CGSize) -> some View {
        let ort = kastenmitte(ding, groesse)
        let halb: Double = Self.kastenbreite / 2
        let kante: Double = ding.links ? ort.x + halb : ort.x - halb
        let ziel = Ringform.punkt(m, radius: m.radius + 12, winkel: ding.grad * Double.pi / 180)
        let quer: Double = (kante + ziel.x) / 2
        var pfad = Path()
        pfad.move(to: CGPoint(x: kante, y: ort.y))
        pfad.addCurve(
            to: ziel, control1: CGPoint(x: quer, y: ort.y), control2: CGPoint(x: quer, y: ziel.y))
        return Startband(
            pfad: pfad, kw: ding.kw, farbe: ding.farbe, versatz: ding.zumRing ? versatz : -versatz)
    }

    private func kasten(_ ding: Startding, _ groesse: CGSize) -> some View {
        let form = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return Button(action: ding.tippen) {
            HStack(spacing: 12) {
                Startzeichenfeld(art: ding.zeichen, farbe: ding.an ? ding.farbe : Farbe.text3, kante: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Zahl(
                        wert: ding.zahl, einheit: ding.einheit, schrift: Schrift.mono(26),
                        einheitSchrift: Schrift.sans(12.5),
                        farbe: ding.an && !ding.alt ? Farbe.text1 : Farbe.text3)
                    Text(ding.name)
                        .font(Schrift.sans(12))
                        .foregroundStyle(Farbe.text2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(width: Self.kastenbreite, height: Self.kastenhoehe, alignment: .leading)
            .background(form.fill(ding.an ? ding.farbe.opacity(0.15) : Farbe.flaeche1.opacity(0.7)))
            .background(form.fill(Farbe.flaeche1))
            .overlay(form.stroke(ding.an ? ding.farbe.opacity(0.5) : Farbe.linie1, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ding.name): \(ding.zahl) \(ding.einheit)")
        .accessibilityHint(ding.auswahl ? "Auswahl öffnen" : "Details öffnen")
        .position(kastenmitte(ding, groesse))
    }
}

/// Punkte, Strahlen und Bögen auf dem Ring, aus Radius und Uhrzeit.
enum Ringform {
    static func punkt(_ m: Stundenring.Mass, radius: Double, winkel: Double) -> CGPoint {
        CGPoint(x: m.mitteX + radius * cos(winkel), y: m.mitteY + radius * sin(winkel))
    }

    static func strahl(_ m: Stundenring.Mass, von: Double, bis: Double, winkel: Double) -> Path {
        var p = Path()
        p.move(to: punkt(m, radius: von, winkel: winkel))
        p.addLine(to: punkt(m, radius: bis, winkel: winkel))
        return p
    }

    /// Ein Stück des Rings zwischen zwei Uhrzeiten, als Linienzug: so steht außer Frage, in
    /// welche Richtung er läuft.
    static func bogen(_ m: Stundenring.Mass, radius: Double, von: Double, bis: Double) -> Path {
        var p = Path()
        let schritte = 8
        for i in 0...schritte {
            let stunde: Double = von + (bis - von) * Double(i) / Double(schritte)
            let ort = punkt(m, radius: radius, winkel: Stundenring.winkel(stunde: stunde))
            if i == 0 { p.move(to: ort) } else { p.addLine(to: ort) }
        }
        return p
    }
}

/// Eine der fünf Sachen rund um den Ring: links, was liefert, rechts, was nimmt.
struct Startding: Identifiable {
    let id: String
    let links: Bool
    let farbe: Color
    let zeichen: Zeichenart
    let zahl: String
    let einheit: String
    let name: String
    /// Die Leistung des Bandes; darunter ruht die Sache.
    let kw: Double
    /// Der Strom fließt zum Ring hin, nicht von ihm weg.
    let zumRing: Bool
    let an: Bool
    /// Der Messwert trägt nicht mehr.
    let alt: Bool
    /// Wo der Kasten an der Wand steht (Anteil der Höhe) und unter welchem Winkel sein Band am
    /// Ring ankommt.
    let hoehe: Double
    let grad: Double
    /// Öffnet eine Auswahl, statt auf die Seite zu führen.
    let auswahl: Bool
    /// Läuft auf dem Hauptfaden, wie der Wegweiser, den sie bewegt.
    let tippen: @MainActor () -> Void

    @MainActor
    static func alle(
        fluss f: Startfluss, augenblick s: EnergySnapshot?, nacht: Bool, sonneAb: String?,
        wpLaeuft: Bool, wegweiser: Wegweiser
    ) -> [Startding] {
        let sonnenname: String = (nacht ? sonneAb.map { "Sonne ab \($0)" } : nil) ?? "Sonne"
        return [
            Startding(
                id: "sonne", links: true, farbe: Farbe.pv, zeichen: nacht ? .mond : .sonne,
                zahl: Formate.kw(s?.pvPowerKw.value), einheit: "kW", name: sonnenname, kw: f.pv,
                zumRing: true, an: f.pv >= Startbuehne.flussAbKw,
                alt: s?.pvPowerKw.belastbar == nil, hoehe: 0.3, grad: 202, auswahl: false,
                tippen: { wegweiser.gehe("/strom/pv") }),
            Startding(
                id: "netz", links: true,
                farbe: f.einspeisung ? Farbe.netzEinspeisung : Farbe.netzBezug, zeichen: .netz,
                zahl: Formate.kw(f.netz), einheit: "kW", name: f.netzName, kw: f.netz,
                zumRing: !f.einspeisung, an: f.netz >= Startbuehne.flussAbKw,
                alt: s?.gridPowerKw.belastbar == nil, hoehe: 0.7, grad: 158, auswahl: false,
                tippen: { wegweiser.gehe("/strom") }),
            Startding(
                id: "speicher", links: false, farbe: Farbe.batterie, zeichen: .batterie,
                zahl: f.socText, einheit: "%", name: f.speicherName, kw: f.speicherBand,
                zumRing: f.speicherWort == .entlaedt, an: f.speicherWort != .haelt,
                alt: s?.batterySoc.belastbar == nil, hoehe: 0.2, grad: -34, auswahl: true,
                tippen: { wegweiser.blatt = .batterie }),
            Startding(
                id: "pumpe", links: false, farbe: Farbe.waermepumpe, zeichen: .waermepumpe,
                zahl: Formate.kw(s?.heatPumpPowerKw.value), einheit: "kW",
                name: f.pumpenName(laeuft: wpLaeuft), kw: f.hp, zumRing: false, an: wpLaeuft,
                alt: s?.heatPumpPowerKw.belastbar == nil, hoehe: 0.5, grad: 0, auswahl: true,
                tippen: { wegweiser.blatt = .waermepumpenmenue }),
            Startding(
                id: "wallbox", links: false, farbe: Farbe.wallbox, zeichen: .auto,
                zahl: Formate.kw(s?.evPowerKw.value), einheit: "kW", name: f.wallboxName, kw: f.ev,
                zumRing: false, an: f.wallboxLaedt, alt: s?.evPowerKw.belastbar == nil,
                hoehe: 0.8, grad: 34, auswahl: false,
                tippen: { wegweiser.gehe("/strom/wallbox") }),
        ]
    }
}
