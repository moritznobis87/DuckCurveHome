import Charts
import DuckCurveKit
import SwiftUI

/// Die Töne der Rechnungsseite als Farben - die einzige Stelle, an der das geschieht.
///
/// **Warum nicht `Farbe.ton`.** Das nimmt ``Kennzahl/Ton``, und dem fehlt der Wert für
/// `--alert` (#E0533D), mit dem die Vorlage die Beanstandung und jede nicht stimmende
/// Befundzahl setzt (`InvoiceCheck.tsx:42`, `:220`). ``Kennzahl/Ton`` zu erweitern hieße, den
/// vollständigen `switch` in `Gestalt/Farben.swift` zu erweitern, und der gehört allen Seiten.
/// Darum trägt ``Rechnungspruefung/Ton`` die Rollen dieser Seite, und hier stehen ihre Farben -
/// nach dem Vorbild von ``Geldfarbe``.
enum Rechnungsfarbe {
    static func zu(_ ton: Rechnungspruefung.Ton) -> Color {
        switch ton {
        case .alarm: return Farbe.alarm
        case .netz: return Farbe.diagrammNetz
        case .bernstein: return Farbe.amber
        case .nebel: return Farbe.mist
        case .grundgebuehr: return Farbe.grundgebuehr
        case .umsatzsteuer: return Farbe.umsatzsteuer
        case .text: return Farbe.text1
        case .leise: return Farbe.text3
        }
    }

    /// Die Legendenklötze einer Reihenliste.
    static func legende(_ reihen: [Rechnungspruefung.Reihe]) -> [Legendenstueck] {
        reihen.map { Legendenstueck(wort: $0.name, farbe: zu($0.ton), hoehe: 8) }
    }

    static func legende(_ reihen: [Rechnungspruefung.Betragsreihe]) -> [Legendenstueck] {
        reihen.map { Legendenstueck(wort: $0.name, farbe: zu($0.ton), hoehe: 8) }
    }
}

// MARK: - Diagramm 1: Menge, Rechnung gegen eigene Messung

/// Gruppierte Säulen je Abrechnungszeitraum: was abgerechnet wurde, neben dem, was das Haus
/// gemessen hat (`charts.ts:279-295`).
///
/// **Das ist die Hauptaussage der Seite**, und sie fehlte in der App ganz. Zwei Säulen
/// nebeneinander sagen in einem Blick, was drei Tabellenspalten erst nach dem Nachrechnen
/// sagen: ob die Rechnung zur Messung passt.
///
/// **Gruppiert und nicht gestapelt.** Die Vorlage setzt `barGap: "10%"` und keinen `stack`
/// (`charts.ts:292-293`) - gestapelt wären 400 abgerechnete und 398 gemessene Kilowattstunden
/// eine Säule von 798, und die Zahl gibt es nicht.
///
/// **Fehlt die Messung, fehlt die Säule** - keine Null. Eine Null wäre die Aussage, das Haus
/// habe in diesem Monat nichts bezogen.
struct Mengenvergleichsbild: View {
    let paare: [Rechnungspruefung.Mengenpaar]
    var hoehe: CGFloat = 200

    @State private var gelesen: String?
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Ablesung(
                kopf: gelesen, zeilen: ablesezeilen,
                aufforderung: Rechnungspruefung.ablesungAufforderung)
            bild
        }
    }

    private var ablesezeilen: [Ablesungszeile] {
        guard let gelesen else { return [] }
        return Rechnungspruefung.mengenablesung(wort: gelesen, paare: paare)
            .map { Ablesungszeile(text: $0.text, farbe: Rechnungsfarbe.zu($0.ton)) }
    }

    private var bild: some View {
        Chart { saeulen }
            .chartForegroundStyleScale(
                domain: Rechnungspruefung.mengenreihen.map(\.name),
                range: Rechnungspruefung.mengenreihen.map { Rechnungsfarbe.zu($0.ton) }
            )
            // Die Legende steht im Kartenkopf und nicht unten wie in ECharts: auf 240 Punkten
            // Höhe nimmt sie dort ein Fünftel der Fläche (`Diagramme/Pvverwendung.swift:160`).
            .chartLegend(.hidden)
            // **Die Querachse wird vorgegeben.** Sonst bestimmt die Reihenfolge der Marken die
            // Reihenfolge der Zeiträume, und ein Monat ohne Messung fiele aus der Achse heraus.
            .chartXScale(domain: paare.map(\.wort))
            .chartXSelection(value: $gelesen)
            .chartYAxis { Rechnungsachsen.werte }
            .chartXAxis { Rechnungsachsen.woerter(paare.map(\.wort), schmal: schmal) }
            .frame(height: hoehe)
    }

    @ChartContentBuilder private var saeulen: some ChartContent {
        ForEach(paare) { p in
            BarMark(x: .value("Zeitraum", p.wort), y: .value("kWh", p.rechnung))
                .foregroundStyle(by: .value("Reihe", Rechnungspruefung.mengenreiheRechnung))
                .position(by: .value("Reihe", Rechnungspruefung.mengenreiheRechnung))
                .cornerRadius(2)
            if let gemessen = p.messung {
                BarMark(x: .value("Zeitraum", p.wort), y: .value("kWh", gemessen))
                    .foregroundStyle(by: .value("Reihe", Rechnungspruefung.mengenreiheMessung))
                    .position(by: .value("Reihe", Rechnungspruefung.mengenreiheMessung))
                    .cornerRadius(2)
            }
        }
        if let gelesen {
            RuleMark(x: .value("gelesen", gelesen))
                .foregroundStyle(Farbe.text1.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }
}

// MARK: - Diagramm 2: der Rechnungsbetrag

/// Gestapelte Säulen in Euro: Arbeitspreis, Grundgebühr, Mehrwertsteuer (`charts.ts:297-322`).
///
/// **Keine Nulllinie, anders als bei ``Geldbalken``.** Dort steht die Einspeisevergütung unter
/// Null und der Stapel braucht die sichtbare Null, um lesbar zu sein; auf einer Rechnung ist
/// nichts negativ, und eine Linie, die immer am unteren Rand liegt, ist Beiwerk.
///
/// **Der Radius sitzt nur am obersten Abschnitt**, wie `borderRadius: [2,2,0,0]` an der letzten
/// Reihe (`charts.ts:316`): ein Radius an jedem Abschnitt zerschneidet den Stapel in drei
/// Kästen.
///
/// **„Arbeitspreis · Grundgebühr · Steuer“ ist in der Vorlage der rechte Kopftext**
/// (`InvoiceCheck.tsx:235`). Hier steht dort die Legende mit Farbflecken: dieselbe Aufzählung,
/// nur dass die Zuordnung dabei ist - sonst liegt die Identität der drei Flächen allein in der
/// Farbe (`Diagramme/Geldbalken.swift:103-111`).
struct Rechnungsbetragsbild: View {
    let reihen: [Rechnungspruefung.Betragsreihe]
    var hoehe: CGFloat = 200

    @State private var gelesen: String?
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Ablesung(
                kopf: gelesen, zeilen: ablesezeilen,
                aufforderung: Rechnungspruefung.ablesungAufforderung)
            bild
        }
    }

    private var achsenwoerter: [String] {
        reihen.first?.werte.map(\.wort) ?? []
    }

    private var ablesezeilen: [Ablesungszeile] {
        guard let gelesen else { return [] }
        return Rechnungspruefung.betragsablesung(wort: gelesen, reihen: reihen)
            .map { Ablesungszeile(text: $0.text, farbe: Rechnungsfarbe.zu($0.ton)) }
    }

    private var bild: some View {
        Chart { stapel }
            .chartForegroundStyleScale(
                domain: reihen.map(\.name),
                range: reihen.map { Rechnungsfarbe.zu($0.ton) }
            )
            .chartLegend(.hidden)
            .chartXScale(domain: achsenwoerter)
            .chartXSelection(value: $gelesen)
            .chartYAxis { Rechnungsachsen.werte }
            .chartXAxis { Rechnungsachsen.woerter(achsenwoerter, schmal: schmal) }
            .frame(height: hoehe)
    }

    @ChartContentBuilder private var stapel: some ChartContent {
        ForEach(Array(reihen.enumerated()), id: \.offset) { stelle, reihe in
            ForEach(Array(reihe.werte.enumerated()), id: \.offset) { _, wert in
                BarMark(
                    x: .value("Zeitraum", wert.wort), y: .value("Euro", wert.wert),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Reihe", reihe.name))
                .cornerRadius(stelle == reihen.count - 1 ? 2 : 0)
            }
        }
        if let gelesen {
            RuleMark(x: .value("gelesen", gelesen))
                .foregroundStyle(Farbe.text1.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }
}

// MARK: - Diagramm 3: der Durchschnittspreis

/// Zwei Linien in ct/kWh: der abgerechnete Preis und der aus den eigenen Preisdaten errechnete
/// (`charts.ts:324-340`).
///
/// **Die eigene Reihe ist gestrichelt**, wie `type: [5, 4]` in der Vorlage (`charts.ts:338`).
/// Das ist nicht Verzierung: die beiden Linien liegen oft wenige Zehntel auseinander, und wenn
/// nur die Farbe sie unterscheidet, ist an jeder Kreuzung nicht mehr zu sagen, welche welche
/// ist.
///
/// **Die Achse fängt nicht bei Null an** (`scale: true`, `charts.ts:336`). Die Spanne rechnet
/// ``Rechnungspruefung/preisspanne(_:)``; der Grund steht dort.
///
/// **Lücken werden verbunden** (`connectNulls: true`, `charts.ts:338`). In Swift Charts heißt
/// das, die `nil`-Punkte gar nicht erst in die Reihe zu geben - ein ausgelassener Monat
/// unterbricht die Linie dann nicht.
struct Durchschnittspreisbild: View {
    let punkte: [Rechnungspruefung.Preispunkt]
    var hoehe: CGFloat = 200

    @State private var gelesen: String?
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Ablesung(
                kopf: gelesen, zeilen: ablesezeilen,
                aufforderung: Rechnungspruefung.ablesungAufforderung)
            bild
        }
    }

    private var ablesezeilen: [Ablesungszeile] {
        guard let gelesen else { return [] }
        return Rechnungspruefung.preisablesung(wort: gelesen, punkte: punkte)
            .map { Ablesungszeile(text: $0.text, farbe: Rechnungsfarbe.zu($0.ton)) }
    }

    /// Ohne Werte gibt es keine Spanne; die Karte zeigt dann gar kein Bild, und `0...1` ist nur
    /// der Platzhalter, den `chartYScale` verlangt.
    private var spanne: ClosedRange<Double> {
        Rechnungspruefung.preisspanne(punkte) ?? 0.0...1.0
    }

    private var eigene: [Rechnungspruefung.Preispunkt] {
        punkte.filter { $0.eigene != nil }
    }

    private var bild: some View {
        Chart { linien }
            .chartForegroundStyleScale(
                domain: Rechnungspruefung.preisreihen.map(\.name),
                range: Rechnungspruefung.preisreihen.map { Rechnungsfarbe.zu($0.ton) }
            )
            .chartLegend(.hidden)
            .chartXScale(domain: punkte.map(\.wort))
            .chartYScale(domain: spanne)
            .chartXSelection(value: $gelesen)
            .chartYAxis { Rechnungsachsen.preise }
            .chartXAxis { Rechnungsachsen.woerter(punkte.map(\.wort), schmal: schmal) }
            .frame(height: hoehe)
    }

    @ChartContentBuilder private var linien: some ChartContent {
        ForEach(punkte) { p in
            LineMark(x: .value("Zeitraum", p.wort), y: .value("ct/kWh", p.rechnung))
                .foregroundStyle(by: .value("Reihe", Rechnungspruefung.preisreiheRechnung))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .symbol(.circle)
                .symbolSize(36)
        }
        ForEach(eigene) { p in
            LineMark(x: .value("Zeitraum", p.wort), y: .value("ct/kWh", p.eigene ?? 0))
                .foregroundStyle(by: .value("Reihe", Rechnungspruefung.preisreiheEigene))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .symbol(.circle)
                .symbolSize(25)
        }
        if let gelesen {
            RuleMark(x: .value("gelesen", gelesen))
                .foregroundStyle(Farbe.text1.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }
}

/// Die Legende des Preisdiagramms: die eigene Reihe als **gestrichelter** Strich.
///
/// ``Legendenstueck`` kennt nur Farbe und Höhe; hier unterscheidet aber auch das Strichmuster
/// die beiden Reihen, und ein durchgezogener Klotz für die eigene Preisreihe wäre eine falsche
/// Legende - dieselbe Begründung wie an ``Strichstueck``.
struct Preislegende: View {
    var body: some View {
        Umbruchzeile(abstand: 12, zeilenabstand: 4) {
            Strichstueck(
                wort: Rechnungspruefung.preisreiheRechnung,
                farbe: Rechnungsfarbe.zu(.bernstein))
            Strichstueck(
                wort: Rechnungspruefung.preisreiheEigene, farbe: Rechnungsfarbe.zu(.nebel),
                muster: [5, 4])
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - Die Achsen der drei Verlaufsdiagramme

/// Die drei Achsen, die alle Rechnungsdiagramme gemeinsam haben.
///
/// **Ausgelagert, weil sonst drei `Chart`-Ausdrücke zu lang werden.** Ein Diagramm mit Achsen,
/// Skalen und Marken in einem Ausdruck ergibt „unable to type-check this expression in
/// reasonable time“; benannte Teile mit angeschriebenem Typ lösen das.
enum Rechnungsachsen {
    /// Drei Teilungen, wie `splitNumber: 3` in der Vorlage (`charts.ts:291`): eine Achse mit
    /// sechs Stufen liest niemand, und der Platz links gehört dem Bild.
    @AxisContentBuilder static var werte: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 0))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    /// Dieselbe Achse mit einer Nachkommastelle - ein Preisfenster von vier Cent hätte mit
    /// ganzen Zahlen nur vier Beschriftungen, von denen zwei ausserhalb liegen.
    @AxisContentBuilder static var preise: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
            AxisGridLine().foregroundStyle(Farbe.rasterlinie)
            AxisValueLabel {
                if let d = wert.as(Double.self) {
                    Text(Formate.zahl(d, stellen: 1))
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    /// **Nicht jede Beschriftung, sondern die, die passen** (`hideOverlap: true`,
    /// `charts.ts:290`). Zwei Jahre Rechnungen sind vierundzwanzig Wörter, und auf 390 Punkten
    /// ist das ein Streifen.
    @AxisContentBuilder static func woerter(_ alle: [String], schmal: Bool) -> some AxisContent {
        AxisMarks(values: Achse.beschriftungen(alle, hoechstens: schmal ? 4 : 12)) { wert in
            AxisValueLabel {
                if let s = wert.as(String.self) {
                    Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

// MARK: - Diagramm 4: die Preisbestandteile

/// Die Positionen einer Rechnung als liegende Balken (`charts.ts:342-367`).
///
/// **Von Hand und nicht mit Swift Charts, und das ist hier das bessere Werkzeug.** Im Projekt
/// gibt es für liegende Balken kein Vorbild - alle neun `BarMark` in `DuckCurveHome` sind
/// senkrecht. Was es gibt, ist die von Hand gebaute ``Anteilsleiste``, und ihr Kopfkommentar
/// begründet gerade diesen Weg. Für die Preisbestandteile kommt ein zweiter Grund dazu: die
/// Namen sind lang („Steuern, Abgaben & Umlagen“), die Vorlage schneidet sie bei 160 px ab
/// (`charts.ts:361`), und eine Liste kann sie umbrechen statt sie zu verstümmeln.
///
/// **Die Länge rechnet der Kern** (``Rechnungspruefung/positionsbalken(_:)``) - gegen die
/// größte Position derselben Rechnung, damit der Vergleich zwischen den Zeilen steht und nicht
/// jede Leiste voll ist.
struct Positionsleiste: View {
    let balken: [Rechnungspruefung.Positionsbalken]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(balken) { b in
                zeile(b)
            }
        }
    }

    private func zeile(_ b: Rechnungspruefung.Positionsbalken) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(b.wort)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                // Die Zahl mit drei Stellen, wie am Balkenende der Vorlage (`charts.ts:364`);
                // die Einheit steht einmal im Kartenkopf und nicht an jeder Zeile.
                Text(b.wert)
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text1)
                    .lineLimit(1)
            }
            leiste(b)
        }
    }

    /// Spur und Füllung, acht Punkte hoch - wie ``Anteilsleiste``, damit die beiden Leisten des
    /// Projekts nicht verschieden aussehen.
    private func leiste(_ b: Rechnungspruefung.Positionsbalken) -> some View {
        GeometryReader { raum in
            ZStack(alignment: .leading) {
                Capsule().fill(Farbe.linie1)
                Capsule()
                    .fill(Rechnungsfarbe.zu(b.ton))
                    .frame(width: max(0, raum.size.width * b.anteil))
            }
        }
        .frame(height: 8)
    }
}

/// Die Legende der Positionskarte: welche Farbe welche Gruppe ist.
///
/// **In der Vorlage steht sie im Zeiger** („darunter die Gruppe in `C.text`“,
/// `charts.ts:350`). Ohne Zeiger muss die Zuordnung dastehen, sonst sind drei Farben ohne
/// Bedeutung - und drei Wörter im Kartenkopf kosten weniger Platz als eine vierte Spalte.
struct Positionslegende: View {
    let balken: [Rechnungspruefung.Positionsbalken]

    /// Die Gruppen in der Reihenfolge ihres ersten Auftretens, ohne Wiederholung.
    private var gruppen: [Legendenstueck] {
        var gesehen = Set<String>()
        var aus: [Legendenstueck] = []
        for b in balken where !gesehen.contains(b.gruppe) {
            gesehen.insert(b.gruppe)
            aus.append(
                Legendenstueck(wort: b.gruppe, farbe: Rechnungsfarbe.zu(b.ton), hoehe: 8))
        }
        return aus
    }

    var body: some View {
        Diagrammlegende(stuecke: gruppen)
    }
}
