import DuckCurveKit
import SwiftUI

/// Alles, was die PV-Abrechnung braucht - in einem Rutsch geholt.
///
/// **Eine Antwort, und die vier Spannen daneben.** Die Karte „Zeiträume im Vergleich“ stellt
/// Tag, Woche, Monat und Jahr **zum selben Anker** nebeneinander
/// (`PvAccounting.tsx:151-161`); das sind vier weitere Abfragen derselben Antwort, und sie
/// stehen nicht mehr in diesem Verbund, sondern als eigener Zustand neben der Seite
/// (``Spannenstand``, Vorlage `useReport.ts:55-77`). Lagen sie hier, wartete der Beleg auf
/// seine langsamste Spalte.
struct PvAbrechnungsdaten: Sendable {
    let bericht: PvTaxReportOut
}

/// PV-Abrechnung: die Zahlen, die in die Umsatzsteuervoranmeldung gehören.
///
/// Nur fuer den Hausherrn. Hier stehen Bemessungsgrundlagen und Umsatzsteuer der Anlage - das ist
/// kein Energiebericht, sondern ein Beleg.
///
/// **Die Seite ist nach der Vorlage neu geordnet** (`PvAccounting.tsx`): sechs Kennzahlen, das
/// Bild „Erlös und Wertabgabe“, die Aufstellung mit sieben Wertspalten und Summenzeile, die vier
/// Spannen im Vergleich, die Sätze. Was vorher dastand - zwei Karten „Einspeisung“ und
/// „Eigenverbrauch“ mit neun Zeilen - ist darin aufgegangen: jede dieser Zeilen ist jetzt eine
/// Kachel oder eine Spalte der Aufstellung, und ein Beleg, auf dem dieselbe Zahl dreimal steht,
/// ist schwerer zu prüfen als einer, auf dem sie einmal steht.
///
/// **Was gerechnet wird, steht im Kern** (``Pvabrechnung``): die Reihenfolge und die Wortlaute
/// der Kennzahlen, der Kleinunternehmerfall, die sieben Spalten mit ihren Unterzeilen, die
/// Filterschwelle für leere Zeitraumstücke, die Rundung ab hundert Kilowattstunden und die vier
/// Sätze unter der Seite. Hier bleibt die Anordnung.
struct PvAbrechnungSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Der Spannenvergleich, als eigener Zustand neben der Seite - der Grund steht an
    /// ``Spannenstand``.
    @State private var streifen = Spannenstand<PvTaxReportOut>()

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        let stand = streifen.fuer(z.anker)
        Berichtsseite(
            hole: { zr, api in
                let bericht = try await api.energiePv(zr.spanne.rawValue, anker: zr.anker)
                return PvAbrechnungsdaten(bericht: bericht)
            },
            // Auch hier muss der Typ dastehen: `kennzahlen` ist in dieser Datei zweimal
            // vorhanden, und solange `Antwort` nicht feststeht, kann der Compiler nicht
            // entscheiden, welche gemeint ist - und leitet `()` ab.
            inhalt: { (d: PvAbrechnungsdaten) in
                inhalt(d, anker: z.anker, streifen: stand)
            },
            // Der zweite Fehlerweg: fällt der Streifen ganz aus, steht sein Grund als Band
            // neben allem, was schon dasteht - und das Band des Belegs bleibt unberührt.
            // Wann der Dienst das gerechnet hat: bei einem Treffer im Zwischenspeicher ist
            // das nicht jetzt, und dann steht es als Zeile ueber der Seite (``Berichtsstand``).
            gerechnetAm: { (d: PvAbrechnungsdaten) in d.bericht.generatedAt },
            nebenfehler: stand.fehler,
            nebenfehlerErneut: { Task { await holeStreifen(anker: z.anker) } }
        )
        // **Am Anker, nicht am Zeitraum.** Ein Spannenwechsel ändert an den vier Spalten
        // desselben Ankertags nichts; hing der Streifen an `z`, holte jeder Wechsel vier
        // Abfragen umsonst. Am Ankerwechsel muss er neu laden, sonst zeigt er den falschen Tag.
        .task(id: z.anker) { await halteStreifenFrisch(anker: z.anker) }
    }

    /// Den Streifen holen und im Fünf-Minuten-Takt nachholen, solange der Anker steht
    /// (`useReport.ts:70`).
    private func halteStreifenFrisch(anker: String) async {
        while !Task.isCancelled {
            await holeStreifen(anker: anker)
            try? await Task.sleep(for: Berichtstakt.nachladen)
        }
    }

    /// Die vier Spannen zum selben Anker, jede für sich: eine fehlende Spalte ist besser als
    /// eine Seite, die an ihr scheitert - die Vorlage nimmt dafür `Promise.allSettled`
    /// (`useReport.ts:61`).
    private func holeStreifen(anker: String) async {
        let api = haus.api
        let neu = await streifen.nachgeholt(zu: anker) { s in
            try await api.energiePv(s.rawValue, anker: anker)
        }
        // Welcher Anker gilt, entscheidet erst das Schreiben - der Knopf „Noch einmal“ läuft
        // neben `.task(id:)` und bricht beim Blättern nicht ab
        // (``Spannenstand/uebernimm(_:zu:)``).
        streifen.uebernimm(neu, zu: wegweiser.zeitraum(jetzt: haus.jetzt).anker)
    }

    @ViewBuilder private func inhalt(
        _ d: PvAbrechnungsdaten, anker: String, streifen: Spannenstand<PvTaxReportOut>
    ) -> some View {
        let b = d.bericht
        let saetze = Pvabrechnung.saetze(b)

        // **Das Kachelfeld trägt keinen Kicker**, so wie die Vorlage auch keinen über ihr
        // `KpiGrid` setzt (`PvAccounting.tsx:94`). „Einspeisung · Eigenverbrauch ·
        // Umsatzsteuer“ stand hier, weil es in der Vorlage der Kicker der Hülle ist
        // (`PvAccounting.tsx:82`) und die App keine Hülle hatte, die ihn zeichnet. Jetzt hat
        // sie eine: ``Seite`` liest ihn aus ``Bereiche/kicker(fuer:)``.
        Kachelfeld(kacheln: kacheln(b))

        erloeskarte(b)
        aufstellungskarte(b)

        // **Der Streifen steht, auch solange seine Zahlen fehlen**: ``Pvabrechnung``
        // zeichnet jede Spalte ohne Antwort als Strich, wie die Vorlage mit ihrem `strip`, das
        // als `{}` anfängt (`PvAccounting.tsx:76`, `:154-160`). Der Anker kommt aus der
        // Blätterleiste und nicht aus `b.anchor`: die Zahlen des Belegs dürfen beim Blättern
        // noch die des alten Tages sein, die vier Spaltenköpfe gehören zu dem Tag, für den der
        // Streifen geholt wurde.
        Spannenstreifen(
            titel: "Zeiträume im Vergleich",
            zeilen: Pvabrechnung.spannenzeilen(streifen.werte),
            anker: anker,
            jetzt: haus.jetzt
        )

        // Die Abdeckung steht in der Kurzzeile und nicht im Rumpf: sie schränkt jede Zahl
        // dieser Seite ein, und zugeklappt wäre sie verschwiegen. Die Vorlage hat dort keinen
        // Deckel (`PvAccounting.tsx:163-172`), die App klappt Methodensätze zu - dieselbe
        // Teilung hat die Stromseite gewählt (`StromSeite.swift:37-56`).
        Methode(saetze.rumpf.map { Optional($0) }, kurz: saetze.kurz)
    }

    /// Die sechs Kennzahlen, und auf der ersten der Weg zur Erzeugung.
    ///
    /// **Der Verweis „Erzeugung →“ hat in der App keinen Platz im Kopf.** Die Vorlage setzt ihn
    /// rechts in die Zeitraumzeile (`PvAccounting.tsx:88`); die Zeitraumleiste der App trägt
    /// dort nur Spannenwahl und Datumskasten (`Seitenwahl.swift:198-206`). Er sitzt darum auf
    /// der Kachel, von der aus man ihn braucht: wer die eingespeiste Menge liest und sie
    /// erklärt haben will, will die Erzeugung sehen. Den Pfeil setzt ``Kachel`` von selbst
    /// (`Karte.swift:255-257`).
    private func kacheln(_ b: PvTaxReportOut) -> [Kacheldaten] {
        var aus = Pvabrechnung.kennzahlen(b).map(Kacheldaten.init)
        if !aus.isEmpty { aus[0].weg = "/strom/pv" }
        return aus
    }

    /// „Erlös und Wertabgabe“: zwei gestapelte Euro-Reihen je Zeitraumstück
    /// (`PvAccounting.tsx:100-105`, `moneyBars` in `charts.ts:367-399`).
    ///
    /// **Die Seite hatte kein Bild.** Sie nannte Summen und listete Zeiträume; aus welchem
    /// Monat das Geld kam, stand nirgends. Gestapelt, weil sich die beiden Reihen zur
    /// Bemessungsgrundlage der Umsatzsteuer addieren.
    ///
    /// Ohne Tooltip: Swift Charts hat keinen wie ECharts (`charts.ts:372-386`), und die Zahlen
    /// stehen in der Aufstellung direkt darunter - dieselbe Entscheidung wie auf der Kostenseite.
    @ViewBuilder private func erloeskarte(_ b: PvTaxReportOut) -> some View {
        let reihen = Pvabrechnung.erloesreihen(b)
        Karte(kicker: "Erlös und Wertabgabe", beiwerk: AnyView(beiwerk(Pvabrechnung.erloeskopf))) {
            if reihen.allSatisfy({ $0.werte.isEmpty }) {
                Leer(satz: Pvabrechnung.leersatz)
            } else {
                // 230 Punkte, weil die Karte der Vorlage 300 hoch ist und Kopfzeile und
                // Polster davon abgehen (`PvAccounting.tsx:101`).
                Balkenbild(stuecke: reihen.map(stueck), einheit: "€", hoehe: 230)
            }
        }
    }

    private func stueck(_ r: Pvabrechnung.Erloesreihe) -> Balkenbild.Stueck {
        Balkenbild.Stueck(name: r.name, farbe: Farbe.ton(r.ton), werte: r.werte)
    }

    /// „Aufstellung“: die sieben Wertspalten je Zeitraum und die Summe darunter.
    ///
    /// **Die Tabelle steht auch dann, wenn kein Zeitraumstück die Schwelle überschreitet.**
    /// Die Summe stammt nicht aus den Zeilen, sondern aus `totals`, und die Vorlage zeichnet sie
    /// unabhängig von `rows.length` (`PvAccounting.tsx:132-141`, gerendert nach der leeren
    /// `rows.map`); ``Abrechnungstabelle`` trägt sie ohnehin. Der Leersatz gehört allein in die
    /// Diagrammkarte (`:103`): ein Beleg, der die abzuführende Steuer verschweigt, weil keine
    /// Stunde bewertet wurde, ist kein Beleg.
    @ViewBuilder private func aufstellungskarte(_ b: PvTaxReportOut) -> some View {
        let a = Pvabrechnung.aufstellung(b)
        Karte(kicker: "Aufstellung", beiwerk: AnyView(beiwerk(a.kopfzeile))) {
            VStack(alignment: .leading, spacing: 8) {
                Abrechnungstabelle(aufstellung: a)
                Text(a.rundungssatz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Was rechts in einer Kopfzeile steht - 12 px in `--text-3` (`ui/Card.tsx:20-28`).
    /// Größe, Farbe und Ausrichtung stehen in ``Kartenhinweis`` - hier standen sie
    /// zum zehnten Mal, und am Telefon alle drei falsch (``Karte/beiwerkzeile(_:)``).
    private func beiwerk(_ satz: String) -> some View {
        Kartenhinweis(satz: satz)
    }
}
