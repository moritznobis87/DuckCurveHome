import XCTest

@testable import DuckCurveKit

/// Der Ladehinweis: vier Entscheidungen, und jede verhindert einen eigenen Schaden.
///
/// **Warum hier Zahlen geprüft werden und keine Bilder.** Die vier Fehler, an denen eine
/// Ladeanimation scheitert, sind alle rechenbar: mehrere Enten laufen gegeneinander (der
/// Zirkus), eine Ente läuft stundenlang weiter (die Wand), sie ist an ihrer Stelle falsch groß,
/// und sie sagt VoiceOver nichts. Keinen davon sieht man an einem laufenden Gerät in der
/// Minute, in der man hinsieht - den zweiten sieht man erst nach einer Stunde, und den vierten
/// nur mit geschlossenen Augen. Hier stehen sie in Zeilen.
final class LadehinweisTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// Ein Hundertstel Toleranz - Gleitkommazahlen, dieselbe Begründung wie in
    /// `LadeschirmTests.haar`.
    private let haar: Double = 0.01

    // MARK: - Der Takt ist der des Hauses

    /// **Es gibt nur einen Atem in dieser App.** Der `Atempunkt` des Ruhebildes und der Schein
    /// des Ladeschirms laufen auf 1,8 Sekunden je Richtung; ein zweiter Takt daneben wäre auf
    /// derselben Seite zu sehen.
    func testDerTaktIstDerAtemDesHauses() {
        XCTAssertEqual(Ladehinweis.halbtakt, 1.8)
        XCTAssertEqual(Ladehinweis.takt, 2 * Ladehinweis.halbtakt)
    }

    /// Dreißig Bilder je Sekunde, und sie sind eine Obergrenze und keine Vorgabe.
    func testDerBildtaktIstDreissigBilder() {
        XCTAssertEqual(1 / Ladehinweis.bildtakt, 30, accuracy: haar)
        // Deutlich feiner als der Takt selbst: über hundert Bilder je Atemzug.
        XCTAssertGreaterThan(Ladehinweis.takt / Ladehinweis.bildtakt, 100)
    }

    // MARK: - Der Zirkus

    /// **Zwei Enten, die zu verschiedenen Zeiten dazukommen, stehen trotzdem im Schritt.**
    ///
    /// Das ist die Prüfung, um die es bei vier gleichzeitig ladenden Karten geht. Die eine Ente
    /// erscheint beim Öffnen der Seite, die andere drei Sekunden später, weil ihre Abfrage
    /// später losging. Hängt der Stand allein am Zeitpunkt, ist er für beide derselbe - ohne
    /// dass eine von der anderen wissen muss.
    func testVierEntenStehenImSelbenSchritt() {
        let gemeinsam = t0.addingTimeInterval(7.3)
        // Die Lage ist eine Funktion des Augenblicks, nicht des Erscheinens: dieselbe Zahl,
        // egal wer fragt.
        let erste = Ladehinweis.hub(jetzt: gemeinsam)
        let zweite = Ladehinweis.hub(jetzt: gemeinsam)
        XCTAssertEqual(erste, zweite)
        // Und sie ist wirklich getaktet: einen ganzen Atemzug später derselbe Stand.
        XCTAssertEqual(
            Ladehinweis.hub(jetzt: gemeinsam.addingTimeInterval(Ladehinweis.takt)), erste,
            accuracy: haar)
    }

    /// Einen halben Takt später ist die Ente am anderen Ende ihres Weges.
    func testEinenHalbenTaktSpaeterIstSieAmAnderenEnde() {
        let unten = t0.addingTimeInterval(-t0.timeIntervalSinceReferenceDate)
        // Ein Zeitpunkt genau auf dem Taktanfang: Zeiger 0, Ente unten.
        XCTAssertEqual(Ladehinweis.zeiger(jetzt: unten), 0, accuracy: haar)
        XCTAssertEqual(Ladehinweis.hub(jetzt: unten), 0, accuracy: haar)
        let oben = unten.addingTimeInterval(Ladehinweis.halbtakt)
        XCTAssertEqual(Ladehinweis.hub(jetzt: oben), 1, accuracy: haar)
    }

    /// Der Zeiger bleibt in seinem Fenster - auch für Zeitpunkte vor 2001, die in dieser
    /// Rechnung negativ sind.
    func testDerZeigerBleibtInSeinemFenster() {
        for schritt in stride(from: -5000.0, through: 5000.0, by: 7.3) {
            let z = Ladehinweis.zeiger(jetzt: t0.addingTimeInterval(schritt))
            XCTAssertGreaterThanOrEqual(z, 0)
            XCTAssertLessThan(z, 1)
        }
    }

    /// Der Hub bleibt zwischen unten und oben, über tausend Stellen des Taktes.
    func testDerHubBleibtZwischenUntenUndOben() {
        for i in 0...1000 {
            let h = Ladehinweis.hub(zeiger: Double(i) / 1000)
            XCTAssertGreaterThanOrEqual(h, 0)
            XCTAssertLessThanOrEqual(h, 1)
        }
    }

    /// **Die Umkehrpunkte sind weich und nicht hart.**
    ///
    /// Das ist der ganze Unterschied zwischen Schwimmen und Rucken: an den Enden des Weges
    /// bewegt sich die Ente je Bild kaum, in der Mitte am meisten. Eine Gerade zwischen unten
    /// und oben hätte überall denselben Schritt - und an den Enden einen Knick.
    func testDieUmkehrpunkteSindWeich() {
        let bild = Ladehinweis.bildtakt / Ladehinweis.takt
        let amEnde = abs(Ladehinweis.hub(zeiger: bild) - Ladehinweis.hub(zeiger: 0))
        let inDerMitte = abs(Ladehinweis.hub(zeiger: 0.25 + bild) - Ladehinweis.hub(zeiger: 0.25))
        XCTAssertLessThan(amEnde, inDerMitte / 10)
    }

    /// Der Schein atmet mit, von halber Deckung unten bis voller oben - die Zahlen des
    /// Ladeschirms.
    func testDerScheinAtmetMitDerEnte() {
        XCTAssertEqual(Ladehinweis.scheindeckung(hub: 0), 0.5, accuracy: haar)
        XCTAssertEqual(Ladehinweis.scheindeckung(hub: 1), 1, accuracy: haar)
        // Auch für Werte, die durch Rundung ein Haar neben dem Rand liegen.
        XCTAssertEqual(Ladehinweis.scheindeckung(hub: -0.2), 0.5, accuracy: haar)
        XCTAssertEqual(Ladehinweis.scheindeckung(hub: 1.2), 1, accuracy: haar)
    }

    // MARK: - Wer keine Bewegung will

    /// Abgestellte Bewegung heißt nicht „kein Bild“: die Ente steht in der Mitte ihres Weges,
    /// der Schein in der Stärke des Ladeschirms.
    func testOhneBewegungStehtDieEnteInDerMitte() {
        XCTAssertEqual(Ladehinweis.ruhigerHub, 0.5)
        XCTAssertEqual(Ladehinweis.ruhigeDeckung, 0.8)
        // Über dem Mittel und nicht darunter - der Schein ist auch Licht und nicht nur Takt.
        XCTAssertGreaterThan(
            Ladehinweis.ruhigeDeckung, Ladehinweis.scheindeckung(hub: Ladehinweis.ruhigerHub))
    }

    // MARK: - Die Wand

    /// **Eine Minute, und das ist die Grenze dieses Hauses.** Länger wartet keine Abfrage einer
    /// Auswertungsseite (`URLSession`, „die ueblichen sechzig Sekunden“ in `Api.swift`).
    func testDieFristIstEineMinute() {
        XCTAssertEqual(Ladehinweis.frist, 60)
        // Länger als das Vollbild wartet, denn eine Karte hat nichts, worauf sie umschalten
        // könnte - aber nicht so lang, dass eine hängende Abfrage die Nacht durchschaukelt.
        XCTAssertGreaterThan(Ladehinweis.frist, Ladeschirm.aufgabeNach)
        XCTAssertLessThanOrEqual(Ladehinweis.frist, 60)
    }

    /// Im Normalfall sieht niemand die Frist: sie ist viele Atemzüge lang.
    func testDieFristIstVieleAtemzuegeLang() {
        XCTAssertGreaterThan(Ladehinweis.frist / Ladehinweis.takt, 15)
    }

    /// Vor der Frist ist die Ente da, danach nicht mehr - und danach kommt sie auch nach
    /// Stunden nicht wieder.
    func testNachDerFristIstDieEnteWeg() {
        XCTAssertTrue(Ladehinweis.enteDa(verstrichen: 0))
        XCTAssertTrue(Ladehinweis.enteDa(verstrichen: Ladehinweis.frist - haar))
        XCTAssertFalse(Ladehinweis.enteDa(verstrichen: Ladehinweis.frist))
        XCTAssertFalse(Ladehinweis.enteDa(verstrichen: 3600))
    }

    /// Sie geht in der Überblendung dieses Hauses - derselben, mit der das Ruhebild kommt und
    /// geht und die ``Ladeschirm/mindestens`` trägt.
    func testSieGehtInDerUeberblendungDesHauses() {
        XCTAssertEqual(Ladehinweis.abgang, 0.6)
        XCTAssertEqual(Ladehinweis.abgang, Ladeschirm.mindestens)
    }

    // MARK: - Die Größe

    /// **Zwei Stufen und nicht fünf.** Jede weitere wäre eine Behauptung über eine Stelle, die
    /// es noch nicht gibt.
    func testEsGibtZweiStufen() {
        XCTAssertEqual(Ladehinweis.Stufe.allCases.count, 2)
    }

    /// Die kleine Stufe ist die Ente des `Entenknopf`, die große das Doppelte.
    func testDieStufenSindDieEntenDiesesHauses() {
        XCTAssertEqual(Ladehinweis.Stufe.klein.kante, 38)
        XCTAssertEqual(Ladehinweis.Stufe.gross.kante, 2 * Ladehinweis.Stufe.klein.kante)
        // Und beide bleiben unter der kleinsten Kachel des Ladeschirms (150), damit die
        // Halbierung eine Halbierung bleibt.
        XCTAssertLessThan(Ladehinweis.Stufe.gross.kante, 150)
    }

    /// **Der Weg der Ente ist ein Zwölftel ihrer eigenen Kante** - in jeder Stufe derselbe
    /// Anteil, damit die große nicht heftiger schaukelt als die kleine, sondern nur weiter.
    func testDerWegIstEinZwoelftelDerEnte() {
        for stufe in Ladehinweis.Stufe.allCases {
            XCTAssertEqual(stufe.hubweite, stufe.kante / 12, accuracy: 0.001)
            // Groß genug, dass man von drei Metern sieht, dass sich etwas bewegt.
            XCTAssertGreaterThan(stufe.hubweite, 2)
        }
    }

    /// **Wo die Ente neben dem Satz steht, bleibt ihr Weg unter einem Viertel dessen Zeile.**
    /// Sonst zieht die Bewegung den Blick von dem Satz weg, der die eigentliche Auskunft ist.
    /// Für die große Stufe gilt das nicht - dort steht die Ente über dem Satz und nicht neben
    /// ihm, und keine Zeile liegt in ihrem Weg.
    func testNebenDemSatzBleibtDerWegUnterEinemViertelDerZeile() {
        let neben = Ladehinweis.Stufe.klein
        XCTAssertFalse(neben.untereinander)
        XCTAssertLessThan(neben.hubweite, neben.satzgroesse * 1.35 / 4)
    }

    /// Der Schein bleibt in der Karte: schmaler als die 2,6 Kanten des Ladeschirms, der auf
    /// einer leeren Fläche liegt.
    func testDerScheinBleibtInDerKarte() {
        for stufe in Ladehinweis.Stufe.allCases {
            XCTAssertLessThan(stufe.schein, stufe.kante * 2.6)
            XCTAssertGreaterThan(stufe.schein, stufe.kante)
        }
    }

    /// **Klein steht neben dem Satz, groß über ihm.** Die vier Hinweise der Datenprüfung
    /// stehen untereinander in einer Spalte; eine Ente darüber würde sie viermal unterbrechen.
    func testKleinStehtNebenDemSatzUndGrossDarueber() {
        XCTAssertFalse(Ladehinweis.Stufe.klein.untereinander)
        XCTAssertTrue(Ladehinweis.Stufe.gross.untereinander)
    }

    /// Der kleine Satz ist der Grad von `Leer` - genau der, der an diesen Stellen bis jetzt
    /// allein dastand -, der große der des Fließtextes.
    func testDieSchriftgradeSindDieDesHauses() {
        XCTAssertEqual(Ladehinweis.Stufe.klein.satzgroesse, 13)
        XCTAssertEqual(Ladehinweis.Stufe.gross.satzgroesse, 15)
    }

    /// **Zu jedem Grad die Kurve, auf der er in diesem Haus hängt.** 13 Punkte sind
    /// `Schrift.klein` auf `.footnote`, 15 Punkte sind `Schrift.text` auf `.body`. Ein Grad auf
    /// der fremden Kurve sieht bei der Vorgabe richtig aus und weicht erst ab, wenn jemand
    /// „Größerer Text“ stellt - also genau dann, wenn niemand mehr hinsieht.
    func testJederGradHaengtAnSeinerEigenenKurve() {
        XCTAssertEqual(Ladehinweis.Stufe.klein.satzbezug, .fussnote)
        XCTAssertEqual(Ladehinweis.Stufe.gross.satzbezug, .fliesstext)
        // Zwei Stufen, zwei Kurven: keine zwei Stufen teilen eine.
        XCTAssertEqual(
            Set(Ladehinweis.Stufe.allCases.map(\.satzbezug)).count,
            Ladehinweis.Stufe.allCases.count)
    }

    // MARK: - Der Satz bleibt

    /// Der Satz der dreizehn Auswertungsseiten, Zeichen für Zeichen der, der dort stand.
    func testDerBerichtssatzIstDerAlte() {
        XCTAssertEqual(Ladehinweis.berichtssatz, "Wird geholt …")
    }

    /// **Ein Bruchstück wird für die Stimme ein Satz.** „lädt …“ ist im Bild richtig - daneben
    /// steht der Kicker der Karte -, vorgelesen ist es ein Wort ohne Aussage.
    func testEinBruchstueckWirdEinSatz() {
        XCTAssertEqual(Ladehinweis.vorleser(satz: Pruefworte.laedt), Ladehinweis.ersatzsatz)
        XCTAssertEqual(Ladehinweis.vorleser(satz: "lädt"), "Wird geladen.")
        XCTAssertEqual(Ladehinweis.vorleser(satz: ""), Ladehinweis.ersatzsatz)
        XCTAssertEqual(Ladehinweis.vorleser(satz: " … "), Ladehinweis.ersatzsatz)
    }

    /// **Ein Satz bleibt sein Satz.** Was dasteht, wird vorgelesen - die Ente ersetzt kein
    /// Wort, sie kommt dazu.
    func testEinSatzBleibtSeinSatz() {
        XCTAssertEqual(Ladehinweis.vorleser(satz: Ladehinweis.berichtssatz), "Wird geholt.")
        XCTAssertEqual(
            Ladehinweis.vorleser(satz: Jahresraster.laedtSatz), "Jahr wird geladen.")
        XCTAssertEqual(
            Ladehinweis.vorleser(satz: "Die Wärmepumpe wird geladen …"),
            "Die Wärmepumpe wird geladen.")
    }

    /// Jeder Ladesatz dieses Hauses wird zu einem Satz, der mit einem Punkt endet und keine
    /// Auslassungspunkte mehr trägt - daran hängt, ob eine Stimme ihn senken kann.
    func testJederLadesatzDesHausesWirdZuEinemSatz() {
        let saetze = [
            Pruefworte.laedt, Ladehinweis.berichtssatz, Jahresraster.laedtSatz,
            Nachbetrachtungsworte.laedtSatz, Datenbestand.ladewort,
            "Die Wärmepumpe wird geladen …", "Die Anforderungen werden gesucht.",
        ]
        for satz in saetze {
            let vor = Ladehinweis.vorleser(satz: satz)
            XCTAssertTrue(vor.hasSuffix("."), vor)
            XCTAssertFalse(vor.contains("…"), vor)
            XCTAssertTrue(vor.first?.isUppercase ?? false, vor)
            // Doppelte Punkte macht niemand: ein Satz, der schon auf einem Punkt endet,
            // bekommt keinen zweiten.
            XCTAssertFalse(vor.hasSuffix(".."), vor)
        }
    }

    /// Der Ersatzsatz nennt kein Subjekt, und das ist Absicht: dieser Baustein steht in vier
    /// Karten, die alle etwas anderes holen.
    func testDerErsatzsatzErfindetKeinSubjekt() {
        XCTAssertEqual(Ladehinweis.ersatzsatz, "Wird geladen.")
        XCTAssertFalse(Ladehinweis.ersatzsatz.contains("Daten"))
    }
}
