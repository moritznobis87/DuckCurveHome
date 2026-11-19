import Foundation

/// Woraus das Haus besteht: jedes Möbelstück, jeder Boden, jedes Gerät als Liste von Körpern.
///
/// **Warum das im Kern steht und nicht in der Zeichnung.** Ein Bett sind drei Quader in
/// bestimmten Maßen an bestimmten Stellen, ein Auto ein Rumpf und vier Räder, eine Treppe
/// `steps` Blöcke von steigender Höhe. Das ist Rechnung, keine Darstellung – und Rechnung
/// lässt sich hier prüfen, auf einem Rechner ohne Bildschirm. Die Ansicht bekommt fertige
/// Körper und malt sie; sie entscheidet nicht, wie breit ein Kopfteil ist.
///
/// **Die Maße stammen aus der Vorlage**, `apps/web/src/components/house/HouseScene.ts`, und
/// sind dort mit Zeilennummern nachgewiesen. Wo diese Fassung vereinfacht, steht es dabei.
public enum Hausmodell {

    /// Dicke der Bodenplatte eines Raums. Möbel stehen darauf, nicht auf dem Gelände.
    public static let bodenDicke = 0.14
    public static let wandHoehe = 1.0
    public static let aussenHoehe = 1.15
    public static let kante = Farbwert(0xBFEEFF)
    public static let amber = Farbwert(0xF2B134)

    // MARK: - Ein Körper

    public struct Teil: Sendable {
        public enum Form: Sendable {
            /// Mitte in x und z, Unterkante in y.
            case quader(b: Double, h: Double, t: Double, winkel: Double)
            case zylinder(r: Double, h: Double)
            /// Eine waagerechte Fläche ohne Höhe – Boden, Schatten, Lichtfleck.
            case ebene(b: Double, t: Double, winkel: Double)
            /// Reine Linienzüge in Weltkoordinaten, etwa ein Tor oder ein Kabel.
            case linien([[Punkt3]])
        }

        public let form: Form
        public let x: Double
        public let y: Double
        public let z: Double
        public let farbe: Farbwert
        /// Leuchtende Teile werden addiert statt überdeckt: Glut, Lampen, Kabel.
        public let leuchtet: Bool
        /// Kanten mitzeichnen – gibt den Glaskörpern ihre Form.
        public let kanten: Bool

        public init(
            form: Form, x: Double, y: Double, z: Double, farbe: Farbwert,
            leuchtet: Bool = false, kanten: Bool = true
        ) {
            self.form = form
            self.x = x
            self.y = y
            self.z = z
            self.farbe = farbe
            self.leuchtet = leuchtet
            self.kanten = kanten
        }
    }

    public struct Punkt3: Sendable, Hashable {
        public let x: Double
        public let y: Double
        public let z: Double
        public init(_ x: Double, _ y: Double, _ z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    // MARK: - Die Töne

    /// Die Tonpalette der Vorlage (`toene`, HouseScene.ts:171-180).
    public static func ton(_ t: ItemToneWahl?) -> Farbwert {
        switch t {
        case .dark: return Farbwert(0x0F3243, deckung: 0.66)
        case .light: return Farbwert(0x2F5D70, deckung: 0.62)
        case .soft: return Farbwert(0x5F8FA3, deckung: 0.55)
        case .water: return Farbwert(0x7FD3E6, deckung: 0.50)
        case .wall: return Farbwert(0xDFF2F8, deckung: 0.24)
        // Die beiden Beläge sind deckend: sie sind Gelände, kein Glas.
        case .paving: return Farbwert(0x103647)
        case .terrace: return Farbwert(0x134052)
        case .slate: return Farbwert(0x24323A, deckung: 0.75)
        case .unbekannt, .none: return Farbwert(0x0F3243, deckung: 0.66)
        }
    }

    static let stufenfarbe = Farbwert(0x7FE3FF, deckung: 0.7)
    static let glut = Farbwert(0xFFA050, deckung: 0.9)
    static let rohrfarbe = Farbwert(0xE08B4A, deckung: 0.7)
    static let emporenfarbe = Farbwert(0x9FD3E6, deckung: 0.22)

    // MARK: - Ein Gegenstand

    /// Die Körper eines Gegenstands, von unten nach oben.
    ///
    /// Die Höhenangabe jedes Teils ist seine **Unterkante** über dem Gelände; die Bodenplatte
    /// ist darin schon enthalten, wo die Vorlage sie einrechnet.
    // MARK: - Der Fussboden

    /// Die Heizschlange eines Raums: der Weg des Rohrs, in Raumkoordinaten.
    ///
    /// **Sie ist die Antwort auf „wo wird gerade geheizt".** Ein Grundriss, in dem alle Räume
    /// gleich aussehen, sagt das nicht; das Dashboard legt deshalb in jeden Raum die Schlange
    /// seines Heizkreises und lässt sie leuchten, solange sein Ventil offen ist
    /// (`house/HouseScene.ts`, `schleifenTextur` und `heizMat.opacity`).
    ///
    /// **Die Masse sind die der Vorlage**: 0,3 m Rand zum Raum, die Bahnen rund einen halben
    /// Meter auseinander, mindestens zwei. Es ist keine Zeichnung der wirklichen Verlegung -
    /// die kennt niemand -, sondern das Bild, das jeder von einer Fussbodenheizung hat.
    public static func heizschlange(
        x0: Double, z0: Double, x1: Double, z1: Double
    ) -> [(x: Double, z: Double)] {
        let breite = x1 - x0
        let tiefe = z1 - z0
        let rand = 0.3
        guard breite > 2 * rand + 0.2, tiefe > 2 * rand + 0.2 else { return [] }
        let bahnen = max(2, Int(((tiefe - 0.6) / 0.5).rounded()) + 1)
        let dz = (tiefe - 2 * rand) / Double(bahnen - 1)
        let links = x0 + rand
        let rechts = x1 - rand
        var weg: [(x: Double, z: Double)] = []
        for i in 0..<bahnen {
            let z = z0 + rand + Double(i) * dz
            // Hin und zurück: eine Schlange, kein Kamm - das Rohr hat einen Anfang und ein
            // Ende, und dazwischen reisst es nicht ab.
            if i % 2 == 0 {
                weg.append((links, z))
                weg.append((rechts, z))
            } else {
                weg.append((rechts, z))
                weg.append((links, z))
            }
        }
        return weg
    }

    /// Wie hell die Schlange leuchtet - 0, wenn das Ventil zu ist.
    ///
    /// Die Vorlage rechnet `(0,22 + 0,5 · Ventil)` und lässt es langsam atmen, je Raum um
    /// seine eigene Lage versetzt, damit nicht das ganze Haus im Gleichtakt pulst
    /// (`HouseScene.ts:1336`).
    public static func heizglut(ventil: Double?, takt: Double, versatz: Double) -> Double {
        guard let v = ventil, v > 0 else { return 0 }
        return (0.22 + 0.5 * min(1, v)) * (0.8 + 0.2 * sin(takt * 1.4 + versatz))
    }

    /// Die Fliesen eines Bodens: die Mittelpunkte der Felder und ihre Helligkeit.
    ///
    /// **Ein Schachbrett, um 45 Grad gedreht, 36 Zentimeter je Feld** (`HouseScene.ts`,
    /// `fliesenTextur` mit `repeat.set(b / 0.36, …)` und `rotation = π/4`). Zwei Töne, beide
    /// fast durchsichtig: der Boden soll eine Oberfläche bekommen, keine Musterung.
    public static let fliesenkante = 0.36

    public static func fliesen(
        x0: Double, z0: Double, x1: Double, z1: Double
    ) -> [(x: Double, z: Double, hell: Bool)] {
        let kante = fliesenkante
        let rand = 0.06
        let a = (x: x0 + rand, z: z0 + rand)
        let b = (x: x1 - rand, z: z1 - rand)
        guard b.x > a.x, b.z > a.z else { return [] }
        // Die Diagonale des Raums: so weit muss das gedrehte Raster reichen.
        let mx = (a.x + b.x) / 2
        let mz = (a.z + b.z) / 2
        let weite = ((b.x - a.x) * (b.x - a.x) + (b.z - a.z) * (b.z - a.z)).squareRoot()
        let zahl = Int((weite / kante).rounded(.up)) + 1
        let wurzel = (0.5).squareRoot()
        var aus: [(x: Double, z: Double, hell: Bool)] = []
        for i in -zahl...zahl {
            for j in -zahl...zahl {
                // Um 45 Grad gedreht: die Achsen des Rasters laufen diagonal.
                let u = Double(i) * kante
                let v = Double(j) * kante
                let x = mx + (u - v) * wurzel
                let z = mz + (u + v) * wurzel
                guard x >= a.x, x <= b.x, z >= a.z, z <= b.z else { continue }
                aus.append((x, z, (i + j) % 2 == 0))
            }
        }
        return aus
    }

    public static func teile(_ it: Item) -> [Teil] {
        let x = it.x ?? 0
        let z = it.z ?? 0
        let y = it.y ?? 0

        switch it.kind {
        case .box:
            return [
                Teil(
                    form: .quader(b: it.b ?? 0.6, h: it.h ?? 0.5, t: it.t ?? 0.6, winkel: 0),
                    x: x, y: bodenDicke + y, z: z, farbe: ton(it.tone ?? .dark))
            ]

        case .cylinder:
            return [
                Teil(
                    form: .zylinder(r: it.r ?? 0.3, h: it.h ?? 0.45), x: x, y: bodenDicke + y,
                    z: z, farbe: ton(it.tone ?? .light))
            ]

        case .chair:
            // Maße fest; `b`/`t` bleiben ungenutzt, wie in der Vorlage.
            return [
                Teil(
                    form: .zylinder(r: it.r ?? 0.19, h: 0.44), x: x, y: bodenDicke + y, z: z,
                    farbe: ton(.light))
            ]

        case .plant:
            return [
                Teil(
                    form: .zylinder(r: it.r ?? 0.2, h: it.h ?? 0.6), x: x, y: bodenDicke + y,
                    z: z, farbe: Farbwert(0x3F8F6C, deckung: 0.6))
            ]

        case .tree:
            return baum(it, x: x, y: y, z: z)

        case .bed:
            return bett(it, x: x, y: y, z: z)

        case .stove:
            return ofen(it, x: x, y: y, z: z)

        case .ladder:
            return leiter(it, y: y)

        case .loft:
            guard let x0 = it.x0, let z0 = it.z0, let x1 = it.x1, let z1 = it.z1 else { return [] }
            return [
                Teil(
                    form: .quader(b: abs(x1 - x0), h: 0.05, t: abs(z1 - z0), winkel: 0),
                    x: (x0 + x1) / 2, y: bodenDicke + (it.y ?? 0.66), z: (z0 + z1) / 2,
                    farbe: emporenfarbe)
            ]

        case .panel:
            return [
                Teil(
                    form: .quader(
                        b: it.b ?? 0.06, h: it.h ?? (wandHoehe - 0.05), t: it.t ?? 0.06,
                        winkel: 0),
                    x: x, y: bodenDicke + y, z: z, farbe: ton(it.tone ?? .dark))
            ]

        case .tiles:
            guard let x0 = it.x0, let z0 = it.z0, let x1 = it.x1, let z1 = it.z1 else { return [] }
            return [
                Teil(
                    form: .ebene(b: abs(x1 - x0), t: abs(z1 - z0), winkel: 0),
                    x: (x0 + x1) / 2, y: bodenDicke + 0.006, z: (z0 + z1) / 2,
                    farbe: Farbwert(0xFFFFFF, deckung: 0.05), kanten: false)
            ]

        case .ground:
            return [
                Teil(
                    form: .ebene(b: it.b ?? 2, t: it.t ?? 2, winkel: it.angle ?? 0),
                    x: x, y: 0.005, z: z, farbe: ton(it.tone ?? .paving), kanten: false)
            ]

        case .wall:
            // Unterkante ist das rohe `y`: eine Gartenmauer steht auf dem Gelände.
            return [
                Teil(
                    form: .quader(b: it.b ?? 0.2, h: it.h ?? 0.9, t: it.t ?? 0.2, winkel: 0),
                    x: x, y: y, z: z, farbe: Farbwert(0xDFF2F8, deckung: 0.24))
            ]

        case .gate:
            return tor(it)

        case .car:
            return auto(it, x: x, z: z)

        case .wallbox:
            return wallbox(it, x: x, y: y, z: z)

        case .heatPump:
            return waermepumpe(it, x: x, z: z)

        case .buffer:
            return puffer(it, x: x, y: y, z: z)

        case .indoorUnit:
            return innengeraet(it, x: x, z: z)

        case .pipe:
            let punkte = (it.points ?? []).compactMap { p -> Punkt3? in
                guard p.count >= 3 else { return nil }
                return Punkt3(p[0], p[1], p[2])
            }
            guard punkte.count >= 2 else { return [] }
            return [
                Teil(
                    form: .linien([punkte]), x: 0, y: 0, z: 0, farbe: rohrfarbe,
                    leuchtet: true, kanten: false)
            ]

        case .flight:
            return treppenlauf(it, y: y)

        case .landing:
            return [
                Teil(
                    form: .quader(b: it.b ?? 1.5, h: it.h ?? 0.1, t: it.t ?? 1.0, winkel: 0),
                    x: x, y: bodenDicke + y, z: z, farbe: stufenfarbe)
            ]

        case .pit:
            return [
                Teil(
                    form: .ebene(b: it.b ?? 2, t: it.t ?? 2, winkel: 0), x: x, y: y, z: z,
                    farbe: Farbwert(0x04141C), kanten: false)
            ]

        case .unbekannt:
            // Eine Art, die diese Fassung nicht kennt, wird nicht geraten.
            return []
        }
    }

    // MARK: - Die zusammengesetzten Gegenstände

    private static func baum(_ it: Item, x: Double, y: Double, z: Double) -> [Teil] {
        let scheibe = (it.b ?? 2.0) / 2
        let hoehe = it.h ?? 2.2
        let krone = it.r ?? 1.3
        return [
            // Die Baumscheibe im Boden.
            Teil(
                form: .ebene(b: scheibe * 2, t: scheibe * 2, winkel: 0), x: x, y: 0.008, z: z,
                farbe: Farbwert(0x0A2331), kanten: false),
            // Der Stamm: der Halbmesser steht fest, nur die Höhe kommt aus dem Plan.
            Teil(
                form: .zylinder(r: 0.07, h: hoehe), x: x, y: y, z: z, farbe: ton(.light),
                kanten: false),
            // Die Krone ist eine flache Scheibe, kein Ball: aus der Höhe dieses Blicks sieht
            // man ohnehin auf sie herab.
            Teil(
                form: .zylinder(r: krone, h: 0.08), x: x, y: y + hoehe, z: z,
                farbe: Farbwert(0x7FD3E6, deckung: 0.16)),
        ]
    }

    private static func bett(_ it: Item, x: Double, y: Double, z: Double) -> [Teil] {
        let b = it.b ?? 1.6
        let t = it.t ?? 2.0
        let kopf = it.head ?? .n
        let fuss = bodenDicke + y
        var aus: [Teil] = [
            Teil(form: .quader(b: b, h: 0.42, t: t, winkel: 0), x: x, y: fuss, z: z,
                 farbe: ton(.light))
        ]
        // Die Decke liegt auf der Matratze und ist vom Kopfteil weggerückt.
        let laengs = kopf == .n || kopf == .s
        let deckeB = laengs ? b - 0.2 : b - 0.5
        let deckeT = laengs ? t - 0.5 : t - 0.2
        let weg = 0.18
        let dx = kopf == .w ? weg : (kopf == .o ? -weg : 0)
        let dz = kopf == .n ? weg : (kopf == .s ? -weg : 0)
        aus.append(
            Teil(
                form: .quader(b: deckeB, h: 0.1, t: deckeT, winkel: 0), x: x + dx,
                y: fuss + 0.42, z: z + dz, farbe: ton(.soft)))
        // Das Kopfteil an seiner Seite.
        switch kopf {
        case .n, .unbekannt:
            aus.append(
                Teil(
                    form: .quader(b: b + 0.06, h: 0.8, t: 0.1, winkel: 0), x: x, y: fuss,
                    z: z - t / 2 + 0.05, farbe: ton(.dark)))
        case .s:
            aus.append(
                Teil(
                    form: .quader(b: b + 0.06, h: 0.8, t: 0.1, winkel: 0), x: x, y: fuss,
                    z: z + t / 2 - 0.05, farbe: ton(.dark)))
        case .w:
            aus.append(
                Teil(
                    form: .quader(b: 0.1, h: 0.8, t: t + 0.06, winkel: 0), x: x - b / 2 + 0.05,
                    y: fuss, z: z, farbe: ton(.dark)))
        case .o:
            aus.append(
                Teil(
                    form: .quader(b: 0.1, h: 0.8, t: t + 0.06, winkel: 0), x: x + b / 2 - 0.05,
                    y: fuss, z: z, farbe: ton(.dark)))
        }
        return aus
    }

    private static func ofen(_ it: Item, x: Double, y: Double, z: Double) -> [Teil] {
        let r = it.r ?? 0.25
        let fuss = bodenDicke + y
        return [
            Teil(form: .zylinder(r: r, h: 0.9), x: x, y: fuss, z: z, farbe: ton(.dark)),
            // Die Glut sitzt vorn in der Tür und leuchtet, wenn der Ofen brennt.
            Teil(
                form: .ebene(b: r * 1.3, t: 0.02, winkel: 0), x: x, y: fuss + 0.4,
                z: z + r + 0.01, farbe: glut, leuchtet: true, kanten: false),
            Teil(
                form: .zylinder(r: 0.05, h: 0.5), x: x, y: fuss + 0.9, z: z,
                farbe: ton(.dark), kanten: false),
        ]
    }

    private static func leiter(_ it: Item, y: Double) -> [Teil] {
        guard let x0 = it.x0, let z0 = it.z0, let x1 = it.x1, let z1 = it.z1 else { return [] }
        let b = it.b ?? 0.4
        let quer = abs(z1 - z0) > abs(x1 - x0)
        // Immer fünf Sprossen - `steps` gilt hier nicht, wie in der Vorlage.
        return (0..<5).map { i in
            let anteil = (Double(i) + 0.5) / 5
            return Teil(
                form: .quader(
                    b: quer ? b : 0.2, h: 0.04, t: quer ? 0.2 : b, winkel: 0),
                x: x0 + (x1 - x0) * anteil, y: bodenDicke + y + 0.1 + Double(i) * 0.11,
                z: z0 + (z1 - z0) * anteil, farbe: stufenfarbe)
        }
    }

    private static func tor(_ it: Item) -> [Teil] {
        let h = it.h ?? 0.85
        let senkrecht = it.x0 == nil || it.x1 == nil
        let a = senkrecht ? (it.z0 ?? 0) : (it.x0 ?? 0)
        let b = senkrecht ? (it.z1 ?? 0) : (it.x1 ?? 0)
        let konst = senkrecht ? (it.x ?? 0) : (it.z ?? 0)
        func p(_ laengs: Double, _ hoehe: Double) -> Punkt3 {
            senkrecht ? Punkt3(konst, hoehe, laengs) : Punkt3(laengs, hoehe, konst)
        }
        var zuege: [[Punkt3]] = [[p(a, 0.02), p(a, h), p(b, h), p(b, 0.02)]]
        let n = max(2, Int((abs(b - a) / 0.3).rounded()))
        for i in 1..<n {
            let s = a + (b - a) * Double(i) / Double(n)
            zuege.append([p(s, 0.02), p(s, h)])
        }
        return [
            Teil(form: .linien(zuege), x: 0, y: 0, z: 0, farbe: kante.mitDeckung(0.4),
                 kanten: false)
        ]
    }

    /// Das Auto – **vereinfacht**, und das ist die größte Abweichung dieser Fassung.
    ///
    /// Die Vorlage zieht einen Rumpf über 17 Leitpunkte und 70 Querschnitte, mit Scheiben, die
    /// aus der Lage über der Schulterlinie entstehen. Das ist eine Freiform, für die eine
    /// Zeichenfläche kein Werkzeug hat. Hier stehen stattdessen drei Quader – Wanne, Kabine,
    /// Haube – in denselben Gesamtmaßen (4,84 m lang, 1,92 m breit, 1,40 m hoch) und vier
    /// Räder an denselben Stellen. Aus dieser Höhe und bei dieser Größe ist der Unterschied
    /// die Rundung, nicht die Gestalt.
    private static func auto(_ it: Item, x: Double, z: Double) -> [Teil] {
        let winkel = (it.angle ?? 0)
        let lack = Farbwert(0x1A4357, deckung: 0.9)
        let scheibe = Farbwert(0xA6E4F6, deckung: 0.42)
        let reifen = Farbwert(0x061620, deckung: 0.92)
        let fuss = bodenDicke
        // Die Räder sitzen an ±1,5 m in der Länge und ±0,82 m quer.
        let raeder: [(Double, Double)] = [(1.5, 0.82), (1.5, -0.82), (-1.5, 0.82), (-1.5, -0.82)]
        var aus: [Teil] = [
            Teil(
                form: .ebene(b: 5.6, t: 2.9, winkel: winkel), x: x, y: fuss - bodenDicke + 0.012,
                z: z, farbe: Farbwert(0x000000, deckung: 0.45), kanten: false),
            // Die Wanne über der ganzen Länge.
            Teil(
                form: .quader(b: 4.84, h: 0.52, t: 1.92, winkel: winkel), x: x, y: fuss + 0.2,
                z: z, farbe: lack),
            // Die Kabine, nach hinten versetzt und schmaler.
            Teil(
                form: .quader(b: 2.6, h: 0.68, t: 1.72, winkel: winkel),
                x: x - 0.45 * cos(winkel), y: fuss + 0.72, z: z - 0.45 * sin(winkel),
                farbe: scheibe),
        ]
        for (dl, dq) in raeder {
            let rx = x + dl * cos(winkel) - dq * sin(winkel)
            let rz = z + dl * sin(winkel) + dq * cos(winkel)
            aus.append(
                Teil(
                    form: .zylinder(r: 0.37, h: 0.26), x: rx, y: 0, z: rz, farbe: reifen,
                    kanten: false))
        }
        return aus
    }

    private static func wallbox(_ it: Item, x: Double, y: Double, z: Double) -> [Teil] {
        let fuss = bodenDicke + y + 0.45
        var aus: [Teil] = [
            Teil(
                form: .quader(b: it.b ?? 0.24, h: it.h ?? 0.4, t: it.t ?? 0.42, winkel: 0),
                x: x, y: fuss, z: z, farbe: ton(.dark)),
            Teil(
                form: .ebene(b: 0.1, t: 0.1, winkel: 0), x: x + (it.b ?? 0.24) / 2 + 0.01,
                y: bodenDicke + y + 0.75, z: z, farbe: glut, leuchtet: true, kanten: false),
        ]
        // Das Kabel zum Auto, wenn eines angegeben ist.
        if let x1 = it.x1, let z1 = it.z1 {
            aus.append(
                Teil(
                    form: .linien([[
                        Punkt3(x, 0.6, z),
                        Punkt3((x + x1) / 2, 0.25, (z + z1) / 2),
                        Punkt3(x1, 0.5, z1),
                    ]]), x: 0, y: 0, z: 0, farbe: amber.mitDeckung(0.8), leuchtet: true,
                    kanten: false))
        }
        return aus
    }

    private static func waermepumpe(_ it: Item, x: Double, z: Double) -> [Teil] {
        let richtung = it.dir ?? .n
        let laengs = richtung == .n || richtung == .s
        // Steht auf dem Gelände, nicht auf einer Bodenplatte.
        var aus: [Teil] = [
            Teil(
                form: .quader(
                    b: laengs ? 1.6 : 0.75, h: 1.35, t: laengs ? 0.75 : 1.6, winkel: 0),
                x: x, y: 0, z: z, farbe: ton(.light))
        ]
        // Der Ventilator als Ring auf der Seite, in die er bläst.
        let versatz = 0.39
        let rx = richtung == .o ? versatz : (richtung == .w ? -versatz : 0)
        let rz = richtung == .s ? versatz : (richtung == .n ? -versatz : 0)
        aus.append(
            Teil(
                form: .zylinder(r: 0.5, h: 0.03), x: x + rx, y: 0.72, z: z + rz,
                farbe: Farbwert(0xE08B4A, deckung: 0.8), leuchtet: true, kanten: false))
        return aus
    }

    private static func puffer(_ it: Item, x: Double, y: Double, z: Double) -> [Teil] {
        let r = it.r ?? 0.5
        // Vier Schichten zu 0,6 m – der Speicher ist 2,4 m hoch und zeigt seine Schichtung.
        return (0..<4).map { i in
            Teil(
                form: .zylinder(r: r, h: 0.6), x: x, y: bodenDicke + y + Double(i) * 0.6, z: z,
                farbe: Farbwert(0x2B4A58, deckung: 0.85))
        }
    }

    private static func innengeraet(_ it: Item, x: Double, z: Double) -> [Teil] {
        let richtung = it.dir ?? .w
        let laengs = richtung == .n || richtung == .s
        return [
            Teil(
                form: .quader(
                    b: laengs ? 0.9 : 0.42, h: 0.85, t: laengs ? 0.42 : 0.9, winkel: 0),
                x: x, y: bodenDicke + 0.3, z: z, farbe: ton(.light))
        ]
    }

    private static func treppenlauf(_ it: Item, y: Double) -> [Teil] {
        guard let x0 = it.x0, let z0 = it.z0, let x1 = it.x1, let z1 = it.z1 else { return [] }
        let stufen = max(1, it.steps ?? 8)
        let b = it.b ?? 1.0
        let bis = it.y1 ?? (y + 1.0)
        let unten = min(y, bis)
        let laengsZ = abs(z1 - z0) > abs(x1 - x0)
        let laenge = sqrt(pow(x1 - x0, 2) + pow(z1 - z0, 2))
        let tritt = laenge / Double(stufen)
        return (0..<stufen).map { i in
            let anteil = (Double(i) + 0.5) / Double(stufen)
            // Jede Stufe ist ein Block vom Fuß des Laufs bis zu ihrer Trittfläche - so sieht
            // man die Treppe als Körper und nicht als schwebende Bretter.
            let oben = y + (bis - y) * Double(i + 1) / Double(stufen)
            return Teil(
                form: .quader(
                    b: laengsZ ? b : tritt * 0.96, h: max(0.03, oben - unten),
                    t: laengsZ ? tritt * 0.96 : b, winkel: 0),
                x: x0 + (x1 - x0) * anteil, y: bodenDicke + unten,
                z: z0 + (z1 - z0) * anteil, farbe: stufenfarbe)
        }
    }

    // MARK: - Der Boden eines Raums

    /// Die sichtbare Bodenfarbe eines Raums.
    ///
    /// **Nicht die Temperaturfarbe pur.** Sie wird nach `#0b2a3a` hin abgedunkelt, und zwar
    /// unterschiedlich stark: ein kalter Raum fast ganz, ein Raum mit Messung kaum, ein Raum
    /// ohne Messung dazwischen. Sonst leuchtet ein Haus, in dem nur zwei Zimmer einen Fühler
    /// haben, in zwei Farben und der Rest ist grau.
    public static func bodenfarbe(_ raum: Room, grad: Double?) -> Farbwert {
        let grund = Farbwert(0x0B2A3A)
        let roh = grad.map { Hausgeometrie.bodenfarbe($0) } ?? Farbwert(0x2C5D72)
        let anteil: Double = raum.cold == true ? 0.55 : (grad != nil ? 0.1 : 0.45)
        return mische(roh, nach: grund, anteil: anteil)
    }

    static func mische(_ a: Farbwert, nach b: Farbwert, anteil: Double) -> Farbwert {
        let f = min(1, max(0, anteil))
        return Farbwert(
            rot: a.rot + (b.rot - a.rot) * f,
            gruen: a.gruen + (b.gruen - a.gruen) * f,
            blau: a.blau + (b.blau - a.blau) * f,
            deckung: a.deckung)
    }
}
