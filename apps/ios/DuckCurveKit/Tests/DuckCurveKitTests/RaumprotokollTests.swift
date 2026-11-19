import XCTest

@testable import DuckCurveKit

final class RaumprotokollTests: XCTestCase {
    typealias P = Raumprotokoll

    // MARK: - Der Satz darüber

    /// **Die wichtigste Antwort ist „nichts".** Hat niemand gestellt, liegt die Ursache einer
    /// Abweichung nicht an der Regelung – und man muss woanders suchen.
    func testOhneAenderungSagtDerSatzGenauDas() {
        XCTAssertEqual(
            P.ueberschrift([], stunden: 48),
            "In 48 Stunden hat niemand den Sollwert verändert.")
    }

    func testEineAenderungIstEinzahl() {
        XCTAssertEqual(
            P.ueberschrift([eintrag(.extern)], stunden: 48),
            "Eine Änderung in 48 Stunden: 1× von außen.")
    }

    func testDieQuellenStehenInFesterReihenfolge() {
        let e = [eintrag(.app), eintrag(.automatik), eintrag(.extern), eintrag(.app)]
        XCTAssertEqual(
            P.ueberschrift(e, stunden: 24),
            "4 Änderungen in 24 Stunden: 1× von außen, 2× hier, 1× durch die Automatik.")
    }

    /// **Gezählt werden Sollwertänderungen, nicht Zeilen.** Ein abgeschickter Befehl, den der
    /// Regler nie zurückmeldete, hat den Sollwert eben nicht verändert.
    func testNurSollwertaenderungenZaehlen() {
        let e = [eintrag(.app, art: .befehl), eintrag(.app, art: .einstellung)]
        XCTAssertEqual(
            P.ueberschrift(e, stunden: 48),
            "In 48 Stunden hat niemand den Sollwert verändert.")
    }

    // MARK: - Die Zeile

    func testDerSprungZeigtBeideWerte() {
        XCTAssertEqual(
            P.sprungText(von: 21, nach: 22.5), "21,0 → " + Formate.celsius(22.5, stellen: 1))
        XCTAssertEqual(P.sprungText(von: nil, nach: 22), "auf " + Formate.celsius(22, stellen: 1))
        XCTAssertEqual(P.sprungText(von: 21, nach: nil), "")
    }

    func testJedeArtHatEinenSatz() {
        for a in RoomLogEntryOutArtWahl.allCases {
            XCTAssertFalse(P.artText(a).isEmpty)
        }
        XCTAssertEqual(P.artText(.befehl), "Befehl geschickt, aber nie gemeldet")
    }

    /// „Von außen" heißt nicht „unbefugt", sondern: nicht über dieses Werkzeug.
    func testJedeQuelleHatEinWort() {
        XCTAssertEqual(P.quelleWort(.extern), "von außen")
        XCTAssertEqual(P.quelleWort(.app), "hier gestellt")
        XCTAssertEqual(P.quelleWort(.automatik), "Automatik")
        for q in RoomLogEntryOutQuelleWahl.allCases {
            XCTAssertFalse(P.quelleWort(q).isEmpty)
        }
    }

    // MARK: - Die Spanne

    /// **Zwei Kelvin Mindestspanne.** Sonst bekommt ein Raum, der zwei Tage auf 0,3 K genau
    /// steht, eine Kurve wie ein Gebirge.
    func testRauschenBleibtEineWaagerechte() {
        let s = P.spanne([[21.0, 21.1, 20.9]])
        XCTAssertNotNil(s)
        XCTAssertGreaterThanOrEqual((s?.bis ?? 0) - (s?.von ?? 0), 2)
    }

    func testDieGrenzenLiegenAufHalbenGrad() {
        let s = P.spanne([[18.3, 23.4]])
        XCTAssertEqual(s?.von, 18.0)
        XCTAssertEqual(s?.bis, 23.5)
    }

    func testOhneEinenWertGibtEsKeineSpanne() {
        XCTAssertNil(P.spanne([[nil, nil], []]))
        XCTAssertNil(P.spanne([]))
    }

    func testBeideReihenZaehlenMit() {
        // Die Zielkurve darf nicht aus dem Bild laufen, nur weil sie höher liegt als die
        // gemessene.
        let s = P.spanne([[19.0, 19.2], [22.0, 22.0]])
        XCTAssertEqual(s?.von, 19.0)
        XCTAssertEqual(s?.bis, 22.0)
    }

    // MARK: - Die Kurvenstücke

    func testWerteWerdenAufDieSpanneGelegt() {
        let st = P.stuecke([20, 22], spanne: (von: 20, bis: 22))
        XCTAssertEqual(st.count, 1)
        XCTAssertEqual(st[0][0].y, 1, accuracy: 0.0001, "der untere Rand ist unten")
        XCTAssertEqual(st[0][1].y, 0, accuracy: 0.0001)
        XCTAssertEqual(st[0][0].x, 0, accuracy: 0.0001)
        XCTAssertEqual(st[0][1].x, 1, accuracy: 0.0001)
    }

    func testLueckenTrennen() {
        let st = P.stuecke([20, 20, nil, 21, 21], spanne: (von: 19, bis: 22))
        XCTAssertEqual(st.count, 2)
    }

    func testEinEinzelnerPunktIstKeineLinie() {
        XCTAssertTrue(P.stuecke([20, nil, 21], spanne: (von: 19, bis: 22)).isEmpty)
    }

    func testEineEntarteteSpanneGibtNichts() {
        XCTAssertTrue(P.stuecke([20, 21], spanne: (von: 20, bis: 20)).isEmpty)
    }

    // MARK: - Hilfe

    private func eintrag(
        _ q: RoomLogEntryOutQuelleWahl, art: RoomLogEntryOutArtWahl = .sollwert
    ) -> RoomLogEntryOut {
        RoomLogEntryOut(
            at: "2026-11-18T08:00:00+01:00", quelle: q, art: art, fromC: 21, toC: 21.5,
            text: "", urheber: nil)
    }
}
