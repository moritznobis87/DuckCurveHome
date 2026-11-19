import XCTest

@testable import DuckCurveKit

final class RaumabweichungTests: XCTestCase {
    typealias R = Raumabweichung

    // MARK: - Die Grenzen

    /// **Der Fehler, den diese Tests festhalten.** Hier stand ±0,3 K fuer „am Ziel" statt
    /// ±0,5. Eine Fussbodenheizung pendelt immer etwas, und Contromes Fuehler loesen 0,1 K
    /// auf - mit der engeren Grenze steht ein ganzes Haus dauerhaft eingefaerbt da, ohne dass
    /// irgendetwas waere.
    func testDasBandAmZielIstEinHalbesKelvin() {
        XCTAssertEqual(R.band, 0.5)
        for k in [-0.49, -0.3, 0.0, 0.3, 0.49] {
            XCTAssertEqual(R.stufe(k), 2, "\(k) K muss „am Ziel“ sein")
        }
        XCTAssertNotEqual(R.stufe(-0.6), 2)
        XCTAssertNotEqual(R.stufe(0.6), 2)
    }

    func testDieFuenfStufenSindDieDesDashboards() {
        XCTAssertEqual(R.stufe(-3.0), 0)
        XCTAssertEqual(R.stufe(-1.6), 0)
        XCTAssertEqual(R.stufe(-1.4), 1)
        XCTAssertEqual(R.stufe(-0.6), 1)
        XCTAssertEqual(R.stufe(0.0), 2)
        XCTAssertEqual(R.stufe(0.6), 3)
        XCTAssertEqual(R.stufe(1.4), 3)
        XCTAssertEqual(R.stufe(1.6), 4)
        XCTAssertEqual(R.stufe(9.9), 4)
    }

    func testDieSkalaIstZweiseitigUndSymmetrisch() {
        for k in [0.7, 1.2, 2.0, 5.0] {
            XCTAssertEqual(R.stufe(k) - 2, 2 - R.stufe(-k), "\(k) K")
        }
    }

    // MARK: - Der Zielwert

    func testEinFehlenderVersatzIstEinerVonNull() {
        XCTAssertEqual(R.ziel(soll: 21.0, versatz: nil), 21.0)
        XCTAssertEqual(R.ziel(soll: 21.0, versatz: -0.3), 20.7)
    }

    func testOhneSollwertGibtEsKeinZiel() {
        XCTAssertNil(R.ziel(soll: nil, versatz: -0.3))
        XCTAssertNil(R.ziel(soll: nil, versatz: nil))
    }

    // MARK: - Die Felder eines Tages

    func testEinFensterOhneMesswertIstNichtAmZiel() {
        let f = R.felder(ist: [nil], soll: [21], versatz: [0])
        XCTAssertEqual(f, [.keinWert])
        // Und es ist etwas anderes als eine Abweichung von null.
        XCTAssertNotEqual(f[0], .wert(0))
    }

    func testOhneSollwertEbenfallsKeinWert() {
        XCTAssertEqual(R.felder(ist: [20.4], soll: [nil], versatz: [0]), [.keinWert])
    }

    /// Zwei leere Felder, zwei Gruende: der Nachmittag war noch nicht, der stumme Fuehler
    /// schon.
    func testWasNochNichtWarIstNichtDasselbeWieWasFehlt() {
        let f = R.felder(ist: [20.5, nil, nil], soll: [21, 21, 21], versatz: [0, 0, 0],
                         bisStelle: 2)
        XCTAssertEqual(f[0], .wert(-0.5))
        XCTAssertEqual(f[1], .keinWert)
        XCTAssertEqual(f[2], .nochNicht)
    }

    func testDieAbweichungIstIstMinusZiel() {
        let f = R.felder(ist: [19.0, 21.0, 23.0], soll: [21, 21, 21], versatz: [-0.3, 0, 0.5])
        XCTAssertEqual(f, [.wert(19.0 - 20.7), .wert(0.0), .wert(23.0 - 21.5)])
    }

    // MARK: - Das Tagesmittel

    func testDasMittelZaehltNurGemessenes() {
        let f: [R.Feld] = [.wert(-1.0), .keinWert, .wert(-2.0), .nochNicht]
        XCTAssertEqual(R.mittel(f)!, -1.5, accuracy: 1e-9)
    }

    func testOhneEinenEinzigenWertGibtEsKeinMittel() {
        XCTAssertNil(R.mittel([.keinWert, .nochNicht]))
        XCTAssertNil(R.mittel([]))
    }

    // MARK: - Welche Fenster schon gewesen sind

    func testEinVergangenerTagIstGanzGewesen() {
        let morgen = Tag.zeitraum("2026-11-17")!.bis.addingTimeInterval(3600)
        XCTAssertNil(R.gewesen(tag: "2026-11-17", jetzt: morgen))
    }

    func testEinKuenftigerTagHatNochKeinFenster() {
        let gestern = Tag.zeitraum("2026-11-17")!.von.addingTimeInterval(-3600)
        XCTAssertEqual(R.gewesen(tag: "2026-11-17", jetzt: gestern), 0)
    }

    func testHeuteZaehltBisJetzt() {
        let von = Tag.zeitraum("2026-11-17")!.von
        // 10:12 Uhr: zehn volle Stunden und zwoelf Minuten = 40 Viertelstunden.
        let jetzt = von.addingTimeInterval(10 * 3600 + 12 * 60)
        XCTAssertEqual(R.gewesen(tag: "2026-11-17", jetzt: jetzt), 40)
        // Und mit einem anderen Schritt entsprechend weniger.
        XCTAssertEqual(R.gewesen(tag: "2026-11-17", jetzt: jetzt, schrittMin: 60), 10)
    }

    func testUnsinnGibtNichts() {
        XCTAssertNil(R.gewesen(tag: "kein Tag", jetzt: Date()))
        XCTAssertNil(R.gewesen(tag: "2026-11-17", jetzt: Date(), schrittMin: 0))
    }
}
