import XCTest

@testable import DuckCurveKit

/// Der Ladeschirm: drei Fristen, und jede von ihnen verhindert einen eigenen Schaden.
///
/// **Warum hier Zeiten durchgespielt werden und keine Bilder.** Die drei Fehler, die ein
/// Ladeschirm machen kann, sind alle zeitlich: er flackert (erscheint und geht wieder), er
/// zuckt (erscheint und ist nach einem Wimpernschlag weg) oder er bleibt für immer stehen. Der
/// letzte ist der schlimme - er sperrt den Nutzer aus seinem eigenen Haus aus -, und er ist der
/// einzige, den man an einem laufenden Gerät nicht sieht, weil man dafür einen Dienst braucht,
/// der schweigt. Hier schweigt er in einer Zeile.
final class LadeschirmTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// Ein Hundertstel Abstand zu jeder Frist, nach beiden Seiten.
    ///
    /// **Nicht Bequemlichkeit, sondern die Auflösung von `Date`.** Ein Zeitpunkt ist eine
    /// Gleitkommazahl von Sekunden seit 2001; bei 1,8 Milliarden Sekunden liegen die darstellbaren
    /// Werte knapp 2,4 · 10⁻⁷ Sekunden auseinander, und `t0 + 0,3` minus `t0` ergibt deshalb nicht
    /// 0,3, sondern eine Haaresbreite daneben - in welche Richtung, sagt die Rundung. Eine Frist
    /// von drei Zehntelsekunden ist keine Stoppuhr; geprüft wird davor und danach.
    private let haar: TimeInterval = 0.01

    private func lauf() -> Ladeschirm.Lauf { Ladeschirm.Lauf(start: t0) }

    /// Ein Takt nach `sekunden` ab Start.
    private func takt(
        _ l: inout Ladeschirm.Lauf, _ sekunden: TimeInterval,
        zahlen: Bool = false, fehler: Bool = false
    ) -> Ladeschirm.Lage {
        l.takt(
            jetzt: t0.addingTimeInterval(sekunden), hatZahlen: zahlen, fehlerSteht: fehler)
    }

    // MARK: - Die Reihenfolge der Fristen

    /// **Die drei Zahlen stehen in einer Ordnung, und sie ist die Aussage.** Wäre die
    /// Mindeststandzeit kürzer als die Ruhefrist, stünde der Schirm nie lange genug; wäre sie
    /// länger als die Aufgabefrist, hielte das Aufgeben ihn noch einmal so lange.
    func testDieFristenStehenInDerRichtigenOrdnung() {
        XCTAssertLessThan(Ladeschirm.ruhefrist, Ladeschirm.mindestens)
        XCTAssertLessThan(Ladeschirm.mindestens, Ladeschirm.aufgabeNach)
        // Länger als der Takt der Aufsicht wird nicht gewartet (`Hauszustand.starte()`).
        XCTAssertLessThanOrEqual(Ladeschirm.aufgabeNach, 5.0)
    }

    // MARK: - Er flackert nicht

    /// Achtzig Millisekunden: der Normalfall im eigenen Netz. Er erscheint gar nicht.
    func testInAchtzigMillisekundenErscheintErNie() {
        var l = lauf()
        XCTAssertEqual(takt(&l, 0), .verborgen)
        XCTAssertEqual(takt(&l, 0.05), .verborgen)
        XCTAssertEqual(takt(&l, 0.08, zahlen: true), .vorbei)
        XCTAssertFalse(l.erschienen)
    }

    /// Kurz vor Ablauf der Ruhefrist ist noch nichts zu sehen, danach steht er.
    func testErKommtErstNachDerRuhefrist() {
        var l = lauf()
        XCTAssertEqual(takt(&l, Ladeschirm.ruhefrist - haar), .verborgen)
        XCTAssertEqual(takt(&l, Ladeschirm.ruhefrist + haar), .steht)
        XCTAssertTrue(l.erschienen)
    }

    // MARK: - Er zuckt nicht

    /// Kommen die Zahlen hundert Millisekunden nach seinem Erscheinen, bleibt er trotzdem
    /// stehen - bis die Mindeststandzeit um ist.
    func testEinmalDaBleibtErDieMindestzeit() {
        var l = lauf()
        let auf = Ladeschirm.ruhefrist + haar
        XCTAssertEqual(takt(&l, auf), .steht)
        XCTAssertEqual(takt(&l, auf + 0.1, zahlen: true), .steht)
        XCTAssertEqual(takt(&l, auf + Ladeschirm.mindestens - haar, zahlen: true), .steht)
        XCTAssertEqual(takt(&l, auf + Ladeschirm.mindestens + haar, zahlen: true), .vorbei)
    }

    /// Die Mindestzeit zählt ab dem Erscheinen und nicht ab dem Start - sonst wäre sie bei
    /// einem Schirm, der spät kommt, schon abgelaufen, bevor er dasteht.
    func testDieMindestzeitZaehltAbDemErscheinen() {
        var l = lauf()
        XCTAssertEqual(takt(&l, 2.0), .steht)
        XCTAssertEqual(takt(&l, 2.0 + Ladeschirm.mindestens - haar, zahlen: true), .steht)
        XCTAssertEqual(takt(&l, 2.0 + Ladeschirm.mindestens + haar, zahlen: true), .vorbei)
    }

    // MARK: - Er bleibt nicht hängen

    /// Der Dienst schweigt für immer. Nach der Aufgabefrist geht der Schirm trotzdem.
    func testEinSchweigenderDienstSperrtNiemandenAus() {
        var l = lauf()
        XCTAssertEqual(takt(&l, 1), .steht)
        XCTAssertEqual(takt(&l, Ladeschirm.aufgabeNach - haar), .steht)
        XCTAssertEqual(takt(&l, Ladeschirm.aufgabeNach + haar), .vorbei)
    }

    /// Und er kommt auch dann nicht wieder, wenn danach noch Minuten ohne Zahlen vergehen.
    func testNachDemAufgebenKommtErNichtWieder() {
        var l = lauf()
        _ = takt(&l, 1)
        XCTAssertEqual(takt(&l, Ladeschirm.aufgabeNach + haar), .vorbei)
        XCTAssertEqual(takt(&l, 60), .vorbei)
        XCTAssertEqual(takt(&l, 600), .vorbei)
    }

    /// **Eine Uhr, die zurückgeht, sperrt auch niemanden aus.**
    ///
    /// Die Lage, in der das zusammenfällt, ist die von `Ladeschirm.wandzusatz`: das iPad kommt
    /// nach einem Stromausfall um vier Uhr von allein hoch, die stehengebliebene Uhr wird vom
    /// Netz gestellt - und zwar zurück -, und der Dienst im Haus hing am selben Strom und
    /// schweigt noch. Solange die Fristen an `jetzt - start` hingen, wurde die Differenz dabei
    /// kleiner statt größer, die fünf Sekunden waren nie erreicht und der Schirm blieb stehen.
    func testEineZurueckgehendeUhrSperrtNiemandenAus() {
        var l = lauf()
        XCTAssertEqual(takt(&l, 1), .steht)
        // Die Netzzeit stellt die Uhr um eine Stunde zurück.
        XCTAssertEqual(takt(&l, 1 - 3600), .steht)
        // Von dort an zählt die Zeit wieder - und die eine Sekunde von vor dem Sprung ist
        // nicht verloren, es fehlen also noch vier der fünf.
        let rest = Ladeschirm.aufgabeNach - 1
        XCTAssertEqual(takt(&l, 1 - 3600 + rest - haar), .steht)
        XCTAssertEqual(takt(&l, 1 - 3600 + rest + haar), .vorbei)
    }

    /// **Dasselbe für den guten Ausgang.** Reißt die Verbindung nach dem Laden ab, darf der
    /// Schirm nicht über die Seite zurückkommen, auf der gerade jemand tippt.
    func testNachDenZahlenKommtErNichtWiederWennDieVerbindungAbreisst() {
        var l = lauf()
        _ = takt(&l, Ladeschirm.ruhefrist + haar)
        XCTAssertEqual(takt(&l, 1.0, zahlen: true), .vorbei)
        XCTAssertEqual(takt(&l, 30, zahlen: false), .vorbei)
    }

    /// Ein Fehler, der nicht von selbst weggeht, beendet das Warten sofort: der Nutzer muss an
    /// den Zugang kommen, um ein falsches Token zu ersetzen.
    func testEinStehenderFehlerLaesstSofortDurch() {
        var l = lauf()
        XCTAssertEqual(takt(&l, 0.1, fehler: true), .vorbei)
        XCTAssertFalse(l.erschienen)
    }

    /// Steht er schon, gilt auch für den Fehler die Mindestzeit - zwischen zwei Bildern ist ein
    /// Zucken ein Zucken, egal welches das zweite ist.
    func testBeiEinemFehlerWaehrendErStehtGiltDieMindestzeit() {
        var l = lauf()
        let auf = Ladeschirm.ruhefrist + haar
        XCTAssertEqual(takt(&l, auf), .steht)
        XCTAssertEqual(takt(&l, auf + 0.1, fehler: true), .steht)
        XCTAssertEqual(takt(&l, auf + Ladeschirm.mindestens + haar, fehler: true), .vorbei)
    }

    // MARK: - Was dasteht

    /// Der Satz ist wörtlich der, den die Startseite in derselben Lage sagt
    /// (`Hauszustand.satz`, solange kein Augenblicksbild da ist). Zwei Wörter für dasselbe
    /// Warten wären zwei Versprechen.
    func testDerSatzIstDerSatzDerStartseite() {
        XCTAssertEqual(Ladeschirm.satz, "Verbinde mit dem Haus …")
    }

    /// Die kurze Wortmarke, wie im Kopf der Anzeige und unter dem Programmsymbol - nicht der
    /// Name des Dienstes.
    func testDieWortmarkeIstDieKurze() {
        XCTAssertEqual(Ladeschirm.marke, "Duck Curve")
        XCTAssertFalse(Ladeschirm.marke.contains("Home"))
    }

    /// Der Zusatz steht nur an der Wand und sagt, dass niemand etwas tun muss.
    func testDerWandzusatzNimmtDieAufforderungZurueck() {
        XCTAssertTrue(Ladeschirm.wandzusatz.contains("Niemand muss etwas tun"))
    }

    /// Für VoiceOver ein Satz, und er sagt, worauf gewartet wird - nicht nur, dass gewartet
    /// wird.
    func testDerVorleserSagtWoraufGewartetWird() {
        XCTAssertTrue(Ladeschirm.vorleser.contains(Ladeschirm.marke))
        XCTAssertTrue(Ladeschirm.vorleser.contains("Haus"))
        XCTAssertTrue(Ladeschirm.vorleser.hasSuffix("."))
    }
}
