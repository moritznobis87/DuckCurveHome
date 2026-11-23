import Foundation

/// Die Wache der Startseite: welche Befunde dastehen, in welcher Reihenfolge und in welchem Ton.
///
/// **Warum die Auswahl im Kern steht und nicht in der Zeile, die sie zeichnet.** Die Vorlage
/// nimmt genau zwei Befunde (`Wache.tsx:30`: `befunde.slice(0, 2)`) und begründet das nicht aus
/// der Darstellung, sondern aus der Sortierung des Dienstes (`Wache.tsx:21-24`: „Der Dienst
/// sortiert: Alarm vor Warnung, bei gleicher Schwere der ältere“). Welche zwei von fünf Befunden
/// jemand im Vorbeigehen liest, ist damit eine Entscheidung über Inhalt und nicht über Form -
/// und sie gehört an eine Stelle, an der sie geprüft werden kann. Dieselbe Begründung trägt
/// ``Ruhebild/schwersterBefund(_:zuerst:)``, die aus der Wache den einen Satz des Ruhebilds nimmt.
///
/// **Die Zwei ist keine Geschmacksfrage.** An der Wand rollt nichts (`JetztSeite.swift`, die
/// Spalte ohne Rollbereich): eine Wache mit fünf Zeilen schiebt Kurve und Fuß aus dem Bild, und
/// was dort unten abgeschnitten wird, ist weg - nicht weggerollt.
///
/// **Der Ton gehört dazu.** `globals.css:205-207` färbt Kante, Grund und Zeichen nach der
/// Schwere: `--alert` auf 10 % `--alert` beim Alarm, `--amber-soft` auf 10 % `--amber-soft` bei
/// einer Warnung. Das ist dieselbe Zuordnung wie die Auswahl - eine Rechnung über dem Befund -
/// und steht deshalb hier und nicht in der `View`.
public enum Wachbefunde {

    /// Wie viele Zeilen höchstens dastehen (`Wache.tsx:30`).
    public static let hoechstens = 2

    /// Die Schwere eines Befunds, auf die drei Fälle des Dienstes gebracht.
    public enum Schwere: Sendable, Hashable {
        case alarm
        case warnung
        /// Eine Schwere, die dieser Fassung unbekannt ist. `Schema.swift` lässt sie ausdrücklich
        /// zu, damit eine neue Stufe im Dienst die App nicht zum Absturz bringt.
        case unbekannt

        /// Kante, Zeichen und Grund dieser Zeile.
        ///
        /// Die unbekannte Schwere nimmt ``Marken/mist`` - die Farbe, mit der die App überall
        /// sagt „das ist eine Auskunft und keine Warnung“. Die Vorlage hat den Fall nicht: ihr
        /// CSS fällt auf `--alert` zurück, und ein roter Balken für eine Stufe, die niemand
        /// kennt, wäre eine Warnung, für die es keinen Grund gibt.
        public var farbe: Farbwert {
            switch self {
            case .alarm: return Marken.alarm
            case .warnung: return Marken.amberWeich
            case .unbekannt: return Marken.mist
            }
        }

        /// Der Grund der Zeile: dieselbe Farbe auf 10 %.
        ///
        /// Die Rechnung stand hier und gehört zu den Marken: ein Zehntel ist dort eine Zahl
        /// für die ganze Wache, hier war es eine Zahl in einem Zweig. ``Marken/wachzeile(_:)``
        /// gibt Kante und Grund als Paar und nennt die Stelle der Vorlage.
        public var grundfarbe: Farbwert {
            Marken.wachzeile(farbe).grund
        }
    }

    /// Eine Zeile der Wache - fertig zum Zeichnen.
    public struct Zeile: Sendable, Hashable, Identifiable {
        /// Die Kennung des Dienstes; in der Vorlage der Schlüssel der Liste (`Wache.tsx:31`).
        public let name: String
        /// Der ganze Satz aus dem Dienst (`text_de`).
        ///
        /// **Er wird nicht gekürzt und nicht umgeschrieben.** `Wache.tsx:14-18` nennt den Grund:
        /// „Die Puffertemperaturen seit 2 Tagen still“ ist eine Beobachtung; erst „ohne sie gibt
        /// es keinen Ladezustand“ sagt, warum es einen stören soll.
        public let satz: String
        public let schwere: Schwere

        public var id: String { name }

        public init(name: String, satz: String, schwere: Schwere) {
            self.name = name
            self.satz = satz
            self.schwere = schwere
        }
    }

    /// Die ersten Zeilen der Wache: begrenzt und eingefärbt, in der Reihenfolge des Dienstes.
    ///
    /// **Hier wird nicht sortiert, und das ist eine Entscheidung.** Der Dienst sortiert schon:
    /// „Alarm vor Warnung, bei gleicher Schwere der ältere“ (`Wache.tsx:21-24`). Die Vorlage
    /// schneidet darum nur ab (`:30`: `slice(0, 2)`), und ``Ruhebild/schwersterBefund(_:zuerst:)``
    /// nimmt aus demselben Grund den ersten und nicht den lautesten: dieselbe Reihenfolge ein
    /// zweites Mal zu behaupten heißt, zwei Wahrheiten darüber zu haben, welcher Befund der
    /// schwerere ist - und die zweite steht dann in einer App, die der Dienst nicht kennt.
    ///
    /// **`zuerst` sind Befunde, die der Dienst nicht haben kann** - heute genau einer: der
    /// Abstand der beiden Uhren (``Hausuhr/befund``). Er steht vor den *Warnungen* des Dienstes,
    /// weil er deren Zeitstempel entwertet: wer die Wache liest, ohne zu wissen, dass die Uhren
    /// auseinandergehen, sucht den Fehler bei den Zahlen.
    ///
    /// **Aber nie vor einem `.alarm` des Dienstes, und das war ein echter Verlust.**
    /// Nachgerechnet: 180 s Versatz plus ein Alarm `puffer_still` („seit zwei Tagen still"),
    /// ``Ruhebild/schwersterBefund(_:zuerst:)`` mit `hoechstens: 1` - auf der Wand stand der
    /// Uhrbefund, eine ``Schwere/warnung``, und der Alarm war weg. Eine schiefe Uhr macht
    /// Zeitstempel fraglich; ein Alarm sagt, dass eine Quelle ganz schweigt. Das zweite wiegt
    /// mehr, und auf dem Ruhebild gibt es nur einen Platz.
    ///
    /// **Umsortiert wird dafür nichts.** Genommen wird der vordere Lauf der Alarme
    /// (`prefix(while:)`), nicht alle Alarme der Liste - das verlässt sich auf die Sortierung
    /// des Dienstes, statt ihr eine zweite eigene gegenüberzustellen. Steht in seiner Liste eine
    /// Warnung vor einem Alarm, bleibt sie dort stehen - und dann **fällt der Alarm bei
    /// `hoechstens: 2` aus der Liste heraus** (nachgerechnet: `[warnung, alarm]` mit einem
    /// eigenen Befund ergibt `[eigener, warnung]`). Dieselbe Zusage trägt schon der Schnitt bei
    /// zwei Zeilen; sie steht auf `_nach_schwere` in `live_runtime.py`, und seit dem 22.11.2026
    /// gibt es dort eine Prüfung dafür (`test_alarme_stehen_vor_warnungen_in_der_liste`), weil
    /// die Funktion bis dahin durch `return list(befunde)` ersetzbar war, ohne dass etwas fiel.
    public static func zeilen(
        _ befunde: [WatchFindingOut], zuerst: [Zeile] = [],
        hoechstens: Int = Wachbefunde.hoechstens
    ) -> [Zeile] {
        guard hoechstens > 0 else { return [] }
        let dienst = befunde.map { b in
            Zeile(name: b.name, satz: b.textDe, schwere: schwere(b.severity))
        }
        let alarme = dienst.prefix { $0.schwere == .alarm }
        var zeilen = Array(alarme)
        zeilen.append(contentsOf: zuerst)
        zeilen.append(contentsOf: dienst.dropFirst(alarme.count))
        return Array(zeilen.prefix(hoechstens))
    }

    /// Die Schwere des Dienstes in die der Oberfläche.
    public static func schwere(_ wahl: WatchFindingOutSeverityWahl) -> Schwere {
        switch wahl {
        case .alarm: return .alarm
        case .warn: return .warnung
        case .unbekannt: return .unbekannt
        }
    }
}
