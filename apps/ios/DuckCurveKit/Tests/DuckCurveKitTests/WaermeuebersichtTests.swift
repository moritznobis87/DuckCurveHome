import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/HeatOverview.tsx`.
final class WaermeuebersichtTests: XCTestCase {

    private let ab = Zeit.ausIso("2026-11-17T00:00:00+01:00")!

    private func totals(
        minuten: Int? = 1440, erzeugt: Double? = 24.5, wp: Double? = 20.1,
        ofenWasser: Double? = 3.2, ofenRaum: Double? = 1.2, entnahme: Double? = 18.4,
        verlust: Double? = 2.1, strom: Double? = 7.0, cop: Double? = 2.87,
        rest: Double? = 0.8
    ) -> HeatTotals {
        HeatTotals(
            minutes: minuten, heatPumpKwh: wp, stoveWaterKwh: ofenWasser,
            stoveRoomKwh: ofenRaum, producedKwh: erzeugt, drawKwh: entnahme, lossKwh: verlust,
            residualKwh: rest, electricKwh: strom, copMean: cop)
    }

    private func kosten(
        bezahlt: Double? = 1.74, entgangen: Double? = 0.42, wpCt: Double? = 8.6,
        kg: Double? = 4.3, eur: Double? = 1.93, ofenCt: Double? = 9.1,
        guenstiger: String? = "Die Wärmepumpe war günstiger."
    ) -> HeatCostOut {
        HeatCostOut(
            heatPumpPaidEur: bezahlt, heatPumpOpportunityEur: entgangen,
            heatPumpCtPerKwh: wpCt, stoveKg: kg, stoveEur: eur, stoveCtPerKwh: ofenCt,
            cheaperDe: guenstiger)
    }

    private func bilanz(
        _ t: HeatTotals? = nil, kosten k: HeatCostOut? = nil,
        lueftung: VentilationOut? = nil, params: HeatParamsOut? = nil
    ) -> HeatBalanceOut {
        HeatBalanceOut(
            period: .day, start: Zeit.iso(ab), end: Zeit.iso(ab.addingTimeInterval(86400)),
            resolutionDe: "je Minute", totals: t ?? totals(), series: [], buckets: [],
            cost: k ?? kosten(), params: params ?? HeatParamsOut(copCurve: []),
            ventilation: lueftung)
    }

    private func summentotals(wp: Double = 7.0, pv: Double = 3.0, batt: Double = 1.0, netz: Double = 3.0)
        -> EnergyTotalsOut
    {
        EnergyTotalsOut(
            heatPumpKwh: wp, heatPumpPvKwh: pv, heatPumpBatteryKwh: batt, heatPumpGridKwh: netz)
    }

    private func strombericht(
        _ t: EnergyTotalsOut? = nil, takten: CyclingStats? = nil, ofen: StoveOut? = nil,
        puffer: [[String: Mischwert]] = [], abdeckung: Double? = 0.98, seit: String? = "2026-01-04"
    ) -> HeatReportOut {
        HeatReportOut(
            summary: EnergySummaryOut(
                period: .day, anchor: "2026-11-17", start: Zeit.iso(ab),
                end: Zeit.iso(ab.addingTimeInterval(86400)), totals: t ?? summentotals(),
                meta: EnergyMetaOut(
                    batteryCapacityKwh: 10, feedInCtKwh: 8.2, dataSince: seit,
                    coverage: abdeckung, estimatedNoteDe: "")),
            thermalKwhEst: 20.1, copEst: 2.87, forecastElectricKwh24h: 8.4,
            forecastThermalKwh24h: 24.1, bufferSeries: puffer, heatLossKwPerK: 0.21,
            cycling: takten ?? CyclingStats(), priceQuality: PriceQualityOut(),
            bufferBalance: BufferBalanceOut(), stove: ofen ?? StoveOut(),
            modelNoteDe: "")
    }

    // MARK: - Die sechs Kopfzahlen

    func testDieDreiFehlendenKopfzahlenStehenJetztDa() {
        let k = Waermeuebersicht.kacheln(bilanz: bilanz(), strom: strombericht())
        XCTAssertEqual(k.count, 6)
        XCTAssertEqual(k.map(\.wort), [
            "Wärme gesamt", "Strom Wärmepumpe", "Arbeitszahl", "Bezahlt", "Wärmepreis",
            "Entnahme",
        ])
        XCTAssertEqual(k.first { $0.wort == "Bezahlt" }?.wert, "1,74")
        XCTAssertEqual(k.first { $0.wort == "Wärmepreis" }?.wert, "8,6")
        XCTAssertEqual(k.first { $0.wort == "Entnahme" }?.wert, "18,4")
    }

    func testDerSonnenanteilStehtAnDerStromkachel() {
        let k = Waermeuebersicht.kacheln(
            bilanz: bilanz(), strom: strombericht(summentotals(wp: 10, pv: 6, batt: 2, netz: 2)))
        XCTAssertEqual(
            k.first { $0.wort == "Strom Wärmepumpe" }?.dazu,
            "\(Formate.prozent(0.8)) Sonnenstrom")
    }

    func testDerMittlereNetzpreisStehtAnDerBezahltKachel() {
        // 1,74 € fuer 3 kWh sind 58 ct je kWh.
        let k = Waermeuebersicht.kacheln(bilanz: bilanz(), strom: strombericht())
        XCTAssertEqual(k.first { $0.wort == "Bezahlt" }?.dazu, "3,0 kWh Netz · Ø 58,0 ct")
    }

    func testOhneNetzbezugStehtKeinMittelpreis() {
        let k = Waermeuebersicht.kacheln(
            bilanz: bilanz(), strom: strombericht(summentotals(netz: 0)))
        XCTAssertEqual(k.first { $0.wort == "Bezahlt" }?.dazu, "0,0 kWh Netz")
    }

    func testOhneOfenNenntDieWaermekachelNurDieWaermepumpe() {
        let k = Waermeuebersicht.kacheln(
            bilanz: bilanz(totals(ofenWasser: 0, ofenRaum: 0)), strom: strombericht())
        XCTAssertEqual(k[0].dazu, "nur die Wärmepumpe")
    }

    func testMitOfenStehtDieZerlegung() {
        let k = Waermeuebersicht.kacheln(bilanz: bilanz(), strom: strombericht())
        XCTAssertEqual(k[0].dazu, "Wärmepumpe 20,1 · Ofen 4,4 kWh")
    }

    func testEinZeitraumOhneGemesseneMinuteIstEinStrichUndKeineNull() {
        let k = Waermeuebersicht.kacheln(
            bilanz: bilanz(totals(minuten: 0)), strom: strombericht())
        XCTAssertEqual(k[0].wert, Formate.leer, "Null waere die Behauptung, es sei nichts gelaufen.")
        XCTAssertEqual(k.first { $0.wort == "Entnahme" }?.wert, Formate.leer)
    }

    func testNullIstEineMessung() {
        let k = Waermeuebersicht.kacheln(
            bilanz: bilanz(totals(minuten: 1440, erzeugt: 0)), strom: strombericht())
        XCTAssertEqual(k[0].wert, "0,0")
    }

    func testOhneArbeitszahlSagtDieKachelWarum() {
        let k = Waermeuebersicht.kacheln(
            bilanz: bilanz(totals(cop: nil)), strom: strombericht())
        XCTAssertEqual(k.first { $0.wort == "Arbeitszahl" }?.dazu, "keine Laufzeit")
    }

    // MARK: - Kosten

    func testDieKostenkarteNenntFuenfZeilenUndDenWaermepreis() {
        XCTAssertEqual(Waermeuebersicht.kostenkernzahl(kosten()).wert, "8,6")
        let z = Waermeuebersicht.kostenzeilen(kosten())
        XCTAssertEqual(z.count, 5)
        XCTAssertEqual(z[0].wert, Formate.euro(1.74))
        XCTAssertEqual(z[2].wert, "4,3 kg")
        XCTAssertEqual(z[4].wert, Formate.ct(9.1))
    }

    func testOhneKostenStehenStriche() {
        let z = Waermeuebersicht.kostenzeilen(nil)
        XCTAssertEqual(z.count, 5)
        XCTAssertTrue(z.allSatisfy { $0.wert == Formate.leer })
    }

    // MARK: - Verschieben

    func testDasVorzeichenDesSparbetragsStehtAlsSatzUndNichtAlsMinus() {
        let gespart = ShiftReportOut(
            period: .day, start: Zeit.iso(ab), end: Zeit.iso(ab), actualEur: 1.2,
            naiveEur: 1.5, savingEur: 0.3, savingCtPerKwh: 1.4, heatPumpKwh: 21,
            shiftedKwh: 8, daysUsed: 1, daysSkipped: 0, methodDe: "")
        let a = Waermeuebersicht.schieben(gespart)
        XCTAssertEqual(a.kernzahl, Formate.euro(0.3))
        XCTAssertEqual(a.bedeutung, "gespart gegenüber einem Lauf ohne Preisblick")
        XCTAssertEqual(a.zeilen.count, 3)
        XCTAssertEqual(a.zeilen[0].wert, "8 von 21 kWh")
        XCTAssertNil(a.hinweis)

        var teurer = gespart
        teurer.savingEur = -0.45
        let b = Waermeuebersicht.schieben(teurer)
        XCTAssertEqual(b.kernzahl, Formate.euro(0.45), "Der Betrag, das Vorzeichen steht im Wort.")
        XCTAssertEqual(b.bedeutung, "mehr bezahlt als ohne Preisblick")
    }

    func testOhneGerechneteTageStehtDerErsatzsatz() {
        let a = Waermeuebersicht.schieben(nil)
        XCTAssertEqual(a.kernzahl, Formate.leer)
        XCTAssertEqual(a.bedeutung, "keine Aussage für diesen Zeitraum")
        XCTAssertTrue(a.zeilen.isEmpty)
        XCTAssertEqual(
            a.hinweis,
            "Dafür braucht es einen Tag mit genug gemessenen Stunden und laufender Wärmepumpe.")

        let mitGrund = ShiftReportOut(
            period: .day, start: Zeit.iso(ab), end: Zeit.iso(ab), actualEur: 0, naiveEur: 0,
            savingEur: 0, heatPumpKwh: 0, shiftedKwh: 0, daysUsed: 0, daysSkipped: 1,
            skippedDe: "Zu wenig gemessene Stunden.", methodDe: "")
        XCTAssertEqual(Waermeuebersicht.schieben(mitGrund).hinweis, "Zu wenig gemessene Stunden.")
    }

    // MARK: - Taktung

    func testDieTaktkarteSagtAufWelcherBasisSieUrteilt() {
        XCTAssertEqual(
            Waermeuebersicht.taktkopf(CyclingStats(coveredHours: 11.6)), "12 h bewertet")
        XCTAssertNil(Waermeuebersicht.taktkopf(CyclingStats()))
    }

    func testDieTaktzeilenSindDieSechsDerVorlage() {
        let z = Waermeuebersicht.taktzeilen(
            CyclingStats(
                runs: 7, dutyCycle: 0.31, meanRunMin: 42.4, shortestRunMin: 9,
                meanPauseMin: 93.6, shortRuns: 2))
        XCTAssertEqual(z.map(\.wort), [
            "Läufe", "Laufanteil", "Lauf im Mittel", "kürzester Lauf", "Pause im Mittel",
            "unter Mindestlaufzeit",
        ])
        XCTAssertEqual(z[2].wert, "42 min")
        XCTAssertEqual(z[3].wert, "9 min")
        XCTAssertEqual(z[5].wert, "2×")
    }

    // MARK: - Der Ofen

    func testDieNeunOfenzeilenUndDerKopf() {
        let o = StoveOut(
            available: true, runningMinutes: 185, burningMinutes: 142, runs: 3,
            longestRunMin: 95, augerRevolutions: 1420, fumeTempMaxC: 184.2, spreadK: 12.4,
            dhwMinutes: 35, minutesByLevel: ["2": 70, "10": 15, "1": 45], operatingHours: 812.4,
            ignitions: 3, pelletKg: 4.3, pelletEur: 1.93, noteDe: "Lief sauber.",
            fuelNoteDe: "Aus 1420 Schneckenumdrehungen.")
        XCTAssertEqual(Waermeuebersicht.ofenkopf(o), "3 Brennphasen")
        let z = Waermeuebersicht.ofenzeilen(o)
        XCTAssertEqual(z.count, 9)
        XCTAssertEqual(z[0].wert, "2:22 h")
        XCTAssertEqual(z[1].wert, "95 min")
        XCTAssertEqual(z[4].wert, "12,4 K")
        XCTAssertEqual(z[5].wert, "184 °C")
        XCTAssertEqual(z[7].wert, "812 h")
        XCTAssertEqual(Waermeuebersicht.ofenbrennstoffsatz(o), "Aus 1420 Schneckenumdrehungen.")
    }

    func testEineEinzelneBrennphaseStehtImSingular() {
        XCTAssertEqual(Waermeuebersicht.ofenkopf(StoveOut(runs: 1)), "1 Brennphase")
        XCTAssertEqual(Waermeuebersicht.ofenkopf(StoveOut()), "0 Brennphasen")
    }

    func testDieLeistungsstufenStehenNachZahlSortiertUndNichtNachZeichen() {
        let o = StoveOut(minutesByLevel: ["2": 70, "10": 15, "1": 45])
        XCTAssertEqual(Waermeuebersicht.ofenstufen(o).map(\.stufe), ["1", "2", "10"])
        XCTAssertEqual(Waermeuebersicht.ofenstufen(o).map(\.dauer), ["45 min", "1:10 h", "15 min"])
    }

    func testOhneSchneckenzaehlungKeinBrennstoffsatz() {
        let o = StoveOut(fuelNoteDe: "Aus Schneckenumdrehungen.")
        XCTAssertNil(
            Waermeuebersicht.ofenbrennstoffsatz(o),
            "Ohne auger_revolutions ist der Satz eine Behauptung ohne Grundlage.")
    }

    func testDauerSchreibtStundenUndMinuten() {
        XCTAssertEqual(Waermeuebersicht.dauer(minuten: 45), "45 min")
        XCTAssertEqual(Waermeuebersicht.dauer(minuten: 60), "1:00 h")
        XCTAssertEqual(Waermeuebersicht.dauer(minuten: 185), "3:05 h")
        XCTAssertEqual(Waermeuebersicht.dauer(minuten: nil), Formate.leer)
    }

    // MARK: - Offenes Fenster

    func testDieFensterkarteStehtNurWennEsEtwasZuZeigenGibt() {
        XCTAssertFalse(Waermeuebersicht.zeigtFenster(nil))
        XCTAssertFalse(
            Waermeuebersicht.zeigtFenster(
                VentilationOut(kwh: 0, openMinutes: 0, minutesKnown: 1440, noteDe: "")))
        XCTAssertTrue(
            Waermeuebersicht.zeigtFenster(
                VentilationOut(kwh: 0, openMinutes: 25, minutesKnown: 1440, noteDe: "")))
        XCTAssertTrue(
            Waermeuebersicht.zeigtFenster(
                VentilationOut(kwh: 0.8, openMinutes: 0, minutesKnown: 1440, noteDe: "")))
    }

    func testDerFensterkopfNenntDenAnteilNurWennErNennenswertIst() {
        let viel = VentilationOut(
            kwh: 1.2, share: 0.065, openMinutes: 48, minutesKnown: 1440, noteDe: "")
        XCTAssertEqual(Waermeuebersicht.fensterkopf(viel), "48 min offen · 7 % der Entnahme")
        let wenig = VentilationOut(
            kwh: 0.1, share: 0.004, openMinutes: 6, minutesKnown: 1440, noteDe: "")
        XCTAssertEqual(Waermeuebersicht.fensterkopf(wenig), "6 min offen")
    }

    // MARK: - Wärme im Zeitraum

    func testDerSpannenvergleichHatZwoelfZeilenUndVierSpalten() {
        let z = Waermeuebersicht.spannenzeilen([.tag: bilanz(), .woche: bilanz()])
        XCTAssertEqual(z.count, 12)
        XCTAssertTrue(z.allSatisfy { $0.werte.count == 4 })
        XCTAssertEqual(z[0].wort, "Wärme gesamt · kWh")
        XCTAssertEqual(z[0].werte[0], "24,5")
        XCTAssertEqual(z[0].werte[2], Formate.leer, "Monat wurde nicht geholt.")
        XCTAssertEqual(z[7].wort, "Arbeitszahl")
        XCTAssertEqual(z[7].werte[0], "2,87")
        XCTAssertEqual(z[9].werte[0], Formate.euro(1.74))
    }

    // MARK: - Annahmen und Abdeckung

    func testDerAnnahmensatzNenntAlleZahlenDerRechnung() {
        let p = HeatParamsOut(
            copCurve: [[-7, 2.4], [2, 3.0], [7, 3.6]], copReferenceC: 45,
            stoveNominalHeatKw: 8.0, stoveWaterHeatKw: 5.5, pelletKwhPerKg: 4.85,
            pelletPriceEurPerT: 450, bufferVolumeLiters: 800, bufferLossKwPerK: 0.0021)
        let satz = Waermeuebersicht.annahmensatz(p)
        XCTAssertTrue(
            satz.contains("Kennlinie \(Formate.minus)7 °C: 2,4 · 2 °C: 3,0 · 7 °C: 3,6"), satz)
        XCTAssertTrue(satz.contains("gültig bei 45 °C Vorlauf"), satz)
        XCTAssertTrue(satz.contains("Puffer 800 l mit 2 W/K Verlust"), satz)
        XCTAssertTrue(satz.contains("Ofen 8,0 kW, davon 5,5 kW ins Wasser"), satz)
        XCTAssertTrue(satz.contains("Pellets 4,85 kWh/kg zu 450 €/t"), satz)
        XCTAssertTrue(satz.contains("auch die vergangener Jahre"), satz)
    }

    func testOhneKennlinieStehtEinStrichUndKeinLeererSatz() {
        let satz = Waermeuebersicht.annahmensatz(HeatParamsOut(copCurve: []))
        XCTAssertTrue(satz.contains("Kennlinie \(Formate.leer)"), satz)
    }

    func testDieAbdeckungStehtAlsSatz() {
        let m = EnergyMetaOut(
            batteryCapacityKwh: 10, feedInCtKwh: 8.2, dataSince: "2026-01-04", coverage: 0.98,
            estimatedNoteDe: "")
        XCTAssertEqual(
            Waermeuebersicht.abdeckungssatz(m),
            "Datenabdeckung \(Formate.prozent(0.98)) · Aufzeichnung seit So, 4.1.")
    }

    func testOhneMessdatenSagtDerSatzDas() {
        let m = EnergyMetaOut(
            batteryCapacityKwh: 10, feedInCtKwh: 8.2, coverage: 0, estimatedNoteDe: "")
        XCTAssertEqual(Waermeuebersicht.abdeckungssatz(m), "noch keine Messdaten im Zeitraum")
    }

    // MARK: - Die Pufferreihe

    private func pufferzeile(
        _ min: Int, oben: Double?, ofen: Bool
    ) -> [String: Mischwert] {
        var z: [String: Mischwert] = [
            "ts": .text(Zeit.iso(ab.addingTimeInterval(Double(min) * 60))),
            "buffer_temp_mid_top_c": .zahl(47.1),
            "buffer_temp_mid_bottom_c": .zahl(38.6),
            "buffer_temp_bottom_c": .zahl(31.2),
            "heat_pump_power_kw": .zahl(2.1),
            "stove_running": .ja(ofen),
        ]
        if let oben { z["buffer_temp_top_c"] = .zahl(oben) }
        return z
    }

    func testDiePufferreiheWirdGeordnetUndEinBlinderFuehlerBleibtLeer() {
        let roh = [
            pufferzeile(10, oben: 52.4, ofen: false),
            pufferzeile(0, oben: nil, ofen: false),
            pufferzeile(5, oben: 53.1, ofen: true),
        ]
        let r = Waermeuebersicht.pufferreihe(roh)
        XCTAssertEqual(r.count, 3)
        XCTAssertEqual(r.map(\.zeit), [0, 5, 10].map { ab.addingTimeInterval(Double($0) * 60) })
        XCTAssertNil(r[0].schichten[0], "Ein blinder Fuehler ist keine Null.")
        XCTAssertEqual(r[1].schichten[0], 53.1)
        XCTAssertEqual(r[0].schichten.count, 4)
        XCTAssertEqual(r[0].wpKw, 2.1)
    }

    func testZeilenOhneZeitstempelFallenWeg() {
        XCTAssertTrue(Waermeuebersicht.pufferreihe([["buffer_temp_top_c": .zahl(50)]]).isEmpty)
        XCTAssertTrue(Waermeuebersicht.pufferreihe([["ts": .text("unfug")]]).isEmpty)
    }

    func testBrennphasenSindZusammenhaengendeAbschnitte() {
        let roh = (0..<10).map { pufferzeile($0, oben: 50, ofen: (2..<5).contains($0)) }
        let p = Waermeuebersicht.brennphasen(Waermeuebersicht.pufferreihe(roh))
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p[0].von, ab.addingTimeInterval(2 * 60))
        XCTAssertEqual(p[0].bis, ab.addingTimeInterval(5 * 60))
    }

    func testEineBrennphaseBisZumEndeDerReiheBleibtOffenUndWirdGeschlossen() {
        let roh = (0..<6).map { pufferzeile($0, oben: 50, ofen: $0 >= 3) }
        let p = Waermeuebersicht.brennphasen(Waermeuebersicht.pufferreihe(roh))
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p[0].von, ab.addingTimeInterval(3 * 60))
        XCTAssertEqual(p[0].bis, ab.addingTimeInterval(5 * 60))
    }

    func testEineZahlStattEinesJaZaehltAuchAlsLaufenderOfen() {
        var z = pufferzeile(0, oben: 50, ofen: false)
        z["stove_running"] = .ganz(1)
        XCTAssertTrue(Waermeuebersicht.pufferreihe([z])[0].ofenLaeuft)
    }
}
