import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/rooms/RoomsReport.tsx:490` (der `title` je Feld
/// der Tagesmatrix) und `:367-373` (bis wohin der laufende Tag gemessen ist).
final class RaumfeldTests: XCTestCase {
    typealias R = Raumabweichung

    private func istwerte(at: String, raeume: [RoomLiveOut] = []) -> RoomsLiveOut {
        RoomsLiveOut(at: at, named: true, rooms: raeume)
    }

    // MARK: - Das Wort zu einem Feld

    func testDieDreiFaelleHabenDreiWorte() {
        XCTAssertEqual(R.feldwort(.nochNicht), "noch nicht")
        XCTAssertEqual(R.feldwort(.keinWert), "kein Messwert")
        XCTAssertEqual(R.feldwort(.wert(1.9)), "+1,9" + Formate.schmalesLeerzeichen + "K")
        XCTAssertEqual(
            R.feldwort(.wert(-0.4)), Formate.minus + "0,4" + Formate.schmalesLeerzeichen + "K")
    }

    /// **Der Punkt, um den es bei diesem Wort geht.** Innerhalb des Bandes sagt
    /// `abweichungText` „am Ziel“ - am Feld der Matrix traegt die Flaeche das schon, und der
    /// Griff darauf soll die Zahl hergeben (`RoomsReport.tsx:490`).
    func testImBandStehtDieZahlUndNichtAmZiel() {
        XCTAssertEqual(R.abweichungText(0.2), "am Ziel")
        XCTAssertEqual(R.feldwort(.wert(0.2)), "+0,2" + Formate.schmalesLeerzeichen + "K")
        XCTAssertNotEqual(R.feldwort(.wert(0.2)), "am Ziel")
    }

    /// Das Vorzeichen haengt an `k > 0`, in der Vorlage wie hier (`palette.ts:56-58`); genau
    /// null bekommt darum das Minus. Festgehalten, damit niemand es unbesehen „verbessert“ -
    /// angeglichen wuerde es, wenn die Vorlage es tut.
    func testGenauNullSchreibtSichWieInDerVorlage() {
        XCTAssertEqual(
            R.feldwort(.wert(0)), Formate.minus + "0,0" + Formate.schmalesLeerzeichen + "K")
    }

    func testEineRiesigeAbweichungRundetWieJedeAndere() {
        XCTAssertEqual(R.feldwort(.wert(12.34)), "+12,3" + Formate.schmalesLeerzeichen + "K")
        XCTAssertEqual(R.feldwort(.wert(0.049)), "+0,0" + Formate.schmalesLeerzeichen + "K")
    }

    // MARK: - Das Blaettchen

    func testDasBlaettchenTraegtRaumZeitUndWert() {
        let h = R.feldhinweis(
            name: "Wohnen", zeitIso: "2026-11-17T07:15:00+01:00", feld: .wert(-1.2))
        XCTAssertEqual(h.raum, "Wohnen")
        XCTAssertEqual(h.zeit, "07:15")
        XCTAssertEqual(h.wert, Formate.minus + "1,2" + Formate.schmalesLeerzeichen + "K")
        XCTAssertEqual(
            h.zeile,
            "Wohnen · 07:15 · " + Formate.minus + "1,2" + Formate.schmalesLeerzeichen + "K")
    }

    /// **Ein Feld ohne Messwert bekommt sein Blaettchen trotzdem** - anders als eine leere
    /// Zelle der Jahresflaeche. „kein Messwert“ und „noch nicht“ zu unterscheiden ist der
    /// Zweck dieser Karte, und ein stummer Griff waere gerade dort keine Antwort.
    func testAuchEinLeeresFeldHatEinBlaettchen() {
        let ohne = R.feldhinweis(
            name: "Bad", zeitIso: "2026-11-17T13:00:00+01:00", feld: .keinWert)
        XCTAssertEqual(ohne.zeile, "Bad · 13:00 · kein Messwert")
        let kuenftig = R.feldhinweis(
            name: "Bad", zeitIso: "2026-11-17T23:45:00+01:00", feld: .nochNicht)
        XCTAssertEqual(kuenftig.zeile, "Bad · 23:45 · noch nicht")
    }

    /// Eine Reihe darf kuerzer sein als ihre Felder; dann steht an der Stelle kein Zeitstempel.
    /// Ein Strich, kein „00:00“ - das waere eine Uhrzeit, die niemand gemessen hat.
    func testOhneZeitstempelStehtEinStrich() {
        XCTAssertEqual(R.feldhinweis(name: "Flur", zeitIso: nil, feld: .wert(0.3)).zeit,
                       Formate.leer)
        XCTAssertEqual(R.feldhinweis(name: "Flur", zeitIso: "unsinn", feld: .wert(0.3)).zeit,
                       Formate.leer)
        XCTAssertEqual(R.feldhinweis(name: "Flur", zeitIso: "", feld: .keinWert).zeit,
                       Formate.leer)
    }

    func testDerRaumnameWirdNichtAngetastet() {
        let h = R.feldhinweis(name: "", zeitIso: nil, feld: .keinWert)
        XCTAssertEqual(h.raum, "", "Ein Raum ohne Namen bleibt ohne Namen.")
        XCTAssertEqual(h.zeile, " · " + Formate.leer + " · kein Messwert")
    }

    // MARK: - Die Zeile fuer die Vorlesehilfe

    func testDieZeilenstimmeNenntMittelUndStummeFenster() {
        let felder: [R.Feld] = [.wert(-1.0), .wert(-2.0), .keinWert, .nochNicht]
        XCTAssertEqual(
            R.matrixzeilenwort(name: "Wohnen", felder: felder),
            "Wohnen · im Tagesmittel " + Formate.minus + "1,5"
                + Formate.schmalesLeerzeichen + "K · 1 von 4 Werten fehlt")
    }

    func testMehrereStummeFensterWerdenGezaehlt() {
        let felder: [R.Feld] = [.wert(0.6), .keinWert, .keinWert, .keinWert]
        XCTAssertEqual(
            R.matrixzeilenwort(name: "Bad", felder: felder),
            "Bad · im Tagesmittel +0,6" + Formate.schmalesLeerzeichen + "K · 3 von 4 Werten fehlen")
    }

    /// Ein kuenftiges Fenster fehlt nicht - es war noch nicht an der Reihe.
    func testKuenftigeFensterZaehlenNichtAlsFehlend() {
        let felder: [R.Feld] = [.wert(0.0), .nochNicht, .nochNicht]
        XCTAssertEqual(
            R.matrixzeilenwort(name: "Flur", felder: felder),
            "Flur · im Tagesmittel " + Formate.minus + "0,0" + Formate.schmalesLeerzeichen + "K")
    }

    func testEineZeileOhneJedenWertSagtDas() {
        XCTAssertEqual(
            R.matrixzeilenwort(name: "Gast", felder: [.keinWert, .keinWert]),
            "Gast · kein Messwert · 2 von 2 Werten fehlen")
        XCTAssertEqual(
            R.matrixzeilenwort(name: "Gast", felder: [.nochNicht]), "Gast · kein Messwert")
        XCTAssertEqual(R.matrixzeilenwort(name: "Gast", felder: []), "Gast · kein Messwert")
    }

    // MARK: - Bis wohin gemessen ist

    func testOhneIstwerteGiltDieHausuhr() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        XCTAssertEqual(R.gemessenBis(live: nil, jetzt: jetzt), jetzt)
    }

    /// **Die Uhr der Antwort schlaegt die Uhr des Hauses** (`RoomsReport.tsx:370-373`).
    func testMitIstwertenGiltDerZeitstempelDerAntwort() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        let gemessen = Zeit.ausIso("2026-11-17T07:00:00+01:00")!
        XCTAssertEqual(
            R.gemessenBis(live: istwerte(at: "2026-11-17T07:00:00+01:00"), jetzt: jetzt), gemessen)
    }

    func testEinUnlesbarerZeitstempelFaelltAufDieHausuhrZurueck() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        XCTAssertEqual(R.gemessenBis(live: istwerte(at: ""), jetzt: jetzt), jetzt)
        XCTAssertEqual(R.gemessenBis(live: istwerte(at: "gestern"), jetzt: jetzt), jetzt)
    }

    /// Das Ergebnis ist dazu da, in ``Raumabweichung/gewesen(tag:jetzt:schrittMin:)`` zu gehen:
    /// eine Bruecke, die seit zwei Stunden schweigt, schraffiert diese zwei Stunden nicht - sie
    /// zeichnet sie blass, denn gemessen wurde dort nichts mehr.
    func testDerZeitstempelDerAntwortVerschiebtDieGrenze() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        let live = istwerte(at: "2026-11-17T07:00:00+01:00")
        XCTAssertEqual(R.gewesen(tag: "2026-11-17", jetzt: jetzt, schrittMin: 15), 38)
        XCTAssertEqual(
            R.gewesen(
                tag: "2026-11-17", jetzt: R.gemessenBis(live: live, jetzt: jetzt),
                schrittMin: 15),
            28)
    }

    /// **Die Schrittbreite kommt aus der Antwort** (`RoomsReport.tsx:366`:
    /// `tag.step_min ?? STEP_MIN`). Mit halbstuendigen Fenstern liegt die Grenze bei der
    /// halben Zahl, und die Seite hat sie durchzugeben.
    func testEineAndereSchrittbreiteVerschiebtDieGrenze() {
        let jetzt = Zeit.ausIso("2026-11-17T07:00:00+01:00")!
        XCTAssertEqual(R.gewesen(tag: "2026-11-17", jetzt: jetzt, schrittMin: 15), 28)
        XCTAssertEqual(R.gewesen(tag: "2026-11-17", jetzt: jetzt, schrittMin: 30), 14)
        XCTAssertEqual(R.gewesen(tag: "2026-11-17", jetzt: jetzt, schrittMin: 60), 7)
    }

    /// Ein vergangener Tag ist ganz gewesen, ganz gleich welche Uhr die Antwort mitbringt -
    /// entschieden wird das in ``Raumabweichung/gewesen(tag:jetzt:schrittMin:)``.
    func testEinVergangenerTagBleibtGanzGewesen() {
        let live = istwerte(at: "2026-11-17T07:00:00+01:00")
        let jetzt = R.gemessenBis(live: live, jetzt: Zeit.ausIso("2026-11-17T09:30:00+01:00")!)
        XCTAssertNil(R.gewesen(tag: "2026-11-16", jetzt: jetzt, schrittMin: 15))
        XCTAssertEqual(R.gewesen(tag: "2026-11-18", jetzt: jetzt, schrittMin: 15), 0)
    }

    /// Die Felder und das Blaettchen lesen dieselbe Grenze: was `felder(…)` blass zeichnet,
    /// nennt `feldwort(…)` „noch nicht“.
    func testFelderUndBlaettchenSindSichEinig() {
        let ist: [Double?] = [20.0, 20.5, 21.0, 21.0]
        let soll: [Double?] = [21.0, 21.0, 21.0, 21.0]
        let felder = R.felder(
            ist: ist, soll: soll, versatz: [0.0, 0.0, 0.0, 0.0], bisStelle: 2)
        XCTAssertEqual(R.feldwort(felder[1]), Formate.minus + "0,5"
            + Formate.schmalesLeerzeichen + "K")
        XCTAssertEqual(R.feldwort(felder[2]), "noch nicht")
        XCTAssertEqual(R.feldwort(felder[3]), "noch nicht")
    }
}
