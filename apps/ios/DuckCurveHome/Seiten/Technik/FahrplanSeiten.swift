import DuckCurveKit
import SwiftUI

/// Fahrplan · Voraus: was der Optimierer für die nächsten Stunden vorhat, Viertelstunde um
/// Viertelstunde.
///
/// **Die Begründung gehört zur Zeile.** Ein Plan, der sagt „23:15 bis 02:00 an", ohne zu sagen
/// warum, ist eine Ansage. Der Dienst liefert zu jeder Viertelstunde einen `reason_code` und oft
/// einen Satz; beide stehen hier.
struct FahrplanSeite: View {
    @Environment(Hauszustand.self) private var haus

    var body: some View {
        Seite {
            if let p = haus.plan {
                kopf(p)
                if !p.intervals.isEmpty {
                    Karte(
                        kicker: "Horizont",
                        titel: "\(Formate.tagUndUhr(iso: p.horizonStart, jetzt: haus.jetzt)) bis \(Formate.tagUndUhr(iso: p.horizonEnd, jetzt: haus.jetzt)) · \(p.planner)"
                    ) {
                        Fahrplanzeichnung(bild: Fahrplanbild.baue(p), plan: p, jetzt: haus.jetzt)
                        // **Die beiden Sätze des Planers stehen unter der Zeichnung**
                        // (`Fahrplan.tsx:642-643`), nicht in einer eigenen Karte davor und
                        // nicht in der zugeklappten Methode: die Notiz blass, die Warnung
                        // rot. Hier hatte die Warnung eine Karte für sich, mit dem erfundenen
                        // Vorsatz „Der Planer meldet etwas." und in Textfarbe - eine Warnung,
                        // die aussieht wie eine Auskunft, ist keine.
                        if let notiz = p.plannerNoteDe, !notiz.isEmpty {
                            Text(notiz)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let warnung = p.plannerWarnDe, !warnung.isEmpty {
                            Text(warnung)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.alarm)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Karte(
                        kicker: "Die Entscheidungen",
                        titel: Fahrplanworte.entscheidungenDazu
                    ) {
                        plantabelle(p)
                    }
                }
                Methode(
                    Fahrplanworte.methode.map(Optional.init) + [
                        "Planer: \(p.planner)\(p.plannerStatus.map { " · \($0)" } ?? "") · erstellt \(Formate.hhmm(iso: p.createdAt))",
                        p.hpActuation == true
                            ? "Die Freigabe wird geschaltet."
                            : "Die Freigabe wird nicht geschaltet – der Plan ist eine Empfehlung.",
                    ],
                    kurz: Fahrplanworte.methodeKurz,
                    titel: Fahrplanworte.methodeTitel
                )
            } else {
                Karte { Leer(satz: Fahrplanworte.ohnePlan) }
            }
        }
    }

    /// Die sieben Zahlen der Vorlage, gerechnet in ``Fahrplankacheln``.
    ///
    /// Vorher standen hier vier andere: erwartete Sonne, die *Zahl* der geplanten Laeufe, das
    /// naechste Preistief und die Puffergroesse. Drei Laeufe koennen zwanzig Minuten oder acht
    /// Stunden sein - die Stunden sind das, was man der gemessenen Laufzeit gegenueberstellt.
    private func kopf(_ p: PlanOut) -> some View {
        // **Vier Spalten, nicht zwei** (`Fahrplan.tsx:548`: `md:grid-cols-4 xl:grid-cols-7`).
        // Bei zwei Spalten stehen die sieben Zahlen am iPad in vier Zeilen und schieben die
        // Zeichnung, um die es auf der Seite geht, unter den Rand.
        Kachelfeld(
            kacheln: Fahrplankacheln.kacheln(p).map(Kacheldaten.init),
            spalten: 4
        )
    }

    /// Die Viertelstunden an den Preisenden – so wie es das Dashboard zeigt.
    ///
    /// Nicht alle 96 und nicht die naechsten 32: an einem ruhigen Tag steht in fast allen
    /// dasselbe, und auf dem Telefon stand das als zweiunddreissig Zeilen „aus" untereinander.
    private func plantabelle(_ p: PlanOut) -> some View {
        let zeilen = Planauswahl.entscheidungen(p.intervals)
        return VStack(alignment: .leading, spacing: 8) {
            if zeilen.isEmpty {
                Text("Noch keine Preise im Horizont.")
                    .font(Schrift.klein).foregroundStyle(Farbe.text3)
            } else {
                Tabelle(
                    // „03:15" allein steht im Horizont zweimal: er reicht ueber zwei Tage.
                    zeilennamen: zeilen.map { Formate.tagUndUhr($0.zeit, jetzt: haus.jetzt) },
                    spalten: [
                        .init(name: "Preis", zellen: zeilen.map { Formate.ct($0.preis) }),
                        .init(
                            name: "Bedarf",
                            zellen: zeilen.map { Formate.kwMitEinheit($0.bedarf) }),
                        // **Drei Spalten tragen Farbe** (`Fahrplan.tsx:715-721`): Puffer,
                        // Wärmepumpe und Ofen sagen dasselbe wie die Streifen darüber, und
                        // sie sollen es in derselben Sprache sagen.
                        .init(
                            name: "Puffer", zellen: zeilen.map { Formate.kwh($0.puffer) },
                            farben: zeilen.map { $0.puffer == nil ? nil : Farbe.puffer }),
                        .init(
                            name: "Wärmepumpe", zellen: zeilen.map(\.zustandswort),
                            farben: zeilen.map { rollenfarbe($0.zustandsrolle) }),
                        .init(
                            name: "Ofen", zellen: zeilen.map(\.ofenwort),
                            farben: zeilen.map { rollenfarbe($0.ofenrolle) }),
                        .init(name: "Warum", zellen: zeilen.map(\.warum)),
                    ]
                )
            }
        }
    }

    /// Dieselben Farben wie im Streifen darüber.
    private func rollenfarbe(_ r: Fahrplanbild.Rolle) -> Color? {
        switch r {
        case .angefordert, .wpGemessen: return Farbe.waermepumpe
        case .gemieden: return Farbe.alarm
        case .frei: return Farbe.text2
        case .aus: return Farbe.text3
        case .ofenAn: return Farbe.ofen
        case .ofenAus, .neutral: return nil
        case .pv: return Farbe.pv
        case .puffer: return Farbe.puffer
        case .heizen: return Farbe.haus
        case .warmwasser: return Farbe.warmwasser
        case .vorhersage: return Farbe.mist
        }
    }

}

/// Wirkung: was der Freigabekontakt K1 wirklich auslöst.
///
/// **Das ist die Ereignisstudie, und sie ist die ehrlichste Seite des Projekts.** K1 ist eine
/// Anforderung, keine Garantie: die Wärmepumpe hat ihren eigenen Regler und darf nein sagen. Die
/// Frage „folgt sie überhaupt?" ist damit eine empirische, und hier steht die Antwort samt
/// Vertrauensbereich.
struct WirkungSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tage = 30
    @State private var wirkung: KontaktwirkungOut?
    @State private var fehler: ApiFehler?
    @State private var laedtNeu = false

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            if let w = wirkung {
                let bild = Wirkungsbild.baue(w)
                urteilskarte(bild)
                Kachelfeld(
                    kacheln: Wirkungskacheln.kacheln(w).map(Kacheldaten.init),
                    kicker: bild.spanne ?? "\(w.days) Tage",
                    spalten: 3
                )
                if !bild.faecher.isEmpty {
                    Karte(
                        kicker: "Antwortfächer",
                        beiwerk: AnyView(
                            Text(
                                "\(w.nAuswertbar ?? 0) Anforderungen bei stehender Maschine, "
                                    + "am Beginn übereinandergelegt"
                            )
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                            .lineLimit(1)
                        )
                    ) {
                        Antwortfaecher(bild: bild)
                    }
                }
                if !bild.gruppen.isEmpty {
                    Karte(
                        kicker: "Jede Anforderung",
                        beiwerk: AnyView(
                            Text("sortiert nach Verzögerung")
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                        )
                    ) {
                        Ereignisraster(bild: bild)
                    }
                }
                // **Offen, nicht zugeklappt** (`Wirkung.tsx:240`): was eine Zahl an diesem
                // Zeitraum einschränkt, darf nicht hinter einem Deckel liegen.
                if !w.hinweiseDe.isEmpty {
                    Karte(kicker: "Zu diesem Zeitraum") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(w.hinweiseDe, id: \.self) { satz in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("·").font(Schrift.klein).foregroundStyle(Farbe.text3)
                                    Text(satz)
                                        .font(Schrift.klein)
                                        .foregroundStyle(Farbe.text2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                if !w.methodeDe.isEmpty {
                    Methode(
                        w.methodeDe.map(Optional.init),
                        kurz: "ein Zusammenhang in der Zeit, keine Ursache · Vergleich zur "
                            + "selben Tageszeit",
                        titel: "Was die Auswertung kann"
                    )
                }
            } else if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            } else {
                Karte { Leer(satz: "Die Anforderungen werden gesucht.") }
            }
        }
        .task(id: tage) { await lade() }
    }

    /// Die Urteilskarte: links der Satz, rechts der Quotenvergleich.
    ///
    /// **Der Satz und das Bild gehören nebeneinander** (`globals.css:648`: zwei Spalten,
    /// darunter 900 Punkten eine). Der Satz sagt, was herauskam; das Bild sagt, wie sicher das
    /// ist - und erst beides zusammen ist das Urteil. In der App stand nur der Satz, klein, in
    /// einer Karte ohne Bild.
    @ViewBuilder private func urteilskarte(_ bild: Wirkungsbild) -> some View {
        Karte(
            kicker: "Folgt die Wärmepumpe der Anforderung?",
            beiwerk: bild.spanne.map { s in
                AnyView(
                    Text(s).font(Schrift.zahlKlein).foregroundStyle(Farbe.text3))
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text("Zeitraum").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    // Die Vorlage zieht hier `.wg-wahl` (`Wirkung.tsx:149`), nicht
                    // `.kl-knopf`: die kleine Mono-Kapsel, die neben die beiden winzigen
                    // Beschriftungen dieser Zeile passt.
                    Tagewahl(tage: $tage, moeglich: [7, 30, 90], form: .wgWahl)
                    if laedtNeu {
                        Text("wird neu gerechnet")
                            .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                    Spacer(minLength: 0)
                }
                if let fehler {
                    Stoerung(fehler: fehler) { Task { await lade() } }
                }
                if schmal {
                    urteilssatz(bild)
                    Quotenbild(bild: bild, ringfarbe: Farbe.flaeche2)
                } else {
                    HStack(alignment: .center, spacing: 28) {
                        urteilssatz(bild)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Quotenbild(bild: bild, ringfarbe: Farbe.flaeche1)
                            .frame(maxWidth: 460)
                    }
                }
            }
        }
    }

    private func urteilssatz(_ bild: Wirkungsbild) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(wort: "Urteil · \(bild.urteilswort)")
            Text(bild.urteilssatz ?? "Noch kein Urteil.")
                .font(Schrift.sans(20, relativeTo: .title3))
                .foregroundStyle(Farbe.text1)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func lade() async {
        laedtNeu = wirkung != nil
        defer { laedtNeu = false }
        do {
            wirkung = try await haus.api.kontaktwirkung(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}
