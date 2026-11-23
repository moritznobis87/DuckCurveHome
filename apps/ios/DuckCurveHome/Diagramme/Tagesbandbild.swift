import Charts
import DuckCurveKit
import SwiftUI

/// Das Tagesband der Wiedergabe: der Tag als Zeile, zum Ablesen.
///
/// Fünf Flächen untereinander auf einer Zeitachse, jede mit ihrer eigenen Größe und Einheit:
/// Sonne und Netz in Kilowatt, der Preis in Cent, dann drei Zeitleisten - was der Fahrplan für die
/// Wärmepumpe vorsah, was sie tat, und der Ofen. **Kein gemeinsames Gitter für verschiedene
/// Einheiten** (`Tagesband.tsx:14-18`): „Kilowatt und Cent auf zwei Achsen desselben Bildes läsen
/// sich als Zusammenhang ihrer Kreuzungspunkte, und die sind Zufall der Skalierung.“
///
/// **Absicht und Ausführung stehen als Nachbarn**, dieselbe Farbe, die Absicht blass und flacher.
/// „Wo die blasse Zeile einen Balken hat und die kräftige darunter keinen, wollte der Fahrplan und
/// die Maschine nicht - das ist die Frage, was der Freigabekontakt wirklich auslöst, als Bild“
/// (`Tagesband.tsx:20-24`).
///
/// **Fünf Flächen, nicht eine mit fünf Achsen.** Swift Charts kennt keine mehrfachen Gitter wie
/// ECharts; der Weg im Projekt ist derselbe wie beim Fahrplan: „Sie teilen die Zeitachse, und jede
/// Fläche trägt ihren Maßstab“ (`Fahrplanzeichnung.swift:13-16`). Alle Flächen bekommen dieselbe
/// `chartXScale` gesetzt, sonst fallen sie auseinander - derselbe Fehler ist im Dashboard schon
/// passiert.
///
/// **Der Spielkopf steht in jeder Fläche.** ECharts verbindet die Gitter mit einem Achsenzeiger
/// (`Tagesband.tsx:169`); hier ist er je Fläche ein eigener `RuleMark`, „sonst endete er über den
/// Zeitleisten“ (`Tagesband.tsx:149`).
struct Tagesbandbild: View {
    let bild: Wiedergabebild
    let daten: AnlageReplayOut
    let stelle: Int
    /// Ein Griff ins Band springt auf das zeitlich nächste Bild - **kein interpolierter Wert**,
    /// denn „zwischen zwei Bildern liegt nichts, was gemessen wäre“ (`Tagesband.tsx:181-182`).
    var aufSprung: (Int) -> Void

    /// Wo der Finger auf der Zeitachse steht. Alle Flächen teilen diese Auswahl, wie beim
    /// Fahrplan (`Fahrplanzeichnung.swift:152`).
    @State private var gewaehlt: Date?

    /// Die Breite der Flächennamen links. In der Vorlage sind es 66 Punkte bis zum Gitter
    /// (`Tagesband.tsx:29`); hier teilen sich Name und Achsenbeschriftung diesen Platz.
    private let namensbreite: CGFloat = 46

    private var zeitbereich: ClosedRange<Date> {
        bild.bandspanne ?? bild.von...bild.bis
    }

    private var kopfzeit: Date? {
        guard stelle >= 0, stelle < bild.zeitpunkte.count else { return nil }
        return bild.zeitpunkte[stelle]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            fahne
            ForEach(bild.bandflaechen) { flaeche in
                bandzeile(flaeche)
            }
        }
        .onChange(of: gewaehlt) { _, neu in
            // Ein Griff ins Band setzt die Stelle; die Seite hält darüber die Wiedergabe an.
            guard let neu, let i = bild.naechsteStelle(zu: neu) else { return }
            aufSprung(i)
        }
    }

    // MARK: - Die Fahne

    /// Was zu diesem Augenblick gilt, als Block über dem Band.
    ///
    /// **Abweichung von der Vorlage, und mit Grund.** Dort ist das ein Hinweisfenster unter dem
    /// Zeiger (`Tagesband.tsx:170-207`). Am Telefon gibt es kein Überfahren: Zeigen und Greifen
    /// sind derselbe Finger, und ein Fenster, das dem Finger folgt, steht unter ihm. Also steht
    /// derselbe Inhalt fest über dem Band und gilt für den Spielkopf - dieselbe Entscheidung wie
    /// bei der Auskunft des Fahrplans (`Fahrplanzeichnung.swift:78-82`). Ein Griff ins Band setzt
    /// den Spielkopf, also ändert sich der Block genauso wie dort die Fahne.
    @ViewBuilder private var fahne: some View {
        if let f = bild.fahne(daten, stelle: stelle) {
            VStack(alignment: .leading, spacing: 2) {
                Text(f.zeit).font(Schrift.zahlKlein).foregroundStyle(Farbe.amberWeich)
                ForEach(f.zeilen) { z in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let marke = z.marke {
                            RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
                                .fill(Tagesbildfarben.farbe(marke))
                                .frame(width: 8, height: 8)
                        }
                        Text(z.satz)
                            .font(Schrift.winzig)
                            // Der eingerückte Satz zur Absicht ist leiser: er erklärt die Zeile
                            // über ihm und ist keine eigene Größe (`Tagesband.tsx:204`).
                            .foregroundStyle(z.eingerueckt ? Farbe.text3 : Farbe.text1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, z.eingerueckt ? 14 : 0)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Eine Fläche

    private func bandzeile(_ flaeche: Wiedergabebild.Bandflaeche) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Die Farbe gehört den Marken; farbige Schrift wäre Kennung ohne Lesbarkeit
            // (`Tagesband.tsx:155-168`).
            Text(flaeche.name)
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
                .frame(width: namensbreite, alignment: .trailing)
                .padding(.top, max(0, flaeche.hoehe / 2 - 7))
            diagramm(flaeche)
        }
    }

    /// Welche Marken in welche Fläche gehören.
    ///
    /// **Die Fallunterscheidung steht hier und nicht im Inhalt der Zeichnung.** Fünf Flächen mit
    /// verschiedenen Marken sind fünf verschiedene `Chart`, und der Rahmen darum ist für alle
    /// derselbe - genau die Aufteilung, die der Fahrplan schon hat
    /// (`Fahrplanzeichnung.swift:120-130`).
    @ViewBuilder private func diagramm(_ flaeche: Wiedergabebild.Bandflaeche) -> some View {
        switch flaeche.art {
        case .kw: rahmen(flaeche) { kwbild }
        case .preis: rahmen(flaeche) { preisbild }
        case .geplant: rahmen(flaeche) { absichtsbild }
        case .gelaufen: rahmen(flaeche) { laufbild }
        case .ofen: rahmen(flaeche) { ofenbild }
        }
    }

    /// Der Rahmen einer Fläche: dieselbe Zeitachse, dieselbe Auswahl, der Spielkopf darin.
    private func rahmen<Inhalt: ChartContent>(
        _ flaeche: Wiedergabebild.Bandflaeche, @ChartContentBuilder inhalt: () -> Inhalt
    ) -> some View {
        let mitZeitachse = bild.bandflaechen.last?.art == flaeche.art
        return Chart {
            inhalt()
            spielkopf
        }
        .chartXScale(domain: zeitbereich)
        .chartYScale(domain: spanne(flaeche))
        .chartXSelection(value: $gewaehlt)
        .chartXAxis {
            // Die Zeitachse steht nur unter der letzten Fläche: fünfmal dieselben Uhrzeiten sind
            // viermal Lärm (`Tagesband.tsx:210`).
            AxisMarks(values: .stride(by: .hour, count: 6)) { wert in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                if mitZeitachse, let t = wert.as(Date.self) {
                    AxisValueLabel {
                        // **Immer die Uhrzeit**, und in der Zeit des Hauses: „zwischen ‚9‘ und
                        // ‚04:00‘ liest niemand eine Zeitachse“ (`Tagesband.tsx:110-113`).
                        Text(Formate.hhmm(t)).font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { _ in
                if istKurve(flaeche) {
                    AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                    AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
        .frame(height: flaeche.hoehe)
    }

    /// Ob eine Fläche eine Kurve mit Zahlen trägt oder eine Zeitleiste ist.
    private func istKurve(_ flaeche: Wiedergabebild.Bandflaeche) -> Bool {
        flaeche.art == .kw || flaeche.art == .preis
    }

    /// Die Spanne der y-Achse.
    ///
    /// Die Zeitleisten laufen von 0 bis 1 und zeigen keine Achse; die beiden Kurven lässt
    /// Swift Charts selbst messen. **Eine Achsenart je Diagramm**: überall `Double`, nie `Int`
    /// daneben.
    private func spanne(_ flaeche: Wiedergabebild.Bandflaeche) -> ClosedRange<Double> {
        switch flaeche.art {
        case .kw: return kwSpanne
        case .preis: return preisSpanne
        case .geplant, .gelaufen, .ofen: return 0...1
        }
    }

    /// Sonne und Netz in einer Fläche, also eine Achse für beide - und das Netz kann negativ
    /// sein, wenn eingespeist wird.
    private var kwSpanne: ClosedRange<Double> {
        let werte = (bild.sonne + bild.netz).compactMap(\.wert).filter(\.isFinite)
        let unten = min(0, werte.min() ?? 0)
        let oben = max(unten + 1, werte.max() ?? 1)
        return unten...oben
    }

    /// Der Preis beginnt nicht bei null, wenn er negativ wird - negative Preise sind der Grund
    /// für das halbe Projekt.
    private var preisSpanne: ClosedRange<Double> {
        guard let p = bild.preisspanne else { return 0...1 }
        let unten = min(0, p.lowerBound)
        let oben = max(unten + 1, p.upperBound)
        return unten...oben
    }

    // MARK: - Der Inhalt einer Fläche

    /// Die Sonne als geglättete Fläche, das Netz als dünne Linie.
    ///
    /// **Je Reihe ein `series:`-Schlüssel**, sonst zieht Swift Charts aus beiden eine Linie.
    /// `connectNulls` gibt es hier nicht - eine Lücke entsteht dadurch, dass der Punkt fehlt,
    /// und das ist der Grund, warum `wert` wahlfrei ist.
    @ChartContentBuilder private var kwbild: some ChartContent {
        ForEach(bild.sonne) { p in
            if let kw = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("kW", kw))
                    .foregroundStyle(Farbe.pv.opacity(0.16))
                    .interpolationMethod(.catmullRom)
            }
        }
        ForEach(bild.sonne) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "Sonne")
                )
                .foregroundStyle(Farbe.pv)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
        ForEach(bild.netz) { p in
            if let kw = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("kW", kw),
                    series: .value("Reihe", "Netz")
                )
                .foregroundStyle(Farbe.preis)
                .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
        }
    }

    /// Der Preis als Treppe: ein Viertelstundenpreis gilt bis zum nächsten und steigt nicht
    /// schräg dorthin (`Tagesband.tsx:233`, `step: "end"`).
    @ChartContentBuilder private var preisbild: some ChartContent {
        ForEach(bild.preis) { p in
            if let ct = p.wert {
                AreaMark(x: .value("Zeit", p.zeit), y: .value("ct", ct))
                    .foregroundStyle(Farbe.preis.opacity(0.14))
                    .interpolationMethod(.stepEnd)
            }
        }
        ForEach(bild.preis) { p in
            if let ct = p.wert {
                LineMark(
                    x: .value("Zeit", p.zeit), y: .value("ct", ct),
                    series: .value("Reihe", "Preis")
                )
                .foregroundStyle(Farbe.preis)
                .lineStyle(StrokeStyle(lineWidth: 1.4))
                .interpolationMethod(.stepEnd)
            }
        }
    }

    /// Die Absicht: blass gefüllt mit einem Rand in der Farbe der Ausführung.
    ///
    /// **Die Blässe kommt aus der Füllfarbe, nicht aus der Deckkraft der ganzen Marke** - „sonst
    /// verblasste der Rand mit, und er ist das, was die Absicht kenntlich macht“
    /// (`Tagesband.tsx:144-147`). In Swift Charts heißt das: ein gefülltes `RectangleMark` und
    /// darüber ein zweites, nur umrissenes.
    @ChartContentBuilder private var absichtsbild: some ChartContent {
        ForEach(Array(bild.geplanteBalken.enumerated()), id: \.offset) { _, lauf in
            RectangleMark(
                xStart: .value("von", lauf.von), xEnd: .value("bis", lauf.bis),
                yStart: .value("u", 0.0), yEnd: .value("o", 1.0)
            )
            .foregroundStyle(Farbe.waermepumpe.opacity(0.2))
        }
        ForEach(Array(bild.geplanteBalken.enumerated()), id: \.offset) { _, lauf in
            RuleMark(
                xStart: .value("von", lauf.von), xEnd: .value("bis", lauf.bis),
                y: .value("o", 1.0)
            )
            .foregroundStyle(Farbe.waermepumpe)
            .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }

    @ChartContentBuilder private var laufbild: some ChartContent {
        ForEach(Array(bild.gelaufeneBalken.enumerated()), id: \.offset) { _, lauf in
            RectangleMark(
                xStart: .value("von", lauf.von), xEnd: .value("bis", lauf.bis),
                yStart: .value("u", 0.0), yEnd: .value("o", 1.0)
            )
            .foregroundStyle(Farbe.waermepumpe)
        }
    }

    @ChartContentBuilder private var ofenbild: some ChartContent {
        ForEach(Array(bild.ofenbalken.enumerated()), id: \.offset) { _, lauf in
            RectangleMark(
                xStart: .value("von", lauf.von), xEnd: .value("bis", lauf.bis),
                yStart: .value("u", 0.0), yEnd: .value("o", 1.0)
            )
            .foregroundStyle(Farbe.ofen)
        }
    }

    /// Der weiße Strich auf dem Bild, das gerade im Schema steht.
    @ChartContentBuilder private var spielkopf: some ChartContent {
        if let t = kopfzeit {
            RuleMark(x: .value("Bild", t))
                .foregroundStyle(Farbe.papier)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
    }
}
