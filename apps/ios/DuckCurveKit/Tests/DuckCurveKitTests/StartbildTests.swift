import XCTest

@testable import DuckCurveKit

/// Die Rechnung der neuen Startseite. Dieselben Werte prüft das Dashboard in
/// `startbild.test.ts`: wer hier eine Zahl ändert, ändert sie dort.
final class StartbildTests: XCTestCase {

    // MARK: - Die zwei Bilder

    func testZweiBilderDieBuehneZuerst() {
        XCTAssertEqual(Startbild.allCases.map(\.rawValue), ["buehne", "uhr"])
        XCTAssertEqual(Startbild.allCases.map(\.name), ["Die Bühne", "Die Uhr"])
        XCTAssertEqual(Startbild.merker, "dch-startbild")
        XCTAssertEqual(Startbild.titel, "Startseite")
        XCTAssertEqual(Startbild.frage, "Welches Bild die Mitte der Startseite auf diesem Gerät trägt.")
        XCTAssertEqual(
            Startbild.buehne.satz,
            "Das Haus steht unter seinem Himmel, und der Strom fließt als leuchtendes Band.")
        XCTAssertEqual(
            Startbild.uhr.satz,
            "Ein Ring über 24 Stunden zeigt den Strompreis, die erwartete Sonne und die Läufe der Wärmepumpe."
        )
    }

    func testUnbekanntesIstDieBuehne() {
        XCTAssertEqual(Startbild.aus("uhr"), .uhr)
        XCTAssertEqual(Startbild.aus("buehne"), .buehne)
        XCTAssertEqual(Startbild.aus(nil), .buehne)
        XCTAssertEqual(Startbild.aus("kacheln"), .buehne)
    }

    // MARK: - Die Bühne

    func testEinBandWirdNachDerLeistungBreitUndIstGedeckelt() {
        XCTAssertEqual(Startbuehne.bandbreite(0), 5)
        XCTAssertEqual(Startbuehne.bandbreite(1.3), 10.85, accuracy: 1e-6)
        XCTAssertEqual(Startbuehne.bandbreite(4.6), 25.7, accuracy: 1e-6)
        XCTAssertEqual(Startbuehne.bandbreite(9), 30)
        XCTAssertEqual(Startbuehne.bandbreite(-2), 5)
    }

    func testDieSonneStehtNurZwischenAufgangUndUntergangAufDemBogen() {
        let von = Date(timeIntervalSince1970: 1000)
        let bis = Date(timeIntervalSince1970: 5000)
        func anteil(_ s: TimeInterval) -> Double? {
            Startbuehne.sonnenanteil(von: von, bis: bis, jetzt: Date(timeIntervalSince1970: s))
        }
        XCTAssertEqual(anteil(1000), 0)
        XCTAssertEqual(anteil(3000), 0.5)
        XCTAssertEqual(anteil(5000), 1)
        XCTAssertNil(anteil(999))
        XCTAssertNil(anteil(5001))
        XCTAssertNil(Startbuehne.sonnenanteil(von: nil, bis: nil, jetzt: Date(timeIntervalSince1970: 3000)))
    }

    func testDieMasseDerWand() {
        let m = Startbuehne.mass(breite: 816, hoehe: 400)
        XCTAssertFalse(m.schmal)
        XCTAssertEqual(m.boden, 340)
        XCTAssertEqual(m.mitte, 408)
        XCTAssertEqual(m.hausHalb, 85.68, accuracy: 1e-6)
        XCTAssertEqual(m.rx, 372)
        XCTAssertEqual(m.ry, 300)
        XCTAssertEqual(m.netzX, 81.6, accuracy: 1e-6)
        XCTAssertEqual(m.wallboxX, 232.56, accuracy: 1e-6)
        XCTAssertEqual(m.speicherX, 583.44, accuracy: 1e-6)
        XCTAssertEqual(m.pumpeX, 726.24, accuracy: 1e-6)
        XCTAssertEqual(m.tief, 370)
        XCTAssertEqual(m.schildY, 244)
    }

    func testDieMasseDesTelefons() {
        let m = Startbuehne.mass(breite: 358, hoehe: 322)
        XCTAssertTrue(m.schmal)
        XCTAssertEqual(m.boden, 268)
        XCTAssertEqual(m.hausHalb, 60)
        XCTAssertEqual(m.rx, 157)
        XCTAssertEqual(m.ry, 204)
        XCTAssertEqual(m.netzX, 40)
        XCTAssertEqual(m.speicherX, 316)
        XCTAssertEqual(m.tief, 294)
    }

    func testDieSonneSitztAufDemBogen() {
        let m = Startbuehne.mass(breite: 816, hoehe: 400)
        XCTAssertEqual(Startbuehne.sonnenort(m, anteil: 0), Startbuehne.Ort(x: 36, y: 340))
        let mittag = Startbuehne.sonnenort(m, anteil: 0.5)
        XCTAssertEqual(mittag.x, 408, accuracy: 1e-6)
        XCTAssertEqual(mittag.y, 40, accuracy: 1e-6)
        let spaet = Startbuehne.sonnenort(m, anteil: 0.75)
        XCTAssertEqual(spaet.x, 671.0437, accuracy: 1e-3)
        XCTAssertEqual(spaet.y, 127.868, accuracy: 1e-3)
    }

    // MARK: - Der Stundenring

    private func um(_ stunde: Int, _ minute: Int) -> Date {
        Kalender.haus.date(
            from: DateComponents(year: 2026, month: 11, day: 25, hour: stunde, minute: minute))!
    }

    private func zelle(_ zeit: Date, _ preis: Double?, _ pv: Double, wp: Bool = false) -> Ausblick.Zelle {
        Ausblick.Zelle(zeit: zeit, preis: preis, pv: pv, wp: wp, ofen: false)
    }

    func testViertelstundenWerdenZuStunden() {
        let zellen = [
            zelle(um(18, 30), 50, 0),
            zelle(um(18, 45), 54, 0),
            zelle(um(19, 0), 40, 0.2, wp: true),
            zelle(um(19, 15), 44, 0.4),
            zelle(um(19, 30), nil, 0.6),
            zelle(um(19, 45), nil, 0.8),
            zelle(um(20, 0), nil, 1),
        ]
        let fenster = Ausblick.Fenster(von: um(19, 30), bis: um(21, 30), mittel: 20)
        let st = Stundenring.stunden24(zellen, guenstig: fenster)
        XCTAssertEqual(st.map(\.stunde), [18, 19, 20])
        XCTAssertEqual(st.map(\.preis), [52, 42, nil])
        XCTAssertEqual(st[1].sonneKw, 0.5, accuracy: 1e-6)
        XCTAssertEqual(st.map(\.wp), [false, true, false])
        XCTAssertEqual(st.map(\.tief), [false, true, true])
    }

    func testNach24StundenIstSchluss() {
        let zellen = (0..<96).map { zelle(um(18, 30).addingTimeInterval(Double($0) * 900), 30, 0) }
        let st = Stundenring.stunden24(zellen, guenstig: nil)
        XCTAssertEqual(st.count, 24)
        XCTAssertEqual(st.first?.stunde, 18)
        XCTAssertEqual(st.last?.stunde, 17)
    }

    func testNullUhrStehtObenUndEsGehtImUhrzeigersinn() {
        XCTAssertEqual(Stundenring.winkel(stunde: 0), -Double.pi / 2, accuracy: 1e-9)
        XCTAssertEqual(Stundenring.winkel(stunde: 6), 0, accuracy: 1e-9)
        XCTAssertEqual(Stundenring.winkel(stunde: 12), Double.pi / 2, accuracy: 1e-9)
        XCTAssertEqual(Stundenring.winkel(stunde: 18), Double.pi, accuracy: 1e-9)
    }

    func testEinPreisWirdAmHoechstenDesTagesGemessenMindestensAnVierzigCent() {
        XCTAssertEqual(Stundenring.preislaenge(53, hoechster: 53), 1)
        XCTAssertEqual(Stundenring.preislaenge(26.5, hoechster: 53), 0.5)
        XCTAssertEqual(Stundenring.preislaenge(20, hoechster: 30), 0.5)
        XCTAssertEqual(Stundenring.preislaenge(20, hoechster: nil), 0.5)
        XCTAssertEqual(Stundenring.preislaenge(-5, hoechster: 53), 0)
    }

    func testDieMasseDesRings() {
        XCTAssertEqual(
            Stundenring.mass(breite: 816, hoehe: 400),
            Stundenring.Mass(mitteX: 408, mitteY: 189, radius: 152, preis: 118, sonne: 106, pumpe: 94, zahl: 78))
        XCTAssertEqual(
            Stundenring.mass(breite: 358, hoehe: 380),
            Stundenring.Mass(mitteX: 179, mitteY: 179, radius: 149, preis: 115, sonne: 103, pumpe: 91, zahl: 75))
    }
}
