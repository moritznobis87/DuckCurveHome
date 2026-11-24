import DuckCurveKit
import SwiftUI

/// Alles, was die Speicherseite braucht - in einem Rutsch geholt.
///
/// **Zwei Antworten, nicht sechs.** Die Seite holte bisher die Zahlen des Zeitraums und
/// den Prüfbericht; der Prüfbericht ist heraus (er zieht erst auf Knopfdruck, siehe
/// ``Speicherpruefkarte``), dafür kommen in der Tagesansicht die Minutenwerte für den
/// Ladezustandsverlauf dazu. Scheitert diese Nebenabfrage, fehlt ihr Bild; die Seite bleibt
/// stehen.
///
/// **Die vier Spannen des Überblicksstreifens stehen nicht mehr darin.** Sie hängen am Anker
/// und nicht am Zeitraum und sind ein eigener Zustand (``Spannenstand``, Vorlage
/// `BatteryReport.tsx:54`); lagen sie hier, wartete die Seite auf ihre langsamste Spalte.
struct Speicherdaten: Sendable {
    let zeitraum: Zeitraum
    let bericht: EnergySummaryOut
    /// Der Ladezustandsverlauf des Ankertags. Ausserhalb der Tagesansicht leer.
    let tagkurve: Speichertagkurve
    /// Die Gegenprobe aus dem Ladestand - nur dort, wo es Minutenwerte gibt.
    let ladestand: Ladestandsenergie?
}

/// Speicher: was hineinging, was herauskam, und was davon übrig blieb.
///
/// **Die Herkunft der Ladung ist die eigentliche Frage.** Ein Speicher, der nachts aus dem
/// Netz lädt, verschiebt Kosten, statt sie zu sparen - und ob er das tut, steht in
/// `grid_to_battery_dark_kwh`. Die Zahl hing bisher als Nebensatz unter „aus dem Netz
/// geladen“; in der Vorlage ist sie eine eigene Kachel in der Größe einer Kennzahl
/// (`BatteryReport.tsx:107-113`).
///
/// **Was gerechnet wird, steht im Kern:** die acht Kopfzahlen mit ihren vier Schwellen
/// (``Speicherbild``), der Ladezustandsverlauf (``Speichertagkurve``) und die Steuerung
/// (``Speichersteuerung``). Hier bleibt die Anordnung.
///
/// **Was diese Seite nicht mehr tut:** den Prüfbericht ungefragt mitholen. Er liest die
/// Minutenreihen des Zeitraums, bei einem Jahr über eine halbe Million Zeilen - *„das ist
/// nichts, was bei jedem Seitenaufruf nebenbei laufen soll“* (`SpeicherCheck.tsx:16`).
struct SpeicherSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    /// Der Überblicksstreifen, als eigener Zustand neben der Seite - der Grund steht an
    /// ``Spannenstand``.
    @State private var streifen = Spannenstand<EnergySummaryOut>()

    var body: some View {
        let jetzt = haus.jetzt
        let z = wegweiser.zeitraum(jetzt: jetzt)
        let stand = streifen.fuer(z.anker)
        Berichtsseite(
            hole: { zr, api in
                try await Self.hole(zr, api: api, jetzt: jetzt)
            },
            inhalt: { (d: Speicherdaten) in
                inhalt(d, anker: z.anker, streifen: stand)
            },
            // Der zweite Fehlerweg: fällt der Streifen ganz aus, steht sein Grund als Band
            // neben allem, was schon dasteht - und das Band der Seite bleibt unberührt.
            // Wann der Dienst das gerechnet hat: bei einem Treffer im Zwischenspeicher ist
            // das nicht jetzt, und dann steht es als Zeile ueber der Seite (``Berichtsstand``).
            gerechnetAm: { (d: Speicherdaten) in d.bericht.generatedAt },
            nebenfehler: stand.fehler,
            nebenfehlerErneut: { Task { await holeStreifen(anker: z.anker) } }
        )
        // **Am Anker, nicht am Zeitraum.** Ein Spannenwechsel ändert an den vier Spalten
        // desselben Ankertags nichts; hing der Streifen an `z`, holte jeder Wechsel vier
        // Abfragen umsonst. Am Ankerwechsel muss er neu laden, sonst zeigt er den falschen Tag.
        .task(id: z.anker) { await halteStreifenFrisch(anker: z.anker) }
    }

    // MARK: - Holen

    /// Den Streifen holen und im Fünf-Minuten-Takt nachholen, solange der Anker steht
    /// (`useReport.ts:70`).
    private func halteStreifenFrisch(anker: String) async {
        while !Task.isCancelled {
            await holeStreifen(anker: anker)
            try? await Task.sleep(for: Berichtstakt.nachladen)
        }
    }

    /// Die vier Spannen zum Anker, jede für sich: eine fehlende Spalte ist besser als eine
    /// Seite, die an ihr scheitert (`useReport.ts:55-77`).
    private func holeStreifen(anker: String) async {
        let api = haus.api
        let neu = await streifen.nachgeholt(zu: anker) { s in
            try await api.energieUebersicht(s.rawValue, anker: anker)
        }
        // Welcher Anker gilt, entscheidet erst das Schreiben - der Knopf „Noch einmal“ läuft
        // neben `.task(id:)` und bricht beim Blättern nicht ab
        // (``Spannenstand/uebernimm(_:zu:)``).
        streifen.uebernimm(neu, zu: wegweiser.zeitraum(jetzt: haus.jetzt).anker)
    }

    /// **Die Minutenwerte laufen neben der eigentlichen Abfrage.** Sie hängen an Spanne und
    /// Anker und fallen ausserhalb der Tagesansicht ganz weg; der Streifen hängt nur am Anker
    /// und steht darum nicht mehr hier, sondern neben der Seite.
    private static func hole(_ z: Zeitraum, api: Api, jetzt: Date) async throws -> Speicherdaten {
        async let minuten = minutenwerte(z, api: api, jetzt: jetzt)
        let bericht = try await api.energieUebersicht(z.spanne.rawValue, anker: z.anker)
        let raster = Pruefpunkt.raster(await minuten)
        return Speicherdaten(
            zeitraum: z,
            bericht: bericht,
            tagkurve: Speichertagkurve.baue(tag: z.anker, raster: raster),
            // Die Gegenprobe braucht die Kapazität; ohne sie ist ein Anteil keine
            // Kilowattstunde, und die Kachel zeigt stattdessen den Wirkungsgrad.
            ladestand: Speicherbild.ausLadestand(
                raster, kapazitaetKwh: bericht.meta.batteryCapacityKwh))
    }

    /// Die Minutenwerte des Ankertags - und nur seine.
    ///
    /// **Der laufende Tag wird anders geholt als ein vergangener** (`BatteryReport.tsx:62-66`):
    /// `range=today` liefert ihn bis jetzt, ein vergangener Tag braucht seine Ortsgrenzen.
    /// ``Api/verlaufTag(_:)`` rechnet die selbst.
    ///
    /// `try?` und kein `throw`: ein fehlender Verlauf ist eine fehlende Karte, keine
    /// gescheiterte Seite. Die Karte sagt dann selbst, dass es für diesen Tag keine
    /// Minutenwerte gibt.
    private static func minutenwerte(
        _ z: Zeitraum, api: Api, jetzt: Date
    ) async -> HistoryOut? {
        guard z.spanne == .tag else { return nil }
        if z.anker == Tag.heute(jetzt: jetzt) {
            return try? await api.verlauf(.heute)
        }
        return try? await api.verlaufTag(z.anker)
    }

    // MARK: - Die Seite

    @ViewBuilder private func inhalt(
        _ d: Speicherdaten, anker: String, streifen: Spannenstand<EnergySummaryOut>
    ) -> some View {
        let b = d.bericht

        // **Der Kicker trägt die Kapazität** („13,5 kWh · Nutzung und Ersparnis“,
        // `BatteryReport.tsx:103`). In der Vorlage steht er rechts in der Reiterzeile;
        // ``Reiterzeile`` hat dafür keinen Platz, und einen anzulegen wäre eine Entscheidung
        // über alle dreizehn Berichtsseiten. Über dem Kachelfeld steht er an derselben Stelle
        // der Lesereihenfolge - unmittelbar vor den Zahlen, die er einordnet.
        Kachelfeld(
            kacheln: Speicherbild.kacheln(b, ladestand: d.ladestand).map(Kacheldaten.init),
            kicker: Speicherbild.seitenkicker(b.meta),
            // Acht Kacheln: am iPad zwei Reihen zu vier, am Telefon eine führende und dann
            // zweispaltig. Die Vorlage setzt `cols={8}` und begründet im selben Atemzug, warum
            // daraus zwei Reihen werden: *„Lieber zwei ruhige Reihen als eine gedrängte“*
            // (`globals.css:103-106`, und zwar über genau diese Seite).
            spalten: schmal ? 2 : 4
        )

        Speichersteuerkarte()

        herkunftUndEntladung(b)
        tagUndUeberblick(d, anker: anker, streifen: streifen)

        Speicherpruefkarte(spanne: d.zeitraum.spanne, anker: b.anchor)

        // Erst der Satz, der „Geladen“ und „Ersparnis netto“ erklärt, dann der Hinweis des
        // Dienstes (`ReportShell.tsx:169-172`). Die Abdeckung steht in der Kurzzeile und nicht
        // im Rumpf: sie schränkt jede Zahl dieser Seite ein, und zugeklappt wäre sie
        // verschwiegen.
        Methode(
            [Speicherbild.methodensatz, b.meta.estimatedNoteDe],
            kurz: Wallbox.abdeckung(b.meta)
        )
    }

    // MARK: - Die zwei Balkenbilder

    /// **Nebeneinander, zu gleichen Teilen** (`BatteryReport.tsx:147`, `--cols: 1fr 1fr`). Am
    /// Telefon untereinander (`globals.css:350`).
    @ViewBuilder private func herkunftUndEntladung(_ b: EnergySummaryOut) -> some View {
        if schmal {
            herkunftskarte(b)
            entladekarte(b)
        } else {
            Spaltenreihe(anteile: [1, 1], abstand: 14) {
                herkunftskarte(b)
                entladekarte(b)
            }
        }
    }

    /// Woher die Ladung kam. Gestapelt, weil Sonne und Netz sich zur geladenen Menge addieren.
    ///
    /// **Die Farbe des Netzes ist das Violett des Netzbezugs** (`charts/palette.ts`, `grid`),
    /// seit dem 24.11.2026 in Fluss und Diagramm dasselbe. Nebelfarben darf sie hier nicht
    /// sein: das ist auf derselben Seite die Farbe der Entladung.
    private func herkunftskarte(_ b: EnergySummaryOut) -> some View {
        Karte(kicker: "Ladung nach Herkunft") {
            Balkenbild(
                stuecke: [
                    Balkenbild.Stueck(
                        name: "Ladung aus PV", farbe: Farbe.pv,
                        werte: b.buckets.map { ($0.label, $0.totals.pvToBatteryKwh ?? 0) }
                    ),
                    Balkenbild.Stueck(
                        name: "Ladung aus Netz", farbe: Farbe.diagrammNetz,
                        werte: b.buckets.map { ($0.label, $0.totals.gridToBatteryKwh ?? 0) }
                    ),
                ],
                hoehe: bildhoehe
            )
        }
    }

    /// Was ins Haus ging - eine Reihe, also ungestapelt (`BatteryReport.tsx:20,153`).
    private func entladekarte(_ b: EnergySummaryOut) -> some View {
        Karte(kicker: "Entladung ins Haus") {
            Balkenbild(
                stuecke: [
                    Balkenbild.Stueck(
                        name: "Entladung ins Haus", farbe: Farbe.diagrammSpeicher,
                        werte: b.buckets.map { ($0.label, $0.totals.batteryToHouseKwh ?? 0) }
                    )
                ],
                gestapelt: false,
                hoehe: bildhoehe
            )
        }
    }

    /// Die Vorlage setzt beide Karten auf feste 280 Punkte; abzüglich Kopfzeile, Polster und
    /// Legende bleiben dem Bild rund 200 (`BatteryReport.tsx:148,152`).
    private var bildhoehe: CGFloat { 200 }

    // MARK: - Tagesverlauf und Überblick

    /// **Zwei Drittel gegen ein Drittel** (`BatteryReport.tsx:157`, `--cols: 8fr 4fr`): links
    /// das Bild, rechts die Beilage. Am Telefon untereinander.
    @ViewBuilder private func tagUndUeberblick(
        _ d: Speicherdaten, anker: String, streifen: Spannenstand<EnergySummaryOut>
    ) -> some View {
        if schmal {
            tageskarte(d)
            ueberblick(d, anker: anker, streifen: streifen)
        } else {
            Spaltenreihe(anteile: [8, 4], abstand: 14) {
                tageskarte(d)
                ueberblick(d, anker: anker, streifen: streifen)
            }
        }
    }

    /// Der Ladezustand über den Tag - und zwei verschiedene Sätze, wo er fehlt.
    ///
    /// **„Keine Minutenwerte“ und „nicht die Tagesansicht“ sind nicht dasselbe.** Das eine ist
    /// eine Lücke in den Daten, das andere eine Eigenschaft der Ansicht; ein Satz für beides
    /// liesse den Leser raten, ob an seinem Speicher etwas fehlt (`BatteryReport.tsx:160`).
    private func tageskarte(_ d: Speicherdaten) -> some View {
        let tagesansicht = d.zeitraum.spanne == .tag
        return Karte(
            kicker: "Ladezustand über den Tag",
            beiwerk: Kartenhinweis.beiwerk(
                Speichertagkurve.kopfzeile(tagesansicht: tagesansicht))
        ) {
            if tagesansicht, !d.tagkurve.leer {
                Speichertagbild(kurve: d.tagkurve)
            } else {
                Leer(satz: Speichertagkurve.leersatz(tagesansicht: tagesansicht))
            }
        }
    }

    /// **Der Streifen steht, auch solange seine Zahlen fehlen**: ``Speicherbild`` zeichnet
    /// jede Spalte ohne Antwort als Strich, wie die Vorlage mit ihrem `strip`, das als `{}`
    /// anfängt (`BatteryReport.tsx:100`, `:165-170`).
    ///
    /// Der Anker kommt aus der Blätterleiste und nicht aus `d.bericht.anchor`: die Zahlen der
    /// Seite dürfen beim Blättern noch die des alten Tages sein, die vier Spaltenköpfe gehören
    /// zu dem Tag, für den der Streifen geholt wurde. Die Kapazität bleibt dagegen aus der
    /// gewählten Spanne - sie ist eine Eigenschaft des Geräts und nicht des Zeitraums.
    private func ueberblick(
        _ d: Speicherdaten, anker: String, streifen: Spannenstand<EnergySummaryOut>
    ) -> some View {
        Spannenstreifen(
            titel: "Speicher im Überblick",
            zeilen: Speicherbild.spannenzeilen(
                streifen.werte, kapazitaetKwh: d.bericht.meta.batteryCapacityKwh),
            anker: anker,
            jetzt: haus.jetzt
        )
    }
}
