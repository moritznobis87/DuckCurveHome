import DuckCurveKit
import SwiftUI

/// Die Reiter eines Bereichs, als Zeile darunter.
///
/// **Diese Ansicht fehlte** – benutzt von `WandRahmen` und `HandRahmen`, geschrieben nie. Wie
/// `Ansichtswahl` ist sie dem Parser nicht aufgefallen: ein Aufruf eines Namens, den es nicht
/// gibt, ist syntaktisch einwandfrei. Der Kommentar an `Reiter.unter` im Kern nennt sie sogar
/// („Sie stehen als Umschalter unter der Reiterzeile") – sie war die ganze Zeit vorgesehen.
///
/// **`darfAlles` blendet aus, es sperrt nicht.** Ein Reiter mit `nurHausherr` verschwindet für
/// einen Gast aus der Zeile. Das ist Höflichkeit und keine Sicherheit: wer die Adresse kennt,
/// käme trotzdem hin. Gesperrt wird dort, wo es zählt – im Dienst, und im Dashboard im
/// BFF-Proxy (`apps/web/src/app/api/dch/[...path]/route.ts`). Dasselbe gilt hier: die App
/// zeigt einem Gast die Kachel nicht, aber verlassen darf sich darauf niemand.
///
/// **Sie rollt waagerecht.** Am iPad passen die Reiter des Technik-Bereichs in eine Zeile, am
/// Telefon nicht – und eine Zeile, die umbricht, verschiebt den Inhalt darunter bei jedem
/// Wechsel. Rollen ist das kleinere Übel als ein springendes Gerippe.
struct Reiterzeile: View {
    let bereich: Bereich
    let aktiv: Reiter?
    let darfAlles: Bool
    let waehle: (Reiter) -> Void

    private var sichtbar: [Reiter] {
        bereich.reiter.filter { darfAlles || !$0.nurHausherr }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sichtbar) { r in
                    knopf(r, gewaehlt: r.weg == aktiv?.weg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        // Ohne das wächst die Zeile am Telefon in die Höhe des Rollbereichs.
        .frame(height: 44)
        // **Keine Trennlinie darunter** (`handy.css:163`: `border-bottom: 0`). Pillen brauchen
        // keinen Strich, der sie von der Seite trennt - sie liegen ohnehin auf ihr.
        .mask(
            // Am Rand ausblenden, damit eine angeschnittene Pille nicht wie ein Fehler aussieht,
            // sondern wie „da geht es weiter" (`handy.css:168-169`).
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.035),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    private func knopf(_ r: Reiter, gewaehlt: Bool) -> some View {
        Button {
            if !gewaehlt { waehle(r) }
        } label: {
            Text(r.name)
                .font(Schrift.sans(14))
                .fontWeight(gewaehlt ? .semibold : .regular)
                // **Weiss auf dunkel fuer den gewaehlten Reiter** (`handy.css:175`). Eine Pille,
                // die nur eine Spur heller ist als ihre Nachbarinnen, sagt nicht, wo man ist.
                .foregroundStyle(gewaehlt ? Farbe.deep : Farbe.text2)
                .lineLimit(1)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(gewaehlt ? Farbe.text1 : Color.white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : [.isButton])
    }
}

#if DEBUG
    #Preview("Reiterzeile") {
        let technik = Bereiche.alle.first { $0.schluessel == .technik }!
        return VStack(spacing: 24) {
            Reiterzeile(bereich: technik, aktiv: technik.reiter.first, darfAlles: true) { _ in }
            // Als Gast: die Reiter mit `nurHausherr` fallen weg.
            Reiterzeile(bereich: technik, aktiv: nil, darfAlles: false) { _ in }
        }
        .background(Farbe.grund)
    }
#endif
