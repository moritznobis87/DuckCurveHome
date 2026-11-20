import Charts
import DuckCurveKit
import SwiftUI

/// Die Leistungen eines Tages, Minute für Minute - und zwar so, wie sie gespeichert sind.
///
/// **Warum diese Ansicht anders ist als jedes andere Diagramm der App.** Überall sonst wird
/// gerechnet, geglättet und zusammengefasst; hier nicht. Das ist die Seite, auf der man
/// nachsieht, ob die Zahlen überhaupt stimmen: eine gemeinsame Kilowattachse, die Nulllinie
/// hervorgehoben, und daneben zwei Gegenproben - der amtliche Zähler gegen den Stromwandler,
/// und der Ladestand gegen die Ladeleistung (`reports/charts.ts:562-775`).
///
/// **Der Ladestand steht auf einer zweiten Achse.** Swift Charts kennt keine zweite Y-Achse;
/// die Prozente werden darum in die Kilowattachse gerechnet (`ladestandAufLeistung`) und die
/// rechte Beschriftung über die Umkehrung gesetzt. Dasselbe Verfahren wie bei der Tageskurve,
/// und aus demselben Grund: zwei Gitter mit verschiedenen Nullpunkten übereinander waren schon
/// einmal der Fehler.
struct Pruefkurvenbild: View {
    let kurve: Pruefkurve

    /// Welcher Ausschnitt gezeigt wird. Ohne Auswahl der ganze Tag.
    @State private var ausschnitt: ClosedRange<Double>?

    private var gezeigt: Pruefkurve {
        guard let a = ausschnitt else {
            // Ohne Ausschnitt reicht jede fünfte Minute: 1440 Punkte mal sechs Reihen sind
            // achttausend Marken, und auf tausend Bildpunkten sieht man den Unterschied nicht.
            return kurve.verdichtet(schrittMin: 5)
        }
        return kurve.ausschnitt(von: a.lowerBound, bis: a.upperBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kurve.leer {
                Leer(satz: Pruefkurve.leersatz)
            } else {
                kopfzeile
                bild
                legende
            }
        }
    }

    private var kopfzeile: some View {
        HStack(spacing: 10) {
            Text(
                "Netz + Bezug, − Einspeisung · Speicher + Entladen, − Laden · Ladestand rechts "
                    + "in %"
            )
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .lineLimit(2)
            Spacer(minLength: 0)
            if ausschnitt != nil {
                Button("Ganzer Tag") { ausschnitt = nil }
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.amber)
                    .buttonStyle(.plain)
            }
        }
    }

    private var bild: some View {
        let k = gezeigt
        return Chart {
            ForEach(Pruefkurve.Reihe.allCases) { reihe in
                reihenmarken(reihe, k)
            }
            // Die Nulllinie ist hier keine Zierde: über ihr ist Bezug, unter ihr Einspeisung.
            RuleMark(y: .value("Null", 0))
                .foregroundStyle(Farbe.text1.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXScale(domain: k.fenster)
        .chartYScale(domain: k.leistungsspanne)
        .chartXSelection(range: auswahl)
        .chartXAxis {
            AxisMarks(values: .stride(by: 3)) { w in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                if let stunde = w.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%02d:00", Int(stunde) % 24))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { w in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                if let kw = w.as(Double.self) {
                    AxisValueLabel {
                        Text(Formate.zahl(kw, stellen: 0))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
            // Rechts der Ladestand in Prozent - ohne eigenes Raster, sonst lägen zwei Gitter
            // mit verschiedenen Nullpunkten übereinander.
            AxisMarks(position: .trailing, values: Pruefkurve.ladestandsmarken.map {
                k.ladestandAufLeistung($0)
            }) { w in
                if let y = w.as(Double.self) {
                    AxisValueLabel {
                        Text(Formate.zahl(k.leistungAufLadestand(y), stellen: 0))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .frame(height: 300)
    }

    /// Der gewählte Ausschnitt als Bindung - gewischt wird in Stunden.
    private var auswahl: Binding<ClosedRange<Double>?> {
        Binding(
            get: { ausschnitt },
            set: { neu in
                guard let neu, neu.upperBound - neu.lowerBound > 0.02 else { return }
                ausschnitt = neu
            }
        )
    }

    @ChartContentBuilder private func reihenmarken(
        _ reihe: Pruefkurve.Reihe, _ k: Pruefkurve
    ) -> some ChartContent {
        let punkte = k.punkte(reihe)
        let farbe = farbe(reihe)
        // **Jede Strecke eine eigene Reihe.** Ohne Schlüssel verbindet Swift Charts alle Punkte
        // zu einer Linie - und über eine Lücke hinweg erfindet sie eine Messung. Nur der
        // Zähler wird durchverbunden: er meldet alle Viertelstunde, und als Strecken wäre er
        // unsichtbar.
        let strecken: [[Kurvenpunkt]] =
            reihe.verbunden ? [punkte] : Pruefkurve.strecken(punkte)
        ForEach(Array(strecken.enumerated()), id: \.offset) { i, strecke in
            ForEach(strecke) { p in
                LineMark(
                    x: .value("Stunde", p.stunde), y: .value("kW", p.wert),
                    series: .value("Reihe", "\(reihe.rawValue)-\(i)")
                )
                .foregroundStyle(farbe)
                .lineStyle(
                    StrokeStyle(
                        lineWidth: reihe.gestrichelt ? 1.5 : 2,
                        dash: reihe.gestrichelt ? [4, 3] : []))
                .opacity(reihe.gestrichelt ? 0.85 : 1)
                .interpolationMethod(stufig(reihe) ? .stepEnd : .linear)
            }
        }
        if reihe == .pv {
            ForEach(punkte) { p in
                AreaMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert))
                    .foregroundStyle(Farbe.pv.opacity(0.18))
            }
        }
        if reihe == .netzZaehler {
            // Der Zähler misst in Sprüngen; seine Punkte sagen, wo wirklich gemessen wurde.
            ForEach(punkte) { p in
                PointMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert))
                    .foregroundStyle(farbe)
                    .symbolSize(14)
            }
        }
    }

    /// Netz und Speicher sind Stufen: zwischen zwei Minuten ändert sich nichts stetig.
    private func stufig(_ reihe: Pruefkurve.Reihe) -> Bool {
        reihe == .netz || reihe == .speicher
    }

    private func farbe(_ reihe: Pruefkurve.Reihe) -> Color {
        switch reihe {
        case .pv: return Farbe.pv
        case .haus: return Farbe.haus
        case .netz, .netzZaehler: return Farbe.diagrammNetz
        case .speicher, .ladestand: return Farbe.diagrammSpeicher
        }
    }

    private var legende: some View {
        Umbruchzeile(abstand: 16, zeilenabstand: 5) {
            ForEach(kurve.legende) { reihe in
                HStack(spacing: 5) {
                    if reihe.gestrichelt {
                        HStack(spacing: 2) {
                            ForEach(0..<2, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(farbe(reihe))
                                    .frame(width: 6, height: 3)
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(farbe(reihe))
                            .frame(width: 14, height: 3)
                    }
                    Text(reihe.name).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

/// Die Quellen: liefert gerade, was liefern soll?
///
/// **Der Punkt sagt, ob geantwortet wird - nicht, ob die Zahl stimmt.** Darum steht neben jedem
/// Punkt der Satz des Dienstes: er kennt das Alter des letzten Messwerts, die Zahl der Abfragen
/// und den Zähler dahinter. Die Oberfläche rechnet nichts nach (`reports/Sources.tsx`).
struct Quellenkarte: View {
    let zeilen: [Quellenstand.Quellenzeile]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if zeilen.isEmpty {
                Leer(satz: Quellenstand.nichtAbrufbar)
            } else {
                ForEach(zeilen) { z in
                    zeile(z)
                }
            }
        }
    }

    private func zeile(_ z: Quellenstand.Quellenzeile) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(farbe(z.ton))
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { _ in 7 }
            Text(z.name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text1)
            Text(z.satz)
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farbe.flaeche2)
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private func farbe(_ ton: Quellenstand.Ton) -> Color {
        switch ton {
        case .ok: return Farbe.amber
        case .alarm: return Farbe.alarm
        case .still: return Farbe.text3
        }
    }
}
