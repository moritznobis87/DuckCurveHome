import DuckCurveKit
import SwiftUI

/// Die nächsten 24 Stunden am Telefon: oben der Preis mit Einordnung, dann drei Bänder, dann
/// drei Sätze.
///
/// **Was hier vorher stand.** Am Telefon zeigte die App an dieser Stelle die Karte „Als
/// Nächstes" mit drei Uhrzeiten untereinander. Genau diese Kachel hat die Wandanzeige abgelöst
/// (`apps/web/src/components/home/Ausblick.tsx`), und zwar mit Begründung: „Strom gerade
/// 38,3 ct" ist eine Zahl ohne Maß, und drei Uhrzeiten sind kein Rat. Gerechnet wird in
/// ``Ausblick`` im Kern; hier wird gezeichnet und nichts entschieden.
///
/// **Drei Bänder, nicht drei Kurven in einem Diagramm.** Preis in ct, Sonne in kW und ein
/// Schaltzustand haben keine gemeinsame Skala. Sie teilen nur die Zeitachse - jedes Band hat
/// seine eigene Höhe und seinen eigenen Maßstab, und der steht rechts in seinem Kopf.
struct Ausblickkarte: View {
    @Environment(Wegweiser.self) private var wegweiser

    let ausblick: Ausblick
    let jetzt: Date
    var warnung: String?

    private let hoehePreis: CGFloat = 46
    private let hoeheSonne: CGFloat = 34
    private let hoeheBand: CGFloat = 10

    var body: some View {
        if ausblick.tragfaehig {
            // **Rechts in der Kopfzeile der Weg zum Fahrplan** (`Ausblick.tsx:123-126`). Er
            // fehlte: von der Startseite fuehrte kein Weg dorthin, obwohl die Karte den Plan
            // zeigt und die Seite es gibt.
            Karte(kicker: "Die nächsten 24 Stunden", beiwerk: AnyView(fahrplanknopf)) {
                VStack(alignment: .leading, spacing: 14) {
                    preiszeile
                    baender
                    saetze
                    fuss
                }
            }
        }
    }

    /// Der Weg zum Fahrplan, rechts in der Kopfzeile.
    private var fahrplanknopf: some View {
        Button {
            wegweiser.gehe("/waerme/fahrplan")
        } label: {
            Text("Fahrplan ›")
                .font(Schrift.sans(13))
                .foregroundStyle(Farbe.amber)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fahrplan öffnen")
    }

    // MARK: - Der Preis und wo er liegt

    @ViewBuilder private var preiszeile: some View {
        if let p = ausblick.preisJetzt {
            VStack(alignment: .leading, spacing: 9) {
                // **Die Zeile darf umbrechen** (`handy.css:86`): „Strom ist gerade weder
                // guenstig noch teuer" neben einer Zahl von 34 Punkten passt auf 390 Punkten
                // Breite nicht in eine Zeile, und gequetscht steht er dort seit jeher.
                Umbruchzeile(abstand: 12, zeilenabstand: 4) {
                    Zahl(
                        wert: Formate.zahl(p, stellen: 1), einheit: "ct/kWh",
                        schrift: Schrift.mono(34, relativeTo: .title),
                        einheitSchrift: Schrift.sans(13.5),
                        farbe: p < 0 ? Farbe.pv : Farbe.text1
                    )
                    .tracking(-1.2)
                    if let lage = ausblick.lage {
                        Text(lage.satz)
                            .font(Schrift.sans(15.5))
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                spur
            }
        }
    }

    /// Billigster Preis, ein Punkt an der Stelle von jetzt, teuerster Preis.
    @ViewBuilder private var spur: some View {
        if let stelle = ausblick.stelle, let lo = ausblick.preisMin, let hi = ausblick.preisMax {
            HStack(spacing: 8) {
                Text(Formate.zahl(lo, stellen: 0))
                    .font(Schrift.mono(12)).foregroundStyle(Farbe.text3)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        // **Die Spur verlaeuft von blass nach kraeftig** (`handy.css:91`): sie
                        // ist selbst schon die Auskunft „links billig, rechts teuer".
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(Farbwert(0x7FA3B3, deckung: 0.22)),
                                        Color(Farbwert(0x7FA3B3, deckung: 0.85)),
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(height: 6)
                        // Der Punkt traegt die eigentliche Auskunft und steht deshalb in der
                        // hellsten Farbe, mit einem Ring in der Kartenflaeche, damit er auf dem
                        // Verlauf freisteht. Vorher war er blaugrau auf blaugrau.
                        Circle()
                            .fill(Farbe.text1)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(Farbe.flaeche2, lineWidth: 3))
                            .offset(x: g.size.width * stelle - 7)
                    }
                    .frame(height: 14)
                }
                .frame(height: 14)
                Text("\(Formate.zahl(hi, stellen: 0)) ct")
                    .font(Schrift.mono(12)).foregroundStyle(Farbe.text3)
            }
            .accessibilityElement()
            .accessibilityLabel(
                "Der Preis liegt in den nächsten 24 Stunden zwischen \(Formate.zahl(lo, stellen: 0)) und \(Formate.zahl(hi, stellen: 0)) Cent, jetzt bei \(Formate.zahl(ausblick.preisJetzt, stellen: 1)) Cent."
            )
        }
    }

    // MARK: - Die Bänder

    private var baender: some View {
        VStack(alignment: .leading, spacing: 10) {
            band(
                "Strompreis",
                rechts: ausblick.preisMin.flatMap { lo in
                    ausblick.preisMax.map {
                        "\(Formate.zahl(lo, stellen: 0)) bis \(Formate.zahl($0, stellen: 0)) ct"
                    }
                },
                hoehe: hoehePreis
            ) { flaeche, zellenbreite in
                preisbild(flaeche, zellenbreite)
            }
            band(
                "Sonne erwartet",
                rechts: ausblick.pvMax >= 0.1 ? "bis \(Formate.zahl(ausblick.pvMax, stellen: 1)) kW" : "keine",
                hoehe: hoeheSonne
            ) { flaeche, zellenbreite in
                sonnenbild(flaeche, zellenbreite)
            }
            if ausblick.hatFahrplan {
                band(
                    ausblick.braende.isEmpty ? "Wärmepumpe geplant" : "Wärmepumpe und Ofen geplant",
                    rechts: nil,
                    hoehe: ausblick.braende.isEmpty ? hoeheBand + 2 : hoeheBand * 2 + 2
                ) { flaeche, zellenbreite in
                    schaltbild(flaeche, zellenbreite)
                }
            }
            achse
        }
    }

    /// Ein Band: Kopfzeile mit Maßstab, darunter die Zeichnung über die ganze Breite.
    private func band(
        _ titel: String, rechts: String?, hoehe: CGFloat,
        inhalt: @escaping (CGRect, CGFloat) -> Pfadsatz
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(titel).font(Schrift.sans(12.5)).foregroundStyle(Farbe.text2)
                Spacer(minLength: 4)
                if let rechts {
                    Text(rechts).font(Schrift.mono(11.5)).foregroundStyle(Farbe.text3)
                }
            }
            Canvas { ctx, groesse in
                let flaeche = CGRect(origin: .zero, size: groesse)
                let zellenbreite = groesse.width / CGFloat(Ausblick.zellenzahl)
                let satz = inhalt(flaeche, zellenbreite)
                for f in satz.flaechen { ctx.fill(f.pfad, with: .color(f.farbe)) }
                for l in satz.linien {
                    ctx.stroke(
                        l.pfad, with: .color(l.farbe),
                        style: StrokeStyle(lineWidth: l.breite, lineJoin: .round))
                }
            }
            .frame(height: hoehe)
            // **Der Boden, auf dem die Flaechen stehen** (`handy.css:97`): ohne ihn enden
            // Stufenkurve und Sonnenflaeche im Nichts.
            Rectangle().fill(Farbe.linie1).frame(height: 1)
        }
    }

    private func preisbild(_ f: CGRect, _ zb: CGFloat) -> Pfadsatz {
        var satz = Pfadsatz()
        if let g = ausblick.guenstig {
            satz.flaechen.append(
                // Das Fenster ist weiches Bernstein, nicht das Gelb der Sonne (`Ausblick.tsx:151`):
                // sonst sieht die Marke im Preisband aus wie die im Sonnenband - und derselbe
                // Punkt vor dem Satz darunter ist schon richtig gesetzt.
                .init(
                    pfad: Path(fensterRechteck(g.von, g.bis, f, zb)),
                    farbe: Farbe.amberWeich.opacity(0.16)))
        }
        guard let lo = ausblick.preisMin, let hi = ausblick.preisMax else { return satz }
        let spanne = max(1, hi - lo)
        let stufen = Stufenbild.baue(
            ausblick.zellen, breite: zb, boden: f.height,
            y: { z in
                guard let p = z.preis else { return nil }
                return f.height - 3 - ((p - lo) / spanne) * (f.height - 8)
            })
        satz.flaechen.append(.init(pfad: stufen.flaeche, farbe: Farbe.preis.opacity(0.16)))
        satz.linien.append(.init(pfad: stufen.linie, farbe: Farbe.preis, breite: 1.6))
        return satz
    }

    private func sonnenbild(_ f: CGRect, _ zb: CGFloat) -> Pfadsatz {
        var satz = Pfadsatz()
        if let s = ausblick.sonne {
            satz.flaechen.append(
                .init(pfad: Path(fensterRechteck(s.von, s.bis, f, zb)), farbe: Farbe.pv.opacity(0.10)))
        }
        let hoch = max(1, ausblick.pvMax)
        let stufen = Stufenbild.baue(
            ausblick.zellen, breite: zb, boden: f.height,
            y: { f.height - 1 - ($0.pv / hoch) * (f.height - 5) })
        satz.flaechen.append(.init(pfad: stufen.flaeche, farbe: Farbe.pv.opacity(0.38)))
        satz.linien.append(.init(pfad: stufen.linie, farbe: Farbe.pv, breite: 1.4))
        return satz
    }

    /// Zwei Spuren: die Wärmepumpe, und darunter der Ofen, wenn er brennen soll.
    private func schaltbild(_ f: CGRect, _ zb: CGFloat) -> Pfadsatz {
        var satz = Pfadsatz()
        func spur(_ y: CGFloat, _ bereiche: [Range<Int>], _ farbe: Color) {
            satz.flaechen.append(
                .init(
                    pfad: Path(
                        roundedRect: CGRect(x: 0, y: y, width: f.width, height: hoeheBand),
                        cornerRadius: 1.5),
                    farbe: Farbe.flaeche3))
            for b in bereiche {
                satz.flaechen.append(
                    .init(
                        pfad: Path(
                            CGRect(
                                x: CGFloat(b.lowerBound) * zb, y: y,
                                width: CGFloat(b.count) * zb, height: hoeheBand)),
                        farbe: farbe))
            }
        }
        spur(0, ausblick.laeufe, Farbe.waermepumpe)
        if !ausblick.braende.isEmpty {
            spur(hoeheBand + 2, ausblick.braende, Farbe.ofen)
        }
        return satz
    }

    private func fensterRechteck(_ von: Date, _ bis: Date, _ f: CGRect, _ zb: CGFloat) -> CGRect {
        guard let erste = ausblick.zellen.first?.zeit else { return .zero }
        let x0 = CGFloat(von.timeIntervalSince(erste) / Ausblick.schritt) * zb
        let x1 = CGFloat(bis.timeIntervalSince(erste) / Ausblick.schritt) * zb
        return CGRect(x: x0, y: 0, width: max(0, x1 - x0), height: f.height)
    }

    /// „jetzt" links, dann jede volle sechste Stunde der Hausuhr.
    private var achse: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Text("jetzt").font(Schrift.achse).foregroundStyle(Farbe.text2)
                ForEach(ausblick.achsenmarken) { m in
                    // **Mittig ueber ihrer Zeit** (`handy.css:99`: `translateX(-50%)`). Mit der
                    // linken Kante auf der Stelle stand „12 Uhr" rund 19 Punkte zu weit rechts.
                    // Ein Rahmen der Breite null zentriert den Text ueber dem Punkt, ohne dass
                    // seine Breite gemessen werden muesste.
                    Text(m.text)
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize()
                        .frame(width: 0)
                        .offset(x: g.size.width * m.anteil)
                }
            }
        }
        .frame(height: 13)
    }

    // MARK: - Die Sätze

    private var saetze: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(ausblick.saetze(jetzt: jetzt)) { s in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // Ein Quadrat mit weichen Ecken, nicht ein Punkt: es ist die Marke der
                    // Flaeche im Band darueber, und die ist eckig (`handy.css:103`).
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(farbe(s.marke))
                        .frame(width: 10, height: 10)
                        .offset(y: -1)
                    Text(s.text)
                        .font(Schrift.sans(14.5))
                        .foregroundStyle(Farbe.text1)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func farbe(_ m: Ausblick.Marke) -> Color {
        switch m {
        case .waermepumpe: return Farbe.waermepumpe
        case .ofen: return Farbe.ofen
        case .guenstig: return Farbe.amberWeich
        case .sonne: return Farbe.pv
        }
    }

    private var fuss: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let s = ausblick.verschiebesatz {
                Text(s).font(Schrift.sans(13)).foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let s = ausblick.preissatz(jetzt: jetzt) {
                Text(s).font(Schrift.sans(13)).foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let warnung, !warnung.isEmpty {
                // Weiches Bernstein, nicht das harte: eine Warnung des Planers ist ein Hinweis
                // und kein Alarm (`handy.css:105`).
                Text(warnung).font(Schrift.sans(13)).foregroundStyle(Farbe.amberWeich)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Zeichenhilfen

/// Flächen und Linien, die ein `Canvas` in dieser Reihenfolge zeichnet.
struct Pfadsatz {
    struct Flaeche {
        let pfad: Path
        let farbe: Color
    }
    struct Linie {
        let pfad: Path
        let farbe: Color
        let breite: CGFloat
    }
    var flaechen: [Flaeche] = []
    var linien: [Linie] = []
}

/// Eine Stufenlinie über die Zellen, als Fläche bis zum Boden geschlossen.
///
/// **Stufen und keine Kurve.** Ein Preis gilt eine Viertelstunde lang und ändert sich dann
/// sprunghaft; eine geglättete Linie behauptete einen Verlauf, den es nicht gibt. Eine Lücke -
/// eine Viertelstunde ohne Preis - unterbricht beides, statt sie zu überbrücken.
enum Stufenbild {
    static func baue<Z>(
        _ zellen: [Z], breite: CGFloat, boden: CGFloat, y: (Z) -> CGFloat?
    ) -> (linie: Path, flaeche: Path) {
        var linie = Path()
        var flaeche = Path()
        var offen = false
        var x0: CGFloat = 0

        func schliesse(bis x: CGFloat) {
            flaeche.addLine(to: CGPoint(x: x, y: boden))
            flaeche.addLine(to: CGPoint(x: x0, y: boden))
            flaeche.closeSubpath()
        }

        for (i, z) in zellen.enumerated() {
            let x = CGFloat(i) * breite
            guard let h = y(z) else {
                if offen { schliesse(bis: x) }
                offen = false
                continue
            }
            if !offen {
                x0 = x
                linie.move(to: CGPoint(x: x, y: h))
                flaeche.move(to: CGPoint(x: x, y: h))
                offen = true
            } else {
                linie.addLine(to: CGPoint(x: x, y: h))
                flaeche.addLine(to: CGPoint(x: x, y: h))
            }
            linie.addLine(to: CGPoint(x: x + breite, y: h))
            flaeche.addLine(to: CGPoint(x: x + breite, y: h))
            if i == zellen.count - 1 { schliesse(bis: x + breite) }
        }
        return (linie, flaeche)
    }
}

#Preview("Ausblick") {
    let jetzt = Vorschau.jetzt
    return ScrollView {
        Ausblickkarte(
            ausblick: Ausblick.baue(Vorschau.plan(), jetzt: jetzt), jetzt: jetzt
        )
        .padding()
    }
    .background(Farbe.grundVerlauf)
}
