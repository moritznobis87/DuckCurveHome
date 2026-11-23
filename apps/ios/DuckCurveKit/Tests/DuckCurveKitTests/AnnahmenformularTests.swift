import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/settings/HeatSettings.tsx` und
/// `apps/web/src/app/waerme/annahmen/page.tsx`.
final class AnnahmenformularTests: XCTestCase {

    /// Die Beispielwerte der Vorlage - dreizehn verschiedene Zahlen, damit ein vertauschtes
    /// Paar auffällt.
    private let werte: [Double] = [11.9, 10, 3.2, 1.8, 0.911, 4.9, 450, 1000, 50, 0.004, 17, 0.5, 21]

    private func konfiguration(
        ofen: Bool = true, puffer: Bool = true, haus: Bool = true,
        kurve: [[Double]] = [[-7, 2.4], [2, 3], [7, 3.5], [15, 4.2]]
    ) -> HemsConfig {
        HemsConfig(
            buffer: puffer
                ? BufferConfig(
                    volumeLiters: 1000, targetTemperatureC: 50, lossKwPerK: 0.004, ambientC: 17,
                    lossUsefulFraction: 0.5)
                : nil,
            heatDemand: haus || !kurve.isEmpty
                ? HeatDemandConfig(indoorTargetC: haus ? 21 : nil, copCurve: kurve) : nil,
            stove: ofen
                ? StoveConfig(
                    nominalHeatKw: 11.9, waterHeatKw: 10, combustionEfficiency: 0.911,
                    minHeatKw: 3.2, minWaterHeatKw: 1.8, pelletPriceEurPerT: 450,
                    pelletKwhPerKg: 4.9)
                : nil)
    }

    // MARK: - Die Tabelle selbst

    func testDieDreizehnFelderStehenInSachreihenfolgeUndNichtAlphabetisch() {
        let schluessel = Annahmenfelder.alle.map(\.schluessel)
        XCTAssertEqual(
            schluessel,
            [
                "stove_nominal_heat_kw", "stove_water_heat_kw", "stove_min_heat_kw",
                "stove_min_water_heat_kw", "stove_combustion_efficiency", "pellet_kwh_per_kg",
                "pellet_price_eur_per_t", "buffer_volume_liters", "buffer_target_temperature_c",
                "buffer_loss_kw_per_k", "buffer_ambient_c", "buffer_loss_useful_fraction",
                "indoor_target_c",
            ])
        XCTAssertNotEqual(
            schluessel, schluessel.sorted(),
            "Alphabetisch sortierte Schemaschlüssel waren genau der Fehler der alten Seite.")
    }

    func testDieBeidenGleichLautendenZeilenTragenVerschiedeneKennungen() {
        let woerter = Annahmenfelder.alle.map(\.wort)
        XCTAssertEqual(
            woerter.filter { $0 == "Ofen: davon ins Wasser" }.count, 2,
            "Volllast und Minimallast heißen in der Vorlage gleich.")
        XCTAssertEqual(Set(Annahmenfelder.alle.map(\.id)).count, 13, "Sonst fehlt eine Zeile.")
    }

    func testNurDerAufstellraumDesPuffersDarfNegativWerden() {
        XCTAssertEqual(
            Annahmenfelder.alle.filter(\.darfNegativ).map(\.schluessel), ["buffer_ambient_c"],
            "Nur dieses Feld braucht eine Tastatur mit Minuszeichen.")
    }

    // MARK: - Flach gegen verschachtelt

    func testJedesFeldLiestSeinenEigenenWertAusDerVerschachteltenKonfiguration() {
        let cfg = konfiguration()
        XCTAssertEqual(Annahmenfelder.alle.map { $0.lesen(cfg) }, werte.map { Optional($0) })
    }

    func testJedesFeldSchreibtGenauSeinenEigenenSchluesselUndKeinenZweiten() throws {
        for feld in Annahmenfelder.alle {
            var patch = HeatConfigIn()
            feld.schreiben(&patch, 42.5)
            let rohdaten = try JSONEncoder().encode(patch)
            let objekt = try JSONSerialization.jsonObject(with: rohdaten) as? [String: Any]
            XCTAssertEqual(
                objekt?.keys.sorted(), [feld.schluessel],
                "„\(feld.wort)\" schreibt nicht das, was seine Kennung behauptet.")
            XCTAssertEqual(objekt?[feld.schluessel] as? Double, 42.5)
        }
    }

    func testEineFehlendeGruppeMachtNurIhreEigenenFelderLeer() {
        let nurOfen = konfiguration(puffer: false, haus: false)
        let gelesen = Annahmenfelder.alle.map { $0.lesen(nurOfen) }
        XCTAssertEqual(Array(gelesen.prefix(7)), werte.prefix(7).map { Optional($0) })
        XCTAssertTrue(gelesen.dropFirst(7).allSatisfy { $0 == nil })
    }

    func testOhneJedeKonfigurationBleibenAlleDreizehnFelderLeerUndNichtNull() {
        let entwuerfe = Annahmenfelder.entwuerfe(HemsConfig())
        XCTAssertEqual(entwuerfe.count, 13)
        XCTAssertTrue(
            entwuerfe.values.allSatisfy(\.isEmpty),
            "Ein Strich wäre etwas, das jemand erst löschen muss.")
    }

    // MARK: - Zwei Spalten

    func testDieSpaltenTeilenSichDieFelderStattBeiEinerFestenZahlZuTrennen() {
        let spalten = Annahmenfelder.spalten()
        XCTAssertEqual(spalten.map(\.count), [7, 6], "13 Felder werden 7 und 6.")
    }

    func testDieSpaltenVerlierenKeinFeldUndVertauschenKeines() {
        let wieder = Annahmenfelder.spalten().flatMap { $0 }.map(\.schluessel)
        XCTAssertEqual(wieder, Annahmenfelder.alle.map(\.schluessel))
    }

    func testEsSindImmerZweiSpaltenAuchWennNichtsDaIst() {
        XCTAssertEqual(Annahmenfelder.spalten([]).map(\.count), [0, 0])
        XCTAssertEqual(Annahmenfelder.spalten(Array(Annahmenfelder.alle.prefix(1))).map(\.count), [1, 0])
        XCTAssertEqual(Annahmenfelder.spalten(Array(Annahmenfelder.alle.prefix(4))).map(\.count), [2, 2])
    }

    // MARK: - Die Kennlinie als Zeile

    func testDieKennlinieWirdMitPunktUndOhneNachstehendeNullGeschrieben() {
        XCTAssertEqual(
            Annahmenfelder.kurveZuText([[-7, 2.4], [2, 3], [7, 3.5], [15, 4.2]]),
            "-7:2.4, 2:3, 7:3.5, 15:4.2",
            "Ein Komma als Dezimaltrennzeichen wäre hier zugleich der Stützpunkttrenner.")
    }

    func testEineLeereKennlinieWirdEineLeereZeile() {
        XCTAssertEqual(Annahmenfelder.kurveZuText([]), "")
    }

    func testEinHalberStuetzpunktFaelltBeimSchreibenWeg() {
        XCTAssertEqual(Annahmenfelder.kurveZuText([[-7, 2.4], [2], [7, 3.5, 9]]), "-7:2.4")
    }

    func testDieKennlinienzeileUeberlebtDenEigenenAusgabeweg() {
        let kurve = [[-7, 2.4], [2, 3], [7, 3.5], [15, 4.2]]
        XCTAssertEqual(Annahmenfelder.textZuKurve(Annahmenfelder.kurveZuText(kurve)), kurve)
    }

    func testWerMitKommaTipptTrenntMitSemikolon() {
        XCTAssertEqual(
            Annahmenfelder.textZuKurve("-7:2,4; 2:3,0"), [[-7, 2.4], [2, 3]],
            "Eine deutsche Tastatur liefert das Komma.")
    }

    func testDasKommaKannNichtTrennerUndDezimaltrennzeichenZugleichSein() {
        XCTAssertNil(
            Annahmenfelder.textZuKurve("-7:2,4, 2:3,0"),
            "Nicht auflösbar - und lieber der Formatsatz als eine halb gelesene Kennlinie.")
    }

    func testDasEchteMinuszeichenDerAnzeigeWirdAuchInDerKennlinieGelesen() {
        XCTAssertEqual(Annahmenfelder.textZuKurve("\u{2212}7:2.4"), [[-7, 2.4]])
    }

    func testDieKennlinieNimmtSemikolonUndUeberzaehligeLeerzeichen() {
        XCTAssertEqual(Annahmenfelder.textZuKurve(" -7:2.4 ;  2:3 ; "), [[-7, 2.4], [2, 3]])
        XCTAssertEqual(Annahmenfelder.textZuKurve(" -7:2.4 ,  2:3 , "), [[-7, 2.4], [2, 3]])
    }

    func testEineLeereKennlinienzeileIstUnlesbarUndNichtEineLeereKurve() {
        XCTAssertNil(Annahmenfelder.textZuKurve(""))
        XCTAssertNil(Annahmenfelder.textZuKurve("   , ;  "))
    }

    func testEinStueckOhneZweiZahlenMachtDieGanzeZeileUnlesbar() {
        XCTAssertNil(Annahmenfelder.textZuKurve("-7:2.4, 2"))
        XCTAssertNil(Annahmenfelder.textZuKurve("-7:2.4, 2:"))
        XCTAssertNil(Annahmenfelder.textZuKurve("-7:2.4, zwei:drei"))
        XCTAssertNil(Annahmenfelder.textZuKurve("-7:2.4:9"))
    }

    func testDieReihenfolgeDerStuetzpunkteWirdHierNichtGepruefft() {
        XCTAssertEqual(
            Annahmenfelder.textZuKurve("15:4.2, -7:2.4"), [[15, 4.2], [-7, 2.4]],
            "Aufsteigend prüft der Dienst, mit der Begründung, die die Oberfläche nicht kennt.")
    }

    // MARK: - Was an den Dienst geht

    func testEineUnlesbareKennlinieHaeltDieGanzeAbgabeAuf() {
        let abgabe = Annahmenfelder.abgabe(
            entwuerfe: Annahmenfelder.entwuerfe(konfiguration()), kennlinie: "7",
            gegen: konfiguration())
        XCTAssertEqual(abgabe, .kennlinieUnlesbar, "Geprüft ohne Anfrage, wie in der Vorlage.")
    }

    func testDieKennlinieGehtImmerMitWeilSieAlsGanzesErsetztWird() throws {
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: [:], kennlinie: "2:3", gegen: nil)
        else { return XCTFail("Eine lesbare Kennlinie ohne Feldänderung ist eine Abgabe.") }
        XCTAssertEqual(patch.copCurve, [[2, 3]])
    }

    func testEinPatchTraegtNurDieFelderDieLesbarDastehen() throws {
        var entwuerfe = Annahmenfelder.entwuerfe(konfiguration())
        entwuerfe["pellet_price_eur_per_t"] = ""
        entwuerfe["buffer_ambient_c"] = "-"
        entwuerfe["indoor_target_c"] = "einundzwanzig"
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: entwuerfe, kennlinie: "2:3", gegen: nil)
        else { return XCTFail("Die Kennlinie ist lesbar.") }
        let objekt =
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as? [String: Any]
        XCTAssertNil(objekt?["pellet_price_eur_per_t"], "Ein leeres Feld bleibt stehen, wie es steht.")
        XCTAssertNil(objekt?["buffer_ambient_c"])
        XCTAssertNil(objekt?["indoor_target_c"], "Was keine Zahl ist, ist keine Annahme.")
        XCTAssertEqual(objekt?.count, 11, "Zehn Felder und die Kennlinie.")
        XCTAssertEqual(objekt?["stove_combustion_efficiency"] as? Double, 0.911)
    }

    func testEinGetipptesKommaKommtAlsZahlBeimDienstAn() throws {
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: ["pellet_kwh_per_kg": "5,05"], kennlinie: "2:3", gegen: nil)
        else { return XCTFail("Die Kennlinie ist lesbar.") }
        XCTAssertEqual(patch.pelletKwhPerKg, 5.05, "Ohne das verschluckt das Feld jede Eingabe.")
    }

    func testEinWertAusserhalbDerDienstgrenzenGehtTrotzdemAnDenDienst() throws {
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: ["pellet_kwh_per_kg": "99"], kennlinie: "2:3", gegen: nil)
        else { return XCTFail("Die Kennlinie ist lesbar.") }
        XCTAssertEqual(
            patch.pelletKwhPerKg, 99,
            "Die Grenzen kennt der Dienst; zwei Prüfungen laufen auseinander.")
    }

    // MARK: - Was ein Uebernehmen NICHT anfasst

    /// Die Konfiguration, wie ein Dienst sie wirklich liefert: Zahlen mit mehr Stellen, als die
    /// Anzeige hat. Genau daran scheiterte das alte `abgabe`.
    private func feinereKonfiguration() -> HemsConfig {
        HemsConfig(
            buffer: BufferConfig(
                volumeLiters: 1000, targetTemperatureC: 50, lossKwPerK: 0.0045, ambientC: 17,
                lossUsefulFraction: 0.5),
            heatDemand: HeatDemandConfig(indoorTargetC: 21.25, copCurve: [[2, 3]]),
            stove: StoveConfig(
                nominalHeatKw: 11.9, waterHeatKw: 10, combustionEfficiency: 0.911,
                minHeatKw: 3.2, minWaterHeatKw: 1.8, pelletPriceEurPerT: 449.5,
                pelletKwhPerKg: 4.9))
    }

    func testEinUebernehmenOhneEingabeSchicktKeinEinzigesFeld() throws {
        let cfg = feinereKonfiguration()
        let entwuerfe = Annahmenfelder.entwuerfe(cfg)
        XCTAssertNotEqual(
            Formate.zahlAusText(entwuerfe["buffer_loss_kw_per_k"] ?? ""), 0.0045,
            "Die Anzeige rundet auf drei Stellen - und genau darin lag der Fehler.")
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: entwuerfe, kennlinie: Annahmenfelder.kurveZuText(cfg.heatDemand?.copCurve ?? []),
            gegen: cfg)
        else { return XCTFail("Die Kennlinie ist lesbar.") }
        let objekt =
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as? [String: Any]
        XCTAssertEqual(
            objekt?.count, 1,
            "Nur die Kennlinie. Wer nichts tippt, darf nichts ändern - und schon gar nicht "
                + "dreizehn Werte auf die Stellen der Anzeige runden.")
        XCTAssertNil(
            objekt?["buffer_loss_kw_per_k"],
            "0,0045 kW/K wurde als 0,005 zurückgeschickt, ohne dass die Zeile bernstein wurde.")
        XCTAssertNil(objekt?["pellet_price_eur_per_t"], "449,50 €/t wurden 450.")
        XCTAssertNil(objekt?["indoor_target_c"], "21,25 °C wurden 21,3.")
    }

    func testWerEinFeldAendertSchicktNurDiesesEineUndNichtDieAnderenZwoelf() throws {
        let cfg = feinereKonfiguration()
        var entwuerfe = Annahmenfelder.entwuerfe(cfg)
        entwuerfe["pellet_kwh_per_kg"] = "5,05"
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: entwuerfe, kennlinie: "2:3", gegen: cfg)
        else { return XCTFail("Die Kennlinie ist lesbar.") }
        let objekt =
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as? [String: Any]
        XCTAssertEqual(objekt?.count, 2, "Das geänderte Feld und die Kennlinie.")
        XCTAssertEqual(objekt?["pellet_kwh_per_kg"] as? Double, 5.05)
        XCTAssertNil(objekt?["buffer_loss_kw_per_k"])
    }

    func testOhneBekannteKonfigurationGehtJedesLesbareFeldMitWeilNichtsZuSchonenIst() throws {
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: Annahmenfelder.entwuerfe(konfiguration()), kennlinie: "2:3", gegen: nil)
        else { return XCTFail("Die Kennlinie ist lesbar.") }
        let objekt =
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as? [String: Any]
        XCTAssertEqual(objekt?.count, 14, "Dreizehn Felder und die Kennlinie.")
    }

    func testEinFeldDasDerDienstNichtHatGehtMitSobaldEineZahlDarinSteht() throws {
        guard case .bereit(let patch) = Annahmenfelder.abgabe(
            entwuerfe: ["indoor_target_c": "21"], kennlinie: "2:3",
            gegen: konfiguration(haus: false))
        else { return XCTFail("Die Kennlinie ist lesbar.") }
        XCTAssertEqual(
            patch.indoorTargetC, 21,
            "Wo der Dienst keinen Wert hat, ist jede Zahl eine Änderung.")
    }

    func testEineGleichwertigAndersGeschriebeneKennlinieIstKeineOffeneAenderung() {
        let cfg = konfiguration()
        XCTAssertFalse(
            Annahmenfelder.kennlinieAbweichend("-7:2.4, 2:3.0, 7:3.5, 15:4.2", gegen: cfg),
            "„3.0“ und „3“ sind derselbe Stützpunkt.")
        XCTAssertFalse(
            Annahmenfelder.kennlinieAbweichend("-7:2,4; 2:3; 7:3,5; 15:4,2", gegen: cfg),
            "Die Semikolonschreibweise ist dieselbe Kennlinie, nur deutsch getippt.")
        XCTAssertTrue(Annahmenfelder.kennlinieAbweichend("2:3", gegen: cfg))
        XCTAssertTrue(
            Annahmenfelder.kennlinieAbweichend("7", gegen: cfg),
            "Unlesbar ist nicht das, was beim Dienst steht.")
        XCTAssertFalse(
            Annahmenfelder.kennlinieAbweichend("", gegen: konfiguration(kurve: [])),
            "Nichts gegen nichts ist keine Änderung.")
        XCTAssertTrue(Annahmenfelder.kennlinieAbweichend("", gegen: cfg))
    }

    // MARK: - Der Entwurf im Feld

    func testDerEntwurfStehtDeutschUndMitDenStellenDesFeldes() {
        let entwuerfe = Annahmenfelder.entwuerfe(konfiguration())
        XCTAssertEqual(entwuerfe["stove_combustion_efficiency"], "0,911")
        XCTAssertEqual(entwuerfe["pellet_price_eur_per_t"], "450")
        XCTAssertEqual(entwuerfe["buffer_loss_kw_per_k"], "0,004")
        XCTAssertEqual(entwuerfe["stove_nominal_heat_kw"], "11,9")
    }

    func testDieKennlinienzeileKommtAusDerKonfigurationDerWaermerechnung() {
        let cfg = konfiguration()
        XCTAssertEqual(
            Annahmenfelder.kurveZuText(cfg.heatDemand?.copCurve ?? []), "-7:2.4, 2:3, 7:3.5, 15:4.2")
    }

    func testEinGleichwertigAndersGeschriebenerWertIstKeineOffeneAenderung() {
        let feld = Annahmenfelder.alle[0]
        XCTAssertFalse(Annahmenfelder.abweichend(feld, entwurf: "11,90", gegen: konfiguration()))
        XCTAssertFalse(Annahmenfelder.abweichend(feld, entwurf: "11.9", gegen: konfiguration()))
    }

    func testEinGeaenderterWertIstEineOffeneAenderung() {
        let feld = Annahmenfelder.alle[0]
        XCTAssertTrue(Annahmenfelder.abweichend(feld, entwurf: "12,0", gegen: konfiguration()))
    }

    func testEinLeeresFeldIstKeineOffeneAenderungWeilEsNichtGeschicktWird() {
        let feld = Annahmenfelder.alle[6]
        XCTAssertFalse(Annahmenfelder.abweichend(feld, entwurf: "", gegen: konfiguration()))
        XCTAssertFalse(Annahmenfelder.abweichend(feld, entwurf: "€/t", gegen: konfiguration()))
    }

    func testEinWertWoDerDienstKeinenHatIstEineOffeneAenderung() {
        let feld = Annahmenfelder.alle[12]
        XCTAssertTrue(
            Annahmenfelder.abweichend(feld, entwurf: "21", gegen: konfiguration(haus: false)))
        XCTAssertTrue(Annahmenfelder.abweichend(feld, entwurf: "21", gegen: nil))
    }

    // MARK: - Getippte Zahlen lesen

    func testEinGetipptesKommaWirdGelesenUndNichtVerschluckt() {
        XCTAssertEqual(Formate.zahlAusText("0,911"), 0.911)
        XCTAssertEqual(Formate.zahlAusText("0.911"), 0.911)
    }

    func testDasEchteMinuszeichenDerAnzeigeWirdWiederGelesen() {
        XCTAssertEqual(Formate.zahlAusText(Formate.zahl(-5.5, stellen: 1)), -5.5)
        XCTAssertEqual(Formate.zahlAusText("-5,5"), -5.5)
    }

    func testEineMitgeschriebeneEinheitenluckeStoertNicht() {
        XCTAssertEqual(Formate.zahlAusText("1\u{202F}200"), 1200)
        XCTAssertEqual(Formate.zahlAusText(" 450 "), 450)
    }

    func testWasKeineZahlIstWirdKeine() {
        XCTAssertNil(Formate.zahlAusText(""))
        XCTAssertNil(Formate.zahlAusText(Formate.leer))
        XCTAssertNil(Formate.zahlAusText("elf"))
        XCTAssertNil(Formate.zahlAusText("11,9,2"))
        XCTAssertEqual(
            Formate.zahlAusText("21,"), 21,
            "Ein nachgestelltes Komma ist nur eine Schreibweise von 21, wie in der Vorlage.")
        XCTAssertNil(Formate.zahlAusText("nan"), "Keine Annahme über ein Haus.")
        XCTAssertNil(Formate.zahlAusText("inf"))
    }

    // MARK: - Die Sätze

    func testDerErfolgssatzNenntDenFahrplanWeilDerNochDenAltenStandZeigt() {
        XCTAssertTrue(Annahmenfelder.uebernommenSatz.hasPrefix("Übernommen."))
        XCTAssertTrue(Annahmenfelder.uebernommenSatz.contains("rückwirkend"))
        XCTAssertTrue(
            Annahmenfelder.uebernommenSatz.contains("Fahrplan"),
            "Ohne den Hinweis sieht die noch alte Fahrplanseite wie Wirkungslosigkeit aus.")
    }

    func testDerLadesatzIstDerDerVorlageUndNichtDerDerApp() {
        XCTAssertEqual(
            Annahmenfelder.ladesatz, "lädt …",
            "Die App sagte „Wird geholt …“ in einer Karte, die Vorlage drei Wörter im Absatz.")
        XCTAssertEqual(
            Annahmenfelder.ladefehler, "Die Konfiguration konnte nicht geladen werden.")
    }

    func testDerKennlinienfehlerNenntDasFormatUndNichtDenFehler() {
        XCTAssertTrue(Annahmenfelder.kennlinienFehler.contains("Temperatur:COP"))
    }

    func testDieEinleitungBeginntMitDemGrundFuerDieGanzeSeite() {
        XCTAssertTrue(
            Annahmenfelder.einleitung.hasPrefix("Es gibt keinen Wärmemengenzähler im Haus."))
        XCTAssertEqual(Annahmenfelder.kicker, "Lieferschein · Datenblatt · Puffer")
    }

    func testDerSchlussabsatzVerweistAufDieWaermebilanz() {
        XCTAssertEqual(
            Annahmenfelder.schlussabsatz.compactMap { stueck -> String? in
                if case .verweis(let wort, let weg) = stueck { return wort + " " + weg }
                return nil
            },
            ["Wärmebilanz /waerme/bilanz"])
        XCTAssertTrue(
            Annahmenfelder.schlussabsatz.contains { stueck in
                if case .satz(let s) = stueck { return s.contains("nicht zuzuordnen") }
                return false
            },
            "Der einzige Satz, der sagt, woran man merkt, ob die Annahmen stimmen.")
    }

    func testDieMethodenkarteGibtZweiSaetzeHerUndKeinenZusammengebauten() {
        XCTAssertEqual(Annahmenfelder.methodensaetze.count, 2)
        XCTAssertTrue(Annahmenfelder.methodensaetze[0].contains("Regelparameter bleiben draußen"))
        XCTAssertTrue(Annahmenfelder.methodensaetze[1].contains("rückwirkend"))
    }
}
