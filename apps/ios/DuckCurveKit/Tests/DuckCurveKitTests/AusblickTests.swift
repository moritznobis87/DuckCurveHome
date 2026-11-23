import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/home/ausblick.ts`.
final class AusblickTests: XCTestCase {

    private let jetzt = Zeit.ausIso("2026-02-24T14:35:00+01:00")!

    /// Ein Plan aus Viertelstunden ab `ab`. `preis`, `pv`, `wp` und `ofen` je Zelle.
    private func plan(
        ab: Date, anzahl: Int, preis: (Int) -> Double? = { _ in 20 },
        pv: (Int) -> Double = { _ in 0 }, wp: (Int) -> Bool = { _ in false },
        ofen: (Int) -> Bool = { _ in false }, grund: (Int) -> String = { _ in "planned_optimizer" }
    ) -> PlanOut {
        let iv = (0..<anzahl).map { i in
            PlanIntervalOut(
                ts: Zeit.iso(ab.addingTimeInterval(Double(i) * 900)), expectedPvKw: pv(i),
                priceCtKwh: preis(i), plannedHpState: wp(i) ? .release : .off,
                plannedStoveOn: ofen(i), reasonCode: grund(i))
        }
        return bau(iv, ab: ab)
    }

    private func bau(_ iv: [PlanIntervalOut], ab: Date) -> PlanOut {
        PlanOut(
            createdAt: Zeit.iso(ab), planner: "test", horizonStart: Zeit.iso(ab),
            horizonEnd: Zeit.iso(ab.addingTimeInterval(24 * 3600)), windows: [], intervals: iv,
            pvForecastTodayKwh: 0)
    }

    private var viertelVor: Date {
        // 14:30 - die laufende Viertelstunde um 14:35.
        Zeit.ausIso("2026-02-24T14:30:00+01:00")!
    }

    // MARK: - Das Raster

    func testDieLaufendeViertelstundeGehoertDazu() {
        let a = Ausblick.baue(plan(ab: viertelVor, anzahl: 96), jetzt: jetzt)
        XCTAssertEqual(a.zellen.count, 96)
        XCTAssertEqual(a.zellen.first?.zeit, viertelVor, "In ihr steht der Preis von jetzt.")
    }

    func testWasVorbeiIstFaelltWegUndEsBleibenHoechstens96Zellen() {
        let a = Ausblick.baue(
            plan(ab: viertelVor.addingTimeInterval(-6 * 3600), anzahl: 200), jetzt: jetzt)
        XCTAssertEqual(a.zellen.count, 96)
        XCTAssertEqual(a.zellen.first?.zeit, viertelVor)
        XCTAssertEqual(
            a.zellen.last?.zeit, viertelVor.addingTimeInterval(95 * 900))
    }

    func testUnterAchtZellenIstEsKeinAusblick() {
        XCTAssertFalse(Ausblick.baue(plan(ab: viertelVor, anzahl: 7), jetzt: jetzt).tragfaehig)
        XCTAssertTrue(Ausblick.baue(plan(ab: viertelVor, anzahl: 8), jetzt: jetzt).tragfaehig)
        XCTAssertFalse(Ausblick.baue(nil, jetzt: jetzt).tragfaehig)
    }

    func testNurGeplanteLaeufeZaehlenUndNichtDiePreisregel() {
        let a = Ausblick.baue(
            plan(
                ab: viertelVor, anzahl: 16, wp: { _ in true },
                grund: { $0 < 8 ? "planned_optimizer" : "price_rule" }), jetzt: jetzt)
        XCTAssertEqual(a.zellen.filter(\.wp).count, 8)
        XCTAssertEqual(a.laeufe, [0..<8])
    }

    func testOhneFahrplanWirdKeinLaufBehauptet() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 32, grund: { _ in "price_rule" }), jetzt: jetzt)
        XCTAssertFalse(a.hatFahrplan)
        XCTAssertTrue(a.saetze(jetzt: jetzt).isEmpty)
    }

    // MARK: - Die Preislage

    func testDiePreislageWirdAmTagGemessenUndNichtAnEinerFestenGrenze() {
        // Preise 10 bis 40 ct, jetzt die billigste Zelle: guenstig.
        let billig = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 32, preis: { 10 + Double($0) }), jetzt: jetzt)
        XCTAssertEqual(billig.lage, .guenstig)
        XCTAssertEqual(billig.lage?.satz, "Strom ist gerade günstig")

        // Dieselbe Spanne, jetzt die teuerste Zelle.
        let teuer = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 32, preis: { 41 - Double($0) }), jetzt: jetzt)
        XCTAssertEqual(teuer.lage, .teuer)

        let mitte = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 33, preis: { $0 == 0 ? 25 : (10 + Double($0)) }),
            jetzt: jetzt)
        XCTAssertEqual(mitte.lage, .mittel)
    }

    func testEineFlacheSpanneHeisstGleichmaessigUndNichtGuenstig() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 32, preis: { 20 + Double($0 % 3) * 0.5 }), jetzt: jetzt)
        XCTAssertEqual(a.lage, .gleichmaessig)
        XCTAssertNil(a.guenstig, "Unter 4 ct Spanne lohnt kein Verschieben.")
    }

    func testOhneGenugPreiseGibtEsKeineLage() {
        let a = Ausblick.baue(plan(ab: viertelVor, anzahl: 7, preis: { 10 + Double($0) }), jetzt: jetzt)
        XCTAssertNil(a.lage)
    }

    func testRangIstDerAnteilDerBilligerenMomente() {
        XCTAssertEqual(Ausblick.rang(10, [10, 20, 30]), 0, accuracy: 1e-9)
        XCTAssertEqual(Ausblick.rang(20, [10, 20, 30]), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Ausblick.rang(30, [10, 20, 30]), 1, accuracy: 1e-9)
        XCTAssertEqual(Ausblick.rang(5, [7]), 0.5, accuracy: 1e-9, "Ein einziger Preis hat keinen Rang.")
    }

    // MARK: - Die Fenster

    func testDasGuenstigsteFensterSindZweiStundenAmStueck() {
        // Ein Tal von Zelle 20 bis 28.
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 48, preis: { (20..<28).contains($0) ? 5 : 30 }),
            jetzt: jetzt)
        let g = a.guenstig!
        XCTAssertEqual(g.von, viertelVor.addingTimeInterval(20 * 900))
        XCTAssertEqual(g.bis, viertelVor.addingTimeInterval(28 * 900), "Acht Zellen = zwei Stunden.")
        XCTAssertEqual(g.mittel, 5, accuracy: 1e-9)
    }

    func testEinFensterSpringtNichtUeberEineLueckeImFahrplan() {
        // Zellen 0..3 billig, dann eine Luecke von zwei Stunden, dann billig.
        var iv = (0..<4).map { i in
            PlanIntervalOut(
                ts: Zeit.iso(viertelVor.addingTimeInterval(Double(i) * 900)), expectedPvKw: 0,
                priceCtKwh: 2, plannedHpState: .off, reasonCode: "planned_optimizer")
        }
        iv += (12..<24).map { i in
            PlanIntervalOut(
                ts: Zeit.iso(viertelVor.addingTimeInterval(Double(i) * 900)), expectedPvKw: 0,
                priceCtKwh: 30, plannedHpState: .off, reasonCode: "planned_optimizer")
        }
        let p = bau(iv, ab: viertelVor)
        let a = Ausblick.baue(p, jetzt: jetzt)
        XCTAssertEqual(a.guenstig?.mittel ?? 0, 30, accuracy: 1e-9)
        XCTAssertEqual(
            a.guenstig?.von, viertelVor.addingTimeInterval(12 * 900),
            "Die billigen vier Zellen allein sind kein Fenster.")
    }

    func testEinTrueberTagHatKeinSonnenfenster() {
        let a = Ausblick.baue(plan(ab: viertelVor, anzahl: 48, pv: { _ in 0.3 }), jetzt: jetzt)
        XCTAssertNil(a.sonne, "Unter 1 kW im Mittel wird keine Sonnenzeit genannt.")
        XCTAssertEqual(a.pvMax, 0.3, accuracy: 1e-9)
    }

    func testDasSonnenfensterIstDieZeitDerHoechstenErwartung() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 48, pv: { (10..<18).contains($0) ? 4.5 : 0.2 }),
            jetzt: jetzt)
        XCTAssertEqual(a.sonne?.von, viertelVor.addingTimeInterval(10 * 900))
        XCTAssertEqual(a.sonne?.mittel ?? 0, 4.5, accuracy: 1e-9)
        XCTAssertEqual(a.pvMax, 4.5, accuracy: 1e-9)
    }

    func testNachtUndWannDieSonneWiederkommt() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 48, pv: { $0 < 20 ? 0 : 2.0 }), jetzt: jetzt)
        XCTAssertTrue(a.nacht)
        XCTAssertEqual(a.sonneWechsel, viertelVor.addingTimeInterval(20 * 900))

        let tag = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 48, pv: { $0 < 20 ? 2.0 : 0 }), jetzt: jetzt)
        XCTAssertFalse(tag.nacht)
        XCTAssertEqual(tag.sonneWechsel, viertelVor.addingTimeInterval(20 * 900), "Wann sie geht.")
    }

    // MARK: - Bis wohin Preise bekannt sind

    func testOhnePreiseFuerMorgenStehtBisWohinSieReichen() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 96, preis: { $0 < 40 ? 20 : nil }), jetzt: jetzt)
        XCTAssertEqual(a.preiseBis, viertelVor.addingTimeInterval(40 * 900))
        XCTAssertNotNil(a.preissatz(jetzt: jetzt))
    }

    func testReichenDiePreiseDurchStehtKeinHinweis() {
        let a = Ausblick.baue(plan(ab: viertelVor, anzahl: 96), jetzt: jetzt)
        XCTAssertNil(a.preiseBis)
        XCTAssertNil(a.preissatz(jetzt: jetzt))
    }

    // MARK: - Die Sätze

    func testEinLaufDerSchonBegonnenHatSagtNurWannErEndet() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 48, wp: { $0 < 6 }), jetzt: jetzt)
        let s = a.saetze(jetzt: jetzt).first { $0.marke == .waermepumpe }!
        XCTAssertEqual(s.text, "Die Wärmepumpe soll bis 16:00 laufen.")
    }

    func testEinSpaetererLaufStehtMitVonUndBis() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 48, wp: { (8..<16).contains($0) }), jetzt: jetzt)
        let s = a.saetze(jetzt: jetzt).first { $0.marke == .waermepumpe }!
        XCTAssertEqual(s.text, "Die Wärmepumpe soll von 16:30 bis 18:30 laufen.")
    }

    func testOhneGeplantenLaufStehtGenauDas() {
        let a = Ausblick.baue(plan(ab: viertelVor, anzahl: 48), jetzt: jetzt)
        let s = a.saetze(jetzt: jetzt).first { $0.marke == .waermepumpe }!
        XCTAssertEqual(
            s.text, "Die Wärmepumpe hat in den nächsten 24 Stunden keinen geplanten Lauf.")
    }

    func testEineZeitAmNaechstenTagBekommtDasWortMorgen() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 96, wp: { (44..<52).contains($0) }), jetzt: jetzt)
        let s = a.saetze(jetzt: jetzt).first { $0.marke == .waermepumpe }!
        XCTAssertEqual(s.text, "Die Wärmepumpe soll von morgen 01:30 bis 03:30 laufen.")
    }

    func testDerOfenUndDieBeidenZeitenStehenMitIhrenMarken() {
        let a = Ausblick.baue(
            plan(
                ab: viertelVor, anzahl: 48, preis: { (20..<28).contains($0) ? 5 : 30 },
                pv: { (10..<18).contains($0) ? 4.5 : 0.2 }, wp: { (8..<16).contains($0) },
                ofen: { (30..<34).contains($0) }), jetzt: jetzt)
        let s = a.saetze(jetzt: jetzt)
        XCTAssertEqual(s.map(\.marke), [.waermepumpe, .ofen, .guenstig, .sonne])
        XCTAssertEqual(s[1].text, "Der Pelletofen soll von 22:00 bis 23:00 brennen.")
        XCTAssertEqual(
            s[2].text, "Am günstigsten ist Netzstrom von 19:30 bis 21:30, im Mittel 5 ct.")
        XCTAssertEqual(s[3].text, "Die meiste Sonne gibt es von 17:00 bis 19:00.")
        XCTAssertNotNil(a.verschiebesatz)
    }

    func testOhneZeitenKeinVerschiebesatz() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 48, preis: { _ in 20 }, pv: { _ in 0 }), jetzt: jetzt)
        XCTAssertNil(a.verschiebesatz)
    }

    func testDieStelleAufDerSpurLiegtZwischenNullUndEins() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 32, preis: { $0 == 0 ? 25 : (10 + Double($0)) }),
            jetzt: jetzt)
        let stelle = a.stelle!
        XCTAssertGreaterThan(stelle, 0)
        XCTAssertLessThan(stelle, 1)
        XCTAssertEqual(stelle, (25 - 11) / (41 - 11), accuracy: 1e-9)
    }

    func testOhneSpanneGibtEsKeineStelle() {
        let a = Ausblick.baue(plan(ab: viertelVor, anzahl: 32, preis: { _ in 20 }), jetzt: jetzt)
        XCTAssertNil(a.stelle)
    }

    // MARK: - Die Zeitachse

    func testDieAchseMarkiertJedeSechsteVolleStundeDerHausuhr() {
        let a = Ausblick.baue(plan(ab: viertelVor, anzahl: 96), jetzt: jetzt)
        // Ab 14:30 sind in 24 Stunden 18:00, 0:00, 6:00 und 12:00 erreicht.
        XCTAssertEqual(a.achsenmarken.map(\.text), ["18 Uhr", "0 Uhr", "6 Uhr", "12 Uhr"])
        XCTAssertEqual(a.achsenmarken.first?.zelle, 14, "18:00 ist 3,5 Stunden nach 14:30.")
        XCTAssertEqual(a.achsenmarken.first?.anteil ?? 0, 14.0 / 96, accuracy: 1e-9)
    }

    func testDieErstenSechsZellenBleibenFreiDamitNichtsAufJetztLiegt() {
        // 17:45 - die naechste volle sechste Stunde ist 18:00, also Zelle 1.
        let spaet = Zeit.ausIso("2026-02-24T17:45:00+01:00")!
        let a = Ausblick.baue(plan(ab: spaet, anzahl: 96), jetzt: spaet)
        XCTAssertFalse(a.achsenmarken.contains { $0.zelle < 6 })
        XCTAssertEqual(a.achsenmarken.first?.text, "0 Uhr")
    }

    // MARK: - Abschnitte

    func testAbschnitteFindenZusammenhaengendeLaeufeBisZumEnde() {
        let a = Ausblick.baue(
            plan(ab: viertelVor, anzahl: 16, wp: { $0 < 2 || $0 >= 14 }), jetzt: jetzt)
        XCTAssertEqual(a.laeufe, [0..<2, 14..<16])
    }
}
