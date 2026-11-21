import DuckCurveKit
import SwiftUI

/// Das Haus: die Raeume als Liste zum Stellen oder als Glasmodell - und neben beidem die
/// Konsole.
///
/// **Ein Schalter in der Seite, kein Reiter.** `areas.ts` haelt das fest: es sind zwei Ansichten
/// derselben Sache, und die Liste ist die zum Arbeiten. Wer einen Sollwert stellen will, tippt
/// ihn in der Liste; wer wissen will, ob irgendwo ein Fenster offen ist, sieht das Modell an.
///
/// **Ein Raster für beide Ansichten.** `globals.css:447` setzt `.haus-seite` als 216 Punkte und
/// den Rest, und **links steht in beiden Ansichten die Konsole** - rechts entweder die
/// Raumliste oder die Bühne. Die App hatte die Konsole nur in der breiten Modellansicht; am
/// Telefon und in jeder Liste fehlten damit Fenster, Puffer, Wärmepumpe und Heizkreise. Unter
/// 900 Punkten wird aus der Spalte eine quer rollende Reihe (`globals.css:543-549`).
///
/// **Der Alarm steht in der Konsole und nicht als eigene Karte.** Scharf oder nicht ist eine
/// Auskunft, die man neben den anderen vier liest, nicht über die ganze Breite.
struct HausSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @State private var ansicht: Ansichtswahlart = .liste
    /// Welches Deck das Modell zeigt. Leer heisst: alle uebereinander.
    ///
    /// **Am Telefon steht zuerst ein einzelnes Deck**, so wie im Dashboard unter 720 Punkten
    /// Breite: zwei Grundrisse uebereinander sind auf dieser Flaeche nicht zu lesen.
    @State private var deck: String = ""
    @State private var deckGewaehlt = false

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }
    @State private var raeume: RoomsLiveOut?
    @State private var hausplan: HouseOut?
    /// Die Tageszeitreihe aller Raeume – die Kurve und der Ventilstreifen jeder Kachel.
    ///
    /// **Ohne sie war die Liste eine Liste.** Bis zum 18.11.2026 holte diese Seite nur
    /// `/rooms` und `/house`; der Tagesverlauf lag die ganze Zeit unter `/rooms/history` und
    /// wurde nur von der Technikseite gelesen. Es fehlte kein Feld, es fehlte ein Aufruf.
    @State private var tag: RoomHistoryOut?
    @State private var fehler: ApiFehler?
    /// Die Automatik für die thermische Masse.
    ///
    /// **Sie gehört unter die Raumkacheln** (`HouseReport.tsx:283`, `RoomsReport.tsx:474`: die
    /// Karte hängt dort an `kacheln`). In der App stand sie als erste und grösste Karte auf
    /// der Heizkreiseseite und drängte die Wärmekarte, um die es dort geht, unter den Rand.
    @State private var automatik: RoomShiftOut?
    /// Welcher Block der Konsole aufgeklappt ist.
    @State private var klappe: Konsolenklappe?
    /// Welcher Raum im Modell scharf gestellt ist - Geschoss und Name, wie im Plan.
    @State private var fokus: Hauskonsolenfenster.Ort?

    private enum Ansichtswahlart: String { case liste, modell }

    var body: some View {
        gerippe
        .task { await lade() }
        // Die Raumtemperaturen kommen nicht im Ereignisstrom - sie werden nachgeholt, aber nicht
        // im Sekundentakt: ein Fussbodenheizkreis bewegt sich in Stunden, nicht in Sekunden.
        .task { await haltHausFrisch() }
        .task { await haltRaeumeFrisch() }
        .sheet(item: $klappe) { art in
            Hauskonsolenblatt(
                art: art, plan: hausplan?.plan, kontakte: hausplan?.contacts ?? [],
                raeume: raeume?.rooms ?? [], springe: springe)
        }
        .sheet(isPresented: raumOffen) {
            if case .raum(let id) = wegweiser.blatt,
               let r = raeume?.rooms.first(where: { $0.id == id })
            {
                Raumblatt(raum: r) { await lade() }
            }
        }
        .sheet(isPresented: protokollOffen) {
            if case .raumprotokoll(let id) = wegweiser.blatt {
                let r = raeume?.rooms.first { $0.id == id }
                Raumprotokollblatt(
                    raumId: id, name: r?.name ?? "Raum \(id)", etage: r?.floor ?? "")
            }
        }
    }

    private var protokollOffen: Binding<Bool> {
        Binding(
            get: {
                if case .raumprotokoll = wegweiser.blatt { return true }
                return false
            },
            set: { offen in
                if !offen, case .raumprotokoll = wegweiser.blatt { wegweiser.blatt = nil }
            }
        )
    }

    /// Nur die Raumblaetter - die uebrigen Blaetter haengen an der Wurzel.
    private var raumOffen: Binding<Bool> {
        Binding(
            get: {
                if case .raum = wegweiser.blatt { return true }
                return false
            },
            set: { offen in
                if !offen, case .raum = wegweiser.blatt { wegweiser.blatt = nil }
            }
        )
    }

    // MARK: - Das Gerippe

    /// **Am Telefon rollt die Seite, an der Wand füllt sie den Schirm.**
    ///
    /// Das Modell braucht die ganze Fläche und darf nicht in einem Rollbereich stehen; alles
    /// andere rollt. Die Konsole steht in beiden Fällen vor dem Inhalt - oben quer, links
    /// senkrecht.
    @ViewBuilder private var gerippe: some View {
        if schmal {
            Seite {
                kopf
                stoerung
                // Unter 900 Punkten wird aus der Spalte eine quer rollende Reihe
                // (`globals.css:546-548`).
                konsole(waagrecht: true)
                switch ansicht {
                case .liste: raumliste
                case .modell: modell
                }
                fussnote
            }
        } else if ansicht == .liste {
            Seite {
                kopf
                stoerung
                // **Auch neben der Liste steht die Konsole links**, in derselben Spalte von
                // 216 Punkten wie neben der Bühne (`HouseReport.tsx:266-285`).
                HStack(alignment: .top, spacing: 14) {
                    konsole(waagrecht: false)
                        .frame(width: 216)
                    VStack(alignment: .leading, spacing: 14) { raumliste }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            wandmodell
        }
    }

    @ViewBuilder private var stoerung: some View {
        if let fehler {
            Stoerung(fehler: fehler) { Task { await lade() } }
        }
    }

    /// Die Konsole - aber nur, wo es einen Hausplan gibt.
    ///
    /// **Die Liste braucht keinen Hausplan** (`HouseReport.tsx:350-352`): die Räume kommen aus
    /// der Heizungsregelung. Fehlt der Plan, steht sie allein da, ohne die Leiste mit Alarm und
    /// Fenstern - deren Kontakte stünden sonst als „keine Kontakte im Plan“ daneben.
    @ViewBuilder private func konsole(waagrecht: Bool) -> some View {
        if hausplan?.plan != nil {
            Hauskonsolenleiste(
                raeume: raeume?.rooms ?? [], plan: hausplan?.plan,
                kontakte: hausplan?.contacts ?? [], waagrecht: waagrecht, klappe: $klappe)
        }
    }

    /// `plan.note_de` steht unter der Modellansicht jeder Breite (`HouseReport.tsx:354`) -
    /// vorher nur in der Wandfassung.
    @ViewBuilder private var fussnote: some View {
        if ansicht == .modell, let satz = hausplan?.plan?.noteDe, !satz.isEmpty {
            Text(satz)
                .font(Schrift.sans(11))
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Das Modell an der Wand

    /// **Links die Leiste, rechts die Bühne - und beides füllt den Schirm.**
    ///
    /// `globals.css:447`: `.haus-seite` ist ein Raster aus 216 Punkten und dem Rest. Die App
    /// hatte stattdessen eine Alarmkarte über die ganze Breite und darunter eine Karte mit dem
    /// Modell darin, und sie rollte: das Modell bekam ein Drittel des Schirms, und die fünf
    /// Zahlen, die daneben gehören, standen nicht da.
    private var wandmodell: some View {
        VStack(alignment: .leading, spacing: 10) {
            werkzeuge
            stoerung
            HStack(alignment: .top, spacing: 14) {
                konsole(waagrecht: false)
                    .frame(width: 216)
                buehne
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            fussnote
        }
        .padding(.horizontal, 32)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Die Bühne: das Modell, randvoll, mit der Legende in ihrer unteren linken Ecke und dem
    /// Fokusfenster oben rechts.
    @ViewBuilder private var buehne: some View {
        if let plan = hausplan?.plan {
            ZStack(alignment: .bottomLeading) {
                glasmodell(plan)
                legende
                    .padding(.leading, 14)
                    .padding(.bottom, 12)
                if let f = fokus {
                    fokusfenster(f, plan: plan)
                        .frame(width: 320)
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                    .strokeBorder(Farbe.linie1, lineWidth: 1)
            )
        } else {
            Karte { modellhinweis }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Das Modell selbst - eine Stelle für beide Fassungen, damit die Werte nicht auseinander
    /// laufen.
    private func glasmodell(_ plan: HousePlan) -> some View {
        Glasmodell(
            plan: plan,
            raeume: Dictionary(
                (raeume?.rooms ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }
            ),
            kontakte: Dictionary(
                (hausplan?.contacts ?? []).map { ($0.key, $0) },
                uniquingKeysWith: { a, _ in a }
            ),
            // **`state` ist eine Zahl, kein Wort.** Hier stand ein Vergleich mit „armed_away“ -
            // das war geraten und falsch. Der Dienst schickt eine Stufe: alles ab 1 ist scharf.
            alarmScharf: Hauskonsolenfenster.stufe(haus.zustand?.alarm) != .unscharf
                && Hauskonsolenfenster.stufe(haus.zustand?.alarm) != .unbekannt,
            sichtbaresDeck: deck.isEmpty ? nil : deck,
            waermepumpeKw: haus.augenblick?.heatPumpPowerKw.belastbar,
            wallboxKw: haus.augenblick?.evPowerKw.belastbar,
            pufferSoc: haus.zustand?.buffer.soc,
            ofenLaeuft: Hauskonsolenfenster.ofenLaeuft(haus.zustand?.stove),
            fokus: fokus,
            // **Ein Tipp öffnet das Fokusfenster, nicht sofort das volle Blatt.** Die Vorlage
            // zeigt neben dem Modell Temperatur, Ziel, Heizkreis und die Kontakte dieses Raums
            // (`HouseReport.tsx:295-343`); das Blatt verdeckt das Modell und kennt die
            // Kontakte nicht. Der Weg zum Stellen steht im Fenster.
            tippeRaum: { id in zeigeFokus(raumId: id) }
        )
    }

    /// Die Werkzeuge der Seite: Ansicht, Geschoss - alle als Pillen, rechts oben.
    ///
    /// **Sie gehören in die Kopfzeile** (`HouseReport.tsx:219-248`, der `right`-Platz der
    /// Hülle). Das Gerippe der App hat dafür keinen Platz; hier stehen sie als eigene Zeile
    /// über der Bühne, in derselben Gestalt: gesperrte Großschrift, das Gewählte in Bernstein.
    ///
    /// **Die Kapselform steht nicht mehr hier.** Diese Datei hatte sie als eigene Funktion
    /// `pillen` nachgebaut, weil ``Ansichtswahl`` nur eine Form kannte; seit dem 21.11.2026
    /// ist sie dort ``Ansichtswahl/Form/hausGruppe`` und kommt aus `globals.css:474-476`.
    private var werkzeuge: some View {
        HStack(spacing: 6) {
            // **Der Kicker steht in der Hülle und damit in beiden Ansichten**
            // (`HouseReport.tsx:218-219`, `layout/AreaShell.tsx:13-29`). Er hing hier nur in
            // `kopf`, den die Wandfassung nicht baut - auf der Anzeige, die mit dem Modell
            // anfängt, stand also nirgends, woher der Plan kommt.
            herkunft
            Spacer(minLength: 0)
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "liste", name: "Liste"), Ansicht(weg: "modell", name: "Modell"),
                ],
                aktiv: Ansicht(weg: ansicht.rawValue, name: ""),
                form: .hausGruppe
            ) { a in ansicht = Ansichtswahlart(rawValue: a.weg) ?? .liste }
            if hausplan?.plan != nil {
                Ansichtswahl(
                    ansichten: deckwahl, aktiv: Ansicht(weg: deck, name: ""), form: .hausGruppe
                ) { a in
                    deck = a.weg
                    deckGewaehlt = true
                }
            }
        }
    }

    /// **Auch ein Haus mit einem Geschoss bekommt seine Gruppe**, dann mit der Aufschrift
    /// „Haus“ (`HouseReport.tsx:233-234`). Die App liess die Pillen bei einem Deck ganz weg -
    /// und damit stand an der Stelle, an der sonst das Geschoss steht, nichts.
    private var deckwahl: [Ansicht] {
        let decks = hausplan?.plan?.decks ?? []
        guard decks.count > 1 else { return [Ansicht(weg: "", name: "Haus")] }
        return [Ansicht(weg: "", name: "Alle")] + decks.map { Ansicht(weg: $0.key, name: $0.name) }
    }

    /// „KALT ▬▬ WARM · GELB: UNTER ZIEL · TIPPEN: RAUM“ (`HouseReport.tsx:288-294`).
    private var legende: some View {
        HStack(spacing: 8) {
            Kicker(wort: "kalt")
            LinearGradient(
                // **Die Skala der Böden, nicht die des Wassers.** Daneben steht ausgeschrieben,
                // warum man die beiden nicht verwechseln darf: ein Raum mit 21 °C ist warm, ein
                // Heizungsvorlauf mit 21 °C ist kalt.
                colors: Hausgeometrie.temperaturstopps.map { Color($0.farbe) },
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 96, height: 8)
            .clipShape(Capsule())
            Kicker(wort: "warm")
            Kicker(wort: "gelb: unter Ziel · tippen: Raum")
                .padding(.leading, 8)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Kopf

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 8) {
            if schmal {
                herkunft
                if let r = raeume, let at = Zeit.ausIso(r.at) {
                    Text("Stand \(Formate.hhmm(at))")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ansichtswahl
            } else {
                herkunft
                HStack {
                    ansichtswahl
                    Spacer(minLength: 8)
                    if let r = raeume, let at = Zeit.ausIso(r.at) {
                        Text("Stand \(Formate.hhmm(at))")
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
    }

    /// **Woher der Plan kommt, stand nirgends.** Die Vorlage setzt es als Kicker in das
    /// Reiterband: `plan.name || "Hausplan"` und dahinter `house.source_de`
    /// (`HouseReport.tsx:219`).
    @ViewBuilder private var herkunft: some View {
        if let h = hausplan {
            Kicker(wort: herkunftswort(h))
        }
    }

    private func herkunftswort(_ h: HouseOut) -> String {
        let eigen = h.plan?.name ?? ""
        let name = eigen.isEmpty ? "Hausplan" : eigen
        return h.sourceDe.isEmpty ? name : "\(name) · \(h.sourceDe)"
    }

    private var ansichtswahl: some View {
        Ansichtswahl(
            ansichten: [
                Ansicht(weg: "liste", name: "Liste"),
                Ansicht(weg: "modell", name: "Modell"),
            ],
            aktiv: Ansicht(weg: ansicht.rawValue, name: "")
        ) { a in
            ansicht = Ansichtswahlart(rawValue: a.weg) ?? .liste
        }
    }

    // MARK: - Liste

    private var raumliste: some View {
        Group {
            if let r = raeume, !r.rooms.isEmpty {
                Raumlegende()
                ForEach(Raumabweichung.nachEtage(r.rooms), id: \.etage) { gruppe in
                    VStack(alignment: .leading, spacing: 10) {
                        // Die Deckzeile: welches Geschoss, und was an ihm auffaellt.
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Kicker(wort: gruppe.etage)
                            Text(Raumabweichung.etagenText(gruppe.raeume))
                                .font(Schrift.zahlKlein)
                                .foregroundStyle(Farbe.text3)
                            Spacer(minLength: 0)
                        }
                        LazyVGrid(columns: spalten, spacing: 12) {
                            ForEach(gruppe.raeume, id: \.id) { raum in
                                Raumkachel(
                                    raum: raum,
                                    serie: serien[raum.id],
                                    proStunde: proStunde,
                                    gewesen: gewesen,
                                    schrittMin: tag?.stepMin ?? 15,
                                    // **Auch ein Gast darf die Kachel antippen.** Das Blatt zeigt
                                    // ihm die Zahlen und laesst den Knopf zum Stellen gesperrt; ihm
                                    // den Weg schon hier zu nehmen, hiesse, ihm das Lesen zu nehmen.
                                    stellen: { wegweiser.blatt = .raum(raum.id) },
                                    protokoll: { wegweiser.blatt = .raumprotokoll(raum.id) }
                                )
                            }
                        }
                    }
                }
                if let a = automatik {
                    Automatikkarte(automatik: a) { neu in automatik = neu }
                }
                if r.named == false {
                    Karte {
                        Leer(
                            satz: "Die Räume heißen nach ihrer Kennung in der Regelung.",
                            dazu: "Die Namensliste kommt als eigene Meldung der Brücke und steht nach ihrem nächsten Start zur Verfügung."
                        )
                    }
                }
            } else if fehler == nil {
                Karte {
                    Leer(
                        satz: "Keine Räume gemeldet.",
                        dazu: "Die Brücke liest die Einzelraumregelung, sobald in ihrer Konfiguration die Adresse des Controme-Servers steht."
                    )
                }
            }
        }
    }

    /// **Ein Gitter, nicht eine Spalte.** Am Telefon steht eine Kachel je Zeile; auf 1100
    /// Punkten Breite stuende sie allein mit einer leeren Mitte, und die Vorlage setzt dort ein
    /// Gitter mit Spalten von mindestens 260 Punkten (`globals.css:115`). Die Kachel ist zu
    /// dicht, um gedehnt zu werden.
    private var spalten: [GridItem] {
        schmal
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 290), spacing: 12)]
    }

    /// Die Tagesreihen nach Raumkennung.
    private var serien: [Int: RoomSeriesOut] {
        Dictionary((tag?.rooms ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Wie viele Fenster auf eine Stunde gehen.
    ///
    /// **Aus der Antwort, nicht aus der Anfrage.** Liefert der Dienst einem Tag eine andere
    /// Breite, soll der Streifen trotzdem Stunden zeigen.
    private var proStunde: Int {
        max(1, Int((60.0 / Double(tag?.stepMin ?? 15)).rounded()))
    }

    /// Wie viele Fenster des Tages schon gewesen sind.
    ///
    /// **Die Uhr des Hauses, nicht die des Geräts**: im Vorführbetrieb läuft sie im Zeitraffer,
    /// und ein halb schraffierter Tag wäre dort schlicht falsch.
    private var gewesen: Int? {
        guard let t = tag, let jetzt = raeume.flatMap({ Zeit.ausIso($0.at) }) else { return nil }
        guard let tagIso = t.start.split(separator: "T").first else { return nil }
        return Raumabweichung.gewesen(
            tag: String(tagIso), jetzt: jetzt, schrittMin: t.stepMin)
    }

    // MARK: - Modell am Telefon

    private var modell: some View {
        Group {
            if let plan = hausplan?.plan {
                Karte {
                    // **Ein Stockwerk nach dem anderen, wie im Dashboard**
                    // (`HouseReport.tsx:233`). Uebereinander liegen zwei Grundrisse, deren
                    // Raeume auf fast dieselbe Stelle des Schirms fallen - und dann liegen
                    // auch ihre Namen uebereinander.
                    // **Auch bei einem einzigen Deck steht die Gruppe da**, dann mit der
                    // Aufschrift „Haus“ (`HouseReport.tsx:230-234`: `.haus-werkzeuge` wird in
                    // jeder Breite gebaut, `globals.css:552` lässt sie am Telefon nur
                    // umbrechen). Die breite Fassung zeigte sie schon so; am Telefon fehlte
                    // sie genau dort, wo sie vorher schon fehlte.
                    Ansichtswahl(
                        ansichten: deckwahl,
                        aktiv: Ansicht(
                            weg: deck,
                            name: plan.decks.first { $0.key == deck }?.name ?? "Alle")
                    ) { a in
                        deck = a.weg
                        deckGewaehlt = true
                    }
                    .onAppear {
                        // Nur bei mehreren Decks: uebereinander sind zwei Grundrisse nicht zu
                        // lesen. Ein einzelnes Deck steht unter „Haus“ ohnehin allein da, und
                        // ein vorgewählter Schlüssel liesse die einzige Pille ungewählt
                        // aussehen.
                        if !deckGewaehlt, schmal, plan.decks.count > 1,
                           let erstes = plan.decks.first
                        {
                            deck = erstes.key
                        }
                    }
                    glasmodell(plan)
                        // **Ein Anteil des Schirms, keine feste Höhe.** Die Vorlage rechnet in
                        // Bildschirmhöhe (`globals.css:550`: 70dvh, `handy.css:393`: 58dvh);
                        // die App hatte 460 Punkte, und auf einem grossen Telefon blieb unter
                        // dem Bild ein leeres Drittel.
                        .containerRelativeFrame(.vertical) { hoehe, _ in hoehe * 0.58 }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .sheet(item: $fokus) { f in
                    fokusblatt(f, plan: plan)
                }
            } else {
                Karte { modellhinweis }
            }
        }
    }

    /// Was an der Stelle des Modells steht, solange es keines gibt.
    ///
    /// Eine Stelle für beide Fassungen: die Wandfassung zeigt denselben Satz in ihrer Bühne,
    /// und zwei Stellen mit denselben drei Sätzen laufen auseinander.
    @ViewBuilder private var modellhinweis: some View {
        if let h = hausplan {
            // **Beide Sätze in derselben Karte, untereinander** (`HouseReport.tsx:257-262`:
            // `house.error_de` und darunter der Hinweis auf die Beispieldatei). Hier standen
            // zwei sich ausschliessende Zweige, und der zweite kam nie dran: im Fall „kein
            // Plan“ setzt der Dienst `present=False` **und** `error_de`
            // (`live_runtime.py:1596-1606`). Gelesen hat man deshalb immer nur „nicht
            // lesbar“ - die falsche Auskunft, wenn bloss noch keiner gemeldet wurde.
            Leer(satz: planhinweis(h), dazu: planabhilfe)
        } else {
            Leer(satz: "Wird geholt …")
        }
    }

    /// Was der Dienst zum fehlenden Plan meldet - und wenn er nichts meldet, der eigene Satz.
    private func planhinweis(_ h: HouseOut) -> String {
        let fehler = h.errorDe ?? ""
        return fehler.isEmpty ? "Für dieses Haus liegt kein Plan vor." : fehler
    }

    private var planabhilfe: String {
        "Die Vorlage liegt im Repository unter config/haus.example.yaml; sie beschreibt jede "
            + "Art von Eintrag. Die Brücke liest die Datei alle 30 Sekunden neu, ein Neustart "
            + "ist nicht nötig."
    }

    // MARK: - Der Fokus am Modell

    /// Den Raum hinter einer Kennung scharf stellen.
    ///
    /// Kennt der Plan die Kennung nicht, bleibt der bisherige Weg: das volle Blatt. Ein Tipp,
    /// der nichts tut, wäre schlimmer als ein Blatt, das zu viel zeigt.
    private func zeigeFokus(raumId: Int) {
        if let ort = Hauskonsolenfenster.raumOrt(plan: hausplan?.plan, raumId: raumId) {
            fokus = ort
        } else {
            wegweiser.blatt = .raum(raumId)
        }
    }

    /// Aus einer Zeile der Konsole in den Raum im Modell (`HouseReport.tsx:176-191`).
    ///
    /// Steht die Liste vorn, wechselt die Seite in die Modellansicht; sonst wird nötigenfalls
    /// das Geschoss gewechselt. Danach schliesst das Blatt der Konsole.
    private func springe(_ ort: Hauskonsolenfenster.Ort) {
        ansicht = .modell
        if !deck.isEmpty, deck != ort.deck { deck = ort.deck }
        if schmal { deck = ort.deck }
        deckGewaehlt = true
        fokus = ort
        klappe = nil
    }

    /// Das Fokusfenster: gross die Temperatur, das Ziel, der Heizkreis, die Kontakte des Raums.
    ///
    /// **Es ersetzt nicht das Stellblatt, es führt dorthin.** Eine zweite Stellmechanik wäre
    /// eine zweite Wahrheit (`HouseReport.tsx:356-362`: die Vorlage öffnet dafür dasselbe
    /// Fenster wie die Raumseite).
    private func fokusfenster(_ ort: Hauskonsolenfenster.Ort, plan: HousePlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            fokuskopf(ort, plan: plan)
            fokuswerte(ort, plan: plan)
            fokuskontakte(ort, plan: plan)
            if let id = raumKennung(ort, plan: plan) {
                Button { wegweiser.blatt = .raum(id) } label: {
                    Text("Sollwert stellen")
                        .font(Schrift.mono(11))
                        .tracking(1.3)
                        .foregroundStyle(Farbe.petrol)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Farbe.amber, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Farbe.grund.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Farbe.linie2, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }

    /// Am Telefon wird aus dem Fenster ein Blatt von unten (`globals.css:551`) - dieselbe
    /// Entscheidung wie bei den Konsolenfenstern.
    private func fokusblatt(_ ort: Hauskonsolenfenster.Ort, plan: HousePlan) -> some View {
        ScrollView {
            fokusfenster(ort, plan: plan)
                .padding(16)
        }
        .seitengrund()
        .presentationDetents([.medium])
    }

    private func fokuskopf(_ ort: Hauskonsolenfenster.Ort, plan: HousePlan) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Kicker(wort: plan.decks.first { $0.key == ort.deck }?.name ?? "")
                Text(ort.raum).font(Schrift.sans(18)).fontWeight(.semibold)
                    .foregroundStyle(Farbe.text1)
            }
            Spacer(minLength: 8)
            Button { fokus = nil } label: {
                Text("SCHLIESSEN")
                    .font(Schrift.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(Farbe.text2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private func fokuswerte(
        _ ort: Hauskonsolenfenster.Ort, plan: HousePlan
    ) -> some View {
        if let r = fokusraum(ort, plan: plan) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(r.tempC.map { Formate.zahl($0, stellen: 1) } ?? Formate.leer)
                    .font(Schrift.mono(44, relativeTo: .largeTitle))
                    .fontWeight(.medium)
                    .foregroundStyle(Farbe.text1)
                Text("°C gemessen").font(Schrift.mono(14)).foregroundStyle(Farbe.text3)
            }
            fokuszeile("Ziel", wert: Formate.celsius(r.targetC ?? r.setpointC, stellen: 1))
            fokuszeile("Heizkreis", wert: Formate.prozent(r.valve))
        } else {
            Text("Kein Thermostat in diesem Raum.")
                .font(Schrift.sans(13))
                .foregroundStyle(Farbe.text3)
        }
    }

    private func fokuszeile(_ wort: String, wert: String) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Farbe.linie1).frame(height: 1)
            HStack {
                Text(wort.uppercased())
                    .font(Schrift.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(Farbe.text3)
                Spacer(minLength: 10)
                Text(wert).font(Schrift.mono(15)).foregroundStyle(Farbe.text1)
            }
            .padding(.top, 8)
        }
    }

    /// Die Kontakte **dieses** Raums (`HouseReport.tsx:322-337`). Das Raumblatt der App kennt
    /// sie nicht - und „steht hier ein Fenster offen“ ist die Frage, wegen der man im Modell
    /// auf einen Raum tippt.
    private func fokuskontakte(
        _ ort: Hauskonsolenfenster.Ort, plan: HousePlan
    ) -> some View {
        let zeilen = Hauskonsolenfenster.kontaktzeilen(
            plan: plan, kontakte: hausplan?.contacts ?? []
        ).filter { $0.ort?.deck == ort.deck && $0.raum == ort.raum }
        return VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Farbe.linie1).frame(height: 1)
            Text("FENSTER UND TÜREN")
                .font(Schrift.mono(10))
                .tracking(1.6)
                .foregroundStyle(Farbe.text3)
                .padding(.top, 8)
            if zeilen.isEmpty {
                Text("keine Kontakte in diesem Raum")
                    .font(Schrift.sans(12.5))
                    .foregroundStyle(Farbe.text3)
            }
            ForEach(zeilen) { z in
                HStack {
                    Text(z.name).font(Schrift.sans(12.5)).foregroundStyle(Farbe.text2)
                    Spacer(minLength: 10)
                    Text(z.wort.uppercased())
                        .font(Schrift.mono(11))
                        .tracking(0.9)
                        .foregroundStyle(z.offen == true ? Farbe.amber : Farbe.text3)
                }
            }
        }
    }

    private func fokusraum(_ ort: Hauskonsolenfenster.Ort, plan: HousePlan) -> RoomLiveOut? {
        guard let id = raumKennung(ort, plan: plan) else { return nil }
        return raeume?.rooms.first { $0.id == id }
    }

    private func raumKennung(_ ort: Hauskonsolenfenster.Ort, plan: HousePlan) -> Int? {
        plan.decks.first { $0.key == ort.deck }?
            .rooms.first { $0.name == ort.raum && $0.partOf == nil }?
            .roomId
    }

    // MARK: - Laden

    private func lade() async {
        async let r = try? haus.api.raeume()
        async let p = try? haus.api.haus()
        async let t = try? haus.api.raeumeTag(Tag.heute(), schrittMin: 15)
        async let a = try? haus.api.raumAutomatik()
        raeume = await r
        hausplan = await p
        tag = await t
        automatik = await a
        if raeume == nil, hausplan == nil {
            fehler = .netz("Räume und Hausplan nicht erreichbar.")
        } else {
            fehler = nil
        }
    }

    /// **Der Hausplan alle zehn Sekunden** (`HouseReport.tsx:53`, `:115-124`). An ihm hängen die
    /// Kontakte, und ein offenes Fenster erschien bisher bis zu einer Minute später: die App
    /// holte alle drei Abfragen in einer Schleife im Minutentakt.
    private func haltHausFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            if let p = try? await haus.api.haus() { hausplan = p }
        }
    }

    /// **Die Räume alle dreissig Sekunden** (`HouseReport.tsx:54`, Begründung im Kopfkommentar:
    /// „alle 30 Sekunden, haeufiger fragt Controme nicht“).
    private func haltRaeumeFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            if let r = try? await haus.api.raeume() { raeume = r }
            if let t = try? await haus.api.raeumeTag(Tag.heute(), schrittMin: 15) { tag = t }
        }
    }
}
