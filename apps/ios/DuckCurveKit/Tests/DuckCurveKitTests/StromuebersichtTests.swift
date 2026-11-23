import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/HouseReport.tsx`,
/// `apps/web/src/components/reports/PeriodStrip.tsx` und
/// `apps/web/src/components/reports/charts.ts`.
///
/// Geprüft wird, was gerechnet wird: die sechs Kennzahlen mit ihren Hinweisen und Tönen, der
/// Unterschied zwischen einem fehlenden Feld und einer Null, die Anteilsregel mit ihrem Nenner,
/// der Weg zur Rechnungsprüfung und wem er gehört, die zwei Reihenfolgen der Balkenbilder mit
/// der Rundung auf zwei Stellen, die Ablesung mit dem Wegfallen der Nullreihen und die vier
/// Spannenzeilen samt der Schwelle von hundert Kilowattstunden.
///
/// **Warum so viele Prüfungen auf Zeichenketten.** Diese Seite ist die eine Stelle, an der
/// jemand nachliest, wie viel Strom ein Tag gebraucht hat und wer ihn gebraucht hat. „0,0 kWh“
/// für einen schweigenden Zähler, „0 % des Verbrauchs“ bei einem Nenner von Null und ein
/// Stapel, dessen Mitte fehlt, sind dort keine Schönheitsfehler: der erste liest sich wie eine
/// Messung, der zweite wie eine Aussage, die niemand getroffen hat, und der dritte verschiebt
/// die Reihen über sich.
final class StromuebersichtTests: XCTestCase {

    // MARK: - Antworten bauen

    private func summen(
        minuten: Int? = 600, haus: Double? = 59.2, wp: Double? = 29.0, ev: Double? = 18.4,
        rest: Double? = 11.8, pvDirekt: Double? = 4.2, batterie: Double? = 2.4,
        netz: Double? = 52.6, autarkie: Double? = 0.112, bezug: Double? = 16.84,
        bezugKwh: Double? = 52.6, einspeisung: Double? = 0.32
    ) -> EnergyTotalsOut {
        var t = EnergyTotalsOut()
        t.minutes = minuten
        t.houseKwh = haus
        t.heatPumpKwh = wp
        t.evKwh = ev
        t.baseKwh = rest
        t.pvDirectKwh = pvDirekt
        t.batteryToHouseKwh = batterie
        t.gridToHouseKwh = netz
        t.autarky = autarkie
        t.importCostEur = bezug
        t.importKwh = bezugKwh
        t.exportRevenueEur = einspeisung
        return t
    }

    private func angaben(
        abdeckung: Double? = 0.61, seit: String? = "2026-03-14T00:00:00+01:00"
    ) -> EnergyMetaOut {
        EnergyMetaOut(
            batteryCapacityKwh: 10, feedInCtKwh: 8.2, dataSince: seit, coverage: abdeckung,
            estimatedNoteDe: "Geschätzt, wo Minutenwerte fehlen.")
    }

    private func stueck(_ name: String, _ t: EnergyTotalsOut) -> EnergyBucketOut {
        EnergyBucketOut(
            start: "2026-11-10T00:00:00+01:00", end: "2026-11-10T01:00:00+01:00", label: name,
            totals: t)
    }

    private func uebersicht(
        _ t: EnergyTotalsOut? = nil, stuecke: [EnergyBucketOut] = [],
        meta: EnergyMetaOut? = nil
    ) -> EnergySummaryOut {
        EnergySummaryOut(
            generatedAt: "2026-11-22T10:00:00+01:00",
            period: .day, anchor: "2026-11-10", start: "2026-11-10T00:00:00+01:00",
            end: "2026-11-11T00:00:00+01:00", totals: t ?? summen(), buckets: stuecke,
            meta: meta ?? angaben())
    }

    // MARK: - Die sechs Kennzahlen

    func testSechsKennzahlenInDerReihenfolgeDerVorlage() {
        let k = Stromuebersicht.kacheln(uebersicht(), hausherr: true)
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Verbrauch gesamt", "Wärmepumpe", "Wallbox", "Haushalt (Rest)", "Autarkie",
                "Netzbezug",
            ])
        XCTAssertEqual(k.map(\.einheit), ["kWh", "kWh", "kWh", "kWh", nil, nil])
        XCTAssertEqual(k[0].wert, "59,2")
        XCTAssertEqual(k[1].wert, "29,0")
        XCTAssertEqual(k[2].wert, "18,4")
        XCTAssertEqual(k[3].wert, "11,8")
        XCTAssertEqual(k[4].wert, "11\(Formate.schmalesLeerzeichen)%")
        XCTAssertEqual(k[5].wert, "16,84\(Formate.schmalesLeerzeichen)€")
    }

    /// Die Töne der Vorlage: `mist`, `muted`, `amber` (`HouseReport.tsx:47-49`).
    func testToeneDerKennzahlen() {
        let k = Stromuebersicht.kacheln(uebersicht(), hausherr: false)
        XCTAssertEqual(k[0].ton, .normal)
        XCTAssertEqual(k[1].ton, .normal)
        XCTAssertEqual(k[2].ton, .nebel)
        XCTAssertEqual(k[3].ton, .gedaempft)
        XCTAssertEqual(k[4].ton, .bernstein)
    }

    func testHinweiseDerKennzahlen() {
        let k = Stromuebersicht.kacheln(uebersicht(), hausherr: true)
        XCTAssertEqual(k[0].dazu, "10 h bewertet")
        XCTAssertEqual(k[1].dazu, "49\(Formate.schmalesLeerzeichen)% des Verbrauchs")
        XCTAssertEqual(k[2].dazu, "31\(Formate.schmalesLeerzeichen)% des Verbrauchs")
        XCTAssertEqual(k[3].dazu, "20\(Formate.schmalesLeerzeichen)% des Verbrauchs")
        XCTAssertEqual(k[4].dazu, "6,6\(Formate.schmalesLeerzeichen)kWh ohne Netz")
        XCTAssertEqual(
            k[5].dazu, "52,6\(Formate.schmalesLeerzeichen)kWh · Rechnungen prüfen")
    }

    /// **Kosten sehen alle, den Griff nur der Hausherr** (`HouseReport.tsx:50-57`).
    func testGastSiehtDieKostenAberKeinenGriff() {
        let gast = Stromuebersicht.kacheln(uebersicht(), hausherr: false)
        XCTAssertEqual(gast[5].wert, "16,84\(Formate.schmalesLeerzeichen)€")
        XCTAssertEqual(gast[5].dazu, "52,6\(Formate.schmalesLeerzeichen)kWh")
        XCTAssertNil(Stromuebersicht.weg("Netzbezug", hausherr: false))
        XCTAssertEqual(Stromuebersicht.weg("Netzbezug", hausherr: true), "/geld/rechnungen")
    }

    /// Nur die Netzbezugskachel führt irgendwohin - die anderen fünf nicht, auch beim Hausherrn.
    func testNurDieNetzbezugskachelFuehrtWeiter() {
        for wort in ["Verbrauch gesamt", "Wärmepumpe", "Wallbox", "Haushalt (Rest)", "Autarkie"] {
            XCTAssertNil(Stromuebersicht.weg(wort, hausherr: true), wort)
        }
    }

    /// **Ein fehlendes Feld ist ein Strich und keine Null** (`ReportShell.tsx:14-16`).
    func testOhneAntwortSechsStricheUndKeineNullen() {
        let k = Stromuebersicht.kacheln(nil, hausherr: true)
        XCTAssertEqual(k.count, 6)
        XCTAssertEqual(k.map(\.wert), Array(repeating: Formate.leer, count: 6))
        XCTAssertEqual(k[0].dazu, "keine Daten")
        for i in 1...5 {
            XCTAssertNil(k[i].dazu, k[i].wort)
        }
    }

    func testLeereSummenGebenStricheUndKeineAnteile() {
        let k = Stromuebersicht.kacheln(uebersicht(EnergyTotalsOut()), hausherr: true)
        XCTAssertEqual(k[0].wert, Formate.leer)
        XCTAssertEqual(k[0].dazu, "keine Daten")
        XCTAssertNil(k[1].dazu)
        XCTAssertEqual(k[4].dazu, "0,0\(Formate.schmalesLeerzeichen)kWh ohne Netz")
        // Der Hinweis der Netzbezugskachel bleibt, auch wenn die Menge fehlt: der Griff ist da.
        XCTAssertEqual(k[5].dazu, "- · Rechnungen prüfen")
    }

    /// Null Minuten heißt „keine Daten“ und nicht „0 h bewertet“.
    func testNullMinutenSindKeineDaten() {
        let k = Stromuebersicht.kacheln(uebersicht(summen(minuten: 0)), hausherr: true)
        XCTAssertEqual(k[0].dazu, "keine Daten")
    }

    /// Ein Nenner von Null ergibt keinen Anteil (`HouseReport.tsx:38`).
    func testAnteilBrauchtEinenNennerGroesserNull() {
        XCTAssertNil(Stromuebersicht.anteil(5, 0))
        XCTAssertNil(Stromuebersicht.anteil(5, nil))
        XCTAssertNil(Stromuebersicht.anteil(nil, 100))
        XCTAssertEqual(
            Stromuebersicht.anteil(0, 100), "0\(Formate.schmalesLeerzeichen)% des Verbrauchs")
    }

    // MARK: - Die zwei Balkenbilder

    func testVerbrauchsreihenInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            Stromuebersicht.Verbraucher.allCases.map(\.name),
            ["Wärmepumpe", "Wallbox", "Haushalt"])
    }

    /// **Die Wörter der Herkunft sind die der Vorlage** (`HouseReport.tsx:25-27`) - die App
    /// schrieb „Sonne direkt“, „aus dem Speicher“, „aus dem Netz“.
    func testHerkunftsreihenTragenDieWoerterDerVorlage() {
        XCTAssertEqual(
            Stromuebersicht.Herkunft.allCases.map(\.name),
            ["PV direkt", "aus Batterie", "aus Netz"])
    }

    /// Die Farben sind dieselben wie in `palette.ts:35-37,38,43,53`.
    func testFarbenDeckenSichMitDerPalette() {
        XCTAssertEqual(Stromuebersicht.Verbraucher.waermepumpe.farbe.hex, "#E0966B")
        XCTAssertEqual(Stromuebersicht.Verbraucher.wallbox.farbe.hex, "#2F89B5")
        XCTAssertEqual(Stromuebersicht.Verbraucher.haushalt.farbe.hex, "#CFD8DC")
        XCTAssertEqual(Stromuebersicht.Herkunft.pvDirekt.farbe.hex, "#F2A900")
        XCTAssertEqual(Stromuebersicht.Herkunft.batterie.farbe.hex, "#7FA3B3")
        XCTAssertEqual(Stromuebersicht.Herkunft.netz.farbe.hex, "#E0533D")
    }

    func testBalkenTragenLabelUndWerteJeReihe() {
        let b = uebersicht(stuecke: [
            stueck("08", summen(wp: 2.0, ev: 0, rest: 0.5)),
            stueck("09", summen(wp: 0, ev: 7.4, rest: 0.6)),
        ])
        let balken = Stromuebersicht.verbrauch(b)
        XCTAssertEqual(balken.map(\.wort), ["08", "09"])
        XCTAssertEqual(balken[0].werte, [2.0, 0, 0.5])
        XCTAssertEqual(balken[1].werte, [0, 7.4, 0.6])
        XCTAssertEqual(balken[0].nummer, 0)
        XCTAssertEqual(balken[1].nummer, 1)
    }

    func testHerkunftsbalkenNehmenDieDreiQuellenfelder() {
        let b = uebersicht(stuecke: [stueck("12", summen(pvDirekt: 3.5, batterie: 1.25, netz: 0))])
        XCTAssertEqual(Stromuebersicht.herkunft(b)[0].werte, [3.5, 1.25, 0])
    }

    /// **Ein fehlendes Feld ist im Balken eine Null**, anders als in den Kacheln
    /// (`charts.ts:84`).
    func testFehlendeFelderSindImBalkenNullen() {
        let b = uebersicht(stuecke: [stueck("10", EnergyTotalsOut())])
        XCTAssertEqual(Stromuebersicht.verbrauch(b)[0].werte, [0, 0, 0])
        XCTAssertEqual(Stromuebersicht.herkunft(b)[0].werte, [0, 0, 0])
    }

    /// Auf zwei Stellen, wie die Vorlage die Balkenwerte rundet (`charts.ts:85`).
    func testBalkenwerteAufZweiStellen() {
        let b = uebersicht(stuecke: [stueck("10", summen(wp: 1.23456, ev: 0.005, rest: 9.994))])
        XCTAssertEqual(Stromuebersicht.verbrauch(b)[0].werte, [1.23, 0.01, 9.99])
    }

    func testOhneStueckeKeineBalken() {
        XCTAssertTrue(Stromuebersicht.verbrauch(uebersicht()).isEmpty)
        XCTAssertTrue(Stromuebersicht.herkunft(nil).isEmpty)
    }

    // MARK: - Die Ablesung eines Balkens

    /// Reihen mit Null fallen weg, die Summe bleibt die des ganzen Stapels
    /// (`charts.ts:66-73`).
    func testAblesungNenntNurReihenUngleichNull() {
        let b = uebersicht(stuecke: [stueck("08", summen(wp: 2.0, ev: 0, rest: 0.5))])
        let balken = Stromuebersicht.verbrauch(b)[0]
        let a = Stromuebersicht.ablesung(
            balken, namen: Stromuebersicht.Verbraucher.allCases.map(\.name))
        XCTAssertEqual(a.wort, "08")
        XCTAssertEqual(a.zeilen.map(\.name), ["Wärmepumpe", "Haushalt"])
        XCTAssertEqual(a.zeilen.map(\.wert), [
            "2,0\(Formate.schmalesLeerzeichen)kWh", "0,5\(Formate.schmalesLeerzeichen)kWh",
        ])
        XCTAssertEqual(a.summe, "Summe 2,5\(Formate.schmalesLeerzeichen)kWh")
    }

    /// Ein Stapel ohne jeden Wert nennt keine Reihe - und doch eine Summe, damit die Zeile
    /// nicht springt.
    func testAblesungEinesLeerenStapels() {
        let b = uebersicht(stuecke: [stueck("03", EnergyTotalsOut())])
        let a = Stromuebersicht.ablesung(
            Stromuebersicht.herkunft(b)[0],
            namen: Stromuebersicht.Herkunft.allCases.map(\.name))
        XCTAssertTrue(a.zeilen.isEmpty)
        XCTAssertEqual(a.summe, "Summe 0,0\(Formate.schmalesLeerzeichen)kWh")
    }

    /// Weniger Namen als Werte: die Ablesung nennt, was sie benennen kann, und greift nicht
    /// über den Rand.
    func testAblesungMitZuWenigenNamen() {
        let b = uebersicht(stuecke: [stueck("08", summen(wp: 2.0, ev: 1.0, rest: 0.5))])
        let a = Stromuebersicht.ablesung(Stromuebersicht.verbrauch(b)[0], namen: ["Wärmepumpe"])
        XCTAssertEqual(a.zeilen.map(\.name), ["Wärmepumpe"])
        XCTAssertEqual(a.summe, "Summe 3,5\(Formate.schmalesLeerzeichen)kWh")
    }

    /// Den Balken zu einem gelesenen Achsenwort finden - die Labels wiederholen sich nicht
    /// (`Bericht.swift` hat die Achsenwörter schon ohne Wiederholung).
    func testBalkenZuEinemGelesenenWort() {
        let b = uebersicht(stuecke: [
            stueck("08", summen(wp: 2.0)), stueck("09", summen(wp: 3.0)),
        ])
        let balken = Stromuebersicht.verbrauch(b)
        XCTAssertEqual(Pvbild.balken(balken, wort: "09")?.werte.first, 3.0)
        XCTAssertNil(Pvbild.balken(balken, wort: "99"))
        XCTAssertNil(Pvbild.balken(balken, wort: nil))
    }

    // MARK: - Strom im Überblick

    func testSpannenzeilenWoertlichNachDerVorlage() {
        let je: [Spanne: EnergySummaryOut] = [
            .tag: uebersicht(),
            .woche: uebersicht(summen(haus: 412.0, autarkie: 0.31, bezug: 98.4, einspeisung: 12.6)),
            .monat: uebersicht(summen(haus: 1680.5, autarkie: 0.24, bezug: 402.1, einspeisung: 44.2)),
            .jahr: uebersicht(summen(haus: 9120.0, autarkie: 0.46, bezug: 2104.9, einspeisung: 612.3)),
        ]
        let zeilen = Stromuebersicht.spannenzeilen(je)
        XCTAssertEqual(
            zeilen.map(\.wort),
            ["Verbrauch · kWh", "Autarkie", "Netzkosten", "Einspeiseerlös"])
        // „Netzkosten“ trägt `--alert` wie in der Vorlage (`HouseReport.tsx:78`:
        // `tone: "ember"`; `PeriodStrip.tsx:19`). Vorher war es `glut`, weil ``Kennzahl/Ton``
        // keinen Alarmton kannte.
        XCTAssertEqual(zeilen.map(\.ton), [.normal, .bernstein, .alarm, .normal])
        XCTAssertEqual(zeilen[0].werte, ["59,2", "412", "1681", "9120"])
        XCTAssertEqual(
            zeilen[1].werte.first, "11\(Formate.schmalesLeerzeichen)%")
        XCTAssertEqual(
            zeilen[2].werte.last, "2104,90\(Formate.schmalesLeerzeichen)€")
        XCTAssertEqual(
            zeilen[3].werte.last, "612,30\(Formate.schmalesLeerzeichen)€")
    }

    /// **Fehlt eine Spanne, steht ein Strich und nicht der Wert der Nachbarin**
    /// (`HouseReport.tsx:39`). Die Spalten stehen in der Reihenfolge von ``Spanne/allCases``.
    func testFehlendeSpanneGibtEinenStrich() {
        let zeilen = Stromuebersicht.spannenzeilen([.tag: uebersicht(), .jahr: uebersicht()])
        for zeile in zeilen {
            XCTAssertEqual(zeile.werte.count, 4, zeile.wort)
            XCTAssertEqual(zeile.werte[1], Formate.leer, zeile.wort)
            XCTAssertEqual(zeile.werte[2], Formate.leer, zeile.wort)
        }
        XCTAssertEqual(zeilen[0].werte[0], "59,2")
        XCTAssertEqual(zeilen[0].werte[3], "59,2")
    }

    func testOhneJedeSpanneVierZeilenVollerStriche() {
        let zeilen = Stromuebersicht.spannenzeilen([:])
        XCTAssertEqual(zeilen.count, 4)
        for zeile in zeilen {
            XCTAssertEqual(zeile.werte, Array(repeating: Formate.leer, count: 4), zeile.wort)
        }
    }

    /// **Die Schwelle liegt bei hundert und sie liegt davor** (`HouseReport.tsx:76`):
    /// 99,96 kWh wird auf eine Stelle gerundet und heißt dann „100,0“, 100 kWh heißt „100“.
    func testVerbrauchszeileAbHundertOhneNachkommastelle() {
        func verbrauch(_ kwh: Double?) -> String {
            Stromuebersicht.spannenzeilen([.tag: uebersicht(summen(haus: kwh))])[0].werte[0]
        }
        XCTAssertEqual(verbrauch(99.94), "99,9")
        XCTAssertEqual(verbrauch(99.96), "100,0")
        XCTAssertEqual(verbrauch(100), "100")
        XCTAssertEqual(verbrauch(100.4), "100")
        XCTAssertEqual(verbrauch(0), "0,0")
        XCTAssertEqual(verbrauch(nil), Formate.leer)
    }

    // MARK: - Methode

    func testMethodensatzNenntDenHaushaltsrestUndDieAufteilung() {
        XCTAssertTrue(Stromuebersicht.methodensatz.hasPrefix("Haushalt (Rest) ="))
        XCTAssertTrue(Stromuebersicht.methodensatz.contains("anteilig an ihrer Leistung je Minute"))
    }

    /// Die Kurzzeile ist die gemeinsame und keine zweite Fassung: `nil` heißt „noch keine
    /// Messdaten im Zeitraum“, Null heißt „Datenabdeckung 0 %“ (`ReportShell.tsx:166`).
    func testKurzzeileUnterscheidetFehlendeVonNullAbdeckung() {
        XCTAssertTrue(
            Wallbox.abdeckung(angaben(abdeckung: nil))
                .hasPrefix("noch keine Messdaten im Zeitraum"))
        XCTAssertTrue(
            Wallbox.abdeckung(angaben(abdeckung: 0))
                .hasPrefix("Datenabdeckung 0\(Formate.schmalesLeerzeichen)%"))
        XCTAssertEqual(
            Wallbox.abdeckung(angaben(abdeckung: 0.61)),
            "Datenabdeckung 61\(Formate.schmalesLeerzeichen)% · Aufzeichnung seit 14.03.2026")
    }
}
