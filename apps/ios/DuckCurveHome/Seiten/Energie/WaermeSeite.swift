import DuckCurveKit
import SwiftUI

/// Wärme: was die Waermepumpe geleistet hat, und mit welcher Arbeitszahl.
///
/// **Die Arbeitszahl fuehrt.** Nicht die Kilowattstunden: wie viel Waerme ein Haus im Februar
/// braucht, sagt etwas ueber das Wetter; wie viel Strom sie gekostet hat, sagt etwas ueber die
/// Anlage. Nur die zweite Zahl laesst sich verbessern.
struct WaermeSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            try await api.energieWaerme(z.spanne.rawValue, anker: z.anker)
        } inhalt: { b in
            Kachelfeld(kacheln: kennzahlen(b), kicker: "Wärme")
            if let takten = taktenzahlen(b.cycling) {
                Karte(kicker: "Takten", titel: b.cycling.verdict) {
                    VStack(spacing: 0) {
                        ForEach(takten) { z in z }
                    }
                }
            }
            Karte(kicker: "Der Ofen") {
                ofen(b.stove)
            }
            Karte(kicker: "Bilanz des Puffers") {
                pufferbilanz(b.bufferBalance)
            }
            Methode([
                b.modelNoteDe,
                b.cycling.noteDe,
                b.bufferBalance.noteDe,
                b.priceQuality.noteDe,
                b.summary.meta.estimatedNoteDe,
            ])
        }
    }

    private func kennzahlen(_ b: HeatReportOut) -> [Kacheldaten] {
        let strom = b.summary.totals.heatPumpKwh ?? 0
        return [
            Kacheldaten(
                "Arbeitszahl", Formate.zahl(b.copEst, stellen: 2),
                dazu: "Wärme je Kilowattstunde Strom"
            ),
            Kacheldaten(
                "Wärme", Formate.zahl(b.thermalKwhEst, stellen: 1), einheit: "kWh",
                farbe: Farbe.waermepumpe
            ),
            Kacheldaten("Strom dafür", Formate.zahl(strom, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "Wärmeverlust des Hauses", Formate.zahl(b.heatLossKwPerK, stellen: 2),
                einheit: "kW/K", dazu: "je Kelvin Unterschied nach draußen"
            ),
            Kacheldaten(
                "Preisvorteil", Formate.zahl(b.priceQuality.advantageCt, stellen: 2), einheit: "ct/kWh",
                dazu: "gegenüber dem Durchschnitt des Hauses"
            ),
            Kacheldaten(
                "in den nächsten 24 h", Formate.zahl(b.forecastElectricKwh24h, stellen: 1),
                einheit: "kWh", dazu: "erwarteter Strombedarf"
            ),
        ]
    }

    /// Die Takt-Kennzahlen - aber nur, wenn ueberhaupt Laeufe erfasst sind.
    private func taktenzahlen(_ c: CyclingStats) -> [Zeile]? {
        guard let laeufe = c.runs, laeufe > 0 else { return nil }
        return [
            Zeile(wort: "Läufe", wert: Formate.zahl(laeufe, stellen: 0)),
            Zeile(wort: "Starts je Tag", wert: Formate.zahl(c.startsPerDay, stellen: 1)),
            Zeile(
                wort: "mittlere Laufzeit",
                wert: Formate.dauer(minuten: c.meanRunMin.map { Int($0.rounded()) })
            ),
            Zeile(
                wort: "kürzester Lauf",
                wert: Formate.dauer(minuten: c.shortestRunMin.map { Int($0.rounded()) })
            ),
            Zeile(
                wort: "mittlere Pause",
                wert: Formate.dauer(minuten: c.meanPauseMin.map { Int($0.rounded()) })
            ),
            Zeile(wort: "Laufanteil", wert: Formate.prozent(c.dutyCycle)),
            Zeile(
                wort: "kurze Läufe", wert: Formate.zahl(c.shortRuns, stellen: 0),
                dazu: c.shortShare.map { "\(Formate.prozent($0)) aller Läufe" }
            ),
        ]
    }

    private func ofen(_ o: StoveOut) -> some View {
        Group {
            if o.available == true {
                VStack(spacing: 0) {
                    Zeile(
                        wort: "Laufzeit",
                        wert: Formate.dauer(minuten: o.runningMinutes.map { Int($0.rounded()) })
                    )
                    Zeile(wort: "Läufe", wert: Formate.zahl(o.runs, stellen: 0))
                    Zeile(wort: "Zündungen", wert: Formate.zahl(o.ignitions, stellen: 0))
                    Zeile(wort: "Pellets", wert: Formate.zahl(o.pelletKg, stellen: 1), einheit: "kg")
                    Zeile(wort: "Pelletkosten", wert: Formate.euro(o.pelletEur))
                    Zeile(
                        wort: "Warmwasser",
                        wert: Formate.dauer(minuten: o.dhwMinutes.map { Int($0.rounded()) })
                    )
                }
            } else {
                Leer(satz: "In diesem Zeitraum hat der Ofen nicht gemeldet.")
            }
        }
    }

    /// Die Bilanz des Puffers: was hineinging, was herauskam, und was sich nicht erklaeren laesst.
    ///
    /// Die letzte Zeile ist die wichtigste. Ein Puffer, dessen Gewinn sich zu einem Drittel
    /// nicht erklaeren laesst, hat entweder einen Fuehler, der luegt, oder eine Waermequelle,
    /// die niemand kennt.
    private func pufferbilanz(_ b: BufferBalanceOut) -> some View {
        VStack(spacing: 0) {
            Zeile(wort: "am Anfang", wert: Formate.zahl(b.energyStartKwh, stellen: 1), einheit: "kWh")
            Zeile(wort: "am Ende", wert: Formate.zahl(b.energyEndKwh, stellen: 1), einheit: "kWh")
            Zeile(
                wort: "durch die Wärmepumpe", wert: Formate.zahl(b.gainWithHpKwh, stellen: 1),
                einheit: "kWh", farbe: Farbe.waermepumpe
            )
            if b.stoveKnown == true {
                Zeile(
                    wort: "durch den Ofen", wert: Formate.zahl(b.gainWithStoveKwh, stellen: 1),
                    einheit: "kWh", farbe: Farbe.ofen
                )
            }
            Zeile(wort: "entnommen", wert: Formate.zahl(b.dropKwh, stellen: 1), einheit: "kWh")
            Zeile(
                wort: "nicht erklärt", wert: Formate.zahl(b.gainUnexplainedKwh, stellen: 1),
                einheit: "kWh",
                farbe: (b.gainUnexplainedKwh ?? 0) > 1 ? Farbe.achtung : Farbe.text1,
                dazu: "Gewinn ohne bekannte Quelle"
            )
        }
    }
}

/// Die Wärmebilanz als eigene Seite: wohin die Waerme ging.
struct WaermebilanzSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            try await api.waermebilanz(z.spanne.rawValue, anker: z.anker)
        } inhalt: { b in
            Kachelfeld(kacheln: kennzahlen(b), kicker: "Wärmebilanz")
            if let eimer = b.buckets, !eimer.isEmpty {
                Karte(kicker: "Woher die Wärme kam") {
                    Balkenbild(stuecke: [
                        .init(
                            name: "Wärmepumpe", farbe: Farbe.waermepumpe,
                            werte: eimer.map { ($0.labelDe, $0.heatPumpKwh ?? 0) }
                        ),
                        .init(
                            name: "Ofen ins Wasser", farbe: Farbe.ofen,
                            werte: eimer.map { ($0.labelDe, $0.stoveWaterKwh ?? 0) }
                        ),
                        .init(
                            name: "Ofen in den Raum", farbe: Farbe.amberWeich,
                            werte: eimer.map { ($0.labelDe, $0.stoveRoomKwh ?? 0) }
                        ),
                    ])
                }
                Karte(kicker: "Wohin sie ging") {
                    Balkenbild(stuecke: [
                        .init(
                            name: "entnommen", farbe: Farbe.mist,
                            werte: eimer.map { ($0.labelDe, $0.drawKwh ?? 0) }
                        ),
                        .init(
                            name: "Verlust", farbe: Farbe.alarm,
                            werte: eimer.map { ($0.labelDe, $0.lossKwh ?? 0) }
                        ),
                    ])
                }
                Karte(kicker: "Die Zahlen") {
                    Tabelle(
                        zeilennamen: eimer.map(\.labelDe),
                        spalten: [
                            .init(
                                name: "Wärmepumpe",
                                zellen: eimer.map { Formate.zahl($0.heatPumpKwh ?? 0, stellen: 1) }
                            ),
                            .init(
                                name: "Strom",
                                zellen: eimer.map { Formate.zahl($0.electricKwh ?? 0, stellen: 1) }
                            ),
                            .init(
                                name: "Arbeitszahl",
                                zellen: eimer.map { Formate.zahl($0.copMean, stellen: 2) }
                            ),
                            .init(
                                name: "Verlust",
                                zellen: eimer.map { Formate.zahl($0.lossKwh ?? 0, stellen: 1) }
                            ),
                        ]
                    )
                }
            }
            Methode([b.noteDe, b.forecastNoteDe, b.params.roomSourceDe])
        }
    }

    private func kennzahlen(_ b: HeatBalanceOut) -> [Kacheldaten] {
        var aus: [Kacheldaten] = [
            Kacheldaten(
                "Wärme gesamt", Formate.zahl(summe(b) { $0.heatPumpKwh }, stellen: 1), einheit: "kWh",
                farbe: Farbe.waermepumpe
            ),
            Kacheldaten("entnommen", Formate.zahl(summe(b) { $0.drawKwh }, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "Verlust", Formate.zahl(summe(b) { $0.lossKwh }, stellen: 1), einheit: "kWh",
                dazu: "davon nutzbar: \(Formate.kwh(summe(b) { $0.lossUsefulKwh }))"
            ),
            Kacheldaten("Strom", Formate.zahl(summe(b) { $0.electricKwh }, stellen: 1), einheit: "kWh"),
        ]
        if let p = b.forecastHeatKwh {
            aus.append(
                Kacheldaten("erwartet, 24 h", Formate.zahl(p, stellen: 1), einheit: "kWh")
            )
        }
        aus.append(Kacheldaten("Auflösung", b.resolutionDe))
        return aus
    }

    private func summe(_ b: HeatBalanceOut, _ feld: (HeatBucketOut) -> Double?) -> Double {
        (b.buckets ?? []).reduce(0) { $0 + (feld($1) ?? 0) }
    }
}
