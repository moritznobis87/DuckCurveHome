import DuckCurveKit
import SwiftUI

/// Eine waagerechte Anteilsleiste: Name und Betrag, darunter ein gefüllter Balken.
///
/// **Es gab im Projekt nichts dafür.** Gesucht nach `ProgressView` und nach einem
/// Fortschrittsbalken: kein Treffer; das Nächste ist die Kapsel der Wirkungszeichnung. Die
/// Vorlage baut die Leiste aus zwei geschachtelten Kästen (`CostReport.tsx:134-140`): eine
/// Spur in `--line-1`, darin der gefüllte Teil in der Serienfarbe, beide `h-2 rounded-full`.
///
/// **Die Länge entscheidet der Kern.** ``Gelduebersicht/ersparnisteile(_:)`` rechnet den
/// Anteil gegen eine **gemeinsame** Skala beider Leisten und rundet auf ganze Prozent - hier
/// wird er nur noch in Punkte umgerechnet. Eine je Zeile normierte Leiste wäre immer voll und
/// würde den Vergleich wegnehmen, um den es geht.
struct Anteilsleiste: View {
    let teil: Gelduebersicht.Ersparnisteil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(teil.wort)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(teil.wert)
                    .font(Schrift.mono(13))
                    .foregroundStyle(Farbe.text1)
                    .lineLimit(1)
            }
            leiste
        }
    }

    /// Acht Punkte hoch, voll gerundet - `h-2 rounded-full` (`CostReport.tsx:136-139`).
    private var leiste: some View {
        GeometryReader { raum in
            ZStack(alignment: .leading) {
                Capsule().fill(Farbe.linie1)
                Capsule()
                    .fill(Geldfarbe.zu(teil.ton))
                    .frame(width: max(0, raum.size.width * teil.anteil))
            }
        }
        .frame(height: 8)
    }
}
