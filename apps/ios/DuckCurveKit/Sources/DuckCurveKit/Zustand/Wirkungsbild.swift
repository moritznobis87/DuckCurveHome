import Foundation

/// Die Seite „Wirkung“ als fertiges Bild: Quotenvergleich, Antwortfächer, Ereignisraster.
///
/// **Das Urteil fällt der Dienst.** Hier wird nichts verglichen, nichts geschätzt und nichts
/// gerundet, was eine Aussage ändern könnte. Der Urteilssatz, beide Quoten und ihre
/// Vertrauensbereiche kommen fertig aus `/anlage/kontaktwirkung`; dieser Typ ordnet, gruppiert
/// und schreibt die Wörter dazu. Die Vorlage (`apps/web/src/components/waerme/wirkung.ts`) sagt
/// denselben Satz im Dateikopf, und er gilt hier doppelt: was eine Oberfläche selbst ausrechnet,
/// prüft niemand nach.
///
/// **Was es nicht ist.** Keine Statistik und keine zweite Meinung. Es steht auch nichts darin,
/// was nur das Zeichnen angeht - keine Farben, keine Punkte, keine Höhen. Was es enthält, sind
/// Entscheidungen über die Daten: welche Minute ein Band verdient, welche Kurve eine Lücke hat,
/// in welche Gruppe ein Schließvorgang gehört, welches Wort neben einer Zeile steht.
///
/// **Lücken bleiben Lücken.** Eine Minute ohne Leistungsmessung ist `nil` und nicht null
/// Kilowatt. Darum liefert dieser Typ die Kurven als **Stücke** und nicht als Reihen mit
/// Löchern: `LineMark` in Swift Charts kennt kein `connectNulls: false` und zöge eine Linie über
/// die Lücke - und damit eine Messung, die es nicht gibt. Dasselbe im Raster: „gemessen und
/// gestanden“ und „nicht gemessen“ sind zwei Aussagen, und nur eine davon ist Stillstand.
public struct Wirkungsbild: Sendable {

    // MARK: - Werte, die aus dem Dienst kommen und hier nur einen Namen bekommen

    /// Ab so vielen Ereignissen je Minute wird das Band der mittleren Hälfte gezeichnet.
    ///
    /// Dieselbe Acht wie `MIN_EREIGNISSE` in
    /// `packages/hems-core/src/hems_core/thermal/kontaktwirkung.py:52` („unter so vielen
    /// auswertbaren Ereignissen gibt es kein Urteil, nur die Zahlen“) und wie `MIN_FUER_BAND` in
    /// `apps/web/src/components/waerme/Antwortfaecher.tsx:41`. Sie steht hier als Name, damit
    /// nicht in zwei Diagrammen zwei verschiedene Achten stehen.
    public static let mindestensFuerBand = 8

    /// Mehr Einzelkurven zeichnet der Fächer nicht (`MAX_KURVEN`, `Antwortfaecher.tsx:40`).
    ///
    /// Es sind die **jüngsten** auswertbaren, nicht die ersten: was die Maschine letzte Woche
    /// tat, sagt mehr über heute.
    public static let maxKurven = 80

    /// Mehr Zeilen zeigt das Raster nicht (`MAX_ZEILEN`, `Ereignisraster.tsx:27`): „darüber wird
    /// es eine Liste, die niemand mehr liest.“
    public static let maxZeilen = 80

    /// Vorgabe für `vor_min`, falls die Antwort sie nicht nennt (`kontaktwirkung.py:41`).
    public static let vorMinVorgabe = 30
    /// Vorgabe für `nach_min` (`kontaktwirkung.py:42`).
    public static let nachMinVorgabe = 120
    /// Vorgabe für `folge_min` (`kontaktwirkung.py:47`): ein Anlauf binnen einer halben Stunde
    /// zählt als Folge des Schließens.
    public static let folgeMinVorgabe = 30

    // MARK: - Der Ausschnitt

    /// Wie weit der Ausschnitt vor das Schließen reicht, in Minuten.
    public var vorMin: Int = Wirkungsbild.vorMinVorgabe
    /// Wie weit er dahinter reicht.
    public var nachMin: Int = Wirkungsbild.nachMinVorgabe
    /// Binnen so vieler Minuten zählt ein Anlauf als Folge.
    public var folgeMin: Int = Wirkungsbild.folgeMinVorgabe
    /// Ab dieser Leistung gilt die Pumpe als laufend.
    public var schwelleKw: Double = 0

    /// Die Breite eines Rasterbalkens in Minuten, also die Zahl der Spalten: `vor + nach + 1`.
    ///
    /// Die Ansicht rechnet sie nicht selbst nach. Ein Balken, dessen Breite um eins von der des
    /// Nachbarn abweicht, setzt den Nullpunkt an zwei verschiedene Stellen - und genau das ist
    /// die Aussage des Rasters.
    public var breite: Int = Wirkungsbild.vorMinVorgabe + Wirkungsbild.nachMinVorgabe + 1

    // MARK: - Was überhaupt gezeigt werden darf

    /// Wie viele Anforderungen bei stehender Maschine auswertbar waren.
    public var nAuswertbar: Int = 0

    /// Darf die Karte „Antwortfächer“ erscheinen?
    ///
    /// **Nicht „hat der Fächer Minuten“.** Der Dienst füllt `faecher.minuten`
    /// unbedingt mit allen 151 Minuten des Ausschnitts, auch wenn kein einziges Ereignis
    /// auswertbar war (`kontaktwirkung.py:281-321`, Aufruf `:524`). Eine Bedingung auf dieses
    /// Raster ist damit immer wahr, und gezeigt wurde eine leere Zeichnung mit Schwellenlinie,
    /// Folgefenster und vierteiliger Legende unter der Zeile „0 Anforderungen bei stehender
    /// Maschine“. Die Vorlage fragt die Zahl der auswertbaren Anforderungen
    /// (`Wirkung.tsx:204`).
    public var faecherZeigen: Bool { nAuswertbar > 0 }

    /// Darf die Karte „Jede Anforderung“ erscheinen? Genau dann, wenn es Zeilen gibt.
    ///
    /// Die Vorlage prüft zweierlei: die Karte hängt an `d.n > 0` (`Wirkung.tsx:233`), das
    /// Raster selbst gibt ohne geliefertes Ereignis `null` zurück (`Ereignisraster.tsx:62`).
    /// Beides zusammen ist dies. Es steht hier, damit die Ansicht keine Bedingung mehr selbst
    /// formt.
    public var rasterZeigen: Bool { !gruppen.isEmpty }

    // MARK: - Das Urteil

    /// Das deutsche Wort zur Urteilskennung, für den Kicker „Urteil · …“.
    public var urteilswort: String = "noch offen"
    /// Der Urteilssatz, wie der Dienst ihn schreibt. Die Oberfläche urteilt nicht.
    public var urteilssatz: String?
    /// „10. Oktober bis 9. November“ - der ausgewertete Zeitraum, oder `nil`, wenn er fehlt.
    public var spanne: String?

    // MARK: - Der Quotenvergleich

    /// Welche der beiden Zeilen gemeint ist - die Ansicht wählt danach die Farbe.
    ///
    /// Eine Aufzählung und nicht der Name als Zeichenkette: dieselbe Rolle trägt im Fächer die
    /// durchgezogene und im Vergleich die gestrichelte Linie, und das muss an einer Stelle
    /// entschieden sein.
    public enum Rolle: String, Sendable, Hashable, CaseIterable {
        /// Was nach einer Anforderung geschah: die Wärmepumpenfarbe, durchgezogen.
        case angefordert
        /// Was zur selben Tageszeit ohne Anforderung geschah: Nebelfarbe, gestrichelt.
        case sonst
    }

    /// Eine Zeile des Punkt-und-Balken-Bildes: beobachtete Quote und ihr Vertrauensbereich.
    ///
    /// **Warum Punkt und Balken und nicht zwei Zahlen.** In der App standen beide Quoten als
    /// Text in zwei verschiedenen Kacheln und waren damit nicht vergleichbar. Die Aussage der
    /// Seite ist aber genau der Abstand der beiden - und ob er größer ist als die Unsicherheit.
    /// Deshalb gehören `lo` und `hi` zur Zeile und nicht in eine Fußnote.
    public struct Quotenzeile: Sendable, Hashable, Identifiable {
        /// „angefordert“ oder „sonst“ - zugleich die Kategorie der Achse.
        public let name: String
        public let rolle: Rolle
        /// Der beobachtete Anteil (0 bis 1), oder `nil`, wenn es nichts zu beobachten gab.
        public let quote: Double?
        /// Untere Grenze des 95-Prozent-Bereichs.
        public let lo: Double?
        /// Obere Grenze des 95-Prozent-Bereichs.
        public let hi: Double?
        /// Was statt Punkt und Balken dasteht, wenn `quote` fehlt.
        public let leer: String

        public var id: String { name }

        /// Die ganze Prozentzahl rechts neben dem Balken, ohne Einheit: „100“.
        public var zahl: String { Formate.prozentZahl(quote) }

        /// Der Bereich darunter: „94 bis 100 %“. `nil`, wenn eine der Grenzen fehlt - ein
        /// halber Vertrauensbereich ist keine Angabe.
        public var bereich: String? {
            guard let lo, let hi, lo.isFinite, hi.isFinite else { return nil }
            return "\(Formate.prozentZahl(lo)) bis \(Formate.prozent(hi))"
        }

        public init(
            name: String, rolle: Rolle, quote: Double?, lo: Double?, hi: Double?, leer: String
        ) {
            self.name = name
            self.rolle = rolle
            self.quote = quote
            self.lo = lo
            self.hi = hi
            self.leer = leer
        }
    }

    /// Die zwei Zeilen des Quotenbildes, immer beide - auch leer.
    ///
    /// Beide stehen auch dann da, wenn keine Quote gerechnet werden konnte: eine Zeile, die
    /// verschwindet, sieht aus wie eine Quote von null.
    public var quotenzeilen: [Quotenzeile] = []

    /// Die Erklärung unter dem Quotenbild, mit der eigenen Folgefrist im Satz.
    public var quotenerklaerung: String = ""

    /// Was ein Vorleser über das Bild sagt (`aria-label`, `Wirkung.tsx:40-106`).
    public var quotenbeschreibung: String = ""

    // MARK: - Der Antwortfächer

    /// Eine Minute des Fächers, über alle Ereignisse zusammengefasst.
    ///
    /// **`q25`/`q75` sind nur gesetzt, wo das Band erlaubt ist.** Die Entscheidung, ob eine
    /// Minute mit weniger als `mindestensFuerBand` Ereignissen eine mittlere Hälfte zeigen darf,
    /// ist eine Aussage über die Daten und keine über das Zeichnen. Sie fällt hier, damit das
    /// Diagramm keine Acht kennt.
    public struct Faecherpunkt: Sendable, Hashable, Identifiable {
        /// Minuten relativ zum Schließen des Kontakts: negativ davor, 0 beim Schließen.
        public let minute: Int
        /// Das **Mittel** der Leistung, nicht der Median - die Maschine läuft oder steht, und
        /// ein Median wäre in jeder Minute entweder null oder die volle Leistung
        /// (`Antwortfaecher.tsx`, Begründung im Dateikopf).
        public let mittelKw: Double?
        public let q25Kw: Double?
        public let q75Kw: Double?
        /// Wie viele Ereignisse diese Minute überhaupt gemessen haben.
        public let n: Int
        public let anteilLaeuft: Double?
        public let anteilAngelaufen: Double?

        public var id: Int { minute }

        /// Hat diese Minute ein Band? Genau dann, wenn beide Viertel dastehen.
        public var hatBand: Bool { q25Kw != nil && q75Kw != nil }

        public init(
            minute: Int, mittelKw: Double?, q25Kw: Double?, q75Kw: Double?, n: Int,
            anteilLaeuft: Double?, anteilAngelaufen: Double?
        ) {
            self.minute = minute
            self.mittelKw = mittelKw
            self.q25Kw = q25Kw
            self.q75Kw = q75Kw
            self.n = n
            self.anteilLaeuft = anteilLaeuft
            self.anteilAngelaufen = anteilAngelaufen
        }
    }

    /// Alle Minuten des Fächers in ihrer Reihenfolge.
    public var faecher: [Faecherpunkt] = []

    /// Ein Punkt des Bandes der mittleren Hälfte: unteres und oberes Viertel einer Minute.
    public struct Bandpunkt: Sendable, Hashable, Identifiable {
        public let minute: Int
        public let unten: Double
        public let oben: Double

        public var id: Int { minute }

        public init(minute: Int, unten: Double, oben: Double) {
            self.minute = minute
            self.unten = unten
            self.oben = oben
        }
    }

    /// Ein zusammenhängendes Stück des Bandes.
    ///
    /// **Warum Stücke, wie bei den Kurven.** `AreaMark` kennt kein `connectNulls: false`. Eine
    /// Fläche aus allen Minuten mit Band schließt sich über die Minuten ohne Band hinweg -
    /// also genau dort, wo zu wenige Ereignisse gemessen haben, behauptete sie eine mittlere
    /// Hälfte. Die Vorlage setzt in **beide** gestapelten Reihen `null` und bricht damit ab
    /// (`Antwortfaecher.tsx:59-65`). Jedes Stück ist im Diagramm eine eigene Reihe; `id` ist
    /// dafür eindeutig („band.0“).
    public struct Bandstueck: Sendable, Hashable, Identifiable {
        public let id: String
        public let punkte: [Bandpunkt]

        public init(id: String, punkte: [Bandpunkt]) {
            self.id = id
            self.punkte = punkte
        }
    }

    /// Das Band der mittleren Hälfte, in Stücken - leer, wo keine Minute eines verdient.
    public var band: [Bandstueck] = []

    /// Die Marken der senkrechten Achse der oberen Fläche, in Kilowatt.
    ///
    /// **Warum die Spanne nicht aus den Daten kommen darf.** Ohne feste Achse skaliert Swift
    /// Charts die Fläche nach ihrem Inhalt: eine Mittelkurve, die bis 0,6 kW steigt, reicht
    /// dann bis an den oberen Rand und sieht aus wie volle Leistung. Die Vorlage setzt `min: 0`
    /// und `splitNumber: 3` (`Antwortfaecher.tsx:157-163`); dass daraus runde Zahlen werden,
    /// rechnet dort ECharts. Hier rechnet es der Kern, denn es ist eine Rundung und keine
    /// Zeichnung.
    public var leistungsmarken: [Double] = [0, 1, 2, 3]

    /// Die Spanne der oberen Fläche: von null bis zur letzten Marke.
    public var leistungsspanne: ClosedRange<Double> { 0...(leistungsmarken.last ?? 1) }

    /// Die Marken der unteren Fläche: fest 0, 50, 100 (`interval: 50`,
    /// `Antwortfaecher.tsx:168`).
    public static let anteilsmarken: [Double] = [0, 50, 100]

    /// Die Spanne der unteren Fläche. **Fest null bis hundert Prozent**
    /// (`Antwortfaecher.tsx:166-167`): die Aussage der Fläche ist der *Abstand* der beiden
    /// Treppen in Prozentpunkten, und der ist nur auf einer festen Achse ablesbar. Nach den
    /// Daten skaliert stiege eine Treppe, die 30 Prozent erreicht, bis an den oberen Rand.
    public static let anteilsspanne: ClosedRange<Double> = 0...100

    /// Ein gemessener Punkt einer Leistungskurve. Ohne `nil`: wo nicht gemessen wurde, endet
    /// das Stück.
    public struct Kurvenpunkt: Sendable, Hashable, Identifiable {
        public let minute: Int
        public let kw: Double
        public var id: Int { minute }

        public init(minute: Int, kw: Double) {
            self.minute = minute
            self.kw = kw
        }
    }

    /// Ein zusammenhängend gemessenes Stück einer Kurve.
    ///
    /// **Warum Stücke und nicht eine Reihe.** Swift Charts hat kein `connectNulls: false`. Eine
    /// Reihe mit Löchern wird zu einer durchgezogenen Linie über die Lücke hinweg, und die
    /// behauptet eine Messung. Jedes Stück ist im Diagramm eine eigene Reihe; `id` ist dafür über
    /// alle Kurven eindeutig („e3.1“, „mittel.0“).
    public struct Kurvenstueck: Sendable, Hashable, Identifiable {
        public let id: String
        public let punkte: [Kurvenpunkt]

        public init(id: String, punkte: [Kurvenpunkt]) {
            self.id = id
            self.punkte = punkte
        }
    }

    /// Die Antwort eines einzelnen Ereignisses, in Stücke zerlegt.
    public struct Einzelkurve: Sendable, Hashable, Identifiable {
        public let id: Int
        public let stuecke: [Kurvenstueck]

        public init(id: Int, stuecke: [Kurvenstueck]) {
            self.id = id
            self.stuecke = stuecke
        }
    }

    /// Die Mittelkurve des Fächers, in Stücken.
    public var mittel: [Kurvenstueck] = []

    /// Bis zu `maxKurven` einzelne Antworten, die jüngsten auswertbaren zuletzt.
    public var einzelkurven: [Einzelkurve] = []

    /// Die Deckung, mit der die Einzelkurven zu zeichnen sind - passend zu ihrer Zahl.
    public var kurvendeckung: Double = Wirkungsbild.deckung(0)

    /// Der Anlaufanteil ohne Anforderung, zur selben Tageszeit. Der Index ist die Minute ab 0.
    ///
    /// Anteile von 0 bis 1, wie sie aus dem Dienst kommen; die Prozentachse des Diagramms
    /// rechnet das Zeichnen um.
    public var anteilOhne: [(minute: Int, anteil: Double)] = []

    /// Steht statt der Bandmarke in der Legende, wenn es für ein Band nicht reicht.
    ///
    /// **Warum ein Satz und keine fehlende Marke.** Eine Legende, in der ein Eintrag fehlt,
    /// erklärt nicht, warum im Bild kein Band ist. Der Satz tut es (`Wirkung.tsx:208-229`).
    public var bandHinweis: String?

    // MARK: - Die Auskunft zu einer Minute

    /// Eine Zeile der Auskunft. `rolle` ist `nil`, wo keine Marke davor steht.
    public struct Auskunftszeile: Sendable, Hashable, Identifiable {
        public let text: String
        public let rolle: Rolle?
        /// Eingerückt: ein Satz, der die Zeile darüber erklärt, keine eigene Größe.
        public let eingerueckt: Bool

        public var id: String { text }

        public init(text: String, rolle: Rolle? = nil, eingerueckt: Bool = false) {
            self.text = text
            self.rolle = rolle
            self.eingerueckt = eingerueckt
        }
    }

    /// Alles, was zu einer Minute des Fächers zu sagen ist.
    public struct Auskunft: Sendable, Hashable {
        public let minute: Int
        public let kopf: String
        public let zeilen: [Auskunftszeile]

        public init(minute: Int, kopf: String, zeilen: [Auskunftszeile]) {
            self.minute = minute
            self.kopf = kopf
            self.zeilen = zeilen
        }
    }

    /// Die Auskunft zu einer Minute - der Inhalt des Hinweisfensters der Vorlage.
    ///
    /// **Warum nicht in der Zeichnung.** Am Telefon gibt es kein Darüberfahren; die Vorlage
    /// zeigt all das in einem Tooltip, und ohne diese Auskunft stünden Mittel, mittlere Hälfte,
    /// die Zahl der Ereignisse je Minute und der Vergleich nirgends in der App. Dasselbe Muster
    /// wie `Fahrplanbild.auskunft`, aus demselben Grund.
    ///
    /// `nil`, wenn die Minute nicht im Ausschnitt liegt.
    public func auskunft(minute: Int) -> Auskunft? {
        guard let p = faecher.first(where: { $0.minute == minute }) else { return nil }

        let kopf: String
        if minute == 0 {
            kopf = "Anforderung beginnt"
        } else if minute > 0 {
            kopf = "\(minute) min nach Beginn der Anforderung"
        } else {
            kopf = "\(-minute) min vor der Anforderung"
        }

        var zeilen: [Auskunftszeile] = []
        if let mittelKw = p.mittelKw {
            zeilen.append(
                Auskunftszeile(
                    text: "im Mittel \(Formate.kwMitEinheit(mittelKw))", rolle: .angefordert))
            if let a = p.q25Kw, let b = p.q75Kw {
                zeilen.append(
                    Auskunftszeile(
                        text: "mittlere Hälfte \(Formate.kw(a)) bis \(Formate.kwMitEinheit(b))",
                        eingerueckt: true))
            }
            zeilen.append(
                Auskunftszeile(
                    text: "läuft in \(Formate.prozent(p.anteilLaeuft)) der \(p.n) Ereignisse",
                    eingerueckt: true))
        } else {
            // Keine Null: null Kilowatt hieße „die Maschine stand“, und das weiß hier niemand.
            zeilen.append(Auskunftszeile(text: "keine Messung"))
        }

        if let an = p.anteilAngelaufen {
            zeilen.append(
                Auskunftszeile(text: "angelaufen \(Formate.prozent(an))", rolle: .angefordert))
        }
        // Der Vergleich beginnt beim Schließen: vor der Anforderung gibt es nichts zu vergleichen.
        if minute >= 0, let ohne = anteilOhne.first(where: { $0.minute == minute })?.anteil {
            zeilen.append(
                Auskunftszeile(
                    text: "ohne Anforderung \(Formate.prozent(ohne))", rolle: .sonst))
        }
        return Auskunft(minute: minute, kopf: kopf, zeilen: zeilen)
    }

    // MARK: - Das Ereignisraster

    /// In welche der vier Gruppen ein Schließvorgang gehört.
    ///
    /// **Die Reihenfolge der Prüfung ist die Aussage.** „Lief schon“ kommt zuerst, weil ein
    /// Kontakt nichts auslösen kann, was bereits läuft - so ein Ereignis zählt in keine Quote.
    /// Dann kommt die fehlende Messung: ohne Leistung im Folgefenster ist „nicht angelaufen“
    /// keine Aussage, sondern Unwissen. Erst danach steht die Frage, ob die Maschine anlief.
    public enum Ereignisgruppe: String, Sendable, Hashable, CaseIterable {
        case gefolgt
        case nichtGefolgt
        case liefSchon
        case unklar

        /// Die Überschrift der Gruppe im Raster (`GRUPPEN`, `wirkung.ts:25-30`).
        public var titel: String {
            switch self {
            case .gefolgt: return "angelaufen"
            case .nichtGefolgt: return "nicht angelaufen"
            case .liefSchon: return "lief schon"
            case .unklar: return "Messung fehlt"
            }
        }
    }

    /// Eine Zeile des Rasters: ein Schließvorgang mit seinem Balken und seinem Wort.
    ///
    /// `laeuft` und `steht` sind Abschnitte in **Spaltennummern** des Balkens, 0 bis `breite`;
    /// Spalte `vorMin` ist der Nullpunkt. Was in keinem der beiden Felder liegt, wurde nicht
    /// gemessen und bleibt leer - ein durchgehender Grund sähe wie gemessener Stillstand aus.
    public struct Ereigniszeile: Sendable, Hashable, Identifiable {
        /// Der Zeitstempel des Schließens, wie der Dienst ihn schickt.
        public let at: String
        /// „Sa., 07.11. 14:35“ in der Zeit des Hauses.
        public let wann: String
        /// Das Wort rechts: „sofort“, „nach 7 min“, „kein Anlauf“ …
        public let ergebnis: String
        public let laeuft: [Range<Int>]
        public let steht: [Range<Int>]
        /// Wie lange der Kontakt geschlossen blieb, in Minuten - auch über den Ausschnitt hinaus.
        public let kontaktMin: Int
        /// Der Kontaktstreifen in Spaltennummern, auf den Ausschnitt beschnitten. `nil`, wenn
        /// der Kontakt keine ganze Minute zu war.
        public let kontaktstreifen: Range<Int>?
        /// Wohin die Zeile führt: in die Wiedergabe dieses Tages, zur Stunde des Ereignisses.
        public let weg: String

        public var id: String { at }

        public init(
            at: String, wann: String, ergebnis: String, laeuft: [Range<Int>],
            steht: [Range<Int>], kontaktMin: Int, kontaktstreifen: Range<Int>?, weg: String
        ) {
            self.at = at
            self.wann = wann
            self.ergebnis = ergebnis
            self.laeuft = laeuft
            self.steht = steht
            self.kontaktMin = kontaktMin
            self.kontaktstreifen = kontaktstreifen
            self.weg = weg
        }
    }

    /// Die Zeilen des Rasters, nach Gruppen. Leere Gruppen fallen weg.
    public var gruppen: [(gruppe: Ereignisgruppe, zeilen: [Ereigniszeile])] = []

    /// Eine Marke der Achsenzeile über dem Raster.
    public struct Achsenmarke: Sendable, Hashable, Identifiable {
        public let minute: Int
        public let wort: String
        /// Wo die Marke steht: 0 bis 1 über die Breite des Balkens.
        public let anteil: Double
        /// Fein: verschwindet auf schmalen Schirmen. Dort ist der Balken hundert Punkte breit,
        /// und sechs Beschriftungen lägen aufeinander (`Ereignisraster.tsx:69-70`).
        public let fein: Bool

        public var id: Int { minute }

        public init(minute: Int, wort: String, anteil: Double, fein: Bool) {
            self.minute = minute
            self.wort = wort
            self.anteil = anteil
            self.fein = fein
        }
    }

    /// Die Marken der Achsenzeile: `-vor`, 0, 30, 60, 90, `nach` - ohne Doppelte.
    public var achsenmarken: [Achsenmarke] = []

    /// Die Marken der Zeitachse des Fächers: alle 30 Minuten, vom Beginn des Ausschnitts an.
    ///
    /// **Warum eine zweite Liste neben ``achsenmarken``.** Die Zeichnung griff zu
    /// ``achsenText(_:)`` und schrieb damit unter jede der sechs Marken „min“. Die Vorlage
    /// nennt die Einheit nur beim Nullpunkt und am Ende und begründet es: „sechsmal „min“
    /// nebeneinander stößt auf schmalen Schirmen zusammen, und einmal genügt“
    /// (`Antwortfaecher.tsx:85-87`). Mit fertigen Wörtern kann die Zeichnung nicht mehr die
    /// falsche Funktion wählen.
    public var faechermarken: [Achsenmarke] = []

    /// „gezeigt sind die jüngsten 80 von 214 Anforderungen“, wenn es mehr sind als `maxZeilen`.
    public var rasterHinweis: String?

    // MARK: - Rechnungen, einzeln prüfbar

    /// Die Deckung einer einzelnen Kurve im Fächer (`wirkung.ts:130-132`).
    ///
    /// Viele Kurven übereinander sollen eine Wolke ergeben, wenige einzeln lesbar bleiben. Mit
    /// fester Deckung wäre eines von beiden falsch: drei Kurven verschwänden, oder hundert würden
    /// zur Fläche.
    public static func deckung(_ n: Int) -> Double {
        guard n > 0 else { return 0.55 }
        return min(0.55, max(0.10, 1.1 / Double(n).squareRoot()))
    }

    /// Eine Leistungskurve als Abschnitte, in Spaltennummern ab dem Beginn des Ausschnitts
    /// (`wirkung.ts:62-71`).
    ///
    /// `laeuft` sind die Abschnitte an oder über der Schwelle, `steht` die gemessenen darunter.
    /// Was in keinem von beiden liegt, wurde nicht gemessen.
    ///
    /// **Warum nicht `Ausblick.abschnitte`.** Das kennt zwei Zustände, an und aus. Hier sind es
    /// drei, und der dritte ist der wichtige: ein Balken, der „nicht gemessen“ wie „gestanden“
    /// zeichnet, behauptet Stillstand, wo niemand hingesehen hat. Ein Wert, der keine Zahl ist
    /// (`NaN`), gilt ebenfalls als nicht gemessen - sonst wäre er stillschweigend Stillstand.
    public static func betrieb(kw: [Double?], schwelleKw: Double) -> (
        laeuft: [Range<Int>], steht: [Range<Int>]
    ) {
        var laeuft: [Range<Int>] = []
        var steht: [Range<Int>] = []
        var lauf: (an: Bool, von: Int)?

        func ablegen(_ l: (an: Bool, von: Int), bis: Int) {
            if l.an {
                laeuft.append(l.von..<bis)
            } else {
                steht.append(l.von..<bis)
            }
        }

        for (i, wert) in kw.enumerated() {
            guard let wert, wert.isFinite else {
                if let l = lauf { ablegen(l, bis: i) }
                lauf = nil
                continue
            }
            let an = wert >= schwelleKw
            if let l = lauf {
                if l.an == an { continue }
                ablegen(l, bis: i)
            }
            lauf = (an, i)
        }
        if let l = lauf { ablegen(l, bis: kw.count) }
        return (laeuft, steht)
    }

    /// In welche Gruppe ein Schließvorgang gehört (`wirkung.ts:19-23`).
    public static func gruppe(_ e: Ereignis) -> Ereignisgruppe {
        if e.liefSchon { return .liefSchon }
        if !e.auswertbar { return .unklar }
        return (e.gefolgt ?? false) ? .gefolgt : .nichtGefolgt
    }

    /// Was neben einer Zeile des Rasters steht (`wirkung.ts:74-81`).
    ///
    /// „Erst nach“ ab der Folgefrist: dieselbe Zahl, die über die Quote entscheidet, soll auch
    /// das Wort entscheiden - sonst steht im Raster „nach 45 min“ und in der Kachel, es sei nicht
    /// gefolgt.
    public static func ergebnisText(_ e: Ereignis, folgeMin: Int) -> String {
        switch gruppe(e) {
        case .liefSchon: return "lief schon"
        case .unklar: return "Messung fehlt"
        case .gefolgt, .nichtGefolgt:
            guard let v = e.verzoegerungMin else { return "kein Anlauf" }
            if v == 0 { return "sofort" }
            return v < folgeMin ? "nach \(v) min" : "erst nach \(v) min"
        }
    }

    /// Die Stücke des Bandes aus den Minuten des Fächers.
    ///
    /// Eine Minute ohne beide Viertel beendet das Stück - siehe ``Bandstueck``.
    static func bandstuecke(_ punkte: [Faecherpunkt]) -> [Bandstueck] {
        var aus: [Bandstueck] = []
        var offen: [Bandpunkt] = []

        func schliessen() {
            if !offen.isEmpty {
                aus.append(Bandstueck(id: "band.\(aus.count)", punkte: offen))
                offen = []
            }
        }

        for p in punkte {
            guard let u = p.q25Kw, let o = p.q75Kw, u.isFinite, o.isFinite else {
                schliessen()
                continue
            }
            offen.append(Bandpunkt(minute: p.minute, unten: u, oben: o))
        }
        schliessen()
        return aus
    }

    /// Stufen, in denen die obere Achse wächst.
    ///
    /// Drei dieser Stufen sind die Spanne. Es sind die Zahlen, die ECharts selbst wählt: eine
    /// Achse bis 1,9 kW ist Rauschen, eine bis 2 kW eine Angabe. Über 150 kW rechnet
    /// ``leistungsmarken(hoechstwert:)`` selbst weiter - eine Wärmepumpe im Haus kommt dort
    /// nicht hin, und eine Liste, die es vorsorglich bis 1000 aufzählt, behauptet eine
    /// Überlegung, die niemand hatte.
    static let leistungsstufen: [Double] = [0.1, 0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10, 20, 25, 50]

    /// Die vier Marken der oberen Fläche zu einem Höchstwert: null und drei gleiche Schritte.
    public static func leistungsmarken(hoechstwert: Double) -> [Double] {
        let ziel = hoechstwert.isFinite ? max(hoechstwert, 0) : 0
        let stufe = leistungsstufen.first { $0 * 3 >= ziel } ?? (ziel / 3).rounded(.up)
        return [0, stufe, stufe * 2, stufe * 3]
    }

    /// Der größte Wert, der in der oberen Fläche vorkommt.
    ///
    /// **Die Schwelle zählt mit.** Sie ist eine gestrichelte Waagerechte im Bild
    /// (`Antwortfaecher.tsx:210-231`), und an ihr hängt, was hier „läuft“ heißt. Läge sie
    /// über der Spanne, wäre sie nicht zu sehen - und die Zeichnung erklärte ihr eigenes Wort
    /// nicht mehr.
    public static func hoechsteLeistung(
        faecher: [Faecherpunkt], kurven: [Einzelkurve], schwelleKw: Double
    ) -> Double {
        var hoch = schwelleKw.isFinite ? max(schwelleKw, 0) : 0
        for p in faecher {
            if let m = p.mittelKw, m.isFinite { hoch = max(hoch, m) }
            if let o = p.q75Kw, o.isFinite { hoch = max(hoch, o) }
        }
        for k in kurven {
            for stueck in k.stuecke {
                for punkt in stueck.punkte { hoch = max(hoch, punkt.kw) }
            }
        }
        return hoch
    }

    /// Die Beschriftung einer Marke der oberen Fläche.
    ///
    /// Ohne Nachkommastelle, solange alle Marken ganz sind: „0 / 2 / 4 / 6“ und nicht
    /// „0,0 / 2,0 / 4,0 / 6,0“, wie es ``Formate/kw(_:stellen:)`` sonst schreibt. Die Achse
    /// der Vorlage zählt ebenfalls in ganzen Zahlen, solange die Stufe eine ist.
    public func leistungswort(_ wert: Double) -> String {
        let ganz = leistungsmarken.allSatisfy { $0 == $0.rounded() }
        return Formate.kw(wert, stellen: ganz ? 0 : 1)
    }

    /// Die Beschriftung einer Marke der unteren Fläche: „50 %“ (`formatter: "{value} %"`,
    /// `Antwortfaecher.tsx:169`). Der Wert ist eine Prozentzahl, kein Anteil.
    public static func anteilswort(_ prozent: Double) -> String {
        Formate.prozent(prozent / 100)
    }

    /// Die Beschriftung einer Minute relativ zum Schließen (`wirkung.ts:84-87`).
    ///
    /// Mit Einheit, wie die Funktion der Vorlage. Die Achsen setzen sie nur an den Enden ein und
    /// nehmen dazwischen `achsenmarke`: die Einheit sechsmal unter einer Achse ist Lärm.
    public static func achsenText(_ minute: Int) -> String {
        if minute == 0 { return "Anforderung" }
        return "\(minute > 0 ? "+" : Formate.minus)\(abs(minute)) min"
    }

    /// Die Beschriftung einer Achsenmarke (`Antwortfaecher.tsx:87`,
    /// `Ereignisraster.tsx:71-79`): beim Nullpunkt das Wort, am Ende die Einheit, dazwischen
    /// nur Vorzeichen und Zahl.
    public static func achsenmarke(_ minute: Int, ende: Int) -> String {
        if minute == 0 || minute == ende { return achsenText(minute) }
        return "\(minute > 0 ? "+" : Formate.minus)\(abs(minute))"
    }

    /// Das deutsche Wort zur Urteilskennung (`URTEIL`, `Wirkung.tsx:33-38`).
    ///
    /// Eine unbekannte Kennung steht rohe da - das ist Absicht der Vorlage: lieber ein fremdes
    /// Wort als eine erfundene Übersetzung, die den Dienst falsch wiedergibt. Fehlt die Kennung
    /// ganz, ist nichts entschieden, und genau das heißt „noch offen“.
    public static func urteilswort(_ kennung: String?) -> String {
        switch kennung {
        case nil, "offen": return "noch offen"
        case "wirkt": return "die Maschine folgt"
        case "kein_unterschied": return "kein gesicherter Unterschied"
        case "seltener": return "seltener als sonst"
        case .some(let roh): return roh
        }
    }

    /// „10. Oktober bis 9. November“ in der Zeit des Hauses (`spanne`, `wirkung.ts:115-117`).
    ///
    /// Beide Enden oder keines: „10. Oktober bis -“ wäre keine Spanne.
    public static func spanne(von: String?, bis: String?) -> String? {
        guard let von, let bis, let a = Zeit.ausIso(von), let b = Zeit.ausIso(bis) else {
            return nil
        }
        return "\(tagUndMonat(a)) bis \(tagUndMonat(b))"
    }

    /// „9. November“ - Tag und Monat ausgeschrieben, in der Zeit des Hauses.
    static func tagUndMonat(_ zeitpunkt: Date) -> String {
        let t = Kalender.haus.dateComponents([.day, .month], from: zeitpunkt)
        return "\(t.day ?? 0). \(Namen.monat(t.month ?? 1))"
    }

    /// „Sa., 07.11. 14:35“ - die linke Spalte einer Rasterzeile (`kurzDatum` + `hhmm`).
    ///
    /// **Nicht `Tag.kurz`.** Das schreibt „Sa, 7.11.“ für Blätterleisten. Die Rasterspalte ist
    /// 112 Punkte breit und steht in Festbreitenschrift; mit führenden Nullen stehen die Ziffern
    /// aller achtzig Zeilen untereinander, ohne nicht.
    static func wann(_ zeitpunkt: Date) -> String {
        let t = Kalender.haus.dateComponents([.weekday, .day, .month], from: zeitpunkt)
        let tag = Namen.wochentag(t.weekday ?? 1, kurz: true)
        let datum = String(format: "%02d.%02d.", t.day ?? 0, t.month ?? 0)
        return "\(tag)., \(datum) \(Formate.hhmm(zeitpunkt))"
    }

    /// Wohin eine Rasterzeile führt (`wiedergabeZiel`, `wirkung.ts:120-122`).
    ///
    /// Tag **und** Stunde in der Zeit des Hauses: ein Ereignis um 00:30 Berliner Zeit steht im
    /// ISO-Stempel als 23:30 des Vortages, und die Wiedergabe des falschen Tages zeigt es nicht.
    static func wiedergabeweg(_ zeitpunkt: Date) -> String {
        let stunde = Kalender.haus.component(.hour, from: zeitpunkt)
        return "/waerme/wiedergabe?day=\(Tag.iso(zeitpunkt))&t=\(stunde)"
    }

    /// Die Zeilen des Rasters, nach Gruppe und darin nach Verzögerung (`wirkung.ts:40-53`).
    ///
    /// **Nach Verzögerung und nicht nach Datum**, weil das Raster so seine Form zeigt: stehen die
    /// Anläufe als Treppe dicht hinter dem Nullpunkt, reagiert die Maschine; streuen sie über das
    /// ganze Fenster, tut sie, was sie ohnehin tut. Nach Datum sortiert sähe beides gleich
    /// unruhig aus. Ohne Verzögerung entscheidet der Zeitpunkt, der jüngste zuerst.
    ///
    /// **Nimmt die ganze Antwort und nicht nur die Ereignisse.** Eine Zeile trägt ihren Balken
    /// und ihr Wort, und beides hängt an `schwelle_kw`, `folge_min` und der Breite des
    /// Ausschnitts. Mit nur den Ereignissen müsste die Ansicht den Rest nachtragen - und damit
    /// rechnen.
    public static func geordnet(_ w: KontaktwirkungOut) -> [(
        gruppe: Ereignisgruppe, zeilen: [Ereigniszeile]
    )] {
        let vorMin = w.vorMin ?? vorMinVorgabe
        let nachMin = w.nachMin ?? nachMinVorgabe
        let folgeMin = w.folgeMin ?? folgeMinVorgabe
        // Die jüngsten, nicht die ersten: was die Maschine letzte Woche tat, sagt mehr über heute.
        let gezeigt = Array(w.ereignisse.suffix(maxZeilen))

        return Ereignisgruppe.allCases.compactMap { g in
            let eigene = gezeigt.filter { gruppe($0) == g }
            if eigene.isEmpty { return nil }
            let sortiert = eigene.sorted { a, b in
                let va = a.verzoegerungMin ?? Int.max
                let vb = b.verzoegerungMin ?? Int.max
                if va != vb { return va < vb }
                let ta = Zeit.ausIso(a.at) ?? .distantPast
                let tb = Zeit.ausIso(b.at) ?? .distantPast
                return ta > tb
            }
            let zeilen = sortiert.map { e in
                zeile(e, schwelleKw: w.schwelleKw, vorMin: vorMin, nachMin: nachMin,
                      folgeMin: folgeMin)
            }
            return (gruppe: g, zeilen: zeilen)
        }
    }

    /// Eine einzelne Rasterzeile.
    static func zeile(
        _ e: Ereignis, schwelleKw: Double, vorMin: Int, nachMin: Int, folgeMin: Int
    ) -> Ereigniszeile {
        let b = betrieb(kw: e.kw, schwelleKw: schwelleKw)
        let zeitpunkt = Zeit.ausIso(e.at)
        // Der Kontakt kann länger zu sein als der Ausschnitt reicht; der Streifen endet am Rand.
        let streifen: Range<Int>? =
            e.kontaktMin > 0 ? vorMin..<(vorMin + min(e.kontaktMin, nachMin + 1)) : nil
        return Ereigniszeile(
            at: e.at,
            wann: zeitpunkt.map(wann) ?? Formate.leer,
            ergebnis: ergebnisText(e, folgeMin: folgeMin),
            laeuft: b.laeuft,
            steht: b.steht,
            kontaktMin: e.kontaktMin,
            kontaktstreifen: streifen,
            weg: zeitpunkt.map(wiedergabeweg) ?? "/waerme/wiedergabe")
    }

    // MARK: - Bauen

    /// Das ganze Bild aus einer Antwort des Dienstes.
    public static func baue(_ w: KontaktwirkungOut) -> Wirkungsbild {
        var b = Wirkungsbild()
        b.vorMin = w.vorMin ?? vorMinVorgabe
        b.nachMin = w.nachMin ?? nachMinVorgabe
        b.folgeMin = w.folgeMin ?? folgeMinVorgabe
        b.schwelleKw = w.schwelleKw
        b.breite = b.vorMin + b.nachMin + 1

        b.urteilswort = urteilswort(w.urteil)
        b.urteilssatz = w.urteilDe
        b.spanne = spanne(von: w.von, bis: w.bis)

        b.quotenzeilen = [
            Quotenzeile(
                name: "angefordert", rolle: .angefordert, quote: w.quote, lo: w.quoteLo,
                hi: w.quoteHi, leer: "keine auswertbare Anforderung"),
            Quotenzeile(
                name: "sonst", rolle: .sonst, quote: w.vergleich.quote, lo: w.vergleich.quoteLo,
                hi: w.vergleich.quoteHi, leer: "kein Vergleich zur selben Tageszeit"),
        ]
        b.quotenerklaerung =
            "Anlauf binnen \(b.folgeMin) Minuten bei stehender Maschine. "
            + "Punkt: beobachtete Quote. Balken: der Bereich, in dem die wahre Quote mit "
            + "95 Prozent Sicherheit liegt. Ein Urteil gibt es erst, wenn sich die Balken nicht "
            + "überlappen."
        b.quotenbeschreibung =
            "Anlauf binnen \(b.folgeMin) Minuten: mit Anforderung "
            + "\(Formate.prozentZahl(w.quote)) Prozent, ohne "
            + "\(Formate.prozentZahl(w.vergleich.quote)) Prozent."

        // Das Minutenraster des Fächers. Ist es leer, bleibt auch der Fächer leer - 151 Punkte
        // ohne Messung sind kein Bild, sondern ein leeres Diagramm mit Achsen. Die Einzelkurven
        // brauchen dagegen eine Minute je Messwert; fehlt das Raster, wird der Ausschnitt
        // gezählt, sonst stünden sie am falschen Ort.
        let f = w.faecher
        let raster = f.minuten
        let kurvenraster = raster.isEmpty ? Array((-b.vorMin)...b.nachMin) : raster

        b.faecher = raster.enumerated().map { i, minute in
            let n = i < f.n.count ? f.n[i] : 0
            let band = n >= mindestensFuerBand
            return Faecherpunkt(
                minute: minute,
                mittelKw: wert(f.mittelKw, i),
                q25Kw: band ? wert(f.q25Kw, i) : nil,
                q75Kw: band ? wert(f.q75Kw, i) : nil,
                n: n,
                anteilLaeuft: wert(f.anteilLaeuft, i),
                anteilAngelaufen: wert(f.anteilAngelaufen, i))
        }
        b.mittel = stuecke(minuten: raster, werte: b.faecher.map(\.mittelKw), name: "mittel")
        b.band = bandstuecke(b.faecher)

        let auswertbar = w.ereignisse.filter(\.auswertbar).suffix(maxKurven)
        b.einzelkurven = auswertbar.enumerated().map { k, e in
            Einzelkurve(
                id: k, stuecke: stuecke(minuten: kurvenraster, werte: e.kw, name: "e\(k)"))
        }
        b.kurvendeckung = deckung(auswertbar.count)
        b.leistungsmarken = leistungsmarken(
            hoechstwert: hoechsteLeistung(
                faecher: b.faecher, kurven: b.einzelkurven, schwelleKw: b.schwelleKw))

        b.anteilOhne = w.vergleich.angelaufenBis.enumerated().map { i, anteil in
            (minute: i, anteil: anteil)
        }

        let nAuswertbar = w.nAuswertbar ?? 0
        b.nAuswertbar = nAuswertbar
        if nAuswertbar < mindestensFuerBand {
            b.bandHinweis =
                "das Band der mittleren Hälfte erscheint ab \(mindestensFuerBand) Ereignissen"
        }

        b.gruppen = geordnet(w)
        b.achsenmarken = marken(vorMin: b.vorMin, nachMin: b.nachMin, breite: b.breite)
        b.faechermarken = faechermarken(
            vorMin: b.vorMin, nachMin: b.nachMin, breite: b.breite)

        // **Gezählt werden die gelieferten Ereignisse, nicht `n`** (`alle.length`,
        // `Ereignisraster.tsx:112`). `n` ist die Zahl aller Anforderungen des Zeitraums; begrenzt
        // der Dienst `ereignisse` selbst, nennt der Satz dann eine Zahl, aus der die gezeigten
        // Zeilen nicht gewählt wurden - „die jüngsten 80 von 214“, wo nur 95 überhaupt kamen.
        let geliefert = w.ereignisse.count
        if geliefert > maxZeilen {
            b.rasterHinweis =
                "gezeigt sind die jüngsten \(maxZeilen) von \(geliefert) Anforderungen"
        }
        return b
    }

    /// Ein Wert einer Reihe, oder `nil`, wo die Reihe kürzer ist als das Minutenraster.
    ///
    /// Der Dienst schickt alle Reihen gleich lang. Eine kürzere soll nicht abstürzen und auch
    /// nicht mit Nullen aufgefüllt werden: eine fehlende Stelle ist eine Lücke.
    static func wert(_ reihe: [Double?], _ i: Int) -> Double? {
        i < reihe.count ? reihe[i] : nil
    }

    /// Eine Reihe mit Lücken in zusammenhängende Stücke zerlegen.
    static func stuecke(minuten: [Int], werte: [Double?], name: String) -> [Kurvenstueck] {
        var aus: [Kurvenstueck] = []
        var offen: [Kurvenpunkt] = []

        func schliessen() {
            // Ein einzelner Punkt ist kein Linienstück - aber er ist eine Messung, und er bleibt
            // stehen: `LineMark` zeichnet ihn als Punkt, und das ist richtiger als nichts.
            if !offen.isEmpty {
                aus.append(Kurvenstueck(id: "\(name).\(aus.count)", punkte: offen))
                offen = []
            }
        }

        for (i, minute) in minuten.enumerated() {
            guard let v = wert(werte, i), v.isFinite else {
                schliessen()
                continue
            }
            offen.append(Kurvenpunkt(minute: minute, kw: v))
        }
        schliessen()
        return aus
    }

    /// Die Marken der Achsenzeile, ohne Doppelte und in ihrer Reihenfolge.
    ///
    /// **Nur Marken im Ausschnitt.** Die Vorlage zählt fest `[-vor, 0, 30, 60, 90, nach]` auf und
    /// wirft nur Doppelte weg (`Ereignisraster.tsx:61`). Bei den 120 Minuten des Dienstes fällt
    /// das nicht auf; schickt er einmal ein kürzeres Fenster, stünden Marken rechts außerhalb des
    /// Balkens, mit einem Anteil über 1. Was nicht im Ausschnitt liegt, bekommt keine Marke.
    static func marken(vorMin: Int, nachMin: Int, breite: Int) -> [Achsenmarke] {
        var gesehen: Set<Int> = []
        let roh = [-vorMin, 0, 30, 60, 90, nachMin]
            .filter { $0 >= -vorMin && $0 <= nachMin }
            .filter { gesehen.insert($0).inserted }
        return roh.map { m in
            Achsenmarke(
                minute: m, wort: achsenmarke(m, ende: nachMin),
                anteil: breite > 0 ? Double(m + vorMin) / Double(breite) : 0,
                fein: m != 0 && m != nachMin)
        }
    }

    /// Die Marken der Zeitachse des Fächers: `interval: 30` der Vorlage
    /// (`Antwortfaecher.tsx:79`), vom Beginn des Ausschnitts an.
    ///
    /// Anders als ``marken(vorMin:nachMin:breite:)`` keine feste Liste: eine Achse mit `min` und
    /// `interval` setzt ihre Marken ab dem `min`, und nicht auf die 30er des Nullpunkts.
    static func faechermarken(vorMin: Int, nachMin: Int, breite: Int) -> [Achsenmarke] {
        stride(from: -vorMin, through: nachMin, by: 30).map { m in
            Achsenmarke(
                minute: m, wort: achsenmarke(m, ende: nachMin),
                anteil: breite > 0 ? Double(m + vorMin) / Double(breite) : 0,
                fein: m != 0 && m != nachMin)
        }
    }
}

/// Die fünf Kacheln der Wirkungsseite, in der Reihenfolge der Vorlage (`Wirkung.tsx:170-202`).
///
/// **Warum fünf und welche fünf.** Die App zeigte sechs andere: „Quote“, „Ereignisse“,
/// „gefolgt“, „lief schon“, „Verzögerung“, „Nachlauf“ - teils dieselbe Zahl zweimal, und ohne
/// die führende Zahl `n`. Vor allem fehlte „ohne Anforderung angelaufen“: die Vergleichsquote ist
/// die halbe Aussage der Seite, denn eine Pumpe, die immer anläuft, folgt keiner Anforderung.
///
/// **Was es nicht ist:** keine Wertung. Der Ton sagt, welche Rolle eine Zahl hat, nicht ob sie
/// gut ist. Eine Quote von 19 Prozent ohne Anforderung ist kein Fehler, sondern der Vergleich.
public enum Wirkungskacheln {

    public static func kacheln(_ w: KontaktwirkungOut) -> [Kennzahl] {
        let n = w.n ?? 0
        let nAuswertbar = w.nAuswertbar ?? 0
        let nLiefSchon = w.nLiefSchon ?? 0
        let gefolgt = w.gefolgt ?? 0
        let folgeMin = w.folgeMin ?? Wirkungsbild.folgeMinVorgabe
        let v = w.vergleich

        return [
            Kennzahl(
                wort: "Anforderungen", wert: String(n),
                dazu: n == 0
                    ? "im Zeitraum keiner"
                    : "\(nAuswertbar) bei stehender Maschine, \(nLiefSchon) bei laufender"),
            Kennzahl(
                wort: "danach angelaufen", wert: Formate.prozentZahl(w.quote),
                einheit: w.quote == nil ? nil : "%",
                dazu: nAuswertbar > 0
                    ? "\(gefolgt) von \(nAuswertbar) binnen \(folgeMin) Minuten, "
                        + "\(nAuswertbar - gefolgt) nicht"
                    : "keine auswertbare Anforderung",
                ton: .glut),
            Kennzahl(
                wort: "ohne Anforderung angelaufen", wert: Formate.prozentZahl(v.quote),
                einheit: v.quote == nil ? nil : "%",
                dazu: v.quote == nil
                    ? "kein Vergleich zur selben Tageszeit"
                    : "zur selben Tageszeit, aus \(v.nGleicheStunde ?? 0) Vergleichsmomenten",
                ton: .nebel),
            Kennzahl(
                wort: "Verzögerung", wert: Formate.minutenZahl(w.verzoegerungMedianMin),
                einheit: w.verzoegerungMedianMin == nil ? nil : "min",
                dazu: "Median von der Anforderung bis zum Anlauf", ton: .gedaempft),
            Kennzahl(
                wort: "Nachlauf", wert: Formate.minutenZahl(w.nachlaufMedianMin),
                einheit: w.nachlaufMedianMin == nil ? nil : "min",
                dazu: nachlaufSatz(w.nachlaufN), ton: .gedaempft),
        ]
    }

    /// „Median nach dem Ende der Anforderung, 3 Fälle“ - und ohne Fälle der Grund dafür.
    static func nachlaufSatz(_ faelle: Int?) -> String {
        guard let faelle, faelle > 0 else { return "kein Ende bei laufender Maschine" }
        let wort = faelle == 1 ? "1 Fall" : "\(faelle) Fälle"
        return "Median nach dem Ende der Anforderung, \(wort)"
    }
}

extension Formate {

    /// Ein Anteil als ganze Prozentzahl **ohne** Einheit: „94“ (`prozentZahl`, `wirkung.ts:90-92`).
    ///
    /// **Warum es die neben `prozent` gibt.** Die Einheit steht an manchen Stellen nur einmal:
    /// „94 bis 100 %“ nennt sie am Ende, die Achse trägt sie in ihrer eigenen Beschriftung, und
    /// die Kachel setzt sie in eigener Schrift neben die Zahl. Mit `prozent` stünde dort
    /// „94 % bis 100 %“ - dieselbe Angabe zweimal.
    public static func prozentZahl(_ anteil: Double?) -> String {
        guard let anteil, anteil.isFinite else { return leer }
        return zahl(anteil * 100, stellen: 0)
    }

    /// Eine Dauer in Minuten als bloße Zahl: „95“ (`minuten`, `Wirkung.tsx:108-110`).
    ///
    /// **Warum nicht `dauer`.** Das schaltet ab einer Stunde auf „1 h 35 min“ um. Die Kacheln
    /// „Verzögerung“ und „Nachlauf“ tragen ihre Einheit getrennt und zählen immer in Minuten;
    /// bei einem Nachlauf von 95 Minuten stünden App und Wandanzeige sonst verschieden da - und
    /// zwei Antworten auf dieselbe Frage sind schlimmer als eine lange Zahl.
    public static func minutenZahl(_ wert: Double?) -> String {
        zahl(wert, stellen: 0)
    }
}
