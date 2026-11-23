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

    /// Die Achsenform: zweistellig, ohne Wochentag, ohne Jahr - und ein Tag, der kein Tag ist,
    /// kommt unveraendert zurueck statt als „00.00.".
    func testTagUndMonatAnDerAchse() {
        XCTAssertEqual(Tag.tagMonat("2026-11-07"), "07.11.")
        XCTAssertEqual(Tag.tagMonat("2026-01-31"), "31.01.")
        XCTAssertEqual(Tag.tagMonat("kein Tag"), "kein Tag")
    }

    /// Die Form der Zellenauskunft: kurzer Wochentag mit Punkt, Tag zweistellig, Monat
    /// ausgeschrieben, Jahr (`apps/web/src/components/reports/charts.ts:473-478`).
    func testKurzerWochentagMitLangemMonat() {
        XCTAssertEqual(Tag.langKurzerWochentag("2026-11-10"), "Di., 10. November 2026")
        XCTAssertEqual(Tag.langKurzerWochentag("2026-11-07"), "Sa., 07. November 2026")
        XCTAssertEqual(Tag.langKurzerWochentag("2026-01-04"), "So., 04. Januar 2026")
    }

    /// Die fuehrende Null kommt aus `day: "2-digit"` und ist der sichtbare Unterschied zu
    /// ``Tag/lang(_:)``, das den Tag einstellig schreibt.
    func testKurzerWochentagHaeltDieFuehrendeNull() {
        XCTAssertEqual(Tag.lang("2026-11-07"), "Samstag, 7. November 2026")
        XCTAssertNotEqual(Tag.langKurzerWochentag("2026-11-07"), Tag.lang("2026-11-07"))
        XCTAssertTrue(Tag.langKurzerWochentag("2026-03-01").hasSuffix("01. März 2026"))
    }

    /// Der Punkt hinter dem Wochentag wird gesetzt, denn ``Namen/wochentageKurz`` fuehrt ihn
    /// nicht - anders als bei ``Tag/kurz(_:)``, das ohne ihn schreibt.
    func testKurzerWochentagSetztDenPunktHinterDenWochentag() {
        XCTAssertTrue(Tag.langKurzerWochentag("2026-11-07").hasPrefix("Sa., "))
        XCTAssertTrue(Tag.kurz("2026-11-07").hasPrefix("Sa, "))
    }

    /// Ein Tag, der kein Tag ist, kommt unveraendert zurueck wie bei den Geschwistern.
    func testKurzerWochentagGibtEinenUngueltigenTagUnveraendertZurueck() {
        XCTAssertEqual(Tag.langKurzerWochentag("kein Tag"), "kein Tag")
        XCTAssertEqual(Tag.langKurzerWochentag("2026-02-30"), "2026-02-30")
    }

    func testRelativeNamen() {
        let jetzt = Tag.date("2026-11-16")!
        XCTAssertEqual(Tag.nameRelativ("2026-11-16", jetzt: jetzt), "Heute")
        XCTAssertEqual(Tag.nameRelativ("2026-11-15", jetzt: jetzt), "Gestern")
        XCTAssertEqual(Tag.nameRelativ("2026-11-17", jetzt: jetzt), "Morgen")
        XCTAssertNil(Tag.nameRelativ("2026-11-10", jetzt: jetzt))
    }
}
