import XCTest

@testable import DuckCurveKit

/// Der Pufferzustand und die Zeilen des Fahrplans.
///
/// Der erste Test ist der Fall vom 25.10.2026, der in `puffer.ts` beschrieben steht: vier satte
/// Temperaturen, ein voller Farbverlauf, und als Fuellstand ein Strich. Die Anzeige sah aus wie
/// immer, nur ohne Zahl - und die Ursache (ein abgemeldeter MQTT-Broker) lag zwei Tage zurueck.
final class PufferTests: XCTestCase {
    private let jetzt = Vorschau.jetzt

    private func fuehler(_ werte: [Double?], guete: [Quality]? = nil, alter: [TimeInterval]? = nil) -> [Messwert] {
        werte.enumerated().map { i, w in
            Messwert(
                value: w,
                observedAt: Zeit.iso(jetzt.addingTimeInterval(-(alter?[i] ?? 0))),
                quality: guete?[i] ?? (w == nil ? .unavailable : .ok),
                source: "test"
            )
        }
    }

    // MARK: - Der Fall vom 25.10.2026

    /// **Vier gute Zahlen und ein veralteter Fuehler.** Der Zustand darf nicht „warm" sein: die
    /// Anzeige weiss nichts Frisches, und das soll dastehen. Das Alter nennt den aeltesten der
    /// vier - er ist der Grund, warum der Dienst nichts rechnet.
    func testEinVeralteterFuehlerSchlaegtAlles() {
        let z = Pufferzustand.aus(
            fuehler: fuehler(
                [52.4, 47.1, 38.6, 31.2],
                guete: [.ok, .stale, .ok, .ok],
                alter: [10, 2 * 3600, 10, 10].map(Double.init)
            ),
            jetzt: jetzt, laedt: false, status: .warm
        )
        XCTAssertTrue(z.veraltet)
        XCTAssertTrue(z.vollstaendig, "Werte sind da - sie sind nur alt")
        XCTAssertFalse(z.traegt, "der Fuellstand darf keine Zahl tragen")
        XCTAssertEqual(z.wort, "Werte vor 2 h")
    }

    /// Der aelteste bestimmt das Alter, nicht der erste veraltete.
    func testDerAeltesteBestimmtDasAlter() {
        let z = Pufferzustand.aus(
            fuehler: fuehler(
                [52.4, 47.1, 38.6, 31.2],
                guete: [.ok, .stale, .stale, .ok],
                alter: [10, 600, 4 * 3600, 10].map(Double.init)
            ),
            jetzt: jetzt, laedt: false, status: .warm
        )
        XCTAssertEqual(z.wort, "Werte vor 4 h")
    }

    /// Ohne lesbaren Zeitstempel bleibt die Auskunft, dass die Werte alt sind - ohne Zahl.
    func testVeraltetOhneLesbaresAlter() {
        let m = [
            Messwert(value: 52.4, observedAt: "kaputt", quality: .stale, source: "test")
        ]
        let z = Pufferzustand.aus(fuehler: m, jetzt: jetzt, laedt: false, status: .warm)
        XCTAssertEqual(z.wort, "Werte veraltet")
    }

    // MARK: - Die uebrigen Faelle

    func testVollstaendigUndFrisch() {
        func wort(laedt: Bool, status: BufferStatus?) -> String {
            Pufferzustand.aus(
                fuehler: fuehler([52.4, 47.1, 38.6, 31.2]), jetzt: jetzt, laedt: laedt, status: status
            ).wort
        }
        // Laden schlaegt den Status: dass er gerade voller wird, ist die naehere Auskunft.
        XCTAssertEqual(wort(laedt: true, status: .warm), "lädt")
        XCTAssertEqual(wort(laedt: false, status: .full), "voll")
        XCTAssertEqual(wort(laedt: false, status: .cold), "kalt")
        XCTAssertEqual(wort(laedt: false, status: .warm), "warm")
        XCTAssertEqual(wort(laedt: false, status: .partial), "hält")
        XCTAssertEqual(wort(laedt: false, status: nil), "hält")
        XCTAssertEqual(wort(laedt: false, status: .unknown), "hält")
    }

    func testFehlendeWerte() {
        let z = Pufferzustand.aus(
            fuehler: fuehler([52.4, nil, 38.6, 31.2]), jetzt: jetzt, laedt: false, status: .warm
        )
        XCTAssertFalse(z.vollstaendig)
        XCTAssertFalse(z.veraltet, "ein fehlender Wert ist nicht ein alter")
        XCTAssertFalse(z.traegt)
        XCTAssertEqual(z.wort, "keine Werte")
    }

    func testGarKeineFuehler() {
        let z = Pufferzustand.aus(fuehler: [], jetzt: jetzt, laedt: false, status: .warm)
        XCTAssertFalse(z.vollstaendig)
        XCTAssertEqual(z.wort, "keine Werte")
    }

    /// Die Reihenfolge der vier Fuehler ist nicht beliebig: das Glas zeichnet sie auf ihrer
    /// Hoehe, und eine verdrehte Reihenfolge ergibt einen Speicher, der unten heiss ist.
    func testDieFuehlerStehenVonObenNachUnten() {
        let t = Vorschau.puffertemperaturen(oben: 52.4, mittigOben: 47.1, mittigUnten: 38.6, unten: 31.2)
        XCTAssertEqual(t.vonObenNachUnten.compactMap(\.value), [52.4, 47.1, 38.6, 31.2])
        // Und sie fallen von oben nach unten - alles andere waere ein Speicher auf dem Kopf.
        let werte = t.vonObenNachUnten.compactMap(\.value)
        XCTAssertEqual(werte, werte.sorted(by: >))
    }

    // MARK: - Die Zeilen des Fahrplans

    /// **Eine Zeile entsteht nur, wenn der Plan die Sache kennt.** Steht nichts ueber den
    /// Pelletofen darin, ist „bleibt aus" eine Behauptung und keine Auskunft.
    func testOhnePlanKeineZeilen() {
        XCTAssertTrue(Fahrplan.zeilen(nil, jetzt: jetzt).isEmpty)
    }

    func testEineZeileNurFuerWasImPlanSteht() {
        // Der Plan der Vorschau kennt den Ofen (`plannedStoveOn: false`), aber keinen
        // Optimierer-Lauf (`reasonCode` ist „pv_surplus"/„none").
        let zeilen = Fahrplan.zeilen(Vorschau.plan(ab: jetzt), jetzt: jetzt)
        XCTAssertTrue(zeilen.contains { $0.wort == "Pelletofen" })
        XCTAssertFalse(zeilen.contains { $0.wort == "Wärmepumpe" })
    }

    func testPhasenFassenZusammenhaengendeViertelstundenZusammen() {
        var p = Vorschau.plan(ab: jetzt, stunden: 4)
        // Die ersten vier Viertelstunden an, dann zwei aus, dann zwei an.
        for i in p.intervals.indices {
            p.intervals[i].plannedStoveOn = (i < 4) || (i >= 6 && i < 8)
        }
        let phasen = Fahrplan.phasen(p, jetzt: jetzt, bis: jetzt.addingTimeInterval(4 * 3600)) {
            $0.plannedStoveOn == true
        }
        XCTAssertEqual(phasen.count, 2, "die Pause muss die Phase schliessen")
        XCTAssertEqual(phasen[0].bis.timeIntervalSince(phasen[0].von), 4 * 900)
        XCTAssertEqual(phasen[1].bis.timeIntervalSince(phasen[1].von), 2 * 900)
    }

    /// **Aus zwei Laeufen mit einer Pause darf nicht ein langer werden.** Die Pause ist das
    /// Takten, und das ist an dieser Anlage der Gegenstand einer eigenen Seite.
    func testEineLueckeSchliesstDiePhase() {
        var p = Vorschau.plan(ab: jetzt, stunden: 2)
        for i in p.intervals.indices {
            p.intervals[i].plannedStoveOn = i != 2
        }
        let phasen = Fahrplan.phasen(p, jetzt: jetzt, bis: jetzt.addingTimeInterval(2 * 3600)) {
            $0.plannedStoveOn == true
        }
        XCTAssertEqual(phasen.count, 2)
    }

    /// Was vorbei ist, zaehlt nicht mehr. Sonst steht in der Leiste ein Lauf von heute morgen.
    func testVergangeneViertelstundenFallenWeg() {
        let anfang = jetzt.addingTimeInterval(-4 * 3600)
        var p = Vorschau.plan(ab: anfang, stunden: 8)
        for i in p.intervals.indices { p.intervals[i].plannedStoveOn = true }
        let phasen = Fahrplan.phasen(p, jetzt: jetzt, bis: jetzt.addingTimeInterval(24 * 3600)) {
            $0.plannedStoveOn == true
        }
        XCTAssertEqual(phasen.count, 1)
        XCTAssertGreaterThanOrEqual(phasen[0].bis, jetzt)
    }

    /// „bis 02:00", solange die Phase laeuft - sonst „23:15 bis 02:00".
    func testSpanneEinerPhase() {
        let laufend = Phase(
            von: jetzt.addingTimeInterval(-1800), bis: jetzt.addingTimeInterval(3600)
        )
        XCTAssertTrue(laufend.spanne(jetzt: jetzt).hasPrefix("bis "))
        let kuenftig = Phase(
            von: jetzt.addingTimeInterval(3600), bis: jetzt.addingTimeInterval(7200)
        )
        XCTAssertTrue(kuenftig.spanne(jetzt: jetzt).contains(" bis "))
        XCTAssertFalse(kuenftig.spanne(jetzt: jetzt).hasPrefix("bis "))
    }

    func testPreistiefKommtAusDemNaechstenFenster() {
        let p = Vorschau.plan(
            ab: jetzt,
            fenster: [
                Vorschau.fenster("2026-02-24T23:15:00+01:00", "2026-02-25T02:00:00+01:00", .cheap)
            ]
        )
        let zeilen = Fahrplan.zeilen(p, jetzt: jetzt)
        XCTAssertEqual(zeilen.first { $0.wort == "Preistief" }?.wann, "23:15 bis 02:00")
    }
}
