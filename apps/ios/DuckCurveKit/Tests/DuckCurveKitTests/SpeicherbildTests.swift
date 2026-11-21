import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/BatteryReport.tsx` samt
/// `socEnergy.test.ts` und `PeriodStrip.tsx`.
///
/// Geprüft wird, was gerechnet wird: die acht Kopfzahlen in ihrer Reihenfolge, die vier
/// Schwellen (0,2 kWh · 0,5 kWh · 5 % · 25 %), die Gegenprobe aus dem Ladestand, die Rundung
/// des Spannenstreifens und die Tageskurve mit ihrer Achse.
final class SpeicherbildTests: XCTestCase {

    private let schmal = Formate.schmalesLeerzeichen
    private let minus = Formate.minus

    // MARK: - Bausteine der Prüfungen

    private func summen(
        minuten: Int? = 1440, grob: Int? = 0, geladen: Double? = 7.5, entladen: Double? = 6.5,
        insHaus: Double? = 6.2, pvZuSpeicher: Double? = 7.1, netzZuSpeicher: Double? = 0.4,
        dunkel: Double? = 0.1, geraet: Double? = 0.15, geraetKosten: Double? = 0.21,
        geraetEntgangen: Double? = 0.04, entladewert: Double? = 1.84, ladekosten: Double? = 0.12,
        netto: Double? = 1.72
    ) -> EnergyTotalsOut {
        EnergyTotalsOut(
            minutes: minuten, coarseMinutes: grob, batteryChargeKwh: geladen,
            batteryDischargeKwh: entladen, batteryToHouseKwh: insHaus,
            pvToBatteryKwh: pvZuSpeicher, gridToBatteryKwh: netzZuSpeicher,
            batteryDeviceKwh: geraet, gridToBatteryDarkKwh: dunkel,
            batteryDeviceCostEur: geraetKosten, batteryDeviceOpportunityEur: geraetEntgangen,
            batteryDischargeValueEur: entladewert, batteryChargeCostEur: ladekosten,
            batteryNetEur: netto)
    }

    private func bericht(
        _ t: EnergyTotalsOut? = nil, kapazitaet: Double = 13.5,
        abdeckung: Double? = 0.94, seit: String? = "2026-09-03", hinweis: String = "Geschätzt."
    ) -> EnergySummaryOut {
        EnergySummaryOut(
            period: .day, anchor: "2026-11-10", start: "2026-11-10T00:00:00+01:00",
            end: "2026-11-11T00:00:00+01:00", totals: t ?? summen(),
            meta: EnergyMetaOut(
                batteryCapacityKwh: kapazitaet, feedInCtKwh: 8.2, dataSince: seit,
                coverage: abdeckung, estimatedNoteDe: hinweis))
    }

    /// Minutenpunkte mit einem Ladestandsverlauf in Prozentpunkten - wie `rows()` in
    /// `socEnergy.test.ts`.
    private func punkte(_ prozent: [Double], beginn: Date = Date(timeIntervalSince1970: 0))
        -> [Pruefpunkt]
    {
        prozent.enumerated().map { stelle, p in
            Pruefpunkt(
                zeit: beginn.addingTimeInterval(Double(stelle) * 60), ladestand: p / 100)
        }
    }

    // MARK: - Die acht Kacheln

    func testAchtKachelnInDerReihenfolgeDerVorlage() {
        let k = Speicherbild.kacheln(bericht())
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Geladen", "Netzladung ohne PV", "Entladen", "Vollzyklen", "Ersparnis",
                "PV-Anteil Ladung", "Wirkungsgrad", "Verlust im Gerät",
            ])
        XCTAssertEqual(
            k.map(\.einheit), ["kWh", "kWh", "kWh", nil, nil, nil, nil, "kWh"])
    }

    func testGeladenTraegtSeineAufteilung() {
        let k = Speicherbild.kacheln(bericht())[0]
        XCTAssertEqual(k.wert, "7,5")
        XCTAssertEqual(k.dazu, "PV 7,1 · Netz 0,4\(schmal)kWh")
        XCTAssertEqual(k.ton, .bernstein)
    }

    func testEntladenNenntWasInsHausGing() {
        let k = Speicherbild.kacheln(bericht())[2]
        XCTAssertEqual(k.wert, "6,5")
        XCTAssertEqual(k.dazu, "6,2\(schmal)kWh ins Haus")
        XCTAssertEqual(k.ton, .nebel)
    }

    func testErsparnisIstNettoUndSagtWoraus() {
        let k = Speicherbild.kacheln(bericht())[4]
        XCTAssertEqual(k.wert, "1,72\(schmal)€")
        XCTAssertEqual(k.dazu, "1,84\(schmal)€ gespart \(minus) 0,12\(schmal)€ fürs Laden")
        XCTAssertEqual(k.ton, .bernstein)
    }

    /// Ohne beide Geldfelder steht „netto“ und nicht „- € gespart − - € fürs Laden“.
    func testErsparnisOhneZahlenSagtNurNetto() {
        let t = summen(entladewert: nil, ladekosten: nil, netto: nil)
        XCTAssertEqual(Speicherbild.kacheln(bericht(t))[4].dazu, "netto")
    }

    // MARK: - Die Schwelle 0,2 kWh

    func testNetzladungOhneSonneWirdErstUeberZweiZehntelAuffaellig() {
        func ton(_ dunkel: Double?) -> Kennzahl.Ton {
            Speicherbild.kacheln(bericht(summen(dunkel: dunkel)))[1].ton
        }
        XCTAssertEqual(ton(0.2), .gedaempft, "genau 0,2 ist noch kein Fall")
        // `BatteryReport.tsx:111`: oberhalb der Schwelle `ember`, darunter `muted`.
        XCTAssertEqual(ton(0.21), .alarm)
        XCTAssertEqual(ton(nil), .gedaempft)
    }

    func testVerlustImGeraetWirdErstUeberZweiZehntelAuffaellig() {
        func kachel(_ geraet: Double?) -> Kennzahl {
            Speicherbild.kacheln(bericht(summen(geraet: geraet)))[7]
        }
        XCTAssertEqual(kachel(0.2).ton, .gedaempft)
        XCTAssertEqual(kachel(0.9).ton, .alarm)
        XCTAssertEqual(kachel(0.9).dazu, "0,21\(schmal)€ bezahlt · 0,04\(schmal)€ entgangen")
    }

    func testNetzladungNenntDieGanzeNetzladung() {
        XCTAssertEqual(
            Speicherbild.kacheln(bericht())[1].dazu,
            "von 0,4\(schmal)kWh Netzladung insgesamt")
    }

    // MARK: - Vollzyklen

    func testVollzyklenRundenAbZehnOhneNachkommastelle() {
        XCTAssertEqual(Speicherbild.zyklenwert(6.5, kapazitaet: 13.5), "0,5")
        XCTAssertEqual(Speicherbild.zyklenwert(140.0, kapazitaet: 13.5), "10")
        XCTAssertEqual(Speicherbild.zyklenwert(130.0, kapazitaet: 13.5), "9,6")
    }

    func testVollzyklenOhneKapazitaetSchweigen() {
        let k = Speicherbild.kacheln(bericht(kapazitaet: 0))[3]
        XCTAssertEqual(k.wert, Formate.leer)
        XCTAssertEqual(k.dazu, "Kapazität unbekannt")
    }

    func testVollzyklenNennenDieKapazitaet() {
        XCTAssertEqual(
            Speicherbild.kacheln(bericht())[3].dazu, "Entladung ÷ 13,5\(schmal)kWh")
    }

    // MARK: - PV-Anteil

    func testPvAnteilUndSeinHinweis() {
        let k = Speicherbild.kacheln(bericht())[5]
        XCTAssertEqual(k.wert, "95\(schmal)%")
        XCTAssertEqual(k.dazu, "0,4\(schmal)kWh aus dem Netz geladen")
    }

    /// Ein Tag ganz aus der Sonne ist der gute Fall und soll als solcher dastehen.
    func testOhneNetzladungStehtDieGuteNachricht() {
        let k = Speicherbild.kacheln(bericht(summen(netzZuSpeicher: 0.02)))[5]
        XCTAssertEqual(k.dazu, "keine Netzladung")
    }

    func testOhneLadungKeinAnteil() {
        XCTAssertNil(Speicherbild.pvAnteil(summen(geladen: 0)))
        XCTAssertNil(Speicherbild.pvAnteil(summen(geladen: nil)))
    }

    // MARK: - Der Schätzzusatz

    func testSchaetzzusatzErstUeberFuenfProzent() {
        XCTAssertEqual(Speicherbild.schaetzzusatz(summen(minuten: 1440, grob: 72)), "")
        XCTAssertEqual(
            Speicherbild.schaetzzusatz(summen(minuten: 1440, grob: 331)),
            " · Aufteilung für 23\(schmal)% des Zeitraums geschätzt")
    }

    func testOhneMinutenKeinZusatzUndKeineDivisionDurchNull() {
        XCTAssertEqual(Speicherbild.grobanteil(summen(minuten: 0, grob: 5)), 0)
        XCTAssertEqual(Speicherbild.grobanteil(summen(minuten: nil, grob: 5)), 0)
    }

    /// Der Zusatz hängt an genau den drei Kacheln, in denen die Annahme steckt.
    func testSchaetzzusatzNurAnDenDreiHerkunftskacheln() {
        let k = Speicherbild.kacheln(bericht(summen(minuten: 1440, grob: 331)))
        let mitZusatz = k.enumerated()
            .filter { ($0.element.dazu ?? "").contains("geschätzt") }
            .map(\.offset)
        XCTAssertEqual(mitZusatz, [0, 1, 5])
    }

    // MARK: - Die siebte Kachel: Gegenprobe oder Wirkungsgrad

    func testOhneLadestandStehtDerWirkungsgrad() {
        let k = Speicherbild.kacheln(bericht(summen(geladen: 10, entladen: 8.5)))[6]
        XCTAssertEqual(k.wort, "Wirkungsgrad")
        XCTAssertEqual(k.wert, "85\(schmal)%")
        XCTAssertEqual(k.dazu, "Entladen ÷ Geladen")
        XCTAssertEqual(k.ton, .gedaempft)
    }

    func testWirkungsgradErstAbEinerHalbenKilowattstunde() {
        XCTAssertNil(Speicherbild.wirkungsgrad(summen(geladen: 0.5)))
        XCTAssertNotNil(Speicherbild.wirkungsgrad(summen(geladen: 0.51)))
    }

    /// Mehr heraus als hinein heisst: am Vortag geladen - nicht 120 Prozent Wirkungsgrad.
    func testWirkungsgradWirdBeiEinsGedeckelt() {
        XCTAssertEqual(Speicherbild.wirkungsgrad(summen(geladen: 10, entladen: 12)), 1)
    }

    func testMitLadestandStehtDieGegenprobe() {
        let l = Ladestandsenergie(ladung: 7.0, entladung: 6.3, punkte: 1200)
        let k = Speicherbild.kacheln(bericht(), ladestand: l)[6]
        XCTAssertEqual(k.wort, "Laut Ladestand")
        XCTAssertEqual(k.wert, "6,3")
        XCTAssertEqual(k.einheit, "kWh")
        XCTAssertEqual(k.dazu, "entladen · Leistungsmessung 6,5\(schmal)kWh")
        XCTAssertEqual(k.ton, .gedaempft, "6,3 gegen 6,5 ist kein Widerspruch")
    }

    func testGegenprobeWidersprichtAbEinemViertel() {
        let t = summen(entladen: 6.5)
        XCTAssertFalse(
            Speicherbild.widerspricht(
                t, ladestand: Ladestandsenergie(ladung: 7, entladung: 5.3, punkte: 100)))
        XCTAssertTrue(
            Speicherbild.widerspricht(
                t, ladestand: Ladestandsenergie(ladung: 7, entladung: 3.0, punkte: 100)))
    }

    /// An einem Tag ohne Entladung darf die Gegenprobe nicht an einer Zehntelstunde scheitern:
    /// gemessen wird an mindestens einer halben Kilowattstunde.
    func testGegenprobeAnEinemStillenTag() {
        let t = summen(entladen: 0)
        XCTAssertFalse(
            Speicherbild.widerspricht(
                t, ladestand: Ladestandsenergie(ladung: 0, entladung: 0.1, punkte: 100)))
        XCTAssertTrue(
            Speicherbild.widerspricht(
                t, ladestand: Ladestandsenergie(ladung: 0, entladung: 0.2, punkte: 100)))
    }

    // MARK: - Die Gegenprobe aus dem Ladestand

    /// Genau der Fall, an dem die Bilanz aufgefallen ist: nachts von 33 auf 0 Prozent
    /// (`socEnergy.test.ts`).
    func testEntladungDesAchtenSeptember() {
        let e = Speicherbild.ausLadestand(
            punkte((0..<34).map { 33 - Double($0) }), kapazitaetKwh: 5.1)
        XCTAssertEqual(e?.entladung ?? 0, 5.1 * 0.33, accuracy: 0.01)
        XCTAssertEqual(e?.ladung ?? 1, 0, accuracy: 0.001)
        XCTAssertEqual(e?.punkte, 34)
    }

    func testLadenUndEntladenWerdenGetrenntGezaehlt() {
        let hoch = (0..<20).map { 20 + Double($0) * 4 }
        let runter = (0..<20).map { 96 - Double($0) * 2 }
        let e = Speicherbild.ausLadestand(punkte(hoch + runter), kapazitaetKwh: 5.0)
        XCTAssertEqual(e?.ladung ?? 0, 5.0 * 0.76, accuracy: 0.01)
        XCTAssertEqual(e?.entladung ?? 0, 5.0 * 0.38, accuracy: 0.01)
    }

    func testGegenprobeSchweigtOhneGenugPunkteUndOhneKapazitaet() {
        XCTAssertNil(Speicherbild.ausLadestand(punkte([50, 49, 48]), kapazitaetKwh: 5.1))
        XCTAssertNil(
            Speicherbild.ausLadestand(
                punkte(Array(repeating: 50, count: 20)), kapazitaetKwh: 0))
        XCTAssertNil(Speicherbild.ausLadestand([], kapazitaetKwh: 5.1))
    }

    /// Zeilen ohne Ladestand zählen nicht mit - zehn Punkte heisst zehn Messungen.
    func testZeilenOhneLadestandZaehlenNicht() {
        var gemischt = punkte(Array(repeating: 50, count: 9))
        gemischt += (0..<20).map {
            Pruefpunkt(zeit: Date(timeIntervalSince1970: Double(100 + $0) * 60), speicher: 1.0)
        }
        XCTAssertNil(Speicherbild.ausLadestand(gemischt, kapazitaetKwh: 5.1))
    }

    /// Eine Zeile, die aus der Reihe fällt, zählte sonst einmal als Abstieg und einmal als
    /// Anstieg - beide Summen wären zu gross.
    func testVerdrehteZeilenWerdenSortiert() {
        var reihe = punkte((0..<20).map { 20 + Double($0) })
        reihe.swapAt(5, 15)
        let e = Speicherbild.ausLadestand(reihe, kapazitaetKwh: 10)
        XCTAssertEqual(e?.ladung ?? 0, 10 * 0.19, accuracy: 0.001)
        XCTAssertEqual(e?.entladung ?? 1, 0, accuracy: 0.001)
    }

    // MARK: - Die leere Antwort

    /// Bis Zahlen da sind steht in jeder Kachel ein Strich; die Seite baut sich nicht leer auf.
    func testLeereSummenGebenAchtKachelnMitStrichen() {
        let leer = EnergyTotalsOut()
        let k = Speicherbild.kacheln(bericht(leer, kapazitaet: 0))
        XCTAssertEqual(k.count, 8)
        XCTAssertEqual(
            k.map(\.wert),
            [
                Formate.leer, Formate.leer, Formate.leer, Formate.leer, Formate.leer,
                Formate.leer, Formate.leer, Formate.leer,
            ])
    }

    // MARK: - Der Spannenstreifen

    func testVierZeilenDesStreifens() {
        let je: [Spanne: EnergySummaryOut] = [
            .tag: bericht(), .woche: bericht(summen(entladen: 41.2)),
            .monat: bericht(summen(entladen: 168.4)),
        ]
        let zeilen = Speicherbild.spannenzeilen(je, kapazitaetKwh: 13.5)
        XCTAssertEqual(
            zeilen.map(\.wort),
            ["Ersparnis netto", "Entladen · kWh", "Vollzyklen", "PV-Anteil"])
        XCTAssertEqual(zeilen[0].ton, .bernstein)
        // Tag · Woche · Monat · Jahr; das fehlende Jahr ist ein Strich und nicht die Nachbarspalte.
        XCTAssertEqual(zeilen[1].werte, ["6,5", "41,2", "168", Formate.leer])
        // Diese Zeile behaelt die Nachkommastelle auch ueber zehn (`BatteryReport.tsx:168`).
        XCTAssertEqual(zeilen[2].werte, ["0,5", "3,1", "12,5", Formate.leer])
    }

    func testStreifenOhneEineEinzigeSpanne() {
        let zeilen = Speicherbild.spannenzeilen([:], kapazitaetKwh: 13.5)
        XCTAssertEqual(zeilen.count, 4)
        XCTAssertTrue(zeilen.allSatisfy { $0.werte == Array(repeating: Formate.leer, count: 4) })
    }

    // MARK: - Die Wörter der Seite

    func testSeitenkickerNenntDieKapazitaet() {
        XCTAssertEqual(
            Speicherbild.seitenkicker(bericht().meta),
            "13,5\(schmal)kWh · Nutzung und Ersparnis")
        XCTAssertEqual(
            Speicherbild.seitenkicker(bericht(kapazitaet: 0).meta), "Nutzung und Ersparnis")
    }

    /// Gedeckelt wird erst, was ohne Deckel die Karte über die Seite wachsen liesse.
    func testNurEinLangerBerichtBrauchtEineHoehengrenze() {
        let kurz = (0..<20).map { "Zeile \($0)" }.joined(separator: "\n")
        let lang = (0..<21).map { "Zeile \($0)" }.joined(separator: "\n")
        XCTAssertFalse(Speicherbild.berichtIstLang(""))
        XCTAssertFalse(Speicherbild.berichtIstLang(kurz))
        XCTAssertTrue(Speicherbild.berichtIstLang(lang))
    }

    func testPruefknopfUndSeinLaufendesWort() {
        XCTAssertEqual(Speicherbild.pruefknopf(laeuft: false), "Speicher prüfen")
        XCTAssertEqual(Speicherbild.pruefknopf(laeuft: true), "liest Minuten ...")
    }
}
