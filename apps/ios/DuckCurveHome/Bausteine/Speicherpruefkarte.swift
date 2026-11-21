import DuckCurveKit
import SwiftUI

/// Die Karte „Stimmt das?“ - der Prüfbericht des Speichers, auf Abruf.
///
/// **Warum auf Abruf und nicht mit der Seite.** Die App holte ihn bisher bei jedem
/// Seitenaufruf und bei jedem Zeitraumwechsel mit. Die Vorlage tut das ausdrücklich nicht:
/// *„Er liest die Minutenreihen des Zeitraums, bei einem Jahr über eine halbe Million Zeilen.
/// Das ist nichts, was bei jedem Seitenaufruf nebenbei laufen soll“* (`SpeicherCheck.tsx:16`).
///
/// **Warum er hier steht und nicht als Kachel.** Die Kacheln dieser Seite rechnen alle aus
/// einer einzigen Messreihe; wenn eine von ihnen unglaubwürdig aussieht, hilft keine weitere
/// Kachel aus derselben Quelle. Der Bericht holt zwei unabhängige Zeugen dazu - den Ladestand
/// des Geräts und den Hausverbrauch der Hub-Wandler (`SpeicherCheck.tsx:10-14`).
///
/// **Der Absatz steht immer da, auch ohne Bericht.** Er sagt nicht, was die Prüfung ergeben
/// hat, sondern wogegen sie prüft - und das ist die Auskunft, die man braucht, um zu
/// entscheiden, ob man sie überhaupt laufen lässt.
struct Speicherpruefkarte: View {
    let spanne: Spanne
    let anker: String

    @Environment(Hauszustand.self) private var haus

    @State private var bericht: String?
    @State private var laeuft = false
    @State private var fehler: String?

    var body: some View {
        Karte(kicker: "Stimmt das?", beiwerk: AnyView(knopf)) {
            VStack(alignment: .leading, spacing: 10) {
                Text(Speicherbild.pruefsatz)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let fehler {
                    Text(fehler).font(Schrift.klein).foregroundStyle(Farbe.alarm)
                }
                if let bericht, !bericht.isEmpty {
                    berichtsfeld(bericht)
                }
            }
        }
    }

    /// Der Knopf rechts im Kartenkopf: eine Kapsel in Bernstein (`globals.css:602-603`).
    /// Gesperrt, solange die Prüfung läuft - sie dauert bei einem Jahr spürbar lange, und ein
    /// zweiter Druck startete einen zweiten Lauf über dieselbe halbe Million Zeilen.
    private var knopf: some View {
        Button {
            pruefe()
        } label: {
            // `.pruef-knopf` (`globals.css:602`): Mono 11, 0,12 em - bei 11 Punkten 1,32 -,
            // Großbuchstaben. Die Kickerschrift, die hier stand, war weder die eine noch die
            // andere Größe.
            Text(Speicherbild.pruefknopf(laeuft: laeuft).uppercased())
                .font(Schrift.mono(11, relativeTo: .caption2))
                .tracking(1.32)
                .foregroundStyle(laeuft ? Farbe.text2 : Farbe.petrol)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(laeuft ? Farbe.linie2 : Farbe.amber)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(laeuft || anker.isEmpty)
    }

    /// Der Bericht als vorformatierter Text: eigene Fläche, Rahmen, Rundung - er ist ein
    /// Dokument in der Karte und nicht ein Satz der Karte (`globals.css:604`).
    ///
    /// **Er rollt in beide Richtungen.** Seine Zeilen sind breiter als jedes Telefon, und
    /// umbrechen darf er nicht: eine Tabelle aus Festbreitenschrift, die umbricht, ist keine
    /// Tabelle mehr. Das ist das `white-space: pre` der Vorlage, und hier steht dafür
    /// `fixedSize()` - der Text wird nie enger gemacht, die Fläche rollt stattdessen.
    @ViewBuilder private func berichtsfeld(_ text: String) -> some View {
        // **Nur ein langer Bericht wird gedeckelt.** Die Vorlage setzt `max-height: 60dvh`;
        // SwiftUI kennt kein `dvh`, und ``containerRelativeFrame`` setzt eine feste Höhe statt
        // einer Obergrenze - aus drei Zeilen würde damit ein halber Bildschirm Leere. Gedeckelt
        // wird darum erst, was ohne Deckel die Karte über die Seite wachsen liesse; wo die
        // Grenze liegt, entscheidet der Kern (``Speicherbild/berichtIstLang(_:)``).
        if Speicherbild.berichtIstLang(text) {
            rollflaeche(text)
                .containerRelativeFrame(.vertical, alignment: .top) { hoehe, _ in hoehe * 0.6 }
        } else {
            rollflaeche(text)
        }
    }

    private func rollflaeche(_ text: String) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Text(text)
                .font(Schrift.mono(11.5))
                .foregroundStyle(Farbe.text2)
                .lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .background(Farbe.deep.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private func pruefe() {
        laeuft = true
        fehler = nil
        Task {
            do {
                bericht = try await haus.api.speicherPruefung(spanne.rawValue, anker: anker)
            } catch let f as ApiFehler {
                fehler = f.rat
                bericht = nil
            } catch {
                fehler = Speicherbild.pruefungGescheitert
                bericht = nil
            }
            laeuft = false
        }
    }
}
