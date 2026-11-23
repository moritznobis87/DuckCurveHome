import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/waerme/tagesuhr.ts`.
///
/// **Diese Prüfungen stehen getrennt**, weil die Geometrie getrennt steht - aus dem Grund, den die
/// Vorlage nennt: „hier sitzen die Fehler, die man einem Bild nicht ansieht“ (`tagesuhr.ts:3-6`).
final class TagesuhrgeometrieTests: XCTestCase {

    private let anfang = Zeit.ausIso("2026-11-07T00:00:00+01:00")!
    private var ende: Date { anfang.addingTimeInterval(24 * 3600) }

    // MARK: - Anteil

    func testDerAnteilLiegtZwischenNullUndEinsUndWirdBeschnitten() {
        XCTAssertEqual(Tagesuhrgeometrie.anteil(anfang, von: anfang, bis: ende), 0)
        XCTAssertEqual(Tagesuhrgeometrie.anteil(ende, von: anfang, bis: ende), 1)
        XCTAssertEqual(
            Tagesuhrgeometrie.anteil(
                anfang.addingTimeInterval(6 * 3600), von: anfang, bis: ende),
            0.25, accuracy: 1e-12)
        XCTAssertEqual(
            Tagesuhrgeometrie.anteil(anfang.addingTimeInterval(-3600), von: anfang, bis: ende), 0)
        XCTAssertEqual(
            Tagesuhrgeometrie.anteil(ende.addingTimeInterval(3600), von: anfang, bis: ende), 1)
    }

    func testEinUmgekehrterOderLeererTagGibtNullStattEinerDivision() {
        XCTAssertEqual(Tagesuhrgeometrie.anteil(anfang, von: ende, bis: anfang), 0)
        XCTAssertEqual(Tagesuhrgeometrie.anteil(anfang, von: anfang, bis: anfang), 0)
    }

    /// **Der Winkel ist der Anteil am Tag, nicht die Uhrzeit** (`tagesuhr.ts:8-10`).
    ///
    /// An einem Tag mit 25 Stunden liegt 12:00 nicht oben gegenüber, sondern etwas davor. Aus der
    /// Uhrzeit gerechnet bliebe eine Stunde offen oder läge doppelt.
    func testAmUmstellungstagTeiltDerAnteilDenGanzenTagUndNichtVierundzwanzigStunden() {
        let langerTag = anfang.addingTimeInterval(25 * 3600)
        let mittag = anfang.addingTimeInterval(12 * 3600)
        XCTAssertEqual(
            Tagesuhrgeometrie.anteil(mittag, von: anfang, bis: langerTag), 12.0 / 25.0,
            accuracy: 1e-12)
        // Das Ende des Tages liegt auf 1 - kein offener Rest.
        XCTAssertEqual(Tagesuhrgeometrie.anteil(langerTag, von: anfang, bis: langerTag), 1)
        let kurzerTag = anfang.addingTimeInterval(23 * 3600)
        XCTAssertEqual(Tagesuhrgeometrie.anteil(kurzerTag, von: anfang, bis: kurzerTag), 1)
    }

    // MARK: - Punkt und Winkel

    func testAnteilNullLiegtObenUndEsGehtImUhrzeigersinn() {
        let m = Tagesuhrgeometrie.mitte
        let oben = Tagesuhrgeometrie.punkt(r: 100, anteil: 0)
        XCTAssertEqual(oben.x, m, accuracy: 1e-9)
        XCTAssertEqual(oben.y, m - 100, accuracy: 1e-9)
        let rechts = Tagesuhrgeometrie.punkt(r: 100, anteil: 0.25)
        XCTAssertEqual(rechts.x, m + 100, accuracy: 1e-9)
        XCTAssertEqual(rechts.y, m, accuracy: 1e-9)
        let unten = Tagesuhrgeometrie.punkt(r: 100, anteil: 0.5)
        XCTAssertEqual(unten.y, m + 100, accuracy: 1e-9)
        let links = Tagesuhrgeometrie.punkt(r: 100, anteil: 0.75)
        XCTAssertEqual(links.x, m - 100, accuracy: 1e-9)
    }

    func testDerAnteilUnterDemZeigerIstDieUmkehrungDesPunktes() {
        for a in stride(from: 0.0, to: 1.0, by: 0.05) {
            let p = Tagesuhrgeometrie.punkt(r: 120, anteil: a)
            let zurueck = Tagesuhrgeometrie.anteilAus(
                dx: p.x - Tagesuhrgeometrie.mitte, dy: p.y - Tagesuhrgeometrie.mitte)
            XCTAssertEqual(zurueck, a, accuracy: 1e-9, "Anteil \(a)")
        }
    }

    func testDerAnteilUnterDemZeigerBleibtImmerPositiv() {
        // Links oben: in Bildschirmkoordinaten negativer Winkel, als Tagesanteil drei Viertel.
        XCTAssertEqual(Tagesuhrgeometrie.anteilAus(dx: -100, dy: 0), 0.75, accuracy: 1e-9)
        XCTAssertEqual(Tagesuhrgeometrie.anteilAus(dx: -1, dy: -100), 1, accuracy: 0.01)
    }

    // MARK: - Der Griff

    /// **Die Mitte gehört der Anzeige** (`Tagesuhr.tsx:208`): „Wer dort klickt, will lesen und
    /// nicht springen.“
    func testDieTrefferzoneEndetInnenBeiSiebzigUndAussenBeiHundertachtundsiebzig() {
        XCTAssertFalse(Tagesuhrgeometrie.imGriff(dx: 0, dy: 0))
        XCTAssertFalse(Tagesuhrgeometrie.imGriff(dx: 69.9, dy: 0))
        XCTAssertTrue(Tagesuhrgeometrie.imGriff(dx: 70, dy: 0))
        XCTAssertTrue(Tagesuhrgeometrie.imGriff(dx: 0, dy: 178))
        XCTAssertFalse(Tagesuhrgeometrie.imGriff(dx: 0, dy: 178.1))
        // Schräg zählt der Abstand, nicht die größere Achse.
        XCTAssertTrue(Tagesuhrgeometrie.imGriff(dx: 120, dy: 120))
        XCTAssertFalse(Tagesuhrgeometrie.imGriff(dx: 140, dy: 140))
    }

    // MARK: - Ringstücke

    func testEinVollerRingWirdInZweiHaelftenGeteilt() {
        let stuecke = Tagesuhrgeometrie.bogenstuecke(von: 0, bis: 1)
        XCTAssertEqual(stuecke.count, 2, "ein Bogen von einem Punkt zu demselben hat Länge null")
        XCTAssertEqual(stuecke[0].von, 0)
        XCTAssertEqual(stuecke[0].bis, 0.5, accuracy: 1e-12)
        XCTAssertEqual(stuecke[1].von, 0.5, accuracy: 1e-12)
        XCTAssertEqual(stuecke[1].bis, 0.9999, accuracy: 1e-12)
    }

    func testEinGewoehnlichesStueckBleibtEinStueck() {
        let stuecke = Tagesuhrgeometrie.bogenstuecke(von: 0.25, bis: 0.4)
        XCTAssertEqual(stuecke.count, 1)
        XCTAssertEqual(stuecke[0].von, 0.25)
        XCTAssertEqual(stuecke[0].bis, 0.4)
    }

    func testEineSpanneVonNullErgibtKeinStueck() {
        XCTAssertTrue(Tagesuhrgeometrie.bogenstuecke(von: 0.3, bis: 0.3).isEmpty)
        XCTAssertTrue(Tagesuhrgeometrie.bogenstuecke(von: 0.7, bis: 0.2).isEmpty)
        XCTAssertTrue(Tagesuhrgeometrie.bogenstuecke(von: 0, bis: .nan).isEmpty)
    }

    // MARK: - Die Stelle unter dem Zeiger

    func testOhneBilderGibtEsKeineStelle() {
        XCTAssertNil(Tagesuhrgeometrie.indexBei(anteil: 0.5, zeiten: [], von: anfang, bis: ende))
    }

    func testDieStelleUnterDemZeigerIstDieZeitlichNaechsteUndKeineGerechnete() {
        // Bilder nur ab 12:00, im Fünfminutenschritt: der Vormittag fehlt.
        let zeiten = (0..<144).map {
            anfang.addingTimeInterval(12 * 3600 + Double($0) * 300)
        }
        // Ein Griff auf den Vormittag landet auf dem ersten vorhandenen Bild und nicht
        // irgendwo in der Mitte der Liste.
        XCTAssertEqual(
            Tagesuhrgeometrie.indexBei(anteil: 0.1, zeiten: zeiten, von: anfang, bis: ende), 0)
        XCTAssertEqual(
            Tagesuhrgeometrie.indexBei(anteil: 0.5, zeiten: zeiten, von: anfang, bis: ende), 0)
        // 18:00 ist sechs Stunden nach 12:00, also 72 Bilder.
        XCTAssertEqual(
            Tagesuhrgeometrie.indexBei(anteil: 0.75, zeiten: zeiten, von: anfang, bis: ende), 72)
        XCTAssertEqual(
            Tagesuhrgeometrie.indexBei(anteil: 1, zeiten: zeiten, von: anfang, bis: ende), 143)
    }

    // MARK: - Die Maße

    func testDieRingeStossenNichtAneinander() {
        let ringe = [
            Tagesuhrgeometrie.ringPreis, Tagesuhrgeometrie.ringSonne,
            Tagesuhrgeometrie.ringGeplant, Tagesuhrgeometrie.ringGelaufen,
            Tagesuhrgeometrie.ringOfen,
        ]
        for r in ringe {
            XCTAssertGreaterThan(r.aussen, r.innen)
        }
        // Von außen nach innen, und zwischen je zweien bleiben drei Punkte frei.
        for paar in zip(ringe, ringe.dropFirst()) {
            XCTAssertEqual(paar.0.innen - paar.1.aussen, 3, accuracy: 1e-9)
        }
        // Die Stundenstriche liegen außerhalb des äußersten Rings, die Zahlen dahinter.
        XCTAssertGreaterThan(Tagesuhrgeometrie.strichInnen, Tagesuhrgeometrie.ringPreis.aussen)
        XCTAssertGreaterThan(
            Tagesuhrgeometrie.zahlenradius, Tagesuhrgeometrie.strichAussenStark)
    }

    func testDerZeigerReichtMitOfenWeiterNachInnen() {
        XCTAssertLessThan(
            Tagesuhrgeometrie.zeigerInnen(mitOfen: true),
            Tagesuhrgeometrie.zeigerInnen(mitOfen: false))
        // Er endet innerhalb der Stundenstriche, nicht über ihnen.
        XCTAssertLessThan(Tagesuhrgeometrie.zeigerAussen, Tagesuhrgeometrie.strichInnen)
    }
}
