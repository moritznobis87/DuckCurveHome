import Foundation

/// Die nächsten 24 Stunden: was in ihnen kommt, und was man daraus macht.
///
/// **Warum es das gibt.** Die Startseite sagt, was gerade ist, in Kilowatt. Was ein Mensch im
/// Haus daraus machen soll, sagt sie nicht: „Strom gerade 38,3 ct" ist eine Zahl ohne Maß. Am
/// Telefon stand dort in der App nur die Karte „Als Nächstes" mit drei Uhrzeiten. Die Vorlage
/// (`apps/web/src/components/home/ausblick.ts` und `Ausblick.tsx`) beantwortet stattdessen drei
/// Fragen, die man sich mit dem Telefon in der Hand stellt:
///
/// - Ist Strom gerade teuer oder günstig? Gemessen an den nächsten 24 Stunden, nicht an einer
///   festen Grenze: 30 ct sind im Januar günstig und im Mai teuer.
/// - Wann ist er am günstigsten, und wann scheint die Sonne? Das ist die Auskunft für alles, was
///   sich verschieben lässt: Waschmaschine, Spülmaschine, Trockner.
/// - Wann läuft die Wärmepumpe das nächste Mal?
///
/// Reine Rechnung auf dem Fahrplan, den die Seite ohnehin hat. Keine Annahme über den
/// Hausverbrauch: das Sonnenfenster ist die Zeit der höchsten erwarteten Erzeugung, nicht eine
/// Zusage, dass Überschuss da ist.
public struct Ausblick: Sendable, Equatable {

    /// Eine Viertelstunde des Ausblicks.
    public struct Zelle: Sendable, Hashable {
        public let zeit: Date
        public let preis: Double?
        public let pv: Double
        /// Nur was der Optimierer geplant hat. Wo die Preisregel einspringt, steht kein Fahrplan.
        public let wp: Bool
        public let ofen: Bool
    }

    /// Ein Fenster von zwei Stunden: so lange läuft eine Waschmaschine.
    public struct Fenster: Sendable, Hashable {
        public let von: Date
        public let bis: Date
        /// Mittlerer Preis in ct/kWh beim Preisfenster, mittlere erwartete Leistung in kW beim
        /// Sonnenfenster.
        public let mittel: Double
    }

    /// Wo der jetzige Preis unter den bekannten Preisen der nächsten 24 Stunden liegt.
    public enum Preislage: String, Sendable, Hashable {
        case guenstig, mittel, teuer, gleichmaessig

        public var satz: String {
            switch self {
            case .guenstig: return "Strom ist gerade günstig"
            case .mittel: return "Strom ist gerade weder günstig noch teuer"
            case .teuer: return "Strom ist gerade teuer"
            case .gleichmaessig: return "Der Preis ändert sich heute kaum"
            }
        }
    }

    /// Welche Farbe der Punkt vor einem Satz hat - die Ansicht setzt sie ein.
    public enum Marke: String, Sendable, Hashable {
        case waermepumpe, ofen, guenstig, sonne
    }

    public struct Satz: Sendable, Hashable, Identifiable {
        public let marke: Marke
        public let text: String
        public var id: String { marke.rawValue }
    }

    // MARK: - Maße

    /// Eine Zelle ist eine Viertelstunde.
    public static let schritt: TimeInterval = 15 * 60
    /// Der Ausblick reicht 24 Stunden.
    public static let zellenzahl = 96
    /// Ein Fenster für verschiebbare Verbraucher: zwei Stunden.
    public static let fensterZellen = 8
    /// Unter dieser Spanne zwischen billigstem und teuerstem Preis lohnt kein Verschieben.
    public static let minSpanneCt: Double = 4
    /// Ab dieser erwarteten Leistung gilt die Sonne als da; darunter ist Dämmerung oder Nacht.
    public static let sonneAbKw: Double = 0.05
    /// Ein Sonnenfenster wird nur genannt, wenn die Erwartung darin im Mittel so hoch ist.
    public static let sonnenfensterAbKw: Double = 1.0

    // MARK: - Was drinsteht

    public var zellen: [Zelle] = []
    public var preisJetzt: Double?
    public var preisMin: Double?
    public var preisMax: Double?
    public var lage: Preislage?
    /// Die günstigsten zwei Stunden am Stück. Fehlt, wenn die Preise kaum auseinanderliegen.
    public var guenstig: Fenster?
    /// Die zwei Stunden mit der meisten erwarteten Sonne. Fehlt an einem trüben Tag.
    public var sonne: Fenster?
    /// Die höchste erwartete Erzeugung im Ausblick, in kW.
    public var pvMax: Double = 0
    /// Es ist dunkel: keine Erzeugung erwartet.
    public var nacht = false
    /// Wann die Sonne wiederkommt, wenn es dunkel ist; wann sie geht, wenn sie scheint.
    public var sonneWechsel: Date?
    /// Bis wohin Preise bekannt sind, wenn nicht für den ganzen Ausblick.
    public var preiseBis: Date?
    /// Hat der Optimierer überhaupt einen Fahrplan gelegt? Ohne ihn wird kein Lauf behauptet.
    public var hatFahrplan = false

    /// Unter acht Zellen ist es kein Ausblick, sondern ein Rest. Die Ansicht zeigt dann nichts.
    public var tragfaehig: Bool { zellen.count >= Self.fensterZellen }

    // MARK: - Bauen

    public static func baue(_ plan: PlanOut?, jetzt: Date) -> Ausblick {
        let ende = jetzt.addingTimeInterval(Double(zellenzahl) * schritt)
        let roh = (plan?.intervals ?? []).compactMap { iv -> (PlanIntervalOut, Date)? in
            guard let t = Zeit.ausIso(iv.ts) else { return nil }
            return (iv, t)
        }
        // Die laufende Viertelstunde gehört dazu: in ihr steht der Preis von jetzt.
        let drin =
            roh
            .filter { $0.1.addingTimeInterval(schritt) > jetzt && $0.1 < ende }
            .sorted { $0.1 < $1.1 }
            .prefix(zellenzahl)

        var a = Ausblick()
        a.zellen = drin.map { iv, t in
            Zelle(
                zeit: t, preis: iv.priceCtKwh, pv: max(0, iv.expectedPvKw),
                wp: iv.reasonCode == "planned_optimizer" && iv.plannedHpState == .release,
                ofen: iv.plannedStoveOn == true)
        }
        a.hatFahrplan = (plan?.intervals ?? []).contains { $0.reasonCode == "planned_optimizer" }

        let preise = a.zellen.compactMap(\.preis)
        a.preisJetzt = a.zellen.first?.preis
        a.preisMin = preise.min()
        a.preisMax = preise.max()
        let spanne = (a.preisMax ?? 0) - (a.preisMin ?? 0)

        if let jetztPreis = a.preisJetzt, preise.count >= fensterZellen {
            if spanne < minSpanneCt {
                a.lage = .gleichmaessig
            } else {
                let r = rang(jetztPreis, preise)
                a.lage = r < 1.0 / 3 ? .guenstig : (r > 2.0 / 3 ? .teuer : .mittel)
            }
        }

        a.guenstig =
            spanne >= minSpanneCt
            ? bestesFenster(a.zellen, fensterZellen, { $0.preis }, kleinstes: true) : nil
        let sonnigstes = bestesFenster(a.zellen, fensterZellen, { $0.pv }, kleinstes: false)
        a.sonne = (sonnigstes?.mittel ?? 0) >= sonnenfensterAbKw ? sonnigstes : nil

        a.pvMax = a.zellen.reduce(0) { max($0, $1.pv) }
        a.nacht = (a.zellen.first?.pv ?? 1) < sonneAbKw
        a.sonneWechsel = a.zellen.dropFirst()
            .first { a.nacht ? $0.pv >= sonneAbKw : $0.pv < sonneAbKw }?.zeit

        if let letzter = a.zellen.last(where: { $0.preis != nil }) {
            let bis = letzter.zeit.addingTimeInterval(schritt)
            a.preiseBis = bis < ende.addingTimeInterval(-schritt) ? bis : nil
        }
        return a
    }

    /// Anteil der Preise, die unter `p` liegen. 0 ist der billigste Moment, 1 der teuerste.
    static func rang(_ p: Double, _ alle: [Double]) -> Double {
        guard alle.count >= 2 else { return 0.5 }
        return Double(alle.filter { $0 < p }.count) / Double(alle.count - 1)
    }

    /// Das Fenster aus `n` Zellen am Stück mit dem kleinsten oder größten Mittel.
    static func bestesFenster(
        _ zellen: [Zelle], _ n: Int, _ wert: (Zelle) -> Double?, kleinstes: Bool
    ) -> Fenster? {
        guard n > 0, zellen.count >= n else { return nil }
        var bestes: Fenster?
        for i in 0...(zellen.count - n) {
            var summe = 0.0
            var vollstaendig = true
            for j in i..<(i + n) {
                // Zellen müssen lückenlos aufeinander folgen: ein Fenster über eine Lücke im
                // Fahrplan wäre länger als zwei Stunden.
                guard let w = wert(zellen[j]),
                    j == i || abs(zellen[j].zeit.timeIntervalSince(zellen[j - 1].zeit) - schritt) < 1
                else {
                    vollstaendig = false
                    break
                }
                summe += w
            }
            guard vollstaendig else { continue }
            let mittel = summe / Double(n)
            let besser =
                bestes == nil
                || (kleinstes ? mittel < bestes!.mittel - 1e-9 : mittel > bestes!.mittel + 1e-9)
            if besser {
                bestes = Fenster(
                    von: zellen[i].zeit,
                    bis: zellen[i + n - 1].zeit.addingTimeInterval(schritt), mittel: mittel)
            }
        }
        return bestes
    }

    /// Zusammenhängende Abschnitte, in denen `an` gilt, als Zellennummern.
    public static func abschnitte(_ zellen: [Zelle], an: (Zelle) -> Bool) -> [Range<Int>] {
        var aus: [Range<Int>] = []
        var start = -1
        for (i, z) in zellen.enumerated() {
            let ja = an(z)
            if ja, start < 0 { start = i }
            if !ja, start >= 0 {
                aus.append(start..<i)
                start = -1
            }
        }
        if start >= 0 { aus.append(start..<zellen.count) }
        return aus
    }

    // MARK: - Die Sätze darunter

    public var laeufe: [Range<Int>] { Self.abschnitte(zellen, an: \.wp) }
    public var braende: [Range<Int>] { Self.abschnitte(zellen, an: \.ofen) }

    /// Zeit einer Zellennummer - auch der Zellennummer *nach* der letzten, als deren Ende.
    public func zeit(zelle: Int) -> Date? {
        guard let erste = zellen.first else { return nil }
        return erste.zeit.addingTimeInterval(Double(zelle) * Self.schritt)
    }

    /// „11:30" heute, „morgen 11:30" am nächsten Tag.
    public static func wann(_ t: Date, jetzt: Date) -> String {
        let morgen = Tag.iso(t) != Tag.iso(jetzt)
        return (morgen ? "morgen " : "") + Formate.hhmm(t)
    }

    static func vonBis(_ von: Date, _ bis: Date, jetzt: Date) -> String {
        "\(wann(von, jetzt: jetzt)) bis \(Formate.hhmm(bis))"
    }

    /// Die Sätze unter dem Bild, in der Reihenfolge der Vorlage.
    public func saetze(jetzt: Date) -> [Satz] {
        var aus: [Satz] = []

        if hatFahrplan {
            if let lauf = laeufe.first, let von = zeit(zelle: lauf.lowerBound),
                let bis = zeit(zelle: lauf.upperBound)
            {
                aus.append(
                    Satz(
                        marke: .waermepumpe,
                        text: lauf.lowerBound == 0
                            ? "Die Wärmepumpe soll bis \(Formate.hhmm(bis)) laufen."
                            : "Die Wärmepumpe soll von \(Self.vonBis(von, bis, jetzt: jetzt)) laufen."
                    ))
            } else {
                aus.append(
                    Satz(
                        marke: .waermepumpe,
                        text: "Die Wärmepumpe hat in den nächsten 24 Stunden keinen geplanten Lauf."
                    ))
            }
        }
        if let brand = braende.first, let von = zeit(zelle: brand.lowerBound),
            let bis = zeit(zelle: brand.upperBound)
        {
            aus.append(
                Satz(
                    marke: .ofen,
                    text: "Der Pelletofen soll von \(Self.vonBis(von, bis, jetzt: jetzt)) brennen."))
        }
        if let g = guenstig {
            aus.append(
                Satz(
                    marke: .guenstig,
                    text:
                        "Am günstigsten ist Netzstrom von \(Self.vonBis(g.von, g.bis, jetzt: jetzt)), im Mittel \(Formate.zahl(g.mittel, stellen: 0)) ct."
                ))
        }
        if let s = sonne {
            aus.append(
                Satz(
                    marke: .sonne,
                    text: "Die meiste Sonne gibt es von \(Self.vonBis(s.von, s.bis, jetzt: jetzt))."))
        }
        return aus
    }

    /// Der Hinweis auf die verschiebbaren Verbraucher - nur wenn es eine Zeit zu nennen gibt.
    public var verschiebesatz: String? {
        (guenstig != nil || sonne != nil)
            ? "Die beiden Zeiten sind die besten für alles, was warten kann: Waschmaschine, Spülmaschine, Trockner."
            : nil
    }

    public func preissatz(jetzt: Date) -> String? {
        preiseBis.map {
            "Preise sind bis \(Self.wann($0, jetzt: jetzt)) bekannt; die für morgen kommen am frühen Nachmittag."
        }
    }

    /// Eine Beschriftung der Zeitachse.
    public struct Achsenmarke: Sendable, Hashable, Identifiable {
        public let zelle: Int
        public let text: String
        public var id: Int { zelle }
        /// Wo sie steht, als Anteil der ganzen Breite.
        public var anteil: Double { Double(zelle) / Double(Ausblick.zellenzahl) }
    }

    /// Jede volle sechste Stunde der Hausuhr. Die erste Marke der Ansicht ist „jetzt", darum
    /// beginnt diese Liste erst bei Zelle 6 - sonst stünden zwei Wörter übereinander.
    public var achsenmarken: [Achsenmarke] {
        zellen.enumerated().compactMap { i, z in
            let t = Kalender.haus.dateComponents([.hour, .minute], from: z.zeit)
            guard t.minute == 0, let stunde = t.hour, stunde % 6 == 0,
                i >= 6, i <= Self.zellenzahl - 4
            else { return nil }
            return Achsenmarke(zelle: i, text: "\(stunde) Uhr")
        }
    }

    /// Wo der jetzige Preis auf der Spur von billigst bis teuerst sitzt - 0 bis 1.
    public var stelle: Double? {
        guard let p = preisJetzt, let lo = preisMin, let hi = preisMax, hi > lo else { return nil }
        return Achse.anteil(p, in: lo...hi)
    }
}
