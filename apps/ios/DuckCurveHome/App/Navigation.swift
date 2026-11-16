import DuckCurveKit
import Observation
import SwiftUI

/// Wo die App gerade steht.
///
/// **Warum Wege und nicht Ansichten.** Eine App braucht keine Adressen. Diese fuehrt sie
/// trotzdem, aus drei Gruenden, die in `Bereiche.swift` stehen: Mitteilungen tragen ein Ziel in
/// genau dieser Schreibweise, die Lesezeichen am iPad sollen weiter gelten, und solange das
/// Dashboard daneben laeuft, soll „wo bin ich" in beiden dasselbe heissen.
///
/// **Jeder Bereich merkt sich seinen Zeitraum.** Das ist der Punkt, um den `areas.ts` umgebaut
/// wurde: wer die Woche in der Photovoltaik ansieht und dann zum Speicher geht, soll dort die
/// Woche finden und nicht wieder heute.
@MainActor
@Observable
final class Wegweiser {
    /// Der Weg, auf dem die App steht.
    var weg: String = "/"

    /// Der Zeitraum je Bereich.
    private var zeitraeume: [Bereich.Schluessel: Zeitraum] = [:]

    /// Wohin ein Tippen auf eine Zahl fuehrt - der Stapel ueber der Seite.
    var blatt: Blatt?

    var bereich: Bereich { Bereiche.bereichVon(weg) }
    var reiter: Reiter? { Bereiche.reiterVon(bereich, weg) }
    var ansicht: Ansicht? { Bereiche.ansichtVon(reiter, weg) }

    init(weg: String = "/") {
        self.weg = weg
    }

    func gehe(_ nachWeg: String) {
        weg = nachWeg
    }

    /// Den Bereich wechseln. Fuehrt auf den Reiter, auf dem man dort zuletzt war - nicht immer
    /// auf den ersten: wer die Wallbox ansieht, zur Technik geht und zurueckkommt, will die
    /// Wallbox wiedersehen.
    private var letzterReiter: [Bereich.Schluessel: String] = [:]

    func geheZuBereich(_ b: Bereich) {
        weg = letzterReiter[b.schluessel] ?? b.weg
    }

    func merkeReiter() {
        letzterReiter[bereich.schluessel] = weg
    }

    // MARK: - Zeitraum

    func zeitraum(jetzt: Date) -> Zeitraum {
        if let z = zeitraeume[bereich.schluessel] { return z }
        // Die Vorgabe haengt am Bereich: Energie und Geld fangen beim Tag an, die Jahreskarte
        // beim Jahr.
        let vorgabe: Spanne = bereich.schluessel == .geld ? .monat : .tag
        let neu = Zeitraum.heute(vorgabe, jetzt: jetzt)
        zeitraeume[bereich.schluessel] = neu
        return neu
    }

    func setzeZeitraum(_ z: Zeitraum) {
        zeitraeume[bereich.schluessel] = z
    }

    /// Nach zwei Minuten ohne Beruehrung steht wieder heute da.
    ///
    /// `Home.tsx` nennt den Grund: „Wer vorbeigeht, soll nicht das Gestern eines anderen sehen."
    /// Gilt nur an der Wand, nicht am Telefon - das gehoert einem.
    func heimkehr(jetzt: Date) {
        for (schluessel, z) in zeitraeume where !z.istAktuell(jetzt: jetzt) {
            zeitraeume[schluessel] = Zeitraum.heute(z.spanne, jetzt: jetzt)
        }
    }
}

/// Ein Blatt ueber der Seite: was beim Tippen auf eine Zahl aufgeht.
enum Blatt: Identifiable, Hashable {
    case waermepumpe
    case ofen
    case batterie
    case raum(Int)
    case zugang
    case entscheidungen

    var id: String {
        switch self {
        case .waermepumpe: return "wp"
        case .ofen: return "ofen"
        case .batterie: return "bat"
        case .raum(let i): return "raum-\(i)"
        case .zugang: return "zugang"
        case .entscheidungen: return "entscheidungen"
        }
    }
}

/// Die Wurzel der Anwendung: waehlt die Oberflaeche nach der Breite.
///
/// **Hier entstehen die „zwei Apps".** Es ist ein Programm, aber zwei Oberflaechen, und sie
/// teilen nur den Kern und die Bausteine - nicht das Gerippe:
///
/// | | Wand (iPad, breit) | Hand (iPhone, schmal) |
/// |---|---|---|
/// | Bereiche | oben als Zeichen, neben der Marke | unten als Leiste mit Namen |
/// | Reiter | eine Zeile unter dem Kopf | waagrecht rollend |
/// | Kopf | Uhr, Datum, Aussentemperatur, Verbindung | nur der Seitenname |
/// | Zahlen | alle gleich gross, nebeneinander | eine fuehrt, der Rest zweispaltig |
/// | Ruhe | nach fuenf Minuten ein Bild | nichts, das Telefon schaltet sich selbst ab |
///
/// Das ist nicht dieselbe Seite in zwei Breiten. `handy.css` beschreibt, warum: bis zum
/// 10.11.2026 *war* die Handy-Ansicht die Wandansicht in einer Spalte, und das Urteil darueber
/// lautete „viel zu schlecht, muss neu gedacht werden". Die Lehre steht hier im Gerippe und
/// nicht in Breitenabfragen, die ueber dreissig Dateien verstreut sind.
///
/// Entschieden wird nach `horizontalSizeClass` und nicht nach Geraeteklasse: ein iPhone im
/// Querformat und ein iPad in einem schmalen Fenster sollen dasselbe bekommen.
struct Wurzel: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite
    @Environment(\.scenePhase) private var lage

    @State private var wegweiser = Wegweiser()

    var body: some View {
        Group {
            if !haus.zugang.istEingerichtet {
                Einrichten()
            } else if breite == .compact {
                HandRahmen(wegweiser: wegweiser)
            } else {
                WandRahmen(wegweiser: wegweiser)
            }
        }
        .environment(wegweiser)
        .hausschrift()
        .seitengrund()
        .preferredColorScheme(.dark)
        .onChange(of: lage) { _, neu in
            // Ein Wecker, der im Hintergrund alle fuenf Sekunden feuert, kostet Batterie, ohne
            // etwas zu bewirken.
            switch neu {
            case .active: haus.beimZurueckkommen()
            case .background, .inactive: haus.beimWegbleiben()
            @unknown default: break
            }
        }
        .task {
            haus.starte()
        }
    }
}

/// Die Reiterzeile eines Bereichs.
///
/// Rollt waagrecht, weil die Technik elf Reiter hat und die auf kein Geraet in eine Zeile passen.
/// Der aktive Reiter wird beim Wechsel in den Blick gerollt - sonst steht man in der Technik auf
/// „Zugang und Sicherung" und sieht die Leiste bei „Anlage".
struct Reiterzeile: View {
    let bereich: Bereich
    let aktiv: Reiter?
    let darfAlles: Bool
    let waehle: (Reiter) -> Void

    var body: some View {
        ScrollViewReader { roller in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(sichtbare) { r in
                        knopf(r)
                            .id(r.weg)
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: aktiv?.weg) { _, neu in
                guard let neu else { return }
                withAnimation(.easeOut(duration: Marken.dauer)) {
                    roller.scrollTo(neu, anchor: .center)
                }
            }
        }
    }

    private var sichtbare: [Reiter] {
        darfAlles ? bereich.reiter : bereich.reiter.filter { !$0.nurHausherr }
    }

    private func knopf(_ r: Reiter) -> some View {
        let istAktiv = aktiv?.weg == r.weg
        return Button {
            waehle(r)
        } label: {
            VStack(spacing: 5) {
                Text(r.name)
                    .font(istAktiv ? Schrift.karte : Schrift.klein)
                    .foregroundStyle(istAktiv ? Farbe.text1 : Farbe.text3)
                    .lineLimit(1)
                // Der Strich unter dem aktiven Reiter, in Amber wie im Dashboard.
                Rectangle()
                    .fill(istAktiv ? Farbe.amber : .clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(istAktiv ? [.isSelected, .isButton] : .isButton)
    }
}

/// Der Umschalter zwischen den Ansichten eines Reiters: „Jetzt | Ein Tag".
///
/// Steht unter der Reiterzeile und nicht daneben - `areas.ts`: es ist dieselbe Sache aus zwei
/// Richtungen, kein weiterer Gegenstand.
struct Ansichtswahl: View {
    let ansichten: [Ansicht]
    let aktiv: Ansicht?
    let waehle: (Ansicht) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ansichten) { a in
                let istAktiv = aktiv?.weg == a.weg
                Button {
                    waehle(a)
                } label: {
                    Text(a.name)
                        .font(Schrift.klein)
                        .foregroundStyle(istAktiv ? Farbe.deep : Farbe.text2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(istAktiv ? Farbe.amberWeich : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(istAktiv ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2)
        .background(Farbe.flaeche2)
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }
}
