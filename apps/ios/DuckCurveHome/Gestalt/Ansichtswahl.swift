import DuckCurveKit
import SwiftUI

/// Der Umschalter zwischen gleichrangigen Ansichten einer Seite.
///
/// **Diese Ansicht fehlte.** Sie wurde an drei Stellen benutzt – über der Tageskurve
/// (Gestern/Heute/Morgen), auf der Haus-Seite (Liste/Modell) und in der Kopfzeile für die
/// Spanne (Tag/Woche/Monat/Jahr) – und war nie geschrieben. Ein Parser bemerkt das nicht: der
/// Aufruf ist syntaktisch einwandfrei, es gibt den Namen nur nicht. Erst der Compiler hat es
/// gesagt, und das ist genau die Sorte Lücke, für die der erste Übersetzungslauf da ist.
///
/// **Verglichen wird über `weg`, nicht über Gleichheit.** Eine der Aufrufstellen
/// übergibt `Ansicht(weg: ansicht.rawValue, name: "")` – sie kennt den Namen an der Stelle
/// nicht und braucht ihn auch nicht. Zwei `Ansicht`-Werte sind nur gleich, wenn auch der Name
/// übereinstimmt; wer hier `==` nähme, hätte dort nie etwas ausgewählt. `weg` ist die
/// Kennung, und sie ist es, die zählt.
///
/// **Eine Ansicht, vier Formen - weil die Vorlage vier hat**, genau wie bei ``Tagewahl``. Die
/// acht Stellen, die einen solchen Umschalter zeigen, tragen im Browser nicht dieselbe
/// Gestalt: drei ziehen die Regel `.ansichten`/`.ansicht` (`globals.css:780-783`), der
/// Schalter über der Tageskurve hat seine eigene (`globals.css:247-248`), der im Kartenkopf
/// der Prognoseseite steht in Mono (`ForecastPage.tsx:283-288`), und die Werkzeuge der
/// Haus-Seite sind Kapseln (`globals.css:474-476`). Bis zum 21.11.2026 gab es hier nur eine
/// Form, und sie war keine davon - die Haus-Seite hatte sich darum einen eigenen Satz Pillen
/// in ihre Datei geschrieben. Welche Maße zu welcher Form gehören, steht an
/// ``Ansichtswahl/Form``.
struct Ansichtswahl: View {
    let ansichten: [Ansicht]
    let aktiv: Ansicht
    /// Die Form, die die Vorlage an der aufrufenden Stelle setzt. Vorgabe ist
    /// ``Form/ansichten``, die einzige Form, die sich in der Vorlage mehrere Stellen teilen.
    ///
    /// **Sie steht vor `waehle` und nicht dahinter**, obwohl neue Parameter sonst hinten
    /// stehen: `waehle` wird an jeder Aufrufstelle als angehängter Abschluss übergeben. Swift
    /// überspringt beim Zuordnen eines angehängten Abschlusses nur Parameter, die einen
    /// Vorgabewert haben *und* keine Funktion sind - ein `form` hinter `waehle` wäre also
    /// zusammen mit einem angehängten Abschluss nicht mehr zu setzen. So bleibt jeder
    /// vorhandene Aufruf `Ansichtswahl(ansichten:aktiv:) { … }` unverändert gültig.
    var form: Form = .ansichten
    /// Läuft nur, wenn eine *andere* Ansicht gewählt wird – ein Tippen auf die aktive soll
    /// keine Abfrage auslösen.
    let waehle: (Ansicht) -> Void

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        leiste(form.zuschnitt(schmal: schmal))
    }

    /// **Die Teile einzeln benannt und mit angeschriebenem Typ.** Eine Kette aus Polster,
    /// Grund, Hülle, Rand und vier Fragezeichen ergibt „unable to type-check this expression
    /// in reasonable time“; das sieht man erst auf dem Mac, nicht beim Parsen.
    private func leiste(_ z: Zuschnitt) -> some View {
        let dehnt: Bool = z.dehnt
        return HStack(spacing: z.abstand) {
            ForEach(ansichten) { a in
                knopf(a, z: z, gewaehlt: a.weg == aktiv.weg)
            }
        }
        .padding(z.polster)
        .background(z.grund)
        .clipShape(huelle(z.radius))
        .overlay(rand(z.radius, farbe: z.rand))
        // **Am Telefon über die ganze Breite** (`handy.css:177-179`: `.ansichten` mit
        // `align-self: stretch`, jede Ansicht `flex: 1`; `handy.css:267-268` dasselbe über
        // `flex: 1` am Tagesschalter). Ein Schalter von 120 Punkten in einer 390 Punkte
        // breiten Zeile ist mit dem Daumen schwer zu treffen; über die ganze Breite hat jede
        // Hälfte 190 Punkte.
        .frame(maxWidth: dehnt ? .infinity : nil)
    }

    private func knopf(_ a: Ansicht, z: Zuschnitt, gewaehlt: Bool) -> some View {
        Button {
            if !gewaehlt { waehle(a) }
        } label: {
            beschriftung(a, z: z, gewaehlt: gewaehlt)
        }
        .buttonStyle(.plain)
        // Ohne das liest eine Sprachausgabe nur „Liste, Modell“ vor und sagt nicht, welche
        // der beiden gerade gilt.
        .accessibilityAddTraits(merkmale(gewaehlt))
    }

    private func beschriftung(_ a: Ansicht, z: Zuschnitt, gewaehlt: Bool) -> some View {
        // **Bernstein auf Petrol für das Gewählte** (`globals.css:783`, `.ansicht-an`, und
        // ebenso an den drei anderen Formen). Vorher war es eine Spur heller als der Grund -
        // auf einem Telefon im Sonnenlicht nicht zu sehen, und auf dem Bildschirmfoto nicht
        // zu unterscheiden.
        let wort: String = z.grossbuchstaben ? a.name.uppercased() : a.name
        let farbe: Color = gewaehlt ? z.textGewaehlt : z.text
        let grund: Color = gewaehlt ? z.grundGewaehlt : Color.clear
        return Text(wort)
            .font(z.schrift)
            .fontWeight(z.gewicht)
            .tracking(z.sperrung)
            .foregroundStyle(farbe)
            .lineLimit(1)
            .frame(maxWidth: z.dehnt ? .infinity : nil)
            .padding(.horizontal, z.polsterQuer)
            .padding(.vertical, z.polsterHoch)
            .background(grund)
            .clipShape(huelle(z.knopfradius))
    }

    /// Der Rahmen, verzweigt statt in einer Hülle für beides: `strokeBorder` gibt es nur an
    /// `InsettableShape`, und `AnyShape` ist keine. Ein mittig gezeichneter Strich stünde zur
    /// Hälfte außerhalb - die Vorlage zeichnet ihn mit `border` innen.
    @ViewBuilder private func rand(_ radius: CGFloat?, farbe: Color) -> some View {
        if let radius {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(farbe, lineWidth: 1)
        } else {
            Capsule().strokeBorder(farbe, lineWidth: 1)
        }
    }

    /// Die Hülle zum Beschneiden. Kein Radius heißt Kapsel - so schreibt die Vorlage
    /// `border-radius: 999px` (`globals.css:474-475`).
    private func huelle(_ radius: CGFloat?) -> AnyShape {
        if let radius {
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        return AnyShape(Capsule())
    }

    private func merkmale(_ gewaehlt: Bool) -> AccessibilityTraits {
        gewaehlt ? [.isButton, .isSelected] : [.isButton]
    }
}

extension Ansichtswahl {
    /// Eine Form der Vorlage - ein Fall je Regel, die die Vorlage für einen solchen
    /// Umschalter schreibt.
    enum Form {
        /// `.ansichten` und `.ansicht` (`globals.css:780-783`), am Telefon
        /// `handy.css:178-179`. Gezogen von der Ansichtsleiste eines Reiters
        /// (`AreaNav.tsx:114`), von Liste/Modell der Haus-Seite (`HouseReport.tsx:222`) und -
        /// bis auf zwei Punkte Polster - von der Spannenwahl im Berichtskopf
        /// (`ReportShell.tsx:120-122`). Die einzige Form, die halbfett gesetzt ist
        /// (`font-weight: 500`), und die einzige, die sich mehrere Stellen teilen.
        case ansichten

        /// Der Tagesschalter über der Kurve der Startseite: `.home-tage` und `.home-tag`
        /// (`globals.css:247-248`), am Telefon `handy.css:267-268`, gezogen von
        /// `DayCurve.tsx:155-157`.
        ///
        /// **An der Wand liegt keine Fläche unter den Knöpfen**, nur ein Rand um die Reihe -
        /// anders als bei ``ansichten``, wo es auch so ist, und anders als in der App bis zum
        /// 21.11.2026, die hier ``Farbe/flaeche2`` unterlegte. Die Knöpfe sind breiter und
        /// flacher als bei ``ansichten`` (14/5 gegen 14/6) und einen Punkt größer: „gestern,
        /// heute, morgen“ liest im Vorbeigehen jemand, der zwei Meter weg steht.
        case tagesschalter

        /// Der Umschalter im Kartenkopf der Prognoseseite (`ForecastPage.tsx:283-288`).
        ///
        /// **Mono in Großbuchstaben und ohne Abstand zwischen den Knöpfen.** Er steht in einer
        /// Zeile mit der Gütezahl „MAE 0,76 kW · Bias …“, die in Mono gesetzt ist
        /// (`ForecastPage.tsx:279-281`); eine Proportionalschrift daneben sähe aus wie ein
        /// Fremdkörper. Die Reihe hat `overflow-hidden` und einen Radius, die Knöpfe keinen -
        /// die Hülle beschneidet die Bernsteinfläche an den Ecken.
        case prognosekopf

        /// Die Werkzeuge der Haus-Seite: `.haus-gruppe` (`globals.css:474-476`), gezogen von
        /// `HouseReport.tsx:231-243`.
        ///
        /// **Kapseln auf dunklem Grund, Mono 10,5 in Großbuchstaben.** Sie liegen in der
        /// Vorlage über dem Grundriss und nicht über einer Karte, und dort muss sich die
        /// Gruppe gegen ein Bild behaupten - daher der eigene Grund und der Rand. Diese Form
        /// stand bis zum 21.11.2026 als eigene Funktion `pillen` in `HausSeite.swift`.
        case hausGruppe

        /// Die Maße dieser Form, Zeile für Zeile aus der Vorlage.
        ///
        /// `schmal` ist die Breitenklasse: die Vorlage schreibt zwei dieser vier Formen am
        /// Telefon neu (`handy.css`), die zwei anderen nicht.
        ///
        /// **Warum die zwei breitenlosen Maße `…Masse` heißen.** Ein `static let` darf in
        /// einer Aufzählung nicht so heißen wie einer ihrer Fälle - `Self.prognosekopf` wäre
        /// sonst der Fall und nicht das Maß, und der Übersetzer meldet beides: eine doppelte
        /// Erklärung und einen falschen Rückgabetyp. Die vier Maße mit Breitenklasse tragen
        /// ihr `Breit`/`Schmal` ohnehin, die zwei ohne brauchen darum ein eigenes Wort.
        func zuschnitt(schmal: Bool) -> Zuschnitt {
            switch self {
            case .ansichten:
                return schmal ? Self.ansichtenSchmal : Self.ansichtenBreit
            case .tagesschalter:
                return schmal ? Self.tagesschalterSchmal : Self.tagesschalterBreit
            case .prognosekopf:
                return Self.prognosekopfMasse
            case .hausGruppe:
                return Self.hausGruppeMasse
            }
        }

        // `globals.css:780`: gap 4, padding 4, Rand 1 px `linie2`, radius 4, keine Fläche.
        // `:781`: padding 6px 14px, radius 3, font-size 12, font-weight 500, Schrift `text2`.
        // `:783` gewählt: Grund `amber`, Schrift `petrol`.
        private static let ansichtenBreit = Zuschnitt(
            abstand: 4,
            polster: 4,
            radius: 4,
            grund: .clear,
            rand: Farbe.linie2,
            dehnt: false,
            schrift: Schrift.sans(12, relativeTo: .caption),
            gewicht: .medium,
            sperrung: 0,
            grossbuchstaben: false,
            polsterQuer: 14,
            polsterHoch: 6,
            knopfradius: 3,
            text: Farbe.text2,
            textGewaehlt: Farbe.petrol,
            grundGewaehlt: Farbe.amber)

        // `handy.css:178`: kein Rand, radius 11, Grund Weiss 7 %, padding 3, gap 2.
        // `:179`: flex 1, padding 9px 8px, radius 8, font-size 14. Das Gewicht bleibt, wie
        // `globals.css:781` es setzt - `handy.css` schreibt es nicht neu.
        private static let ansichtenSchmal = Zuschnitt(
            abstand: 2,
            polster: 3,
            radius: 11,
            grund: Color.white.opacity(0.07),
            rand: .clear,
            dehnt: true,
            schrift: Schrift.sans(14, relativeTo: .subheadline),
            gewicht: .medium,
            sperrung: 0,
            grossbuchstaben: false,
            polsterQuer: 8,
            polsterHoch: 9,
            knopfradius: 8,
            text: Farbe.text2,
            textGewaehlt: Farbe.petrol,
            grundGewaehlt: Farbe.amber)

        // `globals.css:247`: gap 2, Rand 1 px `linie2`, radius 5, padding 2, keine Fläche.
        // `:248`: padding 5px 14px, radius 3, font-size 13. Die Farben stehen am Knopf selbst
        // (`DayCurve.tsx:157`): gewählt `amber` mit `petrol`, sonst durchsichtig mit `text-2`.
        private static let tagesschalterBreit = Zuschnitt(
            abstand: 2,
            polster: 2,
            radius: 5,
            grund: .clear,
            rand: Farbe.linie2,
            dehnt: false,
            schrift: Schrift.klein,
            gewicht: .regular,
            sperrung: 0,
            grossbuchstaben: false,
            polsterQuer: 14,
            polsterHoch: 5,
            knopfradius: 3,
            text: Farbe.text2,
            textGewaehlt: Farbe.petrol,
            grundGewaehlt: Farbe.amber)

        // `handy.css:267`: kein Rand, radius 11, Grund Weiss 7 %, padding 3, gap 2, flex 1.
        // `:268`: flex 1, padding 8px 6px - also 6 quer und 8 hoch -, radius 8, font-size 14.
        private static let tagesschalterSchmal = Zuschnitt(
            abstand: 2,
            polster: 3,
            radius: 11,
            grund: Color.white.opacity(0.07),
            rand: .clear,
            dehnt: true,
            schrift: Schrift.sans(14, relativeTo: .subheadline),
            gewicht: .regular,
            sperrung: 0,
            grossbuchstaben: false,
            polsterQuer: 6,
            polsterHoch: 8,
            knopfradius: 8,
            text: Farbe.text2,
            textGewaehlt: Farbe.petrol,
            grundGewaehlt: Farbe.amber)

        // `ForecastPage.tsx:283`: Reihe ohne gap und ohne padding, radius 3, Rand `line-2`,
        // `overflow-hidden`. `:285-286`: mono, padding 16/8 (`px-4 py-2`), font-size 12,
        // Großbuchstaben, letter-spacing .08em - bei 12 Punkten 0,96. Gewählt Grund `amber`
        // mit `petrol`, sonst durchsichtig mit `text-3`.
        private static let prognosekopfMasse = Zuschnitt(
            abstand: 0,
            polster: 0,
            radius: 3,
            grund: .clear,
            rand: Farbe.linie2,
            dehnt: false,
            schrift: Schrift.mono(12, relativeTo: .caption),
            gewicht: .regular,
            sperrung: 0.96,
            grossbuchstaben: true,
            polsterQuer: 16,
            polsterHoch: 8,
            knopfradius: 0,
            text: Farbe.text3,
            textGewaehlt: Farbe.petrol,
            grundGewaehlt: Farbe.amber)

        // `globals.css:474`: Grund `rgba(15,46,61,.72)` - das ist `flaeche1` mit 72 % -,
        // Rand 1 px `linie2`, radius 999 (Kapsel), padding 3, kein gap. `:475`: mono,
        // font-size 10,5, letter-spacing .12em - bei 10,5 Punkten 1,26 -, Großbuchstaben,
        // Schrift `text2`, radius 999, padding 7px 12px. `:476` gewählt: `petrol` auf `amber`.
        private static let hausGruppeMasse = Zuschnitt(
            abstand: 0,
            polster: 3,
            radius: nil,
            grund: Farbe.flaeche1.opacity(0.72),
            rand: Farbe.linie2,
            dehnt: false,
            schrift: Schrift.mono(10.5, relativeTo: .caption2),
            gewicht: .regular,
            sperrung: 1.26,
            grossbuchstaben: true,
            polsterQuer: 12,
            polsterHoch: 7,
            knopfradius: nil,
            text: Farbe.text2,
            textGewaehlt: Farbe.petrol,
            grundGewaehlt: Farbe.amber)
    }

    /// Die Maße einer Form. Ein eigener Typ, damit jede Form ihre Werte an einer Stelle
    /// beisammen hat und die Ansicht sie nur noch einsetzt - vier Formen über fünfzehn
    /// einzelne Verzweigungen verteilt wären beim Lesen nicht mehr vergleichbar.
    struct Zuschnitt {
        // MARK: Die Reihe

        /// Der `gap` zwischen den Knöpfen.
        let abstand: CGFloat
        /// Das `padding` der Reihe selbst.
        let polster: CGFloat
        /// `nil` steht für `border-radius: 999px`, also die Kapsel.
        let radius: CGFloat?
        /// Die Fläche unter den Knöpfen - `clear`, wo die Vorlage keine setzt und die Reihe
        /// nur einen Rand hat.
        let grund: Color
        /// Der Rand der Reihe - `clear`, wo die Vorlage ihn weglässt (am Telefon tun das
        /// beide Formen, die `handy.css` neu schreibt).
        let rand: Color
        /// `flex: 1` beziehungsweise `align-self: stretch`: die Reihe nimmt die ganze Breite
        /// und jeder Knopf denselben Anteil.
        let dehnt: Bool

        // MARK: Die Knöpfe

        let schrift: Font
        /// `font-weight`. Nur `.ansicht` setzt 500 (`globals.css:781`); die drei anderen
        /// Formen lassen das Gewicht, wie es ist. Synthetisch gefettet und nicht der
        /// Schnitt `IBMPlexSans-SmBld`: ein Medium liegt nicht im Bundle, und 600 wäre hier
        /// zu viel.
        let gewicht: Font.Weight
        /// `letter-spacing` in Punkten - 0, wo die Vorlage keine Sperrung setzt. Die beiden
        /// Mono-Formen rechnen sie aus der em-Angabe der Vorlage und ihrer Schriftgröße.
        let sperrung: CGFloat
        /// `text-transform: uppercase`. Nur die beiden Mono-Formen setzen es.
        let grossbuchstaben: Bool
        let polsterQuer: CGFloat
        let polsterHoch: CGFloat
        /// `nil` steht wieder für die Kapsel; `0` für einen Knopf ohne eigenen Radius, dessen
        /// Ecken die Hülle der Reihe beschneidet (`overflow-hidden`).
        let knopfradius: CGFloat?
        let text: Color
        let textGewaehlt: Color
        let grundGewaehlt: Color
    }
}

#if DEBUG
    #Preview("Ansichtswahl") {
        VStack(alignment: .leading, spacing: 16) {
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "liste", name: "Liste"), Ansicht(weg: "modell", name: "Modell"),
                ],
                aktiv: Ansicht(weg: "liste", name: "Liste")
            ) { _ in }
            Ansichtswahl(
                ansichten: Spanne.allCases.map { Ansicht(weg: $0.rawValue, name: $0.name) },
                aktiv: Ansicht(weg: Spanne.woche.rawValue, name: "")
            ) { _ in }
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "gestern", name: "Gestern"), Ansicht(weg: "heute", name: "Heute"),
                    Ansicht(weg: "morgen", name: "Morgen"),
                ],
                aktiv: Ansicht(weg: "heute", name: "Heute"),
                form: .tagesschalter
            ) { _ in }
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "heute", name: "Heute"), Ansicht(weg: "gestern", name: "Gestern"),
                ],
                aktiv: Ansicht(weg: "heute", name: "Heute"),
                form: .prognosekopf
            ) { _ in }
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "", name: "Alle"), Ansicht(weg: "eg", name: "Erdgeschoss"),
                ],
                aktiv: Ansicht(weg: "", name: "Alle"),
                form: .hausGruppe
            ) { _ in }
        }
        .padding()
        .background(Farbe.grund)
    }
#endif
