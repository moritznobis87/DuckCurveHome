import XCTest

@testable import DuckCurveKit

/// „Mein Zugang“ sagt in der App dasselbe wie im Dashboard (`kontoworte.test.ts`).
final class KontowortTests: XCTestCase {
    func testRollenHeissenWieImDashboard() {
        XCTAssertEqual(Kontoworte.rolle("hausherr").name, "Hausherr")
        XCTAssertEqual(Kontoworte.rolle("hausherr").satz, "Sieht alles und darf alles einstellen.")
        XCTAssertEqual(Kontoworte.rolle("bewohner").satz, "Sieht das Haus und darf dort stellen.")
        XCTAssertEqual(Kontoworte.rolle("service").name, "Beratung")
        // Die Beratung darf am Gerät schreiben (`rechte.py`, `_GERAET`); „stellt nichts“ wäre falsch.
        XCTAssertEqual(Kontoworte.rolle("service").satz, "Sieht alles außer den Akten und darf am Hausgerät arbeiten.")
        XCTAssertEqual(Kontoworte.rolle("gast").satz, "Sieht zu und stellt nichts.")
    }

    func testDieKartenTragenZeichenTitelUndSatz() {
        XCTAssertEqual(Kontoworte.Kartenart.passkeys.zeichen.vorlage, "key")
        XCTAssertEqual(Kontoworte.Kartenart.passwort.zeichen.vorlage, "lock")
        XCTAssertEqual(Kontoworte.Kartenart.sitzungen.zeichen.vorlage, "device")
        XCTAssertEqual(
            [Kontoworte.Kartenart.passkeys, .passwort, .sitzungen].map(\.satz),
            [
                "Anmelden mit Gesicht oder Finger, ohne Passwort.",
                "Der zweite Weg herein, an jedem Gerät.",
                "Wo du gerade angemeldet bist.",
            ])
    }

    func testDieLoeschfrageNenntDenPasskey() {
        XCTAssertEqual(Kontoworte.loeschfrage("iPhone"), "„iPhone“ löschen?")
    }

    func testDasGeraetWirdAusDemUserAgentErkannt() {
        XCTAssertEqual(Kontoworte.geraet("Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X)"), "iPhone")
        XCTAssertEqual(Kontoworte.geraet("Mozilla/5.0 (X11; Linux x86_64)"), "Linux")
        XCTAssertEqual(Kontoworte.geraet("DuckCurveHome/1 CFNetwork Darwin"), "unbekanntes Gerät")
        XCTAssertEqual(Kontoworte.geraet(nil), "unbekanntes Gerät")
    }

    /// In der Zeit des Hauses: 21:50 UTC sind 22:50 in Berlin.
    func testDatumWieImDashboard() {
        XCTAssertEqual(Kontoworte.datum("2026-11-24T21:50:00Z"), "24.11.26, 22:50")
        XCTAssertEqual(Kontoworte.datum(nil), "nie")
        XCTAssertEqual(
            Kontoworte.sitzungszeile(seit: "2026-11-24T21:50:00Z", zuletzt: nil),
            "seit 24.11.26, 22:50 · zuletzt nie")
        XCTAssertEqual(
            Kontoworte.passkeyzeile(gesichert: true, zuletzt: nil), "in der Wolke gesichert · zuletzt nie")
    }
}
