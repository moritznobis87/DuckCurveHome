import Foundation

/// Die Geometrie des Regelkreis-Schaltbilds: die Typen zu ``Schaltbilddaten``.
///
/// **Warum es das gibt.** Der Hausherr hat am 24.11.2026 festgelegt, dass der Regelkreis überall
/// als Blockschaltbild steht und nirgends als Liste. Wo ein Kästchen liegt und wie eine Leitung
/// läuft, ist für Dashboard und App dasselbe und steht einmal in
/// `docs/regelkreis-schaltbild.json`. Das Dashboard hält seine `layout.ts` mit einem Test
/// dagegen; die App bekommt ``Schaltbilddaten`` daraus erzeugt (`tools/gen-schaltbild.py`).
///
/// **Was mit was verbunden ist**, steht nicht hier, sondern kommt vom Dienst (`RegelkreisOut`).
/// Hier steht nur die Zeichnung: Rechtecke, Wege, Aufschriften. Ohne SwiftUI, damit sich auf dem
/// Prüfrechner nachweisen lässt, dass die Zeichnung zu dem passt, was der Dienst liefert.
public enum Schaltbild {
    /// Ein Punkt auf der Karte, in ihren eigenen Einheiten (1400 mal 1300).
    public struct Punkt: Sendable, Hashable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// Ein Rechteck auf der Karte: linke obere Ecke, Breite, Höhe.
    public struct Rechteck: Sendable, Hashable {
        public var x: Double
        public var y: Double
        public var w: Double
        public var h: Double

        public init(x: Double, y: Double, w: Double, h: Double) {
            self.x = x
            self.y = y
            self.w = w
            self.h = h
        }

        public var mitte: Punkt { Punkt(x: x + w / 2, y: y + h / 2) }

        public func enthaelt(_ p: Punkt) -> Bool {
            p.x >= x && p.x <= x + w && p.y >= y && p.y <= y + h
        }
    }

    /// Wo ein Block steht: sein Hauptrechteck und die Stellen, an denen er wiederholt wird.
    ///
    /// Die Außentemperatur wirkt an vier Stellen. In der Topologie ist sie ein Knoten; in der
    /// Zeichnung bekommt sie mehrere Rechtecke, denn eine Leitung quer über das Bild wäre
    /// unleserlicher als derselbe Name zweimal (`layout.ts`, „Wiederholte Knoten“).
    public struct Platz: Sendable, Hashable {
        public var rect: Rechteck
        public var wdh: [Rechteck]

        public init(rect: Rechteck, wdh: [Rechteck] = []) {
            self.rect = rect
            self.wdh = wdh
        }

        /// Alle Rechtecke dieses Blocks, das Hauptrechteck zuerst.
        public var alle: [Rechteck] { [rect] + wdh }
    }

    /// Eine Leitung als Streckenzug. `bogen` ist die Stelle, an der sie über eine andere springt.
    public struct Weg: Sendable, Hashable {
        public var punkte: [Punkt]
        public var bogen: Punkt?

        public init(punkte: [Punkt], bogen: Punkt? = nil) {
            self.punkte = punkte
            self.bogen = bogen
        }
    }

    /// Woran eine Aufschrift ausgerichtet ist, wie `text-anchor` in SVG.
    public enum Anker: String, Sendable, Hashable {
        case start, middle, end
    }

    /// Eine Aufschrift auf der Karte: an einer Leitung oder über einer Ebene.
    public struct Beschriftung: Sendable, Hashable {
        public var x: Double
        public var y: Double
        public var text: String
        public var anker: Anker

        public init(x: Double, y: Double, text: String, anker: Anker = .start) {
            self.x = x
            self.y = y
            self.text = text
            self.anker = anker
        }
    }

    /// Ein Ausschnitt zum Hineinzoomen: eine Ebene der Kaskade oder die ganze Karte.
    public struct Sicht: Sendable, Hashable, Identifiable {
        public var schluessel: String
        public var name: String
        public var ausschnitt: Rechteck
        public var id: String { schluessel }

        public init(schluessel: String, name: String, ausschnitt: Rechteck) {
            self.schluessel = schluessel
            self.name = name
            self.ausschnitt = ausschnitt
        }
    }

    /// Wo ein Block landet, für den es keinen Platz gibt: eine Reihe unter der Karte, sieben
    /// nebeneinander. Dieselbe Rechnung wie im Dashboard (`layout.ts`, `notplatz`). Ein Block,
    /// den der Kern neu kennt und die Zeichnung noch nicht, bleibt so sichtbar.
    public static func notplatz(_ i: Int) -> Rechteck {
        Rechteck(x: 28 + Double(i % 7) * 196, y: 1272 + Double(i / 7) * 56, w: 180, h: 44)
    }

    /// Das Rechteck eines Blocks: sein Platz aus der Zeichnung, sonst ein Notplatz.
    ///
    /// - Parameter ohnePlatz: wie viele Blöcke vor diesem schon keinen Platz hatten.
    public static func rechteck(fuer block: String, ohnePlatz: Int) -> Rechteck {
        Schaltbilddaten.plaetze[block]?.rect ?? notplatz(ohnePlatz)
    }

    /// Der Schlüssel einer Leitung in ``Schaltbilddaten/wege``: „von→nach“.
    public static func kante(von: String, nach: String) -> String {
        "\(von)→\(nach)"
    }

    /// Welcher Block an einem Punkt der Karte liegt, Wiederholungen eingeschlossen.
    ///
    /// - Parameter bloecke: die Blöcke des Dienstes in ihrer Reihenfolge; daraus folgen die
    ///   Notplätze derer, die die Zeichnung nicht kennt.
    public static func block(bei p: Punkt, bloecke: [String]) -> String? {
        var ohnePlatz = 0
        for id in bloecke {
            if let platz = Schaltbilddaten.plaetze[id] {
                if platz.alle.contains(where: { $0.enthaelt(p) }) { return id }
            } else {
                if notplatz(ohnePlatz).enthaelt(p) { return id }
                ohnePlatz += 1
            }
        }
        return nil
    }
}
