import DuckCurveKit
import SwiftUI

/// Ein Kanalzug wie am Mischpult: oben die Anzeige, darunter die Bahn mit dem Schieber, unten
/// der Name (`apps/web/src/components/waermepumpe/Fader.tsx:8-14`).
///
/// Der Schieber zeigt den Entwurf; ein schmaler Strich an der Bahn zeigt, was am Regler steht.
/// Bewegt wird er durch Ziehen oder mit den beiden Knöpfen darunter, die genau einen Schritt
/// gehen – am Telefon trifft man so den Wert, den man meint. Ein Zug, dessen Einstellung sich
/// nicht stellen lässt, ist blass; warum, steht darunter.
///
/// **Ein senkrechter Schieber gibt es in SwiftUI nicht.** `Slider` ist waagerecht und sieht aus
/// wie iOS, nicht wie ein Pult. Also selbst gebaut: Rille, Füllung, Ist-Strich und Knopf in
/// einem `ZStack`, der Wert aus der Höhe des Fingers über die Bahnhöhe – und zurückgerechnet
/// mit derselben Rechnung, mit der gezeichnet wird (``Reglerpult/anteil(_:_:)`` gegen
/// ``Reglerpult/wertBei(_:_:)``; dieselbe Begründung steht an
/// `Diagramme/Jahresflaeche.swift:134-140`).
///
/// **Gerastert, nicht stufenlos.** Eine Heizkurvensteilheit kennt Schritte von 0,05; was
/// dazwischen liegt, nimmt der Regler nicht an (``Reglerpult/wertBei(_:_:)``). Und bewegt ist
/// nicht gesendet: die Bewegung schreibt in den Entwurf, an den Bus geht sie erst über die
/// ``Uebernahmeleiste`` (`Regler.tsx:64`).
///
/// **Die Schwelle von sechs Punkten ist eine senkrechte.** Das Pult rollt waagerecht, die Bahn
/// zieht senkrecht – zwei Gesten, die sich um jeden Finger streiten. Die Vorlage löst das in
/// zwei Hälften: `touch-action: pan-x` gibt das waagerechte Wischen dem Pult
/// (`globals.css:982`), und die Bahn rührt den Wert erst an, wenn der Finger **senkrecht** um
/// sechs Bildpunkte abgewandert ist – `Math.abs(ev.clientY - s.y) < 6` (`Fader.tsx:64`), weil
/// „wer das Pult zur Seite schiebt und dabei auf einer Bahn landet, damit keinen Wert
/// verstellen soll“ (`Fader.tsx:19-22`).
///
/// `DragGesture(minimumDistance: 6)` allein wäre eine Schwelle in jede Richtung: ein waagerechtes
/// Wischen von sechs Punkten, das auf einer Bahn beginnt, ließe die Geste anlaufen und schriebe
/// einen Wert in den Entwurf, den niemand stellen wollte. Also bleibt die Schwelle der Geste
/// stehen – sie hält den Finger dem Rollbereich noch offen, so wie `pan-x` es tut – und ein
/// Merker lässt ``vomZeiger(_:)`` erst zu, wenn die senkrechte Verschiebung die sechs Punkte
/// erreicht. Derselbe Streit ist in `Haus3D/Glasmodell.swift:107-118` beschrieben und mit
/// einem solchen Merker entschieden.
struct Kanalzug: View {
    let w: ReglerEinstellungOut
    /// Was der Zug zeigt: der Entwurf, sonst der gelesene Wert – `nil`, wenn nichts gelesen ist.
    let wert: Double?
    let sperre: Reglerpult.Sperre?
    let fuss: Reglerpult.Fussstand
    /// Nur durchgereicht an ``Reglerfuss``: der Vergleichsknopf ist ein Griff an die Anlage und
    /// gehört dem Hausherrn (siehe ``Vergleichsknopf``).
    let darfStellen: Bool
    let schmal: Bool
    let stelle: (Double) -> Void
    let vergleichen: () -> Void

    @State private var zieht = false
    /// Hat der Finger die sechs Punkte **nach oben oder unten** hinter sich? Bis dahin bewegt
    /// er nichts (`Fader.tsx:64`). Gilt für einen Zug und wird mit ihm zurückgesetzt.
    @State private var senkrechtLos = false

    /// Breite eines Kanals: 96 Punkte, am Telefon 88 (`globals.css:978`, `handy.css:239`).
    private var kanalbreite: CGFloat { schmal ? 88 : 96 }
    private let bahnbreite: CGFloat = 56
    private let bahnhoehe: CGFloat = 190
    private let knopfhoehe: CGFloat = 26

    /// Frei ist der Zug nur ohne Sperrgrund **und** mit einem Wert (`Fader.tsx:23`). Ohne
    /// Vergleich mit dem Bediengerät bewegt sich hier nichts.
    private var frei: Bool { sperre == nil && wert != nil }
    /// Was am Regler steht – der Strich an der Bahn.
    private var ist: Double? { w.wert.belastbar }

    private var geaendert: Bool {
        guard let wert, let ist else { return false }
        return abs(wert - ist) > 1e-6
    }

    var body: some View {
        VStack(spacing: 8) {
            anzeige
            bahn
            tasten
            Text(w.nameDe)
                .font(Schrift.sans(12.5, relativeTo: .caption))
                .foregroundStyle(Farbe.text1)
                .multilineTextAlignment(.center)
                .frame(minHeight: 34, alignment: .top)
            Reglerfuss(stand: fuss, darfStellen: darfStellen, vergleichen: vergleichen)
        }
        .frame(width: kanalbreite)
        // **Die Bahn, die Tasten und der Vergleichsknopf bleiben eigene Elemente.** Mit
        // `children: .combine` wären sie ein Element, und der Vergleichsknopf - der einzige
        // Weg, eine Sperre abzuschalten - wäre für eine Sprachausgabe nicht mehr erreichbar.
        // Die Vorlage hält sie auch auseinander: `role="slider"` an der Bahn, Knöpfe daneben
        // (`Fader.tsx:40-92`).
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(w.gruppeDe): \(w.nameDe)")
    }

    // MARK: - Die Anzeige

    /// Das Wertfeld über der Bahn: Mono, bernstein sobald ein Entwurf dasteht, blass wenn
    /// gesperrt (`globals.css:979-981`).
    private var anzeige: some View {
        Text(wert.map { Reglerpult.zahlText(w, $0) } ?? "?")
            .font(Schrift.zahl)
            .monospacedDigit()
            .foregroundStyle(anzeigenfarbe)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(Kanalzug.pultgrund, in: anzeigenumriss)
            .overlay(anzeigenumriss.strokeBorder(anzeigenrand, lineWidth: 1))
            .shadow(color: geaendert ? Farbe.amber.opacity(0.25) : .clear, radius: 5)
    }

    private var anzeigenumriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    private var anzeigenfarbe: Color {
        if geaendert { return Farbe.amber }
        return frei ? Farbe.waermepumpe : Farbe.text3
    }

    private var anzeigenrand: Color {
        geaendert ? Farbe.amber.opacity(0.6) : Farbe.linie1
    }

    // MARK: - Die Bahn

    private var bahn: some View {
        ZStack(alignment: .topLeading) {
            skala
            rille
            if let ist { istStrich(ist) }
            if let wert { knopf(wert) }
        }
        .frame(width: bahnbreite, height: bahnhoehe)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(ziehen)
        .opacity(frei ? 1 : 0.7)
        // Das Gegenstück zu `role="slider"` samt Pfeiltasten (`Fader.tsx:42-52, 70-76`).
        .accessibilityElement()
        .accessibilityLabel("\(w.gruppeDe): \(w.nameDe)")
        .accessibilityValue(wert.map { Reglerpult.zahlText(w, $0) } ?? "nicht gelesen")
        .accessibilityHint(frei ? "" : (sperre?.wort ?? ""))
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: schritt(1)
            case .decrement: schritt(-1)
            @unknown default: break
            }
        }
    }

    /// Fünf Haarlinien bei 0, 25, 50, 75 und 100 Prozent (`Fader.tsx:78-82`).
    private var skala: some View {
        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { a in
            Rectangle()
                .fill(Farbe.linie2)
                .frame(width: bahnbreite - 8, height: 1)
                .position(x: bahnbreite / 2, y: hoeheFuer(a))
        }
    }

    /// Die Rille: 8 Punkte breit, mittig, mit der Füllung von unten (`globals.css:985-988`).
    private var rille: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Kanalzug.pultgrund)
            Rectangle().fill(fuellung).frame(height: fuellhoehe)
        }
        .frame(width: 8, height: bahnhoehe)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1))
        .position(x: bahnbreite / 2, y: bahnhoehe / 2)
    }

    private var fuellhoehe: CGFloat {
        guard let wert else { return 0 }
        return bahnhoehe * CGFloat(Reglerpult.anteil(w, wert))
    }

    private var fuellung: LinearGradient {
        let farbe = geaendert ? Farbe.amber : (frei ? Farbe.waermepumpe : Farbe.linie2)
        return LinearGradient(
            colors: [farbe, farbe.opacity(0.45)], startPoint: .top, endPoint: .bottom)
    }

    /// **Der Strich, der sagt, was am Regler steht** (`Fader.tsx:86`, `globals.css:990`). Er
    /// bleibt stehen, wenn der Knopf wandert – so ist zu sehen, wie weit der Entwurf von der
    /// Anlage abweicht, und zwar in derselben Bewegung, die ihn verschiebt.
    private func istStrich(_ ist: Double) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Farbe.text2).frame(width: 14, height: 2)
            Spacer(minLength: 0)
            Rectangle().fill(Farbe.text2).frame(width: 14, height: 2)
        }
        .frame(width: bahnbreite)
        .position(x: bahnbreite / 2, y: hoeheFuer(Reglerpult.anteil(w, ist)))
    }

    /// Der Knopf: 44 × 26 Punkte mit Mittelkerbe (`globals.css:991-993`).
    private func knopf(_ wert: Double) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(knopfverlauf)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .frame(width: 44, height: knopfhoehe)
            .shadow(color: frei ? .black.opacity(0.5) : .clear, radius: 4, y: 3)
            .position(x: bahnbreite / 2, y: hoeheFuer(Reglerpult.anteil(w, wert)))
    }

    private var knopfverlauf: LinearGradient {
        let kerbe = Color(red: 0.125, green: 0.200, blue: 0.235)
        let hell: Color = geaendert ? Color(red: 1, green: 0.824, blue: 0.478) : Farbe.text2
        let unten: Color = geaendert ? Farbe.amber : Farbe.text3
        return LinearGradient(
            stops: [
                .init(color: frei ? hell : Farbe.linie2, location: 0),
                .init(color: frei ? hell : Farbe.linie2, location: 0.46),
                .init(color: kerbe, location: 0.46),
                .init(color: kerbe, location: 0.54),
                .init(color: frei ? unten : Farbe.linie2, location: 0.54),
                .init(color: frei ? unten : Farbe.linie2, location: 1),
            ], startPoint: .top, endPoint: .bottom)
    }

    /// Wo auf der Bahn ein Anteil liegt: oben ist 1, unten ist 0 – dieselbe Rechnung, die
    /// ``vomZeiger(_:)`` umkehrt.
    private func hoeheFuer(_ anteil: Double) -> CGFloat {
        bahnhoehe - CGFloat(anteil) * bahnhoehe
    }

    // MARK: - Die Tasten

    /// Zwei Knöpfe, die genau einen Schritt gehen (`Fader.tsx:89-92`).
    ///
    /// Sichtbar sind die 34 × 30 Punkte der Vorlage, getroffen werden 44 – das ist die
    /// Mindestgröße für einen Daumen (`Bausteine/Speichersteuerkarte.swift:34-36`).
    private var tasten: some View {
        HStack(spacing: 6) {
            taste("−", richtung: -1, wozu: "kleiner")
            taste("+", richtung: 1, wozu: "größer")
        }
    }

    private func taste(_ wort: String, richtung: Double, wozu: String) -> some View {
        Button {
            schritt(richtung)
        } label: {
            Text(wort)
                .font(Schrift.sans(17))
                .foregroundStyle(frei ? Farbe.text1 : Farbe.text3)
                .frame(width: 34, height: 30)
                .background(Farbe.flaeche2, in: tastenumriss)
                .overlay(tastenumriss.strokeBorder(Farbe.linie2, lineWidth: 1))
                .frame(width: 38, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!frei)
        .opacity(frei ? 1 : 0.6)
        .accessibilityLabel("\(w.nameDe) einen Schritt \(wozu)")
    }

    private var tastenumriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    // MARK: - Bewegen

    private var ziehen: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { griff in
                guard frei else { return }
                zieht = true
                guard senkrecht(griff.translation.height) else { return }
                vomZeiger(griff.location.y)
            }
            .onEnded { griff in
                defer {
                    zieht = false
                    senkrechtLos = false
                }
                guard frei, senkrecht(griff.translation.height) else { return }
                vomZeiger(griff.location.y)
            }
    }

    /// Ist aus der Geste ein senkrechtes Ziehen geworden? Einmal ja, bleibt es ja, bis der
    /// Finger loslässt – sonst sprang der Wert mitten im Zug wieder weg, sobald der Finger
    /// zufällig auf die Höhe des Aufsetzpunkts zurückkäme.
    private func senkrecht(_ hoehe: CGFloat) -> Bool {
        if senkrechtLos { return true }
        guard abs(hoehe) >= 6 else { return false }
        senkrechtLos = true
        return true
    }

    /// Von der Höhe des Fingers zum Wert. Die sechs Punkte Polster über und unter der Bahn
    /// gehören nicht zur Skala und werden abgezogen.
    private func vomZeiger(_ y: CGFloat) {
        let auf = (y - 6) / bahnhoehe
        stelle(Reglerpult.wertBei(w, 1 - Double(auf)))
    }

    private func schritt(_ richtung: Double) {
        guard frei, let wert else { return }
        stelle(Reglerpult.raster(w, wert + richtung * (w.schritt ?? 1)))
    }

    /// Der Grund der Rille und des Wertfelds: `#06151c` (`globals.css:979, 985`). Ein eigener
    /// Ton, dunkler als jede Kartenfläche – ein Pult hat Löcher, in die man hineinsieht, und
    /// `Gestalt/Marken.swift` ist erzeugt, also steht er hier.
    private static let pultgrund = Color(red: 0.024, green: 0.082, blue: 0.110)
}
