import Foundation

/// Die Steuerung des Speichers: Betriebsart und Untergrenze des Ladestands.
///
/// **Warum sie auf die Speicherseite gehoert und nicht ins Dashboard.** Die untere Leiste ist
/// fuer Dinge, die man im Vorbeigehen drueckt. Das hier ist eine Einstellung, die man einmal
/// trifft und dann an ihren Folgen misst - und die Folgen stehen auf genau dieser Seite:
/// Netzladung, Ladung bei Dunkelheit, Vollzyklen (`BatteryControl.tsx:11-16`).
///
/// **Wozu die Untergrenze.** Der Libbi entlaedt bis zu seiner eigenen Grenze, meldet dann 0 %,
/// und wenn dieser Stand eine Stunde steht, holt er sich rund 6 % aus dem Netz zurueck. Diese
/// Energie erreicht das Haus nicht: gemessen am 03.09.2026 war sie drei Stunden spaeter wieder
/// verschwunden, ohne dass der Speicher etwas abgegeben haette. Die letzten Prozent zu fahren
/// kostet also Netzstrom, Wirkungsgrad und Zyklen und bringt nichts
/// (`BatteryControl.tsx:18-22`).
///
/// **Warum die Woerter hier stehen und nicht in der Karte.** Es gibt in der App schon eine
/// zweite Speicherbedienung (`Seiten/Technik/MitteilungenSeite.swift`, `Batterieblatt`), und
/// die nennt dieselben Betriebsarten anders. Zwei Stellen mit eigenen Woertern sind zwei
/// Antworten auf die Frage, was „Halten“ heisst.
public enum Speichersteuerung {

    /// Eine der drei Betriebsarten der Vorlage (`BatteryControl.tsx:24-28`).
    public struct Betriebsart: Sendable, Hashable, Identifiable {
        public let wahl: BatteryModeInModeWahl
        /// Was auf dem Knopf steht.
        public let wort: String
        /// Was er tut - in der Vorlage das `title`-Attribut, in der App die Zeile darunter.
        public let dazu: String

        public var id: String { wahl.rawValue }

        public init(wahl: BatteryModeInModeWahl, wort: String, dazu: String) {
            self.wahl = wahl
            self.wort = wort
            self.dazu = dazu
        }
    }

    /// Die drei, in der Reihenfolge der Vorlage.
    ///
    /// **`off` ist keine davon.** Es ist die Vorgabe und heisst: DCH sendet gar nichts. Fuer
    /// die Anzeige ist das dasselbe wie „Frei“; der Unterschied steht in der Zeile darunter,
    /// nicht auf einem vierten Knopf (`BatteryControl.tsx:64-66`).
    public static let arten: [Betriebsart] = [
        Betriebsart(
            wahl: .auto, wort: "Auto",
            dazu: "Untergrenze aktiv: DCH hält den Speicher an, bevor er leer läuft."),
        Betriebsart(
            wahl: .normal, wort: "Frei",
            dazu: "Speicher freigegeben; DCH greift nicht ein."),
        Betriebsart(
            wahl: .hold, wort: "Halten",
            dazu: "Speicher befristet anhalten (hält auch das Laden an)."),
    ]

    /// Die fünf Stufen der Untergrenze (`BatteryControl.tsx:29`).
    public static let untergrenzen: [Double] = [0, 0.06, 0.1, 0.15, 0.2]

    /// Wie lange ein „Halten“ gilt, in Minuten (`BatteryControl.tsx:54`).
    ///
    /// **Zwei Stunden, nicht vier.** `Batterieblatt` sendet heute 240; die Vorlage sendet 120,
    /// und zwei Zahlen fuer dieselbe Frist sind zwei verschiedene Versprechen an denselben
    /// Nutzer.
    public static let frist = 120

    // MARK: - Was angezeigt wird

    /// Welcher Knopf gedrueckt aussieht (`BatteryControl.tsx:66`).
    public static func gezeigteArt(_ s: BatteryLiveOut) -> BatteryModeInModeWahl {
        switch s.mode {
        case .auto: return .auto
        case .hold: return .hold
        case .normal, .off, .unbekannt, .none: return .normal
        }
    }

    /// Welche Betriebsart mitgesendet wird, wenn nur die Untergrenze geaendert wird
    /// (`BatteryControl.tsx:111`).
    ///
    /// Aus `off` wird `auto`: eine Untergrenze zu setzen und zugleich „sende nichts“ zu meinen
    /// waere eine Einstellung ohne Wirkung.
    public static func stellwahl(_ s: BatteryLiveOut) -> BatteryModeInModeWahl {
        switch s.mode {
        case .auto: return .auto
        case .normal: return .normal
        case .hold: return .hold
        case .off, .unbekannt, .none: return .auto
        }
    }

    /// „Ladestand 54 %“ oder „Ladestand unbekannt“ - rechts im Kartenkopf
    /// (`BatteryControl.tsx:85`).
    ///
    /// **Der Anteil wird gedeckelt gelesen.** Der Dienst liefert 0 bis 1; `Batterieblatt`
    /// rechnet seit jeher einen Wert ueber 1 als Prozent zurueck, weil die Quelle beides
    /// geliefert hat. Dieselbe Vorsicht hier, damit nicht zwei Stellen der App denselben
    /// Messwert verschieden lesen.
    public static func ladestandswort(_ s: BatteryLiveOut) -> String {
        guard let anteil = ladestand(s) else { return "Ladestand unbekannt" }
        return "Ladestand \(Formate.prozent(anteil))"
    }

    /// Der Ladestand als Anteil von 0 bis 1, oder `nil`.
    public static func ladestand(_ s: BatteryLiveOut) -> Double? {
        guard let roh = s.soc, roh.isFinite else { return nil }
        return roh > 1 ? roh / 100 : roh
    }

    /// „aus“, „6 %“, „10 %“ … (`BatteryControl.tsx:115`).
    public static func untergrenzenwort(_ stufe: Double) -> String {
        stufe <= 0 ? "aus" : Formate.prozent(stufe)
    }

    /// Steht die Untergrenze auf dieser Stufe? (`BatteryControl.tsx:109`)
    ///
    /// Verglichen wird mit einer Schranke und nicht mit `==`: 0,06 ist als Gleitkommazahl nicht
    /// 0,06, und ein Knopf, der nie gedrueckt aussieht, sieht aus wie ein kaputter Knopf.
    public static func istGewaehlt(_ s: BatteryLiveOut, stufe: Double) -> Bool {
        abs((s.reserveSoc ?? 0) - stufe) < 0.001
    }

    /// Ob die Griffe ueberhaupt bedienbar sind (`BatteryControl.tsx:68`).
    public static func gesperrt(_ s: BatteryLiveOut) -> Bool {
        s.controlEnabled != true
    }

    // MARK: - Die Zeile unter den Griffen

    /// Was in der Konfiguration nicht freigegeben ist, laesst sich auch nicht erklaeren
    /// (`BatteryControl.tsx:79`).
    public static let gesperrtSatz =
        "Die Steuerung des Speichers ist in der Konfiguration nicht freigegeben."
    /// Waehrend gesendet wird (`BatteryControl.tsx:121`).
    public static let sendetSatz = "schalte …"
    /// Wenn die Antwort ausbleibt (`BatteryControl.tsx:56`).
    public static let nichtBestaetigt = "Umschalten nicht bestätigt."

    /// Die zusammengesetzte Notenzeile (`BatteryControl.tsx:69-79`).
    ///
    /// **Der Fehler verdraengt alles andere.** Er steht zwoelf Sekunden und ist in dieser Zeit
    /// die einzige Auskunft, die zaehlt - der Hinweis des Dienstes beschreibt einen Zustand,
    /// der gerade nicht erreicht wurde.
    ///
    /// **„Zuletzt gesendet“ ist nicht „so steht es“.** Die myenergi-Cloud bestaetigt nichts; ob
    /// das Geraet folgt, sagt erst die naechste Messung. Darum stehen Absicht und Befehl
    /// nebeneinander (``BatteryLiveOut``).
    public static func zeile(_ s: BatteryLiveOut, fehler: String? = nil) -> String {
        if let fehler, !fehler.isEmpty { return fehler }
        guard s.controlEnabled == true else { return gesperrtSatz }
        var teile: [String] = []
        if let hinweis = s.noteDe, !hinweis.isEmpty { teile.append(hinweis) }
        if let befehl = s.command {
            teile.append("Zuletzt gesendet: \(befehlswort(befehl)).")
        }
        if let letzter = s.lastError, !letzter.isEmpty { teile.append("Fehler: \(letzter)") }
        return teile.joined(separator: " ")
    }

    /// Wie der zuletzt gesendete Befehl heisst (`BatteryControl.tsx:74`).
    ///
    /// Eine unbekannte Spielart des Dienstes heisst hier „normal“ und nicht „—unbekannt—“: der
    /// Rohwert des Schemas ist kein Satz, den jemand lesen soll.
    static func befehlswort(_ befehl: BatteryLiveOutCommandWahl) -> String {
        befehl == .stopped ? "angehalten" : "normal"
    }

    /// Der Befehl, den ein Knopf sendet.
    public static func befehl(
        _ art: BatteryModeInModeWahl, untergrenze: Double? = nil
    ) -> BatteryModeIn {
        BatteryModeIn(mode: art, durationMin: frist, reserveSoc: untergrenze)
    }
}
