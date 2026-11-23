import DuckCurveKit
import SwiftUI

/// Die Karte „Schalter“: je Einstellung, die nur Stufen kennt, ein Kasten mit einer Reihe
/// Knöpfe (`Regler.tsx:170-199`).
///
/// **Die Stufe ist eine Wahl und keine Zählung.** In der App stand die Stufe bis zum 20.11.2026
/// als Wort rechts in einer Zeile und wurde mit einem `Stepper` durchgezählt – „0 aus“, „1 nach
/// Zeitprogramm“, „2 immer an“ sind aber drei Möglichkeiten und keine Skala, und ein Stepper
/// läuft auf dem Weg von 0 nach 2 durch die 1 hindurch. An einem Warmwasserspeicher ist das ein
/// Unterschied.
///
/// **Zwei Striche, zwei Aussagen** (`globals.css:1010-1015`): gefüllt ist die Stufe, die
/// dasteht – bernsteinfarben, sobald sie ein Entwurf ist. Der dicke Strich unten sitzt an der
/// Stufe, die **am Regler** steht. Darum endet die Karte mit dem Satz: „Die Stufe mit dem
/// Strich darunter ist die, die am Regler steht.“
struct Schalterkarte: View {
    let schalter: [ReglerEinstellungOut]
    let entwurf: Reglerpult.Entwurf
    let stellenMoeglich: Bool
    /// Ob der Mensch stellen darf – getrennt von ``stellenMoeglich``, das in die Sperrlogik des
    /// Kerns geht. Hier hängt nur der Vergleichsknopf daran (siehe ``Vergleichsknopf``).
    let darfStellen: Bool
    let stelle: (String, Double) -> Void
    let vergleichen: (ReglerEinstellungOut) -> Void

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }
    /// Höhe eines Griffs – und die Mindestgröße, die eine Fläche hat, die mit dem Daumen
    /// getroffen wird (`Bausteine/Speichersteuerkarte.swift:34-36`).
    private let griffhoehe: CGFloat = 44

    var body: some View {
        if !schalter.isEmpty {
            Karte(kicker: "Schalter") {
                VStack(alignment: .leading, spacing: 10) {
                    feld
                    Text(Reglerpult.stufensatz)
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Am iPad zwei Spalten, am Telefon eine (`globals.css:1005`, `handy.css:236`).
    private var feld: some View {
        LazyVGrid(columns: spalten, alignment: .leading, spacing: 14) {
            ForEach(schalter, id: \.schluessel) { w in
                kasten(w)
            }
        }
    }

    private var spalten: [GridItem] {
        let eine = [GridItem(.flexible(), spacing: 14, alignment: .top)]
        guard !schmal else { return eine }
        return Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 2)
    }

    // MARK: - Ein Kasten

    private func kasten(_ w: ReglerEinstellungOut) -> some View {
        let frei = Reglerpult.bedienbar(w, stellenMoeglich: stellenMoeglich)
        return VStack(alignment: .leading, spacing: 8) {
            name(w)
            stufen(w, frei: frei)
            if let hinweis = w.hinweisDe, !hinweis.isEmpty {
                Text(hinweis)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Reglerfuss(
                stand: Reglerpult.fuss(w, stellenMoeglich: stellenMoeglich),
                darfStellen: darfStellen, mittig: false,
                vergleichen: { vergleichen(w) })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.14), in: umriss)
        .overlay(umriss.strokeBorder(geaendert(w) ? Farbe.amber.opacity(0.6) : Farbe.linie1, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(w.gruppeDe): \(w.nameDe)")
    }

    private var umriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    private func geaendert(_ w: ReglerEinstellungOut) -> Bool {
        guard let gezeigt = Reglerpult.sichtbar(w, entwurf: entwurf), let ist = w.wert.belastbar
        else { return false }
        return gezeigt != ist
    }

    /// „Warmwasser: Betriebsart“, und bei einem Stellbefehl nach Muster der Zusatz dahinter
    /// (`Regler.tsx:180-183`).
    ///
    /// **Der Zusatz steht da, weil er eine Einschränkung ist.** Ein Befehl, der nach einem
    /// Muster gebildet wird, ist nicht aus der Busbeschreibung abgelesen, sondern geraten – und
    /// das gehört neben den Namen und nicht in eine Fußnote.
    private func name(_ w: ReglerEinstellungOut) -> some View {
        Umbruchzeile(abstand: 4, zeilenabstand: 2) {
            Text("\(w.gruppeDe): \(w.nameDe)")
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text1)
            if w.muster == true {
                Text("· Stellbefehl nach Muster gebildet")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    // MARK: - Die Stufen

    private func stufen(_ w: ReglerEinstellungOut, frei: Bool) -> some View {
        let gezeigt = Reglerpult.sichtbar(w, entwurf: entwurf)
        let ist = w.wert.belastbar
        return Umbruchzeile(abstand: 6, zeilenabstand: 6) {
            ForEach(Reglerpult.stufen(w), id: \.zahl) { stufe in
                stufenknopf(
                    w, stufe: stufe, gewaehlt: gezeigt == stufe.zahl, amRegler: ist == stufe.zahl,
                    entwurf: gezeigt == stufe.zahl && ist != stufe.zahl, frei: frei)
            }
        }
    }

    private func stufenknopf(
        _ w: ReglerEinstellungOut, stufe: Reglerpult.Stufe, gewaehlt: Bool,
        amRegler: Bool, entwurf: Bool, frei: Bool
    ) -> some View {
        Button {
            stelle(w.schluessel, stufe.zahl)
        } label: {
            stufenwort(stufe, gewaehlt: gewaehlt)
                .padding(.horizontal, 12)
                .frame(minHeight: griffhoehe)
                .background(stufengrund(gewaehlt: gewaehlt, entwurf: entwurf))
                .overlay(stufenrand(gewaehlt: gewaehlt, entwurf: entwurf))
                // **Der dicke Strich lässt sich nicht als Rand bauen** – ein `strokeBorder` ist
                // überall gleich dick (`globals.css:1011-1012`). Also eine Fläche am unteren
                // Rand, innerhalb des Beschnitts. Vorbild: `Speichersteuerkarte.swift:160-164`.
                .overlay(alignment: .bottom) {
                    if amRegler {
                        Rectangle().fill(Farbe.text2).frame(height: 3)
                    }
                }
                .clipShape(stufenumriss)
        }
        .buttonStyle(.plain)
        .disabled(!frei)
        .opacity(frei ? 1 : 0.55)
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint(amRegler ? "Steht am Regler" : "")
    }

    /// Die Zahl in Mono, das Wort daneben: der Regler kennt nur die Zahl, das Wort ist die
    /// Lesart der Busbeschreibung (`Regler.tsx:187`).
    private func stufenwort(_ stufe: Reglerpult.Stufe, gewaehlt: Bool) -> some View {
        HStack(spacing: 5) {
            Text(Formate.zahl(stufe.zahl, stellen: 0))
                .font(Schrift.zahlKlein)
            Text(stufe.wort)
                .font(gewaehlt ? Schrift.sans(13, relativeTo: .footnote) : Schrift.klein)
        }
        .foregroundStyle(gewaehlt ? Farbe.petrol : Farbe.text2)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .padding(.vertical, 8)
    }

    private var stufenumriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    private func stufengrund(gewaehlt: Bool, entwurf: Bool) -> Color {
        guard gewaehlt else { return Farbe.flaeche2 }
        return entwurf ? Farbe.amber : Farbe.waermepumpe
    }

    private func stufenrand(gewaehlt: Bool, entwurf: Bool) -> some View {
        stufenumriss.strokeBorder(
            gewaehlt ? (entwurf ? Farbe.amber : Farbe.waermepumpe) : Farbe.linie2, lineWidth: 1)
    }
}
