import DuckCurveKit
import SwiftUI

/// Die Seite „Mein Zugang“: das eigene Passwort und das Abmelden.
///
/// Sie steht außerhalb der sechs Bereiche (`docs/seitenbaum.json`, `einzelseiten`) und ist für
/// **jede angemeldete Person** da, nicht nur für den Hausherrn. Der Hausherr hat das am
/// 24.11.2026 entschieden: bis dahin stand der Abschnitt auf „Zugang und Sicherung“ im Bereich
/// System, den ein Bewohner nicht sieht. Die Vorlage ist `apps/web/src/app/konto/page.tsx`.
///
/// **Was der App gegenüber der Vorlage noch fehlt** (`docs/GLEICHSTAND.md`): die Liste der
/// eigenen Passkeys, die eigenen Sitzungen und die Wiederherstellungscodes. Passwort und
/// Abmelden sind da.
struct KontoSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var meldetAb = false

    var body: some View {
        Seite {
            if haus.zugang.istPerson {
                angemeldet
                MeinPasswortKarte()
                abmelden
            } else {
                Karte(kicker: Zugangsworte.meinZugangUeberschrift) {
                    absatz(Zugangsworte.keinePerson)
                }
            }
        }
    }

    private var angemeldet: some View {
        Karte(kicker: Zugangsworte.meinZugangUeberschrift) {
            VStack(alignment: .leading, spacing: 8) {
                absatz(Zugangsworte.angemeldetAls(haus.zugang.email))
                Zeile(
                    wort: "In dieser App",
                    wert: haus.zugang.rolle == .hausherr ? "Vollzugriff" : "nur Ansicht",
                    farbe: haus.zugang.rolle == .hausherr ? Farbe.text1 : Farbe.achtung
                )
            }
        }
    }

    private var abmelden: some View {
        Karte(kicker: Zugangsworte.abmelden) {
            Button {
                meldetAb = true
                Task {
                    await haus.meldeAb()
                    meldetAb = false
                }
            } label: {
                HStack(spacing: 8) {
                    if meldetAb { ProgressView().controlSize(.small) }
                    Text(Zugangsworte.abmelden)
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(meldetAb)
        }
    }

    /// Ein Absatz wie auf „Zugang und Sicherung“: 15 Punkte, zweite Textstufe.
    private func absatz(_ wort: String) -> some View {
        Text(wort)
            .font(Schrift.sans(15, relativeTo: .body))
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
