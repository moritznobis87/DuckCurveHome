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
    @State private var laeuft: Set<String> = []
    @State private var fehlgeschlagen: Set<String> = []

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
                Text(rueckmeldung)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .transition(.opacity)
            }
            // **Umbruch und kein `HStack`.** Sechs Knoepfe zu 54 Punkten mit 14 Punkten
            // Abstand brauchen 394 Punkte; in einer Karte auf einem 390er Telefon stehen 326
            // zur Verfuegung. Eine `ScrollView` zentriert zu breiten Inhalt, und damit rutschte
            // die **ganze Seite** um 18 Punkte nach links - der Satz oben, die Karten, alles.
            // Auf den Screenshots vom 17.11. sah es aus, als haette die Seite keinen Rand.
            Umbruchzeile(abstand: 14, zeilenabstand: 10) {
                waermepumpenknopf
                ofenknopf
                ForEach(Self.schalter, id: \.schluessel) { s in
                    schaltknopf(s)
                }
            }
        }
        .animation(.easeInOut(duration: Marken.dauer), value: rueckmeldung)
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
            fehler: false
        ) {
            wegweiser.blatt = .waermepumpe
        }
    }

    private var ofenknopf: some View {
        // Den Ofen gibt es nicht in jedem Haus - er steht nur da, wenn der Dienst ihn kennt.
        Group {
            if let ofen = haus.zustand?.stove {
                Knopf(
                    name: "Pelletofen",
                    kurz: "Ofen",
                    zeichen: .ofen,
                    an: ofen.running ?? false,
                    farbe: Farbe.ofen,
                    laeuft: false,
                    fehler: false
                ) {
                    wegweiser.blatt = .ofen
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
            farbe: Farbe.amberWeich,
            laeuft: laeuft.contains(s.schluessel),
            fehler: fehlgeschlagen.contains(s.schluessel)
        ) {
            schalte(s.schluessel, name: s.name, auf: !(an ?? false), dauerMin: s.dauerMin)
        }
    }

    // MARK: - Schalten

    private func schalte(_ schluessel: String, name: String, auf an: Bool, dauerMin: Int?) {
        guard haus.darfSchalten else {
            rueckmeldung = "Gastzugang: nur Ansicht."
            return
        }
        laeuft.insert(schluessel)
        fehlgeschlagen.remove(schluessel)
        Task {
            do {
                let antwort = try await haus.api.schalte(
                    schluessel, an: an, dauerMin: an ? dauerMin : nil
                )
                rueckmeldung = antwort.messageDe
            } catch let f as ApiFehler {
                fehlgeschlagen.insert(schluessel)
                rueckmeldung = "\(name): \(f.rat)"
            } catch {
                fehlgeschlagen.insert(schluessel)
                rueckmeldung = "\(name): \(error.localizedDescription)"
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
    let tippen: () -> Void

    private var leuchtet: Bool { an == true }

    private var randfarbe: Color {
        if fehler { return Farbe.alarm }
        return leuchtet ? farbe : Farbe.linie2
    }

    private var inhaltsfarbe: Color {
        if fehler { return Farbe.alarm }
        return leuchtet ? farbe : Farbe.text3
    }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: tippen) {
                Zeichen(zeichen, groesse: 26, farbe: inhaltsfarbe)
                    .frame(width: 54, height: 54)
                    .background(
                        Circle().strokeBorder(randfarbe, lineWidth: 1.5)
                    )
                    // Das Leuchten ist die eigentliche Auskunft: an einer Wand sieht man es
                    // aus drei Metern, eine Beschriftung nicht.
                    .shadow(color: leuchtet ? farbe.opacity(0.35) : .clear, radius: 11)
                    .opacity(laeuft ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityValue(an == nil ? "unbekannt" : (leuchtet ? "an" : "aus"))
            .accessibilityAddTraits(.isButton)

            Text(kurz)
                .font(Schrift.winzig)
                .foregroundStyle(leuchtet ? Farbe.text2 : Farbe.text3)
                .accessibilityHidden(true)
        }
    }
}

/// Die Befunde der Wache: was dem Dienst an seinen eigenen Zahlen auffaellt.
///
/// Steht unter dem Satz und nicht in einer eigenen Karte: es sind Hinweise zum Satz oben, keine
/// Seite fuer sich. Wo nichts ist, steht nichts - eine leere „Alles in Ordnung"-Zeile an einer
/// Wandanzeige ist Laerm.
struct Wache: View {
    let befunde: [WatchFindingOut]

    var body: some View {
        if !befunde.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(befunde.enumerated()), id: \.offset) { _, b in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(farbe(b))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(b.textDe)
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func farbe(_ b: WatchFindingOut) -> Color {
        switch b.severity {
        case .alarm: return Farbe.alarm
        case .warn: return Farbe.achtung
        case .unbekannt: return Farbe.mist
        }
    }
}
