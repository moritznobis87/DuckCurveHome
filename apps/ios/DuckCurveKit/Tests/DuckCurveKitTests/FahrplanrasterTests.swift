import XCTest

@testable import DuckCurveKit

final class FahrplanrasterTests: XCTestCase {

    // MARK: - Die gemeinsame Werteachse

    /// Die Preisachse der Vorlage: ab einer auf 5 ct abgerundeten Untergrenze.
    func testDiePreisachseBeschriftetInRundenStufenAbDerUntergrenze() {
        let marken = Fahrplanraster.achsenmarken(20...48.7)
        XCTAssertEqual(marken.map(\.wert), [20, 30, 40])
        XCTAssertEqual(marken.map(\.wort), ["20", "30", "40"])
    }

    /// `showMinLabel: true` (`Fahrplan.tsx:264-267`): die unterste Zahl steht immer da.
    func testDieUnterstenMarkeIstDieUntergrenzeSelbst() {
        for spanne in [0.0...2.7, 20.0...48.7, 1.5...4.2, 0.0...12.0] {
            let marken = Fahrplanraster.achsenmarken(spanne)
            XCTAssertEqual(marken.first?.wert, spanne.lowerBound)
            XCTAssertEqual(marken.first?.anteil, 0)
        }
    }

    /// Eine Wärmeachse ab 1,5 kW: die Marken liegen auf der Untergrenze plus Stufe, also auf
    /// den Halben - und dann braucht die ganze Achse eine Nachkommastelle.
    func testEineAchseAufHalbenZahlenBekommtEineNachkommastelle() {
        let marken = Fahrplanraster.achsenmarken(1.5...4.2)
        XCTAssertEqual(marken.map(\.wert), [1.5, 2.5, 3.5])
        XCTAssertEqual(marken.map(\.wort), ["1,5", "2,5", "3,5"])
    }

    func testDerAnteilIstNullUntenUndEinsOben() {
        let marken = Fahrplanraster.achsenmarken(0...10, etwa: 2)
        XCTAssertEqual(marken.map(\.wert), [0, 5, 10])
        XCTAssertEqual(marken.map(\.anteil), [0, 0.5, 1])
    }

    /// Geht die Spanne glatt auf, kommt die oberste Marke dazu - so hält es die Vorlage.
    func testEineGlatteSpanneBekommtEineMarkeMehr() {
        XCTAssertEqual(Fahrplanraster.achsenmarken(0...30).map(\.wert), [0, 10, 20, 30])
    }

    /// Die drei Streifen des Fahrplans haben eine Spanne 0…1 und keine sichtbare Achse; wer sie
    /// doch beschriftet, soll keine zwanzig Marken bekommen.
    func testEineSpanneVonNullBisEinsBekommtDreiMarken() {
        let marken = Fahrplanraster.achsenmarken(0...1)
        XCTAssertEqual(marken.map(\.wert), [0, 0.5, 1])
        // Eine Stelle für die ganze Achse, nicht je Marke: „0 / 0,5 / 1“ wären drei
        // Schreibweisen übereinander.
        XCTAssertEqual(marken.map(\.wort), ["0,0", "0,5", "1,0"])
    }

    /// Eine Fläche ohne Schwankung: ``Fahrplanbild/spanne(_:bis:)`` gibt dann `von...von+1`.
    /// Kaputte Spannen dürfen keine Endlosschleife und keine Marke ergeben.
    func testEineLeereOderUngueltigeSpanneBekommtKeineMarken() {
        XCTAssertEqual(Fahrplanraster.achsenmarken(5...5).count, 0)
        XCTAssertEqual(Fahrplanraster.achsenmarken(0...Double.infinity).count, 0)
        XCTAssertEqual(Fahrplanraster.achsenmarken(0...10, etwa: 0).count, 0)
    }

    func testDieStufeIstEinsZweiOderFuenfMalEineZehnerpotenz() {
        XCTAssertEqual(Fahrplanraster.stufe(30, etwa: 3), 10)
        XCTAssertEqual(Fahrplanraster.stufe(28.7, etwa: 3), 10)
        XCTAssertEqual(Fahrplanraster.stufe(12, etwa: 3), 5)
        XCTAssertEqual(Fahrplanraster.stufe(2.7, etwa: 3), 1)
        XCTAssertEqual(Fahrplanraster.stufe(0.6, etwa: 3), 0.2)
        XCTAssertEqual(Fahrplanraster.stufe(0, etwa: 3), 0)
    }

    func testHoechstensZweiNachkommastellen() {
        XCTAssertEqual(Fahrplanraster.stellen([0, 10, 20]), 0)
        XCTAssertEqual(Fahrplanraster.stellen([1.5, 2.5]), 1)
        XCTAssertEqual(Fahrplanraster.stellen([0, 0.25, 0.5]), 2)
        XCTAssertEqual(Fahrplanraster.stellen([0, 0.001]), 2)
    }

    // MARK: - Die Spaltenzahl der Kacheln

    /// `grid-cols-2 md:grid-cols-4 xl:grid-cols-7` (`Fahrplan.tsx:548`), um die beiden
    /// Seitenränder von je 16 Punkten versetzt.
    func testZweiVierUndSiebenSpaltenAnDenSchwellenDerVorlage() {
        XCTAssertEqual(Fahrplanraster.spalten(breite: 390 - 32), 2)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 735), 2)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 736), 4)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 1024 - 32), 4)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 1247), 4)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 1248), 7)
        XCTAssertEqual(Fahrplanraster.spalten(breite: 1366 - 32), 7)
    }

    /// Vor der ersten Messung ist die Breite null - dann gelten die zwei Spalten, mit denen die
    /// Vorlage ohne Medienabfrage anfängt.
    func testOhneGemesseneBreiteZweiSpalten() {
        XCTAssertEqual(Fahrplanraster.spalten(breite: 0), 2)
        XCTAssertEqual(Fahrplanraster.spalten(breite: -1), 2)
        XCTAssertEqual(Fahrplanraster.spalten(breite: .nan), 2)
    }

    // MARK: - Die Zellen einer Entscheidungszeile

    private func iv(
        _ stunde: Int, preis: Double?, zustand: PlanIntervalOutPlannedHpStateWahl = .release,
        ofen: Bool? = false, notiz: String? = "weil billig", puffer: Double? = 21.4
    ) -> PlanIntervalOut {
        PlanIntervalOut(
            ts: String(format: "2026-11-17T%02d:15:00+01:00", stunde),
            expectedPvKw: 0, priceCtKwh: preis, plannedHpState: zustand, plannedStoveOn: ofen,
            reasonCode: "cheap_window", noteDe: notiz, heatDemandKw: 3.1, dhwDemandKw: 0.5,
            bufferKwh: puffer)
    }

    private var jetzt: Date { Zeit.ausIso("2026-11-17T12:00:00+01:00")! }

    func testDieZeileTraegtAlleSiebenWoerterDerVorlage() {
        let e = Planauswahl.entscheidungen([iv(3, preis: 18.44)])
        let z = Fahrplanraster.zeilen(e, jetzt: jetzt)
        XCTAssertEqual(z.count, 1)
        XCTAssertEqual(z[0].zeit, "heute 03:15")
        // „18,4 ct“ und nicht „18,4 ct/kWh“ (`Fahrplan.tsx:713`).
        XCTAssertEqual(z[0].preis, Formate.ctKurz(18.44))
        XCTAssertFalse(z[0].preis.contains("/kWh"))
        XCTAssertEqual(z[0].bedarf, Formate.kwMitEinheit(3.6))
        XCTAssertEqual(z[0].puffer, Formate.kwh(21.4))
        XCTAssertEqual(z[0].pufferrolle, .puffer)
        XCTAssertEqual(z[0].zustand, "angefordert")
        XCTAssertEqual(z[0].zustandsrolle, .angefordert)
        XCTAssertEqual(z[0].ofen, "aus")
        XCTAssertEqual(z[0].ofenMitWort, "Ofen aus")
        XCTAssertEqual(z[0].ofenrolle, .ofenAus)
        XCTAssertEqual(z[0].warum, "weil billig")
    }

    /// Ohne Pufferzahl keine Pufferfarbe: die Vorlage färbt die Zelle nur, wo eine Zahl steht.
    func testEineLeerePufferzelleIstNichtGruen() {
        let e = Planauswahl.entscheidungen([iv(4, preis: 30, puffer: nil)])
        let z = Fahrplanraster.zeilen(e, jetzt: jetzt)
        XCTAssertEqual(z[0].puffer, Formate.leer)
        XCTAssertEqual(z[0].pufferrolle, .neutral)
    }

    /// Kein Ofenfahrplan: ein Strich, und davor steht am Telefon trotzdem das Wort.
    func testOhneOfenfahrplanEinStrichMitWort() {
        let e = Planauswahl.entscheidungen([iv(5, preis: 30, ofen: nil)])
        let z = Fahrplanraster.zeilen(e, jetzt: jetzt)
        XCTAssertEqual(z[0].ofen, Formate.leer)
        XCTAssertEqual(z[0].ofenMitWort, "Ofen " + Formate.leer)
        XCTAssertEqual(z[0].ofenrolle, .neutral)
    }

    func testOhneEntscheidungenKeineZeilen() {
        XCTAssertEqual(Fahrplanraster.zeilen([], jetzt: jetzt).count, 0)
        XCTAssertEqual(
            Fahrplanraster.zeilen(Planauswahl.entscheidungen([]), jetzt: jetzt).count, 0)
    }

    /// Ohne Preis fällt die Viertelstunde schon in ``Planauswahl`` weg - die Zeile darf dann
    /// gar nicht entstehen und nicht mit einem Strich dastehen.
    func testEineViertelstundeOhnePreisErgibtKeineZeile() {
        let e = Planauswahl.entscheidungen([iv(6, preis: nil)])
        XCTAssertEqual(Fahrplanraster.zeilen(e, jetzt: jetzt).count, 0)
    }

    func testDieSiebenSpaltennamenStehenInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            Fahrplanraster.spaltennamen,
            ["Zeit", "Preis", "Bedarf", "Puffer", "Wärmepumpe", "Ofen", "Warum"])
    }
}
