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
            // **Die Spannen stehen ueber den Reitern** (`handy.css:151`: die Zeitraumzeile
            // bekommt `order: 3` und steht damit vor den Reitern, die als eigener Block folgen).
            // Sie gehoeren zum Bereich und nicht zur Seite: wer von „Strom" auf „Waerme"
            // wechselt, behaelt seinen Tag.
            if let spannen = Bereiche.spannen(fuer: wegweiser.weg), spannen.count > 1 {
                Spannenwahl(spannen: spannen)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            if !wegweiser.bereich.reiter.isEmpty {
                Reiterzeile(
                    bereich: wegweiser.bereich,
                    aktiv: wegweiser.reiter,
                    darfAlles: haus.darfSchalten
                ) { r in
                    wegweiser.gehe(r.weg)
                    wegweiser.merkeReiter()
                }
            }
            Seitenwahl(weg: wegweiser.weg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Alfred schwebt ueber der Seite, nicht in der Leiste: die gehoert den fuenf
                // Bereichen, und er ist keiner.
                .overlay(alignment: .bottomTrailing) { Entenknopf() }
            Bereichsleiste(wegweiser: wegweiser)
        }
    }

    /// Der Kopf: die Marke, die Temperatur draussen, der Zustand der Verbindung.
    ///
    /// **Was hier vorher stand.** Der Name der Seite in der Systemschrift, gross und links -
    /// „Jetzt". Das war an zwei Stellen falsch. Erstens sagt die Bereichsleiste unten schon,
    /// wo man ist, und die Reiterzeile darunter sagt es genauer; der Name war eine dritte
    /// Antwort auf eine Frage, die niemand gestellt hat. Zweitens war er in San Francisco
    /// gesetzt und nicht in der Schrift dieser Anwendung - die einzige Stelle der App, an der
    /// das noch so war, und die erste, die man sieht.
    ///
    /// **Jetzt wie die Wandanzeige** (`apps/web/src/components/layout/AreaNav.tsx`, `Brand`,
    /// und `home/Home.tsx:202-213`): links die Kurve und der Name, rechts die Temperatur
    /// draussen und der Punkt. Die Uhr steht nicht dabei - am Telefon steht sie zwei
    /// Millimeter darueber in der Statusleiste des Systems.
    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                wegweiser.gehe("/")
            } label: {
                HStack(spacing: 7) {
                    Zeichen(.ente, groesse: 26, farbe: Farbe.amber)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5 }
                    // **Auf einer Unterseite steht dort ihr Bereich, nicht die Marke**
                    // (`handy.css:140-141`: `.brand-name` verschwindet, `.bereichstitel`
                    // erscheint in 26 Punkten). Die Marke steht auf der Startseite; auf
                    // „Energie" will man lesen, dass man in der Energie ist.
                    Text(aufStartseite ? "Duck Curve" : wegweiser.bereich.name)
                        .font(aufStartseite ? Schrift.marke : Schrift.sans(26, relativeTo: .title))
                        .fontWeight(aufStartseite ? .regular : .semibold)
                        .kerning(aufStartseite ? 0 : -0.65)
                        .foregroundStyle(Farbe.text1)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                aufStartseite
                    ? "Duck Curve Home, zur Startseite"
                    : "\(wegweiser.bereich.name), zur Startseite")

            Spacer(minLength: 8)

            // Auf einer Seite mit Zeitraum steht rechts der Datumskasten; auf der Startseite
            // die Temperatur draussen und der Punkt der Verbindung.
            if Bereiche.spannen(fuer: wegweiser.weg) != nil {
                Datumskasten()
            } else {
                if let grad = aussen {
                    HStack(spacing: 5) {
                        Text(Formate.celsius(grad, stellen: 1))
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                        Text(haus.zustand?.system.outdoorSourceDe ?? "draußen")
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                    }
                    .accessibilityElement(children: .combine)
                }
                Verbindungspunkt()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private var aufStartseite: Bool {
        wegweiser.bereich.schluessel == .jetzt
    }

    /// Der Messwert aus dem Haus, und wenn der alt ist, der des Wetterdienstes - das
    /// entscheidet der Dienst und sagt es im Wort daneben.
    private var aussen: Double? {
        haus.zustand?.system.outdoorShownC ?? haus.augenblick?.outdoorTempC.belastbar
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
