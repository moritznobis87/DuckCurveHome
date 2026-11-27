import Foundation

/// Die vier Zahlen unter der Tageskurve - gestern, heute, morgen.
///
/// **Warum das hier steht.** Es ist die Vorlage `apps/web/src/components/home/tage.ts`, Funktion
/// `kennzahlen`, Zeile für Zeile. Die App zeigte an dieser Stelle etwas anderes: Sonne, „im
/// Haus", „für die Wärme" und je nach Tag Netzbezug oder Preis. Die Autarkie, das bezahlte Geld
/// und der Mittelpreis kamen in der ganzen Seite nicht vor - also drei der vier Zahlen, die die
/// Wandanzeige nennt. Das war kein Diagrammfehler, sondern eine andere Auskunft.
///
/// **Immer vier Kacheln, damit die Zeile beim Umschalten nicht springt.** Eine Zahl, die es für
/// einen Tag nicht geben kann, steht als Strich da und sagt im Wort, warum - „Preise kommen gegen
/// 13 Uhr" ist keine Fehlermeldung, sondern der Fahrplan der Börse.
public enum Tageskacheln {

    /// Wärmemenge eines Fensters: thermisch, und der Strom dafür.
    public struct Waermemenge: Sendable, Hashable {
        public let thermisch: Double
        public let elektrisch: Double

        public init(thermisch: Double, elektrisch: Double) {
            self.thermisch = thermisch
            self.elektrisch = elektrisch
        }
    }

    /// Ein Preis mit seiner Uhrzeit. Die Uhrzeit wird gebraucht: „günstigste Stunde ab 13:00".
    public struct Preispunkt: Sendable, Hashable {
        public let zeit: Date
        public let ct: Double

        public init(zeit: Date, ct: Double) {
            self.zeit = zeit
            self.ct = ct
        }
    }

    /// Was von morgen bekannt ist.
    public struct Morgen: Sendable, Hashable {
        public let pvKwh: Double?
        public let waerme: Waermemenge?
        public let preise: [Preispunkt]

        public init(pvKwh: Double? = nil, waerme: Waermemenge? = nil, preise: [Preispunkt] = []) {
            self.pvKwh = pvKwh
            self.waerme = waerme
            self.preise = preise
        }
    }

    // MARK: - Die vier Zahlen

    public static func kennzahlen(
        tag: Kurventag, bilanz: EnergyTotalsOut?, preisJetzt: Double?, morgen: Morgen
    ) -> [Kennzahl] {
        if tag == .morgen { return morgenKacheln(morgen) }

        let letzte: Kennzahl =
            tag == .heute
            ? Kennzahl(
                wort: "Strom gerade", wert: Formate.zahl(preisJetzt, stellen: 1),
                einheit: "ct", ton: (preisJetzt ?? 0) < 0 ? .sonne : .normal)
            : Kennzahl(
                wort: "Strom im Mittel",
                wert: Formate.zahl(bilanz?.avgImportPriceCt, stellen: 1), einheit: "ct")

        return [
            Kennzahl(
                wort: "Sonne geerntet", wert: Formate.zahl(bilanz?.pvKwh, stellen: 1),
                einheit: "kWh", ton: .sonne),
            Kennzahl(wort: "ohne Netz", wert: autarkie(bilanz?.autarky), einheit: "%"),
            Kennzahl(
                wort: tag == .heute ? "bezahlt bis jetzt" : "bezahlt",
                wert: Formate.zahl(bilanz?.importCostEur, stellen: 2), einheit: "€"),
            letzte,
        ]
    }

    /// Die Autarkie kommt als Anteil und steht als ganze Prozent da. 0,734 wird 73.
    static func autarkie(_ anteil: Double?) -> String {
        guard let anteil, anteil.isFinite else { return Formate.leer }
        return String(Int((anteil * 100).rounded()))
    }

    private static func morgenKacheln(_ m: Morgen) -> [Kennzahl] {
        let ct = m.preise.map(\.ct)
        let mittel = ct.isEmpty ? nil : ct.reduce(0, +) / Double(ct.count)
        let guenstigste = m.preise.min { $0.ct < $1.ct }

        return [
            Kennzahl(
                wort: "Sonne erwartet", wert: Formate.zahl(m.pvKwh, stellen: 1),
                einheit: "kWh", ton: .sonne),
            Kennzahl(
                wort: "Wärme erwartet", wert: Formate.zahl(m.waerme?.thermisch, stellen: 1),
                einheit: "kWh",
                // Dieselben Worte wie im Dashboard (`tage.ts`: „Wärme erwartet, dafür 30,3 kWh Strom“).
                dazu: m.waerme.map { "dafür \(Formate.zahl($0.elektrisch, stellen: 1)) kWh Strom" }),
            Kennzahl(
                wort: ct.isEmpty ? "Preise kommen gegen 13 Uhr" : "Strom im Mittel",
                wert: Formate.zahl(mittel, stellen: 1), einheit: "ct"),
            Kennzahl(
                wort: guenstigste.map { "günstigste Stunde ab \(Formate.hhmm($0.zeit))" }
                    ?? "günstigste Stunde",
                wert: Formate.zahl(guenstigste?.ct, stellen: 1), einheit: "ct",
                ton: (guenstigste?.ct ?? 0) < 0 ? .sonne : .normal),
        ]
    }

    // MARK: - Was in ein Fenster fällt

    /// Erwartete Erzeugung im Fenster, aus dem Raster der Planintervalle.
    ///
    /// Der Schritt wird aus den ersten zwei Stempeln genommen und nicht als Viertelstunde
    /// angenommen: der Planer liefert auch stündlich, und dann wäre die Summe durch vier zu klein.
    public static func pvSumme(_ intervalle: [PlanIntervalOut], von: Date, bis: Date) -> Double? {
        let punkte = intervalle.compactMap { iv -> (Date, Double)? in
            guard let t = Zeit.ausIso(iv.ts) else { return nil }
            return (t, iv.expectedPvKw)
        }
        guard punkte.count >= 2 else { return nil }
        let schrittH = max(1.0 / 60, punkte[1].0.timeIntervalSince(punkte[0].0) / 3600)
        let drin = punkte.filter { $0.0 >= von && $0.0 < bis }
        guard !drin.isEmpty else { return nil }
        return drin.reduce(0) { $0 + $1.1 * schrittH }
    }

    /// Die Preise, die für das Fenster bekannt sind. Leer heißt: die Börse hat sie noch nicht.
    public static func preise(_ intervalle: [PlanIntervalOut], von: Date, bis: Date) -> [Preispunkt]
    {
        intervalle.compactMap { iv -> Preispunkt? in
            guard let ct = iv.priceCtKwh, let t = Zeit.ausIso(iv.ts), t >= von, t < bis else {
                return nil
            }
            return Preispunkt(zeit: t, ct: ct)
        }
    }

    /// Wärmebedarf und Strom dafür, aus der stündlichen Wärmelastprognose.
    ///
    /// Die Punkte sind Stundenwerte in kW, eine Stunde lang - die Summe ist damit zugleich die
    /// Energiemenge in kWh.
    public static func waermeSumme(_ punkte: [HeatForecastPoint], von: Date, bis: Date)
        -> Waermemenge?
    {
        let drin = punkte.filter {
            guard let t = Zeit.ausIso($0.ts) else { return false }
            return t >= von && t < bis
        }
        guard !drin.isEmpty else { return nil }
        return Waermemenge(
            thermisch: drin.reduce(0) { $0 + $1.heatingKw + $1.dhwKw },
            elektrisch: drin.reduce(0) { $0 + $1.electricKw })
    }

    /// Anfang und Ende eines der drei Tage, in der Hauszeit.
    public static func fenster(_ tag: Kurventag, jetzt: Date) -> (von: Date, bis: Date)? {
        Tag.zeitraum(Tag.plus(Tag.heute(jetzt: jetzt), tag.versatz))
    }
}
