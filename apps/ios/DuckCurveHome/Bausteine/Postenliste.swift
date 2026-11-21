import DuckCurveKit
import SwiftUI

/// Die Aufstellung der Kostenseite: fünf Spalten am iPad, zwei Zeilen je Posten am Telefon.
///
/// **Warum nicht ``Tabelle``.** Die kennt Zeichenketten und Farben, aber keinen Weg
/// (`Seiten/Bericht.swift`), und der Weg ist hier der halbe Zweck der Karte: „jede Zahl
/// darunter führt zu der Seite, auf der sie herkommt“ (`CostReport.tsx:17-20`). Dazu kommt,
/// dass ``Tabelle`` jede Spalte gleich breit legt; bei „Entgangene Vergütung (Wärmepumpe,
/// Wallbox, Speichergerät)“ neben „0,00 €“ ist das die falsche Teilung.
///
/// **Die ganze Zeile führt, nicht nur das Wort.** Die Vorlage setzt dort einen Link in 12
/// Punkten (`CostReport.tsx:54`); zwölf Punkte sind mit dem Finger kein Ziel - die
/// Bedienungshilfen nennen 44 Punkte als Mindestmaß. Der Verweis bleibt in Bernstein stehen
/// und sagt, wohin es geht; angefasst wird die Zeile.
///
/// **Am Telefon zwei Zeilen je Posten, und das ist die Vorlage** (`handy.css:304-316`):
/// „Eine Tabelle mit fünf Spalten hat am Handy 60 Punkte je Spalte.“ Oben, was die Zeile ist,
/// und der Betrag, um den es geht; darunter Menge, Preis und der Verweis.
struct Postenliste: View {
    let posten: [Gelduebersicht.Posten]

    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    /// Die Breiten der vier rechten Spalten. „1.234 kWh“, „28,4 ct“, „− 31,20 €“ und
    /// „PV-Abrechnung ›“ passen hinein, ohne zu rutschen; der Name nimmt den Rest.
    private let mengenbreite: CGFloat = 92
    private let preisbreite: CGFloat = 80
    private let betragsbreite: CGFloat = 100
    private let seitenbreite: CGFloat = 116

    var body: some View {
        if posten.isEmpty {
            Leer(satz: "Keine Posten in diesem Zeitraum.")
        } else {
            liste
        }
    }

    private var liste: some View {
        VStack(spacing: 0) {
            if !schmal { koepfe }
            ForEach(Array(posten.enumerated()), id: \.offset) { stelle, p in
                // Jede Zeile trägt oben eine Haarlinie - am Telefon die erste nicht, weil
                // dort keine Kopfzeile darüber steht (`handy.css:306`).
                if stelle > 0 || !schmal { Divider().overlay(Farbe.linie1) }
                Button {
                    wegweiser.gehe(p.weg)
                } label: {
                    if schmal {
                        schmaleZeile(p)
                    } else {
                        breiteZeile(p)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: - Am iPad: fünf Spalten

    private var koepfe: some View {
        HStack(spacing: 10) {
            Kicker(wort: spaltenkopf(0))
                .frame(maxWidth: .infinity, alignment: .leading)
            Kicker(wort: spaltenkopf(1)).frame(width: mengenbreite, alignment: .trailing)
            Kicker(wort: spaltenkopf(2)).frame(width: preisbreite, alignment: .trailing)
            Kicker(wort: spaltenkopf(3)).frame(width: betragsbreite, alignment: .trailing)
            Kicker(wort: spaltenkopf(4)).frame(width: seitenbreite, alignment: .trailing)
        }
        .padding(.bottom, 5)
    }

    private func spaltenkopf(_ stelle: Int) -> String {
        let alle = Gelduebersicht.aufstellungsspalten
        return stelle < alle.count ? alle[stelle] : ""
    }

    private func breiteZeile(_ p: Gelduebersicht.Posten) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(p.wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Eine leere Menge bleibt leer und wird nicht zum Strich: bei der entgangenen
            // Vergütung gibt es keine Menge, und ein Strich hiesse, es fehle eine.
            zahl(p.menge, Farbe.text2).frame(width: mengenbreite, alignment: .trailing)
            zahl(p.preis, Farbe.text2).frame(width: preisbreite, alignment: .trailing)
            zahl(p.betrag, Geldfarbe.zu(p.ton)).frame(width: betragsbreite, alignment: .trailing)
            verweis(p, groesse: 12).frame(width: seitenbreite, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func zahl(_ wert: String, _ farbe: Color) -> some View {
        Text(wert)
            .font(Schrift.zahlKlein)
            .foregroundStyle(farbe)
            .lineLimit(1)
    }

    // MARK: - Am Telefon: zwei Zeilen je Posten

    private func schmaleZeile(_ p: Gelduebersicht.Posten) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(p.wort)
                    .font(Schrift.sans(15))
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(p.betrag)
                    .font(Schrift.mono(17))
                    .foregroundStyle(Geldfarbe.zu(p.ton))
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if !p.menge.isEmpty {
                    Text(p.menge)
                        .font(Schrift.mono(13))
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                }
                if !p.preis.isEmpty {
                    Text(p.preis)
                        .font(Schrift.mono(13))
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                verweis(p, groesse: 13)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// „Wärme ›“ - der Pfeil sagt, dass die Zeile irgendwohin führt, wie auf einer ``Kachel``.
    private func verweis(_ p: Gelduebersicht.Posten, groesse: CGFloat) -> some View {
        Text(p.seite + " ›")
            .font(Schrift.sans(groesse))
            .foregroundStyle(Farbe.amber)
            .lineLimit(1)
    }
}
