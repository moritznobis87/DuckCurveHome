import Foundation

/// Was in den Aufklapp-Fenstern der Hauskonsole steht: rechnen, sortieren, benennen.
///
/// **Warum ein Fenster und keine zweite Seite.** Ein Block der Konsole nennt eine Zahl, und jede
/// dieser Zahlen hat genau eine Anschlussfrage: Welche Tür steht offen? Welcher Fühler zieht den
/// Ladestand herunter? Wie lange lief die Wärmepumpe heute? Welcher Raum hält seine Kreise
/// offen? Die Vorlage schreibt die Begründung aus (`house/Konsole.tsx:16-21`: „Die Antwort
/// gehoert neben die Zahl, nicht hinter einen Seitenwechsel“) - und dieselbe Antwort braucht
/// dieselben Zahlen, egal ob sie in einem Fenster oder in einem Blatt steht.
///
/// **Warum das hier steht und nicht in der Ansicht.** Jede Zeile dieser Fenster ist eine
/// Rechnung mit mindestens einem Grenzfall: ein Kontakt ohne Meldung, ein Fühler ohne Messwert,
/// ein Tag ohne eine einzige Minute Laufzeit, eine Kurve mit Lücken. In SwiftUI geschrieben wäre
/// das eine Ansicht, die niemand prüfen kann.
///
/// Dieselben Regeln wie `apps/web/src/components/house/insights.ts` und `house/live.ts`.
public enum Hauskonsolenfenster {

    // MARK: - Der Alarm

    /// Die Stufen der Alarmanlage, wie der Dienst sie zählt.
    ///
    /// **`state` ist eine Zahl, kein Wort** (`house/live.ts:31-39`): 0 unscharf, 1 zu Hause
    /// scharf, 2 unterwegs scharf, 3 schaltet gerade, ab 4 ausgelöst. Ohne Anlage und ohne
    /// Meldung bleibt die Stufe unbekannt - das ist etwas anderes als „unscharf“ und darf
    /// nicht so aussehen.
    public enum Alarmstufe: String, Sendable, Hashable, CaseIterable {
        case unscharf
        case zuhause
        case unterwegs
        case schaltet
        case ausgeloest
        case unbekannt

        /// Das Wort im Block, in Großschrift wie in der Vorlage (`ALARM_WORT`,
        /// `house/live.ts:40-47`).
        public var wort: String {
            switch self {
            case .unscharf: return "UNSCHARF"
            case .zuhause: return "ZU HAUSE"
            case .unterwegs: return "UNTERWEGS"
            case .schaltet: return "SCHALTET"
            case .ausgeloest: return "AUSGELÖST"
            case .unbekannt: return "KEINE MELDUNG"
            }
        }
    }

    /// Die Stufe aus der gemeldeten Zahl (`house/live.ts:31-39`).
    public static func stufe(_ state: Double?) -> Alarmstufe {
        guard let state, state.isFinite else { return .unbekannt }
        if state >= 4 { return .ausgeloest }
        if state >= 3 { return .schaltet }
        if state >= 2 { return .unterwegs }
        if state >= 1 { return .zuhause }
        return .unscharf
    }

    /// Dasselbe aus der Meldung des Dienstes.
    ///
    /// **Ohne Anlage ist die Stufe unbekannt, nicht unscharf** (`house/live.ts:66`: die Stufe
    /// entsteht nur, wenn `present` gilt). Ein Haus ohne Alarmanlage als „unscharf“ zu melden
    /// hieße, eine Anlage zu behaupten, die niemand hat.
    public static func stufe(_ alarm: AlarmOut?) -> Alarmstufe {
        guard let alarm, alarm.present else { return .unbekannt }
        return stufe(alarm.state)
    }

    /// Der Satz unter dem Wort: was der Dienst sagt, sonst „nicht eingerichtet“
    /// (`house/live.ts`, `alarmSatz`).
    ///
    /// **Leer, wenn er nur das Wort wiederholt.** Ist die Anlage unscharf, meldet der Dienst
    /// „unscharf“, und im Block stand „UNSCHARF“ und darunter noch einmal „unscharf“ (Bild des
    /// Hausherrn vom 27.11.2026). Bei „zu Hause scharf“ unter „ZU HAUSE“ sagt der Satz etwas
    /// dazu und bleibt.
    public static func alarmsatz(_ alarm: AlarmOut?) -> String {
        guard let alarm, alarm.present else { return "nicht eingerichtet" }
        let gemeldet = alarm.stateDe.trimmingCharacters(in: .whitespaces)
        return gemeldet.lowercased() == stufe(alarm).wort.lowercased() ? "" : alarm.stateDe
    }

    // MARK: - Orte im Plan

    /// Wo etwas im Hausplan liegt: in welchem Geschoss, in welchem Raum.
    public struct Ort: Equatable, Sendable, Hashable, Identifiable {
        public let deck: String
        public let raum: String

        /// Deck und Raum zusammen - ein Raumname allein ist nicht eindeutig, „Flur“ gibt es in
        /// jedem Geschoss.
        public var id: String { "\(deck)/\(raum)" }

        public init(deck: String, raum: String) {
            self.deck = deck
            self.raum = raum
        }
    }

    /// Wo ein Raum der Einzelraumregelung im Plan liegt. `nil`, wenn der Plan ihn nicht kennt.
    ///
    /// Teilräume (`partOf`) zählen nicht: sie sind ein Stück eines anderen Raums und haben kein
    /// eigenes Schild, auf das ein Sprung zielen könnte (`insights.ts:22-28`).
    public static func raumOrt(plan: HousePlan?, raumId: Int?) -> Ort? {
        guard let plan, let raumId else { return nil }
        for deck in plan.decks {
            if let raum = deck.rooms.first(where: { $0.roomId == raumId && $0.partOf == nil }) {
                return Ort(deck: deck.key, raum: raum.name)
            }
        }
        return nil
    }

    /// Zu welchem Raum ein Kontakt gehört. `nil`, wenn er keinem zugeordnet ist
    /// (`insights.ts:31-37`).
    public static func kontaktOrt(plan: HousePlan?, schluessel: String) -> Ort? {
        guard let plan else { return nil }
        for deck in plan.decks {
            if let k = deck.contacts.first(where: { $0.key == schluessel }), let raum = k.room {
                return Ort(deck: deck.key, raum: raum)
            }
        }
        return nil
    }

    // MARK: - Fenster und Türen

    /// Ein Kontakt des Plans mit dem, was er zuletzt gemeldet hat.
    public struct Kontaktzeile: Equatable, Sendable, Identifiable {
        public let schluessel: String
        public let name: String
        public let tuer: Bool
        public let raum: String?
        public let ort: Ort?
        /// `nil` heißt: nichts Frisches gemeldet. Das ist nicht „zu“.
        public let offen: Bool?
        public let beobachtetAm: String?

        public var id: String { schluessel }

        public init(
            schluessel: String, name: String, tuer: Bool, raum: String?, ort: Ort?,
            offen: Bool?, beobachtetAm: String?
        ) {
            self.schluessel = schluessel
            self.name = name
            self.tuer = tuer
            self.raum = raum
            self.ort = ort
            self.offen = offen
            self.beobachtetAm = beobachtetAm
        }

        /// Was unter dem Namen steht, wenn kein Raum zugeordnet ist (`Konsole.tsx:203`).
        public var unterzeile: String { raum ?? (tuer ? "Tür" : "Fenster") }

        /// „offen“ / „zu“ / „keine Meldung“ (`Konsole.tsx:208-210`).
        public var wort: String {
            switch offen {
            case .some(true): return "offen"
            case .some(false): return "zu"
            case nil: return "keine Meldung"
            }
        }
    }

    /// Alle Kontakte des Plans, offene zuerst.
    ///
    /// Reihenfolge: offen vor zu vor stumm, Türen vor Fenstern, sonst nach Namen
    /// (`insights.ts:59-77`). **Ein stummer Kontakt steht hinten und nicht gar nicht**: dass er
    /// schweigt, ist die Auskunft, die jemand sucht, der sich fragt, warum eine Tür nie offen
    /// erscheint.
    public static func kontaktzeilen(
        plan: HousePlan?, kontakte: [HouseContactOut]
    ) -> [Kontaktzeile] {
        let gemeldet = Dictionary(kontakte.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        var zeilen: [Kontaktzeile] = []
        for deck in plan?.decks ?? [] {
            for k in deck.contacts {
                let z = gemeldet[k.key]
                zeilen.append(
                    Kontaktzeile(
                        schluessel: k.key, name: k.name, tuer: k.door ?? false, raum: k.room,
                        ort: k.room.map { Ort(deck: deck.key, raum: $0) },
                        offen: z?.open, beobachtetAm: z?.observedAt))
            }
        }
        return zeilen.sorted { a, b in
            let ra = rang(a.offen), rb = rang(b.offen)
            if ra != rb { return ra < rb }
            if a.tuer != b.tuer { return a.tuer }
            return vorher(a.name, b.name)
        }
    }

    private static func rang(_ offen: Bool?) -> Int {
        switch offen {
        case .some(true): return 0
        case .some(false): return 1
        case nil: return 2
        }
    }

    // MARK: - Heizkreise

    /// Ein Raum mit offenen Heizkreisen.
    public struct Kreiszeile: Equatable, Sendable, Identifiable {
        public let id: Int
        public let name: String
        public let etage: String
        public let ventil: Double
        public let kreise: Int
        public let tempC: Double?
        public let zielC: Double?
        public let abweichungK: Double?
        public let ort: Ort?

        public init(
            id: Int, name: String, etage: String, ventil: Double, kreise: Int, tempC: Double?,
            zielC: Double?, abweichungK: Double?, ort: Ort?
        ) {
            self.id = id
            self.name = name
            self.etage = etage
            self.ventil = ventil
            self.kreise = kreise
            self.tempC = tempC
            self.zielC = zielC
            self.abweichungK = abweichungK
            self.ort = ort
        }
    }

    /// Die Räume mit offenen Heizkreisen, der weiteste zuerst.
    ///
    /// **Warum nicht alle Räume** (`insights.ts:93-99`): Der Block zählt die offenen; das
    /// Fenster soll dieselbe Zahl erklären und nicht eine zweite Liste daneben stellen. Wer alle
    /// sehen will, geht auf die Raumseite, und dorthin führt der Fuß des Fensters.
    public static func kreiszeilen(_ raeume: [RoomLiveOut], plan: HousePlan?) -> [Kreiszeile] {
        raeume
            .filter { ($0.valve ?? 0) > 0 }
            .map { r in
                Kreiszeile(
                    id: r.id, name: r.name, etage: r.floor, ventil: r.valve ?? 0,
                    kreise: r.circuits, tempC: r.tempC, zielC: r.targetC ?? r.setpointC,
                    abweichungK: r.deviationK, ort: raumOrt(plan: plan, raumId: r.id))
            }
            .sorted { a, b in
                if a.ventil != b.ventil { return a.ventil > b.ventil }
                let da = a.abweichungK ?? 0, db = b.abweichungK ?? 0
                if da != db { return da < db }
                return vorher(a.name, b.name)
            }
    }

    /// Der Raum, der alle Kreise offen hat und trotzdem unter dem Ziel liegt.
    ///
    /// Er bestimmt die nötige Vorlauftemperatur für alle anderen mit. **Das ist eine andere
    /// Regel als ``Raumkarte/anDerGrenze(tagesventil:abweichung:fensterOffen:)``**: dort geht es
    /// um einen ganzen Tag (0,85 im Mittel), hier um den Augenblick - und da ist das Ventil
    /// entweder ganz offen oder nicht (`insights.ts:121-123`: 0,99 und −0,5 K).
    public static func anDerGrenze(_ zeilen: [Kreiszeile]) -> Kreiszeile? {
        zeilen.first { $0.ventil >= 0.99 && ($0.abweichungK ?? 0) < -0.5 }
    }

    /// Der Satz, der dazu im Fenster steht (`Konsole.tsx:338-341`).
    public static func grenzsatz(_ zeile: Kreiszeile) -> String {
        "\(zeile.name) hat alle Kreise offen und liegt trotzdem unter dem Ziel. "
            + "Dieser Raum bestimmt die nötige Vorlauftemperatur für alle anderen mit."
    }

    // MARK: - Puffer

    /// Die vier Schichten von oben nach unten (`insights.ts:127`).
    public static let schichtnamen = ["oben", "Mitte oben", "Mitte unten", "unten"]

    /// Eine Schicht des Puffers mit ihrem Fühler.
    public struct Schichtzeile: Equatable, Sendable, Identifiable {
        public let name: String
        public let tempC: Double?
        public let beobachtetAm: String?
        /// **Frisch heißt: der Dienst steht dahinter.** `ok` ist gemessen, `derived` gerechnet;
        /// alles andere ist alt oder gar nichts, und dann steht das Alter dabei
        /// (`insights.ts:136-143`).
        public let frisch: Bool

        public var id: String { name }

        public init(name: String, tempC: Double?, beobachtetAm: String?, frisch: Bool) {
            self.name = name
            self.tempC = tempC
            self.beobachtetAm = beobachtetAm
            self.frisch = frisch
        }
    }

    public static func schichtzeilen(_ temps: BufferTemperatures?) -> [Schichtzeile] {
        guard let temps else { return [] }
        let messwerte = [temps.top, temps.midTop, temps.midBottom, temps.bottom]
        return messwerte.enumerated().map { i, m in
            Schichtzeile(
                name: i < schichtnamen.count ? schichtnamen[i] : "Fühler \(i + 1)",
                tempC: m.value, beobachtetAm: m.observedAt,
                frisch: m.quality == .ok || m.quality == .derived)
        }
    }

    /// Das Wort zum Zustand des Puffers (`insights.ts:146-148`).
    public static func statuswort(_ status: BufferStatus?) -> String {
        switch status {
        case .cold: return "kalt"
        case .partial: return "teilweise geladen"
        case .warm: return "warm"
        case .full: return "voll"
        default: return "unbekannt"
        }
    }

    /// Wie der Ladestand gerechnet wurde, in Worten statt als Kennung (`insights.ts:151-156`).
    ///
    /// Eine unbekannte Kennung wird durchgereicht und nicht verschwiegen: dann steht zwar ein
    /// englisches Wort da, aber kein falsches deutsches.
    public static func methodensatz(_ methode: String?) -> String {
        guard let methode, !methode.isEmpty else { return "" }
        if methode.hasPrefix("layered_energy") {
            return "Schichtenmodell: jede Schicht mit ihrem eigenen Anteil am Volumen"
        }
        if methode.hasPrefix("weighted_mean") { return "gewichtetes Mittel der vier Fühler" }
        return methode
    }

    // MARK: - Wärmepumpe

    /// Was die Wärmepumpe heute getan hat, aus dem Minutenraster.
    public struct Tageslauf: Equatable, Sendable {
        /// Elektrische Arbeit seit Mitternacht.
        public let kwh: Double
        /// Minuten, in denen Leistung anlag.
        public let minuten: Int
        /// Die höchste Minutenleistung des Tages - die Achse der Kurve.
        public let hoechst: Double

        public init(kwh: Double, minuten: Int, hoechst: Double) {
            self.kwh = kwh
            self.minuten = minuten
            self.hoechst = hoechst
        }
    }

    /// Ab welcher Leistung die Wärmepumpe als laufend gilt. Darunter ist es Bereitschaft
    /// (`insights.ts:163`).
    public static let laeuftKw = 0.1

    /// Arbeit, Laufzeit und Spitze aus dem Minutenraster (`insights.ts:170-184`).
    ///
    /// **Eine Minute ist eine Sechzigstelstunde**, und mehr steckt in der Rechnung nicht. Das
    /// ist genauer als es aussieht: das Raster mittelt je Minute, was im Ereignisstrom ankam.
    /// Minuten ohne Messwert zählen nicht mit - weder als null kWh noch als Stillstand.
    public static func tageslauf(_ punkte: [Verlaufspunkt]) -> Tageslauf {
        var kwh = 0.0
        var minuten = 0
        var hoechst = 0.0
        for p in punkte {
            guard let w = p.waermepumpe, w.isFinite else { continue }
            kwh += w / 60
            if w >= laeuftKw { minuten += 1 }
            if w > hoechst { hoechst = w }
        }
        return Tageslauf(kwh: kwh, minuten: minuten, hoechst: hoechst)
    }

    /// Die Achse der Tageskurve: mindestens 1 kW, sonst auf die nächste ganze Zahl aufgerundet
    /// (`Konsole.tsx:290`).
    ///
    /// **Warum nicht die Spitze selbst.** Eine Achse, die genau auf dem höchsten Wert endet,
    /// lässt die Kurve die Oberkante berühren und sieht abgeschnitten aus; und an einem Tag
    /// ohne Lauf stünde sonst eine Null an der Achse, durch die nicht zu teilen ist.
    public static func kurvenachse(_ lauf: Tageslauf) -> Double {
        max(1, lauf.hoechst.rounded(.up))
    }

    // MARK: - Die Kurve

    /// Die Reihe auf eine feste Zahl von Stützstellen verdichten (`insights.ts:229-236`).
    ///
    /// **Eine feste Spaltenzahl, keine Schrittweite.** ``Datenbild/verdichte(_:schrittMin:)``
    /// rechnet in Minuten und liefert je nach Tageslänge verschieden viele Felder; die Kurve im
    /// Fenster ist 280 Punkte breit und braucht immer dieselben 96. Je Fenster das Mittel der
    /// vorhandenen Werte; ein Fenster ganz ohne Wert bleibt `nil`.
    public static func verdichte(_ werte: [Double?], stellen: Int) -> [Double?] {
        guard stellen > 0 else { return [] }
        guard werte.count > stellen else { return werte }
        let breite = Double(werte.count) / Double(stellen)
        return (0..<stellen).map { i in
            let von = Int(Double(i) * breite)
            let bis = max(Int(Double(i + 1) * breite), von + 1)
            let teil = werte[von..<min(bis, werte.count)].compactMap { $0 }
            guard !teil.isEmpty else { return nil }
            return teil.reduce(0, +) / Double(teil.count)
        }
    }

    /// Ein Stück je zusammenhängendem Abschnitt der Reihe, in Einheitskoordinaten.
    ///
    /// `x` läuft von 0 bis 1 über die Reihe, `y` von 0 oben bis 1 unten - dieselbe Form wie
    /// ``Raumkarte/kurve(_:)``, damit die Ansicht beide gleich malt. Die Achse ist hier aber
    /// 0 bis `hoechst` und nicht ±Kelvin um ein Ziel.
    ///
    /// **Lücken bleiben Lücken** (`insights.ts:203-208`): „Eine durchgezogene Linie ueber eine
    /// Minute ohne Messwert waere eine Behauptung ueber genau die Minute, in der nichts ankam.“
    /// Ein Stück aus einem einzigen Punkt fällt weg - eine Linie von einem Punkt nach nirgendwo
    /// ist nichts, was man zeichnen könnte.
    public static func sparklinie(_ werte: [Double?], hoechst: Double) -> [[Raumkarte.Punkt]] {
        guard werte.count > 1, hoechst > 0 else { return [] }
        let letzte = Double(werte.count - 1)
        var stuecke: [[Raumkarte.Punkt]] = []
        var lauf: [Raumkarte.Punkt] = []
        for (i, w) in werte.enumerated() {
            guard let w, w.isFinite else {
                if lauf.count > 1 { stuecke.append(lauf) }
                lauf = []
                continue
            }
            let anteil = min(max(w, 0), hoechst) / hoechst
            lauf.append(Raumkarte.Punkt(x: Double(i) / letzte, y: 1 - anteil))
        }
        if lauf.count > 1 { stuecke.append(lauf) }
        return stuecke
    }

    // MARK: - Wie lange schon

    /// Wie lange etwas schon dauert, aus einem Zeitpunkt. `nil`, wenn keiner vorliegt
    /// (`insights.ts:196-201`).
    ///
    /// **Ein Zeitpunkt in der Zukunft ergibt keine Dauer.** Im Vorführbetrieb läuft die Uhr des
    /// Dienstes im Zeitraffer, und ein Messwert, der der Anzeige um Sekunden voraus ist, würde
    /// sonst als „seit −1 min“ dastehen. Nichts zu schreiben ist dann die ehrliche Auskunft.
    public static func seitText(_ iso: String?, jetzt: Date) -> String? {
        guard let iso, let d = Zeit.ausIso(iso) else { return nil }
        let sekunden = jetzt.timeIntervalSince(d)
        guard sekunden.isFinite, sekunden >= 0 else { return nil }
        return Formate.dauer(minuten: Int((sekunden / 60).rounded()))
    }

    // MARK: - Der Ofen

    /// Brennt der Pelletofen? `nil`, wenn es keinen gibt oder er nichts sagt
    /// (`house/live.ts:66`).
    ///
    /// Das Modell lässt die Glut davon atmen (`HouseScene.ts:1341`), und „keine Meldung“ darf
    /// dort nicht wie „aus“ aussehen.
    public static func ofenLaeuft(_ ofen: StoveLiveOut?) -> Bool? {
        guard let ofen, ofen.present == true else { return nil }
        return ofen.running
    }

    // MARK: - Sortieren

    /// Zwei Namen in der Reihenfolge, in der ein deutscher Leser sie erwartet.
    ///
    /// **Warum nicht `<` auf dem String.** Der Vergleich über die Zeichenwerte stellt „Ärzte“
    /// hinter „Zimmer“ und „büro“ hinter „Zimmer“; die Vorlage sortiert mit
    /// `localeCompare(…, "de")`. Eine Locale-Sortierung in der Foundation unter Linux ist
    /// nicht dieselbe wie unter iOS - darum wird hier gefaltet und nicht geliehen: Umlaute auf
    /// ihren Grundbuchstaben, ß auf ss, Großschreibung weg. Erst bei gleichem Faltwert
    /// entscheidet die Urform, damit die Reihenfolge eindeutig bleibt.
    static func vorher(_ a: String, _ b: String) -> Bool {
        let fa = faltung(a), fb = faltung(b)
        if fa != fb { return fa < fb }
        return a < b
    }

    static func faltung(_ s: String) -> String {
        var aus = ""
        for z in s.lowercased() {
            switch z {
            case "ä": aus += "a"
            case "ö": aus += "o"
            case "ü": aus += "u"
            case "ß": aus += "ss"
            case "é", "è", "ê": aus += "e"
            case "á", "à", "â": aus += "a"
            default: aus.append(z)
            }
        }
        return aus
    }
}
