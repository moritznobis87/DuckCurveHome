import XCTest

@testable import DuckCurveKit

/// Die Geometrie des Regelkreis-Schaltbilds. Dass ``Schaltbilddaten`` auf dem Stand von
/// `docs/regelkreis-schaltbild.json` ist, prüft `tools/gen-schaltbild.py --pruefen`; hier steht,
/// was die Zeichnung in sich halten muss, damit die App sie zeichnen und antippen kann.
final class SchaltbildTests: XCTestCase {
    func testDieKarteHatDieMasseDesDashboards() {
        XCTAssertEqual(Schaltbilddaten.breite, 1400)
        XCTAssertEqual(Schaltbilddaten.hoehe, 1300)
        XCTAssertEqual(Schaltbilddaten.sichten.map(\.schluessel), ["alles", "e4", "e3", "e1", "e0"])
        XCTAssertEqual(Schaltbilddaten.sichten.first?.ausschnitt, Schaltbild.Rechteck(x: 0, y: 0, w: 1400, h: 1300))
    }

    func testJedesRechteckLiegtAufDerKarte() {
        for (block, platz) in Schaltbilddaten.plaetze {
            for r in platz.alle {
                XCTAssertGreaterThan(r.w, 0, block)
                XCTAssertGreaterThan(r.h, 0, block)
                XCTAssertGreaterThanOrEqual(r.x, 0, block)
                XCTAssertGreaterThanOrEqual(r.y, 0, block)
                XCTAssertLessThanOrEqual(r.x + r.w, Schaltbilddaten.breite, block)
                XCTAssertLessThanOrEqual(r.y + r.h, Schaltbilddaten.hoehe, block)
            }
        }
    }

    func testJedeLeitungVerbindetZweiBloeckeMitPlatz() {
        for kante in Schaltbilddaten.wege.keys {
            let enden = kante.components(separatedBy: "→")
            XCTAssertEqual(enden.count, 2, kante)
            for ende in enden {
                XCTAssertNotNil(Schaltbilddaten.plaetze[ende], "\(kante): \(ende) hat keinen Platz")
            }
        }
        XCTAssertEqual(Schaltbild.kante(von: "preis", nach: "kosten_wp"), "preis→kosten_wp")
        XCTAssertNotNil(Schaltbilddaten.wege[Schaltbild.kante(von: "preis", nach: "kosten_wp")])
    }

    func testDieEntnahmeDesHeizkreisesSpringtUeberDieRueckfuehrung() {
        // Die eine Kreuzung der Karte (`layout.ts`): dort steht ein Sprungbogen.
        let weg = Schaltbilddaten.wege["heizkreis→puffer"]
        XCTAssertEqual(weg?.bogen, Schaltbild.Punkt(x: 800, y: 716))
        XCTAssertEqual(Schaltbilddaten.wege.values.filter { $0.bogen != nil }.count, 1)
    }

    func testEinBlockOhnePlatzLandetInDerReiheUnterDerKarte() {
        // Dieselbe Rechnung wie im Dashboard (`layout.test.ts`).
        XCTAssertEqual(Schaltbild.notplatz(0), Schaltbild.Rechteck(x: 28, y: 1272, w: 180, h: 44))
        XCTAssertEqual(Schaltbild.notplatz(6), Schaltbild.Rechteck(x: 1204, y: 1272, w: 180, h: 44))
        XCTAssertEqual(Schaltbild.notplatz(7), Schaltbild.Rechteck(x: 28, y: 1328, w: 180, h: 44))
        XCTAssertEqual(Schaltbild.rechteck(fuer: "gibt_es_nicht", ohnePlatz: 1), Schaltbild.notplatz(1))
        XCTAssertEqual(Schaltbild.rechteck(fuer: "puffer", ohnePlatz: 3), Schaltbilddaten.plaetze["puffer"]?.rect)
    }

    func testEinTippTrifftDenBlockAuchAnSeinerWiederholung() {
        let bloecke = ["preis", "aussen", "neu_im_kern", "puffer", "noch_einer"]
        // Die Außentemperatur steht oben und noch dreimal weiter unten.
        XCTAssertEqual(Schaltbild.block(bei: Schaltbild.Punkt(x: 700, y: 80), bloecke: bloecke), "aussen")
        XCTAssertEqual(Schaltbild.block(bei: Schaltbild.Punkt(x: 400, y: 380), bloecke: bloecke), "aussen")
        XCTAssertEqual(Schaltbild.block(bei: Schaltbild.Punkt(x: 850, y: 520), bloecke: bloecke), "puffer")
        // Zwei Blöcke, die die Zeichnung nicht kennt, liegen nebeneinander auf den Notplätzen.
        XCTAssertEqual(Schaltbild.block(bei: Schaltbild.Punkt(x: 40, y: 1290), bloecke: bloecke), "neu_im_kern")
        XCTAssertEqual(Schaltbild.block(bei: Schaltbild.Punkt(x: 240, y: 1290), bloecke: bloecke), "noch_einer")
        // Daneben ist nichts.
        XCTAssertNil(Schaltbild.block(bei: Schaltbild.Punkt(x: 1390, y: 700), bloecke: bloecke))
    }

    func testDieAufschriftenTragenDieWorteDesDashboards() {
        XCTAssertEqual(Schaltbilddaten.ebenen.count, 5)
        XCTAssertEqual(Schaltbilddaten.ebenen.first?.text, "EBENE 4 · ÖKONOMISCHE FÜHRUNG · TAKT 15 MIN, HORIZONT 48 H")
        XCTAssertEqual(Schaltbilddaten.beschriftungen.count, 6)
        XCTAssertTrue(Schaltbilddaten.beschriftungen.contains { $0.text == "Ti als Rückführung" && $0.anker == .middle })
    }
}
