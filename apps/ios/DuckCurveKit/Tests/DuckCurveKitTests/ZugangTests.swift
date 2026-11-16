import XCTest

@testable import DuckCurveKit

/// Adressen, Kopfzeilen, Gerätekennung.
///
/// Das ist die Stelle, an der die App das nachholt, was im Dashboard das BFF leistet. Ein Fehler
/// hier ist nicht sichtbar, sondern still: die Anfrage geht durch, und im Protokoll steht nur
/// nicht mehr, wer sie ausgeloest hat.
final class ZugangTests: XCTestCase {
    private var zugang: Zugang {
        Zugang(
            grund: URL(string: "https://dch.beispiel.net")!,
            token: "geheim",
            geraetename: "iPad Flur"
        )
    }

    func testAdresseSetztDenPraefix() {
        XCTAssertEqual(zugang.adresse("/live/state")?.absoluteString, "https://dch.beispiel.net/api/v1/live/state")
        XCTAssertEqual(zugang.adresse("live/state")?.absoluteString, "https://dch.beispiel.net/api/v1/live/state")
    }

    /// Ein Grund mit Pfad kommt vor, wenn der Dienst hinter einem Pfad liegt.
    func testAdresseMitPfadImGrund() {
        var z = zugang
        z.grund = URL(string: "https://beispiel.net/haus/")!
        XCTAssertEqual(z.adresse("/plan")?.absoluteString, "https://beispiel.net/haus/api/v1/plan")
    }

    /// Wer die App auf das Dashboard zeigen laesst, bekommt dessen Gastregeln mit.
    func testAdresseUeberDasBff() {
        var z = zugang
        z.praefix = "/api/dch"
        XCTAssertEqual(z.adresse("/live/state")?.absoluteString, "https://dch.beispiel.net/api/dch/live/state")
    }

    func testFragenWerdenAngehaengtUndSortiert() {
        let a = zugang.adresse("/energy/summary", ["period": "week", "anchor": "2026-11-16"])
        // Sortiert, damit dieselbe Abfrage immer dieselbe Adresse ergibt.
        XCTAssertEqual(a?.absoluteString, "https://dch.beispiel.net/api/v1/energy/summary?anchor=2026-11-16&period=week")
    }

    /// Ein `nil` ist keine Frage: der Parameter faellt weg, statt als `=` dazustehen.
    func testLeereFragenFallenWeg() {
        let a = zugang.adresse("/history", ["range": "today", "start": nil])
        XCTAssertEqual(a?.absoluteString, "https://dch.beispiel.net/api/v1/history?range=today")
        XCTAssertEqual(zugang.adresse("/plan", [:])?.absoluteString, "https://dch.beispiel.net/api/v1/plan")
    }

    /// **Die Falle, die eine Stunde kostet.** `URLComponents` laesst `+` in einer Frage stehen,
    /// weil RFC 3986 es dort erlaubt. Jeder Webdienst liest eine Frage aber als Formulardaten,
    /// und dort ist `+` ein Leerzeichen: ein Zeitstempel mit Zeitzonenversatz kaeme mit einer
    /// Stunde Fehler an, und das Diagramm waere verschoben, ohne dass etwas auffaellt.
    func testPlusInEinerFrageWirdEntschaerft() {
        let a = zugang.adresse("/history", ["start": "2026-11-16T00:00:00+01:00"])
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.absoluteString.hasSuffix("start=2026-11-16T00:00:00%2B01:00"), a!.absoluteString)
        XCTAssertFalse(a!.absoluteString.contains("+"), a!.absoluteString)
    }

    /// Der Doppelpunkt darf stehen bleiben: er ist in einer Frage erlaubt und bedeutet nichts.
    /// `Zeit.iso` liefert ohnehin immer `Z`, also ist das der Normalfall.
    func testDoppelpunktBleibtLesbar() {
        let a = zugang.adresse("/history", ["start": "2026-11-16T00:00:00Z"])
        XCTAssertEqual(a?.absoluteString, "https://dch.beispiel.net/api/v1/history?start=2026-11-16T00:00:00Z")
    }

    /// Ein Trennzeichen im Wert darf die Frage nicht aufbrechen.
    func testTrennzeichenImWertBrechenNichtAus() {
        let a = zugang.adresse("/suche", ["q": "a&b=c?d#e"])
        XCTAssertNotNil(a)
        XCTAssertEqual(a?.query, "q=a%26b%3Dc%3Fd%23e")
    }

    func testKopfzeilenTragenTokenUndUrheber() {
        let k = zugang.kopfzeilen
        XCTAssertEqual(k["authorization"], "Bearer geheim")
        XCTAssertEqual(k["x-dch-urheber-art"], "geraet")
        XCTAssertEqual(k["x-dch-urheber-name"], "iPad Flur")
        XCTAssertEqual(k["x-dch-urheber-geraet"], "iPad Flur")
        XCTAssertEqual(k["x-dch-urheber-id"], "ipad-flur")
        XCTAssertEqual(k["x-dch-urheber-rolle"], "owner")
    }

    /// Ohne Token laeuft der Dienst im Demo-Betrieb. Dann darf keine leere Kopfzeile stehen -
    /// `Bearer ` mit nichts dahinter ist ein ungueltiges Token, kein fehlendes.
    func testOhneTokenKeineLeereKopfzeile() {
        var z = zugang
        z.token = ""
        XCTAssertNil(z.kopfzeilen["authorization"])
    }

    func testGastWirdAlsGastGemeldet() {
        var z = zugang
        z.rolle = .gast
        XCTAssertEqual(z.kopfzeilen["x-dch-urheber-rolle"], "guest")
    }

    /// `urheber.py` beschneidet die Kennung auf 64 Zeichen und erwartet etwas, das sich in einer
    /// Datenbankspalte durchsuchen laesst.
    func testGeraetekennungIstEntschaerft() {
        func kennung(_ name: String) -> String {
            var z = zugang
            z.geraetename = name
            return z.geraetekennung
        }
        XCTAssertEqual(kennung("iPad Flur"), "ipad-flur")
        XCTAssertEqual(kennung("Moritz' iPhone 17 Pro"), "moritz-iphone-17-pro")
        XCTAssertEqual(kennung("Küche – oben"), "küche-oben")
        XCTAssertEqual(kennung("  ...  "), "")
        XCTAssertEqual(kennung(String(repeating: "a", count: 200)).count, 64)
    }

    func testEingerichtetBrauchtEinenGastgeber() {
        XCTAssertTrue(zugang.istEingerichtet)
        var z = zugang
        z.grund = URL(string: "file:///tmp")!
        XCTAssertFalse(z.istEingerichtet)
    }

    /// Der Zugang wird gespeichert (die Adresse in den Einstellungen, das Token im
    /// Schluesselbund). Also muss er sich schreiben und wieder lesen lassen.
    func testZugangUeberlebtSpeichern() throws {
        let roh = try JSONEncoder().encode(zugang)
        let zurueck = try JSONDecoder().decode(Zugang.self, from: roh)
        XCTAssertEqual(zurueck, zugang)
    }
}

/// Backoff und Aufsicht.
final class VerbindungspolitikTests: XCTestCase {
    func testWartezeitVerdoppeltSichBisZurGrenze() {
        var p = Verbindungspolitik()
        // Ohne Streuung, damit die Zahlen zu prüfen sind.
        XCTAssertEqual(p.gescheitert(zufall: 0), 1.0)
        XCTAssertEqual(p.gescheitert(zufall: 0), 2.0)
        XCTAssertEqual(p.gescheitert(zufall: 0), 4.0)
        XCTAssertEqual(p.gescheitert(zufall: 0), 8.0)
        XCTAssertEqual(p.gescheitert(zufall: 0), 16.0)
        XCTAssertEqual(p.gescheitert(zufall: 0), 30.0)
        // Und bleibt dort.
        for _ in 0..<20 { XCTAssertEqual(p.gescheitert(zufall: 0), 30.0) }
    }

    /// Die Streuung loest den Gleichschritt mehrerer Anzeigen auf.
    func testStreuungLiegtObenDrauf() {
        var p = Verbindungspolitik()
        XCTAssertEqual(p.gescheitert(zufall: 1.0), 1.5)
        XCTAssertEqual(p.gescheitert(zufall: 0.5), 2.25)
    }

    /// Ein gelungener Versuch setzt zurueck. Sonst wartet eine Anzeige, die einmal eine schlechte
    /// Nacht hatte, fuer immer 30 Sekunden.
    func testGelungenSetztZurueck() {
        var p = Verbindungspolitik()
        for _ in 0..<5 { _ = p.gescheitert(zufall: 0) }
        XCTAssertEqual(p.fehlversuche, 5)
        p.gelungen()
        XCTAssertEqual(p.fehlversuche, 0)
        XCTAssertEqual(p.gescheitert(zufall: 0), 1.0)
    }

    func testAufsichtErkenntStille() {
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(Verbindungspolitik.istVerstummt(letzterRahmen: jetzt.addingTimeInterval(-5), jetzt: jetzt))
        XCTAssertFalse(Verbindungspolitik.istVerstummt(letzterRahmen: jetzt.addingTimeInterval(-40), jetzt: jetzt))
        XCTAssertTrue(Verbindungspolitik.istVerstummt(letzterRahmen: jetzt.addingTimeInterval(-41), jetzt: jetzt))
        // Solange nie ein Rahmen kam, ist nichts verstummt - es hat nur nicht angefangen.
        XCTAssertFalse(Verbindungspolitik.istVerstummt(letzterRahmen: nil, jetzt: jetzt))
    }

    /// **Die Schwelle muss ueber dem Ping des Dienstes liegen.** `routers/live.py` setzt
    /// `ping=15`; ein ruhiges Haus schickt sonst nichts. Eine Schwelle von 15 Sekunden hiesse:
    /// jedes Zittern im Netz loest einen Neuaufbau aus, an einer Wandanzeige dauernd.
    func testDieSchwelleLiegtUeberDemPingDesDienstes() {
        let pingDesDienstes: Double = 15
        XCTAssertGreaterThan(
            Verbindungspolitik.stilleBisAbriss, pingDesDienstes * 2,
            "ein einzelner ausgefallener Ping darf kein Abriss sein"
        )
        // Aber auch nicht so hoch, dass ein echter Abriss minutenlang unbemerkt bleibt.
        XCTAssertLessThan(Verbindungspolitik.stilleBisAbriss, 90)
    }

    /// Ein `retry:` aus dem Strom ist ein Wunsch, kein Befehl.
    func testVorschlagWirdInGrenzenGelegt() {
        XCTAssertEqual(Verbindungspolitik.vorschlagInGrenzen(5), 5)
        XCTAssertEqual(Verbindungspolitik.vorschlagInGrenzen(0.01), 1.0)
        XCTAssertEqual(Verbindungspolitik.vorschlagInGrenzen(600), 30.0)
        XCTAssertNil(Verbindungspolitik.vorschlagInGrenzen(nil))
        XCTAssertNil(Verbindungspolitik.vorschlagInGrenzen(0))
        XCTAssertNil(Verbindungspolitik.vorschlagInGrenzen(-1))
        XCTAssertNil(Verbindungspolitik.vorschlagInGrenzen(.nan))
    }
}

/// Die Einordnung von Fehlern - daran haengt, ob die App weiter versucht oder aufgibt.
final class ApiFehlerTests: XCTestCase {
    func testEinFalschesTokenLohntKeineWiederholung() {
        let f = ApiFehler(code: "unauthorized", meldung: "Kein gültiges API-Token.", status: 401)
        XCTAssertTrue(f.istAnmeldung)
        XCTAssertFalse(f.lohntWiederholung)
        XCTAssertTrue(f.rat.contains("Zugang"))
    }

    func testEinGastBekommtEinenAnderenRat() {
        let f = ApiFehler(code: "forbidden", meldung: "Gastzugang: nur Ansicht.", status: 403)
        XCTAssertTrue(f.istVerboten)
        XCTAssertFalse(f.lohntWiederholung)
    }

    func testNetzUndDienstfehlerLohnenWiederholung() {
        XCTAssertTrue(ApiFehler.netz("weg").lohntWiederholung)
        XCTAssertTrue(ApiFehler(code: "x", meldung: "", status: 503).lohntWiederholung)
        XCTAssertTrue(ApiFehler(code: "x", meldung: "", status: 429).lohntWiederholung)
        XCTAssertFalse(ApiFehler(code: "x", meldung: "", status: 404).lohntWiederholung)
    }

    /// Wo der Dienst einen deutschen Satz schickt, wird der gezeigt und nicht ersetzt.
    func testDieMeldungDesDienstesUeberlebt() {
        let f = ApiFehler(code: "buffer_cold", meldung: "Der Puffer ist zu kalt für diesen Griff.", status: 409)
        XCTAssertEqual(f.rat, "Der Puffer ist zu kalt für diesen Griff.")
    }
}
