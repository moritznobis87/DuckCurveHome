import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/DataCheck.tsx` mit `charts.ts`,
/// `Sources.tsx` und `CoverageMap.tsx`.
final class DatenbildTests: XCTestCase {

    private let tagIso = "2026-11-10"
    private var anfang: Date { Tag.zeitraum("2026-11-10")!.von }
    private var jetzt: Date { anfang.addingTimeInterval(12 * 3600) }

    private func zeit(_ minute: Int) -> Date {
        anfang.addingTimeInterval(Double(minute) * 60)
    }

    private func punkt(
        _ minute: Int, pv: Double? = nil, netz: Double? = nil, zaehler: Double? = nil,
        speicher: Double? = nil, soc: Double? = nil
    ) -> Pruefpunkt {
        Pruefpunkt(
            zeit: zeit(minute), pv: pv, netz: netz, netzZaehler: zaehler, speicher: speicher,
            ladestand: soc)
    }

    private func kurve(_ punkte: [Pruefpunkt]) -> Pruefkurve {
        Pruefkurve.baue(tag: tagIso, raster: punkte)
    }

    // MARK: - Der Hausverbrauch ist eine Bilanz, keine Messung

    func testDerHausverbrauchFolgtAusDerBilanzUndNichtAusDemGemeldetenWert() {
        let zeile: [String: Mischwert] = [
            "ts": .text(Zeit.iso(zeit(10))),
            "pv_power_kw": 3.0,
            "grid_power_kw": 1.0,
            "battery_power_kw": 0.5,
            "house_power_kw": 9.9,
        ]
        let k = kurve(Pruefpunkt.raster([zeile]))
        XCTAssertEqual(
            k.haus.first?.wert, 4.5,
            "Haus = PV + Netz + Speicher; `house_power_kw` käme aus der Quelle, die geprüft wird.")
    }

    func testOhneErzeugungOderNetzwertGibtEsKeinenHausverbrauch() {
        let k = kurve([
            punkt(0, pv: nil, netz: 1, speicher: 1),
            punkt(1, pv: 1, netz: nil, speicher: 1),
            punkt(2, pv: 1, netz: 1, speicher: 1),
        ])
        XCTAssertEqual(k.haus.count, 1, "Eine halbe Bilanz ist keine.")
        XCTAssertEqual(k.haus.first?.wert, 3)
    }

    func testDerSpeicherDarfInDerBilanzFehlenUndZaehltDannAlsNull() {
        let k = kurve([punkt(0, pv: 2, netz: 1)])
        XCTAssertEqual(k.haus.first?.wert, 3)
    }

    func testDieBilanzWirdNichtNegativ() {
        let k = kurve([punkt(0, pv: 4, netz: -5, speicher: 0)])
        XCTAssertEqual(
            k.haus.first?.wert, 0, "Ein Haus, das Strom erzeugt, gibt es in dieser Bilanz nicht.")
    }

    func testDerLadestandStehtInProzentUndNichtAlsAnteil() {
        let k = kurve([punkt(0, soc: 0.42)])
        XCTAssertEqual(k.ladestand.first?.wert, 42)
    }

    // MARK: - Was aus der Historie gelesen wird

    func testEineZeileOhneLesbarenZeitstempelFaelltAusDemRaster() {
        let gut: [String: Mischwert] = ["ts": .text(Zeit.iso(zeit(5))), "pv_power_kw": 1.0]
        let ohne: [String: Mischwert] = ["pv_power_kw": 1.0]
        let kaputt: [String: Mischwert] = ["ts": .text("gestern"), "pv_power_kw": 1.0]
        XCTAssertEqual(Pruefpunkt.raster([gut, ohne, kaputt]).count, 1)
    }

    func testDerZaehlerWirdAlsEigeneReiheGelesenUndNichtMitDemWandlerVerwechselt() {
        let zeile: [String: Mischwert] = [
            "ts": .text(Zeit.iso(zeit(1))), "grid_power_kw": 2.0, "grid_power_meter_kw": 2.4,
        ]
        let p = Pruefpunkt.ausZeile(zeile)
        XCTAssertEqual(p?.netz, 2.0)
        XCTAssertEqual(p?.netzZaehler, 2.4)
    }

    func testPunkteAusserhalbDesTagesFallenWeg() {
        let k = kurve([punkt(-30, pv: 1), punkt(10, pv: 1), punkt(24 * 60 + 5, pv: 1)])
        XCTAssertEqual(k.pv.count, 1)
        XCTAssertEqual(k.pv.first?.stunde ?? -1, 10.0 / 60, accuracy: 1e-9)
    }

    func testEineUnsortierteHistorieWirdAufsteigendGezeichnet() {
        let k = kurve([punkt(120, pv: 3), punkt(10, pv: 1), punkt(60, pv: 2)])
        XCTAssertEqual(k.pv.map(\.wert), [1, 2, 3], "Sonst läuft die Linie quer durch den Tag zurück.")
    }

    func testOhneZeilenIstDieKurveLeerUndDieAchseTrotzdemZeichenbar() {
        let k = kurve([])
        XCTAssertTrue(k.leer)
        XCTAssertEqual(k.leistungsspanne, Pruefkurve.mindestspanne)
        XCTAssertEqual(k.fenster, 0...24)
        XCTAssertNil(k.luecken())
    }

    func testEinUnbekannterTagGibtEineLeereKurveUndKeinenAbsturz() {
        XCTAssertTrue(Pruefkurve.baue(tag: "2026-02-30", raster: [punkt(0, pv: 1)]).leer)
    }

    // MARK: - Die Leistungsachse

    func testDieLeistungsachseReichtUeberDieNullHinweg() {
        let k = kurve([punkt(0, pv: 6, netz: -4, speicher: -3)])
        XCTAssertLessThan(
            k.leistungsspanne.lowerBound, -4, "Einspeisung und Laden liegen unter der Nulllinie.")
        XCTAssertGreaterThan(k.leistungsspanne.upperBound, 6)
    }

    func testEinRuhigerTagBekommtDieMindestspanneUndKeineZappelnDeAchse() {
        let k = kurve([punkt(0, pv: 0.2, netz: -0.3, speicher: 0.1)])
        XCTAssertEqual(k.leistungsspanne, Pruefkurve.mindestspanne)
    }

    func testDerLadestandHaengtNichtAnDerLeistungsachse() {
        let mitLadestand = kurve([punkt(0, pv: 1, soc: 1.0)])
        let ohne = kurve([punkt(0, pv: 1)])
        XCTAssertEqual(
            mitLadestand.leistungsspanne, ohne.leistungsspanne,
            "100 Prozent sind keine 100 Kilowatt.")
    }

    func testDieProzentachseTrifftDurchDieNegativeSpanneHindurch() {
        let k = kurve([punkt(0, pv: 6, netz: -4)])
        let s = k.leistungsspanne
        XCTAssertEqual(k.ladestandAufLeistung(0), s.lowerBound, accuracy: 1e-9)
        XCTAssertEqual(k.ladestandAufLeistung(100), s.upperBound, accuracy: 1e-9)
        XCTAssertEqual(
            k.ladestandAufLeistung(50), (s.lowerBound + s.upperBound) / 2, accuracy: 1e-9)
        XCTAssertLessThan(
            k.ladestandAufLeistung(0), 0,
            "Null Prozent gehören an den unteren Rand und nicht auf die Nulllinie.")
        for marke in Pruefkurve.ladestandsmarken {
            XCTAssertEqual(
                k.leistungAufLadestand(k.ladestandAufLeistung(marke)), marke, accuracy: 1e-9)
        }
    }

    // MARK: - Das Zeitfenster

    func testDerAusschnittBeschneidetDieReihenUndRechnetDieAchseNeu() {
        let k = kurve([punkt(0, pv: 0.5), punkt(30, pv: 0.5), punkt(120, pv: 9)])
        let aus = k.ausschnitt(von: 0, bis: 1)
        XCTAssertEqual(aus.pv.count, 2)
        XCTAssertEqual(aus.fenster, 0...1)
        XCTAssertLessThan(
            aus.leistungsspanne.upperBound, k.leistungsspanne.upperBound,
            "Ohne mitgehende Achse bleibt eine Viertelstunde mit 0,5 kW ein flacher Strich.")
    }

    func testEinAusschnittOhneBreiteGibtDenGanzenTagZurueck() {
        let k = kurve([punkt(0, pv: 1), punkt(600, pv: 5)])
        XCTAssertEqual(k.ausschnitt(von: 3, bis: 3).pv.count, 2)
        XCTAssertEqual(k.ausschnitt(von: 3, bis: 3).fenster, 0...24)
    }

    func testEinVerdrehtesFensterMeintDasselbeWieEinRichtiges() {
        let k = kurve([punkt(0, pv: 1), punkt(120, pv: 5), punkt(600, pv: 5)])
        XCTAssertEqual(k.ausschnitt(von: 3, bis: 1).pv.count, k.ausschnitt(von: 1, bis: 3).pv.count)
        XCTAssertEqual(k.ausschnitt(von: 3, bis: 1).fenster, 1...3)
    }

    func testDasFensterBleibtImTag() {
        let k = kurve([punkt(0, pv: 1)])
        XCTAssertEqual(k.ausschnitt(von: -5, bis: 99).fenster, 0...24)
    }

    // MARK: - Lücken und Takte

    func testDerZaehlerBehaeltSeinenEigenenTaktUndWirdVerbundenGezeichnet() {
        let punkte = (0..<60).map { m in
            punkt(m, netz: 1, zaehler: m % 15 == 0 ? 1.2 : nil)
        }
        let k = kurve(punkte)
        XCTAssertEqual(k.netz.count, 60)
        XCTAssertEqual(k.netzZaehler.count, 4, "Der Zähler meldet alle rund fünfzehn Minuten.")
        XCTAssertTrue(Pruefkurve.Reihe.netzZaehler.verbunden)
        XCTAssertEqual(
            Pruefkurve.Reihe.allCases.filter(\.verbunden), [.netzZaehler],
            "Jede andere Reihe muss ihre Lücken zeigen.")
    }

    func testStreckenTrennenEineReiheNurAnEinerEchtenLuecke() {
        let punkte = (0..<10).map { punkt($0, pv: 1) } + (30..<40).map { punkt($0, pv: 1) }
        let k = kurve(punkte)
        let strecken = Pruefkurve.strecken(k.pv)
        XCTAssertEqual(strecken.count, 2, "Zwanzig fehlende Minuten sind keine Messung.")
        XCTAssertEqual(strecken.map(\.count), [10, 10])
    }

    func testEineLueckenloseReiheBleibtEineStrecke() {
        let k = kurve((0..<30).map { punkt($0, pv: 1) })
        XCTAssertEqual(Pruefkurve.strecken(k.pv).count, 1)
    }

    func testEineEinzelneFehlendeMinuteTrenntDieLinieNicht() {
        let punkte = (0..<10).filter { $0 != 4 }.map { punkt($0, pv: 1) }
        let k = kurve(punkte)
        XCTAssertEqual(
            Pruefkurve.strecken(k.pv).count, 1, "Ein verschlucktes Paket ist kein Ausfall.")
    }

    // MARK: - Die Nullen in der Erzeugungsreihe

    private var tagMitLuecke: [Pruefpunkt] {
        // Nacht ohne Erzeugung, Tag von 6 bis 18 Uhr, darin fünf Minuten auf genau null.
        var punkte: [Pruefpunkt] = []
        for m in stride(from: 0, to: 24 * 60, by: 1) {
            let tags = m >= 6 * 60 && m <= 18 * 60
            let loch = m >= 700 && m < 705
            punkte.append(punkt(m, pv: tags && !loch ? 2 : 0, netz: 1))
        }
        return punkte
    }

    func testDieNullenZaehlenNurZwischenErsterUndLetzterErzeugungsminute() {
        let luecke = kurve(tagMitLuecke).luecken()
        XCTAssertEqual(luecke?.minuten, 5, "Die Nacht ist keine Lücke, sondern eine Nacht.")
        XCTAssertEqual(luecke?.von ?? -1, 6, accuracy: 1e-9)
        XCTAssertEqual(luecke?.bis ?? -1, 18, accuracy: 1e-9)
        XCTAssertEqual(luecke?.befund, .luecke)
    }

    func testBewegtSichDerNetzwertInDerLueckeIstDerBefundDeutlicher() {
        let punkte = tagMitLuecke.enumerated().map { i, p in
            Pruefpunkt(
                zeit: p.zeit, pv: p.pv, netz: 1 + Double(i % 7) * 0.1, netzZaehler: nil,
                speicher: nil, ladestand: nil)
        }
        let luecke = kurve(punkte).luecken()
        XCTAssertEqual(luecke?.minuten, 5)
        XCTAssertTrue(luecke?.netzBewegtSich == true)
        XCTAssertEqual(
            luecke?.befund, .lueckeMitNetzbewegung,
            "Dann liefert der Zähler und die Erzeugungsmessung nicht.")
    }

    func testEinTagOhneNullenMeldetKeineLuecke() {
        let punkte = (6 * 60...18 * 60).map { punkt($0, pv: 2, netz: 1) }
        XCTAssertEqual(kurve(punkte).luecken()?.befund, .keine)
    }

    func testEineEinzigeErzeugungsminuteIstKeineStrecke() {
        XCTAssertNil(kurve([punkt(600, pv: 2), punkt(601, pv: 0)]).luecken())
    }

    func testEinWertKnappUeberNullZaehltNichtAlsNull() {
        let punkte = [
            punkt(600, pv: 2, netz: 1), punkt(601, pv: 0.02, netz: 1), punkt(602, pv: 2, netz: 1),
        ]
        XCTAssertEqual(
            kurve(punkte).luecken()?.minuten, 0,
            "0,02 kW schreibt die Anzeige als 0,02 und nicht als 0,00.")
    }

    // MARK: - Verdichten

    func testVerdichtenMitteltUndLaesstDieReiheAufsteigend() {
        let k = kurve((0..<60).map { punkt($0, pv: Double($0)) })
        let grob = k.verdichtet(schrittMin: 5)
        XCTAssertEqual(grob.pv.count, 12)
        XCTAssertEqual(grob.pv.map(\.stunde), grob.pv.map(\.stunde).sorted())
        XCTAssertEqual(grob.pv.first?.wert ?? -1, 2, accuracy: 1e-9, "Mittel von 0 bis 4.")
        XCTAssertEqual(grob.pv[1].wert, 7, accuracy: 1e-9)
        XCTAssertEqual(grob.pv[1].stunde, 5.0 / 60, accuracy: 1e-9)
    }

    func testVerdichtenSchiebtKeinenPunktInDenKastenDavor() {
        let grob = Pruefkurve.verdichte(
            (0..<60).map { Kurvenpunkt(stunde: Double($0) / 60, wert: Double($0)) },
            schrittMin: 5)
        XCTAssertEqual(grob.map(\.wert), (0..<12).map { Double($0) * 5 + 2 })
    }

    func testVerdichtenMitSchrittEinsLaesstDieReiheWieSieIst() {
        let k = kurve((0..<10).map { punkt($0, pv: 1) })
        XCTAssertEqual(k.verdichtet(schrittMin: 1).pv, k.pv)
    }

    // MARK: - Die Legende

    func testDieLegendeStehtInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            kurve([]).legende.map(\.name),
            ["PV", "Haus", "Netz", "Netz (Zähler)", "Speicher", "Ladestand %"])
    }

    func testNurDieBeidenGegenprobenSindGestrichelt() {
        XCTAssertEqual(
            Pruefkurve.Reihe.allCases.filter(\.gestrichelt), [.netzZaehler, .ladestand])
        XCTAssertEqual(Pruefkurve.Reihe.allCases.filter(\.rechteAchse), [.ladestand])
    }

    func testJedeReiheGibtIhreEigenenPunkte() {
        let k = kurve([punkt(0, pv: 1, netz: 2, zaehler: 3, speicher: 4, soc: 0.5)])
        XCTAssertEqual(k.punkte(.pv).first?.wert, 1)
        XCTAssertEqual(k.punkte(.netz).first?.wert, 2)
        XCTAssertEqual(k.punkte(.netzZaehler).first?.wert, 3)
        XCTAssertEqual(k.punkte(.speicher).first?.wert, 4)
        XCTAssertEqual(k.punkte(.ladestand).first?.wert, 50)
        XCTAssertEqual(k.punkte(.haus).first?.wert, 7)
        XCTAssertEqual(k.leistungsreihen.count, 5, "Der Ladestand liegt nicht auf dieser Achse.")
    }

    // MARK: - Quellen

    private func system(
        schaltet: Bool? = true, satz: String? = "Das Haus schaltet selbst.",
        quellen: [SourceStatusOut] = []
    ) -> SystemStatusOut {
        SystemStatusOut(
            mode: "live", serverTime: Zeit.iso(jetzt), simSpeed: 1, bridgeOnline: true,
            sseClients: 1, version: "1", connectionLabelDe: "verbunden", sources: quellen,
            watch: [], outdoorShownC: nil, outdoorSourceDe: nil, hpActuation: schaltet,
            hpActuationDe: satz)
    }

    func testDieVollmachtStehtVorDenQuellen() {
        let zeilen = Quellenstand.zeilen(
            aus: system(quellen: [SourceStatusOut(name: "bridge", online: true)]))
        XCTAssertEqual(zeilen.first?.name, Quellenstand.vollmacht)
        XCTAssertEqual(zeilen.count, 2)
    }

    func testDieVollmachtsZeileNenntDieZweiSicherungen() {
        let zeile = Quellenstand.zeilen(aus: system(schaltet: true)).first
        XCTAssertEqual(zeile?.ton, .ok)
        XCTAssertEqual(
            zeile?.satz, "Das Haus schaltet selbst. · " + Quellenstand.schaltetSatz)
    }

    func testOhneVollmachtSagtDieZeileDassNichtsGeschaltetWird() {
        let zeile = Quellenstand.zeilen(aus: system(schaltet: false)).first
        XCTAssertEqual(zeile?.ton, .still, "Keine Vollmacht ist kein Alarm.")
        XCTAssertEqual(
            zeile?.satz, "Das Haus schaltet selbst. · " + Quellenstand.schaltetNichtSatz)
    }

    func testOhneSatzDesDienstesStehtDerZusatzAlleinUndOhneTrennzeichen() {
        let zeile = Quellenstand.zeilen(aus: system(schaltet: false, satz: nil)).first
        XCTAssertEqual(zeile?.satz, Quellenstand.schaltetNichtSatz)
    }

    func testDerNameDerQuelleKommtAusDerTabelleUndEinUnbekannterBleibtWieErIst() {
        XCTAssertEqual(Quellenstand.name("bridge"), "Haus (Bridge)")
        XCTAssertEqual(Quellenstand.name("myenergi"), "myenergi (Libbi, Wallbox)")
        XCTAssertEqual(Quellenstand.name("inexogy"), "Zähler (inexogy)")
        XCTAssertEqual(
            Quellenstand.name("fronius"), "fronius", "Eine neue Quelle soll auftauchen.")
    }

    func testEineQuelleDieNichtAntwortetSchlaegtAlarmUndNenntIhrenSatz() {
        let zeilen = Quellenstand.zeilen(
            aus: system(quellen: [
                SourceStatusOut(name: "inexogy", online: false, detailDe: "seit 20 min still"),
                SourceStatusOut(name: "myenergi", online: true, detailDe: "4 Abfragen"),
            ]))
        XCTAssertEqual(zeilen.map(\.ton), [.ok, .alarm, .ok])
        XCTAssertEqual(zeilen[1].name, "Zähler (inexogy)")
        XCTAssertEqual(zeilen[1].satz, "seit 20 min still")
    }

    func testOhneZustandGibtEsKeineEinzigeZeile() {
        XCTAssertTrue(
            Quellenstand.zeilen(aus: nil).isEmpty,
            "„Es wird nichts geschaltet\" wäre ohne Antwort eine Behauptung.")
    }

    // MARK: - Verfügbarkeit

    private func reihe(
        stunden: [(String, Int)], abdeckung: Double = 1, unvollstaendig: Int = 0,
        ausfall: Int = 0, zuletzt: String? = nil
    ) -> CoverageSeriesOut {
        CoverageSeriesOut(
            key: "zaehler", labelDe: "Zähler (inexogy)",
            hours: stunden.map { [.text($0.0), .ganz($0.1)] }, coverage: abdeckung,
            minutesSeen: 0, minutesExpected: 0, incompleteHours: unvollstaendig,
            longestOutageH: ausfall, lastAt: zuletzt)
    }

    func testDasRasterHatEineSpalteJeTagUndVierundzwanzigStunden() {
        let tage = Abdeckungsraster.tageZwischen("2026-11-08T00:00:00+01:00", "2026-11-11T00:00:00+01:00")
        XCTAssertEqual(tage, ["2026-11-08", "2026-11-09", "2026-11-10"])
        let r = Abdeckungsraster.baue(reihe(stunden: [("2026-11-09T07:00:00", 60)]), tage: tage)
        XCTAssertEqual(r.tage.count, 3)
        XCTAssertTrue(r.tage.allSatisfy { $0.stunden.count == 24 })
        XCTAssertEqual(r.tage[1].stunden[7], 60)
    }

    func testEineStundeOhneMinutenzeileIstLeerUndNichtNull() {
        let tage = Abdeckungsraster.tageZwischen("2026-11-10T00:00:00+01:00", "2026-11-11T00:00:00+01:00")
        let r = Abdeckungsraster.baue(
            reihe(stunden: [("2026-11-10T03:00:00", 0), ("2026-11-10T04:00:00", 60)]), tage: tage)
        XCTAssertEqual(r.tage[0].stunden[3], 0, "Minutenzeilen sind da, die Reihe fehlt darin.")
        XCTAssertNil(r.tage[0].stunden[5], "Hier stand der Dienst still - das ist unser Ausfall.")
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: r.tage[0].stunden[3]), .fehlend)
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: r.tage[0].stunden[5]), .leer)
    }

    func testEinZeitraumOhneTageGibtEinLeeresRaster() {
        XCTAssertTrue(Abdeckungsraster.tageZwischen("2026-11-10T00:00:00", "2026-11-10T00:00:00").isEmpty)
        XCTAssertTrue(Abdeckungsraster.tageZwischen("heute", "morgen").isEmpty)
        let r = Abdeckungsraster.baue(reihe(stunden: []), tage: [])
        XCTAssertTrue(r.tage.isEmpty)
    }

    func testEineUnbrauchbareStundenangabeWirdUebersprungen() {
        let tage = ["2026-11-10"]
        let r = Abdeckungsraster.baue(
            CoverageSeriesOut(
                key: "k", labelDe: "K",
                hours: [[.text("2026-11-10T05:00:00")], [.text("2026-11-10T06:00:00"), .ganz(12)]],
                coverage: 1, minutesSeen: 0, minutesExpected: 0, incompleteHours: 0,
                longestOutageH: 0),
            tage: tage)
        XCTAssertNil(r.tage[0].stunden[5])
        XCTAssertEqual(r.tage[0].stunden[6], 12)
    }

    func testDieStufenTeilenDieMinutenInDerMitteZwischenDenRampenstopps() {
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: 14), .fehlend)
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: 15), .teils)
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: 44), .teils)
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: 45), .voll)
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: 60), .voll)
        XCTAssertEqual(
            Abdeckungsraster.stufe(minuten: 55), .voll,
            "Eine Stunde mit 55 von 60 Minuten ist etwas anderes als eine mit 5.")
        XCTAssertEqual(Abdeckungsraster.stufe(minuten: 5), .fehlend)
    }

    /// Die Zellfarbe: `nil` bleibt `nil`, und die Enden der Rampe liegen bei 0 und 60 Minuten.
    func testEineStundeOhneMinutenzeileBekommtKeineFarbe() {
        XCTAssertNil(
            Abdeckungsraster.farbe(minuten: nil),
            "Ohne Minutenzeile stand der Dienst still - das ist eine andere Auskunft als null "
                + "Minuten, und darum keine Farbe und nicht die rote.")
        XCTAssertEqual(Abdeckungsraster.farbe(minuten: 0), Marken.abdeckungFehlend)
        XCTAssertEqual(Abdeckungsraster.farbe(minuten: 30), Marken.abdeckungTeils)
        XCTAssertEqual(Abdeckungsraster.farbe(minuten: 60), Marken.abdeckungVoll)
    }

    /// Die Skala ist fest: mehr als sechzig Minuten gibt es nicht, und nichts darunter faellt
    /// aus der Rampe.
    func testDieZellfarbeHaeltSichAnDieFesteSkalaVonNullBisSechzig() {
        XCTAssertEqual(Abdeckungsraster.farbe(minuten: 90), Marken.abdeckungVoll)
        XCTAssertEqual(Abdeckungsraster.farbe(minuten: -5), Marken.abdeckungFehlend)
        // 55 und 48 Minuten muessen sich unterscheiden - genau dafuer ist die Skala stetig.
        XCTAssertNotEqual(
            Abdeckungsraster.farbe(minuten: 55), Abdeckungsraster.farbe(minuten: 48))
    }

    func testAlleReihenDerAntwortKommenAufDasselbeRasterDerTage() {
        let antwort = CoverageOut(
            start: "2026-11-09T00:00:00+01:00", end: "2026-11-11T00:00:00+01:00",
            series: [reihe(stunden: []), reihe(stunden: [])], noteDe: "Note")
        let raster = Abdeckungsraster.baue(antwort)
        XCTAssertEqual(raster.count, 2)
        XCTAssertEqual(raster.map { $0.tage.map(\.tag) }, [["2026-11-09", "2026-11-10"], ["2026-11-09", "2026-11-10"]])
    }

    // MARK: - Die Kopfzeile der Verfügbarkeit

    private func kopf(
        abdeckung: Double, unvollstaendig: Int = 0, ausfall: Int = 0, zuletzt: String? = nil
    ) -> Abdeckungsraster.Kopfzeile {
        Abdeckungsraster.baue(
            reihe(
                stunden: [], abdeckung: abdeckung, unvollstaendig: unvollstaendig,
                ausfall: ausfall, zuletzt: zuletzt),
            tage: []
        ).kopfzeile(jetzt: jetzt)
    }

    func testDieProzentzahlBekommtZweiStellenErstUeberNeunundneunzigKommaNeun() {
        XCTAssertEqual(Formate.abdeckung(0.9998), "99,98" + Formate.schmalesLeerzeichen + "%")
        XCTAssertEqual(Formate.abdeckung(0.999), "99,9" + Formate.schmalesLeerzeichen + "%")
        XCTAssertEqual(Formate.abdeckung(0.87), "87,0" + Formate.schmalesLeerzeichen + "%")
        XCTAssertEqual(Formate.abdeckung(nil), Formate.leer)
    }

    func testUnterNeunundneunzigProzentIstDieKopfzeileDringend() {
        XCTAssertTrue(kopf(abdeckung: 0.98).dringend)
        XCTAssertFalse(kopf(abdeckung: 0.99).dringend)
        XCTAssertEqual(
            kopf(abdeckung: 0.9998).abdeckung,
            "99,98" + Formate.schmalesLeerzeichen + "% Abdeckung")
    }

    func testDerLaengsteAusfallStehtNurWennEsEinenGab() {
        XCTAssertEqual(kopf(abdeckung: 1, unvollstaendig: 3).stuecke.count, 2)
        let mit = kopf(abdeckung: 1, unvollstaendig: 3, ausfall: 2).stuecke
        XCTAssertEqual(mit.count, 3)
        XCTAssertEqual(mit[0], "3 unvollständige Stunden")
        XCTAssertEqual(mit[1], "längster Ausfall 2" + Formate.schmalesLeerzeichen + "h")
    }

    func testDieKopfzeileSetztIhreStueckeOhneLeeresTrennzeichenZusammen() {
        let satz = kopf(
            abdeckung: 1, unvollstaendig: 0,
            zuletzt: Zeit.iso(jetzt.addingTimeInterval(-60))
        ).satz
        XCTAssertEqual(
            satz, "0 unvollständige Stunden · letzter Wert vor 60\(Formate.schmalesLeerzeichen)s",
            "Ohne Ausfall fehlt das Stück und nicht nur sein Inhalt.")
    }

    func testDasAlterDesLetztenWertsHatVierStufenUndEinenSatzFuerKeinenWert() {
        let e = Formate.schmalesLeerzeichen
        func alter(_ sekunden: Double) -> String {
            Abdeckungsraster.alter(
                lastAt: Zeit.iso(jetzt.addingTimeInterval(-sekunden)), jetzt: jetzt)
        }
        XCTAssertEqual(Abdeckungsraster.alter(lastAt: nil, jetzt: jetzt), "noch kein Wert")
        XCTAssertEqual(
            Abdeckungsraster.alter(lastAt: "irgendwann", jetzt: jetzt), "noch kein Wert")
        XCTAssertEqual(alter(2), "letzter Wert gerade eben")
        XCTAssertEqual(alter(30), "letzter Wert vor 30\(e)s")
        XCTAssertEqual(alter(119), "letzter Wert vor 119\(e)s")
        XCTAssertEqual(alter(120), "letzter Wert vor 2\(e)min")
        XCTAssertEqual(alter(7199), "letzter Wert vor 120\(e)min")
        XCTAssertEqual(alter(7200), "letzter Wert vor 2\(e)h")
    }

    func testEinWertAusDerZukunftIstNichtNegativAlt() {
        XCTAssertEqual(
            Abdeckungsraster.alter(
                lastAt: Zeit.iso(jetzt.addingTimeInterval(60)), jetzt: jetzt),
            "letzter Wert gerade eben")
    }
}
