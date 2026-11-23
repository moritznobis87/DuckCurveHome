import Foundation

/// Die festen Sätze und Stufen der Wiedergabeseite.
///
/// **Warum sie im Kern stehen.** Diese Sätze kommen von nirgends her - sie stehen in der Vorlage
/// im Quelltext (`Wiedergabe.tsx:289-317`, `Tagesuhr.tsx:288-313`, `handy.css:400`). Irgendwo
/// müssen sie also wohnen, und im Kern sind sie geprüft und nicht in einer Ansicht vergraben, die
/// nur ein Mac lesen kann. Dasselbe gilt für die Stufen von Tempo und Schrittweite: eine Liste von
/// Knöpfen ist Darstellung, aber *welche* Stufen es gibt, ist eine Festlegung über die Abfrage.
public enum Wiedergabeworte {

    // MARK: - Tempo und Schrittweite

    /// Bilder je Sekunde. **Bei 5-Minuten-Schritten ist 12 ein Tag in 24 Sekunden**
    /// (`Wiedergabe.tsx:36-37`).
    public static let tempi: [Int] = [2, 6, 12, 24]
    public static let tempoVorgabe = 12

    /// Die Auflösungen, die der Dienst kennt (`Wiedergabe.tsx:38`). Fünf Minuten ist die Vorgabe
    /// der Abfrage (`Api.swift:263`); eine Minute ist für einen einzelnen Vorfall da.
    public static let schritte: [Int] = [1, 5, 15]
    public static let schrittVorgabe = 5

    /// Wie lange ein Durchlauf bei diesem Tempo dauert, in Sekunden - für den Methodensatz.
    ///
    /// Abgerundet auf ganze Sekunden wie die Vorlage (`de(anzahl / tempo, 0)`); ein Tempo von
    /// null gäbe keine Dauer, sondern eine Division.
    public static func sekundenJeDurchlauf(anzahl: Int, tempo: Int) -> Double? {
        guard tempo > 0, anzahl > 0 else { return nil }
        return Double(anzahl) / Double(tempo)
    }

    /// Der Takt des Abspielers: eine Sekunde geteilt durch das Tempo.
    public static func takt(tempo: Int) -> Duration {
        .milliseconds(max(1, Int((1000.0 / Double(max(1, tempo))).rounded())))
    }

    // MARK: - Die Absicht des Fahrplans

    /// Was in der Fahne unter der Wärmepumpenzeile steht (`Tagesband.tsx:203`).
    ///
    /// **Drei Fälle, nicht zwei.** Ohne aufbewahrten Fahrplan steht nicht „wollte nicht
    /// anfordern“, denn das wäre ein Nein, das niemand gesagt hat (`Tagesuhr.tsx:23-26`).
    public static func absichtssatz(_ absicht: Bool?) -> String {
        guard let absicht else { return "kein aufbewahrter Fahrplan" }
        return absicht ? "der Fahrplan wollte anfordern" : "der Fahrplan wollte nicht anfordern"
    }

    // MARK: - Die Karte „Zu diesem Tag“

    public static let karteTag = "Zu diesem Tag"

    /// Der feste Satz, der dazukommt, wenn Bilder fehlen (`Wiedergabe.tsx:293-297`).
    ///
    /// Er sagt, warum keine Lücke überbrückt wird - und das ist die ganze Begründung der
    /// Darstellung: „ein ruhiges Haus und ein blindes Messsystem sähen im Schema gleich aus“.
    public static let luecke =
        "Die fehlenden Bilder sind als Lücke zu sehen: der Ring bleibt dort offen, und im Band "
        + "reißt die Linie ab. Überbrückt wird nichts, denn ein ruhiges Haus und ein blindes "
        + "Messsystem sähen im Schema gleich aus."

    // MARK: - Zustände

    /// Solange die Antwort unterwegs ist (`Wiedergabe.tsx:223`).
    public static let wirdGeholt = "Der Tag wird geholt."

    /// Was dasteht, wenn die Antwort da ist und kein Bild enthält (`Wiedergabe.tsx:224`).
    ///
    /// Der Dienst sagt im ersten Hinweis, warum; nur wenn er schweigt, steht dieser Ersatz da.
    /// Vorher blieb an dieser Stelle dauerhaft „Wird geholt …“ stehen - ein Tag ohne Messung sah
    /// damit aus wie ein Netzproblem.
    public static func ohneBilder(_ hinweise: [String]) -> String {
        hinweise.first ?? "Für diesen Tag liegen keine Bilder vor."
    }

    // MARK: - Die Bühne

    /// Der Kicker der Seite (`waerme/wiedergabe/page.tsx:10`).
    ///
    /// Am Telefon ist er in der Vorlage ausgeblendet (`AreaNav.tsx:96`, `hidden md:block`), also
    /// steht er auch hier nur in regulärer Breite.
    public static let seitenkicker = "Ein Tag am Anlagenschema · zum Durchfahren"

    /// Der Hinweis unter der rollenden Zeichnung (`handy.css:400`).
    ///
    /// **Nur in schmaler Breite**, und zwar aus dem Grund, den der Kommentar dort nennt: „Das
    /// Schema ist eine Zeichnung im Querformat und rollt zur Seite. Der Hinweis sagt es, statt
    /// dass die rechte Hälfte unbemerkt fehlt.“
    public static let wischhinweis = "zur Seite wischen: Strom, Erzeuger, Speicher, Verbraucher  ›"

    /// Was ein Vorleseprogramm über die Uhr sagt (`Tagesuhr.tsx:184`).
    public static let uhrName =
        "Tagesuhr: der Tag als Ring, Mitternacht oben. Bedienung über den Schieber in der Leiste."

    /// Der Name des Schiebers (`Wiedergabe.tsx:254`).
    public static let schieberName = "Zeitpunkt"
    /// Die Beschriftung der Schrittwahl (`Wiedergabe.tsx:214`).
    public static let schrittWort = "Schritt"

    /// Was ein Tempoknopf einem Vorleseprogramm sagt (`Wiedergabe.tsx:268`).
    public static func tempoName(_ tempo: Int) -> String {
        "Tempo \(tempo) Bilder je Sekunde"
    }

    // MARK: - Die Methode

    public static let methodeTitel = "Was dieses Bild ist"

    /// Die Zeile, die auch zugeklappt dasteht.
    ///
    /// **Abweichung von der Vorlage, und mit Grund.** Dort steht „· Leertaste spielt, Pfeile
    /// gehen Bild für Bild“ (`Wiedergabe.tsx:303`). Eine Leertaste gibt es auf einem Telefon
    /// nicht; was von derselben Entscheidung bleibt, ist der zweite Teil - der Schieber ist das
    /// Bedienelement, „ein Kreis, auf dem man zielen muss, ist keines“ (`Tagesuhr.tsx:31-33`).
    public static let methodeKurz =
        "dasselbe Schema wie unter Anlage, aus der Minutenreihe nachgebaut · Schieber und Ring "
        + "fahren durch den Tag"

    /// Die drei Absätze der Methode (`Wiedergabe.tsx:305-317`).
    ///
    /// Der dritte trägt die Stelle, an der Schrittweite und Tempo eingesetzt werden; sein erster
    /// Satz ist derselbe Tausch wie in `methodeKurz`.
    public static func methode(
        uhrzeit: String, schrittMin: Int, tempo: Int, anzahl: Int
    ) -> [String] {
        var aus = [
            "Dasselbe Schema wie auf der Seite Anlage, nur aus der Minutenreihe nachgebaut. Es "
                + "gibt genau eine Zusammensetzung des Bildes; die Wiedergabe stellt ihr die "
                + "Eingänge von \(uhrzeit) hin, der Augenblick die von jetzt. Deshalb kann hier "
                + "nichts stehen, was dort nicht stünde, und nichts fehlen, was dort steht.",
            "Die Uhr zeigt den Tag als Ring: außen der Preis, dann die Sonne, dann was der "
                + "Fahrplan für die Wärmepumpe vorsah, und innen, was sie tat. Wo der Umriss der "
                + "Absicht steht und darunter nichts gefüllt ist, wollte der Fahrplan und die "
                + "Maschine nicht. Das Band zeigt dasselbe mit Achsen. Die Uhr lässt sich "
                + "anfassen und drehen.",
        ]
        var dritter =
            "Bedienung: der Schieber in der Leiste fährt Bild für Bild, ein Griff in die Uhr "
            + "oder ins Band springt an eine Stelle und hält die Wiedergabe an."
        if let s = sekundenJeDurchlauf(anzahl: anzahl, tempo: tempo) {
            dritter +=
                " Bei \(schrittMin) Minuten Schritt und \(tempo)× läuft der Tag in "
                + "\(Formate.zahl(s, stellen: 0)) Sekunden durch."
        }
        aus.append(dritter)
        return aus
    }
}
