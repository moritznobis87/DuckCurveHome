import DuckCurveKit
import SwiftUI

/// Der gestrichelte Knopf unter einem Regler: „Am Gerät steht 1,00“.
///
/// **Er sendet nichts an die Pumpe.** Er vermerkt, dass jemand am Bediengerät nachgesehen hat,
/// und schaltet damit die Sperre „nicht verglichen“ ab (`Regler.tsx:108-111`). Der gelesene
/// Wert steht im Knopftext, damit man ihn am Gerät gegenlesen kann, ohne hin- und herzusehen –
/// und darum sagt der Anleitungsabsatz der Seite ausdrücklich: steht dort etwas anderes, ist
/// die Kennung für diese Anlage falsch gelesen, **dann nicht drücken** (`Regler.tsx:133`).
///
/// **Gestrichelt, weil er kein Stellbefehl ist.** Die Knöpfe, die senden, sind gefüllt und
/// bernsteinfarben; dieser ist ein Haken und sieht aus wie einer (`globals.css:1000-1001`).
/// In der App hieß er bis zum 20.11.2026 „Verglichen“ und nannte den Wert nicht – damit fehlte
/// genau die Gegenprobe, um die es geht.
///
/// **Er hängt an `hatVollzugriff` wie jeder andere Griff an den Regler.** Er sendet keinen
/// Stellbefehl, aber er schaltet den Sperrgrund „nicht verglichen“ ab – und zwar für alle, am
/// Dienst, dauerhaft. Danach gehen die Schieber, die Kurvengriffe und die Stufenknöpfe des
/// Hausherrn auf. Ein Gast käme damit an die Anlage, ohne je am Bediengerät gestanden zu haben;
/// im Browser verwehrt das BFF einem Gast jedes Nicht-GET mit 403
/// (`apps/web/src/app/api/dch/[...path]/route.ts:31-38`), und die App hat diese Tür nicht –
/// `rolle` blendet hier nur aus (`Netz/Zugang.swift:33-39`). Also muss sie ausblenden.
struct Vergleichsknopf: View {
    let satz: String
    /// Darf der Mensch an dieser App überhaupt stellen? (`haus.hatVollzugriff`)
    let darfStellen: Bool
    let tun: () -> Void

    var body: some View {
        Button(action: tun) {
            Text(satz)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Farbe.amber.opacity(0.09), in: umriss)
                .overlay(
                    umriss.strokeBorder(
                        Farbe.amber.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        }
        .buttonStyle(.plain)
        .disabled(!darfStellen)
        .opacity(darfStellen ? 1 : 0.45)
        .accessibilityHint("Vermerkt, dass diese Einstellung mit dem Bediengerät verglichen ist")
    }

    private var umriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }
}

/// Die Fußzeile unter einem Kanalzug oder Schalter, in vier Fassungen.
///
/// Die Entscheidung, welche davon dasteht, trifft ``Reglerpult/fuss(_:stellenMoeglich:)`` – hier
/// bleiben die Maße (`Regler.tsx:103-115`, `globals.css:999-1002`).
struct Reglerfuss: View {
    let stand: Reglerpult.Fussstand
    /// Getrennt von der Sperrlogik: `stellenMoeglich` sagt, ob der **Regler** sich stellen
    /// lässt, dies, ob der **Mensch** stellen darf. Die Sperre „nicht verglichen“ steht auch
    /// einem Gast im Weg – nur abschalten darf er sie nicht.
    var darfStellen: Bool = true
    var mittig: Bool = true
    let vergleichen: () -> Void

    var body: some View {
        inhalt
            .frame(
                minHeight: mittig ? 30 : 0,
                alignment: mittig ? .top : .topLeading)
            .frame(maxWidth: .infinity, alignment: mittig ? .center : .leading)
    }

    @ViewBuilder private var inhalt: some View {
        switch stand {
        case .vergleichen(let satz):
            Vergleichsknopf(satz: satz, darfStellen: darfStellen, tun: vergleichen)
        case .wartet(let satz):
            wort(satz, farbe: Farbe.amber)
        case .grund(let satz):
            wort(satz, farbe: Farbe.text3)
        case .gelesen(let satz):
            wort(satz, farbe: Farbe.text3)
        }
    }

    private func wort(_ satz: String, farbe: Color) -> some View {
        Text(satz)
            .font(Schrift.winzig)
            .foregroundStyle(farbe)
            .multilineTextAlignment(mittig ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
