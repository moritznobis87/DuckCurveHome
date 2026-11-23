import DuckCurveKit
import SwiftUI

/// Die Ansichten eines Reiters: derselbe Gegenstand aus zwei Richtungen.
///
/// **Diese Zeile fehlte, und ohne sie gab es kein Zurück.** Drei Reiter des Technikbereichs
/// haben Unteransichten - Anlage (Jetzt · Ein Tag), Wärmepumpe (Jetzt · Betrieb · Kennlinie ·
/// Regler) und Fahrplan (Voraus · Rückblick). Gezeichnet wurde keine davon. Wer auf dem
/// Fahrplan einmal im Rückblick stand, kam nicht mehr zum Fahrplan selbst, denn der Reiter
/// „Fahrplan" führt auf `/waerme/fahrplan`, und `merkeReiter` hatte sich den Rückblick gemerkt:
/// Ein Tipp auf den Reiter landete wieder dort, wo man schon war.
///
/// Der Kern hat die Zeile die ganze Zeit vorgesehen - `Reiter.unter` trägt den Satz „Sie stehen
/// als Umschalter unter der Reiterzeile". Genau das ist sie.
///
/// **Sie ist still, wo es nichts zu wählen gibt.** Ein Reiter ohne Unteransichten, und einer
/// mit nur einer, bekommt keine Zeile - sonst stünde über acht der elf Technikseiten ein
/// Schalter mit einem einzigen Knopf.
struct Unteransichten: View {
    @Environment(Wegweiser.self) private var wegweiser

    let reiter: Reiter?

    var body: some View {
        if let reiter, reiter.unter.count > 1 {
            Ansichtswahl(ansichten: reiter.unter, aktiv: aktiv(reiter)) { a in
                wegweiser.gehe(a.weg)
                // Gemerkt wird die gewählte Ansicht, nicht der Reiter: wer den Rückblick
                // gewählt hat und später über den Bereich zurückkommt, soll ihn wiederfinden.
                wegweiser.merkeReiter()
            }
        }
    }

    /// Welche Ansicht gilt: die mit dem laufenden Weg, sonst die erste.
    ///
    /// Die erste Ansicht trägt die Adresse des Reiters selbst (`Bereiche.swift`), darum ist sie
    /// auch die richtige Antwort, wenn der Weg auf den Reiter zeigt.
    private func aktiv(_ reiter: Reiter) -> Ansicht {
        reiter.unter.first { $0.weg == wegweiser.weg } ?? reiter.unter[0]
    }
}
