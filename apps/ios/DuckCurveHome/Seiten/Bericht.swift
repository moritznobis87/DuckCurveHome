import Charts
import DuckCurveKit
import SwiftUI

/// Das Gerippe einer Berichtsseite: Zeitraum oben, Laden, Fehler, Inhalt.
///
/// **Warum ein Gerippe und nicht zwanzig Mal dasselbe.** Dreizehn Berichtsseiten holen alle
/// dieselbe Art von Antwort zu einem Zeitraum, und jede davon muss drei Dinge koennen: beim
/// Wechsel des Zeitraums neu laden, waehrend des Ladens das Alte stehen lassen, und einen Fehler
/// zeigen, ohne die Seite zu ersetzen.
///
/// **Das Alte bleibt stehen, bis das Neue da ist.** Das ist die wichtigste der drei Regeln. Eine
/// Seite, die beim Blaettern leer wird und dann wieder fuellt, flackert bei jedem Schritt - und
/// an einer Wandanzeige, die ueber eine Woche blaettert, ist das unerträglich.
struct Berichtsseite<Antwort: Sendable, Inhalt: View>: View {
    /// Welche Spannen diese Seite anbietet.
    var spannen: [Spanne] = Spanne.allCases
    /// Die Abfrage. Bekommt Zeitraum und API, liefert die Antwort.
    let hole: (Zeitraum, Api) async throws -> Antwort
    @ViewBuilder let inhalt: (Antwort) -> Inhalt

    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @State private var antwort: Antwort?
    @State private var fehler: ApiFehler?
    @State private var laedt = false

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        Seite(zeitraum: Zeitraumleiste(spannen: spannen)) {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade(z, erzwingen: true) } }
            }
            if let antwort {
                inhalt(antwort)
                    .opacity(laedt ? 0.55 : 1)
                    .animation(.easeInOut(duration: Marken.dauer), value: laedt)
            } else if laedt {
                Karte { Leer(satz: "Wird geholt …") }
            } else if fehler == nil {
                Karte { Leer(satz: "Für diesen Zeitraum ist nichts da.") }
            }
        }
        .task(id: z) { await lade(z) }
    }

    private func lade(_ z: Zeitraum, erzwingen: Bool = false) async {
        laedt = true
        do {
            antwort = try await hole(z, haus.api)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
        laedt = false
    }
}

/// Ein Balkendiagramm ueber die Stuecke eines Zeitraums.
///
/// Das haeufigste Bild der Berichtsseiten: Stunden eines Tages, Tage einer Woche, Monate eines
/// Jahres. Gestapelt, wo sich die Teile zu einer Summe addieren.
struct Balkenbild: View {
    struct Stueck: Identifiable {
        let name: String
        let farbe: Color
        let werte: [(beschriftung: String, wert: Double)]
        var id: String { name }
    }

    let stuecke: [Stueck]
    var einheit: String = "kWh"
    var gestapelt: Bool = true
    var hoehe: CGFloat = 180

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    /// Die Woerter der x-Achse, in ihrer Reihenfolge und ohne Wiederholung.
    private var achsenwoerter: [String] {
        var gesehen = Set<String>()
        var aus: [String] = []
        for s in stuecke {
            for w in s.werte where !gesehen.contains(w.beschriftung) {
                gesehen.insert(w.beschriftung)
                aus.append(w.beschriftung)
            }
        }
        return aus
    }

    var body: some View {
        if stuecke.allSatisfy({ $0.werte.isEmpty }) {
            Leer(satz: "Keine Werte in diesem Zeitraum.")
        } else {
            Chart {
                ForEach(stuecke) { s in
                    ForEach(Array(s.werte.enumerated()), id: \.offset) { _, w in
                        BarMark(
                            x: .value("Zeit", w.beschriftung),
                            y: .value(einheit, w.wert),
                            stacking: gestapelt ? .standard : .unstacked
                        )
                        .foregroundStyle(by: .value("Reihe", s.name))
                        .cornerRadius(1)
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: stuecke.map(\.name),
                range: stuecke.map(\.farbe)
            )
            .chartLegend(position: .top, alignment: .leading, spacing: 6)
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
            .chartXAxis {
                // **Nicht jede Beschriftung, sondern die, die passen.** Swift Charts setzt an
                // eine Achse aus Woertern alle - bei einem Monat dreissig, und auf 390 Punkten
                // ist das ein Ziffernstreifen. Am Telefon sind sechs genug, am iPad zwoelf.
                AxisMarks(values: Achse.beschriftungen(achsenwoerter, hoechstens: schmal ? 6 : 12)) {
                    wert in
                    AxisValueLabel {
                        if let s = wert.as(String.self) {
                            Text(s).font(Schrift.achse).foregroundStyle(Farbe.text3)
                        }
                    }
                }
            }
            .frame(height: hoehe)
        }
    }
}

/// Eine Tabelle, die am Telefon zu einer Liste wird.
///
/// **`handy.css`, Entscheidung 4: „Tabellen werden Listen."** Vier Spalten passen nicht auf 390
/// Punkte. Am iPad stehen die Spalten nebeneinander, am Telefon wird eine gezeigt, die man
/// umschaltet - und die Umschaltung steht als Reihe von Woertern ueber der Liste, nicht als
/// Menue: ein Menue versteckt, welche Spalten es gibt.
struct Tabelle: View {
    struct Spalte: Identifiable {
        let name: String
        /// Die Zellen dieser Spalte, in der Reihenfolge der Zeilen.
        let zellen: [String]
        var id: String { name }
    }

    /// Die erste Spalte ist die Beschriftung der Zeile und wird nie ausgeblendet.
    let zeilennamen: [String]
    let spalten: [Spalte]

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gezeigt = 0

    private var schmal: Bool { breite == .compact }

    var body: some View {
        if zeilennamen.isEmpty {
            Leer(satz: "Keine Zeilen.")
        } else if schmal {
            handyliste
        } else {
            volleTabelle
        }
    }

    private var handyliste: some View {
        VStack(alignment: .leading, spacing: 8) {
            if spalten.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(spalten.enumerated()), id: \.offset) { i, s in
                            Button {
                                gezeigt = i
                            } label: {
                                Text(s.name)
                                    .font(Schrift.winzig)
                                    .foregroundStyle(i == gezeigt ? Farbe.deep : Farbe.text2)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(i == gezeigt ? Farbe.amberWeich : Farbe.flaeche3)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    HStack {
                        Text(name).font(Schrift.klein).foregroundStyle(Farbe.text2)
                        Spacer(minLength: 8)
                        Text(zelle(spalte: gezeigt, zeile: i))
                            .font(Schrift.zahl)
                            .foregroundStyle(Farbe.text1)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var volleTabelle: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(spalten) { s in
                    Text(s.name)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.bottom, 4)
            Divider().overlay(Farbe.linie2)
            ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                if i > 0 { Divider().overlay(Farbe.linie1) }
                HStack {
                    Text(name)
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(spalten.enumerated()), id: \.offset) { s, _ in
                        Text(zelle(spalte: s, zeile: i))
                            .font(Schrift.zahl)
                            .foregroundStyle(Farbe.text1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func zelle(spalte: Int, zeile: Int) -> String {
        guard spalte < spalten.count, zeile < spalten[spalte].zellen.count else {
            return Formate.leer
        }
        return spalten[spalte].zellen[zeile]
    }
}

/// Ein Absatz Text, wie der Dienst ihn liefert - Methodenhinweise, Annahmen, Vorbehalte.
///
/// Die sind nicht Beiwerk: in diesem Projekt steht in fast jeder Antwort ein `*_de`-Feld, das
/// sagt, wie eine Zahl zustande kam. Eine Zahl ohne diesen Satz ist in einer Energieabrechnung
/// eine Behauptung.
struct Methode: View {
    let saetze: [String]
    var titel: String = "Wie das gerechnet ist"

    init(_ saetze: [String?], titel: String = "Wie das gerechnet ist") {
        self.saetze = saetze.compactMap { $0 }.filter { !$0.isEmpty }
        self.titel = titel
    }

    var body: some View {
        if !saetze.isEmpty {
            Karte(kicker: titel) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(saetze.enumerated()), id: \.offset) { _, s in
                        Text(s)
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
