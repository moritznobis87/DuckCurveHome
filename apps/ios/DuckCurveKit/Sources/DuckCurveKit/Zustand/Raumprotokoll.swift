import Foundation

/// Das Protokoll eines Raums: was in den letzten Stunden mit seinem Sollwert geschah.
///
/// **Die erste Frage ist, ob überhaupt etwas geschah.** Wenn sich der Sollwert nicht geändert
/// hat, liegt die Ursache einer Abweichung nicht an der Regelung, und man muss woanders suchen –
/// an der Vorlauftemperatur, am Fenster, am Fühler. Darum steht über dem Protokoll ein Satz und
/// nicht eine Tabelle.
///
/// Dieselben Regeln wie `apps/web/src/components/rooms/protokoll.ts`.
public enum Raumprotokoll {

    /// Woher eine Änderung kam, als Wort.
    ///
    /// **„Von außen" heißt nicht „unbefugt"**, sondern nur: nicht über dieses Werkzeug. Meistens
    /// war es ein Mensch an Contromes eigener Oberfläche oder an einem Thermostat.
    public static func quelleWort(_ q: RoomLogEntryOutQuelleWahl) -> String {
        switch q {
        case .app: return "hier gestellt"
        case .automatik: return "Automatik"
        case .extern: return "von außen"
        case .unbekannt: return "unbekannt"
        }
    }

    /// Was in einer Zeile steht, wenn kein Begründungstext dabei ist.
    public static func artText(_ a: RoomLogEntryOutArtWahl) -> String {
        switch a {
        case .befehl: return "Befehl geschickt, aber nie gemeldet"
        case .ruhe: return "Die Automatik lässt den Raum in Ruhe"
        case .einstellung: return "Die Automatik wurde geschaltet"
        case .sollwert: return "Sollwert geändert"
        case .unbekannt: return "Sollwert geändert"
        }
    }

    /// `21,0 → 22,5 °C`, oder leer, wenn der Eintrag keine Werte trägt.
    public static func sprungText(von: Double?, nach: Double?) -> String {
        guard let nach else { return "" }
        guard let von else { return "auf " + Formate.celsius(nach, stellen: 1) }
        return Formate.zahl(von, stellen: 1) + " → " + Formate.celsius(nach, stellen: 1)
    }

    /// Der Satz über dem Protokoll.
    public static func ueberschrift(_ eintraege: [RoomLogEntryOut], stunden: Int) -> String {
        let gestellt = eintraege.filter { $0.art == .sollwert }
        guard !gestellt.isEmpty else {
            return "In \(stunden) Stunden hat niemand den Sollwert verändert."
        }
        var teile: [String] = []
        let aussen = gestellt.filter { $0.quelle == .extern }.count
        let hier = gestellt.filter { $0.quelle == .app }.count
        let automatik = gestellt.filter { $0.quelle == .automatik }.count
        if aussen > 0 { teile.append("\(aussen)× von außen") }
        if hier > 0 { teile.append("\(hier)× hier") }
        if automatik > 0 { teile.append("\(automatik)× durch die Automatik") }
        let kopf = gestellt.count == 1 ? "Eine Änderung" : "\(gestellt.count) Änderungen"
        return "\(kopf) in \(stunden) Stunden: " + teile.joined(separator: ", ") + "."
    }

    /// Die Temperaturspanne der Kurven: so eng wie möglich, aber nie enger als `mindestK`.
    ///
    /// **Warum eine Untergrenze.** Ein Raum, der zwei Tage lang auf 0,3 K genau steht, bekäme
    /// sonst eine Kurve, die wie ein Gebirge aussieht. Zwei Kelvin Mindestspanne machen aus
    /// Rauschen wieder eine waagerechte Linie – und genau das ist die richtige Auskunft.
    ///
    /// Die Grenzen liegen auf halben Grad nach außen, damit die Achse runde Zahlen trägt.
    public static func spanne(_ reihen: [[Double?]], mindestK: Double = 2)
        -> (von: Double, bis: Double)?
    {
        let werte = reihen.flatMap { $0 }.compactMap { $0 }
        guard let kleinstes = werte.min(), let groesstes = werte.max() else { return nil }
        var von = kleinstes
        var bis = groesstes
        let fehlt = mindestK - (bis - von)
        if fehlt > 0 {
            von -= fehlt / 2
            bis += fehlt / 2
        }
        return ((von * 2).rounded(.down) / 2, (bis * 2).rounded(.up) / 2)
    }

    /// Eine Reihe in Einheitskoordinaten, in Stücken.
    ///
    /// **Lücken bleiben Lücken.** Ein fehlender Wert trennt den Pfad, statt zwei Messwerte über
    /// eine Stunde Stille hinweg zu verbinden – eine durchgezogene Linie wäre dort eine
    /// Behauptung über Zeit, in der nichts gemessen wurde.
    public static func stuecke(_ reihe: [Double?], spanne: (von: Double, bis: Double))
        -> [[Raumkarte.Punkt]]
    {
        guard spanne.bis > spanne.von, reihe.count > 1 else { return [] }
        var aus: [[Raumkarte.Punkt]] = []
        var lauf: [Raumkarte.Punkt] = []
        let letzte = Double(reihe.count - 1)
        for (i, v) in reihe.enumerated() {
            guard let v else {
                if lauf.count > 1 { aus.append(lauf) }
                lauf = []
                continue
            }
            let y = 1 - (v - spanne.von) / (spanne.bis - spanne.von)
            lauf.append(Raumkarte.Punkt(x: Double(i) / letzte, y: min(max(y, 0), 1)))
        }
        if lauf.count > 1 { aus.append(lauf) }
        return aus
    }
}
