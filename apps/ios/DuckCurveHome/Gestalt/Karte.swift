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
        schmal ? 20 : Marken.radius3
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

    var id: String { wort }

    init(_ wort: String, _ wert: String, einheit: String? = nil, dazu: String? = nil, farbe: Color = Farbe.text1) {
        self.wort = wort
        self.wert = wert
        self.einheit = einheit
        self.dazu = dazu
        self.farbe = farbe
    }
}

/// Eine Kachel: eine Zahl, ein Wort, und beim Tippen mehr.
///
/// Das ist der haeufigste Baustein der Anwendung. Die Zahl fuehrt, das Wort erklaert, und wo ein
/// Wert alt oder abgeleitet ist, steht das klein dabei - nicht als Warnzeichen, sondern als
/// Auskunft.
struct Kachel: View {
    let daten: Kacheldaten
    /// Gross: die fuehrende Zahl einer Seite.
    var fuehrend: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Zahl(
                wert: daten.wert,
                einheit: daten.einheit,
                schrift: fuehrend ? Schrift.zahlFuehrend : Schrift.zahlGross,
                einheitSchrift: fuehrend ? Schrift.klein : Schrift.winzig,
                farbe: daten.farbe
            )
            Text(daten.wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
            if let dazu = daten.dazu {
                Text(dazu)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Karte(kicker: kicker) {
            if schmal, ersteFuehrt, let erste = kacheln.first {
                VStack(spacing: 0) {
                    Kachel(daten: erste, fuehrend: true)
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
        let reihen = welche.chunked(spalten)
        return VStack(spacing: 0) {
            ForEach(Array(reihen.enumerated()), id: \.offset) { stelle, reihe in
                if stelle > 0 {
                    Divider().overlay(Farbe.linie1).padding(.vertical, 10)
                }
                HStack(alignment: .top, spacing: 12) {
                    ForEach(reihe) { daten in
                        Kachel(daten: daten)
                    }
                    // Die letzte Reihe auffuellen, damit eine einzelne Kachel nicht die ganze
                    // Breite nimmt und neben ihren Nachbarinnen falsch aussieht.
                    if reihe.count < spalten {
                        ForEach(0..<(spalten - reihe.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
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
