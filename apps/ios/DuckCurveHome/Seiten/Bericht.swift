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
    /// Der Fehler einer **zweiten** Abfrage, die die Seite selbst haelt - als Band neben dem,
    /// was schon dasteht.
    ///
    /// **Warum das hierher gehoert und nicht in ``inhalt``.** ``inhalt`` wird nur gebaut, wenn
    /// eine Antwort da ist. Eine Seite, die ihr Band dort hineinschreibt - so tat es die
    /// Heizkreisseite mit dem Fehler der Istwerte -, verliert es genau dann, wenn die
    /// Hauptabfrage noch unterwegs ist oder selbst scheiterte: statt zweier Nachrichten steht
    /// dann „Wird geholt …“ da, und der Knopf, der es noch einmal versucht, ist mit
    /// verschwunden. Die Vorlage setzt das Band **neben** den Inhalt und ersetzt ihn nie
    /// (`HeatOverview.tsx:138`: `{error ? <ErrorBanner/> : null}` vor den Karten, die weiter
    /// gezeichnet werden).
    ///
    /// **Sieben Ansichten benutzen es inzwischen fuer den Spannenstreifen.** Der haengt am
    /// Anker und nicht am Zeitraum und ist darum ein eigener Zustand (``Spannenstand``); faellt
    /// er ganz aus, steht sein Grund hier - und das Band der Hauptabfrage bleibt davon
    /// unberuehrt. Zwei Zustaende, zwei Fehlerwege.
    var nebenfehler: ApiFehler?
    /// Was der Knopf an diesem Band ausloest. Ohne ihn steht es ohne Knopf, wie in der Vorlage
    /// (`ReportShell.tsx:147-153`).
    var nebenfehlerErneut: (() -> Void)?
    /// Wo in der Antwort steht, wann der Dienst sie gerechnet hat (`generated_at`).
    ///
    /// **Warum die Seite nur die Stelle nennt und nicht die Regel.** Seit der Dienst
    /// Auswertungen zwischenspeichert, ist eine Antwort nicht mehr in jedem Fall von jetzt. Wann
    /// das dastehen muss, ist eine Entscheidung fuer alle dreizehn Seiten und steht einmal im
    /// Kern (``Berichtsstand``); hier steht nur, aus welchem Feld der Zeitstempel kommt. Ohne
    /// Angabe steht keine Zeile - Seiten, deren Antwort keinen Stempel traegt, sollen keinen
    /// erfinden.
    var gerechnetAm: ((Antwort) -> String?)?

    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @State private var antwort: Antwort?
    @State private var fehler: ApiFehler?
    @State private var laedt = false

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        Seite(zeitraum: Zeitraumleiste(spannen: spannen)) {
            if let nebenfehler {
                Stoerung(fehler: nebenfehler, erneut: nebenfehlerErneut)
            }
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade(z, erzwingen: true) } }
            }
            if let antwort {
                if let satz = Berichtsstand.satz(
                    gerechnetAm: gerechnetAm?(antwort), jetzt: haus.jetzt)
                {
                    Kartenhinweis(satz: satz, mono: true)
                }
                inhalt(antwort)
                    .opacity(laedt ? 0.55 : 1)
                    .animation(.easeInOut(duration: Marken.dauer), value: laedt)
            } else if laedt {
                // **Die wichtigste Stelle der Ente: hier wartet jede der dreizehn
                // Auswertungsseiten.** Der Satz ist Zeichen fuer Zeichen der, der hier stand
                // (``Ladehinweis/berichtssatz``); die grosse Stufe, weil der Hinweis an der
                // Stelle der ganzen Seite steht und der einzige auf ihr ist - die Begruendung
                // steht an ``Ladehinweis/Stufe``.
                Karte { Ladeente(satz: Ladehinweis.berichtssatz, stufe: .gross) }
            } else if fehler == nil {
                Karte { Leer(satz: "Für diesen Zeitraum ist nichts da.") }
            }
        }
        .task(id: z) { await halteFrisch(z) }
    }

    /// Holen und im Fuenf-Minuten-Takt nachholen, solange die Seite steht.
    ///
    /// **Warum das Nachladen im Gerippe steht und nicht in dreizehn Seiten.** Die Vorlage hat
    /// es an einer Stelle, dem Haken, den alle Berichte benutzen (`useReport.ts:39` und `:70`:
    /// `setInterval(() => void load(), REFRESH_MS)`). An einer Wandanzeige, die den ganzen Tag
    /// auf „heute“ steht, wechselt der Zeitraum nie - und ohne Takt stuende dort abends der
    /// Stand vom Morgen, ohne dass es dasteht.
    ///
    /// Der Takt steht als ``Berichtstakt/nachladen`` im Kern und nicht hier: seit der
    /// Spannenstreifen ein eigener Zustand mit einer eigenen Schleife ist, braucht ihn auch
    /// jede Seite, die einen hat - und zwei Mal „300“ im Code waeren zwei Mal die Gelegenheit,
    /// es verschieden zu tun.
    ///
    /// Die Schleife haengt an `.task(id:)` und endet damit mit dem Zeitraum und mit der Seite.
    /// Muster und `try?`-Haltung sind die des Ruhebildes, das dieselbe Zahl nachholt
    /// (`Bausteine/Ambiente.swift:520-531`): ein Fehlschlag loescht nichts, weil
    /// ``lade(_:erzwingen:still:)`` die alte Antwort stehen laesst.
    ///
    /// **Nur das erste Holen ist zu sehen.** Danach wird still nachgeholt: das Band „laedt“
    /// dieser App ist die halbe Deckung auf dem Inhalt, und die alle fuenf Minuten aufblitzen
    /// zu lassen waere an einer Wandanzeige ein Flackern ohne Anlass. Die Vorlage benutzt ihr
    /// `loading` ebenfalls nur, solange noch nichts dasteht (`DataCheck.tsx:83`,
    /// `YearMap.tsx:127`: „laedt …“ statt eines leeren Kastens), und nie, um Vorhandenes
    /// abzudunkeln. Der Wechsel des Zeitraums und der Knopf am Fehlerband sind dagegen
    /// erfragt und duerfen sich zeigen.
    private func halteFrisch(_ z: Zeitraum) async {
        var erstes = true
        while !Task.isCancelled {
            await lade(z, still: !erstes)
            erstes = false
            try? await Task.sleep(for: Berichtstakt.nachladen)
        }
    }

    private func lade(_ z: Zeitraum, erzwingen: Bool = false, still: Bool = false) async {
        if !still { laedt = true }
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
///
/// **Dasselbe noch einmal, eine Runde spaeter.** Drei weitere Seiten kamen mit Wuenschen, die
/// sie sich inzwischen daneben gebaut hatten: ein Kopf ueber der Namensspalte
/// (``namenskopf``, `Fahrplan.tsx:697`), eine Spalte, in der kein Wert steht
/// (``Spalte/linksbuendig``, `RoomsReport.tsx:535`), das Raster je Zeile am Telefon
/// (``Handyfassung/block``, `handy.css:319-329`) und „welche Spalten am Telefon“ getrennt von
/// „welche zuerst“ (``festeSpalten``, `handy.css:378`). Alle vier sind wahlfrei und hinten
/// angehaengt; was sie aufloesen, steht an ihnen.
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
        /// Links, in Satzschrift und leise: eine Spalte, in der kein Wert steht.
        ///
        /// **Nicht jede Spalte hinter dem Namen ist eine Zahl.** ``volleZeile`` richtet jede
        /// rechts aus und setzt sie in Zahlenschrift - richtig fuer „1.284,5 kWh“, falsch fuer
        /// die Etage eines Raums (`RoomsReport.tsx:520`, `:535`: der Kopf ohne `text-right`,
        /// die Zelle ohne `mono` und in `text-3`) und falsch fuer die Begruendung des
        /// Fahrplans (`Fahrplan.tsx:703`, `:722`: dasselbe, und „weil der Preis im untersten
        /// Viertel liegt“ ist ein Satz, kein Wert). Gesetzt heisst: links, in derselben Schrift
        /// wie der Zeilenname - in der Vorlage unterscheiden sich die beiden Zellen nur in der
        /// Farbe - und leise in ``Farbe/text3``, wo die Spalte keine eigene Farbe traegt.
        var linksbuendig: Bool = false
        /// Die Zellen, die die Blockfassung am Telefon statt ``zellen`` zeigt.
        ///
        /// **Ohne Kopfzeile traegt die Zelle ihr Wort selbst.** ``Handyfassung/block`` laesst
        /// die Kopfzeile weg, und die Vorlage haengt den Spaltennamen dort an die Zelle, wo
        /// die Einheit nichts sagt (`handy.css:328`: `::before { content: "Ofen " }`,
        /// `:346-347`: „ offen“ und „ davon geheizt“ als `::after`). „brennt“ allein in der
        /// rechten Ecke sagt nicht, was brennt. Leer heisst: dieselben Zellen wie am iPad.
        var handyzellen: [String] = []
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
        /// Je Zeile ein eigenes kleines Raster: alle Spalten gleichzeitig zu sehen.
        ///
        /// `spitze` ist die Spalte oben rechts, `fuss` die umbrechende Zeile darunter - oder
        /// `nil`, wo die Tabelle keine hat. Begruendet steht die Fassung an
        /// ``blockfassung(spitze:fuss:)``.
        case block(spitze: Int, fuss: Int?)
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
    /// Der Kopf ueber der Namensspalte.
    ///
    /// **Eine Kopfzeile, die mit einer leeren Zelle anfaengt, laesst offen, was dort steht.**
    /// Die Vorlage beschriftet die erste Spalte wie die anderen - „Zeit“ im Fahrplan
    /// (`Fahrplan.tsx:697`), „Raum“ in der Raumtabelle (`RoomsReport.tsx:519`). Hier stand
    /// `Text("")`. Leer bleibt erlaubt: eine Tabelle, deren Zeilennamen die Kennzahlen eines
    /// Reglers sind, hat kein Wort fuer die Spalte, und die Vorlage setzt dort auch keines.
    var namenskopf: String = ""
    /// Welche Spalten am Telefon nebeneinander stehen - als Liste und nicht als Anzahl.
    ///
    /// **„Welche Spalten“ und „welche zuerst“ sind zwei Fragen.** ``immerSichtbar`` haelt die
    /// **ersten** n Spalten fest; die Vorlage blendet aber mitten in der Reihe aus
    /// (`handy.css:378`: die Raumtabelle versteckt Etage, Ventil und Kreise und laesst Raum,
    /// Ist, Ziel und Abweichung stehen). Die Heizkreisseite stellte dafuer zwei Spaltenlisten
    /// nach Breite auf - zwei Beschreibungen derselben Tabelle, an einer von beiden wird die
    /// naechste Spalte vergessen. Gesetzt gilt diese Liste, sonst ``immerSichtbar``.
    var festeSpalten: [Int]?

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
        case .block(let spitze, let fuss): blockfassung(spitze: spitze, fuss: fuss)
        }
    }

    /// Welche Spalten am Telefon nebeneinander stehen.
    private var feste: [Int] {
        if let festeSpalten {
            return festeSpalten.filter { $0 >= 0 && $0 < spalten.count }
        }
        return Array(0..<min(max(1, immerSichtbar), spalten.count))
    }

    /// Ob am Telefon die feste Liste steht und nicht der Spaltenumschalter.
    private var festeFassung: Bool {
        festeSpalten != nil || immerSichtbar > 1
    }

    /// **Entweder die feste Liste oder die eine umgeschaltete Spalte, nie beides.** Bis hierher
    /// stand bei mehr als einer festen Spalte die feste Liste **und** darunter noch einmal die
    /// einspaltige Liste derselben Zeilen: auf `/waerme/raeume` stand damit am Telefon jeder
    /// Raum zweimal - erst mit Ist, Ziel und Abweichung, dann noch einmal mit nur „Ist“. Die
    /// zweite Liste war nicht in das `else` gezogen, zu dem sie gehoert.
    @ViewBuilder private var handyliste: some View {
        if festeFassung {
            festeListe
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if spalten.count > 1 {
                    spaltenwahl
                }
                einspaltigeListe
            }
        }
    }

    /// Die eine Spalte, die der Umschalter waehlt.
    private var einspaltigeListe: some View {
        VStack(spacing: 0) {
            ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                if i > 0 { Divider().overlay(Farbe.linie1) }
                zeilenrahmen(i) { handyzeile(i, name: name) }
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
                Text(namenskopf)
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(feste, id: \.self) { s in
                    Text(spalten[s].name)
                        .font(Schrift.achse)
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: ausrichtung(s))
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
                    .font(linksbuendig(s) ? Schrift.klein : Schrift.zahlKlein)
                    .foregroundStyle(farbe(spalte: s, zeile: i))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: ausrichtung(s))
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
            Text(namenskopf)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineLimit(1)
                .frame(width: rollnamensbreite, alignment: .leading)
            ForEach(Array(spalten.enumerated()), id: \.offset) { s, spalte in
                Text(spalte.name)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                    .frame(width: breiteJeSpalte, alignment: ausrichtung(s))
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
                    .font(linksbuendig(s) ? Schrift.klein : Schrift.zahlKlein)
                    .foregroundStyle(farbe(spalte: s, zeile: i))
                    .lineLimit(1)
                    .frame(width: breiteJeSpalte, alignment: ausrichtung(s))
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

    // MARK: - Am Telefon je Zeile ein Raster, wo die Vorlage es so haelt

    /// Jede Zeile als eigenes kleines Raster, mit allen Spalten gleichzeitig.
    ///
    /// **`handy.css`, Entscheidung 4 - und ihre andere Haelfte.** Vier Tabellen baut die
    /// Vorlage am Telefon nicht zu *einer* Spalte um, sondern je Zeile zu einem Raster.
    /// `handy.css:305-306` zaehlt sie auf: die Kosten (`:309-316`), die Entscheidungen des
    /// Fahrplans (`:319-329`), die Linien des Rueckblicks (`:333-337`) und das offene Fenster
    /// (`:340-347`). Die Form ist in allen vier dieselbe: oben links, was die Zeile ist, oben
    /// rechts die Zahl, um die es geht; darunter der Rest in einer Reihe; ganz unten, wo es
    /// einen gibt, der Satz ueber die ganze Breite.
    ///
    /// **Warum nicht die Liste mit dem Spaltenumschalter.** Bei der Entscheidungstabelle des
    /// Fahrplans waren damit Zeit und Preis zu sehen, und Bedarf, Puffer, Zustandswort, Ofen
    /// und die Begruendung waren weg, bis man tippt - auf einer Karte, die „die teuersten und
    /// die billigsten Viertelstunden, **mit Begruendung**“ heisst.
    ///
    /// **Warum sie hier steht und nicht in der Seite.** Die Fahrplanseite hatte sie sich selbst
    /// gebaut, weil dieser Baustein gesperrt war. Zwei Beschreibungen derselben Sache sind eine
    /// zu viel: an einer von beiden wird die naechste Spalte vergessen.
    ///
    /// Jede Zeile ist dort ein eigenes Raster, es gibt also keine Spalten ueber Zeilen hinweg -
    /// drei `HStack` sind dasselbe.
    private func blockfassung(spitze: Int, fuss: Int?) -> some View {
        let mitte = mittelspalten(spitze: spitze, fuss: fuss)
        return VStack(spacing: 0) {
            ForEach(Array(zeilennamen.enumerated()), id: \.offset) { i, name in
                if i > 0 { Divider().overlay(Farbe.linie1) }
                block(i, name: name, spitze: spitze, fuss: fuss, mitte: mitte)
                    // `padding: 12px 0`, die erste Zeile nur `padding-top: 2px`
                    // (`handy.css:319-320`).
                    .padding(.top, i == 0 ? 2 : 12)
                    .padding(.bottom, 12)
            }
        }
    }

    /// Die Spalten der Mittelzeile: alles ausser Spitze und Fuss, in ihrer Reihenfolge.
    private func mittelspalten(spitze: Int, fuss: Int?) -> [Int] {
        spalten.indices.filter { $0 != spitze && $0 != (fuss ?? -1) }
    }

    private func block(_ i: Int, name: String, spitze: Int, fuss: Int?, mitte: [Int])
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            blockkopf(i, name: name, spitze: spitze)
            if !mitte.isEmpty {
                blockmitte(i, mitte: mitte)
            }
            if let fuss {
                blockfuss(i, fuss: fuss)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Oben links der Zeilenname in 15 Punkten (`handy.css:322`), oben rechts die Spitze in 14
    /// (`:323`) - in ihrer Farbe, denn die setzt die Vorlage an der Zelle selbst
    /// (`Fahrplan.tsx:718`).
    private func blockkopf(_ i: Int, name: String, spitze: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(name).font(Schrift.mono(15)).foregroundStyle(Farbe.text1)
            Spacer(minLength: 8)
            Text(blockzelle(spalte: spitze, zeile: i))
                .font(Schrift.sans(14))
                .foregroundStyle(farbe(spalte: spitze, zeile: i))
        }
    }

    /// Die Mittelzeile: die Werte links in 13,5 Punkten Zahlenschrift (`handy.css:321`,
    /// `Fahrplan.tsx:713-716` gibt ihnen `mono`), die letzte Spalte rechts und leise
    /// (`handy.css:327`: `justify-self: end`, `color: var(--text-3)`).
    private func blockmitte(_ i: Int, mitte: [Int]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            ForEach(Array(mitte.dropLast()), id: \.self) { s in
                Text(blockzelle(spalte: s, zeile: i))
                    .font(Schrift.mono(13.5))
                    .foregroundStyle(farbe(spalte: s, zeile: i))
            }
            Spacer(minLength: 8)
            if let letzte = mitte.last {
                Text(blockzelle(spalte: letzte, zeile: i))
                    .font(Schrift.sans(13.5))
                    .foregroundStyle(blockfarbe(spalte: letzte, zeile: i))
            }
        }
    }

    /// Der Satz unter der Zeile: ueber die ganze Breite, umbrechend und leise
    /// (`handy.css:329`: `grid-column: 1 / -1`, `white-space: normal`, `line-height: 1.4`;
    /// `Fahrplan.tsx:722` gibt der Zelle `text-text-3`).
    private func blockfuss(_ i: Int, fuss: Int) -> some View {
        Text(blockzelle(spalte: fuss, zeile: i))
            .font(Schrift.sans(13.5))
            .foregroundStyle(Farbe.text3)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Die Zelle, die am Telefon dasteht: ``Spalte/handyzellen``, wo es sie gibt.
    private func blockzelle(spalte: Int, zeile: Int) -> String {
        guard spalte >= 0, spalte < spalten.count else { return Formate.leer }
        let eigen = spalten[spalte].handyzellen
        if zeile < eigen.count {
            return eigen[zeile]
        }
        return zelle(spalte: spalte, zeile: zeile)
    }

    /// Die Farbe der rechten Zelle der Mittelzeile.
    ///
    /// **Die Vorlage hat hier beides, und das ist kein Widerspruch.** `handy.css:327` faerbt
    /// die Zelle in `--text-3`; steht aber eine Farbe an der Zelle selbst - `Fahrplan.tsx:719`
    /// setzt `style={{ color }}`, wenn der Ofen brennt -, gewinnt die, weil eine Auszeichnung
    /// am Element die Regel einer Klasse schlaegt. Also: die Farbe der Spalte, sonst leise.
    private func blockfarbe(spalte: Int, zeile: Int) -> Color {
        guard spalte >= 0, spalte < spalten.count, zeile < spalten[spalte].farben.count else {
            return Farbe.text3
        }
        return spalten[spalte].farben[zeile] ?? Farbe.text3
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

    /// **Der Kopf der Namensspalte traegt dieselbe Schrift wie die anderen.** So macht es die
    /// Vorlage (`globals.css:908`: `.kl-tabelle th` gilt fuer jede Zelle der Kopfzeile). Hier
    /// stand `Text("")` ohne Schrift und damit in der Lauftextgroesse des Baums - eine leere
    /// Zelle, die die Kopfzeile um ein paar Punkte hoeher machte als ihre Beschriftungen.
    private var kopfzeile: some View {
        HStack {
            Text(namenskopf)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineLimit(engeZellen ? 1 : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(spalten.enumerated()), id: \.offset) { s, spalte in
                Text(spalte.name)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(engeZellen ? 1 : nil)
                    .frame(maxWidth: .infinity, alignment: ausrichtung(s))
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
                    .font(zellschrift(s))
                    .foregroundStyle(farbe(spalte: s, zeile: i))
                    .lineLimit(engeZellen ? 1 : nil)
                    .frame(maxWidth: .infinity, alignment: ausrichtung(s))
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

    private func linksbuendig(_ spalte: Int) -> Bool {
        spalte >= 0 && spalte < spalten.count && spalten[spalte].linksbuendig
    }

    private func ausrichtung(_ spalte: Int) -> Alignment {
        linksbuendig(spalte) ? .leading : .trailing
    }

    /// Die Schrift einer Zelle: Zahlenschrift, wo ein Wert steht - Satzschrift in der Groesse
    /// des Zeilennamens, wo ein Wort steht. In der Vorlage unterscheiden sich die beiden
    /// Zellen nur in der Farbe (`RoomsReport.tsx:534-535`).
    private func zellschrift(_ spalte: Int) -> Font {
        if linksbuendig(spalte) {
            return Schrift.klein
        }
        return engeZellen ? Schrift.zahlKlein : Schrift.zahl
    }

    /// Die Farbe einer Zelle. **Eine linksbuendige Spalte ist von sich aus leise**
    /// (`RoomsReport.tsx:535`, `Fahrplan.tsx:722`: beide `text-3`); eine eigene Farbe in
    /// ``Spalte/farben`` geht weiter vor.
    private func farbe(spalte: Int, zeile: Int) -> Color {
        guard spalte >= 0, spalte < spalten.count else { return Farbe.text1 }
        let vorgabe = spalten[spalte].linksbuendig ? Farbe.text3 : Farbe.text1
        guard zeile < spalten[spalte].farben.count else { return vorgabe }
        return spalten[spalte].farben[zeile] ?? vorgabe
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
    /// Die Punkte einer echten Liste, wo die Vorlage eine hat.
    ///
    /// **Die Vorlage setzt dafuer eine `<ul>` und nicht Absaetze.** Zwei Seiten geben die
    /// Methodensaetze des Dienstes als Liste aus (`Nachbetrachtung.tsx:249-253`,
    /// `Wirkung.tsx:254-258`), und `globals.css:735` gibt ihr 18 Punkte Einzug, 8 Punkte
    /// Abstand und die Punkte davor. Untereinander als Absaetze ist nicht zu sehen, dass es
    /// Punkte einer Aufzaehlung sind - und bei sieben Saetzen ueber eine Rechnung ist genau
    /// das die Auskunft: dass jeder einzeln gilt.
    let punkte: [String]
    /// Die Zeile, die **immer** dasteht - auch zugeklappt.
    ///
    /// **Sie ist der Grund, warum der Deckel zugehen darf.** Zugeklappt verschwindet alles
    /// darunter, und was eine Zahl an diesem Tag einschränkt, darf nicht verschwinden: eine
    /// Seite mit 61 Prozent Datenabdeckung sieht aus wie eine mit hundert. Die Vorlage trennt
    /// das darum ausdrücklich (`components/ui/Methode.tsx`: `kurz` steht im `summary`,
    /// `CoverageNote` setzt die Abdeckung dorthin).
    let kurz: String?
    var titel: String = "Wie das gerechnet ist"
    /// Ein Wort in den Absaetzen, das auf eine andere Seite fuehrt.
    ///
    /// **Der Verweis gehoert in den Satz und nicht als Zeile ueber die Karte.** Die Vorlage
    /// setzt „Annahmen“ mitten in den Satz, zu dem er gehoert (`HeatOverview.tsx:374-376`:
    /// „Wer diese Werte unter *Annahmen* aendert, aendert jede Zahl auf dieser Seite“). Auf
    /// der Waermeseite stand er als bernsteinfarbene Zeile ueber der Methodenkarte - ein Knopf
    /// ohne den Satz, der sagt, was dort zu aendern ist.
    var verweis: (wort: String, weg: String)?

    @State private var offen = false
    @Environment(\.horizontalSizeClass) private var breite
    @Environment(Wegweiser.self) private var wegweiser

    init(
        _ saetze: [String?], kurz: String? = nil, titel: String = "Wie das gerechnet ist",
        punkte: [String] = [], verweis: (wort: String, weg: String)? = nil
    ) {
        self.saetze = saetze.compactMap { $0 }.filter { !$0.isEmpty }
        self.punkte = punkte.filter { !$0.isEmpty }
        self.kurz = (kurz?.isEmpty ?? true) ? nil : kurz
        self.titel = titel
        self.verweis = verweis
    }

    /// **Zugeklappt, bis jemand fragt.** Sechs Berichtsseiten endeten mit 150 bis 210 Wörtern
    /// Methode, immer aufgeklappt - und was immer dasteht, liest niemand
    /// (`components/ui/Methode.tsx`).
    var body: some View {
        if !saetze.isEmpty || !punkte.isEmpty || kurz != nil {
            Karte {
                DisclosureGroup(isExpanded: $offen) {
                    rumpf
                } label: {
                    deckel
                }
                .tint(Farbe.text3)
            }
        }
    }

    /// Erst die Absaetze, dann die Liste - in dieser Reihenfolge stehen sie in der Vorlage, und
    /// der Abstand zwischen ihnen ist ihr `gap: 10px` (`globals.css:733`).
    @ViewBuilder private var rumpf: some View {
        if verweis == nil {
            inhalt
        } else {
            inhalt.environment(\.openURL, abfangen)
        }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(saetze.enumerated()), id: \.offset) { _, s in
                absatz(s)
            }
            if !punkte.isEmpty {
                liste
            }
        }
        .padding(.top, 8)
    }

    /// Ein Absatz des Methodentextes.
    ///
    /// **13 Punkte auf ``Farbe/text2``, am Telefon 14,5.** Die Vorlage setzt `.methode-absatz`
    /// auf `font-size: 13px; line-height: 1.55; color: var(--text-2)` (`globals.css:734`) und
    /// am Telefon auf 14,5 (`handy.css:217`). Hier standen 11,5 Punkte auf ``Farbe/text3``,
    /// auf jeder Breite dieselben - die leiseste Schrift der App fuer den Text, der erklaert,
    /// wie eine Energieabrechnung zustande kommt.
    private func absatz(_ satz: String) -> some View {
        Text(absatztext(satz))
            .font(Schrift.sans(absatzgroesse))
            // `line-height: 1.55`: SwiftUI zaehlt den Zuschlag auf die natuerliche Zeilenhoehe
            // der Schrift (rund 1,3 Em), es bleibt rund ein Viertel der Groesse - dieselbe
            // Rechnung wie in `HaustuerSeite.swift:183`.
            .lineSpacing(absatzgroesse * 0.25)
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
            // `max-width: 90ch` (`globals.css:734`), auf 13 Punkte gerechnet: ein `ch` der
            // Hausschrift ist rund ein halbes Em - dieselbe Umrechnung wie in
            // `HeizkreiseSeite.swift:246-249`.
            .frame(maxWidth: Self.lesebreite, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Die echte Liste: der Punkt steht im Einzug, der Text faengt dahinter an
    /// (`globals.css:735`: `padding-left: 18px`, `gap: 8px`, Punkte als Marke).
    private var liste: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(punkte.enumerated()), id: \.offset) { _, p in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("•")
                        .font(Schrift.sans(absatzgroesse))
                        .foregroundStyle(Farbe.text3)
                        .frame(width: Self.einzug, alignment: .leading)
                    absatz(p)
                }
            }
        }
    }

    private var deckel: some View {
        VStack(alignment: .leading, spacing: 3) {
            // **Keine Sperrschrift am Telefon.** `Karte` schaltet ihre Kopfzeile
            // dort auf lesbare Schrift um („Ueberschriften sind lesbare Schrift,
            // keine Sperrschrift“); diese hier ist zugleich der einzige Griff, mit
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

    private var absatzgroesse: CGFloat {
        breite == .compact ? 14.5 : 13
    }

    /// `max-width: 90ch` auf 13 Punkte (`globals.css:734`).
    private static let lesebreite: CGFloat = 585
    /// `padding-left: 18px` der Liste (`globals.css:735`).
    private static let einzug: CGFloat = 18

    /// Der Absatz als Text - mit dem Verweis an der Stelle, an der sein Wort darin vorkommt.
    ///
    /// **Warum ein `link`-Merkmal und kein Knopf.** Zusammengesetzte `Text` brechen richtig um,
    /// tragen aber keine Beruehrung je Stueck; ein `HStack` aus Text und Knopf bricht nicht um.
    /// Bleibt das Merkmal, das der Absatz mittraegt - dasselbe Mittel und derselbe Umlauf
    /// spaeter wie in `AnnahmenSeite.swift:477-516`.
    ///
    /// Kommt das Wort nicht vor, bleibt der Satz, wie er ist: ein Verweis, der ins Leere zeigt,
    /// ist schlimmer als keiner.
    private func absatztext(_ satz: String) -> AttributedString {
        guard let verweis, let stelle = satz.range(of: verweis.wort) else {
            return AttributedString(satz)
        }
        var aus = AttributedString(String(satz[satz.startIndex..<stelle.lowerBound]))
        var wort = AttributedString(verweis.wort)
        wort[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Farbe.amber
        wort.link = Verweisabsatz.adresse(verweis.weg)
        aus.append(wort)
        aus.append(AttributedString(String(satz[stelle.upperBound...])))
        return aus
    }

    /// Der Wegweiser wird vor dem Verschluss herausgelesen, damit die Schliessung an ihm haengt
    /// und nicht an dieser Ansicht. Geschrieben wird einen Umlauf spaeter: ein Schreiben aus
    /// dem Zeichnen heraus ist „Modifying state during view update“
    /// (`App/Navigation.swift:56-62`).
    private var abfangen: OpenURLAction {
        let ziel = wegweiser
        return OpenURLAction { adresse in
            guard let weg = Verweisabsatz.weg(aus: adresse) else { return .systemAction }
            Task { @MainActor in ziel.gehe(weg) }
            return .handled
        }
    }
}
