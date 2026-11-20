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

    // MARK: - Updates

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
