import DuckCurveKit
import SwiftUI

/// Kosten: was der Strom gekostet hat - und was die Verschiebung gespart hat.
///
/// **Die Ersparnis ist die eigentliche Zahl.** Der Rest ist Buchhaltung: dass Strom Geld kostet,
/// weiss der Hausherr. Was diese Anlage rechtfertigt, ist die Differenz zu einem Haus, das
/// dieselbe Waerme ohne Preisblick erzeugt hätte - und genau die rechnet der Dienst als
/// Vergleichslauf (`/energy/shift`).
struct KostenSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            // Zwei Antworten, weil es zwei Fragen sind: was es gekostet hat, und was es ohne
            // Preisblick gekostet hätte.
            async let kosten = api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
            async let verschiebung = try? api.energieVerschiebung(z.spanne.rawValue, anker: z.anker)
            return try await (kosten: kosten, verschiebung: verschiebung)
        // **Der Typ muss dastehen.** `Berichtsseite` leitet `Antwort` aus der Abfrage ab;
        // bei einem benannten Paar, dessen zweite Haelfte aus `try?` kommt, schafft der
        // Compiler das nicht mehr und meldet „cannot infer type of closure parameter“.
        } inhalt: { (paar: (kosten: EnergySummaryOut, verschiebung: ShiftReportOut?)) in
            Kachelfeld(kacheln: kennzahlen(paar.kosten, paar.verschiebung), kicker: "Geld")
            if let v = paar.verschiebung {
                Karte(kicker: "Der Vergleichslauf", titel: "Was der Preisblick gebracht hat") {
                    VStack(spacing: 0) {
                        Zeile(wort: "wirklich bezahlt", wert: Formate.euro(v.actualEur))
                        Zeile(wort: "ohne Preisblick", wert: Formate.euro(v.naiveEur))
                        Zeile(
                            wort: "gespart", wert: Formate.euro(v.savingEur),
                            farbe: v.savingEur >= 0 ? Farbe.mist : Farbe.alarm
                        )
                        if let ct = v.savingCtPerKwh {
                            Zeile(
                                wort: "je Kilowattstunde Wärmestrom",
                                wert: Formate.zahl(ct, stellen: 2), einheit: "ct"
                            )
                        }
                        Zeile(
                            wort: "verschoben", wert: Formate.zahl(v.shiftedKwh, stellen: 1),
                            einheit: "kWh"
                        )
                    }
                }
                if !v.days.isEmpty {
                    Karte(kicker: "Nach Tagen") {
                        Balkenbild(
                            stuecke: [
                                .init(
                                    name: "gespart", farbe: Farbe.mist,
                                    werte: v.days.map { ($0.day, $0.savingEur) }
                                )
                            ],
                            einheit: "€", gestapelt: false
                        )
                    }
                }
            }
            Karte(kicker: "Nach Zeitraum") {
                Balkenbild(
                    stuecke: [
                        .init(
                            name: "Bezug", farbe: Farbe.netzBezug,
                            werte: paar.kosten.buckets.map { ($0.label, $0.totals.importCostEur ?? 0) }
                        ),
                        .init(
                            name: "Einspeisevergütung", farbe: Farbe.netzEinspeisung,
                            werte: paar.kosten.buckets.map {
                                ($0.label, -($0.totals.exportRevenueEur ?? 0))
                            }
                        ),
                    ],
                    einheit: "€"
                )
            }
            // **`assumptionsDe` ist eine Reihe von Saetzen, kein Satz.** Hier stand sie
            // zwischen drei Zeichenketten, und damit wurde die Reihe `[Any]` - darauf passt
            // `[String?]` nicht. Die Annahmen werden angehaengt, nicht eingereiht.
            Methode(
                [
                    paar.verschiebung?.methodDe,
                    paar.verschiebung?.skippedDe,
                    paar.kosten.meta.estimatedNoteDe,
                ] + (paar.verschiebung?.assumptionsDe ?? []).map { Optional($0) }
            )
        }
    }

    private func kennzahlen(_ k: EnergySummaryOut, _ v: ShiftReportOut?) -> [Kacheldaten] {
        let t = k.totals
        let netto = (t.importCostEur ?? 0) - (t.exportRevenueEur ?? 0)
        var aus: [Kacheldaten] = []
        if let v {
            aus.append(
                Kacheldaten(
                    "gespart", Formate.euro(v.savingEur),
                    dazu: "gegen ein Haus ohne Preisblick",
                    farbe: v.savingEur >= 0 ? Farbe.mist : Farbe.alarm
                )
            )
        }
        aus += [
            Kacheldaten("unterm Strich", Formate.euro(netto), dazu: "Bezug minus Einspeisung"),
            Kacheldaten("Bezug", Formate.euro(t.importCostEur)),
            Kacheldaten(
                "Einspeisung", Formate.euro(t.exportRevenueEur), farbe: Farbe.netzEinspeisung
            ),
            Kacheldaten("Wärmepumpe", Formate.euro(t.heatPumpCostEur)),
            Kacheldaten(
                "mittlerer Bezugspreis", Formate.zahl(t.avgImportPriceCt, stellen: 2),
                einheit: "ct/kWh"
            ),
        ]
        return aus
    }
}

/// Alles, was die PV-Abrechnung braucht - in einem Rutsch geholt.
///
/// **Fünf Antworten, nicht eine.** Die Seite holte eine Spanne. Die Karte „Zeiträume im
/// Vergleich“ stellt Tag, Woche, Monat und Jahr **zum selben Anker** nebeneinander
/// (`PvAccounting.tsx:151-161`, `useReport.ts:55-77`); das sind vier weitere Abfragen derselben
/// Antwort. Scheitert eine, fehlt ihre Spalte - die Seite bleibt stehen.
struct PvAbrechnungsdaten: Sendable {
    let bericht: PvTaxReportOut
    let jeSpanne: [Spanne: PvTaxReportOut]
}

/// PV-Abrechnung: die Zahlen, die in die Umsatzsteuervoranmeldung gehören.
///
/// Nur fuer den Hausherrn. Hier stehen Bemessungsgrundlagen und Umsatzsteuer der Anlage - das ist
/// kein Energiebericht, sondern ein Beleg.
///
/// **Die Seite ist nach der Vorlage neu geordnet** (`PvAccounting.tsx`): sechs Kennzahlen, das
/// Bild „Erlös und Wertabgabe“, die Aufstellung mit sieben Wertspalten und Summenzeile, die vier
/// Spannen im Vergleich, die Sätze. Was vorher dastand - zwei Karten „Einspeisung“ und
/// „Eigenverbrauch“ mit neun Zeilen - ist darin aufgegangen: jede dieser Zeilen ist jetzt eine
/// Kachel oder eine Spalte der Aufstellung, und ein Beleg, auf dem dieselbe Zahl dreimal steht,
/// ist schwerer zu prüfen als einer, auf dem sie einmal steht.
///
/// **Was gerechnet wird, steht im Kern** (``Pvabrechnung``): die Reihenfolge und die Wortlaute
/// der Kennzahlen, der Kleinunternehmerfall, die sieben Spalten mit ihren Unterzeilen, die
/// Filterschwelle für leere Zeitraumstücke, die Rundung ab hundert Kilowattstunden und die vier
/// Sätze unter der Seite. Hier bleibt die Anordnung.
struct PvAbrechnungSeite: View {
    @Environment(Hauszustand.self) private var haus

    var body: some View {
        Berichtsseite { z, api in
            // Die vier Spannen laufen los, bevor die eigentliche Antwort da ist: sie hängen
            // nur am Anker, nicht an der gewählten Spanne.
            async let spannen = holeSpannen(anker: z.anker, api: api)
            let bericht = try await api.energiePv(z.spanne.rawValue, anker: z.anker)
            return PvAbrechnungsdaten(bericht: bericht, jeSpanne: await spannen)
        // Auch hier muss der Typ dastehen: `kennzahlen` ist in dieser Datei zweimal
        // vorhanden, und solange `Antwort` nicht feststeht, kann der Compiler nicht
        // entscheiden, welche gemeint ist - und leitet `()` ab.
        } inhalt: { (d: PvAbrechnungsdaten) in
            inhalt(d)
        }
    }

    /// Die vier Spannen zum selben Anker. `try?` je Spanne: eine fehlende Spalte ist besser als
    /// eine Seite, die an ihr scheitert - die Vorlage nimmt dafür `Promise.allSettled`
    /// (`useReport.ts:60`).
    private func holeSpannen(anker: String, api: Api) async -> [Spanne: PvTaxReportOut] {
        await withTaskGroup(of: (Spanne, PvTaxReportOut?).self) { gruppe in
            for s in Spanne.allCases {
                gruppe.addTask {
                    (s, try? await api.energiePv(s.rawValue, anker: anker))
                }
            }
            var aus: [Spanne: PvTaxReportOut] = [:]
            for await (s, b) in gruppe {
                if let b { aus[s] = b }
            }
            return aus
        }
    }

    @ViewBuilder private func inhalt(_ d: PvAbrechnungsdaten) -> some View {
        let b = d.bericht
        let saetze = Pvabrechnung.saetze(b)

        // Der Kicker ist der der Vorlage (`PvAccounting.tsx:82`) und nicht der Reitername:
        // „PV-Abrechnung“ über einer Karte auf dem Reiter „PV-Abrechnung“ sagt nichts.
        Kachelfeld(
            kacheln: kacheln(b), kicker: "Einspeisung · Eigenverbrauch · Umsatzsteuer")

        erloeskarte(b)
        aufstellungskarte(b)

        Spannenstreifen(
            titel: "Zeiträume im Vergleich",
            zeilen: Pvabrechnung.spannenzeilen(d.jeSpanne),
            anker: b.anchor,
            jetzt: haus.jetzt
        )

        // Die Abdeckung steht in der Kurzzeile und nicht im Rumpf: sie schränkt jede Zahl
        // dieser Seite ein, und zugeklappt wäre sie verschwiegen. Die Vorlage hat dort keinen
        // Deckel (`PvAccounting.tsx:163-172`), die App klappt Methodensätze zu - dieselbe
        // Teilung hat die Stromseite gewählt (`StromSeite.swift:37-56`).
        Methode(saetze.rumpf.map { Optional($0) }, kurz: saetze.kurz)
    }

    /// Die sechs Kennzahlen, und auf der ersten der Weg zur Erzeugung.
    ///
    /// **Der Verweis „Erzeugung →“ hat in der App keinen Platz im Kopf.** Die Vorlage setzt ihn
    /// rechts in die Zeitraumzeile (`PvAccounting.tsx:88`); die Zeitraumleiste der App trägt
    /// dort nur Spannenwahl und Datumskasten (`Seitenwahl.swift:198-206`). Er sitzt darum auf
    /// der Kachel, von der aus man ihn braucht: wer die eingespeiste Menge liest und sie
    /// erklärt haben will, will die Erzeugung sehen. Den Pfeil setzt ``Kachel`` von selbst
    /// (`Karte.swift:255-257`).
    private func kacheln(_ b: PvTaxReportOut) -> [Kacheldaten] {
        var aus = Pvabrechnung.kennzahlen(b).map(Kacheldaten.init)
        if !aus.isEmpty { aus[0].weg = "/strom/pv" }
        return aus
    }

    /// „Erlös und Wertabgabe“: zwei gestapelte Euro-Reihen je Zeitraumstück
    /// (`PvAccounting.tsx:100-105`, `moneyBars` in `charts.ts:367-399`).
    ///
    /// **Die Seite hatte kein Bild.** Sie nannte Summen und listete Zeiträume; aus welchem
    /// Monat das Geld kam, stand nirgends. Gestapelt, weil sich die beiden Reihen zur
    /// Bemessungsgrundlage der Umsatzsteuer addieren.
    ///
    /// Ohne Tooltip: Swift Charts hat keinen wie ECharts (`charts.ts:372-386`), und die Zahlen
    /// stehen in der Aufstellung direkt darunter - dieselbe Entscheidung wie auf der Kostenseite.
    @ViewBuilder private func erloeskarte(_ b: PvTaxReportOut) -> some View {
        let reihen = Pvabrechnung.erloesreihen(b)
        Karte(kicker: "Erlös und Wertabgabe", beiwerk: AnyView(beiwerk(Pvabrechnung.erloeskopf))) {
            if reihen.allSatisfy({ $0.werte.isEmpty }) {
                Leer(satz: Pvabrechnung.leersatz)
            } else {
                // 230 Punkte, weil die Karte der Vorlage 300 hoch ist und Kopfzeile und
                // Polster davon abgehen (`PvAccounting.tsx:101`).
                Balkenbild(stuecke: reihen.map(stueck), einheit: "€", hoehe: 230)
            }
        }
    }

    private func stueck(_ r: Pvabrechnung.Erloesreihe) -> Balkenbild.Stueck {
        Balkenbild.Stueck(name: r.name, farbe: Farbe.ton(r.ton), werte: r.werte)
    }

    /// „Aufstellung“: die sieben Wertspalten je Zeitraum und die Summe darunter.
    ///
    /// **Die Tabelle steht auch dann, wenn kein Zeitraumstück die Schwelle überschreitet.**
    /// Die Summe stammt nicht aus den Zeilen, sondern aus `totals`, und die Vorlage zeichnet sie
    /// unabhängig von `rows.length` (`PvAccounting.tsx:132-141`, gerendert nach der leeren
    /// `rows.map`); ``Abrechnungstabelle`` trägt sie ohnehin. Der Leersatz gehört allein in die
    /// Diagrammkarte (`:103`): ein Beleg, der die abzuführende Steuer verschweigt, weil keine
    /// Stunde bewertet wurde, ist kein Beleg.
    @ViewBuilder private func aufstellungskarte(_ b: PvTaxReportOut) -> some View {
        let a = Pvabrechnung.aufstellung(b)
        Karte(kicker: "Aufstellung", beiwerk: AnyView(beiwerk(a.kopfzeile))) {
            VStack(alignment: .leading, spacing: 8) {
                Abrechnungstabelle(aufstellung: a)
                Text(a.rundungssatz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Was rechts in einer Kopfzeile steht - 12 px in `--text-3` (`Card.tsx:20-28`).
    private func beiwerk(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .multilineTextAlignment(.trailing)
    }
}
