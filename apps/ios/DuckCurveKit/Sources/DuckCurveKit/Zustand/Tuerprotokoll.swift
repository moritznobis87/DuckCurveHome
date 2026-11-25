import Foundation

/// Das Türprotokoll: wer sich am Reader erkennen ließ, und was geschah.
///
/// **Warum die Worte hier stehen und nicht in der Ansicht.** Dieselbe Begründung wie bei
/// ``Raumprotokoll``: „FACE“ zu „Gesicht“ zu machen ist keine Gestaltung, sondern eine
/// Entscheidung darüber, was ein Mensch liest - und eine Entscheidung in einer `View` lässt
/// sich unter Linux nicht prüfen. Der Kommentar der Vorlage sagt es in einem Satz: „„FACE“ ist
/// der Wert der Konsole. Auf einer Seite, die man liest, steht „Gesicht“.“
/// (`apps/web/src/components/settings/DoorLog.tsx:37`).
///
/// ## Der Zustand kommt aus `outcome` und nie aus `granted`
///
/// Das ist die Hauptsache dieser Datei. `granted` ist die Entscheidung der Zutrittskonsole -
/// und sie ist nicht das Ende der Kette. Danach lehnt die Bridge selbst noch ab
/// (Wiederholsperre, nicht freigegebene Tür, Person oder Verfahren,
/// `packages/hems-core/src/hems_core/control/door_access.py:117-149`), oder das Schloss
/// reagiert nicht (`apps/bridge/src/dch_bridge/door.py:101-109`). In beiden Fällen steht
/// `granted` auf „ja“ (`door.py:144`, gelesen in
/// `apps/api/src/dch_api/routers/system.py:212`) und die Tür ist zu. Wer `granted` zählt,
/// zählt abgelehnte und fehlgeschlagene Versuche als Öffnungen und widerspricht damit dem
/// Satz des Dienstes, der über `outcome == "geöffnet"` zählt (`system.py:189`).
///
/// Die Vorlage liest `granted` darum gar nicht: gesucht nach `granted` in `DoorLog.tsx` -
/// Treffer nur in der Typeinfuhr (`:6`). Der Zustand einer Zeile kommt dort allein aus
/// `outcome` (`:60-61`, `:70`).
///
/// **Und ein Fehlschlag ist nicht eine Ablehnung.** Der Kommentar der Vorlage hält den
/// Unterschied ausdrücklich fest (`DoorLog.tsx:68-69`): „dort hat das Haus nein gesagt, hier
/// hat das Schloss nicht reagiert. Nur das zweite ist ein Defekt.“ Deshalb hat
/// ``Zustandston`` drei Fälle und nicht zwei.
public enum Tuerprotokoll {

    // MARK: - Die Worte der Seite

    /// Der Satz unter dem Titel der Karte, wie im Dashboard (`DoorLog.tsx`, `TUERSATZ`).
    ///
    /// Seit dem 25.11.2026 steht nur noch dieser Satz da: Der Hausherr wollte auf den
    /// Systemseiten keine langen Erklärtexte mehr. Einleitung und Nachsatz über die
    /// Erlaubnisliste und die Namen im Klartext sind weggefallen.
    public static let kartensatz = "Zutritte und abgewiesene Versuche am Reader."

    /// Was dasteht, solange die erste Antwort unterwegs ist (`DoorLog.tsx:119`).
    ///
    /// **Ein Absatz und kein Kasten.** Die Vorlage setzt `data` bei jedem Wechsel der Spanne
    /// erst auf `null` (`:85`); während der neuen Abfrage ist die Liste weg und an ihrer
    /// Stelle steht dieser Satz. Ein leerer Kasten mit einem Wort darin behauptete, es gebe
    /// schon etwas zu sehen.
    public static let ladesatz = "lädt …"

    /// Was in einer Zeile steht, wenn der Dienst keinen Namen mitgeschickt hat.
    ///
    /// Möglich ist das: `_door_fields` setzt leere Felder, statt die Abfrage scheitern zu
    /// lassen (`system.py:196-213`). Die Vorlage schreibt `e.actor || "unbekannt"`
    /// (`DoorLog.tsx:65`).
    public static let namenlos = "unbekannt"

    /// Die wählbaren Spannen in Tagen (`DoorLog.tsx:22`).
    ///
    /// **Sieben, vierzehn, dreißig - und nicht neunzig.** Die App bot bis zum 20.11.2026
    /// 7/30/90 an. Neunzig Tage sind bis zu 500 Zeilen (`MAX_DOOR_ENTRIES`, `system.py:164`);
    /// das ist keine Auskunft mehr, sondern ein Stapel. Vierzehn Tage fehlten dagegen ganz,
    /// obwohl sie die Vorgabe sind.
    public static let spannen = [7, 14, 30]

    /// Die Spanne, mit der die Seite aufgeht (`DoorLog.tsx:80`) - dieselbe, die der Dienst
    /// ohne Frage annimmt (`system.py:169`, `days: int = 14`).
    public static let vorgabe = 14

    /// Die Überschrift einer Tagesgruppe, wenn der Zeitstempel unlesbar ist.
    ///
    /// **Warum dieser Fall überhaupt vorkommt.** Das Protokoll kann älter sein als die Fassung,
    /// die es liest (`system.py:196-201`), und ein Eintrag ohne lesbaren Stempel soll nicht
    /// verschwinden: wer die Zahl im Satz des Dienstes nachzählt, soll dieselbe Zahl Zeilen
    /// finden. Die Vorlage schreibt an dieser Stelle „Invalid Date“ - das ist ein Werkzeugname
    /// und keine Auskunft.
    public static let ohneDatum = "ohne Datum"

    // MARK: - Das Verfahren als Wort

    /// „FACE“ → „Gesicht“, „NFC“ → „Karte“, „PIN“ → „Code“, „MOBILE_TAP“/„BT“ → „Telefon“.
    ///
    /// Verglichen wird in Großbuchstaben, damit die Schreibweise der Konsole nichts entscheidet
    /// (`DoorLog.tsx:38-46`). Ein unbekanntes Verfahren steht roh da, aber getrimmt: lieber der
    /// Wert der Konsole als nichts, denn er beantwortet die Frage „wie denn?“ immer noch
    /// halbwegs. Bleibt nach dem Trimmen nichts übrig, steht dort ``namenlos``.
    public static func verfahrenWort(_ verfahren: String) -> String {
        let roh = verfahren.trimmingCharacters(in: .whitespacesAndNewlines)
        switch roh.uppercased() {
        case "FACE": return "Gesicht"
        case "NFC": return "Karte"
        case "PIN": return "Code"
        case "MOBILE_TAP", "BT": return "Telefon"
        default: return roh.isEmpty ? namenlos : roh
        }
    }

    /// „per Gesicht“ - das Verfahren, wie es in der Zeile steht (`DoorLog.tsx:66`).
    ///
    /// Das Wörtchen gehört hierher und nicht in die Ansicht: eine Zeichenkette, die aus zwei
    /// Teilen zusammengesetzt wird, ist eine Textauswahl und keine Gestaltung.
    public static func verfahrenSatz(_ verfahren: String) -> String {
        "per " + verfahrenWort(verfahren)
    }

    /// Der Name in der Zeile, oder ``namenlos`` (`DoorLog.tsx:65`).
    ///
    /// **Nicht getrimmt**, anders als ``verfahrenWort(_:)``. Die Vorlage prüft mit `||` auf die
    /// leere Zeichenkette und nicht auf Leerzeichen, und der Name ist der eines Menschen: „ Anna“
    /// bliebe „ Anna“. Beim Verfahren entscheidet dagegen ein Vergleich, und dort wäre ein
    /// Leerzeichen der Unterschied zwischen „Gesicht“ und „FACE “.
    public static func name(_ actor: String) -> String {
        actor.isEmpty ? namenlos : actor
    }

    // MARK: - Der Zustand

    /// Wie eine Zeile ausgegangen ist - der einzige Zustand, den die Seite kennt.
    public enum Zustandston: Sendable, Hashable {
        /// Die Tür ging auf (`door.py:114`).
        case geoeffnet
        /// Das Haus hat nein gesagt (`door.py:98`).
        case abgelehnt
        /// Das Haus hat ja gesagt und das Schloss hat nicht reagiert (`door.py:108`). **Nur das
        /// ist ein Defekt** (`DoorLog.tsx:68-69`).
        case fehlgeschlagen
    }

    /// Der Ton einer Zeile, genau nach `outcome` (`DoorLog.tsx:60-61`).
    ///
    /// **Alles, was nicht „geöffnet“ oder „fehlgeschlagen“ heißt, ist eine Ablehnung** - so
    /// rechnet die Vorlage, die nur diese beiden abfragt und den Rest neutral stellt (`:70`).
    /// Das trifft „abgelehnt“ (`door.py:99`) und den Rückfall „unbekannt“ eines Eintrags aus
    /// einer früheren Fassung der Bridge (`system.py:211`). Richtig ist das, weil eine
    /// unbekannte Zeile eben keine Öffnung belegt und auch keinen Defekt.
    public static func ton(_ outcome: String) -> Zustandston {
        if outcome == "fehlgeschlagen" { return .fehlgeschlagen }
        if outcome == "geöffnet" { return .geoeffnet }
        return .abgelehnt
    }

    /// Die Begründung der Zeile - oder `nil`, wenn sie nichts hinzufügt (`DoorLog.tsx:72-74`).
    ///
    /// **Bei einer geglückten Öffnung steht sie nicht da**, und das ist kein Platzsparen: dort
    /// ist `reason` der Satz „{actor} an „{door}“ per {method}.“
    /// (`door_access.py:149`) und damit die Zeile selbst noch einmal. Bei einer Ablehnung oder
    /// einem Fehlschlag ist sie dagegen das Einzige, was sagt, *warum* - und dann steht sie in
    /// einer eigenen Zeile darunter.
    public static func begruendung(_ eintrag: DoorEntryOut) -> String? {
        guard ton(eintrag.outcome) != .geoeffnet, !eintrag.reason.isEmpty else { return nil }
        return eintrag.reason
    }

    // MARK: - Nach Tagen gruppiert

    /// Ein Kalendertag des Protokolls mit seinen Zeilen.
    public struct Tagesgruppe: Sendable, Hashable, Identifiable {
        /// Der Kalendertag der Hauszeit, `YYYY-MM-DD` - leer, wo der Zeitstempel unlesbar war.
        public let tag: String
        /// Was über der Gruppe steht: „Heute“, „Gestern“, sonst das lange Datum.
        public let wort: String
        public let eintraege: [DoorEntryOut]

        /// Nicht der Tag allein: käme das Protokoll je unsortiert, stünde derselbe Tag zweimal,
        /// und zwei gleiche Schlüssel sind in einer `ForEach` ein stiller Fehler.
        public var id: String { tag + "|" + (eintraege.first?.at ?? "") }
    }

    /// Die Einträge nach Kalendertagen, in der gelieferten Reihenfolge.
    ///
    /// **Warum gruppiert wird**, in den Worten der Vorlage (`DoorLog.tsx:18-20`): „weil man so
    /// hineinsieht: nicht „der 412. Eintrag“, sondern „gestern Abend“.“ Die App zeigte bis zum
    /// 20.11.2026 eine flache Liste, deren einzige Zeitangabe „07:12“ war - bei neunzig Tagen
    /// bis zu 500 Zeilen ohne Tag untereinander.
    ///
    /// **Nicht sortiert, nur zusammengefasst.** Verglichen wird allein mit der *letzten*
    /// Gruppe, genau wie `groupByDay` (`:48-57`): die Reihenfolge kommt vom Dienst, jüngster
    /// Eintrag zuerst (`system.py:173`), und die soll sie behalten. Eine eigene Sortierung
    /// hier wäre eine zweite Meinung darüber, was „jüngster“ heißt.
    ///
    /// **Der Tag ist der der Hauszeit und nicht der des Geräts.** Das ist eine bewusste
    /// Abweichung: die Vorlage gruppiert über `new Date(e.at).toDateString()`, also in der
    /// Zeitzone des Browsers. Dieses Paket rechnet durchweg in der Zeit des Hauses, mit der
    /// Begründung an ``Kalender/haus`` - wer aus dem Urlaub nachsieht, will wissen, wann jemand
    /// *dort* vor der Tür stand. Sonst wanderte ein Zutritt um 00:30 für den Urlauber in den
    /// Vortag.
    public static func gruppen(_ eintraege: [DoorEntryOut], jetzt: Date = Date())
        -> [Tagesgruppe]
    {
        var tage: [String] = []
        var zeilen: [[DoorEntryOut]] = []
        for e in eintraege {
            let tag = Zeit.ausIso(e.at).map(Tag.iso) ?? ""
            if tage.last == tag {
                zeilen[zeilen.count - 1].append(e)
            } else {
                tage.append(tag)
                zeilen.append([e])
            }
        }
        return zip(tage, zeilen).map {
            Tagesgruppe(tag: $0, wort: tagwort($0, jetzt: jetzt), eintraege: $1)
        }
    }

    /// „Heute“, „Gestern“, sonst „Montag, 3. November“ (`DoorLog.tsx:24-32`).
    ///
    /// **„Morgen“ kommt hier nicht vor**, obwohl ``Tag/nameRelativ(_:jetzt:)`` es kennt: die
    /// Vorlage vergleicht nur mit heute und gestern, und ein Zutritt von morgen gibt es nicht -
    /// die Abfrage reicht von `jetzt - Spanne` bis jetzt (`system.py:185`). Stünde dort je
    /// „Morgen“, wäre das eine falsche Auskunft über eine kaputte Uhr und kein Datum.
    public static func tagwort(_ tag: String, jetzt: Date = Date()) -> String {
        let relativ = Tag.nameRelativ(tag, jetzt: jetzt)
        if relativ == "Heute" || relativ == "Gestern" { return relativ ?? tag }
        guard let zeitpunkt = Tag.date(tag) else { return ohneDatum }
        return Formate.langesDatum(zeitpunkt)
    }

    // MARK: - Die Zählung

    /// Wie viele Versuche wie ausgingen - gezählt über `outcome`.
    public struct Zaehlung: Sendable, Hashable {
        public let geoeffnet: Int
        public let abgelehnt: Int
        public let fehlgeschlagen: Int

        public init(geoeffnet: Int, abgelehnt: Int, fehlgeschlagen: Int) {
            self.geoeffnet = geoeffnet
            self.abgelehnt = abgelehnt
            self.fehlgeschlagen = fehlgeschlagen
        }
    }

    /// Die drei Zahlen der Seite.
    ///
    /// Gezählt wird über ``ton(_:)`` und damit über `outcome` - die Begründung steht im Kopf
    /// dieser Datei. Die Zahl „geöffnet“ ist danach dieselbe, die der Satz des Dienstes nennt
    /// (`system.py:189`); vorher war sie es nicht.
    public static func zaehlung(_ eintraege: [DoorEntryOut]) -> Zaehlung {
        var geoeffnet = 0
        var abgelehnt = 0
        var fehlgeschlagen = 0
        for e in eintraege {
            switch ton(e.outcome) {
            case .geoeffnet: geoeffnet += 1
            case .abgelehnt: abgelehnt += 1
            case .fehlgeschlagen: fehlgeschlagen += 1
            }
        }
        return Zaehlung(
            geoeffnet: geoeffnet, abgelehnt: abgelehnt, fehlgeschlagen: fehlgeschlagen)
    }

    /// Ob eine Zahl der Kopfzeile Aufmerksamkeit verlangt.
    ///
    /// **Warum die Schwelle hier steht und nicht in der Ansicht.** „Mehr als null“ ist eine
    /// Rechnung, auch wenn sie kurz ist - und sie entscheidet, ob eine Kachel gefärbt dasteht.
    /// Welche Farbe daraus wird, entscheidet die Oberfläche; die vorhandene Zuordnung von Ton
    /// zu Farbe (``Kennzahl/Ton``) kennt keinen Alarm, und darum hat diese Seite ihre eigene
    /// kleine Stufung.
    public enum Hervorhebung: Sendable, Hashable {
        /// Textfarbe, wie jede andere Zahl.
        case keine
        /// Es wurde jemand abgewiesen - genau die Frage, wegen der man hineinsieht.
        case achtung
        /// Das Schloss hat nicht reagiert. Das ist ein Defekt (`DoorLog.tsx:68-69`).
        case alarm
    }

    /// Eine Zahl der Kopfzeile mit ihrem Wort und ihrer Stufe.
    public struct Kachelwert: Sendable, Hashable, Identifiable {
        public let wort: String
        public let wert: String
        public let hervor: Hervorhebung

        public var id: String { wort }

        public init(wort: String, wert: String, hervor: Hervorhebung) {
            self.wort = wort
            self.wert = wert
            self.hervor = hervor
        }
    }

    /// Die drei Kacheln über dem Protokoll.
    ///
    /// **Die Vorlage hat sie nicht**, und das ist hier Absicht statt Versehen: sie zählt im Satz
    /// des Dienstes nur Ereignisse und Öffnungen (`system.py:189`). Auf einem Telefon, das die
    /// Liste nur in Ausschnitten zeigt, beantworten drei Zahlen die Frage der Seite vor dem
    /// Rollen - und die dritte, „fehlgeschlagen“, trennt den Defekt von der Ablehnung, worauf
    /// der Kommentar der Vorlage ausdrücklich Wert legt (`DoorLog.tsx:68-69`).
    ///
    /// Die Zahl bleibt auch bei null stehen: eine Kachel, die verschwindet, sobald sie null
    /// sagt, lässt offen, ob nichts war oder nichts gezählt wurde.
    public static func kacheln(_ eintraege: [DoorEntryOut]) -> [Kachelwert] {
        let z = zaehlung(eintraege)
        return [
            Kachelwert(wort: "Öffnungen", wert: String(z.geoeffnet), hervor: .keine),
            Kachelwert(
                wort: "abgewiesen", wert: String(z.abgelehnt),
                hervor: z.abgelehnt > 0 ? .achtung : .keine),
            Kachelwert(
                wort: "fehlgeschlagen", wert: String(z.fehlgeschlagen),
                hervor: z.fehlgeschlagen > 0 ? .alarm : .keine),
        ]
    }
}
