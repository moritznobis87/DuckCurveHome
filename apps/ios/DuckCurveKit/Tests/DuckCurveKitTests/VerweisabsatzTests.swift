import XCTest

@testable import DuckCurveKit

/// Gegen `apps/web/src/app/waerme/annahmen/page.tsx:22-26` - der Verweis mitten im Satz.
final class VerweisabsatzTests: XCTestCase {

    func testDerWegUeberstehtDenWegUeberEineAdresse() throws {
        for weg in ["/waerme/bilanz", "/", "/system/zugang", "/strom/pv"] {
            let adresse = try XCTUnwrap(Verweisabsatz.adresse(weg), weg)
            XCTAssertEqual(
                Verweisabsatz.weg(aus: adresse), weg,
                "Anders zusammengesetzt als zerlegt heißt: ein Verweis, der nichts tut.")
        }
    }

    func testDieAdresseTraegtEinSchemaWeilSonstSafariSieBekommt() throws {
        let adresse = try XCTUnwrap(Verweisabsatz.adresse("/waerme/bilanz"))
        XCTAssertEqual(adresse.scheme, Verweisabsatz.schema)
        XCTAssertEqual(adresse.absoluteString, "duckcurve:/waerme/bilanz")
    }

    func testEinWegOhneSchraegstrichBekommtEinen() throws {
        let adresse = try XCTUnwrap(Verweisabsatz.adresse("waerme"))
        XCTAssertEqual(Verweisabsatz.weg(aus: adresse), "/waerme")
    }

    func testEineFremdeAdresseIstKeinWegDieserApp() throws {
        let draussen = try XCTUnwrap(URL(string: "https://duckcurve.de/waerme"))
        XCTAssertNil(
            Verweisabsatz.weg(aus: draussen),
            "Sonst führt ein Tippen auf einen echten Verweis in eine Seite, die es nicht gibt.")
        XCTAssertNil(Verweisabsatz.weg(aus: try XCTUnwrap(URL(string: "mailto:a@b.de"))))
    }

    // MARK: - Der Schlussabsatz der Annahmenseite

    func testJedesStueckDesSchlussabsatzesIstZeichenbar() throws {
        for stueck in Annahmenfelder.schlussabsatz {
            switch stueck {
            case .satz(let s):
                XCTAssertFalse(s.isEmpty)
            case .verweis(let wort, let weg):
                XCTAssertFalse(wort.isEmpty)
                XCTAssertNotNil(Verweisabsatz.adresse(weg), "Ohne Adresse kein Verweis.")
            }
        }
    }

    /// **Die Vorlage zeigt noch auf die alte Adresse**, und das darf sie: `/waerme/bilanz` steht
    /// in `page.tsx:23` so da, weil Next sie serverseitig weiterleitet
    /// (`waerme/bilanz/page.tsx:14`). Die App muss deshalb denselben Weg nehmen - und er muss
    /// über ``Bereiche/ziel(_:)`` bei einer Seite ankommen, die es gibt. Ein Verweis, der
    /// unverändert auf eine Adresse ohne Seite führt, landet in `Unbekannt`.
    func testDerVerweisKommtTrotzDerWeiterleitungBeiEinerSeiteAn() {
        let weg = Annahmenfelder.schlussabsatz.compactMap { stueck -> String? in
            if case .verweis(_, let weg) = stueck { return weg }
            return nil
        }.first
        XCTAssertEqual(weg, "/waerme/bilanz", "Wörtlich wie die Vorlage (`page.tsx:23`).")
        XCTAssertEqual(Bereiche.ziel("/waerme/bilanz"), "/waerme")
        XCTAssertTrue(
            Bereiche.alleWege.contains("/waerme"),
            "Das Ziel der Weiterleitung muss eine Seite der App sein.")
    }
}
