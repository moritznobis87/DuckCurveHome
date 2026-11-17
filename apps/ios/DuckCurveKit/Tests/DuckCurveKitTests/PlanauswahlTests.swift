import XCTest

@testable import DuckCurveKit

final class PlanauswahlTests: XCTestCase {
    private func iv(_ stunde: Int, _ preis: Double?) -> PlanIntervalOut {
        PlanIntervalOut(
            ts: String(format: "2026-11-17T%02d:00:00+01:00", stunde),
            expectedPvKw: 0, priceCtKwh: preis, plannedHpState: .off, reasonCode: "x"
        )
    }

    func testDieDreiTeuerstenUndDieDreiBilligsten() {
        let plan = (0..<10).map { iv($0, Double(20 + $0)) }   // 20 … 29 ct
        let aus = Planauswahl.raender(plan)
        XCTAssertEqual(aus.count, 6)
        let preise = aus.compactMap(\.priceCtKwh).sorted()
        XCTAssertEqual(preise, [20, 21, 22, 27, 28, 29])
    }

    /// Angezeigt wird nach der Uhr, ausgewaehlt nach dem Preis - sonst springt die Liste.
    func testDieAuswahlStehtInZeitlicherReihenfolge() {
        let plan = (0..<10).map { iv($0, Double(29 - $0)) }
        let aus = Planauswahl.raender(plan)
        XCTAssertEqual(aus.map(\.ts), aus.map(\.ts).sorted())
    }

    func testOhnePreisFaelltEineViertelstundeWeg() {
        let plan = [iv(0, nil), iv(1, 30), iv(2, nil), iv(3, 20)]
        let aus = Planauswahl.raender(plan)
        XCTAssertEqual(aus.count, 2)
        XCTAssertTrue(aus.allSatisfy { $0.priceCtKwh != nil })
    }

    func testEinKurzerPlanWirdNichtVerdoppelt() {
        // Vier Viertelstunden: die drei teuersten und die drei billigsten ueberschneiden sich.
        let aus = Planauswahl.raender([iv(0, 10), iv(1, 20), iv(2, 30), iv(3, 40)])
        XCTAssertEqual(aus.count, 4, "jede Viertelstunde hoechstens einmal")
        XCTAssertEqual(Set(aus.map(\.ts)).count, 4)
    }

    func testOhnePreiseKeineAuswahl() {
        XCTAssertTrue(Planauswahl.raender([]).isEmpty)
        XCTAssertTrue(Planauswahl.raender([iv(0, nil), iv(1, nil)]).isEmpty)
        XCTAssertTrue(Planauswahl.raender([iv(0, 10)], je: 0).isEmpty)
    }

    // MARK: - Der Bedarf

    func testBedarfIstHeizungUndWarmwasser() {
        var a = iv(0, 10); a.heatDemandKw = 2.0; a.dhwDemandKw = 0.5
        XCTAssertEqual(Planauswahl.bedarf(a)!, 2.5, accuracy: 1e-9)
    }

    func testOhneWarmwasserNurDieHeizung() {
        var a = iv(0, 10); a.heatDemandKw = 2.0
        XCTAssertEqual(Planauswahl.bedarf(a), 2.0)
    }

    func testOhneHeizungTrotzdemDasWarmwasser() {
        var a = iv(0, 10); a.dhwDemandKw = 0.8
        XCTAssertEqual(Planauswahl.bedarf(a), 0.8)
    }

    func testOhneBeidesNichts() {
        XCTAssertNil(Planauswahl.bedarf(iv(0, 10)))
    }
}
