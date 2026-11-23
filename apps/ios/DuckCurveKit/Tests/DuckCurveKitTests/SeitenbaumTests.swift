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
    }

    private struct Bereichszeile: Decodable, Equatable {
        let schluessel: String
        let weg: String
        let name: String
        let reiter: [Reiterzeile]
    }

    private struct Reiterzeile: Decodable, Equatable {
        let weg: String
        let name: String
        let zeitraum: Bool
        let nurHausherr: Bool
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
                reiter: bereich.reiter.map { reiter in
                    Reiterzeile(
                        weg: reiter.weg,
                        name: reiter.name,
                        zeitraum: reiter.mitZeitraum,
                        nurHausherr: reiter.nurHausherr,
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
}
