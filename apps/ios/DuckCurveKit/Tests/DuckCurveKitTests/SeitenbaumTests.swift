import XCTest

@testable import DuckCurveKit

/// Dashboard und App zeigen dieselben Seiten unter denselben Adressen.
///
/// Das ist seit dem 23.11.2026 eine feste Regel des Hausherrn, und bis dahin hat sie nur
/// Sorgfalt gehalten: `Bereiche.swift` hier und `areas.ts` im Dashboard wurden von Hand
/// nebeneinander gepflegt.
///
/// `docs/seitenbaum.json` beschreibt den Seitenbaum einmal. Dieser Test haelt die App dagegen,
/// `apps/web/src/lib/seitenbaum.test.ts` das Dashboard. Wer eine Seite nur auf einer Seite
/// eintraegt, bekommt in der anderen CI einen roten Lauf, der die Abweichung beim Namen nennt.
final class SeitenbaumTests: XCTestCase {
    private struct Datei: Decodable, Equatable {
        let bereiche: [Bereichszeile]
        let einzelseiten: [Einzelzeile]
    }

    /// Eine Seite außerhalb der Bereiche, wie die gemeinsame Datei sie schreibt.
    private struct Einzelzeile: Decodable, Equatable {
        let weg: String
        let name: String
        let beschreibung: String
    }

    private struct Bereichszeile: Decodable, Equatable {
        let schluessel: String
        let weg: String
        let name: String
        let nurHausherr: Bool
        let inLeiste: Bool
        let gruppen: [Gruppenzeile]
        let reiter: [Reiterzeile]
    }

    private struct Gruppenzeile: Decodable, Equatable {
        let name: String
        let wort: String
    }

    private struct Reiterzeile: Decodable, Equatable {
        let weg: String
        let name: String
        let zeichen: String
        let farbe: String
        let zeitraum: Bool
        let nurHausherr: Bool
        let gruppe: String?
        let beschreibung: String?
        let unter: [Ansichtszeile]
    }

    private struct Ansichtszeile: Decodable, Equatable {
        let weg: String
        let name: String
    }

    /// Der Seitenbaum der App in der Schreibweise der gemeinsamen Datei.
    private var seitenbaumDerApp: [Bereichszeile] {
        Bereiche.alle.map { bereich in
            Bereichszeile(
                schluessel: bereich.schluessel.rawValue,
                weg: bereich.weg,
                name: bereich.name,
                nurHausherr: bereich.nurHausherr,
                inLeiste: bereich.inLeiste,
                gruppen: bereich.gruppen.map { Gruppenzeile(name: $0.name, wort: $0.wort) },
                reiter: bereich.reiter.map { reiter in
                    Reiterzeile(
                        weg: reiter.weg,
                        name: reiter.name,
                        zeichen: reiter.zeichen.vorlage,
                        farbe: reiter.farbe.rawValue,
                        zeitraum: reiter.mitZeitraum,
                        nurHausherr: reiter.nurHausherr,
                        gruppe: reiter.gruppe,
                        beschreibung: reiter.beschreibung,
                        unter: reiter.unter.map { Ansichtszeile(weg: $0.weg, name: $0.name) }
                    )
                }
            )
        }
    }

    /// Die gemeinsame Datei liegt im Repository, sechs Ebenen ueber dieser Quelle.
    private func gemeinsameDatei() throws -> Datei {
        var ort = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { ort.deleteLastPathComponent() }
        ort.appendPathComponent("docs/seitenbaum.json")
        return try JSONDecoder().decode(Datei.self, from: Data(contentsOf: ort))
    }

    func testStimmtMitDerGemeinsamenDateiUeberein() throws {
        let gemeinsam = try gemeinsameDatei().bereiche
        let app = seitenbaumDerApp
        XCTAssertEqual(app.map(\.name), gemeinsam.map(\.name), "Die Bereiche weichen ab")
        // Je Bereich einzeln, damit die Meldung den Bereich nennt und nicht den ganzen Baum druckt.
        for (eigen, soll) in zip(app, gemeinsam) {
            XCTAssertEqual(eigen, soll, "Der Bereich \(soll.name) weicht vom Dashboard ab")
        }
    }

    /// Jedes Zeichen, das der Seitenbaum nennt, kennt die App unter diesem Namen. Sonst stünde
    /// auf einer Kachel kein Zeichen, und niemand merkte es vor dem Gerät.
    func testJedesZeichenDesSeitenbaumsIstBekannt() throws {
        for bereich in try gemeinsameDatei().bereiche {
            for reiter in bereich.reiter {
                XCTAssertNotNil(Zeichenart(vorlage: reiter.zeichen), "\(reiter.weg): \(reiter.zeichen)")
                XCTAssertNotNil(Seitenfarbe(rawValue: reiter.farbe), "\(reiter.weg): \(reiter.farbe)")
            }
        }
    }

    /// Die Leitzahl zerfällt am letzten Leerzeichen in Zahl und Einheit, wie im Dashboard
    /// (`zahlUndEinheit`). Ein Text ohne Leerzeichen bleibt ganz die Zahl.
    func testLeitzahlZerfaelltInZahlUndEinheit() {
        XCTAssertEqual(Leitzahl("19,1 kWh").zahl, "19,1")
        XCTAssertEqual(Leitzahl("19,1 kWh").einheit, "kWh")
        XCTAssertEqual(Leitzahl("−80 %").zahl, "−80")
        XCTAssertEqual(Leitzahl("−80 %").einheit, "%")
        XCTAssertEqual(Leitzahl("0").zahl, "0")
        XCTAssertEqual(Leitzahl("0").einheit, "")
        XCTAssertEqual(Leitzahl("1 234,5 kWh").zahl, "1 234,5")
    }

    /// Die Seiten außerhalb der Bereiche sind in der App dieselben wie im Dashboard: gleiche
    /// Adresse, gleicher Name, gleicher Satz.
    func testEinzelseitenStimmenMitDerGemeinsamenDateiUeberein() throws {
        let gemeinsam = try gemeinsameDatei().einzelseiten
        let app = Bereiche.einzelseiten.map {
            Einzelzeile(weg: $0.weg, name: $0.name, beschreibung: $0.beschreibung)
        }
        XCTAssertEqual(app, gemeinsam)
    }

    /// Eine Einzelseite gehört zu keinem Bereich, wird aber als Weg gefunden, auch mit
    /// Fragezeichenteil und Schrägstrich am Ende.
    func testEinzelseiteWirdAmWegErkannt() {
        XCTAssertEqual(Bereiche.einzelseite("/konto")?.name, "Mein Zugang")
        XCTAssertEqual(Bereiche.einzelseite("/konto/")?.weg, "/konto")
        XCTAssertNil(Bereiche.einzelseite("/kontor"))
        XCTAssertNil(Bereiche.einzelseite("/system/zugang"))
        XCTAssertTrue(Bereiche.alleWege.contains("/konto"))
    }
}
