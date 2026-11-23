import XCTest

@testable import DuckCurveKit

/// Die Farbskala des Wassers.
///
/// **Warum es dafür Tests gibt.** Die Skala sah in der App falsch aus, und zwar auf eine Art,
/// die man nicht als Fehler erkennt: die Farben waren richtig, nur die Temperaturen daneben
/// verschoben. Ein Puffer um 40 °C erschien cremefarben statt golden. Zwei Oberflächen, die
/// dieselbe Skala zeigen wollen, müssen dieselben Zahlen an denselben Stellen haben – und das
/// ist prüfbar.
final class WasserfarbeTests: XCTestCase {
    private func hex(_ f: Farbwert) -> String {
        String(format: "%02X%02X%02X",
               Int((f.rot * 255).rounded()), Int((f.gruen * 255).rounded()),
               Int((f.blau * 255).rounded()))
    }

    func testDieStuetzstellenSindDieDesDashboards() {
        // anlage/schema.ts, STOPS - Zahl fuer Zahl.
        XCTAssertEqual(hex(Marken.wasserfarbe(10)), "1A3A52")
        XCTAssertEqual(hex(Marken.wasserfarbe(25)), "1F4C66")
        XCTAssertEqual(hex(Marken.wasserfarbe(35)), "7FA3B3")
        XCTAssertEqual(hex(Marken.wasserfarbe(45)), "FFD778")
        XCTAssertEqual(hex(Marken.wasserfarbe(55)), "F2A900")
        XCTAssertEqual(hex(Marken.wasserfarbe(65)), "E0533D")
    }

    func testAusserhalbWirdNichtExtrapoliert() {
        XCTAssertEqual(hex(Marken.wasserfarbe(-20)), "1A3A52")
        XCTAssertEqual(hex(Marken.wasserfarbe(5)), "1A3A52")
        XCTAssertEqual(hex(Marken.wasserfarbe(90)), "E0533D")
    }

    func testOhneWertDasNeutraleBlaugrau() {
        XCTAssertEqual(hex(Marken.wasserfarbe(nil)), "7FA3B3")
        XCTAssertEqual(hex(Marken.wasserfarbe(Double.nan)), "7FA3B3")
    }

    func testDazwischenWirdGemischt() {
        // Genau zwischen 35 (7FA3B3) und 45 (FFD778) liegt die Mitte beider Kanaele.
        //
        // **Mit einer Einheit Spielraum, und das ist kein Nachgeben.** Eine Mitte von 149,5
        // rundet in Fliesskomma nach 149, im Dashboard (`Math.round`) nach 150. Auf eine
        // exakte Hexzahl zu pruefen hiesse, diesen Unterschied zum Fehler zu erklaeren - er
        // ist auf keinem Bildschirm zu sehen. An den Stuetzstellen oben wird exakt geprueft;
        // dort gibt es nichts zu runden, und dort sass der echte Fehler.
        let m = Marken.wasserfarbe(40)
        for (name, ist, soll) in [("rot", m.rot, 0xBF), ("gruen", m.gruen, 0xBD), ("blau", m.blau, 0x96)] {
            XCTAssertEqual(ist * 255, Double(soll), accuracy: 1.0, name)
        }
        // Und es ist wirklich eine Mischung, keine Stufe:
        XCTAssertNotEqual(hex(Marken.wasserfarbe(36)), hex(Marken.wasserfarbe(44)))
    }

    /// **Ab der Komforttemperatur muss das Glas warm aussehen - vorher nicht.**
    ///
    /// Hier stand „bei 40 Grad", geprueft wurde 42, und bei 40 faellt dieselbe Zusicherung durch
    /// (0,163 gegen die geforderten 0,25). Der Test, der genau diesen Anblick verhindern sollte,
    /// liess ihn durch.
    ///
    /// **Entschieden: die Grenze ist 42, nicht die Skala.** 42 °C ist keine runde Zahl, sondern
    /// `BufferConfig.comfort_min_top_c` - die Temperatur, ab der die Oberkante des Puffers
    /// Komfortwaerme liefert. Darunter ist blass die richtige Auskunft: eine flache Saeule bei
    /// 40 °C ergibt 18 % Ladestand und das Wort „kalt" (`usable_energy_kwh([40,40,40,39])`,
    /// 5,523 von 31,395 kWh). Ein goldenes Glas neben dem Wort „kalt" waere ein Widerspruch auf
    /// derselben Kachel, und genau fuer solche Widersprueche haengt die Anzeige an der Wand.
    ///
    /// **Was die Gegenentscheidung gekostet haette.** Die Stuetzstellen bei 40 bunter zu machen
    /// heisst, von `apps/web/src/components/anlage/schema.ts` (`STOPS`) abzuweichen - der
    /// Vorlage, deren Zahlen `testDieStuetzstellenSindDieDesDashboards` Zahl fuer Zahl festhaelt.
    /// Dieselbe Skala in zwei Oberflaechen muss dieselben Zahlen an denselben Stellen zeigen;
    /// zwei Haeuser derselben Temperatur in verschiedenen Farben waren der Fehler, der diese
    /// Datei ueberhaupt entstehen liess.
    func testEinPufferAbDerKomforttemperaturIstNichtBlass() {
        let f = Marken.wasserfarbe(42)
        // Rot deutlich ueber Blau: die warme Haelfte der Skala.
        XCTAssertGreaterThan(f.rot, f.blau + 0.25, "42 Grad muss warm aussehen, nicht blaulich")
    }

    /// Die Gegenrichtung, damit die Entscheidung von oben nicht still kippt: bei 40 Grad ist das
    /// Glas noch nicht warm. Wer die Stuetzstellen verschiebt, faellt hier auf - und nicht erst
    /// an einer Wandanzeige, die einen Puffer mit 18 % golden zeigt.
    func testEinPufferUm40GradIstNochNichtWarm() {
        let f = Marken.wasserfarbe(40)
        XCTAssertLessThan(f.rot, f.blau + 0.25, "40 Grad gehoert in den blassen Uebergang")
        // Aber auch nicht mehr kalt-petrol: der Uebergang hat bei 40 schon begonnen.
        XCTAssertGreaterThan(f.rot, f.blau)
    }
}
