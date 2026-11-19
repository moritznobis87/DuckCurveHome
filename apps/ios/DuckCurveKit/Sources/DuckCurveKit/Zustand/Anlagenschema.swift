import Foundation

/// Die Rechnungen hinter dem Anlagenschema: Farben, Mischung, Tempo, Worte.
///
/// **Alles hier ist ohne Gerät prüfbar.** Die Zeichnung setzt nur zusammen, was diese
/// Funktionen liefern – so wie im Dashboard, wo dieselbe Trennung in `anlage/schema.ts` und
/// `anlage/Schema.tsx` steht.
///
/// **Was die App an dieser Stelle hatte.** Drei Karten mit Zahlenreihen: Strom, Puffer,
/// Wärmepumpe. Die Vorlage zeigt dort eine Bühne – links sammeln sich drei Stromquellen zu
/// einem Strang in die Wärmepumpe, rechts steht der Speicher als Glas, und an ihm treffen
/// sich vier getrennte Wasserkreise, die sich nur dort berühren. Der Arbeitsvorrat
/// (`ABGLEICH.md`) hat diese Seite mit vier kleinen Punkten geführt und dabei vorausgesetzt,
/// die App habe ein Schema. Sie hatte keines; gemeldet hat es der Nutzer.
public enum Anlagenschema {

    // MARK: - Farben

    /// Die Farben des Schemas, als Werte und nicht als Marken: ein Verlauf nimmt keine
    /// Token. Dieselbe Bedeutung wie in ``Marken``.
    public enum Farbwerte {
        public static let pv = Farbwert(0xF2A900)
        public static let pvWeich = Farbwert(0xFFD778)
        public static let netz = Farbwert(0x7FA3B3)
        public static let speicher = Farbwert(0x9FD0DF)
        public static let wallbox = Farbwert(0x5C8FA3)
        public static let waermepumpe = Farbwert(0xE0966B)
        public static let ofen = Farbwert(0xC9742C)
        public static let kalt = Farbwert(0x2A6F8F)
    }

    /// Stützstellen der Wasserskala in °C – dieselbe für Glas und Rohre.
    static let stufen: [(t: Double, r: Double, g: Double, b: Double)] = [
        (10, 0x1A, 0x3A, 0x52),
        (25, 0x1F, 0x4C, 0x66),
        (35, 0x7F, 0xA3, 0xB3),
        (45, 0xFF, 0xD7, 0x78),
        (55, 0xF2, 0xA9, 0x00),
        (65, 0xE0, 0x53, 0x3D),
    ]

    /// Die Farbe einer Wassertemperatur. Ohne Wert: das neutrale Blaugrau der Skala.
    public static func farbe(_ t: Double?) -> Farbwert {
        guard let t, t.isFinite else { return Farbwerte.netz }
        guard let erste = stufen.first, let letzte = stufen.last else { return Farbwerte.netz }
        // `Farbwert` rechnet in Anteilen von 0 bis 1, die Stuetzstellen stehen als Bytes -
        // wie im Dashboard, wo sie aus `rgb()` kommen.
        func ausBytes(_ r: Double, _ g: Double, _ b: Double) -> Farbwert {
            Farbwert(rot: r / 255, gruen: g / 255, blau: b / 255)
        }
        if t <= erste.t { return ausBytes(erste.r, erste.g, erste.b) }
        var vor = erste
        for s in stufen {
            if t <= s.t {
                let f = (t - vor.t) / (s.t - vor.t)
                return ausBytes(
                    (vor.r + (s.r - vor.r) * f).rounded(),
                    (vor.g + (s.g - vor.g) * f).rounded(),
                    (vor.b + (s.b - vor.b) * f).rounded())
            }
            vor = s
        }
        return ausBytes(letzte.r, letzte.g, letzte.b)
    }

    // MARK: - Wann ein Rohr lebt

    /// Unter dieser Leistung steht ein Rohr still.
    public static let anKw = 0.05

    public static func istAn(_ kw: Double?) -> Bool {
        guard let kw, kw.isFinite else { return false }
        return abs(kw) >= anKw
    }

    /// Umlaufzeit eines Lichtpunkts in Sekunden: schneller bei mehr Leistung, in Grenzen, und
    /// auf halbe Sekunden gerundet, damit ein neuer Messwert die Bewegung nicht bei jedem
    /// Abruf neu beginnt. Rückläufe laufen langsamer, damit der Vorlauf das Wort führt.
    public static func rohrDauer(_ kw: Double, leise: Bool = false) -> Double {
        let roh = max(2.4, min(9, 16 / max(abs(kw), anKw))) * (leise ? 1.3 : 1)
        return (roh * 2).rounded() / 2
    }

    /// Wie viele Lichtpunkte auf einem Rohr laufen: zwei bis sieben, mit der Leistung.
    public static func punktzahl(_ kw: Double, leise: Bool = false) -> Int {
        max(2, min(7, Int((abs(kw) * 0.8).rounded()) + 2)) - (leise ? 1 : 0)
    }

    /// Strichstärke der Grundschicht eines Rohrs.
    public static func rohrStaerke(_ kw: Double?, leise: Bool = false) -> Double {
        (istAn(kw) ? min(14, 6 + abs(kw ?? 0) * 0.9) : 4) * (leise ? 0.6 : 1)
    }

    // MARK: - Woher der Strom kommt

    public struct Mischung: Sendable, Hashable {
        /// Sechs Punktfarben im Verhältnis der Anteile; leer, wenn nichts fließt.
        public let farben: [Farbwert]
        public let text: String
        public let haupt: Farbwert
    }

    /// Woher der Strom im Knoten gerade kommt, als Folge von Punktfarben und als Satz.
    ///
    /// **Die sechs Punkte werden nach dem größten Rückstand vergeben:** Platz für Platz
    /// bekommt die Quelle den Punkt, die gemessen an ihrem Anteil am weitesten hinterherhinkt.
    /// So liegen die Farben verschränkt statt blockweise, und zwei Punkte derselben kleinen
    /// Quelle stehen nicht nebeneinander.
    public static func mischung(_ s: AnlageStromOut) -> Mischung {
        let quellen: [(farbe: Farbwert, name: String, anteil: Double)] = [
            (Farbwerte.pv, "PV", s.sharePv),
            (Farbwerte.netz, "Netz", s.shareGrid),
            (Farbwerte.speicher, "Speicher", s.shareBattery),
        ]
        let summe = quellen.reduce(0) { $0 + $1.anteil }
        guard summe >= 0.01 else {
            return Mischung(farben: [], text: "", haupt: Farbwerte.netz)
        }
        var vergeben = [Int](repeating: 0, count: quellen.count)
        var farben: [Farbwert] = []
        for i in 0..<6 {
            var beste = 0
            var bester = -Double.infinity
            for (k, q) in quellen.enumerated() {
                let punkte = (q.anteil / summe) * Double(i + 1) - Double(vergeben[k])
                if punkte > bester {
                    bester = punkte
                    beste = k
                }
            }
            vergeben[beste] += 1
            farben.append(quellen[beste].farbe)
        }
        let haupt = quellen.max { $0.anteil < $1.anteil }?.farbe ?? Farbwerte.netz
        let text =
            quellen
            .filter { $0.anteil / summe >= 0.05 }
            .map { "\($0.name) \(Int((($0.anteil / summe) * 100).rounded()))\u{00a0}%" }
            .joined(separator: ", ")
        return Mischung(farben: farben, text: text, haupt: haupt)
    }

    // MARK: - Worte

    /// „1 h 12 min", „38 min", oder leer, wenn es keinen Beginn gibt.
    public static func dauerText(seit iso: String?, jetzt: Date) -> String {
        guard let iso, let d = Zeit.ausIso(iso) else { return "" }
        let min = max(0, Int((jetzt.timeIntervalSince(d) / 60).rounded()))
        if min < 60 { return "\(min) min" }
        let h = min / 60
        let rest = min % 60
        return rest > 0 ? "\(h) h \(rest) min" : "\(h) h"
    }

    public static func netzWort(_ kw: Double?) -> String {
        guard istAn(kw), let kw else { return "ruht" }
        return kw < 0 ? "Einspeisung" : "Bezug"
    }

    /// Batterie positiv heißt entladen, wie überall in Duck Curve Home.
    public static func batterieWort(_ kw: Double?) -> String {
        guard istAn(kw), let kw else { return "ruht" }
        return kw > 0 ? "entlädt" : "lädt"
    }

    /// „lädt 1,2 kW", „entlädt 0,8 kW", „hält" oder leer. Das Wort kommt vom Dienst, damit
    /// die Schwelle an einer Stelle steht.
    public static func nettoText(_ sp: AnlageSpeicherOut) -> String {
        guard !sp.netWord.isEmpty else { return "" }
        if sp.netWord == "hält" { return "hält" }
        return "\(sp.netWord) \(Formate.zahl(abs(sp.netKw ?? 0), stellen: 1)) kW"
    }

    /// Was in der Ofenkachel unter dem Namen steht.
    ///
    /// **Drei Zustände und nicht zwei.** „Nicht angebunden" und „keine Verbindung" sind nicht
    /// dasselbe wie „aus": Die App schrieb `(running ?? false) ? "läuft" : "aus"` und machte
    /// damit aus einem Ofen, der gerade nicht meldet, einen ausgeschalteten.
    public static func ofenStatus(_ o: AnlageOfenOut) -> String {
        guard o.present else { return "nicht angebunden" }
        guard let laeuft = o.running else { return "keine Verbindung" }
        guard laeuft else { return "aus" }
        let stufe = o.powerLevel.map { "Stufe \(Int($0.rounded()))" } ?? "brennt"
        guard let pumpe = o.pumpPct else { return stufe }
        return "\(stufe) · Pumpe \(Int(pumpe.rounded())) %"
    }

    /// Was in der Warmwasserkachel unter dem Namen steht.
    public static func warmwasserStatus(_ w: AnlageWarmwasserOut, jetzt: Date) -> String {
        guard w.present else { return "kein Fühler am Auslass" }
        guard w.tapping == true else { return "ruht · Auslass kühlt ab" }
        let seit = dauerText(seit: w.tappingSince, jetzt: jetzt)
        return seit.isEmpty ? "Zapfung · Auslass" : "Zapfung seit \(seit) · Auslass"
    }

    /// **Ohne gemeldete Räume steht das da** und nicht „0 von 0, Anteil –".
    public static func heizungStatus(_ h: AnlageHeizkreisOut) -> String {
        guard h.roomsTotal > 0 else { return "keine Räume gemeldet" }
        return h.roomsOpen > 0 ? "Räume nehmen Wärme" : "kein Raum nimmt Wärme"
    }

    /// Der Satz über dem Bild: wer gerade Wärme macht.
    public static func erzeugerSatz(_ a: AnlageOut, jetzt: Date) -> String {
        if a.waermepumpe.running {
            let seit = dauerText(seit: a.waermepumpe.runningSince, jetzt: jetzt)
            return seit.isEmpty ? "Wärmepumpe läuft" : "Wärmepumpe läuft seit \(seit)"
        }
        if a.ofen.running == true {
            return a.ofen.powerLevel.map { "Ofen auf Stufe \(Int($0.rounded()))" } ?? "Ofen brennt"
        }
        return "alle Erzeuger stehen"
    }

    public static func kopfzeile(_ a: AnlageOut, jetzt: Date) -> String {
        var teile: [String] = []
        if let draussen = a.outdoorC {
            teile.append("\(Formate.zahl(draussen, stellen: 0)) °C draußen")
        }
        teile.append(erzeugerSatz(a, jetzt: jetzt))
        let mix = mischung(a.strom)
        if !mix.text.isEmpty { teile.append("Strom aus \(mix.text)") }
        return teile.joined(separator: " · ")
    }

    // MARK: - Wohin ein Symbol führt

    /// Jedes Gerät im Schema ist ein Verweis – dieselben Ziele wie die Knoten der Startseite.
    public enum Ziel: String, Sendable, Hashable, CaseIterable {
        case pv, netz, batterie, haus, waermepumpe, ofen, puffer, heizung, warmwasser

        public var weg: String {
            switch self {
            case .pv: return "/strom/pv"
            case .netz: return "/strom"
            case .batterie: return "/strom/speicher"
            case .haus: return "/strom"
            case .waermepumpe: return "/waerme"
            case .ofen: return "/waerme"
            case .puffer: return "/waerme"
            case .heizung: return "/haus"
            case .warmwasser: return "/waerme"
            }
        }

        public var wort: String {
            switch self {
            case .pv: return "Photovoltaik"
            case .netz: return "Strombilanz"
            case .batterie: return "Stromspeicher"
            case .haus: return "Haushalt in der Strombilanz"
            case .waermepumpe: return "Wärmepumpe und Puffer im Verlauf"
            case .ofen: return "Pelletofen im Verlauf"
            case .puffer: return "Pufferspeicher im Verlauf"
            case .heizung: return "Räume"
            case .warmwasser: return "Wärmeübersicht mit Warmwasser"
            }
        }

        /// Was die Bedienungshilfe vorliest.
        public var ansage: String { "\(wort). Details öffnen" }
    }
}
