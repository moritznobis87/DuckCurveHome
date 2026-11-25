import Foundation

/// Der Energiefluss eines Augenblicks, so wie Bühne und Uhr der Startseite ihn zeichnen.
///
/// Dieselbe Rechnung und dieselben Wörter wie `fluss.ts` im Dashboard. Ein Messwert, der nicht
/// trägt, fließt nicht: er steht mit 0 da und ist in der Anzeige grau.
public struct Startfluss: Sendable, Equatable {

    public enum Speicherwort: String, Sendable, Hashable {
        case laedt = "lädt"
        case entlaedt = "entlädt"
        case haelt = "hält"
    }

    public let pv: Double
    public let haus: Double
    /// Was über den Netzanschluss geht, ohne Vorzeichen; `einspeisung` sagt die Richtung.
    public let netz: Double
    public let einspeisung: Bool
    /// Was in den Speicher geht oder aus ihm kommt, ohne Vorzeichen.
    public let speicher: Double
    public let speicherWort: Speicherwort
    /// Ladestand von 0 bis 1.
    public let soc: Double?
    public let hp: Double
    public let ev: Double
    /// Die Grundlast; `nil`, wenn sie nicht gemessen ist.
    public let rest: Double?

    /// Aus den belastbaren Messwerten. Netz: Bezug ist positiv. Speicher: Abgabe ist positiv.
    public static func aus(
        pv: Double?, netz: Double?, batterie: Double?, haus: Double?, hp: Double?, ev: Double?,
        rest: Double?, soc: Double?
    ) -> Startfluss {
        let grid = netz ?? 0
        let bat = batterie ?? 0
        let lade = max(0, -bat)
        let gibt = max(0, bat)
        let ab = Startbuehne.flussAbKw
        return Startfluss(
            pv: pv ?? 0,
            haus: haus ?? 0,
            netz: abs(grid),
            einspeisung: grid < 0,
            speicher: max(lade, gibt),
            speicherWort: lade >= ab ? .laedt : (gibt >= ab ? .entlaedt : .haelt),
            soc: soc.map { $0 > 1 ? $0 / 100 : $0 },
            hp: hp ?? 0,
            ev: ev ?? 0,
            rest: rest
        )
    }

    public static func aus(_ s: EnergySnapshot?) -> Startfluss {
        aus(
            pv: s?.pvPowerKw.belastbar, netz: s?.gridPowerKw.belastbar,
            batterie: s?.batteryPowerKw.belastbar, haus: s?.housePowerKw.belastbar,
            hp: s?.heatPumpPowerKw.belastbar, ev: s?.evPowerKw.belastbar,
            rest: s?.baseLoadKw.belastbar, soc: s?.batterySoc.belastbar
        )
    }

    // MARK: - Die Wörter

    /// Was unter der Zahl des Hauses steht: die Grundlast, wenn Wärmepumpe oder Wallbox etwas
    /// nehmen, sonst der schlichte Satz. Steht alles still, ist die Grundlast der Hausverbrauch,
    /// und die Zeile würde dieselbe Zahl ein zweites Mal sagen.
    public var hausZeile: String {
        guard let rest, hp + ev >= Startbuehne.flussAbKw else { return "braucht das Haus" }
        return "davon \(Formate.kw(rest)) kW Grundlast"
    }

    public var netzName: String { einspeisung ? "Einspeisung" : "Netzbezug" }
    public var speicherName: String { "Speicher \(speicherWort.rawValue)" }
    public var wallboxLaedt: Bool { ev >= Startbuehne.flussAbKw }
    public var wallboxName: String { wallboxLaedt ? "Wallbox lädt" : "Wallbox steht" }

    public func pumpenName(laeuft: Bool?) -> String {
        "Wärmepumpe " + Wpbild.wort(kw: hp, laeuft: laeuft)
    }

    /// Der Ladestand als ganze Zahl in Prozent, oder der Strich für „kein Wert“.
    public var socText: String {
        soc.map { String(Int(($0 * 100).rounded())) } ?? Formate.leer
    }

    /// Das Band des Speichers: ohne Leistung, solange er hält.
    public var speicherBand: Double { speicherWort == .haelt ? 0 : speicher }
}
