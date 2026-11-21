import DuckCurveKit
import SwiftUI

/// Die Heizkurve zum Anfassen: Vorlauf über der Außentemperatur, mit vier Griffen.
///
/// - Der runde Griff links (bei −10 °C) dreht die Kurve: das ist die Steilheit.
/// - Der eckige Griff rechts (bei 18 °C) hebt und senkt sie als Ganzes: die Verschiebung.
/// - Die beiden Linien oben und unten sind der größte und der kleinste Vorlauf; ihr Griff sitzt
///   am rechten Rand.
///
/// Gezeichnet wird die Näherung aus ``Reglerpult``. Hell und dick ist der Entwurf, dünn und
/// gestrichelt, was am Regler gerade steht, und die Punkte sind die Stunden, in denen der
/// Regler wirklich einen Vorlauf verlangt hat (von der Seite „Betrieb“). Ein Griff, dessen
/// Einstellung sich nicht stellen lässt, ist blass und bewegt sich nicht
/// (`apps/web/src/components/waermepumpe/Heizkurve.tsx:8-18`).
///
/// **Gezeichnet wird mit `Canvas`, die Griffe sind echte Ansichten darüber.** Swift Charts
/// kennt keine Griffe, und ein gezeichneter Griff hat keine Trefffläche und keine Stimme für
/// VoiceOver. Die Lagen beider kommen aus demselben ``Gitter`` – wandert die Rückrechnung von
/// der Zeichnung ab, wandert der Griff von der Kurve weg. Dieselbe Begründung steht an
/// ``Jahresflaeche`` (`Diagramme/Jahresflaeche.swift:134-140`).
///
/// **Die Ränder der Vorlage stehen in Punkten und skalieren nicht mit der Breite.** Die Vorlage
/// zeichnet in ein `viewBox` von 760 × 360 und lässt alles mitwachsen, Schrift eingeschlossen
/// (`Heizkurve.tsx:20-26`). Auf einem Telefon wären die 11 Bildpunkte der Achsenzahlen damit
/// rund sechs Punkte groß – `handy.css:242` hebt sie dort schon auf 14 an und kommt immer noch
/// bei sieben heraus. Hier bleiben die Ränder 46/22/16/40 Punkte und die Schrift ist echte
/// ``Schrift/achse``, am Telefon eine Stufe größer.
struct Heizkurvenbild: View {
    let werte: [ReglerEinstellungOut]
    let entwurf: Reglerpult.Entwurf
    let stellenMoeglich: Bool
    /// Was der Regler je Stunde verlangt hat – Beiwerk: fehlt es, steht die Kurve ohne Punkte
    /// (`Regler.tsx:51`).
    let stunden: [Reglerpult.Kurvenpunkt]
    let stelle: (String, Double) -> Void

    @Environment(\.horizontalSizeClass) private var breite
    @State private var zieht: Reglerpult.Kurvengriff?

    private var schmal: Bool { breite == .compact }
    private var hoehe: CGFloat { schmal ? 250 : 320 }
    private var achsenschrift: Font { schmal ? Schrift.mono(13, relativeTo: .caption2) : Schrift.achse }
    private var beschriftungsschrift: Font { schmal ? Schrift.sans(14) : Schrift.sans(12) }

    var body: some View {
        if let ist = Reglerpult.kurveAus(werte),
            let soll = Reglerpult.kurveAus(werte, entwurf: entwurf)
        {
            VStack(alignment: .leading, spacing: 8) {
                bild(ist: ist, soll: soll)
                kurvenfuss(soll)
            }
        } else {
            Leer(satz: Reglerpult.kurveFehltSatz)
        }
    }

    // MARK: - Die Zeichnung

    private func bild(ist: Reglerpult.Kurve, soll: Reglerpult.Kurve) -> some View {
        GeometryReader { raum in
            let gitter = Gitter(groesse: raum.size)
            ZStack(alignment: .topLeading) {
                Canvas { gestalt, groesse in
                    male(in: &gestalt, gitter: Gitter(groesse: groesse), ist: ist, soll: soll)
                }
                griffe(gitter: gitter, soll: soll)
            }
        }
        .frame(height: hoehe)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Heizkurve: Vorlauf über der Außentemperatur")
    }

    /// Die Stapelreihenfolge ist die der Vorlage (`Heizkurve.tsx:109-161`): Raster, Achsen,
    /// die abgedunkelten Flächen, die Punktwolke, die Ist-Linie, die Soll-Linie, die Grenzen.
    /// Was später kommt, liegt oben – die Soll-Linie über der Punktwolke und nicht darunter.
    private func male(
        in g: inout GraphicsContext, gitter: Gitter, ist: Reglerpult.Kurve,
        soll: Reglerpult.Kurve
    ) {
        maleRaster(in: &g, gitter: gitter)
        maleAchsentitel(in: &g, gitter: gitter)
        maleAussen(in: &g, gitter: gitter, soll: soll)
        malePunkte(in: &g, gitter: gitter)
        if Reglerpult.kurveGeaendert(werte, entwurf: entwurf) {
            maleLinie(in: &g, gitter: gitter, kurve: ist, entwurf: false)
        }
        maleLinie(
            in: &g, gitter: gitter, kurve: soll,
            entwurf: Reglerpult.kurveGeaendert(werte, entwurf: entwurf))
        maleGrenzen(in: &g, gitter: gitter, soll: soll)
    }

    private func maleRaster(in g: inout GraphicsContext, gitter: Gitter) {
        for v in Gitter.yStriche {
            let y = gitter.py(v)
            var pfad = Path()
            pfad.move(to: CGPoint(x: gitter.links, y: y))
            pfad.addLine(to: CGPoint(x: gitter.rechts, y: y))
            g.stroke(pfad, with: .color(Farbe.rasterlinie), lineWidth: 1)
            g.draw(
                achsenzahl(Formate.zahl(v, stellen: 0)),
                at: CGPoint(x: gitter.links - 8, y: y), anchor: .trailing)
        }
        for t in Gitter.xStriche {
            let x = gitter.px(t)
            var pfad = Path()
            pfad.move(to: CGPoint(x: x, y: gitter.oben))
            pfad.addLine(to: CGPoint(x: x, y: gitter.unterkante))
            g.stroke(pfad, with: .color(Farbe.rasterlinie), lineWidth: 1)
            g.draw(
                achsenzahl(Formate.zahl(t, stellen: 0)),
                at: CGPoint(x: x, y: gitter.unterkante + 12), anchor: .top)
        }
    }

    private func maleAchsentitel(in g: inout GraphicsContext, gitter: Gitter) {
        g.draw(
            achsenzahl("Außentemperatur °C"),
            at: CGPoint(x: (gitter.links + gitter.rechts) / 2, y: gitter.groesse.height - 6),
            anchor: .bottom)
        g.draw(
            achsenzahl("Vorlauf °C"),
            at: CGPoint(x: 6, y: gitter.oben), anchor: .topLeading)
    }

    private func achsenzahl(_ wort: String) -> Text {
        Text(wort).font(achsenschrift).foregroundStyle(Farbe.text3)
    }

    /// Was über dem größten und unter dem kleinsten Vorlauf liegt, ist abgedunkelt: dort fährt
    /// der Regler nicht, was die Näherung auch rechnet (`Heizkurve.tsx:125-126`).
    private func maleAussen(in g: inout GraphicsContext, gitter: Gitter, soll: Reglerpult.Kurve) {
        let breite = gitter.rechts - gitter.links
        let obenHoehe = max(0, gitter.py(soll.max) - gitter.oben)
        let untenOben = gitter.py(soll.min)
        let untenHoehe = max(0, gitter.unterkante - untenOben)
        let farbe = GraphicsContext.Shading.color(Color.black.opacity(0.22))
        g.fill(
            Path(CGRect(x: gitter.links, y: gitter.oben, width: breite, height: obenHoehe)),
            with: farbe)
        g.fill(
            Path(CGRect(x: gitter.links, y: untenOben, width: breite, height: untenHoehe)),
            with: farbe)
    }

    private func malePunkte(in g: inout GraphicsContext, gitter: Gitter) {
        let farbe = GraphicsContext.Shading.color(Farbe.mist.opacity(0.55))
        for s in stunden where s.aussen >= Gitter.xVon && s.aussen <= Gitter.xBis {
            let mitte = CGPoint(x: gitter.px(s.aussen), y: gitter.py(gitter.klemme(s.vorlauf)))
            let kasten = CGRect(
                x: mitte.x - 2.6, y: mitte.y - 2.6, width: 5.2, height: 5.2)
            g.fill(Path(ellipseIn: kasten), with: farbe)
        }
    }

    private func maleLinie(
        in g: inout GraphicsContext, gitter: Gitter, kurve: Reglerpult.Kurve, entwurf: Bool
    ) {
        let punkte = Reglerpult.kurvenPunkte(kurve, von: Gitter.xVon, bis: Gitter.xBis)
        var pfad = Path()
        for (stelle, p) in punkte.enumerated() {
            let ort = CGPoint(x: gitter.px(p.aussen), y: gitter.py(gitter.klemme(p.vorlauf)))
            if stelle == 0 { pfad.move(to: ort) } else { pfad.addLine(to: ort) }
        }
        if !entwurf, Reglerpult.kurveGeaendert(werte, entwurf: self.entwurf) {
            // Die gestrichelte Linie ist, was am Regler steht - sie kommt nur dazu, wenn der
            // Entwurf davon abweicht (`Heizkurve.tsx:132`).
            g.stroke(
                pfad, with: .color(Farbe.text3),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            return
        }
        let stil = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        if entwurf {
            g.drawLayer { schicht in
                schicht.addFilter(.shadow(color: Farbe.amber.opacity(0.6), radius: 4))
                schicht.stroke(pfad, with: .color(Farbe.amber), style: stil)
            }
        } else {
            g.stroke(pfad, with: .color(Farbe.waermepumpe), style: stil)
        }
    }

    private func maleGrenzen(in g: inout GraphicsContext, gitter: Gitter, soll: Reglerpult.Kurve) {
        for griff in [Reglerpult.Kurvengriff.max, .min] {
            let v = griff == .max ? soll.max : soll.min
            var pfad = Path()
            pfad.move(to: CGPoint(x: gitter.links, y: gitter.py(v)))
            pfad.addLine(to: CGPoint(x: gitter.rechts, y: gitter.py(v)))
            g.stroke(
                pfad, with: .color(Farbe.text3),
                style: StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
        }
    }

    // MARK: - Die vier Griffe

    @ViewBuilder private func griffe(gitter: Gitter, soll: Reglerpult.Kurve) -> some View {
        schild(.max, gitter: gitter, soll: soll)
        schild(.min, gitter: gitter, soll: soll)
        ziehgriff(.steilheit, gitter: gitter, soll: soll)
        ziehgriff(.verschiebung, gitter: gitter, soll: soll)
    }

    private func wert(_ griff: Reglerpult.Kurvengriff) -> ReglerEinstellungOut? {
        werte.first { $0.schluessel == griff.kennung }
    }

    private func frei(_ griff: Reglerpult.Kurvengriff) -> Bool {
        guard let w = wert(griff) else { return false }
        return Reglerpult.bedienbar(w, stellenMoeglich: stellenMoeglich)
    }

    /// Das Schild am rechten Rand: „max 45°“ (`Heizkurve.tsx:136-145`).
    ///
    /// Sichtbar sind 54 × 20 Punkte wie in der Vorlage, getroffen wird eine Fläche von 44
    /// Punkten Höhe – das ist die Mindestgröße für einen Daumen
    /// (`Bausteine/Speichersteuerkarte.swift:34-36`), und die Vorlage legt für denselben Zweck
    /// unsichtbare Fangflächen unter ihre Griffe (`Heizkurve.tsx:149, 157`).
    @ViewBuilder private func schild(
        _ griff: Reglerpult.Kurvengriff, gitter: Gitter, soll: Reglerpult.Kurve
    ) -> some View {
        if let w = wert(griff) {
            let v = griff == .max ? soll.max : soll.min
            Text(Reglerpult.griffschild(griff, v))
                .font(achsenschrift)
                .foregroundStyle(frei(griff) ? Farbe.text1 : Farbe.text3)
                .frame(width: 54, height: 20)
                .background(griffflaeche(griff))
                .frame(width: 54, height: 44)
                .contentShape(Rectangle())
                .position(x: gitter.rechts - 27, y: gitter.py(v))
                .gesture(ziehen(griff, gitter: gitter, soll: soll))
                .modifier(griffstimme(griff, w: w, wert: v))
        }
    }

    /// Der runde Griff der Steilheit und der eckige der Verschiebung, samt Beschriftung
    /// (`Heizkurve.tsx:147-161`).
    @ViewBuilder private func ziehgriff(
        _ griff: Reglerpult.Kurvengriff, gitter: Gitter, soll: Reglerpult.Kurve
    ) -> some View {
        if let w = wert(griff), let aussen = griff.aussen {
            let x = gitter.px(aussen)
            let y = gitter.py(gitter.klemme(Reglerpult.vorlauf(soll, aussen: aussen)))
            let v = Reglerpult.sichtbar(w, entwurf: entwurf) ?? 0
            griffzeichen(griff)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .position(x: x, y: y)
                .gesture(ziehen(griff, gitter: gitter, soll: soll))
                .modifier(griffstimme(griff, w: w, wert: v))
            beschriftung(griff, w: w, wert: v)
                .position(
                    // `.position` setzt die Mitte; die Vorlage setzt den Anfang bei x+18 bzw.
                    // das Ende bei x−16 (`Heizkurve.tsx:153, 161`). Die halbe Textbreite
                    // dazwischen ist geschätzt - gemessen wird sie erst beim Setzen.
                    x: griff == .steilheit ? x + 18 + 45 : x - 16 - 62,
                    y: griff == .steilheit ? y - 20 : y - 24)
                .allowsHitTesting(false)
        }
    }

    /// Was die Sprachausgabe am Griff sagt. Der Hinweis ist der Sperrgrund selbst – wer nicht
    /// sehen kann, dass ein Griff blass ist, soll hören, warum er sich nicht bewegt.
    ///
    /// **Und was sie an ihm tun kann.** Ein Griff, der sich nur ziehen lässt, ist mit VoiceOver
    /// nicht zu bedienen: die Vorlage stellt darum jeden Griff mit den Pfeiltasten um genau
    /// einen `schritt` (`Heizkurve.tsx:88-95`). Das ist hier ``Griffstimme/stufe`` – ein Schritt
    /// auf, ein Schritt ab, nicht mehr, und gesperrt gar keiner, wie `if (!an) return`
    /// (`Heizkurve.tsx:89`).
    private func griffstimme(
        _ griff: Reglerpult.Kurvengriff, w: ReglerEinstellungOut, wert: Double
    ) -> Griffstimme {
        let an = frei(griff)
        return Griffstimme(
            name: griff.name,
            wert: Reglerpult.zahlText(w, wert),
            hinweis: an
                ? "Ziehen stellt die Heizkurve"
                : Reglerpult.fuss(w, stellenMoeglich: stellenMoeglich).satz,
            stufe: { richtung in
                guard an else { return }
                stelle(w.schluessel, Reglerpult.raster(w, wert + richtung * (w.schritt ?? 1)))
            })
    }

    /// Das Zeichen im Griff: ein Winkel nach oben für die Steilheit, ein Doppelpfeil für die
    /// Verschiebung (`Heizkurve.tsx:151, 159`). Gezeichnet und nicht aus ``Zeichenart`` geholt -
    /// dort gibt es keine Pfeile, und zwei neue Zeichen in `Gestalt/Zeichendaten.swift` wären
    /// erzeugte Daten, die hier niemand braucht.
    @ViewBuilder private func griffzeichen(_ griff: Reglerpult.Kurvengriff) -> some View {
        if griff == .steilheit {
            Griffsymbol(doppelt: false)
                .stroke(
                    zeichenfarbe(griff),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 22)
                .background(griffflaeche(griff, rund: true))
        } else {
            Griffsymbol(doppelt: true)
                .stroke(
                    zeichenfarbe(griff),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 20)
                .background(griffflaeche(griff))
        }
    }

    private func zeichenfarbe(_ griff: Reglerpult.Kurvengriff) -> Color {
        if !frei(griff) { return Farbe.text3 }
        return zieht == griff ? Farbe.petrol : Farbe.text1
    }

    /// Die Fläche eines Griffs: `surface-3` mit 2 Punkten Bernstein, im Zug bernstein gefüllt,
    /// gesperrt grau (`globals.css:952-964`).
    @ViewBuilder private func griffflaeche(_ griff: Reglerpult.Kurvengriff, rund: Bool = false)
        -> some View
    {
        let an = frei(griff)
        let gefuellt = an && zieht == griff
        let gestalt = RoundedRectangle(cornerRadius: rund ? 11 : 5, style: .continuous)
        gestalt
            .fill(gefuellt ? Farbe.amber : (an ? Farbe.flaeche3 : Farbe.flaeche2))
            .overlay(gestalt.strokeBorder(an ? Farbe.amber : Farbe.linie2, lineWidth: 2))
            .opacity(an ? 1 : 0.6)
    }

    /// „Steilheit 1,00“ über der Kurve.
    ///
    /// Die Vorlage legt den Text mit `paint-order: stroke` und vier Punkten Kontur in der
    /// Kartenfarbe über die Linie (`globals.css:965`). SwiftUI kennt das nicht; hier steht
    /// stattdessen eine gefüllte Kapsel dahinter – dasselbe Ziel, lesbar über der Kurve zu
    /// bleiben, mit den Mitteln, die es gibt.
    private func beschriftung(
        _ griff: Reglerpult.Kurvengriff, w: ReglerEinstellungOut, wert: Double
    ) -> some View {
        Text(Reglerpult.griffbeschriftung(griff, w, wert))
            .font(beschriftungsschrift)
            .foregroundStyle(Farbe.text1)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Farbe.flaeche1.opacity(0.85), in: Capsule())
    }

    // MARK: - Ziehen

    /// Vom Finger zur Vorlauftemperatur und zurück in die Einstellung.
    ///
    /// **Gerastert wird sofort.** Was zwischen zwei Schritten liegt, nimmt der Regler nicht an;
    /// ein Griff, der 44,3 °C anzeigt, behauptet eine Genauigkeit, die der Bus nicht hat
    /// (`Heizkurve.tsx:58-60`).
    ///
    /// **Gesendet wird hier nichts.** Die Bewegung schreibt in den Entwurf; an den Bus geht sie
    /// erst über die Übernahmeleiste, nach der Übersicht und einem zweiten Knopfdruck
    /// (`Regler.tsx:64, 285-312`).
    /// **Die Geste hängt hinter `.position`, und darum zählt sie in den Maßen des Bildes.**
    /// `position` gibt die ganze angebotene Fläche zurück und setzt das Kind an seinen Punkt;
    /// was danach kommt, hat denselben Ursprung wie der `ZStack`. Getroffen wird trotzdem nur
    /// die 44 Punkte des Griffs - dafür sorgt das `contentShape` davor. So braucht es keinen
    /// benannten Koordinatenraum, dessen Fassung für iOS 17 ohnehin zwei Namen hat.
    private func ziehen(
        _ griff: Reglerpult.Kurvengriff, gitter: Gitter, soll: Reglerpult.Kurve
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { punkt in
                guard frei(griff), let w = wert(griff) else { return }
                zieht = griff
                let ziel = gitter.vorlaufAn(punkt.location.y)
                let neu = Reglerpult.griffziel(griff, k: soll, ziel: ziel)
                stelle(w.schluessel, Reglerpult.raster(w, neu))
            }
            .onEnded { _ in zieht = nil }
    }

    // MARK: - Legende und Stützstellen

    private func kurvenfuss(_ soll: Reglerpult.Kurve) -> some View {
        let geaendert = Reglerpult.kurveGeaendert(werte, entwurf: entwurf)
        return VStack(alignment: .leading, spacing: 6) {
            if schmal {
                legende(geaendert: geaendert)
                stuetzstellen(soll)
            } else {
                HStack(alignment: .center, spacing: 18) {
                    legende(geaendert: geaendert)
                    Spacer(minLength: 8)
                    stuetzstellen(soll)
                }
            }
        }
    }

    private func legende(geaendert: Bool) -> some View {
        Umbruchzeile(abstand: 18, zeilenabstand: 6) {
            legendenstueck(
                farbe: geaendert ? Farbe.amber : Farbe.waermepumpe, dick: 3,
                wort: geaendert ? "Entwurf" : "eingestellt")
            if geaendert {
                legendenstueck(farbe: Farbe.text3, dick: 2, wort: "am Regler")
            }
            if !stunden.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(Farbe.mist.opacity(0.7)).frame(width: 7, height: 7)
                    Text("vom Regler verlangt, je Stunde")
                        .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private func legendenstueck(farbe: Color, dick: CGFloat, wort: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(farbe).frame(width: 18, height: dick)
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }

    private func stuetzstellen(_ soll: Reglerpult.Kurve) -> some View {
        Text(Reglerpult.kurvenwertesatz(soll))
            .font(Schrift.zahlKlein)
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Was die Sprachausgabe an einem Griff sagt – das Gegenstück zu `role="slider"` mit
/// `aria-valuemin/max/now/valuetext` und den Pfeiltasten (`Heizkurve.tsx:62-96`).
///
/// **Als eigener Modifier, weil es an vier Griffen gleich ist** und weil
/// `accessibilityAdjustableAction` die Pfeiltasten der Vorlage ersetzt: ein Schritt auf, ein
/// Schritt ab, nicht mehr (`Heizkurve.tsx:88-95`). Ohne sie wäre die Kurve nur lesbar – dasselbe
/// Paar aus Stimme und Verstellbarkeit hat die Bahn des Kanalzugs (`Kanalzug.swift:132-138`).
private struct Griffstimme: ViewModifier {
    let name: String
    let wert: String
    let hinweis: String
    /// Einen Schritt auf (`1`) oder ab (`-1`) – was die Pfeiltasten der Vorlage tun.
    let stufe: (Double) -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement()
            .accessibilityLabel(name)
            .accessibilityValue(wert)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(hinweis)
            .accessibilityAdjustableAction { richtung in
                switch richtung {
                case .increment: stufe(1)
                case .decrement: stufe(-1)
                @unknown default: break
                }
            }
    }
}

/// Die Umrechnung zwischen Daten und Bildpunkten – einmal für das Zeichnen und für die Griffe.
///
/// Die Spannen und Ränder sind die der Vorlage (`Heizkurve.tsx:22-31`); die Ränder stehen in
/// Punkten, siehe die Begründung an ``Heizkurvenbild``.
private struct Gitter {
    let groesse: CGSize

    static let xVon = -15.0
    static let xBis = 22.0
    static let yVon = 15.0
    static let yBis = 65.0
    static let xStriche: [Double] = [-15, -10, -5, 0, 5, 10, 15, 20]
    static let yStriche: [Double] = [20, 30, 40, 50, 60]

    let links: CGFloat = 46
    let oben: CGFloat = 16
    private let rechterRand: CGFloat = 22
    private let unten: CGFloat = 40

    var rechts: CGFloat { max(links + 1, groesse.width - rechterRand) }
    var unterkante: CGFloat { max(oben + 1, groesse.height - unten) }

    func px(_ t: Double) -> CGFloat {
        let anteil = (t - Gitter.xVon) / (Gitter.xBis - Gitter.xVon)
        return links + CGFloat(anteil) * (rechts - links)
    }

    func py(_ v: Double) -> CGFloat {
        let anteil = (Gitter.yBis - v) / (Gitter.yBis - Gitter.yVon)
        return oben + CGFloat(anteil) * (unterkante - oben)
    }

    func klemme(_ v: Double) -> Double {
        min(Gitter.yBis, max(Gitter.yVon, v))
    }

    /// Die Rückrechnung: welcher Vorlauf steht an dieser Höhe? Dieselbe Rechnung wie ``py(_:)``,
    /// nur umgedreht.
    func vorlaufAn(_ y: CGFloat) -> Double {
        let spanne = unterkante - oben
        guard spanne > 0 else { return Gitter.yVon }
        let anteil = Double((y - oben) / spanne)
        return klemme(Gitter.yBis - anteil * (Gitter.yBis - Gitter.yVon))
    }
}

/// Das Zeichen in einem Ziehgriff: der Winkel nach oben (Steilheit) oder der Doppelpfeil
/// (Verschiebung) – gezeichnet in das Quadrat, das der Griff ihm gibt (`Heizkurve.tsx:151,
/// 159`).
private struct Griffsymbol: Shape {
    let doppelt: Bool

    func path(in rand: CGRect) -> Path {
        let m = CGPoint(x: rand.midX, y: rand.midY)
        var pfad = Path()
        if doppelt {
            pfad.move(to: CGPoint(x: m.x, y: m.y - 5))
            pfad.addLine(to: CGPoint(x: m.x, y: m.y + 5))
            pfad.move(to: CGPoint(x: m.x - 3, y: m.y - 2))
            pfad.addLine(to: CGPoint(x: m.x, y: m.y - 5))
            pfad.addLine(to: CGPoint(x: m.x + 3, y: m.y - 2))
            pfad.move(to: CGPoint(x: m.x - 3, y: m.y + 2))
            pfad.addLine(to: CGPoint(x: m.x, y: m.y + 5))
            pfad.addLine(to: CGPoint(x: m.x + 3, y: m.y + 2))
        } else {
            pfad.move(to: CGPoint(x: m.x - 4, y: m.y + 3))
            pfad.addLine(to: CGPoint(x: m.x, y: m.y - 4))
            pfad.addLine(to: CGPoint(x: m.x + 4, y: m.y + 3))
        }
        return pfad
    }
}
