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
    /// Die Breite des Tanks. Das Dashboard zeichnet 72 auf 300 – ein schmales, hohes Glas
    /// (`Ambiente.tsx:180`); auf der Startseite ist es schmaler.
    var breite: CGFloat = 60
    /// Die Grösse der vier Fühlerzahlen. Im Ruhebild grösser, weil man dort weiter weg steht.
    var zahlgroesse: CGFloat = 12.5
    /// Blass, wenn die Werte unvollständig oder veraltet sind (`Glas.tsx:44`, `opacity .5`).
    var gedimmt: Bool = false
    /// Ob Füllstand und Wort rechts danebenstehen. Das Ruhebild setzt sie selbst, grösser.
    var mitWerten: Bool = true

    /// Die Höhe der vier Fühler im Speicher, von oben nach unten. Aus `puffer/glas.ts:22`.
    private let hoehen: [Double] = [0.125, 0.375, 0.625, 0.875]

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            tank
                .frame(width: breite + randbreite)
                .opacity(gedimmt ? 0.5 : 1)
            if mitWerten {
                werte
                Spacer(minLength: 0)
            }
        }
    }

    /// Der Platz rechts vom Glas für Strich und Zahl.
    ///
    /// Die Vorlage rechnet ihn aus der Schriftgrösse: `randBreite(s) = round(20 + s * 2.6)`
    /// (`puffer/glas.ts`). Bei 12,5 Punkten sind das 53, bei 17 Punkten 64. Eine feste Zahl
    /// stand hier zuerst - und liess bei grosser Schrift die Zahlen über den Rand laufen.
    private var randbreite: CGFloat { (20 + zahlgroesse * 2.6).rounded() }

    // MARK: - Das Glas

    private var tank: some View {
        GeometryReader { raum in
            let h = raum.size.height
            ZStack(alignment: .topLeading) {
                form
                    .fill(LinearGradient(stops: verlauf, startPoint: .top, endPoint: .bottom))
                    .frame(width: breite, height: h)
                // **Der Glanz macht aus der Farbfläche ein Glas** (`Glas.tsx:66-72`): links ein
                // heller Streifen, rechts ein dunkler. Ohne ihn ist der Tank ein Balken.
                form
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.22), location: 0),
                                .init(color: .white.opacity(0.05), location: 0.18),
                                .init(color: .white.opacity(0), location: 0.55),
                                .init(color: .black.opacity(0.18), location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: breite, height: h)
                form
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.2)
                    .frame(width: breite, height: h)
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
                .position(x: breite + 9, y: y)
            HStack(spacing: 1) {
                Text(m.belastbar.map { Formate.zahl($0, stellen: 0) } ?? Formate.leer)
                    .foregroundStyle(m.quality.traegt ? Farbe.text1 : Farbe.text3)
                if m.belastbar != nil {
                    Text("°").foregroundStyle(Farbe.text3)
                }
            }
            .font(Schrift.mono(zahlgroesse))
            // Der Strich endet bei `breite + 14`, die Zahl beginnt bei `breite + 20`
            // (`Glas.tsx:78-80`). `position` setzt die Mitte, darum die halbe Zahlenbreite
            // dazu: drei Zeichen Mono sind 1,8 Zeilenhöhen breit.
            .position(x: breite + 20 + zahlgroesse * 0.9, y: y)
        }
    }

    /// **Eine Kapsel, kein Kasten** (`puffer/glas.ts`: `rx = breite / 2`). Die Vorlage rundet
    /// den Tank oben und unten zum Halbkreis; ein Radius von 14 Punkten machte daraus eine
    /// Kachel mit weichen Ecken.
    private var form: RoundedRectangle {
        RoundedRectangle(cornerRadius: breite / 2, style: .continuous)
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

    /// Dieselben vier Höhen wie im stehenden Glas, hier als Stellen von links nach rechts
    /// (`puffer/glas.ts:21`).
    private let stellen: [Double] = [0.125, 0.375, 0.625, 0.875]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            kopf
            band
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pufferspeicher: \(zustand.traegt ? Formate.prozent(soc) : "kein Füllstand"), \(zustand.wort)")
    }

    /// **„Puffer" steht in der Kachel, nicht über ihr** (`Rail.tsx:56-57`): links der Kicker,
    /// rechts die Zahl mit ihrem Zustandswort. Als Kartenüberschrift darüber war es eine Zeile
    /// mehr für dasselbe Wort.
    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Kicker(wort: "Puffer")
            Spacer(minLength: 8)
            Zahl(
                wert: zustand.traegt ? Formate.prozent(soc) : Formate.leer,
                schrift: Schrift.mono(30, relativeTo: .title),
                farbe: zustand.traegt ? Farbe.text1 : Farbe.text3
            )
            Text(zustand.wort)
                .font(Schrift.sans(13))
                .foregroundStyle(zustand.veraltet ? Farbe.achtung : Farbe.text3)
        }
    }

    /// **Die Zahlen stehen unter dem Band, nicht darüber** (`Rail.tsx:61-73`). Das Band ist die
    /// Sache, die Zahlen sind ihre Beschriftung - und eine Beschriftung steht unter dem Bild.
    private var band: some View {
        VStack(alignment: .leading, spacing: 3) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LinearGradient(stops: verlauf, startPoint: .leading, endPoint: .trailing))
                .frame(height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                )
                .opacity(zustand.traegt ? 1 : 0.5)
            zahlenzeile
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
