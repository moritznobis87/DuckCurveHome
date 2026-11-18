import DuckCurveKit
import SwiftUI

/// Die Karte: der Kasten, in dem alles steht.
///
/// **Zwei Fassungen, nach Breite.** `handy.css` nennt die Begruendung: am Handy haben Karten
/// keinen Rand, einen grossen Radius und heben sich ueber die Helligkeit vom Grund ab; am iPad
/// haben sie eine Haarlinie und einen kleinen Radius. Der Grund ist nicht Geschmack - bis zum
/// 10.11.2026 war die Handy-Ansicht die iPad-Ansicht in einer Spalte, und das ergab
/// „viereinhalb Bildschirme gleich schwerer Kaesten". Raender sind auf 390 Punkten Breite
/// Laerm; auf 1180 Punkten sind sie Ordnung.
///
/// Umgeschaltet wird nach `horizontalSizeClass`, nicht nach Geraeteklasse: ein iPhone im
/// Querformat und ein iPad in einem schmalen Fenster sollen dasselbe bekommen.
struct Karte<Inhalt: View>: View {
    var kicker: String?
    var titel: String?
    /// Was rechts in der Kopfzeile steht - ein Umschalter, eine Zahl, ein Hinweis.
    var beiwerk: AnyView?
    @ViewBuilder var inhalt: () -> Inhalt

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kicker != nil || titel != nil || beiwerk != nil {
                kopf
            }
            inhalt()
        }
        .padding(schmal ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(flaeche)
        .overlay(rand)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Die Kopfzeile.
    ///
    /// **Der Kicker fällt nie weg, und das war einmal anders.** Hier stand
    /// `if let kicker, titel == nil || !schmal` – am Telefon verschwand der Kicker also,
    /// sobald ein Titel dastand. Das trifft 23 Karten der App, und es nimmt ihnen genau das
    /// Falsche: Aus „Alarm · unscharf" wurde „unscharf", aus „Takten · zu wenig Daten" wurde
    /// „zu wenig Daten", aus „Pufferspeicher · lädt" wurde „lädt". Der Zustand blieb stehen,
    /// die Sache verschwand – und eine Karte, die nur „unscharf" heißt, sagt nicht, was
    /// unscharf ist.
    ///
    /// Gedacht war es gegen zwei Überschriften auf schmalem Schirm. Die Lösung dafür ist
    /// nicht, eine wegzulassen, sondern sie nebeneinander zu setzen: der Kicker führt, der
    /// Titel steht rechts und leiser. So macht es auch das Dashboard, wo die Einordnung
    /// (`rechts={…}`) neben der Kernzahl steht und nicht an ihrer Stelle.
    private var kopf: some View {
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
            if let beiwerk {
                beiwerk
            }
        }
    }

    private var radius: CGFloat {
        // 16 am Telefon (`handy.css:182`). Zwanzig hat dort allein das Flussbild, und eine
        // Karte mit demselben Radius wie das Bild sieht aus wie ein zweites Bild.
        schmal ? 16 : Marken.radius3
    }

    private var flaeche: Color {
        // Am Handy heller als der Grund, damit sie sich ohne Rand abhebt.
        schmal ? Farbe.flaeche2 : Farbe.flaeche1
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
    init(kicker: String? = nil, titel: String? = nil) {
        self.kicker = kicker
        self.titel = titel
        self.beiwerk = nil
        self.inhalt = { EmptyView() }
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

    @Environment(Wegweiser.self) private var wegweiser

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
            if art == .bericht {
                Kicker(wort: daten.wort)
            } else {
                Text(daten.wort)
                    .font(Schrift.sans(13))
                    .foregroundStyle(Farbe.text3)
            }
            zahl
            hinweis
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var abstand: CGFloat {
        art == .bericht ? (fuehrend ? 8 : 5) : 5
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
        switch art {
        case .start: return fuehrend ? Schrift.zahlFuehrend : Schrift.mono(25, relativeTo: .title2)
        case .bericht: return fuehrend ? Schrift.mono(48, relativeTo: .largeTitle) : Schrift.mono(25, relativeTo: .title2)
        }
    }

    private var einheitSchrift: Font {
        switch art {
        case .start: return fuehrend ? Schrift.klein : Schrift.sans(13.5)
        case .bericht: return fuehrend ? Schrift.sans(18) : Schrift.sans(13.5)
        }
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
/// Rahmen". Sechs Kacheln mit je einem Rahmen sind sechs gleich schwere Kaesten; eine Flaeche
/// mit Haarlinien ist eine Tabelle. Am iPad gilt dasselbe, nur dass die Flaeche dort einen Rand
/// bekommt.
struct Kachelfeld: View {
    let kacheln: [Kacheldaten]
    var kicker: String?
    /// Die erste Kachel ueber die ganze Breite - `handy.css`, Entscheidung 2: „Eine Zahl fuehrt."
    var ersteFuehrt: Bool = true
    var spalten: Int = 2
    /// Die Gestalt der Kacheln. Auf einer Berichtsseite fuehrt das Wort, auf der Startseite die
    /// Zahl - siehe ``Kachel/Art``.
    var art: Kachel.Art = .bericht

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Karte(kicker: kicker) {
            if schmal, ersteFuehrt, let erste = kacheln.first {
                VStack(spacing: 0) {
                    Kachel(daten: erste, fuehrend: true, art: art)
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

    private func gitter(_ welche: [Kacheldaten]) -> some View {
        let reihen = zeilen(welche)
        return VStack(spacing: 0) {
            ForEach(Array(reihen.enumerated()), id: \.offset) { stelle, reihe in
                if stelle > 0 {
                    Divider().overlay(Farbe.linie1).padding(.vertical, 10)
                }
                HStack(alignment: .top, spacing: 12) {
                    ForEach(reihe) { daten in
                        Kachel(daten: daten, art: art)
                    }
                    // Die letzte Reihe auffuellen, damit eine einzelne Kachel nicht die ganze
                    // Breite nimmt und neben ihren Nachbarinnen falsch aussieht.
                    if reihe.count < spalten, reihe.count > 1 || welche.count % spalten == 0 {
                        ForEach(0..<(spalten - reihe.count), id: \.self) { _ in
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
    /// laengsten Satz darunter („53,8 kWh · Rechnungen pruefen").
    private func zeilen(_ welche: [Kacheldaten]) -> [[Kacheldaten]] {
        welche.chunked(spalten)
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
/// **Nicht „Fehler" und nicht nichts.** Eine leere Karte ohne Wort laesst offen, ob gerade
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
struct Stoerung: View {
    let fehler: ApiFehler
    var erneut: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Zeichen(.warnung, groesse: 16, farbe: Farbe.achtung)
            VStack(alignment: .leading, spacing: 3) {
                Text(fehler.rat).font(Schrift.klein).foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                if fehler.code != "network" {
                    Text(fehler.code).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
            Spacer(minLength: 8)
            if let erneut {
                Button("Erneut", action: erneut)
                    .font(Schrift.klein)
                    .buttonStyle(.plain)
                    .foregroundStyle(Farbe.amber)
            }
        }
        .padding(12)
        .background(Farbe.flaeche2)
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }
}
