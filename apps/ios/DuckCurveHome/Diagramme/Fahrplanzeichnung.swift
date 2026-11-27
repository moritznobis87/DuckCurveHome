import Charts
import DuckCurveKit
import SwiftUI

/// Der Fahrplan über seinen ganzen Horizont: acht Flächen über **einer** Zeitachse.
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
///
/// **Eine linke Kante für alle acht, und das ist die Hauptaussage der Seite.** Die Vorlage setzt
/// jedem der acht Gitter dieselben Ränder (`Fahrplan.tsx:291`: `left: 56, right: 18`) und legt
/// die Titel auf dieselben 56 Punkte (`:287`) - nur dadurch bedeutet eine Senkrechte durch die
/// Zeichnung überall denselben Zeitpunkt, und nur dadurch stimmt der Satz „sechs Flächen
/// übereinander mit einer gemeinsamen Zeitachse“ (`:19-22`). Hier war bis zum 21.11.2026 jede
/// Fläche ein eigenes `Chart` mit `AxisMarks(position: .leading)`, und das nimmt sich so viel
/// Platz, wie seine eigene Beschriftung braucht: die fünf Wertflächen standen um die Breite von
/// „40“ bzw. „21,5“ eingerückt, die drei Streifen bekamen gar keine Beschriftung und fingen am
/// Kartenrand an - und die Zeitachse stand ausgerechnet unter dem schmalsten der drei. Jetzt
/// trägt eine eigene Spalte fester Breite (``achsenbreite``) die Zahlen, jedes `Chart` hat seine
/// Achsen versteckt, und die Zeitachse steht als neunte, leere Zeichnung unter denselben
/// Rändern. Derselbe Weg wie in `Diagramme/Abdeckungskarte.swift:42, 108, 182` und
/// `Diagramme/Kennlinienbilder.swift`; welche Zahlen in der Spalte stehen und wo, rechnet
/// ``Fahrplanraster/achsenmarken(_:etwa:)``.
struct Fahrplanzeichnung: View {
    let bild: Fahrplanbild
    let plan: PlanOut
    let jetzt: Date

    /// Wo der Finger auf der Zeitachse steht. Ohne Beruehrung: nichts.
    @State private var gewaehlt: Date?

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    /// Die Breite der Zahlenspalte links - für alle acht Flächen dieselbe.
    ///
    /// Die Vorlage hat 56 CSS-Punkte bei 10 px Schrift (`Fahrplan.tsx:291`, `:264`). „21,5“ in
    /// ``Schrift/achse`` braucht am iPad 42 Punkte; am Telefon reicht weniger, und dort zählt
    /// jeder Punkt für die Zeichnung selbst.
    private var achsenbreite: CGFloat { schmal ? 34 : 42 }

    /// Der rechte Rand, den sich die Vorlage für die letzte Zeitmarke nimmt (`:291`:
    /// `right: 18`). Er gilt für alle acht Flächen und für die Zeitachse, sonst wäre die
    /// gemeinsame Kante nur eine halbe.
    private let rechterRand: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            auskunft
            // Für die Preisfläche hat die Vorlage **keinen** Leerhinweis (`:473-487`: sechs
            // Hinweise, der Preis ist nicht darunter). Eine Preiszeichnung ohne Preise ist in
            // diesem Haus kein Zustand, über den man etwas sagen müsste - und der Hinweis
            // nahm hier zugleich der Achse die Beschriftung.
            flaeche("Strompreis · ct/kWh", hoehe: 92, spanne: preisspanne, leer: nil) {
                preisbild
            }
            flaeche(
                "PV · kW · erwartet und gemessen", hoehe: 80, spanne: pvspanne,
                leer: bild.hatMessung ? nil : "keine Messung im Horizont"
            ) {
                pvbild
            }
            flaeche(
                "Wärmebedarf · kW thermisch", hoehe: 92, spanne: waermespanne,
                leer: bild.hatWaerme ? nil : "kein Wärmebedarf im Fahrplan"
            ) {
                waermebild
            }
            flaeche(
                puffertitel, hoehe: 80, spanne: pufferspanne,
                leer: bild.hatPuffer ? nil : "kein Pufferverlauf im Fahrplan"
            ) {
                pufferbild
            }
            flaeche(
                "Wärmepumpe · kW elektrisch · gemessen und geplant", hoehe: 72, spanne: wpspanne,
                leer: bild.hatWpMessung || bild.hatWpPlan
                    ? nil : "weder Messung noch Plan der Wärmepumpe"
            ) {
                wpbild
            }
            flaeche("Wärmepumpe geplant", hoehe: 22, spanne: 0...1, leer: nil, beschriftet: false) {
                streifen(bild.zustandsstreifen)
            }
            flaeche(
                "Anforderung gemessen", hoehe: 22, spanne: 0...1,
                leer: bild.hatAnforderung ? nil : "keine Anforderung gemessen",
                beschriftet: false
            ) {
                streifen(bild.anforderung)
            }
            flaeche(
                "Pelletofen geplant", hoehe: 22, spanne: 0...1,
                leer: bild.ofenstreifen.contains { $0.rolle == .ofenAn }
                    ? nil
                    : (bild.hatOfenfahrplan
                        ? "nicht eingeplant, Begründung darunter" : "kein Ofenfahrplan"),
                beschriftet: false
            ) {
                streifen(bild.ofenstreifen)
            }
            zeitachse
            Fahrplanlegende(stuecke: bild.legende)
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
            // **Dunkler als die Karte, mit bernsteinfarbenem Rand** (`Fahrplan.tsx:315-316`:
            // `backgroundColor: C.deep`, `borderColor: rgba(242,169,0,.4)`). Daran erkennt man,
            // dass das Feld zum Zeiger gehört und nicht zur Karte: es stand auf
            // ``Farbe/flaeche2`` ohne Umriss und sah aus wie eine zweite Karte im Bild.
            .background(Farbe.deep, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Farbe.amber.opacity(0.4), lineWidth: 1)
            }
        } else {
            Text("Zum Lesen einer Viertelstunde die Zeichnung berühren.")
                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }

    // MARK: - Der Rahmen einer Fläche

    /// Titel, Zahlenspalte, Zeichnung - und bei leerer Reihe ein Wort in der Mitte.
    ///
    /// **Die Zeitachse steht nicht hier.** Sie trägt in der Vorlage nur das letzte Gitter
    /// (`Fahrplan.tsx:292`), und wenn sie zu einer der acht Flächen gehörte, hinge sie an deren
    /// Einrückung. Sie steht darum als eigene Zeile unter allen acht (``zeitachse``). Die
    /// senkrechten Rasterlinien stehen in jeder Fläche (`:255`), damit die Flächen übereinander
    /// lesbar bleiben.
    ///
    /// **Die waagerechten Rasterlinien bleiben auch dann stehen, wenn ein Hinweis dasteht.** In
    /// der Vorlage fehlt bei einer leeren Fläche nur die Reihe; Achse und Raster bleiben
    /// (`:473-487` setzt ein `graphic`, kein `show: false`). Hier blendete derselbe `leer`-Fall
    /// die Beschriftung mit ab, und dann wanderte die linke Kante der Fläche.
    private func flaeche<Inhalt: ChartContent>(
        _ titel: String, hoehe: CGFloat, spanne: ClosedRange<Double>, leer: String?,
        beschriftet: Bool = true, @ChartContentBuilder inhalt: () -> Inhalt
    ) -> some View {
        let marken = beschriftet ? Fahrplanraster.achsenmarken(spanne) : []
        return VStack(alignment: .leading, spacing: 3) {
            // Der Titel steht auf der linken Kante der Zeichnung, nicht auf der der Karte
            // (`Fahrplan.tsx:287-288`: `left: 56` wie das Gitter).
            Text(titel)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .padding(.leading, achsenbreite)
            HStack(spacing: 0) {
                werteachse(marken, hoehe: hoehe)
                diagramm(spanne: spanne, marken: marken, hoehe: hoehe, inhalt: inhalt())
                    .overlay {
                        if let leer {
                            Text(leer).font(Schrift.achse).foregroundStyle(Farbe.text3)
                        }
                    }
                Spacer().frame(width: rechterRand)
            }
        }
    }

    /// Eine der acht Flächen, mit versteckten Achsen: die Zahlen stehen daneben, die Zeit darunter.
    private func diagramm<Inhalt: ChartContent>(
        spanne: ClosedRange<Double>, marken: [Fahrplanraster.Achsenmarke], hoehe: CGFloat,
        inhalt: Inhalt
    ) -> some View {
        Chart {
            inhalt
            if let h = bild.horizont, h.contains(jetzt) {
                // **Bernstein, nicht Grau** (`Fahrplan.tsx:272-278`: `--amber-soft`,
                // gestrichelt, 1,2). Die Jetzt-Linie stand in derselben Farbe wie die
                // Achsenbeschriftung und wie die Auswahllinie daneben - drei graue
                // Senkrechte, und keine sagte mehr, welche „jetzt“ meint.
                RuleMark(x: .value("jetzt", jetzt))
                    .foregroundStyle(Farbe.amberWeich)
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
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
        // auch, was der Puffer und der Ofen in dieser Viertelstunde tun. Seit alle acht in
        // derselben Breite rechnen, liegt der Treffpunkt in allen auf derselben Stelle.
        .chartXSelection(value: $gewaehlt)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            }
        }
        .chartYAxis {
            AxisMarks(values: marken.map(\.wert)) { _ in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            }
        }
        .frame(height: hoehe)
    }

    /// Die Zahlen der Werteachse in einer eigenen Spalte fester Breite.
    ///
    /// **Ein Rahmen der Höhe null setzt die Zahl mittig auf ihre Rasterlinie**, ohne dass die
    /// Zeilenhöhe der Schrift gemessen werden müsste - derselbe Griff wie bei den Zeitmarken
    /// des Ausblicks (`Bausteine/Ausblickkarte.swift:272-277`, dort waagerecht). Die unterste
    /// Zahl sitzt damit auf der Grundlinie der Fläche, wie `showMinLabel: true` in der Vorlage.
    private func werteachse(_ marken: [Fahrplanraster.Achsenmarke], hoehe: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            // Hält die Spalte auf Breite und Höhe, auch wo keine Zahl steht - die drei
            // Streifen haben keine (`Fahrplan.tsx:308`: `show: false`) und müssen trotzdem
            // auf derselben Kante anfangen.
            Color.clear.frame(width: achsenbreite, height: hoehe)
            ForEach(marken) { m in
                Text(m.wort)
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize()
                    .padding(.trailing, 5)
                    .frame(height: 0)
                    .offset(y: CGFloat(1 - m.anteil) * hoehe)
            }
        }
        .frame(width: achsenbreite, height: hoehe, alignment: .topTrailing)
    }

    /// Die Zeitachse - einmal, unter allen acht Flächen und in derselben Breite.
    ///
    /// Eine leere Zeichnung mit einer unsichtbaren Marke, damit sie dieselbe Skala bekommt:
    /// derselbe Weg wie in `Diagramme/Tageskurve.swift:394-399`. Achtmal dieselben Uhrzeiten
    /// wären siebenmal Lärm, und an einer der acht Flächen hinge sie an deren Einrückung.
    private var zeitachse: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: achsenbreite)
            Chart {
                RuleMark(x: .value("x", zeitbereich.lowerBound)).foregroundStyle(.clear)
            }
            .chartXScale(domain: zeitbereich)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { w in
                    if let t = w.as(Date.self) {
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
            .frame(height: 16)
            Spacer().frame(width: rechterRand)
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
        // **Flaeche blass, Kante voll** (`Fahrplan.tsx:402-411`: Flaeche 0,20, Linie in
        // Volldeckung, Breite 2). Eine Flaeche ohne Kante verliert ihren Rand gegen die
        // Kartenflaeche; die Linie holt die Lesbarkeit zurueck, die die blasse Flaeche abgibt.
        ForEach(bild.pvGemessen) { p in
            if let kw = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                    .foregroundStyle(Farbe.pv.opacity(0.20))
            }
        }
        ForEach(bild.pvGemessen) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "gemessen")
                )
                .foregroundStyle(Farbe.pv)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        ForEach(bild.pvErwartet) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "erwartet")
                )
                .foregroundStyle(Farbe.mist)
                // **1,5 Punkte und geglättet** (`Fahrplan.tsx:397-399`: `width: 1.5`,
                // `smooth: true`). Die Glättung ist dort kein Zierrat: sie unterscheidet die
                // Prognosekurve von der gemessenen Treppe daneben, die in derselben Fläche
                // liegt. Mit 1,2 Punkten und eckig sahen beide gleich aus.
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    /// Zwei Flächen statt eines Stapels: zuerst die Summe, darüber das Heizen.
    ///
    /// **Die Kante des Warmwassers liegt auf der Summe, nicht auf dem Warmwasser.** Im
    /// gestapelten Bild der Vorlage ist die obere Kante der Warmwasserfläche gerade die Summe
    /// aus beidem (`Fahrplan.tsx:415-437`); eine Linie auf `warmwasser` läge mitten im Bild
    /// und gehörte zu nichts. Die Reihe `bild.warmwasser` wird deshalb gar nicht gezeichnet -
    /// sie steht für die Auskunft.
    ///
    /// **Keine Stufen.** Die beiden gestapelten Reihen der Vorlage haben **kein** `step`
    /// (`:415-437`) - anders als der Preis (`:372`) und die gemessene Wärmepumpe (`:459`), die
    /// es ausdrücklich tragen. Das ist kein Zufall der Vorlage: ein Preis gilt eine
    /// Viertelstunde lang unverändert, ein Wärmebedarf ist ein Modellwert, der sich stetig
    /// ändert. Hier stand `stepEnd` an allen vier Marken.
    @ChartContentBuilder private var waermebild: some ChartContent {
        // Links der Jetzt-Linie der Bedarf, mit dem der letzte aufbewahrte Fahrplan davor
        // rechnete: eine Linie für Heizen und Warmwasser zusammen, blasser als der Stapel rechts
        // (`Fahrplan.tsx`, „Wärmebedarf, damals geplant“). Bis zum 27.11.2026 war dieser Teil
        // leer.
        ForEach(bild.waermeDamals) { p in
            if let kw = p.wert {
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "damalsFlaeche"), stacking: .unstacked
                )
                .foregroundStyle(Farbe.warmwasser.opacity(0.12))
                .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.waermeDamals) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "damals")
                )
                .foregroundStyle(Farbe.warmwasser.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.4))
                .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.waermeSumme) { p in
            if let kw = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                    .foregroundStyle(Farbe.warmwasser.opacity(0.34))
            }
        }
        ForEach(bild.heizen) { p in
            if let kw = p.wert {
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "heizen")
                )
                .foregroundStyle(Farbe.haus.opacity(0.22))
            }
        }
        ForEach(bild.waermeSumme) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "summe")
                )
                .foregroundStyle(Farbe.warmwasser)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        ForEach(bild.heizen) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "heizkante")
                )
                .foregroundStyle(Farbe.haus)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
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
        // Die Decke ist in der Vorlage die Achse selbst (`Fahrplan.tsx:302`), keine Linie im
        // Bild: eine gestrichelte Waagerechte dort sieht aus wie eine zweite Reserve.
        //
        // Jede Fläche trägt ihre eigene Reihe und ist nicht gestapelt: Messung und Plan sind
        // zwei Kurven auf derselben Achse und keine Summe.
        //
        // **Gemessen gefüllt, geplant gestrichelt**, wie bei der PV zwei Flächen darüber
        // (`Fahrplan.tsx`, „Pufferinhalt geplant“ und „Pufferinhalt gemessen“). Bis zum
        // 27.11.2026 war der geplante Inhalt die einzige Kurve hier, und links der Jetzt-Linie
        // stand nichts (Hausherr: „Die Diagramme sind ja da leer“).
        ForEach(bild.puffer) { p in
            if let kwh = p.wert {
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kWh", kwh),
                    series: .value("Reihe", "pufferPlanFlaeche"), stacking: .unstacked
                )
                .foregroundStyle(Farbe.puffer.opacity(0.07))
            }
        }
        ForEach(bild.puffer) { p in
            if let kwh = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kWh", kwh),
                    series: .value("Reihe", "pufferPlan")
                )
                .foregroundStyle(Farbe.puffer)
                .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
            }
        }
        // Was der Fahrplan von damals am Ende jeder vergangenen Viertelstunde erwartete. Eine
        // eigene Reihe und nicht die Verlängerung des Plans von jetzt: an der Jetzt-Linie setzt
        // der neue Plan an der Messung an.
        ForEach(bild.pufferDamals) { p in
            if let kwh = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kWh", kwh),
                    series: .value("Reihe", "pufferDamals")
                )
                .foregroundStyle(Farbe.puffer.opacity(0.75))
                .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
            }
        }
        ForEach(bild.pufferGemessen) { p in
            if let kwh = p.wert {
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kWh", kwh),
                    series: .value("Reihe", "pufferIstFlaeche"), stacking: .unstacked
                )
                .foregroundStyle(Farbe.puffer.opacity(0.20))
            }
        }
        ForEach(bild.pufferGemessen) { p in
            if let kwh = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kWh", kwh),
                    series: .value("Reihe", "pufferIst")
                )
                .foregroundStyle(Farbe.puffer)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
    }

    /// Was die Maschine gezogen hat, und rechts der Jetzt-Linie gestrichelt, womit der
    /// Optimierer sie zählt: ihr Nennwert, wo er sie laufen lässt (`Fahrplan.tsx`,
    /// „Wärmepumpe geplant, kW“). Der Hausherr fragte am 27.11.2026, warum es keinen
    /// geplanten elektrischen Bedarf gibt.
    @ChartContentBuilder private var wpbild: some ChartContent {
        ForEach(bild.wpGeplant) { p in
            if let kw = p.wert {
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "wpPlanFlaeche"), stacking: .unstacked
                )
                .foregroundStyle(Farbe.waermepumpe.opacity(0.08))
                .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.wpGeplant) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "wpPlan")
                )
                .foregroundStyle(Farbe.waermepumpe)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.wpGemessen) { p in
            if let kw = p.wert {
                AreaMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "wpIstFlaeche"), stacking: .unstacked
                )
                .foregroundStyle(Farbe.waermepumpe.opacity(0.22))
                .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.wpGemessen) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "wp")
                )
                .foregroundStyle(Farbe.waermepumpe)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
                .interpolationMethod(.stepEnd)
            }
        }
    }

    /// Ein Streifen aus Viertelstundenfeldern: Farbe und Höhe tragen beide die Aussage.
    @ChartContentBuilder private func streifen(_ felder: [Fahrplanbild.Feld]) -> some ChartContent {
        ForEach(felder) { f in
            RectangleMark(
                xStart: .value("von", f.zeit),
                // 92 Prozent der Viertelstunde (`Fahrplan.tsx:465-469`): bei voller Breite
                // beruehren sich die Felder, und aus zwoelf Entscheidungen wird ein Balken.
                xEnd: .value("bis", f.zeit.addingTimeInterval(Ausblick.schritt * 0.92)),
                yStart: .value("u", 0), yEnd: .value("o", f.hoehe)
            )
            .foregroundStyle(farbe(f.rolle))
        }
    }

    // MARK: - Maßstäbe

    /// Die rote Zone unten hat im Dashboard das Wort „RESERVE“ in sich. Auf 74 Punkten Hoehe
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
        Fahrplanbild.spanne(
            bild.waermeUnten, bis: bild.waermeSumme.map(\.wert) + bild.waermeDamals.map(\.wert))
            ?? 0...5
    }

    private var pufferspanne: ClosedRange<Double> {
        Fahrplanbild.spanne(
            0,
            bis: bild.puffer.map(\.wert) + bild.pufferGemessen.map(\.wert)
                + bild.pufferDamals.map(\.wert) + [bild.pufferDecke])
            ?? 0...10
    }

    private var wpspanne: ClosedRange<Double> {
        Fahrplanbild.spanne(0, bis: bild.wpGemessen.map(\.wert) + bild.wpGeplant.map(\.wert))
            ?? 0...3
    }

    private func farbe(_ r: Fahrplanbild.Rolle) -> Color { r.bildfarbe }

}

/// Jede Rolle hat genau eine Farbe **im Bild** - im Streifen, in der Legende und in den
/// Auskunftszeilen.
///
/// **Ohne `default`, und das ist Absicht.** Als ``Fahrplanbild/Rolle`` um sechs Faelle wuchs,
/// hat der Compiler genau hier angehalten. Ein `default` haette das verschluckt und sechs
/// Zeilen stillschweigend weiss gefaerbt.
///
/// **Nicht dieselbe Zuordnung wie in der Entscheidungstabelle**, und das ist kein Versehen.
/// Hier sind „frei“ und „aus“ Flaechen in 30 und 14 Prozent Deckung (`Fahrplan.tsx:51-56`:
/// `WP_ZUSTAND`); in der Tabelle sind dieselben Woerter Text, und Text in 14 Prozent Deckung
/// ist nicht zu lesen. Die Tabelle hebt sie darum auf ``Farbe/text2`` und ``Farbe/text3``
/// (`Seiten/Technik/FahrplanSeite.swift`, `rollenfarbe(_:)`).
extension Fahrplanbild.Rolle {
    var bildfarbe: Color {
        switch self {
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
        case .vorhersage: return Farbe.mist
        }
    }
}

/// Das Verzeichnis unter der Zeichnung: zwoelf Kloetze mit ihrem Wort.
///
/// **Eine eigene Ansicht, weil sie auch ohne Zeichnung dasteht.** Ohne Intervalle zeigt die
/// Vorlage die Horizontkarte weiter - den Satz an der Stelle des Bildes und die Legende
/// darunter (`Fahrplan.tsx:590-640`: Der Satz steht im `else` des Diagramms, die Legende
/// dahinter und ausserhalb). Sie ist dort das Verzeichnis dessen, was das Bild zeigen *wuerde*.
///
/// **Nicht ``Diagrammlegende``** (`Diagramme/Pvverwendung.swift:170`), und das ist kein
/// uebersehener Baustein: der setzt 12/4 Punkte Abstand, 10 Punkte Klotzbreite und eine
/// Schriftgroesse, richtet sich rechts aus und kennt die blassen Baender nicht. Die Legende des
/// Fahrplans hat in der Vorlage eigene Masse (`:598`, `width: 14`), zwei blasse Stuecke fuer die
/// Preisfenster und vier verschiedene Klotzhoehen fuer die Zustaende. Der vorhandene Baustein
/// liesse davon nichts uebrig.
///
/// **Die Abstaende der Vorlage** (`:598`: `gap-x-5 gap-y-2`, also 20 und 8 px). Hier standen
/// 13 und 5 - auf einem Telefon rueckten damit zwoelf Stuecke so dicht aneinander, dass zwei
/// Zeilen wie eine aussahen. Die Schrift waechst am Telefon eine Stufe (`handy.css:190`:
/// 11 px → 12 px), wie jede kleine Schrift einer Berichtsseite dort.
struct Fahrplanlegende: View {
    let stuecke: [Fahrplanbild.Legendenstueck]

    @Environment(\.horizontalSizeClass) private var breite

    var body: some View {
        Umbruchzeile(abstand: 20, zeilenabstand: 8) {
            ForEach(stuecke) { s in
                HStack(spacing: 5) {
                    // Was im Bild gestrichelt ist, ist es auch hier (``Strichmarke``).
                    if s.gestrichelt {
                        Strichmarke(farbe: s.rolle.bildfarbe, gestrichelt: true)
                    } else {
                        RoundedRectangle(cornerRadius: s.dick <= 2 ? 0 : 1.5)
                            .fill(s.rolle.bildfarbe.opacity(s.blass ? 0.32 : 1))
                            .frame(width: 14, height: s.dick)
                    }
                    Text(s.wort)
                        .font(breite == .compact ? Schrift.sans(12) : Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
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
