import DuckCurveKit
import SwiftUI

/// Die Oberflaeche am Telefon.
///
/// **Die vier Entscheidungen aus `handy.css`**, hier im Gerippe statt in achthundert Zeilen
/// Breitenabfragen verstreut:
///
/// 1. **Die Bereiche stehen unten**, wo der Daumen ist, mit Namen. Der Kopf gehoert der Seite.
/// 2. **Eine Zahl fuehrt.** Die erste Kennzahl steht gross ueber die ganze Breite, die uebrigen
///    darunter zweispaltig in derselben Flaeche - das macht `Kachelfeld`.
/// 3. **Flaechen statt Rahmen.** Karten haben hier keinen Rand und einen grossen Radius - das
///    macht `Karte`.
/// 4. **Tabellen werden Listen.** Vier Spalten passen nicht auf 390 Punkte.
///
/// **Kein Ambiente, keine Heimkehr.** Das Telefon schaltet sich von selbst ab, und es gehoert
/// einem: wer gestern angesehen hat, soll gestern wiederfinden. Beides ist an der Wand anders,
/// und beides steht darum in `WandRahmen` und nicht hier.
struct HandRahmen: View {
    @Environment(Hauszustand.self) private var haus
    let wegweiser: Wegweiser

    var body: some View {
        VStack(spacing: 0) {
            kopf
            if !wegweiser.bereich.reiter.isEmpty {
                Reiterzeile(
                    bereich: wegweiser.bereich,
                    aktiv: wegweiser.reiter,
                    darfAlles: haus.darfSchalten
                ) { r in
                    wegweiser.gehe(r.weg)
                    wegweiser.merkeReiter()
                }
                Divider().overlay(Farbe.linie1)
            }
            Seitenwahl(weg: wegweiser.weg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Bereichsleiste(wegweiser: wegweiser)
        }
    }

    /// Der Kopf gehoert der Seite: ihr Name, und rechts der Zustand der Verbindung.
    ///
    /// Die Uhr steht hier nicht. Am Telefon steht sie schon in der Statusleiste des Systems, und
    /// sie zweimal zu zeigen nimmt der Seite eine Zeile, die sie braucht.
    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(seitenname)
                .font(Schrift.titel)
                .foregroundStyle(Farbe.text1)
            Spacer(minLength: 8)
            if haus.gestoert {
                Verbindungspunkt()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var seitenname: String {
        if let r = wegweiser.reiter {
            if let a = wegweiser.ansicht, wegweiser.bereich.schluessel == .technik {
                // In der Technik ist der Reiter der Gegenstand und die Ansicht die Richtung:
                // „Wärmepumpe · Betrieb".
                return r.name == a.name ? r.name : "\(r.name) · \(a.name)"
            }
            return r.name
        }
        return wegweiser.bereich.name
    }
}

/// Die Bereichsleiste am unteren Rand.
///
/// **Mit Namen, nicht nur mit Zeichen.** Drei Zeichen nebeneinander sind im Vorbeigehen nicht zu
/// unterscheiden - dieselbe Beobachtung, die im Dock unter jeden Knopf ein Wort gesetzt hat
/// („Terrasse", „Hof", „Zaun", Rueckmeldung vom 22.10.2026).
struct Bereichsleiste: View {
    @Environment(Hauszustand.self) private var haus
    let wegweiser: Wegweiser

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Farbe.linie1)
            HStack(spacing: 0) {
                ForEach(Bereiche.alle) { b in
                    knopf(b)
                }
            }
            .padding(.top, 6)
        }
        .background(Farbe.flaeche1)
    }

    private func knopf(_ b: Bereich) -> some View {
        let istAktiv = wegweiser.bereich.schluessel == b.schluessel
        return Button {
            wegweiser.merkeReiter()
            wegweiser.geheZuBereich(b)
        } label: {
            VStack(spacing: 3) {
                Zeichen(bereich: b.zeichen, groesse: 23, farbe: istAktiv ? Farbe.amber : Farbe.text3)
                Text(b.name)
                    .font(Schrift.winzig)
                    .foregroundStyle(istAktiv ? Farbe.text1 : Farbe.text3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(b.name)
        .accessibilityAddTraits(istAktiv ? [.isSelected, .isButton] : .isButton)
    }
}
