import DuckCurveKit
import SwiftUI

/// Das Bild, das nach fünf Minuten ohne Berührung über der Wandanzeige liegt.
///
/// **Was es ist und was nicht.** Kein Bildschirmschoner: die Seite darunter bleibt am Leben und
/// mit ihr die Verbindung. Es ist der Zustand, in dem diese Anzeige die meiste Zeit ist - und
/// darum zeigt es nicht weniger, sondern anderes: was man aus drei Metern liest.
///
/// **Zwei Bilder, und die Sonne entscheidet** (`home/Ambiente.tsx`, `home/ambiente.ts`). Am Tag
/// ist die Sonne die Nachricht: der Sonnenbogen neben dem Satz und drei grosse Knoten darunter.
/// Am Abend ist sie es nicht mehr: dann stehen der Puffer als Glas, der Strompreis und der
/// Fahrplan der Nacht da. Umgeschaltet wird nach dem Sonnenlauf aus dem Fahrplan, nicht nach der
/// Uhr - eine Wolke um 13 Uhr ist kein Abend. Die Rechnung steht im Kern (`Ruhebild`).
///
/// **Warum es bis zum 19.11.2026 viel weniger zeigte.** Es hatte Uhr, Satz, drei selbstgebaute
/// Zahlen und eine Fusszeile - keinen Kopf rechts, keine Umschaltung, keinen Bogen, kein
/// Flussbild, kein Abendbild, keine Tageszahlen und keinen Hinweis, dass eine Berührung die
/// Bedienung zurückholt. Acht Bausteine der Vorlage fehlten.
///
/// **Alle Masse wachsen mit der Fläche.** Die Vorlage schreibt fast jede Grösse als
/// `clamp(klein, x vw, gross)`; `Bildmasse` rechnet das nach. Oberhalb von etwa 1270 Punkten Breite
/// ist fast alles am oberen Anschlag, darunter wächst es linear mit.
struct Ambiente: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.accessibilityReduceMotion) private var ruhigeBewegung
    let aufwachen: () -> Void

    /// Die Tagesbilanz für die drei linken Fusszahlen.
    ///
    /// **Warum das Bild sie selbst holt.** Autarkie und bezahltes Geld stehen nur in der
    /// Tagesbilanz, und die hält heute allein die Jetzt-Seite als eigenen Zustand
    /// (`JetztSeite.swift`). Das Ruhebild liegt über dem ganzen Rahmen - auch über `/haus` oder
    /// `/strom` -, sieht diesen Zustand also nicht. Es lädt sie, solange es steht, und hört
    /// wieder auf, wenn es verschwindet.
    @State private var bilanz: EnergySummaryOut?

    /// Was aus Fahrplan und Uhr folgt - einmal je Minute gerechnet, nicht je Sekunde.
    ///
    /// **Warum gespeichert und nicht gerechnet.** `WandRahmen` taktet im Sekundenschlag; die
    /// Vorlage rastet dagegen auf die Minute (`Home.tsx:117`: `Math.floor(now / 60_000)`). Ohne
    /// Raster liefe der Sonnenlauf sechzigmal so oft, und die Marke im Bogen zappelte.
    @State private var stand = Stand()

    struct Stand {
        var lauf: Ruhebild.Sonnenlauf?
        var bild: Ruhebild.Bild = .abend
        var aussicht = Ruhebild.Aussicht(erwartetKwh: nil, restKwh: nil, bis: nil)
        var bogen: Ruhebild.Bogen?
        var planzeilen: [Planzeile] = []
        var morgenPvKwh: Double?
    }

    /// Die Minute, auf der das Bild steht.
    private var jetztMinute: Date {
        Date(timeIntervalSince1970: (haus.jetzt.timeIntervalSince1970 / 60).rounded(.down) * 60)
    }

    var body: some View {
        GeometryReader { raum in
            let mass = Bildmasse(raum.size)
            ZStack {
                grund(mass)
                schein(mass)
                inhalt(mass)
            }
            .frame(width: raum.size.width, height: raum.size.height)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: aufwachen)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Ruhebild. Antippen für die Bedienung.")
        .onAppear { rechne() }
        .onChange(of: Int(jetztMinute.timeIntervalSince1970)) { _, _ in rechne() }
        .onChange(of: haus.plan?.createdAt) { _, _ in rechne() }
        .task { await holeBilanz() }
    }

    // MARK: - Der Grund

    /// Derselbe Verlauf wie in der Vorlage, aber mit ihrem Winkel.
    ///
    /// `linear-gradient(130deg, …)` legt die Verlaufslinie quer durch die Fläche; ihre Endpunkte
    /// hängen vom Seitenverhältnis ab. `Farbe.grundVerlauf` nimmt dafür zwei feste Punkte - für
    /// ein Bild, das die ganze Anzeige füllt, wandert damit die 62-%-Marke.
    private func grund(_ mass: Bildmasse) -> some View {
        let richtung = CGSize(width: 0.766_044, height: 0.642_788)  // sin 130°, -cos 130°
        let laenge = mass.breite * richtung.width + mass.hoehe * richtung.height
        let halb = laenge / 2
        let mitte = CGPoint(x: mass.breite / 2, y: mass.hoehe / 2)
        let von = UnitPoint(
            x: (mitte.x - halb * richtung.width) / mass.breite,
            y: (mitte.y - halb * richtung.height) / mass.hoehe)
        let bis = UnitPoint(
            x: (mitte.x + halb * richtung.width) / mass.breite,
            y: (mitte.y + halb * richtung.height) / mass.hoehe)
        return LinearGradient(
            stops: Marken.grundVerlauf.map {
                Gradient.Stop(color: Color($0.farbe), location: $0.stelle)
            },
            startPoint: von, endPoint: bis)
    }

    /// Ein weicher Kreis hinter allem: warm und mittig am Tag, kühl und nach rechts am Abend.
    ///
    /// **Der Radius ist grösser, als er aussieht.** `radial-gradient(circle, …)` ohne Mass heisst
    /// `farthest-corner`: hundert Prozent liegen in der Ecke des quadratischen Kastens, also bei
    /// `d/2 · √2`. Wer `d/2` nimmt, zeichnet den Schein um ein Drittel zu klein.
    private func schein(_ mass: Bildmasse) -> some View {
        let tag = stand.bild == .tag
        let d = tag
            ? min(760, mass.breite * 0.70)
            : min(700, mass.breite * 0.66)
        let aussen = d / 2 * 1.414_214
        let farbe = tag ? Farbe.pv : Color(Farbwert(0x7FA3B3))
        return Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: farbe.opacity(tag ? 0.20 : 0.14), location: 0),
                        .init(color: farbe.opacity(0), location: tag ? 0.62 : 0.64),
                    ],
                    center: .center, startRadius: 0, endRadius: aussen
                )
            )
            .frame(width: d, height: d)
            .position(
                x: mass.breite * (tag ? 0.50 : 0.62),
                y: mass.hoehe * (tag ? 0.46 : 0.52))
            .allowsHitTesting(false)
    }

    // MARK: - Die vier Zeilen

    private func inhalt(_ mass: Bildmasse) -> some View {
        VStack(alignment: .leading, spacing: mass.luft) {
            kopf(mass)
            satzzeile(mass)
            // Nur die Mitte dehnt sich; Kopf, Satz und Fuss nehmen ihre eigene Höhe
            // (`globals.css:378`: `grid-template-rows: auto auto minmax(0,1fr) auto`).
            mitte(mass)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            fuss(mass)
        }
        .padding(.horizontal, mass.randSeite)
        .padding(.top, mass.randOben)
        .padding(.bottom, mass.randUnten)
    }

    // MARK: - Kopf

    private func kopf(_ mass: Bildmasse) -> some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Formate.hhmm(jetztMinute))
                    .font(Schrift.mono(mass.uhr))
                    .kerning(mass.uhr * -0.04)
                    .foregroundStyle(Farbe.text1)
                    .monospacedDigit()
                Text(Formate.langesDatum(jetztMinute))
                    .font(Schrift.sans(mass.datum))
                    .foregroundStyle(Farbe.text2)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 10) {
                aussen(mass)
                lebenszeichen(mass)
            }
            .padding(.top, 8)
        }
    }

    /// Die Aussentemperatur mit dem kleinen Wort dahinter - in Sans, damit es nicht wie ein
    /// Messwert aussieht.
    private func aussen(_ mass: Bildmasse) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: mass.aussen * 0.3) {
            Text(Formate.celsius(aussenwert, stellen: 1))
                .font(Schrift.mono(mass.aussen))
                .kerning(mass.aussen * -0.02)
                .foregroundStyle(Farbe.text1)
                .monospacedDigit()
            Text(haus.zustand?.system.outdoorSourceDe ?? "draußen")
                .font(Schrift.sans(mass.aussenWort))
                .foregroundStyle(Farbe.text2)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var aussenwert: Double? {
        haus.zustand?.system.outdoorShownC ?? haus.augenblick?.outdoorTempC.value
    }

    /// Der atmende Punkt und das Wort daneben - das Einzige, was ein Ruhebild von einem
    /// eingefrorenen unterscheidet.
    private func lebenszeichen(_ mass: Bildmasse) -> some View {
        HStack(spacing: 9) {
            Atempunkt(gestoert: haus.gestoert)
            Text(haus.verbindungswort.uppercased())
                .font(Schrift.mono(12))
                .kerning(12 * 0.13)
                .foregroundStyle(haus.gestoert ? Farbe.alarm : Farbe.text2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(haus.zustand?.system.connectionLabelDe ?? haus.verbindungswort)
    }

    // MARK: - Satz

    private func satzzeile(_ mass: Bildmasse) -> some View {
        HStack(alignment: .top, spacing: mass.satzLuft) {
            Text(satz)
                .font(Schrift.sans(mass.satz))
                .kerning(mass.satz * -0.015)
                .lineSpacing(mass.satz * 0.2)
                .foregroundStyle(satzfarbe)
                .fixedSize(horizontal: false, vertical: true)
                // `max-width: 22ch` - und ein „ch" ist der Vorschub der Null, in IBM Plex
                // 0,6 em. Zweiundzwanzig davon sind 13,2 Zeilenhöhen.
                .frame(maxWidth: mass.satz * 13.2, alignment: .leading)
            Spacer(minLength: 0)
            if stand.bild == .tag {
                vorschau(mass)
            }
        }
    }

    /// Der Satz, und wer ihn sagt.
    ///
    /// **Ein Befund schlägt die Entscheidung** (`Ambiente.tsx:58`). Schweigt eine Quelle, steht
    /// der Ausfall da und nicht ein Satz über eine Wärmepumpe, der auf zwei Tage alten Zahlen
    /// beruht. Darum nicht `haus.satz`: der kennt die Wache nicht.
    private var satz: String {
        if let befund { return befund.textDe }
        if let e = haus.zustand?.decision?.explanationDe, !e.isEmpty { return e }
        return "Verbinde mit dem Haus …"
    }

    private var befund: WatchFindingOut? {
        Ruhebild.schwersterBefund(haus.zustand?.system.watch)
    }

    private var satzfarbe: Color {
        switch befund?.severity {
        case .alarm: return Farbe.alarm
        case .warn: return Farbe.amberWeich
        default: return Farbe.text1
        }
    }

    // MARK: - Die Aussicht neben dem Satz (nur am Tag)

    @ViewBuilder private func vorschau(_ mass: Bildmasse) -> some View {
        if stand.aussicht.erwartetKwh != nil || stand.bogen != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Ruhekicker(wort: "Heute erwartet")
                    Spacer(minLength: 0)
                    Grosszahl(
                        wert: eins(stand.aussicht.erwartetKwh), einheit: "kWh",
                        groesse: mass.vorschauZahl, farbe: Farbe.pv)
                }
                if let b = stand.bogen {
                    Sonnenbogen(bogen: b)
                        .frame(height: mass.vorschauBreite * (b.hoehe + 2) / b.breite)
                }
                Text(restzeile)
                    .font(Schrift.sans(mass.vorschauFuss))
                    .foregroundStyle(Farbe.text2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: mass.vorschauBreite)
            .padding(.top, 4)
        }
    }

    /// „noch 4,2 kWh bis 17:00" - was geerntet ist, steht schon unten als Tageszahl.
    private var restzeile: String {
        guard let rest = stand.aussicht.restKwh, let bis = stand.aussicht.bis else { return " " }
        return "noch \(eins(rest)) kWh bis \(Formate.hhmm(bis))"
    }

    // MARK: - Die Mitte

    @ViewBuilder private func mitte(_ mass: Bildmasse) -> some View {
        if stand.bild == .tag {
            Flussreihe(mass: mass, augenblick: haus.augenblick, ruhig: ruhigeBewegung)
        } else {
            abend(mass)
        }
    }

    // MARK: - Das Abendbild

    private func abend(_ mass: Bildmasse) -> some View {
        HStack(alignment: .center, spacing: mass.abendLuft) {
            puffer(mass)
            VStack(alignment: .leading, spacing: mass.abendRechtsLuft) {
                preis(mass)
                planzeilen(mass)
            }
            .frame(width: mass.abendRechts)
            .padding(.leading, mass.abendRand)
            .overlay(alignment: .leading) {
                Rectangle().fill(Farbe.linie1).frame(width: 1)
            }
        }
        .padding(.vertical, mass.abendHoch)
    }

    private func puffer(_ mass: Bildmasse) -> some View {
        let zustand = Pufferzustand.aus(
            fuehler: haus.augenblick?.bufferTempsC.vonObenNachUnten ?? [],
            jetzt: jetztMinute,
            laedt: haus.zustand?.heatPump.running ?? false,
            status: haus.zustand?.buffer.status
        )
        return HStack(alignment: .center, spacing: mass.pufferLuft) {
            Spacer(minLength: 0)
            Pufferglas(
                temperaturen: haus.augenblick?.bufferTempsC.vonObenNachUnten ?? [],
                soc: haus.zustand?.buffer.soc,
                zustand: zustand,
                breite: 72,
                zahlschrift: Schrift.mono(17),
                gedimmt: !zustand.traegt,
                mitWerten: false
            )
            .frame(width: 72 + 64)
            VStack(alignment: .leading, spacing: 4) {
                Ruhekicker(wort: "Puffer")
                Grosszahl(
                    wert: prozent(haus.zustand?.buffer.soc), einheit: "%",
                    groesse: mass.knotenZahl, farbe: Farbe.text1)
                Text(zustand.wort)
                    .font(Schrift.sans(mass.knotenWort))
                    .foregroundStyle(Farbe.text2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func preis(_ mass: Bildmasse) -> some View {
        let ct = haus.augenblick?.electricityPriceCtKwh.value
        return VStack(alignment: .leading, spacing: 8) {
            Ruhekicker(wort: "Strom gerade")
            Grosszahl(
                wert: eins(ct), einheit: "ct", groesse: mass.preisZahl,
                farbe: (ct ?? 0) < 0 ? Farbe.pv : Farbe.text1)
        }
    }

    /// Was das Haus in der Nacht vorhat - und nur das, worüber der Plan etwas weiss.
    private func planzeilen(_ mass: Bildmasse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(stand.planzeilen) { z in
                planzeile(z.wort, z.wann, mass)
            }
            if let morgen = stand.morgenPvKwh {
                planzeile("Morgen Sonne", "\(eins(morgen)) kWh", mass)
            }
        }
        .padding(.top, mass.planRand)
        .overlay(alignment: .top) {
            Rectangle().fill(Farbe.linie1).frame(height: 1)
        }
    }

    private func planzeile(_ wort: String, _ wann: String, _ mass: Bildmasse) -> some View {
        HStack(spacing: 16) {
            Text(wort)
                .font(Schrift.sans(mass.plan))
                .foregroundStyle(Farbe.text2)
            Spacer(minLength: 0)
            Text(wann)
                .font(Schrift.mono(mass.plan))
                .foregroundStyle(Farbe.text1)
        }
    }

    // MARK: - Fuss

    private func fuss(_ mass: Bildmasse) -> some View {
        HStack(alignment: .bottom, spacing: 32) {
            HStack(alignment: .bottom, spacing: mass.zahlenLuft) {
                // **Am Abend nur drei** (`Ambiente.tsx:70`): die vierte ist der Strompreis, und
                // der steht dort schon gross rechts. Dieselbe Zahl zweimal auf einem Bild wäre
                // keine zweite Auskunft.
                ForEach(stand.bild == .abend ? Array(kennzahlen.prefix(3)) : kennzahlen) { k in
                    VStack(alignment: .leading, spacing: 4) {
                        Grosszahl(
                            wert: k.wert, einheit: k.einheit ?? "", groesse: mass.fussZahl,
                            farbe: Farbe.ton(k.ton))
                        Text(k.wort)
                            .font(Schrift.sans(mass.fussWort))
                            .foregroundStyle(Farbe.text2)
                    }
                }
            }
            Spacer(minLength: 0)
            Text("BERÜHREN FÜR DIE BEDIENUNG")
                .font(Schrift.mono(mass.hinweis))
                .kerning(mass.hinweis * 0.08)
                .foregroundStyle(Farbe.text3)
                .padding(.bottom, 6)
                .lineLimit(1)
        }
        .padding(.top, mass.fussRand)
        .overlay(alignment: .top) {
            Rectangle().fill(Farbe.linie1).frame(height: 1)
        }
    }

    private var kennzahlen: [Kennzahl] {
        Tageskacheln.kennzahlen(
            tag: .heute, bilanz: bilanz?.totals,
            preisJetzt: haus.augenblick?.electricityPriceCtKwh.value,
            morgen: Tageskacheln.Morgen())
    }

    // MARK: - Rechnen und Laden

    private func rechne() {
        let jetzt = jetztMinute
        let lauf = Ruhebild.sonnenlauf(haus.plan, jetzt: jetzt)
        var neu = Stand()
        neu.lauf = lauf
        neu.bild = Ruhebild.bild(lauf, jetzt: jetzt, pvKw: haus.augenblick?.pvPowerKw.value)
        neu.aussicht = Ruhebild.aussicht(haus.plan, jetzt: jetzt, lauf: lauf)
        neu.bogen = Ruhebild.bogen(lauf, jetzt: jetzt)
        neu.planzeilen = Fahrplan.zeilen(haus.plan, jetzt: jetzt)
        if let f = Tageskacheln.fenster(.morgen, jetzt: jetzt), let iv = haus.plan?.intervals {
            neu.morgenPvKwh = Tageskacheln.pvSumme(iv, von: f.von, bis: f.bis)
        }
        stand = neu
    }

    /// Die Tagesbilanz, solange das Bild steht - alle fünf Minuten, wie in der Vorlage.
    private func holeBilanz() async {
        while !Task.isCancelled {
            bilanz = try? await haus.api.energieUebersicht("day", anker: haus.heute)
            try? await Task.sleep(for: .seconds(300))
        }
    }

    // MARK: - Zahlen

    /// Eine Nachkommastelle, Komma, Strich wenn nichts da ist (`eins()` in `Ambiente.tsx:96`).
    private func eins(_ n: Double?) -> String {
        Formate.zahl(n, stellen: 1)
    }

    private func prozent(_ anteil: Double?) -> String {
        guard let anteil else { return Formate.leer }
        return Formate.zahl(anteil * 100, stellen: 0)
    }
}

// MARK: - Die Masse des Bildes

/// Jede Grösse der Vorlage als `clamp(klein, Anteil der Breite, gross)`.
///
/// Oberhalb von etwa 1270 Punkten Breite steht fast alles am oberen Anschlag - dort sind es feste
/// Zahlen. Darunter wächst alles mit, und auf einem iPad im Hochformat ist das Bild deshalb
/// kleiner geschrieben und nicht abgeschnitten.
struct Bildmasse {
    let breite: CGFloat
    let hoehe: CGFloat

    init(_ groesse: CGSize) {
        breite = max(320, groesse.width)
        hoehe = max(320, groesse.height)
    }

    private func quer(_ klein: CGFloat, _ anteil: CGFloat, _ gross: CGFloat) -> CGFloat {
        min(max(klein, anteil * breite), gross)
    }

    private func hoch(_ klein: CGFloat, _ anteil: CGFloat, _ gross: CGFloat) -> CGFloat {
        min(max(klein, anteil * hoehe), gross)
    }

    // Rahmen
    var luft: CGFloat { hoch(14, 0.024, 30) }
    var randOben: CGFloat { hoch(22, 0.044, 56) }
    var randUnten: CGFloat { hoch(18, 0.034, 48) }
    var randSeite: CGFloat { quer(26, 0.044, 64) }

    // Kopf
    var uhr: CGFloat { quer(58, 0.09, 112) }
    var datum: CGFloat { quer(14, 0.016, 19) }
    var aussen: CGFloat { quer(22, 0.028, 34) }
    var aussenWort: CGFloat { quer(12, 0.014, 17) }

    // Satz und Aussicht
    var satz: CGFloat { quer(22, 0.032, 40) }
    var satzLuft: CGFloat { quer(24, 0.04, 48) }
    var vorschauBreite: CGFloat { quer(240, 0.30, 360) }
    var vorschauZahl: CGFloat { quer(20, 0.022, 26) }
    var vorschauFuss: CGFloat { quer(12, 0.012, 15) }

    // Flussbild
    var ringGross: CGFloat { quer(100, 0.126, 148) }
    var ringKlein: CGFloat { quer(74, 0.09, 108) }
    var knotenLuft: CGFloat { quer(20, 0.04, 48) }
    var knotenZahl: CGFloat { quer(38, 0.054, 68) }
    var knotenZahlGross: CGFloat { quer(46, 0.066, 84) }
    var knotenWort: CGFloat { quer(14, 0.016, 19) }

    // Abendbild
    var abendLuft: CGFloat { quer(28, 0.044, 56) }
    var abendHoch: CGFloat { hoch(6, 0.016, 18) }
    var abendRechts: CGFloat { quer(300, 0.34, 404) }
    var abendRechtsLuft: CGFloat { hoch(14, 0.024, 22) }
    var abendRand: CGFloat { quer(24, 0.034, 46) }
    var pufferLuft: CGFloat { quer(16, 0.02, 26) }
    var preisZahl: CGFloat { quer(40, 0.054, 68) }
    var plan: CGFloat { quer(14, 0.016, 19) }
    var planRand: CGFloat { hoch(12, 0.02, 18) }

    // Fuss
    var fussRand: CGFloat { hoch(14, 0.024, 26) }
    var fussZahl: CGFloat { quer(26, 0.032, 40) }
    var fussWort: CGFloat { quer(12, 0.013, 16) }
    var zahlenLuft: CGFloat { quer(24, 0.04, 56) }
    var hinweis: CGFloat { quer(11, 0.011, 14) }
}

// MARK: - Bausteine, die nur das Ruhebild braucht

/// Eine Zahl mit ihrer Einheit, beide in der Grösse der Vorlage.
///
/// **Zwei Unterschiede zum Baustein `Zahl`.** Die Einheit ist hier 0,42 der Zahlengrösse
/// (`globals.css:232`: `font-size: .42em`) und nicht eine feste Schrift; und sie steht auch
/// dann da, wenn der Wert fehlt - „- kWh" sagt, was fehlt, „-" allein sagt es nicht.
struct Grosszahl: View {
    let wert: String
    let einheit: String
    let groesse: CGFloat
    var farbe: Color = Farbe.text1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: groesse * 0.22) {
            Text(wert)
                .font(Schrift.mono(groesse))
                .kerning(groesse * -0.03)
                .foregroundStyle(farbe)
                .monospacedDigit()
            if !einheit.isEmpty {
                Text(einheit)
                    .font(Schrift.sans(groesse * 0.42))
                    .foregroundStyle(Farbe.text3)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

/// Der Kicker des Ruhebildes: Mono 12, weit gesperrt, in Nebelgrau.
///
/// Nicht der Baustein `Kicker`: der ist Sans-Halbfett in 10,5 Punkten. Die Vorlage gibt den drei
/// Kickern des Ruhebildes über `.ambiente-vorschau-wort` eine eigene Grösse und Schrift.
struct Ruhekicker: View {
    let wort: String

    var body: some View {
        Text(wort.uppercased())
            .font(Schrift.mono(12))
            .kerning(12 * 0.13)
            .foregroundStyle(Farbe.kicker)
    }
}

/// Der Punkt, der atmet, solange die Zahlen gelten.
struct Atempunkt: View {
    let gestoert: Bool
    @Environment(\.accessibilityReduceMotion) private var ruhigeBewegung
    @State private var atmet = false

    var body: some View {
        Circle()
            .fill(gestoert ? Farbe.alarm : Farbe.gut)
            .frame(width: 8, height: 8)
            // `dch-atmen`: 3,6 Sekunden für den ganzen Weg, also 1,8 hin und 1,8 zurück.
            .opacity(gestoert || ruhigeBewegung ? 1 : (atmet ? 0.5 : 1))
            .animation(
                gestoert || ruhigeBewegung
                    ? nil
                    : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: atmet
            )
            .onAppear { atmet = true }
    }
}

/// Der Sonnenbogen: wo im Tag man steht.
///
/// Gestrichelt und blass ist die Prognose des ganzen Tages, durchgezogen das, was gelaufen ist,
/// und die Fläche darunter die Ernte bis zu dieser Minute. Die senkrechte Marke sagt „jetzt".
///
/// **Fläche und Linie sind zwei Pfade.** Als einer gezeichnet bekäme die Fläche beim Nachziehen
/// der Linie auch ihre Grundlinie und die Kante bei „jetzt" - statt eines Verlaufs stünde ein
/// umrandeter Block da.
struct Sonnenbogen: View {
    let bogen: Ruhebild.Bogen

    var body: some View {
        GeometryReader { raum in
            let f = raum.size.width / bogen.breite
            ZStack(alignment: .topLeading) {
                if !bogen.bisJetzt.isEmpty {
                    flaeche(f).fill(Farbe.pv.opacity(0.26))
                }
                linie(bogen.linie, f)
                    .stroke(
                        Farbe.pv.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6]))
                if !bogen.bisJetzt.isEmpty {
                    linie(bogen.bisJetzt, f)
                        .stroke(Farbe.pv, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                if let x = bogen.jetztX {
                    Path { p in
                        p.move(to: CGPoint(x: x * f, y: 0))
                        p.addLine(to: CGPoint(x: x * f, y: bogen.hoehe * f))
                    }
                    .stroke(
                        Farbe.amberWeich,
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                }
                Path { p in
                    p.move(to: CGPoint(x: 0, y: bogen.hoehe * f))
                    p.addLine(to: CGPoint(x: bogen.breite * f, y: bogen.hoehe * f))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Erwarteter Sonnenverlauf des Tages, der bisherige Teil gefüllt")
    }

    private func linie(_ stellen: [Ruhebild.Bogen.Stelle], _ f: CGFloat) -> Path {
        Path { p in
            for (i, s) in stellen.enumerated() {
                let punkt = CGPoint(x: s.x * f, y: s.y * f)
                if i == 0 { p.move(to: punkt) } else { p.addLine(to: punkt) }
            }
        }
    }

    private func flaeche(_ f: CGFloat) -> Path {
        var p = linie(bogen.bisJetzt, f)
        if let letzte = bogen.bisJetzt.last {
            p.addLine(to: CGPoint(x: letzte.x * f, y: bogen.hoehe * f))
            p.addLine(to: CGPoint(x: 0, y: bogen.hoehe * f))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Das Flussbild des Tages

/// Sonne, Haus, Speicher: drei Knoten, zwei Leitungen, nichts dazwischen.
///
/// **Warum nicht das grosse Flussbild.** `Energiefluss` zeichnet sechs Knoten an festen Plätzen,
/// jeder ein Knopf mit einem Weg dahinter. Hier soll jede Berührung aufwachen und nicht
/// navigieren, und drei Knoten in einer Reihe sind keine Teilmenge von sechs im Kreis.
struct Flussreihe: View {
    let mass: Bildmasse
    let augenblick: EnergySnapshot?
    let ruhig: Bool

    /// Ab dieser Leistung fliesst Strom (`Ambiente.tsx:26`).
    private static let schwelleKw = 0.05

    var body: some View {
        HStack(alignment: .top, spacing: mass.knotenLuft) {
            knoten(
                .sonne, farbe: Farbe.pv, wert: Formate.kw(pv), einheit: "kW", wort: "Sonne",
                zahlfarbe: Farbe.pv)
            leitung(farbe: Farbe.pv, an: (pv ?? 0) > Self.schwelleKw, rueck: false)
            knoten(
                .haus, farbe: Farbe.text1, wert: Formate.kw(haus), einheit: "kW", wort: "Haus",
                gross: true)
            leitung(farbe: Color(Farbwert(0x7FB7C8)), an: laedt || gibt, rueck: gibt)
            knoten(
                .batterie, farbe: Farbe.batterie, wert: prozent(soc), einheit: "%",
                wort: speicherwort, fuellung: soc)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: Werte

    private var pv: Double? { augenblick?.pvPowerKw.value }
    private var haus: Double? { augenblick?.housePowerKw.value }
    private var batterie: Double { augenblick?.batteryPowerKw.value ?? 0 }
    private var soc: Double? { augenblick?.batterySoc.value }
    private var laedt: Bool { batterie < -Self.schwelleKw }
    private var gibt: Bool { batterie > Self.schwelleKw }

    private var speicherwort: String {
        if laedt { return "Speicher lädt" }
        if gibt { return "Speicher gibt ab" }
        return "Speicher hält"
    }

    private func prozent(_ anteil: Double?) -> String {
        guard let anteil else { return Formate.leer }
        return Formate.zahl(anteil * 100, stellen: 0)
    }

    // MARK: Bausteine

    private func knoten(
        _ art: Zeichenart, farbe: Color, wert: String, einheit: String, wort: String,
        gross: Bool = false, zahlfarbe: Color = Farbe.text1, fuellung: Double? = nil
    ) -> some View {
        let r = gross ? mass.ringGross : mass.ringKlein
        return VStack(spacing: 10) {
            // Alle drei Knoten haben dieselbe Kopfzeile, so hoch wie der grösste Kreis - sonst
            // stünden die drei Zahlen auf drei Höhen (`globals.css:412`).
            ring(art, farbe: farbe, r: r, fuellung: fuellung)
                .frame(height: mass.ringGross)
            Grosszahl(
                wert: wert, einheit: einheit,
                groesse: gross ? mass.knotenZahlGross : mass.knotenZahl, farbe: zahlfarbe)
            Text(wort)
                .font(Schrift.sans(mass.knotenWort))
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wort): \(wert) \(einheit)")
    }

    private func ring(_ art: Zeichenart, farbe: Color, r: CGFloat, fuellung: Double?)
        -> some View
    {
        ZStack {
            Circle().fill(Farbe.petrol)
            // `color-mix(in srgb, farbe 12%, transparent)` über Petrol ist genau diese Farbe
            // mit Deckkraft 0,12 - die Mischung mit `transparent` rechnet prämultipliziert.
            Circle().fill(farbe.opacity(0.12))
            if let fuellung {
                // Der Ladestand als Säule von unten, im Kreis beschnitten.
                GeometryReader { raum in
                    Rectangle()
                        .fill(Color(Farbwert(0x7FB7C8, deckung: 0.26)))
                        .frame(height: raum.size.height * min(1, max(0, fuellung)))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(Circle())
            }
            Circle().strokeBorder(farbe, lineWidth: 2)
            // Der Strich der Zeichen skaliert in der Vorlage mit: 1,75 bei 24 Punkten Kantenlänge.
            Zeichen(art, groesse: zeichen(r), farbe: farbe, strich: zeichen(r) / 24 * 1.75)
        }
        .frame(width: r, height: r)
        .shadow(color: .white.opacity(r >= mass.ringGross ? 0.07 : 0), radius: 40)
    }

    /// Das Zeichen ist 44 Prozent des Kreises (`Ambiente.tsx:154`: 48 in 108, 64 in 148).
    private func zeichen(_ r: CGFloat) -> CGFloat { (r * 0.44).rounded() }

    /// Die Leitung: 14 Punkte Strich, 16 Luft, und sie wandert in Flussrichtung.
    private func leitung(farbe: Color, an: Bool, rueck: Bool) -> some View {
        Leitungsstrich(farbe: farbe.opacity(0.9), an: an, rueck: rueck, ruhig: ruhig)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            // Sie trifft die Mitte des grossen Kreises - nicht die der kleinen, die acht Punkte
            // tiefer sitzen (`globals.css:420`: `margin-top: calc(var(--ring-gross) / 2)`).
            .padding(.top, mass.ringGross / 2 - 1)
    }
}

/// Eine wandernde Strichkette. Die Richtung ist das einzige Datum, das sie trägt.
struct Leitungsstrich: View {
    let farbe: Color
    let an: Bool
    let rueck: Bool
    let ruhig: Bool

    @State private var versatz: CGFloat = 0

    var body: some View {
        GeometryReader { raum in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 1))
                p.addLine(to: CGPoint(x: raum.size.width, y: 1))
            }
            .stroke(
                farbe.opacity(an ? 1 : 0.25),
                style: StrokeStyle(lineWidth: 2, dash: [14, 16], dashPhase: versatz))
        }
        .onAppear { laufe() }
        .onChange(of: an) { _, _ in laufe() }
        .onChange(of: rueck) { _, _ in laufe() }
    }

    private func laufe() {
        // 30 Punkte in 2,4 Sekunden, rückwärts wenn der Speicher abgibt.
        versatz = 0
        guard an, !ruhig else { return }
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            versatz = rueck ? 30 : -30
        }
    }
}
