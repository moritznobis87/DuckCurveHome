import Foundation

/// Was die Zeichnung des Schaltbilds rechnet, bevor sie zeichnet: der Text im Kästchen und der
/// Weg einer Leitung.
///
/// Übersetzt aus `apps/web/src/components/regelkreis/Karte.tsx` (`teile`, `kuerze`, `stapel`,
/// `pfad`, `ersatz`), mit denselben Zahlen. Es steht im Kern und nicht in der Ansicht, weil es
/// der Teil ist, an dem Dashboard und App auseinanderlaufen können, ohne dass es jemand sieht:
/// ein Name, der hier nach zwölf Zeichen abbricht und dort nach vierzehn. Hier lässt es sich
/// auf dem Prüfrechner festhalten.
///
/// **Gezählt wird wie im Browser, in UTF-16-Einheiten.** `"Q̇ab".length` ist dort 4 und nicht 3.
/// Wer hier Zeichen zählte, bräche an anderer Stelle um als das Dashboard.
extension Schaltbild {
    // MARK: - Text

    private static func laenge(_ text: String) -> Int { text.utf16.count }

    private static func anfang(_ text: String, _ n: Int) -> String {
        String(decoding: Array(text.utf16.prefix(max(0, n))), as: UTF16.self)
    }

    /// Umbruch an Wortgrenzen auf eine Zeichenzahl, die in die Breite passt (`Karte.tsx`, `teile`).
    public static func teile(_ text: String, max: Int) -> [String] {
        var aus: [String] = []
        var zeile = ""
        for wort in text.components(separatedBy: " ") {
            let versuch = (zeile + " " + wort).trimmingCharacters(in: .whitespaces)
            if laenge(versuch) > max, !zeile.isEmpty {
                aus.append(zeile)
                zeile = wort
            } else {
                zeile = versuch
            }
        }
        if !zeile.isEmpty { aus.append(zeile) }
        return aus
    }

    /// Auf eine Breite kürzen. Abgeschnitten mit Auslassung ist besser als über den Rand hinaus
    /// (`Karte.tsx`, `kuerze`).
    public static func kuerze(_ text: String, breite: Double, proZeichen: Double) -> String {
        let hoechstens = Swift.max(4, Int((breite / proZeichen).rounded(.down)))
        guard laenge(text) > hoechstens else { return text }
        var kurz = anfang(text, hoechstens - 1)
        while let letztes = kurz.last, letztes.isWhitespace { kurz.removeLast() }
        return kurz + "…"
    }

    /// Welche Schrift eine Zeile im Kästchen trägt.
    public enum Zeilenart: Sendable, Hashable {
        case name, nameKlein, formel, wert
    }

    /// Eine Zeile im Textstapel eines Kästchens, mit ihrer Grundlinie auf der Karte.
    public struct Zeile: Sendable, Hashable {
        public var text: String
        public var art: Zeilenart
        public var y: Double
        /// Nur bei einem Parameterwert: woher seine Zahl stammt. Das ist seine Farbe.
        public var herkunft: ParameterAnsichtHerkunftWahl?

        public init(text: String, art: Zeilenart, y: Double, herkunft: ParameterAnsichtHerkunftWahl? = nil) {
            self.text = text
            self.art = art
            self.y = y
            self.herkunft = herkunft
        }
    }

    /// Der Wert eines Parameters mit seiner Einheit, wie er im Kästchen steht.
    public static func wert(_ p: ParameterAnsicht) -> String {
        let zahl = Formate.zahl(p.wert, stellen: p.stellen)
        return p.einheit == "—" ? zahl : "\(zahl) \(p.einheit)"
    }

    /// Der Textstapel eines Kästchens: Name, Übertragungsglied, Parameter, von oben nach unten.
    /// Was nicht mehr hineinpasst, wird weggelassen (`Karte.tsx`, `stapel`).
    ///
    /// - Parameters:
    ///   - stoer: Der Block ist eine Störgröße: ein flaches Kästchen mit kleinem Namen.
    ///   - klein: Das Kästchen ist höchstens 44 hoch.
    ///   - oben: Oben rechts steht eine Marke (Lernmarke oder Signalmarke); der Name weicht ihr aus.
    ///   - rechts: Breite, die das Kennbild rechts im Kästchen belegt.
    ///   - mitFormel: Die Kurzformel wird gezeigt. Mit Kennbild steht sie nicht da.
    public static func stapel(
        block: BlockAnsicht, rect r: Rechteck, parameter: [ParameterAnsicht],
        stoer: Bool, klein: Bool, oben: Bool, rechts: Double, mitFormel: Bool
    ) -> [Zeile] {
        var aus: [Zeile] = []
        let unten = r.y + r.h - ((block.kreis ?? "").isEmpty && (block.marke ?? "").isEmpty ? 6 : 20)
        let ersteBreite = r.w - (oben ? 34 : 20) - rechts
        var y = r.y + (stoer ? 16 : 19)
        let namen: [String] = stoer
            ? [kuerze(block.name, breite: ersteBreite, proZeichen: 6.2)]
            : Array(teile(block.name, max: Int((ersteBreite / 6.4).rounded(.down))).prefix(2))
        for (i, n) in namen.enumerated() {
            let breite = i == 0 ? ersteBreite : r.w - 20 - rechts
            aus.append(Zeile(text: kuerze(n, breite: breite, proZeichen: 6.4), art: stoer ? .nameKlein : .name, y: y))
            y += 14
        }
        if !block.kurz.isEmpty, mitFormel {
            let breit = r.w - 20 - rechts
            let formeln: [String] = klein || stoer
                ? [kuerze(block.kurz, breite: breit, proZeichen: 6.1)]
                : Array(teile(block.kurz, max: Int((breit / 6.1).rounded(.down))).prefix(2))
            y += 3
            for z in formeln {
                if y > unten { break }
                aus.append(Zeile(text: z, art: .formel, y: y))
                y += 12
            }
        }
        if !parameter.isEmpty {
            y += 3
            for p in parameter {
                if y > unten { break }
                aus.append(Zeile(text: "\(p.symbol) = \(wert(p))", art: .wert, y: y, herkunft: p.herkunft))
                y += 12.5
            }
        }
        return aus
    }

    // MARK: - Leitungen

    /// Ein Schritt beim Zeichnen einer Leitung.
    public enum Schritt: Sendable, Hashable {
        case beginn(Punkt)
        case linie(Punkt)
        /// Der Sprungbogen über eine kreuzende Leitung: ein Halbkreis vom Radius 6 bis `ende`.
        case bogen(ende: Punkt, imUhrzeigersinn: Bool)
    }

    /// Der Radius des Sprungbogens an der einen Kreuzung der Karte.
    public static let bogenradius: Double = 6

    /// Eine Leitung als Folge von Schritten, mit dem Sprungbogen an ihrer Kreuzung
    /// (`Karte.tsx`, `pfad`). Leer bei weniger als zwei Punkten: dann wird nichts gezeichnet.
    public static func schritte(_ punkte: [Punkt], bogen: Punkt?) -> [Schritt] {
        guard punkte.count >= 2 else { return [] }
        var aus: [Schritt] = [.beginn(punkte[0])]
        for i in 1..<punkte.count {
            let p = punkte[i]
            let v = punkte[i - 1]
            if let bogen, v.x == p.x, p.x == bogen.x, Swift.min(v.y, p.y) < bogen.y, bogen.y < Swift.max(v.y, p.y) {
                let richtung: Double = p.y > v.y ? 1 : -1
                aus.append(.linie(Punkt(x: p.x, y: bogen.y - bogenradius * richtung)))
                aus.append(.bogen(ende: Punkt(x: p.x, y: bogen.y + bogenradius * richtung), imUhrzeigersinn: richtung > 0))
            }
            aus.append(.linie(p))
        }
        return aus
    }

    /// Ein Ersatzweg für eine Leitung ohne Eintrag: von Rand zu Rand, damit sie sichtbar fehlt
    /// (`Karte.tsx`, `ersatz`).
    public static func ersatzweg(von a: Rechteck, nach b: Rechteck) -> [Punkt] {
        let von = Punkt(x: a.x + a.w, y: a.y + a.h / 2)
        let nach = Punkt(x: b.x, y: b.y + b.h / 2)
        let mitte = (von.x + nach.x) / 2
        return [von, Punkt(x: mitte, y: von.y), Punkt(x: mitte, y: nach.y), nach]
    }

    /// Die Punkte einer Leitung des Dienstes: ihr Weg aus der Zeichnung, sonst der Ersatzweg
    /// zwischen den Rechtecken ihrer Enden. `nil`, wenn einem Ende das Rechteck fehlt.
    public static func weg(
        von: String, nach: String, rechtecke: [String: Rechteck]
    ) -> (punkte: [Punkt], bogen: Punkt?)? {
        if let weg = Schaltbilddaten.wege[kante(von: von, nach: nach)] {
            return (weg.punkte, weg.bogen)
        }
        guard let a = rechtecke[von], let b = rechtecke[nach] else { return nil }
        return (ersatzweg(von: a, nach: b), nil)
    }

    /// Das Rechteck jedes Blocks des Dienstes: sein Platz aus der Zeichnung, sonst ein Notplatz
    /// in der Reihe unter der Karte, in der Reihenfolge des Dienstes.
    public static func rechtecke(bloecke: [String]) -> [String: Rechteck] {
        var aus: [String: Rechteck] = [:]
        var ohnePlatz = 0
        for id in bloecke {
            if let platz = Schaltbilddaten.plaetze[id] {
                aus[id] = platz.rect
            } else {
                aus[id] = notplatz(ohnePlatz)
                ohnePlatz += 1
            }
        }
        return aus
    }

    /// Die Blöcke des Dienstes, für die die Zeichnung keinen Platz kennt. Die Bildunterschrift
    /// nennt sie beim Namen.
    public static func ohnePlatz(bloecke: [String]) -> [String] {
        bloecke.filter { Schaltbilddaten.plaetze[$0] == nil }
    }

    /// Die Bildunterschrift der Karte, derselbe Wortlaut wie im Dashboard (`Karte.tsx`).
    public static func bildunterschrift(ohnePlatz namen: [String]) -> String {
        let fest = "Die Kaskade von außen nach innen: ökonomische Führung, Speicherladung, "
            + "Erzeuger, Vorlauftemperatur, Einzelraum. Störgrößen stehen am Ort ihrer Wirkung und "
            + "werden dort wiederholt, wo sie mehrfach angreifen (↗)."
        return namen.isEmpty ? fest : fest + " Ohne Platz in der Zeichnung: \(namen.joined(separator: ", "))."
    }
}
