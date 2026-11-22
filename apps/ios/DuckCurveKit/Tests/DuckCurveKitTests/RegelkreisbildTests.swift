import XCTest

@testable import DuckCurveKit

/// Was ``Regelkreisbild`` aus der Antwort des Dienstes macht - geprüft an einer kleinen Karte,
/// die alle Fälle einmal enthält: eine Störgröße, eine Summierstelle mit Minuszeichen, einen
/// stetigen Kreis mit Reserven, einen unstetigen ohne, einen übernommenen und einen abgelehnten
/// Parameter.
final class RegelkreisbildTests: XCTestCase {

    // MARK: - Eine Karte zum Draufhalten

    private func glied(_ id: String, kurz: String, kategorie: GliedAnsichtKategorieWahl)
        -> GliedAnsicht
    {
        GliedAnsicht(
            id: id, kurz: kurz, name: "Glied " + kurz, gS: "G(s) = K", art: .sprung,
            kategorie: kategorie, nichtlinear: false, erkennen: "steigt und bleibt",
            kurve: [[0, 0], [0.5, 0.8], [1, 1]], kurve2: [])
    }

    private func parameter(
        _ id: String,
        block: String = "puffer",
        wert: Double = 50,
        unten: Double = 0,
        oben: Double = 100,
        herkunft: ParameterAnsichtHerkunftWahl = .geschaetzt,
        schaetzart: ParameterAnsichtSchaetzartWahl = .rls,
        startwert: Double = 20,
        schaetzung: Double? = 52,
        sigma: Double? = 4,
        n: Int? = 58,
        rmse: Double? = 0.31,
        protokoll: [Uebernahme] = [],
        verlauf: [Messpunkt] = [],
        pruefung: Pruefung? = nil
    ) -> ParameterAnsicht {
        ParameterAnsicht(
            id: id, block: block, symbol: "UA", name: "Verlustbeiwert", einheit: "W/K",
            stellen: 1, wert: wert, herkunft: herkunft, schaetzart: schaetzart,
            schaetzartText: "rekursiv mit Vergessensfaktor", startwert: startwert,
            schaetzung: schaetzung, sigma: sigma, n: n, stand: "2026-11-20T04:00:00Z",
            rmse: rmse, unten: unten, oben: oben,
            warum: "Der Beiwert bestimmt, wie viel der Puffer stehend verliert.",
            quelle: "Stillstandsnächte", wirktAuf: ["R2"], protokoll: protokoll,
            verlauf: verlauf, pruefung: pruefung)
    }

    private func karte(
        parameter eigene: [ParameterAnsicht]? = nil,
        kreise: [KreisAnsicht]? = nil,
        tage: Double? = 41,
        uebersteuert: [String] = [],
        umschalt: Double? = -4.5
    ) -> RegelkreisOut {
        RegelkreisOut(
            stand: "2026-11-22T06:00:00Z",
            seit: "2026-10-12T00:00:00Z",
            tage: tage,
            arbeitspunkt: Arbeitspunkt(
                aussenC: 2.5, vorlaufC: 34, strompreisEurKwh: 0.284, aussenGemessen: true,
                vorlaufGemessen: false),
            kosten: Kostenpunkt(
                cop: 3.4, waermepumpeCtKwh: 8.4, ofenCtKwh: 9.9, copUmschalt: 2.87,
                umschaltAussenC: umschalt),
            bloecke: [
                BlockAnsicht(
                    id: "aussen", ebene: 4, rolle: .stoergroesse, rolleText: "Störgröße",
                    name: "Außentemperatur", kurz: "ϑa",
                    erklaerung: ["Sie ist die größte Störgröße des Hauses."],
                    behandlung: .aufgeschaltet, behandlungText: "aufgeschaltet",
                    quelle: "Wetterstation"),
                BlockAnsicht(
                    id: "puffer", ebene: 3, rolle: .strecke, rolleText: "Strecke",
                    name: "Pufferspeicher", kurz: "Puffer", kreis: "R2",
                    erklaerung: ["Der Puffer dämpft die Kaskade."],
                    gleichungen: ["C · dϑ/dt = Q̇zu − Q̇ab − UA · (ϑ − ϑu)"],
                    parameter: ["ua_puffer"], glied: "itn"),
                BlockAnsicht(
                    id: "summe_vl", ebene: 1, rolle: .summierstelle,
                    rolleText: "Summierstelle", name: "Regelabweichung Vorlauf", kurz: "Σ"),
                BlockAnsicht(
                    id: "vl_regler", ebene: 1, rolle: .regler, rolleText: "Regler",
                    name: "Mischer-Regler", kurz: "PI", kreis: "R1", glied: "pi_regler",
                    gliedEntwurf: "pi_regler"),
            ],
            glieder: [
                glied("itn", kurz: "ITn", kategorie: .strecke),
                glied("pi_regler", kurz: "PI", kategorie: .regler),
            ],
            kanten: [
                KanteAnsicht(
                    von: "kennlinie", nach: "summe_vl", signal: "Sollvorlauf", art: .fuehrung,
                    vorzeichen: .plus),
                KanteAnsicht(
                    von: "vl_fuehler", nach: "summe_vl", signal: "Istvorlauf",
                    art: .rueckfuehrung, vorzeichen: .minus),
                KanteAnsicht(
                    von: "summe_vl", nach: "vl_regler", signal: "Regelabweichung", art: .signal),
            ],
            kreise: kreise ?? [stetigerKreis(), planungskreis()],
            parameter: eigene ?? [parameter("ua_puffer")],
            uebersteuert: uebersteuert,
            uebernahmen: 2)
    }

    private func stetigerKreis(
        phase: Double? = 52, amplitude: Double? = 3.1, gut: Bool = true, hinweis: String? = nil
    ) -> KreisAnsicht {
        KreisAnsicht(
            id: "R1", name: "Vorlauftemperatur", regelgroesse: "Vorlauftemperatur",
            stellgroesse: "Mischerstellung in %", reglerBlock: "vl_regler",
            messglied: "vl_fuehler", taktS: 10, art: .stetig,
            erklaerung: ["Der schnellste Kreis der Kaskade."],
            strecke: StreckeAnsicht(
                art: .foptd, k: 1.8, t1: 42, t2: 0, totzeit: 9, t1Entwurf: 42,
                totzeitEntwurf: 9, halbregel: false),
            regler: ReglerAnsicht(kp: 2.4, tn: 42, lam: 9, regel: "SIMC"),
            reserven: ReservenAnsicht(
                durchtritt: 0.08, periodeMin: 78, phasenreserveGrad: phase,
                amplitudenreserve: amplitude, gut: gut),
            hinweis: hinweis)
    }

    private func planungskreis() -> KreisAnsicht {
        KreisAnsicht(
            id: "R4", name: "Ökonomische Führung", regelgroesse: "Kosten über 48 Stunden",
            stellgroesse: "Führungsgrößen der unteren Kreise", reglerBlock: "fahrplan",
            taktS: 900, art: .planung)
    }

    // MARK: - Die Ebenen

    /// **Von außen nach innen**, und keine leere Ebene dazwischen: Ebene 2 und 0 haben in
    /// dieser Karte keine Blöcke und tauchen darum nicht auf.
    func testEbenenVonAussenNachInnen() {
        let bild = Regelkreisbild.baue(karte())
        XCTAssertEqual(bild.ebenen.map(\.id), [4, 3, 1])
        XCTAssertEqual(bild.ebenen.first?.titel, "Ökonomische Führung")
        XCTAssertEqual(bild.ebenen.first?.bloecke.map(\.name), ["Außentemperatur"])
        XCTAssertEqual(bild.ebenen.last?.bloecke.count, 2)
    }

    /// **Die Summierstelle steht mit in der Liste.** Sie ist die Stelle, an der aus einer Kette
    /// ein Regelkreis wird; eine Liste ohne sie zeigt eine Kette.
    func testSummierstelleStehtDrin() {
        let bild = Regelkreisbild.baue(karte())
        let ebene = bild.ebenen.first { $0.id == 1 }
        XCTAssertEqual(ebene?.bloecke.map(\.id), ["summe_vl", "vl_regler"])
    }

    /// Und ihr Minuszeichen kommt mit: ein echter Minusstrich, kein Bindestrich.
    func testVorzeichenAnDerSummierstelle() {
        let bild = Regelkreisbild.baue(karte())
        let summe = bild.ebenen.flatMap(\.bloecke).first { $0.id == "summe_vl" }
        let hinein = summe?.signale.filter(\.hinein) ?? []
        XCTAssertEqual(hinein.map(\.vorzeichen), ["+", "−"])
        XCTAssertEqual(hinein.map(\.name), ["Sollvorlauf", "Istvorlauf"])
        // Der Gegenüber steht mit seinem Namen da, wo die Karte einen kennt - und mit seiner
        // Kennung, wo nicht. „kennlinie“ ist in dieser kleinen Karte kein Block.
        XCTAssertEqual(hinein.first?.gegenueber, "kennlinie")
        let hinaus = summe?.signale.filter { !$0.hinein } ?? []
        XCTAssertEqual(hinaus.map(\.gegenueber), ["Mischer-Regler"])
        XCTAssertNil(hinaus.first?.vorzeichen)
    }

    /// Eine Störgröße ist als solche erkennbar - die Ansicht färbt sie danach.
    func testStoergroesseErkannt() {
        let bild = Regelkreisbild.baue(karte())
        let aussen = bild.ebenen.flatMap(\.bloecke).first { $0.id == "aussen" }
        XCTAssertEqual(aussen?.stoergroesse, true)
        XCTAssertEqual(aussen?.behandlung, "aufgeschaltet")
        XCTAssertNil(aussen?.glied)
    }

    /// Das Glied hängt am Block, aus dem Katalog aufgelöst.
    func testGliedAufgeloest() {
        let bild = Regelkreisbild.baue(karte())
        let puffer = bild.ebenen.flatMap(\.bloecke).first { $0.id == "puffer" }
        XCTAssertEqual(puffer?.glied?.kurz, "ITn")
        XCTAssertEqual(puffer?.gleichungen.count, 1)
        XCTAssertEqual(puffer?.parameter.count, 1)
    }

    // MARK: - Die Parameter

    /// **Wert, Startwert und Unsicherheit liegen in derselben Einheit** - der Breite des
    /// Plausibilitätsbereichs. Nur so lässt sich zeichnen, ob ein Wert innerhalb seiner eigenen
    /// Streuung vom Startwert abweicht.
    func testAnteileAufDenPlausibilitaetsbereich() {
        let bild = Regelkreisbild.baue(karte())
        let p = bild.ebenen.flatMap(\.bloecke).flatMap(\.parameter).first
        XCTAssertEqual(p?.anteil ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(p?.startAnteil ?? 0, 0.2, accuracy: 1e-9)
        XCTAssertEqual(p?.sigmaAnteil ?? 0, 0.04, accuracy: 1e-9)
    }

    /// **Außerhalb seiner Grenzen rutscht der Griff nicht aus dem Bild.** Ein übersteuerter
    /// Wert darf außerhalb liegen - gezeichnet wird er am Rand, nicht daneben.
    func testAnteileBleibenImBild() {
        let p = parameter("ua_puffer", wert: 140, herkunft: .uebersteuert, schaetzung: nil,
                          sigma: nil, n: nil, rmse: nil)
        let bild = Regelkreisbild.baue(karte(parameter: [p]))
        let zeile = bild.ebenen.flatMap(\.bloecke).flatMap(\.parameter).first
        XCTAssertEqual(zeile?.anteil, 1.0)
        XCTAssertEqual(zeile?.uebersteuert, true)
        XCTAssertEqual(zeile?.herkunftWort, "übersteuert")
        XCTAssertNil(zeile?.schaetzsatz)
    }

    /// Die Schätzung steht als ein Satz da: Wert, Unsicherheit, Stützstellen, Fehlermaß.
    func testSchaetzsatz() {
        let bild = Regelkreisbild.baue(karte())
        let p = bild.ebenen.flatMap(\.bloecke).flatMap(\.parameter).first
        XCTAssertEqual(p?.schaetzsatz, "52,0 W/K · ± 4,0 W/K · n = 58 · RMSE 0,310")
        XCTAssertEqual(p?.wert, "50,0 W/K")
        XCTAssertEqual(p?.lernbar, true)
    }

    /// **Nur die abgelehnte Prüfung steht am Parameter.** Eine angenommene steht im Protokoll;
    /// zweimal dieselbe Auskunft wäre eine Zeile, die niemand mehr liest.
    func testNurDieAbgelehntePruefungStehtDa() {
        let abgelehnt = parameter(
            "ua_puffer",
            pruefung: Pruefung(
                uebernehmen: false, code: .innerhalbUnsicherheit,
                grund: "Die Schätzung liegt innerhalb ihrer eigenen Unsicherheit."))
        let a = Regelkreisbild.baue(karte(parameter: [abgelehnt]))
        XCTAssertEqual(
            a.ebenen.flatMap(\.bloecke).flatMap(\.parameter).first?.pruefsatz,
            "Die Schätzung liegt innerhalb ihrer eigenen Unsicherheit.")

        let angenommen = parameter(
            "ua_puffer",
            pruefung: Pruefung(uebernehmen: true, code: .uebernommen, grund: "Übernommen."))
        let b = Regelkreisbild.baue(karte(parameter: [angenommen]))
        XCTAssertNil(b.ebenen.flatMap(\.bloecke).flatMap(\.parameter).first?.pruefsatz)
    }

    /// Ein Parameter ohne Schätzverfahren ist nicht lernbar - dort steht kein Verlauf.
    func testFesterParameterIstNichtLernbar() {
        let fest = parameter(
            "c_puffer", herkunft: .fest, schaetzart: .keiner, schaetzung: nil, sigma: nil,
            n: nil, rmse: nil)
        let bild = Regelkreisbild.baue(karte(parameter: [fest]))
        let p = bild.ebenen.flatMap(\.bloecke).flatMap(\.parameter).first
        XCTAssertEqual(p?.lernbar, false)
        XCTAssertEqual(p?.stuetzstellen, 0)
        XCTAssertEqual(bild.lernbar, 0)
        XCTAssertEqual(bild.belegt, 0)
    }

    // MARK: - Das Protokoll

    /// **Jüngstes zuerst, über alle Parameter hinweg** - und mit dem Fehlermaß davor und danach,
    /// wo beides vorliegt. Ohne das wäre „ersetzt“ eine Behauptung.
    func testProtokollJuengstesZuerst() {
        let p = parameter(
            "ua_puffer",
            protokoll: [
                Uebernahme(
                    at: "2026-10-20T04:00:00Z", alt: 20, neu: 34, sigma: 6, n: 31,
                    rmseAlt: 0.62, rmseNeu: 0.44, grund: "Erste Übernahme."),
                Uebernahme(
                    at: "2026-11-10T04:00:00Z", alt: 34, neu: 50, sigma: 4, n: 58,
                    rmseAlt: 0.44, rmseNeu: 0.31, grund: "Zweite Übernahme."),
            ])
        let bild = Regelkreisbild.baue(karte(parameter: [p]))
        XCTAssertEqual(bild.protokoll.map(\.grund), ["Zweite Übernahme.", "Erste Übernahme."])
        XCTAssertEqual(bild.protokoll.first?.aenderung, "34,0 → 50,0 W/K")
        XCTAssertEqual(bild.protokoll.first?.guete, "RMSE 0,440 → 0,310")
        // Am Parameter selbst steht dasselbe Protokoll, in derselben Ordnung.
        let zeile = bild.ebenen.flatMap(\.bloecke).flatMap(\.parameter).first
        XCTAssertEqual(zeile?.protokoll.map(\.stand), bild.protokoll.map(\.stand))
    }

    /// Ohne Fehlermaß steht keines da - statt einer erfundenen Null.
    func testProtokollOhneGuete() {
        let p = parameter(
            "ua_puffer",
            protokoll: [
                Uebernahme(
                    at: "2026-11-10T04:00:00Z", alt: 34, neu: 50, sigma: 4, n: 58,
                    grund: "Übernommen."),
            ])
        let bild = Regelkreisbild.baue(karte(parameter: [p]))
        XCTAssertNil(bild.protokoll.first?.guete)
    }

    /// Der Zeitpunkt wird in der Zeit des Hauses gelesen, mit führenden Nullen.
    func testWann() {
        XCTAssertEqual(Regelkreisbild.wann("2026-11-10T04:00:00Z"), "Di., 10.11. 05:00")
        XCTAssertEqual(Regelkreisbild.wann("unbrauchbar"), Formate.leer)
    }

    // MARK: - Die Kreise

    /// Der stetige Kreis trägt beide Reserven, als Zahl und als Ausschlag.
    func testStetigerKreisMitReserven() {
        let bild = Regelkreisbild.baue(karte())
        let r1 = bild.kreise.first
        XCTAssertEqual(r1?.bewertbar, true)
        XCTAssertEqual(r1?.phasenreserve, "52°")
        XCTAssertEqual(r1?.amplitudenreserve, "3,10")
        XCTAssertEqual(r1?.periode, "78 min")
        XCTAssertEqual(r1?.phasenAnteil ?? 0, 52.0 / 90.0, accuracy: 1e-9)
        XCTAssertEqual(r1?.amplitudenAnteil ?? 0, (3.1 - 1) / 5, accuracy: 1e-9)
        XCTAssertEqual(r1?.phasenFeld, .knapp)
        XCTAssertEqual(r1?.amplitudenFeld, .gut)
        XCTAssertEqual(r1?.strecke, "PT1 mit Totzeit · K = 1,800 · T₁ = 42 min · Tt = 9,0 min")
        XCTAssertEqual(r1?.entwurf, "SIMC · Kp = 2,40 · Tn = 42 min · λ = 9,0 min")
        XCTAssertNil(r1?.hinweis)
    }

    /// **Die Frequenzkennlinie reist mit.** Aus ihr kommen die beiden Reserven; ohne sie wäre
    /// im Bild nur die Zahl und nicht der Verlauf, der zu ihr führt.
    func testFrequenzkennlinieUndDurchtritt() {
        let kennlinie = [
            KennliniePunkt(w: 0.001, db: 38, grad: -95),
            KennliniePunkt(w: 0.08, db: 0, grad: -128),
            KennliniePunkt(w: 1.0, db: -34, grad: -212),
        ]
        let kreis = KreisAnsicht(
            id: "R1", name: "Vorlauftemperatur", regelgroesse: "Vorlauftemperatur",
            stellgroesse: "Mischerstellung in %", reglerBlock: "vl_regler", taktS: 10,
            art: .stetig,
            reserven: ReservenAnsicht(
                durchtritt: 0.08, periodeMin: 78, phasenreserveGrad: 52,
                amplitudenreserve: 3.1, gut: true),
            kennlinie: kennlinie)
        let bild = Regelkreisbild.baue(karte(kreise: [kreis]))
        XCTAssertEqual(bild.kreise.first?.kennlinie.count, 3)
        XCTAssertEqual(bild.kreise.first?.durchtritt, 0.08)
        // Ein Kreis ohne Frequenzkennlinie trägt eine leere Liste und keine erfundene Kurve.
        XCTAssertEqual(Regelkreisbild.baue(karte()).kreise.last?.kennlinie, [])
        XCTAssertNil(Regelkreisbild.baue(karte()).kreise.last?.durchtritt)
    }

    /// **Unendlich schlägt voll aus**, denn die Phase erreicht −180° nie - das ist das Beste,
    /// was dieser Pegel zeigen kann, und keine fehlende Angabe.
    func testUnendlicheAmplitudenreserve() {
        let bild = Regelkreisbild.baue(karte(kreise: [stetigerKreis(amplitude: nil)]))
        XCTAssertEqual(bild.kreise.first?.amplitudenreserve, "∞")
        XCTAssertEqual(bild.kreise.first?.amplitudenAnteil, 1.0)
        XCTAssertEqual(bild.kreise.first?.amplitudenFeld, .gut)
    }

    /// **Ohne Frequenzkennlinie steht der Satz statt einer Null.** Ein Zeiger auf null wäre die
    /// Aussage „null Grad“, und die ist falsch: richtig ist „nicht in Grad zu beantworten“.
    func testKreisOhneReserven() {
        let bild = Regelkreisbild.baue(karte())
        let r4 = bild.kreise.last
        XCTAssertEqual(r4?.bewertbar, false)
        XCTAssertNil(r4?.phasenAnteil)
        XCTAssertNil(r4?.amplitudenAnteil)
        XCTAssertEqual(r4?.phasenreserve, "—")
        XCTAssertEqual(r4?.amplitudenreserve, "—")
        XCTAssertEqual(r4?.hinweis, "gleitender Horizont - in Euro beurteilt")
        XCTAssertEqual(r4?.art, "Planung")
        XCTAssertEqual(r4?.takt, "15 min")
    }

    /// Ein eigener Hinweis des Dienstes hat Vorrang vor dem erzeugten Satz.
    func testEigenerHinweisGehtVor() {
        let bild = Regelkreisbild.baue(
            karte(kreise: [
                stetigerKreis(phase: 31, gut: false, hinweis: "Die Phasenreserve ist zu klein."),
            ]))
        XCTAssertEqual(bild.kreise.first?.hinweis, "Die Phasenreserve ist zu klein.")
        XCTAssertEqual(bild.kreise.first?.gut, false)
        XCTAssertEqual(bild.kreise.first?.phasenFeld, .zuKlein)
    }

    /// Die drei Felder, an den Grenzen nachgemessen - 45° und Faktor 2,5 sind die Faustregel
    /// aus dem Kern, nicht aus der Ansicht.
    func testFelderDerReserven() {
        XCTAssertEqual(Regelkreisbild.feld(phasenreserve: 44.9), .zuKlein)
        XCTAssertEqual(Regelkreisbild.feld(phasenreserve: 45), .knapp)
        XCTAssertEqual(Regelkreisbild.feld(phasenreserve: 59.9), .knapp)
        XCTAssertEqual(Regelkreisbild.feld(phasenreserve: 60), .gut)
        XCTAssertEqual(Regelkreisbild.feld(phasenreserve: nil), .zuKlein)
        XCTAssertEqual(Regelkreisbild.feld(amplitudenreserve: 1.9), .zuKlein)
        XCTAssertEqual(Regelkreisbild.feld(amplitudenreserve: 2.0), .knapp)
        XCTAssertEqual(Regelkreisbild.feld(amplitudenreserve: 2.5), .gut)
        XCTAssertEqual(Regelkreisbild.feld(amplitudenreserve: nil), .gut)
    }

    /// Dauern in der Einheit, in der ein Mensch sie wiedererkennt.
    func testDauer() {
        XCTAssertEqual(Regelkreisbild.dauer(0.5), "30 s")
        XCTAssertEqual(Regelkreisbild.dauer(9), "9,0 min")
        XCTAssertEqual(Regelkreisbild.dauer(42), "42 min")
        XCTAssertEqual(Regelkreisbild.dauer(90), "1,5 h")
        XCTAssertEqual(Regelkreisbild.dauer(2880), "2,0 d")
    }

    // MARK: - Der Kopf

    func testKacheln() {
        let k = karte()
        let kacheln = Regelkreisbild.kacheln(k)
        XCTAssertEqual(kacheln.map(\.wort), [
            "Arbeitszahl im Punkt", "Grenzkosten Wärme", "Umschaltpunkt", "Lernstand",
        ])
        XCTAssertEqual(kacheln[0].wert, "3,40")
        XCTAssertEqual(
            kacheln[0].dazu,
            "bei \(Formate.celsius(2.5, stellen: 1)) außen (gemessen) und "
                + "\(Formate.celsius(34)) Vorlauf (aus der Kennlinie)")
        XCTAssertEqual(kacheln[1].wert, "8,4 / 9,9")
        // Die Wärmepumpe ist billiger: der Ton bleibt ruhig.
        XCTAssertEqual(kacheln[1].ton, .nebel)
        XCTAssertEqual(kacheln[2].wert, Formate.celsius(-4.5, stellen: 1))
        XCTAssertEqual(kacheln[3].wert, "41")
        XCTAssertEqual(kacheln[3].dazu, "1 von 1 Größen aus Messung · 2 Übernahmen")
        XCTAssertEqual(kacheln[3].ton, .normal)
    }

    /// **Kein Umschaltpunkt heißt „—“ und nicht −20 Grad.** Außerhalb von −15 bis 18 Grad ist
    /// die Zahl eine Rechnung ohne Bedeutung; das entscheidet der Dienst, hier steht der Strich.
    func testOhneUmschaltpunkt() {
        let kacheln = Regelkreisbild.kacheln(karte(umschalt: nil))
        XCTAssertEqual(kacheln[2].wert, "—")
        XCTAssertEqual(
            kacheln[2].dazu, "außerhalb des sinnvollen Bereichs · nötige Arbeitszahl 2,87")
    }

    /// Eine Übersteuerung schlägt in der Lernstandskachel an - sie ist der Zustand, über den
    /// man Bescheid wissen will.
    func testUebersteuerungFaelltAuf() {
        let kacheln = Regelkreisbild.kacheln(karte(uebersteuert: ["ua_puffer"]))
        XCTAssertEqual(kacheln[3].ton, .alarm)
        XCTAssertEqual(
            kacheln[3].dazu, "1 von 1 Größen aus Messung · 2 Übernahmen · 1 übersteuert")
    }

    /// Ohne Betriebstage steht das auch so da, statt einer Null, die nach Messung aussieht.
    func testLernsatzOhneTage() {
        XCTAssertEqual(
            Regelkreisbild.baue(karte(tage: nil)).lernsatz,
            "Noch keine Betriebstage aufgezeichnet · 1 von 1 lernbaren Größen aus Messung")
        XCTAssertEqual(
            Regelkreisbild.baue(karte()).lernsatz,
            "41 Betriebstage · 1 von 1 lernbaren Größen aus Messung")
    }
}
