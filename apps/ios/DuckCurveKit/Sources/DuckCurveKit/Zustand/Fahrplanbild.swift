import Foundation

/// Der Fahrplan als Bild: acht Flächen über einer Zeitachse, fertig gerechnet.
///
/// **Was die App bisher zeigte.** Eine Fläche: ein Band für die geplante Freigabe, darüber den
/// Preis, beides auf 24 Stunden geschnitten. Die Vorlage (`apps/web/src/components/waerme/
/// Fahrplan.tsx`) zeigt acht Flächen über den ganzen Horizont des Planers, also zwei Tage:
/// Preis, PV erwartet **und gemessen**, Wärmebedarf aus Heizen und Warmwasser, den
/// Pufferverlauf mit seiner Reserve, die gemessene Leistung der Wärmepumpe, den geplanten
/// Zustand, die gemessene Anforderung und den Pelletofen. Gemessenes und Geplantes
/// nebeneinander ist der ganze Zweck der Seite; in der App fehlte das Gemessene vollständig.
///
/// **Lücken bleiben Lücken.** Eine Viertelstunde ohne Messung ist `nil` und nicht null Kilowatt.
/// Der Unterschied ist nicht Feinheit: eine Null hieße „die Anlage stand“, und in der Zukunft
/// wäre sie eine Behauptung über morgen. Dasselbe beim Wärmebedarf - eine Null hieße, das Haus
/// brauche dort keine Wärme.
public struct Fahrplanbild: Sendable {

    /// Ein Punkt einer Reihe. `wert` ist `nil`, wo die Reihe eine Lücke hat.
    public struct Punkt: Sendable, Hashable, Identifiable {
        public let zeit: Date
        public let wert: Double?
        public var id: Date { zeit }
    }

    /// Ein Feld eines Streifens: eine Viertelstunde mit Höhe und Rolle.
    public struct Feld: Sendable, Hashable, Identifiable {
        public let zeit: Date
        public let hoehe: Double
        public let rolle: Rolle
        public var id: Date { zeit }
    }

    /// Welche Farbe ein Feld hat - die Ansicht setzt sie ein.
    public enum Rolle: String, Sendable, Hashable {
        case angefordert, gemieden, frei, aus, ofenAn, ofenAus
        case pv, puffer, wpGemessen, heizen, warmwasser, neutral
        /// Was erwartet wird und nicht gemessen ist: die PV-Prognose, die Preisbänder.
        case vorhersage
    }

    /// Die vier Zustände, die `planned_hp_state` kennt, mit Wort und Balkenhöhe.
    ///
    /// **Der Zustand trägt drei Kennzeichen, nicht eines.** Farbe, Höhe und Wort. „Angefordert“
    /// und „gemieden“ liegen farblich bei ΔE 14 und damit knapp unter dem, was zwei Flächen in
    /// einer Zeile sicher unterscheidbar macht; Höhe und Wort schließen die Lücke.
    public static func zustand(_ z: PlanIntervalOutPlannedHpStateWahl) -> (
        wort: String, hoehe: Double, rolle: Rolle
    ) {
        switch z {
        case .release: return ("angefordert", 1, .angefordert)
        case .avoid: return ("gemieden", 0.55, .gemieden)
        case .free: return ("frei", 0.3, .frei)
        case .off, .unbekannt: return ("aus", 0.12, .aus)
        }
    }

    /// Alle vier in der Reihenfolge der Legende.
    public static var zustandslegende: [(wort: String, hoehe: Double, rolle: Rolle)] {
        [.release, .avoid, .free, .off].map(zustand)
    }

    /// Ein Stück der Legende: ein Klotz in seiner Farbe und das Wort dahinter.
    public struct Legendenstueck: Sendable, Hashable, Identifiable {
        public let wort: String
        public let rolle: Rolle
        /// Wie hoch der Klotz ist. Die Vorlage leitet sie aus der Balkenhöhe ab
        /// (`max(3, round(hoehe * 10))`), damit die vier Zustände in der Legende dieselbe
        /// Rangfolge haben wie im Streifen; eine Linie ist drei Punkte hoch, eine Fläche zehn.
        public let dick: Double
        /// Blass wie das Band hinter der Preiskurve, nicht voll wie eine Fläche.
        public let blass: Bool
        /// Ein gestrichelter Strich: so ist im Bild gezeichnet, was geplant oder erwartet und
        /// noch nicht gemessen ist. Die Marke sieht aus wie ihre Linie.
        public let gestrichelt: Bool

        public var id: String { wort }

        public init(
            wort: String, rolle: Rolle, dick: Double, blass: Bool = false, gestrichelt: Bool = false
        ) {
            self.wort = wort
            self.rolle = rolle
            self.dick = dick
            self.blass = blass
            self.gestrichelt = gestrichelt
        }
    }

    /// Die ganze Legende der Vorlage, in ihrer Reihenfolge (`waerme/Fahrplan.tsx:598-640`).
    ///
    /// **Warum im Kern und nicht in der Zeichnung.** Das letzte Stück steht nur da, wenn der
    /// Plan ein negatives Preisfenster kennt - das ist eine Aussage über die Daten und keine
    /// über das Zeichnen. Sie stand in der Ansicht, zusammen mit elf festen Wörtern.
    public var legende: [Legendenstueck] {
        Self.legendenstuecke(negativesFenster: hatNegativesFenster)
    }

    /// Dieselbe Legende aus dem Plan allein, ohne gebautes Bild.
    ///
    /// **Warum es die Fassung gibt.** Ohne Intervalle zeigt die Vorlage die Horizontkarte
    /// weiter - mit dem Satz „Noch kein Fahrplan gerechnet.“ an der Stelle der Zeichnung und
    /// mit der **vollständigen** Legende darunter (`waerme/Fahrplan.tsx:590-640`: Der Satz
    /// steht im `else` des Diagramms, die Legende dahinter und außerhalb). Sie ist dort kein
    /// Beiwerk des Bildes, sondern das Verzeichnis dessen, was das Bild zeigen *würde*. Ohne
    /// Intervalle gibt es kein ``Fahrplanbild``, und ein leeres zu bauen, nur um an die
    /// Legende zu kommen, hieße ein Bild vorzutäuschen.
    public static func legende(_ plan: PlanOut?) -> [Legendenstueck] {
        legendenstuecke(
            negativesFenster: plan?.windows.contains { $0.kind == .negative } ?? false)
    }

    private static func legendenstuecke(negativesFenster: Bool) -> [Legendenstueck] {
        var stuecke = zustandslegende.map {
            Legendenstueck(
                wort: "Wärmepumpe \($0.wort)", rolle: $0.rolle,
                dick: max(3, ($0.hoehe * 10).rounded()))
        }
        stuecke += [
            Legendenstueck(wort: "Ofen brennt", rolle: .ofenAn, dick: 10),
            Legendenstueck(wort: "Heizen", rolle: .heizen, dick: 10),
            Legendenstueck(wort: "Warmwasser", rolle: .warmwasser, dick: 10),
            // Der Bedarf, mit dem der letzte aufbewahrte Fahrplan davor rechnete: blass, damit
            // die Erinnerung nicht aussieht wie der Plan von jetzt.
            Legendenstueck(
                wort: "Wärmebedarf, damals geplant", rolle: .warmwasser, dick: 10, blass: true),
            // **Gemessen gefüllt, geplant gestrichelt**, bei Puffer und Wärmepumpe wie bei der
            // PV (`Fahrplan.tsx`, Legende). Seit dem 27.11.2026 stehen beide Reihen je zweimal
            // im Bild: links der Jetzt-Linie die Messung, rechts der Plan.
            Legendenstueck(wort: "Pufferinhalt gemessen", rolle: .puffer, dick: 10),
            Legendenstueck(wort: "Pufferinhalt geplant", rolle: .puffer, dick: 2, gestrichelt: true),
            Legendenstueck(wort: "Wärmepumpe gemessen, kW", rolle: .wpGemessen, dick: 10),
            Legendenstueck(
                wort: "Wärmepumpe geplant, kW", rolle: .wpGemessen, dick: 2, gestrichelt: true),
            Legendenstueck(wort: "PV gemessen", rolle: .pv, dick: 10),
            Legendenstueck(wort: "PV erwartet", rolle: .vorhersage, dick: 2, gestrichelt: true),
            Legendenstueck(wort: "Preistief", rolle: .vorhersage, dick: 10, blass: true),
        ]
        if negativesFenster {
            stuecke.append(
                Legendenstueck(wort: "negativer Preis", rolle: .gemieden, dick: 10, blass: true))
        }
        return stuecke
    }

    // MARK: - Die Reihen

    public var preis: [Punkt] = []
    public var pvErwartet: [Punkt] = []
    public var pvGemessen: [Punkt] = []
    public var heizen: [Punkt] = []
    public var warmwasser: [Punkt] = []
    /// Heizen **plus** Warmwasser. Zwei Flächen statt eines Stapels: die obere wird zuerst
    /// gezeichnet, die untere darüber. Das sieht aus wie ein Stapel und braucht keine Summe
    /// in der Ansicht - und eine Summe in der Ansicht war schon zweimal die falsche.
    public var waermeSumme: [Punkt] = []
    /// Der geplante Pufferinhalt am Ende jeder Viertelstunde.
    public var puffer: [Punkt] = []
    /// Der gemessene Pufferinhalt am Ende jeder vergangenen Viertelstunde, auf derselben Skala.
    public var pufferGemessen: [Punkt] = []
    /// **Der Plan von damals** für die vergangenen Viertelstunden: was der letzte aufbewahrte
    /// Fahrplan davor vorhatte. Der Wärmebedarf, gegen den er rechnete (Heizen und Warmwasser
    /// zusammen), und der Pufferinhalt, den er erwartete. Der Optimierer rechnet ab jetzt; diese
    /// Erinnerung kommt aus dem Archiv des Dienstes.
    public var waermeDamals: [Punkt] = []
    public var pufferDamals: [Punkt] = []
    public var wpGemessen: [Punkt] = []
    /// Die elektrische Leistung, mit der der Optimierer die Wärmepumpe zählt: ihr Nennwert,
    /// wo er sie laufen lässt, null, wo nicht. Eine Lücke, wo er nicht geplant hat.
    public var wpGeplant: [Punkt] = []
    /// Dieselbe Zahl aus dem Fahrplan von damals, für die vergangenen Viertelstunden. Eine
    /// Lücke, wo damals die Preisregel führte oder kein Fahrplan aufbewahrt ist.
    public var wpDamals: [Punkt] = []
    public var zustandsstreifen: [Feld] = []
    public var anforderung: [Feld] = []
    public var ofenstreifen: [Feld] = []

    /// Die Preisfenster hinter der Preiskurve - nur billig und negativ; teuer ist der Normalfall.
    public var baender: [(von: Date, bis: Date, negativ: Bool)] = []

    // MARK: - Die Achsen

    public var horizont: ClosedRange<Date>?
    /// Untergrenzen der gestauchten Achsen; `nil` heißt: die Achse beginnt bei null.
    public var preisUnten: Double?
    public var waermeUnten: Double?
    public var pufferDecke: Double?
    public var pufferReserve: Double?

    // MARK: - Was es überhaupt gibt

    public var hatMessung = false
    public var hatWpMessung = false
    /// Der Optimierer nennt für mindestens eine Viertelstunde eine Leistung der Wärmepumpe.
    public var hatWpPlan = false
    public var hatAnforderung = false
    public var hatWaerme = false
    public var hatPuffer = false
    public var hatOfenfahrplan = false
    public var hatNegativesFenster = false

    // MARK: - Bauen

    public static func baue(_ plan: PlanOut) -> Fahrplanbild {
        var b = Fahrplanbild()
        let iv = plan.intervals.compactMap { i -> (PlanIntervalOut, Date)? in
            guard let t = Zeit.ausIso(i.ts) else { return nil }
            return (i, t)
        }
        guard !iv.isEmpty else { return b }

        b.preis = iv.filter { $0.0.priceCtKwh != nil }.map { Punkt(zeit: $0.1, wert: $0.0.priceCtKwh) }
        b.pvErwartet = iv.map { Punkt(zeit: $0.1, wert: $0.0.expectedPvKw) }
        b.pvGemessen = iv.map { Punkt(zeit: $0.1, wert: $0.0.actualPvKw) }
        b.heizen = iv.map { Punkt(zeit: $0.1, wert: $0.0.heatDemandKw) }
        b.warmwasser = iv.map { Punkt(zeit: $0.1, wert: $0.0.dhwDemandKw) }
        b.waermeSumme = iv.map { i, t in
            guard let h = i.heatDemandKw else { return Punkt(zeit: t, wert: nil) }
            return Punkt(zeit: t, wert: h + (i.dhwDemandKw ?? 0))
        }
        b.puffer = iv.map { Punkt(zeit: $0.1, wert: $0.0.bufferKwh) }
        b.pufferGemessen = iv.map { Punkt(zeit: $0.1, wert: $0.0.actualBufferKwh) }
        b.waermeDamals = iv.map { Punkt(zeit: $0.1, wert: $0.0.pastPlanHeatKw) }
        b.pufferDamals = iv.map { Punkt(zeit: $0.1, wert: $0.0.pastPlanBufferKwh) }
        b.wpGemessen = iv.map { Punkt(zeit: $0.1, wert: $0.0.actualHpKw) }
        b.wpGeplant = iv.map { Punkt(zeit: $0.1, wert: $0.0.plannedHpKw) }
        b.wpDamals = iv.map { Punkt(zeit: $0.1, wert: $0.0.pastPlanHpKw) }

        // **Links der Jetzt-Linie die Absicht von damals**, rechts der Fahrplan von jetzt; die
        // Regel und ihr Grund stehen an ``absicht(_:zeit:laufende:)``. Der Fahrplan von damals
        // kennt nur Ja und Nein: Ja sieht aus wie „angefordert“, Nein wie „aus“. Wo das Archiv
        // nichts weiß, bleibt die Stelle leer, so wie eine fehlende Messung im Streifen
        // darunter eine Lücke lässt.
        let laufende = laufendeViertelstunde(plan)
        b.zustandsstreifen = iv.compactMap { i, t in
            switch absicht(i, zeit: t, laufende: laufende) {
            case .jetzt(let wahl):
                let z = zustand(wahl)
                return Feld(zeit: t, hoehe: z.hoehe, rolle: z.rolle)
            case .damals(let freigabe):
                return Feld(
                    zeit: t, hoehe: freigabe ? 1 : 0.12, rolle: freigabe ? .angefordert : .aus)
            case .ohne:
                return nil
            }
        }
        // Nur Viertelstunden mit Messung. Eine fehlende hinterlässt eine Lücke, und das ist
        // richtig: „nicht angefordert“ und „nicht gemessen“ sind zwei verschiedene Aussagen.
        b.anforderung = iv.compactMap { i, t in
            guard let an = i.actualHpRelease else { return nil }
            return Feld(zeit: t, hoehe: an ? 1 : 0.12, rolle: an ? .angefordert : .aus)
        }
        b.ofenstreifen = iv.compactMap { i, t in
            guard let an = i.plannedStoveOn else { return nil }
            return Feld(zeit: t, hoehe: an ? 1 : 0.12, rolle: an ? .ofenAn : .ofenAus)
        }

        b.baender = plan.windows.compactMap { w in
            guard w.kind == .cheap || w.kind == .negative,
                let von = Zeit.ausIso(w.start), let bis = Zeit.ausIso(w.end)
            else { return nil }
            return (von, bis, w.kind == .negative)
        }
        b.hatNegativesFenster = plan.windows.contains { $0.kind == .negative }

        if let von = Zeit.ausIso(plan.horizonStart), let bis = Zeit.ausIso(plan.horizonEnd),
            von < bis
        {
            b.horizont = von...bis
        } else if let erste = iv.first?.1, let letzte = iv.last?.1, erste < letzte {
            b.horizont = erste...letzte
        }

        // 5 ct und 0,5 kW: die Stufen, in denen man diese beiden Größen ohnehin denkt.
        b.preisUnten = untergrenze(iv.compactMap { $0.0.priceCtKwh }, stufe: 5)
        // Beim Wärmebedarf zählt die **Summe** aus beiden Reihen, denn gestapelt bildet sie oben
        // die Kurve. Dass die untere dabei am Rand beschnitten wird, ist der Preis der Stauchung.
        b.waermeUnten = untergrenze(
            iv.filter { $0.0.heatDemandKw != nil }
                .map { ($0.0.heatDemandKw ?? 0) + ($0.0.dhwDemandKw ?? 0) }
                + iv.compactMap { $0.0.pastPlanHeatKw }, stufe: 0.5)
        b.pufferDecke = plan.bufferCapacityKwh
        b.pufferReserve = plan.bufferMinKwh

        b.hatMessung = iv.contains { $0.0.actualPvKw != nil || $0.0.actualHpKw != nil }
        b.hatWpMessung = iv.contains { $0.0.actualHpKw != nil }
        b.hatWpPlan = iv.contains { $0.0.plannedHpKw != nil || $0.0.pastPlanHpKw != nil }
        b.hatAnforderung = !b.anforderung.isEmpty
        b.hatWaerme = iv.contains { $0.0.heatDemandKw != nil || $0.0.pastPlanHeatKw != nil }
        // Gemessen oder geplant: der Streifen ist erst leer, wenn beides fehlt.
        b.hatPuffer = iv.contains {
            $0.0.bufferKwh != nil || $0.0.actualBufferKwh != nil || $0.0.pastPlanBufferKwh != nil
        }
        b.hatOfenfahrplan = !b.ofenstreifen.isEmpty
        return b
    }

    // MARK: - Die Absicht der Wärmepumpe

    /// Was der Streifen „Wärmepumpe geplant“ für eine Viertelstunde zeigt.
    ///
    /// `jetzt`: der laufende Fahrplan mit seinen vier Zuständen. `damals`: der Fahrplan von
    /// damals, der nur Ja oder Nein kennt, weil das Archiv „gemieden“ und „aus“ als dasselbe
    /// Nein ablegt. `ohne`: Der Fahrplan von damals gab nichts vor, oder es ist keiner
    /// aufbewahrt. Beides sieht im Archiv gleich aus, und im Streifen bleibt die Stelle leer.
    public enum Absicht: Sendable, Hashable {
        case jetzt(PlanIntervalOutPlannedHpStateWahl)
        case damals(freigabe: Bool)
        case ohne
    }

    /// Der Beginn der Viertelstunde, in der der Fahrplan gerechnet wurde. Davor liegt seine
    /// Vergangenheit: Der Dienst fragt das Archiv genau für diese Viertelstunden.
    public static func laufendeViertelstunde(_ plan: PlanOut) -> Date? {
        guard let gerechnet = Zeit.ausIso(plan.createdAt) else { return nil }
        let viertel = 15.0 * 60
        return Date(
            timeIntervalSince1970: (gerechnet.timeIntervalSince1970 / viertel).rounded(.down)
                * viertel)
    }

    /// **Warum es das gibt.** Der Optimierer rechnet ab jetzt. Für die Viertelstunden davor
    /// griff im Dienst die Preisregel, und sie antwortet mit den Fenstern von heute. Der
    /// Streifen zeigte links der Jetzt-Linie also nicht, was man vorhatte, als man in die
    /// Stunde hineinging, sondern was die Regel heute über sie sagen würde. Seit dem
    /// 27.11.2026 liefert der Dienst die Absicht des Fahrplans von damals aus dem Archiv
    /// (`past_plan_hp_release`), und die vergangenen Viertelstunden werden daraus gezeichnet.
    ///
    /// Dieselbe Regel steht im Dashboard in `fahrplanband.ts`. Ohne lesbaren Zeitpunkt des
    /// Fahrplans gilt jede Viertelstunde als die von jetzt, wie vor dieser Änderung.
    public static func absicht(_ i: PlanIntervalOut, zeit: Date, laufende: Date?) -> Absicht {
        guard let laufende, zeit < laufende else { return .jetzt(i.plannedHpState) }
        guard let freigabe = i.pastPlanHpRelease else { return .ohne }
        return .damals(freigabe: freigabe)
    }

    /// Das Wort zur Absicht von damals, für die Auskunft zur Viertelstunde.
    public static func damalsWort(_ absicht: Absicht) -> String? {
        switch absicht {
        case .jetzt: return nil
        case .ohne: return "ohne Vorgabe"
        case .damals(let freigabe): return freigabe ? "angefordert" : "nicht angefordert"
        }
    }

    /// Wie viele der gemessenen Viertelstunden der Fahrplan von damals freigegeben hatte.
    ///
    /// `nil`, wenn das Archiv für keine von ihnen etwas weiß: Dann gibt es keinen Vergleich,
    /// und null Stunden wären eine Behauptung.
    public static func damalsFreigegeben(_ gemessen: [PlanIntervalOut]) -> Int? {
        let bekannt = gemessen.compactMap(\.pastPlanHpRelease)
        guard !bekannt.isEmpty else { return nil }
        return bekannt.filter { $0 }.count
    }

    /// Die Untergrenze einer Achse: der kleinste Wert, abgerundet auf eine runde Stufe.
    ///
    /// **Warum nicht null.** Die Regel „Flächen beginnen bei null“ gilt, wo die Fläche die Menge
    /// bedeutet. Der Strompreis bedeutet keine Menge, sondern einen Stand, und sein Tagesgang
    /// spielt sich zwischen 20 und 50 ct ab; von null aus gesehen ist das eine flache Welle in
    /// der oberen Hälfte. Dasselbe beim Wärmebedarf zwischen 1,5 und 4 kW.
    ///
    /// Abgerundet und nicht genau auf das Minimum: sonst klebt die tiefste Stelle auf der Achse.
    public static func untergrenze(_ werte: [Double], stufe: Double) -> Double? {
        let da = werte.filter { $0.isFinite }
        guard let klein = da.min(), let gross = da.max(), stufe > 0 else { return nil }
        let unten = (klein / stufe).rounded(.down) * stufe
        // Eine Reihe ohne Schwankung bekäme sonst min == max und damit gar keine Achse.
        return unten == gross ? unten - stufe : unten
    }

    // MARK: - Die Auskunft zu einer Viertelstunde

    /// Eine Zeile der Auskunft.
    public struct Auskunftszeile: Sendable, Hashable, Identifiable {
        public let wort: String
        public let wert: String
        public let rolle: Rolle
        /// Eingerückt: ein Satz, der die Zeile darüber erklärt, keine eigene Größe.
        public let eingerueckt: Bool
        public var id: String { wort + "|" + wert }
    }

    /// Alles, was zu einer Viertelstunde im Plan steht.
    public struct Auskunft: Sendable, Hashable {
        public let zeit: Date
        public let titel: String
        public let zeilen: [Auskunftszeile]
        /// Der Satz des Planers zu dieser Viertelstunde.
        public let satz: String?
    }

    /// Die Auskunft zu der Viertelstunde, in die `zeit` fällt.
    ///
    /// **Warum es die gibt.** Das Dashboard zeigt all das in einem Hinweisfenster unter dem
    /// Zeiger. Am Telefon gibt es kein Darüberfahren, und ohne diese Auskunft stünden die
    /// Außentemperatur, die Arbeitszahl, der Prognosefehler der Sonne und die Zerlegung des
    /// Wärmebedarfs in Heizen und Warmwasser nirgends in der App.
    public static func auskunft(_ plan: PlanOut, zeit: Date, jetzt: Date) -> Auskunft? {
        let naechstes = plan.intervals.compactMap { i -> (PlanIntervalOut, Date)? in
            guard let t = Zeit.ausIso(i.ts) else { return nil }
            return (i, t)
        }
        // Die Viertelstunde, die zuletzt begonnen hat: ein Zeiger um 00:20 meint die, die
        // 00:15 begann, und nicht die naechste.
        .filter { $0.1 <= zeit }
        .max { $0.1 < $1.1 }
        guard let (i, t) = naechstes else { return nil }

        var z: [Auskunftszeile] = []
        func zeile(_ wort: String, _ wert: String, _ rolle: Rolle = .neutral, eingerueckt: Bool = false) {
            z.append(
                Auskunftszeile(wort: wort, wert: wert, rolle: rolle, eingerueckt: eingerueckt))
        }

        // **„18,4 ct“ ohne Nenner** (`Fahrplan.tsx:328`: `${de(i.price_ct_kwh, 1)} ct`). Den
        // Nenner trägt der Flächentitel „Strompreis · ct/kWh“, und im Auskunftsfeld ist er
        // dasselbe noch einmal.
        zeile("Strompreis", Formate.ctKurz(i.priceCtKwh))
        zeile("PV erwartet", Formate.kwMitEinheit(i.expectedPvKw))
        if let ist = i.actualPvKw {
            zeile("PV gemessen", Formate.kwMitEinheit(ist), .pv)
            // Vorzeichen ausgeschrieben: „+0,4“ liest sich als Zahl, „0,4 mehr als erwartet“
            // als Aussage, und darum geht es in dieser Zeile.
            let ab = ist - i.expectedPvKw
            let wort =
                abs(ab) < 0.05
                ? "wie erwartet"
                : "\(Formate.kwMitEinheit(abs(ab))) \(ab > 0 ? "mehr" : "weniger") als erwartet"
            zeile("", wort, .neutral, eingerueckt: true)
        }
        if let heizen = i.heatDemandKw {
            let warm = i.dhwDemandKw ?? 0
            zeile("Wärmebedarf", Formate.kwMitEinheit(heizen + warm))
            // Zwei Zeilen und nicht eine: so traegt jede Zahl ihre eigene Farbe, wie die beiden
            // Flaechen des Stapels darueber. In einer Zeile waere eine der beiden falsch gefaerbt.
            zeile("Heizen", Formate.kwMitEinheit(heizen), .heizen, eingerueckt: true)
            zeile("Warmwasser", Formate.kwMitEinheit(warm), .warmwasser, eingerueckt: true)
        }
        if let damals = i.pastPlanHeatKw {
            zeile("Wärmebedarf, damals geplant", Formate.kwMitEinheit(damals))
        }
        if let puffer = i.bufferKwh {
            zeile("Puffer danach, geplant", Formate.kwh(puffer), .puffer)
        }
        if let damals = i.pastPlanBufferKwh {
            zeile("Puffer danach, damals geplant", Formate.kwh(damals), .puffer)
        }
        if let puffer = i.actualBufferKwh {
            zeile("Puffer danach, gemessen", Formate.kwh(puffer), .puffer)
        }
        if let aussen = i.outdoorTempC {
            let cop = i.cop.map { " · COP \(Formate.zahl($0, stellen: 2))" } ?? ""
            zeile("Außen", Formate.celsius(aussen, stellen: 1) + cop)
        }
        // Links der Jetzt-Linie die Absicht von damals, rechts der Fahrplan von jetzt.
        let damals = damalsWort(absicht(i, zeit: t, laufende: laufendeViertelstunde(plan)))
        if let damals {
            zeile(
                "Wärmepumpe, damals geplant", damals,
                i.pastPlanHpRelease == true ? .angefordert : .neutral)
        } else {
            let zustand = zustand(i.plannedHpState)
            zeile("Wärmepumpe geplant", zustand.wort, zustand.rolle)
        }
        // Womit der Optimierer sie in dieser Viertelstunde zählt. Nur wo er sie laufen lässt:
        // „mit 0,0 kW gezählt“ unter „aus“ sagt nichts.
        if let kw = damals == nil ? i.plannedHpKw : i.pastPlanHpKw, kw > 0 {
            zeile("", "mit \(Formate.zahl(kw, stellen: 1)) kW gezählt", .wpGemessen, eingerueckt: true)
        }
        if let an = i.actualHpRelease {
            zeile("Anforderung gemessen", an ? "ja" : "nein", an ? .angefordert : .neutral)
        }
        if let kw = i.actualHpKw {
            zeile("Wärmepumpe gemessen", "\(Formate.zahl(kw, stellen: 2)) kW", .wpGemessen)
        }
        zeile(
            "Pelletofen",
            i.plannedStoveOn == nil ? "kein Fahrplan" : (i.plannedStoveOn == true ? "brennt" : "aus"),
            i.plannedStoveOn == true ? .ofenAn : .neutral)

        return Auskunft(
            zeit: t, titel: Formate.tagUndUhr(t, jetzt: jetzt), zeilen: z, satz: i.noteDe)
    }

    /// Die Spanne einer gestauchten Fläche: von der Untergrenze bis zum größten Wert.
    public static func spanne(_ unten: Double?, bis werte: [Double?]) -> ClosedRange<Double>? {
        let da = werte.compactMap { $0 }.filter { $0.isFinite }
        guard let gross = da.max() else { return nil }
        let von = unten ?? 0
        return von < gross ? von...gross : von...(von + 1)
    }
}
