import Foundation

/// Werte des Dienstes als deutsche Wörter.
///
/// **Warum das im Kern steht und nicht in der Oberfläche.** Es ist Logik mit genau einer
/// richtigen Antwort je Eingabe – also prüfbar, und zwar hier auf jedem Rechner. In einer
/// SwiftUI-Datei wäre dasselbe nur auf einem Mac übersetzbar und gar nicht getestet. Dazu
/// kommt ein zweiter Grund, der sich erst beim Bauen gezeigt hat: eine Hilfsfunktion, die als
/// `private func` in einer Ansicht liegt, ist aus der Nachbaransicht nicht erreichbar. Genau
/// daran ist `wertAlsText` gescheitert, nachdem es eine zweite Stelle brauchte.
extension ReglerEinstellungOut {
    /// Einen Wert dieser Einstellung als Text, so wie der Regler ihn meint.
    ///
    /// Drei Formen: eine Auswahl (dann steht das Wort dazu in `wahl`), eine Zahl mit Einheit,
    /// oder eine nackte Zahl. Fehlt der Wert, steht der Strich.
    public func wertAlsText(_ zahl: Double?) -> String {
        guard let zahl else { return Formate.leer }
        if let wort = wahl[String(Int(zahl))] { return wort }
        let text = Formate.zahl(zahl, stellen: stellen ?? 1)
        return einheit.map { "\(text)\(Formate.schmalesLeerzeichen)\($0)" } ?? text
    }
}

extension CyclingStatsVerdictWahl {
    /// Die Einordnung der Taktung als Wort.
    ///
    /// Wortgleich mit dem Dashboard (`reports/HeatOverview.tsx`, `TAKTUNG`) und bewusst
    /// zurückhaltend: das ist ein Hinweis und keine Diagnose. Eine Wärmepumpe, die häufig
    /// taktet, kann dafür gute Gründe haben.
    public var wort: String {
        switch self {
        case .ok: return "unauffällig"
        case .watch: return "grenzwertig"
        case .shortCycling: return "taktet häufig"
        case .unknown, .unbekannt: return "zu wenig Daten"
        }
    }
}

extension RoomShiftOutPhaseWahl {
    /// Die Phase der Raumautomatik als Wort.
    ///
    /// Die Rohwerte sind schon deutsch (`laden`, `zehren`, `aus`) – bis auf den Rückfall, den
    /// jede erzeugte Aufzählung trägt und dessen Rohwert „—unbekannt—" niemandem hilft. Darum
    /// nicht `rawValue` in der Anzeige, sondern das hier.
    public var wort: String {
        switch self {
        case .laden: return "laden"
        case .zehren: return "zehren"
        case .aus: return "aus"
        case .unbekannt: return "unbekannt"
        }
    }
}

/// Das Urteil einer geprüften Rechnung.
///
/// **Die Wörter sind die des Dashboards** (`reports/InvoiceCheck.tsx`, `TONE`), und das war
/// nicht so. Die App kannte `ok`, `warn`, `fail` und `alarm` – drei davon schickt der Dienst
/// nie – und ließ `info` und `error` durchfallen. In der Liste der Rechnungen stand dann das
/// englische Rohwort: „error", „info". Dasselbe Muster wie bei der Schwere eines Befunds:
/// die Vokabel geraten, statt sie nachzulesen.
public enum Rechnungsurteil: String, Sendable, CaseIterable {
    case ok, info, warning, error

    /// Was in der Liste steht.
    public var wort: String {
        switch self {
        case .ok: return "geprüft, alles stimmig"
        case .info: return "geprüft, mit Hinweisen"
        case .warning: return "auffällig"
        case .error: return "Rechenfehler"
        }
    }

    /// Ob es nach einem Fehler aussieht – das entscheidet über die Farbe.
    public var istBefund: Bool { self == .warning || self == .error }

    /// Aus dem Wort des Dienstes. Unbekanntes bleibt `nil`: dann steht es roh da, und das ist
    /// ehrlicher, als es in eine der vier Schubladen zu zwingen.
    public static func aus(_ roh: String) -> Rechnungsurteil? {
        Rechnungsurteil(rawValue: roh)
    }
}

/// Die Reason-Codes des Reglers in Worten.
///
/// Der Dienst schickt Kennungen (`pv_surplus`, `min_runtime_hold`), weil sie stabil sein
/// müssen. Für die Anzeige werden daraus Sätze – eine Kennung an der Wand ist keine
/// Begründung. Unbekannte Kennungen werden gezeigt, wie sie sind: besser eine Kennung als
/// nichts.
///
/// **Warum das im Kern steht.** Es war eine `enum` in einer Blattansicht, und die
/// Entscheidungstabelle des Fahrplans braucht dieselben Sätze - eine Ansicht kann aber nicht
/// aus dem Kern gelesen werden. Es ist Logik mit genau einer richtigen Antwort je Eingabe,
/// also gehört es hierher und ist hier geprüft.
public enum Grundwort {
    public static func text(_ c: ReasonCode) -> String {
        switch c {
        case .pvSurplus: return "Überschuss aus der Sonne"
        case .pvSurplusFading: return "der Überschuss geht zurück"
        case .priceNegative: return "der Strompreis ist negativ"
        case .priceCheapWindow: return "günstiges Preisfenster"
        case .plannedWindow: return "so steht es im Fahrplan"
        case .heatDemandForced: return "die Wärme wird gebraucht"
        case .hpRunningOwnControl: return "die Pumpe läuft nach eigenem Regler"
        case .minRuntimeHold: return "Mindestlaufzeit noch nicht erreicht"
        case .minOfftimePending: return "Mindestpause noch nicht vorbei"
        case .onDelayPending: return "Einschaltverzögerung läuft"
        case .offDelayPending: return "Ausschaltverzögerung läuft"
        case .bufferFull: return "der Puffer ist voll"
        case .bufferNoHeadroom: return "im Puffer ist kein Platz"
        case .maxStartsReached: return "genug Starts für heute"
        default: return c.rawValue.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// Dasselbe für eine Kennung, die noch keine Aufzählung ist.
    public static func text(kennung: String) -> String {
        ReasonCode(rawValue: kennung).map(text) ?? kennung.replacingOccurrences(of: "_", with: " ")
    }
}
