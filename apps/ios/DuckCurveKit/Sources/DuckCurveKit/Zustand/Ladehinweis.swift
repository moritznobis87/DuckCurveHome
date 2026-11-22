import Foundation

/// Der Ladehinweis in einer Karte: die kleine Schwester des ``Ladeschirm``.
///
/// **Der Anlass, wörtlich** (Nutzer am 21.11.2026): „wenn Daten geladen werden finde ich eine
/// Animation mit der Ente Alfred cooler, als einfach nur ‚Daten werden geladen‘“.
///
/// **Was sie von der großen Schwester übernimmt.** ``Ladeschirm`` ist das Vollbild beim Start -
/// Ente groß und mittig, dahinter der atmende Schein im Takt des `Atempunkt`. Hier steht
/// dieselbe Ente, derselbe Schein, derselbe Takt, und aus denselben Gründen; neu ist nur, wo
/// sie steht: nicht auf einer leeren Fläche, sondern in einer Karte neben einem Satz, der
/// vorher allein dastand.
///
/// **Was sich unterscheiden muss, und warum.** Drei Dinge:
///
/// 1. **Die Ente bewegt sich hier selbst** (``hub(zeiger:)``), im Ladeschirm tut sie es nicht.
///    Dort ist sie 150 bis 260 Punkte groß und das einzige auf dem Bildschirm; eine Ente, die
///    in dieser Größe hüpft, wäre Unterhaltung, und darum atmet dort nur das Licht. Hier ist
///    sie 38 Punkte groß und steht neben Text - in dieser Größe ist ein atmender Schein kaum
///    zu sehen, und gerade das Sichsein-Bewegen ist die Auskunft, um die es geht. Gefragt hat
///    der Nutzer nach einer Animation **mit der Ente**.
/// 2. **Keine weiße Kachel darunter.** Im Ladeschirm und am `Entenknopf` steht die Ente auf
///    der Kachel der Marke. In einer Karte wäre eine weiße Scheibe mit einer Ente darin genau
///    der ``Entenknopf`` - und der ist ein Knopf, den man drückt, um Alfred zu fragen. Ein
///    Ladehinweis, der aussieht wie ein Knopf, lädt zum Tippen ein und tut dann nichts.
/// 3. **Die Bewegung endet nach einer Minute** (``frist``). Das Vollbild endet selbst, nach
///    `Ladeschirm.aufgabeNach`; eine Karte kann das nicht - sie hat nichts, worauf sie
///    umschalten könnte. Also endet nicht das Warten, sondern das Bild.
///
/// **Was hier gerechnet wird, und warum im Kern.** Vier Entscheidungen, von denen jede eine
/// eigene Art von Schaden verhindert: der gemeinsame Takt (sonst der Zirkus, siehe
/// ``zeiger(jetzt:)``), die Frist (sonst die Wand, siehe ``frist``), die zwei Stufen (sonst die
/// falsche Größe, siehe ``Stufe``) und der Satz für VoiceOver (sonst ein stummes Bild, siehe
/// ``vorleser(satz:)``). Gezeichnet wird in `apps/ios/DuckCurveHome/Bausteine/Ladeente.swift`;
/// die Ansicht hält kein einziges dieser Maße.
public enum Ladehinweis {

    // MARK: - Der Takt

    /// Ein ganzer Atemzug: 3,6 Sekunden, hin und zurück.
    ///
    /// **Dieselbe Zahl wie überall sonst in diesem Haus, wo etwas atmet** - der `Atempunkt` des
    /// Ruhebildes und der Schein des Ladeschirms laufen beide auf `dch-atmen`: 1,8 Sekunden je
    /// Richtung. Ein zweiter Takt neben diesem wäre auf derselben Seite sofort zu sehen: der
    /// Punkt im Kopf atmet weiter, während die Karte darunter lädt.
    public static let takt: TimeInterval = 3.6

    /// Eine Richtung des Atemzugs - die Zahl, die in den Animationen der Vorlage steht.
    public static let halbtakt: TimeInterval = 1.8

    /// So oft wird höchstens neu gezeichnet: dreißig Bilder je Sekunde.
    ///
    /// **Warum eine Obergrenze überhaupt.** Diese Bewegung hängt nicht an einer Animation, die
    /// das System von sich aus weiterrechnet, sondern an der Uhr (``zeiger(jetzt:)``) - und das
    /// heißt, die Ansicht wird je Bild neu gebaut. Ohne Grenze wären das 120 Bilder je Sekunde
    /// am iPad, und zwar für eine Bewegung, die 3,6 Sekunden für einen ganzen Weg braucht:
    /// dreißig Bilder sind über hundert je Atemzug, und so steht die Schranke auch im Test
    /// (`testDerBildtaktIstDreissigBilder`). In Punkten gerechnet rückt die Ente dabei selbst
    /// an der schnellsten Stelle des Kosinus - der Mitte ihres Weges - nur um gut ein Zehntel
    /// Punkt je Bild: 0,09 in der kleinen Stufe, 0,18 in der großen. Mehr ist nicht zu sehen,
    /// kostet aber an der Wand den ganzen Tag Strom.
    public static let bildtakt: TimeInterval = 1.0 / 30

    /// Der Stand im Takt zu einem Zeitpunkt: 0 bis unter 1.
    ///
    /// **Das ist die Antwort auf den Zirkus, und sie ist der Grund, dass hier eine Uhr steht
    /// und kein Zustand.** Auf `/system/daten` warten vier Karten gleichzeitig
    /// (`Seiten/Technik/DatenSeite.swift`: `kurvenlage`, `quellenlage`, `abdeckungslage`,
    /// `diagnoselage` - drei Abfragen, die nebeneinander laufen, und dazu der Ereignisstrom).
    /// Vier Enten, die jede ihre eigene Dauerschleife bei ihrem eigenen Erscheinen anfangen,
    /// wackeln gegeneinander - und vier gegeneinander wackelnde Enten sind kein Ladehinweis,
    /// sondern Unruhe. Hängt die Lage dagegen allein am Zeitpunkt, dann ist sie für alle Enten
    /// dieselbe, ohne dass eine von der anderen wissen muss: auch die, die drei Sekunden später
    /// dazukommt, weil ihre Abfrage später losging, steht sofort im Schritt.
    ///
    /// **Und darum ist es die Geräteuhr und nicht die des Hauses.** `Hauszustand.jetzt` springt,
    /// sobald der erste Rahmen da ist, um den Versatz zum Dienst - mitten in der Bewegung. Die
    /// Geräteuhr springt auch, nur seltener, und ein Sprung verschiebt hier nichts weiter als
    /// die Phase: die Ente steht danach an einer anderen Stelle ihres Weges und läuft weiter.
    /// Keine Frist hängt an dieser Uhr; die ``frist`` zählt die Ansicht selbst ab.
    public static func zeiger(jetzt: Date) -> Double {
        let sekunden = jetzt.timeIntervalSinceReferenceDate / takt
        let rest = sekunden - sekunden.rounded(.down)
        // Eine Zeit vor 2001 ist negativ; `rounded(.down)` gibt dort trotzdem einen Rest in
        // 0 bis 1, aber Gleitkommaarithmetik kann genau auf 1 aufrunden. Dann wäre der Zeiger
        // einen Takt zu weit, und ``hub(zeiger:)`` liefe über seinen Rand.
        return rest >= 1 ? 0 : max(0, rest)
    }

    /// Wie hoch die Ente zu einem Stand im Takt liegt: 0 ist unten, 1 ist oben.
    ///
    /// **Ein Kosinus und keine Gerade.** Eine Gerade zwischen unten und oben kehrt an den Enden
    /// hart um - das ist kein Schwimmen, das ist ein Ruck. Der Kosinus ist genau das, was
    /// `easeInOut` mit `autoreverses` zeichnet, und das ist die Bewegung, die der `Atempunkt`
    /// und der Schein des Ladeschirms schon haben. Dieselbe Kurve, nur dass hier der Ort bewegt
    /// wird und dort die Deckung.
    public static func hub(zeiger: Double) -> Double {
        (1 - cos(2 * Double.pi * zeiger)) / 2
    }

    /// Der Hub zu einem Zeitpunkt - die beiden Rechnungen hintereinander.
    public static func hub(jetzt: Date) -> Double {
        hub(zeiger: zeiger(jetzt: jetzt))
    }

    /// Die Deckung des Scheins zu einem Hub: unten 0,5, oben 1.
    ///
    /// Dieselben Werte, mit denen der Schein des Ladeschirms atmet (`Atemschein`: `atmet ? 1 :
    /// 0.5`) - dort als Sprung zwischen zwei Zuständen, den eine Animation glättet, hier als
    /// Zahl je Bild. Dass die Ente oben ist, wenn der Schein am stärksten ist, ist Absicht: es
    /// ist eine Bewegung und nicht zwei.
    public static func scheindeckung(hub: Double) -> Double {
        0.5 + 0.5 * min(max(0, hub), 1)
    }

    // MARK: - Wer keine Bewegung will

    /// Der Hub, bei dem die Ente stillsteht: die Mitte ihres Weges.
    ///
    /// **Hinter `accessibilityReduceMotion`, und dieselbe Haltung wie im Ladeschirm:** wer
    /// Bewegung abgestellt hat, bekommt das Bild und nicht nichts. Die Ente steht dann da, wo
    /// sie im Mittel steht - nicht am oberen oder unteren Ende, denn das sind Umkehrpunkte einer
    /// Bewegung, die es für diesen Benutzer nicht gibt.
    public static let ruhigerHub: Double = 0.5

    /// Die Deckung des Scheins, wenn Bewegung abgestellt ist.
    ///
    /// **0,8 und nicht die 0,75, die ``scheindeckung(hub:)`` zum ``ruhigerHub`` ergäbe.** Es ist
    /// die Zahl des Ladeschirms (`Atemschein`: `ruhig ? 0.8 : …`), und sie ist dort begründet:
    /// der Schein ist auch das Licht hinter der Marke und nicht nur die Bewegung, also steht er
    /// etwas über dem Mittel und nicht darunter.
    public static let ruhigeDeckung: Double = 0.8

    // MARK: - Die Frist

    /// So lange bewegt sich die Ente; danach geht sie, und der Satz bleibt allein stehen.
    ///
    /// **Das ist die Zahl, an der die Wand hängt.** Das iPad in der Küche wird nie zugeklappt -
    /// `DuckCurveHomeApp` schaltet dort sogar den Ruhezustand ab, „der Unterschied zwischen
    /// einer Anzeige und einem Spiegel“. Eine Abfrage, die hängt, hängt dort nicht zehn
    /// Sekunden, sondern bis jemand hereinkommt: `quellenlage` in
    /// `Seiten/Technik/DatenSeite.swift` steht auf „lädt“, solange der Ereignisstrom im ersten
    /// Versuch ist, und dieser Strom wartet eine Stunde (`LiveStrom.swift`:
    /// `timeoutInterval = 3600`). Eine Ente, die so lange schaukelt, kostet die ganze Zeit
    /// Strom und Bilder, und im schlimmsten Fall brennt sie sich in das Bild ein.
    ///
    /// **Eine Minute, weil das die Grenze dieses Hauses ist.** Eine Abfrage einer Berichtsseite
    /// läuft auf den Vorgabewert von `URLSession` - „die ueblichen sechzig Sekunden“, so steht
    /// es an der einen Stelle, die sie überschreibt (`Api.swift`, der Strom für Alfreds Fragen,
    /// der zwei Minuten bekommt). Wer nach einer Minute noch wartet, wartet auf eine Antwort,
    /// die der Dienst schon aufgegeben hat; dann ist die Ente keine Auskunft mehr, sondern eine
    /// Behauptung.
    ///
    /// **Und warum die Ente geht, statt stehen zu bleiben.** Stehen bleiben wäre das
    /// Naheliegende - es ist ja genau das, was ``ruhigerHub`` für abgestellte Bewegung tut. Aber
    /// die beiden Fälle sind verschieden: dort ist das stehende Bild eine Entscheidung des
    /// Benutzers für dieses Gerät, hier wäre es ein Bild, das niemand mehr liest und das
    /// stundenlang in denselben Punkten steht - und einbrennen kann ein stehendes Bild besser
    /// als ein bewegtes. Was bleibt, ist der Satz, und damit steht die Karte wieder genau so da,
    /// wie sie vor dieser Änderung immer dastand.
    public static let frist: TimeInterval = 60

    /// Wie lange die Ente zum Gehen braucht.
    ///
    /// Die Überblendung dieses Hauses: 0,6 Sekunden, mit denen `WandRahmen` das Ruhebild kommen
    /// und gehen lässt - dieselbe Zahl, die ``Ladeschirm/mindestens`` aus demselben Grund trägt.
    /// Ein Bild, das in `Marken.dauer` verschwindet, ist weg, bevor man hinsieht, und sieht
    /// darum aus wie ein Fehler.
    public static let abgang: TimeInterval = 0.6

    /// Ob nach `verstrichen` Sekunden Wartens noch eine Ente dasteht.
    ///
    /// **Eine Zeile, und sie steht trotzdem hier.** Die Frist ist die Entscheidung, die an
    /// dieser Stelle am meisten kostet, wenn sie falsch ist; in einer Ansicht wäre der Vergleich
    /// nicht prüfbar, und ein `>=` statt eines `>` fiele niemandem auf.
    public static func enteDa(verstrichen: TimeInterval) -> Bool {
        verstrichen < frist
    }

    // MARK: - Die zwei Stufen

    /// Die Textstufe, auf deren Kurve ein Satz bei „Größerer Text“ wächst.
    ///
    /// **Zwei Fälle, weil dieses Haus zwei Grade kennt** (`Gestalt/Typografie.swift`):
    /// `Schrift.klein` ist 13 Punkte auf `.footnote`, `Schrift.text` 15 Punkte auf `.body`. Ein
    /// Grad ohne seine Kurve ist nur die halbe Angabe - zwei Sätze derselben Punktzahl, die auf
    /// verschiedenen Kurven hängen, sind bei der Vorgabe gleich groß und weichen voneinander ab,
    /// sobald jemand die Schrift stellt.
    ///
    /// **Und darum ein deutscher Name und nicht `Font.TextStyle`.** Dieser Kern baut und testet
    /// unter Linux, wo es kein SwiftUI gibt; die Ansicht übersetzt die zwei Fälle in den Stil.
    public enum Bezug: String, Sendable, Hashable, CaseIterable {
        /// Die Kurve von `Schrift.klein`: `.footnote`.
        case fussnote
        /// Die Kurve von `Schrift.text`: `.body`.
        case fliesstext
    }

    /// Wie groß die Ente an dieser Stelle ist.
    ///
    /// **Zwei Stufen, und die Frage, die sie trennt, ist nicht „wie groß ist die Karte“, sondern
    /// „ist diese Ente allein auf der Seite“.** Das ist dieselbe Entscheidung, die den Zirkus
    /// löst, nur von der anderen Seite her:
    ///
    /// Beide Listen sind gegen `grep -rn 'Ladeente(' apps/ios/DuckCurveHome` nachgezogen; wer
    /// eine Stelle dazustellt, zieht sie hier mit nach, denn dies ist die Stelle, an der man
    /// nachsieht, welche Stufe wohin gehört.
    ///
    /// - ``gross`` steht, wo der Ladehinweis an der Stelle eines ganzen Inhalts steht und der
    ///   einzige der Seite ist. Belege: `Seiten/Bericht.swift` - ein Hinweis, an der Stelle der
    ///   ganzen Seite, und das für alle dreizehn Auswertungsseiten; `HausSeite` - an der Stelle
    ///   des Hausmodells; `Raumprotokollblatt`; `MitteilungenSeite`; `JahreskarteSeite` - an der
    ///   Stelle des Jahresrasters; `HausgeraetSeite` - zweimal, die Seite selbst und das
    ///   Protokollblatt, das als Blatt darüber nichts anderes zeigt; und die fünf Technikseiten,
    ///   deren Ladezustand die ganze Seite ist: `WaermepumpeSeite`, `BetriebSeite`,
    ///   `KennlinieSeite` und `AnnahmenSeite` - je ein Absatz auf einer sonst leeren Seite, ohne
    ///   Karte - sowie `ReglerSeite`, dort in einer Karte.
    /// - ``klein`` steht, wo mehrere gleichzeitig warten oder wo der Hinweis sich seine Karte
    ///   mit etwas teilt, das schon dasteht. Belege: `DatenSeite` - eine Aufrufstelle, aber vier
    ///   Karten, die alle gleichzeitig laden können; `Pruefkurvenbild/Quellenkarte`;
    ///   `NachbetrachtungSeite` - der Satz steht unter der Bedienzeile, mit der man schon den
    ///   Tag wechseln kann, während er lädt; `PrognoseSeite` - zweimal; `WirkungSeite` und
    ///   `ZugangSeite` - je einer, und beide unter etwas, das schon bedienbar dasteht.
    ///
    /// **Warum nicht mitwachsen statt Stufen.** Mitwachsen hieße, die Ente an die Breite ihrer
    /// Karte zu hängen - und die Karten dieser App sind alle etwa gleich breit, auch die, in
    /// denen vier Hinweise untereinander stehen. Die Breite ist also nicht das, was sich
    /// unterscheidet; die Rolle ist es. Mit dem Schriftgrad wächst die Ente trotzdem: das
    /// besorgt `@ScaledMetric` in der Ansicht, damit „Größerer Text“ nicht einen großen Satz
    /// neben eine kleine Ente setzt - und zwar auf der Kurve, die ``Stufe/satzbezug`` nennt,
    /// damit Ente und Satz nicht verschieden schnell wachsen.
    public enum Stufe: String, Sendable, Hashable, CaseIterable {
        /// Neben einem Satz, in einer Karte, die noch etwas anderes trägt.
        case klein
        /// An der Stelle eines ganzen Diagramms oder einer ganzen Seite.
        case gross

        /// Die Kante der Ente in Punkten.
        ///
        /// **38 ist keine neue Zahl.** So groß ist die Ente am `Entenknopf`, der in dieser App
        /// an jeder Seite unten rechts schwebt - die Größe, in der dieses Haus die Ente schon
        /// neben Inhalt stellt, und die kleinste, in der man sie als Ente erkennt. Die große
        /// Stufe ist das Doppelte, und damit stehen die drei Enten dieser App in einer
        /// Halbierung: 150 und mehr im Ladeschirm, 76 an der Stelle eines Diagramms, 38 neben
        /// einem Satz.
        public var kante: Double {
            switch self {
            case .klein: return 38
            case .gross: return 76
            }
        }

        /// Der ganze Weg, den die Ente auf und ab fährt.
        ///
        /// **Ein Zwölftel ihrer eigenen Kante**, also 3,2 beziehungsweise 6,3 Punkte - in beiden
        /// Stufen derselbe Anteil, damit die große nicht heftiger schaukelt als die kleine,
        /// sondern nur weiter.
        ///
        /// Die Schranke nach oben steht in der kleinen Stufe, denn dort steht die Ente **neben**
        /// dem Satz: er ist 13 Punkte groß, seine Zeile damit gut 17 Punkte hoch, und eine Ente,
        /// die weiter fährt als ein Viertel dieser Zeile, zieht den Blick von dem Satz weg, der
        /// die eigentliche Auskunft ist. In der großen Stufe steht die Ente über dem Satz, und
        /// dort liegt keine Zeile in ihrem Weg. Die Schranke nach unten ist die Wand: von drei
        /// Metern muss man sehen, **dass** sich etwas bewegt.
        public var hubweite: Double { kante / 12 }

        /// Der Durchmesser des Scheins hinter der Ente.
        ///
        /// **1,9 Kanten und nicht die 2,6 des Ladeschirms.** Dort liegt der Schein auf einer
        /// leeren Fläche und darf auslaufen, soweit er will. Hier liegt er in einer Karte, deren
        /// Rand bei einer Ente von 38 Punkten nur gut einen Fingerbreit entfernt ist; ein
        /// Schein, der am Rand abgeschnitten wird, ist kein Licht, sondern ein Fleck.
        public var schein: Double { kante * 1.9 }

        /// Die Luft zwischen Ente und Satz.
        public var luft: Double {
            switch self {
            case .klein: return 12
            case .gross: return 14
            }
        }

        /// Der Schriftgrad des Satzes.
        ///
        /// **Klein ist der Grad von `Leer`** - 13 Punkte, also genau der Satz, der an diesen
        /// Stellen bis jetzt allein dastand. Groß ist der Grad des Fließtextes dieser App, 15
        /// Punkte: dort steht der Satz nicht als Beschriftung neben einem Bild, sondern mittig
        /// unter einer Ente und ist das einzige Wort auf der Fläche.
        public var satzgroesse: Double {
            switch self {
            case .klein: return 13
            case .gross: return 15
            }
        }

        /// Auf welcher Kurve der Satz wächst, wenn jemand „Größerer Text“ stellt.
        ///
        /// **Die Zahl allein genügt nicht.** Die beiden Grade der ``satzgroesse`` sind die
        /// zweier Stile dieses Hauses, und jeder bringt seine eigene Kurve mit: 13 Punkte sind
        /// `Schrift.klein` auf `.footnote`, 15 Punkte sind `Schrift.text` auf `.body`. Hinge der
        /// große Satz auf der Kurve der Fußnote, wüchse er anders als jeder andere
        /// 15-Punkt-Satz derselben Seite - und die Ente, die mit ihm wächst, liefe dieselbe
        /// falsche Kurve mit. Es war genau dieser Fehler, der den Satz der `WaermepumpeSeite`
        /// nach dem Einbau der Ente anders wachsen ließ als vorher.
        public var satzbezug: Bezug {
            switch self {
            case .klein: return .fussnote
            case .gross: return .fliesstext
            }
        }

        /// Steht der Satz unter der Ente statt neben ihr?
        ///
        /// **Nebeneinander in der kleinen Stufe, untereinander in der großen** - und das ist
        /// nicht Geschmack, sondern die Form, die die Stelle schon hat. `Leer` setzt seinen Satz
        /// linksbündig an den Rand der Karte, und so stehen die vier Hinweise der
        /// Datenprüfung untereinander in einer Spalte; eine Ente darüber würde diese Spalte
        /// viermal unterbrechen. An der Stelle eines ganzen Diagramms gibt es dagegen keine
        /// Spalte, an die man sich hängen könnte: dort ist die Mitte der Ort, und untereinander
        /// und mittig ist genau, wie der Ladeschirm es macht.
        public var untereinander: Bool { self == .gross }
    }

    // MARK: - Der Satz bleibt

    /// Der Satz dieser Anwendung für „die Antwort ist unterwegs“.
    ///
    /// **Wörtlich der, der schon dastand** - und er stand an sieben Stellen, jedes Mal als
    /// dasselbe Literal in einer Ansicht: im Gerippe der dreizehn Auswertungsseiten
    /// (`Seiten/Bericht.swift`), an der Stelle des Hausmodells (`HausSeite`), im
    /// Raumprotokollblatt, zweimal auf der Prognoseseite, auf der Hausgeräteseite und auf der
    /// Mitteilungsseite. Sieben gleichlautende Literale sind sechs Gelegenheiten, dass eines
    /// davon abweicht, und keines davon liest ein Test. Die Ente kommt dazu; der Satz bleibt
    /// Zeichen für Zeichen derselbe.
    ///
    /// **Er sagt „geholt“ und nicht „geladen“**, und das ist nicht beliebig: „Verbinde mit dem
    /// Haus …“ sagt der ``Ladeschirm``, solange noch keine Verbindung steht. Hier steht sie, und
    /// gewartet wird auf eine einzelne Antwort. Zwei Wörter für zwei verschiedene Wartezeiten,
    /// damit derselbe Satz nicht zwei Dinge verspricht.
    public static let berichtssatz = "Wird geholt …"

    /// Der Satz, den VoiceOver aus einem Ladehinweis macht.
    ///
    /// **Weil ein Bild, das schaukelt, nichts sagt.** Die Ente ist für VoiceOver nicht da; was
    /// gesprochen wird, ist allein dieser Satz - und zwar derselbe, der auch dasteht. Das ist
    /// die Bedingung, unter der die Ente überhaupt dazukommen durfte: sie ersetzt den Satz
    /// nicht, nicht im Bild und nicht im Ohr.
    ///
    /// **Zwei Handgriffe, und beide haben einen Grund.**
    ///
    /// 1. **Die Auslassungspunkte werden ein Punkt.** „lädt …“ ist für das Auge ein Versprechen,
    ///    dass es weitergeht; vorgelesen sind drei Punkte entweder nichts oder „Punkt Punkt
    ///    Punkt“, je nach Stimme und Einstellung. Ein Schlusspunkt ist, was eine Stimme braucht,
    ///    um den Satz als Satz zu senken.
    /// 2. **Ein Bruchstück wird ein Satz.** `Pruefworte.laedt` ist „lädt …“ - kleingeschrieben,
    ///    ohne Subjekt, aus der Vorlage übernommen (`DataCheck.tsx:83`). Im Bild ist das richtig:
    ///    daneben steht der Kicker der Karte, und der sagt, was lädt. Vorgelesen ist „lädt“ ein
    ///    Wort ohne Aussage. Woran man ein Bruchstück erkennt, muss nicht geraten werden: ein
    ///    deutscher Satz fängt groß an. Was klein anfängt, ist keiner und bekommt
    ///    ``ersatzsatz``.
    public static func vorleser(satz: String) -> String {
        let kern = satz.trimmingCharacters(in: satzende)
        guard let erster = kern.first else { return ersatzsatz }
        guard erster.isUppercase else { return ersatzsatz }
        return kern + "."
    }

    /// Was VoiceOver aus einem Bruchstück macht.
    ///
    /// **„Wird geladen.“ und nicht „Daten werden geladen.“** Was geladen wird, weiß dieser
    /// Baustein nicht - er steht in vier verschiedenen Karten der Datenprüfung, und jede holt
    /// etwas anderes. Den Namen sagt der Kicker der Karte, und den liest VoiceOver vor dem
    /// Inhalt. Ein erfundenes Subjekt wäre an drei von vier Stellen falsch.
    public static let ersatzsatz = "Wird geladen."

    /// Die Zeichen, die am Ende eines Satzes stehen und für die Stimme weg müssen.
    ///
    /// Das schmale Leerzeichen ist dabei, weil die Formate dieses Hauses es benutzen
    /// (``Formate/schmalesLeerzeichen``) und ein Satz damit enden kann.
    private static let satzende = CharacterSet(charactersIn: " .\u{2026}\u{202F}\u{00A0}")
}
