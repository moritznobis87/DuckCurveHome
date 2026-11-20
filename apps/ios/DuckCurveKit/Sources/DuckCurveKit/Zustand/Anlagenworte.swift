import Foundation

/// Die festen Worte und Zuordnungen der Seite „Anlage“: Kopfzeile, Fuß, Bühnenhinweise.
///
/// **Warum sie im Kern stehen und nicht in der Ansicht.** Die Vorlage setzt den Kopf aus drei
/// Teilen zusammen und hebt nur den mittleren hervor (`Anlage.tsx:62-75`), der Fuß hebt einzelne
/// Begriffe heraus (`globals.css:595`, `.anlage-fuss .m`), und der Wischhinweis am Telefon ist
/// eine Zeichenkette in einer Stilregel (`handy.css:400`). Das sind alles Festlegungen über
/// *Wortlaut und Fuge*, keine Darstellung - und eine Fuge, die in einer `View` steht, kann hier
/// niemand prüfen. ``Anlagenschema`` rechnet daneben die Zahlen und Farben des Schemas; hier
/// liegt, was dieselbe Seite **um** das Schema herum schreibt.
///
/// Dasselbe Muster wie ``Wiedergabeworte`` für die Nachbarseite.
public enum Anlagenworte {

    // MARK: - Der Takt

    /// Alle 20 Sekunden nachholen, nicht alle 10 (`Anlage.tsx:17`).
    ///
    /// Die Begründung steht in der Vorlage und ist eine Aussage über die Quelle, nicht über das
    /// Netz (`Anlage.tsx:14-16`): die Pufferfühler melden minütlich, und eine Zahl, die sich
    /// öfter ändert als ihre Quelle, lügt mit der Nachkommastelle.
    public static let taktSekunden = 20

    /// Was rechts in der Kopfzeile steht: „Stand 18:04 · alle 20 s“ (`Anlage.tsx:74`).
    ///
    /// **Der Takt steht im Text.** Wer die Seite ansieht und eine Zahl für veraltet hält, soll
    /// ablesen können, wie alt sie höchstens ist - darum nennt die Zeile die Spanne und nicht
    /// nur den Zeitpunkt.
    public static func standzeile(at iso: String?) -> String {
        "Stand \(Formate.hhmm(iso: iso)) · alle \(taktSekunden) s"
    }

    // MARK: - Der Satz über der Bühne

    /// Die drei Teile der Kopfzeile, getrennt - damit die Ansicht den mittleren fett setzen kann.
    ///
    /// ``Anlagenschema/kopfzeile(_:jetzt:)`` fügt dieselben Teile zu **einer** Zeichenkette
    /// zusammen und gibt die Fuge nicht her; die Vorlage braucht die Fuge, weil nur der
    /// Erzeugersatz in `<b>` steht (`globals.css:562`).
    public struct Kopfteile: Sendable, Hashable {
        /// „3 °C draußen“ - ganzzahlig, wie `Math.round(outdoor_c)` (`Anlage.tsx:66`). Ohne
        /// Außenfühler fehlt der Teil ganz, statt eine Null zu behaupten.
        public let draussen: String?
        /// Der Erzeugersatz, der in der Vorlage fett steht.
        public let satz: String
        /// „Strom aus PV 72 %, Netz 28 %“ - ohne Fluss fehlt der Teil (`Anlage.tsx:72`).
        public let mischung: String?

        public init(draussen: String?, satz: String, mischung: String?) {
            self.draussen = draussen
            self.satz = satz
            self.mischung = mischung
        }

        /// Dieselbe Zeile als eine Zeichenkette - für die Bedienungshilfe, die keine Fuge kennt.
        public var ganz: String {
            ([draussen, satz, mischung].compactMap { $0 }).joined(separator: " · ")
        }
    }

    public static func kopfteile(_ a: AnlageOut, jetzt: Date) -> Kopfteile {
        let mix = Anlagenschema.mischung(a.strom)
        return Kopfteile(
            // `Formate.celsius` rundet kaufmännisch vom Betrag weg - das Haus rundet überall so.
            // `Math.round` der Vorlage rundet bei genau −2,5 zur Null hin; das ist dort kein
            // Vorsatz, sondern die Vorgabe der Sprache, und hier wäre es eine zweite Regel.
            draussen: a.outdoorC.map { "\(Formate.celsius($0, stellen: 0)) draußen" },
            satz: Anlagenschema.erzeugerSatz(a, jetzt: jetzt),
            mischung: mix.text.isEmpty ? nil : "Strom aus \(mix.text)")
    }

    /// Was dasteht, solange nichts da ist (`Anlage.tsx:88`). Bei einem Fehler bleibt der Kasten
    /// leer: die Meldung steht dann darüber und muss nicht zweimal dastehen.
    public static let wartesatz = "Die Anlage wird geholt."

    /// Der Bereichskicker der Reiterzeile (`page.tsx:7`).
    ///
    /// **Am Telefon gibt es ihn nicht** (`AreaNav.tsx:96`: `hidden … md:block`) - drei Worte, die
    /// dort die Zeile des Bereichsnamens sprengen würden.
    public static let bereichskicker = "Strom · Speicher · vier Kreise"

    /// Der Hinweis unter der Bühne am Telefon, wörtlich aus `handy.css:400` - zwei Leerzeichen
    /// vor dem Pfeil.
    ///
    /// Die Begründung steht im Kommentar darüber (`handy.css:393-395`): das Schema ist eine
    /// Zeichnung im Querformat und rollt zur Seite, und der Hinweis sagt es, statt dass die
    /// rechte Hälfte unbemerkt fehlt.
    ///
    /// **Derselbe Satz steht in ``Wiedergabeworte/wischhinweis``**, und das ist kein Versehen
    /// der Vorlage: `.anlage-buehne::after` ist die einzige Regel dieser Art, und die
    /// Wiedergabeseite zeichnet dasselbe Schema auf derselben Bühne. Hier steht er, weil die
    /// Regel der Anlagenbühne gehört; zusammengelegt wird er, wenn die Wiedergabeseite auf
    /// ``Anlagenbuehne`` umgestellt ist. Dass beide gleich bleiben, prüft `AnlagenworteTests`.
    public static let wischhinweis = "zur Seite wischen: Strom, Erzeuger, Speicher, Verbraucher  ›"

    // MARK: - Das Glas

    /// Die Farbe zum Wort von ``Anlagenschema/nettoText(_:)`` (`schema.ts:147-150`).
    ///
    /// **Die Vorgabe ist nicht `text3`.** Die Vorlage setzt `rgba(255,255,255,.62)` - das ist
    /// ``Marken/last`` und nicht ``Marken/text3`` (0,48). Ein haltender Speicher steht damit so
    /// laut da wie eine Last im Diagramm und nicht so leise wie ein Hinweis; die Zeile ist eine
    /// Aussage über den Speicher und keine Fußnote.
    public static func nettoFarbe(_ sp: AnlageSpeicherOut) -> Farbwert {
        switch sp.netWord {
        case "lädt": return Anlagenschema.Farbwerte.pvWeich
        case "entlädt": return Anlagenschema.Farbwerte.speicher
        default: return Marken.last
        }
    }

    /// Die Zeile unter dem Glas: „24 kWh nutzbar · 1000 l“ (`Schema.tsx:363-366`).
    ///
    /// **Ganze Zahlen und kein Fassungsvermögen.** Die App schrieb hier „nutzbar von Fassung“ mit
    /// je einer Nachkommastelle; die Vorlage nennt die Fassung an dieser Stelle nicht, weil sie
    /// unter dem Glas nichts erklärt - das Glas *ist* die Fassung. Fehlt der nutzbare Inhalt,
    /// entfällt der erste Teil samt Mittelpunkt, statt einen Strich zu zeigen.
    public static func glaszeile(_ sp: AnlageSpeicherOut) -> String {
        let liter = "\(Int(sp.volumeLiters.rounded())) l"
        guard let nutzbar = sp.usableKwh, nutzbar.isFinite else { return liter }
        return "\(Int(nutzbar.rounded())) kWh nutzbar · \(liter)"
    }

    // MARK: - Der Fuß: drei Spalten Lesehilfe

    /// Ein Stück Satz, hervorgehoben oder nicht (`.anlage-fuss .m`, `globals.css:595`).
    public struct Satzstueck: Sendable, Hashable {
        public let text: String
        public let betont: Bool

        public init(_ text: String, betont: Bool = false) {
            self.text = text
            self.betont = betont
        }
    }

    /// Eine Spalte des Fußes: Überschrift und ein Absatz aus Stücken.
    public struct Lesestueck: Sendable, Hashable, Identifiable {
        public let titel: String
        public let stuecke: [Satzstueck]

        public var id: String { titel }
        /// Der Absatz ohne Hervorhebungen - für die Bedienungshilfe und für die Prüfung.
        public var text: String { stuecke.map(\.text).joined() }

        public init(titel: String, stuecke: [Satzstueck]) {
            self.titel = titel
            self.stuecke = stuecke
        }
    }

    /// Die drei Spalten, wörtlich aus `Anlage.tsx:91-124`.
    ///
    /// **Drei Aussagen hatte die App-Fassung nicht**, und es sind genau die, die über die
    /// Zeichnung hinausgehen: dass jedes Gerät antippbar ist und dahinter seine Seite liegt,
    /// dass sich die vier Systeme *nur* im Speicher berühren, und dass das Trinkwasser keine
    /// Pumpe hat, sondern der Leitungsdruck es treibt. Ohne den letzten Satz sieht ein Kreis
    /// ohne Pumpenpunkt nach einem Fehler in der Zeichnung aus.
    public static let fussspalten: [Lesestueck] = [
        Lesestueck(
            titel: "Lesen",
            stuecke: [
                Satzstueck(
                    "Licht wandert in Flussrichtung, sein Tempo ist die Leistung. Die Farbe "
                        + "eines Rohrs ist die Temperatur seines Wassers, auf derselben Skala "
                        + "wie das Glas. Ein ruhender Punkt auf dem Rohr ist eine Pumpe; sie "
                        + "leuchtet, wenn sie läuft. Jedes Gerät lässt sich antippen; dahinter "
                        + "liegt seine Seite, dieselbe wie von der Startseite aus.")
            ]),
        Lesestueck(
            titel: "Vier getrennte Systeme",
            stuecke: [
                Satzstueck("Sie berühren sich nur im Speicher. Der "),
                Satzstueck("Ofen", betont: true),
                Satzstueck(" speist ganz oben ein und holt unten zurück. Die "),
                Satzstueck("Wärmepumpe", betont: true),
                Satzstueck(" speist in der Mitte ein und holt unten zurück. Der "),
                Satzstueck("Heizkreis", betont: true),
                Satzstueck(" nimmt aus der Mitte und gibt unten zurück. Das "),
                Satzstueck("Trinkwasser", betont: true),
                Satzstueck(
                    " läuft unten kalt nach und wird ganz oben warm entnommen; es hat keine "
                        + "Pumpe, der Leitungsdruck treibt es. Ofen und Wärmepumpe holen ihren "
                        + "Rücklauf "),
                Satzstueck("gemeinsam", betont: true),
                Satzstueck(" an der untersten Spitze und teilen ihn erst danach."),
            ]),
        Lesestueck(
            titel: "Gemessen und gerechnet",
            stuecke: [
                Satzstueck(
                    "Die Wärmepumpe zeigt ihren Strom; ihre Wärme misst heute niemand, Vorlauf "
                        + "und COP kommen mit dem Bus. Der Ofen wird aus seiner Stufe nach "
                        + "Datenblatt geschätzt. Die "),
                Satzstueck("Nettoleistung des Speichers", betont: true),
                Satzstueck(
                    " ist aus den vier Fühlern gerechnet: die Änderung des Energieinhalts über "
                        + "die letzte Viertelstunde, lädt oder entlädt. Beim Warmwasser wird "
                        + "nicht gemessen, sondern "),
                Satzstueck("erkannt", betont: true),
                Satzstueck(
                    ": Ein Anlegefühler am Auslass springt an, sobald warmes Wasser durch die "
                        + "Leitung läuft. Das sagt, dass gezapft wird und seit wann, nicht wie "
                        + "viel."),
            ]),
    ]
}
