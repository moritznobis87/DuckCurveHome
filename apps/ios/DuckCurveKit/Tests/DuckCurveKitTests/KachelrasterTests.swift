import XCTest

@testable import DuckCurveKit

final class KachelrasterTests: XCTestCase {
    /// Die drei Stufen der Fahrplanseite (`waerme/Fahrplan.tsx:548`).
    func testDreiStufen() {
        let r = Kachelraster(mittel: 4, breit: 7)
        XCTAssertEqual(r.spalten(breite: 358), 2)
        XCTAssertEqual(r.spalten(breite: 768 - 32), 4)
        XCTAssertEqual(r.spalten(breite: 1180 - 32), 4)
        XCTAssertEqual(r.spalten(breite: 1280 - 32), 7)
        XCTAssertEqual(r.spalten(breite: 1600), 7)
    }

    /// Die Stufen der Wirkungsseite (`waerme/Wirkung.tsx:171`).
    func testZweiDreiFuenf() {
        let r = Kachelraster(mittel: 3, breit: 5)
        XCTAssertEqual(r.spalten(breite: 390), 2)
        XCTAssertEqual(r.spalten(breite: 900), 3)
        XCTAssertEqual(r.spalten(breite: 1400), 5)
    }

    /// **Vor der ersten Messung gilt die unterste Stufe** - die Vorlage faengt ohne
    /// Medienabfrage mit zwei Spalten an, und eine erfundene Zahl waere ein Sprung im Bild.
    func testOhneMessung() {
        let r = Kachelraster(mittel: 4, breit: 7)
        XCTAssertEqual(r.spalten(breite: 0), 2)
        XCTAssertEqual(r.spalten(breite: -1), 2)
        XCTAssertEqual(r.spalten(breite: .nan), 2)
        // Auch das Unendliche ist kein Mass: `isFinite` faellt zuerst.
        XCTAssertEqual(r.spalten(breite: .infinity), 2)
    }

    /// Die Fahrplanseite behaelt ihre Antwort, obwohl die Schwellen umgezogen sind.
    func testFahrplanrasterUnveraendert() {
        XCTAssertEqual(Fahrplanraster.spalten(breite: 0), 2)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 358), 2)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 1148), 4)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 1248), 7)
    }
}
