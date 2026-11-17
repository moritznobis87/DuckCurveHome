import Charts
import DuckCurveKit
import SwiftUI

/// Der Tagesverlauf der Wärmebilanz: was in den Puffer ging, was herauskam, was drin war.
///
/// **Flächen sind Zufuhr und addieren sich; Linien sind, was wieder herausgeht.** Die
/// Raumwärme des Ofens geht nicht durch den Puffer und steht trotzdem als Fläche: sie ist
/// Zufuhr ins Haus. Unten in einer zweiten Fläche der Pufferinhalt in kWh - daran liest man
/// ab, ob eine Zufuhr gespeichert oder sofort verbraucht wurde.
///
/// **Lücken werden nicht überbrückt.** Eine Minute ohne Messung ist keine Null: eine Null
/// hieße, es sei nichts gelaufen. Die Vorlage setzt dafür `connectNulls: false`.
struct Waermeverlauf: View {
    let punkte: [HeatBalancePointOut]

    private var zeiten: [(zeit: Date, p: HeatBalancePointOut)] {
        punkte.compactMap { p in Zeit.ausIso(p.ts).map { ($0, p) } }
    }

    var body: some View {
        if zeiten.isEmpty {
            Leer(satz: "Für diesen Tag liegen keine Minutenwerte vor.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                leistung
                inhalt
                Umbruchzeile(abstand: 13, zeilenabstand: 5) {
                    ForEach(stuecke) { s in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(s.farbe)
                                .frame(width: 13, height: s.hoehe)
                            Text(s.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        }
                    }
                }
            }
        }
    }

    private var stuecke: [Legendenstueck] {
        [
            .init(wort: "Wärmepumpe", farbe: Farbe.waermepumpe, hoehe: 9),
            .init(wort: "Ofen (Wasser)", farbe: Farbe.ofen, hoehe: 9),
            .init(wort: "Ofen (Raum)", farbe: Farbe.ofen.opacity(0.55), hoehe: 9),
            .init(wort: "Entnahme", farbe: Farbe.mist, hoehe: 2),
            .init(wort: "Verlust an den Raum", farbe: Farbe.alarm, hoehe: 2),
            .init(wort: "Pufferinhalt", farbe: Farbe.puffer, hoehe: 2),
        ]
    }

    /// Oben in kW: drei Flächen übereinander, zwei Linien darüber.
    ///
    /// Gestapelt wird durch Summieren und nicht durch `stacking:` - die Summen stehen schon
    /// gerechnet da, und zwei Flächen in umgekehrter Reihenfolge gezeichnet sehen gleich aus.
    private var leistung: some View {
        Chart {
            flaeche(\.gesamt, Farbe.ofen.opacity(0.45))
            flaeche(\.ohneRaum, Farbe.ofen.opacity(0.8))
            flaeche(\.wp, Farbe.waermepumpe.opacity(0.85))
            linie(\.p.drawKw, Farbe.mist, "Entnahme")
            linie(\.p.lossKw, Farbe.alarm, "Verlust")
        }
        .chartYAxisLabel("kW", position: .leading, alignment: .center)
        .chartXAxis { stundenachse }
        .chartYAxis { werteachse }
        .frame(height: 190)
    }

    /// Unten in kWh: was im Puffer steht.
    private var inhalt: some View {
        Chart {
            ForEach(Array(zeiten.enumerated()), id: \.offset) { _, e in
                if let kwh = e.p.bufferKwh {
                    AreaMark(x: .value("Zeit", e.zeit), y: .value("kWh", kwh))
                        .foregroundStyle(Farbe.puffer.opacity(0.22))
                    LineMark(
                        x: .value("Zeit", e.zeit), y: .value("kWh", kwh),
                        series: .value("Reihe", "puffer")
                    )
                    .foregroundStyle(Farbe.puffer)
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
                }
            }
        }
        .chartYAxisLabel("kWh", position: .leading, alignment: .center)
        .chartXAxis { stundenachse }
        .chartYAxis { werteachse }
        .frame(height: 90)
    }

    @ChartContentBuilder
    private func flaeche(_ wert: KeyPath<Stapel, Double?>, _ farbe: Color) -> some ChartContent {
        ForEach(stapel) { s in
            if let kw = s[keyPath: wert] {
                AreaMark(x: .value("Zeit", s.zeit), y: .value("kW", kw))
                    .foregroundStyle(farbe)
            }
        }
    }

    @ChartContentBuilder
    private func linie(
        _ wert: KeyPath<Eintrag, Double?>, _ farbe: Color, _ name: String
    ) -> some ChartContent {
        ForEach(eintraege) { e in
            if let kw = e[keyPath: wert] {
                LineMark(
                    x: .value("Zeit", e.zeit), y: .value("kW", kw),
                    series: .value("Reihe", name)
                )
                .foregroundStyle(farbe)
                .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
        }
    }

    struct Eintrag: Identifiable {
        let zeit: Date
        let p: HeatBalancePointOut
        var id: Date { zeit }
    }

    /// Die drei Zufuhren, schon aufsummiert: Wärmepumpe, dazu Ofen ins Wasser, dazu Ofen in
    /// den Raum.
    struct Stapel: Identifiable {
        let zeit: Date
        let wp: Double?
        let ohneRaum: Double?
        let gesamt: Double?
        var id: Date { zeit }
    }

    private var eintraege: [Eintrag] {
        zeiten.map { Eintrag(zeit: $0.zeit, p: $0.p) }
    }

    private var stapel: [Stapel] {
        zeiten.map { z in
            let wp = z.p.heatPumpKw
            let wasser = z.p.stoveWaterKw
            let raum = z.p.stoveRoomKw
            // Eine Lücke bleibt eine Lücke: wo keine der drei Größen gemessen ist, steht nichts.
            let alle = [wp, wasser, raum].compactMap { $0 }
            guard !alle.isEmpty else {
                return Stapel(zeit: z.zeit, wp: nil, ohneRaum: nil, gesamt: nil)
            }
            let a = wp ?? 0
            let b = a + (wasser ?? 0)
            return Stapel(zeit: z.zeit, wp: a, ohneRaum: b, gesamt: b + (raum ?? 0))
        }
    }

    private var stundenachse: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: 4)) { w in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let t = w.as(Date.self) {
                    Text(Formate.hhmm(t)).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private var werteachse: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
        }
    }
}

/// Der Puffer über den Tag: vier Schichttemperaturen, die Leistung der Wärmepumpe, und die
/// Brennphasen des Ofens als hinterlegte Bänder.
///
/// **Die Bänder sind der Zweck.** Steigt eine Temperatur innerhalb eines Bandes, war es der
/// Ofen und nicht die Wärmepumpe. Ohne sie musste man das aus der Abwesenheit der
/// Pumpenleistung erschließen - eine Schlussfolgerung, die ein Bild einem abnehmen sollte.
///
/// **Die Temperaturachse steht fest auf 20 bis 70 °C.** Nicht gestaucht: ein Puffer, dessen
/// Schichten an einem lauen Tag zwischen 38 und 42 °C liegen, sähe gestaucht wie ein Tag mit
/// voller Beladung aus. Die absolute Lage ist hier die Aussage.
struct Pufferbild: View {
    let reihe: [Waermeuebersicht.Pufferpunkt]

    private var phasen: [(von: Date, bis: Date)] { Waermeuebersicht.brennphasen(reihe) }

    var body: some View {
        if reihe.isEmpty {
            Leer(satz: "Für diesen Tag liegen keine Puffertemperaturen vor.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                temperaturen
                leistung
                Umbruchzeile(abstand: 13, zeilenabstand: 5) {
                    ForEach(stuecke) { s in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(s.farbe)
                                .frame(width: 13, height: s.hoehe)
                            Text(s.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        }
                    }
                }
            }
        }
    }

    private var stuecke: [Legendenstueck] {
        var s = Waermeuebersicht.schichtnamen.enumerated().map { i, n in
            Legendenstueck(wort: n, farbe: Farbe.pufferschicht(i), hoehe: 2)
        }
        s.append(.init(wort: "Wärmepumpe", farbe: Farbe.waermepumpe, hoehe: 9))
        if !phasen.isEmpty {
            s.append(.init(wort: "Ofen brennt", farbe: Farbe.ofen.opacity(0.2), hoehe: 9))
        }
        return s
    }

    private var temperaturen: some View {
        Chart {
            brennbaender(von: 20, bis: 70)
            ForEach(Array(Waermeuebersicht.schichtnamen.enumerated()), id: \.offset) { i, name in
                ForEach(reihe) { p in
                    if let grad = p.schichten[i] {
                        LineMark(
                            x: .value("Zeit", p.zeit), y: .value("°C", grad),
                            series: .value("Schicht", name)
                        )
                        .foregroundStyle(Farbe.pufferschicht(i))
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                    }
                }
            }
        }
        .chartYScale(domain: 20...70)
        .chartYAxisLabel("°C", position: .leading, alignment: .center)
        .chartXAxis { stundenachse }
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: 20.0, through: 70, by: 10))) {
                _ in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
        }
        .frame(height: 170)
    }

    private var leistung: some View {
        Chart {
            brennbaender(von: 0, bis: hoechsteLeistung)
            ForEach(reihe) { p in
                if let kw = p.wpKw {
                    AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                        .foregroundStyle(Farbe.waermepumpe.opacity(0.18))
                        .interpolationMethod(.stepEnd)
                    LineMark(
                        x: .value("Zeit", p.zeit), y: .value("kW", kw),
                        series: .value("Reihe", "wp")
                    )
                    .foregroundStyle(Farbe.waermepumpe)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.stepEnd)
                }
            }
        }
        .chartYScale(domain: 0...hoechsteLeistung)
        .chartYAxisLabel("kW", position: .leading, alignment: .center)
        .chartXAxis { stundenachse }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { _ in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
        }
        .frame(height: 80)
    }

    private var hoechsteLeistung: Double {
        max(1, reihe.compactMap(\.wpKw).max() ?? 1)
    }

    @ChartContentBuilder
    private func brennbaender(von: Double, bis: Double) -> some ChartContent {
        ForEach(Array(phasen.enumerated()), id: \.offset) { _, p in
            RectangleMark(
                xStart: .value("von", p.von), xEnd: .value("bis", p.bis),
                yStart: .value("u", von), yEnd: .value("o", bis)
            )
            .foregroundStyle(Farbe.ofen.opacity(0.2))
        }
    }

    private var stundenachse: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: 4)) { w in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let t = w.as(Date.self) {
                    Text(Formate.hhmm(t)).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}
