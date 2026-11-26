import DuckCurveKit
import SwiftUI

/// Das Bild, das nach fünf Minuten ohne Berührung über der Wandanzeige liegt.
///
/// **Was es ist und was nicht.** Kein Bildschirmschoner: die Seite darunter bleibt am Leben und
/// mit ihr die Verbindung. Es ist der Zustand, in dem diese Anzeige die meiste Zeit ist - und
/// darum zeigt es nicht weniger, sondern anderes: was man aus drei Metern liest.
///
/// **Dasselbe Bild wie die Startseite** (`home/Ambiente.tsx`). Unter der Uhr steht die Bühne
/// oder die Uhr, wie das Gerät es gewählt hat, daneben der Puffer und die Karte zum Bild; am Fuß
/// stehen die Zahlen des Tages. Tag oder Nacht entscheidet der Sonnenlauf aus dem Fahrplan,
/// nicht die Uhr - eine Wolke um 13 Uhr ist kein Abend. Die Rechnung steht im Kern (`Ruhebild`).
///
/// **Was am 25.11.2026 gegangen ist.** Der Hausherr: „Es läuft noch der Bildschirmschoner auf
/// dem alten Stand. Und bitte streiche im Bildschirmschoner diesen ewig langen Text. Wenn dann
/// nur ein ‚Wärmepumpe läuft‘.“ Der Begründungssatz der Regelung ist gestrichen, mit ihm das
/// eigene Flussbild aus drei Kreisen, der Sonnenbogen daneben und die Abendzeilen zum Fahrplan.
/// Läuft die Wärmepumpe, steht eine Marke unter dem Datum.
///
/// **Alle Masse wachsen mit der Fläche.** Die Vorlage schreibt fast jede Grösse als
/// `clamp(klein, x vw, gross)`; `Bildmasse` rechnet das nach. Oberhalb von etwa 1270 Punkten Breite
/// ist fast alles am oberen Anschlag, darunter wächst es linear mit.
struct Ambiente: View {
    @Environment(Hauszustand.self) private var haus
    let aufwachen: () -> Void

    /// Das Bild, das dieses Gerät für die Startseite gewählt hat (``Startbild``).
    @AppStorage(Startbild.merker) private var startbildGemerkt = Startbild.vorgabe.rawValue

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
    /// **Warum gespeichert und nicht gerechnet.** Die Vorlage rastet auf die Minute
    /// (`Home.tsx:117`: `Math.floor(now / 60_000)`). Ohne Raster liefe der Sonnenlauf
    /// sechzigmal so oft, und die Marke im Bogen zappelte.
    ///
    /// **Wahlfrei, damit das Bild nie im falschen anfängt.** Mit einem Anfangswert stünde im
    /// ersten Durchgang das Abendbild da - auch mittags, für den Bruchteil einer Sekunde, den
    /// die Überblendung sichtbar macht. Solange hier nichts steht, rechnet die Ansicht selbst.
    @State private var stand: Stand?

    /// Die Minute, auf der die **grosse Uhr** steht. Eine eigene Uhr, kein Mitlaufen am Rahmen.
    ///
    /// Sie kommt aus ``Hauszustand/wanduhr`` und nicht aus `haus.jetzt`: hier stand die Uhr des
    /// Dienstes, und eine Maschine mit drei Minuten Rueckstand schrieb `22:04` auf die Wand,
    /// waehrend die Statusleiste des iPads `22:07` zeigte. Was gerechnet wird - Sonnenlauf,
    /// Fahrplan, Aussicht -, nimmt weiter die Uhr der Daten (``datenminute``).
    @State private var takt = Date()

    struct Stand {
        var lauf: Ruhebild.Sonnenlauf?
        var bild: Ruhebild.Bild = .abend
        var aussicht = Ruhebild.Aussicht(erwartetKwh: nil, restKwh: nil, bis: nil)
        var morgenPvKwh: Double?
    }

    /// Jede Sekunde nachsehen, ob die Minute gewechselt hat.
    ///
    /// **Warum eine eigene Uhr.** Bis hierher kam der Takt daher, dass `WandRahmen` im
    /// Sekundenschlag neu baut und das Bild dabei mitgebaut wird. Das ist kein Takt, sondern
    /// ein Zufall: Hört der Rahmen auf zu takten, bleibt die Uhr auf dem Bild stehen - und
    /// genau das ist der eine Fehler, den ein Ruhebild nicht machen darf.
    private static let sekunde = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var jetztMinute: Date { takt }

    /// Die Minute der Daten: in der Uhr des Dienstes sind Fahrplan und Sonnenlauf geschrieben.
    private var datenminute: Date { Minutenraster.minutenanfang(haus.jetzt) }

    private var jetztStand: Stand { stand ?? gerechnet(datenminute) }

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
        .onReceive(Self.sekunde) { _ in
            let minute = Minutenraster.minutenanfang(haus.wanduhr)
            if minute != takt {
                takt = minute
                rechne()
            }
        }
        .onChange(of: haus.plan?.createdAt) { _, _ in rechne() }
        .onChange(of: haus.augenblick?.timestamp) { _, _ in rechne() }
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
        let tag = jetztStand.bild == .tag
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

    // MARK: - Kopf, Befund, Bild und Fuß

    private func inhalt(_ mass: Bildmasse) -> some View {
        VStack(alignment: .leading, spacing: mass.luft) {
            kopf(mass)
            befundzeile(mass)
            // Nur die Mitte dehnt sich; Kopf, Befund und Fuß nehmen ihre eigene Höhe.
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
            VStack(alignment: .leading, spacing: 0) {
                Text(Formate.hhmm(jetztMinute))
                    .font(Schrift.mono(mass.uhr))
                    .kerning(mass.uhr * -0.04)
                    .foregroundStyle(Farbe.text1)
                    .monospacedDigit()
                    // `line-height: .9` bei einem Schriftkasten von 1,3 Zeilen: die Zeile der
                    // Vorlage ist vier Zehntel niedriger als das, was SwiftUI mitbringt, und
                    // das Datum rueckt entsprechend hinauf. Sechs Punkte Abstand bleiben.
                    .padding(.bottom, 6 - mass.uhr * 0.2)
                Text(Formate.langesDatum(jetztMinute))
                    .font(Schrift.sans(mass.datum))
                    .foregroundStyle(Farbe.text2)
                if haus.zustand?.heatPump.running == true {
                    Startmarke(wort: "Wärmepumpe läuft", art: .laeuft)
                        .padding(.top, 8)
                }
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
                // Die Zahl steht da wie in der Vorlage, aber grau, wenn sie nicht traegt -
                // so haelt es die Buehne auch (`Buehnenbild.swift`).
                .foregroundStyle(aussenTraegt ? Farbe.text1 : Farbe.text3)
                .monospacedDigit()
            Text(haus.zustand?.system.outdoorSourceDe ?? "draußen")
                .font(Schrift.sans(mass.aussenWort))
                .foregroundStyle(Farbe.text2)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// Die Aussentemperatur.
    ///
    /// **Eine Abweichung von der Vorlage, mit Absicht.** Dort steht immer der Fuehler
    /// (`outdoor_temp_c.value`). Der Dienst sagt aber mit `outdoorShownC`, wenn er den Wert des
    /// Wetterdienstes zeigt, und `outdoorSourceDe` schreibt es daneben - eine Temperatur ohne
    /// Herkunft ist an einer Wandanzeige eine Behauptung. Die Kopfzeile der Wand macht es
    /// ebenso (`WandRahmen.swift`).
    private var aussenwert: Double? {
        haus.zustand?.system.outdoorShownC ?? haus.augenblick?.outdoorTempC.value
    }

    private var aussenTraegt: Bool {
        haus.zustand?.system.outdoorShownC != nil
            || haus.augenblick?.outdoorTempC.quality.traegt == true
    }

    /// Der atmende Punkt und das Wort daneben - das Einzige, was ein Ruhebild von einem
    /// eingefrorenen unterscheidet.
    private func lebenszeichen(_ mass: Bildmasse) -> some View {
        HStack(spacing: 9) {
            Atempunkt(gestoert: haus.gestoert)
            // Die Farbe traegt der Punkt, nicht das Wort (`globals.css:391`): ein rotes Wort
            // neben einem roten Punkt sagt dasselbe zweimal.
            // Ein Kicker in 12 Punkten, nicht in Nebelgrau: `.ambiente-live kicker`
            // (`Ambiente.tsx:47`) erbt Mono, Grossschrift und 0,13 em von `.kicker` und
            // setzt nur Groesse und Farbe neu (`globals.css:391`). Hier stand das drei
            // Zeilen lang von Hand nachgebaut.
            Kicker(wort: haus.verbindungswort, groesse: 12, farbe: Farbe.text2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(haus.zustand?.system.connectionLabelDe ?? haus.verbindungswort)
    }

    // MARK: - Der Befund der Wache

    /// **Kein Satz mehr.** Der Hausherr hat den Begründungssatz der Regelung am 25.11.2026
    /// gestrichen („Wenn dann nur ein ‚Wärmepumpe läuft‘“); das steht als Marke unter dem Datum.
    /// Was bleibt, ist der Befund der Wache, wenn eine Quelle schweigt: wer im Vorbeigehen auf
    /// die Wand sieht, soll den Ausfall sehen. Im Normalfall steht hier nichts.
    @ViewBuilder private func befundzeile(_ mass: Bildmasse) -> some View {
        if let befund {
            Text(befund.satz)
                .font(Schrift.sans(mass.satz * 0.7))
                .foregroundStyle(satzfarbe)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// **Auch der Befund der eigenen Uhr.** Gehen die Uhren von Dienst und Geraet auseinander,
    /// steht das hier - an der einzigen Stelle, die das Ruhebild für einen Satz hat. Ohne das
    /// waere die Lage auf dem Foto genau so still wie vorher: eine falsche Uhr, `LIVE` daneben
    /// und kein Wort darüber.
    private var befund: Wachbefunde.Zeile? {
        Ruhebild.schwersterBefund(haus.zustand?.system.watch, zuerst: haus.uhrbefunde)
    }

    private var satzfarbe: Color {
        switch befund?.schwere {
        case .alarm: return Farbe.alarmText
        case .warnung: return Farbe.amberWeich
        default: return Farbe.text1
        }
    }

    // MARK: - Die Mitte

    /// **Dasselbe Bild wie die Startseite** (Hausherr am 25.11.2026: „es läuft noch der
    /// Bildschirmschoner auf dem alten Stand“): Bühne oder Uhr, wie das Gerät es gewählt hat,
    /// dazu der Puffer und die Karte zum Bild. Vorher standen hier ein eigenes Flussbild aus
    /// drei Kreisen und am Abend eigene Zeilen zum Fahrplan. Alles ist nur zum Ansehen: eine
    /// Berührung weckt die Seite (`Ambiente.tsx`, `ambiente-bild`).
    ///
    /// **Nach der Breite, die da ist.** Die Karten stehen neben dem Bild, solange ihm dabei
    /// 520 Punkte bleiben; darunter wird es schmal und lässt Wallbox und Wärmepumpe weg
    /// (``Startbuehne/mass(breite:hoehe:)``). Ein iPad im Hochformat hat diese Breite nicht:
    /// dort steht das Bild oben über die ganze Breite und die Karten nebeneinander darunter.
    private func mitte(_ mass: Bildmasse) -> some View {
        let wahl = Startbild.aus(startbildGemerkt)
        let blick = Ausblick.baue(haus.plan, jetzt: datenminute)
        let nacht = jetztStand.bild == .abend
        let sonneAb: String? =
            nacht
            ? Ruhebild.naechsterAufgang(haus.plan, jetzt: datenminute, blick: blick).map { Formate.hhmm($0) }
            : nil
        let innen: CGFloat = mass.breite - 2 * mass.randSeite
        let nebeneinander = innen >= 520 + 14 + 404
        let anordnung =
            nebeneinander
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 14))
            : AnyLayout(VStackLayout(spacing: 14))
        return anordnung {
            startbildansicht(wahl, blick, nacht, sonneAb)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Ist selbst die ganze Breite zu schmal, steht darunter, was das Bild weglässt.
            if innen < 520 {
                if wahl == .uhr {
                    Startdingliste(nacht: nacht, sonneAb: sonneAb)
                } else {
                    Startunterhaus()
                }
            }
            if nebeneinander {
                VStack(spacing: 14) {
                    Startpufferkarte()
                    nebenkarte(wahl, blick)
                }
                .frame(width: 404)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    Startpufferkarte()
                    nebenkarte(wahl, blick)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func startbildansicht(
        _ wahl: Startbild, _ blick: Ausblick, _ nacht: Bool, _ sonneAb: String?
    ) -> some View {
        switch wahl {
        case .buehne:
            Buehnenbild(nacht: nacht, stand: sonnenstand, lauf: jetztStand.lauf, sonneAb: sonneAb)
        case .uhr:
            Stundenringbild(nacht: nacht, ausblick: blick, sonneAb: sonneAb)
        }
    }

    /// Neben der Bühne stehen die nächsten 24 Stunden als Bild; neben der Uhr, deren Ring sie
    /// selbst zeigt, der Strompreis in großer Zahl.
    @ViewBuilder
    private func nebenkarte(_ wahl: Startbild, _ blick: Ausblick) -> some View {
        switch wahl {
        case .buehne:
            Startausblickkarte(ausblick: blick, warnung: haus.plan?.plannerWarnDe)
        case .uhr:
            Startstromkarte(ausblick: blick, warnung: haus.plan?.plannerWarnDe)
        }
    }


    /// Wie weit die Sonne auf ihrem Bogen ist. Vor dem Aufgang und nach dem Untergang sitzt sie
    /// am Ende des Bogens, ohne Fahrplan in seiner Mitte (`JetztSeite.swift`, `sonnenstand`).
    private var sonnenstand: Double {
        let lauf = jetztStand.lauf
        if let anteil = Startbuehne.sonnenanteil(lauf, jetzt: datenminute) { return anteil }
        guard let lauf else { return 0.5 }
        return datenminute < lauf.von ? 0 : 1
    }

    // MARK: - Fuss

    private func fuss(_ mass: Bildmasse) -> some View {
        HStack(alignment: .bottom, spacing: 32) {
            HStack(alignment: .bottom, spacing: mass.zahlenLuft) {
                // **Am Abend nur drei** (`Ambiente.tsx:70`): die vierte ist der Strompreis, und
                // der steht dort schon gross rechts. Dieselbe Zahl zweimal auf einem Bild wäre
                // keine zweite Auskunft.
                ForEach(kennzahlen) { k in
                    VStack(alignment: .leading, spacing: 4) {
                        Grosszahl(
                            wert: k.wert, einheit: k.einheit ?? "", groesse: mass.fussZahl,
                            farbe: Farbe.ton(k.ton))
                        Text(k.wort)
                            .font(Schrift.sans(mass.fussWort))
                            .foregroundStyle(Farbe.text2)
                    }
                }
                // Die fünfte Zahl: am Tag, was die Sonne heute bringen soll, nachts, was sie
                // morgen bringt (`Ambiente.tsx`, `fuss`).
                if let erwartet = sonnenzahl {
                    VStack(alignment: .leading, spacing: 4) {
                        Grosszahl(
                            wert: Formate.zahl(erwartet, stellen: 1), einheit: "kWh",
                            groesse: mass.fussZahl, farbe: Farbe.text1)
                        Text(jetztStand.bild == .abend ? "Sonne morgen" : "Sonne heute erwartet")
                            .font(Schrift.sans(mass.fussWort))
                            .foregroundStyle(Farbe.text2)
                    }
                }
            }
            Spacer(minLength: 0)
            // **Der Hinweis traegt die Beschriftung, nicht der Behaelter.** Auf einem
            // Behaelter voller lesbarer Kinder spricht VoiceOver dessen Beschriftung nie - und
            // das waere ausgerechnet der eine Satz, der sagt, wie man die Bedienung zurueckholt.
            Text("BERÜHREN FÜR DIE BEDIENUNG")
                .font(Schrift.mono(mass.hinweis))
                .kerning(mass.hinweis * 0.08)
                .foregroundStyle(Farbe.text3)
                .padding(.bottom, 6)
                .lineLimit(1)
                .accessibilityLabel("Ruhebild. Antippen für die Bedienung.")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.top, mass.fussRand)
        .overlay(alignment: .top) {
            Rectangle().fill(Farbe.linie1).frame(height: 1)
        }
    }

    private var sonnenzahl: Double? {
        jetztStand.bild == .abend ? jetztStand.morgenPvKwh : jetztStand.aussicht.erwartetKwh
    }

    private var kennzahlen: [Kennzahl] {
        Tageskacheln.kennzahlen(
            tag: .heute, bilanz: bilanz?.totals,
            preisJetzt: haus.augenblick?.electricityPriceCtKwh.value,
            morgen: Tageskacheln.Morgen())
    }

    // MARK: - Rechnen und Laden

    private func rechne() {
        takt = Minutenraster.minutenanfang(haus.wanduhr)
        stand = gerechnet(datenminute)
    }

    private func gerechnet(_ jetzt: Date) -> Stand {
        let lauf = Ruhebild.sonnenlauf(haus.plan, jetzt: jetzt)
        var neu = Stand()
        neu.lauf = lauf
        // **Die Entscheidung auf dem belastbaren Wert, die Zahlen roh.** Eine zwei Tage alte
        // Messung von 0,4 kW hielte die Wand sonst die ganze Nacht auf dem Tagbild. Gezeigt
        // wird der rohe Wert wie in der Vorlage - aber entschieden wird mit dem, der traegt.
        neu.bild = Ruhebild.bild(lauf, jetzt: jetzt, pvKw: haus.augenblick?.pvPowerKw.belastbar)
        neu.aussicht = Ruhebild.aussicht(haus.plan, jetzt: jetzt, lauf: lauf)
        if let f = Tageskacheln.fenster(.morgen, jetzt: jetzt), let iv = haus.plan?.intervals {
            neu.morgenPvKwh = Tageskacheln.pvSumme(iv, von: f.von, bis: f.bis)
        }
        return neu
    }

    /// Die Tagesbilanz, solange das Bild steht - alle fünf Minuten, wie in der Vorlage.
    private func holeBilanz() async {
        while !Task.isCancelled {
            // **Ein Fehlschlag loescht nichts.** Sonst stehen drei der vier Fusszahlen fuer
            // fuenf Minuten auf einem Strich, weil ein einziger Abruf nicht durchkam - und das
            // Bild behauptet, der Tag habe nichts geerntet.
            if let frisch = try? await haus.api.energieUebersicht("day", anker: haus.heute) {
                bilanz = frisch
            }
            try? await Task.sleep(for: .seconds(300))
        }
    }

    // MARK: - Zahlen

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
    /// Wie weit die Zahl gesperrt ist. Die Vorlage nimmt -0,03 em, nur die Zahl der Aussicht
    /// -0,02 em (`globals.css:402`).
    var sperrung: CGFloat = -0.03

    var body: some View {
        // **Der Abstand ist ein Leerzeichen, kein Rand.** Im Markup steht zwischen Zahl und
        // Einheit ein gewoehnliches Leerzeichen, und es gehoert zur Mono-Schrift der Zahl: 0,6
        // em Vorschub, abzueglich der Sperrung. Drei Punkte waeren ein Viertel davon.
        HStack(alignment: .firstTextBaseline, spacing: groesse * (0.6 + sperrung)) {
            Text(wert)
                .font(Schrift.mono(groesse))
                .kerning(groesse * sperrung)
                .foregroundStyle(farbe)
                .monospacedDigit()
            if !einheit.isEmpty {
                Text(einheit)
                    .font(Schrift.sans(groesse * 0.42))
                    .foregroundStyle(Farbe.text3)
            }
        }
        .lineLimit(1)
        // `line-height: 1`: die Zahl bringt in SwiftUI einen Schriftkasten von 1,3 Zeilen mit,
        // die Vorlage gibt ihr genau eine. Die drei Zehntel stehen sonst als Luft zwischen
        // Zahl und Wort, und die Paare sitzen lockerer als gemeint.
        .padding(.vertical, -groesse * 0.15)
        .accessibilityElement(children: .combine)
    }
}

/// Der Punkt, der atmet, solange die Zahlen gelten.
///
/// **Er fängt nach einer Störung wieder an.** Die Dauerschleife hängt an der Änderung von
/// `atmet`; stand sie still, während der Punkt rot war, bleibt sie nach der Störung stehen -
/// der Punkt steht dann halb dunkel da und behauptet, die Anzeige sei eingefroren. Darum wird
/// `atmet` beim Wechsel zurückgesetzt und im nächsten Durchgang neu gesetzt.
struct Atempunkt: View {
    let gestoert: Bool
    @Environment(\.accessibilityReduceMotion) private var ruhigeBewegung
    @State private var atmet = false

    private var still: Bool { gestoert || ruhigeBewegung }

    var body: some View {
        Circle()
            .fill(gestoert ? Farbe.alarm : Farbe.gut)
            .frame(width: 8, height: 8)
            // `dch-atmen`: 3,6 Sekunden für den ganzen Weg, also 1,8 hin und 1,8 zurück.
            .opacity(still ? 1 : (atmet ? 0.5 : 1))
            .animation(
                still ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: atmet
            )
            .onAppear { atmet = !still }
            .onChange(of: still) { _, jetztStill in
                atmet = false
                guard !jetztStill else { return }
                Task { @MainActor in atmet = true }
            }
    }
}
