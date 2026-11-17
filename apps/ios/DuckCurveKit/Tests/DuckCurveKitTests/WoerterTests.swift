import XCTest

@testable import DuckCurveKit

final class WoerterTests: XCTestCase {
    private func einstellung(
        wahl: [String: String] = [:], stellen: Int? = nil, einheit: String? = nil
    ) -> ReglerEinstellungOut {
        ReglerEinstellungOut(
            schluessel: "hk1.soll", nameDe: "Sollvorlauf", gruppeDe: "Heizkreis",
            kennung: "HK1 SOLL", einheit: einheit, stellen: stellen,
            wert: Messwert(value: 21, observedAt: "2026-11-17T08:00:00Z", quality: .ok,
                           source: "ebus"),
            wahl: wahl
        )
    }

    func testEineZahlMitEinheit() {
        let e = einstellung(stellen: 1, einheit: "°C")
        // Das Leerzeichen ist ein schmales - zwischen Zahl und Einheit gehoert kein voller Abstand.
        XCTAssertEqual(e.wertAlsText(21.5), "21,5\u{202F}°C")
    }

    func testOhneEinheitNurDieZahl() {
        XCTAssertEqual(einstellung(stellen: 0).wertAlsText(3), "3")
    }

    func testOhneStellenEineNachkommastelle() {
        // `stellen` ist wahlfrei; der Regler meint dann eine Stelle.
        XCTAssertEqual(einstellung().wertAlsText(2.25), "2,3")
    }

    func testEineAuswahlSchlaegtDieZahl() {
        let e = einstellung(wahl: ["0": "aus", "1": "Heizen", "2": "Kühlen"], einheit: "°C")
        XCTAssertEqual(e.wertAlsText(1), "Heizen")
        // Auch die Einheit faellt weg: „Heizen °C" waere Unsinn.
        XCTAssertFalse(e.wertAlsText(1).contains("°C"))
    }

    func testEinWertAusserhalbDerAuswahlBleibtEineZahl() {
        let e = einstellung(wahl: ["0": "aus", "1": "Heizen"], stellen: 0)
        XCTAssertEqual(e.wertAlsText(7), "7")
    }

    func testOhneWertDerStrich() {
        XCTAssertEqual(einstellung(stellen: 1, einheit: "°C").wertAlsText(nil), Formate.leer)
    }

    func testDieTaktungswoerterSindDieDesDashboards() {
        XCTAssertEqual(CyclingStatsVerdictWahl.ok.wort, "unauffällig")
        XCTAssertEqual(CyclingStatsVerdictWahl.watch.wort, "grenzwertig")
        XCTAssertEqual(CyclingStatsVerdictWahl.shortCycling.wort, "taktet häufig")
        // Der Fall, den jede erzeugte Aufzaehlung traegt, darf nicht „—unbekannt—" zeigen.
        XCTAssertEqual(CyclingStatsVerdictWahl.unbekannt.wort, "zu wenig Daten")
        XCTAssertEqual(CyclingStatsVerdictWahl.unknown.wort, "zu wenig Daten")
    }

    func testDiePhasenwoerterSindDeutschUndNichtDerRueckfall() {
        XCTAssertEqual(RoomShiftOutPhaseWahl.laden.wort, "laden")
        XCTAssertEqual(RoomShiftOutPhaseWahl.zehren.wort, "zehren")
        XCTAssertEqual(RoomShiftOutPhaseWahl.aus.wort, "aus")
        // Der Rohwert waere hier „—unbekannt—" und hilft niemandem.
        XCTAssertEqual(RoomShiftOutPhaseWahl.unbekannt.wort, "unbekannt")
        XCTAssertFalse(RoomShiftOutPhaseWahl.unbekannt.wort.contains("—"))
    }

    func testDieRechnungsurteileSindDieDesDashboards() {
        XCTAssertEqual(Rechnungsurteil.ok.wort, "geprüft, alles stimmig")
        XCTAssertEqual(Rechnungsurteil.info.wort, "geprüft, mit Hinweisen")
        XCTAssertEqual(Rechnungsurteil.warning.wort, "auffällig")
        XCTAssertEqual(Rechnungsurteil.error.wort, "Rechenfehler")
    }

    /// **Die beiden, die roh auf dem Bildschirm standen.** Der Dienst schickt `info` und
    /// `error`; die App kannte sie nicht und zeigte das englische Wort.
    func testInfoUndErrorWerdenErkannt() {
        XCTAssertEqual(Rechnungsurteil.aus("info"), .info)
        XCTAssertEqual(Rechnungsurteil.aus("error"), .error)
        XCTAssertEqual(Rechnungsurteil.aus("warning"), .warning)
        XCTAssertEqual(Rechnungsurteil.aus("ok"), .ok)
    }

    /// Die erfundenen Woerter gibt es nicht - und sollen auch nicht stillschweigend etwas
    /// anderes werden.
    func testErfundeneWoerterBleibenUnbekannt() {
        for roh in ["warn", "fail", "alarm", "", "OK"] {
            XCTAssertNil(Rechnungsurteil.aus(roh), roh)
        }
    }

    func testNurFehlerUndWarnungSindEinBefund() {
        XCTAssertTrue(Rechnungsurteil.error.istBefund)
        XCTAssertTrue(Rechnungsurteil.warning.istBefund)
        XCTAssertFalse(Rechnungsurteil.info.istBefund)
        XCTAssertFalse(Rechnungsurteil.ok.istBefund)
    }
}
