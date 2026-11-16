import Foundation

/// Der Kalendertag als ISO-Datum, an einer Stelle.
///
/// Vorlage: `apps/web/src/lib/day.ts`. Dort steht im Kommentar, was passiert, wenn an dieser
/// Stelle geschludert wird: die Startseite zeigte „Invalid Date“, beide Diagramme blieben leer,
/// und der Zustandsspeicher hing keine Live-Werte mehr an. Deshalb liegt hier, und nur hier, die
/// Entscheidung, was ein Tag ist.
public enum Tag {
    /// Heute in der Zeit des Hauses, unabhaengig davon, wo das Geraet steht.
    public static func heute(jetzt: Date = Date()) -> String {
        iso(jetzt)
    }

    /// Ein Zeitpunkt als Kalendertag der Hauszeit: `2026-11-16`.
    public static func iso(_ d: Date) -> String {
        let t = Kalender.haus.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", t.year ?? 0, t.month ?? 0, t.day ?? 0)
    }

    /// Ist das ein Kalendertag, mit dem die Oberflaeche rechnen kann?
    ///
    /// Die Form allein genuegt nicht: `2026-13-45` besteht jede Pruefung mit regulaerem Ausdruck
    /// und ist doch kein Tag, und `2026-02-30` auch nicht. Darum wird zurueckgerechnet - was sich
    /// nicht wieder zu sich selbst formatieren laesst, ist keiner.
    public static func istTag(_ s: String?) -> Bool {
        guard let s, s.count == 10 else { return false }
        let stuecke = s.split(separator: "-", omittingEmptySubsequences: false)
        guard stuecke.count == 3,
              stuecke[0].count == 4, stuecke[1].count == 2, stuecke[2].count == 2,
              let j = Int(stuecke[0]), let m = Int(stuecke[1]), let t = Int(stuecke[2]),
              stuecke.allSatisfy({ $0.allSatisfy(\.isNumber) })
        else { return false }
        var c = DateComponents()
        c.year = j
        c.month = m
        c.day = t
        c.hour = 12
        // Die Rueckrechnung prueft genau das, was zaehlt. `Calendar` normalisiert, was es nicht
        // gibt: aus dem 30. Februar wird der 2. Maerz, und der schreibt sich nicht wieder zu
        // „2026-02-30“. Den 29. Februar im Nichtschaltjahr faengt dieselbe Zeile.
        guard let d = Kalender.haus.date(from: c) else { return false }
        return iso(d) == s
    }

    /// Ein Kalendertag plus oder minus einige Tage.
    ///
    /// Mittags gerechnet, damit die Sommerzeit den Tag nicht kippt: am 25. Oktober um 00:00 plus
    /// 24 Stunden ist es noch derselbe Tag.
    public static func plus(_ tag: String, _ tage: Int) -> String {
        guard let d = date(tag) else { return tag }
        guard let neu = Kalender.haus.date(byAdding: .day, value: tage, to: d) else { return tag }
        return iso(neu)
    }

    /// Der Tag als Zeitpunkt, mittags in der Hauszeit.
    public static func date(_ tag: String) -> Date? {
        guard istTag(tag) else { return nil }
        let s = tag.split(separator: "-").compactMap { Int($0) }
        guard s.count == 3 else { return nil }
        var c = DateComponents()
        c.year = s[0]
        c.month = s[1]
        c.day = s[2]
        c.hour = 12
        return Kalender.haus.date(from: c)
    }

    /// Anfang und Ende eines Tages in der Hauszeit - der Zeitraum, mit dem die Historie abgefragt wird.
    public static func zeitraum(_ tag: String) -> (von: Date, bis: Date)? {
        guard let mittag = date(tag) else { return nil }
        let von = Kalender.haus.startOfDay(for: mittag)
        guard let bis = Kalender.haus.date(byAdding: .day, value: 1, to: von) else { return nil }
        return (von, bis)
    }

    /// „Samstag, 7. November 2026“ fuer einen Kalendertag.
    public static func lang(_ tag: String) -> String {
        guard let d = date(tag) else { return tag }
        let t = Kalender.haus.dateComponents([.weekday, .day, .month, .year], from: d)
        return "\(Namen.wochentag(t.weekday ?? 1)), \(t.day ?? 0). \(Namen.monat(t.month ?? 1)) \(t.year ?? 0)"
    }

    /// „Sa, 7.11.“ - die kurze Form fuer Reiter und Blaetterleisten.
    public static func kurz(_ tag: String) -> String {
        guard let d = date(tag) else { return tag }
        let t = Kalender.haus.dateComponents([.weekday, .day, .month], from: d)
        return "\(Namen.wochentag(t.weekday ?? 1, kurz: true)), \(t.day ?? 0).\(t.month ?? 0)."
    }

    /// Ist das heute, gestern oder morgen? Fuer die Ueberschrift, die dann ein Wort statt eines
    /// Datums zeigt.
    public static func nameRelativ(_ tag: String, jetzt: Date = Date()) -> String? {
        let heute = iso(jetzt)
        if tag == heute { return "Heute" }
        if tag == plus(heute, -1) { return "Gestern" }
        if tag == plus(heute, 1) { return "Morgen" }
        return nil
    }
}
