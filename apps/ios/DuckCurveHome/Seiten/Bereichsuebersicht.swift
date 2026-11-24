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
///
/// **Leitzahl und Ampel kommen vom Dienst** (`GET /uebersicht/{bereich}`): je Seite ihre
/// wichtigste Zahl und ein Zustand, fertig formuliert, damit Dashboard und App dasselbe zeigen.
/// Eine Ampel, die nicht gut ist, bringt ihren Grund als Satz mit; er steht auf der Karte. Eine
/// Seite ohne Karte des Dienstes (die Annahmen) zeigt nur ihren festen Satz. Antwortet der Dienst
/// nicht, stehen die Karten ohne Zahl da: alte Zahlen stehen zu lassen wäre schlechter als keine.
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

    /// Eine Seite als Karte: ihr Name mit der Ampel, die Leitzahl, der Grund einer Ampel, die
    /// nicht gut ist, der feste Satz und, wo es welche gibt, ihre Ansichten.
    private func karte(_ seite: Reiter) -> some View {
        let stand = karten[seite.weg]
        let ampel = stand.map { Hausgeraet.Ampel($0.ampel?.rawValue) }
        return Button {
            wegweiser.gehe(seite.weg)
            wegweiser.merkeReiter()
        } label: {
            Karte(hervorhebung: randfarbe(ampel)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(seite.name)
                            .font(Schrift.sansHalbfett(17, relativeTo: .headline))
                            .foregroundStyle(Farbe.text1)
                        Spacer(minLength: 8)
                        if let ampel {
                            Circle()
                                .fill(ampel.farbe)
                                .frame(width: 9, height: 9)
                                .accessibilityLabel(ampel.wort)
                        }
                    }
                    if let zahl = stand?.leitzahlDe, !zahl.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(zahl)
                                .font(Schrift.mono(24, relativeTo: .title2))
                                .foregroundStyle(Farbe.text1)
                                .monospacedDigit()
                            Text(stand?.dazuDe ?? "")
                                .font(Schrift.klein)
                                .foregroundStyle(Farbe.text2)
                        }
                    }
                    if let grund = stand?.grundDe, !grund.isEmpty {
                        Text(grund)
                            .font(Schrift.klein)
                            .foregroundStyle(grundfarbe(ampel))
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    /// Eine Karte, die etwas zu sagen hat, hebt sich mit ihrem Rand ab (`globals.css`,
    /// `.uebersicht-karte[data-ampel]`): weicher Bernstein für einen Hinweis, Alarmrot für eine
    /// Störung. Alle anderen behalten den Rand, den die Karte ohnehin hat.
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

    #Preview("Übersicht Anlage · Wand") {
        Vorschaurahmen(breit: true, weg: "/anlage") {
            Bereichsuebersicht(bereich: Bereiche.alle.first { $0.schluessel == .anlage }!)
        }
    }
#endif
