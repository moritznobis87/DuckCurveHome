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

    /// Die Groesse des Kickers, und warum sie 13 ist und nicht 10,5.
    ///
    /// **Das war die aelteste offene Abweichung der App.** Die Vorlage setzt `.kicker` als
    /// IBM Plex **Mono** in 13 px mit 0,13 em Sperrung in Grossbuchstaben
    /// (`globals.css:57-64`); die App schrieb ihn bis zum 21.11.2026 als Sans-Halbfett in
    /// 10,5 Punkten mit 1,4 Punkten Sperrung. Das ist kein Geschmacksunterschied: Mono ist
    /// die Schrift, in der in dieser Anwendung die *Zahlen* stehen, und der Kicker gehoert
    /// dort hin, weil er eine Zahl beschriftet und nicht einen Absatz fuehrt. Halbfett in
    /// 10,5 las sich dagegen wie eine kleine Ueberschrift - also wie das, was der Kicker
    /// gerade nicht ist.
    ///
    /// **Die Groesse ist ein eigener Wert**, weil die Vorlage sie an einzelnen Stellen
    /// ueberschreibt und dabei alles andere an `.kicker` stehen laesst: 12 im Ruhebild
    /// (`globals.css:401` `.ambiente-vorschau-wort`) und am Lebenszeichen
    /// (`globals.css:391` `.ambiente-live`), 11 in der Kopfzeile eines Raumprotokolls
    /// (`Protokoll.tsx:155`) und ueber der Abweichungsskala (`RoomsReport.tsx:48`), 10 im
    /// Tabellenkopf der Kostenaufstellung (`CostReport.tsx:197`). Darum nimmt ``Kicker``
    /// eine Groesse und nicht nur ein Wort.
    public static let kickerGroesse: CGFloat = 13

    /// `letter-spacing: 0.13em` (`globals.css:61`) - in em und nicht in Punkten, darum ein
    /// Faktor. Eine feste Punktzahl waere bei 10 Punkten Schrift eine andere Sperrung als bei
    /// 13, und genau das war der zweite Teil der alten Abweichung.
    public static let kickerSperrung: CGFloat = 0.13

    /// Die Textstufe, an der die Sperrschrift haengt: `.footnote` und nicht `.caption2`.
    ///
    /// 13 Punkte ist die Grundgroesse von `.footnote`, und „Groesserer Text“ soll den Kicker
    /// auf derselben Kurve wachsen lassen wie den Text, dessen Groesse er teilt (``klein``).
    /// Solange der Kicker 10,5 Punkte hatte, war `.caption2` die naehere Stufe - mit der
    /// Groesse zog der Anker um.
    public static let kickerStil: Font.TextStyle = .footnote

    /// Die Sperrschrift ueber einer Karte: „HEUTE“, „PUFFER“ - die Schrift allein, ohne
    /// Grossschrift und ohne Sperrung. Die Zeile, wie sie auf einer Karte steht, ist
    /// ``Kicker``; diese Konstante ist fuer Stellen, die nur die Schrift brauchen.
    ///
    /// **Ueber einer Karte am Handy nicht verwenden** - `handy.css` hat sie dort absichtlich
    /// abgeschafft („Ueberschriften sind lesbare Schrift, keine Sperrschrift“,
    /// `handy.css:184`), und ``Karte`` schaltet ihre Kopfzeile darum selbst auf 15 Punkte um.
    ///
    /// **Auf einer Kennzahlkachel gilt das nicht**, und das ist keine Nachlaessigkeit: die
    /// Vorlage stellt am Handy ausdruecklich nur die Kartenkoepfe um und laesst den Kicker in
    /// der Kachel gesperrt (`handy.css:184` gegen `handy.css:201`
    /// `.kpi-grid > .card > .kicker`). Der Grund ist der Unterschied der beiden: eine
    /// Ueberschrift fuehrt einen Abschnitt und wird gelesen, ein Kachelwort beschriftet eine
    /// Zahl und wird gestreift - und gestreift wird es leichter, wenn es sich von der Zahl
    /// darunter auch in der Form unterscheidet.
    public static let kicker = Font.custom(mono, size: kickerGroesse, relativeTo: kickerStil)

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

    /// Dieselbe Groesse, aber im echten SemiBold der Hausschrift.
    ///
    /// **Warum nicht `sans(13).weight(.semibold)`.** `.weight` sucht auf einer eingebundenen
    /// Schrift keinen Schnitt aus - es laesst iOS den Regular synthetisch fetten, und das
    /// trifft nicht denselben Strich wie der Schnitt, der unter dem PostScript-Namen
    /// `IBMPlexSans-SmBld` im Bundle liegt (die Falle steht oben bei ``sansHalbfett``). Die
    /// Vorlage setzt fuer den gewaehlten Knopf ausdruecklich Gewicht 600
    /// (`globals.css:894`, `.kl-knopf` im Zustand gedrueckt), also braucht es den benannten
    /// Schnitt und nicht das synthetische Gewicht.
    ///
    /// **Es gibt keine Konstante dafuer**, weil die Vorlage dieses Gewicht an Groessen
    /// zwischen den Stufen der App nennt - derselbe Grund, der ``sans(_:relativeTo:)``
    /// rechtfertigt. `relativeTo` bleibt, damit „Groesserer Text“ weiter wirkt.
    public static func sansHalbfett(_ groesse: CGFloat, relativeTo: Font.TextStyle = .body)
        -> Font
    {
        Font.custom(Self.sansHalbfett, size: groesse, relativeTo: relativeTo)
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
///
/// **Groesse und Farbe sind Parameter, weil die Vorlage sie stellenweise ueberschreibt.**
/// `.kicker` ist in der Vorlage eine Klasse, und wer eine zweite danebenschreibt
/// (`class="ambiente-live kicker"`, `Ambiente.tsx:47`), aendert genau das eine Mass und erbt
/// den Rest. Ohne diese beiden Parameter musste jede solche Stelle den ganzen Kicker von Hand
/// nachbauen - so entstand `Ruhekicker` im Ruhebild und das Lebenszeichen daneben, drei
/// Zeilen, die dasselbe sagten. Beide Vorgaben sind gesetzt, darum laeuft jeder alte Aufruf
/// `Kicker(wort:)` unveraendert weiter.
///
/// Die Sperrung kommt nicht mitgegeben: sie haengt in der Vorlage an der Groesse
/// (`0.13em`, ``Schrift/kickerSperrung``) und waere als eigener Parameter eine Einladung,
/// die beiden auseinanderlaufen zu lassen.
struct Kicker: View {
    let wort: String
    /// Die Groesse in Punkten. Vorgabe ist ``Schrift/kickerGroesse``; kleinere Werte nennt die
    /// Vorlage an einzelnen Stellen, sie stehen bei ``Schrift/kickerGroesse``.
    var groesse: CGFloat = Schrift.kickerGroesse
    /// Vorgabe ist `--text-kicker` (`globals.css:63`, in `tokens.css:35` das Nebelgrau).
    /// `.ambiente-live` (`globals.css:391`) setzt dort `--text-2`, weil die Farbe daneben der
    /// atmende Punkt traegt und ein rotes Wort neben einem roten Punkt dasselbe zweimal sagt.
    var farbe: Color = Farbe.kicker

    var body: some View {
        Text(wort.uppercased())
            .font(Schrift.mono(groesse, relativeTo: Schrift.kickerStil))
            .tracking(groesse * Schrift.kickerSperrung)
            .foregroundStyle(farbe)
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

extension Schrift {
    /// Eine Zahl in einer festen Groesse. Für Zahlen in Feldern fester Größe: eine Schrift, die mit „Größerer Text“ wächst,
    /// läuft dort aus ihrem Feld.
    static func custom(_ groesse: CGFloat) -> Font {
        Font.custom(mono, fixedSize: groesse)
    }
}
