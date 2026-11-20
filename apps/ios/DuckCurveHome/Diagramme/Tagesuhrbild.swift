import DuckCurveKit
import SwiftUI

/// Die Tagesuhr: ein Ortstag als Ring, Mitternacht oben, im Uhrzeigersinn.
///
/// **Wozu ein Kreis, wenn daneben schon ein Band liegt** (`Tagesuhr.tsx:10-20`). Die beiden
/// beantworten verschiedene Fragen. Das Band ist zum Ablesen da: wie viel Kilowatt, wie viele
/// Cent, auf einer Achse mit Zahlen. Die Uhr ist zum Zurechtfinden da: wo im Tag stehe ich, was
/// lief da gerade, und was war davor und danach. Größen vergleicht man auf ihr schlecht - ein
/// Ringstück außen ist länger als dasselbe innen -, und deshalb stehen hier keine Größen, die man
/// vergleichen müsste: die beiden Stärkeringe kennen fünf Helligkeitsstufen, die übrigen nur an
/// und aus.
///
/// **Die Ringe, von außen nach innen**, in der Reihenfolge der Ursachen: der Preis, der den Plan
/// treibt; die Sonne, die ihn auch treibt; die Absicht des Fahrplans; und was die Wärmepumpe
/// wirklich tat. Absicht und Ausführung liegen unmittelbar aneinander, damit ihr Auseinanderfallen
/// ohne Suchen auffällt. Der Ofen bekommt den innersten Ring, wenn es ihn gibt.
///
/// **Drei Zustände je Stelle, nicht zwei** (`Tagesuhr.tsx:23-26`). Farbe heißt „ja“, die blasse
/// Spur heißt „gemessen, aber nein“, und gar nichts heißt „keine Messung“. Eine Lücke in der
/// Erfassung bleibt ein Loch im Ring. Dasselbe gilt für die Absicht: ohne aufbewahrten Fahrplan
/// fehlt die Spur ganz, statt ein Nein vorzutäuschen.
///
/// **Gezeichnet, nicht gestapelt.** 288 Bilder auf fünf Ringen wären bis zu 1440 `Shape`-Ansichten
/// mit je einem eigenen Pfad, die SwiftUI bei jedem Bildwechsel neu vermisst - dasselbe Urteil wie
/// bei der Jahresfläche (`Diagramme/Jahresflaeche.swift:5-9`). Also ein `Canvas`, und die
/// Treffersuche mit derselben Rechnung, mit der gezeichnet wurde (`Tagesuhrgeometrie`).
///
/// **Die Uhr ist ein Griff, kein Bedienelement.** Ziehen fährt durch den Tag. Für
/// Vorleseprogramme bleibt der Schieber in der Leiste zuständig - „ein Kreis, auf dem man zielen
/// muss, ist keines“ (`Tagesuhr.tsx:31-33`). Der zweite, schwache Zeiger der Vorlage fällt weg: er
/// zeigt dort die Stelle unter der Maus, und am Telefon ist Zeigen und Greifen derselbe Finger.
struct Tagesuhrbild: View {
    let bild: Wiedergabebild
    let daten: AnlageReplayOut
    let stelle: Int
    /// Ein Griff in die Uhr setzt die Stelle - und hält die Wiedergabe an, was die Seite
    /// entscheidet: „wer hinfasst, will hinsehen“ (`Wiedergabe.tsx:151`).
    var aufSprung: (Int) -> Void

    /// Die Spur: wo gemessen wurde. `rgba(255,255,255,.055)` der Vorlage (`Tagesuhr.tsx:45`) -
    /// zu schwach für einen eigenen Markeneintrag, und nirgends sonst gebraucht.
    private var spurfarbe: Color { Color(Marken.papier.mitDeckung(0.055)) }

    private var mitte: CGPoint {
        CGPoint(x: Tagesuhrgeometrie.mitte, y: Tagesuhrgeometrie.mitte)
    }

    var body: some View {
        GeometryReader { raum in
            Canvas { gestalt, groesse in
                male(in: &gestalt, groesse: groesse)
            }
            .contentShape(Rectangle())
            .gesture(greifen(raum.size))
        }
        .aspectRatio(1, contentMode: .fit)
        // 300 Punkte wie `max-width` der Vorlage (`globals.css:637`); darüber wird aus der Uhr
        // eine Scheibe, die die halbe Karte nimmt, ohne mehr zu sagen.
        .frame(maxWidth: 300)
        .accessibilityLabel(Wiedergabeworte.uhrName)
    }

    // MARK: - Zeichnen

    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        // Gezeichnet wird in den 360 Einheiten des Zifferblatts; die Verkleinerung macht eine
        // Stelle, so wie das Anlagenbild es hält (`Anlagenbild.swift:48-54`).
        let maß = groesse.width / Tagesuhrgeometrie.groesse
        guard maß > 0 else { return }
        g.scaleBy(x: maß, y: maß)
        stundenstriche(in: &g)
        spuren(in: &g)
        staerkeringe(in: &g)
        absicht(in: &g)
        schaltringe(in: &g)
        zeiger(in: &g)
        mittentext(in: &g)
    }

    /// Stundenstriche. Alle sechs Stunden kräftiger und beschriftet, dazwischen nur ein Hauch.
    ///
    /// Geteilt wird durch die Stundenzahl *dieses* Tages, nicht durch 24: an einem
    /// Umstellungstag hat der Ring 23 oder 25 Striche.
    private func stundenstriche(in g: inout GraphicsContext) {
        let stunden = bild.stundenImTag
        guard stunden > 0 else { return }
        for h in 0..<stunden {
            let a = Double(h) / Double(stunden)
            let stark = h % 6 == 0
            var pfad = Path()
            pfad.move(to: ort(r: Tagesuhrgeometrie.strichInnen, anteil: a))
            pfad.addLine(
                to: ort(
                    r: stark ? Tagesuhrgeometrie.strichAussenStark : Tagesuhrgeometrie.strichAussen,
                    anteil: a))
            g.stroke(
                pfad, with: .color(Color(Marken.papier.mitDeckung(stark ? 0.42 : 0.14))),
                lineWidth: 1)
        }
        for h in [0, 6, 12, 18] where h < stunden {
            let p = ort(r: Tagesuhrgeometrie.zahlenradius, anteil: Double(h) / Double(stunden))
            g.draw(
                Text(String(h)).font(Schrift.achse).foregroundStyle(Farbe.text3), at: p,
                anchor: .center)
        }
    }

    /// Wo überhaupt gemessen wurde - ein Loch im Ring heißt „keine Messung“.
    private func spuren(in g: inout GraphicsContext) {
        var ringe = [
            Tagesuhrgeometrie.ringPreis, Tagesuhrgeometrie.ringSonne,
            Tagesuhrgeometrie.ringGelaufen,
        ]
        if bild.hatOfen { ringe.append(Tagesuhrgeometrie.ringOfen) }
        for ring in ringe {
            for lauf in bild.spur {
                fuelle(in: &g, ring: ring, von: lauf.von, bis: lauf.bis, mit: spurfarbe)
            }
        }
    }

    /// Preis und Sonne: fünf Helligkeitsstufen, heller ist mehr.
    private func staerkeringe(in g: inout GraphicsContext) {
        for lauf in bild.preisringe {
            fuelle(
                in: &g, ring: Tagesuhrgeometrie.ringPreis, von: lauf.von, bis: lauf.bis,
                mit: Farbe.preis.opacity(helligkeit(lauf.wert)))
        }
        for lauf in bild.sonnenringe {
            fuelle(
                in: &g, ring: Tagesuhrgeometrie.ringSonne, von: lauf.von, bis: lauf.bis,
                mit: Farbe.pv.opacity(helligkeit(lauf.wert)))
        }
    }

    /// Die Absicht: dieselbe Farbe wie die Ausführung, aber als Umriss.
    ///
    /// „Dasselbe Ding in einem anderen Stand - geplant ist noch nicht geschehen, und ein Umriss
    /// ist noch nicht gefüllt“ (`Tagesuhr.tsx:160-161`). Ein `false` wird zur blassen Spur, nicht
    /// zu einem leeren Platz: gemessen, aber nein.
    private func absicht(in g: inout GraphicsContext) {
        for lauf in bild.geplant {
            let ring = Tagesuhrgeometrie.ringGeplant
            if lauf.wert {
                fuelle(
                    in: &g, ring: ring, von: lauf.von, bis: lauf.bis,
                    mit: Farbe.waermepumpe.opacity(0.22))
                umreisse(in: &g, ring: ring, von: lauf.von, bis: lauf.bis, mit: Farbe.waermepumpe)
            } else {
                fuelle(in: &g, ring: ring, von: lauf.von, bis: lauf.bis, mit: spurfarbe)
            }
        }
    }

    /// Was wirklich lief: Wärmepumpe und, wenn es ihn gibt, der Ofen.
    private func schaltringe(in g: inout GraphicsContext) {
        for lauf in bild.gelaufen where lauf.wert {
            fuelle(
                in: &g, ring: Tagesuhrgeometrie.ringGelaufen, von: lauf.von, bis: lauf.bis,
                mit: Farbe.waermepumpe)
        }
        for lauf in bild.ofen where lauf.wert {
            fuelle(
                in: &g, ring: Tagesuhrgeometrie.ringOfen, von: lauf.von, bis: lauf.bis,
                mit: Farbe.ofen)
        }
    }

    /// Der Zeiger, mit einem dunklen Hof darunter, „damit er über hellen Ringstücken lesbar
    /// bleibt“ (`Tagesuhr.tsx:225`).
    private func zeiger(in g: inout GraphicsContext) {
        guard let a = bild.anteil(stelle: stelle) else { return }
        let innen = Tagesuhrgeometrie.zeigerInnen(mitOfen: bild.hatOfen)
        let aussen = Tagesuhrgeometrie.zeigerAussen
        var pfad = Path()
        pfad.move(to: ort(r: innen, anteil: a))
        pfad.addLine(to: ort(r: aussen, anteil: a))
        g.stroke(
            pfad, with: .color(Farbe.deep),
            style: StrokeStyle(lineWidth: 5, lineCap: .round))
        g.stroke(
            pfad, with: .color(Farbe.papier),
            style: StrokeStyle(lineWidth: 2, lineCap: .round))
        let spitze = ort(r: aussen, anteil: a)
        let knopf = Path(
            ellipseIn: CGRect(x: spitze.x - 4, y: spitze.y - 4, width: 8, height: 8))
        g.fill(knopf, with: .color(Farbe.papier))
        g.stroke(knopf, with: .color(Farbe.deep), lineWidth: 2)
    }

    /// Die Mitte: die Zeit des Bildes und was dort galt.
    ///
    /// Schrift in Textfarbe; die Farbe gehört den Ringen. Die Uhrzeit kommt aus dem Kern und
    /// steht damit in der Zeit des Hauses - „das Zifferblatt zählt vom Tagesbeginn des Hauses,
    /// die Schrift zählte vom Gerät aus“ (`Wiedergabe.tsx:45-52`).
    private func mittentext(in g: inout GraphicsContext) {
        guard let m = bild.mitte(daten, stelle: stelle) else { return }
        g.draw(
            Text(m.zeit).font(Schrift.mono(38)).tracking(-1).foregroundStyle(Farbe.text1),
            at: CGPoint(x: Tagesuhrgeometrie.mitte, y: Tagesuhrgeometrie.mitte - 14),
            anchor: .center)
        g.draw(
            Text(m.sonne).font(Schrift.winzig).foregroundStyle(Farbe.text2),
            at: CGPoint(x: Tagesuhrgeometrie.mitte, y: Tagesuhrgeometrie.mitte + 16),
            anchor: .center)
        g.draw(
            Text(m.pumpe).font(Schrift.winzig).foregroundStyle(Farbe.text2),
            at: CGPoint(x: Tagesuhrgeometrie.mitte, y: Tagesuhrgeometrie.mitte + 34),
            anchor: .center)
    }

    // MARK: - Ringstücke als Pfade

    private func helligkeit(_ stufe: Int) -> Double {
        let stufen = Wiedergabebild.stufen
        guard stufe >= 0, stufe < stufen.count else { return 1 }
        return stufen[stufe]
    }

    private func ort(r: Double, anteil a: Double) -> CGPoint {
        let p = Tagesuhrgeometrie.punkt(r: r, anteil: a)
        return CGPoint(x: p.x, y: p.y)
    }

    /// Die Pfade eines Laufs in einem Ring - je Bogenstück einer.
    ///
    /// **Zwei Bögen und zwei Linien je Stück.** `Path.addArc` zeichnet nur einen Kreisbogen um
    /// einen Mittelpunkt, kein Ringstück; dieselbe Einsicht steht bei den SVG-Bögen des Projekts
    /// (`SvgPfad.swift:279-280`). Der äußere Bogen läuft vorwärts, der innere zurück, und
    /// `closeSubpath` zieht die zweite Linie.
    private func pfade(_ ring: Tagesuhrgeometrie.Ring, von: Date, bis: Date) -> [Path] {
        let a0 = Tagesuhrgeometrie.anteil(von, von: bild.von, bis: bild.bis)
        let a1 = Tagesuhrgeometrie.anteil(bis, von: bild.von, bis: bild.bis)
        return Tagesuhrgeometrie.bogenstuecke(von: a0, bis: a1).map { stueck in
            let w0 = Angle(radians: Tagesuhrgeometrie.winkel(anteil: stueck.von))
            let w1 = Angle(radians: Tagesuhrgeometrie.winkel(anteil: stueck.bis))
            var pfad = Path()
            pfad.addArc(
                center: mitte, radius: ring.aussen, startAngle: w0, endAngle: w1, clockwise: false)
            pfad.addArc(
                center: mitte, radius: ring.innen, startAngle: w1, endAngle: w0, clockwise: true)
            pfad.closeSubpath()
            return pfad
        }
    }

    private func fuelle(
        in g: inout GraphicsContext, ring: Tagesuhrgeometrie.Ring, von: Date, bis: Date,
        mit farbe: Color
    ) {
        for pfad in pfade(ring, von: von, bis: bis) {
            g.fill(pfad, with: .color(farbe))
        }
    }

    private func umreisse(
        in g: inout GraphicsContext, ring: Tagesuhrgeometrie.Ring, von: Date, bis: Date,
        mit farbe: Color
    ) {
        for pfad in pfade(ring, von: von, bis: bis) {
            g.stroke(pfad, with: .color(farbe), lineWidth: 1)
        }
    }

    // MARK: - Greifen

    private func greifen(_ groesse: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { griff in
                guard let i = stelleUnter(griff.location, groesse: groesse) else { return }
                aufSprung(i)
            }
    }

    /// Von einer Stelle auf dem Schirm zu einem Bild - dieselbe Rechnung wie beim Zeichnen.
    ///
    /// Daneben gegriffen heißt: nichts tun, nicht das Nächstbeste nehmen
    /// (`Jahresflaeche.swift:134-135`). Die Mitte ist ausdrücklich daneben: „Wer dort klickt,
    /// will lesen und nicht springen“ (`Tagesuhr.tsx:208`).
    private func stelleUnter(_ punkt: CGPoint, groesse: CGSize) -> Int? {
        guard groesse.width > 0 else { return nil }
        let maß = Tagesuhrgeometrie.groesse / groesse.width
        let dx = punkt.x * maß - Tagesuhrgeometrie.mitte
        let dy = punkt.y * maß - Tagesuhrgeometrie.mitte
        guard Tagesuhrgeometrie.imGriff(dx: dx, dy: dy) else { return nil }
        return Tagesuhrgeometrie.indexBei(
            anteil: Tagesuhrgeometrie.anteilAus(dx: dx, dy: dy), zeiten: bild.zeitpunkte,
            von: bild.von, bis: bild.bis)
    }
}

/// Die Legende zu Uhr und Band.
///
/// **Sie gehört unter beide**, nicht unter die Uhr allein: „beide sprechen dieselben Farben;
/// unter der Uhr allein zog sie die linke Spalte lang und ließ rechts ein Loch“
/// (`globals.css:633-635`). Darum steht sie in der Seite als eigene Zeile unter dem Paar und
/// nicht in `Tagesuhrbild`.
///
/// Jede Zeile ist eine Farbmarke und ein Wort in Textfarbe; farbige Schrift wäre Kennung ohne
/// Lesbarkeit (`Tagesuhr.tsx:288-289`).
struct Tagesuhrlegende: View {
    let bild: Wiedergabebild

    var body: some View {
        Umbruchzeile(abstand: 22, zeilenabstand: 4) {
            ForEach(bild.legende) { eintrag in
                HStack(spacing: 6) {
                    marke(eintrag)
                    Text(eintrag.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    /// Die Marke: 10 × 10, Radius 2 - die Absicht als Umriss, weil sie ein anderer Stand
    /// derselben Sache ist.
    @ViewBuilder private func marke(_ eintrag: Wiedergabebild.Legendeneintrag) -> some View {
        if eintrag.umriss {
            RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
                .strokeBorder(Tagesbildfarben.farbe(eintrag.marke), lineWidth: 1)
                .frame(width: 10, height: 10)
        } else {
            RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
                .fill(Tagesbildfarben.farbe(eintrag.marke))
                .frame(width: 10, height: 10)
        }
    }
}

/// Die Zuordnung von Marke zu Farbe, an einer Stelle für Uhr, Band und Fahne.
///
/// Der Kern nennt nur die Sache (`Wiedergabebild.Marke`), weil es dort kein `Color` gibt; hier
/// steht die eine Übersetzung. Zwei Kopien wären zwei Stellen, an denen die Legende von dem
/// abweicht, was gezeichnet ist.
enum Tagesbildfarben {
    static func farbe(_ marke: Wiedergabebild.Marke) -> Color {
        switch marke {
        case .preis: return Farbe.preis
        case .sonne: return Farbe.pv
        case .waermepumpe: return Farbe.waermepumpe
        case .ofen: return Farbe.ofen
        }
    }
}
