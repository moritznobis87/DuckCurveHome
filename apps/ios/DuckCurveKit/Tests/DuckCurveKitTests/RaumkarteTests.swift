import XCTest

@testable import DuckCurveKit

/// Die Raumkachel: die Worte und die beiden Zeichnungen darin.
final class RaumkarteTests: XCTestCase {
    typealias R = Raumabweichung
    typealias K = Raumkarte

    // MARK: - Die Worte

    func testKelvinHatVorzeichenEchtesMinusUndSchmalesLeerzeichen() {
        XCTAssertEqual(R.kelvin(1.9), "+1,9" + Formate.schmalesLeerzeichen + "K")
        XCTAssertEqual(R.kelvin(-0.2), Formate.minus + "0,2" + Formate.schmalesLeerzeichen + "K")
        // Null ist keine Unterschreitung – sie bekommt dasselbe Minus wie jede andere Null im
        // Haus, und das ist die Entscheidung des Dashboards (`k > 0 ? "+" : "−"`).
        XCTAssertTrue(R.kelvin(0).hasPrefix(Formate.minus))
    }

    /// **Innerhalb des Bandes steht ein Wort, keine Zahl.** „−0,3 K" neben einem Raum, der am
    /// Ziel ist, liest sich als Mangel; „am Ziel" ist das Ergebnis, auf das es hinausläuft.
    func testAmZielStattEinerZahlImBand() {
        XCTAssertEqual(R.abweichungText(0.0), "am Ziel")
        XCTAssertEqual(R.abweichungText(0.5), "am Ziel")
        XCTAssertEqual(R.abweichungText(-0.5), "am Ziel")
        XCTAssertEqual(R.abweichungText(0.6), R.kelvin(0.6))
        XCTAssertEqual(R.abweichungText(nil), "kein Messwert")
    }

    /// **Im Augenblick ist der Anteil ein Bruch.** Die Antriebe kennen kein Dazwischen, also
    /// sagt „1 von 4 offen" mehr als „25 %" – und ist dieselbe Auskunft.
    func testVentilImAugenblickZaehltKreise() {
        XCTAssertEqual(R.ventilText(0.25, kreise: 4), "1 von 4 offen")
        XCTAssertEqual(R.ventilText(1.0, kreise: 4), "4 von 4 offen")
        XCTAssertEqual(R.ventilText(0.0, kreise: 4), "zu")
        XCTAssertEqual(R.ventilText(nil, kreise: 4), "kein Messwert")
        // Ohne bekannte Kreiszahl bleibt nur der Prozentsatz.
        XCTAssertEqual(R.ventilText(0.5, kreise: 0), R.anteilText(0.5))
        // Ein Anteil, der auf kein glattes Vielfaches fällt, ist kein Bruch von Kreisen –
        // dann wäre „1 von 3 offen" eine Erfindung.
        XCTAssertEqual(R.ventilText(0.4, kreise: 3), R.anteilText(0.4))
    }

    /// Über einen Zeitraum ist derselbe Anteil kein Bruch mehr, sondern ein Prozentsatz.
    func testAnteilUeberDenTagIstProzent() {
        XCTAssertEqual(R.anteilText(0.57), "57" + Formate.schmalesLeerzeichen + "%")
        XCTAssertEqual(R.anteilText(0), "zu")
        XCTAssertEqual(R.anteilText(nil), "kein Messwert")
    }

    func testFensterOhneKontaktSagtNichts() {
        XCTAssertNil(R.fensterText(offen: nil, seitMin: nil))
        XCTAssertNil(R.fensterText(offen: 0.0, seitMin: 120))
        XCTAssertEqual(R.fensterText(offen: 1, seitMin: nil), "Fenster offen")
        // Unter fünf Minuten wird nicht gezählt: das ist die Breite eines Fensters der
        // Zeitreihe, und „seit 0 min" wäre eine Genauigkeit, die es nicht gibt.
        XCTAssertEqual(R.fensterText(offen: 1, seitMin: 0), "Fenster offen")
        XCTAssertEqual(R.fensterText(offen: 1, seitMin: 30), "Fenster offen seit 30 min")
        XCTAssertEqual(R.fensterText(offen: 1, seitMin: 60), "Fenster offen seit 1 h")
        XCTAssertEqual(R.fensterText(offen: 1, seitMin: 135), "Fenster offen seit 2 h 15 min")
    }

    /// **Wie lange schon gelüftet wird, rückwärts aus der Reihe.** Einen Wechselzeitpunkt
    /// überträgt die Telemetrie nicht; die Zeitreihe weiß es auf die Breite eines Fensters.
    func testOffenSeitZaehltRueckwaerts() {
        let w: [Double?] = [0, 0, 1, 1, 1, nil]
        XCTAssertEqual(R.offenSeitMin(w, schrittMin: 15, bis: 5), 45)
        XCTAssertEqual(R.offenSeitMin(w, schrittMin: 15, bis: 3), 30)
        XCTAssertNil(R.offenSeitMin(w, schrittMin: 15, bis: 1))
        XCTAssertNil(R.offenSeitMin([], schrittMin: 15, bis: 0))
        // Ein Platz hinter dem Ende der Reihe ist kein Absturz.
        XCTAssertEqual(R.offenSeitMin(w, schrittMin: 15, bis: 99), 45)
    }

    /// **Die Etagenzeile nennt nur, was auffällt** – und wenn nichts auffällt, sagt sie das.
    func testEtagenzeile() {
        XCTAssertEqual(R.etagenText([raum(1, ist: 21, ziel: 21)]), "1 Raum · alle am Ziel")
        XCTAssertEqual(
            R.etagenText([raum(1, ist: 21, ziel: 21), raum(2, ist: 20, ziel: 20.2)]),
            "2 Räume · alle am Ziel")
        XCTAssertEqual(
            R.etagenText([
                raum(1, ist: 21, ziel: 21), raum(2, ist: 18, ziel: 21), raum(3, ist: nil, ziel: 21),
            ]),
            "3 Räume · 1 unter dem Ziel · 1 ohne Messwert")
        // Zu warme Räume erzeugen keinen Teilsatz: niemand regelt nach, weil ein Zimmer ein
        // Grad wärmer ist als geplant.
        XCTAssertEqual(
            R.etagenText([raum(1, ist: 23, ziel: 21)]), "1 Raum · alle am Ziel")
    }

    /// **Nach Etage, in der Reihenfolge, in der sie kommen** – nicht alphabetisch, sonst läge
    /// das Dachgeschoss vor dem Erdgeschoss.
    func testEtagenInDerReihenfolgeDesHauses() {
        let alle = [
            raum(1, ist: 21, ziel: 21, etage: "Erdgeschoss"),
            raum(2, ist: 21, ziel: 21, etage: "Dachgeschoss"),
            raum(3, ist: 21, ziel: 21, etage: "Erdgeschoss"),
            raum(4, ist: 21, ziel: 21, etage: ""),
        ]
        let g = R.nachEtage(alle)
        XCTAssertEqual(g.map(\.etage), ["Erdgeschoss", "Dachgeschoss", "ohne Etagenangabe"])
        XCTAssertEqual(g[0].raeume.map(\.id), [1, 3])
        XCTAssertEqual(g[2].raeume.map(\.id), [4])
    }

    // MARK: - Der Ventilstreifen

    /// **Auf Stunden verdichtet.** 96 Viertelstunden sind in einer Kachel anderthalb Punkte
    /// breit und ergaben einen gesprenkelten Streifen, in dem nichts zu erkennen war.
    func testVentilstundenVerdichtetVierFensterZuEinem() {
        let w: [Double?] = Array(repeating: 1, count: 4) + Array(repeating: 0, count: 4)
        let s = K.ventilstunden(w, proStunde: 4)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s[0], .wert(1))
        XCTAssertEqual(s[1], .wert(0))
    }

    func testEineStundeOhneJedenMesswertIstKeinWertUndKeineNull() {
        let s = K.ventilstunden([nil, nil, nil, nil], proStunde: 4)
        XCTAssertEqual(s, [.keinWert])
        // Ein einziger Messwert reicht für ein Mittel – der Rest der Stunde fehlt eben.
        XCTAssertEqual(K.ventilstunden([nil, 1, nil, nil], proStunde: 4), [.wert(1)])
    }

    /// Eine angebrochene Stunde zählt als gewesen: sie ist zur Hälfte Messung, und sie zu
    /// schraffieren hieße, die letzte Auskunft des Tages wegzunehmen.
    func testWasNochNichtWarIstSchraffiertAberNichtDieLaufendeStunde() {
        let w: [Double?] = Array(repeating: 1, count: 12)
        let s = K.ventilstunden(w, proStunde: 4, gewesen: 6)
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s[0], .wert(1))
        XCTAssertEqual(s[1], .wert(1), "die angebrochene Stunde zählt mit, was von ihr da ist")
        XCTAssertEqual(s[2], .nochNicht)
    }

    func testEinLeererTagGibtKeinenStreifen() {
        XCTAssertTrue(K.ventilstunden([], proStunde: 4).isEmpty)
        XCTAssertTrue(K.ventilstunden([1, 1], proStunde: 0).isEmpty)
    }

    // MARK: - Die Kurve

    /// **Gleiche Grad je Punkt in allen Kacheln.** Die Spanne ist fest bei ±2 K und wächst
    /// nur, wenn ein Raum darüber hinausgeht.
    func testDieSpanneIstMindestensZweiKelvin() {
        XCTAssertEqual(K.kurve([.wert(0.1), .wert(-0.2)]).spanne, 2)
        XCTAssertEqual(K.kurve([.wert(0.1), .wert(-2.4)]).spanne, 3)
        XCTAssertEqual(K.kurve([]).spanne, 2)
    }

    func testDasZielLiegtInDerMitte() {
        let k = K.kurve([.wert(0), .wert(0)])
        XCTAssertEqual(k.stuecke.count, 1)
        for p in k.stuecke[0] { XCTAssertEqual(p.y, 0.5, accuracy: 0.0001) }
    }

    /// Zu warm ist oben, zu kalt unten – und beides bleibt im Bild.
    func testWarmIstObenUndKaltIstUnten() {
        let k = K.kurve([.wert(2), .wert(-2)])
        XCTAssertLessThan(k.stuecke[0][0].y, 0.5)
        XCTAssertGreaterThan(k.stuecke[0][1].y, 0.5)
        for p in k.stuecke[0] {
            XCTAssertGreaterThanOrEqual(p.y, 0)
            XCTAssertLessThanOrEqual(p.y, 1)
        }
    }

    /// **Über eine Lücke wird nicht gezeichnet.** Eine durchgezogene Linie dort wäre eine
    /// Behauptung über Minuten, in denen nichts gemessen wurde.
    func testLueckenTrennenDieKurve() {
        let k = K.kurve([.wert(0), .wert(0), .keinWert, .wert(1), .wert(1)])
        XCTAssertEqual(k.stuecke.count, 2)
        XCTAssertEqual(k.stuecke[0].count, 2)
        XCTAssertEqual(k.stuecke[1].count, 2)
        // Die x-Werte bleiben an ihrem Platz im Tag: das zweite Stück fängt nach der Lücke an.
        XCTAssertEqual(k.stuecke[0][0].x, 0, accuracy: 0.0001)
        XCTAssertEqual(k.stuecke[1][0].x, 0.75, accuracy: 0.0001)
    }

    func testEinEinzelnerPunktIstKeineLinie() {
        let k = K.kurve([.wert(0), .keinWert, .wert(1), .keinWert, .wert(0), .wert(0)])
        XCTAssertEqual(k.stuecke.count, 1, "nur das Paar am Ende ist zu zeichnen")
    }

    func testEinTagOhneJedenMesswertHatKeineKurve() {
        XCTAssertTrue(K.kurve([.keinWert, .nochNicht, .keinWert]).stuecke.isEmpty)
    }

    // MARK: - An der Grenze

    /// **Dieser Raum bestimmt die Vorlauftemperatur für alle mit**: die Kreise standen fast den
    /// ganzen Tag offen und er ist trotzdem zu kalt.
    func testAnDerGrenze() {
        XCTAssertTrue(K.anDerGrenze(tagesventil: 0.9, abweichung: -1.2, fensterOffen: false))
        XCTAssertFalse(K.anDerGrenze(tagesventil: 0.5, abweichung: -1.2, fensterOffen: false))
        XCTAssertFalse(K.anDerGrenze(tagesventil: 0.9, abweichung: -0.2, fensterOffen: false))
        XCTAssertFalse(K.anDerGrenze(tagesventil: 0.9, abweichung: 1.2, fensterOffen: false))
    }

    /// **Ein offenes Fenster nimmt die Anklage zurück.** Sonst sieht ein gelüfteter Raum
    /// genauso aus wie einer, für den die Vorlauftemperatur nicht reicht – und die Seite schiebt
    /// es auf die Heizkurve.
    func testEinOffenesFensterErklaertDieKaelteSchon() {
        XCTAssertFalse(K.anDerGrenze(tagesventil: 0.95, abweichung: -2, fensterOffen: true))
    }

    func testOhneZahlenKeineDiagnose() {
        XCTAssertFalse(K.anDerGrenze(tagesventil: nil, abweichung: -2, fensterOffen: false))
        XCTAssertFalse(K.anDerGrenze(tagesventil: 1, abweichung: nil, fensterOffen: false))
    }

    func testDerLetzteGewesenePlatz() {
        XCTAssertEqual(K.letzterPlatz(6, laenge: 96), 5)
        XCTAssertEqual(K.letzterPlatz(nil, laenge: 96), 95)
        XCTAssertNil(K.letzterPlatz(0, laenge: 96))
        XCTAssertNil(K.letzterPlatz(nil, laenge: 0))
        XCTAssertEqual(K.letzterPlatz(999, laenge: 96), 95)
    }

    // MARK: - Hilfe

    private func raum(
        _ id: Int, ist: Double?, ziel: Double, etage: String = "Erdgeschoss"
    ) -> RoomLiveOut {
        RoomLiveOut(
            id: id,
            name: "Raum \(id)",
            floor: etage,
            circuits: 4,
            tempC: ist,
            setpointC: ziel,
            offsetK: 0,
            targetC: ziel,
            humidityPct: nil,
            valve: 0,
            window: 0,
            deviationK: ist.map { $0 - ziel },
            observedAt: nil,
            quality: .ok
        )
    }
}
