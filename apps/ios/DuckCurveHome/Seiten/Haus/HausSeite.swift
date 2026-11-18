import DuckCurveKit
import SwiftUI

/// Das Haus: die Raeume als Liste zum Stellen oder als Glasmodell.
///
/// **Ein Schalter in der Seite, kein Reiter.** `areas.ts` haelt das fest: es sind zwei Ansichten
/// derselben Sache, und die Liste ist die zum Arbeiten. Wer einen Sollwert stellen will, tippt
/// ihn in der Liste; wer wissen will, ob irgendwo ein Fenster offen ist, sieht das Modell an.
///
/// **Der Alarm steht oben und nicht im Modell.** Scharf oder nicht ist eine Auskunft, die man
/// lesen will, ohne das Haus zu drehen.
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

    private enum Ansichtswahlart: String { case liste, modell }

    var body: some View {
        Seite {
            kopf
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let alarm = haus.zustand?.alarm {
                Alarmkarte(alarm: alarm)
            }
            switch ansicht {
            case .liste:
                raumliste
            case .modell:
                modell
            }
        }
        .task { await lade() }
        // Die Raumtemperaturen kommen nicht im Ereignisstrom - sie werden nachgeholt, aber nicht
        // im Sekundentakt: ein Fussbodenheizkreis bewegt sich in Stunden, nicht in Sekunden.
        .task { await haltFrisch() }
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

    private var kopf: some View {
        HStack {
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "liste", name: "Liste"),
                    Ansicht(weg: "modell", name: "Modell"),
                ],
                aktiv: Ansicht(weg: ansicht.rawValue, name: "")
            ) { a in
                ansicht = Ansichtswahlart(rawValue: a.weg) ?? .liste
            }
            Spacer(minLength: 8)
            if let r = raeume, let at = Zeit.ausIso(r.at) {
                Text("Stand \(Formate.hhmm(at))")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
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

    // MARK: - Modell

    private var modell: some View {
        Karte {
            if let plan = hausplan?.plan {
                // **Ein Stockwerk nach dem anderen, wie im Dashboard** (`HouseReport.tsx:233`:
                // „Alle" und je ein Reiter fuer jedes Deck). Uebereinander liegen zwei
                // Grundrisse, deren Raeume auf fast dieselbe Stelle des Schirms fallen - und
                // dann liegen auch ihre Namen uebereinander. Wer ein Stockwerk waehlt, sieht
                // es allein und gross.
                if plan.decks.count > 1 {
                    Ansichtswahl(
                        ansichten: [Ansicht(weg: "", name: "Alle")]
                            + plan.decks.map { Ansicht(weg: $0.key, name: $0.name) },
                        aktiv: Ansicht(
                            weg: deck,
                            name: plan.decks.first { $0.key == deck }?.name ?? "Alle")
                    ) { a in
                        deck = a.weg
                        deckGewaehlt = true
                    }
                    .onAppear {
                        if !deckGewaehlt, schmal, let erstes = plan.decks.first {
                            deck = erstes.key
                        }
                    }
                }
                Glasmodell(
                    plan: plan,
                    raeume: Dictionary(
                        (raeume?.rooms ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }
                    ),
                    kontakte: Dictionary(
                        (hausplan?.contacts ?? []).map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a }
                    ),
                    // **`state` ist eine Zahl, kein Wort.** Hier stand ein Vergleich mit
                    // „armed_away" - das war geraten und falsch. Der Dienst schickt eine
                    // Stufe (`live_runtime.py`, `ALARM_WORT`): 0 unscharf, 1 zu Hause
                    // scharf, 2 unterwegs scharf, 3 schaltet, 4 ausgeloest. Das Dashboard
                    // liest es in `house/live.ts` genauso - alles ab 1 ist scharf.
                    alarmScharf: (haus.zustand?.alarm?.state ?? 0) >= 1,
                    sichtbaresDeck: deck.isEmpty ? nil : deck,
                    waermepumpeKw: haus.augenblick?.heatPumpPowerKw.belastbar,
                    wallboxKw: haus.augenblick?.evPowerKw.belastbar,
                    pufferSoc: haus.zustand?.buffer.soc
                )
                .frame(height: 460)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if let fehlertext = hausplan?.errorDe, !fehlertext.isEmpty {
                Leer(satz: "Der Hausplan ist nicht lesbar.", dazu: fehlertext)
            } else if hausplan?.present == false {
                Leer(
                    satz: "Für dieses Haus liegt kein Plan vor.",
                    dazu: "Der Plan kommt von der Brücke (haus.yaml)."
                )
            } else {
                Leer(satz: "Wird geholt …")
            }
        }
    }

    // MARK: - Laden

    private func lade() async {
        async let r = try? haus.api.raeume()
        async let p = try? haus.api.haus()
        async let t = try? haus.api.raeumeTag(Tag.heute(), schrittMin: 15)
        raeume = await r
        hausplan = await p
        tag = await t
        if raeume == nil, hausplan == nil {
            fehler = .netz("Räume und Hausplan nicht erreichbar.")
        } else {
            fehler = nil
        }
    }

    private func haltFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard !Task.isCancelled else { return }
            if let r = try? await haus.api.raeume() { raeume = r }
            if let p = try? await haus.api.haus() { hausplan = p }
            if let t = try? await haus.api.raeumeTag(Tag.heute(), schrittMin: 15) { tag = t }
        }
    }
}

/// Der Alarm: scharf oder nicht, und ob er scharf gestellt werden kann.
///
/// **Einen Weg zum Entschaerfen gibt es hier nicht, und das ist Absicht.** Wer das Haus
/// entschaerfen will, tut das an der Anlage selbst - eine App, die das kann, ist der Schluessel
/// unter der Fussmatte.
struct Alarmkarte: View {
    @Environment(Hauszustand.self) private var haus
    let alarm: AlarmOut

    @State private var laeuft = false
    @State private var rueckmeldung: String?

    var body: some View {
        Karte(kicker: "Alarm", titel: alarm.stateDe) {
            VStack(alignment: .leading, spacing: 10) {
                if let r = rueckmeldung {
                    Text(r).font(Schrift.winzig).foregroundStyle(Farbe.text2)
                }
                if alarm.canArm, haus.darfSchalten {
                    HStack(spacing: 10) {
                        knopf("Zu Hause scharf", .daheim)
                        knopf("Abwesend scharf", .fort)
                    }
                    Text("Entschärft wird an der Anlage, nicht hier.")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private func knopf(_ wort: String, _ art: Api.AlarmArt) -> some View {
        Button {
            schaerfe(art)
        } label: {
            Text(wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.deep)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Farbe.amberWeich)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(laeuft)
        .opacity(laeuft ? 0.6 : 1)
    }

    private func schaerfe(_ art: Api.AlarmArt) {
        laeuft = true
        Task {
            do {
                let a = try await haus.api.schaerfeAlarm(art)
                rueckmeldung = a.messageDe
            } catch let f as ApiFehler {
                rueckmeldung = f.rat
            } catch {
                rueckmeldung = error.localizedDescription
            }
            laeuft = false
        }
    }
}
