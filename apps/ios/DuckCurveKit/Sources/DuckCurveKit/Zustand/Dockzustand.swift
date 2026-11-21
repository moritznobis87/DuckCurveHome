import Foundation

/// Was das Dock zeigt und was es sagt: welche Knöpfe dastehen, in welcher Farbe, und wie lange
/// eine Rückmeldung bleibt.
///
/// **Warum das im Kern steht.** Es sind vier Entscheidungen über Inhalt, und jede davon stand
/// bisher in der `View` oder nirgends: ob der Ofenknopf überhaupt dasteht (`Dock.tsx:240`:
/// `stove?.present`), ob der Alarmknopf dasteht (`:242`: `alarm?.present`), welche Farbe die
/// Anlage trägt (`:248`: bei Stufe 4 `--alert`, sonst `--mist`) und wie lange die Zeile über dem
/// Dock stehen bleibt (`:185-189,210`: vier Sekunden, bei einem Fehler acht). An einer
/// Wandanzeige ist das letzte kein Geschmack: ohne Frist stand dort „Kaffeemaschine an“ bis zum
/// nächsten Tippen, also Stunden.
///
/// **Die Sätze des Alarmblatts gehören dazu.** Sie kommen von nirgends her - sie stehen in der
/// Vorlage im Quelltext (`Dock.tsx:167-172`), und der wichtigste von ihnen ist eine Begründung
/// und keine Beschriftung (`Dock.tsx:121-127`: „ihr Zugang ist ein Sitzungskeks auf einem Gerät -
/// genug, um eine Anlage scharf zu schalten, zu wenig, um sie abzuschalten“). Dieselbe Wahl
/// trifft ``Mitteilungsstand`` für die Mitteilungsseite.
public enum Dockzustand {

    // MARK: - Die Rückmeldung über dem Dock

    /// Wie lange eine gelungene Schaltung über dem Dock steht (`Dock.tsx:185`: `ms = 4000`).
    public static let meldefrist: TimeInterval = 4

    /// Und wie lange eine gescheiterte (`Dock.tsx:210`: `8000`).
    ///
    /// Doppelt so lang, weil sie doppelt so viel sagt: ein Fehlersatz nennt den Grund, und wer
    /// im Vorbeigehen tippt, braucht länger, um ihn zu lesen, als für „Kaffeemaschine an“.
    public static let fehlerfrist: TimeInterval = 8

    /// Die Frist zur Meldung.
    public static func frist(fehler: Bool) -> TimeInterval {
        fehler ? fehlerfrist : meldefrist
    }

    /// Was dasteht, wenn ein Gast tippt (`Dock.tsx:197`).
    public static let gastzugang = "Gastzugang · nur Ansicht"

    // MARK: - Welche Knöpfe dastehen

    /// Den Ofen gibt es nicht in jedem Haus (`Dock.tsx:240`).
    ///
    /// **`present` und nicht „der Dienst nennt einen Ofen“.** Der Dienst liefert den Abschnitt
    /// auch in einem Haus ohne Ofen, dann mit `present: false` - die App prüfte bisher nur, ob
    /// der Abschnitt da ist, und stellte damit einen Ofenknopf in Häuser, die keinen haben.
    public static func zeigtOfen(_ ofen: StoveLiveOut?) -> Bool {
        ofen?.present == true
    }

    /// Und die Alarmanlage auch nicht (`Dock.tsx:242`).
    public static func zeigtAlarm(_ alarm: AlarmOut?) -> Bool {
        alarm?.present == true
    }

    // MARK: - Die Alarmanlage

    /// Die Stufe, bei der die Anlage ausgelöst hat (`Dock.tsx:248`: `alarm.state === 4`).
    public static let ausgeloest: Double = 4

    /// Ob der Alarmknopf leuchtet: scharf ist jede Stufe über null (`Dock.tsx:247`).
    public static func alarmLeuchtet(_ alarm: AlarmOut?) -> Bool {
        guard let s = alarm?.state else { return false }
        return s > 0
    }

    /// Die Farbe des Alarmknopfs: „Die Alarmanlage leuchtet, wenn sie scharf ist - rot nur, wenn
    /// sie ausgelöst hat“ (`Dock.tsx:241`).
    public static func alarmfarbe(_ alarm: AlarmOut?) -> Farbwert {
        alarm?.state == ausgeloest ? Marken.alarm : Marken.mist
    }

    /// Ob überhaupt geschärft werden kann: der Dienst muss es anbieten *und* dieses Gerät darf
    /// schalten (`Dock.tsx:146`: `disabled={busy || disabled || !alarm.can_arm}`).
    public static func darfSchaerfen(_ alarm: AlarmOut?, darfSchalten: Bool) -> Bool {
        darfSchalten && alarm?.canArm == true
    }

    /// Welcher Hinweis unter den beiden Knöpfen steht - und keiner, wenn alles in Ordnung ist.
    ///
    /// **Die Reihenfolge der Vorlage** (`Dock.tsx:171-172`): erst der Gastzugang, dann die
    /// Erreichbarkeit. Ein Gast soll nicht „Gerade nicht erreichbar“ lesen und die Anlage für
    /// gestört halten - für ihn ist sie es nicht, er darf nur nicht.
    public static func alarmhinweis(_ alarm: AlarmOut?, darfSchalten: Bool) -> String? {
        if !darfSchalten { return nurAnsicht }
        if alarm?.canArm != true { return nichtErreichbar }
        return nil
    }

    /// Der Satz, der sagt, warum es keinen Knopf zum Entschärfen gibt (`Dock.tsx:167-170`).
    ///
    /// **Er wird nicht gekürzt.** Ohne den zweiten Halbsatz liest sich der erste als Lücke, und
    /// wer eine Lücke vermutet, sucht. Die Begründung steht in `Dock.tsx:121-127` und im Kern
    /// an ``AlarmOut`` noch einmal: die Anzeige hängt in der Küche, Gäste gehen daran vorbei,
    /// und ihr Zugang ist ein Sitzungskeks auf einem Gerät.
    public static let nurScharf =
        "Unscharf wird am Bedienteil geschaltet, nicht hier. Diese Anzeige hängt in der Küche, "
        + "und wer an ihr vorbeigeht, soll eine Alarmanlage einschalten können, nicht "
        + "ausschalten."

    /// „Nur Ansicht: dieses Gerät schaltet nichts.“ (`Dock.tsx:171`)
    public static let nurAnsicht = "Nur Ansicht: dieses Gerät schaltet nichts."

    /// „Gerade nicht erreichbar.“ (`Dock.tsx:172`)
    public static let nichtErreichbar = "Gerade nicht erreichbar."

    /// Was dasteht, wenn das Schärfen keine Bestätigung bekommt (`Dock.tsx:139`).
    public static let nichtBestaetigt = "Die Anlage hat nicht bestätigt."

    /// Die beiden Knöpfe des Blatts, in der Reihenfolge der Vorlage (`Dock.tsx:164-165`).
    ///
    /// „Zu Hause“ zuerst: es ist die häufigere der beiden: abends scharf stellen und im Haus
    /// bleiben. „Unterwegs“ ist die Ausnahme, und sie steht rechts.
    public static let scharfknoepfe: [Scharfknopf] = [
        Scharfknopf(wort: "Zu Hause", art: .daheim),
        Scharfknopf(wort: "Unterwegs", art: .fort),
    ]

    /// Ein Knopf des Alarmblatts: das Wort und die Art, die der Dienst dafür kennt.
    public struct Scharfknopf: Sendable, Hashable, Identifiable {
        public let wort: String
        public let art: Api.AlarmArt

        public var id: String { art.rawValue }

        public init(wort: String, art: Api.AlarmArt) {
            self.wort = wort
            self.art = art
        }
    }
}
