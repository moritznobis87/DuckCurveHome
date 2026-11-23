import Foundation

/// Der Ladeschirm: was zwischen dem ersten Code und den ersten Zahlen dasteht.
///
/// **Der Anlass, wörtlich** (Nutzer am 21.11.2026): „manchmal dauert es nach dem build bis die
/// app lädt und es kommt nur ein petrolfarbener bildschirm. baue vielleicht noch irgendwie
/// stylish alfred als grosses logo in die mitte mit einem app-marken-text, dass der kunde (und
/// ich) es als ladebildschirm erkennen“.
///
/// **Das sind zwei Bildschirme, und nur der zweite steht hier.** Vom Antippen bis zum ersten
/// Code zeichnet das *System*, nicht die App - das ist das Startbrett
/// (`apps/ios/project.yml`, `UILaunchStoryboardName`, und die Datei
/// `DuckCurveHome/Ressourcen/Startbrett.storyboard`). Erst danach läuft Code, und dann beginnt
/// das Warten, um das es hier geht: `Wurzel` zeigte bis jetzt sofort das Gerippe mit leeren
/// Karten, während `haus.starte()` noch den Strom öffnete. Beides sah nach demselben
/// petrolfarbenen Nichts aus, und darum sind die beiden Schirme hier und dort gleich gestaltet.
///
/// **Warum die Regeln im Kern stehen und nicht in der Ansicht.** Ab wann der Schirm erscheint,
/// wie lange er mindestens bleibt und wann er aufgibt, sind drei Entscheidungen mit Folgen -
/// und die schlimmste davon ist ein Schirm, der nie weggeht. In einer `View` wäre keine davon
/// prüfbar; hier spielt `LadeschirmTests` jede Lage durch. Gezeichnet wird in
/// `apps/ios/DuckCurveHome/Bausteine/Ladebild.swift`.
public enum Ladeschirm {

    // MARK: - Die drei Fristen

    /// So lange passiert gar nichts. Ist das Haus vorher da, erscheint der Schirm nie.
    ///
    /// **Dieselbe Ruhefrist, mit der dieses Projekt schon einmal ein Flackern erledigt hat**
    /// (`rooms/Stellen.tsx:35`, `RUHE_MS = 300`: „So lange wird nach der letzten Berührung
    /// gewartet, bevor die Wirkung neu gerechnet wird.“). Dort ist es eine Anfrage, hier ein
    /// Bild - die Frage ist dieselbe: was innerhalb einer Ruhefrist vorbei ist, hat nie
    /// stattgefunden. Im Haus, in dem diese App entsteht, steht der Dienst im selben Netz und
    /// antwortet in weniger als einer Zehntelsekunde; dort bekommt niemand den Ladeschirm
    /// überhaupt zu sehen, und das ist der Normalfall, den die Frist schützt.
    public static let ruhefrist: TimeInterval = 0.3

    /// Steht er, dann steht er so lange - auch wenn die Zahlen gleich danach kommen.
    ///
    /// **Die Zahl ist nicht erfunden:** 0,6 Sekunden ist die Überblendung, mit der diese App
    /// ihren einzigen anderen Vollbildschirm kommen und gehen lässt (`WandRahmen`:
    /// `.easeInOut(duration: 0.6)` für das Ruhebild). Kürzer als ein Überblenden dieses Hauses
    /// ist kein Bild, sondern ein Zucken - und ein Zucken ist schlimmer als die leeren Karten,
    /// gegen die der Schirm gebaut ist.
    public static let mindestens: TimeInterval = 0.6

    /// Danach wird aufgegeben: der Schirm geht, auch wenn nichts gekommen ist.
    ///
    /// **Das ist die wichtigste der drei Zahlen.** Ein Ladeschirm, der auf eine Antwort wartet,
    /// die nie kommt, ist kein Ladeschirm, sondern eine verschlossene Tür: der Dienst ist aus,
    /// das WLAN weg, die Adresse falsch - und der Nutzer kommt nicht einmal mehr an den Zugang,
    /// um es zu richten. Darum endet das Warten immer, und zwar nach fünf Sekunden:
    ///
    /// - Fünf Sekunden ist die Frist, mit der dieses Projekt schon entscheidet, dass eine
    ///   Wandanzeige auf eine Antwort nicht länger wartet (`live/reloadPolicy.ts:15`,
    ///   `AbortSignal.timeout(5000)`).
    /// - Fünf Sekunden ist auch der Takt, in dem die Aufsicht des Hauszustands nachsieht, ob
    ///   noch Rahmen kommen (`Hauszustand.starte()`), und der Mindestabstand, in dem der Dienst
    ///   Augenblicksbilder überhaupt schickt (`Takt` in `live_feed.py`). Wer so lange nichts
    ///   gehört hat, hört jetzt nicht mehr hin, sondern sieht nach.
    ///
    /// Danach steht die Startseite da, wie sie bis jetzt immer dastand - mit leeren Karten, dem
    /// Satz `Hauszustand.satz` und dem Verbindungspunkt, der sagt, woran es liegt. Das ist
    /// kein guter Anblick, aber ein bedienbarer.
    public static let aufgabeNach: TimeInterval = 5.0

    // MARK: - Was dasteht

    /// Die Wortmarke unter der Ente: „Duck Curve“ und nicht „Duck Curve Home“.
    ///
    /// Dieselbe Entscheidung wie im Kopf der Anzeige (`Marke` in
    /// `Gestalt/Zeichen.swift`, `layout/AreaNav.tsx:46-51`) und derselbe Name, der unter dem
    /// Programmsymbol steht (`CFBundleDisplayName: Duck Curve`). Der lange Name ist der des
    /// *Dienstes* im Haus - hier wird nicht der Dienst geladen, sondern die App geöffnet, und
    /// sie soll den Namen tragen, den der Nutzer angetippt hat.
    ///
    /// **Als Text und nicht als Bild.** `Ressourcen/Marke/duck-curve-mark.svg` ist eine
    /// Markenplatte: 1800 × 1000 mit eigenem Hintergrund, Kurvenzug und Balken - und sie ist
    /// vom Bauen ausgenommen (`project.yml`, `excludes: Ressourcen/Marke/*.svg`) und liegt in
    /// keinem Bildkatalog. Die Wortmarke dieser Anwendung ist in beiden Oberflächen ein
    /// gesetztes Wort in der Hausschrift, im Browser wie in der App.
    public static let marke = "Duck Curve"

    /// Der Satz darunter - auf beiden Geräten derselbe, und das ist eine Entscheidung.
    ///
    /// Es ist wörtlich der Satz, den die Startseite in genau dieser Lage sagt
    /// (`Hauszustand.satz`, solange kein Augenblicksbild da ist). Gibt der Schirm auf, folgt
    /// die Startseite mit demselben Satz - und zwei Wörter für dasselbe Warten sind zwei
    /// Versprechen; dieselbe Begründung steht an `Hauszustand.verbindungswort`.
    ///
    /// **Er sagt „verbinde“ und nicht „lädt“**, weil nicht die App lädt, sondern das Haus
    /// antwortet: nach einem frischen Bauen ist die App längst da und wartet aufs Netz. Ein
    /// „lädt …“ ließe den Nutzer am Telefon suchen, wo er nichts findet.
    public static let satz = "Verbinde mit dem Haus …"

    /// Die zweite Zeile, nur an der Wand.
    ///
    /// **Weil an der Wand niemand etwas angetippt hat.** Am Telefon ist der Ladeschirm die
    /// Antwort auf einen Fingertipp, der zwei Sekunden alt ist - da erklärt sich das Warten von
    /// selbst. Das iPad in der Küche kommt dagegen nach einem Stromausfall um vier Uhr von
    /// allein hoch, und wer um sieben hereinkommt, findet eine Anzeige ohne Zahlen und weiß
    /// nicht, ob sie kaputt ist oder ob er etwas tun muss. Dieser Satz sagt: keines von beiden.
    public static let wandzusatz = "Niemand muss etwas tun, die Anzeige baut sich selbst auf."

    /// Was VoiceOver aus dem ganzen Schirm macht.
    ///
    /// Ein Satz und nicht drei Bruchstücke: Ente, Wortmarke und Zeile sind zusammen *eine*
    /// Aussage, und sie muss sagen, **worauf** gewartet wird - „Wird geladen“ allein lässt
    /// offen, ob das Gerät, die App oder das Haus gemeint ist.
    public static let vorleser =
        "Duck Curve wird geladen. Die Anzeige wartet auf die ersten Zahlen aus dem Haus."

    // MARK: - Der Lauf

    /// Was der Schirm gerade tun soll.
    public enum Lage: String, Sendable, Hashable {
        /// Noch nichts zu sehen - die Ruhefrist läuft, er kann noch kommen.
        case verborgen
        /// Er steht.
        case steht
        /// Das Warten ist vorbei. Er kommt nicht wieder, bis die App neu startet.
        case vorbei
    }

    /// Ein Warten, von außen getaktet.
    ///
    /// **Warum ein Zustand und keine reine Funktion.** Zwei der drei Fristen hängen nicht am
    /// Start, sondern daran, *wann der Schirm erschienen ist* - und das weiß nur, wer mitzählt.
    /// Als Funktion mit sechs Argumenten hätte die Ansicht dasselbe Mitzählen gemacht, nur
    /// ungeprüft. Die Ansicht ruft ``takt(jetzt:hatZahlen:fehlerSteht:)`` in kurzen Abständen
    /// und zeichnet, was zurückkommt; mehr weiß sie nicht.
    ///
    /// **Der Lauf ist eine Einbahnstraße.** Nach ``Lage/vorbei`` kommt nie wieder ``Lage/steht``
    /// - auch dann nicht, wenn die Verbindung gleich darauf wieder abreißt. Ein Schirm, der
    /// mitten im Bedienen zurückkommt und die Seite verdeckt, wäre schlimmer als jede leere
    /// Karte; was danach mit der Verbindung ist, sagen der Punkt im Kopf und das
    /// `Hauszustand.verbindungswort`.
    public struct Lauf: Sendable {
        /// Wann die Oberfläche angefangen hat zu warten. Der erste Bezugspunkt, nicht mehr.
        public let start: Date

        /// Die Zeit, die seit dem Start wirklich vergangen ist - aufsummiert, nicht gemessen.
        ///
        /// **Warum nicht einfach `jetzt - start`.** Dann hingen alle drei Fristen an einer Uhr,
        /// die zurückgehen kann, und der schlimmste Fall wäre der, gegen den
        /// ``Ladeschirm/aufgabeNach`` gebaut ist: stellt die Netzzeit die Uhr während des
        /// Wartens zurück, wird die Differenz kleiner statt größer, die fünf Sekunden sind nie
        /// erreicht, und solange der Dienst auch schweigt, bleibt der Schirm für immer stehen.
        /// Das ist keine erfundene Lage, sondern genau die, die ``Ladeschirm/wandzusatz``
        /// beschreibt: das iPad kommt nach einem Stromausfall um vier Uhr von allein hoch - mit
        /// stehengebliebener Uhr, die gleich darauf vom Netz gestellt wird - und der Dienst im
        /// Haus hing am selben Strom und antwortet noch nicht.
        ///
        /// Darum wird je Takt nur der Schritt nach vorn gezählt. Ein Rückwärtssprung zählt
        /// null; danach läuft die Summe weiter, und die Einbahnstraße endet. Ein Sprung nach
        /// vorn zählt voll - er beendet das Warten früher, und früher ist harmlos: dann steht
        /// die bedienbare Startseite da.
        private var verstrichen: TimeInterval = 0
        private var zuletzt: Date?
        private var sichtbarAb: TimeInterval?
        private var erledigt = false

        public init(start: Date) {
            self.start = start
        }

        /// Ob der Schirm je dastand. Für die Ansicht, die danach nicht mehr überblenden muss.
        public var erschienen: Bool { sichtbarAb != nil }

        /// Ein Takt: was jetzt gilt.
        ///
        /// - Parameters:
        ///   - jetzt: die Uhr des Geräts. Nicht die des Hauses (`Hauszustand.jetzt`) - der
        ///     Versatz zum Server springt, sobald der erste Rahmen da ist, und ein Sprung in
        ///     der Uhr, an der eine Frist hängt, macht aus 0,3 Sekunden Warten eine Stunde.
        ///     Die Geräteuhr springt ebenso, nur seltener; was dagegen hilft, steht an
        ///     ``verstrichen``.
        ///   - hatZahlen: ist ein Augenblicksbild da? Das ist „noch nichts da“, sauber
        ///     erkannt: `Hauszustand.nochKeineZahlen`.
        ///   - fehlerSteht: steht ein Fehler, der nicht von selbst weggeht - ein falsches
        ///     Token etwa. Dann wird nicht gewartet, sondern durchgelassen: der Nutzer muss an
        ///     den Zugang kommen.
        public mutating func takt(jetzt: Date, hatZahlen: Bool, fehlerSteht: Bool) -> Lage {
            guard !erledigt else { return .vorbei }
            // Nur der Schritt nach vorn zählt; eine zurückgestellte Uhr verkürzt die Fristen
            // nicht, sie verlängert sie nur um diesen einen Takt.
            verstrichen += max(0, jetzt.timeIntervalSince(zuletzt ?? start))
            zuletzt = jetzt
            // Drei Gründe, nicht mehr zu warten - und der dritte kommt von der Uhr allein.
            let fertig = hatZahlen || fehlerSteht || verstrichen >= Ladeschirm.aufgabeNach

            if let sichtbarAb {
                guard fertig, verstrichen - sichtbarAb >= Ladeschirm.mindestens else {
                    return .steht
                }
                erledigt = true
                return .vorbei
            }
            if fertig {
                // In der Ruhefrist erledigt: er hat nie stattgefunden.
                erledigt = true
                return .vorbei
            }
            guard verstrichen >= Ladeschirm.ruhefrist else { return .verborgen }
            sichtbarAb = verstrichen
            return .steht
        }
    }
}
