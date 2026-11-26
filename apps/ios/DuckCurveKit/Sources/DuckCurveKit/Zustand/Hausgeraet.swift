import Foundation

/// Was die Seite „Hausgerät“ aus `GeraetOut` und `UpdateStatusOut` macht - ohne SwiftUI, damit es
/// hier getestet wird und nicht erst auf einem Mac.
///
/// **Bewertet wird nicht hier.** Ampel und Satz kommen fertig aus der API
/// (`apps/api/src/dch_api/routers/geraet.py`), dieselben wie im Dashboard
/// (`apps/web/src/components/geraet/Geraet.tsx`). Hier stehen nur Namen, Dauern und die Frage,
/// ob gerade etwas läuft - und die Namen müssen zu denen im Dashboard passen, sonst heißt die
/// Datenbank im Browser anders als am iPad.
public enum Hausgeraet {
    /// Das Zeichen jeder Karte auf „Hausgerät“, wie im Dashboard
    /// (`apps/web/src/components/geraet/abschnitte.ts`). Seit dem 25.11.2026 trägt jeder
    /// Abschnitt der Seite eine Karte mit Zeichen wie die übrigen Systemseiten.
    public static let abschnittszeichen: [String: Zeichenart] = [
        "Dienste": .anzeige,
        "Rechenkern": .blitz,
        "Gerät": .haus,
        "SSD-Gesundheit": .schild,
        "Platz auf der SSD": .batterie,
        "Verlauf": .diagramm,
        "Sicherung": .kalender,
        "Abläufe auf dem Gerät": .uhr,
        "Software": .kreis,
        "Neu starten": .warnung,
    ]

    /// Das Zeichen zu einem Abschnitt; ein unbekannter bekommt die Anzeige.
    public static func zeichen(_ abschnitt: String) -> Zeichenart {
        abschnittszeichen[abschnitt] ?? .anzeige
    }

    /// Die Ampel, über alle Teile gleich. Der Generator legt für jedes Feld eine eigene
    /// Aufzählung an (`GeraetDienstOutAmpelWahl`, `ApiSelbstOutAmpelWahl`, …); die Oberfläche
    /// braucht eine.
    public enum Ampel: String, Sendable, CaseIterable {
        case gut, warn, schlecht, aus

        public init(_ roh: String?) {
            self = roh.flatMap(Ampel.init(rawValue:)) ?? .aus
        }

        public var wort: String {
            switch self {
            case .gut: return "in Ordnung"
            case .warn: return "Hinweis"
            case .schlecht: return "Störung"
            case .aus: return "keine Angabe"
            }
        }
    }

    /// Was die Dienste für jemanden sind, der nicht weiß, was ein Container ist.
    public static let dienstnamen: [String: String] = [
        "api": "Rechenkern (API)",
        "web": "Oberfläche",
        "postgres": "Datenbank",
        "caddy": "Webserver (HTTPS)",
        "cloudflared": "Fernzugang",
    ]

    public static let einheitennamen: [String: String] = [
        "duckcurve.service": "Start beim Einschalten",
        "duckcurve-anfrage.path": "Anfragen aus der App",
        "duckcurve-zustand.timer": "Gesundheitsbericht (jede Minute)",
        "duckcurve-pruefen.timer": "Nach Updates sehen (alle 6 Stunden)",
        "duckcurve-sicherung.timer": "Nächtliche Sicherung",
        "duckcurve-kiosk.service": "Anzeige am Bildschirm",
    ]

    static let handgriffe: [String: String] = [
        "neustart": "Neustart",
        "sichern": "Sicherung",
        "protokoll": "Protokoll",
        "geraet_neustart": "Gerät neu starten",
        "zustand": "Bericht erneuern",
    ]

    public static func dienstname(_ name: String) -> String {
        dienstnamen[name] ?? name
    }

    /// Die Fußzeile der Karte Rechenkern, dieselbe wie im Dashboard (`rechenkernZeile` in Geraet.tsx).
    /// Ein Commit-Hash erscheint nicht; `version` ist die Version aus docs/versionen.json.
    public static func rechenkernzeile(_ api: ApiSelbstOut) -> String {
        let n = api.sseClients ?? 0
        let ansichten = n == 1 ? "1 offene Ansicht" : "\(n) offene Ansichten"
        let mb = Int(api.rssMb.rounded())
        return "Fassung \(api.version) · läuft seit \(dauer(sekunden: api.laufzeitS)) · \(mb) MB · \(ansichten)"
    }

    /// Eine Gruppe von Neuerungen derselben Version; `version` leer heißt: noch keiner zugeordnet.
    public struct Neuerungsgruppe: Hashable, Sendable {
        public let version: String?
        public let eintraege: [UpdateNeuerungOut]
    }

    /// Die Neuerungen in Gruppen derselben Version, in der Reihenfolge des Dienstes (neueste
    /// zuerst). Eine Überschrift braucht es erst ab zwei Gruppen; das Dashboard gruppiert genauso
    /// (`nachVersion` in useUpdate.ts).
    public static func neuerungenNachVersion(_ neuerungen: [UpdateNeuerungOut]) -> [Neuerungsgruppe] {
        var gruppen: [Neuerungsgruppe] = []
        for n in neuerungen {
            if let letzte = gruppen.last, letzte.version == n.version {
                gruppen[gruppen.count - 1] = Neuerungsgruppe(version: letzte.version, eintraege: letzte.eintraege + [n])
            } else {
                gruppen.append(Neuerungsgruppe(version: n.version, eintraege: [n]))
            }
        }
        return gruppen
    }

    public static func gruppentitel(_ version: String?) -> String {
        version.map { "Version \($0)" } ?? "Seit der letzten Version"
    }

    /// „3 h 12 min“, „2 T 4 h“ - wie lange etwas schon läuft.
    public static func dauer(sekunden: Int) -> String {
        let s = max(0, sekunden)
        let t = s / 86_400
        let h = (s % 86_400) / 3_600
        let m = (s % 3_600) / 60
        if t > 0 { return "\(t) T \(h) h" }
        if h > 0 { return "\(h) h \(m) min" }
        if m > 0 { return "\(m) min" }
        return "\(s) s"
    }

    /// Wie lange seit einem Zeitpunkt aus der API, als Dauer.
    public static func seit(iso: String?, jetzt: Date = Date()) -> String {
        guard let iso, let d = Zeitpunkt.lies(iso) else { return "–" }
        return dauer(sekunden: Int(jetzt.timeIntervalSince(d).rounded()))
    }

    public static func gigabyte(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1e9
        return "\(Formate.zahl(gb, stellen: gb >= 100 ? 0 : 1)) GB"
    }

    /// Ob das Gerät gerade beschäftigt ist: Dann sind alle Handgriffe gesperrt.
    public static func beschaeftigt(_ g: GeraetOut?) -> Bool {
        guard let g else { return false }
        return g.beschaeftigt != nil || g.letzteAktion?.zustand == "laeuft"
    }

    /// Die zuletzt angefragte Aktion als Satz: „Neustart Oberfläche, 14:02: Neu gestartet.“
    public static func aktionssatz(_ g: GeraetOut) -> (text: String, fehler: Bool)? {
        guard let a = g.letzteAktion else { return nil }
        var was = handgriffe[a.aktion] ?? a.aktion
        if let d = a.dienst {
            was += d == "alle" ? " aller Dienste" : " \(dienstname(d))"
        }
        if a.zustand == "laeuft" { return ("\(was) läuft …", false) }
        let meldung = a.meldung.flatMap { $0.isEmpty ? nil : $0 }
            ?? (a.zustand == "ok" ? "erledigt." : "fehlgeschlagen.")
        return ("\(was), \(Formate.hhmm(iso: a.beendetAm)): \(meldung)", a.zustand != "ok")
    }

    // MARK: - Größen und Prognose

    /// Höchstens `stellen` Nachkommastellen, Nullen am Ende weg: „2,5“ statt „2,50“, wie
    /// `toLocaleString("de-DE", { maximumFractionDigits })` im Dashboard.
    public static func kurz(_ wert: Double, stellen: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = stellen
        return f.string(from: NSNumber(value: wert)) ?? String(wert)
    }

    /// „1,2 GB“, „840 MB“, „2,5 TB“ - dezimal, wie Plattenhersteller und `df -H` zählen.
    public static func bytes(_ b: Int?) -> String {
        guard let b else { return "–" }
        let a = abs(Double(b))
        if a >= 1e12 { return "\(kurz(Double(b) / 1e12, stellen: 2)) TB" }
        if a >= 1e9 { return "\(kurz(Double(b) / 1e9, stellen: 1)) GB" }
        if a >= 1e6 { return "\(kurz(Double(b) / 1e6, stellen: 1)) MB" }
        return "\(kurz(Double(b) / 1e3, stellen: 0)) kB"
    }

    /// „in etwa 13 Monaten“ - eine Schätzung, kein Termin.
    public static func ungefaehr(tage: Int) -> String {
        if tage >= 730 { return "in etwa \(Int((Double(tage) / 365).rounded())) Jahren" }
        if tage >= 60 { return "in etwa \(Int((Double(tage) / 30).rounded())) Monaten" }
        return "in etwa \(tage) Tagen"
    }

    /// Dieselben Sätze wie `prognoseSaetze` im Dashboard (`components/geraet/Verlauf.tsx`).
    public static func prognosesaetze(_ p: GeraetPrognoseOut?) -> [String] {
        let tage = p?.tageVerlauf ?? 0
        guard let p, tage >= 7 else {
            return ["Für eine Prognose braucht es sieben Tage Verlauf; bisher sind es \(kurz(tage, stellen: 1))."]
        }
        var saetze: [String] = []
        if let rate = p.platteBytesProTag {
            if rate <= 0 {
                saetze.append("Die SSD füllt sich derzeit nicht.")
            } else {
                let voll = p.platteVollInTagen.map { "; bei diesem Tempo ist sie \(ungefaehr(tage: $0)) voll" } ?? ""
                saetze.append("Die SSD füllt sich um \(bytes(rate)) pro Tag\(voll).")
            }
        }
        if let db = p.datenbankBytesProTag { saetze.append("Die Datenbank wächst um \(bytes(db)) pro Tag.") }
        if let w = p.ssdGeschriebenBytesProTag { saetze.append("Auf die SSD werden \(bytes(w)) pro Tag geschrieben.") }
        return saetze
    }

    /// Ein Abschnitt des Platzbalkens.
    public struct Platzteil: Sendable, Hashable {
        public let name: String
        public let bytes: Int
        /// Programme, Daten, Sicherungen, Rest, frei - die Oberfläche wählt danach die Farbe.
        public let art: String
    }

    /// Wofür der Platz auf der SSD draufgeht; wie `platzAbschnitte` im Dashboard.
    public static func platz(_ g: GeraetOut) -> [Platzteil]? {
        guard let p = g.rechner?.platten.first(where: { $0.ort == "/" }) else { return nil }
        let d = g.rechner?.dockerPlatz
        let belegt = p.gesamtBytes - p.freiBytes
        let programme = (d?.imagesBytes ?? 0) + (d?.containerBytes ?? 0) + (d?.cacheBytes ?? 0)
        let daten = d?.volumesBytes ?? 0
        let sicherungen = g.sicherung?.gesamtBytes ?? 0
        let rest = max(0, belegt - programme - daten - sicherungen)
        return [
            Platzteil(name: "Programme (Docker-Images, Cache)", bytes: programme, art: "programme"),
            Platzteil(name: "Daten (Datenbank und Volumes)", bytes: daten, art: "daten"),
            Platzteil(name: "Sicherungen", bytes: sicherungen, art: "sicherungen"),
            Platzteil(name: "System und Sonstiges", bytes: rest, art: "rest"),
            Platzteil(name: "frei", bytes: p.freiBytes, art: "frei"),
        ]
    }

    /// Ein Punkt einer Linie im Verlauf. `stueck` wechselt an jeder Lücke, damit die Linie dort
    /// reißt, statt eine Zeit ohne Werte zu überbrücken (Swift Charts verbindet sonst alles).
    public struct Linienpunkt: Sendable, Hashable, Identifiable {
        public let t: Date
        public let wert: Double
        public let stueck: Int
        public var id: Date { t }
    }

    public static func linie(
        _ punkte: [GeraetVerlaufPunktOut], schrittMin: Int, _ wert: (GeraetVerlaufPunktOut) -> Double?
    ) -> [Linienpunkt] {
        var aus: [Linienpunkt] = []
        var stueck = 0
        var vorher: Date?
        for p in punkte {
            guard let t = Zeitpunkt.lies(p.t) else { continue }
            guard let w = wert(p) else {
                stueck += 1
                vorher = nil
                continue
            }
            if let v = vorher, t.timeIntervalSince(v) > Double(schrittMin) * 90 { stueck += 1 }
            aus.append(Linienpunkt(t: t, wert: w, stueck: stueck))
            vorher = t
        }
        return aus
    }

    // MARK: - Updates

    /// Ob der Hinweis „Update bereit“ über der Seite stehen soll - wie `UpdateHinweis.tsx`: nur
    /// für den Hausherrn, nicht auf der Seite Hausgerät selbst (dort steht es ausführlich), nicht
    /// für eine Fassung, die schon einmal nicht hochkam, und nicht, wenn diese Fassung mit
    /// „Nicht jetzt“ weggeklickt wurde. Während eines Updates immer.
    public static func zeigeHinweis(_ s: UpdateStatusOut?, weg: String, hausherr: Bool, weggeklickt: String?) -> Bool {
        guard hausherr, let s, s.unterstuetzt == true, !weg.hasPrefix("/system/geraet") else { return false }
        if updateLaeuft(s) { return true }
        guard s.updateVerfuegbar == true, !schonGescheitert(s) else { return false }
        return weggeklickt == nil || weggeklickt != s.verfuegbar
    }

    public static func hinweissatz(_ s: UpdateStatusOut) -> String {
        if updateLaeuft(s) { return "Duck Curve wird gerade aktualisiert. Die Anwendung startet dabei einmal neu." }
        let n = s.neuerungen.count
        let mit = n == 0 ? "" : " mit \(n) \(n == 1 ? "Neuerung" : "Neuerungen")"
        return "Für Duck Curve steht ein Update bereit\(mit)."
    }

    /// Ob ein Update läuft oder angefragt ist.
    public static func updateLaeuft(_ s: UpdateStatusOut?) -> Bool {
        guard let s else { return false }
        return s.zustand == "laeuft" || s.anfrageOffen == true
    }

    /// Ob die angebotene Fassung genau die ist, die beim letzten Versuch nicht gesund hochkam.
    /// Dann drängt nichts mehr zum Installieren; ein zweiter Versuch bleibt möglich.
    public static func schonGescheitert(_ s: UpdateStatusOut?) -> Bool {
        guard let s, let verfuegbar = s.verfuegbar, let z = s.zuletzt else { return false }
        return z.ergebnis != "ok" && z.nach == verfuegbar
    }

    /// Die Schritte eines Updates, wie `dch` sie meldet, mit dem Wort für die Oberfläche.
    public static let updateSchritte: [(schluessel: String, text: String)] = [
        ("Sicherung", "Datenbank sichern"),
        ("Quelltext", "Einrichtung nachziehen"),
        ("Laden", "Neue Fassung laden"),
        ("Neustart", "Neu starten"),
        ("Pruefung", "Prüfen, ob alles läuft"),
    ]

    /// Was nach einem Update dasteht, oder `nil`.
    public static func updateErgebnis(_ s: UpdateStatusOut) -> String? {
        switch s.zustand {
        case "fertig":
            if let am = s.zuletzt?.am { return "Zuletzt aktualisiert um \(Formate.hhmm(iso: am))." }
            return s.meldung
        case "zurueckgerollt":
            return s.meldung ?? "Die neue Fassung kam nicht gesund hoch; die vorherige läuft wieder."
        case "fehlgeschlagen":
            return s.meldung ?? "Das Update ist fehlgeschlagen."
        default:
            return s.meldung
        }
    }
}

/// Liest die Zeitpunkte der API: mit und ohne Sekundenbruchteile, mit `Z` oder Versatz.
enum Zeitpunkt {
    static func lies(_ iso: String) -> Date? {
        let mit = ISO8601DateFormatter()
        mit.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = mit.date(from: iso) { return d }
        let ohne = ISO8601DateFormatter()
        ohne.formatOptions = [.withInternetDateTime]
        return ohne.date(from: iso)
    }
}
