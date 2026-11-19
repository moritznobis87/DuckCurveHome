import DuckCurveKit
import SwiftUI

/// Die Leiste rechts neben dem Fluss: der Puffer und der Plan.
///
/// Der Puffer bekommt die ganze Hoehe, weil er das zweite Bild der Seite ist. Raeume und
/// Strompreis standen hier als zwei weitere Kacheln und sind weg (Nutzerwunsch 22.10.2026): der
/// Strompreis steht ohnehin in der Tageskurve, die Raeume haben ihre Seite.
///
/// Dazu, was das Haus vorhat: an der Wand drei Zeilen mit Uhrzeiten, am Telefon das Bild der
/// naechsten 24 Stunden (``Ausblickkarte``). Beides, weil die Frage „was hat das Haus vor" sonst
/// nur im Satz oben beantwortet waere - und der sagt nur das Naechste.
struct Leiste: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    var kompakt: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // **Erst was kommt, dann was war.** Am Telefon steht der Ausblick vor dem Puffer und
            // vor der Kurve des Tages (`handy.css:270`: `.home-rail .ausblick { order: -1 }`).
            // An der Wand stehen beide nebeneinander in der Leiste, und dort fuehrt der Puffer:
            // er ist das zweite Bild der Seite.
            if kompakt {
                Ausblickkarte(
                    ausblick: Ausblick.baue(haus.plan, jetzt: haus.jetzt), jetzt: haus.jetzt,
                    warnung: haus.plan?.plannerWarnDe
                )
            }
            // Am Telefon liegt er, an der Wand steht er - so wie im Dashboard
            // (`home/Rail.tsx`, kompakter Zweig, Nutzerwunsch 14.11.2026: „sonst streckt
            // man die Seite unnötig"). Auf einer Rolle ist ein Glas von 300 Punkten Hoehe
            // alles, was man sieht.
            if kompakt {
                // **Die Kachel fuehrt zur Waerme** (`Rail.tsx:55`). Sie zeigt vier
                // Temperaturen und einen Ladestand; wer darauf tippt, will mehr davon.
                Karte {
                    Pufferflach(
                        temperaturen: fuehler, soc: haus.zustand?.buffer.soc, zustand: zustand)
                }
                .contentShape(Rectangle())
                .onTapGesture { wegweiser.gehe("/waerme") }
            } else {
                // Die Pufferkachel dehnt sich, die Planzeilen bleiben so hoch wie ihr Inhalt
                // (`globals.css:236,238,242`: `flex: 1 1 0` gegen `flex: none`).
                Karte(kicker: "Puffer") {
                    // **Keine Mindesthoehe am Tank** (`globals.css:240-241`, woertlich: „das
                    // liess ihn an der Wand ueber die Kachel hinauslaufen"). Die Kachel nimmt,
                    // was die Planzeilen uebrig lassen, und das Glas fuellt sie.
                    Pufferglas(
                        temperaturen: fuehler, soc: haus.zustand?.buffer.soc, zustand: zustand
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            if !kompakt, !zeilen.isEmpty {
                Karte(kicker: "Nächste 24 h") {
                    VStack(spacing: 0) {
                        ForEach(zeilen) { z in
                            HStack {
                                Text(z.wort)
                                    .font(Schrift.klein)
                                    .foregroundStyle(Farbe.text2)
                                Spacer(minLength: 8)
                                Text(z.wann)
                                    .font(Schrift.zahlKlein)
                                    .foregroundStyle(Farbe.text1)
                            }
                            .padding(.vertical, 5)
                            if z.id != zeilen.last?.id {
                                Divider().overlay(Farbe.linie1)
                            }
                        }
                        // Die Warnung des Planers steht dort, wo der Plan steht - vorher stand
                        // sie nur auf der Fahrplanseite.
                        if let w = haus.plan?.plannerWarnDe, !w.isEmpty {
                            Text(w)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.amberWeich)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        }
                    }
                }
            }
        }
    }

    private var fuehler: [Messwert] {
        haus.augenblick?.bufferTempsC.vonObenNachUnten ?? []
    }

    private var zustand: Pufferzustand {
        Pufferzustand.aus(
            fuehler: fuehler,
            jetzt: haus.jetzt,
            laedt: haus.zustand?.heatPump.running ?? false,
            status: haus.zustand?.buffer.status
        )
    }

    private var zeilen: [Planzeile] {
        Fahrplan.zeilen(haus.plan, jetzt: haus.jetzt)
    }
}

/// Das Bild, das nach fuenf Minuten ohne Beruehrung ueber der Wandanzeige liegt.
///
/// **Was es ist und was nicht.** Kein Bildschirmschoner: die Seite darunter bleibt am Leben und
/// mit ihr die Verbindung. Es ist der Zustand, in dem diese Anzeige die meiste Zeit ist - und
/// darum zeigt es nicht weniger, sondern anderes: Uhr, Satz, drei grosse Zahlen. Was man aus
/// zwei Metern im Vorbeigehen liest.
///
/// **Es zeigt immer heute.** `WandRahmen` kehrt nach zwei Minuten zum laufenden Tag zurueck,
/// bevor das Ambiente nach fuenf aufgeht - damit es nie das Gestern von jemandem zeigt.
struct Ambiente: View {
    @Environment(Hauszustand.self) private var haus
    let aufwachen: () -> Void

    var body: some View {
        ZStack {
            Farbe.grundVerlauf.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 28) {
                uhr
                satz
                zahlen
                Spacer(minLength: 0)
                fuss
            }
            .padding(44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: aufwachen)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Ruhebild. Antippen für die Bedienung.")
    }

    private var uhr: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Formate.hhmm(haus.jetzt))
                .font(Schrift.zahlAmbiente)
                .foregroundStyle(Farbe.text1)
                .monospacedDigit()
            Text(Formate.langesDatum(haus.jetzt))
                .font(Schrift.text)
                .foregroundStyle(Farbe.text3)
        }
    }

    private var satz: some View {
        Text(haus.satz)
            .font(Schrift.satz)
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 720, alignment: .leading)
    }

    /// Drei Zahlen. Nicht vier und nicht sechs: aus zwei Metern liest man drei.
    private var zahlen: some View {
        HStack(alignment: .firstTextBaseline, spacing: 48) {
            ForEach(drei, id: \.wort) { k in
                VStack(alignment: .leading, spacing: 2) {
                    Zahl(
                        wert: k.wert, einheit: k.einheit,
                        schrift: Schrift.custom(52), einheitSchrift: Schrift.klein,
                        farbe: k.farbe
                    )
                    Text(k.wort)
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }

    private var drei: [Kacheldaten] {
        let heute = haus.zustand?.todayKwh ?? [:]
        return [
            Kacheldaten(
                "aus der Sonne", Formate.zahl(heute["pv"] ?? 0, stellen: 1),
                einheit: "kWh", farbe: Farbe.pv
            ),
            Kacheldaten(
                "Strompreis",
                Formate.zahl(haus.augenblick?.electricityPriceCtKwh.belastbar ?? 0, stellen: 1),
                einheit: "ct/kWh"
            ),
            Kacheldaten(
                "draußen",
                Formate.zahl(
                    haus.zustand?.system.outdoorShownC ?? haus.augenblick?.outdoorTempC.belastbar ?? 0,
                    stellen: 1
                ),
                einheit: "°C"
            ),
        ]
    }

    /// Unten die naechste Sache und der Zustand der Verbindung - das Einzige, was ein Ruhebild
    /// von einem eingefrorenen unterscheidet.
    private var fuss: some View {
        HStack(spacing: 20) {
            if let erste = Fahrplan.zeilen(haus.plan, jetzt: haus.jetzt).first {
                Text("\(erste.wort) \(erste.wann)")
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 0)
            Verbindungspunkt()
        }
    }
}
