import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/home/tage.ts`, Funktion `kennzahlen`.
final class TageskachelnTests: XCTestCase {

    private func totals(
        pv: Double? = nil, autarky: Double? = nil, kosten: Double? = nil, mittel: Double? = nil
    ) -> EnergyTotalsOut {
        EnergyTotalsOut(
            pvKwh: pv, importCostEur: kosten, autarky: autarky, avgImportPriceCt: mittel)
    }

    private func intervall(_ iso: String, pv: Double = 0, preis: Double? = nil) -> PlanIntervalOut {
        PlanIntervalOut(
            ts: iso, expectedPvKw: pv, priceCtKwh: preis, plannedHpState: .free,
            reasonCode: "none")
    }

    private func punkt(_ iso: String, heizung: Double, warmwasser: Double, strom: Double)
        -> HeatForecastPoint
    {
        HeatForecastPoint(
            ts: iso, outdoorC: 4, heatingKw: heizung, dhwKw: warmwasser, cop: 3.5,
            electricKw: strom)
    }

    // MARK: - Gestern und heute

    func testHeuteZeigtAutarkieGeldUndDenPreisInDiesemAugenblick() {
        let k = Tageskacheln.kennzahlen(
            tag: .heute, bilanz: totals(pv: 13.42, autarky: 0.734, kosten: 1.278),
            preisJetzt: 24.91, morgen: .init())
        XCTAssertEqual(k.count, 4)
        XCTAssertEqual(k[0].wort, "Sonne geerntet")
        XCTAssertEqual(k[0].wert, "13,4")
        XCTAssertEqual(k[0].ton, .sonne)
        XCTAssertEqual(k[1].wort, "ohne Netz")
        XCTAssertEqual(k[1].wert, "73")
        XCTAssertEqual(k[1].einheit, "%")
        XCTAssertEqual(k[2].wort, "bezahlt bis jetzt")
        XCTAssertEqual(k[2].wert, "1,28")
        XCTAssertEqual(k[2].einheit, "€")
        XCTAssertEqual(k[3].wort, "Strom gerade")
        XCTAssertEqual(k[3].wert, "24,9")
    }

    func testGesternIstAbgerechnetUndZeigtDenMittelpreis() {
        let k = Tageskacheln.kennzahlen(
            tag: .gestern, bilanz: totals(pv: 9.0, autarky: 0.51, kosten: 2.4, mittel: 21.37),
            preisJetzt: 24.91, morgen: .init())
        XCTAssertEqual(k[2].wort, "bezahlt")
        XCTAssertEqual(k[3].wort, "Strom im Mittel")
        XCTAssertEqual(k[3].wert, "21,4")
    }

    func testEinNegativerPreisIstEinGewinnUndStehtGelbDa() {
        let k = Tageskacheln.kennzahlen(
            tag: .heute, bilanz: nil, preisJetzt: -3.2, morgen: .init())
        XCTAssertEqual(k[3].ton, .sonne)
    }

    func testOhneBilanzStehenStricheUndDieZeileSpringtNicht() {
        let k = Tageskacheln.kennzahlen(tag: .heute, bilanz: nil, preisJetzt: nil, morgen: .init())
        XCTAssertEqual(k.count, 4)
        XCTAssertEqual(k.map(\.wert), [Formate.leer, Formate.leer, Formate.leer, Formate.leer])
        XCTAssertEqual(k[3].ton, .normal, "Ein fehlender Preis ist kein negativer Preis.")
    }

    func testAutarkieWirdAufGanzeProzentGerundet() {
        XCTAssertEqual(Tageskacheln.autarkie(0.734), "73")
        XCTAssertEqual(Tageskacheln.autarkie(0.735), "74")
        XCTAssertEqual(Tageskacheln.autarkie(1), "100")
        XCTAssertEqual(Tageskacheln.autarkie(0), "0")
        XCTAssertEqual(Tageskacheln.autarkie(nil), Formate.leer)
    }

    // MARK: - Morgen

    func testMorgenNenntDieGuenstigsteStundeMitUhrzeit() {
        let preise = [
            Tageskacheln.Preispunkt(zeit: Zeit.ausIso("2026-11-18T11:00:00+01:00")!, ct: 18.0),
            Tageskacheln.Preispunkt(zeit: Zeit.ausIso("2026-11-18T13:00:00+01:00")!, ct: -2.5),
            Tageskacheln.Preispunkt(zeit: Zeit.ausIso("2026-11-18T19:00:00+01:00")!, ct: 41.5),
        ]
        let k = Tageskacheln.kennzahlen(
            tag: .morgen, bilanz: nil, preisJetzt: nil,
            morgen: .init(
                pvKwh: 6.3, waerme: .init(thermisch: 28.4, elektrisch: 8.1), preise: preise))
        XCTAssertEqual(k[0].wort, "Sonne erwartet")
        XCTAssertEqual(k[0].wert, "6,3")
        XCTAssertEqual(k[1].wort, "Wärme erwartet")
        XCTAssertEqual(k[1].wert, "28,4")
        XCTAssertEqual(k[1].dazu, "dafür 8,1 kWh Strom")
        XCTAssertEqual(k[2].wort, "Strom im Mittel")
        XCTAssertEqual(k[2].wert, "19,0", "(18 - 2,5 + 41,5) / 3")
        XCTAssertEqual(k[3].wort, "günstigste Stunde ab 13:00")
        XCTAssertEqual(k[3].wert, Formate.minus + "2,5")
        XCTAssertEqual(k[3].ton, .sonne)
    }

    func testOhneVeroeffentlichtePreiseSagtDieKachelWarum() {
        let k = Tageskacheln.kennzahlen(
            tag: .morgen, bilanz: nil, preisJetzt: nil, morgen: .init(pvKwh: 6.3))
        XCTAssertEqual(k[2].wort, "Preise kommen gegen 13 Uhr")
        XCTAssertEqual(k[2].wert, Formate.leer)
        XCTAssertEqual(k[3].wort, "günstigste Stunde")
        XCTAssertNil(k[1].dazu, "Ohne Prognose auch kein Stromzusatz.")
    }

    // MARK: - Summen über ein Fenster

    func testPvSummeRechnetMitDemSchrittDesRastersUndNichtMitEinerAnnahme() {
        let von = Zeit.ausIso("2026-11-18T00:00:00+01:00")!
        let bis = von.addingTimeInterval(24 * 3600)
        let viertel = (0..<8).map {
            intervall(
                Zeit.iso(von.addingTimeInterval(Double($0) * 900)), pv: 2.0)
        }
        XCTAssertEqual(Tageskacheln.pvSumme(viertel, von: von, bis: bis)!, 4.0, accuracy: 1e-9)

        let stuendlich = (0..<8).map {
            intervall(Zeit.iso(von.addingTimeInterval(Double($0) * 3600)), pv: 2.0)
        }
        XCTAssertEqual(Tageskacheln.pvSumme(stuendlich, von: von, bis: bis)!, 16.0, accuracy: 1e-9)
    }

    func testPvSummeZaehltNurWasInsFensterFaellt() {
        let von = Zeit.ausIso("2026-11-18T00:00:00+01:00")!
        let bis = von.addingTimeInterval(24 * 3600)
        let iv =
            (0..<4).map { intervall(Zeit.iso(von.addingTimeInterval(Double($0) * 3600)), pv: 1) }
            + (0..<4).map { intervall(Zeit.iso(bis.addingTimeInterval(Double($0) * 3600)), pv: 9) }
        XCTAssertEqual(Tageskacheln.pvSumme(iv, von: von, bis: bis)!, 4.0, accuracy: 1e-9)
    }

    func testOhneZweiPunkteGibtEsKeinenSchrittUndDamitKeineSumme() {
        let von = Zeit.ausIso("2026-11-18T00:00:00+01:00")!
        XCTAssertNil(Tageskacheln.pvSumme([], von: von, bis: von.addingTimeInterval(3600)))
        XCTAssertNil(
            Tageskacheln.pvSumme(
                [intervall(Zeit.iso(von), pv: 3)], von: von, bis: von.addingTimeInterval(3600)))
    }

    func testPreiseOhnePreisFallenWeg() {
        let von = Zeit.ausIso("2026-11-18T00:00:00+01:00")!
        let bis = von.addingTimeInterval(24 * 3600)
        let iv = [
            intervall(Zeit.iso(von), preis: 12),
            intervall(Zeit.iso(von.addingTimeInterval(3600))),
            intervall(Zeit.iso(von.addingTimeInterval(7200)), preis: 14),
            intervall(Zeit.iso(bis.addingTimeInterval(3600)), preis: 99),
        ]
        let p = Tageskacheln.preise(iv, von: von, bis: bis)
        XCTAssertEqual(p.map(\.ct), [12, 14])
    }

    func testWaermeSummeZaehltHeizungUndWarmwasser() {
        let von = Zeit.ausIso("2026-11-18T00:00:00+01:00")!
        let bis = von.addingTimeInterval(24 * 3600)
        let p = [
            punkt(Zeit.iso(von), heizung: 2.0, warmwasser: 0.5, strom: 0.7),
            punkt(Zeit.iso(von.addingTimeInterval(3600)), heizung: 1.5, warmwasser: 0, strom: 0.4),
            punkt(Zeit.iso(bis), heizung: 9, warmwasser: 9, strom: 9),
        ]
        let w = Tageskacheln.waermeSumme(p, von: von, bis: bis)!
        XCTAssertEqual(w.thermisch, 4.0, accuracy: 1e-9)
        XCTAssertEqual(w.elektrisch, 1.1, accuracy: 1e-9)
    }

    func testOhneProgoseInDiesemFensterGibtEsKeineWaermemenge() {
        let von = Zeit.ausIso("2026-11-18T00:00:00+01:00")!
        XCTAssertNil(
            Tageskacheln.waermeSumme([], von: von, bis: von.addingTimeInterval(3600)))
        XCTAssertNil(
            Tageskacheln.waermeSumme(
                [punkt(Zeit.iso(von.addingTimeInterval(-3600)), heizung: 2, warmwasser: 0, strom: 1)],
                von: von, bis: von.addingTimeInterval(3600)))
    }

    func testFensterIstDerKalendertagInDerHauszeit() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        let heute = Tageskacheln.fenster(.heute, jetzt: jetzt)!
        XCTAssertEqual(Tag.iso(heute.von), "2026-11-17")
        XCTAssertEqual(heute.bis.timeIntervalSince(heute.von), 24 * 3600)
        XCTAssertEqual(Tag.iso(Tageskacheln.fenster(.gestern, jetzt: jetzt)!.von), "2026-11-16")
        XCTAssertEqual(Tag.iso(Tageskacheln.fenster(.morgen, jetzt: jetzt)!.von), "2026-11-18")
    }
}
