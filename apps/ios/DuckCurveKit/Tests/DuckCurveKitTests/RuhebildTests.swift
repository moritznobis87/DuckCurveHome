import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/home/ambiente.ts` und ihre Tests
/// (`ambiente.test.ts`) - dieselben Fälle, dieselben Zahlen.
final class RuhebildTests: XCTestCase {

    /// Mitternacht des 23. Oktober 2026 in der Hauszeit.
    private let tag: Date = {
        var teile = DateComponents()
        teile.year = 2026
        teile.month = 10
        teile.day = 23
        return Kalender.haus.date(from: teile)!
    }()

    private func uhr(_ stunde: Double) -> Date {
        tag.addingTimeInterval(stunde * 3600)
    }

    /// Ein Fahrplan mit einem Dreieck Sonne von 9 bis 17 Uhr im Viertelstundenraster.
    private func planMitSonne() -> PlanOut {
        plan { h in h >= 9 && h <= 17 ? max(0, 4 - abs(h - 13) * 0.8) : 0 }
    }

    private func nachts() -> PlanOut {
        plan { _ in 0 }
    }

    private func plan(_ kw: (Double) -> Double) -> PlanOut {
        let intervalle = (0..<96).map { i -> PlanIntervalOut in
            let stunde = Double(i) / 4
            return PlanIntervalOut(
                ts: Zeit.iso(uhr(stunde)), expectedPvKw: kw(stunde), priceCtKwh: 20,
                plannedHpState: .free, reasonCode: "none")
        }
        return PlanOut(
            createdAt: Zeit.iso(tag), planner: "test", horizonStart: Zeit.iso(tag),
            horizonEnd: Zeit.iso(tag.addingTimeInterval(24 * 3600)), windows: [],
            intervals: intervalle, pvForecastTodayKwh: 0)
    }

    private func stunde(_ d: Date) -> Int {
        Kalender.haus.component(.hour, from: d)
    }

    // MARK: - Sonnenlauf

    func testSonnenlaufFindetBeginnUndEndeDerErzeugung() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))
        XCTAssertNotNil(lauf)
        XCTAssertEqual(stunde(lauf!.von), 9)
        // Die letzte Viertelstunde mit Erzeugung endet um 17 Uhr.
        XCTAssertEqual(stunde(lauf!.bis), 17)
    }

    func testSonnenlaufNimmtDieDunklenPunkteAmRandMit() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))!
        // Eine halbe Stunde Luft an beiden Enden, damit der Bogen nicht am Rand klebt. Die
        // letzte helle Viertelstunde beginnt um 17:00 und endet um 17:15; von 8:30 bis 17:45
        // sind das 37 Viertelstunden, also 38 Punkte.
        XCTAssertEqual(stunde(lauf.punkte.first!.zeit), 8)
        XCTAssertEqual(lauf.punkte.first!.kw, 0)
        XCTAssertEqual(stunde(lauf.punkte.last!.zeit), 17)
        XCTAssertEqual(lauf.punkte.count, 38)
    }

    func testSonnenlaufIstNilOhneErzeugungUndOhnePlan() {
        XCTAssertNil(Ruhebild.sonnenlauf(nachts(), jetzt: uhr(12)))
        XCTAssertNil(Ruhebild.sonnenlauf(nil, jetzt: uhr(12)))
    }

    // MARK: - Welches Bild

    func testBildZeigtAmTagDieSonne() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))
        XCTAssertEqual(Ruhebild.bild(lauf, jetzt: uhr(12), pvKw: 2.4), .tag)
        // Eine Wolke um 13 Uhr ist kein Abend.
        XCTAssertEqual(Ruhebild.bild(lauf, jetzt: uhr(13), pvKw: 0), .tag)
    }

    func testBildZeigtAbendsDenPreisUndDenPuffer() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))
        XCTAssertEqual(Ruhebild.bild(lauf, jetzt: uhr(21), pvKw: 0), .abend)
        XCTAssertEqual(Ruhebild.bild(lauf, jetzt: uhr(6), pvKw: 0), .abend)
    }

    func testBildBleibtBeimTagWennDieAnlageLiefert() {
        XCTAssertEqual(Ruhebild.bild(nil, jetzt: uhr(12), pvKw: 1.8), .tag)
        XCTAssertEqual(Ruhebild.bild(nil, jetzt: uhr(12), pvKw: 0.1), .abend)
        XCTAssertEqual(Ruhebild.bild(nil, jetzt: uhr(12), pvKw: nil), .abend)
    }

    func testBildZaehltBeideGrenzenZumTag() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))!
        XCTAssertEqual(Ruhebild.bild(lauf, jetzt: lauf.von, pvKw: 0), .tag)
        XCTAssertEqual(Ruhebild.bild(lauf, jetzt: lauf.bis, pvKw: 0), .tag)
        XCTAssertEqual(Ruhebild.bild(lauf, jetzt: lauf.bis.addingTimeInterval(1), pvKw: 0), .abend)
    }

    // MARK: - Aussicht

    func testAussichtRechnetDenGanzenTagUndDenRestAbJetzt() {
        let p = planMitSonne()
        let lauf = Ruhebild.sonnenlauf(p, jetzt: uhr(12))
        let ganz = Ruhebild.aussicht(p, jetzt: uhr(12), lauf: lauf)
        let spaet = Ruhebild.aussicht(p, jetzt: uhr(16), lauf: lauf)
        XCTAssertGreaterThan(ganz.erwartetKwh ?? 0, 19)
        // Was der Tag bringt, ändert sich im Tagesverlauf nicht - nur der Rest schrumpft.
        XCTAssertEqual(spaet.erwartetKwh ?? 0, ganz.erwartetKwh ?? 0, accuracy: 1e-9)
        XCTAssertLessThan(spaet.restKwh ?? 0, ganz.restKwh ?? 0)
        XCTAssertEqual(stunde(ganz.bis!), 17)
    }

    func testAussichtOhnePlanIstLeerUndKeineNull() {
        let a = Ruhebild.aussicht(nil, jetzt: uhr(12), lauf: nil)
        XCTAssertNil(a.erwartetKwh)
        XCTAssertNil(a.restKwh)
        XCTAssertNil(a.bis)
    }

    // MARK: - Bogen

    func testBogenZeichnetDieLinieUeberDieGanzeBreite() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))
        let b = Ruhebild.bogen(lauf, jetzt: uhr(12), breite: 300, hoehe: 60)!
        XCTAssertEqual(b.linie.first!.x, 0, accuracy: 1e-9)
        XCTAssertEqual(b.linie.last!.x, 300, accuracy: 1e-9)
        // Null Kilowatt liegen auf der Grundlinie, die Spitze vier Punkte unter dem Rand.
        XCTAssertEqual(b.linie.first!.y, 60, accuracy: 1e-9)
        XCTAssertEqual(b.linie.map(\.y).min()!, Ruhebild.bogenLuftOben, accuracy: 1e-9)
    }

    func testBogenFuelltBisZurMarkeJetzt() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))
        let b = Ruhebild.bogen(lauf, jetzt: uhr(12), breite: 300, hoehe: 60)!
        XCTAssertGreaterThan(b.jetztX!, 0)
        XCTAssertLessThan(b.jetztX!, 300)
        // Der letzte Punkt der gefüllten Linie sitzt genau auf der Marke, nicht bis zu einer
        // Viertelstunde davor.
        XCTAssertEqual(b.bisJetzt.last!.x, b.jetztX!, accuracy: 1e-9)
        XCTAssertLessThan(b.bisJetzt.count, b.linie.count)
    }

    func testBogenInterpoliertDenPunktAufJetzt() {
        // 12:07:30 liegt genau zwischen 12:00 und 12:15. Der eingeschobene Punkt muss dort
        // liegen, wo die Kurve zwischen beiden Viertelstunden steht - sonst endet die Fläche
        // bis zu einer Viertelstunde vor der Marke.
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))!
        let jetzt = uhr(12).addingTimeInterval(7.5 * 60)
        let b = Ruhebild.bogen(lauf, jetzt: jetzt, breite: 300, hoehe: 60)!
        let letzter = b.bisJetzt.last!

        // Erwartet: die Stelle von 12:07:30 im Fenster der Punkte und die halbe Höhe zwischen
        // den Werten um 12:00 (3,2 kW) und 12:15 (3,4 kW), von Hand gerechnet.
        let von = lauf.punkte.first!.zeit
        let bis = lauf.punkte.last!.zeit
        let x = jetzt.timeIntervalSince(von) / bis.timeIntervalSince(von) * 300
        let spitze = lauf.punkte.map(\.kw).max()!
        let kw = (3.2 + 3.4) / 2
        let y = 60 - (kw / spitze) * (60 - Ruhebild.bogenLuftOben)
        XCTAssertEqual(letzter.x, x, accuracy: 1e-9)
        XCTAssertEqual(letzter.y, y, accuracy: 1e-9)
        XCTAssertEqual(b.jetztX!, x, accuracy: 1e-9)

        // Und der Punkt steht wirklich zwischen seinen beiden Nachbarn, nicht auf einem davon.
        let davor = b.bisJetzt[b.bisJetzt.count - 2]
        XCTAssertGreaterThan(letzter.x, davor.x)
        XCTAssertLessThan(letzter.y, davor.y)  // vor der Spitze steigt die Kurve
    }

    func testBogenFlaecheEndetAnDerMarkeUndNichtDavor() {
        // Die Vorlage prüft dasselbe an der Zeichenkette der Fläche (`ambiente.test.ts:72`);
        // hier endet die gefüllte Linie an der Marke, und die Ansicht zieht sie von dort auf
        // die Grundlinie zurück.
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))
        let b = Ruhebild.bogen(lauf, jetzt: uhr(12).addingTimeInterval(7.5 * 60), breite: 300,
                               hoehe: 60)!
        XCTAssertEqual(b.bisJetzt.last!.x, b.jetztX!, accuracy: 1e-9)
        XCTAssertLessThan(b.bisJetzt.last!.y, 60)
    }

    func testBogenHatVorSonnenaufgangKeineMarkeUndKeineFlaeche() {
        let lauf = Ruhebild.sonnenlauf(planMitSonne(), jetzt: uhr(12))
        let b = Ruhebild.bogen(lauf, jetzt: uhr(5), breite: 300, hoehe: 60)!
        XCTAssertNil(b.jetztX)
        XCTAssertTrue(b.bisJetzt.isEmpty)
        XCTAssertFalse(b.linie.isEmpty)
    }

    func testBogenBleibtAusOhneSonnenlauf() {
        XCTAssertNil(Ruhebild.bogen(nil, jetzt: uhr(12)))
    }

    func testBogenBlaehtEinenTrubenTagNichtAuf() {
        // Höchstens 0,1 kW den ganzen Tag: die Spitze bleibt bei 0,5 kW, die Kurve flach unten.
        let trueb = plan { h in h >= 9 && h <= 17 ? 0.1 : 0 }
        let lauf = Ruhebild.sonnenlauf(trueb, jetzt: uhr(12))!
        let b = Ruhebild.bogen(lauf, jetzt: uhr(12), breite: 300, hoehe: 60)!
        let hoechste = b.linie.map(\.y).min()!
        XCTAssertEqual(hoechste, 60 - (0.1 / 0.5) * 56, accuracy: 1e-9)
    }

    // MARK: - Der schwerste Befund

    func testSchwersterBefundNimmtDenErstenDerWache() {
        let alarm = WatchFindingOut(
            name: "pv", titleDe: "Keine PV-Daten", severity: .alarm, silentMin: 42,
            textDe: "Der Wechselrichter schweigt seit 42 Minuten.")
        let warnung = WatchFindingOut(
            name: "preis", titleDe: "Preise fehlen", severity: .warn, silentMin: 5,
            textDe: "Die Börse hat noch keine Preise geliefert.")
        XCTAssertEqual(Ruhebild.schwersterBefund([alarm, warnung])?.name, "pv")
        XCTAssertNil(Ruhebild.schwersterBefund([]))
        XCTAssertNil(Ruhebild.schwersterBefund(nil))
    }
}
