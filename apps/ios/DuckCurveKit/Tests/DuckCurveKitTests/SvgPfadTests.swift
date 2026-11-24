import XCTest

@testable import DuckCurveKit

/// Der Leser fuer SVG-Pfadangaben.
///
/// Der letzte Test ist der wichtigste: er schickt alle Pfade der Zeichen durch den Leser.
/// Damit ist nachgewiesen, dass die uebernommenen Zeichnungen des Dashboards in der App
/// ueberhaupt gezeichnet werden koennen - und zwar auf dem Pruefrechner, lange bevor Xcode sie
/// zu sehen bekommt.
final class SvgPfadTests: XCTestCase {
    func testAnfangUndLinie() throws {
        let s = try SvgPfad.lies("M 1 2 L 3 4")
        XCTAssertEqual(s, [.anfang(Punkt(1, 2)), .linie(Punkt(3, 4))])
    }

    /// Kommata statt Leerzeichen, und keine Leerzeichen um das Minus: beide Formen kommen in
    /// handgesetzten Pfaden vor.
    func testTrennzeichen() throws {
        XCTAssertEqual(
            try SvgPfad.lies("M1,2L3,4"),
            [.anfang(Punkt(1, 2)), .linie(Punkt(3, 4))]
        )
        // Gleitkomma: 2,5 − 2,3 ist nicht genau 0,2. Verglichen wird mit Toleranz.
        let senkrecht = try SvgPfad.lies("M 12 2.5v-2.3")
        guard case .linie(let p) = senkrecht[1] else { return XCTFail("eine Linie erwartet") }
        XCTAssertEqual(p.x, 12)
        XCTAssertEqual(p.y, 0.2, accuracy: 1e-9)
        XCTAssertEqual(
            try SvgPfad.lies("M3.5 11.2 12 4"),
            [.anfang(Punkt(3.5, 11.2)), .linie(Punkt(12, 4))]
        )
    }

    /// **Die Regel, an der ein naiver Leser scheitert.** Nach einem `M` ohne Buchstaben ist die
    /// naechste Zahlenpaar eine *Linie*, kein zweites Anheben des Stifts. `home` im Dashboard
    /// faengt genau so an: `M3.5 11.2 12 4l8.5 7.2`.
    func testBefehlswiederholungNachM() throws {
        let s = try SvgPfad.lies("M 1 1 2 2 3 3")
        XCTAssertEqual(s, [.anfang(Punkt(1, 1)), .linie(Punkt(2, 2)), .linie(Punkt(3, 3))])
    }

    func testBefehlswiederholungBeiKurven() throws {
        let s = try SvgPfad.lies("M0 0 C 1 1 2 2 3 3 4 4 5 5 6 6")
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s[2], .kurve(griff1: Punkt(4, 4), griff2: Punkt(5, 5), nach: Punkt(6, 6)))
    }

    func testRelativeBefehle() throws {
        let s = try SvgPfad.lies("m 10 10 l 5 0 l 0 5 z")
        XCTAssertEqual(
            s,
            [.anfang(Punkt(10, 10)), .linie(Punkt(15, 10)), .linie(Punkt(15, 15)), .schluss]
        )
    }

    func testWaagrechtUndSenkrecht() throws {
        let s = try SvgPfad.lies("M 4 10.4 h 10 M 4 13.6 h 10")
        XCTAssertEqual(
            s,
            [
                .anfang(Punkt(4, 10.4)), .linie(Punkt(14, 10.4)),
                .anfang(Punkt(4, 13.6)), .linie(Punkt(14, 13.6)),
            ]
        )
        XCTAssertEqual(try SvgPfad.lies("M 5 5 V 10"), [.anfang(Punkt(5, 5)), .linie(Punkt(5, 10))])
    }

    /// `Z` fuehrt zurueck zum Anfang des Unterpfads, nicht zum Nullpunkt. Danach weiterzuzeichnen
    /// muss dort beginnen.
    func testSchlussFuehrtZumAnfangZurueck() throws {
        let s = try SvgPfad.lies("M 5 5 L 9 5 Z l 0 3")
        XCTAssertEqual(s.last, .linie(Punkt(5, 8)))
    }

    /// `S` spiegelt den letzten Griff am Stift.
    func testGespiegelterGriff() throws {
        let s = try SvgPfad.lies("M 0 0 C 1 1 2 2 3 3 S 5 5 6 6")
        guard case .kurve(let g1, let g2, let nach) = s[2] else {
            return XCTFail("eine Kurve erwartet")
        }
        // Der letzte Griff war (2,2), der Stift steht auf (3,3): gespiegelt ergibt (4,4).
        XCTAssertEqual(g1, Punkt(4, 4))
        XCTAssertEqual(g2, Punkt(5, 5))
        XCTAssertEqual(nach, Punkt(6, 6))
    }

    /// Ohne vorige Kurve liegt der gespiegelte Griff auf dem Stift - so steht es in der
    /// Spezifikation, und ein geratener Griff waere eine erfundene Kurve.
    func testGespiegelterGriffOhneVorigeKurve() throws {
        let s = try SvgPfad.lies("M 2 2 S 5 5 6 6")
        guard case .kurve(let g1, _, _) = s[1] else { return XCTFail("eine Kurve erwartet") }
        XCTAssertEqual(g1, Punkt(2, 2))
    }

    func testQuadratischeKurve() throws {
        let s = try SvgPfad.lies("M 0 0 Q 1 1 2 0 T 4 0")
        XCTAssertEqual(s[1], .kurveKurz(griff: Punkt(1, 1), nach: Punkt(2, 0)))
        // `T` spiegelt (1,1) am Stift (2,0) zu (3,-1).
        XCTAssertEqual(s[2], .kurveKurz(griff: Punkt(3, -1), nach: Punkt(4, 0)))
    }

    func testZehnerpotenz() throws {
        let s = try SvgPfad.lies("M 1e2 2.5e-1 L 3 4")
        XCTAssertEqual(s.first, .anfang(Punkt(100, 0.25)))
    }

    /// Ein `e`, das kein Exponent ist, darf die Zahl nicht verschlucken.
    func testEinEOhneExponentIstEinBefehl() throws {
        // `5e` gefolgt von nichts Zaehlbarem: die Zahl ist 5, das `e` ein unbekannter Befehl.
        XCTAssertThrowsError(try SvgPfad.lies("M 1 5e L 2 2")) { fehler in
            XCTAssertEqual(fehler as? SvgPfad.Fehler, .unbekannterBefehl("e"))
        }
    }

    // MARK: - Boegen

    /// Ein Halbkreis von (0,0) nach (10,0) mit Radius 5: der Bogen muss auf 5 Punkte Hoehe
    /// kommen und genau im Ziel enden.
    func testHalbkreis() throws {
        let s = try SvgPfad.lies("M 0 0 A 5 5 0 0 1 10 0")
        XCTAssertEqual(s.count, 3, "ein Halbkreis wird in zwei Viertel zerlegt")
        guard case .kurve(_, _, let ziel) = s.last else { return XCTFail("eine Kurve erwartet") }
        XCTAssertEqual(ziel.x, 10, accuracy: 1e-9, "der Bogen muss genau im Ziel enden")
        XCTAssertEqual(ziel.y, 0, accuracy: 1e-9)
        let r = SvgPfad.rahmen(s)!
        // `sweep = 1` heisst „in Richtung wachsender Winkel". In SVG zeigt die y-Achse nach
        // unten, auf dem Bildschirm ist das im Uhrzeigersinn - und von links nach rechts geht
        // das ueber den Scheitel, also nach oben (negatives y). Wer hier das Vorzeichen
        // verwechselt, bekommt jedes Zeichen an seinen Rundungen gespiegelt.
        XCTAssertEqual(r.oben, -5, accuracy: 0.01)
        XCTAssertEqual(r.unten, 0, accuracy: 0.01)
    }

    /// Die beiden Richtungen muessen sich spiegeln.
    func testBogenrichtung() throws {
        let hoch = try SvgPfad.lies("M 0 0 A 5 5 0 0 1 10 0")
        let tief = try SvgPfad.lies("M 0 0 A 5 5 0 0 0 10 0")
        XCTAssertEqual(SvgPfad.rahmen(hoch)!.oben, -5, accuracy: 0.01)
        XCTAssertEqual(SvgPfad.rahmen(hoch)!.unten, 0, accuracy: 0.01)
        XCTAssertEqual(SvgPfad.rahmen(tief)!.unten, 5, accuracy: 0.01)
        XCTAssertEqual(SvgPfad.rahmen(tief)!.oben, 0, accuracy: 0.01)
    }

    /// Der grosse Bogen nimmt den laengeren Weg: drei Viertel statt eines.
    func testGrosserBogen() throws {
        let klein = try SvgPfad.lies("M 0 0 A 5 5 0 0 1 5 5")
        let gross = try SvgPfad.lies("M 0 0 A 5 5 0 1 1 5 5")
        XCTAssertLessThan(klein.count, gross.count)
        // Der kleine Bogen bleibt im Kasten zwischen den Punkten, der grosse nicht.
        XCTAssertGreaterThan(SvgPfad.rahmen(gross)!.rechts, 6)
    }

    /// Zu kleine Radien werden aufgezogen, bis der Bogen passt (Spezifikation F.6.6). Ohne das
    /// steht unter der Wurzel eine negative Zahl, und aus dem Zeichen wird ein NaN-Fleck.
    func testZuKleineRadienWerdenAufgezogen() throws {
        let s = try SvgPfad.lies("M 0 0 A 1 1 0 0 1 10 0")
        guard case .kurve(let g1, let g2, let ziel) = s.last else { return XCTFail("Kurve erwartet") }
        for p in [g1, g2, ziel] {
            XCTAssertTrue(p.x.isFinite && p.y.isFinite, "der Bogen hat NaN erzeugt")
        }
        XCTAssertEqual(ziel.x, 10, accuracy: 1e-9)
    }

    /// Ein Radius von null macht aus dem Bogen eine Linie, und gleiche Punkte ergeben nichts -
    /// beides steht so in der Spezifikation.
    func testEntarteteBoegen() throws {
        XCTAssertEqual(try SvgPfad.lies("M 0 0 A 0 5 0 0 1 10 0").last, .linie(Punkt(10, 0)))
        XCTAssertEqual(try SvgPfad.lies("M 3 3 A 5 5 0 0 1 3 3").count, 1)
    }

    /// Ein gedrehter Bogen. Die Drehung betrifft nur Ellipsen, muss aber mitgerechnet werden -
    /// das Thermometer und die Tasse benutzen sie nicht, der Vollstaendigkeit halber trotzdem.
    func testGedrehterBogen() throws {
        let s = try SvgPfad.lies("M 0 0 A 10 5 45 0 1 10 10")
        guard case .kurve(_, _, let ziel) = s.last else { return XCTFail("Kurve erwartet") }
        XCTAssertEqual(ziel.x, 10, accuracy: 1e-9)
        XCTAssertEqual(ziel.y, 10, accuracy: 1e-9)
    }

    /// Relativ geschriebene Boegen kommen in den Zeichen vor: `a2 2 0 0 1 1.9-1.4`.
    func testRelativerBogen() throws {
        let s = try SvgPfad.lies("M 5 5 a 2 2 0 0 1 4 0")
        guard case .kurve(_, _, let ziel) = s.last else { return XCTFail("Kurve erwartet") }
        XCTAssertEqual(ziel.x, 9, accuracy: 1e-9)
        XCTAssertEqual(ziel.y, 5, accuracy: 1e-9)
    }

    /// Die Flaggen eines Bogens stehen ohne Trennzeichen beieinander: `a2 2 0 0 1 1.9-1.4`
    /// enthaelt „0 1" als zwei Flaggen und dann „1.9" und „-1.4".
    func testBogenMitGedraengtenFlaggen() throws {
        let s = try SvgPfad.lies("M3.5 14.3 5.1 9.9a2 2 0 0 1 1.9-1.4")
        guard case .kurve(_, _, let ziel) = s.last else { return XCTFail("Kurve erwartet") }
        XCTAssertEqual(ziel.x, 7.0, accuracy: 1e-9)
        XCTAssertEqual(ziel.y, 8.5, accuracy: 1e-9)
    }

    func testUnbekannterBefehl() {
        XCTAssertThrowsError(try SvgPfad.lies("M 0 0 X 5 5")) { fehler in
            XCTAssertEqual(fehler as? SvgPfad.Fehler, .unbekannterBefehl("X"))
        }
    }

    func testFehlendeZahl() {
        XCTAssertThrowsError(try SvgPfad.lies("M 0")) { fehler in
            guard case .zahlFehlt = fehler as? SvgPfad.Fehler else {
                return XCTFail("zahlFehlt erwartet, nicht \(fehler)")
            }
        }
    }

    func testLeererPfad() throws {
        XCTAssertTrue(try SvgPfad.lies("").isEmpty)
        XCTAssertTrue(try SvgPfad.lies("   ").isEmpty)
    }

    func testRahmen() throws {
        let s = try SvgPfad.lies("M 2 3 L 10 3 L 10 9 Z")
        let r = SvgPfad.rahmen(s)
        XCTAssertEqual(r?.links, 2)
        XCTAssertEqual(r?.oben, 3)
        XCTAssertEqual(r?.rechts, 10)
        XCTAssertEqual(r?.unten, 9)
        XCTAssertNil(SvgPfad.rahmen([]))
    }

    // MARK: - Die Zeichen selbst

    /// **Der Nachweis.** Alle Zeichen, alle Formen, durch den Leser - und jede muss mit einem
    /// Anheben des Stifts beginnen und innerhalb ihres Rasters liegen.
    func testAlleZeichenLassenSichLesen() throws {
        var formen = 0
        for art in Zeichenart.allCases {
            XCTAssertFalse(art.formen.isEmpty, "\(art) hat keine Form")
            for (d, _) in art.formen {
                let stuecke: [Pfadstueck]
                do {
                    stuecke = try SvgPfad.lies(d)
                } catch {
                    XCTFail("\(art): \(error) in „\(d.prefix(60))“")
                    continue
                }
                formen += 1
                XCTAssertFalse(stuecke.isEmpty, "\(art): leere Form")
                guard case .anfang = stuecke.first else {
                    XCTFail("\(art): die Form beginnt nicht mit M")
                    continue
                }
                // Auf dem 24-Punkt-Raster, mit etwas Luft fuer die Griffe der Kurven.
                if let r = SvgPfad.rahmen(stuecke) {
                    XCTAssertGreaterThan(r.links, -2.0, "\(art) ragt links aus dem Raster")
                    XCTAssertGreaterThan(r.oben, -2.0, "\(art) ragt oben aus dem Raster")
                    XCTAssertLessThan(r.rechts, Zeichenart.raster + 2, "\(art) ragt rechts aus dem Raster")
                    XCTAssertLessThan(r.unten, Zeichenart.raster + 2, "\(art) ragt unten aus dem Raster")
                }
            }
        }
        // 24 Zeichen mit zusammen 72 Formen. `home` und `house` sind in Icon.tsx dieselbe
        // Zeichnung und heissen hier beide `haus`. Seit dem 24.11.2026 ist es eine Form mehr:
        // die Waermepumpe als Aussengeraet hat neben Luefter und Fuessen die Lamellen.
        XCTAssertEqual(Zeichenart.allCases.count, 24)
        XCTAssertEqual(formen, 72, "Es sollten 72 Formen aus Icon.tsx uebernommen sein.")
    }

    /// Die Bereichsleiste braucht fuenf Zeichen, und die Marke ist eines davon.
    func testDieZeichenDerBereichsleisteSindDa() {
        for art in [Zeichenart.ente, .haus, .blitz, .euro, .zahnrad] {
            XCTAssertFalse(art.formen.isEmpty, "\(art) fehlt")
        }
        // Die Entenkurve ist eine einzige Kurve - daran erkennt man, dass es die Marke ist und
        // nicht ein zusammengesetztes Zeichen.
        XCTAssertEqual(Zeichenart.ente.formen.count, 1)
    }

    /// Der Kreis, den der Uebernehmer aus `<circle>` rechnet, muss wirklich ein Kreis sein.
    func testDerGerechneteKreisIstEinKreis() throws {
        // `sonne` beginnt mit `<circle cx="12" cy="12" r="3.9">`.
        let stuecke = try SvgPfad.lies(Zeichenart.sonne.formen[0].d)
        let r = SvgPfad.rahmen(stuecke)
        XCTAssertEqual(r?.links ?? 0, 12 - 3.9, accuracy: 0.01)
        XCTAssertEqual(r?.rechts ?? 0, 12 + 3.9, accuracy: 0.01)
        XCTAssertEqual(r?.oben ?? 0, 12 - 3.9, accuracy: 0.01)
        XCTAssertEqual(r?.unten ?? 0, 12 + 3.9, accuracy: 0.01)
    }

    /// Die gefuellte Flaeche im Batteriezeichen ist der Ladestand und muss als gefuellt
    /// uebernommen worden sein - als Strich waere sie ein leeres Kaestchen.
    func testDerLadestandImBatteriezeichenIstGefuellt() {
        let gefuellte = Zeichenart.batterie.formen.filter(\.gefuellt)
        XCTAssertEqual(gefuellte.count, 1, "genau eine Flaeche im Batteriezeichen ist gefuellt")
    }
}
