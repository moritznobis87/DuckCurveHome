import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/house/HouseScene.ts`,
/// `apps/web/src/components/house/HouseReport.tsx` und `apps/web/src/styles/handy.css`.
///
/// **Was hier geprüft wird, sieht man einem Bild nicht an.** Eine Drehung von 35,5 Grad sieht
/// genauso plausibel aus wie eine von 0 Grad - erst der Vergleich mit dem Startwert der Vorlage
/// zeigt, dass die App auf keiner ihrer vier Stellungen stand. Und ob die Vorlesestimme die
/// richtige Himmelsrichtung nennt, entscheidet der Sehstrahl, nicht das Auge.
final class HausbuehneTests: XCTestCase {

    // MARK: - Das Viertelraster

    /// `HouseScene.ts:300-302`: `thetaZiel += richtung * Math.PI / 2`.
    func testEinKlickIstGenauEineVierteldrehung() {
        let null = Hausdrehung.vorgabe
        XCTAssertEqual(null.bogenmass, 0, accuracy: 1e-12)
        XCTAssertEqual(null.gedreht(1).bogenmass, .pi / 2, accuracy: 1e-12)
        XCTAssertEqual(null.gedreht(1).gedreht(1).bogenmass, .pi, accuracy: 1e-12)
        XCTAssertEqual(null.gedreht(-1).bogenmass, -.pi / 2, accuracy: 1e-12)
    }

    /// **Die Vorgabe ist null** (`HouseReport.tsx:143`: `Number(params.get("dreh") ?? 0) ||
    /// undefined`, und `HouseScene.ts:271` setzt `theta` nur, wenn etwas dasteht). Die App stand
    /// bei 0,62 Bogenmaß; das ist keine Vierteldrehung, und genau das hält diese Prüfung fest.
    func testDieVorgabeIstDieUngedrehteStellungUndNichtNullKommaSechsZwei() {
        XCTAssertEqual(Hausdrehung.vorgabe.viertel, 0)
        XCTAssertEqual(Hausdrehung.vorgabe.bogenmass, 0, accuracy: 1e-12)
        XCTAssertNotEqual(Hausdrehung.vorgabe.bogenmass, 0.62)
        // Jede erreichbare Stellung ist ein ganzes Vielfaches von 90 Grad. 0,62 Bogenmaß sind
        // rund 35,5 Grad - von dort aus träfe kein einziger Klick eine gerade Seite.
        for k in -8...8 {
            let grad = Hausdrehung(viertel: k).bogenmass * 180 / .pi
            XCTAssertEqual(grad, Double(k) * 90, accuracy: 1e-9)
        }
        XCTAssertEqual(0.62 * 180 / .pi, 35.5, accuracy: 0.1)
    }

    /// **Gezählt wird ohne Grenze** (`HouseScene.ts:301`: `thetaZiel` wächst weiter). Wer auf
    /// vier zurückfaltet, dreht beim vierten Klick zurück statt weiter.
    func testVierKlicksZaehlenWeiterUndFaltenNichtAufNullZurueck() {
        var d = Hausdrehung.vorgabe
        for _ in 0..<4 { d = d.gedreht(1) }
        XCTAssertEqual(d.viertel, 4)
        XCTAssertEqual(d.bogenmass, 2 * .pi, accuracy: 1e-12)
        XCTAssertEqual(d.stellung, 0)
    }

    /// Swifts `%` behält das Vorzeichen des Zählers: ohne Rückgabe in den positiven Bereich wäre
    /// der erste Klick nach links keine der vier Stellungen.
    func testDieStellungLiegtImmerZwischenNullUndDrei() {
        XCTAssertEqual(Hausdrehung(viertel: -1).stellung, 3)
        XCTAssertEqual(Hausdrehung(viertel: -4).stellung, 0)
        XCTAssertEqual(Hausdrehung(viertel: -5).stellung, 3)
        XCTAssertEqual(Hausdrehung(viertel: 7).stellung, 3)
        for k in -20...20 {
            XCTAssertTrue((0...3).contains(Hausdrehung(viertel: k).stellung))
        }
    }

    /// Nur die Richtung zählt, wie in der Vorlage (`HouseScene.ts:300`, Typ `-1 | 1`).
    func testNurDasVorzeichenDerRichtungZaehlt() {
        XCTAssertEqual(Hausdrehung.vorgabe.gedreht(-3).viertel, -1)
        XCTAssertEqual(Hausdrehung.vorgabe.gedreht(5).viertel, 1)
        XCTAssertEqual(Hausdrehung.vorgabe.gedreht(0).viertel, 1)
    }

    // MARK: - Welche Wand dasteht

    /// **Der Name kommt aus der Rechnung, nicht aus einer Tabelle.**
    /// ``Hausgeometrie/strahl(drehung:)`` gibt den Sehstrahl zum Betrachter; seine stärkere
    /// waagerechte Komponente zeigt auf die zugewandte Wand. Die Buchstaben sind die der Vorlage
    /// (`geometrie.ts:9,57-62`: Norden bei kleinem z, Westen bei kleinem x).
    func testDieZugewandteWandFolgtDemSehstrahlDerGeometrie() {
        for k in -4...7 {
            let d = Hausdrehung(viertel: k)
            let blick = Hausgeometrie.strahl(drehung: d.bogenmass)
            let gerechnet: String =
                abs(blick.2) > abs(blick.0)
                ? (blick.2 > 0 ? "s" : "n")
                : (blick.0 > 0 ? "o" : "w")
            XCTAssertEqual(d.ansicht.seite, gerechnet, "bei \(k) Vierteldrehungen")
        }
    }

    /// Vom ungedrehten Haus aus geht es nach rechts über Osten, Norden und Westen zurück.
    func testDieVierStellungenLaufenVonSuedenUeberOstenNachWesten() {
        let folge = (0..<4).map { Hausdrehung(viertel: $0).ansicht }
        XCTAssertEqual(folge, [.sueden, .osten, .norden, .westen])
        // Die Reihenfolge der Fälle ist die der Klicks - darauf darf sich Lesbares stützen.
        XCTAssertEqual(Hausansicht.allCases, folge)
        XCTAssertEqual(Hausdrehung(viertel: -1).ansicht, .westen)
    }

    /// Die Vorlesestimme soll sagen können, welche der vier Stellungen dasteht.
    func testJedeStellungHatEinWortFuerDieStimmeUndEinesFuerDieWand() {
        XCTAssertEqual(Hausdrehung.vorgabe.ansicht.blick, "Blick von Süden")
        XCTAssertEqual(Hausdrehung.vorgabe.ansicht.wand, "Südseite")
        XCTAssertEqual(Hausdrehung(viertel: 1).ansicht.blick, "Blick von Osten")
        XCTAssertEqual(Hausdrehung(viertel: 2).ansicht.wand, "Nordseite")
        XCTAssertEqual(Hausdrehung(viertel: 3).ansicht.blick, "Blick von Westen")
        for a in Hausansicht.allCases {
            XCTAssertFalse(a.wand.isEmpty)
            XCTAssertTrue(a.blick.hasPrefix("Blick von "))
            XCTAssertEqual(a.seite.count, 1)
        }
        XCTAssertEqual(Set(Hausansicht.allCases.map(\.seite)), ["n", "s", "o", "w"])
    }

    // MARK: - Der Rahmen

    /// **Hochkant heißt: höher als breit.** `handy.css:393` gibt der Bühne am Telefon 58dvh bei
    /// der Breite der einspaltigen Inhaltsspalte (`globals.css:543`); auf 390 zu 844 Punkten sind
    /// das rund 0,731. Der Seitenrand ist 16 Punkte und nicht 14 (`handy.css:110`); hier stand
    /// `2 * 14` und daneben 0,739 - gerechnet mit einem Rand, den es in der Vorlage nicht gibt.
    func testDieBuehneStehtHochkantUndTrifftDieHoeheDerVorlageAmTelefon() {
        XCTAssertLessThan(Hausbuehne.seitenverhaeltnis, 1)
        XCTAssertEqual(Hausbuehne.seitenverhaeltnis, 0.75, accuracy: 1e-12)
        let breite = 390.0 - 2 * 16
        let hoehe = 0.58 * 844
        XCTAssertEqual(Hausbuehne.seitenverhaeltnis, breite / hoehe, accuracy: 0.02)
        // Aus der Breite der Bühne folgt ihre Höhe - und die liegt bei der Vorlage.
        XCTAssertEqual(breite / Hausbuehne.seitenverhaeltnis, hoehe, accuracy: 15)
    }
}
