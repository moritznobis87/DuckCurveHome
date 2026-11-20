import DuckCurveKit
import SwiftUI

/// Die Jahreskarte: ein Kalenderjahr als Fläche aus 365 Tagen und 24 Stunden.
///
/// **Warum eine Fläche und keine Kurve** (`YearMap.tsx:13-15`). Ein Jahr als Linie sind 8760
/// Punkte in einem Bild von 350 Punkten Breite; was übrig bleibt, ist Rauschen. Als Fläche aus Tag
/// und Stunde wird jede Gewohnheit ein Muster: die Heizperiode ein Block, die Sonne ein Bogen, die
/// Nachtabsenkung ein waagerechter Streifen - und die Entenkurve, über ein ganzes Jahr gelegt, ein
/// Bild statt einer Behauptung.
///
/// **Was diese Seite einmal falsch zeigte, und warum es hier steht.** Der Dienst liefert
/// `metrics` als `[Tag][Stunde 0-23]`; diese Seite las dieselbe Liste als Wochenzeilen mit sieben
/// Spalten. Damit waren die Stunden 7 bis 23 jedes Tages überhaupt nicht im Bild - siebzig Prozent
/// der Messwerte -, und die Achsen bedeuteten etwas anderes, als die Beschriftung behauptete. Das
/// Raster liegt jetzt im Kern (`Jahresraster`) und ist dort geprüft, gerade weil ein solcher
/// Fehler in einer Ansicht nicht auffällt: er sieht aus wie ein Bild.
///
/// **Gerechnet wird hier nichts.** Die Obergrenze der Skala, die Farbe je Zelle, die
/// Monatsanfänge, die Texte des Hinweisfensters und der Fließtext unter der Karte kommen aus
/// `Jahresraster`.
struct JahreskarteSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    @State private var karte: YearMapOut?
    @State private var raster: Jahresraster?
    @State private var fehler: ApiFehler?
    @State private var kennzahl: Jahreskennzahl = .netz
    @State private var jahr: Int = 0

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            kopf
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            kennzahlleiste
            bildkarte
            fussnote
        }
        .task(id: jahr) { await lade() }
        .onAppear {
            if jahr == 0 {
                jahr = Kalender.haus.component(.year, from: haus.jetzt)
            }
        }
    }

    // MARK: - Kopf: die Jahreswahl

    /// **Am Telefon steht die Jahreswahl in einer eigenen Zeile.**
    /// So macht es die Vorlage: `.report-header-right { display: contents }` löst den Kasten auf
    /// und gibt der Jahreswahl `order: 2; flex: 1 1 100%` (`handy.css:148-149`).
    ///
    /// **Der Kicker stand hier und steht jetzt im Gerippe.** Er gehört in der Vorlage der Hülle
    /// (`AreaShell.tsx:26`), nicht dieser Seite; ``Seite`` zeichnet ihn aus
    /// ``Bereiche/kicker(fuer:)``, und auch die Regel, dass er am Telefon wegfällt
    /// (`AreaNav.tsx:96`, `hidden … md:block` - unter 768 Punkten ist er nicht zu sehen), steht
    /// dort einmal statt hier und auf vier weiteren Seiten.
    private var kopf: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer(minLength: 4)
            jahreswahl
        }
    }

    /// Vier Jahre, das laufende zuerst (`YearMap.tsx:91-99`).
    ///
    /// **Keine Pfeile mehr.** Hier stand ein Blätterer ‹ Jahr › ohne untere Grenze; wer
    /// zwanzigmal zurück tippte, landete bei 2006 und holte sich eine leere Karte. Die Vorlage
    /// nennt vier Jahre, weil es für mehr keine Daten gibt - und vier Knöpfe zeigen zugleich, dass
    /// es nicht mehr gibt.
    private var jahreswahl: some View {
        HStack(spacing: 4) {
            ForEach(Jahresraster.jahreswahl(jetzt: haus.jetzt), id: \.self) { j in
                Button { jahr = j } label: { jahreswort(j) }
                    .buttonStyle(.plain)
            }
        }
        .padding(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Farbe.linie2, lineWidth: 1)
        )
    }

    private func jahreswort(_ j: Int) -> some View {
        let aktiv: Bool = j == jahr
        return Text(String(j))
            .font(Schrift.mono(12.5, relativeTo: .caption))
            .foregroundStyle(aktiv ? Farbe.petrol : Farbe.text2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(aktiv ? Farbe.amber : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
    }

    // MARK: - Die acht Kennzahlen

    /// Acht Knöpfe in der Reihenfolge der Vorlage, umbrechend statt rollend
    /// (`YearMap.tsx:104`, `flex-wrap`).
    ///
    /// **Umbrechen und nicht rollen.** Hier stand ein waagerechter Rollbereich - damit waren von
    /// acht Kennzahlen drei zu sehen und fünf hinter dem Rand, und welche es gibt, erfuhr man nur
    /// durch Wischen. Acht Wörter sind zwei Zeilen; zwei Zeilen zeigen alles.
    private var kennzahlleiste: some View {
        Umbruchzeile(abstand: 6, zeilenabstand: 6) {
            ForEach(Jahreskennzahl.allCases, id: \.self) { k in
                Button { waehle(k) } label: { kennzahlwort(k) }
                    .buttonStyle(.plain)
            }
        }
    }

    /// 13 Punkte am iPad, 14,5 am Telefon - dort ist Kleinschrift eine Stufe größer
    /// (`handy.css:189-192`: 13 → 14,5).
    private func kennzahlwort(_ k: Jahreskennzahl) -> some View {
        let aktiv: Bool = k == kennzahl
        return Text(k.name)
            .font(Schrift.sans(schmal ? 14.5 : 13, relativeTo: .footnote))
            .foregroundStyle(aktiv ? Farbe.amber : Farbe.text2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(aktiv ? Farbe.amber.opacity(0.10) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                    .strokeBorder(aktiv ? Farbe.amber : Farbe.linie2, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
    }

    private func waehle(_ k: Jahreskennzahl) {
        kennzahl = k
        baue()
    }

    // MARK: - Die Bildkarte

    /// Name der Kennzahl links, Einheit rechts (`YearMap.tsx:125`).
    ///
    /// **Das Jahr steht nicht mehr im Kicker.** Es stand dort und gleich daneben im Blätterer -
    /// zweimal dieselbe Zahl, und der Platz, an dem die Vorlage die Kennzahl nennt, blieb leer.
    @ViewBuilder private var bildkarte: some View {
        // Steht ein Fehler und ist noch nichts da, trägt das Band über der Seite die Auskunft;
        // eine leere Karte darunter wiederholte sie nur mit anderen Worten.
        if raster != nil || fehler == nil {
            Karte(kicker: kennzahl.name, beiwerk: einheitswort) {
                inhalt
            }
        }
    }

    private var einheitswort: AnyView? {
        guard !kennzahl.einheit.isEmpty else { return nil }
        return AnyView(
            Text(kennzahl.einheit)
                .font(Schrift.sans(12, relativeTo: .caption))
                .foregroundStyle(Farbe.text3)
        )
    }

    /// Die drei Zustände der Karte (`YearMap.tsx:127`).
    @ViewBuilder private var inhalt: some View {
        if let r = raster {
            if r.hatStundenwerte {
                Jahresflaeche(raster: r) { ziel in wegweiser.gehe(ziel.weg) }
            } else {
                // **Ein eigener Satz, keine leere Fläche.** Vorher stand hier ein Raster ohne
                // eine einzige Farbe, und das sieht aus wie ein Fehler der App statt wie ein
                // Jahr ohne Daten.
                Leer(satz: Jahresraster.keineStundenSatz(jahr: jahr))
            }
        } else {
            Leer(satz: Jahresraster.laedtSatz)
        }
    }

    // MARK: - Die Fußnote

    /// Der Fließtext unter der Karte (`YearMap.tsx:131-138`): was diese Karte zeigt, der Satz über
    /// Ortszeit und Lücken, die Stundenabdeckung und der wirkliche Werteumfang.
    ///
    /// **Statt einer zugeklappten `Methode`.** Hier stand eine, mit drei anderen Sätzen - und
    /// zugeklappt. Der wichtigste Teil dieses Textes ist der letzte: dass die Farbskala beim 98.
    /// Perzentil endet. Eine Skala, die etwas verschweigt, muss das offen sagen und nicht hinter
    /// einem Dreieck.
    @ViewBuilder private var fussnote: some View {
        if let r = raster {
            Text(r.fussnote)
                .font(Schrift.sans(schmal ? 13.5 : 12, relativeTo: .footnote))
                .foregroundStyle(Farbe.text3)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 640, alignment: .leading)
        }
    }

    // MARK: - Laden

    private func lade() async {
        guard jahr > 2000 else { return }
        do {
            karte = try await haus.api.jahreskarte(jahr: jahr)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
        baue()
    }

    /// Das Raster einmal bauen und merken.
    ///
    /// **Nicht in `body` rechnen.** `Jahresraster.baue` läuft über 8760 Zellen; in einem `body`
    /// liefe es bei jedem Bildwechsel, also auch beim Fahren des Fingers über die Fläche.
    private func baue() {
        guard let karte else {
            raster = nil
            return
        }
        raster = Jahresraster.baue(karte, kennzahl: kennzahl)
    }
}
