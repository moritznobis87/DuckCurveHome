import Charts
import DuckCurveKit
import SwiftUI

/// Die drei gezeichneten Karten der Seite „Betrieb der Wärmepumpe“.
///
/// **Warum sie hier und nicht in der Seite stehen.** Es sind drei `Chart`-Bäume mit je einer
/// Ablesezeile, einer eigenen Achsenbehandlung und einer eigenen Legende; in der Seitendatei
/// wären das vierhundert Zeilen zwischen Kopfsatz und Fußnoten, und der Aufbau der Seite - die
/// Reihenfolge der Vorlage - wäre darin nicht mehr zu sehen. Das vierte Bild der Vorlage, die
/// Lauflängen, steht auch hier, obwohl es ein schlichtes Balkenbild ist: es braucht die Zahl
/// über dem Balken und dieselbe Ablesezeile wie seine Nachbarn.
///
/// **Was alle drei gemeinsam haben, und warum.**
///
/// - **Eine Ablesezeile unter dem Bild statt eines schwebenden Kästchens.** Die Vorlage hat an
///   jedem Diagramm einen Hinweis am Finger (`betrieb.ts:25-31`). Swift Charts hat kein
///   Gegenstück; der Weg im Projekt ist ``Ablesung`` unter dem Bild
///   (`Prognosezeichnung.swift:55-86` begründet es: eine Beschriftung über `annotation`
///   staucht die Skala, und dann stehen zwei Karten nicht mehr auf derselben Teilung).
///   Solange niemand berührt, steht dort die Aufforderung - sonst springt das Bild beim ersten
///   Tippen um die Höhe des Kastens.
/// - **320 Punkte hoch, am Telefon 280** (`globals.css:902`, `handy.css:244`).
/// - **Am Telefon größere Achsenschrift und weniger Schritte.** Die Vorlage stellt am Handy
///   jedes Diagramm gleich nach: Achsenschrift mindestens 11 Pixel, Wertachsen höchstens drei
///   Schritte (`charts/handy.ts:3-18`).
/// - **Die Farben kommen aus dem Kern** (``Betriebsbild/stundenreihen(_:)``,
///   ``Betriebsbild/copfarbe(_:)``), nicht aus der Ansicht: die Zuordnung Reihe → Farbe ist in
///   `palette.ts:46-53` eine begründete Entscheidung und wird dort geprüft.
enum Betriebsmasse {
    /// Die Höhe eines Diagramms (`globals.css:902`: 320; `handy.css:244`: 280).
    static func hoehe(schmal: Bool) -> CGFloat { schmal ? 280 : 320 }

    /// Die Achsenschrift. Am Telefon eine Stufe größer - `charts/handy.ts` setzt dort
    /// mindestens 11 Pixel, weil 10 auf 390 Punkten nicht mehr gelesen wird.
    static func achsenschrift(schmal: Bool) -> Font {
        schmal ? Schrift.mono(11, relativeTo: .caption2) : Schrift.achse
    }

    /// Wie viele Schritte eine Wertachse trägt (`charts/handy.ts`: am Handy höchstens drei).
    static func schritte(schmal: Bool) -> Int { schmal ? 3 : 4 }

    /// Wie viele Wörter an die Tagesachse passen - dieselbe Auswahl wie in ``Balkenbild``.
    static func tagesbeschriftungen(_ woerter: [String], schmal: Bool) -> [String] {
        Achse.beschriftungen(woerter, hoechstens: schmal ? 6 : 12)
    }

    /// Die Zeile unter einem Bild, die seine Achsen nennt - ECharts schreibt den Namen an die
    /// Achse selbst, Swift Charts hat dafuer keinen Platz. Der Wortlaut steht im Kern.
    static func achsenwort(_ wort: String) -> some View {
        Text(wort)
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ein Eintrag der handgebauten Legende: Klotz oder Punkt, dann das Wort.
    @ViewBuilder static func legendenpunkt(wort: String, farbe: Color, raute: Bool) -> some View {
        HStack(spacing: 6) {
            if raute {
                Rectangle().fill(farbe).frame(width: 8, height: 8).rotationEffect(.degrees(45))
            } else {
                Circle().fill(farbe).frame(width: 8, height: 8)
            }
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }
}

// MARK: - Diagramm 1: Laufstunden je Tag

/// Was die Maschine an jedem Tag tat, als gestapelte Balken: Heizen, Abtauen, Heizstab.
///
/// **Die Frage der Karte** (`betrieb.ts:8`): wie lange lief sie, und womit? Die Stapelhöhe ist
/// die Laufzeit, und die Teile sagen, wohin sie ging.
///
/// **Der Spalt zwischen den Teilen.** Die Vorlage zieht dafür einen ein Pixel breiten Rand in
/// der Flächenfarbe (`betrieb.ts:100-101`: „Ein Spalt in der Farbe der Fläche trennt die Teile
/// eines Balkens“). `BarMark` kennt keinen Rand; hier tut es die Rundung von zwei Punkten -
/// die Absicht bleibt dieselbe, die Teile sollen trennbar sein, und sie ist hier festgehalten,
/// damit sie beim nächsten Umbau nicht als Zufall wegfällt.
struct Laufstundenbild: View {
    let betrieb: BetriebOut

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }
    private var reihen: [Betriebsbild.Balkenreihe] { Betriebsbild.stundenreihen(betrieb) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bild
            Betriebsmasse.achsenwort(Betriebsbild.achseStunden)
            Ablesung(
                kopf: abgelesen.map { Tag.punkt($0.tag) },
                zeilen: zeilen,
                aufforderung: "Zum Lesen eines Tages die Zeichnung berühren.")
        }
    }

    private var abgelesen: BetriebTagOut? {
        Betriebsbild.tagMit(betrieb, beschriftung: gelesen)
    }

    private var zeilen: [Ablesungszeile] {
        guard let t = abgelesen else { return [] }
        return Betriebsbild.tagzeilen(t).map { Ablesungszeile(text: "\($0.wort) \($0.wert)") }
    }

    private var bild: some View {
        Chart { balken }
            .chartForegroundStyleScale(
                domain: reihen.map(\.name),
                range: reihen.map { Color($0.farbe) }
            )
            // Unten links, wie in der Vorlage (`betrieb.ts:39`: `bottom: 0, left: 0`).
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .chartXSelection(value: $gelesen)
            .chartXAxis { tagesachse }
            .chartYAxis { stundenachse }
            .frame(height: Betriebsmasse.hoehe(schmal: schmal))
    }

    @ChartContentBuilder private var balken: some ChartContent {
        ForEach(reihen) { r in
            ForEach(Array(r.werte.enumerated()), id: \.offset) { _, w in
                BarMark(
                    x: .value("Tag", w.beschriftung),
                    y: .value("Stunden", w.wert),
                    width: balkenbreite,
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Reihe", r.name))
                .cornerRadius(2)
            }
        }
    }

    private var balkenbreite: MarkDimension {
        Betriebsbild.balkenbreite(betrieb).map { MarkDimension.fixed(CGFloat($0)) } ?? .automatic
    }

    @AxisContentBuilder private var tagesachse: some AxisContent {
        let woerter = reihen.first?.werte.map(\.beschriftung) ?? []
        return AxisMarks(
            values: Betriebsmasse.tagesbeschriftungen(woerter, schmal: schmal)
        ) { wert in
            AxisValueLabel {
                if let s = wert.as(String.self) {
                    Text(s)
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    @AxisContentBuilder private var stundenachse: some AxisContent {
        AxisMarks(
            position: .leading,
            values: .automatic(desiredCount: Betriebsmasse.schritte(schmal: schmal))
        ) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 0))
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

// MARK: - Diagramm 2: Arbeitszahl je Tag

/// Die Arbeitszahl je Tag in zwei Linien: im Heizbetrieb und über alles.
///
/// **Der Abstand der beiden Linien ist die Aussage** (`betrieb.ts:12-14`): „über alles“ enthält
/// jeden Anlauf, das Abtauen und den Heizstab, „im Heizbetrieb“ nur eingeschwungene Fenster -
/// die Lücke zwischen ihnen ist, was Takten und Abtauen an dem Tag gekostet haben.
///
/// **Ein Tag ohne Lauf bleibt eine Lücke.** `connectNulls: false` (`betrieb.ts:137`); der Kern
/// liefert dafür Stücke mit eigenem Reihenschlüssel, weil Swift Charts sonst eine Linie über
/// die Lücke zieht - und damit eine Arbeitszahl behauptet, die niemand gemessen hat.
struct Arbeitszahlbild: View {
    let betrieb: BetriebOut

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }
    private var stuecke: [Betriebsbild.Copstueck] { Betriebsbild.copstuecke(betrieb) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bild
            Betriebsmasse.achsenwort(Betriebsbild.achseCop)
            legende
            Ablesung(
                kopf: abgelesen.map { Tag.punkt($0.tag) },
                zeilen: zeilen,
                aufforderung: "Zum Lesen eines Tages die Zeichnung berühren.")
        }
    }

    private var abgelesen: BetriebTagOut? {
        Betriebsbild.tagMit(betrieb, beschriftung: gelesen)
    }

    private var zeilen: [Ablesungszeile] {
        guard let t = abgelesen else { return [] }
        return Betriebsbild.copzeilen(t).map { z in
            let reihe = Betriebsbild.Copreihe(rawValue: z.wort)
            return Ablesungszeile(
                text: "\(z.wort) \(z.wert)",
                farbe: reihe.map { Color(Betriebsbild.copfarbe($0)) } ?? Farbe.text2)
        }
    }

    private var bild: some View {
        Chart { kurven }
            .chartYScale(domain: Betriebsbild.copSpanne(betrieb))
            .chartXSelection(value: $gelesen)
            .chartXAxis { tagesachse }
            .chartYAxis { copachse }
            .frame(height: Betriebsmasse.hoehe(schmal: schmal))
    }

    @ChartContentBuilder private var kurven: some ChartContent {
        ForEach(stuecke) { s in
            ForEach(s.punkte) { p in
                LineMark(
                    x: .value("Tag", p.beschriftung),
                    y: .value("COP", p.wert),
                    series: .value("Reihe", s.id)
                )
                .foregroundStyle(Color(Betriebsbild.copfarbe(s.reihe)))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            ForEach(s.punkte) { p in
                PointMark(x: .value("Tag", p.beschriftung), y: .value("COP", p.wert))
                    .foregroundStyle(Color(Betriebsbild.copfarbe(s.reihe)))
                    .symbol(.circle)
                    .symbolSize(40)
            }
        }
    }

    /// **Eine eigene Legende und nicht die von Swift Charts.** `chartForegroundStyleScale`
    /// nennt jeden Reihenschlüssel, und die heißen hier „über alles 0“ und „über alles 1“ -
    /// zwei Einträge für eine Linie, sobald ein Tag ohne Lauf dazwischenliegt.
    private var legende: some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 6) {
            ForEach(Betriebsbild.Copreihe.allCases, id: \.self) { r in
                Betriebsmasse.legendenpunkt(
                    wort: r.rawValue, farbe: Color(Betriebsbild.copfarbe(r)), raute: false)
            }
        }
    }

    @AxisContentBuilder private var tagesachse: some AxisContent {
        let woerter = betrieb.tage.map { Tag.punkt($0.tag) }
        return AxisMarks(
            values: Betriebsmasse.tagesbeschriftungen(woerter, schmal: schmal)
        ) { wert in
            AxisValueLabel {
                if let s = wert.as(String.self) {
                    Text(s)
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    @AxisContentBuilder private var copachse: some AxisContent {
        AxisMarks(
            position: .leading,
            values: .automatic(desiredCount: Betriebsmasse.schritte(schmal: schmal))
        ) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 1))
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

// MARK: - Diagramm 3: Wie lange ein Lauf dauert

/// Die Lauflängen als Balken je Klasse - das Bild, an dem Takten zu sehen ist.
///
/// **Die Zahl steht über dem Balken** (`betrieb.ts:172`: `label.position: "top"`). Das ist
/// nicht Zierde: die Klassen sind ungleich breit („unter 10 min“ gegen „ab 90 min“), und ohne
/// die Zahl liest man aus der Höhe ein Verhältnis, das die Klassenbreiten verzerren.
struct Lauflaengenbild: View {
    let betrieb: BetriebOut

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bild
            Betriebsmasse.achsenwort(Betriebsbild.achseLaeufe)
            Ablesung(
                kopf: abgelesen.map(Betriebsbild.klassenName),
                zeilen: zeilen,
                aufforderung: "Zum Lesen einer Klasse die Zeichnung berühren.")
        }
    }

    private var abgelesen: BetriebKlasseOut? {
        Betriebsbild.klasseMit(betrieb, name: gelesen)
    }

    private var zeilen: [Ablesungszeile] {
        guard let k = abgelesen else { return [] }
        return [Ablesungszeile(text: "Läufe \(k.laeufe)")]
    }

    private var bild: some View {
        Chart { balken }
            .chartXSelection(value: $gelesen)
            .chartXAxis { klassenachse }
            .chartYAxis { laufachse }
            .frame(height: Betriebsmasse.hoehe(schmal: schmal))
    }

    @ChartContentBuilder private var balken: some ChartContent {
        ForEach(betrieb.klassen, id: \.vonMin) { k in
            BarMark(
                x: .value("Klasse", Betriebsbild.klassenName(k)),
                y: .value("Läufe", Double(k.laeufe)),
                width: .fixed(46)
            )
            .foregroundStyle(Farbe.waermepumpe)
            .cornerRadius(4)
            .annotation(position: .top, alignment: .center) {
                Text(String(k.laeufe))
                    .font(Betriebsmasse.achsenschrift(schmal: schmal))
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    @AxisContentBuilder private var klassenachse: some AxisContent {
        AxisMarks(values: betrieb.klassen.map(Betriebsbild.klassenName)) { wert in
            AxisValueLabel {
                if let s = wert.as(String.self) {
                    Text(s)
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    /// Nur ganze Zahlen - „2,5 Läufe“ zählt etwas, das es nicht gibt (`betrieb.ts:156`).
    @AxisContentBuilder private var laufachse: some AxisContent {
        AxisMarks(
            position: .leading,
            values: Betriebsbild.laufmarken(betrieb, hoechstens: Betriebsmasse.schritte(schmal: schmal) + 1)
        ) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 0))
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

// MARK: - Diagramm 4: Die Heizkurve des Reglers

/// Die Heizkurve, wie der Regler sie fährt: der Sollwert jeder Stunde über der
/// Außentemperatur, dazu der erreichte Vorlauf und die Gerade durch die Punkte.
///
/// **Das ist der Unterschied zur Seite „Regler“.** Dort steht, was eingestellt *ist*; hier
/// steht, was dabei herauskommt. Die beiden müssen nicht dasselbe sein, und wenn sie es nicht
/// sind, ist das die interessanteste Auskunft der Seite.
///
/// **Die Punktwolke ist der Gegenstand, nicht die Gerade.** Die App zeigte bis hierher nur
/// `a + b·t` über vierundzwanzig Stützstellen - eine Karte, die eine Formel zeichnet. Erst mit
/// den Punkten hat der Satz der Vorlage einen Gegenstand: „Liegen Punkte weit über der
/// Geraden, hat der Regler dort für Warmwasser mehr verlangt“ (`Betrieb.tsx:124`).
///
/// **Beide Achsen ohne Nullzwang** (`scale: true`, `betrieb.ts:195-196`); die Spannen rechnet
/// der Kern, weil `chartXScale`/`chartYScale` eine fertige brauchen.
struct Reglerkurvenbild: View {
    let betrieb: BetriebOut

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: Double?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        if let spannen = Betriebsbild.heizkurvenspannen(betrieb) {
            VStack(alignment: .leading, spacing: 10) {
                bild(spannen)
                Betriebsmasse.achsenwort(Betriebsbild.achseHeizkurve)
                legende
                Ablesung(
                    kopf: abgelesen.map(Betriebsbild.stundenkopf),
                    zeilen: zeilen,
                    aufforderung: "Zum Lesen einer Stunde die Zeichnung berühren.")
            }
        } else {
            Leer(satz: Betriebsbild.keineStundeSatz)
        }
    }

    private var abgelesen: BetriebStundeOut? {
        Betriebsbild.stundeBei(betrieb, aussen: gelesen)
    }

    private var zeilen: [Ablesungszeile] {
        guard let s = abgelesen else { return [] }
        return Betriebsbild.stundenzeilen(s).map { Ablesungszeile(text: "\($0.wort) \($0.wert)") }
    }

    private func bild(
        _ spannen: (aussen: ClosedRange<Double>, vorlauf: ClosedRange<Double>)
    ) -> some View {
        Chart { punkte }
            .chartXScale(domain: spannen.aussen)
            .chartYScale(domain: spannen.vorlauf)
            .chartXSelection(value: $gelesen)
            .chartXAxis { gradachse }
            .chartYAxis { vorlaufachse }
            .frame(height: Betriebsmasse.hoehe(schmal: schmal))
    }

    /// **Die Zeichenfolge ist die Stapelordnung der Vorlage** (`z` in `betrieb.ts:213-236`):
    /// erreicht (2), Gerade (3), Sollwert (4). Swift Charts zeichnet, was später kommt, nach
    /// oben - und obenauf gehört der Sollwert, weil er die Reihe ist, um die es geht.
    @ChartContentBuilder private var punkte: some ChartContent {
        ForEach(Betriebsbild.erreichtpunkte(betrieb)) { p in
            PointMark(x: .value("draußen", p.aussen), y: .value("Vorlauf", p.vorlauf))
                .foregroundStyle(Farbe.diagrammSpeicher)
                .symbol(.diamond)
                .symbolSize(40)
        }
        if let hk = betrieb.heizkurve {
            ForEach(Betriebsbild.geradenpunkte(hk)) { p in
                LineMark(
                    x: .value("draußen", p.aussen),
                    y: .value("Vorlauf", p.vorlauf),
                    series: .value("Reihe", "Gerade")
                )
                .foregroundStyle(Farbe.text1.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        ForEach(Betriebsbild.sollpunkte(betrieb)) { p in
            PointMark(x: .value("draußen", p.aussen), y: .value("Vorlauf", p.vorlauf))
                .foregroundStyle(Farbe.waermepumpe)
                .symbol(.circle)
                .symbolSize(50)
        }
    }

    /// Nur die Reihen, die es gibt (`betrieb.ts:187`) - eine Legende, die eine Reihe nennt, die
    /// nicht im Bild ist, lässt einen danach suchen.
    private var legende: some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 6) {
            ForEach(Betriebsbild.heizkurvenreihen(betrieb), id: \.self) { wort in
                Betriebsmasse.legendenpunkt(
                    wort: wort, farbe: legendenfarbe(wort), raute: wort == "erreicht")
            }
        }
    }

    private func legendenfarbe(_ wort: String) -> Color {
        switch wort {
        case "erreicht": return Farbe.diagrammSpeicher
        case "Gerade": return Farbe.text1.opacity(0.85)
        default: return Farbe.waermepumpe
        }
    }

    @AxisContentBuilder private var gradachse: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: Betriebsmasse.schritte(schmal: schmal))) {
            wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 0))
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    @AxisContentBuilder private var vorlaufachse: some AxisContent {
        AxisMarks(
            position: .leading,
            values: .automatic(desiredCount: Betriebsmasse.schritte(schmal: schmal))
        ) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 0))
                        .font(Betriebsmasse.achsenschrift(schmal: schmal))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}
