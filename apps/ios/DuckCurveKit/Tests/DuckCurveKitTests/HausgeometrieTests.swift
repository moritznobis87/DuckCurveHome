import XCTest

@testable import DuckCurveKit

/// Das Rechnen fuer das Hausmodell.
///
/// Das ist der Teil des Glasmodells, der sich pruefen laesst - und genau deshalb liegt er hier
/// und nicht in einer Szene. Die Vorlage (`geometrie.ts`) hat dieselbe Trennung aus demselben
/// Grund gezogen.
final class HausgeometrieTests: XCTestCase {
    private typealias G = Hausgeometrie

    // MARK: - Intervalle

    func testVereinigtFasstUeberlappendeZusammen() {
        let aus = G.vereinigt([(0, 3), (2, 5), (7, 9)])
        XCTAssertEqual(aus.count, 2)
        XCTAssertEqual(aus[0].a, 0)
        XCTAssertEqual(aus[0].b, 5)
        XCTAssertEqual(aus[1].a, 7)
    }

    /// **Der Fall, um den es eigentlich geht.** Zwei Raeume teilen eine Wand, beide melden sie -
    /// und im Glas soll sie einmal stehen. Zwei anstossende Intervalle sind ein Intervall.
    func testAnstossendeIntervalleWerdenEines() {
        let aus = G.vereinigt([(0, 4), (4, 8)])
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].b, 8)
    }

    /// Ein Rundungsfehler von einem Zentimeter darf keine zweite Wand ergeben.
    func testFastAnstossendeAuch() {
        let aus = G.vereinigt([(0, 4), (4.01, 8)])
        XCTAssertEqual(aus.count, 1)
        // Zwei Dezimeter sind kein Rundungsfehler mehr, sondern eine Luecke.
        XCTAssertEqual(G.vereinigt([(0, 4), (4.2, 8)]).count, 2)
    }

    func testUnsortierteIntervalle() {
        let aus = G.vereinigt([(7, 9), (0, 3), (2, 5)])
        XCTAssertEqual(aus.count, 2)
        XCTAssertEqual(aus[0].a, 0)
    }

    func testOhneLueckenMachtAusEinerWandStuecke() {
        // Eine Wand von 0 bis 10 mit einer Tuer von 4 bis 5.
        let aus = G.ohneLuecken([(0, 10)], luecken: [(4, 5)])
        XCTAssertEqual(aus.count, 2)
        XCTAssertEqual(aus[0].b, 4)
        XCTAssertEqual(aus[1].a, 5)
    }

    func testMehrereTuerenInEinerWand() {
        let aus = G.ohneLuecken([(0, 10)], luecken: [(2, 3), (6, 7)])
        XCTAssertEqual(aus.count, 3)
        XCTAssertEqual(aus.map(\.a), [0, 3, 7])
    }

    /// Eine Tuer am Anfang der Wand ergibt kein Nullstueck davor.
    func testTuerAmRand() {
        let anfang = G.ohneLuecken([(0, 10)], luecken: [(0, 1)])
        XCTAssertEqual(anfang.count, 1)
        XCTAssertEqual(anfang[0].a, 1)
        let ende = G.ohneLuecken([(0, 10)], luecken: [(9, 10)])
        XCTAssertEqual(ende.count, 1)
        XCTAssertEqual(ende[0].b, 9)
    }

    /// Eine Tuer, die die ganze Wand einnimmt, laesst nichts stehen.
    func testTuerUeberDieGanzeWand() {
        XCTAssertTrue(G.ohneLuecken([(0, 10)], luecken: [(0, 10)]).isEmpty)
    }

    /// Eine Luecke ausserhalb der Wand lässt sie unberuehrt.
    func testLueckeDaneben() {
        let aus = G.ohneLuecken([(0, 10)], luecken: [(12, 14)])
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].b, 10)
    }

    func testUeberlappendeLuecken() {
        let aus = G.ohneLuecken([(0, 10)], luecken: [(3, 6), (5, 8)])
        XCTAssertEqual(aus.count, 2)
        XCTAssertEqual(aus[0].b, 3)
        XCTAssertEqual(aus[1].a, 8)
    }

    // MARK: - Aussen oder innen

    private func raum(_ x0: Double, _ z0: Double, _ x1: Double, _ z1: Double, ohneWaende: String? = nil) -> Room {
        Room(name: "Probe", x0: x0, z0: z0, x1: x1, z1: z1, noWalls: ohneWaende)
    }

    /// Ein quadratisches Haus von 0,0 bis 10,10.
    private let huelle: [[Double]] = [[0, 0], [10, 0], [10, 10], [0, 10]]

    func testEineRaumkanteAufDerAussenhaut() {
        let eckraum = raum(0, 0, 4, 4)
        XCTAssertTrue(G.istAussen(huelle: huelle, raum: eckraum, seite: .n), "z0 = 0 liegt auf der Haut")
        XCTAssertTrue(G.istAussen(huelle: huelle, raum: eckraum, seite: .w), "x0 = 0 liegt auf der Haut")
        XCTAssertFalse(G.istAussen(huelle: huelle, raum: eckraum, seite: .s), "z1 = 4 liegt innen")
        XCTAssertFalse(G.istAussen(huelle: huelle, raum: eckraum, seite: .o), "x1 = 4 liegt innen")
    }

    func testEinRaumGanzInnen() {
        let innen = raum(3, 3, 6, 6)
        for seite in G.seiten {
            XCTAssertFalse(G.istAussen(huelle: huelle, raum: innen, seite: seite))
        }
    }

    /// Eine Kante, die die Haut nur beruehrt, zaehlt nicht: 20 Zentimeter Ueberdeckung muss sie
    /// haben, sonst waere jede Ecke eine Aussenwand.
    func testEineKanteDieNurBeruehrt() {
        let schmal = raum(0, 0, 0.1, 4)
        XCTAssertFalse(G.istAussen(huelle: huelle, raum: schmal, seite: .n))
    }

    // MARK: - Wandstuecke eines Decks

    private func deck(_ raeume: [Room], waende: [WallLine] = [], luecken: [WallLine] = []) -> Deck {
        Deck(
            key: "eg", name: "Erdgeschoss", shell: huelle, rooms: raeume,
            walls: waende, gaps: luecken
        )
    }

    /// **Zwei Raeume, eine gemeinsame Wand.** Beide melden sie, im Glas steht sie einmal.
    func testEineGeteilteWandStehtNurEinmal() {
        let d = deck([raum(0, 0, 5, 10), raum(5, 0, 10, 10)])
        let stuecke = G.wandstuecke(d)
        // Die Wand bei x = 5 wird von beiden gemeldet - innen, ueber die ganze Tiefe.
        let geteilt = stuecke.filter { $0.senkrecht && abs($0.konst - 5) < 0.01 && !$0.aussen }
        XCTAssertEqual(geteilt.count, 1, "die geteilte Wand steht \(geteilt.count) Mal im Glas")
        XCTAssertEqual(geteilt[0].a, 0)
        XCTAssertEqual(geteilt[0].b, 10)
    }

    func testEineTuerSchneidetDieWandAuf() {
        let d = deck(
            [raum(0, 0, 5, 10), raum(5, 0, 10, 10)],
            luecken: [WallLine(x: 5, a: 4, b: 5)]
        )
        let geteilt = G.wandstuecke(d).filter { $0.senkrecht && abs($0.konst - 5) < 0.01 && !$0.aussen }
        XCTAssertEqual(geteilt.count, 2, "die Tuer muss die Wand aufteilen")
    }

    /// `noWalls` laesst eine Seite weg - ein offener Durchgang ohne Wand.
    func testOhneWaendeLaesstDieSeiteWeg() {
        let d = deck([raum(0, 0, 5, 10, ohneWaende: "o")])
        XCTAssertTrue(
            G.wandstuecke(d).allSatisfy { !($0.senkrecht && abs($0.konst - 5) < 0.01) },
            "die Ostwand war abgewaehlt und steht trotzdem da"
        )
    }

    func testZusatzwaendeKommenDazu() {
        let ohne = G.wandstuecke(deck([raum(0, 0, 10, 10)])).count
        let mit = G.wandstuecke(deck([raum(0, 0, 10, 10)], waende: [WallLine(z: 5, a: 0, b: 4)])).count
        XCTAssertEqual(mit, ohne + 1)
    }

    /// Die Reihenfolge der Wandstuecke muss bei gleichem Deck gleich bleiben - sonst sortiert
    /// sich die Zeichnung bei jedem Bild um, und durchscheinende Flaechen flackern.
    func testDieReihenfolgeIstStabil() {
        let d = deck([raum(0, 0, 5, 10), raum(5, 0, 10, 10), raum(0, 0, 10, 3)])
        let a = G.wandstuecke(d)
        let b = G.wandstuecke(d)
        XCTAssertEqual(a.count, b.count)
        for i in a.indices {
            XCTAssertEqual(a[i], b[i], "Wandstueck \(i) hat die Stelle gewechselt")
        }
    }

    // MARK: - Versatz und Umgrenzung

    /// Ein Quadrat um 1 nach aussen versetzt wird um 2 groesser - an jeder Ecke um die Summe
    /// der beiden Kantennormalen.
    func testVersetztWeitetEinQuadrat() {
        let aus = G.versetzt([[0, 0], [10, 0], [10, 10], [0, 10]], 1)
        XCTAssertEqual(aus.count, 4)
        let g = G.umgrenzung(aus.map { [$0.x, $0.y] })
        XCTAssertNotNil(g)
        XCTAssertEqual(g!.x1 - g!.x0, 12, accuracy: 1e-9)
        XCTAssertEqual(g!.z1 - g!.z0, 12, accuracy: 1e-9)
    }

    func testUmgrenzung() {
        let g = G.umgrenzung([[1, 2], [5, 3], [-1, 7]])
        XCTAssertEqual(g?.x0, -1)
        XCTAssertEqual(g?.x1, 5)
        XCTAssertEqual(g?.z0, 2)
        XCTAssertEqual(g?.z1, 7)
        XCTAssertNil(G.umgrenzung([]))
    }

    // MARK: - Projektion

    /// Ohne Drehung liegt der Grundriss rechtwinklig: x nach rechts, z nach oben (negativ).
    func testProjektionOhneDrehung() {
        let p = G.bildschirm(x: 3, y: 0, z: 4, drehung: 0)
        XCTAssertEqual(p.sx, 3, accuracy: 1e-9)
        XCTAssertEqual(p.su, -4, accuracy: 1e-9)
    }

    /// **Die Hoehe laeuft schraeg nach rechts oben.** Das ist die Kavalierprojektion: eine Wand
    /// zeigt zwei Seiten, und der Grundriss bleibt masstaeblich.
    func testHoeheLaeuftSchraegNachRechtsOben() {
        let unten = G.bildschirm(x: 0, y: 0, z: 0, drehung: 0)
        let oben = G.bildschirm(x: 0, y: 1, z: 0, drehung: 0)
        XCTAssertEqual(oben.sx - unten.sx, G.kX, accuracy: 1e-9)
        XCTAssertEqual(oben.su - unten.su, G.kY, accuracy: 1e-9)
        XCTAssertGreaterThan(G.kX, 0, "nach rechts")
        XCTAssertGreaterThan(G.kY, 0, "nach oben")
    }

    /// Der Grundriss bleibt bei jeder Drehung masstaeblich: eine Strecke in der Ebene behaelt
    /// ihre Laenge. Das unterscheidet die Kavalierprojektion von einer perspektivischen.
    func testDerGrundrissBleibtMasstaeblich() {
        for th in [0.0, 0.3, 0.7, 1.2, .pi / 2, .pi] {
            let a = G.bildschirm(x: 0, y: 0, z: 0, drehung: th)
            let b = G.bildschirm(x: 3, y: 0, z: 4, drehung: th)
            let laenge = hypot(b.sx - a.sx, b.su - a.su)
            XCTAssertEqual(laenge, 5, accuracy: 1e-9, "bei Drehung \(th)")
        }
    }

    /// Eine Drehung um 90 Grad vertauscht x und z.
    func testDrehungUmNeunzigGrad() {
        let p = G.bildschirm(x: 1, y: 0, z: 0, drehung: .pi / 2)
        XCTAssertEqual(p.sx, 0, accuracy: 1e-9)
        XCTAssertEqual(p.su, -1, accuracy: 1e-9)
    }

    func testStrahlIstEinEinheitsvektor() {
        for th in [0.0, 0.4, 1.1, .pi] {
            let s = G.strahl(drehung: th)
            let l = sqrt(s.0 * s.0 + s.1 * s.1 + s.2 * s.2)
            XCTAssertEqual(l, 1, accuracy: 1e-9, "bei Drehung \(th)")
        }
        // Der Strahl zeigt zum Betrachter, also nach oben: die mittlere Komponente ist positiv.
        XCTAssertGreaterThan(G.strahl(drehung: 0).1, 0)
    }

    // MARK: - Bodenfarbe

    /// Die Skala der Raeume ist eine andere als die des Wassers: ein Raum bei 21 °C ist
    /// angenehm, ein Heizungsvorlauf bei 21 °C ist kalt.
    func testBodenfarbeTrifftDieStopps() {
        XCTAssertEqual(G.bodenfarbe(15).hex, "#25506A")
        XCTAssertEqual(G.bodenfarbe(21).hex, "#6AB6C8")
        XCTAssertEqual(G.bodenfarbe(26).hex, "#FF7A45")
        // Unter und ueber der Skala wird nicht extrapoliert.
        XCTAssertEqual(G.bodenfarbe(-20).hex, G.bodenfarbe(15).hex)
        XCTAssertEqual(G.bodenfarbe(80).hex, G.bodenfarbe(26).hex)
    }

    func testBodenfarbeMischtZwischenDenStopps() {
        // Genau zwischen 19 und 21: die Mitte der beiden Farben.
        let mitte = G.bodenfarbe(20)
        let a = G.bodenfarbe(19)
        let b = G.bodenfarbe(21)
        XCTAssertEqual(mitte.rot, (a.rot + b.rot) / 2, accuracy: 1e-6)
        XCTAssertEqual(mitte.gruen, (a.gruen + b.gruen) / 2, accuracy: 1e-6)
    }

    /// Die Bodenskala ist **zweiseitig** und in der Helligkeit absichtlich nicht gleichsinnig.
    /// Nachgemessen (L\* und ΔE2000 zur Nachbarin):
    ///
    /// | | | L\* | ΔE zur Nachbarin |
    /// |---:|---|---:|---:|
    /// | 15 °C | #25506A | 32,2 | 14,9 |
    /// | 19 °C | #3D7A9C | 48,6 | 20,6 |
    /// | 21 °C | #6AB6C8 | 70,0 | 41,0 |
    /// | 22,5 °C | #C8902F | 63,7 | 10,3 |
    /// | 24 °C | #F2B134 | 76,4 | 24,5 |
    /// | 26 °C | #FF7A45 | 66,2 | – |
    ///
    /// Zwei Dinge sind daran Absicht. Bei 22,5 °C **kippt** die Skala von Cyan auf Amber und
    /// wird dabei dunkler: das ist der Umschlag von „kuehl" nach „warm", und er soll zu sehen
    /// sein. Und die hellste Stufe ist 24 °C, nicht 26 °C - ganz warm wird wieder dunkler, damit
    /// „zu warm" sich von „angenehm warm" unterscheidet.
    ///
    /// Zu pruefen ist darum nicht ein Verlauf, sondern dass jede Stufe von ihrer Nachbarin zu
    /// unterscheiden ist und die Enden weit auseinanderliegen.
    func testBodenskalaIstZweiseitigUndLesbar() {
        let stopps = G.temperaturstopps
        for i in 1..<stopps.count {
            let d = stopps[i - 1].farbe.abstand(zu: stopps[i].farbe)
            XCTAssertGreaterThan(d, 10.0, "Stufe \(i - 1) und \(i) der Bodenskala: nur ΔE2000 \(d)")
        }
        // Die Enden: kaltes Blau gegen warmes Orange.
        XCTAssertEqual(stopps.first!.farbe.abstand(zu: stopps.last!.farbe), 54.7, accuracy: 0.5)
        // Die hellste Stufe ist 24 °C.
        let hell = stopps.map(\.farbe.lab.l)
        XCTAssertEqual(hell.firstIndex(of: hell.max()!), 4)
        // Und der Umschlag bei 22,5 °C ist der engste Schritt der Skala.
        let abstaende = (1..<stopps.count).map { stopps[$0 - 1].farbe.abstand(zu: stopps[$0].farbe) }
        XCTAssertEqual(abstaende.firstIndex(of: abstaende.min()!), 3)
    }

    func testWandlinie() {
        XCTAssertEqual(G.wandlinie(WallLine(x: 5, a: 0, b: 4)).senkrecht, true)
        XCTAssertEqual(G.wandlinie(WallLine(x: 5, a: 0, b: 4)).konst, 5)
        XCTAssertEqual(G.wandlinie(WallLine(z: 3, a: 0, b: 4)).senkrecht, false)
        XCTAssertEqual(G.wandlinie(WallLine(z: 3, a: 0, b: 4)).konst, 3)
    }

    // MARK: - Koerper

    func testEinQuaderZeigtDenDeckelUndHoechstensZweiSeiten() {
        let f = Hausgeometrie.quader(
            x: 3, y: 0, z: 2, b: 1, hoehe: 0.8, t: 0.6, drehung: 0.62)
        XCTAssertEqual(f.filter(\.obenauf).count, 1, "Genau ein Deckel.")
        XCTAssertLessThanOrEqual(f.count, 3, "Von einem Quader sieht man hoechstens drei Seiten.")
        XCTAssertGreaterThanOrEqual(f.count, 2)
    }

    func testDieFlaechenKommenVonHintenNachVorn() {
        let f = Hausgeometrie.quader(
            x: 0, y: 0, z: 0, b: 2, hoehe: 1, t: 2, drehung: 0.4)
        let tiefen = f.map(\.tiefe)
        XCTAssertEqual(tiefen, tiefen.sorted(), "Sonst malt der Spaetere den Frueheren zu.")
    }

    func testDerDeckelIstDasHellsteUndJedeSeiteDunkler() {
        let f = Hausgeometrie.quader(
            x: 0, y: 0, z: 0, b: 1, hoehe: 1, t: 1, drehung: 0.62)
        let deckel = f.first { $0.obenauf }!
        XCTAssertEqual(deckel.licht, 1)
        for seite in f where !seite.obenauf {
            XCTAssertLessThan(seite.licht, 1)
            XCTAssertGreaterThan(seite.licht, 0)
        }
    }

    func testEinKoerperOhneHoeheHatNurSeinenDeckel() {
        let f = Hausgeometrie.quader(x: 0, y: 0, z: 0, b: 2, hoehe: 0, t: 2, drehung: 0.62)
        XCTAssertEqual(f.filter(\.obenauf).count, 1)
        XCTAssertTrue(
            f.filter { !$0.obenauf }.allSatisfy { seite in
                let hoehen = Set(seite.ecken.map(\.y))
                return hoehen.count == 1
            }, "Eine Seite ohne Hoehe ist eine Linie und keine Flaeche.")
    }

    func testDerDeckelLiegtAufDerAngegebenenHoehe() {
        let f = Hausgeometrie.quader(
            x: 1, y: 2.6, z: 1, b: 1, hoehe: 0.4, t: 1, drehung: 0)
        let deckel = f.first { $0.obenauf }!
        XCTAssertTrue(deckel.ecken.allSatisfy { abs($0.y - 3.0) < 1e-9 })
    }

    func testEinGedrehterQuaderBehaeltSeineGrundflaeche() {
        let gerade = Hausgeometrie.quader(
            x: 0, y: 0, z: 0, b: 2, hoehe: 1, t: 1, drehung: 0, winkel: 0)
        let schraeg = Hausgeometrie.quader(
            x: 0, y: 0, z: 0, b: 2, hoehe: 1, t: 1, drehung: 0, winkel: .pi / 4)
        func flaeche(_ e: [(x: Double, y: Double, z: Double)]) -> Double {
            var s = 0.0
            for i in e.indices {
                let a = e[i], b = e[(i + 1) % e.count]
                s += a.x * b.z - b.x * a.z
            }
            return abs(s) / 2
        }
        XCTAssertEqual(
            flaeche(gerade.first { $0.obenauf }!.ecken),
            flaeche(schraeg.first { $0.obenauf }!.ecken), accuracy: 1e-9)
    }

    func testEinZylinderHatSoVieleSeitenWieEckenSichtbarSind() {
        let f = Hausgeometrie.zylinder(
            x: 0, y: 0, z: 0, halbmesser: 0.5, hoehe: 1, drehung: 0.62, ecken: 12)
        XCTAssertEqual(f.filter(\.obenauf).count, 1)
        // Von zwoelf Seiten ist etwa die Haelfte zugewandt.
        let seiten = f.filter { !$0.obenauf }.count
        XCTAssertGreaterThan(seiten, 3)
        XCTAssertLessThan(seiten, 9)
    }

    func testEinGrundrissMitWenigerAlsDreiEckenIstKeinKoerper() {
        XCTAssertTrue(
            Hausgeometrie.prisma(
                grundriss: [(0, 0), (1, 1)], y: 0, hoehe: 1, drehung: 0).isEmpty)
    }

    // MARK: - Treffer

    func testDrinnenUndDraussen() {
        let quadrat = [(x: 0.0, y: 0.0), (x: 4.0, y: 0.0), (x: 4.0, y: 4.0), (x: 0.0, y: 4.0)]
        XCTAssertTrue(Hausgeometrie.imVieleck((x: 2, y: 2), quadrat))
        XCTAssertFalse(Hausgeometrie.imVieleck((x: 5, y: 2), quadrat))
        XCTAssertFalse(Hausgeometrie.imVieleck((x: 2, y: -1), quadrat))
    }

    /// **Ein schiefes Viereck, und genau darum geht es.** Auf dem Schirm ist ein Raum kein
    /// Rechteck mehr: jede Ecke geht einzeln durch die Projektion. Ein Rechteckvergleich träfe
    /// daneben, sobald das Haus gedreht ist - und gedreht ist es immer.
    func testEinSchiefesViereck() {
        let schief = [(x: 0.0, y: 0.0), (x: 6.0, y: 2.0), (x: 5.0, y: 6.0), (x: -1.0, y: 4.0)]
        XCTAssertTrue(Hausgeometrie.imVieleck((x: 2.5, y: 3), schief))
        // Rechts aussen, aber innerhalb des umschliessenden Rechtecks.
        XCTAssertFalse(Hausgeometrie.imVieleck((x: 5.8, y: 5.5), schief))
    }

    func testZuWenigEckenTrifftNie() {
        XCTAssertFalse(Hausgeometrie.imVieleck((x: 0, y: 0), []))
        XCTAssertFalse(Hausgeometrie.imVieleck((x: 0, y: 0), [(x: 0.0, y: 0.0), (x: 1.0, y: 1.0)]))
    }
}
