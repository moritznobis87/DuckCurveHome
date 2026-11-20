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

/// Fahrplan · Rückblick: ein Ortstag in Euro – versprochen, gehalten, wirklich.
///
/// **Drei Zahlen, die nicht dasselbe sind.** Was der erste Plan des Tages versprochen hat, was
/// der Plan am Ende des Tages gesagt hätte, und was wirklich bezahlt wurde. Die Lücke zwischen
/// der ersten und der dritten ist der Prognosefehler; die zwischen der zweiten und der dritten
/// ist das, was die Anlage nicht umgesetzt hat.
///
/// Diese Seite rechnet einen Vergleichslauf und braucht darum Sekunden.
struct NachbetrachtungSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tag: String = ""
    @State private var rueckblick: NachbetrachtungOut?
    @State private var fehler: ApiFehler?
    @State private var laedt = false

    var body: some View {
        Seite {
            tagwahl
            if laedt, rueckblick == nil {
                Karte {
                    Leer(
                        satz: "Wird gerechnet …",
                        dazu: "Der Vergleichslauf rechnet den ganzen Tag nach und braucht Sekunden."
                    )
                }
            }
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let r = rueckblick {
                Kachelfeld(kacheln: kennzahlen(r), kicker: Tag.lang(r.day))
                if let satz = r.satzDe, !satz.isEmpty {
                    Karte(kicker: "Der Tag in einem Satz") {
                        Text(satz)
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.text1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !r.abstaende.isEmpty {
                    // **Das ist die Karte, um die es auf dieser Seite geht.** Jeder Abstand
                    // vergleicht zwei Staende desselben Tages - was versprochen war und was
                    // daraus wurde - und sagt in Euro, was der Unterschied wert ist. Die
                    // Aufteilung in Menge, Zeit und Ofen sagt, *woran* es lag: eine falsche
                    // Menge ist ein Prognosefehler, eine falsche Zeit ein Planungsfehler.
                    Karte(kicker: "Versprochen, gehalten, wirklich") {
                        VStack(spacing: 0) {
                            ForEach(Array(r.abstaende.enumerated()), id: \.offset) { i, a in
                                if i > 0 { Divider().overlay(Farbe.linie1).padding(.vertical, 6) }
                                abstand(a)
                            }
                        }
                    }
                }
                // **`methodeDe` und `hinweiseDe` sind Reihen von Saetzen, keine Saetze.**
                // Standen sie in derselben Reihe wie die drei wahlfreien Einzelsaetze, wurde
                // daraus `[Any]`. Sie werden angehaengt; `Methode` wirft das Leere ohnehin weg.
                Methode(
                    r.methodeDe.map { Optional($0) }
                        + [
                            r.verschiebenDe,
                            r.laeuftNoch == true
                                ? "Der Tag läuft noch – die Zahlen sind vorläufig." : nil,
                            r.ersterPlanErstellt.map {
                                "Der erste Plan des Tages entstand \(Formate.hhmm(iso: $0))."
                            },
                        ]
                        + r.hinweiseDe.map { Optional($0) }
                )
            }
        }
        .task(id: tag) { await lade() }
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
            Spacer(minLength: 0)
        }
        .background(Farbe.flaeche2)
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private func kennzahlen(_ r: NachbetrachtungOut) -> [Kacheldaten] {
        [
            Kacheldaten(
                "Strom der Wärmepumpe", Formate.zahl(r.wpKw, stellen: 1), einheit: "kWh"
            ),
            Kacheldaten(
                "durch Verschieben gespart", Formate.euro(r.verschiebenEur),
                farbe: (r.verschiebenEur ?? 0) >= 0 ? Farbe.mist : Farbe.alarm
            ),
            Kacheldaten(
                "Standby", Formate.zahl(r.standbyKwh, stellen: 2), einheit: "kWh",
                dazu: r.standbyEur.map { Formate.euro($0) }
            ),
            Kacheldaten(
                "Einspeisevergütung", Formate.zahl(r.verguetungCt, stellen: 2), einheit: "ct/kWh"
            ),
            Kacheldaten(
                "verglichene Schritte", r.nVerglichen.map(String.init) ?? Formate.leer,
                dazu: r.schrittMin.map { "je \($0) Minuten" }
            ),
            Kacheldaten("Ofen beteiligt", (r.hatOfen ?? false) ? "ja" : "nein"),
        ]
    }

    private func abstand(_ a: Abstand) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(a.nameDe).font(Schrift.klein).foregroundStyle(Farbe.text1)
                Spacer(minLength: 8)
                if let eur = a.eur {
                    Text(Formate.euro(eur))
                        .font(Schrift.zahl)
                        .foregroundStyle(eur > 0.005 ? Farbe.achtung : eur < -0.005 ? Farbe.mist : Farbe.text2)
                }
            }
            Text("\(a.von) → \(a.nach)")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
            // Woran es lag. Nur was dasteht - ein Nullbetrag ist keine Erklaerung.
            let teile: [(String, Double?)] = [
                ("Menge", a.mengeEur), ("Zeitpunkt", a.zeitEur), ("Ofen", a.ofenEur),
            ]
            let vorhanden = teile.filter { ($0.1 ?? 0) != 0 }
            if !vorhanden.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(vorhanden.enumerated()), id: \.offset) { _, t in
                        Text("\(t.0) \(Formate.euro(t.1))")
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                    }
                }
            }
            if let satz = a.satzDe, !satz.isEmpty {
                Text(satz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lade() async {
        guard Tag.istTag(tag) else { return }
        laedt = true
        do {
            rueckblick = try await haus.api.nachbetrachtung(tag: tag)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
            rueckblick = nil
        } catch {
            fehler = .netz(error.localizedDescription)
            rueckblick = nil
        }
        laedt = false
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

    var body: some View {
        Seite {
            Tagewahl(tage: $tage, moeglich: [7, 30, 90])
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let w = wirkung {
                if let urteil = w.urteilDe, !urteil.isEmpty {
                    Karte(kicker: "Das Urteil", titel: w.urteil) {
                        Text(urteil)
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.text1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Kachelfeld(kacheln: kennzahlen(w), kicker: "\(w.days) Tage")
                Karte(kicker: "Abdeckung") {
                    VStack(spacing: 0) {
                        Zeile(wort: "Kontakt gemessen", wert: Formate.prozent(w.abdeckungKontakt))
                        Zeile(wort: "Leistung gemessen", wert: Formate.prozent(w.abdeckungLeistung))
                        Zeile(
                            wort: "Schwelle", wert: Formate.kw(w.schwelleKw), einheit: "kW",
                            dazu: "ab hier gilt die Pumpe als laufend"
                        )
                        if let vor = w.vorMin, let nach = w.nachMin {
                            Zeile(wort: "Fenster", wert: "\(vor) vor, \(nach) nach", einheit: "min")
                        }
                    }
                }
                Methode(w.methodeDe + w.hinweiseDe)
            } else if fehler == nil {
                Karte { Leer(satz: "Wird gerechnet …") }
            }
        }
        .task(id: tage) { await lade() }
    }

    private func kennzahlen(_ w: KontaktwirkungOut) -> [Kacheldaten] {
        [
            Kacheldaten(
                "Quote", Formate.prozent(w.quote),
                dazu: vertrauen(w),
                farbe: (w.quote ?? 0) > 0.6 ? Farbe.mist : Farbe.achtung
            ),
            Kacheldaten(
                "Ereignisse", w.nAuswertbar.map(String.init) ?? Formate.leer,
                dazu: w.n.map { "von \($0) insgesamt" }
            ),
            Kacheldaten(
                "gefolgt", w.gefolgt.map(String.init) ?? Formate.leer,
                dazu: "die Pumpe lief danach an"
            ),
            Kacheldaten(
                "lief schon", w.nLiefSchon.map(String.init) ?? Formate.leer,
                dazu: "zählt nicht: K1 kann nichts auslösen, was schon läuft"
            ),
            Kacheldaten(
                "Verzögerung", Formate.dauer(minuten: w.verzoegerungMedianMin.map { Int($0.rounded()) }),
                dazu: "Median bis zum Anlauf"
            ),
            Kacheldaten(
                "Nachlauf", Formate.dauer(minuten: w.nachlaufMedianMin.map { Int($0.rounded()) }),
                dazu: w.nachlaufN.map { "aus \($0) Fällen" }
            ),
        ]
    }

    /// Der Vertrauensbereich der Quote.
    ///
    /// **Ohne ihn ist die Quote keine Auskunft.** Eine Quote von 70 Prozent aus zehn Ereignissen
    /// und eine aus tausend sind zwei verschiedene Dinge, und nur das zweite ist eine Zahl.
    private func vertrauen(_ w: KontaktwirkungOut) -> String? {
        guard let lo = w.quoteLo, let hi = w.quoteHi else { return nil }
        return "\(Formate.prozent(lo)) bis \(Formate.prozent(hi))"
    }

    private func lade() async {
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
