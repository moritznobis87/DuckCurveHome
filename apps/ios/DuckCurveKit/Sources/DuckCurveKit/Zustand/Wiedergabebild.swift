import Foundation

/// Ein vergangener Tag als Bild: Ringe, Bandreihen und die Sätze dazu, einmal gerechnet.
///
/// **Warum im Kern und nicht in der Ansicht.** Die Wiedergabeseite zeigt denselben Tag dreimal -
/// das Anlagenschema je Bild, den Tag als Ring und den Tag als Band (`Wiedergabe.tsx:23-26`:
/// „Drei Ansichten desselben Zeitpunkts, eine Uhr“). Die Zusammenfassung zu Läufen, die fünf
/// Helligkeitsstufen, die Preisspanne und das Tagesmaximum der Sonne brauchen Ring **und** Band;
/// in einer `View` lägen sie zweimal und wären kein einziges Mal geprüft.
///
/// **Lücken bleiben Lücken.** Ein Zeitpunkt ohne Messung liefert kein Bild, und es wird keines
/// erfunden (`Schema.swift:1340-1344`). Darum endet ein Lauf nicht nur beim Wertwechsel, sondern
/// auch beim Zeitsprung, und `erwartet` steht neben der Anzahl: erst der Vergleich macht die
/// Lücke sichtbar, statt sie als dichtes Band erscheinen zu lassen.
public struct Wiedergabebild: Sendable {

    // MARK: - Läufe

    /// Ein Stück Tag mit gleichbleibendem Wert: von, bis, und was dort galt.
    ///
    /// Die Grenzen sind Zeitpunkte und keine Bildnummern, denn ein Lauf reicht einen Schritt über
    /// seinen letzten Zeitstempel hinaus - das Bild von 12:00 gilt bis 12:05, sonst fehlte am Ende
    /// jedes Laufs ein Schritt.
    public struct Lauf<Wert: Sendable & Equatable>: Sendable, Equatable {
        public var von: Date
        public var bis: Date
        public var wert: Wert

        public init(von: Date, bis: Date, wert: Wert) {
            self.von = von
            self.bis = bis
            self.wert = wert
        }
    }

    /// Aufeinanderfolgende Bilder mit gleichem Wert zu Läufen zusammenfassen.
    ///
    /// **Ein Lauf endet auch, wenn die Zeit springt** (`tagesuhr.ts:52-62`): „Würde nur der Wert
    /// verglichen, liefe ein Lauf über einen Ausfall hinweg - der Ring zeigte eine Stunde Betrieb,
    /// von der niemand etwas weiß.“ Ein `nil` ergibt keinen Lauf, sondern beendet den offenen:
    /// „nicht gemessen“ und „gemessen, aber nein“ sind zwei verschiedene Aussagen.
    ///
    /// Gebraucht von Uhr **und** Band, deshalb genau einmal (`Tagesband.tsx:52-56`:
    /// „Dieselbe Zusammenfassung wie in der Tagesuhr, also auch dieselben Lücken“).
    public static func laeufe<Wert: Sendable & Equatable>(
        _ werte: [Wert?], zeiten: [Date], schritt: TimeInterval
    ) -> [Lauf<Wert>] {
        var aus: [Lauf<Wert>] = []
        var offen: Int?
        for i in werte.indices {
            guard i < zeiten.count else { break }
            let t = zeiten[i]
            // Der Anschluss wird am Ende des offenen Laufs gemessen, also eine halbe Schrittweite
            // Toleranz nach dessen eigenem Ende. Ein fehlendes Bild reißt damit auf.
            let anschluss = offen.map { t.timeIntervalSince(aus[$0].bis) < schritt * 0.5 } ?? false
            guard let w = werte[i] else {
                offen = nil
                continue
            }
            if let k = offen, anschluss, aus[k].wert == w {
                aus[k].bis = t.addingTimeInterval(schritt)
            } else {
                aus.append(Lauf(von: t, bis: t.addingTimeInterval(schritt), wert: w))
                offen = aus.count - 1
            }
        }
        return aus
    }

    // MARK: - Stufen

    /// Die fünf Helligkeiten der beiden Stärkeringe, von kaum bis voll (`Tagesuhr.tsx:44`).
    ///
    /// **Nicht in `Marken`**, weil sie keine Markenfarben sind, sondern die Auflösung *dieser*
    /// Uhr: „fünf unterscheidbare Helligkeiten liest das Auge sicherer als 288 fast gleiche“
    /// (`tagesuhr.ts:85-92`). Die Spurfarbe dagegen ist eine Marke und steht an ``Marken/spur``:
    /// sie sagt „gemessen, aber nein“ und gilt damit über alle Ringe, nicht nur über die zwei.
    public static let stufen: [Double] = [0.16, 0.32, 0.52, 0.76, 1]

    /// Einen Wert in eine von `anzahl` Stufen einordnen, 0 bis anzahl-1.
    ///
    /// Liegen alle Werte gleich, ist die Spanne null; dann bekommt alles die mittlere Stufe,
    /// statt durch null zu teilen (`tagesuhr.ts:93-97`).
    public static func stufe(wert: Double, min unten: Double, max oben: Double, anzahl: Int) -> Int
    {
        guard anzahl > 0 else { return 0 }
        guard oben > unten else { return (anzahl - 1) / 2 }
        let roh = ((wert - unten) / (oben - unten)) * Double(anzahl)
        guard roh.isFinite else { return 0 }
        return min(anzahl - 1, max(0, Int(roh.rounded(.down))))
    }

    // MARK: - Was angezeigt wird

    /// Welche Marke eine Zeile oder ein Ring trägt. Die Ansicht setzt die Farbe ein; der Kern
    /// nennt nur die Sache, denn `Color` gibt es unter Linux nicht.
    public enum Marke: String, Sendable, Hashable {
        case preis, sonne, waermepumpe, ofen
    }

    /// Ein Punkt einer Bandreihe. `wert` ist `nil`, wo die Reihe eine Lücke hat.
    public struct Punkt: Sendable, Hashable, Identifiable {
        public let zeit: Date
        public let wert: Double?
        public var id: Date { zeit }

        public init(zeit: Date, wert: Double?) {
            self.zeit = zeit
            self.wert = wert
        }
    }

    /// Eine Fläche des Tagesbands: ihr Name links daneben und ihre feste Höhe.
    ///
    /// **Die Höhen sind fest** (`Tagesband.tsx:65-66`): „drei dünne Zeitleisten brauchen keine
    /// Luft, die beiden Kurven schon.“
    public struct Bandflaeche: Sendable, Hashable, Identifiable {
        public let art: Art
        public let name: String
        public let hoehe: Double
        public var id: String { art.rawValue }

        public enum Art: String, Sendable, Hashable {
            case kw, preis, geplant, gelaufen, ofen
        }

        public init(art: Art, name: String, hoehe: Double) {
            self.art = art
            self.name = name
            self.hoehe = hoehe
        }
    }

    /// Ein Eintrag der Legende unter der Uhr.
    ///
    /// **Jede Zeile ist eine Farbmarke und ein Wort in Textfarbe** (`Tagesuhr.tsx:288-289`):
    /// „farbige Schrift wäre Kennung ohne Lesbarkeit.“ Die Absicht steht als Umriss, weil sie
    /// dasselbe Ding in einem anderen Stand ist.
    public struct Legendeneintrag: Sendable, Hashable, Identifiable {
        public let wort: String
        public let marke: Marke
        public let umriss: Bool
        public var id: String { wort }

        public init(wort: String, marke: Marke, umriss: Bool = false) {
            self.wort = wort
            self.marke = marke
            self.umriss = umriss
        }
    }

    /// Eine Zeile der Fahne über dem Band.
    public struct Fahnenzeile: Sendable, Hashable, Identifiable {
        public let satz: String
        /// `nil` heißt: keine Farbmarke davor - der eingerückte Satz zur Absicht.
        public let marke: Marke?
        public let eingerueckt: Bool
        public var id: String { satz }

        public init(satz: String, marke: Marke?, eingerueckt: Bool = false) {
            self.satz = satz
            self.marke = marke
            self.eingerueckt = eingerueckt
        }
    }

    // MARK: - Der Tag

    public var tag: String = ""
    public var schrittMin: Int = 5
    public var schritt: TimeInterval = 300
    /// Anfang und Ende des Ortstags, wie der Dienst sie nennt - die Achse des Rings.
    public var von: Date = .distantPast
    public var bis: Date = .distantPast
    /// Die Zeitstempel der Bilder, aufsteigend.
    public var zeitpunkte: [Date] = []
    /// Wie viele Bilder ein vollständiger Tag hätte.
    public var erwartet: Int = 0
    /// Wie viele Stunden dieser Tag hat - 23 oder 25 an den Umstellungstagen.
    public var stundenImTag: Int = 24
    /// Die Spanne der Zeitachse des Bandes: erstes bis letztes Bild.
    public var bandspanne: ClosedRange<Date>?

    public var anzahl: Int { zeitpunkte.count }
    /// Ob der Tag lückenlos erfasst ist (`Wiedergabe.tsx:189`).
    public var vollstaendig: Bool { anzahl >= erwartet }

    // MARK: - Die Ringe

    /// Wo überhaupt gemessen wurde. Wo keine Spur liegt, wurde nichts erfasst.
    public var spur: [Lauf<Bool>] = []
    public var preisringe: [Lauf<Int>] = []
    public var sonnenringe: [Lauf<Int>] = []
    /// Die Absicht des Fahrplans: `true` gefüllt mit Rand, `false` als blasse Spur.
    public var geplant: [Lauf<Bool>] = []
    public var gelaufen: [Lauf<Bool>] = []
    public var ofen: [Lauf<Bool>] = []

    // MARK: - Die Bandreihen

    public var sonne: [Punkt] = []
    public var netz: [Punkt] = []
    public var preis: [Punkt] = []

    /// Nur die Läufe, die ein Balken werden - `markArea` der Vorlage filtert auf `wert`.
    public var geplanteBalken: [Lauf<Bool>] { geplant.filter(\.wert) }
    public var gelaufeneBalken: [Lauf<Bool>] { gelaufen.filter(\.wert) }
    public var ofenbalken: [Lauf<Bool>] { ofen.filter(\.wert) }

    // MARK: - Was es überhaupt gibt

    public var preisspanne: ClosedRange<Double>?
    public var sonneMax: Double = 0
    public var hatOfen = false
    /// Ob für diesen Tag ein Fahrplan aufbewahrt ist. Ohne ihn fehlt die Spur der Absicht ganz,
    /// „statt ein Nein vorzutäuschen“ (`Tagesuhr.tsx:23-26`).
    public var hatAbsicht = false
    public var hatPreis = false
    public var hinweise: [String] = []

    /// Die Flächen des Bands von oben nach unten (`Tagesband.tsx:67-78`).
    public var bandflaechen: [Bandflaeche] {
        var aus: [Bandflaeche] = [
            Bandflaeche(art: .kw, name: "kW", hoehe: 58),
            Bandflaeche(art: .preis, name: "ct/kWh", hoehe: 30),
            // Ohne aufbewahrten Fahrplan trägt die Zeile ein Fragezeichen statt eines Namens.
            Bandflaeche(art: .geplant, name: hatAbsicht ? "geplant" : "geplant ?", hoehe: 8),
            Bandflaeche(art: .gelaufen, name: "gelaufen", hoehe: 13),
        ]
        if hatOfen {
            aus.append(Bandflaeche(art: .ofen, name: "Ofen", hoehe: 13))
        }
        return aus
    }

    /// Die Legende der Uhr, in der Reihenfolge der Ringe von außen nach innen
    /// (`Tagesuhr.tsx:288-313`).
    public var legende: [Legendeneintrag] {
        var aus: [Legendeneintrag] = []
        if let p = preisspanne {
            aus.append(
                Legendeneintrag(
                    wort: "Preis · \(Formate.zahl(p.lowerBound, stellen: 0)) bis "
                        + "\(Formate.zahl(p.upperBound, stellen: 0)) ct, heller ist teurer",
                    marke: .preis))
        } else {
            aus.append(Legendeneintrag(wort: "Preis · nicht erfasst", marke: .preis))
        }
        if sonneMax > 0 {
            aus.append(
                Legendeneintrag(
                    wort: "Sonne · bis \(Formate.zahl(sonneMax, stellen: 1)) kW, heller ist mehr",
                    marke: .sonne))
        } else {
            aus.append(Legendeneintrag(wort: "Sonne · keine an diesem Tag", marke: .sonne))
        }
        aus.append(
            Legendeneintrag(
                wort: hatAbsicht
                    ? "Wärmepumpe geplant" : "Wärmepumpe geplant · kein Fahrplan aufbewahrt",
                marke: .waermepumpe, umriss: true))
        aus.append(Legendeneintrag(wort: "Wärmepumpe gelaufen", marke: .waermepumpe))
        if hatOfen {
            aus.append(Legendeneintrag(wort: "Pelletofen gebrannt", marke: .ofen))
        }
        return aus
    }

    // MARK: - Bauen

    public static func baue(_ d: AnlageReplayOut) -> Wiedergabebild {
        var b = Wiedergabebild()
        b.tag = d.day
        b.schrittMin = d.stepMin
        b.schritt = TimeInterval(max(1, d.stepMin) * 60)
        b.erwartet = d.erwartet
        b.hinweise = d.hinweiseDe
        // Fehlt die Tagesgrenze, trägt der Ring keine Achse; die Zeitstempel der Bilder springen
        // dafür nicht ein, denn ein Tag, der um 09:00 anfängt, wäre eine andere Uhr.
        guard let von = Zeit.ausIso(d.von), let bis = Zeit.ausIso(d.bis), bis > von else {
            return b
        }
        b.von = von
        b.bis = bis
        b.stundenImTag = max(1, Int((bis.timeIntervalSince(von) / 3600).rounded()))

        // Ein Bild ohne lesbaren Zeitstempel ist kein Bild: es fiele im Ring an eine erfundene
        // Stelle. Die Reihen werden darum über denselben gefilterten Satz gerechnet, damit
        // Preis, Absicht und Bild an jedem Index zusammenpassen.
        let bilder: [(AnlageOut, Date, Int)] = d.frames.enumerated().compactMap { i, f in
            guard let t = Zeit.ausIso(f.at) else { return nil }
            return (f, t, i)
        }
        guard !bilder.isEmpty else { return b }
        let zeiten = bilder.map(\.1)
        b.zeitpunkte = zeiten
        if let erste = zeiten.first, let letzte = zeiten.last, erste < letzte {
            b.bandspanne = erste...letzte
        }

        func preisBei(_ i: Int) -> Double? {
            i < d.preisCtKwh.count ? d.preisCtKwh[i] : nil
        }
        func absichtBei(_ i: Int) -> Bool? {
            i < d.geplantWp.count ? d.geplantWp[i] : nil
        }

        let preise = bilder.compactMap { preisBei($0.2) }.filter(\.isFinite)
        if let klein = preise.min(), let gross = preise.max() {
            b.preisspanne = klein...gross
            b.hatPreis = true
        }
        b.sonneMax = max(0, bilder.compactMap { $0.0.strom.pvKw }.filter(\.isFinite).max() ?? 0)
        b.hatOfen = bilder.contains { $0.0.ofen.present }
        b.hatAbsicht = bilder.contains { absichtBei($0.2) != nil }

        let schritt = b.schritt
        b.spur = laeufe(bilder.map { _ in true }, zeiten: zeiten, schritt: schritt)
        b.preisringe = laeufe(
            bilder.map { _, _, i -> Int? in
                guard let p = preisBei(i), let spanne = b.preisspanne else { return nil }
                return stufe(
                    wert: p, min: spanne.lowerBound, max: spanne.upperBound,
                    anzahl: stufen.count)
            }, zeiten: zeiten, schritt: schritt)
        b.sonnenringe = laeufe(
            bilder.map { f, _, _ -> Int? in
                // Unter 0,05 kW gilt als nichts: dieselbe Schwelle, mit der `Formate.kw` eine
                // Null schreibt - sonst stünde eine Nachtmessung von 0,004 kW als Ringstück da.
                guard let kw = f.strom.pvKw, kw > 0.05, b.sonneMax > 0 else { return nil }
                return stufe(wert: kw, min: 0, max: b.sonneMax, anzahl: stufen.count)
            }, zeiten: zeiten, schritt: schritt)
        b.geplant = laeufe(
            bilder.map { _, _, i in absichtBei(i) }, zeiten: zeiten, schritt: schritt)
        b.gelaufen = laeufe(
            bilder.map { f, _, _ -> Bool? in f.waermepumpe.running }, zeiten: zeiten,
            schritt: schritt)
        b.ofen = laeufe(
            bilder.map { f, _, _ -> Bool? in f.ofen.present ? f.ofen.running : nil },
            zeiten: zeiten, schritt: schritt)

        b.sonne = bilder.map { Punkt(zeit: $0.1, wert: $0.0.strom.pvKw) }
        b.netz = bilder.map { Punkt(zeit: $0.1, wert: $0.0.strom.gridKw) }
        b.preis = bilder.map { Punkt(zeit: $0.1, wert: preisBei($0.2)) }
        return b
    }

    // MARK: - Greifen

    /// Das Bild, dessen Zeit `zeit` am nächsten liegt - für den Griff ins Band.
    ///
    /// **Das nächste Bild, kein interpolierter Wert** (`Tagesband.tsx:181-182`): „zwischen zwei
    /// Bildern liegt nichts, was gemessen wäre.“
    public func naechsteStelle(zu zeit: Date) -> Int? {
        guard !zeitpunkte.isEmpty else { return nil }
        var beste = 0
        var abstand = Double.infinity
        for (i, t) in zeitpunkte.enumerated() {
            let d = abs(t.timeIntervalSince(zeit))
            if d < abstand {
                abstand = d
                beste = i
            }
        }
        return beste
    }

    /// Den Tagesanteil einer Stelle - wohin der Zeiger der Uhr zeigt.
    public func anteil(stelle: Int) -> Double? {
        guard stelle >= 0, stelle < zeitpunkte.count, bis > von else { return nil }
        return Tagesuhrgeometrie.anteil(zeitpunkte[stelle], von: von, bis: bis)
    }

    // MARK: - Die Sätze zu einer Stelle

    /// Die drei Zeilen in der Mitte der Uhr (`Tagesuhr.tsx:271-285`).
    ///
    /// Die Zeit kommt aus dem Zeitstempel des Bildes und steht in der Zeit des Hauses: „das
    /// Zifferblatt zählt vom Tagesbeginn des Hauses, die Schrift zählte vom Gerät aus“
    /// (`Wiedergabe.tsx:45-52`).
    public func mitte(_ d: AnlageReplayOut, stelle: Int) -> (zeit: String, sonne: String, pumpe: String)? {
        guard stelle >= 0, stelle < zeitpunkte.count, stelle < d.frames.count else { return nil }
        let f = d.frames[stelle]
        var sonne = f.strom.pvKw == nil
            ? "Sonne ?" : "Sonne \(Formate.zahl(f.strom.pvKw, stellen: 1)) kW"
        if stelle < d.preisCtKwh.count, let p = d.preisCtKwh[stelle] {
            sonne += " · \(Formate.zahl(p, stellen: 0)) ct"
        }
        var pumpe = f.waermepumpe.running ? "Wärmepumpe läuft" : "Wärmepumpe steht"
        if stelle < d.geplantWp.count, let a = d.geplantWp[stelle] {
            pumpe += a ? " · geplant" : " · nicht geplant"
        }
        return (Formate.hhmm(zeitpunkte[stelle]), sonne, pumpe)
    }

    /// Der Inhalt der Fahne über dem Band (`Tagesband.tsx:188-206`).
    ///
    /// **Ein fehlender Wert ist hier ein „?“ und kein Strich.** So schreibt es die Vorlage
    /// (`Tagesband.tsx:200, 201, 205`: `b.strom.pv_kw == null ? "?" : …`), und so steht es drei
    /// Zentimeter darüber in der Uhrmitte (``mitte(_:stelle:)``, `Tagesuhr.tsx:279`). Mit
    /// ``Formate/leer`` las sich derselbe fehlende Wert auf einem Schirm zweimal verschieden -
    /// in der Uhr ein Fragezeichen, im Band ein Strich.
    public func fahne(_ d: AnlageReplayOut, stelle: Int) -> (zeit: String, zeilen: [Fahnenzeile])? {
        guard stelle >= 0, stelle < zeitpunkte.count, stelle < d.frames.count else { return nil }
        let f = d.frames[stelle]
        var zeilen: [Fahnenzeile] = [
            Fahnenzeile(
                satz: "Sonne " + (f.strom.pvKw == nil
                    ? "?" : "\(Formate.zahl(f.strom.pvKw, stellen: 1)) kW"),
                marke: .sonne)
        ]
        var netzsatz = "Netz " + (f.strom.gridKw == nil
            ? "?" : "\(Formate.zahl(f.strom.gridKw, stellen: 1)) kW")
        if stelle < d.preisCtKwh.count, let p = d.preisCtKwh[stelle] {
            netzsatz += " · \(Formate.zahl(p, stellen: 1)) ct/kWh"
        }
        zeilen.append(Fahnenzeile(satz: netzsatz, marke: .preis))
        if f.waermepumpe.running {
            let leistung = f.waermepumpe.powerKw == nil
                ? "" : ", \(Formate.zahl(f.waermepumpe.powerKw, stellen: 1)) kW"
            zeilen.append(Fahnenzeile(satz: "Wärmepumpe läuft" + leistung, marke: .waermepumpe))
        } else {
            zeilen.append(Fahnenzeile(satz: "Wärmepumpe steht", marke: .waermepumpe))
        }
        let absicht = stelle < d.geplantWp.count ? d.geplantWp[stelle] : nil
        zeilen.append(
            Fahnenzeile(satz: Wiedergabeworte.absichtssatz(absicht), marke: nil, eingerueckt: true))
        if f.ofen.present {
            let wort = f.ofen.running == nil
                ? "?" : (f.ofen.running == true ? "brennt" : "aus")
            zeilen.append(Fahnenzeile(satz: "Ofen " + wort, marke: .ofen))
        }
        return (Formate.hhmm(zeitpunkte[stelle]), zeilen)
    }

    // MARK: - Die Kopfzahl

    /// „288 von 288 Bildern · 5-Minuten-Schritt“ (`Wiedergabe.tsx:197-201`).
    ///
    /// **Sie steht da, auch wenn nichts fehlt.** Eine Zahl, die nur im Fehlerfall erscheint,
    /// lässt im Normalfall offen, ob überhaupt nachgesehen wurde.
    public var kopfzahl: String {
        "\(anzahl) von \(erwartet) Bildern · \(schrittMin)-Minuten-Schritt"
    }
}
