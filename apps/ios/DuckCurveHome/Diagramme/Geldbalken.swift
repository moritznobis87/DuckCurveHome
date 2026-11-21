import Charts
import DuckCurveKit
import SwiftUI

/// Gestapelte Balken in Euro - mit der Nulllinie im Bild und ohne eigene Legende.
///
/// **Warum nicht ``Balkenbild``.** Zwei Dinge braucht diese Seite, die es nicht hat, und beide
/// stehen in der Vorlage. Erstens sitzt die Legende **rechts im Kopf der Karte** und nicht
/// über dem Diagrammfeld (`CostReport.tsx:121`, `:154`); ``Balkenbild`` setzt sie fest nach
/// oben links (`Seiten/Bericht.swift`), und damit stünden auf dieser Seite zwei Legenden
/// übereinander. Zweitens muss die Werteachse die **Null** zeigen: die Einspeisevergütung
/// steht unter der Nulllinie, und ein Stapel aus einem positiven und einem negativen Teil ist
/// ohne sichtbare Null nicht lesbar (`charts.ts:393`, `CostReport.tsx:79`).
///
/// **Was fehlt und bewusst fehlt: der Tooltip mit der Summe** (`charts.ts:376-385`). Swift
/// Charts kann eine Berührungsabfrage, aber im ganzen Projekt gibt es dafür an einem
/// Balkendiagramm kein Vorbild, und der im Projekt gewählte Weg ist, die Zahl **daneben**
/// auszuschreiben - so macht es die Pufferbilanz, und so macht es hier die Aufstellung
/// direkt unter dem Bild.
struct Geldbalken: View {
    let reihen: [Gelduebersicht.Balkenreihe]
    var hoehe: CGFloat = 220

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Chart {
            ForEach(reihen) { reihe in
                ForEach(Array(reihe.werte.enumerated()), id: \.offset) { _, wert in
                    BarMark(
                        x: .value("Zeit", wert.wort),
                        y: .value("Euro", wert.wert),
                        stacking: .standard
                    )
                    // **Je Reihe ein Schlüssel.** Ohne `by:` würde Swift Charts aus beiden
                    // Reihen eine machen, und „Einspeisung“ verschwände im Netzstrom.
                    .foregroundStyle(by: .value("Reihe", reihe.name))
                    .cornerRadius(2)
                }
            }
            // Die Nulllinie. In der Vorlage ist sie die Rasterlinie bei 0, die `splitLine`
            // zeichnet; hier steht sie ausdrücklich da, weil eine automatische Achse mit drei
            // Teilungen die Null nicht treffen muss.
            // `0.0` und nicht `0`: an einer Achse, an der `Double` steht, bricht ein `Int`
            // das Diagramm - Swift Charts kennt je Achse genau eine Art.
            RuleMark(y: .value("Euro", 0.0))
                .foregroundStyle(Farbe.linie2)
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartForegroundStyleScale(
            domain: reihen.map(\.name),
            range: reihen.map { Geldfarbe.zu($0.ton) }
        )
        // Die Legende steht im Kartenkopf (``Geldlegende``), nicht am Diagramm.
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: true))
        .chartYAxis {
            // `splitNumber: 3` in der Vorlage (`charts.ts:390`): eine Geldachse mit sechs
            // Stufen liest niemand, und der Platz links gehört dem Bild.
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
        .chartXAxis {
            // Nicht jede Beschriftung, sondern die, die passen - dieselbe Rechnung wie am
            // ``Balkenbild``: bei einem Monat sind es dreissig, und auf 390 Punkten ist das
            // ein Ziffernstreifen.
            AxisMarks(values: Achse.beschriftungen(achsenwoerter, hoechstens: schmal ? 6 : 12)) {
                wert in
                AxisValueLabel {
                    if let s = wert.as(String.self) {
                        Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .frame(height: hoehe)
    }

    /// Die Wörter der x-Achse, in ihrer Reihenfolge und ohne Wiederholung.
    private var achsenwoerter: [String] {
        var gesehen = Set<String>()
        var aus: [String] = []
        for reihe in reihen {
            for w in reihe.werte where !gesehen.contains(w.wort) {
                gesehen.insert(w.wort)
                aus.append(w.wort)
            }
        }
        return aus
    }
}

/// Die Legende einer Karte: Farbfleck plus Name, rechts im Kopf (`ReportShell.tsx:192-203`).
///
/// **Warum sie dort hingehört.** Die Kopfzeilen der Diagramme trugen die Zuordnung früher als
/// grauen Fliesstext; damit lag die Identität der Flächen allein in der Farbe, und wer die
/// Reihenfolge nicht kennt, muss raten. Ein Farbfleck neben dem Namen kostet nichts und macht
/// aus der Aufzählung eine Legende.
///
/// Umbrechend, weil „gebracht“ und „gekostet“ am Telefon neben einer Überschrift stehen und
/// dort nicht beide in eine Zeile passen.
struct Geldlegende: View {
    let reihen: [Gelduebersicht.Balkenreihe]

    var body: some View {
        Umbruchzeile(abstand: 12, zeilenabstand: 4) {
            ForEach(reihen) { reihe in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Geldfarbe.zu(reihe.ton))
                        .frame(width: 10, height: 8)
                    Text(reihe.name)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}
