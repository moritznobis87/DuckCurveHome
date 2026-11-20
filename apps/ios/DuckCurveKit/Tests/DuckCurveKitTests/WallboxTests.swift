import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/EvReport.tsx`.
///
/// Geprüft wird, was gerechnet wird: die drei Schwellen der abgeleiteten Kennzahlen, die
/// Sortierung der Ladevorgänge, die Mindestdauer von einer Minute, die Rundung des
/// Spannenstreifens ab hundert Kilowattstunden und die Zeile, die auch zugeklappt dasteht.
final class WallboxTests: XCTestCase {

    private let anker = "2026-11-10"
    /// Der 10.11.2026 um 12 Uhr Hauszeit – „heute“ für alle Prüfungen mit Ankerbezug.
    private let jetzt = Zeit.ausIso("2026-11-10T12:00:00+01:00")!

    private func summen(
        geladen: Double? = 20.0, pv: Double? = 8.0, batterie: Double? = 4.0, netz: Double? = 8.0,
        bezahlt: Double? = 2.40, entgangen: Double? = 0.96
    ) -> EnergyTotalsOut {
        EnergyTotalsOut(
            evKwh: geladen, evPvKwh: pv, evBatteryKwh: batterie, evGridKwh: netz,
            evCostEur: bezahlt, evOpportunityEur: entgangen)
    }

    private func vorgang(
        von: String = "2026-11-10T18:42:00+01:00", bis: String = "2026-11-10T21:05:00+01:00",
        kwh: Double = 12.4, sonne: Double? = 0.35, netz: Double = 8.1, kosten: Double = 2.43,
        mittel: Double = 5.2
    ) -> EvSessionOut {
        EvSessionOut(
            start: von, end: bis, kwh: kwh, pvShare: sonne, gridKwh: netz, costEur: kosten,
            avgKw: mittel)
    }

    private func bericht(
        _ t: EnergyTotalsOut? = nil, vorgaenge: [EvSessionOut] = [],
        abdeckung: Double? = 0.61, seit: String? = "2026-11-10", hinweis: String = "Geschätzt."
    ) -> EvReportOut {
        EvReportOut(
            summary: EnergySummaryOut(
                period: .day, anchor: anker, start: "2026-11-10T00:00:00+01:00",
                end: "2026-11-11T00:00:00+01:00", totals: t ?? summen(),
                meta: EnergyMetaOut(
                    batteryCapacityKwh: 10, feedInCtKwh: 8.2, dataSince: seit,
                    coverage: abdeckung, estimatedNoteDe: hinweis)),
            sessions: vorgaenge)
    }

    // MARK: - Die sechs Kopfzahlen

    func testSechsKachelnInDerReihenfolgeDerVorlage() {
        let k = Wallbox.kacheln(bericht(vorgaenge: [vorgang()]))
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Geladen", "Sonnenanteil", "Aus dem Netz", "Bezahlt", "Entgangene Vergütung",
                "Effektiv je kWh",
            ])
        XCTAssertEqual(k.map(\.einheit), ["kWh", nil, "kWh", nil, nil, "ct"])
        XCTAssertEqual(
            k.map(\.ton), [.nebel, .bernstein, .glut, .glut, .gedaempft, .normal])
    }

    func testKachelnTragenDieZahlenUndHinweiseDerVorlage() {
        let k = Wallbox.kacheln(bericht(vorgaenge: [vorgang(), vorgang(von: "2026-11-09T07:00:00+01:00")]))
        XCTAssertEqual(k[0].wert, "20,0")
        XCTAssertEqual(k[0].dazu, "2 Ladevorgänge")
        // (8 + 4) / 20 = 60 %
        XCTAssertEqual(k[1].wert, "60\u{202F}%")
        XCTAssertEqual(k[1].dazu, "PV 8,0 · Batt. 4,0\u{202F}kWh")
        // 2,40 € auf 8 kWh Netz = 30,0 ct/kWh
        XCTAssertEqual(k[2].dazu, "Ø 30,0 ct/kWh bezahlt")
        XCTAssertEqual(k[3].wert, "2,40\u{202F}€")
        XCTAssertEqual(k[3].dazu, "Netzanteil × Strompreis")
        XCTAssertEqual(k[4].dazu, "nicht eingespeister PV-Strom")
        // (2,40 + 0,96) / 20 = 16,8 ct
        XCTAssertEqual(k[5].wert, "16,8")
        XCTAssertEqual(k[5].dazu, "bezahlt + entgangen")
    }

    /// Ein Zeitraum ohne Ladung: drei der sechs Zahlen sind keine, und das muss dastehen.
    func testOhneLadungStehenStricheUndKeinNetzbezug() {
        let leer = summen(geladen: 0, pv: 0, batterie: 0, netz: 0, bezahlt: 0, entgangen: 0)
        let k = Wallbox.kacheln(bericht(leer))
        XCTAssertEqual(k[0].wert, "0,0")
        XCTAssertEqual(k[0].dazu, "0 Ladevorgänge")
        XCTAssertEqual(k[1].wert, Formate.leer)
        XCTAssertEqual(k[2].dazu, "kein Netzbezug")
        XCTAssertEqual(k[5].wert, Formate.leer)
    }

    /// Fehlende Felder sind nicht Null, aber die Hinweiszeile muss trotzdem einen Satz ergeben.
    func testFehlendeFelderGebenStricheUndNullenImHinweis() {
        let nichts = EnergyTotalsOut()
        let k = Wallbox.kacheln(bericht(nichts))
        XCTAssertEqual(k[0].wert, Formate.leer)
        XCTAssertEqual(k[1].wert, Formate.leer)
        XCTAssertEqual(k[1].dazu, "PV 0,0 · Batt. 0,0\u{202F}kWh")
        XCTAssertEqual(k[2].wert, Formate.leer)
        XCTAssertEqual(k[2].dazu, "kein Netzbezug")
        XCTAssertEqual(k[3].wert, Formate.leer)
    }

    // MARK: - Die drei Schwellen

    func testSonnenanteilBrauchtEineGeladeneKilowattstunde() {
        XCTAssertNil(Wallbox.sonnenanteil(summen(geladen: 0)))
        XCTAssertNil(Wallbox.sonnenanteil(summen(geladen: nil)))
        XCTAssertEqual(Wallbox.sonnenanteil(summen(geladen: 20, pv: 8, batterie: 4)) ?? 0, 0.6, accuracy: 1e-9)
        // Auch eine winzige Ladung hat einen Anteil: die Schwelle ist > 0, nicht > 0,01.
        XCTAssertEqual(
            Wallbox.sonnenanteil(summen(geladen: 0.004, pv: 0.004, batterie: 0)) ?? 0, 1.0,
            accuracy: 1e-9)
    }

    func testBezahlterPreisErstUeberHundertstelKilowattstunde() {
        XCTAssertNil(Wallbox.bezahltCt(summen(netz: 0.01)))
        XCTAssertNil(Wallbox.bezahltCt(summen(netz: 0)))
        XCTAssertNil(Wallbox.bezahltCt(summen(netz: nil)))
        XCTAssertEqual(Wallbox.bezahltCt(summen(netz: 0.02, bezahlt: 0.006)) ?? 0, 30.0, accuracy: 1e-9)
    }

    func testEffektivpreisErstUeberHundertstelKilowattstunde() {
        XCTAssertNil(Wallbox.effektivCt(summen(geladen: 0.01)))
        XCTAssertNil(Wallbox.effektivCt(summen(geladen: nil)))
        // Die Schwelle des Sonnenanteils ist milder als diese: 0,005 kWh hat einen Anteil,
        // aber keinen Effektivpreis.
        XCTAssertNotNil(Wallbox.sonnenanteil(summen(geladen: 0.005)))
        XCTAssertNil(Wallbox.effektivCt(summen(geladen: 0.005)))
        XCTAssertEqual(
            Wallbox.effektivCt(summen(geladen: 20, bezahlt: 2.40, entgangen: 0.96)) ?? 0, 16.8,
            accuracy: 1e-9)
    }

    // MARK: - Die Ladevorgänge

    func testVorgaengeStehenNeuesteZuerst() {
        let b = bericht(vorgaenge: [
            vorgang(von: "2026-11-08T07:00:00+01:00", bis: "2026-11-08T08:00:00+01:00"),
            vorgang(von: "2026-11-10T18:42:00+01:00", bis: "2026-11-10T21:05:00+01:00"),
            vorgang(von: "2026-11-09T22:10:00+01:00", bis: "2026-11-09T23:30:00+01:00"),
        ])
        XCTAssertEqual(
            Wallbox.vorgaenge(b).map(\.start),
            [
                "2026-11-10T18:42:00+01:00", "2026-11-09T22:10:00+01:00",
                "2026-11-08T07:00:00+01:00",
            ])
    }

    func testBeginnTraegtDenTagUndAmTelefonOhneWochentag() {
        let z = Wallbox.vorgaenge(bericht(vorgaenge: [vorgang()]))[0]
        XCTAssertEqual(z.beginn, "Di, 10.11. 18:42")
        XCTAssertEqual(z.kurzerBeginn, "10.11. 18:42")
    }

    func testDauerAusDifferenzUndMindestensEineMinute() {
        XCTAssertEqual(
            Wallbox.minuten(
                von: "2026-11-10T18:42:00+01:00", bis: "2026-11-10T21:05:00+01:00"), 143)
        // Beginn gleich Ende: eine Minute, keine Null.
        XCTAssertEqual(
            Wallbox.minuten(
                von: "2026-11-10T18:42:00+01:00", bis: "2026-11-10T18:42:00+01:00"), 1)
        // Unter dreißig Sekunden wird auf null gerundet - und dann auf eins gehoben.
        XCTAssertEqual(
            Wallbox.minuten(
                von: "2026-11-10T18:42:00+01:00", bis: "2026-11-10T18:42:20+01:00"), 1)
        // Ein unlesbarer Zeitstempel gibt keine Dauer her.
        XCTAssertNil(Wallbox.minuten(von: "gestern", bis: "2026-11-10T21:05:00+01:00"))
    }

    func testDauerAlsWortUeberUndUnterEinerStunde() {
        let kurz = Wallbox.vorgaenge(
            bericht(vorgaenge: [
                vorgang(von: "2026-11-10T18:42:00+01:00", bis: "2026-11-10T19:24:00+01:00")
            ]))[0]
        XCTAssertEqual(kurz.dauer, "42\u{202F}min")
        let lang = Wallbox.vorgaenge(bericht(vorgaenge: [vorgang()]))[0]
        XCTAssertEqual(lang.dauer, "2\u{202F}h 23\u{202F}min")
        let kaputt = Wallbox.vorgaenge(
            bericht(vorgaenge: [vorgang(von: "2026-11-10T18:42:00+01:00", bis: "irgendwann")]))[0]
        XCTAssertEqual(kaputt.dauer, Formate.leer)
    }

    func testBezahltFaelltErstUeberEinemHalbenCentAuf() {
        func auffaellig(_ kosten: Double) -> Bool {
            Wallbox.vorgaenge(bericht(vorgaenge: [vorgang(kosten: kosten)]))[0].bezahltAuffaellig
        }
        XCTAssertFalse(auffaellig(0))
        XCTAssertFalse(auffaellig(0.005))
        XCTAssertTrue(auffaellig(0.006))
    }

    func testZellenDerTabelleTragenIhreEinheiten() {
        let z = Wallbox.vorgaenge(bericht(vorgaenge: [vorgang()]))[0]
        XCTAssertEqual(z.energie, "12,4\u{202F}kWh")
        XCTAssertEqual(z.leistung, "5,2\u{202F}kW")
        XCTAssertEqual(z.sonnenanteil, "35\u{202F}%")
        XCTAssertEqual(z.netz, "8,1\u{202F}kWh")
        XCTAssertEqual(z.bezahlt, "2,43\u{202F}€")
    }

    /// `pv_share` ist wahlfrei: ein Vorgang ohne Preiszeitreihe hat keinen Anteil.
    func testFehlenderSonnenanteilGibtEinenStrich() {
        let z = Wallbox.vorgaenge(bericht(vorgaenge: [vorgang(sonne: nil)]))[0]
        XCTAssertEqual(z.sonnenanteil, Formate.leer)
    }

    func testKeineVorgaengeGibtKeineZeilen() {
        XCTAssertTrue(Wallbox.vorgaenge(bericht()).isEmpty)
    }

    func testKopfzeileDerLadevorgangskarte() {
        XCTAssertEqual(Wallbox.kopfzeile(anzahl: 0), "keine im Zeitraum")
        XCTAssertEqual(Wallbox.kopfzeile(anzahl: 1), "1 im Zeitraum")
        XCTAssertEqual(Wallbox.kopfzeile(anzahl: 17), "17 im Zeitraum")
    }

    // MARK: - Wallbox im Überblick

    func testSpannenzeilenVierZeilenUndVierSpalten() {
        let je: [Spanne: EvReportOut] = [
            .tag: bericht(summen(geladen: 12.4), vorgaenge: [vorgang()]),
            .woche: bericht(summen(geladen: 64.2)),
            .monat: bericht(summen(geladen: 212.7)),
            .jahr: bericht(summen(geladen: 1284.3)),
        ]
        let zeilen = Wallbox.spannenzeilen(je)
        XCTAssertEqual(
            zeilen.map(\.wort), ["Geladen · kWh", "Sonnenanteil", "Bezahlt", "Ladevorgänge"])
        XCTAssertEqual(zeilen.map(\.ton), [.nebel, .bernstein, .glut, .normal])
        XCTAssertEqual(zeilen.map { $0.werte.count }, [4, 4, 4, 4])
        XCTAssertEqual(zeilen[3].werte, ["1", "0", "0", "0"])
    }

    /// **Ab hundert Kilowattstunden ohne Nachkommastelle** (`EvReport.tsx:95`).
    func testGeladenRundetAbHundertAufGanzeZahlen() {
        XCTAssertEqual(Wallbox.geladenKurz(summen(geladen: 99.94)), "99,9")
        XCTAssertEqual(Wallbox.geladenKurz(summen(geladen: 100)), "100")
        XCTAssertEqual(Wallbox.geladenKurz(summen(geladen: 1284.3)), "1284")
        XCTAssertEqual(Wallbox.geladenKurz(summen(geladen: nil)), Formate.leer)
    }

    func testFehlendeSpanneStehtAlsStrich() {
        let je: [Spanne: EvReportOut] = [.tag: bericht(), .jahr: bericht()]
        let zeilen = Wallbox.spannenzeilen(je)
        // Reihenfolge der Spalten ist Spanne.allCases: Tag, Woche, Monat, Jahr.
        XCTAssertEqual(zeilen[0].werte[1], Formate.leer)
        XCTAssertEqual(zeilen[0].werte[2], Formate.leer)
        XCTAssertEqual(zeilen[0].werte[0], "20,0")
        XCTAssertEqual(zeilen[0].werte[3], "20,0")
    }

    func testOhneJedeSpanneStehenNurStriche() {
        let zeilen = Wallbox.spannenzeilen([:])
        XCTAssertEqual(zeilen.count, 4)
        for z in zeilen {
            XCTAssertEqual(z.werte, Array(repeating: Formate.leer, count: 4))
        }
    }

    // MARK: - Spaltenköpfe und Bezug des Streifens

    func testTagesspalteHeisstNurHeuteWennSieEsIst() {
        XCTAssertEqual(Spannenworte.kopf(.tag, anker: "2026-11-10", jetzt: jetzt), "Heute")
        XCTAssertEqual(Spannenworte.kopf(.tag, anker: "2026-11-03", jetzt: jetzt), "03.11.")
        XCTAssertEqual(Spannenworte.kopf(.woche, anker: "2026-11-03", jetzt: jetzt), "Woche")
        XCTAssertEqual(Spannenworte.kopf(.monat, anker: "2026-11-10", jetzt: jetzt), "Monat")
        XCTAssertEqual(Spannenworte.kopf(.jahr, anker: "2026-11-10", jetzt: jetzt), "Jahr")
    }

    func testBezugDerSpaltenImKartenkopf() {
        XCTAssertEqual(Spannenworte.bis(anker: "2026-11-10", jetzt: jetzt), "jeweils bis jetzt")
        XCTAssertEqual(
            Spannenworte.bis(anker: "2026-11-03", jetzt: jetzt), "jeweils bis 03.11.2026")
    }

    func testZifferndatumUndWasKeinesIst() {
        XCTAssertEqual(Spannenworte.zifferndatum("2026-11-10"), "10.11.2026")
        XCTAssertEqual(Spannenworte.zifferndatum("2026-01-07"), "07.01.2026")
        XCTAssertEqual(Spannenworte.zifferndatum("irgendwann"), "irgendwann")
    }

    // MARK: - Was die Seite über sich selbst sagt

    func testAbdeckungssatzMitProzentUndJahr() {
        XCTAssertEqual(
            Wallbox.abdeckung(bericht().summary.meta),
            "Datenabdeckung 61\u{202F}% · Aufzeichnung seit 10.11.2026")
    }

    /// Null ist eine Messung, `nil` ist keine - und die Vorlage unterscheidet sie.
    func testAbdeckungUnterscheidetNullVonFehlend() {
        let fehlt = bericht(abdeckung: nil, seit: nil).summary.meta
        XCTAssertEqual(Wallbox.abdeckung(fehlt), "noch keine Messdaten im Zeitraum")
        let null = bericht(abdeckung: 0, seit: nil).summary.meta
        XCTAssertEqual(Wallbox.abdeckung(null), "Datenabdeckung 0\u{202F}%")
    }

    func testAbdeckungLaesstUnbrauchbaresDatumWeg() {
        let krumm = bericht(abdeckung: 0.9, seit: "2026-02-30").summary.meta
        XCTAssertEqual(Wallbox.abdeckung(krumm), "Datenabdeckung 90\u{202F}%")
        // Ein Zeitstempel statt eines Tages wird auf den Tag gekürzt und bleibt brauchbar.
        let lang = bericht(abdeckung: 0.9, seit: "2026-11-10T00:00:00+01:00").summary.meta
        XCTAssertEqual(Wallbox.abdeckung(lang), "Datenabdeckung 90\u{202F}% · Aufzeichnung seit 10.11.2026")
    }

    func testLadevorgangssatzStehtWoertlichDa() {
        XCTAssertEqual(
            Wallbox.ladevorgangssatz,
            "Ein Ladevorgang beginnt ab 0,3 kW Wallboxleistung und endet nach 5 Minuten Pause; "
                + "Vorgänge unter 0,2 kWh werden nicht gezählt.")
    }
}
