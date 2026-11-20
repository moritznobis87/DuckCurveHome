import Foundation

/// Der Speicher ueber einen Tag: Ladestand in Prozent und Leistung in Kilowatt.
///
/// **Warum eine eigene Kurve neben ``Pruefkurve``.** Die Pruefkurve traegt sechs Reihen und
/// gehoert der Seite „Daten prüfen“; hier werden genau zwei gebraucht, und sie liegen nicht
/// uebereinander, sondern in zwei Flaechen untereinander. Die Vorlage begruendet das
/// ausfuehrlich (`charts.ts:11-31`): *„Zwei Kurven in einem Bild liest das Auge als
/// Zusammenhang ihrer Kreuzungspunkte, und wo sie sich kreuzen, entscheidet allein die
/// Skalierung.“* Zwei Flaechen heisst zwei Achsenspannen, und die untere darf darum nicht die
/// der Pruefkurve sein.
///
/// **Der Ladestand wird hier einmal in Prozent gerechnet, nicht in der Ansicht.** Der Dienst
/// liefert ihn als Anteil von 0 bis 1 (`battery_soc`). Eine Reihe, die als 0,42 gezeichnet und
/// als 42 beschriftet wird, ist genau der Fehler, den diese Seite aufdecken soll.
public struct Speichertagkurve: Sendable, Hashable {

    /// Der Ladestand in Prozent, 0 bis 100.
    public var ladestandProzent: [Kurvenpunkt] = []
    /// Die Leistung in Kilowatt. Plus ist Entladen, minus Laden.
    public var leistungKw: [Kurvenpunkt] = []
    /// Wie lang der Tag ist - am Tag der Zeitumstellung 23 oder 25 Stunden.
    public var stunden: Double = 24
    /// Die Zeitachse beider Flaechen. Sie ist dieselbe, sonst stuenden sie nicht uebereinander.
    public var fenster: ClosedRange<Double> = 0...24
    /// Die Achse der unteren Flaeche.
    public var leistungsspanne: ClosedRange<Double> = Speichertagkurve.mindestspanne

    public init() {}

    // MARK: - Die Achse der unteren Flaeche

    /// Die kleinste Leistungsachse, die gezeichnet wird.
    ///
    /// **Enger als ``Pruefkurve/mindestspanne``, und das ist der Punkt.** Dort sind es
    /// −2 bis 4 kW, weil dort sechs Reihen in einer Flaeche von 300 Punkten liegen. Hier ist die
    /// untere Flaeche 60 Punkte hoch (`charts.ts:32-38`); eine erzwungene Spanne von sechs
    /// Kilowatt druecke einen ruhigen Tag darin zu einer geraden Linie.
    public static let mindestspanne: ClosedRange<Double> = -1...1
    /// Luft ueber dem groessten und unter dem kleinsten Wert.
    public static let luft: Double = 1.1
    /// Die Marken der Ladestandsachse (`charts.ts:268`: `interval: 25`).
    public static let ladestandsmarken: [Double] = [0, 25, 50, 75, 100]
    /// Die Ladestandsachse ist fest 0 bis 100 und nicht datenabhaengig: ein Tag zwischen 48 und
    /// 52 Prozent soll als ruhiger Tag dastehen und nicht als Zickzack ueber die ganze Flaeche.
    public static let ladestandsspanne: ClosedRange<Double> = 0...100

    /// Die Leistungsachse zu einer Reihe. Die Null liegt immer darin: ueber ihr ist Entladen,
    /// unter ihr Laden, und an ihr liest man ab, was der Speicher gerade tut.
    public static func spanne(_ punkte: [Kurvenpunkt]) -> ClosedRange<Double> {
        let werte = punkte.map(\.wert).filter(\.isFinite)
        let hoch = max(0, werte.max() ?? 0)
        let tief = min(0, werte.min() ?? 0)
        let oben = max(mindestspanne.upperBound, (hoch * luft * 10).rounded(.up) / 10)
        let unten = min(mindestspanne.lowerBound, (tief * luft * 10).rounded(.down) / 10)
        return unten...oben
    }

    // MARK: - Bauen

    /// Die Kurve eines Kalendertages aus dem Minutenraster.
    ///
    /// - Parameters:
    ///   - tag: der Kalendertag der Hauszeit, `2026-11-10`.
    ///   - raster: die Minutenzeilen; Punkte ausserhalb des Tages fallen weg.
    ///   - schrittMin: auf welches Raster gemittelt wird. Fuenf Minuten wie bei
    ///     ``Pruefkurvenbild`` - 1440 Punkte mal zwei Reihen sind mehr Marken, als eine
    ///     340 Punkte hohe Karte aufloest.
    public static func baue(
        tag: String, raster: [Pruefpunkt], schrittMin: Int = 5
    ) -> Speichertagkurve {
        var k = Speichertagkurve()
        guard let grenzen = Tag.zeitraum(tag) else { return k }
        let von = grenzen.von
        let bis = grenzen.bis
        k.stunden = bis.timeIntervalSince(von) / 3600
        k.fenster = 0...k.stunden

        func stunde(_ d: Date) -> Double { d.timeIntervalSince(von) / 3600 }

        let gemessen = raster
            .filter { $0.zeit >= von && $0.zeit < bis }
            .sorted { $0.zeit < $1.zeit }

        let stand = gemessen.compactMap { p in
            p.ladestand.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0 * 100) }
        }
        let leistung = gemessen.compactMap { p in
            p.speicher.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) }
        }
        k.ladestandProzent = Pruefkurve.verdichte(stand, schrittMin: schrittMin)
        k.leistungKw = Pruefkurve.verdichte(leistung, schrittMin: schrittMin)
        k.leistungsspanne = spanne(k.leistungKw)
        return k
    }

    /// Dasselbe aus der Antwort des Dienstes. `nil` ergibt eine leere Kurve - eine gescheiterte
    /// Abfrage ist kein Tag ohne Messung, aber zu zeichnen ist in beiden Faellen nichts, und
    /// die Unterscheidung traegt die Seite, nicht die Kurve.
    public static func baue(
        tag: String, historie: HistoryOut?, schrittMin: Int = 5
    ) -> Speichertagkurve {
        baue(tag: tag, raster: Pruefpunkt.raster(historie), schrittMin: schrittMin)
    }

    // MARK: - Abfragen

    /// Ist ueberhaupt etwas zu zeichnen?
    public var leer: Bool { ladestandProzent.isEmpty && leistungKw.isEmpty }

    /// Die Strecken der Leistungsreihe - jede Luecke trennt.
    ///
    /// Die Vorlage zeichnet die Leistung ohne `connectNulls`, den Ladestand mit
    /// (`charts.ts:273-274`): ein Speicher, der zwanzig Minuten nicht meldet, hat in dieser Zeit
    /// nicht null Kilowatt geliefert, aber sein Ladestand hat sich auch nicht aufgeloest.
    public var leistungsstrecken: [[Kurvenpunkt]] {
        Pruefkurve.strecken(leistungKw, hoechstabstand: lueckenabstand)
    }

    /// Nach wie viel Zeit eine Luecke eine Luecke ist. Bei einem Fuenf-Minuten-Raster sind drei
    /// fehlende Minuten kein Ausfall; drei fehlende Schritte sind einer.
    public var lueckenabstand: Double { 3 * schrittweite }

    /// Der Abstand zweier Punkte in Stunden, aus den Daten gelesen.
    var schrittweite: Double {
        guard leistungKw.count > 1 else { return 5.0 / 60 }
        let abstaende = zip(leistungKw, leistungKw.dropFirst()).map { $1.stunde - $0.stunde }
        return abstaende.min() ?? (5.0 / 60)
    }

    // MARK: - Die Woerter der Karte

    /// Was rechts im Kartenkopf steht (`BatteryReport.tsx:159`).
    public static func kopfzeile(tagesansicht: Bool) -> String {
        tagesansicht
            ? "oben der Ladezustand, unten die Leistung: + Entladen, \(Formate.minus) Laden"
            : "nur in der Tagesansicht"
    }

    /// Was statt des Bildes dasteht (`BatteryReport.tsx:160`).
    ///
    /// **Zwei verschiedene Saetze, und das ist keine Umstaendlichkeit.** „Keine Minutenwerte“
    /// ist eine Luecke in den Daten; „nicht die Tagesansicht“ ist eine Eigenschaft der Ansicht.
    /// Ein Satz fuer beides liesse den Leser raten, ob an seinem Speicher etwas fehlt.
    public static func leersatz(tagesansicht: Bool) -> String {
        tagesansicht
            ? "Für diesen Tag liegen keine Minutenwerte vor; die Stundenbilanzen oben stammen "
                + "dann aus dem Historienimport."
            : "Der Verlauf wird je Tag gezeigt; für längere Zeiträume gelten die "
                + "Stundenbilanzen oben."
    }

    /// Die Namen der beiden Reihen - in Legende, Kopfzeile und Hinweisfenster dieselben
    /// (`charts.ts:273-274`).
    public static let ladestandsname = "Ladezustand"
    public static let leistungsname = "Leistung"
}
