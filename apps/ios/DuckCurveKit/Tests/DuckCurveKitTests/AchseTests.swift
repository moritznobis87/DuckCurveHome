import XCTest

@testable import DuckCurveKit

final class AchseTests: XCTestCase {
    private let monat = (1...30).map { String(format: "%02d", $0) }

    func testWenigeBleibenAlle() {
        XCTAssertEqual(Achse.beschriftungen(["Mo", "Di", "Mi"]), ["Mo", "Di", "Mi"])
        XCTAssertEqual(Achse.beschriftungen(monat.prefix(8).map { $0 }).count, 8)
    }

    /// **Der Fall von der Geld-Seite.** Dreissig Tage ergaben dreissig Beschriftungen und
    /// damit einen Ziffernstreifen.
    func testEinMonatWirdAusgeduennt() {
        let a = Achse.beschriftungen(monat)
        XCTAssertLessThanOrEqual(a.count, 8)
        XCTAssertGreaterThan(a.count, 4, "zu stark ausgeduennt ist auch nicht lesbar")
        XCTAssertEqual(a.first, "01", "die Achse muss einen Anfang haben")
    }

    func testDieAbstaendeSindGleich() {
        let a = Achse.beschriftungen(monat)
        let stellen = a.compactMap { monat.firstIndex(of: $0) }
        let abstaende = Set(zip(stellen, stellen.dropFirst()).map { $1 - $0 })
        XCTAssertEqual(abstaende.count, 1, "ungleiche Abstaende sehen aus wie ein Fehler")
    }

    func testEinJahrInStunden() {
        let stunden = (0..<8760).map { "\($0)" }
        XCTAssertLessThanOrEqual(Achse.beschriftungen(stunden).count, 8)
    }

    func testLeerUndUnsinn() {
        XCTAssertEqual(Achse.beschriftungen([]), [])
        XCTAssertEqual(Achse.beschriftungen(monat, hoechstens: 0), [])
        XCTAssertEqual(Achse.beschriftungen(monat, hoechstens: 1).count, 1)
    }
}
