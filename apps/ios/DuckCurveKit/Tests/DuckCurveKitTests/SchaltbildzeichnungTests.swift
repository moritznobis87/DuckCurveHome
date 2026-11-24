import XCTest

@testable import DuckCurveKit

/// Der Text im Kästchen und der Weg einer Leitung. Die erwarteten Werte sind die, die
/// `Karte.tsx` im Dashboard für dieselben Eingaben rechnet.
final class SchaltbildzeichnungTests: XCTestCase {
    private func block(
        _ name: String, kurz: String = "", rolle: BlockAnsichtRolleWahl = .strecke,
        kreis: String? = nil, marke: String? = nil
    ) -> BlockAnsicht {
        BlockAnsicht(
            id: "b", ebene: 2, rolle: rolle, rolleText: "", name: name, kurz: kurz, kreis: kreis, marke: marke)
    }

    private func parameter(
        _ symbol: String, wert: Double, einheit: String, stellen: Int,
        herkunft: ParameterAnsichtHerkunftWahl = .gemessen
    ) -> ParameterAnsicht {
        ParameterAnsicht(
            id: symbol, block: "b", symbol: symbol, name: symbol, einheit: einheit, stellen: stellen,
            wert: wert, herkunft: herkunft, schaetzart: .ausgleich, schaetzartText: "", startwert: wert,
            unten: 0, oben: 100, warum: "", wirktAuf: [], protokoll: [])
    }

    // MARK: - Text

    func testDerUmbruchGeschiehtAnWortgrenzen() {
        XCTAssertEqual(Schaltbild.teile("Pufferspeicher mit Schichtung", max: 16), ["Pufferspeicher", "mit Schichtung"])
        XCTAssertEqual(Schaltbild.teile("Wärmepumpe", max: 4), ["Wärmepumpe"], "Ein Wort wird nicht zerrissen.")
        XCTAssertEqual(Schaltbild.teile("a b c", max: 3), ["a b", "c"])
        XCTAssertEqual(Schaltbild.teile("", max: 10), [])
    }

    func testGekuerztWirdMitAuslassungUndNieUnterVierZeichen() {
        XCTAssertEqual(Schaltbild.kuerze("Außentemperatur", breite: 62, proZeichen: 6.2), "Außentemp…")
        XCTAssertEqual(Schaltbild.kuerze("Außen", breite: 62, proZeichen: 6.2), "Außen")
        // Die Breite reichte für ein Zeichen; vier ist die Untergrenze.
        XCTAssertEqual(Schaltbild.kuerze("Strahlung", breite: 5, proZeichen: 6.2), "Str…")
        // Vor der Auslassung steht kein Leerzeichen.
        XCTAssertEqual(Schaltbild.kuerze("ab cdefgh", breite: 24.8, proZeichen: 6.2), "ab…")
    }

    func testGezaehltWirdWieImBrowser() {
        // „Q̇“ ist ein Q mit übergesetztem Punkt: zwei UTF-16-Einheiten, wie `"Q̇".length` im
        // Browser. Sechs Einheiten passen, also bleibt der Text ganz.
        XCTAssertEqual("Q̇ab".utf16.count, 4)
        XCTAssertEqual(Schaltbild.kuerze("Q̇ab", breite: 24.8, proZeichen: 6.2), "Q̇ab")
        XCTAssertEqual(Schaltbild.teile("Q̇ab Q̇zu", max: 7), ["Q̇ab", "Q̇zu"])
    }

    func testDerWertTraegtSeineEinheitUndKeinenStrichAlsEinheit() {
        XCTAssertEqual(Schaltbild.wert(parameter("UA", wert: 52.04, einheit: "W/K", stellen: 1)), "52,0 W/K")
        XCTAssertEqual(Schaltbild.wert(parameter("η", wert: 0.911, einheit: "—", stellen: 3)), "0,911")
    }

    func testDerStapelSetztNameFormelUndParameterUntereinander() {
        let r = Schaltbild.Rechteck(x: 100, y: 200, w: 184, h: 84)
        let zeilen = Schaltbild.stapel(
            block: block("Pelletofen (Stufe 1–5)", kurz: "PT1-Tt"), rect: r,
            parameter: [
                parameter("η", wert: 0.911, einheit: "—", stellen: 3),
                parameter("Tt", wert: 12, einheit: "min", stellen: 1, herkunft: .annahme),
            ],
            stoer: false, klein: false, oben: true, rechts: 54, mitFormel: false)
        XCTAssertEqual(zeilen.map(\.text), ["Pelletofen", "(Stufe 1–5)", "η = 0,911", "Tt = 12,0 min"])
        XCTAssertEqual(zeilen.map(\.art), [.name, .name, .wert, .wert])
        // Erste Grundlinie 19 unter der Oberkante, Namen im Abstand 14, drei Luft, Werte im Abstand 12,5.
        XCTAssertEqual(zeilen.map(\.y), [219, 233, 250, 262.5])
        XCTAssertEqual(zeilen.map(\.herkunft), [nil, nil, .gemessen, .annahme])
    }

    func testOhneKennbildStehtDieFormelUnterDemNamen() {
        let r = Schaltbild.Rechteck(x: 0, y: 0, w: 160, h: 84)
        let zeilen = Schaltbild.stapel(
            block: block("Regler", kurz: "PI"), rect: r, parameter: [],
            stoer: false, klein: false, oben: false, rechts: 0, mitFormel: true)
        XCTAssertEqual(zeilen.map(\.text), ["Regler", "PI"])
        XCTAssertEqual(zeilen.map(\.art), [.name, .formel])
        XCTAssertEqual(zeilen.map(\.y), [19, 36])
    }

    func testWasNichtMehrHineinpasstWirdWeggelassen() {
        // 44 hoch, mit Kreismarke unten: der Stapel endet 20 über der Unterkante, bei 24.
        let r = Schaltbild.Rechteck(x: 0, y: 0, w: 160, h: 44)
        let zeilen = Schaltbild.stapel(
            block: block("Fühler", kurz: "PT1", kreis: "R1"), rect: r,
            parameter: [parameter("T", wert: 90, einheit: "s", stellen: 0)],
            stoer: false, klein: true, oben: false, rechts: 0, mitFormel: true)
        XCTAssertEqual(zeilen.map(\.text), ["Fühler"], "Formel und Parameter lägen unter 24.")
    }

    func testEineStoergroesseBekommtEinenKleinenGekuerztenNamen() {
        let r = Schaltbild.Rechteck(x: 556, y: 62, w: 118, h: 40)
        let zeilen = Schaltbild.stapel(
            block: block("Solare Einstrahlung auf die Fenster", rolle: .stoergroesse), rect: r,
            parameter: [], stoer: true, klein: true, oben: false, rechts: 0, mitFormel: true)
        XCTAssertEqual(zeilen.count, 1)
        XCTAssertEqual(zeilen[0].art, .nameKlein)
        XCTAssertEqual(zeilen[0].y, 78)
        // 98 breit bei 6,2 je Zeichen sind 15 Zeichen: 14 und die Auslassung.
        XCTAssertEqual(zeilen[0].text, "Solare Einstra…")
    }

    // MARK: - Leitungen

    func testEineLeitungOhneKreuzungIstEinStreckenzug() {
        let p = [Schaltbild.Punkt(x: 0, y: 0), Schaltbild.Punkt(x: 10, y: 0), Schaltbild.Punkt(x: 10, y: 20)]
        XCTAssertEqual(
            Schaltbild.schritte(p, bogen: nil),
            [.beginn(p[0]), .linie(p[1]), .linie(p[2])])
        XCTAssertEqual(Schaltbild.schritte([p[0]], bogen: nil), [], "Ein einzelner Punkt ist keine Leitung.")
    }

    func testDieEntnahmeSpringtImBogenUeberDieRueckfuehrung() {
        // `heizkreis→puffer` steigt von 796 nach 580 und kreuzt bei 716.
        let weg = Schaltbilddaten.wege["heizkreis→puffer"]!
        XCTAssertEqual(
            Schaltbild.schritte(weg.punkte, bogen: weg.bogen),
            [
                .beginn(Schaltbild.Punkt(x: 800, y: 796)),
                .linie(Schaltbild.Punkt(x: 800, y: 722)),
                .bogen(ende: Schaltbild.Punkt(x: 800, y: 710), imUhrzeigersinn: false),
                .linie(Schaltbild.Punkt(x: 800, y: 580)),
            ])
        // Abwärts gezeichnet, läge der Bogen auf der anderen Seite.
        let ab = [Schaltbild.Punkt(x: 5, y: 0), Schaltbild.Punkt(x: 5, y: 100)]
        XCTAssertEqual(
            Schaltbild.schritte(ab, bogen: Schaltbild.Punkt(x: 5, y: 50)),
            [
                .beginn(ab[0]), .linie(Schaltbild.Punkt(x: 5, y: 44)),
                .bogen(ende: Schaltbild.Punkt(x: 5, y: 56), imUhrzeigersinn: true), .linie(ab[1]),
            ])
    }

    func testEineLeitungOhneEintragLaeuftVonRandZuRand() {
        let a = Schaltbild.Rechteck(x: 0, y: 0, w: 100, h: 40)
        let b = Schaltbild.Rechteck(x: 300, y: 100, w: 100, h: 60)
        XCTAssertEqual(
            Schaltbild.ersatzweg(von: a, nach: b),
            [
                Schaltbild.Punkt(x: 100, y: 20), Schaltbild.Punkt(x: 200, y: 20),
                Schaltbild.Punkt(x: 200, y: 130), Schaltbild.Punkt(x: 300, y: 130),
            ])
    }

    func testEineLeitungDesDienstesNimmtIhrenWegAusDerZeichnungOderDenErsatz() {
        let rechtecke = Schaltbild.rechtecke(bloecke: ["preis", "kosten_wp", "neu_im_kern"])
        XCTAssertEqual(rechtecke["neu_im_kern"], Schaltbild.notplatz(0))
        let gezeichnet = Schaltbild.weg(von: "preis", nach: "kosten_wp", rechtecke: rechtecke)
        XCTAssertEqual(gezeichnet?.punkte.first, Schaltbild.Punkt(x: 87, y: 102))
        let ersatz = Schaltbild.weg(von: "preis", nach: "neu_im_kern", rechtecke: rechtecke)
        XCTAssertEqual(ersatz?.punkte.count, 4)
        XCTAssertNil(Schaltbild.weg(von: "preis", nach: "unbekannt", rechtecke: rechtecke))
    }

    func testDieBildunterschriftNenntWasKeinenPlatzHat() {
        XCTAssertEqual(Schaltbild.ohnePlatz(bloecke: ["preis", "neu_im_kern", "puffer"]), ["neu_im_kern"])
        XCTAssertTrue(Schaltbild.bildunterschrift(ohnePlatz: []).hasSuffix("wo sie mehrfach angreifen (↗)."))
        XCTAssertTrue(
            Schaltbild.bildunterschrift(ohnePlatz: ["Neuer Block", "Noch einer"])
                .hasSuffix(" Ohne Platz in der Zeichnung: Neuer Block, Noch einer."))
    }
}
