import DuckCurveKit
import SwiftUI

/// Welche Seite zu einem Weg gehoert.
///
/// Alle 29 Seiten des Dashboards, unter denselben Adressen. Das ist absichtlich eine einzige
/// Stelle mit einem langen `switch` und keine Tabelle aus Bauanweisungen: ein `switch` ueber
/// Zeichenketten laesst sich lesen, und der Compiler sagt nichts dazu, ob eine Tabelle
/// vollstaendig ist. Dass jeder Weg aus `Bereiche.alleWege` hier ankommt, prueft dagegen ein
/// Test im Kern (`testJederWegFindetSeinenBereich`) - und was dort durchfaellt, landet unten im
/// `default` und sagt es.
///
/// **Warum `AnyView` und nicht `some View`.** Ein `switch` im ViewBuilder baut aus jedem Zweig
/// eine Schachtel: bei 29 Zweigen steht am Ende ein Typ, der 29 Ebenen tief ineinandersteckt.
/// Das uebersetzt entweder sehr langsam oder gar nicht - „unable to type-check this expression in
/// reasonable time" ist genau dieser Fall, und er trifft eine Datei, die beim Bauen nicht
/// umgangen werden kann. `AnyView` kostet hier nichts: die Huelle wird einmal je Seitenwechsel
/// gebaut, nicht einmal je Bild.
struct Seitenwahl: View {
    let weg: String

    var body: some View {
        seite
    }

    private var seite: AnyView {
        switch sauber {
        // ------------------------------------------------------------------ Jetzt
        case "/":
            return AnyView(JetztSeite())

        // ------------------------------------------------------------------- Haus
        case "/haus":
            return AnyView(HausSeite())

        // ---------------------------------------------------------------- Energie
        case "/strom":
            return AnyView(StromSeite())
        case "/waerme":
            return AnyView(WaermeSeite())
        case "/strom/pv":
            return AnyView(PvSeite())
        case "/strom/speicher":
            return AnyView(SpeicherSeite())
        case "/strom/wallbox":
            return AnyView(WallboxSeite())
        case "/strom/jahr":
            return AnyView(JahreskarteSeite())

        // ------------------------------------------------------------------- Geld
        case "/geld":
            return AnyView(KostenSeite())
        case "/geld/pv-abrechnung":
            return AnyView(PvAbrechnungSeite())
        case "/geld/rechnungen":
            return AnyView(RechnungenSeite())

        // ---------------------------------------------------------------- Technik
        case "/waerme/anlage":
            return AnyView(AnlageSeite())
        case "/waerme/wiedergabe":
            return AnyView(WiedergabeSeite())
        case "/waerme/waermepumpe":
            return AnyView(WaermepumpeSeite())
        case "/waerme/waermepumpe/betrieb":
            return AnyView(BetriebSeite())
        case "/waerme/waermepumpe/kennlinie":
            return AnyView(KennlinieSeite())
        case "/waerme/waermepumpe/regler":
            return AnyView(ReglerSeite())
        case "/waerme/fahrplan":
            return AnyView(FahrplanSeite())
        case "/waerme/nachbetrachtung":
            return AnyView(NachbetrachtungSeite())
        case "/waerme/wirkung":
            return AnyView(WirkungSeite())
        case "/waerme/raeume":
            return AnyView(HeizkreiseSeite())
        case "/waerme/bilanz":
            return AnyView(WaermebilanzSeite())
        case "/waerme/annahmen":
            return AnyView(AnnahmenSeite())
        case "/system":
            return AnyView(PrognoseSeite())
        case "/system/daten":
            return AnyView(DatenSeite())
        case "/system/mitteilungen":
            return AnyView(MitteilungenSeite())
        case "/system/haustuer":
            return AnyView(HaustuerSeite())
        case "/system/zugang":
            return AnyView(ZugangSeite())

        default:
            return AnyView(Unbekannt(weg: sauber))
        }
    }

    /// Fragezeichenteil und Schraegstriche am Ende weg - wie `Bereiche` es auch tut.
    private var sauber: String {
        var s = weg.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? "/"
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s.isEmpty ? "/" : s
    }
}

/// Ein Weg, zu dem es keine Seite gibt.
///
/// Das soll nie zu sehen sein - es kann aber, wenn eine Mitteilung ein Ziel traegt, das eine
/// neuere Fassung des Dienstes kennt und diese App noch nicht. Dann ist ein Satz besser als eine
/// leere Flaeche.
struct Unbekannt: View {
    let weg: String

    var body: some View {
        Seite {
            Karte(titel: "Diese Seite kennt die App nicht") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Der Weg „\(weg)“ gehört zu keiner Seite dieser Fassung.")
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text2)
                    Text("Vermutlich ist der Dienst neuer als die App. Im Dashboard ist die Seite da.")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                }
            }
        }
    }
}

/// Die Huelle jeder Seite: ein Rollbereich mit Rand und gleichmaessigen Abstaenden.
///
/// **Warum eine eigene Huelle und nicht `ScrollView` an jeder Stelle.** Dreissig Seiten, die
/// jede ihren eigenen Rand setzen, haben dreissig verschiedene Raender - im Dashboard ist das
/// zweimal passiert und beide Male erst an der Wand aufgefallen. Hier steht der Rand einmal.
struct Seite<Inhalt: View>: View {
    var zeitraum: Zeitraumleiste?
    @ViewBuilder var inhalt: () -> Inhalt

    @Environment(\.horizontalSizeClass) private var breite

    var body: some View {
        VStack(spacing: 0) {
            if let zeitraum {
                zeitraum
                    .padding(.horizontal, breite == .compact ? 16 : 16)
                    .padding(.bottom, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: breite == .compact ? 12 : 14) {
                    inhalt()
                }
                // **Die Breite steht fest, bevor der Rand kommt.** Ohne diesen Rahmen bestimmt
                // das breiteste Kind die Spalte: ein `HStack`, der 68 Punkte zu breit ist,
                // macht die Spalte 68 Punkte breiter als der Schirm, und eine `ScrollView`
                // zentriert zu breiten Inhalt. Die Folge war keine abgeschnittene Karte,
                // sondern eine Seite ohne Rand - jedes Element 18 Punkte zu weit links,
                // sichtbar am 17.11. auf dem Telefon. Jetzt ueberlaeuft im Zweifel ein Kind,
                // und nicht die Seite.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }
}

extension Seite where Inhalt == EmptyView {
    init() {
        self.zeitraum = nil
        self.inhalt = { EmptyView() }
    }
}

/// Die Zeile, mit der ein Bereich seinen Zeitraum stellt.
///
/// Links die Spanne (Tag, Woche, Monat, Jahr), rechts das Blaettern. „Vorwaerts" ist aus, wenn
/// der Zeitraum schon der laufende ist - ein Bericht ueber morgen ist keiner.
struct Zeitraumleiste: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Welche Spannen diese Seite anbietet. Die Jahreskarte kennt nur das Jahr.
    var spannen: [Spanne] = Spanne.allCases

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        HStack(spacing: 10) {
            if spannen.count > 1 {
                Ansichtswahl(
                    ansichten: spannen.map { Ansicht(weg: $0.rawValue, name: $0.name) },
                    aktiv: Ansicht(weg: z.spanne.rawValue, name: z.spanne.name)
                ) { a in
                    guard let neu = Spanne(rawValue: a.weg) else { return }
                    wegweiser.setzeZeitraum(z.mit(neu))
                }
            }
            Spacer(minLength: 4)
            blaettern(z)
        }
    }

    private func blaettern(_ z: Zeitraum) -> some View {
        let aktuell = z.istAktuell(jetzt: haus.jetzt)
        return HStack(spacing: 8) {
            Button {
                wegweiser.setzeZeitraum(z.verschoben(-1))
            } label: {
                Text("‹").font(Schrift.karte).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Farbe.text2)
            .accessibilityLabel("Zurück")

            Text(z.kurz)
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text1)
                .frame(minWidth: 92)
                .accessibilityLabel(z.name)

            Button {
                wegweiser.setzeZeitraum(z.verschoben(1))
            } label: {
                Text("›").font(Schrift.karte).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(aktuell ? Farbe.text3 : Farbe.text2)
            .disabled(aktuell)
            .accessibilityLabel("Vorwärts")
        }
        .background(Farbe.flaeche2)
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }
}
