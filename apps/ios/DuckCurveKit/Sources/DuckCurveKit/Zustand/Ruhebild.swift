import Foundation

/// Das Ruhebild: was die Wand zeigt, wenn niemand sie berührt.
///
/// **Die Idee** (`apps/web/src/components/home/ambiente.ts`). Die Startseite ist eine Bedienung:
/// Reiter, Kacheln, ein Dock. Das ist richtig, solange jemand davorsteht. Den ganzen Tag über
/// steht niemand davor, und dann ist eine Bedienung nur Unruhe in der Küche. Nach fünf Minuten
/// bleibt deshalb das übrig, was man aus drei Metern liest.
///
/// **Zwei Bilder, und die Sonne entscheidet.** Am Tag ist die Sonne die Nachricht, am Abend der
/// Preis und der Puffer. Umgeschaltet wird nach Aufgang und Untergang der Sonne am Standort des
/// Hauses, die der Fahrplan mitbringt. Das wechselt zweimal am Tag und nicht alle fünf Minuten,
/// wie es eine Schwelle auf die gemessene Leistung täte - eine Wolke um 13 Uhr ist kein Abend.
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

    /// Ab dieser erwarteten Leistung zählt eine Viertelstunde als Erzeugung. Nur für den Ersatz
    /// in ``sonnenlauf(_:jetzt:)``.
    public static let sonneAbKw = 0.05
    /// Erzeugt die Anlage so viel, ist es Tag, auch wenn der Fahrplan nichts vom Sonnenlauf weiß.
    public static let trotzdemTagAbKw = 0.3
    /// Rasterweite einer Viertelstunde. Sie wird auf das letzte helle Intervall addiert, damit
    /// `bis` das Ende dieser Viertelstunde ist und nicht ihr Anfang.
    public static let schritt: TimeInterval = 15 * 60
    /// So viel Luft links und rechts vom Sonnenlauf, damit der Bogen nicht am Rand klebt.
    public static let luft: TimeInterval = 30 * 60

    // MARK: - Der Sonnenlauf

    /// Aufgang und Untergang des heutigen Tages, dazu die Prognose in diesem Fenster.
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

        /// Die Prognose zwischen Aufgang und Untergang, mit einer halben Stunde Luft an beiden
        /// Enden - also einschliesslich der dunklen Punkte davor und danach.
        public let punkte: [Punkt]
        /// Aufgang und Untergang der Sonne.
        public let von: Date
        public let bis: Date

        public init(punkte: [Punkt], von: Date, bis: Date) {
            self.punkte = punkte
            self.von = von
            self.bis = bis
        }
    }

    /// Aufgang und Untergang je Tag, wie der Fahrplan sie mitbringt, nach der Zeit geordnet.
    static func sonnentage(_ plan: PlanOut?) -> [(von: Date, bis: Date)] {
        (plan?.sun ?? [])
            .compactMap { tag -> (von: Date, bis: Date)? in
                guard let von = Zeit.ausIso(tag.sunrise), let bis = Zeit.ausIso(tag.sunset), bis > von
                else { return nil }
                return (von, bis)
            }
            .sorted { $0.von < $1.von }
    }

    /// Der Sonnenlauf des heutigen Tages: Aufgang und Untergang am Standort des Hauses. `nil`,
    /// wenn der Plan nichts dazu sagt.
    ///
    /// **Nicht mehr aus der Ertragsprognose.** Bis zum 26.11.2026 galten als Aufgang und Untergang
    /// die erste und die letzte Viertelstunde, in der die Prognose mehr als 50 Watt kannte. An
    /// jenem Tag standen damit 08:45 und 16:45 an den Enden des Bogens, die Sonne ging aber um
    /// 08:09 auf und um 16:36 unter; um 09:17 saß sie im Bild noch am Horizont (Hausherr: „Es
    /// passt doch nicht“). Der Dienst rechnet die Zeiten jetzt aus Datum und Standort und gibt
    /// sie im Fahrplan mit (`plan.sun`).
    ///
    /// **Der Ersatz.** Ein Dienst vor diesem Tag schickt `sun` nicht mit. Dann gilt wie vorher
    /// das Fenster der erwarteten Erzeugung: ein ungefährer Himmel ist besser als keiner, und
    /// Dienst und App werden nicht im selben Augenblick erneuert.
    public static func sonnenlauf(_ plan: PlanOut?, jetzt: Date) -> Sonnenlauf? {
        guard let tag = Tageskacheln.fenster(.heute, jetzt: jetzt) else { return nil }
        let alle =
            (plan?.intervals ?? [])
            .compactMap { iv -> Sonnenlauf.Punkt? in
                guard let t = Zeit.ausIso(iv.ts), t >= tag.von, t < tag.bis else { return nil }
                return Sonnenlauf.Punkt(zeit: t, kw: iv.expectedPvKw)
            }
            .sorted { $0.zeit < $1.zeit }
        let von: Date
        let bis: Date
        if let heute = sonnentage(plan).first(where: { $0.von >= tag.von && $0.von < tag.bis }) {
            (von, bis) = heute
        } else {
            let hell = alle.filter { $0.kw > sonneAbKw }
            guard let erste = hell.first, let letzte = hell.last else { return nil }
            von = erste.zeit
            bis = letzte.zeit.addingTimeInterval(schritt)
        }
        let punkte = alle.filter {
            $0.zeit >= von.addingTimeInterval(-luft) && $0.zeit <= bis.addingTimeInterval(luft)
        }
        return Sonnenlauf(punkte: punkte, von: von, bis: bis)
    }

    /// Wann die Sonne das nächste Mal aufgeht: heute, wenn es noch vor dem Aufgang ist, sonst
    /// morgen. Weiß der Fahrplan nichts vom Sonnenlauf, gilt der Beginn der Erzeugung aus dem
    /// Ausblick (`ambiente.ts`, `naechsterAufgang`).
    public static func naechsterAufgang(_ plan: PlanOut?, jetzt: Date, blick: Ausblick) -> Date? {
        let tage = sonnentage(plan)
        if !tage.isEmpty { return tage.first { $0.von > jetzt }?.von }
        return blick.nacht ? blick.sonneWechsel : nil
    }

    // MARK: - Welches der beiden Bilder gilt

    public enum Bild: String, Sendable, Hashable {
        case tag, abend
    }

    /// Tag zwischen Aufgang und Untergang - sonst nur, wenn die Anlage trotzdem liefert.
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
    ///
    /// **`zuerst` sind die Befunde, die der Dienst nicht haben kann** - heute genau einer: der
    /// Abstand der beiden Uhren (``Hausuhr/befund``). Er steht vor den Warnungen des Dienstes,
    /// und zwar aus demselben Grund, aus dem er ueberhaupt dasteht: solange die Uhren
    /// auseinandergehen, ist jeder Zeitstempel unter ihm fraglich - aber **hinter** dessen
    /// Alarmen, denn hier gibt es nur einen Platz, und „eine Quelle schweigt ganz" wiegt mehr
    /// als „die Zeitstempel sind fraglich". Beides rechnet
    /// ``Wachbefunde/zeilen(_:zuerst:hoechstens:)``, mitsamt der Begruendung und der Messung -
    /// hier wird nur auf eine Zeile beschnitten, statt eine zweite Reihenfolge zu behaupten.
    public static func schwersterBefund(
        _ wache: [WatchFindingOut]?, zuerst: [Wachbefunde.Zeile] = []
    ) -> Wachbefunde.Zeile? {
        Wachbefunde.zeilen(wache ?? [], zuerst: zuerst, hoechstens: 1).first
    }
}
