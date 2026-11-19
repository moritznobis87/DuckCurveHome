import DuckCurveKit
import SwiftUI

/// Die Abweichung je Raum und Viertelstunde – die Hauptkarte der Heizkreise.
///
/// **Warum sie wichtiger ist als die Temperaturkurven.** Zehn Räume zwischen 18 und 21 °C
/// ergeben als Kurven ein flaches Band, in dem nichts zu erkennen ist. Interessant ist nicht,
/// wie warm ein Raum ist, sondern wie weit er von *seinem* Ziel weg ist – und welcher Raum
/// zuerst abfällt, denn der bestimmt die nötige Vorlauftemperatur für alle. Diese Karte
/// stand im Dashboard (`rooms/RoomsReport.tsx`) und fehlte in der App.
///
/// **Drei Arten von Feld, und das ist der Kern der Sache.** Ein gemessener Wert bekommt eine
/// Farbe aus der fünfstufigen Skala. Ein Fenster ohne Messwert wird schraffiert – nicht grau,
/// denn Grau wäre eine sechste Stufe derselben Skala und würde als Messung gelesen. Ein
/// Fenster, das noch nicht an der Reihe war, bekommt einen eigenen, sehr blassen Ton: sonst
/// wäre der halbe Tag schraffiert und die paar Felder, auf die es ankommt, verschwänden darin.
///
/// Die Rechnung dahinter steht im Kern (`Raumabweichung`) und ist dort geprüft – auch die
/// Grenzen der Skala, die hier einmal zu eng waren.
struct Abweichungsmatrix: View {
    let verlauf: RoomHistoryOut
    /// Das erste Fenster, das noch nicht gewesen ist.
    let bisStelle: Int?

    private let zeilenhoehe: CGFloat = 22
    private let namensbreite: CGFloat = 104
    private let mittelbreite: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Je Raum und Viertelstunde die Abweichung vom Zielwert. "
                + "Der Raum, der zuerst abfällt, bestimmt die nötige Vorlauftemperatur für alle.")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(verlauf.rooms.enumerated()), id: \.offset) { _, raum in
                zeile(raum)
            }
            achse
            legende
        }
    }

    private func felder(_ raum: RoomSeriesOut) -> [Raumabweichung.Feld] {
        Raumabweichung.felder(
            ist: raum.tempC, soll: raum.setpointC, versatz: raum.offsetK, bisStelle: bisStelle
        )
    }

    private func zeile(_ raum: RoomSeriesOut) -> some View {
        let f = felder(raum)
        let m = Raumabweichung.mittel(f)
        return HStack(spacing: 8) {
            Text(raum.name)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: namensbreite, alignment: .leading)
            Canvas { gestalt, groesse in
                male(f, in: &gestalt, groesse: groesse)
            }
            .frame(height: zeilenhoehe - 4)
            Text(m.map { "\($0 > 0 ? "+" : "")\(Formate.zahl($0, stellen: 1))" } ?? Formate.leer)
                .font(Schrift.zahlKlein)
                .foregroundStyle(m == nil ? Farbe.text3 : Farbe.text1)
                .frame(width: mittelbreite, alignment: .trailing)
        }
        .frame(height: zeilenhoehe)
    }

    private func male(
        _ felder: [Raumabweichung.Feld], in g: inout GraphicsContext, groesse: CGSize
    ) {
        guard !felder.isEmpty else { return }
        let breite = groesse.width / CGFloat(felder.count)
        for (i, f) in felder.enumerated() {
            let kasten = CGRect(x: CGFloat(i) * breite, y: 0,
                                width: breite + 0.5, height: groesse.height)
            switch f {
            case .wert(let k):
                g.fill(Path(kasten), with: .color(Color(Marken.abweichungsfarbe(kelvin: k))))
            case .nochNicht:
                g.fill(Path(kasten), with: .color(.white.opacity(0.035)))
            case .keinWert:
                // Schraffur statt Grau: sie gehoert sichtbar nicht zur Skala, und genau das
                // ist die Aussage.
                g.fill(Path(kasten), with: .color(.white.opacity(0.04)))
                var schraffur = Path()
                var x = kasten.minX - kasten.height
                while x < kasten.maxX {
                    schraffur.move(to: CGPoint(x: x, y: kasten.maxY))
                    schraffur.addLine(to: CGPoint(x: x + kasten.height, y: kasten.minY))
                    x += 3
                }
                g.clip(to: Path(kasten))
                g.stroke(schraffur, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
            }
        }
    }

    private var achse: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: namensbreite)
            HStack {
                ForEach([0, 6, 12, 18], id: \.self) { stunde in
                    Text(String(format: "%02d", stunde))
                        .font(Schrift.achse).foregroundStyle(Farbe.text3)
                    if stunde != 18 { Spacer() }
                }
                Spacer()
                Text("24").font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
            Text("Mittel")
                .font(Schrift.achse).foregroundStyle(Farbe.text3)
                .frame(width: mittelbreite, alignment: .trailing)
        }
    }

    private var legende: some View {
        HStack(spacing: 10) {
            ForEach(Array(["−1,5", "−0,5", "am Ziel", "+0,5", "+1,5"].enumerated()), id: \.offset) {
                i, marke in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(Marken.abweichung[i]))
                        .frame(width: 12, height: 10)
                    Text(marke).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
        .padding(.top, 2)
    }
}
