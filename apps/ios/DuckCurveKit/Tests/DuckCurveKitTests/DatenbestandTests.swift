import XCTest

@testable import DuckCurveKit

/// Die Platzbedarfstabelle gegen ihre Vorlage:
/// `apps/web/src/components/settings/StorageReport.tsx:21-83`.
///
/// **Geprüft werden die vier Entscheidungen, nicht die Zahlen.** Dass 1 MB als „1 MB“ dasteht,
/// prüfen die ``FormateTests``. Hier geht es darum, *welche* Zeilen überhaupt dastehen, in
/// welcher Reihenfolge, welcher von vier Zuständen gilt und was die Schlusszeile nennt - also
/// genau das, was bis zum Umbau in einer `View` stand und dort nicht zu prüfen war.
final class DatenbestandTests: XCTestCase {

    private func tabelle(_ name: String, zeilen: Int, daten: Int, index: Int) -> StorageTableOut {
        StorageTableOut(
            name: name, totalBytes: daten + index, tableBytes: daten, indexBytes: index,
            rowsEstimate: zeilen)
    }

    private func bericht(_ tabellen: [StorageTableOut], gesamt: Int? = nil, note: String = "Gemessen an den Seiten, die PostgreSQL für diese Tabellen führt.")
        -> StorageReportOut
    {
        StorageReportOut(
            tables: tabellen,
            totalBytes: gesamt ?? tabellen.reduce(0) { $0 + $1.totalBytes },
            rawRetentionDays: 14,
            noteDe: note)
    }

    // MARK: - Welche Zeilen dastehen

    /// `StorageReport.tsx:45`: `filter(t => t.total_bytes > 0)`.
    ///
    /// Eine Tabelle mit null Byte ist angelegt und leer - sie beantwortet die Frage „wo liegt
    /// der Platz?“ nicht, sondern verlängert die Liste.
    func testLeereTabellenFallenWeg() {
        let b = bericht([
            tabelle("measurements_raw", zeilen: 1_234_567, daten: 400_000_000, index: 600_000_000),
            tabelle("config_versions", zeilen: 0, daten: 0, index: 0),
            tabelle("door_events", zeilen: 12, daten: 8192, index: 8192),
        ])
        XCTAssertEqual(Datenbestand.posten(b).map(\.name), ["measurements_raw", "door_events"])
    }

    /// `StorageReport.tsx:45`: `.slice(0, 8)` - höchstens acht Zeilen.
    func testHoechstensAchtZeilen() {
        let viele = (1...12).map { tabelle("t\($0)", zeilen: $0, daten: 1_048_576, index: 0) }
        let posten = Datenbestand.posten(bericht(viele))
        XCTAssertEqual(posten.count, 8)
        XCTAssertEqual(posten.first?.name, "t1")
        XCTAssertEqual(posten.last?.name, "t8")
    }

    /// Die Reihenfolge ist die des Dienstes und wird nicht nachsortiert.
    ///
    /// Sortierte die App selbst nach Größe, stünde in ihr eine andere Rangliste als an der
    /// Wand, sobald der Dienst seine Reihenfolge einmal ändert.
    func testReihenfolgeBleibtWieGeliefert() {
        let b = bericht([
            tabelle("klein", zeilen: 1, daten: 1024, index: 0),
            tabelle("gross", zeilen: 9, daten: 900_000_000, index: 0),
        ])
        XCTAssertEqual(Datenbestand.posten(b).map(\.name), ["klein", "gross"])
    }

    func testOhneTabellenKeineZeilen() {
        XCTAssertTrue(Datenbestand.posten(bericht([])).isEmpty)
    }

    /// Alle Tabellen leer: gefiltert bleibt nichts, aber es ist nicht derselbe Fall wie „keine
    /// Tabellen“ - der Dienst hat geantwortet, und die Summe steht trotzdem darunter.
    func testNurLeereTabellenErgebenEineLeereTabelleUndKeinenLeerstand() {
        let b = bericht([tabelle("a", zeilen: 0, daten: 0, index: 0)])
        XCTAssertTrue(Datenbestand.posten(b).isEmpty)
        XCTAssertEqual(Datenbestand.stand(b, fehlgeschlagen: false), .tabelle([]))
    }

    // MARK: - Was in den Zellen steht

    /// Die vier Spalten in der Reihenfolge der Vorlage (`StorageReport.tsx:52-56`), und die
    /// zwei Maße, die sie benutzt: binäre Bytes und abgekürzte Zeilen.
    func testZellenInDerReihenfolgeDerVorlage() {
        let b = bericht([
            tabelle("measurements_raw", zeilen: 1_234_567, daten: 1_073_741_824, index: 1_048_576)
        ])
        let p = Datenbestand.posten(b)[0]
        XCTAssertEqual(p.zeilen, "1.235 Tsd.")
        XCTAssertEqual(p.daten, "1 GB")
        XCTAssertEqual(p.indizes, "1 MB")
        // 1 GiB + 1 MiB = 1073741824 + 1048576 Byte, binär also 1,00097… GB -> „1 GB“.
        XCTAssertEqual(p.gesamt, "1 GB")
        XCTAssertEqual(p.zellen, [p.zeilen, p.daten, p.indizes, p.gesamt])
        XCTAssertEqual(Datenbestand.spalten, ["Zeilen", "Daten", "Indizes", "gesamt"])
    }

    /// Unter tausend Zeilen steht die Zahl selbst (`StorageReport.tsx:27`), und ein halbes
    /// Megabyte ist „0,5 MB“ und nicht „512 KB“ - die Vorlage kennt keine Kilobyte.
    func testKleineTabelleBleibtInMegabyteUndGanzenZeilen() {
        let b = bericht([tabelle("door_events", zeilen: 512, daten: 524_288, index: 0)])
        let p = Datenbestand.posten(b)[0]
        XCTAssertEqual(p.zeilen, "512")
        XCTAssertEqual(p.daten, "0,5 MB")
    }

    // MARK: - Die Schlusszeile

    /// `StorageReport.tsx:76`: die Summe kommt aus `total_bytes` des Berichts, nicht aus den
    /// acht gezeigten Zeilen.
    func testSummeKommtVomDienstUndNichtAusDenGezeigtenZeilen() {
        let viele = (1...12).map { tabelle("t\($0)", zeilen: $0, daten: 1_048_576, index: 0) }
        let b = bericht(viele, gesamt: 12 * 1_048_576)
        XCTAssertEqual(Datenbestand.gesamt(b), "12 MB")
        XCTAssertEqual(Datenbestand.summenwort, "alle Tabellen")
    }

    func testAufbewahrungIstDieZahlDesDienstes() {
        XCTAssertEqual(Datenbestand.aufbewahrung(bericht([])), "14")
    }

    // MARK: - Die vier Zustände

    /// `StorageReport.tsx:41-43` fragt in dieser Reihenfolge: Fehler, dann fehlende Antwort,
    /// dann leere Liste. Wer anders prüft, zeigt nach einem Fehlschlag für immer „lädt …“.
    func testFehlerGehtVorAllemAnderen() {
        XCTAssertEqual(
            Datenbestand.stand(nil, fehlgeschlagen: true), .fehler(Datenbestand.fehlerwort))
        // Auch wenn schon eine Antwort da war: ein gescheiterter Nachschlag ist ein Fehler.
        let b = bericht([tabelle("a", zeilen: 1, daten: 1_048_576, index: 0)])
        XCTAssertEqual(
            Datenbestand.stand(b, fehlgeschlagen: true), .fehler(Datenbestand.fehlerwort))
    }

    func testOhneAntwortWirdGeladen() {
        XCTAssertEqual(Datenbestand.stand(nil, fehlgeschlagen: false), .laedt)
    }

    /// Keine Tabellen: dann steht der Satz des Dienstes da und keine leere Tabelle
    /// (`StorageReport.tsx:43`).
    func testKeineTabellenZeigenDenSatzDesDienstes() {
        let b = bericht([], note: "Diese Datenbank meldet keine Größen.")
        XCTAssertEqual(
            Datenbestand.stand(b, fehlgeschlagen: false), .leer("Diese Datenbank meldet keine Größen."))
    }

    func testMitTabellenStehtDieTabelle() {
        let b = bericht([tabelle("a", zeilen: 1, daten: 1_048_576, index: 0)])
        guard case .tabelle(let posten) = Datenbestand.stand(b, fehlgeschlagen: false) else {
            return XCTFail("Mit Tabellen muss der Stand die Tabelle sein.")
        }
        XCTAssertEqual(posten.map(\.name), ["a"])
    }

    /// Die zwei festen Wörter, die die Vorlage schreibt - sie sind der Unterschied zwischen
    /// „noch nichts da“ und „geht nicht“, und beide standen in der App nirgends.
    func testDieWoerterDerZustaende() {
        XCTAssertEqual(Datenbestand.fehlerwort, "Die Größen konnten nicht abgefragt werden.")
        XCTAssertEqual(Datenbestand.ladewort, "lädt …")
    }
}
