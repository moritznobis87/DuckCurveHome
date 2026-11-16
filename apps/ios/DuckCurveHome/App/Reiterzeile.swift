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
            HStack(spacing: 2) {
                ForEach(sichtbar) { r in
                    knopf(r, gewaehlt: r.weg == aktiv?.weg)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        // Ohne das wächst die Zeile am Telefon in die Höhe des Rollbereichs.
        .frame(height: 40)
        .background(Farbe.flaeche1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Farbe.linie1).frame(height: 1)
        }
    }

    private func knopf(_ r: Reiter, gewaehlt: Bool) -> some View {
        Button {
            if !gewaehlt { waehle(r) }
        } label: {
            Text(r.name)
                .font(Schrift.klein)
                .foregroundStyle(gewaehlt ? Farbe.text1 : Farbe.text3)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                        .fill(gewaehlt ? Farbe.flaeche3 : Color.clear)
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
