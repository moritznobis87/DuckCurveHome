import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/waerme/wirkung.ts`, `Wirkung.tsx`,
/// `Antwortfaecher.tsx` und `Ereignisraster.tsx`.
final class WirkungsbildTests: XCTestCase {

    // MARK: - Antworten bauen

    private func faecher(
        minuten: [Int], mittel: [Double?] = [], q25: [Double?] = [], q75: [Double?] = [],
        n: [Int] = [], laeuft: [Double?] = [], angelaufen: [Double?] = []
    ) -> Faecher {
        Faecher(
            minuten: minuten, mittelKw: mittel, medianKw: [], q25Kw: q25, q75Kw: q75,
            anteilLaeuft: laeuft, n: n, anteilAngelaufen: angelaufen)
    }

    private func vergleich(
        quote: Double? = nil, lo: Double? = nil, hi: Double? = nil, gleicheStunde: Int? = nil,
        angelaufenBis: [Double] = []
    ) -> Vergleich {
        Vergleich(
            n: 100, gefolgt: 19, quote: quote, ereignisseGedeckt: 100,
            nGleicheStunde: gleicheStunde, quoteLo: lo, quoteHi: hi,
            angelaufenBis: angelaufenBis)
    }

    private func ereignis(
        at: String = "2026-11-07T14:35:00+01:00", liefSchon: Bool = false,
        auswertbar: Bool = true, gefolgt: Bool? = true, verzoegerung: Int? = 7,
        kontaktMin: Int = 20, kw: [Double?] = []
    ) -> Ereignis {
        Ereignis(
            at: at, liefSchon: liefSchon, auswertbar: auswertbar, gefolgt: gefolgt,
            verzoegerungMin: verzoegerung, kontaktMin: kontaktMin, kw: kw)
    }

    private func antwort(
        von: String? = nil, bis: String? = nil, schwelleKw: Double = 0.4, vorMin: Int? = 30,
        nachMin: Int? = 120, folgeMin: Int? = 30, ereignisse: [Ereignis] = [],
        faecher: Faecher? = nil, n: Int? = nil, nLiefSchon: Int? = nil, nAuswertbar: Int? = nil,
        gefolgt: Int? = nil, quote: Double? = nil, quoteLo: Double? = nil,
        quoteHi: Double? = nil, vergleich: Vergleich? = nil, verzoegerungMedian: Double? = nil,
        nachlaufMedian: Double? = nil, nachlaufN: Int? = nil, urteil: String? = nil,
        urteilDe: String? = nil
    ) -> KontaktwirkungOut {
        KontaktwirkungOut(
            von: von, bis: bis, schwelleKw: schwelleKw, vorMin: vorMin, nachMin: nachMin,
            folgeMin: folgeMin, ereignisse: ereignisse,
            faecher: faecher ?? self.faecher(minuten: []), n: n, nLiefSchon: nLiefSchon,
            nAuswertbar: nAuswertbar, gefolgt: gefolgt, quote: quote, quoteLo: quoteLo,
            quoteHi: quoteHi, vergleich: vergleich ?? self.vergleich(),
            verzoegerungMedianMin: verzoegerungMedian, nachlaufMedianMin: nachlaufMedian,
            nachlaufN: nachlaufN, urteil: urteil, urteilDe: urteilDe, days: 30)
    }

    // MARK: - Leere Antwort

    func testEineLeereAntwortErfindetKeinenFaecherUndKeineZeile() {
        let b = Wirkungsbild.baue(antwort())
        XCTAssertTrue(b.faecher.isEmpty, "151 Punkte ohne Messung sind kein Bild.")
        XCTAssertTrue(b.mittel.isEmpty)
        XCTAssertTrue(b.einzelkurven.isEmpty)
        XCTAssertTrue(b.gruppen.isEmpty)
        XCTAssertTrue(b.anteilOhne.isEmpty)
        XCTAssertNil(b.rasterHinweis)
    }

    func testBeideQuotenzeilenStehenAuchDaWennEsKeineQuoteGibt() {
        let b = Wirkungsbild.baue(antwort())
        XCTAssertEqual(b.quotenzeilen.map(\.name), ["angefordert", "sonst"])
        XCTAssertEqual(b.quotenzeilen.map(\.rolle), [.angefordert, .sonst])
        XCTAssertTrue(b.quotenzeilen.allSatisfy { $0.quote == nil })
        XCTAssertEqual(
            b.quotenzeilen.map(\.leer),
            ["keine auswertbare Anforderung", "kein Vergleich zur selben Tageszeit"],
            "Eine Zeile, die verschwindet, sieht aus wie eine Quote von null.")
        XCTAssertEqual(b.quotenzeilen.map(\.zahl), ["-", "-"])
        XCTAssertNil(b.quotenzeilen[0].bereich)
    }

    func testOhneAuswertbareEreignisseSagtDieLegendeWarumKeinBandDaIst() {
        let b = Wirkungsbild.baue(antwort(nAuswertbar: 7))
        XCTAssertEqual(
            b.bandHinweis, "das Band der mittleren Hälfte erscheint ab 8 Ereignissen")
        XCTAssertNil(Wirkungsbild.baue(antwort(nAuswertbar: 8)).bandHinweis)
    }

    // MARK: - Der Ausschnitt und seine Grenzwerte

    func testDerAusschnittKommtAusDerAntwortUndSonstAusDenVorgabenDesDienstes() {
        let b = Wirkungsbild.baue(antwort(vorMin: 15, nachMin: 60, folgeMin: 45))
        XCTAssertEqual(b.vorMin, 15)
        XCTAssertEqual(b.nachMin, 60)
        XCTAssertEqual(b.folgeMin, 45)
        XCTAssertEqual(b.breite, 76, "vor + nach + 1 Spalte für die Minute null.")

        let ohne = Wirkungsbild.baue(antwort(vorMin: nil, nachMin: nil, folgeMin: nil))
        XCTAssertEqual(ohne.vorMin, 30)
        XCTAssertEqual(ohne.nachMin, 120)
        XCTAssertEqual(ohne.folgeMin, 30)
        XCTAssertEqual(ohne.breite, 151)
    }

    func testDieFolgefristDerAntwortStehtInDerErklaerungUndNichtDieDreissig() {
        let b = Wirkungsbild.baue(antwort(folgeMin: 45, quote: 1, vergleich: vergleich(quote: 0.19)))
        XCTAssertTrue(b.quotenerklaerung.hasPrefix("Anlauf binnen 45 Minuten bei stehender Maschine."))
        XCTAssertTrue(b.quotenerklaerung.contains("wenn sich die Balken nicht überlappen"))
        XCTAssertEqual(
            b.quotenbeschreibung,
            "Anlauf binnen 45 Minuten: mit Anforderung 100 Prozent, ohne 19 Prozent.")
    }

    func testDasBandErscheintErstAbAchtEreignissenInDerMinute() {
        let f = faecher(
            minuten: [0, 1, 2], mittel: [1, 1, 1], q25: [0.5, 0.6, 0.7], q75: [1.5, 1.6, 1.7],
            n: [7, 8, 9])
        let b = Wirkungsbild.baue(antwort(faecher: f))
        XCTAssertEqual(b.faecher.map(\.hatBand), [false, true, true])
        XCTAssertNil(b.faecher[0].q25Kw, "Sieben Ereignisse tragen keine mittlere Hälfte.")
        XCTAssertEqual(b.faecher[1].q25Kw, 0.6)
        XCTAssertEqual(b.faecher[1].q75Kw, 1.6)
        XCTAssertEqual(Wirkungsbild.mindestensFuerBand, 8, "Dieselbe Acht wie MIN_EREIGNISSE.")
    }

    func testEineKuerzereReiheWirdZurLueckeUndNichtZurNull() {
        let f = faecher(minuten: [0, 1, 2], mittel: [1.0], n: [9, 9, 9])
        let b = Wirkungsbild.baue(antwort(faecher: f))
        XCTAssertEqual(b.faecher.count, 3)
        XCTAssertEqual(b.faecher[0].mittelKw, 1.0)
        XCTAssertNil(b.faecher[1].mittelKw)
        XCTAssertNil(b.faecher[2].mittelKw)
    }

    // MARK: - Lücken bleiben Lücken

    func testEineKurveMitLueckeZerfaelltInStueckeUndWirdNichtDurchgezogen() {
        let f = faecher(minuten: [0, 1, 2, 3, 4], mittel: [1, 2, nil, 3, 4], n: [9, 9, 9, 9, 9])
        let b = Wirkungsbild.baue(antwort(faecher: f))
        XCTAssertEqual(b.mittel.count, 2, "Über die Lücke darf keine Linie laufen.")
        XCTAssertEqual(b.mittel.map(\.id), ["mittel.0", "mittel.1"])
        XCTAssertEqual(b.mittel[0].punkte.map(\.minute), [0, 1])
        XCTAssertEqual(b.mittel[1].punkte.map(\.minute), [3, 4])
        XCTAssertEqual(b.mittel[1].punkte.map(\.kw), [3, 4])
    }

    func testJedesStueckJederKurveHatEinenEigenenNamenFuerDieReiheImDiagramm() {
        let f = faecher(minuten: [0, 1, 2], n: [1, 1, 1])
        let e = ereignis(kw: [1, nil, 2])
        let b = Wirkungsbild.baue(antwort(ereignisse: [e, e], faecher: f))
        let namen = b.einzelkurven.flatMap { $0.stuecke.map(\.id) }
        XCTAssertEqual(namen, ["e0.0", "e0.1", "e1.0", "e1.1"])
        XCTAssertEqual(Set(namen).count, namen.count, "Zwei Reihen mit einem Namen fallen zusammen.")
    }

    func testDieMinutenEinerEinzelkurveKommenAusDemRasterDesFaechers() {
        let f = faecher(minuten: [-2, -1, 0, 1], n: [1, 1, 1, 1])
        let b = Wirkungsbild.baue(antwort(ereignisse: [ereignis(kw: [0.1, 0.2, 0.3, 0.4])], faecher: f))
        XCTAssertEqual(b.einzelkurven[0].stuecke[0].punkte.map(\.minute), [-2, -1, 0, 1])
    }

    // MARK: - Die Deckung der Einzelkurven

    func testWenigeKurvenBleibenLesbarUndVieleWerdenZurWolke() {
        XCTAssertEqual(Wirkungsbild.deckung(0), 0.55, accuracy: 1e-9)
        XCTAssertEqual(Wirkungsbild.deckung(1), 0.55, accuracy: 1e-9)
        XCTAssertEqual(Wirkungsbild.deckung(4), 0.55, accuracy: 1e-9, "1,1/2 trifft die Obergrenze.")
        XCTAssertEqual(Wirkungsbild.deckung(9), 1.1 / 3, accuracy: 1e-9)
        XCTAssertEqual(Wirkungsbild.deckung(121), 0.10, accuracy: 1e-9)
        XCTAssertEqual(Wirkungsbild.deckung(400), 0.10, accuracy: 1e-9, "Untergrenze, sonst unsichtbar.")
    }

    func testMehrAlsAchtzigAntwortenZeigtDerFaecherNichtUndEsSindDieJuengsten() {
        let f = faecher(minuten: [0], n: [90])
        let viele = (0..<85).map { i in ereignis(kw: [Double(i)]) }
        let b = Wirkungsbild.baue(antwort(ereignisse: viele, faecher: f))
        XCTAssertEqual(b.einzelkurven.count, Wirkungsbild.maxKurven)
        XCTAssertEqual(b.einzelkurven.first?.stuecke.first?.punkte.first?.kw, 5)
        XCTAssertEqual(b.einzelkurven.last?.stuecke.first?.punkte.first?.kw, 84)
        XCTAssertEqual(b.kurvendeckung, Wirkungsbild.deckung(80), accuracy: 1e-9)
    }

    func testNichtAuswertbareEreignisseKommenNichtInDenFaecher() {
        let f = faecher(minuten: [0], n: [2])
        let b = Wirkungsbild.baue(
            antwort(
                ereignisse: [ereignis(kw: [1]), ereignis(auswertbar: false, kw: [2])],
                faecher: f))
        XCTAssertEqual(b.einzelkurven.count, 1)
        XCTAssertEqual(b.einzelkurven[0].stuecke[0].punkte[0].kw, 1)
    }

    // MARK: - Betrieb: drei Zustände, nicht zwei

    func testNichtGemessenIstWederLaufenNochStehen() {
        let b = Wirkungsbild.betrieb(kw: [nil, 0.1, 0.1, 2, 2, nil, 2], schwelleKw: 1)
        XCTAssertEqual(b.steht, [1..<3])
        XCTAssertEqual(b.laeuft, [3..<5, 6..<7])
    }

    func testDieSchwelleGiltEinschliesslich() {
        let b = Wirkungsbild.betrieb(kw: [0.99, 1.0], schwelleKw: 1)
        XCTAssertEqual(b.steht, [0..<1])
        XCTAssertEqual(b.laeuft, [1..<2])
    }

    func testEineUnzahlIstKeineMessungUndDamitAuchKeinStillstand() {
        let b = Wirkungsbild.betrieb(kw: [Double.nan, 2], schwelleKw: 1)
        XCTAssertTrue(b.steht.isEmpty)
        XCTAssertEqual(b.laeuft, [1..<2])
    }

    func testOhneJedenMesswertBleibtDerBalkenLeer() {
        let b = Wirkungsbild.betrieb(kw: [], schwelleKw: 1)
        XCTAssertTrue(b.laeuft.isEmpty)
        XCTAssertTrue(b.steht.isEmpty)
    }

    // MARK: - Gruppen

    func testLiefSchonGehtVorFehlenderMessungUndDieseVorDerAnlauffrage() {
        XCTAssertEqual(
            Wirkungsbild.gruppe(ereignis(liefSchon: true, auswertbar: false, gefolgt: true)),
            .liefSchon)
        XCTAssertEqual(Wirkungsbild.gruppe(ereignis(auswertbar: false, gefolgt: true)), .unklar)
        XCTAssertEqual(Wirkungsbild.gruppe(ereignis(gefolgt: true)), .gefolgt)
        XCTAssertEqual(Wirkungsbild.gruppe(ereignis(gefolgt: false)), .nichtGefolgt)
        XCTAssertEqual(
            Wirkungsbild.gruppe(ereignis(gefolgt: nil)), .nichtGefolgt,
            "Auswertbar und ohne Angabe heißt nicht gefolgt.")
    }

    func testDieGruppenStehenInFesterReihenfolgeUndLeereFallenWeg() {
        let b = Wirkungsbild.baue(
            antwort(ereignisse: [
                ereignis(at: "2026-11-01T10:00:00+01:00", auswertbar: false, gefolgt: nil, verzoegerung: nil),
                ereignis(at: "2026-11-02T10:00:00+01:00", gefolgt: true, verzoegerung: 3),
                ereignis(at: "2026-11-03T10:00:00+01:00", liefSchon: true, verzoegerung: nil),
            ]))
        XCTAssertEqual(b.gruppen.map(\.gruppe), [.gefolgt, .liefSchon, .unklar])
        XCTAssertEqual(b.gruppen.map(\.zeilen.count), [1, 1, 1])
        XCTAssertEqual(
            b.gruppen.map(\.gruppe.titel), ["angelaufen", "lief schon", "Messung fehlt"])
    }

    func testDieTitelDerVierGruppenSindDieDerVorlage() {
        XCTAssertEqual(
            Wirkungsbild.Ereignisgruppe.allCases.map(\.titel),
            ["angelaufen", "nicht angelaufen", "lief schon", "Messung fehlt"])
    }

    // MARK: - Sortierung

    func testSortiertWirdNachVerzoegerungUndBeiGleichstandDerJuengsteZuerst() {
        let b = Wirkungsbild.baue(
            antwort(ereignisse: [
                ereignis(at: "2026-11-07T10:00:00+01:00", gefolgt: false, verzoegerung: 20),
                ereignis(at: "2026-11-07T11:00:00+01:00", gefolgt: false, verzoegerung: nil),
                ereignis(at: "2026-11-07T12:00:00+01:00", gefolgt: false, verzoegerung: 20),
                ereignis(at: "2026-11-07T09:00:00+01:00", gefolgt: false, verzoegerung: 5),
            ]))
        let zeilen = b.gruppen.first { $0.gruppe == .nichtGefolgt }?.zeilen ?? []
        XCTAssertEqual(
            zeilen.map(\.at),
            [
                "2026-11-07T09:00:00+01:00",
                "2026-11-07T12:00:00+01:00",
                "2026-11-07T10:00:00+01:00",
                "2026-11-07T11:00:00+01:00",
            ],
            "Ohne Verzögerung steht ein Ereignis am Ende, nicht am Anfang.")
    }

    func testMehrAlsAchtzigZeilenZeigtDasRasterNichtUndSagtDasAuch() {
        let viele = (0..<85).map { i in
            ereignis(at: "2026-11-07T10:00:00+01:00", gefolgt: true, verzoegerung: i)
        }
        let b = Wirkungsbild.baue(antwort(ereignisse: viele, n: 85))
        XCTAssertEqual(b.gruppen.map(\.zeilen.count).reduce(0, +), Wirkungsbild.maxZeilen)
        XCTAssertEqual(b.rasterHinweis, "gezeigt sind die jüngsten 80 von 85 Anforderungen")
        let gezeigt = b.gruppen.flatMap(\.zeilen).count
        XCTAssertEqual(gezeigt, 80)
        XCTAssertNil(Wirkungsbild.baue(antwort(ereignisse: viele, n: 80)).rasterHinweis)
    }

    // MARK: - Die Zeile

    func testDerKontaktstreifenEndetAmRandDesAusschnitts() {
        let lang = Wirkungsbild.zeile(
            ereignis(kontaktMin: 300), schwelleKw: 1, vorMin: 30, nachMin: 120, folgeMin: 30)
        XCTAssertEqual(lang.kontaktstreifen, 30..<151)
        XCTAssertEqual(lang.kontaktMin, 300, "Die gemessene Dauer bleibt, nur der Strich endet.")

        let kurz = Wirkungsbild.zeile(
            ereignis(kontaktMin: 10), schwelleKw: 1, vorMin: 30, nachMin: 120, folgeMin: 30)
        XCTAssertEqual(kurz.kontaktstreifen, 30..<40)

        let ohne = Wirkungsbild.zeile(
            ereignis(kontaktMin: 0), schwelleKw: 1, vorMin: 30, nachMin: 120, folgeMin: 30)
        XCTAssertNil(ohne.kontaktstreifen)
    }

    func testDieZeitSteigtInDerZeitDesHausesUndNichtInDerDesZeitstempels() {
        let z = Wirkungsbild.zeile(
            ereignis(at: "2026-11-07T23:30:00Z"), schwelleKw: 1, vorMin: 30, nachMin: 120,
            folgeMin: 30)
        XCTAssertEqual(z.wann, "So., 08.11. 00:30")
        XCTAssertEqual(
            z.weg, "/waerme/wiedergabe?day=2026-11-08&t=0",
            "Die Wiedergabe des Vortages zeigt das Ereignis nicht.")
    }

    func testDieZeitSpalteTraegtFuehrendeNullenDamitDieZiffernUntereinanderStehen() {
        let z = Wirkungsbild.zeile(
            ereignis(at: "2026-11-07T14:35:00+01:00"), schwelleKw: 1, vorMin: 30, nachMin: 120,
            folgeMin: 30)
        XCTAssertEqual(z.wann, "Sa., 07.11. 14:35")
    }

    func testEinUnlesbarerZeitstempelLaesstDieZeileStehenOhneZuLuegen() {
        let z = Wirkungsbild.zeile(
            ereignis(at: "gleich"), schwelleKw: 1, vorMin: 30, nachMin: 120, folgeMin: 30)
        XCTAssertEqual(z.wann, Formate.leer)
        XCTAssertEqual(z.weg, "/waerme/wiedergabe")
    }

    // MARK: - Das Wort neben der Zeile

    func testDasErgebniswortNenntDenGrundUndNichtNurDieZahl() {
        let f = 30
        XCTAssertEqual(
            Wirkungsbild.ergebnisText(ereignis(liefSchon: true), folgeMin: f), "lief schon")
        XCTAssertEqual(
            Wirkungsbild.ergebnisText(ereignis(auswertbar: false), folgeMin: f), "Messung fehlt")
        XCTAssertEqual(
            Wirkungsbild.ergebnisText(ereignis(gefolgt: false, verzoegerung: nil), folgeMin: f),
            "kein Anlauf")
        XCTAssertEqual(Wirkungsbild.ergebnisText(ereignis(verzoegerung: 0), folgeMin: f), "sofort")
        XCTAssertEqual(
            Wirkungsbild.ergebnisText(ereignis(verzoegerung: 7), folgeMin: f), "nach 7 min")
    }

    func testAbDerFolgefristHeisstEsErstNachUndZaehltNichtMehrAlsFolge() {
        XCTAssertEqual(
            Wirkungsbild.ergebnisText(ereignis(verzoegerung: 29), folgeMin: 30), "nach 29 min")
        XCTAssertEqual(
            Wirkungsbild.ergebnisText(ereignis(verzoegerung: 30), folgeMin: 30),
            "erst nach 30 min", "Dieselbe Zahl entscheidet über Wort und Quote.")
    }

    // MARK: - Die Achse

    func testDieAchsenbeschriftungNenntDenNullpunktMitWortUndSonstDasVorzeichen() {
        XCTAssertEqual(Wirkungsbild.achsenText(0), "Anforderung")
        XCTAssertEqual(Wirkungsbild.achsenText(120), "+120 min")
        XCTAssertEqual(Wirkungsbild.achsenText(-30), "\u{2212}30 min")
        XCTAssertEqual(Wirkungsbild.achsenmarke(60, ende: 120), "+60")
        XCTAssertEqual(Wirkungsbild.achsenmarke(-30, ende: 120), "\u{2212}30")
        XCTAssertEqual(
            Wirkungsbild.achsenmarke(120, ende: 120), "+120 min",
            "Die Einheit steht einmal, am Ende.")
    }

    func testDieAchsenmarkenStehenAnteiligUeberDerBreiteUndDieFeinenVerschwindenAmTelefon() {
        let b = Wirkungsbild.baue(antwort())
        XCTAssertEqual(b.achsenmarken.map(\.minute), [-30, 0, 30, 60, 90, 120])
        XCTAssertEqual(b.achsenmarken.map(\.fein), [true, false, true, true, true, false])
        XCTAssertEqual(b.achsenmarken[0].anteil, 0, accuracy: 1e-9)
        XCTAssertEqual(b.achsenmarken[1].anteil, 30.0 / 151.0, accuracy: 1e-9)
        XCTAssertEqual(b.achsenmarken[5].anteil, 150.0 / 151.0, accuracy: 1e-9)
    }

    func testEinKurzerAusschnittBekommtKeineDoppelteMarke() {
        let b = Wirkungsbild.baue(antwort(vorMin: 30, nachMin: 30))
        XCTAssertEqual(b.achsenmarken.map(\.minute), [-30, 0, 30])
    }

    // MARK: - Urteil und Zeitraum

    func testJedeUrteilskennungBekommtIhrDeutschesWort() {
        XCTAssertEqual(Wirkungsbild.urteilswort("offen"), "noch offen")
        XCTAssertEqual(Wirkungsbild.urteilswort("wirkt"), "die Maschine folgt")
        XCTAssertEqual(Wirkungsbild.urteilswort("kein_unterschied"), "kein gesicherter Unterschied")
        XCTAssertEqual(Wirkungsbild.urteilswort("seltener"), "seltener als sonst")
    }

    func testEineUnbekannteKennungStehtRohDaUndWirdNichtErfunden() {
        XCTAssertEqual(Wirkungsbild.urteilswort("zu_wenig_daten"), "zu_wenig_daten")
        XCTAssertEqual(Wirkungsbild.urteilswort(nil), "noch offen")
    }

    func testDasBildUebernimmtDenUrteilssatzDesDienstesWortgleich() {
        let satz = "Die Maschine folgt der Anforderung: 100 % der Anforderungen …"
        let b = Wirkungsbild.baue(antwort(urteil: "wirkt", urteilDe: satz))
        XCTAssertEqual(b.urteilssatz, satz)
        XCTAssertEqual(b.urteilswort, "die Maschine folgt")
    }

    func testDieSpanneStehtAusgeschriebenUndNurMitBeidenEnden() {
        XCTAssertEqual(
            Wirkungsbild.spanne(von: "2026-10-10T00:00:00+02:00", bis: "2026-11-09T23:59:00+01:00"),
            "10. Oktober bis 9. November")
        XCTAssertNil(Wirkungsbild.spanne(von: "2026-10-10T00:00:00+02:00", bis: nil))
        XCTAssertNil(Wirkungsbild.spanne(von: nil, bis: nil))
        XCTAssertNil(Wirkungsbild.spanne(von: "irgendwann", bis: "2026-11-09T00:00:00+01:00"))
    }

    // MARK: - Der Vertrauensbereich

    func testDerVertrauensbereichStehtMitDerEinheitAmEndeUndNurWennErGanzDaIst() {
        let b = Wirkungsbild.baue(
            antwort(quote: 1, quoteLo: 0.94, quoteHi: 1, vergleich: vergleich(quote: 0.19)))
        XCTAssertEqual(b.quotenzeilen[0].zahl, "100")
        XCTAssertEqual(b.quotenzeilen[0].bereich, "94 bis 100\u{202F}%")
        XCTAssertNil(b.quotenzeilen[1].bereich, "Ein halber Bereich ist keine Angabe.")
        XCTAssertEqual(b.quotenzeilen[1].zahl, "19")
    }

    // MARK: - Der Vergleich ohne Anforderung

    func testDerIndexDerVergleichsreiheIstDieMinute() {
        let b = Wirkungsbild.baue(
            antwort(vergleich: vergleich(angelaufenBis: [0, 0.1, 0.25])))
        XCTAssertEqual(b.anteilOhne.map(\.minute), [0, 1, 2])
        XCTAssertEqual(b.anteilOhne.map(\.anteil), [0, 0.1, 0.25])
    }

    // MARK: - Die Auskunft zu einer Minute

    private var faecherMitAllem: Faecher {
        faecher(
            minuten: [-30, 0, 60], mittel: [0.0, 1.25, 2.5], q25: [nil, 0.8, 2.0],
            q75: [nil, 1.8, 3.0], n: [9, 9, 9], laeuft: [0, 0.5, 1],
            angelaufen: [nil, 0.1, 0.8])
    }

    func testDieAuskunftNenntDieMinuteInWortenUndRelativZurAnforderung() {
        let b = Wirkungsbild.baue(antwort(faecher: faecherMitAllem))
        XCTAssertEqual(b.auskunft(minute: 0)?.kopf, "Anforderung beginnt")
        XCTAssertEqual(b.auskunft(minute: 60)?.kopf, "60 min nach Beginn der Anforderung")
        XCTAssertEqual(b.auskunft(minute: -30)?.kopf, "30 min vor der Anforderung")
        XCTAssertNil(b.auskunft(minute: 999), "Eine Minute außerhalb des Ausschnitts hat keine Auskunft.")
    }

    func testDieAuskunftZeigtMittelMittlereHaelfteUndDenVergleich() {
        let b = Wirkungsbild.baue(
            antwort(faecher: faecherMitAllem, vergleich: vergleich(angelaufenBis: [0.05])))
        let a = b.auskunft(minute: 0)
        XCTAssertEqual(
            a?.zeilen.map(\.text),
            [
                "im Mittel 1,3\u{202F}kW",
                "mittlere Hälfte 0,8 bis 1,8\u{202F}kW",
                "läuft in 50\u{202F}% der 9 Ereignisse",
                "angelaufen 10\u{202F}%",
                "ohne Anforderung 5\u{202F}%",
            ])
        XCTAssertEqual(
            a?.zeilen.map(\.rolle), [.angefordert, nil, nil, .angefordert, .sonst])
        XCTAssertEqual(a?.zeilen.map(\.eingerueckt), [false, true, true, false, false])
    }

    func testVorDerAnforderungGibtEsNichtsZuVergleichen() {
        let b = Wirkungsbild.baue(
            antwort(faecher: faecherMitAllem, vergleich: vergleich(angelaufenBis: [0.05])))
        let texte = b.auskunft(minute: -30)?.zeilen.map(\.text) ?? []
        XCTAssertFalse(texte.contains { $0.hasPrefix("ohne Anforderung") })
        XCTAssertFalse(texte.contains { $0.hasPrefix("mittlere Hälfte") }, "Ohne Band keine Hälfte.")
        XCTAssertEqual(texte.first, "im Mittel 0,0\u{202F}kW")
    }

    func testOhneMessungSagtDieAuskunftGenauDasUndNichtNullKilowatt() {
        let f = faecher(minuten: [0], mittel: [nil], n: [0], laeuft: [nil], angelaufen: [nil])
        let b = Wirkungsbild.baue(antwort(faecher: f))
        XCTAssertEqual(b.auskunft(minute: 0)?.zeilen.map(\.text), ["keine Messung"])
    }

    // MARK: - Die fünf Kacheln

    func testDieFuenfKachelnStehenInDerReihenfolgeDerVorlage() {
        let k = Wirkungskacheln.kacheln(antwort())
        XCTAssertEqual(
            k.map(\.wort),
            [
                "Anforderungen", "danach angelaufen", "ohne Anforderung angelaufen",
                "Verzögerung", "Nachlauf",
            ])
        XCTAssertEqual(k.map(\.ton), [.normal, .glut, .nebel, .gedaempft, .gedaempft])
    }

    func testDieFuehrendeKachelTeiltDieAnforderungenInStehendUndLaufend() {
        let k = Wirkungskacheln.kacheln(antwort(n: 31, nLiefSchon: 9, nAuswertbar: 22))
        XCTAssertEqual(k[0].wert, "31")
        XCTAssertNil(k[0].einheit)
        XCTAssertEqual(k[0].dazu, "22 bei stehender Maschine, 9 bei laufender")
    }

    func testOhneEineEinzigeAnforderungSagtDieKachelDas() {
        let k = Wirkungskacheln.kacheln(antwort(n: 0))
        XCTAssertEqual(k[0].wert, "0")
        XCTAssertEqual(k[0].dazu, "im Zeitraum keiner")
        XCTAssertEqual(k[1].dazu, "keine auswertbare Anforderung")
        XCTAssertEqual(k[2].dazu, "kein Vergleich zur selben Tageszeit")
    }

    func testEineFehlendeZahlStehtAlsStrichUndDannOhneEinheit() {
        let k = Wirkungskacheln.kacheln(antwort())
        XCTAssertEqual(k[1].wert, "-")
        XCTAssertNil(k[1].einheit, "„- %\" ist keine Angabe.")
        XCTAssertEqual(k[3].wert, "-")
        XCTAssertNil(k[3].einheit)
        XCTAssertNil(k[4].einheit)
    }

    func testDieQuotenkachelZaehltAufWieVieleGefolgtSindUndWieVieleNicht() {
        let k = Wirkungskacheln.kacheln(
            antwort(folgeMin: 30, nAuswertbar: 22, gefolgt: 19, quote: 0.8636))
        XCTAssertEqual(k[1].wert, "86")
        XCTAssertEqual(k[1].einheit, "%")
        XCTAssertEqual(k[1].dazu, "19 von 22 binnen 30 Minuten, 3 nicht")
    }

    func testDieVergleichskachelNenntDieZahlDerVergleichsmomente() {
        let k = Wirkungskacheln.kacheln(
            antwort(vergleich: vergleich(quote: 0.19, gleicheStunde: 240)))
        XCTAssertEqual(k[2].wert, "19")
        XCTAssertEqual(k[2].einheit, "%")
        XCTAssertEqual(k[2].dazu, "zur selben Tageszeit, aus 240 Vergleichsmomenten")
    }

    func testVerzoegerungUndNachlaufStehenInMinutenUndNichtInStunden() {
        let k = Wirkungskacheln.kacheln(antwort(verzoegerungMedian: 4.6, nachlaufMedian: 95, nachlaufN: 3))
        XCTAssertEqual(k[3].wert, "5")
        XCTAssertEqual(k[3].einheit, "min")
        XCTAssertEqual(k[3].dazu, "Median von der Anforderung bis zum Anlauf")
        XCTAssertEqual(k[4].wert, "95", "Nicht „1 h 35 min\" - sonst stehen App und Wand verschieden da.")
        XCTAssertEqual(k[4].dazu, "Median nach dem Ende der Anforderung, 3 Fälle")
    }

    func testEinEinzelnerNachlaufIstEinFallUndNichtEinFaelle() {
        XCTAssertEqual(
            Wirkungskacheln.nachlaufSatz(1), "Median nach dem Ende der Anforderung, 1 Fall")
        XCTAssertEqual(
            Wirkungskacheln.nachlaufSatz(2), "Median nach dem Ende der Anforderung, 2 Fälle")
        XCTAssertEqual(Wirkungskacheln.nachlaufSatz(0), "kein Ende bei laufender Maschine")
        XCTAssertEqual(Wirkungskacheln.nachlaufSatz(nil), "kein Ende bei laufender Maschine")
    }

    // MARK: - Die zwei neuen Formate

    func testEineProzentzahlOhneEinheitLaesstDieEinheitDemSatz() {
        XCTAssertEqual(Formate.prozentZahl(1), "100")
        XCTAssertEqual(Formate.prozentZahl(0.194), "19")
        XCTAssertEqual(Formate.prozentZahl(0), "0")
        XCTAssertEqual(Formate.prozentZahl(nil), Formate.leer)
        XCTAssertEqual(Formate.prozentZahl(Double.nan), Formate.leer)
        XCTAssertFalse(Formate.prozentZahl(1).contains("%"))
    }

    func testEineDauerAlsBlosseMinutenzahlSchaltetNichtAufStundenUm() {
        XCTAssertEqual(Formate.minutenZahl(95), "95")
        XCTAssertEqual(Formate.minutenZahl(4.6), "5")
        XCTAssertEqual(Formate.minutenZahl(nil), Formate.leer)
        XCTAssertNotEqual(Formate.minutenZahl(95), Formate.dauer(minuten: 95))
    }
}
