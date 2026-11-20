import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/PvAccounting.tsx`.
///
/// Geprüft wird, was gerechnet wird: die Reihenfolge und die Wortlaute der sechs Kennzahlen,
/// der Kleinunternehmerfall, die sieben Spalten der Aufstellung mit ihren Unterzeilen, die
/// Herkunft der Summe, die Schwelle 0,005 kWh für leere Zeitraumstücke, die Rundung ab hundert
/// Kilowattstunden, der Spannenstreifen mit fehlenden Spalten und die vier Sätze unter der
/// Seite.
///
/// **Warum so viele Prüfungen auf Zeichenketten.** Diese Seite ist ein Beleg: ihre Zahlen gehen
/// in eine Voranmeldung. „8,2 ct/kWh“ statt „8,20 ct/kWh“ und „USt darauf“ ohne die Unterzeile,
/// die „erhalten“ von „geschuldet“ trennt, sind dort keine Schönheitsfehler.
final class PvabrechnungTests: XCTestCase {

    // MARK: - Antworten bauen

    private func summen(
        exportKwh: Double? = 120.0, exportNetto: Double? = 9.84, exportUst: Double? = 1.87,
        exportBrutto: Double? = 11.71, eigenKwh: Double? = 42.5, direkt: Double? = 30.1,
        speicher: Double? = 12.4, eigenNetto: Double? = 12.07, eigenUst: Double? = 2.29,
        eigenCt: Double? = 28.4, geschaetzt: Double? = 3.2, zahllast: Double? = 4.16,
        pv: Double? = 162.5, anteil: Double? = 0.26, klein: Bool? = false, satz: Double? = 19
    ) -> PvTaxTotals {
        PvTaxTotals(
            smallBusiness: klein, vatRate: satz, feedInCtKwh: 8.2, exportKwh: exportKwh,
            exportNetEur: exportNetto, exportVatEur: exportUst, exportGrossEur: exportBrutto,
            selfConsumptionKwh: eigenKwh, selfDirectKwh: direkt, selfBatteryKwh: speicher,
            selfValueNetEur: eigenNetto, selfVatEur: eigenUst, selfCtKwh: eigenCt,
            selfEstimatedKwh: geschaetzt, vatPayableEur: zahllast, pvKwh: pv,
            selfConsumptionShare: anteil)
    }

    private func angaben(
        klein: Bool = false, satz: Double = 19, abdeckung: Double? = 0.97,
        methode: String = "Bewertet mit dem Vergütungssatz je Stunde."
    ) -> PvTaxMetaOut {
        PvTaxMetaOut(
            feedInCtKwh: 8.2, vatRate: satz, smallBusiness: klein, pricesIncludeVat: false,
            dataSince: "2024-03-01", coverage: abdeckung, batteryCapacityKwh: 10,
            methodDe: methode)
    }

    private func stueck(
        _ name: String, exportKwh: Double? = 10.0, eigenKwh: Double? = 4.0,
        exportNetto: Double? = 0.82, eigenNetto: Double? = 1.14, zahllast: Double? = 0.37
    ) -> PvTaxBucketOut {
        PvTaxBucketOut(
            start: "2026-01-01T00:00:00+01:00", end: "2026-02-01T00:00:00+01:00", label: name,
            totals: summen(
                exportKwh: exportKwh, exportNetto: exportNetto, eigenKwh: eigenKwh,
                eigenNetto: eigenNetto, zahllast: zahllast))
    }

    private func bericht(
        _ t: PvTaxTotals? = nil, stuecke: [PvTaxBucketOut] = [], meta: PvTaxMetaOut? = nil
    ) -> PvTaxReportOut {
        PvTaxReportOut(
            period: .year, anchor: "2026-11-10", start: "2026-01-01T00:00:00+01:00",
            end: "2027-01-01T00:00:00+01:00", totals: t ?? summen(), buckets: stuecke,
            meta: meta ?? angaben())
    }

    // MARK: - Die sechs Kennzahlen

    func testSechsKennzahlenInDerReihenfolgeDerVorlage() {
        let k = Pvabrechnung.kennzahlen(bericht())
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Eingespeist", "Vergütung netto", "USt auf Einspeisung", "Eigenverbrauch",
                "Wert des Eigenverbrauchs", "Umsatzsteuer gesamt",
            ])
        XCTAssertEqual(k.map(\.einheit), ["kWh", nil, nil, "kWh", nil, nil])
    }

    /// Die Vergütung führt und nicht die Zahllast: „120“ steht als erste Zahl da, nicht „4,16 €“.
    func testDieEinspeisungFuehrtUndIstAbHundertOhneNachkommastelle() {
        let k = Pvabrechnung.kennzahlen(bericht())
        XCTAssertEqual(k[0].wert, "120")
        XCTAssertEqual(k[3].wert, "42,5")
    }

    func testDieHinweiszeilenStehenWoertlichWieInDerVorlage() {
        let k = Pvabrechnung.kennzahlen(bericht())
        XCTAssertEqual(k[0].dazu, "8,20\u{202F}ct/kWh netto")
        XCTAssertEqual(k[1].dazu, "brutto 11,71\u{202F}€")
        XCTAssertEqual(k[2].dazu, "ausgezahlt, abzuführen")
        XCTAssertEqual(k[3].dazu, "davon 12,4 kWh über den Speicher")
        XCTAssertEqual(k[4].dazu, "netto, Ø 28,40\u{202F}ct/kWh")
        XCTAssertEqual(k[5].dazu, "Einspeisung + Wertabgabe")
    }

    /// Nebel auf der Einspeisung, Bernstein auf Eigenverbrauch und Zahllast
    /// (`PvAccounting.tsx:92`, `:95`, `:97`).
    func testDieToeneFolgenDerVorlage() {
        let k = Pvabrechnung.kennzahlen(bericht())
        XCTAssertEqual(k.map(\.ton), [.nebel, .normal, .normal, .bernstein, .normal, .bernstein])
    }

    /// `meta.small_business`, nicht `totals.small_business` (`PvAccounting.tsx:58`).
    func testKleinunternehmerDaempftZweiKachelnUndTauschtIhreHinweise() {
        let k = Pvabrechnung.kennzahlen(
            bericht(summen(klein: false), meta: angaben(klein: true)))
        XCTAssertEqual(k[2].ton, .gedaempft)
        XCTAssertEqual(k[5].ton, .gedaempft)
        XCTAssertEqual(k[1].dazu, "ohne Umsatzsteuer")
        XCTAssertEqual(k[5].dazu, "Kleinunternehmer: keine USt")
    }

    /// Der Schalter steht in `meta`: ein `totals.smallBusiness == true` darf die Kacheln
    /// nicht dämpfen, sonst wechselt die Färbung mit dem Zeitraum.
    func testDerSchalterKommtAusMetaUndNichtAusTotals() {
        let k = Pvabrechnung.kennzahlen(
            bericht(summen(klein: true), meta: angaben(klein: false)))
        XCTAssertEqual(k[2].ton, .normal)
        XCTAssertEqual(k[5].ton, .bernstein)
        XCTAssertEqual(k[5].dazu, "Einspeisung + Wertabgabe")
    }

    func testFehlendeZahlenWerdenZuStrichenUndNichtZuNullen() {
        let leer = PvTaxTotals()
        let k = Pvabrechnung.kennzahlen(bericht(leer))
        XCTAssertEqual(k.map(\.wert), ["-", "-", "-", "-", "-", "-"])
    }

    /// Ohne `self_ct_kwh` bleibt „netto“ stehen und nicht „netto, Ø -/kWh“.
    func testOhneMittelwertBleibtNurNetto() {
        let k = Pvabrechnung.kennzahlen(bericht(summen(eigenCt: nil)))
        XCTAssertEqual(k[4].dazu, "netto")
    }

    /// Ohne Speicherwert fällt die Hinweiszeile weg, statt „davon - kWh“ zu schreiben.
    func testOhneSpeicherwertFaelltDieHinweiszeileWeg() {
        let k = Pvabrechnung.kennzahlen(bericht(summen(speicher: nil)))
        XCTAssertNil(k[3].dazu)
    }

    // MARK: - Die Aufstellung

    func testSiebenSpaltenMitZweiKopfebenen() {
        let a = Pvabrechnung.aufstellung(bericht(stuecke: [stueck("Jan.")]))
        XCTAssertEqual(
            a.spalten.map(\.kopf),
            [
                "Einspeisung", "Vergütung", "USt darauf", "Eigenverbrauch", "Wertabgabe",
                "USt darauf", "Zahllast",
            ])
        XCTAssertEqual(
            a.spalten.map(\.unter),
            ["kWh", "netto", "erhalten", "kWh", "netto", "geschuldet", "USt gesamt"])
    }

    /// „USt darauf“ steht zweimal; nur mit der Unterzeile sind die Spalten unterscheidbar -
    /// und nur dann taugt der Name als Schlüssel für den Umschalter am Telefon.
    func testDieSpaltennamenSindMitUnterzeileEindeutig() {
        let namen = Pvabrechnung.aufstellungsspalten.map(\.id)
        XCTAssertEqual(Set(namen).count, 7)
        XCTAssertEqual(namen[2], "USt darauf · erhalten")
        XCTAssertEqual(namen[5], "USt darauf · geschuldet")
    }

    /// Genau eine Spalte trägt Farbe (`COLUMNS[6].strong`).
    func testNurDieZahllastIstBetont() {
        XCTAssertEqual(
            Pvabrechnung.aufstellungsspalten.map(\.betont),
            [false, false, false, false, false, false, true])
    }

    func testJedeZeileHatSiebenZellenInDerReihenfolgeDerSpalten() {
        let a = Pvabrechnung.aufstellung(bericht(stuecke: [stueck("Jan.")]))
        XCTAssertEqual(a.zeilen.count, 1)
        XCTAssertEqual(a.zeilen[0].wort, "Jan.")
        XCTAssertEqual(
            a.zeilen[0].zellen,
            ["10,0", "0,82\u{202F}€", "1,87\u{202F}€", "4,0", "1,14\u{202F}€", "2,29\u{202F}€",
             "0,37\u{202F}€"])
    }

    /// Die Summe kommt aus `totals` und nicht aus den Zeilen (`rowOf`, `:39-50`).
    func testDieSummeStammtAusDenGesamtwertenUndNichtAusDenZeilen() {
        let a = Pvabrechnung.aufstellung(
            bericht(stuecke: [stueck("Jan."), stueck("Feb.")]))
        XCTAssertEqual(a.summe.wort, "Summe")
        // Zwei Zeilen mit je 10,0 kWh - die Summe sagt trotzdem 120, weil der Dienst sie
        // aus ungerundeten Stundenwerten rechnet.
        XCTAssertEqual(a.summe.zellen[0], "120")
        XCTAssertEqual(a.summe.zellen[6], "4,16\u{202F}€")
    }

    /// `export_kwh > 0.005 || self_consumption_kwh > 0.005` (`PvAccounting.tsx:61`).
    func testLeereZeitraumstueckeFallenWeg() {
        let a = Pvabrechnung.aufstellung(
            bericht(stuecke: [
                stueck("Jan.", exportKwh: 0, eigenKwh: 0),
                stueck("Feb.", exportKwh: 0.004, eigenKwh: 0.004),
                stueck("Mär.", exportKwh: 0.006, eigenKwh: 0),
                stueck("Apr.", exportKwh: 0, eigenKwh: 0.006),
                stueck("Mai", exportKwh: nil, eigenKwh: nil),
            ]))
        XCTAssertEqual(a.zeilen.map(\.wort), ["Mär.", "Apr."])
        XCTAssertEqual(a.kopfzeile, "2 Zeilen · Beträge in Euro")
    }

    func testOhneZeitraumstueckeBleibenSummeUndSaetzeStehen() {
        let a = Pvabrechnung.aufstellung(bericht())
        XCTAssertTrue(a.zeilen.isEmpty)
        XCTAssertEqual(a.kopfzeile, "0 Zeilen · Beträge in Euro")
        XCTAssertEqual(a.summe.zellen.count, 7)
        XCTAssertTrue(a.rundungssatz.hasPrefix("Die Summe stammt aus den ungerundeten"))
    }

    func testFehlendeFelderEinesStueckesWerdenStricheUndKeineNullen() {
        let ohne = PvTaxBucketOut(
            start: "a", end: "b", label: "Jan.",
            totals: PvTaxTotals(exportKwh: 10.0))
        let a = Pvabrechnung.aufstellung(bericht(stuecke: [ohne]))
        XCTAssertEqual(a.zeilen[0].zellen, ["10,0", "-", "-", "-", "-", "-", "-"])
    }

    // MARK: - Erlös und Wertabgabe

    func testZweiReihenMitDenNamenUndToenenDerVorlage() {
        let r = Pvabrechnung.erloesreihen(bericht(stuecke: [stueck("Jan."), stueck("Feb.")]))
        XCTAssertEqual(r.map(\.name), ["Einspeisevergütung netto", "Eigenverbrauch (Wert netto)"])
        XCTAssertEqual(r.map(\.ton), [.nebel, .sonne])
        XCTAssertEqual(r[0].werte.map(\.beschriftung), ["Jan.", "Feb."])
        XCTAssertEqual(r[0].werte.map(\.wert), [0.82, 0.82])
        XCTAssertEqual(r[1].werte.map(\.wert), [1.14, 1.14])
    }

    /// Dasselbe Sieb wie in der Tabelle: Bild und Aufstellung zeigen dieselben Zeiträume.
    func testDasBildBenutztDieselbeFilterschwelleWieDieTabelle() {
        let b = bericht(stuecke: [
            stueck("Jan.", exportKwh: 0, eigenKwh: 0),
            stueck("Feb.", exportKwh: 12.0, eigenKwh: 0),
        ])
        XCTAssertEqual(
            Pvabrechnung.erloesreihen(b)[0].werte.map(\.beschriftung),
            Pvabrechnung.aufstellung(b).zeilen.map(\.wort))
    }

    /// Im Bild ist eine fehlende Zahl kein Strich, sondern kein Balken (`?? 0`).
    func testEineFehlendeZahlWirdImBildZuNull() {
        let ohne = PvTaxBucketOut(
            start: "a", end: "b", label: "Jan.", totals: PvTaxTotals(exportKwh: 10.0))
        let r = Pvabrechnung.erloesreihen(bericht(stuecke: [ohne]))
        XCTAssertEqual(r[0].werte.map(\.wert), [0])
        XCTAssertEqual(r[1].werte.map(\.wert), [0])
    }

    /// `charts.ts:394` rundet die Werte auf zwei Stellen, bevor sie gestapelt werden.
    func testDieWerteWerdenAufCentGerundet() {
        let b = bericht(stuecke: [stueck("Jan.", exportNetto: 1.23456, eigenNetto: 9.87654)])
        let r = Pvabrechnung.erloesreihen(b)
        XCTAssertEqual(r[0].werte[0].wert, 1.23)
        XCTAssertEqual(r[1].werte[0].wert, 9.88)
    }

    func testOhneZeitraumstueckeHatDasBildLeereReihen() {
        let r = Pvabrechnung.erloesreihen(bericht())
        XCTAssertEqual(r.count, 2)
        XCTAssertTrue(r.allSatisfy { $0.werte.isEmpty })
    }

    // MARK: - Zeiträume im Vergleich

    func testFuenfZeilenUndVierSpaltenInDerReihenfolgeDerSpannen() {
        let je: [Spanne: PvTaxReportOut] = [
            .tag: bericht(summen(exportKwh: 3.4, exportNetto: 0.28)),
            .woche: bericht(summen(exportKwh: 22.1, exportNetto: 1.81)),
            .monat: bericht(summen(exportKwh: 98.7, exportNetto: 8.09)),
            .jahr: bericht(summen(exportKwh: 1284.3, exportNetto: 105.31)),
        ]
        let z = Pvabrechnung.spannenzeilen(je)
        XCTAssertEqual(
            z.map(\.wort),
            [
                "Einspeisung · kWh", "Vergütung netto", "Eigenverbrauch · kWh",
                "Wert Eigenverbrauch netto", "Umsatzsteuer gesamt",
            ])
        XCTAssertEqual(z.map(\.ton), [.nebel, .normal, .normal, .normal, .bernstein])
        // Ab hundert ohne Nachkommastelle - die Jahresspalte sagt „1284“ und nicht „1284,3“.
        XCTAssertEqual(z[0].werte, ["3,4", "22,1", "98,7", "1284"])
        XCTAssertEqual(z[1].werte[3], "105,31\u{202F}€")
    }

    /// Eine gescheiterte Spanne fehlt, die Karte bleibt (`PvAccounting.tsx:76`).
    func testEineFehlendeSpanneWirdZuStrichenUndNichtZurNachbarspalte() {
        let z = Pvabrechnung.spannenzeilen([.monat: bericht()])
        XCTAssertEqual(z[0].werte, ["-", "-", "120", "-"])
        XCTAssertEqual(z[4].werte, ["-", "-", "4,16\u{202F}€", "-"])
    }

    func testOhneJedeSpanneStehenFuenfZeilenMitVierStrichen() {
        let z = Pvabrechnung.spannenzeilen([:])
        XCTAssertEqual(z.count, 5)
        XCTAssertTrue(z.allSatisfy { $0.werte == ["-", "-", "-", "-"] })
    }

    // MARK: - Was die Seite über sich selbst sagt

    func testDieAbdeckungStehtInDerKurzzeileUndDerRestImRumpf() {
        let s = Pvabrechnung.saetze(bericht())
        XCTAssertEqual(s.kurz, "Datenabdeckung 97\u{202F}%")
        XCTAssertEqual(
            s.rumpf,
            [
                "Bewertet mit dem Vergütungssatz je Stunde.",
                "Umsatzsteuersatz 19\u{202F}%.",
                "Bei 3,2 kWh der Speicherentladung war die Herkunft nicht bekannt; sie zählen "
                    + "als PV.",
                "Die Zahlen bereiten die Beträge auf, sie ersetzen keine Steuerberatung.",
            ])
    }

    /// `nil` heißt: niemand hat gemessen. Null heißt: gemessen und nichts gefunden.
    func testOhneAbdeckungStehtDerSatzDerVorlageUndNichtNullProzent() {
        XCTAssertEqual(
            Pvabrechnung.saetze(bericht(meta: angaben(abdeckung: nil))).kurz,
            "Für diesen Zeitraum liegen keine Messdaten vor.")
        XCTAssertEqual(
            Pvabrechnung.saetze(bericht(meta: angaben(abdeckung: 0))).kurz,
            "Datenabdeckung 0\u{202F}%")
    }

    func testDerKleinunternehmerSatzTrittAnDieStelleDesSteuersatzes() {
        let s = Pvabrechnung.saetze(bericht(meta: angaben(klein: true)))
        XCTAssertEqual(s.rumpf[1], "Kleinunternehmerregelung: keine Umsatzsteuer ausgewiesen.")
        XCTAssertFalse(s.rumpf.contains { $0.hasPrefix("Umsatzsteuersatz") })
    }

    /// Der Dienst liefert den Satz je nach Quelle als Anteil oder als Prozentzahl.
    func testDerSteuersatzWirdAlsAnteilWieAlsProzentzahlGelesen() {
        XCTAssertEqual(Pvabrechnung.steuersatz(angaben(satz: 0.19)), "Umsatzsteuersatz 19\u{202F}%.")
        XCTAssertEqual(Pvabrechnung.steuersatz(angaben(satz: 19)), "Umsatzsteuersatz 19\u{202F}%.")
        XCTAssertEqual(Pvabrechnung.steuersatz(angaben(satz: 1)), "Umsatzsteuersatz 100\u{202F}%.")
    }

    /// Unter 0,05 kWh steht nichts da (`PvAccounting.tsx:169`).
    func testDerSchaetzsatzStehtErstAbEinemZwanzigstelKilowattstunde() {
        XCTAssertNil(Pvabrechnung.schaetzsatz(nil))
        XCTAssertNil(Pvabrechnung.schaetzsatz(0))
        XCTAssertNil(Pvabrechnung.schaetzsatz(0.05))
        XCTAssertEqual(
            Pvabrechnung.schaetzsatz(0.06),
            "Bei 0,1 kWh der Speicherentladung war die Herkunft nicht bekannt; sie zählen als PV.")
    }

    func testEinLeererMethodensatzDesDienstesHinterlaesstKeineLeerzeile() {
        let s = Pvabrechnung.saetze(bericht(meta: angaben(methode: "")))
        XCTAssertEqual(s.rumpf.count, 3)
        XCTAssertFalse(s.rumpf.contains(""))
    }

    // MARK: - Die Rundungsregel selbst

    /// Die Regel steht in der Vorlage sechsmal; hier steht sie einmal
    /// (`PvAccounting.tsx:30`, `:33`, `:92`, `:95`, `:155`, `:157`).
    func testKwhNachGroesseRundetAbHundertOhneNachkommastelle() {
        XCTAssertEqual(Formate.kwhNachGroesse(0), "0,0")
        XCTAssertEqual(Formate.kwhNachGroesse(99.94), "99,9")
        XCTAssertEqual(Formate.kwhNachGroesse(99.96), "100,0")
        XCTAssertEqual(Formate.kwhNachGroesse(100), "100")
        XCTAssertEqual(Formate.kwhNachGroesse(1284.3), "1284")
        XCTAssertEqual(Formate.kwhNachGroesse(nil), "-")
        XCTAssertEqual(Formate.kwhNachGroesse(Double.nan), "-")
    }

    /// **Die Schwelle greift vor der Rundung, nicht danach.** 99,96 kWh wird „100,0“ und nicht
    /// „100“: verglichen wird der gemessene Wert. Der Fall sieht gewollt aus wie ein Fehler
    /// und ist deshalb hier festgehalten - die Vorlage macht es genauso (`de1` bekommt die
    /// Stellenzahl aus demselben Vergleich).
    func testDieSchwelleGreiftVorDerRundung() {
        XCTAssertEqual(Formate.kwhNachGroesse(99.99), "100,0")
    }
}
