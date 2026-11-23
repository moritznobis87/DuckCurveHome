import Charts
import DuckCurveKit
import SwiftUI

/// Der Speicher über einen Tag: oben der Ladezustand, unten die Leistung.
///
/// **Zwei Flächen und nicht zwei Achsen - und das ist die Entscheidung dieses Bildes.** Die
/// Vorlage hat sie am 10.11.2026 für drei Diagramme zugleich getroffen und ausführlich
/// begründet (`charts.ts:11-31`): *„Zwei Kurven in einem Bild liest das Auge als Zusammenhang
/// ihrer Kreuzungspunkte, und wo sie sich kreuzen, entscheidet allein die Skalierung.“* Prozent
/// und Kilowatt kreuzen sich hier nur, weil jemand eine Achse gewählt hat.
///
/// **Darum auch nicht wie ``Pruefkurvenbild``.** Dort liegt der Ladestand auf der
/// Kilowattachse, umgerechnet, mit zurückgerechneter Beschriftung rechts - das ist das richtige
/// Verfahren für eine Prüfansicht, in der sechs Reihen *zusammen* gelesen werden. Hier werden
/// zwei Reihen *nacheinander* gelesen, und dafür ist die Trennung der Flächen die Antwort.
///
/// **Die Höhen stehen in Punkten und nicht in Anteilen** (`charts.ts:24-27`): die untere Fläche
/// ist fest 60 Punkte hoch, der Abstand fest 34. *„In Prozent schrumpfte die untere Fläche in
/// einer flachen Karte auf 23 Pixel, und der Achsenname der unteren lag auf der untersten Zahl
/// der oberen.“* Was die Karte an Höhe gewinnt, geht an die obere Fläche.
struct Speichertagbild: View {
    let kurve: Speichertagkurve
    /// Die obere Fläche. Die Vorlage gibt ihr, was von 340 Punkten Karte übrig bleibt.
    var hoeheOben: CGFloat = 150

    /// Die untere Fläche, fest (`charts.ts:32`).
    private let hoeheUnten: CGFloat = 60
    /// Der Abstand zwischen beiden, fest (`charts.ts:31`).
    private let abstandFlaechen: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ladestandsflaeche
            Spacer(minLength: 0).frame(height: abstandFlaechen - 8)
            leistungsflaeche
            legende
        }
    }

    // MARK: - Oben: der Ladezustand

    /// **Die Achse ist fest 0 bis 100 und die Marken stehen alle 25 Prozent.** Die Vorlage
    /// setzt `interval: 25` ausdrücklich und nimmt es auch am Telefon nicht zurück
    /// (`charts.ts:268`, `handy.ts:44-63`): ein Ladestand ist immer zwischen leer und voll zu
    /// lesen, und eine Achse, die bei 48 beginnt, macht aus einem ruhigen Tag ein Zickzack.
    private var ladestandsflaeche: some View {
        Chart {
            ForEach(kurve.ladestandProzent) { p in
                LineMark(
                    x: .value("Stunde", p.stunde), y: .value("%", p.wert),
                    series: .value("Reihe", Speichertagkurve.ladestandsname)
                )
                .foregroundStyle(Farbe.pv)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .chartXScale(domain: kurve.fenster)
        .chartYScale(domain: Speichertagkurve.ladestandsspanne)
        .chartXAxis(.hidden)
        .chartYAxis { prozentmarken }
        .chartYAxisLabel(position: .topLeading, alignment: .leading) {
            Text("%").font(Schrift.achse).foregroundStyle(Farbe.text3)
        }
        .frame(height: hoeheOben)
    }

    private var prozentmarken: some AxisContent {
        AxisMarks(position: .leading, values: Speichertagkurve.ladestandsmarken) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let p = wert.as(Double.self) {
                    Text(Formate.zahl(p, stellen: 0))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    // MARK: - Unten: die Leistung

    /// **Eine Stufenlinie mit Fläche** (`charts.ts:273`, `step: "end"`). Zwischen zwei Messungen
    /// ändert sich die Leistung eines Speichers nicht stetig; eine gerade Verbindung erfände
    /// eine Rampe, die es nicht gab.
    ///
    /// **Jede Strecke eine eigene Reihe.** Ohne Schlüssel verbindet Swift Charts alle Punkte zu
    /// einer Linie - über eine Lücke hinweg wäre das eine erfundene Messung.
    private var leistungsflaeche: some View {
        Chart {
            ForEach(Array(kurve.leistungsstrecken.enumerated()), id: \.offset) { i, strecke in
                leistungsmarken(strecke, nummer: i)
            }
        }
        .chartXScale(domain: kurve.fenster)
        .chartYScale(domain: kurve.leistungsspanne)
        .chartXAxis { stundenmarken }
        .chartYAxis { kilowattmarken }
        .chartYAxisLabel(position: .topLeading, alignment: .leading) {
            Text("kW").font(Schrift.achse).foregroundStyle(Farbe.text3)
        }
        .frame(height: hoeheUnten)
    }

    @ChartContentBuilder private func leistungsmarken(
        _ strecke: [Kurvenpunkt], nummer: Int
    ) -> some ChartContent {
        ForEach(strecke) { p in
            AreaMark(
                x: .value("Stunde", p.stunde), y: .value("kW", p.wert),
                series: .value("Reihe", "leistung-\(nummer)")
            )
            .foregroundStyle(Farbe.diagrammSpeicher.opacity(0.12))
            .interpolationMethod(.stepEnd)
        }
        ForEach(strecke) { p in
            LineMark(
                x: .value("Stunde", p.stunde), y: .value("kW", p.wert),
                series: .value("Reihe", "leistung-\(nummer)")
            )
            .foregroundStyle(Farbe.diagrammSpeicher.opacity(0.7))
            .lineStyle(StrokeStyle(lineWidth: 1))
            .interpolationMethod(.stepEnd)
        }
    }

    /// Die Zeitachse steht nur unter der unteren Fläche - sie gilt für beide
    /// (`charts.ts:264`).
    private var stundenmarken: some AxisContent {
        AxisMarks(values: .stride(by: 3)) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let stunde = wert.as(Double.self) {
                    Text(String(format: "%02d:00", Int(stunde) % 24))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    /// Drei Striche, nicht mehr: auf sechzig Punkten Höhe ist jede weitere Zahl Lärm
    /// (`charts.ts:269`: `splitNumber: 2`).
    private var kilowattmarken: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let kw = wert.as(Double.self) {
                    Text(Formate.zahl(kw, stellen: 1))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    // MARK: - Die Legende

    /// **Zwei Flächen heissen zwei Bilder, und zwei Bilder brauchen ihre Namen.** Die Vorlage
    /// setzt eine gemeinsame Legende unter beide (`charts.ts:258`); hier steht sie an
    /// derselben Stelle, damit nicht geraten werden muss, welche Linie welche ist
    /// (`ReportShell.tsx:184-191`).
    private var legende: some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 4) {
            ForEach(stuecke) { s in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(s.farbe)
                        .frame(width: 14, height: s.hoehe)
                    Text(s.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var stuecke: [Legendenstueck] {
        [
            Legendenstueck(
                wort: Speichertagkurve.ladestandsname, farbe: Farbe.pv, hoehe: 3),
            Legendenstueck(
                wort: Speichertagkurve.leistungsname,
                farbe: Farbe.diagrammSpeicher.opacity(0.7), hoehe: 2),
        ]
    }
}
