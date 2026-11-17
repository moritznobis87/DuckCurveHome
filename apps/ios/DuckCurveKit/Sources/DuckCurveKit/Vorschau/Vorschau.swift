import Foundation

/// Beispieldaten: ein Haus, das es nicht gibt, aber plausibel aussieht.
///
/// **Wofuer das gut ist, zweimal.** SwiftUI-Vorschauen brauchen Werte, sonst sind sie leere
/// Rechtecke, und 29 Seiten ohne Vorschau sind 29 Seiten, die nur am Geraet zu beurteilen sind.
/// Die Tests dieses Pakets brauchen dieselben Werte. Beides aus einer Quelle zu nehmen hat einen
/// zweiten Vorteil: diese Datei wird hier unter Linux mitkompiliert, also ist sichergestellt,
/// dass die Vorschauen ueberhaupt bauen - und zwar bevor Xcode sie zu zeichnen versucht.
///
/// **Die Zahlen sind nicht beliebig.** Es ist ein Nachmittag Ende Februar: 4,2 kW aus der
/// Photovoltaik, die Waermepumpe laeuft auf Ueberschuss, der Puffer ist dreiviertel voll, der
/// Preis liegt bei 18,4 ct. Das ist der Zustand, in dem dieses Haus die meiste Zeit interessant
/// ist - nicht der Sonnenhoechststand im Juni, bei dem jede Kachel gruen leuchtet und keine
/// Gestaltungsfrage mehr auffaellt.
public enum Vorschau {
    /// Der Zeitpunkt, auf den sich alle Beispieldaten beziehen. Fest, nicht `Date()`: eine
    /// Vorschau, die sich mit der Uhr aendert, ist nicht zu vergleichen, und ein Test, der von
    /// der Tageszeit abhaengt, faellt irgendwann nachts um.
    public static let jetzt = Zeit.ausIso("2026-02-24T14:35:00+01:00")!

    public static var jetztIso: String { Zeit.iso(jetzt) }

    // MARK: - Bausteine

    /// Ein Messwert mit Zeitstempel und Guete.
    public static func messwert(
        _ wert: Double?, guete: Quality = .ok, quelle: String = "vorschau", am: Date = jetzt
    ) -> Messwert {
        Messwert(value: wert, observedAt: Zeit.iso(am), quality: wert == nil ? .unavailable : guete, source: quelle)
    }

    /// Ein Messwert, der fehlt. Fuer die Pruefung, dass eine Kachel das aushaelt.
    public static var fehlt: Messwert {
        Messwert(value: nil, observedAt: Zeit.iso(jetzt), quality: .unavailable, source: "vorschau")
    }

    public static func puffertemperaturen(
        oben: Double = 52.4, mittigOben: Double = 47.1, mittigUnten: Double = 38.6, unten: Double = 31.2
    ) -> BufferTemperatures {
        BufferTemperatures(
            top: messwert(oben), midTop: messwert(mittigOben),
            midBottom: messwert(mittigUnten), bottom: messwert(unten)
        )
    }

    /// Ein Augenblicksbild der Energieseite.
    public static func augenblick(
        pv: Double? = 4.2,
        netz: Double? = -1.1,
        batterie: Double? = -0.6,
        haus: Double? = 2.5,
        grundlast: Double? = 0.4,
        waermepumpe: Double? = 2.1,
        wallbox: Double? = 0.0,
        preis: Double? = 18.4,
        aussen: Double? = 6.3,
        k1: Bool = true,
        k2: Bool = false,
        am: Date = jetzt
    ) -> EnergySnapshot {
        EnergySnapshot(
            timestamp: Zeit.iso(am),
            pvPowerKw: messwert(pv, am: am),
            gridPowerKw: messwert(netz, am: am),
            batteryPowerKw: messwert(batterie, am: am),
            batterySoc: messwert(0.74, am: am),
            housePowerKw: messwert(haus, am: am),
            baseLoadKw: messwert(grundlast, am: am),
            heatPumpPowerKw: messwert(waermepumpe, am: am),
            evPowerKw: messwert(wallbox, am: am),
            electricityPriceCtKwh: messwert(preis, am: am),
            outdoorTempC: messwert(aussen, am: am),
            bufferTempsC: puffertemperaturen(),
            hpReleaseContact: messwert(k1 ? 1 : 0, am: am),
            hpBlockContact: messwert(k2 ? 1 : 0, am: am),
            actuators: [:],
            balanceResidualKw: 0.0
        )
    }

    public static func puffer(soc: Double = 0.74, status: BufferStatus = .warm) -> BufferState {
        BufferState(
            soc: soc,
            usableEnergyKwh: 18.6 * soc,
            capacityKwh: 18.6,
            volumeLiters: 800,
            meanTempC: 42.3,
            status: status,
            method: "layered_energy_v1",
            headroomSoc: max(0, 0.95 - soc)
        )
    }

    public static func waermepumpeZustand(laeuft: Bool = true) -> HeatPumpState {
        HeatPumpState(
            running: laeuft,
            runningSince: laeuft ? Zeit.iso(jetzt.addingTimeInterval(-42 * 60)) : nil,
            stoppedSince: laeuft ? nil : Zeit.iso(jetzt.addingTimeInterval(-18 * 60)),
            powerKw: laeuft ? 2.1 : 0.0,
            releaseContactOn: laeuft,
            blockContactOn: false,
            startsToday: 3,
            powerKnown: true
        )
    }

    public static func systemzustand(modus: String = "demo") -> SystemStatusOut {
        SystemStatusOut(
            mode: modus,
            serverTime: jetztIso,
            simSpeed: 1,
            bridgeOnline: true,
            sseClients: 2,
            version: "vorschau",
            connectionLabelDe: "Verbunden",
            sources: [],
            watch: [],
            outdoorShownC: 6.3,
            outdoorSourceDe: "Wetterdienst",
            hpActuation: false,
            hpActuationDe: "Der Regler entscheidet, schaltet aber nicht."
        )
    }

    /// Der vollstaendige Live-Zustand, wie der Ereignisstrom ihn schickt.
    public static func liveZustand(
        pv: Double? = 4.2,
        waermepumpe: Double? = 2.1,
        laeuft: Bool = true,
        soc: Double = 0.74,
        preis: Double? = 18.4,
        am: Date = jetzt
    ) -> LiveStateOut {
        LiveStateOut(
            snapshot: augenblick(pv: pv, waermepumpe: waermepumpe, preis: preis, k1: laeuft, am: am),
            buffer: puffer(soc: soc),
            heatPump: waermepumpeZustand(laeuft: laeuft),
            decision: nil,
            operatingMode: OperatingMode(systemMode: .auto, autoProfile: .smart, override: nil),
            stove: nil,
            priceRank: 0.31,
            todayKwh: ["pv": 14.2, "grid_in": 3.1, "grid_out": 6.8, "heat_pump": 7.4, "house": 11.5],
            alarm: nil,
            system: systemzustand()
        )
    }

    // MARK: - Verlauf

    /// Ein Tag im Minutenraster, wie der Dienst ihn liefert.
    ///
    /// Die Photovoltaik folgt einer Glocke um die Mittagszeit, die Waermepumpe laeuft in zwei
    /// Bloecken, und der Preis hat das Tal, das die ganze Anwendung begruendet: mittags billig,
    /// abends teuer. Genug Struktur, um an einem Diagramm zu sehen, ob es richtig zeichnet.
    public static func verlaufszeilen(tag: String = "2026-02-24", schrittMin: Int = 1) -> [[String: Mischwert]] {
        guard let z = Tag.zeitraum(tag) else { return [] }
        var zeilen: [[String: Mischwert]] = []
        var t = z.von
        while t < z.bis {
            let stunde = Double(Kalender.haus.component(.hour, from: t))
                + Double(Kalender.haus.component(.minute, from: t)) / 60
            // Glocke um 12:30, Ende Februar bis gut 5 kW.
            let sonne = max(0, 5.1 * exp(-pow((stunde - 12.5) / 3.1, 2)))
            // Zwei Laeufe: einer am Morgen, einer in der Mittagssonne.
            let laeuft = (stunde >= 5.5 && stunde < 7.2) || (stunde >= 11.0 && stunde < 13.8)
            let wp = laeuft ? 2.1 : 0.0
            let grundlast = 0.35 + 0.25 * sin(stunde / 24 * 2 * .pi)
            let haus = grundlast + wp
            let netz = haus - sonne
            // Preistal zur Mittagszeit, Spitze am Abend.
            let preis = 24.0 - 9.0 * exp(-pow((stunde - 13.0) / 2.6, 2)) + 11.0 * exp(-pow((stunde - 19.0) / 1.9, 2))
            zeilen.append([
                "ts": .text(Zeit.iso(t)),
                "pv_power_kw": .zahl((sonne * 100).rounded() / 100),
                "house_power_kw": .zahl((haus * 100).rounded() / 100),
                "heat_pump_power_kw": .zahl(wp),
                "ev_power_kw": .zahl(0),
                "grid_power_kw": .zahl((netz * 100).rounded() / 100),
                "battery_power_kw": .zahl(0),
                "electricity_price_ct_kwh": .zahl((preis * 10).rounded() / 10),
                "hp_release_contact": .ganz(laeuft ? 1 : 0),
            ])
            t = t.addingTimeInterval(Double(schrittMin) * 60)
        }
        return zeilen
    }

    /// Dasselbe als gefuelltes Minutenraster.
    public static func minutenraster(tag: String = "2026-02-24") -> Minutenraster {
        var r = Minutenraster()
        r.setze(verlaufszeilen(tag: tag), tag: tag)
        return r
    }

    /// Ein Zugang, der auf nichts zeigt - fuer Vorschauen, die nichts laden sollen.
    public static var zugang: Zugang {
        Zugang(
            grund: URL(string: "https://beispiel.invalid")!,
            token: "vorschau",
            geraetename: "iPad Flur"
        )
    }
}

// MARK: - Plan und Prognose

extension Vorschau {
    /// Ein Preisfenster.
    public static func fenster(
        _ von: String, _ bis: String, _ art: PriceWindowOutKindWahl, mittel: Double = 12.0
    ) -> PriceWindowOut {
        PriceWindowOut(
            start: von, end: bis, kind: art, avgCtKwh: mittel,
            labelDe: art == .negative ? "Preis negativ" : art == .cheap ? "Preistief" : "teuer"
        )
    }

    /// Ein Plan ueber einige Stunden, im Viertelstundenraster.
    ///
    /// Die Erwartung folgt derselben Glocke wie die Messung in `verlaufszeilen`, damit Prognose
    /// und Messung in einem Diagramm plausibel nebeneinanderliegen - eine Prognose, die weit
    /// neben der Messung steht, sieht in einer Vorschau wie ein Fehler aus.
    public static func plan(
        ab: Date = Kalender.haus.startOfDay(for: jetzt),
        stunden: Int = 24,
        fenster: [PriceWindowOut] = []
    ) -> PlanOut {
        let felder = (0..<(stunden * 4)).map { i -> PlanIntervalOut in
            let t = ab.addingTimeInterval(Double(i) * 900)
            let h = Double(Kalender.haus.component(.hour, from: t))
                + Double(Kalender.haus.component(.minute, from: t)) / 60
            let sonne = max(0, 5.1 * exp(-pow((h - 12.5) / 3.1, 2)))
            let preis = 24.0 - 9.0 * exp(-pow((h - 13.0) / 2.6, 2)) + 11.0 * exp(-pow((h - 19.0) / 1.9, 2))
            let laeuft = h >= 11.0 && h < 13.8
            return PlanIntervalOut(
                ts: Zeit.iso(t),
                expectedPvKw: (sonne * 100).rounded() / 100,
                priceCtKwh: (preis * 10).rounded() / 10,
                plannedHpState: laeuft ? .release : .free,
                plannedStoveOn: false,
                reasonCode: laeuft ? "pv_surplus" : "none",
                noteDe: laeuft ? "Überschuss erwartet." : nil,
                heatDemandKw: 4.2,
                dhwDemandKw: 0.0,
                bufferKwh: 13.8,
                outdoorTempC: 6.3,
                cop: 3.4
            )
        }
        return PlanOut(
            createdAt: Zeit.iso(jetzt),
            planner: "vorschau",
            plannerStatus: "ok",
            plannerNoteDe: "Ein Plan für die Vorschau.",
            hpActuation: false,
            horizonStart: Zeit.iso(ab),
            horizonEnd: Zeit.iso(ab.addingTimeInterval(Double(stunden) * 3600)),
            windows: fenster,
            intervals: felder,
            pvForecastTodayKwh: 16.4,
            nextCheapWindow: fenster.first { $0.kind == .cheap },
            bufferCapacityKwh: 18.6,
            bufferMinKwh: 4.0
        )
    }

    /// Die Waermelastprognose: was die Waermepumpe nach dem Wetter brauchen wird.
    public static func waermeprognose(ab: Date, stunden: Int = 24) -> [HeatForecastPoint] {
        (0..<stunden).map { h in
            let t = ab.addingTimeInterval(Double(h) * 3600)
            let aussen = 6.3 - 4.0 * cos(Double(h) / 24 * 2 * .pi)
            let heizen = max(0, (20.0 - aussen) * 0.42)
            let cop = 4.6 - (20.0 - aussen) * 0.07
            return HeatForecastPoint(
                ts: Zeit.iso(t),
                outdoorC: (aussen * 10).rounded() / 10,
                heatingKw: (heizen * 100).rounded() / 100,
                dhwKw: h == 6 ? 1.4 : 0.0,
                cop: (cop * 100).rounded() / 100,
                electricKw: ((heizen / max(1, cop)) * 100).rounded() / 100
            )
        }
    }

    /// Eine Wärmepumpe mit Beispielwerten – für die Zeichnung und ihre Tests.
    public static func waermepumpe(
        laeuft: Bool = true,
        pumpe: Bool? = true,
        luefter: Double? = 420,
        einspeisung: WaermepumpeOutEinspeisungWahl? = .oben,
        zaehler: Double? = 1.84,
        bus: Double? = 1.92,
        waerme: Double? = 6.3
    ) -> WaermepumpeOut {
        func m(_ v: Double?, _ g: Quality = .ok) -> Messwert {
            Messwert(value: v, observedAt: Zeit.iso(jetzt), quality: v == nil ? .unavailable : g,
                     source: "demo:ebus")
        }
        return WaermepumpeOut(
            now: Zeit.iso(jetzt), laeuft: laeuft,
            zustandDe: laeuft ? "heizt" : "steht",
            pumpeLaeuft: pumpe,
            aussenC: m(4.2), verdampferC: m(1.1), sauggasC: m(3.4),
            heissgasC: m(68.0), fluessigC: m(31.5), verdichterHz: m(laeuft ? 54 : 0),
            leistungBusKw: m(bus), leistungZaehlerKw: m(zaehler),
            vorlaufC: m(38.4), ruecklaufC: m(33.1), durchflussLMin: m(17.2),
            vorlaufSollC: m(39.0), speicherfuehlerC: m(44.8),
            pufferC: puffertemperaturen().vonObenNachUnten,
            waermeleistungKw: waerme,
            luefterDrehzahl: luefter.map { m($0) },
            kreisDe: "Heizkreis 1", einspeisung: einspeisung
        )
    }
}
