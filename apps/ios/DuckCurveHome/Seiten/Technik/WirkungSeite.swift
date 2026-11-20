import DuckCurveKit
import SwiftUI

/// Wirkung: was der Freigabekontakt K1 wirklich auslöst.
///
/// **Das ist die Ereignisstudie, und sie ist die ehrlichste Seite des Projekts.** K1 ist eine
/// Anforderung, keine Garantie: die Wärmepumpe hat ihren eigenen Regler und darf nein sagen. Die
/// Frage „folgt sie überhaupt?" ist damit eine empirische, und hier steht die Antwort samt
/// Vertrauensbereich.
struct WirkungSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tage = 30
    @State private var wirkung: KontaktwirkungOut?
    @State private var fehler: ApiFehler?
    @State private var laedtNeu = false

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            if let w = wirkung {
                let bild = Wirkungsbild.baue(w)
                urteilskarte(bild)
                Kachelfeld(
                    kacheln: Wirkungskacheln.kacheln(w).map(Kacheldaten.init),
                    kicker: bild.spanne ?? "\(w.days) Tage",
                    spalten: 3
                )
                if !bild.faecher.isEmpty {
                    Karte(
                        kicker: "Antwortfächer",
                        beiwerk: AnyView(
                            Text(
                                "\(w.nAuswertbar ?? 0) Anforderungen bei stehender Maschine, "
                                    + "am Beginn übereinandergelegt"
                            )
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                            .lineLimit(1)
                        )
                    ) {
                        Antwortfaecher(bild: bild)
                    }
                }
                if !bild.gruppen.isEmpty {
                    Karte(
                        kicker: "Jede Anforderung",
                        beiwerk: AnyView(
                            Text("sortiert nach Verzögerung")
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                        )
                    ) {
                        Ereignisraster(bild: bild)
                    }
                }
                // **Offen, nicht zugeklappt** (`Wirkung.tsx:240`): was eine Zahl an diesem
                // Zeitraum einschränkt, darf nicht hinter einem Deckel liegen.
                if !w.hinweiseDe.isEmpty {
                    Karte(kicker: "Zu diesem Zeitraum") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(w.hinweiseDe, id: \.self) { satz in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("·").font(Schrift.klein).foregroundStyle(Farbe.text3)
                                    Text(satz)
                                        .font(Schrift.klein)
                                        .foregroundStyle(Farbe.text2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                if !w.methodeDe.isEmpty {
                    Methode(
                        w.methodeDe.map(Optional.init),
                        kurz: "ein Zusammenhang in der Zeit, keine Ursache · Vergleich zur "
                            + "selben Tageszeit",
                        titel: "Was die Auswertung kann"
                    )
                }
            } else if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            } else {
                Karte { Leer(satz: "Die Anforderungen werden gesucht.") }
            }
        }
        .task(id: tage) { await lade() }
    }

    /// Die Urteilskarte: links der Satz, rechts der Quotenvergleich.
    ///
    /// **Der Satz und das Bild gehören nebeneinander** (`globals.css:648`: zwei Spalten,
    /// darunter 900 Punkten eine). Der Satz sagt, was herauskam; das Bild sagt, wie sicher das
    /// ist - und erst beides zusammen ist das Urteil. In der App stand nur der Satz, klein, in
    /// einer Karte ohne Bild.
    @ViewBuilder private func urteilskarte(_ bild: Wirkungsbild) -> some View {
        Karte(
            kicker: "Folgt die Wärmepumpe der Anforderung?",
            beiwerk: bild.spanne.map { s in
                AnyView(
                    Text(s).font(Schrift.zahlKlein).foregroundStyle(Farbe.text3))
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text("Zeitraum").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    // Die Vorlage zieht hier `.wg-wahl` (`Wirkung.tsx:149`), nicht
                    // `.kl-knopf`: die kleine Mono-Kapsel, die neben die beiden winzigen
                    // Beschriftungen dieser Zeile passt.
                    Tagewahl(tage: $tage, moeglich: [7, 30, 90], form: .wgWahl)
                    if laedtNeu {
                        Text("wird neu gerechnet")
                            .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                    Spacer(minLength: 0)
                }
                if let fehler {
                    Stoerung(fehler: fehler) { Task { await lade() } }
                }
                if schmal {
                    urteilssatz(bild)
                    Quotenbild(bild: bild, ringfarbe: Farbe.flaeche2)
                } else {
                    HStack(alignment: .center, spacing: 28) {
                        urteilssatz(bild)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Quotenbild(bild: bild, ringfarbe: Farbe.flaeche1)
                            .frame(maxWidth: 460)
                    }
                }
            }
        }
    }

    private func urteilssatz(_ bild: Wirkungsbild) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(wort: "Urteil · \(bild.urteilswort)")
            Text(bild.urteilssatz ?? "Noch kein Urteil.")
                .font(Schrift.sans(20, relativeTo: .title3))
                .foregroundStyle(Farbe.text1)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func lade() async {
        laedtNeu = wirkung != nil
        defer { laedtNeu = false }
        do {
            wirkung = try await haus.api.kontaktwirkung(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}
