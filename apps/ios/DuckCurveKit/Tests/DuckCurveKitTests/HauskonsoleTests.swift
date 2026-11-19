import XCTest

@testable import DuckCurveKit

final class HauskonsoleTests: XCTestCase {
    typealias K = Hauskonsole

    /// **Ein Name und eine Zahl.** Zwölf Kontakte ergäben eine Zeile, die niemand liest.
    func testOffenSatz() {
        XCTAssertEqual(K.offenSatz(["Gartentür 1", "Fenster Bad"], von: 12), "Gartentür 1 und 1 weitere")
        XCTAssertEqual(K.offenSatz(["Gartentür 1"], von: 12), "Gartentür 1")
        XCTAssertEqual(K.offenSatz([], von: 12), "alles zu")
        XCTAssertEqual(K.offenSatz([], von: 0), "keine Kontakte im Plan")
    }

    func testPumpensatz() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        let vor40 = Zeit.iso(jetzt.addingTimeInterval(-40 * 60))
        XCTAssertEqual(K.pumpensatz(laeuft: false, seit: vor40, jetzt: jetzt), "steht seit 40 min")
        XCTAssertEqual(K.pumpensatz(laeuft: true, seit: vor40, jetzt: jetzt), "läuft seit 40 min")
        let vor90 = Zeit.iso(jetzt.addingTimeInterval(-90 * 60))
        XCTAssertEqual(K.pumpensatz(laeuft: true, seit: vor90, jetzt: jetzt), "läuft seit 1 h 30 min")
        // Ohne Zeitpunkt bleibt das Wort allein stehen - und keine erfundene Dauer.
        XCTAssertEqual(K.pumpensatz(laeuft: false, seit: nil, jetzt: jetzt), "steht")
        // Unter einer Minute ist „seit 0 min" eine Genauigkeit, die niemand braucht.
        let gerade = Zeit.iso(jetzt.addingTimeInterval(-20))
        XCTAssertEqual(K.pumpensatz(laeuft: true, seit: gerade, jetzt: jetzt), "läuft")
    }

    func testSchichtsatz() {
        XCTAssertEqual(K.schichtsatz([48.2, 41.0, 38.6, 37.1]), "48 · 41 · 39 · 37")
        XCTAssertEqual(K.schichtsatz([nil, 41.0]), "41")
        XCTAssertEqual(K.schichtsatz([nil, nil]), "keine Werte")
    }

    /// **Ein Raum zählt einmal**, auch wenn vier Kreise in ihm liegen.
    func testOffeneKreiseZaehltRaeume() {
        let raeume = [raum(1, ventil: 0.25), raum(2, ventil: 0), raum(3, ventil: 1), raum(4, ventil: nil)]
        XCTAssertEqual(K.offeneKreise(raeume), 2)
        XCTAssertEqual(K.offeneKreise([]), 0)
    }

    private func raum(_ id: Int, ventil: Double?) -> RoomLiveOut {
        RoomLiveOut(
            id: id, name: "Raum \(id)", floor: "Erdgeschoss", circuits: 4, tempC: 21,
            setpointC: 21, offsetK: 0, targetC: 21, humidityPct: nil, valve: ventil,
            window: 0, deviationK: 0, observedAt: nil, quality: .ok)
    }
}
