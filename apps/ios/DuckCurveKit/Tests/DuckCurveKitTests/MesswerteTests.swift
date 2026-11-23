import XCTest

@testable import DuckCurveKit

/// Rohe Zahlen zu Messwerten.
///
/// Klein, aber nicht umsonst: an dieser Umwandlung hängt, ob ein **fehlender** Fühler im
/// Pufferglas anders aussieht als ein **kalter**. Beides ist eine Zahl, die nicht da ist –
/// einmal, weil der Fühler schweigt, einmal, weil es draußen warm ist. Ein `nil`, das als
/// `ok` durchgeht, malt einen leeren Speicher.
final class MesswerteTests: XCTestCase {
    func testEineZahlIstOk() {
        let m = Messwert.ausZahlen([42.5], beobachtet: "2026-11-16T10:00:00Z", quelle: "anlage")
        XCTAssertEqual(m.count, 1)
        XCTAssertEqual(m[0].value, 42.5)
        XCTAssertEqual(m[0].quality, .ok)
        XCTAssertEqual(m[0].observedAt, "2026-11-16T10:00:00Z")
        XCTAssertEqual(m[0].source, "anlage")
    }

    func testEinFehlenderWertIstNichtVerfuegbarUndNichtOk() {
        let m = Messwert.ausZahlen([nil], beobachtet: "2026-11-16T10:00:00Z", quelle: "anlage")
        XCTAssertNil(m[0].value)
        XCTAssertEqual(m[0].quality, .unavailable)
        // Die Oberflaeche entscheidet daran, ob sie einen Strich malt oder eine Temperatur.
        XCTAssertFalse(m[0].quality.traegt)
    }

    func testDieReihenfolgeBleibt() {
        // Die vier Fuehler stehen von oben nach unten; eine vertauschte Reihe zeichnet den
        // Speicher auf dem Kopf.
        let m = Messwert.ausZahlen([60, nil, 40, 30], beobachtet: "x", quelle: "anlage")
        XCTAssertEqual(m.map(\.value), [60, nil, 40, 30])
        XCTAssertEqual(m.map(\.quality), [.ok, .unavailable, .ok, .ok])
    }

    func testEineLeereReiheBleibtLeer() {
        XCTAssertTrue(Messwert.ausZahlen([], beobachtet: "x", quelle: "y").isEmpty)
    }

    func testNullIstEineZahlUndKeinFehlen() {
        // 0 °C ist ein Messwert. `wert == nil` und `wert == 0` zu verwechseln ist der Fehler,
        // den diese Zeile verhindert.
        let m = Messwert.ausZahlen([0], beobachtet: "x", quelle: "y")
        XCTAssertEqual(m[0].value, 0)
        XCTAssertEqual(m[0].quality, .ok)
    }
}
