import Charts
import DuckCurveKit
import SwiftUI

/// Der Fahrplan über seinen ganzen Horizont: acht Flächen über einer Zeitachse.
///
/// **Was hier vorher stand.** Eine Fläche: ein Band für die geplante Freigabe, darüber der
/// Preis, beides auf 24 Stunden geschnitten, die y-Achse versteckt. Gemessenes kam nicht vor.
/// Die Vorlage (`apps/web/src/components/waerme/Fahrplan.tsx`) stellt Geplantes und Gemessenes
/// nebeneinander, und das ist der Zweck der Seite: Duck Curve fordert an, die Maschine
/// entscheidet, und ob beides zusammenpasst sieht man nur, wenn beides dasteht.
///
/// **Acht Flächen, nicht eine mit acht Achsen.** Preis in ct, Leistung in kW, Inhalt in kWh und
/// ein Schaltzustand haben keine gemeinsame Skala. Sie teilen die Zeitachse, und jede Fläche
/// trägt ihren Maßstab im Titel. Im Dashboard war genau das einmal falsch - alle Achsen hingen
/// an Gitter 0 und die Flächen fielen übereinander.
struct Fahrplanzeichnung: View {
    let bild: Fahrplanbild
    let plan: PlanOut
    let jetzt: Date

    /// Wo der Finger auf der Zeitachse steht. Ohne Beruehrung: nichts.
    @State private var gewaehlt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            auskunft
            flaeche(
                "Strompreis · ct/kWh", hoehe: 86, spanne: preisspanne,
                leer: bild.preis.isEmpty ? "keine Preise im Horizont" : nil
            ) {
                preisbild
            }
            flaeche(
                "PV · kW · erwartet und gemessen", hoehe: 74, spanne: pvspanne,
                leer: bild.hatMessung ? nil : "keine Messung im Horizont"
            ) {
                pvbild
            }
            flaeche(
                "Wärmebedarf · kW thermisch", hoehe: 86, spanne: waermespanne,
                leer: bild.hatWaerme ? nil : "kein Wärmebedarf im Fahrplan"
            ) {
                waermebild
            }
            flaeche(
                puffertitel, hoehe: 74, spanne: pufferspanne,
                leer: bild.hatPuffer ? nil : "kein Pufferverlauf im Fahrplan"
            ) {
                pufferbild
            }
            flaeche(
                "Wärmepumpe · kW elektrisch gemessen", hoehe: 66, spanne: wpspanne,
                leer: bild.hatWpMessung ? nil : "keine Messung der Wärmepumpe"
            ) {
                wpbild
            }
            flaeche("Wärmepumpe geplant", hoehe: 16, spanne: 0...1, leer: nil) {
                streifen(bild.zustandsstreifen)
            }
            flaeche(
                "Anforderung gemessen", hoehe: 16, spanne: 0...1,
                leer: bild.hatAnforderung ? nil : "keine Anforderung gemessen"
            ) {
                streifen(bild.anforderung)
            }
            flaeche(
                "Pelletofen geplant", hoehe: 16, spanne: 0...1,
                leer: bild.ofenstreifen.contains { $0.rolle == .ofenAn }
                    ? nil
                    : (bild.hatOfenfahrplan
                        ? "nicht eingeplant, Begründung darunter" : "kein Ofenfahrplan"),
                mitZeitachse: true
            ) {
                streifen(bild.ofenstreifen)
            }
            legende
        }
    }

    // MARK: - Die Auskunft zur berührten Viertelstunde

    /// **Warum es die gibt.** Das Dashboard zeigt all das in einem Hinweisfenster unter dem
    /// Zeiger. Am Telefon gibt es kein Darüberfahren; ohne diese Auskunft stünden
    /// Außentemperatur, Arbeitszahl, der Prognosefehler der Sonne und die Zerlegung des
    /// Wärmebedarfs in Heizen und Warmwasser nirgends in der App.
    @ViewBuilder private var auskunft: some View {
        if let zeit = gewaehlt, let a = Fahrplanbild.auskunft(plan, zeit: zeit, jetzt: jetzt) {
            VStack(alignment: .leading, spacing: 3) {
                Text(a.titel).font(Schrift.zahlKlein).foregroundStyle(Farbe.amberWeich)
                ForEach(a.zeilen) { z in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if !z.wort.isEmpty {
                            Text(z.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        }
                        Text(z.wert)
                            .font(z.eingerueckt ? Schrift.winzig : Schrift.zahlKlein)
                            .foregroundStyle(farbe(z.rolle))
                    }
                    .padding(.leading, z.eingerueckt ? 12 : 0)
                }
                if let satz = a.satz {
                    Text(satz)
                        .font(Schrift.winzig).foregroundStyle(Farbe.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Text("Zum Lesen einer Viertelstunde die Zeichnung berühren.")
                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }

    // MARK: - Der Rahmen einer Fläche

    /// Titel, Zeichnung, und bei leerer Reihe ein Wort in der Mitte statt einer leeren Achse.
    ///
    /// Die Zeitachse steht nur unter der letzten Fläche: achtmal dieselben Uhrzeiten sind
    /// siebenmal Lärm. Die senkrechten Rasterlinien stehen in jeder, damit die Flächen
    /// übereinander lesbar bleiben.
    private func flaeche<Inhalt: ChartContent>(
        _ titel: String, hoehe: CGFloat, spanne: ClosedRange<Double>, leer: String?,
        mitZeitachse: Bool = false, @ChartContentBuilder inhalt: () -> Inhalt
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titel).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            Chart {
                inhalt()
                if let h = bild.horizont, h.contains(jetzt) {
                    RuleMark(x: .value("jetzt", jetzt))
                        .foregroundStyle(Farbe.text2)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                if let g = gewaehlt {
                    RuleMark(x: .value("gewählt", g))
                        .foregroundStyle(Farbe.text1.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXScale(domain: zeitbereich)
            .chartYScale(domain: spanne)
            // Alle acht Flaechen teilen eine Auswahl: ein Finger auf der Preisflaeche zeigt
            // auch, was der Puffer und der Ofen in dieser Viertelstunde tun.
            .chartXSelection(value: $gewaehlt)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { w in
                    AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                    if mitZeitachse, let t = w.as(Date.self) {
                        AxisValueLabel {
                            // Am Tagesanfang das Datum, sonst die Stunde: der Horizont reicht
                            // ueber zwei Tage, und zwei Zwoelfen ohne Tag sind nicht zu trennen.
                            Text(istTagesanfang(t) ? Tag.kurz(Tag.iso(t)) : Formate.hhmm(t))
                                .font(Schrift.achse)
                                .foregroundStyle(istTagesanfang(t) ? Farbe.text2 : Farbe.text3)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    if leer == nil, hoehe > 20 {
                        AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                        AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
            .frame(height: hoehe)
            .overlay {
                if let leer {
                    Text(leer).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private func istTagesanfang(_ t: Date) -> Bool {
        Kalender.haus.component(.hour, from: t) == 0
    }

    // MARK: - Die einzelnen Flächen

    @ChartContentBuilder private var preisbild: some ChartContent {
        // Die Preisfenster hinter der Kurve, ohne Beschriftung: zwei kurze Tiefs nebeneinander
        // druckten im Dashboard ihre Namen ineinander. Sie stehen in der Legende.
        ForEach(Array(bild.baender.enumerated()), id: \.offset) { _, b in
            RectangleMark(
                xStart: .value("von", b.von), xEnd: .value("bis", b.bis),
                yStart: .value("u", preisspanne.lowerBound),
                yEnd: .value("o", preisspanne.upperBound)
            )
            .foregroundStyle((b.negativ ? Farbe.alarm : Farbe.mist).opacity(0.14))
        }
        ForEach(bild.preis) { p in
            if let ct = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("ct", ct))
                    .foregroundStyle(Farbe.preis.opacity(0.16))
                    .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.preis) { p in
            if let ct = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("ct", ct),
                    series: .value("Reihe", "preis")
                )
                .foregroundStyle(Farbe.preis)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
                .interpolationMethod(.stepEnd)
            }
        }
    }

    @ChartContentBuilder private var pvbild: some ChartContent {
        ForEach(bild.pvGemessen) { p in
            if let kw = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                    .foregroundStyle(Farbe.pv.opacity(0.38))
            }
        }
        ForEach(bild.pvErwartet) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "erwartet")
                )
                .foregroundStyle(Farbe.mist)
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
        }
    }

    /// Zwei Flächen statt eines Stapels: zuerst die Summe, darüber das Heizen.
    @ChartContentBuilder private var waermebild: some ChartContent {
        ForEach(bild.waermeSumme) { p in
            if let kw = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                    .foregroundStyle(Farbe.warmwasser.opacity(0.75))
                    .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.heizen) { p in
            if let kw = p.wert {
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "heizen")
                )
                .foregroundStyle(Farbe.haus.opacity(0.75))
                .interpolationMethod(.stepEnd)
            }
        }
    }

    @ChartContentBuilder private var pufferbild: some ChartContent {
        // Unterhalb dieser Linie darf der Puffer nicht landen; sie ist eine Bedingung des
        // Modells und keine Zierde.
        if let reserve = bild.pufferReserve, let h = bild.horizont {
            RectangleMark(
                xStart: .value("von", h.lowerBound), xEnd: .value("bis", h.upperBound),
                yStart: .value("u", pufferspanne.lowerBound), yEnd: .value("o", reserve)
            )
            .foregroundStyle(Farbe.alarm.opacity(0.10))
        }
        if let decke = bild.pufferDecke {
            RuleMark(y: .value("Decke", decke))
                .foregroundStyle(Farbe.linie2)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
        }
        ForEach(bild.puffer) { p in
            if let kwh = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kWh", kwh),
                    series: .value("Reihe", "puffer")
                )
                .foregroundStyle(Farbe.puffer)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
            }
        }
    }

    @ChartContentBuilder private var wpbild: some ChartContent {
        ForEach(bild.wpGemessen) { p in
            if let kw = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                    .foregroundStyle(Farbe.waermepumpe.opacity(0.55))
                    .interpolationMethod(.stepEnd)
            }
        }
    }

    /// Ein Streifen aus Viertelstundenfeldern: Farbe und Höhe tragen beide die Aussage.
    @ChartContentBuilder private func streifen(_ felder: [Fahrplanbild.Feld]) -> some ChartContent {
        ForEach(felder) { f in
            RectangleMark(
                xStart: .value("von", f.zeit),
                xEnd: .value("bis", f.zeit.addingTimeInterval(Ausblick.schritt)),
                yStart: .value("u", 0), yEnd: .value("o", f.hoehe)
            )
            .foregroundStyle(farbe(f.rolle))
        }
    }

    // MARK: - Maßstäbe

    /// Die rote Zone unten hat im Dashboard das Wort „RESERVE" in sich. Auf 74 Punkten Hoehe
    /// ist dafuer kein Platz, also steht es im Titel - gelesen wird es ohnehin dort.
    private var puffertitel: String {
        guard let r = bild.pufferReserve else { return "Pufferinhalt · kWh" }
        return "Pufferinhalt · kWh · Reserve unter \(Formate.kwh(r))"
    }

    private var zeitbereich: ClosedRange<Date> {
        bild.horizont ?? jetzt...jetzt.addingTimeInterval(24 * 3600)
    }

    private var preisspanne: ClosedRange<Double> {
        Fahrplanbild.spanne(bild.preisUnten, bis: bild.preis.map(\.wert)) ?? 0...40
    }

    private var pvspanne: ClosedRange<Double> {
        Fahrplanbild.spanne(0, bis: bild.pvErwartet.map(\.wert) + bild.pvGemessen.map(\.wert))
            ?? 0...5
    }

    private var waermespanne: ClosedRange<Double> {
        Fahrplanbild.spanne(bild.waermeUnten, bis: bild.waermeSumme.map(\.wert)) ?? 0...5
    }

    private var pufferspanne: ClosedRange<Double> {
        Fahrplanbild.spanne(0, bis: bild.puffer.map(\.wert) + [bild.pufferDecke]) ?? 0...10
    }

    private var wpspanne: ClosedRange<Double> {
        Fahrplanbild.spanne(0, bis: bild.wpGemessen.map(\.wert)) ?? 0...3
    }

    /// Jede Rolle hat genau eine Farbe - auch die der Auskunftszeilen.
    ///
    /// **Ohne `default`, und das ist Absicht.** Als ``Fahrplanbild/Rolle`` um sechs Faelle
    /// wuchs, hat der Compiler genau hier angehalten. Ein `default` haette das verschluckt und
    /// sechs Zeilen stillschweigend weiss gefaerbt.
    private func farbe(_ r: Fahrplanbild.Rolle) -> Color {
        switch r {
        case .angefordert: return Farbe.waermepumpe
        case .gemieden: return Farbe.alarm
        case .frei: return Farbe.text1.opacity(0.3)
        case .aus: return Farbe.text1.opacity(0.14)
        case .ofenAn: return Farbe.ofen
        case .ofenAus: return Farbe.text1.opacity(0.14)
        case .pv: return Farbe.pv
        case .puffer: return Farbe.puffer
        case .wpGemessen: return Farbe.waermepumpe
        case .heizen: return Farbe.haus
        case .warmwasser: return Farbe.warmwasser
        case .neutral: return Farbe.text1
        }
    }

    // MARK: - Die Legende

    private var legende: some View {
        Umbruchzeile(abstand: 13, zeilenabstand: 5) {
            ForEach(legendenstuecke) { s in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(s.farbe)
                        .frame(width: 13, height: s.hoehe)
                    Text(s.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private var legendenstuecke: [Legendenstueck] {
        var s = Fahrplanbild.zustandslegende.map {
            Legendenstueck(
                wort: "Wärmepumpe \($0.wort)", farbe: farbe($0.rolle),
                hoehe: max(3, $0.hoehe * 10))
        }
        s += [
            .init(wort: "Ofen brennt", farbe: Farbe.ofen, hoehe: 9),
            .init(wort: "Heizen", farbe: Farbe.haus, hoehe: 9),
            .init(wort: "Warmwasser", farbe: Farbe.warmwasser, hoehe: 9),
            .init(wort: "Pufferinhalt", farbe: Farbe.puffer, hoehe: 3),
            .init(wort: "PV gemessen", farbe: Farbe.pv, hoehe: 9),
            .init(wort: "PV erwartet", farbe: Farbe.mist, hoehe: 2),
            .init(wort: "Preistief", farbe: Farbe.mist.opacity(0.32), hoehe: 9),
        ]
        if bild.hatNegativesFenster {
            s.append(.init(wort: "negativer Preis", farbe: Farbe.alarm.opacity(0.32), hoehe: 9))
        }
        return s
    }
}

/// Ein Eintrag einer Legende: ein Klotz in der Farbe und seiner Höhe, dann das Wort.
struct Legendenstueck: Identifiable {
    let wort: String
    let farbe: Color
    let hoehe: CGFloat
    var id: String { wort }
}

/// Eine Zeile, die am Rand umbricht - zwölf Legendenstücke passen auf kein Telefon.
///
/// SwiftUI hat dafür nichts: `HStack` schiebt hinaus, `ViewThatFits` kennt nur fertige
/// Entwürfe, und ein `LazyVGrid` gibt jedem Stück dieselbe Breite, was bei „aus" und
/// „Wärmepumpe angefordert" lächerlich aussieht. Also ein eigenes `Layout`.
struct Umbruchzeile: Layout {
    var abstand: CGFloat = 12
    var zeilenabstand: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let breite = proposal.width ?? .infinity
        let zeilen = umbrechen(subviews, breite: breite)
        let hoehe = zeilen.reduce(0) { $0 + $1.hoehe } + CGFloat(max(0, zeilen.count - 1)) * zeilenabstand
        return CGSize(width: proposal.width ?? zeilen.map(\.breite).max() ?? 0, height: hoehe)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var y = bounds.minY
        for zeile in umbrechen(subviews, breite: bounds.width) {
            var x = bounds.minX
            for i in zeile.indizes {
                let g = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(
                    at: CGPoint(x: x, y: y + (zeile.hoehe - g.height) / 2),
                    proposal: ProposedViewSize(g))
                x += g.width + abstand
            }
            y += zeile.hoehe + zeilenabstand
        }
    }

    private struct Zeile {
        var indizes: [Int] = []
        var breite: CGFloat = 0
        var hoehe: CGFloat = 0
    }

    private func umbrechen(_ subviews: Subviews, breite: CGFloat) -> [Zeile] {
        var zeilen: [Zeile] = []
        var jetzt = Zeile()
        for i in subviews.indices {
            let g = subviews[i].sizeThatFits(.unspecified)
            let dazu = jetzt.indizes.isEmpty ? g.width : jetzt.breite + abstand + g.width
            if !jetzt.indizes.isEmpty, dazu > breite {
                zeilen.append(jetzt)
                jetzt = Zeile()
            }
            jetzt.breite = jetzt.indizes.isEmpty ? g.width : jetzt.breite + abstand + g.width
            jetzt.hoehe = max(jetzt.hoehe, g.height)
            jetzt.indizes.append(i)
        }
        if !jetzt.indizes.isEmpty { zeilen.append(jetzt) }
        return zeilen
    }
}

#Preview("Fahrplan") {
    ScrollView {
        Fahrplanzeichnung(
            bild: Fahrplanbild.baue(Vorschau.plan()), plan: Vorschau.plan(),
            jetzt: Vorschau.jetzt
        )
        .padding()
    }
    .background(Farbe.grundVerlauf)
}
