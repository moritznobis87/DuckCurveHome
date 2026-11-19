import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Was aus dem Ereignisstrom bei der Anzeige ankommt.
public enum Stromnachricht: Sendable {
    /// Ein neues Augenblicksbild.
    case zustand(LiveStateOut)
    /// Eine Entscheidung des Reglers.
    case entscheidung(Decision)
    /// Ein neuer Plan.
    case plan(PlanOut)
    /// Ein Lebenszeichen mit der Serverzeit. Keine neue Zahl, aber ein Zeichen, dass die
    /// Verbindung steht - und die Grundlage fuer den Zeitversatz zum Dienst.
    case herzschlag(Date)
    /// Der Zustand der Verbindung hat sich geaendert.
    case verbindung(Verbindung)
    /// Etwas ist schiefgegangen. Der Strom versucht es von sich aus weiter; diese Nachricht ist
    /// fuer die Anzeige, die sagen soll, woran es liegt.
    case fehler(ApiFehler)
}

/// Die Verbindung zum Ereignisstrom des Hauses: `/live/stream` als `text/event-stream`.
///
/// **Warum nicht `URLSession.bytes(for:)`.** Das waere unter iOS der kurze Weg, gibt es aber in
/// der Foundation unter Linux nicht - und damit waere dieser Typ der einzige der Netzschicht, der
/// sich auf dem Pruefrechner nicht einmal kompilieren laesst. Der Weg ueber
/// `URLSessionDataDelegate` ist zwei Dutzend Zeilen laenger und laeuft auf beiden Seiten. Das ist
/// der Handel, und er ist bewusst so geschlossen: ein Stueck Netzschicht, das nur auf einem Mac
/// baut, ist ein Stueck Netzschicht, dessen Fehler erst am Geraet auffallen.
///
/// **Was dieser Typ nicht tut.** Er haelt keinen Zustand der Anwendung, legt keine Historie an
/// und entscheidet nicht, welcher Tag angezeigt wird. Er stellt die Verbindung her, haelt sie und
/// liefert, was kommt. Was daraus wird, entscheidet `Hauszustand` in der App.
public actor LiveStrom {
    private var zugang: Zugang
    private var politik = Verbindungspolitik()
    private var aufgabe: Task<Void, Never>?
    private var fortsetzung: AsyncStream<Stromnachricht>.Continuation?
    /// Wann der letzte Rahmen irgendeiner Art kam. Grundlage der Aufsicht.
    private var letzterRahmen: Date?

    public init(zugang: Zugang) {
        self.zugang = zugang
    }

    /// Den Strom oeffnen. Die Folge endet erst, wenn `halte()` gerufen wird.
    public func nachrichten() -> AsyncStream<Stromnachricht> {
        AsyncStream { fort in
            self.fortsetzung = fort
            self.starte()
        }
    }

    /// Den Zugang austauschen - nach dem Einrichten oder einem Wechsel des Tokens.
    public func setze(zugang neu: Zugang) {
        zugang = neu
        politik = Verbindungspolitik()
        starte()
    }

    /// Anhalten, weil die App weggelegt wurde. Kein Wecker, keine Verbindung, keine Batterie.
    public func beimWegbleiben() {
        aufgabe?.cancel()
        aufgabe = nil
        letzterRahmen = nil
        fortsetzung?.yield(.verbindung(.aus))
    }

    /// Sofort wieder verbinden, ohne Wartezeit: der Benutzer sieht gerade hin.
    public func beimZurueckkommen() {
        politik.gelungen()
        starte()
    }

    public func halte() {
        aufgabe?.cancel()
        aufgabe = nil
        fortsetzung?.finish()
        fortsetzung = nil
    }

    // MARK: - Innen

    private func starte() {
        aufgabe?.cancel()
        aufgabe = Task { [weak self] in
            await self?.schleife()
        }
    }

    /// Verbinden, lesen, bei Abriss warten und wieder verbinden - bis die Aufgabe abgebrochen wird.
    private func schleife() async {
        while !Task.isCancelled {
            melde(.verbindung(politik.fehlversuche == 0 ? .verbindet : .verbindetNeu))
            do {
                try await lies()
                // Der Strom ist in Ordnung zu Ende gegangen (der Dienst hat ihn geschlossen).
                // Das ist kein Fehler, aber auch kein Zustand, in dem man bleibt.
                _ = politik.gescheitert()
            } catch is CancellationError {
                return
            } catch let fehler as ApiFehler {
                melde(.fehler(fehler))
                // Bei einem falschen Token hilft Wiederholen nicht. Die Anzeige soll es sagen und
                // nicht im Minutentakt dasselbe versuchen.
                if !fehler.lohntWiederholung {
                    melde(.verbindung(.aus))
                    return
                }
                _ = politik.gescheitert()
            } catch {
                melde(.fehler(.netz((error as NSError).localizedDescription)))
                _ = politik.gescheitert()
            }
            guard !Task.isCancelled else { return }
            melde(.verbindung(.verbindetNeu))
            let warten = politik.naechsteWartezeit
            try? await Task.sleep(nanoseconds: UInt64(warten * 1_000_000_000))
        }
    }

    /// Eine Verbindung aufbauen und lesen, bis sie abreisst.
    private func lies() async throws {
        guard let url = zugang.adresse("/live/stream") else {
            throw ApiFehler(code: "adresse", meldung: "Die Adresse des Hauses ist unbrauchbar.", status: 0)
        }
        var anfrage = URLRequest(url: url)
        anfrage.setValue("text/event-stream", forHTTPHeaderField: "accept")
        anfrage.setValue("no-cache", forHTTPHeaderField: "cache-control")
        for (k, v) in zugang.kopfzeilen where k != "accept" {
            anfrage.setValue(v, forHTTPHeaderField: k)
        }
        // Kein Zeitablauf auf der Anfrage selbst: ein Ereignisstrom ist absichtlich endlos. Die
        // Aufsicht unten erkennt eine verstummte Verbindung, nicht eine lange.
        anfrage.timeoutInterval = 3600

        let strom = Rohstrom()
        let sitzung = URLSession(configuration: .ephemeral, delegate: strom, delegateQueue: nil)
        defer { sitzung.invalidateAndCancel() }

        var leser = SseLeser()
        politik.gelungen()
        letzterRahmen = Date()

        for try await stueck in strom.oeffne(anfrage, in: sitzung) {
            letzterRahmen = Date()
            for ereignis in leser.nimm(stueck) {
                verarbeite(ereignis)
            }
            try Task.checkCancellation()
        }
    }

    private func verarbeite(_ ereignis: SseEreignis) {
        let daten = Data(ereignis.daten.utf8)
        switch ereignis.art {
        case "snapshot":
            guard let z = try? JSONDecoder().decode(LiveStateOut.self, from: daten) else {
                melde(.fehler(ApiFehler(code: "schema", meldung: "Ein Augenblicksbild war nicht lesbar.", status: 200)))
                return
            }
            melde(.verbindung(.live))
            melde(.zustand(z))
            if let e = z.decision { melde(.entscheidung(e)) }
        case "decision":
            if let e = try? JSONDecoder().decode(Decision.self, from: daten) { melde(.entscheidung(e)) }
        case "plan":
            if let p = try? JSONDecoder().decode(PlanOut.self, from: daten) { melde(.plan(p)) }
        case "heartbeat":
            if let d = Zeit.ausIso(ereignis.daten) { melde(.herzschlag(d)) }
        default:
            // Ein unbekanntes Ereignis ist kein Fehler. Der Dienst darf wachsen, ohne dass die
            // App im selben Zug nachzuziehen hat.
            break
        }
    }

    private func melde(_ n: Stromnachricht) {
        fortsetzung?.yield(n)
    }
}
