import DuckCurveKit
import SwiftUI

/// Die Karte: der Kasten, in dem alles steht.
///
/// **Eine Fläche, zwei Formen.** Der Grund ist in beiden Fassungen derselbe: `--surface-2`
/// (`globals.css:72`), in dieser Anwendung ``Farbe/flaeche2``. Das war einmal anders - am iPad
/// stand ``Farbe/flaeche1``, und damit war die Karte dort so dunkel wie der Seitengrund. Dass es
/// auffiel, lag an den Rampen der Jahreskarte: ihr dunkelster Schritt *ist* die Kartenfläche
/// (`Marken.rampeEigen`, `#123544`), und „fast nichts“ verschmolz nur am Telefon mit dem Grund.
/// Eine Fläche, die auf zwei Schirmen zwei Farben hat, ist keine Fläche, sondern zwei.
///
/// Verschieden sind Rand, Radius und Polster, und `handy.css:182` nennt die Begründung: am Handy
/// haben Karten keinen Rand und einen grossen Radius, am iPad eine Haarlinie und einen kleinen
/// (`--radius-2`, also ``Marken/radius2``, dazu 20 Punkte Polster - `globals.css:73-75`). Der
/// Grund ist nicht Geschmack - bis zum 10.11.2026 war die Handy-Ansicht die iPad-Ansicht in einer
/// Spalte, und das ergab „viereinhalb Bildschirme gleich schwerer Kaesten“. Raender sind auf 390
/// Punkten Breite Laerm; auf 1180 Punkten sind sie Ordnung.
///
/// Umgeschaltet wird nach `horizontalSizeClass`, nicht nach Geraeteklasse: ein iPhone im
/// Querformat und ein iPad in einem schmalen Fenster sollen dasselbe bekommen.
struct Karte<Inhalt: View>: View {
    var kicker: String?
    var titel: String?
    /// Was rechts in der Kopfzeile steht - ein Umschalter, eine Zahl, ein Hinweis.
    ///
    /// Am Telefon steht es unter der Kopfzeile; siehe ``beiwerkzeile(_:)``.
    var beiwerk: AnyView?
    /// Die Akzentleiste oben: 3 Punkte Bernstein, nach rechts auslaufend.
    ///
    /// **Was die Vorlage damit auszeichnet.** `Card accent` (`ui/Card.tsx:4-5`,
    /// `globals.css:78-84`) steht in der ganzen Anwendung zweimal, beide Male auf der
    /// Prognoseseite: über „Was sich für die nächste Prognose ändert“
    /// (`forecast/ForecastPage.tsx:326`) und über „Wie der Rückblick zu lesen ist“
    /// (`forecast/Rueckblick.tsx:200`). Es sind die zwei Karten, die nicht messen, sondern
    /// einordnen - was sich ändert, und wie das Gezeigte zu lesen ist. Ohne die Leiste stehen
    /// sie zwischen den Messkarten wie zwei weitere Messungen.
    ///
    /// **Warum sie hier steht und nicht in der Seite.** Die Prognoseseite hatte dafür eine
    /// eigene Hülle `Akzentkarte`, und die musste den Kartenradius ein zweites Mal nennen, um
    /// nach der Leiste noch einmal zu schneiden. Ein Radius an zwei Stellen ist ein Radius, der
    /// auseinanderläuft.
    var akzent: Bool = false
    @ViewBuilder var inhalt: () -> Inhalt

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        rumpf
            .background(flaeche)
            .overlay(rand)
            // **Die Leiste liegt vor dem Schnitt.** Ein `overlay` nach dem `clipShape` stünde in
            // den Ecken über den Radius hinaus; die Vorlage schneidet an derselben Stelle mit
            // `overflow: hidden` (`globals.css:76`).
            .overlay(alignment: .top) { akzentleiste }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var rumpf: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kicker != nil || titel != nil || beiwerk != nil {
                kopf
            }
            inhalt()
        }
        .padding(schmal ? 16 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Die Kopfzeile.
    ///
    /// **Am Telefon bricht sie um** (`handy.css:183-185`: `.card-head { flex-wrap: wrap;
    /// row-gap: 3px }`, und das Beiwerk bekommt `flex-basis: 100%`). Darum sind es dort zwei
    /// Zeilen und keine.
    @ViewBuilder private var kopf: some View {
        if schmal {
            VStack(alignment: .leading, spacing: 3) {
                titelzeile
                if let beiwerk {
                    beiwerkzeile(beiwerk)
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                titelzeile
                if let beiwerk {
                    beiwerkrechts(beiwerk)
                }
            }
        }
    }

    /// Kicker und Titel.
    ///
    /// **Der Kicker fällt nie weg, und das war einmal anders.** Hier stand
    /// `if let kicker, titel == nil || !schmal` – am Telefon verschwand der Kicker also,
    /// sobald ein Titel dastand. Das trifft 23 Karten der App, und es nimmt ihnen genau das
    /// Falsche: Aus „Alarm · unscharf“ wurde „unscharf“, aus „Takten · zu wenig Daten“ wurde
    /// „zu wenig Daten“, aus „Pufferspeicher · lädt“ wurde „lädt“. Der Zustand blieb stehen,
    /// die Sache verschwand – und eine Karte, die nur „unscharf“ heißt, sagt nicht, was
    /// unscharf ist.
    ///
    /// Gedacht war es gegen zwei Überschriften auf schmalem Schirm. Die Lösung dafür ist
    /// nicht, eine wegzulassen, sondern sie nebeneinander zu setzen: der Kicker führt, der
    /// Titel steht rechts und leiser. So macht es auch das Dashboard, wo die Einordnung
    /// (`rechts={…}`) neben der Kernzahl steht und nicht an ihrer Stelle.
    private var titelzeile: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if schmal, let kicker, let titel {
                Text(kicker).font(Schrift.karte).foregroundStyle(Farbe.text1)
                Spacer(minLength: 8)
                Text(titel)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
                    .multilineTextAlignment(.trailing)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    if let kicker {
                        // Am Handy keine Sperrschrift: dort wird der Kicker zur Ueberschrift.
                        if schmal {
                            Text(kicker).font(Schrift.karte).foregroundStyle(Farbe.text1)
                        } else {
                            Kicker(wort: kicker)
                        }
                    }
                    if let titel {
                        Text(titel).font(Schrift.karte).foregroundStyle(Farbe.text1)
                    }
                }
                Spacer(minLength: 8)
            }
        }
    }

    /// Das Beiwerk am Telefon: eine eigene Zeile, linksbuendig, umbrechend.
    ///
    /// **`handy.css:185` gibt ihm `flex-basis: 100%`**, dazu `white-space: normal;
    /// overflow: visible; text-overflow: clip` - es bricht also unter die Kopfzeile und wird
    /// ausdruecklich nicht abgeschnitten. `ui/Card.tsx:24-25` nennt den Grund: „eine Legende
    /// soll umbrechen statt zu verschwinden: ein abgeschnittener Legendeneintrag ist schlimmer
    /// als eine zweite Zeile“.
    ///
    /// **Hier stand das Beiwerk am Telefon rechts neben dem Kicker**, und davon blieb bei einem
    /// ganzen Satz („0 Anforderungen bei stehender Maschine, am Beginn übereinandergelegt“) ein
    /// Wortfragment. Drei Seiten hatten sich darum ihre eigene Fassung gebaut - die Wirkungsseite
    /// eine zweite Zeile im Karteninhalt, die Fahrplanseite und die Prüfkurve je eine eigene
    /// Kopfzeile. Die Ausrichtung gehoert deshalb hierher und nicht in die Seiten: wer sie dort
    /// setzt, setzt sie fuer die falsche Breite mit.
    private func beiwerkzeile(_ ansicht: AnyView) -> some View {
        ansicht
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Dasselbe Beiwerk am iPad: rechts in der Kopfzeile, rechtsbuendig
    /// (`ui/Card.tsx:22`, `justify-between`).
    private func beiwerkrechts(_ ansicht: AnyView) -> some View {
        ansicht.multilineTextAlignment(.trailing)
    }

    /// Die Leiste: Bernstein, Bernstein weich, durchsichtig.
    ///
    /// **Die Farben kommen aus `--accent-bar`** und stehen jetzt an ``Marken/akzentband``,
    /// samt der Begruendung fuer die mittlere Stelle und fuer das durchsichtige Bernstein am
    /// Ende. Hier bleibt die Hoehe: drei Punkte (`globals.css:82`).
    @ViewBuilder private var akzentleiste: some View {
        if akzent {
            Farbe.akzentband.frame(height: 3)
        }
    }

    private var radius: CGFloat {
        // 16 am Telefon (`handy.css:182`). Zwanzig hat dort allein das Flussbild, und eine
        // Karte mit demselben Radius wie das Bild sieht aus wie ein zweites Bild. Am iPad
        // `--radius-2` (`globals.css:74`), nicht `--radius-3`: sechs Punkte sind an einem
        // Kasten von 1180 Punkten Breite eine weiche Ecke, drei sind eine Kante.
        schmal ? 16 : Marken.radius2
    }

    private var flaeche: Color {
        // `--surface-2` in beiden Fassungen (`globals.css:72`, `handy.css:182` aendert den Grund
        // nicht).
        Farbe.flaeche2
    }

    @ViewBuilder private var rand: some View {
        if schmal {
            EmptyView()
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        }
    }
}

extension Karte where Inhalt == EmptyView {
    init(kicker: String? = nil, titel: String? = nil, akzent: Bool = false) {
        self.kicker = kicker
        self.titel = titel
        self.beiwerk = nil
        self.akzent = akzent
        self.inhalt = { EmptyView() }
    }
}

/// Ein Satz als Beiwerk einer Karte - der haeufigste Fall, und der am oeftesten abgeschriebene.
///
/// **Warum es diesen Baustein gibt.** Zehn Seiten hatten dafuer eine eigene, Zeile fuer Zeile
/// gleiche Hilfsfunktion: `Text(satz).font(Schrift.winzig).foregroundStyle(Farbe.text3)
/// .multilineTextAlignment(.trailing)`. Drei Festlegungen, zehnmal getroffen - und alle drei
/// falsch am Telefon, wo das Beiwerk linksbuendig in einer eigenen Zeile steht
/// (``Karte/beiwerkzeile(_:)``).
///
/// **Die Groessen stehen in der Vorlage**: 12 Punkte am iPad (`ui/Card.tsx:26`, `text-[12px]`),
/// 13 am Telefon (`handy.css:185`, `font-size: 13px`). ``Schrift/winzig`` (11,5) war beides
/// nicht; am Telefon fehlten anderthalb Punkte an einer Zeile, die dort oft die laengste der
/// Karte ist.
struct Kartenhinweis: View {
    let satz: String
    /// Zahlenschrift - fuer Spannen, Zeitpunkte und Kennungen, die die Vorlage mit `.mono`
    /// setzt (etwa die Horizontspanne, `waerme/Fahrplan.tsx:577-586`).
    var mono: Bool = false

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Text(satz)
            .font(schrift)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var schrift: Font {
        let groesse: CGFloat = schmal ? 13 : 12
        return mono ? Schrift.mono(groesse) : Schrift.sans(groesse)
    }
}

extension Kartenhinweis {
    /// Dasselbe als `AnyView`, weil ``Karte/beiwerk`` eines nimmt.
    static func beiwerk(_ satz: String, mono: Bool = false) -> AnyView {
        AnyView(Kartenhinweis(satz: satz, mono: mono))
    }
}

/// Was auf einer Kachel steht. Daten, keine Ansicht.
///
/// **Warum getrennt.** Eine Kachel wird je nach Lage anders gezeichnet - am Handy fuehrt die
/// erste gross ueber die ganze Breite, am iPad stehen alle gleich. Waere die Kachel eine Ansicht,
/// muesste `Kachelfeld` sie dafuer veraendern, und eine Ansicht im ViewBuilder zu veraendern geht
/// nicht. Also sind es Daten, und gezeichnet wird daraus.
struct Kacheldaten: Identifiable {
    let wort: String
    let wert: String
    var einheit: String?
    /// Ein zweiter Satz unter dem Wort, wo einer noetig ist.
    var dazu: String?
    var farbe: Color = Farbe.text1
    /// Wohin ein Tippen fuehrt, wenn die Kachel irgendwohin fuehrt.
    var weg: String?

    var id: String { wort }

    /// Aus einer ``Kennzahl`` des Kerns. Die einzige Stelle, an der ein Ton zu einer Farbe
    /// wird - vorher stand diese Abbildung in jeder Seite neu, und auf der Startseite anders
    /// als auf der Fahrplanseite.
    init(_ k: Kennzahl) {
        self.init(k.wort, k.wert, einheit: k.einheit, dazu: k.dazu, farbe: Farbe.ton(k.ton))
    }

    init(
        _ wort: String, _ wert: String, einheit: String? = nil, dazu: String? = nil,
        farbe: Color = Farbe.text1, weg: String? = nil
    ) {
        self.wort = wort
        self.wert = wert
        self.einheit = einheit
        self.dazu = dazu
        self.farbe = farbe
        self.weg = weg
    }
}

/// Eine Kachel: eine Zahl, ein Wort, und beim Tippen mehr.
///
/// Das ist der haeufigste Baustein der Anwendung. Die Zahl fuehrt, das Wort erklaert, und wo ein
/// Wert alt oder abgeleitet ist, steht das klein dabei - nicht als Warnzeichen, sondern als
/// Auskunft.
struct Kachel: View {
    /// **In beiden Gestalten steht das Wort ueber der Zahl.** Am Telefon dreht die Vorlage
    /// beide Raster um (`handy.css:280`: `flex-direction: column-reverse` fuer die Zahlen des
    /// Tages; `Stat.tsx:9-11` setzt den Kicker ohnehin zuerst). Die App hatte es umgekehrt, und
    /// damit stand ueber jeder Zahl eine Zahl: beim Ueberfliegen einer Spalte findet das Auge
    /// erst den Namen und dann den Wert, nicht andersherum.
    ///
    /// Unterschieden sind sie in der Schrift und in der Fuehrung: auf der Startseite ein
    /// schlichtes Wort in 13 Punkten und vier gleich grosse Zahlen (`handy.css:279-283`), auf
    /// einer Berichtsseite ein gesperrter Kicker und eine fuehrende Zahl in 48 Punkten
    /// (`handy.css:197-207`).
    enum Art { case start, bericht }

    let daten: Kacheldaten
    /// Gross: die fuehrende Zahl einer Seite.
    var fuehrend: Bool = false
    var art: Art = .start
    /// Die Werte sind Spannen und brauchen am Telefon eine Stufe weniger.
    ///
    /// `handy.css:381-382` sagt es wörtlich: „Die Fahrplankacheln haben Spannen als Wert
    /// („2,8 bis 3,6“); die brauchen eine Stufe weniger“ - 21 statt 25 Punkte, und das gilt für
    /// `.kpi-handy`, also die fünf Felder der Vorlage, die Spannen zeigen (`Fahrplan.tsx:548`,
    /// `Wirkung.tsx:171`, `waermepumpe/Betrieb.tsx:73`, `Waermepumpe.tsx:93`,
    /// `Kennlinie.tsx:138`).
    var spannen: Bool = false

    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        if let weg = daten.weg {
            Button { wegweiser.gehe(weg) } label: { inhalt }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
        } else {
            inhalt
        }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: abstand) {
            // **Auf der Startseite dreht sich die Reihenfolge mit der Breite.** Am Telefon
            // steht das Wort über der Zahl (`handy.css:280`: `column-reverse`), an der Wand
            // darunter (`globals.css:253`). Das ist kein Versehen der Vorlage: auf dem Telefon
            // liest man eine Spalte von oben nach unten und sucht den Namen, an der Wand sieht
            // man im Vorbeigehen vier Zahlen und liest den Namen nur, wenn eine auffällt.
            if art == .bericht {
                Kicker(wort: daten.wort)
                zahl
            } else if schmal {
                wort
                zahl
            } else {
                zahl
                wort
            }
            hinweis
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var abstand: CGFloat {
        art == .bericht ? (fuehrend ? 8 : 5) : 5
    }

    private var wort: some View {
        Text(daten.wort)
            .font(Schrift.sans(13))
            .foregroundStyle(Farbe.text3)
    }

    private var zahl: some View {
        Zahl(
            wert: daten.wert,
            einheit: daten.einheit,
            schrift: schrift,
            einheitSchrift: einheitSchrift,
            farbe: daten.farbe
        )
        .kerning(art == .bericht && fuehrend ? -1.9 : 0)
    }

    private var schrift: Font {
        if fuehrend {
            // **Die fuehrende Zahl hat eine feste Groesse.** `Typografie` begruendet es am Kopf:
            // sie ist schon so gross, dass eine weitere Stufe den Umbruch zerlegt - „1.234,5“ in
            // 80 Punkten passt auf kein Telefon. Die Zahlen daneben wachsen mit.
            return art == .bericht ? Schrift.custom(48) : Schrift.zahlFuehrend
        }
        return Schrift.mono(zahlgroesse, relativeTo: .title2)
    }

    /// Die Groesse der Kachelzahl.
    ///
    /// **Drei Stufen, und die App hatte durchweg 25.** Am Breitbild 26 (`ui/Stat.tsx:9`:
    /// `text-[26px]`), am Telefon 25 (`handy.css:202`) - und 21, wo die Werte Spannen sind
    /// (`handy.css:382`, siehe ``spannen``). Der fehlende Punkt am Breitbild klingt nach nichts;
    /// er ist der Unterschied zwischen einer Zahl, die die Karte traegt, und einer, die neben
    /// ihrem Kicker steht.
    private var zahlgroesse: CGFloat {
        guard schmal else { return 26 }
        return spannen ? 21 : 25
    }

    private var einheitSchrift: Font {
        if fuehrend {
            return art == .bericht ? Schrift.sans(18) : Schrift.klein
        }
        // 13 am Breitbild (`ui/Stat.tsx:11`: `text-[13px]`), 13,5 am Telefon
        // (`handy.css:203`).
        return Schrift.sans(schmal ? 13.5 : 13)
    }

    @ViewBuilder private var hinweis: some View {
        if let dazu = daten.dazu {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                // Ein Pfeil sagt, dass die Zeile irgendwohin fuehrt (`Stat.tsx:16`).
                if daten.weg != nil {
                    Text("›").font(Schrift.sans(13)).foregroundStyle(Farbe.amber)
                }
                Text(dazu)
                    .font(art == .bericht ? Schrift.sans(fuehrend ? 14.5 : 13) : Schrift.winzig)
                    .foregroundStyle(art == .bericht && fuehrend ? Farbe.text2 : Farbe.text3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Mehrere Kacheln in einer Flaeche, durch Haarlinien getrennt.
///
/// **Warum eine Flaeche und nicht sechs Karten.** `handy.css`, Entscheidung 3: „Flaechen statt
/// Rahmen“. Sechs Kacheln mit je einem Rahmen sind sechs gleich schwere Kaesten; eine Flaeche
/// mit Haarlinien ist eine Tabelle. Am iPad gilt dasselbe, nur dass die Flaeche dort einen Rand
/// bekommt.
struct Kachelfeld: View {
    let kacheln: [Kacheldaten]
    var kicker: String?
    /// Die erste Kachel ueber die ganze Breite - `handy.css`, Entscheidung 2: „Eine Zahl fuehrt.“
    var ersteFuehrt: Bool = true
    /// Eine feste Spaltenzahl. Wer eine ``staffelung`` mitgibt, braucht sie nicht.
    var spalten: Int = 2
    /// Die Gestalt der Kacheln. Auf einer Berichtsseite fuehrt das Wort, auf der Startseite die
    /// Zahl - siehe ``Kachel/Art``.
    var art: Kachel.Art = .bericht
    /// Die Werte sind Spannen - siehe ``Kachel/spannen``.
    var spannen: Bool = false
    /// Die Spaltenzahl nach Breite gestaffelt, statt einer festen.
    ///
    /// **Warum das Feld sich selbst messen muss.** Die Vorlage staffelt jede Kachelreihe zweimal
    /// (`Fahrplan.tsx:548`: `grid-cols-2 md:grid-cols-4 xl:grid-cols-7`), und die obere Stufe
    /// liegt zwischen einem iPad hochkant und einem quer - `horizontalSizeClass` kennt sie nicht.
    /// Darum stand der Messaufbau auf der Fahrplanseite: ein `@State` und ein `GeometryReader`
    /// im Hintergrund, in einer Seite, die davon nichts wissen will. Er steht jetzt hier, und
    /// die Schwellen stehen in ``Kachelraster`` - im Kern, wo sie geprueft werden.
    var staffelung: Kachelraster?

    @Environment(\.horizontalSizeClass) private var breite

    /// Die gemessene Breite des Felds. Vor der ersten Messung null, und ``Kachelraster`` antwortet
    /// darauf mit der untersten Stufe.
    @State private var gemessen: CGFloat = 0

    private var schmal: Bool { breite == .compact }

    /// Wie viele Kacheln in eine Reihe kommen: die Staffelung, wo es eine gibt.
    private var spaltenzahl: Int {
        guard let staffelung else { return spalten }
        return staffelung.spalten(breite: Double(gemessen))
    }

    var body: some View {
        feld.background { messer }
    }

    private var feld: some View {
        Karte(kicker: kicker) {
            if schmal, ersteFuehrt, let erste = kacheln.first {
                VStack(spacing: 0) {
                    Kachel(daten: erste, fuehrend: true, art: art, spannen: spannen)
                        .padding(.bottom, kacheln.count > 1 ? 12 : 0)
                    if kacheln.count > 1 {
                        Divider().overlay(Farbe.linie1)
                        gitter(Array(kacheln.dropFirst()))
                            .padding(.top, 12)
                    }
                }
            } else {
                gitter(kacheln)
            }
        }
    }

    /// Der Breitenleser.
    ///
    /// **Er steht im Hintergrund**, weil eine Flaeche dort die Groesse ihres Vordergrunds annimmt
    /// und damit nichts an der Anordnung aendert; `GeometryReader` als Huelle wuerde die Hoehe des
    /// Kachelfelds auffressen. Ohne Staffelung wird gar nicht gemessen - ein Leser, dessen
    /// Antwort niemand liest, ist nur ein Zeichendurchgang mehr.
    @ViewBuilder private var messer: some View {
        if staffelung != nil {
            GeometryReader { raum in
                Color.clear
                    .onChange(of: raum.size.width, initial: true) { _, neu in
                        gemessen = neu
                    }
            }
        }
    }

    private func gitter(_ welche: [Kacheldaten]) -> some View {
        let anzahl = spaltenzahl
        let reihen = zeilen(welche)
        return VStack(spacing: 0) {
            ForEach(Array(reihen.enumerated()), id: \.offset) { stelle, reihe in
                if stelle > 0 {
                    Divider().overlay(Farbe.linie1).padding(.vertical, 10)
                }
                HStack(alignment: .top, spacing: 12) {
                    ForEach(reihe) { daten in
                        Kachel(daten: daten, art: art, spannen: spannen)
                    }
                    // Die letzte Reihe auffuellen, damit eine einzelne Kachel nicht die ganze
                    // Breite nimmt und neben ihren Nachbarinnen falsch aussieht.
                    // Nur am Telefon (`handy.css:200`): am iPad steht das Raster in einer
                    // Karte mit Rand, und eine Kachel, die dort ploetzlich doppelt so breit
                    // ist wie ihre Nachbarinnen, sieht aus wie ein Fehler im Raster.
                    if reihe.count < anzahl, !schmal || reihe.count > 1
                        || welche.count % anzahl == 0
                    {
                        ForEach(0..<(anzahl - reihe.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
    }

    /// Die Kacheln in Zeilen.
    ///
    /// **Eine einzelne letzte Kachel nimmt die ganze Breite** (`handy.css:200`:
    /// `.kpi-grid > .card:last-child:nth-child(even)`). Sie neben einer leeren Haelfte stehen
    /// zu lassen sieht aus wie eine, die fehlt - und gerade die letzte ist oft die mit dem
    /// laengsten Satz darunter („53,8 kWh · Rechnungen pruefen“).
    private func zeilen(_ welche: [Kacheldaten]) -> [[Kacheldaten]] {
        welche.chunked(spaltenzahl)
    }
}

extension Array {
    /// In Stuecke fester Laenge zerlegen. Das letzte Stueck darf kuerzer sein.
    func chunked(_ groesse: Int) -> [[Element]] {
        guard groesse > 0 else { return [self] }
        var aus: [[Element]] = []
        var i = 0
        while i < count {
            aus.append(Array(self[i..<Swift.min(i + groesse, count)]))
            i += groesse
        }
        return aus
    }
}

/// Eine Zeile aus Beschriftung und Wert, wie sie in Tabellen und Listen steht.
struct Zeile: View {
    let wort: String
    let wert: String
    var einheit: String?
    // **Reihenfolge mit Bedacht:** `dazu` ist Inhalt, `farbe` ist Darstellung, und die
    // Reihenfolge der Felder ist hier die Reihenfolge der Argumente - ein getauschtes Paar
    // uebersetzt nicht. Inhalt zuerst, wie auch bei `Kachel`.
    var dazu: String?
    var farbe: Color = Farbe.text1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                if let dazu {
                    Text(dazu).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
            Spacer(minLength: 8)
            Zahl(wert: wert, einheit: einheit, farbe: farbe)
        }
        .padding(.vertical, 5)
    }
}

/// Was dasteht, solange nichts da ist.
///
/// **Nicht „Fehler“ und nicht nichts.** Eine leere Karte ohne Wort laesst offen, ob gerade
/// geladen wird oder ob es nichts zu zeigen gibt - und an einer Wandanzeige steht sie dann
/// stundenlang so da.
struct Leer: View {
    let satz: String
    var dazu: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(satz).font(Schrift.klein).foregroundStyle(Farbe.text2)
            if let dazu {
                Text(dazu).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }
}

/// Ein Fehler, der dasteht, ohne die Seite zu ersetzen.
///
/// Die Seite behaelt, was sie schon hat - ein Diagramm von vorhin ist mehr wert als eine
/// Fehlermeldung, die die ganze Flaeche nimmt.
///
/// **Ein Band und kein Kasten.** Die Vorlage hat dafuer eine Gestalt, und nur diese eine:
/// `ErrorBanner` (`reports/ReportShell.tsx:147-153`) ist Rahmen `rgba(224,83,61,.4)`, Flaeche
/// `rgba(224,83,61,.12)`, Radius `3px` und Mono 12 in Grossbuchstaben mit Laufweite `.1em`, der
/// Satz in `--alert`. `rgba(224,83,61,…)` ist ``Marken/alarm``; die drei Deckungen sind die der
/// Vorlage und keine erfundenen. Die App zeichnete stattdessen einen Kasten in
/// ``Farbe/flaeche2`` mit einem Warnzeichen davor - eine Karte in einer Karte, die aussah wie
/// ein weiterer Abschnitt der Seite. Das Zeichen faellt weg: das rote Band *ist* das Zeichen,
/// und in der Vorlage steht keines.
///
/// **Alle Aufrufstellen wollen dieselbe Gestalt.** Es sind 28, und die Vorlage setzt an jeder
/// davon dasselbe Band - fuer den Fehler eines Dienstes wie fuer den einer einzelnen Datei
/// (`reports/InvoiceCheck.tsx:207`, neunmal gleich in den uebrigen Berichtsseiten).
///
/// **Zwei Fassungen, weil nicht jeder Fehlschlag einen Code hat.** Ein ``ApiFehler`` bringt Rat
/// und Code mit; „okt.pdf: Kein Tibber-Layout erkannt.“ ist ein Satz über eine einzelne Datei
/// und hat keinen - und einen zu erfinden, damit der Baustein passt, wäre die falsche Richtung.
/// Darum nimmt die zweite Fassung reinen Text. Ein eigenes Band dafür hatte die Rechnungsseite
/// bis zum 20.11.2026; die Vorlage hat für beides dasselbe, und zwei verschieden gefärbte Bänder
/// übereinander sehen nach zwei Arten von Unglück aus, wo es eine ist.
struct Stoerung: View {
    /// Was schiefging, in einem Satz für Menschen (``ApiFehler/rat``).
    let satz: String
    /// Der Code als zweite Zeile, wo es einen gibt.
    let code: String?
    var erneut: (() -> Void)?

    /// Ein Fehler des Dienstes: sein Rat, sein Code.
    ///
    /// **„network“ steht nicht dabei:** der Rat sagt bei einem Netzfehler schon alles, und der
    /// Code darunter wäre dasselbe noch einmal, nur englisch.
    init(fehler: ApiFehler, erneut: (() -> Void)? = nil) {
        self.satz = fehler.rat
        self.code = fehler.code == "network" ? nil : fehler.code
        self.erneut = erneut
    }

    /// Reiner Text, ohne Code: der Fehlschlag einer einzelnen Datei.
    init(satz: String, erneut: (() -> Void)? = nil) {
        self.satz = satz
        self.code = nil
        self.erneut = erneut
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            saetze
            Spacer(minLength: 8)
            if let erneut {
                knopf(erneut)
            }
        }
        // `px-4 py-3` (`ReportShell.tsx:149`).
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Farbe.alarm.opacity(0.12))
        .overlay(rahmen)
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
    }

    private var saetze: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(satz.uppercased())
                .font(Self.bandschrift)
                .tracking(Self.laufweite)
                .foregroundStyle(Farbe.alarmText)
                .fixedSize(horizontal: false, vertical: true)
            if let code {
                // Derselbe Ton wie der Satz, nur eine Zeile tiefer: auf einer roten Flaeche
                // traegt kein zweiter Grauwert, und die Vorlage kennt fuer das Band keinen.
                Text(code.uppercased())
                    .font(Self.bandschrift)
                    .tracking(Self.laufweite)
                    .foregroundStyle(Farbe.alarmText)
            }
        }
    }

    /// **Der Knopf ist eine Zutat der App.** Die Vorlage hat keinen - dort laedt man die Seite
    /// neu. Er bleibt, weil eine Wandanzeige niemanden hat, der sie neu laedt; in Bernstein, der
    /// Handlungsfarbe des Hauses, damit er nicht als Teil der Meldung gelesen wird.
    private func knopf(_ tun: @escaping () -> Void) -> some View {
        Button("Erneut".uppercased(), action: tun)
            .font(Self.bandschrift)
            .tracking(Self.laufweite)
            .buttonStyle(.plain)
            .foregroundStyle(Farbe.amber)
    }

    private var rahmen: some View {
        RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
            .strokeBorder(Farbe.alarm.opacity(0.4), lineWidth: 1)
    }

    /// Mono 12 (`ReportShell.tsx:149`, `text-[12px]` an `.mono`).
    private static let bandschrift: Font = Schrift.mono(12, relativeTo: .caption)
    /// `tracking-[.1em]` bei 12 Punkten.
    private static let laufweite: CGFloat = 1.2
}
