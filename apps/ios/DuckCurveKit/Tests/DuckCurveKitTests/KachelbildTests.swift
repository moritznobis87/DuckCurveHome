import XCTest

@testable import DuckCurveKit

/// Das kleine Bild der Kachel rechnet wie im Dashboard (`Kachelbild.tsx`, `kachelbild.test.ts`).
final class KachelbildTests: XCTestCase {
    func testDerTagHatImmerVierundzwanzigPlaetze() {
        let hoehen = Kachelbild.balkenhoehen([1, 2, 4])
        XCTAssertEqual(hoehen.count, 24)
        XCTAssertEqual(Array(hoehen.prefix(3)), [0.25, 0.5, 1])
        // Was noch nicht war, ist leer und nicht null.
        XCTAssertEqual(hoehen[3], nil)
        XCTAssertEqual(hoehen[23], nil)
    }

    func testEinTagOhneWertBleibtFlach() {
        XCTAssertEqual(Array(Kachelbild.balkenhoehen([0, 0]).prefix(2)), [0, 0])
    }

    func testEinNegativerWertZeichnetKeinenBalkenNachUnten() {
        XCTAssertEqual(Array(Kachelbild.balkenhoehen([-1, 2]).prefix(2)), [0, 1])
    }

    func testDieLaeufeEinesStreifens() {
        XCTAssertEqual(
            Kachelbild.laeufe([0, 1, 1, 0, 1]),
            [Kachelbild.Lauf(von: 0.2, bis: 0.6), Kachelbild.Lauf(von: 0.8, bis: 1)])
        XCTAssertEqual(Kachelbild.laeufe([]), [])
        XCTAssertEqual(Kachelbild.laeufe([0, 0]), [])
        XCTAssertEqual(Kachelbild.laeufe([1, 1]), [Kachelbild.Lauf(von: 0, bis: 1)])
    }

    func testAnteileBleibenImRahmen() {
        XCTAssertEqual(Kachelbild.beschnitten(1.04), 1)
        XCTAssertEqual(Kachelbild.beschnitten(-0.2), 0)
        XCTAssertEqual(Kachelbild.beschnitten(-2.5, unten: -1), -1)
        XCTAssertEqual(Kachelbild.beschnitten(-0.8, unten: -1), -0.8)
    }
}
