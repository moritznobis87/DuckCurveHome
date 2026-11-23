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

    /// Welchen der drei Tage die Startseite zeigt.
    ///
    /// **Warum das hier steht und nicht in der Seite.** Es stand dort (`@State private var tag`),
    /// und damit kam die Heimkehr nicht an: ``heimkehr(jetzt:)`` setzt die Zeitraeume der
    /// Berichtsseiten zurueck, und ein `@State` einer Seite ist von aussen nicht erreichbar. Wer
    /// an der Wandanzeige im Vorbeigehen auf „Gestern“ tippte, hinterliess eine Anzeige, die
    /// gestrige Kurve und gestrige Kacheln so zeigte, wie sonst die heutigen stehen - tagelang.
    /// Genau davor warnt `DayCurve.tsx:32-34`: „die Wandanzeige soll nicht an einem Tag von
    /// vorgestern haengen bleiben, wie es der alten passiert ist.“
    var kurventag: Kurventag = .heute

    var bereich: Bereich { Bereiche.bereichVon(weg) }
    var reiter: Reiter? { Bereiche.reiterVon(bereich, weg) }
    var ansicht: Ansicht? { Bereiche.ansichtVon(reiter, weg) }

    init(weg: String = "/") {
        self.weg = weg
    }

    /// **Eine alte Adresse wird hier zur neuen.** Die Vorlage leitet sie mit `permanent: true`
    /// weiter (`apps/web/next.config.ts:31`), und das heisst: danach steht die neue Adresse da,
    /// nicht die alte. Sonst zeigte die Leiste auf „Jetzt“, waehrend die Seite der Waerme
    /// gezeichnet ist - `bereichVon("/waermebilanz")` findet niemanden. Welcher Weg wohin
    /// aufloest, rechnet der Kern (``Bereiche/weiterleitung(_:)``).
    func gehe(_ nachWeg: String) {
        weg = Bereiche.weiterleitung(nachWeg) ?? nachWeg
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

    /// Der Zeitraum des Bereichs, beschnitten auf das, was die Seite anbietet.
    ///
    /// **Zwei Dinge, die hier zusammengehoeren.**
    ///
    /// Erstens **schreibt dieser Zugriff nichts.** Er wird aus vier Bodys gelesen - der Seite,
    /// dem Datumskasten, der Spannenwahl und der Heizkreisseite -, und ein Getter, der dabei
    /// beobachteten Zustand anlegt, ist „Modifying state during view update": alle lesenden
    /// Ansichten werden im selben Durchlauf wieder ungueltig. Die Vorgabe ist deshalb eine
    /// Rechnung und kein Eintrag; eingetragen wird erst, wenn jemand stellt.
    ///
    /// Zweitens **gilt sie nur, soweit die Seite sie anbietet.** Der Zeitraum haengt am
    /// Bereich, die Spannen haengen am Reiter: wer unter Geld die „Kosten" auf Woche stellt
    /// und dann zur „PV-Abrechnung" wechselt, die nur Monat und Jahr kennt, haette sonst eine
    /// Woche im Kopf, keinen Schalter dafuer (also keinen Weg zurueck) und eine Seite, die
    /// trotzdem einen Monat laedt.
    /// Kennt die Seite die Spanne nicht, faellt sie auf die erste, die die Seite kennt.
    func zeitraum(jetzt: Date) -> Zeitraum {
        // Die Vorgabe haengt am Bereich: Energie fangen beim Tag an, Geld beim Monat.
        let vorgabe: Spanne = bereich.schluessel == .geld ? .monat : .tag
        let z = zeitraeume[bereich.schluessel] ?? Zeitraum.heute(vorgabe, jetzt: jetzt)
        guard let moeglich = Bereiche.spannen(fuer: weg), !moeglich.contains(z.spanne) else {
            return z
        }
        return z.mit(moeglich.first ?? .tag)
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
        // **Und der Tagesschalter der Startseite** (`Home.tsx:162-167`: `HEIMKEHR_MS`). Die
        // Abfrage ist nicht nur Sparsamkeit: `heimkehr` wird an der Wand in jedem Takt gerufen,
        // solange niemand die Anzeige beruehrt, und eine Zuweisung auf eine beobachtete
        // Eigenschaft meldet eine Aenderung auch dann, wenn sich nichts aendert - jede Sekunde
        // ein neuer Durchlauf der ganzen Startseite.
        if kurventag != .heute { kurventag = .heute }
    }
}

/// Ein Blatt ueber der Seite: was beim Tippen auf eine Zahl aufgeht.
enum Blatt: Identifiable, Hashable {
    case waermepumpe
    /// Die Auswahl, die ein Tipp auf die Waermepumpe im Flussbild oeffnet.
    case waermepumpenmenue
    case ofen
    /// Die Alarmanlage scharf stellen - vom Dock der Wandanzeige aus (`Dock.tsx:281-283`).
    case alarm
    case batterie
    case raum(Int)
    /// Das Protokoll eines Raums – zwei Tage Kurve und jede Sollwertänderung.
    case raumprotokoll(Int)
    case zugang
    case entscheidungen

    var id: String {
        switch self {
        case .waermepumpe: return "wp"
        case .waermepumpenmenue: return "wp-menue"
        case .ofen: return "ofen"
        case .alarm: return "alarm"
        case .batterie: return "bat"
        case .raum(let i): return "raum-\(i)"
        case .raumprotokoll(let i): return "raumlog-\(i)"
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

    /// Ob der Ladeschirm steht. Wann er kommt und wann er geht, rechnet ``Ladeschirm/Lauf``.
    @State private var ladebild = false

    var body: some View {
        ZStack {
            Group {
                if !haus.zugang.istEingerichtet {
                    Einrichten()
                } else if breite == .compact {
                    HandRahmen(wegweiser: wegweiser)
                } else {
                    WandRahmen(wegweiser: wegweiser)
                }
            }
            // **Der Ladeschirm liegt darüber und ersetzt das Gerippe nicht.** Ein `else`-Zweig
            // wäre die naheliegende Schreibweise und die falsche: SwiftUI baut den Rahmen dann
            // erst, wenn der Schirm geht, also genau in dem Augenblick, in dem die erste Zahl
            // da ist - die Seite entsteht unter der Überblendung und man sieht sie entstehen.
            // Darüberliegend läuft darunter alles weiter, `.task` und Verbindung eingeschlossen,
            // und am Ende wird nur ein Vorhang weggeblendet.
            if ladebild {
                Ladebild(wand: breite != .compact)
                    .transition(.opacity)
            }
        }
        // Dieselbe Überblendung, mit der an der Wand das Ruhebild kommt und geht - nur kürzer:
        // dort löst sich ein Bild ab, hier wartet jemand.
        .animation(.easeInOut(duration: 0.4), value: ladebild)
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
        // **Am Zugang aufgehängt und nicht nur beim Erscheinen.** Wer die App zum ersten Mal
        // öffnet, steht im Einrichten; erst wenn dort ein Zugang eingetragen ist, gibt es
        // überhaupt etwas zu verbinden - und dann soll das Warten darauf angezeigt werden.
        // `haus.starte()` verträgt den zweiten Aufruf, es hält sich selbst auf.
        .task(id: haus.zugang.istEingerichtet) {
            haus.starte()
            await fuehreLadeschirm()
        }
        // Die Blaetter gehoeren in beide Gerippe, also hierher und nicht in eines von beiden.
        // `Blatt` ist `Identifiable`, also nimmt SwiftUIs eigenes `sheet(item:)` es direkt.
        .sheet(item: Binding(get: { wegweiser.blatt }, set: { wegweiser.blatt = $0 })) { blatt in
            switch blatt {
            case .waermepumpe: Waermepumpenblatt()
            case .waermepumpenmenue: Wpmenue()
            case .ofen: Ofenblatt()
            case .alarm: Alarmblatt()
            case .batterie: Batterieblatt()
            case .entscheidungen: Entscheidungsblatt()
            case .zugang: Einrichten()
            case .raum, .raumprotokoll:
                // Beide Raumblaetter brauchen den Raum und kommen darum aus der Hausseite selbst.
                EmptyView()
            }
        }
        // **Der Wegweiser steht ganz aussen, hinter den Blaettern.**
        //
        // Ein Blatt erbt die Umgebung der Stelle, an der `sheet` haengt - nicht die, die
        // weiter innen eingesetzt wird. Stand `.environment(wegweiser)` vor `.sheet`, dann lag
        // die Einsetzung INNERHALB der Ansicht, an der das Blatt haengt, und das Blatt sah den
        // Wegweiser nicht. `@Environment(Wegweiser.self)` ist nicht wahlfrei: wer ihn dort
        // liest, bekommt keinen Nullwert, sondern einen Abbruch - „No Observable object of
        // type Wegweiser found".
        //
        // Aufgefallen ist es an `Wpmenue`, dem ersten Blatt, das einen Weg kennt: ein Tipp auf
        // die Waermepumpe im Flussbild hat die App beendet. Die anderen Blaetter brauchen nur
        // den Hauszustand, und der wird eine Ebene hoeher eingesetzt - darum lief es so lange.
        .environment(wegweiser)
    }

    /// Den Ladeschirm führen, bis das Warten vorbei ist.
    ///
    /// **Warum eine eigene Schleife und kein Wecker am Rahmen.** Die drei Fristen des
    /// Ladeschirms sind Zehntelsekunden (``Ladeschirm/ruhefrist``, ``Ladeschirm/mindestens``,
    /// ``Ladeschirm/aufgabeNach``); der langsamste Takt, der sie trifft, ist ein Zwanzigstel.
    /// Ein `Timer` in der Wurzel, der so schnell schlägt, schlüge für immer - auch nachts an
    /// einer Wand, die seit Wochen fertig geladen ist. Diese Schleife läuft nur, solange
    /// gewartet wird, und endet mit ``Ladeschirm/Lage/vorbei`` von selbst. Ist beim ersten Takt
    /// schon ein Augenblicksbild da - in jeder Vorschau und bei jedem Zurückkommen -, endet sie
    /// nach dem ersten Durchgang.
    ///
    /// Verlassen wird sie auch, wenn die Aufgabe abgebrochen wird: `.task` räumt sie auf, wenn
    /// die Wurzel verschwindet oder der Zugang wechselt.
    private func fuehreLadeschirm() async {
        guard haus.zugang.istEingerichtet else { return }
        var lauf = Ladeschirm.Lauf(start: Date())
        while !Task.isCancelled {
            switch lauf.takt(
                jetzt: Date(),
                hatZahlen: !haus.nochKeineZahlen,
                fehlerSteht: haus.fehler != nil
            ) {
            case .verborgen:
                break
            case .steht:
                if !ladebild { ladebild = true }
            case .vorbei:
                if ladebild { ladebild = false }
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
