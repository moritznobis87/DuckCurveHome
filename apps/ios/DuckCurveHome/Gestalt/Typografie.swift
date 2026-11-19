import DuckCurveKit
import SwiftUI

/// Die Schriften: IBM Plex Sans fuer Text, IBM Plex Mono fuer Zahlen.
///
/// **Warum Zahlen eine eigene Schrift bekommen.** An einer Wandanzeige stehen Zahlen
/// uebereinander - vier Kennzahlen in einer Reihe, eine Tabelle mit Stunden, die Achse eines
/// Diagramms. In einer Proportionalschrift ist die Eins schmaler als die Null, und dann
/// springen die Spalten bei jedem Takt. Mono loest das, und IBM Plex Mono passt zur Sans, weil
/// es dieselbe Familie ist.
///
/// **Was von iOS kommt und was nicht.** Die Groessen folgen `Font.TextStyle`, damit „Groesserer
/// Text" aus den Bedienungshilfen wirkt - ein iPad an der Wand wird von Leuten gelesen, die
/// zwei Meter entfernt stehen, und wer dort die Schrift hochstellt, soll sie hochgestellt
/// bekommen. Nur die ganz grossen Zahlen (das Ambiente, die fuehrende Zahl einer Seite) sind
/// feste Groessen: sie sind schon so gross, dass eine weitere Stufe den Umbruch zerlegt.
public enum Schrift {
    /// Die PostScript-Namen der Schriften, aus den Dateien gelesen.
    ///
    /// **Hier steckt eine Falle, die niemand im Code sieht.** `Font.custom` nimmt einen Namen und
    /// faellt stillschweigend auf die Systemschrift zurueck, wenn er nicht stimmt - keine
    /// Warnung, kein Fehler, nur eine App, die „fast richtig" aussieht. Und der Name ist nicht
    /// der Dateiname: aus `IBMPlexSans-SemiBold.otf` kommt
    ///
    ///     Familie:     IBM Plex Sans SmBld
    ///     PostScript:  IBMPlexSans-SmBld
    ///
    /// Also `SmBld` und nicht `SemiBold`. Nachgelesen wurde das in der Namenstabelle der
    /// Schriftdatei selbst, nicht im Dateinamen - der luegt hier.
    static let sans = "IBMPlexSans"
    static let sansHalbfett = "IBMPlexSans-SmBld"
    static let mono = "IBMPlexMono"

    // MARK: - Text

    /// Die Ueberschrift einer Seite.
    /// Der Name der Anwendung im Kopf. 16 Punkte halbfett, wie `brand-name` im Dashboard.
    public static let marke = Font.custom(sansHalbfett, size: 16, relativeTo: .headline)

    public static let titel = Font.custom(sansHalbfett, size: 21, relativeTo: .title3)
    /// Die Ueberschrift einer Karte.
    public static let karte = Font.custom(sansHalbfett, size: 15, relativeTo: .headline)
    /// Lauftext und Beschriftungen.
    public static let text = Font.custom(sans, size: 15, relativeTo: .body)
    public static let klein = Font.custom(sans, size: 13, relativeTo: .footnote)
    public static let winzig = Font.custom(sans, size: 11.5, relativeTo: .caption2)

    /// Die Sperrschrift ueber einer Karte: „HEUTE", „PUFFER".
    ///
    /// **Ueber einer Karte am Handy nicht verwenden** - `handy.css` hat sie dort absichtlich
    /// abgeschafft („Ueberschriften sind lesbare Schrift, keine Sperrschrift"), und ``Karte``
    /// schaltet ihre Kopfzeile darum selbst auf 15 Punkte um.
    ///
    /// **Auf einer Kennzahlkachel gilt das nicht**, und das ist keine Nachlaessigkeit: die
    /// Vorlage stellt am Handy ausdruecklich nur die Kartenkoepfe um und laesst den Kicker in
    /// der Kachel gesperrt (`handy.css:184` gegen `handy.css:201`
    /// `.kpi-grid > .card > .kicker`). Der Grund ist der Unterschied der beiden: eine
    /// Ueberschrift fuehrt einen Abschnitt und wird gelesen, ein Kachelwort beschriftet eine
    /// Zahl und wird gestreift - und gestreift wird es leichter, wenn es sich von der Zahl
    /// darunter auch in der Form unterscheidet.
    public static let kicker = Font.custom(sansHalbfett, size: 10.5, relativeTo: .caption2)

    /// Der Satz der Startseite: die Erklaerung des Reglers, gross und ruhig.
    public static let satz = Font.custom(sans, size: 19, relativeTo: .title3)

    // MARK: - Zahlen

    /// Eine Zahl in einer Zeile Text.
    public static let zahl = Font.custom(mono, size: 15, relativeTo: .body)
    public static let zahlKlein = Font.custom(mono, size: 12.5, relativeTo: .caption)
    /// Die Zahl in einer Kachel.
    public static let zahlGross = Font.custom(mono, size: 27, relativeTo: .title2)
    /// Die fuehrende Zahl einer Seite am Handy, und die Uhr im Kopf.
    /// Die grosse Zahl einer Raumkachel.
    ///
    /// **Kleiner als die fuehrende Zahl des Docks, groesser als jede andere.** Auf einer
    /// Raumkachel stehen neben ihr das Ziel und ein Abzeichen; mit 40 Punkten draengte sie beide
    /// aus der Spalte. Die Vorlage nennt 34 am Schirm und 36 am Telefon (`handy.css:368`).
    /// Eine Schrift in genau der Groesse, die die Vorlage nennt.
    ///
    /// **Warum nicht eine der benannten Groessen.** Die Vorlage nennt fuer einzelne Stellen
    /// Groessen, die zwischen den Stufen der App liegen (14,5 fuer die Saetze des Ausblicks,
    /// 15,5 fuer den Satz neben dem Preis). Sie auf die naechste Stufe zu runden hiesse, die
    /// Rangfolge zu aendern, die dort gemeint ist. `relativeTo` bleibt dabei, damit „Groesserer
    /// Text" weiter wirkt.
    public static func sans(_ groesse: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
        Font.custom(Self.sans, size: groesse, relativeTo: relativeTo)
    }

    public static func mono(_ groesse: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
        Font.custom(Self.mono, size: groesse, relativeTo: relativeTo)
    }

    public static let zahlRaum = Font.custom(mono, size: 34, relativeTo: .title)

    public static let zahlFuehrend = Font.custom(mono, size: 40)
    /// Die Zahlen des Ambiente-Bildes.
    public static let zahlAmbiente = Font.custom(mono, size: 64)

    /// Die Achsenbeschriftung eines Diagramms. Klein, aber Mono: die Stunden stehen untereinander.
    public static let achse = Font.custom(mono, size: 10.5, relativeTo: .caption2)
}

/// Eine Zahl mit ihrer Einheit, wie sie ueberall in dieser Anwendung steht.
///
/// Die Einheit ist kleiner, in Sans und gedaempft - so liest das Auge erst die Zahl. Das
/// schmale Leerzeichen zwischen beiden kommt aus `Formate` und ist geschuetzt, damit „3,6 kW"
/// nicht umbricht.
struct Zahl: View {
    let wert: String
    var einheit: String?
    var schrift: Font = Schrift.zahl
    var einheitSchrift: Font = Schrift.winzig
    var farbe: Color = Farbe.text1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(wert)
                .font(schrift)
                .foregroundStyle(farbe)
                .monospacedDigit()
            if let einheit, wert != Formate.leer {
                Text(einheit)
                    .font(einheitSchrift)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }
}

/// Die Sperrschrift-Zeile ueber einer Karte.
struct Kicker: View {
    let wort: String

    var body: some View {
        Text(wort.uppercased())
            .font(Schrift.kicker)
            .tracking(1.4)
            .foregroundStyle(Farbe.kicker)
    }
}

extension View {
    /// Der Hintergrund einer Seite.
    func seitengrund() -> some View {
        background(Farbe.seitengrund.ignoresSafeArea())
    }

    /// Die Schrift der Anwendung auf einen ganzen Baum legen.
    func hausschrift() -> some View {
        font(Schrift.text).foregroundStyle(Farbe.text1)
    }
}
