import Foundation

/// Die Einstellungen des Reglers der Wärmepumpe: die Rechnungen hinter der Seite „Regler“.
///
/// **Lesen.** Eine Einstellung, die nicht gelesen wurde oder zu alt ist, steht als Fragezeichen
/// da, nie als Null: null Kelvin Verschiebung ist eine Einstellung, kein fehlender Wert
/// (`apps/web/src/components/waermepumpe/regler.ts:6-7`).
///
/// **Stellen.** Die Seite sammelt Änderungen als Entwurf und schickt sie erst auf Knopfdruck ab.
/// Was sich bewegen lässt, entscheidet ``bedienbar(_:stellenMoeglich:)``: die Einstellung muss
/// stellbar, gelesen und mit dem Bediengerät verglichen sein, und der Dienst muss einen
/// Stellbefehl loswerden können. Dieselben Bedingungen prüft der Dienst noch einmal
/// (`apps/api/src/dch_api/routers/waermepumpe.py:95-99`); hier sorgen sie dafür, dass ein
/// Regler, der nichts bewirken würde, sich gar nicht erst bewegt (`regler.ts:9-13`).
///
/// **Die Heizkurve** ist eine Näherung, und so steht es auch auf der Seite:
/// Vorlauf = Raum + Steilheit × (Raum − außen) + Verschiebung, begrenzt auf den kleinsten und
/// größten Vorlauf (`regler.ts:138-141`).
///
/// **Warum das im Kern steht und nicht in der Ansicht.** Es ist Logik mit genau einer richtigen
/// Antwort je Eingabe, also prüfbar, und zwar hier auf jedem Rechner – die Begründung steht
/// ausgeschrieben in ``ReglerEinstellungOut/wertAlsText(_:)`` (`Modelle/Woerter.swift:5-10`).
/// Die Oberfläche hatte davon bis zum 20.11.2026 nichts: sie zeigte eine flache Liste mit einem
/// `Stepper` je Zeile, ohne Kurve, ohne Pult und – schwerer – ohne die Sperre „nicht
/// verglichen“. Sie bot damit das Stellen an, wo die Vorlage es verwehrt.
public enum Reglerpult {

    /// Was jemand eingestellt, aber noch nicht abgeschickt hat: Kennung → Wert
    /// (`regler.ts:21`).
    public typealias Entwurf = [String: Double]

    // MARK: - Gelesen oder nicht

    /// Trägt diese Einstellung eine Zahl, auf die man sich berufen kann?
    ///
    /// Das ist `gelesen()` der Vorlage (`regler.ts:33-35`): ein Wert zählt nur mit Güte `ok`
    /// oder `derived`. ``Messwert/belastbar`` trifft genau diese Entscheidung, und sie stand in
    /// der App schon da – nur nicht an dieser Seite.
    public static func gelesen(_ w: ReglerEinstellungOut) -> Bool {
        w.wert.belastbar != nil
    }

    /// Ist das eine Zahl, die auf einen Kanalzug gehört – oder eine Stufenwahl?
    ///
    /// Im Schema ist `art` wahlfrei, in der Vorlage nicht (`Regler.tsx:67-69` rechnet mit einem
    /// festen Wort). Fehlt sie, gilt `zahl`: eine Einstellung mit `von`, `bis` und `schritt`
    /// und ohne Stufenwörter ist auf dem Pult brauchbar, in einem Schalterkasten dagegen ein
    /// leerer Kasten ohne einen einzigen Knopf.
    public static func istZahl(_ w: ReglerEinstellungOut) -> Bool {
        (w.art ?? .zahl) == .zahl
    }

    // MARK: - Die Sperre

    /// Warum sich eine Einstellung gerade nicht bewegen lässt.
    ///
    /// **Die Reihenfolge ist die der Vorlage** (`regler.ts:56-62`) und sie ist kein Zufall: der
    /// erste zutreffende Grund ist der, der dem Bedienenden am meisten sagt. „nur lesen“ steht
    /// vor „nicht gelesen“, weil an einer Einstellung, die der Bus nicht stellen kann, auch ein
    /// frisch gelesener Wert nichts ändert.
    public enum Sperre: Sendable, Hashable, CaseIterable {
        /// Der Dienst meldet diese Einstellung nicht als stellbar.
        case nurLesen
        /// Kein belastbarer Wert da – es gibt nichts, wovon aus man stellen könnte.
        case nichtGelesen
        /// Noch nicht mit dem Bediengerät verglichen. Das ist die Sperre, die der App fehlte.
        case nichtVerglichen
        /// Der Dienst kann gerade keinen Stellbefehl loswerden.
        case nichtMoeglich

        /// Das kurze Wort, das in der Fußzeile des Kanalzugs steht (`regler.ts:57-60`).
        public var wort: String {
            switch self {
            case .nurLesen: return "nur lesen"
            case .nichtGelesen: return "nicht gelesen"
            case .nichtVerglichen: return "nicht verglichen"
            case .nichtMoeglich: return "Stellen nicht möglich"
            }
        }
    }

    /// Der erste zutreffende Sperrgrund – oder `nil`, wenn sich die Einstellung bewegen lässt.
    public static func sperre(_ w: ReglerEinstellungOut, stellenMoeglich: Bool) -> Sperre? {
        if w.stellbar != true { return .nurLesen }
        if !gelesen(w) { return .nichtGelesen }
        if w.bestaetigt != true { return .nichtVerglichen }
        if !stellenMoeglich { return .nichtMoeglich }
        return nil
    }

    /// Lässt sich diese Einstellung bewegen? (`regler.ts:64`)
    public static func bedienbar(_ w: ReglerEinstellungOut, stellenMoeglich: Bool) -> Bool {
        sperre(w, stellenMoeglich: stellenMoeglich) == nil
    }

    // MARK: - Werte als Text

    /// Eine Zahl dieser Einstellung mit deutschem Komma und Einheit, eine Verschiebung mit
    /// Vorzeichen (`regler.ts:38-42`).
    ///
    /// **Das Plus bei `K` ist der ganze Unterschied zu ``ReglerEinstellungOut/wertAlsText(_:)``.**
    /// Eine Verschiebung von +7 K und eine von −7 K heben die Kurve in entgegengesetzte
    /// Richtungen; „7,0 K“ ohne Vorzeichen lässt offen, welche von beiden gemeint ist. Bei einem
    /// Vorlauf von 45 °C stellt sich die Frage nicht, darum steht das Plus nur an `K`.
    ///
    /// Geschrieben wird mit ``Formate/zahl(_:stellen:)`` und dem schmalen Leerzeichen der App –
    /// also mit U+2212 als Minus und U+202F vor der Einheit. Das ist der Hausstil und weicht
    /// von der Vorlage nur in Zeichen ab, die sie selbst nicht benennt.
    public static func zahlText(_ w: ReglerEinstellungOut, _ v: Double) -> String {
        let text = Formate.zahl(v, stellen: w.stellen ?? 1)
        let vorzeichen = (w.einheit == "K" && v > 0) ? "+" : ""
        guard let einheit = w.einheit, !einheit.isEmpty else { return vorzeichen + text }
        return vorzeichen + text + Formate.schmalesLeerzeichen + einheit
    }

    /// Der gelesene Wert als Text – oder ein Fragezeichen (`regler.ts:44-47`).
    ///
    /// **Ein Fragezeichen und nicht der Strich der App.** Hier steht die Zahl, mit der jemand am
    /// Bediengerät gegenliest; „-“ sieht aus wie ein Messwert, „?“ ist eine Frage.
    public static func wertText(_ w: ReglerEinstellungOut) -> String {
        guard let wert = w.wert.belastbar else { return "?" }
        return zahlText(w, wert)
    }

    /// Wann gelesen, als Uhrzeit am Ort des Hauses (`regler.ts:50-53`).
    public static func standText(_ w: ReglerEinstellungOut) -> String {
        guard gelesen(w), Zeit.ausIso(w.wert.observedAt) != nil else { return "nicht gelesen" }
        return Formate.hhmm(iso: w.wert.observedAt)
    }

    // MARK: - Das Raster

    /// Der Wert auf dem Schrittraster der Einstellung, innerhalb ihrer Grenzen
    /// (`regler.ts:67-73`).
    ///
    /// **Darum gibt es kein stufenloses Ziehen.** Eine Heizkurvensteilheit kennt Schritte von
    /// 0,05; was dazwischen liegt, nimmt der Regler nicht an. Ein Schieber, der 0,8375 anzeigt,
    /// behauptet eine Genauigkeit, die der Bus nicht hat.
    public static func raster(_ w: ReglerEinstellungOut, _ wert: Double) -> Double {
        let von = w.von ?? 0
        let bis = w.bis ?? von
        let schritt = w.schritt ?? 1
        let geklemmt = Swift.min(bis, Swift.max(von, wert))
        guard schritt > 0 else { return geklemmt }
        let stufen = ((geklemmt - von) / schritt).rounded()
        // Auf vier Stellen, wie `toFixed(4)` der Vorlage: 0,05 × 17 ist in Binärbrüchen nicht
        // genau 0,85, und eine Steilheit „0,8500000000000001“ ginge so an den Bus.
        return ((von + stufen * schritt) * 10_000).rounded() / 10_000
    }

    /// Wo ein Wert auf der Skala seiner Einstellung liegt, 0 (unten) bis 1 (oben)
    /// (`regler.ts:76-80`).
    public static func anteil(_ w: ReglerEinstellungOut, _ wert: Double) -> Double {
        let von = w.von ?? 0
        let bis = w.bis ?? von + 1
        // Eine Spanne von null hätte keine Mitte und keine Richtung; dann liegt alles unten.
        guard bis > von else { return 0 }
        return Swift.min(1, Swift.max(0, (wert - von) / (bis - von)))
    }

    /// Der Wert an einer Stelle der Skala, auf dem Raster (`regler.ts:83-87`).
    public static func wertBei(_ w: ReglerEinstellungOut, _ a: Double) -> Double {
        let von = w.von ?? 0
        let bis = w.bis ?? von + 1
        return raster(w, von + Swift.min(1, Swift.max(0, a)) * (bis - von))
    }

    /// Der Wert, den die Seite gerade zeigt: der Entwurf, sonst der gelesene (`regler.ts:90-94`).
    public static func sichtbar(_ w: ReglerEinstellungOut, entwurf: Entwurf) -> Double? {
        if let e = entwurf[w.schluessel] { return e }
        return w.wert.belastbar
    }

    // MARK: - Was der Entwurf ändert

    /// Eine Änderung des Entwurfs gegenüber dem, was am Regler steht.
    public struct Aenderung: Sendable, Hashable, Identifiable {
        public let w: ReglerEinstellungOut
        public let alt: Double
        public let neu: Double

        public var id: String { w.schluessel }

        public init(w: ReglerEinstellungOut, alt: Double, neu: Double) {
            self.w = w
            self.alt = alt
            self.neu = neu
        }

        /// „45,0 °C → 41,0 °C“ für die Übersicht in der Leiste (`Regler.tsx:293`).
        public var spanne: String {
            "\(Reglerpult.zahlText(w, alt)) → \(Reglerpult.zahlText(w, neu))"
        }

        /// „Heizkurve: Steilheit“ – Gruppe und Name, wie die Übersicht sie nennt.
        public var wort: String { "\(w.gruppeDe): \(w.nameDe)" }
    }

    /// Was der Entwurf gegenüber dem Gelesenen ändert (`regler.ts:100-108`).
    ///
    /// **Ein Entwurf, der dem gelesenen Wert gleicht, ist keine Änderung.** Wer einen Schieber
    /// hin und wieder zurückzieht, hat nichts geändert – und soll dafür keinen Stellbefehl auf
    /// den Bus schicken. Die Schwelle von 1e-6 ist die der Vorlage und fängt die Reste des
    /// Rasterns ab.
    public static func aenderungen(_ werte: [ReglerEinstellungOut], entwurf: Entwurf)
        -> [Aenderung]
    {
        var aus: [Aenderung] = []
        for w in werte {
            guard let neu = entwurf[w.schluessel], let alt = w.wert.belastbar else { continue }
            if abs(neu - alt) > 1e-6 { aus.append(Aenderung(w: w, alt: alt, neu: neu)) }
        }
        return aus
    }

    // MARK: - Die Fußzeile unter jedem Regler

    /// Was unter einem Kanalzug oder Schalter steht (`Regler.tsx:103-115`).
    ///
    /// **Der Vergleichsknopf trägt den gelesenen Wert im Text, und das ist der Kern der
    /// Absicherung.** Er sendet nichts an die Pumpe; er schaltet nur die Sperre „nicht
    /// verglichen“ ab. Der Wert steht darauf, damit man ihn am Bediengerät gegenlesen kann,
    /// ohne hin- und herzusehen – steht dort eine andere Zahl, ist die Kennung für diese Anlage
    /// falsch gelesen, und dann darf niemand drücken (`Regler.tsx:133`).
    public enum Fussstand: Sendable, Hashable {
        /// „gesendet 21,0 °C, wartet auf den Regler“ – abgeschickt, noch nicht zurückgemeldet.
        case wartet(String)
        /// Der gestrichelte Knopf: „Am Gerät steht 1,00“.
        case vergleichen(String)
        /// Ein anderer Sperrgrund, stumm.
        case grund(String)
        /// „gelesen 14:53“ – nichts im Weg.
        case gelesen(String)

        /// Der Text, der dasteht – in allen vier Fällen.
        public var satz: String {
            switch self {
            case .wartet(let s), .vergleichen(let s), .grund(let s), .gelesen(let s): return s
            }
        }
    }

    public static func fuss(_ w: ReglerEinstellungOut, stellenMoeglich: Bool) -> Fussstand {
        if let g = w.gesendet {
            return .wartet("gesendet \(zahlText(w, g.wert)), wartet auf den Regler")
        }
        switch sperre(w, stellenMoeglich: stellenMoeglich) {
        case .nichtVerglichen: return .vergleichen("Am Gerät steht \(wertText(w))")
        case .some(let grund): return .grund(grund.wort)
        case .none: return .gelesen("gelesen \(standText(w))")
        }
    }

    // MARK: - Die Heizkurve

    /// Die fünf Größen, aus denen die Näherung besteht (`regler.ts:112`).
    public struct Kurve: Sendable, Hashable {
        public let steilheit: Double
        public let verschiebung: Double
        public let raum: Double
        public let min: Double
        public let max: Double

        public init(steilheit: Double, verschiebung: Double, raum: Double, min: Double, max: Double) {
            self.steilheit = steilheit
            self.verschiebung = verschiebung
            self.raum = raum
            self.min = min
            self.max = max
        }
    }

    /// Die Kennungen der fünf Kurvengrößen (`regler.ts:114-120`).
    public enum Kurvenkennung {
        public static let steilheit = "heat_pump_set_slope"
        public static let verschiebung = "heat_pump_set_offset_k"
        public static let raum = "heat_pump_set_room_day_c"
        public static let min = "heat_pump_set_flow_min_c"
        public static let max = "heat_pump_set_flow_max_c"

        /// Alle fünf, in der Reihenfolge der Vorlage.
        public static let alle = [steilheit, verschiebung, raum, min, max]
    }

    /// Ein Griff am Kurvenbild. `raum` hat keinen: die Raumtemperatur ist der Drehpunkt der
    /// Näherung und wird am Pult gestellt, nicht an der Kurve (`Heizkurve.tsx:136-161`).
    public enum Kurvengriff: String, Sendable, Hashable, CaseIterable {
        case steilheit, verschiebung, max, min

        /// Die Kennung der Einstellung, die dieser Griff stellt.
        public var kennung: String {
            switch self {
            case .steilheit: return Kurvenkennung.steilheit
            case .verschiebung: return Kurvenkennung.verschiebung
            case .max: return Kurvenkennung.max
            case .min: return Kurvenkennung.min
            }
        }

        /// Wie die Sprachausgabe ihn nennt (`Heizkurve.tsx:139, 148, 156`).
        public var name: String {
            switch self {
            case .steilheit: return "Steilheit der Heizkurve"
            case .verschiebung: return "Verschiebung der Heizkurve"
            case .max: return "Vorlauf höchstens"
            case .min: return "Vorlauf mindestens"
            }
        }

        /// Das Wort an der Beschriftung bzw. auf dem Schild (`Heizkurve.tsx:142, 153, 161`).
        public var kurzwort: String {
            switch self {
            case .steilheit: return "Steilheit"
            case .verschiebung: return "Verschiebung"
            case .max: return "max"
            case .min: return "min"
            }
        }

        /// Bei welcher Außentemperatur der Griff sitzt – `nil` für die beiden Grenzlinien, die
        /// am rechten Rand hängen und für jede Außentemperatur gelten.
        ///
        /// **Die Stellen sind mit Bedacht gewählt** (`Heizkurve.tsx:25-26`): die Steilheit
        /// wirkt bei −10 °C am stärksten, die Verschiebung ist bei 18 °C nahe am Drehpunkt und
        /// hebt die Kurve dort als Ganzes.
        public var aussen: Double? {
            switch self {
            case .steilheit: return -10
            case .verschiebung: return 18
            case .max, .min: return nil
            }
        }
    }

    /// Die Größen der Kurve aus den Einstellungen, mit dem Entwurf darüber. `nil`, wenn eine
    /// fehlt (`regler.ts:123-135`).
    public static func kurveAus(_ werte: [ReglerEinstellungOut], entwurf: Entwurf = [:]) -> Kurve? {
        func zahl(_ kennung: String) -> Double? {
            guard let w = werte.first(where: { $0.schluessel == kennung }) else { return nil }
            return sichtbar(w, entwurf: entwurf)
        }
        guard let steilheit = zahl(Kurvenkennung.steilheit),
            let verschiebung = zahl(Kurvenkennung.verschiebung),
            let raum = zahl(Kurvenkennung.raum),
            let min = zahl(Kurvenkennung.min),
            let max = zahl(Kurvenkennung.max)
        else { return nil }
        return Kurve(
            steilheit: steilheit, verschiebung: verschiebung, raum: raum, min: min, max: max)
    }

    /// Weicht der Entwurf bei einer der fünf Kurvengrößen von dem ab, was am Regler steht?
    /// Dann wird die Kurve bernsteinfarben und die gestrichelte Ist-Linie kommt dazu
    /// (`Heizkurve.tsx:46`).
    public static func kurveGeaendert(_ werte: [ReglerEinstellungOut], entwurf: Entwurf) -> Bool {
        for kennung in Kurvenkennung.alle {
            guard let neu = entwurf[kennung],
                let w = werte.first(where: { $0.schluessel == kennung })
            else { continue }
            if sichtbar(w, entwurf: [:]) != neu { return true }
        }
        return false
    }

    /// Der Vorlauf, den die Näherung bei einer Außentemperatur ergibt, ohne die Grenzen
    /// (`regler.ts:138`).
    public static func vorlaufFrei(_ k: Kurve, aussen: Double) -> Double {
        k.raum + k.steilheit * (k.raum - aussen) + k.verschiebung
    }

    /// Derselbe, begrenzt auf den kleinsten und größten Vorlauf (`regler.ts:141`).
    public static func vorlauf(_ k: Kurve, aussen: Double) -> Double {
        Swift.min(k.max, Swift.max(k.min, vorlaufFrei(k, aussen: aussen)))
    }

    /// Die Steilheit, mit der die Kurve bei dieser Außentemperatur durch diesen Vorlauf geht
    /// (`regler.ts:144-147`).
    public static func steilheitDurch(_ k: Kurve, aussen: Double, ziel: Double) -> Double {
        let hebel = k.raum - aussen
        return hebel == 0 ? k.steilheit : (ziel - k.raum - k.verschiebung) / hebel
    }

    /// Die Verschiebung, mit der die Kurve bei dieser Außentemperatur durch diesen Vorlauf geht
    /// (`regler.ts:150`).
    public static func verschiebungDurch(_ k: Kurve, aussen: Double, ziel: Double) -> Double {
        ziel - k.raum - k.steilheit * (k.raum - aussen)
    }

    /// Welchen Wert ein Griff bekommt, wenn er auf diesen Vorlauf gezogen wird – noch ohne
    /// Raster (`Heizkurve.tsx:56-61`).
    public static func griffziel(_ griff: Kurvengriff, k: Kurve, ziel: Double) -> Double {
        switch griff {
        case .steilheit: return steilheitDurch(k, aussen: griff.aussen ?? -10, ziel: ziel)
        case .verschiebung: return verschiebungDurch(k, aussen: griff.aussen ?? 18, ziel: ziel)
        case .max, .min: return ziel
        }
    }

    /// Ein Punkt der gezeichneten Kurve.
    public struct Kurvenpunkt: Sendable, Hashable {
        public let aussen: Double
        public let vorlauf: Double

        public init(aussen: Double, vorlauf: Double) {
            self.aussen = aussen
            self.vorlauf = vorlauf
        }
    }

    /// Die Kurve als Punkte von kalt nach warm, je ganzem Grad (`regler.ts:153-156`).
    public static func kurvenPunkte(_ k: Kurve, von: Double, bis: Double) -> [Kurvenpunkt] {
        var aus: [Kurvenpunkt] = []
        var t = von
        while t <= bis {
            aus.append(Kurvenpunkt(aussen: t, vorlauf: vorlauf(k, aussen: t)))
            t += 1
        }
        return aus
    }

    /// Das Schild am rechten Rand einer Grenzlinie: „max 45°“ (`Heizkurve.tsx:142`).
    public static func griffschild(_ griff: Kurvengriff, _ v: Double) -> String {
        "\(griff.kurzwort) \(Formate.zahl(v, stellen: 0))°"
    }

    /// Die Beschriftung an einem Ziehgriff: „Steilheit 1,00“, „Verschiebung +7,0 K“
    /// (`Heizkurve.tsx:153, 161`).
    public static func griffbeschriftung(_ griff: Kurvengriff, _ w: ReglerEinstellungOut, _ v: Double)
        -> String
    {
        "\(griff.kurzwort) \(zahlText(w, v))"
    }

    /// Die Mono-Zeile unter der Kurve: „bei −10 °C 45,0 °C · bei 0 °C 45,0 °C · bei 10 °C
    /// 41,0 °C“ (`Heizkurve.tsx:167-169`).
    ///
    /// **Drei Stützstellen und nicht die ganze Kurve.** Wer an der Steilheit dreht, will wissen,
    /// was das im Februar, im März und in der Übergangszeit bedeutet; die drei Zahlen sagen das
    /// in einer Zeile.
    public static func kurvenwertesatz(_ k: Kurve) -> String {
        [-10.0, 0.0, 10.0]
            .map { t in
                "bei \(Formate.celsius(t, stellen: 0)) \(Formate.celsius(vorlauf(k, aussen: t), stellen: 1))"
            }
            .joined(separator: " · ")
    }

    // MARK: - Die Einteilung der Seite

    /// Eine Gruppe von Kanalzügen am Pult.
    public struct Pultgruppe: Sendable, Hashable, Identifiable {
        public let name: String
        public let werte: [ReglerEinstellungOut]

        public var id: String { name }

        public init(name: String, werte: [ReglerEinstellungOut]) {
            self.name = name
            self.werte = werte
        }
    }

    /// Die Gruppen, die die Vorlage am Pult zuerst zeigt, in dieser Reihenfolge
    /// (`Regler.tsx:68`).
    public static let pultgruppennamen = ["Heizkurve", "Raum", "Warmwasser"]

    /// Die Kanalzüge des Pults: stellbare Zahlen, nach Gruppen.
    ///
    /// **Mit einer Auffanggruppe, die die Vorlage nicht hat.** Dort stehen genau die drei
    /// Gruppen „Heizkurve“, „Raum“ und „Warmwasser“ (`Regler.tsx:68`) – eine stellbare Zahl in
    /// einer vierten Gruppe fiele unter den Tisch, wäre also gelesen, aber nirgends stellbar.
    /// Was der Dienst als stellbar meldet, gehört auf das Pult; darum kommen weitere Gruppen
    /// hinten dran, in der Reihenfolge, in der sie kommen.
    public static func pultgruppen(_ werte: [ReglerEinstellungOut]) -> [Pultgruppe] {
        let zahlen = werte.filter { $0.stellbar == true && istZahl($0) }
        var namen = pultgruppennamen
        for w in zahlen where !namen.contains(w.gruppeDe) { namen.append(w.gruppeDe) }
        return namen.compactMap { name in
            let eigene = zahlen.filter { $0.gruppeDe == name }
            return eigene.isEmpty ? nil : Pultgruppe(name: name, werte: eigene)
        }
    }

    /// Die Schalter: stellbar, aber keine Zahl (`Regler.tsx:69`).
    public static func schalter(_ werte: [ReglerEinstellungOut]) -> [ReglerEinstellungOut] {
        werte.filter { $0.stellbar == true && !istZahl($0) }
    }

    /// Was nur gelesen wird (`Regler.tsx:70`).
    ///
    /// **Ein eigener, zugeklappter Abschnitt und keine Mischung.** In der App standen bis zum
    /// 20.11.2026 lesbare und stellbare Einstellungen gleichberechtigt in denselben
    /// Gruppenkarten – acht Zeilen, an denen nichts zu tun ist, zwischen denen, an denen etwas
    /// zu tun ist.
    public static func nurLesen(_ werte: [ReglerEinstellungOut]) -> [ReglerEinstellungOut] {
        werte.filter { $0.stellbar != true }
    }

    /// Die stellbaren Einstellungen (`Regler.tsx:65`).
    public static func stellbare(_ werte: [ReglerEinstellungOut]) -> [ReglerEinstellungOut] {
        werte.filter { $0.stellbar == true }
    }

    /// Eine Stufe eines Schalters: die Zahl, die der Regler kennt, und das Wort der
    /// Busbeschreibung dazu.
    ///
    /// **Eine Struktur und kein Tupel**, damit `ForEach(…, id: \.zahl)` sie aufzählen kann -
    /// auf ein Tupelglied gibt es in Swift keinen Schlüsselpfad.
    public struct Stufe: Sendable, Hashable, Identifiable {
        public let zahl: Double
        public let wort: String

        public var id: Double { zahl }

        public init(zahl: Double, wort: String) {
            self.zahl = zahl
            self.wort = wort
        }
    }

    /// Die Stufen eines Schalters, nach der Zahl geordnet (`Regler.tsx:185`).
    ///
    /// **Geordnet, und das ist nicht gleichgültig.** `wahl` ist ein Wörterbuch; in Swift ist
    /// seine Reihenfolge nicht festgelegt, und „2 immer an / 0 aus / 1 nach Zeitprogramm“ wäre
    /// bei jedem Start eine andere Reihe. Geordnet wird nach der Zahl, weil der Regler nur sie
    /// kennt.
    public static func stufen(_ w: ReglerEinstellungOut) -> [Stufe] {
        w.wahl
            .compactMap { paar -> Stufe? in
                guard let zahl = Double(paar.key) else { return nil }
                return Stufe(zahl: zahl, wort: paar.value)
            }
            .sorted { $0.zahl < $1.zahl }
    }

    // MARK: - Die Sätze der Seite

    /// „21 von 22 stellbaren Einstellungen mit dem Bediengerät verglichen“
    /// (`Regler.tsx:121-123`).
    ///
    /// **Das steht im Kopf, nicht die Uhrzeit.** Eine Uhrzeit sagt, wann gelesen wurde; diese
    /// Zeile sagt, wie weit die Gegenprobe gediehen ist – und damit, wie viel sich auf dieser
    /// Seite überhaupt bewegen lässt.
    public static func verglichenSatz(_ werte: [ReglerEinstellungOut], fehler: String? = nil)
        -> String
    {
        let stellbar = stellbare(werte)
        let verglichen = stellbar.filter { $0.bestaetigt == true }.count
        let satz =
            "\(verglichen) von \(stellbar.count) stellbaren Einstellungen mit dem Bediengerät verglichen"
        guard let fehler, !fehler.isEmpty else { return satz }
        return satz + " · " + fehler
    }

    /// Ist noch nicht alles verglichen? Dann steht der Anleitungsabsatz da (`Regler.tsx:131`).
    public static func anleitungNoetig(_ werte: [ReglerEinstellungOut]) -> Bool {
        let stellbar = stellbare(werte)
        return stellbar.contains { $0.bestaetigt != true }
    }

    /// Der Absatz, der erklärt, wozu der gestrichelte Knopf da ist (`Regler.tsx:133`).
    public static let anleitungssatz =
        "Bevor sich eine Einstellung bewegen lässt, einmal am Bediengerät nachsehen: Steht dort "
        + "dieselbe Zahl wie hier, den Knopf „Am Gerät steht …“ unter dem Regler drücken. Steht "
        + "dort etwas anderes, ist die Kennung für diese Anlage falsch gelesen; dann bitte nicht "
        + "drücken."

    /// Der Absatz unter der Kurve (`Regler.tsx:151`).
    public static let naeherungssatz =
        "Die Kurve ist eine Näherung: Vorlauf = Raum + Steilheit × (Raum − außen) + "
        + "Verschiebung, begrenzt auf den kleinsten und größten Vorlauf. Sie zeigt, wohin sich "
        + "die Kurve mit einer Änderung bewegt; was der Regler daraus wirklich macht, zeigen "
        + "danach die Punkte."

    /// Der Absatz unter den Schaltern (`Regler.tsx:197`).
    public static let stufensatz =
        "Die Wörter an den Stufen sind die Lesart der Busbeschreibung; der Regler kennt nur die "
        + "Zahl davor. Die Stufe mit dem Strich darunter ist die, die am Regler steht."

    /// Was über der Liste in der zweiten Stufe der Übernahmeleiste steht (`Regler.tsx:289`).
    public static let uebersichtssatz =
        "Diese Änderungen gehen an den Regler der Wärmepumpe und bleiben dort stehen:"

    /// Statt des Diagramms, wenn eine der fünf Größen fehlt (`Heizkurve.tsx:42`).
    public static let kurveFehltSatz =
        "Für die Kurve fehlt eine der fünf Einstellungen: Steilheit, Verschiebung, "
        + "Raumtemperatur Tag, kleinster oder größter Vorlauf."

    /// Der Warnabsatz, wenn der Dienst gerade keinen Stellbefehl loswird (`Regler.tsx:128`).
    ///
    /// Der fette Satz steht vorn und ist in der Vorlage ein eigenes `<strong>`; hier ist er der
    /// erste Satz, und die Ansicht hebt ihn nicht einzeln hervor – ein halb fetter Absatz in
    /// 14 Punkten liest sich am Telefon schlechter als ein ganzer in einer Farbe.
    public static func hindernissatz(_ hindernis: String) -> String {
        "Stellen ist gerade nicht möglich. \(hindernis) Lesen geht weiter."
    }

    /// „1 Änderung im Entwurf“ / „3 Änderungen im Entwurf“ (`Regler.tsx:300`).
    public static func entwurfssatz(_ anzahl: Int) -> String {
        anzahl == 1 ? "1 Änderung im Entwurf" : "\(anzahl) Änderungen im Entwurf"
    }

    // MARK: - Der Nachfragetakt

    /// Wie viele Sekunden bis zum nächsten Lesen (`Regler.tsx:46`).
    ///
    /// **Solange ein gesendeter Wert auf seine Rückmeldung wartet, öfter.** Gestellt ist eine
    /// Einstellung erst, wenn der Regler sie zurückmeldet; bis dahin steht „gesendet …, wartet
    /// auf den Regler“ da, und das soll nicht eine Minute stehen bleiben, wenn der Bus nach
    /// sechs Sekunden antwortet.
    public static func takt(wartet: Bool) -> Double {
        wartet ? 5 : 60
    }

    /// Wartet irgendeine Einstellung auf ihre Rückmeldung? (`Regler.tsx:42`)
    public static func wartet(_ werte: [ReglerEinstellungOut]) -> Bool {
        werte.contains { $0.gesendet != nil }
    }
}
