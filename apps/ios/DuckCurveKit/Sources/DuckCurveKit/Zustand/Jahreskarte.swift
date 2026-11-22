import Foundation

/// Ein Kalenderjahr als Fläche: 365 Spalten (Tage) × 24 Zeilen (Stunden), je Kennzahl eine Karte.
///
/// **Warum eine Fläche und keine Kurve** (`YearMap.tsx:13-15`, `charts.ts:401-408`). Ein Jahr als
/// Linie sind 8760 Punkte in einem Bild von 350 Punkten Breite; was dabei übrig bleibt, ist
/// Rauschen. Als Fläche aus Tag und Stunde wird jede Gewohnheit ein Muster: die Heizperiode ein
/// Block, die Sonne ein Bogen, die Nachtabsenkung ein waagerechter Streifen. Dieselbe Darstellung
/// wie im Browser, und aus demselben Grund.
///
/// **Was hier gerechnet wird und warum nicht in der Ansicht.** Die Obergrenze der Skala, die
/// Farbe je Zelle, die Monatsanfänge der Achse, die Texte des Hinweisfensters und der Fließtext
/// unter der Karte sind Rechnungen - Schwellen, Rundungen, Textauswahl. Sie stehen hier, weil sie
/// hier unter Linux geprüft werden können; die Ansicht zeichnet nur noch.
public struct Jahresraster: Sendable, Hashable {
    /// Das Jahr, wie der Dienst es nennt.
    public let jahr: Int
    /// Die Kalendertage als ISO-Datum, aufsteigend - eine Spalte je Tag.
    public let tage: [String]
    /// Die Werte als `[Tag][Stunde 0-23]`. `nil` heißt „keine Messdaten“, nicht „null“.
    ///
    /// **Die Achsen stehen fest und standen in der App einmal falsch.** Der Dienst liefert diese
    /// Liste als Tage mit je vierundzwanzig Stunden (`apps/api/src/dch_api/schemas.py:607-619`,
    /// `apps/api/src/dch_api/application/energy_accounting.py:1304-1315`). Die App las sie als
    /// Wochenzeilen mit sieben Spalten - damit fielen die Stunden 7 bis 23 jedes Tages aus dem
    /// Bild, und die Beschriftung behauptete etwas anderes, als zu sehen war.
    public let zellen: [[Double?]]
    /// Welche Kennzahl diese Fläche zeigt.
    public let kennzahl: Jahreskennzahl
    /// Wie viele Stunden des Jahres überhaupt Messwerte haben (über alle Kennzahlen).
    public let stundenMitWerten: Int
    /// Seit wann der Dienst Daten hat, falls er es sagt.
    public let datenSeit: String?
    /// Das Ende der Farbskala: das 98. Perzentil, nicht der größte Wert.
    public let grenze: Double
    /// Der wirklich kleinste Wert der Fläche - er steht in der Fußnote, nicht an der Skala.
    public let kleinster: Double?
    /// Der wirklich größte Wert der Fläche.
    public let groesster: Double?

    public init(
        jahr: Int, tage: [String], zellen: [[Double?]], kennzahl: Jahreskennzahl,
        stundenMitWerten: Int, datenSeit: String?, grenze: Double,
        kleinster: Double?, groesster: Double?
    ) {
        self.jahr = jahr
        self.tage = tage
        self.zellen = zellen
        self.kennzahl = kennzahl
        self.stundenMitWerten = stundenMitWerten
        self.datenSeit = datenSeit
        self.grenze = grenze
        self.kleinster = kleinster
        self.groesster = groesster
    }

    // MARK: - Bauen

    /// Eine Antwort des Dienstes auf eine Kennzahl legen.
    ///
    /// Fehlt die Kennzahl in der Antwort, bleibt die Fläche leer statt zu raten: eine Karte ohne
    /// Zellen ist eine ehrliche Auskunft, eine Karte aus Nullen wäre keine.
    public static func baue(_ aus: YearMapOut, kennzahl: Jahreskennzahl) -> Jahresraster {
        let zellen = aus.metrics[kennzahl.rawValue] ?? []
        let vorhandene = zellen.flatMap { $0 }.compactMap { $0 }.filter { $0.isFinite }
        return Jahresraster(
            jahr: aus.year,
            tage: aus.days,
            zellen: zellen,
            kennzahl: kennzahl,
            stundenMitWerten: aus.hoursWithData,
            datenSeit: aus.dataSince,
            grenze: kennzahl.divergierend
                ? robusteGrenze(vorhandene.map { abs($0) })
                : robusteGrenze(vorhandene.filter { $0 > 0 }),
            kleinster: vorhandene.min(),
            groesster: vorhandene.max()
        )
    }

    /// Die robuste Obergrenze: das 98. Perzentil statt des Maximums (`charts.ts:417-424`).
    ///
    /// **Ein einzelner Ausreißer - ein Ladevorgang, ein Defekt - zöge sonst die ganze Skala
    /// zusammen und färbte das restliche Jahr einheitlich dunkel.** Der wahre Größtwert
    /// verschwindet dabei nicht, er steht in der Fußnote. Ohne Werte ist die Grenze 1: eine Skala
    /// von null bis null hätte keine Mitte, durch die sich teilen ließe.
    public static func robusteGrenze(_ werte: [Double]) -> Double {
        guard !werte.isEmpty else { return 1 }
        let sortiert = werte.sorted()
        let stelle = min(sortiert.count - 1, Int((Double(sortiert.count) * 0.98).rounded(.down)))
        return sortiert[stelle]
    }

    // MARK: - Lesen

    /// Hat das Jahr überhaupt Stundenwerte? (`YearMap.tsx:127`, `hours_with_data === 0`.)
    public var hatStundenwerte: Bool { stundenMitWerten > 0 }

    /// Vierundzwanzig Zeilen, immer - auch wenn ein Tag kürzer gemeldet wird.
    public static let stundenJeTag = 24

    /// Der Wert einer Zelle, oder `nil`: keine Messdaten.
    public func wert(tag: Int, stunde: Int) -> Double? {
        guard tag >= 0, tag < zellen.count, stunde >= 0, stunde < zellen[tag].count else {
            return nil
        }
        guard let v = zellen[tag][stunde], v.isFinite else { return nil }
        return v
    }

    /// Wo ein Wert auf der Rampe liegt, 0 bis 1.
    ///
    /// Einfarbig misst von null bis zur Grenze (`charts.ts:518-519`, `min: 0`); divergierend von
    /// `-grenze` bis `+grenze`, also liegt die Null in der flächennahen Mitte. Werte jenseits der
    /// Grenze werden beschnitten - genau das ist der Zweck des Perzentils.
    ///
    /// **Eine Grenze von null kommt vor** und ist hier abgefangen: ein Jahr, in dem jede gemessene
    /// Stunde genau null ist, ergibt sonst eine Division null durch null. Die Vorlage rechnet an
    /// dieser Stelle `NaN` und malt nichts; hier wird daraus der ruhige Anfang der Rampe
    /// beziehungsweise die Mitte, damit das Bild steht statt zu verschwinden.
    public func anteil(_ wert: Double) -> Double {
        guard wert.isFinite else { return 0 }
        if kennzahl.divergierend {
            guard grenze > 0 else { return 0.5 }
            return min(1, max(0, (wert + grenze) / (2 * grenze)))
        }
        guard grenze > 0 else { return 0 }
        return min(1, max(0, wert / grenze))
    }

    /// Die Farbe einer Zelle. `nil` heißt: gar keine Farbe.
    ///
    /// **Leer ist nicht wenig.** Eine Stunde ohne Messdaten bekommt keine Farbe, sondern lässt die
    /// Kartenfläche stehen (`charts.ts:450-451`: „null heißt ‚keine Messdaten‘ - die Zelle bleibt
    /// leer“). In der App stand hier die Linienfarbe, also ein aufgehellter Kasten - eine Lücke
    /// sah damit heller aus als „fast nichts“, und am Tag der Zeitumstellung wurde daraus ein
    /// heller Streifen quer durch das Jahr.
    public func farbe(tag: Int, stunde: Int) -> Farbwert? {
        guard let v = wert(tag: tag, stunde: stunde) else { return nil }
        return Marken.rampenfarbe(kennzahl.rampe, anteil: anteil(v))
    }

    // MARK: - Die Achsen

    /// Eine Beschriftung an der Tagesachse: welche Spalte, welches Wort.
    public struct Monatsmarke: Sendable, Hashable, Identifiable {
        public let spalte: Int
        public let name: String

        public var id: Int { spalte }

        public init(spalte: Int, name: String) {
            self.spalte = spalte
            self.name = name
        }
    }

    /// Die Monatskürzel der Achse, ohne Punkt (`charts.ts:415`).
    ///
    /// **Absichtlich nicht `Namen.monateKurz`.** Dort stehen „Jan.“, „Sept.“ - mit Punkt, wie es
    /// in einem Satz gehört. An einer Achse aus zwölf Wörtern auf 350 Punkten ist der Punkt ein
    /// Pixel Lärm vor dem nächsten Wort, und die Vorlage lässt ihn darum weg. Zwei Listen für
    /// zwei Zwecke, nicht aus Versehen zwei Listen.
    public static let monatskuerzel = [
        "Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez",
    ]

    /// Die Spalten, an denen ein Monat anfängt - die einzigen, die beschriftet werden
    /// (`charts.ts:460-462, 504-506`).
    ///
    /// Dreihundertfünfundsechzig Tage lassen sich nicht beschriften, und jeder zehnte Tag nennt
    /// nichts, was man sucht. Gesucht wird der Monat.
    public var monatsanfaenge: [Monatsmarke] {
        tage.enumerated().compactMap { (i, iso) in
            guard let d = Tag.date(iso) else { return nil }
            let t = Kalender.haus.dateComponents([.day, .month], from: d)
            guard t.day == 1, let m = t.month, m >= 1, m <= 12 else { return nil }
            return Monatsmarke(spalte: i, name: Self.monatskuerzel[m - 1])
        }
    }

    /// Welche Stunden an der senkrechten Achse stehen: jede sechste (`charts.ts:515`,
    /// `interval i % 6`).
    public static func stundeBeschriftet(_ stunde: Int) -> Bool { stunde % 6 == 0 }

    // MARK: - Die Skala

    /// Wie viele Stellen an der Skala stehen (`charts.ts:535`): unter fünf eine, sonst keine.
    ///
    /// Bei einer Skala, die bei 0,8 kWh endet, wäre „1“ gegen „0“ der ganze Unterschied; bei einer,
    /// die bei 40 endet, ist „39,7“ eine Genauigkeit, die niemand ablesen will.
    public var skalenstellen: Int { grenze < 5 ? 1 : 0 }

    /// Das linke Ende der Skala: bei einer divergierenden Karte der andere Pol, sonst null.
    ///
    /// Links und rechts und nicht oben und unten, weil das Band waagerecht liegt
    /// (`charts.ts:522`, `orient: "horizontal"`) und links in Leserichtung das Minimum ist.
    public var skalaLinks: String { skalenwort(kennzahl.divergierend ? -grenze : 0) }

    /// Das rechte Ende der Skala, mit Einheit.
    public var skalaRechts: String { skalenwort(grenze) }

    /// Die Wörter an den Polen, wo es welche gibt - weitergereicht von der Kennzahl, damit die
    /// Ansicht nur eine Sache zu fragen hat.
    public var pole: (links: String, rechts: String)? { kennzahl.pole }

    private func skalenwort(_ wert: Double) -> String {
        let zahl = Formate.zahl(wert, stellen: skalenstellen)
        guard !kennzahl.einheit.isEmpty else { return zahl }
        return zahl + Formate.schmalesLeerzeichen + kennzahl.einheit
    }

    // MARK: - Das Hinweisfenster

    /// Die drei Zeilen über einer Zelle (`charts.ts:467-483`).
    public struct Zellenhinweis: Sendable, Hashable {
        /// „Di., 10. Februar 2026“.
        public let datum: String
        /// „07:00 - 07:59“.
        public let stunde: String
        /// Der Wert mit Einheit, in den Stellen der Kennzahl.
        public let wert: String
        /// Der Kalendertag als ISO-Datum - damit ein Tippen weiterführen kann.
        public let tag: String
        /// Die Stunde als Zahl, 0 bis 23.
        public let stundenzahl: Int

        public init(datum: String, stunde: String, wert: String, tag: String, stundenzahl: Int) {
            self.datum = datum
            self.stunde = stunde
            self.wert = wert
            self.tag = tag
            self.stundenzahl = stundenzahl
        }
    }

    /// Was über einer Zelle steht, oder `nil`, wo nichts gemessen wurde.
    ///
    /// **Kein Fenster über einer leeren Zelle.** Die Vorlage nimmt nur Zellen mit Zahl in die
    /// Reihe (`charts.ts:447-455`), und ohne Reihe gibt es dort kein Hinweisfenster. Ein Fenster
    /// mit einem Strich darin behauptete, hier sei etwas gemessen worden.
    public func hinweis(tag: Int, stunde: Int) -> Zellenhinweis? {
        guard let v = wert(tag: tag, stunde: stunde), tag < tage.count else { return nil }
        let iso = tage[tag]
        var text = Formate.zahl(v, stellen: kennzahl.stellen)
        if !kennzahl.einheit.isEmpty {
            text += Formate.schmalesLeerzeichen + kennzahl.einheit
        }
        return Zellenhinweis(
            datum: Self.datumLang(iso),
            stunde: String(format: "%02d:00 - %02d:59", stunde, stunde),
            wert: text,
            tag: iso,
            stundenzahl: stunde
        )
    }

    /// „Di., 10. Februar 2026“ - die Form, die die Vorlage im Hinweisfenster benutzt
    /// (`charts.ts:473-478`: `weekday: "short", day: "2-digit", month: "long", year: "numeric"`).
    ///
    /// **Nicht `Tag.lang`.** Das schreibt „Dienstag, 10. November 2026“: der volle Wochentag und
    /// der Tag ohne führende Null. Im Hinweisfenster über einer Zelle ist der kurze Wochentag
    /// genau die Auskunft, die man sucht („war das ein Sonntag?“), und die führende Null hält die
    /// drei Zeilen in gleicher Breite, wenn der Finger über die Fläche fährt.
    public static func datumLang(_ iso: String) -> String {
        guard let d = Tag.date(iso) else { return iso }
        let t = Kalender.haus.dateComponents([.weekday, .day, .month, .year], from: d)
        let wochentag = Namen.wochentag(t.weekday ?? 1, kurz: true)
        return String(
            format: "%@., %02d. %@ %d",
            wochentag, t.day ?? 0, Namen.monat(t.month ?? 1), t.year ?? 0)
    }

    /// Was ein Tippen auf eine Zelle tut (`YearMap.tsx:68`).
    ///
    /// **Nur wo ein Tippen etwas tut**, darum trägt der Hinweis diesen Satz nicht selbst
    /// (`charts.ts:439-441`: „Ein Versprechen ohne Wirkung wäre schlimmer als keines“).
    public static let klickhinweis = "Tippen öffnet die Wiedergabe dieser Stunde"

    // MARK: - Die Fußnote

    /// Der Satz, der immer unter der Karte steht (`YearMap.tsx:133-134`).
    public static let ortszeitsatz =
        "Jede Zelle ist eine Stunde in Ortszeit; leere Zellen sind Lücken in der Aufzeichnung, keine Nullwerte."

    /// Der Fließtext unter der Karte, Teil für Teil wie in der Vorlage
    /// (`YearMap.tsx:131-138`).
    ///
    /// Vier Teile: was diese Kennzahl zeigt, der Satz über Ortszeit und Lücken, die
    /// Stundenabdeckung und der wirkliche Werteumfang. Der vierte ist der wichtigste - er sagt,
    /// was die Farbskala verschweigt, weil sie beim 98. Perzentil endet.
    ///
    /// **Stundenzahlen ohne Tausenderpunkt.** Die Vorlage schreibt dort „8.760“
    /// (`toLocaleString("de-DE")`), dieses Paket schreibt überall „8760“ - die Begründung steht in
    /// `Formate` und gilt für jede Zahl der Anwendung, nicht nur für diese.
    public var fussnote: String {
        var text = kennzahl.hinweis + ". " + Self.ortszeitsatz
        let stunden = Double(tage.count * Self.stundenJeTag)
        text += " \(Formate.zahl(Double(stundenMitWerten), stellen: 0))"
        text += " von \(Formate.zahl(stunden, stellen: 0)) Stunden erfasst."
        if let klein = kleinster, let gross = groesster {
            let einheit = kennzahl.einheit.isEmpty
                ? ""
                : Formate.schmalesLeerzeichen + kennzahl.einheit
            text += " Werteumfang \(Formate.zahl(klein, stellen: 2))"
            text += " bis \(Formate.zahl(gross, stellen: 2))\(einheit);"
            text += " die Farbskala endet beim 98. Perzentil, damit einzelne Ausreißer nicht das"
            text += " ganze Jahr einfärben."
        }
        return text
    }

    // MARK: - Die Sätze der Seite

    /// Solange nichts da ist (`YearMap.tsx:127`).
    public static let laedtSatz = "Jahr wird geladen …"

    /// Ein Jahr, in dem der Dienst keine Stunde aufgezeichnet hat (`YearMap.tsx:127`).
    ///
    /// **Ein eigener Zustand, keine leere Fläche.** Vorher zeichnete die App ein Raster ohne eine
    /// einzige Farbe - und das sieht aus wie ein Fehler der App, nicht wie ein Jahr ohne Daten.
    public static func keineStundenSatz(jahr: Int) -> String {
        "Für \(jahr) liegen keine Stundenwerte vor."
    }

    /// Der Kicker der Reiterzeile (`YearMap.tsx:94`).
    public static let kicker = "365 Tage × 24 Stunden"

    /// Die vier Jahre, unter denen gewählt werden kann: das laufende und die drei davor
    /// (`YearMap.tsx:91`).
    ///
    /// **Vier und nicht beliebig viele.** Die App hatte einen Blätterer ohne untere Grenze; wer
    /// zwanzigmal „zurück“ tippte, landete bei 2006 und holte sich eine leere Karte. Die Vorlage
    /// nennt vier Jahre, weil es für mehr keine Daten gibt.
    public static func jahreswahl(jetzt: Date) -> [Int] {
        let dieses = Kalender.haus.component(.year, from: jetzt)
        return (0..<4).map { dieses - $0 }
    }
}

// MARK: - Die acht Kennzahlen

/// Die acht Flächen, die die Jahreskarte zeigen kann - in der Reihenfolge der Vorlage
/// (`YearMap.tsx:16-25`).
///
/// **Die Reihenfolge ist eine Aussage.** `grid_net_kwh` steht vorn und ist die Vorgabe
/// (`YearMap.tsx:37`), weil es die einzige Karte ist, die die Entenkurve über ein ganzes Jahr
/// zeigt: Bezug gegen Einspeisung, um null herum. Die App sortierte die Knöpfe alphabetisch nach
/// dem Schlüssel des Dienstes - damit stand „Autarkie“ vorn, eine Zahl ohne Einheit, die niemand
/// zuerst sehen will, und die eigentliche Karte an fünfter Stelle.
///
/// **Farbzuordnung wie im Energiefluss** (`YearMap.tsx:13-15`): Bernstein für eigene Energie, Mist
/// für das Netz, Terrakotta für die Wärmepumpe. Wer den Energiefluss gelesen hat, liest die Karte
/// ohne Umlernen.
///
/// Die Rohwerte sind die Schlüssel des Dienstes (`apps/api/src/dch_api/schemas.py:595-604`).
public enum Jahreskennzahl: String, CaseIterable, Sendable, Hashable {
    case netz = "grid_net_kwh"
    case erzeugung = "pv_kwh"
    case verbrauch = "house_kwh"
    case waermepumpe = "heat_pump_kwh"
    case netzbezug = "import_kwh"
    case einspeisung = "export_kwh"
    case preis = "price_ct_kwh"
    case autarkie = "autarky"

    /// Was auf dem Knopf und über der Karte steht.
    ///
    /// **Die Worte der Vorlage, nicht eigene.** Die App hieß dieselben Reihen „aus der Sonne“,
    /// „im Haus“, „aus dem Netz“, „eingespeist“ - hübscher, aber in zwei Oberflächen zwei Namen
    /// für dieselbe Zahl, und wer zwischen App und Wandanzeige vergleicht, muss dann übersetzen.
    public var name: String {
        switch self {
        case .netz: return "Netz"
        case .erzeugung: return "Erzeugung"
        case .verbrauch: return "Verbrauch"
        case .waermepumpe: return "Wärmepumpe"
        case .netzbezug: return "Netzbezug"
        case .einspeisung: return "Einspeisung"
        case .preis: return "Strompreis"
        case .autarkie: return "Autarkie"
        }
    }

    /// Die Einheit, rechts im Kartenkopf. Leer bei der Autarkie: ein Anteil hat keine
    /// (`YearMap.tsx:24, 125`).
    public var einheit: String {
        switch self {
        case .preis: return "ct/kWh"
        case .autarkie: return ""
        default: return "kWh"
        }
    }

    /// Nachkommastellen im Hinweisfenster (`YearMap.tsx:23-24`, `digits`).
    ///
    /// Beim Preis eine: Zehntelcent sind der Unterschied, um den es geht, Hundertstel nicht. Sonst
    /// zwei, wie die Vorgabe der Vorlage (`charts.ts:456`, `opts.digits ?? 2`).
    public var stellen: Int {
        switch self {
        case .preis: return 1
        default: return 2
        }
    }

    /// Die Farbrampe. Sie liegt im Kern und ist dort geprüft (`Marken.rampeEigen` und
    /// Geschwister, Werte aus `charts.ts:409-412`).
    public var rampe: [Farbwert] {
        switch self {
        case .netz: return Marken.rampeNetzBilanz
        case .erzeugung, .einspeisung, .autarkie: return Marken.rampeEigen
        case .verbrauch, .netzbezug, .preis: return Marken.rampeNetz
        case .waermepumpe: return Marken.rampeWaerme
        }
    }

    /// Hat diese Karte zwei Pole um null? Nur die Netzbilanz (`YearMap.tsx:17`).
    ///
    /// Einspeisung ist dort eine negative Zahl. Auf einer Skala von null bis zum Maximum erschien
    /// sie als „fast nichts“ - also als derselbe Befund wie eine Stunde, in der gar nichts
    /// geschah. Das ist der Unterschied, um den es auf dieser Karte geht.
    public var divergierend: Bool { self == .netz }

    /// Die Wörter an den Polen, von links nach rechts - nur bei der divergierenden Karte
    /// (`charts.ts:530-532`).
    ///
    /// **Die Bedeutung darf nicht allein in der Farbe stehen.** Wer Blau und Bernstein nicht
    /// unterscheidet, liest an dieser Karte sonst nichts.
    ///
    /// Links steht die Einspeisung, denn links liegt das Minimum des Bandes, und Einspeisung ist
    /// die negative Zahl - dieselbe Seite, auf der `rampeNetzBilanz` ihr Bernstein hat.
    public var pole: (links: String, rechts: String)? {
        divergierend ? (links: "Einspeisung", rechts: "Bezug") : nil
    }

    /// Der erste Teil der Fußnote: was auf dieser Karte zu sehen ist (`YearMap.tsx:17-24`).
    public var hinweis: String {
        switch self {
        case .netz:
            return "Bezug (hell blau) gegen Einspeisung (bernstein) - die Entenkurve über ein ganzes Jahr"
        case .erzeugung:
            return "Wann die Anlage lieferte: Tageslänge und Wetter, Tag für Tag"
        case .verbrauch:
            return "Der Rhythmus des Hauses - Wochentage, Urlaube, Gewohnheiten"
        case .waermepumpe:
            return "Heizperiode, Warmwasserspitzen und die Taktung der Regelung"
        case .netzbezug:
            return "Nur der Bezug, ohne Verrechnung mit der Einspeisung"
        case .einspeisung:
            return "Überschuss, der ins Netz ging"
        case .preis:
            return "Der bezugsgewichtete Preis je Stunde - die Struktur, gegen die geplant wird"
        case .autarkie:
            return "Anteil des Verbrauchs, der nicht aus dem Netz kam (0-1)"
        }
    }
}

// MARK: - Von der Übersicht in den Augenblick

/// Ein Tag und eine Stunde, an denen die Wiedergabe beginnen soll.
///
/// **Warum die Jahreskarte das braucht** (`YearMap.tsx:72-74`): „Aus der Übersicht in den
/// Augenblick: ein Feld ist ein Tag und eine Stunde, und die Wiedergabe kann genau dort beginnen.
/// Die Karte zeigt, *dass* an einem Dienstag im Februar etwas anders war; die Wiedergabe zeigt,
/// was.“ Ohne diesen Weg verliert die Seite ihre zweite Hälfte.
///
/// **Warum als eigener Typ und nicht als zwei Zeichenketten im Weg.** Die Wegetafel der App
/// schneidet den Fragezeichenteil ab, bevor sie eine Seite wählt (`App/Seitenwahl.swift`), und
/// das soll sie: `/strom/jahr?x=1` ist dieselbe Seite. Gelesen werden die Werte darum einmal,
/// hier, mit Prüfung - ein Tag, der kein Tag ist, und eine Stunde jenseits von 23 ergeben kein
/// Ziel, statt die Wiedergabe auf einen erfundenen Tag zu schicken (`YearMap.tsx:78-81` prüft
/// dasselbe).
public struct Wiedergabeziel: Sendable, Hashable {
    /// Der Kalendertag als ISO-Datum.
    public let tag: String
    /// Die Stunde in Ortszeit, 0 bis 23.
    public let stunde: Int

    /// Nur ein echter Kalendertag und eine echte Stunde ergeben ein Ziel.
    public init?(tag: String, stunde: Int) {
        guard Tag.istTag(tag), stunde >= 0, stunde < Jahresraster.stundenJeTag else { return nil }
        self.tag = tag
        self.stunde = stunde
    }

    /// Der Weg zur Wiedergabe - dieselbe Schreibweise wie im Browser (`YearMap.tsx:82`).
    public var weg: String { "\(Self.seite)?day=\(tag)&t=\(stunde)" }

    /// Die Seite, auf der ein Ziel landet.
    public static let seite = "/waerme/wiedergabe"

    /// Ein Ziel aus einem Weg lesen, oder `nil`, wenn keines darin steht.
    ///
    /// Unbekannte Felder werden übergangen und doppelte vom letzten Vorkommen überschrieben - so
    /// macht es jede Adressleiste, und ein Weg aus einer neueren Fassung des Dienstes soll hier
    /// nicht an einem Feld scheitern, das diese App nicht kennt.
    public static func ausWeg(_ weg: String) -> Wiedergabeziel? {
        let stuecke = weg.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard stuecke.count == 2 else { return nil }
        var felder: [String: String] = [:]
        for paar in stuecke[1].split(separator: "&") {
            let kv = paar.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            felder[String(kv[0])] = String(kv[1])
        }
        guard let tag = felder["day"], let t = felder["t"], let stunde = Int(t) else { return nil }
        return Wiedergabeziel(tag: tag, stunde: stunde)
    }

    /// Auf welchem Bild der Wiedergabe diese Stunde liegt - `zeitpunkte` sind die `at` der Bilder,
    /// aufsteigend.
    ///
    /// **Nachgesehen und nicht gerechnet.** `stunde * 60 / step_min` setzt ein dichtes Band ab
    /// Mitternacht voraus, und genau das sagt das Schema nicht zu: „**Lücken sind Lücken.** Ein
    /// Zeitpunkt ohne Messung in der Toleranz liefert kein Bild ... `frames` ist deshalb nicht
    /// notwendig gleichmässig und kann kürzer sein als der Tag“ (`schemas.py:1832-1835`). An einem
    /// Tag, dem der Vormittag fehlt, läge der Schieber mit dieser Rechnung Stunden hinter der
    /// getippten Stunde - der Sprung aus der Jahreskarte zeigte dann etwas anderes als das Feld,
    /// auf das getippt wurde.
    ///
    /// Gesucht ist darum das erste Bild, das in Hauszeit nicht vor der Stunde liegt. Gibt es
    /// keines, ist es das letzte: dort hört der Tag auf, und weiter geht es nicht.
    public static func bildstelle(stunde: Int, zeitpunkte: [String]) -> Int {
        guard !zeitpunkte.isEmpty else { return 0 }
        let treffer = zeitpunkte.firstIndex { iso in
            guard let d = Zeit.ausIso(iso) else { return false }
            return Kalender.haus.component(.hour, from: d) >= stunde
        }
        return treffer ?? zeitpunkte.count - 1
    }
}
