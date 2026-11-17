import DuckCurveKit
import SwiftUI

/// Duck Curve Home auf iPhone und iPad.
///
/// **Ein Programm, zwei Oberflaechen.** Die Wahl trifft `Wurzel` nach der Breite; was die beiden
/// unterscheidet, steht in `WandRahmen` und `HandRahmen`. Sie teilen den Kern (`DuckCurveKit`),
/// die Gestaltung und die Bausteine - nicht das Gerippe.
///
/// **Die Wandanzeige ist der schwierigere Fall.** Sie laeuft Wochen am selben Platz, wird nicht
/// bedient und soll trotzdem stimmen. Drei Dinge gehoeren darum hierher, in den Einstieg:
///
/// 1. **Der Bildschirm bleibt an.** Ein iPad an der Wand, das sich abschaltet, ist ein schwarzes
///    Brett. `isIdleTimerDisabled` ist die einzige Stelle, an der diese App dem System
///    widerspricht - und nur, wenn sie an einer Wand haengt (iPad, am Strom).
/// 2. **Dunkel, immer.** Die Gestaltung ist fuer Dunkelheit gemacht (`tokens.css`: „Dunkle
///    Oberflaechen"); eine helle Fassung gibt es nicht und soll es nicht geben.
/// 3. **Querformat am iPad, beides am Telefon.** Die Wandanzeige ist im Querformat gedacht, und
///    ein iPad, das an der Wand kippt, ist kein Fall, den man vorsehen muss.
@main
struct DuckCurveHomeApp: App {
    @State private var haus = Hauszustand(zugang: Schluesselbund.lies())
    @State private var mitteilungen = Mitteilungen()
    #if canImport(UIKit)
        // Ohne diesen Anschluss kommt das Geraetetoken von Apple nirgends an.
        @UIApplicationDelegateAdaptor(Systemanschluss.self) private var anschluss
    #endif

    var body: some Scene {
        WindowGroup {
            Wurzel()
                .environment(haus)
                .environment(mitteilungen)
                .onAppear {
                    haltDenBildschirmAn()
                    mitteilungen.verbinde(mit: haus)
                }
        }
    }

    /// Den Ruhezustand abschalten - nur am iPad.
    ///
    /// Am Telefon waere das eine Unverschaemtheit: niemand will, dass eine App seinen Akku
    /// leerlaufen laesst, weil sie sich fuer wichtig haelt. Am iPad an der Wand ist es der
    /// Unterschied zwischen einer Anzeige und einem Spiegel.
    private func haltDenBildschirmAn() {
        #if canImport(UIKit)
            guard UIDevice.current.userInterfaceIdiom == .pad else { return }
            UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }
}

#if canImport(UIKit)
    import UIKit
#endif
