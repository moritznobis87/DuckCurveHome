import Foundation

// =====================================================================================
//  Die Seite „Daten prüfen" - alles Gerechnete.
//
//  Vorlage: `apps/web/src/components/reports/DataCheck.tsx` mit `charts.ts` (powerOverlay),
//  `Sources.tsx` und `CoverageMap.tsx`. Diese Datei trägt die drei Rechnungen dieser Seite:
//  die Prüfkurve mit ihrer zweiten Achse, den Zustand der Quellen und das Raster der
//  Verfügbarkeit. Keine Farben, keine Maße, keine Ansicht.
// =====================================================================================

/// Eine Minute, wie die Prüfansicht sie braucht.
///
/// **Warum es dafür einen eigenen Punkt gibt und nicht `Verlaufspunkt`.** Die Prüfansicht
/// liest zwei Reihen, die im Minutenraster der Tageskurve nicht vorkommen: den Ladestand
/// (`battery_soc`) und den amtlichen Zähler (`grid_power_meter_kw`). Beide sind der Zweck
/// dieser Seite - sie sind die zwei Gegenproben, mit denen man eine Messung prüft, ohne ihr zu
/// glauben. Dafür fehlt hier, was `Verlaufspunkt` trägt und die Prüfansicht gerade nicht
/// verwenden darf: `house_power_kw`. Der Hausverbrauch ist auf dieser Seite keine Messung,
/// sondern folgt aus der Bilanz.
///
/// **Das ist kein Live-Raster.** `Minutenraster` schreibt aus dem Ereignisstrom fort und
/// mittelt dabei; hier wird nichts fortgeschrieben. Die Prüfansicht zeigt einen abgelegten
/// Tag so, wie er in der Datenbank steht - sonst prüfte man nicht die Daten, sondern die App.
public struct Pruefpunkt: Sendable, Hashable, Identifiable {
    /// Der Anfang der Minute, auf die dieser Punkt fällt.
    public var zeit: Date
    /// Erzeugung, `pv_power_kw`.
    public var pv: Double?
    /// Der Stromwandler am Netzanschluss, `grid_power_kw`. Plus ist Bezug, minus Einspeisung.
    public var netz: Double?
    /// Derselbe Netzwert, gemessen vom amtlichen Zähler: `grid_power_meter_kw`.
    public var netzZaehler: Double?
    /// Der Speicher, `battery_power_kw`. Plus ist Entladen, minus Laden.
    public var speicher: Double?
    /// Der Ladestand als Anteil von 0 bis 1, so wie der Dienst ihn liefert (`battery_soc`).
    public var ladestand: Double?

    public var id: Date { zeit }

    public init(
        zeit: Date, pv: Double? = nil, netz: Double? = nil, netzZaehler: Double? = nil,
        speicher: Double? = nil, ladestand: Double? = nil
    ) {
        self.zeit = zeit
        self.pv = pv
        self.netz = netz
        self.netzZaehler = netzZaehler
        self.speicher = speicher
        self.ladestand = ladestand
    }

    /// Eine Zeile der Historie lesen.
    ///
    /// Eine Zeile ohne lesbaren Zeitstempel wird verworfen und nicht auf den 1. Januar 1970
    /// gelegt - dort zöge sie die Zeitachse des ganzen Diagramms zu sich (`Minutenraster`
    /// entscheidet an derselben Stelle genauso).
    public static func ausZeile(_ zeile: [String: Mischwert]) -> Pruefpunkt? {
        guard let roh = zeile["ts"]?.alsText, let zeit = Zeit.ausIso(roh) else { return nil }
        return Pruefpunkt(
            zeit: zeit,
            pv: zeile["pv_power_kw"]?.alsZahl,
            netz: zeile["grid_power_kw"]?.alsZahl,
            netzZaehler: zeile["grid_power_meter_kw"]?.alsZahl,
            speicher: zeile["battery_power_kw"]?.alsZahl,
            ladestand: zeile["battery_soc"]?.alsZahl
        )
    }

    /// Alle lesbaren Zeilen einer Historienantwort.
    public static func raster(_ zeilen: [[String: Mischwert]]) -> [Pruefpunkt] {
        zeilen.compactMap(ausZeile)
    }

    /// Dasselbe aus der Antwort des Dienstes. `nil` ergibt ein leeres Raster - eine
    /// gescheiterte Abfrage ist kein Tag ohne Messung, aber zu zeichnen ist in beiden Fällen
    /// nichts, und die Unterscheidung trägt die Seite, nicht die Kurve.
    public static func raster(_ historie: HistoryOut?) -> [Pruefpunkt] {
        raster(historie?.rows ?? [])
    }
}

/// Die sechs Reihen der Prüfkurve, fertig gerechnet, mit ihrer Achsenspanne.
///
/// **Warum eine eigene Kurve neben `Tageskurve`.** Die Tageskurve erzählt den Tag: Sonne,
/// Haus, Wärmepumpe, Preis. Diese hier prüft ihn. Dafür liegen andere Reihen übereinander, und
/// zwei von ihnen messen absichtlich dasselbe zweimal - der Zähler neben dem Wandler, der
/// Ladestand neben der Ladeleistung. Wo zwei Reihen dieselbe Größe anders messen, ist die
/// Abweichung die Nachricht.
///
/// **Der Hausverbrauch ist hier keine Messung.** Er wird aus der Bilanz gerechnet,
/// `max(0, PV + Netz + Speicher)`, und ist `nil`, sobald PV oder Netz fehlen
/// (`charts.ts:565-570`). Das ist nicht Geschmack: `house_power_kw` käme aus derselben Quelle,
/// die geprüft werden soll. Läuft die PV und zeigt das Netz trotzdem Bezug, sieht man an der
/// gerechneten Linie unmittelbar, ob der Verbrauch über der Erzeugung lag oder ob die
/// Erzeugungsreihe eine Lücke hat.
///
/// **Die Spanne muss unter Null reichen.** Anders als `Tageskurve.leistungsgrenze` kann diese
/// Achse nicht bei null beginnen: Netz und Speicher haben Vorzeichen, Einspeisung und Laden
/// liegen unter der Nulllinie, und die Nulllinie ist auf dieser Seite der Bezugspunkt, an dem
/// man die Bilanz abliest.
///
/// **Das ist kein Diagramm.** Hier stehen keine Farben, keine Strichstärken und keine Maße;
/// `Reihe` nennt nur, welche Reihen es gibt, in welcher Reihenfolge sie in der Legende stehen
/// und welche davon gestrichelt auf der rechten Achse liegt.
public struct Pruefkurve: Sendable, Hashable {

    // MARK: - Welche Reihen es gibt

    /// Die sechs Reihen in der Reihenfolge der Legende (`charts.ts:606-625`).
    ///
    /// **Warum eine Aufzählung und keine Zeichenketten in der Ansicht.** Die Namen stehen in
    /// der Legende, im Hinweisfenster und in der Kopfzeile der Karte. Dreimal derselbe Text an
    /// drei Stellen ist dreimal die Gelegenheit, dass zwei davon „Netz (Zähler)" und einer
    /// „Zähler" sagt - und die Legende, die andere Wörter zeigt als das Bild, ist schlimmer als
    /// gar keine.
    public enum Reihe: String, Sendable, Hashable, CaseIterable, Identifiable {
        case pv, haus, netz, netzZaehler, speicher, ladestand

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .pv: return "PV"
            case .haus: return "Haus"
            case .netz: return "Netz"
            case .netzZaehler: return "Netz (Zähler)"
            case .speicher: return "Speicher"
            case .ladestand: return "Ladestand %"
            }
        }

        /// Die beiden Gegenproben sind gestrichelt: sie tragen die Farbe ihres Geschwisters und
        /// unterscheiden sich nur im Strich (`charts.ts:753-773`).
        public var gestrichelt: Bool {
            self == .netzZaehler || self == .ladestand
        }

        /// Liegt die Reihe auf der rechten Prozentachse? Nur der Ladestand.
        public var rechteAchse: Bool { self == .ladestand }

        /// Darf die Reihe über ihre Lücken hinweg gezeichnet werden?
        ///
        /// Nur der Zähler, und der muss es: er meldet alle rund fünfzehn Minuten. Getrennt
        /// gezeichnet bestünde seine Reihe aus einzelnen Punkten und wäre als Linie unsichtbar
        /// (`charts.ts:753-762`, `connectNulls: true`).
        public var verbunden: Bool { self == .netzZaehler }
    }

    // MARK: - Die Reihen

    /// Erzeugung. In der Vorlage die einzige Reihe mit Fläche.
    public var pv: [Kurvenpunkt] = []
    /// Der gerechnete Hausverbrauch aus der Bilanz, **nicht** `house_power_kw`.
    public var haus: [Kurvenpunkt] = []
    /// Der Stromwandler am Netzanschluss.
    public var netz: [Kurvenpunkt] = []
    /// Der amtliche Zähler - dieselbe Größe, anders gemessen.
    public var netzZaehler: [Kurvenpunkt] = []
    /// Der Speicher.
    public var speicher: [Kurvenpunkt] = []
    /// Der Ladestand in **Prozent**, 0 bis 100 - nicht als Anteil.
    public var ladestand: [Kurvenpunkt] = []

    // MARK: - Die Achsen

    /// Wie viele Stunden der Tag hat. 24, am Tag der Zeitumstellung 23 oder 25.
    public var stunden: Double = 24
    /// Der gezeigte Abschnitt der Zeitachse. Ohne gewähltes Fenster der ganze Tag.
    ///
    /// Das ist das `filterMode: "filter"` der Vorlage: ein Ausschnitt verkleinert nicht nur die
    /// Zeitachse, sondern auch die Leistungsachse - sonst bleibt eine Viertelstunde mit 0,3 kW
    /// im Maßstab eines Tages mit 9 kW ein flacher Strich.
    public var fenster: ClosedRange<Double> = 0...24
    /// Die Leistungsachse, von unten nach oben. Reicht immer über die Null hinweg.
    ///
    /// **Gespeichert und nicht gerechnet.** Jede Umrechnung auf die rechte Prozentachse braucht
    /// sie, und das einmal je Punkt: bei 1440 Minuten wäre eine gerechnete Spanne eine Schleife
    /// über alle Reihen in jeder dieser Umrechnungen.
    public var leistungsspanne: ClosedRange<Double> = Pruefkurve.mindestspanne

    // MARK: - Die Konstanten der Vorlage

    /// Die kleinste Leistungsachse, die diese Seite zeigt.
    ///
    /// Nach oben vier Kilowatt wie in `Tageskurve.leistungsgrenze`; nach unten zwei, damit eine
    /// Einspeisung von 300 Watt die Nulllinie nicht auf den unteren Rand drückt. Eine Achse,
    /// die bei jedem Takt auf den aktuellen Höchstwert springt, lässt die Zeichnung zappeln.
    public static let mindestspanne: ClosedRange<Double> = -2...4
    /// Die Luft über dem größten und unter dem kleinsten Wert (`Tageskurve.leistungsgrenze`).
    public static let luft: Double = 1.12
    /// Was „genau 0,00 kW" heißt: alles, was die Anzeige mit zwei Nachkommastellen als `0,00`
    /// schreibt, also weniger als fünf Watt (`DataCheck.tsx:141-147`).
    public static let nullschwelle: Double = 0.005
    /// Ab wann sich der Netzwert „weiterbewegt": fünfzig Watt Spannweite - weniger ist auch in
    /// der Anzeige mit einer Nachkommastelle dieselbe Zahl (`Formate.kw`).
    public static let netzRegung: Double = 0.05
    /// Ab welchem Abstand zweier Punkte eine Reihe eine echte Lücke hat: drei Minuten.
    ///
    /// Das Raster ist ein Minutenraster; zwei bis drei fehlende Minuten sind ein verschlucktes
    /// Paket, zwanzig sind ein Ausfall. Das ist das `connectNulls: false` der Vorlage: Swift
    /// Charts verbindet zwei Punkte auch dann, wenn zwischen ihnen eine halbe Stunde liegt -
    /// die Trennung muss also aus getrennten Strecken kommen.
    public static let lueckenabstand: Double = 3.0 / 60
    /// Was die Hauptkarte sagt, wenn es für den Tag keine Minutenwerte gibt
    /// (`DataCheck.tsx:82-84`).
    public static let leersatz =
        "Für diesen Tag liegen keine Minutenwerte vor. Seine Stundenbilanzen stammen dann aus dem Historienimport."

    public init() {}

    // MARK: - Bauen

    /// Die Kurve eines Kalendertages aus dem Minutenraster.
    ///
    /// - Parameters:
    ///   - tag: der Kalendertag der Hauszeit, `2026-11-10`.
    ///   - raster: die Minutenzeilen; Punkte außerhalb des Tages fallen weg.
    public static func baue(tag: String, raster: [Pruefpunkt]) -> Pruefkurve {
        var k = Pruefkurve()
        guard let grenzen = Tag.zeitraum(tag) else { return k }
        let von = grenzen.von
        let bis = grenzen.bis
        k.stunden = bis.timeIntervalSince(von) / 3600
        k.fenster = 0...k.stunden

        /// Ein Zeitpunkt als Stunde seit Tagesbeginn - dieselbe Achse wie in `Tageskurve`.
        func stunde(_ d: Date) -> Double {
            d.timeIntervalSince(von) / 3600
        }

        // Aufsteigend, und das ist keine Vorsichtsmaßnahme: eine Zeile, die zwischen zwei
        // anderen aus der Reihe fällt, zieht die Linie zurück und wieder vor - im Bild ein
        // Blitz quer über den Tag, in den Zahlen nichts.
        let gemessen = raster
            .filter { $0.zeit >= von && $0.zeit < bis }
            .sorted { $0.zeit < $1.zeit }

        k.pv = gemessen.compactMap { p in p.pv.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) } }
        k.netz = gemessen.compactMap { p in p.netz.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) } }
        k.netzZaehler = gemessen.compactMap { p in
            p.netzZaehler.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) }
        }
        k.speicher = gemessen.compactMap { p in
            p.speicher.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0) }
        }
        // Der Ladestand kommt als Anteil und wird hier einmal in Prozent gerechnet, nicht in
        // der Ansicht: eine Reihe, die als 0,42 gezeichnet und als 42 beschriftet wird, ist
        // genau der Fehler, den diese Seite aufdecken soll.
        k.ladestand = gemessen.compactMap { p in
            p.ladestand.map { Kurvenpunkt(stunde: stunde(p.zeit), wert: $0 * 100) }
        }
        k.haus = gemessen.compactMap { p in
            guard let pv = p.pv, let netz = p.netz else { return nil }
            return Kurvenpunkt(
                stunde: stunde(p.zeit), wert: max(0, pv + netz + (p.speicher ?? 0)))
        }

        k.leistungsspanne = spanne(k.leistungsreihen)
        return k
    }

    /// Dasselbe aus der Antwort des Dienstes.
    public static func baue(tag: String, historie: HistoryOut?) -> Pruefkurve {
        baue(tag: tag, raster: Pruefpunkt.raster(historie))
    }

    // MARK: - Die Reihen abfragen

    /// Die Punkte einer Reihe.
    public func punkte(_ reihe: Reihe) -> [Kurvenpunkt] {
        switch reihe {
        case .pv: return pv
        case .haus: return haus
        case .netz: return netz
        case .netzZaehler: return netzZaehler
        case .speicher: return speicher
        case .ladestand: return ladestand
        }
    }

    /// Alle Reihen, die auf der Leistungsachse liegen - also alle außer dem Ladestand.
    public var leistungsreihen: [[Kurvenpunkt]] {
        Reihe.allCases.filter { !$0.rechteAchse }.map(punkte)
    }

    /// Die Legende, in der Reihenfolge der Vorlage.
    public var legende: [Reihe] { Reihe.allCases }

    /// Ist überhaupt etwas zu zeichnen?
    public var leer: Bool {
        Reihe.allCases.allSatisfy { punkte($0).isEmpty }
    }

    // MARK: - Die Achsenspanne

    /// Die Leistungsachse zu einer Menge von Reihen.
    ///
    /// Die Null liegt immer darin: sie ist auf dieser Seite nicht der Anfang der Achse, sondern
    /// die Linie, an der sich Bezug von Einspeisung und Entladen von Laden scheidet.
    public static func spanne(_ reihen: [[Kurvenpunkt]]) -> ClosedRange<Double> {
        let werte = reihen.flatMap { $0 }.map(\.wert).filter(\.isFinite)
        let hoch = max(0, werte.max() ?? 0)
        let tief = min(0, werte.min() ?? 0)
        let oben = max(mindestspanne.upperBound, (hoch * luft).rounded(.up))
        let unten = min(mindestspanne.lowerBound, (tief * luft).rounded(.down))
        return unten...oben
    }

    /// Ein Ladestand in Prozent, abgebildet auf die Leistungsachse.
    ///
    /// **Warum das sein muss.** Die Vorlage hat zwei Werteachsen: links Kilowatt, rechts
    /// Prozent von 0 bis 100 (`charts.ts:698-719`). Swift Charts kennt nur eine Werteachse je
    /// Bild; die zweite entsteht, indem der Ladestand in die Leistungsachse gerechnet und die
    /// rechte Achse zurückgerechnet beschriftet wird - dasselbe Muster wie
    /// `Tageskurve.preisAufLeistung`.
    ///
    /// **Und warum es hier anders gerechnet wird als dort.** `preisAufLeistung` rechnet auf
    /// `0...leistungsgrenze`, denn dort beginnt die Achse bei null. Hier reicht sie unter die
    /// Null, und 0 Prozent gehört an den **unteren Rand** der Achse, nicht auf die Nulllinie -
    /// sonst läge der halbe Ladestandsbereich unter dem Bild.
    public func ladestandAufLeistung(_ prozent: Double) -> Double {
        let hoehe = leistungsspanne.upperBound - leistungsspanne.lowerBound
        guard hoehe > 0 else { return leistungsspanne.lowerBound }
        return leistungsspanne.lowerBound + prozent / 100 * hoehe
    }

    /// Der Rückweg: welcher Ladestand steht an dieser Stelle der Leistungsachse?
    public func leistungAufLadestand(_ kw: Double) -> Double {
        let hoehe = leistungsspanne.upperBound - leistungsspanne.lowerBound
        guard hoehe > 0 else { return 0 }
        return (kw - leistungsspanne.lowerBound) / hoehe * 100
    }

    /// Die Marken der rechten Achse, in Prozent.
    public static let ladestandsmarken: [Double] = [0, 25, 50, 75, 100]

    // MARK: - Zeitfenster

    /// Die Kurve auf ein Zeitfenster beschneiden - mitsamt neu gerechneter Leistungsachse.
    ///
    /// Ein leeres oder verdrehtes Fenster gibt den ganzen Tag zurück. Eine Auswahl von null
    /// Breite entsteht bei jedem Tippen auf das Diagramm, und ein Bild ohne Punkte wäre darauf
    /// die falsche Antwort.
    public func ausschnitt(von: Double, bis: Double) -> Pruefkurve {
        let a = max(min(von, bis), fenster.lowerBound)
        let b = min(max(von, bis), fenster.upperBound)
        guard b > a else { return self }
        var k = self
        func schneide(_ punkte: [Kurvenpunkt]) -> [Kurvenpunkt] {
            punkte.filter { $0.stunde >= a && $0.stunde <= b }
        }
        k.pv = schneide(pv)
        k.haus = schneide(haus)
        k.netz = schneide(netz)
        k.netzZaehler = schneide(netzZaehler)
        k.speicher = schneide(speicher)
        k.ladestand = schneide(ladestand)
        k.fenster = a...b
        k.leistungsspanne = Self.spanne(k.leistungsreihen)
        return k
    }

    /// Dieselbe Kurve, auf ein gröberes Raster gemittelt.
    ///
    /// **Wozu.** 1440 Minuten mal sechs Reihen sind 8640 Marken in einem Bild; am Telefon ist
    /// das zu spüren. Über den ganzen Tag gezeichnet ist die einzelne Minute ohnehin weniger
    /// als ein Bildpunkt - gemittelt wird, solange kein Fenster gewählt ist, und im Fenster
    /// zeichnet die Ansicht die volle Auflösung.
    ///
    /// Gemittelt, nicht jeder n-te Punkt: ein Nadelstich von 6 kW über eine Minute soll als
    /// gemittelte Spitze stehen bleiben und nicht davon abhängen, ob er auf eine gerade Minute
    /// fiel.
    public func verdichtet(schrittMin: Int) -> Pruefkurve {
        guard schrittMin > 1 else { return self }
        var k = self
        k.pv = Self.verdichte(pv, schrittMin: schrittMin)
        k.haus = Self.verdichte(haus, schrittMin: schrittMin)
        k.netz = Self.verdichte(netz, schrittMin: schrittMin)
        k.netzZaehler = Self.verdichte(netzZaehler, schrittMin: schrittMin)
        k.speicher = Self.verdichte(speicher, schrittMin: schrittMin)
        k.ladestand = Self.verdichte(ladestand, schrittMin: schrittMin)
        k.leistungsspanne = Self.spanne(k.leistungsreihen)
        return k
    }

    /// Eine Reihe auf ein gröberes Raster mitteln. Die Reihe bleibt aufsteigend.
    public static func verdichte(_ punkte: [Kurvenpunkt], schrittMin: Int) -> [Kurvenpunkt] {
        guard schrittMin > 1, !punkte.isEmpty else { return punkte }
        var summe: [Int: (wert: Double, anzahl: Int)] = [:]
        for p in punkte where p.wert.isFinite {
            // Über die Minute gerechnet und nicht über den Bruch `stunde / breite`: die
            // zwanzigste Minute ist als Stunde 0,3333… und ergibt geteilt durch 0,08333… die
            // Zahl 3,9999999999999996 - abgerundet landete sie im Kasten davor.
            let minute = max(0, Int((p.stunde * 60).rounded()))
            let kasten = minute / schrittMin
            let bisher = summe[kasten] ?? (0, 0)
            summe[kasten] = (bisher.wert + p.wert, bisher.anzahl + 1)
        }
        return summe.keys.sorted().map { kasten in
            let s = summe[kasten] ?? (0, 1)
            return Kurvenpunkt(
                stunde: Double(kasten * schrittMin) / 60,
                wert: s.wert / Double(max(1, s.anzahl)))
        }
    }

    /// Eine Reihe in zusammenhängende Strecken zerlegen.
    ///
    /// **Das ist `connectNulls: false` der Vorlage.** Eine fehlende Minute ist in `Kurvenpunkt`
    /// kein Punkt mit dem Wert `nil`, sondern gar kein Punkt - und Swift Charts verbindet, was
    /// da ist. Über eine Lücke von zwanzig Minuten entstünde so eine gerade Linie, die aussieht
    /// wie eine Messung und keine ist. Jede Strecke wird darum als eigene Reihe gezeichnet.
    ///
    /// Der Zähler ist davon ausgenommen (`Reihe.verbunden`): er meldet selten, und seine
    /// Lücken sind sein Takt und kein Ausfall.
    public static func strecken(
        _ punkte: [Kurvenpunkt], hoechstabstand: Double = Pruefkurve.lueckenabstand
    ) -> [[Kurvenpunkt]] {
        var aus: [[Kurvenpunkt]] = []
        var laufend: [Kurvenpunkt] = []
        for p in punkte {
            if let vorher = laufend.last, p.stunde - vorher.stunde > hoechstabstand {
                aus.append(laufend)
                laufend = []
            }
            laufend.append(p)
        }
        if !laufend.isEmpty { aus.append(laufend) }
        return aus
    }

    // MARK: - Die Lücke in der Erzeugungsreihe

    /// Was zwischen der ersten und der letzten Minute mit Erzeugung an Nullen steht.
    ///
    /// **Warum diese Zahl auf dieser Seite steht.** Eine Erzeugungsreihe, die mitten am Tag auf
    /// genau 0,00 kW fällt, sieht aus wie eine Wolke. Bewegt sich der Netzwert in derselben
    /// Strecke weiter, war es keine: dann liefert der Zähler, die Erzeugungsmessung aber nicht -
    /// und eine ausgewiesene Netzladung des Speichers ist eine Folge der Lücke und kein
    /// Verhalten des Geräts (`DataCheck.tsx:141-147`).
    ///
    /// **Was das nicht ist:** keine Aussage über den Ausfall einer Quelle. Dafür ist das
    /// Abdeckungsraster da; hier wird nur ein Tag und nur eine Reihe befragt.
    public struct Erzeugungsluecke: Sendable, Hashable {
        /// Die erste Stunde mit Erzeugung.
        public let von: Double
        /// Die letzte Stunde mit Erzeugung.
        public let bis: Double
        /// Punkte auf genau 0,00 kW dazwischen - im Minutenraster sind das Minuten.
        public let minuten: Int
        /// Hat sich der Netzwert in derselben Strecke weiterbewegt?
        public let netzBewegtSich: Bool

        public init(von: Double, bis: Double, minuten: Int, netzBewegtSich: Bool) {
            self.von = von
            self.bis = bis
            self.minuten = minuten
            self.netzBewegtSich = netzBewegtSich
        }

        /// Was daraus zu schließen ist. Die Ansicht wählt danach ihren Satz.
        public enum Befund: String, Sendable, Hashable {
            /// Keine Null in der Strecke - nichts zu melden.
            case keine
            /// Nullen, aber auch das Netz steht still. Kann eine Wolke gewesen sein.
            case luecke
            /// Nullen, während der Netzwert weiterläuft. Die Erzeugungsmessung fehlt.
            case lueckeMitNetzbewegung
        }

        public var befund: Befund {
            guard minuten > 0 else { return .keine }
            return netzBewegtSich ? .lueckeMitNetzbewegung : .luecke
        }
    }

    /// Die Lücke der Erzeugungsreihe, oder `nil`, wenn der Tag keine Strecke mit Erzeugung hat.
    ///
    /// Eine einzige Minute mit Erzeugung ist keine Strecke: zwischen ihr und sich selbst liegt
    /// nichts, und eine Nacht ohne Sonne ist keine Lücke, sondern eine Nacht.
    public func luecken() -> Erzeugungsluecke? {
        let erzeugend = pv.filter { abs($0.wert) > Self.nullschwelle }
        guard let erste = erzeugend.first?.stunde, let letzte = erzeugend.last?.stunde,
            erste < letzte
        else { return nil }
        let minuten = pv.filter {
            $0.stunde >= erste && $0.stunde <= letzte && abs($0.wert) <= Self.nullschwelle
        }.count
        let netzwerte = netz.filter { $0.stunde >= erste && $0.stunde <= letzte }.map(\.wert)
        let bewegt: Bool
        if let tief = netzwerte.min(), let hoch = netzwerte.max() {
            bewegt = hoch - tief > Self.netzRegung
        } else {
            bewegt = false
        }
        return Erzeugungsluecke(
            von: erste, bis: letzte, minuten: minuten, netzBewegtSich: bewegt)
    }
}

// =====================================================================================
//  Quellen
// =====================================================================================

/// Liefert gerade, was liefern soll? - die Zeilen der Quellenkarte.
///
/// **Warum die Übersetzungstabelle im Kern steht.** Der Dienst nennt seine Quellen
/// `bridge`, `myenergi`, `inexogy`. Das sind Namen von Schnittstellen, nicht von Geräten im
/// Haus; wer vor der Anlage steht, kennt den Zähler und die Wallbox. Die Tabelle der Vorlage
/// (`Sources.tsx:31-35`) stand in der App nirgends. Hier ist sie prüfbar - und ein Name, den
/// sie nicht kennt, bleibt stehen, wie er ist: eine neue Quelle soll auftauchen und nicht
/// verschwinden.
///
/// **Die erste Zeile ist keine Quelle.** Sie ist eine Vollmacht: stellt diese Anlage den
/// Kontakt der Wärmepumpe selbst, oder liest sie ihn nur mit? Sie steht oben, weil jede andere
/// Zahl dieser Seite anders zu lesen ist, je nachdem wie sie ausfällt.
///
/// **Was das nicht ist:** keine Aussage darüber, ob die Werte stimmen. Eine Quelle, die
/// antwortet und seit einer Stunde denselben Wert liefert, steht hier auf `ok`. Darum nennt
/// jede Zeile den Satz des Dienstes mit - er kennt das Alter des letzten Messwerts.
public enum Quellenstand {

    /// Wie eine Zeile dasteht. Die Ansicht setzt die Farbe ein (`Dot.tsx:1-4`).
    public enum Ton: String, Sendable, Hashable {
        /// Antwortet. In der Vorlage `ok`.
        case ok
        /// Antwortet nicht. In der Vorlage `alert`.
        case alarm
        /// Gibt es, tut aber nichts - die Vollmacht, die nicht erteilt ist. Vorlage `muted`.
        case still
    }

    /// Eine Zeile der Quellenkarte.
    public struct Quellenzeile: Sendable, Hashable, Identifiable {
        public let ton: Ton
        public let name: String
        /// Der fertige Satz des Dienstes. Die Oberfläche rechnet nichts nach.
        public let satz: String

        public var id: String { name }

        public init(ton: Ton, name: String, satz: String) {
            self.ton = ton
            self.name = name
            self.satz = satz
        }
    }

    /// Die Namen der Geräte hinter den Schnittstellennamen (`Sources.tsx:31-35`).
    public static let namen: [String: String] = [
        "bridge": "Haus (Bridge)",
        "myenergi": "myenergi (Libbi, Wallbox)",
        "inexogy": "Zähler (inexogy)",
    ]

    /// Der Name einer Quelle. Ein unbekannter bleibt, wie er ist.
    public static func name(_ roh: String) -> String {
        namen[roh] ?? roh
    }

    /// Die Überschrift der Vollmachtszeile.
    public static let vollmacht = "Anforderung an die Wärmepumpe"
    /// Was dahinter steht, wenn die Anlage schaltet (`Sources.tsx:63-64`).
    public static let schaltetSatz =
        "zwei Sicherungen liegen im Haus: das Relais schaltet von selbst ab, und Home Assistant wacht darüber"
    /// Und was, wenn nicht.
    public static let schaltetNichtSatz = "der Regler entscheidet, geschaltet wird nichts"
    /// Womit die Vorlage zwei Sätze in einer Zeile trennt.
    public static let trenner = " · "
    /// Der Satz, wenn der Zustand nicht abrufbar ist (`Sources.tsx:50`).
    public static let nichtAbrufbar = "Der Zustand der Quellen ist gerade nicht abrufbar."

    /// Die Zeilen der Karte: zuerst die Vollmacht, dann je Quelle eine.
    ///
    /// Ohne Zustand gibt es keine Zeilen - auch keine Vollmachtszeile. „Es wird nichts
    /// geschaltet" wäre ohne Antwort des Dienstes eine Behauptung und keine Auskunft.
    public static func zeilen(aus system: SystemStatusOut?) -> [Quellenzeile] {
        guard let system else { return [] }
        let schaltet = system.hpActuation == true
        let stuecke = [system.hpActuationDe, schaltet ? schaltetSatz : schaltetNichtSatz]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        var aus = [
            Quellenzeile(
                ton: schaltet ? .ok : .still, name: vollmacht,
                satz: stuecke.joined(separator: trenner))
        ]
        aus += system.sources.map { q in
            Quellenzeile(
                ton: q.online ? .ok : .alarm, name: name(q.name), satz: q.detailDe ?? "")
        }
        return aus
    }
}

// =====================================================================================
//  Verfügbarkeit
// =====================================================================================

/// Kommen die Daten an? - eine Messreihe als Fläche aus Tagen und Stunden.
///
/// **Warum eine Karte und keine Kurve** (`CoverageMap.tsx:12-27`). Die Frage ist nicht, wie
/// hoch die Leistung war, sondern ob überhaupt etwas ankam. In einer Leistungskurve ist das
/// kaum zu sehen: eine Lücke sieht aus wie eine Null, und eine Null sieht aus wie eine Nacht
/// ohne Verbrauch. Als Fläche aus Tagen und Stunden wird ein Muster daraus - eine Verbindung,
/// die jede Nacht abreißt, ist ein waagerechter Streifen; eine, die alle paar Tage für zwei
/// Stunden wegbleibt, ein Fleck. Die App holte diese Zahlen bisher und warf das Stundenraster
/// weg, also genau das, woraus das Muster entsteht.
///
/// **Leer ist nicht null.** Eine Stunde ohne Eintrag heißt, dass es für sie überhaupt keine
/// Minutenzeile gibt - dann stand der Dienst still, und der Ausfall ist unserer. Eine Stunde
/// mit null Minuten heißt, dass Minutenzeilen da sind und diese eine Reihe darin fehlt: dann
/// hat das Gerät nichts geliefert. Der Unterschied entscheidet, wen man anschaut, und darum ist
/// er hier ein `nil` und keine Null.
///
/// **Was das nicht ist:** keine Farbskala. `Abdeckungsstufe` nennt drei Stufen und die
/// Leerstelle; welche Farben das sind, weiß die Ansicht.
public struct Abdeckungsraster: Sendable, Hashable, Identifiable {

    /// Ein Tag der Karte: 24 Stunden mit ihrer Minutenzahl oder `nil`.
    public struct Rastertag: Sendable, Hashable, Identifiable {
        /// Der Kalendertag, `2026-11-10`.
        public let tag: String
        /// 24 Einträge, von 0 bis 23 Uhr. `nil` heißt: keine Minutenzeile für diese Stunde.
        public let stunden: [Int?]

        public var id: String { tag }

        public init(tag: String, stunden: [Int?]) {
            self.tag = tag
            self.stunden = stunden
        }
    }

    /// Wie voll eine Stunde ist - die drei Stufen der Rampe und die Leerstelle.
    public enum Abdeckungsstufe: String, Sendable, Hashable, CaseIterable {
        /// Keine Minutenzeile. In der Ansicht die Linienfarbe, keine Rampenfarbe.
        case leer
        /// Fast nichts angekommen. Das rote Ende der Rampe.
        case fehlend
        /// Teils. Die Zwischenstufe muss es geben: eine Stunde mit 55 von 60 Minuten ist etwas
        /// anderes als eine mit 5 (`CoverageMap.tsx:30-32`).
        case teils
        /// Vollständig oder nahe daran. Das ruhige Ende der Rampe.
        case voll
    }

    /// Der Schlüssel der Reihe, wie der Dienst ihn nennt.
    public let schluessel: String
    /// Der Name der Reihe, wie er über der Karte steht.
    public let name: String
    /// Die Tage, aufsteigend - eine Spalte je Tag.
    public let tage: [Rastertag]
    /// Anteil der angekommenen Minuten, 0 bis 1.
    public let abdeckung: Double
    public let unvollstaendigeStunden: Int
    /// Vollständig leere Stunden in Folge. Bewusst eine Untergrenze (siehe `CoverageSeriesOut`).
    public let laengsterAusfallH: Int
    /// Wann der letzte Wert kam.
    public let zuletzt: String?

    public var id: String { schluessel }

    public init(
        schluessel: String, name: String, tage: [Rastertag], abdeckung: Double,
        unvollstaendigeStunden: Int, laengsterAusfallH: Int, zuletzt: String? = nil
    ) {
        self.schluessel = schluessel
        self.name = name
        self.tage = tage
        self.abdeckung = abdeckung
        self.unvollstaendigeStunden = unvollstaendigeStunden
        self.laengsterAusfallH = laengsterAusfallH
        self.zuletzt = zuletzt
    }

    // MARK: - Die Konstanten der Vorlage

    /// Wie viele Minuten eine vollständige Stunde hat - die feste Obergrenze der Skala
    /// (`CoverageMap.tsx:117-123`: `max: 60`). Keine Skala nach dem größten Wert: eine Reihe,
    /// die nie mehr als 40 Minuten je Stunde liefert, sähe sonst vollständig aus.
    public static let minutenJeStunde = 60
    /// Ab hier ist eine Stunde nicht mehr „fehlend", sondern „teils".
    ///
    /// Die Rampe hat drei Stopps: 0, 30 und 60 Minuten. Jede Stunde bekommt die Stufe, deren
    /// Stopp ihr am nächsten liegt - die Grenzen liegen also in der Mitte, bei 15 und 45.
    public static let grenzeTeils = 15
    /// Ab hier ist eine Stunde „voll".
    public static let grenzeVoll = 45
    /// Unter welcher Abdeckung die Kopfzeile Alarm schlägt (`CoverageMap.tsx:67`).
    public static let dringendUnter = 0.99
    /// Ab welcher Abdeckung zwei Nachkommastellen stehen (`CoverageMap.tsx:66`).
    ///
    /// Bei 99,99 Prozent ist die Frage nicht, ob die Reihe vollständig ist, sondern wie viele
    /// Minuten fehlen - und mit einer Stelle stünde dort dieselbe Zahl wie bei 100 Prozent.
    public static let feinAb = 0.999
    /// Was unter der Karte steht, zusätzlich zu `note_de` (`CoverageMap.tsx:146-152`).
    public static let lesehilfe =
        "Eine Zelle ohne Farbe heißt, dass für diese Stunde gar keine Minutenzeile existiert - dann stand der Dienst still, und der Ausfall ist unserer. Eine rote Zelle heißt, dass Minutenzeilen da sind und diese eine Reihe darin fehlt: dann hat das Gerät nichts geliefert."
    /// Der Satz, wenn die Abfrage scheitert (`CoverageMap.tsx:92`).
    public static let nichtAbrufbar = "Die Verfügbarkeit konnte nicht abgefragt werden."

    // MARK: - Bauen

    /// Alle Reihen einer Abdeckungsantwort.
    public static func baue(_ abdeckung: CoverageOut) -> [Abdeckungsraster] {
        let tage = tageZwischen(abdeckung.start, abdeckung.end)
        return abdeckung.series.map { baue($0, tage: tage) }
    }

    /// Eine Reihe auf das Raster der Tage legen.
    public static func baue(_ reihe: CoverageSeriesOut, tage: [String]) -> Abdeckungsraster {
        // Der Schlüssel ist die ersten dreizehn Zeichen des Zeitstempels, `2026-11-10T07`, und
        // es wird mit Text verglichen und nicht mit Zeitpunkten (`CoverageMap.tsx:34-40`). Das
        // ist hier das Richtige: Dienst und Anzeige meinen dieselbe Ortszeit, und ein Umweg
        // über `Date` schöbe das Raster an der Zeitumstellung um eine Stunde.
        var minuten: [String: Int] = [:]
        for paar in reihe.hours {
            guard paar.count >= 2, let iso = paar[0].alsText, let n = paar[1].alsZahl else {
                continue
            }
            minuten[String(iso.prefix(13))] = Int(n)
        }
        let spalten = tage.map { tag in
            Rastertag(
                tag: tag,
                stunden: (0..<24).map { h in minuten[tag + "T" + String(format: "%02d", h)] })
        }
        return Abdeckungsraster(
            schluessel: reihe.key, name: reihe.labelDe, tage: spalten,
            abdeckung: reihe.coverage, unvollstaendigeStunden: reihe.incompleteHours,
            laengsterAusfallH: reihe.longestOutageH, zuletzt: reihe.lastAt)
    }

    /// Die Kalendertage von `start` (einschließlich) bis `end` (ausschließlich).
    ///
    /// Ein Zeitraum ohne Tage gibt eine leere Liste - und damit eine Karte ohne Spalten statt
    /// einer Karte voller Leerstellen.
    public static func tageZwischen(_ start: String, _ ende: String) -> [String] {
        guard let a = Zeit.ausIso(start), let b = Zeit.ausIso(ende) else { return [] }
        let erster = Tag.iso(a)
        guard let anzahl = Tag.abstand(Tag.iso(b), erster), anzahl > 0 else { return [] }
        return (0..<anzahl).map { Tag.plus(erster, $0) }
    }

    /// Welche Stufe eine Stunde hat.
    public static func stufe(minuten: Int?) -> Abdeckungsstufe {
        guard let minuten else { return .leer }
        if minuten < grenzeTeils { return .fehlend }
        if minuten < grenzeVoll { return .teils }
        return .voll
    }

    // MARK: - Die Kopfzeile

    /// Was über der Karte einer Reihe steht (`CoverageMap.tsx:65-80`).
    public struct Kopfzeile: Sendable, Hashable {
        public let name: String
        /// „99,98 % Abdeckung".
        public let abdeckung: String
        /// Unter 99 Prozent: die Zahl steht in der Alarmfarbe und nicht in der ruhigen.
        public let dringend: Bool
        /// Die Angaben dahinter, einzeln.
        ///
        /// **Warum eine Liste und kein Satz.** Der längste Ausfall steht nur da, wenn es einen
        /// gab. Als Zeichenkette gebaut hinge an dieser Bedingung ein Trennzeichen, und genau
        /// dort entstehen die „ · · " der Oberfläche.
        public let stuecke: [String]

        public init(name: String, abdeckung: String, dringend: Bool, stuecke: [String]) {
            self.name = name
            self.abdeckung = abdeckung
            self.dringend = dringend
            self.stuecke = stuecke
        }

        /// Die Stücke, wie die Vorlage sie trennt.
        public var satz: String {
            stuecke.joined(separator: Quellenstand.trenner)
        }
    }

    /// Die Kopfzeile dieser Reihe.
    public func kopfzeile(jetzt: Date) -> Kopfzeile {
        var stuecke = ["\(unvollstaendigeStunden) unvollständige Stunden"]
        if laengsterAusfallH > 0 {
            stuecke.append(
                "längster Ausfall \(laengsterAusfallH)\(Formate.schmalesLeerzeichen)h")
        }
        stuecke.append(Self.alter(lastAt: zuletzt, jetzt: jetzt))
        return Kopfzeile(
            name: name,
            abdeckung: Formate.abdeckung(abdeckung) + " Abdeckung",
            dringend: abdeckung < Self.dringendUnter,
            stuecke: stuecke)
    }

    /// Wie alt der letzte Wert dieser Reihe ist, als Satz (`CoverageMap.tsx:62-69`).
    ///
    /// **Warum nicht `Formate.alter`.** Das schweigt unter dreißig Sekunden, und das ist auf
    /// den Kacheln richtig: solange die Werte kommen, ist das Alter keine Nachricht. Hier ist
    /// es die Nachricht - die Frage der Seite lautet, ob überhaupt etwas ankommt, und darauf
    /// ist „gerade eben" eine Antwort und ein leeres Feld keine. Darum vier Stufen bis in die
    /// Sekunden und ein eigener Satz für „noch nie".
    public static func alter(lastAt: String?, jetzt: Date) -> String {
        guard let lastAt, let d = Zeit.ausIso(lastAt) else { return "noch kein Wert" }
        let s = max(0, jetzt.timeIntervalSince(d))
        if s < 5 { return "letzter Wert gerade eben" }
        let e = Formate.schmalesLeerzeichen
        if s < 120 { return "letzter Wert vor \(Int(s.rounded()))\(e)s" }
        if s < 7200 { return "letzter Wert vor \(Int((s / 60).rounded()))\(e)min" }
        return "letzter Wert vor \(Int((s / 3600).rounded()))\(e)h"
    }
}

extension Formate {
    /// Eine Abdeckung als Prozentzahl: zwei Nachkommastellen über 99,9 Prozent, sonst eine.
    ///
    /// **Warum die Stellenzahl wechselt** (`CoverageMap.tsx:66`). Mit einer Stelle steht bei
    /// 99,99 Prozent dasselbe da wie bei 100 - und der Unterschied ist genau der, um den es auf
    /// dieser Seite geht: vier fehlende Minuten gegen keine. Mit zwei Stellen überall stünde
    /// dagegen bei einer Reihe mit 87 Prozent eine Genauigkeit, die nichts sagt.
    public static func abdeckung(_ anteil: Double?) -> String {
        guard let anteil, anteil.isFinite else { return leer }
        let stellen = anteil > Abdeckungsraster.feinAb ? 2 : 1
        return zahl(anteil * 100, stellen: stellen) + schmalesLeerzeichen + "%"
    }
}
