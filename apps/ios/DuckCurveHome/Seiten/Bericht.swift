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
    ///
    /// **Ohne Angabe die des Reiters** (`Bereiche.spannen(fuer:)`). Sie stand bis zum
    /// 18.11.2026 an jeder Seite einzeln, und seit die Wahl am Telefon im Gerippe steht, haette
    /// es sie damit an zwei Stellen gegeben - eine davon waere irgendwann falsch gewesen.
    var spannen: [Spanne]?
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
/// **`handy.css`, Entscheidung 4: „Tabellen werden Listen.“** Vier Spalten passen nicht auf 390
/// Punkte. Am iPad stehen die Spalten nebeneinander, am Telefon wird eine gezeigt, die man
/// umschaltet - und die Umschaltung steht als Reihe von Woertern ueber der Liste, nicht als
/// Menue: ein Menue versteckt, welche Spalten es gibt.
///
/// **Was hinten wahlfrei dazukommt, und warum es hier steht.** Dreizehn Seiten hängen an diesem
/// Gerippe. Zwei Umbauten brauchten mehr, als es konnte, und legten sich deshalb je eine eigene
/// Tabelle daneben - eine fast gleiche Kopie, nur mit anklickbarer Zeile. Zwei Beschreibungen
/// derselben Sache sind eine zu viel: an einer von beiden wird die nächste Spalte vergessen.
/// Also kann das Gerippe jetzt beides, Auswahl (``auswahl``) und seitliches Rollen
/// (``Handyfassung/rollt``), und beides ist wahlfrei - jeder vorhandene Aufruf bleibt, wie er
/// ist, und sieht aus wie vorher.
struct Tabelle: View {
    struct Spalte: Identifiable {
        let name: String
        /// Die Zellen dieser Spalte, in der Reihenfolge der Zeilen.
        let zellen: [String]
        /// Die Farbe je Zelle, wo eine gilt.
        ///
        /// **Warum eine Spalte Farbe tragen darf.** In der Entscheidungstabelle des Fahrplans
        /// stehen dieselben Wörter wie in den Streifen darüber - „angefordert“, „gemieden“,
        /// „brennt“ -, und die Vorlage färbt sie dort wie dort gleich
        /// (`waerme/Fahrplan.tsx:715-721`). Ohne Farbe muss man zweimal lesen, um zu sehen,
        /// dass es dieselbe Sache ist. Leer heißt: alles in `Farbe.text1`, wie bisher.
        var farben: [Color?] = []
        var id: String { name }
    }

    /// Wie die Tabelle am Telefon aussieht.
    ///
    /// **Die Liste ist die Regel, die Rolle die ausdrückliche Ausnahme der Vorlage.**
    /// `handy.css:305-306` baut vier Tabellen zu Listen um; genau zwei nimmt die Vorlage davon
    /// aus und lässt sie seitlich rollen - `.kl-rollt` mit `min-width: 940px`
    /// (`globals.css:912-913`), und am Telefon rollt die Fläche darum, während die Schrift
    /// kleiner wird (`handy.css:246-247`). Es sind die beiden breitesten Tabellen des Projekts:
    /// die Tage der Wärmepumpe (`waermepumpe/Betrieb.tsx:138`, elf Spalten) und die
    /// Reglerkennzahlen (`waermepumpe/Kennzahlen.tsx:50`, dreizehn). Bei so vielen Spalten ist
    /// die Reihe der Spaltennamen kein Angebot mehr: sie füllt am Telefon zwei Zeilen, und
    /// jeder Blick auf eine andere Spalte wirft die vorige weg.
    enum Handyfassung {
        /// Eine Spalte, umgeschaltet über die Reihe der Spaltennamen.
        case liste
        /// Alle Spalten nebeneinander, seitlich zu rollen.
        case rollt
    }

    /// Die erste Spalte ist die Beschriftung der Zeile und wird nie ausgeblendet.
    let zeilennamen: [String]
    let spalten: [Spalte]
    /// Wie viele Spalten am Telefon nebeneinander stehen, bevor die Umschaltung anfängt.
    ///
    /// **Eine Spalte ist die Regel, nicht das Gesetz.** `handy.css` sagt „Tabellen werden
    /// Listen“, und für die meisten Berichte stimmt das: vier Zahlen nebeneinander auf 390
    /// Punkten sind keine. Die Raumtabelle ist der Fall, für den die Vorlage selbst eine
    /// Ausnahme macht (`handy.css:377-379`: sie blendet Etage, Ventil und Kreise aus und
    /// lässt Ist, Ziel und Abweichung nebeneinander stehen) - drei kurze Zahlen gehören dort
    /// zusammen, weil die Abweichung die Differenz der beiden anderen ist.
    var immerSichtbar: Int = 1
    /// Am Telefon zur Liste werden oder seitlich rollen - Begründung an ``Handyfassung``.
    var handyfassung: Handyfassung = .liste
    /// Enge Zellen: eine Zeile je Zelle, in der kleineren Zahlenschrift.
    ///
    /// **Die Vorlage hat zwei Tabellenschriften, und das ist keine Laune.** `.kl-tabelle` steht
    /// in 14 px (`globals.css:907`), die Tabelle der Rechnungsseite in 12 px und `nowrap`
    /// (`InvoiceCheck.tsx:257`, `:281`). Bei acht Spalten in einer Karte bricht sonst
    /// „1.284,5 kWh“ in zwei Zeilen, und eine Tabelle mit zweizeiligen Zellen liest sich nicht
    /// mehr zeilenweise. Gilt nur für die volle Tabelle: am Telefon steht ohnehin eine Spalte,
    /// und die hat Platz.
    var engeZellen: Bool = false
    /// Welche Zeile hervorgehoben ist - in ``Farbe/zeileGewaehlt``.
    var gewaehlteZeile: Int?
    /// Was ein Tippen meldet. Ist es gesetzt, ist die ganze Zeile der Griff.
    ///
    /// **Ein zweites Tippen auf dieselbe Zeile wählt nicht ab.** Die Zeile meldet nur, welche
    /// sie ist; abgewählt wird nirgends - so hält es die Vorlage (`InvoiceCheck.tsx:117-125`:
    /// `open` setzt die Nummer und holt den Bericht, ohne einen Fall für die schon gewählte
    /// Zeile). Auf der Rechnungsseite hängt die ganze untere Hälfte an dieser Auswahl, und die
    /// darf kein Fehltipper leer räumen.
    var auswahl: ((Int) -> Void)?

    @Environment(\.horizontalSizeClass) private var breite
    @State private var gezeigt = 0

    private var schmal: Bool { breite == .compact }

    var body: some View {
        if zeilennamen.isEmpty {
            Leer(satz: "Keine Zeilen.")
        } else if schmal {
            handyansicht
        } else {
            volleTabelle
        }
    }

    @ViewBuilder private var handyansicht: some View {
        switch handyfassung {
        case .liste: handyliste
        case .rollt: rollfassung
        }
    }

    /// Welche Spalten am Telefon nebeneinander stehen.
    private var feste: [Int] {
        Array(0..<min(max(1, immerSichtbar), spalten.count))
    }

    private var handyliste: some View {
        VStack(alignment: .leading, spacing: 8) {
            if immerSichtbar > 1 {
                festeListe
            } else if spalten.count > 1 {
                spaltenwahl
            }
            VStack(spacing: 0) {
                ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    zeilenrahmen(i) { handyzeile(i, name: name) }
                }
            }
        }
    }

    /// Die Umschaltung als Reihe von Wörtern und nicht als Menü.
    private var spaltenwahl: some View {
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

    private func handyzeile(_ i: Int, name: String) -> some View {
        HStack {
            Text(name).font(Schrift.klein).foregroundStyle(Farbe.text2)
            Spacer(minLength: 8)
            Text(zelle(spalte: gezeigt, zeile: i))
                .font(Schrift.zahl)
                .foregroundStyle(farbe(spalte: gezeigt, zeile: i))
        }
    }

    /// Die Fassung mit mehreren festen Spalten: Kopfzeile, dann je Zeile Name und Zahlen.
    private var festeListe: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(feste, id: \.self) { s in
                    Text(spalten[s].name)
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.bottom, 4)
            Divider().overlay(Farbe.linie2)
            ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                if i > 0 { Divider().overlay(Farbe.linie1) }
                zeilenrahmen(i) { festeZeile(i, name: name) }
            }
        }
    }

    private func festeZeile(_ i: Int, name: String) -> some View {
        HStack {
            Text(name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(feste, id: \.self) { s in
                Text(zelle(spalte: s, zeile: i))
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(farbe(spalte: s, zeile: i))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Am Telefon seitlich rollen, wo die Vorlage es so hält

    /// Alle Spalten nebeneinander in einer Fläche, die seitlich rollt.
    ///
    /// **Feste Breiten, nicht gleich geteilte.** In einer rollenden Fläche gibt es keine Breite,
    /// die man teilen könnte: `maxWidth: .infinity` würde dort auf das Nötigste schrumpfen und
    /// die Spalten je nach Inhalt verschieden breit machen. Dieselbe Rechnung macht die
    /// ``Abrechnungstabelle``, die am iPad aus demselben Grund rollt.
    private var rollfassung: some View {
        let breiteJeSpalte = rollspaltenbreite
        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                rollkopf(breiteJeSpalte)
                Divider().overlay(Farbe.linie2)
                ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    zeilenrahmen(i, dehnen: false) {
                        rollzeile(i, name: name, breiteJeSpalte: breiteJeSpalte)
                    }
                }
            }
        }
    }

    private func rollkopf(_ breiteJeSpalte: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("").frame(width: rollnamensbreite, alignment: .leading)
            ForEach(spalten) { s in
                Text(s.name)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                    .frame(width: breiteJeSpalte, alignment: .trailing)
            }
        }
        .padding(.bottom, 4)
    }

    private func rollzeile(_ i: Int, name: String, breiteJeSpalte: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .frame(width: rollnamensbreite, alignment: .leading)
            ForEach(Array(spalten.enumerated()), id: \.offset) { s, _ in
                Text(zelle(spalte: s, zeile: i))
                    // Am Telefon steht die rollende Tabelle kleiner als am iPad
                    // (`handy.css:247`: 13 px statt 14).
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(farbe(spalte: s, zeile: i))
                    .lineLimit(1)
                    .frame(width: breiteJeSpalte, alignment: .trailing)
            }
        }
    }

    /// Die Breite der Namensspalte: dieselben 92 Punkte, mit denen die ``Abrechnungstabelle``
    /// ihren Zeitraumnamen misst (`Bausteine/Abrechnungstabelle.swift:32`) - „Fr., 14.11.“ und
    /// „Zustand 42“ brauchen nicht mehr.
    private var rollnamensbreite: CGFloat { 92 }

    /// Die Breite einer Zahlenspalte: die 940 Punkte, die die Vorlage für die ganze Tabelle
    /// vorschreibt (`globals.css:913`), auf ihre Spalten verteilt - und nie unter den 88
    /// Punkten einer Zahlenspalte der ``Abrechnungstabelle``
    /// (`Bausteine/Abrechnungstabelle.swift:34`), sonst rutscht „1.284,5 kWh“ aus der Zelle.
    private var rollspaltenbreite: CGFloat {
        guard !spalten.isEmpty else { return 88 }
        return max(88, (940 - rollnamensbreite) / CGFloat(spalten.count))
    }

    // MARK: - Am iPad: alle Spalten

    private var volleTabelle: some View {
        VStack(spacing: 0) {
            kopfzeile
            Divider().overlay(Farbe.linie2)
            ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                if i > 0 { Divider().overlay(Farbe.linie1) }
                zeilenrahmen(i) { volleZeile(i, name: name) }
            }
        }
    }

    private var kopfzeile: some View {
        HStack {
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(spalten) { s in
                Text(s.name)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(engeZellen ? 1 : nil)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.bottom, 4)
    }

    private func volleZeile(_ i: Int, name: String) -> some View {
        HStack {
            Text(name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .lineLimit(engeZellen ? 1 : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(spalten.enumerated()), id: \.offset) { s, _ in
                Text(zelle(spalte: s, zeile: i))
                    .font(engeZellen ? Schrift.zahlKlein : Schrift.zahl)
                    .foregroundStyle(farbe(spalte: s, zeile: i))
                    .lineLimit(engeZellen ? 1 : nil)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Die Zeile, und wo sie ein Griff ist

    /// Eine Zeile; ist ``auswahl`` gesetzt, ist sie zugleich der Griff.
    ///
    /// **Die Polsterung liegt innen und die Fläche außen.** Sonst endet die Hervorhebung am Text
    /// und nicht am Rand der Karte, und eine Zeile, deren Hintergrund schmaler ist als die
    /// Zeile, sieht aus wie ein Fehler.
    ///
    /// **Ohne ``auswahl`` bleibt die Polsterung von vorher.** Die dreizehn Seiten, die dieses
    /// Gerippe schon benutzen, sollen sich um keinen Punkt verschieben; einen Knopf, der nichts
    /// tut, bekommen sie auch nicht - er fängt Tippen ab, das sonst die Karte erreicht.
    @ViewBuilder
    private func zeilenrahmen<Inhalt: View>(
        _ i: Int, dehnen: Bool = true, @ViewBuilder inhalt: () -> Inhalt
    ) -> some View {
        if let auswahl {
            Button {
                auswahl(i)
            } label: {
                inhalt()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: dehnen ? CGFloat.infinity : nil, alignment: .leading)
                    .background(i == gewaehlteZeile ? Farbe.zeileGewaehlt : Color.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            inhalt().padding(.vertical, 6)
        }
    }

    private func farbe(spalte: Int, zeile: Int) -> Color {
        guard spalte < spalten.count, zeile < spalten[spalte].farben.count else {
            return Farbe.text1
        }
        return spalten[spalte].farben[zeile] ?? Farbe.text1
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
    /// Die Zeile, die **immer** dasteht - auch zugeklappt.
    ///
    /// **Sie ist der Grund, warum der Deckel zugehen darf.** Zugeklappt verschwindet alles
    /// darunter, und was eine Zahl an diesem Tag einschränkt, darf nicht verschwinden: eine
    /// Seite mit 61 Prozent Datenabdeckung sieht aus wie eine mit hundert. Die Vorlage trennt
    /// das darum ausdrücklich (`components/ui/Methode.tsx`: `kurz` steht im `summary`,
    /// `CoverageNote` setzt die Abdeckung dorthin).
    let kurz: String?
    var titel: String = "Wie das gerechnet ist"

    @State private var offen = false
    @Environment(\.horizontalSizeClass) private var breite

    init(_ saetze: [String?], kurz: String? = nil, titel: String = "Wie das gerechnet ist") {
        self.saetze = saetze.compactMap { $0 }.filter { !$0.isEmpty }
        self.kurz = (kurz?.isEmpty ?? true) ? nil : kurz
        self.titel = titel
    }

    /// **Zugeklappt, bis jemand fragt.** Sechs Berichtsseiten endeten mit 150 bis 210 Wörtern
    /// Methode, immer aufgeklappt - und was immer dasteht, liest niemand
    /// (`components/ui/Methode.tsx`).
    var body: some View {
        if !saetze.isEmpty || kurz != nil {
            Karte {
                DisclosureGroup(isExpanded: $offen) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(saetze.enumerated()), id: \.offset) { _, s in
                            Text(s)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        // **Keine Sperrschrift am Telefon.** `Karte` schaltet ihre Kopfzeile
                        // dort auf lesbare Schrift um („Ueberschriften sind lesbare Schrift,
                        // keine Sperrschrift"); diese hier ist zugleich der einzige Griff, mit
                        // dem die Karte aufgeht, und der soll nicht die kleinste Schrift der
                        // Seite sein.
                        if breite == .compact {
                            Text(titel).font(Schrift.karte).foregroundStyle(Farbe.text1)
                        } else {
                            Kicker(wort: titel)
                        }
                        if let kurz {
                            Text(kurz)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(Farbe.text3)
            }
        }
    }
}
