import Foundation

/// Was die Stromseite rechnet: ihre sechs Kennzahlen, die zwei gestapelten Balkenbilder mit
/// ihrer Ablesung und die vier Zeilen des Überblicksstreifens.
///
/// **Warum das alles hier liegt und nicht in der Ansicht.** Jede Zahl dieser Seite ist eine
/// Auswahl: welcher Satz unter einer Kachel steht, ob eine fehlende Menge als Strich oder als
/// Null erscheint, ab welcher Größe die Nachkommastelle wegfällt, welche Reihen eines Balkens
/// beim Ablesen genannt werden. In einer `View` wäre keine davon prüfbar - und die Vorlage
/// trifft jede einzelne mit einer Begründung, die man nachlesen kann
/// (`apps/web/src/components/reports/HouseReport.tsx`).
///
/// **Die Form der Balken ist dieselbe wie auf /pv**, darum liegen ``Balken`` und ``Ablesung``
/// hier nur als anderer Name für die Typen aus ``Pvbild``. Zwei Typen für dieselbe Sache wären
/// die Art Unordnung, aus der später zwei verschiedene Antworten auf dieselbe Frage werden
/// (siehe die Begründung an ``Kennzahl``).
public enum Stromuebersicht {

    /// Ein Balken: sein Wort an der Achse und die Werte in der Reihenfolge der Reihen.
    public typealias Balken = Pvbild.Balken
    /// Was beim Lesen eines Balkens dasteht.
    public typealias Ablesung = Pvbild.Ablesung

    // MARK: - Die Wörter der Seite

    /// Der Kicker des Reiters (`HouseReport.tsx:42`).
    ///
    /// **Er steht noch nirgends.** Die Vorlage setzt ihn rechts in die Reiterzeile
    /// (`AreaNav.tsx:96`, am Handy ausgeblendet); in der App hat das gemeinsame Gerippe keine
    /// Stelle dafür, und eine einzubauen ist eine Entscheidung über alle dreizehn
    /// Berichtsseiten. Das Wort steht hier, damit es beim Umbau des Gerippes nicht neu
    /// gefunden werden muss.
    public static let seitenkicker = "Verbrauch · Verbraucher · Herkunft"

    public static let verbrauchstitel = "Wer hat verbraucht?"
    public static let herkunftstitel = "Woher kam der Strom?"
    public static let ueberblickstitel = "Strom im Überblick"

    /// Das Wort der Kachel, die zur Rechnungsprüfung führt.
    public static let netzbezugswort = "Netzbezug"

    /// Wohin die Netzbezugskachel führt - **und nur sie**.
    ///
    /// **Kosten sehen alle; nur der Weg zur Rechnungsprüfung bleibt dem Hausherrn**
    /// (`HouseReport.tsx:50-57`). Ein Gast sieht also dieselbe Zahl, aber keinen Griff: die
    /// Abrechnung ist ihm verschlossen, und ein Verweis, der in eine Absage führt, ist
    /// schlechter als keiner.
    public static func weg(_ wort: String, hausherr: Bool) -> String? {
        guard wort == netzbezugswort, hausherr else { return nil }
        return "/geld/rechnungen"
    }

    // MARK: - Die sechs Kennzahlen

    /// Die sechs Kennzahlen der Vorlage, in ihrer Reihenfolge (`HouseReport.tsx:44-59`).
    ///
    /// **Die führende Zahl ist der Verbrauch.** „59,2 kWh, davon die Wärmepumpe 49 Prozent“ ist
    /// der Anfang jeder Frage, die man an diese Seite hat; die Autarkie ist eine Folge davon und
    /// steht als fünfte.
    ///
    /// **Ein fehlendes Feld ist ein Strich und keine Null.** Die Vorlage schreibt jede der
    /// sechs Zahlen durch `de1`/`eur`/`pct`, und die liefern bei `null` einen Strich
    /// (`ReportShell.tsx:14-16`). Die App setzte hier `?? 0`: ein Zähler, der schweigt, sah
    /// damit aus wie einer, der null gemessen hat - und das ist auf einer Seite, die Verbrauch
    /// abrechnet, der Unterschied zwischen „nichts verbraucht“ und „nichts gewusst“.
    ///
    /// Der Satz unter der ersten Kachel ist derselbe wie auf /pv (``Pvbild/bewertet(_:)``):
    /// ohne Minuten steht „keine Daten“ und nicht „0 h bewertet“ - das zweite liest sich wie
    /// eine Messung.
    public static func kacheln(_ b: EnergySummaryOut?, hausherr: Bool) -> [Kennzahl] {
        let t = b?.totals
        return [
            Kennzahl(
                wort: "Verbrauch gesamt", wert: Formate.zahl(t?.houseKwh, stellen: 1),
                einheit: "kWh", dazu: Pvbild.bewertet(t?.minutes)
            ),
            Kennzahl(
                wort: "Wärmepumpe", wert: Formate.zahl(t?.heatPumpKwh, stellen: 1),
                einheit: "kWh", dazu: anteil(t?.heatPumpKwh, t?.houseKwh)
            ),
            Kennzahl(
                wort: "Wallbox", wert: Formate.zahl(t?.evKwh, stellen: 1), einheit: "kWh",
                dazu: anteil(t?.evKwh, t?.houseKwh), ton: .nebel
            ),
            Kennzahl(
                wort: "Haushalt (Rest)", wert: Formate.zahl(t?.baseKwh, stellen: 1),
                einheit: "kWh", dazu: anteil(t?.baseKwh, t?.houseKwh), ton: .gedaempft
            ),
            Kennzahl(
                wort: "Autarkie", wert: Formate.prozent(t?.autarky),
                // Eine Zahl, kein Erklärsatz: wie viele Kilowattstunden ohne das Netz
                // auskamen (`HouseReport.tsx:49`).
                dazu: t.map { "\(Formate.kwh(($0.pvDirectKwh ?? 0) + ($0.batteryToHouseKwh ?? 0))) ohne Netz" },
                ton: .bernstein
            ),
            Kennzahl(
                wort: netzbezugswort, wert: Formate.euro(t?.importCostEur),
                dazu: t.map { netzzeile($0, hausherr: hausherr) },
                // Der Ton `netz` der Vorlage (`HouseReport.tsx`). Bis zum 24.11.2026 stand die
                // Zahl hier in Textfarbe und im Dashboard rot; jetzt in beiden violett.
                ton: .netz
            ),
        ]
    }

    /// „49 % des Verbrauchs“ (`HouseReport.tsx:38`).
    ///
    /// Ohne Verbrauch kein Anteil: ein Nenner von Null ergibt keine Prozentzahl, und eine Null
    /// an ihrer Stelle wäre eine Aussage über einen Tag, von dem nichts bekannt ist.
    static func anteil(_ teil: Double?, _ ganzes: Double?) -> String? {
        guard let teil, let ganzes, ganzes > 0 else { return nil }
        return "\(Formate.prozent(teil / ganzes)) des Verbrauchs"
    }

    /// Die Menge unter den Netzkosten, beim Hausherrn mit dem Hinweis auf den Griff
    /// (`HouseReport.tsx:57`).
    static func netzzeile(_ t: EnergyTotalsOut, hausherr: Bool) -> String {
        let menge = Formate.kwh(t.importKwh)
        return hausherr ? "\(menge) · Rechnungen prüfen" : menge
    }

    // MARK: - Wer hat verbraucht?

    /// Die drei Reihen des ersten Bilds (`CONSUMERS`, `HouseReport.tsx:19-23`).
    ///
    /// **Die Wärmepumpe in ihrer Farbe, wie auf jeder anderen Seite.** Sie war in der Vorlage
    /// einmal hell und der Haushalt sandfarben; neben dem Orange der Wärmepumpe wäre Sand bei
    /// Deuteranopie dieselbe Farbe (ΔE 0,2). Der Rest des Hauses ist deshalb hell: schlechtestes
    /// Paar ΔE 18,2 normal und 16,2 deutan (gemessen 10.11.2026 gegen die Kartenfläche)
    /// (`HouseReport.tsx:15-18`, `palette.ts:38,43,53`).
    public enum Verbraucher: String, Sendable, Hashable, CaseIterable, Identifiable {
        case waermepumpe
        case wallbox
        case haushalt

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .waermepumpe: return "Wärmepumpe"
            case .wallbox: return "Wallbox"
            // „Haushalt“ und nicht „Haushalt (Rest)“: in der Legende neben zwei Geräten sagt
            // die Reihenfolge schon, was der Rest ist (`HouseReport.tsx:22`).
            case .haushalt: return "Haushalt"
            }
        }

        public var farbe: Farbwert {
            switch self {
            case .waermepumpe: return Marken.waermepumpe
            case .wallbox: return Marken.diagrammWallbox
            case .haushalt: return Marken.diagrammHaushalt
            }
        }

        public func wert(_ t: EnergyTotalsOut) -> Double {
            switch self {
            case .waermepumpe: return balkenwert(t.heatPumpKwh)
            case .wallbox: return balkenwert(t.evKwh)
            case .haushalt: return balkenwert(t.baseKwh)
            }
        }
    }

    // MARK: - Woher kam der Strom?

    /// Die drei Reihen des zweiten Bilds (`SOURCES`, `HouseReport.tsx:24-28`).
    ///
    /// **Die Wörter sind die der Vorlage und nicht die der App.** Dort stand „Sonne direkt“,
    /// „aus dem Speicher“ und „aus dem Netz“; die Vorlage schreibt „PV direkt“, „aus Batterie“
    /// und „aus Netz“. Das ist kein Geschmack: dieselben drei Größen heißen in den Kacheln von
    /// /speicher und in der Aufstellung von /geld ebenso, und eine Legende, die sie anders
    /// nennt, macht aus einer Zahl zwei.
    public enum Herkunft: String, Sendable, Hashable, CaseIterable, Identifiable {
        case pvDirekt
        case batterie
        case netz

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .pvDirekt: return "PV direkt"
            case .batterie: return "aus Batterie"
            case .netz: return "aus Netz"
            }
        }

        public var farbe: Farbwert {
            switch self {
            case .pvDirekt: return Marken.pv
            case .batterie: return Marken.diagrammSpeicher
            case .netz: return Marken.diagrammNetz
            }
        }

        public func wert(_ t: EnergyTotalsOut) -> Double {
            switch self {
            case .pvDirekt: return balkenwert(t.pvDirectKwh)
            case .batterie: return balkenwert(t.batteryToHouseKwh)
            case .netz: return balkenwert(t.gridToHouseKwh)
            }
        }
    }

    /// Ein Wert im gestapelten Balken.
    ///
    /// **Ein fehlendes Feld ist hier eine Null** - anders als in den Kacheln darüber. Ein Loch
    /// in einem gestapelten Balken verschiebt die Reihen über sich, und ein Stapel, dessen
    /// Mitte fehlt, behauptet eine Höhe, die niemand gemessen hat (`charts.ts:84`:
    /// `typeof v === "number" ? … : 0`).
    ///
    /// Gerundet wird auf zwei Stellen, wie die Vorlage die Balkenwerte rundet
    /// (`charts.ts:85`: `Math.round(v * 100) / 100`) - gezeigt wird eine Stelle, aber die
    /// Summe des Stapels soll dieselbe sein wie dort.
    static func balkenwert(_ roh: Double?) -> Double {
        guard let roh, roh.isFinite else { return 0 }
        return (roh * 100).rounded() / 100
    }

    /// Die Balken des ersten Bilds, einer je Zeitabschnitt.
    public static func verbrauch(_ b: EnergySummaryOut?) -> [Balken] {
        balken(b) { t in Verbraucher.allCases.map { $0.wert(t) } }
    }

    /// Die Balken des zweiten Bilds, einer je Zeitabschnitt.
    public static func herkunft(_ b: EnergySummaryOut?) -> [Balken] {
        balken(b) { t in Herkunft.allCases.map { $0.wert(t) } }
    }

    static func balken(
        _ b: EnergySummaryOut?, _ werte: (EnergyTotalsOut) -> [Double]
    ) -> [Balken] {
        (b?.buckets ?? []).enumerated().map { i, e in
            Balken(nummer: i, wort: e.label, werte: werte(e.totals))
        }
    }

    /// Was beim Lesen eines Balkens dasteht: der Abschnitt, die Reihen ungleich Null und die
    /// Summe (`charts.ts:58-73`).
    ///
    /// **Ohne das ist der Wert eines Balkens nirgends ablesbar.** An einem Monatsbild mit
    /// dreißig Balken ist die Zahl sonst verloren. Reihen mit Null fallen weg - „Wallbox
    /// 0,0 kWh“ an einem Tag ohne Auto ist eine Zeile ohne Aussage; die Vorlage filtert sie
    /// genauso heraus (`charts.ts:68`).
    public static func ablesung(
        _ balken: Balken, namen: [String], einheit: String = "kWh"
    ) -> Ablesung {
        let zeilen = namen.enumerated().compactMap { i, name -> Ablesung.Zeile? in
            guard i < balken.werte.count, balken.werte[i] != 0 else { return nil }
            return Ablesung.Zeile(
                name: name,
                wert: "\(Formate.zahl(balken.werte[i], stellen: 1))\(Formate.schmalesLeerzeichen)\(einheit)"
            )
        }
        return Ablesung(
            wort: balken.wort, zeilen: zeilen,
            summe:
                "Summe \(Formate.zahl(balken.summe, stellen: 1))\(Formate.schmalesLeerzeichen)\(einheit)"
        )
    }

    // MARK: - Strom im Überblick: vier Größen gegen vier Spannen

    /// Vier Größen gegen Tag, Woche, Monat und Jahr **desselben Ankertags**
    /// (`HouseReport.tsx:75-80`).
    ///
    /// **Ohne diesen Streifen fehlt der Seite ihre Einordnung.** „59,2 kWh“ ohne den Monat
    /// daneben sagt nicht, ob der Tag viel war. Die Spalten folgen der Blätterleiste: blättert
    /// man auf einen vergangenen Tag, zeigen sie dessen Woche, Monat und Jahr und nicht mehr
    /// die laufenden (`PeriodStrip.tsx:22-26`).
    ///
    /// Fehlt eine Spanne, steht in ihrer Spalte ein Strich und nicht eine Null
    /// (`HouseReport.tsx:39`) - die vier Abfragen laufen nebeneinander, und eine gescheiterte
    /// lässt ihre Spalte leer, ohne den Streifen mitzunehmen.
    ///
    /// **„Netzkosten“ trägt ``Kennzahl/Ton/alarm``** - `--alert` #E0533D, so wie die Vorlage
    /// die Zeile setzt (`HouseReport.tsx:78`: `tone: "ember"`; `PeriodStrip.tsx:19` führt
    /// `ember` auf `var(--alert)`). Vorher stand hier `glut` #E0966B, weil ``Kennzahl/Ton``
    /// keinen Alarmton kannte; seit es ihn gibt, ist die Ersatzwahl unnötig. Dieselbe Zeile
    /// steht in ``Gelduebersicht/spannenzeilen(_:)``.
    public static func spannenzeilen(_ je: [Spanne: EnergySummaryOut]) -> [Streifenzeile] {
        let folge = Spanne.allCases
        func reihe(
            _ wort: String, _ ton: Kennzahl.Ton = .normal,
            _ wert: (EnergyTotalsOut) -> String
        ) -> Streifenzeile {
            Streifenzeile(
                wort: wort,
                werte: folge.map { je[$0].map { wert($0.totals) } ?? Formate.leer },
                ton: ton
            )
        }
        return [
            // Ab hundert kWh ohne Nachkommastelle (`HouseReport.tsx:76`): das Zehntel einer
            // Jahressumme ist Rauschen und nimmt in einer Tabelle mit vier Spalten den Platz
            // der Spalte daneben.
            reihe("Verbrauch · kWh") { Formate.kwhNachGroesse($0.houseKwh) },
            reihe("Autarkie", .bernstein) { Formate.prozent($0.autarky) },
            reihe("Netzkosten", .netz) { Formate.euro($0.importCostEur) },
            // `export_revenue_eur` stand auf dieser Seite nirgends und lag ungelesen im
            // Modell: was eingespeist wurde, gehört zur Einordnung des Zeitraums.
            reihe("Einspeiseerlös") { Formate.euro($0.exportRevenueEur) },
        ]
    }

    // MARK: - Methode

    /// Der Satz, der dieser Seite allein gehört (`HouseReport.tsx:82`).
    ///
    /// Die Kurzzeile daneben (Abdeckung und Aufzeichnungsbeginn) ist für jede Berichtsseite
    /// dieselbe und steht schon als ``Wallbox/abdeckung(_:)`` über demselben ``EnergyMetaOut``.
    public static let methodensatz =
        "Haushalt (Rest) = Hausverbrauch ohne Wärmepumpe und Wallbox. "
        + "Verbraucher erhalten die Quellen anteilig an ihrer Leistung je Minute."
}
