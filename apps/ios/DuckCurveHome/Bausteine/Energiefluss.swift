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

    /// Zwei Anordnungen, und beide stehen in der Vorlage.
    ///
    /// **Die Wandanzeige ist fuer das Querformat gemacht** (`FlowHero.tsx`): Netz, Haus und
    /// Speicher in einer Reihe, Sonne darueber, Waermepumpe und Wallbox darunter. Am Telefon
    /// liefen damit sechs Knoten mit Zahlen auf 390 Punkten Breite ineinander - das Dashboard
    /// hat dafuer am 25.10.2026 ein eigenes Bild bekommen (`FlowHandy.tsx`), und die App hatte
    /// bis zum 18.11.2026 nur das Wandbild, auch auf dem Telefon.
    ///
    /// **Die Hand folgt dem Hochformat.** Oben, woher der Strom kommt: Sonne links, Netz rechts.
    /// In der Mitte das Haus, gross, mit seiner Zahl im Kreis, damit unter ihm Platz fuer die
    /// Leitungen bleibt. Unten, wohin er geht: Speicher, Waermepumpe, Wallbox, je in einem
    /// Drittel der Breite, die Beschriftung darunter. So kreuzt keine Leitung ein Wort, und drei
    /// Namen nebeneinander haben je 119 Punkte.
    enum Fassung { case wand, hand }

    /// Die Lage im Bild, in Anteilen der Flaeche.
    func lage(_ fassung: Fassung) -> UnitPoint {
        switch fassung {
        case .wand:
            switch self {
            case .pv: return UnitPoint(x: 0.50, y: 0.13)
            case .netz: return UnitPoint(x: 0.11, y: 0.48)
            case .haus: return UnitPoint(x: 0.50, y: 0.48)
            case .batterie: return UnitPoint(x: 0.89, y: 0.48)
            case .waermepumpe: return UnitPoint(x: 0.20, y: 0.78)
            case .wallbox: return UnitPoint(x: 0.80, y: 0.78)
            }
        case .hand:
            switch self {
            case .pv: return UnitPoint(x: 0.17, y: 0.14)
            case .netz: return UnitPoint(x: 0.83, y: 0.14)
            case .haus: return UnitPoint(x: 0.50, y: 0.46)
            case .batterie: return UnitPoint(x: 0.17, y: 0.75)
            case .waermepumpe: return UnitPoint(x: 0.50, y: 0.75)
            case .wallbox: return UnitPoint(x: 0.83, y: 0.75)
            }
        }
    }

    /// Auf welcher Seite die Beschriftung haengt: dort, wo keine Leitung ankommt.
    ///
    /// `FlowHero.tsx` begruendet es: so endet kein Strich zwischen Zahl und Zeichen und keiner
    /// kreuzt ein Wort. An der Wand bei der Sonne rechts (die Leitung geht nach unten), sonst
    /// unten. In der Hand haengen die beiden oberen Knoten nach aussen - die Sonne links im Bild
    /// traegt ihren Text rechts, das Netz rechts im Bild traegt ihn links -, die drei unteren
    /// tragen ihn unter sich.
    func textseite(_ fassung: Fassung) -> Textseite {
        switch fassung {
        case .wand: return self == .pv ? .rechts : .unten
        case .hand:
            switch self {
            case .pv: return .rechts
            case .netz: return .links
            default: return .unten
            }
        }
    }

    enum Textseite { case unten, rechts, links }
}

/// Die Farbe des Mondes: kuehl und hell, klar nicht das Gelb der Sonne.
let mondlicht = Color(Farbwert(0xB9CFDB))

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
    /// Welche der beiden Anordnungen gezeichnet wird.
    var fassung: Flussknoten.Fassung = .wand

    @Environment(Wegweiser.self) private var wegweiser

    var body: some View {
        GeometryReader { raum in
            ZStack {
                himmel
                if nacht { Sterne() } else { sonnenschein(in: raum.size) }
                Leitungen(flaeche: raum.size, kanten: kanten, fassung: fassung)
                ForEach(Flussknoten.allCases) { k in
                    Knoten(
                        knoten: k,
                        name: name(k),
                        wertText: wertText(k),
                        einheit: einheit(k),
                        zeichen: zeichen(k),
                        farbeUeber: farbeUeber(k),
                        ohneZahl: ohneZahl(k),
                        ohneNamen: fassung == .hand && k == .haus,
                        seite: k.textseite(fassung),
                        // **Die Guete gehoert zu der Zahl, die dasteht** (`FlowHandy.tsx:243`:
                        // `m={s?.battery_soc}`). In der Hand zeigt der Speicher seinen
                        // Ladestand; haengt sein „kein Messwert" an der Leistung, sagt er
                        // „- %" neben „laedt 1,2 kW" - oder verschweigt den Ladestand, waehrend
                        // der Kreis sichtbar bis dorthin gefuellt ist.
                        messwert: fassung == .hand && k == .batterie
                            ? augenblick?.batterySoc : messwert(k),
                        jetzt: jetzt,
                        gross: k == .haus,
                        fuellung: k == .batterie ? ladestand : nil,
                        dazu: dazu(k)
                    ) {
                        tippe(k)
                    }
                    .position(
                        x: k.lage(fassung).x * raum.size.width,
                        y: k.lage(fassung).y * raum.size.height
                    )
                }
                // **Unter dem Haus ist kein Platz.** In der Hand laufen dort drei Leitungen zu
                // Speicher, Waermepumpe und Wallbox; die Grundlast steht deshalb rechts neben
                // dem Kreis, auf seiner Hoehe (`handy.css:52`).
                if fassung == .hand, let g = grundlast ?? fehlendeEingaenge {
                    Text(g)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: max(0, raum.size.width * 0.5 - 72), alignment: .leading)
                        .position(
                            x: raum.size.width * 0.5 + 64 + max(0, raum.size.width * 0.5 - 72) / 2,
                            y: Flussknoten.haus.lage(fassung).y * raum.size.height
                        )
                        .allowsHitTesting(false)
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

    private func sonnenschein(in flaeche: CGSize) -> some View {
        let pv = augenblick?.pvPowerKw.belastbar ?? 0
        let staerke = min(1, max(0, pv / max(1, pvSpitzeKw)))
        return Circle()
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
                x: Flussknoten.pv.lage(fassung).x * flaeche.width,
                y: Flussknoten.pv.lage(fassung).y * flaeche.height
            )
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 1.2), value: staerke)
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
            // **Nur der Anteil, der wirklich ins Haus geht** (`FlowHandy.tsx:131`): bei starker
            // Einspeisung liefe sonst eine dicke, schnelle Leitung zum Haus, waehrend der Strom
            // in Wahrheit ins Netz geht.
            Kante(
                von: .pv, nach: .haus,
                kw: min(
                    s.pvPowerKw.belastbar ?? 0,
                    (s.housePowerKw.belastbar ?? 0) + max(0, -(s.batteryPowerKw.belastbar ?? 0))
                ),
                farbe: Farbe.pv
            ),
            Kante(
                von: netz >= 0 ? .netz : .haus, nach: netz >= 0 ? .haus : .netz,
                kw: abs(netz), farbe: netz >= 0 ? Farbe.netzBezug : Farbe.netzEinspeisung
            ),
            Kante(
                von: batterie >= 0 ? .batterie : .haus, nach: batterie >= 0 ? .haus : .batterie,
                // Die Leitung ist dunkler als der Ring: #7FB7C8 gegen #9FD0DF (`FlowHandy.tsx:147`).
                kw: abs(batterie), farbe: Color(Farbwert(0x7FB7C8))
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
        // **Der rohe Wert, nicht der belastbare** (`FlowHandy.tsx:201`: `kw(m.value)`, und
        // `frisch` nur fuer die Farbe). Ein Messwert mit Guete `stale` traegt eine Zahl - der
        // Dienst schickt sie mit -, und die zeigt die Vorlage, nur grau und mit dem Alter
        // daneben. Hier stand `belastbar`, und damit wurde aus „1,8 kW, vor 7 min" ein Strich:
        // genau die Form, die `fehlt` abschaffen sollte, nur an einer anderen Stelle.
        guard let m = messwert(k)?.value else { return nil }
        // Netz und Speicher zeigen den Betrag: die Richtung steht in der Leitung und im Wort
        // darunter, und ein Minuszeichen daneben hiesse dasselbe zweimal.
        return (k == .netz || k == .batterie) ? abs(m) : m
    }

    /// Der Name am Knoten. **Nachts heisst die Sonne „Nacht".**
    private func name(_ k: Flussknoten) -> String {
        k == .pv && dunkel ? "Nacht" : k.name
    }

    /// An der Stelle der Sonne steht nachts ein Mond.
    private func zeichen(_ k: Flussknoten) -> Zeichenart {
        k == .pv && dunkel ? .mond : k.zeichen
    }

    private func farbeUeber(_ k: Flussknoten) -> Color? {
        if k == .pv, dunkel { return mondlicht }
        // Die Farbe des Netzes sagt die Richtung: Bernstein hinaus, Nebel herein.
        if k == .netz, let v = augenblick?.gridPowerKw.belastbar, v < 0 {
            return Farbe.netzEinspeisung
        }
        return nil
    }

    /// **„0,0 kW Sonne" ist nachts keine Auskunft.** Der Knoten zeigt dann nur Name und Zustand.
    private func ohneZahl(_ k: Flussknoten) -> Bool {
        k == .pv && dunkel
    }

    /// Nacht ist es nur, wenn auch wirklich nichts erzeugt wird: meldet die Anlage Leistung, hat
    /// die Messung recht und nicht die Erwartung.
    private var dunkel: Bool {
        nacht && (augenblick?.pvPowerKw.belastbar ?? 0) < 0.05
    }

    /// Die Zahl am Knoten, fertig gesetzt.
    ///
    /// **Der Speicher zeigt in der Hand seinen Ladestand, nicht seine Leistung.** Die Leistung
    /// steht im Wort darunter („laedt 1,2 kW"), und der Kreis ist ohnehin bis zu diesem Stand
    /// gefuellt - die Zahl daneben sagt dann dasselbe wie das Bild.
    private func wertText(_ k: Flussknoten) -> String {
        if fassung == .hand, k == .batterie {
            guard let soc = ladestand else { return Formate.leer }
            return String(Int((soc * 100).rounded()))
        }
        return Formate.kw(wert(k))
    }

    private func einheit(_ k: Flussknoten) -> String {
        fassung == .hand && k == .batterie ? "%" : "kW"
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
            if fassung == .hand {
                // In der Hand traegt der Knoten den Ladestand als Zahl; das Wort sagt, was der
                // Speicher gerade tut, und mit wie viel.
                if abs(v) < 0.05 { return "hält" }
                return (v > 0 ? "gibt " : "lädt ") + Formate.kwMitEinheit(abs(v))
            }
            let soc = s.batterySoc.belastbar.map { Formate.prozent($0 > 1 ? $0 / 100 : $0) }
            if abs(v) < 0.05 { return soc }
            return [v > 0 ? "entlädt" : "lädt", soc].compactMap { $0 }.joined(separator: " · ")
        case .waermepumpe:
            // **Drei Worte, nicht zwei** (`FlowHero.tsx`, `wpWort`): „läuft", wenn der Dienst es
            // meldet; „Bereitschaft", wenn sie Strom nimmt, ohne zu laufen - das ist die Pumpe
            // des Kreises oder die Abtauung, und es ist keine Stoerung; sonst „steht". Hier
            // stand „aus", und das ist das Wort eines Schalters, nicht einer Anlage.
            if wpLaeuft == true { return "läuft" }
            return (s.heatPumpPowerKw.belastbar ?? 0) >= 0.05 ? "Bereitschaft" : "steht"
        case .pv:
            return dunkel ? sonneAb.map { "Sonne ab \($0)" } : nil
        case .haus:
            // In der Hand steht die Grundlast neben dem Kreis, nicht unter ihm.
            return fassung == .hand ? nil : uebrig
        case .wallbox:
            guard let v = s.evPowerKw.belastbar else { return nil }
            return v >= 0.05 ? "lädt" : "steht"
        }
    }

    /// **Welcher der drei Eingaenge fehlt** (`FlowHandy.tsx:161-170`): der Hausverbrauch wird
    /// aus Sonne, Netz und Speicher gebildet; fehlt einer, gibt es ihn nicht - und dann steht
    /// neben dem Kreis, wo zu suchen ist.
    private var fehlendeEingaenge: String? {
        guard let s = augenblick, s.housePowerKw.value == nil else { return nil }
        let fehlend = [
            ("Sonne", s.pvPowerKw), ("Netz", s.gridPowerKw), ("Speicher", s.batteryPowerKw),
        ].filter { $0.1.belastbar == nil }.map(\.0)
        return fehlend.isEmpty ? nil : "es fehlt: " + fehlend.joined(separator: ", ")
    }

    /// Die Grundlast neben dem Hauskreis.
    ///
    /// **Die Zahl kommt vom Dienst, nicht aus einer Differenz** (`FlowHero.tsx`, `grundlast`):
    /// `base_load_kw` ist die gemessene Grundlast. Sie steht nur da, wenn ueberhaupt etwas
    /// abzuziehen ist - ohne Waermepumpe und Wallbox waere „davon 0,5 kW Grundlast" neben
    /// „0,5 kW" im Kreis dieselbe Zahl zweimal.
    private var grundlast: String? {
        guard let s = augenblick,
              let rest = s.baseLoadKw.belastbar
        else { return nil }
        let andere = (s.heatPumpPowerKw.belastbar ?? 0) + (s.evPowerKw.belastbar ?? 0)
        guard andere >= 0.05 else { return nil }
        return "davon \(Formate.kwMitEinheit(rest)) Grundlast"
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
        // **Die Waermepumpe fragt, wohin** (`FlowHandy.tsx:247`, `onOeffnen`). Wer auf sie
        // tippt, will eines von vier Dingen wissen, und welches, weiss nur er. Hier sprang die
        // App bis zum 19.11.2026 direkt in das Blatt mit Zustand und Stellen - also in eines
        // der vier, ohne zu fragen. Das Blatt haengt weiter am Dock.
        if k == .waermepumpe {
            wegweiser.blatt = .waermepumpenmenue
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
    let fassung: Flussknoten.Fassung

    var body: some View {
        ZStack {
            ForEach(Array(kanten.enumerated()), id: \.offset) { _, kante in
                Leitung(kante: kante, flaeche: flaeche, fassung: fassung)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Eine einzelne Leitung: ein ruhiger Strich, und darauf wandernde Striche, wenn sie fuehrt.
struct Leitung: View {
    let kante: Kante
    let flaeche: CGSize
    let fassung: Flussknoten.Fassung

    @State private var versatz: CGFloat = 0

    var body: some View {
        let pfad = Path { p in
            p.move(to: punkt(kante.von))
            p.addLine(to: punkt(kante.nach))
        }
        ZStack {
            pfad.stroke(
                kante.farbe.opacity(kante.an ? 0.22 : 0.14),
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
        CGPoint(x: k.lage(fassung).x * flaeche.width, y: k.lage(fassung).y * flaeche.height)
    }
}

/// Ein Knoten: Kreis mit Zeichen, daneben Zahl und Wort.
struct Knoten: View {
    let knoten: Flussknoten
    /// Der Name, wie er dasteht - nachts heisst die Sonne „Nacht".
    let name: String
    /// Die Zahl, fertig gesetzt.
    let wertText: String
    let einheit: String
    let zeichen: Zeichenart
    /// Eine andere Farbe als die des Knotens, etwa das Mondlicht oder die Einspeisung.
    var farbeUeber: Color?
    /// Der Knoten zeigt nur Name und Zustand: nachts ist „0,0 kW Sonne" keine Auskunft.
    var ohneZahl: Bool = false
    /// Der Knoten traegt gar keinen Text neben sich - der Hauskreis in der Hand.
    var ohneNamen: Bool = false
    let seite: Flussknoten.Textseite
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
        // Ein Knoten ohne Zahl sagt nicht, dass die Messung fehlt: nachts ist der Mond in
        // seiner Farbe richtig, auch wenn kein Wert dasteht.
        guard belastbar || ohneZahl else { return Farbe.text3 }
        return farbeUeber ?? knoten.farbe
    }

    /// **Ein Knoten ohne Zahl sagt, dass die Messung fehlt.** Ein Strich mit Einheit („- kW")
    /// sah aus wie ein Wert, den es nicht gibt, und der Zustand darunter („haelt", „steht")
    /// wie eine Auskunft.
    private var fehlt: Bool {
        !ohneZahl && (messwert == nil || messwert?.value == nil)
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
            // **Der grosse Kreis bleibt ungetoent** (`handy.css:48`): er ist der Knoten der
            // Summe und steht in der Grundfarbe des Hauses, dafuer mit einem weissen Schein.
            if !gross {
                Circle().fill(farbe.opacity(0.16))
            }
            Circle()
                .strokeBorder(farbe, lineWidth: 1.5)
            if gross {
                grosserInhalt
            } else {
                Zeichen(zeichen, groesse: 24, farbe: farbe)
            }
        }
        .frame(width: kante, height: kante)
        .shadow(color: gross ? .white.opacity(0.09) : .clear, radius: 23)
    }

    /// Im grossen Kreis steht die Zahl selbst, nicht das Zeichen: er ist der Knoten der Summe.
    @ViewBuilder private var grosserInhalt: some View {
        if fehlt {
            // **Ein Strich mit Einheit sieht aus wie ein Wert, den es nicht gibt**
            // (`FlowHandy.tsx:220-221`). Der Hauskreis traegt in der Hand keinen Text neben
            // sich; sagt er es nicht selbst, sagt es niemand.
            Text("Verbrauch nicht bekannt")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: kante - 24)
        } else {
            VStack(spacing: 1) {
                Text(wertText)
                    .font(Schrift.custom(32))
                    .foregroundStyle(belastbar ? Farbe.text1 : Farbe.text3)
                    .monospacedDigit()
                Text(einheit)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    @ViewBuilder private var text: some View {
        let ausrichtung: HorizontalAlignment =
            switch seite {
            case .rechts: .leading
            case .links: .trailing
            case .unten: .center
            }
        let inhalt = VStack(alignment: ausrichtung, spacing: 1) {
            if !gross, !ohneZahl, !fehlt {
                Zahl(
                    wert: wertText,
                    einheit: einheit,
                    schrift: Schrift.custom(22),
                    farbe: belastbar ? Farbe.text1 : Farbe.text3
                )
            }
            // **Unter dem Hauskreis steht in der Hand nichts** (`FlowHandy.tsx:216`): er traegt
            // seine Zahl in sich, und unter ihm laufen drei Leitungen - da ist kein Platz fuer
            // Text. An der Wand liegen Waermepumpe und Wallbox weiter aussen, dort passt es.
            if !ohneNamen {
                Text(name)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                if let zeile = unterzeile {
                    Text(zeile)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
        .fixedSize()

        switch seite {
        case .rechts:
            inhalt.offset(x: kante / 2 + 10 + breiteSchaetzung / 2, y: 0)
        case .links:
            inhalt.offset(x: -(kante / 2 + 10 + breiteSchaetzung / 2), y: 0)
        case .unten:
            inhalt.offset(x: 0, y: kante / 2 + 8 + hoeheSchaetzung / 2)
        }
    }

    /// Die Zeile unter dem Namen: das Wort dazu, und das Alter, wenn der Wert nicht traegt.
    private var unterzeile: String? {
        var teile: [String] = []
        if fehlt { return "kein Messwert" }
        if let dazu { teile.append(dazu) }
        if !belastbar, let alter { teile.append(alter) }
        if !belastbar, let wort = messwert?.quality.wort, alter == nil { teile.append(wort) }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    // Die Versatzrechnung braucht ein Mass. Feste Schaetzungen statt einer Messung: der Text
    // haengt an einem Kreis und nicht in einem Fluss, und eine Messung je Bild waere hier
    // zwei Durchlaeufe des Layouts fuer ein Ergebnis, das sich nie aendert.
    private var breiteSchaetzung: CGFloat { 96 }
    private var hoeheSchaetzung: CGFloat {
        let zahl: CGFloat = (gross || ohneZahl || fehlt) ? 0 : 24
        return zahl + 16 + (unterzeile == nil ? 0 : 14)
    }

    private var vorlesen: String {
        var s = ohneZahl || fehlt
            ? name
            : "\(name): \(wertText) \(einheit == "%" ? "Prozent" : "Kilowatt")"
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

/// Der Sternenhimmel der Nacht.
///
/// **Gesetzte Punkte, keine Zufallszahlen**, damit das Bild bei jedem Laden dasselbe ist
/// (`handy.css:56-73`, dieselben zehn Stellen). Sie stehen nur im oberen Teil: darunter liegen
/// die Knoten, und ein Stern hinter einer Zahl ist Schmutz auf dem Glas.
struct Sterne: View {
    /// Stelle in Anteilen der Flaeche, Halbmesser in Punkten, Deckkraft.
    private static let orte: [(x: Double, y: Double, r: Double, deckung: Double)] = [
        (0.34, 0.09, 1.2, 0.80),
        (0.47, 0.22, 1.0, 0.55),
        (0.58, 0.07, 1.4, 0.70),
        (0.66, 0.31, 1.0, 0.45),
        (0.41, 0.38, 1.0, 0.40),
        (0.52, 0.46, 1.2, 0.35),
        (0.08, 0.44, 1.0, 0.45),
        (0.93, 0.52, 1.0, 0.40),
        (0.27, 0.58, 1.3, 0.50),
        (0.74, 0.66, 1.0, 0.40),
    ]

    var body: some View {
        Canvas { g, groesse in
            // Der Himmel endet bei 54 Prozent der Hoehe: `inset: 0 0 46% 0` in der Vorlage.
            let hoehe = groesse.height * 0.54
            for ort in Self.orte {
                let mitte = CGPoint(x: ort.x * groesse.width, y: ort.y * hoehe)
                let kreis = Path(
                    ellipseIn: CGRect(
                        x: mitte.x - ort.r, y: mitte.y - ort.r,
                        width: ort.r * 2, height: ort.r * 2))
                g.fill(kreis, with: .color(.white.opacity(ort.deckung * 0.85)))
            }
        }
        .allowsHitTesting(false)
    }
}
