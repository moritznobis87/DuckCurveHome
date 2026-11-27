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

    // MARK: - Das Demo-Haus

    /// Der Knopf „Demo ansehen" trägt nichts ein. Also muss dieser eine Wert alles enthalten,
    /// was sonst drei Felder liefern: Adresse, Anmeldung, Rolle.
    func testDemoZeigtAufDasDemohausUndBrauchtKeinToken() {
        let demo = Zugang.demo(geraetename: "iPhone")
        XCTAssertEqual(
            demo.adresse("/live/state")?.absoluteString,
            "https://duckcurvehome-production-7dd0cc79.up.railway.app/api/v1/live/state"
        )
        // Außerhalb des Heimnetzes lässt iOS nur https zu (Info.plist, NSAppTransportSecurity).
        XCTAssertEqual(Zugang.demohaus.scheme, "https")
        XCTAssertTrue(demo.token.isEmpty)
        XCTAssertNil(demo.kopfzeilen["authorization"], "ohne Token keine Anmeldezeile")
        XCTAssertFalse(demo.istPerson)
    }

    /// Wer das Demo-Haus öffnet, sieht die ganze App: Stellgriffe und die Seiten des Hausherrn.
    /// Das ist eine Entscheidung des Hausherrn und kein Versehen; als Gast fehlte beides.
    func testDemoHatDenVollenUmfang() {
        let demo = Zugang.demo(geraetename: "iPhone")
        XCTAssertEqual(demo.rolle, .hausherr)
        XCTAssertTrue(demo.rolle.darfStellen)
        XCTAssertTrue(demo.rolle.hatVollzugriff)
        XCTAssertEqual(demo.kopfzeilen["x-dch-urheber-rolle"], "owner")
    }

    /// Ein eingerichteter Zugang, sonst überspränge die App das Demo-Haus wie den Platzhalter.
    func testDemoGiltAlsEingerichtetUndErkenntSich() {
        let demo = Zugang.demo(geraetename: "iPhone")
        XCTAssertTrue(demo.istEingerichtet)
        XCTAssertTrue(demo.istDemohaus)
        XCTAssertFalse(zugang.istDemohaus)
        XCTAssertFalse(Zugang(grund: Zugang.nichtEingerichtet).istDemohaus)
    }

    /// Der Gerätename reist mit, damit das Protokoll des Demo-Hauses nicht nur „Gerät" kennt.
    func testDemoTraegtDenGeraetenamen() {
        XCTAssertEqual(Zugang.demo(geraetename: "iPad Flur").kopfzeilen["x-dch-urheber-name"], "iPad Flur")
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

    // MARK: - Als Person angemeldet (seit dem 24.11.2026)

    /// Ein Zugang mit E-Mail-Adresse ist eine Person, einer ohne ist ein Gerät mit API-Token.
    func testPersonOderGeraet() {
        XCTAssertFalse(zugang.istPerson)
        var z = zugang
        z.email = "anna@example.org"
        XCTAssertTrue(z.istPerson)
    }

    /// Die Adresse der Person überlebt das Speichern wie der Rest.
    func testPersonUeberlebtSpeichern() throws {
        var z = zugang
        z.email = "anna@example.org"
        let zurueck = try JSONDecoder().decode(Zugang.self, from: JSONEncoder().encode(z))
        XCTAssertEqual(zurueck, z)
    }

    /// Ein Zugang, der vor dem 24.11.2026 gespeichert wurde, hat kein Feld `email`. Er muss
    /// sich weiter lesen lassen und ist dann ein Gerät.
    func testAlterZugangOhneAdresseBleibtLesbar() throws {
        let alt = #"{"grund":"https://dch.example.net","praefix":"/api/v1","token":"geheim","geraetename":"iPad Flur","rolle":"gast"}"#
        let z = try JSONDecoder().decode(Zugang.self, from: Data(alt.utf8))
        XCTAssertEqual(z.email, "")
        XCTAssertFalse(z.istPerson)
        XCTAssertEqual(z.rolle, .gast)
        XCTAssertEqual(z.token, "geheim")
    }

    /// Die Rolle aus dem Ausweis des Dienstes kommt eins zu eins in der App an. Eine, die diese
    /// Fassung nicht kennt, wird zum Gast.
    func testDieRolleDerPersonKommtAusDemAusweis() {
        XCTAssertEqual(Zugang.rolle(derPerson: .hausherr), .hausherr)
        XCTAssertEqual(Zugang.rolle(derPerson: .bewohner), .bewohner)
        XCTAssertEqual(Zugang.rolle(derPerson: .service), .service)
        XCTAssertEqual(Zugang.rolle(derPerson: .gast), .gast)
        XCTAssertEqual(Zugang.rolle(derPerson: .unbekannt), .gast)
    }

    /// Stellen dürfen und Vollzugriff haben sind zweierlei (`auth/rechte.py`): Ein Bewohner
    /// stellt im Haus und sieht keine Akten; Beratung und Gast sehen in der App nur zu.
    func testStellenUndVollzugriffSindZweierlei() {
        let stellt = Zugang.Rolle.allCases.filter(\.darfStellen)
        let voll = Zugang.Rolle.allCases.filter(\.hatVollzugriff)
        XCTAssertEqual(stellt, [.hausherr, .bewohner])
        XCTAssertEqual(voll, [.hausherr])
    }

    /// Eine Rolle, die vor dem 24.11.2026 gespeichert wurde, heißt „hausherr“ oder „gast“ und
    /// liest sich weiter.
    func testAlteRollenBleibenLesbar() {
        XCTAssertEqual(Zugang.Rolle(rawValue: "hausherr"), .hausherr)
        XCTAssertEqual(Zugang.Rolle(rawValue: "gast"), .gast)
        XCTAssertNil(Zugang.Rolle(rawValue: "owner"))
    }

    /// Eine abgelaufene Anmeldung nennt den Ort, an dem man sich neu anmeldet, und spricht
    /// nicht mehr von einem Token: seit dem 24.11.2026 kann es auch eine Sitzung sein.
    func testAbgelaufeneAnmeldungNenntDenWeg() {
        let f = ApiFehler(code: "unauthorized", meldung: "Die Anmeldung ist nicht möglich.", status: 401)
        XCTAssertEqual(f.rat, "Die Anmeldung gilt nicht mehr. Unter „Zugang und Sicherung“ neu anmelden.")
    }
}

/// Die Worte der Anmeldung mit Passwort: dieselben Sätze wie im Dashboard.
final class AnmeldeworteTests: XCTestCase {
    /// Zwei verschiedene Eingaben fallen in der App auf, bevor etwas hinausgeht. Die Länge
    /// prüft der Dienst; hier wird sie nicht nachgebaut.
    func testNurVerschiedeneEingabenSindEinEinwand() {
        XCTAssertNil(Anmeldeworte.einwand(neu: "ein langes Passwort", wiederholung: "ein langes Passwort"))
        XCTAssertNil(Anmeldeworte.einwand(neu: "kurz", wiederholung: "kurz"))
        XCTAssertEqual(
            Anmeldeworte.einwand(neu: "ein langes Passwort", wiederholung: "ein langes Passwor"),
            "Die beiden Eingaben sind verschieden.")
    }

    /// Der Wortlaut des Dashboards (`MeinPasswort.tsx`), Satz für Satz.
    func testDieSaetzeSindDieDesDashboards() {
        XCTAssertEqual(Anmeldeworte.ueberschrift, "Mein Passwort")
        XCTAssertEqual(
            Anmeldeworte.stand(vorhanden: true),
            "Du hast ein Passwort und kannst dich damit an jedem Gerät anmelden.")
        XCTAssertEqual(
            Anmeldeworte.stand(vorhanden: false),
            "Du hast kein Passwort. Mit einem Passwort kommst du auch an Geräten herein, die keinen Passkey können.")
        XCTAssertEqual(Anmeldeworte.knopf(vorhanden: true), "Passwort wechseln")
        XCTAssertEqual(Anmeldeworte.knopf(vorhanden: false), "Passwort vergeben")
        XCTAssertEqual(Anmeldeworte.neufeld(mindestlaenge: 12), "Neues Passwort, mindestens 12 Zeichen")
        XCTAssertEqual(
            Anmeldeworte.gespeichert(vorher: true),
            "Das Passwort ist gewechselt. Deine anderen Geräte sind abgemeldet.")
        XCTAssertEqual(
            Anmeldeworte.gespeichert(vorher: false),
            "Das Passwort ist vergeben. Du kannst dich jetzt auch mit E-Mail-Adresse und Passwort anmelden.")
        XCTAssertEqual(Anmeldeworte.entfernenGesperrt, "Entfernen geht erst mit einem Passkey")
        XCTAssertEqual(Anmeldeworte.anmeldeknopf, "Mit Passwort anmelden")
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

    func testOhneVerbindungIstNurWasDasNetzOderDerServerVerschuldet() {
        // Kein Netz, oder der Dienst startet neu und sein Vorbau meldet 502 oder 503.
        XCTAssertTrue(ApiFehler.netz("Zeit abgelaufen").istOhneVerbindung)
        XCTAssertTrue(ApiFehler(code: "http_error", meldung: "Bad Gateway", status: 502).istOhneVerbindung)
        XCTAssertTrue(ApiFehler(code: "http_error", meldung: "Service Unavailable", status: 503).istOhneVerbindung)
        // Ein abgelehnter Zugang ist eine Antwort des Dienstes. Die Seite des Hausgeraets darf
        // dann nicht „Gerade keine Verbindung“ sagen, sondern muss den Rat zeigen.
        XCTAssertFalse(ApiFehler(code: "unauthorized", meldung: "Kein gültiges API-Token.", status: 401).istOhneVerbindung)
        XCTAssertFalse(ApiFehler(code: "forbidden", meldung: "Gastzugang: nur Ansicht.", status: 403).istOhneVerbindung)
        XCTAssertFalse(ApiFehler(code: "not_found", meldung: "Unbekannt.", status: 404).istOhneVerbindung)
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

    // MARK: - Was als eingerichtet zaehlt

    /// **Der Fehler, der auf dem Geraet eine Stunde gekostet hat.** Der Platzhalter hat einen
    /// Hostnamen; die alte Pruefung sah nur danach und hielt ihn fuer eine Adresse. Die App
    /// uebersprang das Einrichten und sprach mit `nicht.eingerichtet.invalid`.
    func testDerPlatzhalterGiltNichtAlsEingerichtet() {
        let z = Zugang(grund: Zugang.nichtEingerichtet, token: "", geraetename: "x")
        XCTAssertFalse(z.istEingerichtet)
    }

    func testJedeInvalidEndungGiltNichtAlsEingerichtet() {
        // Nicht nur dieser eine Name: `.invalid` ist reserviert und loest nie auf (RFC 2606).
        for roh in ["https://irgendwas.invalid", "http://a.b.invalid", "https://x.invalid"] {
            let z = Zugang(grund: URL(string: roh)!, token: "", geraetename: "x")
            XCTAssertFalse(z.istEingerichtet, roh)
        }
    }

    func testEineEchteAdresseGiltAlsEingerichtet() {
        for roh in ["http://192.168.1.42:8000", "https://haus.example.com", "http://localhost:8000"] {
            let z = Zugang(grund: URL(string: roh)!, token: "", geraetename: "x")
            XCTAssertTrue(z.istEingerichtet, roh)
        }
    }

    func testEineAdresseOhneGastgeberGiltNicht() {
        let z = Zugang(grund: URL(string: "file:///tmp/x")!, token: "", geraetename: "x")
        XCTAssertFalse(z.istEingerichtet)
    }
}
