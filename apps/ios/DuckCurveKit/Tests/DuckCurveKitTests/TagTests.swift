import XCTest

@testable import DuckCurveKit

/// Dieselben Faelle wie `apps/web/src/lib/day.test.ts`, plus das Blaettern.
final class TagTests: XCTestCase {
    func testNimmtEchteTageAn() {
        for s in ["2026-10-17", "2024-02-29"] {
            XCTAssertTrue(Tag.istTag(s), "\(s) sollte ein Tag sein")
        }
    }

    func testWeistUntageZurueck() {
        for s in ["", "today", "2026-13-45", "2026-02-30", "2026-1-7", "Invalid Date", "2025-02-29"] {
            XCTAssertFalse(Tag.istTag(s), "\(s) sollte kein Tag sein")
        }
        XCTAssertFalse(Tag.istTag(nil))
    }

    /// Die Sommerzeit darf den Tag nicht kippen. Am 25. Oktober 2026 endet sie.
    func testBlaetternUeberDieZeitumstellung() {
        XCTAssertEqual(Tag.plus("2026-10-24", 1), "2026-10-25")
        XCTAssertEqual(Tag.plus("2026-10-25", 1), "2026-10-26")
        XCTAssertEqual(Tag.plus("2026-03-29", -1), "2026-03-28")
        XCTAssertEqual(Tag.plus("2026-01-01", -1), "2025-12-31")
        XCTAssertEqual(Tag.plus("2026-02-28", 1), "2026-03-01")
        XCTAssertEqual(Tag.plus("2024-02-28", 1), "2024-02-29")
    }

    func testZeitraumEinesTagesIstVierundzwanzigStunden() {
        let z = Tag.zeitraum("2026-11-16")
        XCTAssertNotNil(z)
        XCTAssertEqual(z!.bis.timeIntervalSince(z!.von), 24 * 3600)
    }

    /// Am Tag des Rueckstellens hat der Tag 25 Stunden. Wer hier 24 annimmt, verliert eine Stunde
    /// Messwerte aus der Historie.
    func testZeitraumAmTagDerZeitumstellung() {
        let herbst = Tag.zeitraum("2026-10-25")
        XCTAssertEqual(herbst!.bis.timeIntervalSince(herbst!.von), 25 * 3600)
        let fruehling = Tag.zeitraum("2026-03-29")
        XCTAssertEqual(fruehling!.bis.timeIntervalSince(fruehling!.von), 23 * 3600)
    }

    func testLangeUndKurzeNamen() {
        XCTAssertEqual(Tag.lang("2026-11-07"), "Samstag, 7. November 2026")
        XCTAssertEqual(Tag.kurz("2026-11-07"), "Sa, 7.11.")
    }

    func testRelativeNamen() {
        let jetzt = Tag.date("2026-11-16")!
        XCTAssertEqual(Tag.nameRelativ("2026-11-16", jetzt: jetzt), "Heute")
        XCTAssertEqual(Tag.nameRelativ("2026-11-15", jetzt: jetzt), "Gestern")
        XCTAssertEqual(Tag.nameRelativ("2026-11-17", jetzt: jetzt), "Morgen")
        XCTAssertNil(Tag.nameRelativ("2026-11-10", jetzt: jetzt))
    }
}
