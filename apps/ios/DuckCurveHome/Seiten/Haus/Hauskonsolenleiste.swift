import DuckCurveKit
import SwiftUI

/// Die Leiste neben dem Hausmodell: fünf Blöcke, jeder eine Zahl und ein Satz.
///
/// **Warum neben dem Modell und nicht darin.** Das Modell zeigt, wo etwas ist; die Leiste sagt,
/// wie viel davon. „2 offen" steht als Zahl da und muss nicht aus zwölf Kontaktstrichen gezählt
/// werden. Die Vorlage hat dafür 216 Punkte links vom Bild reserviert
/// (`house/Konsole.tsx`, `globals.css:447`); in der App stand an dieser Stelle nur der Alarm,
/// quer über die ganze Breite.
///
/// **Jeder Block führt irgendwohin.** Die Vorlage klappt dort ein Fenster auf; hier springt ein
/// Tipp auf die Seite, die dasselbe ausführlich zeigt - der Weg, den die App ohnehin für alles
/// andere nimmt.
struct Hauskonsolenleiste: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    let raeume: [RoomLiveOut]
    let plan: HousePlan?
    let kontakte: [HouseContactOut]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let alarm = haus.zustand?.alarm {
                alarmblock(alarm)
            }
            kontaktblock
            pufferblock
            pumpenblock
            kreisblock
            Spacer(minLength: 0)
        }
    }

    // MARK: - Die Blöcke

    /// Ein Block: Kicker, Zahl, Satz – und ein Streifen in seiner Farbe am linken Rand.
    /// **Zwei Fassungen statt eines Vorgabewerts.** Ein `@ViewBuilder`-Argument mit
    /// Vorgabewert legt den Typ fest, den der Aufrufer wählen soll; der Compiler nimmt das
    /// nicht an. Die Fassung ohne Beiwerk reicht `EmptyView` durch.
    private func block(
        _ kicker: String, wert: String, einheit: String? = nil, satz: String,
        farbe: Color, weg: String? = nil
    ) -> some View {
        block(kicker, wert: wert, einheit: einheit, satz: satz, farbe: farbe, weg: weg) {
            EmptyView()
        }
    }

    private func block<Dazu: View>(
        _ kicker: String, wert: String, einheit: String? = nil, satz: String,
        farbe: Color, weg: String? = nil, @ViewBuilder dazu: () -> Dazu
    ) -> some View {
        let inhalt = VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Kicker(wort: kicker)
                    Zahl(
                        wert: wert, einheit: einheit,
                        schrift: Schrift.mono(26, relativeTo: .title2),
                        einheitSchrift: Schrift.sans(11), farbe: Farbe.text1
                    )
                    Text(satz)
                        .font(Schrift.sans(12))
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if weg != nil {
                    Text("›")
                        .font(Schrift.sans(15))
                        .foregroundStyle(Farbe.text3)
                }
            }
            dazu()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farbe.flaeche1.opacity(0.55))
        .overlay(alignment: .leading) {
            // Der Streifen sagt, worum es geht, bevor man den Kicker gelesen hat.
            Rectangle().fill(farbe).frame(width: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))

        return Group {
            if let weg {
                Button { wegweiser.gehe(weg) } label: { inhalt }
                    .buttonStyle(.plain)
            } else {
                inhalt
            }
        }
    }

    private func alarmblock(_ alarm: AlarmOut) -> some View {
        block(
            "Alarm", wert: alarm.stateDe.uppercased(), satz: alarm.stateDe,
            farbe: (alarm.state ?? 0) >= 1 ? Farbe.amber : Farbe.mist
        ) {
            if alarm.canArm, haus.darfSchalten {
                HStack(spacing: 6) {
                    scharfknopf("Zu Hause", .daheim)
                    scharfknopf("Unterwegs", .fort)
                }
                .padding(.top, 4)
            }
        }
    }

    private func scharfknopf(_ wort: String, _ art: Api.AlarmArt) -> some View {
        Button {
            Task { _ = try? await haus.api.schaerfeAlarm(art) }
        } label: {
            Text(wort.uppercased())
                .font(Schrift.mono(10))
                .kerning(1)
                .foregroundStyle(Farbe.text2)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var kontaktblock: some View {
        let offen = kontakte.filter { $0.open == true }
        return block(
            "Fenster und Türen", wert: String(offen.count), einheit: "offen",
            satz: Hauskonsole.offenSatz(offen.map(\.name), von: kontakte.count),
            farbe: Farbe.mist, weg: "/system/haustuer"
        )
    }

    private var pufferblock: some View {
        let soc = haus.zustand?.buffer.soc
        return block(
            "Puffer",
            wert: soc.map { Formate.zahl($0 * 100, stellen: 0) } ?? Formate.leer,
            einheit: "%",
            satz: Hauskonsole.schichtsatz(schichten), farbe: Farbe.waermepumpe,
            weg: "/waerme"
        )
    }

    private var schichten: [Double?] {
        (haus.augenblick?.bufferTempsC.vonObenNachUnten ?? []).map(\.belastbar)
    }

    private var pumpenblock: some View {
        let wp = haus.zustand?.heatPump
        return block(
            "Wärmepumpe",
            wert: Formate.kw(haus.augenblick?.heatPumpPowerKw.value), einheit: "kW",
            satz: Hauskonsole.pumpensatz(
                laeuft: wp?.running,
                seit: (wp?.running ?? false) ? wp?.runningSince : wp?.stoppedSince,
                jetzt: haus.jetzt),
            farbe: Farbe.waermepumpe, weg: "/waerme/waermepumpe"
        )
    }

    private var kreisblock: some View {
        block(
            "Heizkreise", wert: String(Hauskonsole.offeneKreise(raeume)), einheit: "offen",
            satz: raeume.isEmpty ? "keine Raumwerte" : "\(raeume.count) Räume",
            farbe: Farbe.diagrammWallbox, weg: "/waerme/raeume"
        )
    }
}
