import DuckCurveKit
import SwiftUI

/// Die Karten neben dem Bild der Startseite und die kleinen Teile, aus denen sie bestehen: der
/// Puffer, die nächsten 24 Stunden als Bild (zur Bühne) und der Strompreis in großer Zahl (zur
/// Uhr, deren Ring die 24 Stunden selbst zeigt). Dieselben Karten wie `Karten.tsx` im Dashboard.

/// Ein Zeichen in einem getönten Feld mit runden Ecken, in der Farbe der Sache.
struct Startzeichenfeld: View {
    let art: Zeichenart
    var farbe: Color = Farbe.mist
    var kante: CGFloat = 36

    var body: some View {
        Zeichen(art, groesse: kante * 0.56, farbe: farbe)
            .frame(width: kante, height: kante)
            .background(farbe.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// Ein Zustand als Wort in einer Pille.
struct Startmarke: View {
    enum Art { case ruhig, warm, kuehl, laeuft }

    let wort: String
    var art: Art = .ruhig

    var body: some View {
        HStack(spacing: 7) {
            if art == .laeuft {
                Circle().fill(Farbe.waermepumpe).frame(width: 7, height: 7)
            }
            Text(wort)
                .font(Schrift.sansHalbfett(12.5))
                .foregroundStyle(schrift)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 3)
        .background(grund)
        .clipShape(Capsule())
        .fixedSize()
    }

    private var schrift: Color {
        switch art {
        case .ruhig: return Farbe.text2
        case .warm: return Farbe.amberWeich
        case .kuehl: return Color(Farbwert(0xCFE3EA))
        case .laeuft: return Color(Farbwert(0xF3B392))
        }
    }

    private var grund: Color {
        switch art {
        case .ruhig: return Farbe.text3.opacity(0.18)
        case .warm: return Farbe.amber.opacity(0.18)
        case .kuehl: return Farbe.mist.opacity(0.26)
        case .laeuft: return Farbe.waermepumpe.opacity(0.22)
        }
    }
}

/// Der Puffer: Ladestand, Zustand, der Verlauf von warm nach kalt und die vier Fühler.
struct Startpufferkarte: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    var body: some View {
        let fuehler: [Messwert] = haus.augenblick?.bufferTempsC.vonObenNachUnten ?? []
        let zustand = Pufferzustand.aus(
            fuehler: fuehler, jetzt: haus.jetzt,
            laedt: haus.zustand?.heatPump.running ?? false, status: haus.zustand?.buffer.status)
        Karte {
            Pufferflach(temperaturen: fuehler, soc: haus.zustand?.buffer.soc, zustand: zustand)
        }
        .contentShape(Rectangle())
        .onTapGesture { wegweiser.gehe("/waerme") }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Details öffnen")
    }
}

/// Der Preis jetzt mit einem Wort für seine Lage.
struct Startpreis: View {
    let ausblick: Ausblick
    var gross = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Zahl(
                wert: Formate.zahl(ausblick.preisJetzt, stellen: 1), einheit: gross ? "ct je kWh" : "ct",
                schrift: Schrift.mono(gross ? 44 : 22), einheitSchrift: Schrift.sans(gross ? 15 : 12))
            if gross { Spacer(minLength: 8) }
            if let lage = ausblick.lage {
                Startmarke(wort: lage.wort, art: lage == .teuer ? .warm : (lage == .guenstig ? .kuehl : .ruhig))
            }
        }
    }
}

/// Preistief, beste Sonne und die nächsten Läufe als Zeitspannen statt als Sätze.
struct Startzeitspannen: View {
    let ausblick: Ausblick

    var body: some View {
        let spannen = Stundenring.zeitspannen(ausblick)
        if !spannen.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(spannen) { spanne in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Zeichen(zeichen(spanne.art), groesse: 14, farbe: farbe(spanne.art))
                            Text(spanne.wort)
                                .font(Schrift.sans(11))
                                .foregroundStyle(Farbe.text3)
                                .lineLimit(1)
                        }
                        Text(spanne.text)
                            .font(Schrift.mono(12.5))
                            .foregroundStyle(Farbe.text1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Farbe.deep.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
        }
    }

    private func zeichen(_ art: Stundenring.Zeitspanne.Art) -> Zeichenart {
        switch art {
        case .preistief: return .euro
        case .sonne: return .sonne
        case .waermepumpe: return .waermepumpe
        case .ofen: return .ofen
        }
    }

    private func farbe(_ art: Stundenring.Zeitspanne.Art) -> Color {
        switch art {
        case .preistief: return Farbe.mist
        case .sonne: return Farbe.pv
        case .waermepumpe: return Farbe.waermepumpe
        case .ofen: return Farbe.ofen
        }
    }
}

/// Der Preis als Säulen, die erwartete Sonne dahinter, die Läufe als Striche darunter.
struct Startstundenbild: View {
    let ausblick: Ausblick

    var body: some View {
        let stunden = Stundenring.stunden24(ausblick.zellen, guenstig: ausblick.guenstig)
        let ofen: Bool = stunden.contains { $0.ofen }
        VStack(alignment: .leading, spacing: 4) {
            // Die Höhe gibt nach, wenn die Karte an der Wand wenig Platz hat: gezeichnet wird in
            // der Höhe, die da ist.
            Canvas { g, groesse in
                zeichne(&g, groesse, stunden, ofen)
            }
            .frame(minHeight: 56, idealHeight: 96, maxHeight: 96)
            achse(stunden)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strompreis, erwartete Sonne und geplante Läufe in den nächsten 24 Stunden")
    }

    private func zeichne(
        _ g: inout GraphicsContext, _ groesse: CGSize, _ stunden: [Stundenring.Stunde], _ ofen: Bool
    ) {
        guard !stunden.isEmpty else { return }
        let breite: Double = groesse.width
        // Unter den Säulen bleibt Platz für die Striche der Läufe.
        let boden: Double = groesse.height - (ofen ? 20 : 12)
        let hoch: Double = max(10, boden - 4)
        let b: Double = breite / 24
        let sonneMax: Double = max(ausblick.pvMax, 3)
        var linie = Path()
        var flaeche = Path()
        flaeche.move(to: CGPoint(x: 0, y: boden))
        for (i, st) in stunden.enumerated() {
            let ort = CGPoint(x: (Double(i) + 0.5) * b, y: boden - min(1, st.sonneKw / sonneMax) * hoch)
            if i == 0 { linie.move(to: ort) } else { linie.addLine(to: ort) }
            flaeche.addLine(to: ort)
        }
        flaeche.addLine(to: CGPoint(x: breite, y: boden))
        flaeche.closeSubpath()
        g.fill(
            flaeche,
            with: .linearGradient(
                Gradient(colors: [Farbe.pv.opacity(0.5), Farbe.pv.opacity(0.04)]),
                startPoint: CGPoint(x: 0, y: boden - hoch), endPoint: CGPoint(x: 0, y: boden)))
        g.stroke(linie, with: .color(Farbe.pv.opacity(0.9)), lineWidth: 1.5)

        for (i, st) in stunden.enumerated() {
            let x: Double = Double(i) * b + 3.5
            let w: Double = max(2, b - 7)
            if let preis = st.preis {
                let h: Double = max(3, Stundenring.preislaenge(preis, hoechster: ausblick.preisMax) * hoch)
                let saeule = Path(
                    roundedRect: CGRect(x: x, y: boden - h, width: w, height: h), cornerRadius: w / 2)
                let farbe: Color = i == 0 ? Color.white.opacity(0.95) : Farbe.mist.opacity(st.tief ? 1 : 0.42)
                g.fill(saeule, with: .color(farbe))
            } else {
                // Für diese Stunde gibt es noch keinen Preis.
                let stumpf = Path(
                    roundedRect: CGRect(x: x, y: boden - 20, width: w, height: 20), cornerRadius: w / 2)
                g.stroke(
                    stumpf, with: .color(Farbe.mist.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            let strich: Double = max(2, b - 2)
            if st.wp {
                let lauf = CGRect(x: Double(i) * b + 1, y: boden + 6, width: strich, height: 5)
                g.fill(Path(roundedRect: lauf, cornerRadius: 2.5), with: .color(Farbe.waermepumpe))
            }
            if st.ofen {
                let brand = CGRect(x: Double(i) * b + 1, y: boden + 14, width: strich, height: 5)
                g.fill(Path(roundedRect: brand, cornerRadius: 2.5), with: .color(Farbe.ofen))
            }
        }
    }

    /// „jetzt“ am Anfang, danach jede volle sechste Stunde.
    private func achse(_ stunden: [Stundenring.Stunde]) -> some View {
        GeometryReader { raum in
            let b: Double = raum.size.width / 24
            ZStack(alignment: .topLeading) {
                Text("jetzt")
                    .font(Schrift.mono(10))
                    .foregroundStyle(Farbe.text1)
                    .fixedSize()
                ForEach(Array(stunden.enumerated()), id: \.offset) { i, st in
                    if i > 2, st.stunde % 6 == 0 {
                        Text(String(format: "%02d Uhr", st.stunde))
                            .font(Schrift.mono(10))
                            .foregroundStyle(Farbe.text3)
                            .fixedSize()
                            .position(x: (Double(i) + 0.5) * b, y: 6)
                    }
                }
            }
        }
        .frame(height: 13)
    }
}

/// Die nächsten 24 Stunden als ein Bild mit Zeitspannen. Steht neben der Bühne.
struct Startausblickkarte: View {
    let ausblick: Ausblick
    var warnung: String?

    var body: some View {
        Karte {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Startzeichenfeld(art: .uhr)
                    Text("Nächste 24 Stunden")
                        .font(Schrift.sansHalbfett(15))
                        .foregroundStyle(Farbe.text1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 8)
                    Startpreis(ausblick: ausblick)
                }
                Startstundenbild(ausblick: ausblick)
                Startzeitspannen(ausblick: ausblick)
                Startwarnung(text: warnung)
            }
        }
    }
}

/// Der Strompreis in großer Zahl mit den Zeitspannen. Steht neben der Uhr.
struct Startstromkarte: View {
    let ausblick: Ausblick
    var warnung: String?

    var body: some View {
        Karte {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Startzeichenfeld(art: .euro)
                    Text("Strom gerade")
                        .font(Schrift.sansHalbfett(15))
                        .foregroundStyle(Farbe.text1)
                }
                Startpreis(ausblick: ausblick, gross: true)
                Startzeitspannen(ausblick: ausblick)
                Startwarnung(text: warnung)
            }
        }
    }
}

/// Die Warnung des Planers, wenn er eine hat.
struct Startwarnung: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.amberWeich)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Am Telefon unter der Bühne: Wallbox und Wärmepumpe als zwei Kacheln, an denen die Bänder aus
/// dem Haus ankommen.
struct Startunterhaus: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    var body: some View {
        let f = Startfluss.aus(haus.augenblick)
        let laeuft: Bool = haus.zustand?.heatPump.running ?? false
        HStack(spacing: 12) {
            kachel(
                .auto, Farbe.wallbox, Formate.kw(haus.augenblick?.evPowerKw.value), f.wallboxName,
                an: f.wallboxLaedt, auswahl: false
            ) { wegweiser.gehe("/strom/wallbox") }
            kachel(
                .waermepumpe, Farbe.waermepumpe, Formate.kw(haus.augenblick?.heatPumpPowerKw.value),
                f.pumpenName(laeuft: laeuft), an: laeuft, auswahl: true
            ) { wegweiser.blatt = .waermepumpenmenue }
        }
    }

    private func kachel(
        _ art: Zeichenart, _ farbe: Color, _ zahl: String, _ name: String, an: Bool, auswahl: Bool,
        tippen: @escaping () -> Void
    ) -> some View {
        Button(action: tippen) {
            Karte {
                HStack(spacing: 10) {
                    Startzeichenfeld(art: art, farbe: an ? farbe : Farbe.text3, kante: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Zahl(
                            wert: zahl, einheit: "kW", schrift: Schrift.mono(22),
                            einheitSchrift: Schrift.sans(12), farbe: an ? Farbe.text1 : Farbe.text3)
                        Text(name)
                            .font(Schrift.sans(11.5))
                            .foregroundStyle(Farbe.text3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(auswahl ? "Auswahl öffnen" : "Details öffnen")
    }
}

/// Am Telefon unter der Uhr: die fünf Sachen als Liste in einer Karte.
struct Startdingliste: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    let nacht: Bool
    let sonneAb: String?

    var body: some View {
        let dinge = Startding.alle(
            fluss: Startfluss.aus(haus.augenblick), augenblick: haus.augenblick, nacht: nacht,
            sonneAb: sonneAb, wpLaeuft: haus.zustand?.heatPump.running ?? false, wegweiser: wegweiser)
        Karte {
            VStack(spacing: 0) {
                ForEach(dinge) { ding in
                    Button(action: ding.tippen) {
                        HStack(spacing: 12) {
                            Startzeichenfeld(
                                art: ding.zeichen, farbe: ding.an ? ding.farbe : Farbe.text3, kante: 32)
                            Text(ding.name)
                                .font(Schrift.sans(14.5))
                                .foregroundStyle(ding.an ? Farbe.text1 : Farbe.text3)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Zahl(
                                wert: ding.zahl, einheit: ding.einheit, schrift: Schrift.mono(21),
                                einheitSchrift: Schrift.sans(12),
                                farbe: ding.an && !ding.alt ? Farbe.text1 : Farbe.text3)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(ding.auswahl ? "Auswahl öffnen" : "Details öffnen")
                    if ding.id != dinge.last?.id {
                        Divider().overlay(Farbe.linie1)
                    }
                }
            }
        }
    }
}
