import DuckCurveKit
import SwiftUI

/// Die Karte „Speicher steuern“: Betriebsart und Untergrenze des Ladestands.
///
/// **Warum sie auf der Speicherseite steht und nicht in der unteren Leiste.** Die Leiste ist
/// für Dinge, die man im Vorbeigehen drückt. Das hier ist eine Einstellung, die man einmal
/// trifft und dann an ihren Folgen misst - und die Folgen stehen auf genau dieser Seite:
/// Netzladung, Ladung bei Dunkelheit, Vollzyklen (`BatteryControl.tsx:11-16`).
///
/// **Wozu die Untergrenze.** Der Libbi entlädt bis zu seiner eigenen Grenze, meldet dann 0 %,
/// und wenn dieser Stand eine Stunde steht, holt er sich rund 6 % aus dem Netz zurück. Diese
/// Energie erreicht das Haus nicht: gemessen am 03.09.2026 war sie drei Stunden später wieder
/// verschwunden, ohne dass der Speicher etwas abgegeben hätte. Die letzten Prozent zu fahren
/// kostet also Netzstrom, Wirkungsgrad und Zyklen und bringt nichts
/// (`BatteryControl.tsx:18-22`).
///
/// **Ohne Antwort gar keine Karte** (`BatteryControl.tsx:63`). Ein leerer Kasten mit drei toten
/// Knöpfen sagt weniger als nichts: er behauptet eine Bedienung, die gerade nicht da ist. Die
/// leere Hülle bleibt nur, damit die Abfrage überhaupt laufen kann - sie ist null Punkte hoch.
///
/// **Was gerechnet wird, steht im Kern** (``Speichersteuerung``): die Wörter der drei
/// Betriebsarten, die fünf Stufen, die Frist von zwei Stunden, die Abbildung `off` auf „Frei“
/// und die zusammengesetzte Notenzeile. Hier bleiben die Maße.
struct Speichersteuerkarte: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var stand: BatteryLiveOut?
    @State private var sendet = false
    @State private var fehler: String?

    private var schmal: Bool { breite == .compact }
    /// Höhe der Griffe (`BatteryControl.tsx:90,113`) - und zugleich die Mindestgröße, die eine
    /// Fläche haben muss, die mit dem Daumen getroffen wird.
    private let griffhoehe: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            if let s = stand {
                karte(s)
            }
        }
        .task { await beobachte() }
    }

    private func karte(_ s: BatteryLiveOut) -> some View {
        Karte(
            kicker: "Speicher steuern",
            beiwerk: AnyView(ladestand(s))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                griffe(s)
                Text(sendet ? Speichersteuerung.sendetSatz : Speichersteuerung.zeile(s, fehler: fehler))
                    .font(Schrift.winzig)
                    .foregroundStyle(fehler == nil ? Farbe.text3 : Farbe.alarm)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func ladestand(_ s: BatteryLiveOut) -> some View {
        Kartenhinweis(satz: Speichersteuerung.ladestandswort(s))
    }

    // MARK: - Die zwei Gruppen

    /// **Am iPad nebeneinander, am Telefon untereinander.** Die Vorlage setzt eine Flex-Reihe
    /// mit `flex-wrap` (`BatteryControl.tsx:87`); drei Knöpfe zu 92 Punkten und fünf zu 56
    /// sind zusammen über 600 Punkte breit und brechen auf einem Telefon in jedem Fall um.
    @ViewBuilder private func griffe(_ s: BatteryLiveOut) -> some View {
        let gesperrt = sendet || Speichersteuerung.gesperrt(s) || !haus.darfSchalten
        if schmal {
            VStack(alignment: .leading, spacing: 12) {
                betriebsarten(s, gesperrt: gesperrt)
                VStack(alignment: .leading, spacing: 6) {
                    Kicker(wort: "Untergrenze")
                    untergrenzen(s, gesperrt: gesperrt)
                }
            }
        } else {
            HStack(alignment: .center, spacing: 16) {
                betriebsarten(s, gesperrt: gesperrt)
                HStack(spacing: 8) {
                    Kicker(wort: "Untergrenze")
                    untergrenzen(s, gesperrt: gesperrt)
                }
            }
        }
    }

    /// Die drei Betriebsarten in einem Kasten, durch Haarlinien getrennt - ein Griff und nicht
    /// drei (`BatteryControl.tsx:88-102`).
    private func betriebsarten(_ s: BatteryLiveOut, gesperrt: Bool) -> some View {
        let aktiv = Speichersteuerung.gezeigteArt(s)
        return HStack(spacing: 0) {
            ForEach(Array(Speichersteuerung.arten.enumerated()), id: \.element.id) { stelle, art in
                if stelle > 0 {
                    Rectangle().fill(Farbe.linie1).frame(width: 1, height: griffhoehe)
                }
                artknopf(art, an: art.wahl == aktiv, gesperrt: gesperrt)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
    }

    private func artknopf(
        _ art: Speichersteuerung.Betriebsart, an: Bool, gesperrt: Bool
    ) -> some View {
        Button {
            stelle(art.wahl, untergrenze: nil)
        } label: {
            Text(art.wort)
                .font(Schrift.klein)
                .foregroundStyle(an ? Farbe.petrol : Farbe.text2)
                .lineLimit(1)
                .frame(minWidth: 92, maxWidth: schmal ? .infinity : nil, minHeight: griffhoehe)
                .background(an ? Farbe.amber : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(gesperrt)
        .opacity(gesperrt ? 0.45 : 1)
        // Ohne das liest eine Sprachausgabe nur „Auto, Frei, Halten“ und sagt nicht, welche
        // gerade gilt; der erklärende Satz der Vorlage steht dort als `title`.
        .accessibilityAddTraits(an ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint(Text(art.dazu))
    }

    /// Die fünf Stufen (`BatteryControl.tsx:103-117`). Die gewählte in weichem Bernstein - sie
    /// ist eine Grenze und keine Betriebsart, und darf darum nicht so laut sein wie die.
    private func untergrenzen(_ s: BatteryLiveOut, gesperrt: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(Speichersteuerung.untergrenzen, id: \.self) { stufe in
                stufenknopf(
                    stufe, an: Speichersteuerung.istGewaehlt(s, stufe: stufe),
                    weiter: Speichersteuerung.stellwahl(s), gesperrt: gesperrt)
            }
        }
    }

    private func stufenknopf(
        _ stufe: Double, an: Bool, weiter: BatteryModeInModeWahl, gesperrt: Bool
    ) -> some View {
        Button {
            stelle(weiter, untergrenze: stufe)
        } label: {
            Text(Speichersteuerung.untergrenzenwort(stufe))
                .font(Schrift.zahlKlein)
                .foregroundStyle(an ? Farbe.petrol : Farbe.text2)
                .lineLimit(1)
                .frame(minWidth: 56, maxWidth: schmal ? .infinity : nil, minHeight: griffhoehe)
                .background(an ? Farbe.amberWeich : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(gesperrt)
        .opacity(gesperrt ? 0.45 : 1)
        .accessibilityAddTraits(an ? [.isButton, .isSelected] : [.isButton])
    }

    // MARK: - Holen und senden

    /// **Alle sechzig Sekunden neu** (`BatteryControl.tsx:47`). Der Ladestand ist eine Messung,
    /// die weiterläuft, auch wenn niemand blättert - und die Betriebsart kann von einem anderen
    /// Gerät gestellt worden sein.
    private func beobachte() async {
        while !Task.isCancelled {
            stand = try? await haus.api.batterie()
            try? await Task.sleep(for: .seconds(60))
        }
    }

    /// **Der Fehler steht zwölf Sekunden und verschwindet dann** (`BatteryControl.tsx:57`). Er
    /// gehört zu einem Knopfdruck, nicht zum Zustand des Speichers; stehen bliebe er so lange,
    /// bis jemand die Seite verlässt, und beschriebe dann längst eine andere Lage.
    private func stelle(_ art: BatteryModeInModeWahl, untergrenze: Double?) {
        sendet = true
        fehler = nil
        Task {
            do {
                stand = try await haus.api.stelleBatterie(
                    Speichersteuerung.befehl(art, untergrenze: untergrenze))
            } catch let f as ApiFehler {
                zeigeFehler(f.rat)
            } catch {
                zeigeFehler(Speichersteuerung.nichtBestaetigt)
            }
            sendet = false
        }
    }

    private func zeigeFehler(_ satz: String) {
        fehler = satz
        Task {
            try? await Task.sleep(for: .seconds(12))
            fehler = nil
        }
    }
}
