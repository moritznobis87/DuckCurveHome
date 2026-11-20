import Charts
import DuckCurveKit
import SwiftUI

/// Der Quotenvergleich: zwei Zeilen, ein Punkt und ein Balken.
///
/// **Warum ein Bild und nicht zwei Zahlen.** Die Frage der Seite ist nicht „wie hoch ist die
/// Quote", sondern „ist sie höher als sonst". Zwei Prozentzahlen in zwei Kacheln beantworten
/// das nicht: man muss sie im Kopf vergleichen und weiß dabei nichts über ihre Unsicherheit.
/// Hier liegen beide übereinander auf derselben Spur, jede mit dem Bereich, in dem ihr wahrer
/// Wert liegt - und das Urteil fällt erst, wenn die Balken sich nicht mehr überlappen
/// (`waerme/Wirkung.tsx:40-106`).
struct Quotenbild: View {
    let bild: Wirkungsbild
    /// Die Farbe der Kartenfläche. Der Ring um den Punkt hält ihn vom Balken ab, und dafür
    /// muss er die Farbe haben, auf der er liegt - am Telefon eine andere als an der Wand.
    var ringfarbe: Color = Farbe.flaeche1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(bild.quotenzeilen) { z in
                zeile(z)
            }
            achse
            Text(bild.quotenerklaerung)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bild.quotenbeschreibung)
    }

    private func zeile(_ z: Wirkungsbild.Quotenzeile) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(z.name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .frame(width: 92, alignment: .leading)
            spur(z)
                .frame(height: 22)
            // **Die Zahl steht neben der Spur, nicht darin** (`Wirkung.tsx:92-98`: x=346 bei
            // einer Spur, die bei 332 endet). Swift Charts kennt keinen Platz ausserhalb des
            // Zeichenbereichs; eine Beschriftung über `annotation` stauchte die Skala, und die
            // beiden Zeilen stünden nicht mehr auf derselben Teilung.
            VStack(alignment: .leading, spacing: 1) {
                Zahl(
                    wert: z.zahl, einheit: z.quote == nil ? nil : "%",
                    schrift: Schrift.mono(17), einheitSchrift: Schrift.winzig,
                    farbe: Farbe.text1)
                if let b = z.bereich {
                    Text(b).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
            .frame(width: 86, alignment: .leading)
        }
    }

    @ViewBuilder private func spur(_ z: Wirkungsbild.Quotenzeile) -> some View {
        if let quote = z.quote {
            GeometryReader { raum in
                let breite = raum.size.width
                let mitte = raum.size.height / 2
                let x: (Double) -> CGFloat = { CGFloat(min(1, max(0, $0))) * breite }
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Farbe.text1.opacity(0.14))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .center)
                    if let lo = z.lo, let hi = z.hi {
                        Capsule()
                            .fill(farbe(z.rolle).opacity(0.38))
                            .frame(width: max(2, x(hi) - x(lo)), height: 10)
                            .offset(x: x(lo))
                    }
                    Circle()
                        .fill(farbe(z.rolle))
                        .overlay(Circle().strokeBorder(ringfarbe, lineWidth: 2))
                        .frame(width: 13, height: 13)
                        .offset(x: x(quote) - 6.5)
                }
                .frame(height: raum.size.height)
                .position(x: breite / 2, y: mitte)
            }
        } else {
            HStack {
                Text(z.leer).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                Spacer(minLength: 0)
            }
        }
    }

    /// Null, fünfzig, hundert - mit den Rasterlinien, an denen man die Punkte vergleicht.
    private var achse: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 92)
            GeometryReader { raum in
                ZStack(alignment: .topLeading) {
                    ForEach([0.0, 0.5, 1.0], id: \.self) { anteil in
                        Text(Formate.prozent(anteil))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                            .fixedSize()
                            .position(
                                x: CGFloat(anteil) * raum.size.width, y: 7)
                    }
                }
            }
            .frame(height: 14)
            Spacer().frame(width: 86)
        }
    }

    private func farbe(_ r: Wirkungsbild.Rolle) -> Color {
        r == .angefordert ? Farbe.waermepumpe : Farbe.mist
    }
}

/// Der Antwortfächer: alle Anforderungen am Beginn übereinandergelegt.
///
/// **Zwei Flächen, eine Zeitachse.** Oben die Leistung - jede einzelne Antwort blass, das
/// Mittel voll, dazwischen das Band der mittleren Hälfte. Unten der Anteil, der bis zu dieser
/// Minute angelaufen ist, und daneben derselbe Anteil ohne Anforderung zur selben Tageszeit.
/// Der Abstand dieser beiden Treppen ist die Wirkung; eine Zahl allein zeigt ihn nicht
/// (`waerme/Antwortfaecher.tsx`).
struct Antwortfaecher: View {
    let bild: Wirkungsbild

    /// Wo der Finger steht. Beide Flächen teilen die Auswahl - sonst zeigte die obere eine
    /// andere Minute als die untere.
    @State private var gewaehlt: Int?

    /// **Gleich breite Achsenbeschriftung für beide Flächen.** Sonst schiebt die breitere
    /// Beschriftung ihre Zeichenfläche nach rechts, und der Nullpunkt - die Minute, in der die
    /// Anforderung beginnt - steht in beiden Flächen an verschiedener Stelle. Die Vorlage
    /// erzwingt dasselbe mit `outerBoundsMode: "none"`.
    private let achsenbreite: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            auskunft
            flaeche("Leistung der Wärmepumpe in kW", hoehe: 210) {
                leistungsbild
            } achse: {
                AxisMarks(values: markenwerte) { _ in
                    AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                }
            }
            flaeche("Anteil, der bis hier angelaufen ist", hoehe: 110) {
                anteilsbild
            } achse: {
                AxisMarks(values: markenwerte) { w in
                    AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                    if let m = w.as(Double.self) {
                        AxisValueLabel {
                            Text(Wirkungsbild.achsenText(Int(m)))
                                .font(Schrift.achse)
                                .foregroundStyle(Farbe.text3)
                        }
                    }
                }
            }
            legende
        }
    }

    private var markenwerte: [Double] {
        stride(from: Double(-bild.vorMin), through: Double(bild.nachMin), by: 30).map { $0 }
    }

    // MARK: - Die beiden Flächen

    private func flaeche<Inhalt: ChartContent, Achse: AxisContent>(
        _ titel: String, hoehe: CGFloat,
        @ChartContentBuilder inhalt: () -> Inhalt,
        @AxisContentBuilder achse: () -> Achse
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titel).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            Chart {
                inhalt()
                // Die Minute, in der die Anforderung beginnt - in beiden Flächen dieselbe
                // Senkrechte.
                RuleMark(x: .value("Anforderung", 0.0))
                    .foregroundStyle(Farbe.text1.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartXScale(domain: Double(-bild.vorMin)...Double(bild.nachMin))
            .chartXSelection(value: auswahl)
            .chartXAxis { achse() }
            .frame(height: hoehe)
        }
    }

    /// Die Auswahl der beiden Flächen, gerundet auf ganze Minuten.
    private var auswahl: Binding<Double?> {
        Binding(
            get: { gewaehlt.map(Double.init) },
            set: { neu in gewaehlt = neu.map { Int($0.rounded()) } }
        )
    }

    @ChartContentBuilder private var leistungsbild: some ChartContent {
        // **Jedes Stück eine eigene Reihe.** Eine Linie über eine Lücke hinweg erfindet eine
        // Messung; Swift Charts kennt kein `connectNulls: false`, also zerlegt der Kern die
        // Kurven in zusammenhängende Stücke.
        ForEach(bild.einzelkurven) { kurve in
            ForEach(kurve.stuecke) { stueck in
                ForEach(stueck.punkte) { p in
                    LineMark(
                        x: .value("Minute", Double(p.minute)), y: .value("kW", p.kw),
                        series: .value("Reihe", stueck.id)
                    )
                    .foregroundStyle(Farbe.waermepumpe.opacity(bild.kurvendeckung))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
        }
        ForEach(bild.faecher) { p in
            if let u = p.q25Kw, let o = p.q75Kw {
                AreaMark(
                    x: .value("Minute", Double(p.minute)),
                    yStart: .value("unten", u), yEnd: .value("oben", o)
                )
                .foregroundStyle(Farbe.waermepumpe.opacity(0.22))
            }
        }
        ForEach(bild.mittel) { stueck in
            ForEach(stueck.punkte) { p in
                LineMark(
                    x: .value("Minute", Double(p.minute)), y: .value("kW", p.kw),
                    series: .value("Reihe", stueck.id)
                )
                .foregroundStyle(Farbe.waermepumpe)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        RuleMark(y: .value("Schwelle", bild.schwelleKw))
            .foregroundStyle(Farbe.linie2)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .topLeading, alignment: .leading) {
                Text("läuft ab \(Formate.kw(bild.schwelleKw)) kW")
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
            }
    }

    @ChartContentBuilder private var anteilsbild: some ChartContent {
        // Das Fenster, das als Folge zählt: alles links davon ist die Antwort auf die
        // Anforderung, alles rechts davon kam später.
        RectangleMark(
            xStart: .value("von", 0.0), xEnd: .value("bis", Double(bild.folgeMin)),
            yStart: .value("u", 0.0), yEnd: .value("o", 100.0)
        )
        .foregroundStyle(Farbe.text1.opacity(0.05))
        .annotation(position: .topLeading, alignment: .leading) {
            Text("zählt als Folge: \(bild.folgeMin) min")
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
        }
        ForEach(bild.faecher) { p in
            if let a = p.anteilAngelaufen {
                AreaMark(x: .value("Minute", Double(p.minute)), y: .value("Prozent", a * 100))
                    .foregroundStyle(Farbe.waermepumpe.opacity(0.12))
                    .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.faecher) { p in
            if let a = p.anteilAngelaufen {
                LineMark(
                    x: .value("Minute", Double(p.minute)), y: .value("Prozent", a * 100),
                    series: .value("Reihe", "angelaufen")
                )
                .foregroundStyle(Farbe.waermepumpe)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.anteilOhne, id: \.minute) { p in
            LineMark(
                x: .value("Minute", Double(p.minute)), y: .value("Prozent", p.anteil * 100),
                series: .value("Reihe", "ohne")
            )
            .foregroundStyle(Farbe.mist)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
            .interpolationMethod(.stepEnd)
        }
    }

    // MARK: - Auskunft und Legende

    @ViewBuilder private var auskunft: some View {
        if let m = gewaehlt, let a = bild.auskunft(minute: m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(a.kopf).font(Schrift.zahlKlein).foregroundStyle(Farbe.amberWeich)
                ForEach(a.zeilen) { z in
                    HStack(spacing: 6) {
                        if let r = z.rolle {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(r == .angefordert ? Farbe.waermepumpe : Farbe.mist)
                                .frame(width: 9, height: 3)
                        }
                        Text(z.text)
                            .font(Schrift.winzig)
                            .foregroundStyle(z.eingerueckt ? Farbe.text3 : Farbe.text2)
                    }
                    .padding(.leading, z.eingerueckt ? 15 : 0)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.deep)
            .overlay(
                RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                    .strokeBorder(Farbe.amber.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        } else {
            Text("Zum Lesen einer Minute die Zeichnung berühren.")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
        }
    }

    private var legende: some View {
        Umbruchzeile(abstand: 16, zeilenabstand: 5) {
            stueck("jede einzelne Antwort", Farbe.waermepumpe.opacity(0.45), hoehe: 2)
            stueck("Mittel der Leistung, unten: Anteil angelaufen", Farbe.waermepumpe, hoehe: 2)
            if let satz = bild.bandHinweis {
                Text(satz).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            } else {
                stueck(
                    "mittlere Hälfte der Antworten", Farbe.waermepumpe.opacity(0.3), hoehe: 10)
            }
            stueck("Anteil angelaufen ohne Anforderung, zur selben Tageszeit", Farbe.mist,
                   hoehe: 2, gestrichelt: true)
        }
    }

    private func stueck(_ wort: String, _ farbe: Color, hoehe: CGFloat, gestrichelt: Bool = false)
        -> some View
    {
        HStack(spacing: 5) {
            if gestrichelt {
                // Gestrichelt heißt hier: ein Vergleich, keine Messung an dieser Anforderung.
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(farbe).frame(width: 4, height: hoehe)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: hoehe > 4 ? 2 : 0)
                    .fill(farbe)
                    .frame(width: 14, height: hoehe)
            }
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }
}

/// Das Ereignisraster: eine Zeile je Anforderung, nach Verzögerung sortiert.
///
/// **Warum kein Diagramm, sondern gezeichnete Rechtecke.** Achtzig Zeilen wären achtzig
/// Diagramme; das rollt auf keinem Telefon. Jede Zeile ist darum ein `Canvas`, der in Punkten
/// rechnet - auch der Nullpunktstrich, der sonst anderthalb *Minuten* breit wäre statt
/// anderthalb Punkte (die Vorlage löst dasselbe mit `vector-effect: non-scaling-stroke`).
struct Ereignisraster: View {
    let bild: Wirkungsbild

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            achse
            ForEach(bild.gruppen, id: \.gruppe) { gruppe in
                VStack(alignment: .leading, spacing: 4) {
                    Kicker(wort: "\(gruppe.gruppe.titel) · \(gruppe.zeilen.count)")
                    ForEach(gruppe.zeilen) { z in
                        zeile(z)
                    }
                }
            }
            if let hinweis = bild.rasterHinweis {
                Text(hinweis).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
            legende
        }
    }

    private var achse: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: schmal ? 92 : 112)
            GeometryReader { raum in
                ZStack(alignment: .topLeading) {
                    ForEach(bild.achsenmarken) { m in
                        if !m.fein || !schmal {
                            Text(m.wort)
                                .font(Schrift.achse)
                                .foregroundStyle(Farbe.text3)
                                .fixedSize()
                                .position(x: CGFloat(m.anteil) * raum.size.width, y: 7)
                        }
                    }
                }
            }
            .frame(height: 14)
            Spacer().frame(width: schmal ? 78 : 104)
        }
    }

    private func zeile(_ z: Wirkungsbild.Ereigniszeile) -> some View {
        HStack(spacing: 8) {
            Text(z.wann)
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .frame(width: schmal ? 92 : 112, alignment: .leading)
            Canvas { gestalt, groesse in
                male(z, in: &gestalt, groesse: groesse)
            }
            .frame(height: 13)
            Text(z.ergebnis)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineLimit(1)
                .frame(width: schmal ? 78 : 104, alignment: .trailing)
        }
    }

    private func male(
        _ z: Wirkungsbild.Ereigniszeile, in g: inout GraphicsContext, groesse: CGSize
    ) {
        let spalten = CGFloat(max(1, bild.breite))
        let proSpalte = groesse.width / spalten
        func kasten(_ bereich: Range<Int>, y: CGFloat, hoehe: CGFloat) -> CGRect {
            CGRect(
                x: CGFloat(bereich.lowerBound) * proSpalte, y: y,
                width: max(1, CGFloat(bereich.count) * proSpalte), height: hoehe)
        }
        for b in z.steht {
            g.fill(Path(kasten(b, y: 0, hoehe: 7)), with: .color(.white.opacity(0.07)))
        }
        for b in z.laeuft {
            g.fill(Path(kasten(b, y: 0, hoehe: 7)), with: .color(Farbe.waermepumpe))
        }
        if let streifen = z.kontaktstreifen {
            g.fill(Path(kasten(streifen, y: 8, hoehe: 2)), with: .color(Farbe.mist))
        }
        // Der Nullpunkt in Punkten, nicht in Minuten.
        let x = CGFloat(bild.vorMin) * proSpalte
        g.fill(
            Path(CGRect(x: x - 0.75, y: 0, width: 1.5, height: groesse.height)),
            with: .color(.white.opacity(0.75)))
    }

    private var legende: some View {
        Umbruchzeile(abstand: 16, zeilenabstand: 5) {
            marke("Wärmepumpe läuft", Farbe.waermepumpe, hoehe: 8)
            marke("gemessen, steht", Color.white.opacity(0.12), hoehe: 8)
            marke("angefordert", Farbe.mist, hoehe: 3)
            Text("leer: keine Messung").font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }

    private func marke(_ wort: String, _ farbe: Color, hoehe: CGFloat) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(farbe)
                .frame(width: 12, height: hoehe)
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }
}
