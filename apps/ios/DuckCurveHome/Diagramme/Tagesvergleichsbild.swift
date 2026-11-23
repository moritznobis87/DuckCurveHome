import Charts
import DuckCurveKit
import SwiftUI

/// Der Tagesvergleich: wann jede Linie Strom zog, und wo dabei das Geld auseinanderlief.
///
/// Drei Teile auf einer Zeitachse. **Oben die Umstände:** der eingetretene Preis und der
/// Überschuss. **In der Mitte je Linie ein Streifen:** hell, wo sie Strom zieht, heller, je mehr.
/// Die Streifen stehen untereinander, damit der Blick senkrecht vergleichen kann - „geplant war
/// der Mittag, gelaufen ist der Morgen, und das sieht man, bevor man eine Zahl liest“
/// (`Tagesvergleich.tsx:17-20`). **Unten die aufgelaufenen Kosten:** dieselben Linien als
/// Kurven. Wo zwei Kurven sich trennen, ist die Viertelstunde, in der es teuer wurde, und der
/// Streifen darüber sagt, warum.
///
/// **Jede Größe in ihrer eigenen Fläche** (`Tagesvergleich.tsx:22-23`): „Cent, Kilowatt und Euro
/// in einem Gitter läsen sich als Zusammenhang ihrer Kreuzungspunkte.“ ECharts setzt dafür sechs
/// bis acht `grid` in ein Bild; Swift Charts kennt das nicht, und der im Projekt gewählte Weg
/// sind mehrere `Chart` untereinander mit **derselben** `chartXScale` und derselben
/// `chartXSelection` - `Diagramme/Fahrplanzeichnung.swift:120-180` und
/// `Diagramme/Tagesbandbild.swift:17-22` („sonst fallen sie auseinander“).
///
/// **Die Farben** sind die der Kostentreppe, und sie sind gemessen: „Ein Grün für die perfekte
/// Voraussicht fiel durch - gegen das Orange der Wirklichkeit ΔE 0,8 bei Deuteranopie, also
/// dieselbe Farbe. Deshalb drei Farben für vier Linien: der erste Fahrplan gestrichelt, der
/// letzte Stand durchgezogen“ (`Tagesvergleich.tsx:28-31`). Die Zuordnung steht im Kern an
/// ``Nachbetrachtungsbild/strichart(key:)``.
struct Tagesvergleichsbild: View {
    let daten: NachbetrachtungOut

    /// Wo der Finger auf der Zeitachse steht. Alle Flächen teilen diese Auswahl.
    @State private var gewaehlt: Date?

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    /// Die Breite der Flächennamen links. In der Vorlage sind es 136 Punkte bis zum Gitter, am
    /// Telefon 84 (`Tagesvergleich.tsx:35`).
    private var namensbreite: CGFloat { schmal ? 84 : 120 }

    var body: some View {
        if let gitter = Nachbetrachtungsbild.gitter(daten) {
            let flaechen = Nachbetrachtungsbild.flaechen(daten, schmal: schmal)
            VStack(alignment: .leading, spacing: 0) {
                auskunft(gitter)
                ForEach(Array(flaechen.enumerated()), id: \.element.id) { i, f in
                    zeile(f, gitter: gitter, letzte: i == flaechen.count - 1)
                }
                legende
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Die Auskunft zur berührten Viertelstunde

    /// **Ein Block über der Zeichnung und kein Fenster unter dem Zeiger.** Die Begründung steht
    /// im Kern an ``Nachbetrachtungsbild/auskunft(_:gitter:zeit:)``; dasselbe tun die Auskunft
    /// des Fahrplans und die Fahne des Tagesbands.
    @ViewBuilder private func auskunft(_ gitter: Nachbetrachtungsbild.Zeitgitter) -> some View {
        if let zeit = gewaehlt,
            let a = Nachbetrachtungsbild.auskunft(daten, gitter: gitter, zeit: zeit)
        {
            VStack(alignment: .leading, spacing: 3) {
                Text(a.kopf).font(Schrift.zahlKlein).foregroundStyle(Farbe.amberWeich)
                Text(a.umstaende).font(Schrift.winzig).foregroundStyle(Farbe.text2)
                if let satz = a.nichtVerglichen {
                    Text(satz).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                ForEach(a.zeilen) { z in
                    auskunftszeile(z)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.bottom, 10)
        } else {
            Text("Zum Lesen einer Viertelstunde die Zeichnung berühren.")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .padding(.bottom, 6)
        }
    }

    private func auskunftszeile(_ z: Nachbetrachtungsbild.Auskunftszeile) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            strichmarke(Nachbetrachtungsbild.strichart(key: z.key))
            Text(z.name).font(Schrift.winzig).foregroundStyle(Farbe.text2)
            Spacer(minLength: 6)
            Text(z.kwh).font(Schrift.mono(11)).foregroundStyle(Farbe.text3)
            Text(z.eur).font(Schrift.mono(11)).foregroundStyle(Farbe.text1)
            Text("\(Nachbetrachtungsworte.bisHier) \(z.bisHier)")
                .font(Schrift.mono(11))
                .foregroundStyle(Farbe.text3)
        }
    }

    // MARK: - Eine Fläche

    private func zeile(
        _ f: Nachbetrachtungsbild.Flaeche, gitter: Nachbetrachtungsbild.Zeitgitter, letzte: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Die Farbe gehört den Marken; farbige Schrift wäre Kennung ohne Lesbarkeit.
            Text(f.titel)
                .font(Schrift.mono(10))
                .foregroundStyle(Farbe.text3)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(width: namensbreite, alignment: .trailing)
                .padding(.top, f.art == .streifen ? 0 : 1)
            zeichnung(f, gitter: gitter, letzte: letzte)
        }
        .padding(.top, f.luftDavor)
    }

    @ViewBuilder private func zeichnung(
        _ f: Nachbetrachtungsbild.Flaeche, gitter: Nachbetrachtungsbild.Zeitgitter, letzte: Bool
    ) -> some View {
        switch f.art {
        case .preis:
            rahmen(
                gitter: gitter, hoehe: f.hoehe, spanne: Nachbetrachtungsbild.spanne(daten.preisCt),
                zahlen: true, euro: false, zeitachse: letzte
            ) {
                schleier(gitter, spanne: Nachbetrachtungsbild.spanne(daten.preisCt), mitWort: true)
                preiskurve(gitter)
            }
        case .sonne:
            rahmen(
                gitter: gitter, hoehe: f.hoehe,
                spanne: Nachbetrachtungsbild.spanne(daten.ueberschussKw), zahlen: true,
                euro: false, zeitachse: letzte
            ) {
                schleier(
                    gitter, spanne: Nachbetrachtungsbild.spanne(daten.ueberschussKw),
                    mitWort: false)
                sonnenkurve(gitter)
            }
        case .streifen:
            rahmen(
                gitter: gitter, hoehe: f.hoehe, spanne: 0...1, zahlen: false, euro: false,
                zeitachse: letzte
            ) {
                streifen(f.linie, gitter: gitter)
                schleier(gitter, spanne: 0...1, mitWort: false)
            }
        case .kosten:
            rahmen(
                gitter: gitter, hoehe: f.hoehe, spanne: kostenspanne, zahlen: true,
                euro: true, zeitachse: letzte
            ) {
                schleier(gitter, spanne: kostenspanne, mitWort: false)
                kostenkurven(gitter)
            }
        }
    }

    /// Titel, Zeichnung, gemeinsame Zeitachse - der Rahmen jeder Fläche.
    ///
    /// Die Zeitachse steht nur unter der letzten Fläche: achtmal dieselben Uhrzeiten sind
    /// siebenmal Lärm (`Tagesvergleich.tsx:123`). Die senkrechten Rasterlinien stehen in jeder,
    /// damit die Flächen übereinander lesbar bleiben.
    private func rahmen<Inhalt: ChartContent>(
        gitter: Nachbetrachtungsbild.Zeitgitter, hoehe: Double, spanne: ClosedRange<Double>,
        zahlen: Bool, euro: Bool, zeitachse: Bool,
        @ChartContentBuilder inhalt: () -> Inhalt
    ) -> some View {
        Chart {
            inhalt()
            if let g = gewaehlt {
                RuleMark(x: .value("gewählt", g))
                    .foregroundStyle(Farbe.text1.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: gitter.spanne)
        .chartYScale(domain: spanne)
        .chartXSelection(value: $gewaehlt)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: schmal ? 6 : 3)) { w in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                if zeitachse, let t = w.as(Date.self) {
                    AxisValueLabel {
                        Text(Formate.hhmm(t)).font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { wert in
                if zahlen {
                    AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                    AxisValueLabel {
                        achsenzahl(wert.as(Double.self), euro: euro)
                    }
                }
            }
        }
        .frame(height: hoehe)
    }

    /// Die Beschriftung der senkrechten Achse. „{value} €“ nur in der Kostenfläche
    /// (`Tagesvergleich.tsx:265`); Preis und Überschuss tragen ihre Einheit im Titel.
    ///
    /// **Die Marke kommt aus dem Kern** (``Nachbetrachtungsbild/achsenmarke(_:)``) und nicht aus
    /// festen zwei Stellen: die Vorlage schreibt dort „0 €“ und „2 €“, nicht „0,00 €“, und die
    /// Begründung steht beim Kern - „eine Achse aus sechs Marken wird mit festen zwei Stellen
    /// fast doppelt so breit“. Die Kostentreppe nimmt dieselbe Marke; zwei Schreibweisen für
    /// denselben Betrag auf einer Seite wären zwei zu viel.
    @ViewBuilder private func achsenzahl(_ wert: Double?, euro: Bool) -> some View {
        if let wert {
            Text(euro ? Nachbetrachtungsbild.achsenmarke(wert) : Formate.zahl(wert, stellen: 0))
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
        }
    }

    // MARK: - Der Schleier

    /// Was nicht verglichen wird, liegt unter einem Schleier - in **jeder** Fläche derselbe
    /// (`Tagesvergleich.tsx:101-116`).
    ///
    /// Es gab im Projekt nichts dafür; das nächste Vorbild sind die Preisbänder und die
    /// Reservezone als `RectangleMark` über die ganze Flächenhöhe
    /// (`Diagramme/Fahrplanzeichnung.swift:188-196`). Das Wort steht nur über dem ersten Lauf
    /// der Preisfläche: viermal dasselbe Wort über demselben Zeitraum ist dreimal zu viel.
    @ChartContentBuilder private func schleier(
        _ gitter: Nachbetrachtungsbild.Zeitgitter, spanne: ClosedRange<Double>, mitWort: Bool
    ) -> some ChartContent {
        let laeufe = Nachbetrachtungsbild.schleier(daten, gitter: gitter)
        ForEach(Array(laeufe.enumerated()), id: \.element.id) { i, l in
            RectangleMark(
                xStart: .value("von", l.von), xEnd: .value("bis", l.bis),
                yStart: .value("u", spanne.lowerBound), yEnd: .value("o", spanne.upperBound)
            )
            .foregroundStyle(Color(Marken.deep.mitDeckung(0.62)))
            .annotation(position: .topLeading, alignment: .leading, spacing: 1) {
                if mitWort, i == 0 {
                    Text(Nachbetrachtungsworte.nichtVerglichen)
                        .font(Schrift.mono(10))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    // MARK: - Die einzelnen Flächen

    /// Der eingetretene Preis als Stufenkurve: ein Preis gilt für die ganze Viertelstunde, nicht
    /// als Steigung zwischen zwei Punkten (`Tagesvergleich.tsx:269`, `step: "end"`).
    @ChartContentBuilder private func preiskurve(_ gitter: Nachbetrachtungsbild.Zeitgitter)
        -> some ChartContent
    {
        let punkte = Nachbetrachtungsbild.reihe(daten.preisCt, gitter: gitter)
        ForEach(punkte) { p in
            if let ct = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("ct", ct))
                    .foregroundStyle(Farbe.mist.opacity(0.14))
                    .interpolationMethod(.stepEnd)
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("ct", ct),
                    series: .value("Reihe", "preis")
                )
                .foregroundStyle(Farbe.mist)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
                .interpolationMethod(.stepEnd)
            }
        }
    }

    @ChartContentBuilder private func sonnenkurve(_ gitter: Nachbetrachtungsbild.Zeitgitter)
        -> some ChartContent
    {
        let punkte = Nachbetrachtungsbild.reihe(daten.ueberschussKw, gitter: gitter)
        ForEach(punkte) { p in
            if let kw = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                    .foregroundStyle(Farbe.pv.opacity(0.18))
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "sonne")
                )
                .foregroundStyle(Farbe.pv)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
            }
        }
    }

    /// Ein Streifen: je Lauf gleicher Helligkeit ein Feld, darunter der Ofenrand.
    @ChartContentBuilder private func streifen(
        _ linie: Linie?, gitter: Nachbetrachtungsbild.Zeitgitter
    ) -> some ChartContent {
        if let linie {
            ForEach(
                Nachbetrachtungsbild.streifen(
                    linie, gitter: gitter, vollKwh: Nachbetrachtungsbild.vollKwh(daten))
            ) { feld in
                RectangleMark(
                    xStart: .value("von", feld.von), xEnd: .value("bis", feld.bis),
                    yStart: .value("u", 0.0), yEnd: .value("o", 1.0)
                )
                .foregroundStyle(Color(Nachbetrachtungsbild.streifenfarbe(stufe: feld.stufe)))
            }
            if daten.hatOfen == true {
                ForEach(Nachbetrachtungsbild.ofenspannen(linie, gitter: gitter)) { s in
                    RectangleMark(
                        xStart: .value("von", s.von), xEnd: .value("bis", s.bis),
                        yStart: .value("u", 0.0), yEnd: .value("o", 0.28)
                    )
                    .foregroundStyle(Farbe.ofen)
                }
            }
        }
    }

    /// Die aufgelaufenen Kosten, je Linie eine Kurve.
    ///
    /// **Je Reihe ein `series:`-Schlüssel**, sonst wird aus allen vier eine Linie. Die
    /// Wirklichkeit liegt über den anderen (`z: 5`, `Tagesvergleich.tsx:201`), also wird sie
    /// zuletzt gezeichnet.
    @ChartContentBuilder private func kostenkurven(_ gitter: Nachbetrachtungsbild.Zeitgitter)
        -> some ChartContent
    {
        let linien = Nachbetrachtungsbild.zeilen(daten).sorted {
            ($0.key == "wirklich" ? 1 : 0) < ($1.key == "wirklich" ? 1 : 0)
        }
        ForEach(linien, id: \.key) { l in
            let art = Nachbetrachtungsbild.strichart(key: l.key)
            ForEach(Nachbetrachtungsbild.reihe(l.eurKumuliert, gitter: gitter)) { p in
                if let eur = p.wert {
                    LineMark(
                        x: .value("Zeit", p.zeit), y: .value("€", eur),
                        series: .value("Reihe", l.key)
                    )
                    .foregroundStyle(Color(art.farbe))
                    .lineStyle(strichstil(art))
                }
            }
        }
    }

    /// Durchgezogen oder gestrichelt, in der Breite der Linie.
    ///
    /// Die Strichlänge ist 5 zu 3 - ECharts' `dashed` liegt in derselben Gegend, und ein
    /// kürzerer Strich sieht auf 1,6 Punkten Breite wie eine Punktreihe aus.
    private func strichstil(_ art: Nachbetrachtungsbild.Strichart, dicke: Double? = nil)
        -> StrokeStyle
    {
        StrokeStyle(
            lineWidth: dicke ?? art.breite, dash: art.gestrichelt ? [5, 3] : [])
    }

    private var kostenspanne: ClosedRange<Double> {
        Nachbetrachtungsbild.spanne(
            Nachbetrachtungsbild.zeilen(daten).flatMap { $0.eurKumuliert })
    }

    // MARK: - Die Legende

    /// **Sie steht immer da.** Die Vorlage schreibt die Namen an die Enden der Kurven und lässt
    /// sie am Telefon weg, „dort trägt die Legende unter dem Bild, die ohnehin immer dasteht“
    /// (`Tagesvergleich.tsx:68-69`). Swift Charts hat kein `endLabel` und kein Ausweichen auf
    /// Überlappung; in der App trägt die Legende darum überall.
    private var legende: some View {
        Umbruchzeile(abstand: 16, zeilenabstand: 5) {
            ForEach(Nachbetrachtungsbild.legende(daten)) { stueck in
                HStack(spacing: 7) {
                    legendenmarke(stueck.marke)
                    Text(stueck.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    @ViewBuilder private func legendenmarke(
        _ marke: Nachbetrachtungsbild.Legendenstueck.Marke
    ) -> some View {
        switch marke {
        case .strich(let art):
            strichmarke(art)
        case .stufen:
            // Vier Kästchen zu 9 × 10 Punkten, Lücke 1 (`globals.css:713-714`).
            HStack(spacing: 1) {
                ForEach(Array(Nachbetrachtungsbild.deckungen.enumerated()), id: \.offset) { i, _ in
                    Rectangle()
                        .fill(Color(Nachbetrachtungsbild.streifenfarbe(stufe: i + 1)))
                        .frame(width: 9, height: 10)
                }
            }
        case .ofen:
            Rectangle().fill(Farbe.ofen).frame(width: 10, height: 3)
        }
    }

    /// Die Strichmarke einer Linie: 18 Punkte breit, in ihrer Breite und Art
    /// (`Nachbetrachtung.tsx:38-41`, `globals.css:712`).
    ///
    /// **Mindestens zwei Punkte dick**, wie in der Vorlage (`max(2, round(width))`): eine
    /// Haarlinie von 1,6 Punkten ist auf einem Schirm, der nicht nach Punkten rechnet, keine
    /// Marke mehr, sondern ein Staubkorn.
    private func strichmarke(_ art: Nachbetrachtungsbild.Strichart) -> some View {
        let dicke = max(2, art.breite.rounded())
        return Strichlinie()
            .stroke(Color(art.farbe), style: strichstil(art, dicke: dicke))
            .frame(width: 18, height: dicke)
    }
}

/// Ein waagerechter Strich - die Marke einer Linie in der Legende und in der Auskunft.
///
/// Ein `Rectangle` kann das nicht: gestrichelt wäre dort der *Rand* gestrichelt, also auch oben
/// und unten, und bei zwei Punkten Höhe wird daraus ein Kamm.
private struct Strichlinie: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

#Preview("Tagesvergleich") {
    ScrollView {
        Karte(
            kicker: Nachbetrachtungsworte.vergleichTitel,
            beiwerk: Kartenhinweis.beiwerk(Nachbetrachtungsworte.vergleichDazu)
        ) {
            Tagesvergleichsbild(daten: Vorschau.nachbetrachtung())
        }
        .padding()
    }
    .background(Farbe.grundVerlauf)
}
