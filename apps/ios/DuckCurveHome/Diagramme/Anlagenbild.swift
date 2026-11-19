import DuckCurveKit
import SwiftUI

/// Das Anlagenschema: eine Bühne, auf der man sieht, was gerade fließt.
///
/// **Links der Strom, rechts die Wärme.** Drei Stromquellen sammeln sich in einem Knoten und
/// laufen von dort in die Wärmepumpe und hinunter zum Haushalt. Rechts steht der Speicher als
/// Glas, und an ihm treffen sich vier getrennte Wasserkreise, die sich nur dort berühren: der
/// Ofenkreis (ganz oben hinein, unten heraus), der Wärmepumpenkreis (Mitte hinein, unten
/// heraus), der Heizkreis (Mitte heraus, unten hinein) und das Trinkwasser, das unten kalt
/// nachläuft und oben warm entnommen wird.
///
/// **Das ganze Bild, zum Schieben** (Nutzerwunsch 17.11.2026). Die Bühne ist 1200 × 640 – quer
/// auf einem iPad ist das die Vorlage, am Telefon im Hochformat wäre sie 358 Punkte breit und
/// darin nichts zu lesen. Sie wird darum auf eine lesbare Höhe gebracht und waagerecht
/// geschoben, wie der Plan einer Anlage. Hochkant umzubrechen wäre ein anderes Bild gewesen.
///
/// **Reihenfolge ist Tiefe.** Was später kommt, liegt oben: erst die Lichter, dann die Rohre,
/// dann die Geräte. Der Wärmepumpenvorlauf bekommt einen dunklen Hof, damit er über dem
/// Ofensteiger sichtbar bleibt, statt mit ihm zu verschmelzen.
struct Anlagenbild: View {
    let anlage: AnlageOut
    let jetzt: Date

    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.accessibilityReduceMotion) private var ruhig

    /// Wie hoch die Bühne gezeichnet wird. Darunter sind die Zahlen nicht mehr zu lesen.
    private let hoehe: CGFloat = 430

    private var breite: CGFloat {
        hoehe / Anlagenrohre.buehne.height * Anlagenrohre.buehne.width
    }
    private var maß: CGFloat { hoehe / Anlagenrohre.buehne.height }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            buehne
                .frame(width: breite, height: hoehe)
        }
        .frame(height: hoehe)
        .accessibilityLabel(
            "Anlagenschema. Strom links, Speicher als Glas rechts, vier getrennte Wasserkreise.")
    }

    private var buehne: some View {
        ZStack(alignment: .topLeading) {
            lichter
            rohre
            geraete
        }
        // Gezeichnet wird in den Koordinaten der Vorlage; die Verkleinerung macht eine Stelle.
        .frame(width: Anlagenrohre.buehne.width, height: Anlagenrohre.buehne.height)
        .scaleEffect(maß, anchor: .topLeading)
        .frame(width: breite, height: hoehe, alignment: .topLeading)
    }

    // MARK: - Was wie stark fließt

    private var strom: AnlageStromOut { anlage.strom }
    private var wp: AnlageWaermepumpeOut { anlage.waermepumpe }
    private var ofen: AnlageOfenOut { anlage.ofen }
    private var puffer: AnlageSpeicherOut { anlage.speicher }
    private var heizkreis: AnlageHeizkreisOut { anlage.heizkreis }
    private var warmwasser: AnlageWarmwasserOut { anlage.warmwasser }

    /// Die Wasserkreise haben keine gemessene Leistung – ihre Stärke steht für „läuft".
    private var wpKw: Double { wp.running ? (wp.thermalKw ?? 5) : 0 }
    private var ofenKw: Double { ofen.running == true ? (ofen.waterKw ?? 5) : 0 }
    private var heizKw: Double { heizkreis.running ? 4 : 0 }
    private var wasserKw: Double { warmwasser.tapping == true ? 1.5 : 0 }

    private var fuehler: [Double?] { puffer.tempsC }
    private func fuehler(_ i: Int) -> Double? {
        i < fuehler.count ? fuehler[i] : nil
    }
    private var ruecklauf: Double? { puffer.returnC }
    private var mischung: Anlagenschema.Mischung { Anlagenschema.mischung(strom) }

    // MARK: - Die Lichter dahinter

    private var lichter: some View {
        ZStack {
            schein(
                mitte: CGPoint(x: 120, y: 150), weite: 180,
                farbe: Farbe.pv,
                staerke: 0.08 + min(0.9, (strom.pvKw ?? 0) * 0.14))
            schein(
                mitte: CGPoint(x: 550, y: 145), weite: 400, hoch: 160,
                farbe: Farbe.ofen, staerke: ofen.running == true ? 0.5 : 0)
            schein(
                mitte: CGPoint(x: 550, y: 332), weite: 420, hoch: 190,
                farbe: Farbe.waermepumpe, staerke: wp.running ? 0.3 : 0)
        }
        .animation(.easeInOut(duration: 1.2), value: wp.running)
    }

    private func schein(
        mitte: CGPoint, weite: CGFloat, hoch: CGFloat? = nil, farbe: Color, staerke: Double
    ) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [farbe.opacity(staerke), farbe.opacity(0)],
                    center: .center, startRadius: 0, endRadius: weite / 2)
            )
            .frame(width: weite, height: hoch ?? weite)
            .position(mitte)
            .allowsHitTesting(false)
    }

    // MARK: - Die Rohre

    private var rohre: some View {
        TimelineView(.animation(minimumInterval: ruhig ? 1 : 1.0 / 30)) { takt in
            Canvas { gestalt, _ in
                let sekunden = takt.date.timeIntervalSinceReferenceDate
                for r in rohrliste {
                    zeichne(r, in: &gestalt, sekunden: sekunden)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Ein Rohr mit allem, was seine Darstellung bestimmt.
    private struct Rohrzug {
        let kennung: Anlagenrohre.Kennung
        let kw: Double?
        let farbe: Color
        var umkehren = false
        var leise = false
        /// Für Stränge mit gemischtem Strom: jeder Lichtpunkt trägt die Farbe einer Quelle.
        var farben: [Color] = []
        var hof = false
    }

    private var rohrliste: [Rohrzug] {
        let m = mischung
        let mischfarben = m.farben.map(Color.init)
        let einspeisung = Anlagenschema.istAn(strom.gridKw) && (strom.gridKw ?? 0) < 0
        let laedt = Anlagenschema.istAn(strom.batteryKw) && (strom.batteryKw ?? 0) < 0
        return [
            Rohrzug(kennung: .pv, kw: strom.pvKw, farbe: Color(Anlagenschema.Farbwerte.pv)),
            Rohrzug(
                kennung: .netz, kw: strom.gridKw,
                farbe: Color(einspeisung ? Anlagenschema.Farbwerte.pvWeich : Anlagenschema.Farbwerte.netz),
                umkehren: einspeisung),
            Rohrzug(
                kennung: .batterie, kw: strom.batteryKw,
                farbe: Color(Anlagenschema.Farbwerte.speicher), umkehren: laedt),
            Rohrzug(
                kennung: .zurWaermepumpe, kw: strom.heatPumpKw, farbe: Color(m.haupt),
                farben: mischfarben),
            Rohrzug(
                kennung: .zumHaushalt, kw: strom.restKw, farbe: Color(m.haupt),
                farben: mischfarben),
            Rohrzug(
                kennung: .ofenVorlauf, kw: ofenKw,
                farbe: Color(Anlagenschema.farbe(ofen.flowC ?? fuehler(0)))),
            Rohrzug(
                kennung: .ruecklauf, kw: wpKw + ofenKw,
                farbe: Color(Anlagenschema.farbe(ruecklauf)), leise: true),
            Rohrzug(
                kennung: .ofenRuecklauf, kw: ofenKw,
                farbe: Color(Anlagenschema.farbe(ruecklauf)), leise: true),
            Rohrzug(
                kennung: .wpRuecklauf, kw: wpKw,
                farbe: Color(Anlagenschema.farbe(ruecklauf)), leise: true),
            Rohrzug(
                kennung: .wpVorlauf, kw: wpKw,
                farbe: Color(Anlagenschema.farbe(wp.flowC ?? fuehler(1))), hof: true),
            Rohrzug(
                kennung: .kaltwasser, kw: wasserKw,
                farbe: Color(Anlagenschema.farbe(warmwasser.inletC ?? 12)), leise: true),
            Rohrzug(
                kennung: .warmwasser, kw: wasserKw,
                farbe: Color(Anlagenschema.farbe(fuehler(0).map { $0 + 2 }))),
            Rohrzug(
                kennung: .heizung, kw: heizKw,
                farbe: Color(Anlagenschema.farbe(fuehler(2)))),
            Rohrzug(
                kennung: .heizungRuecklauf, kw: heizKw,
                farbe: Color(Anlagenschema.farbe(ruecklauf)), leise: true),
        ]
    }

    /// Ein Rohr: Grundschicht breit und leise, Kern dünn und hell, Licht wandert darauf.
    ///
    /// `leise` sind Rückläufe – schmaler, blasser, weniger Licht, damit die Schleife als Paar
    /// lesbar bleibt und der Vorlauf das Wort führt.
    private func zeichne(_ r: Rohrzug, in gestalt: inout GraphicsContext, sekunden: Double) {
        let rohr = Anlagenrohre.rohr(r.kennung)
        let an = Anlagenschema.istAn(r.kw)
        let staerke = Anlagenschema.rohrStaerke(r.kw, leise: r.leise)

        if r.hof {
            gestalt.stroke(
                rohr.pfad, with: .color(Farbe.grund.opacity(0.85)),
                style: StrokeStyle(lineWidth: staerke + 7, lineCap: .round))
        }
        gestalt.stroke(
            rohr.pfad, with: .color(r.farbe.opacity(an ? 0.3 : 0.14)),
            style: StrokeStyle(lineWidth: staerke, lineCap: .round))
        gestalt.stroke(
            rohr.pfad, with: .color(r.farbe.opacity(an ? 0.9 : 0.3)),
            style: StrokeStyle(lineWidth: r.leise ? 1.2 : 1.8, lineCap: .round))

        guard an, let kw = r.kw else { return }
        let zahl = r.farben.isEmpty ? Anlagenschema.punktzahl(kw, leise: r.leise) : r.farben.count
        let dauer = Anlagenschema.rohrDauer(kw, leise: r.leise)
        let halbmesser: CGFloat = r.leise ? 2.6 : 3.4
        for i in 0..<max(0, zahl) {
            var anteil = (sekunden / dauer + Double(i) / Double(zahl))
                .truncatingRemainder(dividingBy: 1)
            if r.umkehren { anteil = 1 - anteil }
            let p = rohr.punkt(bei: anteil)
            let farbe = r.farben.isEmpty ? r.farbe : r.farben[i % r.farben.count]
            gestalt.fill(
                Path(ellipseIn: CGRect(
                    x: p.x - halbmesser, y: p.y - halbmesser,
                    width: halbmesser * 2, height: halbmesser * 2)),
                with: .color(farbe))
        }
    }

    // MARK: - Die Geräte

    private var geraete: some View {
        ZStack(alignment: .topLeading) {
            Text("Strom").modifier(Ueberschrift()).position(x: 60 + 26, y: 46)
            Text("Wärme").modifier(Ueberschrift()).position(x: 420 + 30, y: 46)

            quelle(
                .pv, mitte: CGPoint(x: 120, y: 150), rand: Anlagenschema.Farbwerte.pv,
                name: "Sonne", wert: strom.pvKw, hinweis: nil)
            quelle(
                .netz, mitte: CGPoint(x: 120, y: 300), rand: Anlagenschema.Farbwerte.netz,
                name: "Netz", wert: strom.gridKw,
                hinweis: Anlagenschema.netzWort(strom.gridKw))
            quelle(
                .batterie, mitte: CGPoint(x: 120, y: 450),
                rand: Anlagenschema.Farbwerte.speicher, name: "Speicher",
                wert: strom.batteryKw,
                hinweis: batteriewort)
            knoten
            quelle(
                .haus, mitte: CGPoint(x: 330, y: 470), halbmesser: 38,
                rand: Anlagenschema.Farbwerte.wallbox, name: "Haushalt", wert: strom.restKw,
                hinweis: "ohne Wärmepumpe")

            ofenkachel
            waermepumpenkachel
            pufferglas
            warmwasserkachel
            heizungskachel

            hinweis(
                "Kaltwasser"
                    + (warmwasser.inletC.map { " \(Int($0.rounded())) °" } ?? "")
                    + (warmwasser.tapping == true ? " läuft nach" : ""),
                an: CGPoint(x: 992, y: 563), nachLinks: false)

            pumpe(an: CGPoint(x: 748, y: 282), laeuft: wp.running, wort: wp.running ? "Pumpe" : "")
            pumpe(
                an: CGPoint(x: 745, y: 116), laeuft: ofen.running == true,
                wort: ofen.running == true ? ofen.pumpPct.map { "\(Int($0.rounded())) %" } ?? "" : "")
            pumpe(
                an: CGPoint(x: 938, y: 330), laeuft: heizkreis.running,
                wort: heizkreis.running ? "läuft" : "")

            stutzen(
                ofen.running == true ? grad(ofen.flowC) : "", an: CGPoint(x: 800, y: 48))
            stutzen(
                wp.running ? (wp.flowC != nil ? grad(wp.flowC) : "Vorlauf ?") : "",
                an: CGPoint(x: 770, y: 248))
            stutzen(
                (wp.running || ofen.running == true) && ruecklauf != nil
                    ? "zurück \(grad(ruecklauf))" : "",
                an: CGPoint(x: 774, y: 578))
            hinweis(
                heizkreis.running && ruecklauf != nil ? "zurück \(grad(ruecklauf))" : "",
                an: CGPoint(x: 1000, y: 484), nachLinks: false)
        }
    }

    private var batteriewort: String {
        let wort = Anlagenschema.batterieWort(strom.batteryKw)
        guard let soc = strom.batterySoc else { return wort }
        return "\(wort) · \(Int((soc * 100).rounded())) %"
    }

    private func grad(_ t: Double?) -> String {
        t == nil ? "-" : "\(Int((t ?? 0).rounded())) °"
    }

    /// Eine Stromquelle als Kreis mit Namen, Zahl und Wort darunter.
    private func quelle(
        _ ziel: Anlagenschema.Ziel, mitte: CGPoint, halbmesser: CGFloat = 40, rand: Farbwert,
        name: String, wert: Double?, hinweis hinweistext: String?
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color(Farbwert(0x0A2735)))
                .overlay(Circle().strokeBorder(Color(rand).opacity(0.75), lineWidth: 1.2))
                .frame(width: halbmesser * 2, height: halbmesser * 2)
            VStack(spacing: 2) {
                Text(name).font(.custom("IBMPlexSans", size: 14)).foregroundStyle(Farbe.text2)
                Text(Formate.zahl(abs(wert ?? 0), stellen: 1) + " kW")
                    .font(.custom("IBMPlexMono", size: 14))
                    .foregroundStyle(Farbe.text1)
            }
        }
        .frame(width: halbmesser * 2, height: halbmesser * 2)
        .overlay(alignment: .bottom) {
            if let hinweistext, !hinweistext.isEmpty {
                Text(hinweistext)
                    .font(.custom("IBMPlexSans", size: 11))
                    .foregroundStyle(Farbe.text3)
                    .fixedSize()
                    .offset(y: 22)
            }
        }
        .position(mitte)
        .contentShape(Circle())
        .onTapGesture { wegweiser.gehe(ziel.weg) }
        .accessibilityLabel(ziel.ansage)
        .accessibilityAddTraits(.isButton)
    }

    /// Der Knoten, in dem sich die drei Quellen sammeln.
    private var knoten: some View {
        ZStack {
            Circle().fill(.white.opacity(0.12)).frame(width: 28, height: 28).blur(radius: 4)
            Circle().fill(.white.opacity(0.9)).frame(width: 10, height: 10)
        }
        .position(x: 300, y: 300)
        .overlay(alignment: .topLeading) {
            Text(Formate.zahl(abs(strom.houseKw ?? 0), stellen: 1) + " kW im Haus")
                .font(.custom("IBMPlexSans", size: 11))
                .foregroundStyle(Farbe.text3)
                .fixedSize()
                .position(x: 230, y: 286)
        }
        .allowsHitTesting(false)
    }

    private var ofenkachel: some View {
        kachel(
            .ofen, x: 420, y: 100, breite: 260, hoehe: 90, rundung: 24,
            gedimmt: ofen.running != true
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Pelletofen").font(.custom("IBMPlexSans", size: 15))
                    .foregroundStyle(Farbe.text1)
                Text(Anlagenschema.ofenStatus(ofen)).font(.custom("IBMPlexSans", size: 12))
                    .foregroundStyle(Farbe.text3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 1) {
                    grosseZahl(
                        ofen.running == true && ofen.waterKw != nil
                            ? "≈" + Formate.zahl(abs(ofen.waterKw ?? 0), stellen: 1) : "-",
                        einheit: " kW", groesse: 30)
                    Text("ins Wasser").font(.custom("IBMPlexSans", size: 11))
                        .foregroundStyle(Farbe.text3)
                }
            }
            .padding(EdgeInsets(top: 20, leading: 26, bottom: 12, trailing: 24))
        }
    }

    private var waermepumpenkachel: some View {
        kachel(
            .waermepumpe, x: 420, y: 268, breite: 260, hoehe: 128, rundung: 26,
            gedimmt: !wp.running
        ) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Wärmepumpe").font(.custom("IBMPlexSans", size: 15))
                        .foregroundStyle(Farbe.text1)
                    Text(wp.running ? "läuft" : "steht").font(.custom("IBMPlexSans", size: 12))
                        .foregroundStyle(Farbe.text3)
                }
                VStack(alignment: .leading, spacing: 1) {
                    grosseZahl(
                        Formate.zahl(abs(wp.powerKw ?? 0), stellen: 1), einheit: " kW",
                        groesse: 26)
                    Text("Strom hinein").font(.custom("IBMPlexSans", size: 11))
                        .foregroundStyle(Farbe.text3)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                VStack(alignment: .trailing, spacing: 1) {
                    grosseZahl(
                        wp.running
                            ? (wp.thermalKw != nil
                                ? Formate.zahl(abs(wp.thermalKw ?? 0), stellen: 1) : "-")
                            : "0,0",
                        einheit: " kW", groesse: 38)
                    Text(wp.running && wp.thermalKw == nil ? "Wärme nicht gemessen" : "Wärme heraus")
                        .font(.custom("IBMPlexSans", size: 11))
                        .foregroundStyle(Farbe.text3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                copring.frame(maxWidth: .infinity, alignment: .trailing).offset(y: 12)
            }
            .padding(EdgeInsets(top: 22, leading: 26, bottom: 14, trailing: 24))
        }
    }

    /// Die Arbeitszahl als Ring: voll bei 5, wie im Dashboard.
    private var copring: some View {
        let cop = wp.cop
        let anteil = min(1, (cop ?? 0) / 5)
        return ZStack {
            Circle().strokeBorder(.white.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: anteil)
                .stroke(
                    Farbe.waermepumpe.opacity(cop != nil ? 1 : 0.15),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(cop.map { Formate.zahl($0, stellen: 1) } ?? "-")
                .font(.custom("IBMPlexMono", size: 13))
                .foregroundStyle(Farbe.text1)
        }
        .frame(width: 34, height: 34)
        .overlay(alignment: .leading) {
            Text("COP").font(.custom("IBMPlexSans", size: 10))
                .foregroundStyle(Farbe.text3)
                .fixedSize()
                .offset(x: -30)
        }
    }

    private var pufferglas: some View {
        ZStack(alignment: .topLeading) {
            Pufferglas(
                temperaturen: fuehler.map {
                    Messwert(
                        value: $0, observedAt: Zeit.iso(jetzt),
                        quality: $0 == nil ? .unavailable : .ok, source: "anlage")
                },
                soc: puffer.soc,
                zustand: Pufferzustand.aus(
                    fuehler: fuehler.map {
                        Messwert(
                            value: $0, observedAt: Zeit.iso(jetzt),
                            quality: $0 == nil ? .unavailable : .ok, source: "anlage")
                    },
                    jetzt: jetzt, laedt: wp.running || ofen.running == true, status: nil)
            )
            .frame(width: 150, height: 470)
            .position(x: 824 + 75, y: 92 + 235)
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(puffer.soc.map { "\(Int(($0 * 100).rounded())) %" } ?? "-")
                        .font(.custom("IBMPlexMono", size: 24))
                        .foregroundStyle(Farbe.text1)
                    Text(Anlagenschema.nettoText(puffer))
                        .font(.custom("IBMPlexSans", size: 12))
                        .foregroundStyle(nettofarbe)
                }
                Text(
                    "\(Formate.zahl(puffer.usableKwh, stellen: 1)) von \(Formate.zahl(puffer.capacityKwh, stellen: 1)) kWh · \(Int(puffer.volumeLiters)) l"
                )
                .font(.custom("IBMPlexSans", size: 11))
                .foregroundStyle(Farbe.text3)
            }
            .fixedSize()
            .position(x: 860, y: 612)
        }
        .contentShape(Rectangle())
        .onTapGesture { wegweiser.gehe(Anlagenschema.Ziel.puffer.weg) }
        .accessibilityLabel(Anlagenschema.Ziel.puffer.ansage)
        .accessibilityAddTraits(.isButton)
    }

    private var nettofarbe: Color {
        switch puffer.netWord {
        case "lädt": return Farbe.amberWeich
        case "entlädt": return Color(Anlagenschema.Farbwerte.speicher)
        default: return Farbe.text3
        }
    }

    private var warmwasserkachel: some View {
        kachel(
            .warmwasser, x: 980, y: 140, breite: 200, hoehe: 80, rundung: 22,
            gedimmt: !warmwasser.present
        ) {
            abnehmer(
                "Warmwasser",
                wert: warmwasser.outletC.map { "\(Int($0.rounded()))" } ?? "-", einheit: " °",
                satz: Anlagenschema.warmwasserStatus(warmwasser, jetzt: jetzt))
        }
    }

    private var heizungskachel: some View {
        kachel(
            .heizung, x: 980, y: 300, breite: 200, hoehe: 80, rundung: 22,
            gedimmt: !heizkreis.running
        ) {
            abnehmer(
                "Heizung",
                wert: heizkreis.roomsTotal > 0 ? "\(heizkreis.roomsOpen)" : "-",
                einheit: heizkreis.roomsTotal > 0 ? " von \(heizkreis.roomsTotal)" : "",
                satz: Anlagenschema.heizungStatus(heizkreis))
        }
    }

    private func abnehmer(_ name: String, wert: String, einheit: String, satz: String)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(.custom("IBMPlexSans", size: 15)).foregroundStyle(Farbe.text1)
                Spacer(minLength: 8)
                grosseZahl(wert, einheit: einheit, groesse: 22)
            }
            Text(satz).font(.custom("IBMPlexSans", size: 12)).foregroundStyle(Farbe.text3)
        }
        .padding(EdgeInsets(top: 16, leading: 24, bottom: 14, trailing: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Bausteine

    private func kachel<Inhalt: View>(
        _ ziel: Anlagenschema.Ziel, x: CGFloat, y: CGFloat, breite: CGFloat, hoehe: CGFloat,
        rundung: CGFloat, gedimmt: Bool, @ViewBuilder inhalt: () -> Inhalt
    ) -> some View {
        inhalt()
            .frame(width: breite, height: hoehe, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: rundung, style: .continuous)
                    .fill(Farbe.flaeche2.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: rundung, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.28), .white.opacity(0.06),
                                        .white.opacity(0.02),
                                    ],
                                    startPoint: .top, endPoint: .bottom),
                                lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.38), radius: 14, y: 14)
            )
            .opacity(gedimmt ? 0.7 : 1)
            .position(x: x + breite / 2, y: y + hoehe / 2)
            .contentShape(RoundedRectangle(cornerRadius: rundung, style: .continuous))
            .onTapGesture { wegweiser.gehe(ziel.weg) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(ziel.ansage)
            .accessibilityAddTraits(.isButton)
    }

    private func grosseZahl(_ wert: String, einheit: String, groesse: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(wert)
                .font(.custom("IBMPlexMono", size: groesse))
                .foregroundStyle(Farbe.text1)
            if wert != "-", !einheit.isEmpty {
                Text(einheit)
                    .font(.custom("IBMPlexSans", size: max(11, groesse * 0.42)))
                    .foregroundStyle(Farbe.text3)
            }
        }
        .fixedSize()
    }

    private func pumpe(an: CGPoint, laeuft: Bool, wort: String) -> some View {
        ZStack {
            Circle().fill(.white.opacity(laeuft ? 0.16 : 0)).frame(width: 26, height: 26)
                .blur(radius: 4)
            Circle()
                .fill(Color(Farbwert(0x0A2735)))
                .overlay(
                    Circle().strokeBorder(
                        .white.opacity(laeuft ? 0.7 : 0.25), lineWidth: 1.2))
                .frame(width: 16, height: 16)
            Circle()
                .fill(laeuft ? Farbe.amberWeich : .white.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .opacity(laeuft ? 1 : 0.55)
        .overlay(alignment: .top) {
            if !wort.isEmpty {
                Text(wort).font(.custom("IBMPlexSans", size: 11))
                    .foregroundStyle(Farbe.text3)
                    .fixedSize()
                    .offset(y: -18)
            }
        }
        .position(an)
        .allowsHitTesting(false)
    }

    private func stutzen(_ wort: String, an: CGPoint) -> some View {
        hinweis(wort, an: an, nachLinks: true)
    }

    @ViewBuilder private func hinweis(_ wort: String, an: CGPoint, nachLinks: Bool) -> some View {
        if !wort.isEmpty {
            Text(wort)
                .font(.custom("IBMPlexSans", size: 11))
                .foregroundStyle(Farbe.text3)
                .fixedSize()
                .frame(
                    maxWidth: .infinity,
                    alignment: nachLinks ? .trailing : .leading
                )
                .frame(width: 300)
                .position(x: nachLinks ? an.x - 150 : an.x + 150, y: an.y)
                .allowsHitTesting(false)
        }
    }
}

/// Die beiden Überschriften der Bühne.
private struct Ueberschrift: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("IBMPlexSans-SmBld", size: 11))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Farbe.kicker)
            .fixedSize()
    }
}
