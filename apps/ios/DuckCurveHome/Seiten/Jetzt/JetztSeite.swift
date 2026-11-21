import DuckCurveKit
import SwiftUI

/// Jetzt: die Startseite.
///
/// Sie beantwortet eine Frage: **Was tut das Haus gerade, und warum.** Ein Satz, das lebende
/// Bild, die Kurve des Tages, vier Zahlen und das Dock. Alles Analytische steht in den Bereichen;
/// wer eine Zahl verstehen will, tippt sie an.
///
/// **Kurve und Zahlen kennen drei Tage, das Bild oben nur einen.** Gestern, heute, morgen
/// schalten gemeinsam um; der Energiefluss und das Dock bleiben beim Jetzt - ein Schalter, der an
/// einer Wand ein Geraet von gestern anboete, waere eine Falle.
///
/// **Was hier nicht mehr ist** (und im Dashboard auch nicht): die Messuhren, die
/// Begruendungs-Chips, die vier Zeitspuren und das Blaettern durch Tage. Die Begruendung ist der
/// Satz oben; vergangene Tage stehen unter Strom, mit allem Blaettern, das dort hingehoert.
struct JetztSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    @State private var vortag: [Verlaufspunkt] = []
    @State private var waermeprognose: [HeatForecastPoint] = []
    @State private var bilanz: EnergySummaryOut?
    @State private var geholterVortag = ""

    private var schmal: Bool { breite == .compact }

    /// Welcher Tag gezeigt wird - im ``Wegweiser`` und nicht in der Seite.
    ///
    /// **Weil die Heimkehr sonst nicht ankommt.** Hier stand `@State private var tag`, und
    /// `Wegweiser.heimkehr(jetzt:)` setzte nach zwei Minuten brav die Zeitraeume der
    /// Berichtsseiten zurueck - an diese Seite kam es nicht. Wer an der Wandanzeige im
    /// Vorbeigehen auf „Gestern“ tippte, hinterliess eine Anzeige, die gestrige Kurve und
    /// gestrige Kacheln so zeigte, wie sonst die heutigen stehen (`Home.tsx:36-38`: „Wer
    /// vorbeigeht, soll nicht das Gestern eines anderen sehen“).
    private var tag: Kurventag { wegweiser.kurventag }

    var body: some View {
        gerippe
            .task(id: tag) { await ladeFuerTag() }
            .task(id: haus.heute) { await ladeVortag() }
            .task(id: tag) { await haltBilanzFrisch() }
            .onChange(of: haus.heute) { mitternacht() }
    }

    /// **Mitternacht** (`Home.tsx:95-110`, Kommentar: „Die alte Ansicht blieb auf gestern
    /// stehen“).
    ///
    /// Wechselt der Kalendertag, waehrend die Seite steht, dann ist aus dem Gestern von eben
    /// vorgestern geworden: unter „Gestern“ stand dann vorgestern, und „Heute“ begann mit der
    /// Reihe von gestern, weil nichts sie neu holte. Also Schalter zurueck, geholte Reihen
    /// verwerfen - und die Reihe des neuen Tages holen.
    ///
    /// **Das Holen ist der Schritt, ohne den „Heute“ leer bleibt** (`Home.tsx:109`:
    /// `void api.history("today").then(…)`, begruendet in `:95-97`: „weil der
    /// Zustandsspeicher Live-Werte nur an den laufenden Tag anhaengt, hoerte die Kurve dort
    /// schlicht auf“). Es gilt hier genauso: ``Hauszustand`` haengt Live-Werte nur an,
    /// solange `raster.tag` der laufende Tag ist, und `ersteLadung()` holt den Verlauf nur,
    /// wenn das Raster leer ist oder schon auf heute steht - selbst eine Wiederverbindung
    /// fuellt es also nicht nach. ``Tageskurve`` siebt die Messwerte nach dem gezeigten Tag,
    /// und damit stuenden pv, haus, waermepumpe und preis unter „Heute“ bis zum Neustart der
    /// App leer. `ladeTag` setzt `raster` auf den neuen Tag, und damit laeuft auch das
    /// Fortschreiben der Live-Werte wieder an.
    private func mitternacht() {
        if wegweiser.kurventag != .heute { wegweiser.kurventag = .heute }
        geholtesRaster = []
        vortag = []
        geholterVortag = ""
        Task { await haus.ladeTag(haus.heute) }
    }

    @ViewBuilder private var gerippe: some View {
        if schmal { hand } else { wand }
    }

    // MARK: - Die Wandanzeige

    /// **Ein Bild, kein Rollbereich.**
    ///
    /// Die Vorlage legt die Startseite auf genau einen Schirm: `height: 100dvh`,
    /// `overflow: hidden`, fünf Reihen (`globals.css:190`). Vier davon nehmen, was sie
    /// brauchen – Kopf, Satz, Kurve, Fuß –, und das Flussbild bekommt den Rest. Die App rollte
    /// hier, und damit war die Wandanzeige keine: wer im Vorbeigehen hinsieht, scrollt nicht.
    ///
    /// Die Reihenhöhen stehen in der Vorlage als `grid-template-rows: auto auto minmax(0,1fr)
    /// clamp(170px, 24vh, 260px) auto`.
    private var wand: some View {
        GeometryReader { raum in
            // **Zwei Stufen, nach der Höhe des Schirms** (`globals.css:269-274`): unter 820
            // Punkten – und so hoch ist ein 10,9-Zoll-iPad im Querformat genau – rücken die
            // Blöcke auf 8 Punkte zusammen, der Rand auf 14, und der Satz wird kleiner. Sonst
            // drückt der Fuß die Kurve unter den Rand, und abgeschnitten wird hier nichts
            // weggerollt, sondern ist weg.
            let eng = raum.size.height < 820
            VStack(alignment: .leading, spacing: eng ? 8 : 12) {
                satzzeile(breit: raum.size.width, eng: eng)
                HStack(alignment: .center, spacing: 18) {
                    Energiefluss(
                        augenblick: haus.augenblick, jetzt: haus.jetzt,
                        pvSpitzeKw: pvSpitze, wpLaeuft: haus.zustand?.heatPump.running,
                        nacht: istNacht, sonneAb: sonneAb,
                        // Auf einem niedrigen Schirm ruecken auch die Knotenkreise zurueck
                        // (`globals.css:272-273`), nicht nur die Blockabstaende.
                        eng: eng
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Die Leiste ist 272 Punkte breit (`globals.css:211`).
                    // Die Leiste dehnt sich über die ganze Zeilenhöhe - darauf beruht, dass
                    // der Puffer „die ganze Hoehe" bekommt (`globals.css:242`).
                    Leiste()
                        .frame(width: 272)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(haus.gestoert ? 0.6 : 1)
                kurve
                    .frame(height: kurvenhoehe(raum.size.height))
                fuss
            }
            .padding(.horizontal, 32)
            .padding(.top, eng ? 14 : 22)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// `clamp(170px, 24vh, 260px)` (`globals.css:190`).
    private func kurvenhoehe(_ hoehe: CGFloat) -> CGFloat {
        min(260, max(170, hoehe * 0.24))
    }

    /// Der Fuß: links die vier Zahlen des Tages, rechts das Dock.
    ///
    /// **Ohne Karten.** `.home-fuss` ist eine Zeile und keine Fläche (`globals.css:251-255`);
    /// die vier Zahlen stehen frei auf dem Grund, mit 32 Punkten Abstand, und das Dock steht
    /// rechts daneben. In einer Karte wären es zwei weitere Kästen auf einem Schirm, der schon
    /// voll ist.
    private var fuss: some View {
        HStack(alignment: .bottom, spacing: 24) {
            HStack(alignment: .firstTextBaseline, spacing: 32) {
                ForEach(kennzahlen) { k in
                    VStack(alignment: .leading, spacing: 3) {
                        Zahl(
                            wert: k.wert, einheit: k.einheit,
                            schrift: Schrift.custom(26), einheitSchrift: Schrift.sans(12),
                            farbe: k.farbe
                        )
                        Text(k.wort)
                            .font(Schrift.sans(12))
                            .foregroundStyle(Farbe.text2)
                        // **Der Zusatz fehlte an der Wand** (`tage.ts:107`: „Wärme erwartet ·
                        // 4,2 kWh Strom“). Die Vorlage hat die Angabe im Wort selbst; der Kern
                        // fuellt sie als eigenes Feld, und das Telefon zeigt sie laengst. Hier
                        // stand nur die thermische Zahl, und wie viel Strom sie kostet, stand
                        // auf der Startseite der Wandanzeige nirgends.
                        if let dazu = k.dazu {
                            Text(dazu)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                        }
                    }
                }
            }
            Spacer(minLength: 16)
            Dock()
        }
    }

    // MARK: - Die Handfassung

    private var hand: some View {
        Seite {
            satzblock
            // **Am Telefon das Hochformat-Bild** (`FlowHandy.tsx`): sechs Knoten mit Zahlen
            // in der Anordnung der Wandanzeige liefen auf 390 Punkten Breite ineinander.
            Energiefluss(
                augenblick: haus.augenblick, jetzt: haus.jetzt,
                pvSpitzeKw: pvSpitze, wpLaeuft: haus.zustand?.heatPump.running,
                nacht: istNacht, sonneAb: sonneAb, fassung: .hand
            )
            // **Bei unterbrochener Verbindung blasser** (`Home.tsx:227`). Das Bild zeigt
            // dann Zahlen von vorhin, und es soll aussehen, als meinte es sie nicht mehr.
            .opacity(haus.gestoert ? 0.6 : 1)
            Leiste(kompakt: true)
            kurve
            // **Vier gleich grosse Zahlen in zwei Spalten, ohne Ueberschrift**
            // (`handy.css:279-283`). „Eine Zahl fuehrt" gilt in der Vorlage fuer die
            // Kennzahlen der Unterseiten, nicht fuer die Startseite: hier sind es vier Zahlen
            // desselben Tages, und keine davon fuehrt.
            Kachelfeld(kacheln: kennzahlen, ersteFuehrt: false, art: .start)
            // Ohne Ueberschrift: das Dock erklaert sich durch seine Knoepfe, und am Telefon
            // ist jede Zeile Ueberschrift eine Zeile weniger Inhalt (`Dock.tsx:228`).
            Karte {
                Dock()
            }
        }
    }

    /// Der Satz der Wandanzeige, mit dem Stand rechts auf derselben Grundlinie.
    ///
    /// **Untereinander ist die Telefonfassung** (`globals.css:201` gegen `:300`): dort steht
    /// der Stand unter dem Satz, weil drei Satzzeilen auf dem iPhone die Kurve unter den
    /// ersten Bildschirm schoben. An der Wand ist daneben Platz, und eine Zeile weniger ist
    /// eine Zeile mehr für das Bild.
    private func satzzeile(breit: CGFloat, eng: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                Text(haus.satz)
                    // `clamp(20px, 2.1vw, 28px)`, auf niedrigen Schirmen
                    // `clamp(18px, 1.9vw, 24px)` (`globals.css:208`, `:271`).
                    .font(Schrift.sans(
                        eng ? min(24, max(18, breit * 0.019)) : min(28, max(20, breit * 0.021)),
                        relativeTo: .title2))
                    .fontWeight(.medium)
                    .kerning(-0.35)
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                    // Begrenzte Zeilenlänge: über die volle Breite findet das Auge den Anfang
                    // der nächsten Zeile nicht wieder (`globals.css:208`, `max-width: 70ch`).
                    .frame(maxWidth: 820, alignment: .leading)
                Spacer(minLength: 12)
                if !unterzeile.isEmpty {
                    Text(unterzeile)
                        .font(Schrift.sans(13))
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                }
            }
            Wache(befunde: haus.zustand?.system.watch ?? [])
            if let f = haus.fehler {
                Stoerung(fehler: f) { Task { await haus.ersteLadung() } }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Der Satz

    private var satzblock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(haus.satz)
                // 21 Punkte mit Strichstaerke 500 (`handy.css:261`). Es ist der erste Satz der
                // App und traegt die Begruendung des Hauses; in 19 Punkten normal stand er da
                // wie eine Bildunterschrift.
                .font(Schrift.sans(21, relativeTo: .title3))
                .fontWeight(.medium)
                .kerning(-0.3)
                .lineSpacing(2)
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            if !unterzeile.isEmpty {
                Text(unterzeile)
                    .font(Schrift.sans(13))
                    .foregroundStyle(Farbe.text3)
            }
            Wache(befunde: haus.zustand?.system.watch ?? [])
            // **Nur am Telefon, und hier und nicht unter Technik** (`Home.tsx:225`): wer unter
            // Technik ist, hat den Weg schon gefunden. Ob der Hinweis dasteht, entscheidet
            // ``Startseitenhinweis``.
            Mitteilungshinweis()
            if let f = haus.fehler {
                Stoerung(fehler: f) {
                    Task { await haus.ersteLadung() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Die Zeile unter dem Satz, in Worten statt in Kennungen. Erst, wer gerade entscheidet; dann,
    /// was als Naechstes kommt oder seit wann der Satz gilt.
    private var unterzeile: String {
        var teile: [String] = []
        let wort = haus.betriebswort
        if !wort.isEmpty { teile.append(wort) }

        let laeuft = haus.zustand?.heatPump.running ?? false
        let vonHand = haus.zustand?.operatingMode.override != nil
        let aus = haus.zustand?.operatingMode.systemMode == .off
        if !laeuft, !vonHand, !aus,
           // Der Baukoerper steht mit Namen da und nicht angehaengt: in einer
           // `if`-Bedingung ist ein angehaengter nicht vom Rumpf des `if` zu unterscheiden -
           // fuer den Compiler eine Warnung, fuer den Leser schlimmer.
           let naechster = Fahrplan.phasen(
               haus.plan, jetzt: haus.jetzt, bis: haus.jetzt.addingTimeInterval(24 * 3600),
               wenn: { $0.reasonCode == "planned_optimizer" && $0.plannedHpState == .release }
           ).first,
           naechster.von > haus.jetzt
        {
            teile.append("nächster geplanter Lauf um \(Formate.hhmm(naechster.von))")
        } else if let d = haus.zustand?.decision, let at = Zeit.ausIso(d.at) {
            teile.append("Stand \(Formate.hhmm(at))")
        }
        return teile.joined(separator: " · ")
    }

    // MARK: - Die Kurve

    @ViewBuilder private var kurve: some View {
        let bild = TageskurveBild(
            kurve: Tageskurve.baue(
                tag: tag,
                raster: tag == .heute ? haus.raster.punkte : geholtesRaster,
                vortag: schattenreihe,
                plan: haus.plan,
                waermeprognose: waermeprognose,
                jetzt: haus.jetzt
            ),
            tag: tag,
            tagwahl: AnyView(Tagwahl(tag: Binding(
                get: { wegweiser.kurventag }, set: { wegweiser.kurventag = $0 })))
        )
        if schmal {
            Karte { bild }
        } else {
            // **An der Wand ohne Karte** (`globals.css:249`: `.home-kurve` ist eine Spalte,
            // keine Fläche). Sie steht auf dem Grund wie das Flussbild darüber.
            bild
        }
    }

    /// Fuer gestern wird der Verlauf eigens geholt; fuer morgen gibt es keinen.
    @State private var geholtesRaster: [Verlaufspunkt] = []

    /// Welche Reihe als Schatten hinter dem Tag liegt.
    ///
    /// **Hinter heute gestern, hinter morgen heute** (`tage.ts:192`: `punkte = tag === "heute"
    /// ? gestern : heute`). Die App gab fuer morgen nichts, und damit fehlte auf einem von drei
    /// Tagen der Vergleich, der die ganze Begruendung der Schattenkurve ist: „erst der Vortag
    /// macht aus 13,4 kWh eine Auskunft“ (`DayCurve.tsx:28-30`). Der Kern konnte es laengst und
    /// sagte es selbst - ``Tageskurve`` setzt das Schattenwort fuer morgen auf „heute“, ein
    /// Zweig, den die Seite nie erreichte.
    ///
    /// **Hinter gestern liegt nichts** (`tage.ts:146-147`): vorgestern holt die Wandanzeige
    /// nicht, wer so weit zurueck will, ist unter Strom richtig.
    private var schattenreihe: [Verlaufspunkt] {
        switch tag {
        case .heute: return vortag
        case .morgen: return haus.raster.punkte
        case .gestern: return []
        }
    }

    // MARK: - Die vier Zahlen


    /// Vier Zahlen, gerechnet im Kern (``Tageskacheln``) und hier nur eingefaerbt.
    ///
    /// **Was hier vorher stand.** Sonne, „im Haus", „fuer die Waerme" und je nach Tag Netzbezug
    /// oder Preis - also drei andere Zahlen als die Wandanzeige. Autarkie, das bezahlte Geld und
    /// der Mittelpreis kamen auf der Seite nicht vor.
    private var kennzahlen: [Kacheldaten] {
        Tageskacheln.kennzahlen(
            tag: tag, bilanz: bilanz?.totals,
            preisJetzt: haus.augenblick?.electricityPriceCtKwh.belastbar,
            morgen: morgendaten
        )
        .map(Kacheldaten.init)
    }

    /// Was von morgen bekannt ist: Sonne und Preise aus dem Fahrplan, Waerme aus der Prognose.
    private var morgendaten: Tageskacheln.Morgen {
        guard tag == .morgen, let f = Tageskacheln.fenster(.morgen, jetzt: haus.jetzt) else {
            return .init()
        }
        let iv = haus.plan?.intervals ?? []
        return .init(
            pvKwh: Tageskacheln.pvSumme(iv, von: f.von, bis: f.bis),
            waerme: Tageskacheln.waermeSumme(waermeprognose, von: f.von, bis: f.bis),
            preise: Tageskacheln.preise(iv, von: f.von, bis: f.bis)
        )
    }

    // MARK: - Nachladen

    private var pvSpitze: Double {
        let erwartet = (haus.plan?.intervals ?? []).map(\.expectedPvKw).max() ?? 0
        return max(4, erwartet)
    }

    /// Tag oder Nacht - aus der Erwartung des Fahrplans, nicht aus der Uhr. Im Dezember ist um
    /// 17 Uhr Nacht und im Juni nicht.
    private var istNacht: Bool {
        let jetzt = haus.jetzt
        let nah = (haus.plan?.intervals ?? []).filter {
            guard let t = Zeit.ausIso($0.ts) else { return false }
            return abs(t.timeIntervalSince(jetzt)) < 1800
        }
        guard !nah.isEmpty else {
            // Ohne Plan: nach der Sonne im Augenblick.
            return (haus.augenblick?.pvPowerKw.belastbar ?? 0) < 0.05
        }
        return nah.allSatisfy { $0.expectedPvKw < 0.05 }
    }

    /// Wann die Sonne wiederkommt. Nur die Uhrzeit, ohne „morgen": ein Sonnenaufgang ist immer
    /// der naechste, und neben dem Mond ist kein Platz fuer mehr.
    private var sonneAb: String? {
        guard istNacht else { return nil }
        let kuenftig = (haus.plan?.intervals ?? []).compactMap { iv -> Date? in
            guard let t = Zeit.ausIso(iv.ts), t > haus.jetzt, iv.expectedPvKw >= 0.05 else { return nil }
            return t
        }
        return kuenftig.min().map { Formate.hhmm($0) }
    }

    private func ladeFuerTag() async {
        switch tag {
        case .heute:
            geholtesRaster = []
            waermeprognose = []
            // Autarkie, bezahltes Geld und Mittelpreis stehen nur in der Tagesbilanz. Sie wird
            // auch fuer den laufenden Tag geholt - vorher lief sie nur fuer gestern, und heute
            // standen darum drei Striche.
            bilanz = try? await haus.api.energieUebersicht("day", anker: haus.heute)
        case .gestern:
            let gestern = Tag.plus(haus.heute, -1)
            if let h = try? await haus.api.verlaufTag(gestern) {
                var r = Minutenraster()
                r.setze(h, tag: gestern)
                geholtesRaster = r.punkte
            }
            bilanz = try? await haus.api.energieUebersicht("day", anker: gestern)
            waermeprognose = []
        case .morgen:
            geholtesRaster = []
            bilanz = nil
            // Die Waermelastprognose reicht 48 Stunden und wird nur geholt, wenn jemand nach
            // morgen fragt - sonst ist es eine Anfrage, die niemand liest.
            if let w = try? await haus.api.energieWaerme("day", anker: haus.heute) {
                waermeprognose = w.forecast
            }
        }
    }

    /// Die Tagesbilanz des laufenden Tages veraltet, waehrend die Seite steht: bezahltes Geld und
    /// Autarkie wachsen mit jeder Viertelstunde. Die Wandanzeige holt sie alle fuenf Minuten neu.
    private func haltBilanzFrisch() async {
        guard tag == .heute else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            guard !Task.isCancelled, tag == .heute else { return }
            if let b = try? await haus.api.energieUebersicht("day", anker: haus.heute) {
                bilanz = b
            }
        }
    }

    /// Der Vortag liegt als Schattenkurve hinter heute. Eine Anfrage am Tag.
    private func ladeVortag() async {
        let gestern = Tag.plus(haus.heute, -1)
        guard Tag.istTag(gestern), geholterVortag != gestern else { return }
        geholterVortag = gestern
        guard let h = try? await haus.api.verlaufTag(gestern) else {
            geholterVortag = ""
            return
        }
        var r = Minutenraster()
        r.setze(h, tag: gestern)
        vortag = r.punkte
    }
}
