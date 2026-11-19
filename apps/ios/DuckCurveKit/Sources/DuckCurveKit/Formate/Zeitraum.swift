import Foundation

/// Der Zeitraum, den ein Bereich zeigt: Tag, Woche, Monat oder Jahr.
///
/// **Warum alle Reiter eines Bereichs sich einen teilen.** `areas.ts` nennt den Grund: dreizehn
/// Seiten waren nacheinander entstanden, jede mit eigener Zeitraumwahl, und wer die Woche in der
/// Photovoltaik ansah und dann zum Speicher ging, stand dort wieder auf heute. Im Dashboard reist
/// der Zeitraum als `?period=&anchor=` mit; in der App liegt er im Zustand des Bereichs.
public enum Spanne: String, Sendable, Hashable, CaseIterable, Codable {
    case tag = "day"
    case woche = "week"
    case monat = "month"
    case jahr = "year"

    public var name: String {
        switch self {
        case .tag: return "Tag"
        case .woche: return "Woche"
        case .monat: return "Monat"
        case .jahr: return "Jahr"
        }
    }
}

/// Ein Zeitraum: eine Spanne und der Tag, an dem sie haengt.
public struct Zeitraum: Sendable, Hashable, Codable {
    public var spanne: Spanne
    /// Der Anker als ISO-Datum. Ein Tag *in* dem Zeitraum, nicht unbedingt sein Anfang.
    public var anker: String

    public init(spanne: Spanne = .tag, anker: String) {
        self.spanne = spanne
        self.anker = anker
    }

    public static func heute(_ spanne: Spanne = .tag, jetzt: Date = Date()) -> Zeitraum {
        Zeitraum(spanne: spanne, anker: Tag.iso(jetzt))
    }

    /// Einen Schritt vor oder zurueck.
    public func verschoben(_ richtung: Int) -> Zeitraum {
        guard let d = Tag.date(anker) else { return self }
        let feld: Calendar.Component =
            switch spanne {
            case .tag: .day
            case .woche: .weekOfYear
            case .monat: .month
            case .jahr: .year
            }
        guard let neu = Kalender.haus.date(byAdding: feld, value: richtung, to: d) else { return self }
        return Zeitraum(spanne: spanne, anker: Tag.iso(neu))
    }

    /// Dieselbe Stelle, in einer anderen Spanne.
    public func mit(_ neue: Spanne) -> Zeitraum {
        Zeitraum(spanne: neue, anker: anker)
    }

    /// Liegt heute in diesem Zeitraum? Dann gibt es kein „vorwaerts".
    public func istAktuell(jetzt: Date = Date()) -> Bool {
        guard let d = Tag.date(anker) else { return false }
        let feld: Set<Calendar.Component> =
            switch spanne {
            case .tag: [.year, .month, .day]
            case .woche: [.yearForWeekOfYear, .weekOfYear]
            case .monat: [.year, .month]
            case .jahr: [.year]
            }
        let a = Kalender.haus.dateComponents(feld, from: d)
        let b = Kalender.haus.dateComponents(feld, from: jetzt)
        return a == b
    }

    /// Die Kalenderwoche nach ISO 8601.
    ///
    /// **Warum das eine eigene Zeile wert ist.** Die ISO-Woche ist nicht „der wievielte
    /// Siebentageblock des Jahres". Sie beginnt am Montag, und die erste Woche ist die, in der
    /// der erste Donnerstag liegt. Daraus folgt, was jeden selbstgeschriebenen Zaehler zerlegt:
    /// der 1. Januar kann in der Woche 52 oder 53 des *vorigen* Jahres liegen, und der 31.
    /// Dezember in der Woche 1 des *naechsten*. `Calendar` mit `.iso8601` rechnet das richtig;
    /// der Hauskalender mit `firstWeekday = 2` allein tut es nicht, weil ihm die
    /// Donnerstagsregel fehlt (`minimumDaysInFirstWeek`).
    public var kalenderwoche: Int? {
        guard let d = Tag.date(anker) else { return nil }
        return Zeitraum.isoKalender.component(.weekOfYear, from: d)
    }

    /// Das Jahr, zu dem die Kalenderwoche gehoert - nicht immer das Jahr des Datums.
    public var kalenderwochenjahr: Int? {
        guard let d = Tag.date(anker) else { return nil }
        return Zeitraum.isoKalender.component(.yearForWeekOfYear, from: d)
    }

    /// Der Kalender, der die ISO-Woche richtig rechnet: Montag als erster Tag, und die erste
    /// Woche braucht vier Tage im neuen Jahr (das ist die Donnerstagsregel).
    static let isoKalender: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = Formate.zeitzone
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }()

    /// Anfang und Ende des Zeitraums, als Zeitpunkte.
    public var grenzen: (von: Date, bis: Date)? {
        guard let d = Tag.date(anker) else { return nil }
        let kal = spanne == .woche ? Zeitraum.isoKalender : Kalender.haus
        let feld: Calendar.Component =
            switch spanne {
            case .tag: .day
            case .woche: .weekOfYear
            case .monat: .month
            case .jahr: .year
            }
        guard let spanneDesTags = kal.dateInterval(of: feld, for: d) else { return nil }
        return (spanneDesTags.start, spanneDesTags.end)
    }

    /// Die Ueberschrift: „Dienstag, 10.11.2026", „KW 46 · 09.11. - 15.11.2026", „November 2026", „2026".
    public var name: String {
        guard let d = Tag.date(anker) else { return anker }
        let t = Kalender.haus.dateComponents([.weekday, .day, .month, .year], from: d)
        switch spanne {
        case .tag:
            let wt = Namen.wochentag(t.weekday ?? 1)
            return String(format: "%@, %02d.%02d.%04d", wt, t.day ?? 0, t.month ?? 0, t.year ?? 0)
        case .woche:
            guard let g = grenzen, let kw = kalenderwoche else { return anker }
            let von = Kalender.haus.dateComponents([.day, .month], from: g.von)
            // Das Ende ist der Anfang des naechsten Zeitraums; der letzte Tag ist eine Sekunde davor.
            let letzter = g.bis.addingTimeInterval(-1)
            let bis = Kalender.haus.dateComponents([.day, .month, .year], from: letzter)
            return String(
                format: "KW %d · %02d.%02d. - %02d.%02d.%04d",
                kw, von.day ?? 0, von.month ?? 0, bis.day ?? 0, bis.month ?? 0, bis.year ?? 0
            )
        case .monat:
            return "\(Namen.monat(t.month ?? 1)) \(t.year ?? 0)"
        case .jahr:
            return String(t.year ?? 0)
        }
    }

    /// Dasselbe kurz, fuer die Zeitraumzeile am Handy: „Di, 10.11.", „KW 46", „Nov. 2026", „2026".
    public var kurz: String {
        guard let d = Tag.date(anker) else { return anker }
        let t = Kalender.haus.dateComponents([.weekday, .day, .month, .year], from: d)
        switch spanne {
        case .tag:
            return String(
                format: "%@, %02d.%02d.", Namen.wochentag(t.weekday ?? 1, kurz: true),
                t.day ?? 0, t.month ?? 0
            )
        case .woche:
            return kalenderwoche.map { "KW \($0)" } ?? anker
        case .monat:
            return "\(Namen.monat(t.month ?? 1, kurz: true)) \(t.year ?? 0)"
        case .jahr:
            return String(t.year ?? 0)
        }
    }
}
