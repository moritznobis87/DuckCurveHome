import Foundation

/// Der Betrieb der Wärmepumpe über Tage als fertiges Bild: vier Fragen, vier Diagramme.
///
/// **Warum vier und welche** - der Dateikopf der Vorlage sagt es
/// (`apps/web/src/components/waermepumpe/betrieb.ts:6-19`), und er soll beim Umbau nicht
/// verloren gehen:
///
/// 1. Wie lange lief sie, und womit? Gestapelte Balken je Tag: Heizen, Abtauen, Heizstab.
/// 2. Wie gut war sie? Die Arbeitszahl je Tag, einmal über alles (mit Anlauf, Abtauen und
///    Heizstab) und einmal nur im eingeschwungenen Heizbetrieb. **Der Abstand der beiden
///    Linien ist die Aussage der Karte:** er ist, was Takten und Abtauen gekostet haben.
/// 3. Taktet sie? Die Lauflängen als Balken je Klasse. Viele Läufe unter zehn Minuten sind
///    Läufe, die nie aus dem Anlauf herauskommen.
/// 4. Was verlangt der Regler? Der Vorlauf-Sollwert je Stunde über der Außentemperatur - die
///    Heizkurve, wie sie am Gerät eingestellt ist, mit der Geraden durch die Punkte.
///
/// **Was hier liegt und warum.** Jede Schwelle, jede Rundung, jede Textauswahl und jede
/// Farbzuordnung dieser Seite. Nicht aus Ordnungsliebe: eine Rechnung in einer `View` prüft
/// niemand nach, und drei der Zahlen dieser Seite rundet die Vorlage anders, als man es von
/// Hand täte - `startsJeTag` teilt durch die Tage **mit** Betrieb, der Abtauanteil hat eine
/// Nachkommastelle, der Kurzanteil keine. Jede dieser drei Stellen hat einen Test.
///
/// **Lücken bleiben Lücken.** Ein Tag ohne Lauf hat keine Arbeitszahl, und eine Linie über
/// diese Lücke hinweg erfindet eine Messung (`connectNulls: false`, `betrieb.ts:137`). Swift
/// Charts kennt dafür keinen Schalter, also zerlegt ``copstuecke(_:)`` die beiden Kurven in
/// zusammenhängende Stücke - wie es ``Wirkungsbild`` für die Antwortfächer tut.
public enum Betriebsbild {

    // MARK: - Wörter, die an mehr als einer Stelle stehen

    /// Was in einer Zelle und auf einer Kachel steht, wo kein Wert da ist.
    ///
    /// **Ein Fragezeichen und nicht ``Formate/leer``.** Die Vorlage schreibt auf dieser Seite
    /// durchweg „?“ (`Betrieb.tsx:74-77`, `:159-168`), und das ist hier der richtige Ton: der
    /// Strich der übrigen Seiten heißt „es gibt den Wert nicht“, das Fragezeichen heißt „in
    /// diesen Tagen kam keiner“ - eine Auszählung, die etwas nicht ausgezählt hat.
    public static let fehlt = "?"

    /// Der Satz, der über der Seite steht, wenn der Dienst keinen geschickt hat
    /// (`Betrieb.tsx:59`).
    public static let keinKopfsatz = "Noch nichts auszuzählen."

    /// Solange die erste Antwort unterwegs ist (`Betrieb.tsx:46`).
    public static let ladesatz = "Der Betrieb wird ausgezählt …"

    /// Wenn noch nichts da ist und die Abfrage scheitert (`Betrieb.tsx:32`).
    public static let fehlersatz = "Die Auszählung ist gerade nicht zu erreichen."

    /// Was statt des Klassendiagramms steht (`Betrieb.tsx:114`).
    ///
    /// Das Erbe des 14.11.2026, das `bilanz.ts:5-9` festhält: die Seite zeigte ein leeres Bild
    /// und sagte nicht, warum. Seitdem sagt sie, woran es lag.
    public static let keinLaufSatz =
        "Noch kein vollständiger Lauf: ein Lauf zählt, wenn sein Anfang und sein Ende in den "
        + "Daten liegen."

    /// Was statt der Heizkurve steht (`Betrieb.tsx:128`).
    public static let keineStundeSatz =
        "Noch keine Stunde im Heizbetrieb mit Sollwert und Außentemperatur."

    /// Der Erklärsatz unter der Arbeitszahl (`Betrieb.tsx:101`), wörtlich.
    public static let arbeitszahlsatz =
        "„Über alles“ enthält jeden Anlauf, das Abtauen und den Heizstab; „im Heizbetrieb“ "
        + "zählt nur eingeschwungene Fenster. Liegt die erste Linie darunter, ist der Abstand, "
        + "was Takten und Abtauen an dem Tag gekostet haben."

    /// Der Erklärsatz unter der Heizkurve, wenn es keine Gerade gibt (`Betrieb.tsx:123`).
    public static let keineGeradeSatz =
        "Für eine Gerade braucht es mindestens sechs Stunden Heizbetrieb bei "
        + "Außentemperaturen, die drei Grad auseinanderliegen."

    /// Was an den Achsen der vier Diagramme steht - **mit anderen Wörtern als die Vorlage.**
    ///
    /// **Warum unter dem Bild und nicht an der Achse.** ECharts schreibt den Namen an die Achse
    /// selbst; Swift Charts kennt dafür keinen Platz. Weglassen geht nicht: ohne die Einheit ist
    /// die Zahl an der Achse eine Zahl. Also eine leise Zeile unter dem Bild - so hat es die App
    /// bei der Heizkurve schon gehalten („Außentemperatur in °C“).
    ///
    /// **Und daraus folgt die Abweichung.** Die Vorlage schreibt an die Achsen „Stunden“
    /// (`betrieb.ts:112`), „COP“ (`:152`) und „Läufe“ (`:165`). Ein Wort an der Achse steht neben
    /// seinen Zahlen und braucht nichts weiter; dieselbe Zeile unter dem Bild steht allein, und
    /// „Stunden“ allein sagt nicht, wovon - je Tag oder über den Zeitraum. Also hier um den
    /// Bezug ergänzt: `achseStunden`, `achseCop` und `achseLaeufe` sind **nicht** die Wörter der
    /// Vorlage, sondern deren Namen am neuen Ort. Nur `achseHeizkurve` gibt beide Namen der
    /// Vorlage wieder (`:195-196`), in einer Zeile zusammengezogen, weil die eine Zeile unter
    /// dem Bild für x und y zugleich steht.
    public static let achseStunden = "Stunden je Tag"
    public static let achseCop = "Arbeitszahl (COP)"
    public static let achseLaeufe = "Läufe je Klasse"
    public static let achseHeizkurve = "Vorlauf °C über Außentemperatur °C"

    /// Die Namen der beiden Arbeitszahlreihen, wie die Legende sie nennt (`betrieb.ts:154`).
    public enum Copreihe: String, Sendable, Hashable, CaseIterable {
        case heizbetrieb = "im Heizbetrieb"
        case ueberAlles = "über alles"
    }

    // MARK: - Die Weiche

    /// Lief sie im Zeitraum überhaupt? (`Betrieb.tsx:48`)
    ///
    /// **Bei `false` fallen alle vier Diagramme weg**, Kopf, Kacheln, Tabelle und Fuß bleiben
    /// (`Betrieb.tsx:91`). Das ist keine Sparmaßnahme: vier leere Achsen sagen weniger als
    /// keine, und die Tabelle sagt bereits, dass nichts lief.
    public static func lief(_ b: BetriebOut) -> Bool {
        (b.laufMin ?? 0) > 0
    }

    /// Der führende Satz der Seite: der **erste** aus `saetze_de` (`Betrieb.tsx:52`, `:59`).
    public static func kopfsatz(_ b: BetriebOut) -> String {
        b.saetzeDe.first ?? keinKopfsatz
    }

    /// Die Sätze, die in die Karte „Was die Auszählung zeigt“ gehören - alle außer dem ersten.
    public static func weitereSaetze(_ b: BetriebOut) -> [String] {
        Array(b.saetzeDe.dropFirst())
    }

    /// Die Standzeile unter dem Kopfsatz: „Letzte 14 Tage“, bei stehendem Fehler mit Anhang.
    ///
    /// **Der Fehler hängt sich hier an und ersetzt die Seite nicht** (`Betrieb.tsx:60-62`).
    /// Liegen schon Zahlen vor, ist eine gescheiterte Auffrischung eine Randnotiz und kein
    /// Grund, das Gezeigte wegzunehmen.
    public static func standzeile(_ b: BetriebOut, fehler: String? = nil) -> String {
        let grund = "Letzte \(b.zeitraumTage) Tage"
        guard let fehler, !fehler.isEmpty else { return grund }
        return grund + " · " + fehler
    }

    // MARK: - Die vier Kacheln

    /// Die vier Kennzahlen der Vorlage, in ihrer Reihenfolge (`Betrieb.tsx:74-77`).
    ///
    /// **Die erste führt**, und zwar in Bernstein: `tone="amber"` an der einzigen der vier
    /// (`Betrieb.tsx:74`). Starts je Tag ist die Zahl, an der Takten zu erkennen ist - sie
    /// gehört an die Stelle, die `handy.css` für „eine Zahl führt“ freihält.
    public static func kacheln(_ b: BetriebOut) -> [Kennzahl] {
        [startskachel(b), medianKachel(b), abtaukachel(b), arbeitszahlkachel(b)]
    }

    private static func startskachel(_ b: BetriebOut) -> Kennzahl {
        let je = startsJeTag(b)
        return Kennzahl(
            wort: "Starts je Tag",
            wert: je.map { Formate.zahl($0, stellen: 1) } ?? fehlt,
            dazu: "an Tagen mit Betrieb",
            ton: je == nil ? .gedaempft : .bernstein
        )
    }

    private static func medianKachel(_ b: BetriebOut) -> Kennzahl {
        let kurz = kurzAnteil(b)
        return Kennzahl(
            wort: "Ein Lauf dauert",
            wert: b.laufMedianMin.map { Formate.dauer(minuten: Int($0.rounded())) } ?? fehlt,
            // `Formate.prozent` rundet auf ganze Prozent - dieselbe Rundung wie
            // `Math.round(kurz * 100)` in `Betrieb.tsx:75`.
            dazu: kurz.map { "\(Formate.prozent($0)) unter zehn Minuten" } ?? "im Mittel",
            ton: b.laufMedianMin == nil ? .gedaempft : .normal
        )
    }

    private static func abtaukachel(_ b: BetriebOut) -> Kennzahl {
        let anteil = abtauAnteil(b)
        return Kennzahl(
            wort: "Abtauen",
            // **Eine Nachkommastelle, nicht null.** `zahl(abtau * 100)` nimmt die Vorgabe der
            // Vorlage (`betrieb.ts:21`), und der Unterschied zwischen 6,7 und 7,4 Prozent der
            // Laufzeit ist an einer Wärmepumpe eine Nachricht.
            wert: anteil.map { Formate.zahl($0 * 100, stellen: 1) } ?? fehlt,
            einheit: "%",
            dazu: lief(b) ? "der Laufzeit · \(b.abtauungen ?? 0)-mal" : "der Laufzeit",
            ton: anteil == nil ? .gedaempft : .normal
        )
    }

    private static func arbeitszahlkachel(_ b: BetriebOut) -> Kennzahl {
        Kennzahl(
            wort: "Arbeitszahl über alles",
            wert: b.copGesamt.map { Formate.zahl($0, stellen: 2) } ?? fehlt,
            dazu: b.copHeizen.map { "im Heizbetrieb \(Formate.zahl($0, stellen: 2))" }
                ?? "Wärme durch Strom",
            ton: b.copGesamt == nil ? .gedaempft : .normal
        )
    }

    // MARK: - Die Rechnungen hinter den Kacheln

    /// Die Stunden eines Tages nach dem, was die Maschine tat (`betrieb.ts:49-52`).
    ///
    /// Heizen ist der Lauf ohne das Abtauen und ohne die Minuten mit Heizstab; zusammen
    /// ergeben die drei genau die Laufzeit. `max(0, …)` steht dort, weil zwei getrennt
    /// gezählte Posten in Randminuten zusammen über die Laufzeit hinausgehen können - ein
    /// negativer Balkenteil wäre dann eine Aussage, die die Zählung nicht hergibt.
    public static func stundenteile(_ t: BetriebTagOut) -> Stundenteile {
        let heizen = Double(max(0, t.laufMin - t.abtauMin - t.zusatzMin))
        return Stundenteile(
            heizen: heizen / 60,
            abtauen: Double(t.abtauMin) / 60,
            heizstab: Double(t.zusatzMin) / 60
        )
    }

    public struct Stundenteile: Sendable, Hashable {
        public let heizen: Double
        public let abtauen: Double
        public let heizstab: Double

        public init(heizen: Double, abtauen: Double, heizstab: Double) {
            self.heizen = heizen
            self.abtauen = abtauen
            self.heizstab = heizstab
        }
    }

    /// Starts je Tag, **über die Tage mit Betrieb** (`betrieb.ts:55-58`).
    ///
    /// **Das ist der Unterschied, und er ist kein Zehntel.** Teilte man durch den ganzen
    /// Zeitraum, drückte jeder Tag ohne Lauf den Schnitt - in einer milden Woche sieht eine
    /// taktende Maschine dann ruhig aus. `betrieb.test.ts:58-60` hält es ausdrücklich fest.
    public static func startsJeTag(_ b: BetriebOut) -> Double? {
        let tage = b.tage.filter { $0.laufMin > 0 }.count
        guard tage > 0, let starts = b.starts else { return nil }
        return Double(starts) / Double(tage)
    }

    /// Der Anteil des Abtauens an der Laufzeit, 0 bis 1 (`betrieb.ts:61-63`).
    public static func abtauAnteil(_ b: BetriebOut) -> Double? {
        guard let lauf = b.laufMin, lauf > 0 else { return nil }
        return Double(b.abtauMin ?? 0) / Double(lauf)
    }

    /// Der Anteil der vollständigen Läufe, die kürzer als zehn Minuten waren
    /// (`betrieb.ts:66-70`).
    ///
    /// Die kurzen sind die Klasse mit `vonMin == 0` - welche Grenze „kurz“ heißt, entscheidet
    /// der Dienst mit seiner Klassenbildung und nicht die Anzeige.
    public static func kurzAnteil(_ b: BetriebOut) -> Double? {
        let alle = laeufe(b)
        guard alle > 0 else { return nil }
        let kurz = b.klassen.first { $0.vonMin == 0 }?.laeufe ?? 0
        return Double(kurz) / Double(alle)
    }

    /// Wie viele vollständige Läufe die Klassen zusammen zählen (`Betrieb.tsx:51`).
    public static func laeufe(_ b: BetriebOut) -> Int {
        b.klassen.reduce(0) { $0 + $1.laeufe }
    }

    /// Der Name einer Klasse der Lauflängen (`betrieb.ts:72-76`).
    ///
    /// „unter 10 min“, „10 bis 20“, „ab 90 min“ - und nicht „0–10“ und „90+“. Die Wörter sind
    /// der Unterschied: eine Spanne mit Bindestrich liest man als Zahlenpaar, „unter zehn
    /// Minuten“ liest man als Urteil, und genau als Urteil ist die Klasse gemeint.
    ///
    /// **Die offene Grenze wird vor der unteren geprüft**, anders als in der Vorlage. Dort
    /// steht `von_min === 0` zuerst, was bei einer einzigen, nach oben offenen Klasse
    /// („ab 0 min“) „unter null min“ ergäbe. Der Fall kommt vom Dienst nicht, aber ein Satz,
    /// der für keine Eingabe falsch ist, kostet hier nichts.
    public static func klassenName(_ k: BetriebKlasseOut) -> String {
        guard let bis = k.bisMin else { return "ab \(k.vonMin) min" }
        if k.vonMin == 0 { return "unter \(bis) min" }
        return "\(k.vonMin) bis \(bis)"
    }

    /// Der Satz unter dem Klassendiagramm (`Betrieb.tsx:111`), mit richtigem Numerus.
    public static func laufzahlsatz(_ b: BetriebOut) -> String {
        let n = laeufe(b)
        let zahlwort = n == 1 ? "1 vollständiger Lauf" : "\(n) vollständige Läufe"
        return zahlwort
            + ". Die ersten zehn Minuten eines Laufs sind Anlauf; ein Lauf, der kürzer ist, "
            + "kommt nie in den Bereich, in dem die Maschine gut arbeitet."
    }

    // MARK: - Diagramm 1: Laufstunden je Tag

    /// Ein Wert an einer Wortachse.
    public struct Balkenwert: Sendable, Hashable {
        public let beschriftung: String
        public let wert: Double

        public init(beschriftung: String, wert: Double) {
            self.beschriftung = beschriftung
            self.wert = wert
        }
    }

    /// Eine Reihe gestapelter Balken, mit ihrer Farbe.
    public struct Balkenreihe: Sendable, Hashable, Identifiable {
        public let name: String
        public let farbe: Farbwert
        public let werte: [Balkenwert]
        public var id: String { name }

        public init(name: String, farbe: Farbwert, werte: [Balkenwert]) {
            self.name = name
            self.farbe = farbe
            self.werte = werte
        }
    }

    /// Die drei gestapelten Reihen der Laufstunden, in der Stapelordnung der Vorlage
    /// (`betrieb.ts:113`).
    ///
    /// **Die Farben sind die der Vorlage und keine naheliegenden.** Heizen ist die Farbe der
    /// Wärmepumpe (#E0966B) - sie hat eine, überall (`palette.ts:46-53`). Abtauen ist das
    /// Blaugrau des Speichers (#7FA3B3), Heizstab das Rot des Netzbezugs (#E0533D) - und
    /// **nicht** ``Marken/achtung``, das ist Bernstein und hieße „Vorsicht“, wo nur eine
    /// Minute mit Heizstab gemeint ist.
    ///
    /// **Auf zwei Stellen gerundet** (`betrieb.ts:102`): die Stapelhöhe eines Tages soll sich
    /// aus den gezeigten Zahlen nachrechnen lassen.
    public static func stundenreihen(_ b: BetriebOut) -> [Balkenreihe] {
        let teile = b.tage.map { (Tag.punkt($0.tag), stundenteile($0)) }
        func reihe(_ name: String, _ farbe: Farbwert, _ wert: (Stundenteile) -> Double)
            -> Balkenreihe
        {
            Balkenreihe(
                name: name, farbe: farbe,
                werte: teile.map {
                    Balkenwert(beschriftung: $0.0, wert: (wert($0.1) * 100).rounded() / 100)
                })
        }
        return [
            reihe("Heizen", Marken.waermepumpe, \.heizen),
            reihe("Abtauen", Marken.diagrammSpeicher, \.abtauen),
            reihe("Heizstab", Marken.diagrammNetz, \.heizstab),
        ]
    }

    // MARK: - Diagramm 2: Arbeitszahl je Tag

    /// Ein Punkt einer Arbeitszahlkurve.
    public struct Coppunkt: Sendable, Hashable, Identifiable {
        public let beschriftung: String
        public let wert: Double
        public var id: String { beschriftung }

        public init(beschriftung: String, wert: Double) {
            self.beschriftung = beschriftung
            self.wert = wert
        }
    }

    /// Ein zusammenhängendes Stück einer Arbeitszahlkurve - zwischen zwei Stücken liegt ein
    /// Tag ohne Lauf.
    public struct Copstueck: Sendable, Hashable, Identifiable {
        public let reihe: Copreihe
        /// Laufende Nummer des Stücks innerhalb seiner Reihe.
        public let nummer: Int
        public let punkte: [Coppunkt]
        /// Der Reihenschlüssel für Swift Charts: je Stück ein eigener, sonst wird aus allen
        /// zusammen eine Linie.
        public var id: String { "\(reihe.rawValue) \(nummer)" }

        public init(reihe: Copreihe, nummer: Int, punkte: [Coppunkt]) {
            self.reihe = reihe
            self.nummer = nummer
            self.punkte = punkte
        }
    }

    /// Die beiden Arbeitszahlkurven, in zusammenhängende Stücke zerlegt.
    ///
    /// **Warum Stücke und nicht eine Reihe mit Löchern.** `connectNulls: false`
    /// (`betrieb.ts:137`) sagt in ECharts: ein Tag ohne Lauf bleibt eine Lücke. Swift Charts
    /// hat dafür keinen Schalter und verbindet über `nil` hinweg, solange alles eine Reihe
    /// ist - eine Linie über die Lücke behauptete eine Arbeitszahl an einem Tag, an dem die
    /// Maschine stand. Also je Stück ein `series:`-Schlüssel, und das Zerlegen steht hier und
    /// nicht in der Ansicht.
    public static func copstuecke(_ b: BetriebOut) -> [Copstueck] {
        Copreihe.allCases.flatMap { stuecke(b, reihe: $0) }
    }

    private static func stuecke(_ b: BetriebOut, reihe: Copreihe) -> [Copstueck] {
        func wert(_ t: BetriebTagOut) -> Double? {
            switch reihe {
            case .heizbetrieb: return t.copHeizen
            case .ueberAlles: return t.copTag
            }
        }
        var aus: [Copstueck] = []
        var jetzt: [Coppunkt] = []
        func abschliessen() {
            guard !jetzt.isEmpty else { return }
            aus.append(Copstueck(reihe: reihe, nummer: aus.count, punkte: jetzt))
            jetzt = []
        }
        for t in b.tage {
            if let v = wert(t), v.isFinite {
                jetzt.append(Coppunkt(beschriftung: Tag.punkt(t.tag), wert: v))
            } else {
                abschliessen()
            }
        }
        abschliessen()
        return aus
    }

    /// Die Farbe einer Arbeitszahlreihe (`betrieb.ts:154`).
    ///
    /// **Das Paar ist mit Bedacht gewählt** (`palette.ts:46-53`): „im Heizbetrieb“ ist die
    /// Farbe der Wärmepumpe, „über alles“ das helle Grau des übrigen Hauses (#CFD8DC). Das
    /// Sand des Haushalts wäre bei Deuteranopie dieselbe Farbe wie das Orange der Pumpe - und
    /// genau diese zwei Linien liegen hier in einem Gitter übereinander.
    public static func copfarbe(_ r: Copreihe) -> Farbwert {
        switch r {
        case .heizbetrieb: return Marken.waermepumpe
        case .ueberAlles: return Marken.haus
        }
    }

    /// Die Grenzen der Achse der Arbeitszahl: ganze Zahlen um die Werte, mindestens 2 bis 5
    /// (`betrieb.ts:118-122`).
    ///
    /// Die untere Grenze ist kein Nullpunkt: eine Arbeitszahl unter zwei ist ein Befund, und
    /// auf einer Achse von 0 bis 5 wäre der Abstand der beiden Linien - die Aussage der Karte -
    /// halb so groß.
    public static func copSpanne(_ b: BetriebOut) -> ClosedRange<Double> {
        let werte = b.tage.flatMap { [$0.copTag, $0.copHeizen] }
            .compactMap { $0 }
            .filter { $0.isFinite }
        guard let klein = werte.min(), let gross = werte.max() else { return 2...5 }
        return min(2, klein.rounded(.down))...max(5, gross.rounded(.up))
    }

    // MARK: - Diagramm 3: Wie lange ein Lauf dauert

    /// Ganze Zahlen an der Achse der Läufe (`minInterval: 1`, `betrieb.ts:156`).
    ///
    /// **Warum gerechnet.** Eine Achse, auf der „2,5 Läufe“ steht, zählt etwas, das es nicht
    /// gibt. ECharts verhindert das mit einem Schalter; Swift Charts braucht die Marken.
    public static func laufmarken(_ b: BetriebOut, hoechstens: Int = 5) -> [Double] {
        let hoechst = max(1, b.klassen.map(\.laeufe).max() ?? 1)
        let felder = max(1, hoechstens - 1)
        let schritt = max(1, Int((Double(hoechst) / Double(felder)).rounded(.up)))
        var aus: [Double] = []
        var i = 0
        while i <= hoechst {
            aus.append(Double(i))
            i += schritt
        }
        if (aus.last ?? 0) < Double(hoechst) { aus.append(Double(i)) }
        return aus
    }

    // MARK: - Diagramm 4: Die Heizkurve des Reglers

    /// Ein Punkt der Heizkurve: Außentemperatur gegen Vorlauf.
    public struct Kurvenpunkt: Sendable, Hashable, Identifiable {
        public let aussen: Double
        public let vorlauf: Double
        /// Die Stunde, aus der der Punkt kommt - `nil` an den Enden der gerechneten Geraden.
        public let stunde: BetriebStundeOut?
        public var id: String {
            "\(aussen) \(vorlauf) \(stunde?.at ?? "")"
        }

        public init(aussen: Double, vorlauf: Double, stunde: BetriebStundeOut? = nil) {
            self.aussen = aussen
            self.vorlauf = vorlauf
            self.stunde = stunde
        }
    }

    /// Die gerechnete Gerade als **zwei** Punkte (`betrieb.ts:204`).
    ///
    /// **Zwei genügen für eine Gerade**, und die App rechnete vierundzwanzig
    /// (`WaermepumpeSeiten.swift:356-362` vor dem Umbau). Vierundzwanzig Stützstellen sind
    /// nicht genauer, nur mehr - und sie lagen in der Seite, wo niemand nachrechnet, ob
    /// `a + b·t` auch die Punktwolke trifft, über die sie gezeichnet werden.
    public static func geradenpunkte(_ hk: BetriebHeizkurveOut) -> [Kurvenpunkt] {
        [hk.aussenVonC, hk.aussenBisC].map {
            Kurvenpunkt(aussen: $0, vorlauf: hk.a + hk.b * $0)
        }
    }

    /// Die Sollwerte jeder Stunde (`betrieb.ts:226-234`) - die Reihe, die obenauf liegt.
    public static func sollpunkte(_ b: BetriebOut) -> [Kurvenpunkt] {
        b.stunden.map { Kurvenpunkt(aussen: $0.aussenC, vorlauf: $0.sollC, stunde: $0) }
    }

    /// Der **erreichte** Vorlauf, nur für die Stunden, die einen melden (`betrieb.ts:216-223`).
    ///
    /// Die Vorlage zeichnet sie als Raute und nicht als zweiten Kreis: „verlangt“ und
    /// „erreicht“ sind zwei Aussagen, und wer sie unterscheiden soll, muss sie an der Form
    /// unterscheiden können und nicht nur an der Farbe.
    public static func erreichtpunkte(_ b: BetriebOut) -> [Kurvenpunkt] {
        b.stunden.compactMap { s in
            s.vorlaufC.map { Kurvenpunkt(aussen: s.aussenC, vorlauf: $0, stunde: s) }
        }
    }

    /// Welche Reihen die Legende nennt, in der Folge der Vorlage (`betrieb.ts:187`).
    ///
    /// Nur die, die es gibt: eine Legende, die eine Reihe nennt, die nicht im Bild ist, lässt
    /// einen danach suchen.
    public static func heizkurvenreihen(_ b: BetriebOut) -> [String] {
        var aus = ["Sollwert"]
        if !erreichtpunkte(b).isEmpty { aus.append("erreicht") }
        if b.heizkurve != nil { aus.append("Gerade") }
        return aus
    }

    /// Die Spannen der beiden Achsen der Heizkurve.
    ///
    /// **Beide Achsen ohne Nullzwang** (`scale: true`, `betrieb.ts:195-196`). Vorlauftemperaturen
    /// liegen zwischen 30 und 45 Grad; eine Achse ab Null drückt die Punktwolke in das obere
    /// Drittel, und dann ist die Steigung der Heizkurve - der Gegenstand der Karte - nicht mehr
    /// zu sehen. Die Gerade zählt mit, damit sie nicht aus dem Bild läuft.
    public static func heizkurvenspannen(_ b: BetriebOut)
        -> (aussen: ClosedRange<Double>, vorlauf: ClosedRange<Double>)?
    {
        var punkte = sollpunkte(b) + erreichtpunkte(b)
        if let hk = b.heizkurve { punkte += geradenpunkte(hk) }
        guard !punkte.isEmpty else { return nil }
        guard let x = Achse.spanne(werte: punkte.map { $0.aussen }, rand: 1, mindestens: 4),
            let y = Achse.spanne(werte: punkte.map { $0.vorlauf }, rand: 1, mindestens: 4)
        else { return nil }
        return (aussen: x, vorlauf: y)
    }

    /// Was unter der Heizkurve steht: die Formel in Mono, dann der Satz (`Betrieb.tsx:122-125`).
    ///
    /// Getrennt, weil die Vorlage die Formel in `span.mono` setzt und den Rest nicht - und
    /// weil ohne Gerade an der Stelle der Formel ein ganz anderer Satz steht.
    public struct Heizkurvenfuss: Sendable, Hashable {
        public let formel: String?
        public let satz: String

        public init(formel: String?, satz: String) {
            self.formel = formel
            self.satz = satz
        }
    }

    public static func heizkurvenfuss(_ b: BetriebOut) -> Heizkurvenfuss {
        guard let hk = b.heizkurve else {
            return Heizkurvenfuss(formel: nil, satz: keineGeradeSatz)
        }
        let streuung = hk.r2.map { ", erklärt \(Formate.prozent($0)) der Streuung" } ?? ""
        return Heizkurvenfuss(
            formel: hk.formelDe,
            satz: "aus \(hk.n) Stunden\(streuung). Jeder Punkt ist eine Stunde im Heizbetrieb. "
                + "Liegen Punkte weit über der Geraden, hat der Regler dort für Warmwasser "
                + "mehr verlangt."
        )
    }

    // MARK: - Das Abgelesene

    /// Eine Zeile der Auskunft an der berührten Stelle: Wort und Wert.
    public struct Auskunftszeile: Sendable, Hashable, Identifiable {
        public let wort: String
        public let wert: String
        public var id: String { wort }

        public init(wort: String, wert: String) {
            self.wort = wort
            self.wert = wert
        }
    }

    /// Was an einem Tag des Laufstundenbilds steht (`betrieb.ts:81-91`).
    ///
    /// **Nur, was es an dem Tag gab.** Abtauen und Heizstab fehlen, wenn keine Minute darauf
    /// ging - eine Zeile „Heizstab 0 min“ an dreizehn von vierzehn Tagen ist Rauschen, und
    /// `betrieb.test.ts` prüft genau das.
    public static func tagzeilen(_ t: BetriebTagOut) -> [Auskunftszeile] {
        var aus = [
            Auskunftszeile(wort: "Lauf", wert: Formate.dauer(minuten: t.laufMin)),
            Auskunftszeile(wort: "Starts", wert: String(t.starts)),
        ]
        if t.abtauMin > 0 {
            aus.append(
                Auskunftszeile(
                    wort: "Abtauen",
                    wert: "\(Formate.dauer(minuten: t.abtauMin)) · \(t.abtauungen)-mal"))
        }
        if t.zusatzMin > 0 {
            aus.append(
                Auskunftszeile(wort: "Heizstab", wert: Formate.dauer(minuten: t.zusatzMin)))
        }
        aus.append(Auskunftszeile(wort: "Strom", wert: Formate.kwh(t.stromKwh)))
        if let a = t.aussenC {
            aus.append(Auskunftszeile(wort: "draußen", wert: Formate.celsius(a, stellen: 1)))
        }
        return aus
    }

    /// Was an einem Tag des Arbeitszahlbilds steht (`betrieb.ts:146`).
    public static func copzeilen(_ t: BetriebTagOut) -> [Auskunftszeile] {
        var aus = [
            Auskunftszeile(
                wort: Copreihe.heizbetrieb.rawValue,
                wert: t.copHeizen.map { Formate.zahl($0, stellen: 2) } ?? fehlt),
            Auskunftszeile(
                wort: Copreihe.ueberAlles.rawValue,
                wert: t.copTag.map { Formate.zahl($0, stellen: 2) } ?? fehlt),
        ]
        if let w = t.waermeKwh {
            aus.append(Auskunftszeile(wort: "Wärme", wert: Formate.kwh(w)))
        }
        return aus
    }

    /// Was an einer Stunde der Heizkurve steht (`betrieb.ts:179-182`).
    public static func stundenzeilen(_ s: BetriebStundeOut) -> [Auskunftszeile] {
        var aus = [
            Auskunftszeile(wort: "draußen", wert: Formate.celsius(s.aussenC, stellen: 1)),
            Auskunftszeile(wort: "Sollwert", wert: Formate.celsius(s.sollC, stellen: 1)),
        ]
        if let v = s.vorlaufC {
            aus.append(Auskunftszeile(wort: "erreicht", wert: Formate.celsius(v, stellen: 1)))
        }
        aus.append(
            Auskunftszeile(
                wort: Copreihe.heizbetrieb.rawValue,
                wert: "\(s.minuten)\(Formate.schmalesLeerzeichen)min"))
        return aus
    }

    /// Welcher Tag an der berührten Stelle der Wortachse steht.
    ///
    /// **Warum im Kern.** Die Vorlage bekommt von ECharts einen `dataIndex` und greift damit in
    /// `d.tage` (`betrieb.ts:108`); Swift Charts liefert statt eines Index den Wert der Achse,
    /// hier also „14.11.“. Der Weg zurück zum Tag ist eine Zuordnung, die stimmen muss - stünde
    /// sie in der Ansicht, läse eine falsche Zeile ihre Zahlen aus dem falschen Tag.
    public static func tagMit(_ b: BetriebOut, beschriftung: String?) -> BetriebTagOut? {
        guard let beschriftung else { return nil }
        return b.tage.first { Tag.punkt($0.tag) == beschriftung }
    }

    /// Welche Klasse an der berührten Stelle steht (`betrieb.ts:162`).
    public static func klasseMit(_ b: BetriebOut, name: String?) -> BetriebKlasseOut? {
        guard let name else { return nil }
        return b.klassen.first { klassenName($0) == name }
    }

    /// Welche Stunde der berührten Außentemperatur am nächsten liegt.
    ///
    /// **Eine Punktwolke hat keine Achse, an der man ablesen kann.** ECharts trifft mit
    /// `trigger: "item"` genau den Punkt unter dem Finger (`betrieb.ts:194`); Swift Charts gibt
    /// an einer Werteachse nur die Stelle zurück, an der berührt wurde. Also die nächste Stunde
    /// in x-Richtung - bei gleichem Abstand die erste, damit dieselbe Berührung immer dieselbe
    /// Zeile zeigt.
    public static func stundeBei(_ b: BetriebOut, aussen: Double?) -> BetriebStundeOut? {
        guard let aussen, aussen.isFinite else { return nil }
        return b.stunden.min { abs($0.aussenC - aussen) < abs($1.aussenC - aussen) }
    }

    /// Die Breite eines Balkens, wo sie fest sein darf - `nil` heißt: so breit wie sein Fach.
    ///
    /// **`barMaxWidth: 26` hat in Swift Charts kein Gegenstück** (`betrieb.ts:97`). ECharts
    /// heißt das „höchstens 26 Pixel“; hier gibt es nur „fest“ oder „volles Fach“. Bis
    /// vierzehn Tage ist das Fach breiter als 26 Punkte, dort ist die feste Breite genau die
    /// Vorlage; bei dreißig und neunzig Tagen ist es umgekehrt, und 26 Punkte legten die
    /// Balken übereinander.
    public static func balkenbreite(_ b: BetriebOut) -> Double? {
        b.tage.count <= 14 ? 26 : nil
    }

    /// Der Kopf der Auskunft über eine Stunde: „14.11., 06:00“ in der Zeit des Hauses
    /// (`betrieb.ts:180`).
    ///
    /// **Hauszeit und nicht Gerätezeit**, wie überall in dieser Anwendung: wer aus dem Urlaub
    /// nachsieht, will wissen, wann die Maschine *dort* gelaufen ist. Tag und Monat hier
    /// zweistellig - die Vorlage verlangt es an dieser Stelle ausdrücklich
    /// (`{ day: "2-digit", month: "2-digit" }`), anders als an der Achse.
    public static func stundenkopf(_ s: BetriebStundeOut) -> String {
        guard let d = Zeit.ausIso(s.at) else { return s.at }
        return "\(Tag.tagMonat(Tag.iso(d))), \(Formate.hhmm(d))"
    }

    // MARK: - Die Tage als Tabelle

    /// Eine Spalte der Tagestabelle.
    public struct Tabellenspalte: Sendable, Hashable, Identifiable {
        public let name: String
        public let zellen: [String]
        public var id: String { name }

        public init(name: String, zellen: [String]) {
            self.name = name
            self.zellen = zellen
        }
    }

    /// Die elf Spalten der Vorlage, in ihrer Folge, **neuester Tag oben**
    /// (`Betrieb.tsx:144-168`).
    ///
    /// **Die Richtung ist eine Entscheidung** (`[...daten.tage].reverse()`, `Betrieb.tsx:156`):
    /// die Diagramme laufen von links nach rechts durch die Zeit, weil man dort einen Verlauf
    /// sucht; in einer Tabelle sucht man den letzten Tag, und der soll nicht unten stehen.
    ///
    /// **„0“ und nicht „-“ bei Abtauen und Heizstab** (`Betrieb.tsx:164-165`). Der Strich der
    /// übrigen Tabellen heißt „kein Wert“; hier ist die Null gemessen, und das ist an einer
    /// Wärmepumpe die bessere Nachricht.
    public static func tabellenzeilen(_ b: BetriebOut) -> [String] {
        b.tage.reversed().map { Tag.punkt($0.tag) }
    }

    public static func tabellenspalten(_ b: BetriebOut) -> [Tabellenspalte] {
        let tage = Array(b.tage.reversed())
        func spalte(_ name: String, _ zelle: (BetriebTagOut) -> String) -> Tabellenspalte {
            Tabellenspalte(name: name, zellen: tage.map(zelle))
        }
        return [
            spalte("draußen") { $0.aussenC.map { Formate.celsius($0, stellen: 1) } ?? fehlt },
            spalte("Starts") { String($0.starts) },
            spalte("Lauf") { Formate.dauer(minuten: $0.laufMin) },
            spalte("Lauf im Mittel") {
                $0.laufMedianMin.map { Formate.dauer(minuten: Int($0.rounded())) } ?? fehlt
            },
            spalte("Abtauen") { t in
                t.abtauMin > 0
                    ? "\(Formate.dauer(minuten: t.abtauMin)) · \(t.abtauungen)-mal" : "0"
            },
            spalte("Heizstab") { t in
                t.zusatzMin > 0 ? Formate.dauer(minuten: t.zusatzMin) : "0"
            },
            spalte("Strom") { Formate.kwh($0.stromKwh) },
            spalte("Wärme") { $0.waermeKwh.map { Formate.kwh($0) } ?? fehlt },
            spalte("Arbeitszahl") { $0.copTag.map { Formate.zahl($0, stellen: 2) } ?? fehlt },
            spalte(Copreihe.heizbetrieb.rawValue) {
                $0.copHeizen.map { Formate.zahl($0, stellen: 2) } ?? fehlt
            },
        ]
    }

    /// Der Griff der zugeklappten Tabelle (`Betrieb.tsx:137`).
    public static func tabellengriff(_ b: BetriebOut) -> String {
        "Die Tage als Tabelle (\(b.tage.count))"
    }
}
