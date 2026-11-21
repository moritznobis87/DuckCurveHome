import DuckCurveKit
import SwiftUI

/// Alles, was die Wärmeseite braucht - in einem Rutsch geholt, aber nicht in einem Stück.
///
/// **Drei Antworten, und jede darf einzeln fehlen.** Die Vorlage hält drei getrennte Zustände
/// (`HeatOverview.tsx:92-94`) und zeigt das Fehlerband nur für die **Bilanz** (`:138`): fällt
/// `/energy/heat` aus, stehen Kacheln, Tagesverlauf, Kosten und Spannenvergleich weiter. Hier
/// stand bis zur zweiten Runde `try await` an beiden Hauptabfragen, und ein Fehlschlag einer von
/// beiden räumte die ganze Seite - `strom` ist deshalb jetzt ``Optional``.
///
/// **Die vier Spannen dazu.** Der Vergleich „Wärme im Zeitraum“ stellt Tag, Woche, Monat und
/// Jahr nebeneinander; das sind vier weitere Abfragen derselben Bilanz. Scheitert eine, fehlt
/// ihre Spalte - die Seite bleibt stehen.
struct Waermedaten: Sendable {
    let bilanz: HeatBalanceOut
    /// `/energy/heat` - Taktung, Ofen, Strom nach Herkunft, Pufferreihe. Darf fehlen.
    let strom: HeatReportOut?
    let schieben: ShiftReportOut?
    let jeSpanne: [Spanne: HeatBalanceOut]
}

/// Wärme: wer geliefert hat, was es gekostet hat, wie die Anlage lief.
///
/// **Die Wärme kommt aus der Bilanz, und nur von dort.** Wärmemenge, Arbeitszahl und
/// Wärmepreis stehen auf dieser Seite genau einmal. Aus `/energy/heat` kommt nur, was gemessen
/// ist: der Strom der Wärmepumpe nach Herkunft, die Taktung, der Ofen. Die Vorlage
/// (`apps/web/src/components/reports/HeatOverview.tsx`) hat dafür zwei Seiten
/// zusammengelegt, die für denselben Tag verschiedene Zahlen nannten.
///
/// **`/waerme/bilanz` ist keine Seite mehr, und das ist der Punkt.** Bis zum 10.11.2026 stand
/// hier eine zweite Seite „Bilanz“ daneben; die Vorlage hat sie zur Weiterleitung gemacht
/// (`apps/web/src/app/waerme/bilanz/page.tsx:1-15`), weil beide für denselben Tag
/// verschiedene Zahlen nannten - „24,5 kWh Wärme und Arbeitszahl 2,90 auf der einen, 20,4 kWh
/// und 2,41 auf der anderen“ (`HeatOverview.tsx:19-23`). Die App hatte diese zweite Seite als
/// `WaermebilanzSeite` in dieser Datei, mit einer Kachel „Wärme gesamt“, die den Ofen nicht
/// mitzählte. Sie ist gelöscht; die Adresse löst über ``Bereiche/ziel(_:)`` auf diese Seite
/// auf. Keine Zahl ist dabei verloren gegangen: „entnommen“ und „Verlust“ stehen als Unterzeile
/// der Entnahme-Kachel und als Zeilen im Spannenvergleich, die Arbeitszahl ebenfalls dort, die
/// Auflösung als Kopfzeile des Tagesverlaufs. Was nicht wiederkommt, lässt die Vorlage mit
/// Absicht weg: „davon nutzbar“, „erwartet, 24 h“ - der Wärmebedarf der kommenden Stunden
/// gehört zum Fahrplan und steht dort (`HeatOverview.tsx:30-31`).
///
/// **„Bilanz des Puffers“ bleibt stehen, obwohl die Vorlage sie nicht hat** - das ist die eine
/// bewusste Zugabe dieser Seite. `buffer_balance` kommt in ganz `apps/web/src` nur in
/// `lib/api/types.ts:4519-4523` vor, in keiner Komponente; der Dienst rechnet es trotzdem, und
/// die letzte Zeile der Karte ist die einzige Stelle der App, die sagt, wie viel des
/// Pufferzuwachses sich *nicht* erklären lässt. Ein Puffer, dessen Gewinn zu einem Drittel
/// unerklärt ist, hat einen Fühler, der lügt, oder eine Wärmequelle, die niemand kennt - und
/// auf einer Seite mit dem Kicker „gerechnet, nicht gemessen“ ist das die Zahl, die die anderen
/// prüft. `price_quality.note_de` und `model_note_de` sind dagegen weggefallen: sie standen in
/// der Methodenkarte und haben in der Vorlage kein Gegenstück.
///
/// **Was die Vorlage hat und diese Seite nicht.** Das Nachladen im Fünf-Minuten-Takt
/// (`useReport.ts:7, 39, 70`) gehört in ``Berichtsseite`` - es trifft alle dreizehn
/// Berichtsseiten und ist kein Zug über diese eine. Ebenso die Ankerziele `#puffer` und
/// `#ofen` (`HeatOverview.tsx:198, 279`), auf die das Anlagenschema verweist: ein Sprungziel
/// braucht einen `ScrollViewReader` um den Seiteninhalt, und der steht im Gerippe.
struct WaermeSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        Berichtsseite { zr, api in
            // Vier Abfragen nebeneinander. Nur die Bilanz wird geworfen: ihr Fehler ist der
            // einzige, für den die Vorlage ein Band zeigt (`HeatOverview.tsx:138`).
            async let bilanz = api.waermebilanz(zr.spanne.rawValue, anker: zr.anker)
            async let strom = api.energieWaerme(zr.spanne.rawValue, anker: zr.anker)
            async let schieben = api.energieVerschiebung(zr.spanne.rawValue, anker: zr.anker)
            async let spannen = holeSpannen(anker: zr.anker, api: api)
            return Waermedaten(
                bilanz: try await bilanz,
                strom: try? await strom,
                schieben: try? await schieben,
                jeSpanne: await spannen
            )
        } inhalt: { d in
            inhalt(d, z: z)
        }
    }

    /// Die vier Spannen nebeneinander. `try?` je Spanne: eine fehlende Spalte ist besser als
    /// eine Seite, die an ihr scheitert.
    private func holeSpannen(anker: String, api: Api) async -> [Spanne: HeatBalanceOut] {
        await withTaskGroup(of: (Spanne, HeatBalanceOut?).self) { gruppe in
            for s in Spanne.allCases {
                gruppe.addTask {
                    (s, try? await api.waermebilanz(s.rawValue, anker: anker))
                }
            }
            var aus: [Spanne: HeatBalanceOut] = [:]
            for await (s, b) in gruppe {
                if let b { aus[s] = b }
            }
            return aus
        }
    }

    // MARK: - Die Anordnung

    @ViewBuilder private func inhalt(_ d: Waermedaten, z: Zeitraum) -> some View {
        let tag = d.bilanz.period == .day

        Kachelfeld(
            kacheln: Waermeuebersicht.kacheln(bilanz: d.bilanz, strom: d.strom)
                .map(Kacheldaten.init),
            kicker: "Wärme",
            // **Drei Spalten am iPad, zwei am Telefon.** Die Vorlage setzt die sechs in *eine*
            // Reihe (`KpiGrid cols={6}`, `globals.css:107`: Mindestbreite 150 px); auf 1180
            // Punkten blieben davon 186 je Kachel, und „Heizung und Warmwasser · Verlust 2,1
            // kWh“ bricht dort viermal um. Zwei Reihen zu drei sind der nächste Schritt, der
            // die Unterzeilen lesbar lässt - so hält es auch die Stromseite.
            spalten: schmal ? 2 : 3
        )

        // Der Tag als Verlauf, jeder laengere Zeitraum als Balken. Beides zugleich waere
        // dieselbe Zufuhr zweimal: einmal je Minute, einmal je Stunde.
        if tag {
            tagesverlaufskarte(d)
        } else {
            erzeugerkarte(d.bilanz)
        }

        pufferreihenreihe(d, tag: tag)
        kostenreihe(d, z: z, tag: tag)
        ofenreihe(d)

        if let b = d.strom?.bufferBalance {
            Karte(kicker: "Bilanz des Puffers") {
                pufferbilanz(b)
            }
        }

        Spannenstreifen(
            titel: Waermeuebersicht.spannentitel,
            zeilen: Waermeuebersicht.spannenzeilen(d.jeSpanne),
            anker: z.anker,
            jetzt: haus.jetzt
        )

        annahmenverweis
        Methode(
            Waermeuebersicht.methodensaetze.map { $0 as String? } + [
                Waermeuebersicht.verlaufssatz(d.bilanz.noteDe),
                Waermeuebersicht.annahmensatz(d.bilanz.params),
                d.strom?.summary.meta.estimatedNoteDe,
            ],
            // **Die Abdeckung steht in der Kurzzeile und nicht im Rumpf.** Sie schränkt jede
            // Zahl dieser Seite ein, und zugeklappt wäre sie verschwiegen: „eine Seite mit 61
            // Prozent Datenabdeckung sieht aus wie eine mit hundert“ (`Bericht.swift:516-522`,
            // Vorlage `ReportShell.tsx:166-168`). Sie stand hier als einer von acht Sätzen im
            // Deckel.
            kurz: d.strom.map { Waermeuebersicht.abdeckungssatz($0.summary.meta) },
            titel: Waermeuebersicht.methodentitel
        )
    }

    // MARK: - Die Reihen der Vorlage

    /// Pufferschichtung und Stromherkunft, `7fr 5fr` (`HeatOverview.tsx:194`).
    ///
    /// **Ohne Pufferreihe keine Reihe, sondern die Karte allein.** Die Vorlage begründet es
    /// (`:195-196`): „Die Schichtung des Puffers gibt es nur je Tag; in einer Woche wäre sie
    /// ein Knäuel. Dann fehlt die Karte, statt mit einem Platzhalter die halbe Zeile zu
    /// belegen.“ Eine ``Spaltenreihe`` mit einem Kind wäre 7/12 breit - also gar keine.
    @ViewBuilder private func pufferreihenreihe(_ d: Waermedaten, tag: Bool) -> some View {
        let reihe = Waermeuebersicht.pufferreihe(d.strom?.bufferSeries ?? [])
        if tag, !reihe.isEmpty {
            spaltenreihe([7, 5]) {
                Karte(
                    kicker: "Pufferspeicher",
                    beiwerk: beiwerk("Temperaturen in vier Höhen · Leistung der Wärmepumpe")
                ) {
                    Pufferbild(reihe: reihe)
                }
                herkunftskarte(d.strom)
            }
        } else {
            herkunftskarte(d.strom)
        }
    }

    /// Kosten, Taktung und Verschieben zu gleichen Dritteln (`HeatOverview.tsx:213`).
    @ViewBuilder private func kostenreihe(_ d: Waermedaten, z: Zeitraum, tag: Bool) -> some View {
        spaltenreihe([1, 1, 1]) {
            kostenkarte(d.bilanz)
            taktkarte(d.strom?.cycling ?? CyclingStats())
            schiebekarte(d.schieben, z: z, tag: tag)
        }
    }

    /// Ofen und Fenster, `5fr 7fr` - **fehlt beides, fehlt die ganze Reihe**
    /// (`HeatOverview.tsx:276-278`). Die leere Karte „In diesem Zeitraum hat der Ofen nicht
    /// gemeldet.“ ist damit weg: eine Karte, die nur sagt, dass sie nichts sagt, nimmt die
    /// halbe Zeile.
    @ViewBuilder private func ofenreihe(_ d: Waermedaten) -> some View {
        let ofen: StoveOut? = d.strom?.stove.available == true ? d.strom?.stove : nil
        let fenster: VentilationOut? =
            Waermeuebersicht.zeigtFenster(d.bilanz.ventilation) ? d.bilanz.ventilation : nil
        if let ofen, let fenster {
            spaltenreihe([5, 7]) {
                ofenkarte(ofen)
                fensterkarte(fenster)
            }
        } else if let ofen {
            ofenkarte(ofen)
        } else if let fenster {
            fensterkarte(fenster)
        }
    }

    /// Eine `report-row`: am iPad nebeneinander im Maß der Vorlage, am Telefon untereinander
    /// (`globals.css:108` gegen `:350`).
    @ViewBuilder private func spaltenreihe<Inhalt: View>(
        _ anteile: [CGFloat], @ViewBuilder _ inhalt: () -> Inhalt
    ) -> some View {
        if schmal {
            VStack(spacing: 14) { inhalt() }
        } else {
            Spaltenreihe(anteile: anteile, abstand: 14) { inhalt() }
        }
    }

    // MARK: - Die Karten

    /// Der Tagesverlauf. `resolutionDe` steht als Beiwerk rechts im Kopf und nicht als Titel
    /// darunter - so wie `right={bilanz?.resolution_de}` in `ui/Card.tsx:20-29`.
    private func tagesverlaufskarte(_ d: Waermedaten) -> some View {
        Karte(kicker: "Tagesverlauf", beiwerk: beiwerk(d.bilanz.resolutionDe)) {
            Waermeverlauf(punkte: d.bilanz.series)
        }
    }

    private func erzeugerkarte(_ b: HeatBalanceOut) -> some View {
        Karte(kicker: b.period == .year ? "Wärme je Monat" : "Wärme je Tag") {
            if b.buckets.isEmpty {
                Leer(satz: "Für diesen Zeitraum liegen keine Werte vor.")
            } else {
                // 250 statt 180 pt: die Vorlage gibt dem Bild 260 px (`HeatOverview.tsx:185`).
                Balkenbild(stuecke: erzeuger(b), hoehe: 250)
            }
        }
    }

    private func herkunftskarte(_ r: HeatReportOut?) -> some View {
        Karte(kicker: "Strom der Wärmepumpe nach Herkunft") {
            if let r, !r.summary.buckets.isEmpty {
                // 240 pt: die Karte der Vorlage ist 300 px hoch (`HeatOverview.tsx:205`).
                Balkenbild(stuecke: herkunft(r), hoehe: 240)
            } else {
                Leer(satz: "Für diesen Zeitraum liegen keine Werte vor.")
            }
        }
    }

    private func kostenkarte(_ b: HeatBalanceOut) -> some View {
        Karte(kicker: "Was die Wärme gekostet hat") {
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(Waermeuebersicht.kostenkernzahl(b.cost))
                VStack(spacing: 0) {
                    ForEach(Waermeuebersicht.kostenzeilen(b.cost)) { z in
                        Zeile(wort: z.wort, wert: z.wert)
                    }
                }
                hinweis(b.cost?.cheaperDe)
            }
        }
    }

    private func taktkarte(_ c: CyclingStats) -> some View {
        Karte(kicker: "Taktung", beiwerk: beiwerk(Waermeuebersicht.taktkopf(c))) {
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(
                    Kennzahl(
                        wort: "Starts je Tag",
                        wert: Formate.zahl(c.startsPerDay, stellen: 1)),
                    // Ohne Urteil steht „zu wenig Daten“ und nicht nichts
                    // (`HeatOverview.tsx:232`).
                    rechts: Waermeuebersicht.taktwort(c)
                )
                zweispaltig(Waermeuebersicht.taktzeilen(c))
                hinweis(c.noteDe)
            }
        }
    }

    /// **Dieselbe Zahl wie auf „Geld“: eine Rechnung, an zwei Stellen gezeigt** - und darum
    /// unten die zwei Verweise auf die Stelle, die sie rechnet (`HeatOverview.tsx:263-272`).
    private func schiebekarte(_ s: ShiftReportOut?, z: Zeitraum, tag: Bool) -> some View {
        let k = Waermeuebersicht.schieben(s)
        return Karte(kicker: "Hat sich das Verschieben gelohnt?", beiwerk: beiwerk("geschätzt")) {
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(Kennzahl(wort: k.bedeutung, wert: k.kernzahl))
                if !k.zeilen.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(k.zeilen) { z in Zeile(wort: z.wort, wert: z.wert) }
                    }
                }
                hinweis(k.hinweis)
                Spacer(minLength: 0)
                verweise(z: z, tag: tag)
            }
        }
    }

    private func ofenkarte(_ o: StoveOut) -> some View {
        Karte(kicker: "Pelletofen", beiwerk: beiwerk(Waermeuebersicht.ofenkopf(o))) {
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(
                    Kennzahl(
                        wort: "Laufzeit",
                        wert: Waermeuebersicht.dauer(minuten: o.runningMinutes)))
                zweispaltig(Waermeuebersicht.ofenzeilen(o))
                ofenstufen(o)
                ForEach(
                    [o.noteDe, Waermeuebersicht.ofenbrennstoffsatz(o)].compactMap { $0 },
                    id: \.self
                ) { satz in
                    hinweis(satz)
                }
            }
        }
    }

    @ViewBuilder private func ofenstufen(_ o: StoveOut) -> some View {
        let stufen = Waermeuebersicht.ofenstufen(o)
        if !stufen.isEmpty {
            Umbruchzeile(abstand: 12, zeilenabstand: 4) {
                Text("Leistungsstufen:").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                ForEach(Array(stufen.enumerated()), id: \.offset) { _, s in
                    Text("\(s.stufe): \(s.dauer)")
                        .font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                }
            }
        }
    }

    /// **Nur zeigen, wenn es etwas zu zeigen gibt:** eine Karte, die jeden Tag „null“ sagt,
    /// liest nach einer Woche niemand mehr (`HeatOverview.tsx:308-309`).
    private func fensterkarte(_ l: VentilationOut) -> some View {
        Karte(
            kicker: "Bei offenem Fenster",
            beiwerk: beiwerk("geschätzt, nach offenen Heizkreisen verteilt")
        ) {
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(
                    Kennzahl(
                        wort: "kWh in Räume mit offenem Fenster",
                        wert: Formate.zahl(l.kwh, stellen: 1)),
                    rechts: Waermeuebersicht.fensterkopf(l)
                )
                if !l.rooms.isEmpty {
                    Fenstertabelle(raeume: l.rooms)
                }
                hinweis(l.noteDe)
            }
        }
    }

    /// Die Bilanz des Puffers: was hineinging, was herauskam, und was sich nicht erklaeren laesst.
    ///
    /// Die letzte Zeile ist die wichtigste und der Grund, warum diese Karte bleibt, obwohl die
    /// Vorlage sie nicht hat (Begründung im Kopf der Datei). Ein Puffer, dessen Gewinn sich zu
    /// einem Drittel nicht erklaeren laesst, hat entweder einen Fuehler, der luegt, oder eine
    /// Waermequelle, die niemand kennt.
    private func pufferbilanz(_ b: BufferBalanceOut) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                Zeile(
                    wort: "am Anfang", wert: Formate.zahl(b.energyStartKwh, stellen: 1),
                    einheit: "kWh")
                Zeile(
                    wort: "am Ende", wert: Formate.zahl(b.energyEndKwh, stellen: 1),
                    einheit: "kWh")
                Zeile(
                    wort: "durch die Wärmepumpe", wert: Formate.zahl(b.gainWithHpKwh, stellen: 1),
                    einheit: "kWh", farbe: Farbe.waermepumpe
                )
                if b.stoveKnown == true {
                    Zeile(
                        wort: "durch den Ofen",
                        wert: Formate.zahl(b.gainWithStoveKwh, stellen: 1),
                        einheit: "kWh", farbe: Farbe.ofen
                    )
                }
                Zeile(wort: "entnommen", wert: Formate.zahl(b.dropKwh, stellen: 1), einheit: "kWh")
                Zeile(
                    wort: "nicht erklärt", wert: Formate.zahl(b.gainUnexplainedKwh, stellen: 1),
                    einheit: "kWh",
                    dazu: "Gewinn ohne bekannte Quelle",
                    farbe: (b.gainUnexplainedKwh ?? 0) > 1 ? Farbe.achtung : Farbe.text1
                )
            }
            // Der Satz des Dienstes gehört zu der Karte, deren Zahlen er einschränkt, und nicht
            // in die Methodenkarte, wo er als einer von acht Sätzen im Deckel lag.
            hinweis(b.noteDe)
        }
    }

    // MARK: - Bausteine der Karten

    /// Die große Zahl einer Karte mit ihrer Unterzeile.
    ///
    /// **Schrift in Textfarbe, wie überall.** Die Vorlage legt es am Baustein fest und schreibt
    /// die Begründung dazu (`HeatOverview.tsx:78`, umgesetzt `:82`); drei Kernzahlen dieser
    /// Seite standen farbig.
    ///
    /// **Der rechte Platz ist Mono, 11 pt, Versalien, Laufweite 0,08 em** (`:84`) - bei 11 pt
    /// sind das 0,88 pt. Er trägt das Taktungsurteil und die Fensterzeile, und beides ist eine
    /// Einordnung der Zahl links: in Sans ohne Versalien liest es sich wie ein Satzanfang.
    private func kernzahl(_ k: Kennzahl, rechts: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(k.wert)
                .font(Schrift.zahlGross)
                .foregroundStyle(Farbe.ton(k.ton))
            Text(k.wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            if let rechts {
                Spacer(minLength: 6)
                Text(rechts.uppercased())
                    .font(Schrift.mono(11))
                    .tracking(0.88)
                    .foregroundStyle(Farbe.text3)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    /// Sechs Taktzeilen und neun Ofenzeilen stehen in der Vorlage **zweispaltig**
    /// (`grid-cols-2 gap-x-4`, `HeatOverview.tsx:234, 282`). Neun Zeilen untereinander in einer
    /// Drittelkarte sind die halbe Kartenhöhe der Vorlage - und zwei Karten derselben Reihe
    /// werden so hoch wie die höchste.
    ///
    /// Gefüllt wird zeilenweise wie ein CSS-Gitter: links die geraden Plätze, rechts die
    /// ungeraden. Wer die Vorlage nebeneinander liest, liest dieselbe Reihenfolge.
    @ViewBuilder private func zweispaltig(_ zeilen: [Kennzahl]) -> some View {
        let links: [Kennzahl] = zeilen.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        let rechts: [Kennzahl] = zeilen.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        HStack(alignment: .top, spacing: 16) {
            zeilenspalte(links)
            zeilenspalte(rechts)
        }
    }

    private func zeilenspalte(_ zeilen: [Kennzahl]) -> some View {
        VStack(spacing: 0) {
            ForEach(zeilen) { z in
                Zeile(wort: z.wort, wert: z.wert)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ein Satz des Dienstes unter einer Karte.
    @ViewBuilder private func hinweis(_ satz: String?) -> some View {
        if let satz, !satz.isEmpty {
            Text(satz)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Der Untertitel rechts im Kartenkopf, 12 px in `text-3` (`ui/Card.tsx:20-29`) - nicht als
    /// `titel:` unter dem Kicker, wo er am iPad in Textfarbe und derselben Größe wie die
    /// Überschrift stünde.
    private func beiwerk(_ wort: String?) -> AnyView? {
        guard let wort, !wort.isEmpty else { return nil }
        return AnyView(
            Text(wort)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .multilineTextAlignment(.trailing)
        )
    }

    // MARK: - Die Verweise

    /// Die zwei Verweise am Fuß der Verschiebekarte (`HeatOverview.tsx:263-272`).
    ///
    /// **Der Zeitraum reist mit - auf zwei verschiedenen Wegen, und das ist kein Versehen.** Die
    /// Vorlage hängt ihn beide Male an die Adresse (`/geld?period=…&anchor=…` und
    /// `/waerme/nachbetrachtung?day=…`, `HeatOverview.tsx:264, 268`). In der App hängt ein
    /// Zeitraum am Bereich (``Wegweiser/zeitraum(jetzt:)``), und darum wird er für „Geld“ nach
    /// dem Wechsel dort eingetragen - sonst zeigte „Geld“ den Monat, den jemand dort zuletzt
    /// angesehen hat, und nicht den Tag, dessen Ersparnis man gerade liest.
    ///
    /// **Für den Rückblick wäre genau das falsch**, und zwar doppelt. `/waerme/nachbetrachtung`
    /// liegt im Bereich ``Bereich/Schluessel/technik`` (``Bereiche/bereichVon(_:)``): ein
    /// ``Wegweiser/setzeZeitraum(_:)`` schriebe den Wärmetag in den Technikzeitraum und
    /// verstellte damit still „Heizkreise“ - während der Reiter „Fahrplan“ selbst keinen
    /// Zeitraum führt (`Bereiche.swift`, kein `mitZeitraum`) und die Eintragung dort weder zu
    /// sehen noch zurückzunehmen wäre. Und die Rückblickseite liest den Zeitraum des Wegweisers
    /// gar nicht: ihr Tag kommt aus der Adresse. Der Tag reist deshalb dort, wo er hingehört -
    /// in der Adresse, wie es ``NachbetrachtungSeite`` und ``WiedergabeSeite`` untereinander
    /// schon halten.
    ///
    /// „Fahrplan gegen Wirklichkeit“ gibt es nur je Tag: eine Nachbetrachtung einer Woche gibt
    /// es nicht.
    @ViewBuilder private func verweise(z: Zeitraum, tag: Bool) -> some View {
        Umbruchzeile(abstand: 18, zeilenabstand: 4) {
            verweis("Rechnung und Annahmen ›", nach: "/geld", zeitraum: z)
            if tag {
                verweis(
                    "Fahrplan gegen Wirklichkeit ›",
                    nach: "/waerme/nachbetrachtung?day=\(z.anker)", zeitraum: nil)
            }
        }
    }

    /// `zeitraum` ist der Zeitraum, der im Zielbereich eingetragen werden soll - oder `nil`, wo
    /// das Ziel seinen Tag aus der Adresse nimmt. Der Grund steht an ``verweise(z:tag:)``.
    private func verweis(_ wort: String, nach weg: String, zeitraum z: Zeitraum?) -> some View {
        Button {
            wegweiser.gehe(weg)
            if let z { wegweiser.setzeZeitraum(z) }
        } label: {
            Text(wort).font(Schrift.klein).foregroundStyle(Farbe.amber)
        }
        .buttonStyle(.plain)
    }

    /// Der Verweis auf die Annahmen (`HeatOverview.tsx:374-376`).
    ///
    /// **Er steht über der Methodenkarte und nicht in ihr.** ``Methode`` nimmt Sätze und keine
    /// Ansichten, und sie ist das gemeinsame Gerippe von dreizehn Berichtsseiten - ihr eine
    /// Stelle für einen Verweis einzubauen ist eine Entscheidung über alle dreizehn. Der Satz,
    /// zu dem er gehört, steht in ``Waermeuebersicht/annahmensatz(_:)``: „Wer diese Werte unter
    /// Annahmen ändert, ändert jede Zahl auf dieser Seite, auch die vergangener Jahre.“
    private var annahmenverweis: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                wegweiser.gehe("/waerme/annahmen")
            } label: {
                Text("Annahmen ›").font(Schrift.klein).foregroundStyle(Farbe.amber)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Die Balkenbilder

    private func erzeuger(_ b: HeatBalanceOut) -> [Balkenbild.Stueck] {
        [
            .init(
                name: "Wärmepumpe", farbe: Farbe.waermepumpe,
                werte: b.buckets.map { ($0.labelDe, $0.heatPumpKwh ?? 0) }),
            .init(
                name: "Ofen (Wasser)", farbe: Farbe.ofen,
                werte: b.buckets.map { ($0.labelDe, $0.stoveWaterKwh ?? 0) }),
            // Halbtransparentes Ofenbraun statt einer eigenen Farbe: derselbe Erzeuger, ein
            // anderer Weg (`HeatOverview.tsx:44-45`).
            .init(
                name: "Ofen (Raum)", farbe: Farbe.ofen.opacity(0.55),
                werte: b.buckets.map { ($0.labelDe, $0.stoveRoomKwh ?? 0) }),
        ]
    }

    private func herkunft(_ r: HeatReportOut) -> [Balkenbild.Stueck] {
        // `EnergyBucketOut` heisst das Wort `label` und nicht `labelDe` - anders als
        // `HeatBucketOut` zwei Funktionen weiter oben. Zwei Modelle, zwei Namen fuer dasselbe.
        let b = r.summary.buckets
        return [
            .init(
                name: "aus PV", farbe: Farbe.pv,
                werte: b.map { ($0.label, $0.totals.heatPumpPvKwh ?? 0) }),
            .init(
                name: "aus Batterie", farbe: Farbe.batterie,
                werte: b.map { ($0.label, $0.totals.heatPumpBatteryKwh ?? 0) }),
            .init(
                name: "aus Netz", farbe: Farbe.netzBezug,
                werte: b.map { ($0.label, $0.totals.heatPumpGridKwh ?? 0) }),
        ]
    }
}

/// Die Räume mit offenem Fenster - am Telefon eine andere Gestalt, nicht dieselbe in einer
/// Spalte.
///
/// **`handy.css` schreibt diese Tabelle eigens um** (`:305-306, 340-347`): `thead` weg, jede
/// Zeile ein Block, oben links der Raumname und oben rechts die Wärme, darunter die beiden
/// Dauern - und die Spaltennamen hängen als `::after` an der Zelle („ offen“, „ davon
/// geheizt“). In SwiftUI gehören sie in den Text der Zelle; eine Erzeugung des Browsers gibt es
/// hier nicht. Die App zeigte stattdessen ``Tabelle`` mit Spaltenumschalter: am Telefon eine
/// Spalte und ein Schalter für drei Zahlen, die zusammengehören.
///
/// Am iPad bleibt ``Tabelle``, mit der Einheit in jeder Zelle - das macht die Vorlage dort auch
/// (`HeatOverview.tsx:334`).
private struct Fenstertabelle: View {
    let raeume: [VentilationRoomOut]

    @Environment(\.horizontalSizeClass) private var breite

    var body: some View {
        if breite == .compact {
            bloecke
        } else {
            tabelle
        }
    }

    private var tabelle: some View {
        Tabelle(
            zeilennamen: raeume.map(\.name),
            spalten: [
                .init(name: "Fenster offen", zellen: raeume.map { "\($0.openMinutes) min" }),
                .init(name: "davon geheizt", zellen: raeume.map { "\($0.heatingMinutes) min" }),
                .init(name: "Wärme", zellen: raeume.map { Formate.kwh($0.kwh) }),
            ]
        )
    }

    private var bloecke: some View {
        VStack(spacing: 0) {
            ForEach(Array(raeume.enumerated()), id: \.offset) { stelle, r in
                if stelle > 0 { Divider().overlay(Farbe.linie1) }
                block(r)
            }
        }
    }

    private func block(_ r: VentilationRoomOut) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(r.name).font(Schrift.sans(15)).foregroundStyle(Farbe.text1)
                Spacer(minLength: 8)
                Text(Formate.kwh(r.kwh)).font(Schrift.mono(16)).foregroundStyle(Farbe.text1)
            }
            Text("\(r.openMinutes) min offen · \(r.heatingMinutes) min davon geheizt")
                .font(Schrift.sans(13))
                .foregroundStyle(Farbe.text3)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
