import XCTest

@testable import DuckCurveKit

/// Die Worte und Adressen der Seite „Zugang und Sicherung“:
/// `apps/web/src/app/system/zugang/page.tsx` und `docs/openapi.json`.
///
/// **Was hier zu prüfen ist, obwohl es Text ist.** Drei Dinge: dass die Abschnitte in der
/// Reihenfolge der Vorlage stehen (der Bereichskicker nennt sie in genau dieser Folge), dass die
/// Fugen der zwei Absätze mit Festbreitenwörtern die Fachwörter wirklich treffen, und dass die
/// Jahre der Sicherung im Kalender des Hauses gerechnet sind - am 1. Januar um 00:30 ist das ein
/// anderes Jahr als in UTC.
final class ZugangsseiteTests: XCTestCase {

    private var zugang: Zugang {
        Zugang(
            grund: URL(string: "https://dch.beispiel.net")!, token: "geheim",
            geraetename: "iPad Flur")
    }

    // MARK: - Die Adresse der Sicherung

    /// `docs/openapi.json`, `/api/v1/export/{kind}`: `kind` ∈ {minutes, hours}, `year`.
    func testExportadressen() {
        XCTAssertEqual(
            zugang.export(art: .minuten, jahr: 2026)?.absoluteString,
            "https://dch.beispiel.net/api/v1/export/minutes?year=2026")
        XCTAssertEqual(
            zugang.export(art: .stunden, jahr: 2025)?.absoluteString,
            "https://dch.beispiel.net/api/v1/export/hours?year=2025")
    }

    /// Wer die App auf das BFF des Dashboards zeigt, bekommt dessen Adresse - und dort trägt
    /// der Browser eine Sitzung, die die App nicht hat (``Zugangsworte/herunterladen``).
    func testExportueberDasBff() {
        var z = zugang
        z.praefix = "/api/dch"
        XCTAssertEqual(
            z.export(art: .minuten, jahr: 2026)?.absoluteString,
            "https://dch.beispiel.net/api/dch/export/minutes?year=2026")
    }

    /// `year` hat am Dienst Grenzen (2000 bis 2100). Ein Jahr außerhalb ergibt keine Adresse,
    /// damit der Verweis wegfällt statt in eine 422 zu führen - der Fall entsteht nicht aus
    /// einem Tippfehler, sondern aus einer Uhr, die nach einem Stromausfall auf 1970 steht.
    func testJahrAusserhalbDerGrenzenErgibtKeineAdresse() {
        XCTAssertNil(zugang.export(art: .minuten, jahr: 1970))
        XCTAssertNil(zugang.export(art: .minuten, jahr: 1999))
        XCTAssertNil(zugang.export(art: .stunden, jahr: 2101))
        XCTAssertNotNil(zugang.export(art: .stunden, jahr: 2000))
        XCTAssertNotNil(zugang.export(art: .stunden, jahr: 2100))
    }

    /// Die zwei Arten und ihre zwei Wörter (`page.tsx:140, 143`) - und nur diese zwei.
    func testDieZweiArtenUndIhreWoerter() {
        XCTAssertEqual(Zugang.Exportart.allCases.map(\.rawValue), ["minutes", "hours"])
        XCTAssertEqual(Zugang.Exportart.minuten.wort, "Minutenwerte ↓")
        XCTAssertEqual(Zugang.Exportart.stunden.wort, "Stundenbilanz ↓")
    }

    // MARK: - Die Jahre der Sicherung

    /// `page.tsx:135`: `[year, year - 1]`.
    func testZweiJahreAbwaerts() {
        let jetzt = Zeit.ausIso("2026-11-20T10:00:00+01:00")!
        XCTAssertEqual(Zugangsworte.sicherungsjahre(jetzt: jetzt), [2026, 2025])
    }

    /// Gerechnet im Kalender des Hauses: um 00:30 Berliner Zeit am Neujahrstag steht im
    /// ISO-Stempel noch der 31.12. in UTC. Wer dann die Sicherung des abgelaufenen Jahres
    /// holen will, bekäme mit der UTC-Rechnung die von vorletztem.
    func testNeujahrsnachtRechnetInDerZeitDesHauses() {
        let jetzt = Zeit.ausIso("2027-01-01T00:30:00+01:00")!
        XCTAssertEqual(Zugangsworte.sicherungsjahre(jetzt: jetzt), [2027, 2026])
    }

    /// Und die Gegenprobe am anderen Ende des Jahres.
    func testSilvesterabendBleibtImAltenJahr() {
        let jetzt = Zeit.ausIso("2026-12-31T23:30:00+01:00")!
        XCTAssertEqual(Zugangsworte.sicherungsjahre(jetzt: jetzt), [2026, 2025])
    }

    // MARK: - Kurz statt lang (25.11.2026)

    /// Die Seite trägt keine Erklärtexte mehr. Was bleibt, ist je Karte ein Satz wie im
    /// Dashboard und der eine Satz der App zum Herunterladen.
    func testDieKartenSagenDasselbeWieDasDashboard() {
        XCTAssertEqual(Kontoworte.Kartenart.platz.titel, "Platzbedarf")
        XCTAssertEqual(Kontoworte.Kartenart.platz.satz, "Wie groß die Datenbank ist, Tabelle für Tabelle.")
        XCTAssertEqual(Kontoworte.Kartenart.sicherung.titel, "Sicherung")
        XCTAssertEqual(
            Kontoworte.Kartenart.sicherung.satz, "Einmal im Jahr herunterladen und woanders ablegen.")
        XCTAssertEqual(Kontoworte.Kartenart.platz.zeichen.vorlage, "chart")
        XCTAssertEqual(Kontoworte.Kartenart.sicherung.zeichen.vorlage, "calendar")
        XCTAssertEqual(Zugangsworte.sicherungszeile, "gzip-komprimiertes CSV, Minutenwerte rund 20 MB im Jahr")
    }

    /// Der Satz zum Herunterladen bleibt ein Satz und wird nicht wieder zum Absatz.
    func testDerSatzZumHerunterladenIstKurz() {
        XCTAssertLessThan(Zugangsworte.herunterladen.count, 120)
        XCTAssertTrue(Zugangsworte.herunterladen.hasSuffix("."))
        XCTAssertFalse(Zugangsworte.herunterladen.contains("\""))
    }
}
