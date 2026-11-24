import DuckCurveKit
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Das eigene Passwort: vergeben, wechseln, entfernen.
///
/// Das Gegenstück zu `apps/web/src/components/zugang/MeinPasswort.tsx`, mit denselben Sätzen
/// (``Anmeldeworte``) und denselben Regeln: Wer schon ein Passwort hat, nennt das bisherige.
/// Entfernen lässt es sich nur, solange ein Passkey da ist, denn einer der beiden Wege herein
/// muss bleiben. Der Dienst prüft beides; die Karte sagt es vorher. Auch das Entfernen verlangt
/// das bisherige Passwort, sonst ließe sich die Prüfung beim Wechseln umgehen; die Eingabe ist
/// zugleich die Rückfrage.
///
/// Die Karte steht nur da, wenn eine Person angemeldet ist (``Zugang/istPerson``). Ein Gerät mit
/// dem API-Token hat kein Passwort.
struct MeinPasswortKarte: View {
    @Environment(Hauszustand.self) private var haus

    @State private var ich: IchOut?
    @State private var mindestlaenge = Anmeldeworte.mindestlaengeErsatz
    /// Welches Formular offen ist: vergeben oder wechseln, entfernen, oder keines.
    enum Formular: Hashable {
        case setzen
        case entfernen
    }

    @State private var offen: Formular?
    @State private var bisher = ""
    @State private var neu = ""
    @State private var wiederholung = ""
    @State private var hinweis: String?
    @State private var fehler: String?
    @State private var laeuft = false

    private var vorhanden: Bool { ich?.passwort ?? false }
    private var passkeys: Int { ich?.passkeys.count ?? 0 }

    var body: some View {
        Karte(kicker: Anmeldeworte.ueberschrift) {
            VStack(alignment: .leading, spacing: 12) {
                if ich == nil, fehler == nil {
                    Ladeente(satz: "Lade den eigenen Zugang.")
                } else {
                    if ich != nil {
                        satz(Anmeldeworte.stand(vorhanden: vorhanden), farbe: Farbe.text2)
                    }
                    if let hinweis { satz(hinweis, farbe: Farbe.text2) }
                    if let fehler { satz(fehler, farbe: Farbe.amberWeich) }
                    if ich != nil {
                        switch offen {
                        case .setzen: formular
                        case .entfernen: entfernformular
                        case nil: knoepfe
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await lade() }
    }

    private var knoepfe: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                hinweis = nil
                fehler = nil
                offen = .setzen
            } label: {
                knopfbild(Anmeldeworte.knopf(vorhanden: vorhanden))
            }
            .buttonStyle(.plain)
            .disabled(laeuft)
            if vorhanden {
                Button {
                    hinweis = nil
                    fehler = nil
                    offen = .entfernen
                } label: {
                    Text(passkeys == 0 ? Anmeldeworte.entfernenGesperrt : Anmeldeworte.entfernen)
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text3)
                        .underline()
                }
                .buttonStyle(.plain)
                .disabled(laeuft || passkeys == 0)
                .opacity(passkeys == 0 ? 0.6 : 1)
            }
        }
    }

    private var entfernformular: some View {
        VStack(alignment: .leading, spacing: 12) {
            feld(Anmeldeworte.bisherfeld, $bisher, art: .password)
            HStack(spacing: 16) {
                Button {
                    Task { await entferne() }
                } label: {
                    HStack(spacing: 8) {
                        if laeuft { ProgressView().controlSize(.small) }
                        knopfbild(Anmeldeworte.entfernen)
                    }
                }
                .buttonStyle(.plain)
                .disabled(laeuft || bisher.isEmpty)
                abbrechknopf
            }
        }
    }

    private var abbrechknopf: some View {
        Button(Anmeldeworte.abbrechen) {
            leere()
            offen = nil
        }
        .font(Schrift.klein)
        .foregroundStyle(Farbe.text3)
        .buttonStyle(.plain)
    }

    private var formular: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vorhanden {
                feld(Anmeldeworte.bisherfeld, $bisher, art: .password)
            }
            feld(Anmeldeworte.neufeld(mindestlaenge: mindestlaenge), $neu, art: .newPassword)
            feld(Anmeldeworte.wiederholfeld, $wiederholung, art: .newPassword)
            HStack(spacing: 16) {
                Button {
                    Task { await speichere() }
                } label: {
                    HStack(spacing: 8) {
                        if laeuft { ProgressView().controlSize(.small) }
                        knopfbild(Anmeldeworte.knopf(vorhanden: vorhanden))
                    }
                }
                .buttonStyle(.plain)
                .disabled(laeuft || neu.isEmpty)
                abbrechknopf
            }
        }
    }

    private func knopfbild(_ wort: String) -> some View {
        Text(wort)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .overlay(
                RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                    .strokeBorder(Farbe.linie2, lineWidth: 1)
            )
    }

    private func feld(_ wort: String, _ wert: Binding<String>, art: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            SecureField("", text: wert)
                .textContentType(art)
                .textFieldStyle(.plain)
                .font(Schrift.text)
                .padding(10)
                .background(Farbe.flaeche3)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                .accessibilityLabel(wort)
        }
    }

    private func satz(_ wort: String, farbe: Color) -> some View {
        Text(wort)
            .font(Schrift.sans(14, relativeTo: .footnote))
            .foregroundStyle(farbe)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func leere() {
        bisher = ""
        neu = ""
        wiederholung = ""
    }

    // MARK: - Mit dem Dienst

    private func lade() async {
        do {
            ich = try await haus.api.ich()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f.rat
        } catch {
            fehler = ApiFehler.netz(error.localizedDescription).rat
        }
        // Die Mindestlänge nennt der Dienst. Antwortet er darauf nicht, bleibt der Ersatzwert
        // stehen; geprüft wird ohnehin dort.
        if let stand = try? await haus.api.zugangZustand(), let laenge = stand.passwortMindestlaenge {
            mindestlaenge = laenge
        }
    }

    private func speichere() async {
        hinweis = nil
        fehler = nil
        if let einwand = Anmeldeworte.einwand(neu: neu, wiederholung: wiederholung) {
            fehler = einwand
            return
        }
        let vorher = vorhanden
        laeuft = true
        defer { laeuft = false }
        do {
            try await haus.api.setzePasswort(neu: neu, bisher: bisher)
            leere()
            offen = nil
            hinweis = Anmeldeworte.gespeichert(vorher: vorher)
            await lade()
        } catch let f as ApiFehler {
            // Der Satz des Dienstes, nicht der allgemeine Rat: „Das bisherige Passwort stimmt
            // nicht“ ist hier die Auskunft, die hilft.
            fehler = f.meldung
        } catch {
            fehler = ApiFehler.netz(error.localizedDescription).rat
        }
    }

    private func entferne() async {
        hinweis = nil
        fehler = nil
        laeuft = true
        defer { laeuft = false }
        do {
            try await haus.api.entfernePasswort(bisher: bisher)
            leere()
            offen = nil
            hinweis = Anmeldeworte.entfernt
            await lade()
        } catch let f as ApiFehler {
            fehler = f.meldung
        } catch {
            fehler = ApiFehler.netz(error.localizedDescription).rat
        }
    }
}
