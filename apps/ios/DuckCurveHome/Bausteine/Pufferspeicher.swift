import DuckCurveKit
import SwiftUI

/// Der Pufferspeicher als Glas: ein Tank, der von oben nach unten die Farbe seiner vier Fuehler zeigt.
///
/// **Der Speicher sieht ueberall gleich aus** (Nutzerwunsch 14.11.2026): dasselbe Glas auf der
/// Startseite, im Anlagenschema und auf der Waermeseite. Stehend am iPad, liegend am Telefon -
/// dort nimmt ein stehendes Glas die halbe Hoehe fuer eine Zahl.
///
/// **Die vier Fuehler stehen auf ihrer Hoehe**, nicht in einer Legende daneben. Ein Speicher ist
/// geschichtet: oben heiss, unten kalt, und genau das ist die Auskunft. Wo ein Fuehler fehlt,
/// steht kein Punkt - und nicht einer in Grau, der wie eine Messung aussieht.
struct Pufferglas: View {
    let temperaturen: [Messwert]
    let soc: Double?
    let zustand: Pufferzustand
    var liegend: Bool = false
    /// Die Hoehe der vier Fuehler im Speicher, von oben nach unten. Aus `puffer/glas.ts`.
    private let hoehen: [Double] = [0.12, 0.38, 0.62, 0.88]

    var body: some View {
        if liegend {
            HStack(spacing: 14) {
                glas
                    .frame(width: 150, height: 74)
                werte
            }
        } else {
            VStack(spacing: 10) {
                glas
                    .frame(maxWidth: 128, maxHeight: .infinity)
                werte
            }
        }
    }

    // MARK: - Das Glas

    private var glas: some View {
        GeometryReader { raum in
            ZStack {
                form
                    .fill(
                        LinearGradient(
                            stops: verlauf,
                            startPoint: liegend ? .trailing : .top,
                            endPoint: liegend ? .leading : .bottom
                        )
                    )
                form
                    .strokeBorder(Farbe.linie2, lineWidth: 1)
                fuehlerpunkte(in: raum.size)
            }
        }
    }

    private var form: RoundedRectangle {
        RoundedRectangle(cornerRadius: liegend ? 16 : 14, style: .continuous)
    }

    /// Der Farbverlauf des Wassers: die Farbe jedes Fuehlers auf seiner Hoehe.
    ///
    /// Wo Werte fehlen, bleibt das Glas gedeckt - ein Verlauf aus zwei Messungen und zwei
    /// Vermutungen waere ein Bild, das mehr behauptet, als gemessen ist.
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
            stops.append(.init(color: wasserfarbe(wert), location: hoehen[i]))
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

    /// Die Farbskala des Wassers, aus `tokens.css` (`--heat-0` bis `--heat-4`).
    ///
    /// 25 °C ist kalt, 70 °C ist heiss. Zwischen den Stufen wird gemischt - eine Stufenskala
    /// waere hier falsch, denn ein Speicher hat keine Stufen.
    private func wasserfarbe(_ grad: Double) -> Color {
        let stufen: [(Double, Farbwert)] = [
            (25, Marken.waerme[0]), (40, Marken.waerme[1]), (50, Marken.waerme[2]),
            (60, Marken.waerme[3]), (70, Marken.waerme[4]),
        ]
        guard let erste = stufen.first, let letzte = stufen.last else { return Farbe.flaeche3 }
        if grad <= erste.0 { return Color(erste.1) }
        if grad >= letzte.0 { return Color(letzte.1) }
        for i in 1..<stufen.count where grad <= stufen[i].0 {
            let (g0, f0) = stufen[i - 1]
            let (g1, f1) = stufen[i]
            let t = (grad - g0) / (g1 - g0)
            return Color(
                Farbwert(
                    rot: f0.rot + (f1.rot - f0.rot) * t,
                    gruen: f0.gruen + (f1.gruen - f0.gruen) * t,
                    blau: f0.blau + (f1.blau - f0.blau) * t
                )
            )
        }
        return Color(letzte.1)
    }

    /// Die vier Fuehler als Punkte mit ihrer Zahl.
    private func fuehlerpunkte(in flaeche: CGSize) -> some View {
        ForEach(Array(temperaturen.enumerated()), id: \.offset) { i, m in
            if i < hoehen.count, let wert = m.belastbar {
                Text(Formate.celsius(wert))
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.deep)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.72))
                    .clipShape(Capsule())
                    .position(
                        x: liegend ? (1 - hoehen[i]) * flaeche.width : flaeche.width / 2,
                        y: liegend ? flaeche.height / 2 : hoehen[i] * flaeche.height
                    )
            }
        }
    }

    // MARK: - Fuellstand und Wort

    private var werte: some View {
        VStack(alignment: liegend ? .leading : .center, spacing: 2) {
            Zahl(
                wert: zustand.traegt ? Formate.prozent(soc) : Formate.leer,
                schrift: Schrift.zahlGross,
                farbe: zustand.traegt ? Farbe.text1 : Farbe.text3
            )
            Text(zustand.wort)
                .font(Schrift.winzig)
                .foregroundStyle(zustand.veraltet ? Farbe.achtung : Farbe.text3)
                .multilineTextAlignment(liegend ? .leading : .center)
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
