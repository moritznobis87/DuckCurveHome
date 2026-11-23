import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/InvoiceCheck.tsx` und die vier Diagramme
/// in `apps/web/src/components/reports/charts.ts:279-367`.
///
/// Geprüft wird, was gerechnet wird: die chronologische Reihenfolge, das Achsenkürzel samt dem
/// Monat, an dem die Vorlage selbst nicht greift, die vier Kopfkennzahlen mit dem
/// mengengewichteten Mittel, die Rundung der Mehrwertsteuer auf den Cent, die Teilung der
/// Befunde nach Code, die Rangfolge der Schwere, die 98-%-Schwelle der Abdeckungsangabe, die
/// 0,005-Schwelle des Deltas und die Darstellung eines unbekannten Urteils.
///
/// **Warum so viele Prüfungen auf Zeichenketten.** Diese Seite ist die eine Stelle, an der
/// jemand eine Rechnung des Versorgers nachliest. „0,00 ct/kWh“ statt eines Strichs bei Menge
/// null, eine Abdeckungsangabe, die bei 98 % noch dasteht, und ein Delta „· 0,00“ sind dort
/// keine Schönheitsfehler: der erste ist ein Preis, den niemand bezahlt hat, der zweite nimmt
/// der Angabe in der zehnten Zeile die Aufmerksamkeit, und der dritte behauptet eine Abweichung.
final class RechnungspruefungTests: XCTestCase {

    // MARK: - Antworten bauen

    private func zeile(
        nummer: String = "R-1", zeitraum: String = "Oktober 2026",
        start: String = "2026-10-01", ende: String = "2026-10-31",
        kwh: Double = 400, gemessen: Double? = 398.4, gemessenPreis: Double? = 31.2,
        abdeckung: Double? = 0.99, netto: Double = 100, brutto: Double = 119,
        mittel: Double = 31.45, energie: Double = 82, gebuehren: Double = 18,
        urteil: String = "ok", probleme: Int = 0
    ) -> InvoiceSummaryOut {
        InvoiceSummaryOut(
            number: nummer, periodLabel: zeitraum, periodStart: start, periodEnd: ende,
            issuedOn: "2026-11-02", kwh: kwh, measuredKwh: gemessen,
            measuredAvgCtKwh: gemessenPreis, coverage: abdeckung, totalNetEur: netto,
            totalGrossEur: brutto, avgCtKwhGross: mittel, energyNetEur: energie,
            feesNetEur: gebuehren, verdict: urteil, problems: probleme,
            checkedAt: "2026-11-02T10:00:00+01:00")
    }

    private func befund(
        _ code: String, _ schwere: InvoiceFindingSeverityWahl, titel: String = "Titel",
        erwartet: Double? = nil, tatsaechlich: Double? = nil, einheit: String? = nil,
        delta: Double? = nil
    ) -> InvoiceFinding {
        InvoiceFinding(
            code: code, severity: schwere, titleDe: titel, detailDe: "Dazu etwas.",
            expected: erwartet, actual: tatsaechlich, unit: einheit, delta: delta)
    }

    private func position(
        _ name: String, gruppe: String = "Netz", ct: Double = 8.5, stellen: Int = 3,
        betrag: Double = 34
    ) -> InvoicePosition {
        InvoicePosition(
            label: name, group: gruppe, ctPerKwh: ct, ctDecimals: stellen, amountEur: betrag)
    }

    private func rechnung(
        start: String = "2026-10-01", ende: String = "2026-10-31",
        zaehlerVon: Double? = 41_203.4, zaehlerBis: Double? = 41_615.8, geschaetzt: Bool? = false,
        positionen: [InvoicePosition] = []
    ) -> TibberInvoice {
        TibberInvoice(
            number: "R-1", issuedOn: "2026-11-02", periodStart: start, periodEnd: ende,
            periodLabel: "Oktober 2026", kwh: 400, meterStart: zaehlerVon, meterEnd: zaehlerBis,
            meterEstimated: geschaetzt, positions: positionen, fees: [], energyNetEur: 82,
            energyGrossEur: 97.58, feesNetEur: 18, feesGrossEur: 21.42, totalNetEur: 100,
            totalGrossEur: 119, vatEur: 19, avgCtKwh: 25, avgCtKwhGross: 29.75)
    }

    // MARK: - Reihenfolge

    func testChronologischSortiertNachZeitraumAnfang() {
        let liste = [
            zeile(nummer: "C", start: "2026-10-01"),
            zeile(nummer: "A", start: "2026-08-01"),
            zeile(nummer: "B", start: "2026-09-01"),
        ]
        XCTAssertEqual(
            Rechnungspruefung.chronologisch(liste).map(\.number), ["A", "B", "C"])
    }

    /// Gleicher Anfang: die Reihenfolge des Dienstes bleibt. `sorted(by:)` ist in Swift nicht
    /// stabil, die Vorlage sortiert in JavaScript stabil - darum wird die Eingangsstelle
    /// mitsortiert.
    func testChronologischIstStabilBeiGleichemAnfang() {
        let liste = [
            zeile(nummer: "zuerst", start: "2026-10-01"),
            zeile(nummer: "danach", start: "2026-10-01"),
        ]
        XCTAssertEqual(
            Rechnungspruefung.chronologisch(liste).map(\.number), ["zuerst", "danach"])
    }

    func testChronologischMitLeererListe() {
        XCTAssertTrue(Rechnungspruefung.chronologisch([]).isEmpty)
    }

    // MARK: - Achsenkürzel

    func testAchsenkuerzelKuerztDenMonat() {
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel("Oktober 2026"), "Okt 2026")
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel("September 2025"), "Sep 2025")
    }

    func testAchsenkuerzelLaesstKurzeNamenStehen() {
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel("Mai 2026"), "Mai 2026")
    }

    /// **Der Monat, an dem der reguläre Ausdruck der Vorlage nicht greift.** In JavaScript ist
    /// `\w` genau `[A-Za-z0-9_]`; „ä“ gehört nicht dazu, also findet
    /// `/(\w{3})\w* (\d{4})/` in „März 2026“ keinen Treffer und das Label bleibt stehen. Mit den
    /// Wortzeichen von ICU wäre daraus „Mär 2026“ geworden - eine Abweichung zwischen App und
    /// Browser in genau einem Monat des Jahres.
    func testAchsenkuerzelLaesstEinenUmlautmonatStehen() {
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel("März 2026"), "März 2026")
    }

    func testAchsenkuerzelOhneJahrBleibtUnveraendert() {
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel("Oktober"), "Oktober")
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel("Oktober 202"), "Oktober 202")
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel(""), "")
    }

    /// Wie `String.replace` ohne `/g`: nur der erste Treffer.
    func testAchsenkuerzelErsetztNurDenErstenTreffer() {
        XCTAssertEqual(
            Rechnungspruefung.achsenkuerzel("Dezember 2025 bis Januar 2026"),
            "Dez 2025 bis Januar 2026")
    }

    /// Steht vor dem Monat etwas anderes, bleibt es stehen - der Ausdruck ist nicht verankert.
    func testAchsenkuerzelBehaeltDenVorlauf() {
        XCTAssertEqual(Rechnungspruefung.achsenkuerzel("ab Oktober 2026"), "ab Okt 2026")
    }

    // MARK: - Die vier Kopfkennzahlen

    func testKopfkennzahlenOhneRechnungen() {
        let k = Rechnungspruefung.kopfkennzahlen([])
        XCTAssertEqual(k.count, 4)
        XCTAssertEqual(k[0].wort, "Geprüfte Rechnungen")
        XCTAssertEqual(k[0].wert, "0")
        XCTAssertEqual(k[0].dazu, "noch keine")
        XCTAssertEqual(k[1].wert, "0")
        XCTAssertEqual(k[1].dazu, "keine Auffälligkeit")
        XCTAssertEqual(k[1].ton, .bernstein)
        XCTAssertEqual(k[2].wert, "0,00\u{202F}€")
        // Kein „0,00 ct/kWh“: ohne Menge gibt es keinen Preis.
        XCTAssertEqual(k[3].wert, Formate.leer)
        XCTAssertEqual(k[3].einheit, "ct/kWh")
    }

    func testKopfkennzahlenZaehltUndNenntDieSpanne() {
        let liste = [
            zeile(nummer: "B", zeitraum: "Oktober 2026", start: "2026-10-01"),
            zeile(nummer: "A", zeitraum: "August 2026", start: "2026-08-01"),
        ]
        let k = Rechnungspruefung.kopfkennzahlen(liste)
        XCTAssertEqual(k[0].wert, "2")
        // Die Spanne kommt aus der chronologischen Liste, nicht aus der des Dienstes.
        XCTAssertEqual(k[0].dazu, "August 2026 bis Oktober 2026")
    }

    func testKopfkennzahlenBeanstandetZaehltWarnungUndFehler() {
        let liste = [
            zeile(nummer: "A", urteil: "ok"),
            zeile(nummer: "B", urteil: "info"),
            zeile(nummer: "C", urteil: "warning"),
            zeile(nummer: "D", urteil: "error"),
        ]
        let k = Rechnungspruefung.kopfkennzahlen(liste)
        XCTAssertEqual(k[1].wert, "2")
        XCTAssertEqual(k[1].dazu, "Befunde unten ansehen")
        XCTAssertEqual(k[1].ton, .alarm)
    }

    /// Ein unbekanntes Urteil ist keine Beanstandung: der Dienst hat nichts gemeldet, was wie
    /// ein Fehler aussieht.
    func testKopfkennzahlenBeanstandetZaehltUnbekanntesNicht() {
        let k = Rechnungspruefung.kopfkennzahlen([zeile(urteil: "pending")])
        XCTAssertEqual(k[1].wert, "0")
    }

    func testKopfkennzahlenSummeUndMenge() {
        let liste = [
            zeile(nummer: "A", kwh: 400, brutto: 119.95),
            zeile(nummer: "B", kwh: 250.4, brutto: 80.05),
        ]
        let k = Rechnungspruefung.kopfkennzahlen(liste)
        XCTAssertEqual(k[2].wert, "200,00\u{202F}€")
        XCTAssertEqual(k[2].dazu, "über 650\u{202F}kWh")
    }

    /// **Mengengewichtet, nicht Mittel der Mittel.** 100 kWh zu 40 ct und 900 kWh zu 30 ct
    /// ergeben 31,00 ct - der schlichte Mittelwert wäre 35,00 und damit eine Zahl, die kein
    /// Monat hergibt.
    func testKopfkennzahlenPreisIstMengengewichtet() {
        let liste = [
            zeile(nummer: "A", kwh: 100, mittel: 40),
            zeile(nummer: "B", kwh: 900, mittel: 30),
        ]
        let k = Rechnungspruefung.kopfkennzahlen(liste)
        XCTAssertEqual(k[3].wert, "31,00")
        XCTAssertEqual(k[3].dazu, "mengengewichtet über alle Rechnungen")
    }

    func testKopfkennzahlenPreisOhneMengeIstEinStrich() {
        let k = Rechnungspruefung.kopfkennzahlen([zeile(kwh: 0, mittel: 31.4)])
        XCTAssertEqual(k[3].wert, Formate.leer)
    }

    // MARK: - Diagramm 1

    func testMengenpaareNehmenDasKuerzelUndLassenFehlendesLeer() {
        let liste = [
            zeile(nummer: "B", zeitraum: "Oktober 2026", start: "2026-10-01", gemessen: nil),
            zeile(
                nummer: "A", zeitraum: "September 2026", start: "2026-09-01", kwh: 310,
                gemessen: 308.2),
        ]
        let p = Rechnungspruefung.mengenpaare(liste)
        XCTAssertEqual(p.map(\.wort), ["Sep 2026", "Okt 2026"])
        XCTAssertEqual(p[0].rechnung, 310)
        XCTAssertEqual(p[0].messung, 308.2)
        XCTAssertNil(p[1].messung)
    }

    // MARK: - Diagramm 2

    func testBetragsreihenSindDreiInDerReihenfolgeDesStapels() {
        let r = Rechnungspruefung.betragsreihen([zeile()])
        XCTAssertEqual(
            r.map(\.name), ["Arbeitspreis netto", "Grundgebühr netto", "Mehrwertsteuer"])
        XCTAssertEqual(r.map(\.ton), [.bernstein, .grundgebuehr, .umsatzsteuer])
        XCTAssertEqual(r[0].werte.first?.wert, 82)
        XCTAssertEqual(r[1].werte.first?.wert, 18)
        XCTAssertEqual(r[0].werte.first?.wort, "Okt 2026")
    }

    /// **Die Mehrwertsteuer wird auf den Cent gerundet** (`InvoiceCheck.tsx:173`). Ohne das
    /// trägt jeder Monat seinen Gleitkommarest in den Stapel.
    func testUmsatzsteuerWirdAufDenCentGerundet() {
        XCTAssertEqual(Rechnungspruefung.umsatzsteuer(123.45, netto: 103.74), 19.71)
        XCTAssertEqual(Rechnungspruefung.umsatzsteuer(119, netto: 100), 19)
        // Genau auf der halben Stelle, und darstellbar (100,125 ist 100 + 1/8): aufwärts, wie
        // `Math.round`.
        XCTAssertEqual(Rechnungspruefung.umsatzsteuer(100.125, netto: 100), 0.13)
    }

    /// **Die halbe Stelle geht aufwärts, auch im Negativen** - `Math.round(-12.5)` ist −12, und
    /// `Double.rounded()` wäre −13. Bei einer Gutschrift von genau einem halben Cent wären App
    /// und Browser sonst um einen Cent auseinander.
    func testUmsatzsteuerRundetDieHalbeStelleWieMathRound() {
        XCTAssertEqual(Rechnungspruefung.umsatzsteuer(99.875, netto: 100), -0.12)
    }

    func testUmsatzsteuerDarfNichtNegativWerdenOhneGrund() {
        // Netto über Brutto kommt bei einer Gutschrift vor; gerechnet wird trotzdem die
        // Differenz und nicht ihr Betrag - eine verschwiegene Gutschrift wäre eine Erfindung.
        XCTAssertEqual(Rechnungspruefung.umsatzsteuer(100, netto: 119), -19)
    }

    // MARK: - Diagramm 3

    func testPreisreiheNimmtBeideWerte() {
        let p = Rechnungspruefung.preisreihe([zeile(gemessenPreis: nil), zeile(nummer: "B")])
        XCTAssertEqual(p.count, 2)
        XCTAssertNil(p[0].eigene)
        XCTAssertEqual(p[1].eigene, 31.2)
        XCTAssertEqual(p[0].rechnung, 31.45)
    }

    /// **Die Achse fängt nicht bei Null an** (`charts.ts:336`: `scale: true`). Zwei Reihen
    /// zwischen 30 und 32 ct bekommen eine Spanne um diese Werte - mit der Null im Bild wären
    /// die Linien nicht mehr zu trennen.
    func testPreisspanneLaesstDieNullWeg() {
        let punkte = [
            Rechnungspruefung.Preispunkt(wort: "Okt 2026", rechnung: 31.4, eigene: 30.2),
            Rechnungspruefung.Preispunkt(wort: "Nov 2026", rechnung: 32.1, eigene: 31.0),
        ]
        let spanne = Rechnungspruefung.preisspanne(punkte)
        XCTAssertNotNil(spanne)
        XCTAssertGreaterThan(spanne?.lowerBound ?? 0, 20)
        XCTAssertLessThan(spanne?.lowerBound ?? 0, 30.2)
        XCTAssertGreaterThan(spanne?.upperBound ?? 0, 32.1)
    }

    /// Ein Jahr mit stabilem Preis bekommt trotzdem vier Cent Spanne - sonst sieht jedes
    /// Zehntel wie ein Ausschlag aus.
    func testPreisspanneHatEineMindestbreite() {
        let punkte = [
            Rechnungspruefung.Preispunkt(wort: "Okt 2026", rechnung: 31.0, eigene: 31.05)
        ]
        let spanne = Rechnungspruefung.preisspanne(punkte)
        XCTAssertNotNil(spanne)
        XCTAssertGreaterThanOrEqual(
            (spanne?.upperBound ?? 0) - (spanne?.lowerBound ?? 0), 4)
    }

    func testPreisspanneOhneWerteIstLeer() {
        XCTAssertNil(Rechnungspruefung.preisspanne([]))
    }

    // MARK: - Diagramm 4

    func testPositionsbalkenBehaltenDieReihenfolgeDerRechnung() {
        let b = Rechnungspruefung.positionsbalken([
            position("Energie", gruppe: "Stromeinkauf", ct: 22.5),
            position("Netzentgelt", gruppe: "Netz", ct: 9),
            position("Stromsteuer", gruppe: "Steuern, Abgaben & Umlagen", ct: 2.05),
        ])
        XCTAssertEqual(b.map(\.wort), ["Energie", "Netzentgelt", "Stromsteuer"])
        XCTAssertEqual(b.map(\.ton), [.bernstein, .nebel, .grundgebuehr])
    }

    /// Drei Stellen am Balkenende (`charts.ts:364`), nicht die `ctDecimals` der Position: die
    /// Vorlage schreibt hier `de1(value, 3)` und lässt das Feld beiseite.
    func testPositionsbalkenZeigenDreiStellen() {
        let b = Rechnungspruefung.positionsbalken([position("Netz", ct: 9.0765, stellen: 2)])
        XCTAssertEqual(b.first?.wert, "9,077")
    }

    func testPositionsbalkenAnteilGegenDieGroessteStelle() {
        let b = Rechnungspruefung.positionsbalken([
            position("Gross", ct: 20), position("Halb", ct: 10), position("Null", ct: 0),
        ])
        XCTAssertEqual(b[0].anteil, 1)
        XCTAssertEqual(b[1].anteil, 0.5)
        XCTAssertEqual(b[2].anteil, 0)
    }

    /// Eine Gutschrift bekommt keine Länge: eine Leiste nach links ist in dieser Darstellung
    /// nicht vorgesehen, und eine nach rechts wäre eine falsche Aussage.
    func testPositionsbalkenNegativeStelleOhneLaenge() {
        let b = Rechnungspruefung.positionsbalken([
            position("Gross", ct: 20), position("Gutschrift", ct: -3),
        ])
        XCTAssertEqual(b[1].anteil, 0)
        XCTAssertEqual(b[1].wert, "\u{2212}3,000")
    }

    func testPositionsbalkenOhnePositionen() {
        XCTAssertTrue(Rechnungspruefung.positionsbalken([]).isEmpty)
    }

    /// Eine neue Gruppe des Dienstes fällt nicht durch, sondern wird wie die Abgaben
    /// gezeichnet - so macht es das `?? C.base` der Vorlage.
    func testGruppentonFaelltAufDieAbgabenZurueck() {
        XCTAssertEqual(Rechnungspruefung.gruppenton("Etwas Neues"), .grundgebuehr)
        XCTAssertEqual(Rechnungspruefung.gruppenton(""), .grundgebuehr)
    }

    // MARK: - Die Ablesezeile

    func testMengenablesungNenntBeideReihen() {
        let paare = Rechnungspruefung.mengenpaare([zeile(kwh: 400.44, gemessen: 398.36)])
        let z = Rechnungspruefung.mengenablesung(wort: "Okt 2026", paare: paare)
        XCTAssertEqual(z.map(\.text), ["Rechnung: 400,4\u{202F}kWh", "Eigene Messung: 398,4\u{202F}kWh"])
        XCTAssertEqual(z.map(\.ton), [.netz, .nebel])
    }

    /// Ohne eigene Messung steht ein Strich und keine Null.
    func testMengenablesungOhneMessung() {
        let paare = Rechnungspruefung.mengenpaare([zeile(gemessen: nil)])
        let z = Rechnungspruefung.mengenablesung(wort: "Okt 2026", paare: paare)
        XCTAssertEqual(z[1].text, "Eigene Messung: -")
    }

    func testMengenablesungAnEinerUnbekanntenStelle() {
        let paare = Rechnungspruefung.mengenpaare([zeile()])
        XCTAssertTrue(Rechnungspruefung.mengenablesung(wort: "Mai 2019", paare: paare).isEmpty)
    }

    func testBetragsablesungNenntDreiBetraege() {
        let reihen = Rechnungspruefung.betragsreihen([zeile()])
        let z = Rechnungspruefung.betragsablesung(wort: "Okt 2026", reihen: reihen)
        XCTAssertEqual(
            z.map(\.text),
            [
                "Arbeitspreis netto: 82,00\u{202F}€", "Grundgebühr netto: 18,00\u{202F}€",
                "Mehrwertsteuer: 19,00\u{202F}€",
            ])
    }

    /// **Zwei Stellen am Preis, nicht eine.** ``Formate/ct(_:)`` nimmt eine; auf dieser Seite
    /// entscheidet der zweite Cent, ob der abgerechnete Preis zum eigenen passt.
    func testPreisablesungMitZweiStellenUndStrich() {
        let punkte = Rechnungspruefung.preisreihe([zeile(gemessenPreis: nil, mittel: 31.456)])
        let z = Rechnungspruefung.preisablesung(wort: "Okt 2026", punkte: punkte)
        XCTAssertEqual(
            z.map(\.text), ["Rechnung (brutto): 31,46\u{202F}ct/kWh", "Eigene Preisreihe: -"])
    }

    func testReihennamenUndToene() {
        XCTAssertEqual(
            Rechnungspruefung.mengenreihen.map(\.name), ["Rechnung", "Eigene Messung"])
        XCTAssertEqual(
            Rechnungspruefung.preisreihen.map(\.name),
            ["Rechnung (brutto)", "Eigene Preisreihe"])
        // Die abgerechnete Menge ist rot wie `C.grid`, nicht bernstein.
        XCTAssertEqual(Rechnungspruefung.mengenreihen.first?.ton, .netz)
    }

    // MARK: - Die Tabellenspalte „Eigene Messung“

    func testMessungsspalteOhneMessungIstEinStrich() {
        XCTAssertEqual(Rechnungspruefung.messungsspalte(zeile(gemessen: nil)), Formate.leer)
        XCTAssertEqual(Rechnungspruefung.messungsspalte(zeile(gemessen: 0)), Formate.leer)
    }

    func testMessungsspalteOhneAbdeckungsangabe() {
        XCTAssertEqual(
            Rechnungspruefung.messungsspalte(zeile(gemessen: 398.44, abdeckung: nil)),
            "398,4\u{202F}kWh")
    }

    /// **Die Schwelle liegt bei 98 %** (`InvoiceCheck.tsx:286`): genau 98 schweigt, 97 nicht.
    func testMessungsspalteNenntDieAbdeckungErstUnter98Prozent() {
        XCTAssertEqual(
            Rechnungspruefung.messungsspalte(zeile(gemessen: 398.4, abdeckung: 0.98)),
            "398,4\u{202F}kWh")
        XCTAssertEqual(
            Rechnungspruefung.messungsspalte(zeile(gemessen: 398.4, abdeckung: 0.9749)),
            "398,4\u{202F}kWh (97\u{202F}%)")
    }

    // MARK: - Die Tabellenzeilen

    func testTabellenzeilenFormatierenAlleSpalten() {
        let z = Rechnungspruefung.tabellenzeilen([
            zeile(
                nummer: "R-7", kwh: 412.345, gemessen: 408.76, abdeckung: 0.95, netto: 103.74,
                brutto: 123.45, mittel: 29.94, urteil: "warning", probleme: 2)
        ])
        XCTAssertEqual(z.count, 1)
        XCTAssertEqual(z[0].nummer, "R-7")
        XCTAssertEqual(z[0].zeitraum, "Oktober 2026")
        XCTAssertEqual(z[0].menge, "412,35\u{202F}kWh")
        XCTAssertEqual(z[0].messung, "408,8\u{202F}kWh (95\u{202F}%)")
        // „ct“ und nicht „ct/kWh“: der Spaltenkopf sagt „Ø brutto“.
        XCTAssertEqual(z[0].preis, "29,94\u{202F}ct")
        XCTAssertEqual(z[0].netto, "103,74\u{202F}€")
        XCTAssertEqual(z[0].brutto, "123,45\u{202F}€")
        XCTAssertEqual(z[0].ergebnis.text, "auffällig (2)")
        XCTAssertEqual(z[0].ergebnis.ton, .alarm)
    }

    /// **Die Tabelle bleibt in der Reihenfolge des Dienstes** (`InvoiceCheck.tsx:269`): dort
    /// führt die neueste Rechnung, und die ist die, nach der jemand sucht. Nur die Diagramme
    /// sortieren.
    func testTabellenzeilenBleibenUnsortiert() {
        let liste = [
            zeile(nummer: "neu", start: "2026-10-01"), zeile(nummer: "alt", start: "2026-01-01"),
        ]
        XCTAssertEqual(Rechnungspruefung.tabellenzeilen(liste).map(\.nummer), ["neu", "alt"])
    }

    // MARK: - Die Ergebnisspalte

    func testErgebnisNenntWortUndZahl() {
        XCTAssertEqual(
            Rechnungspruefung.ergebnis("warning", probleme: 2).text, "auffällig (2)")
        XCTAssertEqual(Rechnungspruefung.ergebnis("warning", probleme: 2).ton, .alarm)
        XCTAssertEqual(
            Rechnungspruefung.ergebnis("error", probleme: 1).text, "Rechenfehler (1)")
    }

    func testErgebnisOhneBefundeOhneKlammer() {
        XCTAssertEqual(
            Rechnungspruefung.ergebnis("ok", probleme: 0).text, "geprüft, alles stimmig")
        XCTAssertEqual(Rechnungspruefung.ergebnis("ok", probleme: 0).ton, .bernstein)
    }

    /// Ein `ok` mit Befunden behält sein Wort und bekommt die Zahl dazu - die Vorlage knüpft die
    /// Klammer allein an `problems > 0`, nicht an die Schwere.
    func testErgebnisZeigtDieZahlAuchBeiOk() {
        XCTAssertEqual(
            Rechnungspruefung.ergebnis("ok", probleme: 3).text, "geprüft, alles stimmig (3)")
    }

    /// **Ein unbekanntes Wort wird wie `info` dargestellt** (`InvoiceCheck.tsx:272`). In einer
    /// Tabellenspalte neben vier deutschen Sätzen sähe ein englisches Rohwort wie ein Fehler
    /// der App aus.
    func testErgebnisFaelltBeiUnbekanntemWortAufHinweisZurueck() {
        let e = Rechnungspruefung.ergebnis("pending", probleme: 0)
        XCTAssertEqual(e.text, "geprüft, mit Hinweisen")
        XCTAssertEqual(e.ton, .nebel)
    }

    // MARK: - Die Befunde

    func testGerechnetUndVerglichenTeilenNachCode() {
        let alle = [
            befund("vat", .ok), befund("measured_kwh", .warning), befund("base_fee", .error),
            befund("coverage", .info), befund("no_measurement", .info),
            befund("measured_price", .ok),
        ]
        XCTAssertEqual(Rechnungspruefung.gerechnet(alle).map(\.code), ["base_fee", "vat"])
        XCTAssertEqual(
            Rechnungspruefung.verglichen(alle).map(\.code),
            ["measured_kwh", "coverage", "no_measurement", "measured_price"])
    }

    /// Fehler, Warnung, Hinweis, in Ordnung - und Unbekanntes zuletzt (`InvoiceCheck.tsx:19`).
    func testBefundeStehenNachSchwere() {
        let alle = [
            befund("a", .ok), befund("b", .unbekannt), befund("c", .info),
            befund("d", .error), befund("e", .warning),
        ]
        XCTAssertEqual(
            Rechnungspruefung.gerechnet(alle).map(\.code), ["d", "e", "c", "a", "b"])
    }

    /// Gleiche Schwere: die Reihenfolge des Dienstes bleibt. `sorted(by:)` ist nicht stabil, die
    /// Vorlage sortiert stabil - ohne die Eingangsstelle stünden zwei Rechenfehler in
    /// zufälliger Folge.
    func testBefundeGleicherSchwereBleibenInEingangsreihenfolge() {
        let alle = [
            befund("erst", .error), befund("dann", .error), befund("zuletzt", .error),
        ]
        XCTAssertEqual(
            Rechnungspruefung.gerechnet(alle).map(\.code), ["erst", "dann", "zuletzt"])
    }

    func testStimmigZaehltDieOkBefunde() {
        let alle = [befund("a", .ok), befund("b", .ok), befund("c", .warning)]
        XCTAssertEqual(Rechnungspruefung.stimmig(alle), "2 von 3 stimmig")
        XCTAssertEqual(Rechnungspruefung.stimmig([]), "0 von 0 stimmig")
    }

    // MARK: - Die Zahlen eines Befunds

    /// **Nur wenn beide Werte da sind.** Die App zeigte sie, sobald einer dastand.
    func testBefundzahlenBrauchenBeideWerte() {
        XCTAssertNil(
            Rechnungspruefung.befundzahlen(befund("a", .ok, erwartet: 31.2, tatsaechlich: nil)))
        XCTAssertNil(
            Rechnungspruefung.befundzahlen(befund("a", .ok, erwartet: nil, tatsaechlich: 31.2)))
        XCTAssertNil(Rechnungspruefung.befundzahlen(befund("a", .ok)))
    }

    func testBefundzahlenMitEinheit() {
        let f = befund("a", .warning, erwartet: 31.2, tatsaechlich: 31.45, einheit: "ct/kWh")
        XCTAssertEqual(
            Rechnungspruefung.befundzahlen(f), "31,20 erwartet · 31,45\u{202F}ct/kWh")
    }

    func testBefundzahlenOhneEinheitOhneLeerzeichen() {
        let f = befund("a", .ok, erwartet: 3, tatsaechlich: 3)
        XCTAssertEqual(Rechnungspruefung.befundzahlen(f), "3,00 erwartet · 3,00")
    }

    /// **Das Delta erst ab 0,005** (`InvoiceCheck.tsx:44`). Darunter rundet es auf „0,00“, und
    /// ein angehängtes „· 0,00“ behauptet eine Abweichung, die es nicht gibt.
    func testBefundzahlenDeltaSchwelle() {
        let knappDarunter = befund(
            "a", .ok, erwartet: 10, tatsaechlich: 10, einheit: "kWh", delta: 0.004)
        XCTAssertEqual(
            Rechnungspruefung.befundzahlen(knappDarunter), "10,00 erwartet · 10,00\u{202F}kWh")
        let knappDarueber = befund(
            "a", .ok, erwartet: 10, tatsaechlich: 10.01, einheit: "kWh", delta: 0.006)
        XCTAssertEqual(
            Rechnungspruefung.befundzahlen(knappDarueber),
            "10,00 erwartet · 10,01\u{202F}kWh · +0,01")
    }

    /// Ein negatives Delta trägt das echte Minuszeichen der Anzeige und kein zweites Vorzeichen.
    func testBefundzahlenNegativesDelta() {
        let f = befund("a", .error, erwartet: 10, tatsaechlich: 9.5, einheit: "kWh", delta: -0.5)
        XCTAssertEqual(
            Rechnungspruefung.befundzahlen(f),
            "10,00 erwartet · 9,50\u{202F}kWh · \u{2212}0,50")
    }

    func testBefundzahlenTonUndPunktfarbe() {
        XCTAssertEqual(Rechnungspruefung.befundzahlenton(.ok), .leise)
        XCTAssertEqual(Rechnungspruefung.befundzahlenton(.info), .alarm)
        XCTAssertEqual(Rechnungspruefung.befundton(.error), .alarm)
        XCTAssertEqual(Rechnungspruefung.befundton(.warning), .alarm)
        XCTAssertEqual(Rechnungspruefung.befundton(.info), .nebel)
        // `ok` ist bernstein und nicht grün - wie in der Vorlage.
        XCTAssertEqual(Rechnungspruefung.befundton(.ok), .bernstein)
        XCTAssertEqual(Rechnungspruefung.befundton(.unbekannt), .bernstein)
    }

    // MARK: - Die Fußzeile

    func testZaehlerzeileAbgelesen() {
        XCTAssertEqual(
            Rechnungspruefung.zaehlerzeile(rechnung()),
            "Zeitraum 2026-10-01 bis 2026-10-31 · Zählerstand 41203,40 → 41615,80\u{202F}kWh "
                + "(abgelesen)")
    }

    func testZaehlerzeileErrechnet() {
        let z = Rechnungspruefung.zaehlerzeile(rechnung(geschaetzt: true))
        XCTAssertTrue(z.hasSuffix("(errechnet)"), z)
    }

    /// Ohne Angabe gilt „abgelesen“ - so wie das `? :` der Vorlage, dem `null` falsch ist.
    func testZaehlerzeileOhneAngabeGiltAbgelesen() {
        let z = Rechnungspruefung.zaehlerzeile(rechnung(geschaetzt: nil))
        XCTAssertTrue(z.hasSuffix("(abgelesen)"), z)
    }

    func testZaehlerzeileOhneZaehlerstand() {
        let z = Rechnungspruefung.zaehlerzeile(rechnung(zaehlerVon: nil, zaehlerBis: nil))
        XCTAssertTrue(z.contains("Zählerstand - → -"), z)
    }

    // MARK: - Auswahl und Fehlerzeile

    func testErstauswahlNimmtDieNeuesteDerUnsortiertenListe() {
        let liste = [zeile(nummer: "neu", start: "2026-10-01"), zeile(nummer: "alt", start: "2026-01-01")]
        XCTAssertEqual(Rechnungspruefung.erstauswahl(liste), "neu")
    }

    func testErstauswahlBevorzugtDieGewuenschteNummer() {
        let liste = [zeile(nummer: "neu"), zeile(nummer: "alt")]
        XCTAssertEqual(Rechnungspruefung.erstauswahl(liste, gewuenscht: "alt"), "alt")
    }

    /// Eine unbekannte Nummer fällt **still** auf die neueste zurück - keine Fehlermeldung über
    /// eine Rechnung, die jemand vielleicht nie hatte.
    func testErstauswahlFaelltBeiUnbekannterNummerZurueck() {
        let liste = [zeile(nummer: "neu"), zeile(nummer: "alt")]
        XCTAssertEqual(Rechnungspruefung.erstauswahl(liste, gewuenscht: "gibtsnicht"), "neu")
    }

    func testErstauswahlOhneRechnungen() {
        XCTAssertNil(Rechnungspruefung.erstauswahl([], gewuenscht: "R-1"))
    }

    func testDateifehlerzeileVerbindetMitPunkt() {
        XCTAssertNil(Rechnungspruefung.dateifehlerzeile([]))
        XCTAssertEqual(
            Rechnungspruefung.dateifehlerzeile([
                (name: "okt.pdf", rat: "Kein PDF."), (name: "nov.pdf", rat: "Nicht lesbar."),
            ]),
            "okt.pdf: Kein PDF. · nov.pdf: Nicht lesbar.")
    }

    // MARK: - Das Ablegefeld

    func testAblegetextAmSchirmNenntDasZiehen() {
        let t = Rechnungspruefung.ablegetext(laeuft: false, ziehbar: true)
        XCTAssertEqual(t.satz, "Tibber-Rechnung hierher ziehen")
        XCTAssertEqual(t.dazu, "oder klicken, um PDFs auszuwählen - mehrere auf einmal möglich")
    }

    /// **„Hierher ziehen“ ist an einem Telefon eine falsche Anweisung.** Dort steht der Satz,
    /// der stimmt.
    func testAblegetextOhneZiehenNenntDasAuswaehlen() {
        let t = Rechnungspruefung.ablegetext(laeuft: false, ziehbar: false)
        XCTAssertEqual(t.satz, "Tibber-Rechnung auswählen")
        XCTAssertFalse(t.dazu.contains("ziehen"))
    }

    /// Während des Prüfens tauschen beide Zeilen, nicht nur die obere - und das unabhängig
    /// davon, ob gezogen werden kann.
    func testAblegetextWaehrendDesPruefens() {
        for ziehbar in [true, false] {
            let t = Rechnungspruefung.ablegetext(laeuft: true, ziehbar: ziehbar)
            XCTAssertEqual(t.satz, "Rechnung wird geprüft …")
            XCTAssertEqual(t.dazu, "Positionen werden nachgerechnet")
        }
    }

    // MARK: - Die Wortlaute

    /// Die Sätze der Vorlage, wörtlich - sie sind der Grund, warum sie im Kern stehen.
    func testWortlauteStimmenMitDerVorlage() {
        XCTAssertEqual(
            Rechnungspruefung.seitenkicker,
            "Tibber · nachgerechnet und gegen die eigene Messung gehalten")
        XCTAssertEqual(Rechnungspruefung.gespeichert(1), "1 gespeichert")
        XCTAssertEqual(Rechnungspruefung.gespeichert(0), "0 gespeichert")
        XCTAssertEqual(
            Rechnungspruefung.gerechnetTitel("Oktober 2026"),
            "Rechnerische Prüfung · Oktober 2026")
        XCTAssertEqual(Rechnungspruefung.tabellenspalten.count, 8)
        XCTAssertEqual(Rechnungspruefung.tabellenspalten.first, "Zeitraum")
        XCTAssertEqual(Rechnungspruefung.tabellenspalten.last, "Ergebnis")
        XCTAssertTrue(
            Rechnungspruefung.hinweis.hasSuffix("Das PDF selbst wird nicht gespeichert."),
            Rechnungspruefung.hinweis)
        XCTAssertFalse(Rechnungspruefung.leerSatz.contains("RECHNUNGSPRUEFUNG"))
    }
}
