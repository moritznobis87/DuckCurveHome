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

    // MARK: - Die Reihenfolge und die Fugen

    /// Die sechs Abschnitte der Vorlage in ihrer Reihenfolge - der Bereichskicker
    /// („Geräte koppeln · wer zusieht · Daten sichern“, `Bereiche.swift:170`) nennt die ersten
    /// drei in genau dieser Folge.
    func testUeberschriftenInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            Zugangsworte.ueberschriften,
            [
                "Zugang einrichten", "Gerade verbunden", "Platzbedarf", "Sicherung",
                "Sichtbarkeit", "Konfiguration",
            ])
    }

    /// Die Fachwörter von „Sichtbarkeit“ stehen in Festbreitenschrift und nichts sonst
    /// (`page.tsx:161-165`).
    func testSichtbarkeitSetztDreiFachwoerterInFestbreite() {
        let mono = Zugangsworte.sichtbarkeit.filter(\.mono).map(\.wort)
        XCTAssertEqual(mono, ["robots.txt", "noindex", "X-Robots-Tag"])
    }

    /// Ein Absatz in Stücken muss zusammengesetzt wieder ein Absatz sein - keine doppelten
    /// und keine fehlenden Leerzeichen an den Fugen.
    func testDieStueckeFuegenSichZuEinemSatz() {
        let ganz = Zugangsworte.sichtbarkeit.map(\.wort).joined()
        XCTAssertEqual(
            ganz,
            "Das Dashboard ist für Suchmaschinen gesperrt, und zwar über robots.txt, den noindex-Meta-Tag und den Header X-Robots-Tag. Ein Schutz vor unbefugtem Zugriff ist das nicht; dafür sorgt die Anmeldung."
        )
        XCTAssertFalse(ganz.contains("  "))
    }

    /// „Konfiguration“ nennt eine Datei in Festbreite und endet mit dem Doppelpunkt, auf den
    /// der Verweis folgt (`page.tsx:171-173`).
    func testKonfigurationNenntDieDateiUndFuehrtZuDenAnnahmen() {
        XCTAssertEqual(Zugangsworte.konfiguration.filter(\.mono).map(\.wort), ["CONFIGURATION.md"])
        XCTAssertTrue(Zugangsworte.konfiguration.map(\.wort).joined().hasSuffix(":"))
        XCTAssertEqual(Zugangsworte.annahmenweg, "/waerme/annahmen")
        // Das Ziel ist ein Weg, den die App wirklich kennt - sonst führt der Verweis auf
        // `Unbekannt`.
        XCTAssertTrue(Bereiche.alleWege.contains(Zugangsworte.annahmenweg))
    }

    // MARK: - Was die Absätze nicht sein dürfen

    /// Jeder sichtbare Absatz ist da und ist ein Satz und kein Stichwort.
    ///
    /// **Das prüft eine Lücke, die zweimal aufgefallen ist:** eine Zeichenkette, die beim
    /// Umbau leer geblieben ist, fällt auf dem Gerät nur auf, wenn man die Seite ganz
    /// herunterrollt - und in der Vorschau steht sie gar nicht.
    func testJederAbsatzStehtDaUndIstEinSatz() {
        let absaetze = [
            Zugangsworte.koppeln, Zugangsworte.vollzugriff, Zugangsworte.gast,
            Zugangsworte.sitzungsdauer, Zugangsworte.platzbedarf, Zugangsworte.sicherung,
            Zugangsworte.jahresgroesse, Zugangsworte.herunterladen,
            Zugangsworte.sicherungsschluss,
        ]
        for a in absaetze {
            XCTAssertGreaterThan(a.count, 40, "Zu kurz für einen Absatz: \(a)")
            XCTAssertFalse(a.hasPrefix(" "))
            XCTAssertFalse(a.contains("  "))
        }
        XCTAssertEqual(Zugangsworte.methode.count, 3)
    }

    /// Deutsche Anführungszeichen immer als Paar: gleich viele „ wie “.
    ///
    /// Ein mit dem geraden Zeichen geschlossenes Zitat ist im Satzbild ein Fehler, den man am
    /// Gerät übersieht, und in dieser Datei stehen vier Zitate.
    func testAnfuehrungszeichenStehenPaarweise() {
        let alles =
            ([Zugangsworte.koppeln, Zugangsworte.gast, Zugangsworte.herunterladen]
            + Zugangsworte.methode + Zugangsworte.sichtbarkeit.map(\.wort)).joined(separator: " ")
        XCTAssertEqual(
            alles.filter { $0 == "\u{201E}" }.count, alles.filter { $0 == "\u{201C}" }.count)
        XCTAssertFalse(alles.contains("\""))
    }
}
