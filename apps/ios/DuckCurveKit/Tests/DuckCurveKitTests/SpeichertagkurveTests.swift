import XCTest

@testable import DuckCurveKit

/// Gegen `apps/web/src/components/reports/charts.ts:236-276` (`batteryDayChart`).
///
/// Geprüft wird, was gerechnet wird: der Ladestand in Prozent statt als Anteil, die Mittelung
/// auf das Fünf-Minuten-Raster, die Achse der unteren Fläche, die Trennung der Lücken und die
/// beiden Sätze, die statt des Bildes dastehen.
final class SpeichertagkurveTests: XCTestCase {

    private let tag = "2026-11-10"

    private var beginn: Date { Tag.zeitraum("2026-11-10")!.von }

    /// Ein Punkt zur Minute `minute` des Ankertags.
    private func punkt(_ minute: Int, soc: Double? = nil, kw: Double? = nil) -> Pruefpunkt {
        Pruefpunkt(
            zeit: beginn.addingTimeInterval(Double(minute) * 60), speicher: kw,
            ladestand: soc)
    }

    // MARK: - Bauen

    func testLadestandWirdEinmalInProzentGerechnet() {
        let k = Speichertagkurve.baue(
            tag: tag, raster: (0..<10).map { punkt($0, soc: 0.42) }, schrittMin: 1)
        XCTAssertEqual(k.ladestandProzent.count, 10)
        XCTAssertEqual(k.ladestandProzent.first?.wert ?? 0, 42, accuracy: 0.0001)
    }

    func testDieStundeZaehltAbTagesbeginn() {
        let k = Speichertagkurve.baue(tag: tag, raster: [punkt(90, soc: 0.5)], schrittMin: 1)
        XCTAssertEqual(k.ladestandProzent.first?.stunde ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(k.stunden, 24, accuracy: 0.0001)
        XCTAssertEqual(k.fenster, 0...24)
    }

    func testPunkteAusserhalbDesTagesFallenWeg() {
        let raster = [punkt(-30, soc: 0.5), punkt(10, soc: 0.5), punkt(1500, soc: 0.5)]
        let k = Speichertagkurve.baue(tag: tag, raster: raster, schrittMin: 1)
        XCTAssertEqual(k.ladestandProzent.count, 1)
    }

    /// Gemittelt, nicht jeder n-te Punkt: eine Spitze soll als gemittelte Spitze stehen
    /// bleiben und nicht davon abhängen, auf welche Minute sie fiel.
    func testFuenfMinutenWerdenGemittelt() {
        let raster = (0..<5).map { punkt($0, kw: Double($0)) }
        let k = Speichertagkurve.baue(tag: tag, raster: raster, schrittMin: 5)
        XCTAssertEqual(k.leistungKw.count, 1)
        XCTAssertEqual(k.leistungKw[0].wert, 2, accuracy: 0.0001)
        XCTAssertEqual(k.leistungKw[0].stunde, 0, accuracy: 0.0001)
    }

    func testEinUnbekannterTagGibtEineLeereKurve() {
        let k = Speichertagkurve.baue(tag: "kein Tag", raster: [punkt(0, soc: 0.5)])
        XCTAssertTrue(k.leer)
    }

    func testOhneAntwortEineLeereKurve() {
        XCTAssertTrue(Speichertagkurve.baue(tag: tag, historie: nil).leer)
    }

    func testAusDerAntwortDesDienstes() {
        let zeile: [String: Mischwert] = [
            "ts": .text("2026-11-10T06:30:00+01:00"),
            "battery_soc": .zahl(0.64),
            "battery_power_kw": .zahl(-1.2),
        ]
        let k = Speichertagkurve.baue(
            tag: tag,
            historie: HistoryOut(
                start: "2026-11-10T00:00:00+01:00", end: "2026-11-11T00:00:00+01:00",
                rows: [zeile]),
            schrittMin: 1)
        XCTAssertEqual(k.ladestandProzent.first?.wert ?? 0, 64, accuracy: 0.0001)
        XCTAssertEqual(k.leistungKw.first?.wert ?? 0, -1.2, accuracy: 0.0001)
        XCTAssertEqual(k.ladestandProzent.first?.stunde ?? 0, 6.5, accuracy: 0.0001)
    }

    // MARK: - Die Achse der unteren Fläche

    /// Enger als die der Prüfkurve: die untere Fläche ist 60 Punkte hoch, und −2 bis 4 kW
    /// drückte einen ruhigen Tag darin zu einer geraden Linie.
    func testDieAchseIstEngerAlsDieDerPruefkurve() {
        let still = Speichertagkurve.spanne([Kurvenpunkt(stunde: 1, wert: 0.3)])
        XCTAssertEqual(still, -1...1)
        XCTAssertTrue(still.upperBound < Pruefkurve.mindestspanne.upperBound)
    }

    func testDieNullLiegtImmerInDerAchse() {
        let nurLaden = Speichertagkurve.spanne([
            Kurvenpunkt(stunde: 1, wert: -3.0), Kurvenpunkt(stunde: 2, wert: -4.0),
        ])
        XCTAssertTrue(nurLaden.contains(0))
        XCTAssertEqual(nurLaden.upperBound, 1)
        XCTAssertLessThanOrEqual(nurLaden.lowerBound, -4.4)
    }

    func testDieAchseLaesstLuftNachOben() {
        let s = Speichertagkurve.spanne([Kurvenpunkt(stunde: 1, wert: 5.0)])
        XCTAssertGreaterThanOrEqual(s.upperBound, 5.5)
    }

    func testOhneWerteDieMindestspanne() {
        XCTAssertEqual(Speichertagkurve.spanne([]), Speichertagkurve.mindestspanne)
    }

    // MARK: - Lücken

    /// Ein Speicher, der zwanzig Minuten nicht meldet, hat in dieser Zeit nicht null Kilowatt
    /// geliefert - die Strecken trennen, wo nichts gemessen wurde.
    func testEineLueckeTrenntDieLeistungsreihe() {
        var raster = (0..<6).map { punkt($0 * 5, kw: 1.0) }
        raster += (0..<6).map { punkt(120 + $0 * 5, kw: 1.0) }
        let k = Speichertagkurve.baue(tag: tag, raster: raster, schrittMin: 5)
        XCTAssertEqual(k.leistungsstrecken.count, 2)
    }

    func testOhneLueckeEineEinzigeStrecke() {
        let raster = (0..<12).map { punkt($0 * 5, kw: 1.0) }
        let k = Speichertagkurve.baue(tag: tag, raster: raster, schrittMin: 5)
        XCTAssertEqual(k.leistungsstrecken.count, 1)
    }

    // MARK: - Die Wörter der Karte

    func testKopfzeileUndLeersatzUnterscheidenAnsichtUndLuecke() {
        XCTAssertEqual(
            Speichertagkurve.kopfzeile(tagesansicht: true),
            "oben der Ladezustand, unten die Leistung: + Entladen, \(Formate.minus) Laden")
        XCTAssertEqual(Speichertagkurve.kopfzeile(tagesansicht: false), "nur in der Tagesansicht")
        XCTAssertTrue(Speichertagkurve.leersatz(tagesansicht: true).contains("Historienimport"))
        XCTAssertTrue(
            Speichertagkurve.leersatz(tagesansicht: false).contains("je Tag gezeigt"))
    }
}
