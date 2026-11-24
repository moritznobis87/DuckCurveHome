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

    /// Eine Seite als Kachel: oben ihr Zeichen in der Farbe ihrer Sache und rechts der Zustand,
    /// darunter der Name, die Leitzahl groß mit kleiner Einheit, und ein Wort dazu.
    private func kachel(_ seite: Reiter) -> some View {
        let stand = karten[seite.weg]
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
