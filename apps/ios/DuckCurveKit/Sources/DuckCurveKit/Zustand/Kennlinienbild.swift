import Foundation

/// Die Rechnungen der gemessenen Kennlinie: Kopfsatz, Kacheln, drei Bilder, Vergleich, Bilanz.
///
/// Übersetzung von `apps/web/src/components/waermepumpe/kennlinie.ts` und
/// `apps/web/src/components/waermepumpe/bilanz.ts`. Hier steht jede Schwelle, jede Rundung,
/// jede Textauswahl und jede Farbzuordnung dieser Seite - die Ansichten setzen nur zusammen.
///
/// **Warum drei Bilder und nicht eines** (`kennlinie.ts:7-21`, wörtlich übernommen). Die
/// Arbeitszahl hängt an zwei Temperaturen, und ein Diagramm hat zwei Achsen. Eine
/// dreidimensionale Fläche sieht nach viel aus und lässt sich nicht ablesen: welcher Punkt
/// vorn liegt und welcher hinten, entscheidet der Blickwinkel. Stattdessen die Arbeitszahl
/// über der Außentemperatur, dieselbe über der Vorlauftemperatur - „solange das Wetter sich
/// nicht ändert, ist das die Ansicht, in der überhaupt etwas zu sehen ist: eine Pufferladung
/// durchläuft zwanzig Grad Vorlauf an einem Vormittag“ - und das Kennfeld, die Fläche von oben.
///
/// **Die Punktfarbe ist die des Wassers und nicht die der Wärme** (`kennlinie.ts:22-23`): „ein
/// Punkt bei 35 Grad hat die Farbe von 35 Grad warmem Wasser im Speicher.“ Dieselbe Skala
/// steht im Anlagenschema und im Puffer (``Marken/wasserfarbe(_:)``, Stützstellen
/// 10/25/35/45/55/65 °C). Die App hat hier bis zum 20.11.2026 zwischen ``Marken/waerme``
/// gemischt, mit Stützstellen 28/34/40/46/55 - dieselbe Vorlauftemperatur hatte damit in App
/// und Browser verschiedene Farben.
public enum Kennlinienbild {

    // MARK: - Die Sätze, die immer gleich lauten

    /// Solange nichts da ist (`Kennlinie.tsx:96`).
    public static let ladesatz = "Die Kennlinie wird geladen …"

    /// Wenn noch nichts da ist und die Abfrage scheitert (`Kennlinie.tsx:83`).
    public static let fehlersatz = "Die Kennlinie ist gerade nicht zu erreichen."

    /// Ohne einen einzigen Messpunkt (`Kennlinie.tsx:108`).
    public static let keinPunktSatz = "Noch gibt es keine Messpunkte."

    /// Der Kicker der Formelkarte (`Kennlinie.tsx:159`).
    public static let formelkicker = "Ausgleich nach kleinsten Quadraten"

    /// Die Titel der vier Karten (`Kennlinie.tsx:35`, `:170`, `:181`, `:187`, `:200`).
    public static let bilanztitel = "Wo die Minuten geblieben sind"
    public static let aussentitel = "Arbeitszahl über der Außentemperatur"
    public static let vorlauftitel = "Arbeitszahl über der Vorlauftemperatur"
    public static let hubtitel = "Arbeitszahl über dem Hub"
    public static let kennfeldtitel = "Kennfeld: beide Temperaturen zugleich"
    public static let vergleichstitel = "Messung gegen die Annahme des Fahrplans"

    /// Die Namen der Reihen, wie die Legende sie führt (`kennlinie.ts:150`).
    ///
    /// **Nicht „gemessen“ und „angenommen“.** So hieß es in der App; die Vorlage schreibt
    /// „Messpunkt“ und „Annahme des Fahrplans“, und das zweite Wort sagt, *wessen* Annahme es
    /// ist - sie gehört dem Fahrplan und nicht der Messung.
    public static let messpunktwort = "Messpunkt"
    public static let annahmewort = "Annahme des Fahrplans"

    /// Die Namen der Achsen (`kennlinie.ts:152-153`, `:205-206`).
    public static let aussenachse = "Außentemperatur °C"
    public static let vorlaufachse = "Vorlauftemperatur °C"
    public static let hubachse = "Hub: Vorlauf minus draußen, K"
    public static let copachse = "COP"
    /// Die senkrechte Achse des Kennfelds (`kennlinie.ts:272`).
    public static let kennfeldVorlaufachse = "Vorlauf °C"

    /// Der Erklärsatz unter dem Kennfeld (`Kennlinie.tsx:191`), wörtlich.
    public static let kennfeldsatz =
        "Die Farbe ist die Arbeitszahl nach dem Ausgleich. Ein Kreis steht, wo gemessen wurde; "
        + "je größer, desto mehr Punkte."

    /// Was statt des Kennfelds steht, solange sich die Ebene nicht bestimmen lässt
    /// (`Kennlinie.tsx:194`), wörtlich.
    ///
    /// **Der Satz nennt die Bedingung und nicht den Mangel.** „Zu wenige Daten“ wäre dasselbe
    /// in weniger Worten und hülfe niemandem; so steht da, woran man erkennt, wann das Bild
    /// kommt.
    public static let kennfeldLeersatz =
        "Das Kennfeld entsteht, sobald sich der Einfluss beider Temperaturen bestimmen lässt: "
        + "wenn die Messpunkte draußen mindestens vier und im Vorlauf mindestens fünf Grad "
        + "auseinanderliegen, und nicht im Gleichschritt."

    /// Der Schlusssatz der Vergleichskarte (`Kennlinie.tsx:221`), wörtlich.
    public static let vergleichsschluss =
        "„Verlängert“ heißt: bei dieser Temperatur wurde noch nicht gemessen, die Zahl folgt "
        + "aus der Formel. Der Fahrplan rechnet weiter mit seiner Annahme; übernommen wird "
        + "nichts von selbst."

    /// Der Satz hinter der Liste der fehlenden Werte (`Kennlinie.tsx:60`), wörtlich.
    public static let busschluss =
        "Kommt ein Wert dauerhaft nicht, liegt es an der Zuordnung auf dem Bus und nicht an "
        + "der Wärmepumpe."

    // MARK: - Die Rechnungen des Ausgleichs

    /// Die Arbeitszahl nach der Ausgleichsfläche (`kennlinie.ts:30`).
    public static func copNach(_ f: KennlinienFitOut, aussen: Double, vorlauf: Double) -> Double {
        f.a + f.bAussen * aussen + f.cVorlauf * vorlauf
    }

    /// Die Arbeitszahl aller Punkte zusammen (`kennlinie.ts:32-38`).
    ///
    /// **Summe der Wärme durch Summe des Stroms, nicht das Mittel der einzelnen
    /// Arbeitszahlen.** Der Kommentar der Vorlage nennt den Grund in einem Satz: „Ein Fenster
    /// mit 4 kW zählt mehr als eines mit 1 kW.“ Das Mittel der Einzelwerte gäbe einem
    /// Zehn-Minuten-Fenster bei halber Last dasselbe Gewicht wie einem bei voller - und genau
    /// die kleinen Fenster haben die unsichersten Zahlen.
    ///
    /// `nil`, wenn kein Strom gezählt wurde: eine Arbeitszahl ohne Strom im Nenner ist keine.
    public static func gesamt(_ punkte: [KennlinienPunktOut]) -> Double? {
        let strom = punkte.reduce(0.0) { $0 + $1.stromKw * Double($1.minuten) }
        guard strom.isFinite, strom > 0 else { return nil }
        let waerme = punkte.reduce(0.0) { $0 + $1.waermeKw * Double($1.minuten) }
        guard waerme.isFinite else { return nil }
        return waerme / strom
    }

    /// Der Median einer Reihe; bei gerader Anzahl das Mittel der beiden mittleren
    /// (`kennlinie.ts:40-45`).
    public static func mitte(_ werte: [Double]) -> Double? {
        let brauchbar = werte.filter { $0.isFinite }
        guard !brauchbar.isEmpty else { return nil }
        let s = brauchbar.sorted()
        let m = s.count / 2
        return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
    }

    /// Die Vorläufe, für die eine Ausgleichsgerade gezeichnet wird (`kennlinie.ts:49-55`).
    ///
    /// **Runde Fünfer innerhalb der Messung, höchstens drei: erste, mittlere, letzte.** Ohne
    /// Vorlaufterm gibt es keine Stufen - eine Gerade je Stufe wäre dann fünfmal dieselbe
    /// Gerade. Die App zeichnete bis zum 20.11.2026 genau eine, mit dem Vorlauf in der Mitte
    /// des Geltungsbereichs; der Fächer ist aber die Aussage des Bildes: er zeigt, wie viel
    /// Arbeitszahl fünf Grad weniger Vorlauf wert sind.
    public static func vorlaufStufen(_ f: KennlinienFitOut) -> [Double] {
        guard f.art == .ebene, f.vorlaufVonC.isFinite, f.vorlaufBisC.isFinite else { return [] }
        var stufen: [Double] = []
        var t = (f.vorlaufVonC / 5).rounded(.up) * 5
        // Die Schranke ist eine Notbremse gegen eine unsinnige Spanne aus dem Dienst und keine
        // Regel der Vorlage: bei 5-Grad-Schritten sind mehr als 64 Stufen 320 Grad Vorlauf.
        while t <= f.vorlaufBisC, stufen.count < 64 {
            stufen.append(t)
            t += 5
        }
        guard stufen.count > 3 else { return stufen }
        return [stufen[0], stufen[(stufen.count - 1) / 2], stufen[stufen.count - 1]]
    }

    /// Der Bereich der Arbeitszahl-Achse (`kennlinie.ts:115-119`).
    ///
    /// **Geklemmt und nicht dem Diagramm überlassen.** Punkte und Annahme reichten sonst
    /// unterschiedlich weit, und zwei Bilder derselben Größe mit zwei Achsen lassen sich nicht
    /// vergleichen. Ohne Werte der Bereich der Vorlage: 1 bis 6.
    public static func copAchse(
        punkte: [KennlinienPunktOut], annahme: [KennlinienAnnahmeOut]
    ) -> ClosedRange<Double> {
        var werte = punkte.map(\.cop)
        werte.append(contentsOf: annahme.map(\.cop))
        let brauchbar = werte.filter { $0.isFinite }
        guard let kleinste = brauchbar.min(), let groesste = brauchbar.max() else {
            return 1...6
        }
        let unten = Swift.max(0, (kleinste - 0.25).rounded(.down))
        let oben = (groesste + 0.25).rounded(.up)
        return unten...Swift.max(unten, oben)
    }

    // MARK: - Der Kopf der Seite

    /// Die Hauptaussage in einem Satz, in drei Fassungen (`Kennlinie.tsx:108-113`).
    ///
    /// **Die Temperaturen sind die Mediane der Punkte und nicht die Mitte des
    /// Geltungsbereichs** (`:101-102`). Der Satz behauptet damit etwas über den Betrieb, wie er
    /// war, und nicht über die Mitte einer Spanne, in der vielleicht nie gemessen wurde.
    public static func kopfsatz(_ k: KennlinieOut) -> String {
        let ta = mitte(k.punkte.map(\.aussenC))
        let tv = mitte(k.punkte.map(\.vorlaufC))
        if let f = k.fit, let ta, let tv {
            let cop = Formate.zahl(copNach(f, aussen: ta, vorlauf: tv), stellen: 1)
            return "Nach \(f.n) Messpunkten macht die Wärmepumpe bei \(Formate.celsius(ta)) "
                + "draußen und \(Formate.celsius(tv)) Vorlauf aus einer Kilowattstunde Strom "
                + "\(cop) Kilowattstunden Wärme."
        }
        if !k.punkte.isEmpty, let mittel = gesamt(k.punkte) {
            let wort = k.punkte.count == 1 ? "Messpunkt" : "Messpunkte"
            return "\(k.punkte.count) \(wort) bisher, Arbeitszahl im Mittel "
                + "\(Formate.zahl(mittel, stellen: 1))."
        }
        return keinPunktSatz
    }

    /// Die Standzeile unter dem Kopfsatz: „Letzte 30 Tage“, bei stehendem Fehler mit Anhang
    /// (`Kennlinie.tsx:119-121`).
    public static func standzeile(_ k: KennlinieOut, fehler: String? = nil) -> String {
        let grund = "Letzte \(k.tage) Tage"
        guard let fehler, !fehler.isEmpty else { return grund }
        return grund + " · " + fehler
    }

    /// Die Rückblicke, die die Seite anbietet (`Kennlinie.tsx:22`).
    ///
    /// **180 Tage gehören dazu und fehlten in der App.** Eine Kennlinie über 90 Tage kennt im
    /// November keinen warmen Tag; erst ein halbes Jahr deckt beide Enden der Außentemperatur
    /// ab, und genau daran hängt, ob sich der Term für draußen überhaupt bestimmen lässt.
    public static let rueckblicke = [7, 30, 90, 180]

    // MARK: - Die vier Kennzahlkacheln

    /// Die vier Kacheln der Vorlage, in ihrer Reihenfolge (`Kennlinie.tsx:138-153`).
    ///
    /// **Die erste führt in Bernstein**, solange es Punkte gibt (`tone="amber"`, `:139`): die
    /// Zahl der Messpunkte ist die Zahl, an der sich entscheidet, ob der Rest der Seite etwas
    /// bedeutet.
    ///
    /// **Die beiden Steigungen stehen nur da, wo der Ausgleich sie kennt** (`:145`, `:151`).
    /// Eine Steigung aus einem Ausgleich ohne diesen Term wäre eine Null mit zwei
    /// Nachkommastellen - also eine Aussage, die die Messung nicht hergibt.
    public static func kacheln(_ k: KennlinieOut) -> [Kennzahl] {
        [punktekachel(k), mittelkachel(k), aussenkachel(k), vorlaufkachel(k)]
    }

    private static func punktekachel(_ k: KennlinieOut) -> Kennzahl {
        let n = k.punkte.count
        return Kennzahl(
            wort: "Messpunkte", wert: String(n), dazu: "je zehn Minuten Heizbetrieb",
            ton: n > 0 ? .bernstein : .gedaempft)
    }

    private static func mittelkachel(_ k: KennlinieOut) -> Kennzahl {
        let mittel = gesamt(k.punkte)
        return Kennzahl(
            wort: "Arbeitszahl im Mittel",
            wert: mittel.map { Formate.zahl($0, stellen: 1) } ?? "?",
            dazu: "Wärme durch Strom, alle Punkte",
            ton: mittel == nil ? .gedaempft : .normal)
    }

    private static func aussenkachel(_ k: KennlinieOut) -> Kennzahl {
        let f = k.fit
        let gilt = f.map { $0.art == .ebene || $0.art == .aussen } ?? false
        return steigungskachel(
            wort: "Je Grad wärmer draußen", gilt: gilt, wert: f.map { steigung($0.bAussen) })
    }

    private static func vorlaufkachel(_ k: KennlinieOut) -> Kennzahl {
        let f = k.fit
        let gilt = f.map { $0.art == .ebene || $0.art == .vorlauf } ?? false
        return steigungskachel(
            wort: "Je Grad mehr Vorlauf", gilt: gilt, wert: f.map { steigung($0.cVorlauf) })
    }

    /// Eine Steigungskachel: Wert und Ton hängen an derselben Bedingung.
    ///
    /// **Warum zusammen und nicht zweimal verzweigt.** Die Vorlage setzt an beiden Kacheln
    /// dieselbe Bedingung zweimal - einmal für den Wert, einmal für den Ton
    /// (`Kennlinie.tsx:143-146`, `:149-152`). Auseinandergeschrieben wären das vier Stellen,
    /// an denen eine Hälfte vergessen werden kann: ein Fragezeichen in Textfarbe sieht aus wie
    /// ein Messwert, eine gedämpfte Zahl wie ein alter.
    private static func steigungskachel(wort: String, gilt: Bool, wert: String?) -> Kennzahl {
        guard gilt, let wert else {
            return Kennzahl(
                wort: wort, wert: "?", dazu: "Arbeitszahl, nach Ausgleich", ton: .gedaempft)
        }
        return Kennzahl(wort: wort, wert: wert, dazu: "Arbeitszahl, nach Ausgleich")
    }

    /// Eine Steigung mit Vorzeichen, zwei Stellen (`Kennlinie.tsx:143`, `:149`).
    ///
    /// **Das Minus ist U+2212 und nicht der Bindestrich**, wie die Vorlage es setzt und wie
    /// ``Formate/minus`` es für alle Zahlen dieser App festlegt. Das Pluszeichen steht
    /// ausdrücklich dabei: die Zahl ist eine Änderung je Grad, und eine Änderung ohne Richtung
    /// sagt nichts.
    public static func steigung(_ wert: Double) -> String {
        guard wert.isFinite else { return "?" }
        let vorzeichen = wert >= 0 ? "+" : Formate.minus
        return vorzeichen + Formate.zahl(abs(wert), stellen: 2)
    }

    // MARK: - Die Formelkarte

    /// Die Satzzeile unter der Formel (`Kennlinie.tsx:161-164`).
    ///
    /// **r² steht in Prozent und rmse mit ±-Zeichen.** Die App zeigte beide als nackte Zahl
    /// („0,842“, „0,123“); die Vorlage schreibt „erklärt 84 % der Streuung“ und „mittlere
    /// Abweichung ±0,12“. Das erste ist ein Anteil und liest sich nur als Prozent, das zweite
    /// eine Spanne nach beiden Seiten - ohne das Zeichen sieht es wie ein Messwert aus.
    public static func formelzeile(_ f: KennlinienFitOut) -> String {
        var text = "\(f.n) Punkte · mittlere Abweichung ±\(Formate.zahl(f.rmse, stellen: 2))"
        if let r2 = f.r2, r2.isFinite {
            text += " · erklärt \(Formate.prozent(r2)) der Streuung"
        }
        return text + ". " + f.geltungDe
    }

    // MARK: - Das Streubild über der Außentemperatur

    /// Der Name einer Ausgleichsgeraden: ihr Vorlauf (`kennlinie.ts:133`).
    public static func stufenname(_ vorlauf: Double) -> String {
        "\(Formate.zahl(vorlauf, stellen: 0)) °C Vorlauf"
    }

    /// Der Name der einen Geraden ohne Vorlaufterm (`kennlinie.ts:130`).
    public static let ausgleichswort = "Ausgleich"

    /// Der Name der Geraden im zweiten Bild: sie gilt bei mittlerer Außentemperatur
    /// (`kennlinie.ts:186`).
    public static func vorlaufgeradenname(_ k: KennlinieOut) -> String {
        guard let ta = mitte(k.punkte.map(\.aussenC)) else { return ausgleichswort }
        return "Ausgleich bei \(Formate.celsius(ta)) draußen"
    }

    /// Die zwei Enden einer Ausgleichsgeraden über der Außentemperatur (`kennlinie.ts:136`).
    ///
    /// **Zwei Punkte und nicht vierundzwanzig.** Die App zog 24 Schritte über denselben
    /// Geltungsbereich; bei einer Geraden ist das dasselbe Bild mit 24 Marken statt 2 - und
    /// jede Marke ist in Swift Charts eine Messung, die die Auswahl mitzählt.
    public static func gerade(
        _ f: KennlinienFitOut, vorlauf: Double
    ) -> [(aussen: Double, cop: Double)] {
        [f.aussenVonC, f.aussenBisC].map {
            (aussen: $0, cop: copNach(f, aussen: $0, vorlauf: vorlauf))
        }
    }

    /// Die zwei Enden der Geraden über der Vorlauftemperatur, bei mittlerer Außentemperatur
    /// (`kennlinie.ts:197-203`).
    public static func vorlaufgerade(
        _ k: KennlinieOut
    ) -> [(vorlauf: Double, cop: Double)] {
        guard let f = k.fit, let ta = mitte(k.punkte.map(\.aussenC)) else { return [] }
        return [f.vorlaufVonC, f.vorlaufBisC].map {
            (vorlauf: $0, cop: copNach(f, aussen: ta, vorlauf: $0))
        }
    }

    // MARK: - Das Streubild über dem Hub

    /// Was der Hub ist, als Satz über dem Bild (`Kennlinie.tsx`, Karte „Arbeitszahl über dem
    /// Hub“).
    public static let hubsatz =
        "Der Hub ist der Unterschied zwischen Vorlauf und Außenluft, über den die Wärmepumpe "
        + "die Wärme pumpt. Je kleiner er ist, desto weniger Strom kostet eine Kilowattstunde "
        + "Wärme."

    /// Der Hub eines Punkts: Vorlauf minus draußen, in Kelvin (`kennlinie.ts`, `hubVon`).
    public static func hub(_ p: KennlinienPunktOut) -> Double {
        p.vorlaufC - p.aussenC
    }

    /// Die Arbeitszahl nach der Geraden über dem Hub (`kennlinie.ts`, `copNachHub`).
    public static func copNachHub(_ h: KennlinienHubOut, hub: Double) -> Double {
        h.a + h.bHub * hub
    }

    /// Die zwei Enden der Geraden über dem Hub, nur wo gemessen wurde (`kennlinie.ts`,
    /// `optionHub`).
    public static func hubgerade(_ k: KennlinieOut) -> [(hub: Double, cop: Double)] {
        guard let h = k.hub else { return [] }
        return [h.hubVonK, h.hubBisK].map { (hub: $0, cop: copNachHub(h, hub: $0)) }
    }

    /// Die Satzzeile unter der Formel des Hubs, wie ``formelzeile(_:)``.
    public static func hubzeile(_ h: KennlinienHubOut) -> String {
        var text = "\(h.n) Punkte · mittlere Abweichung ±\(Formate.zahl(h.rmse, stellen: 2))"
        if let r2 = h.r2, r2.isFinite {
            text += " · erklärt \(Formate.prozent(r2)) der Streuung"
        }
        return text + ". " + h.geltungDe
    }

    /// Der Hinweis an der Annahmelinie: bei welchem Vorlauf sie gilt (`kennlinie.ts:164`).
    public static func annahmehinweis(_ k: KennlinieOut) -> String {
        guard let tv = k.annahmeVorlaufC, tv.isFinite else { return annahmewort }
        return annahmewort + ", bei \(Formate.celsius(tv)) Vorlauf"
    }

    // MARK: - Das Farbband des Vorlaufs

    /// Von wo bis wo der **gemessene** Vorlauf reicht (`Kennlinie.tsx:105-106`).
    ///
    /// Nicht der Geltungsbereich des Ausgleichs: das Band erklärt die Farbe der Punkte, und
    /// Punkte gibt es nur dort, wo gemessen wurde.
    public static func vorlaufspanne(_ punkte: [KennlinienPunktOut]) -> ClosedRange<Double>? {
        let werte = punkte.map(\.vorlaufC).filter { $0.isFinite }
        guard let von = werte.min(), let bis = werte.max() else { return nil }
        return von...Swift.max(von, bis)
    }

    /// Die fünf Stützen des Verlaufsbands (`Kennlinie.tsx:175`).
    ///
    /// Fünf und nicht zwei: zwischen 30 und 55 Grad liegen drei Stützstellen der Wasserskala,
    /// und ein Verlauf aus nur den beiden Enden ließe sie aus - das Band zeigte dann Farben,
    /// die kein Punkt hat.
    public static func bandfarben(_ spanne: ClosedRange<Double>) -> [Farbwert] {
        [0, 0.25, 0.5, 0.75, 1].map { anteil in
            Marken.wasserfarbe(spanne.lowerBound + (spanne.upperBound - spanne.lowerBound) * anteil)
        }
    }

    /// Was das Band für die Bedienungshilfen sagt (`Kennlinie.tsx:174`).
    public static func bandbeschriftung(_ spanne: ClosedRange<Double>) -> String {
        "Farbe der Punkte: Vorlauf von \(Formate.zahl(spanne.lowerBound, stellen: 0)) bis "
            + "\(Formate.zahl(spanne.upperBound, stellen: 0)) Grad"
    }

    // MARK: - Der Punkt unter dem Finger

    /// Eine Zeile des Punkthinweises: Wort und Wert.
    public struct Punktzeile: Sendable, Hashable, Identifiable {
        public let wort: String
        public let wert: String

        public var id: String { wort }

        public init(wort: String, wert: String) {
            self.wort = wort
            self.wert = wert
        }
    }

    /// Die sechs Zeilen zu einem Messpunkt (`kennlinie.ts`, `punktZeile`).
    ///
    /// **Dieselben Zahlen und Stellen wie in der Tabelle.** Der Punkt im Bild und die Zeile in
    /// der aufklappbaren Tabelle sind derselbe Messwert; stünde die Arbeitszahl einmal mit zwei
    /// und einmal mit einer Stelle, wäre nicht zu sehen, dass es derselbe ist.
    public static func punktzeilen(_ p: KennlinienPunktOut) -> [Punktzeile] {
        [
            Punktzeile(wort: "Arbeitszahl", wert: Formate.zahl(p.cop, stellen: 2)),
            Punktzeile(wort: "draußen", wert: Formate.celsius(p.aussenC, stellen: 1)),
            Punktzeile(wort: "Vorlauf", wert: Formate.celsius(p.vorlaufC, stellen: 1)),
            Punktzeile(
                wort: "Hub",
                wert: Formate.zahl(hub(p), stellen: 1) + Formate.schmalesLeerzeichen + "K"),
            Punktzeile(wort: "Wärme", wert: kilowatt(p.waermeKw, stellen: 1)),
            Punktzeile(wort: "Strom", wert: kilowatt(p.stromKw, stellen: 2)),
        ]
    }

    /// „14.11, 20:00“ - der Zeitpunkt eines Messpunkts, in der Zeit des Hauses
    /// (`kennlinie.ts:109`).
    ///
    /// **Mit führenden Nullen und ohne Wochentag.** Die Form steht in einer Spalte aus bis zu
    /// zweihundert Zeilen in Festbreitenschrift; dort stehen die Ziffern nur mit Nullen
    /// untereinander. ``Formate/kurzDatum(iso:)`` schreibt „Sa., 14.11.“ mit Wochentag und ohne
    /// Uhrzeit - das ist die Form für einen einzelnen Satz, nicht für eine Spalte.
    public static func punktzeit(_ p: KennlinienPunktOut) -> String {
        guard let d = Zeit.ausIso(p.at) else { return Formate.leer }
        let t = Kalender.haus.dateComponents([.day, .month], from: d)
        return String(format: "%02d.%02d, ", t.day ?? 0, t.month ?? 0) + Formate.hhmm(d)
    }

    /// Welche Achse eines Streubilds gemeint ist.
    public enum Achsenwahl: Sendable, Hashable {
        case aussen
        case vorlauf
        case hub
    }

    /// Die Punkte der Spalte, die einer gehaltenen Stelle der Querachse am nächsten liegt.
    ///
    /// **Warum eine Spalte und nicht ein Punkt.** Die Auswahl im Diagramm liefert eine Stelle
    /// der Querachse, keine einzelne Marke - und bei einer Außentemperatur liegen in einem
    /// Streubild über dreißig Tage leicht zwanzig Punkte. Gewählt wird darum der nächste
    /// vorkommende Wert der Achse, und gezeigt werden alle Punkte, die genau auf ihm liegen:
    /// „der nächste Punkt“ allein wäre eine Antwort, die den Nachbarn verschweigt, der einen
    /// halben Grad daneben eine ganz andere Arbeitszahl hatte.
    ///
    /// Höchstens sechs, nach der Zeit sortiert: eine Spalte mit zwanzig Punkten wäre unter dem
    /// Bild eine zweite Seite.
    public static func naechsteSpalte(
        _ punkte: [KennlinienPunktOut], bei stelle: Double?, nach achse: Achsenwahl
    ) -> [KennlinienPunktOut] {
        guard let stelle, stelle.isFinite, !punkte.isEmpty else { return [] }
        func wert(_ p: KennlinienPunktOut) -> Double {
            switch achse {
            case .aussen: return p.aussenC
            case .vorlauf: return p.vorlaufC
            case .hub: return hub(p)
            }
        }
        let brauchbar = punkte.filter { wert($0).isFinite }
        guard
            let naechste = brauchbar.min(by: {
                abs(wert($0) - stelle) < abs(wert($1) - stelle)
            })
        else { return [] }
        let ziel = wert(naechste)
        return brauchbar.filter { wert($0) == ziel }.sorted { $0.at < $1.at }.prefix(6).map { $0 }
    }

    /// Eine Leistung mit Einheit, in der Form der Vorlage: „3,6 kW“, „0,85 kW“.
    ///
    /// Nicht ``Formate/kwMitEinheit(_:)``: das schneidet alles unter 0,05 kW auf null ab (mit
    /// Grund - ein Wechselrichter, der nachts 0,004 kW meldet, speist nicht ein) und schreibt
    /// immer eine Stelle. Hier ist die Zahl der Stromaufnahme eines laufenden Verdichters,
    /// zweistellig, und die Null ist kein Fall, den es gibt.
    private static func kilowatt(_ wert: Double, stellen: Int) -> String {
        Formate.zahl(wert, stellen: stellen) + Formate.schmalesLeerzeichen + "kW"
    }

    // MARK: - Die Messpunkte als Tabelle

    /// Der Griff der aufklappbaren Tabelle (`Kennlinie.tsx:258`).
    public static func tabellengriff(_ k: KennlinieOut) -> String {
        "Die Messpunkte als Tabelle (\(k.punkte.count))"
    }

    /// Die Punkte der Tabelle: **neueste zuerst, auf zweihundert gekappt**
    /// (`Kennlinie.tsx:243-245`).
    ///
    /// Zweihundert sind die Grenze der Vorlage. Neunzig Tage Heizbetrieb ergeben einige tausend
    /// Zehn-Minuten-Fenster; eine Tabelle mit tausend Zeilen ist keine Tabelle mehr, und wer
    /// die ältesten sucht, wechselt den Zeitraum.
    public static func tabellenpunkte(_ k: KennlinieOut) -> [KennlinienPunktOut] {
        Array(k.punkte.reversed().prefix(200))
    }

    /// Die Zeilennamen der Tabelle: die Zeitpunkte.
    public static func tabellenzeilen(_ k: KennlinieOut) -> [String] {
        tabellenpunkte(k).map(punktzeit)
    }

    /// Die sechs Spalten hinter der Zeit (`Kennlinie.tsx:231-238`).
    ///
    /// **`ventil` erscheint in der App zum ersten Mal.** Das Feld steht im Schema und sagt,
    /// welcher Kreis offen war - ohne es ist ein Punkt bei 45 Grad Vorlauf nicht von einem der
    /// Warmwasserladung zu unterscheiden, und gerade die liegen in der Arbeitszahl tiefer.
    public static func tabellenspalten(
        _ k: KennlinieOut
    ) -> [(name: String, zellen: [String])] {
        let p = tabellenpunkte(k)
        return [
            ("draußen", p.map { Formate.celsius($0.aussenC, stellen: 1) }),
            ("Vorlauf", p.map { Formate.celsius($0.vorlaufC, stellen: 1) }),
            ("Wärme", p.map { kilowatt($0.waermeKw, stellen: 1) }),
            ("Strom", p.map { kilowatt($0.stromKw, stellen: 2) }),
            ("Arbeitszahl", p.map { Formate.zahl($0.cop, stellen: 2) }),
            ("Ventil", p.map { $0.ventil.map(String.init) ?? "?" }),
        ]
    }

    // MARK: - Messung gegen die Annahme des Fahrplans

    /// Eine Zeile des Vergleichs (`kennlinie.ts:58-64`).
    public struct Vergleichszeile: Sendable, Hashable, Identifiable {
        public let aussenC: Double
        public let annahme: Double
        public let messung: Double
        /// Liegt die Stelle dort, wo gemessen wurde? Sonst ist die Zahl eine Verlängerung.
        public let gemessen: Bool

        public var id: Double { aussenC }

        public init(aussenC: Double, annahme: Double, messung: Double, gemessen: Bool) {
            self.aussenC = aussenC
            self.annahme = annahme
            self.messung = messung
            self.gemessen = gemessen
        }
    }

    /// Bei welchem Vorlauf der Vergleich gilt (`kennlinie.ts:66-72`).
    ///
    /// Der der Annahme, wenn der Ausgleich den Vorlauf kennt, sonst der Median des gemessenen -
    /// der Kommentar der Vorlage sagt, warum: „denn nur dort sagt er etwas“. Kennt der
    /// Ausgleich den Vorlauf nicht, ist jede Vorlaufangabe erfunden, und der Median ist die
    /// einzige, die wenigstens aus den Punkten kommt.
    public static func vergleichsVorlauf(_ k: KennlinieOut) -> Double? {
        guard let f = k.fit else { return nil }
        if f.art == .ebene || f.art == .vorlauf, let tv = k.annahmeVorlaufC, tv.isFinite {
            return tv
        }
        return mitte(k.punkte.map(\.vorlaufC))
    }

    /// Der Vergleich je Stützstelle der angenommenen Kennlinie (`kennlinie.ts:74-86`).
    public static func vergleich(_ k: KennlinieOut) -> [Vergleichszeile] {
        guard let f = k.fit, let tv = vergleichsVorlauf(k) else { return [] }
        let vorlaufGemessen = tv >= f.vorlaufVonC && tv <= f.vorlaufBisC
        return k.annahme.map { a in
            Vergleichszeile(
                aussenC: a.aussenC, annahme: a.cop,
                messung: copNach(f, aussen: a.aussenC, vorlauf: tv),
                gemessen: vorlaufGemessen && a.aussenC >= f.aussenVonC
                    && a.aussenC <= f.aussenBisC)
        }
    }

    /// Der Kopf der Annahmespalte, mit dem Vorlauf der Annahme (`Kennlinie.tsx:206`).
    public static func annahmespalte(_ k: KennlinieOut) -> String {
        guard let tv = k.annahmeVorlaufC, tv.isFinite else { return "Annahme" }
        return "Annahme (\(Formate.celsius(tv)) Vorlauf)"
    }

    /// Der Kopf der Messungsspalte (`Kennlinie.tsx:207`).
    public static func messungsspalte(_ vorlauf: Double) -> String {
        "Messung (\(Formate.celsius(vorlauf)) Vorlauf)"
    }

    /// Das Wort in der Spalte „Stand“ (`Kennlinie.tsx:216`).
    public static func standwort(_ z: Vergleichszeile) -> String {
        z.gemessen ? "gemessen" : "verlängert"
    }

    // MARK: - Wo die Minuten geblieben sind

    /// Eine der fünf Arten, auf die eine Minute im Heizbetrieb endet (`bilanz.ts:11`).
    public enum Bilanzart: String, Sendable, Hashable, CaseIterable {
        case gueltig
        case anlauf
        case zusatz
        case ohneWaerme
        case ohneWert
    }

    /// Ein Teil des Bilanzbalkens (`bilanz.ts:13`).
    public struct Bilanzteil: Sendable, Hashable, Identifiable {
        public let art: Bilanzart
        public let name: String
        public let minuten: Int
        /// Anteil an den Minuten, die die fünf Arten zusammen ergeben - 0 bis 1.
        public let anteil: Double
        /// Warum diese Minuten so geendet sind, in einem halben Satz.
        public let wozu: String

        public var id: String { art.rawValue }

        public init(art: Bilanzart, name: String, minuten: Int, anteil: Double, wozu: String) {
            self.art = art
            self.name = name
            self.minuten = minuten
            self.anteil = anteil
            self.wozu = wozu
        }
    }

    /// Die feste Folge der fünf Arten, mit Namen und Begründung (`bilanz.ts:15-22`), wörtlich.
    ///
    /// **Die Reihenfolge ist eine Farbentscheidung und keine Rangfolge.** Der Kommentar der
    /// Vorlage begründet die letzte Stelle: „Zuletzt, und nicht neben dem Heizstab: die beiden
    /// warmen Töne lägen sonst aneinander.“ Der Heizstab ist Terrakotta, der fehlende Wert
    /// rot - stehen sie nebeneinander, sieht der Balken an dieser Stelle aus wie ein Teil.
    private static let folge: [(art: Bilanzart, name: String, wozu: String)] = [
        (.gueltig, "brauchbar", "eingeschwungen, alle Werte da"),
        (.anlauf, "Anlauf", "die ersten zehn Minuten nach jedem Start"),
        (.zusatz, "Heizstab", "neben dem Verdichter nahm etwas anderes Strom auf"),
        (.ohneWaerme, "keine Wärme", "kaum Durchfluss oder keine Spreizung"),
        (.ohneWert, "Wert fehlte", "ein nötiger Wert kam länger nicht vom Bus"),
    ]

    /// Die Minuten einer Art aus der Antwort des Dienstes.
    private static func minuten(_ b: KennlinienBilanzOut, _ art: Bilanzart) -> Int {
        switch art {
        case .gueltig: return b.gueltig
        case .anlauf: return b.anlauf
        case .zusatz: return b.zusatz
        case .ohneWaerme: return b.ohneWaerme
        case .ohneWert: return b.ohneWert
        }
    }

    /// Die Teile des Balkens (`bilanz.ts:24-28`).
    ///
    /// **Ein Teil mit null Minuten steht nicht im Balken** (`bilanz.ts:27`): er wäre vier
    /// Punkte breit (`min-width: 4px`) und behauptete damit eine Minute, die es nicht gab.
    /// Ohne Minuten überhaupt gibt es keinen Balken, sondern den Satz des Dienstes.
    public static func bilanzteile(_ b: KennlinienBilanzOut) -> [Bilanzteil] {
        let summe = folge.reduce(0) { $0 + minuten(b, $1.art) }
        guard summe > 0 else { return [] }
        return folge.compactMap { f in
            let m = minuten(b, f.art)
            guard m > 0 else { return nil }
            return Bilanzteil(
                art: f.art, name: f.name, minuten: m, anteil: Double(m) / Double(summe),
                wozu: f.wozu)
        }
    }

    /// Die Farbe einer Art (`globals.css:916-920`).
    ///
    /// **Vier der fünf sind vorhandene Marken.** Der Anlauf ist der Sonderfall: die Vorlage
    /// setzt `color-mix(in oklab, var(--text-3) 70%, transparent)`, also ``Marken/text3`` mit
    /// siebzig Prozent seiner Deckung. Das ist kein Grauwert aus der Liste, sondern ein Ton
    /// *unter* dem leisesten Text - er soll als Untergrund und nicht als Aussage gelesen
    /// werden, so wie ``Marken/spur`` es für die Tagesuhr tut.
    public static func bilanzfarbe(_ art: Bilanzart) -> Farbwert {
        switch art {
        case .gueltig: return Marken.amber
        case .anlauf: return Marken.text3.mitDeckung(Marken.text3.deckung * 0.7)
        case .zusatz: return Marken.waermepumpe
        case .ohneWaerme: return Marken.linie2
        case .ohneWert: return Marken.alarm
        }
    }

    /// Der Anteil eines Teils in ganzen Prozent (`Kennlinie.tsx:49`).
    public static func bilanzanteil(_ t: Bilanzteil) -> String {
        Formate.prozent(t.anteil)
    }

    /// Was der Balken für die Bedienungshilfen sagt (`Kennlinie.tsx:38`).
    public static func bilanzbeschriftung(_ b: KennlinienBilanzOut) -> String {
        let teile = bilanzteile(b).map { "\($0.name) \(Formate.dauer(minuten: $0.minuten))" }
        return "Von \(Formate.dauer(minuten: b.heizen)) im Heizbetrieb: "
            + teile.joined(separator: ", ")
    }

    /// Ein fehlender Wert mit seinen Minuten.
    public struct Fehlwert: Sendable, Hashable, Identifiable {
        public let name: String
        public let minuten: Int

        public var id: String { name }

        public init(name: String, minuten: Int) {
            self.name = name
            self.minuten = minuten
        }
    }

    /// Welche Werte fehlten, der häufigste zuerst (`bilanz.ts:39-44`).
    ///
    /// Bei gleicher Dauer nach dem Namen, damit die Liste sich zwischen zwei Abfragen nicht
    /// umsortiert - die Reihenfolge eines Wörterbuchs ist in Swift wie in JavaScript keine
    /// Zusicherung.
    public static func fehlend(_ b: KennlinienBilanzOut) -> [Fehlwert] {
        b.fehlt
            .map { Fehlwert(name: $0.key, minuten: $0.value) }
            .filter { $0.minuten > 0 }
            .sorted { a, b in
                a.minuten != b.minuten ? a.minuten > b.minuten : a.name < b.name
            }
    }

    /// Der Satz über die fehlenden Werte (`Kennlinie.tsx:60`), wörtlich.
    public static func fehlendsatz(_ b: KennlinienBilanzOut) -> String? {
        let werte = fehlend(b)
        guard !werte.isEmpty else { return nil }
        let liste = werte.map { "\($0.name) (\(Formate.dauer(minuten: $0.minuten)))" }
        return "Gefehlt hat: " + liste.joined(separator: ", ") + ". " + busschluss
    }

    /// Fenster, die begonnen, aber nicht voll genug wurden (`bilanz.ts:47-49`).
    public static func halbeFenster(_ b: KennlinienBilanzOut) -> Int {
        Swift.max(0, b.fenster - b.punkte - b.unglaubwuerdig)
    }

    /// Was aus den brauchbaren Minuten geworden ist (`Kennlinie.tsx:63-68`), wörtlich.
    ///
    /// Steht nur da, wo der Balken steht: ohne Teile gibt es keine brauchbaren Minuten, über
    /// die der Satz etwas sagen könnte.
    public static func punktesatz(_ b: KennlinienBilanzOut) -> String? {
        guard !bilanzteile(b).isEmpty else { return nil }
        let was = b.punkte == 1 ? "wurde 1 Messpunkt" : "wurden \(b.punkte) Messpunkte"
        let halb = halbeFenster(b)
        let anhang = halb > 0 ? "; \(halb) angefangene Fenster hatten zu wenige davon" : ""
        return "Aus den brauchbaren Minuten " + was + anhang + "."
    }

    // MARK: - Das Kennfeld

    /// Wie viele Messpunkte in einem Feld des Rasters liegen.
    public struct Belegungsfeld: Sendable, Hashable, Identifiable {
        /// Die Stelle in ``Kennfeld/aussen``.
        public let i: Int
        /// Die Stelle in ``Kennfeld/vorlauf``.
        public let j: Int
        public let anzahl: Int

        public var id: Int { i * 1000 + j }

        public init(i: Int, j: Int, anzahl: Int) {
            self.i = i
            self.j = j
            self.anzahl = anzahl
        }
    }

    /// Das Kennfeld: die Ausgleichsfläche von oben, mit einem Punkt, wo gemessen wurde.
    public struct Kennfeld: Sendable, Hashable {
        /// Ganze Grad draußen (`kennlinie.ts:226-227`).
        public let aussen: [Int]
        /// Vorlauf in Zweiergraden (`kennlinie.ts:228-229`).
        public let vorlauf: [Int]
        /// Die Arbeitszahl je Feld, auf zwei Stellen gerundet - erst `aussen`, dann `vorlauf`.
        public let zellen: [[Double]]
        public let belegung: [Belegungsfeld]
        /// Der Bereich der Farbskala, auf halbe Schritte gerundet (`kennlinie.ts:276-277`).
        public let spanne: ClosedRange<Double>
        /// Die größte Belegung - der Maßstab der Kreise.
        public let meiste: Int
    }

    /// Das Kennfeld, oder `nil`, solange der Ausgleich keine Ebene ist (`kennlinie.ts:249-251`).
    ///
    /// **Nur bei einer Ebene.** Kennt der Ausgleich nur eine der beiden Temperaturen, wären die
    /// Spalten des Kennfelds alle gleich - eine Fläche, die in einer Richtung nichts sagt,
    /// behauptet trotzdem etwas. Dann steht ``kennfeldLeersatz`` an ihrer Stelle.
    public static func kennfeld(_ k: KennlinieOut) -> Kennfeld? {
        guard let f = k.fit, f.art == .ebene else { return nil }
        let aussen = ganzeGrad(von: f.aussenVonC, bis: f.aussenBisC)
        let vorlauf = zweiergrade(von: f.vorlaufVonC, bis: f.vorlaufBisC)
        guard !aussen.isEmpty, !vorlauf.isEmpty else { return nil }
        let zellen = aussen.map { ta in
            vorlauf.map { tv in
                // Auf zwei Stellen, wie die Vorlage (`kennlinie.ts:254`): die Farbe einer
                // Zelle soll dieselbe Zahl tragen, die ihr Hinweis nennt.
                (copNach(f, aussen: Double(ta), vorlauf: Double(tv)) * 100).rounded() / 100
            }
        }
        let belegt = belegung(k.punkte, aussen: aussen, vorlauf: vorlauf)
        let werte = zellen.flatMap { $0 }.filter { $0.isFinite }
        let unten = ((werte.min() ?? 0) * 2).rounded(.down) / 2
        let oben = ((werte.max() ?? 1) * 2).rounded(.up) / 2
        return Kennfeld(
            aussen: aussen, vorlauf: vorlauf, zellen: zellen, belegung: belegt,
            spanne: unten...Swift.max(unten, oben),
            meiste: Swift.max(1, belegt.map(\.anzahl).max() ?? 1))
    }

    /// Ganze Grad von unten abgerundet bis oben aufgerundet (`kennlinie.ts:226-227`).
    private static func ganzeGrad(von: Double, bis: Double) -> [Int] {
        guard von.isFinite, bis.isFinite, bis >= von, bis - von < 200 else { return [] }
        return Array(Int(von.rounded(.down))...Int(bis.rounded(.up)))
    }

    /// Vorlauf in Zweiergraden, beide Enden auf gerade Grade gelegt (`kennlinie.ts:228-229`).
    private static func zweiergrade(von: Double, bis: Double) -> [Int] {
        guard von.isFinite, bis.isFinite, bis >= von, bis - von < 200 else { return [] }
        let anfang = Int((von / 2).rounded(.down)) * 2
        let ende = Int((bis / 2).rounded(.up)) * 2
        return stride(from: anfang, through: ende, by: 2).map { $0 }
    }

    /// Wie viele Punkte in jedem Feld liegen (`kennlinie.ts:234-243`).
    ///
    /// **Der Vorlauf wird auf zwei Grad gerundet, die Außentemperatur auf ein Grad** - auf
    /// dasselbe Raster also, in dem die Farbe steht. Ein Punkt, der zwischen zwei Felder
    /// fällt, gehört zu keinem und wird nicht gezählt; das ist die Regel der Vorlage und
    /// betrifft nur Punkte außerhalb des Geltungsbereichs.
    public static func belegung(
        _ punkte: [KennlinienPunktOut], aussen: [Int], vorlauf: [Int]
    ) -> [Belegungsfeld] {
        var zaehler: [Int: Int] = [:]
        for p in punkte {
            guard p.aussenC.isFinite, p.vorlaufC.isFinite else { continue }
            guard let i = aussen.firstIndex(of: halbeNachOben(p.aussenC)) else { continue }
            let gerundet = Int((p.vorlaufC / 2).rounded()) * 2
            guard let j = vorlauf.firstIndex(of: gerundet) else { continue }
            zaehler[i * 1000 + j, default: 0] += 1
        }
        return zaehler
            .map { Belegungsfeld(i: $0.key / 1000, j: $0.key % 1000, anzahl: $0.value) }
            .sorted { $0.id < $1.id }
    }

    /// Ein halbes Grad geht nach oben - so rundet `Math.round` der Vorlage
    /// (`kennlinie.ts:237`).
    ///
    /// **Swifts `rounded()` tut das nicht**: es rundet vom Nullpunkt weg, und im Heizbetrieb
    /// ist die Außentemperatur oft negativ. Ein Punkt bei −2,5 °C läge damit in der Spalte −3,
    /// im Browser aber in der Spalte −2 - also eine Aussage darüber, wo gemessen wurde, die
    /// um eine Spalte daneben liegt.
    private static func halbeNachOben(_ wert: Double) -> Int {
        Int((wert + 0.5).rounded(.down))
    }

    /// Wo eine Arbeitszahl in der Farbskala liegt - 0 bis 1.
    public static func kennfeldanteil(_ cop: Double, spanne: ClosedRange<Double>) -> Double {
        let weite = spanne.upperBound - spanne.lowerBound
        guard weite > 0, cop.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, (cop - spanne.lowerBound) / weite))
    }

    /// Der Durchmesser eines Belegungskreises in Punkten (`kennlinie.ts:296`).
    ///
    /// `5 + 7·√(Anzahl/meiste)`: die Wurzel, weil das Auge die Fläche eines Kreises vergleicht
    /// und nicht seinen Durchmesser. Zehn Punkte in einem Feld sollen nicht zehnmal so groß
    /// aussehen wie einer.
    public static func kreisgroesse(anzahl: Int, meiste: Int) -> Double {
        guard meiste > 0 else { return 5 }
        return 5 + 7 * (Double(anzahl) / Double(meiste)).squareRoot()
    }

    /// Die beiden Wörter am Skalenband des Kennfelds (`kennlinie.ts:285`).
    public static func kennfeldskala(_ spanne: ClosedRange<Double>) -> (oben: String, unten: String) {
        (
            oben: "COP " + Formate.zahl(spanne.upperBound, stellen: 1),
            unten: Formate.zahl(spanne.lowerBound, stellen: 1)
        )
    }

    /// Wo ein Feld liegt, für den Hinweis am Finger (`kennlinie.ts:265`).
    public static func kennfeldort(aussen: Int, vorlauf: Int) -> String {
        "\(aussen) °C draußen, \(vorlauf) °C Vorlauf"
    }

    /// Was ein Feld sagt (`kennlinie.ts:268-269`).
    public static func kennfeldwert(_ cop: Double) -> String {
        "Arbeitszahl nach Ausgleich: " + Formate.zahl(cop, stellen: 2)
    }

    /// Wie viele Punkte in einem Feld liegen (`kennlinie.ts:268`).
    public static func kennfeldpunkte(_ anzahl: Int) -> String {
        "\(anzahl) " + (anzahl == 1 ? "Messpunkt" : "Messpunkte")
    }
}
