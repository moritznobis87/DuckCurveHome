import DuckCurveKit
import SwiftUI

/// Die Aufstellung der PV-Abrechnung: acht Spalten, zwei Kopfebenen, eine abgesetzte Summe.
///
/// **Warum nicht ``Tabelle``.** Drei Dinge hat sie nicht, und alle drei trägt diese Seite:
/// eine zweite Kopfzeile je Spalte (ohne sie heißt die dritte Spalte wie die sechste,
/// `PvAccounting.tsx:29-37`), eine Summenzeile, die durch eine stärkere Linie abgesetzt ist
/// (`:132-141`), und Spalten, die ihre Breite behalten dürfen. ``Tabelle`` legt jede Spalte mit
/// `maxWidth: .infinity` gleich breit (`Bericht.swift:282-312`); bei acht Spalten bekäme der
/// Zeitraumname ein Achtel der Karte, und „1.284,5“ stünde in derselben Breite wie „0,00“.
///
/// **Am iPad wird gewischt, und das ist die Vorlage.** Dort liegt die Tabelle in
/// `overflow-x-auto` mit `whitespace-nowrap` (`PvAccounting.tsx:109-110`): die Spalten behalten
/// ihre Breite, und wenn sie nicht passen, rollt die Tabelle. Hier dasselbe - feste Breiten in
/// einer seitlich rollbaren Fläche. Auf 1180 Punkten passen alle acht und es rollt nichts.
///
/// **Am Telefon eine Spalte mit Umschalter.** `handy.css`, Entscheidung 4: „Tabellen werden
/// Listen.“ Die Vorlage macht hier selbst eine Ausnahme - die Aufstellung trägt keine der vier
/// Klassen, die `handy.css:305-347` in Listen wandelt, und bleibt eine Tabelle, die man über
/// acht Spalten wischt. Das ist der eine Punkt, an dem diese Seite über die Vorlage hinausgeht:
/// ein Beleg, auf dem man die Spalte wählt, ist auf 390 Punkten lesbar, einer zum Wischen nicht.
struct Abrechnungstabelle: View {
    let aufstellung: Pvabrechnung.Aufstellung

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gezeigt: Int = 0

    private var schmal: Bool { breite == .compact }

    /// Die Breite des Zeitraumnamens. „Sept.“ und „KW 46“ brauchen nicht mehr.
    private let namensbreite: CGFloat = 92
    /// Die Breite einer Zahlenspalte. „1.284,5“ und „105,31 €“ passen hinein, ohne zu rutschen.
    private let spaltenbreite: CGFloat = 88

    var body: some View {
        if schmal {
            handyfassung
        } else {
            rollbareTabelle
        }
    }

    // MARK: - Am iPad: acht Spalten, die ihre Breite behalten

    private var rollbareTabelle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                koepfe
                Divider().overlay(Farbe.linie2)
                ForEach(Array(aufstellung.zeilen.enumerated()), id: \.offset) { stelle, zeile in
                    if stelle > 0 { Divider().overlay(Farbe.linie1) }
                    breiteZeile(zeile, hervorgehoben: false)
                }
                summenzeile
            }
        }
    }

    /// Die Kopfzeile mit beiden Ebenen: der Name, darunter leiser die Einheit oder die Seite,
    /// auf die sich die Steuer bezieht (`PvAccounting.tsx:116`).
    private var koepfe: some View {
        HStack(spacing: 0) {
            Text("Zeitraum")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .frame(width: namensbreite, alignment: .leading)
            ForEach(aufstellung.spalten) { spalte in
                VStack(alignment: .trailing, spacing: 1) {
                    Text(spalte.kopf)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text2)
                    Text(spalte.unter)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
                .lineLimit(1)
                .frame(width: spaltenbreite, alignment: .trailing)
            }
        }
        .padding(.bottom, 5)
    }

    /// **Die Summe hebt sich über die Größe ab, nicht über die Strichstärke.** Die Vorlage
    /// setzt sie halbfett (`:133-140`); IBM Plex Mono liegt in dieser Anwendung nur in einem
    /// Schnitt vor, und eine aufgerechnete Strichstärke sieht in einer Zahlenspalte nach
    /// Druckfehler aus - dieselbe Entscheidung wie im ``Spannenstreifen``. Die stärkere Linie
    /// darüber (`border-top: 2px solid var(--line-2)`) trägt den Rest.
    private var summenzeile: some View {
        VStack(spacing: 0) {
            Divider().overlay(Farbe.linie2)
            Divider().overlay(Farbe.linie2)
            breiteZeile(aufstellung.summe, hervorgehoben: true)
        }
    }

    private func breiteZeile(_ zeile: Pvabrechnung.Abrechnungszeile, hervorgehoben: Bool)
        -> some View
    {
        HStack(spacing: 0) {
            Text(zeile.wort)
                .font(hervorgehoben ? Schrift.karte : Schrift.klein)
                .foregroundStyle(hervorgehoben ? Farbe.text1 : Farbe.text2)
                .lineLimit(1)
                .frame(width: namensbreite, alignment: .leading)
            ForEach(Array(aufstellung.spalten.enumerated()), id: \.offset) { stelle, spalte in
                Text(zelle(zeile, stelle))
                    .font(hervorgehoben ? Schrift.zahl : Schrift.zahlKlein)
                    .foregroundStyle(farbe(spalte))
                    .lineLimit(1)
                    .frame(width: spaltenbreite, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Am Telefon: eine Spalte, die man wählt

    private var handyfassung: some View {
        VStack(alignment: .leading, spacing: 10) {
            umschalter
            VStack(spacing: 0) {
                ForEach(Array(aufstellung.zeilen.enumerated()), id: \.offset) { stelle, zeile in
                    if stelle > 0 { Divider().overlay(Farbe.linie1) }
                    schmaleZeile(zeile, hervorgehoben: false)
                }
                Divider().overlay(Farbe.linie2)
                Divider().overlay(Farbe.linie2)
                schmaleZeile(aufstellung.summe, hervorgehoben: true)
            }
        }
    }

    /// Die Pillen tragen beide Kopfebenen: „USt darauf“ allein stünde zweimal da, und eine
    /// Wahl zwischen zwei gleich benannten Spalten ist keine.
    private var umschalter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(aufstellung.spalten.enumerated()), id: \.offset) { stelle, spalte in
                    Button {
                        gezeigt = stelle
                    } label: {
                        pille(spalte, an: stelle == gezeigt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        stelle == gezeigt ? [.isButton, .isSelected] : [.isButton])
                }
            }
        }
    }

    private func pille(_ spalte: Pvabrechnung.Abrechnungsspalte, an: Bool) -> some View {
        Text(spalte.name)
            .font(Schrift.winzig)
            .foregroundStyle(an ? Farbe.deep : Farbe.text2)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(an ? Farbe.amberWeich : Farbe.flaeche3)
            .clipShape(Capsule())
    }

    private func schmaleZeile(_ zeile: Pvabrechnung.Abrechnungszeile, hervorgehoben: Bool)
        -> some View
    {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(zeile.wort)
                .font(hervorgehoben ? Schrift.karte : Schrift.sans(14.5))
                .foregroundStyle(hervorgehoben ? Farbe.text1 : Farbe.text2)
            Spacer(minLength: 8)
            Text(zelle(zeile, gezeigt))
                .font(hervorgehoben ? Schrift.mono(16) : Schrift.mono(15))
                .foregroundStyle(gewaehlteFarbe)
                .lineLimit(1)
        }
        .padding(.vertical, 9)
    }

    private var gewaehlteFarbe: Color {
        guard gezeigt < aufstellung.spalten.count else { return Farbe.text1 }
        return farbe(aufstellung.spalten[gezeigt])
    }

    // MARK: - Zelle und Farbe

    /// **Die Zahllast trägt Farbe, die anderen sechs nicht** (`PvAccounting.tsx:126`). Sie ist
    /// die Zahl, die aus dieser Seite in ein Formular wandert; alles andere ist ihre Herleitung.
    private func farbe(_ spalte: Pvabrechnung.Abrechnungsspalte) -> Color {
        spalte.betont ? Farbe.amber : Farbe.text1
    }

    private func zelle(_ zeile: Pvabrechnung.Abrechnungszeile, _ spalte: Int) -> String {
        guard spalte >= 0, spalte < zeile.zellen.count else { return Formate.leer }
        return zeile.zellen[spalte]
    }
}
