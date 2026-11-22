import XCTest

@testable import DuckCurveKit

/// Die Rechnungen des Wärmepumpenbetriebs - Fall für Fall dieselben wie in
/// `apps/web/src/components/waermepumpe/betrieb.test.ts`.
///
/// **Warum die Fälle übernommen und nicht neu erfunden.** Die Vorlage rundet an drei Stellen
/// anders, als man es von Hand täte, und genau diese drei Stellen prüft sie. Ein eigener
/// Testsatz hätte dieselben Zahlen anders gerundet und dann bewiesen, dass die App zu sich
/// selbst passt.
final class BetriebsbildTests: XCTestCase {

    // MARK: - Die Antwort, wie sie der Dienst liefert

    private func tag(
        tag: String = "2026-11-14", starts: Int = 6, laufMin: Int = 300, abtauMin: Int = 20,
        abtauungen: Int = 4, zusatzMin: Int = 10, stromKwh: Double = 14.2,
        waermeKwh: Double? = 52.1, copTag: Double? = 3.86, copHeizen: Double? = 4.3,
        laufMedianMin: Double? = 42, aussenC: Double? = 4.5
    ) -> BetriebTagOut {
        BetriebTagOut(
            tag: tag, starts: starts, laufMin: laufMin, abtauMin: abtauMin,
            abtauungen: abtauungen, zusatzMin: zusatzMin, stromKwh: stromKwh,
            waermeKwh: waermeKwh, stromLaufKwh: 13.5, copTag: copTag, copHeizen: copHeizen,
            laufMedianMin: laufMedianMin, aussenC: aussenC, waermeMin: 290)
    }

    /// Die Vorlage des Tests: drei Tage, von denen der erste stand.
    private func antwort(
        tage: [BetriebTagOut]? = nil, stunden: [BetriebStundeOut]? = nil,
        heizkurve: BetriebHeizkurveOut?? = nil, klassen: [BetriebKlasseOut]? = nil,
        starts: Int? = 16, laufMin: Int? = 600, abtauMin: Int? = 40, abtauungen: Int? = 8,
        copGesamt: Double? = 3.86, copHeizen: Double? = 4.3, laufMedianMin: Double? = 42,
        saetzeDe: [String] = [], hinweiseDe: [String] = []
    ) -> BetriebOut {
        BetriebOut(
            now: "2026-11-14T20:00:00Z", von: "2026-10-31T20:00:00Z",
            bis: "2026-11-14T20:00:00Z", zeitraumTage: 14,
            tage: tage
                ?? [
                    tag(
                        tag: "2026-11-12", starts: 0, laufMin: 0, abtauMin: 0, abtauungen: 0,
                        zusatzMin: 0, copTag: nil, copHeizen: nil),
                    tag(tag: "2026-11-13", starts: 10),
                    tag(),
                ],
            stunden: stunden
                ?? [
                    BetriebStundeOut(
                        at: "2026-11-14T05:00:00Z", minuten: 60, aussenC: 0, sollC: 44,
                        vorlaufC: 41.5, ventil: 1),
                    BetriebStundeOut(
                        at: "2026-11-14T15:00:00Z", minuten: 30, aussenC: 10, sollC: 37),
                ],
            heizkurve: heizkurve
                ?? BetriebHeizkurveOut(
                    a: 44, b: -0.7, n: 24, r2: 0.98, aussenVonC: 0, aussenBisC: 10,
                    formelDe: "Sollwert = 44,0 - 0,70 × Außentemperatur"),
            klassen: klassen
                ?? [
                    BetriebKlasseOut(vonMin: 0, bisMin: 10, laeufe: 4),
                    BetriebKlasseOut(vonMin: 10, bisMin: 20, laeufe: 2),
                    BetriebKlasseOut(vonMin: 20, bisMin: 40, laeufe: 3),
                    BetriebKlasseOut(vonMin: 40, bisMin: 90, laeufe: 6),
                    BetriebKlasseOut(vonMin: 90, laeufe: 1),
                ],
            starts: starts, laufMin: laufMin, abtauMin: abtauMin, abtauungen: abtauungen,
            zusatzMin: 20, copGesamt: copGesamt, copHeizen: copHeizen,
            laufMedianMin: laufMedianMin, saetzeDe: saetzeDe, hinweiseDe: hinweiseDe)
    }

    // MARK: - Der Tag an der Achse

    /// `betrieb.test.ts:44-45`: der Ortstag wird nicht umgerechnet und nicht aufgefüllt.
    func testDerTagStehtEinstelligAnDerAchse() {
        XCTAssertEqual(Tag.punkt("2026-11-04"), "4.11.")
        XCTAssertEqual(Tag.punkt("2026-01-31"), "31.1.")
        // Die zweistellige Form bleibt daneben, mit ihrer eigenen Begründung.
        XCTAssertEqual(Tag.tagMonat("2026-11-04"), "04.11.")
    }

    func testEinUnmoeglicherTagBleibtStehen() {
        XCTAssertEqual(Tag.punkt("2026-02-30"), "2026-02-30")
        XCTAssertEqual(Tag.punkt(""), "")
    }

    // MARK: - Die Teile der Laufzeit

    /// `betrieb.test.ts:49-56`: die drei Teile ergeben wieder die Laufzeit.
    func testDieTeileEinesTagesErgebenDieLaufzeit() {
        let t = Betriebsbild.stundenteile(tag())
        XCTAssertEqual(t.heizen, 4.5, accuracy: 1e-9)
        XCTAssertEqual(t.abtauen, 20.0 / 60, accuracy: 1e-9)
        XCTAssertEqual(t.heizstab, 10.0 / 60, accuracy: 1e-9)
        XCTAssertEqual((t.heizen + t.abtauen + t.heizstab) * 60, 300, accuracy: 1e-9)
    }

    /// Zwei getrennt gezählte Posten können zusammen über die Laufzeit hinausgehen; der
    /// Heizenteil wird dann null und nicht negativ (`betrieb.ts:50`).
    func testHeizenWirdNieNegativ() {
        let t = Betriebsbild.stundenteile(tag(laufMin: 20, abtauMin: 15, zusatzMin: 15))
        XCTAssertEqual(t.heizen, 0)
    }

    func testDieReihenStehenInDerStapelordnungUndSindGerundet() {
        let r = Betriebsbild.stundenreihen(antwort())
        XCTAssertEqual(r.map(\.name), ["Heizen", "Abtauen", "Heizstab"])
        XCTAssertEqual(r[0].werte.map(\.wert), [0, 4.5, 4.5])
        XCTAssertEqual(r[0].werte.map(\.beschriftung), ["12.11.", "13.11.", "14.11."])
        // 20 min sind 0,3333… Stunden und stehen als 0,33 im Balken (`betrieb.ts:102`).
        XCTAssertEqual(r[1].werte[1].wert, 0.33)
        XCTAssertEqual(r[0].farbe, Marken.waermepumpe)
        XCTAssertEqual(r[1].farbe, Marken.diagrammSpeicher)
        XCTAssertEqual(r[2].farbe, Marken.diagrammNetz)
    }

    func testOhneTageKeineBalkenAberAlleDreiReihen() {
        let r = Betriebsbild.stundenreihen(antwort(tage: []))
        XCTAssertEqual(r.count, 3)
        XCTAssertTrue(r.allSatisfy { $0.werte.isEmpty })
    }

    // MARK: - Starts je Tag, Abtauanteil, Kurzanteil

    /// `betrieb.test.ts:58-66` - der Fall, der in der App falsch gerechnet war.
    func testStartsJeTagRechnetUeberDieTageMitBetrieb() {
        // 16 Starts, drei Tage, davon zwei mit Lauf: 8 - und nicht 16/3 und nicht 16/14.
        XCTAssertEqual(Betriebsbild.startsJeTag(antwort()), 8)
        XCTAssertNil(Betriebsbild.startsJeTag(antwort(tage: [], starts: 0)))
        XCTAssertNil(Betriebsbild.startsJeTag(antwort(starts: nil)))
    }

    func testDerAbtauanteilBrauchtEineLaufzeit() {
        XCTAssertEqual(Betriebsbild.abtauAnteil(antwort()) ?? 0, 40.0 / 600, accuracy: 1e-9)
        XCTAssertNil(Betriebsbild.abtauAnteil(antwort(laufMin: 0)))
        XCTAssertNil(Betriebsbild.abtauAnteil(antwort(laufMin: nil)))
        // Kein gemeldetes Abtauen ist null Prozent und nicht „kein Wert“.
        XCTAssertEqual(Betriebsbild.abtauAnteil(antwort(abtauMin: nil)), 0)
    }

    func testDerKurzanteilZaehltDieKlasseAbNull() {
        XCTAssertEqual(Betriebsbild.kurzAnteil(antwort()), 0.25)
        XCTAssertNil(Betriebsbild.kurzAnteil(antwort(klassen: [])))
        // Ohne Klasse „ab null“ gibt es keine kurzen Läufe, aber einen Anteil.
        let ohne = antwort(klassen: [BetriebKlasseOut(vonMin: 10, bisMin: 20, laeufe: 4)])
        XCTAssertEqual(Betriebsbild.kurzAnteil(ohne), 0)
    }

    // MARK: - Die vier Kacheln

    func testDieVierKachelnStehenInDerFolgeDerVorlage() {
        let k = Betriebsbild.kacheln(antwort())
        XCTAssertEqual(
            k.map(\.wort),
            ["Starts je Tag", "Ein Lauf dauert", "Abtauen", "Arbeitszahl über alles"])
        XCTAssertEqual(k[0].wert, "8,0")
        XCTAssertEqual(k[0].ton, .bernstein)
        XCTAssertEqual(k[0].dazu, "an Tagen mit Betrieb")
        XCTAssertEqual(k[1].wert, "42\(Formate.schmalesLeerzeichen)min")
        XCTAssertEqual(k[1].dazu, "25\(Formate.schmalesLeerzeichen)% unter zehn Minuten")
        XCTAssertEqual(k[2].wert, "6,7")
        XCTAssertEqual(k[2].einheit, "%")
        XCTAssertEqual(k[2].dazu, "der Laufzeit · 8-mal")
        XCTAssertEqual(k[3].wert, "3,86")
        XCTAssertEqual(k[3].dazu, "im Heizbetrieb 4,30")
    }

    /// Fehlt eine Zahl, steht „?“ und der Ton ist gedämpft (`Betrieb.tsx:74-77`).
    func testFehlendeZahlenStehenAlsFragezeichenUndGedaempft() {
        let leer = antwort(
            tage: [], klassen: [], starts: nil, laufMin: 0, abtauMin: nil, abtauungen: nil,
            copGesamt: nil, copHeizen: nil, laufMedianMin: nil)
        let k = Betriebsbild.kacheln(leer)
        XCTAssertEqual(k.map(\.wert), ["?", "?", "?", "?"])
        XCTAssertEqual(k.map(\.ton), [.gedaempft, .gedaempft, .gedaempft, .gedaempft])
        // Ohne Lauf nennt die Abtaukachel keine Zahl von Abtauungen (`Betrieb.tsx:76`).
        XCTAssertEqual(k[2].dazu, "der Laufzeit")
        XCTAssertEqual(k[1].dazu, "im Mittel")
        XCTAssertEqual(k[3].dazu, "Wärme durch Strom")
    }

    // MARK: - Die Klassen der Lauflängen

    /// `betrieb.test.ts:68` - die Wörter, nicht die Spannen.
    func testDieKlassenHeissenWieInDerVorlage() {
        XCTAssertEqual(
            antwort().klassen.map(Betriebsbild.klassenName),
            ["unter 10 min", "10 bis 20", "20 bis 40", "40 bis 90", "ab 90 min"])
    }

    func testEineEinzigeOffeneKlasseErgibtKeinenUnsinn() {
        // „ab 0 min“ und nicht „unter null min“: die offene Grenze wird zuerst geprüft.
        XCTAssertEqual(Betriebsbild.klassenName(BetriebKlasseOut(vonMin: 0, laeufe: 3)), "ab 0 min")
    }

    func testDerLaufzahlsatzZaehltRichtig() {
        XCTAssertTrue(Betriebsbild.laufzahlsatz(antwort()).hasPrefix("16 vollständige Läufe."))
        let einer = antwort(klassen: [BetriebKlasseOut(vonMin: 0, bisMin: 10, laeufe: 1)])
        XCTAssertTrue(Betriebsbild.laufzahlsatz(einer).hasPrefix("1 vollständiger Lauf."))
        XCTAssertTrue(Betriebsbild.laufzahlsatz(antwort(klassen: [])).hasPrefix("0 vollständige"))
    }

    func testDieAchseDerLaeufeTraegtNurGanzeZahlen() {
        let m = Betriebsbild.laufmarken(antwort())
        XCTAssertTrue(m.allSatisfy { $0 == $0.rounded() }, "gebrochene Läufe: \(m)")
        XCTAssertEqual(m.first, 0)
        XCTAssertGreaterThanOrEqual(m.last ?? 0, 6)
        // Ohne Klassen bleibt eine Achse von null bis eins stehen - keine leere Achse.
        XCTAssertEqual(Betriebsbild.laufmarken(antwort(klassen: [])), [0, 1])
    }

    // MARK: - Die Arbeitszahl je Tag

    /// `betrieb.test.ts:73-81`: zwei Reihen, und der Tag ohne Lauf bleibt eine Lücke.
    func testDieArbeitszahlkurvenZerfallenAnEinemTagOhneLauf() {
        let s = Betriebsbild.copstuecke(antwort())
        // Je Reihe ein Stück, weil die Lücke am Anfang liegt und keines zerschneidet.
        XCTAssertEqual(s.map(\.reihe), [.heizbetrieb, .ueberAlles])
        XCTAssertEqual(s[0].punkte.map(\.beschriftung), ["13.11.", "14.11."])
        XCTAssertEqual(s[0].punkte.map(\.wert), [4.3, 4.3])
        XCTAssertEqual(s[1].punkte.map(\.wert), [3.86, 3.86])
        // **Je Stück ein eigener Schlüssel** - sonst wird aus allen eine Linie.
        XCTAssertEqual(Set(s.map(\.id)).count, s.count)
    }

    func testEineLueckeInDerMitteMachtZweiStuecke() {
        let b = antwort(tage: [
            tag(tag: "2026-11-12"),
            tag(tag: "2026-11-13", laufMin: 0, copTag: nil, copHeizen: nil),
            tag(tag: "2026-11-14"),
        ])
        let s = Betriebsbild.copstuecke(b).filter { $0.reihe == .ueberAlles }
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s[0].punkte.map(\.beschriftung), ["12.11."])
        XCTAssertEqual(s[1].punkte.map(\.beschriftung), ["14.11."])
    }

    func testOhneJedeArbeitszahlKeinStueck() {
        let b = antwort(tage: [tag(copTag: nil, copHeizen: nil)])
        XCTAssertTrue(Betriebsbild.copstuecke(b).isEmpty)
    }

    /// `betrieb.test.ts:79-81` - drei Fassungen der Achse.
    func testDieAchseDerArbeitszahlUmschliesstDieWerte() {
        XCTAssertEqual(Betriebsbild.copSpanne(antwort()), 2...5)
        let weit = antwort(tage: [tag(copTag: 1.4, copHeizen: 5.6)])
        XCTAssertEqual(Betriebsbild.copSpanne(weit), 1...6)
        XCTAssertEqual(Betriebsbild.copSpanne(antwort(tage: [])), 2...5)
    }

    func testDieFarbenDerBeidenLinienSindDasPaarDerVorlage() {
        XCTAssertEqual(Betriebsbild.copfarbe(.heizbetrieb), Marken.waermepumpe)
        XCTAssertEqual(Betriebsbild.copfarbe(.ueberAlles), Marken.haus)
    }

    // MARK: - Die Heizkurve

    /// `betrieb.test.ts:83-90`: Gerade aus zwei Punkten, Reihen nur, wenn es sie gibt.
    func testDieGeradeStehtAufZweiPunkten() {
        guard let hk = antwort().heizkurve else { return XCTFail("die Vorlage setzt sie") }
        let p = Betriebsbild.geradenpunkte(hk)
        XCTAssertEqual(p.count, 2)
        XCTAssertEqual(p[0].aussen, 0)
        XCTAssertEqual(p[0].vorlauf, 44, accuracy: 1e-9)
        XCTAssertEqual(p[1].aussen, 10)
        XCTAssertEqual(p[1].vorlauf, 37, accuracy: 1e-9)
    }

    func testDieLegendeNenntNurDieReihenDieEsGibt() {
        XCTAssertEqual(Betriebsbild.heizkurvenreihen(antwort()), ["Sollwert", "erreicht", "Gerade"])
        XCTAssertEqual(
            Betriebsbild.heizkurvenreihen(antwort(heizkurve: .some(nil))),
            ["Sollwert", "erreicht"])
        let ohneVorlauf = [
            BetriebStundeOut(at: "2026-11-14T15:00:00Z", minuten: 30, aussenC: 10, sollC: 37)
        ]
        XCTAssertEqual(
            Betriebsbild.heizkurvenreihen(antwort(stunden: ohneVorlauf, heizkurve: .some(nil))),
            ["Sollwert"])
    }

    func testDiePunktwolkeNimmtJedeStundeUndDenVorlaufNurWoErDaIst() {
        XCTAssertEqual(Betriebsbild.sollpunkte(antwort()).count, 2)
        XCTAssertEqual(Betriebsbild.erreichtpunkte(antwort()).count, 1)
        XCTAssertEqual(Betriebsbild.erreichtpunkte(antwort())[0].vorlauf, 41.5)
    }

    func testBeideAchsenBeginnenNichtBeiNull() {
        let s = Betriebsbild.heizkurvenspannen(antwort())
        XCTAssertNotNil(s)
        guard let s else { return }
        XCTAssertGreaterThan(s.vorlauf.lowerBound, 10, "die Achse beginnt bei Null")
        XCTAssertLessThanOrEqual(s.vorlauf.lowerBound, 37)
        XCTAssertGreaterThanOrEqual(s.vorlauf.upperBound, 44)
        XCTAssertLessThanOrEqual(s.aussen.lowerBound, 0)
        XCTAssertGreaterThanOrEqual(s.aussen.upperBound, 10)
    }

    func testOhneStundenUndOhneGeradeKeineSpannen() {
        XCTAssertNil(Betriebsbild.heizkurvenspannen(antwort(stunden: [], heizkurve: .some(nil))))
    }

    func testDerFussNenntStundenUndStreuung() {
        let f = Betriebsbild.heizkurvenfuss(antwort())
        XCTAssertEqual(f.formel, "Sollwert = 44,0 - 0,70 × Außentemperatur")
        XCTAssertTrue(f.satz.hasPrefix("aus 24 Stunden, erklärt 98"), f.satz)
        XCTAssertTrue(f.satz.contains("für Warmwasser mehr verlangt."))
    }

    func testOhneGeradeStehtDortDerErsatzsatz() {
        let f = Betriebsbild.heizkurvenfuss(antwort(heizkurve: .some(nil)))
        XCTAssertNil(f.formel)
        XCTAssertEqual(f.satz, Betriebsbild.keineGeradeSatz)
    }

    func testOhneBestimmtheitsmassFaelltNurDieStreuungWeg() {
        let hk = BetriebHeizkurveOut(
            a: 44, b: -0.7, n: 7, aussenVonC: 0, aussenBisC: 10, formelDe: "y = 44 − 0,7x")
        let f = Betriebsbild.heizkurvenfuss(antwort(heizkurve: .some(hk)))
        XCTAssertTrue(f.satz.hasPrefix("aus 7 Stunden. Jeder Punkt"), f.satz)
    }

    // MARK: - Das Abgelesene

    /// `betrieb.test.ts:92-95`: im Hinweis steht nur, was es an dem Tag gab.
    func testDieAuskunftNenntNurWasEsGab() {
        let mit = Betriebsbild.tagzeilen(tag()).map(\.wort)
        XCTAssertEqual(mit, ["Lauf", "Starts", "Abtauen", "Heizstab", "Strom", "draußen"])
        let ohne = Betriebsbild.tagzeilen(
            tag(abtauMin: 0, abtauungen: 0, zusatzMin: 0, aussenC: nil)
        ).map(\.wort)
        XCTAssertEqual(ohne, ["Lauf", "Starts", "Strom"])
    }

    func testDieAuskunftDerArbeitszahlNenntDieWaermeNurWennSieDaIst() {
        XCTAssertEqual(
            Betriebsbild.copzeilen(tag()).map(\.wort),
            ["im Heizbetrieb", "über alles", "Wärme"])
        XCTAssertEqual(
            Betriebsbild.copzeilen(tag(waermeKwh: nil, copTag: nil)).map(\.wort),
            ["im Heizbetrieb", "über alles"])
        XCTAssertEqual(Betriebsbild.copzeilen(tag(copTag: nil))[1].wert, "?")
    }

    func testDieAuskunftEinerStundeUndIhrKopf() {
        let s = BetriebStundeOut(
            at: "2026-11-14T05:00:00Z", minuten: 60, aussenC: 0, sollC: 44, vorlaufC: 41.5)
        // 05:00 UTC ist im November 06:00 in der Zeit des Hauses, und Tag und Monat stehen
        // hier zweistellig.
        XCTAssertEqual(Betriebsbild.stundenkopf(s), "14.11., 06:00")
        XCTAssertEqual(
            Betriebsbild.stundenzeilen(s).map(\.wort),
            ["draußen", "Sollwert", "erreicht", "im Heizbetrieb"])
        let ohne = BetriebStundeOut(
            at: "2026-11-14T15:00:00Z", minuten: 30, aussenC: 10, sollC: 37)
        XCTAssertEqual(
            Betriebsbild.stundenzeilen(ohne).map(\.wort),
            ["draußen", "Sollwert", "im Heizbetrieb"])
        // Ein unleserlicher Zeitstempel ersetzt die Seite nicht - er steht da, wie er kam.
        let krumm = BetriebStundeOut(at: "gestern", minuten: 5, aussenC: 1, sollC: 40)
        XCTAssertEqual(Betriebsbild.stundenkopf(krumm), "gestern")
    }

    // MARK: - Was unter dem Finger liegt

    func testDieBeruehrteStelleFindetIhrenTag() {
        let b = antwort()
        XCTAssertEqual(Betriebsbild.tagMit(b, beschriftung: "13.11.")?.starts, 10)
        XCTAssertNil(Betriebsbild.tagMit(b, beschriftung: "1.1."))
        XCTAssertNil(Betriebsbild.tagMit(b, beschriftung: nil))
    }

    func testDieBeruehrteStelleFindetIhreKlasse() {
        let b = antwort()
        XCTAssertEqual(Betriebsbild.klasseMit(b, name: "ab 90 min")?.laeufe, 1)
        XCTAssertEqual(Betriebsbild.klasseMit(b, name: "unter 10 min")?.laeufe, 4)
        XCTAssertNil(Betriebsbild.klasseMit(b, name: "90+"))
        XCTAssertNil(Betriebsbild.klasseMit(b, name: nil))
    }

    func testDieBeruehrteStelleFindetDieNaechsteStunde() {
        let b = antwort()
        XCTAssertEqual(Betriebsbild.stundeBei(b, aussen: 1)?.sollC, 44)
        XCTAssertEqual(Betriebsbild.stundeBei(b, aussen: 8)?.sollC, 37)
        // Bei gleichem Abstand die erste, damit dieselbe Berührung dasselbe zeigt.
        XCTAssertEqual(Betriebsbild.stundeBei(b, aussen: 5)?.sollC, 44)
        XCTAssertNil(Betriebsbild.stundeBei(b, aussen: nil))
        XCTAssertNil(Betriebsbild.stundeBei(antwort(stunden: []), aussen: 0))
    }

    func testDieBalkenbreiteIstNurBeiWenigenTagenFest() {
        XCTAssertEqual(Betriebsbild.balkenbreite(antwort()), 26)
        let viele = (0..<30).map { tag(tag: Tag.plus("2026-10-01", $0)) }
        XCTAssertNil(Betriebsbild.balkenbreite(antwort(tage: viele)))
    }

    // MARK: - Kopf, Weiche und Tabelle

    func testDerErsteSatzFuehrtUndDieUebrigenFolgen() {
        let b = antwort(saetzeDe: ["Sie taktet.", "Abtauen kostet 7 Prozent.", "Dritter Satz."])
        XCTAssertEqual(Betriebsbild.kopfsatz(b), "Sie taktet.")
        XCTAssertEqual(
            Betriebsbild.weitereSaetze(b), ["Abtauen kostet 7 Prozent.", "Dritter Satz."])
        XCTAssertEqual(Betriebsbild.kopfsatz(antwort()), Betriebsbild.keinKopfsatz)
        XCTAssertTrue(Betriebsbild.weitereSaetze(antwort()).isEmpty)
        // Ein einziger Satz führt und lässt die Karte darunter weg.
        XCTAssertTrue(Betriebsbild.weitereSaetze(antwort(saetzeDe: ["Allein."])).isEmpty)
    }

    func testDieStandzeileNenntDenRueckblickUndHaengtDenFehlerAn() {
        XCTAssertEqual(Betriebsbild.standzeile(antwort()), "Letzte 14 Tage")
        XCTAssertEqual(
            Betriebsbild.standzeile(antwort(), fehler: "Dienst schweigt"),
            "Letzte 14 Tage · Dienst schweigt")
        XCTAssertEqual(Betriebsbild.standzeile(antwort(), fehler: ""), "Letzte 14 Tage")
    }

    func testDieWeicheHaengtAnDerLaufzeit() {
        XCTAssertTrue(Betriebsbild.lief(antwort()))
        XCTAssertFalse(Betriebsbild.lief(antwort(laufMin: 0)))
        XCTAssertFalse(Betriebsbild.lief(antwort(laufMin: nil)))
    }

    func testDieTabelleHatElfSpaltenUndDenNeuestenTagOben() {
        let b = antwort()
        XCTAssertEqual(Betriebsbild.tabellenzeilen(b), ["14.11.", "13.11.", "12.11."])
        let s = Betriebsbild.tabellenspalten(b)
        XCTAssertEqual(
            s.map(\.name),
            [
                "draußen", "Starts", "Lauf", "Lauf im Mittel", "Abtauen", "Heizstab", "Strom",
                "Wärme", "Arbeitszahl", "im Heizbetrieb",
            ])
        // Zehn Spalten plus die Zeilennamen sind die elf der Vorlage.
        XCTAssertEqual(s.count + 1, 11)
        XCTAssertTrue(s.allSatisfy { $0.zellen.count == 3 })
        XCTAssertEqual(Betriebsbild.tabellengriff(b), "Die Tage als Tabelle (3)")
    }

    func testDieZellenSchreibenNullWoNichtsWarUndFragezeichenWoKeinWertKam() {
        let b = antwort(tage: [
            tag(abtauMin: 0, abtauungen: 0, zusatzMin: 0, waermeKwh: nil, copTag: nil,
                laufMedianMin: nil, aussenC: nil)
        ])
        let s = Betriebsbild.tabellenspalten(b)
        func zelle(_ name: String) -> String? {
            s.first { $0.name == name }?.zellen.first
        }
        XCTAssertEqual(zelle("Abtauen"), "0")
        XCTAssertEqual(zelle("Heizstab"), "0")
        XCTAssertEqual(zelle("draußen"), "?")
        XCTAssertEqual(zelle("Lauf im Mittel"), "?")
        XCTAssertEqual(zelle("Wärme"), "?")
        XCTAssertEqual(zelle("Arbeitszahl"), "?")
        XCTAssertEqual(zelle("Strom"), "14,2\(Formate.schmalesLeerzeichen)kWh")
        XCTAssertEqual(zelle("Abtauen"), "0")
    }

    func testDieZelleDesAbtauensNenntDieZahlDerAbtauungen() {
        let s = Betriebsbild.tabellenspalten(antwort(tage: [tag()]))
        XCTAssertEqual(
            s.first { $0.name == "Abtauen" }?.zellen.first,
            "20\(Formate.schmalesLeerzeichen)min · 4-mal")
    }

    func testOhneTageKeineTabelle() {
        let b = antwort(tage: [])
        XCTAssertTrue(Betriebsbild.tabellenzeilen(b).isEmpty)
        XCTAssertTrue(Betriebsbild.tabellenspalten(b).allSatisfy { $0.zellen.isEmpty })
        XCTAssertEqual(Betriebsbild.tabellengriff(b), "Die Tage als Tabelle (0)")
    }
}
