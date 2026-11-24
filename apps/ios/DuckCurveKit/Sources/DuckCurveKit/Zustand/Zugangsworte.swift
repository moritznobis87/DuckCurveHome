import Foundation

/// Die Worte der Seite „Zugang und Sicherung“ - und die Jahre, für die es eine Sicherung gibt.
///
/// **Warum eine Wortsammlung im Kern und nicht Text in der Ansicht.** Diese Seite *ist* zu drei
/// Vierteln Text: `apps/web/src/app/system/zugang/page.tsx` setzt sechs Abschnitte, von denen
/// vier nichts anderes enthalten als einen Absatz. Diese Absätze sind keine Beschriftung, sie
/// sind die Begründung - warum ein Link wie ein Haustürschlüssel zu behandeln ist, warum die
/// Indizes eigens dastehen, warum ein verwaltetes Volume kein Archiv ist. In einem `ViewBuilder`
/// wären das sechzig Zeilen Zeichenkette, die niemand prüft und die beim nächsten Umbau der
/// Seite still verschwinden. Dasselbe Muster wie ``Pruefworte``, ``Anlagenworte``,
/// ``Wiedergabeworte``.
///
/// **Was hier nicht steht, und warum nicht.** Die Vorlage zeigt an dieser Stelle zwei
/// Pairing-Links mit den echten Tokens (`page.tsx:69-78`) und darunter die Liste „Gerade
/// verbunden“ (`page.tsx:88-114`). Beides ist in der App nicht nachzubauen und auch nicht
/// erfunden: die Tokens sind Umgebungsvariablen des Web-Dienstes (`page.tsx:51-52`), und die
/// Anwesenheitsliste ist eine `Map` im Arbeitsspeicher von Next (`lib/presence.ts:38-41`) - im
/// Dienst des Hauses gibt es für keines von beiden einen Endpunkt. Die App sagt deshalb, wo
/// beides steht, statt es zu behaupten.
public enum Zugangsworte {

    // MARK: - Die Überschriften, in der Reihenfolge der Vorlage

    /// Die sechs `<h2>` der Vorlage in ihrer Reihenfolge (`page.tsx:60, 89, 117, 127, 159, 169`).
    ///
    /// **Sie stehen hier, weil die Reihenfolge eine Aussage ist.** Der Bereichskicker nennt drei
    /// Dinge in genau dieser Folge - „Geräte koppeln · wer zusieht · Daten sichern“
    /// (`Bereiche.swift:170`) -, und die Abschnitte beantworten sie der Reihe nach. Die App
    /// hatte bis zum Umbau keinen Abschnitt an der Stelle des gleichnamigen.
    public static let ueberschriften = [
        "Zugang einrichten", "Gerade verbunden", "Platzbedarf", "Sicherung", "Sichtbarkeit",
        "Konfiguration",
    ]

    // MARK: - Zugang einrichten

    /// Der erste Absatz (`page.tsx:62-68`), auf die App gezogen.
    ///
    /// **Hier geht die App bewusst von der Vorlage ab.** Die Vorlage erklärt, dass die Links
    /// unten die echten Tokens tragen und woher die Adresse kommt (`DCH_PUBLIC_HOST`, begründet
    /// an `page.tsx:29-32`: „Railway antwortet weiterhin unter *.up.railway.app; ein von dort
    /// kopierter Link führte Gäste an der eigenen Domain vorbei“). In der App stehen diese Links
    /// nicht, weil es sie dort nicht gibt - und der Grund ist derselbe, aus dem die App
    /// überhaupt direkt mit dem Dienst spricht: sie hat einen Schlüsselbund, ein Browser hat
    /// keinen (``Zugang``, Kopfkommentar). Der Satz nennt darum beides: was dieses Gerät hat,
    /// und wo die Links für die anderen stehen.
    public static let koppeln =
        "Ein Browser wird einmal über einen Link gepaart und behält danach seine Sitzung. Diese App braucht den Umweg nicht: ihr Token liegt im Schlüsselbund dieses Geräts, durch die Gerätesperre geschützt, und verlässt es nur als Kopfzeile an die Adresse unten. Die Pairing-Links für die anderen Geräte, also Wandanzeige und Gast, stehen im Dashboard auf dieser Seite. Sie tragen die echten Tokens und sind wie ein Haustürschlüssel zu behandeln: wer einen Screenshot davon bekommt, hat die Schlüssel zum Haus."

    /// Was ein Vollzugriff darf (`page.tsx:73`).
    ///
    /// Das `name`-Feld der Vorlage ist ein Teil des Links; in der App ist es der Name dieses
    /// Geräts (``Zugang/geraetename``), und deshalb steht hier „der Name“ und nicht die
    /// Bezeichnung einer Frage, die auf diesem Gerät nicht vorkommt.
    public static let vollzugriff =
        "Darf schalten, sieht Kosten und Rechnungen. Die Sitzung hält ein halbes Jahr; der Name erscheint nur im Protokoll."

    /// Was ein Gast sieht - und was ihm verschlossen bleibt (`page.tsx:78`).
    ///
    /// **Der Satz gilt für das Dashboard und nicht für diese App**, und das ist kein Versehen
    /// der Übernahme: im BFF ist die Beschränkung eine Tür, in der App nur eine ausgeblendete
    /// Schaltfläche (``Zugang``, Punkt 3 des Kopfkommentars). Die Methode der Seite sagt das
    /// noch einmal ausdrücklich; hier steht, was ein Gastzugang *im Dashboard* bedeutet, weil
    /// genau dort die Links für Gäste entstehen.
    public static let gast =
        "Sieht Jetzt, Strom, Wärme und Geld; PV-Abrechnung, Rechnungen und System bleiben verschlossen. Die Schalter bleiben sichtbar und sagen „nur Ansicht“. Ohne Angabe einer Dauer gilt DCH_GUEST_HOURS (Vorgabe 24), höchstens 720 Stunden."

    /// Der Schlussabsatz des ersten Abschnitts (`page.tsx:80-84`).
    ///
    /// **Die Unterscheidung ist die Pointe des ganzen Abschnitts:** der Ablauf begrenzt die
    /// Sitzung und nicht den Link. Wer den Link aufhebt, paart sich erneut - ein abgelaufener
    /// Gast ist also kein ausgesperrter Gast.
    public static let sitzungsdauer =
        "Der Ablauf begrenzt die Sitzung, nicht den Link: wer ihn aufhebt, kann sich erneut paaren. Um das zu unterbinden, ändert man DCH_GUEST_TOKEN im Web-Dienst. Bestehende Gast-Sitzungen laufen dann regulär ab, neue entstehen nicht mehr."

    // MARK: - Platzbedarf

    /// Der Absatz über der Tabelle (`page.tsx:118-122`), wörtlich.
    public static let platzbedarf =
        "Eine verwaltete Datenbank wird nach Arbeitsspeicher abgerechnet, und den belegt sie im Wesentlichen mit ihrer eigenen Größe. Welche Tabelle das ist, lässt sich nicht erraten: bei schmalen Zeilen sind die Indizes regelmäßig größer als die Daten."

    // MARK: - Sicherung

    /// Der Absatz über den Jahreszeilen (`page.tsx:128-134`), wörtlich.
    public static let sicherung =
        "Die Datenbank ist die einzige Kopie. Ein verwaltetes Volume bei einem Anbieter ist kein Archiv: es überlebt keinen gelöschten Zugang und keinen Anbieterwechsel. Einmal im Jahr herunterladen und woanders ablegen. Die Dateien sind gzip-komprimiertes CSV und lassen sich ohne dieses Programm lesen."

    /// Was eine Jahresdatei wiegt (`page.tsx:145-147`), wörtlich.
    ///
    /// Die Zahl steht dabei, weil sie die Entscheidung trägt: 20 MB lädt man über Mobilfunk
    /// nicht versehentlich, und wer es tut, soll es vorher gewusst haben.
    public static let jahresgroesse = "Minutenwerte eines vollen Jahres: rund 20 MB gepackt"

    /// Der Hinweis der App zum Herunterladen - kein Gegenstück in der Vorlage.
    ///
    /// **Warum er nötig ist.** In der Vorlage ist der Verweis ein `<a href>`, und der Browser
    /// trägt das Sitzungscookie mit; die Datei kommt an. In der App führt der Weg über
    /// ``Zugang/export(art:jahr:)`` an den Browser des Geräts - und dort fehlt die
    /// `Authorization`-Kopfzeile, die nur diese App aus dem Schlüsselbund setzen kann
    /// (``Zugang/kopfzeilen``). Das ist kein Fehler, sondern die Folge davon, dass das Token
    /// das Gerät nicht verlässt; es muss aber dastehen, sonst sieht der Benutzer eine leere
    /// Seite und hält das Programm für kaputt.
    public static let herunterladen =
        "Der Verweis gibt die Adresse an den Browser dieses Geräts; dort lädt die Datei und landet in den Dateien. Das Token bleibt dabei im Schlüsselbund und reist nicht mit: ein Dienst, der ein Token verlangt, antwortet dem Browser deshalb mit 401, solange dort keine eigene Sitzung besteht. Dann holt man die Dateien im Dashboard, das die Anmeldung schon hat."

    /// Der Schlussabsatz des Abschnitts (`page.tsx:150-155`), wörtlich.
    public static let sicherungsschluss =
        "Die Stundenbilanz enthält auch die Grundlagen der PV-Abrechnung, also Eigenverbrauch, Wiederbeschaffungswert und Umsatzsteuer. Sie gehört zu den Unterlagen, die aufzubewahren sind. Ein laufendes Jahr ist naturgemäß unvollständig; für den Abschluss im Januar erneut holen."

    /// Für welche Jahre eine Sicherung angeboten wird: das laufende und das davor
    /// (`page.tsx:135`: `[year, year - 1]`).
    ///
    /// **Gerechnet im Kalender des Hauses und nicht in dem des Geräts.** `new Date().getFullYear()`
    /// im Web-Dienst läuft in der Zeitzone des Servers; die App liest die Uhr des Hauses
    /// (``Kalender/haus``). Am 1. Januar um 00:30 Ortszeit sind das zwei verschiedene Jahre -
    /// und wer in der Neujahrsnacht die Sicherung des abgelaufenen Jahres holen will, bekäme
    /// sonst die von vorletztem.
    ///
    /// **Zwei und nicht mehr.** Ein Archiv baut man einmal im Jahr auf (siehe ``sicherung``);
    /// was älter ist, liegt schon woanders, und eine Liste aus zehn Jahren wäre eine Liste von
    /// Dateien, die der Dienst vielleicht nicht mehr hat.
    public static func sicherungsjahre(jetzt: Date) -> [Int] {
        let jahr = Kalender.haus.component(.year, from: jetzt)
        return [jahr, jahr - 1]
    }

    // MARK: - Sichtbarkeit und Konfiguration

    /// Ein Stück eines Absatzes - normale Schrift oder Festbreitenschrift.
    ///
    /// **Warum die Fuge hier liegt und nicht in der Ansicht.** Die Vorlage setzt in diesen zwei
    /// Absätzen vier Fachwörter in `code.mono` (`page.tsx:161-165, 171`): `robots.txt`,
    /// `noindex`, `X-Robots-Tag`, `CONFIGURATION.md`. Das sind Dateinamen und Kopfzeilen - wer
    /// sie suchen soll, muss sie als solche erkennen, und in Fließschrift sieht `X-Robots-Tag`
    /// aus wie ein Wort mit Bindestrichen. Welcher Teil eines Satzes ein solches Wort ist, ist
    /// eine Festlegung über den Satz und keine über die Schrift; dieselbe Überlegung wie bei
    /// ``Anlagenworte/Kopfteile``, wo nur der mittlere Teil fett steht.
    public struct Satzteil: Sendable, Hashable {
        public let wort: String
        /// Festbreitenschrift, wie `code.mono` in der Vorlage.
        public let mono: Bool

        public init(_ wort: String, mono: Bool = false) {
            self.wort = wort
            self.mono = mono
        }
    }

    /// „Sichtbarkeit“ (`page.tsx:160-165`), in Stücken.
    ///
    /// **„Die Seite“ der Vorlage ist hier „das Dashboard“.** Eine App steht in keinem
    /// Suchindex; gesperrt wird die Webseite, und nur dort gibt es `robots.txt`, den
    /// `noindex`-Meta-Tag und den Header. Die Aussage des Abschnitts bleibt dieselbe und ist
    /// der Grund, warum er auf dieser Seite steht: das alles ist kein Zugriffsschutz.
    public static let sichtbarkeit: [Satzteil] = [
        Satzteil("Das Dashboard ist für Suchmaschinen gesperrt, und zwar über "),
        Satzteil("robots.txt", mono: true),
        Satzteil(", den "),
        Satzteil("noindex", mono: true),
        Satzteil("-Meta-Tag und den Header "),
        Satzteil("X-Robots-Tag", mono: true),
        Satzteil(". Ein Schutz vor unbefugtem Zugriff ist das nicht; dafür sorgt die Anmeldung."),
    ]

    /// „Konfiguration“ (`page.tsx:170-174`), in Stücken.
    public static let konfiguration: [Satzteil] = [
        Satzteil("Regelparameter, Aktoren und Grenzwerte stehen in "),
        Satzteil("CONFIGURATION.md", mono: true),
        Satzteil(
            " und im Entity-Mapping, das die Brücke beim Start aus dem Repository lädt. Die Annahmen der Wärmerechnung stehen in dieser App unter:"
        ),
    ]

    /// Der Verweis am Fuß des Abschnitts (`page.tsx:173`) und sein Ziel.
    ///
    /// Das Ziel gibt es in der App (``Bereiche``, Reiter „Annahmen“); der Weg dorthin von dieser
    /// Seite fehlte. Geschrieben wie die anderen Fußverweise der App, mit dem Winkel am Ende
    /// (`Seiten/Technik/ReglerSeite.swift:334-335`).
    public static let annahmenverweis = "Wärme › Annahmen ›"
    /// Wohin ``annahmenverweis`` führt.
    public static let annahmenweg = "/waerme/annahmen"

    // MARK: - Die Methode

    /// Die drei Sätze, die wirklich Begründung sind und darum zugeklappt stehen dürfen.
    ///
    /// **Warum nur noch drei und nicht mehr.** Bis zum Umbau stand ein Fünftel dieser Seite in
    /// einem zugeklappten ``Methode``, während die Vorlage alles sichtbar schreibt. ``Methode``
    /// ist für Rechenwege gedacht („Wie das gerechnet ist“); hier wird nichts gerechnet, hier
    /// steht die Bedienungsanleitung - und die gehört nach oben, sichtbar. Übrig bleibt, was
    /// auch in der Vorlage nicht im Fließtext der Seite steht, sondern in den Kommentaren des
    /// Codes: die drei Vorbehalte zum Token, zur Rolle und zum Protokoll.
    public static let methode: [String] = [
        "Das Token liegt im Schlüsselbund dieses Geräts und ist durch die Gerätesperre geschützt. Es verlässt das Gerät nur als Authorization-Kopfzeile.",
        "Die Rolle „Gast“ blendet in dieser App aus, was nicht in fremde Hände gehört. Sie sperrt nichts am Dienst: wer das Token hat, darf dort alles. Für einen echten Gastzugang zeigt man die App auf das Dashboard und paart dort mit dem Gast-Token.",
        "Jede Änderung, die von hier ausgeht, steht im Protokoll des Dienstes mit dem Namen dieses Geräts und nicht mit dem eines Menschen. Am iPad im Flur kann jeder gestanden haben.",
    ]
}
