import Foundation

/// Die Nachbetrachtung eines Ortstages als Bild: die Kostentreppe, der Tagesvergleich und die
/// Zahlentabelle - alles, was sich daran rechnen lässt, ohne zu zeichnen.
///
/// **Warum im Kern und nicht in der Ansicht.** Drei Darstellungen derselben Antwort teilen
/// dieselben Entscheidungen: wo eine Treppenstufe beginnt, welche Linie überhaupt eine Zeile
/// bekommt, welche Farbe und Strichart sie trägt, und wie eine Viertelstunde zu einer von vier
/// Helligkeiten wird. Die Vorlage hält das genauso getrennt und begründet es im Kopf der Datei:
/// „Alle Euro kommen fertig vom Server, die Sätze auch. Hier steht, wie daraus die Treppe wird“
/// (`apps/web/src/components/waerme/nachbetrachtung.ts:1-6`). In einer `View` läge es dreimal
/// und wäre kein einziges Mal geprüft - und geprüft werden muss es, denn eine Stufe, die um
/// zwanzig Cent verrutscht ist, sieht genauso plausibel aus wie eine richtige.
///
/// **Eine fehlende Stufe wird nicht als Null gezeichnet.** Das ist die Regel, an der die ganze
/// Treppe hängt (`nachbetrachtung.ts:29-36`): „eine Stufe ohne Höhe hieße ‚kein Fehler‘, und das
/// ist etwas anderes als ‚unbekannt‘“. Darum entsteht eine Zeile nur aus einem Abstand, der
/// einen Betrag hat, und die Treppe beginnt bei der Linie, auf die der erste vorhandene Abstand
/// zeigt.
public enum Nachbetrachtungsbild {

    // MARK: - Der Tag aus der Adresse

    /// Welchen Tag der Rückblick zeigt, wenn er unter einer Adresse mit `?day=…` aufgeht.
    ///
    /// **Der Tag gehört in die Adresse und nicht allein in den Zustand der Seite.** Die Vorlage
    /// liest ihn dort (`Nachbetrachtung.tsx:45-50`), und die Wärmeseite hängt ihn an ihren
    /// Verweis (`HeatOverview.tsx:268`: `/waerme/nachbetrachtung?day=${anchor}`). Stand der Tag
    /// nur im `@State` der Rückblickseite, landete wer am 10.11. auf „Fahrplan gegen
    /// Wirklichkeit“ tippt im Rückblick vom 9.11. - oder auf dem Tag, den die Seite zuletzt
    /// gehalten hat.
    ///
    /// **Gerechnet wird hier und nicht in der Ansicht** - dieselben zwei Bedingungen wie in der
    /// Vorlage (`Nachbetrachtung.tsx:50`) und derselbe Rückfall: ein echter Kalendertag, nicht
    /// nach heute, sonst gestern. „Der heutige Tag ist nie zu Ende, und die Frage ‚was hat es
    /// gekostet‘ meint meist einen abgeschlossenen“ (`Nachbetrachtung.tsx:47-48`).
    ///
    /// Unbekannte Felder werden übergangen und ein doppeltes `day` vom letzten Vorkommen
    /// überschrieben - wie in ``Wiedergabeziel/ausWeg(_:)``, und wie es jede Adressleiste macht.
    public static func tag(ausWeg weg: String, heute: String) -> String {
        let gestern = Tag.plus(heute, -1)
        let stuecke = weg.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard stuecke.count == 2 else { return gestern }
        var gefunden: String?
        for paar in stuecke[1].split(separator: "&") {
            let kv = paar.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2, kv[0] == "day" else { continue }
            gefunden = String(kv[1])
        }
        guard let tag = gefunden, Tag.istTag(tag), tag <= heute else { return gestern }
        return tag
    }

    // MARK: - Die Kostentreppe

    /// Was eine Treppenzeile ist: ein Stand, ein Schritt dazwischen, oder ein Vergleich daneben.
    ///
    /// `summe` steht auf dem Boden (`von == 0`), `stufe` schwebt von Stand zu Stand, `bezug`
    /// steht neben dem Weg und gehört nicht zu ihm (`nachbetrachtung.ts:16-18`).
    public enum Stufenart: String, Sendable, Hashable {
        case summe, stufe, bezug
    }

    /// Eine Zeile der Treppe. `von` und `bis` sind Euro auf der gemeinsamen Achse.
    public struct Stufe: Sendable, Hashable, Identifiable {
        public let key: String
        public let name: String
        public let art: Stufenart
        public let von: Double
        public let bis: Double
        /// Der Betrag der Zeile: bei einer Summe ihr Stand, bei einer Stufe ihre Änderung.
        public let eur: Double
        public let geschaetzt: Bool
        public let satz: String

        public var id: String { key }

        public init(
            key: String, name: String, art: Stufenart, von: Double, bis: Double, eur: Double,
            geschaetzt: Bool, satz: String
        ) {
            self.key = key
            self.name = name
            self.art = art
            self.von = von
            self.bis = bis
            self.eur = eur
            self.geschaetzt = geschaetzt
            self.satz = satz
        }
    }

    /// Die drei Abstände, die vom Versprechen zur Wirklichkeit führen, in dieser Reihenfolge
    /// (`nachbetrachtung.ts:27`).
    public static let kette: [String] = ["prognosefehler", "nachfuehren", "eingriff"]

    /// Die Treppe vom Versprechen zur Wirklichkeit, und daneben der Vergleichslauf.
    ///
    /// Sie beginnt bei der ersten Linie, die es gibt. Fehlt das Versprechen, weil der Fahrplan
    /// vor der Erweiterung der Ablage entstand, beginnt sie beim gehaltenen Fahrplan; fehlt jeder
    /// Fahrplan, steht nur die Wirklichkeit da (`nachbetrachtung.ts:29-34`).
    ///
    /// **Der Vergleichslauf steht daneben, nicht auf dem Weg** (`nachbetrachtung.ts:54-56`): was
    /// das Verschieben gegenüber einem Lauf ohne Preisblick gebracht hat, rechnet die
    /// Kostenseite, und die Nachbetrachtung nennt nur ihr Ergebnis.
    public static func treppe(_ d: NachbetrachtungOut) -> [Stufe] {
        var linie: [String: Linie] = [:]
        for l in d.linien { linie[l.key] = l }
        var abstand: [String: Abstand] = [:]
        for a in d.abstaende { abstand[a.key] = a }

        var aus: [Stufe] = []
        let glieder = kette.compactMap { abstand[$0] }.filter { $0.eur != nil }
        let beginn = glieder.first.flatMap { linie[$0.von] }
        if let beginn, let anfang = beginn.eur {
            var stand = anfang
            aus.append(
                Stufe(
                    key: beginn.key, name: beginn.nameDe, art: .summe, von: 0, bis: stand,
                    eur: stand, geschaetzt: false, satz: ""))
            for a in glieder {
                let neu = stand + (a.eur ?? 0)
                aus.append(
                    Stufe(
                        key: a.key, name: a.nameDe, art: .stufe, von: stand, bis: neu,
                        eur: a.eur ?? 0, geschaetzt: false, satz: a.satzDe ?? ""))
                stand = neu
            }
        }
        if let ist = linie["wirklich"], let eur = ist.eur {
            aus.append(
                Stufe(
                    key: "wirklich", name: ist.nameDe, art: .summe, von: 0, bis: eur, eur: eur,
                    geschaetzt: false, satz: ""))
        }
        if let perfekt = linie["perfekt"], let eur = perfekt.eur {
            aus.append(
                Stufe(
                    key: "perfekt", name: perfekt.nameDe, art: .bezug, von: 0, bis: eur, eur: eur,
                    geschaetzt: perfekt.geschaetzt ?? false,
                    satz: abstand["voraussicht"]?.satzDe ?? ""))
        }
        return aus
    }

    /// Die Schrittweiten, aus denen die Achse wählt (`nachbetrachtung.ts:75`).
    private static let schrittweiten: [Double] = [0.1, 0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10, 20, 25, 50]

    /// Die Achse der Treppe: von null (oder darunter, falls eine Linie negativ ist) bis zu einem
    /// runden Wert über dem größten Stand, mit drei bis fünf Marken.
    ///
    /// **Mindestens 0,50 € hoch** (`nachbetrachtung.ts:73`): an einem Tag, an dem die Wärmepumpe
    /// zwölf Cent gekostet hat, wäre eine Achse bis zwölf Cent eine Lupe auf das Rauschen - die
    /// Balken sähen aus wie an einem teuren Tag.
    ///
    /// **Höchstens fünf Felder**, darum die Suche nach der ersten passenden Schrittweite: sechs
    /// Beträge stehen am Telefon aufeinander, und mehr als fünf Felder liest ohnehin niemand ab.
    public static func achse(_ stufen: [Stufe]) -> (min: Double, max: Double, marken: [Double]) {
        let werte = stufen.flatMap { [$0.von, $0.bis] }.filter { $0.isFinite }
        let roh = max(0.5, werte.max() ?? 0.5)
        let tief = min(0, werte.min() ?? 0)
        let schritt = schrittweiten.first { (roh - tief) / $0 <= 5 } ?? 100
        let oben = (roh / schritt).rounded(.up) * schritt
        let unten = (tief / schritt).rounded(.down) * schritt
        var marken: [Double] = []
        var m = unten
        // Die Toleranz zählt die letzte Marke mit, die durch das Aufsummieren knapp über das
        // Maximum rutscht - dieselbe Zeile wie in der Vorlage (`nachbetrachtung.ts:79`).
        while m <= oben + 1e-9 {
            marken.append(((m * 100).rounded()) / 100)
            m += schritt
        }
        return (unten, oben, marken)
    }

    /// Die Beschriftung einer Achsenmarke: „0 €“, „0,5 €“, „2,25 €“.
    ///
    /// **Höchstens zwei Nachkommastellen und keine Nullen am Ende.** Die Vorlage schreibt
    /// `toLocaleString("de-DE", { maximumFractionDigits: 2 })` (`Kostentreppe.tsx:96`), also „1 €“
    /// und nicht „1,00 €“ - eine Achse aus sechs Marken wird mit festen zwei Stellen fast doppelt
    /// so breit, und die Marken stehen dann aufeinander. ``Formate/zahl(_:stellen:)`` schreibt
    /// *genau* so viele Stellen, wie es bekommt (der Grund steht dort); die Nullen fallen darum
    /// hier, und nicht in `Formate`.
    public static func achsenmarke(_ wert: Double) -> String {
        var zahl = Formate.zahl(wert, stellen: 2)
        if zahl.contains(",") {
            while zahl.hasSuffix("0") { zahl.removeLast() }
            if zahl.hasSuffix(",") { zahl.removeLast() }
        }
        return zahl + Formate.schmalesLeerzeichen + "€"
    }

    /// Die Farbe einer Treppenzeile.
    ///
    /// **Die Farbe gehört der Sache, nicht der Richtung** (`Kostentreppe.tsx:16-19`): der
    /// Fahrplan ist kühl, die Wirklichkeit warm, die Vergleichsrechnung hell. Ob eine Stufe
    /// teurer oder günstiger macht, steht an ihrem Vorzeichen und an der Pfeilspitze ihres
    /// Balkens; „eine zweite Farbbedeutung im selben Bild müsste man erst lernen“.
    ///
    /// Die Stufen selbst sind weiß und durchscheinend (`Kostentreppe.tsx:29`): sie sind kein
    /// Zustand der Anlage, sondern die Differenz zweier Zustände, und für eine Differenz gibt es
    /// keine Marke.
    public static func treppenfarbe(_ s: Stufe) -> Farbwert {
        if s.key == "wirklich" { return Marken.waermepumpe }
        if s.art == .bezug { return Marken.haus }
        if s.art == .stufe { return Marken.stufenbalken }
        return Marken.mist
    }

    /// Die Pfeilspitze steht nur, wo es eine Richtung gibt: eine Stufe von null Cent zeigt
    /// nirgendhin (`Kostentreppe.tsx:48-49`).
    public static func zeigtRichtung(_ s: Stufe) -> Bool {
        s.art == .stufe && abs(s.eur) >= 0.005
    }

    /// Die Zerlegung der Stufe „eingriff“ in Menge, Zeitpunkt und Ofen - als eine Zeile.
    ///
    /// Nur wenn Menge **und** Zeitpunkt dastehen (`Kostentreppe.tsx:71-75`): eine Zerlegung aus
    /// einem Teil ist keine.
    public static func eingriffszusatz(_ d: NachbetrachtungOut) -> String? {
        guard let a = d.abstaende.first(where: { $0.key == "eingriff" }),
            let menge = a.mengeEur, let zeit = a.zeitEur
        else { return nil }
        var text =
            "Menge \(Formate.euroMitVorzeichen(menge)) · Zeitpunkt \(Formate.euroMitVorzeichen(zeit))"
        if d.hatOfen == true, let ofen = a.ofenEur {
            text += " · Ofen \(Formate.euroMitVorzeichen(ofen))"
        }
        return text
    }

    /// Der Betrag einer Treppenzeile, so geschrieben, wie er in der Vorlage steht.
    ///
    /// Eine Summe ohne Vorzeichen, eine Stufe mit - der Grund steht an
    /// ``Formate/euroMitVorzeichen(_:)`` (`Kostentreppe.tsx:62`).
    public static func treppenwert(_ s: Stufe) -> String {
        s.art == .stufe ? Formate.euroMitVorzeichen(s.eur) : Formate.euro(s.eur)
    }

    // MARK: - Der Tagesvergleich

    /// Die Linien, die im Tagesvergleich eine eigene Zeile bekommen, in dieser Reihenfolge
    /// (`nachbetrachtung.ts:112`).
    public static let zeilenschluessel: [String] = ["erster", "letzter", "wirklich", "perfekt"]

    /// Die verfügbaren Linien für den Tagesvergleich.
    ///
    /// **Das Versprechen fehlt, und das ist Absicht** (`nachbetrachtung.ts:114`): „es ist
    /// derselbe Fahrplan wie ‚erster‘“ - nur mit seinen eigenen Preisen bewertet. Zwei Streifen
    /// mit identischen Zeiten übereinander sagen nichts, was einer nicht schon sagt.
    public static func zeilen(_ d: NachbetrachtungOut) -> [Linie] {
        var je: [String: Linie] = [:]
        for l in d.linien { je[l.key] = l }
        return zeilenschluessel.compactMap { je[$0] }.filter { $0.verfuegbar == true }
    }

    /// Farbe, Strichart und Breite einer Linie. Dieselbe Zuordnung wie in der Kostentreppe.
    ///
    /// **Drei Farben für vier Linien**, und das ist gemessen und nicht gespart
    /// (`Tagesvergleich.tsx:26-31`): „Ein Grün für die perfekte Voraussicht fiel durch - gegen
    /// das Orange der Wirklichkeit ΔE 0,8 bei Deuteranopie, also dieselbe Farbe.“ Darum trennt
    /// den ersten Fahrplan vom letzten Stand nicht die Farbe, sondern der Strich.
    public struct Strichart: Sendable, Hashable {
        public let farbe: Farbwert
        public let gestrichelt: Bool
        public let breite: Double

        public init(farbe: Farbwert, gestrichelt: Bool, breite: Double) {
            self.farbe = farbe
            self.gestrichelt = gestrichelt
            self.breite = breite
        }
    }

    public static func strichart(key: String) -> Strichart {
        switch key {
        case "wirklich": return Strichart(farbe: Marken.waermepumpe, gestrichelt: false, breite: 2.5)
        case "letzter": return Strichart(farbe: Marken.mist, gestrichelt: false, breite: 2)
        case "erster": return Strichart(farbe: Marken.mist, gestrichelt: true, breite: 1.6)
        default: return Strichart(farbe: Marken.haus, gestrichelt: false, breite: 1.6)
        }
    }

    /// Die vier Deckungen der Helligkeitsstufen (`Tagesvergleich.tsx:37`).
    public static let deckungen: [Double] = [0.28, 0.5, 0.75, 1]

    /// Die Füllung eines Streifenfeldes.
    ///
    /// **Stufe null ist eine Aussage: die Linie sagt „aus“** (`Tagesvergleich.tsx:155-157`). Sie
    /// bekommt einen schwachen Grund, damit sie sich von „sagt nichts“ unterscheidet, das leer
    /// bleibt.
    public static func streifenfarbe(stufe: Int) -> Farbwert {
        guard stufe >= 1 else { return Marken.stufeNull }
        let i = min(deckungen.count, stufe) - 1
        return Marken.waermepumpe.mitDeckung(deckungen[i])
    }

    /// Die Helligkeitsstufe einer Viertelstunde im Tagesstreifen: 0 für nichts, 1 bis 4 für den
    /// Strom im Verhältnis zu dem, was eine Viertelstunde bei Nennleistung zieht.
    ///
    /// **Vier Stufen und kein stufenloser Verlauf** (`nachbetrachtung.ts:99-104`): „die Zeilen
    /// sollen sich vergleichen lassen, und vier Helligkeiten unterscheidet das Auge sicher.
    /// `null` bleibt `null` - keine Aussage ist kein Stillstand.“
    ///
    /// **Eine Nennarbeit von null ergibt die höchste Stufe und keinen Absturz.** In JavaScript
    /// ist `kwh / 0` unendlich, `Math.ceil` davon auch, und `Math.min(4, Infinity)` ist 4 - die
    /// Vorlage kommt dort also bei vier heraus. In Swift würde `Int(Double.infinity)` die
    /// Anwendung beenden, also steht die Grenze hier ausgeschrieben. Der Fall ist nicht
    /// theoretisch: ein Haus ohne eingetragene Nennleistung liefert `wp_kw = 0`.
    public static func staerke(kwh: Double?, vollKwh: Double) -> Int? {
        guard let kwh, kwh.isFinite else { return nil }
        if kwh <= 0.02 * vollKwh { return 0 }
        guard vollKwh > 0 else { return 4 }
        let roh = (kwh / vollKwh) * 4 - 1e-9
        guard roh.isFinite else { return 4 }
        return min(4, max(1, Int(roh.rounded(.up))))
    }

    /// Die Zeitachse der Antwort: die Zeitpunkte, die Schrittweite und die Grenzen des Tages.
    ///
    /// `nil`, wenn der Tag keine Zeitpunkte hat - dann gibt es kein Bild, und die Vorlage
    /// zeichnet auch keines (`Tagesvergleich.tsx:76`).
    public struct Zeitgitter: Sendable, Hashable {
        public let zeiten: [Date]
        public let schritt: TimeInterval
        public let von: Date
        public let bis: Date

        public init(zeiten: [Date], schritt: TimeInterval, von: Date, bis: Date) {
            self.zeiten = zeiten
            self.schritt = schritt
            self.von = von
            self.bis = bis
        }

        public var spanne: ClosedRange<Date> { von <= bis ? von...bis : von...von }
    }

    public static func gitter(_ d: NachbetrachtungOut) -> Zeitgitter? {
        let zeiten = d.zeiten.compactMap { Zeit.ausIso($0) }
        guard let erste = zeiten.first, let letzte = zeiten.last else { return nil }
        let schritt = Double(d.schrittMin ?? 15) * 60
        let von = Zeit.ausIso(d.von) ?? erste
        let bis = Zeit.ausIso(d.bis) ?? letzte.addingTimeInterval(schritt)
        return Zeitgitter(zeiten: zeiten, schritt: schritt, von: von, bis: bis)
    }

    /// Was eine Viertelstunde bei Nennleistung an Arbeit bringt - der Maßstab der
    /// Helligkeitsstufen (`Tagesvergleich.tsx:138`).
    public static func vollKwh(_ d: NachbetrachtungOut) -> Double {
        d.wpKw * (Double(d.schrittMin ?? 15) / 60)
    }

    /// Die senkrechte Spanne einer Kurvenfläche: von null (oder darunter) bis zum größten Wert.
    ///
    /// **Ausgeschrieben und nicht der Automatik überlassen**, obwohl die Vorlage die Achse
    /// rechnen lässt (`splitNumber: 2`, `Tagesvergleich.tsx:130`). Der Schleier über dem nicht
    /// Verglichenen ist in Swift Charts ein `RectangleMark` über die ganze Flächenhöhe
    /// (`Diagramme/Fahrplanzeichnung.swift:188-196`), und ein Rechteck braucht seine beiden
    /// Grenzen als Werte - eine Fläche, deren Schleier nur bis zum höchsten Punkt der Kurve
    /// reicht, hätte oben einen hellen Streifen.
    ///
    /// Unter null nur, wo ein Wert unter null liegt: negative Preise kommen vor und sind der
    /// Grund für das halbe Projekt.
    public static func spanne(_ werte: [Double?]) -> ClosedRange<Double> {
        let da = werte.compactMap { $0 }.filter { $0.isFinite }
        let unten = min(0, da.min() ?? 0)
        let oben = da.max() ?? 1
        return unten < oben ? unten...oben : unten...(unten + 1)
    }

    /// Ein Stück Zeitachse ohne eigenen Wert: der Schleier, der Ofenrand.
    public struct Zeitspanne: Sendable, Hashable, Identifiable {
        public let von: Date
        public let bis: Date
        public var id: Date { von }

        public init(von: Date, bis: Date) {
            self.von = von
            self.bis = bis
        }
    }

    /// Ein Feld eines Helligkeitsstreifens: ein Stück Zeit und seine Stufe.
    public struct Streifenfeld: Sendable, Hashable, Identifiable {
        public let von: Date
        public let bis: Date
        public let stufe: Int
        public var id: Date { von }

        public init(von: Date, bis: Date, stufe: Int) {
            self.von = von
            self.bis = bis
            self.stufe = stufe
        }
    }

    /// Der Streifen einer Linie: je Lauf gleicher Helligkeit ein Feld.
    ///
    /// Zusammengefasst mit ``Wiedergabebild/laeufe(_:zeiten:schritt:)``, also mit derselben
    /// Lückenregel wie die Tagesuhr: ein Lauf endet auch beim Zeitsprung, und ein `nil` ergibt
    /// kein Feld (`Tagesvergleich.tsx:151`, `tagesuhr.ts:52-62`).
    public static func streifen(_ linie: Linie, gitter: Zeitgitter, vollKwh: Double)
        -> [Streifenfeld]
    {
        let stufen = linie.wpKwhJe.map { staerke(kwh: $0, vollKwh: vollKwh) }
        return Wiedergabebild.laeufe(stufen, zeiten: gitter.zeiten, schritt: gitter.schritt)
            .map { Streifenfeld(von: $0.von, bis: $0.bis, stufe: $0.wert) }
    }

    /// Der Ofenrand unter dem Streifen: dort, wo der Ofen mehr als die Hälfte der Viertelstunde
    /// brannte (`Tagesvergleich.tsx:172-181`).
    public static func ofenspannen(_ linie: Linie, gitter: Zeitgitter) -> [Zeitspanne] {
        let an: [Bool?] = linie.ofenJe.map { o in o == nil ? nil : o! > 0.5 }
        return Wiedergabebild.laeufe(an, zeiten: gitter.zeiten, schritt: gitter.schritt)
            .filter { $0.wert }
            .map { Zeitspanne(von: $0.von, bis: $0.bis) }
    }

    /// Die Läufe, über denen der Schleier liegt: was nicht verglichen wird
    /// (`Tagesvergleich.tsx:101-108`).
    public static func schleier(_ d: NachbetrachtungOut, gitter: Zeitgitter) -> [Zeitspanne] {
        let aussen: [Bool?] = d.verglichen.map { !$0 }
        return Wiedergabebild.laeufe(aussen, zeiten: gitter.zeiten, schritt: gitter.schritt)
            .filter { $0.wert }
            .map { Zeitspanne(von: $0.von, bis: $0.bis) }
    }

    /// Ein Punkt einer Kurve. `wert` ist `nil`, wo die Reihe eine Lücke hat - gezeichnet wird
    /// dort nichts (`connectNulls: false`, `Tagesvergleich.tsx:196`).
    public struct Kurvenpunkt: Sendable, Hashable, Identifiable {
        public let zeit: Date
        public let wert: Double?
        public var id: Date { zeit }

        public init(zeit: Date, wert: Double?) {
            self.zeit = zeit
            self.wert = wert
        }
    }

    /// Eine Reihe der Antwort an die Zeitachse geheftet. Reihen, die kürzer sind als die
    /// Zeitachse, enden früher - geraten wird nichts.
    public static func reihe(_ werte: [Double?], gitter: Zeitgitter) -> [Kurvenpunkt] {
        gitter.zeiten.enumerated().map { i, t in
            Kurvenpunkt(zeit: t, wert: i < werte.count ? werte[i] : nil)
        }
    }

    /// Eine Fläche des Tagesvergleichs: ihr Titel links daneben und ihre feste Höhe.
    ///
    /// **Die Höhen und die Luft dazwischen stehen fest** (`Tagesvergleich.tsx:72-94`): der Preis
    /// 56, der Überschuss 40, jeder Streifen 13, die Kosten 170. Die Luft ist der Abstand, den
    /// die Vorlage zwischen zwei gezeichneten Flächen lässt - 34 zwischen den Kurvenflächen,
    /// 7 zwischen zwei Streifen, 37 vor den Kosten.
    ///
    /// **Der Titel steht links und nicht im Bild.** ECharts setzt ihn als `graphic` in die
    /// Zeichnung (`Tagesvergleich.tsx:213-219`); im Projekt steht er links daneben als `Text`,
    /// wie beim Tagesband und beim Fahrplan (`Diagramme/Tagesbandbild.swift:105-110`).
    public struct Flaeche: Sendable, Hashable, Identifiable {
        public enum Art: String, Sendable, Hashable {
            case preis, sonne, streifen, kosten
        }

        public let art: Art
        public let key: String
        public let titel: String
        public let hoehe: Double
        public let luftDavor: Double
        /// Welche Linie der Streifen zeigt - nur bei ``Art/streifen`` gesetzt.
        public let linie: Linie?

        public var id: String { key }

        public init(
            art: Art, key: String, titel: String, hoehe: Double, luftDavor: Double,
            linie: Linie? = nil
        ) {
            self.art = art
            self.key = key
            self.titel = titel
            self.hoehe = hoehe
            self.luftDavor = luftDavor
            self.linie = linie
        }
    }

    /// Hat der Tag überhaupt Überschuss gesehen? Sonst fällt die Sonnenfläche weg
    /// (`Tagesvergleich.tsx:77`) - eine leere Fläche über dem Tag behauptet eine Messung, die
    /// es nicht gab.
    public static func hatSonne(_ d: NachbetrachtungOut) -> Bool {
        d.ueberschussKw.contains { ($0 ?? 0) > 0.05 }
    }

    /// Die Flächen von oben nach unten.
    ///
    /// `schmal` wählt die kurzen Titel der Streifen: am Telefon ist die Spalte der Namen
    /// schmaler, und dort stehen sie kürzer (`Tagesvergleich.tsx:45-46`, `:87`).
    public static func flaechen(_ d: NachbetrachtungOut, schmal: Bool) -> [Flaeche] {
        var aus: [Flaeche] = [
            Flaeche(
                art: .preis, key: "preis", titel: Nachbetrachtungsworte.flaechePreis, hoehe: 56,
                luftDavor: 0)
        ]
        if hatSonne(d) {
            aus.append(
                Flaeche(
                    art: .sonne, key: "sonne", titel: Nachbetrachtungsworte.flaecheSonne,
                    hoehe: 40, luftDavor: 34))
        }
        for (i, l) in zeilen(d).enumerated() {
            aus.append(
                Flaeche(
                    art: .streifen, key: "s:" + l.key,
                    titel: Nachbetrachtungsworte.linienname(l, schmal: schmal), hoehe: 13,
                    luftDavor: i == 0 ? 34 : 7, linie: l))
        }
        aus.append(
            Flaeche(
                art: .kosten, key: "kosten", titel: Nachbetrachtungsworte.flaecheKosten,
                hoehe: 170, luftDavor: 37))
        return aus
    }

    // MARK: - Die Auskunft zu einer Viertelstunde

    /// Eine Zeile der Auskunft: eine Linie mit ihren drei Zahlen.
    public struct Auskunftszeile: Sendable, Hashable, Identifiable {
        public let key: String
        public let name: String
        public let kwh: String
        public let eur: String
        public let bisHier: String
        public var id: String { key }

        public init(key: String, name: String, kwh: String, eur: String, bisHier: String) {
            self.key = key
            self.name = name
            self.kwh = kwh
            self.eur = eur
            self.bisHier = bisHier
        }
    }

    /// Was zu einer Viertelstunde dasteht: Kopf, Umstände, der Hinweis auf das nicht Verglichene
    /// und je Linie eine Zeile.
    ///
    /// **Ein Block über der Zeichnung und kein Fenster unter dem Zeiger**
    /// (`Tagesvergleich.tsx:221-260`). Am Telefon gibt es kein Darüberfahren: Zeigen und Greifen
    /// sind derselbe Finger, und ein Fenster, das dem Finger folgt, steht unter ihm. Dieselbe
    /// Entscheidung wie bei der Auskunft des Fahrplans
    /// (`Diagramme/Fahrplanzeichnung.swift:78-82`) und der Fahne des Tagesbands.
    public struct Auskunft: Sendable, Hashable {
        public let kopf: String
        public let umstaende: String
        public let nichtVerglichen: String?
        public let zeilen: [Auskunftszeile]
    }

    /// Eine Arbeit in kWh mit zwei Nachkommastellen: „0,22 kWh“ - und ohne Wert nur der Strich.
    ///
    /// **Der Strich wird vor der Einheit abgefangen, und das ist der ganze Zweck dieser
    /// Funktion.** ``Formate/zahl(_:stellen:)`` gibt für `nil` den Strich zurück
    /// (`Formate/Formate.swift:45`); angebaute Einheit ergab „- kWh“, einen Strich mit Einheit,
    /// und zwar in jeder nicht verglichenen Viertelstunde, wo der Dienst `wp_kwh_je = null`
    /// liefert. Die Vorlage schreibt dort nur „-“ (`Tagesvergleich.tsx:252`:
    /// `kwh == null ? "-" : ${de(kwh, 2)} kWh`).
    ///
    /// **Nicht ``Formate/kwh(_:)``**: das schreibt eine Nachkommastelle, die Vorlage hier zwei.
    /// Ein Wunsch nach `Formate.kwh(_:stellen:)` steht im Bericht; bis dahin dasselbe Muster wie
    /// ``stunden(_:)`` weiter unten in dieser Datei.
    private static func kwhZwei(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return Formate.leer }
        return Formate.zahl(wert, stellen: 2) + Formate.schmalesLeerzeichen + "kWh"
    }

    /// Die Auskunft zu dem Zeitpunkt, an dem der Finger steht.
    ///
    /// Die Viertelstunde, **in** der der Zeiger steht, nicht die nächstgelegene Marke
    /// (`Tagesvergleich.tsx:237-238`): ein Zeiger bei 12:14 gehört zu 12:00 und nicht zu 12:15.
    public static func auskunft(_ d: NachbetrachtungOut, gitter: Zeitgitter, zeit: Date)
        -> Auskunft?
    {
        guard !gitter.zeiten.isEmpty, gitter.schritt > 0 else { return nil }
        let roh = zeit.timeIntervalSince(gitter.von) / gitter.schritt
        guard roh.isFinite else { return nil }
        let i = min(gitter.zeiten.count - 1, max(0, Int(roh.rounded(.down))))
        let anfang = gitter.zeiten[i]
        let kopf =
            "\(Formate.hhmm(anfang)) bis \(Formate.hhmm(anfang.addingTimeInterval(gitter.schritt)))"
        let preis = i < d.preisCt.count ? d.preisCt[i] : nil
        let sonne = i < d.ueberschussKw.count ? d.ueberschussKw[i] : nil
        var umstaende = preis == nil ? Nachbetrachtungsworte.preisUnbekannt : Formate.ct(preis)
        if let sonne {
            umstaende += " · Überschuss \(Formate.kwMitEinheit(sonne))"
        }
        let verglichen = i < d.verglichen.count ? d.verglichen[i] : true
        let zeilen = Self.zeilen(d).map { l in
            Auskunftszeile(
                key: l.key, name: Nachbetrachtungsworte.linienname(l, schmal: false),
                kwh: Self.kwhZwei(l.wpKwhJe.indices.contains(i) ? l.wpKwhJe[i] : nil),
                eur: Formate.euro(l.eurJe.indices.contains(i) ? l.eurJe[i] : nil),
                bisHier: Formate.euro(
                    l.eurKumuliert.indices.contains(i) ? l.eurKumuliert[i] : nil))
        }
        return Auskunft(
            kopf: kopf, umstaende: umstaende,
            nichtVerglichen: verglichen ? nil : Nachbetrachtungsworte.nichtVerglichenSatz,
            zeilen: zeilen)
    }

    // MARK: - Die Legende

    /// Ein Stück der Legende unter dem Tagesvergleich.
    public struct Legendenstueck: Sendable, Hashable, Identifiable {
        /// Was die Marke zeigt.
        public enum Marke: Sendable, Hashable {
            /// Ein Strich in der Art der Linie - 18 Punkte breit (`globals.css:712`).
            case strich(Strichart)
            /// Die vier Helligkeitskästchen (`globals.css:713-714`).
            case stufen
            /// Der Ofenbalken, 10 × 3 Punkte (`globals.css:644`).
            case ofen
        }

        public let wort: String
        public let marke: Marke
        public var id: String { wort }
    }

    /// Die Legende: je Linie ein Strich, dann die Helligkeitsskala, und bei Ofen seine Marke
    /// (`Nachbetrachtung.tsx:154-175`).
    ///
    /// **Sie steht in der App immer da**, auch am iPad - anders als in der Vorlage, wo die Namen
    /// am Ende der Kurven stehen und die Legende daneben. Swift Charts hat kein `endLabel`, und
    /// die Vorlage selbst verlässt sich am Telefon auf genau diese Legende
    /// (`Tagesvergleich.tsx:68-69`).
    public static func legende(_ d: NachbetrachtungOut) -> [Legendenstueck] {
        var aus = zeilen(d).map { l in
            Legendenstueck(
                wort: Nachbetrachtungsworte.linienname(l, schmal: false),
                marke: .strich(strichart(key: l.key)))
        }
        aus.append(
            Legendenstueck(wort: Nachbetrachtungsworte.stufenlegende(wpKw: d.wpKw), marke: .stufen)
        )
        if d.hatOfen == true {
            aus.append(Legendenstueck(wort: Nachbetrachtungsworte.ofenLegende, marke: .ofen))
        }
        return aus
    }

    // MARK: - Der Kopf der Seite

    /// Die Zeile rechts im Kartenkopf: „N von M Viertelstunden verglichen · erster Fahrplan vom …“
    /// (`Nachbetrachtung.tsx:96-99`).
    public static func kopfzahl(_ d: NachbetrachtungOut) -> String {
        var text =
            "\(d.nVerglichen ?? 0) von \(d.zeiten.count) Viertelstunden verglichen"
        if let erster = d.ersterPlanErstellt {
            text +=
                " · erster Fahrplan vom \(Formate.kurzDatum(iso: erster)) \(Formate.hhmm(iso: erster))"
        }
        return text
    }

    /// Ein Satz des Kopfes: der Name des Abstands als Kicker, darunter sein Satz.
    public struct Kopfsatz: Sendable, Hashable, Identifiable {
        public let key: String
        public let wort: String
        public let satz: String
        public var id: String { key }
    }

    /// Die Sätze, die oben stehen: nur Abstände mit Betrag **und** Satz
    /// (`Nachbetrachtung.tsx:84`).
    ///
    /// Ein Abstand ohne Betrag hat keinen Satz, der etwas behaupten könnte, und ein Satz ohne
    /// Abstand steht über nichts.
    public static func kopfsaetze(_ d: NachbetrachtungOut) -> [Kopfsatz] {
        d.abstaende.compactMap { a in
            guard a.eur != nil, let satz = a.satzDe, !satz.isEmpty else { return nil }
            return Kopfsatz(key: a.key, wort: a.nameDe, satz: satz)
        }
    }

    /// Die Hinweise für die Karte „Zu diesem Tag“.
    ///
    /// **Ohne die Gründe fehlender Linien** (`Nachbetrachtung.tsx:86-87`): „Die Gründe fehlender
    /// Linien stehen schon in der Tabelle; hier nicht noch einmal.“ Erkannt werden sie an ihrem
    /// Anfang, so wie dort - der Dienst schreibt sie als „Die Linie „…“ fehlt: …“
    /// (`packages/hems-core/src/hems_core/accounting/nachbetrachtung.py:663-702`).
    public static func tageshinweise(_ d: NachbetrachtungOut) -> [String] {
        d.hinweiseDe.filter { !$0.hasPrefix(Nachbetrachtungsworte.linienhinweisAnfang) }
    }

    // MARK: - Die Zahlentabelle

    /// Die Tabelle „Die Linien in Zahlen“, fertig formatiert.
    ///
    /// **Fertig formatiert, und das ist der Zweck.** Jede Rundung dieser Tabelle ist eine
    /// Entscheidung der Vorlage - eine Nachkommastelle bei Strom, Preis und Stunden
    /// (`Nachbetrachtung.tsx:34-36`, `de()`), zwei bei Euro -, und unter Linux geprüft werden
    /// kann sie nur, wenn sie hier steht und nicht in der Zelle einer `View`.
    public struct Zahlentabelle: Sendable, Hashable {
        public struct Spalte: Sendable, Hashable, Identifiable {
            public let name: String
            public let zellen: [String]
            public var id: String { name }
        }

        /// Eine Linie, die es nicht gibt, mit ihrem Grund.
        public struct Fehlend: Sendable, Hashable, Identifiable {
            public let key: String
            public let wort: String
            public let grund: String
            public var id: String { key }
        }

        public let zeilennamen: [String]
        public let spalten: [Spalte]
        /// Die Fußnote über die Grundlast - nur, wo sie überhaupt etwas ausmacht.
        public let standbySatz: String?
        public let fehlende: [Fehlend]

        public var istLeer: Bool { zeilennamen.isEmpty }
    }

    /// Eine Stundenzahl: „3,4 h“.
    ///
    /// Von Hand und nicht aus ``Formate``: dort gibt es ``Formate/dauer(minuten:)``, das „3 h
    /// 20 min“ schreibt, und das ist eine andere Form als die der Vorlage
    /// (`Nachbetrachtung.tsx:210`, `de(l.wp_h)` plus „ h“). Ein Wunsch nach `Formate.stunden`
    /// steht im Bericht.
    private static func stunden(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return Formate.leer }
        return Formate.zahl(wert, stellen: 1) + Formate.schmalesLeerzeichen + "h"
    }

    public static func zahlentabelle(_ d: NachbetrachtungOut) -> Zahlentabelle {
        // Alle verfügbaren Linien, nicht nur die vier des Tagesvergleichs: hier steht auch das
        // Versprechen, denn in Zahlen ist es ein eigener Stand (`Nachbetrachtung.tsx:198`).
        let zeilen = d.linien.filter { $0.verfuegbar == true }
        let mitOfen = d.hatOfen == true
        let namen = zeilen.map { l in
            l.nameDe + (l.geschaetzt == true ? " " + Nachbetrachtungsworte.geschaetzt : "")
        }
        var spalten: [Zahlentabelle.Spalte] = [
            Zahlentabelle.Spalte(name: "Kosten", zellen: zeilen.map { Formate.euro($0.eur) })
        ]
        if mitOfen {
            spalten.append(
                Zahlentabelle.Spalte(
                    name: "davon Ofen", zellen: zeilen.map { Formate.euro($0.ofenEur) }))
        }
        spalten.append(
            Zahlentabelle.Spalte(name: "Strom", zellen: zeilen.map { Formate.kwh($0.wpKwh) }))
        spalten.append(
            Zahlentabelle.Spalte(name: "im Mittel", zellen: zeilen.map { Formate.ct($0.ctJeKwh) }))
        spalten.append(
            Zahlentabelle.Spalte(name: "Wärmepumpe", zellen: zeilen.map { stunden($0.wpH) }))
        if mitOfen {
            spalten.append(
                Zahlentabelle.Spalte(name: "Ofen", zellen: zeilen.map { stunden($0.ofenH) }))
        }
        return Zahlentabelle(
            zeilennamen: namen, spalten: spalten, standbySatz: standbySatz(d),
            fehlende: d.linien.filter { $0.verfuegbar != true }.map {
                Zahlentabelle.Fehlend(
                    key: $0.key, wort: $0.nameDe + " fehlt", grund: $0.grundDe ?? "")
            })
    }

    /// Die Fußnote über die Grundlast.
    ///
    /// **Erst ab 0,05 kWh** (`Nachbetrachtung.tsx:217`): „0,0 kWh für 0,00 €“ wäre eine Zeile,
    /// die nichts sagt, und sie stünde unter jeder Tabelle.
    public static func standbySatz(_ d: NachbetrachtungOut) -> String? {
        guard let kwh = d.standbyKwh, let eur = d.standbyEur, kwh >= 0.05 else { return nil }
        return "Daneben, in keiner Linie: die Grundlast der Anlage im Stillstand, "
            + "\(Formate.kwh(kwh)) für \(Formate.euro(eur))."
    }
}
