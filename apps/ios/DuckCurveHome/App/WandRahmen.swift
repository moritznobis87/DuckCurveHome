import Combine
import DuckCurveKit
import SwiftUI

/// Die Wandanzeige: das iPad im Querformat, zwei Meter entfernt.
///
/// **Der Kopf gehoert dem Haus, nicht der Seite.** Marke, Bereiche, Uhr, Datum,
/// Aussentemperatur, Verbindung - und zwar auf jeder Seite gleich. Wer vorbeigeht, soll ohne
/// Tippen wissen, wie spaet es ist, wie kalt es draussen ist und ob die Anzeige noch lebt. Die
/// Seite darunter wechselt, der Kopf nicht.
///
/// **Nach fuenf Minuten wird daraus ein Bild.** Siehe `Ambiente`: die Seite bleibt am Leben und
/// mit ihr die Verbindung, eine Beruehrung holt die Bedienung zurueck. Das ist kein
/// Bildschirmschoner, sondern der Zustand, in dem diese Anzeige die meiste Zeit ist.
struct WandRahmen: View {
    @Environment(Hauszustand.self) private var haus
    let wegweiser: Wegweiser

    /// Wann zuletzt jemand das Glas beruehrt hat.
    @State private var letzteBeruehrung = Date()
    @State private var ruhe = false
    /// Die laufende Uhr im Kopf. Eine Sekunde, nicht feiner.
    @State private var uhr = Date()

    private static let ruheNach: TimeInterval = 5 * 60
    private static let heimkehrNach: TimeInterval = 2 * 60

    var body: some View {
        ZStack {
            anzeige
            if ruhe {
                Ambiente(aufwachen: wecken)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: ruhe)
        .onReceive(Self.jedeSekunde) { jetzt in
            uhr = jetzt
            pruefeRuhe(jetzt)
        }
        // Jede Beruehrung irgendwo auf der Flaeche zaehlt - auch eine, die auf einem Knopf landet.
        .simultaneousGesture(
            TapGesture().onEnded { _ in beruehrt() },
            including: .all
        )
    }

    private var anzeige: some View {
        VStack(spacing: 0) {
            Kopfzeile(uhr: uhr, wegweiser: wegweiser)
            if !wegweiser.bereich.reiter.isEmpty {
                Reiterzeile(
                    bereich: wegweiser.bereich,
                    aktiv: wegweiser.reiter,
                    darfAlles: haus.darfSchalten
                ) { r in
                    beruehrt()
                    wegweiser.gehe(r.weg)
                    wegweiser.merkeReiter()
                }
                // Die Unteransichten des gewaehlten Reiters, wo es welche gibt: Voraus gegen
                // Rueckblick, Jetzt gegen Ein Tag, die vier Sichten der Waermepumpe.
                Unteransichten(reiter: wegweiser.reiter)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
                Divider().overlay(Farbe.linie1)
            }
            Seitenwahl(weg: wegweiser.weg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) { Entenknopf() }
        }
        // **Abgeblendet wird das Bild, nicht die Anzeige** (`Home.tsx:227`: das `opacity`
        // sitzt am Hero). Der Kopf trägt Uhr und Verbindungspunkt - gerade die beiden sollen
        // bei einer Störung voll lesbar bleiben, denn sie sagen, wie alt das Bild ist. Hier
        // lag das Abblenden über allem, Uhr und Punkt eingeschlossen.
        .animation(.easeInOut(duration: 0.4), value: haus.gestoert)
    }

    /// Die laufende Uhr. Eine Sekunde ist fein genug - die Jetzt-Marke im Diagramm wandert
    /// ohnehin nur minutenweise, und `Home.tsx` rechnet aus demselben Grund mit Minuten.
    private static let jedeSekunde = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private func beruehrt() {
        letzteBeruehrung = Date()
        if ruhe { ruhe = false }
    }

    private func wecken() {
        beruehrt()
    }

    private func pruefeRuhe(_ jetzt: Date) {
        let still = jetzt.timeIntervalSince(letzteBeruehrung)
        // Das Ambiente erst, wenn ueberhaupt etwas da ist: eine Wand, die nach fuenf Minuten
        // gross „Verbinde mit dem Haus" sagt, ist kein Bild, sondern ein Vorwurf.
        if still > Self.ruheNach, haus.zustand != nil, !ruhe {
            ruhe = true
        }
        // Und die Heimkehr zum laufenden Tag, damit das Ambiente nie das Gestern von jemandem zeigt.
        if still > Self.heimkehrNach {
            wegweiser.heimkehr(jetzt: haus.jetzt)
        }
    }
}

/// Der Kopf der Wandanzeige.
struct Kopfzeile: View {
    @Environment(Hauszustand.self) private var haus
    let uhr: Date
    let wegweiser: Wegweiser

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Marke()
            bereichszeichen
            Spacer(minLength: 12)
            uhrzeit
        }
        // Derselbe Seitenrand wie die Seite darunter (`globals.css:190`: 32 Punkte).
        .padding(.horizontal, 32)
        .padding(.vertical, 10)
    }

    private var bereichszeichen: some View {
        HStack(spacing: 4) {
            ForEach(Bereiche.alle) { b in
                let istAktiv = wegweiser.bereich.schluessel == b.schluessel
                Button {
                    wegweiser.merkeReiter()
                    wegweiser.geheZuBereich(b)
                } label: {
                    // **Das gewaehlte Zeichen steht auf Bernstein, nicht in Bernstein**
                    // (`globals.css:750`): gefuellte Flaeche, Zeichen in Petrol. Umgekehrt war
                    // es ein helles Zeichen auf einer hellen Flaeche - aus drei Metern nicht
                    // von seinen Nachbarn zu unterscheiden.
                    Zeichen(
                        bereich: b.zeichen,
                        groesse: 22,
                        farbe: istAktiv ? Farbe.petrol : Farbe.text3
                    )
                    .padding(8)
                    .background(istAktiv ? Farbe.amber : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(b.name)
                .accessibilityAddTraits(istAktiv ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private var uhrzeit: some View {
        // Auf einer Grundlinie, nicht mittig: Datum, Uhr und Temperatur sind eine Zeile aus
        // drei Groessen (`globals.css:192`: `align-items: baseline`, Abstand 22).
        HStack(alignment: .firstTextBaseline, spacing: 22) {
            Text(Formate.langesDatum(haus.jetzt))
                .font(Schrift.sans(15))
                .foregroundStyle(Farbe.text2)
            Text(Formate.hhmm(haus.jetzt))
                // `clamp(30px, 3.4vw, 46px)` mit Strichstaerke 500 (`globals.css:194`).
                .font(Schrift.sans(40, relativeTo: .largeTitle))
                .fontWeight(.medium)
                .kerning(-1.2)
                .foregroundStyle(Farbe.text1)
                .monospacedDigit()
            aussen
            Verbindungspunkt()
        }
    }

    /// Die Aussentemperatur - und woher sie kommt.
    ///
    /// Der Dienst sagt mit `outdoor_source_de`, wenn er den Wert des Wetterdienstes zeigt statt
    /// des eigenen Fuehlers. Das steht dann dabei: eine Temperatur ohne Herkunft ist an einer
    /// Wandanzeige eine Behauptung.
    ///
    /// **Eine Zeile, nicht zwei** (`globals.css:195-196`): die Zahl in 17 Punkten, das Wort
    /// klein dahinter. Uebereinander gestapelt waren es zwei Zeilen in einer Kopfzeile, die
    /// sonst aus einer besteht.
    private var aussen: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(Formate.celsius(haus.zustand?.system.outdoorShownC ?? haus.augenblick?.outdoorTempC.value, stellen: 1))
                .font(Schrift.sans(17))
                .foregroundStyle(Farbe.text2)
            Text(haus.zustand?.system.outdoorSourceDe ?? "draußen")
                .font(Schrift.sans(12))
                .foregroundStyle(Farbe.text3)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Der Punkt, der sagt, ob die Anzeige noch lebt.
struct Verbindungspunkt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        HStack(spacing: 6) {
            // **Ein ruhiges Atmen, solange es laeuft** (`globals.css:197`, `dch-atmen`
            // ueber 3,6 Sekunden). An einer Wand ist das der Unterschied zwischen „lebt" und
            // „eingefroren" - ein stehendes Bild sagt das nicht von sich aus. Derselbe Punkt
            // wie im Ruhebild, und aus demselben Grund an einer Stelle: zwei Fassungen atmen
            // irgendwann verschieden, und eine von beiden hoert nach einer Stoerung auf.
            Atempunkt(gestoert: haus.gestoert)
            // **Am Telefon nur der Punkt, solange es laeuft** (`handy.css:227-228`): „live"
            // steht neunundneunzig Prozent der Zeit da und sagt damit nichts. Ausgeschrieben
            // wird, was nicht selbstverstaendlich ist: die Stoerung - und der Vorfuehrbetrieb.
            // **„demo 60×" ist keine Stoerung** (`verbindung` ist dort `.live`), aber jede Zahl
            // der App ist dann erfunden, und das Wort ist die einzige Stelle, die es sagt.
            if !schmal || haus.gestoert || vorfuehrung {
                Text(wort)
                    .font(Schrift.winzig)
                    .foregroundStyle(haus.gestoert ? Farbe.alarm : Farbe.text3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(haus.zustand?.system.connectionLabelDe ?? wort)
    }

    private var vorfuehrung: Bool { haus.vorfuehrung }

    private var wort: String { haus.verbindungswort }

}
