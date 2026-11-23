import Charts
import DuckCurveKit
import SwiftUI

/// Der Tagesverlauf der Wärmebilanz: was in den Puffer ging, was herauskam, was drin war.
///
/// **Flächen für die Erzeuger, Linien für die Senken.** Gestapelt wird nur, was sich wirklich
/// addiert: Wärmepumpe und Ofenwasser gehen beide in denselben Puffer, ihre Summe ist die
/// Zufuhr. Entnahme und Verlust gehen aus ihm heraus und stehen als eigene Linien daneben,
/// nicht als weitere Schicht desselben Stapels - sonst läse man eine Summe, die es nicht gibt
/// (`reports/charts.ts:781-784`).
///
/// **Die Raumwärme des Ofens stand hier als dritte Fläche, und das war falsch.** Sie geht nicht
/// in den Puffer; die Vorlage lässt sie deshalb gestrichelt neben dem Stapel laufen, in
/// derselben Farbe, und sagt es im Kommentar eigens (`charts.ts:878-879`). Als Fläche
/// mitgestapelt zeigte das Bild über dem Puffer eine Zufuhr, die nie in ihm war - und mit ihr
/// galt auch die Farbprüfung der Vorlage nicht mehr (`charts.ts:788-790`). Der Stapel wird
/// darum nicht mehr hier gerechnet, sondern in ``Waermeuebersicht/verlaufsstapel(_:)``, wo ein
/// Test ihn hält.
///
/// **Lücken werden nicht überbrückt.** Eine Minute ohne Messung ist keine Null: eine Null
/// hieße, es sei nichts gelaufen. Die Vorlage setzt dafür `connectNulls: false` - nur der
/// Pufferinhalt wird durchgezogen (`charts.ts:883`). Swift Charts kennt das nicht und verbindet
/// jede Reihe durch; die Reihen werden darum vor dem Zeichnen in Abschnitte geschnitten
/// (``Waermeuebersicht/verlaufsabschnitte(_:_:)``), und jeder Abschnitt ist im Bild eine eigene
/// Reihe.
///
/// **Zwei Dinge der Vorlage fehlen mit Absicht.** Zoom und Schieberegler (`charts.ts:857-860`)
/// hat Swift Charts nicht als fertiges Stück; statt des Hinweiskastens liest der Finger den Tag
/// ab, und das Ergebnis steht über dem Bild (`chartXSelection`, wie in
/// ``Diagramme/Betriebskurven.swift``). Und die Reihen lassen sich nicht einzeln abschalten
/// (`charts.ts:833`): kein Vorbild im Projekt tut das, und acht Flächen hat der Fahrplan auch
/// ohne gelöst. Was bleibt, ist die unterschiedliche Breite der beiden y-Achsen - die Vorlage
/// löst das mit `outerBoundsMode: "none"` (`charts.ts:29-30`), SwiftUI gibt dafür nichts her.
struct Waermeverlauf: View {
    let punkte: [HeatBalancePointOut]

    @State private var gelesen: Date?

    private var stapel: [Waermeuebersicht.Verlaufspunkt] {
        Waermeuebersicht.verlaufsstapel(punkte)
    }

    var body: some View {
        let s = stapel
        if s.isEmpty {
            Leer(satz: "Für diesen Tag liegen keine Minutenwerte vor.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                auskunft(s)
                leistung(s)
                inhalt(s)
                Verlaufslegende(reihen: Waermeuebersicht.verlaufsreihen)
            }
        }
    }

    // MARK: - Was unter dem Finger steht

    /// Die Auskunftszeile an der Stelle des Fingers - statt des Hinweiskastens der Vorlage
    /// (`charts.ts:813-826`, Einheit kWh nur beim Pufferinhalt).
    @ViewBuilder private func auskunft(_ s: [Waermeuebersicht.Verlaufspunkt]) -> some View {
        let a: Waermeuebersicht.Verlaufsablesung? = Waermeuebersicht.verlaufsablesung(
            s, zu: gelesen)
        Umbruchzeile(abstand: 12, zeilenabstand: 4) {
            if let a {
                Text(a.uhrzeit).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                ForEach(a.werte) { w in
                    wertstueck(w)
                }
            } else {
                Text("Auf dem Bild halten liest den Tag ab.")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    private func wertstueck(_ w: Kennzahl) -> some View {
        HStack(spacing: 4) {
            Text(w.wort).font(Schrift.winzig).foregroundStyle(reihenfarbe(w.wort))
            Text("\(w.wert) \(w.einheit ?? "")")
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text1)
        }
    }

    private func reihenfarbe(_ wort: String) -> Color {
        guard let r = Waermeuebersicht.verlaufsreihen.first(where: { $0.wort == wort }) else {
            return Farbe.text3
        }
        return Color(r.farbe)
    }

    // MARK: - Oben: Kilowatt

    /// Zwei Bänder übereinander, drei Linien darüber.
    ///
    /// **Bänder und keine übereinandergelegten Flächen.** Zwei halbdurchsichtige Flächen, von
    /// denen die eine unter der anderen hindurchläuft, geben im Überlappungsbereich eine dritte
    /// Farbe - die Vorlage stapelt und zeigt je Schicht genau ihre eigene Deckung (0,24 und
    /// 0,28, `charts.ts:876-877`). Ein `AreaMark` von Kante zu Kante tut dasselbe. Über jeder
    /// Kante liegt eine 1-pt-Linie in der Vollfarbe (`charts.ts:796-807`).
    private func leistung(_ s: [Waermeuebersicht.Verlaufspunkt]) -> some View {
        Chart {
            band(s, Waermeuebersicht.reiheOfenWasser, von: \.stapelWp, bis: \.stapelZufuhr)
            band(s, Waermeuebersicht.reiheWaermepumpe, von: nil, bis: \.stapelWp)
            kante(s, Waermeuebersicht.reiheOfenWasser, \.stapelZufuhr)
            kante(s, Waermeuebersicht.reiheWaermepumpe, \.stapelWp)
            kurve(s, Waermeuebersicht.reiheOfenRaum, \.raumKw)
            kurve(s, Waermeuebersicht.reiheEntnahme, \.entnahmeKw)
            kurve(s, Waermeuebersicht.reiheVerlust, \.verlustKw)
        }
        .chartYAxisLabel("kW", position: .leading, alignment: .center)
        .chartXSelection(value: $gelesen)
        .chartXAxis { stundenachse }
        .chartYAxis { werteachse(stufen: 4) }
        .frame(height: 300)
    }

    // MARK: - Unten: Kilowattstunden

    /// Was im Puffer steht - eigene Fläche, eigene Achse (`charts.ts:883`).
    private func inhalt(_ s: [Waermeuebersicht.Verlaufspunkt]) -> some View {
        let r = Waermeuebersicht.reihePufferinhalt
        return Chart {
            ForEach(s) { p in
                if let kwh = p.pufferKwh {
                    AreaMark(x: .value("Zeit", p.zeit), y: .value("kWh", kwh))
                        .foregroundStyle(Color(r.farbe).opacity(r.flaechendeckung ?? 0.14))
                    LineMark(
                        x: .value("Zeit", p.zeit), y: .value("kWh", kwh),
                        series: .value("Reihe", r.wort)
                    )
                    .foregroundStyle(Color(r.farbe))
                    .lineStyle(StrokeStyle(lineWidth: r.strich))
                }
            }
        }
        .chartYAxisLabel("kWh", position: .leading, alignment: .center)
        .chartXSelection(value: $gelesen)
        .chartXAxis { stundenachse }
        .chartYAxis { werteachse(stufen: 2) }
        .frame(height: 90)
    }

    // MARK: - Die Stücke des Bildes

    /// Eine Schicht des Stapels, von Kante zu Kante. `von: nil` heißt: ab der Grundlinie.
    ///
    /// Geschnitten in Abschnitte, weil Swift Charts sonst durch jede Lücke hindurchzeichnet -
    /// Begründung an ``Waermeuebersicht/verlaufsabschnitte(_:_:)``.
    @ChartContentBuilder
    private func band(
        _ s: [Waermeuebersicht.Verlaufspunkt], _ r: Waermeuebersicht.Verlaufsreihe,
        von unten: KeyPath<Waermeuebersicht.Verlaufspunkt, Double?>?,
        bis oben: KeyPath<Waermeuebersicht.Verlaufspunkt, Double?>
    ) -> some ChartContent {
        ForEach(abschnitte(s, oben), id: \.nummer) { teil in
            ForEach(teil.punkte) { p in
                AreaMark(
                    x: .value("Zeit", p.zeit),
                    yStart: .value("kW", unten.flatMap { p[keyPath: $0] } ?? 0),
                    yEnd: .value("kW", p[keyPath: oben] ?? 0),
                    series: .value("Reihe", "flaeche-\(r.wort)-\(teil.nummer)")
                )
                .foregroundStyle(Color(r.farbe).opacity(r.flaechendeckung ?? 0.24))
            }
        }
    }

    /// Die Linie in der Vollfarbe über einer Kante des Stapels.
    @ChartContentBuilder
    private func kante(
        _ s: [Waermeuebersicht.Verlaufspunkt], _ r: Waermeuebersicht.Verlaufsreihe,
        _ wert: KeyPath<Waermeuebersicht.Verlaufspunkt, Double?>
    ) -> some ChartContent {
        ForEach(abschnitte(s, wert), id: \.nummer) { teil in
            ForEach(teil.punkte) { p in
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", p[keyPath: wert] ?? 0),
                    series: .value("Reihe", "kante-\(r.wort)-\(teil.nummer)")
                )
                .foregroundStyle(Color(r.farbe))
                .lineStyle(StrokeStyle(lineWidth: r.strich))
            }
        }
    }

    /// Eine Senke als Linie - gestrichelt, wo sie nicht durch den Puffer geht.
    @ChartContentBuilder
    private func kurve(
        _ s: [Waermeuebersicht.Verlaufspunkt], _ r: Waermeuebersicht.Verlaufsreihe,
        _ wert: KeyPath<Waermeuebersicht.Verlaufspunkt, Double?>
    ) -> some ChartContent {
        ForEach(abschnitte(s, wert), id: \.nummer) { teil in
            ForEach(teil.punkte) { p in
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", p[keyPath: wert] ?? 0),
                    series: .value("Reihe", "\(r.wort)-\(teil.nummer)")
                )
                .foregroundStyle(Color(r.farbe))
                .lineStyle(Waermebildstriche.strich(r))
                .opacity(r.gestalt == .gestrichelt ? 0.9 : 1)
            }
        }
    }

    /// Ein Abschnitt mit seiner Nummer - die Nummer wird der Reihenschlüssel im Bild.
    private struct Abschnitt: Identifiable {
        let nummer: Int
        let punkte: [Waermeuebersicht.Verlaufspunkt]
        var id: Int { nummer }
    }

    private func abschnitte(
        _ s: [Waermeuebersicht.Verlaufspunkt],
        _ wert: KeyPath<Waermeuebersicht.Verlaufspunkt, Double?>
    ) -> [Abschnitt] {
        Waermeuebersicht.verlaufsabschnitte(s, wert).enumerated().map {
            Abschnitt(nummer: $0.offset, punkte: $0.element)
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

    private func werteachse(stufen: Int) -> some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: stufen)) { _ in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
        }
    }
}

/// Der Strich einer Reihe des Wärmebildes.
///
/// Eigener Platz, weil ihn Bild und Legende brauchen und ein Strichmuster, das an zwei Stellen
/// verschieden gesetzt wird, an einer von beiden irgendwann anders aussieht.
enum Waermebildstriche {
    /// `dashed` der Vorlage: `[4, 4]` liest sich auf einem Retina-Schirm wie das Muster von
    /// ECharts, und die Strichstärke kommt aus dem Kern (`charts.ts:878-882`).
    static func strich(_ r: Waermeuebersicht.Verlaufsreihe) -> StrokeStyle {
        StrokeStyle(
            lineWidth: r.strich,
            dash: r.gestalt == .gestrichelt ? [4, 4] : [])
    }
}

/// Die Legende des Wärmebildes - mit gestrichelten Zeichen für die gestrichelten Reihen.
///
/// **Das Zeichen muss die Gestalt tragen und nicht nur die Farbe.** „Ofen (Wasser)“ und „Ofen
/// (Raum)“ haben dieselbe Farbe, weil es dasselbe Gerät ist; ohne gestricheltes Zeichen stehen
/// in der Legende zwei gleiche Kästchen mit verschiedenen Wörtern. Die Vorlage gibt genau diesen
/// zwei Einträgen ein eigenes Zeichen aus zwei Balken (`charts.ts:844, 846`:
/// `M0,0 H6 V3 H0 Z M10,0 H16 V3 H10 Z`).
struct Verlaufslegende: View {
    let reihen: [Waermeuebersicht.Verlaufsreihe]

    var body: some View {
        Umbruchzeile(abstand: 13, zeilenabstand: 5) {
            ForEach(reihen) { r in
                HStack(spacing: 5) {
                    zeichen(r)
                    Text(r.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    @ViewBuilder private func zeichen(_ r: Waermeuebersicht.Verlaufsreihe) -> some View {
        let farbe: Color = Color(r.farbe)
        switch r.gestalt {
        case .flaeche:
            ZStack(alignment: .top) {
                Rectangle().fill(farbe.opacity(r.flaechendeckung ?? 0.24))
                Rectangle().fill(farbe).frame(height: 1.5)
            }
            .frame(width: 16, height: 9)
            .clipShape(RoundedRectangle(cornerRadius: 1.5))
        case .linie:
            Rectangle().fill(farbe).frame(width: 16, height: 2)
        case .gestrichelt:
            HStack(spacing: 4) {
                Rectangle().fill(farbe).frame(width: 6, height: 2)
                Rectangle().fill(farbe).frame(width: 6, height: 2)
            }
            .frame(width: 16, height: 2)
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
        // 200 statt 170: die Karte der Vorlage ist 360 px hoch (`HeatOverview.tsx:198`), und
        // davon gehen Kopfzeile, Polster und Legende ab.
        .frame(height: 200)
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
        .frame(height: 90)
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
