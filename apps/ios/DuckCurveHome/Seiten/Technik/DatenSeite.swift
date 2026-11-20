import DuckCurveKit
import SwiftUI

/// Daten prüfen: wie lückenlos die Messwerte sind, und die Tagesdiagnose.
///
/// **Die wichtigste Seite für das Vertrauen in alle anderen.** Jede Zahl dieser App steht auf
/// Minutenwerten; wo die fehlen, rechnet der Dienst mit weniger, als er zu haben scheint. Die
/// längste Lücke je Reihe sagt, wie schlimm es war.
///
/// **Der Platzbedarf stand hier und steht jetzt auf `/system/zugang`.** Dort hat ihn die
/// Vorlage (`apps/web/src/app/system/zugang/page.tsx` mit
/// `apps/web/src/components/settings/StorageReport.tsx`), und hier hatte er nie eine Frage, die
/// er beantwortet: „kommen die Daten an?“ und „wie viel wiegen sie?“ sind zwei Fragen, und die
/// zweite nahm den Platz vor der ersten. Mit ihm ist die private Abschrift von `megabyte`
/// gegangen - sie steht als ``Formate/megabyte(_:)`` im Kern, wo sie geprüft ist.
struct DatenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Wie viele Tage die Waermekarte zeigt (`DataCheck.tsx:98`). Die Zahl steht im Kicker und
    /// in der Abfrage, darum nur einmal.
    private static let kartentage = 28

    @State private var abdeckung: CoverageOut?
    @State private var diagnose: String?
    @State private var fehler: ApiFehler?
    /// Die Minutenwerte des Tages - die Reihen, um die es auf dieser Seite geht.
    @State private var kurve = Pruefkurve()
    @State private var hatMinuten = false

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        // **Keine Spannenwahl** (`DataCheck.tsx:59-68`, `showPeriods={false}`): diese Seite
        // kennt nur Tage. Minutenwerte über eine Woche ergäben ein Bild, in dem man nichts
        // erkennt - und genau zum Erkennen ist sie da.
        Seite(zeitraum: Zeitraumleiste(spannen: [.tag])) {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade(z) } }
            }
            Karte(kicker: "Leistungen über den Tag") {
                if hatMinuten {
                    Pruefkurvenbild(kurve: kurve)
                } else {
                    Leer(satz: Pruefkurve.leersatz)
                }
            }
            Karte(
                kicker: "Quellen",
                beiwerk: AnyView(
                    Text("liefert gerade, was liefern soll?")
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3))
            ) {
                Quellenkarte(zeilen: Quellenstand.zeilen(aus: haus.zustand?.system))
            }
            if let a = abdeckung {
                Karte(
                    kicker: "Kommen die Daten an? \(Self.kartentage) Tage",
                    beiwerk: AnyView(
                        Text("Farbe = Minuten je Stunde, 0 bis 60")
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3))
                ) {
                    Abdeckungskarte(reihen: Abdeckungsraster.baue(a), jetzt: haus.jetzt)
                }
            }
            if let d = diagnose, !d.isEmpty {
                // **Reiner Text, und das soll er bleiben.** Die Tagesdiagnose ist eine Tabelle
                // zum Lesen, keine Datenstruktur - der Dienst schickt sie darum ohne
                // JSON-Umschlag. Sie in Zeilen zu zerlegen und neu zu setzen hiesse, sie zu
                // interpretieren.
                Karte(kicker: "Stundenbilanz und auffällige Strecken") {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(d)
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                            .textSelection(.enabled)
                    }
                }
            }
            // Die drei Absaetze der Vorlage (`DataCheck.tsx:119-147`) erklaeren, wie die
            // Bilder darueber zu lesen sind - sie fehlten ganz. Dann die Noten des Dienstes,
            // und dazwischen der Absatz zur leeren gegen die rote Zelle, der in der Vorlage
            // unmittelbar unter der Karte steht (`CoverageMap.tsx:146-152`).
            Methode(
                Pruefworte.methode.map(Optional.init) + [
                    abdeckung?.noteDe,
                    Abdeckungsraster.lesehilfe,
                    Pruefworte.abdeckungssatz,
                ])
        }
        .task(id: z) { await lade(z) }
    }

    private func lade(_ z: Zeitraum) async {
        async let minuten = try? haus.api.verlaufTag(z.anker)
        let historie = await minuten
        kurve = Pruefkurve.baue(tag: z.anker, historie: historie)
        hatMinuten = !kurve.leer

        // **Immer achtundzwanzig Tage, unabhaengig von der Spanne.** Die Karte ist das
        // Gegenstueck zur Frage „kommen die Daten an?“, und die beantwortet ein einzelner Tag
        // nicht: ein Abriss, der jede Nacht wiederkommt, ist erst ueber Wochen ein Muster
        // (`DataCheck.tsx:98`, `days = 28`). Die Spannenwahl steht auf dieser Seite ohnehin
        // auf Tag.
        async let a = try? haus.api.abdeckung(anker: z.anker, tage: Self.kartentage)
        // Die Tagesdiagnose gibt es nur für einen Tag - für eine Woche wäre sie sieben Tabellen.
        async let d = z.spanne == .tag ? try? haus.api.diagnose(tag: z.anker) : nil
        abdeckung = await a
        diagnose = await d
        fehler = abdeckung == nil ? .netz(Abdeckungsraster.nichtAbrufbar) : nil
    }
}
