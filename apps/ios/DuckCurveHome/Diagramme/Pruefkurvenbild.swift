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
///
/// **Eine Geste, zwei Aufgaben - und darum zwei Wege.** Die Vorlage hat für das Zeitfenster
/// drei eigene Bedienwege (Werkzeug, Regler, Rad - `charts.ts:634-672`) und *daneben* das
/// Hinweisfenster am Zeiger. Swift Charts hat für beides nur die Wischgeste:
/// `chartXSelection(range:)` und `chartXSelection(value:)` nehmen sie einander weg. Die Geste
/// bekommt deshalb die Werteauskunft - die ist nur so zu haben und ist das Werkzeug, für das
/// diese Seite da ist (`charts.ts:591-601`) -, und das Zeitfenster bekommt die Knöpfe unter dem
/// Bild (``Pruefkurve/fensterbreiten``). Bis zum 21.11.2026 war es umgekehrt, und es gab keine
/// Auskunft: man sah eine Abweichung und konnte sie nicht beziffern.
struct Pruefkurvenbild: View {
    let kurve: Pruefkurve

    /// Welcher Ausschnitt gezeigt wird. Ohne Auswahl der ganze Tag.
    @State private var ausschnitt: ClosedRange<Double>?
    /// Wo der Finger auf der Zeitachse steht, in Stunden seit Tagesbeginn.
    @State private var gewaehlt: Double?

    /// Die Höhe der Zeichenfläche.
    ///
    /// **Nachgerechnet und nicht übernommen.** Die Karte der Vorlage ist fest 480 Punkte hoch
    /// und das Diagramm füllt den Rest (`DataCheck.tsx:71, 80`) - aber von diesem Rest geht
    /// innerhalb des Diagramms noch das Gitter ab: `grid: { top: 46, bottom: 88 }`
    /// (`charts.ts:717`), also 134 Punkte für die Werkzeugzeile, den Regler und die Legende.
    /// 480 minus 32 Innenrand minus Kartenkopf ergibt rund 426, davon bleiben als
    /// Zeichenfläche rund 292. Hier tragen Kopfzeile, Auskunft, Fensterwahl und Legende
    /// dieselbe Last außerhalb des Bildes, und 300 Punkte Bild sind deshalb etwas mehr Fläche
    /// als die Vorlage hat, nicht weniger.
    ///
    /// **Keine feste Höhe an der Karte**, und das ist Absicht: ``Karte`` hat keinen
    /// Höhenparameter, und einen einzuführen hieße, eine Karte zu bauen, die bei „Größerer
    /// Text" ihren Inhalt abschneidet.
    private static let bildhoehe: CGFloat = 300

    private var gezeigt: Pruefkurve {
        guard let a = ausschnitt else {
            // Ohne Ausschnitt reicht jede fünfte Minute: 1440 Punkte mal sechs Reihen sind
            // achttausend Marken, und auf tausend Bildpunkten sieht man den Unterschied nicht.
            return kurve.verdichtet(schrittMin: 5)
        }
        return kurve.ausschnitt(von: a.lowerBound, bis: a.upperBound)
    }

    var body: some View {
        let k = gezeigt
        return VStack(alignment: .leading, spacing: 8) {
            if kurve.leer {
                Leer(satz: Pruefkurve.leersatz)
            } else {
                kopfzeile
                auskunft(k)
                bild(k)
                fensterwahl(k)
                legende
            }
        }
    }

    /// Die Vorzeichenregel, wörtlich wie in der Vorlage (`DataCheck.tsx:76`).
    ///
    /// **Sie bricht um und wird nicht abgeschnitten.** `handy.css:185` setzt für genau diese
    /// Zeile `white-space: normal; overflow: visible; text-overflow: clip`, und
    /// `ui/Card.tsx:24-25` nennt den Grund: „ein abgeschnittener Legendeneintrag ist schlimmer
    /// als eine zweite Zeile“. Hier stand `lineLimit(2)`, und auf 390 Punkten fiel damit
    /// „Ladestand rechts in %“ weg - also gerade der Hinweis auf die zweite Achse.
    ///
    /// **Sie steht im Kartenkörper und nicht im Kartenkopf**, obwohl die Vorlage sie als
    /// `right=` setzt - mit der eigenen Begründung, dass diese Zeile die Kopfzeile am Telefon
    /// sprengt (`DataCheck.tsx:73-76`). ``DatenSeite/leistungen`` schreibt das aus.
    private var kopfzeile: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(
                "Netz + Bezug, − Einspeisung · Speicher + Entladen, − Laden · Ladestand rechts "
                    + "in %"
            )
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if ausschnitt != nil {
                Button(Pruefworte.ganzerTag) {
                    ausschnitt = nil
                }
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.amber)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Die Auskunft zur berührten Minute

    /// Die Werte der berührten Minute, jede Reihe in ihrer Farbe (`charts.ts:591-601`).
    ///
    /// **Eine Zeile über dem Bild und kein Fenster am Finger.** Dasselbe tun die Nachbetrachtung
    /// (`Diagramme/Tagesvergleichsbild.swift:58-80`) und der Fahrplan: ein Fenster unter dem
    /// Finger liegt am Telefon unter dem Finger. Die Zeile steht auch dann da, wenn niemand
    /// berührt hat - sonst verschöbe sich beim ersten Tippen die halbe Karte.
    @ViewBuilder private func auskunft(_ k: Pruefkurve) -> some View {
        if let g = gewaehlt, let a = k.auskunft(stunde: g) {
            Umbruchzeile(abstand: 12, zeilenabstand: 3) {
                Text(a.zeit)
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.amberWeich)
                ForEach(a.zeilen) { z in
                    auskunftsstueck(z)
                }
            }
        } else {
            Text(Pruefworte.beruehrung)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
        }
    }

    /// Name in der Farbe der Reihe, Wert daneben - wie die Vorlage ihre Zeile setzt
    /// (`charts.ts:597`: `<span style="color:…">Name</span><span>Wert</span>`).
    private func auskunftsstueck(_ z: Pruefkurve.Auskunft.Zeile) -> some View {
        HStack(spacing: 5) {
            Text(z.reihe.name)
                .font(Schrift.winzig)
                .foregroundStyle(farbe(z.reihe))
            Text(z.wert)
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text1)
        }
    }

    // MARK: - Das Bild

    private func bild(_ k: Pruefkurve) -> some View {
        Chart {
            ForEach(Pruefkurve.Reihe.allCases) { reihe in
                reihenmarken(reihe, k)
            }
            // Die Nulllinie ist hier keine Zierde: über ihr ist Bezug, unter ihr Einspeisung.
            RuleMark(y: .value("Null", 0))
                .foregroundStyle(Farbe.text1.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1))
            zeiger
        }
        .chartXScale(domain: k.fenster)
        .chartYScale(domain: k.leistungsspanne)
        .chartXSelection(value: $gewaehlt)
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
        .frame(height: Self.bildhoehe)
    }

    /// Wo die Auskunft gilt. Ohne ihn stünden Zahlen da, die zu keiner sichtbaren Stelle
    /// gehören - am Telefon liegt der Finger auf dem Bild und verdeckt gerade die Minute.
    @ChartContentBuilder private var zeiger: some ChartContent {
        if let g = gewaehlt {
            RuleMark(x: .value("gewählt", g))
                .foregroundStyle(Farbe.text1.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }

    // MARK: - Das Zeitfenster

    /// Die drei Fensterbreiten, gelegt um die berührte Stelle.
    ///
    /// **Ohne berührte Stelle um die Mitte des gezeigten Ausschnitts.** Das ist kein
    /// Behelf, sondern genau das, was das Rad der Vorlage tut, wenn der Zeiger in der Mitte
    /// steht (`charts.ts:659`, `zoomOnMouseWheel`). Gerechnet wird auf der ganzen Kurve und
    /// nicht auf dem Ausschnitt: sonst hätte ein zweiter Druck auf „3 h“ ein Fenster im
    /// Fenster ergeben.
    private func fensterwahl(_ k: Pruefkurve) -> some View {
        let mitte = (k.fenster.lowerBound + k.fenster.upperBound) / 2
        return Umbruchzeile(abstand: 10, zeilenabstand: 4) {
            Text("Zeitfenster")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
            ForEach(Pruefkurve.fensterbreiten) { breite in
                Button(breite.wort) {
                    ausschnitt = kurve.fensterUm(
                        gewaehlt ?? mitte, breiteH: breite.stunden)
                }
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.amber)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Die Reihen

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
                    x: .value("Stunde", p.stunde),
                    y: .value("kW", achsenwert(p, reihe, k)),
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

    /// Wo ein Punkt auf der **gemeinsamen** Kilowattachse liegt.
    ///
    /// **Warum der Ladestand hier durch die Umrechnung muss.** In der Vorlage hängt er an der
    /// zweiten Werteachse (`charts.ts:770-779`, `yAxisIndex: 1`); Swift Charts hat die nicht,
    /// und `chartYScale` ist ``Pruefkurve/leistungsspanne`` - eine Spanne, aus der der
    /// Ladestand ausdrücklich herausgerechnet ist (``Pruefkurve/leistungsreihen``). Ein
    /// Ladestand von 42 % läge damit bei 42 kW, also weit über dem Rand, und Swift Charts
    /// beschneidet ihn auf die Zeichenfläche: die Linie wäre nie zu sehen, obwohl die rechte
    /// Achse sie beschriftet und die Legende sie führt. Gerechnet wird im Kern
    /// (``Pruefkurve/ladestandAufLeistung(_:)``), die Ansicht wählt nur.
    ///
    /// ``Pruefkurve/auskunft(stunde:)`` bleibt davon unberührt: dort gehört der gemessene
    /// Prozentwert hin, nicht der auf die Achse gerechnete.
    private func achsenwert(
        _ p: Kurvenpunkt, _ reihe: Pruefkurve.Reihe, _ k: Pruefkurve
    ) -> Double {
        reihe.rechteAchse ? k.ladestandAufLeistung(p.wert) : p.wert
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
    /// Was statt der Zeilen dasteht: „lädt …“ oder „nicht abrufbar“
    /// (``Pruefstand/quellensatz``). `nil` heißt: die Zeilen sind dran.
    ///
    /// **Zwei Zustände und nicht einer.** Bis zum 21.11.2026 sagte diese Karte beim Öffnen
    /// „Der Zustand der Quellen ist gerade nicht abrufbar.“ - eine Behauptung über einen
    /// Dienst, der noch nicht gefragt worden war. Die Vorlage schreibt dort „lädt …“
    /// (`Sources.tsx:48-49`).
    var satz: String?
    /// Ist dieser Satz der Ladesatz? Dann steht Alfred daneben.
    ///
    /// **Warum ein eigenes Feld und nicht ein Vergleich mit dem Satz.** ``satz`` trägt zwei
    /// verschiedene Nachrichten - „lädt …“ und „nicht abrufbar“ -, und die Ente gehört nur zur
    /// ersten: eine schaukelnde Ente neben einem Befund wäre eine Lüge über einen Vorgang, den
    /// es nicht gibt. Welche von beiden es ist, weiß der ``Pruefstand`` und nicht diese Karte;
    /// den Satz danach wieder auseinanderzunehmen hieße, dieselbe Entscheidung zweimal zu
    /// treffen, und das zweite Mal ohne Test.
    var laedt = false

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let satz {
                if laedt {
                    Ladeente(satz: satz)
                } else {
                    Leer(satz: satz)
                }
            } else {
                ForEach(zeilen) { z in
                    zeile(z)
                }
            }
        }
    }

    private func zeile(_ z: Quellenstand.Quellenzeile) -> some View {
        inhalt(z)
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

    /// **Am Telefon steht der Satz des Dienstes unter dem Namen.** Die Vorlage gibt ihm
    /// `w-full … sm:w-auto` (`Sources.tsx:61, 79`): unter 640 Punkten eine eigene Zeile. Hier
    /// standen Name und Satz immer in einer Zeile, und auf 390 Punkten teilte sich „inexogy ·
    /// 412 Abfragen · letzter Wert vor 3 min“ die Zeile mit „Zähler (inexogy)“ - beides
    /// gequetscht, keines lesbar.
    @ViewBuilder private func inhalt(_ z: Quellenstand.Quellenzeile) -> some View {
        if schmal {
            VStack(alignment: .leading, spacing: 5) {
                kopf(z)
                dienstsatz(z.satz)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                kopf(z)
                dienstsatz(z.satz)
                Spacer(minLength: 0)
            }
        }
    }

    /// Punkt und Name, wie die Vorlage sie zusammenhält (`Sources.tsx:58-61`,
    /// `<span class="flex items-center gap-2">`): beim Umbruch bleiben sie beieinander.
    private func kopf(_ z: Quellenstand.Quellenzeile) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(farbe(z.ton))
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { _ in 7 }
            Text(z.name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text1)
        }
    }

    private func dienstsatz(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.zahlKlein)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: schmal ? .infinity : nil, alignment: .leading)
    }

    private func farbe(_ ton: Quellenstand.Ton) -> Color {
        switch ton {
        case .ok: return Farbe.amber
        case .alarm: return Farbe.alarm
        case .still: return Farbe.text3
        }
    }
}
