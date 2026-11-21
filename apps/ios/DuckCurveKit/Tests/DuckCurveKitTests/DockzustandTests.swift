import XCTest

@testable import DuckCurveKit

/// Das Dock der Startseite: welche Knoepfe dastehen und wie lange eine Rueckmeldung bleibt.
///
/// **Warum das geprueft wird.** Ein Ofenknopf in einem Haus ohne Ofen ist ein Knopf, der nichts
/// tut; ein Alarmknopf, der bei einer ausgeloesten Anlage nicht rot wird, ist eine verpasste
/// Nachricht; und eine Rueckmeldung ohne Frist steht an einer Wandanzeige stundenlang da. Alles
/// drei sieht man dem Bild nicht an.
final class DockzustandTests: XCTestCase {

    private func alarm(present: Bool = true, state: Double? = 0, kannSchaerfen: Bool = true)
        -> AlarmOut
    {
        AlarmOut(present: present, state: state, stateDe: "unscharf", canArm: kannSchaerfen)
    }

    // MARK: - Die Frist der Rueckmeldung

    /// `Dock.tsx:185,210`: vier Sekunden, bei einem Fehler acht.
    func testDieFristHaengtAmFehler() {
        XCTAssertEqual(Dockzustand.frist(fehler: false), 4)
        XCTAssertEqual(Dockzustand.frist(fehler: true), 8)
        XCTAssertGreaterThan(Dockzustand.fehlerfrist, Dockzustand.meldefrist)
    }

    // MARK: - Ofen und Alarm stehen nur da, wo es sie gibt

    /// `Dock.tsx:240`: `stove?.present`. Der Dienst liefert den Abschnitt auch ohne Ofen.
    func testDerOfenknopfBrauchtEinenOfen() {
        XCTAssertFalse(Dockzustand.zeigtOfen(nil))
        XCTAssertFalse(Dockzustand.zeigtOfen(StoveLiveOut(present: false)))
        // Der haeufige Fall eines Hauses ohne Ofen: ein Abschnitt, in dem nichts steht.
        XCTAssertFalse(Dockzustand.zeigtOfen(StoveLiveOut()))
        XCTAssertTrue(Dockzustand.zeigtOfen(StoveLiveOut(present: true)))
    }

    /// `Dock.tsx:242`: `alarm?.present`.
    func testDerAlarmknopfBrauchtEineAnlage() {
        XCTAssertFalse(Dockzustand.zeigtAlarm(nil))
        XCTAssertFalse(Dockzustand.zeigtAlarm(alarm(present: false)))
        XCTAssertTrue(Dockzustand.zeigtAlarm(alarm()))
    }

    // MARK: - Die Farbe der Anlage

    /// „Die Alarmanlage leuchtet, wenn sie scharf ist - rot nur, wenn sie ausgeloest hat“
    /// (`Dock.tsx:241,247-248`).
    func testDieAnlageLeuchtetScharfUndIstRotNurAusgeloest() {
        XCTAssertFalse(Dockzustand.alarmLeuchtet(alarm(state: 0)))
        XCTAssertTrue(Dockzustand.alarmLeuchtet(alarm(state: 1)))
        XCTAssertTrue(Dockzustand.alarmLeuchtet(alarm(state: 4)))
        // Ohne Messwert leuchtet nichts: ein Knopf, der ohne Auskunft leuchtet, luegt.
        XCTAssertFalse(Dockzustand.alarmLeuchtet(alarm(state: nil)))
        XCTAssertFalse(Dockzustand.alarmLeuchtet(nil))

        XCTAssertEqual(Dockzustand.alarmfarbe(alarm(state: 2)), Marken.mist)
        XCTAssertEqual(Dockzustand.alarmfarbe(alarm(state: 4)), Marken.alarm)
        XCTAssertEqual(Dockzustand.alarmfarbe(nil), Marken.mist)
    }

    // MARK: - Schaerfen

    func testGeschaerftWirdNurMitRechtUndErreichbarkeit() {
        XCTAssertTrue(Dockzustand.darfSchaerfen(alarm(), darfSchalten: true))
        XCTAssertFalse(Dockzustand.darfSchaerfen(alarm(), darfSchalten: false))
        XCTAssertFalse(
            Dockzustand.darfSchaerfen(alarm(kannSchaerfen: false), darfSchalten: true))
        XCTAssertFalse(Dockzustand.darfSchaerfen(nil, darfSchalten: true))
    }

    /// Ein Gast soll nicht „Gerade nicht erreichbar“ lesen und die Anlage fuer gestoert halten
    /// (`Dock.tsx:171-172`: erst der Gastzugang, dann die Erreichbarkeit).
    func testDerHinweisNenntDenGastzugangVorDerErreichbarkeit() {
        XCTAssertEqual(
            Dockzustand.alarmhinweis(alarm(kannSchaerfen: false), darfSchalten: false),
            Dockzustand.nurAnsicht)
        XCTAssertEqual(
            Dockzustand.alarmhinweis(alarm(kannSchaerfen: false), darfSchalten: true),
            Dockzustand.nichtErreichbar)
        XCTAssertNil(Dockzustand.alarmhinweis(alarm(), darfSchalten: true))
    }

    /// Zwei Knoepfe, „Zu Hause“ zuerst, und beide mit der Art, die der Dienst kennt
    /// (`Dock.tsx:164-165`).
    func testDieBeidenScharfknoepfe() {
        XCTAssertEqual(Dockzustand.scharfknoepfe.map(\.wort), ["Zu Hause", "Unterwegs"])
        XCTAssertEqual(Dockzustand.scharfknoepfe.map { $0.art.rawValue }, ["home", "away"])
    }

    /// Der Satz, der sagt, warum es keinen Knopf zum Entschaerfen gibt - ganz und nicht gekuerzt.
    func testDerSatzZumEntschaerfenStehtGanzDa() {
        XCTAssertTrue(Dockzustand.nurScharf.hasPrefix("Unscharf wird am Bedienteil geschaltet"))
        XCTAssertTrue(Dockzustand.nurScharf.contains("einschalten können, nicht ausschalten"))
    }
}
