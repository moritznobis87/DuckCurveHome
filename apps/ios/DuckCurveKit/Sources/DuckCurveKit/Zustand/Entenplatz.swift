import Foundation

/// Wo Alfreds Ente steht: die erlaubten Stellen, das Einrasten nach einem Zug und das Merken.
///
/// **Der Anlass** (Nutzer am 21.11.2026): „das Symbol von Alfred verschiebbar machen wenn man
/// laenger drauf drueckt und es dann ueber den Monitor zieht“. Die Ente sitzt unten rechts über
/// der Seite und liegt dort je nach Seite auf der letzten Zeile einer Liste oder auf dem rechten
/// Rand eines Diagramms.
///
/// **Warum das hier steht und nicht in der Ansicht.** Es sind vier Rechnungen, und jede einzelne
/// ist der Grund, aus dem die Ente sonst falsch sitzt: welche Stellen es überhaupt gibt, welche
/// aus einem Zug folgt, wie weit der Versatz zur Ecke ist, und was aus einer gespeicherten
/// Zeichenkette wird, die niemand mehr kennt. In einer `View` wäre keine davon prüfbar – die
/// übersetzt nur auf einem Mac. Dieselbe Begründung wie bei ``Tagesuhrgeometrie``.
///
/// **Gemerkt wird die Stelle, nicht der Punkt.** Ein Punkt gilt für genau einen Bildschirm in
/// genau einer Lage: ein Telefon im Hochformat, ein iPad im Querformat und ein geteiltes Fenster
/// am iPad haben drei verschiedene Größen, und ein gemerkter Punkt läge in zwei von drei Fällen
/// daneben oder außerhalb. Eine Stelle ist in jeder Größe dieselbe Aussage.
public enum Entenplatz {

    // MARK: - Die Maße der Ente (`Alfredblatt.swift`, `Entenknopf`)

    /// Das Bild der Ente.
    public static let entengroesse: Double = 38
    /// Das Polster zwischen Bild und Rand des weißen Kreises.
    public static let ring: Double = 7
    /// Der Abstand des Kreises zur Kante der Seite.
    public static let rand: Double = 20

    /// Die Kantenlänge des Felds, das die Ente mit Polster und Abstand belegt.
    ///
    /// **Sie steht hier, damit sie nicht zweimal steht.** Das Einrasten und das Begrenzen
    /// rechnen mit ihr; läge sie als Zahl in der Ansicht, würde ein größeres Bild die Ente
    /// still über die Kante schieben.
    public static let kantenlaenge: Double = entengroesse + 2 * ring + 2 * rand

    /// Ab dieser Strecke ist ein liegender Finger ein Zug und kein Halten.
    ///
    /// **Der Radius des weißen Kreises, und das ist die Begründung**: wer den Finger über den
    /// Rand der Ente hinausbewegt, hat sie verlassen und will sie mitnehmen. Darunter liegt
    /// jedes Zittern einer Hand, die ein Telefon hält und dabei spricht – und jedes Zittern,
    /// das die Ente verschiebt, ist eine verlorene Frage.
    public static let zugSchwelle: Double = entengroesse / 2 + ring

    // MARK: - Die Stellen

    /// Die senkrechte Kante, an der die Ente klebt.
    public enum Seite: String, Sendable, Hashable, CaseIterable {
        case links
        case rechts
    }

    /// Die Höhe, auf der sie an dieser Kante sitzt.
    public enum Hoehe: String, Sendable, Hashable, CaseIterable {
        case oben
        case mitte
        case unten
    }

    /// Eine erlaubte Stelle der Ente.
    ///
    /// **Sechs Stellen und nicht beliebig viele.** Zwei Kanten, weil eine Ente in der Mitte der
    /// Seite auf einem Diagramm sitzt und nicht neben ihm – frei stehen zu bleiben heißt, genau
    /// das zuzulassen. Drei Höhen, weil der Daumen unten liegt, die Tabellenköpfe oben stehen
    /// und an der Wandanzeige im Querformat beides weit auseinander ist.
    ///
    /// **Die Reihenfolge ist ein Ring um den Rand** (unten rechts, Mitte rechts, oben rechts,
    /// oben links, Mitte links, unten links). Zwei benachbarte Stellen unterscheiden sich darum
    /// in genau einer Richtung; ``naechste(nach:)`` wandert damit am Rand entlang und nicht über
    /// die Seite. Für die Bedienungshilfe ist das der Unterschied zwischen einer Reise und einem
    /// Sprung.
    public enum Stelle: String, Sendable, Hashable, CaseIterable {
        case untenRechts
        case mitteRechts
        case obenRechts
        case obenLinks
        case mitteLinks
        case untenLinks

        public var seite: Seite {
            switch self {
            case .untenRechts, .mitteRechts, .obenRechts: .rechts
            case .untenLinks, .mitteLinks, .obenLinks: .links
            }
        }

        public var hoehe: Hoehe {
            switch self {
            case .obenRechts, .obenLinks: .oben
            case .mitteRechts, .mitteLinks: .mitte
            case .untenRechts, .untenLinks: .unten
            }
        }

        /// Wie die Stelle gesprochen heißt – für VoiceOver und für den Weg zurück.
        public var name: String { "\(hoehe.rawValue) \(seite.rawValue)" }
    }

    /// Wo die Ente steht, solange niemand sie verschoben hat: unten rechts, wie bisher.
    ///
    /// **Über der Seite und nicht in der Leiste der fünf Bereiche** – dieselbe Entscheidung wie
    /// in ``Entenknopf``: die Leiste gehört den Bereichen, und Alfred ist keiner. Darum liegen
    /// alle sechs Stellen im Feld der Seite und keine darunter.
    public static let vorgabe: Stelle = .untenRechts

    /// Die nächste Stelle im Ring. Sechs Schritte führen zurück zum Anfang.
    public static func naechste(nach stelle: Stelle) -> Stelle {
        let alle = Stelle.allCases
        guard let i = alle.firstIndex(of: stelle) else { return vorgabe }
        return alle[(i + 1) % alle.count]
    }

    // MARK: - Fläche und Punkt

    /// Die Fläche, über der die Ente schwebt.
    ///
    /// Eigene Typen und nicht `CGSize`/`CGPoint`: dieses Paket baut und prüft auch unter Linux,
    /// und `CoreGraphics` gibt es dort nicht. Die Ansicht rechnet beide in einer Zeile um.
    public struct Flaeche: Sendable, Hashable {
        public var breite: Double
        public var hoehe: Double

        public init(breite: Double, hoehe: Double) {
            self.breite = breite
            self.hoehe = hoehe
        }

        /// Noch nicht gemessen – vor dem ersten Durchgang der Ansicht.
        public static let unbekannt = Flaeche(breite: 0, hoehe: 0)
    }

    /// Ein Punkt oder eine Strecke: x nach rechts, y nach unten.
    public struct Punkt: Sendable, Hashable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }

        public static let ursprung = Punkt(x: 0, y: 0)
    }

    /// Ob eine Strecke als Zug gilt – und damit das Halten beendet.
    public static func istZug(_ strecke: Punkt) -> Bool {
        hypot(strecke.x, strecke.y) >= zugSchwelle
    }

    // MARK: - Wo eine Stelle liegt

    /// Der Mittelpunkt des Entenfelds an einer Stelle.
    ///
    /// **Auf der Mitte des Felds und nicht auf der Mitte der Ente**: beide liegen aufeinander,
    /// weil das Polster rundherum gleich breit ist – und mit dem Feld rechnet auch das
    /// Begrenzen, sodass hier keine zweite Rechnung entsteht.
    public static func mittelpunkt(_ stelle: Stelle, in flaeche: Flaeche) -> Punkt {
        let halb = kantenlaenge / 2
        let x: Double
        switch stelle.seite {
        case .links: x = halb
        case .rechts: x = flaeche.breite - halb
        }
        let y: Double
        switch stelle.hoehe {
        case .oben: y = halb
        case .mitte: y = flaeche.hoehe / 2
        case .unten: y = flaeche.hoehe - halb
        }
        return Punkt(x: x, y: y)
    }

    /// Der Versatz gegenüber der Ecke unten rechts – was die Ansicht als `offset` braucht.
    ///
    /// Beide Werte sind null oder negativ: die Ente hängt in beiden Gerippen unten rechts und
    /// wird von dort nach links und nach oben geschoben.
    ///
    /// **Begrenzt, und zwar immer.** Der Zug kommt vom Finger und kennt die Fläche nicht;
    /// ohne diese Grenze ließe sich die Ente halb aus dem Bild ziehen. Dieselbe Grenze fängt
    /// den gedrehten Bildschirm und das geteilte Fenster am iPad auf: wird die Fläche kleiner,
    /// rückt die Ente nach, statt hinter der Kante zu verschwinden.
    public static func versatz(_ stelle: Stelle, zug: Punkt = .ursprung, in flaeche: Flaeche)
        -> Punkt
    {
        // Wie weit es überhaupt zu schieben gibt. Auf einer Fläche, die schmaler ist als die
        // Ente - vor der ersten Messung ist sie null -, gibt es nichts zu schieben.
        let weiteX = max(0, flaeche.breite - kantenlaenge)
        let weiteY = max(0, flaeche.hoehe - kantenlaenge)
        let grundX: Double = stelle.seite == .links ? -weiteX : 0
        let grundY: Double
        switch stelle.hoehe {
        case .oben: grundY = -weiteY
        case .mitte: grundY = -weiteY / 2
        case .unten: grundY = 0
        }
        return Punkt(
            x: min(0, max(-weiteX, grundX + zug.x)),
            y: min(0, max(-weiteY, grundY + zug.y))
        )
    }

    // MARK: - Einrasten

    /// Welche Stelle aus einem Zug folgt: die, deren Mittelpunkt dem losgelassenen Finger am
    /// nächsten liegt.
    ///
    /// **Eingerastet und nicht frei stehen gelassen.** Eine Ente, die bleibt, wo der Finger
    /// aufhört, steht nach dem Drehen oder im geteilten Fenster irgendwo – und auf einer
    /// Seitenmitte verdeckt sie das, was man lesen wollte. Das Einrasten ist darum keine
    /// Bequemlichkeit, sondern die Zusage, dass sie nachher wieder an einer bekannten Stelle
    /// steht.
    ///
    /// Gerechnet wird mit dem begrenzten Versatz, also mit dem, was man sieht: wer die Ente
    /// gegen die linke Kante zieht und dort noch weiter schiebt, rastet links ein und nicht
    /// wieder rechts.
    public static func einrasten(von stelle: Stelle, zug: Punkt, in flaeche: Flaeche) -> Stelle {
        let v = versatz(stelle, zug: zug, in: flaeche)
        let ecke = mittelpunkt(.untenRechts, in: flaeche)
        let jetzt = Punkt(x: ecke.x + v.x, y: ecke.y + v.y)
        var beste = stelle
        var abstand = Double.infinity
        for k in Stelle.allCases {
            let m = mittelpunkt(k, in: flaeche)
            let d = (m.x - jetzt.x) * (m.x - jetzt.x) + (m.y - jetzt.y) * (m.y - jetzt.y)
            if d < abstand {
                abstand = d
                beste = k
            }
        }
        return beste
    }

    // MARK: - Merken

    /// Unter welchem Schlüssel die Stelle im Gerät steht.
    ///
    /// **`UserDefaults` und nicht iCloud.** Die Stelle gilt für ein Gerät: am Telefon liegt die
    /// Ente dort, wo der Daumen hinkommt, an der Wandanzeige im Querformat woanders. Dieselbe
    /// Wahl wie beim weggetippten Mitteilungshinweis (``Startseitenhinweis/merker``) und beim
    /// weggeklickten Update – und dieselbe Schreibweise `dch-…`, damit eine Fehlersuche alle
    /// Merker unter einem Wort findet.
    public static let merker = "dch-ente-stelle"

    /// Was aus dem Gemerkten wird – und was aus Unsinn.
    ///
    /// **Eine fremde oder leere Zeichenkette ist die Vorgabe und kein Absturz.** Hier steht ein
    /// Wort aus einer Datei, die älter sein kann als diese Fassung der App: eine Stelle, die es
    /// einmal gab, ein abgeschnittener Wert, oder gar nichts, weil noch niemand gezogen hat. In
    /// allen drei Fällen ist die Antwort dieselbe und die einzige, die nie falsch sitzt: unten
    /// rechts, wo die Ente seit immer stand.
    public static func gelesen(_ roh: String) -> Stelle {
        Stelle(rawValue: roh) ?? vorgabe
    }

    /// Was von einer Stelle im Gerät steht. Lesbar, damit `defaults read` eine Auskunft gibt
    /// und keine Zahl.
    public static func gemerkt(_ stelle: Stelle) -> String { stelle.rawValue }
}
