import Foundation

/// Die Wärmeseite: wer geliefert hat, was es gekostet hat, wie die Anlage lief.
///
/// **Die Wärme kommt aus der Bilanz, und nur von dort.** Wärmemenge, Arbeitszahl und
/// Wärmepreis stammen aus `GET /energy/waermebilanz`. Aus `GET /energy/heat` kommt nur noch,
/// was gemessen ist - der Strom der Wärmepumpe nach Herkunft - und was aus Messungen gezählt
/// wird: Taktung und Ofenbetrieb. Die Vorlage
/// (`apps/web/src/components/reports/HeatOverview.tsx`) begründet das: bis zum 10.11.2026 gab
/// es zwei Seiten, die für denselben Tag verschiedene Zahlen nannten, weil beide rechneten und
/// keine maß. Zwei Wahrheiten für dieselbe Größe sind keine.
///
/// **Was die App bisher zeigte.** Nur `/energy/heat`. Damit fehlte alles, was allein in der
/// Bilanz steht: die Wärmemenge selbst, die Kosten, die Lüftungsverluste, die Annahmen der
/// Rechnung und die Reihen für die Diagramme. `api.waermebilanz` und `api.energieVerschiebung`
/// lagen im Client bereit und wurden nicht gerufen.
public enum Waermeuebersicht {

    /// Null ist eine Messung, „keine Daten" ist keine. Ohne Minuten im Zeitraum steht ein Strich.
    static func kwh(_ n: Double?) -> String {
        n == nil ? Formate.leer : Formate.zahl(n, stellen: 1)
    }

    /// Dasselbe, aber ein Zeitraum ohne eine einzige gemessene Minute gilt als nichts.
    static func feld(_ b: HeatBalanceOut?, _ waehle: (HeatTotals) -> Double?) -> String {
        guard let b, b.totals.minutes != 0 else { return Formate.leer }
        return kwh(waehle(b.totals))
    }

    /// Minuten als Stunden und Minuten. „3:05 h" liest sich schneller als „185 min".
    ///
    /// ``Formate/dauer(minuten:)`` schreibt „3 h 5 min" - richtig für eine Dauer im Satz, aber
    /// in einer Spalte aus neun Zeilen ist die kurze Form die lesbare.
    public static func dauer(minuten: Int?) -> String {
        guard let minuten else { return Formate.leer }
        if minuten < 60 { return "\(minuten) min" }
        return "\(minuten / 60):\(String(format: "%02d", minuten % 60)) h"
    }

    // MARK: - Die sechs Kopfzahlen

    /// **Keine der sechs trägt einen Ton, und das ist die Vorlage.** `HeatOverview.tsx:141-165`
    /// ruft alle sechs `Stat` ohne `tone`, und `Stat.tsx:34` setzt die Zahl dann in
    /// `var(--text-1)`. Vier davon standen hier farbig - Glut, Nebel und zweimal Bernstein -,
    /// und nebeneinander gestellt war das der auffälligste Unterschied der ganzen Kopfzeile:
    /// eine Reihe aus vier Farben gegen eine Reihe aus einer. Eine Farbe ordnet nur ein, wenn
    /// nicht jede Kachel eine hat.
    public static func kacheln(bilanz: HeatBalanceOut?, strom: HeatReportOut?) -> [Kennzahl] {
        let t = bilanz?.totals
        let kosten = bilanz?.cost
        let e = strom?.summary.totals
        let ofenKwh = (t?.stoveWaterKwh ?? 0) + (t?.stoveRoomKwh ?? 0)

        // Der Anteil Sonnenstrom am Strom der Waermepumpe: PV und Batterie gegen die Summe.
        let wpStrom = e?.heatPumpKwh ?? 0
        let sonnenanteil: Double? =
            wpStrom > 0
            ? ((e?.heatPumpPvKwh ?? 0) + (e?.heatPumpBatteryKwh ?? 0)) / wpStrom : nil
        // Was die bezahlte Kilowattstunde Netzstrom gekostet hat - Euro durch kWh, in Cent.
        let netzKwh = e?.heatPumpGridKwh ?? 0
        let netzCt: Double? =
            netzKwh > 0.01 && kosten?.heatPumpPaidEur != nil
            ? ((kosten?.heatPumpPaidEur ?? 0) / netzKwh) * 100 : nil

        return [
            // **`kwh` und nicht `feld`.** Die Vorlage nimmt in der Kachel `kwh(t?.produced_kwh)`
            // (`HeatOverview.tsx:143`) und behält `feld` - den Strich bei `minutes == 0` - für
            // die Spannentabelle (`:119-127`). Der Unterschied ist nicht Pedanterie: ein Tag,
            // der eben erst angefangen hat, hat noch keine gemessene Minute, und „0,0 kWh“ ist
            // dort die richtige Auskunft. Ein Strich hieße „keine Daten“, und Daten gibt es.
            Kennzahl(
                wort: "Wärme gesamt", wert: kwh(bilanz?.totals.producedKwh), einheit: "kWh",
                dazu: t == nil
                    ? nil
                    : (ofenKwh > 0.05
                        ? "Wärmepumpe \(kwh(t?.heatPumpKwh)) · Ofen \(kwh(ofenKwh)) kWh"
                        : "nur die Wärmepumpe")),
            Kennzahl(
                wort: "Strom Wärmepumpe", wert: Formate.zahl(e?.heatPumpKwh, stellen: 1),
                einheit: "kWh",
                dazu: sonnenanteil.map { "\(Formate.prozent($0)) Sonnenstrom" }),
            Kennzahl(
                wort: "Arbeitszahl", wert: Formate.zahl(t?.copMean, stellen: 2),
                dazu: t?.copMean == nil ? "keine Laufzeit" : "aus Kennlinie und Vorlauf"),
            Kennzahl(
                wort: "Bezahlt", wert: Formate.zahl(kosten?.heatPumpPaidEur, stellen: 2),
                einheit: "€",
                dazu: e == nil
                    ? nil
                    : "\(Formate.zahl(netzKwh, stellen: 1)) kWh Netz"
                        + (netzCt.map { " · Ø \(Formate.zahl($0, stellen: 1)) ct" } ?? "")),
            Kennzahl(
                wort: "Wärmepreis", wert: Formate.zahl(kosten?.heatPumpCtPerKwh, stellen: 1),
                einheit: "ct/kWh",
                dazu: kosten?.stoveCtPerKwh != nil
                    ? "Wärmepumpe · Ofen \(Formate.ct(kosten?.stoveCtPerKwh))"
                    : "je kWh Wärme der Wärmepumpe"),
            // Auch hier `kwh` und nicht `feld` (`HeatOverview.tsx:162`).
            Kennzahl(
                wort: "Entnahme", wert: kwh(bilanz?.totals.drawKwh), einheit: "kWh",
                dazu: t == nil
                    ? nil : "Heizung und Warmwasser · Verlust \(kwh(t?.lossKwh)) kWh"),
        ]
    }

    // MARK: - Was die Wärme gekostet hat

    /// Die Kernzahl der Kostenkarte: der Wärmepreis der Wärmepumpe.
    ///
    /// **In Textfarbe, wie überall.** Die Vorlage legt es am Baustein selbst fest und schreibt
    /// die Begründung dazu (`HeatOverview.tsx:78`: „Die große Zahl einer Karte mit ihrer
    /// Unterzeile. Schrift in Textfarbe, wie überall.“, umgesetzt `:82`). Bernstein stand hier,
    /// weil die Zahl ein Preis ist - aber dann ist jede Kernzahl der Seite etwas, und am Ende
    /// ist keine hervorgehoben.
    public static func kostenkernzahl(_ k: HeatCostOut?) -> Kennzahl {
        Kennzahl(
            wort: "ct je kWh Wärme", wert: Formate.zahl(k?.heatPumpCtPerKwh, stellen: 1))
    }

    /// **Zwei Zahlen verschiedener Art stehen hier nebeneinander,** und das ist Absicht. Der
    /// Strom der Wärmepumpe ist geflossen und bezahlt; dazu gehört die entgangene Vergütung für
    /// Sonnenstrom, der in den Verdichter statt ins Netz ging. Die Pellets waren bezahlt, als
    /// sie geliefert wurden - hier steht, was die verbrannte Menge zum hinterlegten Preis wert
    /// war.
    public static func kostenzeilen(_ k: HeatCostOut?) -> [Kennzahl] {
        [
            Kennzahl(
                wort: "Wärmepumpe: bezahlter Netzstrom",
                wert: Formate.euro(k?.heatPumpPaidEur)),
            Kennzahl(
                wort: "Wärmepumpe: entgangene Vergütung",
                wert: Formate.euro(k?.heatPumpOpportunityEur)),
            Kennzahl(
                wort: "Pellets: verbrannte Menge",
                wert: k?.stoveKg == nil
                    ? Formate.leer : "\(Formate.zahl(k?.stoveKg, stellen: 1)) kg"),
            Kennzahl(wort: "Pellets: Wert zum hinterlegten Preis", wert: Formate.euro(k?.stoveEur)),
            Kennzahl(wort: "Ofen: je kWh Wärme", wert: Formate.ct(k?.stoveCtPerKwh)),
        ]
    }

    // MARK: - Hat sich das Verschieben gelohnt?

    public struct Schiebekarte: Sendable, Hashable {
        public let kernzahl: String
        /// Die Unterzeile sagt, was die Zahl bedeutet - das Vorzeichen allein sagt es nicht.
        public let bedeutung: String
        public let zeilen: [Kennzahl]
        public let hinweis: String?
    }

    /// **Dieselbe Zahl wie auf „Geld": eine Rechnung, an zwei Stellen gezeigt.**
    public static func schieben(_ s: ShiftReportOut?) -> Schiebekarte {
        guard let s, s.daysUsed > 0 else {
            return Schiebekarte(
                kernzahl: Formate.leer, bedeutung: "keine Aussage für diesen Zeitraum",
                zeilen: [],
                hinweis: s?.skippedDe
                    ?? "Dafür braucht es einen Tag mit genug gemessenen Stunden und laufender Wärmepumpe."
            )
        }
        return Schiebekarte(
            kernzahl: Formate.euro(abs(s.savingEur)),
            bedeutung: s.savingEur >= 0
                ? "gespart gegenüber einem Lauf ohne Preisblick"
                : "mehr bezahlt als ohne Preisblick",
            zeilen: [
                Kennzahl(
                    wort: "in andere Stunden verschoben",
                    wert:
                        "\(Formate.zahl(s.shiftedKwh, stellen: 0)) von \(Formate.zahl(s.heatPumpKwh, stellen: 0)) kWh"
                ),
                Kennzahl(
                    wort: "je verschobener kWh",
                    wert: s.savingCtPerKwh == nil
                        ? Formate.leer
                        : "\(Formate.zahl(s.savingCtPerKwh, stellen: 1)) ct"),
                Kennzahl(wort: "gerechnete Tage", wert: String(s.daysUsed)),
            ],
            hinweis: nil)
    }

    // MARK: - Taktung

    /// Auf welcher Datenbasis das Urteil beruht. Ohne die Angabe ist „unauffällig" eine
    /// Behauptung über einen Zeitraum, von dem man nicht weiß, wie viel davon gemessen ist.
    public static func taktkopf(_ c: CyclingStats) -> String? {
        c.coveredHours.map { "\(Formate.zahl($0, stellen: 0)) h bewertet" }
    }

    public static func taktzeilen(_ c: CyclingStats) -> [Kennzahl] {
        [
            Kennzahl(wort: "Läufe", wert: Formate.zahl(c.runs.map(Double.init), stellen: 0)),
            Kennzahl(wort: "Laufanteil", wert: Formate.prozent(c.dutyCycle)),
            Kennzahl(
                wort: "Lauf im Mittel",
                wert: c.meanRunMin == nil
                    ? Formate.leer : "\(Formate.zahl(c.meanRunMin, stellen: 0)) min"),
            Kennzahl(
                wort: "kürzester Lauf",
                wert: c.shortestRunMin == nil ? Formate.leer : "\(c.shortestRunMin ?? 0) min"),
            Kennzahl(
                wort: "Pause im Mittel",
                wert: c.meanPauseMin == nil
                    ? Formate.leer : "\(Formate.zahl(c.meanPauseMin, stellen: 0)) min"),
            Kennzahl(
                wort: "unter Mindestlaufzeit",
                wert: c.shortRuns == nil ? Formate.leer : "\(c.shortRuns ?? 0)×"),
        ]
    }

    // MARK: - Der Pelletofen

    public static func ofenkopf(_ o: StoveOut) -> String {
        let n = o.runs ?? 0
        return "\(n) Brennphase\(n == 1 ? "" : "n")"
    }

    public static func ofenzeilen(_ o: StoveOut) -> [Kennzahl] {
        [
            Kennzahl(wort: "davon mit Feuer", wert: dauer(minuten: o.burningMinutes)),
            Kennzahl(
                wort: "längste Phase",
                wert: (o.longestRunMin ?? 0) > 0 ? "\(o.longestRunMin ?? 0) min" : Formate.leer),
            Kennzahl(
                wort: "Brennstoff",
                wert: (o.pelletKg ?? 0) > 0
                    ? "\(Formate.zahl(o.pelletKg, stellen: 1)) kg" : Formate.leer),
            Kennzahl(
                wort: "zum Preis von",
                wert: (o.pelletEur ?? 0) > 0 ? Formate.euro(o.pelletEur) : Formate.leer),
            Kennzahl(
                wort: "Spreizung",
                wert: o.spreadK == nil
                    ? Formate.leer : "\(Formate.zahl(o.spreadK, stellen: 1)) K"),
            Kennzahl(
                wort: "Rauchgas max.",
                wert: o.fumeTempMaxC == nil
                    ? Formate.leer : "\(Formate.zahl(o.fumeTempMaxC, stellen: 0)) °C"),
            Kennzahl(wort: "Warmwasser", wert: dauer(minuten: o.dhwMinutes)),
            Kennzahl(
                wort: "Betriebsstunden",
                wert: o.operatingHours == nil
                    ? Formate.leer : "\(Formate.zahl(o.operatingHours, stellen: 0)) h"),
            Kennzahl(
                wort: "Zündungen",
                wert: o.ignitions == nil ? Formate.leer : String(o.ignitions ?? 0)),
        ]
    }

    /// Die Leistungsstufen, nach Stufe sortiert: „1: 0:45 h  2: 1:10 h".
    ///
    /// Der Schlüssel kommt als Zeichenkette aus JSON und wird als Zahl sortiert - sonst steht
    /// die Stufe 10 zwischen 1 und 2.
    public static func ofenstufen(_ o: StoveOut) -> [(stufe: String, dauer: String)] {
        o.minutesByLevel
            .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }
            .map { ($0.key, dauer(minuten: $0.value)) }
    }

    /// Der Hinweis zum Brennstoff steht nur, wenn die Schnecke überhaupt gezählt hat.
    public static func ofenbrennstoffsatz(_ o: StoveOut) -> String? {
        o.augerRevolutions != nil ? o.fuelNoteDe : nil
    }

    // MARK: - Bei offenem Fenster

    /// **Nur zeigen, wenn es etwas zu zeigen gibt:** eine Karte, die jeden Tag „null" sagt,
    /// liest nach einer Woche niemand mehr.
    public static func zeigtFenster(_ v: VentilationOut?) -> Bool {
        guard let v else { return false }
        return v.kwh > 0.01 || v.openMinutes > 0
    }

    public static func fensterkopf(_ v: VentilationOut) -> String {
        var aus = "\(v.openMinutes) min offen"
        if let s = v.share, s >= 0.01 {
            aus += " · \(Formate.zahl(s * 100, stellen: 0)) % der Entnahme"
        }
        return aus
    }

    // MARK: - Wärme im Zeitraum

    public static let spannentitel = "Wärme im Zeitraum"

    /// Dieselben zwölf Größen für Tag, Woche, Monat und Jahr nebeneinander.
    ///
    /// **Warum das mehr ist als vier Zahlen.** Ein Tag sagt nichts über die Anlage: er sagt
    /// etwas über das Wetter. Erst die vier Spalten nebeneinander zeigen, ob ein auffälliger
    /// Tag auffällig *ist*.
    ///
    /// Die Einheit steht in der Zeile und nicht in jeder Zelle - im Dashboard liefen vier
    /// Spalten mit „63,7 kWh" am Telefon ineinander.
    /// **Der Rückgabetyp ist ``Streifenzeile``, damit ``Spannenstreifen`` die Karte zeichnen
    /// kann.** Vorher gab diese Funktion ein Tupel zurück und passte damit in nichts außer eine
    /// nackte ``Tabelle``; die Karte verlor dadurch alles, was der Baustein mitbringt - den
    /// Hinweis „jeweils bis jetzt“ im Kartenkopf, die Tagesspalte, die nur „Heute“ heißt, wenn
    /// sie es ist, und die führende erste Zeile (`PeriodStrip.tsx:34-38, 9-16, 84`). Sechs
    /// andere Übersichten der App geben schon ``Streifenzeile`` zurück.
    ///
    /// Keine Zeile trägt einen Ton: die Vorlage setzt in `HeatOverview.tsx:118-131` bei keiner
    /// ein `tone`.
    public static func spannenzeilen(_ je: [Spanne: HeatBalanceOut]) -> [Streifenzeile] {
        let folge = Spanne.allCases
        func reihe(_ wort: String, _ wert: (HeatBalanceOut?) -> String) -> Streifenzeile {
            Streifenzeile(wort: wort, werte: folge.map { wert(je[$0]) })
        }
        return [
            reihe("Wärme gesamt · kWh") { feld($0) { $0.producedKwh } },
            reihe("Wärmepumpe · kWh") { feld($0) { $0.heatPumpKwh } },
            reihe("Ofen ins Wasser · kWh") { feld($0) { $0.stoveWaterKwh } },
            reihe("Ofen in den Raum · kWh") { feld($0) { $0.stoveRoomKwh } },
            reihe("Entnahme · kWh") { feld($0) { $0.drawKwh } },
            reihe("Verlust · kWh") { feld($0) { $0.lossKwh } },
            reihe("Strom Wärmepumpe · kWh") { feld($0) { $0.electricKwh } },
            reihe("Arbeitszahl") { Formate.zahl($0?.totals.copMean, stellen: 2) },
            reihe("nicht zuzuordnen · kWh") { feld($0) { $0.residualKwh } },
            reihe("Strom bezahlt") { Formate.euro($0?.cost?.heatPumpPaidEur) },
            reihe("Pellets · kg") { Formate.zahl($0?.cost?.stoveKg, stellen: 1) },
            reihe("Pellets im Wert von") { Formate.euro($0?.cost?.stoveEur) },
        ]
    }

    // MARK: - Die Annahmen in Zahlen

    /// Der Methodensatz mit den geltenden Annahmen.
    ///
    /// **Warum die Zahlen und nicht nur der Verweis.** Jede Wärmemenge dieser Seite ist
    /// gerechnet, nicht gemessen; wer sie prüfen will, braucht die Eingangsgrößen. Die
    /// Methodenkarte der App brachte bisher nur die Sätze des Dienstes, keine Zahl.
    public static func annahmensatz(_ p: HeatParamsOut) -> String {
        let kennlinie =
            p.copCurve
            .compactMap { paar -> String? in
                guard paar.count >= 2 else { return nil }
                return "\(Formate.zahl(paar[0], stellen: 0)) °C: \(Formate.zahl(paar[1], stellen: 1))"
            }
            .joined(separator: " · ")
        var aus = "Gerechnet wird mit: Kennlinie \(kennlinie.isEmpty ? Formate.leer : kennlinie)"
        aus += ", gültig bei \(Formate.zahl(p.copReferenceC, stellen: 0)) °C Vorlauf"
        aus += "; Puffer \(Formate.zahl(p.bufferVolumeLiters, stellen: 0)) l mit "
        aus += "\(Formate.zahl(p.bufferLossKwPerK.map { $0 * 1000 }, stellen: 0)) W/K Verlust"
        aus += "; Ofen \(Formate.zahl(p.stoveNominalHeatKw, stellen: 1)) kW, davon "
        aus += "\(Formate.zahl(p.stoveWaterHeatKw, stellen: 1)) kW ins Wasser"
        aus += "; Pellets \(Formate.zahl(p.pelletKwhPerKg, stellen: 2)) kWh/kg zu "
        aus += "\(Formate.zahl(p.pelletPriceEurPerT, stellen: 0)) €/t."
        aus += " Wer diese Werte unter Annahmen ändert, ändert jede Zahl auf dieser Seite,"
        aus += " auch die vergangener Jahre."
        return aus
    }

    /// Die Datengüte als eigene Zeile: wie viel des Zeitraums überhaupt gemessen ist.
    public static func abdeckungssatz(_ m: EnergyMetaOut) -> String {
        var teile: [String] = []
        if let c = m.coverage, c > 0 {
            teile.append("Datenabdeckung \(Formate.prozent(c))")
        } else {
            teile.append("noch keine Messdaten im Zeitraum")
        }
        if let seit = m.dataSince, Tag.istTag(seit) {
            teile.append("Aufzeichnung seit \(Tag.kurz(seit))")
        }
        return teile.joined(separator: " · ")
    }

    // MARK: - Die Pufferreihe

    /// Eine Minute der Pufferreihe, aus den losen Feldern des Dienstes gelesen.
    public struct Pufferpunkt: Sendable, Hashable, Identifiable {
        public let zeit: Date
        /// Die vier Schichten, von oben nach unten. Ein blinder Fühler bleibt `nil`.
        public let schichten: [Double?]
        public let wpKw: Double?
        public let ofenLaeuft: Bool

        public var id: Date { zeit }
    }

    public static let schichtnamen = ["oben", "mitte oben", "mitte unten", "unten"]

    /// `buffer_series` kommt als lose Felder und nicht als Modell - also hier einmal
    /// geordnet und nicht in der Ansicht.
    public static func pufferreihe(_ rohe: [[String: Mischwert]]) -> [Pufferpunkt] {
        rohe.compactMap { zeile in
            guard let iso = zeile["ts"]?.alsText, let t = Zeit.ausIso(iso) else { return nil }
            return Pufferpunkt(
                zeit: t,
                schichten: [
                    "buffer_temp_top_c", "buffer_temp_mid_top_c",
                    "buffer_temp_mid_bottom_c", "buffer_temp_bottom_c",
                ].map { zeile[$0]?.alsZahl },
                wpKw: zeile["heat_pump_power_kw"]?.alsZahl,
                ofenLaeuft: zeile["stove_running"]?.alsJa == true
                    || (zeile["stove_running"]?.alsZahl ?? 0) > 0)
        }
        .sorted { $0.zeit < $1.zeit }
    }

    /// Die Brennphasen des Ofens als Zeitspannen.
    ///
    /// **Das ist der eigentliche Erkenntnisgewinn des Pufferbildes:** steigt die Temperatur
    /// innerhalb eines Bandes, war es der Ofen und nicht die Wärmepumpe. Vorher musste man das
    /// aus der Abwesenheit der Pumpenleistung erschließen.
    public static func brennphasen(_ reihe: [Pufferpunkt]) -> [(von: Date, bis: Date)] {
        var aus: [(Date, Date)] = []
        var start: Date?
        for (i, p) in reihe.enumerated() {
            if p.ofenLaeuft, start == nil { start = p.zeit }
            if !p.ofenLaeuft, let s = start {
                aus.append((s, p.zeit))
                start = nil
            }
            if i == reihe.count - 1, let s = start {
                aus.append((s, p.zeit))
            }
        }
        return aus
    }
}
