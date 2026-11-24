import Foundation

/// Die Regelkreis-Karte für die App: geordnet, benannt, und mit den Wörtern versehen.
///
/// **Die Karte selbst zeichnet ``Schaltbild``** mit der Geometrie des Dashboards (Vorgabe des
/// Hausherrn vom 24.11.2026: überall das Blockschaltbild, keine Liste). Dieser Typ trägt, was
/// unter der Karte steht: zu jedem Block sein Blatt mit Übertragungsglied, Parametern samt
/// Herkunft und Signalen nach beiden Seiten, geordnet nach den fünf Ebenen. Die Summierstellen
/// stehen mit darin, mit dem Vorzeichen an jedem Eingang: sie sind die Stelle, an der ein
/// Regelkreis zum Regelkreis wird.
///
/// **Gerechnet wird hier nichts.** Die Reserven kommen fertig aus `/regelkreis`, die Kennbilder
/// als Kurven, die Sätze aus dem Kern des Dienstes. Dieser Typ ordnet, gruppiert und schreibt
/// die Wörter dazu - dieselbe Arbeitsteilung wie bei ``Wirkungsbild``.
public struct Regelkreisbild: Sendable, Hashable {

    // MARK: - Teile

    /// Woher der Wert eines Parameters stammt. Dieselbe Reihenfolge der Verbindlichkeit wie im
    /// Dienst; die Ansicht macht daraus Farben und entscheidet nichts.
    public enum Herkunftston: String, Sendable, Hashable, CaseIterable {
        case gemessen
        case geschaetzt
        case annahme
        case fest
        case entwurf
        case uebersteuert
    }

    /// Ein Parameter, fertig zum Anzeigen - samt allem, was das Blatt dahinter braucht.
    public struct Parameterzeile: Sendable, Hashable, Identifiable {
        public let id: String
        public let symbol: String
        public let name: String
        public let einheit: String
        public let stellen: Int
        /// Der geltende Wert als Zahl - für das Eingabefeld der Übersteuerung.
        public let zahl: Double
        /// Wert mit Einheit, so wie er dasteht.
        public let wert: String
        /// Wo der Wert zwischen seinen Plausibilitätsgrenzen liegt, 0 bis 1.
        public let anteil: Double
        /// Wo der Startwert liegt, 0 bis 1 - die Marke, von der aus gelernt wurde.
        public let startAnteil: Double
        /// Die halbe Breite des Unsicherheitsbands, in derselben Einheit wie ``anteil``.
        public let sigmaAnteil: Double
        public let herkunft: Herkunftston
        public let herkunftWort: String
        /// Untere und obere Grenze, für die Beschriftung des Schiebers.
        public let unten: String
        public let oben: String
        /// „12,3 ± 1,4 · n = 58“, wo eine Schätzung vorliegt.
        public let schaetzsatz: String?
        /// Was die Lernebene zuletzt entschieden hat, wenn sie **abgelehnt** hat - der Satz,
        /// der sagt, warum noch der alte Wert gilt.
        public let pruefsatz: String?
        public let warum: String
        public let quelle: String?
        public let verfahren: String
        public let lernbar: Bool
        public let stuetzstellen: Int
        /// Der Weg der Schätzung über die Zeit, roh aus dem Dienst.
        public let verlauf: [Messpunkt]
        /// Die Übernahmen dieses Parameters, jüngste zuerst.
        public let protokoll: [Protokollzeile]

        public var uebersteuert: Bool { herkunft == .uebersteuert }
    }

    /// Ein Signal von oder zu einem Block.
    public struct Signal: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        /// Der Block am anderen Ende, mit seinem Namen.
        public let gegenueber: String
        public let hinein: Bool
        /// „+“ oder „−“ an einer Summierstelle, sonst leer.
        public let vorzeichen: String?
        /// Eine Störgröße, eine Rückführung, ein gewöhnliches Signal.
        public let art: String
    }

    /// Ein Block der Kaskade.
    public struct Blockzeile: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let rolle: String
        public let kurz: String
        public let kreis: String?
        public let erklaerung: [String]
        public let gleichungen: [String]
        /// Die Behandlung einer Störgröße - aufgeschaltet, ausgeregelt, beobachtet.
        public let behandlung: String?
        public let quelle: String?
        /// Das Übertragungsglied samt Kennbild, wenn der Block eines ist.
        public let glied: GliedAnsicht?
        /// Das Glied des Entwurfs, wo es von der Ausführung abweicht.
        public let gliedEntwurf: GliedAnsicht?
        public let parameter: [Parameterzeile]
        public let signale: [Signal]

        /// Eine Störgröße: sie wird nicht gestellt, sie kommt.
        public var stoergroesse: Bool { rolle == "Störgröße" }
    }

    /// Eine Ebene der Kaskade mit ihren Blöcken.
    public struct Ebenengruppe: Sendable, Hashable, Identifiable {
        public let id: Int
        public let titel: String
        public let takt: String
        public let bloecke: [Blockzeile]
    }

    /// Ein Kreis mit seinen Reserven.
    public struct Kreiszeile: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let regelgroesse: String
        public let stellgroesse: String
        public let reglerBlock: String
        public let art: String
        public let takt: String
        public let erklaerung: [String]
        /// Der Entwurf: „SIMC · Kp = 2,4 · Tn = 48 min“, wo es einen gibt.
        public let entwurf: String?
        /// Die Strecke: „PT1 mit Totzeit · K = 1,8 · T₁ = 42 min · Tt = 9 min“.
        public let strecke: String?
        public let phasenreserve: String
        public let amplitudenreserve: String
        public let periode: String
        /// Phasenreserve auf 0…90° abgebildet, für das Rundinstrument.
        public let phasenAnteil: Double?
        /// Amplitudenreserve auf 1…6 abgebildet, für den Pegel.
        public let amplitudenAnteil: Double?
        /// In welchem Feld die beiden Reserven liegen - die Ansicht macht daraus Farben.
        public let phasenFeld: Reservefeld
        public let amplitudenFeld: Reservefeld
        /// Die Frequenzkennlinie des offenen Kreises, roh aus dem Dienst: je Punkt die
        /// Kreisfrequenz in rad/min, der Betrag in dB und die Phase in Grad.
        public let kennlinie: [KennliniePunkt]
        /// Die Durchtrittsfrequenz in rad/min - die Marke im Bild.
        public let durchtritt: Double?
        public let gut: Bool
        public let bewertbar: Bool
        /// Die Schaltdifferenz des Zweipunktreglers, wo es eine gibt.
        public let hysterese: String?
        /// Der Satz, der dasteht, wenn eine Reserve zu klein ist oder der Kreis nicht stetig ist.
        public let hinweis: String?
    }

    /// Eine Übernahme im Protokoll.
    public struct Protokollzeile: Sendable, Hashable, Identifiable {
        public let id: String
        /// Der rohe Zeitstempel, wie er aus dem Dienst kommt - zum Ordnen.
        public let stand: String
        /// Derselbe Zeitpunkt zum Lesen: „Sa., 07.11. 14:35“, in der Zeit des Hauses.
        public let wann: String
        public let name: String
        public let symbol: String
        public let aenderung: String
        public let grund: String
        public let block: String
        /// Wurde der Fehler des Modells dadurch kleiner? „RMSE 0,420 → 0,310“.
        public let guete: String?
    }

    // MARK: - Das Bild

    public let ebenen: [Ebenengruppe]
    public let kreise: [Kreiszeile]
    public let protokoll: [Protokollzeile]
    /// Wie viele der lernbaren Parameter schon auf einer Messung stehen.
    public let belegt: Int
    public let lernbar: Int
    public let uebersteuert: [String]
    /// Seit wann gelernt wird, in einem Satz.
    public let lernsatz: String

    // MARK: - Wörter

    public static let seitenkicker = "Kaskade in fünf Ebenen · Herkunft jeder Zahl"
    public static let laedtSatz = "Die Karte wird geholt."

    /// Was auf der Seite steht, wenn jemand den Methodendeckel aufmacht.
    public static let methode = [
        "Die Kaskade hat fünf Ebenen, und sie ist nur deshalb zulässig, weil jede innere Ebene "
            + "deutlich schneller ist als die, die sie führt: 15 Minuten oben, 60 Sekunden im "
            + "Raum, und dazwischen Zeitkonstanten von Stunden.",
        "Die Reglerparameter sind nicht geraten, sondern aus der Strecke gerechnet (SIMC). Wer "
            + "eine Zeitkonstante übersteuert, verschiebt damit auch die Nachstellzeit. Darum "
            + "bringt jede Änderung die ganze Karte neu zurück.",
        "Phasen- und Amplitudenreserve stehen für jeden stetigen Kreis. Faustregel: 45° und "
            + "Faktor 2,5. Der Zweipunktkreis und die ökonomische Führung haben keine "
            + "Frequenzkennlinie, denn der eine ist unstetig, und die andere wird in Euro beurteilt.",
        "Gelernt wird nur, wo die Daten es tragen. Eine Schätzung ersetzt den geltenden Wert "
            + "erst, wenn sie genug Stützstellen hat, in den Plausibilitätsgrenzen liegt, "
            + "außerhalb ihrer eigenen Unsicherheit vom alten Wert abweicht und den Fehler des "
            + "Modells messbar verkleinert. Was abgelehnt wurde, steht am Parameter mit "
            + "Begründung.",
    ]

    /// Die Überschrift je Ebene. Von außen nach innen, und das ist zugleich von langsam nach
    /// schnell - der Grund, warum die Kaskade überhaupt zulässig ist.
    public static func ebenentitel(_ ebene: Int) -> String {
        switch ebene {
        case 4: return "Ökonomische Führung"
        case 3: return "Puffer und Erzeugerwahl"
        case 2: return "Die beiden Erzeuger"
        case 1: return "Vorlauftemperatur"
        default: return "Einzelraumregelung"
        }
    }

    public static func ebenentakt(_ ebene: Int) -> String {
        switch ebene {
        case 4: return "Takt 15 min · Horizont 48 h"
        case 3: return "Takt 10 s und 10 min · Zeitkonstanten in Stunden"
        case 2: return "Totzeiten in Minuten · Mindestlaufzeiten in Stunden"
        case 1: return "Takt 10 s · der schnellste Kreis"
        default: return "Takt 60 s · der Estrich bestimmt die Zeit"
        }
    }

    public static func herkunftWort(_ h: Herkunftston) -> String {
        switch h {
        case .gemessen: return "gemessen"
        case .geschaetzt: return "geschätzt"
        case .annahme: return "Annahme"
        case .fest: return "fest"
        case .entwurf: return "Entwurf"
        case .uebersteuert: return "übersteuert"
        }
    }

    public static func ton(_ h: ParameterAnsichtHerkunftWahl) -> Herkunftston {
        switch h {
        case .gemessen: return .gemessen
        case .geschaetzt: return .geschaetzt
        case .fest: return .fest
        case .entwurf: return .entwurf
        case .uebersteuert: return .uebersteuert
        case .annahme, .unbekannt: return .annahme
        }
    }

    /// Die Art eines Kreises in einem Wort.
    public static func artwort(_ a: KreisAnsichtArtWahl) -> String {
        switch a {
        case .stetig: return "stetig"
        case .zweipunkt: return "Zweipunkt"
        case .hybrid: return "hybrid"
        case .planung: return "Planung"
        case .unbekannt: return "unbekannt"
        }
    }

    /// Das Feld, in dem eine Reserve liegt - dieselben drei wie am Rundinstrument des
    /// Dashboards (`Regelkreis.tsx:314-318`).
    public enum Reservefeld: String, Sendable, Hashable {
        case zuKlein
        case knapp
        case gut
    }

    /// Unter 45° rot, bis 60° bernstein, darüber Nebel. Die 45° sind die Faustregel aus dem
    /// Kern (`Reserven.gut`), nicht aus dieser Datei.
    public static func feld(phasenreserve grad: Double?) -> Reservefeld {
        guard let grad else { return .zuKlein }
        if grad < 45.0 { return .zuKlein }
        return grad < 60.0 ? .knapp : .gut
    }

    /// Faktor 2,5 ist die Faustregel. `nil` heißt unendlich - die Phase erreicht −180° nie, und
    /// das ist das Beste, was hier stehen kann.
    public static func feld(amplitudenreserve faktor: Double?) -> Reservefeld {
        guard let faktor else { return .gut }
        if faktor < 2.0 { return .zuKlein }
        return faktor < 2.5 ? .knapp : .gut
    }

    // MARK: - Bauen

    /// Die Antwort des Dienstes in die Form bringen, die die Seite zeigt.
    public static func baue(_ k: RegelkreisOut) -> Regelkreisbild {
        let glieder = Dictionary(k.glieder.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let namen = Dictionary(k.bloecke.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var jeBlock: [String: [ParameterAnsicht]] = [:]
        for p in k.parameter { jeBlock[p.block, default: []].append(p) }

        var gruppen: [Ebenengruppe] = []
        for ebene in [4, 3, 2, 1, 0] {
            let bloecke = k.bloecke.filter { $0.ebene == ebene }.map { b in
                Blockzeile(
                    id: b.id,
                    name: b.name,
                    rolle: b.rolleText,
                    kurz: b.kurz,
                    kreis: b.kreis,
                    erklaerung: b.erklaerung,
                    gleichungen: b.gleichungen,
                    behandlung: b.behandlungText,
                    quelle: b.quelle,
                    glied: b.glied.flatMap { glieder[$0] },
                    gliedEntwurf: b.gliedEntwurf.flatMap { glieder[$0] },
                    parameter: (jeBlock[b.id] ?? []).map(zeile),
                    signale: signale(b.id, kanten: k.kanten, namen: namen)
                )
            }
            if bloecke.isEmpty { continue }
            gruppen.append(
                Ebenengruppe(
                    id: ebene, titel: ebenentitel(ebene), takt: ebenentakt(ebene), bloecke: bloecke
                )
            )
        }

        return Regelkreisbild(
            ebenen: gruppen,
            kreise: k.kreise.map(kreiszeile),
            protokoll: protokollzeilen(k),
            belegt: belegt(k),
            lernbar: lernbar(k),
            uebersteuert: k.uebersteuert,
            lernsatz: lernsatz(k)
        )
    }

    private static func lernbar(_ k: RegelkreisOut) -> Int {
        k.parameter.filter { $0.schaetzart != .keiner }.count
    }

    private static func belegt(_ k: RegelkreisOut) -> Int {
        k.parameter.filter { $0.herkunft == .gemessen || $0.herkunft == .geschaetzt }.count
    }

    private static func lernsatz(_ k: RegelkreisOut) -> String {
        let stand = "\(belegt(k)) von \(lernbar(k)) lernbaren Größen aus Messung"
        guard let tage = k.tage else { return "Noch keine Betriebstage aufgezeichnet · " + stand }
        return "\(Formate.zahl(tage, stellen: 0)) Betriebstage · " + stand
    }

    /// Ein Parameter mit allem, was an ihm hängt.
    ///
    /// **Die drei Anteile liegen in derselben Einheit**, nämlich der Breite des
    /// Plausibilitätsbereichs: der Wert, der Startwert und die halbe Breite der Unsicherheit.
    /// Nur so lässt sich ein Schieber zeichnen, auf dem man sieht, ob ein Wert innerhalb seiner
    /// eigenen Streuung vom Startwert abweicht - und genau das ist die Frage, an der die
    /// Lernebene entscheidet.
    private static func zeile(_ p: ParameterAnsicht) -> Parameterzeile {
        let spanne = max(p.oben - p.unten, 1e-9)
        let einheit = p.einheit == "—" ? "" : p.einheit
        let ton = ton(p.herkunft)
        let mitEinheit = einheit.isEmpty ? "" : " " + einheit
        var schaetzsatz: String?
        if let s = p.schaetzung {
            var teile = [Formate.zahl(s, stellen: p.stellen) + mitEinheit]
            if let sigma = p.sigma {
                teile.append("± " + Formate.zahl(sigma, stellen: p.stellen) + mitEinheit)
            }
            if let n = p.n { teile.append("n = \(n)") }
            if let rmse = p.rmse { teile.append("RMSE " + Formate.zahl(rmse, stellen: 3)) }
            schaetzsatz = teile.joined(separator: " · ")
        }
        return Parameterzeile(
            id: p.id,
            symbol: p.symbol,
            name: p.name,
            einheit: einheit,
            stellen: p.stellen,
            zahl: p.wert,
            wert: Formate.zahl(p.wert, stellen: p.stellen) + mitEinheit,
            anteil: anteil(p.wert, unten: p.unten, spanne: spanne),
            startAnteil: anteil(p.startwert, unten: p.unten, spanne: spanne),
            sigmaAnteil: min(1.0, max(0.0, (p.sigma ?? 0.0) / spanne)),
            herkunft: ton,
            herkunftWort: herkunftWort(ton),
            unten: Formate.zahl(p.unten, stellen: p.stellen),
            oben: Formate.zahl(p.oben, stellen: p.stellen),
            schaetzsatz: schaetzsatz,
            // Die abgelehnte Prüfung ist die interessantere Hälfte: sie sagt, warum noch der
            // alte Wert gilt. Eine angenommene steht schon im Protokoll.
            pruefsatz: (p.pruefung?.uebernehmen ?? true) ? nil : p.pruefung?.grund,
            warum: p.warum,
            quelle: p.quelle,
            verfahren: p.schaetzartText,
            lernbar: p.schaetzart != .keiner,
            stuetzstellen: p.n ?? 0,
            verlauf: p.verlauf,
            protokoll: protokollzeilen(p)
        )
    }

    private static func anteil(_ wert: Double, unten: Double, spanne: Double) -> Double {
        min(1.0, max(0.0, (wert - unten) / spanne))
    }

    private static func signale(
        _ id: String, kanten: [KanteAnsicht], namen: [String: String]
    ) -> [Signal] {
        var aus: [Signal] = []
        for (i, kante) in kanten.enumerated() where kante.nach == id {
            aus.append(
                Signal(
                    id: "in-\(i)", name: kante.signal,
                    gegenueber: namen[kante.von] ?? kante.von, hinein: true,
                    vorzeichen: vorzeichen(kante.vorzeichen), art: artwort(kante.art)
                )
            )
        }
        for (i, kante) in kanten.enumerated() where kante.von == id {
            aus.append(
                Signal(
                    id: "aus-\(i)", name: kante.signal,
                    gegenueber: namen[kante.nach] ?? kante.nach, hinein: false,
                    vorzeichen: nil, art: artwort(kante.art)
                )
            )
        }
        return aus
    }

    private static func vorzeichen(_ v: KanteAnsichtVorzeichenWahl?) -> String? {
        switch v {
        case .plus: return "+"
        // Ein echter Minusstrich, kein Bindestrich: er steht neben einem „+“ und soll
        // dieselbe Breite haben.
        case .minus: return "−"
        case .unbekannt, nil: return nil
        }
    }

    private static func artwort(_ a: KanteAnsichtArtWahl) -> String {
        switch a {
        case .signal, .unbekannt: return "Signal"
        case .stoergroesse: return "Störgröße"
        case .rueckfuehrung: return "Rückführung"
        case .fuehrung: return "Führung"
        case .parameter: return "Parameter"
        }
    }

    private static func kreiszeile(_ k: KreisAnsicht) -> Kreiszeile {
        let r = k.reserven
        let phase = r?.phasenreserveGrad
        let amplitude = r?.amplitudenreserve
        let nichtStetig = k.art == .planung
            ? "gleitender Horizont, in Euro beurteilt"
            : "hybrid und ganzzahlig, ohne Frequenzkennlinie"
        return Kreiszeile(
            id: k.id,
            name: k.name,
            regelgroesse: k.regelgroesse,
            stellgroesse: k.stellgroesse,
            reglerBlock: k.reglerBlock,
            art: artwort(k.art),
            takt: takt(k.taktS),
            erklaerung: k.erklaerung,
            entwurf: k.regler.map { r in
                "\(r.regel) · Kp = \(Formate.zahl(r.kp, stellen: 2)) · Tn = \(dauer(r.tn))"
                    + " · λ = \(dauer(r.lam))"
            },
            strecke: k.strecke.map(streckensatz),
            phasenreserve: phase.map { Formate.zahl($0, stellen: 0) + "°" } ?? "—",
            amplitudenreserve: r == nil
                ? "—" : amplitude.map { Formate.zahl($0, stellen: 2) } ?? "∞",
            periode: r?.periodeMin.map(dauer) ?? "—",
            phasenAnteil: phase.map { min(1.0, max(0.0, $0 / 90.0)) },
            // Unendlich schlägt voll aus: die Phase erreicht −180° nie, und das ist das Beste,
            // was dieser Pegel zeigen kann.
            amplitudenAnteil: r == nil
                ? nil : min(1.0, max(0.0, ((amplitude ?? 6.0) - 1.0) / 5.0)),
            phasenFeld: feld(phasenreserve: phase),
            amplitudenFeld: feld(amplitudenreserve: amplitude),
            kennlinie: k.kennlinie,
            durchtritt: r?.durchtritt,
            gut: r?.gut ?? true,
            bewertbar: r != nil,
            hysterese: k.hystereseK.map { "± " + Formate.zahl($0 / 2, stellen: 2) + " K" },
            hinweis: k.hinweis ?? (r == nil ? nichtStetig : nil)
        )
    }

    private static func streckensatz(_ s: StreckeAnsicht) -> String {
        var teile = [s.art == .iptd ? "I mit Totzeit" : "PT1 mit Totzeit"]
        teile.append("K = " + Formate.zahl(s.k, stellen: 3))
        if let t1 = s.t1, t1 > 0 { teile.append("T₁ = " + dauer(t1)) }
        if let t2 = s.t2, t2 > 0 { teile.append("T₂ = " + dauer(t2)) }
        if s.totzeit > 0 { teile.append("Tt = " + dauer(s.totzeit)) }
        if s.halbregel { teile.append("Halbregel angewandt") }
        return teile.joined(separator: " · ")
    }

    /// Eine Dauer in Minuten, in der Einheit, in der ein Mensch sie wiedererkennt.
    public static func dauer(_ minuten: Double) -> String {
        if minuten >= 1440 { return Formate.zahl(minuten / 1440, stellen: 1) + " d" }
        if minuten >= 90 { return Formate.zahl(minuten / 60, stellen: 1) + " h" }
        if minuten >= 1 { return Formate.zahl(minuten, stellen: minuten < 10 ? 1 : 0) + " min" }
        return Formate.zahl(minuten * 60, stellen: 0) + " s"
    }

    private static func takt(_ sekunden: Double) -> String {
        sekunden >= 60
            ? Formate.zahl(sekunden / 60, stellen: 0) + " min"
            : Formate.zahl(sekunden, stellen: 0) + " s"
    }

    /// Das Protokoll eines Parameters, jüngste Übernahme zuerst.
    private static func protokollzeilen(_ p: ParameterAnsicht) -> [Protokollzeile] {
        let einheit = p.einheit == "—" ? "" : " " + p.einheit
        let zeilen = p.protokoll.enumerated().map { i, u in
            Protokollzeile(
                id: "\(p.id)-\(i)",
                stand: u.at,
                wann: wann(u.at),
                name: p.name,
                symbol: p.symbol,
                aenderung: Formate.zahl(u.alt, stellen: p.stellen) + " → "
                    + Formate.zahl(u.neu, stellen: p.stellen) + einheit,
                grund: u.grund,
                block: p.block,
                guete: guete(u)
            )
        }
        // Jüngste zuerst: die Zeitstempel sind ISO-8601 in UTC und ordnen sich als Text.
        return zeilen.sorted { $0.stand > $1.stand }
    }

    /// Ein Zeitstempel zum Lesen. Dieselbe Form wie im Wirkungsraster: kurzes Datum mit
    /// führenden Nullen, dann die Uhrzeit - in einer Spalte aus vielen Zeilen stehen die
    /// Ziffern damit untereinander.
    public static func wann(_ iso: String) -> String {
        let datum = Formate.kurzDatum(iso: iso)
        let uhr = Formate.hhmm(iso: iso)
        return datum == Formate.leer ? uhr : datum + " " + uhr
    }

    private static func guete(_ u: Uebernahme) -> String? {
        guard let alt = u.rmseAlt, let neu = u.rmseNeu else { return nil }
        return "RMSE " + Formate.zahl(alt, stellen: 3) + " → " + Formate.zahl(neu, stellen: 3)
    }

    /// Das Protokoll der ganzen Karte, jüngste Übernahme zuerst.
    private static func protokollzeilen(_ k: RegelkreisOut) -> [Protokollzeile] {
        k.parameter.flatMap(protokollzeilen).sorted { $0.stand > $1.stand }
    }

    // MARK: - Die Kacheln des Kopfes

    /// Arbeitspunkt, Grenzkosten, Umschaltpunkt und Lernstand - dieselben vier wie im Dashboard.
    public static func kacheln(_ k: RegelkreisOut) -> [Kennzahl] {
        let ap = k.arbeitspunkt
        let kosten = k.kosten
        let billiger = kosten.waermepumpeCtKwh <= kosten.ofenCtKwh
        let gemessen = (ap.aussenGemessen ?? false) ? "gemessen" : "Auslegungspunkt"
        let vorlauf = (ap.vorlaufGemessen ?? false) ? "gemessen" : "aus der Kennlinie"
        let uebernahmen = k.uebernahmen ?? 0
        return [
            Kennzahl(
                wort: "Arbeitszahl im Punkt",
                wert: Formate.zahl(kosten.cop, stellen: 2),
                dazu: "bei \(Formate.celsius(ap.aussenC, stellen: 1)) außen (\(gemessen)) und "
                    + "\(Formate.celsius(ap.vorlaufC)) Vorlauf (\(vorlauf))",
                ton: .bernstein
            ),
            Kennzahl(
                wort: "Grenzkosten Wärme",
                wert: Formate.zahl(kosten.waermepumpeCtKwh, stellen: 1) + " / "
                    + Formate.zahl(kosten.ofenCtKwh, stellen: 1),
                einheit: "ct/kWh",
                dazu: (billiger ? "Wärmepumpe" : "Pelletofen") + " ist billiger, bei "
                    + Formate.zahl(ap.strompreisEurKwh * 100, stellen: 1) + " ct/kWh Strom",
                ton: billiger ? .nebel : .alarm
            ),
            Kennzahl(
                wort: "Umschaltpunkt",
                wert: kosten.umschaltAussenC.map { Formate.celsius($0, stellen: 1) } ?? "—",
                dazu: (kosten.umschaltAussenC == nil
                    ? "außerhalb des sinnvollen Bereichs · nötige Arbeitszahl "
                    : "darunter ist der Ofen billiger · nötige Arbeitszahl ")
                    + Formate.zahl(kosten.copUmschalt, stellen: 2)
            ),
            Kennzahl(
                wort: "Lernstand",
                wert: k.tage.map { Formate.zahl($0, stellen: 0) } ?? "0",
                einheit: "Betriebstage",
                dazu: "\(belegt(k)) von \(lernbar(k)) Größen aus Messung · \(uebernahmen) "
                    + (uebernahmen == 1 ? "Übernahme" : "Übernahmen")
                    + (k.uebersteuert.isEmpty ? "" : " · \(k.uebersteuert.count) übersteuert"),
                ton: k.uebersteuert.isEmpty ? .normal : .alarm
            ),
        ]
    }
}
