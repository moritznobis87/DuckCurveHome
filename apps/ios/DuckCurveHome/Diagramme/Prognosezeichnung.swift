import Charts
import DuckCurveKit
import SwiftUI

// Die Bilder der Prognoseseite: ein Tagesdiagramm, drei Saeulenbilder, ein Rueckblick.
//
// **Was hier vorher stand: nichts.** Die Seite „Prognose“ hatte vier Textkarten und keine
// einzige Zeichnung, obwohl die Antwort auf `GET /forecast/evaluation` rund 96 Punkte je Tag,
// fuenf Sonnenhoehenklassen mit ihren Korrekturfaktoren und die Gewichte der Quellen traegt.
// Die Vorlage (`apps/web/src/components/forecast/ForecastPage.tsx`) macht daraus sieben
// Diagramme; das hier sind die fuenf, die am Telefon und an der Wand dieselbe Aussage tragen.
//
// **Gerechnet wird hier nicht.** Jede Groesse kommt fertig aus `Prognosebild` im Kern - die
// Leistungsgrenze der Hochachse, die Abweichung eines Faktors von 1,00 in Prozentpunkten, die
// symmetrische Spanne der Faktorachse, die Stunde der Jetzt-Linie. Das ist Absicht: jede dieser
// vier Zahlen sieht falsch gerechnet aus wie ein Diagrammfehler, und im Kern ist sie geprueft.
//
// **Auskunft statt Hinweisfenster.** Vier Diagramme der Vorlage haengen an Tooltips mit drei bis
// vier Zeilen (Faktor, gestern, letztes Verhaeltnis, Lerntage; MAE, Bias, Zahl der Paare). Swift
// Charts hat kein Hinweisfenster, und am Telefon gibt es kein Darueberfahren. Jedes Bild hat
// darum eine abgelesene Zeile ueber sich - derselbe Griff wie in `Fahrplanzeichnung` und im
// `Antwortfaecher`. Ohne sie stuenden die Zahl der Paare und die Lerntage nirgends in der App.

extension Farbe {
    /// Der Day-ahead-Lauf: in der Vorlage ein eigenes Blassgrau `#e4ecef`.
    ///
    /// **Das ist keine Marke, und es wird auch keine.** `#e4ecef` steht weder in `tokens.css`
    /// noch in `Marken.swift`; es ist in der Vorlage eine einmalige Farbe für eine einzige
    /// Reihe (`ForecastPage.tsx:19`). Eine neue Serienfarbe müsste gegen `flaeche2` und gegen
    /// jede Nachbarfarbe geprüft werden, wie `Marken.swift:56-92` es für jede andere vormacht -
    /// und das für zwei Prozent Helligkeitsunterschied zu ``Farbe/text1`` (Weiss, 92 %).
    /// Day-ahead ist in diesem Bild das Unbewertete, das Weisse: dieselbe Rolle, die `text1` in
    /// der ganzen App hat. Von der Ist-Reihe unterschieden wird es nicht über die Farbe, sondern
    /// über das Strichmuster - „was gestrichelt ist, ist nicht gemessen“.
    static let dayAhead = text1

    /// Dieselbe Reihe als Fläche: eine Säule und ein Legendenklotz tragen mehr Farbe als ein
    /// Strich.
    ///
    /// `rgba(228,236,239,.55)` der Vorlage (`ForecastPage.tsx:110`). In voller Deckung wäre die
    /// Day-ahead-Säule die hellste Fläche der Karte und das gemessene Ist daneben die leisere
    /// von beiden - genau verkehrt.
    static let dayAheadFlaeche = text1.opacity(0.55)
}

// MARK: - Das Abgelesene

/// Eine Zeile der Auskunft: ein Satz in der Farbe seiner Reihe.
struct Ablesungszeile: Identifiable {
    let text: String
    var farbe: Color = Farbe.text2
    var id: String { text }
}

/// Was an der berührten Stelle steht: ein Kopf und seine Zeilen, in einem Kasten.
///
/// **Warum über dem Bild und nicht darin.** Swift Charts kennt keinen Platz ausserhalb des
/// Zeichenbereichs; eine Beschriftung über `annotation` staucht die Skala, und dann stehen die
/// Säulen zweier Karten nicht mehr auf derselben Teilung. Solange niemand berührt, steht dort
/// die Aufforderung - sonst springt das Bild beim ersten Tippen um die Höhe des Kastens.
struct Ablesung: View {
    let kopf: String?
    let zeilen: [Ablesungszeile]
    let aufforderung: String

    var body: some View {
        if let kopf {
            VStack(alignment: .leading, spacing: 3) {
                Text(kopf).font(Schrift.zahlKlein).foregroundStyle(Farbe.amberWeich)
                ForEach(zeilen) { z in
                    Text(z.text)
                        .font(Schrift.winzig)
                        .foregroundStyle(z.farbe)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Text(aufforderung)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Die Legendenstücke

/// Ein Strich der Legende, auch gestrichelt oder gepunktet.
///
/// **``Legendenstueck`` kann das nicht.** Es kennt Farbe und Höhe (`Umbruchzeile.swift:4`), und
/// die Vorlage zeichnet ihre Striche mit `border-top: 2px dashed` (`ForecastPage.tsx:197`). Im
/// Hauptdiagramm unterscheidet aber **nur** das Strichmuster die drei Reihen - ein
/// durchgezogener Klotz für Day-ahead wäre eine falsche Legende. Also ein `Path` mit `dash`.
struct Strichstueck: View {
    let wort: String
    let farbe: Color
    /// Leer heisst durchgezogen.
    var muster: [CGFloat] = []

    var body: some View {
        HStack(spacing: 6) {
            Canvas { gestalt, groesse in
                var strich = Path()
                strich.move(to: CGPoint(x: 0, y: groesse.height / 2))
                strich.addLine(to: CGPoint(x: groesse.width, y: groesse.height / 2))
                gestalt.stroke(
                    strich, with: .color(farbe),
                    style: StrokeStyle(lineWidth: 2, dash: muster))
            }
            .frame(width: 16, height: 4)
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }
}

/// Ein Klotz der Legende - für Säulen und Flächen.
struct Klotzstueck: View {
    let wort: String
    let farbe: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(farbe)
                .frame(width: 11, height: 11)
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }
}

/// Ein Punkt der Legende, in der Form seiner Punktreihe.
///
/// **Formen und nicht Striche** (`ForecastPage.tsx:318-321`). Die Faktorkarte hat drei Reihen,
/// von denen zwei Punktreihen sind; drei gleich aussehende Striche darunter würden die Raute und
/// den Kreis im Bild nicht erklären, sondern verwischen.
struct Formstueck: View {
    let wort: String
    let farbe: Color
    /// Rautenform: ein gedrehtes Quadrat, wie `symbol(.diamond)` im Bild.
    var raute: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if raute {
                Rectangle()
                    .fill(farbe)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))
                    .frame(width: 12, height: 12)
            } else {
                Circle().fill(farbe).frame(width: 9, height: 9)
            }
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }
}

// MARK: - 1. Das Hauptdiagramm

/// Ein Tag: das gemessene Ist, der Day-ahead-Lauf und der jüngste korrigierte Lauf.
///
/// **Das wichtigste Bild der Seite, und es fehlte ganz.** Hier steht die Frage, die die Seite
/// stellt: lag die Prognose über oder unter dem, was gekommen ist - und zu welcher Tageszeit.
/// Eine Tabelle mit Tagessummen beantwortet das nicht, denn ein Tag, der morgens zu hoch und
/// mittags zu tief lag, sieht in der Summe aus wie ein getroffener.
///
/// **Was gestrichelt ist, ist nicht gemessen.** Dieselbe Regel wie in ``TageskurveBild``: das
/// Ist ist eine Fläche mit voller Kante, Day-ahead ein langer Strich, der korrigierte Lauf ein
/// kurzer. Die Jetzt-Linie steht bei ``Prognosebild/Prognosetag/jetztStunde``, also bei
/// `generatedAt` der Antwort und nicht bei der Uhr des Geräts - sonst stünde sie bis zu fünf
/// Minuten neben dem letzten Ist-Punkt.
struct Prognosekurvenbild: View {
    let tag: Prognosebild.Prognosetag
    /// Der laufende Tag? Dann gibt es den korrigierten Lauf und die Jetzt-Linie.
    let heute: Bool
    /// Wann der Day-ahead-Lauf ausgegeben wurde, als ISO-Zeitpunkt - steht in der Legende.
    var ausgegeben: String?

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: Double?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ablesung
            if tag.leer {
                Leer(
                    satz: "Für diesen Tag sind keine Prognosepunkte da.",
                    dazu: "Der Bewerter hält die Läufe im Arbeitsspeicher; nach einem Neustart "
                        + "des Dienstes füllt sich der Tag von der nächsten Viertelstunde an.")
            } else {
                diagramm
            }
            legende
        }
    }

    private var diagramm: some View {
        Chart {
            // Die Fläche zuerst, damit die Striche darüber liegen. Die Stopps sind die der
            // Vorlage (`ForecastPage.tsx:58-61`): 0,30 oben, 0,03 unten.
            ForEach(tag.ist) { p in
                AreaMark(
                    x: .value("Stunde", p.stunde), y: .value("kW", p.wert),
                    series: .value("Reihe", "istFlaeche")
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Farbe.pv.opacity(0.30), Farbe.pv.opacity(0.03)],
                        startPoint: .top, endPoint: .bottom))
            }
            ForEach(tag.ist) { p in
                LineMark(
                    x: .value("Stunde", p.stunde), y: .value("kW", p.wert),
                    series: .value("Reihe", "ist")
                )
                .foregroundStyle(Farbe.pv)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            ForEach(tag.dayAhead) { p in
                LineMark(
                    x: .value("Stunde", p.stunde), y: .value("kW", p.wert),
                    series: .value("Reihe", "dayAhead")
                )
                .foregroundStyle(Farbe.dayAhead)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [7, 6]))
            }
            ForEach(tag.korrigiert) { p in
                LineMark(
                    x: .value("Stunde", p.stunde), y: .value("kW", p.wert),
                    series: .value("Reihe", "korrigiert")
                )
                .foregroundStyle(Farbe.mist)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
            }
            if let jetzt = tag.jetztStunde {
                // **Weiches Bernstein, nicht das der PV-Reihe.** Die Vorlage nimmt für beide
                // `#f2a900` (`ForecastPage.tsx:69`). In dieser App gilt die Regel aus
                // ``Fahrplanzeichnung``: die Jetzt-Linie darf nicht die Farbe einer Reihe im
                // selben Gitter tragen, sonst sind es zwei bernsteinfarbene Striche und keiner
                // sagt mehr, welcher „jetzt“ meint.
                RuleMark(x: .value("jetzt", jetzt))
                    .foregroundStyle(Farbe.amberWeich)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            if let g = gelesen {
                RuleMark(x: .value("gelesen", g))
                    .foregroundStyle(Farbe.text1.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: 0...24)
        .chartYScale(domain: 0...tag.leistungsgrenze)
        .chartXSelection(value: $gelesen)
        .chartXAxis {
            // Alle drei Stunden wie in der Vorlage, am Telefon alle sechs: acht Uhrzeiten auf
            // 390 Punkten sind ein Ziffernstreifen.
            AxisMarks(values: Array(stride(from: 0.0, through: 24.0, by: schmal ? 6.0 : 3.0))) {
                wert in
                AxisValueLabel {
                    if let d = wert.as(Double.self) {
                        Text(String(format: "%02d:00", Int(d) % 24))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            // Genau drei Marken - 0, Mitte, oben. Dafür ist die Leistungsgrenze im Kern auf
            // gerade Kilowatt gerundet; sonst stünde in der Mitte eine Zahl mit Komma.
            AxisMarks(
                position: .leading,
                values: [0, tag.leistungsgrenze / 2, tag.leistungsgrenze]
            ) { wert in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel {
                    if let d = wert.as(Double.self) {
                        Text("\(Formate.zahl(d, stellen: 0)) kW")
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .frame(height: schmal ? 200 : 260)
    }

    // MARK: Auskunft und Legende

    private var ablesung: some View {
        Ablesung(
            kopf: gelesen.map { Prognosezeichnung.uhrzeit($0) },
            zeilen: gelesen.map { zeilen($0) } ?? [],
            aufforderung: "Zum Lesen einer Viertelstunde die Zeichnung berühren.")
    }

    /// Die drei Reihen an der berührten Stelle. Was dort keinen Punkt hat, fällt weg - eine Null
    /// stünde für eine Messung, die es nicht gibt.
    private func zeilen(_ stunde: Double) -> [Ablesungszeile] {
        var aus: [Ablesungszeile] = []
        if let p = Prognosezeichnung.naechster(tag.ist, bei: stunde) {
            aus.append(
                Ablesungszeile(text: "Ist \(Formate.kwMitEinheit(p.wert))", farbe: Farbe.pv))
        }
        if let p = Prognosezeichnung.naechster(tag.dayAhead, bei: stunde) {
            aus.append(
                Ablesungszeile(
                    text: "Day-ahead \(Formate.kwMitEinheit(p.wert))", farbe: Farbe.dayAhead))
        }
        if let p = Prognosezeichnung.naechster(tag.korrigiert, bei: stunde) {
            aus.append(
                Ablesungszeile(
                    text: "Korrigiert \(Formate.kwMitEinheit(p.wert))", farbe: Farbe.mist))
        }
        return aus
    }

    /// Die Legende, und zwar unter dem Bild.
    ///
    /// **Am Telefon gehört sie dorthin** (`handy.css:54,266`), und hier auch an der Wand: über
    /// dem Bild steht schon der Umschalter Heute/Gestern im Kopf der Karte, und drei Striche
    /// daneben machen aus einer Kopfzeile eine Werkzeugleiste. Sie darf umbrechen - „Jüngster
    /// Lauf, korrigiert“ passt mit zwei Nachbarn auf 390 Punkte nicht in eine Zeile.
    private var legende: some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 5) {
            Strichstueck(wort: "Ist (15-min-Mittel)", farbe: Farbe.pv)
            Strichstueck(wort: dayAheadWort, farbe: Farbe.dayAhead, muster: [7, 6])
            if heute {
                Strichstueck(wort: "Jüngster Lauf, korrigiert", farbe: Farbe.mist, muster: [2, 4])
            }
            if tag.jetztStunde != nil {
                Strichstueck(wort: "jetzt", farbe: Farbe.amberWeich, muster: [4, 4])
            }
        }
    }

    /// „Day-ahead · ausgegeben 06:00“ - die Uhrzeit sagt, wie alt die Ankündigung ist.
    private var dayAheadWort: String {
        guard let ausgegeben else { return "Day-ahead" }
        return "Day-ahead · ausgegeben \(Formate.hhmm(iso: ausgegeben))"
    }
}

// MARK: - 2. Die Tagesenergie

/// Was angekündigt war gegen das, was gekommen ist - je Tag ein Säulenpaar.
///
/// **Dieselben Zahlen standen schon da, als Tabelle:** vier Spalten, am Telefon eine davon auf
/// einmal. Die Frage „gibt es eine Richtung“ - liegt die Prognose immer zu hoch oder nur an
/// einzelnen Tagen - lässt sich daran nicht sehen; an zwei Säulen nebeneinander sieht man sie,
/// ohne zu lesen.
struct Tagesenergiebild: View {
    let paare: [Prognosebild.Tagespaar]

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ablesung
            if paare.isEmpty {
                Leer(satz: "Noch kein abgeschlossener Tag.")
            } else {
                diagramm
            }
            Umbruchzeile(abstand: 14, zeilenabstand: 5) {
                Klotzstueck(wort: "Day-ahead", farbe: Farbe.dayAheadFlaeche)
                Klotzstueck(wort: "Ist", farbe: Farbe.pv)
            }
        }
    }

    private var diagramm: some View {
        Chart {
            // **Der Kalendertag ist die Kategorie, nicht sein Kürzel.** An der Achse steht „Mo“
            // (`ForecastPage.tsx:107`), aber in vierzehn Tagen kommt jeder Wochentag zweimal
            // vor - mit dem Kürzel als Wert fielen die beiden Montage in eine Säule.
            ForEach(paare) { p in
                BarMark(x: .value("Tag", p.tag), y: .value("kWh", p.prognose))
                    .foregroundStyle(Farbe.dayAheadFlaeche)
                    .position(by: .value("Reihe", "Day-ahead"))
                    .cornerRadius(2)
                BarMark(x: .value("Tag", p.tag), y: .value("kWh", p.ist))
                    .foregroundStyle(Farbe.pv)
                    .position(by: .value("Reihe", "Ist"))
                    .cornerRadius(2)
            }
        }
        .chartXSelection(value: $gelesen)
        .chartXAxis {
            AxisMarks(
                values: Achse.beschriftungen(paare.map(\.tag), hoechstens: schmal ? 7 : 14)
            ) { wert in
                AxisValueLabel {
                    if let s = wert.as(String.self) {
                        Text(kurz(s)).font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { wert in
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
        .frame(height: schmal ? 150 : 180)
    }

    private var ablesung: some View {
        let p = paare.first { $0.tag == gelesen }
        return Ablesung(
            kopf: p.map { $0.wochentag },
            zeilen: p.map { zeilen($0) } ?? [],
            aufforderung: "Zum Lesen eines Tages die Zeichnung berühren.")
    }

    private func zeilen(_ p: Prognosebild.Tagespaar) -> [Ablesungszeile] {
        [
            Ablesungszeile(text: "Day-ahead \(Formate.kwh(p.prognose))", farbe: Farbe.dayAhead),
            Ablesungszeile(text: "Ist \(Formate.kwh(p.ist))", farbe: Farbe.pv),
            Ablesungszeile(
                text: "Abweichung \(Formate.prozentpunkte(p.fehlerProzent)) · MAE "
                    + "\(Formate.zahl(p.mae, stellen: 2)) kW"),
        ]
    }

    /// „Mo“ zum Kalendertag an der Achse - fertig aus dem Kern, damit Achse und Auskunft
    /// dasselbe Datum meinen.
    private func kurz(_ tag: String) -> String {
        paare.first { $0.tag == tag }?.kurz ?? tag
    }
}

// MARK: - 3. Der Fehler nach Horizont

/// Je weiter voraus, desto schwerer: MAE und Betrag des Bias über drei Horizontklassen.
///
/// **Vorher eine Tabelle mit einer Spalte.** Es fehlten der Bias - also die Richtung des
/// Fehlers - und die Zahl der Paare, aus denen beides gerechnet ist. Eine Güte von 0,42 kW aus
/// vier Paaren ist etwas anderes als dieselbe Zahl aus vierhundert, und ohne die Zahl der Paare
/// sieht man den Unterschied nicht.
struct Horizontbild: View {
    let balken: [Prognosebild.Fehlerbalken]

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }

    /// Die Säulen, die es wirklich gibt.
    ///
    /// **Eine Klasse ohne Paare bekommt keine Null-Säule.** Der Kern setzt `mae` und `zweites`
    /// auf `nil`, sobald `paare` null ist; eine Säule der Höhe null sagt „kein Fehler“, und das
    /// ist der genaue Gegensatz von „nichts gemessen“.
    private var saeulen: [Prognosezeichnung.Saeule] {
        Prognosezeichnung.saeulen(balken, zweitname: "|Bias|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ablesung
            if saeulen.isEmpty {
                Leer(satz: "Noch keine Paare aus Prognose und Ist.")
            } else {
                diagramm
            }
            Umbruchzeile(abstand: 14, zeilenabstand: 5) {
                Klotzstueck(wort: "MAE", farbe: Farbe.mist)
                Klotzstueck(wort: "|Bias|", farbe: Farbe.text1.opacity(0.4))
            }
        }
    }

    private var diagramm: some View {
        Chart {
            ForEach(saeulen) { s in
                BarMark(x: .value("Horizont", s.name), y: .value("kW", s.wert))
                    .foregroundStyle(s.zweite ? Farbe.text1.opacity(0.4) : Farbe.mist)
                    .position(by: .value("Reihe", s.reihe))
                    .cornerRadius(2)
            }
        }
        .chartXSelection(value: $gelesen)
        .chartXAxis {
            AxisMarks(values: balken.map(\.name)) { wert in
                AxisValueLabel {
                    if let s = wert.as(String.self) {
                        Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
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
        .frame(height: schmal ? 150 : 170)
    }

    private var ablesung: some View {
        let b = balken.first { $0.name == gelesen }
        return Ablesung(
            kopf: b.map { $0.langname },
            zeilen: b.map { Prognosezeichnung.fehlerzeilen($0) } ?? [],
            aufforderung: "Zum Lesen einer Klasse die Zeichnung berühren.")
    }
}

// MARK: - 4. Die Korrekturfaktoren

/// Die gelernten Faktoren nach Sonnenhöhe, als Abweichung von 1,00.
///
/// **Die Karte, von der der Seitentitel handelt - und sie fehlte ganz.** „Stufe 1 ·
/// Bias-Korrektur je Sonnenhöhe“ stand als Kartentitel da, während `corrector.bins` in der App
/// an keiner Stelle gelesen wurde.
///
/// **Gezeichnet wird nicht der Faktor, sondern seine Abweichung von 1,00 in Prozentpunkten.**
/// Faktoren liegen zwischen 0,9 und 1,1; auf einer Achse von 0 bis 1,1 ist das ein Strich. Als
/// Abweichung wird die Achse symmetrisch um Null, die Säulen stehen auf der Nulllinie statt auf
/// dem Achsenboden, und „zu wenig“ zeigt nach unten statt nur ein Stück kürzer zu sein. Die
/// Rechnung und die Spanne stehen in ``Prognosebild/faktorbalken(_:)`` - die Spanne über alle
/// drei Reihen, damit die Raute von „gestern“ nicht abgeschnitten wird.
struct Faktorenbild: View {
    let bild: Prognosebild.Faktorbild

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ablesung
            if bild.klassen.isEmpty {
                Leer(
                    satz: "Noch nichts gelernt.",
                    dazu: "Die Korrektur je Sonnenhöhe braucht abgeschlossene Tage; bis dahin "
                        + "steht der Faktor jeder Klasse auf 1,00.")
            } else {
                diagramm
            }
            Umbruchzeile(abstand: 14, zeilenabstand: 5) {
                Klotzstueck(wort: "Faktor heute", farbe: Farbe.pv)
                Klotzstueck(wort: "Faktor unter 1,00", farbe: Farbe.alarm)
                Formstueck(wort: "gestern", farbe: Farbe.dayAhead, raute: true)
                Formstueck(wort: "letztes Ist/Prognose", farbe: Farbe.mist)
            }
        }
    }

    private var diagramm: some View {
        Chart {
            // **Die Nulllinie ist der Bezug und keine Rasterlinie.** In deren Ton
            // (`rasterlinie`, 9 % Weiss) wäre die Linie, auf der alle Säulen stehen, der
            // leiseste Strich des Bildes.
            RuleMark(y: .value("Prozentpunkte", 0.0))
                .foregroundStyle(Farbe.text1.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1))
            ForEach(bild.klassen) { k in
                if let a = k.abweichung {
                    BarMark(x: .value("Sonnenhöhe", k.name), y: .value("Prozentpunkte", a))
                        // Rot heisst: die Prognose lag zu hoch, der Faktor zieht sie herunter.
                        // Das ist die Richtung und keine Bewertung (`ForecastPage.tsx:156`).
                        .foregroundStyle(k.unterEins ? Farbe.alarm : Farbe.pv)
                        .cornerRadius(2)
                }
                if let g = k.gestern {
                    PointMark(x: .value("Sonnenhöhe", k.name), y: .value("Prozentpunkte", g))
                        .foregroundStyle(Farbe.dayAhead)
                        .symbol(.diamond)
                        .symbolSize(70)
                }
                if let l = k.letztes {
                    PointMark(x: .value("Sonnenhöhe", k.name), y: .value("Prozentpunkte", l))
                        .foregroundStyle(Farbe.mist)
                        .symbol(.circle)
                        .symbolSize(45)
                }
            }
        }
        .chartYScale(domain: bild.spanne)
        .chartXSelection(value: $gelesen)
        .chartXAxis {
            AxisMarks(values: bild.klassen.map(\.name)) { wert in
                AxisValueLabel {
                    if let s = wert.as(String.self) {
                        Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: marken) { wert in
                AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                AxisValueLabel {
                    if let d = wert.as(Double.self) {
                        Text(Formate.prozentpunkte(d, stellen: 0))
                            .font(Schrift.achse)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .frame(height: schmal ? 150 : 180)
    }

    /// Fünf Marken, symmetrisch um Null (`ForecastPage.tsx:147`: `interval: span / 2`).
    private var marken: [Double] {
        let weit = bild.spanne.upperBound
        return [-weit, -weit / 2, 0, weit / 2, weit]
    }

    private var ablesung: some View {
        let k = bild.klassen.first { $0.name == gelesen }
        return Ablesung(
            kopf: k.map { "Sonnenhöhe \($0.name)" },
            zeilen: k.map { zeilen($0) } ?? [],
            aufforderung: "Zum Lesen einer Sonnenhöhenklasse die Zeichnung berühren.")
    }

    /// **Drei Nachkommastellen beim Faktor, nicht eine** (`ForecastPage.tsx:175`). Der
    /// Unterschied zwischen 1,073 und 1,068 ist die ganze Nachricht dieser Karte; auf eine
    /// Stelle gerundet wären beide 1,1.
    ///
    /// Gestern und das letzte Verhältnis stehen als Prozentpunkte da und nicht als Faktor - das
    /// ist, was im Bild als Raute und als Kreis liegt, und zwei Maßstäbe in einer Auskunft wären
    /// eine Falle für den, der sie vergleicht.
    private func zeilen(_ k: Prognosebild.Faktorbild.Klasse) -> [Ablesungszeile] {
        var aus: [Ablesungszeile] = [
            Ablesungszeile(
                text: "Faktor \(Formate.zahl(k.faktor, stellen: 3))",
                farbe: k.unterEins ? Farbe.alarm : Farbe.pv)
        ]
        if let g = k.gestern {
            aus.append(
                Ablesungszeile(
                    text: "gestern \(Formate.prozentpunkte(g))", farbe: Farbe.dayAhead))
        }
        if let l = k.letztes {
            aus.append(
                Ablesungszeile(
                    text: "letztes Ist/Prognose \(Formate.prozentpunkte(l))", farbe: Farbe.mist))
        }
        if let lerntage = k.lerntage {
            aus.append(Ablesungszeile(text: "\(lerntage) Lerntage"))
        }
        return aus
    }
}

// MARK: - 5. Der Rückblick

/// Die abgelegten Läufe gegen das Ist, nach Vorlaufzeit - Säule und Rand.
///
/// **Was der Rückblick anderes sagt als die Bewertung.** Die Bewertung zeigt, was der Bewerter
/// im Arbeitsspeicher hat; der Rückblick liest die abgelegten Läufe und ordnet jedes Paar nach
/// dem Abstand zwischen Lauf und Lieferzeit. Daran sieht man, ab welcher Vorlaufzeit eine
/// Prognose brauchbar ist - sechs Klassen von „0-1h“ bis „24-48h“. In der App waren es drei
/// Zahlen in einer Tabelle.
///
/// **Der Rand von 95 % gehört dazu.** Der mittlere Fehler sagt, wie es im Schnitt lief; die
/// Frage, auf die ein Fahrplan antwortet, ist aber, wie schlimm es schlimmstenfalls kam. Darum
/// die gestrichelte Linie mit Punkten über den Säulen (`Rueckblick.tsx:66-83`).
struct Vorlaufbild: View {
    let balken: [Prognosebild.Fehlerbalken]
    /// Die Einheit der Reihe. Nicht jede ist eine Leistung - heute ist es die Heizlast in kW.
    let einheit: String

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gelesen: String?

    private var schmal: Bool { breite == .compact }

    /// Keine einzige Klasse hat ein Paar: dann gehört ein Satz in das Bild und keine leere Achse.
    private var ohnePaare: Bool {
        balken.allSatisfy { $0.paare == 0 }
    }

    private var saeulen: [Prognosezeichnung.Saeule] {
        Prognosezeichnung.saeulen(balken, zweitname: "Rand (95 %)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ablesung
            diagramm
            Umbruchzeile(abstand: 14, zeilenabstand: 5) {
                Klotzstueck(wort: "mittlerer Fehler", farbe: Farbe.mist)
                Strichstueck(wort: "Rand (95 %)", farbe: Farbe.alarm, muster: [4, 4])
            }
        }
    }

    private var diagramm: some View {
        Chart {
            ForEach(saeulen) { s in
                if s.zweite {
                    LineMark(
                        x: .value("Vorlauf", s.name), y: .value(einheit, s.wert),
                        series: .value("Reihe", "rand")
                    )
                    .foregroundStyle(Farbe.alarm)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .symbol(.circle)
                    .symbolSize(45)
                } else {
                    // Die Breite als Anteil der Spalte: die `barWidth: "52%"` der Vorlage
                    // (`Rueckblick.tsx:63`). Swift Charts kennt dafür `MarkDimension`.
                    BarMark(
                        x: .value("Vorlauf", s.name), y: .value(einheit, s.wert),
                        width: .ratio(0.52)
                    )
                    .foregroundStyle(Farbe.mist)
                    .cornerRadius(2)
                }
            }
        }
        .chartXSelection(value: $gelesen)
        .chartXAxis {
            AxisMarks(values: balken.map(\.name)) { wert in
                AxisValueLabel {
                    if let s = wert.as(String.self) {
                        Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
        .chartYAxis {
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
        .frame(height: schmal ? 150 : 180)
        .overlay {
            if ohnePaare {
                Text("keine Paare im Zeitraum")
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    private var ablesung: some View {
        let b = balken.first { $0.name == gelesen }
        return Ablesung(
            kopf: b.map { "\($0.langname) · \($0.paare) Paare" },
            zeilen: b.map { zeilen($0) } ?? [],
            aufforderung: "Zum Lesen einer Vorlaufklasse die Zeichnung berühren.")
    }

    private func zeilen(_ b: Prognosebild.Fehlerbalken) -> [Ablesungszeile] {
        [
            Ablesungszeile(
                text: "mittlerer Fehler \(Formate.zahl(b.mae, stellen: 2)) \(einheit)",
                farbe: Farbe.mist),
            Ablesungszeile(
                text: "Rand (95 %) \(Formate.zahl(b.zweites, stellen: 2)) \(einheit)",
                farbe: Farbe.alarm),
        ]
    }
}

// MARK: - Was mehrere Bilder teilen

/// Die Handgriffe, die in mehr als einem Bild dieser Seite vorkommen.
///
/// **Warum nicht im Kern.** Das sind zwei Formatierungen und eine Umordnung von Reihen für
/// `position(by:)` - also Fragen der Zeichnung und nicht der Rechnung. Was eine Zahl *ist*,
/// steht in ``Prognosebild``; wie sie an ihren Platz kommt, hier.
enum Prognosezeichnung {

    /// Eine Säule, die es wirklich gibt.
    ///
    /// **Warum die Reihen vorher umgeordnet werden.** Säulenpaare brauchen in Swift Charts
    /// `position(by:)` mit einer gemeinsamen Reihenkennung. Wären die beiden Säulen zwei
    /// `BarMark` in je einem `if let`, stünde in einer Klasse ohne zweite Größe die MAE-Säule
    /// nicht in ihrer halben Spalte, sondern mittig - und die Klassen wären nicht mehr
    /// vergleichbar. Mit einer flachen Reihe entscheidet die Kennung über den Platz.
    struct Saeule: Identifiable {
        let name: String
        let reihe: String
        let wert: Double
        /// Die zweite Größe: `|Bias|` bei den Horizonten, der Rand von 95 % im Rückblick.
        let zweite: Bool

        var id: String { name + "/" + reihe }
    }

    /// Die Fehlerbalken als flache Reihe von Säulen - ohne die, die keine Paare haben.
    static func saeulen(_ balken: [Prognosebild.Fehlerbalken], zweitname: String) -> [Saeule] {
        balken.flatMap { b in
            [
                b.mae.map { Saeule(name: b.name, reihe: "MAE", wert: $0, zweite: false) },
                b.zweites.map { Saeule(name: b.name, reihe: zweitname, wert: $0, zweite: true) },
            ].compactMap { $0 }
        }
    }

    /// Die drei Zeilen der Horizontauskunft: MAE, Betrag des Bias, Zahl der Paare.
    ///
    /// Die Zahl der Paare steht dabei, weil sie das Gewicht der beiden anderen Zahlen ist
    /// (`ForecastPage.tsx:139`). Der Betrag und nicht der Bias: so kommt er aus dem Kern, weil
    /// zwei Säulen nebeneinander keine Achse teilen, von denen die eine nach unten zeigen kann.
    static func fehlerzeilen(_ b: Prognosebild.Fehlerbalken) -> [Ablesungszeile] {
        [
            Ablesungszeile(text: "MAE \(Formate.zahl(b.mae, stellen: 2)) kW", farbe: Farbe.mist),
            Ablesungszeile(
                text: "|Bias| \(Formate.zahl(b.zweites, stellen: 2)) kW",
                farbe: Farbe.text1.opacity(0.7)),
            Ablesungszeile(text: "n = \(b.paare)"),
        ]
    }

    /// Eine Stelle der Stundenachse als Uhrzeit: 13,75 wird „13:45“.
    static func uhrzeit(_ stunde: Double) -> String {
        let minuten = Int((stunde * 60).rounded())
        return String(format: "%02d:%02d", (minuten / 60) % 24, minuten % 60)
    }

    /// Der Punkt, der der berührten Stelle am nächsten liegt - oder keiner.
    ///
    /// **Mit Grenze, und die ist nicht Zierde.** Ohne sie zeigte die Auskunft nachts um drei den
    /// Mittagswert, weil er der einzige Punkt der Reihe ist. Eine Viertelstunde nach links und
    /// rechts ist das Raster der Antwort; alles darüber hinaus ist keine Auskunft über diese
    /// Stelle.
    static func naechster(_ punkte: [Kurvenpunkt], bei stunde: Double) -> Kurvenpunkt? {
        let nah = punkte.min { abs($0.stunde - stunde) < abs($1.stunde - stunde) }
        guard let nah, abs(nah.stunde - stunde) <= 0.25 else { return nil }
        return nah
    }
}
