import DuckCurveKit
import SwiftUI

/// Die Übersicht eines Bereichs: jede Kachel eine Seite. Hat der Bereich Gruppen, steht je Gruppe
/// eine Reihe Kacheln unter ihrem Namen; hat er keine, stehen alle in einem Raster.
///
/// **Eine Kachel zeigt, sie erklärt nicht** (`Bereichsuebersicht.tsx`). Bis zum 24.11.2026 stand
/// auf jeder Karte ein Satz darüber, wovon die Seite handelt, und darunter ihre Ansichten. Am
/// Telefon waren das sechs Kästen voll Text, und der Hausherr hat es so genannt: grafisch
/// schwach, viel zu viel Text. Jetzt trägt jede Kachel das Zeichen der Seite in der Farbe ihrer
/// Sache, den Namen, die Leitzahl groß, ein Wort dazu und am Fuß ein kleines Bild: den Verlauf
/// des Tages, einen Füllstand, eine Abweichung oder den Horizont des Fahrplans
/// (``Kachelbildzeichnung``). Der Satz steht weiter da, für die Vorlesehilfe, und sichtbar nur
/// dort, wo eine Seite keine Zahl hat.
///
/// **Am Telefon stehen zwei Kacheln nebeneinander** (`handy.css`, `.uebersicht-karten`): sechs
/// Seiten passen auf einen Schirm, ohne zu rollen. Breit füllt das Raster die Zeile mit Kacheln
/// ab 190 Punkten. Was nur der Hausherr sieht, fehlt den anderen hier wie in der Reiterzeile;
/// eine Gruppe, von der danach nichts übrig ist, wird nicht gezeichnet.
///
/// Die Zeile über der Seite kommt wie überall aus dem Gerippe (``Bereiche/kicker(fuer:)``).
///
/// **Leitzahl und Ampel kommen vom Dienst** (`GET /uebersicht/{bereich}`): je Seite ihre
/// wichtigste Zahl und ein Zustand, fertig formuliert, damit Dashboard und App dasselbe zeigen.
/// Eine Ampel, die nicht gut ist, bringt ihren Grund als Satz mit; er steht auf der Kachel an
/// der Stelle des Wortes. Zeichen und Farbe trägt der Seitenbaum (``Reiter/zeichen``,
/// ``Reiter/farbe``). Antwortet der Dienst nicht, stehen die Kacheln ohne Zahl da: alte Zahlen
/// stehen zu lassen wäre schlechter als keine.
struct Bereichsuebersicht: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    let bereich: Bereich

    /// Die Karten des Dienstes, nach der Adresse ihrer Seite.
    @State private var karten: [String: UebersichtKarteOut] = [:]

    /// Wie oft die Karten ihre Zahlen neu holen: jede Minute (`Bereichsuebersicht.tsx`,
    /// `ERNEUERN_MS`). Die Übersicht steht auch an der Wand.
    private static let erneuernNach: UInt64 = 60_000_000_000

    private var schmal: Bool { breite == .compact }

    /// Die Seiten einer Gruppe, die dieser Betrachter sehen darf.
    private func seiten(_ gruppe: Gruppe) -> [Reiter] {
        bereich.reiter(derGruppe: gruppe.name).filter { haus.hatVollzugriff || !$0.nurHausherr }
    }

    /// Die Gruppen, von denen für diesen Betrachter etwas übrig ist.
    private var gruppen: [Gruppe] {
        bereich.gruppen.filter { !seiten($0).isEmpty }
    }

    /// Die Seiten eines Bereichs ohne Gruppen, die dieser Betrachter sehen darf.
    private var alleSeiten: [Reiter] {
        bereich.reiter.filter { haus.hatVollzugriff || !$0.nurHausherr }
    }

    var body: some View {
        Seite {
            if bereich.gruppen.isEmpty {
                raster(alleSeiten, inGruppe: false)
            } else if schmal {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(gruppen) { gruppe in
                        spalte(gruppe)
                    }
                }
            } else {
                // Breit stehen die Gruppen nebeneinander, jede mit zwei Kacheln je Zeile
                // (`globals.css`, `.uebersicht`).
                HStack(alignment: .top, spacing: 28) {
                    ForEach(gruppen) { gruppe in
                        spalte(gruppe)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                await lade()
                try? await Task.sleep(nanoseconds: Self.erneuernNach)
            }
        }
    }

    private func lade() async {
        do {
            let antwort = try await haus.api.uebersicht(bereich.schluessel.rawValue)
            var neu: [String: UebersichtKarteOut] = [:]
            for karte in antwort.karten { neu[karte.weg] = karte }
            karten = neu
        } catch {
            karten = [:]
        }
    }

    /// Eine Gruppe: ihr Name, der Halbsatz dazu und darunter ihre Kacheln.
    private func spalte(_ gruppe: Gruppe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Kicker(wort: gruppe.name, groesse: 11)
                Text(gruppe.wort)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            raster(seiten(gruppe), inGruppe: true)
        }
    }

    /// Die Kacheln: am Telefon und in einer Gruppe zwei nebeneinander; ein Bereich ohne Gruppen
    /// füllt breit die Zeile mit Kacheln ab 190 Punkten (`globals.css`, `.uebersicht-karten`).
    private func raster(_ seiten: [Reiter], inGruppe: Bool) -> some View {
        let abstand: CGFloat = schmal ? 10 : 12
        let spalten: [GridItem] = schmal || inGruppe
            ? [
                GridItem(.flexible(), spacing: abstand, alignment: .top),
                GridItem(.flexible(), spacing: abstand, alignment: .top),
            ]
            : [GridItem(.adaptive(minimum: 190), spacing: abstand, alignment: .top)]
        return LazyVGrid(columns: spalten, alignment: .leading, spacing: abstand) {
            ForEach(seiten) { seite in
                kachel(seite)
            }
        }
    }

    private func kachel(_ seite: Reiter) -> some View {
        Seitenkachel(seite: seite, stand: karten[seite.weg])
    }
}

#if DEBUG
    #Preview("Übersicht Anlage · Hand") {
        Vorschaurahmen(weg: "/anlage") {
            Bereichsuebersicht(bereich: Bereiche.alle.first { $0.schluessel == .anlage }!)
        }
    }

    #Preview("Übersicht Energie · Hand") {
        Vorschaurahmen(weg: "/energie") {
            Bereichsuebersicht(bereich: Bereiche.alle.first { $0.schluessel == .energie }!)
        }
    }

    #Preview("Übersicht Energie · Wand") {
        Vorschaurahmen(breit: true, weg: "/energie") {
            Bereichsuebersicht(bereich: Bereiche.alle.first { $0.schluessel == .energie }!)
        }
    }

    #Preview("Übersicht Anlage · Wand") {
        Vorschaurahmen(breit: true, weg: "/anlage") {
            Bereichsuebersicht(bereich: Bereiche.alle.first { $0.schluessel == .anlage }!)
        }
    }
#endif
