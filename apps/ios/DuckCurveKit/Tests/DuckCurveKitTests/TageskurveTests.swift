import XCTest

@testable import DuckCurveKit

/// Das Tagesdiagramm, nachgezaehlt.
///
/// **Warum hier so genau geprueft wird.** Ein falsches Diagramm sieht nicht falsch aus. Eine
/// Prognose, die ueber einer Messung liegt, sieht aus wie eine dickere Linie; ein Vortag, der um
/// eine Stunde verschoben ist, sieht aus wie ein anderer Tag; eine Reihe, die einen Punkt zu
/// viel enthaelt, sieht aus wie eine Reihe. Nichts davon faellt am Geraet auf - hier faellt es auf.
final class TageskurveTests: XCTestCase {
    /// Ein Mittwoch Ende Februar, 14:35 Hauszeit.
    private let jetzt = Zeit.ausIso("2026-02-24T14:35:00+01:00")!

    private func raster(_ tag: String) -> [Verlaufspunkt] {
        var r = Minutenraster()
        r.setze(Vorschau.verlaufszeilen(tag: tag, schrittMin: 15), tag: tag)
        return r.punkte
    }

    /// Ein Plan ab einem Tagesbeginn. Die Bausteine kommen aus `Vorschau`, damit die Formen
    /// des Schemas an einer Stelle stehen und nicht in jedem Test geraten werden.
    private func plan(abTag: String, stunden: Int = 24, fenster: [PriceWindowOut] = []) -> PlanOut {
        guard let z = Tag.zeitraum(abTag) else { fatalError("Kalendertag im Test") }
        return Vorschau.plan(ab: z.von, stunden: stunden, fenster: fenster)
    }

    // MARK: - Welcher Punkt in welchen Tag faellt

    func testHeuteNimmtNurDieMesswerteVonHeute() {
        var alle = raster("2026-02-24")
        alle += raster("2026-02-23")
        let k = Tageskurve.baue(tag: .heute, raster: alle, plan: nil, jetzt: jetzt)
        // 96 Viertelstunden am Tag, und keine vom Vortag.
        XCTAssertEqual(k.pv.count, 96)
        XCTAssertTrue(k.pv.allSatisfy { $0.stunde >= 0 && $0.stunde < 24 })
        XCTAssertEqual(k.stunden, 24)
    }

    func testDieStundeIstDerAbstandZumTagesbeginn() {
        let k = Tageskurve.baue(tag: .heute, raster: raster("2026-02-24"), plan: nil, jetzt: jetzt)
        XCTAssertEqual(k.pv.first?.stunde, 0)
        XCTAssertEqual(k.pv.last?.stunde ?? 0, 23.75, accuracy: 1e-9)
    }

    /// Die Marke „jetzt" steht nur am laufenden Tag. Gestern ist vorbei und morgen hat noch
    /// nicht angefangen - eine Marke dort waere eine Behauptung.
    func testDieJetztMarkeStehtNurHeute() {
        let heute = Tageskurve.baue(tag: .heute, raster: [], plan: nil, jetzt: jetzt)
        XCTAssertEqual(heute.jetztStunde ?? 0, 14 + 35.0 / 60, accuracy: 1e-9)
        XCTAssertNil(Tageskurve.baue(tag: .gestern, raster: [], plan: nil, jetzt: jetzt).jetztStunde)
        XCTAssertNil(Tageskurve.baue(tag: .morgen, raster: [], plan: nil, jetzt: jetzt).jetztStunde)
    }

    // MARK: - Messung und Erwartung

    /// **Der Fall, der sich nicht ansehen laesst.** Die Erwartung darf nicht ueber der Messung
    /// liegen: sonst ist die Kurve doppelt gezeichnet und sagt an dieser Stelle nichts.
    func testDieErwartungBeginntErstJetzt() {
        let k = Tageskurve.baue(
            tag: .heute, raster: raster("2026-02-24"),
            plan: plan(abTag: "2026-02-24"), jetzt: jetzt
        )
        XCTAssertFalse(k.pvErwartet.isEmpty)
        // Fruehestens eine Viertelstunde vor jetzt - die Luecke an der Marke soll geschlossen sein.
        let frueheste = k.pvErwartet.map(\.stunde).min() ?? 0
        XCTAssertGreaterThanOrEqual(frueheste, 14 + 20.0 / 60 - 0.01)
        XCTAssertLessThanOrEqual(frueheste, 14 + 35.0 / 60 + 0.01)
    }

    /// Fuer gestern wird nichts vorhergesagt. Der Plan reicht in die Vergangenheit, und eine
    /// Prognose fuer einen gemessenen Tag ist keine.
    func testFuerGesternGibtEsKeineErwartung() {
        let k = Tageskurve.baue(
            tag: .gestern, raster: raster("2026-02-23"),
            plan: plan(abTag: "2026-02-23", stunden: 48), jetzt: jetzt
        )
        XCTAssertTrue(k.pvErwartet.isEmpty)
        XCTAssertTrue(k.preisErwartet.isEmpty)
        XCTAssertFalse(k.pv.isEmpty, "gemessen ist gestern trotzdem")
    }

    /// Fuer morgen ist alles Erwartung, und nur dort kommt die Waermeprognose dazu.
    func testFuerMorgenNurErwartung() {
        let waerme = Vorschau.waermeprognose(ab: Tag.zeitraum("2026-02-25")!.von)
        let k = Tageskurve.baue(
            tag: .morgen, raster: [],
            plan: plan(abTag: "2026-02-25"),
            waermeprognose: waerme, jetzt: jetzt
        )
        XCTAssertEqual(k.pvErwartet.count, 96)
        XCTAssertEqual(k.waermeErwartet.count, 24)
        XCTAssertTrue(k.pv.isEmpty)

        // Und fuer heute steht die Waermeprognose nicht da - dort ist sie gemessen.
        let heute = Tageskurve.baue(
            tag: .heute, raster: [], plan: nil, waermeprognose: waerme, jetzt: jetzt
        )
        XCTAssertTrue(heute.waermeErwartet.isEmpty)
    }

    // MARK: - Der Schatten

    /// **Der Vortag wird nach der Uhr abgebildet, nicht nach den Sekunden.** Sonst liegt er am
    /// Tag der Zeitumstellung um eine Stunde daneben, und der Vergleich vergleicht zwei
    /// verschiedene Uhrzeiten.
    func testDerSchattenLiegtNachDerUhr() {
        let vortag = raster("2026-02-23")
        let k = Tageskurve.baue(tag: .heute, raster: [], vortag: vortag, plan: nil, jetzt: jetzt)
        XCTAssertFalse(k.schatten.isEmpty)
        XCTAssertEqual(k.schatten.first?.stunde, 0)
        XCTAssertEqual(k.schatten.last?.stunde ?? 0, 23.75, accuracy: 1e-9)
        XCTAssertTrue(k.schatten.allSatisfy { $0.stunde >= 0 && $0.stunde < 24 })
    }

    /// Am Tag nach der Zeitumstellung hat der Vortag 25 Stunden. Nach der Uhr abgebildet,
    /// bleiben alle Punkte zwischen 0 und 24 - nach Sekunden gerechnet liefen sie bis 25.
    func testDerSchattenUeberlebtDieZeitumstellung() {
        let langerTag = raster("2026-10-25")  // der Tag mit 25 Stunden
        let jetztDanach = Zeit.ausIso("2026-10-26T12:00:00+01:00")!
        let k = Tageskurve.baue(
            tag: .heute, raster: [], vortag: langerTag, plan: nil, jetzt: jetztDanach
        )
        XCTAssertFalse(k.schatten.isEmpty)
        XCTAssertTrue(
            k.schatten.allSatisfy { $0.stunde >= 0 && $0.stunde < 24 },
            "nach der Uhr abgebildet bleibt der Vortag im Bild"
        )
        // Und der Tag selbst, der 25 Stunden hatte, wird auch als solcher erkannt.
        let umstellung = Tageskurve.baue(
            tag: .heute, raster: [], plan: nil,
            jetzt: Zeit.ausIso("2026-10-25T12:00:00+02:00")!
        )
        XCTAssertEqual(umstellung.stunden, 25)
    }

    // MARK: - Baender

    func testNurGuenstigeUndNegativeFensterWerdenGezeichnet() {
        let p = plan(abTag: "2026-02-24", fenster: [
            Vorschau.fenster("2026-02-24T11:00:00+01:00", "2026-02-24T14:00:00+01:00", .cheap),
            Vorschau.fenster("2026-02-24T13:00:00+01:00", "2026-02-24T13:30:00+01:00", .negative),
            Vorschau.fenster("2026-02-24T18:00:00+01:00", "2026-02-24T20:00:00+01:00", .expensive),
            Vorschau.fenster("2026-02-24T09:00:00+01:00", "2026-02-24T10:00:00+01:00", .pvSurplus),
        ])
        let k = Tageskurve.baue(tag: .heute, raster: [], plan: p, jetzt: jetzt)
        XCTAssertEqual(k.baender.count, 2)
        XCTAssertEqual(Set(k.baender.map(\.art)), [.guenstig, .negativ])
        XCTAssertEqual(k.baender.first { $0.art == .negativ }?.name, "Preis negativ")
    }

    /// Ein Fenster, das in den Tag hineinreicht, wird auf den Tag beschnitten - sonst zeichnet
    /// das Band ueber den Rand hinaus.
    func testFensterWerdenAufDenTagBeschnitten() {
        let p = plan(abTag: "2026-02-24", fenster: [
            Vorschau.fenster("2026-02-23T22:00:00+01:00", "2026-02-24T03:00:00+01:00", .cheap)
        ])
        let k = Tageskurve.baue(tag: .heute, raster: [], plan: p, jetzt: jetzt)
        XCTAssertEqual(k.baender.count, 1)
        XCTAssertEqual(k.baender[0].von, 0)
        XCTAssertEqual(k.baender[0].bis, 3, accuracy: 1e-9)
    }

    func testFensterAusserhalbDesTagesFallenWeg() {
        let p = plan(abTag: "2026-02-24", fenster: [
            Vorschau.fenster("2026-02-26T11:00:00+01:00", "2026-02-26T14:00:00+01:00", .cheap)
        ])
        let k = Tageskurve.baue(tag: .heute, raster: [], plan: p, jetzt: jetzt)
        XCTAssertTrue(k.baender.isEmpty)
    }

    // MARK: - Energie und Achsen

    /// Die Trapezregel ueber eine gerade Linie muss genau das Rechteck ergeben.
    func testEnergieUnterEinerKurve() {
        let flach = (0...24).map { Kurvenpunkt(stunde: Double($0), wert: 2.0) }
        XCTAssertEqual(Tageskurve.energie(flach) ?? 0, 48.0, accuracy: 1e-9)
        // Ein Dreieck von 0 auf 4 kW ueber vier Stunden: die halbe Flaeche.
        let dreieck = (0...4).map { Kurvenpunkt(stunde: Double($0), wert: Double($0)) }
        XCTAssertEqual(Tageskurve.energie(dreieck) ?? 0, 8.0, accuracy: 1e-9)
        // Ein Punkt ist keine Flaeche.
        XCTAssertNil(Tageskurve.energie([Kurvenpunkt(stunde: 1, wert: 5)]))
        XCTAssertNil(Tageskurve.energie([]))
    }

    /// Bis zur Jetzt-Marke gerechnet, nicht ueber den ganzen Tag: sonst vergleicht die Legende
    /// einen halben Tag mit einem ganzen.
    func testEnergieBisZurMarke() {
        let flach = (0...24).map { Kurvenpunkt(stunde: Double($0), wert: 2.0) }
        XCTAssertEqual(Tageskurve.energie(flach, bis: 12) ?? 0, 24.0, accuracy: 1e-9)
    }

    func testDieSummenStehenBereit() {
        let k = Tageskurve.baue(
            tag: .heute, raster: raster("2026-02-24"), vortag: raster("2026-02-23"),
            plan: nil, jetzt: jetzt
        )
        XCTAssertNotNil(k.pvKwh)
        XCTAssertNotNil(k.schattenKwh)
        // Beide bis zur gleichen Uhrzeit - also etwa gleich gross, nicht um den Faktor zwei daneben.
        XCTAssertEqual(k.pvKwh ?? 0, k.schattenKwh ?? 0, accuracy: 0.5)
    }

    /// Die Achse springt nicht auf den Hoechstwert, sondern auf eine runde Zahl darueber. Sonst
    /// zappelt die ganze Zeichnung bei jedem Takt.
    func testDieLeistungsachseIstRuhig() {
        var k = Tageskurve()
        k.pv = [Kurvenpunkt(stunde: 12, wert: 4.3)]
        XCTAssertEqual(k.leistungsgrenze, 5)
        // Auch bei nichts bleibt eine brauchbare Achse stehen.
        XCTAssertEqual(Tageskurve().leistungsgrenze, 4)
    }

    /// Negative Preise kommen vor und sind der Grund fuer das halbe Projekt: die Achse muss
    /// unter die Null reichen.
    func testDiePreisachseReichtUnterNull() {
        var k = Tageskurve()
        k.preis = [Kurvenpunkt(stunde: 3, wert: -1.4), Kurvenpunkt(stunde: 19, wert: 38.0)]
        let g = k.preisgrenzen
        XCTAssertLessThan(g.unten, 0)
        XCTAssertGreaterThan(g.oben, 38)
        // Ohne Preise eine brauchbare Vorgabe statt einer Achse von 0 bis 0.
        XCTAssertEqual(Tageskurve().preisgrenzen.oben, 40)
    }

    func testLeerErkanntWennNichtsDaIst() {
        XCTAssertTrue(Tageskurve().leer)
        var k = Tageskurve()
        k.haus = [Kurvenpunkt(stunde: 1, wert: 1)]
        XCTAssertFalse(k.leer)
    }
}
