import XCTest

@testable import DuckCurveKit

/// Der Mitteilungshinweis der Startseite: vier Bedingungen, und jede davon haelt ihn auf.
///
/// **Warum geprueft wird, wann er *nicht* dasteht.** Ein Hinweis, der einem Gast einen fremden
/// Weg anbietet, oder einer, der nach dem Wegtippen wiederkommt, ist schlimmer als keiner. Die
/// Vorlage hat vier `return` vor der Ausgabe (`MitteilungsHinweis.tsx:36-56`); hier stehen sie
/// als eine Rechnung.
final class StartseitenhinweisTests: XCTestCase {

    private func zeigt(
        _ lage: Mitteilungsstand.Lage = .aus, hausherr: Bool = true, weg: Bool = false,
        schmal: Bool = true
    ) -> Bool {
        Startseitenhinweis.zeigt(
            lage: lage, istHausherr: hausherr, weggetippt: weg, schmal: schmal)
    }

    func testImNormalfallStehtErDa() {
        XCTAssertTrue(zeigt())
    }

    /// `Home.tsx:225`: nur am Telefon. An der Wand haengt kein Geraet, das jemand anmelden will.
    func testNurAmTelefon() {
        XCTAssertFalse(zeigt(schmal: false))
    }

    /// `MitteilungsHinweis.tsx:40`: nur beim Hausherrn - die Seite dahinter ist seine.
    func testNurBeimHausherrn() {
        XCTAssertFalse(zeigt(hausherr: false))
    }

    /// „Wer ihn wegtippt, will ihn nicht wiedersehen“ (`MitteilungsHinweis.tsx:19-21`).
    func testWeggetipptBleibtWeg() {
        XCTAssertFalse(zeigt(weg: true))
    }

    /// „Hat jemand Mitteilungen abgelehnt, steht nichts da: das war eine Entscheidung“
    /// (`MitteilungsHinweis.tsx:19-21`).
    func testNachEinerAblehnungStehtNichtsDa() {
        XCTAssertFalse(zeigt(.verboten))
    }

    /// Angemeldet, halb angemeldet, gescheitert: ueberall ist das Einschalten schon geschehen.
    /// Eine Pille „Einschalten“ waere dort eine falsche Auskunft.
    func testWoSchonEingeschaltetIstStehtNichtsDa() {
        XCTAssertFalse(zeigt(.an))
        XCTAssertFalse(zeigt(.halb))
        XCTAssertFalse(zeigt(.fehler("Keine Berechtigung für Mitteilungen.")))
    }

    /// Der Satz nennt das Morning Briefing - es ist die Frage, die der Nutzer gestellt hat.
    func testDerSatzNenntDasMorningBriefing() {
        XCTAssertTrue(Startseitenhinweis.satz.contains("Morning Briefing"))
        XCTAssertEqual(Startseitenhinweis.losWort, "Einschalten")
        XCTAssertEqual(Startseitenhinweis.zuWort, "Nicht jetzt")
    }

    /// Der Weg hinter der Pille ist der, den auch die Bereichsliste fuehrt - sonst zeigt der
    /// Hinweis ins Leere.
    func testDerWegFuehrtAufDieMitteilungsseite() {
        XCTAssertEqual(Startseitenhinweis.weg, "/system/mitteilungen")
        XCTAssertNotNil(Bereiche.reiterVon(Bereiche.bereichVon(Startseitenhinweis.weg), Startseitenhinweis.weg))
    }

    /// Derselbe Merker wie in der Vorlage (`MitteilungsHinweis.tsx:25`).
    func testDerMerkerHeisstWieInDerVorlage() {
        XCTAssertEqual(Startseitenhinweis.merker, "dch-mitteilungen-hinweis")
    }
}
