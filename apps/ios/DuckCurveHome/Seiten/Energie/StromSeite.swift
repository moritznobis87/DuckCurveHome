import DuckCurveKit
import SwiftUI

/// Strom: was verbraucht wurde, wer es verbraucht hat, und woher es kam.
///
/// **Die fuehrende Zahl ist der Verbrauch.** Hier stand die Autarkie, mit der Begruendung, die
/// Erzeugung sei die falsche fuehrende Zahl - das stimmt, aber die Vorlage stellt auch nicht die
/// Erzeugung voran, sondern den Verbrauch (`reports/HouseReport.tsx:45`). Der Unterschied ist
/// nicht Geschmack: „59,2 kWh, davon die Waermepumpe 49 Prozent" ist der Anfang jeder Frage, die
/// man an diese Seite hat. Die Autarkie ist eine Folge davon und steht als fuenfte Kachel.
///
/// **Was hier nicht mehr steht:** „aus der Sonne", „eingespeist" und „Eigenverbrauch". Das sind
/// Zahlen der Erzeugung, und die haben ihren eigenen Reiter (``PvSeite``). „aus der Sonne"
/// (6,9 kWh Erzeugung) stand ausserdem dicht neben den 6,6 kWh der Autarkiezeile, die etwas
/// ganz anderes sind - Sonne und Speicher, die ins Haus gingen.
struct StromSeite: View {
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(Hauszustand.self) private var haus

    var body: some View {
        Berichtsseite { z, api in
            try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
        } inhalt: { bericht in
            // Ohne Ueberschrift: der aktive Reiter sagt, wo man ist (`ReportShell.tsx:99`).
            Kachelfeld(kacheln: kennzahlen(bericht))
            Karte(kicker: "Wer hat verbraucht?") {
                Balkenbild(stuecke: verbrauch(bericht))
            }
            Karte(kicker: "Woher kam der Strom?") {
                Balkenbild(stuecke: herkunft(bericht))
            }
            Methode(
                [
                    "Haushalt (Rest) = Hausverbrauch ohne Wärmepumpe und Wallbox. Verbraucher erhalten die Quellen anteilig an ihrer Leistung je Minute.",
                    bericht.meta.estimatedNoteDe,
                ],
                // Die Abdeckung steht in der Kurzzeile und nicht im Rumpf: sie schränkt jede
                // Zahl dieser Seite ein, und zugeklappt wäre sie verschwiegen.
                kurz: [
                    abdeckung(bericht),
                    bericht.meta.dataSince.map { "Aufzeichnung seit \(Tag.lang(String($0.prefix(10))))" },
                ].compactMap { $0 }.joined(separator: " · ")
            )
        }
    }

    /// Wie lueckenlos die Minutenwerte des Zeitraums sind.
    ///
    /// **Sie stand nirgends.** Jede Zahl dieser Seite steht auf Minutenwerten; wo die fehlen,
    /// rechnet der Dienst mit weniger, als er zu haben scheint. Das Feld lag ungelesen im
    /// Modell.
    private func abdeckung(_ b: EnergySummaryOut) -> String? {
        guard let anteil = b.meta.coverage else { return nil }
        if anteil <= 0 { return "Noch keine Messdaten im Zeitraum" }
        return "Datenabdeckung \(Formate.prozent(anteil))"
    }

    /// Die sechs Kennzahlen der Vorlage, in ihrer Reihenfolge.
    private func kennzahlen(_ b: EnergySummaryOut) -> [Kacheldaten] {
        let t = b.totals
        let gesamt = t.houseKwh ?? 0
        return [
            Kacheldaten(
                "Verbrauch gesamt", Formate.zahl(gesamt, stellen: 1), einheit: "kWh",
                dazu: (t.minutes ?? 0) > 0
                    ? "\(Int((Double(t.minutes ?? 0) / 60).rounded())) h bewertet" : "keine Daten"
            ),
            Kacheldaten(
                "Wärmepumpe", Formate.zahl(t.heatPumpKwh ?? 0, stellen: 1), einheit: "kWh",
                dazu: anteil(t.heatPumpKwh, gesamt)
            ),
            Kacheldaten(
                "Wallbox", Formate.zahl(t.evKwh ?? 0, stellen: 1), einheit: "kWh",
                dazu: anteil(t.evKwh, gesamt), farbe: Farbe.mist
            ),
            Kacheldaten(
                "Haushalt (Rest)", Formate.zahl(t.baseKwh ?? 0, stellen: 1), einheit: "kWh",
                dazu: anteil(t.baseKwh, gesamt), farbe: Farbe.text3
            ),
            Kacheldaten(
                "Autarkie", Formate.prozent(t.autarky),
                // Eine Zahl, kein Erklaersatz: wie viele Kilowattstunden ohne das Netz
                // auskamen. Der Satz stand davor und sagte nur, was das Wort schon sagt.
                dazu: "\(Formate.zahl((t.pvDirectKwh ?? 0) + (t.batteryToHouseKwh ?? 0), stellen: 1)) kWh ohne Netz",
                farbe: Farbe.amber
            ),
            // **Kosten sehen alle; nur der Weg zur Rechnungspruefung bleibt dem Hausherrn**
            // (`HouseReport.tsx:50`).
            Kacheldaten(
                "Netzbezug", Formate.euro(t.importCostEur),
                dazu: netzzeile(t), farbe: Farbe.alarm,
                weg: darfPruefen ? "/geld/rechnungen" : nil
            ),
        ]
    }

    private var darfPruefen: Bool { haus.darfSchalten }

    private func netzzeile(_ t: EnergyTotalsOut) -> String {
        let kwh = "\(Formate.zahl(t.importKwh ?? 0, stellen: 1)) kWh"
        return darfPruefen ? "\(kwh) · Rechnungen prüfen" : kwh
    }

    private func anteil(_ teil: Double?, _ ganzes: Double) -> String? {
        guard let teil, ganzes > 0 else { return nil }
        return "\(Formate.prozent(teil / ganzes)) des Verbrauchs"
    }

    /// Wer verbraucht hat - in derselben Reihenfolge wie die Kacheln darueber.
    private func verbrauch(_ b: EnergySummaryOut) -> [Balkenbild.Stueck] {
        [
            Balkenbild.Stueck(
                name: "Wärmepumpe", farbe: Farbe.waermepumpe,
                werte: b.buckets.map { ($0.label, $0.totals.heatPumpKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "Wallbox", farbe: Farbe.diagrammWallbox,
                werte: b.buckets.map { ($0.label, $0.totals.evKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "Haushalt", farbe: Farbe.diagrammHaushalt,
                werte: b.buckets.map { ($0.label, $0.totals.baseKwh ?? 0) }
            ),
        ]
    }

    /// Woher der Strom kam: Sonne direkt, aus dem Speicher, aus dem Netz. Gestapelt, weil die
    /// drei sich zum Hausverbrauch addieren.
    private func herkunft(_ b: EnergySummaryOut) -> [Balkenbild.Stueck] {
        [
            Balkenbild.Stueck(
                name: "Sonne direkt", farbe: Farbe.pv,
                werte: b.buckets.map { ($0.label, $0.totals.pvDirectKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "aus dem Speicher", farbe: Farbe.diagrammSpeicher,
                werte: b.buckets.map { ($0.label, $0.totals.batteryToHouseKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "aus dem Netz", farbe: Farbe.diagrammNetz,
                werte: b.buckets.map { ($0.label, $0.totals.gridToHouseKwh ?? 0) }
            ),
        ]
    }
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
/// Speicher: Ladung, Entladung und woher die Ladung kam.
///
/// **Die Herkunft der Ladung ist die eigentliche Frage.** Ein Speicher, der nachts aus dem Netz
/// laedt, verschiebt Kosten statt sie zu sparen - und ob er das tut, steht in
/// `grid_to_battery_dark_kwh`.
struct SpeicherSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            // Zwei Antworten: die Zahlen, und der Pruefbericht dazu. Der ist reiner Text - er
            // haelt den gemeldeten Ladestand gegen Hausverbrauch und Leistung und sagt, wo es
            // nicht aufgeht. Eine Datenstruktur waere er nicht, er ist eine Antwort zum Lesen.
            async let zahlen = api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
            async let pruefung = try? api.speicherPruefung(z.spanne.rawValue, anker: z.anker)
            return try await (zahlen: zahlen, pruefung: pruefung)
        } inhalt: { paar in
            let b = paar.zahlen
            Kachelfeld(kacheln: kennzahlen(b), kicker: "Speicher")
            Karte(kicker: "Woher die Ladung kam") {
                Balkenbild(stuecke: [
                    .init(
                        name: "aus der Sonne", farbe: Farbe.pv,
                        werte: b.buckets.map { ($0.label, $0.totals.pvToBatteryKwh ?? 0) }
                    ),
                    .init(
                        name: "aus dem Netz", farbe: Farbe.netzBezug,
                        werte: b.buckets.map { ($0.label, $0.totals.gridToBatteryKwh ?? 0) }
                    ),
                ])
            }
            Karte(kicker: "Entladung") {
                Balkenbild(
                    stuecke: [
                        .init(
                            name: "ins Haus", farbe: Farbe.batterie,
                            werte: b.buckets.map { ($0.label, $0.totals.batteryToHouseKwh ?? 0) }
                        )
                    ],
                    gestapelt: false
                )
            }
            if let p = paar.pruefung, !p.isEmpty {
                Karte(kicker: "Nachgerechnet") {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(p)
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                            .textSelection(.enabled)
                    }
                }
            }
            Methode([
                b.meta.estimatedNoteDe,
                "Die Herkunft der Ladung ist gerechnet, nicht gemessen: der Speicher meldet nur, "
                    + "wie viel er genommen hat, nicht woher.",
            ])
        }
    }

    private func kennzahlen(_ b: EnergySummaryOut) -> [Kacheldaten] {
        let t = b.totals
        let dunkel = t.gridToBatteryDarkKwh ?? 0
        return [
            Kacheldaten("geladen", Formate.zahl(t.batteryChargeKwh ?? 0, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "entladen", Formate.zahl(t.batteryDischargeKwh ?? 0, stellen: 1), einheit: "kWh",
                farbe: Farbe.batterie
            ),
            Kacheldaten(
                "aus der Sonne geladen", Formate.zahl(t.pvToBatteryKwh ?? 0, stellen: 1),
                einheit: "kWh", farbe: Farbe.pv
            ),
            Kacheldaten(
                "aus dem Netz geladen", Formate.zahl(t.gridToBatteryKwh ?? 0, stellen: 1),
                einheit: "kWh",
                dazu: dunkel >= 0.05 ? "davon \(Formate.kwh(dunkel)) im Dunkeln" : nil,
                farbe: dunkel >= 0.05 ? Farbe.achtung : Farbe.text1
            ),
            Kacheldaten("Wert der Entladung", Formate.euro(t.batteryDischargeValueEur)),
            Kacheldaten(
                "unterm Strich", Formate.euro(t.batteryNetEur),
                dazu: "Entladung minus Ladekosten"
            ),
        ]
    }
}
