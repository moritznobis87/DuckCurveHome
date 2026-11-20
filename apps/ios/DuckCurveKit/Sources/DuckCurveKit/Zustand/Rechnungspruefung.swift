import Foundation

/// Die Rechnungsseite: welche Rechnung gezeigt wird, was über alle Rechnungen zusammengerechnet
/// wird, und wie ein Befund dasteht.
///
/// Vorlage ist `apps/web/src/components/reports/InvoiceCheck.tsx` mit den vier Diagrammen in
/// `apps/web/src/components/reports/charts.ts:279-367`. Drei Dinge aus der Vorlage tragen diese
/// Datei.
///
/// **Erstens: die Seite vergleicht, sie glaubt nicht.** Was der Versorger abgerechnet hat, steht
/// neben dem, was das Haus selbst gemessen hat - Menge, Preis, Zeitraum. Der Hinweistext der
/// Vorlage sagt denselben Satz in anderen Worten (`InvoiceCheck.tsx:213-217`): geprüft werden
/// Positionen, Summen, Mehrwertsteuer, Grundgebühr nach Tagen und der Anschluss an die
/// Vorrechnung. Eine Abweichung ist eine Frage, kein Beweis - darum heißt die Spalte „Eigene
/// Messung“ und nicht „richtig“.
///
/// **Zweitens: beim Öffnen steht eine Rechnung da.** Die Vorlage wählt die aus `?nr=`, sonst die
/// neueste, und begründet das ausdrücklich: „damit Befunde und Preisbestandteile nicht leer
/// bleiben“ (`InvoiceCheck.tsx:127-129`). Eine Seite, deren untere Hälfte erst nach einem Klick
/// entsteht, sieht beim ersten Blick aus wie eine halbe Seite.
///
/// **Drittens: die Befunde sind zweierlei.** Vier Codes vergleichen gegen eigene Daten
/// (``verglichenCodes``), alle übrigen rechnen die Rechnung nach. Die Vorlage teilt sie in zwei
/// Karten (`InvoiceCheck.tsx:201-202`), und ohne diese Teilung steht nicht da, was nachgerechnet
/// und was verglichen wurde - was ein Rechenfehler des Versorgers ist und was eine Lücke in der
/// eigenen Messung.
///
/// **Warum das hier liegt und nicht in der Ansicht.** Jede Schwelle (98 % Abdeckung, 0,005 am
/// Delta), jede Rundung (zwei Stellen am Preis, drei an einer Position, die Mehrwertsteuer auf
/// den Cent), jede Textauswahl („geprüft, alles stimmig“ gegen „Rechenfehler“) und jede
/// Farbzuordnung ist eine Entscheidung mit genau einer richtigen Antwort je Eingabe. In einer
/// `View` könnte sie unter Linux niemand nachrechnen.
public enum Rechnungspruefung {

    // MARK: - Die Rollen, in denen eine Zahl auf dieser Seite steht

    /// Welche Rolle eine Zahl oder eine Fläche hat - und damit, welche Farbe sie bekommt.
    ///
    /// **Warum nicht ``Kennzahl/Ton``.** Dem fehlt der Wert für `--alert` (#E0533D), und genau
    /// der trägt hier die Beanstandung und jede Befundzahl, die nicht `ok` ist
    /// (`InvoiceCheck.tsx:42`, `:220`). ``Kennzahl/Ton`` zu erweitern hieße, den vollständigen
    /// `switch` in `Gestalt/Farben.swift` zu erweitern, und der gehört allen Seiten. Darum eine
    /// eigene, kleine Aufzählung mit genau den Rollen dieser Seite - wie ``Gelduebersicht/Ton``
    /// es für die Kostenseite tut.
    public enum Ton: String, Sendable, Hashable, CaseIterable {
        /// `--alert` #E0533D - die Beanstandung, „auffällig“, „Rechenfehler“, jede Befundzahl,
        /// die nicht stimmt.
        case alarm
        /// `C.grid` #E0533D - die **abgerechnete** Menge im Mengendiagramm
        /// (`charts.ts:292`).
        ///
        /// Dieselben Hexwerte wie ``alarm``, und trotzdem eine eigene Rolle: dort ist Rot eine
        /// Störung, hier ist es der Netzbezug, der Geld kostet - so wie in
        /// `Marken/diagrammNetz`, dessen Kommentar denselben Grund nennt. Wer die beiden
        /// zusammenlegt, kann die eine nicht mehr ändern, ohne die andere zu treffen.
        case netz
        /// `--amber` #F2A900 - der Ø-Preis, der Arbeitspreis im Stapel, die Rechnungslinie,
        /// „geprüft, alles stimmig“ und der Punkt vor einem Befund ohne Schwere.
        case bernstein
        /// `--mist` #7FA3B3 - die eigene Messung, die eigene Preisreihe, ein Hinweis, die
        /// Netzpositionen.
        case nebel
        /// `C.base` #C2A86B - die Grundgebühr im Stapel und die Positionen der Gruppe
        /// „Steuern, Abgaben & Umlagen“ (`charts/palette.ts:39`).
        case grundgebuehr
        /// `C.export` `rgba(228,236,239,.5)` - die Mehrwertsteuer als oberster Abschnitt des
        /// Stapels (`charts/palette.ts:44`).
        case umsatzsteuer
        /// `--text-1` - eine Zahl ohne Rolle.
        case text
        /// `--text-3` - eine Zahl, die nur Herleitung ist: die Zahlen eines Befunds, der
        /// stimmt.
        case leise
    }

    // MARK: - Die Wortlaute der Seite

    /// Der Kicker der Seite (`InvoiceCheck.tsx:205`).
    ///
    /// **Er steht in der App über der ersten Karte und nicht in der Reiterzeile.** Diese Seite
    /// benutzt in der Vorlage `AreaShell` und keine Zeitraumwahl; die Reiterzeile der App trägt
    /// dort nichts, wohin er gehörte. Dieselbe Entscheidung hat die Kostenseite getroffen
    /// (``Gelduebersicht/seitenkicker``).
    public static let seitenkicker = "Tibber · nachgerechnet und gegen die eigene Messung gehalten"

    public static let pruefkartentitel = "Rechnung prüfen"
    /// Was rechts im Kopf der Prüfkarte steht, solange geprüft wird (`InvoiceCheck.tsx:211`).
    public static let laeuftKurz = "läuft"
    /// „3 gespeichert“ - wie viele Rechnungen der Dienst kennt (`InvoiceCheck.tsx:211`).
    ///
    /// Keine Einzahlform: die Vorlage schreibt auch bei einer „1 gespeichert“, und das Wort
    /// bezieht sich auf die Ablage, nicht auf die Rechnung.
    public static func gespeichert(_ anzahl: Int) -> String { "\(anzahl) gespeichert" }

    public static let ablegefeldZiehen = "Tibber-Rechnung hierher ziehen"
    public static let ablegefeldKlicken =
        "oder klicken, um PDFs auszuwählen - mehrere auf einmal möglich"
    public static let ablegefeldLaeuft = "Rechnung wird geprüft …"
    public static let ablegefeldLaeuftDazu = "Positionen werden nachgerechnet"
    /// Was im Ablegefeld steht, wo nichts hineingezogen werden kann.
    ///
    /// **Die Vorlage ist hier ein Browser auf einem Schirm mit Maus.** „Hierher ziehen“ ist an
    /// einem Telefon keine Verkürzung, sondern eine falsche Anweisung: es gibt dort keine
    /// zweite Fensterhälfte, aus der jemand eine Datei zöge. `handy.css` hat für diese Seite
    /// keine eigene Regel (gesucht nach „rechnung“, „invoice“, „geld“: kein Treffer), also ist
    /// das eine Entscheidung der App - und sie fällt für den Satz, der stimmt.
    public static let ablegefeldTippen = "Tibber-Rechnung auswählen"
    public static let ablegefeldTippenDazu =
        "PDFs aus den Dateien wählen - mehrere auf einmal möglich"

    /// Die beiden Zeilen des Ablegefelds.
    public struct Ablegetext: Sendable, Hashable {
        public let satz: String
        public let dazu: String

        public init(satz: String, dazu: String) {
            self.satz = satz
            self.dazu = dazu
        }
    }

    /// Welche beiden Zeilen im Ablegefeld stehen (`InvoiceCheck.tsx:87-90`).
    ///
    /// Während des Prüfens tauschen **beide** Zeilen - nicht nur die obere. Die untere sagt
    /// dann, was gerade geschieht („Positionen werden nachgerechnet“), und das ist bei einem
    /// Vorgang, der Sekunden dauert, die nützlichere Auskunft als eine Anweisung, die man
    /// gerade befolgt hat.
    public static func ablegetext(laeuft: Bool, ziehbar: Bool) -> Ablegetext {
        if laeuft { return Ablegetext(satz: ablegefeldLaeuft, dazu: ablegefeldLaeuftDazu) }
        return ziehbar
            ? Ablegetext(satz: ablegefeldZiehen, dazu: ablegefeldKlicken)
            : Ablegetext(satz: ablegefeldTippen, dazu: ablegefeldTippenDazu)
    }

    /// Der Hinweis unter dem Ablegefeld (`InvoiceCheck.tsx:213-217`).
    ///
    /// **Der letzte Satz ist der wichtigste.** „Das PDF selbst wird nicht gespeichert“ steht da,
    /// weil auf einer Tibber-Rechnung Name, Adresse, Marktlokations-ID und Zählernummer stehen -
    /// wer eine hochlädt, soll wissen, was damit geschieht, bevor er es tut und nicht danach.
    public static let hinweis = """
        Geprüft werden alle Positionen der Rechnung gegen Menge und Preis, die Summen, die \
        Mehrwertsteuer, die Grundgebühr nach Tagen sowie der Anschluss an die Vorrechnung. \
        Zusätzlich vergleichen wir die abgerechnete Menge mit unserem gemessenen Netzbezug. \
        Das PDF selbst wird nicht gespeichert.
        """

    /// Was dasteht, solange keine Rechnung eingelesen ist (`InvoiceCheck.tsx:333-336`).
    ///
    /// **Nicht „Es sind keine Rechnungen eingelesen“ und kein Verweis in die Dokumentation.** Die
    /// App schickte den Benutzer nach `docs/RECHNUNGSPRUEFUNG.md`, weil sie selbst keine Rechnung
    /// einlesen konnte. Sie kann es jetzt, und damit ist der Leerzustand eine Einladung und keine
    /// Auskunft über ein fehlendes Werkzeug.
    public static let leerSatz = """
        Noch keine Rechnung geprüft. Lade eine Tibber-Rechnung als PDF hoch - die Auswertung \
        entsteht dann hier und wächst mit jeder weiteren Rechnung.
        """

    public static let mengentitel = "Menge: Rechnung gegen eigene Messung"
    public static let mengenkopf = "je Abrechnungszeitraum"
    public static let betragstitel = "Rechnungsbetrag"
    public static let preistitel = "Durchschnittspreis"
    public static let preiskopf = "brutto"
    public static let positionstitel = "Preisbestandteile"
    /// Was rechts im Kopf der Positionskarte steht, solange keine Rechnung gewählt ist
    /// (`InvoiceCheck.tsx:244`).
    public static let positionskopfLeer = "Rechnung auswählen"
    public static let positionsleer = "Eine Rechnung in der Liste auswählen."

    public static let tabellentitel = "Geprüfte Rechnungen"
    /// Was rechts im Kopf der Tabelle steht (`InvoiceCheck.tsx:255`).
    public static let tabellenkopf = "Zeile anklicken für die Befunde"
    /// Die acht Spalten der Tabelle, wörtlich (`InvoiceCheck.tsx:259-268`). Die erste ist in der
    /// App der Zeilenname.
    public static let tabellenspalten = [
        "Zeitraum", "Nummer", "Menge", "Eigene Messung", "Ø brutto", "Netto", "Brutto",
        "Ergebnis",
    ]

    /// „Rechnerische Prüfung · Oktober 2026“ (`InvoiceCheck.tsx:308`).
    public static func gerechnetTitel(_ zeitraum: String) -> String {
        "Rechnerische Prüfung · \(zeitraum)"
    }
    public static let verglichenTitel = "Abgleich mit eigenen Daten"
    public static let verglichenLeer = "Kein Abgleich möglich."
    /// Was in der Rechenkarte steht, wenn der Dienst nichts nachgerechnet hat.
    ///
    /// **Die Vorlage lässt die Liste dort einfach leer** (`InvoiceCheck.tsx:311-315`), und das
    /// geht im Browser, weil die Karte dann sichtbar zusammenfällt. In der App bliebe eine
    /// Karte mit Kopfzeile und nichts darunter stehen, und die lässt offen, ob gerade geladen
    /// wird oder ob es nichts zu zeigen gibt - ``Leer`` ist dafür gemacht.
    public static let gerechnetLeer = "Keine rechnerischen Befunde."

    /// Die beiden Fehlersätze der Vorlage (`InvoiceCheck.tsx:108`, `:123`).
    ///
    /// Sie sind getrennt, weil zwei verschiedene Abfragen fehlschlagen können und die Antwort
    /// darauf eine andere ist: fällt die Liste aus, steht die Seite leer; fällt ein Bericht aus,
    /// steht die Liste noch da und nur die untere Hälfte fehlt.
    public static let listenfehler = "Rechnungen konnten nicht geladen werden."
    public static let berichtfehler = "Rechnung konnte nicht geladen werden."
    /// Was beim Prüfen einer einzelnen Datei schiefgehen kann (`InvoiceCheck.tsx:147`).
    public static let dateifehler = "Fehler beim Prüfen"

    // MARK: - Reihenfolge und Achsenwörter

    /// Die Rechnungen nach Zeitraum aufsteigend (`InvoiceCheck.tsx:161`).
    ///
    /// **Nur die Diagramme sortieren, die Tabelle nicht.** Die Vorlage zeigt in der Tabelle
    /// `items` in der Reihenfolge des Dienstes und sortiert allein für die vier Bilder - ein
    /// Verlauf, der nicht chronologisch ist, ist kein Verlauf. Dass die Tabelle anders sortiert
    /// ist, ist kein Versehen: dort führt die neueste Rechnung, und die ist die, nach der jemand
    /// sucht.
    public static func chronologisch(_ liste: [InvoiceSummaryOut]) -> [InvoiceSummaryOut] {
        liste.enumerated()
            .sorted {
                $0.element.periodStart == $1.element.periodStart
                    ? $0.offset < $1.offset
                    : $0.element.periodStart < $1.element.periodStart
            }
            .map(\.element)
    }

    /// „Oktober 2026“ wird „Okt 2026“ - das Achsenkürzel der Vorlage (`InvoiceCheck.tsx:20`).
    ///
    /// **Von Hand und nicht mit einem regulären Ausdruck, und der Grund ist ein Monat.** Die
    /// Vorlage schreibt `label.replace(/(\w{3})\w* (\d{4})/, "$1 $2")`. In JavaScript ist `\w`
    /// genau `[A-Za-z0-9_]`, Umlaute gehören nicht dazu - „März 2026“ findet dort also **keinen**
    /// Treffer und bleibt stehen. In ICU, dem Motor von `NSRegularExpression`, ist `ä` ein
    /// Wortzeichen; derselbe Ausdruck ergäbe dort „Mär 2026“. Zwei Oberflächen, die denselben
    /// Monat anders abkürzen, sind genau die Art Unterschied, die niemand sucht und jeder sieht.
    /// Darum die Regel ausgeschrieben, mit ASCII-Wortzeichen, und „März 2026“ im Test.
    ///
    /// Ersetzt wird wie `String.replace` ohne `/g` nur der **erste** Treffer.
    public static func achsenkuerzel(_ wort: String) -> String {
        let z = Array(wort)
        var start = 0
        while start < z.count {
            var ende = start
            while ende < z.count, istWortzeichen(z[ende]) { ende += 1 }
            if ende - start >= 3, ende + 5 <= z.count, z[ende] == " ",
                z[(ende + 1)..<(ende + 5)].allSatisfy(istZiffer)
            {
                let vorne = String(z[0..<start])
                let kurz = String(z[start..<(start + 3)])
                let jahr = String(z[(ende + 1)..<(ende + 5)])
                let hinten = String(z[(ende + 5)...])
                return vorne + kurz + " " + jahr + hinten
            }
            start += 1
        }
        return wort
    }

    private static func istWortzeichen(_ c: Character) -> Bool {
        c.isASCII && (c.isLetter || c.isNumber || c == "_")
    }

    private static func istZiffer(_ c: Character) -> Bool {
        c.isASCII && c.isNumber
    }

    // MARK: - Die vier Kennzahlen über alle Rechnungen

    /// Eine Kachel des Kopfrasters: Zahl, Wort, Einheit, Hinweis und Rolle.
    ///
    /// **Warum nicht ``Kennzahl``.** Die trägt ``Kennzahl/Ton``, und dem fehlt `--alert` - siehe
    /// ``Ton``. Sonst ist es derselbe Baustein, und die Ansicht macht daraus dieselbe Kachel.
    public struct Kopfzahl: Sendable, Hashable, Identifiable {
        public let wort: String
        public let wert: String
        public let einheit: String?
        public let dazu: String?
        public let ton: Ton

        public var id: String { wort }

        public init(
            wort: String, wert: String, einheit: String? = nil, dazu: String? = nil,
            ton: Ton = .text
        ) {
            self.wort = wort
            self.wert = wert
            self.einheit = einheit
            self.dazu = dazu
            self.ton = ton
        }
    }

    /// Die vier Kacheln über **allen** Rechnungen (`InvoiceCheck.tsx:219-224`).
    ///
    /// **Die App hatte sie nicht.** Sie zeigte sechs Kacheln zu *einer* gewählten Rechnung;
    /// über alle Rechnungen zusammen stand nichts da. Genau das ist aber die Frage, mit der
    /// jemand auf diese Seite kommt: wie viel habe ich bezahlt, und stimmte es.
    ///
    /// **Der Ø-Preis ist mengengewichtet und nicht der Mittelwert der Mittelwerte.** Ein Monat
    /// mit 40 kWh und ein Monat mit 600 kWh zählen sonst gleich viel, und die Zahl wäre ein
    /// Durchschnitt über Rechnungen statt über Kilowattstunden. Ohne Menge steht ein Strich und
    /// keine Null (`InvoiceCheck.tsx:223`): eine Null wäre ein Preis, den niemand bezahlt hat.
    public static func kopfkennzahlen(_ liste: [InvoiceSummaryOut]) -> [Kopfzahl] {
        let nachZeit = chronologisch(liste)
        let beanstandet = liste.filter { Rechnungsurteil.aus($0.verdict)?.istBefund == true }.count
        let brutto = liste.reduce(0) { $0 + $1.totalGrossEur }
        let menge = liste.reduce(0) { $0 + $1.kwh }
        let gewichtet = liste.reduce(0) { $0 + $1.avgCtKwhGross * $1.kwh }
        return [
            Kopfzahl(
                wort: "Geprüfte Rechnungen", wert: "\(liste.count)",
                dazu: spanne(nachZeit), ton: .text),
            Kopfzahl(
                wort: "Beanstandet", wert: "\(beanstandet)",
                dazu: beanstandet > 0 ? "Befunde unten ansehen" : "keine Auffälligkeit",
                ton: beanstandet > 0 ? .alarm : .bernstein),
            Kopfzahl(
                wort: "Summe brutto", wert: Formate.euro(brutto),
                dazu: "über \(Formate.zahl(menge, stellen: 0))\(Formate.schmalesLeerzeichen)kWh",
                ton: .text),
            Kopfzahl(
                wort: "Ø Preis brutto",
                wert: menge > 0 ? Formate.zahl(gewichtet / menge, stellen: 2) : Formate.leer,
                einheit: "ct/kWh", dazu: "mengengewichtet über alle Rechnungen",
                ton: .bernstein),
        ]
    }

    /// „Januar 2026 bis Oktober 2026“ - oder „noch keine“ (`InvoiceCheck.tsx:220`).
    private static func spanne(_ nachZeit: [InvoiceSummaryOut]) -> String {
        guard let erste = nachZeit.first, let letzte = nachZeit.last else { return "noch keine" }
        return "\(erste.periodLabel) bis \(letzte.periodLabel)"
    }

    // MARK: - Diagramm 1: Menge gegen eigene Messung

    /// Ein Abrechnungszeitraum mit zwei Mengen (`charts.ts:279-295`).
    public struct Mengenpaar: Sendable, Hashable, Identifiable {
        public let wort: String
        public let rechnung: Double
        /// Fehlt die eigene Messung, steht dort kein Balken - nicht eine Null. Eine Null wäre
        /// die Aussage, es sei nichts bezogen worden.
        public let messung: Double?

        public var id: String { wort }

        public init(wort: String, rechnung: Double, messung: Double?) {
            self.wort = wort
            self.rechnung = rechnung
            self.messung = messung
        }
    }

    /// Eine Reihe eines Diagramms: ihr Name in der Legende und ihre Rolle.
    ///
    /// **Der Name ist zugleich der Schlüssel der Reihe im Diagramm.** Swift Charts braucht je
    /// Reihe einen `series:`-Wert; ohne ihn wird aus beiden Mengen eine Säule und aus beiden
    /// Preislinien eine Linie.
    public struct Reihe: Sendable, Hashable, Identifiable {
        public let name: String
        public let ton: Ton

        public var id: String { name }

        public init(name: String, ton: Ton) {
            self.name = name
            self.ton = ton
        }
    }

    public static let mengenreiheRechnung = "Rechnung"
    public static let mengenreiheMessung = "Eigene Messung"
    /// Die beiden Säulen des Mengendiagramms (`charts.ts:292-293`).
    public static let mengenreihen: [Reihe] = [
        Reihe(name: mengenreiheRechnung, ton: .netz),
        Reihe(name: mengenreiheMessung, ton: .nebel),
    ]

    public static func mengenpaare(_ liste: [InvoiceSummaryOut]) -> [Mengenpaar] {
        chronologisch(liste).map {
            Mengenpaar(
                wort: achsenkuerzel($0.periodLabel), rechnung: $0.kwh, messung: $0.measuredKwh)
        }
    }

    // MARK: - Diagramm 2: der Rechnungsbetrag, gestapelt

    public struct Betragswert: Sendable, Hashable {
        public let wort: String
        public let wert: Double

        public init(wort: String, wert: Double) {
            self.wort = wort
            self.wert = wert
        }
    }

    /// Eine Reihe des gestapelten Balkens (`charts.ts:297-322`).
    public struct Betragsreihe: Sendable, Hashable, Identifiable {
        public let name: String
        public let ton: Ton
        public let werte: [Betragswert]

        public var id: String { name }

        public init(name: String, ton: Ton, werte: [Betragswert]) {
            self.name = name
            self.ton = ton
            self.werte = werte
        }
    }

    /// Arbeitspreis, Grundgebühr und Mehrwertsteuer je Zeitraum (`charts.ts:299-303`).
    ///
    /// **Die Mehrwertsteuer wird gerechnet und steht nicht in der Zeile.** `InvoiceSummaryOut`
    /// hat kein Steuerfeld; die Vorlage bildet sie als Brutto minus Netto und rundet auf den
    /// Cent (`InvoiceCheck.tsx:173`). Ohne diese Rundung summiert sich der Gleitkommarest in den
    /// Stapel und die oberste Fläche ist bei jedem Monat um einen Hauch verschieden hoch.
    public static func betragsreihen(_ liste: [InvoiceSummaryOut]) -> [Betragsreihe] {
        let nachZeit = chronologisch(liste)
        return [
            Betragsreihe(
                name: "Arbeitspreis netto", ton: .bernstein,
                werte: nachZeit.map {
                    Betragswert(wort: achsenkuerzel($0.periodLabel), wert: $0.energyNetEur)
                }),
            Betragsreihe(
                name: "Grundgebühr netto", ton: .grundgebuehr,
                werte: nachZeit.map {
                    Betragswert(wort: achsenkuerzel($0.periodLabel), wert: $0.feesNetEur)
                }),
            Betragsreihe(
                name: "Mehrwertsteuer", ton: .umsatzsteuer,
                werte: nachZeit.map {
                    Betragswert(
                        wort: achsenkuerzel($0.periodLabel),
                        wert: umsatzsteuer($0.totalGrossEur, netto: $0.totalNetEur))
                }),
        ]
    }

    /// Brutto minus Netto, auf den Cent gerundet (`InvoiceCheck.tsx:173`).
    ///
    /// **`floor(x + 0,5)` und nicht `rounded()`, und der Unterschied ist das Vorzeichen.**
    /// `Math.round` in JavaScript rundet die halbe Stelle immer **aufwärts**, also −12,5 auf
    /// −12; `Double.rounded()` rundet vom Nullpunkt weg, also auf −13. Bei einer Gutschrift mit
    /// genau einem halben Cent wären App und Browser dann um einen Cent auseinander - und auf
    /// einer Seite, die nachrechnet, ist ein Cent genau die Art Abweichung, die jemand sucht.
    public static func umsatzsteuer(_ brutto: Double, netto: Double) -> Double {
        let roh = (brutto - netto) * 100
        guard roh.isFinite else { return 0 }
        return (roh + 0.5).rounded(.down) / 100
    }

    // MARK: - Diagramm 3: der Durchschnittspreis

    /// Ein Punkt der beiden Preislinien (`charts.ts:324-340`).
    public struct Preispunkt: Sendable, Hashable, Identifiable {
        public let wort: String
        public let rechnung: Double
        /// Der aus den eigenen Preisdaten errechnete Wert, wo es einen gibt.
        public let eigene: Double?

        public var id: String { wort }

        public init(wort: String, rechnung: Double, eigene: Double?) {
            self.wort = wort
            self.rechnung = rechnung
            self.eigene = eigene
        }
    }

    public static let preisreiheRechnung = "Rechnung (brutto)"
    public static let preisreiheEigene = "Eigene Preisreihe"
    /// Die beiden Linien des Preisdiagramms (`charts.ts:337-338`). Die eigene Reihe ist
    /// gestrichelt - das entscheidet die Ansicht, weil es ein Strichmuster und keine Rechnung
    /// ist.
    public static let preisreihen: [Reihe] = [
        Reihe(name: preisreiheRechnung, ton: .bernstein),
        Reihe(name: preisreiheEigene, ton: .nebel),
    ]

    public static func preisreihe(_ liste: [InvoiceSummaryOut]) -> [Preispunkt] {
        chronologisch(liste).map {
            Preispunkt(
                wort: achsenkuerzel($0.periodLabel), rechnung: $0.avgCtKwhGross,
                eigene: $0.measuredAvgCtKwh)
        }
    }

    /// Die Werteachse des Preisdiagramms - **ohne die Null** (`charts.ts:336`: `scale: true`).
    ///
    /// **Warum die Null hier nicht hingehört.** Zwei Preisreihen liegen zwischen 28 und 34
    /// ct/kWh. Mit der Null im Bild werden daraus zwei Linien im obersten Fünftel, und der
    /// Unterschied, um den es geht - stimmt der abgerechnete Preis mit dem eigenen? - ist einen
    /// Pixel hoch. ``Achse/spanne(werte:rand:mindestens:)`` ist der im Projekt dafür gebaute
    /// Weg; die Vorgaben sind hier andere als bei Raumtemperaturen: ein Cent Rand und vier Cent
    /// Mindestspanne, damit ein Jahr mit stabilem Preis nicht aussieht wie ein Jahr mit
    /// Ausschlägen.
    public static func preisspanne(_ punkte: [Preispunkt]) -> ClosedRange<Double>? {
        // `Optional(...)` ausgeschrieben: eine gemischte Reihe aus `Double` und `Double?` ist in
        // einem Literal nicht eindeutig, und `Achse.spanne` nimmt `[Double?]`.
        Achse.spanne(
            werte: punkte.flatMap { [Optional($0.rechnung), $0.eigene] }, rand: 1, mindestens: 4)
    }

    // MARK: - Diagramm 4: die Preisbestandteile einer Rechnung

    /// Eine Position der Rechnung als liegender Balken (`charts.ts:342-367`).
    public struct Positionsbalken: Sendable, Hashable, Identifiable {
        public let wort: String
        public let gruppe: String
        /// Die Zahl, wie sie am Balkenende steht - drei Stellen (`charts.ts:364`).
        public let wert: String
        public let ct: Double
        /// Wie lang der Balken ist, 0 bis 1 - gegen die größte Position dieser Rechnung.
        public let anteil: Double
        public let ton: Ton

        public var id: String { wort }

        public init(
            wort: String, gruppe: String, wert: String, ct: Double, anteil: Double, ton: Ton
        ) {
            self.wort = wort
            self.gruppe = gruppe
            self.wert = wert
            self.ct = ct
            self.anteil = anteil
            self.ton = ton
        }
    }

    /// Die Positionen in der Reihenfolge des Bildes, mit Länge und Farbe.
    ///
    /// **Umgedreht, weil ECharts von unten zeichnet.** Die Vorlage schreibt
    /// `[...positions].reverse()`, damit die erste Position der Rechnung **oben** steht
    /// (`charts.ts:345`). In einer Liste von oben nach unten ist das die ursprüngliche
    /// Reihenfolge - also wird hier **nicht** gedreht, und genau das ist die Übersetzung: beide
    /// Oberflächen zeigen die erste Position zuerst.
    ///
    /// **Die Länge rechnet der Kern.** Wie bei ``Gelduebersicht/ersparnisteile(_:)``: eine je
    /// Zeile normierte Leiste wäre immer voll und nähme den Vergleich weg, um den es geht
    /// (`Bausteine/Anteilsleiste.swift:10-13`). Gerechnet wird gegen die größte Position;
    /// negative Positionen - eine Gutschrift kommt vor - bekommen keine Länge, weil eine Leiste
    /// nach links in dieser Darstellung nicht vorgesehen ist.
    public static func positionsbalken(_ positionen: [InvoicePosition]) -> [Positionsbalken] {
        let groesste = positionen.map(\.ctPerKwh).filter { $0.isFinite }.max() ?? 0
        return positionen.map { p in
            Positionsbalken(
                wort: p.label, gruppe: p.group, wert: Formate.zahl(p.ctPerKwh, stellen: 3),
                ct: p.ctPerKwh, anteil: leistenanteil(p.ctPerKwh, groesste),
                ton: gruppenton(p.group))
        }
    }

    static func leistenanteil(_ wert: Double, _ groesste: Double) -> Double {
        guard groesste > 0, wert.isFinite, wert > 0 else { return 0 }
        return min(1, wert / groesste)
    }

    /// Die Farbe einer Position nach ihrer Gruppe (`charts.ts:344`).
    ///
    /// Die drei Gruppennamen kommen als Text aus dem Dienst und sind darum Zeichenketten und
    /// keine Aufzählung. Was nicht dabei ist, wird wie „Steuern, Abgaben & Umlagen“ gezeichnet -
    /// so macht es die Vorlage mit ihrem `?? C.base`.
    public static func gruppenton(_ gruppe: String) -> Ton {
        switch gruppe {
        case "Stromeinkauf": return .bernstein
        case "Netz": return .nebel
        default: return .grundgebuehr
        }
    }

    // MARK: - Die Ablesezeile über den Verlaufsdiagrammen

    /// Eine Zeile der Ablesung: was an der berührten Stelle steht.
    public struct Ablesezeile: Sendable, Hashable, Identifiable {
        public let text: String
        public let ton: Ton

        public var id: String { text }

        public init(text: String, ton: Ton) {
            self.text = text
            self.ton = ton
        }
    }

    /// Was über einem Verlaufsdiagramm steht, solange niemand es berührt.
    ///
    /// **Warum es diese Zeile überhaupt gibt.** `charts.ts` setzt auf jedes der drei
    /// Verlaufsdiagramme einen Tooltip (`charts.ts:283`, `:304`, `:329`). Der im Projekt
    /// gewählte Weg ist eine Ablesezeile über dem Bild und kein Kasten darin - begründet in
    /// `Diagramme/Geldbalken.swift:15-19` und vorgeführt in
    /// `Diagramme/Prognosezeichnung.swift:55-60`: eine Beschriftung im Zeichenbereich staucht
    /// die Skala, und dann stehen die Säulen zweier Karten nicht mehr auf derselben Teilung.
    public static let ablesungAufforderung = "Einen Zeitraum berühren, um die Zahlen zu lesen."

    /// Die Mengen an der berührten Stelle - „x kWh“ mit einer Stelle (`charts.ts:283`).
    public static func mengenablesung(wort: String, paare: [Mengenpaar]) -> [Ablesezeile] {
        guard let p = paare.first(where: { $0.wort == wort }) else { return [] }
        return [
            Ablesezeile(
                text: "\(mengenreiheRechnung): \(Formate.kwh(p.rechnung))", ton: .netz),
            Ablesezeile(
                text: "\(mengenreiheMessung): \(Formate.kwh(p.messung))", ton: .nebel),
        ]
    }

    /// Die drei Beträge an der berührten Stelle - zwei Stellen und „ €“ (`charts.ts:304`).
    public static func betragsablesung(wort: String, reihen: [Betragsreihe]) -> [Ablesezeile] {
        reihen.compactMap { reihe in
            guard let w = reihe.werte.first(where: { $0.wort == wort }) else { return nil }
            return Ablesezeile(text: "\(reihe.name): \(Formate.euro(w.wert))", ton: reihe.ton)
        }
    }

    /// Die beiden Preise an der berührten Stelle - zwei Stellen, `nil` als Strich
    /// (`charts.ts:329`).
    public static func preisablesung(wort: String, punkte: [Preispunkt]) -> [Ablesezeile] {
        guard let p = punkte.first(where: { $0.wort == wort }) else { return [] }
        return [
            Ablesezeile(text: "\(preisreiheRechnung): \(preistext(p.rechnung))", ton: .bernstein),
            Ablesezeile(text: "\(preisreiheEigene): \(preistext(p.eigene))", ton: .nebel),
        ]
    }

    /// „31,45 ct/kWh“ mit **zwei** Stellen - ``Formate/ct(_:)`` nimmt eine, und auf dieser Seite
    /// steht der Preis einer Rechnung, nicht der einer Stunde: der zweite Cent entscheidet, ob
    /// der abgerechnete Preis zum eigenen passt.
    static func preistext(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return Formate.leer }
        return Formate.zahl(wert, stellen: 2) + Formate.schmalesLeerzeichen + "ct/kWh"
    }

    // MARK: - Die Tabellenzeile

    /// Die Spalte „Eigene Messung“ (`InvoiceCheck.tsx:284-288`).
    ///
    /// **Die Abdeckung steht nur da, wenn sie unter 98 % liegt.** Die App schrieb sie immer hin
    /// („abgedeckter Zeitraum: 100 %“), und eine Zahl, die in neun von zehn Zeilen dasselbe
    /// sagt, liest niemand mehr - gerade dann nicht, wenn sie in der zehnten etwas anderes sagt.
    /// Zwei Prozent fehlende Minuten verschieben eine Monatsmenge um wenige Kilowattstunden;
    /// darunter ist die Lücke die Erklärung für eine Abweichung und muss dastehen.
    ///
    /// Ohne Messung, und bei einer gemessenen Null, steht ein Strich: eine Null wäre die
    /// Behauptung, das Haus habe nichts bezogen.
    public static func messungsspalte(_ r: InvoiceSummaryOut) -> String {
        guard let gemessen = r.measuredKwh, gemessen.isFinite, gemessen > 0 else {
            return Formate.leer
        }
        let menge = Formate.zahl(gemessen, stellen: 1) + Formate.schmalesLeerzeichen + "kWh"
        guard let abdeckung = r.coverage, abdeckung.isFinite, abdeckung < 0.98 else { return menge }
        return menge + " (\(Formate.prozent(abdeckung)))"
    }

    /// Eine Zeile der Tabelle „Geprüfte Rechnungen“, fertig formatiert (`InvoiceCheck.tsx:
    /// 269-299`).
    ///
    /// **Fertig formatiert und nicht als Zahlen.** Jede dieser acht Zellen trägt eine
    /// Entscheidung: zwei Stellen an der Menge, eine an der eigenen Messung, „ct“ und nicht
    /// „ct/kWh“ in der Ø-Spalte, ein Strich statt einer Null. Eine `View` könnte das unter
    /// Linux nicht nachrechnen.
    public struct Tabellenzeile: Sendable, Hashable, Identifiable {
        /// Die Rechnungsnummer - sie wählt die Rechnung aus und ist darum die Kennung.
        public let nummer: String
        public let zeitraum: String
        public let menge: String
        public let messung: String
        public let preis: String
        public let netto: String
        public let brutto: String
        public let ergebnis: Ergebnis

        public var id: String { nummer }

        public init(
            nummer: String, zeitraum: String, menge: String, messung: String, preis: String,
            netto: String, brutto: String, ergebnis: Ergebnis
        ) {
            self.nummer = nummer
            self.zeitraum = zeitraum
            self.menge = menge
            self.messung = messung
            self.preis = preis
            self.netto = netto
            self.brutto = brutto
            self.ergebnis = ergebnis
        }
    }

    /// Die Tabelle **in der Reihenfolge des Dienstes** - nicht chronologisch
    /// (`InvoiceCheck.tsx:269`, nur die Diagramme sortieren).
    public static func tabellenzeilen(_ liste: [InvoiceSummaryOut]) -> [Tabellenzeile] {
        liste.map { r in
            Tabellenzeile(
                nummer: r.number, zeitraum: r.periodLabel,
                menge: Formate.zahl(r.kwh, stellen: 2) + Formate.schmalesLeerzeichen + "kWh",
                messung: messungsspalte(r),
                // „ct“ und nicht „ct/kWh“: der Spaltenkopf sagt „Ø brutto“, und in einer
                // Tabelle mit sieben Zahlenspalten kostet jedes Zeichen Platz
                // (`InvoiceCheck.tsx:289`).
                preis: Formate.zahl(r.avgCtKwhGross, stellen: 2) + Formate.schmalesLeerzeichen
                    + "ct",
                netto: Formate.euro(r.totalNetEur), brutto: Formate.euro(r.totalGrossEur),
                ergebnis: ergebnis(r.verdict, probleme: r.problems))
        }
    }

    /// Was in der Ergebnisspalte steht: Wort und Zahl der Befunde.
    public struct Ergebnis: Sendable, Hashable {
        public let text: String
        public let ton: Ton

        public init(text: String, ton: Ton) {
            self.text = text
            self.ton = ton
        }
    }

    /// Das Urteil als Wort **mit** der Zahl der Befunde - „auffällig (2)“
    /// (`InvoiceCheck.tsx:292-295`).
    ///
    /// **Die App schrieb nur die Zahl** („2 Befunde“), und die Begründung dafür stand in der
    /// Ansicht: auf einer Zeile sei die Zahl die nützlichere Auskunft
    /// (`RechnungenSeite.swift:83-85`). Das galt, solange die Zeile aus zwei Textzeilen bestand.
    /// In einer Tabelle mit einer Spalte „Ergebnis“ gilt es nicht mehr: dort braucht die Spalte
    /// zuerst das Urteil, und die Zahl steht daneben in Klammern.
    ///
    /// **Ein unbekanntes Wort bekommt die Darstellung von `info`** (`InvoiceCheck.tsx:272`:
    /// `TONE[i.verdict] ?? TONE.info`). Das ist eine Abweichung von der Liste der alten App, die
    /// das Rohwort zeigte - und die Vorlage hat recht: in einer Tabellenspalte neben vier
    /// deutschen Sätzen steht ein englisches `pending` wie ein Fehler der App da, nicht wie eine
    /// Auskunft des Dienstes.
    public static func ergebnis(_ roh: String, probleme: Int) -> Ergebnis {
        let urteil = Rechnungsurteil.aus(roh) ?? .info
        let ton: Ton =
            switch urteil {
            case .error, .warning: .alarm
            case .info: .nebel
            case .ok: .bernstein
            }
        return Ergebnis(
            text: probleme > 0 ? "\(urteil.wort) (\(probleme))" : urteil.wort, ton: ton)
    }

    // MARK: - Die Befunde

    /// Die vier Codes, die gegen die eigenen Daten vergleichen (`InvoiceCheck.tsx:201-202`).
    public static let verglichenCodes = [
        "measured_kwh", "measured_price", "coverage", "no_measurement",
    ]

    /// Was die Vorlage nachgerechnet hat: alles außer den vier Vergleichscodes.
    public static func gerechnet(_ findings: [InvoiceFinding]) -> [InvoiceFinding] {
        nachSchwere(findings).filter { !verglichenCodes.contains($0.code) }
    }

    /// Was gegen die eigene Messung gehalten wurde.
    public static func verglichen(_ findings: [InvoiceFinding]) -> [InvoiceFinding] {
        nachSchwere(findings).filter { verglichenCodes.contains($0.code) }
    }

    /// Nach Schwere: Fehler, Warnung, Hinweis, in Ordnung - Unbekanntes zuletzt
    /// (`InvoiceCheck.tsx:19`, `:197-200`).
    ///
    /// **Stabil sortiert, und das ist kein Detail.** `Array.prototype.sort` ist in JavaScript seit
    /// ES2019 stabil; `sorted(by:)` in Swift ist es ausdrücklich **nicht**. Zwei Befunde
    /// derselben Schwere könnten hier also in anderer Reihenfolge stehen als im Browser, und das
    /// wäre bei gleichem Rang die Reihenfolge des Dienstes gegen eine zufällige. Darum wird die
    /// Eingangsstelle mitsortiert.
    static func nachSchwere(_ findings: [InvoiceFinding]) -> [InvoiceFinding] {
        findings.enumerated()
            .sorted {
                rang($0.element.severity) == rang($1.element.severity)
                    ? $0.offset < $1.offset
                    : rang($0.element.severity) < rang($1.element.severity)
            }
            .map(\.element)
    }

    static func rang(_ s: InvoiceFindingSeverityWahl) -> Int {
        switch s {
        case .error: return 0
        case .warning: return 1
        case .info: return 2
        case .ok: return 3
        case .unbekannt: return 9
        }
    }

    /// „3 von 7 stimmig“ - was rechts im Kopf der Rechenkarte steht (`InvoiceCheck.tsx:309`).
    public static func stimmig(_ befunde: [InvoiceFinding]) -> String {
        let gut = befunde.filter { $0.severity == .ok }.count
        return "\(gut) von \(befunde.count) stimmig"
    }

    /// Die Zahlen eines Befunds: „31,20 erwartet · 31,45 ct/kWh · +0,25“
    /// (`InvoiceCheck.tsx:34`, `:41-45`).
    ///
    /// **Nur wenn beide Werte da sind.** Die App zeigte sie, sobald *einer* dastand - und
    /// „erwartet 31,20“ ohne den Vergleichswert ist keine Prüfung, sondern eine Behauptung ohne
    /// Gegenüber. Die Vorlage verlangt `expected != null && actual != null`.
    ///
    /// **Das Delta erst ab 0,005.** Darunter rundet es auf „0,00“, und ein angehängtes „· 0,00“
    /// liest sich wie eine Abweichung, die es nicht gibt.
    public static func befundzahlen(_ f: InvoiceFinding) -> String? {
        guard let erwartet = f.expected, let tatsaechlich = f.actual,
            erwartet.isFinite, tatsaechlich.isFinite
        else { return nil }
        var text = "\(Formate.zahl(erwartet, stellen: 2)) erwartet"
        text += " · \(Formate.zahl(tatsaechlich, stellen: 2))"
        // Die Einheit kommt aus dem Dienst und fehlt bei einem Befund ohne Größe (etwa einer
        // Stückzahl). Dann steht keine - und kein Leerzeichen, das wie eine aussieht.
        if let einheit = f.unit, !einheit.isEmpty {
            text += "\(Formate.schmalesLeerzeichen)\(einheit)"
        }
        if let delta = f.delta, delta.isFinite, abs(delta) >= 0.005 {
            let vorzeichen = delta > 0 ? "+" : ""
            text += " · \(vorzeichen)\(Formate.zahl(delta, stellen: 2))"
        }
        return text
    }

    /// Die Farbe der Befundzahlen: still, wenn der Befund stimmt - sonst `--alert`
    /// (`InvoiceCheck.tsx:42`).
    public static func befundzahlenton(_ s: InvoiceFindingSeverityWahl) -> Ton {
        s == .ok ? .leise : .alarm
    }

    /// Die Farbe des Punktes vor einem Befund (`InvoiceCheck.tsx:22-31`).
    ///
    /// Fehler und Warnung rot, Hinweis nebelfarben, **alles andere - `ok` eingeschlossen -
    /// bernstein**. Dass ein erfolgreich geprüfter Punkt gelb und nicht grün ist, ist auffällig
    /// und bleibt trotzdem so: zwei Oberflächen, die dieselbe Prüfung verschieden einfärben,
    /// sind schlimmer als eine fragliche Farbe.
    public static func befundton(_ s: InvoiceFindingSeverityWahl) -> Ton {
        switch s {
        case .error, .warning: return .alarm
        case .info: return .nebel
        case .ok, .unbekannt: return .bernstein
        }
    }

    // MARK: - Die Fußzeile des Abgleichs

    /// „Zeitraum 2026-10-01 bis 2026-10-31 · Zählerstand 41.203,40 → 41.615,80 kWh (abgelesen)“
    /// (`InvoiceCheck.tsx:322-326`).
    ///
    /// **Der Zählerstand stand in der App nirgends**, obwohl das Modell ihn seit immer trägt
    /// (`meterStart`, `meterEnd`, `meterEstimated`). Er ist die einzige Zahl auf der Seite, die
    /// jemand am Zähler im Keller nachsehen kann - und „(errechnet)“ sagt, wann genau das nicht
    /// geht, weil der Versorger den Stand selbst geschätzt hat.
    ///
    /// Die Datumsangaben stehen so da, wie der Dienst sie schickt, wie in der Vorlage: es sind
    /// die Grenzen der Abrechnung und nicht ein Tag, den die Anzeige deuten dürfte.
    public static func zaehlerzeile(_ i: TibberInvoice) -> String {
        let stand =
            "\(Formate.zahl(i.meterStart, stellen: 2)) → \(Formate.zahl(i.meterEnd, stellen: 2))"
        let art = i.meterEstimated == true ? "errechnet" : "abgelesen"
        return "Zeitraum \(i.periodStart) bis \(i.periodEnd) · Zählerstand \(stand)"
            + "\(Formate.schmalesLeerzeichen)kWh (\(art))"
    }

    // MARK: - Hochladen

    /// Welche Rechnung nach dem Öffnen gezeigt wird (`InvoiceCheck.tsx:127-135`).
    ///
    /// **Die neueste, und das ist `liste.first`** - die erste der *unsortierten* Liste, so wie
    /// die Vorlage es tut. Der Grund steht dort im Kommentar und gilt hier genauso: damit Befunde
    /// und Preisbestandteile nicht leer bleiben.
    ///
    /// Die Vorlage bevorzugt die Nummer aus `?nr=`, weil Alfred im Browser so auf eine geprüfte
    /// Rechnung verlinkt. Der ``Wegweiser`` der App trägt keine Frageliste (gesucht nach `nr=`
    /// in `apps/ios`: kein Treffer), darum nimmt `gewuenscht` hier den Weg, über den eine
    /// gerade geprüfte Rechnung hereinkommt: die aus dem Ablegefeld. Eine unbekannte Nummer
    /// fällt still auf die neueste zurück.
    public static func erstauswahl(_ liste: [InvoiceSummaryOut], gewuenscht: String? = nil)
        -> String?
    {
        if let gewuenscht, liste.contains(where: { $0.number == gewuenscht }) { return gewuenscht }
        return liste.first?.number
    }

    /// Die Fehlschläge mehrerer Dateien in einer Zeile (`InvoiceCheck.tsx:147`, `:154`).
    ///
    /// Je Datei ihr Name und der Rat des Dienstes, verbunden mit „ · “ - wie in der Vorlage. Wer
    /// vier Rechnungen auf einmal ablegt und bei einer scheitert, soll sehen, bei welcher.
    public static func dateifehlerzeile(_ fehler: [(name: String, rat: String)]) -> String? {
        guard !fehler.isEmpty else { return nil }
        return fehler.map { "\($0.name): \($0.rat)" }.joined(separator: " · ")
    }
}
