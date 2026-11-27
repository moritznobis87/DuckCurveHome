import XCTest

@testable import DuckCurveKit

/// Dieselben Fälle wie in `apps/web/src/components/home/tageslegende.test.ts`.
final class KurvenlegendeTests: XCTestCase {

    private let punkt = [Kurvenpunkt(stunde: 12, wert: 1)]
    private let band = [Kurvenband(von: 13, bis: 15, art: .guenstig, name: "Preistief")]

    /// Eine Kurve mit dem, was im Bild steht.
    private func kurve(
        schatten: (wort: String, kwh: Double)? = nil, waermepumpe: Bool = false,
        waermeErwartet: Bool = false, preis: Bool = false, preisErwartet: Bool = false,
        baender: Bool = false
    ) -> Tageskurve {
        var k = Tageskurve()
        if let schatten {
            k.schatten = punkt
            k.schattenwort = schatten.wort
            k.schattenKwh = schatten.kwh
        }
        if waermepumpe { k.waermepumpe = punkt }
        if waermeErwartet { k.waermeErwartet = punkt }
        if preis { k.preis = punkt }
        if preisErwartet { k.preisErwartet = punkt }
        if baender { k.baender = band }
        return k
    }

    private func kurz(_ k: Tageskurve, _ tag: Kurventag) -> [String] {
        k.legende(tag).map { "\($0.reihe.rawValue):\($0.form.rawValue):\($0.wort)" }
    }

    func testMorgenVorDreizehnUhrNenntNurWasImBildStehtUndZeichnetEsGestrichelt() {
        // Das Bild des Hausherrn vom 27.11.2026: Sonne erwartet, heute im Hintergrund, die
        // Wärmepumpe von morgen, aber noch kein Preis und kein Preistief.
        let k = kurve(schatten: ("heute", 10.8), waermeErwartet: true)
        XCTAssertEqual(
            kurz(k, .morgen),
            [
                "sonneErwartet:gestrichelt:Sonne erwartet",
                "schatten:linie:heute \(Formate.kwh(10.8))",
                "waermepumpeErwartet:gestrichelt:Wärmepumpe",
            ])
    }

    func testStrompreisUndPreistiefKommenFuerMorgenDazuSobaldSieImBildStehen() {
        let k = kurve(
            schatten: ("heute", 10.8), waermeErwartet: true, preisErwartet: true, baender: true)
        XCTAssertEqual(
            kurz(k, .morgen),
            [
                "sonneErwartet:gestrichelt:Sonne erwartet",
                "schatten:linie:heute \(Formate.kwh(10.8))",
                "waermepumpeErwartet:gestrichelt:Wärmepumpe",
                "strompreis:gestrichelt:Strompreis",
                "preistief:flaeche:Preistief",
            ])
    }

    func testHeuteStehenSonnePrognoseVortagHausUndDerPreisAlsDurchgezogeneLinie() {
        let k = kurve(schatten: ("gestern", 6.9), preis: true, preisErwartet: true, baender: true)
        XCTAssertEqual(
            kurz(k, .heute),
            [
                "sonne:flaeche:Sonne",
                "sonneErwartet:gestrichelt:Prognose",
                "schatten:linie:gestern \(Formate.kwh(6.9))",
                "haus:linie:Haus",
                "strompreis:linie:Strompreis",
                "preistief:flaeche:Preistief",
            ])
    }

    func testDieGemesseneWaermepumpeStehtNurWoSieGezeichnetIstUndNieFuerMorgen() {
        XCTAssertTrue(kurz(kurve(waermepumpe: true), .heute).contains("waermepumpe:linie:Wärmepumpe"))
        XCTAssertEqual(
            kurz(kurve(waermepumpe: true), .morgen), ["sonneErwartet:gestrichelt:Sonne erwartet"])
    }

    func testOhneBandImBildFehltDasPreistief() {
        XCTAssertEqual(
            kurz(kurve(preis: true), .heute),
            [
                "sonne:flaeche:Sonne", "sonneErwartet:gestrichelt:Prognose", "haus:linie:Haus",
                "strompreis:linie:Strompreis",
            ])
    }

    func testDerPreisIstGestricheltSolangeNochKeinerGegoltenHat() {
        XCTAssertTrue(
            kurz(kurve(preisErwartet: true), .heute).contains("strompreis:gestrichelt:Strompreis"))
    }

    func testGesternZeigtKeinePrognose() {
        XCTAssertEqual(
            kurz(kurve(preis: true), .gestern),
            ["sonne:flaeche:Sonne", "haus:linie:Haus", "strompreis:linie:Strompreis"])
    }
}
