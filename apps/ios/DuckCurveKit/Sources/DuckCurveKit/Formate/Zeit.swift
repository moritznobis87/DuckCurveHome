import Foundation

/// ISO-Zeitstempel lesen und schreiben - von Hand, ohne Formatierer.
///
/// **Warum von Hand.** Der Dienst liefert vier Formen, und `Date.ISO8601FormatStyle` liest nur
/// zwei davon. Nachgemessen auf dieser Toolchain (Swift 6.1.2, Linux):
///
/// | Form                          | `ISO8601FormatStyle` |
/// |-------------------------------|----------------------|
/// | `2026-09-04T11:42:00Z`        | liest               |
/// | `2026-09-04T13:42:00+02:00`   | liest               |
/// | `2026-09-04T13:42:00`         | **scheitert**       |
/// | `2026-09-04T13:42`            | **scheitert**       |
///
/// Die beiden unteren Formen kommen aus der Datenbank und aus `haus.yaml`. Ein `nil` an dieser
/// Stelle laesst in der Anzeige keinen Wert fehlen, sondern einen ganzen Tag leer bleiben - die
/// Zeile ohne Zeitstempel faellt aus dem Raster, und mit ihr das Diagramm.
///
/// Dazu kommt die Menge: eine Tageshistorie sind 1440 Zeilen, und beim Blaettern durch eine Woche
/// zehntausend. Ein Formatierer je Zeile ist dafuer zu langsam, ein geteilter Formatierer unter
/// Swift 6 nicht nebenlaeufigkeitssicher. Dieser Leser ist beides nicht: er rechnet auf Ziffern
/// und ist ein Wertetyp.
public enum Zeit {
    /// Ein ISO-Zeitstempel in allen Formen, die der Dienst liefert.
    ///
    /// Ohne Zeitzonenangabe im Text gilt die Zeit des Hauses - so meint es der Dienst, wenn er
    /// einen Wert aus der Datenbank ohne Versatz schreibt.
    public static func ausIso(_ s: String) -> Date? {
        let z = Array(s.utf8)
        // Mindestens `YYYY-MM-DDTHH:MM` = 16 Zeichen.
        guard z.count >= 16 else { return nil }

        func ziffern(_ von: Int, _ anzahl: Int) -> Int? {
            guard von + anzahl <= z.count else { return nil }
            var wert = 0
            for i in von..<(von + anzahl) {
                let c = z[i]
                guard c >= 48, c <= 57 else { return nil }
                wert = wert * 10 + Int(c - 48)
            }
            return wert
        }

        guard let jahr = ziffern(0, 4), z[4] == UInt8(ascii: "-"),
              let monat = ziffern(5, 2), z[7] == UInt8(ascii: "-"),
              let tag = ziffern(8, 2),
              z[10] == UInt8(ascii: "T") || z[10] == UInt8(ascii: " "),
              let stunde = ziffern(11, 2), z[13] == UInt8(ascii: ":"),
              let minute = ziffern(14, 2)
        else { return nil }

        var i = 16
        var sekunde = 0
        if i < z.count, z[i] == UInt8(ascii: ":") {
            guard let s2 = ziffern(i + 1, 2) else { return nil }
            sekunde = s2
            i += 3
        }
        // Bruchteile werden gelesen und verworfen: das Minutenraster der Anzeige braucht sie nicht.
        if i < z.count, z[i] == UInt8(ascii: ".") {
            i += 1
            while i < z.count, z[i] >= 48, z[i] <= 57 { i += 1 }
        }

        // Zeitzone: `Z`, `+HH:MM`, `+HHMM`, `+HH` - oder nichts.
        var versatz: Int?
        if i < z.count {
            let c = z[i]
            if c == UInt8(ascii: "Z") || c == UInt8(ascii: "z") {
                versatz = 0
                i += 1
            } else if c == UInt8(ascii: "+") || c == UInt8(ascii: "-") {
                let vorzeichen = c == UInt8(ascii: "-") ? -1 : 1
                guard let vh = ziffern(i + 1, 2) else { return nil }
                var vm = 0
                var j = i + 3
                if j < z.count, z[j] == UInt8(ascii: ":") {
                    guard let m2 = ziffern(j + 1, 2) else { return nil }
                    vm = m2
                    j += 3
                } else if let m2 = ziffern(j, 2) {
                    vm = m2
                    j += 2
                }
                versatz = vorzeichen * (vh * 3600 + vm * 60)
                i = j
            }
        }
        // Was danach noch kommt, ist kein Zeitstempel mehr.
        guard i >= z.count else { return nil }

        var teile = DateComponents()
        teile.year = jahr
        teile.month = monat
        teile.day = tag
        teile.hour = stunde
        teile.minute = minute
        teile.second = sekunde

        if let versatz {
            var kal = Calendar(identifier: .gregorian)
            kal.timeZone = TimeZone(secondsFromGMT: versatz) ?? .gmt
            teile.timeZone = kal.timeZone
            return kal.date(from: teile)
        }
        // Ohne Angabe: die Zeit des Hauses.
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = Formate.zeitzone
        teile.timeZone = Formate.zeitzone
        return kal.date(from: teile)
    }

    /// Ein Zeitpunkt als `2026-09-04T11:42:00Z` - die Form, in der der Dienst ihn erwartet.
    public static func iso(_ d: Date) -> String {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = .gmt
        let t = kal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02dZ",
            t.year ?? 0, t.month ?? 0, t.day ?? 0, t.hour ?? 0, t.minute ?? 0, t.second ?? 0
        )
    }
}

/// Die deutschen Namen der Wochentage und Monate.
///
/// **Warum eine Tabelle und nicht `DateFormatter`.** Dieses Paket wird unter Linux getestet und
/// laeuft unter iOS, und die beiden bringen verschiedene ICU-Staende mit. Unter Linux liefert
/// `weekday(.abbreviated)` fuer de-DE heute „Fr.“, in manchen Staenden „Fr“ - ein Punkt, der in
/// einer Blaetterleiste auffaellt und dessen Test dann nur auf einem der beiden Systeme gilt.
/// Deutsch ist die einzige Sprache dieser App; zwanzig Woerter aufzuschreiben ist billiger als
/// eine Abhaengigkeit, die sich unter den Fuessen bewegt.
public enum Namen {
    public static let wochentage = ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
    public static let wochentageKurz = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
    public static let monate = [
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember",
    ]
    public static let monateKurz = [
        "Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez.",
    ]

    /// `Calendar.weekday` zaehlt von 1 (Sonntag) bis 7 (Samstag).
    public static func wochentag(_ nummer: Int, kurz: Bool = false) -> String {
        let i = max(1, min(7, nummer)) - 1
        return kurz ? wochentageKurz[i] : wochentage[i]
    }

    public static func monat(_ nummer: Int, kurz: Bool = false) -> String {
        let i = max(1, min(12, nummer)) - 1
        return kurz ? monateKurz[i] : monate[i]
    }
}
