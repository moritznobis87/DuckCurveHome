import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Betrieb: die Läufe über Tage, mit Abtauen, Takten und der Heizkurve des Reglers.
///
/// **Das Takten ist der Gegenstand.** Eine Waermepumpe, die stuendlich anlaeuft und nach zwoelf
/// Minuten wieder ausgeht, verbraucht mehr und haelt kuerzer als eine, die zweimal am Tag zwei
/// Stunden laeuft. Die Klassenverteilung sagt, welche von beiden hier steht.
///
/// **Der Aufbau ist der der Vorlage** (`apps/web/src/components/waermepumpe/Betrieb.tsx:56-188`),
/// von oben nach unten: ein Satz und die Standzeile, die Wahl des Rückblicks, vier Kacheln, die
/// übrigen Sätze, **vier** Diagramme in zwei Paaren, die Tage als zugeklappte Tabelle, und
/// offen die Hinweise mit zwei Verweisen. Jedes Stück nennt im Kommentar die Stelle, an der es
/// dort steht.
///
/// **Was gerechnet wird, steht in ``Betriebsbild``**, was gezeichnet wird, in
/// `Diagramme/Betriebskurven.swift`. Hier bleibt die Reihenfolge und sonst nichts - das ist der
/// Grund, warum man dieser Datei ansehen kann, wie die Seite aussieht.
struct BetriebSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    /// **Vierzehn Tage, nicht sieben** (`Betrieb.tsx:23`). Eine Woche zeigt an einer
    /// Wärmepumpe das Wetter dieser Woche; zwei Wochen zeigen, wie sie läuft.
    @State private var tage = 14
    @State private var betrieb: BetriebOut?
    @State private var fehler: ApiFehler?
    @State private var tabelleOffen = false

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            if let b = betrieb {
                inhalt(b)
            } else if fehler == nil {
                // **Vor der ersten Antwort ersetzt ein Absatz die ganze Seite**
                // (`Betrieb.tsx:30-33`). Eine Kachelreihe aus Strichen über einem leeren
                // Diagramm sagt weniger als der Satz, dass gerade ausgezählt wird. Der Satz
                // und seine Farbe sind die von vorher; dazugekommen ist Alfred darüber, in der
                // großen Stufe, weil dieser Hinweis an der Stelle der ganzen Seite steht
                // (``Ladehinweis/Stufe``) - dieselbe Stelle, dieselbe Form wie auf der
                // `WaermepumpeSeite`.
                Ladeente(satz: Betriebsbild.ladesatz, stufe: .gross, farbe: Farbe.text3)
            } else {
                // **Der Fehler bekommt keine Ente**, und das ist die Regel an ``Ladeente``:
                // ein Befund ist fertig, und eine schaukelnde Ente daneben behauptete ein
                // Warten, das es nicht mehr gibt.
                Text(Betriebsbild.fehlersatz)
                    .font(Schrift.text)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: tage) { await lade() }
    }

    // MARK: - Die Seite, wenn Zahlen da sind

    @ViewBuilder private func inhalt(_ b: BetriebOut) -> some View {
        kopf(b)
        // `.kl-knopf` wie in der Vorlage dieser Seite (`Betrieb.tsx:67`).
        Tagewahl(
            tage: $tage, moeglich: Self.rueckblicke, gruppe: "Rückblick", form: .klKnopf)
        // **Der Fehler steht in der Standzeile, die Karte bleibt** - und doch steht hier
        // zusätzlich ``Stoerung``. Die Vorlage hat keinen „Erneut“-Knopf und lädt nur beim
        // Wechsel des Zeitraums neu (`Betrieb.tsx:36-38`); auf einem Telefon mit wackligem
        // Netz ist ein Knopf die bessere Antwort als der Rat, den Zeitraum zu wechseln. Die
        // Abweichung ist Absicht und soll nicht als Nachlässigkeit zurückgebaut werden.
        if let fehler {
            Stoerung(fehler: fehler) { Task { await lade() } }
        }
        // `.kpi-handy`: die Werte sind Spannen, und die Vorlage gibt ihnen am Telefon eine
        // Stufe weniger (`handy.css:381-382`).
        Kachelfeld(kacheln: Betriebsbild.kacheln(b).map(Kacheldaten.init), spannen: true)
        auszaehlung(b)
        if Betriebsbild.lief(b) {
            // **Lief sie nicht, fallen alle vier Diagramme weg** (`Betrieb.tsx:48`, `:91`):
            // vier leere Achsen sagen weniger als keine, und Kacheln und Tabelle sagen
            // bereits, dass nichts lief.
            paar {
                Karte(kicker: "Laufstunden je Tag") {
                    Laufstundenbild(betrieb: b)
                }
            } rechts: {
                Karte(kicker: "Arbeitszahl je Tag") {
                    VStack(alignment: .leading, spacing: 10) {
                        Arbeitszahlbild(betrieb: b)
                        kleinerSatz(Betriebsbild.arbeitszahlsatz)
                    }
                }
            }
            paar {
                Karte(kicker: "Wie lange ein Lauf dauert") {
                    lauflaengen(b)
                }
            } rechts: {
                Karte(kicker: "Die Heizkurve des Reglers") {
                    heizkurve(b)
                }
            }
        }
        if !b.tage.isEmpty {
            tabelle(b)
        }
        fuss(b)
    }

    /// Der Kopf: **ein** Satz, groß und allein, darunter die Standzeile
    /// (`Betrieb.tsx:56-63`, `globals.css:789-790`).
    ///
    /// **Der erste Satz steht allein.** Bis hierher schüttete die App alle Sätze gleichwertig
    /// in eine Karte „Was auffällt“ - das Urteil der Seite stand damit als dritter Kasten in
    /// derselben Schriftgröße wie der Rest. Hier führt es, und die übrigen folgen darunter.
    @ViewBuilder private func kopf(_ b: BetriebOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Betriebsbild.kopfsatz(b))
                // 22 Punkte, am Telefon 19 (`globals.css:789`, `handy.css:234`).
                .font(schmal ? Schrift.satz : Schrift.sans(22, relativeTo: .title3))
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            Text(Betriebsbild.standzeile(b, fehler: fehler?.rat))
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Die Karte mit den übrigen Sätzen - nur, wenn nach dem Kopfsatz noch einer übrig ist
    /// (`Betrieb.tsx:80-89`).
    @ViewBuilder private func auszaehlung(_ b: BetriebOut) -> some View {
        let saetze = Betriebsbild.weitereSaetze(b)
        if !saetze.isEmpty {
            Karte(kicker: "Was die Auszählung zeigt") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(saetze.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").font(Schrift.text).foregroundStyle(Farbe.text3)
                            // 15 Punkte, nicht 13 (`globals.css:1024`: `.bt-saetze`). Das ist
                            // Lauftext und keine Fußnote.
                            Text(s)
                                .font(Schrift.text)
                                .foregroundStyle(Farbe.text1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    /// Die Lauflängen mit ihrem Satz - und bei leerer Klassenliste der Satz statt des Bildes.
    ///
    /// **Die Karte fällt nicht weg** (`Betrieb.tsx:106-116`). Bis hierher ließ die App sie bei
    /// leeren Klassen einfach aus; das ist genau der Fehler, den `bilanz.ts:5-9` am
    /// 14.11.2026 festhält - die Seite zeigte nichts und sagte nicht, warum.
    @ViewBuilder private func lauflaengen(_ b: BetriebOut) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if Betriebsbild.laeufe(b) > 0 {
                Lauflaengenbild(betrieb: b)
                kleinerSatz(Betriebsbild.laufzahlsatz(b))
            } else {
                kleinerSatz(Betriebsbild.keinLaufSatz)
            }
        }
    }

    /// Die Heizkurve mit Formel und Satz darunter (`Betrieb.tsx:117-130`).
    @ViewBuilder private func heizkurve(_ b: BetriebOut) -> some View {
        let fuss = Betriebsbild.heizkurvenfuss(b)
        VStack(alignment: .leading, spacing: 10) {
            if b.stunden.isEmpty {
                kleinerSatz(Betriebsbild.keineStundeSatz)
            } else {
                Reglerkurvenbild(betrieb: b)
                if let formel = fuss.formel {
                    // Die Formel in Mono, wie `span.mono` der Vorlage (`Betrieb.tsx:123`);
                    // der Satz dahinter ist Text.
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formel)
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        kleinerSatz(fuss.satz)
                    }
                } else {
                    kleinerSatz(fuss.satz)
                }
            }
        }
    }

    /// Die Tage als Tabelle, **zugeklappt**, mit der Zahl der Tage im Griff
    /// (`Betrieb.tsx:135-137`).
    ///
    /// **Am Telefon rollt sie seitlich und zerfällt nicht zur Liste.** Die Vorlage hält diese
    /// eine Tabelle ausdrücklich davon ab: sie ist mindestens 940 Punkte breit und rollt
    /// (`globals.css:912-913`, `handy.css:246-247`) - anders als `kosten-tabelle` und
    /// `nb-tabelle`, die dort zu Listen umgebaut sind. Bis zum 20.11.2026 stand hier der
    /// Spaltenumschalter, weil das Gerippe nur das konnte; bei elf Spalten füllt dessen Reihe
    /// am Telefon zwei Zeilen, und jeder Blick auf eine andere Spalte wirft die vorige weg.
    @ViewBuilder private func tabelle(_ b: BetriebOut) -> some View {
        Karte {
            DisclosureGroup(isExpanded: $tabelleOffen) {
                Tabelle(
                    zeilennamen: Betriebsbild.tabellenzeilen(b),
                    spalten: Betriebsbild.tabellenspalten(b).map {
                        Tabelle.Spalte(name: $0.name, zellen: $0.zellen)
                    },
                    handyfassung: .rollt
                )
                .padding(.top, 8)
            } label: {
                Text(Betriebsbild.tabellengriff(b))
                    .font(Schrift.karte)
                    .foregroundStyle(Farbe.text1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(Farbe.text3)
        }
    }

    /// Die Fußzeile: die Hinweise **offen**, darunter zwei Verweise (`Betrieb.tsx:177-187`).
    ///
    /// **Offen und nicht in der Methodenkarte.** Auf dieser Seite sind die Hinweise kurz und
    /// sagen, worauf die Auszählung beruht; zugeklappt liest sie niemand, und was eine Zahl
    /// einschränkt, darf nicht verschwinden. `globals.css:795` gibt ihnen 13 Punkte und
    /// `--text-3` - leise, aber da.
    @ViewBuilder private func fuss(_ b: BetriebOut) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(b.hinweiseDe.enumerated()), id: \.offset) { _, h in
                Text(h)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Umbruchzeile(abstand: 18, zeilenabstand: 6) {
                verweis("Die Wärmepumpe jetzt", nach: "/waerme/waermepumpe")
                verweis("Gemessene Kennlinie", nach: "/waerme/waermepumpe/kennlinie")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verweis(_ wort: String, nach weg: String) -> some View {
        Button {
            wegweiser.gehe(weg)
        } label: {
            Text("\(wort) ›").font(Schrift.klein).foregroundStyle(Farbe.amber)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hilfen der Anordnung

    /// Ein 13-Punkt-Absatz unter einem Diagramm (`.kl-klein`, `globals.css:898`).
    ///
    /// Die Sätze sind nicht Beiwerk: sie sagen, was man im Bild sieht. Ohne den unter der
    /// Klassenverteilung ist sie eine Balkenreihe ohne Maßstab.
    private func kleinerSatz(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Zwei Karten nebeneinander, am Telefon untereinander (`.kl-paar`, `globals.css:899`,
    /// `handy.css:235`).
    ///
    /// **Warum nicht immer untereinander.** Die beiden Paare gehören zusammen: Laufstunden und
    /// Arbeitszahl desselben Tages stehen in der Vorlage in einem Blick, und wer die Lücke
    /// zwischen den COP-Linien an einem Tag sieht, sucht daneben die Stunden mit Heizstab.
    /// Auf 390 Punkten ist dafür kein Platz, und dort löst die Vorlage es selbst auf.
    @ViewBuilder private func paar<L: View, R: View>(
        @ViewBuilder links: () -> L, @ViewBuilder rechts: () -> R
    ) -> some View {
        if schmal {
            links()
            rechts()
        } else {
            HStack(alignment: .top, spacing: 16) {
                links().frame(maxWidth: .infinity)
                rechts().frame(maxWidth: .infinity)
            }
        }
    }

    /// Die Rückblicke, die die Seite anbietet (`Betrieb.tsx:20`).
    ///
    /// **Vierzehn Tage sind dabei und fehlten in der App.** Sie sind die Vorwahl: zwei Wochen
    /// enthalten beide Wochenenden und einen Wetterwechsel, sieben Tage oft nicht.
    private static let rueckblicke = [7, 14, 30, 90]

    private func lade() async {
        do {
            betrieb = try await haus.api.betrieb(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}
