import XCTest

@testable import DuckCurveKit

/// Gegen `apps/web/src/components/alfred/hilfetexte.ts` und `strom.ts`.
final class AlfredTests: XCTestCase {

    // MARK: - Wo man steht

    func testDerOrtKommtAusDenBereichenUndNichtAusEinerZweitenListe() {
        let o = Alfred.ortBestimmen("/waerme/waermepumpe/betrieb")
        XCTAssertEqual(o.bereich, "Technik")
        XCTAssertEqual(o.reiter, "Wärmepumpe")
        XCTAssertTrue(o.text?.hasPrefix("Betrieb zeigt") == true, o.text ?? "nil")
    }

    func testEinSchraegstrichAmEndeAendertNichts() {
        XCTAssertEqual(Alfred.ortBestimmen("/geld/").text, Alfred.ortBestimmen("/geld").text)
        XCTAssertEqual(Alfred.saeubere("/"), "/")
        XCTAssertEqual(Alfred.saeubere("/haus//"), "/haus")
    }

    func testOhneEigenenTextNimmtDerOrtDenDesReitersOderBereichs() {
        // Eine Adresse, die es in `seiten` nicht gibt, faellt auf ihren Bereich zurueck.
        let o = Alfred.ortBestimmen("/gibtesnicht")
        XCTAssertNotNil(o.bereich)
        XCTAssertNotNil(o.text, "Lieber der Text des Bereichs als gar keiner.")
    }

    func testJedeSeiteDerAnwendungHatEinenText() {
        // **Das ist der eigentliche Zweck dieses Tests.** Kommt ein Reiter dazu und niemand
        // schreibt Alfred einen Satz, sagt er dort „Zu dieser Seite habe ich noch keinen
        // Hilfetext" - und das faellt sonst niemandem auf.
        let ohne = Bereiche.alleWege.filter { Alfred.seiten[$0] == nil }
        XCTAssertTrue(ohne.isEmpty, "Ohne Hilfetext: \(ohne)")
    }

    func testDieWegbeschreibungNenntJedenBereichUndSeineReiter() {
        let w = Alfred.wegweiser()
        for b in Bereiche.alle {
            XCTAssertTrue(w.contains(b.name), "Bereich \(b.name) fehlt")
            for r in b.reiter {
                XCTAssertTrue(w.contains(r.name), "Reiter \(r.name) fehlt")
            }
        }
    }

    func testDasWissenSagtWoGefragtWurde() {
        let w = Alfred.wissen(weg: "/strom/speicher")
        XCTAssertTrue(w.contains("Bereich Energie, Reiter Speicher"), w)
        XCTAssertTrue(w.contains("AUFBAU DER ANWENDUNG:"))
        XCTAssertTrue(w.contains("Speicher zeigt Laden"))
    }

    // MARK: - Der Verlauf

    private func nachricht(_ wer: AlfredWechselInWerWahl, _ text: String) -> Alfred.Nachricht {
        Alfred.Nachricht(wer: wer, inhalt: text)
    }

    func testDerVerlaufGehtHoechstensZehnWechselWeit() {
        let viele = (0..<25).map { nachricht($0 % 2 == 0 ? .nutzer : .alfred, "Nr \($0)") }
        let v = Alfred.verlaufFuerDienst(viele)
        XCTAssertEqual(v.count, 10)
        XCTAssertEqual(v.last?.inhalt, "Nr 24", "Die letzten zehn, nicht die ersten.")
        XCTAssertEqual(v.first?.inhalt, "Nr 15")
    }

    func testEinKurzerVerlaufGehtGanz() {
        let v = Alfred.verlaufFuerDienst([nachricht(.nutzer, "Hallo")])
        XCTAssertEqual(v.count, 1)
        XCTAssertEqual(v[0].wer, .nutzer)
    }

    // MARK: - Vorschläge

    private func schalten(_ an: Bool, warAn: Bool?) -> AlfredVorschlagOut {
        AlfredVorschlagOut(
            art: .schalten, ziel: .text("terrace_light"), name: "Licht Terrasse", an: an,
            warAn: warAn)
    }

    private func sollwert(_ alt: Double?, _ neu: Double?) -> AlfredVorschlagOut {
        AlfredVorschlagOut(art: .sollwert, ziel: .ganz(3), name: "Arbeiten", alt: alt, neu: neu)
    }

    func testEinSchaltvorschlagStehtAlsSatz() {
        XCTAssertEqual(Alfred.vorschlagText(schalten(true, warAn: false)), "Licht Terrasse einschalten")
        XCTAssertEqual(Alfred.vorschlagText(schalten(false, warAn: true)), "Licht Terrasse ausschalten")
    }

    func testDieBestaetigungZeigtVorherUndNachher() {
        XCTAssertEqual(
            Alfred.vorschlagAenderung(schalten(true, warAn: false)), "Licht Terrasse: aus → ein")
        XCTAssertEqual(
            Alfred.vorschlagAenderung(schalten(false, warAn: true)), "Licht Terrasse: ein → aus")
    }

    func testEinUnbekannterVorzustandWirdNichtErraten() {
        XCTAssertEqual(
            Alfred.vorschlagAenderung(schalten(true, warAn: nil)), "Licht Terrasse: ? → ein",
            "Ein geratenes „aus“ waere eine Behauptung ueber den Zustand des Hauses.")
    }

    func testEinSollwertvorschlagNenntBeideZahlen() {
        XCTAssertEqual(Alfred.vorschlagText(sollwert(20, 21.5)), "Arbeiten: Soll 20 → 21,5 °C")
        XCTAssertEqual(
            Alfred.vorschlagAenderung(sollwert(20, 21.5)),
            "Arbeiten: Solltemperatur 20 °C → 21,5 °C")
    }

    func testFehlendeZahlenStehenAlsFragezeichen() {
        XCTAssertEqual(Alfred.vorschlagText(sollwert(nil, 21)), "Arbeiten: Soll ? → 21 °C")
        XCTAssertEqual(
            Alfred.vorschlagAenderung(sollwert(nil, nil)), "Arbeiten: Solltemperatur ? → ?")
    }

    // MARK: - Was wirklich ausgefuehrt wird

    func testEinSchaltvorschlagWirdZuEinemSchaltbefehl() {
        XCTAssertEqual(
            Alfred.ausfuehrung(schalten(true, warAn: false)),
            .schalten(schluessel: "terrace_light", an: true))
    }

    func testEinSollwertvorschlagWirdZuEinerRaumstellung() {
        XCTAssertEqual(Alfred.ausfuehrung(sollwert(20, 21.5)), .sollwert(raum: 3, grad: 21.5))
    }

    func testEineRaumkennungAlsTextZaehltAuch() {
        let v = AlfredVorschlagOut(art: .sollwert, ziel: .text("7"), name: "Bad", neu: 22)
        XCTAssertEqual(Alfred.ausfuehrung(v), .sollwert(raum: 7, grad: 22))
    }

    func testOhneBrauchbaresZielWirdNichtsAusgefuehrt() {
        XCTAssertNil(
            Alfred.ausfuehrung(
                AlfredVorschlagOut(art: .schalten, ziel: .nichts, name: "Licht", an: true)))
        XCTAssertNil(
            Alfred.ausfuehrung(
                AlfredVorschlagOut(art: .schalten, ziel: .text(""), name: "Licht", an: true)))
        XCTAssertNil(
            Alfred.ausfuehrung(
                AlfredVorschlagOut(art: .sollwert, ziel: .text("Bad"), name: "Bad", neu: 22)))
    }

    func testOhneZustandOderZieltemperaturWirdNichtsAusgefuehrt() {
        XCTAssertNil(
            Alfred.ausfuehrung(
                AlfredVorschlagOut(art: .schalten, ziel: .text("terrace_light"), name: "Licht")),
            "Ein Schaltbefehl ohne „an“ waere geraten.")
        XCTAssertNil(Alfred.ausfuehrung(sollwert(20, nil)))
    }

    func testEineUnbekannteArtWirdNichtAusgefuehrt() {
        let v = AlfredVorschlagOut(art: .unbekannt, ziel: .text("x"), name: "X", an: true)
        XCTAssertNil(
            Alfred.ausfuehrung(v),
            "Ein neuer Vorschlagstyp darf nicht als Schalten durchgehen.")
    }

    // MARK: - Die Schritte

    func testJedesBekannteWerkzeugHatEinenSatz() {
        XCTAssertEqual(Alfred.schrittText("energiebilanz"), "Ich hole die Strombilanz …")
        XCTAssertEqual(Alfred.schrittText("wochenrueckblick"), "Ich stelle die Woche zusammen …")
    }

    func testEinUnbekanntesWerkzeugBekommtDenAllgemeinenSatzUndKeineKennung() {
        XCTAssertEqual(Alfred.schrittText("ganz_neues_werkzeug"), "Ich arbeite daran …")
        XCTAssertFalse(Alfred.schrittText("ganz_neues_werkzeug").contains("_"))
    }

    // MARK: - Der Hinweis nach der KI-Verordnung

    func testOhneModellSagtDerHinweisDassNichtsDasHausVerlaesst() {
        XCTAssertEqual(Alfred.hinweis(nil), Alfred.Texte.hinweisOhneModell)
        XCTAssertEqual(
            Alfred.hinweis(AlfredZustandOut(bereit: false, anbieter: "Anthropic")),
            Alfred.Texte.hinweisOhneModell)
        XCTAssertTrue(Alfred.hinweis(nil).contains("nichts verlässt das Haus"))
    }

    func testMitModellStehtDerAnbieterImHinweis() {
        let h = Alfred.hinweis(AlfredZustandOut(bereit: true, anbieter: "Anthropic"))
        XCTAssertTrue(h.contains("Anthropic"), h)
        XCTAssertTrue(h.contains("Er kann irren."), "Artikel 50 verlangt die Kennzeichnung.")
        XCTAssertTrue(h.contains("schaltet nichts ohne deine Bestätigung"))
    }

    func testEinLeererAnbieternameZaehltNichtAlsAnbieter() {
        XCTAssertEqual(
            Alfred.hinweis(AlfredZustandOut(bereit: true, anbieter: "")),
            Alfred.Texte.hinweisOhneModell)
        XCTAssertEqual(
            Alfred.hinweis(AlfredZustandOut(bereit: true)), Alfred.Texte.hinweisOhneModell)
    }

    // MARK: - Die vorbereiteten Antworten

    func testWasKannAlfredHaengtDavonAbObEinModellDaIst() {
        XCTAssertEqual(
            Alfred.antwortWasKannAlfred(nil), Alfred.Texte.antwortWasKannAlfredOhneModell)
        XCTAssertEqual(
            Alfred.antwortWasKannAlfred(AlfredZustandOut(bereit: true, anbieter: "X")),
            Alfred.Texte.antwortWasKannAlfred)
    }

    func testDieSeitenantwortIstEinVorbereiteterTextUndKeinModell() {
        XCTAssertEqual(Alfred.antwortSeite(weg: "/waerme/fahrplan"), Alfred.seiten["/waerme/fahrplan"])
    }
}
