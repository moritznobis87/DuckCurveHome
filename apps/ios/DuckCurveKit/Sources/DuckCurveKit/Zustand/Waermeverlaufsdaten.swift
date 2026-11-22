import Foundation

/// Der Tagesverlauf der Wärmebilanz, die Sätze der Methodenkarte und das Taktwort - gerechnet.
///
/// **Warum diese Datei neben ``Waermeuebersicht`` steht.** Dort stehen die Karten der Seite als
/// Zahlen mit Wörtern. Hier steht, was das Hauptdiagramm zeigt: welche Größe eine Fläche ist,
/// welche eine Linie, welche Farbe sie trägt und was sich zu einer Summe addieren darf. Das ist
/// die Aussage des Bildes, und sie wäre in einer `View` nicht prüfbar - genau dort lag sie
/// bisher, und genau dort ist sie falsch geworden.
extension Waermeuebersicht {

    // MARK: - Der Tagesverlauf

    /// Eine Minute des Tagesverlaufs, schon für das Bild geordnet.
    ///
    /// **Der Stapel endet nach zwei Schichten, und das ist der Kern dieser Seite.** Die Vorlage
    /// begründet es im Kopf des Diagramms (`charts.ts:781-784`): „Gestapelt wird nur, was sich
    /// wirklich addiert: Wärmepumpe und Ofenwasser gehen beide in denselben Puffer, ihre Summe
    /// ist die Zufuhr. Entnahme und Verlust gehen aus ihm heraus und stehen deshalb als eigene
    /// Linien daneben, nicht als weitere Schicht desselben Stapels - sonst läse man eine Summe,
    /// die es nicht gibt.“ Für die Raumwärme des Ofens sagt sie es noch einmal eigens
    /// (`charts.ts:878-879`): „Die Raumwärme des Ofens geht nicht in den Puffer. Sie gehört
    /// deshalb nicht in den Stapel, auch wenn sie vom selben Gerät kommt.“
    ///
    /// Die App hat sie bis hierher mitgestapelt und damit über dem Puffer eine Zufuhr gezeigt,
    /// die nie in ihm war.
    public struct Verlaufspunkt: Sendable, Hashable, Identifiable {
        public let zeit: Date
        /// Die Wärmepumpe, wie gemessen.
        public let wpKw: Double?
        /// Das Ofenwasser, wie gemessen.
        public let wasserKw: Double?
        /// Die Raumwärme des Ofens - eigene Reihe, nie im Stapel.
        public let raumKw: Double?
        public let entnahmeKw: Double?
        public let verlustKw: Double?
        public let pufferKwh: Double?

        public var id: Date { zeit }

        public init(
            zeit: Date, wpKw: Double? = nil, wasserKw: Double? = nil, raumKw: Double? = nil,
            entnahmeKw: Double? = nil, verlustKw: Double? = nil, pufferKwh: Double? = nil
        ) {
            self.zeit = zeit
            self.wpKw = wpKw
            self.wasserKw = wasserKw
            self.raumKw = raumKw
            self.entnahmeKw = entnahmeKw
            self.verlustKw = verlustKw
            self.pufferKwh = pufferKwh
        }

        /// Die untere Kante des Stapels: die Wärmepumpe allein.
        ///
        /// **Eine Lücke bleibt eine Lücke.** Ist keine der beiden Zufuhren gemessen, steht
        /// nichts - eine Null hieße, es sei nichts gelaufen (`connectNulls: false`,
        /// `charts.ts:799`). Ist eine der beiden gemessen, gilt die andere als nicht gelaufen:
        /// der Stapel hat dann eine Kante und kein Loch.
        public var stapelWp: Double? {
            gemessen ? (wpKw ?? 0) : nil
        }

        /// Die obere Kante des Stapels - „ihre Summe ist die Zufuhr“ (`charts.ts:782`).
        public var stapelZufuhr: Double? {
            gemessen ? (wpKw ?? 0) + (wasserKw ?? 0) : nil
        }

        private var gemessen: Bool { wpKw != nil || wasserKw != nil }
    }

    /// Die Reihen des Tagesverlaufs, geordnet und geprüft.
    ///
    /// **Warum die Farbe hier fällt und nicht in der Ansicht.** Die Vorlage hat für dieses Bild
    /// die Farbabstände gemessen (`charts.ts:788-790`: engstes Paar Ofen gegen Verlust, ΔE 16,9
    /// bei einer Projektgrenze von 15) und für die Entnahme eigens begründet, warum sie hell
    /// ist und nicht sandfarben (`charts.ts:872-875`: mit dem Orange der Wärmepumpe wäre Sand
    /// bei Deuteranopie dieselbe Farbe, ΔE 0,2). Eine Zuordnung mit einer solchen Begründung
    /// ist eine Rechnung und gehört an eine Stelle, an der ein Test sie festhält.
    public static func verlaufsstapel(_ punkte: [HeatBalancePointOut]) -> [Verlaufspunkt] {
        punkte
            .compactMap { p in
                guard let t = Zeit.ausIso(p.ts) else { return nil }
                return Verlaufspunkt(
                    zeit: t, wpKw: p.heatPumpKw, wasserKw: p.stoveWaterKw,
                    raumKw: p.stoveRoomKw, entnahmeKw: p.drawKw, verlustKw: p.lossKw,
                    pufferKwh: p.bufferKwh)
            }
            .sorted { $0.zeit < $1.zeit }
    }

    /// Die zusammenhängenden Abschnitte einer Reihe - die Lücken dazwischen bleiben Lücken.
    ///
    /// **Swift Charts zieht eine Linie durch jede Lücke.** Die Vorlage setzt überall
    /// `connectNulls: false` und nimmt davon einzig den Pufferinhalt aus (`charts.ts:799, 883`);
    /// das Gegenstück dazu gibt es in Swift Charts nicht - eine Reihe, der dreißig Punkte
    /// fehlen, wird trotzdem durchverbunden, und eine halbe Stunde ohne Messung sähe aus wie
    /// eine halbe Stunde mit gleichmäßigem Lauf. Eine Minute ohne Messung ist aber keine Null.
    ///
    /// Also wird die Reihe vor dem Zeichnen geschnitten, und jeder Abschnitt bekommt im Bild
    /// seinen eigenen Reihenschlüssel. Ein Abschnitt aus einem einzigen Punkt zeichnet nichts -
    /// ebenso wie die Vorlage, die ihre Symbole abgeschaltet hat (`showSymbol: false`).
    public static func verlaufsabschnitte(
        _ punkte: [Verlaufspunkt], _ wert: KeyPath<Verlaufspunkt, Double?>
    ) -> [[Verlaufspunkt]] {
        var aus: [[Verlaufspunkt]] = []
        var lauf: [Verlaufspunkt] = []
        for p in punkte {
            if p[keyPath: wert] != nil {
                lauf.append(p)
            } else if !lauf.isEmpty {
                aus.append(lauf)
                lauf = []
            }
        }
        if !lauf.isEmpty { aus.append(lauf) }
        return aus
    }

    /// Eine Reihe des Tagesverlaufs: Wort, Farbe, Gestalt.
    public struct Verlaufsreihe: Sendable, Hashable, Identifiable {

        /// Wie die Reihe gezeichnet wird.
        ///
        /// **Die Gestalt trägt die Aussage, nicht nur die Farbe.** „Ofen (Raum)“ und „Ofen
        /// (Wasser)“ haben dieselbe Farbe, weil es dasselbe Gerät ist; dass die eine
        /// gestrichelt daneben steht und die andere im Stapel liegt, ist der ganze Unterschied
        /// (`charts.ts:878-880`). Ein gestricheltes Zeichen tragen beide gestrichelten Reihen
        /// auch in der Legende (`charts.ts:844, 846`).
        public enum Gestalt: String, Sendable, Hashable {
            /// Eine Fläche mit einer Linie in der Vollfarbe darüber (`charts.ts:796-807`).
            case flaeche
            /// Eine durchgezogene Linie.
            case linie
            /// Eine gestrichelte Linie - was nicht durch den Puffer geht.
            case gestrichelt
        }

        public let wort: String
        public let farbe: Farbwert
        public let gestalt: Gestalt
        /// Die Strichstärke, wie die Vorlage sie setzt (`charts.ts:876-883`).
        public let strich: Double
        /// Die Deckung der Fläche, wo es eine gibt.
        public let flaechendeckung: Double?
        /// Die Einheit der Reihe. Alles in kW, nur der Pufferinhalt in kWh
        /// (`charts.ts:823`: der Hinweiskasten setzt die Einheit je Reihe).
        public let einheit: String

        public var id: String { wort }

        public init(
            wort: String, farbe: Farbwert, gestalt: Gestalt, strich: Double,
            flaechendeckung: Double? = nil, einheit: String = "kW"
        ) {
            self.wort = wort
            self.farbe = farbe
            self.gestalt = gestalt
            self.strich = strich
            self.flaechendeckung = flaechendeckung
            self.einheit = einheit
        }
    }

    public static let reiheWaermepumpe = Verlaufsreihe(
        wort: "Wärmepumpe", farbe: Marken.waermepumpe, gestalt: .flaeche, strich: 1,
        flaechendeckung: 0.24)

    public static let reiheOfenWasser = Verlaufsreihe(
        wort: "Ofen (Wasser)", farbe: Marken.ofen, gestalt: .flaeche, strich: 1,
        flaechendeckung: 0.28)

    public static let reiheOfenRaum = Verlaufsreihe(
        wort: "Ofen (Raum)", farbe: Marken.ofen, gestalt: .gestrichelt, strich: 1.5)

    /// **Die Entnahme ist hell und nicht sandfarben** (`charts.ts:872-875`): `C.house` #CFD8DC.
    /// Vorher stand sie in der App auf `Farbe.mist` - derselben Marke wie der Netzbezug -, und
    /// `Marken.swift:107-108` verbietet das ausdrücklich: „der Abstand zu `alarm` und
    /// `netzBezug` ist nur ΔE 9,3: Ofen und Netzbezug dürfen nicht ohne Zweitkodierung in
    /// dieselbe Grafik.“ Genau das war der Fall - Ofenflächen und eine durchgezogene Linie in
    /// Netzbezugsfarbe in einem Bild.
    public static let reiheEntnahme = Verlaufsreihe(
        wort: "Entnahme", farbe: Marken.haus, gestalt: .linie, strich: 2)

    public static let reiheVerlust = Verlaufsreihe(
        wort: "Verlust an den Raum", farbe: Marken.alarm, gestalt: .gestrichelt, strich: 1.5)

    /// Der Pufferinhalt steht in der unteren Fläche und in `C.mist` #7FA3B3
    /// (`charts.ts:883`) - nicht im Grün von `Marken.puffer`, das die App hier hatte.
    public static let reihePufferinhalt = Verlaufsreihe(
        wort: "Pufferinhalt", farbe: Marken.mist, gestalt: .flaeche, strich: 2,
        flaechendeckung: 0.14, einheit: "kWh")

    /// Die sechs Reihen in der Reihenfolge der Legende der Vorlage (`charts.ts:838-846`).
    public static let verlaufsreihen: [Verlaufsreihe] = [
        reiheWaermepumpe, reiheOfenWasser, reiheOfenRaum, reiheEntnahme, reiheVerlust,
        reihePufferinhalt,
    ]

    // MARK: - Die Auskunftszeile unter dem Finger

    /// Was an einer Stelle des Tages stand - eine Uhrzeit und die Werte der sechs Reihen.
    public struct Verlaufsablesung: Sendable, Hashable {
        public let uhrzeit: String
        /// Je Reihe ein Wort und ein Wert. Reihen ohne Messung an dieser Stelle fehlen, wie im
        /// Hinweiskasten der Vorlage (`charts.ts:819`: `filter` auf die Zahlen).
        public let werte: [Kennzahl]
    }

    /// Die Ablesung zu einer Stelle der Zeitachse.
    ///
    /// **Statt des Hinweiskastens der Vorlage.** `dataZoom` und `tooltip` (`charts.ts:813-826,
    /// 857-860`) hat Swift Charts nicht als fertiges Stück; der im Projekt gewählte Weg ist,
    /// den Finger lesen zu lassen und das Ergebnis über das Bild zu schreiben
    /// (`chartXSelection`, so wie `Diagramme/Betriebskurven.swift`). Gesucht wird der nächste
    /// Punkt und nicht der vorangehende: bei einer Minutenreihe ist das derselbe, bei einer
    /// Viertelstundenreihe liest sich der nächste richtiger.
    public static func verlaufsablesung(_ stapel: [Verlaufspunkt], zu zeit: Date?)
        -> Verlaufsablesung?
    {
        guard let zeit, !stapel.isEmpty else { return nil }
        guard
            let p = stapel.min(by: {
                abs($0.zeit.timeIntervalSince(zeit)) < abs($1.zeit.timeIntervalSince(zeit))
            })
        else { return nil }
        let paare: [(Verlaufsreihe, Double?)] = [
            (reiheWaermepumpe, p.wpKw), (reiheOfenWasser, p.wasserKw),
            (reiheOfenRaum, p.raumKw), (reiheEntnahme, p.entnahmeKw),
            (reiheVerlust, p.verlustKw), (reihePufferinhalt, p.pufferKwh),
        ]
        let werte = paare.compactMap { reihe, wert -> Kennzahl? in
            guard let wert else { return nil }
            return Kennzahl(
                wort: reihe.wort, wert: Formate.zahl(wert, stellen: 1), einheit: reihe.einheit)
        }
        guard !werte.isEmpty else { return nil }
        return Verlaufsablesung(uhrzeit: Formate.hhmm(p.zeit), werte: werte)
    }

    // MARK: - Das Taktwort

    /// Die Einordnung der Taktung, mit Rückfall.
    ///
    /// **Ohne Urteil steht „zu wenig Daten“ und nicht nichts** (`HeatOverview.tsx:232`:
    /// `TAKTUNG[(takt?.verdict ?? "unknown")]`). Eine Kernzahl „3,4 Starts je Tag“ ohne jede
    /// Einordnung liest sich wie ein Befund; dass keiner vorliegt, ist selbst die Auskunft.
    public static func taktwort(_ c: CyclingStats) -> String {
        c.verdict?.wort ?? CyclingStatsVerdictWahl.unknown.wort
    }

    // MARK: - Wie gerechnet wird

    /// Der Titel der Methodenkarte, wie die Vorlage ihn schreibt (`ui/Methode.tsx:66`).
    ///
    /// Er steht hier und nicht als neue Vorgabe in ``Methode``: die Vorgabe gilt für alle
    /// dreizehn Berichtsseiten, und das ist ein Zug über alle dreizehn, nicht über diese eine.
    public static let methodentitel = "Wie gerechnet wird"

    /// Die vier handgeschriebenen Absätze der Methodenkarte.
    ///
    /// **Auf einer Seite mit dem Kicker „gerechnet, nicht gemessen“ sind sie die Begründung
    /// jeder Zahl** (`HeatOverview.tsx:352-365`). Sie standen in der App nirgends: die
    /// Methodenkarte brachte nur die `*_de`-Sätze des Dienstes, und damit fehlte die
    /// Carnot-Umrechnung auf den wirklichen Vorlauf, der Satz „die Entnahme ist der Rest der
    /// Bilanz, und jeder Fehler der anderen Größen landet in ihr“ und die Unterscheidung der
    /// zwei Arten von Kosten.
    ///
    /// Sie liegen im Kern und nicht in der Ansicht, damit ein Test sie unter Linux festhält -
    /// vier Absätze in einem `ViewBuilder` sind vier Absätze, die niemand vergleicht.
    public static let methodensaetze: [String] = [
        """
        Im Haus gibt es keinen Wärmemengenzähler: jede Wärmemenge auf dieser Seite ist aus \
        Strom, Ofenbetrieb und Puffertemperaturen gerechnet.
        """,
        """
        Gemessen werden der Strom der Wärmepumpe, der Betriebszustand des Ofens und vier \
        Puffertemperaturen. Die Wärme der Wärmepumpe ist Strom mal Arbeitszahl. Die \
        Arbeitszahl folgt der Kennlinie über der Außentemperatur und wird über das Verhältnis \
        der Carnot-Zahlen auf den wirklichen Vorlauf umgerechnet: dieselbe Maschine liefert \
        bei 40 °C Vorlauf deutlich mehr als bei 58 °C, und der Puffer durchläuft an einem \
        Wintertag beides.
        """,
        """
        Die Entnahme in Heiz- und Brauchwasserkreis wird nicht gemessen; sie ist der Rest der \
        Bilanz, und jeder Fehler der anderen Größen landet in ihr. Was nicht aufgeht, steht \
        deshalb in der Tabelle als „nicht zuzuordnen“. Ein dauerhaft großer Rest heißt, dass \
        eine Annahme nicht stimmt.
        """,
        """
        Bei den Kosten stehen zwei Zahlen verschiedener Art nebeneinander. Der Strom der \
        Wärmepumpe ist geflossen und bezahlt; dazu gehört die entgangene Einspeisevergütung \
        für Sonnenstrom, der in den Verdichter statt ins Netz ging. Die Pellets waren bezahlt, \
        als sie geliefert wurden; hier steht, was die verbrannte Menge zum hinterlegten Preis \
        wert war. Die Menge ist aus den Leistungsstufen des Ofens geschätzt.
        """,
    ]

    /// Was im Tagesverlauf Fläche und was Linie ist - mit dem Hinweis des Dienstes dahinter.
    ///
    /// Die Vorlage setzt den Absatz aus beidem zusammen (`HeatOverview.tsx:366-369`): der feste
    /// Satz sagt die Regel, `note_de` sagt, was an diesem Tag von ihr abweicht.
    public static func verlaufssatz(_ noteDe: String?) -> String {
        let fest = """
            Im Tagesverlauf sind Flächen Zufuhr in den Puffer und addieren sich; Linien sind, \
            was wieder herausgeht. Die Raumwärme des Ofens geht nicht durch den Puffer.
            """
        guard let noteDe, !noteDe.isEmpty else { return fest }
        return "\(fest) \(noteDe)"
    }
}
