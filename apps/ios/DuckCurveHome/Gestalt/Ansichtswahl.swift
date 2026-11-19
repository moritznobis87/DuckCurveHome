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

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        HStack(spacing: schmal ? 2 : 2) {
            ForEach(ansichten) { a in
                knopf(a, gewaehlt: a.weg == aktiv.weg)
            }
        }
        .padding(schmal ? 3 : 2)
        .background(schmal ? Color.white.opacity(0.07) : Farbe.flaeche2)
        .clipShape(
            RoundedRectangle(cornerRadius: schmal ? 11 : Marken.radius3, style: .continuous))
        // **Am Telefon ueber die ganze Breite** (`handy.css:177-179`: `.ansichten` mit
        // `align-self: stretch`, jede Ansicht `flex: 1`). Ein Schalter von 120 Punkten in einer
        // 390 Punkte breiten Zeile ist mit dem Daumen schwer zu treffen; ueber die ganze Breite
        // hat jede Haelfte 190 Punkte.
        .frame(maxWidth: schmal ? .infinity : nil)
    }

    private func knopf(_ a: Ansicht, gewaehlt: Bool) -> some View {
        Button {
            if !gewaehlt { waehle(a) }
        } label: {
            Text(a.name)
                // **Bernstein auf Petrol fuer das Gewaehlte** (`globals.css:781`,
                // `.ansicht-an`). Vorher war es eine Spur heller als der Grund - auf einem
                // Telefon im Sonnenlicht nicht zu sehen, und auf dem Bildschirmfoto nicht zu
                // unterscheiden.
                .font(schmal ? Schrift.sans(14) : Schrift.klein)
                .fontWeight(gewaehlt ? .medium : .regular)
                .foregroundStyle(gewaehlt ? Farbe.petrol : Farbe.text2)
                .lineLimit(1)
                .frame(maxWidth: schmal ? .infinity : nil)
                .padding(.horizontal, schmal ? 8 : 11)
                .padding(.vertical, schmal ? 9 : 5)
                .background(
                    RoundedRectangle(cornerRadius: schmal ? 8 : Marken.radius2, style: .continuous)
                        .fill(gewaehlt ? Farbe.amber : Color.clear)
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
