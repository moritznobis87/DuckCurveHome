import XCTest

@testable import DuckCurveKit

/// Der Kern gegen den **echten** Dienst im Demo-Betrieb.
///
/// **Warum das etwas anderes ist als `NetzLaufTests`.** Der Prüfstand dort antwortet mit dem, was
/// ich für die richtige Form halte - und wenn ich mich irre, irrt er mit. Dieser Lauf fragt den
/// Dienst selbst. Er beweist das, was sich sonst erst am Gerät zeigt: dass die 172 erzeugten
/// Strukturen die Antworten lesen, die wirklich kommen.
///
/// Das ist die Naht, an der ein generierter Client bricht - ein Feld, das im Schema wahlfrei
/// heißt und in Wirklichkeit fehlt, eine Aufzählung mit einem Wert, den das Schema nicht kennt,
/// eine Zahl, die als Zeichenkette kommt. Nichts davon fällt beim Übersetzen auf.
///
///     tools/ios-demo.sh &
///     DCH_DEMO=http://localhost:8000 swift test --filter DemoLaufTests
///
/// Ohne `DCH_DEMO` werden die Tests übersprungen.
final class DemoLaufTests: XCTestCase {
    private var api: Api?

    override func setUp() {
        super.setUp()
        guard let roh = ProcessInfo.processInfo.environment["DCH_DEMO"],
              let url = URL(string: roh)
        else { return }
        api = Api(zugang: Zugang(grund: url, token: "", geraetename: "Prüflauf"))
    }

    private func dienst() throws -> Api {
        try XCTSkipIf(api == nil, "Kein Demo-Dienst: DCH_DEMO nicht gesetzt.")
        return api!
    }

    // MARK: - Der Augenblick

    func testLiveZustand() async throws {
        let z = try await dienst().liveZustand()
        // Ein Augenblicksbild ohne lesbaren Zeitstempel laesst die ganze Anzeige leer.
        XCTAssertNotNil(Zeit.ausIso(z.snapshot.timestamp))
        XCTAssertNotNil(Zeit.ausIso(z.system.serverTime))
        // Die Guete muss eine bekannte sein - `.unbekannt` hiesse, das Schema kennt sie nicht.
        XCTAssertNotEqual(z.snapshot.pvPowerKw.quality, .unbekannt)
        XCTAssertNotEqual(z.buffer.status, .unbekannt)
        XCTAssertNotEqual(z.operatingMode.systemMode, .unbekannt)
        // Vier Puffertemperaturen, von oben nach unten.
        XCTAssertEqual(z.snapshot.bufferTempsC.vonObenNachUnten.count, 4)
    }

    func testDerPlan() async throws {
        let p = try await dienst().plan()
        XCTAssertNotNil(Zeit.ausIso(p.horizonStart))
        XCTAssertNotNil(Zeit.ausIso(p.horizonEnd))
        XCTAssertFalse(p.intervals.isEmpty, "ein Plan ohne Viertelstunden ist keiner")
        for iv in p.intervals.prefix(20) {
            XCTAssertNotNil(Zeit.ausIso(iv.ts))
            XCTAssertNotEqual(iv.plannedHpState, .unbekannt)
        }
        for w in p.windows {
            XCTAssertNotEqual(w.kind, .unbekannt, "unbekannte Fensterart: \(w.labelDe)")
        }
    }

    func testVerlaufUndMinutenraster() async throws {
        let h = try await dienst().verlauf(.heute)
        XCTAssertNotNil(Zeit.ausIso(h.start))
        var raster = Minutenraster()
        raster.setze(h, tag: Tag.heute())
        // Jede Zeile muss einen lesbaren Zeitstempel haben - sonst faellt sie aus dem Raster.
        XCTAssertEqual(raster.punkte.count, h.rows.count, "Zeilen ohne lesbaren Zeitstempel")
        if raster.punkte.count > 1 {
            XCTAssertEqual(
                raster.punkte.map(\.zeit), raster.punkte.map(\.zeit).sorted(),
                "die Reihe ist nicht aufsteigend"
            )
        }
    }

    // MARK: - Alles, was die Seiten holen

    /// **Der breite Lauf.** Jeder Endpunkt, den eine Seite anfasst, einmal - und jede Antwort
    /// durch den erzeugten Leser. Was hier durchgeht, wird am Gerät nicht am Schema scheitern.
    func testAlleSeitenEndpunkte() async throws {
        let api = try dienst()
        let heute = Tag.heute()
        var fehler: [String] = []

        func pruefe(_ name: String, _ lauf: () async throws -> Void) async {
            do {
                try await lauf()
            } catch let f as ApiFehler where f.code == "schema" {
                fehler.append("\(name): \(f.meldung)")
            } catch let f as ApiFehler {
                // 404 und 501 sind in Ordnung: nicht jedes Haus hat jedes Geraet, und der
                // Demo-Betrieb kennt nicht jeden Weg. Ein Schemafehler ist etwas anderes.
                if f.status != 404, f.status != 501, f.status != 503 {
                    fehler.append("\(name): \(f.status) \(f.code)")
                }
            } catch {
                fehler.append("\(name): \(error)")
            }
        }

        await pruefe("anlage") { _ = try await api.anlage() }
        await pruefe("haus") { _ = try await api.haus() }
        await pruefe("raeume") { _ = try await api.raeume() }
        await pruefe("raeumeTag") { _ = try await api.raeumeTag(heute) }
        await pruefe("waermepumpe") { _ = try await api.waermepumpe() }
        await pruefe("betrieb") { _ = try await api.betrieb(tage: 7) }
        await pruefe("kennlinie") { _ = try await api.kennlinie(tage: 7) }
        await pruefe("reglerEinstellungen") { _ = try await api.reglerEinstellungen() }
        await pruefe("reglerKennzahlen") { _ = try await api.reglerKennzahlen(tage: 7) }
        await pruefe("energieUebersicht") { _ = try await api.energieUebersicht("day", anker: heute) }
        await pruefe("energieWaerme") { _ = try await api.energieWaerme("day", anker: heute) }
        await pruefe("energieVerschiebung") { _ = try await api.energieVerschiebung("day", anker: heute) }
        await pruefe("waermebilanz") { _ = try await api.waermebilanz("day", anker: heute) }
        await pruefe("energieWallbox") { _ = try await api.energieWallbox("day", anker: heute) }
        await pruefe("energiePv") { _ = try await api.energiePv("day", anker: heute) }
        await pruefe("jahreskarte") { _ = try await api.jahreskarte(jahr: 2026) }
        await pruefe("batterie") { _ = try await api.batterie() }
        await pruefe("entscheidungen") { _ = try await api.entscheidungen() }
        await pruefe("prognoseBewertung") { _ = try await api.prognoseBewertung() }
        await pruefe("prognoseVerlauf") { _ = try await api.prognoseVerlauf(tage: 7) }
        await pruefe("abdeckung") { _ = try await api.abdeckung(anker: heute, tage: 7) }
        await pruefe("datenbestand") { _ = try await api.datenbestand() }
        await pruefe("haustuer") { _ = try await api.haustuer(tage: 7) }
        await pruefe("einstellungen") { _ = try await api.einstellungen() }
        await pruefe("rechnungen") { _ = try await api.rechnungen() }
        await pruefe("raumAutomatik") { _ = try await api.raumAutomatik() }
        await pruefe("morgenbrief") { _ = try await api.morgenbrief() }
        await pruefe("mitteilungGeraete") { _ = try await api.mitteilungGeraete() }
        await pruefe("kontaktwirkung") { _ = try await api.kontaktwirkung(tage: 7) }
        await pruefe("anlageWiedergabe") { _ = try await api.anlageWiedergabe(tag: Tag.plus(heute, -1)) }
        await pruefe("diagnose") { _ = try await api.diagnose(tag: heute) }
        await pruefe("speicherPruefung") { _ = try await api.speicherPruefung("day", anker: heute) }
        // Die Regelkreis-Karte ist die groesste Antwort des Dienstes: 35 Bloecke, 56 Kanten, 31
        // Parameter mit Protokoll und Verlauf, dazu der Gliedkatalog mit gerechneten Kurven. Wenn
        // irgendwo ein erzeugtes Modell von seinem Schema abweicht, dann hier.
        await pruefe("regelkreis") {
            let karte = try await api.regelkreis()
            // Eine Antwort, die durchkommt, aber leer ist, waere hier kein Erfolg: `pruefe`
            // schluckt 404 absichtlich, und eine leere Karte sieht genauso aus.
            XCTAssertFalse(karte.bloecke.isEmpty, "die Karte kam ohne Bloecke")
            XCTAssertFalse(karte.parameter.isEmpty, "die Karte kam ohne Parameter")
            XCTAssertEqual(karte.kreise.count, 5, "fuenf Kreise hat die Kaskade")
        }

        XCTAssertTrue(fehler.isEmpty, "\n" + fehler.joined(separator: "\n"))
    }

    // MARK: - Der Ereignisstrom

    /// Der Strom am echten Dienst.
    ///
    /// **Erwartet wird ein Augenblicksbild, nicht zwei.** Das war erst anders, und das Messen
    /// hat es widerlegt: der Dienst drosselt Augenblicksbilder absichtlich (`Takt` in
    /// `live_feed.py`) - hoechstens alle fuenf Sekunden, und nur, wenn sich am Kern des
    /// Zustands etwas geaendert hat. Ein ruhiges Haus schickt eines beim Verbinden und dann
    /// sechzig Sekunden lang keines mehr. Das ist richtig so und spart einer Wandanzeige, die
    /// Wochen laeuft, viel Verkehr.
    ///
    /// Was stattdessen geprueft wird: dass etwas ankommt, dass es lesbar ist, und dass die
    /// Verbindung danach **steht** - der Strom traegt Entscheidungen, Herzschlaege und die
    /// Kommentar-Pings des Dienstes, und an denen haengt die Aufsicht.
    func testDerStromLiefertUndBleibt() async throws {
        let api = try dienst()
        let strom = LiveStrom(zugang: api.zugang)
        var zustaende = 0
        var nachrichten = 0
        var verbindung: Verbindung = .verbindet
        var fehler: ApiFehler?
        let frist = Date().addingTimeInterval(20)

        for await nachricht in await strom.nachrichten() {
            nachrichten += 1
            switch nachricht {
            case .zustand(let z):
                XCTAssertNotNil(Zeit.ausIso(z.snapshot.timestamp))
                XCTAssertNotEqual(z.snapshot.pvPowerKw.quality, .unbekannt)
                zustaende += 1
            case .verbindung(let v):
                verbindung = v
            case .fehler(let f):
                fehler = f
            default:
                break
            }
            if Date() > frist { break }
        }
        await strom.halte()

        XCTAssertNil(fehler, "der Strom meldet einen Fehler: \(fehler?.meldung ?? "")")
        XCTAssertGreaterThanOrEqual(zustaende, 1, "kein einziges Augenblicksbild")
        XCTAssertEqual(verbindung, .live, "die Verbindung steht am Ende nicht als „live“ da")
        // Nach zwanzig Sekunden muss mehr gekommen sein als der eine Rahmen vom Anfang -
        // Entscheidungen, Herzschlaege, Plan. Sonst waere der Strom stumm.
        XCTAssertGreaterThan(nachrichten, 2, "nach dem ersten Rahmen kam nichts mehr")
    }

    /// Die Demo laeuft im Zeitraffer oder in Echtzeit - in beiden Faellen muss die Serverzeit
    /// lesbar sein, denn daraus entsteht der Zeitversatz. Ohne ihn ist „heute" geraten.
    func testDieServerzeitIstLesbar() async throws {
        let z = try await dienst().liveZustand()
        let serverzeit = Zeit.ausIso(z.system.serverTime)
        XCTAssertNotNil(serverzeit)
        if let s = serverzeit {
            // Im Demo-Betrieb darf sie weit weg sein; unlesbar oder 1970 darf sie nicht sein.
            XCTAssertGreaterThan(s.timeIntervalSince1970, 1_600_000_000)
        }
    }
}
