import DuckCurveKit
import SwiftUI

/// Der Umschalter zwischen gleichrangigen Ansichten einer Seite.
///
/// **Diese Ansicht fehlte.** Sie wurde an drei Stellen benutzt – über der Tageskurve
/// (Gestern/Heute/Morgen), auf der Haus-Seite (Liste/Modell) und in der Kopfzeile für die
/// Spanne (Tag/Woche/Monat/Jahr) – und war nie geschrieben. Ein Parser bemerkt das nicht: der
/// Aufruf ist syntaktisch einwandfrei, es gibt den Namen nur nicht. Erst der Compiler hat es
/// gesagt, und das ist genau die Sorte Lücke, für die der erste Übersetzungslauf da ist.
///
/// **Verglichen wird über `weg`, nicht über Gleichheit.** Eine der drei Aufrufstellen
/// übergibt `Ansicht(weg: ansicht.rawValue, name: "")` – sie kennt den Namen an der Stelle
/// nicht und braucht ihn auch nicht. Zwei `Ansicht`-Werte sind nur gleich, wenn auch der Name
/// übereinstimmt; wer hier `==` nähme, hätte dort nie etwas ausgewählt. `weg` ist die
/// Kennung, und sie ist es, die zählt.
struct Ansichtswahl: View {
    let ansichten: [Ansicht]
    let aktiv: Ansicht
    /// Läuft nur, wenn eine *andere* Ansicht gewählt wird – ein Tippen auf die aktive soll
    /// keine Abfrage auslösen.
    let waehle: (Ansicht) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ansichten) { a in
                knopf(a, gewaehlt: a.weg == aktiv.weg)
            }
        }
        .padding(2)
        .background(Farbe.flaeche2)
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private func knopf(_ a: Ansicht, gewaehlt: Bool) -> some View {
        Button {
            if !gewaehlt { waehle(a) }
        } label: {
            Text(a.name)
                .font(Schrift.klein)
                .foregroundStyle(gewaehlt ? Farbe.text1 : Farbe.text3)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                        .fill(gewaehlt ? Farbe.flaeche3 : Color.clear)
                )
        }
        .buttonStyle(.plain)
        // Ohne das liest eine Sprachausgabe nur „Liste, Modell" vor und sagt nicht, welche
        // der beiden gerade gilt.
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : [.isButton])
    }
}

#if DEBUG
    #Preview("Ansichtswahl") {
        VStack(spacing: 16) {
            Ansichtswahl(
                ansichten: [Ansicht(weg: "liste", name: "Liste"), Ansicht(weg: "modell", name: "Modell")],
                aktiv: Ansicht(weg: "liste", name: "Liste")
            ) { _ in }
            Ansichtswahl(
                ansichten: Spanne.allCases.map { Ansicht(weg: $0.rawValue, name: $0.name) },
                aktiv: Ansicht(weg: Spanne.woche.rawValue, name: "")
            ) { _ in }
        }
        .padding()
        .background(Farbe.grund)
    }
#endif
