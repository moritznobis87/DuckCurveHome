import DuckCurveKit
import SwiftUI

/// Das Dock: Schalter am unteren Rand, die leuchten, wenn sie an sind.
///
/// **Kaffee und Lichter schalten beim Tippen.** Sie haben nur an und aus. **Waermepumpe und Ofen
/// oeffnen ein Blatt**, weil sie mehr koennen: Auto, An fuer eine Frist, Aus fuer eine Frist,
/// und einen Satz, warum der Optimierer gerade so entschieden hat.
///
/// **Unter jedem Knopf steht ein Wort.** Drei Gluehbirnen nebeneinander sind nicht zu
/// unterscheiden (Rueckmeldung vom 22.10.2026, an der Wand); „Terrasse", „Hof", „Zaun" loesen das.
///
/// **Gaeste sehen alles und schalten nichts.** Der Knopf bleibt bedienbar und sagt, warum nichts
/// passiert; ein toter Knopf ohne Erklaerung ist aergerlicher als ein kurzer Satz.
struct Dock: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Was zuletzt geschaltet wurde - steht als Satz ueber dem Dock.
    @State private var rueckmeldung: String?
    /// Ob die Meldung ein Fehler ist: sie bleibt dann doppelt so lange stehen.
    @State private var meldungIstFehler = false
    @State private var laeuft: Set<String> = []
    @State private var fehlgeschlagen: Set<String> = []

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    /// Die Schalter, die nur an und aus kennen.
    private static let schalter: [(schluessel: String, name: String, kurz: String, zeichen: Zeichenart, dauerMin: Int?)] = [
        ("coffee_machine", "Kaffeemaschine", "Kaffee", .kaffee, 120),
        ("terrace_light", "Licht Terrasse", "Terrasse", .lampe, nil),
        ("courtyard_light", "Licht Innenhof", "Hof", .lampe, nil),
        ("garden_fence_light", "Licht Gartenzaun", "Zaun", .lampe, nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let rueckmeldung {
                // **Rechts und bernsteinfarben** (`globals.css:256,264`: `align-items:
                // flex-end`, `right: 0`, 13 Punkte, `--amber-soft`). Sie gehoert ueber den
                // Knopf, den jemand gerade gedrueckt hat, und die Knoepfe stehen an der Wand
                // rechts. Am Telefon fuellt das Dock seine Karte, dort steht sie links.
                Text(rueckmeldung)
                    .font(Schrift.sans(13))
                    .foregroundStyle(Farbe.amberWeich)
                    .frame(maxWidth: .infinity, alignment: schmal ? .leading : .trailing)
                    .transition(.opacity)
            }
            // **Umbruch und kein `HStack`.** Sechs Knoepfe zu 54 Punkten mit 14 Punkten
            // Abstand brauchen 394 Punkte; in einer Karte auf einem 390er Telefon stehen 326
            // zur Verfuegung. Eine `ScrollView` zentriert zu breiten Inhalt, und damit rutschte
            // die **ganze Seite** um 18 Punkte nach links - der Satz oben, die Karten, alles.
            // Auf den Screenshots vom 17.11. sah es aus, als haette die Seite keinen Rand.
            // **Erst die Schalter, dann die Anlagen** (`Dock.tsx:231-249`), getrennt durch
            // einen Strich: links, was nur an und aus kennt, rechts, was mehr kann. Die App
            // hatte die Reihenfolge umgekehrt - und damit stand die Waermepumpe, die ein Blatt
            // oeffnet, zwischen vier Knoepfen, die schalten.
            Umbruchzeile(abstand: schmal ? 14 : 10, zeilenabstand: 10) {
                ForEach(Self.schalter, id: \.schluessel) { s in
                    schaltknopf(s)
                }
                if !schmal {
                    Rectangle()
                        .fill(Farbe.linie2)
                        .frame(width: 1, height: 36)
                        .padding(.horizontal, 4)
                        .padding(.top, 12)
                }
                waermepumpenknopf
                ofenknopf
                alarmknopf
            }
        }
        .animation(.easeInOut(duration: Marken.dauer), value: rueckmeldung)
        // **Die Meldung verschwindet von selbst** (`Dock.tsx:185-189,210`). Sie tat es nicht:
        // an einer Wandanzeige stand „Kaffeemaschine an“ bis zum naechsten Tippen, also
        // stundenlang. `task(id:)` bricht den Lauf ab, sobald eine neue Meldung kommt - das
        // ist dasselbe wie das `clearTimeout` der Vorlage.
        .task(id: rueckmeldung) { await loescheMeldung() }
    }

    private func loescheMeldung() async {
        guard rueckmeldung != nil else { return }
        let frist = Dockzustand.frist(fehler: meldungIstFehler)
        try? await Task.sleep(nanoseconds: UInt64(frist * 1_000_000_000))
        guard !Task.isCancelled else { return }
        rueckmeldung = nil
    }

    /// Sagen, was geschaltet wurde - und fuer wie lange es dasteht.
    private func sag(_ satz: String, fehler: Bool = false) {
        meldungIstFehler = fehler
        rueckmeldung = satz
    }

    // MARK: - Die Knöpfe

    private var waermepumpenknopf: some View {
        Knopf(
            name: "Wärmepumpe",
            kurz: "Pumpe",
            zeichen: .waermepumpe,
            an: haus.zustand?.heatPump.running,
            farbe: Farbe.waermepumpe,
            laeuft: false,
            fehler: false,
            offen: wegweiser.blatt == .waermepumpe
        ) {
            wegweiser.blatt = .waermepumpe
        }
    }

    private var ofenknopf: some View {
        // **Den Ofen gibt es nicht in jedem Haus** (`Dock.tsx:240`: `stove?.present`). Die App
        // prüfte nur, ob der Dienst den Abschnitt liefert - er liefert ihn immer.
        Group {
            if Dockzustand.zeigtOfen(haus.zustand?.stove) {
                Knopf(
                    name: "Pelletofen",
                    kurz: "Ofen",
                    zeichen: .ofen,
                    an: haus.zustand?.stove?.running ?? false,
                    farbe: Farbe.ofen,
                    laeuft: false,
                    fehler: false,
                    offen: wegweiser.blatt == .ofen
                ) {
                    wegweiser.blatt = .ofen
                }
            }
        }
    }

    /// **Die Alarmanlage, nur wo es eine gibt** (`Dock.tsx:242-252`).
    ///
    /// Sie fehlte im Dock ganz: scharf stellen ging in der App nur auf der Hausseite, und
    /// nicht dort, wo man abends im Vorbeigehen daran kommt. Sie leuchtet, wenn sie scharf
    /// ist - rot nur, wenn sie ausgeloest hat (``Dockzustand/alarmfarbe(_:)``).
    private var alarmknopf: some View {
        Group {
            if Dockzustand.zeigtAlarm(haus.zustand?.alarm) {
                Knopf(
                    name: "Alarmanlage · \(haus.zustand?.alarm?.stateDe ?? "")",
                    kurz: "Alarm",
                    zeichen: .schild,
                    an: Dockzustand.alarmLeuchtet(haus.zustand?.alarm),
                    farbe: Color(Dockzustand.alarmfarbe(haus.zustand?.alarm)),
                    laeuft: false,
                    fehler: false,
                    offen: wegweiser.blatt == .alarm
                ) {
                    wegweiser.blatt = .alarm
                }
            }
        }
    }

    private func schaltknopf(
        _ s: (schluessel: String, name: String, kurz: String, zeichen: Zeichenart, dauerMin: Int?)
    ) -> some View {
        let m = haus.augenblick?.actuators[s.schluessel]
        let an = m?.belastbar.map { $0 > 0.5 }
        return Knopf(
            name: s.name,
            kurz: s.kurz,
            zeichen: s.zeichen,
            an: an,
            // **`--amber` und nicht `--amber-soft`** (`Dock.tsx:236`, `tokens.css:13`). Das
            // weiche Gelb ist der Warnton der Oberflaeche - es traegt die Wache und die
            // Dockmeldung; ein leuchtender Lichtschalter ist keine Warnung.
            farbe: Farbe.amber,
            laeuft: laeuft.contains(s.schluessel),
            fehler: fehlgeschlagen.contains(s.schluessel)
        ) {
            schalte(s.schluessel, name: s.name, auf: !(an ?? false), dauerMin: s.dauerMin)
        }
    }

    // MARK: - Schalten

    private func schalte(_ schluessel: String, name: String, auf an: Bool, dauerMin: Int?) {
        guard haus.darfSchalten else {
            sag(Dockzustand.gastzugang)
            return
        }
        laeuft.insert(schluessel)
        fehlgeschlagen.remove(schluessel)
        Task {
            do {
                let antwort = try await haus.api.schalte(
                    schluessel, an: an, dauerMin: an ? dauerMin : nil
                )
                sag(antwort.messageDe)
            } catch let f as ApiFehler {
                fehlgeschlagen.insert(schluessel)
                sag("\(name): \(f.rat)", fehler: true)
            } catch {
                fehlgeschlagen.insert(schluessel)
                sag("\(name): \(error.localizedDescription)", fehler: true)
            }
            laeuft.remove(schluessel)
        }
    }
}

/// Ein Knopf des Docks.
struct Knopf: View {
    let name: String
    let kurz: String
    let zeichen: Zeichenart
    /// `nil` heisst: der Dienst weiss es nicht.
    let an: Bool?
    let farbe: Color
    var laeuft: Bool = false
    var fehler: Bool = false
    /// Ob das Blatt dieses Knopfes offen ist (`Dock.tsx:50-52`: `aria-expanded`).
    ///
    /// **Ein Tipp auf Waermepumpe, Ofen oder Alarm fuehrt in ein Blatt, und der Knopf soll das
    /// zeigen.** Er tat es nicht: nach dem Tippen sah er aus wie vorher, und auf dem iPad, wo
    /// das Blatt neben dem Dock steht, war nicht zu sehen, zu welchem der sieben Knoepfe es
    /// gehoert.
    var offen: Bool = false
    let tippen: () -> Void

    private var leuchtet: Bool { an == true }

    private var randfarbe: Color {
        if fehler { return Farbe.alarm }
        return leuchtet || offen ? farbe : Farbe.linie2
    }

    private var inhaltsfarbe: Color {
        if fehler { return Farbe.alarm }
        return leuchtet ? farbe : Farbe.text3
    }

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    /// Die Kante des Knopfes: 60 an der Wand, 48 am Telefon (`globals.css:261`,
    /// `handy.css:285-286`).
    private var kante: CGFloat { schmal ? 48 : 60 }

    /// Und sein Radius: 16 an der Wand, 14 am Telefon - kein Kreis.
    ///
    /// **Hier stand ein Kreis** (Radius 30, „am Telefon ein Kreis“, mit Berufung auf
    /// `globals.css:261`). Dort steht aber 60 Punkte mit Radius 16, und `handy.css:285-286`
    /// sagt 48 mit 14. In `handy.css` gibt es keine Zeile, die aus dem Knopf einen Kreis
    /// macht: sieben Kreise nebeneinander sind eine Perlenkette, sieben Felder eine Tastatur.
    private var radius: CGFloat { schmal ? 14 : 16 }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: tippen) {
                Zeichen(zeichen, groesse: 26, farbe: inhaltsfarbe)
                    .frame(width: kante, height: kante)
                    .background(flaeche)
                    // Das Leuchten ist die eigentliche Auskunft: an einer Wand sieht man es
                    // aus drei Metern, eine Beschriftung nicht.
                    .shadow(color: leuchtet ? farbe.opacity(0.35) : .clear, radius: 11)
                    .opacity(laeuft ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityValue(an == nil ? "unbekannt" : (leuchtet ? "an" : "aus"))
            .accessibilityAddTraits(.isButton)

            // An der Wand gesperrt und gross geschrieben (`globals.css:259`), am Telefon
            // gewoehnliche Schrift: dort liest man sie, hier streift man sie.
            Text(schmal ? kurz : kurz.uppercased())
                .font(schmal ? Schrift.winzig : Schrift.sans(10))
                .kerning(schmal ? 0 : 0.4)
                .foregroundStyle(leuchtet ? Farbe.text2 : Farbe.text3)
                .accessibilityHidden(true)
        }
        .frame(width: kante)
    }

    /// Grund, Toenung und Rand des Knopfes.
    ///
    /// **Zwei Kreise statt `color-mix`.** Die Vorlage toent den offenen Knopf mit
    /// `color-mix(in srgb, farbe 14%, transparent)` ueber dem deckenden Grund
    /// (`Dock.tsx:52`); SwiftUI kennt das nicht, also liegt die Toenung als eigene Flaeche
    /// darueber - derselbe Weg, den der Energiefluss fuer seine Ringe geht.
    private var flaeche: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Farbe.flaeche1.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(offen ? farbe.opacity(0.14) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(randfarbe, lineWidth: schmal ? 1.5 : 1)
            )
    }
}

/// Die Befunde der Wache: was dem Dienst an seinen eigenen Zahlen auffaellt.
///
/// Steht unter dem Satz und nicht in einer eigenen Karte: es sind Hinweise zum Satz oben, keine
/// Seite fuer sich. Wo nichts ist, steht nichts - eine leere „Alles in Ordnung"-Zeile an einer
/// Wandanzeige ist Laerm. `globals.css:202-203` sagt es so: „Keine Kachel, kein Fenster: eine
/// Zeile mit Kante, die man im Vorbeigehen sieht und die nichts verdeckt.“
///
/// **Hoechstens zwei, und das ist keine Darstellungsfrage.** Welche zwei von fuenf Befunden
/// dastehen, rechnet ``Wachbefunde`` - mitsamt dem Ton. Hier stand `ForEach(befunde)` ohne
/// Grenze, und an der Wand, wo nichts rollt, schob eine Wache mit fuenf Zeilen Kurve und Fuss
/// aus dem Bild. Was dort abgeschnitten wird, ist weg.
struct Wache: View {
    let befunde: [WatchFindingOut]

    private var zeilen: [Wachbefunde.Zeile] { Wachbefunde.zeilen(befunde) }

    var body: some View {
        if !zeilen.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(zeilen) { z in
                    zeile(z)
                }
            }
        }
    }

    /// Eine getoente Zeile mit Kante links (`globals.css:205-207`).
    ///
    /// **Ein Warnzeichen und kein Punkt, und 14 Punkte Schrift und nicht 11,5.** Die App hatte
    /// hier einen Punkt von fuenf Punkten und den Satz in der kleinsten Schrift der
    /// Oberflaeche - also in der Groesse, in der sonst Fussnoten stehen. Ein Befund der Wache
    /// ist das Gegenteil einer Fussnote: es ist der Satz, der sagt, dass die Zahlen darunter
    /// nicht stimmen.
    private func zeile(_ z: Wachbefunde.Zeile) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Zeichen(.warnung, groesse: 16, farbe: Color(z.schwere.farbe))
            Text(z.satz)
                .font(Schrift.sans(14))
                .lineSpacing(2)
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(z.schwere.grundfarbe))
        // Radius `0 4px 4px 0`: die Kante links bleibt scharf, damit sie als Kante liest und
        // nicht als Kachelrand.
        .clipShape(.rect(topLeadingRadius: 0, bottomLeadingRadius: 0,
                         bottomTrailingRadius: 4, topTrailingRadius: 4))
        .overlay(alignment: .leading) {
            // Die drei Punkte starke Kante in der Schwerefarbe (`globals.css:205`).
            Rectangle()
                .fill(Color(z.schwere.farbe))
                .frame(width: 3)
        }
    }
}
