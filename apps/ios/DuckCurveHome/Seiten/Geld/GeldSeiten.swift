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
        Berichtsseite(spannen: [.tag, .woche, .monat, .jahr]) { z, api in
            // Zwei Antworten, weil es zwei Fragen sind: was es gekostet hat, und was es ohne
            // Preisblick gekostet hätte.
            async let kosten = api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
            async let verschiebung = try? api.energieVerschiebung(z.spanne.rawValue, anker: z.anker)
            return try await (kosten: kosten, verschiebung: verschiebung)
        // **Der Typ muss dastehen.** `Berichtsseite` leitet `Antwort` aus der Abfrage ab;
        // bei einem benannten Paar, dessen zweite Haelfte aus `try?` kommt, schafft der
        // Compiler das nicht mehr und meldet „cannot infer type of closure parameter".
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

/// PV-Abrechnung: die Zahlen, die in die Steuererklaerung gehoeren.
///
/// Nur fuer den Hausherrn. Hier stehen Bemessungsgrundlagen und Umsatzsteuer der Anlage - das ist
/// kein Energiebericht, sondern ein Beleg.
struct PvAbrechnungSeite: View {
    var body: some View {
        Berichtsseite(spannen: [.monat, .jahr]) { z, api in
            try await api.energiePv(z.spanne.rawValue, anker: z.anker)
        // Auch hier muss der Typ dastehen: `kennzahlen` ist in dieser Datei zweimal
        // vorhanden, und solange `Antwort` nicht feststeht, kann der Compiler nicht
        // entscheiden, welche gemeint ist - und leitet `()` ab.
        } inhalt: { (b: PvTaxReportOut) in
            Kachelfeld(kacheln: kennzahlen(b), kicker: "PV-Abrechnung")
            Karte(kicker: "Einspeisung") {
                VStack(spacing: 0) {
                    Zeile(
                        wort: "eingespeist", wert: Formate.zahl(b.totals.exportKwh, stellen: 1),
                        einheit: "kWh"
                    )
                    Zeile(wort: "netto", wert: Formate.euro(b.totals.exportNetEur))
                    Zeile(wort: "Umsatzsteuer", wert: Formate.euro(b.totals.exportVatEur))
                    Zeile(wort: "brutto", wert: Formate.euro(b.totals.exportGrossEur))
                }
            }
            Karte(kicker: "Eigenverbrauch") {
                VStack(spacing: 0) {
                    Zeile(
                        wort: "selbst verbraucht",
                        wert: Formate.zahl(b.totals.selfConsumptionKwh, stellen: 1), einheit: "kWh"
                    )
                    Zeile(
                        wort: "davon direkt", wert: Formate.zahl(b.totals.selfDirectKwh, stellen: 1),
                        einheit: "kWh"
                    )
                    Zeile(
                        wort: "davon aus dem Speicher",
                        wert: Formate.zahl(b.totals.selfBatteryKwh, stellen: 1), einheit: "kWh"
                    )
                    Zeile(wort: "Wert netto", wert: Formate.euro(b.totals.selfValueNetEur))
                    Zeile(wort: "Umsatzsteuer darauf", wert: Formate.euro(b.totals.selfVatEur))
                }
            }
            Karte(kicker: "Nach Zeitraum") {
                Tabelle(
                    zeilennamen: b.buckets.map(\.label),
                    spalten: [
                        .init(
                            name: "eingespeist",
                            zellen: b.buckets.map { Formate.zahl($0.totals.exportKwh, stellen: 1) }
                        ),
                        .init(
                            name: "Vergütung",
                            zellen: b.buckets.map { Formate.euro($0.totals.exportNetEur) }
                        ),
                        .init(
                            name: "Eigenverbrauch",
                            zellen: b.buckets.map {
                                Formate.zahl($0.totals.selfConsumptionKwh, stellen: 1)
                            }
                        ),
                        .init(
                            name: "USt. zu zahlen",
                            zellen: b.buckets.map { Formate.euro($0.totals.vatPayableEur) }
                        ),
                    ]
                )
            }
            Methode([
                b.totals.smallBusiness == true
                    ? "Kleinunternehmerregelung: keine Umsatzsteuer ausgewiesen."
                    : b.totals.vatRate.map {
                        "Umsatzsteuersatz \(Formate.prozent($0 > 1 ? $0 / 100 : $0))."
                    },
                b.totals.selfEstimatedKwh.map {
                    $0 > 0.05
                        ? "Vom Eigenverbrauch sind \(Formate.kwh($0)) geschätzt, nicht gemessen."
                        : nil
                } ?? nil,
                // **`PvTaxMetaOut` heisst sein Feld `methodDe`, nicht `estimatedNoteDe`.**
                // Die Verwechslung lag nahe: auf der Geld-Seite darueber ist `meta` ein
                // `EnergyMetaOut`, und dort gibt es `estimatedNoteDe` wirklich. Zwei Typen,
                // beide „meta", verschiedene Felder.
                b.meta.methodDe,
                "Diese Seite ist eine Rechenhilfe und keine Steuerberatung.",
            ])
        }
    }

    private func kennzahlen(_ b: PvTaxReportOut) -> [Kacheldaten] {
        let t = b.totals
        return [
            Kacheldaten(
                "Umsatzsteuer zu zahlen", Formate.euro(t.vatPayableEur),
                dazu: "aus Einspeisung und Eigenverbrauch"
            ),
            Kacheldaten("erzeugt", Formate.zahl(t.pvKwh, stellen: 1), einheit: "kWh", farbe: Farbe.pv),
            Kacheldaten(
                "eingespeist", Formate.zahl(t.exportKwh, stellen: 1), einheit: "kWh",
                dazu: Formate.euro(t.exportGrossEur) + " brutto"
            ),
            Kacheldaten(
                "selbst verbraucht", Formate.zahl(t.selfConsumptionKwh, stellen: 1), einheit: "kWh",
                dazu: Formate.euro(t.selfValueNetEur) + " netto"
            ),
            Kacheldaten(
                "Vergütungssatz", Formate.zahl(t.feedInCtKwh, stellen: 2), einheit: "ct/kWh"
            ),
            Kacheldaten("Eigenverbrauchsanteil", Formate.prozent(t.selfConsumptionShare)),
        ]
    }
}
