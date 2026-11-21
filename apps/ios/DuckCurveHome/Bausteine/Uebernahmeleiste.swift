import DuckCurveKit
import SwiftUI

/// Die Leiste am unteren Rand: sie steht da, solange es etwas zu übernehmen gibt
/// (`Regler.tsx:285-312`, `globals.css:1021`).
///
/// **Zwei Knopfdrücke mit einer Liste dazwischen.** Erst „Übernehmen …“, dann die Übersicht mit
/// dem Satz „Diese Änderungen gehen an den Regler der Wärmepumpe und bleiben dort stehen:“ und
/// jeder Zeile als „alt → neu“, dann „Jetzt stellen“. Das ist an einer Heizungsanlage keine
/// Umständlichkeit: eine Heizkurvensteilheit, die versehentlich von 0,4 auf 1,4 geht, merkt man
/// im Februar an der Rechnung.
///
/// **Sie ersetzt die Nachfrage je Griff.** Die App fragte bis zum 20.11.2026 nach jedem Griff
/// einzeln mit einem `Alert` und sendete dann sofort. Wer die Kurve zieht, bewegt Steilheit und
/// Verschiebung aber in einer Bewegung – drei Alerts hintereinander wären unbenutzbar. Die
/// Vorsicht wird dadurch nicht kleiner, sondern größer: sie fragt einmal nach **allem**, mit
/// alten und neuen Werten in einer Liste.
struct Uebernahmeleiste: View {
    let offen: [Reglerpult.Aenderung]
    @Binding var uebersicht: Bool
    let laeuft: Bool
    let verwerfen: () -> Void
    let uebernehmen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if uebersicht {
                liste
            } else {
                Text(Reglerpult.entwurfssatz(offen.count))
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text1)
            }
            knoepfe
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farbe.deep, in: umriss)
        // `color-mix(in srgb, deep 92%, amber)` (`globals.css:1021`): die Leiste gehört zur
        // Seite und nicht auf sie - ein Hauch Bernstein im Dunkel, kein eigener Ton.
        .background(Farbe.amber.opacity(0.08), in: umriss)
        .overlay(umriss.strokeBorder(Farbe.amber.opacity(0.55), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.45), radius: 12, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Änderungen übernehmen")
    }

    private var liste: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Reglerpult.uebersichtssatz)
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(offen) { a in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    Text(a.wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    Spacer(minLength: 6)
                    Text(a.spanne).font(Schrift.zahlKlein).foregroundStyle(Farbe.amber)
                }
            }
        }
    }

    private var knoepfe: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            leiserKnopf(uebersicht ? "Zurück" : "Verwerfen") {
                if uebersicht { uebersicht = false } else { verwerfen() }
            }
            hauptknopf
        }
    }

    private func leiserKnopf(_ wort: String, tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Text(wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(laeuft)
        .opacity(laeuft ? 0.5 : 1)
    }

    /// **Der Knopf, der sendet, sieht auch so aus**: gefüllt in Bernstein mit dunkler Schrift
    /// (`globals.css:938`). Daneben steht nichts Gleichwertiges – es gibt auf dieser Seite genau
    /// eine Stelle, an der etwas an den Bus geht.
    private var hauptknopf: some View {
        Button {
            if uebersicht { uebernehmen() } else { uebersicht = true }
        } label: {
            Text(laeuft ? "Wird gesendet …" : (uebersicht ? "Jetzt stellen" : "Übernehmen …"))
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.petrol)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Farbe.amber, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(laeuft)
        .opacity(laeuft ? 0.5 : 1)
    }

    private var umriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }
}
