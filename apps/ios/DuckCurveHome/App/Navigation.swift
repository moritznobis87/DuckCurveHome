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
            switch neu {
            case .active:
                haus.beimZurueckkommen()
                // Eine angetippte Mitteilung fuehrt auf ihre Seite. Geprueft wird das Ziel in
                // `Mitteilungen`; hier wird nur gesprungen. Sie kann ankommen, bevor die
                // Oberflaeche da ist - darum wird hier abgeholt und nicht dort zugestellt.
                if let ziel = Zielsprung.abholen() { wegweiser.gehe(ziel) }
            case .background, .inactive:
                // Ein Wecker, der im Hintergrund alle fuenf Sekunden feuert, kostet Batterie,
                // ohne etwas zu bewirken.
                haus.beimWegbleiben()
            @unknown default:
                break
            }
        }
        .task {
            haus.starte()
        }
        // Die Blaetter gehoeren in beide Gerippe, also hierher und nicht in eines von beiden.
        // `Blatt` ist `Identifiable`, also nimmt SwiftUIs eigenes `sheet(item:)` es direkt.
        .sheet(item: Binding(get: { wegweiser.blatt }, set: { wegweiser.blatt = $0 })) { blatt in
            switch blatt {
            case .waermepumpe: Waermepumpenblatt()
            case .ofen: Ofenblatt()
            case .batterie: Batterieblatt()
            case .entscheidungen: Entscheidungsblatt()
            case .zugang: Einrichten()
            case .raum:
                // Das Raumblatt braucht den Raum und kommt darum aus der Hausseite selbst.
                EmptyView()
            }
        }
    }
}
