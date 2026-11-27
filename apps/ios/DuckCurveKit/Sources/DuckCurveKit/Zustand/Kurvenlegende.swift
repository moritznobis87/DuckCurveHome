import Foundation

/// Ein Eintrag der Legende unter der Tageskurve: was er nennt und wie die Marke davor aussieht.
///
/// **Sie nennt, was im Bild steht, und zeichnet es so, wie es dort steht.** Der Hausherr am
/// 27.11.2026 mit einem Bild der App, Reiter „Morgen“, um 12:34 Uhr: „Die Legenden-Erklärung
/// passt überhaupt nicht zu der Grafik.“ Im Bild standen zwei gestrichelte Linien und eine
/// durchgezogene. In der Legende standen fünf Einträge mit durchgezogenem Strich, zwei davon,
/// Strompreis und Preistief, für etwas, das gar nicht im Bild war: Die Preise für morgen
/// veröffentlicht die Börse erst gegen 13 Uhr. Die Ansicht zeichnete jeden Strich durchgezogen,
/// gleich was der Eintrag sagte.
///
/// Darum hängen drei Einträge am Inhalt: die erwartete Wärmepumpe, der Strompreis und das
/// Preistief. Sonne, Prognose und Haus bleiben am Tag: sie gehören zu jedem Tag, und ohne sie
/// stünde an einem Tag ohne Messwerte ein leeres Bild ohne ein Wort, was dort stehen würde.
/// Dass die Preise für morgen erst gegen 13 Uhr kommen, sagen die Zahlen des Tages
/// (``Tageskacheln``); die Legende wiederholt es nicht.
///
/// Gerechnet wird hier und im Dashboard in `tageslegende.ts`, mit denselben Fällen in beiden
/// Tests.
public struct Kurvenlegende: Sendable, Hashable, Identifiable {
    /// Welche Reihe des Bildes der Eintrag nennt. Die Ansicht gibt jeder ihre Farbe.
    public enum Reihe: String, Sendable, Hashable {
        case sonne, sonneErwartet, schatten, haus, waermepumpe, waermepumpeErwartet, strompreis,
            preistief
    }

    /// Wie die Marke vor dem Wort aussieht: eine Fläche, ein Strich oder ein gestrichelter Strich.
    public enum Form: String, Sendable, Hashable {
        case flaeche, linie, gestrichelt
    }

    public let reihe: Reihe
    public let wort: String
    public let form: Form

    public var id: Reihe { reihe }

    public init(reihe: Reihe, wort: String, form: Form) {
        self.reihe = reihe
        self.wort = wort
        self.form = form
    }
}

extension Tageskurve {
    /// Der Tag im Hintergrund mit seiner Sonne, etwa „heute 10,8 kWh“. `nil`, wenn es keinen gibt.
    public var schattenlegende: String? {
        guard !schatten.isEmpty else { return nil }
        let wort = schattenwort ?? "Vortag"
        guard let kwh = schattenKwh else { return wort }
        return "\(wort) \(Formate.kwh(kwh))"
    }

    /// Die Einträge der Legende für diesen Tag, in der Reihenfolge, in der sie dastehen.
    public func legende(_ tag: Kurventag) -> [Kurvenlegende] {
        var aus: [Kurvenlegende] = []
        if tag != .morgen {
            aus.append(Kurvenlegende(reihe: .sonne, wort: "Sonne", form: .flaeche))
        }
        if tag != .gestern {
            aus.append(
                Kurvenlegende(
                    reihe: .sonneErwartet, wort: tag == .morgen ? "Sonne erwartet" : "Prognose",
                    form: .gestrichelt))
        }
        // Der Tag im Hintergrund ist gemessen, also durchgezogen: gestrichelt ist nur, was noch
        // keiner gemessen hat.
        if let wort = schattenlegende {
            aus.append(Kurvenlegende(reihe: .schatten, wort: wort, form: .linie))
        }
        if tag != .morgen {
            aus.append(Kurvenlegende(reihe: .haus, wort: "Haus", form: .linie))
        }
        if tag != .morgen, !waermepumpe.isEmpty {
            aus.append(Kurvenlegende(reihe: .waermepumpe, wort: "Wärmepumpe", form: .linie))
        }
        if tag == .morgen, !waermeErwartet.isEmpty {
            aus.append(
                Kurvenlegende(reihe: .waermepumpeErwartet, wort: "Wärmepumpe", form: .gestrichelt))
        }
        // Der Preis ist durchgezogen, sobald ein Stück von ihm schon gegolten hat.
        if !preis.isEmpty || !preisErwartet.isEmpty {
            aus.append(
                Kurvenlegende(
                    reihe: .strompreis, wort: "Strompreis", form: preis.isEmpty ? .gestrichelt : .linie))
        }
        if !baender.isEmpty {
            aus.append(Kurvenlegende(reihe: .preistief, wort: "Preistief", form: .flaeche))
        }
        return aus
    }
}
