import DuckCurveKit
import SwiftUI

/// Die vier Beträge am Kopf der Kostenseite: eine Zeile am iPad, ein Raster am Telefon.
///
/// **Warum nicht ``Kachelfeld``.** Zwei Dinge unterscheiden diesen Block von einem
/// Kennzahlraster, und beide stehen in der Vorlage mit Begründung. Erstens trennt sie die vier
/// Beträge am Schirm durch **senkrechte** Haarlinien in einer einzigen Reihe
/// (`divide-x divide-line-1`, `CostReport.tsx:111`); ``Kachelfeld`` trennt nur waagerecht und
/// setzt zwei Spalten (`Gestalt/Karte.swift`). Eine Reihe sagt „das sind die vier Zahlen
/// dieses Zeitraums“, ein Raster sagt „das sind vier von vielen“. Zweitens steht die
/// nicht führende Zahl dort in 34 Punkten und nicht in 25 (`CostReport.tsx:37`).
///
/// **Am Telefon ist es ein anderes Bild, und die Vorlage sagt warum** (`handy.css:349-358`):
/// „Vier Beträge nebeneinander liefen bei 34 Punkt Schrift ineinander. Jetzt wie die
/// Kennzahlen: der bezahlte Betrag führt, die übrigen stehen darunter.“ Also „Bezahlt“ über
/// die ganze Breite in 48 Punkten, dann zwei Spalten in 25 Punkten, und eine Zahl, die allein
/// übrig bleibt, nimmt wieder die ganze Zeile (`:last-child:nth-child(even)`). Statt der
/// senkrechten Linien stehen dort waagerechte, die erste Reihe ohne.
struct Betragszeile: View {
    let betraege: [Gelduebersicht.Betrag]

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        if schmal {
            raster
        } else {
            reihe
        }
    }

    // MARK: - Am iPad: eine Reihe mit senkrechten Haarlinien

    /// `px-5 py-1`, erstes ohne links, letztes ohne rechts (`CostReport.tsx:35`) - und
    /// zwischen je zwei eine Linie, nicht an jedem Rand eine.
    private var reihe: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(betraege.enumerated()), id: \.offset) { stelle, b in
                if stelle > 0 { haarlinie }
                betrag(b, zahlschrift: Schrift.custom(34), sperrung: -1.02, zeilen: 2, abstand: 4)
                    .padding(.leading, stelle == 0 ? 0 : 20)
                    .padding(.trailing, stelle == betraege.count - 1 ? 0 : 20)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Die senkrechte Trennung. Ein ``Divider`` in einem `HStack` wäre dasselbe Mittel, nimmt
    /// aber seine Farbe aus der Umgebung; hier soll es `--line-1` sein wie in der Vorlage.
    private var haarlinie: some View {
        Rectangle()
            .fill(Farbe.linie1)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Am Telefon: eine führende Zahl, dann zwei Spalten

    private var raster: some View {
        VStack(spacing: 0) {
            ForEach(Array(reihen.enumerated()), id: \.offset) { stelle, zeile in
                if stelle > 0 { Divider().overlay(Farbe.linie1) }
                HStack(alignment: .top, spacing: 20) {
                    ForEach(zeile) { b in
                        betrag(
                            b, zahlschrift: zahlschrift(b), sperrung: sperrung(b),
                            zeilen: 3, abstand: fuehrt(b) ? 8 : 5
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, stelle == 0 ? 2 : 13)
                .padding(.bottom, 14)
            }
        }
    }

    /// Die erste Zahl allein, dann Paare - und bleibt eine übrig, steht sie allein
    /// (`handy.css:352-354`). Bei vier Beträgen heißt das: eine, zwei, eine.
    private var reihen: [[Gelduebersicht.Betrag]] {
        guard let erste = betraege.first else { return [] }
        var aus: [[Gelduebersicht.Betrag]] = [[erste]]
        var rest = Array(betraege.dropFirst())
        while !rest.isEmpty {
            let wieviele = min(2, rest.count)
            aus.append(Array(rest.prefix(wieviele)))
            rest.removeFirst(wieviele)
        }
        return aus
    }

    private func fuehrt(_ b: Gelduebersicht.Betrag) -> Bool {
        b.wort == betraege.first?.wort
    }

    private func zahlschrift(_ b: Gelduebersicht.Betrag) -> Font {
        fuehrt(b) ? Schrift.custom(48) : Schrift.custom(25)
    }

    /// Die Sperrung in Punkten. Die Vorlage setzt `-.03em` an jeder Zahl und `-0.04em` an der
    /// führenden am Telefon (`CostReport.tsx:37`, `handy.css:356`); `em` mal Schriftgröße
    /// ergibt die Punkte.
    private func sperrung(_ b: Gelduebersicht.Betrag) -> CGFloat {
        fuehrt(b) ? -1.92 : -0.75
    }

    // MARK: - Ein Betrag

    /// Wort, Zahl, Hinweis - in dieser Reihenfolge, wie in der Vorlage (`CostReport.tsx:34-41`)
    /// und wie auf jeder Kachel dieser Anwendung: das Auge sucht in einer Spalte erst den
    /// Namen und dann den Wert.
    private func betrag(
        _ b: Gelduebersicht.Betrag, zahlschrift: Font, sperrung: CGFloat, zeilen: Int,
        abstand: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: abstand) {
            Kicker(wort: b.wort)
            Text(b.wert)
                .font(zahlschrift)
                .kerning(sperrung)
                .foregroundStyle(Geldfarbe.zu(b.ton))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let dazu = b.dazu {
                Text(dazu)
                    .font(Schrift.sans(zeilen > 2 ? 13 : 12))
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(zeilen)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
