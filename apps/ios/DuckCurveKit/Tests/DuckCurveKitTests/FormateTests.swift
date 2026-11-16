import XCTest

@testable import DuckCurveKit

/// Dieselben Faelle wie `apps/web/src/lib/format/format.test.ts`.
///
/// Das ist der Zweck: was an der Wand steht und was in der App steht, soll Zeichen fuer Zeichen
/// dasselbe sein. Weicht eine der beiden Seiten ab, faellt es hier auf und nicht am iPad.
final class FormateTests: XCTestCase {
    func testKwMitKommaUndMinuszeichen() {
        XCTAssertEqual(Formate.kw(6.84), "6,8")
        XCTAssertEqual(Formate.kw(-2.4), "\u{2212}2,4")
        XCTAssertEqual(Formate.kw(0.02), "0,0")
        XCTAssertEqual(Formate.kw(nil), "-")
        XCTAssertEqual(Formate.kwMitEinheit(3.6), "3,6\u{202F}kW")
    }

    /// Ein negativer Wert knapp unter der Schwelle darf kein Vorzeichen bekommen: sonst zeigt die
    /// Wand eine Einspeisung, die es nicht gibt.
    func testKleineNegativeWerteVerlierenDasVorzeichen() {
        XCTAssertEqual(Formate.kw(-0.01), "0,0")
        XCTAssertEqual(Formate.kw(-0.04), "0,0")
        XCTAssertEqual(Formate.kw(-0.06), "\u{2212}0,1")
        XCTAssertEqual(Formate.zahl(-0.004, stellen: 1), "0,0")
    }

    func testProzentTemperaturUndPreis() {
        XCTAssertEqual(Formate.prozent(0.62), "62\u{202F}%")
        XCTAssertEqual(Formate.celsius(59.6), "60\u{202F}°C")
        XCTAssertEqual(Formate.ct(-1.25), "\u{2212}1,3\u{202F}ct/kWh")
    }

    /// `-1.25` auf eine Stelle ist der Fall, an dem sich kaufmaennisches und mathematisches
    /// Runden unterscheiden. Das Dashboard rundet kaufmaennisch, also auf `1,3`.
    func testRundetWieDasDashboard() {
        XCTAssertEqual(Formate.zahl(1.25, stellen: 1), "1,3")
        XCTAssertEqual(Formate.zahl(2.45, stellen: 1), "2,5")
        XCTAssertEqual(Formate.zahl(0.5, stellen: 0), "1")
    }

    func testUhrzeitInHauszeit() {
        // 11:42 UTC im September ist 13:42 in Berlin (Sommerzeit).
        XCTAssertEqual(Formate.hhmm(iso: "2026-09-04T11:42:00Z"), "13:42")
        // Im Januar nur eine Stunde Versatz.
        XCTAssertEqual(Formate.hhmm(iso: "2026-01-04T11:42:00Z"), "12:42")
    }

    /// Der Dienst liefert Zeitstempel in drei Formen. Alle drei muessen gelesen werden, sonst
    /// bleibt in der Anzeige ein ganzer Tag leer.
    func testLiestAlleFormenVonZeitstempeln() {
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T11:42:00Z"))
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T11:42:00.123Z"))
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T13:42:00+02:00"))
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T13:42:00"))
        XCTAssertNil(Zeit.ausIso("heute"))
        XCTAssertNil(Zeit.ausIso(""))
    }

    /// Ohne Zeitzone im Text meint der Dienst die Zeit des Hauses - nicht UTC.
    func testZeitstempelOhneZoneGiltAlsHauszeit() {
        let d = Zeit.ausIso("2026-09-04T13:42:00")
        XCTAssertEqual(Formate.hhmm(d), "13:42")
    }

    func testAlterSchweigtSolangeDieWerteKommen() {
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertNil(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-10), jetzt: jetzt))
        XCTAssertEqual(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-45), jetzt: jetzt), "vor 45 s")
        XCTAssertEqual(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-600), jetzt: jetzt), "vor 10 min")
        XCTAssertEqual(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-7200), jetzt: jetzt), "vor 2 h")
    }

    func testMinutenBisIstNieNegativ() {
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(Formate.minutenBis(jetzt.addingTimeInterval(900), jetzt: jetzt), 15)
        XCTAssertEqual(Formate.minutenBis(jetzt.addingTimeInterval(-900), jetzt: jetzt), 0)
        XCTAssertNil(Formate.minutenBis(nil, jetzt: jetzt))
    }

    func testDauer() {
        XCTAssertEqual(Formate.dauer(minuten: 45), "45\u{202F}min")
        XCTAssertEqual(Formate.dauer(minuten: 60), "1\u{202F}h")
        XCTAssertEqual(Formate.dauer(minuten: 200), "3\u{202F}h 20\u{202F}min")
        XCTAssertEqual(Formate.dauer(minuten: nil), "-")
    }

    /// Nicht endliche Werte kommen aus Divisionen in der Auswertung. Sie duerfen nicht als
    /// „inf" an der Wand landen.
    func testUnendlichUndNaNWerdenZumBindestrich() {
        XCTAssertEqual(Formate.kw(.infinity), "-")
        XCTAssertEqual(Formate.kw(.nan), "-")
        XCTAssertEqual(Formate.ct(.nan), "-")
        XCTAssertEqual(Formate.prozent(.infinity), "-")
    }
}

extension FormateTests {
    /// `zahl` nimmt seit dem ersten Uebersetzungslauf `Double?` – und muss sich dabei wie die
    /// dreizehn Geschwister verhalten, sonst ist die Falle nur verschoben.
    func testZahlOhneWertGibtDenStrich() {
        XCTAssertEqual(Formate.zahl(nil, stellen: 1), Formate.zahl(Double.nan, stellen: 1))
        // Derselbe Strich wie bei den anderen, nicht „0,0" und nicht leer.
        XCTAssertEqual(Formate.zahl(nil, stellen: 2), Formate.kw(nil))
        XCTAssertFalse(Formate.zahl(nil, stellen: 0).isEmpty)
    }

    func testZahlMitWertBleibtWieVorher() {
        XCTAssertEqual(Formate.zahl(3.14159, stellen: 2), "3,14")
        XCTAssertEqual(Formate.zahl(-0.04, stellen: 1), "0,0")
        XCTAssertEqual(Formate.zahl(Optional(2.5), stellen: 1), "2,5")
    }
}
