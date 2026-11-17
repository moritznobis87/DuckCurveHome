import Foundation

/// Die Maße und die Rechnung der Wärmepumpen-Zeichnung.
///
/// **Warum das im Kern steht.** Die Zeichnung selbst ist SwiftUI und lässt sich nur auf einem
/// Mac übersetzen; ihre Maße und die drei Entscheidungen darin sind reine Rechnung und hier
/// prüfbar. Die Zahlen sind die des Dashboards (`waermepumpe/bild.ts`), Punkt für Punkt
/// übernommen – diese Zeichnung ist an einer echten Anlage gewachsen, und ihre Eigenheiten
/// (wo der Vorlauf einspeist, wo der Fühler der Wärmepumpe sitzt) sind Auskünfte des
/// Hausherrn und keine Gestaltung, die man nachempfinden darf.
public enum Wpbild {
    /// Zwei Lagen, eine Zeichnung: an der Wand nebeneinander, am Telefon untereinander.
    public enum Lage: Sendable { case breit, hoch }

    public typealias Punkt = (x: Double, y: Double)

    /// Die drei Blöcke.
    public static let aussenBlock = (breite: 330.0, hoehe: 250.0)
    public static let innenBlock = (breite: 300.0, hoehe: 250.0)
    public static let speicherBlock = (breite: 250.0, hoehe: 250.0)

    /// Das Glas im Block „Speicher"; links daneben stehen die vier Temperaturen.
    public static let tank = (x: 133.0, y: 40.0, breite: 64.0, hoehe: 190.0)
    /// Ein Schild an einer Leitung.
    public static let schild = (breite: 124.0, hoehe: 38.0)

    /// Höhe des Fühlers der Wärmepumpe im Speicher, als Anteil von oben.
    ///
    /// Die Mitte zwischen Oberkante (0) und dem obersten eigenen Fühler (0,125) – Auskunft des
    /// Hausherrn vom 15.11.2026.
    public static let fuehlerWp = 0.0625

    private static let mitte = tank.x + tank.breite / 2

    public struct Plan: Sendable {
        public let sicht: (breite: Double, hoehe: Double)
        public let aussen: Punkt
        public let innen: Punkt
        public let speicher: Punkt
        /// Leitungen als Punktfolgen in Flussrichtung.
        public let heissgas: [Punkt]
        public let fluessig: [Punkt]
        public let vorlauf: [Punkt]
        /// Der Vorlauf im Heizbetrieb: die Maschine speist dann nicht oben, sondern tiefer in
        /// den Speicher ein (Auskunft des Hausherrn, 14.11.2026). Er endet seitlich auf halber
        /// Höhe.
        public let vorlaufTiefer: [Punkt]
        public let ruecklauf: [Punkt]
        /// Linke obere Ecke der Schilder an den Leitungen.
        public let schilder: (heissgas: Punkt, fluessig: Punkt, vorlauf: Punkt, ruecklauf: Punkt)
    }

    public static func plan(_ lage: Lage) -> Plan {
        switch lage {
        case .breit:
            return Plan(
                sicht: (1120, 450),
                aussen: (10, 100), innen: (410, 100), speicher: (850, 100),
                heissgas: [(260, 100), (260, 50), (450, 50), (450, 100)],
                fluessig: [(450, 350), (450, 400), (260, 400), (260, 350)],
                vorlauf: [(660, 100), (660, 50), (1015, 50), (1015, 100 + tank.y)],
                vorlaufTiefer: [
                    (660, 100), (660, 50), (1100, 50),
                    (1100, 100 + tank.y + tank.hoehe / 2),
                    (850 + tank.x + tank.breite, 100 + tank.y + tank.hoehe / 2),
                ],
                ruecklauf: [
                    (1015, 100 + tank.y + tank.hoehe), (1015, 400), (660, 400), (660, 350),
                ],
                schilder: (
                    heissgas: (293, 31), fluessig: (293, 381),
                    vorlauf: (776, 31), ruecklauf: (776, 381)
                )
            )
        case .hoch:
            return Plan(
                sicht: (380, 1000),
                aussen: (25, 10), innen: (40, 370), speicher: (20, 740),
                heissgas: [(150, 260), (150, 370)],
                fluessig: [(300, 370), (300, 260)],
                // Der Vorlauf verlaesst das Innengeraet links und kommt mittig auf dem Glas an:
                // ein Versatz unter den beiden Schildern.
                vorlauf: [(150, 620), (150, 712), (20 + mitte, 712), (20 + mitte, 740 + tank.y)],
                vorlaufTiefer: [
                    (150, 620), (150, 712), (272, 712),
                    (272, 740 + tank.y + tank.hoehe / 2),
                    (20 + tank.x + tank.breite, 740 + tank.y + tank.hoehe / 2),
                ],
                ruecklauf: [
                    (20 + tank.x + tank.breite, 740 + tank.y + tank.hoehe - 24),
                    (300, 740 + tank.y + tank.hoehe - 24), (300, 620),
                ],
                schilder: (
                    heissgas: (14, 296), fluessig: (164, 296),
                    vorlauf: (14, 660), ruecklauf: (164, 660)
                )
            )
        }
    }

    // MARK: - Was die Zeichnung aus den Daten schließt

    /// Die Leistungsaufnahme, die gilt: der Zähler, wo er einen Wert hat, sonst die Auskunft
    /// der Maschine.
    public static func aufnahme(_ w: WaermepumpeOut) -> (kw: Double?, quelle: String) {
        if let z = w.leistungZaehlerKw.belastbar { return (z, "Zähler") }
        if let b = w.leistungBusKw.belastbar { return (b, "laut Maschine") }
        return (nil, "")
    }

    /// Der Satz über der Zeichnung: was die Maschine gerade tut, in einem Atemzug.
    public static func satz(_ w: WaermepumpeOut) -> String {
        let strom = aufnahme(w).kw
        guard w.laeuft else { return "Die Wärmepumpe \(w.zustandDe)." }
        if let waerme = w.waermeleistungKw, let strom {
            return "Die Wärmepumpe \(w.zustandDe): rund \(Formate.zahl(waerme, stellen: 1)) kW "
                + "Wärme aus \(Formate.zahl(strom, stellen: 1)) kW Strom."
        }
        if let strom {
            return "Die Wärmepumpe \(w.zustandDe) und nimmt \(Formate.zahl(strom, stellen: 1)) kW auf."
        }
        return "Die Wärmepumpe \(w.zustandDe)."
    }

    /// Speist der Vorlauf tiefer in den Speicher ein?
    ///
    /// Sagt die Betriebsart des Reglers: bei Warmwasser oben, im Heizbetrieb tiefer. Ohne
    /// Auskunft bleibt die Leitung oben – eine Vermutung wäre hier eine Behauptung über
    /// Hydraulik.
    public static func speistTiefer(_ w: WaermepumpeOut) -> Bool {
        w.einspeisung == .tiefer
    }

    /// Dreht der Lüfter?
    ///
    /// Nach seiner abgefragten Drehzahl, wenn es sie gibt; sonst mit dem Verdichter. **Das ist
    /// kein Schönheitsgriff:** in einer Pause läuft er draußen oft weiter (beobachtet am
    /// 14.11.2026 um 16:52 – Verdichter aus, Lüfter dreht), und eine Zeichnung, die ihn dann
    /// stehend zeigt, behauptet eine Messung, die sie nicht hat.
    public static func luefterLaeuft(_ w: WaermepumpeOut) -> Bool {
        if let d = w.luefterDrehzahl?.belastbar { return d > 0 }
        return w.laeuft
    }

    /// Das Wort unter dem Lüfter.
    public static func luefterwort(_ w: WaermepumpeOut) -> String {
        guard let d = w.luefterDrehzahl?.belastbar else { return "Lüfter · nicht gemessen" }
        return "Lüfter · Drehzahl \(Formate.zahl(d.rounded(), stellen: 0))"
    }
}
