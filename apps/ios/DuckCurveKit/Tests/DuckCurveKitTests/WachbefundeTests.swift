import XCTest

@testable import DuckCurveKit

/// Die Wache der Startseite, nachgezaehlt.
///
/// **Warum hier genau geprueft wird.** Die Wache ist die Stelle, an der das Haus sagt, dass es
/// gerade blind ist (`Wache.tsx:7-11`: zwei Tage lang vier satte Puffertemperaturen von
/// vorgestern). Wird aus fuenf Befunden der falsche gewaehlt, steht an der Wand eine Belanglosigkeit
/// und der Alarm nicht - und das sieht man dem Bild nicht an.
final class WachbefundeTests: XCTestCase {

    private func befund(
        _ name: String, _ schwere: WatchFindingOutSeverityWahl, seit: String? = nil,
        satz: String = "Etwas schweigt."
    ) -> WatchFindingOut {
        WatchFindingOut(
            name: name, titleDe: name, severity: schwere, since: seit, silentMin: 0, textDe: satz)
    }

    // MARK: - Hoechstens zwei

    /// `Wache.tsx:30`: `befunde.slice(0, 2)`. An der Wand rollt nichts - eine dritte Zeile
    /// schiebt die Kurve aus dem Bild.
    func testHoechstensZweiZeilen() {
        let viele = (1...5).map { befund("b\($0)", .warn) }
        XCTAssertEqual(Wachbefunde.zeilen(viele).count, 2)
        XCTAssertEqual(Wachbefunde.hoechstens, 2)
    }

    func testOhneBefundeKeineZeile() {
        XCTAssertTrue(Wachbefunde.zeilen([]).isEmpty)
    }

    /// Weniger Befunde als die Grenze: dann stehen eben weniger da und nichts wird erfunden.
    func testEinEinzelnerBefundStehtAllein() {
        let zeilen = Wachbefunde.zeilen([befund("mqtt", .alarm)])
        XCTAssertEqual(zeilen.map(\.name), ["mqtt"])
    }

    /// Eine Grenze von null ergibt keine Zeile und keinen Absturz: `prefix(0)` ist leer, und
    /// `zeilen(_:hoechstens:)` wird auch aus dem Ruhebild heraus gerufen werden koennen.
    func testEineGrenzeVonNullErgibtNichts() {
        XCTAssertTrue(Wachbefunde.zeilen([befund("b", .alarm)], hoechstens: 0).isEmpty)
        XCTAssertTrue(Wachbefunde.zeilen([befund("b", .alarm)], hoechstens: -1).isEmpty)
    }

    // MARK: - Die Reihenfolge

    /// **Die des Dienstes, unangetastet.** Er sortiert Alarm vor Warnung und bei gleicher
    /// Schwere den aelteren (`Wache.tsx:21-24`); hier wird nur abgeschnitten. Dieselbe
    /// Entscheidung trifft `Ruhebild.schwersterBefund`, und sie beide noch einmal zu
    /// behaupten hiesse, zwei Wahrheiten darueber zu haben, welcher Befund der schwerere ist.
    func testDieReihenfolgeDesDienstesBleibt() {
        let zeilen = Wachbefunde.zeilen(
            [befund("erster", .warn), befund("zweiter", .alarm), befund("dritter", .alarm)])
        XCTAssertEqual(zeilen.map(\.name), ["erster", "zweiter"])
    }

    /// Und sie ist dieselbe, die das Ruhebild aus derselben Liste nimmt - sonst stuende auf dem
    /// Bild ein anderer Befund als in der Zeile darunter.
    func testRuhebildUndWacheNehmenDenselbenErsten() {
        let befunde = [befund("erster", .warn), befund("zweiter", .alarm)]
        XCTAssertEqual(
            Wachbefunde.zeilen(befunde).first?.name,
            Ruhebild.schwersterBefund(befunde)?.name)
    }

    /// **Ein Alarm des Dienstes wird nicht von einem eigenen Befund verdraengt.**
    ///
    /// Gemessen am Fall, der es aufdeckte: der Uhrbefund (eine ``Wachbefunde/Schwere/warnung``)
    /// nahm bei `hoechstens: 1` den einen Platz des Ruhebilds, und der Alarm `puffer_still` war
    /// weg. Eine schiefe Uhr macht Zeitstempel fraglich - ein Alarm sagt, dass eine Quelle ganz
    /// schweigt, und das wiegt mehr.
    func testEinAlarmDesDienstesStehtVorDemEigenenBefund() {
        let eigen = Wachbefunde.Zeile(
            name: "hausuhr", satz: "Die Uhren gehen auseinander.", schwere: .warnung)

        XCTAssertEqual(
            Wachbefunde.zeilen([befund("mqtt", .alarm)], zuerst: [eigen], hoechstens: 1)
                .map(\.name),
            ["mqtt"])
        XCTAssertEqual(
            Wachbefunde.zeilen([befund("mqtt", .alarm)], zuerst: [eigen]).map(\.name),
            ["mqtt", "hausuhr"])
        // Zwei Alarme fuellen beide Plaetze - der eigene Befund tritt ganz zurueck.
        XCTAssertEqual(
            Wachbefunde.zeilen(
                [befund("mqtt", .alarm), befund("puffer", .alarm)], zuerst: [eigen]).map(\.name),
            ["mqtt", "puffer"])
    }

    /// **Vor den Warnungen des Dienstes steht er aber schon**, denn er entwertet deren
    /// Zeitstempel: wer die Wache liest, ohne zu wissen, dass die Uhren auseinandergehen, sucht
    /// den Fehler bei den Zahlen.
    func testDerEigeneBefundStehtVorDenWarnungenDesDienstes() {
        let eigen = Wachbefunde.Zeile(
            name: "hausuhr", satz: "Die Uhren gehen auseinander.", schwere: .warnung)
        XCTAssertEqual(
            Wachbefunde.zeilen([befund("puffer", .warn)], zuerst: [eigen], hoechstens: 1)
                .map(\.name),
            ["hausuhr"])
        XCTAssertEqual(
            Wachbefunde.zeilen([befund("fremd", .unbekannt)], zuerst: [eigen], hoechstens: 1)
                .map(\.name),
            ["hausuhr"])
    }

    /// Umsortiert wird dafuer nichts: genommen wird der vordere Lauf der Alarme, nicht alle
    /// Alarme der Liste. Steht in der Liste des Dienstes eine Warnung vor einem Alarm, bleibt
    /// sie dort stehen - die App behauptet keine zweite Sortierung.
    func testDerVordereLaufDerAlarmeZaehltUndNichtAlleAlarme() {
        let eigen = Wachbefunde.Zeile(
            name: "hausuhr", satz: "Die Uhren gehen auseinander.", schwere: .warnung)
        XCTAssertEqual(
            Wachbefunde.zeilen(
                [befund("warnung", .warn), befund("alarm", .alarm)], zuerst: [eigen]).map(\.name),
            ["hausuhr", "warnung"])
    }

    /// Eine unbekannte Schwere bringt nichts zum Absturz - `Schema.swift` laesst sie zu, damit
    /// eine neue Stufe im Dienst die App nicht umbringt.
    func testEineUnbekannteSchwereWirdGezeigt() {
        let zeilen = Wachbefunde.zeilen([befund("fremd", .unbekannt)])
        XCTAssertEqual(zeilen.map(\.name), ["fremd"])
        XCTAssertEqual(zeilen.first?.schwere, .unbekannt)
    }

    // MARK: - Der Satz und der Ton

    /// Der Satz kommt wortgleich aus dem Dienst: er landet auch als Mitteilung auf einem
    /// Telefon, wo niemand etwas zusammensetzen kann (`Wache.tsx:14-18`).
    func testDerSatzWirdNichtAngefasst() {
        let lang =
            "Die Puffertemperaturen seit 2 Tagen still - ohne sie gibt es keinen Ladezustand."
        XCTAssertEqual(Wachbefunde.zeilen([befund("puffer", .alarm, satz: lang)]).first?.satz, lang)
    }

    /// `globals.css:205-206`: Alarm in `--alert`, Warnung in `--amber-soft`, Grund je auf 10 %.
    func testDerTonFolgtDerSchwere() {
        XCTAssertEqual(Wachbefunde.Schwere.alarm.farbe, Marken.alarm)
        XCTAssertEqual(Wachbefunde.Schwere.warnung.farbe, Marken.amberWeich)
        XCTAssertEqual(Wachbefunde.Schwere.unbekannt.farbe, Marken.mist)
        XCTAssertEqual(Wachbefunde.Schwere.alarm.grundfarbe.deckung, 0.10, accuracy: 1e-9)
        // Der Grund ist dieselbe Farbe, nur blasser - nicht eine andere.
        XCTAssertEqual(Wachbefunde.Schwere.warnung.grundfarbe.hex, Marken.amberWeich.hex)
    }

    /// Zwei Befunde gleichen Namens kommen nicht vor, und der Name ist der Schluessel der
    /// Liste (`Wache.tsx:31`).
    func testDerNameIstDerSchluessel() {
        XCTAssertEqual(Wachbefunde.zeilen([befund("mqtt", .alarm)]).first?.id, "mqtt")
    }
}
