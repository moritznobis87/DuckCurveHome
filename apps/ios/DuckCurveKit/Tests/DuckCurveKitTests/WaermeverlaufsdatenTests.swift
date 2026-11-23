import XCTest

@testable import DuckCurveKit

/// Gegen `apps/web/src/components/reports/charts.ts:778-886` und
/// `apps/web/src/components/reports/HeatOverview.tsx:232, 352-369`.
///
/// **Der Grund für diese Datei ist eine verbotene Summe.** Der Tagesverlauf der App hat
/// `stove_room_kw` in den Zufuhrstapel gerechnet; die Vorlage verbietet das ausdrücklich im
/// Kommentar („sonst läse man eine Summe, die es nicht gibt“, `charts.ts:781-784`). Solange die
/// Rechnung in der `View` lag, konnte kein Test sie halten.
final class WaermeverlaufsdatenTests: XCTestCase {

    private func punkt(
        _ iso: String, wp: Double? = nil, wasser: Double? = nil, raum: Double? = nil,
        entnahme: Double? = nil, verlust: Double? = nil, puffer: Double? = nil
    ) -> HeatBalancePointOut {
        HeatBalancePointOut(
            ts: iso, heatPumpKw: wp, stoveWaterKw: wasser, stoveRoomKw: raum, drawKw: entnahme,
            lossKw: verlust, bufferKwh: puffer)
    }

    // MARK: - Der Stapel

    func testDerStapelEndetNachZweiSchichtenUndDieRaumwaermeStehtDaneben() {
        let s = Waermeuebersicht.verlaufsstapel([
            punkt("2026-11-17T08:00:00+01:00", wp: 2.0, wasser: 1.5, raum: 3.0)
        ])
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s[0].stapelWp, 2.0)
        XCTAssertEqual(
            s[0].stapelZufuhr, 3.5,
            "Die Zufuhr ist Wärmepumpe plus Ofenwasser - die Raumwärme geht nicht in den Puffer.")
        XCTAssertEqual(s[0].raumKw, 3.0, "Sie bleibt als eigene Größe erhalten.")
        XCTAssertNotEqual(s[0].stapelZufuhr, 6.5, "6,5 wäre die Summe, die es nicht gibt.")
    }

    func testOhneOfenIstDieZufuhrDieWaermepumpeAllein() {
        let s = Waermeuebersicht.verlaufsstapel([punkt("2026-11-17T08:00:00+01:00", wp: 2.4)])
        XCTAssertEqual(s[0].stapelWp, 2.4)
        XCTAssertEqual(s[0].stapelZufuhr, 2.4)
        XCTAssertNil(s[0].raumKw)
    }

    /// Eine Lücke bleibt eine Lücke (`connectNulls: false`, `charts.ts:799`).
    func testEineMinuteOhneJedeZufuhrmessungBleibtLeerUndWirdNichtNull() {
        let s = Waermeuebersicht.verlaufsstapel([
            punkt("2026-11-17T08:00:00+01:00", raum: 3.0, entnahme: 1.1)
        ])
        XCTAssertNil(s[0].stapelWp, "Null hieße, es sei nichts gelaufen.")
        XCTAssertNil(s[0].stapelZufuhr)
        XCTAssertEqual(s[0].raumKw, 3.0, "Die Raumwärme hängt nicht am Stapel.")
        XCTAssertEqual(s[0].entnahmeKw, 1.1)
    }

    /// Ist nur eine der beiden Zufuhren gemessen, hat der Stapel eine Kante und kein Loch.
    func testNurDasOfenwasserGemessenGibtEineKanteAbNull() {
        let s = Waermeuebersicht.verlaufsstapel([punkt("2026-11-17T08:00:00+01:00", wasser: 1.5)])
        XCTAssertEqual(s[0].stapelWp, 0)
        XCTAssertEqual(s[0].stapelZufuhr, 1.5)
        XCTAssertNil(s[0].wpKw, "Gemessen ist sie nicht - in der Ablesung steht kein Wert.")
    }

    func testDerStapelWirdNachZeitGeordnetUndZeilenOhneZeitstempelFallenWeg() {
        let s = Waermeuebersicht.verlaufsstapel([
            punkt("2026-11-17T09:00:00+01:00", wp: 2),
            punkt("kein Zeitstempel", wp: 9),
            punkt("2026-11-17T08:00:00+01:00", wp: 1),
        ])
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.map(\.wpKw), [1, 2])
    }

    func testDerLeereTagGibtEinenLeerenStapel() {
        XCTAssertTrue(Waermeuebersicht.verlaufsstapel([]).isEmpty)
    }

    // MARK: - Die Abschnitte

    func testEineLueckeSchneidetDieReiheUndWirdNichtUeberbrueckt() {
        let s = Waermeuebersicht.verlaufsstapel([
            punkt("2026-11-17T08:00:00+01:00", wp: 1, entnahme: 0.5),
            punkt("2026-11-17T08:01:00+01:00", wp: 2, entnahme: 0.6),
            punkt("2026-11-17T08:02:00+01:00", entnahme: 0.7),
            punkt("2026-11-17T08:03:00+01:00", wp: 3, entnahme: 0.8),
        ])
        let a = Waermeuebersicht.verlaufsabschnitte(s, \.stapelWp)
        XCTAssertEqual(a.count, 2, "Die ungemessene Minute trennt zwei Abschnitte.")
        XCTAssertEqual(a[0].map(\.wpKw), [1, 2])
        XCTAssertEqual(a[1].map(\.wpKw), [3])
        XCTAssertEqual(
            Waermeuebersicht.verlaufsabschnitte(s, \.entnahmeKw).count, 1,
            "Die Entnahme ist durchgehend gemessen - ein Abschnitt.")
    }

    func testOhneEinenEinzigenWertGibtEsKeinenAbschnitt() {
        let s = Waermeuebersicht.verlaufsstapel([punkt("2026-11-17T08:00:00+01:00", wp: 1)])
        XCTAssertTrue(Waermeuebersicht.verlaufsabschnitte(s, \.verlustKw).isEmpty)
        XCTAssertTrue(Waermeuebersicht.verlaufsabschnitte([], \.wpKw).isEmpty)
    }

    // MARK: - Die Reihen

    func testDieSechsReihenTragenDieFarbenUndGestaltenDerVorlage() {
        let r = Waermeuebersicht.verlaufsreihen
        XCTAssertEqual(
            r.map(\.wort),
            [
                "Wärmepumpe", "Ofen (Wasser)", "Ofen (Raum)", "Entnahme",
                "Verlust an den Raum", "Pufferinhalt",
            ])
        // `charts.ts:876-883`.
        XCTAssertEqual(Waermeuebersicht.reiheWaermepumpe.farbe, Farbwert(0xE0966B))
        XCTAssertEqual(Waermeuebersicht.reiheOfenWasser.farbe, Farbwert(0xB5651D))
        XCTAssertEqual(Waermeuebersicht.reiheOfenRaum.farbe, Farbwert(0xB5651D))
        XCTAssertEqual(
            Waermeuebersicht.reiheEntnahme.farbe, Farbwert(0xCFD8DC),
            "C.house - nicht C.mist, das ist die Marke des Netzbezugs.")
        XCTAssertEqual(Waermeuebersicht.reiheVerlust.farbe, Farbwert(0xE0533D))
        XCTAssertEqual(
            Waermeuebersicht.reihePufferinhalt.farbe, Farbwert(0x7FA3B3),
            "C.mist - nicht das Grün von Marken.puffer.")
    }

    func testGestricheltIstGenauDasWasNichtDurchDenPufferGeht() {
        let gestrichelt = Waermeuebersicht.verlaufsreihen
            .filter { $0.gestalt == .gestrichelt }
            .map(\.wort)
        XCTAssertEqual(gestrichelt, ["Ofen (Raum)", "Verlust an den Raum"])
        XCTAssertEqual(Waermeuebersicht.reiheOfenRaum.strich, 1.5)
        XCTAssertEqual(Waermeuebersicht.reiheVerlust.strich, 1.5)
        XCTAssertEqual(Waermeuebersicht.reiheEntnahme.gestalt, .linie)
        XCTAssertEqual(Waermeuebersicht.reiheEntnahme.strich, 2)
    }

    func testDieFlaechendeckungenSindDieDerVorlageUndNichtDichter() {
        XCTAssertEqual(Waermeuebersicht.reiheWaermepumpe.flaechendeckung, 0.24)
        XCTAssertEqual(Waermeuebersicht.reiheOfenWasser.flaechendeckung, 0.28)
        XCTAssertEqual(Waermeuebersicht.reihePufferinhalt.flaechendeckung, 0.14)
        XCTAssertNil(Waermeuebersicht.reiheOfenRaum.flaechendeckung)
        XCTAssertNil(Waermeuebersicht.reiheEntnahme.flaechendeckung)
    }

    func testNurDerPufferinhaltStehtInKilowattstunden() {
        XCTAssertEqual(Waermeuebersicht.reihePufferinhalt.einheit, "kWh")
        XCTAssertTrue(
            Waermeuebersicht.verlaufsreihen.dropLast().allSatisfy { $0.einheit == "kW" })
    }

    // MARK: - Die Ablesung

    func testDieAblesungNimmtDenNaechstenPunktUndNenntDieEinheitJeReihe() {
        let s = Waermeuebersicht.verlaufsstapel([
            punkt("2026-11-17T08:00:00+01:00", wp: 1.0, puffer: 10.0),
            punkt("2026-11-17T09:00:00+01:00", wp: 2.04, wasser: 1.5, raum: 3.0, puffer: 12.36),
        ])
        let a = Waermeuebersicht.verlaufsablesung(s, zu: Zeit.ausIso("2026-11-17T08:50:00+01:00"))
        XCTAssertEqual(a?.uhrzeit, "09:00")
        XCTAssertEqual(a?.werte.map(\.wort), [
            "Wärmepumpe", "Ofen (Wasser)", "Ofen (Raum)", "Pufferinhalt",
        ])
        XCTAssertEqual(a?.werte.first?.wert, "2,0", "Eine Stelle, wie de1 in charts.ts:819.")
        XCTAssertEqual(a?.werte.first?.einheit, "kW")
        XCTAssertEqual(a?.werte.last?.wert, "12,4")
        XCTAssertEqual(a?.werte.last?.einheit, "kWh")
    }

    func testOhneFingerUndOhneReiheGibtEsKeineAblesung() {
        let s = Waermeuebersicht.verlaufsstapel([punkt("2026-11-17T08:00:00+01:00", wp: 1)])
        XCTAssertNil(Waermeuebersicht.verlaufsablesung(s, zu: nil))
        XCTAssertNil(Waermeuebersicht.verlaufsablesung([], zu: Date()))
    }

    /// Eine Minute, in der nichts gemessen ist, gibt keine leere Zeile mit einer Uhrzeit.
    func testEinePunktOhneJedenWertGibtKeineAblesung() {
        let s = Waermeuebersicht.verlaufsstapel([punkt("2026-11-17T08:00:00+01:00")])
        XCTAssertEqual(s.count, 1)
        XCTAssertNil(Waermeuebersicht.verlaufsablesung(s, zu: s[0].zeit))
    }

    // MARK: - Das Taktwort

    func testOhneUrteilStehtZuWenigDatenUndNichtNichts() {
        XCTAssertEqual(Waermeuebersicht.taktwort(CyclingStats()), "zu wenig Daten")
        XCTAssertEqual(
            Waermeuebersicht.taktwort(CyclingStats(verdict: .shortCycling)), "taktet häufig")
        XCTAssertEqual(Waermeuebersicht.taktwort(CyclingStats(verdict: .ok)), "unauffällig")
        XCTAssertEqual(Waermeuebersicht.taktwort(CyclingStats(verdict: .watch)), "grenzwertig")
        XCTAssertEqual(
            Waermeuebersicht.taktwort(CyclingStats(verdict: .unbekannt)), "zu wenig Daten",
            "Der Rückfall jeder erzeugten Aufzählung sagt dasselbe wie unknown.")
    }

    // MARK: - Wie gerechnet wird

    func testDieVierHandgeschriebenenAbsaetzeStehenImKern() {
        let s = Waermeuebersicht.methodensaetze
        XCTAssertEqual(s.count, 4)
        XCTAssertTrue(s[0].contains("keinen Wärmemengenzähler"))
        XCTAssertTrue(s[1].contains("Carnot-Zahlen"), "Die Umrechnung auf den wirklichen Vorlauf.")
        XCTAssertTrue(s[1].contains("58 °C"))
        XCTAssertTrue(s[2].contains("Rest der Bilanz"))
        XCTAssertTrue(s[2].contains("nicht zuzuordnen"))
        XCTAssertTrue(s[3].contains("entgangene Einspeisevergütung"))
        XCTAssertTrue(s.allSatisfy { !$0.isEmpty && !$0.contains("  ") })
    }

    func testDerVerlaufssatzZiehtDenHinweisDesDienstesAn() {
        let ohne = Waermeuebersicht.verlaufssatz(nil)
        XCTAssertTrue(ohne.hasSuffix("geht nicht durch den Puffer."))
        XCTAssertEqual(Waermeuebersicht.verlaufssatz(""), ohne, "Ein leeres Feld hängt nichts an.")
        XCTAssertEqual(
            Waermeuebersicht.verlaufssatz("Zwei Fühler fehlten."),
            "\(ohne) Zwei Fühler fehlten.")
    }

    func testDerMethodentitelIstDerDerVorlage() {
        XCTAssertEqual(Waermeuebersicht.methodentitel, "Wie gerechnet wird")
    }
}
