import DuckCurveKit
import SwiftUI

/// Die Kostentreppe: vom Versprechen des ersten Fahrplans zur Wirklichkeit, Stufe für Stufe.
///
/// **Eine Treppe und keine fünf Balken nebeneinander**, weil die Frage nicht „wie hoch ist jede
/// Linie“ heißt, sondern „wie kam es vom einen zum anderen“ (`Kostentreppe.tsx:10-13`). Jede
/// Stufe beginnt, wo die vorige endet; ihre Länge ist ihr Anteil am Abstand, und der Faden
/// zwischen den Zeilen zeigt, dass es ein Weg ist.
///
/// **Kein `Chart`, und das ist kein Umweg.** Swift Charts kann mit `BarMark(xStart:xEnd:)`
/// schwebende Balken, aber nicht den Faden zur nächsten Zeile, nicht die Pfeilspitze und nicht
/// den Mindeststrich einer Nullstufe. Gebaut wird darum wie die ``Anteilsleiste``: eine Spur aus
/// ``GeometryReader`` und Punkte aus Prozent, „die Längen rechnet der Kern“
/// (``Nachbetrachtungsbild/treppe(_:)`` und ``Nachbetrachtungsbild/achse(_:)``).
///
/// **Die Farbe gehört der Sache, nicht der Richtung** - die Begründung steht im Kern an
/// ``Nachbetrachtungsbild/treppenfarbe(_:)``. **Geschätztes ist umrandet, nicht gefüllt**
/// (`Kostentreppe.tsx:22`): eine Linie, die der Dienst als Schätzung kennzeichnet, sieht anders
/// aus als das Gemessene.
struct Kostentreppe: View {
    let daten: NachbetrachtungOut

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    /// Die Spalte der Namen: 120 bis 190 Punkte am iPad, 84 bis 112 am Telefon
    /// (`globals.css:691`, `:723`).
    private var namensbreite: CGFloat { schmal ? 100 : 160 }
    /// Die Spalte des Betrags: 84 Punkte, am Telefon 70 (`globals.css:691`, `:723`).
    private var wertbreite: CGFloat { schmal ? 70 : 84 }
    private var lueckeImRaster: CGFloat { schmal ? 8 : 12 }

    private var stufen: [Nachbetrachtungsbild.Stufe] { Nachbetrachtungsbild.treppe(daten) }

    var body: some View {
        let alle = stufen
        if !alle.isEmpty {
            let achse = Nachbetrachtungsbild.achse(alle)
            let kette = alle.filter { $0.art != .bezug }
            let bezug = alle.filter { $0.art == .bezug }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(kette.enumerated()), id: \.element.id) { i, s in
                    zeile(
                        s, achse: achse,
                        // Der Faden führt zur nächsten Stufe. Vor einer Summe steht keiner: die
                        // steht auf dem Boden und beginnt nicht, wo die vorige endet.
                        faden: i < kette.count - 1 && kette[i + 1].art != .summe)
                }
                if !bezug.isEmpty {
                    trenner
                    ForEach(bezug) { s in zeile(s, achse: achse, faden: false) }
                }
                achsenzeile(achse)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Nachbetrachtungsworte.treppeName)
        }
    }

    // MARK: - Eine Zeile

    private func zeile(
        _ s: Nachbetrachtungsbild.Stufe,
        achse: (min: Double, max: Double, marken: [Double]), faden: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: lueckeImRaster) {
            name(s)
                .frame(width: namensbreite, alignment: .leading)
            spur(s, achse: achse, faden: faden)
            Text(Nachbetrachtungsbild.treppenwert(s))
                .font(Schrift.mono(schmal ? 12 : 13))
                .foregroundStyle(s.art == .stufe ? Farbe.text2 : Farbe.text1)
                .lineLimit(1)
                .frame(width: wertbreite, alignment: .trailing)
        }
        // Der Satz der Zeile ist in der Vorlage ihr `title` (`Kostentreppe.tsx:39`); am Telefon
        // gibt es kein Darüberfahren, also trägt ihn die Vorlesestimme.
        .accessibilityElement(children: .combine)
        .accessibilityHint(s.satz)
    }

    @ViewBuilder private func name(_ s: Nachbetrachtungsbild.Stufe) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.name + (s.geschaetzt ? " " + Nachbetrachtungsworte.geschaetzt : ""))
                .font(Schrift.sans(schmal ? 11.5 : 12.5))
                .foregroundStyle(s.art == .summe ? Farbe.text1 : Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
            // Die Zerlegung des Eingriffs in Menge, Zeitpunkt und Ofen - eine eigene Zeile
            // darunter (`globals.css:695`).
            if s.key == "eingriff", let zusatz = Nachbetrachtungsbild.eingriffszusatz(daten) {
                Text(zusatz)
                    .font(Schrift.sans(11))
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Die Spur: 22 Punkte hoch, links eine Haarlinie, darin der Balken an seiner Stelle.
    private func spur(
        _ s: Nachbetrachtungsbild.Stufe,
        achse: (min: Double, max: Double, marken: [Double]), faden: Bool
    ) -> some View {
        GeometryReader { raum in
            let spanne = achse.max - achse.min
            let teiler = spanne > 0 ? spanne : 1
            let anteil = { (x: Double) in (x - achse.min) / teiler }
            let links = raum.size.width * anteil(min(s.von, s.bis))
            // Eine Stufe von null Cent bleibt als Strich sichtbar: sie ist eine Aussage
            // (`Kostentreppe.tsx:52`).
            let lang = max(2, raum.size.width * abs(anteil(s.bis) - anteil(s.von)))
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Farbe.linie2)
                    .frame(width: 1)
                balken(s)
                    .frame(width: lang, height: s.art == .stufe ? 10 : 16)
                    .overlay(alignment: s.bis >= s.von ? .trailing : .leading) {
                        pfeilspitze(s)
                    }
                    .offset(x: links, y: s.art == .stufe ? 6 : 3)
                if faden {
                    fadenlinie(an: raum.size.width * anteil(s.bis))
                }
            }
            .frame(width: raum.size.width, height: 22, alignment: .topLeading)
        }
        .frame(height: 22)
        .frame(maxWidth: .infinity)
    }

    /// Der Balken selbst.
    ///
    /// Rechts gerundet, weil er von links wächst; eine Stufe ist flacher und an beiden Enden
    /// leicht gerundet (`globals.css:697-698`). Geschätztes ist umrandet und nicht gefüllt
    /// (`Kostentreppe.tsx:54-55`).
    ///
    /// **Vier Zweige und keine Typlöschung.** `strokeBorder` verlangt `InsettableShape`, und
    /// zwei verschiedene Formen aus einer Funktion zu geben hieße, eine eigene Hülle dafür zu
    /// bauen - für vier Zeilen, die hier ausgeschrieben kürzer sind als die Hülle.
    @ViewBuilder private func balken(_ s: Nachbetrachtungsbild.Stufe) -> some View {
        let farbe = Color(Nachbetrachtungsbild.treppenfarbe(s))
        let umriss = StrokeStyle(lineWidth: 1.5, dash: [3, 2])
        if s.art == .stufe {
            let form = RoundedRectangle(cornerRadius: 2, style: .continuous)
            if s.geschaetzt {
                form.strokeBorder(farbe, style: umriss)
            } else {
                form.fill(farbe)
            }
        } else {
            let form = UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 0, bottomLeading: 0, bottomTrailing: 4, topTrailing: 4),
                style: .continuous)
            if s.geschaetzt {
                form.strokeBorder(farbe, style: umriss)
            } else {
                form.fill(farbe)
            }
        }
    }

    /// Die Pfeilspitze: nach rechts teurer, nach links günstiger - und nur, wo es eine Richtung
    /// gibt (`globals.css:700-702`).
    @ViewBuilder private func pfeilspitze(_ s: Nachbetrachtungsbild.Stufe) -> some View {
        if Nachbetrachtungsbild.zeigtRichtung(s) {
            Pfeilspitze(nachRechts: s.bis >= s.von)
                .fill(Color(Nachbetrachtungsbild.treppenfarbe(s)))
                .frame(width: 7, height: 14)
                .offset(x: s.bis >= s.von ? 7 : -7)
        }
    }

    /// Der Faden zur nächsten Zeile: dort, wo diese endet, beginnt die nächste.
    private func fadenlinie(an x: CGFloat) -> some View {
        Rectangle()
            .fill(Farbe.linie2)
            .frame(width: 1, height: 28)
            .offset(x: x, y: 11)
    }

    // MARK: - Trenner und Achse

    /// „Zum Vergleich gerechnet“: was danach kommt, liegt nicht auf dem Weg.
    private var trenner: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(Farbe.linie1)
            Kicker(wort: Nachbetrachtungsworte.zumVergleich)
                .padding(.top, 10)
        }
        .padding(.top, 4)
    }

    /// Die Achse unter der Treppe.
    ///
    /// **Am Telefon bleiben nur Anfang und Ende** (`Kostentreppe.tsx:92`): „sechs Beträge auf
    /// hundert Punkten lägen aufeinander.“ Die erste Marke steht linksbündig, die letzte
    /// rechtsbündig, die mittleren mittig über ihrer Stelle (`globals.css:707-711`).
    private func achsenzeile(_ achse: (min: Double, max: Double, marken: [Double]))
        -> some View
    {
        HStack(alignment: .top, spacing: lueckeImRaster) {
            Color.clear.frame(width: namensbreite, height: 1)
            GeometryReader { raum in
                let spanne = achse.max - achse.min
                let teiler = spanne > 0 ? spanne : 1
                ZStack(alignment: .topLeading) {
                    ForEach(Array(achse.marken.enumerated()), id: \.offset) { i, m in
                        marke(
                            m, stelle: raum.size.width * ((m - achse.min) / teiler),
                            erste: i == 0, letzte: i == achse.marken.count - 1)
                    }
                }
                .frame(width: raum.size.width, alignment: .topLeading)
            }
            .frame(height: 16)
            .frame(maxWidth: .infinity)
            Color.clear.frame(width: wertbreite, height: 1)
        }
        .padding(.top, 2)
    }

    @ViewBuilder private func marke(
        _ m: Double, stelle: CGFloat, erste: Bool, letzte: Bool
    ) -> some View {
        if erste || letzte || !schmal {
            Text(Nachbetrachtungsbild.achsenmarke(m))
                .font(Schrift.mono(10))
                .foregroundStyle(Farbe.text3)
                .lineLimit(1)
                .fixedSize()
                .alignmentGuide(.leading) { d in
                    erste ? 0 : (letzte ? d.width : d.width / 2)
                }
                .offset(x: stelle)
        }
    }
}

/// Ein Dreieck, das nach rechts oder links zeigt - die Pfeilspitze eines Treppenbalkens.
///
/// Es gab im Projekt nichts dafür: gesucht nach `Triangle` und `Path` in `Diagramme` und
/// `Bausteine` - das Nächste sind die Rohre der Anlage, und die sind Linien. In der Vorlage ist
/// die Spitze ein Rand-Kunstgriff (`border: 7px solid transparent` mit einer gefärbten Kante,
/// `globals.css:700-702`); in SwiftUI ist ein Dreieck ein Dreieck.
private struct Pfeilspitze: Shape {
    let nachRechts: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        if nachRechts {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        } else {
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        }
        p.closeSubpath()
        return p
    }
}

#Preview("Kostentreppe") {
    ScrollView {
        Karte(kicker: "Was hat der Tag gekostet?") {
            Kostentreppe(daten: Vorschau.nachbetrachtung())
        }
        .padding()
    }
    .background(Farbe.grundVerlauf)
}
