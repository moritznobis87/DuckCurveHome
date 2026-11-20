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
