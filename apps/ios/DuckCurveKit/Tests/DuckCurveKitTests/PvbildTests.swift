import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/PvReport.tsx` und
/// `apps/web/src/components/reports/charts.ts`.
final class PvbildTests: XCTestCase {

    // 10.11.2026 ist ein Dienstag; Winterzeit, also +01:00.
    private let tagesbeginn = Zeit.ausIso("2026-11-10T00:00:00+01:00")!
    private let mittag = Zeit.ausIso("2026-11-10T12:00:00+01:00")!

    // MARK: - Hilfen

    /// Ein Plan mit `anzahl` Intervallen im Abstand `abstand` Sekunden ab `ab`.
    private func plan(
        ab: Date, anzahl: Int, abstand: Double = 900, pv: (Int) -> Double = { _ in 0 },
        tagessumme: Double = 0
    ) -> PlanOut {
        let iv = (0..<anzahl).map { i in
            PlanIntervalOut(
                ts: Zeit.iso(ab.addingTimeInterval(Double(i) * abstand)), expectedPvKw: pv(i),
                plannedHpState: .off, reasonCode: "planned_optimizer")
        }
        return PlanOut(
            createdAt: Zeit.iso(ab), planner: "test", horizonStart: Zeit.iso(ab),
            horizonEnd: Zeit.iso(ab.addingTimeInterval(48 * 3600)), windows: [], intervals: iv,
            pvForecastTodayKwh: tagessumme)
    }

    private func totals(
        minutes: Int? = 600, pv: Double? = 12.5, exportKwh: Double? = 4.0,
        direkt: Double? = 5.0, speicher: Double? = 3.5, erloes: Double? = 0.32,
        ersparnisDirekt: Double? = 1.75, anteil: Double? = 0.68, batterieNetto: Double? = 0.4
    ) -> EnergyTotalsOut {
        var t = EnergyTotalsOut()
        t.minutes = minutes
        t.pvKwh = pv
        t.exportKwh = exportKwh
        t.pvDirectKwh = direkt
        t.pvToBatteryKwh = speicher
        t.exportRevenueEur = erloes
        t.pvDirectSavingsEur = ersparnisDirekt
        t.selfConsumptionShare = anteil
        t.batteryNetEur = batterieNetto
        return t
    }

    private func meta(
        feedIn: Double = 8.2, seit: String? = "2026-03-14T00:00:00+01:00",
        abdeckung: Double? = 0.61
    ) -> EnergyMetaOut {
        EnergyMetaOut(
            batteryCapacityKwh: 10, feedInCtKwh: feedIn, dataSince: seit, coverage: abdeckung,
            estimatedNoteDe: "Geschätzt, wo Minutenwerte fehlen.")
    }

    private func bericht(
        _ t: EnergyTotalsOut? = nil, buckets: [EnergyBucketOut] = [],
        meta m: EnergyMetaOut? = nil, anker: String = "2026-11-10"
    ) -> EnergySummaryOut {
        EnergySummaryOut(
            period: .day, anchor: anker, start: "\(anker)T00:00:00+01:00",
            end: "\(anker)T23:59:59+01:00", totals: t ?? totals(), buckets: buckets,
            meta: m ?? meta())
    }

    private func bucket(_ label: String, _ t: EnergyTotalsOut) -> EnergyBucketOut {
        EnergyBucketOut(start: "2026-11-10T00:00:00+01:00", end: "2026-11-10T01:00:00+01:00",
                        label: label, totals: t)
    }

    // MARK: - Prognosesummen (PvReport.tsx:24-36)

    func testOhnePlanIstBeidesNull() {
        let p = Pvbild.prognose(nil, tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 0)
        XCTAssertEqual(p.morgen, 0)
        XCTAssertTrue(p.punkte.isEmpty)
    }

    /// Weniger als zwei Stuetzpunkte: keine Intervallbreite, also keine eigene Summe - das
    /// Feld des Dienstes steht allein da (`PvReport.tsx:25`).
    func testEinEinzelnesIntervallGibtNurDasFeldDesDienstes() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 1, pv: { _ in 9 }, tagessumme: 17.5),
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 17.5)
        XCTAssertEqual(p.morgen, 0)
        XCTAssertEqual(p.punkte.count, 1)
    }

    func testLeererPlanOhneTagessummeGibtNull() {
        let p = Pvbild.prognose(plan(ab: tagesbeginn, anzahl: 0), tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 0)
    }

    /// Viertelstunden zu 2 kW ueber einen ganzen Tag: 96 mal 2 mal 0,25 = 48 kWh.
    func testViertelstundenWerdenMitDerIntervallbreiteGewichtet() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 96, pv: { _ in 2 }), tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 48, accuracy: 1e-9)
        XCTAssertEqual(p.morgen, 0, accuracy: 1e-9)
    }

    /// Dasselbe mit Stundenintervallen: die Breite kommt aus den Daten, nicht aus einer
    /// Annahme ueber das Raster.
    func testStundenintervalleErgebenDieVierfacheSumme() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 24, abstand: 3600, pv: { _ in 2 }),
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 48, accuracy: 1e-9)
    }

    /// Zwei Tage im Plan: die zweite Haelfte zaehlt zu morgen, nicht zu heute.
    func testDasZweiteFensterIstMorgen() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 192, pv: { $0 < 96 ? 2 : 4 }),
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 48, accuracy: 1e-9)
        XCTAssertEqual(p.morgen, 96, accuracy: 1e-9)
    }

    /// Was hinter dem zweiten Tag liegt, zaehlt zu keinem der beiden Fenster.
    func testDerDritteTagZaehltZuKeinemFenster() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 288, pv: { _ in 2 }), tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 48, accuracy: 1e-9)
        XCTAssertEqual(p.morgen, 48, accuracy: 1e-9)
    }

    /// Ein Plan, der vor dem Tagesbeginn anfaengt: das Fenster ist halboffen links
    /// geschlossen - was davor liegt, faellt heraus.
    func testWasVorDemTagesbeginnLiegtFaelltHeraus() {
        let p = Pvbild.prognose(
            plan(
                ab: tagesbeginn.addingTimeInterval(-6 * 3600), anzahl: 120, pv: { _ in 2 }),
            tagesbeginn: tagesbeginn)
        // 120 Viertelstunden ab 18:00 des Vortags: 24 davon liegen vor Mitternacht.
        XCTAssertEqual(p.heute, 96 * 2 * 0.25, accuracy: 1e-9)
    }

    /// **Die Regel, an der man sich verrechnet:** `pvForecastTodayKwh` schlaegt die eigene
    /// Summe, aber nur wenn es ungleich Null ist (`PvReport.tsx:35`).
    func testDasFeldDesDienstesSchlaegtDieEigeneSumme() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 96, pv: { _ in 2 }, tagessumme: 31.4),
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 31.4)
        XCTAssertEqual(p.morgen, 0, accuracy: 1e-9)
    }

    func testEineNullImFeldDesDienstesSchlaegtNichts() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 96, pv: { _ in 2 }, tagessumme: 0),
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 48, accuracy: 1e-9)
    }

    /// Ein unlesbarer Zeitstempel faellt heraus und zieht die Achse nicht auf 1970.
    func testUnlesbareZeitstempelFallenHeraus() {
        var iv = plan(ab: tagesbeginn, anzahl: 4, pv: { _ in 2 }).intervals
        iv[2] = PlanIntervalOut(
            ts: "kein Zeitstempel", expectedPvKw: 99, plannedHpState: .off,
            reasonCode: "planned_optimizer")
        let roh = PlanOut(
            createdAt: Zeit.iso(tagesbeginn), planner: "test",
            horizonStart: Zeit.iso(tagesbeginn), horizonEnd: Zeit.iso(mittag), windows: [],
            intervals: iv, pvForecastTodayKwh: 0)
        let p = Pvbild.prognose(roh, tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.punkte.count, 3)
        XCTAssertEqual(p.heute, 3 * 2 * 0.25, accuracy: 1e-9)
    }

    /// Zwei gleiche Zeitstempel ergaeben die Breite Null; die Untergrenze ist eine Minute.
    func testDoppelteZeitstempelZiehenDieSummeNichtAufNull() {
        let p = Pvbild.prognose(
            plan(ab: tagesbeginn, anzahl: 2, abstand: 0, pv: { _ in 60 }),
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(p.heute, 2 * 60 * (1.0 / 60.0), accuracy: 1e-9)
    }

    // MARK: - Die Zweitageskurve (charts.ts:178-233)

    private func raster(_ werte: [(Int, Double?)]) -> [Verlaufspunkt] {
        werte.map {
            Verlaufspunkt(zeit: tagesbeginn.addingTimeInterval(Double($0.0) * 60), pv: $0.1)
        }
    }

    func testDasFensterReichtUeber48Stunden() {
        let b = Pvbild.tagundmorgen(raster: [], plan: nil, tagesbeginn: tagesbeginn)
        XCTAssertEqual(b.beginn, tagesbeginn)
        XCTAssertEqual(b.tagesende, tagesbeginn.addingTimeInterval(24 * 3600))
        XCTAssertEqual(b.ende, tagesbeginn.addingTimeInterval(48 * 3600))
        XCTAssertTrue(b.leer)
        XCTAssertEqual(b.hoechstwert, 0)
    }

    /// **Die Regel, um die es hier geht:** eine Luecke bleibt eine Luecke. Drei Messungen,
    /// ein Loch, zwei Messungen - das sind zwei Abschnitte und nicht eine Linie darueber.
    func testEineLueckeZerlegtDieIstkurve() {
        let b = Pvbild.tagundmorgen(
            raster: raster([(0, 1), (1, 2), (2, 3), (3, nil), (4, 4), (5, 5)]), plan: nil,
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(b.ist.count, 2)
        XCTAssertEqual(b.ist[0].punkte.map(\.kw), [1, 2, 3])
        XCTAssertEqual(b.ist[1].punkte.map(\.kw), [4, 5])
        XCTAssertEqual(b.ist[0].nummer, 0)
        XCTAssertEqual(b.ist[1].nummer, 1)
        XCTAssertEqual(b.hoechstwert, 5)
    }

    func testMehrereLueckenHintereinanderSindEineLuecke() {
        let b = Pvbild.tagundmorgen(
            raster: raster([(0, 1), (1, nil), (2, nil), (3, nil), (4, 2)]), plan: nil,
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(b.ist.count, 2)
    }

    func testEinRasterNurAusLueckenGibtKeinenAbschnitt() {
        let b = Pvbild.tagundmorgen(
            raster: raster([(0, nil), (1, nil)]), plan: nil, tagesbeginn: tagesbeginn)
        XCTAssertTrue(b.ist.isEmpty)
        XCTAssertTrue(b.leer)
    }

    func testEineEinzelneMessungBleibtEinAbschnitt() {
        let b = Pvbild.tagundmorgen(
            raster: raster([(0, nil), (1, 7), (2, nil)]), plan: nil,
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(b.ist.count, 1)
        XCTAssertEqual(b.ist[0].punkte.count, 1)
    }

    /// Punkte ausserhalb des Fensters gehoeren nicht ins Bild - und sie beenden das laufende
    /// Stueck, damit keine Linie quer durch das Bild gezogen wird.
    func testPunkteAusserhalbDesFenstersFallenHeraus() {
        let draussen = Verlaufspunkt(
            zeit: tagesbeginn.addingTimeInterval(-3600), pv: 9)
        let dahinter = Verlaufspunkt(
            zeit: tagesbeginn.addingTimeInterval(49 * 3600), pv: 9)
        let b = Pvbild.tagundmorgen(
            raster: [draussen] + raster([(10, 1), (11, 2)]) + [dahinter], plan: nil,
            tagesbeginn: tagesbeginn)
        XCTAssertEqual(b.ist.count, 1)
        XCTAssertEqual(b.ist[0].punkte.map(\.kw), [1, 2])
    }

    func testDasRasterWirdNachZeitSortiert() {
        let b = Pvbild.tagundmorgen(
            raster: raster([(5, 5), (1, 1), (3, 3)]), plan: nil, tagesbeginn: tagesbeginn)
        XCTAssertEqual(b.ist.count, 1)
        XCTAssertEqual(b.ist[0].punkte.map(\.kw), [1, 3, 5])
    }

    func testDiePrognosereiheWirdAufDasFensterBeschnitten() {
        let b = Pvbild.tagundmorgen(
            raster: [],
            plan: plan(
                ab: tagesbeginn.addingTimeInterval(-3600), anzahl: 300, abstand: 1800,
                pv: { _ in 1 }),
            tagesbeginn: tagesbeginn)
        // 300 Halbstunden ab 23:00 des Vortags reichen bis weit in den dritten Tag; im
        // Fenster liegen die 97 Stuetzpunkte von 00:00 bis einschliesslich 48:00.
        XCTAssertEqual(b.prognose.count, 97)
        XCTAssertEqual(b.prognose.first?.zeit, tagesbeginn)
        XCTAssertEqual(b.prognose.last?.zeit, b.ende)
    }

    // MARK: - Die sechs Kacheln (PvReport.tsx:87-98)

    func testDieSechsKachelnStehenInDerReihenfolgeDerVorlage() {
        let k = Pvbild.kacheln(
            bericht(), prognose: Pvbild.Prognose(heute: 18.4, morgen: 22.1, punkte: []),
            istHeute: true)
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Erzeugung", "Eigenverbrauch", "Eingespeist", "Ersparnis direkt",
                "Prognose heute", "Prognose morgen",
            ])
    }

    func testDieWerteUndSaetzeDerKacheln() {
        let k = Pvbild.kacheln(
            bericht(), prognose: Pvbild.Prognose(heute: 18.45, morgen: 22.1, punkte: []),
            istHeute: true)
        XCTAssertEqual(k[0].wert, "12,5")
        XCTAssertEqual(k[0].einheit, "kWh")
        XCTAssertEqual(k[0].dazu, "10 h bewertet")
        XCTAssertEqual(k[0].ton, .sonne)
        XCTAssertEqual(k[1].wert, "68\(Formate.schmalesLeerzeichen)%")
        XCTAssertNil(k[1].einheit)
        XCTAssertEqual(k[1].dazu, "8,5 kWh selbst genutzt")
        XCTAssertEqual(k[1].ton, .normal)
        XCTAssertEqual(k[2].wert, "4,0")
        XCTAssertEqual(
            k[2].dazu, "Erlös 0,32\(Formate.schmalesLeerzeichen)€ bei 8,2 ct")
        XCTAssertEqual(k[2].ton, .nebel)
        XCTAssertEqual(k[3].wert, "1,75\(Formate.schmalesLeerzeichen)€")
        XCTAssertEqual(k[3].dazu, "gegenüber Netzbezug")
        XCTAssertEqual(k[3].ton, .bernstein)
        XCTAssertEqual(k[4].wert, "18,5")
        XCTAssertEqual(k[4].dazu, "12,5 kWh bisher erzeugt")
        XCTAssertEqual(k[5].wert, "22,1")
        XCTAssertEqual(k[5].dazu, "aus Wetterprognose")
    }

    /// **Der Satz, der nicht verloren gehen darf.** Blaettert man zurueck, folgt der Rest der
    /// Seite dem gewaehlten Tag, die Prognose aber nicht.
    func testBeiEinemVergangenenTagStehtDieAbgrenzungDa() {
        let k = Pvbild.kacheln(
            bericht(anker: "2026-11-03"),
            prognose: Pvbild.Prognose(heute: 18.4, morgen: 0, punkte: []), istHeute: false)
        XCTAssertEqual(k[4].dazu, "für heute, nicht für den gewählten Tag")
    }

    func testOhneAntwortBleibenDieSaetzeWeg() {
        let k = Pvbild.kacheln(
            nil, prognose: Pvbild.Prognose(heute: 0, morgen: 0, punkte: []), istHeute: true)
        XCTAssertEqual(k[0].wert, Formate.leer)
        XCTAssertEqual(k[0].dazu, "keine Daten")
        XCTAssertNil(k[1].dazu)
        XCTAssertNil(k[2].dazu)
        XCTAssertEqual(k[3].dazu, "gegenüber Netzbezug")
        XCTAssertEqual(k[4].dazu, "Tagesprognose")
        XCTAssertEqual(k[5].wert, Formate.leer)
        XCTAssertEqual(k[5].dazu, "noch nicht verfügbar")
    }

    func testFehlendeEinzelfelderGebenEinenStrichUndKeineNull() {
        let t = totals(
            minutes: nil, pv: nil, exportKwh: nil, direkt: nil, speicher: nil, erloes: nil,
            ersparnisDirekt: nil, anteil: nil, batterieNetto: nil)
        let k = Pvbild.kacheln(
            bericht(t), prognose: Pvbild.Prognose(heute: 0, morgen: 0, punkte: []),
            istHeute: true)
        XCTAssertEqual(k[0].wert, Formate.leer)
        XCTAssertEqual(k[0].dazu, "keine Daten")
        XCTAssertEqual(k[1].wert, Formate.leer)
        // Die Summe der beiden Eigenverbrauchsteile ist eine Summe und keine Zahl des
        // Dienstes: fehlen beide, steht 0,0 - die Antwort war da, nur die Felder nicht.
        XCTAssertEqual(k[1].dazu, "0,0 kWh selbst genutzt")
        XCTAssertEqual(k[2].dazu, "Erlös \(Formate.leer) bei 8,2 ct")
        XCTAssertEqual(k[3].wert, Formate.leer)
    }

    func testNullMinutenHeisstKeineDaten() {
        XCTAssertEqual(Pvbild.bewertet(0), "keine Daten")
        XCTAssertEqual(Pvbild.bewertet(nil), "keine Daten")
    }

    /// 29 Minuten runden auf Null Stunden - der Satz heisst dann „0 h bewertet“ und nicht
    /// „keine Daten“: es ist gemessen worden, nur wenig.
    func testDieStundenWerdenKaufmaennischGerundet() {
        XCTAssertEqual(Pvbild.bewertet(29), "0 h bewertet")
        XCTAssertEqual(Pvbild.bewertet(30), "1 h bewertet")
        XCTAssertEqual(Pvbild.bewertet(89), "1 h bewertet")
        XCTAssertEqual(Pvbild.bewertet(90), "2 h bewertet")
        XCTAssertEqual(Pvbild.bewertet(1440), "24 h bewertet")
    }

    /// Genau Null heisst „noch nicht verfuegbar“, nicht „0,0 kWh“ (`PvReport.tsx:97`).
    func testEineMorgenprognoseVonNullIstKeineProgose() {
        let k = Pvbild.kacheln(
            bericht(), prognose: Pvbild.Prognose(heute: 1, morgen: 0, punkte: []),
            istHeute: true)
        XCTAssertEqual(k[5].wert, Formate.leer)
        XCTAssertEqual(k[5].dazu, "noch nicht verfügbar")
    }

    // MARK: - Erzeugung und Verwendung (charts.ts:52-89)

    func testDieDreiReihenHeissenWieInDerVorlage() {
        XCTAssertEqual(
            Pvbild.Verwendung.allCases.map(\.name),
            ["Direkt genutzt", "In Batterie", "Eingespeist"])
    }

    func testDieBalkenTragenDieDreiWerteInDerReihenfolgeDerReihen() {
        let b = Pvbild.verwendung(
            bericht(buckets: [
                bucket("08", totals(exportKwh: 0.5, direkt: 1.25, speicher: 0.75)),
                bucket("09", totals(exportKwh: 1.0, direkt: 2.0, speicher: 0)),
            ]))
        XCTAssertEqual(b.count, 2)
        XCTAssertEqual(b[0].wort, "08")
        XCTAssertEqual(b[0].werte, [1.25, 0.75, 0.5])
        XCTAssertEqual(b[0].summe, 2.5, accuracy: 1e-9)
        XCTAssertEqual(b[1].werte, [2.0, 0, 1.0])
    }

    /// Ein fehlendes Feld ist in einem gestapelten Balken eine Null: ein Loch verschiebt die
    /// Reihen darueber.
    func testFehlendeFelderWerdenNullUndNichtNichts() {
        let b = Pvbild.verwendung(
            bericht(buckets: [bucket("08", totals(exportKwh: nil, direkt: 1, speicher: nil))]))
        XCTAssertEqual(b[0].werte, [1, 0, 0])
    }

    /// Die Vorlage rundet die Balkenwerte auf zwei Stellen, bevor sie sie zeichnet.
    func testDieBalkenwerteWerdenAufZweiStellenGerundet() {
        let b = Pvbild.verwendung(
            bericht(buckets: [
                bucket("08", totals(exportKwh: 0.004, direkt: 1.2349, speicher: 0.005))
            ]))
        XCTAssertEqual(b[0].werte, [1.23, 0.01, 0.0])
    }

    func testOhneAntwortGibtEsKeineBalken() {
        XCTAssertTrue(Pvbild.verwendung(nil).isEmpty)
        XCTAssertTrue(Pvbild.verwendung(bericht()).isEmpty)
    }

    func testDieAblesungNenntBucketReihenUndSumme() {
        let b = Pvbild.verwendung(
            bericht(buckets: [bucket("08", totals(exportKwh: 0.5, direkt: 1.25, speicher: 0.75))]))
        let a = Pvbild.ablesung(b[0])
        XCTAssertEqual(a.wort, "08")
        XCTAssertEqual(a.zeilen.map(\.name), ["Direkt genutzt", "In Batterie", "Eingespeist"])
        XCTAssertEqual(a.zeilen.map(\.wert).first, "1,3\(Formate.schmalesLeerzeichen)kWh")
        XCTAssertEqual(a.summe, "Summe 2,5\(Formate.schmalesLeerzeichen)kWh")
    }

    /// Reihen mit Null fallen weg: „In Batterie 0,0 kWh“ an einem Dezembertag ist eine Zeile
    /// ohne Aussage (`charts.ts:66`).
    func testReihenMitNullStehenNichtInDerAblesung() {
        let b = Pvbild.verwendung(
            bericht(buckets: [bucket("08", totals(exportKwh: 0, direkt: 2, speicher: 0))]))
        let a = Pvbild.ablesung(b[0])
        XCTAssertEqual(a.zeilen.map(\.name), ["Direkt genutzt"])
        XCTAssertEqual(a.summe, "Summe 2,0\(Formate.schmalesLeerzeichen)kWh")
    }

    func testEinLeererBalkenHatKeineZeilenAberEineSumme() {
        let b = Pvbild.verwendung(
            bericht(buckets: [bucket("03", totals(exportKwh: 0, direkt: 0, speicher: 0))]))
        let a = Pvbild.ablesung(b[0])
        XCTAssertTrue(a.zeilen.isEmpty)
        XCTAssertEqual(a.summe, "Summe 0,0\(Formate.schmalesLeerzeichen)kWh")
    }

    func testDerGeleseneBalkenWirdAmAchsenwortGefunden() {
        let b = Pvbild.verwendung(
            bericht(buckets: [bucket("08", totals()), bucket("09", totals())]))
        XCTAssertEqual(Pvbild.balken(b, wort: "09")?.nummer, 1)
        XCTAssertNil(Pvbild.balken(b, wort: "10"))
        XCTAssertNil(Pvbild.balken(b, wort: nil))
    }

    // MARK: - PV im Überblick (PvReport.tsx:111-120)

    func testDieVierZeilenDesStreifens() {
        let je: [Spanne: EnergySummaryOut] = [
            .tag: bericht(), .woche: bericht(), .monat: bericht(), .jahr: bericht(),
        ]
        let z = Pvbild.spannenzeilen(je)
        XCTAssertEqual(
            z.map(\.wort),
            ["Erzeugt · kWh", "Eigenverbrauch", "Einspeiseerlös", "Ersparnis"])
        XCTAssertEqual(z[0].ton, .bernstein)
        XCTAssertEqual(z[1].ton, .normal)
        XCTAssertEqual(z[0].werte, ["12,5", "12,5", "12,5", "12,5"])
        XCTAssertEqual(z[1].werte.first, "68\(Formate.schmalesLeerzeichen)%")
        XCTAssertEqual(z[2].werte.first, "0,32\(Formate.schmalesLeerzeichen)€")
        // 1,75 + 0,40 - die Summe aus zwei Feldern, die es so in keiner Antwort gibt.
        XCTAssertEqual(z[3].werte.first, "2,15\(Formate.schmalesLeerzeichen)€")
    }

    /// Ab hundert kWh ohne Nachkommastelle (`PvReport.tsx:115`).
    func testAbHundertKwhOhneNachkommastelle() {
        let z = Pvbild.spannenzeilen([
            .tag: bericht(totals(pv: 99.94)), .jahr: bericht(totals(pv: 4213.7)),
        ])
        XCTAssertEqual(z[0].werte[0], "99,9")
        XCTAssertEqual(z[0].werte[3], "4214")
    }

    func testGenauHundertIstSchonOhneNachkommastelle() {
        let z = Pvbild.spannenzeilen([.tag: bericht(totals(pv: 100))])
        XCTAssertEqual(z[0].werte[0], "100")
    }

    /// Eine gescheiterte Spanne faellt weg, der Streifen bleibt - mit einem Strich in ihrer
    /// Spalte und nicht mit einer Null.
    func testEineFehlendeSpanneGibtEinenStrich() {
        let z = Pvbild.spannenzeilen([.tag: bericht(), .jahr: bericht()])
        XCTAssertEqual(z[0].werte, ["12,5", Formate.leer, Formate.leer, "12,5"])
        XCTAssertEqual(z[3].werte[1], Formate.leer)
    }

    func testOhneJedeSpanneStehenVierStriche() {
        let z = Pvbild.spannenzeilen([:])
        XCTAssertEqual(z.count, 4)
        for zeile in z {
            XCTAssertEqual(zeile.werte, Array(repeating: Formate.leer, count: 4))
        }
    }

    /// Fehlen beide Geldfelder, gibt es keine Summe und keine Null.
    func testOhneBeideGeldfelderGibtEsKeineErsparnis() {
        XCTAssertNil(
            Pvbild.ersparnis(totals(ersparnisDirekt: nil, batterieNetto: nil)))
        XCTAssertEqual(
            Pvbild.ersparnis(totals(ersparnisDirekt: nil, batterieNetto: 0.4)), 0.4)
        XCTAssertEqual(
            Pvbild.ersparnis(totals(ersparnisDirekt: 1.75, batterieNetto: nil)), 1.75)
        let z = Pvbild.spannenzeilen([
            .tag: bericht(totals(ersparnisDirekt: nil, batterieNetto: nil))
        ])
        XCTAssertEqual(z[3].werte[0], Formate.leer)
    }

    // MARK: - Methodensatz und die geteilten Wörter

    /// Spaltenköpfe, Hinweis und Kurzzeile sind nicht Sache dieser Seite - geprüft wird hier
    /// nur, dass die Seite dieselben Wörter bekommt wie ihre Schwestern.
    func testDieSeiteBenutztDieGeteiltenWoerterDesStreifens() {
        XCTAssertEqual(Spannenworte.kopf(.tag, anker: "2026-11-10", jetzt: mittag), "Heute")
        XCTAssertEqual(
            Spannenworte.kopf(.tag, anker: "2026-11-03", jetzt: mittag), "03.11.")
        XCTAssertEqual(
            Spannenworte.bis(anker: "2026-11-10", jetzt: mittag), "jeweils bis jetzt")
        XCTAssertEqual(
            Spannenworte.bis(anker: "2026-11-03", jetzt: mittag), "jeweils bis 03.11.2026")
        XCTAssertEqual(
            Wallbox.abdeckung(meta()),
            "Datenabdeckung 61\(Formate.schmalesLeerzeichen)% · Aufzeichnung seit 14.03.2026")
        XCTAssertEqual(
            Wallbox.abdeckung(meta(seit: nil, abdeckung: nil)),
            "noch keine Messdaten im Zeitraum")
    }

    func testDerErsparnissatzNenntBeideTeileDerSumme() {
        XCTAssertTrue(Pvbild.ersparnissatz.contains("PV direkt"))
        XCTAssertTrue(Pvbild.ersparnissatz.contains("Batterieentladung"))
    }

    // MARK: - Vier Spannen in einem Zug

    func testJeSpanneHoltAlleVierUndLaesstGescheiterteWeg() async {
        let aus: [Spanne: String] = await Pvbild.jeSpanne { s in
            s == .monat ? nil : s.rawValue
        }
        XCTAssertEqual(aus.count, 3)
        XCTAssertEqual(aus[.tag], "day")
        XCTAssertNil(aus[.monat])
        XCTAssertEqual(aus[.jahr], "year")
    }
}
