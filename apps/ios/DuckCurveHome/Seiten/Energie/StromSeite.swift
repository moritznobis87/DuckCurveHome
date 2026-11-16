import DuckCurveKit
import SwiftUI

/// Strom: was verbraucht und erzeugt wurde, über den gewählten Zeitraum.
///
/// Die fuehrende Zahl ist die Autarkie - nicht die Erzeugung. Erzeugt wird viel oder wenig, je
/// nach Jahreszeit; was das Haus daraus macht, ist die Frage, die diese Anlage stellt.
struct StromSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
        } inhalt: { bericht in
            Kachelfeld(kacheln: kennzahlen(bericht), kicker: "Strom")
            Karte(kicker: "Woher der Strom kam") {
                Balkenbild(stuecke: herkunft(bericht))
            }
            Karte(kicker: "Wohin er ging") {
                Balkenbild(stuecke: verbrauch(bericht))
            }
            Karte(kicker: "Die Zahlen") {
                tabelle(bericht)
            }
            Methode([
                bericht.meta.estimatedNoteDe,
                bericht.meta.dataSince.map { "Daten seit \(Formate.hhmm(iso: $0) == Formate.leer ? $0 : $0)." },
            ])
        }
    }

    private func kennzahlen(_ b: EnergySummaryOut) -> [Kacheldaten] {
        let t = b.totals
        return [
            Kacheldaten(
                "Autarkie", Formate.prozent(t.autarky), dazu: "Anteil des Verbrauchs ohne Netz"
            ),
            Kacheldaten("aus der Sonne", Formate.zahl(t.pvKwh ?? 0, stellen: 1), einheit: "kWh", farbe: Farbe.pv),
            Kacheldaten("aus dem Netz", Formate.zahl(t.importKwh ?? 0, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "eingespeist", Formate.zahl(t.exportKwh ?? 0, stellen: 1), einheit: "kWh",
                farbe: Farbe.netzEinspeisung
            ),
            Kacheldaten("im Haus", Formate.zahl(t.houseKwh ?? 0, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "Eigenverbrauch", Formate.prozent(t.selfConsumptionShare),
                dazu: "Anteil der Erzeugung, der im Haus blieb"
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
                name: "aus dem Speicher", farbe: Farbe.batterie,
                werte: b.buckets.map { ($0.label, $0.totals.batteryToHouseKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "aus dem Netz", farbe: Farbe.netzBezug,
                werte: b.buckets.map { ($0.label, $0.totals.gridToHouseKwh ?? 0) }
            ),
        ]
    }

    private func verbrauch(_ b: EnergySummaryOut) -> [Balkenbild.Stueck] {
        [
            Balkenbild.Stueck(
                name: "Grundlast", farbe: Farbe.last,
                werte: b.buckets.map { ($0.label, $0.totals.baseKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "Wärmepumpe", farbe: Farbe.waermepumpe,
                werte: b.buckets.map { ($0.label, $0.totals.heatPumpKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "Wallbox", farbe: Farbe.wallbox,
                werte: b.buckets.map { ($0.label, $0.totals.evKwh ?? 0) }
            ),
        ]
    }

    private func tabelle(_ b: EnergySummaryOut) -> some View {
        Tabelle(
            zeilennamen: b.buckets.map(\.label),
            spalten: [
                .init(name: "Sonne", zellen: b.buckets.map { Formate.zahl($0.totals.pvKwh ?? 0, stellen: 1) }),
                .init(name: "Haus", zellen: b.buckets.map { Formate.zahl($0.totals.houseKwh ?? 0, stellen: 1) }),
                .init(name: "Bezug", zellen: b.buckets.map { Formate.zahl($0.totals.importKwh ?? 0, stellen: 1) }),
                .init(
                    name: "Einspeisung",
                    zellen: b.buckets.map { Formate.zahl($0.totals.exportKwh ?? 0, stellen: 1) }
                ),
            ]
        )
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

/// Wallbox: die Ladevorgaenge des Zeitraums.
struct WallboxSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            try await api.energieWallbox(z.spanne.rawValue, anker: z.anker)
        } inhalt: { b in
            Kachelfeld(kacheln: kennzahlen(b), kicker: "Wallbox")
            Karte(kicker: "Ladevorgänge") {
                if b.sessions.isEmpty {
                    Leer(satz: "In diesem Zeitraum wurde nicht geladen.")
                } else {
                    Tabelle(
                        zeilennamen: b.sessions.map {
                            Formate.hhmm(iso: $0.start) + " – " + Formate.hhmm(iso: $0.end)
                        },
                        spalten: [
                            .init(name: "kWh", zellen: b.sessions.map { Formate.zahl($0.kwh, stellen: 1) }),
                            .init(
                                name: "Sonnenanteil",
                                zellen: b.sessions.map { Formate.prozent($0.pvShare) }
                            ),
                            .init(
                                name: "Netz",
                                zellen: b.sessions.map { Formate.zahl($0.gridKwh, stellen: 1) }
                            ),
                            .init(name: "Kosten", zellen: b.sessions.map { Formate.euro($0.costEur) }),
                            .init(
                                name: "mittlere Leistung",
                                zellen: b.sessions.map { Formate.zahl($0.avgKw, stellen: 1) }
                            ),
                        ]
                    )
                }
            }
            Methode([b.summary.meta.estimatedNoteDe])
        }
    }

    private func kennzahlen(_ b: EvReportOut) -> [Kacheldaten] {
        let t = b.summary.totals
        return [
            Kacheldaten("geladen", Formate.zahl(t.evKwh ?? 0, stellen: 1), einheit: "kWh", farbe: Farbe.wallbox),
            Kacheldaten("Ladevorgänge", String(b.sessions.count)),
            Kacheldaten(
                "aus der Sonne", Formate.zahl(t.evPvKwh ?? 0, stellen: 1), einheit: "kWh", farbe: Farbe.pv
            ),
            Kacheldaten("aus dem Netz", Formate.zahl(t.evGridKwh ?? 0, stellen: 1), einheit: "kWh"),
            Kacheldaten("Kosten", Formate.euro(t.evCostEur)),
            Kacheldaten(
                "entgangene Einspeisung", Formate.euro(t.evOpportunityEur),
                dazu: "was die Sonnenkilowattstunden im Netz gebracht hätten"
            ),
        ]
    }
}
