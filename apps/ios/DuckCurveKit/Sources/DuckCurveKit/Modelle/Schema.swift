// Erzeugt von tools/gen-swift.py aus docs/openapi.json. Nicht von Hand aendern.
//
// Dieselbe Quelle, aus der apps/web/src/lib/api/types.ts entsteht. Neu erzeugen mit
// `tools/gen-swift.py`, pruefen mit `tools/gen-swift.py --pruefen`.

import Foundation

// MARK: - Aufzaehlungen

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum AlarmArmInModeWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case home = "home"
    case away = "away"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = AlarmArmInModeWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum AlfredRechnungOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case tibber = "tibber"
    case andere = "andere"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = AlfredRechnungOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum AlfredVorschlagOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case schalten = "schalten"
    case sollwert = "sollwert"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = AlfredVorschlagOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum AlfredWechselInWerWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case alfred = "alfred"
    case nutzer = "nutzer"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = AlfredWechselInWerWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ApiSelbstOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ApiSelbstOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum AusweisOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case person = "person"
    case geraet = "geraet"
    case gast = "gast"
    case dienst = "dienst"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = AusweisOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum AusweisOutRolleWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case hausherr = "hausherr"
    case bewohner = "bewohner"
    case gast = "gast"
    case service = "service"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = AusweisOutRolleWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum AutoProfile: String, Codable, Sendable, Hashable, CaseIterable {
    case eco = "eco"
    case pv = "pv"
    case price = "price"
    case smart = "smart"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = AutoProfile(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum BatteryLiveOutCommandWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case normal = "normal"
    case stopped = "stopped"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = BatteryLiveOutCommandWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum BatteryLiveOutModeWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case auto = "auto"
    case normal = "normal"
    case hold = "hold"
    case off = "off"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = BatteryLiveOutModeWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum BatteryModeInModeWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case auto = "auto"
    case normal = "normal"
    case hold = "hold"
    case off = "off"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = BatteryModeInModeWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum BlockAnsichtBehandlungWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case aufgeschaltet = "aufgeschaltet"
    case ausgeregelt = "ausgeregelt"
    case beobachtet = "beobachtet"
    case geplant = "geplant"
    case erkannt = "erkannt"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = BlockAnsichtBehandlungWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum BlockAnsichtRolleWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case regler = "regler"
    case stellglied = "stellglied"
    case strecke = "strecke"
    case beobachter = "beobachter"
    case rechenglied = "rechenglied"
    case modell = "modell"
    case logik = "logik"
    case vorsteuerung = "vorsteuerung"
    case messglied = "messglied"
    case stoergroesse = "stoergroesse"
    case summierstelle = "summierstelle"
    case teilkreise = "teilkreise"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = BlockAnsichtRolleWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum BufferConfigSocMethodWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case layeredEnergyV1 = "layered_energy_v1"
    case weightedMeanV1 = "weighted_mean_v1"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = BufferConfigSocMethodWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum BufferStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case cold = "cold"
    case partial = "partial"
    case warm = "warm"
    case full = "full"
    case unknown = "unknown"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = BufferStatus(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ContactSideWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case n = "n"
    case s = "s"
    case o = "o"
    case w = "w"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ContactSideWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ControllerState: String, Codable, Sendable, Hashable, CaseIterable {
    case off = "off"
    case idle = "idle"
    case arming = "arming"
    case released = "released"
    case runningReleased = "running_released"
    case cooldown = "cooldown"
    case manual = "manual"
    case failsafe = "failsafe"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ControllerState(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum CyclingStatsVerdictWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case ok = "ok"
    case watch = "watch"
    case shortCycling = "short_cycling"
    case unknown = "unknown"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = CyclingStatsVerdictWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum DemoControlInFaultQualityWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case stale = "stale"
    case unavailable = "unavailable"
    case unknown = "unknown"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = DemoControlInFaultQualityWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum DemoControlInScenarioWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case reset = "reset"
    case sunnySurplus = "sunny_surplus"
    case coldEvening = "cold_evening"
    case bufferFull = "buffer_full"
    case sensorOutage = "sensor_outage"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = DemoControlInScenarioWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum EinladungPersonOutRolleWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case hausherr = "hausherr"
    case bewohner = "bewohner"
    case gast = "gast"
    case service = "service"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = EinladungPersonOutRolleWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum EnergySummaryOutPeriodWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = EnergySummaryOutPeriodWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetAktionInAktionWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case neustart = "neustart"
    case sichern = "sichern"
    case protokoll = "protokoll"
    case geraetNeustart = "geraet_neustart"
    case zustand = "zustand"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetAktionInAktionWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetDienstOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetDienstOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetEinheitOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetEinheitOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetPlatteOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetPlatteOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetRechnerOutDrosselungAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetRechnerOutDrosselungAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetRechnerOutSpannungAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetRechnerOutSpannungAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetRechnerOutSpeicherAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetRechnerOutSpeicherAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetRechnerOutTemperaturAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetRechnerOutTemperaturAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetRechnerOutZeitAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetRechnerOutZeitAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetSicherungOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetSicherungOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetSsdOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetSsdOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GeraetVerlaufOutSpanneWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case tag = "tag"
    case woche = "woche"
    case monat = "monat"
    case jahr = "jahr"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GeraetVerlaufOutSpanneWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GliedAnsichtArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case sprung = "sprung"
    case kennlinie = "kennlinie"
    case takt = "takt"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GliedAnsichtArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum GliedAnsichtKategorieWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case strecke = "strecke"
    case regler = "regler"
    case messglied = "messglied"
    case nichtlinear = "nichtlinear"
    case planung = "planung"
    case beobachter = "beobachter"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = GliedAnsichtKategorieWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum HandeingriffOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case waermepumpe = "waermepumpe"
    case ofen = "ofen"
    case speicher = "speicher"
    case raum = "raum"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = HandeingriffOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum HeatBalanceOutPeriodWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = HeatBalanceOutPeriodWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum HeatPumpModeInManualStateWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case on = "on"
    case off = "off"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = HeatPumpModeInManualStateWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum InvoiceFeePerWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case month = "month"
    case day = "day"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = InvoiceFeePerWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum InvoiceFindingSeverityWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case ok = "ok"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = InvoiceFindingSeverityWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ItemDeviceWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case pellet = "pellet"
    case wood = "wood"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ItemDeviceWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ItemDirWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case n = "n"
    case s = "s"
    case o = "o"
    case w = "w"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ItemDirWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ItemHeadWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case n = "n"
    case s = "s"
    case o = "o"
    case w = "w"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ItemHeadWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ItemKindWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case box = "box"
    case cylinder = "cylinder"
    case bed = "bed"
    case chair = "chair"
    case stove = "stove"
    case ladder = "ladder"
    case loft = "loft"
    case panel = "panel"
    case tiles = "tiles"
    case ground = "ground"
    case wall = "wall"
    case gate = "gate"
    case plant = "plant"
    case tree = "tree"
    case car = "car"
    case wallbox = "wallbox"
    case heatPump = "heat_pump"
    case buffer = "buffer"
    case indoorUnit = "indoor_unit"
    case pipe = "pipe"
    case flight = "flight"
    case landing = "landing"
    case pit = "pit"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ItemKindWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ItemToneWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case dark = "dark"
    case light = "light"
    case soft = "soft"
    case water = "water"
    case wall = "wall"
    case paving = "paving"
    case terrace = "terrace"
    case slate = "slate"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ItemToneWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum KanteAnsichtArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case signal = "signal"
    case stoergroesse = "stoergroesse"
    case rueckfuehrung = "rueckfuehrung"
    case fuehrung = "fuehrung"
    case parameter = "parameter"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = KanteAnsichtArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum KanteAnsichtVorzeichenWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case plus = "+"
    case minus = "-"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = KanteAnsichtVorzeichenWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum KennlinienFitOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case ebene = "ebene"
    case aussen = "aussen"
    case vorlauf = "vorlauf"
    case mittel = "mittel"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = KennlinienFitOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum KennlinienHubOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gerade = "gerade"
    case mittel = "mittel"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = KennlinienHubOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum KreisAnsichtArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case stetig = "stetig"
    case zweipunkt = "zweipunkt"
    case hybrid = "hybrid"
    case planung = "planung"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = KreisAnsichtArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum OverrideKind: String, Codable, Sendable, Hashable, CaseIterable {
    case forceRelease = "force_release"
    case forceOff = "force_off"
    case forceBlock = "force_block"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = OverrideKind(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ParameterAnsichtHerkunftWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gemessen = "gemessen"
    case geschaetzt = "geschaetzt"
    case annahme = "annahme"
    case fest = "fest"
    case entwurf = "entwurf"
    case uebersteuert = "uebersteuert"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ParameterAnsichtHerkunftWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ParameterAnsichtSchaetzartWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case ausgleich = "ausgleich"
    case fenster = "fenster"
    case rls = "rls"
    case ereignis = "ereignis"
    case bilanz = "bilanz"
    case stillstand = "stillstand"
    case ewma = "ewma"
    case keiner = "keiner"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ParameterAnsichtSchaetzartWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum PersonAendernInRolleWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case hausherr = "hausherr"
    case bewohner = "bewohner"
    case gast = "gast"
    case service = "service"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = PersonAendernInRolleWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum PersonAnlegenInRolleWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case hausherr = "hausherr"
    case bewohner = "bewohner"
    case gast = "gast"
    case service = "service"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = PersonAnlegenInRolleWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum PersonOutRolleWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case hausherr = "hausherr"
    case bewohner = "bewohner"
    case gast = "gast"
    case service = "service"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = PersonOutRolleWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum PlanIntervalOutPlannedHpStateWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case off = "off"
    case release = "release"
    case free = "free"
    case avoid = "avoid"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = PlanIntervalOutPlannedHpStateWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum PriceWindowOutKindWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case cheap = "cheap"
    case expensive = "expensive"
    case negative = "negative"
    case pvSurplus = "pv_surplus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = PriceWindowOutKindWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum PruefungCodeWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case uebernommen = "uebernommen"
    case zuWenigDaten = "zu_wenig_daten"
    case innerhalbUnsicherheit = "innerhalb_unsicherheit"
    case zuFrueh = "zu_frueh"
    case grenzen = "grenzen"
    case nichtBesser = "nicht_besser"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = PruefungCodeWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum PvTaxReportOutPeriodWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = PvTaxReportOutPeriodWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum Quality: String, Codable, Sendable, Hashable, CaseIterable {
    case ok = "ok"
    case stale = "stale"
    case unavailable = "unavailable"
    case unknown = "unknown"
    case derived = "derived"
    case inconsistent = "inconsistent"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = Quality(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ReasonCode: String, Codable, Sendable, Hashable, CaseIterable {
    case pvSurplus = "pv_surplus"
    case pvSurplusFading = "pv_surplus_fading"
    case priceNegative = "price_negative"
    case priceCheapWindow = "price_cheap_window"
    case plannedWindow = "planned_window"
    case heatDemandForced = "heat_demand_forced"
    case hpRunningOwnControl = "hp_running_own_control"
    case minRuntimeHold = "min_runtime_hold"
    case minOfftimePending = "min_offtime_pending"
    case onDelayPending = "on_delay_pending"
    case offDelayPending = "off_delay_pending"
    case bufferFull = "buffer_full"
    case bufferNoHeadroom = "buffer_no_headroom"
    case maxStartsReached = "max_starts_reached"
    case noTrigger = "no_trigger"
    case plannedPause = "planned_pause"
    case importTooHigh = "import_too_high"
    case manualOverride = "manual_override"
    case modeOff = "mode_off"
    case sensorStale = "sensor_stale"
    case sensorUnavailable = "sensor_unavailable"
    case priceDataStale = "price_data_stale"
    case hpNotResponding = "hp_not_responding"
    case failsafe = "failsafe"
    case toggleRateExceeded = "toggle_rate_exceeded"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ReasonCode(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ReglerEinstellungOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case zahl = "zahl"
    case wahl = "wahl"
    case schalter = "schalter"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ReglerEinstellungOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum RoomLogEntryOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case sollwert = "sollwert"
    case befehl = "befehl"
    case ruhe = "ruhe"
    case einstellung = "einstellung"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = RoomLogEntryOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum RoomLogEntryOutQuelleWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case app = "app"
    case automatik = "automatik"
    case extern = "extern"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = RoomLogEntryOutQuelleWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum RoomShiftOutPhaseWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case laden = "laden"
    case zehren = "zehren"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = RoomShiftOutPhaseWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum ShiftReportOutPeriodWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = ShiftReportOutPeriodWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum StoveLiveOutModeWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case auto = "auto"
    case on = "on"
    case off = "off"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = StoveLiveOutModeWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum StoveModeInModeWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case auto = "auto"
    case on = "on"
    case off = "off"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = StoveModeInModeWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum StreckeAnsichtArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case foptd = "foptd"
    case iptd = "iptd"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = StreckeAnsichtArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum SystemMode: String, Codable, Sendable, Hashable, CaseIterable {
    case off = "off"
    case manual = "manual"
    case auto = "auto"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = SystemMode(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum UebersichtBildOutArtWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case balken = "balken"
    case fuellung = "fuellung"
    case abweichung = "abweichung"
    case streifen = "streifen"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = UebersichtBildOutArtWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum UebersichtKarteOutAmpelWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case gut = "gut"
    case warn = "warn"
    case schlecht = "schlecht"
    case aus = "aus"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = UebersichtKarteOutAmpelWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum UpdateAnfrageInAktionWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case installieren = "installieren"
    case pruefen = "pruefen"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = UpdateAnfrageInAktionWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum VersandOutWegWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case smtp = "smtp"
    case https = "https"
    case leer = ""
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = VersandOutWegWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum WaermepumpeOutEinspeisungWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case oben = "oben"
    case tiefer = "tiefer"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = WaermepumpeOutEinspeisungWahl(rawValue: roh) ?? .unbekannt
    }
}

/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue
/// Spielart im Dienst die App nicht stehen laesst.
public enum WatchFindingOutSeverityWahl: String, Codable, Sendable, Hashable, CaseIterable {
    case warn = "warn"
    case alarm = "alarm"
    case unbekannt = "—unbekannt—"

    public init(from decoder: any Decoder) throws {
        let roh = try decoder.singleValueContainer().decode(String.self)
        self = WatchFindingOutSeverityWahl(rawValue: roh) ?? .unbekannt
    }
}

// MARK: - Strukturen

/// Der Abstand zwischen zwei Linien, mit seiner Bedeutung. Positiv heißt: teurer.
public struct Abstand: Codable, Sendable, Hashable {
    public var key: String
    public var nameDe: String
    public var von: String
    public var nach: String
    public var eur: Double?
    public var satzDe: String?
    public var mengeEur: Double?
    public var zeitEur: Double?
    public var ofenEur: Double?

    public enum CodingKeys: String, CodingKey {
        case key
        case nameDe = "name_de"
        case von
        case nach
        case eur
        case satzDe = "satz_de"
        case mengeEur = "menge_eur"
        case zeitEur = "zeit_eur"
        case ofenEur = "ofen_eur"
    }

    public init(key: String, nameDe: String, von: String, nach: String, eur: Double? = nil, satzDe: String? = nil, mengeEur: Double? = nil, zeitEur: Double? = nil, ofenEur: Double? = nil) {
        self.key = key
        self.nameDe = nameDe
        self.von = von
        self.nach = nach
        self.eur = eur
        self.satzDe = satzDe
        self.mengeEur = mengeEur
        self.zeitEur = zeitEur
        self.ofenEur = ofenEur
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.nameDe = try c.decode(String.self, forKey: .nameDe)
        self.von = try c.decode(String.self, forKey: .von)
        self.nach = try c.decode(String.self, forKey: .nach)
        self.eur = try c.decodeIfPresent(Double.self, forKey: .eur)
        self.satzDe = try c.decodeIfPresent(String.self, forKey: .satzDe)
        self.mengeEur = try c.decodeIfPresent(Double.self, forKey: .mengeEur)
        self.zeitEur = try c.decodeIfPresent(Double.self, forKey: .zeitEur)
        self.ofenEur = try c.decodeIfPresent(Double.self, forKey: .ofenEur)
    }
}

public struct ActuatorCommandIn: Codable, Sendable, Hashable {
    public var state: Bool
    public var durationMin: Int?

    public enum CodingKeys: String, CodingKey {
        case state
        case durationMin = "duration_min"
    }

    public init(state: Bool, durationMin: Int? = nil) {
        self.state = state
        self.durationMin = durationMin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.state = try c.decode(Bool.self, forKey: .state)
        self.durationMin = try c.decodeIfPresent(Int.self, forKey: .durationMin)
    }
}

public struct ActuatorCommandOut: Codable, Sendable, Hashable {
    public var key: String
    public var requested: Bool
    public var observed: Bool?
    public var ok: Bool
    public var messageDe: String

    public enum CodingKeys: String, CodingKey {
        case key
        case requested
        case observed
        case ok
        case messageDe = "message_de"
    }

    public init(key: String, requested: Bool, observed: Bool? = nil, ok: Bool, messageDe: String) {
        self.key = key
        self.requested = requested
        self.observed = observed
        self.ok = ok
        self.messageDe = messageDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.requested = try c.decode(Bool.self, forKey: .requested)
        self.observed = try c.decodeIfPresent(Bool.self, forKey: .observed)
        self.ok = try c.decode(Bool.self, forKey: .ok)
        self.messageDe = try c.decode(String.self, forKey: .messageDe)
    }
}

public struct AlarmArmIn: Codable, Sendable, Hashable {
    public var mode: AlarmArmInModeWahl

    public init(mode: AlarmArmInModeWahl) {
        self.mode = mode
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try c.decode(AlarmArmInModeWahl.self, forKey: .mode)
    }
}

public struct AlarmArmOut: Codable, Sendable, Hashable {
    public var ok: Bool
    public var alarm: AlarmOut
    public var messageDe: String

    public enum CodingKeys: String, CodingKey {
        case ok
        case alarm
        case messageDe = "message_de"
    }

    public init(ok: Bool, alarm: AlarmOut, messageDe: String) {
        self.ok = ok
        self.alarm = alarm
        self.messageDe = messageDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decode(Bool.self, forKey: .ok)
        self.alarm = try c.decode(AlarmOut.self, forKey: .alarm)
        self.messageDe = try c.decode(String.self, forKey: .messageDe)
    }
}

/// Die Alarmanlage, so weit sie dieses Werkzeug angeht.
///
/// **Scharf ja, unscharf nein.** Die Anzeige hängt in der Küche, Gäste gehen daran vorbei, und
/// ihr Zugang ist ein Sitzungskeks auf einem Gerät - schwächer als ein Code am Bedienteil.
/// Deshalb kennt diese Schnittstelle nur das Schärfen. Wer entschärfen will, tut es dort, wo es
/// hingehört, und `can_arm` sagt, ob überhaupt geschaltet werden darf.
public struct AlarmOut: Codable, Sendable, Hashable {
    public var present: Bool
    public var state: Double?
    public var stateDe: String
    public var canArm: Bool
    public var observedAt: String?

    public enum CodingKeys: String, CodingKey {
        case present
        case state
        case stateDe = "state_de"
        case canArm = "can_arm"
        case observedAt = "observed_at"
    }

    public init(present: Bool, state: Double? = nil, stateDe: String, canArm: Bool, observedAt: String? = nil) {
        self.present = present
        self.state = state
        self.stateDe = stateDe
        self.canArm = canArm
        self.observedAt = observedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.present = try c.decode(Bool.self, forKey: .present)
        self.state = try c.decodeIfPresent(Double.self, forKey: .state)
        self.stateDe = try c.decode(String.self, forKey: .stateDe)
        self.canArm = try c.decode(Bool.self, forKey: .canArm)
        self.observedAt = try c.decodeIfPresent(String.self, forKey: .observedAt)
    }
}

public struct AlfredAntwortOut: Codable, Sendable, Hashable {
    public var bereit: Bool
    public var antwort: String
    public var vorschlaege: [AlfredVorschlagOut]

    public init(bereit: Bool, antwort: String, vorschlaege: [AlfredVorschlagOut] = []) {
        self.bereit = bereit
        self.antwort = antwort
        self.vorschlaege = vorschlaege
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bereit = try c.decode(Bool.self, forKey: .bereit)
        self.antwort = try c.decode(String.self, forKey: .antwort)
        self.vorschlaege = try c.decodeIfPresent([AlfredVorschlagOut].self, forKey: .vorschlaege) ?? []
    }
}

public struct AlfredFrageIn: Codable, Sendable, Hashable {
    public var frage: String
    public var wissen: String?
    public var verlauf: [AlfredWechselIn]

    public init(frage: String, wissen: String? = nil, verlauf: [AlfredWechselIn] = []) {
        self.frage = frage
        self.wissen = wissen
        self.verlauf = verlauf
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.frage = try c.decode(String.self, forKey: .frage)
        self.wissen = try c.decodeIfPresent(String.self, forKey: .wissen)
        self.verlauf = try c.decodeIfPresent([AlfredWechselIn].self, forKey: .verlauf) ?? []
    }
}

/// `tibber`: erkannt, geprueft und abgelegt wie auf der Rechnungsseite, ohne Sprachmodell.
/// `andere`: vom Sprachmodell gelesen, fest gegen die eigene Messung gehalten, nicht gespeichert.
public struct AlfredRechnungOut: Codable, Sendable, Hashable {
    public var art: AlfredRechnungOutArtWahl
    public var tibber: TibberZusammenfassung?
    public var andere: Rechnungsergebnis?
    public var link: String?

    public init(art: AlfredRechnungOutArtWahl, tibber: TibberZusammenfassung? = nil, andere: Rechnungsergebnis? = nil, link: String? = nil) {
        self.art = art
        self.tibber = tibber
        self.andere = andere
        self.link = link
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(AlfredRechnungOutArtWahl.self, forKey: .art)
        self.tibber = try c.decodeIfPresent(TibberZusammenfassung.self, forKey: .tibber)
        self.andere = try c.decodeIfPresent(Rechnungsergebnis.self, forKey: .andere)
        self.link = try c.decodeIfPresent(String.self, forKey: .link)
    }
}

/// Ein Vorschlag, noch nicht ausgeführt. `art` sagt, welcher Endpunkt ihn beim Drücken ausführt:
/// `schalten` → POST /control/actuators/{ziel}, `sollwert` → POST /rooms/{ziel}/setpoint.
public struct AlfredVorschlagOut: Codable, Sendable, Hashable {
    public var art: AlfredVorschlagOutArtWahl
    public var ziel: Mischwert
    public var name: String
    public var an: Bool?
    public var warAn: Bool?
    public var alt: Double?
    public var neu: Double?

    public enum CodingKeys: String, CodingKey {
        case art
        case ziel
        case name
        case an
        case warAn = "war_an"
        case alt
        case neu
    }

    public init(art: AlfredVorschlagOutArtWahl, ziel: Mischwert, name: String, an: Bool? = nil, warAn: Bool? = nil, alt: Double? = nil, neu: Double? = nil) {
        self.art = art
        self.ziel = ziel
        self.name = name
        self.an = an
        self.warAn = warAn
        self.alt = alt
        self.neu = neu
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(AlfredVorschlagOutArtWahl.self, forKey: .art)
        self.ziel = try c.decode(Mischwert.self, forKey: .ziel)
        self.name = try c.decode(String.self, forKey: .name)
        self.an = try c.decodeIfPresent(Bool.self, forKey: .an)
        self.warAn = try c.decodeIfPresent(Bool.self, forKey: .warAn)
        self.alt = try c.decodeIfPresent(Double.self, forKey: .alt)
        self.neu = try c.decodeIfPresent(Double.self, forKey: .neu)
    }
}

/// Ein früherer Wechsel des Gesprächs. Ungeprüfte Eingabe aus dem Browser: Begrenzt werden Rolle,
/// Länge und - in `AlfredFrageIn` - die Zahl; der Dienst nimmt davon nur die letzten.
public struct AlfredWechselIn: Codable, Sendable, Hashable {
    public var wer: AlfredWechselInWerWahl
    public var inhalt: String

    public init(wer: AlfredWechselInWerWahl, inhalt: String) {
        self.wer = wer
        self.inhalt = inhalt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wer = try c.decode(AlfredWechselInWerWahl.self, forKey: .wer)
        self.inhalt = try c.decode(String.self, forKey: .inhalt)
    }
}

/// Eine eingefügte Entitätenliste aus Home Assistant (Entwicklerwerkzeuge → Zustände).
public struct AlfredZuordnungIn: Codable, Sendable, Hashable {
    public var liste: String

    public init(liste: String) {
        self.liste = liste
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.liste = try c.decode(String.self, forKey: .liste)
    }
}

/// Ob Alfred antworten kann, und an wen Fragen gehen (KI-Verordnung Art. 50).
public struct AlfredZustandOut: Codable, Sendable, Hashable {
    public var bereit: Bool
    public var anbieter: String?
    public var modell: String?

    public init(bereit: Bool, anbieter: String? = nil, modell: String? = nil) {
        self.bereit = bereit
        self.anbieter = anbieter
        self.modell = modell
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bereit = try c.decode(Bool.self, forKey: .bereit)
        self.anbieter = try c.decodeIfPresent(String.self, forKey: .anbieter)
        self.modell = try c.decodeIfPresent(String.self, forKey: .modell)
    }
}

/// Das Ergebnis einer Anmeldung.
///
/// `token` ist der Ausweis im Klartext und existiert genau hier einmal. Das BFF legt ihn in ein
/// HttpOnly-Cookie und gibt ihn nie an den Browser weiter; eine App legt ihn in den
/// Schlüsselbund.
public struct AngemeldetOut: Codable, Sendable, Hashable {
    public var token: String
    public var laeuftAbAm: String
    public var ausweis: AusweisOut
    public var codes: [String]

    public enum CodingKeys: String, CodingKey {
        case token
        case laeuftAbAm = "laeuft_ab_am"
        case ausweis
        case codes
    }

    public init(token: String, laeuftAbAm: String, ausweis: AusweisOut, codes: [String] = []) {
        self.token = token
        self.laeuftAbAm = laeuftAbAm
        self.ausweis = ausweis
        self.codes = codes
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try c.decode(String.self, forKey: .token)
        self.laeuftAbAm = try c.decode(String.self, forKey: .laeuftAbAm)
        self.ausweis = try c.decode(AusweisOut.self, forKey: .ausweis)
        self.codes = try c.decodeIfPresent([String].self, forKey: .codes) ?? []
    }
}

/// Der Heizkreis: wie viele Räume gerade Wärme nehmen. Eine Leistung gibt es nicht; die
/// Wärmebilanz kennt sie nur als Rest, und ein Rest ist keine Anzeige für den Augenblick.
public struct AnlageHeizkreisOut: Codable, Sendable, Hashable {
    public var roomsTotal: Int
    public var roomsOpen: Int
    public var openShare: Double?
    public var running: Bool

    public enum CodingKeys: String, CodingKey {
        case roomsTotal = "rooms_total"
        case roomsOpen = "rooms_open"
        case openShare = "open_share"
        case running
    }

    public init(roomsTotal: Int, roomsOpen: Int, openShare: Double? = nil, running: Bool) {
        self.roomsTotal = roomsTotal
        self.roomsOpen = roomsOpen
        self.openShare = openShare
        self.running = running
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.roomsTotal = try c.decode(Int.self, forKey: .roomsTotal)
        self.roomsOpen = try c.decode(Int.self, forKey: .roomsOpen)
        self.openShare = try c.decodeIfPresent(Double.self, forKey: .openShare)
        self.running = try c.decode(Bool.self, forKey: .running)
    }
}

/// Der Pelletofen im Schema. `water_kw` ist geschätzt aus der Leistungsstufe nach dem
/// Datenblatt, dieselbe Rechnung wie in der Wärmebilanz.
public struct AnlageOfenOut: Codable, Sendable, Hashable {
    public var present: Bool
    public var running: Bool?
    public var powerLevel: Double?
    public var flowC: Double?
    public var returnC: Double?
    public var pumpPct: Double?
    public var waterKw: Double?

    public enum CodingKeys: String, CodingKey {
        case present
        case running
        case powerLevel = "power_level"
        case flowC = "flow_c"
        case returnC = "return_c"
        case pumpPct = "pump_pct"
        case waterKw = "water_kw"
    }

    public init(present: Bool, running: Bool? = nil, powerLevel: Double? = nil, flowC: Double? = nil, returnC: Double? = nil, pumpPct: Double? = nil, waterKw: Double? = nil) {
        self.present = present
        self.running = running
        self.powerLevel = powerLevel
        self.flowC = flowC
        self.returnC = returnC
        self.pumpPct = pumpPct
        self.waterKw = waterKw
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.present = try c.decode(Bool.self, forKey: .present)
        self.running = try c.decodeIfPresent(Bool.self, forKey: .running)
        self.powerLevel = try c.decodeIfPresent(Double.self, forKey: .powerLevel)
        self.flowC = try c.decodeIfPresent(Double.self, forKey: .flowC)
        self.returnC = try c.decodeIfPresent(Double.self, forKey: .returnC)
        self.pumpPct = try c.decodeIfPresent(Double.self, forKey: .pumpPct)
        self.waterKw = try c.decodeIfPresent(Double.self, forKey: .waterKw)
    }
}

/// Das Anlagenschema im Augenblick: alles, was die Seite „Anlage" zeichnet, in einer Antwort.
///
/// Keine Zeitreihe, kein Zeitraum: Das Bild ist der Augenblick, und seine Zahlen kommen aus dem
/// Live-Zustand, aus den Räumen und aus zwei kurzen Rückblicken in die Minutenreihe für die
/// Nettoleistung des Speichers und die Zapferkennung.
public struct AnlageOut: Codable, Sendable, Hashable {
    public var at: String
    public var outdoorC: Double?
    public var strom: AnlageStromOut
    public var waermepumpe: AnlageWaermepumpeOut
    public var ofen: AnlageOfenOut
    public var speicher: AnlageSpeicherOut
    public var heizkreis: AnlageHeizkreisOut
    public var warmwasser: AnlageWarmwasserOut

    public enum CodingKeys: String, CodingKey {
        case at
        case outdoorC = "outdoor_c"
        case strom
        case waermepumpe
        case ofen
        case speicher
        case heizkreis
        case warmwasser
    }

    public init(at: String, outdoorC: Double? = nil, strom: AnlageStromOut, waermepumpe: AnlageWaermepumpeOut, ofen: AnlageOfenOut, speicher: AnlageSpeicherOut, heizkreis: AnlageHeizkreisOut, warmwasser: AnlageWarmwasserOut) {
        self.at = at
        self.outdoorC = outdoorC
        self.strom = strom
        self.waermepumpe = waermepumpe
        self.ofen = ofen
        self.speicher = speicher
        self.heizkreis = heizkreis
        self.warmwasser = warmwasser
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.outdoorC = try c.decodeIfPresent(Double.self, forKey: .outdoorC)
        self.strom = try c.decode(AnlageStromOut.self, forKey: .strom)
        self.waermepumpe = try c.decode(AnlageWaermepumpeOut.self, forKey: .waermepumpe)
        self.ofen = try c.decode(AnlageOfenOut.self, forKey: .ofen)
        self.speicher = try c.decode(AnlageSpeicherOut.self, forKey: .speicher)
        self.heizkreis = try c.decode(AnlageHeizkreisOut.self, forKey: .heizkreis)
        self.warmwasser = try c.decode(AnlageWarmwasserOut.self, forKey: .warmwasser)
    }
}

/// Ein Ortstag als Folge von Anlagenbildern: die Wiedergabe.
///
/// Dieselben Bilder wie `GET /anlage`, nur aus der Minutenreihe nachgebaut und nicht aus dem
/// Augenblick. Die Oberflaeche faehrt mit einem Schieber darueber; das Schema zeichnet jedes Bild
/// so, wie es den Augenblick zeichnet.
///
/// **Luecken sind Luecken.** Ein Zeitpunkt ohne Messung in der Toleranz liefert kein Bild, und es
/// wird keines erfunden: `frames` ist deshalb nicht notwendig gleichmaessig und kann kuerzer sein
/// als der Tag. `erwartet` sagt, wie viele Bilder ein vollstaendiger Tag haette - erst der
/// Vergleich macht die Luecke sichtbar, statt sie als dichtes Band erscheinen zu lassen.
///
/// **Was der Rueckblick nicht zeigen kann**, steht in `hinweise_de` und nicht nur im Quelltext:
/// beim ersten Bild ist unbekannt, wie lange die Waermepumpe schon lief, und fuer Tage vor dem
/// 09.11.2026 gibt es keinen aufbewahrten Fahrplan. Der Heizkreis leuchtet, soweit die
/// Raumhistorie Ventilstellungen fuer den Tag hat.
public struct AnlageReplayOut: Codable, Sendable, Hashable {
    public var day: String
    public var stepMin: Int
    public var von: String
    public var bis: String
    public var erwartet: Int
    public var frames: [AnlageOut]
    public var preisCtKwh: [Double?]
    public var geplantWp: [Bool?]
    public var geplantOfen: [Bool?]
    public var hinweiseDe: [String]

    public enum CodingKeys: String, CodingKey {
        case day
        case stepMin = "step_min"
        case von
        case bis
        case erwartet
        case frames
        case preisCtKwh = "preis_ct_kwh"
        case geplantWp = "geplant_wp"
        case geplantOfen = "geplant_ofen"
        case hinweiseDe = "hinweise_de"
    }

    public init(day: String, stepMin: Int, von: String, bis: String, erwartet: Int, frames: [AnlageOut] = [], preisCtKwh: [Double?] = [], geplantWp: [Bool?] = [], geplantOfen: [Bool?] = [], hinweiseDe: [String] = []) {
        self.day = day
        self.stepMin = stepMin
        self.von = von
        self.bis = bis
        self.erwartet = erwartet
        self.frames = frames
        self.preisCtKwh = preisCtKwh
        self.geplantWp = geplantWp
        self.geplantOfen = geplantOfen
        self.hinweiseDe = hinweiseDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try c.decode(String.self, forKey: .day)
        self.stepMin = try c.decode(Int.self, forKey: .stepMin)
        self.von = try c.decode(String.self, forKey: .von)
        self.bis = try c.decode(String.self, forKey: .bis)
        self.erwartet = try c.decode(Int.self, forKey: .erwartet)
        self.frames = try c.decodeIfPresent([AnlageOut].self, forKey: .frames) ?? []
        self.preisCtKwh = try c.decodeIfPresent([Double?].self, forKey: .preisCtKwh) ?? []
        self.geplantWp = try c.decodeIfPresent([Bool?].self, forKey: .geplantWp) ?? []
        self.geplantOfen = try c.decodeIfPresent([Bool?].self, forKey: .geplantOfen) ?? []
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
    }
}

/// Das Glas: vier Fühler von oben nach unten, Ladezustand und die gerechnete Nettoleistung.
///
/// `net_kw` ist die Änderung des Energieinhalts über die letzte Viertelstunde, positiv = lädt,
/// aus den vier Temperaturen und dem Volumen. `net_word` ist das Wort dazu („lädt", „entlädt",
/// „hält"), hier entschieden und nicht in der Anzeige, damit die Schwelle an einer Stelle steht.
/// `return_c` ist die Temperatur des gemeinsamen Rücklaufs an der untersten Spitze: der unterste
/// Fühler, den Ofen- und Wärmepumpenkreis teilen.
public struct AnlageSpeicherOut: Codable, Sendable, Hashable {
    public var tempsC: [Double?]
    public var soc: Double?
    public var usableKwh: Double?
    public var capacityKwh: Double
    public var volumeLiters: Double
    public var netKw: Double?
    public var netWord: String
    public var returnC: Double?

    public enum CodingKeys: String, CodingKey {
        case tempsC = "temps_c"
        case soc
        case usableKwh = "usable_kwh"
        case capacityKwh = "capacity_kwh"
        case volumeLiters = "volume_liters"
        case netKw = "net_kw"
        case netWord = "net_word"
        case returnC = "return_c"
    }

    public init(tempsC: [Double?] = [], soc: Double? = nil, usableKwh: Double? = nil, capacityKwh: Double, volumeLiters: Double, netKw: Double? = nil, netWord: String, returnC: Double? = nil) {
        self.tempsC = tempsC
        self.soc = soc
        self.usableKwh = usableKwh
        self.capacityKwh = capacityKwh
        self.volumeLiters = volumeLiters
        self.netKw = netKw
        self.netWord = netWord
        self.returnC = returnC
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tempsC = try c.decodeIfPresent([Double?].self, forKey: .tempsC) ?? []
        self.soc = try c.decodeIfPresent(Double.self, forKey: .soc)
        self.usableKwh = try c.decodeIfPresent(Double.self, forKey: .usableKwh)
        self.capacityKwh = try c.decode(Double.self, forKey: .capacityKwh)
        self.volumeLiters = try c.decode(Double.self, forKey: .volumeLiters)
        self.netKw = try c.decodeIfPresent(Double.self, forKey: .netKw)
        self.netWord = try c.decode(String.self, forKey: .netWord)
        self.returnC = try c.decodeIfPresent(Double.self, forKey: .returnC)
    }
}

/// Die Stromseite des Schemas: drei Quellen, ein Knoten, zwei Abgänge.
///
/// Vorzeichen wie im Live-Zustand: Netz positiv ist Bezug, Batterie positiv ist Laden. Die
/// Anteile (`share_*`) sagen, woher der Strom im Knoten gerade kommt: PV, Netzbezug und
/// Speicherentladung nach ihrer Einspeisung. Das ist eine Zuordnung nach Anteilen, keine Physik,
/// aber es ist die Zuordnung, die jede Bilanz benutzt. Sie summieren sich zu 1 oder sind alle 0.
public struct AnlageStromOut: Codable, Sendable, Hashable {
    public var pvKw: Double?
    public var gridKw: Double?
    public var batteryKw: Double?
    public var batterySoc: Double?
    public var houseKw: Double?
    public var heatPumpKw: Double?
    public var restKw: Double?
    public var sharePv: Double
    public var shareGrid: Double
    public var shareBattery: Double

    public enum CodingKeys: String, CodingKey {
        case pvKw = "pv_kw"
        case gridKw = "grid_kw"
        case batteryKw = "battery_kw"
        case batterySoc = "battery_soc"
        case houseKw = "house_kw"
        case heatPumpKw = "heat_pump_kw"
        case restKw = "rest_kw"
        case sharePv = "share_pv"
        case shareGrid = "share_grid"
        case shareBattery = "share_battery"
    }

    public init(pvKw: Double? = nil, gridKw: Double? = nil, batteryKw: Double? = nil, batterySoc: Double? = nil, houseKw: Double? = nil, heatPumpKw: Double? = nil, restKw: Double? = nil, sharePv: Double, shareGrid: Double, shareBattery: Double) {
        self.pvKw = pvKw
        self.gridKw = gridKw
        self.batteryKw = batteryKw
        self.batterySoc = batterySoc
        self.houseKw = houseKw
        self.heatPumpKw = heatPumpKw
        self.restKw = restKw
        self.sharePv = sharePv
        self.shareGrid = shareGrid
        self.shareBattery = shareBattery
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.pvKw = try c.decodeIfPresent(Double.self, forKey: .pvKw)
        self.gridKw = try c.decodeIfPresent(Double.self, forKey: .gridKw)
        self.batteryKw = try c.decodeIfPresent(Double.self, forKey: .batteryKw)
        self.batterySoc = try c.decodeIfPresent(Double.self, forKey: .batterySoc)
        self.houseKw = try c.decodeIfPresent(Double.self, forKey: .houseKw)
        self.heatPumpKw = try c.decodeIfPresent(Double.self, forKey: .heatPumpKw)
        self.restKw = try c.decodeIfPresent(Double.self, forKey: .restKw)
        self.sharePv = try c.decode(Double.self, forKey: .sharePv)
        self.shareGrid = try c.decode(Double.self, forKey: .shareGrid)
        self.shareBattery = try c.decode(Double.self, forKey: .shareBattery)
    }
}

/// Die Wärmepumpe im Schema. Wärme, Vorlauf und COP bleiben leer, bis der Bus angeschlossen
/// ist; die Anzeige sagt dann „Wärme nicht gemessen" statt eine Zahl zu erfinden.
public struct AnlageWaermepumpeOut: Codable, Sendable, Hashable {
    public var running: Bool
    public var runningSince: String?
    public var powerKw: Double?
    public var thermalKw: Double?
    public var flowC: Double?
    public var cop: Double?

    public enum CodingKeys: String, CodingKey {
        case running
        case runningSince = "running_since"
        case powerKw = "power_kw"
        case thermalKw = "thermal_kw"
        case flowC = "flow_c"
        case cop
    }

    public init(running: Bool, runningSince: String? = nil, powerKw: Double? = nil, thermalKw: Double? = nil, flowC: Double? = nil, cop: Double? = nil) {
        self.running = running
        self.runningSince = runningSince
        self.powerKw = powerKw
        self.thermalKw = thermalKw
        self.flowC = flowC
        self.cop = cop
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.running = try c.decode(Bool.self, forKey: .running)
        self.runningSince = try c.decodeIfPresent(String.self, forKey: .runningSince)
        self.powerKw = try c.decodeIfPresent(Double.self, forKey: .powerKw)
        self.thermalKw = try c.decodeIfPresent(Double.self, forKey: .thermalKw)
        self.flowC = try c.decodeIfPresent(Double.self, forKey: .flowC)
        self.cop = try c.decodeIfPresent(Double.self, forKey: .cop)
    }
}

/// Das Trinkwasser: ein Anlegefühler am warmen Auslass, sonst nichts.
///
/// `present` ist falsch, solange kein Fühler meldet; dann bleibt die Kachel gedimmt und sagt das.
/// `tapping` ist **erkannt**, nicht gemessen: Das Rohr springt auf, sobald warmes Wasser läuft,
/// siehe `hems_core.thermal.anlage.zapfung`. Es sagt, dass und seit wann, nicht wie viel.
public struct AnlageWarmwasserOut: Codable, Sendable, Hashable {
    public var present: Bool
    public var outletC: Double?
    public var inletC: Double?
    public var tapping: Bool?
    public var tappingSince: String?

    public enum CodingKeys: String, CodingKey {
        case present
        case outletC = "outlet_c"
        case inletC = "inlet_c"
        case tapping
        case tappingSince = "tapping_since"
    }

    public init(present: Bool, outletC: Double? = nil, inletC: Double? = nil, tapping: Bool? = nil, tappingSince: String? = nil) {
        self.present = present
        self.outletC = outletC
        self.inletC = inletC
        self.tapping = tapping
        self.tappingSince = tappingSince
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.present = try c.decode(Bool.self, forKey: .present)
        self.outletC = try c.decodeIfPresent(Double.self, forKey: .outletC)
        self.inletC = try c.decodeIfPresent(Double.self, forKey: .inletC)
        self.tapping = try c.decodeIfPresent(Bool.self, forKey: .tapping)
        self.tappingSince = try c.decodeIfPresent(String.self, forKey: .tappingSince)
    }
}

public struct AnmeldenIn: Codable, Sendable, Hashable {
    public var schritt: String
    public var antwort: [String: Mischwert]

    public init(schritt: String, antwort: [String: Mischwert] = [:]) {
        self.schritt = schritt
        self.antwort = antwort
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schritt = try c.decode(String.self, forKey: .schritt)
        self.antwort = try c.decodeIfPresent([String: Mischwert].self, forKey: .antwort) ?? [:]
    }
}

/// Was die API über sich selbst weiß; auch ohne Hausgerät (Railway) vorhanden.
public struct ApiSelbstOut: Codable, Sendable, Hashable {
    public var version: String
    public var commit: String
    public var modus: String
    public var laufzeitS: Int
    public var rssMb: Double
    public var datenbankOk: Bool?
    public var datenbankMs: Double?
    public var datenbankDe: String?
    public var datenbankBytes: Int?
    public var bridgeOnline: Bool?
    public var verbindungDe: String?
    public var quellen: [SourceStatusOut]
    public var befunde: [WatchFindingOut]
    public var sseClients: Int?
    public var alfredEingerichtet: Bool?
    public var energyRebuild: String?
    public var ampel: ApiSelbstOutAmpelWahl?
    public var textDe: String?

    public enum CodingKeys: String, CodingKey {
        case version
        case commit
        case modus
        case laufzeitS = "laufzeit_s"
        case rssMb = "rss_mb"
        case datenbankOk = "datenbank_ok"
        case datenbankMs = "datenbank_ms"
        case datenbankDe = "datenbank_de"
        case datenbankBytes = "datenbank_bytes"
        case bridgeOnline = "bridge_online"
        case verbindungDe = "verbindung_de"
        case quellen
        case befunde
        case sseClients = "sse_clients"
        case alfredEingerichtet = "alfred_eingerichtet"
        case energyRebuild = "energy_rebuild"
        case ampel
        case textDe = "text_de"
    }

    public init(version: String, commit: String, modus: String, laufzeitS: Int, rssMb: Double, datenbankOk: Bool? = nil, datenbankMs: Double? = nil, datenbankDe: String? = nil, datenbankBytes: Int? = nil, bridgeOnline: Bool? = nil, verbindungDe: String? = nil, quellen: [SourceStatusOut] = [], befunde: [WatchFindingOut] = [], sseClients: Int? = nil, alfredEingerichtet: Bool? = nil, energyRebuild: String? = nil, ampel: ApiSelbstOutAmpelWahl? = nil, textDe: String? = nil) {
        self.version = version
        self.commit = commit
        self.modus = modus
        self.laufzeitS = laufzeitS
        self.rssMb = rssMb
        self.datenbankOk = datenbankOk
        self.datenbankMs = datenbankMs
        self.datenbankDe = datenbankDe
        self.datenbankBytes = datenbankBytes
        self.bridgeOnline = bridgeOnline
        self.verbindungDe = verbindungDe
        self.quellen = quellen
        self.befunde = befunde
        self.sseClients = sseClients
        self.alfredEingerichtet = alfredEingerichtet
        self.energyRebuild = energyRebuild
        self.ampel = ampel
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decode(String.self, forKey: .version)
        self.commit = try c.decode(String.self, forKey: .commit)
        self.modus = try c.decode(String.self, forKey: .modus)
        self.laufzeitS = try c.decode(Int.self, forKey: .laufzeitS)
        self.rssMb = try c.decode(Double.self, forKey: .rssMb)
        self.datenbankOk = try c.decodeIfPresent(Bool.self, forKey: .datenbankOk)
        self.datenbankMs = try c.decodeIfPresent(Double.self, forKey: .datenbankMs)
        self.datenbankDe = try c.decodeIfPresent(String.self, forKey: .datenbankDe)
        self.datenbankBytes = try c.decodeIfPresent(Int.self, forKey: .datenbankBytes)
        self.bridgeOnline = try c.decodeIfPresent(Bool.self, forKey: .bridgeOnline)
        self.verbindungDe = try c.decodeIfPresent(String.self, forKey: .verbindungDe)
        self.quellen = try c.decodeIfPresent([SourceStatusOut].self, forKey: .quellen) ?? []
        self.befunde = try c.decodeIfPresent([WatchFindingOut].self, forKey: .befunde) ?? []
        self.sseClients = try c.decodeIfPresent(Int.self, forKey: .sseClients)
        self.alfredEingerichtet = try c.decodeIfPresent(Bool.self, forKey: .alfredEingerichtet)
        self.energyRebuild = try c.decodeIfPresent(String.self, forKey: .energyRebuild)
        self.ampel = try c.decodeIfPresent(ApiSelbstOutAmpelWahl.self, forKey: .ampel)
        self.textDe = try c.decodeIfPresent(String.self, forKey: .textDe)
    }
}

/// Ein Gerät der iOS-App anmelden.
///
/// Derselbe Zuschnitt wie `PushSubscribeIn`, nur dass die Adresse ein Gerätetoken ist und die
/// beiden Schlüssel fehlen: APNs verschlüsselt selbst.
public struct ApnsSubscribeIn: Codable, Sendable, Hashable {
    public var token: String
    public var label: String?
    public var sandbox: Bool?

    public init(token: String, label: String? = nil, sandbox: Bool? = nil) {
        self.token = token
        self.label = label
        self.sandbox = sandbox
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try c.decode(String.self, forKey: .token)
        self.label = try c.decodeIfPresent(String.self, forKey: .label)
        self.sandbox = try c.decodeIfPresent(Bool.self, forKey: .sandbox)
    }
}

public struct ApnsUnsubscribeIn: Codable, Sendable, Hashable {
    public var token: String

    public init(token: String) {
        self.token = token
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try c.decode(String.self, forKey: .token)
    }
}

/// Der Punkt, für den die Karte gerechnet wird.
public struct Arbeitspunkt: Codable, Sendable, Hashable {
    public var aussenC: Double
    public var vorlaufC: Double
    public var strompreisEurKwh: Double
    public var aussenGemessen: Bool?
    public var vorlaufGemessen: Bool?

    public enum CodingKeys: String, CodingKey {
        case aussenC = "aussen_c"
        case vorlaufC = "vorlauf_c"
        case strompreisEurKwh = "strompreis_eur_kwh"
        case aussenGemessen = "aussen_gemessen"
        case vorlaufGemessen = "vorlauf_gemessen"
    }

    public init(aussenC: Double, vorlaufC: Double, strompreisEurKwh: Double, aussenGemessen: Bool? = nil, vorlaufGemessen: Bool? = nil) {
        self.aussenC = aussenC
        self.vorlaufC = vorlaufC
        self.strompreisEurKwh = strompreisEurKwh
        self.aussenGemessen = aussenGemessen
        self.vorlaufGemessen = vorlaufGemessen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aussenC = try c.decode(Double.self, forKey: .aussenC)
        self.vorlaufC = try c.decode(Double.self, forKey: .vorlaufC)
        self.strompreisEurKwh = try c.decode(Double.self, forKey: .strompreisEurKwh)
        self.aussenGemessen = try c.decodeIfPresent(Bool.self, forKey: .aussenGemessen)
        self.vorlaufGemessen = try c.decodeIfPresent(Bool.self, forKey: .vorlaufGemessen)
    }
}

/// Wer gerade fragt. Die Oberfläche blendet danach aus, was die Rolle nicht darf - verboten
/// wird es am Dienst (`dch_api/auth/rechte.py`).
public struct AusweisOut: Codable, Sendable, Hashable {
    public var art: AusweisOutArtWahl
    public var rolle: AusweisOutRolleWahl
    public var personId: String?
    public var name: String?
    public var email: String?

    public enum CodingKeys: String, CodingKey {
        case art
        case rolle
        case personId = "person_id"
        case name
        case email
    }

    public init(art: AusweisOutArtWahl, rolle: AusweisOutRolleWahl, personId: String? = nil, name: String? = nil, email: String? = nil) {
        self.art = art
        self.rolle = rolle
        self.personId = personId
        self.name = name
        self.email = email
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(AusweisOutArtWahl.self, forKey: .art)
        self.rolle = try c.decode(AusweisOutRolleWahl.self, forKey: .rolle)
        self.personId = try c.decodeIfPresent(String.self, forKey: .personId)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.email = try c.decodeIfPresent(String.self, forKey: .email)
    }
}

/// Das Ergebnis von „Alles zurück auf Automatik“.
public struct AutomatikZurueckOut: Codable, Sendable, Hashable {
    public var ok: Bool
    public var meldungDe: String
    public var handeingriffe: HandeingriffeOut

    public enum CodingKeys: String, CodingKey {
        case ok
        case meldungDe = "meldung_de"
        case handeingriffe
    }

    public init(ok: Bool, meldungDe: String, handeingriffe: HandeingriffeOut) {
        self.ok = ok
        self.meldungDe = meldungDe
        self.handeingriffe = handeingriffe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decode(Bool.self, forKey: .ok)
        self.meldungDe = try c.decode(String.self, forKey: .meldungDe)
        self.handeingriffe = try c.decode(HandeingriffeOut.self, forKey: .handeingriffe)
    }
}

/// Ergebnis eines manuell angestoßenen myenergi-Historienabrufs.
public struct BackfillResultOut: Codable, Sendable, Hashable {
    public var ok: Bool
    public var readings: Int?
    public var start: String?
    public var end: String?
    public var errorDe: String?
    public var priceNoteDe: String?

    public enum CodingKeys: String, CodingKey {
        case ok
        case readings
        case start
        case end
        case errorDe = "error_de"
        case priceNoteDe = "price_note_de"
    }

    public init(ok: Bool, readings: Int? = nil, start: String? = nil, end: String? = nil, errorDe: String? = nil, priceNoteDe: String? = nil) {
        self.ok = ok
        self.readings = readings
        self.start = start
        self.end = end
        self.errorDe = errorDe
        self.priceNoteDe = priceNoteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decode(Bool.self, forKey: .ok)
        self.readings = try c.decodeIfPresent(Int.self, forKey: .readings)
        self.start = try c.decodeIfPresent(String.self, forKey: .start)
        self.end = try c.decodeIfPresent(String.self, forKey: .end)
        self.errorDe = try c.decodeIfPresent(String.self, forKey: .errorDe)
        self.priceNoteDe = try c.decodeIfPresent(String.self, forKey: .priceNoteDe)
    }
}

public struct BalanceConfig: Codable, Sendable, Hashable {
    public var toleranceKw: Double?
    public var minFlowKw: Double?

    public enum CodingKeys: String, CodingKey {
        case toleranceKw = "tolerance_kw"
        case minFlowKw = "min_flow_kw"
    }

    public init(toleranceKw: Double? = nil, minFlowKw: Double? = nil) {
        self.toleranceKw = toleranceKw
        self.minFlowKw = minFlowKw
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.toleranceKw = try c.decodeIfPresent(Double.self, forKey: .toleranceKw)
        self.minFlowKw = try c.decodeIfPresent(Double.self, forKey: .minFlowKw)
    }
}

public struct BatteryConfig: Codable, Sendable, Hashable {
    public var capacityKwh: Double?
    public var maxPowerKw: Double?
    public var controlEnabled: Bool?
    public var inverterIdleKw: Double?
    public var reserveSoc: Double?

    public enum CodingKeys: String, CodingKey {
        case capacityKwh = "capacity_kwh"
        case maxPowerKw = "max_power_kw"
        case controlEnabled = "control_enabled"
        case inverterIdleKw = "inverter_idle_kw"
        case reserveSoc = "reserve_soc"
    }

    public init(capacityKwh: Double? = nil, maxPowerKw: Double? = nil, controlEnabled: Bool? = nil, inverterIdleKw: Double? = nil, reserveSoc: Double? = nil) {
        self.capacityKwh = capacityKwh
        self.maxPowerKw = maxPowerKw
        self.controlEnabled = controlEnabled
        self.inverterIdleKw = inverterIdleKw
        self.reserveSoc = reserveSoc
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.capacityKwh = try c.decodeIfPresent(Double.self, forKey: .capacityKwh)
        self.maxPowerKw = try c.decodeIfPresent(Double.self, forKey: .maxPowerKw)
        self.controlEnabled = try c.decodeIfPresent(Bool.self, forKey: .controlEnabled)
        self.inverterIdleKw = try c.decodeIfPresent(Double.self, forKey: .inverterIdleKw)
        self.reserveSoc = try c.decodeIfPresent(Double.self, forKey: .reserveSoc)
    }
}

/// Der Speicher im Augenblick: sein Ladestand und was DCH mit ihm vorhat.
///
/// `mode` ist die Absicht, `command` der zuletzt an den Libbi gesendete Befehl. Die myenergi-Cloud
/// bestätigt nichts; ob das Gerät folgt, sagt erst die nächste Messung. Deshalb stehen beide da.
///
/// `command` kann None sein, und das ist nicht dasselbe wie „normal": es heißt, dass DCH gar nichts
/// gesendet hat und der Speicher in seiner eigenen Betriebsart läuft.
public struct BatteryLiveOut: Codable, Sendable, Hashable {
    public var controlEnabled: Bool?
    public var mode: BatteryLiveOutModeWahl?
    public var endsAt: String?
    public var reserveSoc: Double?
    public var soc: Double?
    public var command: BatteryLiveOutCommandWahl?
    public var sentAt: String?
    public var lastError: String?
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case controlEnabled = "control_enabled"
        case mode
        case endsAt = "ends_at"
        case reserveSoc = "reserve_soc"
        case soc
        case command
        case sentAt = "sent_at"
        case lastError = "last_error"
        case noteDe = "note_de"
    }

    public init(controlEnabled: Bool? = nil, mode: BatteryLiveOutModeWahl? = nil, endsAt: String? = nil, reserveSoc: Double? = nil, soc: Double? = nil, command: BatteryLiveOutCommandWahl? = nil, sentAt: String? = nil, lastError: String? = nil, noteDe: String? = nil) {
        self.controlEnabled = controlEnabled
        self.mode = mode
        self.endsAt = endsAt
        self.reserveSoc = reserveSoc
        self.soc = soc
        self.command = command
        self.sentAt = sentAt
        self.lastError = lastError
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.controlEnabled = try c.decodeIfPresent(Bool.self, forKey: .controlEnabled)
        self.mode = try c.decodeIfPresent(BatteryLiveOutModeWahl.self, forKey: .mode)
        self.endsAt = try c.decodeIfPresent(String.self, forKey: .endsAt)
        self.reserveSoc = try c.decodeIfPresent(Double.self, forKey: .reserveSoc)
        self.soc = try c.decodeIfPresent(Double.self, forKey: .soc)
        self.command = try c.decodeIfPresent(BatteryLiveOutCommandWahl.self, forKey: .command)
        self.sentAt = try c.decodeIfPresent(String.self, forKey: .sentAt)
        self.lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

/// `off` heißt: DCH sendet nichts und lässt dem Speicher seine eigene Regelung.
public struct BatteryModeIn: Codable, Sendable, Hashable {
    public var mode: BatteryModeInModeWahl
    public var durationMin: Int?
    public var reserveSoc: Double?

    public enum CodingKeys: String, CodingKey {
        case mode
        case durationMin = "duration_min"
        case reserveSoc = "reserve_soc"
    }

    public init(mode: BatteryModeInModeWahl, durationMin: Int? = nil, reserveSoc: Double? = nil) {
        self.mode = mode
        self.durationMin = durationMin
        self.reserveSoc = reserveSoc
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try c.decode(BatteryModeInModeWahl.self, forKey: .mode)
        self.durationMin = try c.decodeIfPresent(Int.self, forKey: .durationMin)
        self.reserveSoc = try c.decodeIfPresent(Double.self, forKey: .reserveSoc)
    }
}

public struct Befund: Codable, Sendable, Hashable {
    public var stufe: String
    public var titel: String
    public var text: String

    public init(stufe: String, titel: String, text: String) {
        self.stufe = stufe
        self.titel = titel
        self.text = text
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stufe = try c.decode(String.self, forKey: .stufe)
        self.titel = try c.decode(String.self, forKey: .titel)
        self.text = try c.decode(String.self, forKey: .text)
    }
}

/// Sollwert = a + b * Außentemperatur, nach kleinsten Quadraten über die Stunden.
public struct BetriebHeizkurveOut: Codable, Sendable, Hashable {
    public var a: Double
    public var b: Double
    public var n: Int
    public var r2: Double?
    public var aussenVonC: Double
    public var aussenBisC: Double
    public var formelDe: String

    public enum CodingKeys: String, CodingKey {
        case a
        case b
        case n
        case r2
        case aussenVonC = "aussen_von_c"
        case aussenBisC = "aussen_bis_c"
        case formelDe = "formel_de"
    }

    public init(a: Double, b: Double, n: Int, r2: Double? = nil, aussenVonC: Double, aussenBisC: Double, formelDe: String) {
        self.a = a
        self.b = b
        self.n = n
        self.r2 = r2
        self.aussenVonC = aussenVonC
        self.aussenBisC = aussenBisC
        self.formelDe = formelDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.a = try c.decode(Double.self, forKey: .a)
        self.b = try c.decode(Double.self, forKey: .b)
        self.n = try c.decode(Int.self, forKey: .n)
        self.r2 = try c.decodeIfPresent(Double.self, forKey: .r2)
        self.aussenVonC = try c.decode(Double.self, forKey: .aussenVonC)
        self.aussenBisC = try c.decode(Double.self, forKey: .aussenBisC)
        self.formelDe = try c.decode(String.self, forKey: .formelDe)
    }
}

/// Eine Klasse der Lauflängen: von einschließlich, bis ausschließlich (`None`: nach oben offen).
public struct BetriebKlasseOut: Codable, Sendable, Hashable {
    public var vonMin: Int
    public var bisMin: Int?
    public var laeufe: Int

    public enum CodingKeys: String, CodingKey {
        case vonMin = "von_min"
        case bisMin = "bis_min"
        case laeufe
    }

    public init(vonMin: Int, bisMin: Int? = nil, laeufe: Int) {
        self.vonMin = vonMin
        self.bisMin = bisMin
        self.laeufe = laeufe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.vonMin = try c.decode(Int.self, forKey: .vonMin)
        self.bisMin = try c.decodeIfPresent(Int.self, forKey: .bisMin)
        self.laeufe = try c.decode(Int.self, forKey: .laeufe)
    }
}

/// Ein Lauf des Verdichters, vom Anlaufen bis zum Halt.
public struct BetriebLaufOut: Codable, Sendable, Hashable {
    public var start: String
    public var minuten: Int
    public var abtauMin: Int
    public var abtauungen: Int
    public var zusatzMin: Int
    public var stromKwh: Double
    public var waermeKwh: Double?
    public var angeschnitten: Bool?

    public enum CodingKeys: String, CodingKey {
        case start
        case minuten
        case abtauMin = "abtau_min"
        case abtauungen
        case zusatzMin = "zusatz_min"
        case stromKwh = "strom_kwh"
        case waermeKwh = "waerme_kwh"
        case angeschnitten
    }

    public init(start: String, minuten: Int, abtauMin: Int, abtauungen: Int, zusatzMin: Int, stromKwh: Double, waermeKwh: Double? = nil, angeschnitten: Bool? = nil) {
        self.start = start
        self.minuten = minuten
        self.abtauMin = abtauMin
        self.abtauungen = abtauungen
        self.zusatzMin = zusatzMin
        self.stromKwh = stromKwh
        self.waermeKwh = waermeKwh
        self.angeschnitten = angeschnitten
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.minuten = try c.decode(Int.self, forKey: .minuten)
        self.abtauMin = try c.decode(Int.self, forKey: .abtauMin)
        self.abtauungen = try c.decode(Int.self, forKey: .abtauungen)
        self.zusatzMin = try c.decode(Int.self, forKey: .zusatzMin)
        self.stromKwh = try c.decode(Double.self, forKey: .stromKwh)
        self.waermeKwh = try c.decodeIfPresent(Double.self, forKey: .waermeKwh)
        self.angeschnitten = try c.decodeIfPresent(Bool.self, forKey: .angeschnitten)
    }
}

/// Der Betrieb der Wärmepumpe über Tage: Läufe, Abtauen, Takten, Heizkurve des Reglers.
///
/// Eine Auszählung gespeicherter Minuten. Was sie taugt, steht in `hinweise_de`.
public struct BetriebOut: Codable, Sendable, Hashable {
    public var now: String
    public var von: String
    public var bis: String
    public var zeitraumTage: Int
    public var tage: [BetriebTagOut]
    public var laeufe: [BetriebLaufOut]
    public var stunden: [BetriebStundeOut]
    public var heizkurve: BetriebHeizkurveOut?
    public var klassen: [BetriebKlasseOut]
    public var starts: Int?
    public var laufMin: Int?
    public var abtauMin: Int?
    public var abtauungen: Int?
    public var zusatzMin: Int?
    public var copGesamt: Double?
    public var copHeizen: Double?
    public var laufMedianMin: Double?
    public var saetzeDe: [String]
    public var hinweiseDe: [String]

    public enum CodingKeys: String, CodingKey {
        case now
        case von
        case bis
        case zeitraumTage = "zeitraum_tage"
        case tage
        case laeufe
        case stunden
        case heizkurve
        case klassen
        case starts
        case laufMin = "lauf_min"
        case abtauMin = "abtau_min"
        case abtauungen
        case zusatzMin = "zusatz_min"
        case copGesamt = "cop_gesamt"
        case copHeizen = "cop_heizen"
        case laufMedianMin = "lauf_median_min"
        case saetzeDe = "saetze_de"
        case hinweiseDe = "hinweise_de"
    }

    public init(now: String, von: String, bis: String, zeitraumTage: Int, tage: [BetriebTagOut] = [], laeufe: [BetriebLaufOut] = [], stunden: [BetriebStundeOut] = [], heizkurve: BetriebHeizkurveOut? = nil, klassen: [BetriebKlasseOut] = [], starts: Int? = nil, laufMin: Int? = nil, abtauMin: Int? = nil, abtauungen: Int? = nil, zusatzMin: Int? = nil, copGesamt: Double? = nil, copHeizen: Double? = nil, laufMedianMin: Double? = nil, saetzeDe: [String] = [], hinweiseDe: [String] = []) {
        self.now = now
        self.von = von
        self.bis = bis
        self.zeitraumTage = zeitraumTage
        self.tage = tage
        self.laeufe = laeufe
        self.stunden = stunden
        self.heizkurve = heizkurve
        self.klassen = klassen
        self.starts = starts
        self.laufMin = laufMin
        self.abtauMin = abtauMin
        self.abtauungen = abtauungen
        self.zusatzMin = zusatzMin
        self.copGesamt = copGesamt
        self.copHeizen = copHeizen
        self.laufMedianMin = laufMedianMin
        self.saetzeDe = saetzeDe
        self.hinweiseDe = hinweiseDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.now = try c.decode(String.self, forKey: .now)
        self.von = try c.decode(String.self, forKey: .von)
        self.bis = try c.decode(String.self, forKey: .bis)
        self.zeitraumTage = try c.decode(Int.self, forKey: .zeitraumTage)
        self.tage = try c.decodeIfPresent([BetriebTagOut].self, forKey: .tage) ?? []
        self.laeufe = try c.decodeIfPresent([BetriebLaufOut].self, forKey: .laeufe) ?? []
        self.stunden = try c.decodeIfPresent([BetriebStundeOut].self, forKey: .stunden) ?? []
        self.heizkurve = try c.decodeIfPresent(BetriebHeizkurveOut.self, forKey: .heizkurve)
        self.klassen = try c.decodeIfPresent([BetriebKlasseOut].self, forKey: .klassen) ?? []
        self.starts = try c.decodeIfPresent(Int.self, forKey: .starts)
        self.laufMin = try c.decodeIfPresent(Int.self, forKey: .laufMin)
        self.abtauMin = try c.decodeIfPresent(Int.self, forKey: .abtauMin)
        self.abtauungen = try c.decodeIfPresent(Int.self, forKey: .abtauungen)
        self.zusatzMin = try c.decodeIfPresent(Int.self, forKey: .zusatzMin)
        self.copGesamt = try c.decodeIfPresent(Double.self, forKey: .copGesamt)
        self.copHeizen = try c.decodeIfPresent(Double.self, forKey: .copHeizen)
        self.laufMedianMin = try c.decodeIfPresent(Double.self, forKey: .laufMedianMin)
        self.saetzeDe = try c.decodeIfPresent([String].self, forKey: .saetzeDe) ?? []
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
    }
}

/// Eine Stunde im Heizbetrieb: was der Regler als Vorlauf verlangte, bei welchem Wetter.
public struct BetriebStundeOut: Codable, Sendable, Hashable {
    public var at: String
    public var minuten: Int
    public var aussenC: Double
    public var sollC: Double
    public var vorlaufC: Double?
    public var ventil: Int?

    public enum CodingKeys: String, CodingKey {
        case at
        case minuten
        case aussenC = "aussen_c"
        case sollC = "soll_c"
        case vorlaufC = "vorlauf_c"
        case ventil
    }

    public init(at: String, minuten: Int, aussenC: Double, sollC: Double, vorlaufC: Double? = nil, ventil: Int? = nil) {
        self.at = at
        self.minuten = minuten
        self.aussenC = aussenC
        self.sollC = sollC
        self.vorlaufC = vorlaufC
        self.ventil = ventil
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.minuten = try c.decode(Int.self, forKey: .minuten)
        self.aussenC = try c.decode(Double.self, forKey: .aussenC)
        self.sollC = try c.decode(Double.self, forKey: .sollC)
        self.vorlaufC = try c.decodeIfPresent(Double.self, forKey: .vorlaufC)
        self.ventil = try c.decodeIfPresent(Int.self, forKey: .ventil)
    }
}

/// Ein Ortstag der Wärmepumpe (`hems_core.thermal.betrieb.Tag`).
public struct BetriebTagOut: Codable, Sendable, Hashable {
    public var tag: String
    public var starts: Int
    public var laufMin: Int
    public var abtauMin: Int
    public var abtauungen: Int
    public var zusatzMin: Int
    public var stromKwh: Double
    public var waermeKwh: Double?
    public var stromLaufKwh: Double?
    public var copTag: Double?
    public var copHeizen: Double?
    public var laufMedianMin: Double?
    public var aussenC: Double?
    public var waermeMin: Int?

    public enum CodingKeys: String, CodingKey {
        case tag
        case starts
        case laufMin = "lauf_min"
        case abtauMin = "abtau_min"
        case abtauungen
        case zusatzMin = "zusatz_min"
        case stromKwh = "strom_kwh"
        case waermeKwh = "waerme_kwh"
        case stromLaufKwh = "strom_lauf_kwh"
        case copTag = "cop_tag"
        case copHeizen = "cop_heizen"
        case laufMedianMin = "lauf_median_min"
        case aussenC = "aussen_c"
        case waermeMin = "waerme_min"
    }

    public init(tag: String, starts: Int, laufMin: Int, abtauMin: Int, abtauungen: Int, zusatzMin: Int, stromKwh: Double, waermeKwh: Double? = nil, stromLaufKwh: Double? = nil, copTag: Double? = nil, copHeizen: Double? = nil, laufMedianMin: Double? = nil, aussenC: Double? = nil, waermeMin: Int? = nil) {
        self.tag = tag
        self.starts = starts
        self.laufMin = laufMin
        self.abtauMin = abtauMin
        self.abtauungen = abtauungen
        self.zusatzMin = zusatzMin
        self.stromKwh = stromKwh
        self.waermeKwh = waermeKwh
        self.stromLaufKwh = stromLaufKwh
        self.copTag = copTag
        self.copHeizen = copHeizen
        self.laufMedianMin = laufMedianMin
        self.aussenC = aussenC
        self.waermeMin = waermeMin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tag = try c.decode(String.self, forKey: .tag)
        self.starts = try c.decode(Int.self, forKey: .starts)
        self.laufMin = try c.decode(Int.self, forKey: .laufMin)
        self.abtauMin = try c.decode(Int.self, forKey: .abtauMin)
        self.abtauungen = try c.decode(Int.self, forKey: .abtauungen)
        self.zusatzMin = try c.decode(Int.self, forKey: .zusatzMin)
        self.stromKwh = try c.decode(Double.self, forKey: .stromKwh)
        self.waermeKwh = try c.decodeIfPresent(Double.self, forKey: .waermeKwh)
        self.stromLaufKwh = try c.decodeIfPresent(Double.self, forKey: .stromLaufKwh)
        self.copTag = try c.decodeIfPresent(Double.self, forKey: .copTag)
        self.copHeizen = try c.decodeIfPresent(Double.self, forKey: .copHeizen)
        self.laufMedianMin = try c.decodeIfPresent(Double.self, forKey: .laufMedianMin)
        self.aussenC = try c.decodeIfPresent(Double.self, forKey: .aussenC)
        self.waermeMin = try c.decodeIfPresent(Int.self, forKey: .waermeMin)
    }
}

public struct BinCorrection: Codable, Sendable, Hashable {
    public var bin: Int
    public var labelDe: String
    public var factor: Double?
    public var previous: Double?
    public var lastRatio: Double?
    public var days: Int?

    public enum CodingKeys: String, CodingKey {
        case bin
        case labelDe = "label_de"
        case factor
        case previous
        case lastRatio = "last_ratio"
        case days
    }

    public init(bin: Int, labelDe: String, factor: Double? = nil, previous: Double? = nil, lastRatio: Double? = nil, days: Int? = nil) {
        self.bin = bin
        self.labelDe = labelDe
        self.factor = factor
        self.previous = previous
        self.lastRatio = lastRatio
        self.days = days
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bin = try c.decode(Int.self, forKey: .bin)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
        self.factor = try c.decodeIfPresent(Double.self, forKey: .factor)
        self.previous = try c.decodeIfPresent(Double.self, forKey: .previous)
        self.lastRatio = try c.decodeIfPresent(Double.self, forKey: .lastRatio)
        self.days = try c.decodeIfPresent(Int.self, forKey: .days)
    }
}

public struct BlockAnsicht: Codable, Sendable, Hashable {
    public var id: String
    public var ebene: Int
    public var rolle: BlockAnsichtRolleWahl
    public var rolleText: String
    public var name: String
    public var kurz: String
    public var kreis: String?
    public var erklaerung: [String]
    public var gleichungen: [String]
    public var behandlung: BlockAnsichtBehandlungWahl?
    public var behandlungText: String?
    public var quelle: String?
    public var marke: String?
    public var gibtMarke: String?
    public var parameter: [String]
    public var glied: String?
    public var gliedEntwurf: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case ebene
        case rolle
        case rolleText = "rolle_text"
        case name
        case kurz
        case kreis
        case erklaerung
        case gleichungen
        case behandlung
        case behandlungText = "behandlung_text"
        case quelle
        case marke
        case gibtMarke = "gibt_marke"
        case parameter
        case glied
        case gliedEntwurf = "glied_entwurf"
    }

    public init(id: String, ebene: Int, rolle: BlockAnsichtRolleWahl, rolleText: String, name: String, kurz: String, kreis: String? = nil, erklaerung: [String] = [], gleichungen: [String] = [], behandlung: BlockAnsichtBehandlungWahl? = nil, behandlungText: String? = nil, quelle: String? = nil, marke: String? = nil, gibtMarke: String? = nil, parameter: [String] = [], glied: String? = nil, gliedEntwurf: String? = nil) {
        self.id = id
        self.ebene = ebene
        self.rolle = rolle
        self.rolleText = rolleText
        self.name = name
        self.kurz = kurz
        self.kreis = kreis
        self.erklaerung = erklaerung
        self.gleichungen = gleichungen
        self.behandlung = behandlung
        self.behandlungText = behandlungText
        self.quelle = quelle
        self.marke = marke
        self.gibtMarke = gibtMarke
        self.parameter = parameter
        self.glied = glied
        self.gliedEntwurf = gliedEntwurf
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.ebene = try c.decode(Int.self, forKey: .ebene)
        self.rolle = try c.decode(BlockAnsichtRolleWahl.self, forKey: .rolle)
        self.rolleText = try c.decode(String.self, forKey: .rolleText)
        self.name = try c.decode(String.self, forKey: .name)
        self.kurz = try c.decode(String.self, forKey: .kurz)
        self.kreis = try c.decodeIfPresent(String.self, forKey: .kreis)
        self.erklaerung = try c.decodeIfPresent([String].self, forKey: .erklaerung) ?? []
        self.gleichungen = try c.decodeIfPresent([String].self, forKey: .gleichungen) ?? []
        self.behandlung = try c.decodeIfPresent(BlockAnsichtBehandlungWahl.self, forKey: .behandlung)
        self.behandlungText = try c.decodeIfPresent(String.self, forKey: .behandlungText)
        self.quelle = try c.decodeIfPresent(String.self, forKey: .quelle)
        self.marke = try c.decodeIfPresent(String.self, forKey: .marke)
        self.gibtMarke = try c.decodeIfPresent(String.self, forKey: .gibtMarke)
        self.parameter = try c.decodeIfPresent([String].self, forKey: .parameter) ?? []
        self.glied = try c.decodeIfPresent(String.self, forKey: .glied)
        self.gliedEntwurf = try c.decodeIfPresent(String.self, forKey: .gliedEntwurf)
    }
}

public struct BlockRuleConfig: Codable, Sendable, Hashable {
    public var enabled: Bool?
    public var maxDurationMin: Int?
    public var maxPerDay: Int?
    public var minSoc: Double?
    public var minOutdoorTempC: Double?
    public var blockTtlMin: Int?

    public enum CodingKeys: String, CodingKey {
        case enabled
        case maxDurationMin = "max_duration_min"
        case maxPerDay = "max_per_day"
        case minSoc = "min_soc"
        case minOutdoorTempC = "min_outdoor_temp_c"
        case blockTtlMin = "block_ttl_min"
    }

    public init(enabled: Bool? = nil, maxDurationMin: Int? = nil, maxPerDay: Int? = nil, minSoc: Double? = nil, minOutdoorTempC: Double? = nil, blockTtlMin: Int? = nil) {
        self.enabled = enabled
        self.maxDurationMin = maxDurationMin
        self.maxPerDay = maxPerDay
        self.minSoc = minSoc
        self.minOutdoorTempC = minOutdoorTempC
        self.blockTtlMin = blockTtlMin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        self.maxDurationMin = try c.decodeIfPresent(Int.self, forKey: .maxDurationMin)
        self.maxPerDay = try c.decodeIfPresent(Int.self, forKey: .maxPerDay)
        self.minSoc = try c.decodeIfPresent(Double.self, forKey: .minSoc)
        self.minOutdoorTempC = try c.decodeIfPresent(Double.self, forKey: .minOutdoorTempC)
        self.blockTtlMin = try c.decodeIfPresent(Int.self, forKey: .blockTtlMin)
    }
}

/// Energiebilanz des Puffers am Ankertag, aus den vier Fühlern gerechnet.
///
/// Die Änderung des Energieinhalts ist die Nettoleistung des Speichers. Wer sie verursacht hat, war
/// bis zur Anbindung des Ofens eine Schlussfolgerung: steigt der Inhalt, während die Wärmepumpe
/// steht, muss die Wärme von woanders kommen. Mit den Maestro-Daten ist es eine Feststellung, und
/// `gain_unexplained_kwh` bleibt für das übrig, was wirklich niemand erklärt.
public struct BufferBalanceOut: Codable, Sendable, Hashable {
    public var energyStartKwh: Double?
    public var energyEndKwh: Double?
    public var gainKwh: Double?
    public var dropKwh: Double?
    public var gainWithHpKwh: Double?
    public var gainWithoutHpKwh: Double?
    public var gainWithStoveKwh: Double?
    public var gainUnexplainedKwh: Double?
    public var stoveKnown: Bool?
    public var samples: Int?
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case energyStartKwh = "energy_start_kwh"
        case energyEndKwh = "energy_end_kwh"
        case gainKwh = "gain_kwh"
        case dropKwh = "drop_kwh"
        case gainWithHpKwh = "gain_with_hp_kwh"
        case gainWithoutHpKwh = "gain_without_hp_kwh"
        case gainWithStoveKwh = "gain_with_stove_kwh"
        case gainUnexplainedKwh = "gain_unexplained_kwh"
        case stoveKnown = "stove_known"
        case samples
        case noteDe = "note_de"
    }

    public init(energyStartKwh: Double? = nil, energyEndKwh: Double? = nil, gainKwh: Double? = nil, dropKwh: Double? = nil, gainWithHpKwh: Double? = nil, gainWithoutHpKwh: Double? = nil, gainWithStoveKwh: Double? = nil, gainUnexplainedKwh: Double? = nil, stoveKnown: Bool? = nil, samples: Int? = nil, noteDe: String? = nil) {
        self.energyStartKwh = energyStartKwh
        self.energyEndKwh = energyEndKwh
        self.gainKwh = gainKwh
        self.dropKwh = dropKwh
        self.gainWithHpKwh = gainWithHpKwh
        self.gainWithoutHpKwh = gainWithoutHpKwh
        self.gainWithStoveKwh = gainWithStoveKwh
        self.gainUnexplainedKwh = gainUnexplainedKwh
        self.stoveKnown = stoveKnown
        self.samples = samples
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.energyStartKwh = try c.decodeIfPresent(Double.self, forKey: .energyStartKwh)
        self.energyEndKwh = try c.decodeIfPresent(Double.self, forKey: .energyEndKwh)
        self.gainKwh = try c.decodeIfPresent(Double.self, forKey: .gainKwh)
        self.dropKwh = try c.decodeIfPresent(Double.self, forKey: .dropKwh)
        self.gainWithHpKwh = try c.decodeIfPresent(Double.self, forKey: .gainWithHpKwh)
        self.gainWithoutHpKwh = try c.decodeIfPresent(Double.self, forKey: .gainWithoutHpKwh)
        self.gainWithStoveKwh = try c.decodeIfPresent(Double.self, forKey: .gainWithStoveKwh)
        self.gainUnexplainedKwh = try c.decodeIfPresent(Double.self, forKey: .gainUnexplainedKwh)
        self.stoveKnown = try c.decodeIfPresent(Bool.self, forKey: .stoveKnown)
        self.samples = try c.decodeIfPresent(Int.self, forKey: .samples)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

public struct BufferConfig: Codable, Sendable, Hashable {
    public var volumeLiters: Double?
    public var layers: [Double]
    public var minUsefulTemperatureC: Double?
    public var targetTemperatureC: Double?
    public var maxTemperatureC: Double?
    public var comfortMinTopC: Double?
    public var lossKwPerK: Double?
    public var ambientC: Double?
    public var lossUsefulFraction: Double?
    public var socMethod: BufferConfigSocMethodWahl?
    public var weights: [Double]
    public var statusThresholds: [Double]
    public var socFull: Double?

    public enum CodingKeys: String, CodingKey {
        case volumeLiters = "volume_liters"
        case layers
        case minUsefulTemperatureC = "min_useful_temperature_c"
        case targetTemperatureC = "target_temperature_c"
        case maxTemperatureC = "max_temperature_c"
        case comfortMinTopC = "comfort_min_top_c"
        case lossKwPerK = "loss_kw_per_k"
        case ambientC = "ambient_c"
        case lossUsefulFraction = "loss_useful_fraction"
        case socMethod = "soc_method"
        case weights
        case statusThresholds = "status_thresholds"
        case socFull = "soc_full"
    }

    public init(volumeLiters: Double? = nil, layers: [Double] = [], minUsefulTemperatureC: Double? = nil, targetTemperatureC: Double? = nil, maxTemperatureC: Double? = nil, comfortMinTopC: Double? = nil, lossKwPerK: Double? = nil, ambientC: Double? = nil, lossUsefulFraction: Double? = nil, socMethod: BufferConfigSocMethodWahl? = nil, weights: [Double] = [], statusThresholds: [Double] = [], socFull: Double? = nil) {
        self.volumeLiters = volumeLiters
        self.layers = layers
        self.minUsefulTemperatureC = minUsefulTemperatureC
        self.targetTemperatureC = targetTemperatureC
        self.maxTemperatureC = maxTemperatureC
        self.comfortMinTopC = comfortMinTopC
        self.lossKwPerK = lossKwPerK
        self.ambientC = ambientC
        self.lossUsefulFraction = lossUsefulFraction
        self.socMethod = socMethod
        self.weights = weights
        self.statusThresholds = statusThresholds
        self.socFull = socFull
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.volumeLiters = try c.decodeIfPresent(Double.self, forKey: .volumeLiters)
        self.layers = try c.decodeIfPresent([Double].self, forKey: .layers) ?? []
        self.minUsefulTemperatureC = try c.decodeIfPresent(Double.self, forKey: .minUsefulTemperatureC)
        self.targetTemperatureC = try c.decodeIfPresent(Double.self, forKey: .targetTemperatureC)
        self.maxTemperatureC = try c.decodeIfPresent(Double.self, forKey: .maxTemperatureC)
        self.comfortMinTopC = try c.decodeIfPresent(Double.self, forKey: .comfortMinTopC)
        self.lossKwPerK = try c.decodeIfPresent(Double.self, forKey: .lossKwPerK)
        self.ambientC = try c.decodeIfPresent(Double.self, forKey: .ambientC)
        self.lossUsefulFraction = try c.decodeIfPresent(Double.self, forKey: .lossUsefulFraction)
        self.socMethod = try c.decodeIfPresent(BufferConfigSocMethodWahl.self, forKey: .socMethod)
        self.weights = try c.decodeIfPresent([Double].self, forKey: .weights) ?? []
        self.statusThresholds = try c.decodeIfPresent([Double].self, forKey: .statusThresholds) ?? []
        self.socFull = try c.decodeIfPresent(Double.self, forKey: .socFull)
    }
}

public struct BufferState: Codable, Sendable, Hashable {
    public var soc: Double?
    public var usableEnergyKwh: Double?
    public var capacityKwh: Double
    public var volumeLiters: Double
    public var meanTempC: Double?
    public var status: BufferStatus
    public var method: String
    public var headroomSoc: Double?

    public enum CodingKeys: String, CodingKey {
        case soc
        case usableEnergyKwh = "usable_energy_kwh"
        case capacityKwh = "capacity_kwh"
        case volumeLiters = "volume_liters"
        case meanTempC = "mean_temp_c"
        case status
        case method
        case headroomSoc = "headroom_soc"
    }

    public init(soc: Double? = nil, usableEnergyKwh: Double? = nil, capacityKwh: Double, volumeLiters: Double, meanTempC: Double? = nil, status: BufferStatus, method: String, headroomSoc: Double? = nil) {
        self.soc = soc
        self.usableEnergyKwh = usableEnergyKwh
        self.capacityKwh = capacityKwh
        self.volumeLiters = volumeLiters
        self.meanTempC = meanTempC
        self.status = status
        self.method = method
        self.headroomSoc = headroomSoc
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.soc = try c.decodeIfPresent(Double.self, forKey: .soc)
        self.usableEnergyKwh = try c.decodeIfPresent(Double.self, forKey: .usableEnergyKwh)
        self.capacityKwh = try c.decode(Double.self, forKey: .capacityKwh)
        self.volumeLiters = try c.decode(Double.self, forKey: .volumeLiters)
        self.meanTempC = try c.decodeIfPresent(Double.self, forKey: .meanTempC)
        self.status = try c.decode(BufferStatus.self, forKey: .status)
        self.method = try c.decode(String.self, forKey: .method)
        self.headroomSoc = try c.decodeIfPresent(Double.self, forKey: .headroomSoc)
    }
}

public struct BufferTemperatures: Codable, Sendable, Hashable {
    public var top: Messwert
    public var midTop: Messwert
    public var midBottom: Messwert
    public var bottom: Messwert

    public enum CodingKeys: String, CodingKey {
        case top
        case midTop = "mid_top"
        case midBottom = "mid_bottom"
        case bottom
    }

    public init(top: Messwert, midTop: Messwert, midBottom: Messwert, bottom: Messwert) {
        self.top = top
        self.midTop = midTop
        self.midBottom = midBottom
        self.bottom = bottom
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.top = try c.decode(Messwert.self, forKey: .top)
        self.midTop = try c.decode(Messwert.self, forKey: .midTop)
        self.midBottom = try c.decode(Messwert.self, forKey: .midBottom)
        self.bottom = try c.decode(Messwert.self, forKey: .bottom)
    }
}

/// Ein Fenster oder eine Tuer mit Kontakt der Alarmanlage.
///
/// `key` ist der Schluessel, unter dem die Bruecke den Kontakt meldet (Entity-Zuordnung, `kind:
/// binary`, 1 heisst offen). `side` sagt, in welcher Aussenwand des Raums er sitzt, `at` ist die
/// Koordinate dieser Wand (z fuer n/s, x fuer o/w), `a..b` die Lage laengs der Wand.
public struct Contact: Codable, Sendable, Hashable {
    public var name: String
    public var key: String
    public var room: String?
    public var side: ContactSideWahl
    public var at: Double
    public var a: Double
    public var b: Double
    public var door: Bool?

    public init(name: String, key: String, room: String? = nil, side: ContactSideWahl, at: Double, a: Double, b: Double, door: Bool? = nil) {
        self.name = name
        self.key = key
        self.room = room
        self.side = side
        self.at = at
        self.a = a
        self.b = b
        self.door = door
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.key = try c.decode(String.self, forKey: .key)
        self.room = try c.decodeIfPresent(String.self, forKey: .room)
        self.side = try c.decode(ContactSideWahl.self, forKey: .side)
        self.at = try c.decode(Double.self, forKey: .at)
        self.a = try c.decode(Double.self, forKey: .a)
        self.b = try c.decode(Double.self, forKey: .b)
        self.door = try c.decodeIfPresent(Bool.self, forKey: .door)
    }
}

public struct ControlConfig: Codable, Sendable, Hashable {
    public var tickS: Int?
    public var ewmaSeconds: Double?
    public var sensorGraceMin: Double?
    public var maxTogglesPerHour: Int?
    public var failsafeHoldMin: Int?
    public var pv: PvRuleConfig?
    public var price: PriceRuleConfig?
    public var block: BlockRuleConfig?

    public enum CodingKeys: String, CodingKey {
        case tickS = "tick_s"
        case ewmaSeconds = "ewma_seconds"
        case sensorGraceMin = "sensor_grace_min"
        case maxTogglesPerHour = "max_toggles_per_hour"
        case failsafeHoldMin = "failsafe_hold_min"
        case pv
        case price
        case block
    }

    public init(tickS: Int? = nil, ewmaSeconds: Double? = nil, sensorGraceMin: Double? = nil, maxTogglesPerHour: Int? = nil, failsafeHoldMin: Int? = nil, pv: PvRuleConfig? = nil, price: PriceRuleConfig? = nil, block: BlockRuleConfig? = nil) {
        self.tickS = tickS
        self.ewmaSeconds = ewmaSeconds
        self.sensorGraceMin = sensorGraceMin
        self.maxTogglesPerHour = maxTogglesPerHour
        self.failsafeHoldMin = failsafeHoldMin
        self.pv = pv
        self.price = price
        self.block = block
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tickS = try c.decodeIfPresent(Int.self, forKey: .tickS)
        self.ewmaSeconds = try c.decodeIfPresent(Double.self, forKey: .ewmaSeconds)
        self.sensorGraceMin = try c.decodeIfPresent(Double.self, forKey: .sensorGraceMin)
        self.maxTogglesPerHour = try c.decodeIfPresent(Int.self, forKey: .maxTogglesPerHour)
        self.failsafeHoldMin = try c.decodeIfPresent(Int.self, forKey: .failsafeHoldMin)
        self.pv = try c.decodeIfPresent(PvRuleConfig.self, forKey: .pv)
        self.price = try c.decodeIfPresent(PriceRuleConfig.self, forKey: .price)
        self.block = try c.decodeIfPresent(BlockRuleConfig.self, forKey: .block)
    }
}

/// Serialisierbarer Zustand des Korrektors (Persistenz in der API).
public struct CorrectorState: Codable, Sendable, Hashable {
    public var bins: [BinCorrection]
    public var kGlobal: Double?
    public var kGlobalPrevious: Double?
    public var daysLearned: Int?
    public var minDays: Int?
    public var halfLifeDays: Double?
    public var updatedOn: String?

    public enum CodingKeys: String, CodingKey {
        case bins
        case kGlobal = "k_global"
        case kGlobalPrevious = "k_global_previous"
        case daysLearned = "days_learned"
        case minDays = "min_days"
        case halfLifeDays = "half_life_days"
        case updatedOn = "updated_on"
    }

    public init(bins: [BinCorrection] = [], kGlobal: Double? = nil, kGlobalPrevious: Double? = nil, daysLearned: Int? = nil, minDays: Int? = nil, halfLifeDays: Double? = nil, updatedOn: String? = nil) {
        self.bins = bins
        self.kGlobal = kGlobal
        self.kGlobalPrevious = kGlobalPrevious
        self.daysLearned = daysLearned
        self.minDays = minDays
        self.halfLifeDays = halfLifeDays
        self.updatedOn = updatedOn
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bins = try c.decodeIfPresent([BinCorrection].self, forKey: .bins) ?? []
        self.kGlobal = try c.decodeIfPresent(Double.self, forKey: .kGlobal)
        self.kGlobalPrevious = try c.decodeIfPresent(Double.self, forKey: .kGlobalPrevious)
        self.daysLearned = try c.decodeIfPresent(Int.self, forKey: .daysLearned)
        self.minDays = try c.decodeIfPresent(Int.self, forKey: .minDays)
        self.halfLifeDays = try c.decodeIfPresent(Double.self, forKey: .halfLifeDays)
        self.updatedOn = try c.decodeIfPresent(String.self, forKey: .updatedOn)
    }
}

public struct CoverageOut: Codable, Sendable, Hashable {
    public var start: String
    public var end: String
    public var series: [CoverageSeriesOut]
    public var noteDe: String

    public enum CodingKeys: String, CodingKey {
        case start
        case end
        case series
        case noteDe = "note_de"
    }

    public init(start: String, end: String, series: [CoverageSeriesOut] = [], noteDe: String) {
        self.start = start
        self.end = end
        self.series = series
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.series = try c.decodeIfPresent([CoverageSeriesOut].self, forKey: .series) ?? []
        self.noteDe = try c.decode(String.self, forKey: .noteDe)
    }
}

/// Verfügbarkeit einer Messreihe: je Stunde die Zahl der angekommenen Minuten, plus Kennzahlen.
///
/// `longest_outage_h` zählt nur **vollständig** leere Stunden. Das ist bewusst eine Untergrenze:
/// aus Stundenzahlen lässt sich nicht ablesen, ob die fehlenden Minuten einer halb gefüllten Stunde
/// zusammenhängen. Eine Zahl, die etwas behauptet, was die Daten nicht hergeben, wäre hier schlimmer
/// als eine, die zu klein ist - und die Karte zeigt die Teilstunden ohnehin.
public struct CoverageSeriesOut: Codable, Sendable, Hashable {
    public var key: String
    public var labelDe: String
    public var hours: [[Mischwert]]
    public var coverage: Double
    public var minutesSeen: Int
    public var minutesExpected: Int
    public var incompleteHours: Int
    public var longestOutageH: Int
    public var lastAt: String?

    public enum CodingKeys: String, CodingKey {
        case key
        case labelDe = "label_de"
        case hours
        case coverage
        case minutesSeen = "minutes_seen"
        case minutesExpected = "minutes_expected"
        case incompleteHours = "incomplete_hours"
        case longestOutageH = "longest_outage_h"
        case lastAt = "last_at"
    }

    public init(key: String, labelDe: String, hours: [[Mischwert]] = [], coverage: Double, minutesSeen: Int, minutesExpected: Int, incompleteHours: Int, longestOutageH: Int, lastAt: String? = nil) {
        self.key = key
        self.labelDe = labelDe
        self.hours = hours
        self.coverage = coverage
        self.minutesSeen = minutesSeen
        self.minutesExpected = minutesExpected
        self.incompleteHours = incompleteHours
        self.longestOutageH = longestOutageH
        self.lastAt = lastAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
        self.hours = try c.decodeIfPresent([[Mischwert]].self, forKey: .hours) ?? []
        self.coverage = try c.decode(Double.self, forKey: .coverage)
        self.minutesSeen = try c.decode(Int.self, forKey: .minutesSeen)
        self.minutesExpected = try c.decode(Int.self, forKey: .minutesExpected)
        self.incompleteHours = try c.decode(Int.self, forKey: .incompleteHours)
        self.longestOutageH = try c.decode(Int.self, forKey: .longestOutageH)
        self.lastAt = try c.decodeIfPresent(String.self, forKey: .lastAt)
    }
}

/// Kennzahlen der Taktung eines Zeitraums.
public struct CyclingStats: Codable, Sendable, Hashable {
    public var runs: Int?
    public var coveredHours: Double?
    public var startsPerDay: Double?
    public var runningMinutes: Int?
    public var dutyCycle: Double?
    public var meanRunMin: Double?
    public var medianRunMin: Double?
    public var shortestRunMin: Int?
    public var longestRunMin: Int?
    public var meanPauseMin: Double?
    public var shortRuns: Int?
    public var shortShare: Double?
    public var verdict: CyclingStatsVerdictWahl?
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case runs
        case coveredHours = "covered_hours"
        case startsPerDay = "starts_per_day"
        case runningMinutes = "running_minutes"
        case dutyCycle = "duty_cycle"
        case meanRunMin = "mean_run_min"
        case medianRunMin = "median_run_min"
        case shortestRunMin = "shortest_run_min"
        case longestRunMin = "longest_run_min"
        case meanPauseMin = "mean_pause_min"
        case shortRuns = "short_runs"
        case shortShare = "short_share"
        case verdict
        case noteDe = "note_de"
    }

    public init(runs: Int? = nil, coveredHours: Double? = nil, startsPerDay: Double? = nil, runningMinutes: Int? = nil, dutyCycle: Double? = nil, meanRunMin: Double? = nil, medianRunMin: Double? = nil, shortestRunMin: Int? = nil, longestRunMin: Int? = nil, meanPauseMin: Double? = nil, shortRuns: Int? = nil, shortShare: Double? = nil, verdict: CyclingStatsVerdictWahl? = nil, noteDe: String? = nil) {
        self.runs = runs
        self.coveredHours = coveredHours
        self.startsPerDay = startsPerDay
        self.runningMinutes = runningMinutes
        self.dutyCycle = dutyCycle
        self.meanRunMin = meanRunMin
        self.medianRunMin = medianRunMin
        self.shortestRunMin = shortestRunMin
        self.longestRunMin = longestRunMin
        self.meanPauseMin = meanPauseMin
        self.shortRuns = shortRuns
        self.shortShare = shortShare
        self.verdict = verdict
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.runs = try c.decodeIfPresent(Int.self, forKey: .runs)
        self.coveredHours = try c.decodeIfPresent(Double.self, forKey: .coveredHours)
        self.startsPerDay = try c.decodeIfPresent(Double.self, forKey: .startsPerDay)
        self.runningMinutes = try c.decodeIfPresent(Int.self, forKey: .runningMinutes)
        self.dutyCycle = try c.decodeIfPresent(Double.self, forKey: .dutyCycle)
        self.meanRunMin = try c.decodeIfPresent(Double.self, forKey: .meanRunMin)
        self.medianRunMin = try c.decodeIfPresent(Double.self, forKey: .medianRunMin)
        self.shortestRunMin = try c.decodeIfPresent(Int.self, forKey: .shortestRunMin)
        self.longestRunMin = try c.decodeIfPresent(Int.self, forKey: .longestRunMin)
        self.meanPauseMin = try c.decodeIfPresent(Double.self, forKey: .meanPauseMin)
        self.shortRuns = try c.decodeIfPresent(Int.self, forKey: .shortRuns)
        self.shortShare = try c.decodeIfPresent(Double.self, forKey: .shortShare)
        self.verdict = try c.decodeIfPresent(CyclingStatsVerdictWahl.self, forKey: .verdict)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

public struct DailyScoreOut: Codable, Sendable, Hashable {
    public var day: String
    public var energyForecastKwh: Double
    public var energyActualKwh: Double
    public var energyErrorPct: Double?
    public var maeKw: Double
    public var biasKw: Double
    public var kGlobalAfter: Double
    public var issuedAt: String?

    public enum CodingKeys: String, CodingKey {
        case day
        case energyForecastKwh = "energy_forecast_kwh"
        case energyActualKwh = "energy_actual_kwh"
        case energyErrorPct = "energy_error_pct"
        case maeKw = "mae_kw"
        case biasKw = "bias_kw"
        case kGlobalAfter = "k_global_after"
        case issuedAt = "issued_at"
    }

    public init(day: String, energyForecastKwh: Double, energyActualKwh: Double, energyErrorPct: Double? = nil, maeKw: Double, biasKw: Double, kGlobalAfter: Double, issuedAt: String? = nil) {
        self.day = day
        self.energyForecastKwh = energyForecastKwh
        self.energyActualKwh = energyActualKwh
        self.energyErrorPct = energyErrorPct
        self.maeKw = maeKw
        self.biasKw = biasKw
        self.kGlobalAfter = kGlobalAfter
        self.issuedAt = issuedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try c.decode(String.self, forKey: .day)
        self.energyForecastKwh = try c.decode(Double.self, forKey: .energyForecastKwh)
        self.energyActualKwh = try c.decode(Double.self, forKey: .energyActualKwh)
        self.energyErrorPct = try c.decodeIfPresent(Double.self, forKey: .energyErrorPct)
        self.maeKw = try c.decode(Double.self, forKey: .maeKw)
        self.biasKw = try c.decode(Double.self, forKey: .biasKw)
        self.kGlobalAfter = try c.decode(Double.self, forKey: .kGlobalAfter)
        self.issuedAt = try c.decodeIfPresent(String.self, forKey: .issuedAt)
    }
}

public struct Decision: Codable, Sendable, Hashable {
    public var id: String?
    public var at: String
    public var controllerState: ControllerState
    public var k1Release: Bool
    public var k2Block: Bool
    public var reasons: [ReasonCode]
    public var blockedBy: [ReasonCode]
    public var inputs: DecisionInputs
    public var validUntil: String
    public var nextExpected: NextExpected?
    public var explanationDe: String
    public var changed: Bool?

    public enum CodingKeys: String, CodingKey {
        case id
        case at
        case controllerState = "controller_state"
        case k1Release = "k1_release"
        case k2Block = "k2_block"
        case reasons
        case blockedBy = "blocked_by"
        case inputs
        case validUntil = "valid_until"
        case nextExpected = "next_expected"
        case explanationDe = "explanation_de"
        case changed
    }

    public init(id: String? = nil, at: String, controllerState: ControllerState, k1Release: Bool, k2Block: Bool, reasons: [ReasonCode] = [], blockedBy: [ReasonCode] = [], inputs: DecisionInputs, validUntil: String, nextExpected: NextExpected? = nil, explanationDe: String, changed: Bool? = nil) {
        self.id = id
        self.at = at
        self.controllerState = controllerState
        self.k1Release = k1Release
        self.k2Block = k2Block
        self.reasons = reasons
        self.blockedBy = blockedBy
        self.inputs = inputs
        self.validUntil = validUntil
        self.nextExpected = nextExpected
        self.explanationDe = explanationDe
        self.changed = changed
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
        self.at = try c.decode(String.self, forKey: .at)
        self.controllerState = try c.decode(ControllerState.self, forKey: .controllerState)
        self.k1Release = try c.decode(Bool.self, forKey: .k1Release)
        self.k2Block = try c.decode(Bool.self, forKey: .k2Block)
        self.reasons = try c.decodeIfPresent([ReasonCode].self, forKey: .reasons) ?? []
        self.blockedBy = try c.decodeIfPresent([ReasonCode].self, forKey: .blockedBy) ?? []
        self.inputs = try c.decode(DecisionInputs.self, forKey: .inputs)
        self.validUntil = try c.decode(String.self, forKey: .validUntil)
        self.nextExpected = try c.decodeIfPresent(NextExpected.self, forKey: .nextExpected)
        self.explanationDe = try c.decode(String.self, forKey: .explanationDe)
        self.changed = try c.decodeIfPresent(Bool.self, forKey: .changed)
    }
}

public struct DecisionInputs: Codable, Sendable, Hashable {
    public var surplusEwmaKw: Double?
    public var importEwmaKw: Double?
    public var hpRunning: Bool
    public var hpPowerKw: Double
    public var bufferSoc: Double?
    public var bufferTopC: Double?
    public var priceCtKwh: Double?
    public var priceRank: Double?
    public var outdoorTempC: Double?
    public var startsToday: Int
    public var secondsSinceStop: Double?
    public var secondsSinceStart: Double?

    public enum CodingKeys: String, CodingKey {
        case surplusEwmaKw = "surplus_ewma_kw"
        case importEwmaKw = "import_ewma_kw"
        case hpRunning = "hp_running"
        case hpPowerKw = "hp_power_kw"
        case bufferSoc = "buffer_soc"
        case bufferTopC = "buffer_top_c"
        case priceCtKwh = "price_ct_kwh"
        case priceRank = "price_rank"
        case outdoorTempC = "outdoor_temp_c"
        case startsToday = "starts_today"
        case secondsSinceStop = "seconds_since_stop"
        case secondsSinceStart = "seconds_since_start"
    }

    public init(surplusEwmaKw: Double? = nil, importEwmaKw: Double? = nil, hpRunning: Bool, hpPowerKw: Double, bufferSoc: Double? = nil, bufferTopC: Double? = nil, priceCtKwh: Double? = nil, priceRank: Double? = nil, outdoorTempC: Double? = nil, startsToday: Int, secondsSinceStop: Double? = nil, secondsSinceStart: Double? = nil) {
        self.surplusEwmaKw = surplusEwmaKw
        self.importEwmaKw = importEwmaKw
        self.hpRunning = hpRunning
        self.hpPowerKw = hpPowerKw
        self.bufferSoc = bufferSoc
        self.bufferTopC = bufferTopC
        self.priceCtKwh = priceCtKwh
        self.priceRank = priceRank
        self.outdoorTempC = outdoorTempC
        self.startsToday = startsToday
        self.secondsSinceStop = secondsSinceStop
        self.secondsSinceStart = secondsSinceStart
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.surplusEwmaKw = try c.decodeIfPresent(Double.self, forKey: .surplusEwmaKw)
        self.importEwmaKw = try c.decodeIfPresent(Double.self, forKey: .importEwmaKw)
        self.hpRunning = try c.decode(Bool.self, forKey: .hpRunning)
        self.hpPowerKw = try c.decode(Double.self, forKey: .hpPowerKw)
        self.bufferSoc = try c.decodeIfPresent(Double.self, forKey: .bufferSoc)
        self.bufferTopC = try c.decodeIfPresent(Double.self, forKey: .bufferTopC)
        self.priceCtKwh = try c.decodeIfPresent(Double.self, forKey: .priceCtKwh)
        self.priceRank = try c.decodeIfPresent(Double.self, forKey: .priceRank)
        self.outdoorTempC = try c.decodeIfPresent(Double.self, forKey: .outdoorTempC)
        self.startsToday = try c.decode(Int.self, forKey: .startsToday)
        self.secondsSinceStop = try c.decodeIfPresent(Double.self, forKey: .secondsSinceStop)
        self.secondsSinceStart = try c.decodeIfPresent(Double.self, forKey: .secondsSinceStart)
    }
}

/// Ein Geschoss. `shell` ist die Aussenhaut (Vieleck, gegen den Uhrzeigersinn in x/z); an ihr
/// werden Aussenwaende hoeher und heller gezeichnet und steht der Schutzschild der Alarmanlage.
/// `plate` ist die Grundplatte darunter, `holes` sind Loecher darin (Luftraeume).
public struct Deck: Codable, Sendable, Hashable {
    public var key: String
    public var name: String
    public var shell: [[Double]]
    public var plate: [[Double]]?
    public var alarmShell: [[Double]]?
    public var holes: [[Double]]
    public var rooms: [Room]
    public var walls: [WallLine]
    public var gaps: [WallLine]
    public var openings: [Opening]
    public var contacts: [Contact]
    public var items: [Item]
    public var places: [Place]

    public enum CodingKeys: String, CodingKey {
        case key
        case name
        case shell
        case plate
        case alarmShell = "alarm_shell"
        case holes
        case rooms
        case walls
        case gaps
        case openings
        case contacts
        case items
        case places
    }

    public init(key: String, name: String, shell: [[Double]] = [], plate: [[Double]]? = nil, alarmShell: [[Double]]? = nil, holes: [[Double]] = [], rooms: [Room] = [], walls: [WallLine] = [], gaps: [WallLine] = [], openings: [Opening] = [], contacts: [Contact] = [], items: [Item] = [], places: [Place] = []) {
        self.key = key
        self.name = name
        self.shell = shell
        self.plate = plate
        self.alarmShell = alarmShell
        self.holes = holes
        self.rooms = rooms
        self.walls = walls
        self.gaps = gaps
        self.openings = openings
        self.contacts = contacts
        self.items = items
        self.places = places
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.name = try c.decode(String.self, forKey: .name)
        self.shell = try c.decodeIfPresent([[Double]].self, forKey: .shell) ?? []
        self.plate = try c.decodeIfPresent([[Double]].self, forKey: .plate)
        self.alarmShell = try c.decodeIfPresent([[Double]].self, forKey: .alarmShell)
        self.holes = try c.decodeIfPresent([[Double]].self, forKey: .holes) ?? []
        self.rooms = try c.decodeIfPresent([Room].self, forKey: .rooms) ?? []
        self.walls = try c.decodeIfPresent([WallLine].self, forKey: .walls) ?? []
        self.gaps = try c.decodeIfPresent([WallLine].self, forKey: .gaps) ?? []
        self.openings = try c.decodeIfPresent([Opening].self, forKey: .openings) ?? []
        self.contacts = try c.decodeIfPresent([Contact].self, forKey: .contacts) ?? []
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        self.places = try c.decodeIfPresent([Place].self, forKey: .places) ?? []
    }
}

public struct DemoControlIn: Codable, Sendable, Hashable {
    public var speed: Double?
    public var faultKey: String?
    public var faultQuality: DemoControlInFaultQualityWahl?
    public var faultDurationS: Int?
    public var scenario: DemoControlInScenarioWahl?

    public enum CodingKeys: String, CodingKey {
        case speed
        case faultKey = "fault_key"
        case faultQuality = "fault_quality"
        case faultDurationS = "fault_duration_s"
        case scenario
    }

    public init(speed: Double? = nil, faultKey: String? = nil, faultQuality: DemoControlInFaultQualityWahl? = nil, faultDurationS: Int? = nil, scenario: DemoControlInScenarioWahl? = nil) {
        self.speed = speed
        self.faultKey = faultKey
        self.faultQuality = faultQuality
        self.faultDurationS = faultDurationS
        self.scenario = scenario
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.speed = try c.decodeIfPresent(Double.self, forKey: .speed)
        self.faultKey = try c.decodeIfPresent(String.self, forKey: .faultKey)
        self.faultQuality = try c.decodeIfPresent(DemoControlInFaultQualityWahl.self, forKey: .faultQuality)
        self.faultDurationS = try c.decodeIfPresent(Int.self, forKey: .faultDurationS)
        self.scenario = try c.decodeIfPresent(DemoControlInScenarioWahl.self, forKey: .scenario)
    }
}

/// Ein Zutritt an der Haustür, so wie er im Ereignisprotokoll steht.
///
/// Aufbereitet und nicht roh: die Oberfläche soll eine Zeile zeigen können, ohne selbst zu wissen,
/// wie die Zutrittskonsole ihre Felder nennt. Die Übersetzung von „ACCESS" zu „geöffnet" ist an
/// der Tür passiert, hier steht das Ergebnis.
public struct DoorEntryOut: Codable, Sendable, Hashable {
    public var at: String
    public var actor: String
    public var door: String
    public var method: String
    public var outcome: String
    public var granted: Bool
    public var reason: String

    public init(at: String, actor: String, door: String, method: String, outcome: String, granted: Bool, reason: String) {
        self.at = at
        self.actor = actor
        self.door = door
        self.method = method
        self.outcome = outcome
        self.granted = granted
        self.reason = reason
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.actor = try c.decode(String.self, forKey: .actor)
        self.door = try c.decode(String.self, forKey: .door)
        self.method = try c.decode(String.self, forKey: .method)
        self.outcome = try c.decode(String.self, forKey: .outcome)
        self.granted = try c.decode(Bool.self, forKey: .granted)
        self.reason = try c.decode(String.self, forKey: .reason)
    }
}

public struct DoorLogOut: Codable, Sendable, Hashable {
    public var entries: [DoorEntryOut]
    public var days: Int
    public var noteDe: String

    public enum CodingKeys: String, CodingKey {
        case entries
        case days
        case noteDe = "note_de"
    }

    public init(entries: [DoorEntryOut] = [], days: Int, noteDe: String) {
        self.entries = entries
        self.days = days
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.entries = try c.decodeIfPresent([DoorEntryOut].self, forKey: .entries) ?? []
        self.days = try c.decode(Int.self, forKey: .days)
        self.noteDe = try c.decode(String.self, forKey: .noteDe)
    }
}

/// Einen neuen Link ausstellen. Die Person steht in der Adresse, nicht hier.
public struct EinladenIn: Codable, Sendable, Hashable {
    public var einladen: Bool?

    public init(einladen: Bool? = nil) {
        self.einladen = einladen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.einladen = try c.decodeIfPresent(Bool.self, forKey: .einladen)
    }
}

/// Der Einladungslink - einmal, im Klartext, zum Kopieren oder Verschicken.
public struct EinladungOut: Codable, Sendable, Hashable {
    public var person: PersonOut
    public var link: String
    public var laeuftAbAm: String
    public var verschickt: Bool?

    public enum CodingKeys: String, CodingKey {
        case person
        case link
        case laeuftAbAm = "laeuft_ab_am"
        case verschickt
    }

    public init(person: PersonOut, link: String, laeuftAbAm: String, verschickt: Bool? = nil) {
        self.person = person
        self.link = link
        self.laeuftAbAm = laeuftAbAm
        self.verschickt = verschickt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.person = try c.decode(PersonOut.self, forKey: .person)
        self.link = try c.decode(String.self, forKey: .link)
        self.laeuftAbAm = try c.decode(String.self, forKey: .laeuftAbAm)
        self.verschickt = try c.decodeIfPresent(Bool.self, forKey: .verschickt)
    }
}

/// Für die Seite hinter dem Link: zu wem er gehört und welche Wege herein es schon gibt.
public struct EinladungPersonOut: Codable, Sendable, Hashable {
    public var email: String
    public var anzeigename: String?
    public var rolle: EinladungPersonOutRolleWahl
    public var passkeys: Int?
    public var passwort: Bool?

    public init(email: String, anzeigename: String? = nil, rolle: EinladungPersonOutRolleWahl, passkeys: Int? = nil, passwort: Bool? = nil) {
        self.email = email
        self.anzeigename = anzeigename
        self.rolle = rolle
        self.passkeys = passkeys
        self.passwort = passwort
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.email = try c.decode(String.self, forKey: .email)
        self.anzeigename = try c.decodeIfPresent(String.self, forKey: .anzeigename)
        self.rolle = try c.decode(EinladungPersonOutRolleWahl.self, forKey: .rolle)
        self.passkeys = try c.decodeIfPresent(Int.self, forKey: .passkeys)
        self.passwort = try c.decodeIfPresent(Bool.self, forKey: .passwort)
    }
}

public struct EnergyBucketOut: Codable, Sendable, Hashable {
    public var start: String
    public var end: String
    public var label: String
    public var totals: EnergyTotalsOut

    public init(start: String, end: String, label: String, totals: EnergyTotalsOut) {
        self.start = start
        self.end = end
        self.label = label
        self.totals = totals
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.label = try c.decode(String.self, forKey: .label)
        self.totals = try c.decode(EnergyTotalsOut.self, forKey: .totals)
    }
}

public struct EnergyMetaOut: Codable, Sendable, Hashable {
    public var batteryCapacityKwh: Double
    public var feedInCtKwh: Double
    public var dataSince: String?
    public var coverage: Double?
    public var estimatedNoteDe: String

    public enum CodingKeys: String, CodingKey {
        case batteryCapacityKwh = "battery_capacity_kwh"
        case feedInCtKwh = "feed_in_ct_kwh"
        case dataSince = "data_since"
        case coverage
        case estimatedNoteDe = "estimated_note_de"
    }

    public init(batteryCapacityKwh: Double, feedInCtKwh: Double, dataSince: String? = nil, coverage: Double? = nil, estimatedNoteDe: String) {
        self.batteryCapacityKwh = batteryCapacityKwh
        self.feedInCtKwh = feedInCtKwh
        self.dataSince = dataSince
        self.coverage = coverage
        self.estimatedNoteDe = estimatedNoteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.batteryCapacityKwh = try c.decode(Double.self, forKey: .batteryCapacityKwh)
        self.feedInCtKwh = try c.decode(Double.self, forKey: .feedInCtKwh)
        self.dataSince = try c.decodeIfPresent(String.self, forKey: .dataSince)
        self.coverage = try c.decodeIfPresent(Double.self, forKey: .coverage)
        self.estimatedNoteDe = try c.decode(String.self, forKey: .estimatedNoteDe)
    }
}

public struct EnergySnapshot: Codable, Sendable, Hashable {
    public var timestamp: String
    public var pvPowerKw: Messwert
    public var gridPowerKw: Messwert
    public var batteryPowerKw: Messwert
    public var batterySoc: Messwert
    public var housePowerKw: Messwert
    public var baseLoadKw: Messwert
    public var heatPumpPowerKw: Messwert
    public var evPowerKw: Messwert
    public var electricityPriceCtKwh: Messwert
    public var outdoorTempC: Messwert
    public var bufferTempsC: BufferTemperatures
    public var hpReleaseContact: Messwert
    public var hpBlockContact: Messwert
    public var actuators: [String: Messwert]
    public var balanceResidualKw: Double?

    public enum CodingKeys: String, CodingKey {
        case timestamp
        case pvPowerKw = "pv_power_kw"
        case gridPowerKw = "grid_power_kw"
        case batteryPowerKw = "battery_power_kw"
        case batterySoc = "battery_soc"
        case housePowerKw = "house_power_kw"
        case baseLoadKw = "base_load_kw"
        case heatPumpPowerKw = "heat_pump_power_kw"
        case evPowerKw = "ev_power_kw"
        case electricityPriceCtKwh = "electricity_price_ct_kwh"
        case outdoorTempC = "outdoor_temp_c"
        case bufferTempsC = "buffer_temps_c"
        case hpReleaseContact = "hp_release_contact"
        case hpBlockContact = "hp_block_contact"
        case actuators
        case balanceResidualKw = "balance_residual_kw"
    }

    public init(timestamp: String, pvPowerKw: Messwert, gridPowerKw: Messwert, batteryPowerKw: Messwert, batterySoc: Messwert, housePowerKw: Messwert, baseLoadKw: Messwert, heatPumpPowerKw: Messwert, evPowerKw: Messwert, electricityPriceCtKwh: Messwert, outdoorTempC: Messwert, bufferTempsC: BufferTemperatures, hpReleaseContact: Messwert, hpBlockContact: Messwert, actuators: [String: Messwert] = [:], balanceResidualKw: Double? = nil) {
        self.timestamp = timestamp
        self.pvPowerKw = pvPowerKw
        self.gridPowerKw = gridPowerKw
        self.batteryPowerKw = batteryPowerKw
        self.batterySoc = batterySoc
        self.housePowerKw = housePowerKw
        self.baseLoadKw = baseLoadKw
        self.heatPumpPowerKw = heatPumpPowerKw
        self.evPowerKw = evPowerKw
        self.electricityPriceCtKwh = electricityPriceCtKwh
        self.outdoorTempC = outdoorTempC
        self.bufferTempsC = bufferTempsC
        self.hpReleaseContact = hpReleaseContact
        self.hpBlockContact = hpBlockContact
        self.actuators = actuators
        self.balanceResidualKw = balanceResidualKw
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.timestamp = try c.decode(String.self, forKey: .timestamp)
        self.pvPowerKw = try c.decode(Messwert.self, forKey: .pvPowerKw)
        self.gridPowerKw = try c.decode(Messwert.self, forKey: .gridPowerKw)
        self.batteryPowerKw = try c.decode(Messwert.self, forKey: .batteryPowerKw)
        self.batterySoc = try c.decode(Messwert.self, forKey: .batterySoc)
        self.housePowerKw = try c.decode(Messwert.self, forKey: .housePowerKw)
        self.baseLoadKw = try c.decode(Messwert.self, forKey: .baseLoadKw)
        self.heatPumpPowerKw = try c.decode(Messwert.self, forKey: .heatPumpPowerKw)
        self.evPowerKw = try c.decode(Messwert.self, forKey: .evPowerKw)
        self.electricityPriceCtKwh = try c.decode(Messwert.self, forKey: .electricityPriceCtKwh)
        self.outdoorTempC = try c.decode(Messwert.self, forKey: .outdoorTempC)
        self.bufferTempsC = try c.decode(BufferTemperatures.self, forKey: .bufferTempsC)
        self.hpReleaseContact = try c.decode(Messwert.self, forKey: .hpReleaseContact)
        self.hpBlockContact = try c.decode(Messwert.self, forKey: .hpBlockContact)
        self.actuators = try c.decodeIfPresent([String: Messwert].self, forKey: .actuators) ?? [:]
        self.balanceResidualKw = try c.decodeIfPresent(Double.self, forKey: .balanceResidualKw)
    }
}

public struct EnergySummaryOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var period: EnergySummaryOutPeriodWahl
    public var anchor: String
    public var start: String
    public var end: String
    public var totals: EnergyTotalsOut
    public var buckets: [EnergyBucketOut]
    public var meta: EnergyMetaOut

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case period
        case anchor
        case start
        case end
        case totals
        case buckets
        case meta
    }

    public init(generatedAt: String, period: EnergySummaryOutPeriodWahl, anchor: String, start: String, end: String, totals: EnergyTotalsOut, buckets: [EnergyBucketOut] = [], meta: EnergyMetaOut) {
        self.generatedAt = generatedAt
        self.period = period
        self.anchor = anchor
        self.start = start
        self.end = end
        self.totals = totals
        self.buckets = buckets
        self.meta = meta
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.period = try c.decode(EnergySummaryOutPeriodWahl.self, forKey: .period)
        self.anchor = try c.decode(String.self, forKey: .anchor)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.totals = try c.decode(EnergyTotalsOut.self, forKey: .totals)
        self.buckets = try c.decodeIfPresent([EnergyBucketOut].self, forKey: .buckets) ?? []
        self.meta = try c.decode(EnergyMetaOut.self, forKey: .meta)
    }
}

/// Summen plus abgeleitete Kennzahlen als normale Felder (für JSON).
public struct EnergyTotalsOut: Codable, Sendable, Hashable {
    public var minutes: Int?
    public var coarseMinutes: Int?
    public var pvKwh: Double?
    public var importKwh: Double?
    public var exportKwh: Double?
    public var batteryChargeKwh: Double?
    public var batteryDischargeKwh: Double?
    public var houseKwh: Double?
    public var heatPumpKwh: Double?
    public var evKwh: Double?
    public var baseKwh: Double?
    public var pvDirectKwh: Double?
    public var batteryToHouseKwh: Double?
    public var gridToHouseKwh: Double?
    public var pvToBatteryKwh: Double?
    public var gridToBatteryKwh: Double?
    public var batteryDeviceKwh: Double?
    public var batteryDevicePvKwh: Double?
    public var batteryDeviceGridKwh: Double?
    public var gridToBatteryDarkKwh: Double?
    public var batteryPvToHouseKwh: Double?
    public var batteryOriginEstimatedKwh: Double?
    public var heatPumpPvKwh: Double?
    public var heatPumpBatteryKwh: Double?
    public var heatPumpGridKwh: Double?
    public var evPvKwh: Double?
    public var evBatteryKwh: Double?
    public var evGridKwh: Double?
    public var importCostEur: Double?
    public var exportRevenueEur: Double?
    public var heatPumpCostEur: Double?
    public var heatPumpOpportunityEur: Double?
    public var evCostEur: Double?
    public var evOpportunityEur: Double?
    public var batteryDeviceCostEur: Double?
    public var batteryDeviceOpportunityEur: Double?
    public var batteryDischargeValueEur: Double?
    public var batteryChargeCostEur: Double?
    public var batterySavingsEur: Double?
    public var pvDirectSavingsEur: Double?
    public var priceWeightedCt: Double?
    public var priceHoursCt: Double?
    public var selfConsumptionValueEur: Double?
    public var priceMissingMinutes: Int?
    public var autarky: Double?
    public var selfConsumptionShare: Double?
    public var avgImportPriceCt: Double?
    public var batteryNetEur: Double?

    public enum CodingKeys: String, CodingKey {
        case minutes
        case coarseMinutes = "coarse_minutes"
        case pvKwh = "pv_kwh"
        case importKwh = "import_kwh"
        case exportKwh = "export_kwh"
        case batteryChargeKwh = "battery_charge_kwh"
        case batteryDischargeKwh = "battery_discharge_kwh"
        case houseKwh = "house_kwh"
        case heatPumpKwh = "heat_pump_kwh"
        case evKwh = "ev_kwh"
        case baseKwh = "base_kwh"
        case pvDirectKwh = "pv_direct_kwh"
        case batteryToHouseKwh = "battery_to_house_kwh"
        case gridToHouseKwh = "grid_to_house_kwh"
        case pvToBatteryKwh = "pv_to_battery_kwh"
        case gridToBatteryKwh = "grid_to_battery_kwh"
        case batteryDeviceKwh = "battery_device_kwh"
        case batteryDevicePvKwh = "battery_device_pv_kwh"
        case batteryDeviceGridKwh = "battery_device_grid_kwh"
        case gridToBatteryDarkKwh = "grid_to_battery_dark_kwh"
        case batteryPvToHouseKwh = "battery_pv_to_house_kwh"
        case batteryOriginEstimatedKwh = "battery_origin_estimated_kwh"
        case heatPumpPvKwh = "heat_pump_pv_kwh"
        case heatPumpBatteryKwh = "heat_pump_battery_kwh"
        case heatPumpGridKwh = "heat_pump_grid_kwh"
        case evPvKwh = "ev_pv_kwh"
        case evBatteryKwh = "ev_battery_kwh"
        case evGridKwh = "ev_grid_kwh"
        case importCostEur = "import_cost_eur"
        case exportRevenueEur = "export_revenue_eur"
        case heatPumpCostEur = "heat_pump_cost_eur"
        case heatPumpOpportunityEur = "heat_pump_opportunity_eur"
        case evCostEur = "ev_cost_eur"
        case evOpportunityEur = "ev_opportunity_eur"
        case batteryDeviceCostEur = "battery_device_cost_eur"
        case batteryDeviceOpportunityEur = "battery_device_opportunity_eur"
        case batteryDischargeValueEur = "battery_discharge_value_eur"
        case batteryChargeCostEur = "battery_charge_cost_eur"
        case batterySavingsEur = "battery_savings_eur"
        case pvDirectSavingsEur = "pv_direct_savings_eur"
        case priceWeightedCt = "price_weighted_ct"
        case priceHoursCt = "price_hours_ct"
        case selfConsumptionValueEur = "self_consumption_value_eur"
        case priceMissingMinutes = "price_missing_minutes"
        case autarky
        case selfConsumptionShare = "self_consumption_share"
        case avgImportPriceCt = "avg_import_price_ct"
        case batteryNetEur = "battery_net_eur"
    }

    public init(minutes: Int? = nil, coarseMinutes: Int? = nil, pvKwh: Double? = nil, importKwh: Double? = nil, exportKwh: Double? = nil, batteryChargeKwh: Double? = nil, batteryDischargeKwh: Double? = nil, houseKwh: Double? = nil, heatPumpKwh: Double? = nil, evKwh: Double? = nil, baseKwh: Double? = nil, pvDirectKwh: Double? = nil, batteryToHouseKwh: Double? = nil, gridToHouseKwh: Double? = nil, pvToBatteryKwh: Double? = nil, gridToBatteryKwh: Double? = nil, batteryDeviceKwh: Double? = nil, batteryDevicePvKwh: Double? = nil, batteryDeviceGridKwh: Double? = nil, gridToBatteryDarkKwh: Double? = nil, batteryPvToHouseKwh: Double? = nil, batteryOriginEstimatedKwh: Double? = nil, heatPumpPvKwh: Double? = nil, heatPumpBatteryKwh: Double? = nil, heatPumpGridKwh: Double? = nil, evPvKwh: Double? = nil, evBatteryKwh: Double? = nil, evGridKwh: Double? = nil, importCostEur: Double? = nil, exportRevenueEur: Double? = nil, heatPumpCostEur: Double? = nil, heatPumpOpportunityEur: Double? = nil, evCostEur: Double? = nil, evOpportunityEur: Double? = nil, batteryDeviceCostEur: Double? = nil, batteryDeviceOpportunityEur: Double? = nil, batteryDischargeValueEur: Double? = nil, batteryChargeCostEur: Double? = nil, batterySavingsEur: Double? = nil, pvDirectSavingsEur: Double? = nil, priceWeightedCt: Double? = nil, priceHoursCt: Double? = nil, selfConsumptionValueEur: Double? = nil, priceMissingMinutes: Int? = nil, autarky: Double? = nil, selfConsumptionShare: Double? = nil, avgImportPriceCt: Double? = nil, batteryNetEur: Double? = nil) {
        self.minutes = minutes
        self.coarseMinutes = coarseMinutes
        self.pvKwh = pvKwh
        self.importKwh = importKwh
        self.exportKwh = exportKwh
        self.batteryChargeKwh = batteryChargeKwh
        self.batteryDischargeKwh = batteryDischargeKwh
        self.houseKwh = houseKwh
        self.heatPumpKwh = heatPumpKwh
        self.evKwh = evKwh
        self.baseKwh = baseKwh
        self.pvDirectKwh = pvDirectKwh
        self.batteryToHouseKwh = batteryToHouseKwh
        self.gridToHouseKwh = gridToHouseKwh
        self.pvToBatteryKwh = pvToBatteryKwh
        self.gridToBatteryKwh = gridToBatteryKwh
        self.batteryDeviceKwh = batteryDeviceKwh
        self.batteryDevicePvKwh = batteryDevicePvKwh
        self.batteryDeviceGridKwh = batteryDeviceGridKwh
        self.gridToBatteryDarkKwh = gridToBatteryDarkKwh
        self.batteryPvToHouseKwh = batteryPvToHouseKwh
        self.batteryOriginEstimatedKwh = batteryOriginEstimatedKwh
        self.heatPumpPvKwh = heatPumpPvKwh
        self.heatPumpBatteryKwh = heatPumpBatteryKwh
        self.heatPumpGridKwh = heatPumpGridKwh
        self.evPvKwh = evPvKwh
        self.evBatteryKwh = evBatteryKwh
        self.evGridKwh = evGridKwh
        self.importCostEur = importCostEur
        self.exportRevenueEur = exportRevenueEur
        self.heatPumpCostEur = heatPumpCostEur
        self.heatPumpOpportunityEur = heatPumpOpportunityEur
        self.evCostEur = evCostEur
        self.evOpportunityEur = evOpportunityEur
        self.batteryDeviceCostEur = batteryDeviceCostEur
        self.batteryDeviceOpportunityEur = batteryDeviceOpportunityEur
        self.batteryDischargeValueEur = batteryDischargeValueEur
        self.batteryChargeCostEur = batteryChargeCostEur
        self.batterySavingsEur = batterySavingsEur
        self.pvDirectSavingsEur = pvDirectSavingsEur
        self.priceWeightedCt = priceWeightedCt
        self.priceHoursCt = priceHoursCt
        self.selfConsumptionValueEur = selfConsumptionValueEur
        self.priceMissingMinutes = priceMissingMinutes
        self.autarky = autarky
        self.selfConsumptionShare = selfConsumptionShare
        self.avgImportPriceCt = avgImportPriceCt
        self.batteryNetEur = batteryNetEur
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.minutes = try c.decodeIfPresent(Int.self, forKey: .minutes)
        self.coarseMinutes = try c.decodeIfPresent(Int.self, forKey: .coarseMinutes)
        self.pvKwh = try c.decodeIfPresent(Double.self, forKey: .pvKwh)
        self.importKwh = try c.decodeIfPresent(Double.self, forKey: .importKwh)
        self.exportKwh = try c.decodeIfPresent(Double.self, forKey: .exportKwh)
        self.batteryChargeKwh = try c.decodeIfPresent(Double.self, forKey: .batteryChargeKwh)
        self.batteryDischargeKwh = try c.decodeIfPresent(Double.self, forKey: .batteryDischargeKwh)
        self.houseKwh = try c.decodeIfPresent(Double.self, forKey: .houseKwh)
        self.heatPumpKwh = try c.decodeIfPresent(Double.self, forKey: .heatPumpKwh)
        self.evKwh = try c.decodeIfPresent(Double.self, forKey: .evKwh)
        self.baseKwh = try c.decodeIfPresent(Double.self, forKey: .baseKwh)
        self.pvDirectKwh = try c.decodeIfPresent(Double.self, forKey: .pvDirectKwh)
        self.batteryToHouseKwh = try c.decodeIfPresent(Double.self, forKey: .batteryToHouseKwh)
        self.gridToHouseKwh = try c.decodeIfPresent(Double.self, forKey: .gridToHouseKwh)
        self.pvToBatteryKwh = try c.decodeIfPresent(Double.self, forKey: .pvToBatteryKwh)
        self.gridToBatteryKwh = try c.decodeIfPresent(Double.self, forKey: .gridToBatteryKwh)
        self.batteryDeviceKwh = try c.decodeIfPresent(Double.self, forKey: .batteryDeviceKwh)
        self.batteryDevicePvKwh = try c.decodeIfPresent(Double.self, forKey: .batteryDevicePvKwh)
        self.batteryDeviceGridKwh = try c.decodeIfPresent(Double.self, forKey: .batteryDeviceGridKwh)
        self.gridToBatteryDarkKwh = try c.decodeIfPresent(Double.self, forKey: .gridToBatteryDarkKwh)
        self.batteryPvToHouseKwh = try c.decodeIfPresent(Double.self, forKey: .batteryPvToHouseKwh)
        self.batteryOriginEstimatedKwh = try c.decodeIfPresent(Double.self, forKey: .batteryOriginEstimatedKwh)
        self.heatPumpPvKwh = try c.decodeIfPresent(Double.self, forKey: .heatPumpPvKwh)
        self.heatPumpBatteryKwh = try c.decodeIfPresent(Double.self, forKey: .heatPumpBatteryKwh)
        self.heatPumpGridKwh = try c.decodeIfPresent(Double.self, forKey: .heatPumpGridKwh)
        self.evPvKwh = try c.decodeIfPresent(Double.self, forKey: .evPvKwh)
        self.evBatteryKwh = try c.decodeIfPresent(Double.self, forKey: .evBatteryKwh)
        self.evGridKwh = try c.decodeIfPresent(Double.self, forKey: .evGridKwh)
        self.importCostEur = try c.decodeIfPresent(Double.self, forKey: .importCostEur)
        self.exportRevenueEur = try c.decodeIfPresent(Double.self, forKey: .exportRevenueEur)
        self.heatPumpCostEur = try c.decodeIfPresent(Double.self, forKey: .heatPumpCostEur)
        self.heatPumpOpportunityEur = try c.decodeIfPresent(Double.self, forKey: .heatPumpOpportunityEur)
        self.evCostEur = try c.decodeIfPresent(Double.self, forKey: .evCostEur)
        self.evOpportunityEur = try c.decodeIfPresent(Double.self, forKey: .evOpportunityEur)
        self.batteryDeviceCostEur = try c.decodeIfPresent(Double.self, forKey: .batteryDeviceCostEur)
        self.batteryDeviceOpportunityEur = try c.decodeIfPresent(Double.self, forKey: .batteryDeviceOpportunityEur)
        self.batteryDischargeValueEur = try c.decodeIfPresent(Double.self, forKey: .batteryDischargeValueEur)
        self.batteryChargeCostEur = try c.decodeIfPresent(Double.self, forKey: .batteryChargeCostEur)
        self.batterySavingsEur = try c.decodeIfPresent(Double.self, forKey: .batterySavingsEur)
        self.pvDirectSavingsEur = try c.decodeIfPresent(Double.self, forKey: .pvDirectSavingsEur)
        self.priceWeightedCt = try c.decodeIfPresent(Double.self, forKey: .priceWeightedCt)
        self.priceHoursCt = try c.decodeIfPresent(Double.self, forKey: .priceHoursCt)
        self.selfConsumptionValueEur = try c.decodeIfPresent(Double.self, forKey: .selfConsumptionValueEur)
        self.priceMissingMinutes = try c.decodeIfPresent(Int.self, forKey: .priceMissingMinutes)
        self.autarky = try c.decodeIfPresent(Double.self, forKey: .autarky)
        self.selfConsumptionShare = try c.decodeIfPresent(Double.self, forKey: .selfConsumptionShare)
        self.avgImportPriceCt = try c.decodeIfPresent(Double.self, forKey: .avgImportPriceCt)
        self.batteryNetEur = try c.decodeIfPresent(Double.self, forKey: .batteryNetEur)
    }
}

/// Ein Schließvorgang und was die Maschine um ihn herum tat.
public struct Ereignis: Codable, Sendable, Hashable {
    public var at: String
    public var liefSchon: Bool
    public var auswertbar: Bool
    public var gefolgt: Bool?
    public var verzoegerungMin: Int?
    public var kontaktMin: Int
    public var kw: [Double?]

    public enum CodingKeys: String, CodingKey {
        case at
        case liefSchon = "lief_schon"
        case auswertbar
        case gefolgt
        case verzoegerungMin = "verzoegerung_min"
        case kontaktMin = "kontakt_min"
        case kw
    }

    public init(at: String, liefSchon: Bool, auswertbar: Bool, gefolgt: Bool? = nil, verzoegerungMin: Int? = nil, kontaktMin: Int, kw: [Double?] = []) {
        self.at = at
        self.liefSchon = liefSchon
        self.auswertbar = auswertbar
        self.gefolgt = gefolgt
        self.verzoegerungMin = verzoegerungMin
        self.kontaktMin = kontaktMin
        self.kw = kw
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.liefSchon = try c.decode(Bool.self, forKey: .liefSchon)
        self.auswertbar = try c.decode(Bool.self, forKey: .auswertbar)
        self.gefolgt = try c.decodeIfPresent(Bool.self, forKey: .gefolgt)
        self.verzoegerungMin = try c.decodeIfPresent(Int.self, forKey: .verzoegerungMin)
        self.kontaktMin = try c.decode(Int.self, forKey: .kontaktMin)
        self.kw = try c.decodeIfPresent([Double?].self, forKey: .kw) ?? []
    }
}

public struct EvReportOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var summary: EnergySummaryOut
    public var sessions: [EvSessionOut]

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case summary
        case sessions
    }

    public init(generatedAt: String, summary: EnergySummaryOut, sessions: [EvSessionOut] = []) {
        self.generatedAt = generatedAt
        self.summary = summary
        self.sessions = sessions
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.summary = try c.decode(EnergySummaryOut.self, forKey: .summary)
        self.sessions = try c.decodeIfPresent([EvSessionOut].self, forKey: .sessions) ?? []
    }
}

public struct EvSessionOut: Codable, Sendable, Hashable {
    public var start: String
    public var end: String
    public var kwh: Double
    public var pvShare: Double?
    public var gridKwh: Double
    public var costEur: Double
    public var avgKw: Double

    public enum CodingKeys: String, CodingKey {
        case start
        case end
        case kwh
        case pvShare = "pv_share"
        case gridKwh = "grid_kwh"
        case costEur = "cost_eur"
        case avgKw = "avg_kw"
    }

    public init(start: String, end: String, kwh: Double, pvShare: Double? = nil, gridKwh: Double, costEur: Double, avgKw: Double) {
        self.start = start
        self.end = end
        self.kwh = kwh
        self.pvShare = pvShare
        self.gridKwh = gridKwh
        self.costEur = costEur
        self.avgKw = avgKw
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.kwh = try c.decode(Double.self, forKey: .kwh)
        self.pvShare = try c.decodeIfPresent(Double.self, forKey: .pvShare)
        self.gridKwh = try c.decode(Double.self, forKey: .gridKwh)
        self.costEur = try c.decode(Double.self, forKey: .costEur)
        self.avgKw = try c.decode(Double.self, forKey: .avgKw)
    }
}

/// Alle auswertbaren Ereignisse übereinandergelegt, je Minute relativ zum Schließen.
public struct Faecher: Codable, Sendable, Hashable {
    public var minuten: [Int]
    public var mittelKw: [Double?]
    public var medianKw: [Double?]
    public var q25Kw: [Double?]
    public var q75Kw: [Double?]
    public var anteilLaeuft: [Double?]
    public var n: [Int]
    public var anteilAngelaufen: [Double?]

    public enum CodingKeys: String, CodingKey {
        case minuten
        case mittelKw = "mittel_kw"
        case medianKw = "median_kw"
        case q25Kw = "q25_kw"
        case q75Kw = "q75_kw"
        case anteilLaeuft = "anteil_laeuft"
        case n
        case anteilAngelaufen = "anteil_angelaufen"
    }

    public init(minuten: [Int] = [], mittelKw: [Double?] = [], medianKw: [Double?] = [], q25Kw: [Double?] = [], q75Kw: [Double?] = [], anteilLaeuft: [Double?] = [], n: [Int] = [], anteilAngelaufen: [Double?] = []) {
        self.minuten = minuten
        self.mittelKw = mittelKw
        self.medianKw = medianKw
        self.q25Kw = q25Kw
        self.q75Kw = q75Kw
        self.anteilLaeuft = anteilLaeuft
        self.n = n
        self.anteilAngelaufen = anteilAngelaufen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.minuten = try c.decodeIfPresent([Int].self, forKey: .minuten) ?? []
        self.mittelKw = try c.decodeIfPresent([Double?].self, forKey: .mittelKw) ?? []
        self.medianKw = try c.decodeIfPresent([Double?].self, forKey: .medianKw) ?? []
        self.q25Kw = try c.decodeIfPresent([Double?].self, forKey: .q25Kw) ?? []
        self.q75Kw = try c.decodeIfPresent([Double?].self, forKey: .q75Kw) ?? []
        self.anteilLaeuft = try c.decodeIfPresent([Double?].self, forKey: .anteilLaeuft) ?? []
        self.n = try c.decodeIfPresent([Int].self, forKey: .n) ?? []
        self.anteilAngelaufen = try c.decodeIfPresent([Double?].self, forKey: .anteilAngelaufen) ?? []
    }
}

public struct ForecastDayOut: Codable, Sendable, Hashable {
    public var day: String
    public var issuedAt: String?
    public var score: ForecastScore?
    public var points: [ForecastPointOut]

    public enum CodingKeys: String, CodingKey {
        case day
        case issuedAt = "issued_at"
        case score
        case points
    }

    public init(day: String, issuedAt: String? = nil, score: ForecastScore? = nil, points: [ForecastPointOut] = []) {
        self.day = day
        self.issuedAt = issuedAt
        self.score = score
        self.points = points
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try c.decode(String.self, forKey: .day)
        self.issuedAt = try c.decodeIfPresent(String.self, forKey: .issuedAt)
        self.score = try c.decodeIfPresent(ForecastScore.self, forKey: .score)
        self.points = try c.decodeIfPresent([ForecastPointOut].self, forKey: .points) ?? []
    }
}

public struct ForecastEvaluationOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var stageDe: String
    public var sources: [SourceOut]
    public var today: ForecastDayOut
    public var yesterday: ForecastDayOut
    public var daily: [DailyScoreOut]
    public var horizons: [HorizonScoreOut]
    public var corrector: CorrectorState
    public var correctionActive: Bool
    public var nextChangesDe: [String]
    public var runsKept: Int
    public var notesDe: [String]

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case stageDe = "stage_de"
        case sources
        case today
        case yesterday
        case daily
        case horizons
        case corrector
        case correctionActive = "correction_active"
        case nextChangesDe = "next_changes_de"
        case runsKept = "runs_kept"
        case notesDe = "notes_de"
    }

    public init(generatedAt: String, stageDe: String, sources: [SourceOut] = [], today: ForecastDayOut, yesterday: ForecastDayOut, daily: [DailyScoreOut] = [], horizons: [HorizonScoreOut] = [], corrector: CorrectorState, correctionActive: Bool, nextChangesDe: [String] = [], runsKept: Int, notesDe: [String] = []) {
        self.generatedAt = generatedAt
        self.stageDe = stageDe
        self.sources = sources
        self.today = today
        self.yesterday = yesterday
        self.daily = daily
        self.horizons = horizons
        self.corrector = corrector
        self.correctionActive = correctionActive
        self.nextChangesDe = nextChangesDe
        self.runsKept = runsKept
        self.notesDe = notesDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.stageDe = try c.decode(String.self, forKey: .stageDe)
        self.sources = try c.decodeIfPresent([SourceOut].self, forKey: .sources) ?? []
        self.today = try c.decode(ForecastDayOut.self, forKey: .today)
        self.yesterday = try c.decode(ForecastDayOut.self, forKey: .yesterday)
        self.daily = try c.decodeIfPresent([DailyScoreOut].self, forKey: .daily) ?? []
        self.horizons = try c.decodeIfPresent([HorizonScoreOut].self, forKey: .horizons) ?? []
        self.corrector = try c.decode(CorrectorState.self, forKey: .corrector)
        self.correctionActive = try c.decode(Bool.self, forKey: .correctionActive)
        self.nextChangesDe = try c.decodeIfPresent([String].self, forKey: .nextChangesDe) ?? []
        self.runsKept = try c.decode(Int.self, forKey: .runsKept)
        self.notesDe = try c.decodeIfPresent([String].self, forKey: .notesDe) ?? []
    }
}

/// Der Rückblick aus dem dauerhaften Archiv: Fehler je Reihe und je Vorlaufzeit.
///
/// Etwas anderes als `ForecastEvaluationOut`: dort steht, was der Bewerter im Arbeitsspeicher hält
/// (PV, gestern und heute), hier, was in `forecast_runs` liegt - mehrere Tage, und auch die
/// Außentemperatur, an der im Modell v1 der ganze Wärmebedarf hängt.
public struct ForecastHistoryOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var von: String
    public var bis: String
    public var tage: Int
    public var reihen: [ReiheOut]
    public var hinweiseDe: [String]

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case von
        case bis
        case tage
        case reihen
        case hinweiseDe = "hinweise_de"
    }

    public init(generatedAt: String, von: String, bis: String, tage: Int, reihen: [ReiheOut] = [], hinweiseDe: [String] = []) {
        self.generatedAt = generatedAt
        self.von = von
        self.bis = bis
        self.tage = tage
        self.reihen = reihen
        self.hinweiseDe = hinweiseDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.von = try c.decode(String.self, forKey: .von)
        self.bis = try c.decode(String.self, forKey: .bis)
        self.tage = try c.decode(Int.self, forKey: .tage)
        self.reihen = try c.decodeIfPresent([ReiheOut].self, forKey: .reihen) ?? []
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
    }
}

public struct ForecastPointOut: Codable, Sendable, Hashable {
    public var ts: String
    public var actualKw: Double?
    public var dayAheadKw: Double?
    public var latestKw: Double?
    public var correctedKw: Double?

    public enum CodingKeys: String, CodingKey {
        case ts
        case actualKw = "actual_kw"
        case dayAheadKw = "day_ahead_kw"
        case latestKw = "latest_kw"
        case correctedKw = "corrected_kw"
    }

    public init(ts: String, actualKw: Double? = nil, dayAheadKw: Double? = nil, latestKw: Double? = nil, correctedKw: Double? = nil) {
        self.ts = ts
        self.actualKw = actualKw
        self.dayAheadKw = dayAheadKw
        self.latestKw = latestKw
        self.correctedKw = correctedKw
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts = try c.decode(String.self, forKey: .ts)
        self.actualKw = try c.decodeIfPresent(Double.self, forKey: .actualKw)
        self.dayAheadKw = try c.decodeIfPresent(Double.self, forKey: .dayAheadKw)
        self.latestKw = try c.decodeIfPresent(Double.self, forKey: .latestKw)
        self.correctedKw = try c.decodeIfPresent(Double.self, forKey: .correctedKw)
    }
}

public struct ForecastScore: Codable, Sendable, Hashable {
    public var n: Int
    public var maeKw: Double
    public var biasKw: Double
    public var rmseKw: Double
    public var energyForecastKwh: Double
    public var energyActualKwh: Double
    public var energyErrorPct: Double?

    public enum CodingKeys: String, CodingKey {
        case n
        case maeKw = "mae_kw"
        case biasKw = "bias_kw"
        case rmseKw = "rmse_kw"
        case energyForecastKwh = "energy_forecast_kwh"
        case energyActualKwh = "energy_actual_kwh"
        case energyErrorPct = "energy_error_pct"
    }

    public init(n: Int, maeKw: Double, biasKw: Double, rmseKw: Double, energyForecastKwh: Double, energyActualKwh: Double, energyErrorPct: Double? = nil) {
        self.n = n
        self.maeKw = maeKw
        self.biasKw = biasKw
        self.rmseKw = rmseKw
        self.energyForecastKwh = energyForecastKwh
        self.energyActualKwh = energyActualKwh
        self.energyErrorPct = energyErrorPct
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.n = try c.decode(Int.self, forKey: .n)
        self.maeKw = try c.decode(Double.self, forKey: .maeKw)
        self.biasKw = try c.decode(Double.self, forKey: .biasKw)
        self.rmseKw = try c.decode(Double.self, forKey: .rmseKw)
        self.energyForecastKwh = try c.decode(Double.self, forKey: .energyForecastKwh)
        self.energyActualKwh = try c.decode(Double.self, forKey: .energyActualKwh)
        self.energyErrorPct = try c.decodeIfPresent(Double.self, forKey: .energyErrorPct)
    }
}

/// Was das Modell gelesen hat, nach Pruefung der Typen.
public struct GeleseneRechnung: Codable, Sendable, Hashable {
    public var anbieter: String?
    public var von: String?
    public var bis: String?
    public var kwh: Double?
    public var arbeitspreisCtKwh: Double?
    public var grundpreisEurMonat: Double?
    public var bruttoEur: Double?
    public var nettoEur: Double?

    public enum CodingKeys: String, CodingKey {
        case anbieter
        case von
        case bis
        case kwh
        case arbeitspreisCtKwh = "arbeitspreis_ct_kwh"
        case grundpreisEurMonat = "grundpreis_eur_monat"
        case bruttoEur = "brutto_eur"
        case nettoEur = "netto_eur"
    }

    public init(anbieter: String? = nil, von: String? = nil, bis: String? = nil, kwh: Double? = nil, arbeitspreisCtKwh: Double? = nil, grundpreisEurMonat: Double? = nil, bruttoEur: Double? = nil, nettoEur: Double? = nil) {
        self.anbieter = anbieter
        self.von = von
        self.bis = bis
        self.kwh = kwh
        self.arbeitspreisCtKwh = arbeitspreisCtKwh
        self.grundpreisEurMonat = grundpreisEurMonat
        self.bruttoEur = bruttoEur
        self.nettoEur = nettoEur
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.anbieter = try c.decodeIfPresent(String.self, forKey: .anbieter)
        self.von = try c.decodeIfPresent(String.self, forKey: .von)
        self.bis = try c.decodeIfPresent(String.self, forKey: .bis)
        self.kwh = try c.decodeIfPresent(Double.self, forKey: .kwh)
        self.arbeitspreisCtKwh = try c.decodeIfPresent(Double.self, forKey: .arbeitspreisCtKwh)
        self.grundpreisEurMonat = try c.decodeIfPresent(Double.self, forKey: .grundpreisEurMonat)
        self.bruttoEur = try c.decodeIfPresent(Double.self, forKey: .bruttoEur)
        self.nettoEur = try c.decodeIfPresent(Double.self, forKey: .nettoEur)
    }
}

public struct GeraetAktionIn: Codable, Sendable, Hashable {
    public var aktion: GeraetAktionInAktionWahl
    public var dienst: String?

    public init(aktion: GeraetAktionInAktionWahl, dienst: String? = nil) {
        self.aktion = aktion
        self.dienst = dienst
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aktion = try c.decode(GeraetAktionInAktionWahl.self, forKey: .aktion)
        self.dienst = try c.decodeIfPresent(String.self, forKey: .dienst)
    }
}

/// Die zuletzt aus der App angefragte Aktion und wie sie ausging.
public struct GeraetAktionOut: Codable, Sendable, Hashable {
    public var aktion: String
    public var dienst: String?
    public var zustand: String
    public var meldung: String?
    public var von: String?
    public var begonnenAm: String?
    public var beendetAm: String?

    public enum CodingKeys: String, CodingKey {
        case aktion
        case dienst
        case zustand
        case meldung
        case von
        case begonnenAm = "begonnen_am"
        case beendetAm = "beendet_am"
    }

    public init(aktion: String, dienst: String? = nil, zustand: String, meldung: String? = nil, von: String? = nil, begonnenAm: String? = nil, beendetAm: String? = nil) {
        self.aktion = aktion
        self.dienst = dienst
        self.zustand = zustand
        self.meldung = meldung
        self.von = von
        self.begonnenAm = begonnenAm
        self.beendetAm = beendetAm
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aktion = try c.decode(String.self, forKey: .aktion)
        self.dienst = try c.decodeIfPresent(String.self, forKey: .dienst)
        self.zustand = try c.decode(String.self, forKey: .zustand)
        self.meldung = try c.decodeIfPresent(String.self, forKey: .meldung)
        self.von = try c.decodeIfPresent(String.self, forKey: .von)
        self.begonnenAm = try c.decodeIfPresent(String.self, forKey: .begonnenAm)
        self.beendetAm = try c.decodeIfPresent(String.self, forKey: .beendetAm)
    }
}

/// Ein Container des Geräts (postgres, api, web, caddy, cloudflared).
public struct GeraetDienstOut: Codable, Sendable, Hashable {
    public var name: String
    public var zustand: String
    public var gesundheit: String?
    public var pruefung: String?
    public var pruefungFehlschlaege: Int?
    public var gestartetAm: String?
    public var neustarts: Int?
    public var exitCode: Int?
    public var image: String?
    public var revision: String?
    public var cpuProzent: Double?
    public var speicherMb: Double?
    public var ampel: GeraetDienstOutAmpelWahl?
    public var textDe: String?

    public enum CodingKeys: String, CodingKey {
        case name
        case zustand
        case gesundheit
        case pruefung
        case pruefungFehlschlaege = "pruefung_fehlschlaege"
        case gestartetAm = "gestartet_am"
        case neustarts
        case exitCode = "exit_code"
        case image
        case revision
        case cpuProzent = "cpu_prozent"
        case speicherMb = "speicher_mb"
        case ampel
        case textDe = "text_de"
    }

    public init(name: String, zustand: String, gesundheit: String? = nil, pruefung: String? = nil, pruefungFehlschlaege: Int? = nil, gestartetAm: String? = nil, neustarts: Int? = nil, exitCode: Int? = nil, image: String? = nil, revision: String? = nil, cpuProzent: Double? = nil, speicherMb: Double? = nil, ampel: GeraetDienstOutAmpelWahl? = nil, textDe: String? = nil) {
        self.name = name
        self.zustand = zustand
        self.gesundheit = gesundheit
        self.pruefung = pruefung
        self.pruefungFehlschlaege = pruefungFehlschlaege
        self.gestartetAm = gestartetAm
        self.neustarts = neustarts
        self.exitCode = exitCode
        self.image = image
        self.revision = revision
        self.cpuProzent = cpuProzent
        self.speicherMb = speicherMb
        self.ampel = ampel
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.zustand = try c.decode(String.self, forKey: .zustand)
        self.gesundheit = try c.decodeIfPresent(String.self, forKey: .gesundheit)
        self.pruefung = try c.decodeIfPresent(String.self, forKey: .pruefung)
        self.pruefungFehlschlaege = try c.decodeIfPresent(Int.self, forKey: .pruefungFehlschlaege)
        self.gestartetAm = try c.decodeIfPresent(String.self, forKey: .gestartetAm)
        self.neustarts = try c.decodeIfPresent(Int.self, forKey: .neustarts)
        self.exitCode = try c.decodeIfPresent(Int.self, forKey: .exitCode)
        self.image = try c.decodeIfPresent(String.self, forKey: .image)
        self.revision = try c.decodeIfPresent(String.self, forKey: .revision)
        self.cpuProzent = try c.decodeIfPresent(Double.self, forKey: .cpuProzent)
        self.speicherMb = try c.decodeIfPresent(Double.self, forKey: .speicherMb)
        self.ampel = try c.decodeIfPresent(GeraetDienstOutAmpelWahl.self, forKey: .ampel)
        self.textDe = try c.decodeIfPresent(String.self, forKey: .textDe)
    }
}

public struct GeraetDockerPlatzOut: Codable, Sendable, Hashable {
    public var imagesBytes: Int?
    public var containerBytes: Int?
    public var volumesBytes: Int?
    public var cacheBytes: Int?

    public enum CodingKeys: String, CodingKey {
        case imagesBytes = "images_bytes"
        case containerBytes = "container_bytes"
        case volumesBytes = "volumes_bytes"
        case cacheBytes = "cache_bytes"
    }

    public init(imagesBytes: Int? = nil, containerBytes: Int? = nil, volumesBytes: Int? = nil, cacheBytes: Int? = nil) {
        self.imagesBytes = imagesBytes
        self.containerBytes = containerBytes
        self.volumesBytes = volumesBytes
        self.cacheBytes = cacheBytes
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.imagesBytes = try c.decodeIfPresent(Int.self, forKey: .imagesBytes)
        self.containerBytes = try c.decodeIfPresent(Int.self, forKey: .containerBytes)
        self.volumesBytes = try c.decodeIfPresent(Int.self, forKey: .volumesBytes)
        self.cacheBytes = try c.decodeIfPresent(Int.self, forKey: .cacheBytes)
    }
}

/// Ein systemd-Dienst oder -Zeitgeber des Geräts (Start, Sicherung, Updates, Bericht).
public struct GeraetEinheitOut: Codable, Sendable, Hashable {
    public var name: String
    public var beschreibung: String?
    public var aktiv: String?
    public var unterzustand: String?
    public var eingeschaltet: Bool?
    public var naechsterLauf: String?
    public var ampel: GeraetEinheitOutAmpelWahl?
    public var textDe: String?

    public enum CodingKeys: String, CodingKey {
        case name
        case beschreibung
        case aktiv
        case unterzustand
        case eingeschaltet
        case naechsterLauf = "naechster_lauf"
        case ampel
        case textDe = "text_de"
    }

    public init(name: String, beschreibung: String? = nil, aktiv: String? = nil, unterzustand: String? = nil, eingeschaltet: Bool? = nil, naechsterLauf: String? = nil, ampel: GeraetEinheitOutAmpelWahl? = nil, textDe: String? = nil) {
        self.name = name
        self.beschreibung = beschreibung
        self.aktiv = aktiv
        self.unterzustand = unterzustand
        self.eingeschaltet = eingeschaltet
        self.naechsterLauf = naechsterLauf
        self.ampel = ampel
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.beschreibung = try c.decodeIfPresent(String.self, forKey: .beschreibung)
        self.aktiv = try c.decodeIfPresent(String.self, forKey: .aktiv)
        self.unterzustand = try c.decodeIfPresent(String.self, forKey: .unterzustand)
        self.eingeschaltet = try c.decodeIfPresent(Bool.self, forKey: .eingeschaltet)
        self.naechsterLauf = try c.decodeIfPresent(String.self, forKey: .naechsterLauf)
        self.ampel = try c.decodeIfPresent(GeraetEinheitOutAmpelWahl.self, forKey: .ampel)
        self.textDe = try c.decodeIfPresent(String.self, forKey: .textDe)
    }
}

public struct GeraetNetzOut: Codable, Sendable, Hashable {
    public var schnittstelle: String
    public var empfangenBytes: Int
    public var gesendetBytes: Int

    public enum CodingKeys: String, CodingKey {
        case schnittstelle
        case empfangenBytes = "empfangen_bytes"
        case gesendetBytes = "gesendet_bytes"
    }

    public init(schnittstelle: String, empfangenBytes: Int, gesendetBytes: Int) {
        self.schnittstelle = schnittstelle
        self.empfangenBytes = empfangenBytes
        self.gesendetBytes = gesendetBytes
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schnittstelle = try c.decode(String.self, forKey: .schnittstelle)
        self.empfangenBytes = try c.decode(Int.self, forKey: .empfangenBytes)
        self.gesendetBytes = try c.decode(Int.self, forKey: .gesendetBytes)
    }
}

/// Die Seite Hausgerät: Rechner, Dienste, Zeitgeber, Sicherung, API und die letzte Aktion.
public struct GeraetOut: Codable, Sendable, Hashable {
    public var unterstuetzt: Bool
    public var berichtAm: String?
    public var berichtAlt: Bool?
    public var kanal: String?
    public var fernzugang: Bool?
    public var dockerLaeuft: Bool?
    public var rechner: GeraetRechnerOut?
    public var dienste: [GeraetDienstOut]
    public var einheiten: [GeraetEinheitOut]
    public var sicherung: GeraetSicherungOut?
    public var letzteAktion: GeraetAktionOut?
    public var beschaeftigt: String?
    public var api: ApiSelbstOut
    public var ampel: GeraetOutAmpelWahl?
    public var textDe: String?

    public enum CodingKeys: String, CodingKey {
        case unterstuetzt
        case berichtAm = "bericht_am"
        case berichtAlt = "bericht_alt"
        case kanal
        case fernzugang
        case dockerLaeuft = "docker_laeuft"
        case rechner
        case dienste
        case einheiten
        case sicherung
        case letzteAktion = "letzte_aktion"
        case beschaeftigt
        case api
        case ampel
        case textDe = "text_de"
    }

    public init(unterstuetzt: Bool, berichtAm: String? = nil, berichtAlt: Bool? = nil, kanal: String? = nil, fernzugang: Bool? = nil, dockerLaeuft: Bool? = nil, rechner: GeraetRechnerOut? = nil, dienste: [GeraetDienstOut] = [], einheiten: [GeraetEinheitOut] = [], sicherung: GeraetSicherungOut? = nil, letzteAktion: GeraetAktionOut? = nil, beschaeftigt: String? = nil, api: ApiSelbstOut, ampel: GeraetOutAmpelWahl? = nil, textDe: String? = nil) {
        self.unterstuetzt = unterstuetzt
        self.berichtAm = berichtAm
        self.berichtAlt = berichtAlt
        self.kanal = kanal
        self.fernzugang = fernzugang
        self.dockerLaeuft = dockerLaeuft
        self.rechner = rechner
        self.dienste = dienste
        self.einheiten = einheiten
        self.sicherung = sicherung
        self.letzteAktion = letzteAktion
        self.beschaeftigt = beschaeftigt
        self.api = api
        self.ampel = ampel
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.unterstuetzt = try c.decode(Bool.self, forKey: .unterstuetzt)
        self.berichtAm = try c.decodeIfPresent(String.self, forKey: .berichtAm)
        self.berichtAlt = try c.decodeIfPresent(Bool.self, forKey: .berichtAlt)
        self.kanal = try c.decodeIfPresent(String.self, forKey: .kanal)
        self.fernzugang = try c.decodeIfPresent(Bool.self, forKey: .fernzugang)
        self.dockerLaeuft = try c.decodeIfPresent(Bool.self, forKey: .dockerLaeuft)
        self.rechner = try c.decodeIfPresent(GeraetRechnerOut.self, forKey: .rechner)
        self.dienste = try c.decodeIfPresent([GeraetDienstOut].self, forKey: .dienste) ?? []
        self.einheiten = try c.decodeIfPresent([GeraetEinheitOut].self, forKey: .einheiten) ?? []
        self.sicherung = try c.decodeIfPresent(GeraetSicherungOut.self, forKey: .sicherung)
        self.letzteAktion = try c.decodeIfPresent(GeraetAktionOut.self, forKey: .letzteAktion)
        self.beschaeftigt = try c.decodeIfPresent(String.self, forKey: .beschaeftigt)
        self.api = try c.decode(ApiSelbstOut.self, forKey: .api)
        self.ampel = try c.decodeIfPresent(GeraetOutAmpelWahl.self, forKey: .ampel)
        self.textDe = try c.decodeIfPresent(String.self, forKey: .textDe)
    }
}

public struct GeraetPlatteOut: Codable, Sendable, Hashable {
    public var ort: String
    public var gesamtBytes: Int
    public var freiBytes: Int
    public var ampel: GeraetPlatteOutAmpelWahl?

    public enum CodingKeys: String, CodingKey {
        case ort
        case gesamtBytes = "gesamt_bytes"
        case freiBytes = "frei_bytes"
        case ampel
    }

    public init(ort: String, gesamtBytes: Int, freiBytes: Int, ampel: GeraetPlatteOutAmpelWahl? = nil) {
        self.ort = ort
        self.gesamtBytes = gesamtBytes
        self.freiBytes = freiBytes
        self.ampel = ampel
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ort = try c.decode(String.self, forKey: .ort)
        self.gesamtBytes = try c.decode(Int.self, forKey: .gesamtBytes)
        self.freiBytes = try c.decode(Int.self, forKey: .freiBytes)
        self.ampel = try c.decodeIfPresent(GeraetPlatteOutAmpelWahl.self, forKey: .ampel)
    }
}

/// Wachstum je Tag über die letzten 30 Tage (eine Gerade durch die Füllstände), erst ab
/// sieben Tagen Verlauf. Eine Schätzung „bei diesem Tempo“, kein Termin.
public struct GeraetPrognoseOut: Codable, Sendable, Hashable {
    public var tageVerlauf: Double?
    public var platteBytesProTag: Int?
    public var platteVollInTagen: Int?
    public var datenbankBytesProTag: Int?
    public var sicherungBytesProTag: Int?
    public var ssdGeschriebenBytesProTag: Int?

    public enum CodingKeys: String, CodingKey {
        case tageVerlauf = "tage_verlauf"
        case platteBytesProTag = "platte_bytes_pro_tag"
        case platteVollInTagen = "platte_voll_in_tagen"
        case datenbankBytesProTag = "datenbank_bytes_pro_tag"
        case sicherungBytesProTag = "sicherung_bytes_pro_tag"
        case ssdGeschriebenBytesProTag = "ssd_geschrieben_bytes_pro_tag"
    }

    public init(tageVerlauf: Double? = nil, platteBytesProTag: Int? = nil, platteVollInTagen: Int? = nil, datenbankBytesProTag: Int? = nil, sicherungBytesProTag: Int? = nil, ssdGeschriebenBytesProTag: Int? = nil) {
        self.tageVerlauf = tageVerlauf
        self.platteBytesProTag = platteBytesProTag
        self.platteVollInTagen = platteVollInTagen
        self.datenbankBytesProTag = datenbankBytesProTag
        self.sicherungBytesProTag = sicherungBytesProTag
        self.ssdGeschriebenBytesProTag = ssdGeschriebenBytesProTag
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tageVerlauf = try c.decodeIfPresent(Double.self, forKey: .tageVerlauf)
        self.platteBytesProTag = try c.decodeIfPresent(Int.self, forKey: .platteBytesProTag)
        self.platteVollInTagen = try c.decodeIfPresent(Int.self, forKey: .platteVollInTagen)
        self.datenbankBytesProTag = try c.decodeIfPresent(Int.self, forKey: .datenbankBytesProTag)
        self.sicherungBytesProTag = try c.decodeIfPresent(Int.self, forKey: .sicherungBytesProTag)
        self.ssdGeschriebenBytesProTag = try c.decodeIfPresent(Int.self, forKey: .ssdGeschriebenBytesProTag)
    }
}

public struct GeraetProtokollOut: Codable, Sendable, Hashable {
    public var dienst: String
    public var vorhanden: Bool
    public var erstelltAm: String?
    public var zeilen: [String]

    public enum CodingKeys: String, CodingKey {
        case dienst
        case vorhanden
        case erstelltAm = "erstellt_am"
        case zeilen
    }

    public init(dienst: String, vorhanden: Bool, erstelltAm: String? = nil, zeilen: [String] = []) {
        self.dienst = dienst
        self.vorhanden = vorhanden
        self.erstelltAm = erstelltAm
        self.zeilen = zeilen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dienst = try c.decode(String.self, forKey: .dienst)
        self.vorhanden = try c.decode(Bool.self, forKey: .vorhanden)
        self.erstelltAm = try c.decodeIfPresent(String.self, forKey: .erstelltAm)
        self.zeilen = try c.decodeIfPresent([String].self, forKey: .zeilen) ?? []
    }
}

/// Der Rechner selbst: Raspberry Pi oder was sonst darunter läuft.
public struct GeraetRechnerOut: Codable, Sendable, Hashable {
    public var name: String?
    public var modell: String?
    public var system: String?
    public var kernel: String?
    public var adresse: String?
    public var zeitzone: String?
    public var zeitdienstAn: Bool?
    public var zeitSynchron: Bool?
    public var zeitDe: String?
    public var zeitAmpel: GeraetRechnerOutZeitAmpelWahl?
    public var laufzeitS: Int?
    public var kerne: Int?
    public var last: [Double]
    public var temperaturC: Double?
    public var temperaturAmpel: GeraetRechnerOutTemperaturAmpelWahl?
    public var drosselung: String?
    public var drosselungDe: [String]
    public var drosselungAmpel: GeraetRechnerOutDrosselungAmpelWahl?
    public var speicherGesamtMb: Int?
    public var speicherFreiMb: Int?
    public var speicherAmpel: GeraetRechnerOutSpeicherAmpelWahl?
    public var platten: [GeraetPlatteOut]
    public var docker: String?
    public var cpuProzent: Double?
    public var taktMhz: Double?
    public var eingangsspannungV: Double?
    public var spannungAmpel: GeraetRechnerOutSpannungAmpelWahl?
    public var swapGesamtMb: Int?
    public var swapFreiMb: Int?
    public var netz: GeraetNetzOut?
    public var ssd: GeraetSsdOut?
    public var dockerPlatz: GeraetDockerPlatzOut?

    public enum CodingKeys: String, CodingKey {
        case name
        case modell
        case system
        case kernel
        case adresse
        case zeitzone
        case zeitdienstAn = "zeitdienst_an"
        case zeitSynchron = "zeit_synchron"
        case zeitDe = "zeit_de"
        case zeitAmpel = "zeit_ampel"
        case laufzeitS = "laufzeit_s"
        case kerne
        case last
        case temperaturC = "temperatur_c"
        case temperaturAmpel = "temperatur_ampel"
        case drosselung
        case drosselungDe = "drosselung_de"
        case drosselungAmpel = "drosselung_ampel"
        case speicherGesamtMb = "speicher_gesamt_mb"
        case speicherFreiMb = "speicher_frei_mb"
        case speicherAmpel = "speicher_ampel"
        case platten
        case docker
        case cpuProzent = "cpu_prozent"
        case taktMhz = "takt_mhz"
        case eingangsspannungV = "eingangsspannung_v"
        case spannungAmpel = "spannung_ampel"
        case swapGesamtMb = "swap_gesamt_mb"
        case swapFreiMb = "swap_frei_mb"
        case netz
        case ssd
        case dockerPlatz = "docker_platz"
    }

    public init(name: String? = nil, modell: String? = nil, system: String? = nil, kernel: String? = nil, adresse: String? = nil, zeitzone: String? = nil, zeitdienstAn: Bool? = nil, zeitSynchron: Bool? = nil, zeitDe: String? = nil, zeitAmpel: GeraetRechnerOutZeitAmpelWahl? = nil, laufzeitS: Int? = nil, kerne: Int? = nil, last: [Double] = [], temperaturC: Double? = nil, temperaturAmpel: GeraetRechnerOutTemperaturAmpelWahl? = nil, drosselung: String? = nil, drosselungDe: [String] = [], drosselungAmpel: GeraetRechnerOutDrosselungAmpelWahl? = nil, speicherGesamtMb: Int? = nil, speicherFreiMb: Int? = nil, speicherAmpel: GeraetRechnerOutSpeicherAmpelWahl? = nil, platten: [GeraetPlatteOut] = [], docker: String? = nil, cpuProzent: Double? = nil, taktMhz: Double? = nil, eingangsspannungV: Double? = nil, spannungAmpel: GeraetRechnerOutSpannungAmpelWahl? = nil, swapGesamtMb: Int? = nil, swapFreiMb: Int? = nil, netz: GeraetNetzOut? = nil, ssd: GeraetSsdOut? = nil, dockerPlatz: GeraetDockerPlatzOut? = nil) {
        self.name = name
        self.modell = modell
        self.system = system
        self.kernel = kernel
        self.adresse = adresse
        self.zeitzone = zeitzone
        self.zeitdienstAn = zeitdienstAn
        self.zeitSynchron = zeitSynchron
        self.zeitDe = zeitDe
        self.zeitAmpel = zeitAmpel
        self.laufzeitS = laufzeitS
        self.kerne = kerne
        self.last = last
        self.temperaturC = temperaturC
        self.temperaturAmpel = temperaturAmpel
        self.drosselung = drosselung
        self.drosselungDe = drosselungDe
        self.drosselungAmpel = drosselungAmpel
        self.speicherGesamtMb = speicherGesamtMb
        self.speicherFreiMb = speicherFreiMb
        self.speicherAmpel = speicherAmpel
        self.platten = platten
        self.docker = docker
        self.cpuProzent = cpuProzent
        self.taktMhz = taktMhz
        self.eingangsspannungV = eingangsspannungV
        self.spannungAmpel = spannungAmpel
        self.swapGesamtMb = swapGesamtMb
        self.swapFreiMb = swapFreiMb
        self.netz = netz
        self.ssd = ssd
        self.dockerPlatz = dockerPlatz
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.modell = try c.decodeIfPresent(String.self, forKey: .modell)
        self.system = try c.decodeIfPresent(String.self, forKey: .system)
        self.kernel = try c.decodeIfPresent(String.self, forKey: .kernel)
        self.adresse = try c.decodeIfPresent(String.self, forKey: .adresse)
        self.zeitzone = try c.decodeIfPresent(String.self, forKey: .zeitzone)
        self.zeitdienstAn = try c.decodeIfPresent(Bool.self, forKey: .zeitdienstAn)
        self.zeitSynchron = try c.decodeIfPresent(Bool.self, forKey: .zeitSynchron)
        self.zeitDe = try c.decodeIfPresent(String.self, forKey: .zeitDe)
        self.zeitAmpel = try c.decodeIfPresent(GeraetRechnerOutZeitAmpelWahl.self, forKey: .zeitAmpel)
        self.laufzeitS = try c.decodeIfPresent(Int.self, forKey: .laufzeitS)
        self.kerne = try c.decodeIfPresent(Int.self, forKey: .kerne)
        self.last = try c.decodeIfPresent([Double].self, forKey: .last) ?? []
        self.temperaturC = try c.decodeIfPresent(Double.self, forKey: .temperaturC)
        self.temperaturAmpel = try c.decodeIfPresent(GeraetRechnerOutTemperaturAmpelWahl.self, forKey: .temperaturAmpel)
        self.drosselung = try c.decodeIfPresent(String.self, forKey: .drosselung)
        self.drosselungDe = try c.decodeIfPresent([String].self, forKey: .drosselungDe) ?? []
        self.drosselungAmpel = try c.decodeIfPresent(GeraetRechnerOutDrosselungAmpelWahl.self, forKey: .drosselungAmpel)
        self.speicherGesamtMb = try c.decodeIfPresent(Int.self, forKey: .speicherGesamtMb)
        self.speicherFreiMb = try c.decodeIfPresent(Int.self, forKey: .speicherFreiMb)
        self.speicherAmpel = try c.decodeIfPresent(GeraetRechnerOutSpeicherAmpelWahl.self, forKey: .speicherAmpel)
        self.platten = try c.decodeIfPresent([GeraetPlatteOut].self, forKey: .platten) ?? []
        self.docker = try c.decodeIfPresent(String.self, forKey: .docker)
        self.cpuProzent = try c.decodeIfPresent(Double.self, forKey: .cpuProzent)
        self.taktMhz = try c.decodeIfPresent(Double.self, forKey: .taktMhz)
        self.eingangsspannungV = try c.decodeIfPresent(Double.self, forKey: .eingangsspannungV)
        self.spannungAmpel = try c.decodeIfPresent(GeraetRechnerOutSpannungAmpelWahl.self, forKey: .spannungAmpel)
        self.swapGesamtMb = try c.decodeIfPresent(Int.self, forKey: .swapGesamtMb)
        self.swapFreiMb = try c.decodeIfPresent(Int.self, forKey: .swapFreiMb)
        self.netz = try c.decodeIfPresent(GeraetNetzOut.self, forKey: .netz)
        self.ssd = try c.decodeIfPresent(GeraetSsdOut.self, forKey: .ssd)
        self.dockerPlatz = try c.decodeIfPresent(GeraetDockerPlatzOut.self, forKey: .dockerPlatz)
    }
}

public struct GeraetSicherungOut: Codable, Sendable, Hashable {
    public var letzte: String?
    public var letzteAm: String?
    public var letzteBytes: Int?
    public var anzahl: Int?
    public var gesamtBytes: Int?
    public var ausserHaus: String?
    public var ampel: GeraetSicherungOutAmpelWahl?
    public var textDe: String?

    public enum CodingKeys: String, CodingKey {
        case letzte
        case letzteAm = "letzte_am"
        case letzteBytes = "letzte_bytes"
        case anzahl
        case gesamtBytes = "gesamt_bytes"
        case ausserHaus = "ausser_haus"
        case ampel
        case textDe = "text_de"
    }

    public init(letzte: String? = nil, letzteAm: String? = nil, letzteBytes: Int? = nil, anzahl: Int? = nil, gesamtBytes: Int? = nil, ausserHaus: String? = nil, ampel: GeraetSicherungOutAmpelWahl? = nil, textDe: String? = nil) {
        self.letzte = letzte
        self.letzteAm = letzteAm
        self.letzteBytes = letzteBytes
        self.anzahl = anzahl
        self.gesamtBytes = gesamtBytes
        self.ausserHaus = ausserHaus
        self.ampel = ampel
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.letzte = try c.decodeIfPresent(String.self, forKey: .letzte)
        self.letzteAm = try c.decodeIfPresent(String.self, forKey: .letzteAm)
        self.letzteBytes = try c.decodeIfPresent(Int.self, forKey: .letzteBytes)
        self.anzahl = try c.decodeIfPresent(Int.self, forKey: .anzahl)
        self.gesamtBytes = try c.decodeIfPresent(Int.self, forKey: .gesamtBytes)
        self.ausserHaus = try c.decodeIfPresent(String.self, forKey: .ausserHaus)
        self.ampel = try c.decodeIfPresent(GeraetSicherungOutAmpelWahl.self, forKey: .ampel)
        self.textDe = try c.decodeIfPresent(String.self, forKey: .textDe)
    }
}

/// SMART der Platte, auf der das System liegt. NVMe meldet alles; eine Platte am USB-Adapter
/// oft nur Temperatur und Betriebsstunden.
public struct GeraetSsdOut: Codable, Sendable, Hashable {
    public var geraet: String
    public var modell: String?
    public var gesund: Bool?
    public var temperaturC: Double?
    public var betriebsstunden: Int?
    public var abnutzungProzent: Double?
    public var reserveProzent: Double?
    public var geschriebenBytes: Int?
    public var gelesenBytes: Int?
    public var fehler: Int?
    public var unsichereAbschaltungen: Int?
    public var ampel: GeraetSsdOutAmpelWahl?
    public var textDe: String?

    public enum CodingKeys: String, CodingKey {
        case geraet
        case modell
        case gesund
        case temperaturC = "temperatur_c"
        case betriebsstunden
        case abnutzungProzent = "abnutzung_prozent"
        case reserveProzent = "reserve_prozent"
        case geschriebenBytes = "geschrieben_bytes"
        case gelesenBytes = "gelesen_bytes"
        case fehler
        case unsichereAbschaltungen = "unsichere_abschaltungen"
        case ampel
        case textDe = "text_de"
    }

    public init(geraet: String, modell: String? = nil, gesund: Bool? = nil, temperaturC: Double? = nil, betriebsstunden: Int? = nil, abnutzungProzent: Double? = nil, reserveProzent: Double? = nil, geschriebenBytes: Int? = nil, gelesenBytes: Int? = nil, fehler: Int? = nil, unsichereAbschaltungen: Int? = nil, ampel: GeraetSsdOutAmpelWahl? = nil, textDe: String? = nil) {
        self.geraet = geraet
        self.modell = modell
        self.gesund = gesund
        self.temperaturC = temperaturC
        self.betriebsstunden = betriebsstunden
        self.abnutzungProzent = abnutzungProzent
        self.reserveProzent = reserveProzent
        self.geschriebenBytes = geschriebenBytes
        self.gelesenBytes = gelesenBytes
        self.fehler = fehler
        self.unsichereAbschaltungen = unsichereAbschaltungen
        self.ampel = ampel
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.geraet = try c.decode(String.self, forKey: .geraet)
        self.modell = try c.decodeIfPresent(String.self, forKey: .modell)
        self.gesund = try c.decodeIfPresent(Bool.self, forKey: .gesund)
        self.temperaturC = try c.decodeIfPresent(Double.self, forKey: .temperaturC)
        self.betriebsstunden = try c.decodeIfPresent(Int.self, forKey: .betriebsstunden)
        self.abnutzungProzent = try c.decodeIfPresent(Double.self, forKey: .abnutzungProzent)
        self.reserveProzent = try c.decodeIfPresent(Double.self, forKey: .reserveProzent)
        self.geschriebenBytes = try c.decodeIfPresent(Int.self, forKey: .geschriebenBytes)
        self.gelesenBytes = try c.decodeIfPresent(Int.self, forKey: .gelesenBytes)
        self.fehler = try c.decodeIfPresent(Int.self, forKey: .fehler)
        self.unsichereAbschaltungen = try c.decodeIfPresent(Int.self, forKey: .unsichereAbschaltungen)
        self.ampel = try c.decodeIfPresent(GeraetSsdOutAmpelWahl.self, forKey: .ampel)
        self.textDe = try c.decodeIfPresent(String.self, forKey: .textDe)
    }
}

public struct GeraetVerlaufDienstOut: Codable, Sendable, Hashable {
    public var cpuProzent: Double?
    public var speicherMb: Double?

    public enum CodingKeys: String, CodingKey {
        case cpuProzent = "cpu_prozent"
        case speicherMb = "speicher_mb"
    }

    public init(cpuProzent: Double? = nil, speicherMb: Double? = nil) {
        self.cpuProzent = cpuProzent
        self.speicherMb = speicherMb
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.cpuProzent = try c.decodeIfPresent(Double.self, forKey: .cpuProzent)
        self.speicherMb = try c.decodeIfPresent(Double.self, forKey: .speicherMb)
    }
}

public struct GeraetVerlaufOut: Codable, Sendable, Hashable {
    public var unterstuetzt: Bool
    public var spanne: GeraetVerlaufOutSpanneWahl?
    public var von: String?
    public var bis: String?
    public var schrittMin: Int?
    public var punkte: [GeraetVerlaufPunktOut]
    public var prognose: GeraetPrognoseOut?

    public enum CodingKeys: String, CodingKey {
        case unterstuetzt
        case spanne
        case von
        case bis
        case schrittMin = "schritt_min"
        case punkte
        case prognose
    }

    public init(unterstuetzt: Bool, spanne: GeraetVerlaufOutSpanneWahl? = nil, von: String? = nil, bis: String? = nil, schrittMin: Int? = nil, punkte: [GeraetVerlaufPunktOut] = [], prognose: GeraetPrognoseOut? = nil) {
        self.unterstuetzt = unterstuetzt
        self.spanne = spanne
        self.von = von
        self.bis = bis
        self.schrittMin = schrittMin
        self.punkte = punkte
        self.prognose = prognose
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.unterstuetzt = try c.decode(Bool.self, forKey: .unterstuetzt)
        self.spanne = try c.decodeIfPresent(GeraetVerlaufOutSpanneWahl.self, forKey: .spanne)
        self.von = try c.decodeIfPresent(String.self, forKey: .von)
        self.bis = try c.decodeIfPresent(String.self, forKey: .bis)
        self.schrittMin = try c.decodeIfPresent(Int.self, forKey: .schrittMin)
        self.punkte = try c.decodeIfPresent([GeraetVerlaufPunktOut].self, forKey: .punkte) ?? []
        self.prognose = try c.decodeIfPresent(GeraetPrognoseOut.self, forKey: .prognose)
    }
}

/// Ein Abschnitt im Verlauf: Mittel, Spitzen und Stände am Ende des Abschnitts.
public struct GeraetVerlaufPunktOut: Codable, Sendable, Hashable {
    public var t: String
    public var cpuProzent: Double?
    public var cpuProzentMax: Double?
    public var last1: Double?
    public var temperaturC: Double?
    public var temperaturCMax: Double?
    public var taktMhz: Double?
    public var eingangsspannungV: Double?
    public var eingangsspannungVMin: Double?
    public var speicherBelegtMb: Double?
    public var speicherGesamtMb: Double?
    public var swapBelegtMb: Double?
    public var platteBelegtBytes: Int?
    public var platteGesamtBytes: Int?
    public var ssdTemperaturC: Double?
    public var ssdTemperaturCMax: Double?
    public var ssdAbnutzungProzent: Double?
    public var ssdGeschriebenBytes: Int?
    public var netzEmpfangenBytesS: Double?
    public var netzGesendetBytesS: Double?
    public var datenbankBytes: Int?
    public var sicherungBytes: Int?
    public var dockerBytes: Int?
    public var drosselungJetzt: Bool?
    public var dienste: [String: GeraetVerlaufDienstOut]

    public enum CodingKeys: String, CodingKey {
        case t
        case cpuProzent = "cpu_prozent"
        case cpuProzentMax = "cpu_prozent_max"
        case last1
        case temperaturC = "temperatur_c"
        case temperaturCMax = "temperatur_c_max"
        case taktMhz = "takt_mhz"
        case eingangsspannungV = "eingangsspannung_v"
        case eingangsspannungVMin = "eingangsspannung_v_min"
        case speicherBelegtMb = "speicher_belegt_mb"
        case speicherGesamtMb = "speicher_gesamt_mb"
        case swapBelegtMb = "swap_belegt_mb"
        case platteBelegtBytes = "platte_belegt_bytes"
        case platteGesamtBytes = "platte_gesamt_bytes"
        case ssdTemperaturC = "ssd_temperatur_c"
        case ssdTemperaturCMax = "ssd_temperatur_c_max"
        case ssdAbnutzungProzent = "ssd_abnutzung_prozent"
        case ssdGeschriebenBytes = "ssd_geschrieben_bytes"
        case netzEmpfangenBytesS = "netz_empfangen_bytes_s"
        case netzGesendetBytesS = "netz_gesendet_bytes_s"
        case datenbankBytes = "datenbank_bytes"
        case sicherungBytes = "sicherung_bytes"
        case dockerBytes = "docker_bytes"
        case drosselungJetzt = "drosselung_jetzt"
        case dienste
    }

    public init(t: String, cpuProzent: Double? = nil, cpuProzentMax: Double? = nil, last1: Double? = nil, temperaturC: Double? = nil, temperaturCMax: Double? = nil, taktMhz: Double? = nil, eingangsspannungV: Double? = nil, eingangsspannungVMin: Double? = nil, speicherBelegtMb: Double? = nil, speicherGesamtMb: Double? = nil, swapBelegtMb: Double? = nil, platteBelegtBytes: Int? = nil, platteGesamtBytes: Int? = nil, ssdTemperaturC: Double? = nil, ssdTemperaturCMax: Double? = nil, ssdAbnutzungProzent: Double? = nil, ssdGeschriebenBytes: Int? = nil, netzEmpfangenBytesS: Double? = nil, netzGesendetBytesS: Double? = nil, datenbankBytes: Int? = nil, sicherungBytes: Int? = nil, dockerBytes: Int? = nil, drosselungJetzt: Bool? = nil, dienste: [String: GeraetVerlaufDienstOut] = [:]) {
        self.t = t
        self.cpuProzent = cpuProzent
        self.cpuProzentMax = cpuProzentMax
        self.last1 = last1
        self.temperaturC = temperaturC
        self.temperaturCMax = temperaturCMax
        self.taktMhz = taktMhz
        self.eingangsspannungV = eingangsspannungV
        self.eingangsspannungVMin = eingangsspannungVMin
        self.speicherBelegtMb = speicherBelegtMb
        self.speicherGesamtMb = speicherGesamtMb
        self.swapBelegtMb = swapBelegtMb
        self.platteBelegtBytes = platteBelegtBytes
        self.platteGesamtBytes = platteGesamtBytes
        self.ssdTemperaturC = ssdTemperaturC
        self.ssdTemperaturCMax = ssdTemperaturCMax
        self.ssdAbnutzungProzent = ssdAbnutzungProzent
        self.ssdGeschriebenBytes = ssdGeschriebenBytes
        self.netzEmpfangenBytesS = netzEmpfangenBytesS
        self.netzGesendetBytesS = netzGesendetBytesS
        self.datenbankBytes = datenbankBytes
        self.sicherungBytes = sicherungBytes
        self.dockerBytes = dockerBytes
        self.drosselungJetzt = drosselungJetzt
        self.dienste = dienste
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.t = try c.decode(String.self, forKey: .t)
        self.cpuProzent = try c.decodeIfPresent(Double.self, forKey: .cpuProzent)
        self.cpuProzentMax = try c.decodeIfPresent(Double.self, forKey: .cpuProzentMax)
        self.last1 = try c.decodeIfPresent(Double.self, forKey: .last1)
        self.temperaturC = try c.decodeIfPresent(Double.self, forKey: .temperaturC)
        self.temperaturCMax = try c.decodeIfPresent(Double.self, forKey: .temperaturCMax)
        self.taktMhz = try c.decodeIfPresent(Double.self, forKey: .taktMhz)
        self.eingangsspannungV = try c.decodeIfPresent(Double.self, forKey: .eingangsspannungV)
        self.eingangsspannungVMin = try c.decodeIfPresent(Double.self, forKey: .eingangsspannungVMin)
        self.speicherBelegtMb = try c.decodeIfPresent(Double.self, forKey: .speicherBelegtMb)
        self.speicherGesamtMb = try c.decodeIfPresent(Double.self, forKey: .speicherGesamtMb)
        self.swapBelegtMb = try c.decodeIfPresent(Double.self, forKey: .swapBelegtMb)
        self.platteBelegtBytes = try c.decodeIfPresent(Int.self, forKey: .platteBelegtBytes)
        self.platteGesamtBytes = try c.decodeIfPresent(Int.self, forKey: .platteGesamtBytes)
        self.ssdTemperaturC = try c.decodeIfPresent(Double.self, forKey: .ssdTemperaturC)
        self.ssdTemperaturCMax = try c.decodeIfPresent(Double.self, forKey: .ssdTemperaturCMax)
        self.ssdAbnutzungProzent = try c.decodeIfPresent(Double.self, forKey: .ssdAbnutzungProzent)
        self.ssdGeschriebenBytes = try c.decodeIfPresent(Int.self, forKey: .ssdGeschriebenBytes)
        self.netzEmpfangenBytesS = try c.decodeIfPresent(Double.self, forKey: .netzEmpfangenBytesS)
        self.netzGesendetBytesS = try c.decodeIfPresent(Double.self, forKey: .netzGesendetBytesS)
        self.datenbankBytes = try c.decodeIfPresent(Int.self, forKey: .datenbankBytes)
        self.sicherungBytes = try c.decodeIfPresent(Int.self, forKey: .sicherungBytes)
        self.dockerBytes = try c.decodeIfPresent(Int.self, forKey: .dockerBytes)
        self.drosselungJetzt = try c.decodeIfPresent(Bool.self, forKey: .drosselungJetzt)
        self.dienste = try c.decodeIfPresent([String: GeraetVerlaufDienstOut].self, forKey: .dienste) ?? [:]
    }
}

/// Ein Übertragungsglied mit seinem Bild: Kurzzeichen, Name, Funktion, Sprungantwort.
///
/// Der Katalog steht einmal in der Antwort und nicht an jedem Block. Die Kurven sind auf das
/// Einheitsquadrat normiert - Form, keine Messung.
public struct GliedAnsicht: Codable, Sendable, Hashable {
    public var id: String
    public var kurz: String
    public var name: String
    public var gS: String
    public var art: GliedAnsichtArtWahl
    public var kategorie: GliedAnsichtKategorieWahl
    public var nichtlinear: Bool
    public var erkennen: String
    public var kurve: [[Double]]
    public var kurve2: [[Double]]

    public enum CodingKeys: String, CodingKey {
        case id
        case kurz
        case name
        case gS = "g_s"
        case art
        case kategorie
        case nichtlinear
        case erkennen
        case kurve
        case kurve2
    }

    public init(id: String, kurz: String, name: String, gS: String, art: GliedAnsichtArtWahl, kategorie: GliedAnsichtKategorieWahl, nichtlinear: Bool, erkennen: String, kurve: [[Double]] = [], kurve2: [[Double]] = []) {
        self.id = id
        self.kurz = kurz
        self.name = name
        self.gS = gS
        self.art = art
        self.kategorie = kategorie
        self.nichtlinear = nichtlinear
        self.erkennen = erkennen
        self.kurve = kurve
        self.kurve2 = kurve2
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.kurz = try c.decode(String.self, forKey: .kurz)
        self.name = try c.decode(String.self, forKey: .name)
        self.gS = try c.decode(String.self, forKey: .gS)
        self.art = try c.decode(GliedAnsichtArtWahl.self, forKey: .art)
        self.kategorie = try c.decode(GliedAnsichtKategorieWahl.self, forKey: .kategorie)
        self.nichtlinear = try c.decode(Bool.self, forKey: .nichtlinear)
        self.erkennen = try c.decode(String.self, forKey: .erkennen)
        self.kurve = try c.decodeIfPresent([[Double]].self, forKey: .kurve) ?? []
        self.kurve2 = try c.decodeIfPresent([[Double]].self, forKey: .kurve2) ?? []
    }
}

/// Der Restfehler eines Teilmodells gegen die Messung.
public struct GueteAnsicht: Codable, Sendable, Hashable {
    public var modell: String
    public var block: String
    public var einheit: String
    public var rmse: Double?
    public var n: Int
    public var quelle: String

    public init(modell: String, block: String, einheit: String, rmse: Double? = nil, n: Int, quelle: String) {
        self.modell = modell
        self.block = block
        self.einheit = einheit
        self.rmse = rmse
        self.n = n
        self.quelle = quelle
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.modell = try c.decode(String.self, forKey: .modell)
        self.block = try c.decode(String.self, forKey: .block)
        self.einheit = try c.decode(String.self, forKey: .einheit)
        self.rmse = try c.decodeIfPresent(Double.self, forKey: .rmse)
        self.n = try c.decode(Int.self, forKey: .n)
        self.quelle = try c.decode(String.self, forKey: .quelle)
    }
}

public struct HTTPValidationError: Codable, Sendable, Hashable {
    public var detail: [ValidationError]

    public init(detail: [ValidationError] = []) {
        self.detail = detail
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.detail = try c.decodeIfPresent([ValidationError].self, forKey: .detail) ?? []
    }
}

/// Etwas, das gerade von Hand gestellt ist und von der Automatik abweicht.
public struct HandeingriffOut: Codable, Sendable, Hashable {
    public var art: HandeingriffOutArtWahl
    public var weg: String
    public var satzDe: String
    public var bis: String?
    public var zuruecksetzbar: Bool?

    public enum CodingKeys: String, CodingKey {
        case art
        case weg
        case satzDe = "satz_de"
        case bis
        case zuruecksetzbar
    }

    public init(art: HandeingriffOutArtWahl, weg: String, satzDe: String, bis: String? = nil, zuruecksetzbar: Bool? = nil) {
        self.art = art
        self.weg = weg
        self.satzDe = satzDe
        self.bis = bis
        self.zuruecksetzbar = zuruecksetzbar
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(HandeingriffOutArtWahl.self, forKey: .art)
        self.weg = try c.decode(String.self, forKey: .weg)
        self.satzDe = try c.decode(String.self, forKey: .satzDe)
        self.bis = try c.decodeIfPresent(String.self, forKey: .bis)
        self.zuruecksetzbar = try c.decodeIfPresent(Bool.self, forKey: .zuruecksetzbar)
    }
}

/// Was gerade von Hand gestellt ist, oben auf der Seite „Einstellen“.
public struct HandeingriffeOut: Codable, Sendable, Hashable {
    public var eingriffe: [HandeingriffOut]

    public init(eingriffe: [HandeingriffOut] = []) {
        self.eingriffe = eingriffe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.eingriffe = try c.decodeIfPresent([HandeingriffOut].self, forKey: .eingriffe) ?? []
    }
}

/// Die Wärmeseite eines Zeitraums: wer geliefert hat, was entnommen wurde, was verloren ging.
public struct HeatBalanceOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var period: HeatBalanceOutPeriodWahl
    public var start: String
    public var end: String
    public var resolutionDe: String
    public var totals: HeatTotals
    public var previous: HeatTotals?
    public var series: [HeatBalancePointOut]
    public var buckets: [HeatBucketOut]
    public var cost: HeatCostOut?
    public var forecastHeatKwh: Double?
    public var forecastNoteDe: String?
    public var params: HeatParamsOut
    public var ventilation: VentilationOut?
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case period
        case start
        case end
        case resolutionDe = "resolution_de"
        case totals
        case previous
        case series
        case buckets
        case cost
        case forecastHeatKwh = "forecast_heat_kwh"
        case forecastNoteDe = "forecast_note_de"
        case params
        case ventilation
        case noteDe = "note_de"
    }

    public init(generatedAt: String, period: HeatBalanceOutPeriodWahl, start: String, end: String, resolutionDe: String, totals: HeatTotals, previous: HeatTotals? = nil, series: [HeatBalancePointOut] = [], buckets: [HeatBucketOut] = [], cost: HeatCostOut? = nil, forecastHeatKwh: Double? = nil, forecastNoteDe: String? = nil, params: HeatParamsOut, ventilation: VentilationOut? = nil, noteDe: String? = nil) {
        self.generatedAt = generatedAt
        self.period = period
        self.start = start
        self.end = end
        self.resolutionDe = resolutionDe
        self.totals = totals
        self.previous = previous
        self.series = series
        self.buckets = buckets
        self.cost = cost
        self.forecastHeatKwh = forecastHeatKwh
        self.forecastNoteDe = forecastNoteDe
        self.params = params
        self.ventilation = ventilation
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.period = try c.decode(HeatBalanceOutPeriodWahl.self, forKey: .period)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.resolutionDe = try c.decode(String.self, forKey: .resolutionDe)
        self.totals = try c.decode(HeatTotals.self, forKey: .totals)
        self.previous = try c.decodeIfPresent(HeatTotals.self, forKey: .previous)
        self.series = try c.decodeIfPresent([HeatBalancePointOut].self, forKey: .series) ?? []
        self.buckets = try c.decodeIfPresent([HeatBucketOut].self, forKey: .buckets) ?? []
        self.cost = try c.decodeIfPresent(HeatCostOut.self, forKey: .cost)
        self.forecastHeatKwh = try c.decodeIfPresent(Double.self, forKey: .forecastHeatKwh)
        self.forecastNoteDe = try c.decodeIfPresent(String.self, forKey: .forecastNoteDe)
        self.params = try c.decode(HeatParamsOut.self, forKey: .params)
        self.ventilation = try c.decodeIfPresent(VentilationOut.self, forKey: .ventilation)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

/// Ein Punkt der Wärmebilanz im Zeitverlauf, alle Leistungen thermisch in kW.
public struct HeatBalancePointOut: Codable, Sendable, Hashable {
    public var ts: String
    public var heatPumpKw: Double?
    public var stoveWaterKw: Double?
    public var stoveRoomKw: Double?
    public var drawKw: Double?
    public var lossKw: Double?
    public var lossUsefulKw: Double?
    public var bufferChangeKw: Double?
    public var bufferKwh: Double?
    public var cop: Double?

    public enum CodingKeys: String, CodingKey {
        case ts
        case heatPumpKw = "heat_pump_kw"
        case stoveWaterKw = "stove_water_kw"
        case stoveRoomKw = "stove_room_kw"
        case drawKw = "draw_kw"
        case lossKw = "loss_kw"
        case lossUsefulKw = "loss_useful_kw"
        case bufferChangeKw = "buffer_change_kw"
        case bufferKwh = "buffer_kwh"
        case cop
    }

    public init(ts: String, heatPumpKw: Double? = nil, stoveWaterKw: Double? = nil, stoveRoomKw: Double? = nil, drawKw: Double? = nil, lossKw: Double? = nil, lossUsefulKw: Double? = nil, bufferChangeKw: Double? = nil, bufferKwh: Double? = nil, cop: Double? = nil) {
        self.ts = ts
        self.heatPumpKw = heatPumpKw
        self.stoveWaterKw = stoveWaterKw
        self.stoveRoomKw = stoveRoomKw
        self.drawKw = drawKw
        self.lossKw = lossKw
        self.lossUsefulKw = lossUsefulKw
        self.bufferChangeKw = bufferChangeKw
        self.bufferKwh = bufferKwh
        self.cop = cop
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts = try c.decode(String.self, forKey: .ts)
        self.heatPumpKw = try c.decodeIfPresent(Double.self, forKey: .heatPumpKw)
        self.stoveWaterKw = try c.decodeIfPresent(Double.self, forKey: .stoveWaterKw)
        self.stoveRoomKw = try c.decodeIfPresent(Double.self, forKey: .stoveRoomKw)
        self.drawKw = try c.decodeIfPresent(Double.self, forKey: .drawKw)
        self.lossKw = try c.decodeIfPresent(Double.self, forKey: .lossKw)
        self.lossUsefulKw = try c.decodeIfPresent(Double.self, forKey: .lossUsefulKw)
        self.bufferChangeKw = try c.decodeIfPresent(Double.self, forKey: .bufferChangeKw)
        self.bufferKwh = try c.decodeIfPresent(Double.self, forKey: .bufferKwh)
        self.cop = try c.decodeIfPresent(Double.self, forKey: .cop)
    }
}

/// Ein Balken der Statistik: Stunde, Tag oder Monat, je nach Zeitraum.
public struct HeatBucketOut: Codable, Sendable, Hashable {
    public var start: String
    public var labelDe: String
    public var heatPumpKwh: Double?
    public var stoveWaterKwh: Double?
    public var stoveRoomKwh: Double?
    public var drawKwh: Double?
    public var lossKwh: Double?
    public var lossUsefulKwh: Double?
    public var residualKwh: Double?
    public var electricKwh: Double?
    public var copMean: Double?

    public enum CodingKeys: String, CodingKey {
        case start
        case labelDe = "label_de"
        case heatPumpKwh = "heat_pump_kwh"
        case stoveWaterKwh = "stove_water_kwh"
        case stoveRoomKwh = "stove_room_kwh"
        case drawKwh = "draw_kwh"
        case lossKwh = "loss_kwh"
        case lossUsefulKwh = "loss_useful_kwh"
        case residualKwh = "residual_kwh"
        case electricKwh = "electric_kwh"
        case copMean = "cop_mean"
    }

    public init(start: String, labelDe: String, heatPumpKwh: Double? = nil, stoveWaterKwh: Double? = nil, stoveRoomKwh: Double? = nil, drawKwh: Double? = nil, lossKwh: Double? = nil, lossUsefulKwh: Double? = nil, residualKwh: Double? = nil, electricKwh: Double? = nil, copMean: Double? = nil) {
        self.start = start
        self.labelDe = labelDe
        self.heatPumpKwh = heatPumpKwh
        self.stoveWaterKwh = stoveWaterKwh
        self.stoveRoomKwh = stoveRoomKwh
        self.drawKwh = drawKwh
        self.lossKwh = lossKwh
        self.lossUsefulKwh = lossUsefulKwh
        self.residualKwh = residualKwh
        self.electricKwh = electricKwh
        self.copMean = copMean
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
        self.heatPumpKwh = try c.decodeIfPresent(Double.self, forKey: .heatPumpKwh)
        self.stoveWaterKwh = try c.decodeIfPresent(Double.self, forKey: .stoveWaterKwh)
        self.stoveRoomKwh = try c.decodeIfPresent(Double.self, forKey: .stoveRoomKwh)
        self.drawKwh = try c.decodeIfPresent(Double.self, forKey: .drawKwh)
        self.lossKwh = try c.decodeIfPresent(Double.self, forKey: .lossKwh)
        self.lossUsefulKwh = try c.decodeIfPresent(Double.self, forKey: .lossUsefulKwh)
        self.residualKwh = try c.decodeIfPresent(Double.self, forKey: .residualKwh)
        self.electricKwh = try c.decodeIfPresent(Double.self, forKey: .electricKwh)
        self.copMean = try c.decodeIfPresent(Double.self, forKey: .copMean)
    }
}

/// Die Annahmen der Wärmerechnung, soweit sie von Hand zu stellen sind.
///
/// **Teilmenge, kein Abbild der Konfiguration.** Hier stehen nur Werte, die ein Mensch an seiner
/// Anlage kennt oder ablesen kann: was auf dem Lieferschein der Pellets steht, was im Datenblatt des
/// Ofens steht, wie warm der Puffer gefahren wird. Regelparameter bleiben draußen; sie gehören in
/// die Konfigurationsdatei, wo eine falsche Zahl beim Start auffällt und nicht nachts um drei.
///
/// Jedes Feld ist freiwillig: geschickt wird, was geändert wurde, alles andere bleibt stehen.
public struct HeatConfigIn: Codable, Sendable, Hashable {
    public var copCurve: [[Double]]?
    public var bufferTargetTemperatureC: Double?
    public var bufferVolumeLiters: Double?
    public var bufferLossKwPerK: Double?
    public var bufferAmbientC: Double?
    public var bufferLossUsefulFraction: Double?
    public var indoorTargetC: Double?
    public var stoveNominalHeatKw: Double?
    public var stoveWaterHeatKw: Double?
    public var stoveMinHeatKw: Double?
    public var stoveMinWaterHeatKw: Double?
    public var stoveCombustionEfficiency: Double?
    public var pelletKwhPerKg: Double?
    public var pelletPriceEurPerT: Double?

    public enum CodingKeys: String, CodingKey {
        case copCurve = "cop_curve"
        case bufferTargetTemperatureC = "buffer_target_temperature_c"
        case bufferVolumeLiters = "buffer_volume_liters"
        case bufferLossKwPerK = "buffer_loss_kw_per_k"
        case bufferAmbientC = "buffer_ambient_c"
        case bufferLossUsefulFraction = "buffer_loss_useful_fraction"
        case indoorTargetC = "indoor_target_c"
        case stoveNominalHeatKw = "stove_nominal_heat_kw"
        case stoveWaterHeatKw = "stove_water_heat_kw"
        case stoveMinHeatKw = "stove_min_heat_kw"
        case stoveMinWaterHeatKw = "stove_min_water_heat_kw"
        case stoveCombustionEfficiency = "stove_combustion_efficiency"
        case pelletKwhPerKg = "pellet_kwh_per_kg"
        case pelletPriceEurPerT = "pellet_price_eur_per_t"
    }

    public init(copCurve: [[Double]]? = nil, bufferTargetTemperatureC: Double? = nil, bufferVolumeLiters: Double? = nil, bufferLossKwPerK: Double? = nil, bufferAmbientC: Double? = nil, bufferLossUsefulFraction: Double? = nil, indoorTargetC: Double? = nil, stoveNominalHeatKw: Double? = nil, stoveWaterHeatKw: Double? = nil, stoveMinHeatKw: Double? = nil, stoveMinWaterHeatKw: Double? = nil, stoveCombustionEfficiency: Double? = nil, pelletKwhPerKg: Double? = nil, pelletPriceEurPerT: Double? = nil) {
        self.copCurve = copCurve
        self.bufferTargetTemperatureC = bufferTargetTemperatureC
        self.bufferVolumeLiters = bufferVolumeLiters
        self.bufferLossKwPerK = bufferLossKwPerK
        self.bufferAmbientC = bufferAmbientC
        self.bufferLossUsefulFraction = bufferLossUsefulFraction
        self.indoorTargetC = indoorTargetC
        self.stoveNominalHeatKw = stoveNominalHeatKw
        self.stoveWaterHeatKw = stoveWaterHeatKw
        self.stoveMinHeatKw = stoveMinHeatKw
        self.stoveMinWaterHeatKw = stoveMinWaterHeatKw
        self.stoveCombustionEfficiency = stoveCombustionEfficiency
        self.pelletKwhPerKg = pelletKwhPerKg
        self.pelletPriceEurPerT = pelletPriceEurPerT
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.copCurve = try c.decodeIfPresent([[Double]].self, forKey: .copCurve)
        self.bufferTargetTemperatureC = try c.decodeIfPresent(Double.self, forKey: .bufferTargetTemperatureC)
        self.bufferVolumeLiters = try c.decodeIfPresent(Double.self, forKey: .bufferVolumeLiters)
        self.bufferLossKwPerK = try c.decodeIfPresent(Double.self, forKey: .bufferLossKwPerK)
        self.bufferAmbientC = try c.decodeIfPresent(Double.self, forKey: .bufferAmbientC)
        self.bufferLossUsefulFraction = try c.decodeIfPresent(Double.self, forKey: .bufferLossUsefulFraction)
        self.indoorTargetC = try c.decodeIfPresent(Double.self, forKey: .indoorTargetC)
        self.stoveNominalHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveNominalHeatKw)
        self.stoveWaterHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveWaterHeatKw)
        self.stoveMinHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveMinHeatKw)
        self.stoveMinWaterHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveMinWaterHeatKw)
        self.stoveCombustionEfficiency = try c.decodeIfPresent(Double.self, forKey: .stoveCombustionEfficiency)
        self.pelletKwhPerKg = try c.decodeIfPresent(Double.self, forKey: .pelletKwhPerKg)
        self.pelletPriceEurPerT = try c.decodeIfPresent(Double.self, forKey: .pelletPriceEurPerT)
    }
}

/// Was die Wärme des Zeitraums gekostet hat, je Erzeuger und je Kilowattstunde.
///
/// **Zwei verschiedene Arten von Kosten**, und sie stehen deshalb getrennt. Der Strom der
/// Wärmepumpe ist bezahlt worden, als er floss; zu ihm gehört die entgangene Einspeisevergütung für
/// PV-Strom, der stattdessen ins Haus ging. Die Pellets sind bezahlt worden, als sie geliefert
/// wurden - hier steht, was die in diesem Zeitraum **verbrannte** Menge zum hinterlegten Preis
/// wert war. Das ist kein Kontoauszug, sondern der Vergleichsmaßstab zwischen zwei Erzeugern.
public struct HeatCostOut: Codable, Sendable, Hashable {
    public var heatPumpPaidEur: Double?
    public var heatPumpOpportunityEur: Double?
    public var heatPumpCtPerKwh: Double?
    public var stoveKg: Double?
    public var stoveEur: Double?
    public var stoveCtPerKwh: Double?
    public var cheaperDe: String?

    public enum CodingKeys: String, CodingKey {
        case heatPumpPaidEur = "heat_pump_paid_eur"
        case heatPumpOpportunityEur = "heat_pump_opportunity_eur"
        case heatPumpCtPerKwh = "heat_pump_ct_per_kwh"
        case stoveKg = "stove_kg"
        case stoveEur = "stove_eur"
        case stoveCtPerKwh = "stove_ct_per_kwh"
        case cheaperDe = "cheaper_de"
    }

    public init(heatPumpPaidEur: Double? = nil, heatPumpOpportunityEur: Double? = nil, heatPumpCtPerKwh: Double? = nil, stoveKg: Double? = nil, stoveEur: Double? = nil, stoveCtPerKwh: Double? = nil, cheaperDe: String? = nil) {
        self.heatPumpPaidEur = heatPumpPaidEur
        self.heatPumpOpportunityEur = heatPumpOpportunityEur
        self.heatPumpCtPerKwh = heatPumpCtPerKwh
        self.stoveKg = stoveKg
        self.stoveEur = stoveEur
        self.stoveCtPerKwh = stoveCtPerKwh
        self.cheaperDe = cheaperDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.heatPumpPaidEur = try c.decodeIfPresent(Double.self, forKey: .heatPumpPaidEur)
        self.heatPumpOpportunityEur = try c.decodeIfPresent(Double.self, forKey: .heatPumpOpportunityEur)
        self.heatPumpCtPerKwh = try c.decodeIfPresent(Double.self, forKey: .heatPumpCtPerKwh)
        self.stoveKg = try c.decodeIfPresent(Double.self, forKey: .stoveKg)
        self.stoveEur = try c.decodeIfPresent(Double.self, forKey: .stoveEur)
        self.stoveCtPerKwh = try c.decodeIfPresent(Double.self, forKey: .stoveCtPerKwh)
        self.cheaperDe = try c.decodeIfPresent(String.self, forKey: .cheaperDe)
    }
}

/// Wärmebedarfsmodell v1 (Plan 20.2): Heizgradstunden, Warmwasserprofil, COP-Kennlinie.
public struct HeatDemandConfig: Codable, Sendable, Hashable {
    public var heatLossKwPerK: Double?
    public var indoorTargetC: Double?
    public var heatingLimitC: Double?
    public var internalGainsKw: Double?
    public var dhwKwhPerDay: Double?
    public var dhwProfile: [Double]
    public var copCurve: [[Double]]

    public enum CodingKeys: String, CodingKey {
        case heatLossKwPerK = "heat_loss_kw_per_k"
        case indoorTargetC = "indoor_target_c"
        case heatingLimitC = "heating_limit_c"
        case internalGainsKw = "internal_gains_kw"
        case dhwKwhPerDay = "dhw_kwh_per_day"
        case dhwProfile = "dhw_profile"
        case copCurve = "cop_curve"
    }

    public init(heatLossKwPerK: Double? = nil, indoorTargetC: Double? = nil, heatingLimitC: Double? = nil, internalGainsKw: Double? = nil, dhwKwhPerDay: Double? = nil, dhwProfile: [Double] = [], copCurve: [[Double]] = []) {
        self.heatLossKwPerK = heatLossKwPerK
        self.indoorTargetC = indoorTargetC
        self.heatingLimitC = heatingLimitC
        self.internalGainsKw = internalGainsKw
        self.dhwKwhPerDay = dhwKwhPerDay
        self.dhwProfile = dhwProfile
        self.copCurve = copCurve
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.heatLossKwPerK = try c.decodeIfPresent(Double.self, forKey: .heatLossKwPerK)
        self.indoorTargetC = try c.decodeIfPresent(Double.self, forKey: .indoorTargetC)
        self.heatingLimitC = try c.decodeIfPresent(Double.self, forKey: .heatingLimitC)
        self.internalGainsKw = try c.decodeIfPresent(Double.self, forKey: .internalGainsKw)
        self.dhwKwhPerDay = try c.decodeIfPresent(Double.self, forKey: .dhwKwhPerDay)
        self.dhwProfile = try c.decodeIfPresent([Double].self, forKey: .dhwProfile) ?? []
        self.copCurve = try c.decodeIfPresent([[Double]].self, forKey: .copCurve) ?? []
    }
}

public struct HeatForecastPoint: Codable, Sendable, Hashable {
    public var ts: String
    public var outdoorC: Double
    public var heatingKw: Double
    public var dhwKw: Double
    public var cop: Double
    public var electricKw: Double

    public enum CodingKeys: String, CodingKey {
        case ts
        case outdoorC = "outdoor_c"
        case heatingKw = "heating_kw"
        case dhwKw = "dhw_kw"
        case cop
        case electricKw = "electric_kw"
    }

    public init(ts: String, outdoorC: Double, heatingKw: Double, dhwKw: Double, cop: Double, electricKw: Double) {
        self.ts = ts
        self.outdoorC = outdoorC
        self.heatingKw = heatingKw
        self.dhwKw = dhwKw
        self.cop = cop
        self.electricKw = electricKw
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts = try c.decode(String.self, forKey: .ts)
        self.outdoorC = try c.decode(Double.self, forKey: .outdoorC)
        self.heatingKw = try c.decode(Double.self, forKey: .heatingKw)
        self.dhwKw = try c.decode(Double.self, forKey: .dhwKw)
        self.cop = try c.decode(Double.self, forKey: .cop)
        self.electricKw = try c.decode(Double.self, forKey: .electricKw)
    }
}

/// Die Annahmen, mit denen gerechnet wurde.
///
/// Sie stehen im Bericht, weil eine gerechnete Wärmemenge ohne ihre Annahmen keine Zahl ist,
/// sondern eine Behauptung. Wer sie ändert, ändert jede Zahl auf dieser Seite, auch die von letztem
/// Jahr - gespeichert werden Eingänge, nicht Ergebnisse.
public struct HeatParamsOut: Codable, Sendable, Hashable {
    public var copCurve: [[Double]]
    public var copReferenceC: Double?
    public var stoveNominalHeatKw: Double?
    public var stoveWaterHeatKw: Double?
    public var stoveMinHeatKw: Double?
    public var stoveMinWaterHeatKw: Double?
    public var stoveCombustionEfficiency: Double?
    public var pelletKwhPerKg: Double?
    public var pelletPriceEurPerT: Double?
    public var bufferVolumeLiters: Double?
    public var bufferLossKwPerK: Double?
    public var bufferAmbientC: Double?
    public var bufferLossUsefulFraction: Double?
    public var roomSourceDe: String?

    public enum CodingKeys: String, CodingKey {
        case copCurve = "cop_curve"
        case copReferenceC = "cop_reference_c"
        case stoveNominalHeatKw = "stove_nominal_heat_kw"
        case stoveWaterHeatKw = "stove_water_heat_kw"
        case stoveMinHeatKw = "stove_min_heat_kw"
        case stoveMinWaterHeatKw = "stove_min_water_heat_kw"
        case stoveCombustionEfficiency = "stove_combustion_efficiency"
        case pelletKwhPerKg = "pellet_kwh_per_kg"
        case pelletPriceEurPerT = "pellet_price_eur_per_t"
        case bufferVolumeLiters = "buffer_volume_liters"
        case bufferLossKwPerK = "buffer_loss_kw_per_k"
        case bufferAmbientC = "buffer_ambient_c"
        case bufferLossUsefulFraction = "buffer_loss_useful_fraction"
        case roomSourceDe = "room_source_de"
    }

    public init(copCurve: [[Double]] = [], copReferenceC: Double? = nil, stoveNominalHeatKw: Double? = nil, stoveWaterHeatKw: Double? = nil, stoveMinHeatKw: Double? = nil, stoveMinWaterHeatKw: Double? = nil, stoveCombustionEfficiency: Double? = nil, pelletKwhPerKg: Double? = nil, pelletPriceEurPerT: Double? = nil, bufferVolumeLiters: Double? = nil, bufferLossKwPerK: Double? = nil, bufferAmbientC: Double? = nil, bufferLossUsefulFraction: Double? = nil, roomSourceDe: String? = nil) {
        self.copCurve = copCurve
        self.copReferenceC = copReferenceC
        self.stoveNominalHeatKw = stoveNominalHeatKw
        self.stoveWaterHeatKw = stoveWaterHeatKw
        self.stoveMinHeatKw = stoveMinHeatKw
        self.stoveMinWaterHeatKw = stoveMinWaterHeatKw
        self.stoveCombustionEfficiency = stoveCombustionEfficiency
        self.pelletKwhPerKg = pelletKwhPerKg
        self.pelletPriceEurPerT = pelletPriceEurPerT
        self.bufferVolumeLiters = bufferVolumeLiters
        self.bufferLossKwPerK = bufferLossKwPerK
        self.bufferAmbientC = bufferAmbientC
        self.bufferLossUsefulFraction = bufferLossUsefulFraction
        self.roomSourceDe = roomSourceDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.copCurve = try c.decodeIfPresent([[Double]].self, forKey: .copCurve) ?? []
        self.copReferenceC = try c.decodeIfPresent(Double.self, forKey: .copReferenceC)
        self.stoveNominalHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveNominalHeatKw)
        self.stoveWaterHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveWaterHeatKw)
        self.stoveMinHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveMinHeatKw)
        self.stoveMinWaterHeatKw = try c.decodeIfPresent(Double.self, forKey: .stoveMinWaterHeatKw)
        self.stoveCombustionEfficiency = try c.decodeIfPresent(Double.self, forKey: .stoveCombustionEfficiency)
        self.pelletKwhPerKg = try c.decodeIfPresent(Double.self, forKey: .pelletKwhPerKg)
        self.pelletPriceEurPerT = try c.decodeIfPresent(Double.self, forKey: .pelletPriceEurPerT)
        self.bufferVolumeLiters = try c.decodeIfPresent(Double.self, forKey: .bufferVolumeLiters)
        self.bufferLossKwPerK = try c.decodeIfPresent(Double.self, forKey: .bufferLossKwPerK)
        self.bufferAmbientC = try c.decodeIfPresent(Double.self, forKey: .bufferAmbientC)
        self.bufferLossUsefulFraction = try c.decodeIfPresent(Double.self, forKey: .bufferLossUsefulFraction)
        self.roomSourceDe = try c.decodeIfPresent(String.self, forKey: .roomSourceDe)
    }
}

public struct HeatPumpConfig: Codable, Sendable, Hashable {
    public var minimumElectricPowerKw: Double?
    public var nominalElectricPowerKw: Double?
    public var nominalThermalPowerKw: Double?
    public var runningThresholdKw: Double?
    public var runningDebounceS: Int?
    public var minRuntimeMin: Int?
    public var minOfftimeMin: Int?
    public var startTimeoutMin: Int?
    public var maxStartsPerDay: Int?
    public var releaseTtlMin: Int?
    public var hwAutoOffReleaseS: Int?
    public var hwAutoOffBlockS: Int?

    public enum CodingKeys: String, CodingKey {
        case minimumElectricPowerKw = "minimum_electric_power_kw"
        case nominalElectricPowerKw = "nominal_electric_power_kw"
        case nominalThermalPowerKw = "nominal_thermal_power_kw"
        case runningThresholdKw = "running_threshold_kw"
        case runningDebounceS = "running_debounce_s"
        case minRuntimeMin = "min_runtime_min"
        case minOfftimeMin = "min_offtime_min"
        case startTimeoutMin = "start_timeout_min"
        case maxStartsPerDay = "max_starts_per_day"
        case releaseTtlMin = "release_ttl_min"
        case hwAutoOffReleaseS = "hw_auto_off_release_s"
        case hwAutoOffBlockS = "hw_auto_off_block_s"
    }

    public init(minimumElectricPowerKw: Double? = nil, nominalElectricPowerKw: Double? = nil, nominalThermalPowerKw: Double? = nil, runningThresholdKw: Double? = nil, runningDebounceS: Int? = nil, minRuntimeMin: Int? = nil, minOfftimeMin: Int? = nil, startTimeoutMin: Int? = nil, maxStartsPerDay: Int? = nil, releaseTtlMin: Int? = nil, hwAutoOffReleaseS: Int? = nil, hwAutoOffBlockS: Int? = nil) {
        self.minimumElectricPowerKw = minimumElectricPowerKw
        self.nominalElectricPowerKw = nominalElectricPowerKw
        self.nominalThermalPowerKw = nominalThermalPowerKw
        self.runningThresholdKw = runningThresholdKw
        self.runningDebounceS = runningDebounceS
        self.minRuntimeMin = minRuntimeMin
        self.minOfftimeMin = minOfftimeMin
        self.startTimeoutMin = startTimeoutMin
        self.maxStartsPerDay = maxStartsPerDay
        self.releaseTtlMin = releaseTtlMin
        self.hwAutoOffReleaseS = hwAutoOffReleaseS
        self.hwAutoOffBlockS = hwAutoOffBlockS
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.minimumElectricPowerKw = try c.decodeIfPresent(Double.self, forKey: .minimumElectricPowerKw)
        self.nominalElectricPowerKw = try c.decodeIfPresent(Double.self, forKey: .nominalElectricPowerKw)
        self.nominalThermalPowerKw = try c.decodeIfPresent(Double.self, forKey: .nominalThermalPowerKw)
        self.runningThresholdKw = try c.decodeIfPresent(Double.self, forKey: .runningThresholdKw)
        self.runningDebounceS = try c.decodeIfPresent(Int.self, forKey: .runningDebounceS)
        self.minRuntimeMin = try c.decodeIfPresent(Int.self, forKey: .minRuntimeMin)
        self.minOfftimeMin = try c.decodeIfPresent(Int.self, forKey: .minOfftimeMin)
        self.startTimeoutMin = try c.decodeIfPresent(Int.self, forKey: .startTimeoutMin)
        self.maxStartsPerDay = try c.decodeIfPresent(Int.self, forKey: .maxStartsPerDay)
        self.releaseTtlMin = try c.decodeIfPresent(Int.self, forKey: .releaseTtlMin)
        self.hwAutoOffReleaseS = try c.decodeIfPresent(Int.self, forKey: .hwAutoOffReleaseS)
        self.hwAutoOffBlockS = try c.decodeIfPresent(Int.self, forKey: .hwAutoOffBlockS)
    }
}

public struct HeatPumpModeIn: Codable, Sendable, Hashable {
    public var systemMode: SystemMode
    public var autoProfile: AutoProfile?
    public var manualState: HeatPumpModeInManualStateWahl?
    public var durationMin: Int?

    public enum CodingKeys: String, CodingKey {
        case systemMode = "system_mode"
        case autoProfile = "auto_profile"
        case manualState = "manual_state"
        case durationMin = "duration_min"
    }

    public init(systemMode: SystemMode, autoProfile: AutoProfile? = nil, manualState: HeatPumpModeInManualStateWahl? = nil, durationMin: Int? = nil) {
        self.systemMode = systemMode
        self.autoProfile = autoProfile
        self.manualState = manualState
        self.durationMin = durationMin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.systemMode = try c.decode(SystemMode.self, forKey: .systemMode)
        self.autoProfile = try c.decodeIfPresent(AutoProfile.self, forKey: .autoProfile)
        self.manualState = try c.decodeIfPresent(HeatPumpModeInManualStateWahl.self, forKey: .manualState)
        self.durationMin = try c.decodeIfPresent(Int.self, forKey: .durationMin)
    }
}

public struct HeatPumpState: Codable, Sendable, Hashable {
    public var running: Bool
    public var runningSince: String?
    public var stoppedSince: String?
    public var powerKw: Double
    public var releaseContactOn: Bool
    public var blockContactOn: Bool
    public var startsToday: Int
    public var powerKnown: Bool?

    public enum CodingKeys: String, CodingKey {
        case running
        case runningSince = "running_since"
        case stoppedSince = "stopped_since"
        case powerKw = "power_kw"
        case releaseContactOn = "release_contact_on"
        case blockContactOn = "block_contact_on"
        case startsToday = "starts_today"
        case powerKnown = "power_known"
    }

    public init(running: Bool, runningSince: String? = nil, stoppedSince: String? = nil, powerKw: Double, releaseContactOn: Bool, blockContactOn: Bool, startsToday: Int, powerKnown: Bool? = nil) {
        self.running = running
        self.runningSince = runningSince
        self.stoppedSince = stoppedSince
        self.powerKw = powerKw
        self.releaseContactOn = releaseContactOn
        self.blockContactOn = blockContactOn
        self.startsToday = startsToday
        self.powerKnown = powerKnown
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.running = try c.decode(Bool.self, forKey: .running)
        self.runningSince = try c.decodeIfPresent(String.self, forKey: .runningSince)
        self.stoppedSince = try c.decodeIfPresent(String.self, forKey: .stoppedSince)
        self.powerKw = try c.decode(Double.self, forKey: .powerKw)
        self.releaseContactOn = try c.decode(Bool.self, forKey: .releaseContactOn)
        self.blockContactOn = try c.decode(Bool.self, forKey: .blockContactOn)
        self.startsToday = try c.decode(Int.self, forKey: .startsToday)
        self.powerKnown = try c.decodeIfPresent(Bool.self, forKey: .powerKnown)
    }
}

public struct HeatReportOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var summary: EnergySummaryOut
    public var thermalKwhEst: Double
    public var copEst: Double
    public var forecast: [HeatForecastPoint]
    public var forecastElectricKwh24h: Double
    public var forecastThermalKwh24h: Double
    public var bufferSeries: [[String: Mischwert]]
    public var heatLossKwPerK: Double
    public var cycling: CyclingStats
    public var priceQuality: PriceQualityOut
    public var bufferBalance: BufferBalanceOut
    public var stove: StoveOut
    public var modelNoteDe: String

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case summary
        case thermalKwhEst = "thermal_kwh_est"
        case copEst = "cop_est"
        case forecast
        case forecastElectricKwh24h = "forecast_electric_kwh_24h"
        case forecastThermalKwh24h = "forecast_thermal_kwh_24h"
        case bufferSeries = "buffer_series"
        case heatLossKwPerK = "heat_loss_kw_per_k"
        case cycling
        case priceQuality = "price_quality"
        case bufferBalance = "buffer_balance"
        case stove
        case modelNoteDe = "model_note_de"
    }

    public init(generatedAt: String, summary: EnergySummaryOut, thermalKwhEst: Double, copEst: Double, forecast: [HeatForecastPoint] = [], forecastElectricKwh24h: Double, forecastThermalKwh24h: Double, bufferSeries: [[String: Mischwert]] = [], heatLossKwPerK: Double, cycling: CyclingStats, priceQuality: PriceQualityOut, bufferBalance: BufferBalanceOut, stove: StoveOut, modelNoteDe: String) {
        self.generatedAt = generatedAt
        self.summary = summary
        self.thermalKwhEst = thermalKwhEst
        self.copEst = copEst
        self.forecast = forecast
        self.forecastElectricKwh24h = forecastElectricKwh24h
        self.forecastThermalKwh24h = forecastThermalKwh24h
        self.bufferSeries = bufferSeries
        self.heatLossKwPerK = heatLossKwPerK
        self.cycling = cycling
        self.priceQuality = priceQuality
        self.bufferBalance = bufferBalance
        self.stove = stove
        self.modelNoteDe = modelNoteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.summary = try c.decode(EnergySummaryOut.self, forKey: .summary)
        self.thermalKwhEst = try c.decode(Double.self, forKey: .thermalKwhEst)
        self.copEst = try c.decode(Double.self, forKey: .copEst)
        self.forecast = try c.decodeIfPresent([HeatForecastPoint].self, forKey: .forecast) ?? []
        self.forecastElectricKwh24h = try c.decode(Double.self, forKey: .forecastElectricKwh24h)
        self.forecastThermalKwh24h = try c.decode(Double.self, forKey: .forecastThermalKwh24h)
        self.bufferSeries = try c.decodeIfPresent([[String: Mischwert]].self, forKey: .bufferSeries) ?? []
        self.heatLossKwPerK = try c.decode(Double.self, forKey: .heatLossKwPerK)
        self.cycling = try c.decode(CyclingStats.self, forKey: .cycling)
        self.priceQuality = try c.decode(PriceQualityOut.self, forKey: .priceQuality)
        self.bufferBalance = try c.decode(BufferBalanceOut.self, forKey: .bufferBalance)
        self.stove = try c.decode(StoveOut.self, forKey: .stove)
        self.modelNoteDe = try c.decode(String.self, forKey: .modelNoteDe)
    }
}

/// Summen eines Zeitraums in kWh, thermisch, plus die Zahlen, die sie beurteilbar machen.
public struct HeatTotals: Codable, Sendable, Hashable {
    public var minutes: Int?
    public var heatPumpKwh: Double?
    public var stoveWaterKwh: Double?
    public var stoveRoomKwh: Double?
    public var producedKwh: Double?
    public var drawKwh: Double?
    public var lossKwh: Double?
    public var lossUsefulKwh: Double?
    public var bufferChangeKwh: Double?
    public var residualKwh: Double?
    public var electricKwh: Double?
    public var copMean: Double?
    public var stoveMinutes: Int?
    public var unknownMinutes: Int?
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case minutes
        case heatPumpKwh = "heat_pump_kwh"
        case stoveWaterKwh = "stove_water_kwh"
        case stoveRoomKwh = "stove_room_kwh"
        case producedKwh = "produced_kwh"
        case drawKwh = "draw_kwh"
        case lossKwh = "loss_kwh"
        case lossUsefulKwh = "loss_useful_kwh"
        case bufferChangeKwh = "buffer_change_kwh"
        case residualKwh = "residual_kwh"
        case electricKwh = "electric_kwh"
        case copMean = "cop_mean"
        case stoveMinutes = "stove_minutes"
        case unknownMinutes = "unknown_minutes"
        case noteDe = "note_de"
    }

    public init(minutes: Int? = nil, heatPumpKwh: Double? = nil, stoveWaterKwh: Double? = nil, stoveRoomKwh: Double? = nil, producedKwh: Double? = nil, drawKwh: Double? = nil, lossKwh: Double? = nil, lossUsefulKwh: Double? = nil, bufferChangeKwh: Double? = nil, residualKwh: Double? = nil, electricKwh: Double? = nil, copMean: Double? = nil, stoveMinutes: Int? = nil, unknownMinutes: Int? = nil, noteDe: String? = nil) {
        self.minutes = minutes
        self.heatPumpKwh = heatPumpKwh
        self.stoveWaterKwh = stoveWaterKwh
        self.stoveRoomKwh = stoveRoomKwh
        self.producedKwh = producedKwh
        self.drawKwh = drawKwh
        self.lossKwh = lossKwh
        self.lossUsefulKwh = lossUsefulKwh
        self.bufferChangeKwh = bufferChangeKwh
        self.residualKwh = residualKwh
        self.electricKwh = electricKwh
        self.copMean = copMean
        self.stoveMinutes = stoveMinutes
        self.unknownMinutes = unknownMinutes
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.minutes = try c.decodeIfPresent(Int.self, forKey: .minutes)
        self.heatPumpKwh = try c.decodeIfPresent(Double.self, forKey: .heatPumpKwh)
        self.stoveWaterKwh = try c.decodeIfPresent(Double.self, forKey: .stoveWaterKwh)
        self.stoveRoomKwh = try c.decodeIfPresent(Double.self, forKey: .stoveRoomKwh)
        self.producedKwh = try c.decodeIfPresent(Double.self, forKey: .producedKwh)
        self.drawKwh = try c.decodeIfPresent(Double.self, forKey: .drawKwh)
        self.lossKwh = try c.decodeIfPresent(Double.self, forKey: .lossKwh)
        self.lossUsefulKwh = try c.decodeIfPresent(Double.self, forKey: .lossUsefulKwh)
        self.bufferChangeKwh = try c.decodeIfPresent(Double.self, forKey: .bufferChangeKwh)
        self.residualKwh = try c.decodeIfPresent(Double.self, forKey: .residualKwh)
        self.electricKwh = try c.decodeIfPresent(Double.self, forKey: .electricKwh)
        self.copMean = try c.decodeIfPresent(Double.self, forKey: .copMean)
        self.stoveMinutes = try c.decodeIfPresent(Int.self, forKey: .stoveMinutes)
        self.unknownMinutes = try c.decodeIfPresent(Int.self, forKey: .unknownMinutes)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

public struct HemsConfig: Codable, Sendable, Hashable {
    public var heatPump: HeatPumpConfig?
    public var control: ControlConfig?
    public var buffer: BufferConfig?
    public var balance: BalanceConfig?
    public var timeouts: SensorTimeouts?
    public var tariff: TariffConfig?
    public var heatDemand: HeatDemandConfig?
    public var battery: BatteryConfig?
    public var stove: StoveConfig?

    public enum CodingKeys: String, CodingKey {
        case heatPump = "heat_pump"
        case control
        case buffer
        case balance
        case timeouts
        case tariff
        case heatDemand = "heat_demand"
        case battery
        case stove
    }

    public init(heatPump: HeatPumpConfig? = nil, control: ControlConfig? = nil, buffer: BufferConfig? = nil, balance: BalanceConfig? = nil, timeouts: SensorTimeouts? = nil, tariff: TariffConfig? = nil, heatDemand: HeatDemandConfig? = nil, battery: BatteryConfig? = nil, stove: StoveConfig? = nil) {
        self.heatPump = heatPump
        self.control = control
        self.buffer = buffer
        self.balance = balance
        self.timeouts = timeouts
        self.tariff = tariff
        self.heatDemand = heatDemand
        self.battery = battery
        self.stove = stove
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.heatPump = try c.decodeIfPresent(HeatPumpConfig.self, forKey: .heatPump)
        self.control = try c.decodeIfPresent(ControlConfig.self, forKey: .control)
        self.buffer = try c.decodeIfPresent(BufferConfig.self, forKey: .buffer)
        self.balance = try c.decodeIfPresent(BalanceConfig.self, forKey: .balance)
        self.timeouts = try c.decodeIfPresent(SensorTimeouts.self, forKey: .timeouts)
        self.tariff = try c.decodeIfPresent(TariffConfig.self, forKey: .tariff)
        self.heatDemand = try c.decodeIfPresent(HeatDemandConfig.self, forKey: .heatDemand)
        self.battery = try c.decodeIfPresent(BatteryConfig.self, forKey: .battery)
        self.stove = try c.decodeIfPresent(StoveConfig.self, forKey: .stove)
    }
}

public struct HistoryOut: Codable, Sendable, Hashable {
    public var start: String
    public var end: String
    public var resolutionS: Int?
    public var rows: [[String: Mischwert]]

    public enum CodingKeys: String, CodingKey {
        case start
        case end
        case resolutionS = "resolution_s"
        case rows
    }

    public init(start: String, end: String, resolutionS: Int? = nil, rows: [[String: Mischwert]] = []) {
        self.start = start
        self.end = end
        self.resolutionS = resolutionS
        self.rows = rows
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.resolutionS = try c.decodeIfPresent(Int.self, forKey: .resolutionS)
        self.rows = try c.decodeIfPresent([[String: Mischwert]].self, forKey: .rows) ?? []
    }
}

public struct HorizonScoreOut: Codable, Sendable, Hashable {
    public var key: String
    public var labelDe: String
    public var score: ForecastScore

    public enum CodingKeys: String, CodingKey {
        case key
        case labelDe = "label_de"
        case score
    }

    public init(key: String, labelDe: String, score: ForecastScore) {
        self.key = key
        self.labelDe = labelDe
        self.score = score
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
        self.score = try c.decode(ForecastScore.self, forKey: .score)
    }
}

/// Ein Kontakt des Hausplans im Augenblick. `open` ist `None`, wenn nichts Frisches vorliegt:
/// nicht zugeordnet, noch nie gemeldet oder seit einer halben Stunde still.
public struct HouseContactOut: Codable, Sendable, Hashable {
    public var key: String
    public var name: String
    public var room: String?
    public var door: Bool
    public var `open`: Bool?
    public var observedAt: String?
    public var quality: Quality

    public enum CodingKeys: String, CodingKey {
        case key
        case name
        case room
        case door
        case `open`
        case observedAt = "observed_at"
        case quality
    }

    public init(key: String, name: String, room: String? = nil, door: Bool, open: Bool? = nil, observedAt: String? = nil, quality: Quality) {
        self.key = key
        self.name = name
        self.room = room
        self.door = door
        self.`open` = open
        self.observedAt = observedAt
        self.quality = quality
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.name = try c.decode(String.self, forKey: .name)
        self.room = try c.decodeIfPresent(String.self, forKey: .room)
        self.door = try c.decode(Bool.self, forKey: .door)
        self.`open` = try c.decodeIfPresent(Bool.self, forKey: .`open`)
        self.observedAt = try c.decodeIfPresent(String.self, forKey: .observedAt)
        self.quality = try c.decode(Quality.self, forKey: .quality)
    }
}

/// Der Hausplan fuer die Modellansicht, samt dem Zustand seiner Kontakte.
///
/// `present` ist falsch, solange keine Bruecke einen Plan gemeldet hat oder der letzte gemeldete
/// nicht lesbar war; dann steht der Grund in `error_de`. Der Plan selbst ist Geometrie, keine
/// Messung: Raeume verweisen ueber `room_id` auf die Einzelraumregelung, Kontakte ueber `key`
/// auf die Entity-Zuordnung. Was zu welchem Raum gehoert, entscheidet die Datei des Hauses.
public struct HouseOut: Codable, Sendable, Hashable {
    public var at: String
    public var present: Bool
    public var plan: HousePlan?
    public var sourceDe: String
    public var receivedAt: String?
    public var errorDe: String
    public var contacts: [HouseContactOut]

    public enum CodingKeys: String, CodingKey {
        case at
        case present
        case plan
        case sourceDe = "source_de"
        case receivedAt = "received_at"
        case errorDe = "error_de"
        case contacts
    }

    public init(at: String, present: Bool, plan: HousePlan? = nil, sourceDe: String, receivedAt: String? = nil, errorDe: String, contacts: [HouseContactOut] = []) {
        self.at = at
        self.present = present
        self.plan = plan
        self.sourceDe = sourceDe
        self.receivedAt = receivedAt
        self.errorDe = errorDe
        self.contacts = contacts
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.present = try c.decode(Bool.self, forKey: .present)
        self.plan = try c.decodeIfPresent(HousePlan.self, forKey: .plan)
        self.sourceDe = try c.decode(String.self, forKey: .sourceDe)
        self.receivedAt = try c.decodeIfPresent(String.self, forKey: .receivedAt)
        self.errorDe = try c.decode(String.self, forKey: .errorDe)
        self.contacts = try c.decodeIfPresent([HouseContactOut].self, forKey: .contacts) ?? []
    }
}

/// Das ganze Haus: ein bis drei Decks. `note_de` steht unter der Anzeige, etwa fuer das, was
/// im Plan angenommen und nicht gemessen ist.
public struct HousePlan: Codable, Sendable, Hashable {
    public var version: Int?
    public var name: String?
    public var decks: [Deck]
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case version
        case name
        case decks
        case noteDe = "note_de"
    }

    public init(version: Int? = nil, name: String? = nil, decks: [Deck] = [], noteDe: String? = nil) {
        self.version = version
        self.name = name
        self.decks = decks
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.decks = try c.decodeIfPresent([Deck].self, forKey: .decks) ?? []
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

/// Die eigene Seite: wer ich bin, welche Passkeys und welche Sitzungen ich habe.
public struct IchOut: Codable, Sendable, Hashable {
    public var ausweis: AusweisOut
    public var passkeys: [PasskeyOut]
    public var sitzungen: [SitzungOut]
    public var codesOffen: Int?
    public var passwort: Bool?

    public enum CodingKeys: String, CodingKey {
        case ausweis
        case passkeys
        case sitzungen
        case codesOffen = "codes_offen"
        case passwort
    }

    public init(ausweis: AusweisOut, passkeys: [PasskeyOut] = [], sitzungen: [SitzungOut] = [], codesOffen: Int? = nil, passwort: Bool? = nil) {
        self.ausweis = ausweis
        self.passkeys = passkeys
        self.sitzungen = sitzungen
        self.codesOffen = codesOffen
        self.passwort = passwort
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ausweis = try c.decode(AusweisOut.self, forKey: .ausweis)
        self.passkeys = try c.decodeIfPresent([PasskeyOut].self, forKey: .passkeys) ?? []
        self.sitzungen = try c.decodeIfPresent([SitzungOut].self, forKey: .sitzungen) ?? []
        self.codesOffen = try c.decodeIfPresent(Int.self, forKey: .codesOffen)
        self.passwort = try c.decodeIfPresent(Bool.self, forKey: .passwort)
    }
}

public struct ImportResult: Codable, Sendable, Hashable {
    public var kind: String
    public var rows: Int
    public var entities: [String]
    public var unmapped: [String]
    public var first: String?
    public var last: String?
    public var hoursComputed: Int
    public var hoursWritten: Int
    public var hoursKeptExisting: Int
    public var hoursConsumerPatched: Int?
    public var rawReadingsStored: Int
    public var priceMinutesFromTibber: Int
    public var minutesWithoutPrice: Int
    public var dryRun: Bool
    public var noteDe: String

    public enum CodingKeys: String, CodingKey {
        case kind
        case rows
        case entities
        case unmapped
        case first
        case last
        case hoursComputed = "hours_computed"
        case hoursWritten = "hours_written"
        case hoursKeptExisting = "hours_kept_existing"
        case hoursConsumerPatched = "hours_consumer_patched"
        case rawReadingsStored = "raw_readings_stored"
        case priceMinutesFromTibber = "price_minutes_from_tibber"
        case minutesWithoutPrice = "minutes_without_price"
        case dryRun = "dry_run"
        case noteDe = "note_de"
    }

    public init(kind: String, rows: Int, entities: [String] = [], unmapped: [String] = [], first: String? = nil, last: String? = nil, hoursComputed: Int, hoursWritten: Int, hoursKeptExisting: Int, hoursConsumerPatched: Int? = nil, rawReadingsStored: Int, priceMinutesFromTibber: Int, minutesWithoutPrice: Int, dryRun: Bool, noteDe: String) {
        self.kind = kind
        self.rows = rows
        self.entities = entities
        self.unmapped = unmapped
        self.first = first
        self.last = last
        self.hoursComputed = hoursComputed
        self.hoursWritten = hoursWritten
        self.hoursKeptExisting = hoursKeptExisting
        self.hoursConsumerPatched = hoursConsumerPatched
        self.rawReadingsStored = rawReadingsStored
        self.priceMinutesFromTibber = priceMinutesFromTibber
        self.minutesWithoutPrice = minutesWithoutPrice
        self.dryRun = dryRun
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try c.decode(String.self, forKey: .kind)
        self.rows = try c.decode(Int.self, forKey: .rows)
        self.entities = try c.decodeIfPresent([String].self, forKey: .entities) ?? []
        self.unmapped = try c.decodeIfPresent([String].self, forKey: .unmapped) ?? []
        self.first = try c.decodeIfPresent(String.self, forKey: .first)
        self.last = try c.decodeIfPresent(String.self, forKey: .last)
        self.hoursComputed = try c.decode(Int.self, forKey: .hoursComputed)
        self.hoursWritten = try c.decode(Int.self, forKey: .hoursWritten)
        self.hoursKeptExisting = try c.decode(Int.self, forKey: .hoursKeptExisting)
        self.hoursConsumerPatched = try c.decodeIfPresent(Int.self, forKey: .hoursConsumerPatched)
        self.rawReadingsStored = try c.decode(Int.self, forKey: .rawReadingsStored)
        self.priceMinutesFromTibber = try c.decode(Int.self, forKey: .priceMinutesFromTibber)
        self.minutesWithoutPrice = try c.decode(Int.self, forKey: .minutesWithoutPrice)
        self.dryRun = try c.decode(Bool.self, forKey: .dryRun)
        self.noteDe = try c.decode(String.self, forKey: .noteDe)
    }
}

public struct InvoiceFee: Codable, Sendable, Hashable {
    public var label: String
    public var amountEur: Double
    public var rateEur: Double?
    public var per: InvoiceFeePerWahl?
    public var days: Int?

    public enum CodingKeys: String, CodingKey {
        case label
        case amountEur = "amount_eur"
        case rateEur = "rate_eur"
        case per
        case days
    }

    public init(label: String, amountEur: Double, rateEur: Double? = nil, per: InvoiceFeePerWahl? = nil, days: Int? = nil) {
        self.label = label
        self.amountEur = amountEur
        self.rateEur = rateEur
        self.per = per
        self.days = days
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try c.decode(String.self, forKey: .label)
        self.amountEur = try c.decode(Double.self, forKey: .amountEur)
        self.rateEur = try c.decodeIfPresent(Double.self, forKey: .rateEur)
        self.per = try c.decodeIfPresent(InvoiceFeePerWahl.self, forKey: .per)
        self.days = try c.decodeIfPresent(Int.self, forKey: .days)
    }
}

public struct InvoiceFinding: Codable, Sendable, Hashable {
    public var code: String
    public var severity: InvoiceFindingSeverityWahl
    public var titleDe: String
    public var detailDe: String
    public var expected: Double?
    public var actual: Double?
    public var unit: String?
    public var delta: Double?

    public enum CodingKeys: String, CodingKey {
        case code
        case severity
        case titleDe = "title_de"
        case detailDe = "detail_de"
        case expected
        case actual
        case unit
        case delta
    }

    public init(code: String, severity: InvoiceFindingSeverityWahl, titleDe: String, detailDe: String, expected: Double? = nil, actual: Double? = nil, unit: String? = nil, delta: Double? = nil) {
        self.code = code
        self.severity = severity
        self.titleDe = titleDe
        self.detailDe = detailDe
        self.expected = expected
        self.actual = actual
        self.unit = unit
        self.delta = delta
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try c.decode(String.self, forKey: .code)
        self.severity = try c.decode(InvoiceFindingSeverityWahl.self, forKey: .severity)
        self.titleDe = try c.decode(String.self, forKey: .titleDe)
        self.detailDe = try c.decode(String.self, forKey: .detailDe)
        self.expected = try c.decodeIfPresent(Double.self, forKey: .expected)
        self.actual = try c.decodeIfPresent(Double.self, forKey: .actual)
        self.unit = try c.decodeIfPresent(String.self, forKey: .unit)
        self.delta = try c.decodeIfPresent(Double.self, forKey: .delta)
    }
}

public struct InvoicePosition: Codable, Sendable, Hashable {
    public var label: String
    public var group: String
    public var ctPerKwh: Double
    public var ctDecimals: Int
    public var amountEur: Double

    public enum CodingKeys: String, CodingKey {
        case label
        case group
        case ctPerKwh = "ct_per_kwh"
        case ctDecimals = "ct_decimals"
        case amountEur = "amount_eur"
    }

    public init(label: String, group: String, ctPerKwh: Double, ctDecimals: Int, amountEur: Double) {
        self.label = label
        self.group = group
        self.ctPerKwh = ctPerKwh
        self.ctDecimals = ctDecimals
        self.amountEur = amountEur
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try c.decode(String.self, forKey: .label)
        self.group = try c.decode(String.self, forKey: .group)
        self.ctPerKwh = try c.decode(Double.self, forKey: .ctPerKwh)
        self.ctDecimals = try c.decode(Int.self, forKey: .ctDecimals)
        self.amountEur = try c.decode(Double.self, forKey: .amountEur)
    }
}

/// Ergebnis einer Rechnungsprüfung: gelesene Rechnung, Befunde, Ampel und der Vergleichswert.
public struct InvoiceReportOut: Codable, Sendable, Hashable {
    public var invoice: TibberInvoice
    public var findings: [InvoiceFinding]
    public var verdict: String
    public var measured: MeasuredPeriod?
    public var checkedAt: String
    public var fileName: String?
    public var alreadyKnown: Bool?

    public enum CodingKeys: String, CodingKey {
        case invoice
        case findings
        case verdict
        case measured
        case checkedAt = "checked_at"
        case fileName = "file_name"
        case alreadyKnown = "already_known"
    }

    public init(invoice: TibberInvoice, findings: [InvoiceFinding] = [], verdict: String, measured: MeasuredPeriod? = nil, checkedAt: String, fileName: String? = nil, alreadyKnown: Bool? = nil) {
        self.invoice = invoice
        self.findings = findings
        self.verdict = verdict
        self.measured = measured
        self.checkedAt = checkedAt
        self.fileName = fileName
        self.alreadyKnown = alreadyKnown
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.invoice = try c.decode(TibberInvoice.self, forKey: .invoice)
        self.findings = try c.decodeIfPresent([InvoiceFinding].self, forKey: .findings) ?? []
        self.verdict = try c.decode(String.self, forKey: .verdict)
        self.measured = try c.decodeIfPresent(MeasuredPeriod.self, forKey: .measured)
        self.checkedAt = try c.decode(String.self, forKey: .checkedAt)
        self.fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        self.alreadyKnown = try c.decodeIfPresent(Bool.self, forKey: .alreadyKnown)
    }
}

/// Eine Zeile im Rechnungsverlauf.
public struct InvoiceSummaryOut: Codable, Sendable, Hashable {
    public var number: String
    public var periodLabel: String
    public var periodStart: String
    public var periodEnd: String
    public var issuedOn: String
    public var kwh: Double
    public var measuredKwh: Double?
    public var measuredAvgCtKwh: Double?
    public var coverage: Double?
    public var totalNetEur: Double
    public var totalGrossEur: Double
    public var avgCtKwhGross: Double
    public var energyNetEur: Double
    public var feesNetEur: Double
    public var verdict: String
    public var problems: Int
    public var checkedAt: String

    public enum CodingKeys: String, CodingKey {
        case number
        case periodLabel = "period_label"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case issuedOn = "issued_on"
        case kwh
        case measuredKwh = "measured_kwh"
        case measuredAvgCtKwh = "measured_avg_ct_kwh"
        case coverage
        case totalNetEur = "total_net_eur"
        case totalGrossEur = "total_gross_eur"
        case avgCtKwhGross = "avg_ct_kwh_gross"
        case energyNetEur = "energy_net_eur"
        case feesNetEur = "fees_net_eur"
        case verdict
        case problems
        case checkedAt = "checked_at"
    }

    public init(number: String, periodLabel: String, periodStart: String, periodEnd: String, issuedOn: String, kwh: Double, measuredKwh: Double? = nil, measuredAvgCtKwh: Double? = nil, coverage: Double? = nil, totalNetEur: Double, totalGrossEur: Double, avgCtKwhGross: Double, energyNetEur: Double, feesNetEur: Double, verdict: String, problems: Int, checkedAt: String) {
        self.number = number
        self.periodLabel = periodLabel
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.issuedOn = issuedOn
        self.kwh = kwh
        self.measuredKwh = measuredKwh
        self.measuredAvgCtKwh = measuredAvgCtKwh
        self.coverage = coverage
        self.totalNetEur = totalNetEur
        self.totalGrossEur = totalGrossEur
        self.avgCtKwhGross = avgCtKwhGross
        self.energyNetEur = energyNetEur
        self.feesNetEur = feesNetEur
        self.verdict = verdict
        self.problems = problems
        self.checkedAt = checkedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.number = try c.decode(String.self, forKey: .number)
        self.periodLabel = try c.decode(String.self, forKey: .periodLabel)
        self.periodStart = try c.decode(String.self, forKey: .periodStart)
        self.periodEnd = try c.decode(String.self, forKey: .periodEnd)
        self.issuedOn = try c.decode(String.self, forKey: .issuedOn)
        self.kwh = try c.decode(Double.self, forKey: .kwh)
        self.measuredKwh = try c.decodeIfPresent(Double.self, forKey: .measuredKwh)
        self.measuredAvgCtKwh = try c.decodeIfPresent(Double.self, forKey: .measuredAvgCtKwh)
        self.coverage = try c.decodeIfPresent(Double.self, forKey: .coverage)
        self.totalNetEur = try c.decode(Double.self, forKey: .totalNetEur)
        self.totalGrossEur = try c.decode(Double.self, forKey: .totalGrossEur)
        self.avgCtKwhGross = try c.decode(Double.self, forKey: .avgCtKwhGross)
        self.energyNetEur = try c.decode(Double.self, forKey: .energyNetEur)
        self.feesNetEur = try c.decode(Double.self, forKey: .feesNetEur)
        self.verdict = try c.decode(String.self, forKey: .verdict)
        self.problems = try c.decode(Int.self, forKey: .problems)
        self.checkedAt = try c.decode(String.self, forKey: .checkedAt)
    }
}

/// Ein Moebel, ein Geraet, ein Stueck Treppe. Welche Felder gelten, sagt `kind`; die Anzeige
/// nimmt fuer fehlende Masse ihre Voreinstellungen. Geprueft wird hier nur, dass die Zahlen endlich
/// sind und die Art bekannt ist.
public struct Item: Codable, Sendable, Hashable {
    public var kind: ItemKindWahl
    public var tone: ItemToneWahl?
    public var x: Double?
    public var z: Double?
    public var y: Double?
    public var b: Double?
    public var t: Double?
    public var h: Double?
    public var r: Double?
    public var x0: Double?
    public var z0: Double?
    public var x1: Double?
    public var z1: Double?
    public var y1: Double?
    public var steps: Int?
    public var head: ItemHeadWahl?
    public var dir: ItemDirWahl?
    public var angle: Double?
    public var device: ItemDeviceWahl?
    public var label: String?
    public var points: [[Double]]?

    public init(kind: ItemKindWahl, tone: ItemToneWahl? = nil, x: Double? = nil, z: Double? = nil, y: Double? = nil, b: Double? = nil, t: Double? = nil, h: Double? = nil, r: Double? = nil, x0: Double? = nil, z0: Double? = nil, x1: Double? = nil, z1: Double? = nil, y1: Double? = nil, steps: Int? = nil, head: ItemHeadWahl? = nil, dir: ItemDirWahl? = nil, angle: Double? = nil, device: ItemDeviceWahl? = nil, label: String? = nil, points: [[Double]]? = nil) {
        self.kind = kind
        self.tone = tone
        self.x = x
        self.z = z
        self.y = y
        self.b = b
        self.t = t
        self.h = h
        self.r = r
        self.x0 = x0
        self.z0 = z0
        self.x1 = x1
        self.z1 = z1
        self.y1 = y1
        self.steps = steps
        self.head = head
        self.dir = dir
        self.angle = angle
        self.device = device
        self.label = label
        self.points = points
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try c.decode(ItemKindWahl.self, forKey: .kind)
        self.tone = try c.decodeIfPresent(ItemToneWahl.self, forKey: .tone)
        self.x = try c.decodeIfPresent(Double.self, forKey: .x)
        self.z = try c.decodeIfPresent(Double.self, forKey: .z)
        self.y = try c.decodeIfPresent(Double.self, forKey: .y)
        self.b = try c.decodeIfPresent(Double.self, forKey: .b)
        self.t = try c.decodeIfPresent(Double.self, forKey: .t)
        self.h = try c.decodeIfPresent(Double.self, forKey: .h)
        self.r = try c.decodeIfPresent(Double.self, forKey: .r)
        self.x0 = try c.decodeIfPresent(Double.self, forKey: .x0)
        self.z0 = try c.decodeIfPresent(Double.self, forKey: .z0)
        self.x1 = try c.decodeIfPresent(Double.self, forKey: .x1)
        self.z1 = try c.decodeIfPresent(Double.self, forKey: .z1)
        self.y1 = try c.decodeIfPresent(Double.self, forKey: .y1)
        self.steps = try c.decodeIfPresent(Int.self, forKey: .steps)
        self.head = try c.decodeIfPresent(ItemHeadWahl.self, forKey: .head)
        self.dir = try c.decodeIfPresent(ItemDirWahl.self, forKey: .dir)
        self.angle = try c.decodeIfPresent(Double.self, forKey: .angle)
        self.device = try c.decodeIfPresent(ItemDeviceWahl.self, forKey: .device)
        self.label = try c.decodeIfPresent(String.self, forKey: .label)
        self.points = try c.decodeIfPresent([[Double]].self, forKey: .points)
    }
}

public struct KanteAnsicht: Codable, Sendable, Hashable {
    public var von: String
    public var nach: String
    public var signal: String
    public var art: KanteAnsichtArtWahl
    public var vorzeichen: KanteAnsichtVorzeichenWahl?

    public init(von: String, nach: String, signal: String, art: KanteAnsichtArtWahl, vorzeichen: KanteAnsichtVorzeichenWahl? = nil) {
        self.von = von
        self.nach = nach
        self.signal = signal
        self.art = art
        self.vorzeichen = vorzeichen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.von = try c.decode(String.self, forKey: .von)
        self.nach = try c.decode(String.self, forKey: .nach)
        self.signal = try c.decode(String.self, forKey: .signal)
        self.art = try c.decode(KanteAnsichtArtWahl.self, forKey: .art)
        self.vorzeichen = try c.decodeIfPresent(KanteAnsichtVorzeichenWahl.self, forKey: .vorzeichen)
    }
}

/// Die gemessene Kennlinie der Wärmepumpe: Messpunkte, Ausgleich und die bisherige Annahme.
///
/// Die Punkte sind Abschätzungen aus Durchfluss, Spreizung und Zähler; warum, steht in
/// `hinweise_de`.
public struct KennlinieOut: Codable, Sendable, Hashable {
    public var now: String
    public var von: String
    public var bis: String
    public var tage: Int
    public var punkte: [KennlinienPunktOut]
    public var fit: KennlinienFitOut?
    public var hub: KennlinienHubOut?
    public var fehltDe: String?
    public var annahme: [KennlinienAnnahmeOut]
    public var annahmeVorlaufC: Double?
    public var bilanz: KennlinienBilanzOut?
    public var hinweiseDe: [String]

    public enum CodingKeys: String, CodingKey {
        case now
        case von
        case bis
        case tage
        case punkte
        case fit
        case hub
        case fehltDe = "fehlt_de"
        case annahme
        case annahmeVorlaufC = "annahme_vorlauf_c"
        case bilanz
        case hinweiseDe = "hinweise_de"
    }

    public init(now: String, von: String, bis: String, tage: Int, punkte: [KennlinienPunktOut] = [], fit: KennlinienFitOut? = nil, hub: KennlinienHubOut? = nil, fehltDe: String? = nil, annahme: [KennlinienAnnahmeOut] = [], annahmeVorlaufC: Double? = nil, bilanz: KennlinienBilanzOut? = nil, hinweiseDe: [String] = []) {
        self.now = now
        self.von = von
        self.bis = bis
        self.tage = tage
        self.punkte = punkte
        self.fit = fit
        self.hub = hub
        self.fehltDe = fehltDe
        self.annahme = annahme
        self.annahmeVorlaufC = annahmeVorlaufC
        self.bilanz = bilanz
        self.hinweiseDe = hinweiseDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.now = try c.decode(String.self, forKey: .now)
        self.von = try c.decode(String.self, forKey: .von)
        self.bis = try c.decode(String.self, forKey: .bis)
        self.tage = try c.decode(Int.self, forKey: .tage)
        self.punkte = try c.decodeIfPresent([KennlinienPunktOut].self, forKey: .punkte) ?? []
        self.fit = try c.decodeIfPresent(KennlinienFitOut.self, forKey: .fit)
        self.hub = try c.decodeIfPresent(KennlinienHubOut.self, forKey: .hub)
        self.fehltDe = try c.decodeIfPresent(String.self, forKey: .fehltDe)
        self.annahme = try c.decodeIfPresent([KennlinienAnnahmeOut].self, forKey: .annahme) ?? []
        self.annahmeVorlaufC = try c.decodeIfPresent(Double.self, forKey: .annahmeVorlaufC)
        self.bilanz = try c.decodeIfPresent(KennlinienBilanzOut.self, forKey: .bilanz)
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
    }
}

public struct KennliniePunkt: Codable, Sendable, Hashable {
    public var w: Double
    public var db: Double
    public var grad: Double

    public init(w: Double, db: Double, grad: Double) {
        self.w = w
        self.db = db
        self.grad = grad
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.w = try c.decode(Double.self, forKey: .w)
        self.db = try c.decode(Double.self, forKey: .db)
        self.grad = try c.decode(Double.self, forKey: .grad)
    }
}

/// Ein Punkt der Kennlinie, mit der der Fahrplan bisher rechnet.
public struct KennlinienAnnahmeOut: Codable, Sendable, Hashable {
    public var aussenC: Double
    public var cop: Double

    public enum CodingKeys: String, CodingKey {
        case aussenC = "aussen_c"
        case cop
    }

    public init(aussenC: Double, cop: Double) {
        self.aussenC = aussenC
        self.cop = cop
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aussenC = try c.decode(Double.self, forKey: .aussenC)
        self.cop = try c.decode(Double.self, forKey: .cop)
    }
}

/// Wo die Minuten des Zeitraums geblieben sind (`hems_core.thermal.kennlinie.Bilanz`).
///
/// Von den Minuten, in denen die Maschine heizte, zählt nur ein Teil: nicht der Anlauf, nicht
/// die mit Heizstab, nicht die ohne einen nötigen Wert. Die Zahlen hier addieren sich zu
/// `heizen`; eine leere Kennlinie zeigt damit, woran es liegt.
public struct KennlinienBilanzOut: Codable, Sendable, Hashable {
    public var minuten: Int
    public var heizen: Int
    public var anlauf: Int
    public var zusatz: Int
    public var ohneWert: Int
    public var ohneWaerme: Int
    public var gueltig: Int
    public var fenster: Int
    public var punkte: Int
    public var unglaubwuerdig: Int
    public var fehlt: [String: Int]
    public var verhaeltnis: Double?
    public var satzDe: String?

    public enum CodingKeys: String, CodingKey {
        case minuten
        case heizen
        case anlauf
        case zusatz
        case ohneWert = "ohne_wert"
        case ohneWaerme = "ohne_waerme"
        case gueltig
        case fenster
        case punkte
        case unglaubwuerdig
        case fehlt
        case verhaeltnis
        case satzDe = "satz_de"
    }

    public init(minuten: Int, heizen: Int, anlauf: Int, zusatz: Int, ohneWert: Int, ohneWaerme: Int, gueltig: Int, fenster: Int, punkte: Int, unglaubwuerdig: Int, fehlt: [String: Int] = [:], verhaeltnis: Double? = nil, satzDe: String? = nil) {
        self.minuten = minuten
        self.heizen = heizen
        self.anlauf = anlauf
        self.zusatz = zusatz
        self.ohneWert = ohneWert
        self.ohneWaerme = ohneWaerme
        self.gueltig = gueltig
        self.fenster = fenster
        self.punkte = punkte
        self.unglaubwuerdig = unglaubwuerdig
        self.fehlt = fehlt
        self.verhaeltnis = verhaeltnis
        self.satzDe = satzDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.minuten = try c.decode(Int.self, forKey: .minuten)
        self.heizen = try c.decode(Int.self, forKey: .heizen)
        self.anlauf = try c.decode(Int.self, forKey: .anlauf)
        self.zusatz = try c.decode(Int.self, forKey: .zusatz)
        self.ohneWert = try c.decode(Int.self, forKey: .ohneWert)
        self.ohneWaerme = try c.decode(Int.self, forKey: .ohneWaerme)
        self.gueltig = try c.decode(Int.self, forKey: .gueltig)
        self.fenster = try c.decode(Int.self, forKey: .fenster)
        self.punkte = try c.decode(Int.self, forKey: .punkte)
        self.unglaubwuerdig = try c.decode(Int.self, forKey: .unglaubwuerdig)
        self.fehlt = try c.decodeIfPresent([String: Int].self, forKey: .fehlt) ?? [:]
        self.verhaeltnis = try c.decodeIfPresent(Double.self, forKey: .verhaeltnis)
        self.satzDe = try c.decodeIfPresent(String.self, forKey: .satzDe)
    }
}

/// COP = a + b_aussen * Außentemperatur + c_vorlauf * Vorlauftemperatur, kleinste Quadrate.
///
/// `art` sagt, welche Terme sich aus den Punkten bestimmen ließen: `ebene` beide, `aussen`
/// oder `vorlauf` nur einer, `mittel` keiner.
public struct KennlinienFitOut: Codable, Sendable, Hashable {
    public var art: KennlinienFitOutArtWahl
    public var a: Double
    public var bAussen: Double
    public var cVorlauf: Double
    public var n: Int
    public var rmse: Double
    public var r2: Double?
    public var aussenVonC: Double
    public var aussenBisC: Double
    public var vorlaufVonC: Double
    public var vorlaufBisC: Double
    public var formelDe: String
    public var geltungDe: String

    public enum CodingKeys: String, CodingKey {
        case art
        case a
        case bAussen = "b_aussen"
        case cVorlauf = "c_vorlauf"
        case n
        case rmse
        case r2
        case aussenVonC = "aussen_von_c"
        case aussenBisC = "aussen_bis_c"
        case vorlaufVonC = "vorlauf_von_c"
        case vorlaufBisC = "vorlauf_bis_c"
        case formelDe = "formel_de"
        case geltungDe = "geltung_de"
    }

    public init(art: KennlinienFitOutArtWahl, a: Double, bAussen: Double, cVorlauf: Double, n: Int, rmse: Double, r2: Double? = nil, aussenVonC: Double, aussenBisC: Double, vorlaufVonC: Double, vorlaufBisC: Double, formelDe: String, geltungDe: String) {
        self.art = art
        self.a = a
        self.bAussen = bAussen
        self.cVorlauf = cVorlauf
        self.n = n
        self.rmse = rmse
        self.r2 = r2
        self.aussenVonC = aussenVonC
        self.aussenBisC = aussenBisC
        self.vorlaufVonC = vorlaufVonC
        self.vorlaufBisC = vorlaufBisC
        self.formelDe = formelDe
        self.geltungDe = geltungDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(KennlinienFitOutArtWahl.self, forKey: .art)
        self.a = try c.decode(Double.self, forKey: .a)
        self.bAussen = try c.decode(Double.self, forKey: .bAussen)
        self.cVorlauf = try c.decode(Double.self, forKey: .cVorlauf)
        self.n = try c.decode(Int.self, forKey: .n)
        self.rmse = try c.decode(Double.self, forKey: .rmse)
        self.r2 = try c.decodeIfPresent(Double.self, forKey: .r2)
        self.aussenVonC = try c.decode(Double.self, forKey: .aussenVonC)
        self.aussenBisC = try c.decode(Double.self, forKey: .aussenBisC)
        self.vorlaufVonC = try c.decode(Double.self, forKey: .vorlaufVonC)
        self.vorlaufBisC = try c.decode(Double.self, forKey: .vorlaufBisC)
        self.formelDe = try c.decode(String.self, forKey: .formelDe)
        self.geltungDe = try c.decode(String.self, forKey: .geltungDe)
    }
}

/// COP = a + b_hub * Hub, mit Hub = Vorlauf minus Außentemperatur (`hems_core.thermal.kennlinie`).
///
/// `art` ist `gerade`, wenn der Hub genug streut, sonst `mittel`. Der Gütegrad ist der Anteil
/// an der Arbeitszahl eines idealen Kreisprozesses bei denselben Temperaturen.
public struct KennlinienHubOut: Codable, Sendable, Hashable {
    public var art: KennlinienHubOutArtWahl
    public var a: Double
    public var bHub: Double
    public var n: Int
    public var rmse: Double
    public var r2: Double?
    public var hubVonK: Double
    public var hubBisK: Double
    public var guetegrad: Double?
    public var formelDe: String
    public var geltungDe: String
    public var gueteDe: String?

    public enum CodingKeys: String, CodingKey {
        case art
        case a
        case bHub = "b_hub"
        case n
        case rmse
        case r2
        case hubVonK = "hub_von_k"
        case hubBisK = "hub_bis_k"
        case guetegrad
        case formelDe = "formel_de"
        case geltungDe = "geltung_de"
        case gueteDe = "guete_de"
    }

    public init(art: KennlinienHubOutArtWahl, a: Double, bHub: Double, n: Int, rmse: Double, r2: Double? = nil, hubVonK: Double, hubBisK: Double, guetegrad: Double? = nil, formelDe: String, geltungDe: String, gueteDe: String? = nil) {
        self.art = art
        self.a = a
        self.bHub = bHub
        self.n = n
        self.rmse = rmse
        self.r2 = r2
        self.hubVonK = hubVonK
        self.hubBisK = hubBisK
        self.guetegrad = guetegrad
        self.formelDe = formelDe
        self.geltungDe = geltungDe
        self.gueteDe = gueteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(KennlinienHubOutArtWahl.self, forKey: .art)
        self.a = try c.decode(Double.self, forKey: .a)
        self.bHub = try c.decode(Double.self, forKey: .bHub)
        self.n = try c.decode(Int.self, forKey: .n)
        self.rmse = try c.decode(Double.self, forKey: .rmse)
        self.r2 = try c.decodeIfPresent(Double.self, forKey: .r2)
        self.hubVonK = try c.decode(Double.self, forKey: .hubVonK)
        self.hubBisK = try c.decode(Double.self, forKey: .hubBisK)
        self.guetegrad = try c.decodeIfPresent(Double.self, forKey: .guetegrad)
        self.formelDe = try c.decode(String.self, forKey: .formelDe)
        self.geltungDe = try c.decode(String.self, forKey: .geltungDe)
        self.gueteDe = try c.decodeIfPresent(String.self, forKey: .gueteDe)
    }
}

/// Ein Fenster im eingeschwungenen Heizbetrieb (`hems_core.thermal.kennlinie`).
public struct KennlinienPunktOut: Codable, Sendable, Hashable {
    public var at: String
    public var minuten: Int
    public var aussenC: Double
    public var vorlaufC: Double
    public var cop: Double
    public var waermeKw: Double
    public var stromKw: Double
    public var ventil: Int?

    public enum CodingKeys: String, CodingKey {
        case at
        case minuten
        case aussenC = "aussen_c"
        case vorlaufC = "vorlauf_c"
        case cop
        case waermeKw = "waerme_kw"
        case stromKw = "strom_kw"
        case ventil
    }

    public init(at: String, minuten: Int, aussenC: Double, vorlaufC: Double, cop: Double, waermeKw: Double, stromKw: Double, ventil: Int? = nil) {
        self.at = at
        self.minuten = minuten
        self.aussenC = aussenC
        self.vorlaufC = vorlaufC
        self.cop = cop
        self.waermeKw = waermeKw
        self.stromKw = stromKw
        self.ventil = ventil
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.minuten = try c.decode(Int.self, forKey: .minuten)
        self.aussenC = try c.decode(Double.self, forKey: .aussenC)
        self.vorlaufC = try c.decode(Double.self, forKey: .vorlaufC)
        self.cop = try c.decode(Double.self, forKey: .cop)
        self.waermeKw = try c.decode(Double.self, forKey: .waermeKw)
        self.stromKw = try c.decode(Double.self, forKey: .stromKw)
        self.ventil = try c.decodeIfPresent(Int.self, forKey: .ventil)
    }
}

/// Was der Freigabekontakt K1 auslöst: die Ereignisstudie über die letzten `days` Tage.
///
/// Jeder Schließvorgang ist ein Ereignis; `ereignisse` enthält zu jedem die Leistung der
/// Wärmepumpe von einer halben Stunde davor bis zwei Stunden danach, `faecher` legt sie am
/// Nullpunkt übereinander. `quote` ist der Anteil der Schließvorgänge bei stehender Maschine, auf
/// die binnen `folge_min` Minuten ein Anlauf folgte, `vergleich.quote` derselbe Anteil ohne
/// Schließvorgang zur selben Tageszeit.
///
/// Das Urteil steht in `urteil` und `urteil_de` und wird hier gefällt, nicht in der Oberfläche.
/// Es ist ein Zusammenhang in der Zeit und keine Ursache; warum, steht in `methode_de`.
public struct KontaktwirkungOut: Codable, Sendable, Hashable {
    public var von: String?
    public var bis: String?
    public var schwelleKw: Double
    public var vorMin: Int?
    public var nachMin: Int?
    public var folgeMin: Int?
    public var ereignisse: [Ereignis]
    public var faecher: Faecher
    public var n: Int?
    public var nLiefSchon: Int?
    public var nAuswertbar: Int?
    public var gefolgt: Int?
    public var quote: Double?
    public var quoteLo: Double?
    public var quoteHi: Double?
    public var vergleich: Vergleich
    public var verzoegerungMedianMin: Double?
    public var nachlaufMedianMin: Double?
    public var nachlaufN: Int?
    public var abdeckungKontakt: Double?
    public var abdeckungLeistung: Double?
    public var urteil: String?
    public var urteilDe: String?
    public var hinweiseDe: [String]
    public var methodeDe: [String]
    public var days: Int

    public enum CodingKeys: String, CodingKey {
        case von
        case bis
        case schwelleKw = "schwelle_kw"
        case vorMin = "vor_min"
        case nachMin = "nach_min"
        case folgeMin = "folge_min"
        case ereignisse
        case faecher
        case n
        case nLiefSchon = "n_lief_schon"
        case nAuswertbar = "n_auswertbar"
        case gefolgt
        case quote
        case quoteLo = "quote_lo"
        case quoteHi = "quote_hi"
        case vergleich
        case verzoegerungMedianMin = "verzoegerung_median_min"
        case nachlaufMedianMin = "nachlauf_median_min"
        case nachlaufN = "nachlauf_n"
        case abdeckungKontakt = "abdeckung_kontakt"
        case abdeckungLeistung = "abdeckung_leistung"
        case urteil
        case urteilDe = "urteil_de"
        case hinweiseDe = "hinweise_de"
        case methodeDe = "methode_de"
        case days
    }

    public init(von: String? = nil, bis: String? = nil, schwelleKw: Double, vorMin: Int? = nil, nachMin: Int? = nil, folgeMin: Int? = nil, ereignisse: [Ereignis] = [], faecher: Faecher, n: Int? = nil, nLiefSchon: Int? = nil, nAuswertbar: Int? = nil, gefolgt: Int? = nil, quote: Double? = nil, quoteLo: Double? = nil, quoteHi: Double? = nil, vergleich: Vergleich, verzoegerungMedianMin: Double? = nil, nachlaufMedianMin: Double? = nil, nachlaufN: Int? = nil, abdeckungKontakt: Double? = nil, abdeckungLeistung: Double? = nil, urteil: String? = nil, urteilDe: String? = nil, hinweiseDe: [String] = [], methodeDe: [String] = [], days: Int) {
        self.von = von
        self.bis = bis
        self.schwelleKw = schwelleKw
        self.vorMin = vorMin
        self.nachMin = nachMin
        self.folgeMin = folgeMin
        self.ereignisse = ereignisse
        self.faecher = faecher
        self.n = n
        self.nLiefSchon = nLiefSchon
        self.nAuswertbar = nAuswertbar
        self.gefolgt = gefolgt
        self.quote = quote
        self.quoteLo = quoteLo
        self.quoteHi = quoteHi
        self.vergleich = vergleich
        self.verzoegerungMedianMin = verzoegerungMedianMin
        self.nachlaufMedianMin = nachlaufMedianMin
        self.nachlaufN = nachlaufN
        self.abdeckungKontakt = abdeckungKontakt
        self.abdeckungLeistung = abdeckungLeistung
        self.urteil = urteil
        self.urteilDe = urteilDe
        self.hinweiseDe = hinweiseDe
        self.methodeDe = methodeDe
        self.days = days
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.von = try c.decodeIfPresent(String.self, forKey: .von)
        self.bis = try c.decodeIfPresent(String.self, forKey: .bis)
        self.schwelleKw = try c.decode(Double.self, forKey: .schwelleKw)
        self.vorMin = try c.decodeIfPresent(Int.self, forKey: .vorMin)
        self.nachMin = try c.decodeIfPresent(Int.self, forKey: .nachMin)
        self.folgeMin = try c.decodeIfPresent(Int.self, forKey: .folgeMin)
        self.ereignisse = try c.decodeIfPresent([Ereignis].self, forKey: .ereignisse) ?? []
        self.faecher = try c.decode(Faecher.self, forKey: .faecher)
        self.n = try c.decodeIfPresent(Int.self, forKey: .n)
        self.nLiefSchon = try c.decodeIfPresent(Int.self, forKey: .nLiefSchon)
        self.nAuswertbar = try c.decodeIfPresent(Int.self, forKey: .nAuswertbar)
        self.gefolgt = try c.decodeIfPresent(Int.self, forKey: .gefolgt)
        self.quote = try c.decodeIfPresent(Double.self, forKey: .quote)
        self.quoteLo = try c.decodeIfPresent(Double.self, forKey: .quoteLo)
        self.quoteHi = try c.decodeIfPresent(Double.self, forKey: .quoteHi)
        self.vergleich = try c.decode(Vergleich.self, forKey: .vergleich)
        self.verzoegerungMedianMin = try c.decodeIfPresent(Double.self, forKey: .verzoegerungMedianMin)
        self.nachlaufMedianMin = try c.decodeIfPresent(Double.self, forKey: .nachlaufMedianMin)
        self.nachlaufN = try c.decodeIfPresent(Int.self, forKey: .nachlaufN)
        self.abdeckungKontakt = try c.decodeIfPresent(Double.self, forKey: .abdeckungKontakt)
        self.abdeckungLeistung = try c.decodeIfPresent(Double.self, forKey: .abdeckungLeistung)
        self.urteil = try c.decodeIfPresent(String.self, forKey: .urteil)
        self.urteilDe = try c.decodeIfPresent(String.self, forKey: .urteilDe)
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
        self.methodeDe = try c.decodeIfPresent([String].self, forKey: .methodeDe) ?? []
        self.days = try c.decode(Int.self, forKey: .days)
    }
}

/// Grenzkosten der Wärme an diesem Arbeitspunkt - die Zahl, nach der zugeordnet wird.
public struct Kostenpunkt: Codable, Sendable, Hashable {
    public var cop: Double
    public var waermepumpeCtKwh: Double
    public var ofenCtKwh: Double
    public var copUmschalt: Double
    public var umschaltAussenC: Double?

    public enum CodingKeys: String, CodingKey {
        case cop
        case waermepumpeCtKwh = "waermepumpe_ct_kwh"
        case ofenCtKwh = "ofen_ct_kwh"
        case copUmschalt = "cop_umschalt"
        case umschaltAussenC = "umschalt_aussen_c"
    }

    public init(cop: Double, waermepumpeCtKwh: Double, ofenCtKwh: Double, copUmschalt: Double, umschaltAussenC: Double? = nil) {
        self.cop = cop
        self.waermepumpeCtKwh = waermepumpeCtKwh
        self.ofenCtKwh = ofenCtKwh
        self.copUmschalt = copUmschalt
        self.umschaltAussenC = umschaltAussenC
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.cop = try c.decode(Double.self, forKey: .cop)
        self.waermepumpeCtKwh = try c.decode(Double.self, forKey: .waermepumpeCtKwh)
        self.ofenCtKwh = try c.decode(Double.self, forKey: .ofenCtKwh)
        self.copUmschalt = try c.decode(Double.self, forKey: .copUmschalt)
        self.umschaltAussenC = try c.decodeIfPresent(Double.self, forKey: .umschaltAussenC)
    }
}

/// Ein Kreis der Kaskade mit seinem Entwurf.
public struct KreisAnsicht: Codable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var regelgroesse: String
    public var stellgroesse: String
    public var reglerBlock: String
    public var messglied: String?
    public var taktS: Double
    public var art: KreisAnsichtArtWahl
    public var erklaerung: [String]
    public var strecke: StreckeAnsicht?
    public var regler: ReglerAnsicht?
    public var reserven: ReservenAnsicht?
    public var kennlinie: [KennliniePunkt]
    public var hystereseK: Double?
    public var hinweis: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case regelgroesse
        case stellgroesse
        case reglerBlock = "regler_block"
        case messglied
        case taktS = "takt_s"
        case art
        case erklaerung
        case strecke
        case regler
        case reserven
        case kennlinie
        case hystereseK = "hysterese_k"
        case hinweis
    }

    public init(id: String, name: String, regelgroesse: String, stellgroesse: String, reglerBlock: String, messglied: String? = nil, taktS: Double, art: KreisAnsichtArtWahl, erklaerung: [String] = [], strecke: StreckeAnsicht? = nil, regler: ReglerAnsicht? = nil, reserven: ReservenAnsicht? = nil, kennlinie: [KennliniePunkt] = [], hystereseK: Double? = nil, hinweis: String? = nil) {
        self.id = id
        self.name = name
        self.regelgroesse = regelgroesse
        self.stellgroesse = stellgroesse
        self.reglerBlock = reglerBlock
        self.messglied = messglied
        self.taktS = taktS
        self.art = art
        self.erklaerung = erklaerung
        self.strecke = strecke
        self.regler = regler
        self.reserven = reserven
        self.kennlinie = kennlinie
        self.hystereseK = hystereseK
        self.hinweis = hinweis
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.regelgroesse = try c.decode(String.self, forKey: .regelgroesse)
        self.stellgroesse = try c.decode(String.self, forKey: .stellgroesse)
        self.reglerBlock = try c.decode(String.self, forKey: .reglerBlock)
        self.messglied = try c.decodeIfPresent(String.self, forKey: .messglied)
        self.taktS = try c.decode(Double.self, forKey: .taktS)
        self.art = try c.decode(KreisAnsichtArtWahl.self, forKey: .art)
        self.erklaerung = try c.decodeIfPresent([String].self, forKey: .erklaerung) ?? []
        self.strecke = try c.decodeIfPresent(StreckeAnsicht.self, forKey: .strecke)
        self.regler = try c.decodeIfPresent(ReglerAnsicht.self, forKey: .regler)
        self.reserven = try c.decodeIfPresent(ReservenAnsicht.self, forKey: .reserven)
        self.kennlinie = try c.decodeIfPresent([KennliniePunkt].self, forKey: .kennlinie) ?? []
        self.hystereseK = try c.decodeIfPresent(Double.self, forKey: .hystereseK)
        self.hinweis = try c.decodeIfPresent(String.self, forKey: .hinweis)
    }
}

/// Eine der Linien: ihre Summe, und je Viertelstunde, woraus sie entstand.
public struct Linie: Codable, Sendable, Hashable {
    public var key: String
    public var nameDe: String
    public var verfuegbar: Bool?
    public var grundDe: String?
    public var geschaetzt: Bool?
    public var eur: Double?
    public var stromEur: Double?
    public var ofenEur: Double?
    public var wpKwh: Double?
    public var ctJeKwh: Double?
    public var wpH: Double?
    public var ofenH: Double?
    public var wpKwhJe: [Double?]
    public var ofenJe: [Double?]
    public var eurJe: [Double?]
    public var eurKumuliert: [Double?]

    public enum CodingKeys: String, CodingKey {
        case key
        case nameDe = "name_de"
        case verfuegbar
        case grundDe = "grund_de"
        case geschaetzt
        case eur
        case stromEur = "strom_eur"
        case ofenEur = "ofen_eur"
        case wpKwh = "wp_kwh"
        case ctJeKwh = "ct_je_kwh"
        case wpH = "wp_h"
        case ofenH = "ofen_h"
        case wpKwhJe = "wp_kwh_je"
        case ofenJe = "ofen_je"
        case eurJe = "eur_je"
        case eurKumuliert = "eur_kumuliert"
    }

    public init(key: String, nameDe: String, verfuegbar: Bool? = nil, grundDe: String? = nil, geschaetzt: Bool? = nil, eur: Double? = nil, stromEur: Double? = nil, ofenEur: Double? = nil, wpKwh: Double? = nil, ctJeKwh: Double? = nil, wpH: Double? = nil, ofenH: Double? = nil, wpKwhJe: [Double?] = [], ofenJe: [Double?] = [], eurJe: [Double?] = [], eurKumuliert: [Double?] = []) {
        self.key = key
        self.nameDe = nameDe
        self.verfuegbar = verfuegbar
        self.grundDe = grundDe
        self.geschaetzt = geschaetzt
        self.eur = eur
        self.stromEur = stromEur
        self.ofenEur = ofenEur
        self.wpKwh = wpKwh
        self.ctJeKwh = ctJeKwh
        self.wpH = wpH
        self.ofenH = ofenH
        self.wpKwhJe = wpKwhJe
        self.ofenJe = ofenJe
        self.eurJe = eurJe
        self.eurKumuliert = eurKumuliert
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.nameDe = try c.decode(String.self, forKey: .nameDe)
        self.verfuegbar = try c.decodeIfPresent(Bool.self, forKey: .verfuegbar)
        self.grundDe = try c.decodeIfPresent(String.self, forKey: .grundDe)
        self.geschaetzt = try c.decodeIfPresent(Bool.self, forKey: .geschaetzt)
        self.eur = try c.decodeIfPresent(Double.self, forKey: .eur)
        self.stromEur = try c.decodeIfPresent(Double.self, forKey: .stromEur)
        self.ofenEur = try c.decodeIfPresent(Double.self, forKey: .ofenEur)
        self.wpKwh = try c.decodeIfPresent(Double.self, forKey: .wpKwh)
        self.ctJeKwh = try c.decodeIfPresent(Double.self, forKey: .ctJeKwh)
        self.wpH = try c.decodeIfPresent(Double.self, forKey: .wpH)
        self.ofenH = try c.decodeIfPresent(Double.self, forKey: .ofenH)
        self.wpKwhJe = try c.decodeIfPresent([Double?].self, forKey: .wpKwhJe) ?? []
        self.ofenJe = try c.decodeIfPresent([Double?].self, forKey: .ofenJe) ?? []
        self.eurJe = try c.decodeIfPresent([Double?].self, forKey: .eurJe) ?? []
        self.eurKumuliert = try c.decodeIfPresent([Double?].self, forKey: .eurKumuliert) ?? []
    }
}

public struct LiveStateOut: Codable, Sendable, Hashable {
    public var snapshot: EnergySnapshot
    public var buffer: BufferState
    public var heatPump: HeatPumpState
    public var decision: Decision?
    public var operatingMode: OperatingMode
    public var stove: StoveLiveOut?
    public var priceRank: Double?
    public var todayKwh: [String: Double]
    public var alarm: AlarmOut?
    public var system: SystemStatusOut

    public enum CodingKeys: String, CodingKey {
        case snapshot
        case buffer
        case heatPump = "heat_pump"
        case decision
        case operatingMode = "operating_mode"
        case stove
        case priceRank = "price_rank"
        case todayKwh = "today_kwh"
        case alarm
        case system
    }

    public init(snapshot: EnergySnapshot, buffer: BufferState, heatPump: HeatPumpState, decision: Decision? = nil, operatingMode: OperatingMode, stove: StoveLiveOut? = nil, priceRank: Double? = nil, todayKwh: [String: Double] = [:], alarm: AlarmOut? = nil, system: SystemStatusOut) {
        self.snapshot = snapshot
        self.buffer = buffer
        self.heatPump = heatPump
        self.decision = decision
        self.operatingMode = operatingMode
        self.stove = stove
        self.priceRank = priceRank
        self.todayKwh = todayKwh
        self.alarm = alarm
        self.system = system
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.snapshot = try c.decode(EnergySnapshot.self, forKey: .snapshot)
        self.buffer = try c.decode(BufferState.self, forKey: .buffer)
        self.heatPump = try c.decode(HeatPumpState.self, forKey: .heatPump)
        self.decision = try c.decodeIfPresent(Decision.self, forKey: .decision)
        self.operatingMode = try c.decode(OperatingMode.self, forKey: .operatingMode)
        self.stove = try c.decodeIfPresent(StoveLiveOut.self, forKey: .stove)
        self.priceRank = try c.decodeIfPresent(Double.self, forKey: .priceRank)
        self.todayKwh = try c.decodeIfPresent([String: Double].self, forKey: .todayKwh) ?? [:]
        self.alarm = try c.decodeIfPresent(AlarmOut.self, forKey: .alarm)
        self.system = try c.decode(SystemStatusOut.self, forKey: .system)
    }
}

/// Was wir für den Abrechnungszeitraum selbst gemessen haben.
public struct MeasuredPeriod: Codable, Sendable, Hashable {
    public var importKwh: Double
    public var coverage: Double?
    public var avgPriceCtKwh: Double?

    public enum CodingKeys: String, CodingKey {
        case importKwh = "import_kwh"
        case coverage
        case avgPriceCtKwh = "avg_price_ct_kwh"
    }

    public init(importKwh: Double, coverage: Double? = nil, avgPriceCtKwh: Double? = nil) {
        self.importKwh = importKwh
        self.coverage = coverage
        self.avgPriceCtKwh = avgPriceCtKwh
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.importKwh = try c.decode(Double.self, forKey: .importKwh)
        self.coverage = try c.decodeIfPresent(Double.self, forKey: .coverage)
        self.avgPriceCtKwh = try c.decodeIfPresent(Double.self, forKey: .avgPriceCtKwh)
    }
}

public struct Messwert: Codable, Sendable, Hashable {
    public var value: Double?
    public var observedAt: String
    public var quality: Quality
    public var source: String

    public enum CodingKeys: String, CodingKey {
        case value
        case observedAt = "observed_at"
        case quality
        case source
    }

    public init(value: Double? = nil, observedAt: String, quality: Quality, source: String) {
        self.value = value
        self.observedAt = observedAt
        self.quality = quality
        self.source = source
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try c.decodeIfPresent(Double.self, forKey: .value)
        self.observedAt = try c.decode(String.self, forKey: .observedAt)
        self.quality = try c.decode(Quality.self, forKey: .quality)
        self.source = try c.decode(String.self, forKey: .source)
    }
}

/// Woraus der Arbeitsspeicher dieses Vorgangs besteht.
///
/// Der Dienst wird nach Arbeitsspeicher abgerechnet, und die Plattform nennt nur eine Summe je
/// Dienst. `rss_mb` ist diese Summe für die API, `types` beantwortet die Anschlussfrage: Liegt
/// irgendwo eine Million Zeilen herum, die dort nicht hingehört?
///
/// Die Differenz zwischen `rss_mb` und `tracked_mb` ist gross und in Ordnung: Interpreter,
/// Bibliotheken und der Speicher von C-Erweiterungen zählen nicht zum verwalteten Haufen.
public struct MemoryReportOut: Codable, Sendable, Hashable {
    public var rssMb: Double?
    public var peakMb: Double?
    public var objects: Int
    public var trackedMb: Double
    public var types: [MemoryTypeOut]
    public var poolDe: String
    public var noteDe: String

    public enum CodingKeys: String, CodingKey {
        case rssMb = "rss_mb"
        case peakMb = "peak_mb"
        case objects
        case trackedMb = "tracked_mb"
        case types
        case poolDe = "pool_de"
        case noteDe = "note_de"
    }

    public init(rssMb: Double? = nil, peakMb: Double? = nil, objects: Int, trackedMb: Double, types: [MemoryTypeOut] = [], poolDe: String, noteDe: String) {
        self.rssMb = rssMb
        self.peakMb = peakMb
        self.objects = objects
        self.trackedMb = trackedMb
        self.types = types
        self.poolDe = poolDe
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rssMb = try c.decodeIfPresent(Double.self, forKey: .rssMb)
        self.peakMb = try c.decodeIfPresent(Double.self, forKey: .peakMb)
        self.objects = try c.decode(Int.self, forKey: .objects)
        self.trackedMb = try c.decode(Double.self, forKey: .trackedMb)
        self.types = try c.decodeIfPresent([MemoryTypeOut].self, forKey: .types) ?? []
        self.poolDe = try c.decode(String.self, forKey: .poolDe)
        self.noteDe = try c.decode(String.self, forKey: .noteDe)
    }
}

/// Eine Objektgruppe im Python-Haufen: Typ, Anzahl, flache Größe.
public struct MemoryTypeOut: Codable, Sendable, Hashable {
    public var name: String
    public var count: Int
    public var mb: Double

    public init(name: String, count: Int, mb: Double) {
        self.name = name
        self.count = count
        self.mb = mb
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.count = try c.decode(Int.self, forKey: .count)
        self.mb = try c.decode(Double.self, forKey: .mb)
    }
}

/// Eine Schätzung zu einem Zeitpunkt, mit ihrer Unsicherheit. Eine Stützstelle des Verlaufs.
public struct Messpunkt: Codable, Sendable, Hashable {
    public var at: String
    public var wert: Double
    public var sigma: Double?
    public var n: Int?

    public init(at: String, wert: Double, sigma: Double? = nil, n: Int? = nil) {
        self.at = at
        self.wert = wert
        self.sigma = sigma
        self.n = n
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.wert = try c.decode(Double.self, forKey: .wert)
        self.sigma = try c.decodeIfPresent(Double.self, forKey: .sigma)
        self.n = try c.decodeIfPresent(Int.self, forKey: .n)
    }
}

public struct MorgenbriefIn: Codable, Sendable, Hashable {
    public var enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decode(Bool.self, forKey: .enabled)
    }
}

/// Der Morgenbrief: ob er verschickt wird und was heute darin stünde.
///
/// Eine Mitteilung am Morgen mit dem, was der Tag bringt: erwartete Sonne, günstigste und
/// teuerste Zeit für Netzstrom, geplante Läufe der Wärmepumpe. `zeilen` ist der Brief, wie er
/// jetzt verschickt würde, damit die Seite ihn zeigen kann, bevor jemand ihn einschaltet.
public struct MorgenbriefOut: Codable, Sendable, Hashable {
    public var enabled: Bool
    public var uhrzeit: String
    public var fuerDe: String?
    public var titel: String?
    public var zeilen: [String]
    public var hinweisDe: String?
    public var zuletztDe: String?
    public var geraete: Int?

    public enum CodingKeys: String, CodingKey {
        case enabled
        case uhrzeit
        case fuerDe = "fuer_de"
        case titel
        case zeilen
        case hinweisDe = "hinweis_de"
        case zuletztDe = "zuletzt_de"
        case geraete
    }

    public init(enabled: Bool, uhrzeit: String, fuerDe: String? = nil, titel: String? = nil, zeilen: [String] = [], hinweisDe: String? = nil, zuletztDe: String? = nil, geraete: Int? = nil) {
        self.enabled = enabled
        self.uhrzeit = uhrzeit
        self.fuerDe = fuerDe
        self.titel = titel
        self.zeilen = zeilen
        self.hinweisDe = hinweisDe
        self.zuletztDe = zuletztDe
        self.geraete = geraete
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decode(Bool.self, forKey: .enabled)
        self.uhrzeit = try c.decode(String.self, forKey: .uhrzeit)
        self.fuerDe = try c.decodeIfPresent(String.self, forKey: .fuerDe)
        self.titel = try c.decodeIfPresent(String.self, forKey: .titel)
        self.zeilen = try c.decodeIfPresent([String].self, forKey: .zeilen) ?? []
        self.hinweisDe = try c.decodeIfPresent(String.self, forKey: .hinweisDe)
        self.zuletztDe = try c.decodeIfPresent(String.self, forKey: .zuletztDe)
        self.geraete = try c.decodeIfPresent(Int.self, forKey: .geraete)
    }
}

/// Ein Ortstag in Euro: was der Fahrplan versprach, was er hielt, was der Tag kostete.
///
/// Fünf Linien, alle mit derselben Rechnung über dieselben Viertelstunden bewertet
/// (`verglichen`): der erste Fahrplan des Tages mit seinen eigenen Kosten (`versprochen`) und mit
/// den eingetretenen Werten (`erster`), der jeweils letzte Stand des Fahrplans (`letzter`), die
/// Messung (`wirklich`) und ein Vergleichslauf mit perfekter Voraussicht (`perfekt`).
///
/// `abstaende` sind die Stufen dazwischen. Die ersten drei führen vom Versprechen zur
/// Wirklichkeit: Prognosefehler, Nachführen, Eingriff der Maschine. Positiv heißt teurer.
///
/// Eine Linie, die fehlt, hat `verfuegbar=false` und sagt in `grund_de`, warum. Das ist für
/// Tage vor dem 09.11.2026 der Normalfall bei allen Fahrplanlinien: aufbewahrt wird erst seitdem.
public struct NachbetrachtungOut: Codable, Sendable, Hashable {
    public var zeiten: [String]
    public var schrittMin: Int?
    public var verglichen: [Bool]
    public var nVerglichen: Int?
    public var preisCt: [Double?]
    public var ueberschussKw: [Double?]
    public var linien: [Linie]
    public var abstaende: [Abstand]
    public var standbyKwh: Double?
    public var standbyEur: Double?
    public var ersterPlanErstellt: String?
    public var satzDe: String?
    public var hinweiseDe: [String]
    public var methodeDe: [String]
    public var day: String
    public var von: String
    public var bis: String
    public var laeuftNoch: Bool?
    public var wpKw: Double
    public var verguetungCt: Double
    public var hatOfen: Bool?
    public var verschiebenEur: Double?
    public var verschiebenDe: String?

    public enum CodingKeys: String, CodingKey {
        case zeiten
        case schrittMin = "schritt_min"
        case verglichen
        case nVerglichen = "n_verglichen"
        case preisCt = "preis_ct"
        case ueberschussKw = "ueberschuss_kw"
        case linien
        case abstaende
        case standbyKwh = "standby_kwh"
        case standbyEur = "standby_eur"
        case ersterPlanErstellt = "erster_plan_erstellt"
        case satzDe = "satz_de"
        case hinweiseDe = "hinweise_de"
        case methodeDe = "methode_de"
        case day
        case von
        case bis
        case laeuftNoch = "laeuft_noch"
        case wpKw = "wp_kw"
        case verguetungCt = "verguetung_ct"
        case hatOfen = "hat_ofen"
        case verschiebenEur = "verschieben_eur"
        case verschiebenDe = "verschieben_de"
    }

    public init(zeiten: [String] = [], schrittMin: Int? = nil, verglichen: [Bool] = [], nVerglichen: Int? = nil, preisCt: [Double?] = [], ueberschussKw: [Double?] = [], linien: [Linie] = [], abstaende: [Abstand] = [], standbyKwh: Double? = nil, standbyEur: Double? = nil, ersterPlanErstellt: String? = nil, satzDe: String? = nil, hinweiseDe: [String] = [], methodeDe: [String] = [], day: String, von: String, bis: String, laeuftNoch: Bool? = nil, wpKw: Double, verguetungCt: Double, hatOfen: Bool? = nil, verschiebenEur: Double? = nil, verschiebenDe: String? = nil) {
        self.zeiten = zeiten
        self.schrittMin = schrittMin
        self.verglichen = verglichen
        self.nVerglichen = nVerglichen
        self.preisCt = preisCt
        self.ueberschussKw = ueberschussKw
        self.linien = linien
        self.abstaende = abstaende
        self.standbyKwh = standbyKwh
        self.standbyEur = standbyEur
        self.ersterPlanErstellt = ersterPlanErstellt
        self.satzDe = satzDe
        self.hinweiseDe = hinweiseDe
        self.methodeDe = methodeDe
        self.day = day
        self.von = von
        self.bis = bis
        self.laeuftNoch = laeuftNoch
        self.wpKw = wpKw
        self.verguetungCt = verguetungCt
        self.hatOfen = hatOfen
        self.verschiebenEur = verschiebenEur
        self.verschiebenDe = verschiebenDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.zeiten = try c.decodeIfPresent([String].self, forKey: .zeiten) ?? []
        self.schrittMin = try c.decodeIfPresent(Int.self, forKey: .schrittMin)
        self.verglichen = try c.decodeIfPresent([Bool].self, forKey: .verglichen) ?? []
        self.nVerglichen = try c.decodeIfPresent(Int.self, forKey: .nVerglichen)
        self.preisCt = try c.decodeIfPresent([Double?].self, forKey: .preisCt) ?? []
        self.ueberschussKw = try c.decodeIfPresent([Double?].self, forKey: .ueberschussKw) ?? []
        self.linien = try c.decodeIfPresent([Linie].self, forKey: .linien) ?? []
        self.abstaende = try c.decodeIfPresent([Abstand].self, forKey: .abstaende) ?? []
        self.standbyKwh = try c.decodeIfPresent(Double.self, forKey: .standbyKwh)
        self.standbyEur = try c.decodeIfPresent(Double.self, forKey: .standbyEur)
        self.ersterPlanErstellt = try c.decodeIfPresent(String.self, forKey: .ersterPlanErstellt)
        self.satzDe = try c.decodeIfPresent(String.self, forKey: .satzDe)
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
        self.methodeDe = try c.decodeIfPresent([String].self, forKey: .methodeDe) ?? []
        self.day = try c.decode(String.self, forKey: .day)
        self.von = try c.decode(String.self, forKey: .von)
        self.bis = try c.decode(String.self, forKey: .bis)
        self.laeuftNoch = try c.decodeIfPresent(Bool.self, forKey: .laeuftNoch)
        self.wpKw = try c.decode(Double.self, forKey: .wpKw)
        self.verguetungCt = try c.decode(Double.self, forKey: .verguetungCt)
        self.hatOfen = try c.decodeIfPresent(Bool.self, forKey: .hatOfen)
        self.verschiebenEur = try c.decodeIfPresent(Double.self, forKey: .verschiebenEur)
        self.verschiebenDe = try c.decodeIfPresent(String.self, forKey: .verschiebenDe)
    }
}

public struct NameIn: Codable, Sendable, Hashable {
    public var name: String

    public init(name: String) {
        self.name = name
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
    }
}

public struct NextExpected: Codable, Sendable, Hashable {
    public var action: String
    public var at: String?
    public var because: ReasonCode
    public var textDe: String

    public enum CodingKeys: String, CodingKey {
        case action
        case at
        case because
        case textDe = "text_de"
    }

    public init(action: String, at: String? = nil, because: ReasonCode, textDe: String) {
        self.action = action
        self.at = at
        self.because = because
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.action = try c.decode(String.self, forKey: .action)
        self.at = try c.decodeIfPresent(String.self, forKey: .at)
        self.because = try c.decode(ReasonCode.self, forKey: .because)
        self.textDe = try c.decode(String.self, forKey: .textDe)
    }
}

/// Fenster oder Tuer ohne Kontakt: steht still in der Wand.
public struct Opening: Codable, Sendable, Hashable {
    public var x: Double?
    public var z: Double?
    public var a: Double
    public var b: Double
    public var door: Bool?

    public init(x: Double? = nil, z: Double? = nil, a: Double, b: Double, door: Bool? = nil) {
        self.x = x
        self.z = z
        self.a = a
        self.b = b
        self.door = door
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.x = try c.decodeIfPresent(Double.self, forKey: .x)
        self.z = try c.decodeIfPresent(Double.self, forKey: .z)
        self.a = try c.decode(Double.self, forKey: .a)
        self.b = try c.decode(Double.self, forKey: .b)
        self.door = try c.decodeIfPresent(Bool.self, forKey: .door)
    }
}

public struct OperatingMode: Codable, Sendable, Hashable {
    public var systemMode: SystemMode?
    public var autoProfile: AutoProfile?
    public var override: Override?

    public enum CodingKeys: String, CodingKey {
        case systemMode = "system_mode"
        case autoProfile = "auto_profile"
        case override
    }

    public init(systemMode: SystemMode? = nil, autoProfile: AutoProfile? = nil, override: Override? = nil) {
        self.systemMode = systemMode
        self.autoProfile = autoProfile
        self.override = override
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.systemMode = try c.decodeIfPresent(SystemMode.self, forKey: .systemMode)
        self.autoProfile = try c.decodeIfPresent(AutoProfile.self, forKey: .autoProfile)
        self.override = try c.decodeIfPresent(Override.self, forKey: .override)
    }
}

public struct Override: Codable, Sendable, Hashable {
    public var kind: OverrideKind
    public var startedAt: String
    public var endsAt: String
    public var setBy: String?

    public enum CodingKeys: String, CodingKey {
        case kind
        case startedAt = "started_at"
        case endsAt = "ends_at"
        case setBy = "set_by"
    }

    public init(kind: OverrideKind, startedAt: String, endsAt: String, setBy: String? = nil) {
        self.kind = kind
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.setBy = setBy
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try c.decode(OverrideKind.self, forKey: .kind)
        self.startedAt = try c.decode(String.self, forKey: .startedAt)
        self.endsAt = try c.decode(String.self, forKey: .endsAt)
        self.setBy = try c.decodeIfPresent(String.self, forKey: .setBy)
    }
}

/// Ein Parameter, wie ihn die Oberfläche zeigt.
public struct ParameterAnsicht: Codable, Sendable, Hashable {
    public var id: String
    public var block: String
    public var symbol: String
    public var name: String
    public var einheit: String
    public var stellen: Int
    public var wert: Double
    public var herkunft: ParameterAnsichtHerkunftWahl
    public var schaetzart: ParameterAnsichtSchaetzartWahl
    public var schaetzartText: String
    public var startwert: Double
    public var schaetzung: Double?
    public var sigma: Double?
    public var n: Int?
    public var stand: String?
    public var rmse: Double?
    public var unten: Double
    public var oben: Double
    public var warum: String
    public var quelle: String?
    public var wirktAuf: [String]
    public var protokoll: [Uebernahme]
    public var verlauf: [Messpunkt]
    public var pruefung: Pruefung?

    public enum CodingKeys: String, CodingKey {
        case id
        case block
        case symbol
        case name
        case einheit
        case stellen
        case wert
        case herkunft
        case schaetzart
        case schaetzartText = "schaetzart_text"
        case startwert
        case schaetzung
        case sigma
        case n
        case stand
        case rmse
        case unten
        case oben
        case warum
        case quelle
        case wirktAuf = "wirkt_auf"
        case protokoll
        case verlauf
        case pruefung
    }

    public init(id: String, block: String, symbol: String, name: String, einheit: String, stellen: Int, wert: Double, herkunft: ParameterAnsichtHerkunftWahl, schaetzart: ParameterAnsichtSchaetzartWahl, schaetzartText: String, startwert: Double, schaetzung: Double? = nil, sigma: Double? = nil, n: Int? = nil, stand: String? = nil, rmse: Double? = nil, unten: Double, oben: Double, warum: String, quelle: String? = nil, wirktAuf: [String] = [], protokoll: [Uebernahme] = [], verlauf: [Messpunkt] = [], pruefung: Pruefung? = nil) {
        self.id = id
        self.block = block
        self.symbol = symbol
        self.name = name
        self.einheit = einheit
        self.stellen = stellen
        self.wert = wert
        self.herkunft = herkunft
        self.schaetzart = schaetzart
        self.schaetzartText = schaetzartText
        self.startwert = startwert
        self.schaetzung = schaetzung
        self.sigma = sigma
        self.n = n
        self.stand = stand
        self.rmse = rmse
        self.unten = unten
        self.oben = oben
        self.warum = warum
        self.quelle = quelle
        self.wirktAuf = wirktAuf
        self.protokoll = protokoll
        self.verlauf = verlauf
        self.pruefung = pruefung
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.block = try c.decode(String.self, forKey: .block)
        self.symbol = try c.decode(String.self, forKey: .symbol)
        self.name = try c.decode(String.self, forKey: .name)
        self.einheit = try c.decode(String.self, forKey: .einheit)
        self.stellen = try c.decode(Int.self, forKey: .stellen)
        self.wert = try c.decode(Double.self, forKey: .wert)
        self.herkunft = try c.decode(ParameterAnsichtHerkunftWahl.self, forKey: .herkunft)
        self.schaetzart = try c.decode(ParameterAnsichtSchaetzartWahl.self, forKey: .schaetzart)
        self.schaetzartText = try c.decode(String.self, forKey: .schaetzartText)
        self.startwert = try c.decode(Double.self, forKey: .startwert)
        self.schaetzung = try c.decodeIfPresent(Double.self, forKey: .schaetzung)
        self.sigma = try c.decodeIfPresent(Double.self, forKey: .sigma)
        self.n = try c.decodeIfPresent(Int.self, forKey: .n)
        self.stand = try c.decodeIfPresent(String.self, forKey: .stand)
        self.rmse = try c.decodeIfPresent(Double.self, forKey: .rmse)
        self.unten = try c.decode(Double.self, forKey: .unten)
        self.oben = try c.decode(Double.self, forKey: .oben)
        self.warum = try c.decode(String.self, forKey: .warum)
        self.quelle = try c.decodeIfPresent(String.self, forKey: .quelle)
        self.wirktAuf = try c.decodeIfPresent([String].self, forKey: .wirktAuf) ?? []
        self.protokoll = try c.decodeIfPresent([Uebernahme].self, forKey: .protokoll) ?? []
        self.verlauf = try c.decodeIfPresent([Messpunkt].self, forKey: .verlauf) ?? []
        self.pruefung = try c.decodeIfPresent(Pruefung.self, forKey: .pruefung)
    }
}

public struct PasskeyAbschliessenIn: Codable, Sendable, Hashable {
    public var schritt: String
    public var antwort: [String: Mischwert]
    public var name: String?
    public var token: String?

    public init(schritt: String, antwort: [String: Mischwert] = [:], name: String? = nil, token: String? = nil) {
        self.schritt = schritt
        self.antwort = antwort
        self.name = name
        self.token = token
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schritt = try c.decode(String.self, forKey: .schritt)
        self.antwort = try c.decodeIfPresent([String: Mischwert].self, forKey: .antwort) ?? [:]
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.token = try c.decodeIfPresent(String.self, forKey: .token)
    }
}

public struct PasskeyBeginnenIn: Codable, Sendable, Hashable {
    public var token: String?

    public init(token: String? = nil) {
        self.token = token
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try c.decodeIfPresent(String.self, forKey: .token)
    }
}

public struct PasskeyOut: Codable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var gesichert: Bool
    public var erstelltAm: String
    public var zuletztBenutztAm: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case gesichert
        case erstelltAm = "erstellt_am"
        case zuletztBenutztAm = "zuletzt_benutzt_am"
    }

    public init(id: String, name: String, gesichert: Bool, erstelltAm: String, zuletztBenutztAm: String? = nil) {
        self.id = id
        self.name = name
        self.gesichert = gesichert
        self.erstelltAm = erstelltAm
        self.zuletztBenutztAm = zuletztBenutztAm
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.gesichert = try c.decode(Bool.self, forKey: .gesichert)
        self.erstelltAm = try c.decode(String.self, forKey: .erstelltAm)
        self.zuletztBenutztAm = try c.decodeIfPresent(String.self, forKey: .zuletztBenutztAm)
    }
}

public struct PasswortAnmeldenIn: Codable, Sendable, Hashable {
    public var email: String
    public var passwort: String

    public init(email: String, passwort: String) {
        self.email = email
        self.passwort = passwort
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.email = try c.decode(String.self, forKey: .email)
        self.passwort = try c.decode(String.self, forKey: .passwort)
    }
}

/// Das eigene Passwort entfernen. Verlangt das bisherige, wie das Wechseln.
public struct PasswortEntfernenIn: Codable, Sendable, Hashable {
    public var bisher: String

    public init(bisher: String) {
        self.bisher = bisher
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bisher = try c.decode(String.self, forKey: .bisher)
    }
}

/// Das eigene Passwort vergeben oder wechseln.
public struct PasswortSetzenIn: Codable, Sendable, Hashable {
    public var neu: String
    public var bisher: String?

    public init(neu: String, bisher: String? = nil) {
        self.neu = neu
        self.bisher = bisher
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.neu = try c.decode(String.self, forKey: .neu)
        self.bisher = try c.decodeIfPresent(String.self, forKey: .bisher)
    }
}

/// Das Passwort hinter dem Einladungslink vergeben.
public struct PasswortUeberLinkIn: Codable, Sendable, Hashable {
    public var token: String
    public var passwort: String

    public init(token: String, passwort: String) {
        self.token = token
        self.passwort = passwort
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try c.decode(String.self, forKey: .token)
        self.passwort = try c.decode(String.self, forKey: .passwort)
    }
}

public struct PersonAendernIn: Codable, Sendable, Hashable {
    public var rolle: PersonAendernInRolleWahl?
    public var aktiv: Bool?
    public var anzeigename: String?

    public init(rolle: PersonAendernInRolleWahl? = nil, aktiv: Bool? = nil, anzeigename: String? = nil) {
        self.rolle = rolle
        self.aktiv = aktiv
        self.anzeigename = anzeigename
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rolle = try c.decodeIfPresent(PersonAendernInRolleWahl.self, forKey: .rolle)
        self.aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv)
        self.anzeigename = try c.decodeIfPresent(String.self, forKey: .anzeigename)
    }
}

public struct PersonAnlegenIn: Codable, Sendable, Hashable {
    public var email: String
    public var anzeigename: String?
    public var rolle: PersonAnlegenInRolleWahl?
    public var einladen: Bool?

    public init(email: String, anzeigename: String? = nil, rolle: PersonAnlegenInRolleWahl? = nil, einladen: Bool? = nil) {
        self.email = email
        self.anzeigename = anzeigename
        self.rolle = rolle
        self.einladen = einladen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.email = try c.decode(String.self, forKey: .email)
        self.anzeigename = try c.decodeIfPresent(String.self, forKey: .anzeigename)
        self.rolle = try c.decodeIfPresent(PersonAnlegenInRolleWahl.self, forKey: .rolle)
        self.einladen = try c.decodeIfPresent(Bool.self, forKey: .einladen)
    }
}

public struct PersonOut: Codable, Sendable, Hashable {
    public var id: String
    public var email: String
    public var anzeigename: String?
    public var rolle: PersonOutRolleWahl
    public var aktiv: Bool?
    public var erstelltAm: String
    public var zuletztAngemeldetAm: String?
    public var passkeys: Int?
    public var passwort: Bool?
    public var codesOffen: Int?
    public var einladungOffen: Bool?

    public enum CodingKeys: String, CodingKey {
        case id
        case email
        case anzeigename
        case rolle
        case aktiv
        case erstelltAm = "erstellt_am"
        case zuletztAngemeldetAm = "zuletzt_angemeldet_am"
        case passkeys
        case passwort
        case codesOffen = "codes_offen"
        case einladungOffen = "einladung_offen"
    }

    public init(id: String, email: String, anzeigename: String? = nil, rolle: PersonOutRolleWahl, aktiv: Bool? = nil, erstelltAm: String, zuletztAngemeldetAm: String? = nil, passkeys: Int? = nil, passwort: Bool? = nil, codesOffen: Int? = nil, einladungOffen: Bool? = nil) {
        self.id = id
        self.email = email
        self.anzeigename = anzeigename
        self.rolle = rolle
        self.aktiv = aktiv
        self.erstelltAm = erstelltAm
        self.zuletztAngemeldetAm = zuletztAngemeldetAm
        self.passkeys = passkeys
        self.passwort = passwort
        self.codesOffen = codesOffen
        self.einladungOffen = einladungOffen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.email = try c.decode(String.self, forKey: .email)
        self.anzeigename = try c.decodeIfPresent(String.self, forKey: .anzeigename)
        self.rolle = try c.decode(PersonOutRolleWahl.self, forKey: .rolle)
        self.aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv)
        self.erstelltAm = try c.decode(String.self, forKey: .erstelltAm)
        self.zuletztAngemeldetAm = try c.decodeIfPresent(String.self, forKey: .zuletztAngemeldetAm)
        self.passkeys = try c.decodeIfPresent(Int.self, forKey: .passkeys)
        self.passwort = try c.decodeIfPresent(Bool.self, forKey: .passwort)
        self.codesOffen = try c.decodeIfPresent(Int.self, forKey: .codesOffen)
        self.einladungOffen = try c.decodeIfPresent(Bool.self, forKey: .einladungOffen)
    }
}

/// Eine Ortsmarke draussen: Garten, Innenhof, Strasse.
public struct Place: Codable, Sendable, Hashable {
    public var text: String
    public var x: Double
    public var z: Double

    public init(text: String, x: Double, z: Double) {
        self.text = text
        self.x = x
        self.z = z
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try c.decode(String.self, forKey: .text)
        self.x = try c.decode(Double.self, forKey: .x)
        self.z = try c.decode(Double.self, forKey: .z)
    }
}

public struct PlanIntervalOut: Codable, Sendable, Hashable {
    public var ts: String
    public var expectedPvKw: Double
    public var priceCtKwh: Double?
    public var plannedHpState: PlanIntervalOutPlannedHpStateWahl
    public var plannedStoveOn: Bool?
    public var reasonCode: String
    public var noteDe: String?
    public var heatDemandKw: Double?
    public var dhwDemandKw: Double?
    public var bufferKwh: Double?
    public var outdoorTempC: Double?
    public var cop: Double?
    public var plannedCostEur: Double?
    public var plannedHpCostEur: Double?
    public var plannedPelletCostEur: Double?
    public var actualPvKw: Double?
    public var actualHpKw: Double?
    public var actualHpRelease: Bool?
    public var actualHpRunMin: Double?

    public enum CodingKeys: String, CodingKey {
        case ts
        case expectedPvKw = "expected_pv_kw"
        case priceCtKwh = "price_ct_kwh"
        case plannedHpState = "planned_hp_state"
        case plannedStoveOn = "planned_stove_on"
        case reasonCode = "reason_code"
        case noteDe = "note_de"
        case heatDemandKw = "heat_demand_kw"
        case dhwDemandKw = "dhw_demand_kw"
        case bufferKwh = "buffer_kwh"
        case outdoorTempC = "outdoor_temp_c"
        case cop
        case plannedCostEur = "planned_cost_eur"
        case plannedHpCostEur = "planned_hp_cost_eur"
        case plannedPelletCostEur = "planned_pellet_cost_eur"
        case actualPvKw = "actual_pv_kw"
        case actualHpKw = "actual_hp_kw"
        case actualHpRelease = "actual_hp_release"
        case actualHpRunMin = "actual_hp_run_min"
    }

    public init(ts: String, expectedPvKw: Double, priceCtKwh: Double? = nil, plannedHpState: PlanIntervalOutPlannedHpStateWahl, plannedStoveOn: Bool? = nil, reasonCode: String, noteDe: String? = nil, heatDemandKw: Double? = nil, dhwDemandKw: Double? = nil, bufferKwh: Double? = nil, outdoorTempC: Double? = nil, cop: Double? = nil, plannedCostEur: Double? = nil, plannedHpCostEur: Double? = nil, plannedPelletCostEur: Double? = nil, actualPvKw: Double? = nil, actualHpKw: Double? = nil, actualHpRelease: Bool? = nil, actualHpRunMin: Double? = nil) {
        self.ts = ts
        self.expectedPvKw = expectedPvKw
        self.priceCtKwh = priceCtKwh
        self.plannedHpState = plannedHpState
        self.plannedStoveOn = plannedStoveOn
        self.reasonCode = reasonCode
        self.noteDe = noteDe
        self.heatDemandKw = heatDemandKw
        self.dhwDemandKw = dhwDemandKw
        self.bufferKwh = bufferKwh
        self.outdoorTempC = outdoorTempC
        self.cop = cop
        self.plannedCostEur = plannedCostEur
        self.plannedHpCostEur = plannedHpCostEur
        self.plannedPelletCostEur = plannedPelletCostEur
        self.actualPvKw = actualPvKw
        self.actualHpKw = actualHpKw
        self.actualHpRelease = actualHpRelease
        self.actualHpRunMin = actualHpRunMin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts = try c.decode(String.self, forKey: .ts)
        self.expectedPvKw = try c.decode(Double.self, forKey: .expectedPvKw)
        self.priceCtKwh = try c.decodeIfPresent(Double.self, forKey: .priceCtKwh)
        self.plannedHpState = try c.decode(PlanIntervalOutPlannedHpStateWahl.self, forKey: .plannedHpState)
        self.plannedStoveOn = try c.decodeIfPresent(Bool.self, forKey: .plannedStoveOn)
        self.reasonCode = try c.decode(String.self, forKey: .reasonCode)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
        self.heatDemandKw = try c.decodeIfPresent(Double.self, forKey: .heatDemandKw)
        self.dhwDemandKw = try c.decodeIfPresent(Double.self, forKey: .dhwDemandKw)
        self.bufferKwh = try c.decodeIfPresent(Double.self, forKey: .bufferKwh)
        self.outdoorTempC = try c.decodeIfPresent(Double.self, forKey: .outdoorTempC)
        self.cop = try c.decodeIfPresent(Double.self, forKey: .cop)
        self.plannedCostEur = try c.decodeIfPresent(Double.self, forKey: .plannedCostEur)
        self.plannedHpCostEur = try c.decodeIfPresent(Double.self, forKey: .plannedHpCostEur)
        self.plannedPelletCostEur = try c.decodeIfPresent(Double.self, forKey: .plannedPelletCostEur)
        self.actualPvKw = try c.decodeIfPresent(Double.self, forKey: .actualPvKw)
        self.actualHpKw = try c.decodeIfPresent(Double.self, forKey: .actualHpKw)
        self.actualHpRelease = try c.decodeIfPresent(Bool.self, forKey: .actualHpRelease)
        self.actualHpRunMin = try c.decodeIfPresent(Double.self, forKey: .actualHpRunMin)
    }
}

public struct PlanOut: Codable, Sendable, Hashable {
    public var createdAt: String
    public var planner: String
    public var plannerStatus: String?
    public var plannerNoteDe: String?
    public var plannerWarnDe: String?
    public var hpActuation: Bool?
    public var horizonStart: String
    public var horizonEnd: String
    public var windows: [PriceWindowOut]
    public var intervals: [PlanIntervalOut]
    public var pvForecastTodayKwh: Double
    public var nextCheapWindow: PriceWindowOut?
    public var bufferCapacityKwh: Double?
    public var bufferMinKwh: Double?
    public var sun: [SunDayOut]

    public enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case planner
        case plannerStatus = "planner_status"
        case plannerNoteDe = "planner_note_de"
        case plannerWarnDe = "planner_warn_de"
        case hpActuation = "hp_actuation"
        case horizonStart = "horizon_start"
        case horizonEnd = "horizon_end"
        case windows
        case intervals
        case pvForecastTodayKwh = "pv_forecast_today_kwh"
        case nextCheapWindow = "next_cheap_window"
        case bufferCapacityKwh = "buffer_capacity_kwh"
        case bufferMinKwh = "buffer_min_kwh"
        case sun
    }

    public init(createdAt: String, planner: String, plannerStatus: String? = nil, plannerNoteDe: String? = nil, plannerWarnDe: String? = nil, hpActuation: Bool? = nil, horizonStart: String, horizonEnd: String, windows: [PriceWindowOut] = [], intervals: [PlanIntervalOut] = [], pvForecastTodayKwh: Double, nextCheapWindow: PriceWindowOut? = nil, bufferCapacityKwh: Double? = nil, bufferMinKwh: Double? = nil, sun: [SunDayOut] = []) {
        self.createdAt = createdAt
        self.planner = planner
        self.plannerStatus = plannerStatus
        self.plannerNoteDe = plannerNoteDe
        self.plannerWarnDe = plannerWarnDe
        self.hpActuation = hpActuation
        self.horizonStart = horizonStart
        self.horizonEnd = horizonEnd
        self.windows = windows
        self.intervals = intervals
        self.pvForecastTodayKwh = pvForecastTodayKwh
        self.nextCheapWindow = nextCheapWindow
        self.bufferCapacityKwh = bufferCapacityKwh
        self.bufferMinKwh = bufferMinKwh
        self.sun = sun
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.createdAt = try c.decode(String.self, forKey: .createdAt)
        self.planner = try c.decode(String.self, forKey: .planner)
        self.plannerStatus = try c.decodeIfPresent(String.self, forKey: .plannerStatus)
        self.plannerNoteDe = try c.decodeIfPresent(String.self, forKey: .plannerNoteDe)
        self.plannerWarnDe = try c.decodeIfPresent(String.self, forKey: .plannerWarnDe)
        self.hpActuation = try c.decodeIfPresent(Bool.self, forKey: .hpActuation)
        self.horizonStart = try c.decode(String.self, forKey: .horizonStart)
        self.horizonEnd = try c.decode(String.self, forKey: .horizonEnd)
        self.windows = try c.decodeIfPresent([PriceWindowOut].self, forKey: .windows) ?? []
        self.intervals = try c.decodeIfPresent([PlanIntervalOut].self, forKey: .intervals) ?? []
        self.pvForecastTodayKwh = try c.decode(Double.self, forKey: .pvForecastTodayKwh)
        self.nextCheapWindow = try c.decodeIfPresent(PriceWindowOut.self, forKey: .nextCheapWindow)
        self.bufferCapacityKwh = try c.decodeIfPresent(Double.self, forKey: .bufferCapacityKwh)
        self.bufferMinKwh = try c.decodeIfPresent(Double.self, forKey: .bufferMinKwh)
        self.sun = try c.decodeIfPresent([SunDayOut].self, forKey: .sun) ?? []
    }
}

/// Lief die Wärmepumpe zur richtigen Zeit? Ergebnis statt Regeltreue.
///
/// Verglichen wird, was der Wärmepumpenstrom aus dem Netz gekostet hat, mit dem, was der Bezug des
/// ganzen Hauses im selben Zeitraum im Mittel kostete. Liegt der erste darunter, hat die Steuerung
/// gewirkt - unabhängig davon, ob sie jedes geplante Fenster genau getroffen hat.
public struct PriceQualityOut: Codable, Sendable, Hashable {
    public var hpGridPriceCt: Double?
    public var houseGridPriceCt: Double?
    public var advantageCt: Double?
    public var cheapShare: Double?
    public var pvShare: Double?
    public var hoursRanked: Int?
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case hpGridPriceCt = "hp_grid_price_ct"
        case houseGridPriceCt = "house_grid_price_ct"
        case advantageCt = "advantage_ct"
        case cheapShare = "cheap_share"
        case pvShare = "pv_share"
        case hoursRanked = "hours_ranked"
        case noteDe = "note_de"
    }

    public init(hpGridPriceCt: Double? = nil, houseGridPriceCt: Double? = nil, advantageCt: Double? = nil, cheapShare: Double? = nil, pvShare: Double? = nil, hoursRanked: Int? = nil, noteDe: String? = nil) {
        self.hpGridPriceCt = hpGridPriceCt
        self.houseGridPriceCt = houseGridPriceCt
        self.advantageCt = advantageCt
        self.cheapShare = cheapShare
        self.pvShare = pvShare
        self.hoursRanked = hoursRanked
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hpGridPriceCt = try c.decodeIfPresent(Double.self, forKey: .hpGridPriceCt)
        self.houseGridPriceCt = try c.decodeIfPresent(Double.self, forKey: .houseGridPriceCt)
        self.advantageCt = try c.decodeIfPresent(Double.self, forKey: .advantageCt)
        self.cheapShare = try c.decodeIfPresent(Double.self, forKey: .cheapShare)
        self.pvShare = try c.decodeIfPresent(Double.self, forKey: .pvShare)
        self.hoursRanked = try c.decodeIfPresent(Int.self, forKey: .hoursRanked)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

public struct PriceRuleConfig: Codable, Sendable, Hashable {
    public var negativePriceRelease: Bool?
    public var cheapQuantile: Double?
    public var minWindowMin: Int?
    public var priceMaxAgeH: Double?
    public var expensiveQuantile: Double?

    public enum CodingKeys: String, CodingKey {
        case negativePriceRelease = "negative_price_release"
        case cheapQuantile = "cheap_quantile"
        case minWindowMin = "min_window_min"
        case priceMaxAgeH = "price_max_age_h"
        case expensiveQuantile = "expensive_quantile"
    }

    public init(negativePriceRelease: Bool? = nil, cheapQuantile: Double? = nil, minWindowMin: Int? = nil, priceMaxAgeH: Double? = nil, expensiveQuantile: Double? = nil) {
        self.negativePriceRelease = negativePriceRelease
        self.cheapQuantile = cheapQuantile
        self.minWindowMin = minWindowMin
        self.priceMaxAgeH = priceMaxAgeH
        self.expensiveQuantile = expensiveQuantile
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.negativePriceRelease = try c.decodeIfPresent(Bool.self, forKey: .negativePriceRelease)
        self.cheapQuantile = try c.decodeIfPresent(Double.self, forKey: .cheapQuantile)
        self.minWindowMin = try c.decodeIfPresent(Int.self, forKey: .minWindowMin)
        self.priceMaxAgeH = try c.decodeIfPresent(Double.self, forKey: .priceMaxAgeH)
        self.expensiveQuantile = try c.decodeIfPresent(Double.self, forKey: .expensiveQuantile)
    }
}

public struct PriceWindowOut: Codable, Sendable, Hashable {
    public var start: String
    public var end: String
    public var kind: PriceWindowOutKindWahl
    public var avgCtKwh: Double?
    public var labelDe: String

    public enum CodingKeys: String, CodingKey {
        case start
        case end
        case kind
        case avgCtKwh = "avg_ct_kwh"
        case labelDe = "label_de"
    }

    public init(start: String, end: String, kind: PriceWindowOutKindWahl, avgCtKwh: Double? = nil, labelDe: String) {
        self.start = start
        self.end = end
        self.kind = kind
        self.avgCtKwh = avgCtKwh
        self.labelDe = labelDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.kind = try c.decode(PriceWindowOutKindWahl.self, forKey: .kind)
        self.avgCtKwh = try c.decodeIfPresent(Double.self, forKey: .avgCtKwh)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
    }
}

/// Das Ergebnis der Übernahmeprüfung, mit Satz für die Oberfläche.
public struct Pruefung: Codable, Sendable, Hashable {
    public var uebernehmen: Bool
    public var code: PruefungCodeWahl
    public var grund: String

    public init(uebernehmen: Bool, code: PruefungCodeWahl, grund: String) {
        self.uebernehmen = uebernehmen
        self.code = code
        self.grund = grund
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.uebernehmen = try c.decode(Bool.self, forKey: .uebernehmen)
        self.code = try c.decode(PruefungCodeWahl.self, forKey: .code)
        self.grund = try c.decode(String.self, forKey: .grund)
    }
}

/// Ein angemeldetes Gerät, soweit der Dienst es kennt: ein Wort und der Stand der Zustellung.
public struct PushGeraetOut: Codable, Sendable, Hashable {
    public var label: String
    public var seit: String?
    public var zuletztOk: String?
    public var fehlversuche: Int?
    public var letzterFehlerDe: String?

    public enum CodingKeys: String, CodingKey {
        case label
        case seit
        case zuletztOk = "zuletzt_ok"
        case fehlversuche
        case letzterFehlerDe = "letzter_fehler_de"
    }

    public init(label: String, seit: String? = nil, zuletztOk: String? = nil, fehlversuche: Int? = nil, letzterFehlerDe: String? = nil) {
        self.label = label
        self.seit = seit
        self.zuletztOk = zuletztOk
        self.fehlversuche = fehlversuche
        self.letzterFehlerDe = letzterFehlerDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try c.decode(String.self, forKey: .label)
        self.seit = try c.decodeIfPresent(String.self, forKey: .seit)
        self.zuletztOk = try c.decodeIfPresent(String.self, forKey: .zuletztOk)
        self.fehlversuche = try c.decodeIfPresent(Int.self, forKey: .fehlversuche)
        self.letzterFehlerDe = try c.decodeIfPresent(String.self, forKey: .letzterFehlerDe)
    }
}

public struct PushGeraeteOut: Codable, Sendable, Hashable {
    public var devices: [PushGeraetOut]

    public init(devices: [PushGeraetOut] = []) {
        self.devices = devices
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.devices = try c.decodeIfPresent([PushGeraetOut].self, forKey: .devices) ?? []
    }
}

/// Der öffentliche Schlüssel des Dienstes und die Zahl der angemeldeten Geräte.
///
/// Der Browser braucht den Schlüssel, um ein Abonnement anzulegen; ohne ihn geht gar nichts.
/// Öffentlich ist er im Wortsinn: Er darf in jeder Seite stehen.
public struct PushKeyOut: Codable, Sendable, Hashable {
    public var publicKey: String
    public var devices: Int

    public enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case devices
    }

    public init(publicKey: String, devices: Int) {
        self.publicKey = publicKey
        self.devices = devices
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.publicKey = try c.decode(String.self, forKey: .publicKey)
        self.devices = try c.decode(Int.self, forKey: .devices)
    }
}

public struct PushResultOut: Codable, Sendable, Hashable {
    public var ok: Bool
    public var devices: Int
    public var messageDe: String
    public var detailsDe: [String]

    public enum CodingKeys: String, CodingKey {
        case ok
        case devices
        case messageDe = "message_de"
        case detailsDe = "details_de"
    }

    public init(ok: Bool, devices: Int, messageDe: String, detailsDe: [String] = []) {
        self.ok = ok
        self.devices = devices
        self.messageDe = messageDe
        self.detailsDe = detailsDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decode(Bool.self, forKey: .ok)
        self.devices = try c.decode(Int.self, forKey: .devices)
        self.messageDe = try c.decode(String.self, forKey: .messageDe)
        self.detailsDe = try c.decodeIfPresent([String].self, forKey: .detailsDe) ?? []
    }
}

public struct PushSubscribeIn: Codable, Sendable, Hashable {
    public var endpoint: String
    public var p256dh: String
    public var auth: String
    public var label: String?
    public var origin: String?

    public init(endpoint: String, p256dh: String, auth: String, label: String? = nil, origin: String? = nil) {
        self.endpoint = endpoint
        self.p256dh = p256dh
        self.auth = auth
        self.label = label
        self.origin = origin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.endpoint = try c.decode(String.self, forKey: .endpoint)
        self.p256dh = try c.decode(String.self, forKey: .p256dh)
        self.auth = try c.decode(String.self, forKey: .auth)
        self.label = try c.decodeIfPresent(String.self, forKey: .label)
        self.origin = try c.decodeIfPresent(String.self, forKey: .origin)
    }
}

public struct PushUnsubscribeIn: Codable, Sendable, Hashable {
    public var endpoint: String

    public init(endpoint: String) {
        self.endpoint = endpoint
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.endpoint = try c.decode(String.self, forKey: .endpoint)
    }
}

public struct PvRuleConfig: Codable, Sendable, Hashable {
    public var onSurplusKw: Double?
    public var offImportKw: Double?
    public var onDelayMin: Double?
    public var offDelayMin: Double?
    public var countBatteryChargingAboveSoc: Double?
    public var heatPumpBeforeEv: Bool?
    public var minBufferHeadroomSoc: Double?

    public enum CodingKeys: String, CodingKey {
        case onSurplusKw = "on_surplus_kw"
        case offImportKw = "off_import_kw"
        case onDelayMin = "on_delay_min"
        case offDelayMin = "off_delay_min"
        case countBatteryChargingAboveSoc = "count_battery_charging_above_soc"
        case heatPumpBeforeEv = "heat_pump_before_ev"
        case minBufferHeadroomSoc = "min_buffer_headroom_soc"
    }

    public init(onSurplusKw: Double? = nil, offImportKw: Double? = nil, onDelayMin: Double? = nil, offDelayMin: Double? = nil, countBatteryChargingAboveSoc: Double? = nil, heatPumpBeforeEv: Bool? = nil, minBufferHeadroomSoc: Double? = nil) {
        self.onSurplusKw = onSurplusKw
        self.offImportKw = offImportKw
        self.onDelayMin = onDelayMin
        self.offDelayMin = offDelayMin
        self.countBatteryChargingAboveSoc = countBatteryChargingAboveSoc
        self.heatPumpBeforeEv = heatPumpBeforeEv
        self.minBufferHeadroomSoc = minBufferHeadroomSoc
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.onSurplusKw = try c.decodeIfPresent(Double.self, forKey: .onSurplusKw)
        self.offImportKw = try c.decodeIfPresent(Double.self, forKey: .offImportKw)
        self.onDelayMin = try c.decodeIfPresent(Double.self, forKey: .onDelayMin)
        self.offDelayMin = try c.decodeIfPresent(Double.self, forKey: .offDelayMin)
        self.countBatteryChargingAboveSoc = try c.decodeIfPresent(Double.self, forKey: .countBatteryChargingAboveSoc)
        self.heatPumpBeforeEv = try c.decodeIfPresent(Bool.self, forKey: .heatPumpBeforeEv)
        self.minBufferHeadroomSoc = try c.decodeIfPresent(Double.self, forKey: .minBufferHeadroomSoc)
    }
}

public struct PvTaxBucketOut: Codable, Sendable, Hashable {
    public var start: String
    public var end: String
    public var label: String
    public var totals: PvTaxTotals

    public init(start: String, end: String, label: String, totals: PvTaxTotals) {
        self.start = start
        self.end = end
        self.label = label
        self.totals = totals
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.label = try c.decode(String.self, forKey: .label)
        self.totals = try c.decode(PvTaxTotals.self, forKey: .totals)
    }
}

/// Was die Zahlen der Abrechnung bedingt - gehört sichtbar zur Auswertung, nicht ins Kleingedruckte.
public struct PvTaxMetaOut: Codable, Sendable, Hashable {
    public var feedInCtKwh: Double
    public var vatRate: Double
    public var smallBusiness: Bool
    public var pricesIncludeVat: Bool
    public var dataSince: String?
    public var coverage: Double?
    public var batteryCapacityKwh: Double
    public var methodDe: String

    public enum CodingKeys: String, CodingKey {
        case feedInCtKwh = "feed_in_ct_kwh"
        case vatRate = "vat_rate"
        case smallBusiness = "small_business"
        case pricesIncludeVat = "prices_include_vat"
        case dataSince = "data_since"
        case coverage
        case batteryCapacityKwh = "battery_capacity_kwh"
        case methodDe = "method_de"
    }

    public init(feedInCtKwh: Double, vatRate: Double, smallBusiness: Bool, pricesIncludeVat: Bool, dataSince: String? = nil, coverage: Double? = nil, batteryCapacityKwh: Double, methodDe: String) {
        self.feedInCtKwh = feedInCtKwh
        self.vatRate = vatRate
        self.smallBusiness = smallBusiness
        self.pricesIncludeVat = pricesIncludeVat
        self.dataSince = dataSince
        self.coverage = coverage
        self.batteryCapacityKwh = batteryCapacityKwh
        self.methodDe = methodDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.feedInCtKwh = try c.decode(Double.self, forKey: .feedInCtKwh)
        self.vatRate = try c.decode(Double.self, forKey: .vatRate)
        self.smallBusiness = try c.decode(Bool.self, forKey: .smallBusiness)
        self.pricesIncludeVat = try c.decode(Bool.self, forKey: .pricesIncludeVat)
        self.dataSince = try c.decodeIfPresent(String.self, forKey: .dataSince)
        self.coverage = try c.decodeIfPresent(Double.self, forKey: .coverage)
        self.batteryCapacityKwh = try c.decode(Double.self, forKey: .batteryCapacityKwh)
        self.methodDe = try c.decode(String.self, forKey: .methodDe)
    }
}

/// PV-Abrechnung eines Zeitraums: Einspeisung, Eigenverbrauch, Umsatzsteuer.
public struct PvTaxReportOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var period: PvTaxReportOutPeriodWahl
    public var anchor: String
    public var start: String
    public var end: String
    public var totals: PvTaxTotals
    public var buckets: [PvTaxBucketOut]
    public var meta: PvTaxMetaOut

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case period
        case anchor
        case start
        case end
        case totals
        case buckets
        case meta
    }

    public init(generatedAt: String, period: PvTaxReportOutPeriodWahl, anchor: String, start: String, end: String, totals: PvTaxTotals, buckets: [PvTaxBucketOut] = [], meta: PvTaxMetaOut) {
        self.generatedAt = generatedAt
        self.period = period
        self.anchor = anchor
        self.start = start
        self.end = end
        self.totals = totals
        self.buckets = buckets
        self.meta = meta
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.period = try c.decode(PvTaxReportOutPeriodWahl.self, forKey: .period)
        self.anchor = try c.decode(String.self, forKey: .anchor)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.totals = try c.decode(PvTaxTotals.self, forKey: .totals)
        self.buckets = try c.decodeIfPresent([PvTaxBucketOut].self, forKey: .buckets) ?? []
        self.meta = try c.decode(PvTaxMetaOut.self, forKey: .meta)
    }
}

/// Geldseite der PV für einen Zeitraum. Beträge in EUR, Preise in ct/kWh.
public struct PvTaxTotals: Codable, Sendable, Hashable {
    public var smallBusiness: Bool?
    public var vatRate: Double?
    public var feedInCtKwh: Double?
    public var exportKwh: Double?
    public var exportNetEur: Double?
    public var exportVatEur: Double?
    public var exportGrossEur: Double?
    public var selfConsumptionKwh: Double?
    public var selfDirectKwh: Double?
    public var selfBatteryKwh: Double?
    public var selfValueNetEur: Double?
    public var selfVatEur: Double?
    public var selfCtKwh: Double?
    public var selfEstimatedKwh: Double?
    public var vatPayableEur: Double?
    public var pvKwh: Double?
    public var selfConsumptionShare: Double?

    public enum CodingKeys: String, CodingKey {
        case smallBusiness = "small_business"
        case vatRate = "vat_rate"
        case feedInCtKwh = "feed_in_ct_kwh"
        case exportKwh = "export_kwh"
        case exportNetEur = "export_net_eur"
        case exportVatEur = "export_vat_eur"
        case exportGrossEur = "export_gross_eur"
        case selfConsumptionKwh = "self_consumption_kwh"
        case selfDirectKwh = "self_direct_kwh"
        case selfBatteryKwh = "self_battery_kwh"
        case selfValueNetEur = "self_value_net_eur"
        case selfVatEur = "self_vat_eur"
        case selfCtKwh = "self_ct_kwh"
        case selfEstimatedKwh = "self_estimated_kwh"
        case vatPayableEur = "vat_payable_eur"
        case pvKwh = "pv_kwh"
        case selfConsumptionShare = "self_consumption_share"
    }

    public init(smallBusiness: Bool? = nil, vatRate: Double? = nil, feedInCtKwh: Double? = nil, exportKwh: Double? = nil, exportNetEur: Double? = nil, exportVatEur: Double? = nil, exportGrossEur: Double? = nil, selfConsumptionKwh: Double? = nil, selfDirectKwh: Double? = nil, selfBatteryKwh: Double? = nil, selfValueNetEur: Double? = nil, selfVatEur: Double? = nil, selfCtKwh: Double? = nil, selfEstimatedKwh: Double? = nil, vatPayableEur: Double? = nil, pvKwh: Double? = nil, selfConsumptionShare: Double? = nil) {
        self.smallBusiness = smallBusiness
        self.vatRate = vatRate
        self.feedInCtKwh = feedInCtKwh
        self.exportKwh = exportKwh
        self.exportNetEur = exportNetEur
        self.exportVatEur = exportVatEur
        self.exportGrossEur = exportGrossEur
        self.selfConsumptionKwh = selfConsumptionKwh
        self.selfDirectKwh = selfDirectKwh
        self.selfBatteryKwh = selfBatteryKwh
        self.selfValueNetEur = selfValueNetEur
        self.selfVatEur = selfVatEur
        self.selfCtKwh = selfCtKwh
        self.selfEstimatedKwh = selfEstimatedKwh
        self.vatPayableEur = vatPayableEur
        self.pvKwh = pvKwh
        self.selfConsumptionShare = selfConsumptionShare
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.smallBusiness = try c.decodeIfPresent(Bool.self, forKey: .smallBusiness)
        self.vatRate = try c.decodeIfPresent(Double.self, forKey: .vatRate)
        self.feedInCtKwh = try c.decodeIfPresent(Double.self, forKey: .feedInCtKwh)
        self.exportKwh = try c.decodeIfPresent(Double.self, forKey: .exportKwh)
        self.exportNetEur = try c.decodeIfPresent(Double.self, forKey: .exportNetEur)
        self.exportVatEur = try c.decodeIfPresent(Double.self, forKey: .exportVatEur)
        self.exportGrossEur = try c.decodeIfPresent(Double.self, forKey: .exportGrossEur)
        self.selfConsumptionKwh = try c.decodeIfPresent(Double.self, forKey: .selfConsumptionKwh)
        self.selfDirectKwh = try c.decodeIfPresent(Double.self, forKey: .selfDirectKwh)
        self.selfBatteryKwh = try c.decodeIfPresent(Double.self, forKey: .selfBatteryKwh)
        self.selfValueNetEur = try c.decodeIfPresent(Double.self, forKey: .selfValueNetEur)
        self.selfVatEur = try c.decodeIfPresent(Double.self, forKey: .selfVatEur)
        self.selfCtKwh = try c.decodeIfPresent(Double.self, forKey: .selfCtKwh)
        self.selfEstimatedKwh = try c.decodeIfPresent(Double.self, forKey: .selfEstimatedKwh)
        self.vatPayableEur = try c.decodeIfPresent(Double.self, forKey: .vatPayableEur)
        self.pvKwh = try c.decodeIfPresent(Double.self, forKey: .pvKwh)
        self.selfConsumptionShare = try c.decodeIfPresent(Double.self, forKey: .selfConsumptionShare)
    }
}

public struct Rechnungsergebnis: Codable, Sendable, Hashable {
    public var gelesen: GeleseneRechnung
    public var mittlererPreisCtKwh: Double?
    public var gemessenKwh: Double?
    public var abdeckung: Double?
    public var befunde: [Befund]
    public var zeilenGesendet: Int

    public enum CodingKeys: String, CodingKey {
        case gelesen
        case mittlererPreisCtKwh = "mittlerer_preis_ct_kwh"
        case gemessenKwh = "gemessen_kwh"
        case abdeckung
        case befunde
        case zeilenGesendet = "zeilen_gesendet"
    }

    public init(gelesen: GeleseneRechnung, mittlererPreisCtKwh: Double? = nil, gemessenKwh: Double? = nil, abdeckung: Double? = nil, befunde: [Befund] = [], zeilenGesendet: Int) {
        self.gelesen = gelesen
        self.mittlererPreisCtKwh = mittlererPreisCtKwh
        self.gemessenKwh = gemessenKwh
        self.abdeckung = abdeckung
        self.befunde = befunde
        self.zeilenGesendet = zeilenGesendet
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.gelesen = try c.decode(GeleseneRechnung.self, forKey: .gelesen)
        self.mittlererPreisCtKwh = try c.decodeIfPresent(Double.self, forKey: .mittlererPreisCtKwh)
        self.gemessenKwh = try c.decodeIfPresent(Double.self, forKey: .gemessenKwh)
        self.abdeckung = try c.decodeIfPresent(Double.self, forKey: .abdeckung)
        self.befunde = try c.decodeIfPresent([Befund].self, forKey: .befunde) ?? []
        self.zeilenGesendet = try c.decode(Int.self, forKey: .zeilenGesendet)
    }
}

/// Die Regelkreis-Karte: Struktur, geltende Parameter, Entwurf und Lernzustand.
///
/// Alles, was die Karte zeigt, steht hier: je Block seine Erklärung, seine Gleichungen und seine
/// Parameter, je Kreis die Strecke, der daraus entworfene Regler, seine Reserven und die
/// Frequenzkennlinie, je Parameter die Herkunft - gemessen, geschätzt, angenommen, fest,
/// übersteuert -, die Unsicherheit und das Übernahmeprotokoll.
///
/// Koordinaten stehen nicht darin. Wo ein Kästchen liegt, ist eine Frage der Zeichnung; was
/// verbunden ist, eine Aussage über das Haus.
public struct RegelkreisOut: Codable, Sendable, Hashable {
    public var stand: String
    public var seit: String?
    public var tage: Double?
    public var arbeitspunkt: Arbeitspunkt
    public var kosten: Kostenpunkt
    public var bloecke: [BlockAnsicht]
    public var glieder: [GliedAnsicht]
    public var kanten: [KanteAnsicht]
    public var kreise: [KreisAnsicht]
    public var parameter: [ParameterAnsicht]
    public var guete: [GueteAnsicht]
    public var uebersteuert: [String]
    public var uebernahmen: Int?

    public init(stand: String, seit: String? = nil, tage: Double? = nil, arbeitspunkt: Arbeitspunkt, kosten: Kostenpunkt, bloecke: [BlockAnsicht] = [], glieder: [GliedAnsicht] = [], kanten: [KanteAnsicht] = [], kreise: [KreisAnsicht] = [], parameter: [ParameterAnsicht] = [], guete: [GueteAnsicht] = [], uebersteuert: [String] = [], uebernahmen: Int? = nil) {
        self.stand = stand
        self.seit = seit
        self.tage = tage
        self.arbeitspunkt = arbeitspunkt
        self.kosten = kosten
        self.bloecke = bloecke
        self.glieder = glieder
        self.kanten = kanten
        self.kreise = kreise
        self.parameter = parameter
        self.guete = guete
        self.uebersteuert = uebersteuert
        self.uebernahmen = uebernahmen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stand = try c.decode(String.self, forKey: .stand)
        self.seit = try c.decodeIfPresent(String.self, forKey: .seit)
        self.tage = try c.decodeIfPresent(Double.self, forKey: .tage)
        self.arbeitspunkt = try c.decode(Arbeitspunkt.self, forKey: .arbeitspunkt)
        self.kosten = try c.decode(Kostenpunkt.self, forKey: .kosten)
        self.bloecke = try c.decodeIfPresent([BlockAnsicht].self, forKey: .bloecke) ?? []
        self.glieder = try c.decodeIfPresent([GliedAnsicht].self, forKey: .glieder) ?? []
        self.kanten = try c.decodeIfPresent([KanteAnsicht].self, forKey: .kanten) ?? []
        self.kreise = try c.decodeIfPresent([KreisAnsicht].self, forKey: .kreise) ?? []
        self.parameter = try c.decodeIfPresent([ParameterAnsicht].self, forKey: .parameter) ?? []
        self.guete = try c.decodeIfPresent([GueteAnsicht].self, forKey: .guete) ?? []
        self.uebersteuert = try c.decodeIfPresent([String].self, forKey: .uebersteuert) ?? []
        self.uebernahmen = try c.decodeIfPresent(Int.self, forKey: .uebernahmen)
    }
}

/// Ein Parameter von Hand. Beschnitten wird auf die Plausibilitätsgrenzen des Registers.
public struct RegelkreisStellenIn: Codable, Sendable, Hashable {
    public var wert: Double

    public init(wert: Double) {
        self.wert = wert
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wert = try c.decode(Double.self, forKey: .wert)
    }
}

/// Eine Zeile des Protokolls: wer wann was gestellt hat.
public struct ReglerAenderungOut: Codable, Sendable, Hashable {
    public var at: String
    public var schluessel: String
    public var nameDe: String
    public var vonDe: String
    public var aufDe: String
    public var urheberDe: String?

    public enum CodingKeys: String, CodingKey {
        case at
        case schluessel
        case nameDe = "name_de"
        case vonDe = "von_de"
        case aufDe = "auf_de"
        case urheberDe = "urheber_de"
    }

    public init(at: String, schluessel: String, nameDe: String, vonDe: String, aufDe: String, urheberDe: String? = nil) {
        self.at = at
        self.schluessel = schluessel
        self.nameDe = nameDe
        self.vonDe = vonDe
        self.aufDe = aufDe
        self.urheberDe = urheberDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.schluessel = try c.decode(String.self, forKey: .schluessel)
        self.nameDe = try c.decode(String.self, forKey: .nameDe)
        self.vonDe = try c.decode(String.self, forKey: .vonDe)
        self.aufDe = try c.decode(String.self, forKey: .aufDe)
        self.urheberDe = try c.decodeIfPresent(String.self, forKey: .urheberDe)
    }
}

public struct ReglerAnsicht: Codable, Sendable, Hashable {
    public var kp: Double
    public var tn: Double
    public var lam: Double
    public var regel: String

    public init(kp: Double, tn: Double, lam: Double, regel: String) {
        self.kp = kp
        self.tn = tn
        self.lam = lam
        self.regel = regel
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kp = try c.decode(Double.self, forKey: .kp)
        self.tn = try c.decode(Double.self, forKey: .tn)
        self.lam = try c.decode(Double.self, forKey: .lam)
        self.regel = try c.decode(String.self, forKey: .regel)
    }
}

public struct ReglerBestaetigenIn: Codable, Sendable, Hashable {
    public var bestaetigt: Bool

    public init(bestaetigt: Bool) {
        self.bestaetigt = bestaetigt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bestaetigt = try c.decode(Bool.self, forKey: .bestaetigt)
    }
}

/// Eine Einstellung des Reglers der Wärmepumpe, gelesen über den Bus.
public struct ReglerEinstellungOut: Codable, Sendable, Hashable {
    public var schluessel: String
    public var nameDe: String
    public var gruppeDe: String
    public var kennung: String
    public var einheit: String?
    public var stellen: Int?
    public var wert: Messwert
    public var lesartDe: String?
    public var art: ReglerEinstellungOutArtWahl?
    public var stellbar: Bool?
    public var von: Double?
    public var bis: Double?
    public var schritt: Double?
    public var wahl: [String: String]
    public var bestaetigt: Bool?
    public var muster: Bool?
    public var hinweisDe: String?
    public var gesendet: ReglerGesendetOut?

    public enum CodingKeys: String, CodingKey {
        case schluessel
        case nameDe = "name_de"
        case gruppeDe = "gruppe_de"
        case kennung
        case einheit
        case stellen
        case wert
        case lesartDe = "lesart_de"
        case art
        case stellbar
        case von
        case bis
        case schritt
        case wahl
        case bestaetigt
        case muster
        case hinweisDe = "hinweis_de"
        case gesendet
    }

    public init(schluessel: String, nameDe: String, gruppeDe: String, kennung: String, einheit: String? = nil, stellen: Int? = nil, wert: Messwert, lesartDe: String? = nil, art: ReglerEinstellungOutArtWahl? = nil, stellbar: Bool? = nil, von: Double? = nil, bis: Double? = nil, schritt: Double? = nil, wahl: [String: String] = [:], bestaetigt: Bool? = nil, muster: Bool? = nil, hinweisDe: String? = nil, gesendet: ReglerGesendetOut? = nil) {
        self.schluessel = schluessel
        self.nameDe = nameDe
        self.gruppeDe = gruppeDe
        self.kennung = kennung
        self.einheit = einheit
        self.stellen = stellen
        self.wert = wert
        self.lesartDe = lesartDe
        self.art = art
        self.stellbar = stellbar
        self.von = von
        self.bis = bis
        self.schritt = schritt
        self.wahl = wahl
        self.bestaetigt = bestaetigt
        self.muster = muster
        self.hinweisDe = hinweisDe
        self.gesendet = gesendet
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schluessel = try c.decode(String.self, forKey: .schluessel)
        self.nameDe = try c.decode(String.self, forKey: .nameDe)
        self.gruppeDe = try c.decode(String.self, forKey: .gruppeDe)
        self.kennung = try c.decode(String.self, forKey: .kennung)
        self.einheit = try c.decodeIfPresent(String.self, forKey: .einheit)
        self.stellen = try c.decodeIfPresent(Int.self, forKey: .stellen)
        self.wert = try c.decode(Messwert.self, forKey: .wert)
        self.lesartDe = try c.decodeIfPresent(String.self, forKey: .lesartDe)
        self.art = try c.decodeIfPresent(ReglerEinstellungOutArtWahl.self, forKey: .art)
        self.stellbar = try c.decodeIfPresent(Bool.self, forKey: .stellbar)
        self.von = try c.decodeIfPresent(Double.self, forKey: .von)
        self.bis = try c.decodeIfPresent(Double.self, forKey: .bis)
        self.schritt = try c.decodeIfPresent(Double.self, forKey: .schritt)
        self.wahl = try c.decodeIfPresent([String: String].self, forKey: .wahl) ?? [:]
        self.bestaetigt = try c.decodeIfPresent(Bool.self, forKey: .bestaetigt)
        self.muster = try c.decodeIfPresent(Bool.self, forKey: .muster)
        self.hinweisDe = try c.decodeIfPresent(String.self, forKey: .hinweisDe)
        self.gesendet = try c.decodeIfPresent(ReglerGesendetOut.self, forKey: .gesendet)
    }
}

/// Was am Regler der Wärmepumpe eingestellt ist, und was sich davon stellen lässt.
public struct ReglerEinstellungenOut: Codable, Sendable, Hashable {
    public var now: String
    public var gelesen: Int
    public var satzDe: String
    public var werte: [ReglerEinstellungOut]
    public var stellenMoeglich: Bool?
    public var hindernisDe: String?
    public var stellenJeTag: Int?
    public var protokoll: [ReglerAenderungOut]
    public var hinweiseDe: [String]

    public enum CodingKeys: String, CodingKey {
        case now
        case gelesen
        case satzDe = "satz_de"
        case werte
        case stellenMoeglich = "stellen_moeglich"
        case hindernisDe = "hindernis_de"
        case stellenJeTag = "stellen_je_tag"
        case protokoll
        case hinweiseDe = "hinweise_de"
    }

    public init(now: String, gelesen: Int, satzDe: String, werte: [ReglerEinstellungOut] = [], stellenMoeglich: Bool? = nil, hindernisDe: String? = nil, stellenJeTag: Int? = nil, protokoll: [ReglerAenderungOut] = [], hinweiseDe: [String] = []) {
        self.now = now
        self.gelesen = gelesen
        self.satzDe = satzDe
        self.werte = werte
        self.stellenMoeglich = stellenMoeglich
        self.hindernisDe = hindernisDe
        self.stellenJeTag = stellenJeTag
        self.protokoll = protokoll
        self.hinweiseDe = hinweiseDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.now = try c.decode(String.self, forKey: .now)
        self.gelesen = try c.decode(Int.self, forKey: .gelesen)
        self.satzDe = try c.decode(String.self, forKey: .satzDe)
        self.werte = try c.decodeIfPresent([ReglerEinstellungOut].self, forKey: .werte) ?? []
        self.stellenMoeglich = try c.decodeIfPresent(Bool.self, forKey: .stellenMoeglich)
        self.hindernisDe = try c.decodeIfPresent(String.self, forKey: .hindernisDe)
        self.stellenJeTag = try c.decodeIfPresent(Int.self, forKey: .stellenJeTag)
        self.protokoll = try c.decodeIfPresent([ReglerAenderungOut].self, forKey: .protokoll) ?? []
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
    }
}

/// Ein Stellbefehl, der hinausgegangen ist und dessen Rückmeldung noch aussteht.
public struct ReglerGesendetOut: Codable, Sendable, Hashable {
    public var wert: Double
    public var at: String

    public init(wert: Double, at: String) {
        self.wert = wert
        self.at = at
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wert = try c.decode(Double.self, forKey: .wert)
        self.at = try c.decode(String.self, forKey: .at)
    }
}

/// Was in den Minuten geschah, in denen der Regler diese Kennzahl sendete.
public struct ReglerKennzahlOut: Codable, Sendable, Hashable {
    public var code: Int
    public var minuten: Int
    public var laufMin: Int
    public var vorlaufC: Double?
    public var vorlaufSollC: Double?
    public var obenKH: Double?
    public var untenKH: Double?
    public var angefordertAnteil: Double?
    public var zusatzKw: Double?
    public var heizanforderungAnteil: Double?
    public var flag1b45Anteil: Double?
    public var ventil1Anteil: Double?
    public var heizstabAnteil: Double?
    public var zuletzt: String?

    public enum CodingKeys: String, CodingKey {
        case code
        case minuten
        case laufMin = "lauf_min"
        case vorlaufC = "vorlauf_c"
        case vorlaufSollC = "vorlauf_soll_c"
        case obenKH = "oben_k_h"
        case untenKH = "unten_k_h"
        case angefordertAnteil = "angefordert_anteil"
        case zusatzKw = "zusatz_kw"
        case heizanforderungAnteil = "heizanforderung_anteil"
        case flag1b45Anteil = "flag_1b45_anteil"
        case ventil1Anteil = "ventil_1_anteil"
        case heizstabAnteil = "heizstab_anteil"
        case zuletzt
    }

    public init(code: Int, minuten: Int, laufMin: Int, vorlaufC: Double? = nil, vorlaufSollC: Double? = nil, obenKH: Double? = nil, untenKH: Double? = nil, angefordertAnteil: Double? = nil, zusatzKw: Double? = nil, heizanforderungAnteil: Double? = nil, flag1b45Anteil: Double? = nil, ventil1Anteil: Double? = nil, heizstabAnteil: Double? = nil, zuletzt: String? = nil) {
        self.code = code
        self.minuten = minuten
        self.laufMin = laufMin
        self.vorlaufC = vorlaufC
        self.vorlaufSollC = vorlaufSollC
        self.obenKH = obenKH
        self.untenKH = untenKH
        self.angefordertAnteil = angefordertAnteil
        self.zusatzKw = zusatzKw
        self.heizanforderungAnteil = heizanforderungAnteil
        self.flag1b45Anteil = flag1b45Anteil
        self.ventil1Anteil = ventil1Anteil
        self.heizstabAnteil = heizstabAnteil
        self.zuletzt = zuletzt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try c.decode(Int.self, forKey: .code)
        self.minuten = try c.decode(Int.self, forKey: .minuten)
        self.laufMin = try c.decode(Int.self, forKey: .laufMin)
        self.vorlaufC = try c.decodeIfPresent(Double.self, forKey: .vorlaufC)
        self.vorlaufSollC = try c.decodeIfPresent(Double.self, forKey: .vorlaufSollC)
        self.obenKH = try c.decodeIfPresent(Double.self, forKey: .obenKH)
        self.untenKH = try c.decodeIfPresent(Double.self, forKey: .untenKH)
        self.angefordertAnteil = try c.decodeIfPresent(Double.self, forKey: .angefordertAnteil)
        self.zusatzKw = try c.decodeIfPresent(Double.self, forKey: .zusatzKw)
        self.heizanforderungAnteil = try c.decodeIfPresent(Double.self, forKey: .heizanforderungAnteil)
        self.flag1b45Anteil = try c.decodeIfPresent(Double.self, forKey: .flag1b45Anteil)
        self.ventil1Anteil = try c.decodeIfPresent(Double.self, forKey: .ventil1Anteil)
        self.heizstabAnteil = try c.decodeIfPresent(Double.self, forKey: .heizstabAnteil)
        self.zuletzt = try c.decodeIfPresent(String.self, forKey: .zuletzt)
    }
}

public struct ReglerKennzahlenOut: Codable, Sendable, Hashable {
    public var now: String
    public var tage: Int
    public var zeilen: [ReglerKennzahlOut]

    public init(now: String, tage: Int, zeilen: [ReglerKennzahlOut] = []) {
        self.now = now
        self.tage = tage
        self.zeilen = zeilen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.now = try c.decode(String.self, forKey: .now)
        self.tage = try c.decode(Int.self, forKey: .tage)
        self.zeilen = try c.decodeIfPresent([ReglerKennzahlOut].self, forKey: .zeilen) ?? []
    }
}

public struct ReglerStellenIn: Codable, Sendable, Hashable {
    public var wert: Double

    public init(wert: Double) {
        self.wert = wert
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wert = try c.decode(Double.self, forKey: .wert)
    }
}

/// Die Antwort auf einen Stellbefehl oder eine Bestätigung: ob es ging, ein Satz dazu, und
/// der Stand danach.
public struct ReglerStellenOut: Codable, Sendable, Hashable {
    public var ok: Bool
    public var messageDe: String
    public var einstellungen: ReglerEinstellungenOut

    public enum CodingKeys: String, CodingKey {
        case ok
        case messageDe = "message_de"
        case einstellungen
    }

    public init(ok: Bool, messageDe: String, einstellungen: ReglerEinstellungenOut) {
        self.ok = ok
        self.messageDe = messageDe
        self.einstellungen = einstellungen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decode(Bool.self, forKey: .ok)
        self.messageDe = try c.decode(String.self, forKey: .messageDe)
        self.einstellungen = try c.decode(ReglerEinstellungenOut.self, forKey: .einstellungen)
    }
}

/// Eine Reihe im Rückblick: ihre Wertung über alles und je Vorlaufklasse.
public struct ReiheOut: Codable, Sendable, Hashable {
    public var key: String
    public var labelDe: String
    public var einheit: String
    public var gesamt: Wertung
    public var jeVorlauf: [VorlaufOut]
    public var laeufe: Int

    public enum CodingKeys: String, CodingKey {
        case key
        case labelDe = "label_de"
        case einheit
        case gesamt
        case jeVorlauf = "je_vorlauf"
        case laeufe
    }

    public init(key: String, labelDe: String, einheit: String, gesamt: Wertung, jeVorlauf: [VorlaufOut] = [], laeufe: Int) {
        self.key = key
        self.labelDe = labelDe
        self.einheit = einheit
        self.gesamt = gesamt
        self.jeVorlauf = jeVorlauf
        self.laeufe = laeufe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
        self.einheit = try c.decode(String.self, forKey: .einheit)
        self.gesamt = try c.decode(Wertung.self, forKey: .gesamt)
        self.jeVorlauf = try c.decodeIfPresent([VorlaufOut].self, forKey: .jeVorlauf) ?? []
        self.laeufe = try c.decode(Int.self, forKey: .laeufe)
    }
}

public struct ReservenAnsicht: Codable, Sendable, Hashable {
    public var durchtritt: Double?
    public var periodeMin: Double?
    public var phasenreserveGrad: Double?
    public var amplitudenreserve: Double?
    public var gut: Bool

    public enum CodingKeys: String, CodingKey {
        case durchtritt
        case periodeMin = "periode_min"
        case phasenreserveGrad = "phasenreserve_grad"
        case amplitudenreserve
        case gut
    }

    public init(durchtritt: Double? = nil, periodeMin: Double? = nil, phasenreserveGrad: Double? = nil, amplitudenreserve: Double? = nil, gut: Bool) {
        self.durchtritt = durchtritt
        self.periodeMin = periodeMin
        self.phasenreserveGrad = phasenreserveGrad
        self.amplitudenreserve = amplitudenreserve
        self.gut = gut
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.durchtritt = try c.decodeIfPresent(Double.self, forKey: .durchtritt)
        self.periodeMin = try c.decodeIfPresent(Double.self, forKey: .periodeMin)
        self.phasenreserveGrad = try c.decodeIfPresent(Double.self, forKey: .phasenreserveGrad)
        self.amplitudenreserve = try c.decodeIfPresent(Double.self, forKey: .amplitudenreserve)
        self.gut = try c.decode(Bool.self, forKey: .gut)
    }
}

/// Ein Raum als Rechteck. `room_id` ist die Kennung der Einzelraumregelung; ohne sie zeigt die
/// Anzeige den Namen, aber keine Temperatur.
public struct Room: Codable, Sendable, Hashable {
    public var name: String
    public var roomId: Int?
    public var x0: Double
    public var z0: Double
    public var x1: Double
    public var z1: Double
    public var partOf: String?
    public var minor: Bool?
    public var silent: Bool?
    public var `open`: Bool?
    public var cold: Bool?
    public var tech: Bool?
    public var tiles: Bool?
    public var noWalls: String?
    public var railing: String?

    public enum CodingKeys: String, CodingKey {
        case name
        case roomId = "room_id"
        case x0
        case z0
        case x1
        case z1
        case partOf = "part_of"
        case minor
        case silent
        case `open`
        case cold
        case tech
        case tiles
        case noWalls = "no_walls"
        case railing
    }

    public init(name: String, roomId: Int? = nil, x0: Double, z0: Double, x1: Double, z1: Double, partOf: String? = nil, minor: Bool? = nil, silent: Bool? = nil, open: Bool? = nil, cold: Bool? = nil, tech: Bool? = nil, tiles: Bool? = nil, noWalls: String? = nil, railing: String? = nil) {
        self.name = name
        self.roomId = roomId
        self.x0 = x0
        self.z0 = z0
        self.x1 = x1
        self.z1 = z1
        self.partOf = partOf
        self.minor = minor
        self.silent = silent
        self.`open` = open
        self.cold = cold
        self.tech = tech
        self.tiles = tiles
        self.noWalls = noWalls
        self.railing = railing
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.roomId = try c.decodeIfPresent(Int.self, forKey: .roomId)
        self.x0 = try c.decode(Double.self, forKey: .x0)
        self.z0 = try c.decode(Double.self, forKey: .z0)
        self.x1 = try c.decode(Double.self, forKey: .x1)
        self.z1 = try c.decode(Double.self, forKey: .z1)
        self.partOf = try c.decodeIfPresent(String.self, forKey: .partOf)
        self.minor = try c.decodeIfPresent(Bool.self, forKey: .minor)
        self.silent = try c.decodeIfPresent(Bool.self, forKey: .silent)
        self.`open` = try c.decodeIfPresent(Bool.self, forKey: .`open`)
        self.cold = try c.decodeIfPresent(Bool.self, forKey: .cold)
        self.tech = try c.decodeIfPresent(Bool.self, forKey: .tech)
        self.tiles = try c.decodeIfPresent(Bool.self, forKey: .tiles)
        self.noWalls = try c.decodeIfPresent(String.self, forKey: .noWalls)
        self.railing = try c.decodeIfPresent(String.self, forKey: .railing)
    }
}

/// Was eine Sollwertänderung in diesem Raum bedeutet - geschätzt, mit Herkunft im Satz.
///
/// Die Zahlen sind klein und ihre Grundlage ist eine Annahme; beides muss die Anzeige sagen. Der
/// Zweck ist nicht die zweite Nachkommastelle, sondern die Größenordnung: ob ein halbes Grad
/// Cent oder Euro kostet, und ob Vorladen vor dem Preishoch überhaupt lohnt.
public struct RoomEffectOut: Codable, Sendable, Hashable {
    public var roomId: Int
    public var name: String
    public var deltaK: Double
    public var share: Double
    public var dailyKwhTh: Double
    public var dailyKwhEl: Double
    public var dailyEur: Double
    public var storeKwhTh: Double
    public var storeKwhEl: Double
    public var shiftSavingEur: Double?
    public var halfLifeH: Double
    public var cop: Double
    public var outdoorC: Double
    public var aussenGemessen: Bool
    public var priceCtKwh: Double?
    public var cheapCtKwh: Double?
    public var expensiveCtKwh: Double?
    public var noteDe: String

    public enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case name
        case deltaK = "delta_k"
        case share
        case dailyKwhTh = "daily_kwh_th"
        case dailyKwhEl = "daily_kwh_el"
        case dailyEur = "daily_eur"
        case storeKwhTh = "store_kwh_th"
        case storeKwhEl = "store_kwh_el"
        case shiftSavingEur = "shift_saving_eur"
        case halfLifeH = "half_life_h"
        case cop
        case outdoorC = "outdoor_c"
        case aussenGemessen = "aussen_gemessen"
        case priceCtKwh = "price_ct_kwh"
        case cheapCtKwh = "cheap_ct_kwh"
        case expensiveCtKwh = "expensive_ct_kwh"
        case noteDe = "note_de"
    }

    public init(roomId: Int, name: String, deltaK: Double, share: Double, dailyKwhTh: Double, dailyKwhEl: Double, dailyEur: Double, storeKwhTh: Double, storeKwhEl: Double, shiftSavingEur: Double? = nil, halfLifeH: Double, cop: Double, outdoorC: Double, aussenGemessen: Bool, priceCtKwh: Double? = nil, cheapCtKwh: Double? = nil, expensiveCtKwh: Double? = nil, noteDe: String) {
        self.roomId = roomId
        self.name = name
        self.deltaK = deltaK
        self.share = share
        self.dailyKwhTh = dailyKwhTh
        self.dailyKwhEl = dailyKwhEl
        self.dailyEur = dailyEur
        self.storeKwhTh = storeKwhTh
        self.storeKwhEl = storeKwhEl
        self.shiftSavingEur = shiftSavingEur
        self.halfLifeH = halfLifeH
        self.cop = cop
        self.outdoorC = outdoorC
        self.aussenGemessen = aussenGemessen
        self.priceCtKwh = priceCtKwh
        self.cheapCtKwh = cheapCtKwh
        self.expensiveCtKwh = expensiveCtKwh
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.roomId = try c.decode(Int.self, forKey: .roomId)
        self.name = try c.decode(String.self, forKey: .name)
        self.deltaK = try c.decode(Double.self, forKey: .deltaK)
        self.share = try c.decode(Double.self, forKey: .share)
        self.dailyKwhTh = try c.decode(Double.self, forKey: .dailyKwhTh)
        self.dailyKwhEl = try c.decode(Double.self, forKey: .dailyKwhEl)
        self.dailyEur = try c.decode(Double.self, forKey: .dailyEur)
        self.storeKwhTh = try c.decode(Double.self, forKey: .storeKwhTh)
        self.storeKwhEl = try c.decode(Double.self, forKey: .storeKwhEl)
        self.shiftSavingEur = try c.decodeIfPresent(Double.self, forKey: .shiftSavingEur)
        self.halfLifeH = try c.decode(Double.self, forKey: .halfLifeH)
        self.cop = try c.decode(Double.self, forKey: .cop)
        self.outdoorC = try c.decode(Double.self, forKey: .outdoorC)
        self.aussenGemessen = try c.decode(Bool.self, forKey: .aussenGemessen)
        self.priceCtKwh = try c.decodeIfPresent(Double.self, forKey: .priceCtKwh)
        self.cheapCtKwh = try c.decodeIfPresent(Double.self, forKey: .cheapCtKwh)
        self.expensiveCtKwh = try c.decodeIfPresent(Double.self, forKey: .expensiveCtKwh)
        self.noteDe = try c.decode(String.self, forKey: .noteDe)
    }
}

public struct RoomHistoryOut: Codable, Sendable, Hashable {
    public var start: String
    public var end: String
    public var stepMin: Int
    public var ts: [String]
    public var rooms: [RoomSeriesOut]

    public enum CodingKeys: String, CodingKey {
        case start
        case end
        case stepMin = "step_min"
        case ts
        case rooms
    }

    public init(start: String, end: String, stepMin: Int, ts: [String] = [], rooms: [RoomSeriesOut] = []) {
        self.start = start
        self.end = end
        self.stepMin = stepMin
        self.ts = ts
        self.rooms = rooms
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.stepMin = try c.decode(Int.self, forKey: .stepMin)
        self.ts = try c.decodeIfPresent([String].self, forKey: .ts) ?? []
        self.rooms = try c.decodeIfPresent([RoomSeriesOut].self, forKey: .rooms) ?? []
    }
}

/// Ein Raum im Augenblick.
///
/// `deviation_k` wird hier gerechnet und nicht in der Anzeige, weil zur Abweichung die Frage
/// gehört, auf welchen Wert sie sich bezieht - und die ist entschieden: auf `target_c`, den
/// Sollwert **plus** Offset. Contromes Oberfläche rechnet es selbst vor (`21,00 - 0,32` über
/// `20,68`). `setpoint_c` und `offset_k` stehen weiter einzeln daneben, damit die Rechnung
/// nachvollziehbar bleibt und ein falsches Vorzeichen auffällt.
///
/// **Jedes Feld ist angegeben, keines hat eine Voreinstellung.** Das ist keine Pedanterie: Aus den
/// Voreinstellungen wird in der erzeugten Schnittstellenbeschreibung „darf fehlen", und in der App
/// heißt das für jede Zahl eine zweite Möglichkeit neben `null` - undefiniert -, die dasselbe
/// bedeutet und trotzdem überall mitgeprüft werden müsste.
public struct RoomLiveOut: Codable, Sendable, Hashable {
    public var id: Int
    public var name: String
    public var floor: String
    public var circuits: Int
    public var tempC: Double?
    public var setpointC: Double?
    public var offsetK: Double?
    public var targetC: Double?
    public var humidityPct: Double?
    public var valve: Double?
    public var window: Double?
    public var deviationK: Double?
    public var observedAt: String?
    public var quality: Quality

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case floor
        case circuits
        case tempC = "temp_c"
        case setpointC = "setpoint_c"
        case offsetK = "offset_k"
        case targetC = "target_c"
        case humidityPct = "humidity_pct"
        case valve
        case window
        case deviationK = "deviation_k"
        case observedAt = "observed_at"
        case quality
    }

    public init(id: Int, name: String, floor: String, circuits: Int, tempC: Double? = nil, setpointC: Double? = nil, offsetK: Double? = nil, targetC: Double? = nil, humidityPct: Double? = nil, valve: Double? = nil, window: Double? = nil, deviationK: Double? = nil, observedAt: String? = nil, quality: Quality) {
        self.id = id
        self.name = name
        self.floor = floor
        self.circuits = circuits
        self.tempC = tempC
        self.setpointC = setpointC
        self.offsetK = offsetK
        self.targetC = targetC
        self.humidityPct = humidityPct
        self.valve = valve
        self.window = window
        self.deviationK = deviationK
        self.observedAt = observedAt
        self.quality = quality
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.floor = try c.decode(String.self, forKey: .floor)
        self.circuits = try c.decode(Int.self, forKey: .circuits)
        self.tempC = try c.decodeIfPresent(Double.self, forKey: .tempC)
        self.setpointC = try c.decodeIfPresent(Double.self, forKey: .setpointC)
        self.offsetK = try c.decodeIfPresent(Double.self, forKey: .offsetK)
        self.targetC = try c.decodeIfPresent(Double.self, forKey: .targetC)
        self.humidityPct = try c.decodeIfPresent(Double.self, forKey: .humidityPct)
        self.valve = try c.decodeIfPresent(Double.self, forKey: .valve)
        self.window = try c.decodeIfPresent(Double.self, forKey: .window)
        self.deviationK = try c.decodeIfPresent(Double.self, forKey: .deviationK)
        self.observedAt = try c.decodeIfPresent(String.self, forKey: .observedAt)
        self.quality = try c.decode(Quality.self, forKey: .quality)
    }
}

/// Eine Zeile der Zeitleiste: wann sich der Sollwert geändert hat und wer es war.
///
/// `quelle` ist `app` (hier gestellt), `automatik` oder `extern`. **`extern` heißt nicht
/// „der Nutzer"**, sondern nur: nicht über dieses Werkzeug. Dahinter stecken die Controme-App,
/// das Bedienteil an der Wand oder Contromes eigenes Heizprogramm, und diese drei lassen sich
/// von hier aus nicht unterscheiden.
///
/// `art` ist `sollwert` (gemessene Änderung), `befehl` (geschickt, aber nie gemeldet),
/// `ruhe` (die Automatik zieht sich zurück) oder `einstellung` (die Automatik wurde geschaltet).
public struct RoomLogEntryOut: Codable, Sendable, Hashable {
    public var at: String
    public var quelle: RoomLogEntryOutQuelleWahl
    public var art: RoomLogEntryOutArtWahl
    public var fromC: Double?
    public var toC: Double?
    public var text: String
    public var urheber: String?

    public enum CodingKeys: String, CodingKey {
        case at
        case quelle
        case art
        case fromC = "from_c"
        case toC = "to_c"
        case text
        case urheber
    }

    public init(at: String, quelle: RoomLogEntryOutQuelleWahl, art: RoomLogEntryOutArtWahl, fromC: Double? = nil, toC: Double? = nil, text: String, urheber: String? = nil) {
        self.at = at
        self.quelle = quelle
        self.art = art
        self.fromC = fromC
        self.toC = toC
        self.text = text
        self.urheber = urheber
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.quelle = try c.decode(RoomLogEntryOutQuelleWahl.self, forKey: .quelle)
        self.art = try c.decode(RoomLogEntryOutArtWahl.self, forKey: .art)
        self.fromC = try c.decodeIfPresent(Double.self, forKey: .fromC)
        self.toC = try c.decodeIfPresent(Double.self, forKey: .toC)
        self.text = try c.decode(String.self, forKey: .text)
        self.urheber = try c.decodeIfPresent(String.self, forKey: .urheber)
    }
}

/// Das Protokoll eines Raums: Zeitreihe und Zeitleiste über denselben Zeitraum.
public struct RoomLogOut: Codable, Sendable, Hashable {
    public var room: RoomSeriesOut
    public var start: String
    public var end: String
    public var stepMin: Int
    public var ts: [String]
    public var targetC: [Double?]
    public var entries: [RoomLogEntryOut]

    public enum CodingKeys: String, CodingKey {
        case room
        case start
        case end
        case stepMin = "step_min"
        case ts
        case targetC = "target_c"
        case entries
    }

    public init(room: RoomSeriesOut, start: String, end: String, stepMin: Int, ts: [String] = [], targetC: [Double?] = [], entries: [RoomLogEntryOut] = []) {
        self.room = room
        self.start = start
        self.end = end
        self.stepMin = stepMin
        self.ts = ts
        self.targetC = targetC
        self.entries = entries
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.room = try c.decode(RoomSeriesOut.self, forKey: .room)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.stepMin = try c.decode(Int.self, forKey: .stepMin)
        self.ts = try c.decodeIfPresent([String].self, forKey: .ts) ?? []
        self.targetC = try c.decodeIfPresent([Double?].self, forKey: .targetC) ?? []
        self.entries = try c.decodeIfPresent([RoomLogEntryOut].self, forKey: .entries) ?? []
    }
}

/// Eine Raumzeitreihe spaltenweise: alle Listen so lang wie `ts` der Hülle.
public struct RoomSeriesOut: Codable, Sendable, Hashable {
    public var id: Int
    public var name: String
    public var floor: String
    public var circuits: Int
    public var tempC: [Double?]
    public var setpointC: [Double?]
    public var offsetK: [Double?]
    public var valve: [Double?]
    public var window: [Double?]

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case floor
        case circuits
        case tempC = "temp_c"
        case setpointC = "setpoint_c"
        case offsetK = "offset_k"
        case valve
        case window
    }

    public init(id: Int, name: String, floor: String, circuits: Int, tempC: [Double?] = [], setpointC: [Double?] = [], offsetK: [Double?] = [], valve: [Double?] = [], window: [Double?] = []) {
        self.id = id
        self.name = name
        self.floor = floor
        self.circuits = circuits
        self.tempC = tempC
        self.setpointC = setpointC
        self.offsetK = offsetK
        self.valve = valve
        self.window = window
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.floor = try c.decode(String.self, forKey: .floor)
        self.circuits = try c.decode(Int.self, forKey: .circuits)
        self.tempC = try c.decodeIfPresent([Double?].self, forKey: .tempC) ?? []
        self.setpointC = try c.decodeIfPresent([Double?].self, forKey: .setpointC) ?? []
        self.offsetK = try c.decodeIfPresent([Double?].self, forKey: .offsetK) ?? []
        self.valve = try c.decodeIfPresent([Double?].self, forKey: .valve) ?? []
        self.window = try c.decodeIfPresent([Double?].self, forKey: .window) ?? []
    }
}

/// Ein von Hand gestellter Sollwert, dauerhaft.
///
/// Ohne Frist und ohne Rücknahme: Wer in Controme am Sollwert dreht, meint es so, bis er es
/// anders meint. Ein Wert auf Zeit wäre eine zweite Wahrheit neben der, die der Regler kennt.
public struct RoomSetpointIn: Codable, Sendable, Hashable {
    public var setpointC: Double

    public enum CodingKeys: String, CodingKey {
        case setpointC = "setpoint_c"
    }

    public init(setpointC: Double) {
        self.setpointC = setpointC
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.setpointC = try c.decode(Double.self, forKey: .setpointC)
    }
}

public struct RoomSetpointOut: Codable, Sendable, Hashable {
    public var ok: Bool
    public var room: RoomLiveOut
    public var setpointC: Double
    public var messageDe: String

    public enum CodingKeys: String, CodingKey {
        case ok
        case room
        case setpointC = "setpoint_c"
        case messageDe = "message_de"
    }

    public init(ok: Bool, room: RoomLiveOut, setpointC: Double, messageDe: String) {
        self.ok = ok
        self.room = room
        self.setpointC = setpointC
        self.messageDe = messageDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decode(Bool.self, forKey: .ok)
        self.room = try c.decode(RoomLiveOut.self, forKey: .room)
        self.setpointC = try c.decode(Double.self, forKey: .setpointC)
        self.messageDe = try c.decode(String.self, forKey: .messageDe)
    }
}

public struct RoomShiftEventOut: Codable, Sendable, Hashable {
    public var at: String
    public var textDe: String

    public enum CodingKeys: String, CodingKey {
        case at
        case textDe = "text_de"
    }

    public init(at: String, textDe: String) {
        self.at = at
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.textDe = try c.decode(String.self, forKey: .textDe)
    }
}

/// Alles freiwillig: Was fehlt, bleibt, wie es war.
public struct RoomShiftIn: Codable, Sendable, Hashable {
    public var enabled: Bool?
    public var rooms: [Int]?
    public var deltaK: Double?
    public var drawK: Double?
    public var leadH: Double?
    public var minSpreadCt: Double?

    public enum CodingKeys: String, CodingKey {
        case enabled
        case rooms
        case deltaK = "delta_k"
        case drawK = "draw_k"
        case leadH = "lead_h"
        case minSpreadCt = "min_spread_ct"
    }

    public init(enabled: Bool? = nil, rooms: [Int]? = nil, deltaK: Double? = nil, drawK: Double? = nil, leadH: Double? = nil, minSpreadCt: Double? = nil) {
        self.enabled = enabled
        self.rooms = rooms
        self.deltaK = deltaK
        self.drawK = drawK
        self.leadH = leadH
        self.minSpreadCt = minSpreadCt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        self.rooms = try c.decodeIfPresent([Int].self, forKey: .rooms)
        self.deltaK = try c.decodeIfPresent(Double.self, forKey: .deltaK)
        self.drawK = try c.decodeIfPresent(Double.self, forKey: .drawK)
        self.leadH = try c.decodeIfPresent(Double.self, forKey: .leadH)
        self.minSpreadCt = try c.decodeIfPresent(Double.self, forKey: .minSpreadCt)
    }
}

/// Was die Automatik darf, was sie gerade will und was sie getan hat.
///
/// **Aus, bis jemand sie einschaltet.** Das ist die einzige Stelle in Duck Curve Home, an der das
/// Werkzeug von sich aus etwas in der Wohnung verstellt; die Voreinstellung ist deshalb nicht
/// „an mit Vorsicht", sondern „aus".
public struct RoomShiftOut: Codable, Sendable, Hashable {
    public var enabled: Bool
    public var rooms: [Int]
    public var deltaK: Double
    public var drawK: Double
    public var leadH: Double
    public var minSpreadCt: Double
    public var phase: RoomShiftOutPhaseWahl
    public var offsetK: Double
    public var until: String?
    public var windowStart: String?
    public var windowEnd: String?
    public var spreadCt: Double?
    public var reasonDe: String
    public var active: [RoomShiftRoomOut]
    public var log: [RoomShiftEventOut]
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case enabled
        case rooms
        case deltaK = "delta_k"
        case drawK = "draw_k"
        case leadH = "lead_h"
        case minSpreadCt = "min_spread_ct"
        case phase
        case offsetK = "offset_k"
        case until
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case spreadCt = "spread_ct"
        case reasonDe = "reason_de"
        case active
        case log
        case noteDe = "note_de"
    }

    public init(enabled: Bool, rooms: [Int] = [], deltaK: Double, drawK: Double, leadH: Double, minSpreadCt: Double, phase: RoomShiftOutPhaseWahl, offsetK: Double, until: String? = nil, windowStart: String? = nil, windowEnd: String? = nil, spreadCt: Double? = nil, reasonDe: String, active: [RoomShiftRoomOut] = [], log: [RoomShiftEventOut] = [], noteDe: String? = nil) {
        self.enabled = enabled
        self.rooms = rooms
        self.deltaK = deltaK
        self.drawK = drawK
        self.leadH = leadH
        self.minSpreadCt = minSpreadCt
        self.phase = phase
        self.offsetK = offsetK
        self.until = until
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.spreadCt = spreadCt
        self.reasonDe = reasonDe
        self.active = active
        self.log = log
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decode(Bool.self, forKey: .enabled)
        self.rooms = try c.decodeIfPresent([Int].self, forKey: .rooms) ?? []
        self.deltaK = try c.decode(Double.self, forKey: .deltaK)
        self.drawK = try c.decode(Double.self, forKey: .drawK)
        self.leadH = try c.decode(Double.self, forKey: .leadH)
        self.minSpreadCt = try c.decode(Double.self, forKey: .minSpreadCt)
        self.phase = try c.decode(RoomShiftOutPhaseWahl.self, forKey: .phase)
        self.offsetK = try c.decode(Double.self, forKey: .offsetK)
        self.until = try c.decodeIfPresent(String.self, forKey: .until)
        self.windowStart = try c.decodeIfPresent(String.self, forKey: .windowStart)
        self.windowEnd = try c.decodeIfPresent(String.self, forKey: .windowEnd)
        self.spreadCt = try c.decodeIfPresent(Double.self, forKey: .spreadCt)
        self.reasonDe = try c.decode(String.self, forKey: .reasonDe)
        self.active = try c.decodeIfPresent([RoomShiftRoomOut].self, forKey: .active) ?? []
        self.log = try c.decodeIfPresent([RoomShiftEventOut].self, forKey: .log) ?? []
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

/// Ein Raum, in dem die Automatik gerade etwas angestellt hat - oder gerade ruht.
public struct RoomShiftRoomOut: Codable, Sendable, Hashable {
    public var roomId: Int
    public var name: String
    public var baseSetpointC: Double
    public var offsetK: Double
    public var writtenSetpointC: Double
    public var writtenAt: String
    public var pausedUntil: String?

    public enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case name
        case baseSetpointC = "base_setpoint_c"
        case offsetK = "offset_k"
        case writtenSetpointC = "written_setpoint_c"
        case writtenAt = "written_at"
        case pausedUntil = "paused_until"
    }

    public init(roomId: Int, name: String, baseSetpointC: Double, offsetK: Double, writtenSetpointC: Double, writtenAt: String, pausedUntil: String? = nil) {
        self.roomId = roomId
        self.name = name
        self.baseSetpointC = baseSetpointC
        self.offsetK = offsetK
        self.writtenSetpointC = writtenSetpointC
        self.writtenAt = writtenAt
        self.pausedUntil = pausedUntil
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.roomId = try c.decode(Int.self, forKey: .roomId)
        self.name = try c.decode(String.self, forKey: .name)
        self.baseSetpointC = try c.decode(Double.self, forKey: .baseSetpointC)
        self.offsetK = try c.decode(Double.self, forKey: .offsetK)
        self.writtenSetpointC = try c.decode(Double.self, forKey: .writtenSetpointC)
        self.writtenAt = try c.decode(String.self, forKey: .writtenAt)
        self.pausedUntil = try c.decodeIfPresent(String.self, forKey: .pausedUntil)
    }
}

public struct RoomsLiveOut: Codable, Sendable, Hashable {
    public var at: String
    public var named: Bool
    public var rooms: [RoomLiveOut]

    public init(at: String, named: Bool, rooms: [RoomLiveOut] = []) {
        self.at = at
        self.named = named
        self.rooms = rooms
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.named = try c.decode(Bool.self, forKey: .named)
        self.rooms = try c.decodeIfPresent([RoomLiveOut].self, forKey: .rooms) ?? []
    }
}

public struct SensorTimeouts: Codable, Sendable, Hashable {
    public var powerS: Double?
    public var batteryS: Double?
    public var temperatureS: Double?
    public var outdoorTempS: Double?
    public var priceS: Double?

    public enum CodingKeys: String, CodingKey {
        case powerS = "power_s"
        case batteryS = "battery_s"
        case temperatureS = "temperature_s"
        case outdoorTempS = "outdoor_temp_s"
        case priceS = "price_s"
    }

    public init(powerS: Double? = nil, batteryS: Double? = nil, temperatureS: Double? = nil, outdoorTempS: Double? = nil, priceS: Double? = nil) {
        self.powerS = powerS
        self.batteryS = batteryS
        self.temperatureS = temperatureS
        self.outdoorTempS = outdoorTempS
        self.priceS = priceS
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.powerS = try c.decodeIfPresent(Double.self, forKey: .powerS)
        self.batteryS = try c.decodeIfPresent(Double.self, forKey: .batteryS)
        self.temperatureS = try c.decodeIfPresent(Double.self, forKey: .temperatureS)
        self.outdoorTempS = try c.decodeIfPresent(Double.self, forKey: .outdoorTempS)
        self.priceS = try c.decodeIfPresent(Double.self, forKey: .priceS)
    }
}

/// Ein Tag im Vergleichslauf. `note_de` ist leer, wenn gerechnet wurde.
public struct ShiftDayOut: Codable, Sendable, Hashable {
    public var day: String
    public var savingEur: Double
    public var heatPumpKwh: Double
    public var shiftedKwh: Double
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case day
        case savingEur = "saving_eur"
        case heatPumpKwh = "heat_pump_kwh"
        case shiftedKwh = "shifted_kwh"
        case noteDe = "note_de"
    }

    public init(day: String, savingEur: Double, heatPumpKwh: Double, shiftedKwh: Double, noteDe: String? = nil) {
        self.day = day
        self.savingEur = savingEur
        self.heatPumpKwh = heatPumpKwh
        self.shiftedKwh = shiftedKwh
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try c.decode(String.self, forKey: .day)
        self.savingEur = try c.decode(Double.self, forKey: .savingEur)
        self.heatPumpKwh = try c.decode(Double.self, forKey: .heatPumpKwh)
        self.shiftedKwh = try c.decode(Double.self, forKey: .shiftedKwh)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

/// Was das Verschieben der Wärmepumpe gebracht hat - eine Rechnung, keine Messung.
///
/// Der Vergleichslauf legt dieselbe Strommenge in die Stunden, in denen ein gewöhnlicher
/// Thermostat sie gebraucht hätte, und stellt die Stromrechnung beider Läufe gegenüber. Die
/// Annahmen stehen einzeln in `assumptions_de`, weil eine Zahl ohne sie mehr behauptet, als sie
/// weiß.
public struct ShiftReportOut: Codable, Sendable, Hashable {
    public var generatedAt: String
    public var period: ShiftReportOutPeriodWahl
    public var start: String
    public var end: String
    public var actualEur: Double
    public var naiveEur: Double
    public var savingEur: Double
    public var savingCtPerKwh: Double?
    public var heatPumpKwh: Double
    public var shiftedKwh: Double
    public var days: [ShiftDayOut]
    public var daysUsed: Int
    public var daysSkipped: Int
    public var skippedDe: String?
    public var methodDe: String
    public var assumptionsDe: [String]

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case period
        case start
        case end
        case actualEur = "actual_eur"
        case naiveEur = "naive_eur"
        case savingEur = "saving_eur"
        case savingCtPerKwh = "saving_ct_per_kwh"
        case heatPumpKwh = "heat_pump_kwh"
        case shiftedKwh = "shifted_kwh"
        case days
        case daysUsed = "days_used"
        case daysSkipped = "days_skipped"
        case skippedDe = "skipped_de"
        case methodDe = "method_de"
        case assumptionsDe = "assumptions_de"
    }

    public init(generatedAt: String, period: ShiftReportOutPeriodWahl, start: String, end: String, actualEur: Double, naiveEur: Double, savingEur: Double, savingCtPerKwh: Double? = nil, heatPumpKwh: Double, shiftedKwh: Double, days: [ShiftDayOut] = [], daysUsed: Int, daysSkipped: Int, skippedDe: String? = nil, methodDe: String, assumptionsDe: [String] = []) {
        self.generatedAt = generatedAt
        self.period = period
        self.start = start
        self.end = end
        self.actualEur = actualEur
        self.naiveEur = naiveEur
        self.savingEur = savingEur
        self.savingCtPerKwh = savingCtPerKwh
        self.heatPumpKwh = heatPumpKwh
        self.shiftedKwh = shiftedKwh
        self.days = days
        self.daysUsed = daysUsed
        self.daysSkipped = daysSkipped
        self.skippedDe = skippedDe
        self.methodDe = methodDe
        self.assumptionsDe = assumptionsDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(String.self, forKey: .generatedAt)
        self.period = try c.decode(ShiftReportOutPeriodWahl.self, forKey: .period)
        self.start = try c.decode(String.self, forKey: .start)
        self.end = try c.decode(String.self, forKey: .end)
        self.actualEur = try c.decode(Double.self, forKey: .actualEur)
        self.naiveEur = try c.decode(Double.self, forKey: .naiveEur)
        self.savingEur = try c.decode(Double.self, forKey: .savingEur)
        self.savingCtPerKwh = try c.decodeIfPresent(Double.self, forKey: .savingCtPerKwh)
        self.heatPumpKwh = try c.decode(Double.self, forKey: .heatPumpKwh)
        self.shiftedKwh = try c.decode(Double.self, forKey: .shiftedKwh)
        self.days = try c.decodeIfPresent([ShiftDayOut].self, forKey: .days) ?? []
        self.daysUsed = try c.decode(Int.self, forKey: .daysUsed)
        self.daysSkipped = try c.decode(Int.self, forKey: .daysSkipped)
        self.skippedDe = try c.decodeIfPresent(String.self, forKey: .skippedDe)
        self.methodDe = try c.decode(String.self, forKey: .methodDe)
        self.assumptionsDe = try c.decodeIfPresent([String].self, forKey: .assumptionsDe) ?? []
    }
}

public struct SitzungOut: Codable, Sendable, Hashable {
    public var id: String
    public var erstelltAm: String
    public var laeuftAbAm: String
    public var zuletztBenutztAm: String?
    public var herkunft: String?
    public var diese: Bool?

    public enum CodingKeys: String, CodingKey {
        case id
        case erstelltAm = "erstellt_am"
        case laeuftAbAm = "laeuft_ab_am"
        case zuletztBenutztAm = "zuletzt_benutzt_am"
        case herkunft
        case diese
    }

    public init(id: String, erstelltAm: String, laeuftAbAm: String, zuletztBenutztAm: String? = nil, herkunft: String? = nil, diese: Bool? = nil) {
        self.id = id
        self.erstelltAm = erstelltAm
        self.laeuftAbAm = laeuftAbAm
        self.zuletztBenutztAm = zuletztBenutztAm
        self.herkunft = herkunft
        self.diese = diese
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.erstelltAm = try c.decode(String.self, forKey: .erstelltAm)
        self.laeuftAbAm = try c.decode(String.self, forKey: .laeuftAbAm)
        self.zuletztBenutztAm = try c.decodeIfPresent(String.self, forKey: .zuletztBenutztAm)
        self.herkunft = try c.decodeIfPresent(String.self, forKey: .herkunft)
        self.diese = try c.decodeIfPresent(Bool.self, forKey: .diese)
    }
}

public struct SourceOut: Codable, Sendable, Hashable {
    public var name: String
    public var labelDe: String
    public var weight: Double
    public var mae7dKw: Double?
    public var active: Bool

    public enum CodingKeys: String, CodingKey {
        case name
        case labelDe = "label_de"
        case weight
        case mae7dKw = "mae_7d_kw"
        case active
    }

    public init(name: String, labelDe: String, weight: Double, mae7dKw: Double? = nil, active: Bool) {
        self.name = name
        self.labelDe = labelDe
        self.weight = weight
        self.mae7dKw = mae7dKw
        self.active = active
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
        self.weight = try c.decode(Double.self, forKey: .weight)
        self.mae7dKw = try c.decodeIfPresent(Double.self, forKey: .mae7dKw)
        self.active = try c.decode(Bool.self, forKey: .active)
    }
}

/// Zustand einer Messquelle (Bridge, myenergi, …).
public struct SourceStatusOut: Codable, Sendable, Hashable {
    public var name: String
    public var online: Bool
    public var lastOk: String?
    public var detailDe: String?

    public enum CodingKeys: String, CodingKey {
        case name
        case online
        case lastOk = "last_ok"
        case detailDe = "detail_de"
    }

    public init(name: String, online: Bool, lastOk: String? = nil, detailDe: String? = nil) {
        self.name = name
        self.online = online
        self.lastOk = lastOk
        self.detailDe = detailDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.online = try c.decode(Bool.self, forKey: .online)
        self.lastOk = try c.decodeIfPresent(String.self, forKey: .lastOk)
        self.detailDe = try c.decodeIfPresent(String.self, forKey: .detailDe)
    }
}

/// Womit die Datenbank ihren Platz füllt, und wie lange Rohwerte aufgehoben werden.
///
/// Die Aufbewahrung gehört dazu, weil sie der einzige Regler ist, der von außen gestellt werden
/// kann: `measurements_raw` ist ein Durchlauferhitzer für die Verdichtung zu Minutenwerten, alles
/// darüber hinaus ist Vorrat für einen Fall, der selten eintritt.
public struct StorageReportOut: Codable, Sendable, Hashable {
    public var tables: [StorageTableOut]
    public var totalBytes: Int
    public var rawRetentionDays: Int
    public var noteDe: String

    public enum CodingKeys: String, CodingKey {
        case tables
        case totalBytes = "total_bytes"
        case rawRetentionDays = "raw_retention_days"
        case noteDe = "note_de"
    }

    public init(tables: [StorageTableOut] = [], totalBytes: Int, rawRetentionDays: Int, noteDe: String) {
        self.tables = tables
        self.totalBytes = totalBytes
        self.rawRetentionDays = rawRetentionDays
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tables = try c.decodeIfPresent([StorageTableOut].self, forKey: .tables) ?? []
        self.totalBytes = try c.decode(Int.self, forKey: .totalBytes)
        self.rawRetentionDays = try c.decode(Int.self, forKey: .rawRetentionDays)
        self.noteDe = try c.decode(String.self, forKey: .noteDe)
    }
}

/// Platzbedarf einer Tabelle: Daten, Indizes, geschätzte Zeilen.
public struct StorageTableOut: Codable, Sendable, Hashable {
    public var name: String
    public var totalBytes: Int
    public var tableBytes: Int
    public var indexBytes: Int
    public var rowsEstimate: Int

    public enum CodingKeys: String, CodingKey {
        case name
        case totalBytes = "total_bytes"
        case tableBytes = "table_bytes"
        case indexBytes = "index_bytes"
        case rowsEstimate = "rows_estimate"
    }

    public init(name: String, totalBytes: Int, tableBytes: Int, indexBytes: Int, rowsEstimate: Int) {
        self.name = name
        self.totalBytes = totalBytes
        self.tableBytes = tableBytes
        self.indexBytes = indexBytes
        self.rowsEstimate = rowsEstimate
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.totalBytes = try c.decode(Int.self, forKey: .totalBytes)
        self.tableBytes = try c.decode(Int.self, forKey: .tableBytes)
        self.indexBytes = try c.decode(Int.self, forKey: .indexBytes)
        self.rowsEstimate = try c.decode(Int.self, forKey: .rowsEstimate)
    }
}

/// Der Pelletofen als zweite Wärmequelle am selben Puffer.
///
/// Die Zahlen stammen vom Gerät und vom Betreiber, nicht aus einer Messung; der Wärmemengenzähler
/// steht noch aus. Sie sind trotzdem belastbar genug für eine Kostenentscheidung, weil der Ofen
/// praktisch immer unter Volllast läuft und die Aufteilung zwischen Wasser und Raum dann fest ist.
///
/// **Die Kette:** aus der Nennleistung und dem Verbrennungswirkungsgrad folgt die Feuerungsleistung,
/// daraus über den Heizwert der Pelletdurchsatz, daraus über den Preis die Kosten je Stunde. Geteilt
/// durch die Wärme, die tatsächlich ankommt, ergibt das den Wärmepreis, mit dem sich der Ofen gegen
/// die Wärmepumpe vergleichen lässt. Gerechnet wird das in `hems_core.accounting.stove_cost`.
public struct StoveConfig: Codable, Sendable, Hashable {
    public var present: Bool?
    public var controlEnabled: Bool?
    public var nominalHeatKw: Double?
    public var waterHeatKw: Double?
    public var combustionEfficiency: Double?
    public var minHeatKw: Double?
    public var minWaterHeatKw: Double?
    public var minCombustionEfficiency: Double?
    public var electricW: Double?
    public var electricIgnitionW: Double?
    public var pelletKgPerHourMax: Double?
    public var pelletKgPerHourMin: Double?
    public var powerLevels: Int?
    public var hopperKg: Double?
    public var refillsPerDay: Double?
    public var refillHour: Int?
    public var pelletPriceEurPerT: Double?
    public var pelletKwhPerKg: Double?
    public var roomHeatCredit: Double?
    public var minRuntimeMin: Double?
    public var minOfftimeMin: Double?
    public var startCostEur: Double?

    public enum CodingKeys: String, CodingKey {
        case present
        case controlEnabled = "control_enabled"
        case nominalHeatKw = "nominal_heat_kw"
        case waterHeatKw = "water_heat_kw"
        case combustionEfficiency = "combustion_efficiency"
        case minHeatKw = "min_heat_kw"
        case minWaterHeatKw = "min_water_heat_kw"
        case minCombustionEfficiency = "min_combustion_efficiency"
        case electricW = "electric_w"
        case electricIgnitionW = "electric_ignition_w"
        case pelletKgPerHourMax = "pellet_kg_per_hour_max"
        case pelletKgPerHourMin = "pellet_kg_per_hour_min"
        case powerLevels = "power_levels"
        case hopperKg = "hopper_kg"
        case refillsPerDay = "refills_per_day"
        case refillHour = "refill_hour"
        case pelletPriceEurPerT = "pellet_price_eur_per_t"
        case pelletKwhPerKg = "pellet_kwh_per_kg"
        case roomHeatCredit = "room_heat_credit"
        case minRuntimeMin = "min_runtime_min"
        case minOfftimeMin = "min_offtime_min"
        case startCostEur = "start_cost_eur"
    }

    public init(present: Bool? = nil, controlEnabled: Bool? = nil, nominalHeatKw: Double? = nil, waterHeatKw: Double? = nil, combustionEfficiency: Double? = nil, minHeatKw: Double? = nil, minWaterHeatKw: Double? = nil, minCombustionEfficiency: Double? = nil, electricW: Double? = nil, electricIgnitionW: Double? = nil, pelletKgPerHourMax: Double? = nil, pelletKgPerHourMin: Double? = nil, powerLevels: Int? = nil, hopperKg: Double? = nil, refillsPerDay: Double? = nil, refillHour: Int? = nil, pelletPriceEurPerT: Double? = nil, pelletKwhPerKg: Double? = nil, roomHeatCredit: Double? = nil, minRuntimeMin: Double? = nil, minOfftimeMin: Double? = nil, startCostEur: Double? = nil) {
        self.present = present
        self.controlEnabled = controlEnabled
        self.nominalHeatKw = nominalHeatKw
        self.waterHeatKw = waterHeatKw
        self.combustionEfficiency = combustionEfficiency
        self.minHeatKw = minHeatKw
        self.minWaterHeatKw = minWaterHeatKw
        self.minCombustionEfficiency = minCombustionEfficiency
        self.electricW = electricW
        self.electricIgnitionW = electricIgnitionW
        self.pelletKgPerHourMax = pelletKgPerHourMax
        self.pelletKgPerHourMin = pelletKgPerHourMin
        self.powerLevels = powerLevels
        self.hopperKg = hopperKg
        self.refillsPerDay = refillsPerDay
        self.refillHour = refillHour
        self.pelletPriceEurPerT = pelletPriceEurPerT
        self.pelletKwhPerKg = pelletKwhPerKg
        self.roomHeatCredit = roomHeatCredit
        self.minRuntimeMin = minRuntimeMin
        self.minOfftimeMin = minOfftimeMin
        self.startCostEur = startCostEur
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.present = try c.decodeIfPresent(Bool.self, forKey: .present)
        self.controlEnabled = try c.decodeIfPresent(Bool.self, forKey: .controlEnabled)
        self.nominalHeatKw = try c.decodeIfPresent(Double.self, forKey: .nominalHeatKw)
        self.waterHeatKw = try c.decodeIfPresent(Double.self, forKey: .waterHeatKw)
        self.combustionEfficiency = try c.decodeIfPresent(Double.self, forKey: .combustionEfficiency)
        self.minHeatKw = try c.decodeIfPresent(Double.self, forKey: .minHeatKw)
        self.minWaterHeatKw = try c.decodeIfPresent(Double.self, forKey: .minWaterHeatKw)
        self.minCombustionEfficiency = try c.decodeIfPresent(Double.self, forKey: .minCombustionEfficiency)
        self.electricW = try c.decodeIfPresent(Double.self, forKey: .electricW)
        self.electricIgnitionW = try c.decodeIfPresent(Double.self, forKey: .electricIgnitionW)
        self.pelletKgPerHourMax = try c.decodeIfPresent(Double.self, forKey: .pelletKgPerHourMax)
        self.pelletKgPerHourMin = try c.decodeIfPresent(Double.self, forKey: .pelletKgPerHourMin)
        self.powerLevels = try c.decodeIfPresent(Int.self, forKey: .powerLevels)
        self.hopperKg = try c.decodeIfPresent(Double.self, forKey: .hopperKg)
        self.refillsPerDay = try c.decodeIfPresent(Double.self, forKey: .refillsPerDay)
        self.refillHour = try c.decodeIfPresent(Int.self, forKey: .refillHour)
        self.pelletPriceEurPerT = try c.decodeIfPresent(Double.self, forKey: .pelletPriceEurPerT)
        self.pelletKwhPerKg = try c.decodeIfPresent(Double.self, forKey: .pelletKwhPerKg)
        self.roomHeatCredit = try c.decodeIfPresent(Double.self, forKey: .roomHeatCredit)
        self.minRuntimeMin = try c.decodeIfPresent(Double.self, forKey: .minRuntimeMin)
        self.minOfftimeMin = try c.decodeIfPresent(Double.self, forKey: .minOfftimeMin)
        self.startCostEur = try c.decodeIfPresent(Double.self, forKey: .startCostEur)
    }
}

/// Der Pelletofen im Augenblick: was er tut und ob DCH ihn schalten darf.
///
/// Zwei Dinge sind hier bewusst getrennt. `running` ist eine **Beobachtung** aus dem Maestro-Modul;
/// `mode` ist eine **Absicht** des Bedienenden. Beide können auseinanderlaufen: ein Ofen braucht
/// Minuten zum Zünden und noch mehr zum Ausbrennen, und in dieser Zeit sagt die Oberfläche „an"
/// (gewollt) und „läuft nicht" (gemessen) zugleich. Genau das soll sie auch.
///
/// `control_enabled` ist die Freigabe aus der Konfiguration. Ist sie aus, zeigt die Leiste den Ofen
/// weiterhin an, aber ohne Schaltflächen: eine Feuerstätte fernzustarten gehört nicht zu den
/// Dingen, die standardmäßig eingeschaltet sind.
public struct StoveLiveOut: Codable, Sendable, Hashable {
    public var present: Bool?
    public var controlEnabled: Bool?
    public var mode: StoveLiveOutModeWahl?
    public var endsAt: String?
    public var running: Bool?
    public var powerLevel: Double?
    public var fumeTempC: Double?
    public var boilerTempC: Double?
    public var observedAt: String?
    public var quality: Quality?
    public var plannedOn: Bool?
    public var planUntil: String?
    public var planNoteDe: String?
    public var noteDe: String?

    public enum CodingKeys: String, CodingKey {
        case present
        case controlEnabled = "control_enabled"
        case mode
        case endsAt = "ends_at"
        case running
        case powerLevel = "power_level"
        case fumeTempC = "fume_temp_c"
        case boilerTempC = "boiler_temp_c"
        case observedAt = "observed_at"
        case quality
        case plannedOn = "planned_on"
        case planUntil = "plan_until"
        case planNoteDe = "plan_note_de"
        case noteDe = "note_de"
    }

    public init(present: Bool? = nil, controlEnabled: Bool? = nil, mode: StoveLiveOutModeWahl? = nil, endsAt: String? = nil, running: Bool? = nil, powerLevel: Double? = nil, fumeTempC: Double? = nil, boilerTempC: Double? = nil, observedAt: String? = nil, quality: Quality? = nil, plannedOn: Bool? = nil, planUntil: String? = nil, planNoteDe: String? = nil, noteDe: String? = nil) {
        self.present = present
        self.controlEnabled = controlEnabled
        self.mode = mode
        self.endsAt = endsAt
        self.running = running
        self.powerLevel = powerLevel
        self.fumeTempC = fumeTempC
        self.boilerTempC = boilerTempC
        self.observedAt = observedAt
        self.quality = quality
        self.plannedOn = plannedOn
        self.planUntil = planUntil
        self.planNoteDe = planNoteDe
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.present = try c.decodeIfPresent(Bool.self, forKey: .present)
        self.controlEnabled = try c.decodeIfPresent(Bool.self, forKey: .controlEnabled)
        self.mode = try c.decodeIfPresent(StoveLiveOutModeWahl.self, forKey: .mode)
        self.endsAt = try c.decodeIfPresent(String.self, forKey: .endsAt)
        self.running = try c.decodeIfPresent(Bool.self, forKey: .running)
        self.powerLevel = try c.decodeIfPresent(Double.self, forKey: .powerLevel)
        self.fumeTempC = try c.decodeIfPresent(Double.self, forKey: .fumeTempC)
        self.boilerTempC = try c.decodeIfPresent(Double.self, forKey: .boilerTempC)
        self.observedAt = try c.decodeIfPresent(String.self, forKey: .observedAt)
        self.quality = try c.decodeIfPresent(Quality.self, forKey: .quality)
        self.plannedOn = try c.decodeIfPresent(Bool.self, forKey: .plannedOn)
        self.planUntil = try c.decodeIfPresent(String.self, forKey: .planUntil)
        self.planNoteDe = try c.decodeIfPresent(String.self, forKey: .planNoteDe)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
    }
}

/// `auto` heißt: DCH schaltet nicht und überlässt dem Ofen seine eigene Regelung.
public struct StoveModeIn: Codable, Sendable, Hashable {
    public var mode: StoveModeInModeWahl
    public var durationMin: Int?

    public enum CodingKeys: String, CodingKey {
        case mode
        case durationMin = "duration_min"
    }

    public init(mode: StoveModeInModeWahl, durationMin: Int? = nil) {
        self.mode = mode
        self.durationMin = durationMin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try c.decode(StoveModeInModeWahl.self, forKey: .mode)
        self.durationMin = try c.decodeIfPresent(Int.self, forKey: .durationMin)
    }
}

/// Der Pelletofen im Zeitraum. `available=False` heißt: keine Daten, nicht „lief nicht".
public struct StoveOut: Codable, Sendable, Hashable {
    public var available: Bool?
    public var runningMinutes: Int?
    public var burningMinutes: Int?
    public var runs: Int?
    public var longestRunMin: Int?
    public var augerRevolutions: Double?
    public var fumeTempMaxC: Double?
    public var spreadK: Double?
    public var pumpingMinutes: Int?
    public var dhwMinutes: Int?
    public var minutesByLevel: [String: Int]
    public var operatingHours: Double?
    public var ignitions: Int?
    public var pelletKg: Double?
    public var pelletEur: Double?
    public var noteDe: String?
    public var fuelNoteDe: String?

    public enum CodingKeys: String, CodingKey {
        case available
        case runningMinutes = "running_minutes"
        case burningMinutes = "burning_minutes"
        case runs
        case longestRunMin = "longest_run_min"
        case augerRevolutions = "auger_revolutions"
        case fumeTempMaxC = "fume_temp_max_c"
        case spreadK = "spread_k"
        case pumpingMinutes = "pumping_minutes"
        case dhwMinutes = "dhw_minutes"
        case minutesByLevel = "minutes_by_level"
        case operatingHours = "operating_hours"
        case ignitions
        case pelletKg = "pellet_kg"
        case pelletEur = "pellet_eur"
        case noteDe = "note_de"
        case fuelNoteDe = "fuel_note_de"
    }

    public init(available: Bool? = nil, runningMinutes: Int? = nil, burningMinutes: Int? = nil, runs: Int? = nil, longestRunMin: Int? = nil, augerRevolutions: Double? = nil, fumeTempMaxC: Double? = nil, spreadK: Double? = nil, pumpingMinutes: Int? = nil, dhwMinutes: Int? = nil, minutesByLevel: [String: Int] = [:], operatingHours: Double? = nil, ignitions: Int? = nil, pelletKg: Double? = nil, pelletEur: Double? = nil, noteDe: String? = nil, fuelNoteDe: String? = nil) {
        self.available = available
        self.runningMinutes = runningMinutes
        self.burningMinutes = burningMinutes
        self.runs = runs
        self.longestRunMin = longestRunMin
        self.augerRevolutions = augerRevolutions
        self.fumeTempMaxC = fumeTempMaxC
        self.spreadK = spreadK
        self.pumpingMinutes = pumpingMinutes
        self.dhwMinutes = dhwMinutes
        self.minutesByLevel = minutesByLevel
        self.operatingHours = operatingHours
        self.ignitions = ignitions
        self.pelletKg = pelletKg
        self.pelletEur = pelletEur
        self.noteDe = noteDe
        self.fuelNoteDe = fuelNoteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.available = try c.decodeIfPresent(Bool.self, forKey: .available)
        self.runningMinutes = try c.decodeIfPresent(Int.self, forKey: .runningMinutes)
        self.burningMinutes = try c.decodeIfPresent(Int.self, forKey: .burningMinutes)
        self.runs = try c.decodeIfPresent(Int.self, forKey: .runs)
        self.longestRunMin = try c.decodeIfPresent(Int.self, forKey: .longestRunMin)
        self.augerRevolutions = try c.decodeIfPresent(Double.self, forKey: .augerRevolutions)
        self.fumeTempMaxC = try c.decodeIfPresent(Double.self, forKey: .fumeTempMaxC)
        self.spreadK = try c.decodeIfPresent(Double.self, forKey: .spreadK)
        self.pumpingMinutes = try c.decodeIfPresent(Int.self, forKey: .pumpingMinutes)
        self.dhwMinutes = try c.decodeIfPresent(Int.self, forKey: .dhwMinutes)
        self.minutesByLevel = try c.decodeIfPresent([String: Int].self, forKey: .minutesByLevel) ?? [:]
        self.operatingHours = try c.decodeIfPresent(Double.self, forKey: .operatingHours)
        self.ignitions = try c.decodeIfPresent(Int.self, forKey: .ignitions)
        self.pelletKg = try c.decodeIfPresent(Double.self, forKey: .pelletKg)
        self.pelletEur = try c.decodeIfPresent(Double.self, forKey: .pelletEur)
        self.noteDe = try c.decodeIfPresent(String.self, forKey: .noteDe)
        self.fuelNoteDe = try c.decodeIfPresent(String.self, forKey: .fuelNoteDe)
    }
}

/// Das Streckenmodell eines Kreises, in Zahlen.
public struct StreckeAnsicht: Codable, Sendable, Hashable {
    public var art: StreckeAnsichtArtWahl
    public var k: Double
    public var t1: Double?
    public var t2: Double?
    public var totzeit: Double
    public var t1Entwurf: Double
    public var totzeitEntwurf: Double
    public var halbregel: Bool

    public enum CodingKeys: String, CodingKey {
        case art
        case k
        case t1
        case t2
        case totzeit
        case t1Entwurf = "t1_entwurf"
        case totzeitEntwurf = "totzeit_entwurf"
        case halbregel
    }

    public init(art: StreckeAnsichtArtWahl, k: Double, t1: Double? = nil, t2: Double? = nil, totzeit: Double, t1Entwurf: Double, totzeitEntwurf: Double, halbregel: Bool) {
        self.art = art
        self.k = k
        self.t1 = t1
        self.t2 = t2
        self.totzeit = totzeit
        self.t1Entwurf = t1Entwurf
        self.totzeitEntwurf = totzeitEntwurf
        self.halbregel = halbregel
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(StreckeAnsichtArtWahl.self, forKey: .art)
        self.k = try c.decode(Double.self, forKey: .k)
        self.t1 = try c.decodeIfPresent(Double.self, forKey: .t1)
        self.t2 = try c.decodeIfPresent(Double.self, forKey: .t2)
        self.totzeit = try c.decode(Double.self, forKey: .totzeit)
        self.t1Entwurf = try c.decode(Double.self, forKey: .t1Entwurf)
        self.totzeitEntwurf = try c.decode(Double.self, forKey: .totzeitEntwurf)
        self.halbregel = try c.decode(Bool.self, forKey: .halbregel)
    }
}

/// Sonnenaufgang und Sonnenuntergang eines Tages am Standort des Hauses.
public struct SunDayOut: Codable, Sendable, Hashable {
    public var day: String
    public var sunrise: String
    public var sunset: String

    public init(day: String, sunrise: String, sunset: String) {
        self.day = day
        self.sunrise = sunrise
        self.sunset = sunset
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try c.decode(String.self, forKey: .day)
        self.sunrise = try c.decode(String.self, forKey: .sunrise)
        self.sunset = try c.decode(String.self, forKey: .sunset)
    }
}

public struct SystemEventOut: Codable, Sendable, Hashable {
    public var at: String
    public var severity: String
    public var code: String
    public var message: String
    public var context: [String: Mischwert]

    public init(at: String, severity: String, code: String, message: String, context: [String: Mischwert] = [:]) {
        self.at = at
        self.severity = severity
        self.code = code
        self.message = message
        self.context = context
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.severity = try c.decode(String.self, forKey: .severity)
        self.code = try c.decode(String.self, forKey: .code)
        self.message = try c.decode(String.self, forKey: .message)
        self.context = try c.decodeIfPresent([String: Mischwert].self, forKey: .context) ?? [:]
    }
}

public struct SystemStatusOut: Codable, Sendable, Hashable {
    public var mode: String
    public var serverTime: String
    public var simSpeed: Double
    public var bridgeOnline: Bool
    public var sseClients: Int
    public var version: String
    public var connectionLabelDe: String
    public var sources: [SourceStatusOut]
    public var watch: [WatchFindingOut]
    public var outdoorShownC: Double?
    public var outdoorSourceDe: String?
    public var hpActuation: Bool?
    public var hpActuationDe: String?

    public enum CodingKeys: String, CodingKey {
        case mode
        case serverTime = "server_time"
        case simSpeed = "sim_speed"
        case bridgeOnline = "bridge_online"
        case sseClients = "sse_clients"
        case version
        case connectionLabelDe = "connection_label_de"
        case sources
        case watch
        case outdoorShownC = "outdoor_shown_c"
        case outdoorSourceDe = "outdoor_source_de"
        case hpActuation = "hp_actuation"
        case hpActuationDe = "hp_actuation_de"
    }

    public init(mode: String, serverTime: String, simSpeed: Double, bridgeOnline: Bool, sseClients: Int, version: String, connectionLabelDe: String, sources: [SourceStatusOut] = [], watch: [WatchFindingOut] = [], outdoorShownC: Double? = nil, outdoorSourceDe: String? = nil, hpActuation: Bool? = nil, hpActuationDe: String? = nil) {
        self.mode = mode
        self.serverTime = serverTime
        self.simSpeed = simSpeed
        self.bridgeOnline = bridgeOnline
        self.sseClients = sseClients
        self.version = version
        self.connectionLabelDe = connectionLabelDe
        self.sources = sources
        self.watch = watch
        self.outdoorShownC = outdoorShownC
        self.outdoorSourceDe = outdoorSourceDe
        self.hpActuation = hpActuation
        self.hpActuationDe = hpActuationDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try c.decode(String.self, forKey: .mode)
        self.serverTime = try c.decode(String.self, forKey: .serverTime)
        self.simSpeed = try c.decode(Double.self, forKey: .simSpeed)
        self.bridgeOnline = try c.decode(Bool.self, forKey: .bridgeOnline)
        self.sseClients = try c.decode(Int.self, forKey: .sseClients)
        self.version = try c.decode(String.self, forKey: .version)
        self.connectionLabelDe = try c.decode(String.self, forKey: .connectionLabelDe)
        self.sources = try c.decodeIfPresent([SourceStatusOut].self, forKey: .sources) ?? []
        self.watch = try c.decodeIfPresent([WatchFindingOut].self, forKey: .watch) ?? []
        self.outdoorShownC = try c.decodeIfPresent(Double.self, forKey: .outdoorShownC)
        self.outdoorSourceDe = try c.decodeIfPresent(String.self, forKey: .outdoorSourceDe)
        self.hpActuation = try c.decodeIfPresent(Bool.self, forKey: .hpActuation)
        self.hpActuationDe = try c.decodeIfPresent(String.self, forKey: .hpActuationDe)
    }
}

/// Geldseite: Einspeisevergütung, Ersatzpreis und die umsatzsteuerliche Einordnung der Anlage.
///
/// Netto und brutto sauber zu trennen ist hier keine Förmlichkeit: die Tibber-Preise der Zeitreihe sind
/// Bruttopreise (Energie, Netz, Steuern, Abgaben - so zeigt Tibber sie), die Einspeisevergütung nach EEG
/// ist ein Nettosatz, und die steuerliche Bemessungsgrundlage des Eigenverbrauchs ist ebenfalls netto.
public struct TariffConfig: Codable, Sendable, Hashable {
    public var feedInCtKwh: Double?
    public var fallbackImportCtKwh: Double?
    public var vatRate: Double?
    public var priceIncludesVat: Bool?
    public var smallBusiness: Bool?

    public enum CodingKeys: String, CodingKey {
        case feedInCtKwh = "feed_in_ct_kwh"
        case fallbackImportCtKwh = "fallback_import_ct_kwh"
        case vatRate = "vat_rate"
        case priceIncludesVat = "price_includes_vat"
        case smallBusiness = "small_business"
    }

    public init(feedInCtKwh: Double? = nil, fallbackImportCtKwh: Double? = nil, vatRate: Double? = nil, priceIncludesVat: Bool? = nil, smallBusiness: Bool? = nil) {
        self.feedInCtKwh = feedInCtKwh
        self.fallbackImportCtKwh = fallbackImportCtKwh
        self.vatRate = vatRate
        self.priceIncludesVat = priceIncludesVat
        self.smallBusiness = smallBusiness
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.feedInCtKwh = try c.decodeIfPresent(Double.self, forKey: .feedInCtKwh)
        self.fallbackImportCtKwh = try c.decodeIfPresent(Double.self, forKey: .fallbackImportCtKwh)
        self.vatRate = try c.decodeIfPresent(Double.self, forKey: .vatRate)
        self.priceIncludesVat = try c.decodeIfPresent(Bool.self, forKey: .priceIncludesVat)
        self.smallBusiness = try c.decodeIfPresent(Bool.self, forKey: .smallBusiness)
    }
}

public struct TibberInvoice: Codable, Sendable, Hashable {
    public var number: String
    public var issuedOn: String
    public var periodStart: String
    public var periodEnd: String
    public var periodLabel: String
    public var kwh: Double
    public var meterStart: Double?
    public var meterEnd: Double?
    public var meterEstimated: Bool?
    public var positions: [InvoicePosition]
    public var fees: [InvoiceFee]
    public var energyNetEur: Double
    public var energyGrossEur: Double
    public var feesNetEur: Double
    public var feesGrossEur: Double
    public var totalNetEur: Double
    public var totalGrossEur: Double
    public var vatEur: Double
    public var avgCtKwh: Double
    public var avgCtKwhGross: Double

    public enum CodingKeys: String, CodingKey {
        case number
        case issuedOn = "issued_on"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case periodLabel = "period_label"
        case kwh
        case meterStart = "meter_start"
        case meterEnd = "meter_end"
        case meterEstimated = "meter_estimated"
        case positions
        case fees
        case energyNetEur = "energy_net_eur"
        case energyGrossEur = "energy_gross_eur"
        case feesNetEur = "fees_net_eur"
        case feesGrossEur = "fees_gross_eur"
        case totalNetEur = "total_net_eur"
        case totalGrossEur = "total_gross_eur"
        case vatEur = "vat_eur"
        case avgCtKwh = "avg_ct_kwh"
        case avgCtKwhGross = "avg_ct_kwh_gross"
    }

    public init(number: String, issuedOn: String, periodStart: String, periodEnd: String, periodLabel: String, kwh: Double, meterStart: Double? = nil, meterEnd: Double? = nil, meterEstimated: Bool? = nil, positions: [InvoicePosition] = [], fees: [InvoiceFee] = [], energyNetEur: Double, energyGrossEur: Double, feesNetEur: Double, feesGrossEur: Double, totalNetEur: Double, totalGrossEur: Double, vatEur: Double, avgCtKwh: Double, avgCtKwhGross: Double) {
        self.number = number
        self.issuedOn = issuedOn
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.periodLabel = periodLabel
        self.kwh = kwh
        self.meterStart = meterStart
        self.meterEnd = meterEnd
        self.meterEstimated = meterEstimated
        self.positions = positions
        self.fees = fees
        self.energyNetEur = energyNetEur
        self.energyGrossEur = energyGrossEur
        self.feesNetEur = feesNetEur
        self.feesGrossEur = feesGrossEur
        self.totalNetEur = totalNetEur
        self.totalGrossEur = totalGrossEur
        self.vatEur = vatEur
        self.avgCtKwh = avgCtKwh
        self.avgCtKwhGross = avgCtKwhGross
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.number = try c.decode(String.self, forKey: .number)
        self.issuedOn = try c.decode(String.self, forKey: .issuedOn)
        self.periodStart = try c.decode(String.self, forKey: .periodStart)
        self.periodEnd = try c.decode(String.self, forKey: .periodEnd)
        self.periodLabel = try c.decode(String.self, forKey: .periodLabel)
        self.kwh = try c.decode(Double.self, forKey: .kwh)
        self.meterStart = try c.decodeIfPresent(Double.self, forKey: .meterStart)
        self.meterEnd = try c.decodeIfPresent(Double.self, forKey: .meterEnd)
        self.meterEstimated = try c.decodeIfPresent(Bool.self, forKey: .meterEstimated)
        self.positions = try c.decodeIfPresent([InvoicePosition].self, forKey: .positions) ?? []
        self.fees = try c.decodeIfPresent([InvoiceFee].self, forKey: .fees) ?? []
        self.energyNetEur = try c.decode(Double.self, forKey: .energyNetEur)
        self.energyGrossEur = try c.decode(Double.self, forKey: .energyGrossEur)
        self.feesNetEur = try c.decode(Double.self, forKey: .feesNetEur)
        self.feesGrossEur = try c.decode(Double.self, forKey: .feesGrossEur)
        self.totalNetEur = try c.decode(Double.self, forKey: .totalNetEur)
        self.totalGrossEur = try c.decode(Double.self, forKey: .totalGrossEur)
        self.vatEur = try c.decode(Double.self, forKey: .vatEur)
        self.avgCtKwh = try c.decode(Double.self, forKey: .avgCtKwh)
        self.avgCtKwhGross = try c.decode(Double.self, forKey: .avgCtKwhGross)
    }
}

/// Das Ergebnis der festen Tibber-Pruefung, so knapp, wie Alfred es im Panel sagt. Die volle
/// Auswertung steht auf der Rechnungsseite, auf die `AlfredRechnungOut.link` zeigt.
public struct TibberZusammenfassung: Codable, Sendable, Hashable {
    public var zeitraum: String
    public var von: String
    public var bis: String
    public var kwh: Double
    public var bruttoEur: Double
    public var ctKwhBrutto: Double
    public var gemessenKwh: Double?
    public var abdeckung: Double?
    public var urteil: String
    public var befunde: [Befund]
    public var schonBekannt: Bool

    public enum CodingKeys: String, CodingKey {
        case zeitraum
        case von
        case bis
        case kwh
        case bruttoEur = "brutto_eur"
        case ctKwhBrutto = "ct_kwh_brutto"
        case gemessenKwh = "gemessen_kwh"
        case abdeckung
        case urteil
        case befunde
        case schonBekannt = "schon_bekannt"
    }

    public init(zeitraum: String, von: String, bis: String, kwh: Double, bruttoEur: Double, ctKwhBrutto: Double, gemessenKwh: Double? = nil, abdeckung: Double? = nil, urteil: String, befunde: [Befund] = [], schonBekannt: Bool) {
        self.zeitraum = zeitraum
        self.von = von
        self.bis = bis
        self.kwh = kwh
        self.bruttoEur = bruttoEur
        self.ctKwhBrutto = ctKwhBrutto
        self.gemessenKwh = gemessenKwh
        self.abdeckung = abdeckung
        self.urteil = urteil
        self.befunde = befunde
        self.schonBekannt = schonBekannt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.zeitraum = try c.decode(String.self, forKey: .zeitraum)
        self.von = try c.decode(String.self, forKey: .von)
        self.bis = try c.decode(String.self, forKey: .bis)
        self.kwh = try c.decode(Double.self, forKey: .kwh)
        self.bruttoEur = try c.decode(Double.self, forKey: .bruttoEur)
        self.ctKwhBrutto = try c.decode(Double.self, forKey: .ctKwhBrutto)
        self.gemessenKwh = try c.decodeIfPresent(Double.self, forKey: .gemessenKwh)
        self.abdeckung = try c.decodeIfPresent(Double.self, forKey: .abdeckung)
        self.urteil = try c.decode(String.self, forKey: .urteil)
        self.befunde = try c.decodeIfPresent([Befund].self, forKey: .befunde) ?? []
        self.schonBekannt = try c.decode(Bool.self, forKey: .schonBekannt)
    }
}

/// Ein Eintrag im Änderungsprotokoll. Was sich geändert hat, und warum.
public struct Uebernahme: Codable, Sendable, Hashable {
    public var at: String
    public var alt: Double
    public var neu: Double
    public var sigma: Double
    public var n: Int
    public var rmseAlt: Double?
    public var rmseNeu: Double?
    public var grund: String

    public enum CodingKeys: String, CodingKey {
        case at
        case alt
        case neu
        case sigma
        case n
        case rmseAlt = "rmse_alt"
        case rmseNeu = "rmse_neu"
        case grund
    }

    public init(at: String, alt: Double, neu: Double, sigma: Double, n: Int, rmseAlt: Double? = nil, rmseNeu: Double? = nil, grund: String) {
        self.at = at
        self.alt = alt
        self.neu = neu
        self.sigma = sigma
        self.n = n
        self.rmseAlt = rmseAlt
        self.rmseNeu = rmseNeu
        self.grund = grund
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.at = try c.decode(String.self, forKey: .at)
        self.alt = try c.decode(Double.self, forKey: .alt)
        self.neu = try c.decode(Double.self, forKey: .neu)
        self.sigma = try c.decode(Double.self, forKey: .sigma)
        self.n = try c.decode(Int.self, forKey: .n)
        self.rmseAlt = try c.decodeIfPresent(Double.self, forKey: .rmseAlt)
        self.rmseNeu = try c.decodeIfPresent(Double.self, forKey: .rmseNeu)
        self.grund = try c.decode(String.self, forKey: .grund)
    }
}

/// Das kleine Bild einer Kachel: eine Form, die sich auf einen Blick lesen lässt.
///
/// Vier Arten, damit Dashboard und App dasselbe zeichnen und keine eine fünfte erfindet:
///
/// - `balken`: der Verlauf des heutigen Tages in Stunden, `werte` in kWh je Stunde. Eine Stunde,
///   die noch nicht war, fehlt am Ende; die Kachel zeichnet immer 24 Plätze.
/// - `fuellung`: ein Füllstand, `anteil` von 0 bis 1.
/// - `abweichung`: eine Abweichung nach unten oder oben, `anteil` von -1 bis 1.
/// - `streifen`: was im Horizont geplant ist, `werte` je Abschnitt 1 für „angefordert", sonst 0.
///
/// Das Bild ist Beigabe und trägt keine Zahl, die nicht auch als Leitzahl dasteht.
public struct UebersichtBildOut: Codable, Sendable, Hashable {
    public var art: UebersichtBildOutArtWahl
    public var werte: [Double]
    public var anteil: Double?

    public init(art: UebersichtBildOutArtWahl, werte: [Double] = [], anteil: Double? = nil) {
        self.art = art
        self.werte = werte
        self.anteil = anteil
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.art = try c.decode(UebersichtBildOutArtWahl.self, forKey: .art)
        self.werte = try c.decodeIfPresent([Double].self, forKey: .werte) ?? []
        self.anteil = try c.decodeIfPresent(Double.self, forKey: .anteil)
    }
}

/// Eine Karte der Bereichsübersicht: die wichtigste Zahl einer Seite und ihr Zustand.
///
/// Der Dienst rechnet und formuliert, damit Dashboard und App nachweislich dasselbe zeigen. Die
/// Karte selbst (Name der Seite, der feste Satz dazu) steht im Seitenbaum; hier steht nur, was
/// sich mit der Zeit ändert.
public struct UebersichtKarteOut: Codable, Sendable, Hashable {
    public var weg: String
    public var leitzahlDe: String?
    public var dazuDe: String?
    public var ampel: UebersichtKarteOutAmpelWahl?
    public var grundDe: String?
    public var bild: UebersichtBildOut?

    public enum CodingKeys: String, CodingKey {
        case weg
        case leitzahlDe = "leitzahl_de"
        case dazuDe = "dazu_de"
        case ampel
        case grundDe = "grund_de"
        case bild
    }

    public init(weg: String, leitzahlDe: String? = nil, dazuDe: String? = nil, ampel: UebersichtKarteOutAmpelWahl? = nil, grundDe: String? = nil, bild: UebersichtBildOut? = nil) {
        self.weg = weg
        self.leitzahlDe = leitzahlDe
        self.dazuDe = dazuDe
        self.ampel = ampel
        self.grundDe = grundDe
        self.bild = bild
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.weg = try c.decode(String.self, forKey: .weg)
        self.leitzahlDe = try c.decodeIfPresent(String.self, forKey: .leitzahlDe)
        self.dazuDe = try c.decodeIfPresent(String.self, forKey: .dazuDe)
        self.ampel = try c.decodeIfPresent(UebersichtKarteOutAmpelWahl.self, forKey: .ampel)
        self.grundDe = try c.decodeIfPresent(String.self, forKey: .grundDe)
        self.bild = try c.decodeIfPresent(UebersichtBildOut.self, forKey: .bild)
    }
}

/// Die Karten eines Bereichs. Eine Seite ohne Karte hat nichts, was sich mit der Zeit ändert.
public struct UebersichtOut: Codable, Sendable, Hashable {
    public var bereich: String
    public var karten: [UebersichtKarteOut]

    public init(bereich: String, karten: [UebersichtKarteOut] = []) {
        self.bereich = bereich
        self.karten = karten
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bereich = try c.decode(String.self, forKey: .bereich)
        self.karten = try c.decodeIfPresent([UebersichtKarteOut].self, forKey: .karten) ?? []
    }
}

public struct UpdateAnfrageIn: Codable, Sendable, Hashable {
    public var aktion: UpdateAnfrageInAktionWahl

    public init(aktion: UpdateAnfrageInAktionWahl) {
        self.aktion = aktion
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aktion = try c.decode(UpdateAnfrageInAktionWahl.self, forKey: .aktion)
    }
}

public struct UpdateErgebnisOut: Codable, Sendable, Hashable {
    public var am: String?
    public var ergebnis: String?
    public var von: String?
    public var nach: String?

    public init(am: String? = nil, ergebnis: String? = nil, von: String? = nil, nach: String? = nil) {
        self.am = am
        self.ergebnis = ergebnis
        self.von = von
        self.nach = nach
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.am = try c.decodeIfPresent(String.self, forKey: .am)
        self.ergebnis = try c.decodeIfPresent(String.self, forKey: .ergebnis)
        self.von = try c.decodeIfPresent(String.self, forKey: .von)
        self.nach = try c.decodeIfPresent(String.self, forKey: .nach)
    }
}

public struct UpdateNeuerungOut: Codable, Sendable, Hashable {
    public var sha: String
    public var titel: String

    public init(sha: String, titel: String) {
        self.sha = sha
        self.titel = titel
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sha = try c.decode(String.self, forKey: .sha)
        self.titel = try c.decode(String.self, forKey: .titel)
    }
}

/// Was der Update-Dienst des Geräts zuletzt festgestellt hat. `unterstuetzt` ist falsch ohne
/// Hausgerät (Railway, Entwicklung); dann bietet die Oberfläche nichts an.
public struct UpdateStatusOut: Codable, Sendable, Hashable {
    public var unterstuetzt: Bool?
    public var kanal: String?
    public var aktuell: String?
    public var verfuegbar: String?
    public var updateVerfuegbar: Bool?
    public var neuerungen: [UpdateNeuerungOut]
    public var geprueftAm: String?
    public var zustand: String?
    public var schritt: String?
    public var meldung: String?
    public var zuletzt: UpdateErgebnisOut?
    public var anfrageOffen: Bool?

    public enum CodingKeys: String, CodingKey {
        case unterstuetzt
        case kanal
        case aktuell
        case verfuegbar
        case updateVerfuegbar = "update_verfuegbar"
        case neuerungen
        case geprueftAm = "geprueft_am"
        case zustand
        case schritt
        case meldung
        case zuletzt
        case anfrageOffen = "anfrage_offen"
    }

    public init(unterstuetzt: Bool? = nil, kanal: String? = nil, aktuell: String? = nil, verfuegbar: String? = nil, updateVerfuegbar: Bool? = nil, neuerungen: [UpdateNeuerungOut] = [], geprueftAm: String? = nil, zustand: String? = nil, schritt: String? = nil, meldung: String? = nil, zuletzt: UpdateErgebnisOut? = nil, anfrageOffen: Bool? = nil) {
        self.unterstuetzt = unterstuetzt
        self.kanal = kanal
        self.aktuell = aktuell
        self.verfuegbar = verfuegbar
        self.updateVerfuegbar = updateVerfuegbar
        self.neuerungen = neuerungen
        self.geprueftAm = geprueftAm
        self.zustand = zustand
        self.schritt = schritt
        self.meldung = meldung
        self.zuletzt = zuletzt
        self.anfrageOffen = anfrageOffen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.unterstuetzt = try c.decodeIfPresent(Bool.self, forKey: .unterstuetzt)
        self.kanal = try c.decodeIfPresent(String.self, forKey: .kanal)
        self.aktuell = try c.decodeIfPresent(String.self, forKey: .aktuell)
        self.verfuegbar = try c.decodeIfPresent(String.self, forKey: .verfuegbar)
        self.updateVerfuegbar = try c.decodeIfPresent(Bool.self, forKey: .updateVerfuegbar)
        self.neuerungen = try c.decodeIfPresent([UpdateNeuerungOut].self, forKey: .neuerungen) ?? []
        self.geprueftAm = try c.decodeIfPresent(String.self, forKey: .geprueftAm)
        self.zustand = try c.decodeIfPresent(String.self, forKey: .zustand)
        self.schritt = try c.decodeIfPresent(String.self, forKey: .schritt)
        self.meldung = try c.decodeIfPresent(String.self, forKey: .meldung)
        self.zuletzt = try c.decodeIfPresent(UpdateErgebnisOut.self, forKey: .zuletzt)
        self.anfrageOffen = try c.decodeIfPresent(Bool.self, forKey: .anfrageOffen)
    }
}

public struct ValidationError: Codable, Sendable, Hashable {
    public var loc: [Mischwert]
    public var msg: String
    public var type: String
    public var input: Mischwert?
    public var ctx: [String: Mischwert]

    public init(loc: [Mischwert] = [], msg: String, type: String, input: Mischwert? = nil, ctx: [String: Mischwert] = [:]) {
        self.loc = loc
        self.msg = msg
        self.type = type
        self.input = input
        self.ctx = ctx
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.loc = try c.decodeIfPresent([Mischwert].self, forKey: .loc) ?? []
        self.msg = try c.decode(String.self, forKey: .msg)
        self.type = try c.decode(String.self, forKey: .type)
        self.input = try c.decodeIfPresent(Mischwert.self, forKey: .input)
        self.ctx = try c.decodeIfPresent([String: Mischwert].self, forKey: .ctx) ?? [:]
    }
}

/// Wärme, die in Räume mit offenem Fenster ging - geschätzt, nicht gemessen.
///
/// Die Entnahme der Wärmebilanz ist eine Zahl für das ganze Haus. Verteilt wird sie hier nach
/// offenen Heizkreisen je Raum; was auf Räume mit offenem Fenster entfällt, steht hier. Das ist
/// **nicht** der Lüftungsverlust: Ein Teil dieser Wärme ist im Raum geblieben. Und es ist eher zu
/// viel als zu wenig, weil Warmwasser in derselben Entnahme steckt und sich nicht trennen lässt.
public struct VentilationOut: Codable, Sendable, Hashable {
    public var kwh: Double
    public var share: Double?
    public var openMinutes: Int
    public var minutesKnown: Int
    public var rooms: [VentilationRoomOut]
    public var noteDe: String

    public enum CodingKeys: String, CodingKey {
        case kwh
        case share
        case openMinutes = "open_minutes"
        case minutesKnown = "minutes_known"
        case rooms
        case noteDe = "note_de"
    }

    public init(kwh: Double, share: Double? = nil, openMinutes: Int, minutesKnown: Int, rooms: [VentilationRoomOut] = [], noteDe: String) {
        self.kwh = kwh
        self.share = share
        self.openMinutes = openMinutes
        self.minutesKnown = minutesKnown
        self.rooms = rooms
        self.noteDe = noteDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kwh = try c.decode(Double.self, forKey: .kwh)
        self.share = try c.decodeIfPresent(Double.self, forKey: .share)
        self.openMinutes = try c.decode(Int.self, forKey: .openMinutes)
        self.minutesKnown = try c.decode(Int.self, forKey: .minutesKnown)
        self.rooms = try c.decodeIfPresent([VentilationRoomOut].self, forKey: .rooms) ?? []
        self.noteDe = try c.decode(String.self, forKey: .noteDe)
    }
}

/// Ein Raum, in dem während der Heizzeit ein Fenster offen stand.
public struct VentilationRoomOut: Codable, Sendable, Hashable {
    public var roomId: Int
    public var name: String
    public var openMinutes: Int
    public var heatingMinutes: Int
    public var kwh: Double

    public enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case name
        case openMinutes = "open_minutes"
        case heatingMinutes = "heating_minutes"
        case kwh
    }

    public init(roomId: Int, name: String, openMinutes: Int, heatingMinutes: Int, kwh: Double) {
        self.roomId = roomId
        self.name = name
        self.openMinutes = openMinutes
        self.heatingMinutes = heatingMinutes
        self.kwh = kwh
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.roomId = try c.decode(Int.self, forKey: .roomId)
        self.name = try c.decode(String.self, forKey: .name)
        self.openMinutes = try c.decode(Int.self, forKey: .openMinutes)
        self.heatingMinutes = try c.decode(Int.self, forKey: .heatingMinutes)
        self.kwh = try c.decode(Double.self, forKey: .kwh)
    }
}

/// Dieselbe Quote ohne Schließvorgang: wie oft läuft die Maschine von selbst an?
public struct Vergleich: Codable, Sendable, Hashable {
    public var n: Int
    public var gefolgt: Int
    public var quoteGesamt: Double?
    public var quote: Double?
    public var ereignisseGedeckt: Int
    public var nGleicheStunde: Int?
    public var quoteLo: Double?
    public var quoteHi: Double?
    public var angelaufenBis: [Double]

    public enum CodingKeys: String, CodingKey {
        case n
        case gefolgt
        case quoteGesamt = "quote_gesamt"
        case quote
        case ereignisseGedeckt = "ereignisse_gedeckt"
        case nGleicheStunde = "n_gleiche_stunde"
        case quoteLo = "quote_lo"
        case quoteHi = "quote_hi"
        case angelaufenBis = "angelaufen_bis"
    }

    public init(n: Int, gefolgt: Int, quoteGesamt: Double? = nil, quote: Double? = nil, ereignisseGedeckt: Int, nGleicheStunde: Int? = nil, quoteLo: Double? = nil, quoteHi: Double? = nil, angelaufenBis: [Double] = []) {
        self.n = n
        self.gefolgt = gefolgt
        self.quoteGesamt = quoteGesamt
        self.quote = quote
        self.ereignisseGedeckt = ereignisseGedeckt
        self.nGleicheStunde = nGleicheStunde
        self.quoteLo = quoteLo
        self.quoteHi = quoteHi
        self.angelaufenBis = angelaufenBis
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.n = try c.decode(Int.self, forKey: .n)
        self.gefolgt = try c.decode(Int.self, forKey: .gefolgt)
        self.quoteGesamt = try c.decodeIfPresent(Double.self, forKey: .quoteGesamt)
        self.quote = try c.decodeIfPresent(Double.self, forKey: .quote)
        self.ereignisseGedeckt = try c.decode(Int.self, forKey: .ereignisseGedeckt)
        self.nGleicheStunde = try c.decodeIfPresent(Int.self, forKey: .nGleicheStunde)
        self.quoteLo = try c.decodeIfPresent(Double.self, forKey: .quoteLo)
        self.quoteHi = try c.decodeIfPresent(Double.self, forKey: .quoteHi)
        self.angelaufenBis = try c.decodeIfPresent([Double].self, forKey: .angelaufenBis) ?? []
    }
}

/// Ob eine Einladung per E-Mail hinausgehen kann - und was sonst fehlt.
public struct VersandOut: Codable, Sendable, Hashable {
    public var aktiv: Bool?
    public var weg: VersandOutWegWahl?
    public var fehlt: [String]

    public init(aktiv: Bool? = nil, weg: VersandOutWegWahl? = nil, fehlt: [String] = []) {
        self.aktiv = aktiv
        self.weg = weg
        self.fehlt = fehlt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv)
        self.weg = try c.decodeIfPresent(VersandOutWegWahl.self, forKey: .weg)
        self.fehlt = try c.decodeIfPresent([String].self, forKey: .fehlt) ?? []
    }
}

/// Eine Sprosse der Vorlaufleiter mit ihrer Wertung.
public struct VorlaufOut: Codable, Sendable, Hashable {
    public var key: String
    public var labelDe: String
    public var wertung: Wertung

    public enum CodingKeys: String, CodingKey {
        case key
        case labelDe = "label_de"
        case wertung
    }

    public init(key: String, labelDe: String, wertung: Wertung) {
        self.key = key
        self.labelDe = labelDe
        self.wertung = wertung
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.labelDe = try c.decode(String.self, forKey: .labelDe)
        self.wertung = try c.decode(Wertung.self, forKey: .wertung)
    }
}

/// Die Wärmepumpe im Augenblick, für ihre Technikseite.
///
/// Jede Größe ist ein Messwert mit Zeitpunkt und Güte: fehlt einer, steht auf der Seite ein
/// Fragezeichen an seiner Stelle und keine Null. Die drei gerechneten Größen am Ende
/// entstehen aus diesen Messwerten; wie, steht in `hinweise_de` und in
/// `application/waermepumpe.py`.
public struct WaermepumpeOut: Codable, Sendable, Hashable {
    public var now: String
    public var laeuft: Bool
    public var zustandCode: Int?
    public var zustandDe: String
    public var pumpeLaeuft: Bool?
    public var aussenC: Messwert
    public var verdampferC: Messwert
    public var sauggasC: Messwert
    public var heissgasC: Messwert
    public var fluessigC: Messwert
    public var verdichterHz: Messwert
    public var leistungBusKw: Messwert
    public var leistungZaehlerKw: Messwert
    public var vorlaufC: Messwert
    public var ruecklaufC: Messwert
    public var durchflussLMin: Messwert
    public var vorlaufSollC: Messwert
    public var speicherfuehlerC: Messwert
    public var pufferC: [Messwert]
    public var spreizungK: Double?
    public var waermeleistungKw: Double?
    public var arbeitszahl: Double?
    public var heizanforderung: Bool?
    public var raumSollC: Messwert?
    public var zusatzKw: Double?
    public var ventilCode: Int?
    public var heizstabCode: Int?
    public var verdichterA: Messwert?
    public var luefterDrehzahl: Messwert?
    public var kreisCode: Int?
    public var kreisDe: String?
    public var einspeisung: WaermepumpeOutEinspeisungWahl?
    public var busStummDe: String?
    public var hinweiseDe: [String]

    public enum CodingKeys: String, CodingKey {
        case now
        case laeuft
        case zustandCode = "zustand_code"
        case zustandDe = "zustand_de"
        case pumpeLaeuft = "pumpe_laeuft"
        case aussenC = "aussen_c"
        case verdampferC = "verdampfer_c"
        case sauggasC = "sauggas_c"
        case heissgasC = "heissgas_c"
        case fluessigC = "fluessig_c"
        case verdichterHz = "verdichter_hz"
        case leistungBusKw = "leistung_bus_kw"
        case leistungZaehlerKw = "leistung_zaehler_kw"
        case vorlaufC = "vorlauf_c"
        case ruecklaufC = "ruecklauf_c"
        case durchflussLMin = "durchfluss_l_min"
        case vorlaufSollC = "vorlauf_soll_c"
        case speicherfuehlerC = "speicherfuehler_c"
        case pufferC = "puffer_c"
        case spreizungK = "spreizung_k"
        case waermeleistungKw = "waermeleistung_kw"
        case arbeitszahl
        case heizanforderung
        case raumSollC = "raum_soll_c"
        case zusatzKw = "zusatz_kw"
        case ventilCode = "ventil_code"
        case heizstabCode = "heizstab_code"
        case verdichterA = "verdichter_a"
        case luefterDrehzahl = "luefter_drehzahl"
        case kreisCode = "kreis_code"
        case kreisDe = "kreis_de"
        case einspeisung
        case busStummDe = "bus_stumm_de"
        case hinweiseDe = "hinweise_de"
    }

    public init(now: String, laeuft: Bool, zustandCode: Int? = nil, zustandDe: String, pumpeLaeuft: Bool? = nil, aussenC: Messwert, verdampferC: Messwert, sauggasC: Messwert, heissgasC: Messwert, fluessigC: Messwert, verdichterHz: Messwert, leistungBusKw: Messwert, leistungZaehlerKw: Messwert, vorlaufC: Messwert, ruecklaufC: Messwert, durchflussLMin: Messwert, vorlaufSollC: Messwert, speicherfuehlerC: Messwert, pufferC: [Messwert] = [], spreizungK: Double? = nil, waermeleistungKw: Double? = nil, arbeitszahl: Double? = nil, heizanforderung: Bool? = nil, raumSollC: Messwert? = nil, zusatzKw: Double? = nil, ventilCode: Int? = nil, heizstabCode: Int? = nil, verdichterA: Messwert? = nil, luefterDrehzahl: Messwert? = nil, kreisCode: Int? = nil, kreisDe: String? = nil, einspeisung: WaermepumpeOutEinspeisungWahl? = nil, busStummDe: String? = nil, hinweiseDe: [String] = []) {
        self.now = now
        self.laeuft = laeuft
        self.zustandCode = zustandCode
        self.zustandDe = zustandDe
        self.pumpeLaeuft = pumpeLaeuft
        self.aussenC = aussenC
        self.verdampferC = verdampferC
        self.sauggasC = sauggasC
        self.heissgasC = heissgasC
        self.fluessigC = fluessigC
        self.verdichterHz = verdichterHz
        self.leistungBusKw = leistungBusKw
        self.leistungZaehlerKw = leistungZaehlerKw
        self.vorlaufC = vorlaufC
        self.ruecklaufC = ruecklaufC
        self.durchflussLMin = durchflussLMin
        self.vorlaufSollC = vorlaufSollC
        self.speicherfuehlerC = speicherfuehlerC
        self.pufferC = pufferC
        self.spreizungK = spreizungK
        self.waermeleistungKw = waermeleistungKw
        self.arbeitszahl = arbeitszahl
        self.heizanforderung = heizanforderung
        self.raumSollC = raumSollC
        self.zusatzKw = zusatzKw
        self.ventilCode = ventilCode
        self.heizstabCode = heizstabCode
        self.verdichterA = verdichterA
        self.luefterDrehzahl = luefterDrehzahl
        self.kreisCode = kreisCode
        self.kreisDe = kreisDe
        self.einspeisung = einspeisung
        self.busStummDe = busStummDe
        self.hinweiseDe = hinweiseDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.now = try c.decode(String.self, forKey: .now)
        self.laeuft = try c.decode(Bool.self, forKey: .laeuft)
        self.zustandCode = try c.decodeIfPresent(Int.self, forKey: .zustandCode)
        self.zustandDe = try c.decode(String.self, forKey: .zustandDe)
        self.pumpeLaeuft = try c.decodeIfPresent(Bool.self, forKey: .pumpeLaeuft)
        self.aussenC = try c.decode(Messwert.self, forKey: .aussenC)
        self.verdampferC = try c.decode(Messwert.self, forKey: .verdampferC)
        self.sauggasC = try c.decode(Messwert.self, forKey: .sauggasC)
        self.heissgasC = try c.decode(Messwert.self, forKey: .heissgasC)
        self.fluessigC = try c.decode(Messwert.self, forKey: .fluessigC)
        self.verdichterHz = try c.decode(Messwert.self, forKey: .verdichterHz)
        self.leistungBusKw = try c.decode(Messwert.self, forKey: .leistungBusKw)
        self.leistungZaehlerKw = try c.decode(Messwert.self, forKey: .leistungZaehlerKw)
        self.vorlaufC = try c.decode(Messwert.self, forKey: .vorlaufC)
        self.ruecklaufC = try c.decode(Messwert.self, forKey: .ruecklaufC)
        self.durchflussLMin = try c.decode(Messwert.self, forKey: .durchflussLMin)
        self.vorlaufSollC = try c.decode(Messwert.self, forKey: .vorlaufSollC)
        self.speicherfuehlerC = try c.decode(Messwert.self, forKey: .speicherfuehlerC)
        self.pufferC = try c.decodeIfPresent([Messwert].self, forKey: .pufferC) ?? []
        self.spreizungK = try c.decodeIfPresent(Double.self, forKey: .spreizungK)
        self.waermeleistungKw = try c.decodeIfPresent(Double.self, forKey: .waermeleistungKw)
        self.arbeitszahl = try c.decodeIfPresent(Double.self, forKey: .arbeitszahl)
        self.heizanforderung = try c.decodeIfPresent(Bool.self, forKey: .heizanforderung)
        self.raumSollC = try c.decodeIfPresent(Messwert.self, forKey: .raumSollC)
        self.zusatzKw = try c.decodeIfPresent(Double.self, forKey: .zusatzKw)
        self.ventilCode = try c.decodeIfPresent(Int.self, forKey: .ventilCode)
        self.heizstabCode = try c.decodeIfPresent(Int.self, forKey: .heizstabCode)
        self.verdichterA = try c.decodeIfPresent(Messwert.self, forKey: .verdichterA)
        self.luefterDrehzahl = try c.decodeIfPresent(Messwert.self, forKey: .luefterDrehzahl)
        self.kreisCode = try c.decodeIfPresent(Int.self, forKey: .kreisCode)
        self.kreisDe = try c.decodeIfPresent(String.self, forKey: .kreisDe)
        self.einspeisung = try c.decodeIfPresent(WaermepumpeOutEinspeisungWahl.self, forKey: .einspeisung)
        self.busStummDe = try c.decodeIfPresent(String.self, forKey: .busStummDe)
        self.hinweiseDe = try c.decodeIfPresent([String].self, forKey: .hinweiseDe) ?? []
    }
}

/// Ein Stueck Wandlinie: `x` fuer eine Nord-Sued-Wand, `z` fuer eine Ost-West-Wand, `a..b`
/// laengs der Wand. Genau eines von `x` und `z` ist gesetzt.
public struct WallLine: Codable, Sendable, Hashable {
    public var x: Double?
    public var z: Double?
    public var a: Double
    public var b: Double

    public init(x: Double? = nil, z: Double? = nil, a: Double, b: Double) {
        self.x = x
        self.z = z
        self.a = a
        self.b = b
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.x = try c.decodeIfPresent(Double.self, forKey: .x)
        self.z = try c.decodeIfPresent(Double.self, forKey: .z)
        self.a = try c.decode(Double.self, forKey: .a)
        self.b = try c.decode(Double.self, forKey: .b)
    }
}

/// Ein Befund des Wächters: Dieses Signal schweigt, seit wann, und was deshalb fehlt.
///
/// Die Regeln stehen in `hems_core.watch`; hier ist nur die Form für die Oberfläche. Der Text ist
/// ein ganzer Satz, weil er auch als Mitteilung auf einem Telefon landet, wo niemand aus
/// `name` und `silent_min` etwas zusammensetzen kann.
public struct WatchFindingOut: Codable, Sendable, Hashable {
    public var name: String
    public var titleDe: String
    public var severity: WatchFindingOutSeverityWahl
    public var since: String?
    public var silentMin: Double
    public var textDe: String

    public enum CodingKeys: String, CodingKey {
        case name
        case titleDe = "title_de"
        case severity
        case since
        case silentMin = "silent_min"
        case textDe = "text_de"
    }

    public init(name: String, titleDe: String, severity: WatchFindingOutSeverityWahl, since: String? = nil, silentMin: Double, textDe: String) {
        self.name = name
        self.titleDe = titleDe
        self.severity = severity
        self.since = since
        self.silentMin = silentMin
        self.textDe = textDe
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.titleDe = try c.decode(String.self, forKey: .titleDe)
        self.severity = try c.decode(WatchFindingOutSeverityWahl.self, forKey: .severity)
        self.since = try c.decodeIfPresent(String.self, forKey: .since)
        self.silentMin = try c.decode(Double.self, forKey: .silentMin)
        self.textDe = try c.decode(String.self, forKey: .textDe)
    }
}

/// Kennzahlen einer Menge von Proben, in der Einheit der Reihe.
///
/// Einheitenfrei benannt: `mae` ist bei der PV ein Kilowatt und bei der Temperatur ein Kelvin. Eine
/// Energiesumme steht hier bewusst nicht - sie ergibt nur für Leistungen einen Sinn, und wer sie
/// für PV braucht, findet sie in `evaluation.ForecastScore`.
public struct Wertung: Codable, Sendable, Hashable {
    public var n: Int
    public var mae: Double
    public var bias: Double
    public var rmse: Double
    public var p95: Double

    public init(n: Int, mae: Double, bias: Double, rmse: Double, p95: Double) {
        self.n = n
        self.mae = mae
        self.bias = bias
        self.rmse = rmse
        self.p95 = p95
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.n = try c.decode(Int.self, forKey: .n)
        self.mae = try c.decode(Double.self, forKey: .mae)
        self.bias = try c.decode(Double.self, forKey: .bias)
        self.rmse = try c.decode(Double.self, forKey: .rmse)
        self.p95 = try c.decode(Double.self, forKey: .p95)
    }
}

public struct WiederherstellenIn: Codable, Sendable, Hashable {
    public var email: String
    public var code: String

    public init(email: String, code: String) {
        self.email = email
        self.code = code
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.email = try c.decode(String.self, forKey: .email)
        self.code = try c.decode(String.self, forKey: .code)
    }
}

/// Ein Kalenderjahr als Tag × Stunde: 365 Spalten, 24 Zeilen, je Kennzahl eine Fläche.
///
/// Die Stunde ist Ortszeit, nicht UTC - sonst wanderte die Sonne im Bild um eine Stunde, sobald die
/// Zeitumstellung kommt. `null` heißt „keine Messdaten", nicht „null Kilowattstunden"; beides zu
/// unterscheiden ist der halbe Nutzen der Darstellung.
public struct YearMapOut: Codable, Sendable, Hashable {
    public var year: Int
    public var days: [String]
    public var metrics: [String: [[Double?]]]
    public var hoursWithData: Int
    public var dataSince: String?

    public enum CodingKeys: String, CodingKey {
        case year
        case days
        case metrics
        case hoursWithData = "hours_with_data"
        case dataSince = "data_since"
    }

    public init(year: Int, days: [String] = [], metrics: [String: [[Double?]]] = [:], hoursWithData: Int, dataSince: String? = nil) {
        self.year = year
        self.days = days
        self.metrics = metrics
        self.hoursWithData = hoursWithData
        self.dataSince = dataSince
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.year = try c.decode(Int.self, forKey: .year)
        self.days = try c.decodeIfPresent([String].self, forKey: .days) ?? []
        self.metrics = try c.decodeIfPresent([String: [[Double?]]].self, forKey: .metrics) ?? [:]
        self.hoursWithData = try c.decode(Int.self, forKey: .hoursWithData)
        self.dataSince = try c.decodeIfPresent(String.self, forKey: .dataSince)
    }
}

/// Der Beginn einer WebAuthn-Zeremonie.
///
/// `optionen` ist der JSON-Text, den `navigator.credentials` erwartet - unverändert
/// weiterzugeben. `schritt` kommt mit der Antwort des Geräts zurück und bindet sie an ihre
/// Challenge.
public struct ZeremonieOut: Codable, Sendable, Hashable {
    public var schritt: String
    public var optionen: String

    public init(schritt: String, optionen: String) {
        self.schritt = schritt
        self.optionen = optionen
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schritt = try c.decode(String.self, forKey: .schritt)
        self.optionen = try c.decode(String.self, forKey: .optionen)
    }
}

/// Was die Oberfläche über die Anmeldung wissen muss, bevor jemand angemeldet ist.
///
/// Öffentlich und mit Absicht wortkarg: `personen` ist eine Zahl, keine Liste. Dass es noch
/// niemanden gibt, muss die Anmeldeseite sagen können - wer das ist, braucht sie nicht.
public struct ZugangZustandOut: Codable, Sendable, Hashable {
    public var anmeldung: Bool?
    public var personen: Int?
    public var rpId: String?
    public var versand: VersandOut?
    public var passwortMindestlaenge: Int?

    public enum CodingKeys: String, CodingKey {
        case anmeldung
        case personen
        case rpId = "rp_id"
        case versand
        case passwortMindestlaenge = "passwort_mindestlaenge"
    }

    public init(anmeldung: Bool? = nil, personen: Int? = nil, rpId: String? = nil, versand: VersandOut? = nil, passwortMindestlaenge: Int? = nil) {
        self.anmeldung = anmeldung
        self.personen = personen
        self.rpId = rpId
        self.versand = versand
        self.passwortMindestlaenge = passwortMindestlaenge
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.anmeldung = try c.decodeIfPresent(Bool.self, forKey: .anmeldung)
        self.personen = try c.decodeIfPresent(Int.self, forKey: .personen)
        self.rpId = try c.decodeIfPresent(String.self, forKey: .rpId)
        self.versand = try c.decodeIfPresent(VersandOut.self, forKey: .versand)
        self.passwortMindestlaenge = try c.decodeIfPresent(Int.self, forKey: .passwortMindestlaenge)
    }
}

public struct Zuordnungsergebnis: Codable, Sendable, Hashable {
    public var zeilen: [Zuordnungszeile]
    public var verworfen: [String]
    public var offen: [String]
    public var yaml: String
    public var zeilenGesendet: Int

    public enum CodingKeys: String, CodingKey {
        case zeilen
        case verworfen
        case offen
        case yaml
        case zeilenGesendet = "zeilen_gesendet"
    }

    public init(zeilen: [Zuordnungszeile] = [], verworfen: [String] = [], offen: [String] = [], yaml: String, zeilenGesendet: Int) {
        self.zeilen = zeilen
        self.verworfen = verworfen
        self.offen = offen
        self.yaml = yaml
        self.zeilenGesendet = zeilenGesendet
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.zeilen = try c.decodeIfPresent([Zuordnungszeile].self, forKey: .zeilen) ?? []
        self.verworfen = try c.decodeIfPresent([String].self, forKey: .verworfen) ?? []
        self.offen = try c.decodeIfPresent([String].self, forKey: .offen) ?? []
        self.yaml = try c.decode(String.self, forKey: .yaml)
        self.zeilenGesendet = try c.decode(Int.self, forKey: .zeilenGesendet)
    }
}

public struct Zuordnungszeile: Codable, Sendable, Hashable {
    public var schluessel: String
    public var entitaet: String
    public var einheit: String
    public var grund: String
    public var yaml: String

    public init(schluessel: String, entitaet: String, einheit: String, grund: String, yaml: String) {
        self.schluessel = schluessel
        self.entitaet = entitaet
        self.einheit = einheit
        self.grund = grund
        self.yaml = yaml
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schluessel = try c.decode(String.self, forKey: .schluessel)
        self.entitaet = try c.decode(String.self, forKey: .entitaet)
        self.einheit = try c.decode(String.self, forKey: .einheit)
        self.grund = try c.decode(String.self, forKey: .grund)
        self.yaml = try c.decode(String.self, forKey: .yaml)
    }
}
