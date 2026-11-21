import DuckCurveKit
import SwiftUI

/// Welche Seite zu einem Weg gehoert.
///
/// Alle 28 Seiten des Dashboards, unter denselben Adressen. Das ist absichtlich eine einzige
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
            // Der Fragezeichenteil wählt die Seite nicht, aber er sagt ihr, wo sie anfangen soll:
            // aus der Jahreskarte kommt ein Tag und eine Stunde (`YearMap.tsx:82`). Gelesen und
            // geprüft wird das im Kern, damit ein erfundener Tag hier nicht durchkommt.
            return AnyView(WiedergabeSeite(ziel: Wiedergabeziel.ausWeg(weg)))
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
            // Wie bei der Wiedergabe wählt der Fragezeichenteil die Seite nicht, aber er sagt
            // ihr, welchen Tag sie zeigt: von der Wärmeseite kommt der gelesene Tag mit
            // (`HeatOverview.tsx:268`). Geprüft wird er im Kern.
            return AnyView(NachbetrachtungSeite(weg: weg))
        case "/waerme/wirkung":
            return AnyView(WirkungSeite())
        case "/waerme/raeume":
            return AnyView(HeizkreiseSeite())
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
        case "/system/geraet":
            return AnyView(HausgeraetSeite())
        case "/system/zugang":
            return AnyView(ZugangSeite())

        default:
            return AnyView(Unbekannt(weg: sauber))
        }
    }

    /// Fragezeichenteil und Schraegstriche am Ende weg, und alte Adressen auf ihren Nachfolger.
    ///
    /// **Hier steht die Weiterleitung, nicht in einer Ansicht.** Next.js hat zwei Mittel dafuer -
    /// `redirects()` in `apps/web/next.config.ts:17` und `redirect()` in einer Seite, die sonst
    /// nichts tut (`apps/web/src/app/waerme/bilanz/page.tsx:14`); eine App hat nur ihren
    /// Wegweiser. Die Aufloesung ist eine reine Rechnung ueber Zeichenketten und liegt deshalb im
    /// Kern (``Bereiche/ziel(_:)``), geprueft von `AlteWegeTests`. Eine Umleitungsansicht, die im
    /// Zeichnen `wegweiser.gehe(...)` ruft, waere der andere Weg - und genau der, vor dem
    /// `Navigation.swift:56-62` warnt („Modifying state during view update“).
    ///
    /// Der Zeitraum muss dabei nichts mitnehmen: er haengt am Bereich und nicht an der Adresse
    /// (`Navigation.swift:22,69-81`), und alte wie neue Adresse liegen im selben Bereich.
    private var sauber: String {
        Bereiche.ziel(weg)
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
///
/// **Und darum traegt sie auch den Kicker.** Die Vorlage gibt ihn der Huelle jeder Seite
/// (`AreaShell.tsx:14,26`), nicht der Seite; `ReportShell` reicht ihn nur weiter
/// (`ReportShell.tsx:103`). Das Gegenstueck zu `AreaShell` ist diese Ansicht - jede der
/// achtundzwanzig Seiten steckt in ihr, ``Berichtsseite`` baut sich selbst aus ihr. Stuende er
/// in ``Berichtsseite``, haetten ihn dreizehn Seiten und fuenfzehn nicht.
struct Seite<Inhalt: View>: View {
    var zeitraum: Zeitraumleiste?
    @ViewBuilder var inhalt: () -> Inhalt

    @Environment(\.horizontalSizeClass) private var breite
    @Environment(Wegweiser.self) private var wegweiser

    var body: some View {
        VStack(spacing: 0) {
            kicker
            // **Am Telefon steht die Zeitwahl im Gerippe**, ueber den Reitern und neben dem
            // Namen des Bereichs - so wie in der Vorlage (`handy.css:146-161`). Hier stand sie
            // unter den Reitern, und der Name des Bereichs stand nirgends.
            if let zeitraum, breite != .compact {
                zeitraum
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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

    /// Die Stichworte, die sagen, was auf der Seite steht - „Laeufe · Abtauen · Heizkurve“.
    ///
    /// **Rechts und nicht links.** Die Vorlage setzt die Reiterzeile auf `justify-between` und
    /// haengt den Kicker an ihr rechtes Ende (`AreaNav.tsx:93,96`). Die Reiterzeile der App
    /// zeichnet das Gerippe und nicht die Huelle; der Kicker steht darum in einer eigenen Zeile
    /// unmittelbar darunter - aber am rechten Rand, wo die Vorlage ihn hat, und ueber dem
    /// Rollbereich, damit er wie dort beim Blaettern stehen bleibt.
    ///
    /// **Am Telefon faellt er weg**, und das ist nicht gespart, sondern abgeschrieben: er traegt
    /// `hidden … md:block` (`AreaNav.tsx:96`) und ist unter 768 Punkten nicht zu sehen.
    /// `handy.css` holt ihn auch nicht zurueck - was dort auf lesbare Schrift umgestellt wird,
    /// ist der Kicker **einer Karte** (`handy.css:184`, `.card-head h2.kicker`) und der der
    /// Methodenkarte (`handy.css:214`), nicht dieser. Am Telefon sagen Bereichsname, Reiterzeile
    /// und Unteransichten schon zu dritt, wo man ist; eine vierte Antwort auf 390 Punkten kostet
    /// nur die Zeile, in der die erste Zahl stehen sollte.
    @ViewBuilder private var kicker: some View {
        if breite != .compact, let wort = Bereiche.kicker(fuer: wegweiser.weg) {
            Kicker(wort: wort)
                // `truncate` an derselben Stelle: ein Kicker, der umbricht, schiebt die Seite
                // nach unten.
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
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
///
/// **Am Telefon steht sie nicht hier.** Dort zerfaellt sie in zwei Teile, die an zwei Stellen
/// des Gerippes stehen: der Datumskasten neben dem Bereichsnamen, die Spannen als breiter
/// Schalter darunter - und beides ueber den Reitern (`handy.css:146-161`). Das zeichnet
/// ``HandRahmen``; diese Ansicht ist die der Wand.
struct Zeitraumleiste: View {
    @Environment(Wegweiser.self) private var wegweiser

    /// Welche Spannen diese Seite anbietet. Ohne Angabe die des Reiters.
    var spannen: [Spanne]?

    private var welche: [Spanne] {
        spannen ?? Bereiche.spannen(fuer: wegweiser.weg) ?? Spanne.allCases
    }

    var body: some View {
        HStack(spacing: 10) {
            if welche.count > 1 {
                Spannenwahl(spannen: welche)
            }
            Spacer(minLength: 4)
            Datumskasten()
        }
    }
}

/// Die Wahl der Spanne: Tag, Woche, Monat, Jahr.
struct Spannenwahl: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    let spannen: [Spanne]

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        Ansichtswahl(
            ansichten: spannen.map { Ansicht(weg: $0.rawValue, name: $0.name) },
            aktiv: Ansicht(weg: z.spanne.rawValue, name: z.spanne.name)
        ) { a in
            guard let neu = Spanne(rawValue: a.weg) else { return }
            wegweiser.setzeZeitraum(z.mit(neu))
        }
    }
}

/// Der Kasten zum Blaettern: zurueck, der Zeitraum, vorwaerts.
struct Datumskasten: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        let aktuell = z.istAktuell(jetzt: haus.jetzt)
        HStack(spacing: schmal ? 2 : 8) {
            Button {
                wegweiser.setzeZeitraum(z.verschoben(-1))
            } label: {
                Text("‹")
                    .font(schmal ? Schrift.sans(16) : Schrift.karte)
                    .frame(width: schmal ? 34 : 28, height: schmal ? 34 : 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Farbe.text2)
            .accessibilityLabel("Zurück")

            Text(z.kurz)
                .font(schmal ? Schrift.mono(13.5) : Schrift.zahlKlein)
                .foregroundStyle(Farbe.text1)
                .lineLimit(1)
                .padding(.horizontal, schmal ? 4 : 0)
                .frame(minWidth: schmal ? 0 : 92)
                .accessibilityLabel(z.name)

            Button {
                wegweiser.setzeZeitraum(z.verschoben(1))
            } label: {
                Text("›")
                    .font(schmal ? Schrift.sans(16) : Schrift.karte)
                    .frame(width: schmal ? 34 : 28, height: schmal ? 34 : 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(aktuell ? Farbe.text3 : Farbe.text2)
            .disabled(aktuell)
            .accessibilityLabel("Vorwärts")

            // **„heute" nur, wenn man nicht heute ist** (`ReportShell.tsx:114`): ein Knopf, der
            // nichts tut, ist einer zu viel.
            if !aktuell {
                Button {
                    wegweiser.setzeZeitraum(Zeitraum.heute(z.spanne, jetzt: haus.jetzt))
                } label: {
                    Text("HEUTE")
                        .font(Schrift.kicker)
                        .kerning(0.6)
                        .foregroundStyle(Farbe.amber)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zu heute")
            }
        }
        .padding(schmal ? 3 : 0)
        .background(schmal ? Color.white.opacity(0.07) : Farbe.flaeche2)
        .clipShape(
            RoundedRectangle(cornerRadius: schmal ? 11 : Marken.radius3, style: .continuous))
    }
}
