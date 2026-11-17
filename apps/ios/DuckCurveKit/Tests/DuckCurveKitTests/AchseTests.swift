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

    // MARK: - anteil / wert

    func testAnteilLiegtZwischenNullUndEins() {
        XCTAssertEqual(Achse.anteil(10, in: 10...50), 0, accuracy: 1e-9)
        XCTAssertEqual(Achse.anteil(30, in: 10...50), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Achse.anteil(50, in: 10...50), 1, accuracy: 1e-9)
    }

    /// Der Fehler, um den es ging: 49,1 ct auf einer Achse bis 40 lief oben aus dem Bild.
    func testWerteAusserhalbLandenAufDemRandUndNichtDarueber() {
        XCTAssertEqual(Achse.anteil(60, in: 10...50), 1, accuracy: 1e-9)
        XCTAssertEqual(Achse.anteil(-5, in: 10...50), 0, accuracy: 1e-9)
    }

    func testEineSpanneOhneBreiteLiegtInDerMitte() {
        XCTAssertEqual(Achse.anteil(7, in: 7...7), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Achse.anteil(Double.nan, in: 0...1), 0.5, accuracy: 1e-9)
    }

    func testWertIstDieUmkehrungVonAnteil() {
        let spanne = -3.0...21.0
        for ct in [-3.0, 0.0, 7.5, 21.0] {
            XCTAssertEqual(
                Achse.wert(anteil: Achse.anteil(ct, in: spanne), in: spanne), ct, accuracy: 1e-9)
        }
    }

    func testNegativePreiseBleibenInDerSpanne() {
        let spanne = Achse.spanne(werte: [-4.2, 0, 12.0], rand: 2, mindestens: 10)!
        XCTAssertTrue(spanne.contains(-4.2))
        XCTAssertEqual(Achse.anteil(-4.2, in: spanne), 0.1, accuracy: 0.1)
    }
}
