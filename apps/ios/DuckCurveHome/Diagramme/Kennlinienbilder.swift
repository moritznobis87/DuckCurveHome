import Charts
import DuckCurveKit
import SwiftUI

/// Die drei Bilder der gemessenen Kennlinie: zweimal Streubild, einmal Kennfeld.
///
/// **Warum drei und nicht eines** - die Begründung steht im Kern (``Kennlinienbild``) und kommt
/// wörtlich aus `apps/web/src/components/waermepumpe/kennlinie.ts:7-21`. Kurz: die Arbeitszahl
/// hängt an zwei Temperaturen, ein Diagramm hat zwei Achsen, und eine dreidimensionale Fläche
/// lässt sich nicht ablesen.
///
/// **Gerechnet wird nichts hier.** Achsenbereiche, Vorlaufstufen, Geraden, Rasterfelder,
/// Kreisgrößen, Farbanteile und jeder Satz kommen aus ``Kennlinienbild`` und sind dort geprüft.

/// Die Farben dieser Bilder, die in ``Farbe`` und ``Marken`` kein Gegenstück haben.
///
/// **Warum sie hier stehen und nicht als Marke.** Die Vorlage setzt die zwei Linien als
/// Literale -
/// `rgba(255,255,255,.5)` für die Annahme und `rgba(255,255,255,.85)` für den einen Ausgleich
/// ohne Vorlaufterm (`kennlinie.ts:162`, `:130`). In ``Marken`` liegt Weiß in vier Deckungen
/// (0,92 / 0,72 / 0,58 / 0,055), und keine davon ist eine von diesen beiden: 0,5 ist leiser als
/// `text3` wäre, 0,85 lauter als `text2`. Die Datei ``Marken`` gehört allen Seiten und wird in
/// dieser Runde nicht angefasst; der Wunsch nach zwei Marken ist gemeldet. Bis dahin steht hier,
/// was die Vorlage schreibt, an einer Stelle und nicht in sechs Aufrufen.
private enum Kennlinienfarben {
    /// Die gestrichelte Annahme des Fahrplans (`kennlinie.ts:162`).
    static let annahme = Farbe.papier.opacity(0.5)
    /// Die eine Ausgleichsgerade ohne Vorlaufterm und die des zweiten Bildes
    /// (`kennlinie.ts:130`, `:208`).
    static let ausgleich = Farbe.papier.opacity(0.85)

    /// Die sechs Stopps des Kennfelds, hell für viel (`COP_FARBEN`, `kennlinie.ts:246`).
    ///
    /// **Dieselbe Arbeitszahl muss im Kennfeld der App und im Browser dieselbe Farbe haben** -
    /// sonst sagt das Bild über dieselbe Messung zwei verschiedene Dinge. Die Werte sind darum
    /// die der Vorlage und keine nächstliegende vorhandene Rampe: vier der sechs Stopps wären
    /// andere Farben. Dahin gehört sie als ``Marken``-Rampe neben die vier der Jahreskarte;
    /// diese Datei gehört in dieser Runde nicht allen Seiten, ``Marken`` schon und wird nicht
    /// angefasst. Der Wunsch nach `Marken.kopframpe` ist gemeldet. Gemischt wird mit
    /// ``Marken/rampenfarbe(_:anteil:)``, also mit derselben Mischung wie überall sonst.
    static let kopframpe: [Farbwert] = [
        Farbwert(0x173847), Farbwert(0x2F5560), Farbwert(0x667A5C),
        Farbwert(0xB3993F), Farbwert(0xF2A900), Farbwert(0xFFD778),
    ]
}

/// Die beiden Achsen der Streubilder.
///
/// **Keine Ticks, eine Rasterlinie, Beschriftung in ``Farbe/text3``** - das ist der Achsenstil
/// der Vorlage (`kennlinie.ts:97-105`). Dort steht auch `axisLine.onZero: false` mit der
/// Begründung: „mit der Vorgabe wandert die senkrechte Achse auf null Grad und steht mitten
/// zwischen den Punkten.“ Swift Charts legt die Achse ohnehin an den Rand, also ist hier nichts
/// dagegen zu tun.
private enum Kennlinienachse {
    /// Ganze Grad an der Querachse: eine Außentemperatur mit Nachkommastelle wäre an einer
    /// Achse mit sechs Marken sechsmal dieselbe Auskunft.
    static func waagerecht() -> some AxisContent {
        AxisMarks { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 0))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    /// Die Arbeitszahl mit einer Stelle: zwischen 2,5 und 3,0 liegt der halbe Unterschied, um
    /// den es auf dieser Seite geht.
    static func senkrecht() -> some AxisContent {
        AxisMarks(position: .leading) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 1))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

// MARK: - Arbeitszahl über der Außentemperatur

/// Das erste Streubild: die Punkte in der Farbe ihres Vorlaufs, darüber bis zu drei
/// Ausgleichsgeraden und die Annahme des Fahrplans.
///
/// **Die Punktfarbe ist die des Wassers** (`kennlinie.ts:22-23`): „ein Punkt bei 35 Grad hat
/// die Farbe von 35 Grad warmem Wasser im Speicher.“ Dieselbe Skala trägt das Anlagenschema und
/// das Glas des Puffers, und darum liegt sie im Kern (``Marken/wasserfarbe(_:)``) und nicht
/// hier.
///
/// **Bis zu drei Geraden statt einer.** Die App zeichnete eine Gerade beim Vorlauf in der Mitte
/// des Geltungsbereichs. Der Fächer ist aber die Aussage des Bildes: er zeigt, was fünf Grad
/// weniger Vorlauf an Arbeitszahl wert sind - und das ist die einzige Einstellung, mit der man
/// sie überhaupt beeinflussen kann.
///
/// **Die Namen stehen in der Legende und nicht am Kurvenende.** Die Vorlage hängt ein
/// `endLabel` rechts an jede Gerade und hält dafür 104 Punkte Rand frei (`kennlinie.ts:139`,
/// `:145`). Swift Charts hat kein Gegenstück, und ein Viertel der Breite für drei Wörter
/// freizuhalten wäre auf 390 Punkten teuer. Die Zuordnung bleibt erhalten: die Legende nennt
/// jede Stufe in ihrer Farbe.
struct Kennlinienstreubild: View {
    let kennlinie: KennlinieOut

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: Double?

    private var schmal: Bool { breite == .compact }
    /// 320 Punkte, am Telefon 280 (`globals.css:902`, `handy.css:244`).
    private var hoehe: CGFloat { schmal ? 280 : 320 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Achsenwort(wort: Kennlinienbild.copachse)
            diagramm
            Achsenfuss(wort: Kennlinienbild.aussenachse)
            legende
            band
            Punktauswahl(punkte: gelesenePunkte)
        }
    }

    // MARK: Das Diagramm

    private var diagramm: some View {
        Chart {
            annahmelinie
            ausgleichsgeraden
            messpunkte
        }
        .chartYScale(domain: bereich)
        .chartXSelection(value: $gelesen)
        .chartLegend(.hidden)
        .chartXAxis { Kennlinienachse.waagerecht() }
        .chartYAxis { Kennlinienachse.senkrecht() }
        .frame(height: hoehe)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Kennlinienbild.aussentitel)
    }

    private var bereich: ClosedRange<Double> {
        Kennlinienbild.copAchse(punkte: kennlinie.punkte, annahme: kennlinie.annahme)
    }

    /// Die Annahme des Fahrplans: gestrichelt, mit kleinen offenen Kreisen
    /// (`kennlinie.ts:155-162`).
    ///
    /// **Die Kreise gehören dazu.** Ohne sie ist nicht zu sehen, wo die Annahme Stützstellen
    /// hat und wo sie nur geradeaus zwischen zweien läuft - und genau das ist der Unterschied
    /// zwischen einer eingestellten Kurve und einer gemessenen.
    @ChartContentBuilder private var annahmelinie: some ChartContent {
        ForEach(kennlinie.annahme, id: \.aussenC) { a in
            LineMark(
                x: .value("draußen", a.aussenC),
                y: .value(Kennlinienbild.copachse, a.cop),
                series: .value("Reihe", "annahme")
            )
            .foregroundStyle(Kennlinienfarben.annahme)
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .symbol {
                Circle()
                    .strokeBorder(Kennlinienfarben.annahme, lineWidth: 1)
                    .frame(width: 5, height: 5)
            }
        }
    }

    @ChartContentBuilder private var ausgleichsgeraden: some ChartContent {
        ForEach(geraden) { g in
            ForEach(g.punkte) { p in
                LineMark(
                    x: .value("draußen", p.x),
                    y: .value(Kennlinienbild.copachse, p.y),
                    series: .value("Reihe", g.id)
                )
                .foregroundStyle(g.farbe)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
    }

    @ChartContentBuilder private var messpunkte: some ChartContent {
        ForEach(Array(kennlinie.punkte.enumerated()), id: \.offset) { _, p in
            PointMark(
                x: .value("draußen", p.aussenC),
                y: .value(Kennlinienbild.copachse, p.cop)
            )
            .symbol { Punktzeichen(farbe: Color(Marken.wasserfarbe(p.vorlaufC))) }
        }
    }

    // MARK: Die Geraden

    /// Eine Ausgleichsgerade mit ihrem Namen und ihrer Farbe.
    private struct Gerade: Identifiable {
        let id: String
        let farbe: Color
        let punkte: [Ende]

        struct Ende: Identifiable {
            let id: Int
            let x: Double
            let y: Double
        }
    }

    /// Eine Gerade je Vorlaufstufe in deren Wasserfarbe - ohne Vorlaufterm genau eine in
    /// Textfarbe (`kennlinie.ts:126-142`).
    private var geraden: [Gerade] {
        guard let f = kennlinie.fit else { return [] }
        let stufen: [Double] = Kennlinienbild.vorlaufStufen(f)
        if stufen.isEmpty {
            let tv: Double =
                Kennlinienbild.mitte(kennlinie.punkte.map(\.vorlaufC)) ?? 40
            return [
                Gerade(
                    id: Kennlinienbild.ausgleichswort, farbe: Kennlinienfarben.ausgleich,
                    punkte: enden(f, vorlauf: tv))
            ]
        }
        return stufen.map { tv in
            Gerade(
                id: Kennlinienbild.stufenname(tv),
                farbe: Color(Marken.wasserfarbe(tv)),
                punkte: enden(f, vorlauf: tv))
        }
    }

    private func enden(_ f: KennlinienFitOut, vorlauf: Double) -> [Gerade.Ende] {
        Kennlinienbild.gerade(f, vorlauf: vorlauf).enumerated().map { stelle, e in
            Gerade.Ende(id: stelle, x: e.aussen, y: e.cop)
        }
    }

    // MARK: Legende und Farbband

    private var legende: some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 5) {
            // Der Punkt der Legende trägt die Farbe von 40 °C Vorlauf, wie in der Vorlage
            // (`kennlinie.ts:172`, `itemStyle.color: farbe(40)`): einen Punkt in fünf Farben
            // gibt es nicht, und das Band darunter sagt, was die Farben heißen.
            Punktmarke(
                wort: Kennlinienbild.messpunktwort, farbe: Color(Marken.wasserfarbe(40)))
            // Die Legendenzeile der Annahme nennt deren Vorlauf
            // (``Kennlinienbild/annahmehinweis(_:)``, `kennlinie.ts:164`). Die Vorlage führt
            // den Satz im Hinweis am Zeiger; die App hat für die Annahmelinie keinen - die
            // Auswahl zeigt nur Messpunkte. Und ohne diese Zahl ist die gestrichelte Kurve
            // mit den Punkten nicht vergleichbar: sie gilt für einen Vorlauf, der nicht der
            // gemessene sein muss.
            if !kennlinie.annahme.isEmpty {
                Linieneintrag(
                    wort: Kennlinienbild.annahmehinweis(kennlinie),
                    farbe: Kennlinienfarben.annahme,
                    gestrichelt: true)
            }
            ForEach(geraden) { g in
                Linieneintrag(wort: g.id, farbe: g.farbe, gestrichelt: false, wortfarbe: g.farbe)
            }
        }
    }

    private var band: some View { Vorlaufband(punkte: kennlinie.punkte) }

    private var gelesenePunkte: [KennlinienPunktOut] {
        Kennlinienbild.naechsteSpalte(kennlinie.punkte, bei: gelesen, nach: .aussen)
    }
}

/// Das Verlaufsband unter einem Streubild: von wo bis wo der gemessene Vorlauf reichte
/// (`Kennlinie.tsx`, `Vorlaufskala`). Steht unter beiden Bildern, deren Punkte die Farbe ihres
/// Vorlaufs tragen: über der Außentemperatur und über dem Hub.
///
/// **Ein Band und keine fünf festen Kreise.** Die App zeigte Kreise bei 28/34/40/46/55 °C -
/// also Marken einer Skala, die es so nicht gibt. Das Band nennt die beiden Enden der
/// Messung und zeigt dazwischen die Farben, die wirklich vorkommen.
private struct Vorlaufband: View {
    let punkte: [KennlinienPunktOut]

    @ViewBuilder var body: some View {
        if let spanne = Kennlinienbild.vorlaufspanne(punkte) {
            HStack(spacing: 10) {
                Text("Vorlauf \(Formate.celsius(spanne.lowerBound))")
                    .font(Schrift.mono(12, relativeTo: .caption))
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                LinearGradient(
                    colors: Kennlinienbild.bandfarben(spanne).map { Color($0) },
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(maxWidth: 180)
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(Formate.celsius(spanne.upperBound))
                    .font(Schrift.mono(12, relativeTo: .caption))
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Kennlinienbild.bandbeschriftung(spanne))
        }
    }
}

// MARK: - Arbeitszahl über der Vorlauftemperatur

/// Das zweite Streubild - und das wichtigere an einem gleichbleibenden Wettertag.
///
/// Die Begründung steht wörtlich in der Vorlage (`kennlinie.ts:16-18`): „Solange das Wetter
/// sich nicht ändert, ist das die Ansicht, in der überhaupt etwas zu sehen ist: eine
/// Pufferladung durchläuft zwanzig Grad Vorlauf an einem Vormittag.“ In der App fehlte dieses
/// Bild ganz.
///
/// **Hier sind alle Punkte gleich gefärbt** (`kennlinie.ts:214`): die Vorlauftemperatur steht
/// schon auf der Achse, und eine zweite Kodierung derselben Größe wäre nur noch Schmuck. Der
/// Achsenbereich ist der der Punkte **ohne** die Annahme (`kennlinie.ts:184`) - die Annahme
/// kennt den Vorlauf nicht und hat in diesem Bild keine Kurve.
struct Vorlaufstreubild: View {
    let kennlinie: KennlinieOut

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: Double?

    private var schmal: Bool { breite == .compact }
    private var hoehe: CGFloat { schmal ? 280 : 320 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Achsenwort(wort: Kennlinienbild.copachse)
            diagramm
            Achsenfuss(wort: Kennlinienbild.vorlaufachse)
            legende
            Punktauswahl(punkte: gelesenePunkte)
        }
    }

    private var diagramm: some View {
        Chart {
            gerade
            messpunkte
        }
        .chartYScale(domain: Kennlinienbild.copAchse(punkte: kennlinie.punkte, annahme: []))
        .chartXSelection(value: $gelesen)
        .chartLegend(.hidden)
        .chartXAxis { Kennlinienachse.waagerecht() }
        .chartYAxis { Kennlinienachse.senkrecht() }
        .frame(height: hoehe)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Kennlinienbild.vorlauftitel)
    }

    @ChartContentBuilder private var gerade: some ChartContent {
        ForEach(Array(Kennlinienbild.vorlaufgerade(kennlinie).enumerated()), id: \.offset) {
            _, e in
            LineMark(
                x: .value("Vorlauf", e.vorlauf),
                y: .value(Kennlinienbild.copachse, e.cop),
                series: .value("Reihe", "ausgleich")
            )
            .foregroundStyle(Kennlinienfarben.ausgleich)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }

    @ChartContentBuilder private var messpunkte: some ChartContent {
        ForEach(Array(kennlinie.punkte.enumerated()), id: \.offset) { _, p in
            PointMark(
                x: .value("Vorlauf", p.vorlaufC),
                y: .value(Kennlinienbild.copachse, p.cop)
            )
            .symbol { Punktzeichen(farbe: Farbe.waermepumpe) }
        }
    }

    private var legende: some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 5) {
            Punktmarke(wort: Kennlinienbild.messpunktwort, farbe: Farbe.waermepumpe)
            if !Kennlinienbild.vorlaufgerade(kennlinie).isEmpty {
                Linieneintrag(
                    wort: Kennlinienbild.vorlaufgeradenname(kennlinie),
                    farbe: Kennlinienfarben.ausgleich, gestrichelt: false)
            }
        }
    }

    private var gelesenePunkte: [KennlinienPunktOut] {
        Kennlinienbild.naechsteSpalte(kennlinie.punkte, bei: gelesen, nach: .vorlauf)
    }
}

// MARK: - Arbeitszahl über dem Hub

/// Das dritte Streubild: die Arbeitszahl über dem Hub, Vorlauf minus draußen
/// (`kennlinie.ts`, `optionHub`; Wunsch des Hausherrn vom 24.11.2026).
///
/// Der Hub fasst beide Temperaturen in einer Zahl. Das Bild trägt deshalb auch dann, wenn der
/// Vorlauf der Heizkurve folgt und die Ebene die zwei Einflüsse nicht trennen kann. Die Punkte
/// tragen wie im ersten Bild die Farbe ihres Vorlaufs, das Band darunter erklärt sie.
struct Hubstreubild: View {
    let kennlinie: KennlinieOut

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: Double?

    private var schmal: Bool { breite == .compact }
    private var hoehe: CGFloat { schmal ? 280 : 320 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Achsenwort(wort: Kennlinienbild.copachse)
            diagramm
            Achsenfuss(wort: Kennlinienbild.hubachse)
            legende
            Vorlaufband(punkte: kennlinie.punkte)
            Punktauswahl(punkte: gelesenePunkte)
        }
    }

    private var diagramm: some View {
        Chart {
            gerade
            messpunkte
        }
        .chartYScale(domain: Kennlinienbild.copAchse(punkte: kennlinie.punkte, annahme: []))
        .chartXSelection(value: $gelesen)
        .chartLegend(.hidden)
        .chartXAxis { Kennlinienachse.waagerecht() }
        .chartYAxis { Kennlinienachse.senkrecht() }
        .frame(height: hoehe)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Kennlinienbild.hubtitel)
    }

    @ChartContentBuilder private var gerade: some ChartContent {
        ForEach(Array(Kennlinienbild.hubgerade(kennlinie).enumerated()), id: \.offset) { _, e in
            LineMark(
                x: .value("Hub", e.hub),
                y: .value(Kennlinienbild.copachse, e.cop),
                series: .value("Reihe", "ausgleich")
            )
            .foregroundStyle(Kennlinienfarben.ausgleich)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }

    @ChartContentBuilder private var messpunkte: some ChartContent {
        ForEach(Array(kennlinie.punkte.enumerated()), id: \.offset) { _, p in
            PointMark(
                x: .value("Hub", Kennlinienbild.hub(p)),
                y: .value(Kennlinienbild.copachse, p.cop)
            )
            .symbol { Punktzeichen(farbe: Color(Marken.wasserfarbe(p.vorlaufC))) }
        }
    }

    private var legende: some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 5) {
            Punktmarke(
                wort: Kennlinienbild.messpunktwort, farbe: Color(Marken.wasserfarbe(40)))
            if !Kennlinienbild.hubgerade(kennlinie).isEmpty {
                Linieneintrag(
                    wort: Kennlinienbild.ausgleichswort,
                    farbe: Kennlinienfarben.ausgleich, gestrichelt: false)
            }
        }
    }

    private var gelesenePunkte: [KennlinienPunktOut] {
        Kennlinienbild.naechsteSpalte(kennlinie.punkte, bei: gelesen, nach: .hub)
    }
}

// MARK: - Das Kennfeld

/// Beide Temperaturen zugleich: die Ausgleichsfläche von oben, die Arbeitszahl als Farbe.
///
/// **Ein Raster aus Rechtecken und kein `Canvas`.** Swift Charts hat keine Wärmekarte mit
/// Farbskala, also wird gezeichnet - und das Projekt hat dafür zwei Vorbilder: ein `Canvas`
/// (``Abdeckungskarte``, über zweitausend Felder) und gestapelte Rechtecke
/// (``Abweichungsmatrix``, knapp tausend). Das Kennfeld hat kaum mehr als zwanzig mal fünfzehn
/// Felder; gezeichnet wird es trotzdem in einem `Canvas`, weil die Belegungskreise
/// mitgezeichnet werden müssen und ein Kreis über einer Rechteckkachel in SwiftUI eine zweite
/// Lage mit eigener Vermessung wäre.
///
/// **Die Lücke zwischen den Feldern ist nicht Zierde.** Die Vorlage setzt einen Rand von einem
/// Pixel in der Kartenfläche (`kennlinie.ts:290`); ohne ihn wird aus den Feldern ein Streifen,
/// und man sieht nicht mehr, dass jedes eine eigene Zahl ist. Dieselbe Begründung steht an
/// ``Abweichungsmatrix`` (`Bausteine/Abweichungsmatrix.swift:36-45`).
struct Kennfeldbild: View {
    let feld: Kennlinienbild.Kennfeld

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }
    /// 380 Punkte, am Telefon 320 (`globals.css:903`, `handy.css:245`).
    private var hoehe: CGFloat { schmal ? 320 : 380 }
    private var achsenbreite: CGFloat { schmal ? 24 : 30 }
    private var luecke: CGFloat { schmal ? 1 : 1.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Achsenwort(wort: Kennlinienbild.kennfeldVorlaufachse)
            HStack(alignment: .top, spacing: 8) {
                vorlaufachse
                raster
                skalenband
            }
            .frame(height: hoehe)
            aussenachse
            Achsenfuss(wort: Kennlinienbild.aussenachse)
        }
    }

    // MARK: Das Raster

    /// Die Felder und die Kreise in einer Zeichnung.
    ///
    /// Oben der höchste Vorlauf: so liest sich die Fläche wie die Kennlinie daneben, in der die
    /// Arbeitszahl nach oben besser wird und der Vorlauf nach oben steigt.
    private var raster: some View {
        Canvas { gestalt, groesse in
            male(in: &gestalt, groesse: groesse)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Kennlinienbild.kennfeldtitel)
    }

    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        let spalten = feld.aussen.count
        let zeilen = feld.vorlauf.count
        guard spalten > 0, zeilen > 0 else { return }
        let breiteJeFeld = max(
            1, (groesse.width - CGFloat(spalten - 1) * luecke) / CGFloat(spalten))
        let hoeheJeFeld = max(
            1, (groesse.height - CGFloat(zeilen - 1) * luecke) / CGFloat(zeilen))
        for i in 0..<spalten {
            for j in 0..<zeilen {
                let kasten = rahmen(
                    i: i, j: j, breiteJeFeld: breiteJeFeld, hoeheJeFeld: hoeheJeFeld,
                    zeilen: zeilen)
                g.fill(Path(roundedRect: kasten, cornerRadius: 1.5), with: .color(farbe(i, j)))
            }
        }
        for b in feld.belegung {
            let kasten = rahmen(
                i: b.i, j: b.j, breiteJeFeld: breiteJeFeld, hoeheJeFeld: hoeheJeFeld,
                zeilen: zeilen)
            male(kreis: b, mittig: CGPoint(x: kasten.midX, y: kasten.midY), in: &g)
        }
    }

    private func rahmen(
        i: Int, j: Int, breiteJeFeld: CGFloat, hoeheJeFeld: CGFloat, zeilen: Int
    ) -> CGRect {
        // Die Zeile 0 ist der niedrigste Vorlauf und steht unten.
        let zeile = zeilen - 1 - j
        return CGRect(
            x: CGFloat(i) * (breiteJeFeld + luecke),
            y: CGFloat(zeile) * (hoeheJeFeld + luecke),
            width: breiteJeFeld, height: hoeheJeFeld)
    }

    private func farbe(_ i: Int, _ j: Int) -> Color {
        guard i < feld.zellen.count, j < feld.zellen[i].count else { return Farbe.flaeche2 }
        let anteil = Kennlinienbild.kennfeldanteil(feld.zellen[i][j], spanne: feld.spanne)
        return Color(Marken.rampenfarbe(Self.rampe, anteil: anteil))
    }

    /// Die Rampe des Kennfelds: die der Vorlage (``Kennlinienfarben/kopframpe``).
    private static let rampe: [Farbwert] = Kennlinienfarben.kopframpe

    /// Die Belegungskreise: je größer, desto mehr Punkte (`kennlinie.ts:291-298`).
    ///
    /// Dunkle Füllung und weißer Rand, damit sie auf jedem Feld der Rampe zu sehen sind - ein
    /// weißer Kreis verschwände auf dem hellen Ende, ein dunkler auf dem dunklen.
    private func male(kreis b: Kennlinienbild.Belegungsfeld, mittig: CGPoint, in g: inout GraphicsContext) {
        let d = CGFloat(Kennlinienbild.kreisgroesse(anzahl: b.anzahl, meiste: feld.meiste))
        let kasten = CGRect(x: mittig.x - d / 2, y: mittig.y - d / 2, width: d, height: d)
        g.fill(Path(ellipseIn: kasten), with: .color(Color(Marken.deep.mitDeckung(0.85))))
        g.stroke(Path(ellipseIn: kasten), with: .color(Farbe.papier), lineWidth: 1.2)
    }

    // MARK: Die Achsen

    /// Der Vorlauf links, von oben nach unten absteigend.
    private var vorlaufachse: some View {
        VStack(spacing: luecke) {
            ForEach(Array(feld.vorlauf.reversed().enumerated()), id: \.offset) { stelle, grad in
                Text(stelle % vorlaufschritt == 0 ? String(grad) : "")
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                    .frame(maxHeight: .infinity)
                    .frame(width: achsenbreite, alignment: .trailing)
            }
        }
    }

    /// Die Außentemperatur unter dem Raster.
    private var aussenachse: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: achsenbreite)
            HStack(spacing: luecke) {
                ForEach(Array(feld.aussen.enumerated()), id: \.offset) { stelle, grad in
                    Text(stelle % aussenschritt == 0 ? String(grad) : "")
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            }
            Spacer().frame(width: bandbreite)
        }
    }

    /// Wie viele Beschriftungen die Achsen tragen.
    ///
    /// **Nicht jede, sondern die, die passen** - dieselbe Rechnung wie in ``Abdeckungskarte``.
    /// Zwanzig Zahlen auf 300 Punkten sind ein Ziffernstreifen, und am Telefon wird es eng, noch
    /// bevor die Zahlen zweistellig sind.
    private var aussenschritt: Int {
        let hoechstens = schmal ? 6 : 12
        return max(1, Int((Double(feld.aussen.count) / Double(hoechstens)).rounded(.up)))
    }

    private var vorlaufschritt: Int {
        let hoechstens = schmal ? 6 : 10
        return max(1, Int((Double(feld.vorlauf.count) / Double(hoechstens)).rounded(.up)))
    }

    // MARK: Das Skalenband

    private var bandbreite: CGFloat { 44 }

    /// Die Skala senkrecht rechts, mit der Arbeitszahl oben und unten (`kennlinie.ts:274-288`).
    ///
    /// **Senkrecht und nicht waagerecht**, anders als bei der Jahreskarte: die Vorlage setzt
    /// `orient: "vertical"` (`:282`), und das passt zur Aussage - oben ist die bessere
    /// Arbeitszahl, so wie oben im Raster der höhere Vorlauf steht.
    private var skalenband: some View {
        let worte = Kennlinienbild.kennfeldskala(feld.spanne)
        return VStack(alignment: .leading, spacing: 4) {
            Text(worte.oben)
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
                .lineLimit(1)
            LinearGradient(
                colors: Self.rampe.reversed().map { Color($0) },
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 10)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(worte.unten)
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
                .lineLimit(1)
        }
        .frame(width: bandbreite, alignment: .leading)
    }
}

// MARK: - Die kleinen Teile, die sich beide Streubilder teilen

/// Das Zeichen eines Messpunkts: gefüllt, mit einem Rand in der Kartenfläche.
///
/// **Der Rand trennt überlappende Punkte, die Deckkraft tut das nicht.** Die App zeichnete
/// Punkte mit `opacity(0.75)` und ohne Rand; zwei Punkte übereinander wurden damit ein dunklerer
/// Punkt, und man konnte nicht sehen, dass es zwei sind. Die Vorlage setzt einen Rand von 1,5
/// Pixeln in der Kartenfläche `#123544` (`kennlinie.ts:172-173`) - also eine Lücke, die so
/// aussieht wie die Karte darunter.
private struct Punktzeichen: View {
    let farbe: Color

    var body: some View {
        Circle()
            .fill(farbe)
            .frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(Farbe.flaeche2, lineWidth: 1.5))
    }
}

/// Der Name der senkrechten Achse, über dem Bild.
///
/// **Über dem Bild und nicht gedreht daneben.** Die Vorlage setzt den Namen an die Achse
/// (`kennlinie.ts:153`); Swift Charts kennt dafür nichts, und gedrehter Text kostet Breite und
/// ist am Telefon kaum zu lesen. In der App stand bisher nirgends „COP“ - und eine Achse ohne
/// Namen macht aus einer Arbeitszahl eine Zahl.
private struct Achsenwort: View {
    let wort: String

    var body: some View {
        Text(wort)
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
    }
}

/// Der Name der waagerechten Achse, unter dem Bild und mittig wie in der Vorlage
/// (`nameLocation: "middle"`, `kennlinie.ts:152`).
private struct Achsenfuss: View {
    let wort: String

    var body: some View {
        Text(wort)
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// Ein Legendeneintrag mit einem Punkt davor.
private struct Punktmarke: View {
    let wort: String
    let farbe: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }
}

/// Ein Legendeneintrag mit einem Strich davor - gestrichelt, wo die Linie gestrichelt ist.
///
/// **Das Wort trägt die Farbe der Linie, wo es ihr Name ist.** Die Vorlage färbt das
/// `endLabel` einer Ausgleichsgeraden in deren Farbe (`kennlinie.ts:139`); hier steht der Name
/// in der Legende und nicht am Kurvenende, also muss die Zuordnung dort geschehen. Bei
/// „Annahme des Fahrplans“ bleibt das Wort in ``Farbe/text3``: die Linie ist dort kein Name,
/// sondern eine Art, und die eigene Farbe wäre heller als jeder Text der Karte.
///
/// **Der Strich selbst ist die ``Strichmarke`` aller Legenden.** Bis zum 27.11.2026 zeichnete
/// dieser Eintrag ihn als eigenes Rechteck und nahm ihm für „gestrichelt“ nur ein Viertel der
/// Deckung: die Annahmelinie ist im Bild gestrichelt, in der Legende war sie durchgezogen und
/// etwas blasser. Sechzehn Punkte breit wie in der Vorlage (`itemWidth: 16`, `kennlinie.ts:150`).
private struct Linieneintrag: View {
    let wort: String
    let farbe: Color
    let gestrichelt: Bool
    var wortfarbe: Color = Farbe.text3

    var body: some View {
        HStack(spacing: 5) {
            Strichmarke(farbe: farbe, gestrichelt: gestrichelt, breite: 16)
            Text(wort).font(Schrift.winzig).foregroundStyle(wortfarbe)
        }
    }
}

/// Was unter dem Bild steht, wenn jemand eine Stelle der Achse hält.
///
/// **Eine Spalte und nicht eine Marke.** `.chartXSelection` wählt eine Stelle der Querachse,
/// keine einzelne Marke - in einem Streubild liegen bei einer Außentemperatur mehrere Punkte,
/// und das Projekt hat kein Vorbild für die Auswahl einer Marke (gesucht nach `chartOverlay` in
/// `apps/ios/DuckCurveHome`: kein Treffer). Gezeigt werden darum **alle** Punkte dieser Spalte,
/// mit denselben Zahlen und Stellen, die die Vorlage im Hinweis am Zeiger führt
/// (`kennlinie.ts:108-112`) - und dieselben, die die aufklappbare Tabelle zeigt.
private struct Punktauswahl: View {
    let punkte: [KennlinienPunktOut]

    var body: some View {
        if !punkte.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(punkte.enumerated()), id: \.offset) { _, p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Kennlinienbild.punktzeit(p))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                        ForEach(Kennlinienbild.punktzeilen(p)) { z in
                            HStack(spacing: 12) {
                                Text(z.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                                Spacer(minLength: 8)
                                Text(z.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                            }
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}
