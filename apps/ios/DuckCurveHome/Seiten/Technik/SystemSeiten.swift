import Charts
import DuckCurveKit
import SwiftUI

/// Heizkreise: die Räume über einen Tag, als Zeitreihe.
///
/// Die Liste zum Stellen steht im Bereich Haus; hier geht es um den Verlauf. Das ist die Frage,
/// die eine Liste nicht beantwortet: ob ein Raum die Nacht hält, oder ob er morgens von unten
/// anfängt.
struct HeizkreiseSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Die Istwerte neben dem Tagesverlauf.
    ///
    /// **Zwei Abfragen auf einer Seite, und `Berichtsseite` kennt nur eine.** Der Tagesverlauf
    /// kommt aus `/rooms/history`, die heutigen Zahlen der Tabelle aus `/rooms`; die Vorlage
    /// holt letztere am laufenden Tag alle dreissig Sekunden nach (`RoomsReport.tsx:38`).
    /// Darum steht dieser Zustand neben dem Gerüst und nicht darin.
    @State private var live: RoomsLiveOut?
    @State private var fehlerLive: ApiFehler?

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        Berichtsseite { z, api in
            try await api.raeumeTag(z.anker, schrittMin: 15)
        } inhalt: { verlauf in
            if let f = fehlerLive {
                Stoerung(fehler: f) { Task { await holeLive(heute: z.anker == haus.heute) } }
            }
            // **Räume ohne Namen** (`RoomsReport.tsx:431-436`): die Brücke schickt die
            // Namensliste als eigene Meldung; bis dahin stehen die Kennungen da, und das
            // gehört dazugesagt.
            if live?.named == false, !verlauf.rooms.isEmpty {
                Text(
                    "Die Räume heißen hier nach ihrer Kennung in der Heizungsregelung. Die "
                        + "Namensliste kommt als eigene Meldung der Brücke und steht nach ihrem "
                        + "nächsten Start zur Verfügung."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            }
            if verlauf.rooms.isEmpty {
                Karte {
                    Leer(
                        satz: "Keine Räume",
                        dazu: "Es liegen keine Werte der Einzelraumregelung vor. Die Brücke "
                            + "liest sie, sobald in ihrer Konfiguration die Adresse des "
                            + "Controme-Servers eingetragen ist.")
                }
            } else {
                // **Die Hauptkarte, und zwar zuerst.** Nicht die Temperaturen, sondern die
                // Abweichung vom Ziel: zehn Raeume zwischen 18 und 21 Grad sind als Kurven
                // ein flaches Band. So macht es das Dashboard (`rooms/RoomsReport.tsx`), und
                // es beantwortet die Frage, die diese Seite stellt - welcher Raum bestimmt
                // die Vorlauftemperatur.
                Karte(
                    kicker: "Abweichung im Tagesverlauf",
                    beiwerk: AnyView(
                        Text(
                            "Je Raum und Viertelstunde die Abweichung vom Zielwert. Der Raum, "
                                + "der zuerst abfällt, bestimmt die nötige Vorlauftemperatur "
                                + "für alle."
                        )
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                    )
                ) {
                    Abweichungsmatrix(
                        verlauf: verlauf,
                        bisStelle: Raumabweichung.gewesen(tag: z.anker, jetzt: haus.jetzt)
                    )
                }
                Karte(kicker: "Die Räume als Tabelle") {
                    raumtabelle(verlauf, heute: z.anker == haus.heute)
                }
                // **Offen, nicht zugeklappt** (`RoomsReport.tsx:549-557`). Wer nicht weiß,
                // dass auf Sollwert plus Versatz geregelt wird, liest die Spalte „Ziel" als
                // das, was er eingestellt hat - und das ist sie nicht.
                Text(
                    "Geregelt wird auf Sollwert plus Versatz – Controme rechnet das in seiner "
                        + "eigenen Oberfläche vor und zeigt das Ergebnis als Zieltemperatur. "
                        + "Der Versatz ist dabei die Summe mehrerer benannter Anpassungen, "
                        + "nicht nur der Witterung. Die Antriebe am Verteiler sind auf oder zu "
                        + "– ein Zwischenwert im Streifen heißt „ein Teil der Kreise“ oder "
                        + "„einen Teil des Fensters“, nicht „halb offen“. Ein Tippen auf "
                        + "eine Kachel im Bereich Haus stellt den Sollwert dieses Raums, "
                        + "dauerhaft und in halben Grad; die Ventile bleiben Sache des Reglers."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: z.anker) { await holeLive(heute: z.anker == haus.heute) }
    }

    /// Die Tabelle der Vorlage: Raum, Etage, Ist, Ziel, Abweichung, Ventil am Tag, Kreise.
    ///
    /// **Ist und Ziel sind der letzte Messwert, kein Tagesmittel.** Hier stand „Im Tagesmittel"
    /// mit vier anderen Spalten; ein Mittel über einen Tag sagt aber nichts darüber, welcher
    /// Raum gerade abfällt - und genau das ist die Frage dieser Seite.
    private func raumtabelle(_ verlauf: RoomHistoryOut, heute: Bool) -> some View {
        let zeilen = Raumabweichung.tabellenzeilen(live: live, tag: verlauf, istHeute: heute)
        return Tabelle(
            zeilennamen: zeilen.map(\.name),
            spalten: [
                .init(name: "Ist", zellen: zeilen.map { Formate.celsius($0.ist, stellen: 1) }),
                .init(name: "Ziel", zellen: zeilen.map { Formate.celsius($0.ziel, stellen: 1) }),
                .init(
                    name: "Abweichung",
                    zellen: zeilen.map { $0.abweichung.map(Raumabweichung.kelvin) ?? Formate.leer },
                    farben: zeilen.map {
                        $0.abweichung.map { Color(Marken.abweichungsfarbe(kelvin: $0)) }
                    }),
                .init(name: "Etage", zellen: zeilen.map(\.etage)),
                .init(
                    name: "Ventil am Tag",
                    zellen: zeilen.map { Raumabweichung.anteilText($0.tagesventil) }),
                .init(
                    name: "Kreise",
                    zellen: zeilen.map { $0.kreise > 0 ? String($0.kreise) : Formate.leer }),
            ],
            // Ist, Ziel und Abweichung gehören am Telefon nebeneinander: die dritte Zahl ist
            // die Differenz der beiden anderen (`handy.css:377-379`).
            immerSichtbar: 3
        )
    }

    /// Die Istwerte holen und, solange der laufende Tag gezeigt wird, alle dreissig Sekunden
    /// nachziehen.
    private func holeLive(heute: Bool) async {
        while !Task.isCancelled {
            do {
                live = try await haus.api.raeume()
                fehlerLive = nil
            } catch {
                // Nur die Istwerte scheitern hier; der Tagesverlauf hat sein eigenes Gerüst.
                fehlerLive = error as? ApiFehler ?? .netz(error.localizedDescription)
            }
            guard heute else { return }
            try? await Task.sleep(for: Raumabweichung.liveTakt)
        }
    }
}

/// Anlage · Ein Tag: die Wiedergabe eines vergangenen Ortstags.
///
/// **Dieselben Bilder, über einen Tag abspielbar.** Der Dienst liefert den Tag als Folge von
/// Augenblicken (`frames`); hier läuft ein Schieber darüber, und die Anlagenwerte folgen ihm.
/// Das ist die Antwort auf „was ist an diesem Tag eigentlich passiert" – eine Frage, die keine
/// Tageskurve beantwortet, weil sie nur Leistungen zeigt und keine Temperaturen.
struct WiedergabeSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tag: String = ""
    @State private var wiedergabe: AnlageReplayOut?
    @State private var stelle: Double = 0
    @State private var laeuftAb = false
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            tagwahl
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let w = wiedergabe, !w.frames.isEmpty {
                Karte(kicker: "Wiedergabe", titel: zeitpunkt(w)) {
                    VStack(alignment: .leading, spacing: 12) {
                        schieber(w)
                        werte(w)
                    }
                }
                Methode(
                    w.hinweiseDe + [
                        "Aufgelöst in \(w.stepMin) Minuten, \(w.frames.count) Augenblicke.",
                    ]
                )
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task(id: tag) { await lade() }
        .task(id: laeuftAb) { await spiele() }
        .onAppear { if tag.isEmpty { tag = Tag.plus(haus.heute, -1) } }
    }

    private var tagwahl: some View {
        HStack(spacing: 8) {
            Button { tag = Tag.plus(tag, -1) } label: {
                Text("‹").font(Schrift.karte).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).foregroundStyle(Farbe.text2)
            Text(Tag.kurz(tag)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1).frame(minWidth: 92)
            Button { tag = Tag.plus(tag, 1) } label: {
                Text("›").font(Schrift.karte).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(tag < haus.heute ? Farbe.text2 : Farbe.text3)
            .disabled(tag >= haus.heute)
            Spacer(minLength: 8)
            Button {
                laeuftAb.toggle()
            } label: {
                Text(laeuftAb ? "Anhalten" : "Abspielen")
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.deep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Farbe.amberWeich)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func schieber(_ w: AnlageReplayOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Slider(value: $stelle, in: 0...Double(max(1, w.frames.count - 1)), step: 1)
                .tint(Farbe.amber)
            HStack {
                Text(Formate.hhmm(iso: w.von)).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                Spacer()
                Text(Formate.hhmm(iso: w.bis)).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func zeitpunkt(_ w: AnlageReplayOut) -> String {
        guard let rahmen = aktueller(w) else { return Tag.lang(w.day) }
        return Formate.hhmm(iso: rahmen.at)
    }

    private func aktueller(_ w: AnlageReplayOut) -> AnlageOut? {
        let i = Int(stelle)
        guard i >= 0, i < w.frames.count else { return w.frames.first }
        return w.frames[i]
    }

    private func werte(_ w: AnlageReplayOut) -> some View {
        Group {
            if let a = aktueller(w) {
                VStack(spacing: 0) {
                    Zeile(wort: "Sonne", wert: Formate.kw(a.strom.pvKw), einheit: "kW", farbe: Farbe.pv)
                    Zeile(wort: "Haus", wert: Formate.kw(a.strom.houseKw), einheit: "kW")
                    Zeile(
                        wort: "Wärmepumpe", wert: Formate.kw(a.strom.heatPumpKw), einheit: "kW",
                        farbe: Farbe.waermepumpe
                    )
                    if let aussen = a.outdoorC {
                        Zeile(wort: "draußen", wert: Formate.celsius(aussen, stellen: 1))
                    }
                    Zeile(wort: "Vorlauf", wert: Formate.celsius(a.waermepumpe.flowC, stellen: 1))
                    Zeile(wort: "Puffer", wert: Formate.prozent(a.speicher.soc))
                    Zeile(
                        wort: "Puffer oben",
                        wert: Formate.celsius(a.speicher.tempsC.first ?? nil, stellen: 1)
                    )
                    Zeile(wort: "offene Kreise", wert: "\(a.heizkreis.roomsOpen) von \(a.heizkreis.roomsTotal)")
                    if Int(stelle) < w.preisCtKwh.count,
                       let p = w.preisCtKwh[Int(stelle)]
                    {
                        Zeile(wort: "Strompreis", wert: Formate.zahl(p, stellen: 1), einheit: "ct/kWh")
                    }
                    if Int(stelle) < w.geplantWp.count,
                       let g = w.geplantWp[Int(stelle)]
                    {
                        Zeile(wort: "w.geplantWp", wert: g ? "freigegeben" : "nicht freigegeben")
                    }
                }
            }
        }
    }

    /// Abspielen: ein Augenblick je Viertelsekunde. Schnell genug, dass ein Tag in einer Minute
    /// durchläuft, langsam genug, dass man etwas sieht.
    private func spiele() async {
        guard laeuftAb else { return }
        while laeuftAb, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let w = wiedergabe else { return }
            let letzte = Double(max(1, w.frames.count - 1))
            if stelle >= letzte {
                stelle = 0
            } else {
                stelle += 1
            }
        }
    }

    private func lade() async {
        guard Tag.istTag(tag) else { return }
        do {
            wiedergabe = try await haus.api.anlageWiedergabe(tag: tag)
            stelle = 0
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

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

    /// Was in der Vorlage im Kopf der Hülle steht: die Sache, der Stand, die Marke.
    ///
    /// **Am Telefon fällt der Stand weg.** Die Vorlage blendet ihn unter 1400 px aus
    /// (`ForecastPage.tsx:246`), und aus demselben Grund: „Stand 14:35 · Bridge (PV-Prognose)“
    /// neben einer Überschrift auf 390 Punkten lässt von der Überschrift zwei Wörter übrig. Die
    /// Uhrzeit steht ohnehin in der Jetzt-Linie des Hauptdiagramms.
    @ViewBuilder private func kopfzeile(_ b: ForecastEvaluationOut) -> some View {
        let marke = Stufenmarke(wort: markenwort(b), aktiv: b.correctionActive)
        if schmal {
            VStack(alignment: .leading, spacing: 8) {
                Text("PV-Prognose gegen Ist · Korrekturfaktoren")
                    .font(Schrift.karte)
                    .foregroundStyle(Farbe.text1)
                marke
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Kicker(wort: "PV-Prognose gegen Ist · Korrekturfaktoren")
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
            Tagewahl(tage: $tage, moeglich: [3, 7, 14, 30])
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

/// Daten prüfen: wie lückenlos die Messwerte sind, was der Bestand wiegt, und die Tagesdiagnose.
///
/// **Die wichtigste Seite für das Vertrauen in alle anderen.** Jede Zahl dieser App steht auf
/// Minutenwerten; wo die fehlen, rechnet der Dienst mit weniger, als er zu haben scheint. Die
/// längste Lücke je Reihe sagt, wie schlimm es war.
struct DatenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Wie viele Tage die Waermekarte zeigt (`DataCheck.tsx:98`). Die Zahl steht im Kicker und
    /// in der Abfrage, darum nur einmal.
    private static let kartentage = 28

    @State private var abdeckung: CoverageOut?
    @State private var bestand: StorageReportOut?
    @State private var diagnose: String?
    @State private var fehler: ApiFehler?
    /// Die Minutenwerte des Tages - die Reihen, um die es auf dieser Seite geht.
    @State private var kurve = Pruefkurve()
    @State private var hatMinuten = false

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        // **Keine Spannenwahl** (`DataCheck.tsx:59-68`, `showPeriods={false}`): diese Seite
        // kennt nur Tage. Minutenwerte über eine Woche ergäben ein Bild, in dem man nichts
        // erkennt - und genau zum Erkennen ist sie da.
        Seite(zeitraum: Zeitraumleiste(spannen: [.tag])) {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade(z) } }
            }
            Karte(kicker: "Leistungen über den Tag") {
                if hatMinuten {
                    Pruefkurvenbild(kurve: kurve)
                } else {
                    Leer(satz: Pruefkurve.leersatz)
                }
            }
            Karte(
                kicker: "Quellen",
                beiwerk: AnyView(
                    Text("liefert gerade, was liefern soll?")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3))
            ) {
                Quellenkarte(zeilen: Quellenstand.zeilen(aus: haus.zustand?.system))
            }
            if let a = abdeckung {
                Karte(
                    kicker: "Kommen die Daten an? \(Self.kartentage) Tage",
                    beiwerk: AnyView(
                        Text("Farbe = Minuten je Stunde, 0 bis 60")
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3))
                ) {
                    Abdeckungskarte(reihen: Abdeckungsraster.baue(a), jetzt: haus.jetzt)
                }
            }
            if let d = diagnose, !d.isEmpty {
                // **Reiner Text, und das soll er bleiben.** Die Tagesdiagnose ist eine Tabelle
                // zum Lesen, keine Datenstruktur - der Dienst schickt sie darum ohne
                // JSON-Umschlag. Sie in Zeilen zu zerlegen und neu zu setzen hiesse, sie zu
                // interpretieren.
                Karte(kicker: "Stundenbilanz und auffällige Strecken") {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(d)
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                            .textSelection(.enabled)
                    }
                }
            }
            // **Der Bestand steht unten, nicht oben.** In der Vorlage gibt es ihn auf
            // dieser Seite gar nicht; er ist kein Fehler, nahm aber den Platz vor der
            // Hauptsache ein (`DataCheck.tsx:88-90`: der Augenblick vor der Karte, die Karte
            // vor der Bilanz).
            if let b = bestand {
                datenbestand(b)
            }
            // Die drei Absaetze der Vorlage (`DataCheck.tsx:119-147`) erklaeren, wie die
            // Bilder darueber zu lesen sind - sie fehlten ganz. Dann die Noten des Dienstes,
            // und dazwischen der Absatz zur leeren gegen die rote Zelle, der in der Vorlage
            // unmittelbar unter der Karte steht (`CoverageMap.tsx:146-152`).
            Methode(
                Pruefworte.methode.map(Optional.init) + [
                    abdeckung?.noteDe,
                    Abdeckungsraster.lesehilfe,
                    bestand?.noteDe,
                    Pruefworte.abdeckungssatz,
                ])
        }
        .task(id: z) { await lade(z) }
    }

    /// Was der Bestand wiegt - und wie lange Rohwerte bleiben.
    ///
    /// Die Aufbewahrungsfrist steht dabei, weil sie die Antwort auf die Frage ist, die sich an
    /// eine Lücke von vor drei Wochen anschliesst: nachsehen kann man dort nicht mehr.
    private func datenbestand(_ b: StorageReportOut) -> some View {
        Karte(kicker: "Datenbestand", titel: megabyte(b.totalBytes)) {
            VStack(alignment: .leading, spacing: 10) {
                Zeile(
                    wort: "Rohwerte bleiben", wert: "\(b.rawRetentionDays)", einheit: "Tage",
                    dazu: "danach nur noch Minutenmittel"
                )
                if !b.tables.isEmpty {
                    Tabelle(
                        zeilennamen: b.tables.map(\.name),
                        spalten: [
                            .init(name: "gesamt", zellen: b.tables.map { megabyte($0.totalBytes) }),
                            .init(name: "Daten", zellen: b.tables.map { megabyte($0.tableBytes) }),
                            .init(name: "Index", zellen: b.tables.map { megabyte($0.indexBytes) }),
                            .init(
                                name: "Zeilen",
                                zellen: b.tables.map { Formate.zahl(Double($0.rowsEstimate), stellen: 0) }
                            ),
                        ]
                    )
                }
            }
        }
    }

    private func megabyte(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 {
            return Formate.zahl(mb / 1024, stellen: 2) + Formate.schmalesLeerzeichen + "GB"
        }
        return Formate.zahl(mb, stellen: 1) + Formate.schmalesLeerzeichen + "MB"
    }

    private func lade(_ z: Zeitraum) async {
        async let minuten = try? haus.api.verlaufTag(z.anker)
        let historie = await minuten
        kurve = Pruefkurve.baue(tag: z.anker, historie: historie)
        hatMinuten = !kurve.leer

        // **Immer achtundzwanzig Tage, unabhaengig von der Spanne.** Die Karte ist das
        // Gegenstueck zur Frage „kommen die Daten an?", und die beantwortet ein einzelner Tag
        // nicht: ein Abriss, der jede Nacht wiederkommt, ist erst ueber Wochen ein Muster
        // (`DataCheck.tsx:98`, `days = 28`). Die Spannenwahl steht auf dieser Seite ohnehin
        // auf Tag.
        async let a = try? haus.api.abdeckung(anker: z.anker, tage: Self.kartentage)
        async let b = try? haus.api.datenbestand()
        // Die Tagesdiagnose gibt es nur für einen Tag - für eine Woche wäre sie sieben Tabellen.
        async let d = z.spanne == .tag ? try? haus.api.diagnose(tag: z.anker) : nil
        abdeckung = await a
        bestand = await b
        diagnose = await d
        fehler = abdeckung == nil ? .netz(Abdeckungsraster.nichtAbrufbar) : nil
    }
}

/// Haustür: wer wann aufgeschlossen hat.
struct HaustuerSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tage = 7
    @State private var protokoll: DoorLogOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            Tagewahl(tage: $tage, moeglich: [7, 30, 90])
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let p = protokoll {
                Kachelfeld(
                    kacheln: [
                        Kacheldaten("Öffnungen", String(p.entries.filter(\.granted).count)),
                        Kacheldaten(
                            "abgewiesen", String(p.entries.filter { !$0.granted }.count),
                            farbe: p.entries.contains { !$0.granted } ? Farbe.achtung : Farbe.text1
                        ),
                        Kacheldaten("Zeitraum", "\(p.days) Tage"),
                    ],
                    kicker: "Haustür"
                )
                Karte(kicker: "Protokoll") {
                    if p.entries.isEmpty {
                        Leer(satz: "In diesem Zeitraum wurde nicht aufgeschlossen.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(p.entries.enumerated()), id: \.offset) { i, e in
                                if i > 0 { Divider().overlay(Farbe.linie1) }
                                eintrag(e)
                            }
                        }
                    }
                }
                Methode([p.noteDe])
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task(id: tage) { await lade() }
    }

    private func eintrag(_ e: DoorEntryOut) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(e.granted ? Farbe.mist : Farbe.alarm)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.actor).font(Schrift.klein).foregroundStyle(Farbe.text1)
                Text([e.door, e.method, e.reason].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Formate.hhmm(iso: e.at)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                Text(e.outcome).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
        .padding(.vertical, 6)
    }

    private func lade() async {
        do {
            protokoll = try await haus.api.haustuer(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

/// Annahmen: die Einstellungen, mit denen der Fahrplan rechnet.
///
/// **Was hier steht, ist nicht gemessen, sondern gesetzt.** Pufferfassung, Verlust je Kelvin,
/// Pelletpreis, die angenommene COP-Kurve. Jede dieser Zahlen geht in jede Euro-Zahl der App
/// ein, und keine davon kommt aus einer Messung.
struct AnnahmenSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var einstellungen: HemsConfig?
    @State private var fehler: ApiFehler?
    /// Was in den Feldern steht, als Text - nicht als Zahl.
    ///
    /// **Warum Text und nicht `Double?`.** Wer „0," getippt hat, ist mitten im Tippen; eine
    /// Zahl daraus zu machen hiesse, die Null zu uebernehmen und den Rest zu verwerfen. Der
    /// Entwurf bleibt roh, bis er abgegeben wird (`Annahmenfelder.abgabe`).
    @State private var entwuerfe: [String: String] = [:]
    @State private var kennlinie = ""
    @State private var schickt = false
    @State private var uebernommen = false
    @State private var ansicht = "formular"

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let c = einstellungen {
                if ansicht == "formular" {
                    formular(c)
                } else {
                    werteliste(c)
                }
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task { await lade() }
    }

    // MARK: - Das Formular

    /// **Die Seite stellt, sie zeigt nicht nur.** Hier stand eine Leseliste roher Schlüssel
    /// („hw auto off block s 1200"), und darunter der Satz, geändert werde das im Dashboard.
    /// Die Vorlage (`settings/HeatSettings.tsx`) ist ein Formular: zwölf beschriftete Felder
    /// mit ihren Einheiten und Erklärsätzen, die Kennlinie als Zeile, ein Knopf. Jede Änderung
    /// wirkt sofort und rückwirkend - das steht als Satz darüber, nicht im Kleingedruckten.
    @ViewBuilder private func formular(_ c: HemsConfig) -> some View {
        Karte(kicker: Annahmenfelder.kicker, beiwerk: AnyView(umschalter)) {
            VStack(alignment: .leading, spacing: 18) {
                Text(Annahmenfelder.einleitung)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                spalten(c)
                kennlinienzeile(c)
                abgabezeile
            }
        }
        Methode(Annahmenfelder.methodensaetze.map(Optional.init))
    }

    /// Zwei Spalten an der Wand, eine am Telefon - wie die Vorlage.
    @ViewBuilder private func spalten(_ c: HemsConfig) -> some View {
        let gruppen = Annahmenfelder.spalten()
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                ForEach(Array(gruppen.enumerated()), id: \.offset) { _, felder in
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(felder) { feld in
                            feldzeile(feld, c)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 640)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(gruppen.flatMap { $0 }) { feld in
                    feldzeile(feld, c)
                }
            }
        }
    }

    private func feldzeile(_ feld: Annahmenfeld, _ c: HemsConfig) -> some View {
        let gebunden = Binding(
            get: { entwuerfe[feld.schluessel] ?? "" },
            set: { entwuerfe[feld.schluessel] = $0 }
        )
        let geaendert = Annahmenfelder.abweichend(
            feld, entwurf: gebunden.wrappedValue, gegen: c)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(feld.wort)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                TextField("", text: gebunden)
                    .font(Schrift.zahl)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(feld.darfNegativ ? .numbersAndPunctuation : .decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 92)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Farbe.flaeche2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                            .strokeBorder(
                                geaendert ? Farbe.amber : Farbe.linie2, lineWidth: 1)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                    .disabled(!haus.darfSchalten)
                Text(feld.einheit)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .frame(width: 42, alignment: .leading)
            }
            if let hinweis = feld.hinweis {
                Text(hinweis)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func kennlinienzeile(_ c: HemsConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: Annahmenfelder.kennlinienTitel)
            Text(Annahmenfelder.kennlinienErklaerung)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: $kennlinie)
                .font(Schrift.zahl)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Farbe.flaeche2)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(
                            kennlinie != Annahmenfelder.kurveZuText(c.heatDemand?.copCurve ?? [])
                                ? Farbe.amber : Farbe.linie2,
                            lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                .disabled(!haus.darfSchalten)
        }
    }

    @ViewBuilder private var abgabezeile: some View {
        HStack(spacing: 12) {
            Button {
                Task { await uebernimm() }
            } label: {
                Text(schickt ? Annahmenfelder.knopfLaeuft : Annahmenfelder.knopf)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.petrol)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Farbe.amber)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(schickt || !haus.darfSchalten)
            .opacity(haus.darfSchalten ? 1 : 0.4)
            if uebernommen {
                Text(Annahmenfelder.uebernommenSatz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Die rohen Werte bleiben erreichbar - sie sind mehr als die zwölf Annahmen, und wer eine
    /// Kennung sucht, findet sie nur dort.
    private var umschalter: some View {
        Ansichtswahl(
            ansichten: [
                Ansicht(weg: "formular", name: "Annahmen"),
                Ansicht(weg: "werte", name: "Alle Werte"),
            ],
            aktiv: Ansicht(weg: ansicht, name: "")
        ) { a in ansicht = a.weg }
    }

    @ViewBuilder private func werteliste(_ c: HemsConfig) -> some View {
        Karte(kicker: "Alle Werte", beiwerk: AnyView(umschalter)) {
            VStack(alignment: .leading, spacing: 14) {
                if let wp = c.heatPump {
                    abschnitt("Wärmepumpe", wp.alsZeilen)
                }
                if let puffer = c.buffer {
                    abschnitt("Pufferspeicher", puffer.alsZeilen)
                }
                if let waerme = c.heatDemand {
                    abschnitt("Wärmebedarf", waerme.alsZeilen)
                }
                if let tarif = c.tariff {
                    abschnitt("Tarif", tarif.alsZeilen)
                }
                if let ofen = c.stove {
                    abschnitt("Pelletofen", ofen.alsZeilen)
                }
                if let regelung = c.control {
                    abschnitt("Regelung", regelung.alsZeilen)
                }
            }
        }
    }

    private func abschnitt(_ wort: String, _ zeilen: [(wort: String, wert: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: wort)
            Werteliste(werte: zeilen)
        }
    }

    // MARK: - Laden und Abgeben

    private func lade() async {
        do {
            let c = try await haus.api.einstellungen()
            uebernimmAntwort(c)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(Annahmenfelder.ladefehler)
        }
    }

    private func uebernimm() async {
        guard !schickt else { return }
        schickt = true
        uebernommen = false
        defer { schickt = false }
        switch Annahmenfelder.abgabe(entwuerfe: entwuerfe, kennlinie: kennlinie) {
        case .kennlinieUnlesbar:
            fehler = ApiFehler(code: "kennlinie", meldung: Annahmenfelder.kennlinienFehler, status: 0)
        case .bereit(let patch):
            do {
                let c = try await haus.api.stelleWaerme(patch)
                uebernimmAntwort(c)
                fehler = nil
                uebernommen = true
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(Annahmenfelder.aenderungAbgelehnt)
            }
        }
    }

    /// Nach jedem Laden und nach jedem Übernehmen stehen die Felder auf dem, was der Dienst
    /// wirklich hat - nicht auf dem, was jemand getippt hatte.
    private func uebernimmAntwort(_ c: HemsConfig) {
        einstellungen = c
        entwuerfe = Annahmenfelder.entwuerfe(c)
        kennlinie = Annahmenfelder.kurveZuText(c.heatDemand?.copCurve ?? [])
    }
}

/// Eine Liste aus Schlüssel und Wert, wie sie aus einer Konfiguration kommt.
struct Werteliste: View {
    let werte: [(wort: String, wert: String)]

    var body: some View {
        if werte.isEmpty {
            Leer(satz: "Nichts gesetzt.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(werte.enumerated()), id: \.offset) { i, w in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    HStack(alignment: .firstTextBaseline) {
                        Text(w.wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                        Spacer(minLength: 8)
                        Text(w.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}

/// Eine Konfiguration als Zeilen.
///
/// **Warum über `Encodable` und nicht Feld für Feld.** Die Konfiguration hat neun Gruppen mit
/// zusammen gut siebzig Feldern, und sie wächst - jedes neue Feld müsste hier nachgetragen
/// werden, und wer es vergisst, merkt nichts. Über die Kodierung kommt alles, was da ist, und
/// zwar unter den Namen des Schemas: `cop_curve` statt `copCurve`. Das ist hier richtig, denn
/// wer diese Seite liest, sucht die Zahl aus `hems.yaml`.
protocol AlsZeilen {}

extension AlsZeilen where Self: Encodable {
    var alsZeilen: [(wort: String, wert: String)] {
        guard let roh = try? JSONEncoder().encode(self),
              let buch = try? JSONSerialization.jsonObject(with: roh) as? [String: Any]
        else { return [] }
        return buch.keys.sorted().compactMap { schluessel in
            guard let wert = buch[schluessel] else { return nil }
            let text = textVon(wert)
            guard !text.isEmpty else { return nil }
            return (wort: schluessel.replacingOccurrences(of: "_", with: " "), wert: text)
        }
    }

    private func textVon(_ wert: Any) -> String {
        switch wert {
        case let d as Double: return Formate.zahl(d, stellen: d == d.rounded() ? 0 : 2)
        case let i as Int: return String(i)
        case let b as Bool: return b ? "ja" : "nein"
        case let s as String: return s
        case let liste as [Any]:
            // Eine Stützpunktliste (die COP-Kurve) wird als Paare geschrieben.
            if let paare = liste as? [[Double]] {
                return paare.map { p in
                    p.count >= 2
                        ? "\(Formate.zahl(p[0], stellen: 0))→\(Formate.zahl(p[1], stellen: 2))"
                        : ""
                }
                .filter { !$0.isEmpty }
                .joined(separator: "  ")
            }
            return liste.map { textVon($0) }.joined(separator: ", ")
        case is NSNull: return ""
        default: return ""
        }
    }
}

extension HeatPumpConfig: AlsZeilen {}
extension BufferConfig: AlsZeilen {}
extension HeatDemandConfig: AlsZeilen {}
extension TariffConfig: AlsZeilen {}
extension StoveConfig: AlsZeilen {}
extension ControlConfig: AlsZeilen {}
extension BatteryConfig: AlsZeilen {}
extension BalanceConfig: AlsZeilen {}


/// Die Automatik für die thermische Masse.
///
/// **Was sie tut.** Sie hebt die Sollwerte der Räume vor einem Preistief an und senkt sie danach:
/// das Haus wird zum Speicher, und die Wärme, die abends gebraucht wird, ist mittags für
/// weniger Geld hineingegangen. Der Versatz ist klein - ein halbes Grad reicht, weil ein Haus
/// viel Masse hat.
///
/// **Sie ist aus, bis jemand sie einschaltet.** Das ist Absicht: eine Automatik, die ohne
/// Zutun an den Sollwerten der Wohnräume dreht, ist etwas, das man ausdrücklich gewollt haben
/// muss.
struct Automatikkarte: View {
    @Environment(Hauszustand.self) private var haus
    let automatik: RoomShiftOut
    let geaendert: (RoomShiftOut) -> Void

    @State private var laeuft = false

    var body: some View {
        Karte(kicker: "Automatik für die thermische Masse", titel: titel) {
            VStack(alignment: .leading, spacing: 10) {
                Text(automatik.reasonDe)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    Zeile(
                        wort: "Anhebung", wert: Formate.zahl(automatik.deltaK, stellen: 1),
                        einheit: "K", dazu: "vor dem Preistief"
                    )
                    Zeile(
                        wort: "Absenkung", wert: Formate.zahl(automatik.drawK, stellen: 1),
                        einheit: "K", dazu: "danach, zum Entladen"
                    )
                    Zeile(
                        wort: "Vorlauf", wert: Formate.zahl(automatik.leadH, stellen: 1),
                        einheit: "h", dazu: "so früh fängt sie an"
                    )
                    Zeile(
                        wort: "lohnt ab", wert: Formate.zahl(automatik.minSpreadCt, stellen: 1),
                        einheit: "ct", dazu: "Preisunterschied im Tag"
                    )
                    if let spanne = automatik.spreadCt {
                        Zeile(
                            wort: "heute", wert: Formate.zahl(spanne, stellen: 1), einheit: "ct",
                            farbe: spanne >= automatik.minSpreadCt ? Farbe.mist : Farbe.text3
                        )
                    }
                    if let von = automatik.windowStart, let bis = automatik.windowEnd {
                        Zeile(
                            wort: "Fenster",
                            wert: "\(Formate.hhmm(iso: von)) – \(Formate.hhmm(iso: bis))"
                        )
                    }
                    Zeile(
                        wort: "Versatz jetzt", wert: Formate.zahl(automatik.offsetK, stellen: 1),
                        einheit: "K",
                        farbe: abs(automatik.offsetK) > 0.05 ? Farbe.amber : Farbe.text1
                    )
                }
                // **`rooms` sind die Raumnummern, `active` sind die Raeume.** Hier stand
                // `rooms` - eine Reihe von `Int`. Die Liste zeigt Namen und geschriebene
                // Werte, also das, was die Automatik wirklich gestellt hat: `active`.
                if !automatik.active.isEmpty {
                    raumliste(automatik.active)
                }
                if !automatik.log.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zuletzt").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        ForEach(Array(automatik.log.prefix(5).enumerated()), id: \.offset) { _, e in
                            Text("\(Formate.hhmm(iso: e.at)) · \(e.textDe)")
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if haus.darfSchalten {
                    Button {
                        schalte(!automatik.enabled)
                    } label: {
                        Text(automatik.enabled ? "Automatik ausschalten" : "Automatik einschalten")
                            .font(Schrift.klein)
                            .foregroundStyle(automatik.enabled ? Farbe.text2 : Farbe.deep)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(automatik.enabled ? Farbe.flaeche3 : Farbe.amberWeich)
                            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(laeuft)
                    .opacity(laeuft ? 0.6 : 1)
                }
                if let hinweis = automatik.noteDe, !hinweis.isEmpty {
                    Text(hinweis)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var titel: String {
        if !automatik.enabled { return "aus" }
        // `active` ist keine Ja/Nein-Angabe, sondern die Reihe der Raeume, an denen gerade
        // geschrieben ist. „Greift gerade" heisst: diese Reihe ist nicht leer.
        if !automatik.active.isEmpty { return "greift gerade · \(automatik.phase.wort)" }
        return "an · \(automatik.phase.wort)"
    }

    /// Welche Räume mitmachen - und was die Automatik an ihnen wirklich geschrieben hat.
    ///
    /// Der geschriebene Sollwert steht neben dem Grundwert, weil sie auseinanderlaufen können:
    /// wer von Hand stellt, während die Automatik läuft, verschiebt den Grundwert, und der
    /// geschriebene folgt erst beim nächsten Schritt.
    private func raumliste(_ raeume: [RoomShiftRoomOut]) -> some View {
        Tabelle(
            zeilennamen: raeume.map(\.name),
            spalten: [
                .init(
                    name: "Grundwert",
                    zellen: raeume.map { Formate.celsius($0.baseSetpointC, stellen: 1) }
                ),
                .init(
                    name: "Versatz",
                    zellen: raeume.map { Formate.zahl($0.offsetK, stellen: 1) + " K" }
                ),
                .init(
                    name: "geschrieben",
                    zellen: raeume.map { Formate.celsius($0.writtenSetpointC, stellen: 1) }
                ),
                .init(
                    name: "wann",
                    zellen: raeume.map { Formate.hhmm(iso: $0.writtenAt) }
                ),
            ]
        )
    }

    private func schalte(_ an: Bool) {
        laeuft = true
        Task {
            if let neu = try? await haus.api.stelleRaumAutomatik(RoomShiftIn(enabled: an)) {
                geaendert(neu)
            }
            laeuft = false
        }
    }
}
