import DuckCurveKit
import SwiftUI

/// Strom: was verbraucht wurde, wer es verbraucht hat, und woher es kam.
///
/// **Die fuehrende Zahl ist der Verbrauch.** Hier stand die Autarkie, mit der Begruendung, die
/// Erzeugung sei die falsche fuehrende Zahl - das stimmt, aber die Vorlage stellt auch nicht die
/// Erzeugung voran, sondern den Verbrauch (`reports/HouseReport.tsx:45`). Der Unterschied ist
/// nicht Geschmack: „59,2 kWh, davon die Waermepumpe 49 Prozent" ist der Anfang jeder Frage, die
/// man an diese Seite hat. Die Autarkie ist eine Folge davon und steht als fuenfte Kachel.
///
/// **Was hier nicht mehr steht:** „aus der Sonne", „eingespeist" und „Eigenverbrauch". Das sind
/// Zahlen der Erzeugung, und die haben ihren eigenen Reiter (``PvSeite``). „aus der Sonne"
/// (6,9 kWh Erzeugung) stand ausserdem dicht neben den 6,6 kWh der Autarkiezeile, die etwas
/// ganz anderes sind - Sonne und Speicher, die ins Haus gingen.
struct StromSeite: View {
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(Hauszustand.self) private var haus

    var body: some View {
        Berichtsseite { z, api in
            try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
        } inhalt: { bericht in
            // Ohne Ueberschrift: der aktive Reiter sagt, wo man ist (`ReportShell.tsx:99`).
            Kachelfeld(kacheln: kennzahlen(bericht))
            Karte(kicker: "Wer hat verbraucht?") {
                Balkenbild(stuecke: verbrauch(bericht))
            }
            Karte(kicker: "Woher kam der Strom?") {
                Balkenbild(stuecke: herkunft(bericht))
            }
            Methode(
                [
                    "Haushalt (Rest) = Hausverbrauch ohne Wärmepumpe und Wallbox. Verbraucher erhalten die Quellen anteilig an ihrer Leistung je Minute.",
                    bericht.meta.estimatedNoteDe,
                ],
                // Die Abdeckung steht in der Kurzzeile und nicht im Rumpf: sie schränkt jede
                // Zahl dieser Seite ein, und zugeklappt wäre sie verschwiegen.
                kurz: [
                    abdeckung(bericht),
                    bericht.meta.dataSince.map { "Aufzeichnung seit \(Tag.lang(String($0.prefix(10))))" },
                ].compactMap { $0 }.joined(separator: " · ")
            )
        }
    }

    /// Wie lueckenlos die Minutenwerte des Zeitraums sind.
    ///
    /// **Sie stand nirgends.** Jede Zahl dieser Seite steht auf Minutenwerten; wo die fehlen,
    /// rechnet der Dienst mit weniger, als er zu haben scheint. Das Feld lag ungelesen im
    /// Modell.
    private func abdeckung(_ b: EnergySummaryOut) -> String? {
        guard let anteil = b.meta.coverage else { return nil }
        if anteil <= 0 { return "Noch keine Messdaten im Zeitraum" }
        return "Datenabdeckung \(Formate.prozent(anteil))"
    }

    /// Die sechs Kennzahlen der Vorlage, in ihrer Reihenfolge.
    private func kennzahlen(_ b: EnergySummaryOut) -> [Kacheldaten] {
        let t = b.totals
        let gesamt = t.houseKwh ?? 0
        return [
            Kacheldaten(
                "Verbrauch gesamt", Formate.zahl(gesamt, stellen: 1), einheit: "kWh",
                dazu: (t.minutes ?? 0) > 0
                    ? "\(Int((Double(t.minutes ?? 0) / 60).rounded())) h bewertet" : "keine Daten"
            ),
            Kacheldaten(
                "Wärmepumpe", Formate.zahl(t.heatPumpKwh ?? 0, stellen: 1), einheit: "kWh",
                dazu: anteil(t.heatPumpKwh, gesamt)
            ),
            Kacheldaten(
                "Wallbox", Formate.zahl(t.evKwh ?? 0, stellen: 1), einheit: "kWh",
                dazu: anteil(t.evKwh, gesamt), farbe: Farbe.mist
            ),
            Kacheldaten(
                "Haushalt (Rest)", Formate.zahl(t.baseKwh ?? 0, stellen: 1), einheit: "kWh",
                dazu: anteil(t.baseKwh, gesamt), farbe: Farbe.text3
            ),
            Kacheldaten(
                "Autarkie", Formate.prozent(t.autarky),
                // Eine Zahl, kein Erklaersatz: wie viele Kilowattstunden ohne das Netz
                // auskamen. Der Satz stand davor und sagte nur, was das Wort schon sagt.
                dazu: "\(Formate.zahl((t.pvDirectKwh ?? 0) + (t.batteryToHouseKwh ?? 0), stellen: 1)) kWh ohne Netz",
                farbe: Farbe.amber
            ),
            // **Kosten sehen alle; nur der Weg zur Rechnungspruefung bleibt dem Hausherrn**
            // (`HouseReport.tsx:50`).
            Kacheldaten(
                "Netzbezug", Formate.euro(t.importCostEur),
                dazu: netzzeile(t), farbe: Farbe.alarm,
                weg: darfPruefen ? "/geld/rechnungen" : nil
            ),
        ]
    }

    private var darfPruefen: Bool { haus.darfSchalten }

    private func netzzeile(_ t: EnergyTotalsOut) -> String {
        let kwh = "\(Formate.zahl(t.importKwh ?? 0, stellen: 1)) kWh"
        return darfPruefen ? "\(kwh) · Rechnungen prüfen" : kwh
    }

    private func anteil(_ teil: Double?, _ ganzes: Double) -> String? {
        guard let teil, ganzes > 0 else { return nil }
        return "\(Formate.prozent(teil / ganzes)) des Verbrauchs"
    }

    /// Wer verbraucht hat - in derselben Reihenfolge wie die Kacheln darueber.
    private func verbrauch(_ b: EnergySummaryOut) -> [Balkenbild.Stueck] {
        [
            Balkenbild.Stueck(
                name: "Wärmepumpe", farbe: Farbe.waermepumpe,
                werte: b.buckets.map { ($0.label, $0.totals.heatPumpKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "Wallbox", farbe: Farbe.diagrammWallbox,
                werte: b.buckets.map { ($0.label, $0.totals.evKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "Haushalt", farbe: Farbe.diagrammHaushalt,
                werte: b.buckets.map { ($0.label, $0.totals.baseKwh ?? 0) }
            ),
        ]
    }

    /// Woher der Strom kam: Sonne direkt, aus dem Speicher, aus dem Netz. Gestapelt, weil die
    /// drei sich zum Hausverbrauch addieren.
    private func herkunft(_ b: EnergySummaryOut) -> [Balkenbild.Stueck] {
        [
            Balkenbild.Stueck(
                name: "Sonne direkt", farbe: Farbe.pv,
                werte: b.buckets.map { ($0.label, $0.totals.pvDirectKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "aus dem Speicher", farbe: Farbe.diagrammSpeicher,
                werte: b.buckets.map { ($0.label, $0.totals.batteryToHouseKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "aus dem Netz", farbe: Farbe.diagrammNetz,
                werte: b.buckets.map { ($0.label, $0.totals.gridToHouseKwh ?? 0) }
            ),
        ]
    }
}

/// Photovoltaik: was die Anlage erzeugt hat und was daraus wurde.
struct PvSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
        } inhalt: { b in
            Kachelfeld(kacheln: kennzahlen(b), kicker: "Photovoltaik")
            Karte(kicker: "Was aus der Erzeugung wurde") {
                Balkenbild(stuecke: [
                    .init(
                        name: "direkt ins Haus", farbe: Farbe.pv,
                        werte: b.buckets.map { ($0.label, $0.totals.pvDirectKwh ?? 0) }
                    ),
                    .init(
                        name: "in den Speicher", farbe: Farbe.batterie,
                        werte: b.buckets.map { ($0.label, $0.totals.pvToBatteryKwh ?? 0) }
                    ),
                    .init(
                        name: "eingespeist", farbe: Farbe.netzEinspeisung,
                        werte: b.buckets.map { ($0.label, $0.totals.exportKwh ?? 0) }
                    ),
                ])
            }
            Methode([b.meta.estimatedNoteDe])
        }
    }

    private func kennzahlen(_ b: EnergySummaryOut) -> [Kacheldaten] {
        let t = b.totals
        let direkt = t.pvDirectKwh ?? 0
        let speicher = t.pvToBatteryKwh ?? 0
        return [
            Kacheldaten("erzeugt", Formate.zahl(t.pvKwh ?? 0, stellen: 1), einheit: "kWh", farbe: Farbe.pv),
            Kacheldaten("direkt verbraucht", Formate.zahl(direkt, stellen: 1), einheit: "kWh"),
            Kacheldaten("in den Speicher", Formate.zahl(speicher, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "eingespeist", Formate.zahl(t.exportKwh ?? 0, stellen: 1), einheit: "kWh",
                farbe: Farbe.netzEinspeisung
            ),
            Kacheldaten("Eigenverbrauch", Formate.prozent(t.selfConsumptionShare)),
            Kacheldaten(
                "ersparte Kosten", Formate.euro(t.pvDirectSavingsEur),
                dazu: "gegen den Bezugspreis der jeweiligen Stunde"
            ),
        ]
    }
}

/// Speicher: Ladung, Entladung und woher die Ladung kam.
///
/// **Die Herkunft der Ladung ist die eigentliche Frage.** Ein Speicher, der nachts aus dem Netz
/// laedt, verschiebt Kosten statt sie zu sparen - und ob er das tut, steht in
/// `grid_to_battery_dark_kwh`.
struct SpeicherSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            // Zwei Antworten: die Zahlen, und der Pruefbericht dazu. Der ist reiner Text - er
            // haelt den gemeldeten Ladestand gegen Hausverbrauch und Leistung und sagt, wo es
            // nicht aufgeht. Eine Datenstruktur waere er nicht, er ist eine Antwort zum Lesen.
            async let zahlen = api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
            async let pruefung = try? api.speicherPruefung(z.spanne.rawValue, anker: z.anker)
            return try await (zahlen: zahlen, pruefung: pruefung)
        } inhalt: { paar in
            let b = paar.zahlen
            Kachelfeld(kacheln: kennzahlen(b), kicker: "Speicher")
            Karte(kicker: "Woher die Ladung kam") {
                Balkenbild(stuecke: [
                    .init(
                        name: "aus der Sonne", farbe: Farbe.pv,
                        werte: b.buckets.map { ($0.label, $0.totals.pvToBatteryKwh ?? 0) }
                    ),
                    .init(
                        name: "aus dem Netz", farbe: Farbe.netzBezug,
                        werte: b.buckets.map { ($0.label, $0.totals.gridToBatteryKwh ?? 0) }
                    ),
                ])
            }
            Karte(kicker: "Entladung") {
                Balkenbild(
                    stuecke: [
                        .init(
                            name: "ins Haus", farbe: Farbe.batterie,
                            werte: b.buckets.map { ($0.label, $0.totals.batteryToHouseKwh ?? 0) }
                        )
                    ],
                    gestapelt: false
                )
            }
            if let p = paar.pruefung, !p.isEmpty {
                Karte(kicker: "Nachgerechnet") {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(p)
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                            .textSelection(.enabled)
                    }
                }
            }
            Methode([
                b.meta.estimatedNoteDe,
                "Die Herkunft der Ladung ist gerechnet, nicht gemessen: der Speicher meldet nur, "
                    + "wie viel er genommen hat, nicht woher.",
            ])
        }
    }

    private func kennzahlen(_ b: EnergySummaryOut) -> [Kacheldaten] {
        let t = b.totals
        let dunkel = t.gridToBatteryDarkKwh ?? 0
        return [
            Kacheldaten("geladen", Formate.zahl(t.batteryChargeKwh ?? 0, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "entladen", Formate.zahl(t.batteryDischargeKwh ?? 0, stellen: 1), einheit: "kWh",
                farbe: Farbe.batterie
            ),
            Kacheldaten(
                "aus der Sonne geladen", Formate.zahl(t.pvToBatteryKwh ?? 0, stellen: 1),
                einheit: "kWh", farbe: Farbe.pv
            ),
            Kacheldaten(
                "aus dem Netz geladen", Formate.zahl(t.gridToBatteryKwh ?? 0, stellen: 1),
                einheit: "kWh",
                dazu: dunkel >= 0.05 ? "davon \(Formate.kwh(dunkel)) im Dunkeln" : nil,
                farbe: dunkel >= 0.05 ? Farbe.achtung : Farbe.text1
            ),
            Kacheldaten("Wert der Entladung", Formate.euro(t.batteryDischargeValueEur)),
            Kacheldaten(
                "unterm Strich", Formate.euro(t.batteryNetEur),
                dazu: "Entladung minus Ladekosten"
            ),
        ]
    }
}
