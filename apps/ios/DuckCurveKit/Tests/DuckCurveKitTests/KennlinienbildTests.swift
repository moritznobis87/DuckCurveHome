import XCTest

@testable import DuckCurveKit

/// Die Rechnungen der gemessenen Kennlinie - Fall für Fall dieselben wie in
/// `apps/web/src/components/waermepumpe/kennlinie.ts` und `bilanz.ts`.
///
/// **Warum die Fälle der Vorlage und nicht eigene.** An vier Stellen rundet die Vorlage anders,
/// als man es von Hand täte: die Gesamt-Arbeitszahl ist nach Minuten *und* Leistung gewichtet,
/// r² steht in ganzen Prozent, die Skala des Kennfelds liegt auf halben Schritten, und die
/// Zellen des Kennfelds sind auf zwei Stellen gerundet, bevor die Spanne daraus entsteht. Ein
/// eigener Testsatz hätte dieselben Zahlen anders gerundet und dann bewiesen, dass die App zu
/// sich selbst passt.
final class KennlinienbildTests: XCTestCase {

    // MARK: - Die Antwort, wie sie der Dienst liefert

    private func punkt(
        at: String = "2026-11-14T19:00:00Z", minuten: Int = 10, aussenC: Double = 5,
        vorlaufC: Double = 35, cop: Double = 3, waermeKw: Double = 3, stromKw: Double = 1,
        ventil: Int? = 1
    ) -> KennlinienPunktOut {
        KennlinienPunktOut(
            at: at, minuten: minuten, aussenC: aussenC, vorlaufC: vorlaufC, cop: cop,
            waermeKw: waermeKw, stromKw: stromKw, ventil: ventil)
    }

    /// Drei Punkte, deren Mediane in der Mitte liegen: draußen 5 °C, Vorlauf 35 °C.
    private var dreiPunkte: [KennlinienPunktOut] {
        [
            punkt(
                at: "2026-11-14T17:00:00Z", aussenC: 2, vorlaufC: 32, cop: 4, waermeKw: 4,
                stromKw: 1, ventil: 1),
            punkt(
                at: "2026-11-14T18:00:00Z", aussenC: 5, vorlaufC: 35, cop: 3, waermeKw: 3,
                stromKw: 1, ventil: 2),
            punkt(
                at: "2026-11-14T19:00:00Z", aussenC: 8, vorlaufC: 40, cop: 2, waermeKw: 2,
                stromKw: 1, ventil: nil),
        ]
    }

    private func fit(
        art: KennlinienFitOutArtWahl = .ebene, a: Double = 3.5, bAussen: Double = 0.1,
        cVorlauf: Double = -0.04, n: Int = 3, rmse: Double = 0.123, r2: Double? = 0.842,
        aussenVonC: Double = 2, aussenBisC: Double = 8, vorlaufVonC: Double = 32,
        vorlaufBisC: Double = 40
    ) -> KennlinienFitOut {
        KennlinienFitOut(
            art: art, a: a, bAussen: bAussen, cVorlauf: cVorlauf, n: n, rmse: rmse, r2: r2,
            aussenVonC: aussenVonC, aussenBisC: aussenBisC, vorlaufVonC: vorlaufVonC,
            vorlaufBisC: vorlaufBisC,
            formelDe: "COP = 3,50 + 0,10 · draußen − 0,04 · Vorlauf",
            geltungDe: "Gilt für 2 bis 8 °C draußen und 32 bis 40 °C Vorlauf.")
    }

    private func bilanz(
        minuten: Int = 43200, heizen: Int = 600, anlauf: Int = 60, zusatz: Int = 30,
        ohneWert: Int = 10, ohneWaerme: Int = 0, gueltig: Int = 500, fenster: Int = 55,
        punkte: Int = 50, unglaubwuerdig: Int = 2,
        fehlt: [String: Int] = ["strom": 25, "aussen": 10, "vorlauf": 10],
        satzDe: String? = "Es waren 500 von 600 Minuten brauchbar."
    ) -> KennlinienBilanzOut {
        KennlinienBilanzOut(
            minuten: minuten, heizen: heizen, anlauf: anlauf, zusatz: zusatz,
            ohneWert: ohneWert, ohneWaerme: ohneWaerme, gueltig: gueltig, fenster: fenster,
            punkte: punkte, unglaubwuerdig: unglaubwuerdig, fehlt: fehlt, verhaeltnis: nil,
            satzDe: satzDe)
    }

    private func antwort(
        tage: Int = 30, punkte: [KennlinienPunktOut]? = nil, fit: KennlinienFitOut?? = nil,
        fehltDe: String? = nil,
        annahme: [KennlinienAnnahmeOut]? = nil, annahmeVorlaufC: Double? = 35,
        bilanz: KennlinienBilanzOut?? = nil, hinweiseDe: [String] = ["Geschätzt aus Spreizung."]
    ) -> KennlinieOut {
        KennlinieOut(
            now: "2026-11-14T19:00:00Z", von: "2026-10-15T19:00:00Z",
            bis: "2026-11-14T19:00:00Z", tage: tage, punkte: punkte ?? dreiPunkte,
            fit: fit ?? self.fit(), fehltDe: fehltDe,
            annahme: annahme
                ?? [
                    KennlinienAnnahmeOut(aussenC: -5, cop: 2.2),
                    KennlinienAnnahmeOut(aussenC: 5, cop: 3.1),
                ],
            annahmeVorlaufC: annahmeVorlaufC, bilanz: bilanz ?? self.bilanz(),
            hinweiseDe: hinweiseDe)
    }

    /// Ein schmales Leerzeichen vor der Einheit, wie ``Formate`` es überall setzt.
    private var sp: String { Formate.schmalesLeerzeichen }

    // MARK: - Die Rechnungen des Ausgleichs

    func testCopNachIstDieEbene() {
        let f = fit()
        XCTAssertEqual(Kennlinienbild.copNach(f, aussen: 5, vorlauf: 35), 2.6, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.copNach(f, aussen: 0, vorlauf: 0), 3.5, accuracy: 1e-9)
    }

    /// Nach Minuten **und** Leistung gewichtet: Summe der Wärme durch Summe des Stroms.
    ///
    /// Der Fall trennt die beiden Rechnungen: das Mittel der Einzel-Arbeitszahlen wäre hier 3,0;
    /// gewichtet kommt 2,0 heraus, weil das Fenster mit der schlechten Arbeitszahl dreimal so
    /// lang ist und die doppelte Leistung zieht.
    func testGesamtIstGewichtetUndNichtDasMittelDerEinzelwerte() {
        let p = [
            punkt(minuten: 10, cop: 4, waermeKw: 4, stromKw: 1),
            punkt(minuten: 30, cop: 2, waermeKw: 4, stromKw: 2),
        ]
        let einzelmittel = (4.0 + 2.0) / 2
        XCTAssertEqual(einzelmittel, 3.0, accuracy: 1e-9)
        // (4·10 + 4·30) / (1·10 + 2·30) = 160 / 70
        XCTAssertEqual(Kennlinienbild.gesamt(p)!, 160.0 / 70.0, accuracy: 1e-9)
    }

    func testGesamtOhneStromUndOhnePunkteIstNichts() {
        XCTAssertNil(Kennlinienbild.gesamt([]))
        XCTAssertNil(Kennlinienbild.gesamt([punkt(stromKw: 0)]))
        XCTAssertNil(Kennlinienbild.gesamt([punkt(minuten: 0, stromKw: 2)]))
    }

    func testMitteIstDerMedian() {
        XCTAssertEqual(Kennlinienbild.mitte([3, 1, 2])!, 2, accuracy: 1e-9)
        // Gerade Anzahl: das Mittel der beiden mittleren.
        XCTAssertEqual(Kennlinienbild.mitte([1, 2, 3, 10])!, 2.5, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.mitte([7])!, 7, accuracy: 1e-9)
        XCTAssertNil(Kennlinienbild.mitte([]))
    }

    func testVorlaufStufenSindRundeFuenferUndHoechstensDrei() {
        // 32 bis 40: die runden Fünfer darin sind 35 und 40.
        XCTAssertEqual(Kennlinienbild.vorlaufStufen(fit()), [35, 40])
        // 30 bis 52: fünf Stufen, davon erste, mittlere, letzte.
        XCTAssertEqual(
            Kennlinienbild.vorlaufStufen(fit(vorlaufVonC: 30, vorlaufBisC: 52)),
            [30, 40, 50])
    }

    /// Ohne Vorlaufterm keine Stufen: eine Gerade je Stufe wäre fünfmal dieselbe Gerade.
    func testVorlaufStufenNurBeiEinerEbene() {
        for art in [KennlinienFitOutArtWahl.aussen, .vorlauf, .mittel, .unbekannt] {
            XCTAssertEqual(Kennlinienbild.vorlaufStufen(fit(art: art)), [], "\(art)")
        }
    }

    /// Eine Spanne ohne runden Fünfer darin ergibt keine Stufe und keine Endlosschleife.
    func testVorlaufStufenKannLeerSein() {
        XCTAssertEqual(Kennlinienbild.vorlaufStufen(fit(vorlaufVonC: 36, vorlaufBisC: 39)), [])
    }

    func testCopAchseKlemmtAufGanzeGrenzen() {
        let k = antwort()
        // Punkte 2 bis 4, Annahme 2,2 bis 3,1: floor(2 − 0,25) = 1, ceil(4 + 0,25) = 5.
        XCTAssertEqual(Kennlinienbild.copAchse(punkte: k.punkte, annahme: k.annahme), 1...5)
    }

    /// Nie unter null: eine negative Arbeitszahl gibt es nicht, und eine Achse, die sie
    /// anbietet, verschenkt die Hälfte des Bildes.
    func testCopAchseGehtNichtUnterNull() {
        let p = [punkt(cop: 0.1)]
        XCTAssertEqual(Kennlinienbild.copAchse(punkte: p, annahme: []), 0...1)
    }

    func testCopAchseOhneWerteIstDerBereichDerVorlage() {
        XCTAssertEqual(Kennlinienbild.copAchse(punkte: [], annahme: []), 1...6)
    }

    // MARK: - Der Kopf der Seite

    func testKopfsatzMitFitNenntDieMedianeUndDieKernzahl() {
        XCTAssertEqual(
            Kennlinienbild.kopfsatz(antwort()),
            "Nach 3 Messpunkten macht die Wärmepumpe bei 5\(sp)°C draußen und 35\(sp)°C Vorlauf "
                + "aus einer Kilowattstunde Strom 2,6 Kilowattstunden Wärme.")
    }

    func testKopfsatzOhneFitNenntDasGewichteteMittel() {
        let k = antwort(fit: .some(nil))
        XCTAssertEqual(
            Kennlinienbild.kopfsatz(k), "3 Messpunkte bisher, Arbeitszahl im Mittel 3,0.")
    }

    func testKopfsatzBeiEinemPunktIstEinzahl() {
        let k = antwort(punkte: [punkt(waermeKw: 3, stromKw: 1)], fit: .some(nil))
        XCTAssertEqual(
            Kennlinienbild.kopfsatz(k), "1 Messpunkt bisher, Arbeitszahl im Mittel 3,0.")
    }

    func testKopfsatzOhnePunkteUndOhneFit() {
        XCTAssertEqual(
            Kennlinienbild.kopfsatz(antwort(punkte: [], fit: .some(nil))),
            "Noch gibt es keine Messpunkte.")
    }

    /// Ein Ausgleich ohne Punkte kommt vor (die Punkte sind gekappt, der Ausgleich bleibt) -
    /// dann gibt es keinen Median, und der Satz fällt auf die letzte Fassung zurück.
    func testKopfsatzMitFitAberOhnePunkte() {
        XCTAssertEqual(
            Kennlinienbild.kopfsatz(antwort(punkte: [])), "Noch gibt es keine Messpunkte.")
    }

    func testStandzeileHaengtDenFehlerAnUndErsetztNichts() {
        XCTAssertEqual(Kennlinienbild.standzeile(antwort()), "Letzte 30 Tage")
        XCTAssertEqual(
            Kennlinienbild.standzeile(antwort(tage: 180), fehler: Kennlinienbild.fehlersatz),
            "Letzte 180 Tage · Die Kennlinie ist gerade nicht zu erreichen.")
        XCTAssertEqual(Kennlinienbild.standzeile(antwort(), fehler: ""), "Letzte 30 Tage")
    }

    /// 180 Tage fehlten in der App und stehen in der Vorlage (`Kennlinie.tsx:22`).
    func testRueckblickeWieDieVorlage() {
        XCTAssertEqual(Kennlinienbild.rueckblicke, [7, 30, 90, 180])
    }

    // MARK: - Die vier Kacheln

    func testKachelnSindVierInDerReihenfolgeDerVorlage() {
        let k = Kennlinienbild.kacheln(antwort())
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Messpunkte", "Arbeitszahl im Mittel", "Je Grad wärmer draußen",
                "Je Grad mehr Vorlauf",
            ])
        XCTAssertEqual(k.map(\.wert), ["3", "3,0", "+0,10", "\(Formate.minus)0,04"])
        XCTAssertEqual(k[0].ton, .bernstein)
        XCTAssertEqual(k[0].dazu, "je zehn Minuten Heizbetrieb")
        XCTAssertEqual(k[1].dazu, "Wärme durch Strom, alle Punkte")
        XCTAssertEqual(k[2].ton, .normal)
    }

    /// Das Minus ist U+2212 und nicht der Bindestrich (`Kennlinie.tsx:143`, `:149`).
    func testSteigungTraegtDasEchteMinuszeichen() {
        XCTAssertEqual(Kennlinienbild.steigung(0.12), "+0,12")
        XCTAssertEqual(Kennlinienbild.steigung(-0.12), "\u{2212}0,12")
        XCTAssertEqual(Kennlinienbild.steigung(0), "+0,00")
        XCTAssertFalse(Kennlinienbild.steigung(-0.12).contains("-"))
    }

    /// Ohne Punkte und ohne Ausgleich zeigen drei Kacheln ein Fragezeichen - und sind gedämpft.
    func testKachelnOhneAusgleichZeigenFragezeichenGedaempft() {
        let k = Kennlinienbild.kacheln(antwort(punkte: [], fit: .some(nil)))
        XCTAssertEqual(k.map(\.wert), ["0", "?", "?", "?"])
        XCTAssertEqual(k.map(\.ton), [.gedaempft, .gedaempft, .gedaempft, .gedaempft])
    }

    /// Kennt der Ausgleich nur die Außentemperatur, steht die Vorlaufsteigung nicht da.
    func testKachelnBeiEinemAusgleichNurUeberDraussen() {
        let k = Kennlinienbild.kacheln(antwort(fit: fit(art: .aussen)))
        XCTAssertEqual(k[2].wert, "+0,10")
        XCTAssertEqual(k[2].ton, .normal)
        XCTAssertEqual(k[3].wert, "?")
        XCTAssertEqual(k[3].ton, .gedaempft)
    }

    func testKachelnBeiEinemAusgleichNurUeberDemVorlauf() {
        let k = Kennlinienbild.kacheln(antwort(fit: fit(art: .vorlauf)))
        XCTAssertEqual(k[2].wert, "?")
        XCTAssertEqual(k[3].wert, "\(Formate.minus)0,04")
    }

    // MARK: - Die Formelkarte

    /// r² in Prozent, rmse mit ±-Zeichen und zwei Stellen.
    func testFormelzeileSchreibtProzentUndSpanne() {
        XCTAssertEqual(
            Kennlinienbild.formelzeile(fit()),
            "3 Punkte · mittlere Abweichung ±0,12 · erklärt 84\(sp)% der Streuung. "
                + "Gilt für 2 bis 8 °C draußen und 32 bis 40 °C Vorlauf.")
    }

    func testFormelzeileOhneBestimmtheit() {
        XCTAssertEqual(
            Kennlinienbild.formelzeile(fit(r2: nil)),
            "3 Punkte · mittlere Abweichung ±0,12. "
                + "Gilt für 2 bis 8 °C draußen und 32 bis 40 °C Vorlauf.")
    }

    // MARK: - Die Geraden und ihre Namen

    /// Zwei Endpunkte und nicht vierundzwanzig Schritte.
    func testGeradeHatZweiEnden() {
        let g = Kennlinienbild.gerade(fit(), vorlauf: 35)
        XCTAssertEqual(g.count, 2)
        XCTAssertEqual(g[0].aussen, 2)
        XCTAssertEqual(g[1].aussen, 8)
        XCTAssertEqual(g[0].cop, 3.5 + 0.2 - 1.4, accuracy: 1e-9)
    }

    func testVorlaufgeradeLaeuftUeberDenVorlaufBeiMittlererAussentemperatur() {
        let g = Kennlinienbild.vorlaufgerade(antwort())
        XCTAssertEqual(g.count, 2)
        XCTAssertEqual(g[0].vorlauf, 32)
        XCTAssertEqual(g[1].vorlauf, 40)
        XCTAssertEqual(g[1].cop, 3.5 + 0.5 - 1.6, accuracy: 1e-9)
    }

    func testVorlaufgeradeOhnePunkteOderOhneFitIstLeer() {
        XCTAssertTrue(Kennlinienbild.vorlaufgerade(antwort(punkte: [])).isEmpty)
        XCTAssertTrue(Kennlinienbild.vorlaufgerade(antwort(fit: .some(nil))).isEmpty)
    }

    func testNamenDerGeraden() {
        XCTAssertEqual(Kennlinienbild.stufenname(35), "35 °C Vorlauf")
        XCTAssertEqual(
            Kennlinienbild.vorlaufgeradenname(antwort()), "Ausgleich bei 5\(sp)°C draußen")
        XCTAssertEqual(Kennlinienbild.vorlaufgeradenname(antwort(punkte: [])), "Ausgleich")
    }

    func testAnnahmehinweisNenntDenVorlaufDerAnnahme() {
        XCTAssertEqual(
            Kennlinienbild.annahmehinweis(antwort()),
            "Annahme des Fahrplans, bei 35\(sp)°C Vorlauf")
        XCTAssertEqual(
            Kennlinienbild.annahmehinweis(antwort(annahmeVorlaufC: nil)),
            "Annahme des Fahrplans")
    }

    // MARK: - Das Farbband des Vorlaufs

    func testVorlaufspanneKommtAusDenPunktenUndNichtAusDemFit() {
        // Der Ausgleich gilt für 32 bis 40; gemessen wurde von 32 bis 40.
        XCTAssertEqual(Kennlinienbild.vorlaufspanne(dreiPunkte), 32...40)
        XCTAssertNil(Kennlinienbild.vorlaufspanne([]))
    }

    func testVorlaufspanneBeiEinemPunktIstEinPunkt() {
        XCTAssertEqual(Kennlinienbild.vorlaufspanne([punkt(vorlaufC: 38)]), 38...38)
    }

    /// Fünf Stützen, die unterwegs die Stützstellen der Wasserskala mitnehmen.
    func testBandfarbenSindFuenfUndLiegenAufDerWasserskala() {
        let farben = Kennlinienbild.bandfarben(25...65)
        XCTAssertEqual(farben.count, 5)
        XCTAssertEqual(farben.first, Marken.wasserfarbe(25))
        XCTAssertEqual(farben.last, Marken.wasserfarbe(65))
        XCTAssertEqual(farben[2], Marken.wasserfarbe(45))
    }

    func testBandbeschriftung() {
        XCTAssertEqual(
            Kennlinienbild.bandbeschriftung(32...40),
            "Farbe der Punkte: Vorlauf von 32 bis 40 Grad")
    }

    // MARK: - Der Punkt und die Tabelle

    func testPunktzeilenSindFuenfMitDenStellenDerVorlage() {
        let z = Kennlinienbild.punktzeilen(
            punkt(aussenC: 4.52, vorlaufC: 38.4, cop: 3.456, waermeKw: 4.25, stromKw: 1.234))
        XCTAssertEqual(z.map(\.wort), ["Arbeitszahl", "draußen", "Vorlauf", "Wärme", "Strom"])
        XCTAssertEqual(
            z.map(\.wert),
            ["3,46", "4,5\(sp)°C", "38,4\(sp)°C", "4,3\(sp)kW", "1,23\(sp)kW"])
    }

    /// In der Zeit des Hauses und nicht in der des Zeitstempels: 19:00 UTC sind 20:00 in Berlin.
    func testPunktzeitStehtInDerZeitDesHauses() {
        XCTAssertEqual(
            Kennlinienbild.punktzeit(punkt(at: "2026-11-14T19:00:00Z")), "14.11, 20:00")
    }

    func testPunktzeitOhneLesbarenStempel() {
        XCTAssertEqual(Kennlinienbild.punktzeit(punkt(at: "irgendwann")), Formate.leer)
    }

    /// Neueste zuerst und auf zweihundert gekappt.
    func testTabellenpunkteSindUmgekehrtUndGekappt() {
        let p = Kennlinienbild.tabellenpunkte(antwort())
        XCTAssertEqual(p.map(\.aussenC), [8, 5, 2])
        let viele = (0..<250).map { punkt(minuten: $0, aussenC: Double($0)) }
        let gekappt = Kennlinienbild.tabellenpunkte(antwort(punkte: viele))
        XCTAssertEqual(gekappt.count, 200)
        XCTAssertEqual(gekappt.first?.aussenC, 249)
        XCTAssertEqual(gekappt.last?.aussenC, 50)
    }

    func testTabellengriffNenntDieZahl() {
        XCTAssertEqual(
            Kennlinienbild.tabellengriff(antwort()), "Die Messpunkte als Tabelle (3)")
        XCTAssertEqual(
            Kennlinienbild.tabellengriff(antwort(punkte: [])),
            "Die Messpunkte als Tabelle (0)")
    }

    func testTabellenspaltenSindSechsUndKennenDasVentil() {
        let s = Kennlinienbild.tabellenspalten(antwort())
        XCTAssertEqual(
            s.map(\.name),
            ["draußen", "Vorlauf", "Wärme", "Strom", "Arbeitszahl", "Ventil"])
        XCTAssertEqual(s[0].zellen, ["8,0\(sp)°C", "5,0\(sp)°C", "2,0\(sp)°C"])
        XCTAssertEqual(s[4].zellen, ["2,00", "3,00", "4,00"])
        // Ohne Ventil ein Fragezeichen und keine Null: der Kreis war nicht gemeldet.
        XCTAssertEqual(s[5].zellen, ["?", "2", "1"])
    }

    func testTabellenzeilenSindDieZeitpunkte() {
        XCTAssertEqual(
            Kennlinienbild.tabellenzeilen(antwort()),
            ["14.11, 20:00", "14.11, 19:00", "14.11, 18:00"])
    }

    // MARK: - Die gehaltene Stelle im Diagramm

    func testNaechsteSpalteNimmtDenNaechstenAchsenwert() {
        let p = Kennlinienbild.naechsteSpalte(dreiPunkte, bei: 4.6, nach: .aussen)
        XCTAssertEqual(p.map(\.aussenC), [5])
    }

    /// Alle Punkte derselben Spalte, nicht nur einer - und nach der Zeit sortiert.
    func testNaechsteSpalteZeigtAlleDerSpalte() {
        let viele = [
            punkt(at: "2026-11-14T19:00:00Z", aussenC: 5, cop: 3.4),
            punkt(at: "2026-11-14T17:00:00Z", aussenC: 5, cop: 3.1),
            punkt(at: "2026-11-14T18:00:00Z", aussenC: 9, cop: 2.2),
        ]
        let p = Kennlinienbild.naechsteSpalte(viele, bei: 5.4, nach: .aussen)
        XCTAssertEqual(p.map(\.at), ["2026-11-14T17:00:00Z", "2026-11-14T19:00:00Z"])
    }

    /// Höchstens sechs: eine Spalte mit zwanzig Punkten wäre unter dem Bild eine zweite Seite.
    func testNaechsteSpalteIstGekappt() {
        let viele = (0..<20).map { punkt(at: "2026-11-14T1\($0 % 10):00:00Z", aussenC: 5) }
        XCTAssertEqual(Kennlinienbild.naechsteSpalte(viele, bei: 5, nach: .aussen).count, 6)
    }

    func testNaechsteSpalteNachDemVorlauf() {
        let p = Kennlinienbild.naechsteSpalte(dreiPunkte, bei: 33.4, nach: .vorlauf)
        XCTAssertEqual(p.map(\.vorlaufC), [32])
    }

    func testNaechsteSpalteOhneAuswahlUndOhnePunkte() {
        XCTAssertTrue(Kennlinienbild.naechsteSpalte(dreiPunkte, bei: nil, nach: .aussen).isEmpty)
        XCTAssertTrue(Kennlinienbild.naechsteSpalte([], bei: 5, nach: .aussen).isEmpty)
    }

    // MARK: - Messung gegen die Annahme

    func testVergleichsVorlaufNimmtDenDerAnnahmeWennDerFitIhnKennt() {
        XCTAssertEqual(Kennlinienbild.vergleichsVorlauf(antwort())!, 35, accuracy: 1e-9)
        XCTAssertEqual(
            Kennlinienbild.vergleichsVorlauf(antwort(fit: fit(art: .vorlauf)))!, 35,
            accuracy: 1e-9)
    }

    /// Kennt der Ausgleich den Vorlauf nicht, gilt der Median der Messung - „denn nur dort sagt
    /// er etwas“.
    func testVergleichsVorlaufSonstDerMedianDerMessung() {
        let k = antwort(fit: fit(art: .aussen), annahmeVorlaufC: 50)
        XCTAssertEqual(Kennlinienbild.vergleichsVorlauf(k)!, 35, accuracy: 1e-9)
    }

    func testVergleichsVorlaufOhneFitIstNichts() {
        XCTAssertNil(Kennlinienbild.vergleichsVorlauf(antwort(fit: .some(nil))))
        XCTAssertTrue(Kennlinienbild.vergleich(antwort(fit: .some(nil))).isEmpty)
    }

    /// Ohne Annahmestützstellen gibt es keine Zeilen - und die Karte fällt weg.
    func testVergleichOhneAnnahmeIstLeer() {
        XCTAssertTrue(Kennlinienbild.vergleich(antwort(annahme: [])).isEmpty)
    }

    func testVergleichTrenntGemessenVonVerlaengert() {
        let z = Kennlinienbild.vergleich(antwort())
        XCTAssertEqual(z.count, 2)
        // −5 °C liegt außerhalb von 2 bis 8: verlängert.
        XCTAssertEqual(z[0].aussenC, -5)
        XCTAssertFalse(z[0].gemessen)
        XCTAssertEqual(z[0].messung, 3.5 - 0.5 - 1.4, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.standwort(z[0]), "verlängert")
        // 5 °C liegt darin, und 35 °C Vorlauf auch: gemessen.
        XCTAssertEqual(z[1].aussenC, 5)
        XCTAssertTrue(z[1].gemessen)
        XCTAssertEqual(z[1].annahme, 3.1, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.standwort(z[1]), "gemessen")
    }

    /// Liegt der Vorlauf der Annahme außerhalb der Messung, ist **jede** Zeile verlängert -
    /// auch die, deren Außentemperatur gemessen wurde.
    func testVergleichIstVerlaengertWennDerVorlaufDerAnnahmeNichtGemessenWurde() {
        let k = antwort(annahmeVorlaufC: 55)
        XCTAssertEqual(Kennlinienbild.vergleich(k).filter(\.gemessen).count, 0)
    }

    func testSpaltenkoepfeNennenIhrenVorlauf() {
        XCTAssertEqual(Kennlinienbild.annahmespalte(antwort()), "Annahme (35\(sp)°C Vorlauf)")
        XCTAssertEqual(Kennlinienbild.annahmespalte(antwort(annahmeVorlaufC: nil)), "Annahme")
        XCTAssertEqual(Kennlinienbild.messungsspalte(35), "Messung (35\(sp)°C Vorlauf)")
    }

    // MARK: - Wo die Minuten geblieben sind

    func testBilanzteileInFesterFolgeOhneLeereTeile() {
        let t = Kennlinienbild.bilanzteile(bilanz())
        // „keine Wärme“ hat null Minuten und steht nicht im Balken.
        XCTAssertEqual(t.map(\.art), [.gueltig, .anlauf, .zusatz, .ohneWert])
        XCTAssertEqual(
            t.map(\.name), ["brauchbar", "Anlauf", "Heizstab", "Wert fehlte"])
        XCTAssertEqual(t[0].wozu, "eingeschwungen, alle Werte da")
        XCTAssertEqual(t[1].wozu, "die ersten zehn Minuten nach jedem Start")
        XCTAssertEqual(t[2].wozu, "neben dem Verdichter nahm etwas anderes Strom auf")
        XCTAssertEqual(t[3].wozu, "ein nötiger Wert kam länger nicht vom Bus")
        XCTAssertEqual(t[0].minuten, 500)
        XCTAssertEqual(t[0].anteil, 500.0 / 600.0, accuracy: 1e-9)
        XCTAssertEqual(t.reduce(0.0) { $0 + $1.anteil }, 1, accuracy: 1e-9)
    }

    /// Der Heizstab liegt in der Folge **vor** dem fehlenden Wert, damit die beiden warmen Töne
    /// nicht aneinandergrenzen.
    func testDieWarmenToeneLiegenNichtNebeneinander() {
        let t = Kennlinienbild.bilanzteile(
            bilanz(anlauf: 10, zusatz: 10, ohneWert: 10, ohneWaerme: 10, gueltig: 10))
        XCTAssertEqual(t.map(\.art), [.gueltig, .anlauf, .zusatz, .ohneWaerme, .ohneWert])
        let zusatzStelle = t.firstIndex { $0.art == .zusatz }!
        let ohneWertStelle = t.firstIndex { $0.art == .ohneWert }!
        XCTAssertGreaterThan(ohneWertStelle - zusatzStelle, 1)
    }

    func testBilanzOhneMinutenHatKeinenBalken() {
        let leer = bilanz(
            heizen: 0, anlauf: 0, zusatz: 0, ohneWert: 0, ohneWaerme: 0, gueltig: 0,
            fenster: 0, punkte: 0, unglaubwuerdig: 0, fehlt: [:])
        XCTAssertTrue(Kennlinienbild.bilanzteile(leer).isEmpty)
        XCTAssertNil(Kennlinienbild.punktesatz(leer))
        XCTAssertNil(Kennlinienbild.fehlendsatz(leer))
    }

    func testBilanzanteilInGanzenProzent() {
        let t = Kennlinienbild.bilanzteile(bilanz())
        XCTAssertEqual(Kennlinienbild.bilanzanteil(t[0]), "83\(sp)%")
        XCTAssertEqual(Kennlinienbild.bilanzanteil(t[1]), "10\(sp)%")
        XCTAssertEqual(Kennlinienbild.bilanzanteil(t[3]), "2\(sp)%")
    }

    /// Vier Farben sind vorhandene Marken; der Anlauf ist ``Marken/text3`` mit siebzig Prozent
    /// seiner Deckung (`color-mix(in oklab, var(--text-3) 70%, transparent)`).
    func testBilanzfarbenSindDieDerVorlage() {
        XCTAssertEqual(Kennlinienbild.bilanzfarbe(.gueltig), Marken.amber)
        XCTAssertEqual(Kennlinienbild.bilanzfarbe(.zusatz), Marken.waermepumpe)
        XCTAssertEqual(Kennlinienbild.bilanzfarbe(.ohneWaerme), Marken.linie2)
        XCTAssertEqual(Kennlinienbild.bilanzfarbe(.ohneWert), Marken.alarm)
        let anlauf = Kennlinienbild.bilanzfarbe(.anlauf)
        XCTAssertEqual(anlauf.deckung, Marken.text3.deckung * 0.7, accuracy: 1e-9)
        XCTAssertEqual(anlauf.rot, Marken.text3.rot, accuracy: 1e-9)
        // Leiser als der leiseste Text - sonst liest sich der Anlauf als Aussage.
        XCTAssertLessThan(anlauf.deckung, Marken.text3.deckung)
    }

    func testBilanzbeschriftungNenntDieDauern() {
        XCTAssertEqual(
            Kennlinienbild.bilanzbeschriftung(bilanz()),
            "Von 10\(sp)h im Heizbetrieb: brauchbar 8\(sp)h 20\(sp)min, Anlauf 1\(sp)h, "
                + "Heizstab 30\(sp)min, Wert fehlte 10\(sp)min")
    }

    func testFehlendSortiertDenHaeufigstenNachVorn() {
        let f = Kennlinienbild.fehlend(bilanz())
        XCTAssertEqual(f.map(\.name), ["strom", "aussen", "vorlauf"])
        XCTAssertEqual(f.map(\.minuten), [25, 10, 10])
    }

    /// Ein Wert mit null Minuten fehlte nicht und steht nicht in der Liste.
    func testFehlendUebergehtNullen() {
        XCTAssertTrue(Kennlinienbild.fehlend(bilanz(fehlt: ["strom": 0])).isEmpty)
        XCTAssertTrue(Kennlinienbild.fehlend(bilanz(fehlt: [:])).isEmpty)
        XCTAssertNil(Kennlinienbild.fehlendsatz(bilanz(fehlt: [:])))
    }

    func testFehlendsatzNenntDenBus() {
        XCTAssertEqual(
            Kennlinienbild.fehlendsatz(bilanz()),
            "Gefehlt hat: strom (25\(sp)min), aussen (10\(sp)min), vorlauf (10\(sp)min). "
                + "Kommt ein Wert dauerhaft nicht, liegt es an der Zuordnung auf dem Bus und "
                + "nicht an der Wärmepumpe.")
    }

    func testHalbeFensterNieNegativ() {
        XCTAssertEqual(Kennlinienbild.halbeFenster(bilanz()), 3)
        XCTAssertEqual(
            Kennlinienbild.halbeFenster(bilanz(fenster: 10, punkte: 10, unglaubwuerdig: 4)), 0)
    }

    func testPunktesatzMitUndOhneAngefangeneFenster() {
        XCTAssertEqual(
            Kennlinienbild.punktesatz(bilanz()),
            "Aus den brauchbaren Minuten wurden 50 Messpunkte; 3 angefangene Fenster hatten "
                + "zu wenige davon.")
        XCTAssertEqual(
            Kennlinienbild.punktesatz(bilanz(fenster: 1, punkte: 1, unglaubwuerdig: 0)),
            "Aus den brauchbaren Minuten wurde 1 Messpunkt.")
    }

    // MARK: - Das Kennfeld

    func testKennfeldNurBeiEinerEbene() {
        XCTAssertNotNil(Kennlinienbild.kennfeld(antwort()))
        for art in [KennlinienFitOutArtWahl.aussen, .vorlauf, .mittel, .unbekannt] {
            XCTAssertNil(Kennlinienbild.kennfeld(antwort(fit: fit(art: art))), "\(art)")
        }
        XCTAssertNil(Kennlinienbild.kennfeld(antwort(fit: .some(nil))))
    }

    func testKennfeldrasterIstGanzeGradUndZweiergrade() {
        let feld = Kennlinienbild.kennfeld(antwort())!
        XCTAssertEqual(feld.aussen, [2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(feld.vorlauf, [32, 34, 36, 38, 40])
        XCTAssertEqual(feld.zellen.count, 7)
        XCTAssertEqual(feld.zellen[0].count, 5)
    }

    /// Die Enden werden nach außen gelegt, nicht abgeschnitten: ein Punkt bei 31,4 °C Vorlauf
    /// braucht ein Feld, in das er fällt.
    func testKennfeldrasterLegtDieEndenNachAussen() {
        let feld = Kennlinienbild.kennfeld(
            antwort(fit: fit(aussenVonC: 1.4, aussenBisC: 6.2, vorlaufVonC: 31.4, vorlaufBisC: 39.1)))!
        XCTAssertEqual(feld.aussen, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(feld.vorlauf, [30, 32, 34, 36, 38, 40])
    }

    func testKennfeldzellenSindAufZweiStellenGerundet() {
        let feld = Kennlinienbild.kennfeld(antwort())!
        // 3,5 + 0,1·2 − 0,04·32 = 2,42
        XCTAssertEqual(feld.zellen[0][0], 2.42, accuracy: 1e-9)
        for reihe in feld.zellen {
            for wert in reihe {
                XCTAssertEqual((wert * 100).rounded() / 100, wert, accuracy: 1e-12)
            }
        }
    }

    /// Die Skala liegt auf halben Schritten: 2,10 bis 3,02 werden 2,0 bis 3,5.
    func testKennfeldspanneLiegtAufHalbenSchritten() {
        let feld = Kennlinienbild.kennfeld(antwort())!
        XCTAssertEqual(feld.spanne.lowerBound, 2.0, accuracy: 1e-9)
        XCTAssertEqual(feld.spanne.upperBound, 3.5, accuracy: 1e-9)
        let worte = Kennlinienbild.kennfeldskala(feld.spanne)
        XCTAssertEqual(worte.oben, "COP 3,5")
        XCTAssertEqual(worte.unten, "2,0")
    }

    func testKennfeldbelegungZaehltAufDemRaster() {
        let feld = Kennlinienbild.kennfeld(antwort())!
        XCTAssertEqual(feld.belegung.map { [$0.i, $0.j, $0.anzahl] }, [[0, 0, 1], [3, 2, 1], [6, 4, 1]])
        XCTAssertEqual(feld.meiste, 1)
    }

    /// Zwei Punkte im selben Feld zählen zusammen, auch wenn ihr Vorlauf sich um ein Grad
    /// unterscheidet - gerundet wird auf zwei Grad.
    func testKennfeldbelegungFasstZusammen() {
        let p = [
            punkt(aussenC: 5.2, vorlaufC: 35.4),
            punkt(aussenC: 4.8, vorlaufC: 36.4),
            punkt(aussenC: 5.0, vorlaufC: 36.0),
        ]
        let feld = Kennlinienbild.kennfeld(antwort(punkte: p))!
        XCTAssertEqual(feld.belegung.count, 1)
        XCTAssertEqual(feld.belegung[0].anzahl, 3)
        XCTAssertEqual(feld.aussen[feld.belegung[0].i], 5)
        XCTAssertEqual(feld.vorlauf[feld.belegung[0].j], 36)
        XCTAssertEqual(feld.meiste, 3)
    }

    /// Ein halbes Grad unter null geht nach oben, wie `Math.round` der Vorlage
    /// (`kennlinie.ts:237`), und nicht vom Nullpunkt weg: −2,5 °C belegt die Spalte −2.
    ///
    /// Außentemperaturen kommen mit einer Nachkommastelle und sind im Heizbetrieb oft negativ;
    /// mit Swifts `rounded()` stünde der Kreis eine Spalte neben der Stelle, an der der
    /// Browser ihn zeichnet.
    func testKennfeldbelegungRundetHalbeGradeNachOben() {
        let feld = Kennlinienbild.kennfeld(
            antwort(
                punkte: [punkt(aussenC: -2.5, vorlaufC: 35)],
                fit: fit(aussenVonC: -5, aussenBisC: 2)))!
        XCTAssertEqual(feld.belegung.count, 1)
        XCTAssertEqual(feld.aussen[feld.belegung[0].i], -2)
        XCTAssertEqual(feld.vorlauf[feld.belegung[0].j], 36)
    }

    /// Ein Punkt außerhalb des Rasters wird nicht gezählt - und erfindet kein Feld.
    func testKennfeldbelegungUebergehtPunkteAusserhalb() {
        let feld = Kennlinienbild.kennfeld(antwort(punkte: [punkt(aussenC: -20, vorlaufC: 60)]))!
        XCTAssertTrue(feld.belegung.isEmpty)
        XCTAssertEqual(feld.meiste, 1)
    }

    func testKennfeldanteilKlemmtAufNullBisEins() {
        XCTAssertEqual(Kennlinienbild.kennfeldanteil(2.0, spanne: 2...4), 0, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.kennfeldanteil(3.0, spanne: 2...4), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.kennfeldanteil(9.0, spanne: 2...4), 1, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.kennfeldanteil(1.0, spanne: 2...4), 0, accuracy: 1e-9)
        // Eine Spanne ohne Weite: keine Teilung durch null.
        XCTAssertEqual(Kennlinienbild.kennfeldanteil(3.0, spanne: 3...3), 0, accuracy: 1e-9)
    }

    /// Die Wurzel, weil das Auge die Fläche vergleicht: vier Punkte sind doppelt so groß wie
    /// einer, nicht viermal.
    func testKreisgroesseWaechstMitDerWurzel() {
        XCTAssertEqual(Kennlinienbild.kreisgroesse(anzahl: 1, meiste: 1), 12, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.kreisgroesse(anzahl: 1, meiste: 4), 8.5, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.kreisgroesse(anzahl: 0, meiste: 4), 5, accuracy: 1e-9)
        XCTAssertEqual(Kennlinienbild.kreisgroesse(anzahl: 3, meiste: 0), 5, accuracy: 1e-9)
    }

    func testKennfeldworte() {
        XCTAssertEqual(
            Kennlinienbild.kennfeldort(aussen: 5, vorlauf: 36), "5 °C draußen, 36 °C Vorlauf")
        XCTAssertEqual(
            Kennlinienbild.kennfeldwert(2.4211), "Arbeitszahl nach Ausgleich: 2,42")
        XCTAssertEqual(Kennlinienbild.kennfeldpunkte(1), "1 Messpunkt")
        XCTAssertEqual(Kennlinienbild.kennfeldpunkte(4), "4 Messpunkte")
    }

    // MARK: - Leere und fehlende Antworten

    /// Eine Antwort, in der alles Wahlfreie fehlt, darf keine Rechnung zum Absturz bringen.
    func testLeereAntwortTraegtDieGanzeSeite() {
        let k = KennlinieOut(
            now: "2026-11-14T19:00:00Z", von: "2026-11-07T19:00:00Z",
            bis: "2026-11-14T19:00:00Z", tage: 7)
        XCTAssertEqual(Kennlinienbild.kopfsatz(k), "Noch gibt es keine Messpunkte.")
        XCTAssertEqual(Kennlinienbild.standzeile(k), "Letzte 7 Tage")
        XCTAssertEqual(Kennlinienbild.kacheln(k).count, 4)
        XCTAssertNil(Kennlinienbild.kennfeld(k))
        XCTAssertTrue(Kennlinienbild.vergleich(k).isEmpty)
        XCTAssertNil(Kennlinienbild.vorlaufspanne(k.punkte))
        XCTAssertTrue(Kennlinienbild.tabellenpunkte(k).isEmpty)
        XCTAssertEqual(Kennlinienbild.copAchse(punkte: k.punkte, annahme: k.annahme), 1...6)
        XCTAssertNil(k.bilanz)
    }

    /// Ein Ausgleich mit umgekehrter Spanne (so etwas kam am 14.11.2026 aus dem Dienst) darf
    /// kein Raster erzwingen.
    func testKennfeldOhneBrauchbareSpanne() {
        XCTAssertNil(
            Kennlinienbild.kennfeld(antwort(fit: fit(aussenVonC: 8, aussenBisC: 2))))
    }
}
