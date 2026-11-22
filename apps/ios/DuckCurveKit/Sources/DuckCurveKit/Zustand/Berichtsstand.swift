import Foundation

/// Wann eine Auswertung gerechnet wurde - und wann das dastehen muss.
///
/// **Der Anlass.** Der Dienst legt Auswertungen seit dem 22.11.2026 in einen Zwischenspeicher
/// (`dch_api/application/berichtsspeicher.py`): ein abgeschlossener Zeitraum bleibt dauerhaft
/// liegen, der laufende eine Minute. Damit ist eine Antwort nicht mehr in jedem Fall von jetzt,
/// und eine Zahl aus dem Speicher, die aussieht wie eine von jetzt, ist eine stille Lüge - an
/// einer Wandanzeige, die wochenlang auf derselben Seite steht, besonders. Der Dienst sagt
/// deshalb in jeder dieser Antworten, wann er sie gerechnet hat (`generated_at`), und hier steht
/// die Regel, wann die App es zeigt.
///
/// **Die Schwelle ist die Frist des Speichers, nicht eine runde Zahl.** Ist eine Antwort höchstens
/// ``schwelle`` alt, kann sie ohnehin nur aus dem laufenden Zeitraum stammen und ist so frisch,
/// wie der Minutentakt des Hauses es überhaupt zulässt - dann wäre die Zeile nur Beiwerk, das bei
/// jedem Nachladen aufblitzt. Ist sie älter, hat der Speicher gegriffen (oder der Zeitraum ist
/// abgeschlossen und die Zahl endgültig), und beides will man lesen können.
///
/// **Der Satz ist der der Vorlage.** Die Prognoseseite zeigt ihren Stand schon so an - „Stand
/// 14:35“ (`apps/web/src/components/forecast/ForecastPage.tsx:246`, in dieser App
/// ``PrognoseSeite``) -, und ein zweites Wort für dieselbe Sache wäre eine Fehlerquelle ohne
/// Gegenwert.
public enum Berichtsstand {
    /// Die Frist des Zwischenspeichers für den laufenden Zeitraum: `berichtsspeicher.FRIST`.
    public static let schwelle: TimeInterval = 60

    /// „Stand 14:35“ - oder nichts, wenn die Antwort frisch ist.
    ///
    /// Nichts kommt auch bei fehlendem oder unlesbarem Zeitstempel und bei einem, der in der
    /// Zukunft liegt: die Uhr des Geräts und die des Hauses gehen nicht gleich, und ein
    /// „Stand“ hinter der eigenen Uhr wäre keine Auskunft, sondern eine Verwirrung.
    public static func satz(gerechnetAm iso: String?, jetzt: Date) -> String? {
        guard let iso, let gerechnet = Zeit.ausIso(iso) else { return nil }
        let alter = jetzt.timeIntervalSince(gerechnet)
        guard alter > schwelle else { return nil }
        return "Stand \(Formate.hhmm(gerechnet))"
    }
}
