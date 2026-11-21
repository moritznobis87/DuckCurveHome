import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/waerme/Fahrplan.tsx`.
final class FahrplanbildTests: XCTestCase {

    private let ab = Zeit.ausIso("2026-11-17T00:00:00+01:00")!

    private func plan(
        anzahl: Int = 96,
        preis: (Int) -> Double? = { _ in 20 },
        pv: (Int) -> Double = { _ in 0 },
        pvIst: (Int) -> Double? = { _ in nil },
        hpIst: (Int) -> Double? = { _ in nil },
        anforderung: (Int) -> Bool? = { _ in nil },
        laufMin: (Int) -> Double? = { _ in nil },
        heizen: (Int) -> Double? = { _ in nil },
        warmwasser: (Int) -> Double? = { _ in nil },
        puffer: (Int) -> Double? = { _ in nil },
        cop: (Int) -> Double? = { _ in nil },
        zustand: (Int) -> PlanIntervalOutPlannedHpStateWahl = { _ in .off },
        ofen: (Int) -> Bool? = { _ in nil },
        fenster: [PriceWindowOut] = [],
        decke: Double? = nil, reserve: Double? = nil, schaltet: Bool? = nil
    ) -> PlanOut {
        let iv = (0..<anzahl).map { i in
            PlanIntervalOut(
                ts: Zeit.iso(ab.addingTimeInterval(Double(i) * 900)), expectedPvKw: pv(i),
                priceCtKwh: preis(i), plannedHpState: zustand(i), plannedStoveOn: ofen(i),
                reasonCode: "planned_optimizer", heatDemandKw: heizen(i),
                dhwDemandKw: warmwasser(i), bufferKwh: puffer(i), cop: cop(i),
                actualPvKw: pvIst(i), actualHpKw: hpIst(i), actualHpRelease: anforderung(i),
                actualHpRunMin: laufMin(i))
        }
        return PlanOut(
            createdAt: Zeit.iso(ab), planner: "greedy_v1", hpActuation: schaltet,
            horizonStart: Zeit.iso(ab),
            horizonEnd: Zeit.iso(ab.addingTimeInterval(48 * 3600)), windows: fenster,
            intervals: iv, pvForecastTodayKwh: 12.4, bufferCapacityKwh: decke,
            bufferMinKwh: reserve)
    }

    // MARK: - Lücken bleiben Lücken

    func testEineViertelstundeOhneMessungIstEineLueckeUndNichtNullKilowatt() {
        let b = Fahrplanbild.baue(plan(anzahl: 8, pvIst: { $0 < 4 ? 2.5 : nil }))
        XCTAssertEqual(b.pvGemessen.count, 8)
        XCTAssertEqual(b.pvGemessen.prefix(4).compactMap(\.wert), [2.5, 2.5, 2.5, 2.5])
        XCTAssertTrue(b.pvGemessen.suffix(4).allSatisfy { $0.wert == nil })
        XCTAssertTrue(b.hatMessung)
    }

    func testOhneJedeMessungSagtDasBildDas() {
        let b = Fahrplanbild.baue(plan(anzahl: 8))
        XCTAssertFalse(b.hatMessung)
        XCTAssertFalse(b.hatWpMessung)
        XCTAssertFalse(b.hatAnforderung)
        XCTAssertFalse(b.hatWaerme)
        XCTAssertFalse(b.hatPuffer)
        XCTAssertFalse(b.hatOfenfahrplan)
    }

    func testEineFehlendeAnforderungHinterlaesstEineLueckeImStreifen() {
        let b = Fahrplanbild.baue(
            plan(anzahl: 8, anforderung: { $0 < 3 ? ($0 == 0) : nil }))
        XCTAssertEqual(b.anforderung.count, 3, "„nicht angefordert“ und „nicht gemessen“ sind zwei Aussagen.")
        XCTAssertEqual(b.anforderung.map(\.rolle), [.angefordert, .aus, .aus])
        XCTAssertEqual(b.anforderung.map(\.hoehe), [1, 0.12, 0.12])
    }

    func testWarmwasserKommtImBedarfVor() {
        let b = Fahrplanbild.baue(
            plan(anzahl: 4, heizen: { _ in 2.0 }, warmwasser: { $0 == 2 ? 1.5 : 0 }))
        XCTAssertEqual(b.heizen.compactMap(\.wert), [2, 2, 2, 2])
        XCTAssertEqual(b.warmwasser.compactMap(\.wert), [0, 0, 1.5, 0])
        XCTAssertTrue(b.hatWaerme)
    }

    func testDieSummeDerWaermeIstEinePunktreiheUndKeineRechnungInDerAnsicht() {
        let b = Fahrplanbild.baue(
            plan(
                anzahl: 4, heizen: { $0 < 3 ? 2.0 : nil },
                warmwasser: { $0 == 1 ? 1.5 : ($0 == 2 ? nil : 0) }))
        XCTAssertEqual(b.waermeSumme.map(\.wert), [2.0, 3.5, 2.0, nil])
    }

    // MARK: - Der geplante Zustand

    func testDerZustandTraegtFarbeHoeheUndWort() {
        XCTAssertEqual(Fahrplanbild.zustand(.release).wort, "angefordert")
        XCTAssertEqual(Fahrplanbild.zustand(.release).hoehe, 1)
        XCTAssertEqual(Fahrplanbild.zustand(.avoid).wort, "gemieden")
        XCTAssertEqual(Fahrplanbild.zustand(.avoid).hoehe, 0.55)
        XCTAssertEqual(Fahrplanbild.zustand(.free).wort, "frei")
        XCTAssertEqual(Fahrplanbild.zustand(.free).hoehe, 0.3)
        XCTAssertEqual(Fahrplanbild.zustand(.off).wort, "aus")
        XCTAssertEqual(Fahrplanbild.zustand(.off).hoehe, 0.12)
        XCTAssertEqual(
            Fahrplanbild.zustand(.unbekannt).wort, "aus", "Ein unbekannter Wert ist kein Lauf.")
        XCTAssertEqual(Fahrplanbild.zustandslegende.count, 4)
    }

    func testVierZustaendeSindVierVerschiedeneHoehen() {
        let hoehen = Fahrplanbild.zustandslegende.map(\.hoehe)
        XCTAssertEqual(Set(hoehen).count, 4, "Sonst sehen gemieden, frei und aus gleich aus.")
    }

    func testDerStreifenHatEinFeldJeViertelstunde() {
        let b = Fahrplanbild.baue(
            plan(anzahl: 4, zustand: { [.release, .avoid, .free, .off][$0] }))
        XCTAssertEqual(
            b.zustandsstreifen.map(\.rolle), [.angefordert, .gemieden, .frei, .aus])
    }

    func testDerOfenstreifenZaehltNurViertelstundenMitFahrplan() {
        let b = Fahrplanbild.baue(plan(anzahl: 6, ofen: { $0 < 4 ? ($0 < 2) : nil }))
        XCTAssertEqual(b.ofenstreifen.count, 4)
        XCTAssertEqual(b.ofenstreifen.map(\.rolle), [.ofenAn, .ofenAn, .ofenAus, .ofenAus])
        XCTAssertTrue(b.hatOfenfahrplan)
    }

    // MARK: - Die Achsen

    func testDiePreisachseBeginntNichtBeiNullSondernEineStufeDarunter() {
        let b = Fahrplanbild.baue(plan(anzahl: 8, preis: { 22 + Double($0) }))
        XCTAssertEqual(b.preisUnten, 20, "22 abgerundet auf 5-ct-Stufen.")
    }

    func testEineReiheOhneSchwankungBekommtTrotzdemEineAchse() {
        XCTAssertEqual(Fahrplanbild.untergrenze([30, 30, 30], stufe: 5), 25)
        XCTAssertEqual(Fahrplanbild.untergrenze([2.0, 2.0], stufe: 0.5), 1.5)
    }

    func testOhneWerteGibtEsKeineUntergrenze() {
        XCTAssertNil(Fahrplanbild.untergrenze([], stufe: 5))
        XCTAssertNil(Fahrplanbild.untergrenze([30], stufe: 0))
    }

    func testNegativePreiseDrueckenDieAchseUnterNull() {
        XCTAssertEqual(Fahrplanbild.untergrenze([-2.5, 18], stufe: 5), -5)
    }

    func testDieWaermeachseRechnetMitDerSummeAusHeizenUndWarmwasser() {
        let b = Fahrplanbild.baue(
            plan(anzahl: 8, heizen: { _ in 1.8 }, warmwasser: { _ in 0.4 }))
        XCTAssertEqual(b.waermeUnten, 2.0, "1,8 + 0,4 = 2,2, abgerundet auf halbe kW.")
    }

    func testDerHorizontIstDerDesPlanersUndNichtDerDerIntervalle() {
        let b = Fahrplanbild.baue(plan(anzahl: 8))
        XCTAssertEqual(b.horizont?.lowerBound, ab)
        XCTAssertEqual(
            b.horizont?.upperBound, ab.addingTimeInterval(48 * 3600),
            "Zwei Tage, auch wenn nur zwei Stunden Intervalle vorliegen.")
    }

    func testDieSpanneEinerGestauchtenFlaecheGehtBisZumGroesstenWert() {
        let s = Fahrplanbild.spanne(20, bis: [22, 48, nil, 31])!
        XCTAssertEqual(s.lowerBound, 20)
        XCTAssertEqual(s.upperBound, 48)
        XCTAssertNil(Fahrplanbild.spanne(20, bis: [nil, nil]))
    }

    func testEineFlacheSpanneWirdNichtLeer() {
        let s = Fahrplanbild.spanne(5, bis: [5, 5])!
        XCTAssertLessThan(s.lowerBound, s.upperBound)
    }

    // MARK: - Die Preisfenster

    func testNurBilligUndNegativWerdenHinterlegt() {
        let f = [
            PriceWindowOut(
                start: Zeit.iso(ab), end: Zeit.iso(ab.addingTimeInterval(3600)), kind: .cheap,
                labelDe: "Preistief"),
            PriceWindowOut(
                start: Zeit.iso(ab.addingTimeInterval(7200)),
                end: Zeit.iso(ab.addingTimeInterval(10800)), kind: .expensive, labelDe: "teuer"),
            PriceWindowOut(
                start: Zeit.iso(ab.addingTimeInterval(14400)),
                end: Zeit.iso(ab.addingTimeInterval(18000)), kind: .negative,
                labelDe: "negativer Preis"),
        ]
        let b = Fahrplanbild.baue(plan(anzahl: 8, fenster: f))
        XCTAssertEqual(b.baender.count, 2, "Teuer ist der Normalfall und braucht keine Farbe.")
        XCTAssertEqual(b.baender.map(\.negativ), [false, true])
        XCTAssertTrue(b.hatNegativesFenster)
    }

    // MARK: - Der Puffer

    func testDeckeUndReserveKommenAusDemPlan() {
        let b = Fahrplanbild.baue(plan(anzahl: 8, puffer: { _ in 6.2 }, decke: 12, reserve: 3))
        XCTAssertEqual(b.pufferDecke, 12)
        XCTAssertEqual(b.pufferReserve, 3)
        XCTAssertTrue(b.hatPuffer)
    }

    // MARK: - Die Auskunft zu einer Viertelstunde

    func testDieAuskunftNenntAlleswasZurViertelstundeImPlanSteht() {
        let p = plan(
            anzahl: 8, preis: { _ in 24.9 }, pv: { _ in 2.0 }, pvIst: { _ in 2.4 },
            hpIst: { _ in 1.75 }, anforderung: { _ in true }, heizen: { _ in 2.1 },
            warmwasser: { _ in 0.4 }, puffer: { _ in 6.2 }, cop: { _ in 3.21 },
            zustand: { _ in .release }, ofen: { _ in false })
        let a = Fahrplanbild.auskunft(p, zeit: ab, jetzt: ab)!
        XCTAssertEqual(a.titel, "heute 00:00")
        let paare = a.zeilen.map { "\($0.wort)=\($0.wert)" }
        // „18,4 ct“ ohne Nenner, wie die Vorlage (`Fahrplan.tsx:328`).
        XCTAssertTrue(paare.contains("Strompreis=\(Formate.ctKurz(24.9))"), "\(paare)")
        XCTAssertFalse(paare.contains { $0.contains("ct/kWh") }, "\(paare)")
        XCTAssertTrue(paare.contains("PV erwartet=\(Formate.kwMitEinheit(2.0))"))
        XCTAssertTrue(paare.contains("PV gemessen=\(Formate.kwMitEinheit(2.4))"))
        XCTAssertTrue(paare.contains("=\(Formate.kwMitEinheit(0.4)) mehr als erwartet"))
        XCTAssertTrue(paare.contains("Wärmebedarf=\(Formate.kwMitEinheit(2.5))"))
        XCTAssertTrue(paare.contains("Heizen=\(Formate.kwMitEinheit(2.1))"))
        XCTAssertTrue(paare.contains("Warmwasser=\(Formate.kwMitEinheit(0.4))"))
        XCTAssertEqual(
            a.zeilen.filter(\.eingerueckt).map(\.rolle), [.neutral, .heizen, .warmwasser],
            "Jede Zahl traegt ihre eigene Farbe.")
        XCTAssertTrue(paare.contains("Puffer danach=\(Formate.kwh(6.2))"))
        XCTAssertTrue(paare.contains("Wärmepumpe geplant=angefordert"))
        XCTAssertTrue(paare.contains("Anforderung gemessen=ja"))
        XCTAssertTrue(paare.contains("Wärmepumpe gemessen=1,75 kW"))
        XCTAssertTrue(paare.contains("Pelletofen=aus"))
    }

    func testDieAussentemperaturUndDieArbeitszahlStehenZusammenInEinerZeile() {
        let p = plan(anzahl: 4, cop: { _ in 3.21 })
        // outdoor_temp_c steht nur, wenn es da ist: ohne Fuehler keine Zeile.
        XCTAssertFalse(
            Fahrplanbild.auskunft(p, zeit: ab, jetzt: ab)!.zeilen.contains { $0.wort == "Außen" })
    }

    func testEinePrognoseWieErwartetSagtGenauDas() {
        let p = plan(anzahl: 4, pv: { _ in 2.0 }, pvIst: { _ in 2.02 })
        let a = Fahrplanbild.auskunft(p, zeit: ab, jetzt: ab)!
        XCTAssertTrue(a.zeilen.contains { $0.eingerueckt && $0.wert == "wie erwartet" })
    }

    func testWenigerAlsErwartetStehtAlsWortUndNichtAlsVorzeichen() {
        let p = plan(anzahl: 4, pv: { _ in 2.0 }, pvIst: { _ in 1.2 })
        let a = Fahrplanbild.auskunft(p, zeit: ab, jetzt: ab)!
        XCTAssertTrue(
            a.zeilen.contains { $0.wert == "\(Formate.kwMitEinheit(0.8)) weniger als erwartet" },
            "\(a.zeilen.map(\.wert))")
    }

    func testDieAuskunftTrifftDieViertelstundeInDieDerZeigerFaellt() {
        let p = plan(anzahl: 8, preis: { 20 + Double($0) })
        // 00:20 liegt in der Viertelstunde, die 00:15 beginnt.
        let a = Fahrplanbild.auskunft(p, zeit: ab.addingTimeInterval(20 * 60), jetzt: ab)!
        XCTAssertEqual(a.zeit, ab.addingTimeInterval(900))
        XCTAssertEqual(a.titel, "heute 00:15")
    }

    func testVorDemErstenIntervallGibtEsKeineAuskunft() {
        let p = plan(anzahl: 8)
        XCTAssertNil(Fahrplanbild.auskunft(p, zeit: ab.addingTimeInterval(-7200), jetzt: ab))
    }

    func testDerSatzDesPlanersGehoertZurAuskunft() {
        var p = plan(anzahl: 4)
        p.intervals[1].noteDe = "teuer, darum gemieden"
        let a = Fahrplanbild.auskunft(p, zeit: ab.addingTimeInterval(900), jetzt: ab)!
        XCTAssertEqual(a.satz, "teuer, darum gemieden")
        XCTAssertNil(Fahrplanbild.auskunft(p, zeit: ab, jetzt: ab)!.satz)
    }

    func testOhneOfenfahrplanSagtDieAuskunftKeinFahrplan() {
        let a = Fahrplanbild.auskunft(plan(anzahl: 4), zeit: ab, jetzt: ab)!
        XCTAssertTrue(a.zeilen.contains { $0.wort == "Pelletofen" && $0.wert == "kein Fahrplan" })
    }

    // MARK: - Die sieben Kacheln

    func testAngefordertStehtInStundenUndNichtAlsZahlDerLaeufe() {
        let k = Fahrplankacheln.kacheln(
            plan(anzahl: 96, zustand: { (8..<32).contains($0) ? .release : .off }))
        let a = k.first { $0.wort == "Wärmepumpe angefordert" }!
        XCTAssertEqual(a.wert, "6,0 h", "24 Viertelstunden sind sechs Stunden.")
        XCTAssertEqual(a.dazu, "im ganzen Horizont · wird nur beobachtet, nicht geschaltet")
    }

    func testWirdGeschaltetStehtInDerKachel() {
        let k = Fahrplankacheln.kacheln(plan(anzahl: 8, schaltet: true))
        XCTAssertEqual(
            k.first { $0.wort == "Wärmepumpe angefordert" }?.dazu,
            "im ganzen Horizont · Duck Curve fordert selbst an")
    }

    func testGelaufenZaehltMinutenUndVergleichtMitDemselbenFenster() {
        // Vier Viertelstunden mit Messung, davon drei voll gelaufen; geplant waren zwei davon.
        let k = Fahrplankacheln.kacheln(
            plan(
                anzahl: 96, laufMin: { $0 < 4 ? [15.0, 15, 15, 0][$0] : nil },
                zustand: { $0 < 2 ? .release : .off }))
        let g = k.first { $0.wort == "Wärmepumpe gelaufen" }!
        XCTAssertEqual(g.wert, "0,8 h", "45 Minuten.")
        XCTAssertEqual(g.dazu, "seit Mitternacht · im selben Fenster geplant 0,5 h")
    }

    func testOhneMessungStehtKeineMessung() {
        let k = Fahrplankacheln.kacheln(plan(anzahl: 8))
        let g = k.first { $0.wort == "Wärmepumpe gelaufen" }!
        XCTAssertEqual(g.wert, Formate.leer)
        XCTAssertEqual(g.dazu, "keine Messung")
    }

    func testNullOfenstundenSindEineEntscheidungUndKeinFehlenderFahrplan() {
        let mit = Fahrplankacheln.kacheln(plan(anzahl: 8, ofen: { _ in false }))
            .first { $0.wort == "Ofen geplant" }!
        XCTAssertEqual(mit.wert, "0,0 h")
        XCTAssertEqual(mit.dazu, "nicht eingeplant, Begründung unten")

        let ohne = Fahrplankacheln.kacheln(plan(anzahl: 8)).first { $0.wort == "Ofen geplant" }!
        XCTAssertEqual(ohne.wert, Formate.leer)
        XCTAssertEqual(ohne.dazu, "kein Fahrplan für den Ofen")

        let brennt = Fahrplankacheln.kacheln(plan(anzahl: 8, ofen: { $0 < 4 }))
            .first { $0.wort == "Ofen geplant" }!
        XCTAssertEqual(brennt.wert, "1,0 h")
        XCTAssertEqual(brennt.dazu, "Volllast, 15 kg je Füllung")
        // `tone={kennzahlen.ofenViertel ? "ember" : "muted"}` (`Fahrplan.tsx:559-562`), und
        // `ember` ist `var(--alert)` (`Stat.tsx:5`). Vorher stand hier `glut`, der Ton der
        // Wärmepumpe - siehe ``Kennzahl/Ton/alarm``.
        XCTAssertEqual(brennt.ton, .alarm)
        XCTAssertEqual(mit.ton, .gedaempft, "Kein Ofenlauf ist kein Alarm.")
    }

    /// **„Wärmepumpe angefordert“ trägt den Alarmton** (`Fahrplan.tsx:551-554`:
    /// `tone="ember"`), und zwar unabhängig davon, ob Duck Curve selbst schaltet.
    func testAngefordertTraegtDenAlarmton() {
        XCTAssertEqual(
            Fahrplankacheln.kacheln(plan(anzahl: 8))
                .first { $0.wort == "Wärmepumpe angefordert" }?.ton, .alarm)
        XCTAssertEqual(
            Fahrplankacheln.kacheln(plan(anzahl: 8, schaltet: true))
                .first { $0.wort == "Wärmepumpe angefordert" }?.ton, .alarm)
    }

    func testDerGeplanteWaermebedarfIstArbeitUndNichtLeistung() {
        let k = Fahrplankacheln.kacheln(
            plan(anzahl: 96, heizen: { _ in 2.0 }, warmwasser: { _ in 0.5 }))
        let w = k.first { $0.wort == "Wärmebedarf geplant" }!
        XCTAssertEqual(w.wert, "60", "96 Viertelstunden mal 2,5 kW, geteilt durch vier.")
        XCTAssertEqual(w.einheit, "kWh")
        XCTAssertEqual(w.dazu, "Modell v1, nicht gemessen")
    }

    func testOhneBedarfSagtDieKachelKeinFahrplan() {
        let w = Fahrplankacheln.kacheln(plan(anzahl: 8))
            .first { $0.wort == "Wärmebedarf geplant" }!
        XCTAssertEqual(w.wert, Formate.leer)
        XCTAssertEqual(w.dazu, "kein Fahrplan")
    }

    func testCopUndPreisStehenAlsSpanne() {
        let k = Fahrplankacheln.kacheln(
            plan(anzahl: 8, preis: { 18 + Double($0) * 4 }, cop: { 2.4 + Double($0) * 0.2 }))
        XCTAssertEqual(k.first { $0.wort == "COP im Horizont" }?.wert, "2,4 bis 3,8")
        XCTAssertEqual(k.first { $0.wort == "Preisspanne" }?.wert, "18 bis 46")
    }

    func testOhneWerteStehenStriche() {
        let k = Fahrplankacheln.kacheln(plan(anzahl: 8, preis: { _ in nil }))
        XCTAssertEqual(k.first { $0.wort == "COP im Horizont" }?.wert, Formate.leer)
        XCTAssertEqual(k.first { $0.wort == "Preisspanne" }?.wert, Formate.leer)
        XCTAssertEqual(k.count, 7, "Immer sieben, damit die Zeile nicht springt.")
    }

    func testOhnePlanStehenSiebenStriche() {
        let k = Fahrplankacheln.kacheln(nil)
        XCTAssertEqual(k.count, 7)
        XCTAssertEqual(k.first { $0.wort == "Wärmepumpe angefordert" }?.wert, "0,0 h")
    }

    func testViertelstundenRechnenKaufmaennisch() {
        XCTAssertEqual(Fahrplankacheln.viertelstunden(0), "0,0 h")
        XCTAssertEqual(Fahrplankacheln.viertelstunden(1), "0,3 h")
        XCTAssertEqual(Fahrplankacheln.viertelstunden(96), "24,0 h")
    }

    // MARK: - Die Legende

    func testDieLegendeHatDieElfStueckeDerVorlage() {
        let b = Fahrplanbild.baue(plan(anzahl: 8, preis: { _ in 30 }))
        let woerter = b.legende.map(\.wort)
        XCTAssertEqual(
            woerter,
            [
                "Wärmepumpe angefordert", "Wärmepumpe gemieden", "Wärmepumpe frei",
                "Wärmepumpe aus", "Ofen brennt", "Heizen", "Warmwasser", "Pufferinhalt",
                "PV gemessen", "PV erwartet", "Preistief",
            ])
    }

    func testDasZwoelfteStueckStehtNurBeiNegativemPreis() {
        let ohne = Fahrplanbild.baue(plan(anzahl: 8, preis: { _ in 30 }))
        XCTAssertFalse(ohne.legende.contains { $0.wort == "negativer Preis" })
    }

    /// Ohne Intervalle bleibt die Horizontkarte stehen - mit dem Satz und der ganzen Legende.
    func testDieLegendeStehtAuchOhnePlanUndOhneIntervalle() {
        let ohneIntervalle = plan(anzahl: 0)
        XCTAssertEqual(
            Fahrplanbild.legende(nil).map(\.wort),
            Fahrplanbild.legende(ohneIntervalle).map(\.wort))
        XCTAssertEqual(Fahrplanbild.legende(nil).count, 11)
        XCTAssertFalse(Fahrplanbild.legende(nil).contains { $0.wort == "negativer Preis" })
    }

    /// Das zwoelfte Stueck haengt an den Fenstern und nicht an den Intervallen: ein Plan ohne
    /// Viertelstunden kann ein negatives Preisfenster kennen.
    func testDasZwoelfteStueckHaengtAmFensterUndNichtAmBild() {
        let mit = plan(
            anzahl: 0,
            fenster: [
                PriceWindowOut(
                    start: Zeit.iso(ab.addingTimeInterval(3600)),
                    end: Zeit.iso(ab.addingTimeInterval(7200)), kind: .negative,
                    labelDe: "negativer Preis")
            ])
        XCTAssertTrue(Fahrplanbild.legende(mit).contains { $0.wort == "negativer Preis" })
        XCTAssertEqual(Fahrplanbild.legende(mit).count, 12)
    }

    func testDieKlotzhoehenFolgenDenBalkenhoehen() {
        let b = Fahrplanbild.baue(plan(anzahl: 8, preis: { _ in 30 }))
        let dick = Dictionary(uniqueKeysWithValues: b.legende.map { ($0.wort, $0.dick) })
        XCTAssertEqual(dick["Wärmepumpe angefordert"], 10)
        XCTAssertEqual(dick["Wärmepumpe gemieden"], 6)
        XCTAssertEqual(dick["Wärmepumpe frei"], 3, "0,3 mal 10 gerundet waere 3")
        XCTAssertEqual(dick["Wärmepumpe aus"], 3, "unter drei Punkten sieht man nichts mehr")
        XCTAssertEqual(dick["Pufferinhalt"], 3, "eine Linie, keine Flaeche")
        XCTAssertEqual(dick["PV erwartet"], 2, "ein gestrichelter Strich")
    }

    // MARK: - Die festen Saetze

    func testDieMethodeHatDreiAbsaetzeUndNennteBusUndPreisregel() {
        XCTAssertEqual(Fahrplanworte.methode.count, 3)
        XCTAssertTrue(Fahrplanworte.methode[0].contains("eBUS"))
        XCTAssertTrue(Fahrplanworte.methode[1].contains("Preisregel"))
        XCTAssertTrue(Fahrplanworte.methode[2].contains("Rückblick"))
        XCTAssertFalse(Fahrplanworte.methodeKurz.isEmpty)
    }
}
