import XCTest

@testable import DuckCurveKit

/// Das Minutenraster, das die Anzeige selbst fortschreibt.
///
/// Vorlage: `apps/web/src/lib/live/store.test.ts`. Die Faelle hier sind dieselben und einige
/// mehr - vor allem die, die `store.ts` im Kommentar nennt, ohne sie zu pruefen: der verspaetete
/// Rahmen und der unlesbare Zeitstempel.
final class VerlaufTests: XCTestCase {
    /// Ein Augenblicksbild bauen - die Bausteine kommen aus `Vorschau`, damit hier nicht in
    /// jedem Test sechzehn Messwerte stehen.
    private func zustand(
        zeit: String, pv: Double?, haus: Double?, wp: Double? = nil, preis: Double? = nil, k1: Double? = nil
    ) -> LiveStateOut {
        var z = Vorschau.liveZustand()
        var s = z.snapshot
        s.timestamp = zeit
        s.pvPowerKw = Vorschau.messwert(pv)
        s.housePowerKw = Vorschau.messwert(haus)
        s.heatPumpPowerKw = Vorschau.messwert(wp)
        s.evPowerKw = Vorschau.messwert(nil)
        s.gridPowerKw = Vorschau.messwert(nil)
        s.batteryPowerKw = Vorschau.messwert(nil)
        s.electricityPriceCtKwh = Vorschau.messwert(preis)
        s.hpReleaseContact = Vorschau.messwert(k1)
        z.snapshot = s
        return z
    }

    // MARK: - Aus der Historie lesen

    func testLiestEineZeileDerHistorie() {
        let zeile: [String: Mischwert] = [
            "ts": .text("2026-11-16T12:00:00Z"),
            "pv_power_kw": .zahl(3.6),
            "house_power_kw": .zahl(1.2),
            "hp_release_contact": .ganz(1),
            "grid_power_kw": .nichts,
        ]
        let p = Minutenraster.punktAusZeile(zeile)
        XCTAssertEqual(p?.pv, 3.6)
        XCTAssertEqual(p?.haus, 1.2)
        // Eine Ganzzahl ist auch eine Zahl: K1 kommt als 0 oder 1.
        XCTAssertEqual(p?.k1, 1.0)
        // `null` ist kein Wert, nicht die Zahl null.
        XCTAssertNil(p?.netz)
        XCTAssertNil(p?.wallbox)
    }

    /// Eine Zeile ohne lesbaren Zeitstempel darf nicht auf den 1. Januar 1970 fallen - dort zoege
    /// sie die Zeitachse des ganzen Diagramms zu sich.
    func testZeileOhneZeitstempelWirdVerworfen() {
        XCTAssertNil(Minutenraster.punktAusZeile(["pv_power_kw": .zahl(1)]))
        XCTAssertNil(Minutenraster.punktAusZeile(["ts": .nichts, "pv_power_kw": .zahl(1)]))
        XCTAssertNil(Minutenraster.punktAusZeile(["ts": .text("Invalid Date")]))
        XCTAssertNil(Minutenraster.punktAusZeile(["ts": .zahl(1_763_000_000)]))
    }

    func testSetzeVerwirftWasVorherDaWar() {
        var r = Minutenraster()
        r.setze([["ts": .text("2026-11-16T12:00:00Z"), "pv_power_kw": .zahl(1)]], tag: "2026-11-16")
        XCTAssertEqual(r.punkte.count, 1)
        r.setze([], tag: "2026-11-15")
        XCTAssertTrue(r.punkte.isEmpty)
        XCTAssertEqual(r.tag, "2026-11-15")
    }

    // MARK: - Fortschreiben

    func testEineNeueMinuteWirdAngehaengt() {
        var r = Minutenraster()
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:10Z", pv: 3.0, haus: 1.0))
        r.schreibeFort(zustand(zeit: "2026-11-16T12:01:10Z", pv: 4.0, haus: 2.0))
        XCTAssertEqual(r.punkte.count, 2)
        XCTAssertEqual(r.punkte[0].pv, 3.0)
        XCTAssertEqual(r.punkte[1].pv, 4.0)
    }

    /// Alles, was in dieselbe Minute faellt, wird zu einem Punkt gemittelt.
    func testMehrereBilderInEinerMinuteWerdenGemittelt() {
        var r = Minutenraster()
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:05Z", pv: 3.0, haus: 1.0))
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:25Z", pv: 5.0, haus: 2.0))
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:45Z", pv: 7.0, haus: 3.0))
        XCTAssertEqual(r.punkte.count, 1)
        XCTAssertEqual(r.punkte[0].pv!, 5.0, accuracy: 1e-9)
        XCTAssertEqual(r.punkte[0].haus!, 2.0, accuracy: 1e-9)
        XCTAssertEqual(r.punkte[0].zeit, Zeit.ausIso("2026-11-16T12:00:00Z"))
    }

    /// Der Preis gilt fuer die ganze Stunde und ein Kontakt ist an oder aus: beide werden nicht
    /// gemittelt, sondern uebernommen. Ein halb offener Kontakt waere eine Aussage, die es nicht gibt.
    func testPreisUndKontaktWerdenNichtGemittelt() {
        var r = Minutenraster()
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:05Z", pv: 1, haus: 1, preis: 20, k1: 0))
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:35Z", pv: 1, haus: 1, preis: 30, k1: 1))
        XCTAssertEqual(r.punkte.count, 1)
        XCTAssertEqual(r.punkte[0].preis, 30)
        XCTAssertEqual(r.punkte[0].k1, 1)
    }

    /// Ein Wert, der fehlt, darf das Mittel nicht verderben - und ein Mittel aus nichts und
    /// etwas ist das Etwas.
    func testFehlendeWerteVerderbenDasMittelNicht() {
        var r = Minutenraster()
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:05Z", pv: nil, haus: 2.0))
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:35Z", pv: 4.0, haus: nil))
        XCTAssertEqual(r.punkte[0].pv, 4.0)
        XCTAssertEqual(r.punkte[0].haus, 2.0)
    }

    /// **Der Fall, den `store.ts` nennt und nicht prueft.** Ein Rahmen, der zu spaet kommt,
    /// gehoert nicht an das Ende der Reihe: die Zeitachse muss aufsteigend bleiben, sonst laeuft
    /// die Kurve im Diagramm zurueck.
    func testVerspaeteterRahmenWirdVerworfen() {
        var r = Minutenraster()
        r.schreibeFort(zustand(zeit: "2026-11-16T12:05:00Z", pv: 5.0, haus: 1.0))
        r.schreibeFort(zustand(zeit: "2026-11-16T12:02:00Z", pv: 2.0, haus: 1.0))
        XCTAssertEqual(r.punkte.count, 1)
        XCTAssertEqual(r.punkte[0].pv, 5.0)
        // Und die Reihe ist immer noch aufsteigend.
        XCTAssertEqual(r.punkte.map(\.zeit), r.punkte.map(\.zeit).sorted())
    }

    func testEinUnlesbarerZeitstempelAendertNichts() {
        var r = Minutenraster()
        r.schreibeFort(zustand(zeit: "2026-11-16T12:00:00Z", pv: 1, haus: 1))
        r.schreibeFort(zustand(zeit: "heute", pv: 9, haus: 9))
        XCTAssertEqual(r.punkte.count, 1)
        XCTAssertEqual(r.punkte[0].pv, 1)
    }

    /// Das Raster waechst nicht ueber alle Grenzen. An einer Wandanzeige, die Wochen laeuft,
    /// waere das der Grund, warum sie langsam wird.
    func testDasRasterWaechstNichtUeberAlleGrenzen() {
        var r = Minutenraster()
        let anfang = Zeit.ausIso("2026-11-16T00:00:00Z")!
        for i in 0..<(Minutenraster.hoechstzahl + 200) {
            let t = Zeit.iso(anfang.addingTimeInterval(Double(i) * 60))
            r.schreibeFort(zustand(zeit: t, pv: Double(i), haus: 1))
        }
        XCTAssertEqual(r.punkte.count, Minutenraster.hoechstzahl)
        // Die aeltesten sind weg, die neuesten da.
        XCTAssertEqual(r.punkte.last?.pv, Double(Minutenraster.hoechstzahl + 199))
        XCTAssertEqual(r.punkte.first?.pv, 200)
    }

    func testMinutenanfang() {
        let d = Zeit.ausIso("2026-11-16T12:34:56Z")!
        XCTAssertEqual(Minutenraster.minutenanfang(d), Zeit.ausIso("2026-11-16T12:34:00Z"))
        let genau = Zeit.ausIso("2026-11-16T12:34:00Z")!
        XCTAssertEqual(Minutenraster.minutenanfang(genau), genau)
    }

    /// Vor 1970 gibt es keine Messwerte, aber die Rechnung muss auch dort stimmen: bei negativen
    /// Sekunden rundet eine ganzzahlige Division zur Null hin und damit in die falsche Richtung.
    func testMinutenanfangVor1970() {
        let d = Date(timeIntervalSince1970: -30)
        XCTAssertEqual(Minutenraster.minutenanfang(d), Date(timeIntervalSince1970: -60))
    }

    // MARK: - Auswerten

    func testHoechsteLeistungNimmtDenBetrag() {
        var r = Minutenraster()
        r.setze(
            [
                ["ts": .text("2026-11-16T12:00:00Z"), "pv_power_kw": .zahl(3.0), "grid_power_kw": .zahl(-7.5)],
                ["ts": .text("2026-11-16T12:01:00Z"), "pv_power_kw": .zahl(4.0)],
            ], tag: "2026-11-16")
        // Einspeisung ist negativ und muss die Achse trotzdem aufziehen.
        XCTAssertEqual(r.hoechsteLeistung, 7.5)
    }

    func testPreisspanne() {
        var r = Minutenraster()
        r.setze(
            [
                ["ts": .text("2026-11-16T12:00:00Z"), "electricity_price_ct_kwh": .zahl(28.4)],
                ["ts": .text("2026-11-16T12:01:00Z"), "electricity_price_ct_kwh": .zahl(-1.2)],
                ["ts": .text("2026-11-16T12:02:00Z")],
            ], tag: "2026-11-16")
        let s = r.preisspanne
        XCTAssertEqual(s?.tiefster, -1.2)
        XCTAssertEqual(s?.hoechster, 28.4)
    }

    func testPreisspanneOhnePreise() {
        var r = Minutenraster()
        r.setze([["ts": .text("2026-11-16T12:00:00Z")]], tag: "2026-11-16")
        XCTAssertNil(r.preisspanne)
    }

    func testPunkteImZeitraum() {
        var r = Minutenraster()
        r.setze(
            (0..<10).map { i in
                ["ts": .text(Zeit.iso(Zeit.ausIso("2026-11-16T12:00:00Z")!.addingTimeInterval(Double(i) * 60)))]
            }, tag: "2026-11-16")
        let von = Zeit.ausIso("2026-11-16T12:03:00Z")!
        let bis = Zeit.ausIso("2026-11-16T12:06:00Z")!
        XCTAssertEqual(r.punkte(von: von, bis: bis).count, 3)
    }
}
