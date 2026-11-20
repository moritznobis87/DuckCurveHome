import Foundation

/// Das Ruhebild: was die Wand zeigt, wenn niemand sie berührt.
///
/// **Die Idee** (`apps/web/src/components/home/ambiente.ts`). Die Startseite ist eine Bedienung:
/// Reiter, Kacheln, ein Dock. Das ist richtig, solange jemand davorsteht. Den ganzen Tag über
/// steht niemand davor, und dann ist eine Bedienung nur Unruhe in der Küche. Nach fünf Minuten
/// bleibt deshalb das übrig, was man aus drei Metern liest.
///
/// **Zwei Bilder, und die Sonne entscheidet.** Am Tag ist die Sonne die Nachricht, am Abend der
/// Preis und der Puffer. Umgeschaltet wird nicht nach der Uhr, sondern nach dem Sonnenlauf aus
/// dem Fahrplan: Solange die Prognose Erzeugung kennt, gilt der Tag. Das wechselt zweimal am Tag
/// und nicht alle fünf Minuten, wie es eine Schwelle auf die gemessene Leistung täte - eine Wolke
/// um 13 Uhr ist kein Abend.
///
/// **Warum eigene Rechnung und nicht `Ausblick`.** `Ausblick` rechnet auf dem Fenster
/// `jetzt … jetzt+24 h`. Der Sonnenbogen braucht den Kalendertag: sonst wäre am Nachmittag die
/// linke Hälfte des Bogens der morgige Tag. Und `Tageskurve.pvErwartet` beginnt für heute erst bei
/// `jetzt - 15 min`, damit keine Prognose über eine Messung gelegt wird - der Bogen braucht genau
/// das Gegenteil: den ganzen erwarteten Tag, gefüllt nur bis jetzt.
///
/// Alles hier ist reine Rechnung, damit es Tests gibt; die Zeichnung steht in
/// `apps/ios/DuckCurveHome/Bausteine/Ambiente.swift`.
public enum Ruhebild {

    // MARK: - Maße

    /// Ab dieser erwarteten Leistung zählt eine Viertelstunde als Erzeugung.
    public static let sonneAbKw = 0.05
    /// Erzeugt die Anlage so viel, ist es Tag, auch wenn die Prognose nichts davon wusste.
    public static let trotzdemTagAbKw = 0.3
    /// Rasterweite einer Viertelstunde. Sie wird auf das letzte helle Intervall addiert, damit
    /// `bis` das Ende dieser Viertelstunde ist und nicht ihr Anfang.
    public static let schritt: TimeInterval = 15 * 60
    /// So viel Luft links und rechts vom Sonnenlauf, damit der Bogen nicht am Rand klebt.
    public static let luft: TimeInterval = 30 * 60

    // MARK: - Der Sonnenlauf

    /// Die Prognose des heutigen Tages im Fenster der Erzeugung.
    public struct Sonnenlauf: Sendable, Equatable {
        /// Eine Viertelstunde der Prognose.
        public struct Punkt: Sendable, Equatable {
            public let zeit: Date
            public let kw: Double

            public init(zeit: Date, kw: Double) {
                self.zeit = zeit
                self.kw = kw
            }
        }

        /// Die Prognose im Fenster der Erzeugung, mit einer halben Stunde Luft an beiden Enden -
        /// also einschliesslich der dunklen Punkte davor und danach.
        public let punkte: [Punkt]
        /// Beginn und Ende der erwarteten Erzeugung.
        public let von: Date
        public let bis: Date

        public init(punkte: [Punkt], von: Date, bis: Date) {
            self.punkte = punkte
            self.von = von
            self.bis = bis
        }
    }

    /// Der Sonnenlauf des heutigen Tages aus dem Fahrplan. `nil`, wenn der Plan nichts dazu sagt.
    public static func sonnenlauf(_ plan: PlanOut?, jetzt: Date) -> Sonnenlauf? {
        guard let tag = Tageskacheln.fenster(.heute, jetzt: jetzt) else { return nil }
        let alle =
            (plan?.intervals ?? [])
            .compactMap { iv -> Sonnenlauf.Punkt? in
                guard let t = Zeit.ausIso(iv.ts), t >= tag.von, t < tag.bis else { return nil }
                return Sonnenlauf.Punkt(zeit: t, kw: iv.expectedPvKw)
            }
            .sorted { $0.zeit < $1.zeit }
        let hell = alle.filter { $0.kw > sonneAbKw }
        guard let erste = hell.first, let letzte = hell.last else { return nil }
        let von = erste.zeit
        let bis = letzte.zeit.addingTimeInterval(schritt)
        let punkte = alle.filter {
            $0.zeit >= von.addingTimeInterval(-luft) && $0.zeit <= bis.addingTimeInterval(luft)
        }
        return Sonnenlauf(punkte: punkte, von: von, bis: bis)
    }

    // MARK: - Welches der beiden Bilder gilt

    public enum Bild: String, Sendable, Hashable {
        case tag, abend
    }

    /// Tag, solange die Prognose Erzeugung kennt - sonst nur, wenn die Anlage trotzdem liefert.
    ///
    /// Beide Grenzen zählen dazu: um Punkt Sonnenaufgang ist es schon Tag, um Punkt
    /// Sonnenuntergang noch.
    public static func bild(_ lauf: Sonnenlauf?, jetzt: Date, pvKw: Double?) -> Bild {
        if let lauf, jetzt >= lauf.von, jetzt <= lauf.bis { return .tag }
        if let pvKw, pvKw >= trotzdemTagAbKw { return .tag }
        return .abend
    }

    // MARK: - Die Aussicht

    /// Was der Tag noch bringt.
    public struct Aussicht: Sendable, Equatable {
        /// Was der ganze Tag bringen soll. Ändert sich im Tagesverlauf nicht.
        public let erwartetKwh: Double?
        /// Was ab jetzt noch kommt.
        public let restKwh: Double?
        /// Wann die Erzeugung endet.
        public let bis: Date?

        public init(erwartetKwh: Double?, restKwh: Double?, bis: Date?) {
            self.erwartetKwh = erwartetKwh
            self.restKwh = restKwh
            self.bis = bis
        }
    }

    public static func aussicht(_ plan: PlanOut?, jetzt: Date, lauf: Sonnenlauf?) -> Aussicht {
        guard let tag = Tageskacheln.fenster(.heute, jetzt: jetzt), let iv = plan?.intervals else {
            return Aussicht(erwartetKwh: nil, restKwh: nil, bis: lauf?.bis)
        }
        return Aussicht(
            erwartetKwh: Tageskacheln.pvSumme(iv, von: tag.von, bis: tag.bis),
            restKwh: Tageskacheln.pvSumme(iv, von: max(jetzt, tag.von), bis: tag.bis),
            bis: lauf?.bis
        )
    }

    // MARK: - Der Bogen

    /// Der Sonnenbogen des Tages: ein kleiner Verlauf ohne Achsen.
    ///
    /// Er sagt nicht, wie viel - das sagen die Zahlen daneben -, sondern **wo im Tag man steht**.
    /// Gefüllt ist, was hinter einem liegt. Darum ist die Breite der Sonnenlauf und nicht der
    /// Kalendertag: Ein Bogen von Mitternacht bis Mitternacht ist in der Mitte ein Hügel und an
    /// den Rändern Leere.
    ///
    /// **Der Kern rechnet Stellen, nicht Pfadtexte.** Die Vorlage gibt `d`-Attribute für SVG
    /// zurück; in Swift wären das Zeichenketten, die die Ansicht wieder zerlegen müsste. Hier
    /// kommen Punkte in demselben Koordinatenfeld (340 × 62, y nach unten), und die Ansicht zieht
    /// daraus ihren `Path`.
    public struct Bogen: Sendable, Equatable {
        public struct Stelle: Sendable, Equatable {
            public let x: Double
            public let y: Double

            public init(x: Double, y: Double) {
                self.x = x
                self.y = y
            }
        }

        /// Der ganze erwartete Verlauf.
        public let linie: [Stelle]
        /// Derselbe Verlauf bis jetzt. Leer vor Sonnenaufgang.
        public let bisJetzt: [Stelle]
        /// Wo die Marke „jetzt" steht, oder `nil`, wenn jetzt ausserhalb des Bogens liegt.
        public let jetztX: Double?
        public let breite: Double
        public let hoehe: Double

        public init(linie: [Stelle], bisJetzt: [Stelle], jetztX: Double?, breite: Double,
                    hoehe: Double) {
            self.linie = linie
            self.bisJetzt = bisJetzt
            self.jetztX = jetztX
            self.breite = breite
            self.hoehe = hoehe
        }
    }

    /// Mindestspitze, damit ein trüber Tag keinen aufgeblasenen Bogen bekommt.
    public static let bogenSpitzeMinKw = 0.5
    /// Luft über der Spitze, damit die Kurve den oberen Rand nie berührt.
    public static let bogenLuftOben: Double = 4

    public static func bogen(_ lauf: Sonnenlauf?, jetzt: Date, breite: Double = 340,
                             hoehe: Double = 62) -> Bogen? {
        let punkte = lauf?.punkte ?? []
        guard punkte.count >= 2, let erster = punkte.first, let letzter = punkte.last else {
            return nil
        }
        let von = erster.zeit
        let bis = letzter.zeit
        let spanne = bis.timeIntervalSince(von)
        guard spanne > 0 else { return nil }

        let spitze = max(bogenSpitzeMinKw, punkte.map(\.kw).max() ?? 0)
        func x(_ zeit: Date) -> Double { zeit.timeIntervalSince(von) / spanne * breite }
        func y(_ kw: Double) -> Double { hoehe - (kw / spitze) * (hoehe - bogenLuftOben) }
        func stelle(_ p: Sonnenlauf.Punkt) -> Bogen.Stelle {
            Bogen.Stelle(x: x(p.zeit), y: y(p.kw))
        }

        // An den Rändern keine Marke: dort stünde sie auf der Grundlinie und sagte nichts.
        let drin = jetzt > von && jetzt < bis
        var vorbei = punkte.filter { $0.zeit <= jetzt }
        if drin, let a = vorbei.last {
            // Der Punkt genau auf „jetzt": zwischen den beiden Viertelstunden eingeschoben, damit
            // die Fläche an der Marke endet und nicht bis zu 15 Minuten davor.
            let b = vorbei.count < punkte.count ? punkte[vorbei.count] : a
            let breiteMs = b.zeit.timeIntervalSince(a.zeit)
            let f = breiteMs > 0 ? jetzt.timeIntervalSince(a.zeit) / breiteMs : 0
            vorbei.append(Sonnenlauf.Punkt(zeit: jetzt, kw: a.kw + (b.kw - a.kw) * f))
        }

        return Bogen(
            linie: punkte.map(stelle),
            bisJetzt: vorbei.count > 1 ? vorbei.map(stelle) : [],
            jetztX: drin ? x(jetzt) : nil,
            breite: breite,
            hoehe: hoehe
        )
    }

    // MARK: - Der schwerste Befund

    /// Der Befund, der den Satz ersetzt - oder `nil`, wenn alles still ist.
    ///
    /// **Warum der erste und nicht der lauteste.** Der Dienst sortiert die Wache schon: Alarm vor
    /// Warnung, bei gleicher Schwere der ältere. Hier noch einmal zu sortieren hiesse, diese
    /// Reihenfolge ein zweites Mal zu behaupten (`apps/web/src/components/home/Wache.tsx`,
    /// `schwerster`).
    public static func schwersterBefund(_ wache: [WatchFindingOut]?) -> WatchFindingOut? {
        wache?.first
    }
}
