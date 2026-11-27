import DuckCurveKit
import SwiftUI

/// Die Konsole des Hauses: fünf Blöcke, jeder eine Zahl und ein Satz.
///
/// **Warum neben dem Modell und nicht darin.** Das Modell zeigt, wo etwas ist; die Konsole sagt,
/// wie viel davon. „2 offen“ steht als Zahl da und muss nicht aus zwölf Kontaktstrichen gezählt
/// werden. Die Vorlage hat dafür 216 Punkte links reserviert (`house/Konsole.tsx`,
/// `globals.css:447`).
///
/// **Sie steht in beiden Ansichten und auf jeder Breite.** Bis zum 20.11.2026 baute die App sie
/// nur in der breiten Modellansicht; am Telefon - der Fassung, mit der die Seite anfängt - und
/// in jeder Listenansicht fehlten damit vier der fünf Blöcke, und „wie viele Fenster sind
/// offen“ war genau dort nicht zu beantworten, wo man es fragt. Die Vorlage setzt die Konsole in
/// beide Spaltenfassungen des Rasters `.haus-seite` und legt sie am Telefon quer
/// (`globals.css:543-549`, `handy.css:388-390`).
///
/// **Jeder Block klappt auf.** Die Antwort auf seine Zahl steht in ``Hauskonsolenblatt``, nicht
/// hinter einem Seitenwechsel (`Konsole.tsx:16-21`); der Weg auf die ausführliche Seite bleibt
/// im Fuß des Blattes.
struct Hauskonsolenleiste: View {
    @Environment(Hauszustand.self) private var haus

    let raeume: [RoomLiveOut]
    let plan: HousePlan?
    let kontakte: [HouseContactOut]
    /// Quer rollend statt untereinander - die Fassung unter 900 Punkten Breite
    /// (`globals.css:546-548`).
    var waagrecht: Bool = false
    /// Welcher Block offen ist. Die Seite hält den Zustand, weil sie das Blatt zeigt.
    @Binding var klappe: Konsolenklappe?

    @State private var rueckmeldung: String?
    @State private var schaltet = false

    private typealias F = Hauskonsolenfenster

    var body: some View {
        if waagrecht {
            ScrollView(.horizontal, showsIndicators: false) {
                // **Alle Blöcke der Reihe sind gleich hoch**, wie im Dashboard, wo die Reihe
                // ihre Kinder streckt (`globals.css`: `.haus-konsole` als Zeile). Bis zum
                // 27.11.2026 stand jeder in seiner eigenen Höhe: der Alarm mit seinen zwei
                // Knöpfen hoch, „Fenster und Türen“ daneben niedrig (Hausherr: „Warum haben
                // die Boxen nicht die gleiche Höhe?“). Die Reihe nimmt die Höhe des höchsten
                // Blocks, und jeder Block füllt sie (``block(_:wert:einheit:satz:farbe:klappe:flaeche:rand:dazu:)``).
                HStack(alignment: .top, spacing: 6) { bloecke }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                bloecke
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder private var bloecke: some View {
        alarmblock
        kontaktblock
        pufferblock
        pumpenblock
        kreisblock
    }

    // MARK: - Der Block

    /// Ein Block: Kicker, Zahl, Satz - und ein Streifen in seiner Farbe am linken Rand.
    ///
    /// Maße nach `globals.css:451-461`: Polster 10/12/10/18, Radius 16/4/4/16, Streifen 6 mit
    /// eigener Rundung, Fläche `rgba(15,46,61,.72)`, Kicker Mono 9,5, Wert Mono 21, Einheit 10
    /// in Großschrift, Satz 11,5 in `--text-2`. Die App hatte überall `Marken.radius2` (3),
    /// einen 3-Punkt-Streifen und den Satz in `--text-3` - das war der zu blasse Satz und die
    /// fehlende einseitige Rundung.
    ///
    /// **Zwei Fassungen statt eines Vorgabewerts.** Ein `@ViewBuilder`-Argument mit Vorgabewert
    /// legt den Typ fest, den der Aufrufer wählen soll; der Compiler nimmt das nicht an. Die
    /// Fassung ohne Beiwerk reicht `EmptyView` durch.
    private func block(
        _ kicker: String, wert: String, einheit: String? = nil, satz: String, farbe: Color,
        klappe ziel: Konsolenklappe? = nil
    ) -> some View {
        block(kicker, wert: wert, einheit: einheit, satz: satz, farbe: farbe, klappe: ziel) {
            EmptyView()
        }
    }

    private func block<Dazu: View>(
        _ kicker: String, wert: String, einheit: String? = nil, satz: String, farbe: Color,
        klappe ziel: Konsolenklappe? = nil, flaeche: AnyShapeStyle? = nil,
        rand: Color? = nil, @ViewBuilder dazu: () -> Dazu
    ) -> some View {
        let kopf = VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kicker.uppercased())
                        .font(Schrift.mono(9.5))
                        .tracking(1.7)
                        .foregroundStyle(Farbe.text3)
                    wertzeile(wert, einheit: einheit)
                    // Ohne Satz bleibt die Zeile weg (`Konsole.tsx`, `Block`).
                    if !satz.isEmpty {
                        Text(satz)
                            .font(Schrift.sans(11.5))
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 4)
                if ziel != nil {
                    Text(klappe == ziel ? "‹" : "›")
                        .font(Schrift.mono(16))
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        return VStack(alignment: .leading, spacing: 0) {
            if let ziel {
                Button { klappe = (klappe == ziel) ? nil : ziel } label: { kopf }
                    .buttonStyle(.plain)
                    .accessibilityHint("Zeigt die einzelnen Werte.")
            } else {
                kopf
            }
            dazu()
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minWidth: waagrecht ? mindestbreite(ziel) : nil, alignment: .leading)
        // In der Reihe füllt jeder Block deren Höhe, der Inhalt bleibt oben.
        .frame(maxHeight: waagrecht ? .infinity : nil, alignment: .topLeading)
        .background(flaeche ?? AnyShapeStyle(Farbe.flaeche1.opacity(0.72)), in: huelle)
        .overlay(huelle.strokeBorder(rand ?? Farbe.linie1, lineWidth: 1))
        .overlay(alignment: .leading) { streifen(farbe) }
    }

    /// Am Telefon rollt die Reihe quer, und jeder Block braucht eine Mindestbreite, sonst
    /// quetschen sich fünf in eine Bildschirmbreite (`handy.css:388-389`). Der Alarmblock
    /// braucht Platz für zwei Knöpfe nebeneinander.
    private func mindestbreite(_ ziel: Konsolenklappe?) -> CGFloat {
        ziel == nil ? 228 : 150
    }

    /// Die Hülle: links rund wie eine Kapsel, rechts fast eckig - so sitzt die Reihe der Blöcke
    /// am Modell wie eine Leiste und nicht wie fünf Karten (`globals.css:452`).
    private var huelle: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 16, bottomLeading: 16, bottomTrailing: 4, topTrailing: 4),
            style: .continuous)
    }

    /// Der Streifen sagt, worum es geht, bevor man den Kicker gelesen hat.
    private func streifen(_ farbe: Color) -> some View {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 15, bottomLeading: 15, bottomTrailing: 0, topTrailing: 0),
            style: .continuous
        )
        .fill(farbe)
        .frame(width: 6)
    }

    private func wertzeile(_ wert: String, einheit: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(wert)
                .font(Schrift.mono(21, relativeTo: .title3))
                .foregroundStyle(Farbe.text1)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let einheit, wert != Formate.leer {
                Text(einheit.uppercased())
                    .font(Schrift.mono(10))
                    .tracking(1)
                    .foregroundStyle(Farbe.text3)
            }
        }
    }

    // MARK: - Alarm

    /// Der Alarm: das Wort der Stufe als Wert, der Satz des Dienstes darunter - und der Block
    /// selbst färbt sich.
    ///
    /// **Zweimal dasselbe ist einmal zu viel.** Hier stand `stateDe.uppercased()` als Wert und
    /// `stateDe` als Satz. Die Vorlage setzt oben das Wort der Stufe (`ALARM_WORT`,
    /// `house/live.ts:40-47`) und darunter, was die Anlage dazu meldet.
    private var alarmblock: some View {
        let alarm = haus.zustand?.alarm
        let stufe = F.stufe(alarm)
        return block(
            "Alarm", wert: stufe.wort, satz: F.alarmsatz(alarm), farbe: Farbe.amber,
            klappe: nil, flaeche: alarmflaeche(stufe), rand: alarmrand(stufe)
        ) {
            VStack(alignment: .leading, spacing: 4) {
                if alarm?.present == true, stufe != .ausgeloest {
                    HStack(spacing: 6) {
                        scharfknopf("zu Hause", .daheim, gesperrt: stufe == .zuhause)
                        scharfknopf("unterwegs", .fort, gesperrt: stufe == .unterwegs)
                    }
                }
                if let r = rueckmeldung {
                    Text(r).font(Schrift.sans(11.5)).foregroundStyle(Farbe.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // **Ein Gast soll wissen, warum nichts geht.** Die Vorlage schreibt es in den
                // Block (`Konsole.tsx:183`); in der App fehlte der Satz, und die Knöpfe waren
                // einfach weg.
                if alarm?.present == true, !haus.darfSchalten {
                    Text("Gastzugang: nur Ansicht.")
                        .font(Schrift.sans(11.5))
                        .foregroundStyle(Farbe.text3)
                }
            }
            .padding(.top, 6)
        }
        .modifier(Puls(an: stufe == .ausgeloest))
    }

    /// Die Zustandsfläche des Blocks (`globals.css:462-464`): ein Verlauf von der Farbe der
    /// Stufe in die gewöhnliche Fläche, auf 70 Prozent der Breite ausgelaufen.
    ///
    /// Die Vorlage nennt dort eigene Hexwerte (#F2B134, #FF7A45, #FF3B3B). Der Kern führt sie
    /// nicht; genommen ist die jeweils nächstliegende Marke, damit keine zweite Palette
    /// entsteht.
    private func alarmflaeche(_ stufe: F.Alarmstufe) -> AnyShapeStyle? {
        guard let farbe = stufenfarbe(stufe) else { return nil }
        let grund = Farbe.flaeche1.opacity(0.72)
        return AnyShapeStyle(
            LinearGradient(
                stops: [
                    Gradient.Stop(color: farbe.opacity(stufendeckung(stufe)), location: 0),
                    Gradient.Stop(color: grund, location: 0.7),
                    Gradient.Stop(color: grund, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing))
    }

    private func stufendeckung(_ stufe: F.Alarmstufe) -> Double {
        switch stufe {
        case .zuhause: return 0.16
        case .unterwegs: return 0.2
        case .ausgeloest: return 0.3
        default: return 0
        }
    }

    private func stufenfarbe(_ stufe: F.Alarmstufe) -> Color? {
        switch stufe {
        case .zuhause: return Farbe.amber
        case .unterwegs: return Farbe.waermepumpe
        case .ausgeloest: return Farbe.alarm
        default: return nil
        }
    }

    private func alarmrand(_ stufe: F.Alarmstufe) -> Color? {
        switch stufe {
        case .zuhause: return Farbe.amber.opacity(0.45)
        case .unterwegs: return Farbe.waermepumpe.opacity(0.5)
        case .ausgeloest: return Farbe.alarm.opacity(0.7)
        default: return nil
        }
    }

    private func scharfknopf(_ wort: String, _ art: Api.AlarmArt, gesperrt: Bool) -> some View {
        let aus = gesperrt || schaltet || !(haus.zustand?.alarm?.canArm ?? false)
            || !haus.darfSchalten
        return Button {
            schaerfe(art)
        } label: {
            Text(wort.uppercased())
                .font(Schrift.mono(10.5))
                .tracking(1.3)
                .foregroundStyle(Farbe.text2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(aus)
        .opacity(aus ? 0.4 : 1)
    }

    private func schaerfe(_ art: Api.AlarmArt) {
        schaltet = true
        Task {
            do {
                rueckmeldung = try await haus.api.schaerfeAlarm(art).messageDe
            } catch let f as ApiFehler {
                rueckmeldung = f.rat
            } catch {
                rueckmeldung = "Die Anlage hat nicht bestätigt."
            }
            schaltet = false
        }
    }

    // MARK: - Die vier Zahlen mit Anschlussfrage

    private var kontaktblock: some View {
        let zeilen = F.kontaktzeilen(plan: plan, kontakte: kontakte)
        let offen = zeilen.filter { $0.offen == true }
        return block(
            "Fenster und Türen", wert: String(offen.count), einheit: "offen",
            satz: Hauskonsole.offenSatz(offen.map(\.name), von: zeilen.count),
            farbe: Farbe.mist, klappe: .kontakte)
    }

    private var pufferblock: some View {
        let soc = haus.zustand?.buffer.soc
        return block(
            "Puffer",
            wert: soc.map { Formate.zahl($0 * 100, stellen: 0) } ?? Formate.leer,
            einheit: "%", satz: Hauskonsole.schichtsatz(schichten), farbe: Farbe.waermepumpe,
            klappe: .puffer)
    }

    private var schichten: [Double?] {
        (haus.augenblick?.bufferTempsC.vonObenNachUnten ?? []).map(\.belastbar)
    }

    private var pumpenblock: some View {
        let wp = haus.zustand?.heatPump
        return block(
            "Wärmepumpe", wert: Formate.kw(haus.augenblick?.heatPumpPowerKw.value),
            einheit: "kW",
            satz: Hauskonsole.pumpensatz(
                laeuft: wp?.running,
                seit: (wp?.running ?? false) ? wp?.runningSince : wp?.stoppedSince,
                jetzt: haus.jetzt),
            farbe: Farbe.waermepumpe, klappe: .waermepumpe)
    }

    /// **Die Farbe der Vorlage ist `--ev`** (`Konsole.tsx`, `tokens.css`), im Kern
    /// `Farbe.wallbox`. Seit dem 24.11.2026 ist das derselbe Wert wie im Diagramm (#2F89B5).
    private var kreisblock: some View {
        block(
            "Heizkreise", wert: String(Hauskonsole.offeneKreise(raeume)), einheit: "offen",
            satz: raeume.isEmpty ? "keine Raumwerte" : "\(raeume.count) Räume",
            farbe: Farbe.wallbox, klappe: .kreise)
    }
}

/// Der Puls des ausgelösten Alarms (`globals.css:464`: `dch-pulse .7s ease-in-out infinite`).
///
/// **Der Schein pulst, nicht der Block.** `dch-pulse` animiert ausschliesslich `box-shadow`
/// (`globals.css:96-99`: 0 0 0 4px rgba(242,169,0,.14) ↔ 0 0 0 8px rgba(242,169,0,.05)), der
/// Block selbst behält seine Deckkraft (`globals.css:464`). Hier lag die Animation auf der
/// Deckkraft des ganzen Blocks, und damit flackerte auch der Text - „AUSGELÖST“, der Satz der
/// Anlage und die Rückmeldung - zwischen voll und 55 Prozent. Genau in dem Zustand, in dem man
/// ihn lesen will.
///
/// **Nur im Zustand „ausgelöst“.** Eine Dauerzeichnung auf einer Wandanzeige, die rund um die
/// Uhr läuft, ist kein Hinweis mehr, sondern Flimmern - dieselbe Überlegung wie im Glasmodell,
/// das nur atmet, solange irgendwo geheizt wird (`Haus3D/Glasmodell.swift:68-78`).
private struct Puls: ViewModifier {
    let an: Bool
    @State private var weit = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: Farbe.amber.opacity(an ? (weit ? 0.05 : 0.14) : 0),
                radius: weit ? 8 : 4)
            .onChange(of: an, initial: true) { _, jetztAn in
                weit = false
                guard jetztAn else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    weit = true
                }
            }
    }
}
