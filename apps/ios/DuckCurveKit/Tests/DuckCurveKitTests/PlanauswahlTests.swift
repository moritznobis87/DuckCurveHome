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

    // MARK: - Die Entscheidungen

    private func voll(_ stunde: Int, preis: Double?, zustand: PlanIntervalOutPlannedHpStateWahl,
                      ofen: Bool?, notiz: String?) -> PlanIntervalOut {
        PlanIntervalOut(
            ts: String(format: "2026-11-17T%02d:00:00+01:00", stunde),
            expectedPvKw: 0, priceCtKwh: preis, plannedHpState: zustand, plannedStoveOn: ofen,
            reasonCode: "price_rule", noteDe: notiz, heatDemandKw: 2, dhwDemandKw: 0.5,
            bufferKwh: 12)
    }

    /// Der Fehler, der diesen Typ noetig gemacht hat: die Ansicht hatte `release` auf „frei"
    /// abgebildet - und „frei" ist der Name eines anderen Zustands.
    func testDasWortDesZustandsIstDasDerZeichnung() {
        let plan = [
            voll(0, preis: 40, zustand: .release, ofen: true, notiz: "teuer, aber noetig"),
            voll(1, preis: 10, zustand: .free, ofen: false, notiz: nil),
        ]
        let e = Planauswahl.entscheidungen(plan)
        XCTAssertEqual(e.count, 2)
        XCTAssertEqual(e[0].zustandswort, "angefordert")
        XCTAssertEqual(e[0].zustandsrolle, .angefordert)
        XCTAssertEqual(e[1].zustandswort, "frei")
        XCTAssertEqual(e[1].zustandsrolle, .frei)
        XCTAssertEqual(
            e[0].zustandswort, Fahrplanbild.zustand(.release).wort,
            "dasselbe Wort wie im Streifen darueber")
    }

    func testDerOfenHatDreiZustaendeUndEinerDavonIstNichts() {
        let e = Planauswahl.entscheidungen([
            voll(0, preis: 40, zustand: .off, ofen: true, notiz: nil),
            voll(1, preis: 30, zustand: .off, ofen: false, notiz: nil),
            voll(2, preis: 10, zustand: .off, ofen: nil, notiz: nil),
        ])
        XCTAssertEqual(e.map(\.ofenwort), ["brennt", "aus", Formate.leer])
        XCTAssertEqual(e.map(\.ofenrolle), [.ofenAn, .ofenAus, .neutral])
    }

    func testDerSatzDesDienstesSchlaegtSeinenSchluessel() {
        let e = Planauswahl.entscheidungen([
            voll(0, preis: 40, zustand: .avoid, ofen: nil, notiz: "Strom ist teuer"),
            voll(1, preis: 10, zustand: .release, ofen: nil, notiz: nil),
        ])
        XCTAssertEqual(e[0].warum, "Strom ist teuer")
        XCTAssertEqual(e[1].warum, "price rule", "ohne Satz die Kennung in Worten - leer bleibt es nie")
    }

    func testDerBedarfIstHeizenUndWarmwasser() {
        let e = Planauswahl.entscheidungen([voll(0, preis: 40, zustand: .off, ofen: nil, notiz: nil)])
        XCTAssertEqual(e[0].bedarf ?? 0, 2.5, accuracy: 1e-9)
        XCTAssertEqual(e[0].puffer ?? 0, 12, accuracy: 1e-9)
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
