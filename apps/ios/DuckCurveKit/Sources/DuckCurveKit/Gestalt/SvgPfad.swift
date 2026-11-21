import Foundation

/// Ein Stueck eines gezeichneten Pfades.
///
/// Das ist absichtlich kein `CGPath`: `CoreGraphics` gibt es unter Linux nicht, und dieser Typ
/// soll hier geprueft werden koennen. Die Oberflaeche rechnet ihn in zwei Dutzend Zeilen in einen
/// SwiftUI-`Path` um (siehe `Gestalt/Zeichen.swift`).
public enum Pfadstueck: Sendable, Hashable {
    case anfang(Punkt)
    case linie(Punkt)
    /// Eine kubische Bezier-Kurve: zwei Griffe und ein Ziel.
    case kurve(griff1: Punkt, griff2: Punkt, nach: Punkt)
    /// Eine quadratische Bezier-Kurve: ein Griff und ein Ziel.
    case kurveKurz(griff: Punkt, nach: Punkt)
    case schluss
}

/// Ein Punkt in der Zeichenebene.
public struct Punkt: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static func + (a: Punkt, b: Punkt) -> Punkt { Punkt(a.x + b.x, a.y + b.y) }
    public static func - (a: Punkt, b: Punkt) -> Punkt { Punkt(a.x - b.x, a.y - b.y) }
    public static func * (p: Punkt, f: Double) -> Punkt { Punkt(p.x * f, p.y * f) }

    /// Der Punkt, auf ein neues Rechteck umgerechnet.
    public func skaliert(von raster: Double, auf kante: Double) -> Punkt {
        Punkt(x / raster * kante, y / raster * kante)
    }
}

/// Der Leser fuer SVG-Pfadangaben (`d="M 2 15 C ..."`).
///
/// **Warum das hier steht und nicht in der Oberflaeche.** Das Dashboard zeichnet seine Zeichen,
/// das Anlagenschema, die Tagesuhr und das Flussbild als SVG - zusammen gut tausend Zeilen
/// handgesetzter Pfade, die seit Monaten so aussehen, wie sie aussehen sollen. Sie in SwiftUI
/// nachzuzeichnen hiesse, sie neu zu erfinden, und zwar ohne sie sehen zu koennen. Mit diesem
/// Leser werden dieselben Pfadangaben uebernommen: was im Dashboard richtig aussah, sieht in der
/// App gleich aus, und wer eine Zeichnung aendert, aendert sie an einer Stelle.
///
/// Umgesetzt ist der ganze Befehlssatz fuer Pfade: `M`, `L`, `H`, `V`, `C`, `S`, `Q`, `T`, `A`
/// und `Z`, jeweils absolut und relativ. Der Bogen (`A`) wird dabei in Bezier-Kurven zerlegt -
/// siehe `Bogen` am Ende dieser Datei. Dass er dazugehoert, hat der Test gezeigt: zehn der 25
/// Zeichen benutzen ihn, weil ein Viertelkreis sich von Hand so am bequemsten schreibt.
public enum SvgPfad {
    public enum Fehler: Error, Sendable, Equatable {
        case unbekannterBefehl(Character)
        case zahlFehlt(String)
    }

    /// Eine Pfadangabe in Stuecke zerlegen.
    public static func lies(_ d: String) throws -> [Pfadstueck] {
        var leser = Zahlenleser(d)
        var stuecke: [Pfadstueck] = []
        /// Wo der Stift steht.
        var stift = Punkt(0, 0)
        /// Wo der letzte Unterpfad begann - dorthin fuehrt `Z`.
        var anfang = Punkt(0, 0)
        /// Der gespiegelte Griff fuer `S` und `T`.
        var letzterGriff: Punkt?
        var letzterBefehl: Character = " "

        while let befehl = leser.naechsterBefehl() {
            // Eine Befehlsfolge darf den Buchstaben weglassen, wenn er sich wiederholt:
            // „M 1 2 3 4" ist „M 1 2 L 3 4". Der Zahlenleser gibt dann `nil` zurueck, und hier
            // wird der vorige Befehl weitergeführt.
            let b = befehl == "\0" ? wiederholung(von: letzterBefehl) : befehl
            let relativ = b.isLowercase
            switch Character(b.uppercased()) {
            case "M":
                let p = try leser.punkt()
                stift = relativ ? stift + p : p
                anfang = stift
                stuecke.append(.anfang(stift))
                letzterGriff = nil
            case "L":
                let p = try leser.punkt()
                stift = relativ ? stift + p : p
                stuecke.append(.linie(stift))
                letzterGriff = nil
            case "H":
                let x = try leser.zahl()
                stift = Punkt(relativ ? stift.x + x : x, stift.y)
                stuecke.append(.linie(stift))
                letzterGriff = nil
            case "V":
                let y = try leser.zahl()
                stift = Punkt(stift.x, relativ ? stift.y + y : y)
                stuecke.append(.linie(stift))
                letzterGriff = nil
            case "C":
                let g1r = try leser.punkt()
                let g2r = try leser.punkt()
                let zr = try leser.punkt()
                let g1 = relativ ? stift + g1r : g1r
                let g2 = relativ ? stift + g2r : g2r
                let z = relativ ? stift + zr : zr
                stuecke.append(.kurve(griff1: g1, griff2: g2, nach: z))
                letzterGriff = g2
                stift = z
            case "S":
                let g2r = try leser.punkt()
                let zr = try leser.punkt()
                let g2 = relativ ? stift + g2r : g2r
                let z = relativ ? stift + zr : zr
                // Der erste Griff ist die Spiegelung des letzten am Stift. Ohne vorige Kurve
                // liegt er auf dem Stift - so steht es in der Spezifikation.
                let g1 = letzterGriff.map { stift * 2 - $0 } ?? stift
                stuecke.append(.kurve(griff1: g1, griff2: g2, nach: z))
                letzterGriff = g2
                stift = z
            case "Q":
                let gr = try leser.punkt()
                let zr = try leser.punkt()
                let g = relativ ? stift + gr : gr
                let z = relativ ? stift + zr : zr
                stuecke.append(.kurveKurz(griff: g, nach: z))
                letzterGriff = g
                stift = z
            case "T":
                let zr = try leser.punkt()
                let z = relativ ? stift + zr : zr
                let g = letzterGriff.map { stift * 2 - $0 } ?? stift
                stuecke.append(.kurveKurz(griff: g, nach: z))
                letzterGriff = g
                stift = z
            case "Z":
                stuecke.append(.schluss)
                stift = anfang
                letzterGriff = nil
            case "A":
                let rx = try leser.zahl()
                let ry = try leser.zahl()
                let drehung = try leser.zahl()
                let grosserBogen = try leser.zahl() != 0
                let imUhrzeigersinn = try leser.zahl() != 0
                let zielRoh = try leser.punkt()
                let ziel = relativ ? stift + zielRoh : zielRoh
                stuecke.append(
                    contentsOf: Bogen.alsKurven(
                        von: stift, nach: ziel, rx: rx, ry: ry, drehungGrad: drehung,
                        grosserBogen: grosserBogen, imUhrzeigersinn: imUhrzeigersinn
                    )
                )
                stift = ziel
                letzterGriff = nil
            default:
                throw Fehler.unbekannterBefehl(b)
            }
            letzterBefehl = b
        }
        return stuecke
    }

    /// Welcher Befehl gilt, wenn der Buchstabe weggelassen wurde.
    ///
    /// Nach einem `M` folgt `L`, nach einem `m` ein `l`; alle uebrigen wiederholen sich selbst.
    /// Das ist die Regel der Spezifikation und nicht Bequemlichkeit: `M 1 2 3 4` ist eine Linie
    /// und nicht ein zweites Anheben des Stifts.
    private static func wiederholung(von letzter: Character) -> Character {
        switch letzter {
        case "M": return "L"
        case "m": return "l"
        default: return letzter
        }
    }

    /// Der umschliessende Rahmen eines Pfades - fuer Zeichnungen, deren Raster nicht bekannt ist.
    ///
    /// Gerechnet wird ueber die Stuetzpunkte, nicht ueber die Kurven selbst. Eine Bezier-Kurve
    /// bleibt innerhalb ihrer Griffe, der Rahmen ist also nie zu klein - hoechstens etwas zu
    /// gross, und das ist die ungefaehrlichere Seite.
    public static func rahmen(_ stuecke: [Pfadstueck]) -> (links: Double, oben: Double, rechts: Double, unten: Double)? {
        var punkte: [Punkt] = []
        for s in stuecke {
            switch s {
            case .anfang(let p), .linie(let p): punkte.append(p)
            case .kurve(let g1, let g2, let p): punkte.append(contentsOf: [g1, g2, p])
            case .kurveKurz(let g, let p): punkte.append(contentsOf: [g, p])
            case .schluss: break
            }
        }
        guard let erster = punkte.first else { return nil }
        var links = erster.x, rechts = erster.x, oben = erster.y, unten = erster.y
        for p in punkte {
            links = min(links, p.x)
            rechts = max(rechts, p.x)
            oben = min(oben, p.y)
            unten = max(unten, p.y)
        }
        return (links, oben, rechts, unten)
    }
}

/// Liest Befehle und Zahlen aus einer SVG-Pfadangabe.
private struct Zahlenleser {
    private let z: [Character]
    private var i = 0

    init(_ s: String) {
        z = Array(s)
    }

    /// Der naechste Befehlsbuchstabe - oder `\0`, wenn eine Zahl folgt (Befehlswiederholung),
    /// oder `nil` am Ende.
    mutating func naechsterBefehl() -> Character? {
        ueberspringeTrenner()
        guard i < z.count else { return nil }
        let c = z[i]
        if c.isLetter {
            i += 1
            return c
        }
        // Eine Zahl ohne Buchstaben davor: der vorige Befehl gilt weiter.
        return "\0"
    }

    mutating func punkt() throws -> Punkt {
        let x = try zahl()
        let y = try zahl()
        return Punkt(x, y)
    }

    mutating func zahl() throws -> Double {
        ueberspringeTrenner()
        let anfang = i
        if i < z.count, z[i] == "+" || z[i] == "-" { i += 1 }
        var zifferGesehen = false
        while i < z.count, z[i].isNumber {
            i += 1
            zifferGesehen = true
        }
        if i < z.count, z[i] == "." {
            i += 1
            while i < z.count, z[i].isNumber {
                i += 1
                zifferGesehen = true
            }
        }
        // Zehnerpotenz: `1e-3` kommt in erzeugten Pfaden vor.
        if zifferGesehen, i < z.count, z[i] == "e" || z[i] == "E" {
            let merk = i
            i += 1
            if i < z.count, z[i] == "+" || z[i] == "-" { i += 1 }
            if i < z.count, z[i].isNumber {
                while i < z.count, z[i].isNumber { i += 1 }
            } else {
                i = merk  // kein Exponent, sondern der naechste Befehl
            }
        }
        guard zifferGesehen, let d = Double(String(z[anfang..<i])) else {
            throw SvgPfad.Fehler.zahlFehlt(String(z[anfang..<min(anfang + 12, z.count)]))
        }
        return d
    }

    /// Leerzeichen und Kommata zwischen den Zahlen.
    private mutating func ueberspringeTrenner() {
        while i < z.count, z[i] == " " || z[i] == "," || z[i] == "\n" || z[i] == "\t" || z[i] == "\r" {
            i += 1
        }
    }
}

/// Ein elliptischer Bogen, in kubische Bezier-Kurven zerlegt.
///
/// **Warum das sein muss.** Zehn der 25 Zeichen des Dashboards benutzen `A`: der Mond, der Euro,
/// die Lampe, die Tasse, das Thermometer, die Tuer, das Auto, der Ofen. Ein Bogen ist in SVG die
/// bequemste Art, einen Viertelkreis zu schreiben, und wer von Hand zeichnet, nimmt sie. Ohne
/// `A` bleiben diese Zeichen leer - und eine Bereichsleiste mit fuenf Zeichen, von denen drei
/// fehlen, ist keine.
///
/// **Warum zerlegt und nicht gezeichnet.** SwiftUI kann einen Bogen zeichnen (`Path.addArc`),
/// aber nur einen Kreisbogen um einen Mittelpunkt - nicht die Form, die SVG beschreibt: „von hier
/// nach dort, mit diesen Radien, auf dem laengeren oder kuerzeren Weg". Die Umrechnung vom einen
/// in das andere ist die eigentliche Arbeit, und wenn sie schon getan ist, sind Bezier-Kurven das
/// einfachere Ziel: sie brauchen keine Sonderbehandlung in `Pfadstueck` und keine
/// Fallunterscheidung beim Zeichnen.
///
/// Umgesetzt sind die Anmerkungen zur Implementierung der SVG-Spezifikation, Abschnitt F.6:
/// Umrechnung von der Endpunkt- in die Mittelpunktform (F.6.5), Korrektur zu kleiner Radien
/// (F.6.6) und Zerlegung in Stuecke von hoechstens 90 Grad.
enum Bogen {
    static func alsKurven(
        von: Punkt, nach: Punkt, rx rxRoh: Double, ry ryRoh: Double, drehungGrad: Double,
        grosserBogen: Bool, imUhrzeigersinn: Bool
    ) -> [Pfadstueck] {
        // Gleiche Punkte: kein Bogen. So steht es in der Spezifikation - nicht eine Linie, nichts.
        if von == nach { return [] }
        // Ein Radius von null macht aus dem Bogen eine Linie (Spezifikation F.6.2).
        var rx = abs(rxRoh)
        var ry = abs(ryRoh)
        if rx == 0 || ry == 0 { return [.linie(nach)] }

        let phi = drehungGrad * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // Schritt 1: in das gedrehte, auf die Radien bezogene Koordinatensystem.
        let dx2 = (von.x - nach.x) / 2
        let dy2 = (von.y - nach.y) / 2
        let x1s = cosPhi * dx2 + sinPhi * dy2
        let y1s = -sinPhi * dx2 + cosPhi * dy2

        // Schritt 2: zu kleine Radien aufziehen, bis der Bogen ueberhaupt passt (F.6.6). Ohne das
        // ergibt die Wurzel unten eine negative Zahl, und aus dem Zeichen wird ein NaN-Fleck.
        let zuKlein = (x1s * x1s) / (rx * rx) + (y1s * y1s) / (ry * ry)
        if zuKlein > 1 {
            let f = sqrt(zuKlein)
            rx *= f
            ry *= f
        }

        // Schritt 3: der Mittelpunkt im gedrehten System.
        let zaehler = max(0, rx * rx * ry * ry - rx * rx * y1s * y1s - ry * ry * x1s * x1s)
        let nenner = rx * rx * y1s * y1s + ry * ry * x1s * x1s
        var faktor = nenner > 0 ? sqrt(zaehler / nenner) : 0
        if grosserBogen == imUhrzeigersinn { faktor = -faktor }
        let cxs = faktor * rx * y1s / ry
        let cys = -faktor * ry * x1s / rx

        // Schritt 4: Anfangswinkel und Ueberstrichung.
        let startWinkel = atan2((y1s - cys) / ry, (x1s - cxs) / rx)
        let endWinkel = atan2((-y1s - cys) / ry, (-x1s - cxs) / rx)
        var spanne = endWinkel - startWinkel
        if !imUhrzeigersinn, spanne > 0 {
            spanne -= 2 * .pi
        } else if imUhrzeigersinn, spanne < 0 {
            spanne += 2 * .pi
        }

        // Der Mittelpunkt zurueck im Bild.
        let mx = (von.x + nach.x) / 2
        let my = (von.y + nach.y) / 2
        let cx = cosPhi * cxs - sinPhi * cys + mx
        let cy = sinPhi * cxs + cosPhi * cys + my

        // Schritt 5: in Stuecke von hoechstens 90 Grad. Eine Bezier-Kurve nähert einen
        // Viertelkreis auf etwa ein Zehntausendstel des Radius an; ein halber Kreis in einem
        // Stueck waere sichtbar zu flach.
        let stuecke = max(1, Int(ceil(abs(spanne) / (.pi / 2))))
        let schritt = spanne / Double(stuecke)
        // Das Griffmass fuer einen Bogen dieser Oeffnung.
        let griffmass = 4.0 / 3.0 * tan(schritt / 4)

        func aufDemBogen(_ winkel: Double) -> (punkt: Punkt, ableitung: Punkt) {
            let cosW = cos(winkel)
            let sinW = sin(winkel)
            let p = Punkt(
                cx + rx * cosPhi * cosW - ry * sinPhi * sinW,
                cy + rx * sinPhi * cosW + ry * cosPhi * sinW
            )
            // Die Richtung, in die der Bogen hier laeuft - daraus werden die Griffe.
            let a = Punkt(
                -rx * cosPhi * sinW - ry * sinPhi * cosW,
                -rx * sinPhi * sinW + ry * cosPhi * cosW
            )
            return (p, a)
        }

        var aus: [Pfadstueck] = []
        var winkel = startWinkel
        var (vonPunkt, vonAbleitung) = aufDemBogen(winkel)
        for _ in 0..<stuecke {
            let bis = winkel + schritt
            let (bisPunkt, bisAbleitung) = aufDemBogen(bis)
            aus.append(
                .kurve(
                    griff1: vonPunkt + vonAbleitung * griffmass,
                    griff2: bisPunkt - bisAbleitung * griffmass,
                    nach: bisPunkt
                )
            )
            winkel = bis
            vonPunkt = bisPunkt
            vonAbleitung = bisAbleitung
        }
        // Der letzte Punkt muss genau das Ziel sein und nicht fast - sonst klafft die Form.
        if case .kurve(let g1, let g2, _) = aus.last, !aus.isEmpty {
            aus[aus.count - 1] = .kurve(griff1: g1, griff2: g2, nach: nach)
        }
        return aus
    }
}
