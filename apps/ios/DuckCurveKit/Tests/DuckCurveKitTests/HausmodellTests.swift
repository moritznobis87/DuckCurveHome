import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/house/HouseScene.ts`, Zeilen 769–1030.
final class HausmodellTests: XCTestCase {

    private func item(
        _ kind: ItemKindWahl, x: Double = 0, z: Double = 0, y: Double? = nil,
        b: Double? = nil, t: Double? = nil, h: Double? = nil, r: Double? = nil,
        x0: Double? = nil, z0: Double? = nil, x1: Double? = nil, z1: Double? = nil,
        y1: Double? = nil, steps: Int? = nil, head: ItemHeadWahl? = nil,
        dir: ItemDirWahl? = nil, angle: Double? = nil, tone: ItemToneWahl? = nil,
        punkte: [[Double]]? = nil
    ) -> Item {
        Item(
            kind: kind, tone: tone, x: x, z: z, y: y, b: b, t: t, h: h, r: r, x0: x0, z0: z0,
            x1: x1, z1: z1, y1: y1, steps: steps, head: head, dir: dir, angle: angle,
            points: punkte)
    }

    private func quadermasse(_ teil: Hausmodell.Teil) -> (b: Double, h: Double, t: Double)? {
        guard case .quader(let b, let h, let t, _) = teil.form else { return nil }
        return (b, h, t)
    }

    // MARK: - Die einfachen Körper

    func testEinKastenNimmtSeineMasseUndStehtAufDerBodenplatte() {
        let teile = Hausmodell.teile(item(.box, x: 2, z: 3, b: 1.2, t: 0.8, h: 0.6))
        XCTAssertEqual(teile.count, 1)
        let m = quadermasse(teile[0])!
        XCTAssertEqual(m.b, 1.2)
        XCTAssertEqual(m.h, 0.6)
        XCTAssertEqual(m.t, 0.8)
        XCTAssertEqual(
            teile[0].y, Hausmodell.bodenDicke,
            "Moebel stehen auf der Bodenplatte, nicht im Estrich.")
    }

    func testOhneMasseGeltenDieVorgabenDerVorlage() {
        let m = quadermasse(Hausmodell.teile(item(.box))[0])!
        XCTAssertEqual(m.b, 0.6)
        XCTAssertEqual(m.h, 0.5)
        XCTAssertEqual(m.t, 0.6)
    }

    func testEinStuhlHatFesteMasseUndIgnoriertBreiteUndTiefe() {
        let teile = Hausmodell.teile(item(.chair, b: 99, t: 99))
        guard case .zylinder(let r, let h) = teile[0].form else { return XCTFail("kein Zylinder") }
        XCTAssertEqual(r, 0.19)
        XCTAssertEqual(h, 0.44)
    }

    func testEinePflanzeHatIhreEigeneFarbeUndNimmtKeinenTon() {
        let gruen = Hausmodell.teile(item(.plant, tone: .water))[0].farbe
        XCTAssertEqual(gruen.hex, "#3F8F6C", "Der Ton wird bei Pflanzen nicht gelesen.")
    }

    // MARK: - Das Bett

    func testEinBettSindMatratzeDeckeUndKopfteil() {
        let teile = Hausmodell.teile(item(.bed, x: 1, z: 2, b: 1.6, t: 2.0, head: .n))
        XCTAssertEqual(teile.count, 3)
        let matratze = quadermasse(teile[0])!
        XCTAssertEqual(matratze.b, 1.6)
        XCTAssertEqual(matratze.h, 0.42)
        let decke = quadermasse(teile[1])!
        XCTAssertEqual(decke.b, 1.4, accuracy: 1e-9, "b - 0,2 bei Kopf im Norden.")
        XCTAssertEqual(decke.t, 1.5, accuracy: 1e-9, "t - 0,5.")
        XCTAssertEqual(teile[1].y, Hausmodell.bodenDicke + 0.42, "Die Decke liegt auf.")
        XCTAssertEqual(teile[1].z, 2 + 0.18, "Vom Kopfteil weg.")
        let kopf = quadermasse(teile[2])!
        XCTAssertEqual(kopf.h, 0.8)
        XCTAssertEqual(teile[2].z, 2 - 1.0 + 0.05, "Am Kopfende.")
    }

    func testDasKopfteilWandertMitSeinerHimmelsrichtung() {
        for (richtung, erwartet) in [
            (ItemHeadWahl.s, 2 + 1.0 - 0.05), (.n, 2 - 1.0 + 0.05),
        ] {
            let teile = Hausmodell.teile(item(.bed, x: 1, z: 2, head: richtung))
            XCTAssertEqual(teile[2].z, erwartet, accuracy: 1e-9, "\(richtung)")
        }
        let west = Hausmodell.teile(item(.bed, x: 1, z: 2, head: .w))
        XCTAssertEqual(west[2].x, 1 - 0.8 + 0.05, accuracy: 1e-9)
        let masse = quadermasse(west[2])!
        XCTAssertEqual(masse.b, 0.1, "Quer gestellt ist das Kopfteil duenn in x.")
    }

    // MARK: - Die Treppe

    func testEineTreppeHatSoVieleStufenWieAngegebenUndSteigt() {
        let teile = Hausmodell.teile(
            item(.flight, y: 0, b: 1, x0: 0, z0: 0, x1: 0, z1: 3, y1: 2.8, steps: 7))
        XCTAssertEqual(teile.count, 7)
        let hoehen = teile.compactMap { quadermasse($0)?.h }
        XCTAssertEqual(hoehen, hoehen.sorted(), "Jede Stufe reicht hoeher als die davor.")
        XCTAssertEqual(hoehen.last!, 2.8, accuracy: 1e-9, "Die letzte endet oben.")
        XCTAssertTrue(
            teile.allSatisfy { $0.y == Hausmodell.bodenDicke },
            "Jede Stufe ist ein Block vom Fuss des Laufs - so wird die Treppe ein Koerper.")
    }

    func testEineTreppeOhneEckenWirdNichtGeraten() {
        XCTAssertTrue(Hausmodell.teile(item(.flight, steps: 8)).isEmpty)
    }

    func testEineLeiterHatImmerFuenfSprossen() {
        let teile = Hausmodell.teile(item(.ladder, x0: 0, z0: 0, x1: 0, z1: 1, steps: 12))
        XCTAssertEqual(teile.count, 5, "`steps` gilt bei der Leiter nicht.")
        let hoehen = teile.map(\.y)
        XCTAssertEqual(hoehen[1] - hoehen[0], 0.11, accuracy: 1e-9)
    }

    // MARK: - Die Geräte

    func testDieWaermepumpeStehtAufDemGelaendeUndNichtAufEinerBodenplatte() {
        let teile = Hausmodell.teile(item(.heatPump, x: 5, z: 5, dir: .n))
        XCTAssertEqual(teile[0].y, 0, "Sie steht draussen.")
        let m = quadermasse(teile[0])!
        XCTAssertEqual(m.b, 1.6)
        XCTAssertEqual(m.h, 1.35)
        XCTAssertEqual(m.t, 0.75)
    }

    func testDieWaermepumpeDrehtSichMitIhrerBlasrichtung() {
        let laengs = quadermasse(Hausmodell.teile(item(.heatPump, dir: .n))[0])!
        let quer = quadermasse(Hausmodell.teile(item(.heatPump, dir: .o))[0])!
        XCTAssertEqual(laengs.b, quer.t)
        XCTAssertEqual(laengs.t, quer.b)
    }

    func testDerPufferHatVierSchichten() {
        let teile = Hausmodell.teile(item(.buffer, x: 1, z: 1))
        XCTAssertEqual(teile.count, 4)
        let hoehen = teile.map(\.y)
        XCTAssertEqual(hoehen.first!, Hausmodell.bodenDicke)
        XCTAssertEqual(hoehen.last! + 0.6, Hausmodell.bodenDicke + 2.4, accuracy: 1e-9)
    }

    func testDieWallboxHaengtAnDerWandUndHatEinLaempchen() {
        let teile = Hausmodell.teile(item(.wallbox, x: 2, z: 2, y: 0))
        XCTAssertEqual(teile[0].y, Hausmodell.bodenDicke + 0.45)
        XCTAssertTrue(teile.contains { $0.leuchtet }, "Das Laempchen leuchtet.")
    }

    func testEinKabelEntstehtNurMitZiel() {
        XCTAssertEqual(Hausmodell.teile(item(.wallbox)).count, 2)
        let mitKabel = Hausmodell.teile(item(.wallbox, x1: 5, z1: 5))
        XCTAssertEqual(mitKabel.count, 3)
        if case .linien(let zuege) = mitKabel[2].form {
            XCTAssertEqual(zuege[0].count, 3, "Anfang, Durchhang, Ende.")
        } else {
            XCTFail("kein Linienzug")
        }
    }

    // MARK: - Gelände

    func testEineGartenmauerStehtAufDemGelaendeUndNichtAufEinerPlatte() {
        let teile = Hausmodell.teile(item(.wall, x: 0, z: 0, y: 0))
        XCTAssertEqual(teile[0].y, 0, "Eine Mauer hat keine Bodenplatte unter sich.")
    }

    func testEinBelagLiegtFlachAmBoden() {
        let teile = Hausmodell.teile(item(.ground, b: 6, t: 4, tone: .terrace))
        XCTAssertEqual(teile[0].y, 0.005)
        XCTAssertEqual(teile[0].farbe.hex, "#134052")
        XCTAssertEqual(teile[0].farbe.deckung, 1, "Gelaende ist kein Glas.")
    }

    func testEinTorIstNurLinienUndKeineFlaeche() {
        let teile = Hausmodell.teile(item(.gate, x: 0, h: 0.85, x0: 0, z0: 0, x1: 3, z1: 0))
        XCTAssertEqual(teile.count, 1)
        guard case .linien(let zuege) = teile[0].form else { return XCTFail("keine Linien") }
        XCTAssertEqual(zuege[0].count, 4, "Der Umriss.")
        XCTAssertGreaterThan(zuege.count, 1, "Dazu die Fuellstaebe.")
    }

    func testEinBaumIstScheibeStammUndKrone() {
        let teile = Hausmodell.teile(item(.tree, x: 1, z: 1, b: 2, h: 2.2, r: 1.3))
        XCTAssertEqual(teile.count, 3)
        guard case .zylinder(let stammR, let stammH) = teile[1].form else {
            return XCTFail("kein Stamm")
        }
        XCTAssertEqual(stammR, 0.07, "Der Stamm ist immer gleich duenn.")
        XCTAssertEqual(stammH, 2.2)
        XCTAssertEqual(teile[2].y, 2.2, "Die Krone sitzt oben auf dem Stamm.")
    }

    // MARK: - Was nicht gezeichnet wird

    func testEineUnbekannteArtWirdNichtGeraten() {
        XCTAssertTrue(Hausmodell.teile(item(.unbekannt)).isEmpty)
    }

    func testEinRohrBrauchtZweiPunkte() {
        XCTAssertTrue(Hausmodell.teile(item(.pipe, punkte: [[0, 0, 0]])).isEmpty)
        XCTAssertFalse(Hausmodell.teile(item(.pipe, punkte: [[0, 0, 0], [1, 1, 1]])).isEmpty)
    }

    // MARK: - Die Bodenfarbe

    private func raum(kalt: Bool = false) -> Room {
        Room(name: "Test", x0: 0, z0: 0, x1: 4, z1: 4, cold: kalt)
    }

    func testEinRaumMitMessungLeuchtetFastUngedaempft() {
        let mit = Hausmodell.bodenfarbe(raum(), grad: 21)
        let roh = Hausgeometrie.bodenfarbe(21)
        XCTAssertEqual(mit.rot, roh.rot, accuracy: 0.12, "Nur um ein Zehntel abgedunkelt.")
    }

    func testEinKalterRaumWirdStarkAbgedunkelt() {
        let kalt = Hausmodell.bodenfarbe(raum(kalt: true), grad: 21)
        let warm = Hausmodell.bodenfarbe(raum(), grad: 21)
        XCTAssertLessThan(
            kalt.rot + kalt.gruen + kalt.blau, warm.rot + warm.gruen + warm.blau,
            "Kalt heisst dunkler, nicht anders gefaerbt.")
    }

    func testOhneMessungGibtEsEinenGrundton() {
        let ohne = Hausmodell.bodenfarbe(raum(), grad: nil)
        XCTAssertGreaterThan(ohne.rot + ohne.gruen + ohne.blau, 0)
        XCTAssertNotEqual(ohne.hex, Hausmodell.bodenfarbe(raum(), grad: 24).hex)
    }

    func testDieToenePassenZurVorlage() {
        XCTAssertEqual(Hausmodell.ton(.dark).hex, "#0F3243")
        XCTAssertEqual(Hausmodell.ton(.dark).deckung, 0.66)
        XCTAssertEqual(Hausmodell.ton(.water).hex, "#7FD3E6")
        XCTAssertEqual(Hausmodell.ton(.paving).deckung, 1, "Belag ist deckend.")
        XCTAssertEqual(
            Hausmodell.ton(nil).hex, "#0F3243", "Ohne Angabe der dunkle Ton, wie in der Vorlage.")
    }
}

/// Der Fussboden: die Heizschlange und die Fliesen.
final class FussbodenTests: XCTestCase {
    // MARK: - Die Heizschlange

    /// **Eine Schlange, kein Kamm.** Das Rohr hat einen Anfang und ein Ende; zwischen zwei
    /// Bahnen reisst es nicht ab.
    func testDerWegHaengtZusammen() {
        let weg = Hausmodell.heizschlange(x0: 0, z0: 0, x1: 4, z1: 3)
        XCTAssertGreaterThanOrEqual(weg.count, 4)
        // Je zwei Punkte eine Bahn; zwischen zwei Bahnen wechselt nur die Tiefe.
        for i in stride(from: 1, to: weg.count - 1, by: 2) {
            XCTAssertEqual(weg[i].x, weg[i + 1].x, accuracy: 0.001, "der Bogen laeuft senkrecht")
        }
    }

    /// Hin und zurück: jede zweite Bahn läuft andersherum.
    func testJedeZweiteBahnLaeuftZurueck() {
        let weg = Hausmodell.heizschlange(x0: 0, z0: 0, x1: 4, z1: 3)
        XCTAssertLessThan(weg[0].x, weg[1].x, "die erste Bahn nach rechts")
        XCTAssertGreaterThan(weg[2].x, weg[3].x, "die zweite zurueck")
    }

    /// Der Rand bleibt frei, und zwar auf allen vier Seiten.
    func testDerRandBleibtFrei() {
        let weg = Hausmodell.heizschlange(x0: 1, z0: 2, x1: 5, z1: 6)
        for p in weg {
            XCTAssertGreaterThanOrEqual(p.x, 1.29)
            XCTAssertLessThanOrEqual(p.x, 4.71)
            XCTAssertGreaterThanOrEqual(p.z, 2.29)
            XCTAssertLessThanOrEqual(p.z, 5.71)
        }
    }

    /// Ein Raum, in den keine Schlange passt, bekommt keine - statt einer entarteten.
    func testEinZuKleinerRaumBekommtKeine() {
        XCTAssertTrue(Hausmodell.heizschlange(x0: 0, z0: 0, x1: 0.5, z1: 3).isEmpty)
        XCTAssertTrue(Hausmodell.heizschlange(x0: 0, z0: 0, x1: 3, z1: 0.5).isEmpty)
    }

    /// Ein tieferer Raum bekommt mehr Bahnen, rund eine je halben Meter.
    func testMehrTiefeMehrBahnen() {
        let flach = Hausmodell.heizschlange(x0: 0, z0: 0, x1: 4, z1: 2).count
        let tief = Hausmodell.heizschlange(x0: 0, z0: 0, x1: 4, z1: 6).count
        XCTAssertGreaterThan(tief, flach)
        XCTAssertGreaterThanOrEqual(flach, 4, "mindestens zwei Bahnen")
    }

    // MARK: - Die Glut

    /// **Ein geschlossenes Ventil leuchtet nicht.** Das ist die ganze Auskunft des Bildes:
    /// wo gerade geheizt wird.
    func testZuIstDunkel() {
        XCTAssertEqual(Hausmodell.heizglut(ventil: 0, takt: 0, versatz: 0), 0)
        XCTAssertEqual(Hausmodell.heizglut(ventil: nil, takt: 0, versatz: 0), 0)
    }

    func testMehrVentilMehrGlut() {
        let wenig = Hausmodell.heizglut(ventil: 0.25, takt: 0, versatz: 0)
        let viel = Hausmodell.heizglut(ventil: 1, takt: 0, versatz: 0)
        XCTAssertGreaterThan(viel, wenig)
        XCTAssertGreaterThan(wenig, 0)
        XCTAssertLessThanOrEqual(viel, 1)
    }

    /// Es atmet, und nicht das ganze Haus im Gleichtakt.
    func testEsAtmetUndVersetzt() {
        let a = Hausmodell.heizglut(ventil: 1, takt: 0, versatz: 0)
        let b = Hausmodell.heizglut(ventil: 1, takt: 1.1, versatz: 0)
        XCTAssertNotEqual(a, b, accuracy: 0.0001)
        XCTAssertNotEqual(
            Hausmodell.heizglut(ventil: 1, takt: 0.5, versatz: 0),
            Hausmodell.heizglut(ventil: 1, takt: 0.5, versatz: 2.3), accuracy: 0.0001)
    }

    // MARK: - Die Fliesen

    /// Ein Schachbrett: zwei Töne, abwechselnd, und beide kommen vor.
    func testZweiToeneAbwechselnd() {
        let f = Hausmodell.fliesen(x0: 0, z0: 0, x1: 4, z1: 4)
        XCTAssertFalse(f.isEmpty)
        XCTAssertTrue(f.contains { $0.hell })
        XCTAssertTrue(f.contains { !$0.hell })
    }

    /// Keine Fliese liegt ausserhalb ihres Raums - sonst stehen sie auf der Wand.
    func testKeineFlieseLiegtDraussen() {
        let f = Hausmodell.fliesen(x0: 1, z0: 2, x1: 5, z1: 7)
        for k in f {
            XCTAssertGreaterThanOrEqual(k.x, 1.05)
            XCTAssertLessThanOrEqual(k.x, 4.95)
            XCTAssertGreaterThanOrEqual(k.z, 2.05)
            XCTAssertLessThanOrEqual(k.z, 6.95)
        }
    }

    func testEinWinzigerRaumBekommtKeine() {
        XCTAssertTrue(Hausmodell.fliesen(x0: 0, z0: 0, x1: 0.1, z1: 0.1).isEmpty)
    }
}
