import Foundation

/// Die festen Sätze der Nachbetrachtungsseite.
///
/// **Warum sie im Kern stehen.** Diese Wörter kommen von nirgends her - sie stehen in der
/// Vorlage im Quelltext (`apps/web/src/components/waerme/Nachbetrachtung.tsx`,
/// `Kostentreppe.tsx`, `Tagesvergleich.tsx`). Irgendwo müssen sie also wohnen, und im Kern sind
/// sie geprüft, auf jedem Rechner übersetzbar und nicht in einer Ansicht vergraben, die nur ein
/// Mac lesen kann. Dasselbe Muster wie ``Fahrplanworte`` und ``Wiedergabeworte``.
///
/// **Sie sind wörtlich und nicht ungefähr.** „Der Tag wird bewertet. Der Vergleichslauf mit
/// perfekter Voraussicht braucht einige Sekunden.“ sagt zwei Dinge, die ein kürzeres „Wird
/// gerechnet …“ nicht sagt: *dass* gerechnet wird und *warum* es dauert. Wand und App sollen
/// Zeichen für Zeichen dasselbe zeigen.
public enum Nachbetrachtungsworte {

    // MARK: - Kartenköpfe

    /// Der Titel der Kopfkarte (`Nachbetrachtung.tsx:93`).
    public static let kopfTitel = "Was hat der Tag gekostet?"

    public static let vergleichTitel = "Der Tag, Linie für Linie"
    /// Was rechts im Kopf der Vergleichskarte steht (`Nachbetrachtung.tsx:152`).
    public static let vergleichDazu =
        "oben die Umstände, in der Mitte wann jede Linie Strom zieht, unten was dabei auflief"

    public static let tabelleTitel = "Die Linien in Zahlen"
    /// „über die 96 verglichenen Viertelstunden“ (`Nachbetrachtung.tsx:181`).
    public static func tabelleDazu(nVerglichen: Int?) -> String {
        "über die \(nVerglichen ?? 0) verglichenen Viertelstunden"
    }

    /// Der Titel der offenen Hinweiskarte (`Nachbetrachtung.tsx:239`).
    public static let hinweiseTitel = "Zu diesem Tag"

    // MARK: - Laden, Fehler, Verweise

    /// **Warum so lang.** Die Seite rechnet einen ganzen Tag mit perfekter Voraussicht nach, und
    /// das dauert Sekunden. Ein Ladetext, der das nicht sagt, lässt die Seite kaputt aussehen
    /// (`Nachbetrachtung.tsx:118`).
    public static let laedtSatz =
        "Der Tag wird bewertet. Der Vergleichslauf mit perfekter Voraussicht braucht einige "
        + "Sekunden."

    /// Der Satz, der dasteht, wenn der Dienst keinen eigenen schickt (`Nachbetrachtung.tsx:71`).
    public static let fehlerSatz = "Die Nachbetrachtung ist gerade nicht zu erreichen."

    /// Der Verweis in die Wiedergabe (`Nachbetrachtung.tsx:113`).
    public static let zurWiedergabe = "diesen Tag in der Wiedergabe ansehen"

    /// Der Kicker über dem Vergleich ohne Preisblick (`Nachbetrachtung.tsx:137`).
    public static let ohnePreisblick = "Ohne Preisblick"
    /// Der Verweis auf die Kostenseite (`Nachbetrachtung.tsx:140`).
    public static let zurRechnung = "Zur Rechnung ›"

    // MARK: - Die Kostentreppe

    /// Was die Treppe für Hilfstechnik ist (`Kostentreppe.tsx:80`).
    public static let treppeName = "Kostentreppe vom Versprechen des Fahrplans zur Wirklichkeit"

    /// Die Trennzeile vor den Bezugszeilen (`Kostentreppe.tsx:84`).
    public static let zumVergleich = "zum Vergleich gerechnet"

    /// Der Vermerk an einer geschätzten Linie (`Kostentreppe.tsx:43`,
    /// `Nachbetrachtung.tsx:204`).
    ///
    /// Mit dem Mittelpunkt davor, so wie die Vorlage ihn setzt; er trennt den Vermerk vom Namen,
    /// ohne eine zweite Zeile zu brauchen.
    public static let geschaetzt = "· geschätzt"

    // MARK: - Der Tagesvergleich

    public static let flaechePreis = "Preis in ct/kWh"
    public static let flaecheSonne = "Überschuss in kW"
    public static let flaecheKosten = "aufgelaufene Kosten in €"

    /// Das Wort über dem Schleier, nur in der Preisfläche (`Tagesvergleich.tsx:107`).
    public static let nichtVerglichen = "nicht verglichen"
    /// Der Satz in der Auskunft (`Tagesvergleich.tsx:245`).
    public static let nichtVerglichenSatz = "Diese Viertelstunde wird nicht verglichen."
    /// Wo kein Preis eingetreten ist (`Tagesvergleich.tsx:252`).
    public static let preisUnbekannt = "Preis unbekannt"
    /// Die Spalte „bis hier“ der Auskunft (`Tagesvergleich.tsx:258`).
    public static let bisHier = "bis hier"

    /// Die langen Namen der Linien (`Tagesvergleich.tsx:39-44`).
    public static let lang: [String: String] = [
        "erster": "erster Fahrplan",
        "letzter": "letzter Stand",
        "wirklich": "wirklich",
        "perfekt": "perfekte Voraussicht",
    ]

    /// Die knappen Namen für die schmale Spalte am Telefon (`Tagesvergleich.tsx:46`).
    public static let knapp: [String: String] = [
        "erster": "erster Plan",
        "letzter": "letzter Stand",
        "wirklich": "wirklich",
        "perfekt": "perfekt",
    ]

    /// Der Name, unter dem eine Linie im Bild steht.
    ///
    /// **Der eigene Name des Dienstes ist der Rückfall und nicht die Regel.** Die Vorlage nimmt
    /// ihre kurzen Namen und fällt auf `name_de` zurück (`Nachbetrachtung.tsx:158`,
    /// `Tagesvergleich.tsx:87`): „der erste Fahrplan des Tages, mit den eingetretenen Preisen
    /// bewertet“ ist als Streifenbeschriftung richtig und unlesbar.
    public static func linienname(_ l: Linie, schmal: Bool) -> String {
        if schmal, let k = knapp[l.key] { return k }
        return lang[l.key] ?? l.nameDe
    }

    /// Der Text an den vier Helligkeitskästchen der Legende (`Nachbetrachtung.tsx:167`).
    ///
    /// **Geteilt durch vier, nicht durch die Schrittweite.** Die Vorlage schreibt `wp_kw / 4`
    /// (also die Arbeit einer Viertelstunde bei Nennleistung) und rundet auf zwei Stellen.
    public static func stufenlegende(wpKw: Double) -> String {
        "Strom der Wärmepumpe je Viertelstunde, bis "
            + Formate.zahl(wpKw / 4, stellen: 2) + Formate.schmalesLeerzeichen + "kWh"
    }

    public static let ofenLegende = "Ofen brennt"

    // MARK: - Hinweise und Methode

    /// Woran ein Hinweis über eine fehlende Linie zu erkennen ist (`Nachbetrachtung.tsx:87`).
    ///
    /// **Das Anführungszeichen steht als Fluchtfolge und nicht als Zeichen.** U+201E ist das
    /// öffnende deutsche Zeichen; am Ende eines Swift-Textes gefolgt vom ASCII-Zeichen sieht es
    /// aus wie ein Zitat, das mit dem falschen Zeichen geschlossen wurde - der Fehler, den
    /// `tools/ios-typpruefen.py` als Regel 10 fängt. Hier ist es richtig, aber nicht zu
    /// erkennen; geschrieben als `\u{201E}` ist beides wieder dasselbe.
    public static let linienhinweisAnfang = "Die Linie \u{201E}"

    /// Die Zeile, die am zugeklappten Methodenblock dasteht (`Nachbetrachtung.tsx:248`).
    public static let methodeKurz =
        "jede Linie mit derselben Rechnung über dieselben Viertelstunden · Überschuss zur "
        + "Vergütung, der Rest zum Bezugspreis"

    /// Der Vorgabetitel der Vorlage (`components/ui/Methode.tsx:18`) - nicht der der App
    /// („Wie das gerechnet ist“, `Seiten/Bericht.swift:524`).
    public static let methodeTitel = "Wie gerechnet wird"

    /// Was die Spalte „im Mittel“ erklärt (`Nachbetrachtung.tsx:191`).
    public static let imMittelDazu =
        "Was die Kilowattstunde Strom dieser Linie im Mittel gekostet hat. Hängt nicht an der "
        + "Menge."
}
