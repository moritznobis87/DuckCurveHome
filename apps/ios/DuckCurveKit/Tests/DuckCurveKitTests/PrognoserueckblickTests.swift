import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/forecast/Rueckblick.tsx`.
final class PrognoserueckblickTests: XCTestCase {

    private func wertung(
        n: Int, mae: Double = 0.4, bias: Double = 0, p95: Double = 1.2
    ) -> Wertung {
        Wertung(n: n, mae: mae, bias: bias, rmse: mae * 1.3, p95: p95)
    }

    private func vorlauf(_ name: String, n: Int) -> VorlaufOut {
        VorlaufOut(key: name, labelDe: "nächste \(name)", wertung: wertung(n: n))
    }

    private func reihe(
        _ key: String = "pv", name: String = "PV-Leistung", einheit: String = "kW",
        gesamt: Wertung? = nil, laeufe: Int = 184
    ) -> ReiheOut {
        ReiheOut(
            key: key, labelDe: name, einheit: einheit, gesamt: gesamt ?? wertung(n: 96),
            jeVorlauf: [vorlauf("0-1h", n: 48), vorlauf("1-3h", n: 48)], laeufe: laeufe)
    }

    private func verlauf(tage: Int = 7, reihen: [ReiheOut] = [], hinweise: [String] = [])
        -> ForecastHistoryOut
    {
        ForecastHistoryOut(
            generatedAt: "2026-11-20T14:35:00+01:00", von: "2026-11-13", bis: "2026-11-20",
            tage: tage, reihen: reihen, hinweiseDe: hinweise)
    }

    // MARK: - Der Kopf einer Reihenkarte

    func testDerKartenkopfTraegtDieEinheitDerReihe() {
        XCTAssertEqual(
            Prognosebild.Rueckblick.kopfkicker(reihe(einheit: "kW")), "PV-Leistung · kW")
        XCTAssertEqual(
            Prognosebild.Rueckblick.kopfkicker(
                reihe("t_aussen", name: "Außentemperatur", einheit: "K")),
            "Außentemperatur · K")
    }

    func testEinePositiveAbweichungTraegtDasPlusUndEineNegativeDasEchteMinus() {
        XCTAssertEqual(
            Prognosebild.Rueckblick.kopfrechts(reihe(gesamt: wertung(n: 96, bias: 0.12))),
            "96 Paare · Bias +0,12 kW")
        let minus = Prognosebild.Rueckblick.kopfrechts(
            reihe(gesamt: wertung(n: 96, bias: -0.12)))
        XCTAssertEqual(minus, "96 Paare · Bias \(Formate.minus)0,12 kW")
        XCTAssertFalse(minus.contains("+"))
    }

    func testEineAbweichungVonGenauNullTraegtKeinVorzeichen() {
        XCTAssertEqual(
            Prognosebild.Rueckblick.kopfrechts(reihe(gesamt: wertung(n: 4, bias: 0))),
            "4 Paare · Bias 0,00 kW")
    }

    func testOhnePaareNenntDerKopfDieLaeufeUndNichtEineNullAlsMessung() {
        XCTAssertEqual(
            Prognosebild.Rueckblick.kopfrechts(
                reihe(gesamt: wertung(n: 0, mae: 0, bias: 0, p95: 0), laeufe: 14)),
            "14 Läufe, keine Paare")
    }

    // MARK: - Die Lesehilfe

    func testDieLesehilfeNenntTageUndLaeufeNurMitAntwort() {
        XCTAssertNil(
            Prognosebild.Rueckblick.lesehilfeRechts(nil),
            "ohne Antwort wäre „0 Läufe im Bestand“ eine Aussage über die Leitung")
        XCTAssertEqual(
            Prognosebild.Rueckblick.lesehilfeRechts(
                verlauf(tage: 30, reihen: [reihe(laeufe: 184), reihe("t", laeufe: 184)])),
            "30 Tage · 184 Läufe im Bestand")
    }

    func testDieLaeufeWerdenNichtSummiertSondernSindDieGroessteZahl() {
        let v = verlauf(reihen: [reihe("pv", laeufe: 184), reihe("t", laeufe: 180)])
        XCTAssertEqual(Prognosebild.Rueckblick.laeufe(v), 184, "es sind dieselben Läufe")
    }

    func testOhneReihenUndOhneAntwortSindEsNullLaeufe() {
        XCTAssertEqual(Prognosebild.Rueckblick.laeufe(verlauf(reihen: [])), 0)
        XCTAssertEqual(Prognosebild.Rueckblick.laeufe(nil), 0)
        XCTAssertEqual(
            Prognosebild.Rueckblick.lesehilfeRechts(verlauf(tage: 3, reihen: [])),
            "3 Tage · 0 Läufe im Bestand",
            "eine Antwort ohne Reihen ist eine Antwort - die Null ist hier gemessen")
    }

    // MARK: - Der Fehler der zweiten Abfrage

    func testOhneFehlerStehtKeinSatz() {
        XCTAssertNil(Prognosebild.Rueckblick.fehlersatz(nil))
    }

    func testDieMeldungDesDienstesWirdAngezeigtUndNichtErsetzt() {
        let f = ApiFehler(
            code: "upstream_unreachable", meldung: "Die Bridge antwortet nicht.", status: 502)
        XCTAssertEqual(Prognosebild.Rueckblick.fehlersatz(f), "Die Bridge antwortet nicht.")
    }

    func testOhneMeldungStehtDerSatzDerVorlage() {
        for leer in ["", "   ", "\n"] {
            let f = ApiFehler(code: "unknown", meldung: leer, status: 500)
            XCTAssertEqual(
                Prognosebild.Rueckblick.fehlersatz(f), "Rückblick nicht verfügbar.",
                "ein Fehler ohne Satz darf nicht als leere Zeile erscheinen")
        }
    }

    func testEinNetzfehlerBehaeltSeinenEigenenSatz() {
        XCTAssertEqual(
            Prognosebild.Rueckblick.fehlersatz(.netz("Zeitüberschreitung")),
            "Keine Verbindung zum Haus. (Zeitüberschreitung)")
    }

    // MARK: - Wie viele Spalten der Rückblick hat

    func testJedeReiheBekommtEineGleichBreiteSpalte() {
        XCTAssertEqual(Prognosebild.Rueckblick.spalten(reihen: 1), [1])
        XCTAssertEqual(Prognosebild.Rueckblick.spalten(reihen: 2), [1, 1])
        XCTAssertEqual(Prognosebild.Rueckblick.spalten(reihen: 6), [1, 1, 1, 1, 1, 1])
    }

    func testKeineReiheErgibtEineSpalteUndNichtKeine() {
        XCTAssertEqual(
            Prognosebild.Rueckblick.spalten(reihen: 0), [1],
            "`max(1, reihen.length)` der Vorlage - eine leere Spalte, keine Spalte von null")
        XCTAssertEqual(Prognosebild.Rueckblick.spalten(reihen: -3), [1])
    }
}
