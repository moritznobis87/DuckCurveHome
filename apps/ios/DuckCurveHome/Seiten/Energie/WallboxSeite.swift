import DuckCurveKit
import SwiftUI

/// Alles, was die Wallboxseite braucht – in einem Rutsch geholt.
///
/// **Fünf Antworten, nicht eine.** Die Seite holte bisher genau eine Spanne
/// (`StromSeite.swift:284-285` vor dem Umbau). Der Streifen „Wallbox im Überblick“ stellt Tag,
/// Woche, Monat und Jahr **zum selben Anker** nebeneinander (`EvReport.tsx:26,91-100`); das sind
/// vier weitere Abfragen derselben Antwort. Scheitert eine, fehlt ihre Spalte – die Seite bleibt
/// stehen.
struct Wallboxdaten: Sendable {
    let bericht: EvReportOut
    let jeSpanne: [Spanne: EvReportOut]
}

/// Wallbox: wann geladen wurde, woraus, und was es gekostet hat.
///
/// **Die Seite hatte kein einziges Bild.** Sie nannte sechs Summen und listete die
/// Ladevorgänge; wann und woraus geladen wurde, stand nirgends. „Geladene Energie nach
/// Herkunft“ ist in der Vorlage die einzige Stelle, die das zeigt (`EvReport.tsx:46-51`), und
/// die Batterie als Quelle kam in der App überhaupt nicht vor – `ev_battery_kwh` lag ungelesen
/// im Modell.
///
/// **Was gerechnet wird, steht im Kern** (``Wallbox``): die drei abgeleiteten Kennzahlen mit
/// ihren Schwellen, die Sortierung und Dauer der Ladevorgänge, die Rundung des Streifens und
/// die Zeile über die Datengrundlage. Hier bleibt die Anordnung.
struct WallboxSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Berichtsseite { z, api in
            // Die vier Spannen laufen los, bevor die eigentliche Antwort da ist: sie hängen
            // nur am Anker, nicht an der gewählten Spanne.
            async let spannen = holeSpannen(anker: z.anker, api: api)
            let bericht = try await api.energieWallbox(z.spanne.rawValue, anker: z.anker)
            return Wallboxdaten(bericht: bericht, jeSpanne: await spannen)
        } inhalt: { d in
            inhalt(d)
        }
    }

    /// Die vier Spannen zum selben Anker. `try?` je Spanne: eine fehlende Spalte ist besser als
    /// eine Seite, die an ihr scheitert (`useReport.ts:55-77` nimmt dafür `Promise.allSettled`).
    private func holeSpannen(anker: String, api: Api) async -> [Spanne: EvReportOut] {
        await withTaskGroup(of: (Spanne, EvReportOut?).self) { gruppe in
            for s in Spanne.allCases {
                gruppe.addTask {
                    (s, try? await api.energieWallbox(s.rawValue, anker: anker))
                }
            }
            var aus: [Spanne: EvReportOut] = [:]
            for await (s, b) in gruppe {
                if let b { aus[s] = b }
            }
            return aus
        }
    }

    @ViewBuilder private func inhalt(_ d: Wallboxdaten) -> some View {
        let b = d.bericht

        // **Ohne Kicker über dem Kachelfeld.** Hier stand „Wallbox“ – ein Wort, das der aktive
        // Reiter schon sagt. Die Vorlage setzt über dem KPI-Raster keinen und begründet das
        // beim Titel (`ReportShell.tsx:99-100`): „der aktive Reiter sagt, wo man ist.“
        Kachelfeld(kacheln: Wallbox.kacheln(b).map(Kacheldaten.init))

        Karte(kicker: "Geladene Energie nach Herkunft") {
            Balkenbild(stuecke: herkunft(b.summary), hoehe: 220)
        }

        Karte(kicker: "Ladevorgänge", beiwerk: AnyView(anzahl(b))) {
            ladevorgaenge(b)
        }

        Spannenstreifen(
            titel: "Wallbox im Überblick",
            zeilen: Wallbox.spannenzeilen(d.jeSpanne),
            anker: b.summary.anchor,
            jetzt: haus.jetzt
        )

        // Erst der Satz, der sagt, was ein Ladevorgang ist, dann der Hinweis des Dienstes -
        // in dieser Reihenfolge (`ReportShell.tsx:169-172`). Die Abdeckung steht in der
        // Kurzzeile und nicht im Rumpf: sie schränkt jede Zahl dieser Seite ein, und
        // zugeklappt wäre sie verschwiegen.
        Methode(
            [Wallbox.ladevorgangssatz, b.summary.meta.estimatedNoteDe],
            kurz: Wallbox.abdeckung(b.summary.meta)
        )
    }

    /// Woraus die Ladung kam, je Zeitabschnitt. Gestapelt, weil die drei sich zur geladenen
    /// Menge addieren (`EvReport.tsx:14-18`).
    ///
    /// Die drei Farben sind dieselben Hexwerte wie `C.pv`, `C.battery` und `C.grid`
    /// (`charts/palette.ts:35-37`); `Marken.swift:117-135` nennt dafür denselben Grund wie die
    /// Vorlage. Insbesondere ist es **nicht** `Farbe.wallbox` (0x5C8FA3) – der Wert wurde dort
    /// ausdrücklich verworfen, weil er dem Strompreis zu nah liegt.
    private func herkunft(_ s: EnergySummaryOut) -> [Balkenbild.Stueck] {
        [
            Balkenbild.Stueck(
                name: "aus PV", farbe: Farbe.pv,
                werte: s.buckets.map { ($0.label, $0.totals.evPvKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "aus Batterie", farbe: Farbe.diagrammSpeicher,
                werte: s.buckets.map { ($0.label, $0.totals.evBatteryKwh ?? 0) }
            ),
            Balkenbild.Stueck(
                name: "aus Netz", farbe: Farbe.diagrammNetz,
                werte: s.buckets.map { ($0.label, $0.totals.evGridKwh ?? 0) }
            ),
        ]
    }

    /// „4 im Zeitraum“ rechts im Kartenkopf (`EvReport.tsx:54`). Das Feld gab es, die Seite
    /// übergab es nicht.
    private func anzahl(_ b: EvReportOut) -> some View {
        Kartenhinweis(satz: Wallbox.kopfzeile(anzahl: b.sessions.count))
    }

    @ViewBuilder private func ladevorgaenge(_ b: EvReportOut) -> some View {
        let zeilen = Wallbox.vorgaenge(b)
        if zeilen.isEmpty {
            Leer(satz: "Keine Ladevorgänge im gewählten Zeitraum.")
        } else {
            Tabelle(zeilennamen: namen(zeilen), spalten: spalten(zeilen))
        }
    }

    /// Der Zeilenname ist der Beginn – am Telefon ohne Wochentag.
    ///
    /// Dort ist er die einzige Spalte, die immer dasteht (`Bericht.swift:206-244`), und muss
    /// neben der umgeschalteten Zahl Platz haben. Die Vorlage hat dasselbe Problem und löst es
    /// mit waagerechtem Rollen (`EvReport.tsx:56,74`), das es in einer Rollfläche, die schon
    /// senkrecht rollt, nicht gibt.
    private func namen(_ zeilen: [Wallbox.Vorgangszeile]) -> [String] {
        schmal ? zeilen.map(\.kurzerBeginn) : zeilen.map(\.beginn)
    }

    /// Die sechs Spalten hinter dem Beginn, in der Reihenfolge der Vorlage
    /// (`EvReport.tsx:60-66`).
    ///
    /// **Die Reihenfolge ist am Telefon eine Entscheidung und keine Geschmacksfrage**: dort
    /// steht die erste Spalte zuerst da (`Bericht.swift:213-227`, `gezeigt = 0`). Mit „Dauer“
    /// vorn beantwortet die Liste beim Aufschlagen „wie lange“ – die Frage, die die App bisher
    /// dem Leser überließ, weil sie nur Beginn und Ende nannte.
    ///
    /// Farbig sind zwei Spalten, wie in der Vorlage: „Sonnenanteil“ in Bernstein (`:78`) und
    /// „Bezahlt“ in Alarmrot, sobald überhaupt Geld geflossen ist, sonst gedämpft (`:80`).
    /// „Dauer“ und „Ø Leistung“ stehen in `--text-3`, weil sie einordnen und nicht die Sache
    /// sind (`:75,77`).
    private func spalten(_ zeilen: [Wallbox.Vorgangszeile]) -> [Tabelle.Spalte] {
        func gleich(_ farbe: Color) -> [Color?] { zeilen.map { _ -> Color? in farbe } }
        return [
            .init(name: "Dauer", zellen: zeilen.map(\.dauer), farben: gleich(Farbe.text3)),
            .init(name: "Energie", zellen: zeilen.map(\.energie)),
            .init(name: "Ø Leistung", zellen: zeilen.map(\.leistung), farben: gleich(Farbe.text3)),
            .init(
                name: "Sonnenanteil", zellen: zeilen.map(\.sonnenanteil),
                farben: gleich(Farbe.amber)
            ),
            .init(name: "Netz", zellen: zeilen.map(\.netz)),
            .init(
                name: "Bezahlt", zellen: zeilen.map(\.bezahlt),
                farben: zeilen.map { $0.bezahltAuffaellig ? Farbe.alarm : Farbe.text3 }
            ),
        ]
    }
}
