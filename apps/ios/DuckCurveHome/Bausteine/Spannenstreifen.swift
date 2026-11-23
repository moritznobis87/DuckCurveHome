import DuckCurveKit
import SwiftUI

/// Vier Spannen zum selben Anker nebeneinander – am Telefon eine davon.
///
/// **Warum ein eigener Baustein und nicht ``Tabelle``.** Die Vorlage benutzt diesen Streifen auf
/// sieben Berichtsseiten (`PeriodStrip` in `HouseReport`, `PvReport`, `EvReport`,
/// `PvAccounting`, `BatteryReport`, `CostReport`, `HeatOverview`), und drei Dinge hat ``Tabelle``
/// nicht: einen Kopf über der ersten Spalte, die Regel, dass die Tagesspalte nur „Heute“ heißt,
/// wenn sie es auch ist, und den Hinweis „jeweils bis …“ im Kartenkopf
/// (`PeriodStrip.tsx:11-16,34-38`). Ohne den Hinweis stehen vier Zahlen da, ohne zu sagen, bis
/// wann sie zählen.
///
/// **Am Telefon ist es eine andere Ansicht, nicht dieselbe in einer Spalte.** Die Begründung
/// steht in der Vorlage (`PeriodStrip.tsx:28-30`): „Vier Zahlenspalten neben dem Namen der Zeile
/// passen nicht auf 390 Punkte: die Namen wurden abgeschnitten, die Zahlen liefen ineinander.“
/// Dort steht deshalb ein Reihenschalter über einer Liste, die eine Spanne in lesbarer Größe
/// zeigt (`handy.css:291-299`).
///
/// **Die Zahlen kommen aus einem eigenen Zustand und dürfen fehlen.** Die vier Spalten hängen
/// am Ankertag und nicht an der gewählten Spanne; sie werden darum neben der Seite geholt
/// (``Spannenstand``) und treffen später ein als ihre Kacheln. Solange eine Spalte fehlt, steht
/// in ihren Zellen ein Strich - die Zeilen bringen ihn selbst mit (``Streifenzeile``), und so
/// macht es die Vorlage auch: dort fragt die Zeile ihren Wert je Spanne ab
/// (`PeriodStrip.tsx:18`, `:58`, `:85`), und der Aufrufer antwortet mit „-“, wo er keinen hat
/// (`HouseReport.tsx:39`).
struct Spannenstreifen: View {
    let titel: String
    let zeilen: [Streifenzeile]
    /// Der Ankertag, auf den sich alle vier Spalten beziehen.
    let anker: String
    let jetzt: Date

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gewaehlt: Spanne = .tag

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Karte(kicker: titel, beiwerk: AnyView(hinweis)) {
            if schmal {
                handyfassung
            } else {
                tabelle
            }
        }
    }

    /// „jeweils bis jetzt“ oder „jeweils bis 10.11.2026“ – rechts im Kartenkopf.
    private var hinweis: some View {
        Kartenhinweis(satz: Spannenworte.bis(anker: anker, jetzt: jetzt))
    }

    // MARK: - Am iPad: vier Spalten

    private var tabelle: some View {
        VStack(spacing: 0) {
            spaltenkoepfe
            ForEach(Array(zeilen.enumerated()), id: \.offset) { stelle, zeile in
                Divider().overlay(Farbe.linie1)
                zahlenzeile(zeile, fuehrend: stelle == 0)
            }
        }
    }

    private var spaltenkoepfe: some View {
        HStack(spacing: 8) {
            // Über der ersten Spalte steht nichts: ihre Zellen sagen selbst, was sie sind.
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Spanne.allCases, id: \.self) { spanne in
                Text(Spannenworte.kopf(spanne, anker: anker, jetzt: jetzt))
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.bottom, 6)
    }

    /// **Die erste Zeile führt, und sie führt über die Größe.** Die Vorlage setzt sie halbfett
    /// (`PeriodStrip.tsx:85`); IBM Plex Mono liegt in dieser Anwendung nur in einem Schnitt vor,
    /// und eine aufgerechnete Strichstärke sieht in einer Zahlenspalte nach Druckfehler aus.
    /// Zwei Punkte mehr tun dasselbe, ohne das zu riskieren.
    private func zahlenzeile(_ zeile: Streifenzeile, fuehrend: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(zeile.wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(zeile.werte.enumerated()), id: \.offset) { _, wert in
                Text(wert)
                    .font(fuehrend ? Schrift.zahl : Schrift.zahlKlein)
                    .foregroundStyle(Farbe.ton(zeile.ton))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
    }

    // MARK: - Am Telefon: ein Schalter und eine Liste

    private var handyfassung: some View {
        VStack(alignment: .leading, spacing: 12) {
            schalter
            liste
        }
    }

    /// Der Reihenschalter, `.spannen` aus `handy.css:291-293`: eine Fläche, vier Pillen, die
    /// aktive in Bernstein auf dunklem Grund.
    private var schalter: some View {
        HStack(spacing: 2) {
            ForEach(Spanne.allCases, id: \.self) { spanne in
                Button {
                    gewaehlt = spanne
                } label: {
                    pille(spanne)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(spanne == gewaehlt ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .padding(3)
        .background(Farbe.flaeche3)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func pille(_ spanne: Spanne) -> some View {
        let an: Bool = spanne == gewaehlt
        return Text(Spannenworte.kopf(spanne, anker: anker, jetzt: jetzt))
            .font(Schrift.klein)
            .foregroundStyle(an ? Farbe.deep : Farbe.text2)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(an ? Farbe.amber : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var liste: some View {
        VStack(spacing: 0) {
            ForEach(Array(zeilen.enumerated()), id: \.offset) { stelle, zeile in
                if stelle > 0 { Divider().overlay(Farbe.linie1) }
                listenzeile(zeile)
            }
        }
    }

    private func listenzeile(_ zeile: Streifenzeile) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(zeile.wort)
                .font(Schrift.sans(14.5))
                .foregroundStyle(Farbe.text2)
            Spacer(minLength: 8)
            Text(wert(zeile))
                .font(Schrift.mono(16))
                .foregroundStyle(Farbe.ton(zeile.ton))
                .lineLimit(1)
        }
        .padding(.vertical, 11)
    }

    /// Der Wert der gewählten Spalte. Fehlt sie, steht ein Strich – nicht die Nachbarspalte.
    private func wert(_ zeile: Streifenzeile) -> String {
        guard let stelle = Spanne.allCases.firstIndex(of: gewaehlt),
              stelle < zeile.werte.count
        else { return Formate.leer }
        return zeile.werte[stelle]
    }
}
