import Foundation

/// Was die Guete eines Messwerts fuer die Anzeige bedeutet.
///
/// Jeder Wert aus dem Dienst traegt eine Guete - `ok`, `stale`, `unavailable`, `unknown`,
/// `derived`, `inconsistent` - und `ARCHITECTURE.md` nennt sie neben Zeitpunkt und Quelle als
/// Teil jedes Messwerts. Was daraus folgt, steht hier und nicht in der Ansicht: ob eine Zahl
/// dasteht oder ein Bindestrich, ist eine Entscheidung und keine Formatierung.
extension Quality {
    /// Traegt der Wert eine Zahl?
    ///
    /// `derived` zaehlt mit: ein aus der Bilanz gerechneter Wert ist kein schlechterer Wert,
    /// sondern ein anderer Weg zur selben Zahl. `stale` zaehlt nicht mit - er war einmal
    /// richtig, und das ist etwas anderes als „er ist richtig".
    public var traegt: Bool {
        self == .ok || self == .derived
    }

    /// Das Wort, das neben dem Wert stehen kann - oder `nil`, wenn nichts zu sagen ist.
    public var wort: String? {
        switch self {
        case .ok, .derived: return nil
        case .stale: return "alt"
        case .unavailable: return "fehlt"
        case .unknown: return "unbekannt"
        case .inconsistent: return "widersprüchlich"
        case .unbekannt: return nil
        }
    }

    /// Wie schlimm es ist. Die Anzeige macht daraus eine Farbe.
    public var stufe: Stufe {
        switch self {
        case .ok, .derived: return .gut
        case .stale: return .alt
        case .unavailable, .unknown, .unbekannt: return .fehlt
        case .inconsistent: return .falsch
        }
    }

    public enum Stufe: Sendable, Hashable {
        case gut, alt, fehlt, falsch
    }
}

extension Messwert {
    /// Der Wert, wenn er traegt - sonst `nil`.
    ///
    /// Das ist die Stelle, an der entschieden wird, ob eine Zahl dasteht oder ein Bindestrich.
    public var belastbar: Double? {
        quality.traegt ? value : nil
    }

    public var zeitpunkt: Date? {
        Zeit.ausIso(observedAt)
    }

    /// Wie alt der Wert ist, in Worten - oder `nil`, solange er frisch ist.
    public func alter(jetzt: Date) -> String? {
        guard let z = zeitpunkt else { return nil }
        return Formate.alter(beobachtetAm: z, jetzt: jetzt)
    }

    /// Die Zeile, die unter einem Wert stehen kann: „alt · vor 4 min".
    public func hinweis(jetzt: Date) -> String? {
        var teile: [String] = []
        if let w = quality.wort { teile.append(w) }
        if !quality.traegt, let a = alter(jetzt: jetzt) { teile.append(a) }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }
}
