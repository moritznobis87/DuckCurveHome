import DuckCurveKit
import SwiftUI

/// Was ein Tipp auf die Wärmepumpe im Flussbild öffnet: eine Auswahl aus vier Zielen.
///
/// **Warum eine Auswahl und kein Sprung** (Nutzerwunsch 14.11.2026, `home/WpMenue.tsx`). Bis
/// dahin führte der Knoten auf die Seite „Wärme". Wer auf die Wärmepumpe tippt, will aber eines
/// von mehreren Dingen wissen, und welches, weiß nur er: wie sie gerade arbeitet, was sie
/// kostet, wann sie laufen soll, wie viel sie verbraucht hat. Vier Ziele, je ein Zeichen und
/// ein Satz.
///
/// **Warum die App bis zum 19.11.2026 etwas anderes zeigte.** Sie sprang vom Knoten direkt in
/// das Blatt mit Zustand, Stellen und letzter Entscheidung – also in genau eines der vier
/// Dinge, ohne zu fragen. Das Blatt bleibt: es hängt am Dock, so wie im Dashboard die
/// Schaltfläche unter dem Dockknopf. Der Knoten fragt jetzt.
///
/// **Nur die Wärmepumpe hat das.** Die anderen Knoten haben ein Ziel und springen weiter
/// direkt.
struct Wpmenue: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.dismiss) private var schliessen
    @Environment(\.horizontalSizeClass) private var breite

    /// Ein Ziel der Auswahl. Dieselben vier wie in `WpMenue.tsx:21-26`.
    struct Ziel: Identifiable {
        let weg: String
        let zeichen: Zeichenart
        let titel: String
        let satz: String

        var id: String { weg }
    }

    static let ziele: [Ziel] = [
        Ziel(
            weg: "/waerme/waermepumpe", zeichen: .zahnrad, titel: "Technik",
            satz: "Wie sie gerade arbeitet: Außengerät, Innengerät, alle Messwerte"
        ),
        Ziel(
            weg: "/waerme/nachbetrachtung", zeichen: .euro, titel: "Kosten",
            satz: "Was die Wärme gekostet hat, Tag für Tag"
        ),
        Ziel(
            weg: "/waerme/fahrplan", zeichen: .kalender, titel: "Fahrplan",
            satz: "Wann sie laufen soll und warum"
        ),
        Ziel(
            weg: "/waerme", zeichen: .diagramm, titel: "Verbrauch",
            satz: "Wärme und Strom über Tage und Wochen"
        ),
    ]

    /// Wie hoch die Auswahl wirklich ist - gemessen, nicht geschätzt.
    ///
    /// **Warum gemessen.** Der erste Satz („Wie sie gerade arbeitet: Außengerät, Innengerät,
    /// alle Messwerte") bricht je nach Breite und Schriftgröße auf zwei oder drei Zeilen. Eine
    /// feste Höhe wäre für den einen Fall zu knapp und für den anderen zu weit, und ein Blatt,
    /// das unten leer weitergeht, sieht aus, als fehle etwas darin.
    ///
    /// **Gemessen über `onAppear`/`onChange` und nicht über eine Preference.** Das Ziel ist
    /// `@State`, und `onPreferenceChange` nimmt seit dem iOS-18-SDK einen `@Sendable`
    /// Abschluss - der darf diesen Zustand nicht anfassen. Dieses Projekt übersetzt mit
    /// `SWIFT_STRICT_CONCURRENCY: complete`, da wäre das ein Fehler und kein Hinweis.
    @State private var inhaltshoehe: CGFloat = 480

    var body: some View {
        inhalt
            .background(
                GeometryReader { raum in
                    Color.clear
                        .onAppear { inhaltshoehe = raum.size.height }
                        .onChange(of: raum.size.height) { _, neu in inhaltshoehe = neu }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Farbe.flaeche1.ignoresSafeArea())
            .presentationDetents([.height(inhaltshoehe)])
            .presentationDragIndicator(.visible)
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: 16) {
            kopf
            // **Am Telefon eine Spalte, an der Wand zwei** (`globals.css:810` gegen
            // `handy.css:233`). Vier Kacheln untereinander sind auf 1100 Punkten eine Liste in
            // einem leeren Feld; auf 390 Punkten nebeneinander ist jeder Satz drei Zeilen hoch.
            LazyVGrid(
                columns: breite == .compact
                    ? [GridItem(.flexible())]
                    : [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(Self.ziele) { z in
                    knopf(z)
                }
            }
            Button("Schließen") { schliessen() }
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Wärmepumpe")
                .font(Schrift.sans(20, relativeTo: .title3))
                .fontWeight(.semibold)
                .foregroundStyle(Farbe.text1)
            Spacer(minLength: 8)
            Text(zeile)
                .font(Schrift.mono(14))
                .foregroundStyle(Farbe.text3)
        }
    }

    /// „1,2 kW · läuft" – dieselbe Zeile wie am Knoten darunter.
    private var zeile: String {
        let kw = haus.augenblick?.heatPumpPowerKw.value
        let wort = Wpbild.wort(kw: kw, laeuft: haus.zustand?.heatPump.running)
        return "\(Formate.kwMitEinheit(kw)) · \(wort)"
    }

    private func knopf(_ z: Ziel) -> some View {
        Button {
            // Erst schliessen, dann springen: sonst liegt die Auswahl noch über der Seite,
            // auf die sie geführt hat.
            schliessen()
            wegweiser.gehe(z.weg)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Zeichen(z.zeichen, groesse: 24, farbe: Farbe.amber)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Farbe.amber.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(z.titel)
                        .font(Schrift.sans(16))
                        .fontWeight(.semibold)
                        .foregroundStyle(Farbe.text1)
                    Text(z.satz)
                        .font(Schrift.sans(13))
                        .foregroundStyle(Farbe.text3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche2)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Farbe.linie1, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(z.titel): \(z.satz)")
        .accessibilityAddTraits(.isButton)
    }
}
