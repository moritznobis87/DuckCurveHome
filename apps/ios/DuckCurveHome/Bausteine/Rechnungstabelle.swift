import DuckCurveKit
import SwiftUI

/// Eine Tabelle, deren Zeile ein Griff ist: Anklicken wählt die Zeile aus.
///
/// **Warum nicht ``Tabelle``.** Die ist heute reine Anzeige - keine anklickbare Zeile, keine
/// Hervorhebung (`Seiten/Bericht.swift:157-328`). Die Rechnungsseite braucht beides: dort ist
/// die Zeile der Griff, mit dem die Befunde und die Preisbestandteile darunter umgeschaltet
/// werden (`InvoiceCheck.tsx:277-279`). ``Tabelle`` darum zu erweitern wäre ein Eingriff in
/// einen Baustein, den dreizehn Seiten benutzen; also steht das Auswählen hier und ``Tabelle``
/// bleibt, wie sie ist. Die Spalten sind dieselben (``Tabelle/Spalte``), damit es nicht zwei
/// Beschreibungen derselben Sache gibt.
///
/// **Die Hervorhebung ist ``Farbe/flaeche3`` und nicht `--surface-1`, weil die App ihre
/// Kartenflächen umgekehrt belegt.** In der Vorlage steht die Karte auf `--surface-2` (#123544)
/// und die gewählte Zeile auf dem dunkleren `--surface-1` (#0F2E3D). ``Karte`` nimmt am iPad
/// `flaeche1` und am Telefon `flaeche2` - mit `flaeche1` als Hervorhebung wäre die gewählte
/// Zeile am iPad also unsichtbar und am Telefon sichtbar. `flaeche3` (#173F50) hebt sich von
/// beiden ab; der Unterschied zur Vorlage ist die Richtung, nicht die Sache.
///
/// **Am Telefon bleibt es bei einer Spalte.** `handy.css` baut Tabellen zu Listen um
/// (Entscheidung 4), und für diese Tabelle fehlt der Vorlage nur die Klasse, mit der sie
/// dieselbe Regel bekommen hätte (`handy.css:305-306`: vier Tabellen stehen dort, keine davon
/// ist diese). Acht Spalten auf 390 Punkten sind keine Tabelle, sondern ein Rollbalken.
struct Rechnungstabelle: View {
    /// Die erste Spalte ist die Beschriftung der Zeile und wird nie ausgeblendet.
    let zeilennamen: [String]
    let spalten: [Tabelle.Spalte]
    /// Welche Zeile hervorgehoben ist.
    var gewaehlt: Int?
    let waehle: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gezeigt = 0

    private var schmal: Bool { breite == .compact }

    var body: some View {
        if zeilennamen.isEmpty {
            Leer(satz: "Keine Zeilen.")
        } else if schmal {
            handyliste
        } else {
            volleTabelle
        }
    }

    // MARK: - Am Telefon: eine Spalte, umschaltbar

    private var handyliste: some View {
        VStack(alignment: .leading, spacing: 8) {
            if spalten.count > 1 {
                spaltenwahl
            }
            VStack(spacing: 0) {
                ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    griff(i) {
                        HStack {
                            Text(name).font(Schrift.klein).foregroundStyle(Farbe.text2)
                            Spacer(minLength: 8)
                            Text(zelle(spalte: gezeigt, zeile: i))
                                .font(Schrift.zahl)
                                .foregroundStyle(farbe(spalte: gezeigt, zeile: i))
                        }
                    }
                }
            }
        }
    }

    /// Die Umschaltung als Reihe von Wörtern und nicht als Menü - ein Menü versteckt, welche
    /// Spalten es gibt (``Tabelle``).
    private var spaltenwahl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(spalten.enumerated()), id: \.offset) { i, s in
                    Button {
                        gezeigt = i
                    } label: {
                        Text(s.name)
                            .font(Schrift.winzig)
                            .foregroundStyle(i == gezeigt ? Farbe.deep : Farbe.text2)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(i == gezeigt ? Farbe.amberWeich : Farbe.flaeche3)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Am iPad: alle Spalten

    private var volleTabelle: some View {
        VStack(spacing: 0) {
            kopfzeile
            Divider().overlay(Farbe.linie2)
            ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                if i > 0 { Divider().overlay(Farbe.linie1) }
                griff(i) { zeileninhalt(i, name: name) }
            }
        }
    }

    private var kopfzeile: some View {
        HStack {
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(spalten) { s in
                Text(s.name)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.bottom, 4)
    }

    private func zeileninhalt(_ i: Int, name: String) -> some View {
        HStack {
            Text(name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(spalten.enumerated()), id: \.offset) { s, _ in
                Text(zelle(spalte: s, zeile: i))
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(farbe(spalte: s, zeile: i))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Der Griff

    /// Eine Zeile als Knopf, mit der Hervorhebung der gewählten.
    ///
    /// Die Polsterung liegt **innen** und die Fläche **außen**: sonst endet die Hervorhebung am
    /// Text und nicht am Rand der Karte, und eine Zeile, deren Hintergrund schmaler ist als die
    /// Zeile, sieht aus wie ein Fehler.
    private func griff<Inhalt: View>(_ i: Int, @ViewBuilder inhalt: () -> Inhalt) -> some View {
        Button {
            waehle(i)
        } label: {
            inhalt()
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(i == gewaehlt ? Farbe.flaeche3 : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func farbe(spalte: Int, zeile: Int) -> Color {
        guard spalte < spalten.count, zeile < spalten[spalte].farben.count else {
            return Farbe.text1
        }
        return spalten[spalte].farben[zeile] ?? Farbe.text1
    }

    private func zelle(spalte: Int, zeile: Int) -> String {
        guard spalte < spalten.count, zeile < spalten[spalte].zellen.count else {
            return Formate.leer
        }
        return spalten[spalte].zellen[zeile]
    }
}
