import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/CostReport.tsx`.
///
/// Geprüft wird, was gerechnet wird: die vier Beträge mit ihren Hinweisen, die Summenregel für
/// wahlfreie Felder, der Haushaltsabzug, die Schwelle 0,05 kWh der Preisspalte, die sieben
/// Posten mit ihren Wegen, die gemeinsame Skala der beiden Ersparnisleisten, die drei Zustände
/// des Vergleichslaufs mit Einzahl und Mehrzahl, das Wegfiltern der Tage mit Notiz, die
/// Vorzeichen der beiden Diagramme und die fünf Spannenzeilen mit fehlenden Spalten.
///
/// **Warum so viele Prüfungen auf Zeichenketten.** Diese Seite ist die eine Stelle, an der
/// jemand nachliest, was ein Monat gekostet hat. „1 Tage bewertet“, „- kWh“ und ein
/// Vergleichslauf, der bei null gerechneten Tagen eine bernsteinfarbene Null zeigt, sind dort
/// keine Schönheitsfehler: der eine liest sich wie ein Fehler, der andere wie eine Messung, und
/// der dritte wie eine Aussage, die niemand getroffen hat.
final class GelduebersichtTests: XCTestCase {

    // MARK: - Antworten bauen

    private func summen(
        minuten: Int? = 43_200, bezug: Double? = 128.40, einspeisung: Double? = 31.20,
        bezugKwh: Double? = 412.0, einspeisungKwh: Double? = 380.0, wpEur: Double? = 44.10,
        wpKwh: Double? = 160.0, evEur: Double? = 18.60, evKwh: Double? = 62.0,
        speicherEur: Double? = 3.20, speicherKwh: Double? = 11.0, sonne: Double? = 52.80,
        speicherNetto: Double? = 17.40, wpChance: Double? = 6.10, evChance: Double? = 2.40,
        speicherChance: Double? = 0.90, mittelpreis: Double? = 31.16
    ) -> EnergyTotalsOut {
        EnergyTotalsOut(
            minutes: minuten, importKwh: bezugKwh, exportKwh: einspeisungKwh,
            batteryDeviceGridKwh: speicherKwh, heatPumpGridKwh: wpKwh, evGridKwh: evKwh,
            importCostEur: bezug, exportRevenueEur: einspeisung, heatPumpCostEur: wpEur,
            heatPumpOpportunityEur: wpChance, evCostEur: evEur, evOpportunityEur: evChance,
            batteryDeviceCostEur: speicherEur, batteryDeviceOpportunityEur: speicherChance,
            pvDirectSavingsEur: sonne, avgImportPriceCt: mittelpreis,
            batteryNetEur: speicherNetto)
    }

    private func angaben(
        abdeckung: Double? = 0.97, seit: String? = "2026-03-01", satz: Double = 8.2,
        hinweis: String = "Wo Minutenwerte fehlen, ist aus der Nachbarstunde geschätzt."
    ) -> EnergyMetaOut {
        EnergyMetaOut(
            batteryCapacityKwh: 10, feedInCtKwh: satz, dataSince: seit, coverage: abdeckung,
            estimatedNoteDe: hinweis)
    }

    private func stueck(_ name: String, bezug: Double?, einspeisung: Double?)
        -> EnergyBucketOut
    {
        EnergyBucketOut(
            start: "2026-11-01T00:00:00+01:00", end: "2026-11-02T00:00:00+01:00", label: name,
            totals: summen(bezug: bezug, einspeisung: einspeisung))
    }

    private func uebersicht(
        _ t: EnergyTotalsOut? = nil, stuecke: [EnergyBucketOut] = [],
        meta: EnergyMetaOut? = nil
    ) -> EnergySummaryOut {
        EnergySummaryOut(
            generatedAt: "2026-11-22T10:00:00+01:00",
            period: .month, anchor: "2026-11-10", start: "2026-11-01T00:00:00+01:00",
            end: "2026-12-01T00:00:00+01:00", totals: t ?? summen(), buckets: stuecke,
            meta: meta ?? angaben())
    }

    private func waerme(
        pelletKg: Double? = 48.6, pelletEur: Double? = 17.95,
        hinweis: String? = "Die Pelletmenge ist aus den Leistungsstufen geschätzt."
    ) -> HeatReportOut {
        HeatReportOut(
            generatedAt: "2026-11-22T10:00:00+01:00",
            summary: uebersicht(), thermalKwhEst: 420.1, copEst: 2.91,
            forecastElectricKwh24h: 8.4, forecastThermalKwh24h: 24.1, heatLossKwPerK: 0.21,
            cycling: CyclingStats(), priceQuality: PriceQualityOut(),
            bufferBalance: BufferBalanceOut(),
            stove: StoveOut(pelletKg: pelletKg, pelletEur: pelletEur, noteDe: hinweis),
            modelNoteDe: "")
    }

    private func tag(_ datum: String, _ gespart: Double, notiz: String? = nil) -> ShiftDayOut {
        ShiftDayOut(
            day: datum, savingEur: gespart, heatPumpKwh: 12.0, shiftedKwh: 4.0, noteDe: notiz)
    }

    private func schieben(
        gespart: Double = 4.62, ctJeKwh: Double? = 2.4, wpKwh: Double = 192.0,
        verschoben: Double = 38.0, tage: [ShiftDayOut] = [], genutzt: Int = 12,
        uebersprungen: Int = 0, grund: String? = nil,
        methode: String = "Gegen einen Lauf ohne Preisblick gerechnet."
    ) -> ShiftReportOut {
        ShiftReportOut(
            generatedAt: "2026-11-22T10:00:00+01:00",
            period: .month, start: "2026-11-01T00:00:00+01:00",
            end: "2026-12-01T00:00:00+01:00", actualEur: 44.10, naiveEur: 48.72,
            savingEur: gespart, savingCtPerKwh: ctJeKwh, heatPumpKwh: wpKwh,
            shiftedKwh: verschoben, days: tage, daysUsed: genutzt,
            daysSkipped: uebersprungen, skippedDe: grund, methodDe: methode,
            assumptionsDe: ["Der Wärmebedarf bleibt gleich.", "Die Preise sind die gemessenen."])
    }

    // MARK: - Die vier Beträge

    func testVierBetraegeInDerReihenfolgeDerVorlage() {
        let b = Gelduebersicht.kopfbetraege(uebersicht(), waerme: waerme())
        XCTAssertEqual(b.map(\.wort), ["Bezahlt", "Bekommen", "Gespart", "Energie je Tag"])
        XCTAssertEqual(
            b.map(\.ton), [.alarm, .nebel, .bernstein, .text],
            "Bezahlt rot, bekommen Nebel, gespart Bernstein, je Tag ohne Ton")
    }

    /// `bezahlt = import_cost_eur + heat.stove.pellet_eur` (`CostReport.tsx:66-67`).
    func testBezahltEnthaeltDiePellets() {
        let b = Gelduebersicht.kopfbetraege(uebersicht(), waerme: waerme())
        XCTAssertEqual(b[0].wert, Formate.euro(128.40 + 17.95))
        XCTAssertEqual(b[0].dazu, "Netzstrom 128,40\u{202F}€ · Pellets 17,95\u{202F}€")
    }

    /// Ohne `/energy/heat` ist „Bezahlt“ allein der Netzstrom - und der Hinweis sagt es.
    func testOhneWaermeantwortBleibtDerNetzstromStehen() {
        let b = Gelduebersicht.kopfbetraege(uebersicht(), waerme: nil)
        XCTAssertEqual(b[0].wert, Formate.euro(128.40))
        XCTAssertEqual(b[0].dazu, "Netzstrom 128,40\u{202F}€ · Pellets -")
    }

    /// Die Summenregel: ein Teil genügt, alle fehlen heißt Strich.
    func testEineSummeIstEineZahlSobaldEinTeilEineIst() {
        XCTAssertEqual(Gelduebersicht.summe([nil, 2.5]), 2.5)
        XCTAssertEqual(Gelduebersicht.summe([1.5, 2.5]), 4.0)
        XCTAssertNil(Gelduebersicht.summe([nil, nil]))
        XCTAssertNil(Gelduebersicht.summe([Double.nan]), "NaN ist keine Messung")
    }

    func testFehltDerNetzbezugUndDiePelletsStehtEinStrich() {
        let b = Gelduebersicht.kopfbetraege(
            uebersicht(summen(bezug: nil)), waerme: waerme(pelletEur: nil))
        XCTAssertEqual(b[0].wert, Formate.leer)
        XCTAssertNil(b[0].dazu, "Netzstrom - · Pellets - sagt nichts")
    }

    func testBekommenNenntDieMengeUndDassSieNettoIst() {
        let b = Gelduebersicht.kopfbetraege(uebersicht(), waerme: waerme())
        XCTAssertEqual(b[1].wert, Formate.euro(31.20))
        XCTAssertEqual(b[1].dazu, "Einspeisung 380\u{202F}kWh · netto")
    }

    /// `gespart = pv_direct_savings_eur + battery_net_eur` (`CostReport.tsx:69`), und der
    /// Hinweis ist fest - er gilt auch ohne Antwort.
    func testGespartIstSonnePlusSpeicherMitFestemHinweis() {
        let b = Gelduebersicht.kopfbetraege(uebersicht(), waerme: waerme())
        XCTAssertEqual(b[2].wert, Formate.euro(52.80 + 17.40))
        XCTAssertEqual(
            b[2].dazu, "Sonne direkt und Speicher, gegen den Netzpreis derselben Stunde")
    }

    /// `tage = max(1, minutes / 1440)`, `jeTag = (bezahlt - bekommen) / tage`
    /// (`CostReport.tsx:70-71`).
    func testEnergieJeTagRechnetUeberDieBewerteteZeit() {
        let b = Gelduebersicht.kopfbetraege(uebersicht(), waerme: waerme())
        let erwartet = (128.40 + 17.95 - 31.20) / 30.0
        XCTAssertEqual(b[3].wert, Formate.euro(erwartet))
        XCTAssertEqual(b[3].dazu, "bezahlt minus bekommen, 30 Tage bewertet")
    }

    /// Unter anderthalb Tagen „Tag“ - sonst stünde auf der Tagesansicht „1 Tage“.
    func testEinTagStehtImEinzahl() {
        let b = Gelduebersicht.kopfbetraege(
            uebersicht(summen(minuten: 1440)), waerme: waerme())
        XCTAssertEqual(b[3].dazu, "bezahlt minus bekommen, 1 Tag bewertet")
    }

    /// Mindestens ein Tag: sechs bewertete Stunden sollen den Tagespreis nicht vervierfachen.
    func testWenigerAlsEinTagZaehltAlsEinTag() {
        XCTAssertEqual(Gelduebersicht.bewerteteTage(360), 1)
        XCTAssertEqual(Gelduebersicht.bewerteteTage(43_200), 30)
        XCTAssertNil(Gelduebersicht.bewerteteTage(0))
        XCTAssertNil(Gelduebersicht.bewerteteTage(nil))
    }

    func testOhneBewerteteMinutenGibtEsKeinenTagespreis() {
        let b = Gelduebersicht.kopfbetraege(uebersicht(summen(minuten: 0)), waerme: waerme())
        XCTAssertEqual(b[3].wert, Formate.leer)
        XCTAssertNil(b[3].dazu)
    }

    // MARK: - Die Aufstellung

    func testSiebenPostenInDerReihenfolgeDerVorlage() {
        let p = Gelduebersicht.aufstellung(uebersicht(), waerme: waerme())
        XCTAssertEqual(
            p.map(\.wort),
            [
                "Netzstrom Haushalt", "Netzstrom Wärmepumpe", "Netzstrom Wallbox",
                "Netzstrom Speichergerät", "Pellets", "Einspeisung",
                "Entgangene Vergütung (Wärmepumpe, Wallbox, Speichergerät)",
            ])
    }

    /// Der halbe Zweck der Seite: jede Zahl führt zu ihrer Seite (`CostReport.tsx:17-20`).
    func testJederPostenFuehrtZuSeinerSeite() {
        let p = Gelduebersicht.aufstellung(uebersicht(), waerme: waerme())
        XCTAssertEqual(
            p.map(\.weg),
            [
                "/strom", "/waerme", "/strom/wallbox", "/strom/speicher", "/waerme",
                "/geld/pv-abrechnung", "/strom/pv",
            ])
        XCTAssertEqual(
            p.map(\.seite),
            ["Strom", "Wärme", "Wallbox", "Speicher", "Wärme", "PV-Abrechnung", "Photovoltaik"])
    }

    /// `haushalt = import − heat_pump − ev − battery_device` (`CostReport.tsx:101-102`).
    func testHaushaltIstDerNetzbezugOhneDieDreiGeraete() {
        let h = Gelduebersicht.haushaltsrest(summen())
        XCTAssertEqual(h.eur ?? 0, 128.40 - 44.10 - 18.60 - 3.20, accuracy: 0.0001)
        XCTAssertEqual(h.kwh ?? 0, 412.0 - 160.0 - 62.0 - 11.0, accuracy: 0.0001)
    }

    /// Ein negativer Haushaltsposten wäre ein Rechenfehler und keine Auskunft.
    func testHaushaltWirdNieNegativ() {
        let h = Gelduebersicht.haushaltsrest(summen(bezug: 10.0, bezugKwh: 20.0))
        XCTAssertEqual(h.eur, 0)
        XCTAssertEqual(h.kwh, 0)
    }

    /// Fehlt der Netzbezug, fehlt der Haushaltsposten - nicht „0,00 €“.
    func testOhneNetzbezugStehtImHaushaltEinStrich() {
        let p = Gelduebersicht.aufstellung(
            uebersicht(summen(bezug: nil, bezugKwh: nil)), waerme: waerme())
        XCTAssertEqual(p[0].betrag, Formate.leer)
        XCTAssertEqual(p[0].menge, Formate.leer)
        XCTAssertEqual(p[0].preis, Formate.leer)
    }

    /// `ct(e, kwh) = kwh > 0.05 ? de1(e / kwh * 100, 1) + " ct" : "-"` (`CostReport.tsx:104`).
    func testPreisspalteHatEineStelleUndEineSchwelle() {
        XCTAssertEqual(Gelduebersicht.ctJeKwh(44.10, 160.0), "27,6\u{202F}ct")
        XCTAssertEqual(
            Gelduebersicht.ctJeKwh(0.60, 0.05), Formate.leer,
            "genau 0,05 kWh liegt noch unter der Schwelle")
        XCTAssertEqual(Gelduebersicht.ctJeKwh(0.60, 0.051), "1176,5\u{202F}ct")
        XCTAssertEqual(Gelduebersicht.ctJeKwh(nil, 160.0), Formate.leer)
        XCTAssertEqual(Gelduebersicht.ctJeKwh(44.10, nil), Formate.leer)
    }

    /// Die Pelletzeile: eine Stelle in kg, **keine** Preisspalte (`CostReport.tsx:209`).
    func testPelletzeileHatKeinenPreisUndEineStelle() {
        let p = Gelduebersicht.aufstellung(uebersicht(), waerme: waerme())
        XCTAssertEqual(p[4].menge, "48,6\u{202F}kg")
        XCTAssertEqual(p[4].preis, "")
        XCTAssertEqual(p[4].betrag, Formate.euro(17.95))
        XCTAssertEqual(p[4].ton, .ofen)
    }

    func testOhneWaermeantwortBleibtDiePelletzeileLeer() {
        let p = Gelduebersicht.aufstellung(uebersicht(), waerme: nil)
        XCTAssertEqual(p[4].menge, Formate.leer)
        XCTAssertEqual(p[4].betrag, Formate.leer)
    }

    /// „− 31,20 €“ mit U+2212 und einem Leerzeichen (`CostReport.tsx:210`).
    func testEinspeisungStehtAlsAbzugMitEchtemMinus() {
        let p = Gelduebersicht.aufstellung(uebersicht(), waerme: waerme())
        XCTAssertEqual(p[5].betrag, "\u{2212} 31,20\u{202F}€")
        XCTAssertEqual(p[5].preis, "8,20\u{202F}ct", "der Vergütungssatz mit zwei Stellen")
        XCTAssertEqual(p[5].menge, "380\u{202F}kWh")
    }

    func testEntgangeneVerguetungIstDieSummeDerDreiChancen() {
        let p = Gelduebersicht.aufstellung(uebersicht(), waerme: waerme())
        XCTAssertEqual(p[6].betrag, Formate.euro(6.10 + 2.40 + 0.90))
        XCTAssertEqual(p[6].menge, "")
        XCTAssertEqual(p[6].preis, "")
        XCTAssertEqual(p[6].ton, .leise)
    }

    func testFuenfSpaltenkoepfeUndDieKopfzeileDerKarte() {
        XCTAssertEqual(
            Gelduebersicht.aufstellungsspalten,
            ["Posten", "Menge", "Ø Preis", "Betrag", "Seite"])
        XCTAssertEqual(
            Gelduebersicht.aufstellungskopf,
            "Beträge in Euro · aus denselben Stundenbilanzen wie alle anderen Seiten")
        XCTAssertEqual(Gelduebersicht.aufstellungssaetze.count, 3)
        XCTAssertTrue(Gelduebersicht.aufstellungssaetze[0].contains("Eigenverbrauch des Wechselrichters"))
        XCTAssertTrue(Gelduebersicht.aufstellungssaetze[1].contains("nicht gewogen"))
        XCTAssertTrue(Gelduebersicht.aufstellungssaetze[2].contains("kein Geld, das fehlt"))
    }

    // MARK: - Woraus die Ersparnis besteht

    /// Gemeinsame Skala: beide Leisten messen an der grösseren der beiden
    /// (`CostReport.tsx:130`).
    func testBeideLeistenTeilenEineSkala() {
        let e = Gelduebersicht.ersparnisteile(summen(sonne: 50.0, speicherNetto: 25.0))
        XCTAssertEqual(e.map(\.wort), ["Sonne direkt genutzt", "Speicher statt Netz (netto)"])
        XCTAssertEqual(e[0].anteil, 1.0)
        XCTAssertEqual(e[1].anteil, 0.5)
        XCTAssertEqual(e.map(\.ton), [.bernstein, .nebel])
    }

    /// Auf ganze Prozent gerundet, wie `Math.round(v / max * 100)`.
    func testDerLeistenanteilWirdAufGanzeProzentGerundet() {
        let e = Gelduebersicht.ersparnisteile(summen(sonne: 100.0, speicherNetto: 33.333))
        XCTAssertEqual(e[1].anteil, 0.33)
    }

    /// Ein Speicher, der Geld gekostet hat: leere Leiste, aber der Betrag nennt das Minus.
    func testEinNegativerSpeicheranteilLaeuftNichtNachLinks() {
        let e = Gelduebersicht.ersparnisteile(summen(sonne: 20.0, speicherNetto: -4.0))
        XCTAssertEqual(e[1].anteil, 0)
        XCTAssertEqual(e[1].wert, Formate.euro(-4.0))
    }

    /// Der Boden 0,01 € verhindert die Division durch Null.
    func testOhneErsparnisBleibenBeideLeistenLeer() {
        let e = Gelduebersicht.ersparnisteile(summen(sonne: nil, speicherNetto: nil))
        XCTAssertEqual(e.map(\.anteil), [0, 0])
        XCTAssertEqual(e.map(\.wert), [Formate.euro(0), Formate.euro(0)])
    }

    // MARK: - Was das Verschieben gebracht hat

    func testGesparterVergleichslaufStehtInBernsteinMitSeinemSatz() {
        let v = Gelduebersicht.verschiebung(schieben(gespart: 4.62))
        XCTAssertEqual(v.zahl, Formate.euro(4.62))
        XCTAssertEqual(v.ton, .bernstein)
        XCTAssertEqual(v.satz, "gespart gegenüber einem Lauf ohne Preisblick")
    }

    /// Negativ darf sie sein, und dann sagt sie es (`CostReport.tsx:28-31`).
    func testEinVergleichslaufDerGeldGekostetHatSagtDas() {
        let v = Gelduebersicht.verschiebung(schieben(gespart: -1.80))
        XCTAssertEqual(v.ton, .alarm)
        XCTAssertEqual(v.satz, "mehr bezahlt gegenüber einem Lauf ohne Preisblick")
    }

    /// Der dritte Zustand: kein gerechneter Tag heißt keine Aussage, nicht „nichts gebracht“.
    func testOhneGerechneteTageStehtDerLeersatzInLeise() {
        let v = Gelduebersicht.verschiebung(schieben(gespart: 0, genutzt: 0))
        XCTAssertEqual(v.ton, .leise)
        XCTAssertEqual(v.satz, "Für diesen Zeitraum reicht es nicht für eine Aussage.")
        XCTAssertNil(v.dazu, "ohne gerechnete Tage gibt es nichts aufzuschlüsseln")
        XCTAssertEqual(v.zahl, Formate.euro(0), "die Zahl bleibt stehen, nur leise")
    }

    func testOhneAntwortStehtEinStrich() {
        let v = Gelduebersicht.verschiebung(nil)
        XCTAssertEqual(v.zahl, Formate.leer)
        XCTAssertEqual(v.ton, .leise)
        XCTAssertNil(v.dazu)
    }

    /// Die Detailzeile in voller Länge (`CostReport.tsx:166-172`).
    func testDieDetailzeileNenntCentMengeTageUndUebersprungene() {
        let v = Gelduebersicht.verschiebung(
            schieben(uebersprungen: 2, grund: "zu wenig Preisdaten"))
        XCTAssertEqual(
            v.dazu,
            "2,4\u{202F}ct je verschobener kWh · 38 von 192\u{202F}kWh verschoben · "
                + "12 Tage gerechnet · 2 ohne Aussage (zu wenig Preisdaten)")
    }

    func testOhneCentWertFaelltDerHalbeSatzWeg() {
        let v = Gelduebersicht.verschiebung(schieben(ctJeKwh: nil))
        XCTAssertEqual(
            v.dazu, "38 von 192\u{202F}kWh verschoben · 12 Tage gerechnet")
    }

    func testEinGerechneterTagStehtImEinzahl() {
        let v = Gelduebersicht.verschiebung(schieben(ctJeKwh: nil, genutzt: 1))
        XCTAssertEqual(v.dazu, "38 von 192\u{202F}kWh verschoben · 1 Tag gerechnet")
    }

    func testOhneGrundStehtKeineLeereKlammer() {
        let v = Gelduebersicht.verschiebung(
            schieben(ctJeKwh: nil, uebersprungen: 3, grund: nil))
        XCTAssertEqual(
            v.dazu, "38 von 192\u{202F}kWh verschoben · 12 Tage gerechnet · 3 ohne Aussage")
    }

    // MARK: - Die beiden Balkendiagramme

    /// „Netzstrom“ positiv, „Einspeisung“ unter der Nulllinie (`CostReport.tsx:73-83`).
    func testHauptdiagrammStelltDieVerguetungUnterDieNulllinie() {
        let b = uebersicht(stuecke: [
            stueck("01.11.", bezug: 4.20, einspeisung: 1.10),
            stueck("02.11.", bezug: 3.80, einspeisung: 0.90),
        ])
        let r = Gelduebersicht.hauptreihen(b)
        XCTAssertEqual(r.map(\.name), ["Netzstrom", "Einspeisung"])
        XCTAssertEqual(r.map(\.ton), [.netz, .einspeisung])
        XCTAssertEqual(r[0].werte.map(\.wert), [4.20, 3.80])
        XCTAssertEqual(r[1].werte.map(\.wert), [-1.10, -0.90])
        XCTAssertEqual(r[0].werte.map(\.wort), ["01.11.", "02.11."])
    }

    /// Im Diagramm ist eine fehlende Zahl kein Balken, kein Strich.
    func testEinFehlenderBetragIstImDiagrammEineNull() {
        let b = uebersicht(stuecke: [stueck("01.11.", bezug: nil, einspeisung: nil)])
        let r = Gelduebersicht.hauptreihen(b)
        XCTAssertEqual(r[0].werte.map(\.wert), [0])
        XCTAssertEqual(r[1].werte.map(\.wert), [0])
    }

    func testOhneZeitraumstueckeHatDasHauptdiagrammKeineWerte() {
        let r = Gelduebersicht.hauptreihen(uebersicht())
        XCTAssertTrue(r.allSatisfy { $0.werte.isEmpty })
        XCTAssertEqual(
            Gelduebersicht.hauptdiagrammleer,
            "Für diesen Zeitraum liegen keine bewerteten Stunden vor.")
    }

    /// Zwei Reihen statt einer eingefärbten (`CostReport.tsx:85-93`).
    func testTagesdiagrammTrenntGebrachtVonGekostet() {
        let v = schieben(tage: [
            tag("2026-11-07", 0.80), tag("2026-11-08", -0.30), tag("2026-11-09", 0),
        ])
        let r = Gelduebersicht.verschiebungsreihen(v)
        XCTAssertEqual(r.map(\.name), ["gebracht", "gekostet"])
        XCTAssertEqual(r.map(\.ton), [.bernstein, .alarm])
        XCTAssertEqual(r[0].werte.map(\.wert), [0.80, 0, 0])
        XCTAssertEqual(r[1].werte.map(\.wert), [0, -0.30, 0])
    }

    /// Das Achsenwort ist „07.11.“ und nicht „2026-11-07“ (`CostReport.tsx:90`).
    func testAchsenwortIstTagUndMonat() {
        let r = Gelduebersicht.verschiebungsreihen(schieben(tage: [tag("2026-11-07", 1.0)]))
        XCTAssertEqual(r[0].werte.map(\.wort), ["07.11."])
    }

    /// Tage mit Notiz werden weggelassen (`CostReport.tsx:88`).
    func testTageMitNotizWerdenNichtGezeichnet() {
        let v = schieben(tage: [
            tag("2026-11-07", 0.80),
            tag("2026-11-08", 0, notiz: "Wärmepumpe stand still"),
            tag("2026-11-09", 0.40),
        ])
        let r = Gelduebersicht.verschiebungsreihen(v)
        XCTAssertEqual(r[0].werte.map(\.wort), ["07.11.", "09.11."])
    }

    func testOhneTageOhneNotizBleibenBeideReihenLeer() {
        let v = schieben(tage: [tag("2026-11-08", 0, notiz: "zu wenig Preisdaten")])
        XCTAssertTrue(Gelduebersicht.verschiebungsreihen(v).allSatisfy { $0.werte.isEmpty })
        XCTAssertTrue(Gelduebersicht.verschiebungsreihen(nil).allSatisfy { $0.werte.isEmpty })
    }

    // MARK: - Die vier Spannen

    func testFuenfSpannenzeilenInDerReihenfolgeDerVorlage() {
        let je: [Spanne: EnergySummaryOut] = [
            .tag: uebersicht(), .woche: uebersicht(), .monat: uebersicht(),
            .jahr: uebersicht(),
        ]
        let z = Gelduebersicht.spannenzeilen(je)
        XCTAssertEqual(
            z.map(\.wort),
            [
                "Bezahlt (Netzstrom)", "Bekommen (Einspeisung)", "Gespart (Sonne, Speicher)",
                "Netzbezug", "Ø Bezugspreis",
            ])
        XCTAssertEqual(z[0].werte.count, 4)
        XCTAssertEqual(z[0].werte[0], Formate.euro(128.40))
        XCTAssertEqual(z[2].werte[0], Formate.euro(52.80 + 17.40))
        XCTAssertEqual(z[3].werte[0], "412\u{202F}kWh")
        // „Bezahlt (Netzstrom)“ trägt `--alert` wie in der Vorlage (`CostReport.tsx:229`:
        // `tone: "ember"`; `PeriodStrip.tsx:19`). Vorher war es `glut`, weil ``Kennzahl/Ton``
        // keinen Alarmton kannte.
        XCTAssertEqual(
            // Seit dem 24.11.2026 `netz`: das Violett des Netzbezugs.
            z.map(\.ton), [.netz, .nebel, .bernstein, .normal, .normal])
    }

    /// **Eine** Nachkommastelle am Ø-Preis (`CostReport.tsx:233`) - die App hatte zwei.
    func testBezugspreisHatEineNachkommastelle() {
        let z = Gelduebersicht.spannenzeilen([.tag: uebersicht()])
        XCTAssertEqual(z[4].werte[0], "31,2\u{202F}ct")
    }

    func testOhneMittelpreisStehtEinStrich() {
        let z = Gelduebersicht.spannenzeilen([.tag: uebersicht(summen(mittelpreis: nil))])
        XCTAssertEqual(z[4].werte[0], Formate.leer)
    }

    /// Eine fehlende Spanne lässt ihre Spalte leer, nicht die der Nachbarin
    /// (`CostReport.tsx:98`).
    func testEineFehlendeSpanneLaesstIhreSpalteLeer() {
        let z = Gelduebersicht.spannenzeilen([.tag: uebersicht(), .jahr: uebersicht()])
        XCTAssertEqual(
            z[0].werte, [Formate.euro(128.40), Formate.leer, Formate.leer, Formate.euro(128.40)])
    }

    func testOhneJedeSpanneStehenVierStriche() {
        let z = Gelduebersicht.spannenzeilen([:])
        XCTAssertEqual(z.count, 5)
        XCTAssertTrue(z.allSatisfy { $0.werte == Array(repeating: Formate.leer, count: 4) })
    }

    // MARK: - Die Sätze unter der Seite

    /// Die Abdeckung bleibt sichtbar, auch zugeklappt (`ReportShell.tsx:166-168`).
    func testDieKurzzeileNenntAbdeckungUndAufzeichnungsbeginn() {
        XCTAssertEqual(
            Gelduebersicht.methodenkurz(uebersicht()),
            "Datenabdeckung 97\u{202F}% · Aufzeichnung seit So, 1.3.")
    }

    func testOhneMessdatenSagtDieKurzzeileDas() {
        let m = Gelduebersicht.methodenkurz(uebersicht(meta: angaben(abdeckung: nil, seit: nil)))
        XCTAssertEqual(m, "noch keine Messdaten im Zeitraum")
    }

    /// Erst die Notiz des Ofens, dann der Absatz, der auf jeder Seite steht
    /// (`CostReport.tsx:236`).
    func testDieOfennotizStehtVorDemAllgemeinenAbsatz() {
        let s = Gelduebersicht.methodensaetze(uebersicht(), waerme: waerme())
        XCTAssertEqual(s.count, 2)
        XCTAssertTrue(s[0].contains("Pelletmenge"))
        XCTAssertTrue(s[1].contains("Minutenwerte"))
    }

    func testOhneOfennotizBleibtEinAbsatz() {
        let s = Gelduebersicht.methodensaetze(uebersicht(), waerme: waerme(hinweis: nil))
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(
            Gelduebersicht.methodensaetze(uebersicht(), waerme: nil).count, 1,
            "ohne Wärmeantwort bleibt der allgemeine Absatz")
    }

    /// Die Annahmen des Vergleichslaufs stehen **nicht** in der Methodenkarte - sie gehören
    /// zu der Zahl, die sie voraussetzt.
    func testDieAnnahmenStehenNichtInDerMethodenkarte() {
        let s = Gelduebersicht.methodensaetze(uebersicht(), waerme: waerme())
        XCTAssertFalse(s.contains { $0.contains("Wärmebedarf bleibt gleich") })
        XCTAssertEqual(Gelduebersicht.annahmentitel, "Annahmen des Vergleichslaufs")
    }

    // MARK: - Die Wortlaute der Karten

    func testDieKartenheissenWieInDerVorlage() {
        XCTAssertEqual(Gelduebersicht.seitenkicker, "Was der Zeitraum gekostet hat, in einer Zeile")
        XCTAssertEqual(Gelduebersicht.hauptdiagrammtitel, "Bezahlt und bekommen")
        XCTAssertEqual(Gelduebersicht.ersparnistitel, "Woraus die Ersparnis besteht")
        XCTAssertEqual(Gelduebersicht.verschiebungstitel, "Was das Verschieben gebracht hat")
        XCTAssertEqual(Gelduebersicht.aufstellungstitel, "Aufstellung")
        XCTAssertEqual(Gelduebersicht.spannentitel, "Kosten im Zeitraum")
    }

    func testDerErsparnissatzNenntWogegenGerechnetWird() {
        XCTAssertTrue(Gelduebersicht.ersparnissatz.contains("Netzpreis der jeweiligen Stunde"))
        XCTAssertTrue(Gelduebersicht.ersparnissatz.contains("gerechnet, nicht gemessen"))
    }
}
