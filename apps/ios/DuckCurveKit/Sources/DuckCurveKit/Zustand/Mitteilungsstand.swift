import Foundation

/// Was die Seite „Mitteilungen“ sagt: der Stand je Gerät, das Zählwort und die Sätze dazu.
///
/// **Warum das im Kern steht und nicht in der Seite.** Die Vorlage entscheidet den Satz unter
/// einem Gerätenamen in vier Stufen und färbt die Zeile danach
/// (`apps/web/src/components/settings/Mitteilungen.tsx:64-71`). Das ist keine Darstellung,
/// sondern eine Auskunft: welche der vier Stufen gilt, entscheidet, ob der Hausherr nachsieht
/// oder beruhigt weitergeht. Bis zum 12.11.2026 stand an dieser Stelle „an 0 von 1 Geräten
/// zugestellt“, und *warum*, stand nur im Protokoll des Dienstes - der Kommentar der Vorlage
/// nennt den Tag, an dem im Haus keine einzige Mitteilung ankam (`Mitteilungen.tsx:24-27`).
/// Eine Stufenwahl, die so viel trägt, gehört an eine Stelle, an der sie geprüft werden kann,
/// und nicht in eine `View`, die nur ein Mac übersetzt.
///
/// **Die festen Sätze stehen aus demselben Grund hier.** Sie kommen von nirgends her - sie
/// stehen in der Vorlage im Quelltext (`Mitteilungen.tsx:190-193`, `:257-260`, `:269-275`,
/// `Morgenbrief.tsx:68-71`, `:99-103`). Irgendwo müssen sie wohnen, und hier liegen sie neben
/// der Rechnung, die sie auswählt; dasselbe tut ``Wiedergabeworte`` für die Wiedergabeseite.
public enum Mitteilungsstand {

    // MARK: - Die Karte „Mitteilungen“

    /// Der Kicker der ersten Karte (`Mitteilungen.tsx:189`).
    ///
    /// Die App nannte sie „Dieses Gerät“ (`MitteilungenSeite.swift:60` vor dem Umbau). Das ist
    /// enger als die Karte: in ihr steht auch, welche *anderen* Geräte angemeldet sind.
    public static let kicker = "Mitteilungen"

    /// Der Satz unter dem Titel der Karte, wie im Dashboard (`Mitteilungen.tsx`, `MITTEILUNGEN`).
    ///
    /// Seit dem 25.11.2026 kurz: Der Hausherr wollte auf den Systemseiten keine langen
    /// Erklärtexte mehr. Die Fußnote, was „angenommen“ heißt, ist mit weggefallen; die Antwort der
    /// Probe sagt es selbst.
    public static let erklaerung = "Störungen und das Morning Briefing auf die angemeldeten Geräte."

    // MARK: - Die Lage dieses Geräts

    /// Wie es um die Mitteilungen auf *diesem* Gerät steht.
    ///
    /// **Das Gegenstück zu `PushLage` der Vorlage** (`apps/web/src/lib/push/lage.ts:13-21`),
    /// um die Fälle beschnitten, die es in einer App vom Home-Bildschirm nicht gibt: `ios-browser`
    /// und `geht-nicht` beschreiben einen Browser (`Mitteilungen.tsx:196-211`), und diese App
    /// *ist* die Home-Bildschirm-App und geht über APNs
    /// (`apps/ios/DuckCurveHome/Mitteilungen/Mitteilungen.swift:8-24`).
    ///
    /// Dafür hat sie zwei Fälle, die die Vorlage nicht hat: ``halb`` - erlaubt, aber der Dienst
    /// kennt das Gerätetoken noch nicht - und ``fehler``, vor allem für die fehlende
    /// Push-Berechtigung einer unbezahlt signierten Fassung (`Mitteilungen.swift:114-130`). Die
    /// gehören einem Gerätetoken an und haben im Browser kein Gegenstück.
    public enum Lage: Sendable, Hashable {
        /// Noch nicht gefragt - wie `aus` der Vorlage.
        case aus
        /// Der Benutzer hat abgelehnt - wie `verboten` der Vorlage.
        case verboten
        /// Erlaubt, aber beim Dienst noch nicht angekommen.
        case halb
        /// Angemeldet, der Dienst kennt dieses Gerät.
        case an
        /// Die Anmeldung ist gescheitert; der Satz kommt vom System oder vom Dienst.
        case fehler(String)
    }

    /// Der Satz zur Lage, und ob er ein Warnsatz ist.
    ///
    /// `warnt` entscheidet die Farbe: die Vorlage warnt auf dieser Seite durchweg in
    /// `--amber-soft` (`Mitteilungen.tsx:214`) und bestätigt in `--pv` (`:228`). Welcher von
    /// beiden gilt, ist hier gerechnet und nicht in der Ansicht abgefragt - sonst stünde die
    /// Zuordnung an zwei Stellen und nirgends ein Test.
    public struct Lagesatz: Sendable, Hashable {
        /// Was dasteht; `nil`, wenn zur Lage nur ein Knopf gehört und kein Satz.
        public let satz: String?
        /// `true` → Warnton (`--amber-soft`), `false` → Bestätigung (`--pv`).
        public let warnt: Bool

        public init(satz: String?, warnt: Bool) {
            self.satz = satz
            self.warnt = warnt
        }
    }

    /// Der Satz unter der Erklärung, je Lage.
    ///
    /// Bei ``Lage/aus`` steht kein Satz, nur der Knopf - genau wie in der Vorlage, wo `aus`
    /// allein die Schaltfläche zeigt (`Mitteilungen.tsx:222-226`). Ein Satz „Mitteilungen sind
    /// aus“ wäre eine Auskunft, die der Knopf schon gibt.
    public static func lagesatz(_ lage: Lage) -> Lagesatz {
        switch lage {
        case .aus:
            return Lagesatz(satz: nil, warnt: false)
        case .verboten:
            // Wortgleich mit dem Dashboard (`Mitteilungen.tsx`).
            return Lagesatz(
                satz: "Mitteilungen sind auf diesem Gerät abgelehnt. Zurücknehmen lässt sich das "
                    + "nur in den Einstellungen des Geräts.",
                warnt: true)
        case .halb:
            // Kein Gegenstück in der Vorlage: dort ist ein Abonnement im Browser auch gleich
            // beim Dienst. Hier vergibt das Betriebssystem das Token, und zwischen Erlaubnis
            // und Anmeldung liegt ein Netzweg, der scheitern kann.
            return Lagesatz(
                satz: "Erlaubt, aber der Dienst kennt dieses Gerät noch nicht.", warnt: true)
        case .an:
            return Lagesatz(satz: "Dieses Gerät ist angemeldet.", warnt: false)
        case .fehler(let satz):
            return Lagesatz(satz: satz, warnt: true)
        }
    }

    /// Ob der Knopf „Auf diesem Gerät einschalten“ dasteht (`Mitteilungen.tsx:222-226`).
    public static func darfEinschalten(_ lage: Lage) -> Bool {
        lage == .aus
    }

    /// Welcher Probeknopf dasteht.
    ///
    /// **Drei Fälle und nicht zwei.** Die App konnte bisher nur proben, wenn *dieses* Gerät
    /// angemeldet war (`MitteilungenSeite.swift:83-85` vor dem Umbau). Die Vorlage bietet die
    /// Probe auch sonst, sobald fremde Geräte in der Liste stehen
    /// (`Mitteilungen.tsx:238-242`) - und das ist der Fall, in dem sie am meisten nützt: wer am
    /// iPad sitzt und wissen will, ob das Telefon klingelt, hat genau diesen Knopf gebraucht.
    public enum Probeknopf: Sendable, Hashable {
        case keiner
        /// „Probe senden“ - dieses Gerät ist angemeldet (`Mitteilungen.tsx:231`).
        case diesesGeraet
        /// „Probe an die angemeldeten Geräte“ (`Mitteilungen.tsx:240`).
        case fremdeGeraete
    }

    /// Welcher Probeknopf zur Lage und zur Zahl bekannter Geräte gehört.
    ///
    /// `geraete` ist `nil`, solange die Abfrage nicht geantwortet hat; dann steht kein Knopf da,
    /// wie in der Vorlage, wo `geraete && geraete.length > 0` beides prüft (`:238`).
    public static func probeknopf(lage: Lage, geraete: Int?) -> Probeknopf {
        if lage == .an { return .diesesGeraet }
        return (geraete ?? 0) > 0 ? .fremdeGeraete : .keiner
    }

    // MARK: - Die angemeldeten Geräte

    /// Eine Zeile der Geräteliste: Name, seit wann, und wie es um die Zustellung steht.
    ///
    /// `seit` und `stand` sind fertige Sätze und keine Rohwerte - das Zusammensetzen ist die
    /// Rechnung, um die es hier geht, und eine Ansicht, die „angemeldet seit“ selbst davorsetzt,
    /// hätte denselben Satz an zwei Stellen.
    public struct Geraetezeile: Sendable, Hashable, Identifiable {
        /// Das Wort, unter dem der Dienst das Gerät führt (`PushGeraetOut/label`).
        public let name: String
        /// „angemeldet seit Sa., 07.11.“ - `nil`, wenn der Dienst keinen Zeitpunkt kennt
        /// (`Mitteilungen.tsx:75`: dort steht dann die leere Zeichenkette).
        public let seit: String?
        /// Der Zustandssatz (`Mitteilungen.tsx:64-70`).
        public let stand: String
        /// Ob die Zeile im Warnton steht (`globals.css:766`, `Mitteilungen.tsx:71`).
        public let schlecht: Bool

        /// Name und Anmeldezeitpunkt, wie die Vorlage ihren Schlüssel bildet
        /// (`Mitteilungen.tsx:263`). Zwei Geräte gleichen Namens kommen vor - zwei gleichen
        /// Namens *und* gleicher Anmeldung nicht.
        public var id: String { "\(name)|\(seit ?? "")" }

        public init(name: String, seit: String?, stand: String, schlecht: Bool) {
            self.name = name
            self.seit = seit
            self.stand = stand
            self.schlecht = schlecht
        }
    }

    /// Die Zeilen der Geräteliste, in der Reihenfolge des Dienstes.
    public static func zeilen(_ geraete: PushGeraeteOut) -> [Geraetezeile] {
        geraete.devices.map(zeile(_:))
    }

    /// Eine Zeile aus einem Gerät des Dienstes.
    ///
    /// **Die vier Stufen in der Reihenfolge der Vorlage** (`Mitteilungen.tsx:64-70`): ein
    /// letzter Fehler schlägt alles, denn er ist das Neueste und das Einzige, was den Grund
    /// nennt; danach der letzte Erfolg; danach gescheiterte Versuche ohne jeden Erfolg; und
    /// zuletzt der stille Fall, in dem noch gar nichts verschickt wurde.
    ///
    /// **Leer ist wie fehlend.** Die Vorlage prüft `g.letzter_fehler_de` und `g.zuletzt_ok` auf
    /// Wahrheit, und die leere Zeichenkette ist in JavaScript unwahr. Ein Dienst, der `""`
    /// liefert statt `null`, bekäme hier sonst eine leere Zeile als Zustandssatz.
    public static func zeile(_ g: PushGeraetOut) -> Geraetezeile {
        let fehler = gefuellt(g.letzterFehlerDe)
        let erfolg = gefuellt(g.zuletztOk)
        let versuche = g.fehlversuche ?? 0
        let stand: String
        if let fehler {
            stand = ohneVorsatz(fehler, name: g.label)
        } else if let erfolg {
            stand = "Zuletzt angenommen am \(wann(erfolg))."
        } else if versuche > 0 {
            stand =
                "Noch keine Mitteilung angenommen, \(versuche) "
                + "\(versuche == 1 ? "Versuch" : "Versuche") gescheitert. Eine Probe zeigt den "
                + "Grund."
        } else {
            stand = "Noch keine Mitteilung verschickt."
        }
        return Geraetezeile(
            name: g.label,
            seit: gefuellt(g.seit).map { "angemeldet seit \(Formate.kurzDatum(iso: $0))" },
            stand: stand,
            schlecht: fehler != nil || (erfolg == nil && versuche > 0))
    }

    /// „Sa., 07.11., 06:12“ - Datum und Uhrzeit, wie `wann()` der Vorlage sie setzt
    /// (`Mitteilungen.tsx:58-60`).
    private static func wann(_ iso: String) -> String {
        "\(Formate.kurzDatum(iso: iso)), \(Formate.hhmm(iso: iso))"
    }

    /// Der Fehlersatz des Dienstes ohne den vorangestellten Gerätenamen
    /// (`Mitteilungen.tsx:65`: `replace(\`${g.label}: \`, "")`).
    ///
    /// Der Dienst stellt seinen Meldungen den Namen voran, weil sie auch in einer Liste über
    /// alle Geräte stehen (`push.py:158`, `satz_de`). In der Zeile *dieses* Geräts steht der
    /// Name schon links daneben, und „Telefon: Telefon antwortet nicht“ liest sich wie ein
    /// Fehler der Seite.
    public static func ohneVorsatz(_ satz: String, name: String) -> String {
        let vorsatz = "\(name): "
        guard satz.hasPrefix(vorsatz) else { return satz }
        return String(satz.dropFirst(vorsatz.count))
    }


    /// Der Warnsatz, wenn kein Gerät angemeldet ist (`Mitteilungen.tsx`, `KEIN_GERAET`).
    public static let ohneGeraete =
        "Kein Gerät angemeldet. Störungen und das Morning Briefing gehen an niemanden."

    // MARK: - Die Karte „Morning Briefing“

    /// Der Kicker der zweiten Karte (`Morgenbrief.tsx:67`).
    ///
    /// **„Morning Briefing“ und nicht „Morgenbrief“.** Die Vorlage sagt auf dieser Seite dreimal
    /// den englischen Namen (`Morgenbrief.tsx:67`, `:89`, `Mitteilungen.tsx:192`), weil das der
    /// Name der Mitteilung ist, die auf dem Sperrbildschirm erscheint. Im Quelltext heißt die
    /// Sache weiter Morgenbrief - der Benutzer liest den Titel, nicht den Dateinamen.
    public static let briefKicker = "Morning Briefing"

    /// Der Rückfall für die Uhrzeit, solange die Antwort unterwegs ist (`Morgenbrief.tsx:69`).
    ///
    /// Sieben Uhr ist nicht geraten, sondern die Vorgabe des Dienstes; und die Karte zeigt ihren
    /// erklärenden Satz in der Vorlage **vor** der Antwort (`Morgenbrief.tsx:68` steht außerhalb
    /// der `stand`-Abfrage). Ohne Rückfall stünde dort eine Lücke mitten im Satz.
    public static let briefUhrzeitRueckfall = "07:00"

    /// Der Satz unter dem Titel der zweiten Karte, mit der Uhrzeit (`Morgenbrief.tsx`, `briefsatz`).
    public static func briefErklaerung(uhrzeit: String?) -> String {
        let zeit = gefuellt(uhrzeit) ?? briefUhrzeitRueckfall
        return "Jeden Morgen um \(zeit) Uhr: Sonne, Strompreis und Wärme des Tages."
    }

    /// Der Einordnungssatz über der Vorschau (`Morgenbrief.tsx:74-78`).
    ///
    /// **Das Wort „morgen“ wird nie selbst gezeigt.** `fuer_de` ist eine Kennung des Dienstes
    /// („heute“ | „morgen“), und die App setzte sie als eigene Zeile unter den Brief
    /// (`MitteilungenSeite.swift:163-165` vor dem Umbau). Ein einzelnes Wort „morgen“ unter
    /// einem Brief sagt nicht, was es heißen soll; der Satz der Vorlage sagt es: vom heutigen
    /// Tag ist zu wenig übrig.
    public static func einordnung(_ brief: MorgenbriefOut) -> String {
        brief.fuerDe == "morgen"
            ? "So sähe das Briefing morgen früh aus:"
            : "Das Briefing für heute:"
    }

    /// Der Titel in der Vorschau, mit Rückfall (`Morgenbrief.tsx:81`).
    public static func vorschautitel(_ brief: MorgenbriefOut) -> String {
        gefuellt(brief.titel) ?? briefKicker
    }

    /// Der Zustandssatz neben den Knöpfen (`Morgenbrief.tsx:89`).
    ///
    /// In der App stand er im Kartentitel („kommt täglich um 07:00“,
    /// `MitteilungenSeite.swift:145` vor dem Umbau), wo er keine Farbe tragen kann. Ein Titel
    /// ist eine Überschrift und kein Schalterzustand; neben dem Knopf, der ihn ändert, ist er
    /// die Antwort auf die Frage, die der Knopf stellt.
    public static func briefZustand(an: Bool) -> String {
        an ? "eingeschaltet" : "ausgeschaltet"
    }

    /// Das Wort auf dem Schaltknopf (`Morgenbrief.tsx:91`).
    public static func schaltwort(an: Bool) -> String {
        an ? "Ausschalten" : "Einschalten"
    }

    /// Ob „Jetzt senden“ bedienbar ist (`Morgenbrief.tsx:93`).
    ///
    /// **Gesperrt, solange keine Zeilen da sind.** Ein Brief ohne Zeilen ist kein Brief, und
    /// was verschickt würde, wäre die feste Probe des Dienstes (`push.py:130-133`) - also etwas
    /// anderes als das, was die Vorschau darüber zeigt. Der Knopf verspricht dann mehr, als er
    /// hält.
    public static func darfSenden(_ brief: MorgenbriefOut) -> Bool {
        !brief.zeilen.isEmpty
    }

    /// Ob der Warnsatz dasteht, dass das Briefing an niemanden geht (`Morgenbrief.tsx:99`).
    ///
    /// **Nur bei eingeschaltetem Briefing.** Ist es aus, geht es ohnehin an niemanden, und zwei
    /// Sätze übereinander, die dasselbe sagen, machen den einen davon unglaubwürdig.
    public static func warntOhneGeraete(_ brief: MorgenbriefOut) -> Bool {
        brief.enabled && (brief.geraete ?? 0) == 0
    }

    /// Der Warnsatz dazu (`Morgenbrief.tsx:100-102`).
    public static let briefOhneGeraete = "Kein Gerät angemeldet. Das Briefing geht an niemanden."

    /// Was nach dem Abmelden dasteht (`Mitteilungen.tsx:163`).
    ///
    /// **Ein Satz und keine stumme Liste.** Die App sagte nach dem Abmelden nichts
    /// (`MitteilungenSeite.swift:86-91` vor dem Umbau); die Liste darunter hatte ein Gerät
    /// weniger, und das war die ganze Rückmeldung. Wer das Gerät nicht in der Liste wiedererkennt
    /// - und das ist der Normalfall, wenn drei „iPhone“ heißen -, weiß nicht, ob es geklappt hat.
    public static let abgemeldet = "Dieses Gerät bekommt keine Mitteilungen mehr."

    // MARK: - Wenn etwas nicht klappt

    /// Laden gescheitert (`Morgenbrief.tsx:30`).
    public static let briefNichtErreichbar = "Das Morning Briefing ist gerade nicht zu erreichen."
    /// Schalten gescheitert (`Morgenbrief.tsx:43`).
    ///
    /// Der zweite Halbsatz ist der wichtigere: nach einem gescheiterten Schalten steht der
    /// Knopf noch so da wie vorher, und ohne diesen Satz sähe das aus wie „hat geklappt“.
    public static let schaltenGescheitert =
        "Das hat nicht geklappt. Die Einstellung ist unverändert."
    /// Senden gescheitert (`Morgenbrief.tsx:58`).
    public static let sendenGescheitert = "Das Briefing ließ sich nicht verschicken."

    /// Was eine gescheiterte Probe oder Anmeldung sagt, mit dem Grund dahinter
    /// (`Mitteilungen.tsx:55`, `hinweis()`).
    ///
    /// Den Sonderfall „Registration failed“ der Vorlage (`:51-54`) gibt es hier nicht: er
    /// beschreibt den Push-Dienst eines Browsers. Das Gegenstück dieser App ist die fehlende
    /// Push-Berechtigung, und die übersetzt ``Mitteilungen`` selbst
    /// (`Mitteilungen/Mitteilungen.swift:114-130`), weil nur sie den Fehler von APNs sieht.
    public static func hinweis(_ grund: String) -> String {
        "Das hat nicht geklappt: \(grund)"
    }

    // MARK: - Hilfe

    /// Eine Zeichenkette, die wirklich etwas enthält - leer ist wie fehlend.
    private static func gefuellt(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
