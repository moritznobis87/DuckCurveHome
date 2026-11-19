import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Der Client zum Dienst: alle Endpunkte, die die App braucht.
///
/// Die Reihenfolge und die Namen folgen `apps/web/src/lib/api/client.ts`, damit sich die beiden
/// nebeneinanderlegen lassen. Wo das Dashboard dort von Hand nacharbeitet (`?? []` fuer Listen,
/// die im Schema wahlfrei sind), ist hier nichts zu tun: der Modellgenerator setzt die leere
/// Liste schon beim Lesen ein.
public struct Api: Sendable {
    public var zugang: Zugang
    private let sitzung: URLSession

    public init(zugang: Zugang, sitzung: URLSession = .shared) {
        self.zugang = zugang
        self.sitzung = sitzung
    }

    // MARK: - Das Fundament

    private static let leser: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private static let schreiber: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    /// Eine Anfrage stellen und die Antwort lesen.
    ///
    /// Modulweit sichtbar und nicht `private`, damit `@testable import` daran kommt: der
    /// Pruefstand ruft damit Wege ab, fuer die es keinen erzeugten Antworttyp gibt (den
    /// Fehlerumschlag und die zurueckgegebenen Urheber-Kopfzeilen). Oeffentlich ist er nicht -
    /// die App soll die benannten Griffe benutzen und keine Wege selbst zusammensetzen.
    func hole<T: Decodable>(
        _ pfad: String,
        fragen: [String: String?] = [:],
        verfahren: String = "GET",
        rumpf: Data? = nil,
        rumpfArt: String? = nil,
        _ typ: T.Type = T.self
    ) async throws -> T {
        let roh = try await bytes(pfad, fragen: fragen, verfahren: verfahren, rumpf: rumpf, rumpfArt: rumpfArt)
        do {
            return try Self.leser.decode(T.self, from: roh)
        } catch {
            // Eine Antwort, die nicht zum Schema passt, ist ein Fehler des Dienstes oder ein
            // veralteter Generatorlauf - beides soll benannt werden und nicht als leere Seite
            // enden.
            throw ApiFehler(
                code: "schema",
                meldung: "Die Antwort passt nicht zum Schema (\(pfad)). Läuft der Dienst in einer anderen Fassung? \(error)",
                status: 200
            )
        }
    }

    /// Eine Anfrage, deren Antwort reiner Text ist - die Tagesdiagnose und der Speicherbericht.
    private func text(_ pfad: String, fragen: [String: String?] = [:]) async throws -> String {
        let roh = try await bytes(pfad, fragen: fragen, verfahren: "GET", rumpf: nil, rumpfArt: nil)
        return String(decoding: roh, as: UTF8.self)
    }

    /// Die rohe Anfrage. Hier und nur hier wird aus HTTP ein `ApiFehler`.
    private func bytes(
        _ pfad: String,
        fragen: [String: String?],
        verfahren: String,
        rumpf: Data?,
        rumpfArt: String?
    ) async throws -> Data {
        guard let url = zugang.adresse(pfad, fragen) else {
            throw ApiFehler(code: "adresse", meldung: "Die Adresse des Hauses ist unbrauchbar.", status: 0)
        }
        var anfrage = URLRequest(url: url)
        anfrage.httpMethod = verfahren
        anfrage.cachePolicy = .reloadIgnoringLocalCacheData
        for (k, v) in zugang.kopfzeilen { anfrage.setValue(v, forHTTPHeaderField: k) }
        if let rumpf {
            anfrage.httpBody = rumpf
            anfrage.setValue(rumpfArt ?? "application/json", forHTTPHeaderField: "content-type")
        }

        let daten: Data
        let antwort: URLResponse
        do {
            (daten, antwort) = try await sitzung.daten(fuer: anfrage)
        } catch {
            throw ApiFehler.netz((error as NSError).localizedDescription)
        }
        guard let http = antwort as? HTTPURLResponse else {
            throw ApiFehler(code: "antwort", meldung: "Unverständliche Antwort.", status: 0)
        }
        guard (200..<300).contains(http.statusCode) else {
            let umschlag = try? Self.leser.decode(FehlerUmschlag.self, from: daten)
            throw ApiFehler(
                code: umschlag?.error?.code ?? "http_error",
                meldung: umschlag?.error?.message ?? "Fehler \(http.statusCode)",
                status: http.statusCode
            )
        }
        return daten
    }

    private func rumpf(_ wert: some Encodable) throws -> Data {
        try Self.schreiber.encode(wert)
    }

    /// Ein JSON-Rumpf aus einem Woerterbuch, fuer die wenigen Stellen, an denen kein Schematyp
    /// vorliegt (die Demo-Steuerung und die kleinen Schalter).
    private func rumpf(_ werte: [String: Mischwert]) throws -> Data {
        try Self.schreiber.encode(werte)
    }

    // MARK: - Leben und Verlauf

    /// Der Gesundheitszustand. `/health` hat im Schema kein eigenes Modell, sondern ein offenes
    /// Woerterbuch - also wird es auch hier eines.
    public func lebt() async throws -> [String: Mischwert] {
        try await hole("/health")
    }

    public func liveZustand() async throws -> LiveStateOut {
        try await hole("/live/state")
    }

    /// Der Verlauf in einem der festen Zeitraeume.
    public func verlauf(_ spanne: Verlaufsspanne = .heute) async throws -> HistoryOut {
        try await hole("/history", fragen: ["range": spanne.rawValue])
    }

    public enum Verlaufsspanne: String, Sendable {
        case heute = "today"
        case gestern = "yesterday"
        case letzte24h = "24h"
    }

    /// Minutenwerte eines beliebigen Tages.
    ///
    /// Ohne das ist der Verlauf nur fuer heute und gestern zu sehen - und genau der beantwortet
    /// die Frage „was ist an diesem Tag wirklich passiert?“.
    public func verlaufTag(von: Date, bis: Date) async throws -> HistoryOut {
        try await hole(
            "/history",
            fragen: ["range": "custom", "start": Zeit.iso(von), "end": Zeit.iso(bis)]
        )
    }

    /// Dieselbe Abfrage aus einem Kalendertag.
    public func verlaufTag(_ tag: String) async throws -> HistoryOut {
        guard let z = Tag.zeitraum(tag) else {
            throw ApiFehler(code: "tag", meldung: "„\(tag)“ ist kein Kalendertag.", status: 0)
        }
        return try await verlaufTag(von: z.von, bis: z.bis)
    }

    /// Reiner Text, kein JSON: die Diagnose ist eine Tabelle zum Lesen, keine Datenstruktur.
    public func diagnose(tag: String) async throws -> String {
        try await text("/energy/diagnose", fragen: ["day": tag])
    }

    public func plan() async throws -> PlanOut {
        try await hole("/plan")
    }

    /// Ein Ortstag in Euro: versprochen, gehalten, wirklich. Rechnet einen Vergleichslauf und
    /// braucht darum Sekunden.
    public func nachbetrachtung(tag: String) async throws -> NachbetrachtungOut {
        try await hole("/plan/nachbetrachtung", fragen: ["day": tag])
    }

    // MARK: - Energie und Geld

    public func energieUebersicht(_ zeitraum: String, anker: String) async throws -> EnergySummaryOut {
        try await hole("/energy/summary", fragen: ["period": zeitraum, "anchor": anker])
    }

    /// Der Vergleichslauf: dieselben Stunden ohne Preisblick.
    public func energieVerschiebung(_ zeitraum: String, anker: String) async throws -> ShiftReportOut {
        try await hole("/energy/shift", fragen: ["period": zeitraum, "anchor": anker])
    }

    public func energieWaerme(_ zeitraum: String, anker: String) async throws -> HeatReportOut {
        try await hole("/energy/heat", fragen: ["period": zeitraum, "anchor": anker])
    }

    public func waermebilanz(_ zeitraum: String, anker: String) async throws -> HeatBalanceOut {
        try await hole("/energy/waermebilanz", fragen: ["period": zeitraum, "anchor": anker])
    }

    public func energieWallbox(_ zeitraum: String, anker: String) async throws -> EvReportOut {
        try await hole("/energy/ev", fragen: ["period": zeitraum, "anchor": anker])
    }

    public func energiePv(_ zeitraum: String, anker: String) async throws -> PvTaxReportOut {
        try await hole("/energy/pv", fragen: ["period": zeitraum, "anchor": anker])
    }

    public func jahreskarte(jahr: Int) async throws -> YearMapOut {
        try await hole("/energy/year-map", fragen: ["year": String(jahr)])
    }

    /// Wie die Tagesdiagnose reiner Text: der Pruefbericht des Speichers, gegen Ladestand und
    /// Hausverbrauch gehalten.
    public func speicherPruefung(_ zeitraum: String, anker: String) async throws -> String {
        try await text("/energy/speicher-check", fragen: ["period": zeitraum, "anchor": anker])
    }

    // MARK: - Haus und Raeume

    /// Der Hausplan samt Kontakten. Geometrie von der Bruecke, Zustand aus dem Augenblick.
    public func haus() async throws -> HouseOut {
        try await hole("/haus")
    }

    public func raeume() async throws -> RoomsLiveOut {
        try await hole("/rooms")
    }

    public func raeumeTag(_ tag: String, schrittMin: Int = 15) async throws -> RoomHistoryOut {
        try await hole("/rooms/history", fragen: ["day": tag, "step_min": String(schrittMin)])
    }

    /// Das Protokoll eines Raums: Kurve und Zeitleiste ueber die letzten Stunden, hoechstens 48.
    public func raumProtokoll(_ id: Int, stunden: Int = 48, schrittMin: Int = 5) async throws -> RoomLogOut {
        try await hole("/rooms/\(id)/log", fragen: ["hours": String(stunden), "step_min": String(schrittMin)])
    }

    public func raumWirkung(_ id: Int, deltaK: Double) async throws -> RoomEffectOut {
        try await hole("/rooms/\(id)/wirkung", fragen: ["delta_k": String(deltaK)])
    }

    /// Dauerhaft, ohne Frist: derselbe Griff wie in Contromes eigener Oberflaeche.
    public func stelleRaum(_ id: Int, sollwertC: Double) async throws -> RoomSetpointOut {
        try await hole(
            "/rooms/\(id)/setpoint", verfahren: "POST",
            rumpf: try rumpf(["setpoint_c": .zahl(sollwertC)])
        )
    }

    /// Die Automatik fuer die thermische Masse. Aus, bis jemand sie einschaltet.
    public func raumAutomatik() async throws -> RoomShiftOut {
        try await hole("/rooms/automatik")
    }

    public func stelleRaumAutomatik(_ patch: RoomShiftIn) async throws -> RoomShiftOut {
        try await hole("/rooms/automatik", verfahren: "POST", rumpf: try rumpf(patch))
    }

    // MARK: - Anlage und Waermepumpe

    /// Das Anlagenschema: der Augenblick der Wasser- und Stromseite, in einer Antwort.
    public func anlage() async throws -> AnlageOut {
        try await hole("/anlage")
    }

    /// Dieselben Bilder ueber einen vergangenen Ortstag: die Wiedergabe.
    public func anlageWiedergabe(tag: String, schrittMin: Int = 5) async throws -> AnlageReplayOut {
        try await hole("/anlage/wiedergabe", fragen: ["day": tag, "step_min": String(schrittMin)])
    }

    /// Was K1 ausloest: die Ereignisstudie ueber 7, 30 oder 90 Tage.
    public func kontaktwirkung(tage: Int = 30) async throws -> KontaktwirkungOut {
        try await hole("/anlage/kontaktwirkung", fragen: ["days": String(tage)])
    }

    /// Die Technikseite der Waermepumpe: alle Messwerte des Augenblicks samt Abschaetzung.
    public func waermepumpe() async throws -> WaermepumpeOut {
        try await hole("/waermepumpe")
    }

    public func reglerKennzahlen(tage: Int = 7) async throws -> ReglerKennzahlenOut {
        try await hole("/waermepumpe/kennzahlen", fragen: ["tage": String(tage)])
    }

    public func reglerEinstellungen() async throws -> ReglerEinstellungenOut {
        try await hole("/waermepumpe/einstellungen")
    }

    /// Eine Einstellung des Reglers stellen.
    ///
    /// Gestellt ist sie erst, wenn der Regler sie zurueckmeldet - die Antwort traegt darum die
    /// vollstaendigen Einstellungen und nicht nur ein „in Ordnung“.
    public func stelleRegler(_ schluessel: String, wert: Double) async throws -> ReglerStellenOut {
        try await hole(
            "/waermepumpe/einstellungen/\(schluessel)", verfahren: "POST",
            rumpf: try rumpf(["wert": .zahl(wert)])
        )
    }

    /// Vermerken, dass eine Einstellung mit dem Bediengeraet verglichen ist (oder das zuruecknehmen).
    public func bestaetigeRegler(_ schluessel: String, bestaetigt: Bool) async throws -> ReglerStellenOut {
        try await hole(
            "/waermepumpe/einstellungen/\(schluessel)/bestaetigen", verfahren: "POST",
            rumpf: try rumpf(["bestaetigt": .ja(bestaetigt)])
        )
    }

    public func betrieb(tage: Int) async throws -> BetriebOut {
        try await hole("/waermepumpe/betrieb", fragen: ["tage": String(tage)])
    }

    public func kennlinie(tage: Int) async throws -> KennlinieOut {
        try await hole("/waermepumpe/kennlinie", fragen: ["tage": String(tage)])
    }

    // MARK: - Steuern

    public func batterie() async throws -> BatteryLiveOut {
        try await hole("/control/battery")
    }

    public func stelleBatterie(_ befehl: BatteryModeIn) async throws -> BatteryLiveOut {
        try await hole("/control/battery/mode", verfahren: "POST", rumpf: try rumpf(befehl))
    }

    public func stelleWaermepumpe(_ befehl: HeatPumpModeIn) async throws -> OperatingMode {
        try await hole("/control/heat-pump/mode", verfahren: "POST", rumpf: try rumpf(befehl))
    }

    public func stelleOfen(_ befehl: StoveModeIn) async throws -> StoveLiveOut {
        try await hole("/control/stove/mode", verfahren: "POST", rumpf: try rumpf(befehl))
    }

    public func schalte(_ schluessel: String, an: Bool, dauerMin: Int? = nil) async throws -> ActuatorCommandOut {
        var werte: [String: Mischwert] = ["state": .ja(an)]
        werte["duration_min"] = dauerMin.map { Mischwert.ganz($0) } ?? .nichts
        return try await hole("/control/actuators/\(schluessel)", verfahren: "POST", rumpf: try rumpf(werte))
    }

    /// Nur schaerfen. Einen Weg zum Entschaerfen gibt es nicht, und das ist Absicht.
    public func schaerfeAlarm(_ art: AlarmArt) async throws -> AlarmArmOut {
        try await hole(
            "/control/alarm/arm", verfahren: "POST",
            rumpf: try rumpf(["mode": .text(art.rawValue)])
        )
    }

    public enum AlarmArt: String, Sendable {
        case daheim = "home"
        case fort = "away"
    }

    public func entscheidungen() async throws -> [Decision] {
        try await hole("/control/decisions")
    }

    // MARK: - Prognose, Anlagenzustand, System

    public func prognoseBewertung() async throws -> ForecastEvaluationOut {
        try await hole("/forecast/evaluation")
    }

    /// Der Rueckblick aus `forecast_runs`: wie gut die Prognose war, nach Abstand zur Lieferung.
    /// Etwas anderes als `prognoseBewertung`, das nur den Arbeitsspeicher des Bewerters zeigt.
    public func prognoseVerlauf(tage: Int = 7) async throws -> ForecastHistoryOut {
        try await hole("/forecast/history", fragen: ["days": String(tage)])
    }

    public func abdeckung(anker: String, tage: Int) async throws -> CoverageOut {
        try await hole("/system/coverage", fragen: ["anchor": anker, "days": String(tage)])
    }

    public func haustuer(tage: Int) async throws -> DoorLogOut {
        try await hole("/system/door", fragen: ["days": String(tage)])
    }

    public func datenbestand() async throws -> StorageReportOut {
        try await hole("/system/storage")
    }

    public func speicher() async throws -> AnlageSpeicherOut {
        try await hole("/system/speicher")
    }

    // MARK: - Einstellungen

    public func einstellungen() async throws -> HemsConfig {
        try await hole("/config")
    }

    public func stelleWaerme(_ patch: HeatConfigIn) async throws -> HemsConfig {
        try await hole("/config/heat", verfahren: "POST", rumpf: try rumpf(patch))
    }

    // MARK: - Rechnungen

    public func rechnungen() async throws -> [InvoiceSummaryOut] {
        try await hole("/import/tibber-invoices")
    }

    public func rechnung(_ nummer: String) async throws -> InvoiceReportOut {
        let entschaerft = nummer.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? nummer
        return try await hole("/import/tibber-invoices/\(entschaerft)")
    }

    /// Eine Rechnung pruefen. Der Rumpf ist das PDF selbst, nicht JSON.
    public func pruefeRechnung(_ pdf: Data, name: String) async throws -> InvoiceReportOut {
        try await hole(
            "/import/tibber-invoice", fragen: ["file_name": name], verfahren: "POST",
            rumpf: pdf, rumpfArt: "application/pdf"
        )
    }

    // MARK: - Mitteilungen

    /// Der oeffentliche Schluessel darf in jeder Seite stehen; der private verlaesst den Dienst nie.
    public func mitteilungSchluessel() async throws -> PushKeyOut {
        try await hole("/push/key")
    }

    public func meldeGeraetAn(_ anmeldung: PushSubscribeIn) async throws -> PushResultOut {
        try await hole("/push/subscribe", verfahren: "POST", rumpf: try rumpf(anmeldung))
    }

    public func meldeGeraetAb(endpunkt: String) async throws -> PushResultOut {
        try await hole("/push/unsubscribe", verfahren: "POST", rumpf: try rumpf(["endpoint": .text(endpunkt)]))
    }

    public func mitteilungProbe() async throws -> PushResultOut {
        try await hole("/push/test", verfahren: "POST")
    }

    public func mitteilungGeraete() async throws -> PushGeraeteOut {
        try await hole("/push/geraete")
    }

    /// Der Morgenbrief: ob er kommt, was heute darin stuende, und ein Versand zur Probe.
    public func morgenbrief() async throws -> MorgenbriefOut {
        try await hole("/push/morgenbrief")
    }

    public func stelleMorgenbrief(an: Bool) async throws -> MorgenbriefOut {
        try await hole("/push/morgenbrief", verfahren: "PUT", rumpf: try rumpf(["enabled": .ja(an)]))
    }

    public func sendeMorgenbrief() async throws -> PushResultOut {
        try await hole("/push/morgenbrief/senden", verfahren: "POST")
    }

    // MARK: - Demo

    /// Die Demo steuern: Zeitraffer, Szenarien, Stoerungen. Nur im Demo-Betrieb vorhanden.
    public func demo(_ werte: [String: Mischwert]) async throws -> [String: Mischwert] {
        try await hole("/demo", verfahren: "POST", rumpf: try rumpf(werte))
    }
}

extension URLSession {
    /// `data(for:)` gibt es auf Linux nicht, nur die Fassung mit Rueckruf. Diese Huelle macht
    /// daraus auf beiden Plattformen dasselbe - und ist der Grund, warum die Netzschicht dieses
    /// Pakets auch unter Linux gebaut und geprueft werden kann.
    func daten(fuer anfrage: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
            return try await withCheckedThrowingContinuation { fort in
                let aufgabe = dataTask(with: anfrage) { daten, antwort, fehler in
                    if let fehler {
                        fort.resume(throwing: fehler)
                    } else if let daten, let antwort {
                        fort.resume(returning: (daten, antwort))
                    } else {
                        fort.resume(
                            throwing: URLError(.badServerResponse)
                        )
                    }
                }
                aufgabe.resume()
            }
        #else
            return try await data(for: anfrage)
        #endif
    }
}

extension Api {
    /// Dieses Gerät für APNs anmelden.
    ///
    /// Der Rumpf hat denselben Zuschnitt wie bei Web Push (`PushSubscribeIn`): eine Adresse,
    /// ein Name, eine Herkunft. Nur dass die Adresse hier ein Gerätetoken ist und die beiden
    /// Schlüssel fehlen – APNs verschlüsselt selbst.
    ///
    /// **`sandbox` ist ein Parameter und keine Abfrage von `#if DEBUG`.** Diese Entscheidung
    /// hängt an der Signatur des Baus und gehört damit in die App; der Kern baut auch dort,
    /// wo es kein Bundle gibt, und soll nicht wissen, wie er signiert wurde. Die App übergibt
    /// `Bauart.istEntwicklung`. Wer es verwechselt, bekommt von Apple „BadDeviceToken" ohne
    /// weitere Auskunft, denn ein Token aus einem Entwicklungsbau gilt an einer anderen
    /// Adresse als eines aus dem App Store.
    public func meldeApnsAn(
        token: String, name: String, sandbox: Bool
    ) async throws -> PushResultOut {
        try await hole(
            "/push/apns/subscribe", verfahren: "POST",
            rumpf: try JSONEncoder().encode([
                "token": Mischwert.text(token),
                "label": .text(name),
                "sandbox": .ja(sandbox),
            ])
        )
    }

    // MARK: - Alfred

    /// Kann Alfred antworten? Liest nur Einstellungen; kein Modell, keine Kosten.
    public func alfredZustand() async throws -> AlfredZustandOut {
        try await hole("/alfred/status")
    }

    /// Eine Frage an den Helfer, ohne Fortschritt.
    ///
    /// Ohne eingerichtetes Modell kommt `bereit == false` statt eines Fehlers zurueck - die
    /// Oberflaeche zeigt dann ihre vorbereiteten Texte.
    public func alfredFrage(_ frage: AlfredFrageIn) async throws -> AlfredAntwortOut {
        try await hole("/alfred/ask", verfahren: "POST", rumpf: try rumpf(frage))
    }

    /// Dieselbe Frage, mit Fortschritt: je laufendem Werkzeug ein Name.
    ///
    /// **POST und kein `EventSource`.** Die Frage traegt die Hilfetexte im Rumpf; ein
    /// Ereignisstrom ueber GET koennte sie nicht mitnehmen. Der Dienst antwortet darum mit
    /// `text/event-stream` im Rumpf eines POST, und gelesen wird er mit demselben
    /// ``Rohstrom``, der den Live-Strom des Hauses liest.
    ///
    /// Der Dienst meldet nur den **Namen** des Werkzeugs; den Satz dazu hat die Oberflaeche
    /// (``Alfred/schrittText(_:)``). Ein unbekanntes Werkzeug ist kein Fehler: der Dienst darf
    /// wachsen, ohne dass die App im selben Zug nachzieht.
    public func alfredFrageMitFortschritt(
        _ frage: AlfredFrageIn, schritt: @escaping @Sendable (String) -> Void
    ) async throws -> AlfredAntwortOut {
        guard let url = zugang.adresse("/alfred/ask/stream", [:]) else {
            throw ApiFehler(code: "adresse", meldung: "Die Adresse des Hauses ist unbrauchbar.", status: 0)
        }
        var anfrage = URLRequest(url: url)
        anfrage.httpMethod = "POST"
        anfrage.cachePolicy = .reloadIgnoringLocalCacheData
        for (k, v) in zugang.kopfzeilen { anfrage.setValue(v, forHTTPHeaderField: k) }
        anfrage.setValue("application/json", forHTTPHeaderField: "content-type")
        anfrage.setValue("text/event-stream", forHTTPHeaderField: "accept")
        anfrage.setValue("no-cache", forHTTPHeaderField: "cache-control")
        // Eine Frage mit Werkzeugen dauert laenger als die ueblichen sechzig Sekunden: das
        // Modell holt erst Bilanzen, dann antwortet es. Zwei Minuten sind die Grenze, nach
        // der niemand mehr wartet.
        anfrage.timeoutInterval = 120
        anfrage.httpBody = try rumpf(frage)

        // **Eine eigene Sitzung, in der der Strom selbst der Zusteller ist.** Hier stand
        // `sitzung` - die geteilte Sitzung dieses Clients, deren Zusteller niemand ist. Damit
        // rief `URLSession` die Rueckmeldungen von ``Rohstrom`` nie auf: kein Byte kam an, der
        // Strom lieferte nichts und endete nie, und die Oberflaeche stand fuer immer auf „Ich
        // denke nach ...". Gemeldet am 17.11. von einem Geraet, auf dem Alfred eine Frage
        // schickte und keine Antwort bekam.
        //
        // `LiveStrom` macht es seit jeher richtig; beim Mitbenutzen von `Rohstrom` ist mir
        // entgangen, dass die halbe Einrichtung in der Sitzung steckt.
        let strom = Rohstrom()
        let stromsitzung = URLSession(configuration: .ephemeral, delegate: strom, delegateQueue: nil)
        defer { stromsitzung.invalidateAndCancel() }

        var leser = SseLeser()
        for try await stueck in strom.oeffne(anfrage, in: stromsitzung) {
            for ereignis in leser.nimm(stueck) {
                guard let daten = ereignis.daten.data(using: .utf8) else { continue }
                switch ereignis.art {
                case "schritt":
                    if let s = try? Self.leser.decode(AlfredSchritt.self, from: daten) {
                        schritt(s.werkzeug)
                    }
                case "antwort":
                    if let a = try? Self.leser.decode(AlfredAntwortOut.self, from: daten) {
                        return a
                    }
                case "fehler":
                    let u = try? Self.leser.decode(FehlerUmschlag.self, from: daten)
                    throw ApiFehler(
                        code: u?.error?.code ?? "alfred",
                        meldung: u?.error?.message ?? "Alfred konnte nicht antworten.",
                        status: 200)
                default:
                    break
                }
            }
        }
        // Der Strom endete ohne Antwort - abgebrochene Verbindung, Zeitueberschreitung.
        throw ApiFehler(
            code: "abbruch", meldung: "Die Verbindung zu Alfred ist abgerissen.", status: 0)
    }

    /// Eine Stromrechnung als PDF: erkennen, pruefen, zusammenfassen.
    ///
    /// **Erst die feste Erkennung, dann das Modell.** Liest die Tibber-Pruefung das PDF, wird
    /// es ohne Sprachmodell geprueft und abgelegt - nichts verlaesst das Haus, auch ohne
    /// eingerichteten Schluessel.
    public func alfredRechnung(pdf: Data) async throws -> AlfredRechnungOut {
        try await hole(
            "/alfred/rechnung", verfahren: "POST", rumpf: pdf, rumpfArt: "application/pdf")
    }

    /// Einrichtung: aus einer eingefuegten Entitaetenliste einen YAML-Ausschnitt vorschlagen.
    /// Schreibt nichts; die Datei liegt in Home Assistant.
    public func alfredZuordnung(liste: String) async throws -> Zuordnungsergebnis {
        try await hole(
            "/alfred/zuordnung", verfahren: "POST",
            rumpf: try rumpf(AlfredZuordnungIn(liste: liste)))
    }

    /// Dieses Gerät abmelden.
    public func meldeApnsAb(token: String) async throws -> PushResultOut {
        try await hole(
            "/push/apns/unsubscribe", verfahren: "POST",
            rumpf: try JSONEncoder().encode(["token": Mischwert.text(token)])
        )
    }
}
