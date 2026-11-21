import Charts
import DuckCurveKit
import SwiftUI

/// Heute und morgen: die gemessene PV-Leistung gegen die erwartete, auf einer Zeitachse über
/// achtundvierzig Stunden.
///
/// **Das ist der Teil der Seite, der ihren Namen einlöst.** Der Reiter heißt „Erzeugung ·
/// Verwendung · Prognose“ (`PvReport.tsx:77`); ohne diese Karte ist die Seite eine Rückschau.
///
/// **Zwei Tage auf einer Achse, mit einer beschrifteten Trennlinie.** Die Vorlage setzt dafür
/// eine `markLine` mit `position: "insideEndTop"` (`charts.ts:219`); Swift Charts hat nichts
/// Entsprechendes, und der Weg des Projekts ist `RuleMark` plus `.annotation`
/// (`Wirkungszeichnung.swift:243-258`). Am Tagesanfang steht das Datum statt der Stunde, wie im
/// Fahrplanbild - „zwei Zwölfen ohne Tag sind nicht zu trennen“
/// (`Fahrplanzeichnung.swift:158-159`).
///
/// **Was gestrichelt ist, ist nicht gemessen** (`Tageskurve.swift:16-17`): die Prognose ist eine
/// dünne gestrichelte Linie mit blasser Fläche, das Ist eine dicke in der Farbe der Sonne mit
/// einem Verlauf darunter. Die Lücken des Ist bleiben Lücken - jeder Abschnitt ist eine eigene
/// Reihe, weil eine Linie über ein Loch hinweg eine Messung behauptet, die es nicht gibt.
struct Pvtageskurve: View {
    let bild: Pvbild.Zweitagebild
    let jetzt: Date
    var hoehe: CGFloat = 240

    @State private var gelesen: Date?

    var body: some View {
        if bild.leer {
            Leer(
                satz: "Keine Vorschau da.",
                dazu: "Weder Minutenwerte noch ein Plan für diesen Tag."
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ablesezeile
                kurve
                Diagrammlegende(stuecke: Self.legende)
            }
        }
    }

    static var legende: [Legendenstueck] {
        [
            Legendenstueck(wort: "Prognose", farbe: Farbe.diagrammHaushalt, hoehe: 2),
            Legendenstueck(wort: "Ist", farbe: Farbe.pv, hoehe: 3),
        ]
    }

    /// Was unter dem Finger steht: „Di., 14:30“ und je Reihe der Wert in kW
    /// (`charts.ts:184-195`).
    private var ablesezeile: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let g = gelesen {
                Text("\(Tag.kurz(Tag.iso(g))) \(Formate.hhmm(g))")
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text2)
                Spacer(minLength: 6)
                wertzeile("Ist", wert: naechster(bild.ist.flatMap(\.punkte), zu: g))
                wertzeile("Prognose", wert: naechster(bild.prognose, zu: g))
            } else {
                Text("Zum Ablesen über das Bild streichen.")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 16, alignment: .topLeading)
    }

    @ViewBuilder private func wertzeile(_ wort: String, wert: Double?) -> some View {
        if let wert {
            HStack(spacing: 4) {
                Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                Text(Formate.kwMitEinheit(wert))
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text1)
            }
        }
    }

    /// Der Stützpunkt, der der gelesenen Stelle am nächsten liegt - höchstens eine halbe
    /// Stunde entfernt.
    ///
    /// **Die Grenze ist nicht Zierde.** Die Prognose steht in Viertelstunden, das Ist in
    /// Minuten; ohne Grenze zeigte die Ablesung in einer Lücke der Istkurve den Wert von
    /// vorhin und behauptete damit eine Messung, die an dieser Stelle fehlt.
    private func naechster(_ punkte: [Pvbild.Punkt], zu stelle: Date) -> Double? {
        var beste: Pvbild.Punkt?
        var abstand = Double.greatestFiniteMagnitude
        for p in punkte {
            let d = abs(p.zeit.timeIntervalSince(stelle))
            if d < abstand {
                abstand = d
                beste = p
            }
        }
        guard abstand <= 1800 else { return nil }
        return beste?.kw
    }

    private var kurve: some View {
        Chart {
            inhalt
        }
        .chartXScale(domain: bild.beginn...bild.ende)
        .chartYScale(domain: 0...obergrenze)
        .chartLegend(.hidden)
        .chartXSelection(value: $gelesen)
        .chartXAxis { xAchse }
        .chartYAxis { yAchse }
        .frame(height: hoehe)
    }

    /// Die Höhe der Wertachse. `min: 0` wie in der Vorlage (`charts.ts:208`), und oben etwas
    /// Luft, damit die Spitze die Beschriftung der Trennlinie nicht berührt.
    private var obergrenze: Double {
        max(1, bild.hoechstwert * 1.15)
    }

    @ChartContentBuilder private var inhalt: some ChartContent {
        prognosereihe
        istreihe
        trennlinie
        jetztlinie
        if let g = gelesen {
            RuleMark(x: .value("gelesen", g))
                .foregroundStyle(Farbe.text1.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }

    @ChartContentBuilder private var prognosereihe: some ChartContent {
        ForEach(bild.prognose) { p in
            AreaMark(
                x: .value("Zeit", p.zeit), y: .value("kW", p.kw),
                series: .value("Reihe", "prognoseFlaeche")
            )
            .foregroundStyle(Farbe.diagrammHaushalt.opacity(0.06))
            LineMark(
                x: .value("Zeit", p.zeit), y: .value("kW", p.kw),
                series: .value("Reihe", "prognose")
            )
            .foregroundStyle(Farbe.diagrammHaushalt)
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
    }

    /// Je Abschnitt eine eigene Reihe: so bleibt eine Lücke eine Lücke.
    @ChartContentBuilder private var istreihe: some ChartContent {
        ForEach(bild.ist) { a in
            ForEach(a.punkte) { p in
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", p.kw),
                    series: .value("Reihe", "istFlaeche\(a.nummer)")
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Farbe.pv.opacity(0.3), Farbe.pv.opacity(0.03)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", p.kw),
                    series: .value("Reihe", "ist\(a.nummer)")
                )
                .foregroundStyle(Farbe.pv)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
        }
    }

    /// Die Grenze zwischen heute und morgen, beschriftet.
    @ChartContentBuilder private var trennlinie: some ChartContent {
        RuleMark(x: .value("morgen", bild.tagesende))
            .foregroundStyle(Farbe.text1.opacity(0.25))
            .lineStyle(StrokeStyle(lineWidth: 1))
            .annotation(position: .top, alignment: .leading, spacing: 2) {
                Text("morgen").font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
    }

    /// Die Jetzt-Linie, ohne Beschriftung (`charts.ts:229`: `label: { show: false }`).
    ///
    /// Sie steht nur da, wenn „jetzt“ überhaupt im Bild liegt - blättert man auf einen
    /// vergangenen Tag, bleibt die Vorschau die von heute, und dann liegt sie es immer; an
    /// einem Gerät mit falscher Uhr nicht.
    @ChartContentBuilder private var jetztlinie: some ChartContent {
        if jetzt >= bild.beginn, jetzt <= bild.ende {
            RuleMark(x: .value("jetzt", jetzt))
                .foregroundStyle(Farbe.pv)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
    }

    /// Alle sechs Stunden eine Marke, wie `interval: 6 h` der Vorlage - das bleibt auch am
    /// Telefon so (`handy.ts:16,37`: ein festes Raster wird nicht angetastet).
    @AxisContentBuilder private var xAchse: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: 6)) { w in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            if let t = w.as(Date.self) {
                AxisValueLabel {
                    Text(istTagesanfang(t) ? Tag.kurz(Tag.iso(t)) : Formate.hhmm(t))
                        .font(Schrift.achse)
                        .foregroundStyle(istTagesanfang(t) ? Farbe.text2 : Farbe.text3)
                }
            }
        }
    }

    @AxisContentBuilder private var yAchse: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
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

    private func istTagesanfang(_ t: Date) -> Bool {
        Kalender.haus.component(.hour, from: t) == 0
    }
}
