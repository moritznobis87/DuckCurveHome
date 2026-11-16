import DuckCurveKit
import SwiftUI

/// Die Knoten des Energieflusses.
enum Flussknoten: String, CaseIterable, Identifiable {
    case pv, netz, haus, batterie, waermepumpe, wallbox

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pv: return "Sonne"
        case .netz: return "Netz"
        case .haus: return "Haus"
        case .batterie: return "Speicher"
        case .waermepumpe: return "Wärmepumpe"
        case .wallbox: return "Wallbox"
        }
    }

    var farbe: Color {
        switch self {
        case .pv: return Farbe.pv
        case .netz: return Farbe.netzBezug
        // Das Haus ist weiss: es ist der Knoten der Summe, auf den die drei Leitungen zielen.
        case .haus: return Farbe.text1
        case .batterie: return Color(Farbwert(0x9FD0DF))
        case .waermepumpe: return Farbe.waermepumpe
        case .wallbox: return Color(Farbwert(0x8FC3D6))
        }
    }

    var zeichen: Zeichenart {
        switch self {
        case .pv: return .sonne
        case .netz: return .netz
        case .haus: return .haus
        case .batterie: return .batterie
        case .waermepumpe: return .waermepumpe
        case .wallbox: return .auto
        }
    }

    /// Wohin ein Tippen fuehrt.
    var weg: String {
        switch self {
        case .pv: return "/strom/pv"
        case .netz: return "/strom"
        case .haus: return "/strom"
        case .batterie: return "/strom/speicher"
        case .waermepumpe: return "/waerme/waermepumpe"
        case .wallbox: return "/strom/wallbox"
        }
    }

    /// Die Lage im Bild, in Anteilen der Flaeche. Uebernommen aus `FlowHero.tsx`.
    var lage: UnitPoint {
        switch self {
        case .pv: return UnitPoint(x: 0.50, y: 0.13)
        case .netz: return UnitPoint(x: 0.11, y: 0.48)
        case .haus: return UnitPoint(x: 0.50, y: 0.48)
        case .batterie: return UnitPoint(x: 0.89, y: 0.48)
        case .waermepumpe: return UnitPoint(x: 0.20, y: 0.78)
        case .wallbox: return UnitPoint(x: 0.80, y: 0.78)
        }
    }

    /// Auf welcher Seite die Beschriftung haengt: dort, wo keine Leitung ankommt.
    ///
    /// `FlowHero.tsx` begruendet es: so endet kein Strich zwischen Zahl und Zeichen und keiner
    /// kreuzt ein Wort. Bei der Sonne rechts (die Leitung geht nach unten), sonst unten.
    var textseite: Textseite {
        self == .pv ? .rechts : .unten
    }

    enum Textseite { case unten, rechts }
}

/// Der Energiefluss als Bild.
///
/// **Die Kreise sind die Ziele.** Jede Leitung laeuft von Kreismitte zu Kreismitte; der Kreis
/// liegt darueber und deckt ihr Ende ab.
///
/// **Knoten sind Text, Leitungen sind Striche.** `FlowHero.tsx` beschreibt, warum das getrennt
/// ist: vorher war alles ein SVG, und die Zahlen skalierten mit der Karte - je groesser der
/// Bildschirm, desto groesser die Schrift, bis sie hinter die Nachbarkreise lief. Hier stehen die
/// Knoten als eigene Ansichten an festen Anteilspositionen, die Schrift hat ihre Groesse, und
/// nur die Leitungen dahinter fuellen die Flaeche.
///
/// **Der Sonnenschein ist ein Messwert.** Der Lichtschein hinter der Sonne hat die Staerke der
/// PV-Leistung. An einem grauen Tag ist er fast aus; das ist kein Schmuck, sondern die Auskunft.
struct Energiefluss: View {
    let augenblick: EnergySnapshot?
    let jetzt: Date
    /// Die hoechste erwartete PV-Leistung - daran haengt die Staerke des Scheins.
    var pvSpitzeKw: Double = 5
    var wpLaeuft: Bool?
    var nacht: Bool = false
    /// Wann die Sonne wiederkommt, nachts.
    var sonneAb: String?

    @Environment(Wegweiser.self) private var wegweiser

    var body: some View {
        GeometryReader { raum in
            ZStack {
                himmel
                sonnenschein(in: raum.size)
                Leitungen(flaeche: raum.size, kanten: kanten)
                ForEach(Flussknoten.allCases) { k in
                    Knoten(
                        knoten: k,
                        wert: wert(k),
                        messwert: messwert(k),
                        jetzt: jetzt,
                        gross: k == .haus,
                        fuellung: k == .batterie ? ladestand : nil,
                        dazu: dazu(k)
                    ) {
                        tippe(k)
                    }
                    .position(
                        x: k.lage.x * raum.size.width,
                        y: k.lage.y * raum.size.height
                    )
                }
            }
        }
        .frame(height: 410)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Hintergrund

    private var himmel: some View {
        // Nacht: dunkler Himmel ohne Schein. Tag: ein Verlauf, der oben aufhellt, wo die Sonne steht.
        RadialGradient(
            colors: nacht
                ? [Color(Farbwert(0x143848)), Color(Farbwert(0x0C2A37)), Color(Farbwert(0x0B2734))]
                : [Color(Farbwert(0x1A4658)), Farbe.flaeche2],
            center: UnitPoint(x: 0.5, y: 0),
            startRadius: 0,
            endRadius: 420
        )
    }

    @ViewBuilder private func sonnenschein(in flaeche: CGSize) -> some View {
        if !nacht {
            let pv = augenblick?.pvPowerKw.belastbar ?? 0
            let staerke = min(1, max(0, pv / max(1, pvSpitzeKw)))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Farbe.amber.opacity(0.36 * staerke), Farbe.amber.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .position(
                    x: Flussknoten.pv.lage.x * flaeche.width,
                    y: Flussknoten.pv.lage.y * flaeche.height
                )
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 1.2), value: staerke)
        }
    }

    // MARK: - Die Leitungen

    /// Welche Leitung wie stark fuehrt, und in welche Richtung.
    ///
    /// Die Vorzeichenkonvention des Hauses: `grid_power_kw` > 0 ist Bezug, < 0 Einspeisung;
    /// `battery_power_kw` > 0 ist Entladen, < 0 Laden. Die Richtung der Leitung folgt daraus -
    /// bei Einspeisung laeuft sie vom Haus zum Netz und nicht umgekehrt.
    private var kanten: [Kante] {
        guard let s = augenblick else { return [] }
        let netz = s.gridPowerKw.belastbar ?? 0
        let batterie = s.batteryPowerKw.belastbar ?? 0
        return [
            Kante(von: .pv, nach: .haus, kw: s.pvPowerKw.belastbar ?? 0, farbe: Farbe.pv),
            Kante(
                von: netz >= 0 ? .netz : .haus, nach: netz >= 0 ? .haus : .netz,
                kw: abs(netz), farbe: netz >= 0 ? Farbe.netzBezug : Farbe.netzEinspeisung
            ),
            Kante(
                von: batterie >= 0 ? .batterie : .haus, nach: batterie >= 0 ? .haus : .batterie,
                kw: abs(batterie), farbe: Flussknoten.batterie.farbe
            ),
            Kante(
                von: .haus, nach: .waermepumpe, kw: s.heatPumpPowerKw.belastbar ?? 0,
                farbe: Farbe.waermepumpe
            ),
            Kante(
                von: .haus, nach: .wallbox, kw: s.evPowerKw.belastbar ?? 0,
                farbe: Flussknoten.wallbox.farbe
            ),
        ]
    }

    // MARK: - Werte an den Knoten

    private func messwert(_ k: Flussknoten) -> Messwert? {
        guard let s = augenblick else { return nil }
        switch k {
        case .pv: return s.pvPowerKw
        case .netz: return s.gridPowerKw
        case .haus: return s.housePowerKw
        case .batterie: return s.batteryPowerKw
        case .waermepumpe: return s.heatPumpPowerKw
        case .wallbox: return s.evPowerKw
        }
    }

    private func wert(_ k: Flussknoten) -> Double? {
        // Netz und Speicher zeigen den Betrag: die Richtung steht in der Leitung und im Wort
        // darunter, und ein Minuszeichen daneben hiesse dasselbe zweimal.
        guard let m = messwert(k)?.belastbar else { return nil }
        return (k == .netz || k == .batterie) ? abs(m) : m
    }

    /// Das Wort unter dem Knoten, wo es eines braucht.
    private func dazu(_ k: Flussknoten) -> String? {
        guard let s = augenblick else { return nil }
        switch k {
        case .netz:
            guard let v = s.gridPowerKw.belastbar else { return nil }
            if abs(v) < 0.05 { return nil }
            return v > 0 ? "Bezug" : "Einspeisung"
        case .batterie:
            guard let v = s.batteryPowerKw.belastbar else { return nil }
            let soc = s.batterySoc.belastbar.map { Formate.prozent($0 > 1 ? $0 / 100 : $0) }
            if abs(v) < 0.05 { return soc }
            return [v > 0 ? "entlädt" : "lädt", soc].compactMap { $0 }.joined(separator: " · ")
        case .waermepumpe:
            guard let laeuft = wpLaeuft else { return nil }
            return laeuft ? "läuft" : "aus"
        case .pv:
            return nacht ? sonneAb.map { "Sonne ab \($0)" } : nil
        case .haus:
            return uebrig
        case .wallbox:
            guard let v = s.evPowerKw.belastbar, v >= 0.05 else { return nil }
            return "lädt"
        }
    }

    /// Was vom Hausverbrauch bleibt, wenn Waermepumpe und Wallbox abgezogen sind.
    ///
    /// `FlowHero.tsx` erzaehlt, warum das dasteht: Waermepumpe und Wallbox haengen als eigene
    /// Kreise unter dem Haus, und wer die beiden vom Hausverbrauch abzieht, fand eine Zahl, die
    /// nirgends stand - „Das Haus nimmt 0,5 kW, die Pumpe 0,1 - wo sind die anderen 0,4?"
    /// (gefragt am 29.10.2026).
    private var uebrig: String? {
        guard let s = augenblick,
              let haus = s.housePowerKw.belastbar
        else { return nil }
        let abzug = (s.heatPumpPowerKw.belastbar ?? 0) + (s.evPowerKw.belastbar ?? 0)
        guard abzug >= 0.05 else { return nil }
        let rest = haus - abzug
        guard rest >= 0.05 else { return nil }
        return "übrige \(Formate.kwMitEinheit(rest))"
    }

    private var ladestand: Double? {
        guard let soc = augenblick?.batterySoc.belastbar else { return nil }
        return soc > 1 ? soc / 100 : soc
    }

    private func tippe(_ k: Flussknoten) {
        // Die Waermepumpe oeffnet ein Blatt: sie kann mehr als an und aus.
        if k == .waermepumpe {
            wegweiser.blatt = .waermepumpe
        } else if k == .batterie {
            wegweiser.blatt = .batterie
        } else {
            wegweiser.gehe(k.weg)
        }
    }
}

/// Eine Leitung zwischen zwei Knoten.
struct Kante {
    let von: Flussknoten
    let nach: Flussknoten
    let kw: Double
    let farbe: Color

    /// Unter 50 Watt laeuft nichts. Darunter wuerde jede Messabweichung als Fluss erscheinen.
    var an: Bool { kw >= 0.05 }

    /// Die Strichbreite nach der Leistung. Gedeckelt, damit 11 kW am Wallbox-Lader nicht die
    /// halbe Flaeche einnehmen.
    var breite: CGFloat {
        an ? min(6, 2.2 + kw * 0.6) : 2
    }

    /// Wie schnell die Striche wandern. Mehr Leistung, schneller - das ist die eigentliche
    /// Auskunft des Bildes, und sie kommt ohne Zahl an.
    var dauer: Double {
        kw > 3 ? 1.4 : kw > 0.8 ? 2.2 : 3.4
    }
}

/// Die Leitungen, als ein Bild hinter den Knoten.
struct Leitungen: View {
    let flaeche: CGSize
    let kanten: [Kante]

    var body: some View {
        ZStack {
            ForEach(Array(kanten.enumerated()), id: \.offset) { _, kante in
                Leitung(kante: kante, flaeche: flaeche)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Eine einzelne Leitung: ein ruhiger Strich, und darauf wandernde Striche, wenn sie fuehrt.
struct Leitung: View {
    let kante: Kante
    let flaeche: CGSize

    @State private var versatz: CGFloat = 0

    var body: some View {
        let pfad = Path { p in
            p.move(to: punkt(kante.von))
            p.addLine(to: punkt(kante.nach))
        }
        ZStack {
            pfad.stroke(
                kante.farbe.opacity(kante.an ? 0.3 : 0.14),
                style: StrokeStyle(lineWidth: kante.breite, lineCap: .round)
            )
            if kante.an {
                pfad.stroke(
                    kante.farbe,
                    style: StrokeStyle(
                        lineWidth: kante.breite,
                        lineCap: .round,
                        dash: [10, 16],
                        dashPhase: versatz
                    )
                )
                .onAppear { laufe() }
                .onChange(of: kante.dauer) { _, _ in laufe() }
            }
        }
    }

    private func laufe() {
        versatz = 0
        withAnimation(.linear(duration: kante.dauer).repeatForever(autoreverses: false)) {
            versatz = -26
        }
    }

    private func punkt(_ k: Flussknoten) -> CGPoint {
        CGPoint(x: k.lage.x * flaeche.width, y: k.lage.y * flaeche.height)
    }
}

/// Ein Knoten: Kreis mit Zeichen, daneben Zahl und Wort.
struct Knoten: View {
    let knoten: Flussknoten
    let wert: Double?
    let messwert: Messwert?
    let jetzt: Date
    var gross: Bool = false
    /// Der Ladestand, als Anteil - fuellt den Kreis von unten.
    var fuellung: Double?
    var dazu: String?
    let tippen: () -> Void

    private var belastbar: Bool {
        messwert?.quality.traegt == true && messwert?.value != nil
    }

    private var alter: String? {
        messwert?.alter(jetzt: jetzt)
    }

    private var farbe: Color {
        belastbar ? knoten.farbe : Farbe.text3
    }

    private var kante: CGFloat { gross ? 108 : 52 }

    var body: some View {
        Button(action: tippen) {
            ZStack {
                ring
                text
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vorlesen)
        .accessibilityAddTraits(.isButton)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(gross ? Farbe.deep : Farbe.petrol)
            if let fuellung {
                // Der Ladestand als Flaeche von unten, nicht als Ring: so ist er auch bei 52
                // Punkten Durchmesser als Ladung zu lesen.
                GeometryReader { r in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color(Farbwert(0x7FB7C8, deckung: 0.3)))
                            .frame(height: r.size.height * min(1, max(0, fuellung)))
                    }
                }
                .clipShape(Circle())
            }
            Circle()
                .fill(farbe.opacity(0.14))
            Circle()
                .strokeBorder(farbe, lineWidth: 1.5)
            if gross {
                grosserInhalt
            } else {
                Zeichen(knoten.zeichen, groesse: 26, farbe: farbe)
            }
        }
        .frame(width: kante, height: kante)
    }

    /// Im grossen Kreis steht die Zahl selbst, nicht das Zeichen: er ist der Knoten der Summe.
    private var grosserInhalt: some View {
        VStack(spacing: 1) {
            Text(Formate.kw(wert))
                .font(Schrift.custom(32))
                .foregroundStyle(belastbar ? Farbe.text1 : Farbe.text3)
                .monospacedDigit()
            Text("kW")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
        }
    }

    @ViewBuilder private var text: some View {
        let inhalt = VStack(alignment: knoten.textseite == .rechts ? .leading : .center, spacing: 1) {
            if !gross {
                Zahl(
                    wert: Formate.kw(wert),
                    einheit: "kW",
                    schrift: Schrift.custom(22),
                    farbe: belastbar ? Farbe.text1 : Farbe.text3
                )
            }
            Text(knoten.name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
            if let zeile = unterzeile {
                Text(zeile)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
        }
        .fixedSize()

        switch knoten.textseite {
        case .rechts:
            inhalt.offset(x: kante / 2 + 14 + breiteSchaetzung / 2, y: 0)
        case .unten:
            inhalt.offset(x: 0, y: kante / 2 + 10 + hoeheSchaetzung / 2)
        }
    }

    /// Die Zeile unter dem Namen: das Wort dazu, und das Alter, wenn der Wert nicht traegt.
    private var unterzeile: String? {
        var teile: [String] = []
        if let dazu { teile.append(dazu) }
        if !belastbar, let alter { teile.append(alter) }
        if !belastbar, let wort = messwert?.quality.wort, alter == nil { teile.append(wort) }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    // Die Versatzrechnung braucht ein Mass. Feste Schaetzungen statt einer Messung: der Text
    // haengt an einem Kreis und nicht in einem Fluss, und eine Messung je Bild waere hier
    // zwei Durchlaeufe des Layouts fuer ein Ergebnis, das sich nie aendert.
    private var breiteSchaetzung: CGFloat { 96 }
    private var hoeheSchaetzung: CGFloat { unterzeile == nil ? 38 : 52 }

    private var vorlesen: String {
        var s = "\(knoten.name): \(Formate.kw(wert)) Kilowatt"
        if let dazu { s += ", \(dazu)" }
        if !belastbar, let alter { s += ", \(alter)" }
        return s + ". Details öffnen."
    }
}

extension Schrift {
    /// Eine Zahl in einer festen Groesse. Das Flussbild hat eigene Groessen, weil die Kreise
    /// feste Durchmesser haben - eine Schrift, die mit „Groesserer Text" waechst, laeuft dort
    /// aus dem Kreis.
    static func custom(_ groesse: CGFloat) -> Font {
        Font.custom(mono, fixedSize: groesse)
    }
}
