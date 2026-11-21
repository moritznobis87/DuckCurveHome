import DuckCurveKit
import SwiftUI

/// Wirkung: was der Freigabekontakt K1 wirklich auslöst.
///
/// **Das ist die Ereignisstudie, und sie ist die ehrlichste Seite des Projekts.** K1 ist eine
/// Anforderung, keine Garantie: die Wärmepumpe hat ihren eigenen Regler und darf nein sagen. Die
/// Frage „folgt sie überhaupt?“ ist damit eine empirische, und hier steht die Antwort samt
/// Vertrauensbereich.
///
/// **Die Urteilskarte steht immer, auch ohne Daten** (`Wirkung.tsx:144-168`). Vorher ersetzte
/// eine Störung die ganze Seite, und damit war die Zeitraumwahl weg - wer sich den Fehler bei
/// 90 Tagen holte, kam nicht auf 7 zurück, ohne die Seite zu verlassen. Dasselbe Muster und
/// dieselbe Begründung stehen in ``NachbetrachtungSeite`` („die Tagwahl bleibt bedienbar, und
/// wer einen anderen Tag nimmt, kommt aus dem Fehler heraus“).
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
            let bild = wirkung.map(Wirkungsbild.baue)
            urteilskarte(bild)
            if let w = wirkung, let bild {
                // Kein Kicker über dem Kachelfeld: der ausgewertete Zeitraum steht schon als
                // Beiwerk der Urteilskarte, und die Vorlage setzt über das Feld keine
                // Überschrift (`Wirkung.tsx:171`).
                // **Zwei Spalten am Telefon, drei am iPad, fuenf an der Wand**
                // (`Wirkung.tsx:171`: `grid-cols-2 md:grid-cols-3 xl:grid-cols-5`). Hier stand
                // fest `spalten: 3`, und damit fehlte die obere Stufe; ``Kachelfeld`` misst sich
                // dafuer selbst. Die Werte sind Spannen und bekommen am Telefon eine Stufe
                // weniger (`handy.css:381-382`, `.kpi-handy`).
                Kachelfeld(
                    kacheln: Wirkungskacheln.kacheln(w).map(Kacheldaten.init),
                    spannen: true,
                    staffelung: Kachelraster(mittel: 3, breit: 5)
                )
                if bild.faecherZeigen {
                    faecherkarte(bild)
                }
                if bild.rasterZeigen {
                    Karte(kicker: "Jede Anforderung", beiwerk: rasterbeiwerk) {
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
                    // **Eine echte Liste und nicht Absätze** (`Wirkung.tsx:254-258`: eine
                    // `<ul>` im Methodendeckel, gestaltet in `globals.css:735`).
                    Methode(
                        [],
                        kurz: "ein Zusammenhang in der Zeit, keine Ursache · Vergleich zur "
                            + "selben Tageszeit",
                        titel: "Was die Auswertung kann",
                        punkte: w.methodeDe
                    )
                }
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
    ///
    /// **Ohne Daten bleibt der Kopf stehen** und darunter steht, woran es liegt: die Störung
    /// oder der Satz der ersten Ladung (`Wirkung.tsx:156-157`). Die Zeitraumwahl bleibt in
    /// beiden Fällen bedienbar.
    @ViewBuilder private func urteilskarte(_ bild: Wirkungsbild?) -> some View {
        Karte(
            kicker: "Folgt die Wärmepumpe der Anforderung?",
            beiwerk: bild?.spanne.map { s in
                AnyView(
                    Text(s).font(Schrift.zahlKlein).foregroundStyle(Farbe.text3))
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                zeitraumzeile
                if let fehler {
                    Stoerung(fehler: fehler) { Task { await lade() } }
                }
                if let bild {
                    urteilsraster(bild)
                } else if fehler == nil {
                    // Die kleine Stufe: der Hinweis teilt seine Karte mit der Zeitraumzeile
                    // darüber, die während der Suche bedienbar bleibt
                    // (``Ladehinweis/Stufe``). Der Satz steht jetzt im Kern.
                    Ladeente(satz: Wirkungsbild.laedtSatz)
                }
            }
        }
    }

    private var zeitraumzeile: some View {
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
    }

    @ViewBuilder private func urteilsraster(_ bild: Wirkungsbild) -> some View {
        if schmal {
            urteilssatz(bild)
            Quotenbild(bild: bild)
        } else {
            HStack(alignment: .center, spacing: 28) {
                urteilssatz(bild)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Quotenbild(bild: bild)
                    .frame(maxWidth: 460)
            }
        }
    }

    /// **Der Urteilssatz wächst mit der Breite** (`globals.css:650`:
    /// `clamp(17px, 2vw, 22px)`, dazu `max-width: 60ch`). Er stand fest auf 20 Punkten: am
    /// Telefon drei Punkte zu groß für eine Spalte von 358 Punkten, an der Wand zwei zu klein
    /// für den Satz, der die Seite trägt. Die 640 Punkte sind die 60 Zeichen der Vorlage in
    /// dieser Schrift - ein Satz, der über die ganze Wand läuft, ist nicht mehr zu lesen.
    private func urteilssatz(_ bild: Wirkungsbild) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(wort: "Urteil · \(bild.urteilswort)")
            Text(bild.urteilssatz ?? "Noch kein Urteil.")
                .font(Schrift.sans(schmal ? 17 : 22, relativeTo: .title3))
                .foregroundStyle(Farbe.text1)
                .lineSpacing(5)
                .frame(maxWidth: 640, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Die beiden Zeichnungskarten

    @ViewBuilder private func faecherkarte(_ bild: Wirkungsbild) -> some View {
        let satz =
            "\(bild.nAuswertbar) Anforderungen bei stehender Maschine, "
            + "am Beginn übereinandergelegt"
        Karte(kicker: "Antwortfächer", beiwerk: kopfbeiwerk(satz)) {
            Antwortfaecher(bild: bild)
        }
    }

    /// Der halbe Satz, der fehlte: die Vorlage sagt im Kartenkopf, dass eine Zeile irgendwohin
    /// führt (`Wirkung.tsx:235`) - und ohne ihn merkt es am Telefon niemand, weil es dort kein
    /// Darüberfahren gibt.
    private var rastersatz: String {
        "sortiert nach Verzögerung · eine Zeile öffnet die Wiedergabe dieses Augenblicks"
    }

    private var rasterbeiwerk: AnyView { kopfbeiwerk(rastersatz) }

    /// **Das Beiwerk geht jetzt in jeder Breite als Beiwerk hinein.** Hier stand
    /// `beiwerk: schmal ? nil : …` und darunter eine zweite Fassung desselben Satzes als erste
    /// Zeile des Karteninhalts - weil ``Karte`` das Beiwerk am Telefon neben die Überschrift
    /// setzte und von „0 Anforderungen bei stehender Maschine, am Beginn übereinandergelegt“ ein
    /// Wortfragment blieb. ``Karte/beiwerkzeile(_:)`` gibt ihm dort inzwischen die eigene Zeile,
    /// die `handy.css:185` vorsieht; Größe und Farbe stehen in ``Kartenhinweis``.
    private func kopfbeiwerk(_ satz: String) -> AnyView {
        Kartenhinweis.beiwerk(satz)
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
