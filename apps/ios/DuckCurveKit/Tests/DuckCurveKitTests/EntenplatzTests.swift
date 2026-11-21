import XCTest

@testable import DuckCurveKit

/// Die Stelle der Ente: welche es gibt, welche aus einem Zug folgt, und was aus Unsinn wird.
///
/// **Warum hier so viel geprüft wird für eine Ente, die man anfasst.** Ein verschobenes Zeichen
/// sieht an jeder Stelle plausibel aus – auch an einer, die zur Hälfte neben dem Schirm liegt
/// oder auf der Leiste der fünf Bereiche. Dieselbe Beobachtung wie bei der Tagesuhr: „ein Ring,
/// der um eine Viertelstunde verdreht ist, sieht genauso plausibel aus wie ein richtiger“.
/// Darum steht die Rechnung hier und nicht in der Ansicht.
final class EntenplatzTests: XCTestCase {

    /// Ein Telefon im Hochformat, ohne Kopf und ohne Bereichsleiste – das Feld, über dem die
    /// Ente in ``HandRahmen`` schwebt.
    private let telefon = Entenplatz.Flaeche(breite: 390, hoehe: 560)
    /// Ein iPad im Querformat, wie die Wandanzeige.
    private let wand = Entenplatz.Flaeche(breite: 1180, hoehe: 700)

    // MARK: - Die Stellen

    func testSechsStellenAnZweiKantenUndDreiHoehen() {
        XCTAssertEqual(Entenplatz.Stelle.allCases.count, 6)
        for seite in Entenplatz.Seite.allCases {
            for hoehe in Entenplatz.Hoehe.allCases {
                let treffer = Entenplatz.Stelle.allCases.filter {
                    $0.seite == seite && $0.hoehe == hoehe
                }
                XCTAssertEqual(treffer.count, 1, "\(hoehe.rawValue) \(seite.rawValue)")
            }
        }
    }

    func testDieVorgabeIstUntenRechtsWieBisher() {
        XCTAssertEqual(Entenplatz.vorgabe, .untenRechts)
        XCTAssertEqual(Entenplatz.versatz(.untenRechts, in: telefon), .ursprung)
    }

    /// Der Ring am Rand: zwei benachbarte Stellen unterscheiden sich in genau einer Richtung.
    /// Sonst springt die Ente für die Bedienungshilfe über die Seite statt am Rand entlang.
    func testDerRingWandertAmRandEntlang() {
        var stelle = Entenplatz.vorgabe
        var gesehen: Set<Entenplatz.Stelle> = [stelle]
        for _ in 1..<Entenplatz.Stelle.allCases.count {
            let naechste = Entenplatz.naechste(nach: stelle)
            let seiteWechselt = naechste.seite != stelle.seite
            let hoeheWechselt = naechste.hoehe != stelle.hoehe
            XCTAssertNotEqual(
                seiteWechselt, hoeheWechselt,
                "\(stelle.name) → \(naechste.name) wechselt beides oder nichts")
            gesehen.insert(naechste)
            stelle = naechste
        }
        XCTAssertEqual(gesehen.count, 6, "Jede Stelle genau einmal auf einer Runde.")
        XCTAssertEqual(Entenplatz.naechste(nach: stelle), Entenplatz.vorgabe, "Und zurück.")
    }

    func testJedeStelleHatEinenGesprochenenNamen() {
        XCTAssertEqual(Entenplatz.Stelle.untenRechts.name, "unten rechts")
        XCTAssertEqual(Entenplatz.Stelle.obenLinks.name, "oben links")
        let namen = Set(Entenplatz.Stelle.allCases.map(\.name))
        XCTAssertEqual(namen.count, 6, "Zwei Stellen mit demselben Namen wären nicht ansagbar.")
    }

    // MARK: - Im Bild bleiben

    /// **Die Probe auf die eigentliche Zusage.** An jeder Stelle, in jeder Fläche, auch mit
    /// einem Zug weit über den Rand hinaus: das Entenfeld liegt vollständig im Bild.
    func testAnKeinerStelleUndNachKeinemZugRagtDieEnteHeraus() {
        let zuege = [
            Entenplatz.Punkt.ursprung,
            Entenplatz.Punkt(x: -4000, y: -4000),
            Entenplatz.Punkt(x: 4000, y: 4000),
            Entenplatz.Punkt(x: -4000, y: 4000),
            Entenplatz.Punkt(x: 180, y: -260),
        ]
        for flaeche in [telefon, wand] {
            for stelle in Entenplatz.Stelle.allCases {
                for zug in zuege {
                    let v = Entenplatz.versatz(stelle, zug: zug, in: flaeche)
                    XCTAssertLessThanOrEqual(v.x, 0)
                    XCTAssertLessThanOrEqual(v.y, 0)
                    XCTAssertGreaterThanOrEqual(
                        v.x, -(flaeche.breite - Entenplatz.kantenlaenge),
                        "\(stelle.name) ragt links heraus")
                    XCTAssertGreaterThanOrEqual(
                        v.y, -(flaeche.hoehe - Entenplatz.kantenlaenge),
                        "\(stelle.name) ragt oben heraus")
                }
            }
        }
    }

    /// Vor der ersten Messung ist die Fläche null. Dann gibt es nichts zu schieben, und die
    /// Ente sitzt in ihrer Ecke – und nicht an einer negativen Stelle.
    func testOhneGemesseneFlaecheBleibtDieEnteInDerEcke() {
        for stelle in Entenplatz.Stelle.allCases {
            let v = Entenplatz.versatz(
                stelle, zug: Entenplatz.Punkt(x: -300, y: -300), in: .unbekannt)
            XCTAssertEqual(v, .ursprung, stelle.name)
        }
    }

    /// Wird die Fläche kleiner – gedreht, geteiltes Fenster am iPad –, rückt die Ente nach,
    /// statt hinter der Kante zu verschwinden.
    func testEineKleinereFlaecheHoltDieEnteNach() {
        let gross = Entenplatz.versatz(.obenLinks, in: wand)
        let klein = Entenplatz.versatz(.obenLinks, in: telefon)
        XCTAssertLessThan(gross.x, klein.x, "Auf der breiten Fläche geht es weiter nach links.")
        XCTAssertGreaterThanOrEqual(klein.y, -(telefon.hoehe - Entenplatz.kantenlaenge))
    }

    // MARK: - Einrasten

    func testEinZugAnDieAndereKanteRastetDortEin() {
        // Von unten rechts weit nach links: unten links.
        let zug = Entenplatz.Punkt(x: -telefon.breite, y: 0)
        XCTAssertEqual(Entenplatz.einrasten(von: .untenRechts, zug: zug, in: telefon), .untenLinks)
    }

    func testEinZugNachObenRastetObenEin() {
        let zug = Entenplatz.Punkt(x: 0, y: -telefon.hoehe)
        XCTAssertEqual(Entenplatz.einrasten(von: .untenRechts, zug: zug, in: telefon), .obenRechts)
    }

    func testEinZugInDieMitteDerKanteRastetAufDerMittlerenHoeheEin() {
        let zug = Entenplatz.Punkt(x: 0, y: -(telefon.hoehe - Entenplatz.kantenlaenge) / 2)
        XCTAssertEqual(Entenplatz.einrasten(von: .untenRechts, zug: zug, in: telefon), .mitteRechts)
    }

    /// Ein Zug unter der Schwelle ist gar keiner. Rastet er trotzdem ein, muss es dieselbe
    /// Stelle sein – sonst wanderte die Ente beim Sprechen.
    func testEinKleinerZugAendertDieStelleNicht() {
        for stelle in Entenplatz.Stelle.allCases {
            let zug = Entenplatz.Punkt(x: -Entenplatz.zugSchwelle + 1, y: 0)
            XCTAssertFalse(Entenplatz.istZug(zug))
            XCTAssertEqual(Entenplatz.einrasten(von: stelle, zug: zug, in: telefon), stelle)
        }
    }

    /// Jede Stelle wird von ihrem eigenen Mittelpunkt aus wieder getroffen – das Einrasten
    /// kennt keine Stelle, die es nicht erreicht.
    func testJedeStelleIstErreichbar() {
        for flaeche in [telefon, wand] {
            for ziel in Entenplatz.Stelle.allCases {
                let von = Entenplatz.Stelle.untenRechts
                let m = Entenplatz.mittelpunkt(ziel, in: flaeche)
                let start = Entenplatz.mittelpunkt(von, in: flaeche)
                let zug = Entenplatz.Punkt(x: m.x - start.x, y: m.y - start.y)
                XCTAssertEqual(
                    Entenplatz.einrasten(von: von, zug: zug, in: flaeche), ziel,
                    "\(ziel.name) in \(flaeche.breite)×\(flaeche.hoehe)")
            }
        }
    }

    /// Wer über die Kante hinaus zieht, bleibt an der Kante – und rastet nicht wieder zurück,
    /// weil die Rechnung mit dem begrenzten Versatz arbeitet und nicht mit dem rohen Zug.
    func testUeberDieKanteHinausRastetAnDerKanteEin() {
        let zug = Entenplatz.Punkt(x: -3000, y: -3000)
        XCTAssertEqual(Entenplatz.einrasten(von: .untenRechts, zug: zug, in: telefon), .obenLinks)
    }

    // MARK: - Die Schwelle

    /// Die Schwelle ist der Radius des weißen Kreises: der Finger hat die Ente verlassen.
    func testDieSchwelleIstDerRandDerEnte() {
        XCTAssertEqual(Entenplatz.zugSchwelle, Entenplatz.entengroesse / 2 + Entenplatz.ring)
        XCTAssertTrue(Entenplatz.istZug(Entenplatz.Punkt(x: 0, y: -Entenplatz.zugSchwelle)))
        XCTAssertFalse(Entenplatz.istZug(.ursprung))
        // Schräg gezählt wird die Strecke und nicht die größere ihrer beiden Richtungen.
        let schraeg = Entenplatz.zugSchwelle * 0.71
        XCTAssertTrue(Entenplatz.istZug(Entenplatz.Punkt(x: schraeg, y: schraeg)))
        XCTAssertFalse(Entenplatz.istZug(Entenplatz.Punkt(x: schraeg, y: 0)))
    }

    /// Die Kantenlänge ist die Summe der drei Maße der Ansicht. Wächst das Bild, wächst sie mit
    /// – sonst schiebt ein größeres Bild die Ente still über die Kante.
    func testDieKantenlaengeKommtAusDenMassenDerEnte() {
        XCTAssertEqual(
            Entenplatz.kantenlaenge,
            Entenplatz.entengroesse + 2 * Entenplatz.ring + 2 * Entenplatz.rand)
        XCTAssertEqual(Entenplatz.kantenlaenge, 92)
    }

    // MARK: - Merken

    func testDerMerkerHeisstWieDieAnderenMerkerDesGeraets() {
        XCTAssertEqual(Entenplatz.merker, "dch-ente-stelle")
        XCTAssertTrue(Entenplatz.merker.hasPrefix("dch-"))
    }

    func testJedeStelleUeberlebtDasMerkenUndLesen() {
        for stelle in Entenplatz.Stelle.allCases {
            XCTAssertEqual(Entenplatz.gelesen(Entenplatz.gemerkt(stelle)), stelle)
        }
        XCTAssertEqual(Entenplatz.gemerkt(.mitteLinks), "mitteLinks")
    }

    /// **Der Fall, der sonst erst auf einem fremden Gerät auffällt.** Im Merker steht ein Wort
    /// aus einer Datei, die älter sein kann als diese Fassung: eine Stelle, die es einmal gab,
    /// ein abgeschnittener Wert, ein leerer Eintrag. Jedes davon ist die Vorgabe.
    func testAusUnsinnWirdDieVorgabeUndKeinAbsturz() {
        for roh in ["", " ", "mitte", "untenRechts ", "UNTENRECHTS", "oben-links", "7", "ente"] {
            XCTAssertEqual(Entenplatz.gelesen(roh), Entenplatz.vorgabe, "„\(roh)“")
        }
    }
}
