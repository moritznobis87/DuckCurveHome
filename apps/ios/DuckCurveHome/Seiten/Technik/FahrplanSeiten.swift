import Charts
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
                if let warnung = p.plannerWarnDe, !warnung.isEmpty {
                    Karte { Leer(satz: "Der Planer meldet etwas.", dazu: warnung) }
                }
                if !p.windows.isEmpty {
                    Karte(kicker: "Preisfenster") {
                        VStack(spacing: 0) {
                            ForEach(Array(p.windows.enumerated()), id: \.offset) { i, w in
                                if i > 0 { Divider().overlay(Farbe.linie1) }
                                fenster(w)
                            }
                        }
                    }
                }
                if !p.intervals.isEmpty {
                    Karte(kicker: "Der Plan") {
                        bild(p)
                    }
                    Karte(kicker: "Viertelstunde für Viertelstunde") {
                        plantabelle(p)
                    }
                }
                Methode([
                    p.plannerNoteDe,
                    "Planer: \(p.planner)\(p.plannerStatus.map { " · \($0)" } ?? "")",
                    "Erstellt \(Formate.hhmm(iso: p.createdAt)), Horizont bis \(Formate.hhmm(iso: p.horizonEnd)).",
                    p.hpActuation == true
                        ? "Die Freigabe wird geschaltet."
                        : "Die Freigabe wird nicht geschaltet – der Plan ist eine Empfehlung.",
                ])
            } else {
                Karte { Leer(satz: "Es liegt kein Fahrplan vor.") }
            }
        }
    }

    private func kopf(_ p: PlanOut) -> some View {
        Kachelfeld(
            kacheln: [
                Kacheldaten(
                    "aus der Sonne erwartet", Formate.zahl(p.pvForecastTodayKwh, stellen: 1),
                    einheit: "kWh", farbe: Farbe.pv
                ),
                Kacheldaten(
                    "geplante Läufe",
                    String(
                        Fahrplan.phasen(p, jetzt: haus.jetzt, bis: haus.jetzt.addingTimeInterval(24 * 3600)) {
                            $0.plannedHpState == .release
                        }.count
                    )
                ),
                Kacheldaten(
                    "nächstes Preistief",
                    p.nextCheapWindow.map { Formate.hhmm(iso: $0.start) } ?? Formate.leer,
                    dazu: p.nextCheapWindow.flatMap { w in
                        w.avgCtKwh.map { "im Mittel \(Formate.ct($0))" }
                    }
                ),
                Kacheldaten(
                    "Puffer, nutzbar", Formate.zahl(p.bufferCapacityKwh, stellen: 1), einheit: "kWh",
                    dazu: p.bufferMinKwh.map { "mindestens \(Formate.kwh($0))" }
                ),
            ],
            kicker: "Voraus"
        )
    }

    private func fenster(_ w: PriceWindowOut) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(w.kind == .negative ? Farbe.amber : w.kind == .cheap ? Farbe.mist : Farbe.alarm)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(w.labelDe).font(Schrift.klein).foregroundStyle(Farbe.text1)
                Text("\(Formate.hhmm(iso: w.start)) bis \(Formate.hhmm(iso: w.end))")
                    .font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 8)
            Text(Formate.ct(w.avgCtKwh)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
        }
        .padding(.vertical, 6)
    }

    /// Der Plan als Band: wann die Pumpe freigegeben ist, über dem Preis.
    private func bild(_ p: PlanOut) -> some View {
        let felder = p.intervals.compactMap { iv -> (stunde: Double, preis: Double?, frei: Bool)? in
            guard let t = Zeit.ausIso(iv.ts) else { return nil }
            let h = t.timeIntervalSince(haus.jetzt) / 3600
            guard h >= -0.5, h <= 24 else { return nil }
            return (h, iv.priceCtKwh, iv.plannedHpState == .release)
        }
        return VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(Array(felder.enumerated()), id: \.offset) { _, f in
                    if f.frei {
                        RectangleMark(
                            xStart: .value("von", f.stunde),
                            xEnd: .value("bis", f.stunde + 0.25),
                            yStart: .value("u", 0),
                            yEnd: .value("o", 1)
                        )
                        .foregroundStyle(Farbe.waermepumpe.opacity(0.55))
                    }
                }
                ForEach(Array(felder.enumerated()), id: \.offset) { _, f in
                    if let preis = f.preis {
                        LineMark(
                            x: .value("Stunde", f.stunde),
                            y: .value("Preis", preis / 40)
                        )
                        .foregroundStyle(Farbe.preis)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.stepEnd)
                    }
                }
                RuleMark(x: .value("jetzt", 0))
                    .foregroundStyle(Farbe.text2)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            .chartXScale(domain: 0...24)
            .chartYScale(domain: 0...1)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 0.0, through: 24, by: 4))) { w in
                    AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                    AxisValueLabel {
                        if let h = w.as(Double.self) {
                            Text("+\(Int(h)) h").font(Schrift.achse).foregroundStyle(Farbe.text3)
                        }
                    }
                }
            }
            .frame(height: 110)
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Rectangle().fill(Farbe.waermepumpe.opacity(0.55)).frame(width: 12, height: 8)
                    Text("Freigabe geplant").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                HStack(spacing: 5) {
                    Rectangle().fill(Farbe.preis).frame(width: 12, height: 2)
                    Text("Preis, 0 bis 40 ct").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private func plantabelle(_ p: PlanOut) -> some View {
        // Nur die naechsten acht Stunden: 96 Zeilen liest niemand, und was in 20 Stunden gilt,
        // wird vorher dreimal neu gerechnet.
        let kuenftig = p.intervals.compactMap { iv -> (PlanIntervalOut, Date)? in
            guard let t = Zeit.ausIso(iv.ts), t >= haus.jetzt.addingTimeInterval(-900),
                  t <= haus.jetzt.addingTimeInterval(8 * 3600)
            else { return nil }
            return (iv, t)
        }
        return Tabelle(
            zeilennamen: kuenftig.map { Formate.hhmm($0.1) },
            spalten: [
                .init(name: "Pumpe", zellen: kuenftig.map { zustandswort($0.0.plannedHpState) }),
                .init(name: "Preis", zellen: kuenftig.map { Formate.zahl($0.0.priceCtKwh, stellen: 1) }),
                .init(name: "Sonne", zellen: kuenftig.map { Formate.zahl($0.0.expectedPvKw, stellen: 1) }),
                .init(name: "Wärmebedarf", zellen: kuenftig.map { Formate.zahl($0.0.heatDemandKw, stellen: 1) }),
                .init(name: "Arbeitszahl", zellen: kuenftig.map { Formate.zahl($0.0.cop, stellen: 2) }),
                .init(name: "Puffer", zellen: kuenftig.map { Formate.zahl($0.0.bufferKwh, stellen: 1) }),
                .init(name: "Grund", zellen: kuenftig.map { $0.0.noteDe ?? grundwort($0.0.reasonCode) }),
            ]
        )
    }

    private func zustandswort(_ z: PlanIntervalOutPlannedHpStateWahl) -> String {
        switch z {
        case .release: return "frei"
        case .off: return "aus"
        case .free: return "offen"
        case .avoid: return "meiden"
        case .unbekannt: return "?"
        }
    }

    private func grundwort(_ code: String) -> String {
        ReasonCode(rawValue: code).map(Grundwort.text) ?? code.replacingOccurrences(of: "_", with: " ")
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
