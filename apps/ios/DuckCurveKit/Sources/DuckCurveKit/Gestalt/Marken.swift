import Foundation

/// Die Design-Tokens, eine Quelle.
///
/// Uebersetzt aus `apps/web/src/styles/tokens.css`, mit den Begruendungen von dort - sie sind
/// keine Verzierung, sondern Auflagen an jede Grafik, die diese Farben benutzt.
///
/// **Warum hier Zahlen und keine `Color`.** Dieses Paket kennt kein SwiftUI, damit es unter Linux
/// baut und getestet werden kann. Die Umsetzung nach `Color` steht in
/// `../DuckCurveHome/Gestalt/Farben.swift` und ist eine Zeile je Marke. Der Vorteil: die
/// Palettenpruefung (`MarkenTests`) laeuft hier mit und faellt auf, wenn jemand eine Serienfarbe
/// aendert, ohne den Abstand zu ihren Nachbarn nachzurechnen.
public enum Marken {
    // MARK: - Marke, identisch zur Website

    public static let petrol = Farbwert(0x0F2E3D)
    public static let deep = Farbwert(0x082431)
    public static let amber = Farbwert(0xF2A900)
    public static let amberWeich = Farbwert(0xFFD778)
    public static let mist = Farbwert(0x7FA3B3)
    public static let papier = Farbwert(0xFFFFFF)
    public static let wolke = Farbwert(0xF1F5F5)
    public static let tinte = Farbwert(0x102E3C)

    // MARK: - Dunkle Oberflaechen

    public static let grund = deep
    public static let flaeche1 = Farbwert(0x0F2E3D)
    public static let flaeche2 = Farbwert(0x123544)
    public static let flaeche3 = Farbwert(0x173F50)
    public static let flaecheGlas = Farbwert(0x082431, deckung: 0.38)
    public static let linie1 = Farbwert(0xFFFFFF, deckung: 0.10)
    public static let linie2 = Farbwert(0xFFFFFF, deckung: 0.17)
    public static let rasterlinie = Farbwert(0xFFFFFF, deckung: 0.09)

    /// Der Verlauf des Hintergrunds, 130 Grad wie im Dashboard.
    public static let grundVerlauf: [(farbe: Farbwert, stelle: Double)] = [
        (deep, 0.0), (petrol, 0.62), (Farbwert(0x153C4C), 1.0),
    ]

    // MARK: - Text auf Dunkel

    public static let text1 = Farbwert(0xFFFFFF, deckung: 0.92)
    public static let text2 = Farbwert(0xFFFFFF, deckung: 0.72)
    public static let text3 = Farbwert(0xFFFFFF, deckung: 0.48)
    public static let textKicker = mist

    // MARK: - Energie-Semantik (Serienfarben, auf flaeche2 geprueft)

    public static let pv = amber
    public static let netzBezug = mist
    public static let netzEinspeisung = amberWeich
    public static let batterie = Farbwert(0x4F7B88)

    /// Warmes Terrakotta statt Fastweiss: Weiss ist im Energiefluss dem Haus vorbehalten (Knoten
    /// der Summe). Deutlich abgesetzt von `amber` (PV) und von `alarm`, damit die Waermepumpe
    /// nicht wie eine Stoerung aussieht.
    public static let waermepumpe = Farbwert(0xE0966B)

    /// Pelletofen: die zweite Waermequelle am selben Puffer, steht also direkt neben
    /// `waermepumpe` und muss von ihm unterscheidbar sein. Der warme Bereich ist eng: gegen
    /// `waermepumpe`, `amber` und `alarm` gleichzeitig zu bestehen, gelingt nur hier. Geprueft auf
    /// `flaeche2`: ΔE 15,3 zu `waermepumpe`, 20,7 zu `amber`, 18,3 zu `batterie`, jeweils ueber
    /// der Schwelle von 15.
    ///
    /// **Zwei Auflagen.** Erstens liegt der Kontrast zur Flaeche bei 2,99:1 und damit knapp unter
    /// 3:1; die Farbe darf deshalb nie allein tragen, es gehoert immer eine sichtbare
    /// Beschriftung daneben. Zweitens ist der Abstand zu `alarm` und `netzBezug` nur ΔE 9,3: Ofen
    /// und Netzbezug duerfen nicht ohne Zweitkodierung in dieselbe Grafik.
    public static let ofen = Farbwert(0xB5651D)

    /// Der Hausverbrauch als Summe, nicht als Quelle - und das Heizen, denn es ist der Verlust
    /// der Huelle. Eigene Farbe, weil er in der Pruefansicht neben PV, Netz und Speicher steht;
    /// dort scheitert das Sandfarbene des Haushalts an der PV (ΔE 9,3). Geprueft: schlechtestes
    /// Paar dieser vier ΔE 18,5 normal / 15,1 CVD. Entspricht `house` in palette.ts.
    public static let haus = Farbwert(0xCFD8DC)

    /// Das Warmwasser im gestapelten Waermebedarf. Das Heizen nimmt die Farbe des Hauses, das
    /// Warmwasser bekommt sein eigenes Blau: ΔE 21,9 normal / 18,1 protan gegen `flaeche2`. Es
    /// ist das einzige **gestapelte** Paar der Fahrplanseite und damit das einzige, an dem diese
    /// Liste streng sein muss. Entspricht `dhw` in palette.ts.
    public static let warmwasser = Farbwert(0x4AA3C7)

    /// Der Pufferinhalt: eine einzelne Linie in einer eigenen Flaeche. Ihr naechster Nachbar auf
    /// der Fahrplanseite ist der Strompreis drei Flaechen hoeher, ΔE 14,6 normal / 13,7 deutan -
    /// knapp unter der Grenze 15, die hier sonst gilt. Zulaessig, weil die beiden nie im selben
    /// Gitter stehen: eigene Achse in kWh, eigener Titel, eine Luecke dazwischen.
    /// Entspricht `puffer` in palette.ts.
    public static let puffer = Farbwert(0x8FBF6B)

    public static let wallbox = Farbwert(0x5C8FA3)
    public static let preis = mist
    public static let last = Farbwert(0xFFFFFF, deckung: 0.62)

    // MARK: - Status

    public static let gut = mist
    public static let achtung = amber
    public static let alarm = Farbwert(0xE0533D)

    // MARK: - Thermische Skala

    /// Abweichung vom Raumsollwert, fuenfstufig und zweiseitig. Null ist nicht farblos, sondern
    /// gedeckt: ein Raum auf Sollwert soll als Zustand zu sehen sein, nicht als Luecke. Die
    /// Nachbarstufen liegen in ihrer Helligkeit ueber der Unterscheidungsschwelle, und die beiden
    /// Enden sind auch ohne Farbwahrnehmung zu trennen.
    public static let abwKalt2 = Farbwert(0x6FD0F2)
    public static let abwKalt1 = Farbwert(0x3F88A8)
    public static let abwNull = Farbwert(0x3A5560)
    public static let abwWarm1 = Farbwert(0xA8781F)
    public static let abwWarm2 = Farbwert(0xFFC247)

    /// Ein offenes Ventil. Nicht amber: die Farbe steht in dieser Anwendung fuer Preis und Sonne,
    /// und ein offener Heizkreis ist weder das eine noch das andere.
    public static let ventilOffen = Farbwert(0xCFD8DC)

    /// Die Waermeskala der Jahreskarte und des Puffers, kalt nach heiss.
    public static let waerme: [Farbwert] = [
        Farbwert(0x1F4C66), Farbwert(0x7FA3B3), Farbwert(0xFFD778), Farbwert(0xF2A900), Farbwert(0xE0533D),
    ]

    /// Die Stützstellen der Wassertemperatur, in Grad.
    ///
    /// **Dieselben wie im Dashboard** (`anlage/schema.ts`, `STOPS`) – und das war nicht so.
    /// Die Farben stimmten, die Temperaturen daneben nicht: ich hatte `7FA3B3` auf 40 °C und
    /// `FFD778` auf 50 °C gelegt statt auf 35 und 45. Bei den Temperaturen, die ein Puffer
    /// wirklich hat (um die 40 °C), landete damit alles im blassen Übergang zwischen den
    /// beiden – ein Glas in Creme statt in Gold. Dieselbe Skala in zwei Oberflächen muss
    /// dieselben Zahlen an denselben Stellen zeigen, sonst ist es nicht dieselbe Skala.
    public static let wasserstufen: [(grad: Double, farbe: Farbwert)] = [
        (10, Farbwert(0x1A3A52)), (25, Farbwert(0x1F4C66)), (35, Farbwert(0x7FA3B3)),
        (45, Farbwert(0xFFD778)), (55, Farbwert(0xF2A900)), (65, Farbwert(0xE0533D)),
    ]

    /// Die Farbe einer Wassertemperatur – für das Glas und für die Rohre.
    ///
    /// Zwischen den Stützstellen wird gemischt: ein Speicher hat keine Stufen. Ohne Wert
    /// kommt das neutrale Blaugrau der Skala, wie im Dashboard.
    public static func wasserfarbe(_ grad: Double?) -> Farbwert {
        guard let grad, grad.isFinite else { return Farbwert(0x7FA3B3) }
        guard let erste = wasserstufen.first, let letzte = wasserstufen.last else {
            return Farbwert(0x7FA3B3)
        }
        if grad <= erste.grad { return erste.farbe }
        if grad >= letzte.grad { return letzte.farbe }
        for i in 1..<wasserstufen.count where grad <= wasserstufen[i].grad {
            let (g0, f0) = wasserstufen[i - 1]
            let (g1, f1) = wasserstufen[i]
            let t = (grad - g0) / (g1 - g0)
            return Farbwert(
                rot: f0.rot + (f1.rot - f0.rot) * t,
                gruen: f0.gruen + (f1.gruen - f0.gruen) * t,
                blau: f0.blau + (f1.blau - f0.blau) * t
            )
        }
        return letzte.farbe
    }

    /// Die fuenf Stufen der Abweichung, kalt nach warm.
    public static let abweichung: [Farbwert] = [abwKalt2, abwKalt1, abwNull, abwWarm1, abwWarm2]

    /// Die Farbe zu einer Abweichung in Kelvin. Die Schwellen sind dieselben wie im Dashboard.
    public static func abweichungsfarbe(kelvin: Double?) -> Farbwert {
        // **Ohne Wert gibt es keine Farbe.** Hier stand `abwNull` - ein stummer Fuehler sah
        // damit aus wie ein Raum, der genau am Ziel steht. Das ist die unangenehmste Sorte
        // Falschaussage: sie beruhigt. Wer keinen Wert hat, zeichnet eine Schraffur und ruft
        // diese Funktion gar nicht.
        guard let k = kelvin, k.isFinite else { return abwNull }
        // Die Grenzen sind die des Dashboards (`rooms/palette.ts`); sie stehen in
        // `Raumabweichung.stufe` und werden hier nur nachgeschlagen.
        return abweichung[Raumabweichung.stufe(k)]
    }

    // MARK: - Form

    public static let radius1: Double = 2
    public static let radius2: Double = 3
    public static let radius3: Double = 6

    // MARK: - Bewegung

    /// Die Dauer eines Uebergangs. Im Dashboard 0,18 s.
    public static let dauer: Double = 0.18
}

/// Eine Farbe als Zahl, ohne SwiftUI: Rot, Gruen, Blau und Deckung, jeweils 0 bis 1.
public struct Farbwert: Sendable, Hashable {
    public var rot: Double
    public var gruen: Double
    public var blau: Double
    public var deckung: Double

    public init(rot: Double, gruen: Double, blau: Double, deckung: Double = 1) {
        self.rot = rot
        self.gruen = gruen
        self.blau = blau
        self.deckung = deckung
    }

    /// Aus `0xF2A900`.
    public init(_ hex: UInt32, deckung: Double = 1) {
        self.rot = Double((hex >> 16) & 0xFF) / 255
        self.gruen = Double((hex >> 8) & 0xFF) / 255
        self.blau = Double(hex & 0xFF) / 255
        self.deckung = deckung
    }

    /// `#F2A900` - fuer Beschriftungen, die als Text aus dem Kern kommen.
    public var hex: String {
        String(format: "#%02X%02X%02X", Int((rot * 255).rounded()), Int((gruen * 255).rounded()), Int((blau * 255).rounded()))
    }

    /// Dieselbe Farbe mit anderer Deckung.
    public func mitDeckung(_ d: Double) -> Farbwert {
        Farbwert(rot: rot, gruen: gruen, blau: blau, deckung: d)
    }

    // MARK: - Pruefung der Palette

    /// Relative Leuchtdichte nach WCAG.
    public var leuchtdichte: Double {
        func kanal(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * kanal(rot) + 0.7152 * kanal(gruen) + 0.0722 * kanal(blau)
    }

    /// Kontrastverhaeltnis zu einer anderen Farbe, 1 bis 21.
    public func kontrast(zu andere: Farbwert) -> Double {
        let a = leuchtdichte
        let b = andere.leuchtdichte
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// CIE Lab, Bezugsweiss D65 - die Grundlage fuer den Farbabstand.
    public var lab: (l: Double, a: Double, b: Double) {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linear(rot), g = linear(gruen), bl = linear(blau)
        let x = (r * 0.4124564 + g * 0.3575761 + bl * 0.1804375) / 0.95047
        let y = r * 0.2126729 + g * 0.7151522 + bl * 0.0721750
        let z = (r * 0.0193339 + g * 0.1191920 + bl * 0.9503041) / 1.08883
        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0 / 3.0) : (7.787 * t) + 16.0 / 116.0
        }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// Der Farbabstand ΔE76 - die alte, einfache Formel: der Abstand zweier Punkte im Lab-Raum.
    ///
    /// Sie ueberschaetzt den Unterschied bei gesaettigten Farben erheblich. Fuer die Palette ist
    /// `abstand(zu:)` (ΔE2000) zustaendig; diese Formel steht hier, weil sie sich von Hand
    /// nachrechnen laesst und damit die Probe auf die Lab-Umrechnung ist.
    public func abstand76(zu andere: Farbwert) -> Double {
        let a = lab
        let b = andere.lab
        return sqrt(pow(a.l - b.l, 2) + pow(a.a - b.a, 2) + pow(a.b - b.b, 2))
    }

    /// Der Farbabstand ΔE2000 (CIEDE2000) zu einer anderen Farbe.
    ///
    /// Das ist das Mass, das die Anleitung der Datenvisualisierung meint, wenn sie 15 als
    /// Schwelle fuer Serienfarben nennt, die nebeneinander stehen. Der Unterschied zur alten
    /// Formel ist nicht klein: `ofen` gegen `waermepumpe` sind nach ΔE76 fast 25 Punkte und nach
    /// ΔE2000 knapp 17 - die alte Formel haelt fuer sicher unterscheidbar, was es kaum ist.
    ///
    /// Die Umsetzung folgt der Veroeffentlichung von Sharma, Wu und Dalal (2005), samt der
    /// Rotationskorrektur im Blaubereich, an der die meisten Kurzfassungen scheitern.
    public func abstand(zu andere: Farbwert) -> Double {
        let (l1, a1, b1) = lab
        let (l2, a2, b2) = andere.lab

        let c1 = sqrt(a1 * a1 + b1 * b1)
        let c2 = sqrt(a2 * a2 + b2 * b2)
        let cMittel = (c1 + c2) / 2
        let c7 = pow(cMittel, 7)
        let g = cMittel > 0 ? 0.5 * (1 - sqrt(c7 / (c7 + pow(25, 7)))) : 0

        let a1s = (1 + g) * a1
        let a2s = (1 + g) * a2
        let c1s = sqrt(a1s * a1s + b1 * b1)
        let c2s = sqrt(a2s * a2s + b2 * b2)

        func winkel(_ a: Double, _ b: Double) -> Double {
            if a == 0, b == 0 { return 0 }
            let w = atan2(b, a) * 180 / .pi
            return w < 0 ? w + 360 : w
        }
        let h1s = winkel(a1s, b1)
        let h2s = winkel(a2s, b2)

        let dL = l2 - l1
        let dC = c2s - c1s

        var dh: Double = 0
        if c1s * c2s != 0 {
            let roh = h2s - h1s
            if abs(roh) <= 180 {
                dh = roh
            } else if roh > 180 {
                dh = roh - 360
            } else {
                dh = roh + 360
            }
        }
        let dH = 2 * sqrt(c1s * c2s) * sin(dh * .pi / 360)

        let lMittel = (l1 + l2) / 2
        let cMittelS = (c1s + c2s) / 2

        var hMittel: Double = 0
        if c1s * c2s == 0 {
            hMittel = h1s + h2s
        } else if abs(h1s - h2s) <= 180 {
            hMittel = (h1s + h2s) / 2
        } else if h1s + h2s < 360 {
            hMittel = (h1s + h2s + 360) / 2
        } else {
            hMittel = (h1s + h2s - 360) / 2
        }

        func grad(_ w: Double) -> Double { cos(w * .pi / 180) }
        let t = 1 - 0.17 * grad(hMittel - 30) + 0.24 * grad(2 * hMittel)
            + 0.32 * grad(3 * hMittel + 6) - 0.20 * grad(4 * hMittel - 63)

        let dTheta = 30 * exp(-pow((hMittel - 275) / 25, 2))
        let cs7 = pow(cMittelS, 7)
        let rC = cMittelS > 0 ? 2 * sqrt(cs7 / (cs7 + pow(25, 7))) : 0
        let sL = 1 + (0.015 * pow(lMittel - 50, 2)) / sqrt(20 + pow(lMittel - 50, 2))
        let sC = 1 + 0.045 * cMittelS
        let sH = 1 + 0.015 * cMittelS * t
        let rT = -sin(2 * dTheta * .pi / 180) * rC

        return sqrt(
            pow(dL / sL, 2) + pow(dC / sC, 2) + pow(dH / sH, 2)
                + rT * (dC / sC) * (dH / sH)
        )
    }
}
