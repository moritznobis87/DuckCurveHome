import XCTest

@testable import DuckCurveKit

/// Zeitraeume, Blaettern und die Kalenderwoche.
///
/// Die Kalenderwoche ist hier der eigentliche Gegenstand. Sie sieht nach einer Division aus und
/// ist keine: der 1. Januar kann in der Woche 52 oder 53 des *vorigen* Jahres liegen, und der 31.
/// Dezember in der Woche 1 des *naechsten*. Ein Bericht, der ueber den Jahreswechsel die falsche
/// Woche abfragt, zeigt stillschweigend fremde Zahlen.
final class ZeitraumTests: XCTestCase {
    // MARK: - Kalenderwoche

    /// Die Faelle, an denen jeder selbstgebaute Zaehler scheitert.
    func testKalenderwocheAmJahreswechsel() {
        // Der 1.1.2026 ist ein Donnerstag - also liegt er in der KW 1 von 2026.
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-01-01").kalenderwoche, 1)
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-01-01").kalenderwochenjahr, 2026)

        // Der 1.1.2027 ist ein Freitag - die Woche begann am Montag, dem 28.12.2026, und ist
        // trotzdem die KW 53 von 2026.
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2027-01-01").kalenderwoche, 53)
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2027-01-01").kalenderwochenjahr, 2026)

        // Der 31.12.2024 ist ein Dienstag und gehoert zur KW 1 von 2025.
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2024-12-31").kalenderwoche, 1)
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2024-12-31").kalenderwochenjahr, 2025)

        // Der 1.1.2023 ist ein Sonntag: KW 52 von 2022.
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2023-01-01").kalenderwoche, 52)
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2023-01-01").kalenderwochenjahr, 2022)
    }

    func testKalenderwocheMittenImJahr() {
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-11-16").kalenderwoche, 47)
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-02-24").kalenderwoche, 9)
    }

    /// Eine Woche beginnt am Montag und dauert sieben Tage.
    func testWochengrenzen() {
        // Der 16.11.2026 ist ein Montag.
        let z = Zeitraum(spanne: .woche, anker: "2026-11-18")  // ein Mittwoch
        let g = z.grenzen
        XCTAssertNotNil(g)
        XCTAssertEqual(Tag.iso(g!.von), "2026-11-16")
        XCTAssertEqual(g!.bis.timeIntervalSince(g!.von), 7 * 24 * 3600)
    }

    // MARK: - Grenzen

    func testTagesgrenzen() {
        let g = Zeitraum(spanne: .tag, anker: "2026-11-16").grenzen
        XCTAssertEqual(g!.bis.timeIntervalSince(g!.von), 24 * 3600)
        XCTAssertEqual(Tag.iso(g!.von), "2026-11-16")
    }

    func testMonatsgrenzen() {
        let g = Zeitraum(spanne: .monat, anker: "2026-02-24").grenzen
        XCTAssertEqual(Tag.iso(g!.von), "2026-02-01")
        // Februar 2026 hat 28 Tage.
        XCTAssertEqual(g!.bis.timeIntervalSince(g!.von), 28 * 24 * 3600)
        // 2024 war ein Schaltjahr.
        let schalt = Zeitraum(spanne: .monat, anker: "2024-02-10").grenzen
        XCTAssertEqual(schalt!.bis.timeIntervalSince(schalt!.von), 29 * 24 * 3600)
    }

    func testJahresgrenzen() {
        let g = Zeitraum(spanne: .jahr, anker: "2026-06-15").grenzen
        XCTAssertEqual(Tag.iso(g!.von), "2026-01-01")
        XCTAssertEqual(Tag.iso(g!.bis.addingTimeInterval(-1)), "2026-12-31")
    }

    /// Ein Monat mit Zeitumstellung ist keine runde Zahl von Stunden. Wer hier mit 24 rechnet,
    /// verliert eine Stunde Messwerte.
    func testMonatMitZeitumstellung() {
        let maerz = Zeitraum(spanne: .monat, anker: "2026-03-15").grenzen
        XCTAssertEqual(maerz!.bis.timeIntervalSince(maerz!.von), 31 * 24 * 3600 - 3600)
        let oktober = Zeitraum(spanne: .monat, anker: "2026-10-15").grenzen
        XCTAssertEqual(oktober!.bis.timeIntervalSince(oktober!.von), 31 * 24 * 3600 + 3600)
    }

    // MARK: - Blaettern

    func testBlaettern() {
        XCTAssertEqual(Zeitraum(spanne: .tag, anker: "2026-11-16").verschoben(-1).anker, "2026-11-15")
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-11-16").verschoben(-1).anker, "2026-11-09")
        XCTAssertEqual(Zeitraum(spanne: .monat, anker: "2026-11-16").verschoben(1).anker, "2026-12-16")
        XCTAssertEqual(Zeitraum(spanne: .jahr, anker: "2026-11-16").verschoben(1).anker, "2027-11-16")
    }

    /// Der 31. Maerz minus einen Monat ist nicht der 31. Februar. `Calendar` legt ihn auf den
    /// letzten Tag des Monats - und das ist die richtige Antwort.
    func testBlaetternUeberKurzeMonate() {
        XCTAssertEqual(Zeitraum(spanne: .monat, anker: "2026-03-31").verschoben(-1).anker, "2026-02-28")
        XCTAssertEqual(Zeitraum(spanne: .monat, anker: "2026-01-31").verschoben(1).anker, "2026-02-28")
        XCTAssertEqual(Zeitraum(spanne: .jahr, anker: "2024-02-29").verschoben(1).anker, "2025-02-28")
    }

    func testSpanneWechselnBehaeltDieStelle() {
        let z = Zeitraum(spanne: .tag, anker: "2026-11-16")
        XCTAssertEqual(z.mit(.monat).anker, "2026-11-16")
        XCTAssertEqual(z.mit(.monat).spanne, .monat)
    }

    // MARK: - Ist das jetzt?

    func testIstAktuell() {
        let jetzt = Tag.date("2026-11-18")!  // ein Mittwoch
        XCTAssertTrue(Zeitraum(spanne: .tag, anker: "2026-11-18").istAktuell(jetzt: jetzt))
        XCTAssertFalse(Zeitraum(spanne: .tag, anker: "2026-11-17").istAktuell(jetzt: jetzt))
        // Montag derselben Woche: dieselbe Woche.
        XCTAssertTrue(Zeitraum(spanne: .woche, anker: "2026-11-16").istAktuell(jetzt: jetzt))
        XCTAssertFalse(Zeitraum(spanne: .woche, anker: "2026-11-15").istAktuell(jetzt: jetzt))
        XCTAssertTrue(Zeitraum(spanne: .monat, anker: "2026-11-01").istAktuell(jetzt: jetzt))
        XCTAssertTrue(Zeitraum(spanne: .jahr, anker: "2026-01-01").istAktuell(jetzt: jetzt))
        XCTAssertFalse(Zeitraum(spanne: .jahr, anker: "2025-12-31").istAktuell(jetzt: jetzt))
    }

    /// Am Jahreswechsel muss „diese Woche" der Woche folgen und nicht dem Jahr. Sonst meldet die
    /// Anzeige am 1. Januar, die laufende Woche sei vorbei.
    func testIstAktuellAmJahreswechsel() {
        let silvester = Tag.date("2026-12-31")!
        XCTAssertTrue(Zeitraum(spanne: .woche, anker: "2027-01-01").istAktuell(jetzt: silvester))
    }

    // MARK: - Namen

    func testNamen() {
        XCTAssertEqual(Zeitraum(spanne: .tag, anker: "2026-11-10").name, "Dienstag, 10.11.2026")
        XCTAssertEqual(Zeitraum(spanne: .monat, anker: "2026-11-10").name, "November 2026")
        XCTAssertEqual(Zeitraum(spanne: .jahr, anker: "2026-11-10").name, "2026")
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-11-18").name, "KW 47 · 16.11. - 22.11.2026")
    }

    func testKurzeNamen() {
        XCTAssertEqual(Zeitraum(spanne: .tag, anker: "2026-11-10").kurz, "Di, 10.11.")
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-11-18").kurz, "KW 47")
        XCTAssertEqual(Zeitraum(spanne: .monat, anker: "2026-11-10").kurz, "Nov. 2026")
        XCTAssertEqual(Zeitraum(spanne: .jahr, anker: "2026-11-10").kurz, "2026")
    }

    /// Eine Woche, die ueber den Monatswechsel geht, muss beide Monate nennen.
    func testWochennameUeberDenMonatswechsel() {
        XCTAssertEqual(Zeitraum(spanne: .woche, anker: "2026-12-01").name, "KW 49 · 30.11. - 06.12.2026")
    }

    /// Ein unbrauchbarer Anker darf keinen „Invalid Date"-Namen ergeben.
    func testUnbrauchbarerAnker() {
        let z = Zeitraum(spanne: .tag, anker: "heute")
        XCTAssertEqual(z.name, "heute")
        XCTAssertNil(z.grenzen)
        XCTAssertNil(z.kalenderwoche)
        XCTAssertFalse(z.istAktuell())
        // Blaettern auf einem Untag aendert nichts, statt etwas zu erfinden.
        XCTAssertEqual(z.verschoben(-1).anker, "heute")
    }

    func testUeberlebtSpeichern() throws {
        let z = Zeitraum(spanne: .woche, anker: "2026-11-16")
        let roh = try JSONEncoder().encode(z)
        XCTAssertEqual(try JSONDecoder().decode(Zeitraum.self, from: roh), z)
        // Die Spanne muss als das Wort des Dienstes gespeichert werden, damit sie in eine Abfrage
        // gesetzt werden kann.
        XCTAssertEqual(Spanne.woche.rawValue, "week")
    }
}
