import Foundation

/// Rechnen fuer das Hausmodell: Waende aus Raeumen, Luecken, Versatz, Projektion.
///
/// Wortgleich portiert aus `apps/web/src/components/house/geometrie.ts`, mit demselben Satz
/// darueber: „Hier steht, was sich pruefen laesst, ohne einen Bildschirm zu haben."
///
/// ## Warum die App kein SceneKit braucht
///
/// Das Dashboard zeichnet das Haus mit three.js, 1366 Zeilen in `HouseScene.ts`. Diese Szene
/// nach SceneKit zu uebersetzen waere die groesste unpruefbare Arbeit des ganzen Umbaus - und
/// sie waere unnoetig. Zwei Zeilen in der Vorlage sagen, warum:
///
/// ```
/// private readonly camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -500, 500);
/// export function bildschirm(x, y, z, th) { ... }
/// ```
///
/// Die Kamera ist **orthographisch**, und die Lage jedes Punkts wird mit einer
/// **Kavalierprojektion** gerechnet: senkrechte Kanten laufen schraeg nach rechts oben, der
/// Grundriss bleibt masstaeblich und rechtwinklig. Das ist keine perspektivische Szene, die man
/// rendern muss - das ist eine Zeichnung, und zwar eine, deren Koordinaten diese Datei
/// ausrechnet. Die App zeichnet sie mit `Path`, wie das Dashboard sie mit SVG zeichnen koennte.
///
/// Was dabei verloren geht, ist ehrlich zu benennen: die Beleuchtung (zwei gerichtete Lichter
/// auf transparenten Lambert-Flaechen) und das Glimmen der Glut mit additivem Blending. Beides
/// ist Stimmung und nicht Auskunft. Was bleibt, ist die Geometrie - und die ist hier gerechnet
/// und geprueft, statt in einer Szene zu stecken, die niemand nachrechnen kann.
public enum Hausgeometrie {
    /// Die vier Seiten eines Raums.
    public enum Seite: String, Sendable, Hashable, CaseIterable {
        case n, s, w, o
    }

    /// Die Reihenfolge, in der `wandstuecke` die Seiten abgeht. Nord, Sued, West, Ost - wie im
    /// Dashboard, damit die Reihenfolge der Wandstuecke dieselbe ist.
    public static let seiten: [Seite] = [.n, .s, .w, .o]

    /// Ein Stueck einer Wand auf einer Wandlinie.
    public struct Wandstueck: Sendable, Hashable {
        /// Nord-Sued-Wand (feste x) oder Ost-West-Wand (feste z).
        public var senkrecht: Bool
        public var konst: Double
        public var a: Double
        public var b: Double
        /// Liegt auf der Aussenhaut? Dann ist die Wand hoeher und heller.
        public var aussen: Bool

        public init(senkrecht: Bool, konst: Double, a: Double, b: Double, aussen: Bool) {
            self.senkrecht = senkrecht
            self.konst = konst
            self.a = a
            self.b = b
            self.aussen = aussen
        }
    }

    public typealias Intervall = (a: Double, b: Double)

    /// Die Toleranz, mit der zwei Koordinaten als dieselbe gelten. Zwei Zentimeter: Raumkanten
    /// kommen aus einem Plan, der in Metern gezeichnet ist, und ein Rundungsfehler darf keine
    /// zweite Wand ergeben.
    static let toleranz = 0.02

    // MARK: - Intervalle

    /// Ueberlappende oder anstossende Intervalle zu einem zusammenfassen.
    ///
    /// Das ist der Grund, warum eine Wand zwischen zwei Raeumen nur einmal im Glas steht: beide
    /// Raeume melden sie, und hier werden die beiden Meldungen eine.
    public static func vereinigt(_ iv: [Intervall]) -> [Intervall] {
        let sortiert = iv.sorted { $0.a < $1.a }
        var aus: [Intervall] = []
        for stueck in sortiert {
            if let letztes = aus.last, stueck.a <= letztes.b + toleranz {
                aus[aus.count - 1].b = max(letztes.b, stueck.b)
            } else {
                aus.append(stueck)
            }
        }
        return aus
    }

    /// Intervalle abzueglich der Luecken darin: aus einer Wand werden Wandstuecke zwischen den Tueren.
    public static func ohneLuecken(_ iv: [Intervall], luecken: [Intervall]) -> [Intervall] {
        var aus: [Intervall] = []
        for stueck in iv {
            var stelle = stueck.a
            let passend = luecken
                .filter { $0.b > stueck.a + toleranz && $0.a < stueck.b - toleranz }
                .sorted { $0.a < $1.a }
            for luecke in passend {
                if luecke.a > stelle + toleranz {
                    aus.append((a: stelle, b: luecke.a))
                }
                stelle = max(stelle, luecke.b)
            }
            if stueck.b > stelle + toleranz {
                aus.append((a: stelle, b: stueck.b))
            }
        }
        return aus
    }

    // MARK: - Waende

    /// Liegt eine Raumkante auf der Aussenhaut?
    public static func istAussen(huelle: [[Double]], raum: Room, seite: Seite) -> Bool {
        let n = huelle.count
        guard n > 1 else { return false }
        for i in 0..<n {
            let p = huelle[i]
            let q = huelle[(i + 1) % n]
            guard p.count >= 2, q.count >= 2 else { continue }
            let (ax, az) = (p[0], p[1])
            let (bx, bz) = (q[0], q[1])
            if seite == .n || seite == .s {
                let z = seite == .n ? raum.z0 : raum.z1
                if abs(az - z) > 0.05 || abs(bz - z) > 0.05 { continue }
                if min(ax, bx) < raum.x1 - 0.2 && max(ax, bx) > raum.x0 + 0.2 { return true }
            } else {
                let x = seite == .w ? raum.x0 : raum.x1
                if abs(ax - x) > 0.05 || abs(bx - x) > 0.05 { continue }
                if min(az, bz) < raum.z1 - 0.2 && max(az, bz) > raum.z0 + 0.2 { return true }
            }
        }
        return false
    }

    /// Alle Wandstuecke eines Decks: Raumkanten und Zusatzwaende, je Wandlinie vereinigt, ohne
    /// die Tuerluecken.
    public static func wandstuecke(_ deck: Deck) -> [Wandstueck] {
        struct Linie {
            var senkrecht: Bool
            var konst: Double
            var aussen: Bool
            var iv: [Intervall]
        }
        // Die Reihenfolge muss stabil sein, damit die Zeichnung sich nicht bei jedem Bild
        // umsortiert. Ein Woerterbuch allein gibt das nicht her.
        var schluessel: [String] = []
        var linien: [String: Linie] = [:]

        func melde(_ senkrecht: Bool, _ konst: Double, _ von: Double, _ bis: Double, _ aussen: Bool) {
            let s = "\(senkrecht ? "x" : "z"):\(String(format: "%.2f", konst)):\(aussen ? "a" : "i")"
            if linien[s] == nil {
                linien[s] = Linie(senkrecht: senkrecht, konst: konst, aussen: aussen, iv: [])
                schluessel.append(s)
            }
            linien[s]?.iv.append((a: min(von, bis), b: max(von, bis)))
        }

        for raum in deck.rooms {
            for seite in seiten {
                if (raum.noWalls ?? "").contains(seite.rawValue) { continue }
                let senkrecht = seite == .w || seite == .o
                let konst: Double =
                    senkrecht
                    ? (seite == .w ? raum.x0 : raum.x1)
                    : (seite == .n ? raum.z0 : raum.z1)
                melde(
                    senkrecht, konst,
                    senkrecht ? raum.z0 : raum.x0,
                    senkrecht ? raum.z1 : raum.x1,
                    istAussen(huelle: deck.shell, raum: raum, seite: seite)
                )
            }
        }
        for w in deck.walls ?? [] {
            melde(w.x != nil, w.x ?? w.z ?? 0, w.a, w.b, false)
        }

        var aus: [Wandstueck] = []
        for s in schluessel {
            guard let w = linien[s] else { continue }
            let luecken: [Intervall] = (deck.gaps ?? []).compactMap { l in
                if w.senkrecht {
                    guard let x = l.x, abs(x - w.konst) < 0.06 else { return nil }
                } else {
                    guard let z = l.z, abs(z - w.konst) < 0.06 else { return nil }
                }
                return (a: l.a, b: l.b)
            }
            for stueck in ohneLuecken(vereinigt(w.iv), luecken: luecken) {
                aus.append(
                    Wandstueck(
                        senkrecht: w.senkrecht, konst: w.konst, a: stueck.a, b: stueck.b,
                        aussen: w.aussen
                    )
                )
            }
        }
        return aus
    }

    /// Ein Vieleck um `d` nach aussen versetzt (gegen den Uhrzeigersinn in x/z gegeben).
    public static func versetzt(_ punkte: [[Double]], _ d: Double) -> [Punkt] {
        let n = punkte.count
        guard n > 2 else { return punkte.map { Punkt($0.first ?? 0, $0.count > 1 ? $0[1] : 0) } }
        var aus: [Punkt] = []
        for i in 0..<n {
            let p = punkte[i]
            let q = punkte[(i + 1) % n]
            let o = punkte[(i - 1 + n) % n]
            guard p.count >= 2, q.count >= 2, o.count >= 2 else { continue }
            let e1 = (p[0] - o[0], p[1] - o[1])
            let e2 = (q[0] - p[0], q[1] - p[1])
            let l1 = max(hypot(e1.0, e1.1), 1e-9)
            let l2 = max(hypot(e2.0, e2.1), 1e-9)
            let n1 = (e1.1 / l1, -e1.0 / l1)
            let n2 = (e2.1 / l2, -e2.0 / l2)
            aus.append(Punkt(p[0] + d * (n1.0 + n2.0), p[1] + d * (n1.1 + n2.1)))
        }
        return aus
    }

    /// Die Umgrenzung einer Punktmenge in x/z.
    public static func umgrenzung(_ punkte: [[Double]]) -> (x0: Double, x1: Double, z0: Double, z1: Double)? {
        let xs = punkte.compactMap(\.first)
        let zs = punkte.compactMap { $0.count > 1 ? $0[1] : nil }
        guard let x0 = xs.min(), let x1 = xs.max(), let z0 = zs.min(), let z1 = zs.max() else {
            return nil
        }
        return (x0, x1, z0, z1)
    }

    // MARK: - Kavalierprojektion

    /// Senkrechte Kanten laufen schraeg nach rechts oben: so zeigen Waende und Moebel zwei
    /// Seiten, und der Grundriss bleibt masstaeblich und rechtwinklig.
    public static let kX = 0.34
    public static let kY = 0.58

    /// Bildschirmkoordinaten (rechts, oben) eines Punkts bei Drehung `th` des Grundrisses.
    ///
    /// Die zweite Zahl zaehlt nach **oben**, nicht nach unten - das ist die Rechnung der Vorlage.
    /// Wer sie unverändert in eine Zeichenebene setzt, in der y nach unten zeigt, bekommt das
    /// Haus auf dem Kopf.
    public static func bildschirm(x: Double, y: Double, z: Double, drehung th: Double) -> (sx: Double, su: Double) {
        let c = cos(th)
        let s = sin(th)
        return (sx: x * c - z * s + kX * y, su: -(x * s + z * c) + kY * y)
    }

    /// Richtung des Sehstrahls im gedrehten Grundriss, zum Betrachter hin, als Einheitsvektor.
    ///
    /// Braucht die Zeichnung, um zu entscheiden, welche Seite einer Wand zu sehen ist.
    public static func strahl(drehung th: Double) -> (Double, Double, Double) {
        let c = cos(th)
        let s = sin(th)
        let v = (-kX * c + kY * s, 1.0, kX * s + kY * c)
        let l = max(sqrt(v.0 * v.0 + v.1 * v.1 + v.2 * v.2), 1e-9)
        return (v.0 / l, v.1 / l, v.2 / l)
    }

    // MARK: - Temperaturfarbe

    /// Farbstopps der Raumboeden, von kalt nach warm.
    ///
    /// Eine eigene Skala, nicht die des Wassers: ein Raum bei 21 °C ist angenehm, ein
    /// Heizungsvorlauf bei 21 °C ist kalt. Dieselben Farben fuer beides waeren eine
    /// Verwechslung, die man nicht bemerkt.
    public static let temperaturstopps: [(grad: Double, farbe: Farbwert)] = [
        (15, Farbwert(0x25506A)),
        (19, Farbwert(0x3D7A9C)),
        (21, Farbwert(0x6AB6C8)),
        (22.5, Farbwert(0xC8902F)),
        (24, Farbwert(0xF2B134)),
        (26, Farbwert(0xFF7A45)),
    ]

    /// Die Farbe eines Bodens zu einer Raumtemperatur.
    public static func bodenfarbe(_ grad: Double) -> Farbwert {
        guard let erster = temperaturstopps.first, let letzter = temperaturstopps.last else {
            return Farbwert(0x25506A)
        }
        if grad <= erster.grad { return erster.farbe }
        if grad >= letzter.grad { return letzter.farbe }
        for i in 1..<temperaturstopps.count {
            let (g1, b) = temperaturstopps[i]
            guard grad <= g1 else { continue }
            let (g0, a) = temperaturstopps[i - 1]
            let f = (grad - g0) / (g1 - g0)
            return Farbwert(
                rot: a.rot + (b.rot - a.rot) * f,
                gruen: a.gruen + (b.gruen - a.gruen) * f,
                blau: a.blau + (b.blau - a.blau) * f
            )
        }
        return letzter.farbe
    }

    /// Die Wandlinie einer Oeffnung: feste Koordinate und Laufrichtung.
    public static func wandlinie(_ o: WallLine) -> (senkrecht: Bool, konst: Double) {
        o.x != nil ? (true, o.x ?? 0) : (false, o.z ?? 0)
    }

    public static func wandlinie(_ o: Opening) -> (senkrecht: Bool, konst: Double) {
        o.x != nil ? (true, o.x ?? 0) : (false, o.z ?? 0)
    }
}
