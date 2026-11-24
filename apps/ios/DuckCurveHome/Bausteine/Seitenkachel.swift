import DuckCurveKit
import SwiftUI

/// Eine Seite als Kachel: oben ihr Zeichen in der Farbe ihrer Sache und rechts der Zustand,
/// darunter der Name, die Leitzahl groß mit kleiner Einheit, ein Wort dazu und am Fuß das kleine
/// Bild (`Bereichsuebersicht.tsx`, `Kachel`).
///
/// Herausgelöst aus ``Bereichsuebersicht``, weil „Einstellen“ die Seiten des Systems mit
/// derselben Kachel zeigt (``EinstellenSeite``).
struct Seitenkachel: View {
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    let seite: Reiter
    /// Die Karte des Dienstes zu dieser Seite; `nil`, solange keine da ist.
    let stand: UebersichtKarteOut?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        let ampel = stand.map { Hausgeraet.Ampel($0.ampel?.rawValue) }
        let leitzahl = stand?.leitzahlDe.flatMap { $0.isEmpty ? nil : Leitzahl($0) }
        let farbe = seite.farbe.farbe
        let rundung: CGFloat = schmal ? 14 : Marken.radius3
        return Button {
            wegweiser.gehe(seite.weg)
            wegweiser.merkeReiter()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center) {
                    Zeichen(seite.zeichen, groesse: 22, farbe: farbe)
                        .frame(width: 36, height: 36)
                        .background(farbe.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    if let ampel {
                        Zustandszeichen(ampel: ampel)
                    }
                }
                .padding(.bottom, 12)
                Text(seite.name)
                    .font(Schrift.sansHalbfett(14, relativeTo: .subheadline))
                    .foregroundStyle(Farbe.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let leitzahl {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(leitzahl.zahl)
                            .font(Schrift.mono(schmal ? 26 : 28, relativeTo: .title))
                            .foregroundStyle(Farbe.text1)
                            .monospacedDigit()
                        if !leitzahl.einheit.isEmpty {
                            Text(leitzahl.einheit)
                                .font(Schrift.mono(14, relativeTo: .subheadline))
                                .foregroundStyle(Farbe.text2)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                unterzeile(seite, stand: stand, ampel: ampel, hatZahl: leitzahl != nil)
                Spacer(minLength: 0)
                // Das kleine Bild am Fuß der Kachel, in der Farbe der Sache
                // (`globals.css`, `.uebersicht-bild`).
                if let bild = stand?.bild {
                    Kachelbildzeichnung(bild: bild, farbe: farbe)
                }
            }
            .padding(EdgeInsets(top: 13, leading: 14, bottom: 14, trailing: 14))
            .frame(maxWidth: .infinity, minHeight: schmal ? 170 : 176, maxHeight: .infinity, alignment: .topLeading)
            .background {
                // Ein Hauch der Farbe der Sache aus der Ecke des Zeichens; die Fläche bleibt die
                // der Karten (`globals.css`, `.uebersicht-karte`).
                ZStack {
                    Farbe.flaeche1
                    RadialGradient(
                        colors: [farbe.opacity(0.13), .clear],
                        center: .topLeading, startRadius: 0, endRadius: 190)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: rundung, style: .continuous)
                    .strokeBorder(randfarbe(ampel) ?? Farbe.linie1, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: rundung, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(seite.beschreibung ?? "")
    }

    /// Die Zeile unter der Zahl: der Grund einer Ampel, die nicht gut ist, sonst das Wort zur
    /// Zahl. Eine Kachel ohne Zahl zeigt den Satz der Seite, damit sie nicht leer dasteht.
    @ViewBuilder private func unterzeile(
        _ seite: Reiter, stand: UebersichtKarteOut?, ampel: Hausgeraet.Ampel?, hatZahl: Bool
    ) -> some View {
        if let grund = stand?.grundDe, !grund.isEmpty {
            zeile(grund, farbe: grundfarbe(ampel))
        } else if let dazu = stand?.dazuDe, !dazu.isEmpty {
            zeile(dazu, farbe: Farbe.text3)
        } else if !hatZahl, let satz = seite.beschreibung {
            zeile(satz, farbe: Farbe.text3)
        }
    }

    private func zeile(_ wort: String, farbe: Color) -> some View {
        Text(wort)
            .font(Schrift.sans(12.5, relativeTo: .caption))
            .foregroundStyle(farbe)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    /// Eine Kachel, die etwas zu sagen hat, hebt sich mit ihrem Rand ab (`globals.css`,
    /// `.uebersicht-karte[data-ampel]`): weicher Bernstein für einen Hinweis, Alarmrot für eine
    /// Störung. Alle anderen behalten die feine Linie.
    private func randfarbe(_ ampel: Hausgeraet.Ampel?) -> Color? {
        switch ampel {
        case .warn: return Farbe.amberWeich.opacity(0.45)
        case .schlecht: return Farbe.alarm.opacity(0.6)
        default: return nil
        }
    }

    /// Die Schrift des Grundes: der Warnton für einen Hinweis, Alarm als Schrift für eine
    /// Störung, Grau, wo es nur keine Auskunft gibt.
    private func grundfarbe(_ ampel: Hausgeraet.Ampel?) -> Color {
        switch ampel {
        case .schlecht: return Farbe.alarmText
        case .aus: return Farbe.text3
        default: return Farbe.amberWeich
        }
    }
}
