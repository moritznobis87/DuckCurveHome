import DuckCurveKit
import SwiftUI

/// Die Karte „Pult“: je stellbare Zahl ein Kanalzug, in Gruppenkästen (`Regler.tsx:154-168`).
///
/// **Waagerecht rollbar, und das bleibt am Telefon so.** Die Vorlage legt die Gruppen in eine
/// Flexreihe mit `overflow-x: auto` (`globals.css:974`); am Telefon fährt sie randlos aus und
/// schnappt an den Gruppen ein (`handy.css:237-238`). Eine Spaltenfassung ohne Pult gibt es
/// dort nicht – wer hier eine erfindet, weicht von der Vorlage ab.
///
/// **Was welche Gruppe ist, entscheidet der Kern** (``Reglerpult/pultgruppen(_:)``), und er hat
/// eine Auffanggruppe mehr als die Vorlage: eine stellbare Zahl in einer vierten Gruppe fiele
/// dort unter den Tisch.
///
/// **Der Verlauf der Vorlage liegt hier hinter den Zügen, nicht hinter der ganzen Karte**
/// (`globals.css:973`: `linear-gradient(180deg, surface-2, deep)`). ``Karte`` bringt ihren
/// Grund selbst mit und schaltet ihn nach Breite um; ein zweiter Grund von außen wäre eine
/// Ausnahme in einem Baustein, den 30 Seiten benutzen.
struct Pultkarte: View {
    let gruppen: [Reglerpult.Pultgruppe]
    let entwurf: Reglerpult.Entwurf
    let stellenMoeglich: Bool
    /// Ob der Mensch stellen darf – getrennt von ``stellenMoeglich``, das in die Sperrlogik des
    /// Kerns geht. Hier hängt nur der Vergleichsknopf daran (siehe ``Vergleichsknopf``).
    let darfStellen: Bool
    let stelle: (String, Double) -> Void
    let vergleichen: (ReglerEinstellungOut) -> Void

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        if !gruppen.isEmpty {
            Karte(kicker: "Pult") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: schmal ? 14 : 22) {
                        ForEach(gruppen) { gruppe in
                            kasten(gruppe)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, schmal ? 14 : 0)
                    .padding(.bottom, 6)
                }
                .scrollTargetBehaviorViewAligned(an: schmal)
                .padding(.horizontal, schmal ? -14 : 0)
                .background(verlauf)
            }
        }
    }

    /// Ein Gruppenkasten mit der Sperrschrift darüber – das „HEIZKURVE“ der Vorlage
    /// (`globals.css:975-976`).
    private func kasten(_ gruppe: Reglerpult.Pultgruppe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(wort: gruppe.name)
            HStack(alignment: .top, spacing: 10) {
                ForEach(gruppe.werte, id: \.schluessel) { w in
                    zug(w)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.18), in: kastenumriss)
        .overlay(kastenumriss.strokeBorder(Farbe.linie1, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(gruppe.name)
    }

    private var kastenumriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    private func zug(_ w: ReglerEinstellungOut) -> some View {
        Kanalzug(
            w: w,
            wert: Reglerpult.sichtbar(w, entwurf: entwurf),
            sperre: Reglerpult.sperre(w, stellenMoeglich: stellenMoeglich),
            fuss: Reglerpult.fuss(w, stellenMoeglich: stellenMoeglich),
            darfStellen: darfStellen,
            schmal: schmal,
            stelle: { neu in stelle(w.schluessel, neu) },
            vergleichen: { vergleichen(w) }
        )
    }

    private var verlauf: LinearGradient {
        LinearGradient(
            colors: [Farbe.flaeche2, Farbe.deep], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// Das Gegenstück zu `scroll-snap-align: start` am Telefon (`handy.css:238`): beim Loslassen
    /// steht eine Gruppe am linken Rand und nicht irgendwo.
    ///
    /// **Als eigener Modifier, weil `scrollTargetBehavior` nur am Telefon gilt.** Ein `if` in
    /// der Modifizierkette lässt sich nicht schreiben; ein benannter Modifier mit einem
    /// `@ViewBuilder` schon, und er sagt zugleich, was er bedeutet. Wirksam wird er nur
    /// zusammen mit `scrollTargetLayout()` am Inhalt – darum steht das dort.
    @ViewBuilder func scrollTargetBehaviorViewAligned(an: Bool) -> some View {
        if an {
            // Mit `self.`, weil `tools/ios-typpruefen.py` jeden Namen ohne Punkt davor im
            // Projekt sucht und `scrollTargetBehavior` aus SwiftUI kommt.
            self.scrollTargetBehavior(.viewAligned)
        } else {
            self
        }
    }
}
