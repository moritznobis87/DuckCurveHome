import Foundation

/// Das gemeinsame Raster der Fahrplanseite: eine Werteachse fester Breite, die Spaltenzahl der
/// Kacheln und die Zellwörter einer Entscheidungszeile.
///
/// **Warum das eine Datei ist.** Alle drei sind dieselbe Art von Aufgabe: Die Vorlage legt eine
/// Zahl, eine Schwelle oder ein Wort fest, und die Ansicht darf sie nicht erraten. Die Vorlage
/// setzt allen acht Gittern der Zeichnung dieselben Ränder (`waerme/Fahrplan.tsx:291`:
/// `left: 56, right: 18`), sie schaltet das Kachelraster an zwei festen Breiten um (`:548`:
/// `grid-cols-2 md:grid-cols-4 xl:grid-cols-7`) und sie baut jede Tabellenzeile am Telefon zu
/// einem Block mit vier Spalten um (`styles/handy.css:319-329`). Keine der drei Zahlen und
/// keines der Wörter ist eine Frage des Zeichnens.
public enum Fahrplanraster {

    // MARK: - Die gemeinsame Werteachse der acht Flächen

    /// Eine Beschriftung der Werteachse: ihr Wert, ihr Wort und wo sie steht.
    ///
    /// ``anteil`` ist der Platz in der Spanne, 0 unten und 1 oben. Die Ansicht setzt die Zahl
    /// damit neben ihre Rasterlinie, ohne die Spanne noch einmal zu kennen.
    public struct Achsenmarke: Sendable, Hashable, Identifiable {
        public let wert: Double
        public let wort: String
        public let anteil: Double

        public var id: Double { wert }

        public init(wert: Double, wort: String, anteil: Double) {
            self.wert = wert
            self.wort = wort
            self.anteil = anteil
        }
    }

    /// Die Beschriftungen einer Werteachse, von der Untergrenze aufwärts in runden Stufen.
    ///
    /// **Warum die unterste Zahl immer dabei ist.** Die Vorlage setzt an jeder der fünf
    /// Werteachsen `showMinLabel: true` und begründet das selbst
    /// (`waerme/Fahrplan.tsx:264-267`): Die Achsen fangen nicht bei null an, sondern bei einer
    /// abgerundeten Untergrenze (``Fahrplanbild/untergrenze(_:stufe:)``), und ohne diese Zahl
    /// liefe die Kurve unter die tiefste Beschriftung - genau die soll man ablesen können. Die
    /// Marken stehen deshalb bei `unten + k · Stufe` und nicht auf runden Vielfachen.
    ///
    /// **Warum nicht `AxisMarks(values: .automatic)`.** Die Zahlen stehen nicht mehr im
    /// Diagramm, sondern in einer eigenen Spalte links davon - nur so haben alle acht Flächen
    /// dieselbe linke Kante (``achsenbreite`` in der Zeichnung, Vorlage `:291`). Dann muss die
    /// Ansicht aber wissen, *welche* Zahlen sie hinschreibt und *wo*, und eine automatische
    /// Achse sagt ihr das nicht.
    ///
    /// `etwa` ist eine Zielzahl und keine Obergrenze: Bei einer Spanne, die ein glattes
    /// Vielfaches der Stufe ist, kommt eine Marke dazu (Spanne 0…30, `etwa: 3` → 0, 10, 20, 30).
    /// So hält es auch ECharts, und eine Achse, der die oberste Zahl fehlt, weil eine Zählung
    /// nicht aufgeht, sieht nach Fehler aus.
    public static func achsenmarken(_ spanne: ClosedRange<Double>, etwa: Int = 3)
        -> [Achsenmarke]
    {
        let unten = spanne.lowerBound
        let breite = spanne.upperBound - unten
        guard breite > 0, breite.isFinite, unten.isFinite, etwa > 0 else { return [] }
        let schritt = stufe(breite, etwa: etwa)
        guard schritt > 0 else { return [] }
        var werte: [Double] = []
        var k = 0
        while true {
            let wert = unten + Double(k) * schritt
            // Ein Hauch Spielraum, damit eine Marke genau auf der Oberkante nicht an der
            // Gleitkommadarstellung scheitert: 1,5 + 3 · 0,9 ist nicht genau 4,2.
            guard wert <= spanne.upperBound + schritt * 1e-9 else { break }
            werte.append(wert)
            k += 1
            // Eine Reißleine: eine Stufe, die aus einer kaputten Spanne fast null wird, soll
            // keine Endlosschleife ergeben.
            guard k < 64 else { break }
        }
        let stellen = stellen(werte)
        return werte.map {
            Achsenmarke(
                wert: $0, wort: Formate.zahl($0, stellen: stellen),
                anteil: Achse.anteil($0, in: spanne))
        }
    }

    /// Die runde Stufe, in der eine Spanne beschriftet wird: 1, 2, 5 oder 10 mal eine Zehnerpotenz.
    ///
    /// Dieselbe Familie, aus der auch ECharts seine Achsenabstände wählt. Aufgerundet und nicht
    /// abgerundet: eine zu kleine Stufe ergibt mehr Zahlen als Platz ist, und auf 22 Punkten
    /// Flächenhöhe stehen sie dann übereinander.
    static func stufe(_ breite: Double, etwa: Int) -> Double {
        let rau = breite / Double(max(1, etwa))
        guard rau > 0, rau.isFinite else { return 0 }
        let zehner = pow(10, log10(rau).rounded(.down))
        for faktor in [1.0, 2.0, 5.0] where zehner * faktor >= rau {
            return zehner * faktor
        }
        return zehner * 10
    }

    /// Wie viele Nachkommastellen alle Marken brauchen - höchstens zwei.
    ///
    /// **Eine Zahl für die ganze Achse und nicht je Marke.** „1,5 / 2,5 / 3,5“ ist eine Achse,
    /// „2 / 2,5 / 4“ wäre drei verschiedene Schreibweisen übereinander. Die Zahl richtet sich
    /// deshalb nach der Marke, die am meisten Stellen braucht - auch nach der Untergrenze, die
    /// nicht auf der Stufe liegen muss (``achsenmarken(_:etwa:)``: bei einer Wärmeachse ab
    /// 1,5 kW in Schritten von 1 kW sind das die Halben).
    static func stellen(_ werte: [Double]) -> Int {
        for s in 0...2 {
            let faktor = pow(10.0, Double(s))
            if werte.allSatisfy({ abs(($0 * faktor).rounded() / faktor - $0) < 1e-9 }) {
                return s
            }
        }
        return 2
    }

    // MARK: - Wie viele Kacheln in einer Reihe

    /// Zwei, vier oder sieben Kennzahlkacheln nebeneinander.
    ///
    /// Die Vorlage schaltet zweimal um (`waerme/Fahrplan.tsx:548`:
    /// `grid-cols-2 md:grid-cols-4 xl:grid-cols-7`) - zwei Spalten bis 768 px, vier bis
    /// 1280 px, sieben darüber. `handy.css:197` baut daraus unter 720 px die eine Fläche mit
    /// zwei Spalten.
    ///
    /// **Gemessen wird die Breite des Kachelfelds, nicht die des Fensters.** Eine
    /// Medienabfrage der Vorlage kennt das Fenster; eine SwiftUI-Ansicht kennt den Platz, den
    /// sie bekommt. Dazwischen liegen die beiden Ränder der Seite von je 16 Punkten
    /// (`App/Seitenwahl.swift`, `padding(.horizontal, 16)`), und die Schwellen stehen deshalb
    /// um diese 32 Punkte tiefer. Ist links noch eine Leiste, fällt die Antwort eine Stufe
    /// vorsichtiger aus - und eine Stufe zu wenig ist hier der harmlose Fehler.
    ///
    /// Eine Breite von null gibt es im ersten Zeichendurchgang, bevor gemessen wurde: dann
    /// gelten die zwei Spalten, mit denen die Vorlage ohne Medienabfrage anfängt.
    public static func spalten(breite: Double) -> Int {
        guard breite.isFinite, breite > 0 else { return 2 }
        if breite >= 1280 - 32 { return 7 }
        if breite >= 768 - 32 { return 4 }
        return 2
    }

    // MARK: - Die Zellen einer Entscheidungszeile

    /// Eine Zeile der Entscheidungstabelle, fertig in Wörtern.
    ///
    /// **Warum die Wörter im Kern stehen und nicht in der Ansicht.** Die Zeile wird zweimal
    /// gezeichnet: am iPad als Tabellenzeile aus sieben Zellen (`waerme/Fahrplan.tsx:711-723`)
    /// und am Telefon als Block aus vier Spalten und drei Zeilen (`handy.css:319-329`). Beide
    /// Fassungen müssen dieselben Wörter zeigen; stünde die Formatierung in der Ansicht, stünde
    /// sie zweimal da - und zwei Beschreibungen derselben Sache sind eine zu viel.
    public struct Entscheidungszeile: Sendable, Hashable, Identifiable {
        /// „heute 03:15“ - die Uhrzeit allein steht im Horizont zweimal.
        public let zeit: String
        /// „18,4 ct“ **ohne Nenner** (`Fahrplan.tsx:713`); „ct/kWh“ trägt der Flächentitel.
        public let preis: String
        public let bedarf: String
        public let puffer: String
        /// `.puffer`, wo eine Zahl dasteht, sonst `.neutral`: die Vorlage färbt die Zelle nur
        /// dann (`Fahrplan.tsx:715`: `color: i.buffer_kwh == null ? undefined : C.puffer`).
        public let pufferrolle: Fahrplanbild.Rolle
        public let zustand: String
        public let zustandsrolle: Fahrplanbild.Rolle
        public let ofen: String
        /// Dasselbe Wort mit dem Wort „Ofen“ davor - am Telefon fehlt die Kopfzeile, und
        /// „brennt“ allein in der rechten Ecke sagt nicht, was brennt
        /// (`handy.css:328`: `td:nth-child(6)::before { content: "Ofen " }`).
        public let ofenMitWort: String
        public let ofenrolle: Fahrplanbild.Rolle
        public let warum: String

        public var id: String { zeit }

        public init(
            zeit: String, preis: String, bedarf: String, puffer: String,
            pufferrolle: Fahrplanbild.Rolle, zustand: String,
            zustandsrolle: Fahrplanbild.Rolle, ofen: String, ofenMitWort: String,
            ofenrolle: Fahrplanbild.Rolle, warum: String
        ) {
            self.zeit = zeit
            self.preis = preis
            self.bedarf = bedarf
            self.puffer = puffer
            self.pufferrolle = pufferrolle
            self.zustand = zustand
            self.zustandsrolle = zustandsrolle
            self.ofen = ofen
            self.ofenMitWort = ofenMitWort
            self.ofenrolle = ofenrolle
            self.warum = warum
        }
    }

    /// Die Spaltennamen der Tabelle, in der Reihenfolge der Vorlage (`Fahrplan.tsx:697-703`).
    ///
    /// **„Zeit“ steht dabei.** Die Vorlage beschriftet die erste Spalte wie die anderen sechs;
    /// eine Kopfzeile, die mit einer leeren Zelle anfängt, lässt offen, was dort steht.
    public static let spaltennamen = [
        "Zeit", "Preis", "Bedarf", "Puffer", "Wärmepumpe", "Ofen", "Warum",
    ]

    /// Die Entscheidungen als fertige Zeilen.
    public static func zeilen(_ entscheidungen: [Planauswahl.Entscheidung], jetzt: Date)
        -> [Entscheidungszeile]
    {
        entscheidungen.map { e in
            Entscheidungszeile(
                zeit: Formate.tagUndUhr(e.zeit, jetzt: jetzt),
                preis: Formate.ctKurz(e.preis),
                bedarf: Formate.kwMitEinheit(e.bedarf),
                puffer: Formate.kwh(e.puffer),
                pufferrolle: e.puffer == nil ? .neutral : .puffer,
                zustand: e.zustandswort,
                zustandsrolle: e.zustandsrolle,
                ofen: e.ofenwort,
                ofenMitWort: "Ofen " + e.ofenwort,
                ofenrolle: e.ofenrolle,
                warum: e.warum
            )
        }
    }
}
