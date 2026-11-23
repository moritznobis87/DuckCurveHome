import Foundation

/// Alfred, der Helfer.
///
/// **Ohne Sprachmodell erklärt er die Anwendung** – vorbereitete Texte, nichts verlässt das
/// Haus. Mit Modell beantwortet er Fragen zu den Daten dieses Hauses, schlägt Schaltungen vor
/// (ausgeführt erst auf Knopfdruck) und liest Rechnungen.
///
/// **Der Anbieter bleibt der Oberfläche unbekannt.** Sie schickt eine Frage an den eigenen
/// Dienst und bekommt eine Antwort. Nur den *Namen* des Anbieters zeigt sie, weil die
/// KI-Verordnung es verlangt (Art. 50) – deshalb steht er in ``hinweisModell(anbieter:)``
/// und nicht als Fußnote irgendwo.
///
/// **Warum die Wegbeschreibung gerechnet und nicht geschrieben ist.** Im Dashboard steht die
/// Begründung: von vierzehn aus dem Kopf geschriebenen Hilfetexten waren dort zwei falsch –
/// links und rechts vertauscht, eine Auswahl, die es nicht gab. Beides klang plausibel. Ein
/// Sprachmodell täte dasselbe, nur überzeugender und öfter. Welcher Reiter in welchem Bereich
/// steht, kommt deshalb aus ``Bereiche/alle`` – derselben Liste, aus der die Leiste gebaut
/// wird. Ein umbenannter Reiter ist dann auch in Alfreds Auskunft umbenannt.
public enum Alfred {

    // MARK: - Was eine Seite zeigt

    /// Was eine Seite zeigt, je Adresse. Wortgleich mit `apps/web/src/components/alfred/
    /// hilfetexte.ts`, damit Alfred im Browser und am Telefon dasselbe sagt.
    ///
    /// Die Texte sagen, was eine Seite zeigt, und nennen keine Knöpfe darin: was auf einer
    /// Seite genau steht, ändert sich öfter als ihre Aufgabe.
    public static let seiten: [String: String] = [
        "/": "Jetzt ist die Wandanzeige: der Energiefluss im Augenblick (Photovoltaik, Netz, Speicher, Haus, Wärmepumpe, Wallbox), der Pufferspeicher, der Strompreis und der Ausblick auf die nächsten 24 Stunden.",
        "/haus": "Haus zeigt die Räume, als Liste zum Stellen der Solltemperatur oder als Modell mit Temperaturen und Kontakten.",
        "/strom": "Strom zeigt die Strombilanz des gewählten Zeitraums: Erzeugung, Netzbezug, Einspeisung, Speicher und Verbrauch.",
        "/waerme": "Wärme zeigt, was die Wärmepumpe an Strom gebraucht und gekostet hat, und die Wärmebilanz der Erzeuger.",
        "/strom/pv": "Photovoltaik zeigt Erzeugung, Eigenverbrauch und Einspeisung der Anlage im gewählten Zeitraum.",
        "/strom/speicher": "Speicher zeigt Laden, Entladen und Ladestand des Hausspeichers und was er gebracht hat.",
        "/strom/wallbox": "Wallbox zeigt Ladeenergie, Herkunft des Stroms, Kosten und Ladevorgänge.",
        "/strom/jahr": "Die Jahreskarte zeigt ein Kalenderjahr als Fläche aus Tagen und Stunden.",
        "/geld": "Kosten zeigt, was Strom im gewählten Zeitraum gekostet hat.",
        "/geld/pv-abrechnung": "PV-Abrechnung zeigt Einspeisung, Eigenverbrauch und Umsatzsteuer der Anlage. Nur mit Vollzugriff.",
        "/geld/rechnungen": "Rechnungen prüft Tibber-Rechnungen: Das PDF wird hochgeladen, nachgerechnet und gegen den eigenen Zähler gehalten. Nur mit Vollzugriff.",
        "/anlage": "Anlage ist die Übersicht der Heizungsanlage. Sie ordnet ihre Seiten in drei Gruppen: die Maschine, ihre Regelung und die Abstimmung.",
        "/waerme/anlage": "Anlage zeigt das Anlagenschema im Augenblick; die Ansicht Ein Tag spielt einen ganzen Tag als Folge von Bildern ab.",
        "/waerme/wiedergabe": "Ein Tag spielt das Anlagenschema über einen ganzen Tag ab.",
        "/waerme/waermepumpe": "Wärmepumpe zeigt die Wärmepumpe allein, mit allem, was ihr eigener Bus meldet. Die Ansichten Betrieb und Kennlinie zeigen dieselbe Maschine über Tage und über Wochen.",
        "/waerme/waermepumpe/betrieb": "Betrieb zeigt die Läufe der Wärmepumpe über Tage: Laufzeiten, Abtauen, Takten und die Heizkurve des Reglers.",
        "/waerme/waermepumpe/kennlinie": "Kennlinie zeigt die gemessene Arbeitszahl der Wärmepumpe über Wochen.",
        "/waerme/waermepumpe/regler": "Regler zeigt, was am Regler der Wärmepumpe eingestellt ist: oben die Heizkurve als Kurve, darunter ein Pult. Was sich stellen lässt, lässt sich dort verstellen; was nicht, ist blass.",
        "/waerme/fahrplan": "Fahrplan zeigt den Plan voraus: Preisfenster, PV-Überschuss und wann die Wärmepumpe laufen soll. Die Ansicht Rückblick ist die Nachbetrachtung.",
        "/waerme/nachbetrachtung": "Rückblick zeigt einen vergangenen Tag in Euro: was der Fahrplan versprochen hat, was gehalten wurde und woran es lag.",
        "/waerme/wirkung": "Wirkung zeigt, ob die Wärmepumpe der Anforderung folgt und was das Verschieben gebracht hat.",
        "/waerme/regelkreis": "Regelkreis zeigt die ganze Regelung als Kaskade: fünf Ebenen von der Kostenrechnung bis in den einzelnen Raum, die Störgrößen am Ort ihrer Wirkung, und zu jedem Parameter, ob er gemessen, geschätzt oder angenommen ist. Dort steht auch, warum eine Schätzung noch nicht übernommen wurde, und dort lässt sich jeder Wert von Hand setzen. Nur mit Vollzugriff.",
        "/waerme/raeume": "Über den Tag zeigt die Raumtemperaturen und Heizkreise über den gewählten Zeitraum.",
        "/system": "Prognose zeigt, wie gut PV- und Verbrauchsprognosen waren. Nur mit Vollzugriff.",
        "/system/daten": "Daten prüfen zeigt, wie vollständig die Messreihen sind. Nur mit Vollzugriff.",
        "/waerme/annahmen": "Annahmen zeigt die Wärmeannahmen des Modells und lässt sie ändern. Nur mit Vollzugriff.",
        "/system/mitteilungen": "Mitteilungen stellt das Morning Briefing und die angemeldeten Geräte ein. Nur mit Vollzugriff.",
        "/system/haustuer": "Haustür zeigt die Zutritte an der Haustür. Nur mit Vollzugriff.",
        "/system/geraet": "Hausgerät zeigt, wie es dem Rechner im Haus und seinen Diensten geht, holt Protokolle, startet Dienste neu und installiert Updates. Nur mit Vollzugriff.",
        "/system/zugang": "Zugang und Sicherung verwaltet gekoppelte Geräte und die Sicherung. Nur mit Vollzugriff.",
    ]

    /// Wo man steht: Bereich, Reiter und der Text der Seite.
    public struct Ort: Sendable, Hashable {
        public let bereich: String
        public let reiter: String?
        public let text: String?
    }

    public static func ortBestimmen(_ weg: String) -> Ort {
        let sauber = saeubere(weg)
        let bereich = Bereiche.bereichVon(sauber)
        let reiter = Bereiche.reiterVon(bereich, sauber)
        let text = seiten[sauber] ?? reiter.flatMap { seiten[$0.weg] } ?? seiten[bereich.weg]
        return Ort(bereich: bereich.name, reiter: reiter?.name, text: text)
    }

    static func saeubere(_ weg: String) -> String {
        var s = weg
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s.isEmpty ? "/" : s
    }

    /// Die Wegbeschreibung: Bereiche, ihre Reiter und deren Ansichten, aus ``Bereiche/alle``.
    public static func wegweiser(_ bereiche: [Bereich] = Bereiche.alle) -> String {
        bereiche.map { b in
            guard !b.reiter.isEmpty else { return "\(b.name): eine Seite." }
            let reiter = b.reiter.map { r -> String in
                guard !r.unter.isEmpty else { return r.name }
                return "\(r.name) (Ansichten: \(r.unter.map(\.name).joined(separator: ", ")))"
            }
            return "\(b.name): \(reiter.joined(separator: ", "))."
        }
        .joined(separator: "\n")
    }

    /// Das Wissen für das Modell: wo gefragt wurde, was die Seite zeigt, der Aufbau.
    public static func wissen(weg: String) -> String {
        let ort = ortBestimmen(weg)
        let wo = ort.reiter.map { "Bereich \(ort.bereich), Reiter \($0)" } ?? "Bereich \(ort.bereich)"
        return [
            "Der Anwender steht gerade hier: \(wo).",
            ort.text ?? "",
            "Die Reiter eines Bereichs teilen sich den gewählten Zeitraum.",
            "AUFBAU DER ANWENDUNG:",
            wegweiser(),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    // MARK: - Der Gesprächsverlauf

    public struct Nachricht: Sendable, Hashable, Identifiable {
        public let id: UUID
        public let wer: AlfredWechselInWerWahl
        public let inhalt: String
        /// Trägt die KI-Marke. Vorbereitete Texte haben keine.
        public let ausModell: Bool
        /// Ein Verweis unter dem Text, etwa auf die volle Auswertung einer Rechnung.
        public let weg: String?

        public init(
            id: UUID = UUID(), wer: AlfredWechselInWerWahl, inhalt: String,
            ausModell: Bool = false, weg: String? = nil
        ) {
            self.id = id
            self.wer = wer
            self.inhalt = inhalt
            self.ausModell = ausModell
            self.weg = weg
        }
    }

    /// Höchstzahl der mitgesendeten Wechsel. Der Dienst kürzt auf seinen eigenen Wert; diese
    /// Schranke begrenzt nur die Übertragung.
    public static let verlaufMax = 10

    /// Der Gesprächsverlauf für den Dienst. Er lebt nur im Gerät und endet mit dem Blatt.
    public static func verlaufFuerDienst(_ nachrichten: [Nachricht]) -> [AlfredWechselIn] {
        nachrichten.suffix(verlaufMax).map { AlfredWechselIn(wer: $0.wer, inhalt: $0.inhalt) }
    }

    // MARK: - Vorschläge

    /// Beschriftung eines Vorschlags, ohne Zahlen zu erfinden: was steht, steht im Vorschlag.
    public static func vorschlagText(_ v: AlfredVorschlagOut) -> String {
        switch v.art {
        case .schalten:
            return "\(v.name) \(v.an == true ? "einschalten" : "ausschalten")"
        case .sollwert, .unbekannt:
            return "\(v.name): Soll \(gradzahl(v.alt)) → \(gradzahl(v.neu)) °C"
        }
    }

    /// Was genau sich ändert, für die Bestätigung: vorher und nachher, aus den Feldern des
    /// Vorschlags. Unbekanntes steht als „?" und wird nicht erraten.
    public static func vorschlagAenderung(_ v: AlfredVorschlagOut) -> String {
        switch v.art {
        case .schalten:
            let vorher = v.warAn == nil ? "?" : (v.warAn == true ? "ein" : "aus")
            return "\(v.name): \(vorher) → \(v.an == true ? "ein" : "aus")"
        case .sollwert, .unbekannt:
            return "\(v.name): Solltemperatur \(grad(v.alt)) → \(grad(v.neu))"
        }
    }

    static func gradzahl(_ x: Double?) -> String {
        guard let x else { return "?" }
        return Formate.zahl(x, stellen: x == x.rounded() ? 0 : 1)
    }

    static func grad(_ x: Double?) -> String {
        x == nil ? "?" : "\(gradzahl(x)) °C"
    }

    /// Was ein Vorschlag auf Knopfdruck wirklich tut.
    ///
    /// **Die einzige Stelle, an der aus der Ausgabe eines Sprachmodells eine Handlung am Haus
    /// wird** - darum steht sie im Kern, mit Tests, und nicht in einer Ansicht. Ausgefuehrt
    /// wird genau das hier, nicht was im Antworttext stand.
    ///
    /// `nil` heisst: nicht ausfuehrbar. Ein Vorschlag ohne brauchbares Ziel, ohne Zustand oder
    /// ohne neue Temperatur wird nicht geraten, sondern nicht angeboten.
    public enum Ausfuehrung: Sendable, Hashable {
        case schalten(schluessel: String, an: Bool)
        case sollwert(raum: Int, grad: Double)
    }

    public static func ausfuehrung(_ v: AlfredVorschlagOut) -> Ausfuehrung? {
        switch v.art {
        case .schalten:
            guard let schluessel = v.ziel.alsText, !schluessel.isEmpty, let an = v.an else {
                return nil
            }
            return .schalten(schluessel: schluessel, an: an)
        case .sollwert:
            // Die Raumkennung kommt als Zahl; manche Dienste schreiben sie als Text.
            let raum = v.ziel.alsZahl.map { Int($0) } ?? v.ziel.alsText.flatMap { Int($0) }
            guard let raum, let grad = v.neu else { return nil }
            return .sollwert(raum: raum, grad: grad)
        case .unbekannt:
            // Eine Art, die diese Fassung der App nicht kennt, wird nicht ausgefuehrt.
            return nil
        }
    }

    // MARK: - Die Schritte

    /// Der Satz zu einem Werkzeug. Bei einem unbekannten (Dienst neuer als App) der
    /// allgemeine statt eines rohen Bezeichners.
    public static func schrittText(_ werkzeug: String) -> String {
        schritte[werkzeug] ?? Texte.schrittAllgemein
    }

    static let schritte: [String: String] = [
        "jetzt": "Ich schaue auf den Augenblick …",
        "energiebilanz": "Ich hole die Strombilanz …",
        "waerme": "Ich schaue auf die Wärmepumpe …",
        "waermebilanz": "Ich hole die Wärmebilanz …",
        "verschiebung": "Ich prüfe, was das Verschieben gebracht hat …",
        "wallbox": "Ich schaue auf die Wallbox …",
        "pv_abrechnung": "Ich hole die PV-Abrechnung …",
        "nachbetrachtung": "Ich lese die Nachbetrachtung …",
        "fahrplan": "Ich lese den Fahrplan …",
        "waermepumpe": "Ich frage die Wärmepumpe …",
        "kontaktwirkung": "Ich prüfe, ob die Wärmepumpe folgt …",
        "raeume": "Ich schaue in die Räume …",
        "entscheidungen": "Ich lese die Entscheidungen des Reglers …",
        "prognoseguete": "Ich prüfe die Prognosen …",
        "tagesdiagnose": "Ich schlüssele den Tag auf …",
        "rechnungen": "Ich hole die Rechnungen …",
        "rechnung": "Ich lese die Rechnung …",
        "wochenrueckblick": "Ich stelle die Woche zusammen …",
        "leitfaden": "Ich lege mir den Weg zurecht …",
        "nachschlagen": "Ich schlage in den Methodenpapieren nach …",
        "schalten_vorschlagen": "Ich bereite einen Vorschlag vor …",
        "sollwert_vorschlagen": "Ich bereite einen Vorschlag vor …",
    ]

    // MARK: - Die Texte

    /// Alles, was Alfred sagt, an einer Stelle. Wortgleich mit `hilfetexte.ts`.
    public enum Texte {
        public static let name = "Alfred"
        public static let ansprechen = "Alfred fragen"
        public static let schliessen = "Schließen"
        public static let begruessung =
            "Hallo, ich bin Alfred. Ich erkläre, was du hier siehst, und beantworte Fragen zu deinem Haus."
        public static let seiteErklaeren = "Was zeigt diese Seite?"
        public static let wasKannAlfred = "Was kannst du?"
        public static let keineSeitenhilfe = "Zu dieser Seite habe ich noch keinen Hilfetext."
        public static let antwortWasKannAlfredOhneModell =
            "Im Moment erkläre ich die Seiten und sage, wo was steht. Eine Tibber-Rechnung kannst du als PDF schicken: Ich prüfe sie, lege sie ab und fasse das Ergebnis zusammen. Sobald ein Sprachmodell eingerichtet ist, beantworte ich auch Fragen zu deinen Daten."
        public static let antwortWasKannAlfred =
            "Ich beantworte Fragen zu deinen Daten: Verbrauch, Kosten, PV, Wärmepumpe, Speicher, Rechnungen, Prognosen. Ich vergleiche Zeiträume und mache einen Wochenrückblick. Lichter und Raumtemperaturen schlage ich vor. Geschaltet wird erst, wenn du den Vorschlag geprüft und mit OK bestätigt hast. Eine Stromrechnung kannst du als PDF schicken; Tibber-Rechnungen prüfe und lege ich ab, die anderer Anbieter lese ich. Ich rechne nichts selbst, die Zahlen kommen aus denselben Auswertungen wie auf den Seiten."
        public static let beispiele = [
            "Wie war die Woche?", "Warum war der letzte Monat teurer?",
            "Folgt die Wärmepumpe der Anforderung?",
        ]
        public static let frageFeld = "Frage an Alfred …"
        public static let frageSenden = "Fragen"
        public static let frageLaeuft = "Ich denke nach …"
        public static let frageFehler = "Das hat nicht geklappt. Versuch es bitte gleich noch einmal."
        public static let frageOhneModell = "Für Fragen ist noch kein Sprachmodell eingerichtet."
        public static let kiMarke = "KI-Antwort"
        public static let hinweisOhneModell =
            "Noch kein KI-Assistent: vorbereitete Texte, nichts verlässt das Haus."
        public static let schrittAllgemein = "Ich arbeite daran …"
        public static let vorschlagTitel = "Vorschläge, noch nicht ausgeführt"
        public static let bestaetigungTitel = "Wirklich ausführen?"
        public static let bestaetigungHinweis =
            "Das hat Alfred vorgeschlagen, ein KI-Assistent. Ausgeführt wird genau, was hier steht, nicht was in seiner Antwort steht. Im Protokoll erscheint es als „über Alfred“."
        public static let bestaetigungAbbrechen = "Abbrechen"
        public static let bestaetigungOk = "OK, ausführen"
        public static let vorschlagLaeuft = "Läuft …"
        public static let vorschlagFehler = "Das ließ sich nicht ausführen."
        // MARK: Sprechen
        //
        // **Die Ente gedrückt halten, sprechen, loslassen.** Dieselbe Geste wie im Dashboard,
        // wo sie seit dem 14.11.2026 steht. Was sie am Telefon anders macht: dort erkennt der
        // Browser und schickt die Aufnahme je nach Hersteller an Apple oder Google; hier
        // erkennt das Gerät, und bei einem Modell, das es kann, verlässt die Aufnahme das
        // Telefon nicht.
        public static let haltenLaeuft = "Ich höre zu … Lass die Ente los, wenn du fertig bist."
        public static let sprachWartet = "Einen Moment …"
        public static let sprachNichtsGehoert =
            "Ich habe nichts verstanden. Halte die Ente gedrückt, solange du sprichst, und lass dann los."
        public static let sprachNichtErlaubt =
            "Ich darf Mikrofon oder Spracherkennung nicht benutzen. Erlaube beides in den Einstellungen unter Duck Curve, oder tipp deine Frage ins Feld."
        /// Der Finger war schneller als der Erlaubnisdialog - beim ersten Mal immer.
        public static let sprachJetztErlaubt =
            "Jetzt darf ich zuhören. Halte die Ente noch einmal gedrückt und sprich."
        public static let sprachNichtAngelaufen =
            "Ich konnte nicht zuhören. Versuch es noch einmal, oder tipp deine Frage ins Feld."
        public static let sprachKeineSprache =
            "Für Deutsch ist auf diesem Gerät keine Spracherkennung eingerichtet. Tipp deine Frage ins Feld."
        public static let sprachFehler =
            "Die Spracherkennung hat nicht geklappt. Tipp deine Frage ins Feld."

        // MARK: Die Ente verschieben
        //
        // **Drei Gesten auf einem Zeichen, und die Worte müssen sie auseinanderhalten.** Tippen
        // öffnet, Halten spricht, Ziehen verschiebt - siehe ``Entenplatz`` für die Stellen und
        // ``Entenknopf`` für die Grenze zwischen Halten und Ziehen.

        /// Was VoiceOver an der Ente sagt, wenn der Hinweis gelesen wird.
        ///
        /// **Er nennt die Aktionen und nicht die Finger.** Vorher stand hier „Ente gedrückt
        /// halten, sprechen, loslassen“ - eine Anleitung für eine Geste, die mit eingeschaltetem
        /// VoiceOver niemand ausführt, und seit dem Verschieben auch keine vollständige mehr.
        /// Erreichbar ist für die Bedienungshilfe, was unter den Aktionen steht.
        public static let enteHinweis =
            "Doppeltippen fragt Alfred. Mit den Aktionen lässt sich die Ente an eine andere Stelle setzen."

        /// Was unter den Aktionen steht: ein Schritt weiter am Rand entlang
        /// (``Entenplatz/naechste(nach:)``).
        public static let enteVerschieben = "Ente weitersetzen"

        /// Und der Weg zurück - an der Ente selbst und als Knopf im Blatt.
        public static let enteZurueck = "Ente zurücksetzen"

        /// Wo sie steht, als Wert des Elements: „steht unten rechts“.
        public static func enteStelle(_ name: String) -> String { "steht \(name)" }

        public static let rechnungKnopf = "Rechnung prüfen (PDF)"
        public static let rechnungZurAuswertung = "Zur vollen Auswertung"
        public static let rechnungKeinPdf = "Das war keine PDF-Datei. Schick mir bitte eine Rechnung als PDF."
        public static let rechnungLaeuft = "Ich lese die Rechnung …"
        public static let rechnungHinweisOhneModell =
            "Tibber-Rechnungen prüft der Dienst selbst und legt sie ab, nichts verlässt das Haus. Rechnungen anderer Anbieter brauchen ein Sprachmodell."

        /// Der Hinweis mit dem Namen des Anbieters. **Er ist keine Zierde:** Artikel 50 der
        /// KI-Verordnung verlangt, dass erkennbar ist, dass hier ein KI-System antwortet.
        public static func hinweisModell(anbieter: String) -> String {
            "KI-Assistent (\(anbieter)). Er kann irren. Für Fragen gehen Zahlen deines Hauses an \(anbieter), keine Alarm-, Tür- oder Standortdaten. Er schaltet nichts ohne deine Bestätigung."
        }

        public static func rechnungHinweis(anbieter: String) -> String {
            "Tibber-Rechnungen prüft der Dienst selbst und legt sie ab, nichts verlässt das Haus. Bei anderen Anbietern gehen nur Zeilen mit Mengen, Preisen und Zeiträumen an \(anbieter); Namen, Anschrift, Kunden- und Zählernummern und IBAN sind geschwärzt, gespeichert wird nichts."
        }
    }

    /// Der Hinweis unter dem Gespräch, je nachdem, ob ein Modell eingerichtet ist.
    public static func hinweis(_ zustand: AlfredZustandOut?) -> String {
        guard let zustand, zustand.bereit, let anbieter = zustand.anbieter, !anbieter.isEmpty
        else { return Texte.hinweisOhneModell }
        return Texte.hinweisModell(anbieter: anbieter)
    }

    /// Die Antwort auf „Was kannst du?" – sie hängt davon ab, ob ein Modell da ist.
    public static func antwortWasKannAlfred(_ zustand: AlfredZustandOut?) -> String {
        zustand?.bereit == true ? Texte.antwortWasKannAlfred : Texte.antwortWasKannAlfredOhneModell
    }

    /// Die Antwort auf „Was zeigt diese Seite?" – ein vorbereiteter Text, kein Modell.
    public static func antwortSeite(weg: String) -> String {
        ortBestimmen(weg).text ?? Texte.keineSeitenhilfe
    }
}

/// Ein Fortschrittsereignis des Stroms: nur der Name des Werkzeugs.
///
/// Steht hier und nicht in `Schema.swift`: der Ereignisrumpf eines `text/event-stream` ist
/// kein Antworttyp eines Weges und kommt im OpenAPI-Papier darum nicht vor.
struct AlfredSchritt: Decodable, Sendable {
    let werkzeug: String
}
