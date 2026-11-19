import XCTest

@testable import DuckCurveKit

/// Die Netzschicht am laufenden Dienst.
///
/// **Warum echtes HTTP und keine Attrappe.** Eine Attrappe ersetzt genau die Naht, an der eine
/// Netzschicht bricht: dass die Kopfzeilen tatsaechlich hinausgehen, dass ein 401 als Antwort mit
/// Rumpf ankommt und nicht als Netzfehler, dass Delegate, Actor und Leser im Zusammenspiel
/// Nachrichten liefern. Das laesst sich nur an einem Dienst pruefen, der antwortet.
///
/// Der Dienst ist `apps/ios/pruefstand/dienst.py`. Diese Tests laufen nur, wenn er laeuft und
/// `DCH_PRUEFSTAND` auf seine Adresse zeigt - sonst werden sie uebersprungen, damit `swift test`
/// auch ohne ihn durchlaeuft:
///
///     python3 apps/ios/pruefstand/dienst.py 8111 &
///     DCH_PRUEFSTAND=http://127.0.0.1:8111 swift test
final class NetzLaufTests: XCTestCase {
    private var zugang: Zugang?

    override func setUp() {
        super.setUp()
        guard let roh = ProcessInfo.processInfo.environment["DCH_PRUEFSTAND"],
              let url = URL(string: roh)
        else { return }
        zugang = Zugang(grund: url, token: "pruefstand", geraetename: "iPad Flur")
    }

    /// Den Zugang holen oder den Test ueberspringen.
    private func zugangOderUeberspringen() throws -> Zugang {
        try XCTSkipIf(zugang == nil, "Kein Prüfstand: DCH_PRUEFSTAND nicht gesetzt.")
        return zugang!
    }

    // MARK: - Lesen

    func testLiestDenLiveZustand() async throws {
        let api = Api(zugang: try zugangOderUeberspringen())
        let z = try await api.liveZustand()
        XCTAssertEqual(z.snapshot.pvPowerKw.value, 4.2)
        XCTAssertEqual(z.snapshot.pvPowerKw.quality, .ok)
        XCTAssertEqual(z.buffer.status, .warm)
        XCTAssertTrue(z.heatPump.running)
        XCTAssertEqual(z.operatingMode.systemMode, .auto)
        XCTAssertEqual(z.system.version, "pruefstand")
        // Ein Zeitstempel, der sich lesen laesst - daran haengt das ganze Diagramm.
        XCTAssertNotNil(Zeit.ausIso(z.snapshot.timestamp))
    }

    func testLiestDenPlan() async throws {
        let api = Api(zugang: try zugangOderUeberspringen())
        let p = try await api.plan()
        XCTAssertEqual(p.planner, "pruefstand")
        XCTAssertEqual(p.plannerNoteDe, "Ein Plan vom Prüfstand.")
        XCTAssertEqual(p.pvForecastTodayKwh, 16.4)
        XCTAssertNotNil(Zeit.ausIso(p.horizonStart))
        XCTAssertNotNil(Zeit.ausIso(p.horizonEnd))
        // Die leeren Listen kommen aus dem Generator, nicht aus Handarbeit im Client. Und ein
        // `null` im JSON wird `nil`, nicht ein leerer Wert.
        XCTAssertTrue(p.intervals.isEmpty)
        XCTAssertTrue(p.windows.isEmpty)
        XCTAssertNil(p.nextCheapWindow)
        XCTAssertNil(p.plannerWarnDe)
    }

    func testLiestDieHistorieUndFuelltDasRaster() async throws {
        let api = Api(zugang: try zugangOderUeberspringen())
        let h = try await api.verlauf(.heute)
        XCTAssertEqual(h.rows.count, 5)

        var raster = Minutenraster()
        raster.setze(h, tag: "2026-02-24")
        XCTAssertEqual(raster.punkte.count, 5)
        XCTAssertEqual(raster.punkte.first?.pv, 3.0)
        XCTAssertEqual(raster.punkte.last?.pv, 5.0)
        // `null` im JSON ist kein Wert, nicht die Zahl null.
        XCTAssertNil(raster.punkte.first?.netz)
        // Und die Reihe ist aufsteigend.
        XCTAssertEqual(raster.punkte.map(\.zeit), raster.punkte.map(\.zeit).sorted())
    }

    /// Zwei Endpunkte liefern reinen Text und keinen JSON-Umschlag. Wer die durch den
    /// JSON-Leser schickt, bekommt eine leere Seite und keinen Fehler.
    func testLiestReinenText() async throws {
        let api = Api(zugang: try zugangOderUeberspringen())
        let t = try await api.diagnose(tag: "2026-02-24")
        XCTAssertTrue(t.contains("Diagnose"))
        XCTAssertTrue(t.contains("14,2 kWh"))
    }

    // MARK: - Schreiben und der Urheber

    /// **Der Test, der die Luecke des BFF schliesst.** Der Dienst gibt zurueck, welche
    /// Urheber-Kopfzeilen ankamen. Ohne sie steht im Protokoll wieder nur, *dass* jemand den
    /// Sollwert gestellt hat.
    func testDerUrheberReistMit() async throws {
        let zugang = try zugangOderUeberspringen()
        let api = Api(zugang: zugang)
        let antwort: [String: Mischwert] = try await withCheckedThrowingContinuation { fort in
            Task {
                do {
                    // Der erzeugte Typ traegt die Urheber-Felder nicht, darum roh gelesen.
                    let roh = try await api.rohPost(
                        "/rooms/3/setpoint", json: ["setpoint_c": .zahl(21.5)])
                    fort.resume(returning: roh)
                } catch {
                    fort.resume(throwing: error)
                }
            }
        }
        XCTAssertEqual(antwort["urheber_art"]?.alsText, "geraet")
        XCTAssertEqual(antwort["urheber_id"]?.alsText, "ipad-flur")
        XCTAssertEqual(antwort["urheber_name"]?.alsText, "iPad Flur")
        XCTAssertEqual(antwort["urheber_rolle"]?.alsText, "owner")
        XCTAssertEqual(antwort["content_type"]?.alsText, "application/json")
        XCTAssertEqual(antwort["setpoint_c"]?.alsZahl, 21.5)
    }

    func testStellenGibtDieAntwortDesDienstesZurueck() async throws {
        let api = Api(zugang: try zugangOderUeberspringen())
        let a = try await api.stelleRaum(3, sollwertC: 21.5)
        XCTAssertTrue(a.ok)
        XCTAssertEqual(a.messageDe, "Gestellt.")
    }

    // MARK: - Fehler

    /// Ein falsches Token muss als `unauthorized` ankommen und nicht als Netzfehler - daran
    /// haengt, ob die App es weiter versucht oder den Benutzer zum Einrichten schickt.
    func testFalschesTokenGibtEinenAnmeldefehler() async throws {
        var z = try zugangOderUeberspringen()
        z.token = "falsch"
        let api = Api(zugang: z)
        do {
            _ = try await api.liveZustand()
            XCTFail("Ein falsches Token muss abgewiesen werden.")
        } catch let f as ApiFehler {
            XCTAssertEqual(f.status, 401)
            XCTAssertTrue(f.istAnmeldung)
            XCTAssertFalse(f.lohntWiederholung)
            XCTAssertEqual(f.meldung, "Kein gültiges API-Token.")
            XCTAssertTrue(f.rat.contains("Zugang"))
        }
    }

    /// Der deutsche Satz des Dienstes muss durchkommen, nicht ersetzt werden.
    func testFehlerUmschlagWirdGelesen() async throws {
        let api = Api(zugang: try zugangOderUeberspringen())
        do {
            _ = try await api.lebt2("/kaputt")
            XCTFail("Hier muss ein Fehler kommen.")
        } catch let f as ApiFehler {
            XCTAssertEqual(f.code, "buffer_cold")
            XCTAssertEqual(f.status, 409)
            XCTAssertEqual(f.meldung, "Der Puffer ist zu kalt für diesen Griff.")
            XCTAssertEqual(f.rat, "Der Puffer ist zu kalt für diesen Griff.")
        }
    }

    func testEinUnerreichbaresHausIstEinNetzfehler() async throws {
        _ = try zugangOderUeberspringen()
        // Ein Port, auf dem nichts horcht.
        let api = Api(zugang: Zugang(grund: URL(string: "http://127.0.0.1:9")!, token: "x"))
        do {
            _ = try await api.liveZustand()
            XCTFail("Hier kann nichts antworten.")
        } catch let f as ApiFehler {
            XCTAssertEqual(f.status, 0)
            XCTAssertTrue(f.lohntWiederholung)
            XCTAssertTrue(f.rat.contains("nicht erreichbar"))
        }
    }

    // MARK: - Der Ereignisstrom

    /// **Der Test, auf den es ankommt.** Der Dienst zerhackt den ersten Rahmen absichtlich in
    /// drei Stuecke, eines mitten im JSON, streut einen Kommentar und ein unbekanntes Ereignis
    /// ein - und am Ende muessen bei der App zwei Augenblicksbilder, ein Plan und ein Herzschlag
    /// angekommen sein.
    func testDerStromLiefertDurchAlleSchichten() async throws {
        let zugang = try zugangOderUeberspringen()
        let strom = LiveStrom(zugang: zugang)
        var zustaende: [LiveStateOut] = []
        var plaene: [PlanOut] = []
        var herzschlaege: [Date] = []
        var verbindungen: [Verbindung] = []

        let frist = Date().addingTimeInterval(10)
        for await nachricht in await strom.nachrichten() {
            switch nachricht {
            case .zustand(let z): zustaende.append(z)
            case .plan(let p): plaene.append(p)
            case .herzschlag(let d): herzschlaege.append(d)
            case .verbindung(let v): verbindungen.append(v)
            case .entscheidung, .fehler: break
            }
            // Fertig, sobald alles da ist - oder wenn die Zeit um ist.
            if zustaende.count >= 2 && !plaene.isEmpty && !herzschlaege.isEmpty { break }
            if Date() > frist { break }
        }
        await strom.halte()

        XCTAssertEqual(zustaende.count, 2, "beide Augenblicksbilder müssen ankommen")
        XCTAssertEqual(zustaende.first?.snapshot.pvPowerKw.value, 4.2)
        XCTAssertEqual(zustaende.last?.snapshot.pvPowerKw.value, 5.5)
        XCTAssertEqual(plaene.count, 1)
        XCTAssertEqual(plaene.first?.plannerNoteDe, "Ein Plan vom Prüfstand.")
        XCTAssertEqual(herzschlaege.count, 1)
        XCTAssertEqual(herzschlaege.first, Zeit.ausIso("2026-02-24T14:35:00Z"))
        XCTAssertTrue(verbindungen.contains(.live), "die Verbindung muss als „live“ gemeldet werden")
    }

    /// Ein falsches Token am Ereignisstrom: der Dienst antwortet mit 401 und Rumpf, nicht mit
    /// einem Netzfehler. Ohne die Pruefung im Delegate wartet die App auf Ereignisse, die nie
    /// kommen, und zeigt „verbindet" statt „das Token stimmt nicht".
    func testDerStromErkenntEinFalschesToken() async throws {
        var z = try zugangOderUeberspringen()
        z.token = "falsch"
        let strom = LiveStrom(zugang: z)
        var fehler: ApiFehler?
        let frist = Date().addingTimeInterval(10)
        for await nachricht in await strom.nachrichten() {
            if case .fehler(let f) = nachricht {
                fehler = f
                break
            }
            if Date() > frist { break }
        }
        await strom.halte()
        XCTAssertEqual(fehler?.status, 401)
        XCTAssertEqual(fehler?.code, "unauthorized")
    }
}

// MARK: - Zwei Griffe nur fuer den Pruefstand

extension Api {
    /// Eine rohe POST-Anfrage, deren Antwort als Woerterbuch zurueckkommt.
    ///
    /// Nur fuer den Pruefstand: der erzeugte Antworttyp kennt die Urheber-Felder nicht, die der
    /// Pruefdienst zurueckgibt, und soll sie auch nicht kennen.
    func rohPost(_ pfad: String, json: [String: Mischwert]) async throws -> [String: Mischwert] {
        try await hole(pfad, verfahren: "POST", rumpf: try JSONEncoder().encode(json))
    }

    /// Einen beliebigen Weg abrufen - fuer die Pruefung des Fehlerumschlags.
    func lebt2(_ pfad: String) async throws -> [String: Mischwert] {
        try await hole(pfad)
    }
}
