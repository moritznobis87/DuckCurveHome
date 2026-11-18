import Foundation

/// Die Abweichung eines Raums von seinem Ziel – die Größe, um die es beim Heizen geht.
///
/// **Warum nicht die Temperatur selbst.** Zehn Räume zwischen 18 und 21 °C ergeben als Kurven
/// ein flaches Band, in dem nichts zu erkennen ist; genau so sah die Seite aus. Interessant
/// ist nicht, wie warm ein Raum ist, sondern **wie weit er von seinem Ziel weg ist** – und
/// welcher Raum zuerst abfällt, denn der bestimmt die nötige Vorlauftemperatur für alle.
public enum Raumabweichung {
    /// Ab welcher Abweichung ein Raum als „unter Sollwert" gilt.
    ///
    /// Darunter ist es Messrauschen: Contromes Fühler lösen 0,1 K auf, und eine
    /// Fußbodenheizung pendelt immer etwas. Die Zahl stammt aus dem Dashboard
    /// (`rooms/palette.ts`, `BAND_K`) und ist dort begründet.
    public static let band = 0.5

    /// Was in einem Feld der Tagesmatrix steht.
    ///
    /// **Drei Fälle, nicht zwei.** Ein Feld ohne Messwert und ein Feld, das noch nicht an der
    /// Reihe war, sind beide leer – aber aus verschiedenen Gründen: der Nachmittag ist noch
    /// nicht gewesen, der stumme Fühler schon. Sie gleich zu zeichnen hieße, eine halbe Seite
    /// zu schraffieren und darin die paar Felder zu verstecken, auf die es ankommt.
    public enum Feld: Equatable, Sendable {
        case wert(Double)
        /// Gemessen werden sollte, gemeldet wurde nichts.
        case keinWert
        /// Dieses Fenster liegt noch in der Zukunft.
        case nochNicht
    }

    /// Der Zielwert eines Fensters: Sollwert plus Versatz.
    ///
    /// Dieselbe Rechnung wie auf der Dienstseite, und sie steht hier ein zweites Mal, weil die
    /// Zeitreihe die beiden Zahlen einzeln überträgt statt den fertigen Zielwert – dann ist an
    /// der Kurve noch zu sehen, woraus er entstand. **Ein fehlender Versatz ist einer von
    /// null, ein fehlender Sollwert dagegen kein Zielwert.**
    public static func ziel(soll: Double?, versatz: Double?) -> Double? {
        guard let soll else { return nil }
        return soll + (versatz ?? 0)
    }

    /// Die Abweichungen eines Raums über den Tag.
    ///
    /// `bisStelle` ist das erste Fenster, das noch nicht gewesen ist – alles ab dort gilt als
    /// `nochNicht`. Ohne Angabe wird der ganze Tag als gewesen behandelt.
    public static func felder(
        ist: [Double?], soll: [Double?], versatz: [Double?], bisStelle: Int? = nil
    ) -> [Feld] {
        let grenze = bisStelle ?? ist.count
        return (0..<ist.count).map { i in
            if i >= grenze { return .nochNicht }
            guard let t = i < ist.count ? ist[i] : nil,
                  let z = ziel(soll: i < soll.count ? soll[i] : nil,
                               versatz: i < versatz.count ? versatz[i] : nil)
            else { return .keinWert }
            return .wert(t - z)
        }
    }

    /// Das Tagesmittel der Abweichung – über die Fenster, die einen Wert haben.
    public static func mittel(_ felder: [Feld]) -> Double? {
        let werte = felder.compactMap { f -> Double? in
            if case .wert(let k) = f { return k }
            return nil
        }
        guard !werte.isEmpty else { return nil }
        return werte.reduce(0, +) / Double(werte.count)
    }

    /// Welche Stufe der fünfstufigen Skala – 0 ist am kältesten, 4 am wärmsten.
    ///
    /// **Die Grenzen sind die des Dashboards** (`rooms/palette.ts`, `STUFEN`), und das war
    /// nicht so: hier stand ±0,3 statt ±0,5 für „am Ziel" und −1,0 statt −1,5 für die kälteste
    /// Stufe. Mit den engeren Grenzen ist das gewöhnliche Pendeln einer Fußbodenheizung schon
    /// eine Abweichung, und das ganze Haus steht dauerhaft eingefärbt da.
    public static func stufe(_ kelvin: Double) -> Int {
        if kelvin < -1.5 { return 0 }
        if kelvin < -band { return 1 }
        if kelvin < band { return 2 }
        if kelvin < 1.5 { return 3 }
        return 4
    }

    /// Wie viele Fenster eines Tages schon gewesen sind.
    ///
    /// Für einen vergangenen Tag sind es alle, für einen künftigen keines, für heute die bis
    /// jetzt. **Die Uhr ist die des Hauses**, nicht die des Geräts: im Vorführbetrieb läuft
    /// sie im Zeitraffer, und ein halb schraffierter Tag wäre dort schlicht falsch.
    public static func gewesen(tag: String, jetzt: Date, schrittMin: Int = 15) -> Int? {
        guard schrittMin > 0, let spanne = Tag.zeitraum(tag) else { return nil }
        if jetzt >= spanne.bis { return nil }        // ganz vorbei: nichts ist „noch nicht"
        if jetzt <= spanne.von { return 0 }          // noch nicht angefangen
        let sekunden = jetzt.timeIntervalSince(spanne.von)
        return Int(sekunden / Double(schrittMin * 60))
    }

    // MARK: - Die Worte

    /// Eine Temperaturdifferenz mit Vorzeichen: „+1,9 K", „−0,4 K".
    ///
    /// Mit echtem Minus und schmalem Leerzeichen vor der Einheit, wie überall im Haus.
    public static func kelvin(_ k: Double) -> String {
        let vorzeichen = k > 0 ? "+" : Formate.minus
        return vorzeichen + Formate.zahl(abs(k), stellen: 1) + Formate.schmalesLeerzeichen + "K"
    }

    /// Die Abweichung als Text: **„am Ziel" innerhalb des Bandes**, sonst mit Vorzeichen.
    ///
    /// Nicht „auf Soll": geregelt wird auf Sollwert *plus Versatz*, und der Sollwert allein ist
    /// eine Zahl, auf die niemand regelt.
    public static func abweichungText(_ k: Double?) -> String {
        guard let k else { return "kein Messwert" }
        return abs(k) <= band ? "am Ziel" : kelvin(k)
    }

    /// Wie weit die Heizkreise offen sind – für einen Augenblick, nicht für einen Zeitraum.
    ///
    /// **Die Antriebe kennen kein Dazwischen**; der Anteil entsteht aus der Zahl der Kreise. In
    /// einem Augenblick ist er deshalb immer ein glatter Bruch, und „1 von 4 offen" sagt mehr
    /// als „25 %".
    public static func ventilText(_ anteil: Double?, kreise: Int) -> String {
        guard let anteil else { return "kein Messwert" }
        if anteil <= 0 { return "zu" }
        guard kreise > 0 else { return anteilText(anteil) }
        let offen = anteil * Double(kreise)
        guard abs(offen - offen.rounded()) <= 0.01 else { return anteilText(anteil) }
        return "\(Int(offen.rounded())) von \(kreise) offen"
    }

    /// Derselbe Anteil über einen Zeitraum – und da ist er kein Bruch mehr.
    ///
    /// Über eine Viertelstunde gemittelt heißt 0,57 weder „0,57 Kreise" noch „57 % offen" an
    /// einem Ventil, das nur auf und zu kennt, sondern: so viel von allem, was offen sein
    /// könnte, war offen. Der Prozentsatz ist dafür die einzige ehrliche Form.
    public static func anteilText(_ anteil: Double?) -> String {
        guard let anteil else { return "kein Messwert" }
        if anteil <= 0 { return "zu" }
        return Formate.zahl(anteil * 100, stellen: 0) + Formate.schmalesLeerzeichen + "%"
    }

    /// Der Fensterkontakt als Satz. **Ohne Kontakt steht nichts da** – nicht „zu", denn das
    /// wäre eine Behauptung über einen Raum, an dem niemand misst.
    public static func fensterText(offen: Double?, seitMin: Int?) -> String? {
        guard let offen, offen >= 0.5 else { return nil }
        guard let seitMin, seitMin >= 5 else { return "Fenster offen" }
        if seitMin < 60 { return "Fenster offen seit \(seitMin) min" }
        let h = seitMin / 60
        let m = seitMin % 60
        return "Fenster offen seit \(h) h" + (m > 0 ? " \(m) min" : "")
    }

    /// Wie lange das Fenster schon offen steht, in Minuten – aus dem Ende der Reihe rückwärts.
    ///
    /// **Warum nicht aus einem Zeitstempel.** Die Messreihe sagt, *dass* der Kontakt offen ist,
    /// nicht *seit wann*; einen Wechselzeitpunkt überträgt die Telemetrie nicht. Die Zeitreihe
    /// weiß es trotzdem, auf die Breite eines Fensters genau. Das reicht für den Satz, um den
    /// es geht: „kalt, weil seit einer halben Stunde gelüftet wird".
    public static func offenSeitMin(_ werte: [Double?], schrittMin: Int, bis: Int) -> Int? {
        var i = min(bis, werte.count - 1)
        // Noch nicht gemessene Fenster am Ende überspringen.
        while i >= 0, werte[i] == nil { i -= 1 }
        guard i >= 0, (werte[i] ?? 0) >= 0.5 else { return nil }
        var zahl = 0
        while i >= 0, (werte[i] ?? 0) >= 0.5 {
            zahl += 1
            i -= 1
        }
        return zahl * schrittMin
    }

    /// Die Zeile über einer Etage: „3 Räume · alle am Ziel".
    ///
    /// Sie nennt nur, was auffällt. Steht nichts Auffälliges da, steht da, dass nichts
    /// auffällt – eine Etage ohne Zeile wäre eine Etage, über die niemand etwas gesagt hat.
    public static func etagenText(_ raeume: [RoomLiveOut]) -> String {
        let n = raeume.count
        var teile: [String] = []
        let kalt = raeume.filter { ($0.deviationK ?? 0) < -band && $0.deviationK != nil }.count
        let stumm = raeume.filter { $0.tempC == nil }.count
        if kalt > 0 { teile.append("\(kalt) unter dem Ziel") }
        if stumm > 0 { teile.append("\(stumm) ohne Messwert") }
        if teile.isEmpty { teile.append("alle am Ziel") }
        return "\(n) \(n == 1 ? "Raum" : "Räume") · " + teile.joined(separator: " · ")
    }

    /// Die Räume nach Etage, **in der Reihenfolge, in der sie kommen**.
    ///
    /// Nicht alphabetisch: die Reihenfolge ist die der Anlage, und sortiert läge das
    /// Dachgeschoss vor dem Erdgeschoss.
    public static func nachEtage(_ raeume: [RoomLiveOut]) -> [(etage: String, raeume: [RoomLiveOut])] {
        var aus: [(etage: String, raeume: [RoomLiveOut])] = []
        for r in raeume {
            let name = r.floor.isEmpty ? "ohne Etagenangabe" : r.floor
            if let i = aus.firstIndex(where: { $0.etage == name }) {
                aus[i].raeume.append(r)
            } else {
                aus.append((etage: name, raeume: [r]))
            }
        }
        return aus
    }
}
