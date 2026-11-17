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

    // MARK: - Die Spanne einer Werteachse

    /// **Der Fall von der Heizkreise-Seite.** Zehn Raeume zwischen 18 und 21 Grad standen auf
    /// einer Achse von 0 bis 30.
    func testRaumtemperaturenBekommenKeineNull() {
        let s = Achse.spanne(werte: [18.2, 18.7, 20.9, 19.1, 18.4])!
        XCTAssertGreaterThan(s.lowerBound, 10, "die Null gehoert hier nicht auf die Achse")
        XCTAssertLessThanOrEqual(s.lowerBound, 17.2)
        XCTAssertGreaterThanOrEqual(s.upperBound, 21.9)
    }

    func testEinFlacherTagBekommtTrotzdemLuft() {
        // Alles innerhalb eines Zehntelgrads: ohne Mindestspanne saehe jedes Rauschen aus
        // wie ein Ereignis.
        let s = Achse.spanne(werte: [20.00, 20.05, 20.03])!
        XCTAssertGreaterThanOrEqual(s.upperBound - s.lowerBound, 4)
    }

    func testFehlendeWerteZaehlenNicht() {
        let s = Achse.spanne(werte: [nil, 18.0, nil, 22.0, nil])!
        XCTAssertEqual(s.lowerBound, 17)
        XCTAssertEqual(s.upperBound, 23)
    }

    func testOhneEinenEinzigenWertGibtEsKeineSpanne() {
        XCTAssertNil(Achse.spanne(werte: []))
        XCTAssertNil(Achse.spanne(werte: [nil, nil]))
        XCTAssertNil(Achse.spanne(werte: [Double.nan]))
    }
}
