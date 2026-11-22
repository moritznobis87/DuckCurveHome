import DuckCurveKit
import SwiftUI

/// Ein Raum als Kachel: die große Zahl, das Ziel, der Tagesverlauf, die Ventile.
///
/// **Warum eine Kachel und keine Zeile.** Bis zum 18.11.2026 stand hier eine Liste – Farbpunkt,
/// Name, rechts die Temperatur – und darin fehlte alles, worum es beim Heizen geht: wie weit der
/// Raum von seinem Ziel weg ist, wie der Tag verlaufen ist und wie lange die Kreise offen
/// standen. Genau diese drei Dinge beantworten die Frage, die über die Vorlauftemperatur
/// entscheidet: **welcher Raum kommt zuerst nicht mehr mit?** Ein Raum, dessen Kreise den ganzen
/// Tag offen sind und der trotzdem unter dem Ziel bleibt, bestimmt sie für alle anderen mit.
///
/// Gestalt und Regeln sind die der Vorlage (`apps/web/src/components/rooms/RoomsReport.tsx`,
/// `RaumKachel`) in ihrer Handy-Fassung (`handy.css:364-375`): Name über die ganze Breite, links
/// die Zahlen, rechts der Verlauf, unten die Fußzeile.
struct Raumkachel: View {
    let raum: RoomLiveOut
    /// Die Tageszeitreihe dieses Raums – ohne sie bleibt der Platz leer, aber er bleibt.
    let serie: RoomSeriesOut?
    /// Wie viele Fenster auf eine Stunde gehen.
    let proStunde: Int
    /// Wie viele Fenster des Tages schon gewesen sind; `nil` heißt: alle.
    let gewesen: Int?
    let schrittMin: Int
    let stellen: (() -> Void)?
    let protokoll: () -> Void

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        // **Der Protokollknopf liegt über der Kachel, nicht in ihr.** Die Kachel ist selbst ein
        // Knopf – sie stellt den Sollwert –, und ein Knopf im Knopf ist mit VoiceOver nicht zu
        // bedienen: der äußere verschluckt den inneren. Im ZStack sind es Geschwister.
        ZStack(alignment: .bottomTrailing) {
            kachel
            Kleinknopf(wort: "Protokoll", tun: protokoll)
                .padding(.trailing, schmal ? 14 : 12)
                .padding(.bottom, schmal ? 11 : 10)
                .accessibilityLabel("\(raum.name): Protokoll der letzten Stunden")
        }
    }

    private var kachel: some View {
        Karte {
            VStack(alignment: .leading, spacing: 9) {
                kopf
                // **Zwei Anordnungen, und beide stehen in der Vorlage.** Am Telefon stehen die
                // Zahlen links und der Verlauf rechts daneben, weil eine Kachel dort die ganze
                // Breite hat und sonst zu hoch wuerde (`handy.css:364`: 1fr und 42 %). Auf dem
                // iPad stehen drei Kacheln nebeneinander, jede rund 300 Punkte breit; dort ist
                // nebeneinander kein Platz, und der Verlauf liegt unter den Zahlen und nimmt die
                // ganze Kachelbreite (`globals.css:147`: vier Zeilen uebereinander).
                if schmal {
                    HStack(alignment: .bottom, spacing: 14) {
                        zahlen
                        Spacer(minLength: 6)
                        verlauf.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    zahlen
                    verlauf
                }
                Divider().overlay(Farbe.linie1)
                fuss
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { stellen?() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vorlesen)
        .accessibilityAddTraits(stellen == nil ? [] : .isButton)
        .accessibilityHint(stellen == nil ? "" : "Antippen zum Stellen des Sollwerts.")
    }

    // MARK: - Kopf

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(raum.name)
                .font(Schrift.karte)
                .foregroundStyle(Farbe.text1)
                .lineLimit(1)
            Spacer(minLength: 6)
            // **Höchstens ein Abzeichen, und das Fenster hat Vorrang.** Beides nebeneinander
            // wäre ein Widerspruch: ein offenes Fenster erklärt die Kälte schon, dann ist der
            // Raum nicht „an der Grenze".
            if let f = fenstertext {
                Abzeichen(wort: f, farbe: Farbe.mist)
            } else if anDerGrenze {
                // Farblos und mit Zeichen. Bernstein hieße auf dieser Seite „zu warm" und sagte
                // damit das Gegenteil.
                Abzeichen(wort: "! an der Grenze", farbe: Farbe.text2, rand: Farbe.linie2)
            }
        }
    }

    // MARK: - Zahlen

    private var zahlen: some View {
        VStack(alignment: .leading, spacing: 7) {
            if raum.tempC == nil {
                Text("kein Messwert")
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text3)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Formate.zahl(raum.tempC ?? 0, stellen: 1))
                        .font(Schrift.zahlRaum)
                        .foregroundStyle(raum.quality.traegt ? Farbe.text1 : Farbe.text3)
                        .monospacedDigit()
                    Text("°C")
                        .font(Schrift.zahlKlein)
                        .foregroundStyle(Farbe.text3)
                }
            }
            // **Ziel, nicht Soll.** Geregelt wird auf Sollwert plus Versatz; der Versatz ist
            // Contromes Summe mehrerer benannter Anpassungen, nicht nur der Witterung. Am Handy
            // steht die Rechnung nicht in der Kachel – sie steht im Blatt zum Stellen, Zeile für
            // Zeile, und hier wäre sie eine vierte Zahl auf 150 Punkten Breite.
            HStack(spacing: 8) {
                Text("Ziel \(Formate.celsius(raum.targetC ?? raum.setpointC, stellen: 1))")
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                abzeichen
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Das Abzeichen der Abweichung: „am Ziel" gedeckt, sonst die Zahl in ihrer Stufenfarbe.
    private var abzeichen: some View {
        let d = raum.deviationK
        let stumm = raum.tempC == nil
        let amZiel = d != nil && abs(d ?? 0) <= Raumabweichung.band
        return Text(Raumabweichung.abweichungText(d))
            .font(Schrift.zahlKlein)
            .foregroundStyle(stumm ? Farbe.text3 : amZiel ? Farbe.text2 : Farbe.deep)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(stumm ? Color.clear : Farbe.abweichung(kelvin: d ?? 0))
            .overlay {
                if stumm {
                    RoundedRectangle(cornerRadius: Marken.radius1)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius1))
    }

    // MARK: - Verlauf

    @ViewBuilder private var verlauf: some View {
        if let s = serie {
            Raumverlauf(
                felder: felder(s),
                ventil: Raumkarte.ventilstunden(s.valve, proStunde: proStunde, gewesen: gewesen),
                linie: raum.tempC == nil ? Farbe.text3 : Farbe.abweichung(kelvin: raum.deviationK ?? 0)
            )
        } else {
            // Derselbe Platz mit Reihe und ohne: ein Raum ohne Zeitreihe soll die Kachel neben
            // sich nicht kürzer machen.
            Color.clear
        }
    }

    private func felder(_ s: RoomSeriesOut) -> [Raumabweichung.Feld] {
        Raumabweichung.felder(
            ist: s.tempC, soll: s.setpointC, versatz: s.offsetK, bisStelle: gewesen)
    }

    // MARK: - Fuß

    private var fuss: some View {
        HStack(spacing: 8) {
            Text("Ventil \(Raumabweichung.ventilText(raum.valve, kreise: raum.circuits))")
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text3)
            Spacer(minLength: 8)
            if let f = raum.humidityPct {
                Text("\(Formate.zahl(f, stellen: 0)) % rF")
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text3)
            }
        }
        // Platz für den Protokollknopf, der darüber liegt.
        .padding(.trailing, 86)
    }

    // MARK: - Die Diagnose

    private var fenstertext: String? {
        let seit = serie.flatMap { s -> Int? in
            guard let platz = Raumkarte.letzterPlatz(gewesen, laenge: s.window.count) else {
                return nil
            }
            return Raumabweichung.offenSeitMin(s.window, schrittMin: schrittMin, bis: platz)
        }
        return Raumabweichung.fensterText(offen: raum.window, seitMin: seit)
    }

    private var anDerGrenze: Bool {
        Raumkarte.anDerGrenze(
            tagesventil: serie.flatMap {
                Raumkarte.mittel(Raumkarte.ventilstunden($0.valve, proStunde: proStunde, gewesen: gewesen))
            },
            abweichung: raum.deviationK,
            fensterOffen: fenstertext != nil
        )
    }

    private var vorlesen: String {
        var s = "\(raum.name): \(Formate.celsius(raum.tempC, stellen: 1))"
        if let z = raum.targetC ?? raum.setpointC {
            s += ", Ziel \(Formate.celsius(z, stellen: 1))"
        }
        s += ", \(Raumabweichung.abweichungText(raum.deviationK))"
        s += ". Ventil \(Raumabweichung.ventilText(raum.valve, kreise: raum.circuits))"
        if let f = fenstertext { s += ". \(f)" }
        if anDerGrenze { s += ". An der Grenze: die Vorlauftemperatur reicht für diesen Raum nicht" }
        return s + "."
    }
}

/// Der Tagesverlauf einer Kachel: die Abweichung als Kurve, darunter die Ventile, darunter die
/// Achse.
///
/// **Alles in einem Canvas.** Kurve und Streifen teilen die Breite auf den Punkt – zwei Ansichten
/// übereinander mit eigenen Rändern treffen sich nie genau, und ein Streifen, der einen halben
/// Punkt breiter ist als die Kurve darüber, sieht wie ein Fehler aus.
struct Raumverlauf: View {
    let felder: [Raumabweichung.Feld]
    let ventil: [Raumabweichung.Feld]
    let linie: Color

    private var kurve: Raumkarte.Kurve { Raumkarte.kurve(felder) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Canvas { g, groesse in
                male(in: &g, groesse: groesse)
            }
            .frame(height: 38)
            .accessibilityHidden(true)
            Canvas { g, groesse in
                maleStreifen(in: &g, groesse: groesse)
            }
            .frame(height: 7)
            .accessibilityHidden(true)
            achse
        }
    }

    /// Die Kurve mit der gestrichelten Ziellinie in der Mitte.
    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        var ziel = Path()
        ziel.move(to: CGPoint(x: 0, y: groesse.height / 2))
        ziel.addLine(to: CGPoint(x: groesse.width, y: groesse.height / 2))
        g.stroke(
            ziel, with: .color(Farbe.linie2),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        for stueck in kurve.stuecke {
            var p = Path()
            for (i, punkt) in stueck.enumerated() {
                let stelle = CGPoint(x: punkt.x * groesse.width, y: punkt.y * groesse.height)
                if i == 0 { p.move(to: stelle) } else { p.addLine(to: stelle) }
            }
            g.stroke(
                p, with: .color(linie),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    /// Der Streifen: ein Feld je Stunde, die Deckkraft trägt den Anteil.
    ///
    /// **Auf oder zu, nichts dazwischen** – die verbauten Antriebe kennen keine
    /// Zwischenstellung. Ein Zwischenwert heißt deshalb „ein Teil der Kreise offen", nicht „halb
    /// offen", und steht als blassere Fläche derselben Farbe da, nicht als eigene Farbe.
    private func maleStreifen(in g: inout GraphicsContext, groesse: CGSize) {
        guard !ventil.isEmpty else { return }
        let breite = groesse.width / CGFloat(ventil.count)
        for (i, f) in ventil.enumerated() {
            let kasten = CGRect(
                x: CGFloat(i) * breite + 0.5, y: 0,
                width: max(0.5, breite - 1), height: groesse.height)
            let rund = Path(roundedRect: kasten, cornerRadius: 1)
            switch f {
            case .wert(let anteil) where anteil > 0:
                g.fill(rund, with: .color(Farbe.ventilOffen.opacity(0.35 + 0.65 * anteil)))
            case .wert:
                g.fill(rund, with: .color(.white.opacity(0.07)))
            case .nochNicht:
                g.fill(rund, with: .color(.white.opacity(0.035)))
            case .keinWert:
                // Schraffur statt Grau, wie in der Tagesmatrix: Grau wäre eine sechste Stufe
                // derselben Skala und würde als Messwert gelesen.
                g.fill(rund, with: .color(.white.opacity(0.04)))
                var schraffur = Path()
                var x = kasten.minX - kasten.height
                while x < kasten.maxX {
                    schraffur.move(to: CGPoint(x: x, y: kasten.maxY))
                    schraffur.addLine(to: CGPoint(x: x + kasten.height, y: kasten.minY))
                    x += 3
                }
                g.clip(to: rund)
                g.stroke(schraffur, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
            }
        }
    }

    /// **Die Achse ist eine Zeile, keine zwei.** Die Spanne steht am rechten Ende, wo ohnehin die
    /// 24 steht – und nur, wenn sie über ±2 K hinausgeht.
    private var achse: some View {
        HStack(spacing: 0) {
            Text("00").font(Schrift.achse).foregroundStyle(Farbe.text3)
            Spacer(minLength: 2)
            Text("12").font(Schrift.achse).foregroundStyle(Farbe.text3)
            Spacer(minLength: 2)
            HStack(spacing: 5) {
                if kurve.spanne > 2 {
                    Text("±\(Formate.zahl(kurve.spanne, stellen: 0)) K")
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                        .opacity(0.8)
                }
                Text("24").font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
        }
    }
}

/// Ein kleines Abzeichen in der Kopfzeile einer Kachel.
struct Abzeichen: View {
    let wort: String
    let farbe: Color
    var rand: Color?

    var body: some View {
        // **Eigene Maße und nicht ``Schrift/kicker``.** Das Abzeichen hatte sich die
        // Kickerschrift geborgt; die Vorlage gibt ihm eine eigene (`RoomsReport.tsx:199`
        // und `:205`: `mono text-[10px] uppercase tracking-[.08em]`, bei 10 Punkten also
        // 0,8). Seit der Kicker Mono 13 ist, wäre die Borgung ein Abzeichen in
        // Überschriftgröße.
        Text(wort.uppercased())
            .font(Schrift.mono(10, relativeTo: .caption2))
            .tracking(0.8)
            .foregroundStyle(farbe)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay {
                RoundedRectangle(cornerRadius: Marken.radius1)
                    .strokeBorder(rand ?? farbe, lineWidth: 1)
            }
    }
}

/// Die Legende über den Kacheln: die Skala und die beiden Sonderfälle.
///
/// **Sie gehört über die Kacheln, nicht in den Seitenkopf.** Dort stand sie in der Vorlage
/// zuerst und drängte den Untertitel ins Abschneiden; gebraucht wird sie hier.
struct Raumlegende: View {
    private static let marken = ["−1,5", "−0,5", "0", "+0,5", "+1,5"]

    var body: some View {
        Umbruchzeile(abstand: 18, zeilenabstand: 10) {
            HStack(alignment: .center, spacing: 10) {
                Kicker(wort: "Abweichung")
                HStack(spacing: 2) {
                    ForEach(Array(Self.marken.enumerated()), id: \.offset) { i, marke in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: Marken.radius1)
                                .fill(Farbe.abweichung[i])
                                .frame(width: 26, height: 9)
                            Text(marke).font(Schrift.achse).foregroundStyle(Farbe.text3)
                        }
                    }
                }
            }
            HStack(spacing: 14) {
                posten(farbe: Farbe.ventilOffen, wort: "Ventil offen", schraffiert: false)
                posten(farbe: .white.opacity(0.04), wort: "kein Messwert", schraffiert: true)
            }
        }
        .accessibilityHidden(true)
    }

    private func posten(farbe: Color, wort: String, schraffiert: Bool) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: Marken.radius1)
                .fill(farbe)
                .frame(width: 18, height: 8)
                .overlay {
                    if schraffiert {
                        Schraffur()
                        RoundedRectangle(cornerRadius: Marken.radius1)
                            .strokeBorder(Farbe.linie1, lineWidth: 1)
                    }
                }
            Text(wort).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
        }
    }
}

/// Die Schraffur für „kein Messwert" – 45 Grad, wie in der Tagesmatrix und im Streifen.
private struct Schraffur: View {
    var body: some View {
        Canvas { g, groesse in
            var p = Path()
            var x = -groesse.height
            while x < groesse.width {
                p.move(to: CGPoint(x: x, y: groesse.height))
                p.addLine(to: CGPoint(x: x + groesse.height, y: 0))
                x += 3
            }
            g.stroke(p, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
        }
    }
}

/// Ein kleiner Knopf mit Wort und Rand – der zweite Griff einer Kachel.
struct Kleinknopf: View {
    let wort: String
    let tun: () -> Void

    var body: some View {
        Button(action: tun) {
            // `.raum-protokoll-knopf mono` (`globals.css:175`, am Telefon
            // `handy.css:375`: `font-size: 11px; letter-spacing: .08em`, also 0,88) - nicht
            // die Kickerschrift, die er sich geborgt hatte. Polster und Radius stehen hier
            // schon in den Maßen des Telefons; die Schrift zog nach.
            Text(wort.uppercased())
                .font(Schrift.mono(11, relativeTo: .caption2))
                .tracking(0.88)
                .foregroundStyle(Farbe.text3)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.white.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
