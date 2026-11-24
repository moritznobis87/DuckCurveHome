import XCTest

@testable import DuckCurveKit

/// Die Palette nachrechnen.
///
/// **Was dieser Test leistet und was nicht.** Er ist kein Urteil ueber die Palette - die ist
/// gestaltet und steht. Er ist ein Waechter gegen stilles Verrutschen: wer eine Serienfarbe
/// aendert, sieht hier, welche Nachbarschaft sich dabei verschiebt. Die Zahlen sind deshalb
/// festgenagelt und nicht nur gegen eine Schwelle gehalten.
///
/// **Ein Befund aus dem Nachrechnen.** Die Zahlen, die `apps/web/src/styles/tokens.css` zum
/// Pelletofen nennt, lassen sich mit keiner der beiden ueblichen Formeln reproduzieren:
///
/// | Paar                  | tokens.css | ΔE2000 | ΔE76  |
/// |-----------------------|-----------:|-------:|------:|
/// | Ofen / Wärmepumpe     |       15,3 |  16,8  |  25,0 |
/// | Ofen / Amber          |       20,7 |  23,7  |  37,1 |
/// | Ofen / Batterie       |       18,3 |  38,0  |  74,0 |
/// | Ofen / Alarm          |        9,3 |  16,9  |  28,4 |
/// | Ofen / Netzbezug      |        9,3 |  39,4  |  74,1 |
///
/// Die beiden ersten liegen nah genug an ΔE2000, um dieselbe Messung zu sein. Die drei unteren
/// nicht: der Abstand zur Batterie ist doppelt so gross wie dort behauptet, der zum Netzbezug
/// viermal. Die Auflage in `tokens.css`, Ofen und Netzbezug nicht ohne Zweitkodierung in dieselbe
/// Grafik zu setzen, steht also auf einer Zahl, die nicht nachzurechnen ist. Sie wird hier
/// trotzdem nicht angetastet: eine gestalterische Auflage zu streichen, weil ihre Begruendung
/// einen Zahlendreher hat, ist eine Entscheidung fuer den Hausherrn und nicht fuer diesen Test.
final class MarkenTests: XCTestCase {
    /// Die Serienfarben, die in derselben Grafik nebeneinander stehen koennen.
    private static let serien: [(String, Farbwert)] = [
        ("PV", Marken.pv),
        ("Netzbezug", Marken.netzBezug),
        ("Einspeisung", Marken.netzEinspeisung),
        ("Batterie", Marken.batterie),
        ("Wärmepumpe", Marken.waermepumpe),
        ("Ofen", Marken.ofen),
        ("Wallbox", Marken.wallbox),
    ]

    /// Die gemessenen Abstaende, auf eine Stelle festgenagelt. Weicht einer ab, hat jemand eine
    /// Marke verschoben - dann ist diese Tabelle nachzurechnen und die Nachbarschaft zu pruefen.
    private static let gemessen: [String: Double] = [
        "Netzbezug|Wallbox": 7.8,
        "Batterie|Wallbox": 7.9,
        "PV|Einspeisung": 13.1,
        "Netzbezug|Batterie": 14.9,
        "Wärmepumpe|Ofen": 16.8,
        "PV|Wärmepumpe": 18.4,
        "Einspeisung|Wärmepumpe": 22.6,
        "PV|Ofen": 23.7,
        "Einspeisung|Ofen": 32.8,
        "Netzbezug|Wärmepumpe": 34.1,
        "Wärmepumpe|Wallbox": 37.8,
        "Batterie|Ofen": 38.0,
        "Batterie|Wärmepumpe": 39.1,
        "Netzbezug|Ofen": 39.4,
        "Netzbezug|Einspeisung": 39.6,
        "Ofen|Wallbox": 40.3,
        "PV|Netzbezug": 41.4,
        "Einspeisung|Wallbox": 45.1,
        "PV|Wallbox": 45.6,
        "PV|Batterie": 46.0,
        "Einspeisung|Batterie": 46.8,
    ]

    func testJederAbstandIstNochDerGemessene() {
        let s = Self.serien
        for i in s.indices {
            for j in s.indices where j > i {
                let schluessel = "\(s[i].0)|\(s[j].0)"
                guard let erwartet = Self.gemessen[schluessel] else {
                    XCTFail("Fuer \(schluessel) fehlt der gemessene Abstand in der Tabelle.")
                    continue
                }
                let ist = s[i].1.abstand(zu: s[j].1)
                XCTAssertEqual(ist, erwartet, accuracy: 0.1, "\(schluessel): ΔE2000 \(ist) statt \(erwartet)")
            }
        }
    }

    /// Welche Paare unter der Schwelle von 15 liegen, ist eine Eigenschaft der Palette und soll
    /// benannt sein - nicht, damit sie geaendert wird, sondern damit niemand versehentlich ein
    /// weiteres Paar hinzufuegt.
    ///
    /// Die vier sind erklaerbar: `pv` und `netzEinspeisung` sind beide Amber und meinen beide die
    /// Sonne; `netzBezug`, `batterie` und `wallbox` sind drei gedeckte Blaugraus. In derselben
    /// Grafik tragen sie nie allein - der Energiefluss beschriftet jeden Knoten.
    func testNurDieBekanntenViviPaareLiegenUnterDerSchwelle() {
        let s = Self.serien
        var eng: Set<Set<String>> = []
        for i in s.indices {
            for j in s.indices where j > i {
                if s[i].1.abstand(zu: s[j].1) < 15.0 {
                    eng.insert([s[i].0, s[j].0])
                }
            }
        }
        let bekannt: Set<Set<String>> = [
            ["Netzbezug", "Wallbox"],
            ["Batterie", "Wallbox"],
            ["PV", "Einspeisung"],
            ["Netzbezug", "Batterie"],
        ]
        XCTAssertEqual(eng, bekannt, "Die Menge der eng benachbarten Serienfarben hat sich geaendert.")
    }

    /// Text muss auf der Flaeche lesbar sein. WCAG AA fordert 4,5:1 fuer Lauftext, 3:1 fuer grossen.
    func testTextIstLesbar() {
        XCTAssertGreaterThan(Marken.text1.kontrast(zu: Marken.flaeche2), 4.5)
        XCTAssertGreaterThan(Marken.text2.kontrast(zu: Marken.flaeche2), 4.5)
        // Die dritte Stufe traegt nur Beiwerk und darf darunter liegen - aber nicht beliebig.
        XCTAssertGreaterThan(Marken.text3.kontrast(zu: Marken.flaeche2), 2.4)
    }

    /// **Kleine Schrift erreicht 4,5:1 auf den Karten.** Gemessen am 24.11.2026 lag die blasse
    /// Stufe mit 48 % Deckung bei 4,41, 4,22 und 3,88 auf den Flaechen 1 bis 3, das Nebelgrau der
    /// Stichwortzeilen auf Flaeche 3 bei 4,18 und Alarmrot als Schrift bei 3,70 und 3,38. Die
    /// drei Marken sind danach gesetzt (`tokens.css`: `--text-3`, `--text-kicker`,
    /// `--alert-text`); dieser Test haelt die Schwelle, damit sie nicht wieder darunter rutschen.
    func testKleineSchriftErreichtVierKommaFuenfAufDenKarten() {
        for flaeche in [Marken.flaeche1, Marken.flaeche2, Marken.flaeche3] {
            // Die blasse Stufe ist Weiss mit Deckung; gemessen wird sie auf der Flaeche liegend.
            let blass = flaeche.gemischt(mit: Marken.papier, anteil: Marken.text3.deckung)
                .mitDeckung(1)
            XCTAssertGreaterThanOrEqual(blass.kontrast(zu: flaeche), 4.5, "text3 auf \(flaeche.hex)")
            XCTAssertGreaterThanOrEqual(
                Marken.textKicker.kontrast(zu: flaeche), 4.5, "Kicker auf \(flaeche.hex)")
        }
        XCTAssertGreaterThanOrEqual(Marken.alarmText.kontrast(zu: Marken.flaeche1), 4.5)
        XCTAssertGreaterThanOrEqual(Marken.alarmText.kontrast(zu: Marken.flaeche2), 4.5)
        // Auf Flaeche 3 bleibt auch das hellere Rot darunter. Sie ist die Flaeche fuer den
        // gedrueckten und ueberfahrenen Zustand, auf der keine Fehlermeldung steht; die Zahl ist
        // festgehalten, damit niemand sie fuer erfuellt haelt.
        XCTAssertEqual(Marken.alarmText.kontrast(zu: Marken.flaeche3), 4.21, accuracy: 0.03)
        // Das Alarmrot der Flaechen und Marken bleibt, wo es war, und ist keine Schriftfarbe.
        XCTAssertEqual(Marken.alarm.hex, "#E0533D")
        XCTAssertLessThan(Marken.alarm.kontrast(zu: Marken.flaeche2), 4.5)
    }

    /// Die blasse Stufe bleibt von der mittleren zu unterscheiden: sonst waeren es zwei Namen
    /// fuer dieselbe Schrift.
    func testDieDreiTextstufenBleibenGetrennt() {
        XCTAssertEqual(Marken.text1.deckung, 0.92, accuracy: 1e-9)
        XCTAssertEqual(Marken.text2.deckung, 0.72, accuracy: 1e-9)
        XCTAssertEqual(Marken.text3.deckung, 0.58, accuracy: 1e-9)
    }

    /// Der Kontrast des Ofens zur Flaeche liegt knapp unter 3:1. Das ist der Grund fuer die
    /// Auflage in `tokens.css`, dass immer eine Beschriftung daneben gehoert - und diese Zahl
    /// stimmt dort.
    func testDerOfenBleibtUnterDreiZuEins() {
        XCTAssertEqual(Marken.ofen.kontrast(zu: Marken.flaeche2), 2.99, accuracy: 0.02)
        XCTAssertLessThan(Marken.ofen.kontrast(zu: Marken.flaeche2), 3.0)
    }

    /// Die fuenf Stufen der Abweichung muessen als Folge zu lesen sein: jede Stufe von ihrer
    /// Nachbarin unterscheidbar.
    func testDieStufenDerAbweichungSindUnterscheidbar() {
        let a = Marken.abweichung
        for i in 0..<(a.count - 1) {
            let d = a[i].abstand(zu: a[i + 1])
            XCTAssertGreaterThan(d, 15.0, "Stufe \(i) und \(i + 1) der Abweichung: nur ΔE2000 \(d)")
        }
    }

    /// Die beiden Enden der Skala muessen auch ohne Farbwahrnehmung zu trennen sein.
    ///
    /// **`tokens.css` begruendet das mit dem Hellwert, und das traegt nicht:** kalt (#6FD0F2) hat
    /// L\* 79,0 und warm (#FFC247) L\* 82,0 - drei Punkte, nicht die dort genannten „mehr als 20“.
    /// Beide Enden sind helle Farben, das ist Absicht.
    ///
    /// Was wirklich traegt, ist der Blauanteil: 242 gegen 71. Rot- und Gruenblindheit lassen die
    /// Blauwahrnehmung unberuehrt, und genau daran bleiben hellblau und hellgelb zu trennen. Der
    /// Test prueft deshalb den Blauanteil und nicht die Helligkeit.
    func testDieEndenDerSkalaSindAuchOhneFarbeZuTrennen() {
        let kalt = Marken.abwKalt2
        let warm = Marken.abwWarm2
        XCTAssertLessThan(abs(kalt.lab.l - warm.lab.l), 6.0, "Beide Enden sind helle Farben - das ist Absicht.")
        XCTAssertGreaterThan(abs(kalt.blau - warm.blau) * 255, 120, "Der Blauanteil trennt die Enden nicht mehr.")
    }

    /// **Dieser Test hielt meine falschen Grenzen fest.** Er erwartete bei −0,5 K noch
    /// „kalt“, weil die Fassung davor bei −0,3 trennte. Das Dashboard prueft
    /// `k >= von && k < bis` (`rooms/palette.ts`), und damit gehoert genau −0,5 schon zu
    /// „am Ziel“. Die Kanten stehen jetzt ausdruecklich da, denn an ihnen sass der Fehler.
    func testAbweichungsfarbeTrifftDieStufen() {
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: -2.0), Marken.abwKalt2)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: -1.0), Marken.abwKalt1)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: 0.0), Marken.abwNull)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: 1.0), Marken.abwWarm1)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: 2.0), Marken.abwWarm2)

        // Die Kanten, genau wie in der Vorlage: die untere gehoert zur Stufe, die obere nicht.
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: -1.5), Marken.abwKalt1)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: -1.51), Marken.abwKalt2)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: -0.5), Marken.abwNull)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: -0.51), Marken.abwKalt1)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: 0.5), Marken.abwWarm1)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: 0.49), Marken.abwNull)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: 1.5), Marken.abwWarm2)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: 1.49), Marken.abwWarm1)

        // Ohne Messwert bleibt die Stufe gedeckt. **Die Matrix ruft hier gar nicht an**: ein
        // fehlender Wert wird schraffiert, nicht eingefaerbt - sonst sieht ein stummer
        // Fuehler aus wie ein Raum am Ziel.
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: nil), Marken.abwNull)
        XCTAssertEqual(Marken.abweichungsfarbe(kelvin: .nan), Marken.abwNull)
    }

    /// Die Waermeskala ist ein Verlauf, keine Menge von Kategorien - und wird anders gemessen.
    ///
    /// Die Schwelle von 15 gilt fuer Serienfarben, die gleichzeitig in einer Legende stehen und
    /// einzeln benannt werden muessen. Eine Verlaufsskala liest das Auge als Gefaelle: hier
    /// genuegt, dass jede Stufe von ihrer Nachbarin zu unterscheiden ist, und was zaehlt, ist die
    /// Spanne vom kalten zum heissen Ende. Stufe 2 und 3 sind Amber-Soft und Amber und liegen bei
    /// ΔE2000 13,1 - fuer einen Verlauf richtig, fuer eine Legende zu nah.
    ///
    /// Die Helligkeit laeuft dabei nicht gleichsinnig: L\* steigt von 30,4 auf 87,6 und faellt
    /// dann auf 54,4. Das ist Absicht - heiss ist dunkelrot, nicht hell.
    func testDieWaermeskalaIstEinLesbarerVerlauf() {
        let w = Marken.waerme
        for i in 0..<(w.count - 1) {
            let d = w[i].abstand(zu: w[i + 1])
            XCTAssertGreaterThan(d, 10.0, "Stufe \(i) und \(i + 1) der Waermeskala: nur ΔE2000 \(d)")
        }
        XCTAssertGreaterThan(w.first!.abstand(zu: w.last!), 40.0, "Die Skala spannt zu wenig.")
        let hell = w.map(\.lab.l)
        XCTAssertEqual(hell.firstIndex(of: hell.max()!), 2, "Die hellste Stufe ist die Mitte der Skala.")
    }

    func testHexSchreibtSichZurueck() {
        XCTAssertEqual(Marken.amber.hex, "#F2A900")
        XCTAssertEqual(Marken.deep.hex, "#082431")
        XCTAssertEqual(Marken.ofen.hex, "#B5651D")
        XCTAssertEqual(Farbwert(0xFFFFFF).hex, "#FFFFFF")
    }

    /// Weiss gegen Schwarz ist 21:1 - die Probe, dass die Kontrastrechnung richtig ist.
    func testKontrastrechnungIstRichtig() {
        XCTAssertEqual(Farbwert(0xFFFFFF).kontrast(zu: Farbwert(0x000000)), 21.0, accuracy: 0.01)
        XCTAssertEqual(Farbwert(0x777777).kontrast(zu: Farbwert(0x777777)), 1.0, accuracy: 0.01)
    }

    /// Die Probe auf CIEDE2000: dieselbe Farbe hat Abstand null, und die Formel ist symmetrisch.
    /// Dazu zwei Paare aus der Veroeffentlichung von Sharma, Wu und Dalal.
    func testAbstandsformelIstRichtig() {
        XCTAssertEqual(Marken.amber.abstand(zu: Marken.amber), 0.0, accuracy: 1e-9)
        XCTAssertEqual(
            Marken.ofen.abstand(zu: Marken.pv), Marken.pv.abstand(zu: Marken.ofen), accuracy: 1e-9
        )
        // Weiss gegen Schwarz: der groesste Abstand, den es gibt - 100 in der Helligkeit.
        XCTAssertEqual(Farbwert(0xFFFFFF).abstand(zu: Farbwert(0x000000)), 100.0, accuracy: 0.5)
        // ΔE76 muss bei gesaettigten Farben deutlich darueber liegen - das ist der Grund fuer ΔE2000.
        XCTAssertGreaterThan(Marken.ofen.abstand76(zu: Marken.waermepumpe), Marken.ofen.abstand(zu: Marken.waermepumpe))
    }

    // MARK: - Die Rampe der Verfügbarkeit

    /// Die drei Stopps müssen sich auch ohne Farbwahrnehmung trennen lassen: die Karte hat
    /// keine Beschriftung je Zelle, nur Helligkeit und Ton.
    func testDieDreiStufenDerAbdeckungTrennenSichInDerHelligkeit() {
        let stufen = Marken.abdeckung
        XCTAssertEqual(stufen.count, 3)
        for (a, b) in zip(stufen, stufen.dropFirst()) {
            let abstand = abs(a.leuchtdichte - b.leuchtdichte)
            XCTAssertGreaterThan(
                abstand, 0.04,
                "Zwei benachbarte Stufen der Abdeckungskarte müssen sich in der Helligkeit "
                    + "unterscheiden, nicht nur im Farbton.")
        }
    }

    func testDieEndenDerAbdeckungsrampeSindDieSchonGepruefentenMarken() {
        XCTAssertEqual(Marken.abdeckungFehlend, Marken.alarm, "rot ist das laute Ende")
        XCTAssertEqual(Marken.abdeckungVoll, Marken.mist, "blaugrau das ruhige")
    }

    /// Die Raender der Rampe sind genau die Stopps, und die Mitte ist genau der Sandton.
    func testDieRampeTrifftAnIhrenStuetzstellenDieStopps() {
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: 0), Marken.abdeckungFehlend)
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: 0.5), Marken.abdeckungTeils)
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: 1), Marken.abdeckungVoll)
    }

    /// Zwischen den Stopps wird gemischt - sonst waere die Karte dreifarbig, und eine Stunde
    /// mit 55 Minuten saehe aus wie eine mit 48.
    func testZwischenDenStoppsLiegenEigeneToene() {
        let mitte = Marken.abdeckungsfarbe(anteil: 0.75)
        XCTAssertNotEqual(mitte, Marken.abdeckungTeils)
        XCTAssertNotEqual(mitte, Marken.abdeckungVoll)
        // Sie liegt zwischen den beiden, Kanal fuer Kanal.
        let a = Marken.abdeckungTeils
        let b = Marken.abdeckungVoll
        XCTAssertEqual(mitte.rot, (a.rot + b.rot) / 2, accuracy: 1e-9)
        XCTAssertEqual(mitte.gruen, (a.gruen + b.gruen) / 2, accuracy: 1e-9)
        XCTAssertEqual(mitte.blau, (a.blau + b.blau) / 2, accuracy: 1e-9)
    }

    /// **Die Rampe ist keine Helligkeitsrampe, und das muss man wissen.** Der Sandton der Mitte
    /// ist heller als beide Enden; von null Minuten nach sechzig geht die Helligkeit erst
    /// aufwaerts und dann wieder abwaerts. Zweideutig wird sie dadurch nicht, denn die Enden
    /// trennt der Farbton (rot gegen blaugrau), und innerhalb jeder Haelfte ist die Helligkeit
    /// eindeutig. Genau das haelt dieser Test fest, damit ein Wechsel der Stopps die
    /// Eindeutigkeit nicht unbemerkt verliert.
    func testJedeHaelfteDerRampeIstInDerHelligkeitEindeutig() {
        func dichten(_ von: Int, _ bis: Int) -> [Double] {
            (von...bis).map { Marken.abdeckungsfarbe(anteil: Double($0) / 60).leuchtdichte }
        }
        for (a, b) in zip(dichten(0, 30), dichten(0, 30).dropFirst()) {
            XCTAssertGreaterThan(b, a, "Die erste Haelfte wird heller, Minute fuer Minute.")
        }
        for (a, b) in zip(dichten(30, 60), dichten(30, 60).dropFirst()) {
            XCTAssertLessThan(b, a, "Die zweite Haelfte wird ruhiger, Minute fuer Minute.")
        }
    }

    /// Werte ausserhalb der Rampe und ein Unwert duerfen keine fremde Farbe erfinden.
    func testAusserhalbDerRampeStehenIhreEnden() {
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: -3), Marken.abdeckungFehlend)
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: 7), Marken.abdeckungVoll)
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: .nan), Marken.abdeckungFehlend)
    }

    /// Mischen ist stetig und an den Enden genau: 0 ist diese Farbe, 1 die andere.
    func testGemischtTrifftDieEndenUndBeschneidetDenAnteil() {
        let a = Farbwert(0x000000)
        let b = Farbwert(0xFFFFFF)
        XCTAssertEqual(a.gemischt(mit: b, anteil: 0), a)
        XCTAssertEqual(a.gemischt(mit: b, anteil: 1), b)
        XCTAssertEqual(a.gemischt(mit: b, anteil: -1), a, "unter null wird beschnitten")
        XCTAssertEqual(a.gemischt(mit: b, anteil: 2), b, "ueber eins auch")
        XCTAssertEqual(a.gemischt(mit: b, anteil: .nan), a, "ein Unwert laesst die Farbe stehen")
        XCTAssertEqual(a.gemischt(mit: b, anteil: 0.5).rot, 0.5, accuracy: 1e-9)
    }

    /// Auch die Deckung wird gemischt - eine Farbe mit Deckung 0 darf nicht plötzlich deckend
    /// werden, nur weil sie zu 10 Prozent eingemischt ist.
    func testGemischtNimmtAuchDieDeckungMit() {
        let offen = Farbwert(0xFFFFFF, deckung: 0)
        let dicht = Farbwert(0xFFFFFF, deckung: 1)
        XCTAssertEqual(offen.gemischt(mit: dicht, anteil: 0.25).deckung, 0.25, accuracy: 1e-9)
    }

    // MARK: - Die Rampen der Jahreskarte

    /// Die Rampen sind aus der Vorlage uebernommen; dieser Test haelt fest, dass sie es bleiben.
    func testDieRampenDerJahreskarteHabenIhreEndenUndIhreLaenge() {
        XCTAssertEqual(Marken.rampeEigen.count, 6)
        XCTAssertEqual(Marken.rampeNetz.count, 6)
        XCTAssertEqual(Marken.rampeWaerme.count, 6)
        XCTAssertEqual(Marken.rampeNetzBilanz.count, 7)
        // Der dunkelste Schritt der einfarbigen Rampen ist die Kartenflaeche selbst.
        for rampe in [Marken.rampeEigen, Marken.rampeNetz, Marken.rampeWaerme] {
            XCTAssertEqual(rampe.first, Farbwert(0x123544))
        }
        XCTAssertEqual(Marken.rampeEigen.last, Farbwert(0xFFD778))
        XCTAssertEqual(Marken.rampeNetz.last, Farbwert(0xE4ECEF))
        XCTAssertEqual(Marken.rampeWaerme.last, Farbwert(0xF6CDB4))
    }

    /// **Jede einfarbige Rampe wird durchgehend heller.** Das ist ihr Zweck: „mehr“ soll sich
    /// als „heller“ lesen, ohne dass man eine Skala daneben braucht.
    func testDieEinfarbigenRampenSteigenInDerHelligkeit() {
        for (name, rampe) in [
            ("eigen", Marken.rampeEigen), ("netz", Marken.rampeNetz),
            ("waerme", Marken.rampeWaerme),
        ] {
            var vorher = -1.0
            for schritt in 0...40 {
                let dichte = Marken.rampenfarbe(rampe, anteil: Double(schritt) / 40).leuchtdichte
                XCTAssertGreaterThan(dichte, vorher - 1e-9, "Rampe \(name) faellt bei \(schritt).")
                vorher = dichte
            }
        }
    }

    /// Die divergierende Rampe: beide Pole gleich hell, die Mitte deutlich dunkler.
    func testDieNetzbilanzIstAnBeidenPolenGleichHellUndInDerMitteRuhig() {
        let links = Marken.rampenfarbe(Marken.rampeNetzBilanz, anteil: 0)
        let rechts = Marken.rampenfarbe(Marken.rampeNetzBilanz, anteil: 1)
        let mitte = Marken.rampenfarbe(Marken.rampeNetzBilanz, anteil: 0.5)
        XCTAssertEqual(links.leuchtdichte, rechts.leuchtdichte, accuracy: 0.08)
        XCTAssertLessThan(mitte.leuchtdichte, links.leuchtdichte / 2)
        XCTAssertLessThan(mitte.leuchtdichte, rechts.leuchtdichte / 2)
    }

    /// Eine leere Rampe darf keine Farbe erfinden, und die Enden gelten ausserhalb.
    func testDieRampenrechnungHaeltSichAnIhreGrenzen() {
        XCTAssertEqual(Marken.rampenfarbe([], anteil: 0.5), Marken.text3)
        XCTAssertEqual(Marken.rampenfarbe(Marken.rampeEigen, anteil: -2), Marken.rampeEigen[0])
        XCTAssertEqual(Marken.rampenfarbe(Marken.rampeEigen, anteil: 9), Marken.rampeEigen[5])
        XCTAssertEqual(Marken.rampenfarbe(Marken.rampeEigen, anteil: .nan), Marken.rampeEigen[0])
        // Die Abdeckungsrampe laeuft jetzt ueber dieselbe Rechnung und muss dasselbe liefern.
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: 0.5), Marken.abdeckungTeils)
        XCTAssertEqual(Marken.abdeckungsfarbe(anteil: 0.25),
                       Marken.abdeckungFehlend.gemischt(mit: Marken.abdeckungTeils, anteil: 0.5))
    }

    // MARK: - Die nachgezogenen Farben

    /// Die Hexwerte der Vorlage, festgenagelt wie die uebrigen.
    ///
    /// **Drei von ihnen tragen eine Zahl, die in dieser Liste schon vorkommt**, und genau
    /// darum stehen sie da: #C2A86B ist auch `abdeckungTeils`, #E4ECEF auch der oberste Stopp
    /// von `rampeNetz`, und das Weiss der Spur auch `papier`. Vor diesem Test holten sich die
    /// Seiten die Werte von dort - wer den Sandton der Abdeckungskarte verschoben haette,
    /// haette die Grundgebuehr einer Stromrechnung mitverschoben. Hier wird deshalb kein
    /// Gleichstand geprueft, sondern jeder Wert einzeln gegen die Vorlage: die beiden duerfen
    /// auseinanderlaufen, sie duerfen es nur nicht unbemerkt.
    func testDieNachgezogenenFarbenHabenDieWerteDerVorlage() {
        // `C.base`, `charts/palette.ts:39` - in `reports/charts.ts:300` die Grundgebuehr.
        XCTAssertEqual(Marken.grundgebuehr.hex, "#C2A86B")
        XCTAssertEqual(Marken.grundgebuehr.deckung, 1.0, accuracy: 1e-9)
        // `C.export`, `charts/palette.ts:44` - `rgba(228,236,239,.5)`, halbe Deckung.
        XCTAssertEqual(Marken.umsatzsteuer.hex, "#E4ECEF")
        XCTAssertEqual(Marken.umsatzsteuer.deckung, 0.5, accuracy: 1e-9)
        // `SPUR`, `waerme/Tagesuhr.tsx:51` - `rgba(255,255,255,.055)`.
        XCTAssertEqual(Marken.spur.hex, "#FFFFFF")
        XCTAssertEqual(Marken.spur.deckung, 0.055, accuracy: 1e-9)
        // `.anlage-buehne`, `globals.css:565`.
        XCTAssertEqual(Marken.buehneOben.hex, "#0A2735")
        XCTAssertEqual(Marken.buehneOben.deckung, 0.85, accuracy: 1e-9)
        XCTAssertEqual(Marken.buehneUnten.hex, "#05161F")
        XCTAssertEqual(Marken.buehneUnten.deckung, 0.9, accuracy: 1e-9)
    }

    /// Die Spur muss schwaecher sein als jede Linie des Rasters.
    ///
    /// Daran haengt, dass die Tagesuhr drei Aussagen tragen kann: Spur, Fuellung, nichts. Mit
    /// der Deckung einer Rasterlinie waere die Spur ein Messwert und nicht ein Untergrund.
    func testDieSpurIstSchwaecherAlsJedeLinie() {
        XCTAssertLessThan(Marken.spur.deckung, Marken.rasterlinie.deckung)
        XCTAssertLessThan(Marken.spur.deckung, Marken.linie1.deckung)
        XCTAssertLessThan(Marken.spur.deckung, Marken.linie2.deckung)
    }

    /// Der gestapelte Rechnungsbetrag: Arbeitspreis, Grundgebuehr, Mehrwertsteuer.
    ///
    /// **Ein Befund, nicht eine Auflage.** Arbeitspreis (`pv`) und Grundgebuehr liegen bei
    /// ΔE2000 14,3 und damit unter der Schwelle 15, die diese Liste fuer **gestapelte** Reihen
    /// sonst verlangt - und gestapelt sind sie (`reports/charts.ts:313`, `stack: "eur"`). Der
    /// Kopf von `charts/palette.ts` fuehrt drei durchgerechnete Diagramme auf; dieses ist
    /// keines davon. Die Zahl wird hier festgenagelt und nicht verbessert: die App soll
    /// dieselben Farben zeigen wie der Browser, und eine eigene Wahl waere zwei Paletten. Wer
    /// sie heben will, hebt sie in der Vorlage.
    func testDerStapelDesRechnungsbetragsHaeltSeineGemessenenAbstaende() {
        XCTAssertEqual(Marken.pv.abstand(zu: Marken.grundgebuehr), 14.3, accuracy: 0.1)
        XCTAssertEqual(Marken.pv.abstand(zu: Marken.umsatzsteuer), 33.9, accuracy: 0.1)
        XCTAssertEqual(Marken.grundgebuehr.abstand(zu: Marken.umsatzsteuer), 27.4, accuracy: 0.1)
    }

    /// Beide Abschnitte muessen sich von der Kartenflaeche abheben - der untere Abschnitt eines
    /// Stapels verschwand in der Vorlage schon einmal im Hintergrund (`charts/palette.ts`,
    /// Haushalt #4D6B78 mit 2,28:1).
    ///
    /// Die Mehrwertsteuer traegt halbe Deckung, also zaehlt nicht ihr Hexwert, sondern was
    /// davon auf der Karte ankommt: 3,91:1 statt der 10,84:1 des reinen #E4ECEF.
    func testBeideReihenDesRechnungsbetragsHebenSichVonDerKarteAb() {
        XCTAssertGreaterThan(Marken.grundgebuehr.kontrast(zu: Marken.flaeche2), 3.0)
        let aufDerKarte = Marken.flaeche2.gemischt(
            mit: Marken.umsatzsteuer, anteil: Marken.umsatzsteuer.deckung)
        XCTAssertEqual(aufDerKarte.kontrast(zu: Marken.flaeche2), 3.91, accuracy: 0.02)
        XCTAssertGreaterThan(aufDerKarte.kontrast(zu: Marken.flaeche2), 3.0)
    }

    /// Die Buehne ist dunkler als die dunkelste Kartenflaeche - das ist ihr ganzer Zweck.
    ///
    /// Die Deckungen der Anlagenzeichnung sind fuer diesen Grund gerechnet. Stuende sie auf
    /// `flaeche1`, verloeren die Lichtpunkte in den Rohren und die Glaskacheln ihren Kontrast.
    /// Nach unten wird es dunkler, damit die Zeichnung auf dem Boden steht.
    func testDieBuehneIstDunklerAlsDieDunkelsteKartenflaeche() {
        XCTAssertLessThan(Marken.buehneOben.leuchtdichte, Marken.flaeche1.leuchtdichte)
        XCTAssertLessThan(Marken.buehneUnten.leuchtdichte, Marken.buehneOben.leuchtdichte)
    }

    /// Der Rand der Buehne ist eine Lichtkante oben und kein gleichmaessiger Grauwert.
    ///
    /// Der Stopp bei 30 Prozent ist der Punkt: zwischen 0 und 0,3 faellt die Deckung um 0,11,
    /// auf den restlichen 70 Prozent nur noch um 0,01. Ein Verlauf mit zwei Stopps - oder ein
    /// `strokeBorder` in einer Farbe - waere oben zu dunkel und unten zu hell.
    func testDerRandDerBuehneIstEineLichtkanteOben() {
        let rand = Marken.buehneRand
        XCTAssertEqual(rand.count, 3)
        XCTAssertEqual(rand.map(\.stelle), [0, 0.3, 1])
        for stopp in rand {
            XCTAssertEqual(stopp.farbe.hex, Marken.papier.hex, "der Rand ist Weiss mit Deckung")
        }
        let oben = rand[0].farbe.deckung - rand[1].farbe.deckung
        let unten = rand[1].farbe.deckung - rand[2].farbe.deckung
        XCTAssertGreaterThan(oben, 0, "oben heller als in der Mitte")
        XCTAssertGreaterThan(unten, 0, "und die Mitte heller als unten")
        XCTAssertGreaterThan(oben, unten * 10, "der Sprung sitzt im ersten Drittel")
    }

    // MARK: - Die aus den Seiten eingesammelten Werte

    /// Die Zahlen der Vorlage, festgenagelt wie die uebrigen.
    ///
    /// **Drei von ihnen sind Weiss mit Deckung, und zwei tragen eine Zahl, die in dieser Liste
    /// schon vorkommt**: ``Marken/stufenbalken`` hat die 0,62 von ``Marken/last``, und
    /// ``Marken/hauslinie`` war in der Tageskurve als ``Marken/text1`` mit anderer Deckung
    /// gerechnet. Darum steht hier kein Gleichstand, sondern jeder Wert einzeln gegen seine
    /// Stelle in der Vorlage: die beiden duerfen auseinanderlaufen, sie duerfen es nur nicht
    /// unbemerkt.
    func testDieEingesammeltenWerteHabenDieZahlenDerVorlage() {
        // `rgba(255,255,255,.88)`, `home/DayCurve.tsx:127` und `:146`.
        XCTAssertEqual(Marken.hauslinie.hex, "#FFFFFF")
        XCTAssertEqual(Marken.hauslinie.deckung, 0.88, accuracy: 1e-9)
        // `rgba(255,255,255,.62)`, `waerme/Kostentreppe.tsx:29`.
        XCTAssertEqual(Marken.stufenbalken.hex, "#FFFFFF")
        XCTAssertEqual(Marken.stufenbalken.deckung, 0.62, accuracy: 1e-9)
        // `rgba(255,255,255,.07)`, `waerme/Tagesvergleich.tsx:156`.
        XCTAssertEqual(Marken.stufeNull.hex, "#FFFFFF")
        XCTAssertEqual(Marken.stufeNull.deckung, 0.07, accuracy: 1e-9)
        // `rgba(255, 255, 255, .06)`, `globals.css:664` (`a.wk-zeile:hover`).
        XCTAssertEqual(Marken.zeileGedrueckt.hex, "#FFFFFF")
        XCTAssertEqual(Marken.zeileGedrueckt.deckung, 0.06, accuracy: 1e-9)
        // `rgba(255,255,255,.85)`, `reports/charts.ts:540` (`emphasis.itemStyle.borderColor`).
        XCTAssertEqual(Marken.zelleBeruehrt.hex, "#FFFFFF")
        XCTAssertEqual(Marken.zelleBeruehrt.deckung, 0.85, accuracy: 1e-9)
    }

    /// **Die weissen Schleier sind eine Leiter, und jede Stufe bedeutet etwas anderes.**
    ///
    /// Spur („gemessen, aber nichts lief“), gedrueckte Zeile, Stufe null eines Streifens
    /// („aus“), Rasterlinie, Haarlinie: fuenf Aussagen zwischen 0,055 und 0,10. Genau darum
    /// darf keine von ihnen eine andere vertreten - die Wirkungsseite nahm fuer die gedrueckte
    /// Zeile ``Marken/linie1`` und war damit um zwei Drittel zu kraeftig. Dieser Test haelt die
    /// Reihenfolge fest: wer eine Stufe verschiebt, sieht hier, ob sie ihre Nachbarin
    /// ueberholt.
    func testDieWeissenSchleierBleibenEineLeiter() {
        let leiter = [
            Marken.spur, Marken.zeileGedrueckt, Marken.stufeNull, Marken.rasterlinie,
            Marken.linie1, Marken.linie2,
        ]
        for stufe in leiter {
            XCTAssertEqual(stufe.hex, Marken.papier.hex, "jede Stufe ist Weiss mit Deckung")
        }
        for (a, b) in zip(leiter, leiter.dropFirst()) {
            XCTAssertLessThan(a.deckung, b.deckung, "die Leiter steigt, Stufe fuer Stufe")
        }
    }

    /// Das Akzentband: drei Stopps, und der Sinn sitzt in den Stellen.
    ///
    /// Der mittlere Stopp hat in CSS keine eigene Stelle und liegt damit mittig zwischen seinen
    /// Nachbarn, also bei 43 Prozent (`tokens.css:98`). Der letzte traegt dieselbe Farbe wie der
    /// mittlere auf Deckung null: ein Verlauf nach durchsichtigem Schwarz wird in SwiftUI in der
    /// Mitte grau, und ein graues Akzentband ist kein Akzent.
    func testDasAkzentbandHatDreiStoppsUndLaeuftInsDurchsichtigeBernstein() {
        let band = Marken.akzentband
        XCTAssertEqual(band.count, 3)
        XCTAssertEqual(band.map(\.stelle), [0, 0.43, 0.86])
        XCTAssertEqual(band[0].farbe, Marken.amber)
        XCTAssertEqual(band[1].farbe, Marken.amberWeich)
        XCTAssertEqual(band[2].farbe.hex, Marken.amberWeich.hex, "dieselbe Farbe, nicht Schwarz")
        XCTAssertEqual(band[2].farbe.deckung, 0, accuracy: 1e-9)
        // Die Mitte zwischen den letzten beiden Stopps bleibt Bernstein und wird nicht grau.
        let mitte = band[1].farbe.gemischt(mit: band[2].farbe, anteil: 0.5)
        XCTAssertEqual(mitte.hex, Marken.amberWeich.hex)
        XCTAssertEqual(mitte.deckung, 0.5, accuracy: 1e-9)
    }

    /// Der Fokusring: sechs Punkte und 0,12 gehoeren zusammen (`tokens.css:97`).
    ///
    /// **Darum ein Paar und nicht zwei Zahlen.** Ein Ring von sechs Punkten traegt nur bei
    /// dieser schwachen Deckung; umgekehrt ist 0,12 bei einem Punkt Staerke nicht zu sehen. Wer
    /// eine der beiden anfasst, soll die andere daneben finden.
    func testDerFokusringHatStaerkeUndDeckungDerVorlage() {
        XCTAssertEqual(Marken.fokusring.staerke, 6, accuracy: 1e-9)
        XCTAssertEqual(Marken.fokusring.farbe.hex, Marken.amber.hex)
        XCTAssertEqual(Marken.fokusring.farbe.deckung, 0.12, accuracy: 1e-9)
    }

    /// Die Lesebreite ist nachgerechnet und nicht geschaetzt.
    ///
    /// `max-w-[90ch]` (`reports/ReportShell.tsx:143-145`), `1ch` ist die Vorschubbreite der
    /// Null, in IBM Plex Sans 600 von 1000 Einheiten, und der Hinweisabsatz steht auf 11,5
    /// Punkten. Zwei Seiten trugen dafuer je eine eigene 560 - rund zehn Prozent zu schmal.
    /// Dieser Test ist die Rechnung selbst, damit die Zahl nicht wieder zur Schaetzung wird.
    func testDieLesebreiteIstNeunzigZeichenInPlexSans() {
        XCTAssertEqual(Marken.lesebreite, 90 * 0.6 * 11.5, accuracy: 1e-9)
        XCTAssertEqual(Marken.lesebreite, 621, accuracy: 1e-9)
    }

    /// Die Wachzeile: Kante und Grund sind dieselbe Farbe, einmal voll und einmal auf 10 %.
    ///
    /// `globals.css:205-206` schreibt beide Faelle aus - `--alert` auf `rgba(224,83,61,.10)`
    /// und `--amber-soft` auf `rgba(255,215,120,.10)`. Die Rechnung stand in der Wache; sie
    /// gilt aber fuer jede Schwere, auch fuer die, die diese Fassung nicht kennt.
    func testDieWachzeileGibtKanteUndGrundAlsPaar() {
        for schwere in [Marken.alarm, Marken.amberWeich, Marken.mist] {
            let paar = Marken.wachzeile(schwere)
            XCTAssertEqual(paar.kante, schwere, "die Kante ist die Schwerefarbe selbst")
            XCTAssertEqual(paar.grund.hex, schwere.hex, "der Grund ist dieselbe Farbe")
            XCTAssertEqual(paar.grund.deckung, Marken.wachgrundDeckung, accuracy: 1e-9)
        }
        XCTAssertEqual(Marken.wachgrundDeckung, 0.10, accuracy: 1e-9)
        XCTAssertEqual(Marken.wachzeile(Marken.alarm).grund.hex, "#E0533D")
        XCTAssertEqual(Marken.wachzeile(Marken.amberWeich).grund.hex, "#FFD778")
    }
}
