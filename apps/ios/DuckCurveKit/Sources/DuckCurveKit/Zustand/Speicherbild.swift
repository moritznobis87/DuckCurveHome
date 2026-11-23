import Foundation

// =====================================================================================
//  Die Speicherseite - alles Gerechnete.
//
//  Vorlage: `apps/web/src/components/reports/BatteryReport.tsx` mit `PeriodStrip.tsx` und
//  `SpeicherCheck.tsx`. Hier stehen die acht Kopfzahlen, die Gegenprobe aus dem Ladestand,
//  die vier Zeilen des Spannenstreifens und die Saetze, die die Seite ueber sich selbst sagt.
//  Keine Farben, keine Masse, keine Ansicht.
// =====================================================================================

/// Geladene und entladene Energie aus dem Ladestandsverlauf, unabhaengig von der
/// Leistungsmessung.
///
/// **Wozu eine zweite Rechnung fuer dieselbe Zahl.** Jede Zahl der Speicherseite kommt aus
/// einer einzigen Messreihe, der Leistung des Speichers. Die Gegenprobe zaehlt stattdessen die
/// Anstiege und Abstiege des Ladestands - zwei unabhaengige Wege zur selben Groesse. Laufen
/// sie auseinander, fehlen der Bilanz Minuten, und das gehoert auf die Seite und nicht in eine
/// Rueckfrage (`BatteryReport.tsx:85-88`).
///
/// **Es ist die Energie *im* Speicher, nicht die an den Klemmen.** An den Klemmen ist die
/// Ladung etwas groesser und die Entladung etwas kleiner, weil die Verluste dazwischenliegen.
/// Fuer die Frage „stimmt die Groessenordnung?“ reicht das genau (`BatteryReport.tsx:22-27`).
public struct Ladestandsenergie: Sendable, Hashable {
    /// Die Summe der Anstiege, mal Kapazitaet.
    public let ladung: Double
    /// Die Summe der Abstiege, mal Kapazitaet - als positive Zahl.
    public let entladung: Double
    /// Wie viele Minuten ueberhaupt einen Ladestand gemeldet haben.
    public let punkte: Int

    public init(ladung: Double, entladung: Double, punkte: Int) {
        self.ladung = ladung
        self.entladung = entladung
        self.punkte = punkte
    }
}

/// Was auf der Speicherseite gerechnet wird.
///
/// **Warum das nicht in der Seite steht.** Acht Kopfzahlen, vier davon abgeleitet, und jede
/// haengt an einer Schwelle: 0,2 kWh fuer „Netzladung ohne PV“ und „Verlust im Geraet“,
/// 0,5 kWh, bevor ein Wirkungsgrad ueberhaupt eine Aussage ist, 5 % Stundenmittel, ab denen die
/// Aufteilung auf PV und Netz geschaetzt heisst, und 25 % Abweichung, ab denen die Gegenprobe
/// widerspricht. Eine Schwelle in einer `View` prueft niemand nach.
public enum Speicherbild {

    // MARK: - Die Gegenprobe aus dem Ladestand

    /// Ladung und Entladung aus dem Ladestandsverlauf (`BatteryReport.tsx:29-41`).
    ///
    /// `nil` unter zehn Messpunkten oder ohne bekannte Kapazitaet: aus drei Minuten laesst sich
    /// kein Tag gegenrechnen, und ohne Kapazitaet ist ein Anteil keine Kilowattstunde.
    ///
    /// **Sortiert, anders als die Vorlage.** Dort kommen die Zeilen der Reihe nach aus dem
    /// Dienst. Eine Zeile, die zwischen zwei anderen aus der Reihe faellt, zaehlte hier einmal
    /// als Abstieg und einmal als Anstieg - beide Summen waeren zu gross, und zwar gleichmaessig
    /// genug, um nicht aufzufallen. ``Pruefkurve/baue(tag:raster:)`` sortiert an derselben
    /// Stelle aus demselben Grund.
    public static func ausLadestand(
        _ raster: [Pruefpunkt], kapazitaetKwh: Double
    ) -> Ladestandsenergie? {
        guard kapazitaetKwh > 0 else { return nil }
        let stand = raster
            .sorted { $0.zeit < $1.zeit }
            .compactMap(\.ladestand)
            .filter(\.isFinite)
        guard stand.count >= 10 else { return nil }
        var hoch = 0.0
        var runter = 0.0
        for i in 1..<stand.count {
            let schritt = stand[i] - stand[i - 1]
            if schritt > 0 { hoch += schritt } else { runter -= schritt }
        }
        return Ladestandsenergie(
            ladung: hoch * kapazitaetKwh,
            entladung: runter * kapazitaetKwh,
            punkte: stand.count)
    }

    // MARK: - Die acht Kopfzahlen

    /// Ab hier heisst „Netzladung ohne PV“ und „Verlust im Geraet“ eine Auffaelligkeit und nicht
    /// mehr Rauschen (`BatteryReport.tsx:110,141`).
    public static let auffallendKwh = 0.2
    /// Unter einer halben Kilowattstunde Ladung ist ein Wirkungsgrad keine Aussage
    /// (`BatteryReport.tsx:96`).
    public static let wirkungsgradAbKwh = 0.5
    /// Ab welcher Abweichung die Gegenprobe der Leistungsmessung widerspricht
    /// (`BatteryReport.tsx:129`).
    public static let gegenprobeAbweichung = 0.25
    /// Ab welchem Anteil Stundenmittel die Aufteilung auf PV und Netz geschaetzt heisst
    /// (`BatteryReport.tsx:92`).
    public static let schaetzgrenze = 0.05

    /// Die acht Kennzahlen der Vorlage, in ihrer Reihenfolge (`BatteryReport.tsx:105-145`).
    ///
    /// **Die siebte Kachel ist zwei verschiedene.** Liegen Minutenwerte mit Ladestand vor - also
    /// in der Tagesansicht -, steht dort die Gegenprobe „Laut Ladestand“; sonst der
    /// Wirkungsgrad. Beides beantwortet dieselbe Frage („kommt heraus, was hineinging?“), nur
    /// aus verschiedenen Quellen, und beides zugleich waere eine Kachel zu viel.
    ///
    /// **Drei Kacheln tragen den Alarmton, und zwar nur oberhalb ihrer Schwelle**
    /// (`BatteryReport.tsx:111`, `:130`, `:142`, jeweils `tone={... ? "ember" : "muted"}`):
    /// „Netzladung ohne PV“, die Gegenprobe „Laut Ladestand“ und „Verlust im Geraet“. Sie
    /// standen auf ``Kennzahl/Ton/glut``, weil der Kern damals kein Alarmrot kannte - und
    /// `glut` ist `Marken.waermepumpe`, eine Farbe, die ausdruecklich **nicht** wie eine
    /// Stoerung aussehen soll. Genau das sind diese drei aber: Strom, der in den Speicher
    /// ging, ohne dass Sonne da war, und Ladung, die die Zellen nie erreicht hat.
    public static func kacheln(
        _ b: EnergySummaryOut, ladestand: Ladestandsenergie? = nil
    ) -> [Kennzahl] {
        let t = b.totals
        let kapazitaet = b.meta.batteryCapacityKwh
        let zusatz = schaetzzusatz(t)
        let entladen = t.batteryDischargeKwh ?? 0
        let dunkel = t.gridToBatteryDarkKwh ?? 0
        let geraet = t.batteryDeviceKwh ?? 0

        return [
            Kennzahl(
                wort: "Geladen", wert: Formate.zahl(t.batteryChargeKwh, stellen: 1),
                einheit: "kWh", dazu: herkunftssatz(t) + zusatz, ton: .bernstein),
            Kennzahl(
                wort: "Netzladung ohne PV", wert: Formate.zahl(dunkelwert(t), stellen: 1),
                einheit: "kWh",
                dazu: "von \(Formate.zahl(t.gridToBatteryKwh, stellen: 1))"
                    + "\(Formate.schmalesLeerzeichen)kWh Netzladung insgesamt" + zusatz,
                ton: dunkel > auffallendKwh ? .alarm : .gedaempft),
            Kennzahl(
                wort: "Entladen", wert: Formate.zahl(t.batteryDischargeKwh, stellen: 1),
                einheit: "kWh",
                dazu: "\(Formate.zahl(t.batteryToHouseKwh, stellen: 1))"
                    + "\(Formate.schmalesLeerzeichen)kWh ins Haus",
                ton: .nebel),
            Kennzahl(
                wort: "Vollzyklen", wert: zyklenwert(entladen, kapazitaet: kapazitaet),
                dazu: kapazitaet > 0
                    ? "Entladung ÷ \(Formate.zahl(kapazitaet, stellen: 1))"
                        + "\(Formate.schmalesLeerzeichen)kWh"
                    : "Kapazität unbekannt"),
            Kennzahl(
                wort: "Ersparnis", wert: Formate.euro(t.batteryNetEur),
                dazu: ersparnissatz(t), ton: .bernstein),
            Kennzahl(
                wort: "PV-Anteil Ladung", wert: Formate.prozent(pvAnteil(t)),
                dazu: netzladungssatz(t) + zusatz),
            siebte(t, ladestand: ladestand),
            Kennzahl(
                wort: "Verlust im Gerät", wert: Formate.zahl(t.batteryDeviceKwh, stellen: 1),
                einheit: "kWh",
                dazu: "\(Formate.euro(t.batteryDeviceCostEur)) bezahlt · "
                    + "\(Formate.euro(t.batteryDeviceOpportunityEur)) entgangen",
                ton: geraet > auffallendKwh ? .alarm : .gedaempft),
        ]
    }

    /// Die Gegenprobe, oder - wo es keine gibt - der Wirkungsgrad
    /// (`BatteryReport.tsx:125-135`).
    static func siebte(_ t: EnergyTotalsOut, ladestand: Ladestandsenergie?) -> Kennzahl {
        guard let l = ladestand else {
            return Kennzahl(
                wort: "Wirkungsgrad", wert: Formate.prozent(wirkungsgrad(t)),
                dazu: "Entladen ÷ Geladen", ton: .gedaempft)
        }
        return Kennzahl(
            wort: "Laut Ladestand", wert: Formate.zahl(l.entladung, stellen: 1), einheit: "kWh",
            dazu: "entladen · Leistungsmessung "
                + "\(Formate.zahl(t.batteryDischargeKwh, stellen: 1))"
                + "\(Formate.schmalesLeerzeichen)kWh",
            ton: widerspricht(t, ladestand: l) ? .alarm : .gedaempft)
    }

    /// Laufen Leistungsmessung und Ladestand auseinander? (`BatteryReport.tsx:129`)
    ///
    /// Gemessen wird am groesseren der beiden Wege, mindestens aber an einer halben
    /// Kilowattstunde: an einem Tag ohne Entladung waeren sonst 0,1 gegen 0,0 kWh ein
    /// Widerspruch von unendlich viel Prozent.
    public static func widerspricht(_ t: EnergyTotalsOut, ladestand: Ladestandsenergie) -> Bool {
        let gemessen = t.batteryDischargeKwh ?? 0
        let bezug = max(ladestand.entladung, 0.5)
        return abs(ladestand.entladung - gemessen) > gegenprobeAbweichung * bezug
    }

    /// Vollzyklen: die Entladung gemessen an einer Speicherfuellung
    /// (`BatteryReport.tsx:94,115`).
    ///
    /// **Ab zehn Zyklen ohne Nachkommastelle.** Eine Monats- oder Jahresspalte zeigt „47“ und
    /// nicht „47,3“; das Zehntel einer solchen Summe ist Rauschen.
    public static func zyklenwert(_ entladen: Double, kapazitaet: Double) -> String {
        guard kapazitaet > 0 else { return Formate.leer }
        let zyklen = entladen / kapazitaet
        return Formate.zahl(zyklen, stellen: zyklen >= 10 ? 0 : 1)
    }

    /// Der Anteil der Sonne an der Ladung (`BatteryReport.tsx:95`). Ohne Ladung kein Anteil.
    public static func pvAnteil(_ t: EnergyTotalsOut) -> Double? {
        guard let geladen = t.batteryChargeKwh, geladen > 0 else { return nil }
        return (t.pvToBatteryKwh ?? 0) / geladen
    }

    /// Entladen durch Geladen, nach oben auf eins begrenzt (`BatteryReport.tsx:96`).
    ///
    /// Erst ab einer halben Kilowattstunde Ladung: darunter ist der Quotient zweier Rundungen
    /// und keine Eigenschaft des Speichers. Die Deckelung auf eins ist keine Schoenheit - ein
    /// Speicher, der mehr abgibt, als er am selben Tag aufnahm, hat am Vortag geladen.
    public static func wirkungsgrad(_ t: EnergyTotalsOut) -> Double? {
        guard let geladen = t.batteryChargeKwh, geladen > wirkungsgradAbKwh else { return nil }
        return min(1, (t.batteryDischargeKwh ?? 0) / geladen)
    }

    /// **Die Dunkelladung wird nicht auf Null geschoent.** Fehlt das Feld, steht ein Strich;
    /// eine Null waere die Auskunft „nichts im Dunkeln geladen“, und die gibt die Antwort nicht
    /// her.
    static func dunkelwert(_ t: EnergyTotalsOut) -> Double? {
        t.gridToBatteryDarkKwh
    }

    /// „PV 7,1 · Netz 0,4 kWh“ - woraus die Ladung kam (`BatteryReport.tsx:106`).
    static func herkunftssatz(_ t: EnergyTotalsOut) -> String {
        let pv = Formate.zahl(t.pvToBatteryKwh, stellen: 1)
        let netz = Formate.zahl(t.gridToBatteryKwh, stellen: 1)
        return "PV \(pv) · Netz \(netz)\(Formate.schmalesLeerzeichen)kWh"
    }

    /// „1,84 € gespart − 0,12 € fürs Laden“, und wo es nichts zu rechnen gibt: „netto“
    /// (`BatteryReport.tsx:122`).
    ///
    /// Der Hinweis traegt die ganze Begruendung der Kachel: netto heisst vermiedener Bezug
    /// minus dem, was das Fuellen gekostet hat. Die alte Zahl der App zaehlte nur die Entladung
    /// und sah den Verlust nie (`BatteryReport.tsx:116-117`).
    static func ersparnissatz(_ t: EnergyTotalsOut) -> String {
        guard t.batteryDischargeValueEur != nil || t.batteryChargeCostEur != nil else {
            return "netto"
        }
        return "\(Formate.euro(t.batteryDischargeValueEur)) gespart \(Formate.minus) "
            + "\(Formate.euro(t.batteryChargeCostEur)) fürs Laden"
    }

    /// „0,4 kWh aus dem Netz geladen“ - oder die gute Nachricht (`BatteryReport.tsx:124`).
    ///
    /// **„keine Netzladung“ ist eine Auskunft, ein Strich waere keine.** Ein Tag, an dem der
    /// Speicher nur aus der Sonne gefuellt wurde, ist der gute Fall und soll als solcher
    /// dastehen.
    static func netzladungssatz(_ t: EnergyTotalsOut) -> String {
        let netz = t.gridToBatteryKwh ?? 0
        guard netz > 0.05 else { return "keine Netzladung" }
        return "\(Formate.zahl(netz, stellen: 1))\(Formate.schmalesLeerzeichen)"
            + "kWh aus dem Netz geladen"
    }

    // MARK: - Der Schaetzzusatz

    /// Welcher Anteil des Zeitraums nur als Stundenmittel vorliegt (`BatteryReport.tsx:90`).
    public static func grobanteil(_ t: EnergyTotalsOut) -> Double {
        guard let minuten = t.minutes, minuten > 0 else { return 0 }
        return Double(t.coarseMinutes ?? 0) / Double(minuten)
    }

    /// Der Zusatz an genau den drei Kacheln, in denen die Annahme steckt
    /// (`BatteryReport.tsx:92-93`).
    ///
    /// **Warum nicht in der Methode unten.** Dort sind die Summen richtig; geschaetzt ist nur
    /// die Aufteilung auf PV und Netz - und genau die steht auf „Geladen“, „Netzladung ohne PV“
    /// und „PV-Anteil Ladung“. Was eine Zahl an diesem Tag einschraenkt, gehoert neben die Zahl
    /// (`ui/Methode.tsx:11-13`).
    public static func schaetzzusatz(_ t: EnergyTotalsOut) -> String {
        let anteil = grobanteil(t)
        guard anteil > schaetzgrenze else { return "" }
        return " · Aufteilung für \(Formate.prozent(anteil)) des Zeitraums geschätzt"
    }

    // MARK: - Der Spannenstreifen

    /// Die vier Zeilen von „Speicher im Überblick“ (`BatteryReport.tsx:162-171`).
    ///
    /// **Die Kapazitaet kommt aus der gewaehlten Spanne und nicht aus jeder Spalte**, genau wie
    /// in der Vorlage (`cap` steht dort ausserhalb der Zeilen). Sie ist eine Eigenschaft des
    /// Geraets und nicht des Zeitraums; vier Spalten mit vier Kapazitaeten waeren vier
    /// verschiedene Speicher.
    public static func spannenzeilen(
        _ je: [Spanne: EnergySummaryOut], kapazitaetKwh: Double
    ) -> [Streifenzeile] {
        let folge = Spanne.allCases
        func reihe(
            _ wort: String, _ ton: Kennzahl.Ton, _ wert: @escaping (EnergyTotalsOut) -> String
        ) -> Streifenzeile {
            Streifenzeile(
                wort: wort,
                werte: folge.map { je[$0].map { wert($0.totals) } ?? Formate.leer },
                ton: ton)
        }
        return [
            reihe("Ersparnis netto", .bernstein) { Formate.euro($0.batteryNetEur) },
            // Ab hundert Kilowattstunden ohne Nachkommastelle - dieselbe Regel wie im
            // Wallboxstreifen (`BatteryReport.tsx:167`).
            reihe("Entladen · kWh", .normal) { Formate.kwhNachGroesse($0.batteryDischargeKwh) },
            // Hier immer mit einer Nachkommastelle, anders als in der Kachel: die Vorlage
            // schreibt die Stelle fuer diese Zeile fest (`BatteryReport.tsx:168`), die Regel
            // „ab zehn ohne Nachkommastelle“ gilt dort nur fuer die Kachel
            // (`BatteryReport.tsx:115`). Vier Spalten nebeneinander lesen sich sonst
            // uneinheitlich - „12“ neben „3,1“.
            reihe("Vollzyklen", .normal) { t in
                kapazitaetKwh > 0
                    ? Formate.zahl((t.batteryDischargeKwh ?? 0) / kapazitaetKwh, stellen: 1)
                    : Formate.leer
            },
            reihe("PV-Anteil", .normal) { Formate.prozent(pvAnteil($0)) },
        ]
    }

    // MARK: - Was die Seite ueber sich selbst sagt

    /// Der Kicker der Seite: die Kapazitaet und wofuer die Zahlen stehen
    /// (`BatteryReport.tsx:103`).
    ///
    /// **Er steht in der App ueber dem Kachelfeld und nicht in der Reiterzeile.** Die Vorlage
    /// setzt ihn rechts in die Reiterzeile (`AreaNav.tsx:96`); ``Reiterzeile`` hat dafuer keinen
    /// Platz, und einen anzulegen waere eine Entscheidung ueber alle dreizehn Berichtsseiten.
    /// Ueber dem Kachelfeld steht er an derselben Stelle der Lesereihenfolge - unmittelbar vor
    /// den Zahlen, die er einordnet.
    public static func seitenkicker(_ m: EnergyMetaOut) -> String {
        guard m.batteryCapacityKwh > 0 else { return "Nutzung und Ersparnis" }
        return "\(Formate.zahl(m.batteryCapacityKwh, stellen: 1))"
            + "\(Formate.schmalesLeerzeichen)kWh · Nutzung und Ersparnis"
    }

    /// Der Absatz der Methode, der „Geladen“ und „Ersparnis netto“ erklaert
    /// (`BatteryReport.tsx:174`).
    public static let methodensatz =
        "Geladen ist, was in den Zellen ankam: Was der Wandler zusätzlich sah, hat sie nie "
        + "erreicht und steht als Verlust im Gerät daneben. Ersparnis ist netto gerechnet: der "
        + "vermiedene Bezug der Entladestunden, abzüglich dessen, was das Füllen gekostet hat "
        + "(Netzanteil zum Bezugspreis, PV-Anteil zur entgangenen Vergütung). Die Verluste "
        + "stecken darin von selbst, weil mehr hineinging als herauskam."

    /// Der Absatz der Karte „Stimmt das?“ (`SpeicherCheck.tsx:43-49`).
    ///
    /// **Er steht immer da, auch ohne Bericht.** Er sagt nicht, was die Pruefung ergeben hat,
    /// sondern wogegen sie prueft - und das ist die Auskunft, die man braucht, um zu
    /// entscheiden, ob man sie ueberhaupt laufen laesst.
    public static let pruefsatz =
        "Alle Zahlen dieser Seite kommen aus einer einzigen Messreihe, der Leistung des "
        + "Speichers. Stimmt sie nicht, stimmt keine davon, und zwar alle im selben Sinn. Die "
        + "Prüfung hält sie gegen zwei Messungen, die nichts mit ihr zu tun haben: den "
        + "Ladestand aus dem Gerät und den Hausverbrauch von den Wandlern des Hubs. Damit lässt "
        + "sich trennen, ob der Strom im Speicher angekommen ist, ob er nur im Gerät geblieben "
        + "ist oder ob er gar nicht geflossen ist."

    /// Die Beschriftung des Pruefknopfs (`SpeicherCheck.tsx:41`).
    public static func pruefknopf(laeuft: Bool) -> String {
        laeuft ? "liest Minuten ..." : "Speicher prüfen"
    }

    /// Was dasteht, wenn die Pruefung nicht durchlief (`SpeicherCheck.tsx:31`).
    public static let pruefungGescheitert = "Die Prüfung ist nicht durchgelaufen."

    /// Ab wie vielen Zeilen der Pruefbericht eine Hoehengrenze braucht.
    ///
    /// **Die Vorlage deckelt ihn bei `max-height: 60dvh`** (`globals.css:604`). In SwiftUI gibt
    /// es kein `dvh`, und eine Grenze, die immer gilt, macht aus einem dreizeiligen Bericht
    /// einen halben Bildschirm Leere. Gedeckelt wird darum erst, was ohne Deckel die Karte
    /// ueber die Seite wachsen liesse - ein Jahresbericht hat einige hundert Zeilen, der eines
    /// Tages zwei Dutzend.
    public static let berichtZeilengrenze = 20

    /// Braucht dieser Bericht eine Hoehengrenze?
    ///
    /// Gezaehlt werden auch leere Zeilen: sie nehmen denselben Platz wie volle, und ein
    /// Bericht mit vielen Absaetzen ist genauso lang wie einer ohne.
    public static func berichtIstLang(_ text: String) -> Bool {
        text.split(separator: "\n", omittingEmptySubsequences: false).count
            > berichtZeilengrenze
    }
}
