import Foundation

/// Ein Punkt im Minutenraster der Tageskurve.
///
/// Vorlage: `HistoryPoint` in `apps/web/src/lib/live/store.ts`. Die Felder sind dieselben, damit
/// Diagramm und Dashboard dieselbe Kurve zeichnen.
public struct Verlaufspunkt: Sendable, Hashable, Identifiable {
    /// Der Anfang der Minute, auf die dieser Punkt faellt.
    public var zeit: Date
    public var pv: Double?
    /// Der ganze Hausverbrauch, mit Waermepumpe und Wallbox: die weisse Linie der Tageskurve.
    public var haus: Double?
    public var waermepumpe: Double?
    public var wallbox: Double?
    public var netz: Double?
    public var batterie: Double?
    public var preis: Double?
    /// Der Freigabekontakt K1, als 0 oder 1. Im Diagramm ein Band, keine Kurve.
    public var k1: Double?

    public var id: Date { zeit }

    public init(
        zeit: Date, pv: Double? = nil, haus: Double? = nil, waermepumpe: Double? = nil,
        wallbox: Double? = nil, netz: Double? = nil, batterie: Double? = nil,
        preis: Double? = nil, k1: Double? = nil
    ) {
        self.zeit = zeit
        self.pv = pv
        self.haus = haus
        self.waermepumpe = waermepumpe
        self.wallbox = wallbox
        self.netz = netz
        self.batterie = batterie
        self.preis = preis
        self.k1 = k1
    }
}

/// Das Minutenraster: aus der Historie des Dienstes lesen und mit Live-Werten fortschreiben.
///
/// **Warum die Anzeige ueberhaupt selbst fortschreibt.** Die Historie kommt einmal beim Verbinden
/// und danach nicht mehr - es gibt keine Abfrageschleife, nur den Ereignisstrom. Die Kurve bis
/// zur Jetzt-Linie entsteht also im Geraet, aus denselben Augenblicksbildern, die auch die
/// Kacheln speisen. Das Mittel je Minute ist der Grund, warum sie trotzdem so aussieht wie die,
/// die der Dienst beim naechsten Verbinden liefert.
public struct Minutenraster: Sendable {
    public private(set) var punkte: [Verlaufspunkt] = []
    /// Der Kalendertag, den dieses Raster zeigt. Leer, solange nichts geladen ist.
    public private(set) var tag: String = ""
    /// Wie viele Augenblicksbilder in die jeweils letzte Minute eingegangen sind - der Nenner
    /// des laufenden Mittels.
    private var anzahl: [Date: Int] = [:]

    /// Mehr als das behaelt die Anzeige nicht. 1500 Minuten sind gut 25 Stunden, also ein Tag
    /// samt Ueberhang; alles Aeltere waere ohnehin nicht zu sehen.
    public static let hoechstzahl = 1500

    public init() {}

    /// Die Historie des Dienstes uebernehmen. Das verwirft, was vorher da war.
    public mutating func setze(_ zeilen: [[String: Mischwert]], tag: String) {
        punkte = zeilen.compactMap(Self.punktAusZeile)
        self.tag = tag
        anzahl = [:]
    }

    /// Dasselbe aus der Antwort des Dienstes.
    public mutating func setze(_ historie: HistoryOut, tag: String) {
        setze(historie.rows, tag: tag)
    }

    /// Eine Zeile der Historie in einen Punkt uebersetzen.
    ///
    /// Eine Zeile ohne lesbaren Zeitstempel wird verworfen und nicht auf den 1. Januar 1970
    /// gelegt - dort zoege sie die Zeitachse des ganzen Diagramms zu sich.
    public static func punktAusZeile(_ zeile: [String: Mischwert]) -> Verlaufspunkt? {
        guard let roh = zeile["ts"]?.alsText, let zeit = Zeit.ausIso(roh) else { return nil }
        return Verlaufspunkt(
            zeit: zeit,
            pv: zeile["pv_power_kw"]?.alsZahl,
            haus: zeile["house_power_kw"]?.alsZahl,
            waermepumpe: zeile["heat_pump_power_kw"]?.alsZahl,
            wallbox: zeile["ev_power_kw"]?.alsZahl,
            netz: zeile["grid_power_kw"]?.alsZahl,
            batterie: zeile["battery_power_kw"]?.alsZahl,
            preis: zeile["electricity_price_ct_kwh"]?.alsZahl,
            k1: zeile["hp_release_contact"]?.alsZahl
        )
    }

    /// Den Anfang der Minute, auf die ein Zeitpunkt faellt.
    public static func minutenanfang(_ d: Date) -> Date {
        let s = d.timeIntervalSince1970
        return Date(timeIntervalSince1970: (s / 60).rounded(.down) * 60)
    }

    /// Einen Live-Zustand in das Raster fortschreiben.
    ///
    /// Leistungen werden ueber die Minute gemittelt, Preis und Kontaktstellung nicht: der Preis
    /// gilt fuer die ganze Stunde, und ein Kontakt ist an oder aus. Ein halb offener Kontakt
    /// waere eine Aussage, die es nicht gibt.
    public mutating func schreibeFort(_ zustand: LiveStateOut) {
        guard let jetzt = Zeit.ausIso(zustand.snapshot.timestamp) else { return }
        let minute = Self.minutenanfang(jetzt)
        let s = zustand.snapshot
        let frisch = Verlaufspunkt(
            zeit: minute,
            pv: s.pvPowerKw.value,
            haus: s.housePowerKw.value,
            waermepumpe: s.heatPumpPowerKw.value,
            wallbox: s.evPowerKw.value,
            netz: s.gridPowerKw.value,
            batterie: s.batteryPowerKw.value,
            preis: s.electricityPriceCtKwh.value,
            k1: s.hpReleaseContact.value
        )

        if let letzter = punkte.last, letzter.zeit == minute {
            let n = anzahl[minute] ?? 1
            func mittel(_ a: Double?, _ b: Double?) -> Double? {
                guard let a else { return b }
                guard let b else { return a }
                return (a * Double(n) + b) / Double(n + 1)
            }
            anzahl[minute] = n + 1
            punkte[punkte.count - 1] = Verlaufspunkt(
                zeit: minute,
                pv: mittel(letzter.pv, frisch.pv),
                haus: mittel(letzter.haus, frisch.haus),
                waermepumpe: mittel(letzter.waermepumpe, frisch.waermepumpe),
                wallbox: mittel(letzter.wallbox, frisch.wallbox),
                netz: mittel(letzter.netz, frisch.netz),
                batterie: mittel(letzter.batterie, frisch.batterie),
                preis: frisch.preis,
                k1: frisch.k1
            )
            return
        }
        // Ein verspaeteter Rahmen gehoert nicht an das Ende der Reihe. Er wird verworfen und
        // nicht einsortiert: die Reihe muss aufsteigend bleiben, sonst laeuft die Kurve zurueck.
        if let letzter = punkte.last, minute < letzter.zeit { return }

        anzahl[minute] = 1
        punkte.append(frisch)
        if punkte.count > Self.hoechstzahl {
            let weg = punkte.count - Self.hoechstzahl
            for p in punkte.prefix(weg) { anzahl[p.zeit] = nil }
            punkte.removeFirst(weg)
        }
    }

    /// Nur die Punkte, die in einen Zeitraum fallen.
    public func punkte(von: Date, bis: Date) -> [Verlaufspunkt] {
        punkte.filter { $0.zeit >= von && $0.zeit < bis }
    }

    /// Der groesste Betrag einer Leistung im Raster - fuer die Skalierung der Achse.
    public var hoechsteLeistung: Double {
        var m = 0.0
        for p in punkte {
            for w in [p.pv, p.haus, p.waermepumpe, p.wallbox, p.netz, p.batterie] {
                if let w, w.isFinite { m = max(m, abs(w)) }
            }
        }
        return m
    }

    /// Spanne der Preise im Raster, oder `nil`, wenn keiner da ist.
    public var preisspanne: (tiefster: Double, hoechster: Double)? {
        let preise = punkte.compactMap(\.preis).filter(\.isFinite)
        guard let tief = preise.min(), let hoch = preise.max() else { return nil }
        return (tief, hoch)
    }
}
