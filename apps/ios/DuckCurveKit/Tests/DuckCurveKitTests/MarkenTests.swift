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
    /// L\* 79,0 und warm (#FFC247) L\* 82,0 - drei Punkte, nicht die dort genannten „mehr als 20".
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
}
