import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/BatteryControl.tsx`.
///
/// Geprüft wird, was entschieden wird: welcher Knopf gedrückt aussieht, was `off` bedeutet,
/// welche Betriebsart eine Untergrenze mitsendet, die Frist von zwei Stunden, die fünf Stufen
/// und die zusammengesetzte Notenzeile samt ihrer Rangfolge.
final class SpeichersteuerungTests: XCTestCase {

    private let schmal = Formate.schmalesLeerzeichen

    private func stand(
        frei: Bool? = true, art: BatteryLiveOutModeWahl? = .auto, reserve: Double? = 0.1,
        soc: Double? = 0.54, befehl: BatteryLiveOutCommandWahl? = nil,
        letzterFehler: String? = nil, hinweis: String? = "Untergrenze 10 %."
    ) -> BatteryLiveOut {
        BatteryLiveOut(
            controlEnabled: frei, mode: art, reserveSoc: reserve, soc: soc, command: befehl,
            lastError: letzterFehler, noteDe: hinweis)
    }

    // MARK: - Die drei Betriebsarten

    func testDreiBetriebsartenMitDenWoertenDerVorlage() {
        XCTAssertEqual(Speichersteuerung.arten.map(\.wort), ["Auto", "Frei", "Halten"])
        XCTAssertEqual(
            Speichersteuerung.arten.map(\.wahl), [.auto, .normal, .hold])
        XCTAssertTrue(Speichersteuerung.arten[0].dazu.hasPrefix("Untergrenze aktiv"))
        XCTAssertTrue(Speichersteuerung.arten[2].dazu.contains("hält auch das Laden an"))
    }

    /// `off` ist die Vorgabe und heisst: DCH sendet gar nichts. Für die Anzeige ist das
    /// dasselbe wie „Frei“ - der Unterschied steht in der Zeile darunter.
    func testOffSiehtAusWieFrei() {
        XCTAssertEqual(Speichersteuerung.gezeigteArt(stand(art: .off)), .normal)
        XCTAssertEqual(Speichersteuerung.gezeigteArt(stand(art: .normal)), .normal)
        XCTAssertEqual(Speichersteuerung.gezeigteArt(stand(art: .hold)), .hold)
        XCTAssertEqual(Speichersteuerung.gezeigteArt(stand(art: nil)), .normal)
        XCTAssertEqual(Speichersteuerung.gezeigteArt(stand(art: .unbekannt)), .normal)
    }

    /// Eine Untergrenze zu setzen und zugleich „sende nichts“ zu meinen wäre eine Einstellung
    /// ohne Wirkung - aus `off` wird darum `auto`.
    func testUntergrenzeSchaltetAusOffNachAuto() {
        XCTAssertEqual(Speichersteuerung.stellwahl(stand(art: .off)), .auto)
        XCTAssertEqual(Speichersteuerung.stellwahl(stand(art: nil)), .auto)
        XCTAssertEqual(Speichersteuerung.stellwahl(stand(art: .hold)), .hold)
        XCTAssertEqual(Speichersteuerung.stellwahl(stand(art: .normal)), .normal)
    }

    // MARK: - Die Untergrenze

    func testFuenfStufenUndIhreWoerter() {
        XCTAssertEqual(Speichersteuerung.untergrenzen, [0, 0.06, 0.1, 0.15, 0.2])
        XCTAssertEqual(
            Speichersteuerung.untergrenzen.map(Speichersteuerung.untergrenzenwort),
            ["aus", "6\(schmal)%", "10\(schmal)%", "15\(schmal)%", "20\(schmal)%"])
    }

    /// Verglichen wird mit einer Schranke: 0,06 ist als Gleitkommazahl nicht 0,06, und ein
    /// Knopf, der nie gedrückt aussieht, sieht aus wie ein kaputter Knopf.
    func testGewaehlteStufeWirdNichtMitGleichheitGesucht() {
        let s = stand(reserve: 0.06)
        XCTAssertTrue(Speichersteuerung.istGewaehlt(s, stufe: 0.06))
        XCTAssertFalse(Speichersteuerung.istGewaehlt(s, stufe: 0.1))
        // Ohne gemeldete Reserve steht „aus“ gedrückt - das ist der Zustand, nicht eine Lücke.
        XCTAssertTrue(Speichersteuerung.istGewaehlt(stand(reserve: nil), stufe: 0))
    }

    func testFristSindZweiStunden() {
        XCTAssertEqual(Speichersteuerung.frist, 120)
        let befehl = Speichersteuerung.befehl(.hold)
        XCTAssertEqual(befehl.mode, .hold)
        XCTAssertEqual(befehl.durationMin, 120)
        XCTAssertNil(befehl.reserveSoc)
        XCTAssertEqual(Speichersteuerung.befehl(.auto, untergrenze: 0.15).reserveSoc, 0.15)
    }

    // MARK: - Der Ladestand im Kartenkopf

    func testLadestandswort() {
        XCTAssertEqual(Speichersteuerung.ladestandswort(stand(soc: 0.54)), "Ladestand 54\(schmal)%")
        XCTAssertEqual(Speichersteuerung.ladestandswort(stand(soc: nil)), "Ladestand unbekannt")
    }

    /// Dieselbe Vorsicht wie in `Batterieblatt`: die Quelle hat beides geliefert, Anteil und
    /// Prozent. Zwei Stellen der App dürfen denselben Messwert nicht verschieden lesen.
    func testEinProzentwertWirdAlsProzentGelesen() {
        XCTAssertEqual(Speichersteuerung.ladestandswort(stand(soc: 54)), "Ladestand 54\(schmal)%")
    }

    // MARK: - Die Notenzeile

    func testGesperrteSteuerungSagtEsUndSonstNichts() {
        let zeile = Speichersteuerung.zeile(stand(frei: false))
        XCTAssertEqual(zeile, Speichersteuerung.gesperrtSatz)
        XCTAssertEqual(Speichersteuerung.zeile(stand(frei: nil)), Speichersteuerung.gesperrtSatz)
        XCTAssertTrue(Speichersteuerung.gesperrt(stand(frei: nil)))
        XCTAssertFalse(Speichersteuerung.gesperrt(stand(frei: true)))
    }

    func testZeileSetztHinweisBefehlUndFehlerZusammen() {
        let s = stand(befehl: .stopped, letzterFehler: "Zeitüberschreitung")
        XCTAssertEqual(
            Speichersteuerung.zeile(s),
            "Untergrenze 10 %. Zuletzt gesendet: angehalten. Fehler: Zeitüberschreitung")
    }

    func testOhneBefehlUndFehlerBleibtNurDerHinweis() {
        XCTAssertEqual(Speichersteuerung.zeile(stand()), "Untergrenze 10 %.")
    }

    func testOhneAlleTeileEineLeereZeile() {
        XCTAssertEqual(Speichersteuerung.zeile(stand(befehl: nil, hinweis: nil)), "")
        XCTAssertEqual(Speichersteuerung.zeile(stand(befehl: nil, hinweis: "")), "")
    }

    /// Der Fehler verdrängt alles andere: er beschreibt, was gerade nicht erreicht wurde.
    func testDerFehlerVerdraengtDenHinweis() {
        XCTAssertEqual(
            Speichersteuerung.zeile(stand(befehl: .normal), fehler: "Umschalten nicht bestätigt."),
            "Umschalten nicht bestätigt.")
        XCTAssertEqual(Speichersteuerung.zeile(stand(), fehler: ""), "Untergrenze 10 %.")
    }

    /// Der Rohwert des Schemas ist kein Satz, den jemand lesen soll.
    func testEinUnbekannterBefehlHeisstNormal() {
        XCTAssertEqual(
            Speichersteuerung.zeile(stand(befehl: .unbekannt, hinweis: nil)),
            "Zuletzt gesendet: normal.")
    }
}
