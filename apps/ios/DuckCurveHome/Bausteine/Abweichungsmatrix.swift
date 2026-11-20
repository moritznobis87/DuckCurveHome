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

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    /// Die Zelle ist 20 Punkte hoch, die Zeile drei darüber (`RoomsReport.tsx:486`,
    /// `gap-[3px]`).
    private let zellenhoehe: CGFloat = 20
    private var namensbreite: CGFloat { schmal ? 76 : 128 }
    private let mittelbreite: CGFloat = 62
    /// Zwei Punkte zwischen zwei Viertelstunden, am Telefon einer.
    ///
    /// **Das ist der Unterschied zwischen einem Raster und einem Balken.** Die Felder standen
    /// hier ohne Lücke aneinander und überlappten sich sogar um einen halben Punkt - aus
    /// sechsundneunzig Viertelstunden wurde ein durchgehender Streifen, und man konnte nicht
    /// mehr sehen, dass jede Zelle eine eigene Messung ist.
    private var luecke: CGFloat { schmal ? 1 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(verlauf.rooms.enumerated()), id: \.offset) { _, raum in
                zeile(raum)
            }
            achse
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
            // **Rechtsbündig an das Band gesetzt** (`RoomsReport.tsx:489`): die Namen sind
            // verschieden lang, und links gesetzt beginnt jedes Band woanders.
            Text(raum.name)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: namensbreite, alignment: .trailing)
            Canvas { gestalt, groesse in
                male(f, in: &gestalt, groesse: groesse)
            }
            .frame(height: zellenhoehe)
            // Die Einheit gehört dazu: „+1,4" ist eine Zahl, „+1,4 K" ist eine Abweichung.
            Text(m.map(Raumabweichung.kelvin) ?? Formate.leer)
                .font(Schrift.zahlKlein)
                .foregroundStyle(m == nil ? Farbe.text3 : Farbe.text1)
                .frame(width: mittelbreite, alignment: .trailing)
        }
    }

    private func male(
        _ felder: [Raumabweichung.Feld], in g: inout GraphicsContext, groesse: CGSize
    ) {
        guard !felder.isEmpty else { return }
        let n = CGFloat(felder.count)
        let breite = max(1, (groesse.width - (n - 1) * luecke) / n)
        for (i, f) in felder.enumerated() {
            let kasten = CGRect(x: CGFloat(i) * (breite + luecke), y: 0,
                                width: breite, height: groesse.height)
            let form = Path(roundedRect: kasten, cornerRadius: 2)
            switch f {
            case .wert(let k):
                g.fill(form, with: .color(Color(Marken.abweichungsfarbe(kelvin: k))))
            case .nochNicht:
                g.fill(form, with: .color(.white.opacity(0.035)))
            case .keinWert:
                // Schraffur statt Grau: sie gehoert sichtbar nicht zur Skala, und genau das
                // ist die Aussage.
                g.fill(form, with: .color(.white.opacity(0.04)))
                var schraffur = Path()
                var x = kasten.minX - kasten.height
                while x < kasten.maxX {
                    schraffur.move(to: CGPoint(x: x, y: kasten.maxY))
                    schraffur.addLine(to: CGPoint(x: x + kasten.height, y: kasten.minY))
                    x += 3
                }
                g.clip(to: form)
                g.stroke(schraffur, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
            }
        }
    }

    private var achse: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: namensbreite)
            HStack {
                ForEach([0, 6, 12, 18], id: \.self) { stunde in
                    Text(stundenwort(stunde))
                        .font(Schrift.achse).foregroundStyle(Farbe.text3)
                    if stunde != 18 { Spacer() }
                }
                Spacer()
                Text(stundenwort(24)).font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
            Text("Mittel")
                .font(Schrift.achse).foregroundStyle(Farbe.text3)
                .frame(width: mittelbreite, alignment: .trailing)
        }
    }

    /// An der Wand „06:00", am Telefon „06" (`handy.css:384`).
    private func stundenwort(_ stunde: Int) -> String {
        schmal ? String(format: "%02d", stunde) : String(format: "%02d:00", stunde)
    }

}
