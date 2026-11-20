import DuckCurveKit
import SwiftUI

/// Alles, was die Kostenseite braucht - in einem Rutsch geholt.
///
/// **Sieben Antworten, nicht zwei.** Die Seite holte Übersicht und Vergleichslauf
/// (`GeldSeiten.swift:15-17`). Dazu kommen jetzt `/energy/heat` - ohne das gibt es keinen
/// Pelletpreis, und ohne den ist „Bezahlt“ um einen ganzen Brennstoff zu klein
/// (`CostReport.tsx:62`, `:66-67`) - und dieselbe Übersicht noch einmal für Tag, Woche, Monat
/// und Jahr desselben Ankertags (`useReport.ts:149-171`). Scheitert eine davon, fehlt ihre
/// Spalte; die Seite bleibt stehen.
///
/// **Der Typ muss an `inhalt:` dastehen, und das ist der Grund für diesen Verbund.**
/// ``Berichtsseite`` leitet `Antwort` aus der Abfrage ab; bei einem benannten Paar, dessen
/// zweite Hälfte aus `try?` kommt, schafft der Compiler das nicht mehr und meldet „cannot
/// infer type of closure parameter“. Ein benannter Verbund nimmt ihm die Arbeit ab - die
/// Angabe bleibt trotzdem stehen, weil `inhalt(_:)` in diesem Ordner mehrfach vorkommt und
/// der Compiler sonst `()` ableitet.
struct Kostendaten: Sendable {
    let kosten: EnergySummaryOut
    /// Darf fehlen: ohne sie stehen Pellets und Ofennotiz nicht da, die Seite schon.
    let waerme: HeatReportOut?
    /// Darf fehlen: der Vergleichslauf ist eine Schätzung und kein Teil der Buchhaltung.
    let verschiebung: ShiftReportOut?
    let jeSpanne: [Spanne: EnergySummaryOut]
}

/// Kosten: was der Zeitraum gekostet hat, in einer Zeile.
///
/// **Warum es diese Seite gibt** (`CostReport.tsx:14-32`). Euro-Beträge standen auf fünf
/// Seiten verstreut: Netzbezug beim Haus, Pellets bei der Wärme, Ladekosten bei der Wallbox,
/// Erlös bei der PV-Abrechnung, Ersparnis beim Speicher. Was der Oktober gekostet hat, war
/// nirgends in einer Zeile zu lesen. Hier steht sie, und jede Zahl darunter führt zu der
/// Seite, von der sie kommt - darum ist die „Aufstellung“ keine Tabelle, sondern eine Liste
/// aus Knöpfen.
///
/// **Fast nichts hier ist neu gerechnet.** Alle Beträge kommen aus denselben Stundenbilanzen
/// wie die Geräteseiten; die Seite addiert sie nur. Die eine Ausnahme ist der Vergleichslauf:
/// was das Verschieben der Wärmepumpe gebracht hat, lässt sich nicht messen, denn es gibt nur
/// den einen Verlauf, der stattgefunden hat. Die Zahl steht als Schätzung da, nennt ihre
/// Annahmen und darf negativ sein; genau dann hat das Verschieben Geld gekostet, und eine
/// Anzeige, die das verschweigt, wäre Werbung.
///
/// **Was gerechnet wird, steht im Kern** (``Gelduebersicht``): die vier Beträge mit ihren
/// Hinweisen, der Haushaltsabzug, die Schwelle der Preisspalte, die sieben Posten mit ihren
/// Wegen, die gemeinsame Skala der Ersparnisleisten, die drei Zustände des Vergleichslaufs,
/// die Vorzeichen der Diagramme und die fünf Spannenzeilen. Hier bleibt die Anordnung.
struct KostenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Berichtsseite { z, api in
            // Die vier Spannen laufen los, bevor die eigentliche Antwort da ist: sie hängen
            // nur am Anker, nicht an der gewählten Spanne.
            async let spannen = holeSpannen(anker: z.anker, api: api)
            async let waerme = try? api.energieWaerme(z.spanne.rawValue, anker: z.anker)
            async let schieben = try? api.energieVerschiebung(z.spanne.rawValue, anker: z.anker)
            let kosten = try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
            return Kostendaten(
                kosten: kosten, waerme: await waerme, verschiebung: await schieben,
                jeSpanne: await spannen)
        } inhalt: { (d: Kostendaten) in
            inhalt(d)
        }
    }

    /// Die vier Spannen zum selben Anker. `try?` je Spanne: eine fehlende Spalte ist besser
    /// als eine Seite, die an ihr scheitert - die Vorlage nimmt dafür `Promise.allSettled`
    /// (`useReport.ts:160`).
    private func holeSpannen(anker: String, api: Api) async -> [Spanne: EnergySummaryOut] {
        await withTaskGroup(of: (Spanne, EnergySummaryOut?).self) { gruppe in
            for s in Spanne.allCases {
                gruppe.addTask {
                    (s, try? await api.energieUebersicht(s.rawValue, anker: anker))
                }
            }
            var aus: [Spanne: EnergySummaryOut] = [:]
            for await (s, b) in gruppe {
                if let b { aus[s] = b }
            }
            return aus
        }
    }

    // MARK: - Die Anordnung

    @ViewBuilder private func inhalt(_ d: Kostendaten) -> some View {
        kopfzeile(d)
        bildUndErsparnis(d)
        verschiebungskarte(d)
        aufstellungskarte(d)
        Spannenstreifen(
            titel: Gelduebersicht.spannentitel,
            zeilen: Gelduebersicht.spannenzeilen(d.jeSpanne),
            anker: d.kosten.anchor,
            jetzt: haus.jetzt
        )
        // Die Abdeckung steht in der Kurzzeile und nicht im Rumpf: sie schränkt jede Zahl
        // dieser Seite ein, und zugeklappt wäre sie verschwiegen (`ReportShell.tsx:155-162`).
        // Die Annahmen des Vergleichslaufs stehen nicht mehr hier, sondern bei der Zahl, die
        // sie voraussetzt.
        //
        // **`Methode` nimmt `[String?]`, und die Reihe muss das von sich aus sein.** Hier
        // stand einmal ein Literal aus drei wahlfreien Zeichenketten plus `assumptionsDe` -
        // damit wurde die Reihe `[Any]`, und darauf passt `[String?]` nicht. Die Sätze kommen
        // jetzt als `[String]` aus dem Kern und werden umgehängt, nicht eingereiht.
        Methode(
            Gelduebersicht.methodensaetze(d.kosten, waerme: d.waerme).map { Optional($0) },
            kurz: Gelduebersicht.methodenkurz(d.kosten)
        )
    }

    /// Die vier Beträge, unter dem Kicker der Vorlage.
    ///
    /// **Der Kicker ist der der Seite und nicht der Reitername** (`CostReport.tsx:107`). Die
    /// Vorlage setzt ihn rechts in die Zeitraumzeile; die Zeitraumleiste der App trägt dort
    /// nur Spannenwahl und Datumskasten. Dieselbe Entscheidung hat die PV-Abrechnung
    /// getroffen.
    @ViewBuilder private func kopfzeile(_ d: Kostendaten) -> some View {
        Karte(kicker: Gelduebersicht.seitenkicker) {
            Betragszeile(betraege: Gelduebersicht.kopfbetraege(d.kosten, waerme: d.waerme))
        }
    }

    /// Das Hauptdiagramm und die Ersparnis nebeneinander - am Telefon untereinander.
    ///
    /// `8fr 4fr` am Schirm (`CostReport.tsx:119`), am Telefon zwei Karten mit 14 Punkten
    /// Abstand (`handy.css:209`).
    @ViewBuilder private func bildUndErsparnis(_ d: Kostendaten) -> some View {
        if schmal {
            hauptdiagramm(d)
            ersparniskarte(d)
        } else {
            Spaltenreihe(anteile: [8, 4], abstand: 14) {
                hauptdiagramm(d)
                ersparniskarte(d)
            }
        }
    }

    /// „Bezahlt und bekommen“: Netzstrom nach oben, Einspeisung nach unten.
    @ViewBuilder private func hauptdiagramm(_ d: Kostendaten) -> some View {
        let reihen = Gelduebersicht.hauptreihen(d.kosten)
        Karte(
            kicker: Gelduebersicht.hauptdiagrammtitel,
            beiwerk: AnyView(Geldlegende(reihen: reihen))
        ) {
            if d.kosten.buckets.isEmpty {
                Leer(satz: Gelduebersicht.hauptdiagrammleer)
            } else {
                // 230 Punkte, weil die Karte der Vorlage 300 hoch ist und Kopfzeile und
                // Polster davon abgehen (`CostReport.tsx:120`).
                Geldbalken(reihen: reihen, hoehe: 230)
            }
        }
    }

    /// „Woraus die Ersparnis besteht“: zwei Leisten auf einer Skala und der Satz, der sagt,
    /// wogegen gerechnet wird.
    @ViewBuilder private func ersparniskarte(_ d: Kostendaten) -> some View {
        Karte(kicker: Gelduebersicht.ersparnistitel) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Gelduebersicht.ersparnisteile(d.kosten.totals)) { teil in
                    Anteilsleiste(teil: teil)
                }
                absatz(Gelduebersicht.ersparnissatz)
            }
        }
    }

    /// „Was das Verschieben gebracht hat“: links die Zahl, rechts die Tage, darunter die
    /// Methode und die zugeklappten Annahmen.
    ///
    /// **Aus zwei Karten wird eine.** Die App hatte „Der Vergleichslauf“ mit fünf Zeilen und
    /// darunter „Nach Tagen“ (`GeldSeiten.swift:24-56`). Die Vorlage führt mit **einer** Zahl
    /// in 40 Punkten und stellt das Tagesbild daneben; `actualEur` und `naiveEur` kommen nicht
    /// vor. Zwei Beträge, von denen keiner bezahlt wurde, neben vier, die es wurden, machen
    /// die Seite unlesbar.
    @ViewBuilder private func verschiebungskarte(_ d: Kostendaten) -> some View {
        let gesagt = Gelduebersicht.verschiebung(d.verschiebung)
        let reihen = Gelduebersicht.verschiebungsreihen(d.verschiebung)
        Karte(
            kicker: Gelduebersicht.verschiebungstitel,
            beiwerk: AnyView(Geldlegende(reihen: reihen))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                zahlUndTage(gesagt, reihen: reihen)
                if let methode = d.verschiebung?.methodDe, !methode.isEmpty {
                    absatz(methode)
                }
                if let annahmen = d.verschiebung?.assumptionsDe, !annahmen.isEmpty {
                    Annahmenblock(saetze: annahmen)
                }
            }
        }
    }

    @ViewBuilder private func zahlUndTage(
        _ gesagt: Gelduebersicht.Verschiebung, reihen: [Gelduebersicht.Balkenreihe]
    ) -> some View {
        if schmal {
            VStack(alignment: .leading, spacing: 14) {
                verschiebungszahl(gesagt)
                tagesdiagramm(reihen)
            }
        } else {
            HStack(alignment: .top, spacing: 20) {
                verschiebungszahl(gesagt).frame(width: 260, alignment: .leading)
                tagesdiagramm(reihen).frame(maxWidth: .infinity)
            }
        }
    }

    private func verschiebungszahl(_ gesagt: Gelduebersicht.Verschiebung) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gesagt.zahl)
                // 40 Punkte, `tracking-[-.03em]` (`CostReport.tsx:158`).
                .font(Schrift.zahlFuehrend)
                .kerning(-1.2)
                .foregroundStyle(Geldfarbe.zu(gesagt.ton))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(gesagt.satz)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
            if let dazu = gesagt.dazu {
                Text(dazu)
                    .font(Schrift.mono(12))
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// **Bleibt kein Tag ohne Notiz übrig, steht hier nichts** - kein Leersatz
    /// (`CostReport.tsx:175`). Die Zahl links sagt schon, dass es für diesen Zeitraum keine
    /// Aussage gibt; ein zweiter Satz daneben sagte dasselbe noch einmal.
    @ViewBuilder private func tagesdiagramm(_ reihen: [Gelduebersicht.Balkenreihe]) -> some View {
        if reihen.contains(where: { !$0.werte.isEmpty }) {
            Geldbalken(reihen: reihen, hoehe: 150)
        }
    }

    /// „Aufstellung“: sieben Posten, jeder mit dem Weg zu seiner Seite.
    @ViewBuilder private func aufstellungskarte(_ d: Kostendaten) -> some View {
        Karte(
            kicker: Gelduebersicht.aufstellungstitel,
            beiwerk: AnyView(kopfhinweis(Gelduebersicht.aufstellungskopf))
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Postenliste(posten: Gelduebersicht.aufstellung(d.kosten, waerme: d.waerme))
                ForEach(Array(Gelduebersicht.aufstellungssaetze.enumerated()), id: \.offset) {
                    _, satz in
                    absatz(satz)
                }
            }
        }
    }

    /// Ein erläuternder Absatz unter einer Karte - 12 Punkte in `--text-3`
    /// (`ReportShell.tsx:143-145`).
    private func absatz(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Was rechts in einer Kopfzeile steht.
    private func kopfhinweis(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .multilineTextAlignment(.trailing)
    }
}

/// Die Annahmen des Vergleichslaufs, zugeklappt (`CostReport.tsx:181-190`).
///
/// **Warum zugeklappt und warum trotzdem hier.** „Die Annahmen gehoeren dazu, aber nicht jedem
/// jeden Tag ins Gesicht: zugeklappt steht die Karte ruhig, aufgeklappt steht alles da, was
/// die Zahl voraussetzt“ (`CostReport.tsx:179-180`). In der App lagen sie bisher im Rumpf der
/// Methodenkarte am Fuss der Seite - drei Karten entfernt von der Zahl, für die sie gelten.
///
/// Es ist der zweite ``DisclosureGroup`` der App nach ``Methode``, und der erste **innerhalb**
/// einer Karte; Titel, Pfeil und `tint` folgen deshalb dem Vorbild dort.
struct Annahmenblock: View {
    let saetze: [String]

    @State private var offen = false

    var body: some View {
        DisclosureGroup(isExpanded: $offen) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(saetze.enumerated()), id: \.offset) { _, satz in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        Text(satz)
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            Text(Gelduebersicht.annahmentitel)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(Farbe.text3)
    }
}
