import DuckCurveKit
import SwiftUI

/// Ein Zustand als Marke: „STUFE 1 - BIAS-KORREKTUR JE SONNENHÖHE · AKTIV“.
///
/// **Es gibt in dieser App keine `Pill`.** Die Vorlage setzt den Stand der Korrektur als Marke
/// in die Kopfzeile (`ForecastPage.tsx:247`, `components/ui/Pill.tsx`): Mono, Versalien,
/// gesperrt, Bernstein auf bernsteinfarbener Fläche, solange die Korrektur angewandt wird, sonst
/// leise. In der App standen dieselben zwei Dinge getrennt da - `stageDe` als Kartentitel,
/// `correctionActive` als „ja/nein“ in einer Zeile darunter. Zusammen sind sie eine Aussage:
/// welche Stufe läuft, und ob sie schon wirkt oder noch lernt.
private struct Stufenmarke: View {
    let wort: String
    /// Die Korrektur wird angewandt. Sonst lernt sie nur mit.
    let aktiv: Bool

    var body: some View {
        Text(wort.uppercased())
            .font(Schrift.zahlKlein)
            .tracking(1.1)
            .foregroundStyle(aktiv ? Farbe.amber : Farbe.text2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(aktiv ? Farbe.amber.opacity(0.14) : Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
                    .strokeBorder(
                        aktiv ? Farbe.amber.opacity(0.35) : Farbe.linie2, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous))
    }
}

/// Prognose: wie gut die Vorhersage war - und was sie daraus gelernt hat.
///
/// **Vorher vier Textkarten und keine einzige Zeichnung.** Die Antwort auf
/// `GET /forecast/evaluation` trägt rund 96 Punkte je Tag für heute und gestern, fünf
/// Sonnenhöhenklassen mit ihren Korrekturfaktoren und die Gewichte der Quellen. Gezeigt wurden
/// davon drei Zahlentabellen; `today.points`, `yesterday`, `corrector.bins` und `sources` wurden
/// in der App an keiner Stelle gelesen. Diese Seite ist der Nachbau der Vorlage
/// (`apps/web/src/components/forecast/ForecastPage.tsx` und `forecast/Rueckblick.tsx`), von oben
/// nach unten in derselben Reihenfolge.
///
/// **Zwei Abfragen mit zwei Takten.** Die Bewertung kommt aus dem Arbeitsspeicher des Bewerters
/// und wird alle fünf Minuten nachgeholt (`ForecastPage.tsx:27`), der Rückblick liest die
/// abgelegten Läufe und reicht alle zehn (`Rueckblick.tsx:150`). Die App holte beides einmal beim
/// Erscheinen - an einer Wandanzeige stand damit eine Seite, deren „Stand 08:15“ um 20 Uhr noch
/// dastand.
///
/// **Gerechnet wird in ``Prognosebild``.** Die Kacheln, die Tageskurve samt Leistungsgrenze und
/// Jetzt-Stunde, die Faktorabweichungen mit ihrer Spanne, die Fehlerbalken und die Tagespaare
/// kommen fertig aus dem Kern; hier stehen nur Karten, Schalter und Sätze.
struct PrognoseSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var bewertung: ForecastEvaluationOut?
    @State private var verlauf: ForecastHistoryOut?
    @State private var fehler: ApiFehler?
    /// Heute oder gestern im Hauptdiagramm.
    ///
    /// **Nur lokal, keine zweite Abfrage** (`ForecastPage.tsx:207`): beide Tage stehen in
    /// derselben Antwort. Als Zeichenkette und nicht als Aufzählung, weil ``Ansichtswahl`` über
    /// ``Ansicht/weg`` vergleicht.
    @State private var gezeigterTag = "heute"
    /// Die Tiefe des Rückblicks. Die Vorlage bietet 3, 7, 14 und 30 Tage an; die App hatte die
    /// Sieben fest verdrahtet.
    @State private var tage = 7

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await holeBewertung() } }
            }
            if let b = bewertung {
                kopfzeile(b)
                Kachelfeld(
                    kacheln: Prognosebild.kacheln(b).map { Kacheldaten($0) },
                    kicker: "Heute", spalten: 2, art: .bericht)
                hauptkarte(b)
                dreierreihe(b)
                zweierreihe(b)
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
            rueckblick
        }
        .task { await haltBewertungFrisch() }
        .task(id: tage) { await haltVerlaufFrisch() }
    }

    // MARK: - Kopfzeile

    /// Was in der Vorlage im Kopf der Hülle steht: der Stand und die Marke.
    ///
    /// **Am Telefon fällt der Stand weg.** Die Vorlage blendet ihn unter 1400 px aus
    /// (`ForecastPage.tsx:246`), und aus demselben Grund: „Stand 14:35 · Bridge (PV-Prognose)“
    /// neben einer Überschrift auf 390 Punkten lässt von der Überschrift zwei Wörter übrig. Die
    /// Uhrzeit steht ohnehin in der Jetzt-Linie des Hauptdiagramms.
    ///
    /// **Die Sache selbst stand hier zweimal** - einmal als Sperrschrift, einmal als
    /// Überschrift fürs Telefon -, und sie gehört der Hülle und nicht dieser Seite
    /// (`ForecastPage.tsx:245`). ``Seite`` zeichnet sie jetzt aus ``Bereiche/kicker(fuer:)``;
    /// hier bleibt, was die Seite selbst weiß.
    @ViewBuilder private func kopfzeile(_ b: ForecastEvaluationOut) -> some View {
        let marke = Stufenmarke(wort: markenwort(b), aktiv: b.correctionActive)
        if schmal {
            marke
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Spacer(minLength: 8)
                Text(standwort(b)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                marke
            }
        }
    }

    /// „Stufe 1 - Bias-Korrektur je Sonnenhöhe · aktiv“ bzw. „· lernt“.
    ///
    /// Die Stufe kommt vom Dienst (`forecast_evaluation.py:39`); angehängt wird nur, ob sie
    /// schon wirkt. Das ist der Unterschied zwischen einer Korrektur, die die Prognose verändert,
    /// und einer, die bloß mitzählt.
    private func markenwort(_ b: ForecastEvaluationOut) -> String {
        b.stageDe + (b.correctionActive ? " · aktiv" : " · lernt")
    }

    private func standwort(_ b: ForecastEvaluationOut) -> String {
        let quelle = b.sources.first.map { " · \($0.labelDe)" } ?? ""
        return "Stand \(Formate.hhmm(iso: b.generatedAt))\(quelle)"
    }

    // MARK: - Das Hauptdiagramm

    /// „Heute · Prognose gegen Ist“ mit dem Umschalter im Kopf der Karte.
    ///
    /// **„Jetzt“ ist `generatedAt` und nicht `haus.jetzt`.** Die App hat eine eigene Uhr, und
    /// sie wäre hier falsch: die Antwort ist bis zu fünf Minuten alt, und eine Jetzt-Linie fünf
    /// Minuten rechts des letzten Ist-Punktes sieht aus wie eine Messlücke
    /// (`ForecastPage.tsx:217`).
    private func hauptkarte(_ b: ForecastEvaluationOut) -> some View {
        let heute = gezeigterTag == "heute"
        let gezeigt = heute ? b.today : b.yesterday
        let bild = Prognosebild.tageskurve(
            gezeigt, heute: heute, gerechnetAm: Zeit.ausIso(b.generatedAt))
        return Karte(
            kicker: (heute ? "Heute" : "Gestern") + " · Prognose gegen Ist",
            titel: guetezeile(gezeigt.score),
            beiwerk: AnyView(
                Ansichtswahl(
                    ansichten: [
                        Ansicht(weg: "heute", name: "Heute"),
                        Ansicht(weg: "gestern", name: "Gestern"),
                    ],
                    aktiv: Ansicht(weg: gezeigterTag, name: "")
                ) { a in gezeigterTag = a.weg })
        ) {
            Prognosekurvenbild(tag: bild, heute: heute, ausgegeben: gezeigt.issuedAt)
        }
    }

    /// „MAE 0,76 kW · Bias −0,12 kW · +12,4 %“ - die drei Zahlen des gezeigten Tages.
    private func guetezeile(_ bewertet: ForecastScore?) -> String? {
        guard let bewertet else { return nil }
        return "MAE \(Formate.zahl(bewertet.maeKw, stellen: 2)) kW · Bias "
            + "\(Formate.zahl(bewertet.biasKw, stellen: 2)) kW · "
            + Formate.prozentpunkte(bewertet.energyErrorPct)
    }

    // MARK: - Die drei kleinen Karten

    /// **Nebeneinander nur an der Wand.** Die Vorlage setzt drei Spalten (5fr/3fr/4fr) und fällt
    /// am Telefon auf eine (`globals.css:108,350`). Untereinander wären es dort drei Karten mit
    /// je 150 Punkten Bild - lesbar; nebeneinander wären es drei Diagramme auf 120 Punkten
    /// Breite, in denen vierzehn Säulenpaare zu einem Streifen verschmelzen.
    @ViewBuilder private func dreierreihe(_ b: ForecastEvaluationOut) -> some View {
        if schmal {
            tagesenergiekarte(b)
            horizontkarte(b)
            faktorkarte(b)
        } else {
            HStack(alignment: .top, spacing: 14) {
                tagesenergiekarte(b)
                horizontkarte(b)
                faktorkarte(b)
            }
        }
    }

    private func tagesenergiekarte(_ b: ForecastEvaluationOut) -> some View {
        let paare = Prognosebild.tagesenergie(b.daily)
        // Die Zahl steht wirklich im Titel (`ForecastPage.tsx:298`): „letzte 9 Tage“ sagt, dass
        // der Bestand noch keine vierzehn hat - sonst sähe die kurze Reihe nach einem Fehler aus.
        return Karte(kicker: "Tagesenergie · kWh", titel: "letzte \(paare.count) Tage") {
            Tagesenergiebild(paare: paare)
        }
    }

    private func horizontkarte(_ b: ForecastEvaluationOut) -> some View {
        Karte(kicker: "Fehler nach Horizont", titel: "gestern und heute, alle Läufe") {
            Horizontbild(balken: Prognosebild.horizonte(b))
        }
    }

    private func faktorkarte(_ b: ForecastEvaluationOut) -> some View {
        Karte(kicker: "Korrekturfaktoren nach Sonnenhöhe", titel: lerntext(b.corrector)) {
            Faktorenbild(bild: Prognosebild.faktorbalken(b.corrector))
        }
    }

    /// „12 Lerntage · Halbwertszeit 7 d“ (`ForecastPage.tsx:316`).
    ///
    /// Die Halbwertszeit gehört dazu: sie sagt, wie schnell die Faktoren einen alten Tag
    /// vergessen - ohne sie ist „12 Lerntage“ eine Zahl ohne Maßstab.
    private func lerntext(_ st: CorrectorState) -> String? {
        guard let gelernt = st.daysLearned else { return nil }
        return "\(gelernt) Lerntage · Halbwertszeit "
            + "\(Formate.zahl(st.halfLifeDays, stellen: 0)) d"
    }

    // MARK: - Die zwei breiten Karten

    @ViewBuilder private func zweierreihe(_ b: ForecastEvaluationOut) -> some View {
        if schmal {
            aenderungskarte(b)
            quellenkarte(b)
        } else {
            HStack(alignment: .top, spacing: 14) {
                aenderungskarte(b)
                quellenkarte(b)
            }
        }
    }

    /// Was sich für die nächste Prognose ändert - und darunter, offen, was die Zahlen
    /// einschränkt.
    ///
    /// **`notesDe` stand in einer zugeklappten ``Methode``-Karte.** Was eine Zahl einschränkt,
    /// darf nicht hinter einem Deckel liegen; die Vorlage setzt diese Sätze darum offen unter die
    /// Liste, getrennt durch eine Linie (`ForecastPage.tsx:337-343`). Der Deckel ist für
    /// Methodensätze da, die immer gleich lauten - diese hier gelten für den heutigen Lauf.
    private func aenderungskarte(_ b: ForecastEvaluationOut) -> some View {
        Karte(
            kicker: "Was sich für die nächste Prognose ändert",
            titel: abschlusstext(b.corrector)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if b.nextChangesDe.isEmpty {
                    Leer(satz: "Für den nächsten Lauf ändert sich nichts.")
                } else {
                    // Die Nummer trägt eine Auskunft: die Reihenfolge ist die, in der es wirkt.
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(b.nextChangesDe.enumerated()), id: \.offset) { i, satz in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(String(format: "%02d", i + 1))
                                    .font(Schrift.zahlKlein)
                                    .foregroundStyle(Farbe.text3)
                                Text(satz)
                                    .font(Schrift.klein)
                                    .foregroundStyle(Farbe.text1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                if !b.notesDe.isEmpty {
                    Divider().overlay(Farbe.linie1)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(b.notesDe.enumerated()), id: \.offset) { _, satz in
                            Text(satz)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    /// „Tagesabschluss Mo, 17.11.“ - oder dass es noch keinen gibt.
    ///
    /// Die Faktoren ändern sich nur beim Tagesabschluss. Ohne dieses Datum weiß man nicht, ob
    /// die Liste darunter von heute Nacht ist oder von vorletzter Woche.
    private func abschlusstext(_ st: CorrectorState) -> String {
        guard let abschluss = st.updatedOn else { return "noch kein Tagesabschluss" }
        return "Tagesabschluss \(Tag.kurz(abschluss))"
    }

    /// Welche Quelle mit welchem Gewicht in die Prognose eingeht.
    ///
    /// **`sources` wurde in der App nirgends gelesen** - also kein Gewicht, kein MAE über sieben
    /// Tage, kein aktiv/aus. Die Seite sagte damit nicht, woher die Prognose kommt, die sie
    /// bewertet.
    private func quellenkarte(_ b: ForecastEvaluationOut) -> some View {
        let quellen = b.sources
        // `Tabelle` kann keine farbige Zelle von sich aus, aber eine Spalte darf Farben tragen -
        // „aktiv“ steht in Bernstein, „aus“ leise. Dasselbe Paar wie in der Vorlage.
        let staerke: [Color?] = quellen.map { $0.active ? Farbe.amber : Farbe.text3 }
        return Karte(
            kicker: "Quellen und Gewichte",
            titel: "Ist/Prognose gesamt \(Formate.zahl(b.corrector.kGlobal, stellen: 2))"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if quellen.isEmpty {
                    Leer(satz: "Keine Quelle gemeldet.")
                } else {
                    Tabelle(
                        // **Der technische Name in den Zeilennamen.** Die Vorlage setzt ihn
                        // klein unter das Wort (`ForecastPage.tsx:357`); `Tabelle` hat keine
                        // zweite Zeile unter dem Zeilennamen, und er gehört dazu: in der
                        // Konfiguration der Brücke heißt die Quelle so und nicht anders.
                        zeilennamen: quellen.map { "\($0.labelDe) (\($0.name))" },
                        spalten: [
                            .init(
                                name: "Gewicht",
                                zellen: quellen.map { Formate.zahl($0.weight, stellen: 2) }
                            ),
                            .init(
                                name: "MAE 7 d · kW",
                                zellen: quellen.map { Formate.zahl($0.mae7dKw, stellen: 2) }
                            ),
                            .init(
                                name: "Status",
                                zellen: quellen.map { $0.active ? "aktiv" : "aus" },
                                farben: staerke
                            ),
                        ],
                        // Drei kurze Spalten gehören auch am Telefon nebeneinander: Gewicht und
                        // Güte sind erst zusammen eine Aussage - viel Gewicht bei schlechter
                        // Güte ist die Nachricht, und mit einem Spaltenumschalter sieht man sie
                        // nicht.
                        immerSichtbar: 3
                    )
                }
                Text(quellensatz(b))
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Der Satz unter der Tabelle, wörtlich wie in der Vorlage - samt Bias der kurzen Woche und
    /// der Zahl der aufbewahrten Läufe.
    private func quellensatz(_ b: ForecastEvaluationOut) -> String {
        "Weitere Quellen (forecast.solar, Solcast aus Home Assistant) kommen mit der Bridge dazu "
            + "und werden hier nach ihrer Güte gewichtet. Bias 7 Tage: "
            + "\(Formate.zahl(Prognosebild.bias7(b.daily), stellen: 2)) kW · aufbewahrte Läufe: "
            + "\(b.runsKept)."
    }

    // MARK: - Der Rückblick

    /// Die abgelegten Läufe gegen das Ist, mit der Wahl 3/7/14/30 Tage.
    ///
    /// **Eigener Abschnitt, eigene Abfrage.** Der Rückblick liest `forecast_runs` und nicht den
    /// Arbeitsspeicher des Bewerters; die Tageszahl ist der einzige Schalter der Seite, der eine
    /// neue Abfrage auslöst. Bis die Antwort da ist, bleibt die alte stehen - eine Seite, die
    /// beim Umschalten leer wird, flackert bei jedem Schritt.
    @ViewBuilder private var rueckblick: some View {
        VStack(alignment: .leading, spacing: 10) {
            if schmal {
                Text("Rückblick · abgelegte Läufe gegen das Ist")
                    .font(Schrift.karte)
                    .foregroundStyle(Farbe.text1)
            } else {
                Kicker(wort: "Rückblick · abgelegte Läufe gegen das Ist")
            }
            // Der Rueckblick hat in der Vorlage seinen eigenen Knopf
            // (`Rueckblick.tsx:173`) - und schreibt „3 d“ statt „3 Tage“.
            Tagewahl(tage: $tage, moeglich: [3, 7, 14, 30], form: .prognoseRueckblick)
        }
        if let v = verlauf {
            if v.reihen.isEmpty {
                Karte { Leer(satz: "Im Bestand liegt für diesen Zeitraum kein Lauf.") }
            } else {
                ForEach(v.reihen, id: \.key) { r in
                    Karte(kicker: r.labelDe, titel: kopfrechts(r)) {
                        Vorlaufbild(balken: Prognosebild.vorlaufbalken(r), einheit: r.einheit)
                    }
                }
            }
            // `kurz` steht auch zugeklappt da - genau dafür ist es gedacht: wie viele Tage und
            // wie viele Läufe hinter den Säulen stehen, schränkt sie ein.
            Methode(
                v.hinweiseDe, kurz: "\(v.tage) Tage · \(laeufe(v)) Läufe im Bestand",
                titel: "Wie der Rückblick zu lesen ist")
        } else {
            // Eine Tagewahl über einer leeren Fläche sieht aus wie ein Schalter, der nichts tut.
            Karte { Leer(satz: "Wird geholt …") }
        }
    }

    /// „96 Paare · Bias +0,12 kW“ - oder, wenn es keine gibt, wie viele Läufe trotzdem dalagen.
    ///
    /// **Die Zahl der Läufe ohne Paare ist die wichtigere Auskunft von beiden.** Sie trennt „der
    /// Dienst legt nichts ab“ von „er legt ab, findet aber kein Ist dazu“ (`Rueckblick.tsx:170`).
    private func kopfrechts(_ r: ReiheOut) -> String {
        let gesamt = r.gesamt
        if gesamt.n == 0 { return "\(r.laeufe) Läufe, keine Paare" }
        let vorzeichen = gesamt.bias > 0 ? "+" : ""
        return "\(gesamt.n) Paare · Bias \(vorzeichen)"
            + "\(Formate.zahl(gesamt.bias, stellen: 2)) \(r.einheit)"
    }

    /// Die Läufe im Bestand: die größte Zahl über alle Reihen.
    ///
    /// Jede Reihe zählt ihre eigenen; „im Bestand“ meint den Bestand und nicht die Reihe, und
    /// eine Summe wäre falsch - es sind dieselben Läufe.
    private func laeufe(_ v: ForecastHistoryOut) -> Int {
        v.reihen.map(\.laeufe).max() ?? 0
    }

    // MARK: - Nachladen

    /// Die Bewertung alle fünf Minuten (`ForecastPage.tsx:27`: `REFRESH_MS = 300_000`).
    private func haltBewertungFrisch() async {
        while !Task.isCancelled {
            await holeBewertung()
            try? await Task.sleep(for: .seconds(300))
        }
    }

    private func holeBewertung() async {
        do {
            bewertung = try await haus.api.prognoseBewertung()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }

    /// Der Rückblick alle zehn Minuten - und bei jeder neuen Tageszahl sofort, weil die Aufgabe
    /// an `tage` hängt.
    ///
    /// **Ein Fehler hier löscht nichts.** Die Störung oben gehört der Bewertung; ein Rückblick,
    /// der einmal nicht antwortet, soll nicht die Säulen von vorhin vom Schirm nehmen.
    private func haltVerlaufFrisch() async {
        while !Task.isCancelled {
            if let frisch = try? await haus.api.prognoseVerlauf(tage: tage) {
                verlauf = frisch
            }
            try? await Task.sleep(for: .seconds(600))
        }
    }
}
