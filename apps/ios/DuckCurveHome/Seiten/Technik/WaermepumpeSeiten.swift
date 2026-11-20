import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Jetzt: alle Messwerte des Augenblicks, wie der eigene Bus sie meldet.
///
/// **Das ist die Seite, auf der nichts weggelassen wird.** Die Startseite zeigt eine Zahl, diese
/// zeigt achtzehn - Verdampfer, Sauggas, Heissgas, Flüssig, Verdichterfrequenz, Durchfluss,
/// Spreizung. Wer hierherkommt, sucht etwas Bestimmtes und soll es finden, ohne zu tippen.
struct WaermepumpeSeite: View {
    @Environment(Hauszustand.self) private var haus

    @Environment(\.horizontalSizeClass) private var breite

    @State private var wp: WaermepumpeOut?
    @State private var fehler: ApiFehler?

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let w = wp {
                // **Die Zeichnung zuerst.** Sie gibt den achtzehn Zahlen darunter einen Ort:
                // Heissgas ist die Leitung nach oben, Fluessig die zurueck, der Verdichter
                // sitzt im Aussengeraet. Wer eine Zahl sucht, findet sie hier schneller als
                // in einer Liste - und sieht nebenbei, ob ueberhaupt etwas fliesst.
                Karte {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Wpbild.satz(w))
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.text1)
                            .fixedSize(horizontal: false, vertical: true)
                        Waermepumpenbild(wp: w, lage: breite == .compact ? .hoch : .breit)
                    }
                }
                Kachelfeld(kacheln: kennzahlen(w), kicker: w.zustandDe)
                if let busStumm = w.busStummDe, !busStumm.isEmpty {
                    Karte { Leer(satz: "Der Bus schweigt.", dazu: busStumm) }
                }
                Karte(kicker: "Kältekreis") {
                    VStack(spacing: 0) {
                        Zeile(wort: "Verdampfer", wert: Formate.celsius(w.verdampferC.belastbar, stellen: 1))
                        Zeile(wort: "Sauggas", wert: Formate.celsius(w.sauggasC.belastbar, stellen: 1))
                        Zeile(wort: "Heißgas", wert: Formate.celsius(w.heissgasC.belastbar, stellen: 1))
                        Zeile(wort: "Flüssig", wert: Formate.celsius(w.fluessigC.belastbar, stellen: 1))
                        Zeile(
                            wort: "Verdichter", wert: Formate.zahl(w.verdichterHz.belastbar, stellen: 0),
                            einheit: "Hz"
                        )
                        // **Das `if let` und das `.belastbar` sagen zwei verschiedene Dinge.**
                        // Wahlfrei ist hier das *Feld*: nicht jede Pumpe meldet diese beiden
                        // Groessen ueberhaupt - dann faellt die Zeile weg. Wahlfrei ist auch die
                        // *Zahl* im Messwert: gemeldet, aber alt oder unglaubwuerdig - dann
                        // steht die Zeile da und zeigt einen Strich, wie die Zeilen darueber.
                        if let a = w.verdichterA {
                            Zeile(
                                wort: "Verdichterstrom",
                                wert: Formate.zahl(a.belastbar, stellen: 1), einheit: "A"
                            )
                        }
                        if let l = w.luefterDrehzahl {
                            Zeile(
                                wort: "Lüfter",
                                wert: Formate.zahl(l.belastbar, stellen: 0), einheit: "1/min"
                            )
                        }
                    }
                }
                Karte(kicker: "Wasserseite") {
                    VStack(spacing: 0) {
                        Zeile(wort: "Vorlauf", wert: Formate.celsius(w.vorlaufC.belastbar, stellen: 1))
                        Zeile(wort: "Rücklauf", wert: Formate.celsius(w.ruecklaufC.belastbar, stellen: 1))
                        Zeile(wort: "Sollvorlauf", wert: Formate.celsius(w.vorlaufSollC.belastbar, stellen: 1))
                        if let s = w.spreizungK {
                            Zeile(wort: "Spreizung", wert: Formate.zahl(s, stellen: 1), einheit: "K")
                        }
                        Zeile(
                            wort: "Durchfluss", wert: Formate.zahl(w.durchflussLMin.belastbar, stellen: 1),
                            einheit: "l/min"
                        )
                        Zeile(wort: "Speicherfühler", wert: Formate.celsius(w.speicherfuehlerC.belastbar, stellen: 1))
                        // Der Puffer meldet mehrere Fuehler - jeden mit seiner Nummer, damit
                        // die Schichtung zu sehen ist.
                        ForEach(Array(w.pufferC.enumerated()), id: \.offset) { i, m in
                            Zeile(
                                wort: "Puffer \(i + 1)",
                                wert: Formate.celsius(m.belastbar, stellen: 1),
                                dazu: m.hinweis(jetzt: haus.jetzt)
                            )
                        }
                        if let p = w.pumpeLaeuft {
                            Zeile(wort: "Pumpe", wert: p ? "läuft" : "aus")
                        }
                    }
                }
                Karte(kicker: "Regler und Kontakte") {
                    VStack(spacing: 0) {
                        if let h = w.heizanforderung {
                            Zeile(wort: "Heizanforderung", wert: h ? "ja" : "nein")
                        }
                        if let r = w.raumSollC?.belastbar {
                            Zeile(wort: "Raumsollwert", wert: Formate.celsius(r, stellen: 1))
                        }
                        if let v = w.ventilCode {
                            Zeile(wort: "Umschaltventil", wert: String(v))
                        }
                        if let h = w.heizstabCode {
                            Zeile(wort: "Heizstab", wert: String(h))
                        }
                        if let z = w.zusatzKw {
                            Zeile(
                                wort: "Zusatzheizung", wert: Formate.kw(z), einheit: "kW",
                                farbe: z > 0.05 ? Farbe.achtung : Farbe.text1
                            )
                        }
                        if let k = w.kreisDe {
                            Zeile(wort: "Kreis", wert: k, dazu: w.kreisCode.map(String.init))
                        }
                        if let e = w.einspeisung {
                            Zeile(wort: "Einspeisung", wert: e.rawValue)
                        }
                    }
                }
                Methode(w.hinweiseDe, titel: "Hinweise des Busses")
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task { await lade() }
        .task { await haltFrisch() }
    }

    private func kennzahlen(_ w: WaermepumpeOut) -> [Kacheldaten] {
        [
            Kacheldaten(
                // Der Zaehler fuehrt, der Bus hilft aus. **Beide Felder sind `Messwert` und
                // nicht wahlfrei** - wahlfrei ist erst die Zahl darin (`.belastbar` ist nil,
                // wenn die Guete sie nicht traegt). Hier stand `w.leistungZaehlerKw ?? …`,
                // was zweierlei verwechselt: den Messwert mit seiner Zahl, und „kein Wert"
                // mit „kein Messwert".
                "Leistung",
                Formate.kw(w.leistungZaehlerKw.belastbar ?? w.leistungBusKw.belastbar),
                einheit: "kW",
                dazu: w.leistungZaehlerKw.belastbar != nil ? "am Zähler" : "über den Bus",
                farbe: Farbe.waermepumpe
            ),
            Kacheldaten(
                "Wärmeleistung", Formate.zahl(w.waermeleistungKw, stellen: 2), einheit: "kW"
            ),
            Kacheldaten("Arbeitszahl", Formate.zahl(w.arbeitszahl, stellen: 2)),
            Kacheldaten("draußen", Formate.celsius(w.aussenC.belastbar, stellen: 1)),
            Kacheldaten("Vorlauf", Formate.celsius(w.vorlaufC.belastbar, stellen: 1)),
            Kacheldaten(
                "Verdichter", Formate.zahl(w.verdichterHz.belastbar, stellen: 0), einheit: "Hz",
                dazu: w.laeuft ? "läuft" : "aus"
            ),
        ]
    }

    private func lade() async {
        do {
            wp = try await haus.api.waermepumpe()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }

    private func haltFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            if let w = try? await haus.api.waermepumpe() { wp = w }
        }
    }
}

/// Die Wahl des Zeitraums in Tagen, fuer die Seiten, die keinen Kalender brauchen.
///
/// **Die Knopfform der Vorlage, an einer Stelle.** Die Vorlage hat dafuer genau eine Regel:
/// `.kl-knopf` (`globals.css:893-894`) - 13 Punkte, Polster 7/13, eine Haarlinie `linie1` als
/// Rahmen, und gewaehlt `amber` auf `petrol` in Gewicht 600. Die Reihe darum ist `.kl-wahl`
/// (`globals.css:892`) mit Abstand 6 und Umbruch; darum ``Umbruchzeile`` und nicht `HStack` -
/// vier Knoepfe in dieser Groesse passen am Telefon nicht in eine Zeile, und abgeschnitten
/// waere schlechter als umgebrochen.
///
/// **Warum es die Form nur einmal gibt.** Es gab eine zweite, fast gleiche Fassung auf der
/// Betriebsseite, weil die Vorlage dort nachgelesen wurde und die gemeinsame Ansicht gerade
/// nicht angefasst werden durfte. Zwei Fassungen derselben Form laufen auseinander, sobald
/// eine von beiden gepflegt wird.
struct Tagewahl: View {
    @Binding var tage: Int
    let moeglich: [Int]
    /// Die Beschriftung der Gruppe fuer die Bedienungshilfen, wie `aria-label` an `.kl-wahl`
    /// (`Betrieb.tsx:65`). `nil` laesst die Knoepfe einzeln stehen - so war es vorher, und so
    /// bleibt es an den Stellen, die keine Gruppe nennen.
    var gruppe: String?

    var body: some View {
        if let gruppe {
            reihe
                .accessibilityElement(children: .contain)
                .accessibilityLabel(gruppe)
        } else {
            reihe
        }
    }

    /// **Die Teile einzeln benannt und mit angeschriebenem Typ.** Eine Kette aus Polster,
    /// Grund, Rahmen und drei Fragezeichen ergibt „unable to type-check this expression in
    /// reasonable time“; das sieht man erst auf dem Mac, nicht beim Parsen.
    private var reihe: some View {
        Umbruchzeile(abstand: 6, zeilenabstand: 6) {
            ForEach(moeglich, id: \.self) { n in
                knopf(n)
            }
        }
    }

    private func knopf(_ n: Int) -> some View {
        let gewaehlt: Bool = n == tage
        return Button {
            tage = n
        } label: {
            Text("\(n) Tage")
                .font(schrift(gewaehlt))
                .foregroundStyle(gewaehlt ? Farbe.petrol : Farbe.text2)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(gewaehlt ? Farbe.amber : Color.clear)
                .overlay(Capsule().strokeBorder(rand(gewaehlt), lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(merkmale(gewaehlt))
    }

    /// Gewaehlt halbfett (`font-weight: 600`, `globals.css:894`): der Unterschied soll nicht
    /// allein an der Farbe haengen.
    private func schrift(_ gewaehlt: Bool) -> Font {
        gewaehlt
            ? Schrift.sansHalbfett(13, relativeTo: .footnote)
            : Schrift.klein
    }

    private func rand(_ gewaehlt: Bool) -> Color {
        gewaehlt ? Farbe.amber : Farbe.linie1
    }

    private func merkmale(_ gewaehlt: Bool) -> AccessibilityTraits {
        gewaehlt ? [.isButton, .isSelected] : [.isButton]
    }
}
