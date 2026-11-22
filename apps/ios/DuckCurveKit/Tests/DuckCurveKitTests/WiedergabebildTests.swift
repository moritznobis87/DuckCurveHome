import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/waerme/Wiedergabe.tsx`, `Tagesuhr.tsx`,
/// `Tagesband.tsx` und `tagesuhr.ts`.
///
/// **Warum hier so viel geprüft wird.** Die Geometrie der Uhr ist die Sorte Rechnung, die man
/// einem Bild nicht ansieht: „ein Ring, der um eine Viertelstunde verdreht ist, sieht genauso
/// plausibel aus wie ein richtiger“ (`tagesuhr.ts:3-6`).
final class WiedergabebildTests: XCTestCase {

    private let tagesanfang = Zeit.ausIso("2026-11-07T00:00:00+01:00")!

    // MARK: - Antworten bauen

    private func bild(
        at: Date, pv: Double? = nil, netz: Double? = nil, wpLaeuft: Bool = false,
        wpKw: Double? = nil, ofenDa: Bool = false, ofenLaeuft: Bool? = nil
    ) -> AnlageOut {
        AnlageOut(
            at: Zeit.iso(at),
            strom: AnlageStromOut(
                pvKw: pv, gridKw: netz, sharePv: 0, shareGrid: 1, shareBattery: 0),
            waermepumpe: AnlageWaermepumpeOut(running: wpLaeuft, powerKw: wpKw),
            ofen: AnlageOfenOut(present: ofenDa, running: ofenLaeuft),
            speicher: AnlageSpeicherOut(
                capacityKwh: 20, volumeLiters: 800, netWord: "hält"),
            heizkreis: AnlageHeizkreisOut(roomsTotal: 8, roomsOpen: 3, running: true),
            warmwasser: AnlageWarmwasserOut(present: true))
    }

    /// Eine Antwort mit `anzahl` Bildern im Schritt `schrittMin`, ab Tagesanfang.
    private func antwort(
        anzahl: Int, schrittMin: Int = 5, stunden: Int = 24, erwartet: Int? = nil,
        auslassen: Set<Int> = [],
        pv: (Int) -> Double? = { _ in nil },
        netz: (Int) -> Double? = { _ in nil },
        preis: (Int) -> Double? = { _ in nil },
        geplant: (Int) -> Bool? = { _ in nil },
        wp: (Int) -> Bool = { _ in false },
        ofenDa: Bool = false,
        ofen: (Int) -> Bool? = { _ in nil },
        hinweise: [String] = []
    ) -> AnlageReplayOut {
        let stellen = (0..<anzahl).filter { !auslassen.contains($0) }
        let frames = stellen.map { i in
            bild(
                at: tagesanfang.addingTimeInterval(Double(i * schrittMin * 60)), pv: pv(i),
                netz: netz(i), wpLaeuft: wp(i), ofenDa: ofenDa, ofenLaeuft: ofen(i))
        }
        return AnlageReplayOut(
            day: "2026-11-07", stepMin: schrittMin, von: Zeit.iso(tagesanfang),
            bis: Zeit.iso(tagesanfang.addingTimeInterval(Double(stunden) * 3600)),
            erwartet: erwartet ?? anzahl, frames: frames,
            preisCtKwh: stellen.map { preis($0) }, geplantWp: stellen.map { geplant($0) },
            geplantOfen: [], hinweiseDe: hinweise)
    }

    // MARK: - Läufe

    func testGleicheWerteWerdenEinLaufUndEinLaufReichtEinenSchrittWeiter() {
        let zeiten = (0..<4).map { tagesanfang.addingTimeInterval(Double($0) * 300) }
        let laeufe = Wiedergabebild.laeufe([true, true, true, true], zeiten: zeiten, schritt: 300)
        XCTAssertEqual(laeufe.count, 1)
        XCTAssertEqual(laeufe[0].von, zeiten[0])
        // Das letzte Bild gilt bis zum Ende seines Schrittes, nicht bis zu seinem Zeitstempel.
        XCTAssertEqual(laeufe[0].bis, zeiten[3].addingTimeInterval(300))
    }

    func testEinLaufBrichtAnEinerLueckeAbUndWirdNichtUeberbrueckt() {
        // Vier Bilder, aber das dritte fehlt in der Zeit: 0, 5, 20, 25 Minuten.
        let zeiten = [0.0, 300, 1200, 1500].map(tagesanfang.addingTimeInterval)
        let laeufe = Wiedergabebild.laeufe([true, true, true, true], zeiten: zeiten, schritt: 300)
        XCTAssertEqual(laeufe.count, 2, "über einen Ausfall hinweg darf kein Lauf laufen")
        XCTAssertEqual(laeufe[0].bis, zeiten[1].addingTimeInterval(300))
        XCTAssertEqual(laeufe[1].von, zeiten[2])
    }

    func testEinWechselDesWertesBeendetDenLauf() {
        let zeiten = (0..<4).map { tagesanfang.addingTimeInterval(Double($0) * 300) }
        let laeufe = Wiedergabebild.laeufe([true, true, false, true], zeiten: zeiten, schritt: 300)
        XCTAssertEqual(laeufe.map(\.wert), [true, false, true])
    }

    func testNilErgibtKeinenLaufUndBeendetDenOffenen() {
        let zeiten = (0..<4).map { tagesanfang.addingTimeInterval(Double($0) * 300) }
        let laeufe = Wiedergabebild.laeufe(
            [true, nil, true, true], zeiten: zeiten, schritt: 300)
        XCTAssertEqual(laeufe.count, 2)
        XCTAssertEqual(laeufe[0].bis, zeiten[0].addingTimeInterval(300))
        XCTAssertEqual(laeufe[1].von, zeiten[2])
    }

    func testMehrWerteAlsZeitenBrechenAbStattZuRaten() {
        let zeiten = [tagesanfang]
        let laeufe = Wiedergabebild.laeufe([true, true, true], zeiten: zeiten, schritt: 300)
        XCTAssertEqual(laeufe.count, 1)
    }

    // MARK: - Stufen

    func testFuenfStufenLiegenAufDenGrenzenDerVorlage() {
        // 0…10 in fünf Stufen: 0→0, 2→1, 4→2, 6→3, 8→4, 10→4 (oben beschnitten).
        let n = Wiedergabebild.stufen.count
        XCTAssertEqual(n, 5)
        XCTAssertEqual(Wiedergabebild.stufe(wert: 0, min: 0, max: 10, anzahl: n), 0)
        XCTAssertEqual(Wiedergabebild.stufe(wert: 1.9, min: 0, max: 10, anzahl: n), 0)
        XCTAssertEqual(Wiedergabebild.stufe(wert: 2, min: 0, max: 10, anzahl: n), 1)
        XCTAssertEqual(Wiedergabebild.stufe(wert: 8, min: 0, max: 10, anzahl: n), 4)
        XCTAssertEqual(Wiedergabebild.stufe(wert: 10, min: 0, max: 10, anzahl: n), 4)
    }

    func testBeiSpanneNullBekommtAllesDieMittlereStufe() {
        XCTAssertEqual(Wiedergabebild.stufe(wert: 27, min: 27, max: 27, anzahl: 5), 2)
        XCTAssertEqual(Wiedergabebild.stufe(wert: 27, min: 30, max: 10, anzahl: 5), 2)
    }

    func testWerteAusserhalbDerSpanneWerdenBeschnittenUndNichtNegativ() {
        XCTAssertEqual(Wiedergabebild.stufe(wert: -5, min: 0, max: 10, anzahl: 5), 0)
        XCTAssertEqual(Wiedergabebild.stufe(wert: 99, min: 0, max: 10, anzahl: 5), 4)
        XCTAssertEqual(Wiedergabebild.stufe(wert: .nan, min: 0, max: 10, anzahl: 5), 0)
    }

    // MARK: - Das Bild bauen

    func testEineLeereAntwortErgibtEinBildOhneRingeStattEinesAbsturzes() {
        let b = Wiedergabebild.baue(antwort(anzahl: 0, erwartet: 288))
        XCTAssertEqual(b.anzahl, 0)
        XCTAssertFalse(b.vollstaendig)
        XCTAssertTrue(b.spur.isEmpty)
        XCTAssertNil(b.preisspanne)
        XCTAssertNil(b.bandspanne)
        XCTAssertEqual(b.sonneMax, 0)
    }

    func testOhneLesbareTagesgrenzeGibtEsKeineUhrAberAuchKeinenAbsturz() {
        var a = antwort(anzahl: 4)
        a.von = "kein Zeitstempel"
        let b = Wiedergabebild.baue(a)
        XCTAssertEqual(b.anzahl, 0)
        XCTAssertEqual(b.schrittMin, 5)
        XCTAssertNil(b.anteil(stelle: 0))
    }

    func testFehlendeFelderDerAntwortGebenKeineAbsichtUndKeinenPreis() {
        var a = antwort(anzahl: 6, pv: { _ in 1.0 })
        a.preisCtKwh = []
        a.geplantWp = []
        let b = Wiedergabebild.baue(a)
        XCTAssertFalse(b.hatPreis)
        XCTAssertFalse(b.hatAbsicht)
        XCTAssertNil(b.preisspanne)
        XCTAssertTrue(b.preisringe.isEmpty)
        XCTAssertTrue(b.geplant.isEmpty)
        XCTAssertEqual(b.sonnenringe.count, 1, "die Sonne steht trotzdem im Ring")
    }

    func testEinBildOhneLesbarenZeitstempelFaelltAusAllenReihenGleichzeitig() {
        var a = antwort(anzahl: 4, preis: { Double(20 + $0) })
        a.frames[2].at = "Dienstagmittag"
        let b = Wiedergabebild.baue(a)
        XCTAssertEqual(b.anzahl, 3)
        XCTAssertEqual(b.preis.count, 3)
        // Der Preis des dritten Bildes fällt mit ihm weg, nicht der des vierten.
        XCTAssertEqual(b.preis.map(\.wert), [20, 21, 23])
    }

    func testDieKopfzahlNenntBeideZahlenUndDenSchritt() {
        let b = Wiedergabebild.baue(antwort(anzahl: 280, erwartet: 288))
        XCTAssertEqual(b.kopfzahl, "280 von 288 Bildern · 5-Minuten-Schritt")
        XCTAssertFalse(b.vollstaendig)
    }

    func testEinVollstaendigerTagSagtDasAuch() {
        let b = Wiedergabebild.baue(antwort(anzahl: 288, erwartet: 288))
        XCTAssertTrue(b.vollstaendig)
    }

    func testDieSonneUnterFuenfzigWattIstKeinRingstueck() {
        // Nachts meldet der Wechselrichter 0,004 kW - das ist kein Sonnenschein.
        let b = Wiedergabebild.baue(
            antwort(anzahl: 6, pv: { $0 < 3 ? 0.004 : 2.0 }))
        XCTAssertEqual(b.sonnenringe.count, 1)
        XCTAssertEqual(b.sonneMax, 2.0)
        // Die Bandreihe behält den Messwert: dort ist 0,004 kW eine gemessene Null und keine Lücke.
        XCTAssertEqual(b.sonne.count, 6)
        XCTAssertEqual(b.sonne[0].wert, 0.004)
    }

    func testEinTagOhneSonneSagtEsInDerLegende() {
        let b = Wiedergabebild.baue(antwort(anzahl: 6))
        XCTAssertTrue(b.legende.contains { $0.wort == "Sonne · keine an diesem Tag" })
        XCTAssertTrue(b.legende.contains { $0.wort == "Preis · nicht erfasst" })
    }

    func testDieLegendeNenntDiePreisspanneGanzzahlig() {
        let b = Wiedergabebild.baue(
            antwort(anzahl: 4, preis: { [12.4, 31.6, 20.0, 25.0][$0] }))
        XCTAssertEqual(b.preisspanne, 12.4...31.6)
        XCTAssertTrue(
            b.legende.contains { $0.wort == "Preis · 12 bis 32 ct, heller ist teurer" },
            b.legende.map(\.wort).joined(separator: " | "))
    }

    func testOhneOfenFehltDerInnersteRingUndSeineLegendenzeile() {
        let b = Wiedergabebild.baue(antwort(anzahl: 4, ofenDa: false, ofen: { _ in true }))
        XCTAssertFalse(b.hatOfen)
        XCTAssertTrue(b.ofen.isEmpty)
        XCTAssertFalse(b.legende.contains { $0.wort == "Pelletofen gebrannt" })
        XCTAssertFalse(b.bandflaechen.contains { $0.art == .ofen })
    }

    func testMitOfenKommtDieZeileUndDieFlaecheDazu() {
        let b = Wiedergabebild.baue(antwort(anzahl: 4, ofenDa: true, ofen: { $0 < 2 }))
        XCTAssertTrue(b.hatOfen)
        XCTAssertEqual(b.ofenbalken.count, 1)
        XCTAssertTrue(b.legende.contains { $0.wort == "Pelletofen gebrannt" })
        XCTAssertEqual(b.bandflaechen.map(\.art), [.kw, .preis, .geplant, .gelaufen, .ofen])
    }

    func testOhneAufbewahrtenFahrplanTraegtDieBandzeileEinFragezeichen() {
        let b = Wiedergabebild.baue(antwort(anzahl: 4))
        XCTAssertFalse(b.hatAbsicht)
        XCTAssertEqual(b.bandflaechen.first { $0.art == .geplant }?.name, "geplant ?")
        XCTAssertTrue(
            b.legende.contains { $0.wort == "Wärmepumpe geplant · kein Fahrplan aufbewahrt" })
    }

    func testMitFahrplanHeisstDieZeileNurGeplant() {
        let b = Wiedergabebild.baue(antwort(anzahl: 4, geplant: { $0 < 2 }))
        XCTAssertTrue(b.hatAbsicht)
        XCTAssertEqual(b.bandflaechen.first { $0.art == .geplant }?.name, "geplant")
        XCTAssertEqual(b.geplanteBalken.count, 1, "nur die wahren Läufe werden Balken")
        XCTAssertEqual(b.geplant.count, 2, "der Ring braucht beide: Absicht und blasse Spur")
    }

    func testDieFlaechenhoehenSindDieDerVorlage() {
        let b = Wiedergabebild.baue(antwort(anzahl: 4, ofenDa: true, ofen: { _ in false }))
        XCTAssertEqual(b.bandflaechen.map(\.hoehe), [58, 30, 8, 13, 13])
        XCTAssertEqual(b.bandflaechen.map(\.name), ["kW", "ct/kWh", "geplant ?", "gelaufen", "Ofen"])
    }

    // MARK: - Greifen

    func testDasNaechsteBildWirdNachgesehenUndNichtGerechnet() {
        // Der Vormittag fehlt: Bilder nur ab 12:00. Eine Rechnung aus Anteil mal Anzahl läge
        // Stunden daneben.
        let b = Wiedergabebild.baue(antwort(anzahl: 288, auslassen: Set(0..<144)))
        XCTAssertEqual(b.anzahl, 144)
        let mittag = tagesanfang.addingTimeInterval(12 * 3600)
        XCTAssertEqual(b.naechsteStelle(zu: mittag), 0)
        XCTAssertEqual(b.naechsteStelle(zu: tagesanfang), 0, "vor dem ersten Bild: das erste")
        XCTAssertEqual(
            b.naechsteStelle(zu: mittag.addingTimeInterval(3600)), 12, "eine Stunde = zwölf Bilder")
    }

    func testOhneBilderGibtEsKeineStelle() {
        let b = Wiedergabebild.baue(antwort(anzahl: 0))
        XCTAssertNil(b.naechsteStelle(zu: tagesanfang))
        XCTAssertNil(b.anteil(stelle: 0))
    }

    // MARK: - Die Sätze

    func testDieMitteDerUhrNenntSonnePreisUndPumpe() {
        let a = antwort(
            anzahl: 4, pv: { _ in 3.42 }, preis: { _ in 26.8 }, geplant: { _ in true },
            wp: { _ in true })
        let b = Wiedergabebild.baue(a)
        let m = b.mitte(a, stelle: 1)
        XCTAssertEqual(m?.sonne, "Sonne 3,4 kW · 27 ct")
        XCTAssertEqual(m?.pumpe, "Wärmepumpe läuft · geplant")
        XCTAssertEqual(m?.zeit, "00:05")
    }

    func testOhneMesswertStehtEinFragezeichenUndKeineNull() {
        let a = antwort(anzahl: 2)
        let b = Wiedergabebild.baue(a)
        XCTAssertEqual(b.mitte(a, stelle: 0)?.sonne, "Sonne ?")
        // Ohne aufbewahrten Fahrplan steht hinter der Pumpe nichts - kein „nicht geplant“.
        XCTAssertEqual(b.mitte(a, stelle: 0)?.pumpe, "Wärmepumpe steht")
    }

    /// Die Fahne schreibt denselben fehlenden Wert wie die Uhrmitte: ein Fragezeichen
    /// (`Tagesband.tsx:200, 201, 205`). Ein Strich hier und ein Fragezeichen drei Zentimeter
    /// darüber waren zwei Schreibweisen für dieselbe Lücke auf einem Schirm.
    func testDieFahneSchreibtDieLueckeWieDieUhrmitte() {
        let a = antwort(anzahl: 2, ofenDa: true)
        let zeilen = Wiedergabebild.baue(a).fahne(a, stelle: 0)?.zeilen.map(\.satz) ?? []
        XCTAssertEqual(zeilen.first, "Sonne ?")
        XCTAssertEqual(zeilen[1], "Netz ?")
        XCTAssertEqual(zeilen.last, "Ofen ?")
    }

    func testEineStelleJenseitsDerBilderGibtKeineMitteUndKeineFahne() {
        let a = antwort(anzahl: 2)
        let b = Wiedergabebild.baue(a)
        XCTAssertNil(b.mitte(a, stelle: 7))
        XCTAssertNil(b.fahne(a, stelle: -1))
    }

    func testDieFahneTraegtDieAbsichtEingeruecktUndInDreiFaellen() {
        let a = antwort(
            anzahl: 3, pv: { _ in 1.25 }, netz: { _ in -0.8 }, preis: { _ in 31.44 },
            geplant: { $0 == 0 ? true : ($0 == 1 ? false : nil) }, wp: { _ in true })
        let b = Wiedergabebild.baue(a)
        XCTAssertEqual(
            b.fahne(a, stelle: 0)?.zeilen.first { $0.eingerueckt }?.satz,
            "der Fahrplan wollte anfordern")
        XCTAssertEqual(
            b.fahne(a, stelle: 1)?.zeilen.first { $0.eingerueckt }?.satz,
            "der Fahrplan wollte nicht anfordern")
        XCTAssertEqual(
            b.fahne(a, stelle: 2)?.zeilen.first { $0.eingerueckt }?.satz,
            "kein aufbewahrter Fahrplan")
        let zeilen = b.fahne(a, stelle: 0)?.zeilen.map(\.satz) ?? []
        XCTAssertEqual(zeilen.first, "Sonne 1,3 kW")
        XCTAssertEqual(zeilen[1], "Netz \(Formate.minus)0,8 kW · 31,4 ct/kWh")
    }

    func testDieFahneNenntDieLeistungDerPumpeNurWennSieGemessenIst() {
        var a = antwort(anzahl: 2, wp: { _ in true })
        a.frames[0].waermepumpe.powerKw = 1.84
        let b = Wiedergabebild.baue(a)
        XCTAssertEqual(b.fahne(a, stelle: 0)?.zeilen[2].satz, "Wärmepumpe läuft, 1,8 kW")
        XCTAssertEqual(b.fahne(a, stelle: 1)?.zeilen[2].satz, "Wärmepumpe läuft")
    }

    func testDerOfenStehtInDerFahneNurWennEsIhnGibt() {
        let mit = antwort(anzahl: 2, ofenDa: true, ofen: { _ in true })
        let ohne = antwort(anzahl: 2)
        XCTAssertEqual(Wiedergabebild.baue(mit).fahne(mit, stelle: 0)?.zeilen.last?.satz, "Ofen brennt")
        XCTAssertNil(
            Wiedergabebild.baue(ohne).fahne(ohne, stelle: 0)?.zeilen.first { $0.marke == .ofen })
    }

    // MARK: - Die Worte

    func testDieMethodeSetztSchrittTempoUndDauerEin() {
        let saetze = Wiedergabeworte.methode(
            uhrzeit: "14:35", schrittMin: 5, tempo: 12, anzahl: 288)
        XCTAssertEqual(saetze.count, 3)
        XCTAssertTrue(saetze[0].contains("von 14:35 hin"), saetze[0])
        XCTAssertTrue(
            saetze[2].contains("Bei 5 Minuten Schritt und 12× läuft der Tag in 24 Sekunden durch."),
            saetze[2])
    }

    func testOhneBilderNenntDieMethodeKeineDauer() {
        let saetze = Wiedergabeworte.methode(uhrzeit: "-", schrittMin: 5, tempo: 12, anzahl: 0)
        XCTAssertFalse(saetze[2].contains("Sekunden"))
        XCTAssertNil(Wiedergabeworte.sekundenJeDurchlauf(anzahl: 288, tempo: 0))
    }

    func testDerTaktFolgtDemTempo() {
        XCTAssertEqual(Wiedergabeworte.takt(tempo: 2), .milliseconds(500))
        XCTAssertEqual(Wiedergabeworte.takt(tempo: 24), .milliseconds(42))
        XCTAssertEqual(Wiedergabeworte.takt(tempo: 0), .milliseconds(1000))
    }

    func testEinTagOhneBilderSagtDenHinweisDesDienstesUndSonstEinenEigenenSatz() {
        XCTAssertEqual(
            Wiedergabeworte.ohneBilder(["Für diesen Tag fehlt die Minutenreihe."]),
            "Für diesen Tag fehlt die Minutenreihe.")
        XCTAssertFalse(Wiedergabeworte.ohneBilder([]).isEmpty)
    }

    func testTempiUndSchritteSindDieDerVorlage() {
        XCTAssertEqual(Wiedergabeworte.tempi, [2, 6, 12, 24])
        XCTAssertEqual(Wiedergabeworte.schritte, [1, 5, 15])
        XCTAssertEqual(Wiedergabeworte.tempoVorgabe, 12)
        XCTAssertEqual(Wiedergabeworte.schrittVorgabe, 5)
    }
}
