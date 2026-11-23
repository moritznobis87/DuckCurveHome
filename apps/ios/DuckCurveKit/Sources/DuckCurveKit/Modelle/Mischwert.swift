import Foundation

/// Ein JSON-Wert, dessen Art erst zur Laufzeit feststeht.
///
/// Das Schema hat drei Stellen, an denen das vorkommt, und alle drei sind gewollt so:
///
/// - `HistoryOut.rows` - eine Zeile des Minutenrasters ist ein Woerterbuch aus Zeitstempel und
///   Zahlen, und welche Spalten darin stehen, entscheidet der Dienst nach Verfuegbarkeit.
///   Im Dashboard ist das `Record<string, number | string | null>`.
/// - `CoverageSeriesOut.hours` - Stunde und Zahl als Paar.
/// - `SystemEventOut.context` - was zu einem Ereignis zu sagen war.
///
/// Die Alternative waere, jede dieser Stellen von Hand zu einem eigenen Typ zu machen. Dann
/// braeche die App aber jedes Mal, wenn der Dienst eine Spalte hinzufuegt, und genau das passiert
/// an diesen Stellen oft.
public enum Mischwert: Codable, Sendable, Hashable {
    case zahl(Double)
    case ganz(Int)
    case text(String)
    case ja(Bool)
    case liste([Mischwert])
    case buch([String: Mischwert])
    case nichts

    // MARK: - Lesen

    /// Der Wert als Zahl, wenn er eine ist. `"3,5"` ist keine - Text bleibt Text.
    ///
    /// Ganzzahlen zaehlen mit: der Dienst liefert `hp_release_contact` als 0 oder 1, und an der
    /// Oberflaeche ist das eine Leistungskurve wie jede andere.
    public var alsZahl: Double? {
        switch self {
        case .zahl(let d): return d
        case .ganz(let i): return Double(i)
        default: return nil
        }
    }

    public var alsText: String? {
        if case .text(let s) = self { return s }
        return nil
    }

    public var alsJa: Bool? {
        if case .ja(let b) = self { return b }
        return nil
    }

    public var istNichts: Bool {
        if case .nichts = self { return true }
        return false
    }

    // MARK: - Codable

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .nichts
            return
        }
        // Ganzzahl vor Gleitkomma: sonst wird aus `3` die Zahl `3.0` und beim Zurueckschreiben
        // steht `3.0` im JSON, wo `3` stand.
        if let i = try? c.decode(Int.self) {
            self = .ganz(i)
        } else if let d = try? c.decode(Double.self) {
            self = .zahl(d)
        } else if let b = try? c.decode(Bool.self) {
            self = .ja(b)
        } else if let s = try? c.decode(String.self) {
            self = .text(s)
        } else if let l = try? c.decode([Mischwert].self) {
            self = .liste(l)
        } else if let b = try? c.decode([String: Mischwert].self) {
            self = .buch(b)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unbekannter JSON-Wert.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .zahl(let d): try c.encode(d)
        case .ganz(let i): try c.encode(i)
        case .text(let s): try c.encode(s)
        case .ja(let b): try c.encode(b)
        case .liste(let l): try c.encode(l)
        case .buch(let b): try c.encode(b)
        case .nichts: try c.encodeNil()
        }
    }
}

extension Mischwert: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral {
    public init(floatLiteral value: Double) { self = .zahl(value) }
    public init(integerLiteral value: Int) { self = .ganz(value) }
    public init(stringLiteral value: String) { self = .text(value) }
}
