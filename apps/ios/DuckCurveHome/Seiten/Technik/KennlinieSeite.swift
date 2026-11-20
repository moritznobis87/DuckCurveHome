import Charts
import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Kennlinie: die gemessene Arbeitszahl über der Außentemperatur.
///
/// **Das ist das Datenblatt dieser Maschine, aus eigenen Messungen.** Hersteller nennen die
/// Arbeitszahl bei A7/W35 und A-7/W35; was die Anlage in diesem Haus bei diesem Vorlauf wirklich
/// leistet, steht nirgends - außer hier.
///
/// **Die Punkte sind das Wichtigste, nicht die Kurve.** Eine Regression durch zwanzig Punkte
/// sieht genauso glatt aus wie eine durch zweitausend. Darum stehen die Punkte darunter, die
/// Bilanz sagt, wie viele Minuten überhaupt brauchbar waren, und die Geltung sagt, in welchem
/// Bereich die Kurve etwas bedeutet.
struct KennlinieSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var tage = 30
    @State private var kennlinie: KennlinieOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            // `.kl-knopf` wie in der Vorlage dieser Seite (`Kennlinie.tsx:126`).
            Tagewahl(tage: $tage, moeglich: [7, 30, 90], form: .klKnopf)
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let k = kennlinie {
                if let fehlt = k.fehltDe, !fehlt.isEmpty {
                    Karte { Leer(satz: "Für eine Kennlinie fehlt etwas.", dazu: fehlt) }
                }
                if let fit = k.fit {
                    kennzahlenKarte(fit, k)
                    bild(k, fit)
                } else if !k.punkte.isEmpty {
                    bild(k, nil)
                }
                if let b = k.bilanz {
                    bilanz(b)
                }
                if !k.annahme.isEmpty {
                    Karte(
                        kicker: "Angenommene Kurve",
                        titel: k.annahmeVorlaufC.map { "bei \(Formate.celsius($0)) Vorlauf" }
                    ) {
                        Tabelle(
                            zeilennamen: k.annahme.map { Formate.celsius($0.aussenC) },
                            spalten: [
                                .init(
                                    name: "Arbeitszahl",
                                    zellen: k.annahme.map { Formate.zahl($0.cop, stellen: 2) }
                                )
                            ]
                        )
                        Text(
                            "Diese Kurve nimmt der Fahrplan an, solange nicht genug gemessen ist. "
                                + "Sie steht in den Annahmen und ist einstellbar."
                        )
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                    }
                }
                Methode(k.hinweiseDe)
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task(id: tage) { await lade() }
    }

    private func kennzahlenKarte(_ fit: KennlinienFitOut, _ k: KennlinieOut) -> some View {
        Karte(kicker: "Die gemessene Kurve", titel: fit.formelDe) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 0) {
                    Zeile(wort: "Art", wert: fit.art.rawValue)
                    Zeile(
                        wort: "Streuung", wert: Formate.zahl(fit.rmse, stellen: 3),
                        dazu: "mittlerer Fehler der Arbeitszahl"
                    )
                    if let r2 = fit.r2 {
                        Zeile(
                            wort: "Bestimmtheit", wert: Formate.zahl(r2, stellen: 3),
                            dazu: r2 < 0.5 ? "schwach – die Punkte streuen weit" : nil,
                            farbe: r2 < 0.5 ? Farbe.achtung : Farbe.text1
                        )
                    }
                    Zeile(wort: "Messpunkte", wert: String(fit.n))
                    Zeile(
                        wort: "gilt für draußen",
                        wert: "\(Formate.celsius(fit.aussenVonC)) bis \(Formate.celsius(fit.aussenBisC))"
                    )
                    Zeile(
                        wort: "und für Vorlauf",
                        wert: "\(Formate.celsius(fit.vorlaufVonC)) bis \(Formate.celsius(fit.vorlaufBisC))"
                    )
                }
                Text(fit.geltungDe)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Die Punkte als Streubild, die Kurve darüber.
    ///
    /// **Die Punkte bekommen die Farbe ihres Vorlaufs.** Die Arbeitszahl hängt an zwei Größen,
    /// nicht an einer: draußen und Vorlauf. Ein Streubild ohne diese zweite Kodierung sieht wie
    /// Rauschen aus, wo in Wahrheit zwei Scharen liegen - und genau das war an der Vorlage die
    /// Beobachtung, die den Antwortfächer hervorgebracht hat.
    private func bild(_ k: KennlinieOut, _ fit: KennlinienFitOut?) -> some View {
        Karte(kicker: "Messpunkte") {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(Array(k.punkte.enumerated()), id: \.offset) { _, p in
                        PointMark(
                            x: .value("draußen", p.aussenC),
                            y: .value("Arbeitszahl", p.cop)
                        )
                        .symbolSize(18)
                        .foregroundStyle(vorlauffarbe(p.vorlaufC))
                        .opacity(0.75)
                    }
                    if let fit {
                        ForEach(kurve(fit), id: \.aussen) { punkt in
                            LineMark(
                                x: .value("draußen", punkt.aussen),
                                y: .value("Arbeitszahl", punkt.cop),
                                series: .value("Reihe", "fit")
                            )
                            .foregroundStyle(Farbe.text1)
                            .lineStyle(StrokeStyle(lineWidth: 1.8))
                        }
                    }
                    ForEach(k.annahme, id: \.aussenC) { a in
                        LineMark(
                            x: .value("draußen", a.aussenC),
                            y: .value("Arbeitszahl", a.cop),
                            series: .value("Reihe", "annahme")
                        )
                        .foregroundStyle(Farbe.mist)
                        .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
                    }
                }
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
                                Text(Formate.zahl(d, stellen: 1))
                                    .font(Schrift.achse).foregroundStyle(Farbe.text3)
                            }
                        }
                    }
                }
                .frame(height: 220)
                legende(k)
            }
        }
    }

    /// Die Farbskala des Vorlaufs: kalt nach heiss, dieselbe wie im Puffer.
    private func vorlauffarbe(_ grad: Double) -> Color {
        let stufen: [(Double, Farbwert)] = [
            (28, Marken.waerme[0]), (34, Marken.waerme[1]), (40, Marken.waerme[2]),
            (46, Marken.waerme[3]), (55, Marken.waerme[4]),
        ]
        guard let erste = stufen.first, let letzte = stufen.last else { return Farbe.mist }
        if grad <= erste.0 { return Color(erste.1) }
        if grad >= letzte.0 { return Color(letzte.1) }
        for i in 1..<stufen.count where grad <= stufen[i].0 {
            let (g0, f0) = stufen[i - 1]
            let (g1, f1) = stufen[i]
            let t = (grad - g0) / (g1 - g0)
            return Color(
                Farbwert(
                    rot: f0.rot + (f1.rot - f0.rot) * t,
                    gruen: f0.gruen + (f1.gruen - f0.gruen) * t,
                    blau: f0.blau + (f1.blau - f0.blau) * t
                )
            )
        }
        return Color(letzte.1)
    }

    private func legende(_ k: KennlinieOut) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("Vorlauf").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                ForEach([28.0, 34, 40, 46, 55], id: \.self) { g in
                    HStack(spacing: 2) {
                        Circle().fill(vorlauffarbe(g)).frame(width: 7, height: 7)
                        Text(Formate.zahl(g, stellen: 0))
                            .font(Schrift.achse).foregroundStyle(Farbe.text3)
                    }
                }
                Text("°C").font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Rectangle().fill(Farbe.text1).frame(width: 12, height: 2)
                    Text("gemessen").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                if !k.annahme.isEmpty {
                    HStack(spacing: 5) {
                        Rectangle().fill(Farbe.mist).frame(width: 12, height: 1.5)
                        Text("angenommen").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                }
                Text("Außentemperatur in °C")
                    .font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func kurve(_ fit: KennlinienFitOut) -> [(aussen: Double, cop: Double)] {
        // Die Formel des Dienstes: a + b·draußen + c·Vorlauf. Fuer das Bild wird der Vorlauf in
        // der Mitte seines Geltungsbereichs eingesetzt - eine Flaeche in einem Diagramm mit zwei
        // Achsen waere nicht zu lesen, und die Mitte ist die ehrlichste Scheibe daraus.
        let vorlauf = (fit.vorlaufVonC + fit.vorlaufBisC) / 2
        let schritte = 24
        return (0...schritte).map { i in
            let x = fit.aussenVonC + (fit.aussenBisC - fit.aussenVonC) * Double(i) / Double(schritte)
            return (aussen: x, cop: fit.a + fit.bAussen * x + fit.cVorlauf * vorlauf)
        }
    }

    /// Die Bilanz der Minuten: wie viel von dem Zeitraum überhaupt brauchbar war.
    ///
    /// **Das ist die Karte, die eine Kennlinie glaubwürdig macht oder nicht.** Dreißig Tage
    /// klingen nach viel; wenn davon vierzig Minuten brauchbar sind, ist die Kurve eine
    /// Vermutung mit Nachkommastellen.
    private func bilanz(_ b: KennlinienBilanzOut) -> some View {
        Karte(kicker: "Woher die Punkte kommen") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 0) {
                    Zeile(wort: "Minuten im Zeitraum", wert: Formate.zahl(Double(b.minuten), stellen: 0))
                    Zeile(wort: "davon geheizt", wert: Formate.zahl(Double(b.heizen), stellen: 0))
                    Zeile(wort: "Anlauf, verworfen", wert: Formate.zahl(Double(b.anlauf), stellen: 0))
                    Zeile(
                        wort: "mit Zusatzheizung", wert: Formate.zahl(Double(b.zusatz), stellen: 0),
                        dazu: "zählt nicht: der Heizstab verfälscht die Arbeitszahl"
                    )
                    Zeile(wort: "ohne Messwert", wert: Formate.zahl(Double(b.ohneWert), stellen: 0))
                    Zeile(wort: "ohne Wärmemenge", wert: Formate.zahl(Double(b.ohneWaerme), stellen: 0))
                    Zeile(
                        wort: "unglaubwürdig", wert: Formate.zahl(Double(b.unglaubwuerdig), stellen: 0),
                        farbe: b.unglaubwuerdig > b.gueltig / 4 ? Farbe.achtung : Farbe.text1
                    )
                    Divider().overlay(Farbe.linie1).padding(.vertical, 4)
                    Zeile(
                        wort: "brauchbar", wert: Formate.zahl(Double(b.gueltig), stellen: 0),
                        dazu: "in \(b.fenster) Fenstern, daraus \(b.punkte) Punkte",
                        farbe: Farbe.mist
                    )
                }
                if let satz = b.satzDe, !satz.isEmpty {
                    Text(satz)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !b.fehlt.isEmpty {
                    let fehlt = b.fehlt
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Was einzeln fehlte")
                            .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        ForEach(fehlt.keys.sorted(), id: \.self) { k in
                            HStack {
                                Text(k).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                                Spacer(minLength: 8)
                                Text(Formate.zahl(Double(fehlt[k] ?? 0), stellen: 0))
                                    .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                            }
                        }
                    }
                }
            }
        }
    }

    private func lade() async {
        do {
            kennlinie = try await haus.api.kennlinie(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}
