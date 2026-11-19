import DuckCurveKit
import SwiftUI

/// Anlage: der Augenblick der Wasser- und Stromseite in einer Antwort.
///
/// **Oben das Schema, darunter die Zahlen.** Hier stand, ein Schema auf 390 Punkten Breite sei
/// ein Gewirr und der Unterschied zur Gruppenansicht auf dem iPad kleiner, als er aussehe.
/// Beides war eine Ausrede fuer etwas, das ich nicht gebaut hatte: das Dashboard zeigt an
/// dieser Stelle eine Buehne, auf der man *sieht*, was fliesst - und genau deshalb heisst die
/// Seite Anlage und nicht Anlagenwerte. Gemeldet hat es der Nutzer, nicht der Arbeitsvorrat;
/// der fuehrte die Seite mit vier kleinen Punkten und setzte dabei voraus, es gebe ein Schema.
///
/// Das Bild steht in voller Groesse da und wird geschoben (Nutzerwunsch 17.11.2026). Die
/// Gruppen darunter bleiben: auf einem Telefon liest man eine Zahl schneller aus einer Zeile
/// als aus einer Zeichnung, und sie tragen Werte, die im Schema keinen Platz haben.
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
                Karte(kicker: "Die Anlage", titel: Anlagenschema.erzeugerSatz(a, jetzt: haus.jetzt)) {
                    Anlagenbild(anlage: a, jetzt: haus.jetzt)
                }
                lesehilfe
                strom(a.strom)
                speicher(a.speicher, stand: a.at)
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

    /// Die drei Bloecke unter dem Bild. **Zwei davon sind Inhalt und keine Bildbeschreibung:**
    /// wie die vier Kreise gebaut sind, und was gemessen und was gerechnet ist.
    private var lesehilfe: some View {
        VStack(alignment: .leading, spacing: 12) {
            Karte(kicker: "Lesen") {
                VStack(alignment: .leading, spacing: 6) {
                    satz(
                        "Das Licht wandert in Fliessrichtung. Je mehr Leistung, desto schneller und desto mehr Punkte; ein Rohr ohne Fluss steht still und ist duenn.")
                    satz(
                        "Die Farbe eines Rohrs ist die Temperatur seines Wassers, nach derselben Skala wie das Glas. Ruecklaeufe sind schmaler und blasser, damit die Schleife als Paar lesbar bleibt.")
                    satz(
                        "Ein Punkt an einer Pumpe heisst: sie laeuft. Beim Strom traegt jeder Lichtpunkt die Farbe seiner Quelle, im Verhaeltnis der Anteile.")
                }
            }
            Karte(kicker: "Vier getrennte Systeme") {
                VStack(alignment: .leading, spacing: 6) {
                    satz("Der Ofen speist ganz oben ein und holt unten zurueck.")
                    satz("Die Waermepumpe speist in der Mitte ein und holt unten zurueck.")
                    satz("Der Heizkreis nimmt aus der Mitte und gibt unten zurueck.")
                    satz(
                        "Das Trinkwasser laeuft unten kalt nach und wird ganz oben warm entnommen.")
                    satz(
                        "Ofen und Waermepumpe holen ihren Ruecklauf gemeinsam an der untersten Spitze - darum ist es dort ein Rohr und erst danach zwei.")
                }
            }
            Karte(kicker: "Gemessen und gerechnet") {
                VStack(alignment: .leading, spacing: 6) {
                    satz(
                        "Die Waerme der Waermepumpe wird nicht gemessen. Vorlauftemperatur und Arbeitszahl kommen von ihrem eigenen Bus; die Leistung ist daraus gerechnet.")
                    satz(
                        "Die Waerme des Ofens ist aus seiner Leistungsstufe nach Datenblatt geschaetzt.")
                    satz(
                        "Die Nettoleistung des Speichers kommt aus den vier Fuehlern ueber die letzte Viertelstunde.")
                    satz(
                        "Warmwasser wird am Anlegefuehler des Auslasses erkannt, nicht gemessen: es steht da, dass gezapft wird und seit wann, nicht wie viel.")
                }
            }
        }
    }

    private func satz(_ text: String) -> some View {
        Text(text)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    /// **`stand` kommt von der Antwort, nicht vom Fuehler.** `/anlage` liefert die vier
    /// Temperaturen als nackte Zahlen und einen Zeitstempel fuer die ganze Antwort; der
    /// Ereignisstrom liefert dieselben Werte als `Messwert` mit eigener Guete. `Pufferglas`
    /// zeichnet Messwerte, weil ein fehlender Fuehler anders aussehen muss als ein kalter -
    /// also werden die Zahlen hier dazu gemacht, mit dem einen Zeitstempel, den es gibt.
    private func speicher(_ s: AnlageSpeicherOut, stand: String) -> some View {
        let fuehler = Messwert.ausZahlen(s.tempsC, beobachtet: stand, quelle: "anlage")
        return Karte(kicker: "Pufferspeicher", titel: s.netWord) {
            HStack(alignment: .top, spacing: 16) {
                Pufferglas(
                    temperaturen: fuehler,
                    soc: s.soc,
                    zustand: Pufferzustand.aus(
                        fuehler: fuehler, jetzt: haus.jetzt,
                        laedt: (s.netKw ?? 0) > 0.1,
                        status: haus.zustand?.buffer.status
                    )
                )
                // Breit genug fuer Tank, Zahlen daneben und den Fuellstand.
                .frame(minWidth: 220, maxWidth: .infinity, minHeight: 210)
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
                    dazu: h.roomsOpen == 0 && h.running
                        ? "die Pumpe läuft gegen geschlossene Ventile" : nil,
                    farbe: h.roomsOpen == 0 && h.running ? Farbe.achtung : Farbe.text1
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
