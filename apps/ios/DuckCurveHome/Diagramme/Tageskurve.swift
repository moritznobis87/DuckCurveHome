import Charts
import DuckCurveKit
import SwiftUI

/// Die Kurve des Tages: die Marke selbst.
///
/// Sonne als Flaeche (gemessen voll, Prognose blass und gestrichelt), das Haus als weisse Linie,
/// der Strompreis als Linie auf eigener Flaeche darunter, das Preistief als Band durch beide.
/// Ein Blick zeigt, warum es dieses Haus gibt: mittags ist Strom billig, weil die Sonne scheint.
///
/// **Zwei Flaechen, nicht zwei Achsen.** `DayCurve.tsx` hat das am 10.11.2026 umgestellt, und
/// die Begruendung gilt hier erst recht: Leistung und Preis an zwei Achsen uebereinander ergaben
/// Preisstufen, die Sonne und Haus kreuzten, und vier Mal „PREISTIEF" ineinander. Jetzt steht die
/// Leistung oben, der Preis als eigene niedrige Flaeche darunter, an derselben Zeitachse.
///
/// **Was gestrichelt ist, ist nicht gemessen.** Das ist die einzige Regel, die man kennen muss,
/// um die Zeichnung zu lesen - und sie gilt ausnahmslos.
///
/// **Was Swift Charts hier nicht kann.** Das Dashboard laesst in dieser Zeichnung ziehen und
/// zoomen (`dataZoom`). Swift Charts bringt das nicht mit; nachgebaut ist stattdessen ein
/// Fadenkreuz, das beim Ziehen die Werte einer Stunde zeigt. Das ist die ehrlichere Loesung als
/// ein halbgares Zoomen: an einem Tagesdiagramm mit 24 Stunden ist Ablesen die haeufigere Frage,
/// und dafuer taugt das Fadenkreuz besser als eine Lupe.
struct TageskurveBild: View {
    let kurve: Tageskurve
    /// Welcher Tag - steht in der Legende und entscheidet, was gestrichelt ist.
    let tag: Kurventag
    /// Der Umschalter Gestern/Heute/Morgen.
    ///
    /// **Er steht über dem Bild, links, und die Legende rechts daneben**
    /// (`DayCurve.tsx:153-164`: eine Zeile mit `justify-between`). Die App hatte beide
    /// vertauscht - der Schalter rechts, die Legende links -, und damit stand das Bedienelement
    /// dort, wo das Auge die Erklärung sucht.
    var tagwahl: AnyView?

    @Environment(\.horizontalSizeClass) private var breite

    /// Wo das Fadenkreuz steht, in Stunden. `nil`, solange niemand zieht.
    @State private var faden: Double?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: schmal ? 8 : 4) {
            // **Am Telefon steht die Legende unter dem Bild** (`handy.css:54,266`). Oben
            // drängt sie das Bild nach unten und beantwortet eine Frage, die man erst hat,
            // wenn man die Kurven gesehen hat. An der Wand steht sie oben rechts, neben dem
            // Tagesschalter.
            if schmal {
                if let tagwahl { tagwahl }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    if let tagwahl { tagwahl }
                    Spacer(minLength: 8)
                    legende
                }
            }
            if kurve.leer {
                Leer(
                    satz: tag == .morgen
                        ? "Für morgen liegt noch kein Plan vor."
                        : "Für diesen Tag sind keine Messwerte da.",
                    dazu: tag == .morgen ? "Der Fahrplan wird alle 15 Minuten neu gerechnet." : nil
                )
            } else if schmal {
                leistungsflaeche
                preisflaeche
                zeitachse
            } else {
                // **An der Wand ein Bild mit zwei Achsen** (`DayCurve.tsx`: ein `grid`, links
                // Kilowatt, rechts Cent). Zwei Flächen übereinander sind die Fassung fürs
                // Telefon, wo die Breite für eine zweite Achse fehlt - auf 1100 Punkten
                // trennen sie, was zusammengehört: wann der Preis tief lag und was das Haus
                // in dieser Stunde getan hat.
                wandbild
            }
            if schmal { legende }
        }
    }

    // MARK: - Das Bild der Wandanzeige

    /// Leistung und Preis in einem Bild, mit zwei Achsen.
    ///
    /// **Wie die zweite Achse entsteht.** Swift Charts kennt nur eine Werteachse je Bild. Der
    /// Preis wird darum in die Leistungsachse gerechnet (``Tageskurve/preisAufLeistung(_:)``)
    /// und die rechte Achse zurückgerechnet beschriftet. Die Marken sind die der Preisachse,
    /// nicht die der Leistung - sonst stünden dort krumme Zahlen.
    private var wandbild: some View {
        Chart {
            ForEach(kurve.baender) { b in
                RectangleMark(xStart: .value("von", b.von), xEnd: .value("bis", b.bis))
                    .foregroundStyle(bandfarbe(b).opacity(0.14))
            }
            // Der Vortag zuerst, damit er hinter allem liegt.
            ForEach(kurve.schatten) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "schatten"))
                    .foregroundStyle(Farbe.pvSchatten)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                    .opacity(0.75)
            }
            ForEach(kurve.pv) { p in
                AreaMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "pv"))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Farbe.pv.opacity(0.45), Farbe.pv.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "pvLinie"))
                    .foregroundStyle(Farbe.pv)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            ForEach(kurve.pvErwartet) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "pvErwartet"))
                    .foregroundStyle(Farbe.pv.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            ForEach(kurve.haus) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "haus"))
                    .foregroundStyle(Farbe.last)
                    .lineStyle(StrokeStyle(lineWidth: 1.8))
            }
            ForEach(kurve.waermepumpe) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "wp"))
                    .foregroundStyle(Farbe.waermepumpe.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
            ForEach(kurve.waermeErwartet) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "wpErwartet"))
                    .foregroundStyle(Farbe.waermepumpe.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            // Der Preis, auf die Leistungsachse gerechnet.
            ForEach(kurve.preis) { p in
                LineMark(
                    x: .value("Stunde", p.stunde),
                    y: .value("kW", kurve.preisAufLeistung(p.wert)),
                    series: .value("Reihe", "preis")
                )
                .foregroundStyle(Farbe.preis)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
                .interpolationMethod(.stepEnd)
            }
            ForEach(kurve.preisErwartet) { p in
                LineMark(
                    x: .value("Stunde", p.stunde),
                    y: .value("kW", kurve.preisAufLeistung(p.wert)),
                    series: .value("Reihe", "preisErwartet")
                )
                .foregroundStyle(Farbe.preis.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5, 5]))
                .interpolationMethod(.stepEnd)
            }
            if let jetzt = kurve.jetztStunde {
                RuleMark(x: .value("jetzt", jetzt))
                    .foregroundStyle(Farbe.amberWeich)
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            }
            if let faden {
                RuleMark(x: .value("Faden", faden))
                    .foregroundStyle(Farbe.amber.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: 0...kurve.stunden)
        .chartYScale(domain: 0...kurve.leistungsgrenze)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0.0, through: kurve.stunden, by: 6))) { wert in
                AxisValueLabel {
                    if let d = wert.as(Double.self) {
                        Text(String(format: "%02d:00", Int(d) % 24))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, kurve.leistungsgrenze / 2, kurve.leistungsgrenze]) { wert in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel {
                    if let d = wert.as(Double.self) {
                        Text("\(Formate.zahl(d, stellen: 0)) kW")
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
            // **Die rechte Achse trägt die Preise.** Keine Rasterlinien: zwei Raster
            // übereinander ergeben ein Netz, in dem keines mehr zu lesen ist
            // (`DayCurve.tsx`: `splitLine: { show: false }`).
            AxisMarks(position: .trailing, values: kurve.preismarken.map(kurve.preisAufLeistung)) { wert in
                AxisValueLabel {
                    if let d = wert.as(Double.self) {
                        Text("\(Formate.zahl(kurve.leistungAufPreis(d), stellen: preisstellen)) ct")
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .chartOverlay { feld in
            fadenkreuzflaeche(feld)
        }
    }

    /// Halbe Cent nur, wenn die Schrittweite welche hat - sonst steht „37,5" neben „40,0".
    private var preisstellen: Int {
        kurve.preisgrenzen.schritt < 1 || kurve.preisgrenzen.schritt.truncatingRemainder(dividingBy: 1) != 0 ? 1 : 0
    }

    // MARK: - Leistung

    private var leistungsflaeche: some View {
        Chart {
            // Der Vortag zuerst, damit er hinter allem liegt.
            ForEach(kurve.schatten) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "schatten"))
                    .foregroundStyle(Farbe.pv.opacity(0.26))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))
            }
            ForEach(kurve.baender) { b in
                RectangleMark(
                    xStart: .value("von", b.von),
                    xEnd: .value("bis", b.bis)
                )
                .foregroundStyle(bandfarbe(b).opacity(0.14))
            }
            ForEach(kurve.pv) { p in
                AreaMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "pv"))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Farbe.pv.opacity(0.42), Farbe.pv.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            ForEach(kurve.pvErwartet) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "pvErwartet"))
                    .foregroundStyle(Farbe.pv.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
            }
            ForEach(kurve.haus) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "haus"))
                    .foregroundStyle(Farbe.last)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
            }
            ForEach(kurve.waermepumpe) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "wp"))
                    .foregroundStyle(Farbe.waermepumpe.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
            ForEach(kurve.waermeErwartet) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("kW", p.wert), series: .value("Reihe", "wpErwartet"))
                    .foregroundStyle(Farbe.waermepumpe.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
            }
            if let jetzt = kurve.jetztStunde {
                RuleMark(x: .value("jetzt", jetzt))
                    .foregroundStyle(Farbe.text2)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            if let faden {
                RuleMark(x: .value("Faden", faden))
                    .foregroundStyle(Farbe.amber.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: 0...kurve.stunden)
        .chartYScale(domain: 0...kurve.leistungsgrenze)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { wert in
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
        .frame(height: schmal ? 170 : 230)
        .chartOverlay { feld in
            fadenkreuzflaeche(feld)
        }
    }

    // MARK: - Preis

    private var preisflaeche: some View {
        Chart {
            ForEach(kurve.baender) { b in
                RectangleMark(xStart: .value("von", b.von), xEnd: .value("bis", b.bis))
                    .foregroundStyle(bandfarbe(b).opacity(0.14))
            }
            // Die Nulllinie, wo die Achse unter sie reicht: ein negativer Preis ist eine
            // Nachricht, und ohne die Linie ist nicht zu sehen, wo sie anfaengt.
            if kurve.preisgrenzen.unten < 0 {
                RuleMark(y: .value("null", 0))
                    .foregroundStyle(Farbe.linie2)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            ForEach(kurve.preis) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("ct", p.wert), series: .value("Reihe", "preis"))
                    .foregroundStyle(Farbe.preis)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                    .interpolationMethod(.stepEnd)
            }
            ForEach(kurve.preisErwartet) { p in
                LineMark(x: .value("Stunde", p.stunde), y: .value("ct", p.wert), series: .value("Reihe", "preisErwartet"))
                    .foregroundStyle(Farbe.preis.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
                    .interpolationMethod(.stepEnd)
            }
            if let jetzt = kurve.jetztStunde {
                RuleMark(x: .value("jetzt", jetzt))
                    .foregroundStyle(Farbe.text2)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            if let faden {
                RuleMark(x: .value("Faden", faden))
                    .foregroundStyle(Farbe.amber.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: 0...kurve.stunden)
        .chartYScale(domain: kurve.preisgrenzen.unten...kurve.preisgrenzen.oben)
        .chartXAxis(.hidden)
        .chartYAxis {
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
        .frame(height: schmal ? 72 : 92)
    }

    /// Die Zeitachse, einmal unter beiden Flaechen.
    ///
    /// Eine Achse statt zweier: die beiden Panels haengen an derselben Zeit, und zwei
    /// Beschriftungen uebereinander sagen dasselbe zweimal.
    private var zeitachse: some View {
        Chart {
            // Eine unsichtbare Marke, damit die Flaeche dieselbe Skala bekommt.
            RuleMark(x: .value("x", 0)).foregroundStyle(.clear)
        }
        .chartXScale(domain: 0...kurve.stunden)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: stundenmarken) { wert in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel {
                    if let h = wert.as(Double.self) {
                        Text(String(format: "%02d", Int(h)))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .frame(height: 18)
    }

    /// Alle drei Stunden am Telefon, alle zwei am iPad. 24 Zahlen passen auf 390 Punkte nicht.
    private var stundenmarken: [Double] {
        let schritt: Double = schmal ? 4 : 2
        return Array(stride(from: 0, through: kurve.stunden, by: schritt))
    }

    // MARK: - Fadenkreuz

    private func fadenkreuzflaeche(_ feld: ChartProxy) -> some View {
        GeometryReader { raum in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { griff in
                            // `plotFrame` ist wahlfrei: in einem Zwischenzustand, in dem die
                            // Flaeche noch keine Groesse hat, gibt es keinen. Ein Ausrufezeichen
                            // waere hier ein Absturz beim ersten Zeichnen.
                            guard let rahmen = feld.plotFrame else { return }
                            let x = griff.location.x - raum[rahmen].origin.x
                            guard let h: Double = feld.value(atX: x) else { return }
                            faden = min(kurve.stunden, max(0, h))
                        }
                        .onEnded { _ in faden = nil }
                )
        }
    }

    // MARK: - Legende

    /// Die Legende nennt, was zu sehen ist - und die Kilowattstunden, damit der Vergleich mit
    /// dem Vortag eine Zahl hat.
    ///
    /// `DayCurve.tsx`: „Eine Kurve allein sagt nicht, ob der Tag gut war; erst der Vortag macht
    /// aus 13,4 kWh eine Auskunft."
    private var legende: some View {
        // **Sie darf umbrechen** (`handy.css:266`: `flex-wrap: wrap`). Sechs Einträge auf
        // 390 Punkten sind zwei Zeilen; in einer Zeile sind es sechs abgeschnittene Wörter.
        Umbruchzeile(abstand: 14, zeilenabstand: 5) {
            if let gelesen = abgelesen {
                Text(gelesen)
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.amber)
            } else {
                ForEach(eintraege, id: \.wort) { e in
                    HStack(spacing: 6) {
                        if e.flaeche {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(e.farbe)
                                .frame(width: 14, height: 8)
                                .opacity(0.6)
                        } else {
                            Rectangle()
                                .fill(e.farbe)
                                .frame(width: 14, height: 2)
                                .opacity(e.gestrichelt ? 0.8 : 1)
                        }
                        Text(e.wort)
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .frame(minHeight: 16)
    }

    private struct Legendeneintrag {
        let wort: String
        let farbe: Color
        var gestrichelt = false
        /// Eine Fläche statt eines Strichs: die Sonne und die Preisbänder sind Flächen im
        /// Bild, und ihre Marke soll aussehen wie das, was sie benennt (`DayCurve.tsx:230`).
        var flaeche = false
    }

    private var eintraege: [Legendeneintrag] {
        var aus: [Legendeneintrag] = []
        if !kurve.pv.isEmpty {
            let kwh = kurve.pvKwh.map { " \(Formate.kwh($0))" } ?? ""
            aus.append(Legendeneintrag(wort: "Sonne\(kwh)", farbe: Farbe.pv, flaeche: true))
        }
        if !kurve.pvErwartet.isEmpty {
            aus.append(
                Legendeneintrag(
                    wort: tag == .morgen ? "Sonne erwartet" : "Prognose",
                    farbe: Farbe.pv, gestrichelt: true))
        }
        if !kurve.schatten.isEmpty {
            let kwh = kurve.schattenKwh.map { " \(Formate.kwh($0))" } ?? ""
            aus.append(Legendeneintrag(wort: "gestern\(kwh)", farbe: Farbe.pvSchatten))
        }
        if !kurve.haus.isEmpty {
            aus.append(Legendeneintrag(wort: "Haus", farbe: Farbe.last))
        }
        if !kurve.waermepumpe.isEmpty {
            aus.append(Legendeneintrag(wort: "Wärmepumpe", farbe: Farbe.waermepumpe))
        }
        if !kurve.waermeErwartet.isEmpty {
            aus.append(
                Legendeneintrag(wort: "Wärmepumpe", farbe: Farbe.waermepumpe, gestrichelt: true)
            )
        }
        // **Der Strompreis gehört in die Legende.** Er fehlte: eine zweite Achse rechts und
        // eine Linie im Bild, die niemand benennt (`DayCurve.tsx:147`).
        if !kurve.preis.isEmpty || !kurve.preisErwartet.isEmpty {
            aus.append(
                Legendeneintrag(
                    wort: "Strompreis", farbe: Farbe.preis,
                    gestrichelt: kurve.preis.isEmpty))
        }
        if !kurve.baender.isEmpty {
            // Jede Bandart einmal, nicht einmal je Band - sonst stehen dort vier Mal „Preistief".
            for art in Set(kurve.baender.map(\.art)) {
                let name = kurve.baender.first { $0.art == art }?.name ?? ""
                aus.append(Legendeneintrag(wort: name, farbe: bandfarbe(art), flaeche: true))
            }
        }
        return aus
    }

    /// Was unter dem Finger steht, wenn jemand zieht.
    private var abgelesen: String? {
        guard let faden else { return nil }
        let stunde = Int(faden)
        let minute = Int((faden - Double(stunde)) * 60)
        var teile = [String(format: "%02d:%02d", stunde, minute)]
        if let pv = naechster(kurve.pv.isEmpty ? kurve.pvErwartet : kurve.pv, faden) {
            teile.append("Sonne \(Formate.kwMitEinheit(pv))")
        }
        if let haus = naechster(kurve.haus, faden) {
            teile.append("Haus \(Formate.kwMitEinheit(haus))")
        }
        if let preis = naechster(kurve.preis.isEmpty ? kurve.preisErwartet : kurve.preis, faden) {
            teile.append(Formate.ct(preis))
        }
        return teile.joined(separator: " · ")
    }

    private func naechster(_ reihe: [Kurvenpunkt], _ stunde: Double) -> Double? {
        reihe.min { abs($0.stunde - stunde) < abs($1.stunde - stunde) }?.wert
    }

    private func bandfarbe(_ b: Kurvenband) -> Color {
        bandfarbe(b.art)
    }

    private func bandfarbe(_ art: Kurvenband.Art) -> Color {
        switch art {
        case .guenstig: return Farbe.mist
        case .negativ: return Farbe.amber
        case .teuer: return Farbe.alarm
        }
    }
}

/// Der Umschalter Gestern / Heute / Morgen über der Kurve.
struct Tagwahl: View {
    @Binding var tag: Kurventag

    var body: some View {
        Ansichtswahl(
            ansichten: Kurventag.allCases.map { Ansicht(weg: $0.rawValue, name: $0.name) },
            aktiv: Ansicht(weg: tag.rawValue, name: tag.name)
        ) { a in
            guard let neu = Kurventag(rawValue: a.weg) else { return }
            tag = neu
        }
    }
}

#if DEBUG
    #Preview("Tageskurve, heute") {
        let raster = Vorschau.minutenraster(tag: "2026-02-24")
        let vortag = Vorschau.minutenraster(tag: "2026-02-23")
        let plan = Vorschau.plan(
            ab: Tag.zeitraum("2026-02-24")!.von,
            fenster: [
                Vorschau.fenster("2026-02-24T11:00:00+01:00", "2026-02-24T14:00:00+01:00", .cheap)
            ]
        )
        return TageskurveBild(
            kurve: Tageskurve.baue(
                tag: .heute, raster: raster.punkte, vortag: vortag.punkte,
                plan: plan, jetzt: Vorschau.jetzt
            ),
            tag: .heute
        )
        .padding()
        .background(Farbe.flaeche1)
    }
#endif
