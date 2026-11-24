import DuckCurveKit
import SwiftUI

/// Eine Karte auf „Mein Zugang“: Zeichen in einer getönten Fläche, Titel und Satz, darunter der
/// Inhalt (`globals.css`, `.konto-karte`). Dieselbe Bildsprache wie die Kacheln der Übersichten.
struct Kontokarte<Inhalt: View>: View {
    let art: Kontoworte.Kartenart
    @ViewBuilder let inhalt: () -> Inhalt

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Zeichen(art.zeichen, groesse: 20, farbe: Farbe.mist)
                    .frame(width: 36, height: 36)
                    .background(Farbe.mist.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(art.titel)
                        .font(Schrift.sansHalbfett(16, relativeTo: .headline))
                        .foregroundStyle(Farbe.text1)
                    Text(art.satz)
                        .font(Schrift.sans(13, relativeTo: .footnote))
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            inhalt()
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Farbe.flaeche1
                RadialGradient(
                    colors: [Farbe.mist.opacity(0.10), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 260)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }
}

/// Ein runder Knopf wie im Dashboard (`globals.css`, `.zugang-knopf`): hervorgehoben in Bernstein,
/// sonst mit feinem Rand, leise ohne Rand.
struct Zugangsknopf: View {
    enum Art { case hervor, normal, leise }

    let wort: String
    var art: Art = .normal
    var klein = false
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Text(wort)
                .font(art == .hervor ? Schrift.sansHalbfett(klein ? 13 : 14) : Schrift.sans(klein ? 13 : 14))
                .foregroundStyle(art == .hervor ? Farbe.deep : art == .leise ? Farbe.text3 : Farbe.text1)
                .padding(.horizontal, klein ? 12 : 18)
                .padding(.vertical, klein ? 6 : 10)
                .background(art == .hervor ? Farbe.amber : Color.clear)
                .overlay(
                    Capsule().strokeBorder(
                        art == .hervor ? Farbe.amber : art == .leise ? Color.clear : Farbe.linie2,
                        lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
