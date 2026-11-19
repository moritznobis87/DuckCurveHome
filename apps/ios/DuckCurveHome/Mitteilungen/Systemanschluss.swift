import SwiftUI

#if canImport(UIKit)
    import UIKit

    /// Der Anschluss ans System für Mitteilungen.
    ///
    /// **Dieser Teil fehlte, und ohne ihn war der ganze Weg tot.** Die App rief
    /// `registerForRemoteNotifications()`, Apple antwortet darauf dem Delegaten der
    /// Anwendung – und einen gab es nicht. Das Gerätetoken kam also nie an, wurde nie an den
    /// Dienst gemeldet, und eine Mitteilung hätte dieses Gerät nie erreicht. Nichts daran
    /// stürzt ab, nichts meldet sich: es passiert einfach nichts. Aufgefallen ist es erst, als
    /// die Signierung am Gerät scheiterte und ich den Weg nachgelesen habe.
    ///
    /// Die beiden Rückmeldungen von Apple sind das Einzige, was hier steht. Alles Weitere –
    /// Anmelden beim Dienst, Abmelden, der Stand der Erlaubnis – gehört in `Mitteilungen`.
    final class Systemanschluss: NSObject, UIApplicationDelegate {
        /// Gesetzt von `Mitteilungen.verbinde(mit:)`. Schwach, weil SwiftUI diesen Delegaten
        /// selbst erzeugt und am Leben hält, nicht wir.
        @MainActor static weak var mitteilungen: Mitteilungen?

        func application(
            _ application: UIApplication,
            didRegisterForRemoteNotificationsWithDeviceToken token: Data
        ) {
            MainActor.assumeIsolated { Systemanschluss.mitteilungen?.tokenKam(token) }
        }

        func application(
            _ application: UIApplication,
            didFailToRegisterForRemoteNotificationsWithError fehler: Error
        ) {
            MainActor.assumeIsolated {
                Systemanschluss.mitteilungen?.anmeldungScheiterte(fehler)
            }
        }
    }
#endif
