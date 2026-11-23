import Charts
import DuckCurveKit
import SwiftUI

/// Was aus der Erzeugung wurde: gestapelte Balken je Zeitabschnitt, ablesbar.
///
/// **Warum nicht ``Balkenbild``.** Das Gerippe zeichnet dasselbe Bild, aber ohne Zeiger und mit
/// der Legende *im* Diagramm (`Bericht.swift:164`). Die Vorlage tut beides anders, und zwar mit
/// Begründung: die Legende steht im Kartenkopf, weil ein Farbfleck neben dem Namen aus einer
/// Aufzählung eine Legende macht (`ReportShell.tsx:187-190`), und der Wert eines Balkens ist
/// ablesbar, weil er an einem Monatsbild mit dreißig Balken sonst verloren ist
/// (`charts.ts:58-73`). Hier steht deshalb die Fassung für diese Karte; das gemeinsame
/// ``Balkenbild`` bleibt, wie es ist, und seine zwölf übrigen Aufrufer bleiben verschont.
struct Pvverwendungsbild: View {
    let balken: [Pvbild.Balken]
    var hoehe: CGFloat = 240

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }

    /// Die Farben der drei Reihen.
    ///
    /// `Direkt genutzt` ist die Sonne, `In Batterie` die Speicherfarbe des Diagramms
    /// (`Marken.diagrammSpeicher` #7FA3B3 ist `C.battery` der Vorlage, `palette.ts:36`).
    /// **`Eingespeist` weicht ab:** die Vorlage nimmt dort `rgba(228,236,239,.5)`
    /// (`palette.ts:44`), und dafür gibt es in `Marken` keine Marke. Genommen ist die
    /// nächstliegende vorhandene helle Diagrammfarbe; `Farbe.netzEinspeisung` wäre falsch,
    /// weil sie ein Gelb neben das Gelb der Sonne legt - und der oberste Balkenabschnitt ist
    /// genau der, der sich von der Erzeugung unterscheiden soll.
    static func farbe(_ r: Pvbild.Verwendung) -> Color {
        switch r {
        case .direkt: return Farbe.pv
        case .speicher: return Farbe.diagrammSpeicher
        case .einspeisung: return Farbe.diagrammHaushalt
        }
    }

    static var legende: [Legendenstueck] {
        Pvbild.Verwendung.allCases.map {
            Legendenstueck(wort: $0.name, farbe: farbe($0), hoehe: 8)
        }
    }

    private var reihen: [Pvbild.Verwendung] { Pvbild.Verwendung.allCases }

    private var achsenwoerter: [String] { balken.map(\.wort) }

    private var ablesung: Pvbild.Ablesung? {
        Pvbild.balken(balken, wort: gelesen).map { Pvbild.ablesung($0) }
    }

    var body: some View {
        if balken.isEmpty {
            Leer(satz: "Keine Werte in diesem Zeitraum.")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ablesezeile
                bild
            }
        }
    }

    /// Was unter dem Finger steht: Abschnitt, die Reihen ungleich Null, und die Summe.
    ///
    /// **Die Zeile steht über dem Bild und immer**, auch leer. Ein Streifen, der beim Antippen
    /// erscheint, schiebt das Diagramm um seine eigene Höhe nach unten, und dann liegt der
    /// Finger nicht mehr auf dem Balken, den er gewählt hat.
    private var ablesezeile: some View {
        Group {
            if let a = ablesung {
                // **Eine umbrechende Zeile und kein `HStack`.** Drei Reihennamen mit Werten
                // und dazu die Summe sind auf einer schmalen Karte mehr, als eine Zeile
                // trägt; abgeschnitten wäre die Ablesung nutzlos.
                Umbruchzeile(abstand: 10, zeilenabstand: 2) {
                    Text(a.wort).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                    ForEach(a.zeilen) { z in
                        HStack(spacing: 4) {
                            Text(z.name).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                            Text(z.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                        }
                    }
                    Text(a.summe).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                }
            } else {
                Text("Zum Ablesen über das Bild streichen.")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 16, alignment: .topLeading)
    }

    private var bild: some View {
        Chart {
            inhalt
        }
        .chartForegroundStyleScale(
            domain: reihen.map(\.name), range: reihen.map { Self.farbe($0) }
        )
        // Die Legende steht im Kartenkopf, nicht im Bild: auf 240 Punkten Höhe nimmt sie dort
        // ein Fünftel der Fläche, die dem Diagramm gehört.
        .chartLegend(.hidden)
        .chartXSelection(value: $gelesen)
        .chartYAxis { yAchse }
        .chartXAxis { xAchse }
        .frame(height: hoehe)
    }

    /// Die Balken, Reihe für Reihe von unten, und die gelesene Stelle.
    @ChartContentBuilder private var inhalt: some ChartContent {
        ForEach(balken) { b in
            ForEach(Array(reihen.enumerated()), id: \.offset) { i, r in
                BarMark(
                    x: .value("Zeit", b.wort),
                    y: .value("kWh", i < b.werte.count ? b.werte[i] : 0),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Reihe", r.name))
                // Nur oben gerundet, wie `borderRadius [2,2,0,0]` an der obersten Reihe
                // (`charts.ts:88`): ein Radius an jedem Abschnitt zerschneidet den Stapel.
                .cornerRadius(i == reihen.count - 1 ? 2 : 0)
            }
        }
        if let g = gelesen {
            RuleMark(x: .value("gelesen", g))
                .foregroundStyle(Farbe.text1.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
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

    /// **Nicht jede Beschriftung, sondern die, die passen.** Bei einem Monat sind es dreißig
    /// Wörter, und auf 390 Punkten ist das ein Ziffernstreifen (`charts.ts:72`:
    /// `interval: "auto"` ab mehr als zwölf Buckets).
    @AxisContentBuilder private var xAchse: some AxisContent {
        AxisMarks(values: Achse.beschriftungen(achsenwoerter, hoechstens: schmal ? 6 : 12)) {
            wert in
            AxisValueLabel {
                if let s = wert.as(String.self) {
                    Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

/// Die Legende einer Diagrammkarte, wie sie im Kartenkopf steht.
///
/// **Umbrechend und nicht abgeschnitten.** Die Vorlage lässt dem Beiwerk eines Kartenkopfs
/// genau dafür das `truncate` weg, wenn es ein Element und kein Wort ist („damit eine Legende
/// umbricht statt zu verschwinden“, `ui/Card.tsx:24-26`), und am Telefon rutscht es auf eine
/// eigene Zeile (`handy.css:185`).
///
/// **Sie steht unter dem Kopf und nicht in ihm, und das ist der Rest einer Umgehung.** Solange
/// ``Karte`` ihr `beiwerk` am Telefon neben den Kicker setzte, war dort für drei Farbflecke mit
/// Namen kein Platz; seit ``Karte/beiwerkzeile(_:)`` wäre er es. Die Vorlage setzt die Legende
/// tatsächlich in den Kopf (`reports/PvReport.tsx:103`, `right={<ChartLegend …>}`, ebenso
/// `HouseReport.tsx:64, 68`, `CostReport.tsx:121`, `BatteryReport.tsx:149`). Sie dorthin zu
/// ziehen verschiebt am iPad vier Karten und ist darum nicht Sache dieser Runde - gemeldet.
struct Diagrammlegende: View {
    let stuecke: [Legendenstueck]

    var body: some View {
        Umbruchzeile(abstand: 12, zeilenabstand: 4) {
            ForEach(stuecke) { s in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(s.farbe)
                        .frame(width: 10, height: s.hoehe)
                    Text(s.wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
