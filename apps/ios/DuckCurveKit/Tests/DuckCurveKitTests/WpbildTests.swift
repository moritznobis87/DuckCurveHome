import XCTest

@testable import DuckCurveKit

/// Die Maße und die Schlüsse der Wärmepumpen-Zeichnung.
final class WpbildTests: XCTestCase {
    // MARK: - Die Leitungen enden an den Geräten

    /// **Jede Leitung endet an einer Stelle, die es am Gerät gibt.** Das ist die Zusage der
    /// Zeichnung (`bild.ts`), und sie ist nachrechenbar: ein Zahlendreher beim Übernehmen
    /// hinge die Leitung in der Luft, und am Bildschirm sähe man es erst, wenn man hinsieht.
    func testJedeLeitungBeginntUndEndetAnEinemBlock() {
        for lage in [Wpbild.Lage.breit, .hoch] {
            let p = Wpbild.plan(lage)
            let bloecke: [(String, Wpbild.Punkt, (breite: Double, hoehe: Double))] = [
                ("aussen", p.aussen, Wpbild.aussenBlock),
                ("innen", p.innen, Wpbild.innenBlock),
                ("speicher", p.speicher, Wpbild.speicherBlock),
            ]
            func amBlock(_ q: Wpbild.Punkt) -> Bool {
                for (_, ort, groesse) in bloecke {
                    let x0 = ort.x, x1 = ort.x + groesse.breite
                    let y0 = ort.y, y1 = ort.y + groesse.hoehe
                    let drin = q.x >= x0 - 1 && q.x <= x1 + 1 && q.y >= y0 - 1 && q.y <= y1 + 1
                    if drin { return true }
                }
                return false
            }
            for (name, leitung) in [
                ("heissgas", p.heissgas), ("fluessig", p.fluessig),
                ("vorlauf", p.vorlauf), ("vorlaufTiefer", p.vorlaufTiefer),
                ("ruecklauf", p.ruecklauf),
            ] {
                XCTAssertTrue(amBlock(leitung.first!), "\(lage) \(name): Anfang haengt in der Luft")
                XCTAssertTrue(amBlock(leitung.last!), "\(lage) \(name): Ende haengt in der Luft")
            }
        }
    }

    func testAllesLiegtInnerhalbDerZeichenflaeche() {
        for lage in [Wpbild.Lage.breit, .hoch] {
            let p = Wpbild.plan(lage)
            for (name, leitung) in [
                ("heissgas", p.heissgas), ("fluessig", p.fluessig), ("vorlauf", p.vorlauf),
                ("vorlaufTiefer", p.vorlaufTiefer), ("ruecklauf", p.ruecklauf),
            ] {
                for q in leitung {
                    XCTAssertTrue(q.x >= 0 && q.x <= p.sicht.breite, "\(lage) \(name): x \(q.x)")
                    XCTAssertTrue(q.y >= 0 && q.y <= p.sicht.hoehe, "\(lage) \(name): y \(q.y)")
                }
            }
        }
    }

    func testDieLageAendertDieForm() {
        // Quer ist breiter als hoch, hochkant umgekehrt - sonst waere die zweite Lage sinnlos.
        let b = Wpbild.plan(.breit).sicht
        let h = Wpbild.plan(.hoch).sicht
        XCTAssertGreaterThan(b.breite, b.hoehe)
        XCTAssertGreaterThan(h.hoehe, h.breite)
    }

    // MARK: - Was die Zeichnung aus den Daten schliesst

    func testDerZaehlerSchlaegtDenBus() {
        let w = Vorschau.waermepumpe(zaehler: 1.84, bus: 1.92)
        let a = Wpbild.aufnahme(w)
        XCTAssertEqual(a.kw, 1.84)
        XCTAssertEqual(a.quelle, "Zähler")
    }

    func testOhneZaehlerDieMaschine() {
        let a = Wpbild.aufnahme(Vorschau.waermepumpe(zaehler: nil, bus: 1.92))
        XCTAssertEqual(a.kw, 1.92)
        XCTAssertEqual(a.quelle, "laut Maschine")
    }

    func testOhneBeideKeineQuelle() {
        let a = Wpbild.aufnahme(Vorschau.waermepumpe(zaehler: nil, bus: nil))
        XCTAssertNil(a.kw)
        XCTAssertEqual(a.quelle, "")
    }

    func testDerSatzNenntWaermeUndStrom() {
        let s = Wpbild.satz(Vorschau.waermepumpe(zaehler: 1.8, waerme: 6.3))
        XCTAssertTrue(s.contains("6,3 kW Wärme"), s)
        XCTAssertTrue(s.contains("1,8 kW Strom"), s)
    }

    func testEineStehendeMaschineBekommtNurIhrZustandswort() {
        let s = Wpbild.satz(Vorschau.waermepumpe(laeuft: false))
        XCTAssertEqual(s, "Die Wärmepumpe steht.")
    }

    func testOhneWaermeleistungNurDieAufnahme() {
        let s = Wpbild.satz(Vorschau.waermepumpe(zaehler: 1.8, waerme: nil))
        XCTAssertTrue(s.contains("nimmt 1,8 kW auf"), s)
    }

    /// Die Einspeisung ist eine Aufzaehlung. Ohne Auskunft bleibt die Leitung oben - eine
    /// Vermutung waere hier eine Behauptung ueber Hydraulik.
    func testEingespeistWirdNurTieferWennEsDasteht() {
        XCTAssertTrue(Wpbild.speistTiefer(Vorschau.waermepumpe(einspeisung: .tiefer)))
        XCTAssertFalse(Wpbild.speistTiefer(Vorschau.waermepumpe(einspeisung: .oben)))
        XCTAssertFalse(Wpbild.speistTiefer(Vorschau.waermepumpe(einspeisung: nil)))
        XCTAssertFalse(Wpbild.speistTiefer(Vorschau.waermepumpe(einspeisung: .unbekannt)))
    }

    /// **Der Fall aus dem echten Haus.** Am 14.11.2026 um 16:52 stand der Verdichter und der
    /// Luefter drehte. Eine Zeichnung, die ihn dann anhaelt, behauptet eine Messung.
    func testDerLuefterDrehtAuchWennDerVerdichterSteht() {
        XCTAssertTrue(Wpbild.luefterLaeuft(Vorschau.waermepumpe(laeuft: false, luefter: 310)))
        XCTAssertFalse(Wpbild.luefterLaeuft(Vorschau.waermepumpe(laeuft: false, luefter: 0)))
    }

    func testOhneDrehzahlFolgtDerLuefterDemVerdichter() {
        XCTAssertTrue(Wpbild.luefterLaeuft(Vorschau.waermepumpe(laeuft: true, luefter: nil)))
        XCTAssertFalse(Wpbild.luefterLaeuft(Vorschau.waermepumpe(laeuft: false, luefter: nil)))
        XCTAssertEqual(
            Wpbild.luefterwort(Vorschau.waermepumpe(luefter: nil)), "Lüfter · nicht gemessen")
        XCTAssertEqual(
            Wpbild.luefterwort(Vorschau.waermepumpe(luefter: 420)), "Lüfter · Drehzahl 420")
    }
}
