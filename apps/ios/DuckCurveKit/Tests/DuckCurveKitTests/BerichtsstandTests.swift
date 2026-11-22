import XCTest

@testable import DuckCurveKit

/// Wann „Stand 14:35“ dasteht - und wann nicht.
final class BerichtsstandTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_800_000_000)

    private func iso(_ versatz: TimeInterval) -> String {
        Zeit.iso(jetzt.addingTimeInterval(versatz))
    }

    func testFrischeAntwortZeigtKeinenStand() {
        XCTAssertNil(Berichtsstand.satz(gerechnetAm: iso(0), jetzt: jetzt))
        XCTAssertNil(Berichtsstand.satz(gerechnetAm: iso(-30), jetzt: jetzt))
    }

    func testGenauAufDerSchwelleNochNicht() {
        XCTAssertNil(Berichtsstand.satz(gerechnetAm: iso(-Berichtsstand.schwelle), jetzt: jetzt))
    }

    func testAeltereAntwortZeigtIhreUhrzeit() {
        let satz = Berichtsstand.satz(gerechnetAm: iso(-20 * 60), jetzt: jetzt)
        XCTAssertEqual(satz, "Stand \(Formate.hhmm(jetzt.addingTimeInterval(-20 * 60)))")
    }

    func testOhneZeitstempelUndMitUnlesbaremNichts() {
        XCTAssertNil(Berichtsstand.satz(gerechnetAm: nil, jetzt: jetzt))
        XCTAssertNil(Berichtsstand.satz(gerechnetAm: "", jetzt: jetzt))
        XCTAssertNil(Berichtsstand.satz(gerechnetAm: "vorgestern", jetzt: jetzt))
    }

    func testEinStandInDerZukunftIstKeineAuskunft() {
        XCTAssertNil(Berichtsstand.satz(gerechnetAm: iso(120), jetzt: jetzt))
    }
}
