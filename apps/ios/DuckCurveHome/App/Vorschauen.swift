#if DEBUG
    import DuckCurveKit
    import SwiftUI

    /// Die Vorschauen für Xcode, an einer Stelle.
    ///
    /// **Warum nicht je eine neben ihrer Seite.** Jede Vorschau braucht dieselben drei Zeilen
    /// Umgebung - Hauszustand, Wegweiser, Hintergrund -, und dreißigmal dieselben drei Zeilen
    /// sind dreißig Stellen, an denen eine davon fehlt. Hier steht die Umgebung einmal
    /// (`Vorschaurahmen`), und darunter eine Zeile je Seite.
    ///
    /// **Was eine Vorschau hier zeigt und was nicht.** Der Hauszustand ist mit Beispieldaten
    /// gefüllt und verbindet sich nicht - alles, was aus dem Ereignisstrom kommt, ist also da:
    /// das Flussbild, der Puffer, die Tageskurve, das Dock, der Satz des Reglers. Was eine Seite
    /// sich selbst holt - Berichte, Räume, Rechnungen -, kommt nicht, und sie zeigt ihren
    /// Leerzustand. Auch das ist einen Blick wert: eine Seite, die ohne Daten schlecht aussieht,
    /// sieht am ersten Tag im Haus schlecht aus.

    /// Die Umgebung, die jede Seite braucht.
    struct Vorschaurahmen<Inhalt: View>: View {
        var breit: Bool = false
        var weg: String = "/"
        @ViewBuilder var inhalt: () -> Inhalt

        @State private var haus = Hauszustand.vorschau()
        @State private var wegweiser = Wegweiser()

        var body: some View {
            inhalt()
                .environment(haus)
                .environment(wegweiser)
                .environment(Mitteilungen())
                .hausschrift()
                .seitengrund()
                .preferredColorScheme(.dark)
                .onAppear { wegweiser.gehe(weg) }
                // Die Breite entscheidet über das Gerippe. In einer Vorschau gibt es kein Gerät,
                // das sie vorgibt - also wird sie gesetzt.
                .environment(\.horizontalSizeClass, breit ? .regular : .compact)
        }
    }

    // MARK: - Die beiden Gerippe

    #Preview("Wand · Jetzt") {
        Vorschaurahmen(breit: true) {
            WandRahmen(wegweiser: Wegweiser())
        }
    }

    #Preview("Hand · Jetzt") {
        Vorschaurahmen {
            HandRahmen(wegweiser: Wegweiser())
        }
    }

    #Preview("Das Ruhebild") {
        Vorschaurahmen(breit: true) {
            Ambiente(aufwachen: {})
        }
    }

    #Preview("Einrichten") {
        Vorschaurahmen {
            Einrichten()
        }
    }

    // MARK: - Die Seiten

    #Preview("Jetzt, breit") {
        Vorschaurahmen(breit: true) { JetztSeite() }
    }

    #Preview("Jetzt, schmal") {
        Vorschaurahmen { JetztSeite() }
    }

    #Preview("Haus") {
        Vorschaurahmen(weg: "/haus") { HausSeite() }
    }

    #Preview("Strom") {
        Vorschaurahmen(weg: "/strom") { StromSeite() }
    }

    #Preview("Anlage") {
        Vorschaurahmen(breit: true, weg: "/waerme/anlage") { AnlageSeite() }
    }

    #Preview("Fahrplan") {
        Vorschaurahmen(breit: true, weg: "/waerme/fahrplan") { FahrplanSeite() }
    }

    #Preview("Wärmepumpe") {
        Vorschaurahmen(weg: "/waerme/waermepumpe") { WaermepumpeSeite() }
    }

    #Preview("Zugang") {
        Vorschaurahmen(weg: "/system/zugang") { ZugangSeite() }
    }

    // MARK: - Die Blätter

    #Preview("Blatt · Wärmepumpe") {
        Vorschaurahmen { Waermepumpenblatt() }
    }

    #Preview("Blatt · Entscheidungen") {
        Vorschaurahmen { Entscheidungsblatt() }
    }

    // MARK: - Einzelne Bausteine

    #Preview("Energiefluss") {
        Vorschaurahmen(breit: true) {
            Energiefluss(
                augenblick: Vorschau.augenblick(),
                jetzt: Vorschau.jetzt,
                pvSpitzeKw: 5.1,
                wpLaeuft: true
            )
            .padding()
        }
    }

    /// Nachts, mit dem Mond an der Stelle der Sonne. Der zweite Zustand des Bildes, und der,
    /// den die Wandanzeige die halbe Zeit zeigt.
    #Preview("Energiefluss bei Nacht") {
        Vorschaurahmen(breit: true) {
            Energiefluss(
                augenblick: Vorschau.augenblick(pv: 0, waermepumpe: 0, k1: false),
                jetzt: Vorschau.jetzt,
                wpLaeuft: false,
                nacht: true,
                sonneAb: "07:42"
            )
            .padding()
        }
    }

    /// Was passiert, wenn nichts da ist. Das ist der Zustand am ersten Tag und nach jedem
    /// Ausfall - und er ist genauso zu gestalten wie der gefüllte.
    #Preview("Energiefluss ohne Werte") {
        Vorschaurahmen(breit: true) {
            Energiefluss(augenblick: nil, jetzt: Vorschau.jetzt)
                .padding()
        }
    }

    #Preview("Das Dock") {
        Vorschaurahmen {
            Dock().padding()
        }
    }

    #Preview("Die Zeichen") {
        Vorschaurahmen {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], spacing: 18) {
                    ForEach(Zeichenart.allCases, id: \.self) { art in
                        VStack(spacing: 6) {
                            Zeichen(art, groesse: 30, farbe: Farbe.amber)
                            Text(art.rawValue)
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                        }
                    }
                }
                .padding()
            }
        }
    }

    /// Die Palette, wie sie wirklich aussieht. Die Zahlen daneben sind die gemessenen Abstände -
    /// dieselben, die `MarkenTests` festnagelt.
    #Preview("Die Palette") {
        Vorschaurahmen {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(
                        [
                            ("PV", Marken.pv), ("Netzbezug", Marken.netzBezug),
                            ("Einspeisung", Marken.netzEinspeisung), ("Batterie", Marken.batterie),
                            ("Wärmepumpe", Marken.waermepumpe), ("Ofen", Marken.ofen),
                            ("Wallbox", Marken.wallbox), ("Preis", Marken.preis),
                            ("Alarm", Marken.alarm), ("Achtung", Marken.achtung),
                        ],
                        id: \.0
                    ) { name, wert in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(wert))
                                .frame(width: 44, height: 26)
                            Text(name).font(Schrift.klein).foregroundStyle(Farbe.text1)
                            Spacer()
                            Text(wert.hex).font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                            Text("\(Formate.zahl(wert.kontrast(zu: Marken.flaeche2), stellen: 2)):1")
                                .font(Schrift.zahlKlein)
                                .foregroundStyle(
                                    wert.kontrast(zu: Marken.flaeche2) < 3 ? Farbe.achtung : Farbe.text3
                                )
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding()
            }
        }
    }
#endif
