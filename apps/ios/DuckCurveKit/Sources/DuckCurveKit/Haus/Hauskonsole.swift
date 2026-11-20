import Foundation

/// Die Leiste neben dem Hausmodell: fünf Blöcke, jeder eine Zahl und ein Satz.
///
/// **Warum neben dem Modell und nicht darin.** Das Modell zeigt, wo etwas ist; die Leiste sagt,
/// wie viel davon. „2 offen" steht als Zahl da und muss nicht aus zwölf Kontaktstrichen gezählt
/// werden - und wer wissen will, welche zwei, tippt darauf.
///
/// Dieselben Sätze wie `apps/web/src/components/house/Konsole.tsx` und `house/live.ts`.
public enum Hauskonsole {
    /// Welcher Kontakt offen ist, als Satz: „Gartentür 1 und 1 weitere".
    ///
    /// **Ein Name und eine Zahl, nicht alle Namen.** Zwölf Kontakte ergäben eine Zeile, die
    /// niemand liest; der erste Name sagt, wo man anfangen muss.
    public static func offenSatz(_ offen: [String], von gesamt: Int) -> String {
        if gesamt == 0 { return "keine Kontakte im Plan" }
        guard let erster = offen.first else { return "alles zu" }
        if offen.count == 1 { return erster }
        return "\(erster) und \(offen.count - 1) weitere"
    }

    /// Was unter der Wärmepumpe steht: „läuft seit 14:20" oder „steht seit 40 min".
    public static func pumpensatz(
        laeuft: Bool?, seit: String?, jetzt: Date
    ) -> String {
        let wort = laeuft == true ? "läuft" : "steht"
        guard let seit, let d = Zeit.ausIso(seit) else { return wort }
        let min = Int(jetzt.timeIntervalSince(d) / 60)
        guard min >= 1 else { return wort }
        if min < 60 { return "\(wort) seit \(min) min" }
        let h = min / 60
        let rest = min % 60
        return rest > 0 ? "\(wort) seit \(h) h \(rest) min" : "\(wort) seit \(h) h"
    }

    /// Die vier Schichten des Puffers als Zeile: „48 · 41 · 39 · 37".
    public static func schichtsatz(_ temperaturen: [Double?]) -> String {
        let da = temperaturen.compactMap { $0 }.map { Formate.zahl($0, stellen: 0) }
        return da.isEmpty ? "keine Werte" : da.joined(separator: " · ")
    }

    /// Wie viele Heizkreise offen sind - gezählt über die Räume, nicht über die Kreise.
    ///
    /// **Ein Raum zählt einmal.** Ein Raum mit vier Kreisen, von denen einer offen ist, ist ein
    /// Raum, in dem geheizt wird; vier zu zählen hieße, die Zahl von der Verrohrung abhängig zu
    /// machen statt vom Haus.
    public static func offeneKreise(_ raeume: [RoomLiveOut]) -> Int {
        raeume.filter { ($0.valve ?? 0) > 0 }.count
    }
}
