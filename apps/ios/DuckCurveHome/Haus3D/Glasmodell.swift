import DuckCurveKit
import SwiftUI

/// Das Haus als Glasmodell: die Decks uebereinander, von der Seite gesehen.
///
/// **Kein SceneKit.** Die Begruendung steht in `Hausgeometrie` im Kern und ist kurz: die Vorlage
/// zeichnet mit einer *orthographischen* Kamera und rechnet die Lage jedes Punkts mit einer
/// Kavalierprojektion. Das ist keine Szene, die gerendert werden muss, sondern eine Zeichnung
/// mit ausgerechneten Koordinaten - und die rechnet der Kern, geprueft, in 29 Tests. Hier wird
/// sie nur noch gezogen.
///
/// Was dabei fehlt und was nicht: die Beleuchtung und das additiv ueberblendete Glimmen der Glut
/// sind weg - Stimmung, keine Auskunft. Die Geometrie, die Raumtemperaturen als Bodenfarbe, die
/// Kontakte und der Alarm sind da.
///
/// **Das Modell laesst sich drehen.** Mit dem Finger, um die Hochachse. Das ist nicht Spielerei:
/// ein Haus von einer Seite zeigt die Raeume dahinter nicht, und wer wissen will, ob im
/// Gaestezimmer das Fenster offen ist, muss um die Ecke sehen koennen.
struct Glasmodell: View {
    let plan: HousePlan
    /// Die Raeume mit ihren Temperaturen, nach Raumkennung.
    let raeume: [Int: RoomLiveOut]
    /// Die Kontakte, nach Schluessel.
    let kontakte: [String: HouseContactOut]
    var alarmScharf: Bool = false
    /// Welches Deck gezeigt wird. `nil` heisst: alle uebereinander.
    var sichtbaresDeck: String?

    /// Die Drehung des Grundrisses. Die Vorgabe zeigt die Suedwestecke - dort ist die Terrasse.
    @State private var drehung: Double = 0.62
    @State private var beimZiehenAb: Double = 0.62

    private typealias G = Hausgeometrie

    /// Die Hoehe eines Decks in Metern, und der Abstand zwischen zwei Decks. Nicht aus dem Plan:
    /// der Dienst liefert Grundrisse, keine Raumhoehen.
    private let deckhoehe = 2.6
    private let abstand = 0.5

    var body: some View {
        GeometryReader { raum in
            let maß = masstab(in: raum.size)
            Canvas { gestalt, groesse in
                zeichne(in: &gestalt, groesse: groesse, maß: maß)
            }
            .gesture(
                DragGesture()
                    .onChanged { griff in
                        // Eine Bildschirmbreite ist eine halbe Umdrehung: so kommt man mit einem
                        // Wisch um das Haus, ohne dass ein Zittern es herumreisst.
                        drehung = beimZiehenAb + griff.translation.width / raum.size.width * .pi
                    }
                    .onEnded { _ in beimZiehenAb = drehung }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vorlesen)
        .accessibilityHint("Mit dem Finger drehen.")
    }

    // MARK: - Masstab

    /// Wie viele Punkte ein Meter ist, und wo die Mitte liegt.
    ///
    /// **Fuer die aktuelle Drehung, und das war einmal anders.** Der Massstab kam aus der
    /// Vereinigung ueber acht Drehungen, damit das Haus beim Ziehen nicht atmet. Der Preis
    /// dafuer war, dass immer die unguenstigste Drehung die Groesse bestimmt: ein langes,
    /// winkelfoermiges Haus steht quer gesehen fast doppelt so breit da wie ueber Eck, und
    /// damit war es in jeder anderen Drehung klein. Auf dem Telefon fuellte es ein Drittel der
    /// Karte, der Rest war leer, und die Namen der Raeume lagen uebereinander, weil zwischen
    /// den beiden Decks keine dreissig Punkte blieben (Screenshot vom 17.11.).
    ///
    /// Jetzt fuellt es die Karte in jeder Drehung. Beim Ziehen wird es dadurch groesser und
    /// kleiner - das ist eine ruhige, stetige Bewegung und kein Springen, denn die Ausdehnung
    /// aendert sich stetig mit dem Winkel.
    private func masstab(in flaeche: CGSize) -> (punkteJeMeter: Double, mitte: CGPoint) {
        var links = Double.infinity, rechts = -Double.infinity
        var unten = Double.infinity, oben = -Double.infinity
        for (stelle, deck) in gezeigteDecks.enumerated() {
            let y = Double(stelle) * (deckhoehe + abstand)
            for ecke in deck.shell where ecke.count >= 2 {
                for hoehe in [y, y + deckhoehe] {
                    let p = G.bildschirm(x: ecke[0], y: hoehe, z: ecke[1], drehung: drehung)
                    links = min(links, p.sx)
                    rechts = max(rechts, p.sx)
                    unten = min(unten, p.su)
                    oben = max(oben, p.su)
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
        // `punkt` rechnet x = mitte.x + sx*maß und y = mitte.y - su*maß - daher die Vorzeichen.
        return (
            maß,
            CGPoint(
                x: flaeche.width / 2 - (links + rechts) / 2 * maß,
                y: flaeche.height / 2 + (unten + oben) / 2 * maß
            )
        )
    }

    /// Welche Decks gezeichnet werden - alle, oder genau eines.
    private var gezeigteDecks: [Deck] {
        guard let sichtbaresDeck else { return plan.decks }
        return plan.decks.filter { $0.key == sichtbaresDeck }
    }

    /// Die Hoehe, auf der ein Deck liegt. Wird nur eines gezeigt, liegt es unten.
    private func hoehe(von deck: Deck) -> Double {
        guard let i = gezeigteDecks.firstIndex(where: { $0.key == deck.key }) else { return 0 }
        return Double(i) * (deckhoehe + abstand)
    }

    /// Ein Punkt im Haus auf die Zeichenebene.
    ///
    /// **Das Vorzeichen ist hier die ganze Arbeit.** `bildschirm` rechnet `su` nach oben, die
    /// Zeichenebene zaehlt y nach unten. Wer das vergisst, bekommt das Haus auf dem Kopf - und
    /// zwar ein Haus, das sonst richtig aussieht, weshalb man lange sucht.
    private func punkt(
        _ x: Double, _ y: Double, _ z: Double, _ maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) -> CGPoint {
        let p = G.bildschirm(x: x, y: y, z: z, drehung: drehung)
        return CGPoint(
            x: maß.mitte.x + p.sx * maß.punkteJeMeter,
            y: maß.mitte.y - p.su * maß.punkteJeMeter
        )
    }

    // MARK: - Zeichnen

    private func zeichne(
        in gestalt: inout GraphicsContext, groesse: CGSize,
        maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) {
        // Von unten nach oben: so deckt das obere Deck das untere, nicht umgekehrt.
        for deck in gezeigteDecks {
            zeichneDeck(deck, y: hoehe(von: deck), in: &gestalt, maß: maß)
        }
    }

    private func zeichneDeck(
        _ deck: Deck, y: Double, in gestalt: inout GraphicsContext,
        maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) {
        // 1. Die Boeden der Raeume, in der Farbe ihrer Temperatur.
        for raum in deck.rooms where !(raum.tech ?? false) {
            let pfad = viereck(raum, y: y, maß: maß)
            gestalt.fill(pfad, with: .color(bodenfarbe(raum).opacity(0.5)))
            gestalt.stroke(pfad, with: .color(Farbe.linie1), lineWidth: 0.6)
        }

        // 2. Die Aussenhaut als Boden und als Deckel.
        if let huelle = vieleck(deck.shell, y: y, maß: maß) {
            gestalt.stroke(huelle, with: .color(Farbe.linie2), lineWidth: 1.1)
        }

        // 3. Die Waende, jede als senkrechte Flaeche.
        for w in G.wandstuecke(deck) {
            zeichneWand(w, y: y, in: &gestalt, maß: maß)
        }

        // 4. Die Kontakte: ein Strich, der leuchtet, wenn er offen ist.
        for k in deck.contacts {
            zeichneKontakt(k, y: y, in: &gestalt, maß: maß)
        }

        // 5. Die Namen der Raeume - aber nur, wo sie hinpassen.
        //
        // **Was hier vorher stand.** Jeder Raum bekam seinen Namen und seine Temperatur in die
        // Mitte gezeichnet, ohne zu fragen, ob dort Platz ist. Auf dem Telefon ergab das einen
        // Haufen aus dreizehn Woertern in der Bildmitte, in dem kein einziges zu lesen war
        // (Screenshot vom 17.11.): „Schlafen" ueber „Ankleide" ueber „Bad" ueber „18,3 °C".
        //
        // Ein Raum, dessen Grundflaeche auf dem Schirm schmaler ist als sein Name, bekommt
        // keinen. Das ist kein Verlust: er steht in der Liste, die einen Fingerbreit entfernt
        // ist, und ein unlesbares Wort ist schlechter als keines.
        for raum in deck.rooms where !(raum.minor ?? false) && !(raum.tech ?? false) {
            beschrifte(raum, y: y, in: &gestalt, maß: maß)
        }
    }

    private func beschrifte(
        _ raum: Room, y: Double, in gestalt: inout GraphicsContext,
        maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) {
        // Die Grundflaeche des Raumes auf dem Schirm - nicht seine Breite in Metern: unter der
        // Kavalierprojektion wird aus einem quadratischen Zimmer ein schmales Parallelogramm.
        let ecken = [
            punkt(raum.x0, y + 0.02, raum.z0, maß), punkt(raum.x1, y + 0.02, raum.z0, maß),
            punkt(raum.x1, y + 0.02, raum.z1, maß), punkt(raum.x0, y + 0.02, raum.z1, maß),
        ]
        let xs = ecken.map(\.x)
        let ys = ecken.map(\.y)
        guard let links = xs.min(), let rechts = xs.max(),
            let oben = ys.min(), let unten = ys.max()
        else { return }
        let breite = rechts - links
        let hoehe = unten - oben
        let mitte = CGPoint(x: (links + rechts) / 2, y: (oben + unten) / 2)

        var name = gestalt.resolve(
            Text(raum.name).font(Schrift.winzig).foregroundStyle(Farbe.text1))
        name.shading = .color(Farbe.text1)
        let namensmass = name.measure(in: CGSize(width: 400, height: 100))
        guard namensmass.width + 4 <= breite, namensmass.height + 2 <= hoehe else { return }

        let temperatur = raum.roomId.flatMap { raeume[$0]?.tempC }
        guard let t = temperatur else {
            gestalt.draw(name, at: mitte, anchor: .center)
            return
        }
        let zahl = gestalt.resolve(
            Text(Formate.celsius(t, stellen: 1))
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text2))
        let zahlmass = zahl.measure(in: CGSize(width: 400, height: 100))
        // Zwei Zeilen nur, wenn zwei Zeilen hineinpassen. Sonst fuehrt der Name - wo man ist,
        // ist die erste Frage; wie warm es dort ist, die zweite.
        guard namensmass.height + zahlmass.height + 3 <= hoehe,
            zahlmass.width + 4 <= breite
        else {
            gestalt.draw(name, at: mitte, anchor: .center)
            return
        }
        let versatz = (namensmass.height + zahlmass.height + 1) / 2
        gestalt.draw(
            name, at: CGPoint(x: mitte.x, y: mitte.y - versatz + namensmass.height / 2),
            anchor: .center)
        gestalt.draw(
            zahl, at: CGPoint(x: mitte.x, y: mitte.y + versatz - zahlmass.height / 2),
            anchor: .center)
    }

    private func zeichneWand(
        _ w: G.Wandstueck, y: Double, in gestalt: inout GraphicsContext,
        maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) {
        let hoehe = w.aussen ? deckhoehe : deckhoehe * 0.78
        let (a, b) = (w.a, w.b)
        let ecken: [CGPoint] =
            w.senkrecht
            ? [
                punkt(w.konst, y, a, maß), punkt(w.konst, y, b, maß),
                punkt(w.konst, y + hoehe, b, maß), punkt(w.konst, y + hoehe, a, maß),
            ]
            : [
                punkt(a, y, w.konst, maß), punkt(b, y, w.konst, maß),
                punkt(b, y + hoehe, w.konst, maß), punkt(a, y + hoehe, w.konst, maß),
            ]
        var pfad = Path()
        pfad.move(to: ecken[0])
        for p in ecken.dropFirst() { pfad.addLine(to: p) }
        pfad.closeSubpath()
        // Aussenwaende heller: `geometrie.ts` nennt es so, und es gibt dem Glas seine Form.
        gestalt.fill(pfad, with: .color(Farbe.mist.opacity(w.aussen ? 0.17 : 0.09)))
        gestalt.stroke(
            pfad, with: .color(Farbe.linie2.opacity(w.aussen ? 1 : 0.6)), lineWidth: 0.6
        )
    }

    private func zeichneKontakt(
        _ k: Contact, y: Double, in gestalt: inout GraphicsContext,
        maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) {
        let zustand = kontakte[k.key]
        let offen = zustand?.open == true
        let senkrecht = k.side == .w || k.side == .o
        let hoehe = (k.door ?? false) ? 2.05 : 1.3
        let von = senkrecht ? punkt(k.at, y, k.a, maß) : punkt(k.a, y, k.at, maß)
        let bis = senkrecht ? punkt(k.at, y, k.b, maß) : punkt(k.b, y, k.at, maß)
        let obenVon = senkrecht ? punkt(k.at, y + hoehe, k.a, maß) : punkt(k.a, y + hoehe, k.at, maß)
        let obenBis = senkrecht ? punkt(k.at, y + hoehe, k.b, maß) : punkt(k.b, y + hoehe, k.at, maß)

        var pfad = Path()
        pfad.move(to: von)
        pfad.addLine(to: bis)
        pfad.addLine(to: obenBis)
        pfad.addLine(to: obenVon)
        pfad.closeSubpath()

        // Ein offener Kontakt leuchtet. Scharf gestellt und offen ist Alarm - und das ist die
        // einzige Stelle in diesem Bild, die rot sein darf.
        let farbe: Color =
            offen
            ? (alarmScharf ? Farbe.alarm : Farbe.ventilOffen)
            : Farbe.mist.opacity(0.25)
        gestalt.fill(pfad, with: .color(farbe.opacity(offen ? 0.5 : 0.18)))
        gestalt.stroke(pfad, with: .color(farbe), lineWidth: offen ? 1.6 : 0.6)
    }

    // MARK: - Hilfsformen

    private func viereck(
        _ raum: Room, y: Double, maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) -> Path {
        var p = Path()
        p.move(to: punkt(raum.x0, y, raum.z0, maß))
        p.addLine(to: punkt(raum.x1, y, raum.z0, maß))
        p.addLine(to: punkt(raum.x1, y, raum.z1, maß))
        p.addLine(to: punkt(raum.x0, y, raum.z1, maß))
        p.closeSubpath()
        return p
    }

    private func vieleck(
        _ punkte: [[Double]], y: Double, maß: (punkteJeMeter: Double, mitte: CGPoint)
    ) -> Path? {
        let gueltig = punkte.filter { $0.count >= 2 }
        guard gueltig.count >= 3 else { return nil }
        var p = Path()
        p.move(to: punkt(gueltig[0][0], y, gueltig[0][1], maß))
        for ecke in gueltig.dropFirst() {
            p.addLine(to: punkt(ecke[0], y, ecke[1], maß))
        }
        p.closeSubpath()
        return p
    }

    /// Die Farbe des Bodens: die Raumtemperatur, wo es eine gibt.
    ///
    /// Wo keine gemessen ist, bleibt der Boden gedeckt - ein Raum in Blau hiesse „kalt", und das
    /// ist etwas anderes als „nicht gemessen".
    private func bodenfarbe(_ raum: Room) -> Color {
        guard let id = raum.roomId, let t = raeume[id]?.tempC else {
            return Farbe.flaeche3
        }
        return Color(G.bodenfarbe(t))
    }

    private var vorlesen: String {
        let offene = kontakte.values.filter { $0.open == true }
        var s = "Hausmodell mit \(plan.decks.count) Geschossen."
        if offene.isEmpty {
            s += " Alle Fenster und Türen zu."
        } else {
            s += " Offen: " + offene.map(\.name).sorted().joined(separator: ", ") + "."
        }
        if alarmScharf { s += " Alarm ist scharf." }
        return s
    }
}
