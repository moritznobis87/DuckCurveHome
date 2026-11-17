import DuckCurveKit
import SwiftUI

/// Der Pufferspeicher als Glas: ein Tank, der von oben nach unten die Farbe seiner vier Fühler
/// zeigt.
///
/// **Der Speicher sieht überall gleich aus** (Nutzerwunsch 14.11.2026): dasselbe Glas auf der
/// Startseite, im Anlagenschema und auf der Wärmeseite.
///
/// **An der Wand steht er, am Telefon liegt er.** Hier stand einmal, die liegende Fassung sei
/// meine Erfindung und im Dashboard gebe es sie nicht. Das war falsch, und der Satz hat eine
/// richtige Lösung verdrängt: `home/Rail.tsx` legt den Speicher im kompakten Zweig hin
/// (`home-puffer-flach`), auf Nutzerwunsch vom 14.11.2026 und mit dessen Begründung – „sonst
/// streckt man die Seite unnötig". Am Telefon ist die Startseite eine Rolle, und ein Glas von
/// 300 Punkten Höhe schiebt alles Folgende unter den Rand. Liegend ist es dasselbe Glas auf
/// der Seite: dieselbe Farbskala, jede Zahl an der Stelle ihres Fühlers, links oben, rechts
/// unten.
///
/// **Die vier Fühler stehen neben dem Glas, auf ihrer Höhe**, jeder mit einem Strich dorthin –
/// so wie im Dashboard. Vorher standen sie als weiße Pillen *im* Wasser und verdeckten genau
/// das, was sie beschriften. Wo ein Fühler fehlt, steht ein Strich und keine Zahl.
struct Pufferglas: View {
    let temperaturen: [Messwert]
    let soc: Double?
    let zustand: Pufferzustand
    /// Die Höhe der vier Fühler im Speicher, von oben nach unten. Aus `puffer/glas.ts`.
    private let hoehen: [Double] = [0.12, 0.38, 0.62, 0.88]
    /// Die Breite des Tanks. Das Dashboard zeichnet 56 auf 300 – ein schmales, hohes Glas.
    private let tankbreite: CGFloat = 60

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            tank
                .frame(width: tankbreite + 46)
            werte
            Spacer(minLength: 0)
        }
    }

    // MARK: - Das Glas

    private var tank: some View {
        GeometryReader { raum in
            let h = raum.size.height
            ZStack(alignment: .topLeading) {
                form
                    .fill(LinearGradient(stops: verlauf, startPoint: .top, endPoint: .bottom))
                    .frame(width: tankbreite, height: h)
                form
                    .strokeBorder(Farbe.linie2, lineWidth: 1)
                    .frame(width: tankbreite, height: h)
                ForEach(Array(temperaturen.enumerated()), id: \.offset) { i, m in
                    if i < hoehen.count {
                        fuehler(m, bei: hoehen[i], hoehe: h)
                    }
                }
            }
        }
    }

    /// Ein Fühler: ein Strich aus dem Glas heraus und die Zahl daneben.
    private func fuehler(_ m: Messwert, bei anteil: Double, hoehe: CGFloat) -> some View {
        let y = anteil * hoehe
        return Group {
            Rectangle()
                .fill(Farbe.linie2)
                .frame(width: 10, height: 1)
                .position(x: tankbreite + 5, y: y)
            HStack(spacing: 1) {
                Text(m.belastbar.map { Formate.zahl($0, stellen: 0) } ?? Formate.leer)
                    .foregroundStyle(m.quality.traegt ? Farbe.text1 : Farbe.text3)
                if m.belastbar != nil {
                    Text("°").foregroundStyle(Farbe.text3)
                }
            }
            .font(Schrift.zahlKlein)
            .position(x: tankbreite + 32, y: y)
        }
    }

    private var form: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    /// Der Farbverlauf des Wassers: die Farbe jedes Fühlers auf seiner Höhe.
    ///
    /// Wo Werte fehlen, bleibt das Glas gedeckt – ein Verlauf aus zwei Messungen und zwei
    /// Vermutungen wäre ein Bild, das mehr behauptet, als gemessen ist.
    private var verlauf: [Gradient.Stop] {
        let werte = temperaturen.map(\.belastbar)
        guard werte.contains(where: { $0 != nil }) else {
            return [
                .init(color: Farbe.flaeche3, location: 0),
                .init(color: Farbe.flaeche2, location: 1),
            ]
        }
        var stops: [Gradient.Stop] = []
        for (i, wert) in werte.enumerated() where i < hoehen.count {
            guard let wert else { continue }
            // Die Skala steht im Kern und ist dort geprueft - sie ist dieselbe wie die der
            // Rohre im Anlagenschema und die der Jahreskarte.
            stops.append(.init(color: Color(Marken.wasserfarbe(wert)), location: hoehen[i]))
        }
        // Die Raender fortsetzen, damit oben und unten keine harte Kante entsteht.
        if let erster = stops.first {
            stops.insert(.init(color: erster.color, location: 0), at: 0)
        }
        if let letzter = stops.last {
            stops.append(.init(color: letzter.color, location: 1))
        }
        return stops
    }

    // MARK: - Fuellstand und Wort

    private var werte: some View {
        VStack(alignment: .leading, spacing: 2) {
            Zahl(
                wert: zustand.traegt ? Formate.prozent(soc) : Formate.leer,
                schrift: Schrift.zahlGross,
                farbe: zustand.traegt ? Farbe.text1 : Farbe.text3
            )
            Text(zustand.wort)
                .font(Schrift.winzig)
                .foregroundStyle(zustand.veraltet ? Farbe.achtung : Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pufferspeicher: \(zustand.traegt ? Formate.prozent(soc) : "kein Füllstand"), \(zustand.wort)")
    }
}

#if DEBUG
    #Preview("Puffer, stehend") {
        let t = Vorschau.puffertemperaturen().vonObenNachUnten
        return Pufferglas(
            temperaturen: t,
            soc: 0.74,
            zustand: Pufferzustand.aus(fuehler: t, jetzt: Vorschau.jetzt, laedt: true, status: .warm)
        )
        .frame(height: 320)
        .padding()
        .background(Farbe.flaeche1)
    }

    #Preview("Puffer, veraltet") {
        let t = [
            Vorschau.messwert(52.4),
            Vorschau.messwert(47.1, guete: .stale, am: Vorschau.jetzt.addingTimeInterval(-7200)),
            Vorschau.messwert(38.6),
            Vorschau.messwert(31.2),
        ]
        return Pufferglas(
            temperaturen: t,
            soc: nil,
            zustand: Pufferzustand.aus(fuehler: t, jetzt: Vorschau.jetzt, laedt: false, status: .warm)
        )
        .frame(height: 320)
        .padding()
        .background(Farbe.flaeche1)
    }
#endif


/// Derselbe Speicher, auf die Seite gelegt – die Fassung fürs Telefon.
///
/// Links oben, rechts unten: die Leserichtung ersetzt die Höhe. Die vier Zahlen stehen an der
/// Stelle ihres Fühlers über dem Band, die Worte „oben" und „unten" darunter an den Enden.
struct Pufferflach: View {
    let temperaturen: [Messwert]
    let soc: Double?
    let zustand: Pufferzustand

    /// Dieselben vier Höhen wie im stehenden Glas, hier als Stellen von links nach rechts.
    private let stellen: [Double] = [0.12, 0.38, 0.62, 0.88]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            kopf
            band
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pufferspeicher: \(zustand.traegt ? Formate.prozent(soc) : "kein Füllstand"), \(zustand.wort)")
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Zahl(
                wert: zustand.traegt ? Formate.prozent(soc) : Formate.leer,
                schrift: Schrift.zahlGross,
                farbe: zustand.traegt ? Farbe.text1 : Farbe.text3
            )
            Text(zustand.wort)
                .font(Schrift.klein)
                .foregroundStyle(zustand.veraltet ? Farbe.achtung : Farbe.text3)
            Spacer(minLength: 0)
        }
    }

    private var band: some View {
        VStack(alignment: .leading, spacing: 3) {
            zahlenzeile
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(stops: verlauf, startPoint: .leading, endPoint: .trailing))
                .frame(height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                )
                .opacity(zustand.traegt ? 1 : 0.5)
            orte
        }
    }

    private var zahlenzeile: some View {
        GeometryReader { raum in
            ForEach(Array(temperaturen.enumerated()), id: \.offset) { i, m in
                if i < stellen.count {
                    HStack(spacing: 1) {
                        Text(m.belastbar.map { Formate.zahl($0, stellen: 0) } ?? Formate.leer)
                            .foregroundStyle(m.quality.traegt ? Farbe.text1 : Farbe.text3)
                        if m.belastbar != nil {
                            Text("°").foregroundStyle(Farbe.text3)
                        }
                    }
                    .font(Schrift.zahlKlein)
                    .position(x: stellen[i] * raum.size.width, y: raum.size.height / 2)
                }
            }
        }
        .frame(height: 15)
    }

    private var orte: some View {
        GeometryReader { raum in
            Text("oben")
                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                .position(x: stellen[0] * raum.size.width, y: raum.size.height / 2)
            Text("unten")
                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                .position(x: stellen[3] * raum.size.width, y: raum.size.height / 2)
        }
        .frame(height: 13)
    }

    /// Derselbe Verlauf wie im stehenden Glas, nur von links nach rechts.
    private var verlauf: [Gradient.Stop] {
        let werte = temperaturen.map(\.belastbar)
        guard werte.contains(where: { $0 != nil }) else {
            return [
                .init(color: Farbe.flaeche3, location: 0),
                .init(color: Farbe.flaeche2, location: 1),
            ]
        }
        var stops: [Gradient.Stop] = []
        for (i, wert) in werte.enumerated() where i < stellen.count {
            guard let wert else { continue }
            stops.append(.init(color: Color(Marken.wasserfarbe(wert)), location: stellen[i]))
        }
        if let erster = stops.first {
            stops.insert(.init(color: erster.color, location: 0), at: 0)
        }
        if let letzter = stops.last {
            stops.append(.init(color: letzter.color, location: 1))
        }
        return stops
    }
}
