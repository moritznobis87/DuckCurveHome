import XCTest

@testable import DuckCurveKit

/// Der Leser des Ereignisstroms, Stueck fuer Stueck.
///
/// Der wichtigste Test ist `testByteweiseErgibtDasselbe`: der Live-Zustand dieses Hauses ist
/// einige Dutzend Kilobyte gross und kommt nie in einem Stueck. Ein Leser, der nur bei ganzen
/// Rahmen funktioniert, laeuft im Labor und versagt am iPad.
final class SseLeserTests: XCTestCase {
    private func d(_ s: String) -> Data { Data(s.utf8) }

    func testEinfachesEreignis() {
        var leser = SseLeser()
        let aus = leser.nimm(d("event: snapshot\nid: 7\ndata: {\"a\":1}\n\n"))
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].art, "snapshot")
        XCTAssertEqual(aus[0].daten, "{\"a\":1}")
        XCTAssertEqual(aus[0].kennung, "7")
    }

    /// Ohne `event:` gilt `message` - so steht es in der Spezifikation.
    func testOhneArtGiltMessage() {
        var leser = SseLeser()
        let aus = leser.nimm(d("data: hallo\n\n"))
        XCTAssertEqual(aus.map(\.art), ["message"])
    }

    func testMehrereEreignisseInEinemStueck() {
        var leser = SseLeser()
        let aus = leser.nimm(d("event: a\ndata: 1\n\nevent: b\ndata: 2\n\nevent: c\ndata: 3\n\n"))
        XCTAssertEqual(aus.map(\.art), ["a", "b", "c"])
        XCTAssertEqual(aus.map(\.daten), ["1", "2", "3"])
    }

    /// **Der Test, auf den es ankommt.** Derselbe Strom, einmal in einem Stueck und einmal Byte
    /// fuer Byte, muss dasselbe ergeben.
    func testByteweiseErgibtDasselbe() {
        let strom = """
            event: snapshot
            id: 1
            data: {"pv":3.6,"haus":1.2}

            : offenhalten

            event: decision
            data: {"k1":true}
            data: {"zweite":"zeile"}

            event: plan
            id: 2
            data: {}


            """
        var ganz = SseLeser()
        let inEinem = ganz.nimm(d(strom))

        var stueckweise = SseLeser()
        var einzeln: [SseEreignis] = []
        for byte in Array(strom.utf8) {
            einzeln.append(contentsOf: stueckweise.nimm(Data([byte])))
        }

        XCTAssertEqual(inEinem.count, 3)
        XCTAssertEqual(inEinem, einzeln, "byteweise gelesen kommt etwas anderes heraus")
        XCTAssertEqual(inEinem.map(\.art), ["snapshot", "decision", "plan"])
        // Zwei `data:`-Zeilen werden mit Zeilenumbruch verbunden.
        XCTAssertEqual(inEinem[1].daten, "{\"k1\":true}\n{\"zweite\":\"zeile\"}")
    }

    /// Ein Rahmen, der mitten in einem Mehrbytezeichen zerschnitten wird. „Wärmepumpe" hat ein
    /// Umlaut-ä, und das sind zwei Bytes.
    func testSchnittInEinemMehrbytezeichen() {
        let text = "event: snapshot\ndata: {\"name\":\"Wärmepumpe läuft\"}\n\n"
        let bytes = Array(text.utf8)
        // Jeden moeglichen Schnitt durchprobieren.
        for schnitt in 1..<bytes.count {
            var leser = SseLeser()
            var aus = leser.nimm(Data(bytes[0..<schnitt]))
            aus.append(contentsOf: leser.nimm(Data(bytes[schnitt...])))
            XCTAssertEqual(aus.count, 1, "Schnitt bei \(schnitt) ergibt \(aus.count) Ereignisse")
            XCTAssertEqual(aus.first?.daten, "{\"name\":\"Wärmepumpe läuft\"}", "Schnitt bei \(schnitt)")
        }
    }

    /// `\r\n` ist ein Umbruch, nicht zwei. Kommt das `\n` erst im naechsten Stueck, darf das
    /// `\r` kein Ereignis abschliessen - sonst entsteht aus einem Rahmen ein halber.
    func testWagenruecklaufUndZeilenvorschub() {
        var leser = SseLeser()
        XCTAssertTrue(leser.nimm(d("event: a\r\ndata: 1\r")).isEmpty)
        let aus = leser.nimm(d("\n\r\n"))
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].art, "a")
        XCTAssertEqual(aus[0].daten, "1")
    }

    func testNurWagenruecklauf() {
        var leser = SseLeser()
        let aus = leser.nimm(d("event: a\rdata: 1\r\r"))
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].daten, "1")
    }

    /// Kommentare halten die Verbindung offen und sind keine Ereignisse.
    func testKommentareWerdenUebersprungen() {
        var leser = SseLeser()
        let aus = leser.nimm(d(": halte offen\n\n: noch eins\n\ndata: echt\n\n"))
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].daten, "echt")
    }

    /// Ein Ereignis ohne `data:` wird verworfen - auch wenn es einen Namen hat.
    func testEreignisOhneDatenWirdVerworfen() {
        var leser = SseLeser()
        XCTAssertTrue(leser.nimm(d("event: leer\n\n")).isEmpty)
        XCTAssertTrue(leser.nimm(d("id: 9\n\n")).isEmpty)
    }

    /// Ein unvollstaendiges Ereignis am Ende bleibt im Puffer und wird nicht herausgegeben.
    func testUnvollstaendigesBleibtLiegen() {
        var leser = SseLeser()
        XCTAssertTrue(leser.nimm(d("event: snapshot\ndata: {\"halb\":")).isEmpty)
        let aus = leser.nimm(d("true}\n\n"))
        XCTAssertEqual(aus.map(\.daten), ["{\"halb\":true}"])
    }

    /// Ein Feld ohne Leerzeichen nach dem Doppelpunkt, und eines mit zwei. Genau eines gehoert
    /// nicht zum Wert.
    func testLeerzeichenNachDemDoppelpunkt() {
        var leser = SseLeser()
        let aus = leser.nimm(d("data:ohne\n\ndata:  mitzwei\n\n"))
        XCTAssertEqual(aus.map(\.daten), ["ohne", " mitzwei"])
    }

    func testRetryWirdGelesen() {
        var leser = SseLeser()
        _ = leser.nimm(d("retry: 2500\ndata: x\n\n"))
        XCTAssertEqual(leser.vorschlagWartezeit, 2.5)
    }

    /// Unbekannte Felder ignoriert der Leser, statt an ihnen zu scheitern.
    func testUnbekannteFelderStoerenNicht() {
        var leser = SseLeser()
        let aus = leser.nimm(d("event: a\nunfug: 1\ndata: gut\nnochmal: 2\n\n"))
        XCTAssertEqual(aus.map(\.daten), ["gut"])
    }

    /// Ein leerer `data:`-Wert ist ein Ereignis mit leerem Rumpf, nicht keines.
    func testLeereDatenZeileIstEinEreignis() {
        var leser = SseLeser()
        let aus = leser.nimm(d("event: heartbeat\ndata:\n\n"))
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].art, "heartbeat")
        XCTAssertEqual(aus[0].daten, "")
    }

    /// Der Strom, wie der Dienst ihn wirklich schickt: `apps/api/.../routers/live.py` sendet
    /// `snapshot`, `plan`, `decision` und zwischendurch `heartbeat` mit der Serverzeit.
    func testDerStromDesDienstes() {
        var leser = SseLeser()
        var aus: [SseEreignis] = []
        aus += leser.nimm(d("event: snapshot\nid: 0\ndata: {\"system\":{}}\n\n"))
        aus += leser.nimm(d("event: plan\nid: 0\ndata: {\"intervals\":[]}\n\n"))
        aus += leser.nimm(d("event: heartbeat\ndata: 2026-11-16T17:04:00+01:00\n\n"))
        aus += leser.nimm(d("event: decision\nid: 12\ndata: {\"id\":\"d12\"}\n\n"))
        XCTAssertEqual(aus.map(\.art), ["snapshot", "plan", "heartbeat", "decision"])
        XCTAssertEqual(aus[2].daten, "2026-11-16T17:04:00+01:00")
        XCTAssertNotNil(Zeit.ausIso(aus[2].daten), "die Serverzeit aus dem Herzschlag muss lesbar sein")
    }
}
