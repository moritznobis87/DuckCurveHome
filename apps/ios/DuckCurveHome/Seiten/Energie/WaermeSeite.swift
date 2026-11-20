import DuckCurveKit
import SwiftUI

/// Alles, was die Wärmeseite braucht - in einem Rutsch geholt.
///
/// **Drei Antworten, nicht eine.** Die Seite hat bisher nur `/energy/heat` geholt. Die Wärme
/// selbst, die Kosten, die Lüftung und die Annahmen stehen in `/energy/waermebilanz`, der
/// Nutzen des Verschiebens in `/energy/shift`. Beide Methoden lagen im Client bereit und
/// wurden nie gerufen.
///
/// **Die vier Spannen dazu.** Der Vergleich „Wärme im Zeitraum" stellt Tag, Woche, Monat und
/// Jahr nebeneinander; das sind vier weitere Abfragen derselben Bilanz. Scheitert eine, fehlt
/// ihre Spalte - die Seite bleibt stehen.
struct Waermedaten: Sendable {
    let bilanz: HeatBalanceOut
    let strom: HeatReportOut
    let schieben: ShiftReportOut?
    let jeSpanne: [Spanne: HeatBalanceOut]
}

/// Wärme: wer geliefert hat, was es gekostet hat, wie die Anlage lief.
///
/// **Die Wärme kommt aus der Bilanz, und nur von dort.** Wärmemenge, Arbeitszahl und
/// Wärmepreis stehen auf dieser Seite genau einmal. Aus `/energy/heat` kommt nur, was gemessen
/// ist: der Strom der Wärmepumpe nach Herkunft, die Taktung, der Ofen. Die Vorlage
/// (`apps/web/src/components/reports/HeatOverview.tsx`) hat dafür zwei Seiten
/// zusammengelegt, die für denselben Tag verschiedene Zahlen nannten.
///
/// **`/waerme/bilanz` ist keine Seite mehr, und das ist der Punkt.** Bis zum 10.11.2026 stand
/// hier eine zweite Seite „Bilanz“ daneben; die Vorlage hat sie zur Weiterleitung gemacht
/// (`apps/web/src/app/waerme/bilanz/page.tsx:1-15`), weil beide für denselben Tag
/// verschiedene Zahlen nannten - „24,5 kWh Wärme und Arbeitszahl 2,90 auf der einen, 20,4 kWh
/// und 2,41 auf der anderen“ (`HeatOverview.tsx:19-23`). Die App hatte diese zweite Seite als
/// `WaermebilanzSeite` in dieser Datei, mit einer Kachel „Wärme gesamt“, die den Ofen nicht
/// mitzählte. Sie ist gelöscht; die Adresse löst über ``Bereiche/ziel(_:)`` auf diese Seite
/// auf. Keine Zahl ist dabei verloren gegangen: „entnommen“ und „Verlust“ stehen als Unterzeile
/// der Entnahme-Kachel und als Zeilen im Spannenvergleich, die Arbeitszahl ebenfalls dort, die
/// Auflösung als Kopfzeile des Tagesverlaufs. Was nicht wiederkommt, lässt die Vorlage mit
/// Absicht weg: „davon nutzbar“, „erwartet, 24 h“ - der Wärmebedarf der kommenden Stunden
/// gehört zum Fahrplan und steht dort (`HeatOverview.tsx:30-31`).
struct WaermeSeite: View {
    var body: some View {
        Berichtsseite { z, api in
            async let bilanz = api.waermebilanz(z.spanne.rawValue, anker: z.anker)
            async let strom = api.energieWaerme(z.spanne.rawValue, anker: z.anker)
            async let spannen = holeSpannen(anker: z.anker, api: api)
            // Der Nutzen des Verschiebens darf fehlen - er ist eine Schaetzung und kein Teil
            // der Seite. Die drei oben laufen waehrenddessen schon.
            let schieben = try? await api.energieVerschiebung(z.spanne.rawValue, anker: z.anker)
            return Waermedaten(
                bilanz: try await bilanz, strom: try await strom, schieben: schieben,
                jeSpanne: await spannen
            )
        } inhalt: { d in
            inhalt(d)
        }
    }

    /// Die vier Spannen nebeneinander. `try?` je Spanne: eine fehlende Spalte ist besser als
    /// eine Seite, die an ihr scheitert.
    private func holeSpannen(anker: String, api: Api) async -> [Spanne: HeatBalanceOut] {
        await withTaskGroup(of: (Spanne, HeatBalanceOut?).self) { gruppe in
            for s in Spanne.allCases {
                gruppe.addTask {
                    (s, try? await api.waermebilanz(s.rawValue, anker: anker))
                }
            }
            var aus: [Spanne: HeatBalanceOut] = [:]
            for await (s, b) in gruppe {
                if let b { aus[s] = b }
            }
            return aus
        }
    }

    @ViewBuilder private func inhalt(_ d: Waermedaten) -> some View {
        let tag = d.bilanz.period == .day

        Kachelfeld(
            kacheln: Waermeuebersicht.kacheln(bilanz: d.bilanz, strom: d.strom)
                .map(Kacheldaten.init),
            kicker: "Wärme"
        )

        // Der Tag als Verlauf, jeder laengere Zeitraum als Balken. Beides zugleich waere
        // dieselbe Zufuhr zweimal: einmal je Minute, einmal je Stunde.
        if tag {
            Karte(kicker: "Tagesverlauf", titel: d.bilanz.resolutionDe) {
                Waermeverlauf(punkte: d.bilanz.series)
            }
            if !pufferreihe(d).isEmpty {
                Karte(
                    kicker: "Pufferspeicher",
                    titel: "Temperaturen in vier Höhen · Leistung der Wärmepumpe"
                ) {
                    Pufferbild(reihe: pufferreihe(d))
                }
            }
        } else {
            Karte(kicker: d.bilanz.period == .year ? "Wärme je Monat" : "Wärme je Tag") {
                if d.bilanz.buckets.isEmpty {
                    Leer(satz: "Für diesen Zeitraum liegen keine Werte vor.")
                } else {
                    Balkenbild(stuecke: erzeuger(d.bilanz))
                }
            }
        }

        Karte(kicker: "Strom der Wärmepumpe nach Herkunft") {
            if d.strom.summary.buckets.isEmpty {
                Leer(satz: "Für diesen Zeitraum liegen keine Werte vor.")
            } else {
                Balkenbild(stuecke: herkunft(d.strom))
            }
        }

        Karte(kicker: "Was die Wärme gekostet hat") {
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(Waermeuebersicht.kostenkernzahl(d.bilanz.cost))
                VStack(spacing: 0) {
                    ForEach(Waermeuebersicht.kostenzeilen(d.bilanz.cost)) { z in
                        Zeile(wort: z.wort, wert: z.wert)
                    }
                }
                if let satz = d.bilanz.cost?.cheaperDe, !satz.isEmpty {
                    Text(satz).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        Karte(kicker: "Taktung", titel: Waermeuebersicht.taktkopf(d.strom.cycling)) {
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(
                    Kennzahl(
                        wort: "Starts je Tag",
                        wert: Formate.zahl(d.strom.cycling.startsPerDay, stellen: 1)),
                    rechts: d.strom.cycling.verdict?.wort
                )
                VStack(spacing: 0) {
                    ForEach(Waermeuebersicht.taktzeilen(d.strom.cycling)) { z in
                        Zeile(wort: z.wort, wert: z.wert)
                    }
                }
                if let satz = d.strom.cycling.noteDe, !satz.isEmpty {
                    Text(satz).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        // Dieselbe Zahl wie auf „Geld": eine Rechnung, an zwei Stellen gezeigt.
        Karte(kicker: "Hat sich das Verschieben gelohnt?", titel: "geschätzt") {
            let k = Waermeuebersicht.schieben(d.schieben)
            VStack(alignment: .leading, spacing: 8) {
                kernzahl(Kennzahl(wort: k.bedeutung, wert: k.kernzahl, ton: .bernstein))
                if !k.zeilen.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(k.zeilen) { z in Zeile(wort: z.wort, wert: z.wert) }
                    }
                }
                if let h = k.hinweis {
                    Text(h).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        if d.strom.stove.available == true {
            Karte(kicker: "Pelletofen", titel: Waermeuebersicht.ofenkopf(d.strom.stove)) {
                ofenkarte(d.strom.stove)
            }
        } else {
            Karte(kicker: "Pelletofen") {
                Leer(satz: "In diesem Zeitraum hat der Ofen nicht gemeldet.")
            }
        }

        // Nur zeigen, wenn es etwas zu zeigen gibt: eine Karte, die jeden Tag „null" sagt,
        // liest nach einer Woche niemand mehr.
        if let l = d.bilanz.ventilation, Waermeuebersicht.zeigtFenster(l) {
            Karte(
                kicker: "Bei offenem Fenster",
                titel: "geschätzt, nach offenen Heizkreisen verteilt"
            ) {
                fensterkarte(l)
            }
        }

        Karte(kicker: "Bilanz des Puffers") {
            pufferbilanz(d.strom.bufferBalance)
        }

        Karte(kicker: "Wärme im Zeitraum") {
            spannenvergleich(d.jeSpanne)
        }

        Methode(
            [
                "Im Haus gibt es keinen Wärmemengenzähler: jede Wärmemenge auf dieser Seite ist aus Strom, Ofenbetrieb und Puffertemperaturen gerechnet.",
                d.bilanz.noteDe,
                d.strom.modelNoteDe,
                d.strom.bufferBalance.noteDe,
                d.strom.priceQuality.noteDe,
                Waermeuebersicht.annahmensatz(d.bilanz.params),
                Waermeuebersicht.abdeckungssatz(d.strom.summary.meta),
                d.strom.summary.meta.estimatedNoteDe,
            ])
    }

    // MARK: - Bausteine

    /// Die große Zahl einer Karte mit ihrer Unterzeile.
    private func kernzahl(_ k: Kennzahl, rechts: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(k.wert)
                .font(Schrift.zahlGross)
                .foregroundStyle(Farbe.ton(k.ton))
            Text(k.wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            if let rechts {
                Spacer(minLength: 6)
                Text(rechts).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func pufferreihe(_ d: Waermedaten) -> [Waermeuebersicht.Pufferpunkt] {
        Waermeuebersicht.pufferreihe(d.strom.bufferSeries)
    }

    private func erzeuger(_ b: HeatBalanceOut) -> [Balkenbild.Stueck] {
        [
            .init(
                name: "Wärmepumpe", farbe: Farbe.waermepumpe,
                werte: b.buckets.map { ($0.labelDe, $0.heatPumpKwh ?? 0) }),
            .init(
                name: "Ofen (Wasser)", farbe: Farbe.ofen,
                werte: b.buckets.map { ($0.labelDe, $0.stoveWaterKwh ?? 0) }),
            .init(
                name: "Ofen (Raum)", farbe: Farbe.ofen.opacity(0.55),
                werte: b.buckets.map { ($0.labelDe, $0.stoveRoomKwh ?? 0) }),
        ]
    }

    private func herkunft(_ r: HeatReportOut) -> [Balkenbild.Stueck] {
        // `EnergyBucketOut` heisst das Wort `label` und nicht `labelDe` - anders als
        // `HeatBucketOut` zwei Funktionen weiter oben. Zwei Modelle, zwei Namen fuer dasselbe.
        let b = r.summary.buckets
        return [
            .init(
                name: "aus PV", farbe: Farbe.pv,
                werte: b.map { ($0.label, $0.totals.heatPumpPvKwh ?? 0) }),
            .init(
                name: "aus Batterie", farbe: Farbe.batterie,
                werte: b.map { ($0.label, $0.totals.heatPumpBatteryKwh ?? 0) }),
            .init(
                name: "aus Netz", farbe: Farbe.netzBezug,
                werte: b.map { ($0.label, $0.totals.heatPumpGridKwh ?? 0) }),
        ]
    }

    private func ofenkarte(_ o: StoveOut) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            kernzahl(
                Kennzahl(
                    wort: "Laufzeit", wert: Waermeuebersicht.dauer(minuten: o.runningMinutes),
                    ton: .glut))
            VStack(spacing: 0) {
                ForEach(Waermeuebersicht.ofenzeilen(o)) { z in
                    Zeile(wort: z.wort, wert: z.wert)
                }
            }
            let stufen = Waermeuebersicht.ofenstufen(o)
            if !stufen.isEmpty {
                Umbruchzeile(abstand: 12, zeilenabstand: 4) {
                    Text("Leistungsstufen:").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    ForEach(Array(stufen.enumerated()), id: \.offset) { _, s in
                        Text("\(s.stufe): \(s.dauer)")
                            .font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                    }
                }
            }
            ForEach([o.noteDe, Waermeuebersicht.ofenbrennstoffsatz(o)].compactMap { $0 }, id: \.self) {
                satz in
                Text(satz).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func fensterkarte(_ l: VentilationOut) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            kernzahl(
                Kennzahl(
                    wort: "kWh in Räume mit offenem Fenster",
                    wert: Formate.zahl(l.kwh, stellen: 1)),
                rechts: Waermeuebersicht.fensterkopf(l)
            )
            if !l.rooms.isEmpty {
                Tabelle(
                    zeilennamen: l.rooms.map(\.name),
                    spalten: [
                        .init(
                            name: "Fenster offen",
                            zellen: l.rooms.map { "\($0.openMinutes) min" }),
                        .init(
                            name: "davon geheizt",
                            zellen: l.rooms.map { "\($0.heatingMinutes) min" }),
                        .init(
                            name: "Wärme",
                            zellen: l.rooms.map { Formate.kwh($0.kwh) }),
                    ]
                )
            }
            if !l.noteDe.isEmpty {
                Text(l.noteDe).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Dieselben zwölf Größen für Tag, Woche, Monat und Jahr nebeneinander.
    private func spannenvergleich(_ je: [Spanne: HeatBalanceOut]) -> some View {
        let zeilen = Waermeuebersicht.spannenzeilen(je)
        return Tabelle(
            zeilennamen: zeilen.map(\.wort),
            spalten: Spanne.allCases.enumerated().map { i, s in
                .init(name: s.name, zellen: zeilen.map { $0.werte[i] })
            }
        )
    }

    /// Die Bilanz des Puffers: was hineinging, was herauskam, und was sich nicht erklaeren laesst.
    ///
    /// Die letzte Zeile ist die wichtigste. Ein Puffer, dessen Gewinn sich zu einem Drittel
    /// nicht erklaeren laesst, hat entweder einen Fuehler, der luegt, oder eine Waermequelle,
    /// die niemand kennt.
    private func pufferbilanz(_ b: BufferBalanceOut) -> some View {
        VStack(spacing: 0) {
            Zeile(wort: "am Anfang", wert: Formate.zahl(b.energyStartKwh, stellen: 1), einheit: "kWh")
            Zeile(wort: "am Ende", wert: Formate.zahl(b.energyEndKwh, stellen: 1), einheit: "kWh")
            Zeile(
                wort: "durch die Wärmepumpe", wert: Formate.zahl(b.gainWithHpKwh, stellen: 1),
                einheit: "kWh", farbe: Farbe.waermepumpe
            )
            if b.stoveKnown == true {
                Zeile(
                    wort: "durch den Ofen", wert: Formate.zahl(b.gainWithStoveKwh, stellen: 1),
                    einheit: "kWh", farbe: Farbe.ofen
                )
            }
            Zeile(wort: "entnommen", wert: Formate.zahl(b.dropKwh, stellen: 1), einheit: "kWh")
            Zeile(
                wort: "nicht erklärt", wert: Formate.zahl(b.gainUnexplainedKwh, stellen: 1),
                einheit: "kWh",
                dazu: "Gewinn ohne bekannte Quelle",
                farbe: (b.gainUnexplainedKwh ?? 0) > 1 ? Farbe.achtung : Farbe.text1
            )
        }
    }
}
