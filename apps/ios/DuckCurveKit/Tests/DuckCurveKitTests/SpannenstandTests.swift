import XCTest

@testable import DuckCurveKit

/// Der eigene Zustand des Spannenstreifens: vier Abfragen zu einem Anker, und was passiert,
/// wenn eine, alle oder der Anker selbst wegfällt.
///
/// Gegen die Vorlage `apps/web/src/components/reports/useReport.ts:55-77` (`useMultiPeriod`:
/// `Promise.allSettled` über die vier Spannen, Zustand nur am Anker).
final class SpannenstandTests: XCTestCase {

    private let leer = Spannenstand<String>()

    // MARK: - Vier Spannen in einem Zug

    func testHoltAlleVierUndLaesstGescheiterteWeg() async {
        let stand = await leer.nachgeholt(zu: "2026-11-10") { s in
            if s == .monat { throw ApiFehler(code: "zeit", meldung: "zu lange", status: 504) }
            return s.rawValue
        }
        XCTAssertEqual(stand.anker, "2026-11-10")
        XCTAssertEqual(stand.werte.count, 3)
        XCTAssertEqual(stand.werte[.tag], "day")
        XCTAssertNil(stand.werte[.monat])
        XCTAssertEqual(stand.werte[.jahr], "year")
        // Drei Spalten stehen - das ist kein Fall für ein Fehlerband.
        XCTAssertNil(stand.fehler)
    }

    /// Erst wenn **keine** der vier antwortet, trägt der Stand einen Grund: ein Streifen aus
    /// Strichen ohne Erklärung ist schlechter als eine Meldung.
    func testOhneEineEinzigeAntwortStehtDerGrundDa() async {
        let stand = await leer.nachgeholt(zu: "2026-11-10") { _ in
            throw ApiFehler(code: "netz", meldung: "Keine Verbindung zum Haus.", status: 0)
        }
        XCTAssertTrue(stand.werte.isEmpty)
        XCTAssertEqual(stand.fehler?.code, "netz")
    }

    /// Ein Fehler, der kein ``ApiFehler`` ist, bekommt trotzdem einen Satz.
    func testFremderFehlerWirdZuEinemSatzFuerMenschen() async {
        struct Eigen: Error {}
        let stand = await leer.nachgeholt(zu: "2026-11-10") { _ in throw Eigen() }
        XCTAssertEqual(stand.fehler?.code, "network")
    }

    // MARK: - Was dasteht, bleibt stehen

    func testNachholenBehaeltDieSpalteDieDiesmalAussetzt() async {
        let erst = await leer.nachgeholt(zu: "2026-11-10") { $0.rawValue }
        XCTAssertEqual(erst.werte.count, 4)

        let dann = await erst.nachgeholt(zu: "2026-11-10") { s in
            if s == .jahr { throw ApiFehler(code: "zeit", meldung: "zu lange", status: 504) }
            return "neu-\(s.rawValue)"
        }
        XCTAssertEqual(dann.werte[.tag], "neu-day")
        // Die Jahresspalte hält ihre Zahl aus dem Lauf davor, statt zum Strich zu werden.
        XCTAssertEqual(dann.werte[.jahr], "year")
        XCTAssertNil(dann.fehler)
    }

    /// Beim Ankerwechsel fängt der Stand leer an: die Zahlen des alten Tages sind für den
    /// neuen keine Auskunft.
    func testBeimAnkerwechselBleibtNichtsStehen() async {
        let erst = await leer.nachgeholt(zu: "2026-11-10") { $0.rawValue }
        let dann = await erst.nachgeholt(zu: "2026-11-03") { s in
            if s == .tag { throw ApiFehler(code: "zeit", meldung: "zu lange", status: 504) }
            return "neu-\(s.rawValue)"
        }
        XCTAssertEqual(dann.anker, "2026-11-03")
        XCTAssertNil(dann.werte[.tag])
        XCTAssertEqual(dann.werte[.woche], "neu-week")
    }

    // MARK: - Der Stand und sein Anker

    func testFuerDenEigenenAnkerDerStandSelbstUndSonstEinLeerer() async {
        let stand = await leer.nachgeholt(zu: "2026-11-10") { $0.rawValue }
        XCTAssertEqual(stand.fuer("2026-11-10").werte.count, 4)

        let fremd = stand.fuer("2026-11-03")
        XCTAssertEqual(fremd.anker, "2026-11-03")
        XCTAssertTrue(fremd.werte.isEmpty)
        XCTAssertNil(fremd.fehler)
    }

    /// Auch das Fehlerband gehört zu einem Anker: beim Blättern darf die Meldung des alten
    /// Tages nicht über dem neuen stehen bleiben.
    func testEinFehlerGiltNurFuerSeinenAnker() async {
        let stand = await leer.nachgeholt(zu: "2026-11-10") { _ in
            throw ApiFehler(code: "netz", meldung: "Keine Verbindung zum Haus.", status: 0)
        }
        XCTAssertEqual(stand.fuer("2026-11-10").fehler?.code, "netz")
        XCTAssertNil(stand.fuer("2026-11-03").fehler)
    }

    // MARK: - Was geschrieben werden darf

    /// Der verwaiste Lauf des Knopfes „Noch einmal“ darf den neuen Anker nicht löschen.
    ///
    /// Der Weg hinein: alle vier Spalten zu A fallen aus, das Band steht, der Nutzer tippt
    /// „Noch einmal“, blättert auf B und der alte Lauf kommt **danach** zurück. Schreibt er
    /// seinen A-Stand, zeigt ``Spannenstand/fuer(_:)`` beim Zeichnen einen leeren: vier
    /// Striche, kein Fehler, also auch kein Band und kein Knopf mehr.
    func testEinLaufZuEinemVergangenenAnkerWirdVerworfen() async {
        var stand = await leer.nachgeholt(zu: "2026-11-03") { $0.rawValue }
        let alt = await leer.nachgeholt(zu: "2026-11-10") { _ in
            throw ApiFehler(code: "netz", meldung: "Keine Verbindung zum Haus.", status: 0)
        }

        stand.uebernimm(alt, zu: "2026-11-03")
        XCTAssertEqual(stand.anker, "2026-11-03")
        XCTAssertEqual(stand.werte.count, 4, "der alte Lauf hat den neuen Anker überschrieben")

        // Derselbe Lauf, solange sein Anker noch oben steht: er gehört dorthin und wird
        // übernommen - sonst stünde das Fehlerband nach dem Knopfdruck nie wieder da.
        var aufAltemAnker = Spannenstand<String>(anker: "2026-11-10")
        aufAltemAnker.uebernimm(alt, zu: "2026-11-10")
        XCTAssertEqual(aufAltemAnker.fehler?.code, "netz")
    }

    /// Der erste Lauf einer Seite trifft einen Stand ohne Anker - und muss durchkommen.
    func testDerErsteLaufKommtDurch() async {
        var stand = leer
        let erst = await leer.nachgeholt(zu: "2026-11-10") { $0.rawValue }
        stand.uebernimm(erst, zu: "2026-11-10")
        XCTAssertEqual(stand.werte.count, 4)
    }

    func testDerTaktIstDerDerVorlage() {
        XCTAssertEqual(Berichtstakt.nachladen, .seconds(300))
    }
}
