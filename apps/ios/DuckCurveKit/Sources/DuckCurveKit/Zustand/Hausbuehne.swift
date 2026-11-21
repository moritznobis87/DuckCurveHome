import Foundation

/// Die Bühne des Glasmodells: in welchem Rahmen sie steht.
///
/// **Warum das hier liegt und nicht in der Ansicht.** Das Viertelraster, der Startwert, das
/// Falten auf vier Stellungen und der Name der zugewandten Wand sind Regeln, keine Darstellung.
/// Eine `View` übersetzt nur auf einem Mac; hier gehen sie durch den Compiler und durch
/// Prüfungen. Die Ansicht rechnet davon nichts selbst.
public enum Hausbuehne {

    /// Breite zu Höhe der Bühne: **hochkant**, drei zu vier.
    ///
    /// **Die Vorlage misst in Bildschirmhöhe, nicht in Seitenverhältnis** - und am Telefon kommt
    /// dabei hochkant heraus. `handy.css:393` gibt `.haus-buehne-huelle` 58dvh; die Breite ist
    /// die der einspaltigen Inhaltsspalte (`globals.css:543`), und von ihren 390 Punkten gehen
    /// links und rechts je 16 ab (`handy.css:110`: `.report-main { padding: 10px 16px ... }`,
    /// in der App `Seitenwahl.swift`). Das Gerät, gegen das gemessen wird, ist 390 Punkte breit
    /// (`messungen/geld-pv-abrechnung.md:193`) und 844 Punkte hoch - letzteres ist die
    /// Punkthöhe dieser Geräteklasse und steht in keiner Messung dieses Hauses; die Vorlage
    /// bestätigt nur die Größenordnung (`globals.css:278`: quer „rund 850 Punkte breit“). Also
    /// rund 358 zu 490 Punkte - 0,731, und drei zu vier ist davon knapp zwei Hundertstel weg.
    ///
    /// **An der Wand tut die Vorlage etwas anderes.** Dort füllt die Bühne die Restspalte des
    /// Rasters aus 216 Punkten und dem Rest (`globals.css:447`) bei `min-height: 480px`
    /// (`globals.css:468`) und liegt damit quer. Hochkant steht sie in beiden Breiten auf Wunsch
    /// des Nutzers, nicht nach der Vorlage: an der Wand bleibt deshalb neben der Bühne Luft.
    /// Das ist die einzige Stelle, an der diese Seite bewusst von der Vorlage abweicht.
    public static let seitenverhaeltnis: Double = 3.0 / 4.0
}

/// Welche Wand des Hauses dem Betrachter zugewandt ist.
///
/// **Die Namen stehen nicht in der Vorlage** - dort trägt keine der vier Stellungen einen Namen,
/// die Drehung ist nur eine Zahl in der Adresse (`HouseReport.tsx:143`). Sie kommen aus der
/// Rechnung: ``Hausgeometrie/strahl(drehung:)`` gibt den Sehstrahl zum Betrachter, und seine
/// stärkere waagerechte Komponente zeigt auf die zugewandte Wand. Geprüft wird genau so, gegen
/// `strahl` und nicht gegen eine Tabelle.
///
/// **Die Buchstaben sind die der Vorlage** (`geometrie.ts:9`: `"n" | "s" | "o" | "w"`, und
/// `geometrie.ts:57-62`: Norden liegt bei kleinem z, Süden bei großem, Westen bei kleinem x,
/// Osten bei großem).
public enum Hausansicht: Sendable, CaseIterable {
    case sueden
    case osten
    case norden
    case westen

    /// Der Buchstabe der Vorlage für diese Wand (`geometrie.ts:9`).
    public var seite: String {
        switch self {
        case .sueden: return "s"
        case .osten: return "o"
        case .norden: return "n"
        case .westen: return "w"
        }
    }

    /// Die zugewandte Wand als Wort: „Südseite“.
    public var wand: String {
        switch self {
        case .sueden: return "Südseite"
        case .osten: return "Ostseite"
        case .norden: return "Nordseite"
        case .westen: return "Westseite"
        }
    }

    /// Für die Vorlesestimme: „Blick von Süden“ - sie soll sagen können, welche der vier
    /// Stellungen gerade dasteht, denn seit dem Wegfall der Geste drehen nur noch die Knöpfe,
    /// und ein Knopf allein sagt nicht, wo man gelandet ist.
    public var blick: String {
        switch self {
        case .sueden: return "Blick von Süden"
        case .osten: return "Blick von Osten"
        case .norden: return "Blick von Norden"
        case .westen: return "Blick von Westen"
        }
    }
}

/// Die Drehung des Grundrisses, in Vierteldrehungen gezählt.
///
/// **Die Vorlage zählt in Vierteln, nicht in Winkeln.** `HouseScene.ts:271` liest den Startwert
/// als `(start.drehung * Math.PI) / 2`, und `drehen` rechnet `thetaZiel += richtung * Math.PI / 2`
/// (`HouseScene.ts:300-302`). Eine andere Stellung als die vier gibt es im Browser nicht: die
/// Szene horcht nur auf `pointerdown` und `pointerup` (`HouseScene.ts:265-266`), nie auf
/// `pointermove` - der Zeiger wählt einen Raum, er dreht nicht.
///
/// **Die Vorgabe ist null.** `HouseReport.tsx:143` liest `Number(params.get("dreh") ?? 0) ||
/// undefined`; ohne Adresszusatz bleibt `theta = 0`. Die App stand bei 0,62 Bogenmaß - rund 35,5
/// Grad und damit keine Vierteldrehung: mit 90-Grad-Schritten von dort aus zeigte sie vier
/// Eckansichten und nie eine gerade Seite, während der Browser auf seinem Raster sitzt.
///
/// **Gezählt wird ohne Grenze, benannt wird im Viertelkreis.** `thetaZiel` wächst in der Vorlage
/// über vier Klicks hinaus weiter. Wer die Zählung auf 0 bis 3 zurückfaltet, dreht beim vierten
/// Klick sichtbar zurück, statt weiter in dieselbe Richtung. ``bogenmass`` nimmt deshalb
/// ``viertel`` wie gezählt; nur ``stellung`` und ``ansicht`` falten auf vier.
public struct Hausdrehung: Sendable, Equatable {

    /// Wie viele Vierteldrehungen, mit Vorzeichen und ohne Grenze.
    public let viertel: Int

    /// Die Vorgabe der Vorlage: ungedreht, der Blick von Süden.
    public static let vorgabe = Hausdrehung(viertel: 0)

    public init(viertel: Int = 0) {
        self.viertel = viertel
    }

    /// Der Winkel im Bogenmaß, so wie ``Hausgeometrie/bildschirm(x:y:z:drehung:)`` ihn nimmt.
    public var bogenmass: Double { Double(viertel) * .pi / 2 }

    /// Einen Klick weiter. Wie in der Vorlage zählt nur die Richtung: `-1` nach links, sonst
    /// nach rechts (`HouseScene.ts:300`, dort als Typ `-1 | 1`).
    public func gedreht(_ richtung: Int) -> Hausdrehung {
        Hausdrehung(viertel: viertel + (richtung < 0 ? -1 : 1))
    }

    /// Die Stellung im Viertelkreis, 0 bis 3 - auch bei negativer Zählung.
    ///
    /// Swifts `%` behält das Vorzeichen des Zählers: `-1 % 4` ist `-1`, nicht `3`. Ohne die
    /// Rückgabe in den positiven Bereich wäre der erste Klick nach links keine der vier
    /// Stellungen.
    public var stellung: Int {
        let rest = viertel % 4
        return rest < 0 ? rest + 4 : rest
    }

    /// Welche Wand dem Betrachter zugewandt ist.
    public var ansicht: Hausansicht {
        switch stellung {
        case 1: return .osten
        case 2: return .norden
        case 3: return .westen
        default: return .sueden
        }
    }
}
