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
///
/// **Die Zeichnung steht auf einer Buehne und nicht in einer Karte** (``Anlagenbuehne``). Hier
/// stand `Karte(kicker: "Die Anlage", titel: erzeugerSatz(…))` - zwei Dinge auf einmal falsch:
/// die Karte ist heller als der Grund, fuer den die Deckungen der Zeichnung gerechnet sind, und
/// der Erzeugersatz stand als Kartentitel, wo die Vorlage ihn in die Kopfzeile setzt, zwischen
/// Aussentemperatur und Strommischung (`Anlage.tsx:62-75`).
struct AnlageSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite
    @Environment(\.scenePhase) private var lage

    @State private var anlage: AnlageOut?
    @State private var fehler: ApiFehler?

    private var schmal: Bool { breite == .compact }

    /// Die Reihenfolge der Vorlage: Kicker, Satz, Fehler, Bühne, Fuß - und erst danach die
    /// Zahlengruppen, die nur die App hat (`Anlage.tsx:59-126`).
    ///
    /// **Der Fuß steht auch ohne Daten da.** Die Vorlage hält ihn außerhalb der Abfrage: wer die
    /// Seite zum ersten Mal öffnet und auf die Bühne wartet, kann schon lesen, was er dann
    /// sehen wird.
    var body: some View {
        Seite {
            if !schmal {
                // Am Telefon blendet die Vorlage den Bereichskicker aus (`AreaNav.tsx:96`).
                Kicker(wort: Anlagenworte.bereichskicker)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            kopf
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let a = anlage {
                Anlagenbuehne {
                    Anlagenbild(anlage: a, jetzt: haus.jetzt)
                }
            } else {
                Anlagenwarten(fehler: fehler != nil)
            }
            fuss
            if let a = anlage {
                strom(a.strom)
                speicher(a.speicher, stand: a.at)
                waermepumpe(a.waermepumpe)
                ofenkarte(a.ofen)
                heizkreis(a.heizkreis)
                warmwasser(a.warmwasser)
            }
        }
        .task { await lade() }
        .task { await haltFrisch() }
        // Das Gegenstück zu `visibilitychange` (`Anlage.tsx:48-52`): wer die App nach einer
        // Stunde wieder aufklappt, soll keinen Stand von vor einer Stunde sehen.
        .onChange(of: lage) { _, neu in
            if neu == .active { Task { await lade() } }
        }
    }

    // MARK: - Der Kopf: ein Satz und der Stand

    /// Die Kopfzeile der Vorlage (`Anlage.tsx:62-75`, `globals.css:560-563`).
    ///
    /// **Ein Satz und keine zwei Beschriftungen.** Hier standen links der Stand und rechts die
    /// Außentemperatur, beide winzig und gleich laut - und dazwischen fehlte das, was die Seite
    /// zu sagen hat: wer Wärme macht und woher der Strom dafür kommt. Die Vorlage schreibt es
    /// als einen Satz, in dem nur der Erzeuger fett steht.
    ///
    /// **Ohne Daten steht dort „Anlage“** (`Anlage.tsx:71`) und kein Stand: eine Uhrzeit, die
    /// zu keiner Antwort gehört, wäre eine Behauptung.
    @ViewBuilder private var kopf: some View {
        let teile = anlage.map { Anlagenworte.kopfteile($0, jetzt: haus.jetzt) }
        // `.anlage-kopf` ist `flex-wrap` mit `space-between`: passt der Stand nicht mehr neben
        // den Satz, rutscht er darunter. Entschieden wird nach Breitenklasse und nicht mit
        // `ViewThatFits` - das wählt nach Höhe, und ein umbrechender Satz „passt“ immer.
        if schmal {
            VStack(alignment: .leading, spacing: 6) {
                kopfsatz(teile)
                if let a = anlage { stand(a.at) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                kopfsatz(teile)
                Spacer(minLength: 8)
                if let a = anlage { stand(a.at) }
            }
        }
    }

    /// Der Satz links: 15 Punkte in ``Farbe/text2``, der Erzeuger fett in ``Farbe/text1``.
    ///
    /// Zusammengesetzt aus ``Text``-Stücken und nicht aus einem `AttributedString`: so bleibt
    /// jede Schrift eine Hausschrift aus ``Schrift`` und der Umbruch Sache von SwiftUI.
    /// Die Vorlage setzt 300 für den Satz und 500 für das `<b>`; IBM Plex gibt es im Haus nur
    /// in 400 und 600, also stehen hier ``Schrift/sans(_:relativeTo:)`` und ``Schrift/karte``.
    private func kopfsatz(_ teile: Anlagenworte.Kopfteile?) -> some View {
        var zeile = Text("")
        var ansage = "Anlage"
        if let teile {
            ansage = teile.ganz
            if let draussen = teile.draussen {
                zeile = zeile + leicht("\(draussen) · ")
            }
            zeile = zeile + Text(teile.satz).font(Schrift.karte).foregroundStyle(Farbe.text1)
            if let mischung = teile.mischung {
                zeile = zeile + leicht(" · \(mischung)")
            }
        } else {
            zeile = zeile + leicht(ansage)
        }
        return zeile
            .font(Schrift.sans(15))
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(ansage)
    }

    private func leicht(_ text: String) -> Text {
        Text(text).font(Schrift.sans(15)).foregroundStyle(Farbe.text2)
    }

    /// „Stand 18:04 · alle 20 s“ - der Takt steht im Text, damit ablesbar ist, wie alt eine
    /// Zahl höchstens sein kann.
    private func stand(_ at: String) -> some View {
        Text(Anlagenworte.standzeile(at: at))
            .font(Schrift.sans(12))
            .foregroundStyle(Farbe.text3)
            .lineLimit(1)
    }

    // MARK: - Der Fuß: drei Spalten Lesehilfe

    /// Die Lesehilfe als dreispaltiger Fuß (`Anlage.tsx:91-124`, `globals.css:591-595`).
    ///
    /// **Keine Karten.** Drei Karten machen aus drei Spalten Lesehilfe drei Abschnitte, die
    /// genauso laut sind wie die Zahlengruppen darunter; die Vorlage setzt sie als Fuß ohne
    /// Fläche und ohne Rand, in drei Spalten von mindestens 260 Punkten. Am Telefon ist es
    /// eine Spalte ohne Polster (`handy.css:401`).
    private var fuss: some View {
        LazyVGrid(columns: spalten, alignment: .leading, spacing: 12) {
            ForEach(Anlagenworte.fussspalten) { stueck in
                VStack(alignment: .leading, spacing: 4) {
                    fusstitel(stueck.titel)
                    absatz(stueck)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(schmal ? EdgeInsets() : EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8))
    }

    /// Die Überschrift einer Spalte: 12 Punkte, gesperrt, Großbuchstaben, ``Farbe/text3``.
    ///
    /// **Nicht ``Kicker``.** Der Kicker der App trägt `var(--text-kicker)` und ist damit die
    /// Sperrschrift über einer *Karte* - richtig für den Bereichskicker oben, falsch hier: der
    /// Fuß setzt seine `h2` ausdrücklich in `var(--text-3)` (`globals.css:593`), weil drei
    /// Überschriften in Markenfarbe unter der Bühne lauter wären als die Bühne.
    private func fusstitel(_ wort: String) -> some View {
        Text(wort.uppercased())
            .font(Schrift.sans(12))
            .tracking(1.2)
            .foregroundStyle(Farbe.text3)
    }

    /// `repeat(auto-fit, minmax(260px, 1fr))` am Schirm, eine Spalte am Telefon.
    private var spalten: [GridItem] {
        schmal
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 260), spacing: 28)]
    }

    /// Ein Absatz mit hervorgehobenen Begriffen (`.anlage-fuss .m`, `globals.css:595`).
    ///
    /// Die Stücke und ihre Fugen kommen aus dem Kern (``Anlagenworte/fussspalten``), weil eine
    /// Fuge mitten in einem Satz in einer `View` nicht zu prüfen wäre.
    private func absatz(_ stueck: Anlagenworte.Lesestueck) -> some View {
        var zeile = Text("")
        for teil in stueck.stuecke {
            zeile =
                zeile
                + Text(teil.text)
                    .font(Schrift.sans(13.5))
                    .foregroundStyle(teil.betont ? Farbe.text1 : Farbe.text2)
        }
        return zeile
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(stueck.text)
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

    /// Alle zwanzig Sekunden nachholen, und nur im Vordergrund.
    ///
    /// Der Ereignisstrom traegt diese Antwort nicht - sie ist eine eigene Zusammenstellung des
    /// Dienstes. **Zwanzig und nicht zehn** (``Anlagenworte/taktSekunden``): die Pufferfuehler
    /// melden minuetlich, und eine Zahl, die sich oefter aendert als ihre Quelle, luegt mit der
    /// Nachkommastelle (`Anlage.tsx:14-16`). Im Hintergrund wird nichts geholt - das Gegenstueck
    /// zu `document.visibilityState === "visible"` (`Anlage.tsx:46`); nachgeholt wird beim
    /// Zurueckkommen, in `onChange(of: lage)`.
    private func haltFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Anlagenworte.taktSekunden))
            guard !Task.isCancelled else { return }
            guard lage == .active else { continue }
            if let a = try? await haus.api.anlage() { anlage = a }
        }
    }
}
