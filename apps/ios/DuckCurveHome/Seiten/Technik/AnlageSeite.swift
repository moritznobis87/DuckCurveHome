import DuckCurveKit
import SwiftUI

/// Anlage: der Augenblick der Wasser- und Stromseite in einer Antwort.
///
/// Das Dashboard zeichnet hier ein Anlagenschema - Puffer, Waermepumpe, Ofen, Heizkreise,
/// Warmwasser, mit Leitungen dazwischen. In der App stehen dieselben Werte als Gruppen mit dem
/// Glas des Puffers in der Mitte: ein Schema auf 390 Punkten Breite ist ein Gewirr, und auf dem
/// iPad ist der Unterschied zur Gruppenansicht kleiner, als er aussieht - abgelesen wird ohnehin
/// Gruppe fuer Gruppe.
struct AnlageSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var anlage: AnlageOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let a = anlage {
                kopf(a)
                strom(a.strom)
                speicher(a.speicher)
                waermepumpe(a.waermepumpe)
                ofenkarte(a.ofen)
                heizkreis(a.heizkreis)
                warmwasser(a.warmwasser)
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task { await lade() }
        .task { await haltFrisch() }
    }

    private func kopf(_ a: AnlageOut) -> some View {
        HStack {
            Text("Stand \(Formate.hhmm(iso: a.at))")
                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
            Spacer(minLength: 8)
            if let aussen = a.outdoorC {
                Text("\(Formate.celsius(aussen, stellen: 1)) draußen")
                    .font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func strom(_ s: AnlageStromOut) -> some View {
        Karte(kicker: "Strom") {
            VStack(spacing: 0) {
                Zeile(wort: "Sonne", wert: Formate.kw(s.pvKw), einheit: "kW", farbe: Farbe.pv)
                Zeile(wort: "Netz", wert: Formate.kw(s.gridKw), einheit: "kW")
                Zeile(wort: "Speicher", wert: Formate.kw(s.batteryKw), einheit: "kW")
                Zeile(wort: "Ladestand", wert: Formate.prozent(s.batterySoc.map { $0 > 1 ? $0 / 100 : $0 }))
                Zeile(wort: "Haus", wert: Formate.kw(s.houseKw), einheit: "kW")
                Zeile(wort: "Wärmepumpe", wert: Formate.kw(s.heatPumpKw), einheit: "kW", farbe: Farbe.waermepumpe)
                Zeile(wort: "übriges", wert: Formate.kw(s.restKw), einheit: "kW")
                Divider().overlay(Farbe.linie1).padding(.vertical, 6)
                // Die drei Anteile sagen, woher der Strom in diesem Augenblick kommt - und sie
                // addieren sich zu eins, was sie als Aufteilung lesbar macht.
                Zeile(wort: "davon aus der Sonne", wert: Formate.prozent(s.sharePv), farbe: Farbe.pv)
                Zeile(wort: "aus dem Netz", wert: Formate.prozent(s.shareGrid))
                Zeile(wort: "aus dem Speicher", wert: Formate.prozent(s.shareBattery))
            }
        }
    }

    private func speicher(_ s: AnlageSpeicherOut) -> some View {
        Karte(kicker: "Pufferspeicher", titel: s.netWord) {
            HStack(alignment: .top, spacing: 16) {
                Pufferglas(
                    temperaturen: s.tempsC,
                    soc: s.soc,
                    zustand: Pufferzustand.aus(
                        fuehler: s.tempsC, jetzt: haus.jetzt,
                        laedt: (s.netKw ?? 0) > 0.1,
                        status: haus.zustand?.buffer.status
                    )
                )
                .frame(width: 118, height: 210)
                VStack(spacing: 0) {
                    Zeile(wort: "nutzbar", wert: Formate.zahl(s.usableKwh, stellen: 1), einheit: "kWh")
                    Zeile(wort: "Fassung", wert: Formate.zahl(s.capacityKwh, stellen: 1), einheit: "kWh")
                    Zeile(wort: "Volumen", wert: Formate.zahl(s.volumeLiters, stellen: 0), einheit: "l")
                    Zeile(
                        wort: "gerade", wert: Formate.kw(s.netKw), einheit: "kW",
                        dazu: s.netWord
                    )
                    if let r = s.returnC {
                        Zeile(wort: "Rücklauf", wert: Formate.celsius(r, stellen: 1))
                    }
                }
            }
        }
    }

    private func waermepumpe(_ w: AnlageWaermepumpeOut) -> some View {
        Karte(kicker: "Wärmepumpe", titel: w.running ? "läuft" : "aus") {
            VStack(spacing: 0) {
                Zeile(
                    wort: "Leistung", wert: Formate.kw(w.powerKw), einheit: "kW",
                    farbe: Farbe.waermepumpe
                )
                if let th = w.thermalKw {
                    Zeile(wort: "Wärmeleistung", wert: Formate.zahl(th, stellen: 2), einheit: "kW")
                }
                if let c = w.cop {
                    Zeile(wort: "Arbeitszahl", wert: Formate.zahl(c, stellen: 2))
                }
                Zeile(wort: "Vorlauf", wert: Formate.celsius(w.flowC, stellen: 1))
                if let seit = w.runningSince, let d = Zeit.ausIso(seit) {
                    Zeile(wort: "läuft seit", wert: Formate.hhmm(d))
                }
                Zeile(
                    wort: "Freigabe K1",
                    wert: (haus.zustand?.heatPump.releaseContactOn ?? false) ? "zu" : "offen"
                )
                Zeile(
                    wort: "Sperre K2",
                    wert: (haus.zustand?.heatPump.blockContactOn ?? false) ? "zu" : "offen"
                )
            }
        }
    }

    private func ofenkarte(_ o: AnlageOfenOut) -> some View {
        Karte(kicker: "Pelletofen", titel: (o.running ?? false) ? "läuft" : "aus") {
            if o.present {
                VStack(spacing: 0) {
                    if let s = o.powerLevel {
                        Zeile(wort: "Stufe", wert: Formate.zahl(s, stellen: 0), farbe: Farbe.ofen)
                    }
                    if let w = o.waterKw {
                        Zeile(wort: "ins Wasser", wert: Formate.kw(w), einheit: "kW", farbe: Farbe.ofen)
                    }
                    Zeile(wort: "Vorlauf", wert: Formate.celsius(o.flowC, stellen: 1))
                    Zeile(wort: "Rücklauf", wert: Formate.celsius(o.returnC, stellen: 1))
                    if let p = o.pumpPct {
                        Zeile(wort: "Pumpe", wert: Formate.prozent(p > 1 ? p / 100 : p))
                    }
                }
            } else {
                Leer(satz: "Der Ofen meldet nicht.")
            }
        }
    }

    /// Die Heizkreise: wie viele offen sind.
    ///
    /// Das ist die Zahl, die zum Vorlauf gehoert. Ein hoher Vorlauf bei zwei offenen Kreisen von
    /// zehn heisst etwas anderes als bei zehn von zehn - im ersten Fall heizt die Anlage gegen
    /// geschlossene Ventile.
    private func heizkreis(_ h: AnlageHeizkreisOut) -> some View {
        Karte(kicker: "Heizkreise", titel: h.running ? "Pumpe läuft" : "Pumpe aus") {
            VStack(spacing: 0) {
                Zeile(
                    wort: "offen", wert: "\(h.roomsOpen) von \(h.roomsTotal)",
                    farbe: h.roomsOpen == 0 && h.running ? Farbe.achtung : Farbe.text1,
                    dazu: h.roomsOpen == 0 && h.running
                        ? "die Pumpe läuft gegen geschlossene Ventile" : nil
                )
                Zeile(wort: "Anteil", wert: Formate.prozent(h.openShare))
            }
        }
    }

    private func warmwasser(_ w: AnlageWarmwasserOut) -> some View {
        Karte(
            kicker: "Warmwasser",
            titel: (w.tapping ?? false) ? "wird gezapft" : "ruhig"
        ) {
            if w.present {
                VStack(spacing: 0) {
                    Zeile(wort: "Auslauf", wert: Formate.celsius(w.outletC, stellen: 1))
                    Zeile(wort: "Zulauf", wert: Formate.celsius(w.inletC, stellen: 1))
                    if let seit = w.tappingSince, let d = Zeit.ausIso(seit) {
                        Zeile(wort: "seit", wert: Formate.hhmm(d))
                    }
                }
            } else {
                Leer(satz: "Keine Warmwassermessung.")
            }
        }
    }

    private func lade() async {
        do {
            anlage = try await haus.api.anlage()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }

    /// Alle zehn Sekunden nachholen. Der Ereignisstrom traegt diese Antwort nicht - sie ist eine
    /// eigene Zusammenstellung des Dienstes.
    private func haltFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            if let a = try? await haus.api.anlage() { anlage = a }
        }
    }
}
