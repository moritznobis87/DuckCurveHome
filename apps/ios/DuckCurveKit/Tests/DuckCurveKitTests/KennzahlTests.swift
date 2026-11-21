import XCTest

@testable import DuckCurveKit

/// Der Ton einer Kachel - und welche Farbe er bedeutet.
///
/// **Was dieser Test leisten kann und was nicht.** Die Zuordnung Ton zu Farbe steht in
/// `apps/ios/DuckCurveHome/Gestalt/Farben.swift`, und die Datei gehoert zur Oberflaeche: unter
/// Linux wird sie nicht uebersetzt, nur geparst. Nachrechenbar ist hier das, worauf sie zeigt -
/// die Marken, aus denen `Farbe.ton` seine Farben nimmt. Dass ``Kennzahl/Ton/alarm`` und
/// ``Kennzahl/Ton/glut`` auf zwei verschiedene Marken zeigen muessen, ist der ganze Grund, aus
/// dem es den Alarmton gibt; faellt der Unterschied weg, ist der Ton ueberfluessig geworden und
/// jemand soll das hier sehen.
final class KennzahlTests: XCTestCase {

    // MARK: - Der Ton fuer `--alert`

    /// `--alert` der Vorlage ist #E0533D (`apps/web/src/styles/tokens.css:64`), und `Stat.tsx:5`
    /// wie `PeriodStrip.tsx:19` fuehren den Ton `ember` genau darauf.
    func testDerAlarmtonZeigtAufDieAlarmfarbeDerVorlage() {
        XCTAssertEqual(Marken.alarm.hex, "#E0533D")
    }

    /// **`glut` war der falsche Ersatz und nicht nur ein ungenauer.** Er ist die Farbe der
    /// Waermepumpe, und die ist ausdruecklich so gewaehlt, dass sie von `alarm` absteht
    /// (`Gestalt/Marken.swift:94-97`).
    func testAlarmUndGlutSindZweiVerschiedeneFarben() {
        XCTAssertEqual(Marken.waermepumpe.hex, "#E0966B")
        XCTAssertNotEqual(Marken.alarm, Marken.waermepumpe)
    }

    /// Der Rohwert ist der Name, wie bei den sechs Geschwistern: die Vorlage schreibt an jede
    /// Kachel ein Wort und keine Farbe.
    func testDerAlarmtonTraegtSeinenNamenAlsRohwert() {
        XCTAssertEqual(Kennzahl.Ton.alarm.rawValue, "alarm")
        XCTAssertNotEqual(Kennzahl.Ton.alarm, .glut)
    }

    // MARK: - Die Vorgabe

    /// Ohne Angabe bleibt der Ton `normal` - der Alarmton kommt nicht von selbst an eine Zahl.
    func testOhneAngabeIstDerTonNormal() {
        XCTAssertEqual(Kennzahl(wort: "Netzbezug", wert: "12,4").ton, .normal)
        XCTAssertEqual(Kennzahl(wort: "Netzbezug", wert: "12,4", ton: .alarm).ton, .alarm)
    }
}
