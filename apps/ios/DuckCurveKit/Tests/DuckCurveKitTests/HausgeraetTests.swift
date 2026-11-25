import XCTest

@testable import DuckCurveKit

/// Die Seite „Hausgerät“ ohne Oberfläche: Namen, Dauern, Sperre, Sätze, und dass die Antwort der
/// API mit dem erzeugten Schema gelesen wird.
final class HausgeraetTests: XCTestCase {
    private func lies<T: Decodable>(_ json: String, _ typ: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    func testAntwortDerApiWirdGelesen() throws {
        let g = try lies(
            """
            {"unterstuetzt": true, "bericht_am": "2026-11-20T09:00:00Z", "bericht_alt": false,
             "rechner": {"name": "duckcurve", "laufzeit_s": 3600, "kerne": 4, "last": [0.1, 0.2, 0.3],
                         "temperatur_c": 51.5, "temperatur_ampel": "gut", "drosselung": "0x50000",
                         "drosselung_de": ["Seit dem Start war die Spannung mindestens einmal zu niedrig."],
                         "drosselung_ampel": "warn", "speicher_gesamt_mb": 4096, "speicher_frei_mb": 3000,
                         "speicher_ampel": "gut", "platten": [{"ort": "/", "gesamt_bytes": 500000000000,
                         "frei_bytes": 420000000000, "ampel": "gut"}]},
             "dienste": [{"name": "web", "zustand": "running", "gesundheit": "unhealthy", "neustarts": 0,
                          "ampel": "schlecht", "text_de": "Läuft, aber die Prüfung schlägt fehl."}],
             "api": {"version": "0.1.0", "commit": "abc1234", "modus": "live", "laufzeit_s": 60,
                     "rss_mb": 200.5, "quellen": [], "befunde": [], "ampel": "gut"},
             "ampel": "schlecht", "text_de": "web: Läuft, aber die Prüfung schlägt fehl."}
            """, GeraetOut.self)
        XCTAssertEqual(g.dienste.first?.name, "web")
        XCTAssertEqual(Hausgeraet.Ampel(g.dienste.first?.ampel?.rawValue), .schlecht)
        XCTAssertEqual(Hausgeraet.Ampel(g.rechner?.drosselungAmpel?.rawValue), .warn)
        XCTAssertEqual(g.einheiten, [])
        XCTAssertNil(g.sicherung)
    }

    func testAmpelOhneAngabe() {
        XCTAssertEqual(Hausgeraet.Ampel(nil), .aus)
        XCTAssertEqual(Hausgeraet.Ampel("—unbekannt—"), .aus)
        XCTAssertEqual(Hausgeraet.Ampel("warn").wort, "Hinweis")
    }

    func testNamenWieImDashboard() {
        // Dieselben Wörter wie apps/web/src/components/geraet/Geraet.tsx (DIENSTNAMEN).
        XCTAssertEqual(Hausgeraet.dienstname("postgres"), "Datenbank")
        XCTAssertEqual(Hausgeraet.dienstname("web"), "Oberfläche")
        XCTAssertEqual(Hausgeraet.dienstname("unbekannt"), "unbekannt")
    }

    func testDauer() {
        XCTAssertEqual(Hausgeraet.dauer(sekunden: 42), "42 s")
        XCTAssertEqual(Hausgeraet.dauer(sekunden: 3_720), "1 h 2 min")
        XCTAssertEqual(Hausgeraet.dauer(sekunden: 90_000), "1 T 1 h")
        let jetzt = Hausgeraet.zeit("2026-11-20T10:00:00Z")
        XCTAssertEqual(Hausgeraet.seit(iso: "2026-11-20T09:30:00.123456+00:00", jetzt: jetzt), "30 min")
        XCTAssertEqual(Hausgeraet.seit(iso: nil), "–")
    }

    func testBeschaeftigtUndAktionssatz() throws {
        var g = try lies(
            """
            {"unterstuetzt": true, "api": {"version": "1", "commit": "x", "modus": "live", "laufzeit_s": 1, "rss_mb": 1},
             "letzte_aktion": {"aktion": "neustart", "dienst": "web", "zustand": "laeuft"}}
            """, GeraetOut.self)
        XCTAssertTrue(Hausgeraet.beschaeftigt(g))
        XCTAssertEqual(Hausgeraet.aktionssatz(g)?.text, "Neustart Oberfläche läuft …")
        g.letzteAktion = GeraetAktionOut(aktion: "neustart", dienst: "alle", zustand: "fehler", meldung: "")
        XCTAssertFalse(Hausgeraet.beschaeftigt(g))
        let satz = try XCTUnwrap(Hausgeraet.aktionssatz(g))
        XCTAssertTrue(satz.fehler)
        XCTAssertTrue(satz.text.hasPrefix("Neustart aller Dienste"))
        XCTAssertTrue(satz.text.hasSuffix("fehlgeschlagen."))
        g.letzteAktion = nil
        g.beschaeftigt = "Es läuft bereits ein Update."
        XCTAssertTrue(Hausgeraet.beschaeftigt(g))
    }

    func testGescheiterteFassungDraengtNicht() throws {
        let s = try lies(
            """
            {"unterstuetzt": true, "verfuegbar": "bbbbbbbbbbbb", "update_verfuegbar": true, "zustand": "zurueckgerollt",
             "zuletzt": {"ergebnis": "zurueckgerollt", "von": "aaaaaaaaaaaa", "nach": "bbbbbbbbbbbb"}}
            """, UpdateStatusOut.self)
        XCTAssertTrue(Hausgeraet.schonGescheitert(s))
        XCTAssertFalse(Hausgeraet.updateLaeuft(s))
        XCTAssertEqual(Hausgeraet.updateErgebnis(s), "Die neue Fassung kam nicht gesund hoch; die vorherige läuft wieder.")
        var neuer = s
        neuer.verfuegbar = "cccccccccccc"
        XCTAssertFalse(Hausgeraet.schonGescheitert(neuer))
        neuer.anfrageOffen = true
        XCTAssertTrue(Hausgeraet.updateLaeuft(neuer))
    }

    func testPrognoseUndGroessen() throws {
        XCTAssertEqual(Hausgeraet.bytes(1_200_000_000), "1,2 GB")
        XCTAssertEqual(Hausgeraet.bytes(2_500_000_000_000), "2,5 TB")
        XCTAssertEqual(Hausgeraet.bytes(nil), "–")
        XCTAssertEqual(Hausgeraet.ungefaehr(tage: 380), "in etwa 13 Monaten")
        let p = try lies(
            """
            {"tage_verlauf": 20, "platte_bytes_pro_tag": 1200000000, "platte_voll_in_tagen": 380,
             "datenbank_bytes_pro_tag": 2000000}
            """, GeraetPrognoseOut.self)
        XCTAssertEqual(Hausgeraet.prognosesaetze(p), [
            "Die SSD füllt sich um 1,2 GB pro Tag; bei diesem Tempo ist sie in etwa 13 Monaten voll.",
            "Die Datenbank wächst um 2 MB pro Tag.",
        ])
        let kurz = try lies("{\"tage_verlauf\": 2.5}", GeraetPrognoseOut.self)
        XCTAssertTrue(Hausgeraet.prognosesaetze(kurz)[0].contains("sieben Tage"))
    }

    func testPlatzWieImDashboard() throws {
        let g = try lies(
            """
            {"unterstuetzt": true, "api": {"version": "1", "commit": "x", "modus": "live", "laufzeit_s": 1, "rss_mb": 1},
             "rechner": {"platten": [{"ort": "/", "gesamt_bytes": 500000000000, "frei_bytes": 420000000000}],
                         "docker_platz": {"images_bytes": 30000000000, "container_bytes": 1000000,
                                          "volumes_bytes": 10000000000, "cache_bytes": 9000000000}},
             "sicherung": {"anzahl": 3, "gesamt_bytes": 1000000000}}
            """, GeraetOut.self)
        let teile = try XCTUnwrap(Hausgeraet.platz(g))
        XCTAssertEqual(teile.map { Int((Double($0.bytes) / 1e9).rounded()) }, [39, 10, 1, 30, 420])
    }

    func testLinieReisstAnLuecken() throws {
        let v = try lies(
            """
            {"unterstuetzt": true, "schritt_min": 5, "punkte": [
              {"t": "2026-11-20T10:00:00Z", "cpu_prozent": 1},
              {"t": "2026-11-20T10:05:00Z", "cpu_prozent": 2},
              {"t": "2026-11-20T10:30:00Z", "cpu_prozent": 3},
              {"t": "2026-11-20T10:35:00Z"},
              {"t": "2026-11-20T10:40:00Z", "cpu_prozent": 5}]}
            """, GeraetVerlaufOut.self)
        let linie = Hausgeraet.linie(v.punkte, schrittMin: 5) { $0.cpuProzent }
        XCTAssertEqual(linie.map(\.wert), [1, 2, 3, 5])
        XCTAssertEqual(linie.map(\.stueck), [0, 0, 1, 2])
    }

    func testUpdatehinweis() throws {
        let s = try lies(
            """
            {"unterstuetzt": true, "verfuegbar": "bbbbbbbbbbbb", "update_verfuegbar": true,
             "neuerungen": [{"sha": "b", "titel": "x"}, {"sha": "c", "titel": "y"}]}
            """, UpdateStatusOut.self)
        XCTAssertTrue(Hausgeraet.zeigeHinweis(s, weg: "/", hausherr: true, weggeklickt: nil))
        XCTAssertFalse(Hausgeraet.zeigeHinweis(s, weg: "/", hausherr: false, weggeklickt: nil))
        XCTAssertFalse(Hausgeraet.zeigeHinweis(s, weg: "/system/geraet", hausherr: true, weggeklickt: nil))
        XCTAssertFalse(Hausgeraet.zeigeHinweis(s, weg: "/", hausherr: true, weggeklickt: "bbbbbbbbbbbb"))
        XCTAssertTrue(Hausgeraet.zeigeHinweis(s, weg: "/", hausherr: true, weggeklickt: "aaaaaaaaaaaa"))
        XCTAssertEqual(Hausgeraet.hinweissatz(s), "Für Duck Curve steht ein Update bereit mit 2 Neuerungen.")
        var laeuft = s
        laeuft.zustand = "laeuft"
        XCTAssertTrue(Hausgeraet.zeigeHinweis(laeuft, weg: "/", hausherr: true, weggeklickt: "bbbbbbbbbbbb"))
        XCTAssertTrue(Hausgeraet.hinweissatz(laeuft).hasPrefix("Duck Curve wird gerade aktualisiert"))
    }

    func testReiterNurFuerDenHausherrn() {
        XCTAssertEqual(Bereiche.bereichVon("/system/geraet").schluessel, .system)
    }

    /// Dieselben Zeichen wie im Dashboard (`abschnitte.ts`, `abschnitte.test.ts`).
    func testJederAbschnittHatDasZeichenDesDashboards() {
        let alsVorlage = Hausgeraet.abschnittszeichen.mapValues(\.vorlage)
        XCTAssertEqual(
            alsVorlage,
            [
                "Dienste": "dashboard", "Rechenkern": "bolt", "Gerät": "house",
                "SSD-Gesundheit": "shield", "Platz auf der SSD": "battery", "Verlauf": "chart",
                "Sicherung": "calendar", "Abläufe auf dem Gerät": "clock", "Software": "loop",
                "Neu starten": "alert",
            ])
        XCTAssertEqual(Hausgeraet.zeichen("unbekannt"), .anzeige)
    }
}

extension Hausgeraet {
    static func zeit(_ iso: String) -> Date { Zeitpunkt.lies(iso)! }
}
