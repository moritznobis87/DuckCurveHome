import DuckCurveKit
import SwiftUI

/// Das Blatt der Alarmanlage: zwei Knöpfe zum Schärfen, keiner zum Entschärfen.
///
/// **Das ist keine Lücke** (`Dock.tsx:121-127`, wörtlich): „Die Anzeige haengt in der Kueche,
/// Gaeste gehen daran vorbei, und ihr Zugang ist ein Sitzungskeks auf einem Geraet - genug, um
/// eine Anlage scharf zu schalten, zu wenig, um sie abzuschalten.“ Der Satz unten sagt das,
/// damit niemand sucht.
///
/// **Warum es dieses Blatt gibt.** Das Schärfen gab es in der App nur auf der Hausseite
/// (`Hauskonsolenleiste.swift`). Vom Dock der Wandanzeige, wo man im Vorbeigehen daran kommt,
/// ging es nicht - und das ist die Stelle, an der man abends daran vorbeigeht.
///
/// Die Sätze, die Knöpfe und die Frage, wer schärfen darf, stehen in ``Dockzustand``.
struct Alarmblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    @State private var schaltet = false
    @State private var rueckmeldung: String?
    @State private var fehler: String?

    private var alarm: AlarmOut? { haus.zustand?.alarm }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    zustand
                    griffe
                    begruendung
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Alarmanlage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }

    /// Die Stufe als Wort, nicht als Zahl: `state_de` kommt aus dem Dienst, weil nur er weiß,
    /// wie die Anlage ihre Stufen nennt (`Dock.tsx:159`).
    private var zustand: some View {
        Karte {
            VStack(spacing: 0) {
                Zeile(
                    wort: "Zustand", wert: alarm?.stateDe ?? Formate.leer,
                    farbe: Color(Dockzustand.alarmfarbe(alarm))
                )
                if let a = alarm, let seit = a.observedAt, let d = Zeit.ausIso(seit) {
                    Zeile(wort: "gesehen", wert: Formate.hhmm(d))
                }
            }
        }
    }

    private var griffe: some View {
        Karte(kicker: "Scharf stellen") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(Dockzustand.scharfknoepfe) { k in
                        scharfknopf(k)
                    }
                }
                if let hinweis = Dockzustand.alarmhinweis(alarm, darfSchalten: haus.darfSchalten) {
                    Text(hinweis)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
                if let r = rueckmeldung {
                    Text(r).font(Schrift.klein).foregroundStyle(Farbe.pv)
                }
                if let f = fehler {
                    Text(f).font(Schrift.klein).foregroundStyle(Farbe.alarm)
                }
            }
        }
    }

    /// **Zwei Knöpfe in `--mist` und nicht in Rot** (`Dock.tsx:149`). Scharf stellen ist nichts
    /// Schlimmes; rot ist die Farbe der ausgelösten Anlage, und zwei rote Knöpfe sähen aus wie
    /// zwei Arten von Alarm.
    private func scharfknopf(_ k: Dockzustand.Scharfknopf) -> some View {
        let gesperrt = schaltet || !Dockzustand.darfSchaerfen(alarm, darfSchalten: haus.darfSchalten)
        return Button {
            schaerfe(k.art)
        } label: {
            Text(k.wort.uppercased())
                .font(Schrift.mono(13))
                .tracking(1.3)
                .foregroundStyle(Farbe.text1)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Farbe.mist, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(gesperrt)
        .opacity(gesperrt ? 0.45 : 1)
    }

    private var begruendung: some View {
        Text(Dockzustand.nurScharf)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func schaerfe(_ art: Api.AlarmArt) {
        schaltet = true
        fehler = nil
        Task {
            do {
                rueckmeldung = try await haus.api.schaerfeAlarm(art).messageDe
            } catch let f as ApiFehler {
                fehler = f.rat
            } catch {
                fehler = Dockzustand.nichtBestaetigt
            }
            schaltet = false
        }
    }
}
