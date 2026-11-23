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

    /// Wie hoch die Bühne gezeichnet wird: **940 × 501**, wie am Telefon der Vorlage.
    ///
    /// `min-width: 940px` der Zeichnung wird in `handy.css` nicht überschrieben
    /// (`globals.css:567`), die Bühne ist dort also 940 Punkte breit und bei 1200 × 640 damit
    /// 501 hoch. Hier standen 430 - das sind 806 × 430, ein Siebtel kleiner als gemeint, und
    /// die kleinen Schriften (11,5 bei Gewicht 300) verlieren bei dieser Verkleinerung genau
    /// das, was sie lesbar macht.
    private let hoehe: CGFloat = Anlagenrohre.buehne.height / Anlagenrohre.buehne.width * 940

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

    /// Die Wasserkreise haben keine gemessene Leistung – ihre Stärke steht für „läuft“.
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

    /// **Bei „Bewegung reduzieren“ keine Lichtpunkte und keine Zeitachse.** Die App senkte hier
    /// nur den Takt auf ein Bild je Sekunde - die Punkte wanderten weiter, nur ruckelnd, und das
    /// ist genau das Bild, das die Einstellung vermeiden soll. Die Vorlage zeichnet sie gar nicht
    /// (`Schema.tsx:74`); damit fällt auch der `TimelineView` weg, denn ein Bild, das sich nicht
    /// bewegt, braucht keine Uhr.
    @ViewBuilder private var rohre: some View {
        if ruhig {
            Canvas { gestalt, _ in
                for r in rohrliste {
                    zeichne(r, in: &gestalt, sekunden: nil)
                }
            }
            .allowsHitTesting(false)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { takt in
                Canvas { gestalt, _ in
                    let sekunden = takt.date.timeIntervalSinceReferenceDate
                    for r in rohrliste {
                        zeichne(r, in: &gestalt, sekunden: sekunden)
                    }
                }
            }
            .allowsHitTesting(false)
        }
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
    private func zeichne(_ r: Rohrzug, in gestalt: inout GraphicsContext, sekunden: Double?) {
        let rohr = Anlagenrohre.rohr(r.kennung)
        let an = Anlagenschema.istAn(r.kw)
        let staerke = Anlagenschema.rohrStaerke(r.kw, leise: r.leise)

        if r.hof {
            // **Fester Hof, 20 Punkte breit** (`.anlage-halo`, `globals.css:579`). Mitlaufend
            // mit der Rohrstärke war er bei schwacher Leistung zu schmal, um den Ofensteiger zu
            // verdecken - und genau dafür ist er da.
            gestalt.stroke(
                rohr.pfad, with: .color(Color(Farbwert(0x07_1D28)).opacity(0.9)),
                style: StrokeStyle(lineWidth: 20, lineCap: .round))
        }
        // Die Deckungen der Vorlage (`Schema.tsx:72-73`). Die App hatte 0,3 und 0,9 - auf dem
        // hellen Kartengrund war das nötig, auf der Bühne ist es ein Leuchtkabel: die Rohre
        // führten das Bild, wo sie es nur tragen sollen.
        gestalt.stroke(
            rohr.pfad, with: .color(r.farbe.opacity(an ? (r.leise ? 0.12 : 0.16) : 0.06)),
            style: StrokeStyle(lineWidth: staerke, lineCap: .round))
        gestalt.stroke(
            rohr.pfad, with: .color(r.farbe.opacity(an ? (r.leise ? 0.35 : 0.5) : 0.12)),
            style: StrokeStyle(lineWidth: an ? (r.leise ? 1.2 : 1.6) : 1, lineCap: .round))

        guard let sekunden, an, let kw = r.kw else { return }
        let zahl = r.farben.isEmpty ? Anlagenschema.punktzahl(kw, leise: r.leise) : r.farben.count
        let dauer = Anlagenschema.rohrDauer(kw, leise: r.leise)
        for i in 0..<max(0, zahl) {
            var anteil = (sekunden / dauer + Double(i) / Double(zahl))
                .truncatingRemainder(dividingBy: 1)
            if r.umkehren { anteil = 1 - anteil }
            let farbe = r.farben.isEmpty ? r.farbe : r.farben[i % r.farben.count]
            licht(
                rohr.punkt(bei: anteil), halbmesser: punktmass(i, r),
                deckung: punktdeckung(i, r), farbe: farbe, in: &gestalt)
        }
    }

    /// Halbmesser und Deckung wechseln von Punkt zu Punkt (`Schema.tsx:78-80`).
    ///
    /// Jeder zweite Punkt ist kleiner und blasser - das lässt eine Reihe gleich schneller Punkte
    /// wie Wasser aussehen und nicht wie eine Perlenkette. Gemischter Strom hat gleich grosse
    /// Punkte, weil dort die Farbe den Unterschied macht; Rückläufe sind gedämpft.
    private func punktmass(_ i: Int, _ r: Rohrzug) -> CGFloat {
        let roh: CGFloat = r.farben.isEmpty ? (i % 2 != 0 ? 2.2 : 3.2) : 3
        return roh * (r.leise ? 0.8 : 1)
    }

    private func punktdeckung(_ i: Int, _ r: Rohrzug) -> Double {
        let roh: Double = r.farben.isEmpty ? (i % 2 != 0 ? 0.55 : 0.95) : 0.92
        return roh * (r.leise ? 0.7 : 1)
    }

    /// Ein Lichtpunkt mit Hof.
    ///
    /// **Gemalt und nicht gefiltert.** Im SVG trägt jeder Punkt `filter="url(#anlage-weich)"` -
    /// einen Gauss von 2,2 (`Schema.tsx:81`, `:196-198`). In einem `Canvas` kostet ein Filter je
    /// Punkt zu viel, und ein Filter für eine gemeinsame Punkteschicht würde die Tiefenfolge
    /// umwerfen: der dunkle Hof des Wärmepumpenvorlaufs läge dann unter fremden Punkten. Also
    /// zwei Kreise - ein weiter, blasser und der Kern darauf -, dasselbe Mittel wie bei der
    /// Pumpe.
    private func licht(
        _ p: CGPoint, halbmesser: CGFloat, deckung: Double, farbe: Color,
        in gestalt: inout GraphicsContext
    ) {
        func kreis(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
        gestalt.fill(kreis(halbmesser * 2.1), with: .color(farbe.opacity(deckung * 0.22)))
        gestalt.fill(kreis(halbmesser), with: .color(farbe.opacity(deckung)))
    }

    // MARK: - Die Geräte

    private var geraete: some View {
        ZStack(alignment: .topLeading) {
            // **Der Textanfang steht bei x 60 bzw. 420** (`Schema.tsx:207-212`), `.position`
            // setzt aber die Mitte - und eine Überschrift, deren Mitte feststeht, wandert mit
            // ihrer Länge. Darum derselbe Griff wie bei ``hinweis``.
            ueberschrift("Strom", ab: 60)
            ueberschrift("Wärme", ab: 420)

            quelle(
                .pv, mitte: CGPoint(x: 120, y: 150), rand: Anlagenschema.Farbwerte.pv,
                name: "PV", wert: strom.pvKw, hinweis: nil)
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
                rand: Anlagenschema.Farbwerte.wallbox, name: "Haushalt", namengroesse: 12.5,
                zahlgroesse: 13, wert: strom.restKw,
                // **„inkl. Wallbox“ und nicht „ohne Wärmepumpe“** (`Schema.tsx:297`). Beides
                // ist wahr, aber nur eines sagt, was in der Zahl *drin* ist - und die Wallbox
                // ist der Posten, der sie verdoppeln kann.
                hinweis: "inkl. Wallbox")

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

    private func ueberschrift(_ wort: String, ab x: CGFloat) -> some View {
        Text(wort)
            .modifier(Ueberschrift())
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: 300)
            .position(x: x + 150, y: 46)
            .allowsHitTesting(false)
    }

    /// Dasselbe wie `de()` der Vorlage (`schema.ts:55-56`): der Betrag mit einer Stelle - und
    /// **ohne Wert ein Strich**, nicht „0,0“.
    ///
    /// Die App rechnete hier `abs(wert ?? 0)` und machte damit aus jedem schweigenden Zähler
    /// eine gemessene Null: ein Haus, dessen Netzzähler ausgefallen ist, sah aus wie ein Haus
    /// ohne Netzbezug. Die Einheit entfällt mit dem Wert (``grosseZahl``), so wie das `<tspan>`
    /// der Vorlage (`Schema.tsx:143-147`).
    private func de(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return Formate.leer }
        return Formate.kw(abs(wert))
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
        name: String, namengroesse: CGFloat = 14, zahlgroesse: CGFloat = 14, wert: Double?,
        hinweis hinweistext: String?
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color(Farbwert(0x0A2735)))
                .overlay(Circle().strokeBorder(Color(rand).opacity(0.75), lineWidth: 1.2))
                .frame(width: halbmesser * 2, height: halbmesser * 2)
            VStack(spacing: 2) {
                // `.anlage-name` nennt keine Farbe und erbt damit `var(--text-1)`
                // (`globals.css:568`, `.anlage-flaeche text`); hier stand `text2`.
                Text(name)
                    .font(.system(size: namengroesse, weight: .medium))
                    .foregroundStyle(Farbe.text1)
                grosseZahl(de(wert), einheit: " kW", groesse: zahlgroesse)
            }
        }
        .frame(width: halbmesser * 2, height: halbmesser * 2)
        .overlay(alignment: .bottom) {
            if let hinweistext, !hinweistext.isEmpty {
                Text(hinweistext)
                    .font(.system(size: 11.5, weight: .light))
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
            // „zusammen 4,2 kW“, rechtsbündig vor dem Knoten (`Schema.tsx:284-286`): das Wort
            // gehört zu der Stelle, an der sich die drei Quellen sammeln, und nennt ihre Summe.
            // „im Haus“ sagte eine Zugehörigkeit, die der Knoten nicht meint - die Wärmepumpe
            // steht auch im Haus und hängt an demselben Punkt.
            hinweis(
                "zusammen \(de(strom.houseKw)) kW", an: CGPoint(x: 286, y: 292),
                nachLinks: true)
        }
        .allowsHitTesting(false)
    }

    private var ofenkachel: some View {
        kachel(
            .ofen, x: 420, y: 100, breite: 260, hoehe: 90, rundung: 24,
            gedimmt: ofen.running != true
        ) {
            VStack(alignment: .leading, spacing: 3) {
                name("Pelletofen")
                unterzeile(Anlagenschema.ofenStatus(ofen))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) {
                let gemeldet = ofen.running == true && ofen.waterKw != nil
                VStack(alignment: .trailing, spacing: 1) {
                    grosseZahl(
                        gemeldet ? "≈" + de(ofen.waterKw) : Formate.leer,
                        einheit: " kW", groesse: 32, einheitGroesse: 13)
                    // **„geschätzt aus der Stufe“, und nur wenn eine Stufe brennt**
                    // (`Schema.tsx:312-314`). „ins Wasser“ stand auch an einem Strich - und
                    // erklärte damit eine Schätzung, die niemand gemacht hat.
                    hinweistext(gemeldet ? "geschätzt aus der Stufe" : "")
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
                    name("Wärmepumpe")
                    unterzeile(wpStatus)
                }
                VStack(alignment: .leading, spacing: 1) {
                    grosseZahl(de(wp.powerKw), einheit: " kW", groesse: 30)
                    hinweistext("Strom hinein")
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                VStack(alignment: .trailing, spacing: 1) {
                    // **„0,0“ nur, wenn sie steht** (`Schema.tsx:331`): eine stehende Pumpe
                    // macht gemessene null Wärme, eine laufende ohne Zähler macht welche, die
                    // niemand kennt - und dann steht dort ein Strich.
                    grosseZahl(
                        wp.running ? de(wp.thermalKw) : Formate.zahl(0, stellen: 1),
                        einheit: " kW", groesse: 44, einheitGroesse: 13)
                    hinweistext(
                        wp.running && wp.thermalKw == nil ? "Wärme nicht gemessen" : "Wärme heraus")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                copring.frame(maxWidth: .infinity, alignment: .trailing).offset(y: 12)
            }
            .padding(EdgeInsets(top: 22, leading: 26, bottom: 14, trailing: 24))
        }
    }

    /// Was unter „Wärmepumpe“ steht (`Schema.tsx:325`).
    ///
    /// **Mit der Dauer, wenn es eine gibt.** Die App schrieb nur „läuft“ - und damit sieht eine
    /// Pumpe, die seit zwei Minuten taktet, aus wie eine, die seit drei Stunden durchläuft.
    private var wpStatus: String {
        guard wp.running else { return "steht" }
        let seit = Anlagenschema.dauerText(seit: wp.runningSince, jetzt: jetzt)
        return seit.isEmpty ? "läuft" : "läuft seit \(seit)"
    }

    /// Der Name auf einer Kachel: `.anlage-name`, 15 Punkte, Gewicht 500 (`globals.css:570`).
    private func name(_ wort: String) -> some View {
        Text(wort)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Farbe.text1)
    }

    /// Die Zeile unter dem Namen: `.anlage-sub`, 12,5 Punkte, Gewicht 300, ``Farbe/text2``
    /// (`globals.css:571`) - hier stand 12 Punkte in `text3`, also leiser als gemeint.
    private func unterzeile(_ wort: String) -> some View {
        Text(wort)
            .font(.system(size: 12.5, weight: .light))
            .foregroundStyle(Farbe.text2)
    }

    /// Ein Hinweis in der Kachel: `.anlage-hint`, 11,5 Punkte, Gewicht 300 (`globals.css:572`).
    private func hinweistext(_ wort: String) -> some View {
        Text(wort)
            .font(.system(size: 11.5, weight: .light))
            .foregroundStyle(Farbe.text3)
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
            // Die Zahl im Ring ist die einzige `.anlage-num` mit Gewicht 400 - sie steht in
            // einem Ring von 34 Punkten und hält bei 200 nicht stand (`Schema.tsx:336`).
            Text(cop.map { Formate.zahl($0, stellen: 1) } ?? Formate.leer)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Farbe.text1)
        }
        .frame(width: 34, height: 34)
        .overlay(alignment: .leading) {
            Text("COP").font(.system(size: 10, weight: .light))
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
                    jetzt: jetzt, laedt: wp.running || ofen.running == true, status: nil),
                breite: glasBreite,
                zahlgroesse: glasZahl,
                // **Ohne Fuellstand im Glas.** Der Prozentwert steht hier gleich darunter als
                // eigene Zeile (mit „netto“ und den Kilowattstunden daneben); im Glas stand er
                // ein zweites Mal, in einer Spalte von wenigen Punkten Breite.
                mitWerten: false
            )
            .frame(width: glasBreite + glasRand, height: 470, alignment: .topLeading)
            .position(x: 824 + (glasBreite + glasRand) / 2, y: 92 + 235)
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    grosseZahl(
                        puffer.soc.map { "\(Int(($0 * 100).rounded()))" } ?? Formate.leer,
                        einheit: " %", groesse: 24)
                    if !Anlagenschema.nettoText(puffer).isEmpty {
                        Text(Anlagenschema.nettoText(puffer))
                            .font(.system(size: 12))
                            .foregroundStyle(Color(Anlagenworte.nettoFarbe(puffer)))
                    }
                }
                hinweistext(Anlagenworte.glaszeile(puffer))
            }
            .fixedSize()
            .position(x: 860, y: 612)
        }
        .contentShape(Rectangle())
        .onTapGesture { wegweiser.gehe(Anlagenschema.Ziel.puffer.weg) }
        .accessibilityLabel(Anlagenschema.Ziel.puffer.ansage)
        .accessibilityAddTraits(.isButton)
    }

    /// **Der Tank ist 72 Punkte breit und steht von x 824 bis x 896** (`Schema.tsx:368`).
    ///
    /// Das ist die eine Zahl, an der die ganze Bühne hängt: an der Kante 896 enden der
    /// Warmwasser-, der Heizungs- und der Kaltwasserstutzen, an 824 der Wärmepumpenvorlauf
    /// (`Anlagenrohre.swift:101-109`). Hier stand ein Aufruf **ohne `breite`** - also die
    /// Voreinstellung 60 - in einem Rahmen von 150 Punkten; im zentrierten Rahmen rutschte der
    /// Tank um 18,5 Punkte nach rechts. Folge: der Wärmepumpenvorlauf endete im Leeren, die
    /// vier anderen Rohre endeten im Wasser statt an der Wand, und damit sagte die Bühne nicht
    /// mehr, was sie sagen soll - dass sich die vier getrennten Systeme *genau hier* berühren.
    ///
    /// Der Rahmen muss darum so breit sein wie das Kind: Tank plus Zahlenspalte, nach derselben
    /// Formel wie in ``Pufferglas`` (`Pufferspeicher.swift:57`: `round(20 + s * 2,6)`), und
    /// linksoben gesetzt.
    private let glasBreite: CGFloat = 72
    private let glasZahl: CGFloat = 13
    private var glasRand: CGFloat { (20 + glasZahl * 2.6).rounded() }

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

    private func abnehmer(_ wort: String, wert: String, einheit: String, satz: String)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                name(wort)
                Spacer(minLength: 8)
                grosseZahl(wert, einheit: einheit, groesse: 22)
            }
            unterzeile(satz)
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
            .background(kachelflaeche(rundung))
            .opacity(gedimmt ? 0.7 : 1)
            .position(x: x + breite / 2, y: y + hoehe / 2)
            .contentShape(RoundedRectangle(cornerRadius: rundung, style: .continuous))
            .onTapGesture { wegweiser.gehe(ziel.weg) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(ziel.ansage)
            .accessibilityAddTraits(.isButton)
    }

    /// Die Fläche einer Kachel: **Glas und keine Karte** (`.anlage-glas`, `globals.css:576`).
    ///
    /// Hier stand `flaeche2` bei 0,92 - eine gedeckte Farbe (#123544), die auf der Bühne wie
    /// eine aufgelegte Karte wirkt. Die Vorlage füllt mit `rgba(255,255,255,.045)`: die Kachel
    /// ist eine *Aufhellung* des Grundes, der Bühnenverlauf scheint durch, und die Kacheln
    /// liegen damit in der Zeichnung statt auf ihr.
    ///
    /// Zwei Ränder, wie im SVG: der gleichmäßige Strich (weiß 0,10) und darin die Haarlinie,
    /// deren Verlauf **bei 25 %** schon auf 0,06 gefallen ist (`Schema.tsx:177-181`). Die App
    /// zog ihn über die ganze Höhe und machte daraus einen Rahmen; gemeint ist eine Lichtkante
    /// an der Oberkante.
    private func kachelflaeche(_ rundung: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: rundung, style: .continuous)
            .fill(.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: rundung, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: rundung - 0.5, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.28), location: 0),
                                .init(color: .white.opacity(0.06), location: 0.25),
                                .init(color: .white.opacity(0.02), location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
                    .padding(0.5)
            )
            .shadow(color: .black.opacity(0.38), radius: 14, y: 14)
    }

    /// Eine grosse Zahl mit Einheit: `.anlage-num` und `.anlage-unit` (`globals.css:573-574`).
    ///
    /// **Gewicht 200 und die Systemschrift.** Die Vorlage schaltet die ganze Zeichnung
    /// ausdrücklich auf `-apple-system`/SF Pro, und zwar mit Begründung
    /// (`globals.css:566-568`): die leichten Schnitte 200 und 300 halten die Kacheln ruhig, und
    /// IBM Plex kommt im Haus nur in 400 und 600. Eine Zahl in Plex Mono ist hier also nicht
    /// hausschriftlich, sondern zu schwer - dazu fehlte ihr die Engführung von −0,03 em.
    /// `monospacedDigit` ersetzt `font-variant-numeric: tabular-nums` (`globals.css:567`).
    ///
    /// Die Einheitsgrösse steht in der Vorlage an der Stelle und wird nicht gerechnet: 12 im
    /// Regelfall, 13 an den grossen Zahlen (`Schema.tsx:139`, `:311`, `:331`). Die App rechnete
    /// `max(11, groesse * 0,42)` - an der 44er Zahl der Wärmepumpe wären das 18 Punkte.
    private func grosseZahl(
        _ wert: String, einheit: String, groesse: CGFloat, einheitGroesse: CGFloat = 12
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(wert)
                .font(.system(size: groesse, weight: .thin))
                .monospacedDigit()
                .kerning(-groesse * 0.03)
                .foregroundStyle(Farbe.text1)
            if wert != Formate.leer, !einheit.isEmpty {
                Text(einheit)
                    .font(.system(size: einheitGroesse))
                    .foregroundStyle(Farbe.text2)
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
                Text(wort).font(.system(size: 11.5, weight: .light))
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
                .font(.system(size: 11.5, weight: .light))
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

/// Die beiden Überschriften der Bühne: `.anlage-cap` (`globals.css:569`).
///
/// **Nicht ``Farbe/kicker``.** Der Kicker der App ist `mist` (#7FA3B3) - ein Blaugrau, das auf
/// der Bühne genau die Farbe des Netzes trägt und damit wie eine Beschriftung des Netzstrangs
/// aussieht. Die Vorlage setzt hier ausdrücklich `fill: var(--text-3)`, also weiß bei 0,48:
/// eine Überschrift über der Zeichnung und kein Teil von ihr. Sperrung 0,12 em bei 11 Punkten
/// sind 1,32.
private struct Ueberschrift: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .medium))
            .tracking(1.32)
            .textCase(.uppercase)
            .foregroundStyle(Farbe.text3)
            .fixedSize()
    }
}
