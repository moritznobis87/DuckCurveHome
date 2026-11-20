import Charts
import DuckCurveKit
import SwiftUI

/// Alles, was die Stromseite braucht - in einem Rutsch geholt.
///
/// **Fünf Antworten, nicht eine.** Neben den Zahlen der gewählten Spanne laufen die vier
/// Spannen des Überblicksstreifens; der hängt nur am Anker, nicht an der Spanne
/// (`useReport.ts:55-77`). Scheitert eine der vier, fehlt ihre Spalte und die Seite bleibt
/// stehen.
struct Stromdaten: Sendable {
    let bericht: EnergySummaryOut
    /// Tag, Woche, Monat und Jahr desselben Ankertags - soweit sie geantwortet haben.
    let jeSpanne: [Spanne: EnergySummaryOut]
}

/// Strom: was verbraucht wurde, wer es verbraucht hat, und woher es kam.
///
/// **Die fuehrende Zahl ist der Verbrauch.** Hier stand die Autarkie, mit der Begruendung, die
/// Erzeugung sei die falsche fuehrende Zahl - das stimmt, aber die Vorlage stellt auch nicht die
/// Erzeugung voran, sondern den Verbrauch (`reports/HouseReport.tsx:45`). Der Unterschied ist
/// nicht Geschmack: „59,2 kWh, davon die Waermepumpe 49 Prozent“ ist der Anfang jeder Frage, die
/// man an diese Seite hat. Die Autarkie ist eine Folge davon und steht als fuenfte Kachel.
///
/// **Was gerechnet wird, steht im Kern** (``Stromuebersicht``): die sechs Kennzahlen mit ihren
/// Hinweisen, die Reihen und Rundungen der beiden Balkenbilder, die Ablesung eines Stapels und
/// die vier Zeilen des Überblicksstreifens. Hier bleibt die Anordnung.
///
/// **Was hier nicht mehr steht:** „aus der Sonne“, „eingespeist“ und „Eigenverbrauch“. Das sind
/// Zahlen der Erzeugung, und die haben ihren eigenen Reiter (``PvSeite``). „aus der Sonne“
/// (6,9 kWh Erzeugung) stand ausserdem dicht neben den 6,6 kWh der Autarkiezeile, die etwas
/// ganz anderes sind - Sonne und Speicher, die ins Haus gingen.
///
/// **Der Reiterkicker steht jetzt im Gerippe.** „Verbrauch · Verbraucher · Herkunft“
/// (`HouseReport.tsx:42`, gezeichnet `AreaNav.tsx:96`) fehlte hier, und eine Stelle dafür war
/// eine Entscheidung über alle achtundzwanzig Seiten - gefallen ist sie in ``Seite``, die ihn
/// aus ``Bereiche/kicker(fuer:)`` liest. Das Wort bleibt ``Stromuebersicht/seitenkicker``; der
/// Reiter `/strom` zeigt dorthin.
struct StromSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Berichtsseite { z, api in
            try await Self.hole(z, api: api)
        } inhalt: { d in
            inhalt(d)
        }
    }

    /// **Die vier Spannen laufen neben der gewaehlten**, mit `try?` je Spanne und nicht für
    /// alle vier zusammen: eine fehlende Spalte ist besser als eine Seite, die an ihr scheitert
    /// (`useReport.ts:55-77`).
    private static func hole(_ z: Zeitraum, api: Api) async throws -> Stromdaten {
        async let spannen = Pvbild.jeSpanne { s in
            try? await api.energieUebersicht(s.rawValue, anker: z.anker)
        }
        let bericht = try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
        return Stromdaten(bericht: bericht, jeSpanne: await spannen)
    }

    @ViewBuilder private func inhalt(_ d: Stromdaten) -> some View {
        // Ohne Ueberschrift: der aktive Reiter sagt, wo man ist (`ReportShell.tsx:99`).
        Kachelfeld(
            kacheln: kacheln(d.bericht),
            // **Drei Spalten am iPad, zwei am Telefon.** Die Vorlage setzt die sechs in *eine*
            // Reihe (`KpiGrid cols={6}`, `globals.css:107`); auf 1180 Punkten blieben davon
            // 186 je Kachel, und „52,6 kWh · Rechnungen prüfen“ bricht dort dreimal um. Zwei
            // Reihen zu drei sind der nächste Schritt, der die beiden Diagramme nicht unter
            // den Rand schiebt - bei zwei Spalten wären es drei Reihen (`handy.css:196` hält
            // am Telefon ohnehin zwei fest).
            spalten: schmal ? 2 : 3
        )
        diagrammreihe(d.bericht)
        Spannenstreifen(
            titel: Stromuebersicht.ueberblickstitel,
            zeilen: Stromuebersicht.spannenzeilen(d.jeSpanne),
            anker: d.bericht.anchor,
            jetzt: haus.jetzt
        )
        // Erst der Satz, der dieser Seite allein gehoert, dann der Hinweis des Dienstes
        // (`ReportShell.tsx:169-172`). Die Abdeckung steht in der Kurzzeile und nicht im Rumpf:
        // sie schraenkt jede Zahl dieser Seite ein, und zugeklappt waere sie verschwiegen.
        Methode(
            [Stromuebersicht.methodensatz, d.bericht.meta.estimatedNoteDe],
            kurz: Wallbox.abdeckung(d.bericht.meta),
            // **Der Titel der Vorlage ist „Wie gerechnet wird“** (`ui/Methode.tsx:18`), nicht
            // „Wie das gerechnet ist“. Er steht hier an der Karte und nicht als neue Vorgabe
            // in ``Methode``: die Vorgabe gilt für alle dreizehn Berichtsseiten, und das ist
            // ein Zug über alle dreizehn, nicht über diese eine.
            titel: "Wie gerechnet wird"
        )
    }

    // MARK: - Die sechs Kacheln

    /// **Die Farbe der Netzbezugskachel ist die einzige, die hier und nicht im Kern fällt.**
    /// ``Streifenzeile`` und ``Kennzahl`` tragen einen ``Kennzahl/Ton``, und dem fehlt der Wert
    /// für `--alert` #E0533D (`HouseReport.tsx:54`: `tone="ember"`). Der nächstliegende
    /// vorhandene Ton wäre `glut` #E0966B - und das ist auf *dieser* Seite die Farbe der
    /// Wärmepumpenkachel zwei Plätze weiter links. Zwei Kacheln in derselben Farbe für
    /// Verschiedenes wären schlechter als diese eine Zeile hier.
    private func kacheln(_ b: EnergySummaryOut) -> [Kacheldaten] {
        Stromuebersicht.kacheln(b, hausherr: haus.darfSchalten).map { k in
            var daten = Kacheldaten(k)
            if k.wort == Stromuebersicht.netzbezugswort {
                daten.farbe = Farbe.alarm
                daten.weg = Stromuebersicht.weg(k.wort, hausherr: haus.darfSchalten)
            }
            return daten
        }
    }

    // MARK: - Die zwei Diagrammkarten

    /// **Nebeneinander, und das ist gesetzt.** Die Vorlage stellt die beiden Fragen in eine
    /// Reihe zu zwei gleichen Spalten (`HouseReport.tsx:62`, `globals.css:108`) - „zwei Fragen
    /// nebeneinander, jede als Verlauf“; daneben stand je ein Ring mit denselben Anteilen, die
    /// schon in den Kacheln und im Verlauf stehen, und der ist absichtlich weg, nicht vergessen
    /// (`HouseReport.tsx:60-61`). An der Wand ist das der Unterschied zwischen einem Vergleich
    /// und zwei Bildern. Am Telefon stehen sie untereinander (`globals.css:350`).
    @ViewBuilder private func diagrammreihe(_ b: EnergySummaryOut) -> some View {
        LazyVGrid(columns: spalten, alignment: .leading, spacing: 12) {
            verbrauchskarte(b)
            herkunftskarte(b)
        }
    }

    /// Zwei gleiche Spalten am iPad, eine am Telefon - `1fr 1fr` gegen einspaltig.
    ///
    /// `LazyVGrid` und nicht `ViewThatFits`: das zweite braucht fertige Entwürfe und wählt
    /// nach Höhe, nicht nach Breite. Vorbild ist ``HausSeite`` und die PV-Seite daneben.
    private var spalten: [GridItem] {
        schmal
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    }

    private func verbrauchskarte(_ b: EnergySummaryOut) -> some View {
        Karte(kicker: Stromuebersicht.verbrauchstitel) {
            // Die Legende steht unter dem Kartenkopf und nicht in ihm: ``Karte`` setzt ihr
            // `beiwerk` am Telefon neben den Kicker, und für drei Farbflecke mit Namen ist
            // dort kein Platz. Umbrechen muss sie in jedem Fall - „damit eine Legende
            // umbricht statt zu verschwinden“ (`Card.tsx:24-26`).
            Diagrammlegende(stuecke: Strombalkenbild.verbraucher)
            Strombalkenbild(
                balken: Stromuebersicht.verbrauch(b),
                reihen: Strombalkenbild.verbraucher,
                hoehe: bildhoehe
            )
        }
    }

    private func herkunftskarte(_ b: EnergySummaryOut) -> some View {
        Karte(kicker: Stromuebersicht.herkunftstitel) {
            Diagrammlegende(stuecke: Strombalkenbild.herkunft)
            Strombalkenbild(
                balken: Stromuebersicht.herkunft(b),
                reihen: Strombalkenbild.herkunft,
                hoehe: bildhoehe
            )
        }
    }

    /// 220 Punkte: die Karte der Vorlage ist 280 Pixel hoch, davon gehen Rand, Kopfzeile und
    /// Legende ab (`HouseReport.tsx:63,67`).
    private var bildhoehe: CGFloat { 220 }
}

/// Photovoltaik: was die Anlage erzeugt hat, was daraus wurde, und was morgen kommt.
///
/// **Die Seite ist keine Rückschau.** Ihr Reiter heißt „Erzeugung · Verwendung · Prognose“
/// (`PvReport.tsx:77`), und der dritte Teil ist die Karte „Heute und morgen“: die gemessene
/// Leistung gegen die erwartete auf einer Achse über achtundvierzig Stunden. Ohne sie steht
/// auf der Seite nur, was gewesen ist.
///
/// **Drei Felder folgen dem Anker nicht**, und das steht daneben. Die zwei Prognosekacheln und
/// die Vorschaukurve kommen aus dem laufenden Plan; der kennt heute und morgen, und für einen
/// vergangenen Tag gibt es keine Vorhersage mehr. Blättert man zurück, folgt der Rest der Seite
/// dem gewählten Tag, diese drei nicht - und genau das muss dastehen, sonst liest man sie als
/// Prognose des gewählten Tages (`PvReport.tsx:92-95`).
///
/// **Was hier nicht mehr steht:** die Kacheln „direkt verbraucht“ und „in den Speicher“. Beide
/// sind in der Vorlage die zwei ersten Reihen des Balkenbilds, und ihre Summe ist der
/// Eigenverbrauch der zweiten Kachel - an der Wand stand dieselbe Größe damit dreimal.
struct PvSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Berichtsseite { z, api in
            // Die vier Spannen laufen neben der gewaehlten: eine fehlende Spalte ist besser
            // als eine Seite, die an ihr scheitert (`useReport.ts:55-77`).
            async let spannen = Pvbild.jeSpanne { s in
                try? await api.energieUebersicht(s.rawValue, anker: z.anker)
            }
            let bericht = try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
            return (bericht: bericht, jeSpanne: await spannen)
        } inhalt: { d in
            inhalt(d.bericht, jeSpanne: d.jeSpanne)
        }
    }

    /// **Plan und Minutenwerte werden nicht erneut geholt.** Beide liegen im Hauszustand
    /// (`Hauszustand.ersteLadung()` holt sie nach jeder Verbindung) und gehoeren nicht zum
    /// Zeitraum dieser Seite. Haengte die Vorschau an der Abfrage der Berichtsseite, wuerde sie
    /// bei jedem Blaettern neu geholt - und saehe danach aus wie die Prognose des gewaehlten
    /// Tages, die es nicht gibt.
    @ViewBuilder private func inhalt(
        _ b: EnergySummaryOut, jeSpanne: [Spanne: EnergySummaryOut]
    ) -> some View {
        let jetzt = haus.jetzt
        let istHeute = b.anchor == Tag.iso(jetzt)
        let tagesbeginn = Kalender.haus.startOfDay(for: jetzt)
        let prognose = Pvbild.prognose(haus.plan, tagesbeginn: tagesbeginn)

        if haus.darfSchalten {
            abrechnungsverweis
        }
        // Ohne Ueberschrift: der aktive Reiter sagt, wo man ist (`ReportShell.tsx:99`).
        Kachelfeld(
            kacheln: Pvbild.kacheln(b, prognose: prognose, istHeute: istHeute)
                .map(Kacheldaten.init),
            // **Drei Spalten am iPad, zwei am Telefon.** Die Vorlage setzt sechs in eine Reihe
            // (`KpiGrid cols={6}`); auf 1180 Punkten blieben davon 186 je Kachel, und „Erlös
            // 0,32 € bei 8,2 ct“ bricht dort dreimal um. Zwei Reihen zu drei sind der nächste
            // Schritt, der die Diagramme nicht unter den Rand schiebt - bei zwei Spalten wären
            // es drei Reihen (`handy.css:196` hält am Telefon ohnehin zwei fest).
            spalten: schmal ? 2 : 3
        )
        diagrammreihe(b, prognose: prognose, istHeute: istHeute, tagesbeginn: tagesbeginn)
        Spannenstreifen(
            titel: "PV im Überblick",
            zeilen: Pvbild.spannenzeilen(jeSpanne),
            anker: b.anchor,
            jetzt: jetzt
        )
        // Erst der Satz, der die zusammengesetzte Ersparnis erklaert, dann der Hinweis des
        // Dienstes (`ReportShell.tsx:169-172`). Die Abdeckung steht in der Kurzzeile und nicht
        // im Rumpf: sie schraenkt jede Zahl dieser Seite ein, und zugeklappt waere sie
        // verschwiegen.
        Methode(
            [Pvbild.ersparnissatz, b.meta.estimatedNoteDe],
            kurz: Wallbox.abdeckung(b.meta)
        )
    }

    /// Der Weg zur Abrechnung, den nur der Hausherr sieht.
    ///
    /// **Gästen wird der Weg gar nicht erst gezeigt: die Abrechnung ist ihnen verschlossen**
    /// (`PvReport.tsx:83-84`).
    ///
    /// **Er steht hier und nicht in der Kopfzeile**, anders als in der Vorlage. Die Kopfzeile
    /// ist das gemeinsame Gerippe aller dreizehn Berichtsseiten und hat keine Stelle für ein
    /// Beiwerk; eine dort einzubauen ist eine Entscheidung über alle dreizehn. Am Telefon
    /// rutscht der Verweis in der Vorlage ohnehin in eine eigene Zeile unter den Zeitraum
    /// (`handy.css:149`) - also genau dorthin, wo er hier steht.
    private var abrechnungsverweis: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                wegweiser.gehe("/geld/pv-abrechnung")
            } label: {
                Text("Abrechnung →").font(Schrift.klein).foregroundStyle(Farbe.amber)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Die zwei Diagrammkarten

    /// **Nebeneinander, und das ist gesetzt.** Die Vorlage stellt Verwendung und Vorschau in
    /// eine Reihe zu zwei gleichen Spalten (`PvReport.tsx:101`, `globals.css:108`); neben der
    /// Verwendung stand einmal ein Ring mit denselben drei Anteilen, die in den Kacheln darüber
    /// stehen, und der ist absichtlich weg, nicht vergessen (`PvReport.tsx:99-100`). Am Telefon
    /// stehen die beiden untereinander (`globals.css:350`).
    @ViewBuilder private func diagrammreihe(
        _ b: EnergySummaryOut, prognose: Pvbild.Prognose, istHeute: Bool, tagesbeginn: Date
    ) -> some View {
        LazyVGrid(columns: spalten, alignment: .leading, spacing: 12) {
            verwendungskarte(b)
            vorschaukarte(istHeute: istHeute, tagesbeginn: tagesbeginn)
        }
    }

    /// Zwei gleiche Spalten am iPad, eine am Telefon - `1fr 1fr` gegen einspaltig.
    private var spalten: [GridItem] {
        schmal
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    }

    private func verwendungskarte(_ b: EnergySummaryOut) -> some View {
        Karte(kicker: "Erzeugung und Verwendung") {
            // Die Legende steht unter dem Kartenkopf und nicht in ihm: ``Karte`` setzt ihr
            // `beiwerk` am Telefon neben den Kicker, und für drei Farbflecke mit Namen ist
            // dort kein Platz. Umbrechen muss sie in jedem Fall - „damit eine Legende
            // umbricht statt zu verschwinden“ (`Card.tsx:24-26`).
            Diagrammlegende(stuecke: Pvverwendungsbild.legende)
            Pvverwendungsbild(balken: Pvbild.verwendung(b), hoehe: bildhoehe)
        }
    }

    private func vorschaukarte(istHeute: Bool, tagesbeginn: Date) -> some View {
        Karte(
            // „Heute und morgen“ nur, wenn der Anker heute ist; sonst sagt der Titel selbst,
            // dass hier eine Prognose steht und kein gewählter Tag (`PvReport.tsx:107`).
            kicker: istHeute ? "Heute und morgen" : "Prognose heute und morgen",
            beiwerk: AnyView(prognosegueteverweis)
        ) {
            Pvtageskurve(
                bild: Pvbild.tagundmorgen(
                    raster: istrohdaten, plan: haus.plan, tagesbeginn: tagesbeginn
                ),
                jetzt: haus.jetzt,
                hoehe: bildhoehe
            )
        }
    }

    /// Die Minutenwerte, aber nur wenn sie vom laufenden Tag sind.
    ///
    /// Der Hauszustand kann auf einen anderen Tag umgeladen sein, weil die Startseite durch die
    /// Tage blättert (`Hauszustand.ladeTag(_:)`). Die Vorschau zeigt immer heute; ein Raster
    /// von vorgestern in dieses Bild zu legen hieße, eine Messung an eine Stelle zu setzen, an
    /// die sie nicht gehört.
    private var istrohdaten: [Verlaufspunkt] {
        haus.raster.tag == haus.heute ? haus.raster.punkte : []
    }

    /// 240 Punkte: die Karte der Vorlage ist 300 Pixel hoch, davon gehen Rand und Kopfzeile ab
    /// (`PvReport.tsx:102,106`).
    private var bildhoehe: CGFloat { 240 }

    private var prognosegueteverweis: some View {
        Button {
            wegweiser.gehe("/system")
        } label: {
            Text("Prognosegüte →").font(Schrift.winzig).foregroundStyle(Farbe.amber)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Das Bild beider Diagrammkarten

/// Gestapelte Balken je Zeitabschnitt, ablesbar - das Bild beider Diagrammkarten von /strom.
///
/// **Warum nicht ``Balkenbild``.** Das gemeinsame Gerippe zeichnet dasselbe Bild, aber ohne
/// Zeiger und mit der Legende *im* Diagramm. Die Vorlage tut beides anders, und zwar mit
/// Begründung: die Legende steht im Kartenkopf, weil „die Identität der Flächen sonst allein in
/// der Farbe liegt und wer die Reihenfolge nicht kennt, raten muss“
/// (`ReportShell.tsx:187-190`), und der Wert eines Balkens ist ablesbar, weil er an einem
/// Monatsbild mit dreißig Balken sonst verloren ist (`charts.ts:58-73`). Hier steht deshalb die
/// Fassung dieser Seite; ``Balkenbild`` bleibt, wie es ist, und seine übrigen Aufrufer bleiben
/// verschont.
///
/// **Die Reihen kommen von außen**, weil die Seite zwei Bilder derselben Gestalt über zwei
/// verschiedenen Reihensätzen zeigt: „Wer hat verbraucht?“ und „Woher kam der Strom?“
/// (`HouseReport.tsx:62-71`). Welche Reihen das sind, welche Wörter sie tragen und welche Farben
/// sie haben, steht im Kern (``Stromuebersicht/Verbraucher`` und ``Stromuebersicht/Herkunft``)
/// und ist dort gegen `palette.ts` geprüft.
///
/// **Warum hier und nicht unter `Diagramme/`.** Das Xcode-Projekt liegt erzeugt im Repository
/// und zählt jede Swift-Datei einzeln auf; eine neu angelegte Datei steht nicht darin und wird
/// darum stumm nicht mitgebaut - ihre Ansicht fehlt zur Laufzeit, ohne dass ein Compiler etwas
/// sagt (Kopfkommentar von `tools/xcodeproj-pruefen.py`). Sie steht deshalb bei ihrem einzigen
/// Aufrufer, in einer Datei, die schon im Build ist.
struct Strombalkenbild: View {
    let balken: [Stromuebersicht.Balken]
    /// Die Reihen von unten nach oben - Wort und Farbe, wie sie auch in der Legende stehen.
    let reihen: [Legendenstueck]
    /// 220 Punkte: die Karte der Vorlage ist 280 Pixel hoch, davon gehen Rand, Kopfzeile und
    /// Legende ab (`HouseReport.tsx:63,67`).
    var hoehe: CGFloat = 220

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }

    /// Die Legende der ersten Karte (`CONSUMERS`, `HouseReport.tsx:19-23`).
    static var verbraucher: [Legendenstueck] {
        Stromuebersicht.Verbraucher.allCases.map {
            Legendenstueck(wort: $0.name, farbe: Color($0.farbe), hoehe: 8)
        }
    }

    /// Die Legende der zweiten Karte (`SOURCES`, `HouseReport.tsx:24-28`).
    static var herkunft: [Legendenstueck] {
        Stromuebersicht.Herkunft.allCases.map {
            Legendenstueck(wort: $0.name, farbe: Color($0.farbe), hoehe: 8)
        }
    }

    private var namen: [String] { reihen.map(\.wort) }

    private var achsenwoerter: [String] { balken.map(\.wort) }

    private var ablesung: Stromuebersicht.Ablesung? {
        Pvbild.balken(balken, wort: gelesen).map {
            Stromuebersicht.ablesung($0, namen: namen)
        }
    }

    var body: some View {
        if balken.isEmpty {
            Leer(satz: "Keine Werte in diesem Zeitraum.")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ablesezeile
                bild
            }
        }
    }

    /// Was unter dem Finger steht: der Abschnitt, die Reihen ungleich Null und die Summe.
    ///
    /// **Die Zeile steht über dem Bild und immer**, auch leer. Ein Streifen, der beim Antippen
    /// erscheint, schiebt das Diagramm um seine eigene Höhe nach unten, und dann liegt der
    /// Finger nicht mehr auf dem Balken, den er gewählt hat.
    @ViewBuilder private var ablesezeile: some View {
        Group {
            if let a = ablesung {
                // **Eine umbrechende Zeile und kein `HStack`.** Drei Reihennamen mit Werten
                // und dazu die Summe sind auf einer halb so breiten Karte mehr, als eine Zeile
                // trägt; abgeschnitten wäre die Ablesung nutzlos.
                Umbruchzeile(abstand: 10, zeilenabstand: 2) {
                    Text(a.wort).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                    ForEach(a.zeilen) { z in
                        zeile(z)
                    }
                    Text(a.summe).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                }
            } else {
                Text("Zum Ablesen über das Bild streichen.")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 16, alignment: .topLeading)
    }

    private func zeile(_ z: Stromuebersicht.Ablesung.Zeile) -> some View {
        HStack(spacing: 4) {
            Text(z.name).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            Text(z.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
        }
    }

    private var bild: some View {
        Chart {
            inhalt
        }
        .chartForegroundStyleScale(domain: namen, range: reihen.map(\.farbe))
        // Die Legende steht im Kartenkopf, nicht im Bild: auf 220 Punkten Höhe nimmt sie dort
        // ein Fünftel der Fläche, die dem Diagramm gehört.
        .chartLegend(.hidden)
        .chartXSelection(value: $gelesen)
        .chartYAxis { yAchse }
        .chartXAxis { xAchse }
        .frame(height: hoehe)
    }

    /// Die Balken, Reihe für Reihe von unten, und die gelesene Stelle.
    @ChartContentBuilder private var inhalt: some ChartContent {
        ForEach(balken) { b in
            ForEach(Array(reihen.enumerated()), id: \.offset) { i, r in
                BarMark(
                    x: .value("Zeit", b.wort),
                    y: .value("kWh", i < b.werte.count ? b.werte[i] : 0),
                    stacking: .standard
                )
                // **Je Reihe ein Schlüssel.** Ohne `by:` würde Swift Charts aus allen drei
                // eine machen, und der Stapel wäre eine Fläche in einer Farbe.
                .foregroundStyle(by: .value("Reihe", r.wort))
                // Nur oben gerundet, wie `borderRadius [2,2,0,0]` an der obersten Reihe
                // (`charts.ts:88`): ein Radius an jedem Abschnitt zerschneidet den Stapel.
                .cornerRadius(i == reihen.count - 1 ? 2 : 0)
            }
        }
        if let g = gelesen {
            RuleMark(x: .value("gelesen", g))
                .foregroundStyle(Farbe.text1.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }

    /// `splitNumber: 3` wie in der Vorlage (`charts.ts:76`): eine Achse mit sechs Stufen liest
    /// auf einer halbbreiten Karte niemand, und der Platz links gehört dem Bild.
    @AxisContentBuilder private var yAchse: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 0))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    /// **Nicht jede Beschriftung, sondern die, die passen.** Bei einem Monat sind es dreißig
    /// Wörter, und auf einer halben Kartenbreite ist das ein Ziffernstreifen (`charts.ts:75`:
    /// `interval: "auto"` ab mehr als zwölf Buckets).
    @AxisContentBuilder private var xAchse: some AxisContent {
        AxisMarks(values: Achse.beschriftungen(achsenwoerter, hoechstens: schmal ? 6 : 8)) {
            wert in
            AxisValueLabel {
                if let s = wert.as(String.self) {
                    Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}
