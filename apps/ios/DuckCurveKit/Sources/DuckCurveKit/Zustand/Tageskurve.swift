import Foundation

/// Ein Punkt einer Reihe im Tagesdiagramm.
///
/// Die x-Achse zaehlt Stunden seit Tagesbeginn, nicht Zeitpunkte. Das ist derselbe Griff wie im
/// Dashboard (`hx` in `DayCurve.tsx`) und hat zwei Gruende: eine Zahlenachse von 0 bis 24 laesst
/// sich beschriften, ohne dass Zeitzonen hineinspielen, und der Vortag laesst sich darauf
/// abbilden, obwohl er ein anderer Tag ist.
public struct Kurvenpunkt: Sendable, Hashable, Identifiable {
    /// Stunden seit Tagesbeginn, 0 bis 24 (am Tag der Zeitumstellung bis 23 oder 25).
    public var stunde: Double
    public var wert: Double

    public var id: Double { stunde }

    public init(stunde: Double, wert: Double) {
        self.stunde = stunde
        self.wert = wert
    }
}

/// Ein Band auf der Zeitachse: ein Preisfenster.
public struct Kurvenband: Sendable, Hashable, Identifiable {
    public var von: Double
    public var bis: Double
    public var art: Art
    public var name: String

    public var id: String { "\(art.rawValue)-\(von)" }

    public enum Art: String, Sendable, Hashable {
        case guenstig = "cheap"
        case negativ = "negative"
        case teuer = "expensive"
    }

    public init(von: Double, bis: Double, art: Art, name: String) {
        self.von = von
        self.bis = bis
        self.art = art
        self.name = name
    }
}

/// Welcher der drei Tage gezeigt wird.
///
/// **Weiter zurueck als gestern geht es hier nicht.** `DayCurve.tsx` begruendet es: vergangene
/// Tage stehen unter Strom, mit Blaettern und allem. „Die Wandanzeige soll nicht an einem Tag von
/// vorgestern haengen bleiben, wie es der alten passiert ist."
public enum Kurventag: String, Sendable, Hashable, CaseIterable {
    case gestern, heute, morgen

    public var name: String {
        switch self {
        case .gestern: return "Gestern"
        case .heute: return "Heute"
        case .morgen: return "Morgen"
        }
    }

    public var versatz: Int {
        switch self {
        case .gestern: return -1
        case .heute: return 0
        case .morgen: return 1
        }
    }
}

/// Alles, was das Tagesdiagramm zeichnet - fertig gerechnet.
///
/// **Warum das im Kern steht und nicht in der Ansicht.** Es ist die Stelle mit den meisten
/// stillen Fehlern: welche Reihe ab wann gestrichelt ist, welcher Punkt noch in den Tag faellt,
/// wie der Vortag auf die Achse kommt. Nichts davon sieht man an einem Diagramm an - eine
/// Prognose, die ueber einer Messung liegt, sieht aus wie eine dickere Linie. Hier wird es
/// gerechnet und in `TageskurveTests` nachgezaehlt.
public struct Tageskurve: Sendable {
    /// Gemessene PV-Leistung, als Flaeche.
    public var pv: [Kurvenpunkt] = []
    /// Erwartete PV-Leistung, blass und gestrichelt.
    public var pvErwartet: [Kurvenpunkt] = []
    /// Der ganze Hausverbrauch, als weisse Linie.
    public var haus: [Kurvenpunkt] = []
    /// Die Waermepumpe.
    public var waermepumpe: [Kurvenpunkt] = []
    /// Der Vortag, blass und ohne Flaeche, hinter allem.
    public var schatten: [Kurvenpunkt] = []
    /// Gemessener Preis.
    public var preis: [Kurvenpunkt] = []
    /// Erwarteter Preis.
    public var preisErwartet: [Kurvenpunkt] = []
    /// Der Strom, den die Waermepumpe nach der Wetterprognose brauchen wird. Nur fuer morgen.
    public var waermeErwartet: [Kurvenpunkt] = []
    /// Die Preisfenster.
    public var baender: [Kurvenband] = []
    /// Wo die Marke „jetzt" steht - nur am laufenden Tag.
    public var jetztStunde: Double?
    /// Wie viele Stunden der Tag hat. 24, am Tag der Zeitumstellung 23 oder 25.
    public var stunden: Double = 24

    /// Die Energie, die bis zur Jetzt-Marke aus der Sonne kam - und dasselbe am Vortag.
    ///
    /// `DayCurve.tsx`: „Eine Kurve allein sagt nicht, ob der Tag gut war; erst der Vortag macht
    /// aus 13,4 kWh eine Auskunft."
    public var pvKwh: Double?
    public var schattenKwh: Double?

    public init() {}

    // MARK: - Bauen

    /// Das Diagramm fuer einen Tag zusammenstellen.
    ///
    /// - Parameters:
    ///   - tag: welcher der drei Tage.
    ///   - raster: die Messwerte des gezeigten Tages.
    ///   - vortag: die Messwerte des Tages davor, fuer den Schatten.
    ///   - plan: Erwartung fuer Sonne und Preis.
    ///   - waermeprognose: der erwartete Strombedarf der Waermepumpe (nur fuer morgen gebraucht).
    ///   - jetzt: die Zeit des Hauses.
    public static func baue(
        tag: Kurventag,
        raster: [Verlaufspunkt],
        vortag: [Verlaufspunkt] = [],
        plan: PlanOut?,
        waermeprognose: [HeatForecastPoint] = [],
        jetzt: Date
    ) -> Tageskurve {
        var k = Tageskurve()
        let tagIso = Tag.plus(Tag.iso(jetzt), tag.versatz)
        guard let grenzen = Tag.zeitraum(tagIso) else { return k }
        let von = grenzen.von
        let bis = grenzen.bis
        k.stunden = bis.timeIntervalSince(von) / 3600

        /// Ein Zeitpunkt als Stunde seit Tagesbeginn.
        func stunde(_ d: Date) -> Double {
            d.timeIntervalSince(von) / 3600
        }

        func imTag(_ d: Date) -> Bool {
            d >= von && d < bis
        }

        // --------------------------------------------------------------- Messung
        let gemessen = raster.filter { imTag($0.zeit) }
        k.pv = gemessen.compactMap { p in p.pv.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) } }
        k.haus = gemessen.compactMap { p in p.haus.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) } }
        k.waermepumpe = gemessen.compactMap { p in
            p.waermepumpe.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) }
        }
        k.preis = gemessen.compactMap { p in p.preis.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) } }

        // ------------------------------------------------------------ Die Marke
        if tag == .heute {
            k.jetztStunde = max(0, min(k.stunden, stunde(jetzt)))
        }

        // ------------------------------------------------------------ Erwartung
        //
        // Gestern wird nichts vorhergesagt, heute erst ab jetzt: eine Prognose ueber eine
        // Messung zu legen, die es schon gibt, waere doppelt gezeichnet und sagte nichts. Die
        // Viertelstunde Rueckgriff schliesst die Luecke zwischen dem letzten Messwert und der
        // ersten Erwartung - ohne sie klafft die Kurve an der Jetzt-Marke.
        let abZeit = tag == .heute ? max(von, jetzt.addingTimeInterval(-15 * 60)) : von
        if tag != .gestern {
            let voraus = (plan?.intervals ?? []).compactMap { i -> (Date, PlanIntervalOut)? in
                guard let t = Zeit.ausIso(i.ts), t >= abZeit, imTag(t) else { return nil }
                return (t, i)
            }
            k.pvErwartet = voraus.map { Kurvenpunkt(stunde: stunde($0.0), wert: $0.1.expectedPvKw) }
            k.preisErwartet = voraus.compactMap { t, i in
                i.priceCtKwh.map { Kurvenpunkt(stunde: stunde(t), wert: $0) }
            }
        }

        // Fuer morgen kommt eine Linie dazu, die es sonst nicht gaebe: der Strom, den die
        // Waermepumpe nach der Wetterprognose brauchen wird.
        if tag == .morgen {
            k.waermeErwartet = waermeprognose.compactMap { p in
                guard let t = Zeit.ausIso(p.ts), imTag(t) else { return nil }
                return Kurvenpunkt(stunde: stunde(t), wert: p.electricKw)
            }
        }

        // -------------------------------------------------------------- Schatten
        //
        // **Der Vortag wird nach der Uhr abgebildet, nicht nach den Sekunden.** Am Tag der
        // Zeitumstellung hat er 23 oder 25 Stunden; „um 12 Uhr" liegt dann nicht dort, wo 12 mal
        // 3600 Sekunden seit Mitternacht liegen. Verglichen werden soll die Uhrzeit.
        k.schatten = vortag.compactMap { p in
            guard let v = p.pv else { return nil }
            let t = Kalender.haus.dateComponents([.hour, .minute], from: p.zeit)
            let h = Double(t.hour ?? 0) + Double(t.minute ?? 0) / 60
            return Kurvenpunkt(stunde: h, wert: v)
        }

        // --------------------------------------------------------------- Baender
        k.baender = (plan?.windows ?? []).compactMap { w in
            guard let a = Zeit.ausIso(w.start), let e = Zeit.ausIso(w.end) else { return nil }
            guard a < bis, e > von else { return nil }
            guard let art = Kurvenband.Art(rawValue: w.kind.rawValue) else { return nil }
            // Nur die Fenster, die einen Griff begruenden. Teure Fenster stehen im Fahrplan.
            guard art == .guenstig || art == .negativ else { return nil }
            return Kurvenband(
                von: max(0, stunde(a)),
                bis: min(k.stunden, stunde(e)),
                art: art,
                name: art == .negativ ? "Preis negativ" : "Preistief"
            )
        }

        // ------------------------------------------------------------- Die Summen
        k.pvKwh = energie(k.pv, bis: k.jetztStunde)
        k.schattenKwh = energie(k.schatten, bis: k.jetztStunde)
        return k
    }

    /// Die Energie unter einer Leistungskurve, in kWh.
    ///
    /// Trapezregel ueber die Stuetzpunkte. Bei einem Minutenraster ist der Unterschied zur
    /// Rechteckregel klein, aber nicht null - und bei einer Reihe mit Luecken (ein Ausfall von
    /// zwanzig Minuten) ist er gross: die Trapezregel fuellt die Luecke mit dem Mittel der
    /// Raender, die Rechteckregel mit dem letzten Wert.
    public static func energie(_ punkte: [Kurvenpunkt], bis: Double? = nil) -> Double? {
        let reihe = bis.map { grenze in punkte.filter { $0.stunde <= grenze } } ?? punkte
        guard reihe.count > 1 else { return nil }
        var summe = 0.0
        for i in 1..<reihe.count {
            let dt = reihe[i].stunde - reihe[i - 1].stunde
            guard dt > 0 else { continue }
            summe += (reihe[i].wert + reihe[i - 1].wert) / 2 * dt
        }
        return summe
    }

    /// Die obere Grenze der Leistungsachse.
    ///
    /// Nicht der groesste Messwert, sondern eine runde Zahl darueber: eine Achse, die bei jedem
    /// Takt auf den aktuellen Hoechstwert springt, laesst die ganze Zeichnung zappeln.
    public var leistungsgrenze: Double {
        let alle = [pv, pvErwartet, haus, waermepumpe, schatten, waermeErwartet]
            .flatMap { $0 }
            .map { abs($0.wert) }
            .filter { $0.isFinite }
        let hoch = alle.max() ?? 0
        // In Schritten von einem Kilowatt, mindestens vier.
        return max(4, (hoch * 1.12).rounded(.up))
    }

    /// Die Grenzen der Preisachse, mit der Schrittweite ihrer Marken.
    ///
    /// **So eng wie möglich, und auf runden Zahlen.** Hier stand `min(0, tief − 2)` bis
    /// `max(10, hoch + 2)`: die Achse reichte immer bis zur Null, und an einem gewöhnlichen
    /// Tag zwischen 38 und 52 ct lag die ganze Kurve damit im oberen Viertel und sah flach
    /// aus - genau so stand es am 19.11.2026 auf dem iPad. Die Null gehört auf diese Achse nur,
    /// wenn es negative Preise gibt; dann ist sie die Nachricht.
    ///
    /// **Wie die runde Spanne entsteht** (`charts/dayBounds.ts`, `priceBounds`): gesucht wird
    /// die feinste runde Schrittweite, die mit höchstens sieben Abschnitten auskommt. Weil die
    /// Schrittweiten ansteigen, ist der erste Treffer zugleich der mit der engsten Spanne - und
    /// je enger die Spanne, desto mehr Höhe bleibt für den Verlauf. Ein gröberer Schritt reißt
    /// die Achse beim Runden wieder auf: bei 22 bis 46 ct ergibt Schritt 5 die Spanne 20 bis
    /// 50, Schritt 20 dagegen 0 bis 60.
    public var preisgrenzen: (unten: Double, oben: Double, schritt: Double) {
        let alle = (preis + preisErwartet).map(\.wert).filter(\.isFinite)
        guard let tief = alle.min(), let hoch = alle.max() else { return (0, 45, 15) }
        // Wenig Luft, damit die Kurve die Ränder nicht berührt.
        let luft = max(0.5, (hoch - tief) * 0.06)
        for schritt in [0.5, 1, 2, 2.5, 5, 10, 20, 25, 50, 100] {
            let unten = ((tief - luft) / schritt).rounded(.down) * schritt
            let oben = ((hoch + luft) / schritt).rounded(.up) * schritt
            if (oben - unten) / schritt <= 7 {
                return (unten, max(oben, unten + 2 * schritt), schritt)
            }
        }
        let unten = (tief - luft).rounded(.down)
        let oben = (hoch + luft).rounded(.up)
        return (unten, oben, max(1, ((hoch - tief) / 3).rounded()))
    }

    /// Die Marken der Preisachse, von unten nach oben.
    public var preismarken: [Double] {
        let g = preisgrenzen
        guard g.schritt > 0, g.oben > g.unten else { return [] }
        var aus: [Double] = []
        var v = g.unten
        // Rundungsfehler: `0.1 + 0.2` ist nicht `0.3`, und eine Marke, die um ein
        // Milliardstel über der Grenze liegt, fiele sonst weg.
        while v <= g.oben + g.schritt / 1000 {
            aus.append((v * 1000).rounded() / 1000)
            v += g.schritt
        }
        return aus
    }

    /// Ein Preis in Cent, abgebildet auf die Leistungsachse.
    ///
    /// **Warum das sein muss.** Die Wandanzeige zeichnet Leistung und Preis in EIN Bild mit
    /// zwei Achsen - links Kilowatt, rechts Cent (`DayCurve.tsx`, `yAxis[1].position: right`).
    /// Swift Charts kennt nur eine Werteachse je Bild; die zweite entsteht, indem der Preis in
    /// die Leistungsachse gerechnet und die rechte Achse zurückgerechnet beschriftet wird.
    public func preisAufLeistung(_ ct: Double) -> Double {
        let g = preisgrenzen
        guard g.oben > g.unten else { return 0 }
        return (ct - g.unten) / (g.oben - g.unten) * leistungsgrenze
    }

    /// Der Rückweg: welcher Preis steht an dieser Stelle der Leistungsachse?
    public func leistungAufPreis(_ kw: Double) -> Double {
        let g = preisgrenzen
        guard leistungsgrenze > 0 else { return g.unten }
        return g.unten + kw / leistungsgrenze * (g.oben - g.unten)
    }

    /// Ist überhaupt etwas zu zeichnen?
    public var leer: Bool {
        pv.isEmpty && pvErwartet.isEmpty && haus.isEmpty && preis.isEmpty && preisErwartet.isEmpty
    }
}
