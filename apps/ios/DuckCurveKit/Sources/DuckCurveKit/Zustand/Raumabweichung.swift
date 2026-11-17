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
}
