import DuckCurveKit
import SwiftUI

/// Das Haus als Glasmodell: Decks, Räume, Möbel, Gelände – von schräg oben.
///
/// **Was hier vorher stand, und warum es kein Haus war.** Die Zeichnung las aus dem Hausplan
/// nur `rooms`, `walls` und `contacts`. Alles andere, was der Dienst mitschickt, blieb liegen:
/// `items` (Betten, Sofas, Tische, Treppenläufe, das Auto, die Wallbox, Bäume, Beläge) und
/// `places` (GARTEN, TERRASSE, INNENHOF, STRASSE). Übrig blieb ein Stapel durchscheinender
/// Kästen. Dazu bekam **jeder** Raum seinen Namen und seine Temperatur ins Bild – die Vorlage
/// blendet den Namen unter 27 Punkten je Meter aus und zeigt dann nur noch die Zahl. Das war
/// der Haufen Wörter in der Mitte.
///
/// **Reihenfolge ist Tiefe.** Eine Zeichenfläche kennt keine Tiefenprüfung. Darum werden erst
/// *alle* Flächen des Decks gesammelt – Böden, Wände, Öffnungen, Möbel –, nach ihrem Abstand
/// zum Betrachter sortiert und dann von hinten nach vorn gemalt. Wer stattdessen Gruppe für
/// Gruppe malt, bekommt ein Bett, das durch die Wand davor scheint.
///
/// **Das Modell lässt sich drehen**, mit dem Finger um die Hochachse und in Vierteldrehungen
/// über die beiden Knöpfe. Das ist nicht Spielerei: ein Haus von einer Seite zeigt die Räume
/// dahinter nicht.
struct Glasmodell: View {
    let plan: HousePlan
    /// Die Raeume mit ihren Temperaturen, nach Raumkennung.
    let raeume: [Int: RoomLiveOut]
    /// Die Kontakte, nach Schluessel.
    let kontakte: [String: HouseContactOut]
    var alarmScharf: Bool = false
    /// Welches Deck gezeigt wird. `nil` heisst: alle uebereinander.
    var sichtbaresDeck: String?
    /// Die Zahlen der Geräteschilder.
    var waermepumpeKw: Double?
    var wallboxKw: Double?
    var pufferSoc: Double?
    /// Was ein Tipp auf einen Raum tut. Ohne das bleibt das Modell ein Bild.
    var tippeRaum: ((Int) -> Void)?

    /// Die Drehung des Grundrisses. Die Vorgabe zeigt die Suedwestecke - dort ist die Terrasse.
    @State private var drehung: Double = 0.62
    @State private var beimZiehenAb: Double = 0.62
    /// Ob der Finger dreht - oder nur auf einem Raum liegt.
    @State private var zieht = false

    private typealias G = Hausgeometrie

    /// Die Hoehe eines Decks in Metern, und der Abstand zwischen zwei Decks. Nicht aus dem Plan:
    /// der Dienst liefert Grundrisse, keine Raumhoehen.
    private let deckhoehe = 2.6
    private let abstand = 0.5

    /// Unter so vielen Punkten je Meter steht in einem Schild nur noch die Temperatur.
    private let nameAb = 27.0
    /// Nebenräume stehen erst ab hier überhaupt da.
    private let kleinAb = 30.0

    var body: some View {
        GeometryReader { raum in
            let maß = masstab(in: raum.size)
            ZStack(alignment: .topLeading) {
                // Der Himmel der Vorlage ist eine einzige flache Farbe, gleich der Karte.
                Color(Farbwert(0x0B2E3F))
                // **Das Bild atmet, aber nur viermal in der Sekunde.** Die Heizschlangen
                // pulsen über rund viereinhalb Sekunden; dafür reicht es, das Modell alle
                // 250 Millisekunden neu zu malen. Sechzig Bilder je Sekunde wären hundert
                // Flächen zu sortieren je Bild, für eine Bewegung, die niemand so schnell
                // sieht. Heizt kein Raum, steht das Bild still.
                if heizt {
                    TimelineView(.periodic(from: .now, by: 0.25)) { lage in
                        Canvas { gestalt, groesse in
                            zeichne(
                                in: &gestalt, groesse: groesse, maß: maß,
                                takt: lage.date.timeIntervalSinceReferenceDate)
                        }
                    }
                } else {
                    Canvas { gestalt, groesse in
                        zeichne(in: &gestalt, groesse: groesse, maß: maß, takt: 0)
                    }
                }
                // **Die Schilder sind für Finger durchlässig** (`globals.css:472`, mit
                // Begründung: „damit das Tippen die Boeden darunter trifft"). Sie sitzen genau
                // über der Raummitte - also dort, wo man hintippt.
                schilder(maß: maß)
                    .allowsHitTesting(false)
                drehknoepfe
            }
            .contentShape(Rectangle())
            // **Ein Tipp trifft einen Raum** (`HouseScene.ts`, und die Legende der Vorlage
            // sagt es ausdrücklich: „TIPPEN: RAUM"). Das Modell war bis zum 19.11.2026 ein
            // Bild, das man drehen konnte: die Temperatur eines Raums ablesen ja, stellen nur
            // über die Liste.
            //
            // **Tippen und Drehen in einer Geste.** Zwei nebeneinander - `onTapGesture` neben
            // `DragGesture` - streiten sich um jeden Finger, der sich beim Antippen um zwei
            // Punkte bewegt. Die Vorlage misst darum selbst: unter acht Punkten Weg ist es ein
            // Tipp, darüber ein Drehen (`HouseScene.ts`, `pointerup` mit der 8-Punkt-Schwelle).
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { griff in
                        if !zieht,
                           abs(griff.translation.width) + abs(griff.translation.height) > 8
                        {
                            zieht = true
                        }
                        guard zieht else { return }
                        // Eine Bildschirmbreite ist eine halbe Umdrehung: so kommt man mit
                        // einem Wisch um das Haus, ohne dass ein Zittern es herumreisst.
                        drehung = beimZiehenAb + griff.translation.width / raum.size.width * .pi
                    }
                    .onEnded { griff in
                        if zieht {
                            beimZiehenAb = drehung
                            zieht = false
                        } else if let id = raumBei(griff.startLocation, maß: maß) {
                            tippeRaum?(id)
                        }
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vorlesen)
        .accessibilityHint("Mit dem Finger drehen, auf einen Raum tippen zum Stellen.")
    }

    // MARK: - Treffer

    /// Welcher Raum liegt unter diesem Punkt des Schirms?
    ///
    /// **Von vorn nach hinten gesucht.** Zwei Decks nebeneinander überdecken sich nicht, aber
    /// ein Raum und die Platte darunter schon; wer von hinten sucht, trifft den falschen.
    private func raumBei(_ stelle: CGPoint, maß: (punkteJeMeter: Double, mitte: CGPoint)) -> Int? {
        var treffer: (tiefe: Double, id: Int)?
        for deck in gezeigteDecks {
            let v = versatz(von: deck)
            for raum in deck.rooms where !(raum.tech ?? false) {
                // **Ein Teilraum führt auf seinen Hauptraum.** „Essen" ist ein Teil von
                // „Wohnen" und hat keinen eigenen Fühler; wer darauf tippt, meint den Raum,
                // zu dem es gehört (`HouseScene.ts`, `hauptKnoten`).
                let id = raum.roomId
                    ?? raum.partOf.flatMap { name in
                        deck.rooms.first { $0.name == name }?.roomId
                    }
                guard let id else { continue }
                let ecken: [(x: Double, y: Double, z: Double)] = [
                    (raum.x0 + v.x, 0, raum.z0 + v.z), (raum.x1 + v.x, 0, raum.z0 + v.z),
                    (raum.x1 + v.x, 0, raum.z1 + v.z), (raum.x0 + v.x, 0, raum.z1 + v.z),
                ]
                let auf = ecken.map { punkt($0.x, $0.y, $0.z, maß) }
                    .map { (x: Double($0.x), y: Double($0.y)) }
                guard G.imVieleck((x: Double(stelle.x), y: Double(stelle.y)), auf) else {
                    continue
                }
                let t = tiefe(ecken)
                if treffer == nil || t > treffer!.tiefe { treffer = (t, id) }
            }
        }
        return treffer?.id
    }

    // MARK: - Welche Decks

    private var gezeigteDecks: [Deck] {
        guard let sichtbaresDeck else { return plan.decks }
        return plan.decks.filter { $0.key == sichtbaresDeck }
    }

    /// Wo ein Deck steht.
    ///
    /// **Nebeneinander, nicht übereinander** (`HouseScene.ts`, `anordnen`: „Die Decks
    /// nebeneinander (quer) oder untereinander (hochkant), im Bildschirm gemessen"). Zwei
    /// Grundrisse übereinander sind zwei Grundrisse, von denen man einen sieht; nebeneinander
    /// sind es zwei Häuser, die man vergleichen kann.
    ///
    /// **Gemessen wird auf dem Schirm, versetzt wird in der Welt.** Der Abstand ist die Breite
    /// des vorigen Decks auf dem Schirm plus 3,6 Meter; zurückgedreht wird er, damit die
    /// beiden nebeneinander bleiben, egal wie das Haus steht.
    private func versatz(von deck: Deck) -> (x: Double, z: Double) {
        guard sichtbaresDeck == nil,
              let i = gezeigteDecks.firstIndex(where: { $0.key == deck.key }), i > 0
        else { return (0, 0) }
        var lauf = 0.0
        for vor in gezeigteDecks.prefix(i) {
            lauf += ausdehnung(vor).breite + 3.6
        }
        let c = cos(drehung)
        let sn = sin(drehung)
        return (x: lauf * c, z: -lauf * sn)
    }

    /// Der Umriss, der ein Deck im Bild beansprucht: die Grundplatte, sonst die Huelle.
    private func umriss(_ deck: Deck) -> [[Double]] {
        let p = deck.plate ?? []
        return p.count >= 3 ? p : deck.shell
    }

    /// Wie breit und hoch ein Deck auf dem Schirm steht, in Metern der Bildebene.
    private func ausdehnung(_ deck: Deck) -> (breite: Double, hoehe: Double) {
        var links = Double.infinity, rechts = -Double.infinity
        var unten = Double.infinity, oben = -Double.infinity
        for ecke in umriss(deck) where ecke.count >= 2 {
            for hoch in [0.0, deckhoehe] {
                let p = G.bildschirm(x: ecke[0], y: hoch, z: ecke[1], drehung: drehung)
                links = min(links, p.sx)
                rechts = max(rechts, p.sx)
                unten = min(unten, p.su)
                oben = max(oben, p.su)
            }
        }
        guard links.isFinite, rechts > links else { return (0, 0) }
        return (rechts - links, oben - unten)
    }

    // MARK: - Masstab

    /// Wie viele Punkte ein Meter ist, und wo die Mitte liegt – fuer die aktuelle Drehung.
    private func masstab(in flaeche: CGSize) -> (punkteJeMeter: Double, mitte: CGPoint) {
        var links = Double.infinity, rechts = -Double.infinity
        var unten = Double.infinity, oben = -Double.infinity
        for deck in gezeigteDecks {
            let v = versatz(von: deck)
            // **Gemessen wird die Grundplatte, nicht die Huelle** (`HouseScene.ts`,
            // `ausschnittBerechnen`: `plate ?? shell`, um 1,5 m erweitert). Im Plan dieses
            // Hauses reicht die Platte bis zu 5,4 m ueber die Huelle hinaus - Terrasse, Hof,
            // Auto, Wallbox und die Waermepumpe bei x = 13 liegen draussen. Wer nur die Huelle
            // misst, zeichnet sie ausserhalb des Bildes.
            for ecke in umriss(deck) where ecke.count >= 2 {
                for hoch in [0.0, deckhoehe] {
                    let p = G.bildschirm(
                        x: ecke[0] + v.x, y: hoch, z: ecke[1] + v.z, drehung: drehung)
                    links = min(links, p.sx - 1.5)
                    rechts = max(rechts, p.sx + 1.5)
                    unten = min(unten, p.su - 1.5)
                    oben = max(oben, p.su + 1.5)
                }
            }
        }
        guard links.isFinite, rechts > links, oben > unten else {
            return (12, CGPoint(x: flaeche.width / 2, y: flaeche.height / 2))
        }
        let rand = 14.0
        let maß = min(
            (flaeche.width - 2 * rand) / (rechts - links),
            (flaeche.height - 2 * rand) / (oben - unten)
        )
        return (
            maß,
            CGPoint(
                x: flaeche.width / 2 - (links + rechts) / 2 * maß,
                y: flaeche.height / 2 + (unten + oben) / 2 * maß
            )
        )
    }

    private func punkt(
        _ x: Double, _ y: Double, _ z: Double, _ maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) -> CGPoint {
        let p = G.bildschirm(x: x, y: y, z: z, drehung: drehung)
        return CGPoint(
            x: maß.mitte.x + p.sx * maß.punkteJeMeter,
            y: maß.mitte.y - p.su * maß.punkteJeMeter
        )
    }

    // MARK: - Alles, was gemalt wird

    /// Eine fertige Fläche: Punkte in Modellkoordinaten, Farbe, Tiefe.
    private struct Malstueck {
        let ecken: [(x: Double, y: Double, z: Double)]
        let tiefe: Double
        let farbe: Color
        let kante: Color?
        let strich: Double
        /// Nur Linien, keine Fläche.
        let offen: Bool
    }

    /// Heizt ueberhaupt ein Raum? Nur dann muss das Bild sich bewegen.
    private var heizt: Bool {
        raeume.values.contains { ($0.valve ?? 0) > 0 }
    }

    private func zeichne(
        in gestalt: inout GraphicsContext, groesse: CGSize,
        maß: (punkteJeMeter: Double, mitte: CGPoint), takt: Double
    ) {
        for deck in gezeigteDecks {
            var roh: [Malstueck] = []
            sammle(deck, y: 0, takt: takt, in: &roh)
            let v = versatz(von: deck)
            let stuecke = (v.x == 0 && v.z == 0)
                ? roh
                : roh.map { st in
                    Malstueck(
                        ecken: st.ecken.map { (x: $0.x + v.x, y: $0.y, z: $0.z + v.z) },
                        tiefe: st.tiefe, farbe: st.farbe, kante: st.kante, strich: st.strich,
                        offen: st.offen)
                }
            // **Von hinten nach vorn.** Ohne das steht ein Bett vor der Wand, hinter der es
            // steht.
            for s in stuecke.sorted(by: { $0.tiefe < $1.tiefe }) {
                var pfad = Path()
                let punkte = s.ecken.map { punkt($0.x, $0.y, $0.z, maß) }
                guard let erster = punkte.first else { continue }
                pfad.move(to: erster)
                for p in punkte.dropFirst() { pfad.addLine(to: p) }
                if !s.offen { pfad.closeSubpath() }
                if !s.offen { gestalt.fill(pfad, with: .color(s.farbe)) }
                if let kante = s.kante {
                    gestalt.stroke(
                        pfad, with: .color(kante),
                        style: StrokeStyle(lineWidth: s.strich, lineJoin: .round))
                }
            }
        }
    }

    private func tiefe(_ ecken: [(x: Double, y: Double, z: Double)]) -> Double {
        let blick = G.strahl(drehung: drehung)
        let n = Double(max(1, ecken.count))
        let mx = ecken.reduce(0) { $0 + $1.x } / n
        let my = ecken.reduce(0) { $0 + $1.y } / n
        let mz = ecken.reduce(0) { $0 + $1.z } / n
        return mx * blick.0 + my * blick.1 + mz * blick.2
    }

    private func sammle(
        _ deck: Deck, y: Double, takt: Double, in stuecke: inout [Malstueck]
    ) {
        // 1. Die Platte, auf der das Deck steht.
        if let platte = G.umgrenzung(deck.plate ?? deck.shell) {
            let rand = 1.3
            let ecken: [(x: Double, y: Double, z: Double)] = [
                (platte.x0 - rand, y - 0.02, platte.z0 - rand),
                (platte.x1 + rand, y - 0.02, platte.z0 - rand),
                (platte.x1 + rand, y - 0.02, platte.z1 + rand),
                (platte.x0 - rand, y - 0.02, platte.z1 + rand),
            ]
            stuecke.append(
                Malstueck(
                    ecken: ecken, tiefe: tiefe(ecken) - 1000, farbe: Color(Farbwert(0x0B2A3A)),
                    kante: Color(Hausmodell.amber.mitDeckung(0.4)), strich: 1, offen: false))
        }

        // 1b. Das Meterraster auf der Platte.
        //
        // **Es gibt dem Bild seinen Plancharakter** (`HouseScene.ts`, `rasterTextur`): ohne
        // das Raster ist die Platte eine dunkle Flaeche, mit ihm ist sie Gelaende mit einem
        // Mass. Je ein Strich auf den Meter, sehr blass - es soll unter dem Haus liegen, nicht
        // mit ihm um Aufmerksamkeit streiten.
        if let platte = G.umgrenzung(deck.plate ?? deck.shell) {
            let rand = 1.3
            let x0 = platte.x0 - rand, x1 = platte.x1 + rand
            let z0 = platte.z0 - rand, z1 = platte.z1 + rand
            let strichfarbe = Color(Farbwert(0xA9ECFF, deckung: 0.07))
            for x in stride(from: x0.rounded(.up), through: x1, by: 1) {
                let ecken: [(x: Double, y: Double, z: Double)] =
                    [(x, y - 0.015, z0), (x, y - 0.015, z1)]
                stuecke.append(
                    Malstueck(
                        ecken: ecken, tiefe: tiefe(ecken) - 900, farbe: .clear,
                        kante: strichfarbe, strich: 0.5, offen: true))
            }
            for z in stride(from: z0.rounded(.up), through: z1, by: 1) {
                let ecken: [(x: Double, y: Double, z: Double)] =
                    [(x0, y - 0.015, z), (x1, y - 0.015, z)]
                stuecke.append(
                    Malstueck(
                        ecken: ecken, tiefe: tiefe(ecken) - 900, farbe: .clear,
                        kante: strichfarbe, strich: 0.5, offen: true))
            }
        }

        // 2. Die Boeden der Raeume, in der Farbe ihrer Temperatur.
        //
        // **Eine Platte, keine Flaeche** (`HouseScene.ts`: `BoxGeometry(b, BODEN_D, t)`). Ein
        // Boden ohne Dicke hat im Schraegblick keine Kante, und ohne die Kanten verliert das
        // ganze Bild sein Relief: die Moebel stehen dann nicht auf etwas, sondern daneben.
        //
        // **Ausgelassen werden nur Lufttraeume** (`open`), nicht die Technikraeume: auch die
        // haben einen Fussboden.
        for raum in deck.rooms where !(raum.open ?? false) {
            let grad = raum.roomId.flatMap { raeume[$0]?.tempC }
            let farbe = Hausmodell.bodenfarbe(raum, grad: grad)
            let grundriss: [(x: Double, z: Double)] = [
                (raum.x0 + 0.01, raum.z0 + 0.01), (raum.x1 - 0.01, raum.z0 + 0.01),
                (raum.x1 - 0.01, raum.z1 - 0.01), (raum.x0 + 0.01, raum.z1 - 0.01),
            ]
            for f in G.prisma(
                grundriss: grundriss, y: y, hoehe: Hausmodell.bodenDicke, drehung: drehung)
            {
                stuecke.append(
                    Malstueck(
                        ecken: f.ecken, tiefe: f.tiefe - (f.obenauf ? 500 : 520),
                        farbe: Color(farbe).opacity(farbe.deckung * (0.62 + 0.38 * f.licht)),
                        kante: Color(Farbe.linie1), strich: 0.6, offen: false))
            }
        }

        // 2b. Die Fliesen und die Heizschlangen.
        //
        // **Beides liegt auf dem Boden, nicht darin** - ein Haar ueber ihm, damit es ihn nicht
        // durchschneidet. Die Fliesen geben dem Boden eine Oberflaeche; die Schlange sagt, wo
        // gerade geheizt wird, und das ist die Auskunft, wegen der man auf das Modell sieht.
        for raum in deck.rooms where !(raum.open ?? false) {
            let oben = y + Hausmodell.bodenDicke
            if raum.tiles == true {
                for f in Hausmodell.fliesen(x0: raum.x0, z0: raum.z0, x1: raum.x1, z1: raum.z1) {
                    // Die halbe Diagonale einer Raute, deren Mitten 0,36 m auseinander
                    // liegen: 0,36 / Wurzel 2. Mit der Hälfte davon klaffen zwischen den
                    // Feldern Lücken - ein Punktfeld statt eines Schachbretts.
                    let halb = Hausmodell.fliesenkante * (0.5).squareRoot()
                    let ecken: [(x: Double, y: Double, z: Double)] = [
                        (f.x, oben + 0.006, f.z - halb),
                        (f.x + halb, oben + 0.006, f.z),
                        (f.x, oben + 0.006, f.z + halb),
                        (f.x - halb, oben + 0.006, f.z),
                    ]
                    stuecke.append(
                        Malstueck(
                            ecken: ecken, tiefe: tiefe(ecken) - 480,
                            farbe: f.hell
                                ? Color(Farbwert(0xFFFFFF, deckung: 0.035))
                                : Color(Farbwert(0x040E16, deckung: 0.13)),
                            kante: nil, strich: 0, offen: false))
                }
            }
            let glut = Hausmodell.heizglut(
                ventil: raum.roomId.flatMap { raeume[$0]?.valve },
                takt: takt, versatz: raum.x0)
            guard glut > 0 else { continue }
            let weg = Hausmodell.heizschlange(
                x0: raum.x0, z0: raum.z0, x1: raum.x1, z1: raum.z1)
            guard weg.count > 1 else { continue }
            stuecke.append(
                Malstueck(
                    ecken: weg.map { (x: $0.x, y: oben + 0.012, z: $0.z) },
                    tiefe: tiefe(weg.map { (x: $0.x, y: oben + 0.012, z: $0.z) }) - 450,
                    farbe: .clear,
                    kante: Color(Farbwert(0xFFC85A, deckung: min(1, glut))),
                    strich: 2.2, offen: true))
        }

        // 3. Die Moebel und das Gelaende.
        for stueck in deck.items {
            for teil in Hausmodell.teile(stueck) {
                sammle(teil, deckhoehe: y, in: &stuecke)
            }
        }

        // 4. Die Waende.
        for w in G.wandstuecke(deck) {
            let hoch = w.aussen ? Hausmodell.aussenHoehe : Hausmodell.wandHoehe
            let dicke = w.aussen ? 0.14 : 0.08
            let grundriss: [(x: Double, z: Double)] =
                w.senkrecht
                ? [
                    (w.konst - dicke / 2, w.a), (w.konst + dicke / 2, w.a),
                    (w.konst + dicke / 2, w.b), (w.konst - dicke / 2, w.b),
                ]
                : [
                    (w.a, w.konst - dicke / 2), (w.a, w.konst + dicke / 2),
                    (w.b, w.konst + dicke / 2), (w.b, w.konst - dicke / 2),
                ]
            let farbe = w.aussen
                ? Farbwert(0xDFF2F8, deckung: 0.24) : Farbwert(0xCFE9F2, deckung: 0.16)
            for f in G.prisma(
                grundriss: grundriss, y: y + Hausmodell.bodenDicke, hoehe: hoch, drehung: drehung)
            {
                stuecke.append(
                    Malstueck(
                        ecken: f.ecken, tiefe: f.tiefe,
                        farbe: Color(farbe).opacity(farbe.deckung * (0.55 + 0.45 * f.licht)),
                        kante: Color(Hausmodell.kante.mitDeckung(w.aussen ? 0.5 : 0.28)),
                        strich: 0.6, offen: false))
            }
        }

        // 5. Fenster und Tueren.
        for o in deck.openings {
            sammle(o, y: y, in: &stuecke)
        }

        // 6. Die Kontakte, die melden.
        for k in deck.contacts {
            sammle(k, y: y, in: &stuecke)
        }

        // 7. Gelaender.
        for raum in deck.rooms {
            guard let seiten = raum.railing, !seiten.isEmpty else { continue }
            sammleGelaender(raum, seiten: seiten, y: y, in: &stuecke)
        }
    }

    /// Ein Körper des Hausmodells, in Flächen zerlegt.
    private func sammle(_ teil: Hausmodell.Teil, deckhoehe y: Double, in stuecke: inout [Malstueck])
    {
        let grund = y + teil.y
        switch teil.form {
        case .quader(let b, let h, let t, let winkel):
            for f in G.quader(
                x: teil.x, y: grund, z: teil.z, b: b, hoehe: h, t: t, drehung: drehung,
                winkel: winkel)
            {
                stuecke.append(flaeche(f, teil: teil))
            }
        case .zylinder(let r, let h):
            for f in G.zylinder(
                x: teil.x, y: grund, z: teil.z, halbmesser: r, hoehe: h, drehung: drehung)
            {
                stuecke.append(flaeche(f, teil: teil))
            }
        case .ebene(let b, let t, let winkel):
            for f in G.quader(
                x: teil.x, y: grund, z: teil.z, b: b, hoehe: 0, t: t, drehung: drehung,
                winkel: winkel) where f.obenauf
            {
                stuecke.append(flaeche(f, teil: teil))
            }
        case .linien(let zuege):
            for zug in zuege {
                let ecken = zug.map { (x: $0.x, y: y + $0.y, z: $0.z) }
                stuecke.append(
                    Malstueck(
                        ecken: ecken, tiefe: tiefe(ecken), farbe: .clear,
                        kante: Color(teil.farbe), strich: teil.leuchtet ? 2 : 1, offen: true))
            }
        }
    }

    private func flaeche(_ f: Hausgeometrie.Flaeche, teil: Hausmodell.Teil) -> Malstueck {
        // Das Licht faellt auf den Deckel; die Seiten sind gestuft. So behaelt ein Glaskoerper
        // seine Form, auch wenn er durchsichtig ist.
        let farbe = Color(teil.farbe).opacity(teil.farbe.deckung * (0.5 + 0.5 * f.licht))
        return Malstueck(
            ecken: f.ecken, tiefe: f.tiefe, farbe: farbe,
            kante: teil.kanten ? Color(Hausmodell.kante.mitDeckung(0.28)) : nil,
            strich: 0.5, offen: false)
    }

    private func sammle(_ o: Opening, y: Double, in stuecke: inout [Malstueck]) {
        let linie = G.wandlinie(o)
        let tuer = o.door ?? false
        let unten = y + Hausmodell.bodenDicke + (tuer ? 0 : 0.4)
        let hoch = tuer ? Hausmodell.wandHoehe + 0.1 : 0.7
        let farbe = tuer
            ? Farbwert(0xD9E7EC, deckung: 0.55) : Farbwert(0xBFEEFF, deckung: 0.5)
        let ecken: [(x: Double, y: Double, z: Double)] =
            linie.senkrecht
            ? [
                (linie.konst, unten, o.a), (linie.konst, unten, o.b),
                (linie.konst, unten + hoch, o.b), (linie.konst, unten + hoch, o.a),
            ]
            : [
                (o.a, unten, linie.konst), (o.b, unten, linie.konst),
                (o.b, unten + hoch, linie.konst), (o.a, unten + hoch, linie.konst),
            ]
        stuecke.append(
            Malstueck(
                ecken: ecken, tiefe: tiefe(ecken) + 0.02, farbe: Color(farbe),
                kante: Color(Hausmodell.kante.mitDeckung(0.5)), strich: 0.6, offen: false))
    }

    private func sammle(_ k: Contact, y: Double, in stuecke: inout [Malstueck]) {
        let zustand = kontakte[k.key]
        let offen = zustand?.open == true
        let senkrecht = k.side == .w || k.side == .o
        let tuer = k.door ?? false
        let unten = y + Hausmodell.bodenDicke + (tuer ? 0 : 0.4)
        let hoch = tuer ? Hausmodell.wandHoehe + 0.1 : 0.7
        let ecken: [(x: Double, y: Double, z: Double)] =
            senkrecht
            ? [
                (k.at, unten, k.a), (k.at, unten, k.b),
                (k.at, unten + hoch, k.b), (k.at, unten + hoch, k.a),
            ]
            : [
                (k.a, unten, k.at), (k.b, unten, k.at),
                (k.b, unten + hoch, k.at), (k.a, unten + hoch, k.at),
            ]
        // Ein offener Kontakt leuchtet. Scharf gestellt und offen ist Alarm - und das ist die
        // einzige Stelle in diesem Bild, die rot sein darf.
        let farbe: Farbwert =
            offen
            ? (alarmScharf ? Farbwert(0xFF3B3B) : Hausmodell.amber)
            : Farbwert(0xBFEEFF, deckung: 0.25)
        stuecke.append(
            Malstueck(
                ecken: ecken, tiefe: tiefe(ecken) + 0.03,
                farbe: Color(farbe).opacity(offen ? 0.55 : 0.18),
                kante: Color(farbe), strich: offen ? 1.6 : 0.6, offen: false))
    }

    /// Ein Geländer: senkrechte Stäbe alle 40 cm und ein Handlauf.
    private func sammleGelaender(
        _ raum: Room, seiten: String, y: Double, in stuecke: inout [Malstueck]
    ) {
        let hoch = 0.5
        let fuss = y + Hausmodell.bodenDicke
        for seite in seiten {
            let (a, b, konst, senkrecht): (Double, Double, Double, Bool)
            switch seite {
            case "n": (a, b, konst, senkrecht) = (raum.x0, raum.x1, raum.z0, false)
            case "s": (a, b, konst, senkrecht) = (raum.x0, raum.x1, raum.z1, false)
            case "w": (a, b, konst, senkrecht) = (raum.z0, raum.z1, raum.x0, true)
            case "o": (a, b, konst, senkrecht) = (raum.z0, raum.z1, raum.x1, true)
            default: continue
            }
            func p(_ laengs: Double, _ hoehe: Double) -> (x: Double, y: Double, z: Double) {
                senkrecht ? (konst, hoehe, laengs) : (laengs, hoehe, konst)
            }
            let weiss = Color(Farbwert(0xFFFFFF, deckung: 0.75))
            let handlauf = [p(a, fuss + hoch), p(b, fuss + hoch)]
            stuecke.append(
                Malstueck(
                    ecken: handlauf, tiefe: tiefe(handlauf) + 0.05, farbe: .clear,
                    kante: weiss, strich: 1, offen: true))
            let n = max(2, Int((abs(b - a) / 0.4).rounded()))
            for i in 0...n {
                let s = a + (b - a) * Double(i) / Double(n)
                let stab = [p(s, fuss), p(s, fuss + hoch)]
                stuecke.append(
                    Malstueck(
                        ecken: stab, tiefe: tiefe(stab) + 0.05, farbe: .clear, kante: weiss,
                        strich: 1, offen: true))
            }
        }
    }

    // MARK: - Die Schilder

    @ViewBuilder private func schilder(maß: (punkteJeMeter: Double, mitte: CGPoint)) -> some View {
        let nah = maß.punkteJeMeter
        ForEach(Array(gezeigteDecks.enumerated()), id: \.offset) { _, deck in
            let v = versatz(von: deck)
            let y = 0.0
            // Der Name des Decks, unten links neben seiner Platte.
            if let platte = G.umgrenzung(deck.plate ?? deck.shell) {
                ort(deck.name, farbe: Farbwert(0xA9ECFF, deckung: 0.55), sperrung: 2.2)
                    .position(punkt(platte.x0 - 1.4 + v.x, y + 0.05, platte.z1 + 1.4 + v.z, maß))
            }
            // Die Orte: GARTEN, TERRASSE, INNENHOF.
            ForEach(Array(deck.places.enumerated()), id: \.offset) { _, p in
                ort(p.text, farbe: Farbwert(0xA9ECFF, deckung: 0.38), sperrung: 2.6)
                    .position(punkt(p.x + v.x, y + 0.02, p.z + v.z, maß))
            }
            // Die Raumschilder.
            ForEach(Array(deck.rooms.enumerated()), id: \.offset) { _, raum in
                if zeigeSchild(raum, nah: nah) {
                    raumschild(raum, nah: nah)
                        .position(
                            punkt(
                                (raum.x0 + raum.x1) / 2 + v.x, y + 1.25,
                                (raum.z0 + raum.z1) / 2 + v.z, maß))
                }
            }
            // Die Geraeteschilder.
            ForEach(Array(deck.items.enumerated()), id: \.offset) { _, stueck in
                if let schild = geraeteschild(stueck) {
                    schild.0
                        .position(
                            punkt(schild.1.x + v.x, y + schild.1.y, schild.1.z + v.z, maß))
                }
            }
        }
    }

    /// **Welcher Raum ein Schild bekommt.** Teilräume und stille Räume keines; Nebenräume erst,
    /// wenn das Bild groß genug ist, sie zu tragen.
    private func zeigeSchild(_ raum: Room, nah: Double) -> Bool {
        if raum.silent == true || raum.partOf != nil { return false }
        if raum.minor == true, nah < kleinAb { return false }
        return true
    }

    private func ort(_ text: String, farbe: Farbwert, sperrung: Double) -> some View {
        Text(text.uppercased())
            .font(.custom("IBMPlexMono", size: 10))
            .tracking(sperrung)
            .foregroundStyle(Color(farbe))
            .fixedSize()
    }

    /// Ein Raumschild: Temperatur groß, Name klein und gesperrt daneben.
    ///
    /// **Der Name verschwindet im Kleinen**, so wie in der Vorlage: unter 27 Punkten je Meter
    /// steht nur noch die Zahl. Dreizehn Namen auf einem Telefon sind kein Beschriftung,
    /// sondern ein Teppich.
    private func raumschild(_ raum: Room, nah: Double) -> some View {
        let grad = raum.roomId.flatMap { raeume[$0]?.tempC }
        let ziel = raum.roomId.flatMap { raeume[$0]?.targetC ?? raeume[$0]?.setpointC }
        let unterZiel = grad != nil && ziel != nil && grad! < ziel! - 0.3
        let stumm = raum.roomId != nil && grad == nil
        let klein = raum.minor == true
        return HStack(alignment: .firstTextBaseline, spacing: 7) {
            if raum.roomId != nil {
                Text(grad.map { Formate.zahl($0, stellen: 1) + "°" } ?? "-")
                    .font(.custom("IBMPlexMono", size: klein ? 11 : 14))
                    .foregroundStyle(
                        stumm
                            ? Farbe.text3
                            : (unterZiel ? Color(Farbwert(0xFFD27A)) : Color(Farbwert(0xFFFFFF)))
                    )
            }
            if nah >= nameAb || raum.roomId == nil {
                Text(raum.name.uppercased())
                    .font(.custom("IBMPlexMono", size: 9))
                    .tracking(1.4)
                    .foregroundStyle(Color(Farbwert(0xBFD3DA)))
            }
        }
        .padding(.vertical, klein ? 3 : 4)
        .padding(.horizontal, klein ? 7 : 10)
        .background(
            Capsule().fill(Color(Farbwert(0x07202C, deckung: 0.78)))
                .overlay(Capsule().strokeBorder(Color(Farbwert(0xA9ECFF, deckung: 0.22)), lineWidth: 1))
        )
        .opacity(raum.cold == true || raum.tech == true ? 0.75 : 1)
        .fixedSize()
    }

    /// Wärmepumpe, Puffer und Wallbox tragen ihre Zahl im Bild.
    private func geraeteschild(_ it: Item)
        -> (AnyView, (x: Double, y: Double, z: Double))?
    {
        let x = it.x ?? 0
        let z = it.z ?? 0
        switch it.kind {
        case .heatPump:
            let richtung = it.dir ?? .n
            let dx = richtung == .o ? 1.287 : (richtung == .w ? -1.287 : 0)
            let dz = richtung == .s ? 1.287 : (richtung == .n ? -1.287 : 0)
            return (
                AnyView(
                    technikschild(
                        it.label ?? "Wärmepumpe",
                        wert: waermepumpeKw.map { Formate.zahl($0, stellen: 1) + " kW" })),
                (x + dx, 0.1, z + dz)
            )
        case .buffer:
            return (
                AnyView(
                    technikschild(
                        it.label ?? "Puffer",
                        wert: pufferSoc.map { "\(Int(($0 * 100).rounded())) %" })),
                (x, 2.75, z)
            )
        case .wallbox:
            return (
                AnyView(
                    technikschild(
                        it.label ?? "Wallbox",
                        wert: wallboxKw.map { Formate.zahl($0, stellen: 1) + " kW" })),
                (x, 0.2, z + 1.1)
            )
        default:
            return nil
        }
    }

    private func technikschild(_ name: String, wert: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(wert ?? "-")
                .font(.custom("IBMPlexMono", size: 13))
                .foregroundStyle(Farbe.amber)
            Text(name.uppercased())
                .font(.custom("IBMPlexMono", size: 9))
                .tracking(1.4)
                .foregroundStyle(Color(Farbwert(0xBFD3DA)))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule().fill(Color(Farbwert(0x07202C, deckung: 0.78)))
                .overlay(
                    Capsule().strokeBorder(
                        Color(Hausmodell.amber.mitDeckung(0.4)), lineWidth: 1))
        )
        .fixedSize()
    }

    /// Zwei Knöpfe, die in Vierteldrehungen drehen – wie im Dashboard.
    private var drehknoepfe: some View {
        HStack(spacing: 6) {
            knopf("↺") { dreheUm(-1) }
            knopf("↻") { dreheUm(1) }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func knopf(_ zeichen: String, _ tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Text(zeichen)
                .font(.system(size: 15))
                .foregroundStyle(Farbe.text2)
                .frame(width: 34, height: 30)
                .background(Capsule().fill(Color(Farbwert(0x0F2E3D, deckung: 0.72))))
                .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(zeichen == "↺" ? "Nach links drehen" : "Nach rechts drehen")
    }

    private func dreheUm(_ richtung: Double) {
        withAnimation(.easeInOut(duration: 0.45)) {
            drehung += richtung * .pi / 2
            beimZiehenAb = drehung
        }
    }

    // MARK: - Vorlesen

    private var vorlesen: String {
        let namen = gezeigteDecks.flatMap(\.rooms)
            .filter { !($0.minor ?? false) && $0.partOf == nil }
            .compactMap { raum -> String? in
                guard let id = raum.roomId, let t = raeume[id]?.tempC else { return nil }
                return "\(raum.name) \(Formate.celsius(t, stellen: 1))"
            }
        let offen = kontakte.values.filter { $0.open == true }.count
        return "Hausmodell. " + namen.joined(separator: ", ")
            + (offen > 0 ? ". \(offen) Fenster oder Türen offen." : "")
    }
}
