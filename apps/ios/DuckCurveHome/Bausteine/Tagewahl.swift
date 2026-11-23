import DuckCurveKit
import SwiftUI

/// Die Wahl des Zeitraums in Tagen, fuer die Seiten, die keinen Kalender brauchen.
///
/// **Warum sie hier steht und nicht bei einer Seite.** Sie stand bis zum 20.11.2026 in
/// `Seiten/Technik/WaermepumpeSeiten.swift`, unter der Wärmepumpenseite - benutzt wird sie
/// aber von fuenf Seiten (Betrieb, Kennlinie, Wirkung, Prognose-Rueckblick,
/// Haustuerprotokoll), und die Wärmepumpenseite ist nicht einmal eine davon. Ein Baustein,
/// der fuenf Seiten dient, in der Datei einer sechsten: wer ihn aendert, aendert ihn fuer
/// vier Seiten, die er beim Oeffnen der Datei nicht gesehen hat. Die Typnamen sind
/// unveraendert geblieben - Swift kennt keinen Dateiimport im Modul, und darum hat sich an
/// den fuenf Aufrufstellen keine Zeile geaendert.
///
/// **Eine Ansicht, vier Knopfformen - weil die Vorlage vier hat.** Die fuenf Stellen, die
/// diese Wahl zeigen, tragen im Browser nicht dieselbe Form. Nur zwei ziehen die Regel
/// `.kl-knopf` (`Kennlinie.tsx:126`, `Betrieb.tsx:67`); die drei anderen setzen ihre Maße
/// selbst (`Wirkung.tsx:149`, `Rueckblick.tsx:173`, `DoorLog.tsx:107`). Darum traegt
/// ``Tagewahl`` die Form als Parameter und nicht als Annahme: eine einzige Form hat alle
/// fuenf Stellen auf die groesste von ihnen gezogen, und die drei kleinen sahen danach zu
/// gross aus. Welche Maße zu welcher Form gehoeren, steht an ``Tagewahl/Form``.
///
/// **Warum die Reihe ueberall ``Umbruchzeile`` ist und kein `HStack`.** `.kl-wahl`
/// (`globals.css:892`) und die Leiste der Wirkungskarte (`Wirkung.tsx:146`) brechen im
/// Browser um; vier Knoepfe in der grossen Form passen am Telefon nicht in eine Zeile, und
/// abgeschnitten waere schlechter als umgebrochen. Die beiden Mono-Formen brechen in der
/// Vorlage nicht um (`Rueckblick.tsx:167`, `DoorLog.tsx:100`) - sie sind aber auch so klein,
/// dass der Umbruch nie eintritt, und eine zweite Reihenart dafuer waere Aufwand ohne Bild.
struct Tagewahl: View {
    @Binding var tage: Int
    let moeglich: [Int]
    /// Die Beschriftung der Gruppe fuer die Bedienungshilfen, wie `aria-label` an `.kl-wahl`
    /// (`Betrieb.tsx:65`). `nil` laesst die Knoepfe einzeln stehen - so war es vorher, und so
    /// bleibt es an den Stellen, die keine Gruppe nennen.
    var gruppe: String?
    /// Die Form, die die Vorlage an der aufrufenden Stelle setzt. Vorgabe ist ``Form/klKnopf``,
    /// die einzige Form, die sich in der Vorlage zwei Stellen teilen - der Normalfall also, aber
    /// ausdruecklich nicht die Form fuer alle.
    var form: Form = .klKnopf

    var body: some View {
        if let gruppe {
            reihe
                .accessibilityElement(children: .contain)
                .accessibilityLabel(gruppe)
        } else {
            reihe
        }
    }

    /// Abstand und Zeilenabstand kommen aus der Form, weil die Vorlage den `gap` an jeder der
    /// fuenf Stellen anders setzt - 6 bei `.kl-wahl`, 8 und 4 bei den anderen.
    private var reihe: some View {
        let abstand: CGFloat = form.zuschnitt.abstand
        return Umbruchzeile(abstand: abstand, zeilenabstand: abstand) {
            ForEach(moeglich, id: \.self) { n in
                knopf(n)
            }
        }
    }

    /// **Die Teile einzeln benannt und mit angeschriebenem Typ.** Eine Kette aus Polster,
    /// Grund, Rahmen und drei Fragezeichen ergibt „unable to type-check this expression in
    /// reasonable time“; das sieht man erst auf dem Mac, nicht beim Parsen.
    private func knopf(_ n: Int) -> some View {
        let z: Zuschnitt = form.zuschnitt
        let gewaehlt: Bool = n == tage
        return Button {
            tage = n
        } label: {
            Text("\(n) \(z.einheit)")
                .font(gewaehlt ? z.schriftGewaehlt : z.schrift)
                .tracking(z.sperrung)
                .foregroundStyle(gewaehlt ? z.textGewaehlt : z.text)
                .padding(.horizontal, z.polsterQuer)
                .padding(.vertical, z.polsterHoch)
                .background(gewaehlt ? z.grundGewaehlt : Color.clear)
                .overlay(rahmen(gewaehlt))
                .clipShape(huelle)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(merkmale(gewaehlt))
    }

    /// Der Rahmen, verzweigt statt in einer Huelle fuer beides: `strokeBorder` gibt es nur an
    /// `InsettableShape`, und `AnyShape` ist keine. Ein mittig gezeichneter Strich stuende zur
    /// Haelfte ausserhalb - die Vorlage zeichnet ihn mit `border` innen.
    @ViewBuilder private func rahmen(_ gewaehlt: Bool) -> some View {
        let z: Zuschnitt = form.zuschnitt
        let farbe: Color = gewaehlt ? z.randGewaehlt : z.rand
        if let radius = z.radius {
            RoundedRectangle(cornerRadius: radius).strokeBorder(farbe, lineWidth: 1)
        } else {
            Capsule().strokeBorder(farbe, lineWidth: 1)
        }
    }

    /// Die Huelle zum Beschneiden. Kein Radius heißt Kapsel - so schreibt die Vorlage
    /// `border-radius: 999px` (`globals.css:893`, `:621`).
    private var huelle: AnyShape {
        if let radius = form.zuschnitt.radius {
            return AnyShape(RoundedRectangle(cornerRadius: radius))
        }
        return AnyShape(Capsule())
    }

    private func merkmale(_ gewaehlt: Bool) -> AccessibilityTraits {
        gewaehlt ? [.isButton, .isSelected] : [.isButton]
    }
}

extension Tagewahl {
    /// Eine Knopfform der Vorlage - ein Fall je Stelle, an der die Vorlage eigene Maße setzt.
    enum Form {
        /// `.kl-knopf` (`globals.css:893-894`), gezogen von `Kennlinie.tsx:126` und
        /// `Betrieb.tsx:67`. Die groesste der vier und die einzige, die gewaehlt halbfett wird
        /// - auf diesen beiden Seiten ist die Wahl die erste Zeile der Seite und soll von
        /// weitem zu treffen sein.
        case klKnopf

        /// `.wg-wahl` und `.wg-wahl-an` (`globals.css:621-622`), gezogen von
        /// `Wirkung.tsx:149`. Klein, weil die Wahl dort in einer Leiste neben zwei winzigen
        /// Beschriftungen steht (`Wirkung.tsx:146-153`) und nicht ueber ihnen.
        case wgWahl

        /// Der eigene Knopf des Prognose-Rueckblicks (`Rueckblick.tsx:173`). Er sitzt in der
        /// Kopfzeile neben der Legende (`Rueckblick.tsx:162-167`), faerbt gewaehlt nur Schrift
        /// und Rahmen - und schreibt „3 d“ statt „3 Tage“ (`Rueckblick.tsx:175`), weil vier
        /// Knoepfe mit dem ganzen Wort die Kopfzeile sprengen.
        case prognoseRueckblick

        /// Der eigene Knopf des Haustuerprotokolls (`DoorLog.tsx:107-111`). Gewaehlt faerbt er
        /// Schrift und Rahmen `amber`, den Grund nicht.
        case haustuerprotokoll

        /// Die Maße dieser Form, Zeile fuer Zeile aus der Vorlage.
        var zuschnitt: Zuschnitt {
            switch self {
            case .klKnopf:
                // `globals.css:893`: font-size 13, padding 7px 13px, radius 999, Rahmen
                // `linie1`, Schrift `text2`. `:894` gewaehlt: Grund und Rahmen `amber`,
                // Schrift `petrol`, font-weight 600. Reihe `.kl-wahl` (`:892`): gap 6.
                return Zuschnitt(
                    schrift: Schrift.klein,
                    schriftGewaehlt: Schrift.sansHalbfett(13, relativeTo: .footnote),
                    sperrung: 0,
                    polsterQuer: 13,
                    polsterHoch: 7,
                    radius: nil,
                    abstand: 6,
                    text: Farbe.text2,
                    textGewaehlt: Farbe.petrol,
                    grundGewaehlt: Farbe.amber,
                    rand: Farbe.linie1,
                    randGewaehlt: Farbe.amber,
                    einheit: "Tage")
            case .wgWahl:
                // `globals.css:621`: Mono, font-size 11, letter-spacing .08em, padding
                // 5px 10px, radius 999, Rahmen `linie1`, Schrift `text3`, kein Grund. `:622`
                // gewaehlt: Grund und Rahmen `amber`, Schrift `petrol`, Gewicht unveraendert.
                // Leiste `Wirkung.tsx:146`: gap-2, also 8.
                return Zuschnitt(
                    schrift: Schrift.mono(11, relativeTo: .caption2),
                    schriftGewaehlt: Schrift.mono(11, relativeTo: .caption2),
                    sperrung: 0.88,
                    polsterQuer: 10,
                    polsterHoch: 5,
                    radius: nil,
                    abstand: 8,
                    text: Farbe.text3,
                    textGewaehlt: Farbe.petrol,
                    grundGewaehlt: Farbe.amber,
                    rand: Farbe.linie1,
                    randGewaehlt: Farbe.amber,
                    einheit: "Tage")
            case .prognoseRueckblick:
                // `Rueckblick.tsx:173`: mono, rounded-[3px], border, px-2 py-[3px],
                // text-[11px]; gewaehlt `border-line-1 text-text-1`, sonst `border-line-2
                // text-text-3`. Kein Grund in keinem der beiden Zustaende. Reihe `:167`:
                // gap-1, also 4.
                return Zuschnitt(
                    schrift: Schrift.mono(11, relativeTo: .caption2),
                    schriftGewaehlt: Schrift.mono(11, relativeTo: .caption2),
                    sperrung: 0,
                    polsterQuer: 8,
                    polsterHoch: 3,
                    radius: 3,
                    abstand: 4,
                    text: Farbe.text3,
                    textGewaehlt: Farbe.text1,
                    grundGewaehlt: Color.clear,
                    rand: Farbe.linie2,
                    randGewaehlt: Farbe.linie1,
                    einheit: "d")
            case .haustuerprotokoll:
                // `DoorLog.tsx:107-111`: mono, rounded-[2px], border, px-3 py-1,
                // text-[12px]; gewaehlt `border-amber text-amber`, sonst `border-line-1
                // text-text-3`, kein Grund. px-3 sind 12, py-1 sind 4 - Tailwind rechnet in
                // Vierteln eines rem und `apps/web` setzt die Stufen nicht um
                // (`globals.css:5-30` nennt nur Farben, Schriften und Radien). Reihe `:100`:
                // gap-2, also 8.
                return Zuschnitt(
                    schrift: Schrift.mono(12, relativeTo: .caption),
                    schriftGewaehlt: Schrift.mono(12, relativeTo: .caption),
                    sperrung: 0,
                    polsterQuer: 12,
                    polsterHoch: 4,
                    radius: 2,
                    abstand: 8,
                    text: Farbe.text3,
                    textGewaehlt: Farbe.amber,
                    grundGewaehlt: Color.clear,
                    rand: Farbe.linie1,
                    randGewaehlt: Farbe.amber,
                    einheit: "Tage")
            }
        }
    }

    /// Die Maße einer Knopfform. Ein eigener Typ, damit jede Form ihre Werte an einer Stelle
    /// beisammen hat und der Knopf sie nur noch einsetzt - vier Formen ueber sieben einzelne
    /// Verzweigungen verteilt waeren beim Lesen nicht mehr vergleichbar.
    struct Zuschnitt {
        /// Die Schrift im Ruhezustand.
        let schrift: Font
        /// Die Schrift des gewaehlten Knopfes. Nur `.kl-knopf` wird halbfett
        /// (`font-weight: 600`, `globals.css:894`); die drei anderen lassen sie, wie sie ist.
        let schriftGewaehlt: Font
        /// `letter-spacing` in Punkten - 0, wo die Vorlage keine Sperrung setzt.
        let sperrung: CGFloat
        let polsterQuer: CGFloat
        let polsterHoch: CGFloat
        /// `nil` steht fuer `border-radius: 999px`, also die Kapsel.
        let radius: CGFloat?
        /// Der `gap` der Reihe, in der die Vorlage die Knoepfe aufreiht.
        let abstand: CGFloat
        let text: Color
        let textGewaehlt: Color
        /// Der Grund des gewaehlten Knopfes - `clear`, wo die Vorlage keinen setzt und der
        /// Unterschied allein an Schrift und Rahmen haengt.
        let grundGewaehlt: Color
        let rand: Color
        let randGewaehlt: Color
        /// Das Wort hinter der Zahl, wie die Vorlage es schreibt: „Tage“ - oder, im
        /// Prognose-Rueckblick, „d“.
        let einheit: String
    }
}
