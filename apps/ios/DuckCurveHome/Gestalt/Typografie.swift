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
    /// Der Name, unter dem die Schrift im Bundle liegt. Muss zu `Info.plist` passen.
    static let sans = "IBMPlexSans"
    static let sansHalbfett = "IBMPlexSans-SemiBold"
    static let mono = "IBMPlexMono"

    // MARK: - Text

    /// Die Ueberschrift einer Seite.
    public static let titel = Font.custom(sansHalbfett, size: 21, relativeTo: .title3)
    /// Die Ueberschrift einer Karte.
    public static let karte = Font.custom(sansHalbfett, size: 15, relativeTo: .headline)
    /// Lauftext und Beschriftungen.
    public static let text = Font.custom(sans, size: 15, relativeTo: .body)
    public static let klein = Font.custom(sans, size: 13, relativeTo: .footnote)
    public static let winzig = Font.custom(sans, size: 11.5, relativeTo: .caption2)

    /// Die Sperrschrift ueber einer Karte: „HEUTE", „PUFFER".
    ///
    /// Am Handy nicht verwenden - `handy.css` hat sie dort absichtlich abgeschafft
    /// („Ueberschriften sind lesbare Schrift, keine Sperrschrift").
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
