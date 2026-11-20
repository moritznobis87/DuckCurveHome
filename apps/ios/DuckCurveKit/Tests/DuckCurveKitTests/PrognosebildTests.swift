import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlagen `apps/web/src/components/forecast/ForecastPage.tsx` und `Rueckblick.tsx`.
final class PrognosebildTests: XCTestCase {

    /// Montag, der 16. November 2026, 00:00 in der Zeit des Hauses.
    private let tagIso = "2026-11-16"
    private var mitternacht: Date { Zeit.ausIso("2026-11-16T00:00:00+01:00")! }

    private func punkt(
        stunde: Double, ist: Double? = nil, dayAhead: Double? = nil, korrigiert: Double? = nil
    ) -> ForecastPointOut {
        ForecastPointOut(
            ts: Zeit.iso(mitternacht.addingTimeInterval(stunde * 3600)),
            actualKw: ist, dayAheadKw: dayAhead, latestKw: nil, correctedKw: korrigiert)
    }

    private func wertung(
        n: Int = 96, mae: Double = 0.5, bias: Double = 0, fehlerProzent: Double? = nil,
        ist: Double = 10, prognose: Double = 11
    ) -> ForecastScore {
        ForecastScore(
            n: n, maeKw: mae, biasKw: bias, rmseKw: mae * 1.4, energyForecastKwh: prognose,
            energyActualKwh: ist, energyErrorPct: fehlerProzent)
    }

    private func tag(
        _ day: String? = nil, punkte: [ForecastPointOut] = [], score: ForecastScore? = nil
    ) -> ForecastDayOut {
        ForecastDayOut(day: day ?? tagIso, issuedAt: nil, score: score, points: punkte)
    }

    private func tagesnote(
        _ day: String, fehlerProzent: Double? = nil, bias: Double = 0, prognose: Double = 11,
        ist: Double = 10, mae: Double = 0.5
    ) -> DailyScoreOut {
        DailyScoreOut(
            day: day, energyForecastKwh: prognose, energyActualKwh: ist,
            energyErrorPct: fehlerProzent, maeKw: mae, biasKw: bias, kGlobalAfter: 1)
    }

    private func bewertung(
        heute: ForecastDayOut? = nil, daily: [DailyScoreOut] = [],
        horizonte: [HorizonScoreOut] = [], quellen: [SourceOut] = [],
        korrektor: CorrectorState = CorrectorState()
    ) -> ForecastEvaluationOut {
        ForecastEvaluationOut(
            generatedAt: Zeit.iso(mitternacht.addingTimeInterval(13.5 * 3600)),
            stageDe: "Stufe 1 - Bias-Korrektur je Sonnenhöhe", sources: quellen,
            today: heute ?? tag(), yesterday: tag(Tag.plus(tagIso, -1)), daily: daily,
            horizons: horizonte, corrector: korrektor, correctionActive: true,
            nextChangesDe: [], runsKept: 42, notesDe: [])
    }

    private func klasse(
        _ name: String, faktor: Double? = nil, gestern: Double? = nil, letztes: Double? = nil,
        tage: Int? = nil
    ) -> BinCorrection {
        BinCorrection(
            bin: 0, labelDe: name, factor: faktor, previous: gestern, lastRatio: letztes,
            days: tage)
    }

    // MARK: - Die Tageskurve: Stunden seit Mitternacht des gezeigten Tages

    func testDieStundeZaehltSeitMitternachtDesGezeigtenTagesUndNichtSeitDemErstenPunkt() {
        let b = Prognosebild.tageskurve(
            tag(punkte: [punkt(stunde: 6, ist: 1), punkt(stunde: 12.25, ist: 4)]),
            heute: true, gerechnetAm: nil)
        XCTAssertEqual(b.ist.map(\.stunde), [6, 12.25])
    }

    func testEinUnbekannterKalendertagErgibtEinLeeresBildUndKeineAchseAusDemNichts() {
        let b = Prognosebild.tageskurve(
            tag("kein Tag", punkte: [punkt(stunde: 6, ist: 1)]), heute: true,
            gerechnetAm: mitternacht)
        XCTAssertTrue(b.leer)
        XCTAssertNil(b.jetztStunde)
    }

    func testEinTagOhnePunkteSagtDassErLeerIstStattEinLeeresGitterZuZeichnen() {
        let b = Prognosebild.tageskurve(tag(), heute: true, gerechnetAm: nil)
        XCTAssertTrue(b.leer)
        XCTAssertEqual(b.leistungsgrenze, 2, "mindestens zwei Kilowatt, sonst hat die Achse keine Mitte")
    }

    func testEineFehlendeMessungHinterlaesstEineLueckeUndKeineNullKilowatt() {
        let b = Prognosebild.tageskurve(
            tag(punkte: [
                punkt(stunde: 6, ist: 1, dayAhead: 1.2),
                punkt(stunde: 7, ist: nil, dayAhead: 2.4),
                punkt(stunde: 8, ist: 3, dayAhead: 3.1),
            ]), heute: true, gerechnetAm: nil)
        XCTAssertEqual(b.ist.map(\.stunde), [6, 8], "eine Null hiesse „die Anlage stand\"")
        XCTAssertEqual(b.dayAhead.count, 3)
        XCTAssertFalse(b.leer)
    }

    func testDerKorrigierteLaufStehtNurBeiHeuteUndBeiGesternNicht() {
        let punkte = [punkt(stunde: 12, ist: 3, dayAhead: 2.8, korrigiert: 3.1)]
        XCTAssertEqual(
            Prognosebild.tageskurve(tag(punkte: punkte), heute: true, gerechnetAm: nil)
                .korrigiert.map(\.wert), [3.1])
        XCTAssertTrue(
            Prognosebild.tageskurve(tag(punkte: punkte), heute: false, gerechnetAm: nil)
                .korrigiert.isEmpty,
            "der juengste Lauf ist eine Aussage ueber den laufenden Tag")
    }

    // MARK: - Die Leistungsgrenze der Hochachse

    func testDieLeistungsgrenzeIstGeradeUndLaesstZehnProzentLuft() {
        let b = Prognosebild.tageskurve(
            tag(punkte: [punkt(stunde: 12, ist: 4.3)]), heute: true, gerechnetAm: nil)
        XCTAssertEqual(b.leistungsgrenze, 6, "4,3 mal 1,1 ist 4,73, aufgerundet auf gerade 6")
    }

    func testDieLeistungsgrenzeNimmtAlleDreiReihenUndNichtNurDasIst() {
        let b = Prognosebild.tageskurve(
            tag(punkte: [punkt(stunde: 12, ist: 2, dayAhead: 1.5, korrigiert: 5)]),
            heute: true, gerechnetAm: nil)
        XCTAssertEqual(b.leistungsgrenze, 6, "ueber dem Ist allein waere es 4 und der korrigierte Lauf abgeschnitten")
    }

    // MARK: - Die Jetzt-Linie kommt aus der Antwort

    func testDieJetztLinieKommtAusDemZeitpunktDerAntwortUndNichtAusDerGeraeteuhr() {
        let b = Prognosebild.tageskurve(
            tag(punkte: [punkt(stunde: 13, ist: 2)]), heute: true,
            gerechnetAm: mitternacht.addingTimeInterval(13.5 * 3600))
        XCTAssertEqual(b.jetztStunde ?? -1, 13.5, accuracy: 0.0001)
    }

    func testGesternHatKeineJetztLinieAuchWennEinZeitpunktMitgegebenWird() {
        let b = Prognosebild.tageskurve(
            tag(punkte: [punkt(stunde: 13, ist: 2)]), heute: false,
            gerechnetAm: mitternacht.addingTimeInterval(13.5 * 3600))
        XCTAssertNil(b.jetztStunde)
    }

    func testEineJetztLinieAusserhalbDesTagesIstKeineJetztLinieSondernEinStrichAmRand() {
        let b = Prognosebild.tageskurve(
            tag(punkte: [punkt(stunde: 13, ist: 2)]), heute: true,
            gerechnetAm: mitternacht.addingTimeInterval(25 * 3600))
        XCTAssertNil(b.jetztStunde)
    }

    // MARK: - Die fünf Kacheln

    func testDieFuenfKachelnStehenInDerReihenfolgeDerVorlage() {
        let k = Prognosebild.kacheln(bewertung())
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Heute · Ist bis jetzt", "Heute · Day-ahead bis jetzt", "Heute · Abweichung",
                "MAE · 7 Tage", "Tage innerhalb ±15 %",
            ])
        XCTAssertEqual(k.map(\.einheit), ["kWh", "kWh", nil, "kW", nil])
    }

    func testOhneBewertungDesTagesStehtInJederKachelEinStrichUndKeineNull() {
        let k = Prognosebild.kacheln(bewertung())
        XCTAssertEqual(k[0].wert, Formate.leer)
        XCTAssertEqual(k[1].wert, Formate.leer)
        XCTAssertEqual(k[2].wert, Formate.leer)
        XCTAssertEqual(k[3].wert, Formate.leer, "ohne Quelle gibt es kein MAE")
    }

    func testDieErstenVierKachelnTragenDieZahlenDesTagesUndDerErstenQuelle() {
        let k = Prognosebild.kacheln(
            bewertung(
                heute: tag(score: wertung(fehlerProzent: 12.4, ist: 18.62, prognose: 16.55)),
                quellen: [
                    SourceOut(name: "bridge_pv", labelDe: "Bridge", weight: 1, mae7dKw: 0.761, active: true),
                    SourceOut(name: "solcast", labelDe: "Solcast", weight: 0, mae7dKw: 9, active: false),
                ]))
        XCTAssertEqual(k[0].wert, "18,6")
        XCTAssertEqual(k[1].wert, "16,6")
        XCTAssertEqual(k[2].wert, "+12,4" + Formate.schmalesLeerzeichen + "%")
        XCTAssertEqual(k[3].wert, "0,76", "die erste Quelle, nicht die mit dem besten MAE")
    }

    func testDieAbweichungskachelSchlaegtErstJenseitsVonFuenfzehnProzentUm() {
        func ton(_ pct: Double) -> Kennzahl.Ton {
            Prognosebild.kacheln(bewertung(heute: tag(score: wertung(fehlerProzent: pct))))[2].ton
        }
        XCTAssertEqual(ton(15), .normal, "genau an der Grenze ist noch nicht darueber")
        XCTAssertEqual(ton(-15), .normal)
        XCTAssertEqual(ton(15.1), .glut)
        XCTAssertEqual(ton(-15.1), .glut, "zu wenig ist so weit daneben wie zu viel")
    }

    func testDieTrefferkachelZaehltNurDieLetztenSiebenTage() {
        let pct: [Double?] = [1, 2, 20, 10, nil, 15, -15, 16, -3]
        let daily = pct.enumerated().map {
            tagesnote(Tag.plus("2026-11-10", $0.offset), fehlerProzent: $0.element)
        }
        let k = Prognosebild.kacheln(bewertung(daily: daily))
        XCTAssertEqual(
            k[4].wert, "4 / 7",
            "die beiden Treffer der ersten zwei Tage liegen ausserhalb des Fensters")
    }

    func testEinTagOhneGemesseneAbweichungZaehltNichtAlsTreffer() {
        let daily = (0..<3).map { tagesnote(Tag.plus("2026-11-14", $0), fehlerProzent: nil) }
        XCTAssertEqual(
            Prognosebild.kacheln(bewertung(daily: daily))[4].wert, "0 / 3",
            "„nichts gemessen\" ist kein Treffer")
    }

    // MARK: - Der Bias der kurzen Woche

    func testBias7IstDasMittelDerLetztenSiebenTageUndNichtAllerTage() {
        let daily = (0..<9).map {
            tagesnote(Tag.plus("2026-11-10", $0), bias: Double($0))
        }
        XCTAssertEqual(Prognosebild.bias7(daily) ?? 0, 5, accuracy: 0.0001)
    }

    func testOhneTageGibtEsKeinenBiasUndKeineNull() {
        XCTAssertNil(Prognosebild.bias7([]))
    }

    // MARK: - Die Korrekturfaktoren

    func testDieSaeuleZeigtDieAbweichungVonEinsInProzentpunktenAufEinZehntelGerundet() {
        let bild = Prognosebild.faktorbalken(
            CorrectorState(bins: [klasse("0-10°", faktor: 1.0734)]))
        XCTAssertEqual(bild.klassen.first?.abweichung, 7.3)
        XCTAssertEqual(bild.klassen.first?.faktor, 1.0734, "der Faktor selbst bleibt ungerundet")
    }

    func testDieFaktorachseIstSymmetrischUndNimmtAlleDreiReihen() {
        let nurSaeulen = Prognosebild.faktorbalken(
            CorrectorState(bins: [klasse("0-10°", faktor: 1.02)]))
        XCTAssertEqual(nurSaeulen.spanne, -10...10)

        let mitRaute = Prognosebild.faktorbalken(
            CorrectorState(bins: [klasse("0-10°", faktor: 1.02, gestern: 1.18)]))
        XCTAssertEqual(
            mitRaute.spanne, -30...30,
            "eine Spanne nur ueber die Saeulen schneidet die Raute von gestern ab")
    }

    func testDieFaktorachseIstMindestensZehnProzentpunkteWeit() {
        let bild = Prognosebild.faktorbalken(
            CorrectorState(bins: [klasse("0-10°", faktor: 1.001, gestern: 0.999)]))
        XCTAssertEqual(
            bild.spanne, -10...10,
            "ein ruhiger Tag soll nicht aus einem halben Prozentpunkt ein Ereignis machen")
    }

    func testEinFaktorUnterEinsWirdMarkiertUndEinFehlenderNicht() {
        let bild = Prognosebild.faktorbalken(
            CorrectorState(bins: [
                klasse("0-10°", faktor: 0.94), klasse("10-20°", faktor: 1),
                klasse("20-30°", faktor: 1.06), klasse("über 45°"),
            ]))
        XCTAssertEqual(bild.klassen.map(\.unterEins), [true, false, false, false])
        XCTAssertNil(bild.klassen.last?.abweichung, "ohne Faktor gibt es keine Saeule")
    }

    func testOhneKlassenBleibtDieAchseStehenUndDieListeIstLeer() {
        let bild = Prognosebild.faktorbalken(CorrectorState())
        XCTAssertTrue(bild.klassen.isEmpty)
        XCTAssertEqual(bild.spanne, -10...10)
    }

    func testDieKlassenBehaltenDieReihenfolgeDerSonnenhoehen() {
        let namen = ["0-10°", "10-20°", "20-30°", "30-45°", "über 45°"]
        let bild = Prognosebild.faktorbalken(
            CorrectorState(bins: namen.map { klasse($0, faktor: 1) }))
        XCTAssertEqual(bild.klassen.map(\.name), namen)
        XCTAssertEqual(bild.klassen.map(\.id), namen)
    }

    // MARK: - Die Fehlerbalken

    func testDieHorizontbalkenTragenDenBetragDesBiasUndNichtDenBias() {
        let b = Prognosebild.horizonte(
            bewertung(horizonte: [
                HorizonScoreOut(
                    key: "0-3h", labelDe: "nächste 3 Stunden",
                    score: wertung(n: 48, mae: 0.42, bias: -0.31))
            ]))
        XCTAssertEqual(b.first?.zweites, 0.31, "zwei Saeulen auf einer Achse ab null")
        XCTAssertEqual(b.first?.mae, 0.42)
        XCTAssertEqual(b.first?.langname, "nächste 3 Stunden")
        XCTAssertEqual(b.first?.name, "0-3h")
        XCTAssertEqual(b.first?.paare, 48)
    }

    func testEineHorizontklasseOhnePaareZeichnetKeineSaeule() {
        let b = Prognosebild.horizonte(
            bewertung(horizonte: [
                HorizonScoreOut(
                    key: "12-36h", labelDe: "12 bis 36 Stunden",
                    score: wertung(n: 0, mae: 0, bias: 0))
            ]))
        XCTAssertNil(b.first?.mae, "eine Null-Saeule hiesse „kein Fehler\"")
        XCTAssertNil(b.first?.zweites)
        XCTAssertEqual(b.first?.paare, 0)
    }

    func testDieVorlaufbalkenTragenDenRandVonFuenfundneunzigProzentAlsZweiteGroesse() {
        let reihe = ReiheOut(
            key: "heizlast", labelDe: "Heizlast aus der Temperatur", einheit: "kW",
            gesamt: Wertung(n: 10, mae: 0.5, bias: 0.1, rmse: 0.7, p95: 1.2),
            jeVorlauf: [
                VorlaufOut(
                    key: "0-1h", labelDe: "bis 1 Stunde",
                    wertung: Wertung(n: 10, mae: 0.5, bias: 0.1, rmse: 0.7, p95: 1.2)),
                VorlaufOut(
                    key: "1-3h", labelDe: "1 bis 3 Stunden",
                    wertung: Wertung(n: 0, mae: 0, bias: 0, rmse: 0, p95: 0)),
            ], laeufe: 7)
        let b = Prognosebild.vorlaufbalken(reihe)
        XCTAssertEqual(b.first?.zweites, 1.2)
        XCTAssertNil(b.last?.zweites, "ohne Paare auch kein Rand")
        XCTAssertNil(b.last?.mae)
    }

    func testDieVorlaufbalkenBehaltenDieSechsKlassenInIhrerReihenfolge() {
        let namen = ["0-1h", "1-3h", "3-6h", "6-12h", "12-24h", "24-48h"]
        let reihe = ReiheOut(
            key: "heizlast", labelDe: "Heizlast", einheit: "kW",
            gesamt: Wertung(n: 0, mae: 0, bias: 0, rmse: 0, p95: 0),
            jeVorlauf: namen.map {
                VorlaufOut(
                    key: $0, labelDe: $0,
                    wertung: Wertung(n: 1, mae: 0.3, bias: 0, rmse: 0.3, p95: 0.6))
            }, laeufe: 3)
        XCTAssertEqual(Prognosebild.vorlaufbalken(reihe).map(\.name), namen)
    }

    func testEineReiheOhneVorlaufklassenGibtKeineBalken() {
        let reihe = ReiheOut(
            key: "heizlast", labelDe: "Heizlast", einheit: "kW",
            gesamt: Wertung(n: 0, mae: 0, bias: 0, rmse: 0, p95: 0), jeVorlauf: [], laeufe: 0)
        XCTAssertTrue(Prognosebild.vorlaufbalken(reihe).isEmpty)
    }

    // MARK: - Die Tagesenergie

    func testDieTagesenergieNimmtDieLetztenVierzehnTageUndNichtAlle() {
        let daily = (0..<20).map { tagesnote(Tag.plus("2026-11-01", $0)) }
        let paare = Prognosebild.tagesenergie(daily)
        XCTAssertEqual(paare.count, 14)
        XCTAssertEqual(paare.first?.tag, "2026-11-07")
        XCTAssertEqual(paare.last?.tag, "2026-11-20")
    }

    func testDieTagesenergieSortiertNachTagUndNichtNachEingang() {
        let daily = ["2026-11-18", "2026-11-16", "2026-11-17"].map { tagesnote($0) }
        XCTAssertEqual(
            Prognosebild.tagesenergie(daily).map(\.tag),
            ["2026-11-16", "2026-11-17", "2026-11-18"])
    }

    func testJederTagTraegtZweiFormateDesselbenDatumsFuerAchseUndAuskunft() {
        let paar = Prognosebild.tagesenergie([tagesnote("2026-11-16")]).first
        XCTAssertEqual(paar?.kurz, "Mo", "an der Achse stehen zwei Zeichen")
        XCTAssertEqual(paar?.wochentag, "Mo, 16.11.", "in der Auskunft der ganze Kopf")
    }

    func testEinUnbekannterTagBehaeltSeinenEigenenTextStattEinerErfundenenBeschriftung() {
        let paar = Prognosebild.tagesenergie([tagesnote("Montag")]).first
        XCTAssertEqual(paar?.kurz, "Montag")
    }

    func testDieTagesenergieTraegtBeideMengenUndDieAbweichungDazu() {
        let paar = Prognosebild.tagesenergie(
            [tagesnote("2026-11-16", fehlerProzent: -3, prognose: 16.5, ist: 16, mae: 0.42)]
        ).first
        XCTAssertEqual(paar?.prognose, 16.5)
        XCTAssertEqual(paar?.ist, 16)
        XCTAssertEqual(paar?.fehlerProzent, -3)
        XCTAssertEqual(paar?.mae, 0.42)
    }

    func testOhneTageUndOhneObergrenzeGibtEsKeineSaeulenpaare() {
        XCTAssertTrue(Prognosebild.tagesenergie([]).isEmpty)
        XCTAssertTrue(
            Prognosebild.tagesenergie([tagesnote("2026-11-16")], hoechstens: 0).isEmpty,
            "eine Obergrenze von null darf nicht hinten anfangen zu zaehlen")
    }

    // MARK: - Prozent mit Vorzeichen

    func testDasVorzeichenStehtNurUeberNullUndDasMinusIstEinEchtesMinus() {
        let s = Formate.schmalesLeerzeichen
        XCTAssertEqual(Formate.prozentpunkte(12.4), "+12,4" + s + "%")
        XCTAssertEqual(Formate.prozentpunkte(-3), Formate.minus + "3,0" + s + "%")
        XCTAssertEqual(Formate.prozentpunkte(0), "0,0" + s + "%", "eine Null hat kein Vorzeichen")
        XCTAssertEqual(Formate.prozentpunkte(nil), Formate.leer)
        XCTAssertEqual(Formate.prozentpunkte(12.4, vorzeichen: false), "12,4" + s + "%")
        XCTAssertEqual(Formate.prozentpunkte(12.44, stellen: 0), "+12" + s + "%")
    }
}
