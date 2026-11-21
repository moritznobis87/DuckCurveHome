import Charts
import DuckCurveKit
import SwiftUI

/// Der Quotenvergleich: zwei Zeilen, ein Punkt und ein Balken.
///
/// **Warum ein Bild und nicht zwei Zahlen.** Die Frage der Seite ist nicht „wie hoch ist die
/// Quote“, sondern „ist sie höher als sonst“. Zwei Prozentzahlen in zwei Kacheln beantworten
/// das nicht: man muss sie im Kopf vergleichen und weiß dabei nichts über ihre Unsicherheit.
/// Hier liegen beide übereinander auf derselben Spur, jede mit dem Bereich, in dem ihr wahrer
/// Wert liegt - und das Urteil fällt erst, wenn die Balken sich nicht mehr überlappen
/// (`waerme/Wirkung.tsx:40-106`).
struct Quotenbild: View {
    let bild: Wirkungsbild
    /// Die Farbe der Kartenfläche. Der Ring um den Punkt hält ihn vom Balken ab, und dafür
    /// muss er die Farbe haben, auf der er liegt - am Telefon eine andere als an der Wand.
    var ringfarbe: Color = Farbe.flaeche1

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            zeilen
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

    /// Die beiden Zeilen - und hinter ihnen die Rasterlinien.
    ///
    /// **Die Linien gehen durch beide Zeilen hindurch** (`Wirkung.tsx:89-96`: von y=14 bis
    /// y=104, während die Zeilen bei y=38 und y=82 liegen). Darum liegen sie im Hintergrund
    /// dieses Blocks und nicht in der Beschriftungszeile darunter: nur eine Linie, die an beiden
    /// Punkten vorbeiläuft, macht sie vergleichbar. Das Polster gibt ihnen die Höhe, die sie in
    /// der Vorlage über die Zeilen hinaus haben.
    private var zeilen: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(bild.quotenzeilen) { z in
                zeile(z)
            }
        }
        .padding(.vertical, 6)
        .background(rasterlinien)
    }

    private var rasterlinien: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: namensbreite)
            GeometryReader { raum in
                ZStack(alignment: .leading) {
                    ForEach(stellen, id: \.self) { anteil in
                        Rectangle()
                            .fill(Farbe.rasterlinie)
                            .frame(width: 1)
                            .offset(x: CGFloat(anteil) * raum.size.width - 0.5)
                    }
                }
            }
            Spacer().frame(width: zahlenbreite)
        }
    }

    private func zeile(_ z: Wirkungsbild.Quotenzeile) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(z.name)
                .font(Schrift.sans(namensgroesse))
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .frame(width: namensbreite, alignment: .leading)
            spur(z)
                .frame(height: 22)
            // **Die Zahl steht neben der Spur, nicht darin** (`Wirkung.tsx:92-98`: x=346 bei
            // einer Spur, die bei 332 endet). Swift Charts kennt keinen Platz ausserhalb des
            // Zeichenbereichs; eine Beschriftung über `annotation` stauchte die Skala, und die
            // beiden Zeilen stünden nicht mehr auf derselben Teilung.
            VStack(alignment: .leading, spacing: 1) {
                Zahl(
                    wert: z.zahl, einheit: z.quote == nil ? nil : "%",
                    schrift: Schrift.mono(zahlengroesse), einheitSchrift: Schrift.winzig,
                    farbe: Farbe.text1)
                if let b = z.bereich {
                    Text(b)
                        .font(Schrift.mono(kleingroesse))
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                }
            }
            .frame(width: zahlenbreite, alignment: .leading)
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

    /// Null, fünfzig, hundert - die Beschriftung zu den Linien hinter den Zeilen.
    private var achse: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: namensbreite)
            GeometryReader { raum in
                ZStack(alignment: .topLeading) {
                    ForEach(stellen, id: \.self) { anteil in
                        Text(Formate.prozent(anteil))
                            .font(Schrift.mono(kleingroesse))
                            .foregroundStyle(Farbe.text3)
                            .fixedSize()
                            .position(
                                x: CGFloat(anteil) * raum.size.width, y: 7)
                    }
                }
            }
            .frame(height: kleingroesse + 4)
            Spacer().frame(width: zahlenbreite)
        }
    }

    /// Die drei Stellen der Spur: null, fünfzig, hundert Prozent (`Wirkung.tsx:89`).
    private let stellen: [Double] = [0, 0.5, 1]

    // MARK: - Maße nach Breite

    /// **Am Telefon größere Schrift** (`globals.css:676`: `.wk-q-name` 15, `.wk-q-zahl` 20,
    /// `.wk-q-klein`/`.wk-q-achse` 13 statt 12,5 / 17 / 10,5). Die Vorlage braucht das, weil ihr
    /// Bild ein SVG mit festem `viewBox` ist und auf 390 Punkten kleiner gerechnet wird als auf
    /// 520; hier wächst nur die Spur mit, die Schrift stand fest. Die Zahlenspalte wächst mit,
    /// sonst bricht „94 bis 100 %“ in Mono 13 um.
    private var namensgroesse: CGFloat { schmal ? 15 : 12.5 }
    private var zahlengroesse: CGFloat { schmal ? 20 : 17 }
    private var kleingroesse: CGFloat { schmal ? 13 : 10.5 }
    private var namensbreite: CGFloat { 92 }
    private var zahlenbreite: CGFloat { schmal ? 98 : 86 }

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
///
/// **Beide Flächen haben eine senkrechte Achse, und die untere eine feste.** Das fehlte, und es
/// war der schwerste Fehler dieser Seite: ohne `chartYScale` skaliert Swift Charts die untere
/// Fläche nach ihren Daten, und eine Treppe, die bis 30 Prozent steigt, reicht dann bis an den
/// oberen Rand - sie sieht aus wie volle Folgsamkeit. Die Vorlage setzt dort ausdrücklich
/// `min: 0, max: 100, interval: 50` (`Antwortfaecher.tsx:164-171`), für die obere `min: 0` mit
/// drei Marken (`:157-163`). Gerechnet wird die Spanne im Kern
/// (``Wirkungsbild/leistungsspanne``), gezeichnet hier.
struct Antwortfaecher: View {
    let bild: Wirkungsbild

    /// Wo der Finger steht. Beide Flächen teilen die Auswahl - sonst zeigte die obere eine
    /// andere Minute als die untere.
    @State private var gewaehlt: Int?

    /// **Gleich breite Achsenbeschriftung für beide Flächen.** Sonst schiebt die breitere
    /// Beschriftung ihre Zeichenfläche nach rechts, und der Nullpunkt - die Minute, in der die
    /// Anforderung beginnt - steht in beiden Flächen an verschiedener Stelle. Oben stehen
    /// „0/2/4/6“, unten „0 %/50 %/100 %“; auf diese Breite gebracht, rücken beide Flächen gleich
    /// weit ein. Die Vorlage erzwingt dasselbe mit `outerBoundsMode: "none"` und festen Rändern
    /// (`Antwortfaecher.tsx:34-35`, `:148-154`).
    private let achsenbreite: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            auskunft
            leistungsflaeche
            anteilsflaeche
            legende
        }
    }

    // MARK: - Die beiden Flächen

    /// **Der Titel steht über der Fläche, nicht an der Achse** (`Antwortfaecher.tsx:103-114`):
    /// „neben der Achse stieße er mit deren Zahlen zusammen“. Mono 10, wie dort - dieselbe
    /// Schrift wie die Achsenzahlen darunter, damit er zur Fläche gehört und nicht zum Text.
    private func flaechentitel(_ titel: String) -> some View {
        Text(titel).font(Schrift.achse).foregroundStyle(Farbe.text3)
    }

    private var leistungsflaeche: some View {
        VStack(alignment: .leading, spacing: 3) {
            flaechentitel("Leistung der Wärmepumpe in kW")
            Chart {
                leistungsbild
                nulllinie
            }
            .chartXScale(domain: fenster)
            .chartYScale(domain: bild.leistungsspanne)
            .chartXSelection(value: auswahl)
            // Beschriftet wird nur die untere Fläche (`xAchse(0, false)`,
            // `Antwortfaecher.tsx:155`): zwei Zeitachsen übereinander sagen dasselbe zweimal.
            .chartXAxis(.hidden)
            .chartYAxis { kilowattmarken }
            .frame(height: 210)
        }
    }

    private var anteilsflaeche: some View {
        VStack(alignment: .leading, spacing: 3) {
            flaechentitel("Anteil, der bis hier angelaufen ist")
            Chart {
                anteilsbild
                nulllinie
            }
            .chartXScale(domain: fenster)
            .chartYScale(domain: Wirkungsbild.anteilsspanne)
            .chartXSelection(value: auswahl)
            .chartXAxis { zeitachse }
            .chartYAxis { prozentmarken }
            .frame(height: 110)
        }
    }

    private var fenster: ClosedRange<Double> {
        Double(-bild.vorMin)...Double(bild.nachMin)
    }

    // MARK: - Die Achsen

    /// Die Zeitachse: Marken alle 30 Minuten, die Einheit nur am Nullpunkt und am Ende.
    ///
    /// Die Wörter kommen fertig aus dem Kern (``Wirkungsbild/faechermarken``). Hier stand
    /// `achsenText`, und das schreibt die Einheit immer mit - „min“ fünfmal unter einer Achse
    /// (Begründung der Vorlage: `Antwortfaecher.tsx:85-86`).
    private var zeitachse: some AxisContent {
        AxisMarks(values: bild.faechermarken.map { Double($0.minute) }) { wert in
            AxisValueLabel {
                if let m = wert.as(Double.self) {
                    Text(zeitwort(m))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private func zeitwort(_ wert: Double) -> String {
        let minute = Int(wert.rounded())
        return bild.faechermarken.first { $0.minute == minute }?.wort
            ?? Wirkungsbild.achsenmarke(minute, ende: bild.nachMin)
    }

    private var kilowattmarken: some AxisContent {
        AxisMarks(position: .leading, values: bild.leistungsmarken) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let p = wert.as(Double.self) {
                    achsenwort(bild.leistungswort(p))
                }
            }
        }
    }

    private var prozentmarken: some AxisContent {
        AxisMarks(position: .leading, values: Wirkungsbild.anteilsmarken) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let p = wert.as(Double.self) {
                    achsenwort(Wirkungsbild.anteilswort(p))
                }
            }
        }
    }

    private func achsenwort(_ wort: String) -> some View {
        Text(wort)
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
            .lineLimit(1)
            .frame(width: achsenbreite, alignment: .trailing)
    }

    /// Die Minute, in der die Anforderung beginnt - in beiden Flächen dieselbe Senkrechte.
    @ChartContentBuilder private var nulllinie: some ChartContent {
        RuleMark(x: .value("Anforderung", 0.0))
            .foregroundStyle(Farbe.text1.opacity(0.75))
            .lineStyle(StrokeStyle(lineWidth: 1.5))
    }

    /// Die Auswahl der beiden Flächen, gerundet auf ganze Minuten.
    private var auswahl: Binding<Double?> {
        Binding(
            get: { gewaehlt.map(Double.init) },
            set: { neu in gewaehlt = neu.map { Int($0.rounded()) } }
        )
    }

    // MARK: - Was in den Flächen steht

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
        // Das Band bricht ab, wo zu wenige Ereignisse gemessen haben - darum auch hier Stücke
        // mit je eigener Reihe und keine Fläche über alle Minuten (``Wirkungsbild/Bandstueck``).
        ForEach(bild.band) { stueck in
            ForEach(stueck.punkte) { p in
                AreaMark(
                    x: .value("Minute", Double(p.minute)),
                    yStart: .value("unten", p.unten), yEnd: .value("oben", p.oben),
                    series: .value("Reihe", stueck.id)
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
            yStart: .value("u", Wirkungsbild.anteilsspanne.lowerBound),
            yEnd: .value("o", Wirkungsbild.anteilsspanne.upperBound)
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

/// Der Druckzustand einer Rasterzeile.
///
/// **Hover gibt es in der App nicht.** Die Vorlage legt der Zeile unter dem Zeiger einen Grund
/// unter und hellt ihr Ergebniswort auf (`globals.css:664`, `:668`); beides hat in SwiftUI kein
/// Gegenstück. Der übliche Weg im Haus - der sichtbare Verweis in Bernstein mit „›“
/// (`Karte.swift:254-257`) - wäre bei achtzig Zeilen achtzigmal Lärm. Bleibt der Druckzustand,
/// und der Satz im Kartenkopf, den die Vorlage ohnehin schreibt (`Wirkung.tsx:235`).
///
/// Polster und Radius sind die der Vorlage (`globals.css:663`: `padding: 3px 6px`,
/// `border-radius: 4px`) - und die Achsenzeile trägt dasselbe Polster, weil sie dort dieselbe
/// Rasterzeile ist (`.wk-kopfzeile`, `Ereignisraster.tsx:65`).
private struct Rasterzeilenstil: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(configuration.isPressed ? Farbe.linie1 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .contentShape(Rectangle())
    }
}

/// Das Ereignisraster: eine Zeile je Anforderung, nach Verzögerung sortiert.
///
/// **Warum kein Diagramm, sondern gezeichnete Rechtecke.** Achtzig Zeilen wären achtzig
/// Diagramme; das rollt auf keinem Telefon. Jede Zeile ist darum ein `Canvas`, der in Punkten
/// rechnet - auch der Nullpunktstrich, der sonst anderthalb *Minuten* breit wäre statt
/// anderthalb Punkte (die Vorlage löst dasselbe mit `vector-effect: non-scaling-stroke`).
///
/// **Jede Zeile führt in die Wiedergabe dieses Augenblicks** (`Ereignisraster.tsx:22-23`,
/// `:37`). Das Raster sagt, dass die Maschine am Dienstag nicht folgte; warum, zeigt das
/// Anlagenschema von Dienstag. Das Ziel liegt fertig im Kern
/// (``Wirkungsbild/Ereigniszeile/weg``); gesprungen wird über den ``Wegweiser``, und der
/// Fragezeichenteil `?day=&t=` übersteht das - ``Bereiche/weiterleitung(_:)`` putzt ihn
/// absichtlich nicht weg, und ``Wiedergabeziel/ausWeg(_:)`` liest ihn in `Seitenwahl` zurück.
struct Ereignisraster: View {
    let bild: Wirkungsbild

    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            achse
            ForEach(bild.gruppen, id: \.gruppe) { gruppe in
                VStack(alignment: .leading, spacing: 4) {
                    Kicker(wort: "\(gruppe.gruppe.titel) · \(gruppe.zeilen.count)")
                        .padding(.leading, 6)
                    ForEach(gruppe.zeilen) { z in
                        zeile(z)
                    }
                }
            }
            legende
        }
    }

    /// Die Achsenzeile.
    ///
    /// **Die erste und die letzte Marke hängen nicht über den Rand.** Alle Marken mittig gesetzt
    /// hieß: „−30 min“ reichte nach links in die Datumsspalte und „+120 min“ nach rechts aus der
    /// Zeile. Die Vorlage nimmt genau diesen beiden den Versatz (`globals.css:672-673`:
    /// `:first-child { transform: none }`, `:last-child { translateX(-100%) }`).
    private var achse: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: datumsbreite)
            GeometryReader { raum in
                ZStack(alignment: .topLeading) {
                    ForEach(Array(bild.achsenmarken.enumerated()), id: \.element.id) { i, m in
                        if !m.fein || !schmal {
                            achsenmarke(m, stelle: i, breite: raum.size.width)
                        }
                    }
                }
            }
            .frame(height: 14)
            Spacer().frame(width: ergebnisbreite)
        }
        .padding(.horizontal, 6)
    }

    private func achsenmarke(
        _ m: Wirkungsbild.Achsenmarke, stelle: Int, breite: CGFloat
    ) -> some View {
        let x = CGFloat(m.anteil) * breite
        let erste = stelle == 0
        let letzte = stelle == bild.achsenmarken.count - 1
        let ausrichtung: Alignment = erste ? .leading : (letzte ? .trailing : .center)
        let versatz: CGFloat = erste ? x : (letzte ? x - breite : x - breite / 2)
        return Text(m.wort)
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
            .fixedSize()
            .frame(width: breite, alignment: ausrichtung)
            .offset(x: versatz, y: 0)
    }

    private func zeile(_ z: Wirkungsbild.Ereigniszeile) -> some View {
        Button {
            wegweiser.gehe(z.weg)
        } label: {
            zeileninhalt(z)
        }
        .buttonStyle(Rasterzeilenstil())
        .accessibilityLabel(
            "\(z.wann) · \(z.ergebnis) · \(z.kontaktMin) min angefordert. "
                + "Öffnet die Wiedergabe.")
    }

    private func zeileninhalt(_ z: Wirkungsbild.Ereigniszeile) -> some View {
        HStack(spacing: 8) {
            Text(z.wann)
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .frame(width: datumsbreite, alignment: .leading)
            Canvas { gestalt, groesse in
                male(z, in: &gestalt, groesse: groesse)
            }
            .frame(height: 13)
            // **Linksbündig wie die Rasterspalte der Vorlage** (`globals.css:663`, `:667`:
            // `.wk-ergebnis` hat keine eigene Ausrichtung). Rechts ausgerichtet standen die
            // Wörter von achtzig Zeilen auf der anderen Kante als in der Vorlage.
            Text(z.ergebnis)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineLimit(1)
                .frame(width: ergebnisbreite, alignment: .leading)
        }
    }

    private var datumsbreite: CGFloat { schmal ? 92 : 112 }
    private var ergebnisbreite: CGFloat { schmal ? 78 : 104 }

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

    /// Die Legende - und als ihr **letzter Eintrag** der Hinweis, dass nur die jüngsten achtzig
    /// Zeilen dastehen (`Ereignisraster.tsx:110-114`: derselbe `<ul>`). Als eigene Zeile über
    /// der Legende las er sich wie eine Überschrift des Rasters und nicht wie seine Fußnote.
    private var legende: some View {
        Umbruchzeile(abstand: 16, zeilenabstand: 5) {
            marke("Wärmepumpe läuft", Farbe.waermepumpe, hoehe: 8)
            marke("gemessen, steht", Color.white.opacity(0.12), hoehe: 8)
            marke("angefordert", Farbe.mist, hoehe: 3)
            Text("leer: keine Messung").font(Schrift.winzig).foregroundStyle(Farbe.text3)
            if let hinweis = bild.rasterHinweis {
                Text(hinweis).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
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
