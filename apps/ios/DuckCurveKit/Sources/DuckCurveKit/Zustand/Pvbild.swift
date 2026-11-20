import Foundation

/// Was die Photovoltaikseite rechnet: Prognosesummen, die Zweitageskurve, ihre sechs Kacheln,
/// die drei Reihen des Verwendungsbilds und der Spannenstreifen.
///
/// **Warum das alles hier liegt und nicht in der Ansicht.** Jede Zahl dieser Seite ist eine
/// Auswahl: welcher Satz unter einer Kachel steht, ob die Prognose aus dem Plan oder aus dem
/// Feld des Dienstes kommt, ob eine Lücke in der Istkurve eine Lücke bleibt. In einer `View`
/// wäre keine davon prüfbar - und die Vorlage trifft jede einzelne mit einer Begründung,
/// die man nachlesen kann (`apps/web/src/components/reports/PvReport.tsx`).
public enum Pvbild {

    // MARK: - Prognosesummen heute und morgen

    /// Ein Punkt der Leistungskurve: Zeitpunkt und kW.
    public struct Punkt: Sendable, Hashable, Identifiable {
        public let zeit: Date
        public let kw: Double
        public var id: Date { zeit }

        public init(zeit: Date, kw: Double) {
            self.zeit = zeit
            self.kw = kw
        }
    }

    /// Die beiden Tagessummen der Vorschau samt den Stützpunkten, aus denen sie entstanden.
    public struct Prognose: Sendable, Hashable {
        public let heute: Double
        public let morgen: Double
        public let punkte: [Punkt]
    }

    /// Die erwartete Erzeugung heute und morgen aus den Planintervallen.
    ///
    /// Wörtlich nach `PvReport.tsx:24-36` (`forecastKwh`), und die drei Regeln dort sind der
    /// ganze Inhalt der Funktion:
    ///
    /// 1. **Die Intervallbreite kommt aus den ersten zwei Stützpunkten**, nicht aus einer
    ///    Annahme über das Raster - der Planer liefert je nach Lauf Viertelstunden oder
    ///    Stunden. Mindestens eine Minute, damit ein doppelter Zeitstempel die Summe nicht
    ///    auf Null zieht.
    /// 2. **Zwei Fenster, halboffen:** [Tagesbeginn, +24 h) ist heute, [+24 h, +48 h) ist
    ///    morgen. Was weiter rechts liegt, zählt zu keinem der beiden - der Horizont reicht
    ///    manchmal weiter als zwei Tage.
    /// 3. **`pvForecastTodayKwh` schlägt die eigene Summe**, wenn es ungleich Null ist: der
    ///    Dienst rechnet die Tagesprognose aus dem vollen Wettermodell, die Summe hier nur
    ///    aus dem, was im Plan übrig ist. Steht dort eine Null, ist das Feld nicht gefüllt
    ///    und nicht „null kWh erwartet“ (`PvReport.tsx:35`: `plan.pv_forecast_today_kwh ||
    ///    today`).
    ///
    /// Ohne Plan oder mit weniger als zwei lesbaren Stützpunkten bleibt die eigene Summe
    /// unmöglich; dann steht das Feld des Dienstes allein da, auch wenn es Null ist.
    public static func prognose(_ plan: PlanOut?, tagesbeginn: Date) -> Prognose {
        guard let plan else { return Prognose(heute: 0, morgen: 0, punkte: []) }
        // Ein Intervall ohne lesbaren Zeitstempel fällt heraus und wird nicht auf den
        // 1. Januar 1970 gelegt: dort zöge es die Zeitachse des Diagramms zu sich.
        let punkte = plan.intervals.compactMap { iv -> Punkt? in
            guard let z = Zeit.ausIso(iv.ts) else { return nil }
            return Punkt(zeit: z, kw: iv.expectedPvKw)
        }
        guard punkte.count >= 2 else {
            return Prognose(heute: plan.pvForecastTodayKwh, morgen: 0, punkte: punkte)
        }
        let stunden = max(
            1.0 / 60.0, punkte[1].zeit.timeIntervalSince(punkte[0].zeit) / 3600.0
        )
        let tagesende = tagesbeginn.addingTimeInterval(24 * 3600)
        let uebermorgen = tagesende.addingTimeInterval(24 * 3600)
        var heute = 0.0
        var morgen = 0.0
        for p in punkte {
            if p.zeit >= tagesbeginn, p.zeit < tagesende {
                heute += p.kw * stunden
            } else if p.zeit >= tagesende, p.zeit < uebermorgen {
                morgen += p.kw * stunden
            }
        }
        return Prognose(
            heute: plan.pvForecastTodayKwh != 0 ? plan.pvForecastTodayKwh : heute,
            morgen: morgen, punkte: punkte
        )
    }

    // MARK: - Ist gegen Prognose über 48 Stunden

    /// Ein zusammenhängendes Stück der Istkurve.
    ///
    /// **Warum Abschnitte und nicht eine Reihe.** Die Vorlage zeichnet die Istkurve mit
    /// `connectNulls: false` (`charts.ts:226`): wo der Zähler geschwiegen hat, ist ein Loch,
    /// und eine Linie über das Loch hinweg behauptet eine Messung, die es nicht gibt. Swift
    /// Charts kennt kein `connectNulls` - dort verbindet eine Reihe alles, was dieselbe
    /// `series` trägt. Die Lücke muss deshalb schon in den Daten stehen: je Abschnitt eine
    /// eigene Reihe.
    public struct Abschnitt: Sendable, Hashable, Identifiable {
        public let nummer: Int
        public let punkte: [Punkt]
        public var id: Int { nummer }
    }

    /// Istkurve und Prognosekurve auf einer Zeitachse über zwei Tage.
    public struct Zweitagebild: Sendable, Hashable {
        public let ist: [Abschnitt]
        public let prognose: [Punkt]
        /// Mitternacht des Tages, auf den sich die Vorschau bezieht.
        public let beginn: Date
        /// Die Trennlinie, an der „morgen“ anfängt.
        public let tagesende: Date
        /// Das rechte Ende der Achse: Beginn plus 48 Stunden.
        public let ende: Date
        /// Die höchste Leistung in beiden Reihen - Null, wenn nichts da ist.
        public let hoechstwert: Double

        public var leer: Bool { ist.isEmpty && prognose.isEmpty }
    }

    /// Die beiden Reihen der Vorschaukarte.
    ///
    /// Der Istteil kommt aus dem Minutenraster (`pv_power_kw`, `Verlauf.swift`), der
    /// Prognoseteil aus den Planintervallen - genau die zwei Quellen, die
    /// `PvReport.tsx:49-52,68` mit `Promise.allSettled` holt. Beide werden auf das Fenster
    /// [Tagesbeginn, +48 h] beschnitten, weil die Achse dort endet
    /// (`charts.ts:179,200-201`); ein Punkt dahinter wäre keine Information, sondern ein
    /// Strich an den Rand.
    public static func tagundmorgen(
        raster: [Verlaufspunkt], plan: PlanOut?, tagesbeginn: Date
    ) -> Zweitagebild {
        let tagesende = tagesbeginn.addingTimeInterval(24 * 3600)
        let ende = tagesbeginn.addingTimeInterval(48 * 3600)
        let ist = abschnitte(raster, von: tagesbeginn, bis: ende)
        let vorschau = prognose(plan, tagesbeginn: tagesbeginn).punkte.filter {
            $0.zeit >= tagesbeginn && $0.zeit <= ende
        }
        let hoch = max(
            ist.flatMap(\.punkte).map(\.kw).max() ?? 0, vorschau.map(\.kw).max() ?? 0
        )
        return Zweitagebild(
            ist: ist, prognose: vorschau, beginn: tagesbeginn, tagesende: tagesende,
            ende: ende, hoechstwert: hoch
        )
    }

    /// Das Minutenraster in zusammenhängende Stücke zerlegen.
    ///
    /// Eine fehlende Messung (`pv == nil`) und ein Punkt außerhalb des Fensters beenden beide
    /// das laufende Stück. Ein Stück aus einem einzigen Punkt bleibt stehen: es ist eine
    /// Messung, und Swift Charts zeichnet dafür einen Punkt statt einer Linie - das ist
    /// richtiger als sie wegzulassen.
    static func abschnitte(_ raster: [Verlaufspunkt], von: Date, bis: Date) -> [Abschnitt] {
        var aus: [Abschnitt] = []
        var laufend: [Punkt] = []
        func schliessen() {
            if !laufend.isEmpty {
                aus.append(Abschnitt(nummer: aus.count, punkte: laufend))
                laufend = []
            }
        }
        for p in raster.sorted(by: { $0.zeit < $1.zeit }) {
            guard p.zeit >= von, p.zeit <= bis, let kw = p.pv, kw.isFinite else {
                schliessen()
                continue
            }
            laufend.append(Punkt(zeit: p.zeit, kw: kw))
        }
        schliessen()
        return aus
    }

    // MARK: - Die sechs Kacheln

    /// Die sechs Kennzahlen der Seite, in der Reihenfolge der Vorlage
    /// (`PvReport.tsx:87-98`).
    ///
    /// **Was hier nicht mehr steht:** „direkt verbraucht“ und „in den Speicher“. Beide waren
    /// Kacheln der App, in der Vorlage sind sie die zwei ersten Reihen des Balkenbilds, und
    /// ihre Summe ist der Eigenverbrauch der zweiten Kachel - an der Wand stand dieselbe
    /// Größe damit dreimal.
    ///
    /// **Die beiden Prognosefelder folgen dem Anker nicht**, und das muss dastehen. Der Plan
    /// kennt nur heute und morgen; für einen vergangenen Tag gibt es keine Vorhersage mehr.
    /// Blättert man zurück, folgt der Rest der Seite dem gewählten Tag, diese Felder aber
    /// nicht - ohne den Satz „für heute, nicht für den gewählten Tag“ liest man sie als
    /// Prognose des gewählten Tages (`PvReport.tsx:92-95`).
    public static func kacheln(
        _ b: EnergySummaryOut?, prognose: Prognose, istHeute: Bool
    ) -> [Kennzahl] {
        let t = b?.totals
        return [
            Kennzahl(
                wort: "Erzeugung", wert: Formate.zahl(t?.pvKwh, stellen: 1), einheit: "kWh",
                dazu: bewertet(t?.minutes), ton: .sonne
            ),
            Kennzahl(
                wort: "Eigenverbrauch", wert: Formate.prozent(t?.selfConsumptionShare),
                dazu: t.map {
                    "\(Formate.zahl(($0.pvDirectKwh ?? 0) + ($0.pvToBatteryKwh ?? 0), stellen: 1)) kWh selbst genutzt"
                }
            ),
            Kennzahl(
                wort: "Eingespeist", wert: Formate.zahl(t?.exportKwh, stellen: 1),
                einheit: "kWh",
                dazu: b.map {
                    "Erlös \(Formate.euro($0.totals.exportRevenueEur)) bei \(Formate.zahl($0.meta.feedInCtKwh, stellen: 1)) ct"
                },
                ton: .nebel
            ),
            Kennzahl(
                wort: "Ersparnis direkt", wert: Formate.euro(t?.pvDirectSavingsEur),
                dazu: "gegenüber Netzbezug", ton: .bernstein
            ),
            Kennzahl(
                wort: "Prognose heute", wert: Formate.zahl(prognose.heute, stellen: 1),
                einheit: "kWh", dazu: prognosesatz(t, istHeute: istHeute)
            ),
            Kennzahl(
                wort: "Prognose morgen",
                wert: prognose.morgen > 0
                    ? Formate.zahl(prognose.morgen, stellen: 1) : Formate.leer,
                einheit: "kWh",
                dazu: prognose.morgen > 0 ? "aus Wetterprognose" : "noch nicht verfügbar"
            ),
        ]
    }

    /// „N h bewertet“ - wie viele Stunden Minutenwerte in die Summe eingegangen sind.
    ///
    /// Ganze Stunden, kaufmännisch gerundet (`Math.round(minutes / 60)`,
    /// `PvReport.tsx:88`). Keine Minuten heißt „keine Daten“ und nicht „0 h bewertet“: das
    /// zweite liest sich wie eine Messung.
    static func bewertet(_ minuten: Int?) -> String {
        guard let minuten, minuten > 0 else { return "keine Daten" }
        return "\(Int((Double(minuten) / 60).rounded())) h bewertet"
    }

    /// Der Satz unter „Prognose heute“.
    static func prognosesatz(_ t: EnergyTotalsOut?, istHeute: Bool) -> String {
        guard istHeute else { return "für heute, nicht für den gewählten Tag" }
        guard let t else { return "Tagesprognose" }
        return "\(Formate.zahl(t.pvKwh, stellen: 1)) kWh bisher erzeugt"
    }

    // MARK: - Erzeugung und Verwendung

    /// Was aus der Erzeugung wurde: die drei Reihen des gestapelten Balkenbilds.
    ///
    /// Reihenfolge, Wörter und Farben nach `PvReport.tsx:17-21` (`SERIES`). Die Namen sind
    /// Großschreibung, nicht Kleinschreibung: gesperrt gesetzt liest sich „direkt ins Haus“
    /// als Versehen.
    public enum Verwendung: String, Sendable, Hashable, CaseIterable, Identifiable {
        case direkt
        case speicher
        case einspeisung

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .direkt: return "Direkt genutzt"
            case .speicher: return "In Batterie"
            case .einspeisung: return "Eingespeist"
            }
        }

        /// Der Wert dieser Reihe in einem Bucket. Fehlt er, ist er Null und nicht nichts:
        /// ein Loch in einem gestapelten Balken verschiebt die Reihen darüber
        /// (`charts.ts:84`: `typeof v === "number" ? … : 0`).
        public func wert(_ t: EnergyTotalsOut) -> Double {
            let roh: Double? =
                switch self {
                case .direkt: t.pvDirectKwh
                case .speicher: t.pvToBatteryKwh
                case .einspeisung: t.exportKwh
                }
            guard let roh, roh.isFinite else { return 0 }
            // Auf zwei Stellen, wie die Vorlage die Balkenwerte rundet (`charts.ts:85`).
            return (roh * 100).rounded() / 100
        }
    }

    /// Ein Balken: sein Wort auf der Achse und die drei Werte in der Reihenfolge von
    /// ``Verwendung``.
    public struct Balken: Sendable, Hashable, Identifiable {
        public let nummer: Int
        public let wort: String
        public let werte: [Double]
        public var id: Int { nummer }

        public var summe: Double { werte.reduce(0, +) }
    }

    public static func verwendung(_ b: EnergySummaryOut?) -> [Balken] {
        (b?.buckets ?? []).enumerated().map { i, e in
            Balken(
                nummer: i, wort: e.label,
                werte: Verwendung.allCases.map { $0.wert(e.totals) }
            )
        }
    }

    /// Was beim Lesen eines Balkens dasteht.
    ///
    /// **Ohne das ist der Wert eines Balkens nirgends ablesbar.** Die Vorlage nennt beim
    /// Darüberfahren den Bucket, je Reihe Name und Wert und darunter abgesetzt die Summe
    /// (`charts.ts:58-73`); an einem Monatsbild mit dreißig Balken ist die Zahl sonst
    /// verloren. Reihen mit Null fallen weg - „In Batterie 0,0 kWh“ an einem Dezembertag ist
    /// eine Zeile ohne Aussage.
    public struct Ablesung: Sendable, Hashable {
        public struct Zeile: Sendable, Hashable, Identifiable {
            public let name: String
            public let wert: String
            public var id: String { name }
        }
        public let wort: String
        public let zeilen: [Zeile]
        public let summe: String
    }

    public static func ablesung(_ balken: Balken, einheit: String = "kWh") -> Ablesung {
        let zeilen = Verwendung.allCases.enumerated().compactMap { i, r -> Ablesung.Zeile? in
            guard i < balken.werte.count, balken.werte[i] != 0 else { return nil }
            return Ablesung.Zeile(
                name: r.name,
                wert: "\(Formate.zahl(balken.werte[i], stellen: 1))\(Formate.schmalesLeerzeichen)\(einheit)"
            )
        }
        return Ablesung(
            wort: balken.wort, zeilen: zeilen,
            summe:
                "Summe \(Formate.zahl(balken.summe, stellen: 1))\(Formate.schmalesLeerzeichen)\(einheit)"
        )
    }

    /// Den Balken zu einem gelesenen Achsenwort finden.
    public static func balken(_ balken: [Balken], wort: String?) -> Balken? {
        guard let wort else { return nil }
        return balken.first { $0.wort == wort }
    }

    // MARK: - PV im Überblick: vier Größen gegen vier Spannen

    /// Vier Größen gegen Tag, Woche, Monat und Jahr **desselben Ankertags**.
    ///
    /// **Warum das mehr ist als vier Zahlen.** Ein Tag sagt etwas über das Wetter, nicht über
    /// die Anlage; erst die vier Spalten nebeneinander zeigen, ob ein auffälliger Tag
    /// auffällig *ist*. Die Spalten folgen der Navigation: blättert man auf einen vergangenen
    /// Tag, zeigen sie dessen Woche, Monat und Jahr und nicht mehr die laufenden
    /// (`PeriodStrip.tsx:22-26`).
    ///
    /// Fehlt eine Spanne, steht in ihrer Spalte ein Strich und nicht eine Null
    /// (`PvReport.tsx:72`) - eine Abfrage, die gescheitert ist, hat keinen Wert, und die
    /// anderen drei Spalten bleiben trotzdem lesbar.
    ///
    /// **Eine Zeile gehört nicht dieser Seite allein:** derselbe Streifen steht auf /strom mit
    /// anderen Zeilen über denselben Antworten. Die Spaltenköpfe und der Hinweis „jeweils bis
    /// …“ liegen darum nicht hier, sondern in ``Spannenworte``, und die Gestalt in
    /// ``Spannenstreifen``.
    public static func spannenzeilen(_ je: [Spanne: EnergySummaryOut]) -> [Streifenzeile] {
        let folge = Spanne.allCases
        func reihe(
            _ wort: String, _ ton: Kennzahl.Ton = .normal,
            _ wert: @escaping (EnergyTotalsOut) -> String
        ) -> Streifenzeile {
            Streifenzeile(
                wort: wort,
                werte: folge.map { je[$0].map { wert($0.totals) } ?? Formate.leer },
                ton: ton
            )
        }
        return [
            // Ab hundert kWh ohne Nachkommastelle: das Zehntel einer Jahressumme ist Rauschen
            // und nimmt in einer Tabelle mit vier Spalten den Platz der Spalte daneben
            // (`PvReport.tsx:115`).
            reihe("Erzeugt · kWh", .bernstein) { Formate.kwhNachGroesse($0.pvKwh) },
            reihe("Eigenverbrauch") { Formate.prozent($0.selfConsumptionShare) },
            reihe("Einspeiseerlös") { Formate.euro($0.exportRevenueEur) },
            reihe("Ersparnis") { Formate.euro(ersparnis($0)) },
        ]
    }

    /// Die Ersparnis des Streifens: PV direkt plus Batterieentladung.
    ///
    /// **Eine Summe aus zwei Feldern, die es so in keiner Antwort gibt** (`PvReport.tsx:118`).
    /// Darum steht ihre Rechnung im Methodensatz der Seite. Fehlen beide Felder, gibt es keine
    /// Summe und keine Null; fehlt eines, trägt das andere sie - der Dienst lässt ein Geldfeld
    /// weg, wenn es für den Zeitraum keinen Preis gab, nicht wenn es null Euro waren.
    static func ersparnis(_ t: EnergyTotalsOut) -> Double? {
        guard t.pvDirectSavingsEur != nil || t.batteryNetEur != nil else { return nil }
        return (t.pvDirectSavingsEur ?? 0) + (t.batteryNetEur ?? 0)
    }

    // MARK: - Methode

    /// Der Satz, der die Ersparnis des Streifens erklärt - der einzige Methodensatz, der dieser
    /// Seite allein gehört (`PvReport.tsx:121`).
    ///
    /// Die Kurzzeile daneben (Abdeckung und Aufzeichnungsbeginn) ist für jede Berichtsseite
    /// dieselbe und steht schon als ``Wallbox/abdeckung(_:)`` über demselben
    /// ``EnergyMetaOut``.
    public static let ersparnissatz =
        "Ersparnis im Überblick = PV direkt plus Batterieentladung, jeweils gegen den Strompreis der Stunde."

    // MARK: - Vier Spannen in einem Zug

    /// Dieselbe Abfrage für Tag, Woche, Monat und Jahr, nebenläufig.
    ///
    /// **`try?` je Spanne, nicht für alle vier zusammen.** Eine fehlende Spalte ist besser
    /// als eine Seite, die an ihr scheitert - die Vorlage holt die vier mit
    /// `Promise.allSettled` und lässt den Streifen stehen, wenn eine wegfällt
    /// (`useReport.ts:55-77`).
    ///
    /// Steht hier und nicht in der Seite, weil /strom denselben Streifen über denselben
    /// Antworten braucht. Der richtige Platz wäre ``Api`` selbst; dort lag die Fassung
    /// dieses Projekts bisher privat in einer einzigen Seite.
    public static func jeSpanne<T: Sendable>(
        _ hole: @Sendable @escaping (Spanne) async -> T?
    ) async -> [Spanne: T] {
        await withTaskGroup(of: (Spanne, T?).self) { gruppe in
            for s in Spanne.allCases {
                gruppe.addTask { (s, await hole(s)) }
            }
            var aus: [Spanne: T] = [:]
            for await (s, wert) in gruppe {
                if let wert { aus[s] = wert }
            }
            return aus
        }
    }
}
