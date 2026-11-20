import DuckCurveKit
import SwiftUI

/// Anlage · Ein Tag: die Wiedergabe eines vergangenen Ortstags.
///
/// **Gezeichnet wird dasselbe Schema wie auf der Seite Anlage** - dieselbe Ansicht, dieselben
/// Rohre, dasselbe wandernde Licht -, nur bekommt es statt des Augenblicks ein Bild aus der
/// Minutenreihe. Dass es dieselbe Ansicht ist, ist die ganze Idee: „ein zweites, vereinfachtes
/// Rückblickschema wäre in einer Woche ein anderes Haus“ (`Wiedergabe.tsx:19-21`). Hier stand
/// stattdessen eine Liste von zehn Zeilen, und die ließ alles weg, was die Seite ausmacht: die
/// vier Wasserkreise, das Glas des Puffers, die Rohrfarben als Temperatur, Netz und Batterie samt
/// Anteilen, den Ofen, das Warmwasser und drei der vier Pufferfühler.
///
/// **Drei Ansichten desselben Zeitpunkts, eine Uhr** (`Wiedergabe.tsx:23-26`). Oben das Schema:
/// was in diesem Augenblick floss. Darunter die Tagesuhr: wo im Tag dieser Augenblick liegt, als
/// Ring zum Anfassen. Daneben das Tagesband: derselbe Tag als Zeile, mit Achsen zum Ablesen. Alle
/// drei hängen an einem einzigen Index, und jede kann ihn verstellen.
///
/// **Die Uhr der Wiedergabe ist nicht die Wanduhr.** Das Schema bekommt die Zeit des Bildes, nicht
/// `haus.jetzt`. Sonst stünde daran „läuft seit 7 Stunden“, weil es die Laufzeit gegen jetzt
/// rechnet, während das Bild von gestern Mittag ist (`Wiedergabe.tsx:28-30`) - **das war schon
/// einmal der Fehler.**
///
/// **Alle Uhrzeiten dieser Seite in der Zeit des Hauses**, nicht des Geräts: sonst passte die
/// Mitte der Tagesuhr nicht zu ihrem eigenen Zifferblatt, denn das zählt vom Tagesbeginn des
/// Hauses (`Wiedergabe.tsx:45-52`). Das leisten `Formate.hhmm` und `Tag.lang` ohnehin; gerechnet
/// wird im Kern (`Wiedergabebild`), gezeichnet hier.
struct WiedergabeSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    /// Woher der Sprung kam: ein Tag und eine Stunde, auf die in der Jahreskarte getippt wurde.
    ///
    /// **Wahlfrei, und das ist der ganze Zweck.** Die Seite wird meist ohne Ziel aufgerufen und
    /// zeigt dann gestern von Mitternacht an. Kommt sie aus der Jahreskarte, trägt der Weg einen
    /// Tag und eine Stunde (`YearMap.tsx:72-84`), und dann beginnt sie dort: „Die Karte zeigt,
    /// *dass* an einem Dienstag im Februar etwas anders war; die Wiedergabe zeigt, was.“
    var ziel: Wiedergabeziel?

    @State private var tag: String = ""
    @State private var schritt: Int = Wiedergabeworte.schrittVorgabe
    @State private var tempo: Int = Wiedergabeworte.tempoVorgabe
    @State private var wiedergabe: AnlageReplayOut?
    @State private var bild: Wiedergabebild?
    @State private var stelle: Int = 0
    @State private var laeuftAb = false
    @State private var geholt = false
    @State private var fehler: ApiFehler?

    /// Ob die Wunschstunde aus dem Weg schon angewandt ist.
    ///
    /// **Sie gilt einmal je Seitenaufruf, nicht je Ladung** (`Wiedergabe.tsx:86-92`, dort eine
    /// Referenz). Ein Wechsel der Schrittweite holt denselben Tag neu; ohne diese Sperre würfe
    /// das den Spielkopf auf die Stunde aus dem Weg zurück, obwohl man gerade woanders stand.
    @State private var zielVerbraucht = false

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            // Der Seitenkicker der Vorlage (`page.tsx:10`). Am Telefon ist er dort ausgeblendet
            // (`AreaNav.tsx:96`, `hidden md:block`), also steht er hier auch nur breit.
            if !schmal {
                Kicker(wort: Wiedergabeworte.seitenkicker)
            }
            Karte(kicker: "Wiedergabe", beiwerk: kopfzahl) {
                tagwahl
                if let fehler {
                    Stoerung(fehler: fehler) { Task { await lade() } }
                }
                if let b = bild, let w = wiedergabe, b.anzahl > 0 {
                    buehne(w)
                    leiste(b)
                    tagesansicht(w, bild: b)
                } else if fehler == nil {
                    Text(zustandssatz)
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            zuDiesemTag
            methode
        }
        .task(id: ladeschluessel) { await lade() }
        .task(id: taktschluessel) { await spiele() }
        .onAppear { if tag.isEmpty { tag = ziel?.tag ?? Tag.plus(haus.heute, -1) } }
    }

    // MARK: - Die Kopfzeile

    /// „288 von 288 Bildern · 5-Minuten-Schritt“ (`Wiedergabe.tsx:197-201`).
    ///
    /// **Die Vollständigkeit des Tages stand nirgends.** Ohne diese Zahl sieht ein Tag, dem der
    /// Vormittag fehlt, aus wie ein ruhiger Vormittag.
    private var kopfzahl: AnyView? {
        guard let b = bild, b.erwartet > 0 || b.anzahl > 0 else { return nil }
        return AnyView(
            Text(b.kopfzahl)
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text3)
                .multilineTextAlignment(.trailing))
    }

    // MARK: - Tageswahl und Schrittweite

    /// „‹“, ein Datumsfeld, „›“, der lange Tag - und rechts die Schrittweite.
    @ViewBuilder private var tagwahl: some View {
        if schmal {
            VStack(alignment: .leading, spacing: 8) {
                tagzeile
                schrittwahl
            }
        } else {
            HStack(alignment: .center, spacing: 8) {
                tagzeile
                Spacer(minLength: 12)
                schrittwahl
            }
        }
    }

    private var tagzeile: some View {
        HStack(spacing: 8) {
            blaetterknopf("‹", um: -1)
            // **Ein direkter Sprung auf jeden Tag bis heute** (`Wiedergabe.tsx:209`,
            // `max={heute()}`). Vorher ließ sich nur Tag für Tag blättern, und ein Vorfall vom
            // letzten Februar war dreihundert Tipper weit weg.
            DatePicker("", selection: datumswahl, in: ...obergrenze, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Farbe.amber)
            blaetterknopf("›", um: 1)
            Text(Tag.lang(tag))
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Ein Tag zurück oder vor. Vorwärts endet heute: einen Tag, der nicht vorbei ist, gibt es
    /// nicht zum Nachsehen.
    private func blaetterknopf(_ zeichen: String, um tage: Int) -> some View {
        let moeglich = tage < 0 || tag < haus.heute
        return Button {
            tag = Tag.plus(tag, tage)
        } label: {
            Text(zeichen)
                .font(Schrift.karte)
                .frame(width: 30, height: 30)
                .foregroundStyle(moeglich ? Farbe.text2 : Farbe.text3)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(moeglich ? Farbe.linie1 : Farbe.linie2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!moeglich)
        .accessibilityLabel(tage < 0 ? "Tag zurück" : "Tag vor")
    }

    /// Die drei Auflösungen. **Ein Wechsel holt den Tag neu** (`Wiedergabe.tsx:99`): eine
    /// Minutenauflösung für einen einzelnen Vorfall gab es in der App nicht.
    private var schrittwahl: some View {
        HStack(spacing: 8) {
            Text(Wiedergabeworte.schrittWort)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
            ForEach(Wiedergabeworte.schritte, id: \.self) { s in
                wahlknopf("\(s) min", an: schritt == s) { schritt = s }
            }
        }
    }

    /// Eine Kapsel aus `.wg-wahl`: Mono, gesperrt, Rand - und gewählt Petrol auf Bernstein
    /// (`globals.css:621-622`).
    private func wahlknopf(_ wort: String, an: Bool, tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Text(wort)
                .font(Schrift.achse)
                .tracking(0.8)
                .foregroundStyle(an ? Farbe.petrol : Farbe.text3)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(an ? Farbe.amber : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(an ? Color.clear : Farbe.linie1, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Die Bühne

    /// Das Anlagenschema zu diesem Bild - auf derselben Bühne wie auf der Seite Anlage.
    ///
    /// **Die Zeit des Bildes, nicht die Wanduhr** - der Grund steht oben am Typ.
    ///
    /// **Die Bühne gehört zur Zeichnung und ist nicht die Karte.** Hier stand das Schema nackt
    /// in der Karte, also auf `flaeche1` beziehungsweise `flaeche2`. Die Vorlage legt es
    /// stattdessen in dieselbe Hülle wie auf der Seite Anlage (`Wiedergabe.tsx:233-236`) und
    /// begründet das: „Die Bühne selbst leiht sich die Rahmen der Anlage …, damit das Schema in
    /// beiden Ansichten in derselben Fassung sitzt“ (`globals.css:606-609`). Die Deckungen der
    /// Lichtpunkte, des Sonnenscheins und der Glaskacheln sind für den dunklen Verlauf der
    /// Bühne gerechnet, nicht für eine Karte - sonst stünde dieselbe Zeichnung auf den zwei
    /// Seiten in zwei Fassungen, und gerade das soll nicht sein.
    ///
    /// **Der Wischhinweis steht darum hier nicht mehr.** ``Anlagenbuehne`` setzt ihn am Telefon
    /// selbst und innerhalb der Hülle, wie `.anlage-buehne::after` (`handy.css:400`); eine
    /// zweite Zeile hier wäre derselbe Satz doppelt.
    @ViewBuilder private func buehne(_ w: AnlageReplayOut) -> some View {
        if let f = augenblick(w) {
            Anlagenbuehne {
                Anlagenbild(anlage: f, jetzt: Zeit.ausIso(f.at) ?? haus.jetzt)
            }
        }
    }

    // MARK: - Die Transportleiste

    private func leiste(_ b: Wiedergabebild) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                spielknopf
                Text(uhrzeit(b))
                    .font(Schrift.zahl)
                    .foregroundStyle(Farbe.text1)
                    .frame(minWidth: 52, alignment: .leading)
                schieber(b)
                Text("\(min(stelle, b.anzahl - 1) + 1)/\(b.anzahl)")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .frame(minWidth: 54, alignment: .trailing)
            }
            tempowahl
        }
    }

    private var spielknopf: some View {
        Button {
            laeuftAb.toggle()
        } label: {
            Text(laeuftAb ? "❚❚" : "▶")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.petrol)
                .frame(width: 38, height: 38)
                .background(Farbe.amber, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(laeuftAb ? "Anhalten" : "Abspielen")
    }

    /// Der Schieber - und **das Bedienelement für Vorleseprogramme**.
    ///
    /// Die Uhr ist ein zusätzlicher Griff, kein Ersatz: „ein Kreis, auf dem man zielen muss, ist
    /// keines“ (`Tagesuhr.tsx:31-33`). Darum trägt der Schieber die Uhrzeit als Wert, wie in der
    /// Vorlage `aria-valuetext` (`Wiedergabe.tsx:255`).
    private func schieber(_ b: Wiedergabebild) -> some View {
        Slider(
            value: schieberwert(b), in: 0...Double(max(1, b.anzahl - 1)), step: 1,
            onEditingChanged: { greift in
                // **Ein Sprung von Hand hält die Wiedergabe an**: „wer hinfasst, will hinsehen“
                // (`Wiedergabe.tsx:151`). Vorher zählte der Abspieler unabhängig vom Schieber
                // weiter, und was man eingestellt hatte, war eine Viertelsekunde später weg.
                if greift { laeuftAb = false }
            }
        )
        .tint(Farbe.amber)
        .frame(minWidth: 120)
        .accessibilityLabel(Wiedergabeworte.schieberName)
        .accessibilityValue(uhrzeit(b))
    }

    /// Bilder je Sekunde (`Wiedergabe.tsx:36`): „Bei 5-Minuten-Schritten ist 12 ein Tag in 24
    /// Sekunden.“
    private var tempowahl: some View {
        HStack(spacing: 8) {
            ForEach(Wiedergabeworte.tempi, id: \.self) { t in
                wahlknopf("\(t)×", an: tempo == t) { tempo = t }
                    .accessibilityLabel(Wiedergabeworte.tempoName(t))
            }
        }
    }

    // MARK: - Uhr und Band

    /// **Die Uhr hat eine feste Spalte; das Band nimmt den Rest** (`globals.css:626-629`). Unter
    /// 860 Punkten eine Spalte in der Reihenfolge Uhr, Legende, Band (`globals.css:630`) - die
    /// Legende gehört unter Uhr *und* Band, „denn beide sprechen dieselben Farben“.
    @ViewBuilder private func tagesansicht(_ w: AnlageReplayOut, bild b: Wiedergabebild)
        -> some View
    {
        if schmal {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer(minLength: 0)
                    uhr(w, bild: b)
                    Spacer(minLength: 0)
                }
                Tagesuhrlegende(bild: b)
                band(w, bild: b)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 28) {
                    uhr(w, bild: b).frame(width: 280)
                    band(w, bild: b)
                }
                Tagesuhrlegende(bild: b)
            }
        }
    }

    private func uhr(_ w: AnlageReplayOut, bild b: Wiedergabebild) -> some View {
        Tagesuhrbild(bild: b, daten: w, stelle: min(stelle, max(0, b.anzahl - 1))) { i in
            greifen(i, in: b)
        }
    }

    private func band(_ w: AnlageReplayOut, bild b: Wiedergabebild) -> some View {
        Tagesbandbild(bild: b, daten: w, stelle: min(stelle, max(0, b.anzahl - 1))) { i in
            greifen(i, in: b)
        }
    }

    /// Ein Griff in Uhr oder Band: Stelle setzen und anhalten.
    private func greifen(_ i: Int, in b: Wiedergabebild) {
        laeuftAb = false
        stelle = min(max(0, i), max(0, b.anzahl - 1))
    }

    // MARK: - Die Karte „Zu diesem Tag“

    /// **Offen und nicht zugeklappt**: „Was für diesen Tag gilt, bleibt offen stehen; zugeklappt
    /// wäre es verschwiegen“ (`Wiedergabe.tsx:285`). Die App steckte genau diese Sätze in die
    /// zugeklappte Methode.
    @ViewBuilder private var zuDiesemTag: some View {
        if let b = bild, b.anzahl > 0, !b.hinweise.isEmpty || !b.vollstaendig {
            Karte(kicker: Wiedergabeworte.karteTag) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(hinweissaetze(b), id: \.self) { satz in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").font(Schrift.klein).foregroundStyle(Farbe.text3)
                            Text(satz)
                                .font(Schrift.klein)
                                .foregroundStyle(Farbe.text2)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func hinweissaetze(_ b: Wiedergabebild) -> [String] {
        b.vollstaendig ? b.hinweise : b.hinweise + [Wiedergabeworte.luecke]
    }

    // MARK: - Die Methode

    @ViewBuilder private var methode: some View {
        if let b = bild, b.anzahl > 0 {
            Methode(
                Wiedergabeworte.methode(
                    uhrzeit: uhrzeit(b), schrittMin: b.schrittMin, tempo: tempo, anzahl: b.anzahl),
                kurz: Wiedergabeworte.methodeKurz, titel: Wiedergabeworte.methodeTitel)
        }
    }

    // MARK: - Zustände

    /// Was dasteht, solange kein Bild da ist.
    ///
    /// **Ein Tag ohne Bilder sagt es jetzt.** Vorher griff die Bedingung nicht, und es blieb
    /// dauerhaft „Wird geholt …“ stehen - ein Tag ohne Messung sah damit aus wie ein Netzproblem.
    private var zustandssatz: String {
        guard geholt, let b = bild else { return Wiedergabeworte.wirdGeholt }
        return b.anzahl == 0 ? Wiedergabeworte.ohneBilder(b.hinweise) : Wiedergabeworte.wirdGeholt
    }

    // MARK: - Hilfen

    private var obergrenze: Date {
        Tag.date(haus.heute) ?? haus.jetzt
    }

    private var datumswahl: Binding<Date> {
        Binding(
            get: { Tag.date(tag) ?? obergrenze },
            set: { neu in
                let gewaehlt = Tag.iso(neu)
                if gewaehlt != tag, Tag.istTag(gewaehlt) { tag = gewaehlt }
            })
    }

    private func schieberwert(_ b: Wiedergabebild) -> Binding<Double> {
        Binding(
            get: { Double(min(stelle, max(0, b.anzahl - 1))) },
            set: { stelle = min(max(0, Int($0.rounded())), max(0, b.anzahl - 1)) })
    }

    private func augenblick(_ w: AnlageReplayOut) -> AnlageOut? {
        guard stelle >= 0, stelle < w.frames.count else { return w.frames.first }
        return w.frames[stelle]
    }

    private func uhrzeit(_ b: Wiedergabebild) -> String {
        guard stelle >= 0, stelle < b.zeitpunkte.count else { return Formate.leer }
        return Formate.hhmm(b.zeitpunkte[stelle])
    }

    /// Der Tag **und** die Schrittweite holen neu (`Wiedergabe.tsx:124`).
    private var ladeschluessel: String { "\(tag)|\(schritt)" }
    /// Tempo und Lauf bestimmen den Takt; ein Wechsel setzt den Abspieler neu auf.
    private var taktschluessel: String { "\(laeuftAb)|\(tempo)" }

    // MARK: - Abspielen und Laden

    /// Der Abspieler. **Am Ende hält er an**, statt von vorn zu beginnen: „ein Tag, der unbemerkt
    /// in den nächsten Durchlauf rutscht, lässt einen zweimal dasselbe für zwei Tage halten“
    /// (`Wiedergabe.tsx:128-129`). Die App setzte `stelle = 0` und lief endlos im Kreis.
    private func spiele() async {
        guard laeuftAb else { return }
        while laeuftAb, !Task.isCancelled {
            try? await Task.sleep(for: Wiedergabeworte.takt(tempo: tempo))
            guard !Task.isCancelled, laeuftAb else { return }
            guard let b = bild, b.anzahl > 0 else { return }
            if stelle + 1 >= b.anzahl {
                stelle = b.anzahl - 1
                laeuftAb = false
                return
            }
            stelle += 1
        }
    }

    private func lade() async {
        guard Tag.istTag(tag) else { return }
        laeuftAb = false
        do {
            let w = try await haus.api.anlageWiedergabe(tag: tag, schrittMin: schritt)
            let b = Wiedergabebild.baue(w)
            wiedergabe = w
            bild = b
            stelle = anfangsstelle(w, bild: b)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
        geholt = true
    }

    /// Auf welchem Augenblick der Schieber steht, wenn ein Tag geladen ist.
    ///
    /// Null, außer die Seite wurde mit einem Ziel aufgerufen - dann auf der getippten Stunde
    /// (`YearMap.tsx:76-84`). Ohne das landete jeder Sprung aus der Jahreskarte um Mitternacht,
    /// und wer auf einen Dienstagnachmittag getippt hat, müsste ihn sich dort noch einmal suchen.
    ///
    /// Das Ziel gilt nur für seinen eigenen Tag und nur einmal: wer weiterblättert oder die
    /// Schrittweite wechselt, bleibt, wo er ist - eine Stunde, die aus einem anderen Tag oder aus
    /// einer vorigen Ladung stammt, ist dort keine Auskunft.
    ///
    /// Welches Bild zur Stunde gehört, sucht der Kern (`Wiedergabeziel.bildstelle`): `frames` ist
    /// nicht notwendig gleichmässig (`schemas.py:1832-1835`), und eine Rechnung, die ein dichtes
    /// Band annimmt, wäre hier auch nicht prüfbar.
    private func anfangsstelle(_ w: AnlageReplayOut, bild b: Wiedergabebild) -> Int {
        guard let ziel, !zielVerbraucht, ziel.tag == w.day, b.anzahl > 0 else { return 0 }
        zielVerbraucht = true
        return min(
            Wiedergabeziel.bildstelle(stunde: ziel.stunde, zeitpunkte: w.frames.map(\.at)),
            b.anzahl - 1)
    }
}
