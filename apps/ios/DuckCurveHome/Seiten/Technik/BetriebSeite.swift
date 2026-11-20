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
            } else {
                // **Vor der ersten Antwort ersetzt ein Absatz die ganze Seite**
                // (`Betrieb.tsx:30-33`). Eine Kachelreihe aus Strichen über einem leeren
                // Diagramm sagt weniger als der Satz, dass gerade ausgezählt wird.
                Text(fehler == nil ? Betriebsbild.ladesatz : Betriebsbild.fehlersatz)
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
        Rueckblickwahl(tage: $tage, moeglich: Self.rueckblicke)
        // **Der Fehler steht in der Standzeile, die Karte bleibt** - und doch steht hier
        // zusätzlich ``Stoerung``. Die Vorlage hat keinen „Erneut“-Knopf und lädt nur beim
        // Wechsel des Zeitraums neu (`Betrieb.tsx:36-38`); auf einem Telefon mit wackligem
        // Netz ist ein Knopf die bessere Antwort als der Rat, den Zeitraum zu wechseln. Die
        // Abweichung ist Absicht und soll nicht als Nachlässigkeit zurückgebaut werden.
        if let fehler {
            Stoerung(fehler: fehler) { Task { await lade() } }
        }
        Kachelfeld(kacheln: Betriebsbild.kacheln(b).map(Kacheldaten.init))
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
    /// **Am Telefon der Spaltenumschalter und nicht die seitliche Rolle, und das ist eine
    /// Abweichung.** Die Vorlage hält diese eine Tabelle ausdrücklich davon ab, zur Liste zu
    /// werden: sie ist mindestens 940 Punkte breit und rollt (`globals.css:912-913`,
    /// `handy.css:246-247`) - anders als `kosten-tabelle` und `nb-tabelle`, die dort zu
    /// Listen umgebaut sind. Bei elf Spalten ist die Rolle aber das schlechtere Angebot: man
    /// sieht nicht, welche Spalten es gibt, und findet die gesuchte nur durch Wischen.
    /// ``Tabelle`` nennt am Telefon alle elf Namen in einer Reihe und zeigt die gewählte -
    /// dieselbe Entscheidung, die `handy.css` für seine übrigen Tabellen getroffen hat.
    @ViewBuilder private func tabelle(_ b: BetriebOut) -> some View {
        Karte {
            DisclosureGroup(isExpanded: $tabelleOffen) {
                Tabelle(
                    zeilennamen: Betriebsbild.tabellenzeilen(b),
                    spalten: Betriebsbild.tabellenspalten(b).map {
                        Tabelle.Spalte(name: $0.name, zellen: $0.zellen)
                    }
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

/// Die Wahl des Rückblicks in Tagen, in der Knopfform der Vorlage (`.kl-knopf`,
/// `globals.css:892-895`).
///
/// **Warum nicht ``Tagewahl``.** Die gibt es, und fünf andere Seiten zeichnen mit ihr ihre
/// Knopfreihe - in anderen Maßen: 11,5 Punkte, Polster 10/5, kein Rahmen, gewählt
/// `amberWeich` auf `deep` (`WaermepumpeSeiten.swift:377-400`). Die Vorlage nennt für diese
/// Knöpfe 13 Punkte, Polster 7/13, eine Haarlinie als Rahmen und gewählt `--amber` auf
/// `--petrol` mit Gewicht 600, und zwar für **alle** Seiten, die `.kl-wahl` benutzen. Die
/// gemeinsame Ansicht darauf zu ziehen, wäre richtig und ändert fünf Seiten auf einmal; das
/// gehört in einen Schritt, der sie alle ansieht, und nicht in den Umbau dieser einen.
struct Rueckblickwahl: View {
    @Binding var tage: Int
    let moeglich: [Int]

    var body: some View {
        Umbruchzeile(abstand: 6, zeilenabstand: 6) {
            ForEach(moeglich, id: \.self) { n in
                knopf(n)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rückblick")
    }

    /// **Die Teile einzeln benannt und mit angeschriebenem Typ.** Vier Fragezeichen in einer
    /// Kette von Modifikatoren ergeben „unable to type-check this expression in reasonable
    /// time“; der Prüfer sieht das nicht, der Mac dann schon.
    private func knopf(_ n: Int) -> some View {
        let gewaehlt: Bool = n == tage
        return Button {
            tage = n
        } label: {
            Text("\(n) Tage")
                .font(schrift(gewaehlt))
                .foregroundStyle(gewaehlt ? Farbe.petrol : Farbe.text2)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(gewaehlt ? Farbe.amber : Color.clear)
                .overlay(Capsule().strokeBorder(rand(gewaehlt), lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(merkmale(gewaehlt))
    }

    /// Gewählt halbfett (`font-weight: 600`, `globals.css:894`): der Unterschied soll nicht
    /// allein an der Farbe hängen.
    private func schrift(_ gewaehlt: Bool) -> Font {
        gewaehlt
            ? Font.custom(Schrift.sansHalbfett, size: 13, relativeTo: .footnote)
            : Schrift.klein
    }

    private func rand(_ gewaehlt: Bool) -> Color {
        gewaehlt ? Farbe.amber : Farbe.linie1
    }

    private func merkmale(_ gewaehlt: Bool) -> AccessibilityTraits {
        gewaehlt ? [.isButton, .isSelected] : [.isButton]
    }
}
