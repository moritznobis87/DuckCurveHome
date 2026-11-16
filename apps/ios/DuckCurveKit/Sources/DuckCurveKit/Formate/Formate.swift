import Foundation

/// Zahlen- und Zeitformate der Anzeige (de-DE, schmales Leerzeichen vor der Einheit).
///
/// Die Vorlage ist `apps/web/src/lib/format/index.ts`, und die Tests dieses Pakets pruefen
/// dieselben Faelle wie `format.test.ts` dort. Was das Dashboard an der Wand zeigt und was die
/// App zeigt, soll Zeichen fuer Zeichen dasselbe sein.
///
/// **Warum hier von Hand gerechnet wird und nicht mit `NumberFormatter`.**
///
/// `Intl.NumberFormat` im Browser, `NumberFormatter` unter iOS und derselbe Typ unter Linux
/// greifen auf drei verschiedene ICU-Staende zu. Bei `de-DE` und einer Nachkommastelle ist das
/// heute einerlei, aber es ist nicht zugesichert, und genau die Stellen, an denen es auffaellt,
/// sind die, die man an einer Wandanzeige nicht nachrechnet. Vor allem aber: dieses Paket wird
/// unter Linux getestet und laeuft unter iOS. Ein Test, der nur auf dem Pruefrechner gilt, ist
/// keiner. Die Regeln sind klein genug, um sie auszuschreiben:
///
/// - Komma als Dezimaltrennzeichen, kein Tausenderpunkt (die Anzeige zeigt keine vierstelligen kW),
/// - U+2212 MINUS SIGN statt des Bindestrichs, weil der in IBM Plex Sans zu kurz fuer eine Zahl ist,
/// - U+202F NARROW NO-BREAK SPACE vor der Einheit, damit „3,6 kW“ nicht umbricht.
public enum Formate {
    /// U+202F, das schmale geschuetzte Leerzeichen vor der Einheit.
    public static let schmalesLeerzeichen = "\u{202F}"
    /// U+2212, das echte Minuszeichen.
    public static let minus = "\u{2212}"
    /// Was dasteht, wenn kein Wert da ist. Ein Bindestrich, nicht „0“ - das ist ein Unterschied.
    public static let leer = "-"

    // MARK: - Zahlen

    /// Eine Zahl mit fester Zahl von Nachkommastellen, deutsch geschrieben.
    ///
    /// Rundet kaufmaennisch (wie `Intl.NumberFormat`), setzt das Komma und das echte Minuszeichen.
    /// Eine Zahl, die zu `-0,0` gerundet wuerde, wird `0,0`: ein Vorzeichen an einer Null ist eine
    /// Aussage, die die Messung nicht hergibt.
    ///
    /// **Nimmt `Double?`, und das war erst anders.** Diese Funktion war die einzige der vierzehn
    /// hier, die ein nicht-wahlfreies `Double` verlangte - und genau deshalb hat sie beim ersten
    /// Uebersetzungslauf der Oberflaeche vierzehn Fehler erzeugt. Fast jede Zahl, die aus dem
    /// Dienst kommt, ist wahlfrei: ein Zaehler, der schweigt, liefert `null`, und das ist kein
    /// Sonderfall, sondern der Alltag. Eine Schnittstelle, in der dreizehn Funktionen das
    /// aushalten und eine nicht, ist eine Falle - und sie hat zugeschnappt. Fehlt der Wert,
    /// steht hier derselbe Strich wie bei den Geschwistern.
    public static func zahl(_ wert: Double?, stellen: Int) -> String {
        guard let wert, wert.isFinite else { return leer }
        let faktor = pow(10.0, Double(stellen))
        let gerundet = (wert * faktor).rounded() / faktor
        let negativ = gerundet < 0
        let betrag = abs(gerundet)
        var text = String(format: "%.\(stellen)f", betrag)
        text = text.replacingOccurrences(of: ".", with: ",")
        // `-0,0` entsteht aus jeder kleinen negativen Zahl. Das Vorzeichen faellt weg.
        let istNull = text.allSatisfy { $0 == "0" || $0 == "," }
        return (negativ && !istNull) ? minus + text : text
    }

    /// Leistung in kW, ohne Einheit. Was dem Betrag nach unter 0,05 liegt, ist eine Null.
    ///
    /// Der Schwellwert ist kein Schoenheitsmittel: ein Wechselrichter, der nachts 0,004 kW
    /// meldet, und ein Zaehler, der −0,01 kW meldet, sollen beide „0,0“ zeigen und nicht
    /// „0,0“ gegen „−0,0“ - sonst sieht die Wand eine Einspeisung, die es nicht gibt.
    public static func kw(_ wert: Double?, stellen: Int = 1) -> String {
        guard let wert, wert.isFinite else { return leer }
        let abgeschnitten = abs(wert) < 0.05 ? 0 : wert
        return zahl(abgeschnitten, stellen: stellen)
    }

    /// Leistung in kW mit Einheit: „3,6 kW“.
    public static func kwMitEinheit(_ wert: Double?) -> String {
        let v = kw(wert)
        return v == leer ? v : v + schmalesLeerzeichen + "kW"
    }

    /// Energie in kWh mit Einheit.
    public static func kwh(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: 1) + schmalesLeerzeichen + "kWh"
    }

    /// Ein Anteil (0 bis 1) als Prozent, ganzzahlig.
    public static func prozent(_ anteil: Double?) -> String {
        guard let anteil, anteil.isFinite else { return leer }
        return zahl((anteil * 100).rounded(), stellen: 0) + schmalesLeerzeichen + "%"
    }

    /// Temperatur in Grad Celsius.
    public static func celsius(_ wert: Double?, stellen: Int = 0) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: stellen) + schmalesLeerzeichen + "°C"
    }

    /// Strompreis in ct/kWh. Negative Preise kommen vor und sind der Grund fuer das halbe Projekt.
    public static func ct(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: 1) + schmalesLeerzeichen + "ct/kWh"
    }

    /// Geld in Euro.
    public static func euro(_ wert: Double?, stellen: Int = 2) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: stellen) + schmalesLeerzeichen + "€"
    }

    /// Eine Dauer in Minuten als „45 min“ oder „3 h 20 min“.
    public static func dauer(minuten: Int?) -> String {
        guard let minuten, minuten >= 0 else { return leer }
        if minuten < 60 { return "\(minuten)\(schmalesLeerzeichen)min" }
        let h = minuten / 60
        let m = minuten % 60
        return m == 0 ? "\(h)\(schmalesLeerzeichen)h" : "\(h)\(schmalesLeerzeichen)h \(m)\(schmalesLeerzeichen)min"
    }

    // MARK: - Zeit

    /// Die Zeitzone des Hauses. Nicht die des Geraets: wer aus dem Urlaub nachsieht, will wissen,
    /// wann die Waermepumpe *dort* gelaufen ist.
    public static let zeitzone = TimeZone(identifier: "Europe/Berlin") ?? TimeZone(secondsFromGMT: 3600)!

    /// „13:42“ in der Zeit des Hauses.
    ///
    /// Gerechnet, nicht formatiert: ein `DateFormatter` ist unter Swift 6 nicht
    /// nebenlaeufigkeitssicher zu teilen und zu langsam, um ihn je Zeile neu zu bauen. Eine
    /// Protokollseite zeigt dreihundert Uhrzeiten.
    public static func hhmm(_ zeitpunkt: Date?) -> String {
        guard let zeitpunkt else { return leer }
        let t = Kalender.haus.dateComponents([.hour, .minute], from: zeitpunkt)
        return String(format: "%02d:%02d", t.hour ?? 0, t.minute ?? 0)
    }

    /// Dasselbe aus einem ISO-Zeitstempel, wie der Dienst ihn liefert.
    public static func hhmm(iso: String?) -> String {
        guard let iso, let d = Zeit.ausIso(iso) else { return leer }
        return hhmm(d)
    }

    /// „13:42:07“ - nur im Protokoll, wo die Sekunde etwas aussagt.
    public static func hhmmss(_ zeitpunkt: Date?) -> String {
        guard let zeitpunkt else { return leer }
        let t = Kalender.haus.dateComponents([.hour, .minute, .second], from: zeitpunkt)
        return String(format: "%02d:%02d:%02d", t.hour ?? 0, t.minute ?? 0, t.second ?? 0)
    }

    /// „Samstag, 7. November“ - die Ueberschrift des Tagesdiagramms.
    public static func langesDatum(_ zeitpunkt: Date) -> String {
        let t = Kalender.haus.dateComponents([.weekday, .day, .month], from: zeitpunkt)
        let tag = Namen.wochentag(t.weekday ?? 1)
        return "\(tag), \(t.day ?? 0). \(Namen.monat(t.month ?? 1))"
    }

    /// Wie alt ein Messwert ist - oder `nil`, wenn er frisch genug ist, um es nicht zu erwaehnen.
    ///
    /// Unter 30 Sekunden steht nichts da. Das ist Absicht: ein Alter an jedem Wert macht die
    /// Anzeige unruhig, und solange die Werte kommen, ist das Alter keine Nachricht.
    public static func alter(beobachtetAm: Date, jetzt: Date) -> String? {
        let s = max(0, jetzt.timeIntervalSince(beobachtetAm))
        if s < 30 { return nil }
        if s < 90 { return "vor \(Int(s.rounded())) s" }
        if s < 3600 { return "vor \(Int((s / 60).rounded())) min" }
        return "vor \(Int((s / 3600).rounded())) h"
    }

    /// Minuten bis zu einem Zeitpunkt, nie negativ.
    public static func minutenBis(_ zeitpunkt: Date?, jetzt: Date) -> Int? {
        guard let zeitpunkt else { return nil }
        return max(0, Int((zeitpunkt.timeIntervalSince(jetzt) / 60).rounded()))
    }
}

/// Der Kalender des Hauses: gregorianisch, Woche beginnt am Montag, Zeitzone Europe/Berlin.
public enum Kalender {
    public static let haus: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = Formate.zeitzone
        c.firstWeekday = 2
        return c
    }()
}
