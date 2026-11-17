import Charts
import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Jetzt: alle Messwerte des Augenblicks, wie der eigene Bus sie meldet.
///
/// **Das ist die Seite, auf der nichts weggelassen wird.** Die Startseite zeigt eine Zahl, diese
/// zeigt achtzehn - Verdampfer, Sauggas, Heissgas, Flüssig, Verdichterfrequenz, Durchfluss,
/// Spreizung. Wer hierherkommt, sucht etwas Bestimmtes und soll es finden, ohne zu tippen.
struct WaermepumpeSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var wp: WaermepumpeOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let w = wp {
                Kachelfeld(kacheln: kennzahlen(w), kicker: w.zustandDe)
                if let busStumm = w.busStummDe, !busStumm.isEmpty {
                    Karte { Leer(satz: "Der Bus schweigt.", dazu: busStumm) }
                }
                Karte(kicker: "Kältekreis") {
                    VStack(spacing: 0) {
                        Zeile(wort: "Verdampfer", wert: Formate.celsius(w.verdampferC.belastbar, stellen: 1))
                        Zeile(wort: "Sauggas", wert: Formate.celsius(w.sauggasC.belastbar, stellen: 1))
                        Zeile(wort: "Heißgas", wert: Formate.celsius(w.heissgasC.belastbar, stellen: 1))
                        Zeile(wort: "Flüssig", wert: Formate.celsius(w.fluessigC.belastbar, stellen: 1))
                        Zeile(
                            wort: "Verdichter", wert: Formate.zahl(w.verdichterHz.belastbar, stellen: 0),
                            einheit: "Hz"
                        )
                        // **Das `if let` und das `.belastbar` sagen zwei verschiedene Dinge.**
                        // Wahlfrei ist hier das *Feld*: nicht jede Pumpe meldet diese beiden
                        // Groessen ueberhaupt - dann faellt die Zeile weg. Wahlfrei ist auch die
                        // *Zahl* im Messwert: gemeldet, aber alt oder unglaubwuerdig - dann
                        // steht die Zeile da und zeigt einen Strich, wie die Zeilen darueber.
                        if let a = w.verdichterA {
                            Zeile(
                                wort: "Verdichterstrom",
                                wert: Formate.zahl(a.belastbar, stellen: 1), einheit: "A"
                            )
                        }
                        if let l = w.luefterDrehzahl {
                            Zeile(
                                wort: "Lüfter",
                                wert: Formate.zahl(l.belastbar, stellen: 0), einheit: "1/min"
                            )
                        }
                    }
                }
                Karte(kicker: "Wasserseite") {
                    VStack(spacing: 0) {
                        Zeile(wort: "Vorlauf", wert: Formate.celsius(w.vorlaufC.belastbar, stellen: 1))
                        Zeile(wort: "Rücklauf", wert: Formate.celsius(w.ruecklaufC.belastbar, stellen: 1))
                        Zeile(wort: "Sollvorlauf", wert: Formate.celsius(w.vorlaufSollC.belastbar, stellen: 1))
                        if let s = w.spreizungK {
                            Zeile(wort: "Spreizung", wert: Formate.zahl(s, stellen: 1), einheit: "K")
                        }
                        Zeile(
                            wort: "Durchfluss", wert: Formate.zahl(w.durchflussLMin.belastbar, stellen: 1),
                            einheit: "l/min"
                        )
                        Zeile(wort: "Speicherfühler", wert: Formate.celsius(w.speicherfuehlerC.belastbar, stellen: 1))
                        // Der Puffer meldet mehrere Fuehler - jeden mit seiner Nummer, damit
                        // die Schichtung zu sehen ist.
                        ForEach(Array(w.pufferC.enumerated()), id: \.offset) { i, m in
                            Zeile(
                                wort: "Puffer \(i + 1)",
                                wert: Formate.celsius(m.belastbar, stellen: 1),
                                dazu: m.hinweis(jetzt: haus.jetzt)
                            )
                        }
                        if let p = w.pumpeLaeuft {
                            Zeile(wort: "Pumpe", wert: p ? "läuft" : "aus")
                        }
                    }
                }
                Karte(kicker: "Regler und Kontakte") {
                    VStack(spacing: 0) {
                        if let h = w.heizanforderung {
                            Zeile(wort: "Heizanforderung", wert: h ? "ja" : "nein")
                        }
                        if let r = w.raumSollC?.belastbar {
                            Zeile(wort: "Raumsollwert", wert: Formate.celsius(r, stellen: 1))
                        }
                        if let v = w.ventilCode {
                            Zeile(wort: "Umschaltventil", wert: String(v))
                        }
                        if let h = w.heizstabCode {
                            Zeile(wort: "Heizstab", wert: String(h))
                        }
                        if let z = w.zusatzKw {
                            Zeile(
                                wort: "Zusatzheizung", wert: Formate.kw(z), einheit: "kW",
                                farbe: z > 0.05 ? Farbe.achtung : Farbe.text1
                            )
                        }
                        if let k = w.kreisDe {
                            Zeile(wort: "Kreis", wert: k, dazu: w.kreisCode.map(String.init))
                        }
                        if let e = w.einspeisung {
                            Zeile(wort: "Einspeisung", wert: e.rawValue)
                        }
                    }
                }
                Methode(w.hinweiseDe, titel: "Hinweise des Busses")
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task { await lade() }
        .task { await haltFrisch() }
    }

    private func kennzahlen(_ w: WaermepumpeOut) -> [Kacheldaten] {
        [
            Kacheldaten(
                // Der Zaehler fuehrt, der Bus hilft aus. **Beide Felder sind `Messwert` und
                // nicht wahlfrei** - wahlfrei ist erst die Zahl darin (`.belastbar` ist nil,
                // wenn die Guete sie nicht traegt). Hier stand `w.leistungZaehlerKw ?? …`,
                // was zweierlei verwechselt: den Messwert mit seiner Zahl, und „kein Wert"
                // mit „kein Messwert".
                "Leistung",
                Formate.kw(w.leistungZaehlerKw.belastbar ?? w.leistungBusKw.belastbar),
                einheit: "kW",
                dazu: w.leistungZaehlerKw.belastbar != nil ? "am Zähler" : "über den Bus",
                farbe: Farbe.waermepumpe
            ),
            Kacheldaten(
                "Wärmeleistung", Formate.zahl(w.waermeleistungKw, stellen: 2), einheit: "kW"
            ),
            Kacheldaten("Arbeitszahl", Formate.zahl(w.arbeitszahl, stellen: 2)),
            Kacheldaten("draußen", Formate.celsius(w.aussenC.belastbar, stellen: 1)),
            Kacheldaten("Vorlauf", Formate.celsius(w.vorlaufC.belastbar, stellen: 1)),
            Kacheldaten(
                "Verdichter", Formate.zahl(w.verdichterHz.belastbar, stellen: 0), einheit: "Hz",
                dazu: w.laeuft ? "läuft" : "aus"
            ),
        ]
    }

    private func lade() async {
        do {
            wp = try await haus.api.waermepumpe()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }

    private func haltFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            if let w = try? await haus.api.waermepumpe() { wp = w }
        }
    }
}

/// Wärmepumpe · Betrieb: die Läufe über Tage, mit Abtauen, Takten und der Heizkurve des Reglers.
///
/// **Das Takten ist der Gegenstand.** Eine Waermepumpe, die stuendlich anlaeuft und nach zwoelf
/// Minuten wieder ausgeht, verbraucht mehr und haelt kuerzer als eine, die zweimal am Tag zwei
/// Stunden laeuft. Die Klassenverteilung unten sagt, welche von beiden hier steht.
struct BetriebSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tage = 7
    @State private var betrieb: BetriebOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            Tagewahl(tage: $tage, moeglich: [7, 30, 90])
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let b = betrieb {
                Kachelfeld(kacheln: kennzahlen(b), kicker: "\(b.zeitraumTage) Tage")
                if !b.saetzeDe.isEmpty {
                    Karte(kicker: "Was auffällt") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(b.saetzeDe.enumerated()), id: \.offset) { _, s in
                                Text(s)
                                    .font(Schrift.klein)
                                    .foregroundStyle(Farbe.text1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                if !b.klassen.isEmpty {
                    Karte(kicker: "Wie lange die Läufe dauerten") {
                        Balkenbild(
                            stuecke: [
                                .init(
                                    name: "Läufe", farbe: Farbe.waermepumpe,
                                    werte: b.klassen.map { (klassenname($0), Double($0.laeufe)) }
                                )
                            ],
                            einheit: "Läufe", gestapelt: false, hoehe: 150
                        )
                    }
                }
                if !b.tage.isEmpty {
                    Karte(kicker: "Nach Tagen") {
                        Tabelle(
                            zeilennamen: b.tage.map { Tag.kurz($0.tag) },
                            spalten: [
                                .init(name: "Starts", zellen: b.tage.map { String($0.starts) }),
                                .init(
                                    name: "Laufzeit",
                                    zellen: b.tage.map { Formate.dauer(minuten: $0.laufMin) }
                                ),
                                .init(
                                    name: "Abtauen",
                                    zellen: b.tage.map { Formate.dauer(minuten: $0.abtauMin) }
                                ),
                                .init(
                                    name: "Strom",
                                    zellen: b.tage.map { Formate.zahl($0.stromKwh, stellen: 1) }
                                ),
                                .init(
                                    name: "Arbeitszahl",
                                    zellen: b.tage.map { Formate.zahl($0.copTag, stellen: 2) }
                                ),
                            ]
                        )
                    }
                }
                if let hk = b.heizkurve {
                    heizkurve(hk)
                }
                Methode(b.hinweiseDe)
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task(id: tage) { await lade() }
    }

    /// Starts je Tag - die Zahl, an der sich Takten erkennen laesst.
    private func starteJeTag(_ b: BetriebOut) -> String? {
        guard let starts = b.starts, b.zeitraumTage > 0 else { return nil }
        return "\(Formate.zahl(Double(starts) / Double(b.zeitraumTage), stellen: 1)) je Tag"
    }

    private func klassenname(_ k: BetriebKlasseOut) -> String {
        guard let bis = k.bisMin else { return "\(k.vonMin)+" }
        return "\(k.vonMin)–\(bis)"
    }

    private func kennzahlen(_ b: BetriebOut) -> [Kacheldaten] {
        [
            Kacheldaten(
                "Starts", b.starts.map(String.init) ?? Formate.leer,
                dazu: starteJeTag(b)
            ),
            Kacheldaten(
                "Laufzeit", Formate.dauer(minuten: b.laufMin)
            ),
            Kacheldaten(
                "Lauf im Mittel", Formate.dauer(minuten: b.laufMedianMin.map { Int($0.rounded()) }),
                dazu: "Median"
            ),
            Kacheldaten("Arbeitszahl", Formate.zahl(b.copGesamt, stellen: 2)),
            Kacheldaten(
                "Abtauen", Formate.dauer(minuten: b.abtauMin),
                dazu: b.abtauungen.map { "\($0) Mal" }
            ),
            Kacheldaten(
                "Zusatzheizung", Formate.dauer(minuten: b.zusatzMin),
                farbe: (b.zusatzMin ?? 0) > 0 ? Farbe.achtung : Farbe.text1
            ),
        ]
    }

    /// Die Heizkurve, wie der Regler sie faehrt - gemessen, nicht eingestellt.
    ///
    /// Das ist der Unterschied zur Seite „Regler": dort steht, was eingestellt *ist*; hier steht,
    /// was dabei herauskommt. Die beiden muessen nicht dasselbe sein, und wenn sie es nicht sind,
    /// ist das die interessanteste Auskunft der ganzen Seite.
    private func heizkurve(_ hk: BetriebHeizkurveOut) -> some View {
        Karte(kicker: "Gemessene Heizkurve", titel: hk.formelDe) {
            VStack(alignment: .leading, spacing: 10) {
                Chart {
                    ForEach(kurvenpunkte(hk), id: \.aussen) { p in
                        LineMark(
                            x: .value("draußen", p.aussen),
                            y: .value("Vorlauf", p.vorlauf)
                        )
                        .foregroundStyle(Farbe.waermepumpe)
                        .lineStyle(StrokeStyle(lineWidth: 1.8))
                    }
                }
                .chartXScale(domain: hk.aussenVonC...hk.aussenBisC)
                .chartXAxis {
                    AxisMarks { w in
                        AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                        AxisValueLabel {
                            if let d = w.as(Double.self) {
                                Text(Formate.zahl(d, stellen: 0))
                                    .font(Schrift.achse).foregroundStyle(Farbe.text3)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { w in
                        AxisGridLine().foregroundStyle(Farbe.rasterlinie)
                        AxisValueLabel {
                            if let d = w.as(Double.self) {
                                Text(Formate.zahl(d, stellen: 0))
                                    .font(Schrift.achse).foregroundStyle(Farbe.text3)
                            }
                        }
                    }
                }
                .frame(height: 160)
                HStack(spacing: 16) {
                    Text("Außentemperatur in °C")
                        .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    Spacer(minLength: 0)
                    Text("aus \(hk.n) Messungen")
                        .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    if let r2 = hk.r2 {
                        Text("R² \(Formate.zahl(r2, stellen: 2))")
                            .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                    }
                }
            }
        }
    }

    private func kurvenpunkte(_ hk: BetriebHeizkurveOut) -> [(aussen: Double, vorlauf: Double)] {
        let schritte = 24
        return (0...schritte).map { i in
            let x = hk.aussenVonC + (hk.aussenBisC - hk.aussenVonC) * Double(i) / Double(schritte)
            return (aussen: x, vorlauf: hk.a + hk.b * x)
        }
    }

    private func lade() async {
        do {
            betrieb = try await haus.api.betrieb(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

/// Die Wahl des Zeitraums in Tagen, fuer die Seiten, die keinen Kalender brauchen.
struct Tagewahl: View {
    @Binding var tage: Int
    let moeglich: [Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(moeglich, id: \.self) { n in
                Button {
                    tage = n
                } label: {
                    Text("\(n) Tage")
                        .font(Schrift.winzig)
                        .foregroundStyle(n == tage ? Farbe.deep : Farbe.text2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(n == tage ? Farbe.amberWeich : Farbe.flaeche2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
