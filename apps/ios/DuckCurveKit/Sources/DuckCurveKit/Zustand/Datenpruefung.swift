import Foundation

// =====================================================================================
//  Die Seite „Daten prüfen" - was der Abgleich mit der Vorlage nachtrug.
//
//  Vorlage: `apps/web/src/components/reports/DataCheck.tsx` mit `CoverageMap.tsx` und
//  `charts.ts` (`powerOverlay`, `yearMap`). `Zustand/Datenbild.swift` trägt die Reihen, die
//  Quellen und das Raster; hier stehen die vier Rechnungen, die dort fehlten:
//
//  1. ``Pruefstand`` - welcher Satz in welcher Karte steht, solange noch nichts da ist. Die
//     App behauptete beim Öffnen „Für diesen Tag liegen keine Minutenwerte vor", wo die
//     Vorlage „lädt …" schreibt (`DataCheck.tsx:83`, `:115`, `CoverageMap.tsx:102`,
//     `Sources.tsx:49`).
//  2. ``Pruefkurve/auskunft(stunde:)`` - die Werte der berührten Minute. Das ist das
//     Werkzeug, mit dem man die zwei Gegenproben vergleicht (`charts.ts:591-601`).
//  3. ``Abdeckungsraster/auskunft(tag:stunde:)`` samt ``Abdeckungsraster/treffer(x:y:gesamt:spalten:zellenhoehe:luecke:)``
//     - welche Zelle unter dem Finger liegt und was sie sagt (`charts.ts:470-483`).
//  4. Die Worte, die es nur im Browser gab: der CSV-Verweis und die drei Ladesätze.
//
//  Keine Farben, keine Maße, keine Ansicht - nur die Rechnung und das Wort.
// =====================================================================================

/// Wie weit die vier Abfragen dieser Seite sind, und was statt ihres Inhalts dasteht.
///
/// **Warum das eine Rechnung ist und keine Oberfläche.** Die Vorlage schreibt in jede der vier
/// Karten zuerst „lädt …" und erst danach den Befund (`DataCheck.tsx:83`, `:115`,
/// `CoverageMap.tsx:102`, `Sources.tsx:49`). Die App hatte dafür nichts: `hatMinuten` begann
/// auf `false`, und damit stand beim Öffnen der Seite „Für diesen Tag liegen keine
/// Minutenwerte vor" - ein Befund über die Datenlage, wo noch nichts abgefragt war. Auf
/// gerade dieser Seite ist das der schlimmste Fehler, den sie machen kann: sie ist die Seite,
/// auf der man nachsieht, ob den Zahlen zu glauben ist.
///
/// **Und warum das Störungsband hierher gehört.** Es steht in der Vorlage nur, wenn Verlauf
/// **und** Diagnose scheitern (`DataCheck.tsx:41`); eine gescheiterte Abdeckungsabfrage
/// ersetzt nur die eigene Karte (`CoverageMap.tsx:93, 101`) und lässt den Rest der Seite in
/// Ruhe. In der App war es umgekehrt: `fehler` kam ausschließlich aus der Abdeckung. Die Seite
/// schlug also oben Alarm, wenn die Wärmekarte fehlte, und blieb stumm, wenn die beiden
/// Reihen fehlten, um die es geht. Diese Zuordnung ist eine Bedingung über vier Zustände und
/// gehört deshalb unter Test und nicht in einen `ViewBuilder`.
public struct Pruefstand: Sendable, Hashable {

    /// Wie weit eine einzelne Abfrage ist.
    ///
    /// Vier Fälle und nicht drei: „nichts gekommen" und „gekommen, aber leer" sind auf dieser
    /// Seite verschiedene Nachrichten. Ein Tag ohne Minutenwerte ist ein Tag aus dem
    /// Historienimport; eine gescheiterte Abfrage ist ein Fehler der Verbindung, und wer die
    /// beiden zusammenwirft, schreibt dem Dienst ein Loch zu, das das Netz hatte.
    public enum Lage: String, Sendable, Hashable, CaseIterable {
        /// Die Abfrage läuft noch. In der Vorlage `loading`.
        case laedt
        /// Antwort da, Inhalt da.
        case da
        /// Antwort da, nichts darin.
        case leer
        /// Keine Antwort.
        case fehler
    }

    /// Die Minutenwerte des Tages (`api.historyDay`).
    public var kurve: Lage
    /// Der Augenblick aus dem Live-Zustand (`api.liveState`).
    public var quellen: Lage
    /// Die Wärmekarte über achtundzwanzig Tage (`api.coverage`).
    public var abdeckung: Lage
    /// Die Stundenbilanz als Text (`api.diagnoseDay`).
    public var diagnose: Lage

    public init(
        kurve: Lage = .laedt, quellen: Lage = .laedt, abdeckung: Lage = .laedt,
        diagnose: Lage = .laedt
    ) {
        self.kurve = kurve
        self.quellen = quellen
        self.abdeckung = abdeckung
        self.diagnose = diagnose
    }

    /// Die Lage einer Abfrage aus ihrem Ergebnis.
    ///
    /// Zwei Fragen und nicht eine: ob überhaupt geantwortet wurde, und ob etwas darin stand.
    /// Beides als ein `Optional` zu führen wäre der Fehler, den die Seite schon hatte.
    public static func lage(antwortDa: Bool, inhaltDa: Bool) -> Lage {
        guard antwortDa else { return .fehler }
        return inhaltDa ? .da : .leer
    }

    /// Das Störungsband über der Seite - oder `nil`, und das ist der Normalfall.
    ///
    /// **Nur wenn Verlauf und Diagnose beide scheitern** (`DataCheck.tsx:41`). Beide kommen aus
    /// derselben Abfrage desselben Tages; scheitern beide, ist nicht eine Zahl fraglich,
    /// sondern die Verbindung. Scheitert eine, steht ihr Satz in ihrer Karte, und die andere
    /// Hälfte der Seite bleibt lesbar.
    public var stoerung: String? {
        kurve == .fehler && diagnose == .fehler ? Pruefworte.ladefehler : nil
    }

    /// Was in der Hauptkarte statt des Bildes steht (`DataCheck.tsx:81-84`).
    ///
    /// Eine gescheiterte Abfrage bekommt hier denselben Satz wie ein leerer Tag, und das ist
    /// die Vorlage: sie setzt `rows` auf `[]`, wenn die Abfrage scheitert, und schreibt danach
    /// den Leersatz. Die Nachricht „es ging etwas schief" steht in diesem Fall oben im Band
    /// und nicht zweimal.
    public var kurvensatz: String? {
        switch kurve {
        case .da: return nil
        case .laedt: return Pruefworte.laedt
        case .leer, .fehler: return Pruefkurve.leersatz
        }
    }

    /// Was in der Quellenkarte statt der Zeilen steht (`Sources.tsx:48-49`).
    public var quellensatz: String? {
        switch quellen {
        case .da: return nil
        case .laedt: return Pruefworte.laedt
        case .leer, .fehler: return Quellenstand.nichtAbrufbar
        }
    }

    /// Was in der Abdeckungskarte statt der Wärmekarte steht (`CoverageMap.tsx:101-102`).
    ///
    /// **`leer` gibt hier keinen Satz.** Eine Antwort ohne Reihen ist etwas anderes als eine
    /// gescheiterte Abfrage - der Dienst hat dann geantwortet und nichts zu melden -, und das
    /// sagt die Karte selbst. Die Karte bleibt in jedem Fall stehen; die Vorlage ersetzt bei
    /// einem Fehler nur ihren Inhalt und nicht die Stelle.
    public var rastersatz: String? {
        switch abdeckung {
        case .da, .leer: return nil
        case .laedt: return Pruefworte.laedt
        case .fehler: return Abdeckungsraster.nichtAbrufbar
        }
    }

    /// Was in der Stundenbilanz statt des Textes steht (`DataCheck.tsx:115`).
    public var diagnosesatz: String? {
        switch diagnose {
        case .da: return nil
        case .laedt: return Pruefworte.laedt
        case .leer, .fehler: return Pruefworte.keineDiagnose
        }
    }
}

// =====================================================================================
//  Die Worte, die es nur im Browser gab
// =====================================================================================

extension Pruefworte {
    /// Was dasteht, solange eine Abfrage läuft (`DataCheck.tsx:83`).
    ///
    /// **Ein Satz und nicht vier.** Die Vorlage schreibt ihn an vier Stellen gleich; in der App
    /// stand er in anderen Seitentexten je einmal für sich (etwa `Speichertagkurve`), und drei
    /// Schreibweisen von „lädt" auf einer Seite sind zwei zu viel.
    public static let laedt = "lädt …"

    /// Das Störungsband, wenn Verlauf und Diagnose beide scheitern (`DataCheck.tsx:41`).
    public static let ladefehler = "Daten konnten nicht geladen werden."

    /// Die Stundenbilanz, wenn der Dienst nichts schickt (`DataCheck.tsx:115`).
    public static let keineDiagnose = "Keine Diagnose verfügbar."

    /// Der Verweis auf die Rohdaten, wörtlich (`DataCheck.tsx:104-108`).
    ///
    /// **Er ist einer der drei Gründe, aus denen diese Seite besteht.** Der Kopf der Vorlage
    /// zählt sie auf: die Reihen übereinander, dieselben Zahlen je Stunde, „und daneben der Weg
    /// zu den Rohdaten … braucht genau diese drei Dinge und nichts weiter"
    /// (`DataCheck.tsx:16-20`). In der App fehlte er ganz.
    ///
    /// Der Pfeil steht am Wort wie bei der Jahressicherung (``Zugang/Exportart/wort``) und
    /// zeigt nach rechts wie in der Vorlage: dort führt er aus der App hinaus, hier auch.
    public static let csvVerweis = "Minutenwerte dieses Tages als CSV ›"


    /// Der Weg zurück zum ganzen Tag (`charts.ts:645`, `restore: { title: "Ganzer Tag" }`).
    public static let ganzerTag = "Ganzer Tag"

    /// Was über dem Bild steht, solange niemand es berührt hat.
    ///
    /// **Kein Gegenstück in der Vorlage, und es muss eines geben.** Dort schwebt das
    /// Hinweisfenster am Zeiger und braucht keine Ankündigung - eine Maus ist schon da. Am
    /// Telefon ist die Geste unsichtbar, bis man sie macht, und die Zeile über dem Bild wäre
    /// sonst beim Öffnen leer und würde die Höhe der Karte beim ersten Tippen verschieben.
    /// Dieselbe Entscheidung, mit derselben Begründung, trifft die Nachbetrachtung
    /// (`Diagramme/Tagesvergleichsbild.swift:78-80`).
    public static let beruehrung = "Zum Lesen einer Minute die Fläche berühren."

    /// Der Befund zur Lücke in der Erzeugungsreihe, oder `nil`, wenn es keinen gibt.
    ///
    /// **Warum diese Zahl jetzt dasteht.** ``Pruefworte/zaehler`` verspricht sie wörtlich: die
    /// Stundenbilanz „zählt die Minuten auf genau 0,00 kW und meldet es, wenn sich der Netzwert
    /// in derselben Strecke weiterbewegt". Gerechnet und geprüft war das längst
    /// (``Pruefkurve/luecken()``), gezeigt wurde es nirgends - ein Versprechen im Text, dem
    /// nichts auf dem Schirm entsprach. Die Vorlage zeigt die Zahl selbst auch nicht; sie
    /// verweist dafür auf den Diagnosetext (`DataCheck.tsx:142-146`), und genau unter dem steht
    /// dieser Satz.
    ///
    /// **Zwei Befunde, zwei Sätze.** Stehen Erzeugung und Netz gleichzeitig still, kann es eine
    /// Wolke gewesen sein; läuft das Netz weiter, liefert der Zähler und die Erzeugungsmessung
    /// nicht - und eine ausgewiesene Netzladung des Speichers ist dann eine Folge der Lücke
    /// und kein Verhalten des Geräts. Wer beides gleich benennt, schreibt dem Speicher ein
    /// Verhalten zu, das er nicht hatte.
    public static func erzeugungsluecke(_ luecke: Pruefkurve.Erzeugungsluecke?) -> String? {
        guard let luecke else { return nil }
        let von = Pruefkurve.uhrzeit(stunde: luecke.von)
        let bis = Pruefkurve.uhrzeit(stunde: luecke.bis)
        let minuten = "\(luecke.minuten)\(Formate.schmalesLeerzeichen)Minuten"
        switch luecke.befund {
        case .keine:
            return nil
        case .luecke:
            return "Zwischen \(von) und \(bis) steht die Erzeugung \(minuten) auf genau 0,00 kW, der Netzwert in derselben Strecke ebenfalls still. Das kann eine Wolke gewesen sein."
        case .lueckeMitNetzbewegung:
            return "Zwischen \(von) und \(bis) steht die Erzeugung \(minuten) auf genau 0,00 kW, während sich der Netzwert weiterbewegt: dann liefert der Zähler, die Erzeugungsmessung aber nicht, und eine ausgewiesene Netzladung ist eine Folge der Lücke."
        }
    }

}

// =====================================================================================
//  Die Auskunft zu einer Stelle der Prüfkurve
// =====================================================================================

extension Pruefkurve.Reihe {
    /// Die Einheit, in der der Wert dieser Reihe dasteht.
    ///
    /// **Hier weicht die App von der Vorlage ab, und zwar bewusst.** Deren Hinweisfenster hängt
    /// an jede Zeile „kW" (`charts.ts:597`), auch an den Ladestand - dessen Wert ist aber
    /// Prozent, und die Reihe heißt im selben Fenster „Ladestand %". „84,00 kW" neben einem
    /// Speicher mit 5,1 kWh ist auf einer Seite, die Messwerte gegeneinander prüft, die eine
    /// Zahl, die man nicht schreiben darf. Die rechte Achse ist dort ausdrücklich Prozent
    /// (`charts.ts:706-717`, `name: "%"`), also steht das hier auch an der Zahl.
    public var einheit: String {
        rechteAchse ? "%" : "kW"
    }
}

extension Pruefkurve {

    /// Die Werte an einer Stelle der Zeitachse (`charts.ts:591-601`).
    ///
    /// **Das ist das Werkzeug, für das die Seite da ist.** Zwei Reihen messen hier absichtlich
    /// dasselbe zweimal - der amtliche Zähler gegen den Stromwandler, der Ladestand gegen die
    /// Ladeleistung. Ob sie zueinander passen, entscheidet sich nicht am Bild, sondern an zwei
    /// Zahlen zur selben Minute; ohne sie lässt sich eine Abweichung sehen und nicht beziffern.
    public struct Auskunft: Sendable, Hashable {

        /// Eine Reihe mit ihrem Wert an dieser Stelle.
        public struct Zeile: Sendable, Hashable, Identifiable {
            public let reihe: Pruefkurve.Reihe
            /// Fertig gesetzt: zwei Nachkommastellen und die Einheit.
            public let wert: String

            public var id: String { reihe.rawValue }

            public init(reihe: Pruefkurve.Reihe, wert: String) {
                self.reihe = reihe
                self.wert = wert
            }
        }

        /// Die Minute, auf die der Finger eingerastet ist, als „07:34".
        public let zeit: String
        /// Die Reihen in der Reihenfolge der Legende. Reihen ohne Wert fallen weg.
        public let zeilen: [Zeile]

        public init(zeit: String, zeilen: [Zeile]) {
            self.zeit = zeit
            self.zeilen = zeilen
        }
    }

    /// Wie viele Nachkommastellen die Auskunft zeigt.
    ///
    /// **Zwei, und nicht die eine von ``Formate/kw(_:stellen:)``** (`charts.ts:597`,
    /// `de1(…, 2)`). Mit einer Stelle stünde bei Wandler und Zähler dreimal dieselbe Zahl, und
    /// die Frage, ob sie sich unterscheiden, ist genau die Frage dieser Seite.
    public static let auskunftsstellen = 2

    /// Wie nah ein Punkt an der eingerasteten Stelle liegen muss, um mitzuzählen.
    ///
    /// **Eine Viertelminute, also fast genau.** Die Vorlage listet im Hinweisfenster nur die
    /// Reihen, die zu *diesem* Zeitstempel einen Wert haben (`charts.ts:596`,
    /// `p.value[1] != null`); der Zähler meldet alle rund fünfzehn Minuten und fehlt deshalb in
    /// vierzehn von fünfzehn Fenstern. Den nächstgelegenen Zählerwert aus sieben Minuten
    /// Entfernung dazuzuschreiben, wäre auf dieser Seite keine Hilfe, sondern eine falsche
    /// Gegenprobe - man verglich dann zwei Minuten und glaubte, eine zu vergleichen. Die
    /// Viertelminute ist nur die Luft, die das Rechnen in `Double` braucht; das Raster ist ein
    /// Minutenraster.
    public static let auskunftsraster: Double = 0.25 / 60

    /// Eine Stunde seit Tagesbeginn als Uhrzeit: 7,5667 wird „07:34".
    ///
    /// **Am Tag der Zeitumstellung ist das die Stunde seit Mitternacht und nicht die Uhrzeit
    /// der Wand.** Dieselbe Vereinfachung macht die Stundenachse des Bildes
    /// (`Diagramme/Pruefkurvenbild.swift`, `Int(stunde) % 24`), und beide müssen dieselbe
    /// machen: eine Achse, die „03:00" schreibt, und eine Auskunft, die für denselben Punkt
    /// „02:00" sagt, wäre schlimmer als eine Stunde Versatz an zwei Tagen im Jahr.
    public static func uhrzeit(stunde: Double) -> String {
        guard stunde.isFinite else { return Formate.leer }
        let tag = 24 * 60
        var minuten = Int((stunde * 60).rounded()) % tag
        if minuten < 0 { minuten += tag }
        return String(format: "%02d:%02d", minuten / 60, minuten % 60)
    }

    /// Die Auskunft zu der Stelle, die dem Finger am nächsten liegt.
    ///
    /// **Eingerastet und nicht interpoliert.** Die Stelle ist der nächstgelegene gemessene
    /// Punkt irgendeiner Reihe - auf einer Seite, die Messwerte prüft, darf keine Zahl
    /// dastehen, die niemand gemessen hat. Gerechnet wird auf der Kurve, die auch gezeichnet
    /// ist: über den ganzen Tag ist das die verdichtete, im Zeitfenster die volle Auflösung,
    /// und eine Auskunft, die eine andere Zahl nennt als die Linie darunter zeigt, wäre auf
    /// dieser Seite die schlimmste.
    ///
    /// `nil`, solange die Kurve leer ist oder die Stelle keine Reihe trifft.
    public func auskunft(stunde: Double) -> Auskunft? {
        guard stunde.isFinite else { return nil }
        var rast: Double?
        var abstand = Double.infinity
        for reihe in Reihe.allCases {
            for p in punkte(reihe) where p.stunde.isFinite {
                let d = abs(p.stunde - stunde)
                if d < abstand {
                    abstand = d
                    rast = p.stunde
                }
            }
        }
        guard let rast else { return nil }
        let zeilen = Reihe.allCases.compactMap { reihe -> Auskunft.Zeile? in
            guard
                let p = punkte(reihe).first(where: {
                    abs($0.stunde - rast) <= Self.auskunftsraster
                })
            else { return nil }
            return Auskunft.Zeile(
                reihe: reihe,
                wert: Formate.zahl(p.wert, stellen: Self.auskunftsstellen)
                    + Formate.schmalesLeerzeichen + reihe.einheit)
        }
        guard !zeilen.isEmpty else { return nil }
        return Auskunft(zeit: Self.uhrzeit(stunde: rast), zeilen: zeilen)
    }

    // MARK: - Das Zeitfenster

    /// Eine angebotene Fensterbreite mit ihrem Wort auf dem Knopf.
    public struct Fensterbreite: Sendable, Hashable, Identifiable {
        public let stunden: Double
        public let wort: String

        public var id: String { wort }

        public init(stunden: Double, wort: String) {
            self.stunden = stunden
            self.wort = wort
        }
    }

    /// Die drei Fensterbreiten, die die App anbietet.
    ///
    /// **Hier geht die App einen eigenen Weg, und die Messung sagt, warum.** Die Vorlage hat
    /// für das Zeitfenster drei eigene Bedienwege - ein Werkzeug zum Aufziehen, einen Regler
    /// unter dem Bild, Rad und zwei Finger am Zeiger (`charts.ts:634-672`) - und *daneben* das
    /// Hinweisfenster am Zeiger. Swift Charts hat für beides nur die Wischgeste:
    /// `chartXSelection(range:)` und `chartXSelection(value:)` nehmen sie einander weg. Die
    /// Geste bekommt deshalb die Auskunft, die man nur so haben kann, und das Fenster bekommt
    /// Knöpfe - denselben Weg geht die App beim Spannenschalter am Telefon
    /// (`Bausteine/Spannenstreifen.swift:19-40`).
    ///
    /// Eine, drei, sechs Stunden: eine Stunde ist die Strecke, um die es meist geht (ein Lauf
    /// der Wärmepumpe, eine Ladung), sechs sind ein Vormittag. Ein Fenster unter einer Stunde
    /// braucht es nicht - bei sechzig Minuten auf tausend Bildpunkten ist die einzelne Minute
    /// schon breiter als der Finger.
    public static let fensterbreiten: [Fensterbreite] = [
        Fensterbreite(stunden: 1, wort: "1" + Formate.schmalesLeerzeichen + "h"),
        Fensterbreite(stunden: 3, wort: "3" + Formate.schmalesLeerzeichen + "h"),
        Fensterbreite(stunden: 6, wort: "6" + Formate.schmalesLeerzeichen + "h"),
    ]

    /// Ein Fenster dieser Breite um eine Stelle, innerhalb des Tages.
    ///
    /// **Am Tagesrand verschiebt sich das Fenster, statt zu schrumpfen.** Ein halbes Fenster um
    /// 23:50 zeigte die halbe Auflösung - und wer dort nachsieht, sucht gerade die Strecke am
    /// Rand. Dieselbe Breite, nur verschoben, ist die Antwort, die er erwartet.
    ///
    /// Eine Breite, die größer ist als der Tag, gibt den ganzen Tag; der ist dann genau das
    /// Fenster, und „Ganzer Tag" braucht niemand zu drücken, um dasselbe zu sehen.
    public func fensterUm(_ stunde: Double, breiteH: Double) -> ClosedRange<Double> {
        let tagesende = max(0, stunden)
        let breite = min(max(0, breiteH), tagesende)
        guard breite > 0, stunde.isFinite else { return 0...tagesende }
        var von = min(max(0, stunde - breite / 2), tagesende - breite)
        if von < 0 { von = 0 }
        return von...(von + breite)
    }
}

// =====================================================================================
//  Die Auskunft zu einer Zelle der Abdeckungskarte
// =====================================================================================

extension Abdeckungsraster {

    /// Was eine Zelle der Wärmekarte sagt (`charts.ts:470-483`).
    public struct Zellenauskunft: Sendable, Hashable {
        /// Der Tag als „Di., 10. November 2026" (``Tag/langKurzerWochentag(_:)``).
        public let tag: String
        /// Die Stunde als „07:00 - 07:59".
        public let stunde: String
        /// Die Minutenzahl als „42 min" - oder ``Abdeckungsraster/leereZelle``.
        public let wert: String
        /// Gibt es für diese Stunde überhaupt eine Minutenzeile?
        ///
        /// Die Ansicht braucht das, nicht den Text: eine leere Zelle sagt etwas über **uns**,
        /// eine rote etwas über das Gerät, und der Satz dazu steht leiser als eine Zahl.
        public let leer: Bool

        public init(tag: String, stunde: String, wert: String, leer: Bool) {
            self.tag = tag
            self.stunde = stunde
            self.wert = wert
            self.leer = leer
        }
    }

    /// Was in einer Zelle ohne Minutenzeile steht.
    ///
    /// **Die Vorlage sagt hier nichts, und sie muss nicht.** Ihre Wärmekarte hat für eine leere
    /// Stunde gar keinen Datenpunkt (`charts.ts:450-451`), also auch kein Hinweisfenster - der
    /// Zeiger findet dort nichts. Auf einem `Canvas` trifft der Finger jede Stelle, und eine
    /// Berührung, die wortlos bleibt, sieht aus wie eine Karte, die nicht reagiert. Das Wort
    /// ist zugleich die Auskunft, um die es auf dieser Seite geht: leer ist nicht null
    /// (`CoverageMap.tsx:24-27`, „Der Unterschied entscheidet, wen man anschaut").
    public static let leereZelle = "keine Minutenzeile"

    /// Was über der Karte steht, solange niemand sie berührt hat.
    ///
    /// Kein Gegenstück in der Vorlage, und aus demselben Grund nötig wie
    /// ``Pruefworte/beruehrung`` über der Prüfkurve: dort schwebt ein Hinweisfenster am Zeiger,
    /// hier ist die Geste unsichtbar, bis man sie macht. „Stunde" und nicht „Zelle": das Wort
    /// nennt, was man erfährt, und nicht, woraus das Bild gebaut ist.
    public static let beruehrung = "Zum Lesen einer Stunde die Karte berühren."

    /// Die Auskunft zu einer Zelle, oder `nil`, wenn es die Zelle nicht gibt.
    public func auskunft(tag: Int, stunde: Int) -> Zellenauskunft? {
        guard tage.indices.contains(tag), (0..<24).contains(stunde) else { return nil }
        let spalte = tage[tag]
        let minuten = stunde < spalte.stunden.count ? spalte.stunden[stunde] : nil
        return Zellenauskunft(
            tag: Tag.langKurzerWochentag(spalte.tag),
            stunde: String(format: "%02d:00 - %02d:59", stunde, stunde),
            wert: minuten.map { "\($0)\(Formate.schmalesLeerzeichen)min" } ?? Self.leereZelle,
            leer: minuten == nil)
    }

    // MARK: - Welche Zelle unter dem Finger liegt

    /// Eine Zelle der Wärmekarte: Spalte und Zeile.
    public struct Treffer: Sendable, Hashable {
        /// Der Index des Tages, also die Spalte von links.
        public let tag: Int
        /// Die Stunde, also die Zeile von oben - Mitternacht ist oben.
        public let stunde: Int

        public init(tag: Int, stunde: Int) {
            self.tag = tag
            self.stunde = stunde
        }
    }

    /// Wie breit eine Spalte des Rasters ist.
    ///
    /// **Eine Rechnung, zwei Verwendungen - und darum hier.** Die Ansicht malt damit
    /// (`Diagramme/Abdeckungskarte.swift`) und rechnet damit zurück, welche Zelle berührt
    /// wurde. Stünde die Formel zweimal dort, zeigte die Auskunft nach der ersten Änderung auf
    /// die Nachbarspalte - und das wäre genau der Fehler, den man auf dieser Seite nicht
    /// bemerkt, weil zwei Nachbartage ähnlich aussehen.
    public static func spaltenbreite(gesamt: Double, spalten: Int, luecke: Double) -> Double {
        guard spalten > 0 else { return 0 }
        return max(1, (gesamt - Double(spalten - 1) * luecke) / Double(spalten))
    }

    /// Welche Zelle unter einem Punkt des Rasterkastens liegt.
    ///
    /// **Die erste Trefferrechnung dieser Art im Projekt.** Die Karte ist aus gutem Grund
    /// gezeichnet und nicht gestapelt - über zweitausend Felder -, und damit gibt es keine
    /// Marke, die ein Tippen treffen könnte: Spalte und Zeile sind aus derselben Rechnung
    /// zurückzurechnen, mit der gemalt wird. Dass sie im Kern steht und nicht in der Ansicht,
    /// ist der einzige Weg, sie zu prüfen.
    ///
    /// **Die Fuge zählt zur Spalte links davon.** Zwischen zwei Spalten liegt ein Punkt Luft;
    /// ein Finger ist vierzig mal so breit, und „daneben getroffen, also keine Auskunft" wäre
    /// an einer Stelle, die man nicht sehen kann, die falsche Strenge.
    ///
    /// **Außerhalb des Kastens gibt es dagegen keine Zelle**: links steht die Stundenachse,
    /// unten die Tagesachse. Geprüft wird gegen die Maße und nicht nur gegen die Zahl der
    /// Spalten - achtundzwanzig Spalten von 9,04 Punkten mit Fuge sind in `Double` genau 281,0
    /// breit, und ein Finger bei 281 landete über die Rundung in der letzten Spalte statt
    /// daneben.
    public static func treffer(
        x: Double, y: Double, gesamt: Double, spalten: Int, zellenhoehe: Double, luecke: Double
    ) -> Treffer? {
        guard spalten > 0, gesamt > 0, zellenhoehe > 0, luecke >= 0 else { return nil }
        guard x.isFinite, y.isFinite, x >= 0, y >= 0, x <= gesamt else { return nil }
        let hoehe = 24 * zellenhoehe + 23 * luecke
        guard y <= hoehe else { return nil }
        let breite = spaltenbreite(gesamt: gesamt, spalten: spalten, luecke: luecke)
        let spalte = Int(x / (breite + luecke))
        let zeile = Int(y / (zellenhoehe + luecke))
        guard spalte < spalten, zeile < 24 else { return nil }
        return Treffer(tag: spalte, stunde: zeile)
    }
}
