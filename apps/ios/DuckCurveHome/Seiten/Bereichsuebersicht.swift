import DuckCurveKit
import SwiftUI

/// Die Übersicht eines Bereichs mit Gruppen: je Gruppe eine Reihe Karten, jede Karte eine Seite.
///
/// Sie ersetzt die lange Reiterzeile als Einstieg (`Bereichsuebersicht.tsx`). Wer den Bereich
/// öffnet, sieht zuerst, welche Seiten es gibt und wovon jede handelt, und muss dafür keine
/// Zeile durchrollen. Den Satz auf der Karte trägt der Seitenbaum (``Reiter/beschreibung``),
/// damit er im Dashboard und in der App derselbe ist.
///
/// **Breit stehen die Gruppen nebeneinander, schmal untereinander** (`globals.css`,
/// `.uebersicht`). Was nur der Hausherr sieht, fehlt einem Gast hier wie in der Reiterzeile;
/// eine Gruppe, von der danach nichts übrig ist, wird nicht gezeichnet.
///
/// Die Zeile über der Seite kommt wie überall aus dem Gerippe (``Bereiche/kicker(fuer:)``).
struct Bereichsuebersicht: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    let bereich: Bereich

    private var schmal: Bool { breite == .compact }

    /// Die Seiten einer Gruppe, die dieser Betrachter sehen darf.
    private func seiten(_ gruppe: Gruppe) -> [Reiter] {
        bereich.reiter(derGruppe: gruppe.name).filter { haus.darfSchalten || !$0.nurHausherr }
    }

    /// Die Gruppen, von denen für diesen Betrachter etwas übrig ist.
    private var gruppen: [Gruppe] {
        bereich.gruppen.filter { !seiten($0).isEmpty }
    }

    var body: some View {
        Seite {
            if schmal {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(gruppen) { gruppe in
                        spalte(gruppe)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 24) {
                    ForEach(gruppen) { gruppe in
                        spalte(gruppe)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    /// Eine Gruppe: ihr Name, der Halbsatz dazu und darunter ihre Seiten.
    private func spalte(_ gruppe: Gruppe) -> some View {
        VStack(alignment: .leading, spacing: schmal ? 9 : 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Kicker(wort: gruppe.name, groesse: 11)
                Text(gruppe.wort)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(seiten(gruppe)) { seite in
                karte(seite)
            }
        }
    }

    /// Eine Seite als Karte: ihr Name, der Satz dazu und, wo es welche gibt, ihre Ansichten.
    private func karte(_ seite: Reiter) -> some View {
        Button {
            wegweiser.gehe(seite.weg)
            wegweiser.merkeReiter()
        } label: {
            Karte {
                VStack(alignment: .leading, spacing: 6) {
                    Text(seite.name)
                        .font(Schrift.sansHalbfett(17, relativeTo: .headline))
                        .foregroundStyle(Farbe.text1)
                    if let satz = seite.beschreibung {
                        Text(satz)
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !seite.unter.isEmpty {
                        Text(seite.unter.map(\.name).joined(separator: " · "))
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
    #Preview("Übersicht Anlage · Hand") {
        Vorschaurahmen(weg: "/anlage") {
            Bereichsuebersicht(bereich: Bereiche.alle.first { $0.schluessel == .anlage }!)
        }
    }

    #Preview("Übersicht Anlage · Wand") {
        Vorschaurahmen(breit: true, weg: "/anlage") {
            Bereichsuebersicht(bereich: Bereiche.alle.first { $0.schluessel == .anlage }!)
        }
    }
#endif
