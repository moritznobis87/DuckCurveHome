import DuckCurveKit
import SwiftUI

/// Der Regelkreis: die Kaskade von außen nach innen, mit der Herkunft jeder Zahl.
///
/// **Was hier anders ist als im Dashboard.** Dort steht ein Blockschaltbild von 1400 Punkten
/// Breite, in dem man Kästchen anklickt. Am Telefon ist dieselbe Zeichnung ein Ausschnitt, durch
/// den man schiebt - also steht hier die Kaskade als Liste: fünf Ebenen von der ökonomischen
/// Führung bis in den einzelnen Raum, je Block sein Übertragungsglied mit Kennbild, seine
/// Signale nach beiden Seiten und seine Parameter mit Schieber, Herkunft und Lernverlauf.
///
/// **Der Zweck der Seite ist die Herkunft.** Jede Zahl in dieser Anlage ist entweder gemessen,
/// geschätzt, angenommen, fest, aus dem Entwurf gerechnet oder von Hand übersteuert - und das
/// steht an ihr. Wo die Lernebene eine Schätzung **nicht** übernommen hat, steht der Grund
/// dabei; wo sie übernommen hat, steht die alte Zahl, die neue und das Datum im Protokoll. Das
/// ist die eigentliche Auskunft: man sieht, wie die Regelung sich über die Zeit auf dieses Haus
/// einstellt, und man sieht, wann sie es bleiben lässt.
///
/// **Jeder Parameter lässt sich übersteuern**, und zwar hier, nicht nur im Browser. Ein von Hand
/// gesetzter Wert wird nicht mehr überschrieben, bis er wieder freigegeben ist - das Blatt sagt
/// das, und die Plakette am Parameter zeigt es.
///
/// Gerechnet wird in dieser Datei nichts: Anteile, Sätze, Reserven und Kurven kommen aus
/// ``Regelkreisbild`` und aus dem Dienst.
struct RegelkreisSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var karte: RegelkreisOut?
    @State private var fehler: ApiFehler?
    @State private var laedtNeu = false

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            kopfkarte
            if let k = karte {
                let bild = Regelkreisbild.baue(k)
                Kachelfeld(
                    kacheln: Regelkreisbild.kacheln(k).map(Kacheldaten.init),
                    staffelung: Kachelraster(mittel: 2, breit: 4)
                )
                kreiskarte(bild)
                ForEach(bild.ebenen) { ebene in
                    ebenenkarte(ebene)
                }
                protokollkarte(bild)
                Methode(
                    [], kurz: "fünf Ebenen · SIMC-Entwurf · Übernahme nur mit Beleg",
                    titel: "Wie diese Karte zu lesen ist", punkte: Regelkreisbild.methode)
            }
        }
        .task { await lade() }
    }

    // MARK: - Kopf

    /// **Der Kopf steht immer**, auch ohne Daten - mit der Störung oder dem Ladesatz darin.
    /// Dasselbe Muster und dieselbe Begründung wie in ``WirkungSeite``: eine Seite, die beim
    /// Fehler ganz verschwindet, nimmt dem Benutzer auch den Weg zurück.
    @ViewBuilder private var kopfkarte: some View {
        Karte(
            kicker: "Der Regelkreis dieses Hauses",
            beiwerk: karte.map { k in
                Kartenhinweis.beiwerk(Regelkreisbild.baue(k).lernsatz, mono: true)
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "Fünf Ebenen, von der Kostenrechnung über 48 Stunden bis zum Stellantrieb "
                        + "am Verteiler. Jeder Block trägt sein Übertragungsglied, jede Zahl "
                        + "ihre Herkunft."
                )
                .font(Schrift.sans(schmal ? 15 : 16, relativeTo: .body))
                .foregroundStyle(Farbe.text2)
                .lineSpacing(4)
                .frame(maxWidth: 640, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                if let fehler {
                    Stoerung(fehler: fehler) { Task { await lade() } }
                } else if karte == nil {
                    Ladeente(satz: Regelkreisbild.laedtSatz)
                }
                if laedtNeu {
                    Text("wird neu geholt")
                        .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                herkunftslegende
            }
        }
    }

    /// Die Legende der sechs Herkünfte. **Sie gehört in den Kopf und nicht in eine Fußnote**:
    /// ohne sie sind die Farben an einunddreißig Schiebern Dekoration.
    private var herkunftslegende: some View {
        HStack(spacing: 12) {
            ForEach(Regelkreisbild.Herkunftston.allCases, id: \.self) { h in
                HStack(spacing: 4) {
                    Leuchte(farbe: Herkunftsfarbe.farbe(h), kante: 6)
                    Text(Regelkreisbild.herkunftWort(h))
                        .font(Schrift.mono(10.5))
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        // Sechs Wörter nebeneinander passen an der Wand, am Telefon nicht: dort wird geschoben,
        // statt sie zu brechen - gebrochen wäre aus der Legende eine zweite Tabelle geworden.
        .modifier(Querschieber(an: schmal))
    }

    // MARK: - Die Kreise

    /// Die fünf Kreise mit ihren Reserven. **Das ist die Karte, auf die der Regelungstechniker
    /// zuerst sieht**: Phasenreserve, Amplitudenreserve, Periode - und der Satz für die zwei
    /// Kreise, die keine Frequenzkennlinie haben.
    @ViewBuilder private func kreiskarte(_ bild: Regelkreisbild) -> some View {
        Karte(
            kicker: "Die fünf Kreise",
            beiwerk: Kartenhinweis.beiwerk("Faustregel: 45° Phase, Faktor 2,5", mono: true)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(bild.kreise.enumerated()), id: \.element.id) { nr, kreis in
                    if nr > 0 {
                        Rectangle().fill(Farbe.linie1).frame(height: 1)
                    }
                    Kreiszeileansicht(kreis: kreis, schmal: schmal)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Die Ebenen

    @ViewBuilder private func ebenenkarte(_ ebene: Regelkreisbild.Ebenengruppe) -> some View {
        Karte(
            kicker: "Ebene \(ebene.id) · \(ebene.titel)",
            beiwerk: Kartenhinweis.beiwerk(ebene.takt, mono: true)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ebene.bloecke.enumerated()), id: \.element.id) { nr, block in
                    if nr > 0 {
                        Rectangle().fill(Farbe.linie1).frame(height: 1)
                    }
                    Blockansicht(block: block, schmal: schmal, karte: $karte)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: - Das Protokoll

    /// Was die Lernebene bisher übernommen hat, jüngstes zuerst.
    @ViewBuilder private func protokollkarte(_ bild: Regelkreisbild) -> some View {
        Karte(
            kicker: "Lernprotokoll",
            beiwerk: Kartenhinweis.beiwerk(
                bild.protokoll.isEmpty
                    ? "noch keine Übernahme"
                    : "\(bild.protokoll.count) Übernahmen", mono: true)
        ) {
            if bild.protokoll.isEmpty {
                Text(
                    "Noch hat keine Schätzung einen Parameter ersetzt. Das ist der erwartete "
                        + "Zustand in den ersten zwei Wochen: vorher reichen die Daten nicht, "
                        + "und eine Übernahme ohne Beleg wäre Raten mit mehr Schritten."
                )
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(bild.protokoll.prefix(40)) { zeile in
                        protokollzeile(zeile)
                    }
                }
            }
        }
    }

    private func protokollzeile(_ z: Regelkreisbild.Protokollzeile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(z.wann)
                    .font(Schrift.mono(10.5))
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                Text(z.name)
                    .font(Schrift.sans(13))
                    .foregroundStyle(Farbe.text2)
                Spacer(minLength: 4)
                Text(z.aenderung)
                    .font(Schrift.mono(12, relativeTo: .caption))
                    .foregroundStyle(Farbe.amber)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(z.grund)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
                if let guete = z.guete {
                    Text("· " + guete)
                        .font(Schrift.mono(10))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    // MARK: - Holen und Stellen

    private func lade() async {
        laedtNeu = karte != nil
        defer { laedtNeu = false }
        do {
            karte = try await haus.api.regelkreis()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

// MARK: - Eine Kreiszeile

/// Ein Kreis: Regelgröße, Stellgröße, Entwurf - und rechts die beiden Instrumente.
private struct Kreiszeileansicht: View {
    let kreis: Regelkreisbild.Kreiszeile
    let schmal: Bool

    @State private var offen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if schmal {
                kopf
                instrumente
            } else {
                HStack(alignment: .top, spacing: 20) {
                    kopf
                    Spacer(minLength: 8)
                    instrumente
                }
            }
            if !kreis.erklaerung.isEmpty {
                DisclosureGroup(isExpanded: $offen) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(kreis.erklaerung.enumerated()), id: \.offset) { _, satz in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                                Text(satz)
                                    .font(Schrift.winzig)
                                    .foregroundStyle(Farbe.text3)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Warum dieser Kreis so entworfen ist")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(Farbe.text3)
            }
        }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(kreis.id)
                    .font(Schrift.mono(13, relativeTo: .body))
                    .foregroundStyle(Farbe.amber)
                Text(kreis.name)
                    .font(Schrift.sans(15, relativeTo: .body))
                    .foregroundStyle(Farbe.text1)
                Plakette(wort: kreis.art)
            }
            Text("\(kreis.regelgroesse) ← \(kreis.stellgroesse) · Takt \(kreis.takt)")
                .font(Schrift.mono(11))
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            if let strecke = kreis.strecke {
                Text("Strecke: " + strecke)
                    .font(Schrift.mono(11))
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let entwurf = kreis.entwurf {
                Text("Regler: " + entwurf)
                    .font(Schrift.mono(11))
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let hysterese = kreis.hysterese {
                Text("Schaltdifferenz: " + hysterese)
                    .font(Schrift.mono(11))
                    .foregroundStyle(Farbe.text2)
            }
            if let hinweis = kreis.hinweis {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Leuchte(
                        farbe: kreis.bewertbar
                            ? Reservefarbe.farbe(kreis.phasenFeld) : Farbe.text3,
                        kante: 6)
                    Text(hinweis)
                        .font(Schrift.winzig)
                        .foregroundStyle(kreis.bewertbar && !kreis.gut ? Farbe.alarm : Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Links der Zeiger für die Phase, rechts der Pegel für die Amplitude. **Wo es keine
    /// Reserven gibt, stehen auch keine Instrumente**: ein Zeiger auf null wäre die Aussage
    /// „null Grad“, und das ist falsch - richtig ist „nicht in Grad zu beantworten“.
    @ViewBuilder private var instrumente: some View {
        if kreis.bewertbar {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(spacing: 3) {
                    Rundinstrument(
                        anteil: kreis.phasenAnteil,
                        zahl: kreis.phasenreserve,
                        felder: [
                            .init(bis: 45.0 / 90.0, farbe: Farbe.alarm),
                            .init(bis: 60.0 / 90.0, farbe: Farbe.amber),
                            .init(bis: 1.0, farbe: Farbe.mist),
                        ],
                        titel: "Phasenreserve \(kreis.id)"
                    )
                    Text("Phase")
                        .font(Schrift.mono(9.5)).foregroundStyle(Farbe.text3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Pegel(
                        anteil: kreis.amplitudenAnteil ?? 0,
                        schwelle: (2.5 - 1.0) / 5.0,
                        farbe: Reservefarbe.farbe(kreis.amplitudenFeld),
                        laenge: 84,
                        titel: "Amplitudenreserve \(kreis.id)",
                        zahl: kreis.amplitudenreserve
                    )
                    Text("Amplitude · Periode \(kreis.periode)")
                        .font(Schrift.mono(9.5)).foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

// MARK: - Ein Block

/// Ein Block der Kaskade: Kennbild, Name, Rolle, Übertragungsfunktion - und darunter seine
/// Parameter und Signale.
private struct Blockansicht: View {
    let block: Regelkreisbild.Blockzeile
    let schmal: Bool
    /// **Die ganze Karte als Bindung, nicht zwei Rückrufe.** Eine Übersteuerung bringt vom
    /// Dienst die vollständige Karte zurück - der Parameter, an dem getippt wurde, schreibt
    /// sie hierher, und die Seite zeichnet sich neu. Mit Rückrufen durch zwei Ebenen wären es
    /// zwei asynchrone Funktionswerte in einer Ansicht, und die Seite müsste sie halten,
    /// obwohl sie die eingegebene Zahl nie sieht.
    @Binding var karte: RegelkreisOut?

    @State private var offen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            kopf
            if !block.parameter.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(block.parameter) { p in
                        Parameterblock(zeile: p, karte: $karte)
                    }
                }
            }
            DisclosureGroup(isExpanded: $offen) {
                VStack(alignment: .leading, spacing: 8) {
                    saetze
                    gleichungen
                    signale
                }
                .padding(.top, 8)
            } label: {
                Text("Was dieser Block tut, und woran er hängt")
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(Farbe.text3)
        }
    }

    private var kopf: some View {
        HStack(alignment: .top, spacing: 10) {
            if let glied = block.glied {
                VStack(spacing: 2) {
                    Kennbild(glied: glied, farbe: kennfarbe)
                    Text(glied.kurz)
                        .font(Schrift.mono(9.5))
                        .foregroundStyle(Farbe.text3)
                        .lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(block.name)
                        .font(Schrift.sans(15, relativeTo: .body))
                        .foregroundStyle(Farbe.text1)
                        .fixedSize(horizontal: false, vertical: true)
                    if let kreis = block.kreis {
                        Plakette(wort: kreis, ton: .amber)
                    }
                }
                HStack(spacing: 6) {
                    Text(block.rolle)
                        .font(Schrift.mono(10.5))
                        .foregroundStyle(Farbe.text3)
                    if let glied = block.glied {
                        Text("· " + glied.name)
                            .font(Schrift.mono(10.5))
                            .foregroundStyle(Farbe.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let glied = block.glied {
                    Text(glied.gS)
                        .font(Schrift.mono(11.5, relativeTo: .caption))
                        .foregroundStyle(Farbe.mist)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let behandlung = block.behandlung {
                    Text("Behandlung: " + behandlung)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
                // **Das Glied des Entwurfs steht dabei, wo es ein anderes ist.** Der
                // Pufferlade-Regler ist ausgeführt als Zweipunktregler, entworfen ist er als
                // PI - und wer die Nachstellzeit im Parameter sieht, muss wissen, woher sie
                // kommt.
                if let entwurf = block.gliedEntwurf, entwurf.id != block.glied?.id {
                    HStack(spacing: 6) {
                        Kennbild(
                            glied: entwurf, breite: 34, hoehe: 22, farbe: Farbe.mist)
                        Text("entworfen als \(entwurf.name) · \(entwurf.gS)")
                            .font(Schrift.mono(10))
                            .foregroundStyle(Farbe.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Eine Störgröße ist nicht gestellt, sie kommt - und bekommt darum die Farbe des Hauses,
    /// nicht die der Regelung.
    private var kennfarbe: Color {
        block.stoergroesse ? Farbe.mist : Farbe.amber
    }

    @ViewBuilder private var saetze: some View {
        if !block.erklaerung.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(block.erklaerung.enumerated()), id: \.offset) { _, satz in
                    Text(satz)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text2)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let quelle = block.quelle {
                    Text("Quelle: " + quelle)
                        .font(Schrift.mono(10))
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder private var gleichungen: some View {
        if !block.gleichungen.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(block.gleichungen.enumerated()), id: \.offset) { _, zeile in
                    Text(zeile)
                        .font(Schrift.mono(11))
                        .foregroundStyle(Farbe.text1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche3.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous))
        }
    }

    /// Die Signale mit ihrem Vorzeichen. **An einer Summierstelle ist das Vorzeichen die ganze
    /// Auskunft**: ein Minus macht aus einer Kette einen Regelkreis.
    @ViewBuilder private var signale: some View {
        if !block.signale.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(block.signale) { s in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(s.vorzeichen ?? (s.hinein ? "→" : "←"))
                            .font(Schrift.mono(11, relativeTo: .caption))
                            .foregroundStyle(
                                s.vorzeichen == "−" ? Farbe.alarm : Farbe.text3)
                            .frame(width: 12, alignment: .center)
                        Text(s.name)
                            .font(Schrift.mono(10.5))
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text((s.hinein ? "von " : "nach ") + s.gegenueber)
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// MARK: - Ein Parameter

/// Ein Parameter: Schieber, Herkunft, und aufgeklappt das ganze Blatt dahinter.
///
/// **Aufgeklappt steht hier, was die Seite trägt**: welche Schätzung vorliegt, mit welcher
/// Unsicherheit und aus wie vielen Stützstellen, nach welchem Verfahren sie entsteht, warum der
/// alte Wert noch gilt oder wann er ersetzt wurde - und das Eingabefeld, mit dem man die
/// Lernebene überstimmt.
private struct Parameterblock: View {
    let zeile: Regelkreisbild.Parameterzeile
    @Binding var karte: RegelkreisOut?

    @State private var offen = false
    @State private var entwurf = ""
    @State private var laeuft = false
    @State private var meldung: String?
    @FocusState private var imFeld: Bool

    @Environment(Hauszustand.self) private var haus

    var body: some View {
        DisclosureGroup(isExpanded: $offen) {
            blatt.padding(.top, 10)
        } label: {
            kopf
        }
        .tint(Farbe.text3)
        .onChange(of: offen) { _, jetzt in
            // Das Feld beginnt beim geltenden Wert: wer übersteuert, will meist eine Zahl in
            // seiner Nähe, und ein leeres Feld verlangt, den Wert von oben abzuschreiben.
            if jetzt, entwurf.isEmpty {
                entwurf = Formate.zahl(zeile.zahl, stellen: zeile.stellen)
            }
        }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(zeile.symbol)
                    .font(Schrift.mono(12.5, relativeTo: .caption))
                    .foregroundStyle(Farbe.text1)
                Text(zeile.name)
                    .font(Schrift.sans(13))
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text(zeile.wert)
                    .font(Schrift.mono(13, relativeTo: .body))
                    .foregroundStyle(Herkunftsfarbe.farbe(zeile.herkunft))
                    .lineLimit(1)
            }
            Parameterschieber(zeile: zeile)
            HStack(spacing: 6) {
                Plakette(wort: zeile.herkunftWort, ton: Herkunftsfarbe.ton(zeile.herkunft))
                if zeile.stuetzstellen > 0 {
                    Text("n = \(zeile.stuetzstellen)")
                        .font(Schrift.mono(10))
                        .foregroundStyle(Farbe.text3)
                }
                if zeile.pruefsatz != nil {
                    Text("Übernahme abgelehnt")
                        .font(Schrift.mono(10))
                        .foregroundStyle(Farbe.amber)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder private var blatt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(zeile.warum)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            zeilen
            if zeile.lernbar {
                verlauf
            }
            if let satz = zeile.pruefsatz {
                hinweiszeile(satz, farbe: Farbe.amber)
            }
            if !zeile.protokoll.isEmpty {
                protokoll
            }
            stellzeile
        }
    }

    /// Die harten Angaben als Wort-Wert-Paare. **Das Verfahren steht dabei**, weil „geschätzt“
    /// ohne „wie“ keine Auskunft ist: eine Ausgleichsrechnung über dreißig Tage und ein
    /// rekursiver Schätzer mit Vergessensfaktor sind zwei verschiedene Versprechen.
    private var zeilen: some View {
        VStack(alignment: .leading, spacing: 4) {
            paar("Verfahren", zeile.verfahren)
            if let satz = zeile.schaetzsatz {
                paar("Letzte Schätzung", satz)
            } else if zeile.lernbar {
                paar("Letzte Schätzung", "noch keine")
            }
            paar("Plausibel zwischen", "\(zeile.unten) und \(zeile.oben) \(zeile.einheit)")
            if let quelle = zeile.quelle {
                paar("Quelle", quelle)
            }
        }
    }

    private func paar(_ wort: String, _ wert: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(wort)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .frame(width: 118, alignment: .leading)
            Text(wert)
                .font(Schrift.mono(11))
                .foregroundStyle(Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var verlauf: some View {
        VStack(alignment: .leading, spacing: 4) {
            Kicker(wort: "Wie die Schätzung einläuft")
            Lernverlauf(punkte: zeile.verlauf, geltend: zeile.zahl)
        }
    }

    private func hinweiszeile(_ satz: String, farbe: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Leuchte(farbe: farbe, kante: 6)
            Text(satz)
                .font(Schrift.winzig)
                .foregroundStyle(farbe)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var protokoll: some View {
        VStack(alignment: .leading, spacing: 4) {
            Kicker(wort: "Übernahmen")
            ForEach(zeile.protokoll) { u in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(u.wann)
                            .font(Schrift.mono(10))
                            .foregroundStyle(Farbe.text3)
                        Text(u.aenderung)
                            .font(Schrift.mono(11))
                            .foregroundStyle(Farbe.amber)
                        Spacer(minLength: 0)
                    }
                    Text(u.guete.map { u.grund + " · " + $0 } ?? u.grund)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Übersteuern

    /// Feld, Knopf, Freigabe - und der Satz, was eine Übersteuerung bedeutet.
    @ViewBuilder private var stellzeile: some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: "Eigenen Wert setzen")
            Text(
                zeile.uebersteuert
                    ? "Dieser Wert ist von Hand gesetzt. Die Lernebene lässt ihn in Ruhe, "
                        + "solange er nicht freigegeben ist."
                    : "Ein eigener Wert gilt sofort und wird nicht mehr überschrieben, bis er "
                        + "freigegeben ist. Der Entwurf aller Kreise, in denen die Größe "
                        + "vorkommt, wird damit neu gerechnet."
            )
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                feld
                Text(zeile.einheit)
                    .font(Schrift.mono(11))
                    .foregroundStyle(Farbe.text3)
                    .frame(width: 44, alignment: .leading)
                knopf
                if zeile.uebersteuert {
                    freigabeknopf
                }
                Spacer(minLength: 0)
            }
            if let meldung {
                Text(meldung)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.alarm)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var feld: some View {
        TextField("", text: $entwurf)
            .font(Schrift.mono(13))
            .multilineTextAlignment(.trailing)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.plain)
            .focused($imFeld)
            .frame(width: 96)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Farbe.flaeche3)
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
                    .strokeBorder(imFeld ? Farbe.amber : Farbe.linie2, lineWidth: 1)
            }
            .disabled(!haus.darfSchalten || laeuft)
    }

    private var knopf: some View {
        Button {
            Task { await uebernimm() }
        } label: {
            Text(laeuft ? "…" : "Setzen")
                .font(Schrift.sans(13))
                .foregroundStyle(Farbe.petrol)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Farbe.amber)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(laeuft || !haus.darfSchalten)
        .opacity(laeuft ? 0.6 : (haus.darfSchalten ? 1 : 0.4))
    }

    private var freigabeknopf: some View {
        Button {
            Task { await gibFrei() }
        } label: {
            Text("Freigeben")
                .font(Schrift.sans(13))
                .foregroundStyle(Farbe.text2)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .overlay {
                    RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(laeuft || !haus.darfSchalten)
        .opacity(laeuft ? 0.6 : (haus.darfSchalten ? 1 : 0.4))
    }

    /// **Das Komma wird zum Punkt, und was dann keine Zahl ist, geht nicht ans Netz.** Die
    /// Tastatur des Geräts liefert ein deutsches Komma; `Double("2,4")` ist `nil`. Ohne diese
    /// Zeile wäre jede Eingabe mit Komma eine stumme Ablehnung.
    ///
    /// **Und das echte Minuszeichen wird zum Bindestrich.** Das Feld füllt sich beim Aufklappen
    /// mit ``Formate/zahl(_:stellen:)``, und die setzt U+2212 (``Formate/minus``) - typografisch
    /// richtig, aber `Double("−4.5")` ist `nil`. Ein negativer Parameter wäre damit ohne
    /// Zutun des Benutzers unsetzbar gewesen: aufklappen, „Setzen", „Das ist keine Zahl".
    private func uebernimm() async {
        let roh = entwurf
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: Formate.minus, with: "-")
            .trimmingCharacters(in: .whitespaces)
        guard let wert = Double(roh) else {
            meldung = "Das ist keine Zahl."
            return
        }
        laeuft = true
        defer { laeuft = false }
        do {
            // **Die Antwort ist die ganze Karte**, weil eine übersteuerte Zeitkonstante die
            // Nachstellzeit und damit die Reserven jedes Kreises verschiebt, in dem sie
            // vorkommt. Selbst nachzurechnen wäre eine zweite Wahrheit.
            karte = try await haus.api.stelleRegelkreis(zeile.id, wert: wert)
            meldung = nil
            imFeld = false
        } catch let f as ApiFehler {
            meldung = f.rat
        } catch {
            meldung = error.localizedDescription
        }
    }

    private func gibFrei() async {
        laeuft = true
        defer { laeuft = false }
        do {
            karte = try await haus.api.gibRegelkreisFrei(zeile.id)
            meldung = nil
        } catch let f as ApiFehler {
            meldung = f.rat
        } catch {
            meldung = error.localizedDescription
        }
    }
}

// MARK: - Querschieber

/// Eine Zeile, die am Telefon geschoben wird und am iPad einfach dasteht.
///
/// **Warum als Modifikator und nicht zweimal geschrieben.** Ein `ScrollView` um eine Zeile
/// herum ändert deren Breitenverhalten: innerhalb schrumpft sie auf ihren Inhalt. Beide
/// Fassungen im Code zu halten, hieße dieselbe Legende zweimal zu schreiben.
private struct Querschieber: ViewModifier {
    let an: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if an {
            ScrollView(.horizontal, showsIndicators: false) { content }
        } else {
            content
        }
    }
}
