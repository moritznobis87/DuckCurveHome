import DuckCurveKit
import Observation
import SwiftUI
import UserNotifications

/// Mitteilungen auf dieses Geraet.
///
/// ## Warum das nicht derselbe Weg ist wie im Dashboard
///
/// Der Dienst schickt Mitteilungen bisher als **Web Push** mit einem VAPID-Schluesselpaar
/// (`apps/api/src/dch_api/application/push.py`). Das ist fuer einen Browser der richtige Weg und
/// fuer eine App keiner: eine iOS-App kann Web Push nicht empfangen. Apple laesst Mitteilungen
/// nur ueber **APNs** zu, und dort ist die Adresse kein Endpunkt beim Push-Dienst des Browsers,
/// sondern ein Geraetetoken, das das Betriebssystem vergibt.
///
/// Darum ist der Dienst um einen zweiten Weg erweitert worden - `/push/apns/*` neben
/// `/push/subscribe`. Beide Wege bedienen dieselben Mitteilungen und dieselben Regeln (siehe
/// `push.py`); nur der Versand unterscheidet sich.
///
/// **Was der Hausherr dafuer beschaffen muss, kann niemand sonst beschaffen:** einen
/// Signierschluessel aus seinem Apple-Developer-Konto (eine `.p8`-Datei, eine Schluesselkennung
/// und eine Teamkennung). Ohne den kann kein Dienst auf der Welt eine Mitteilung an diese App
/// schicken - das ist Apples Entwurf und nicht zu umgehen. Wie er eingetragen wird, steht in
/// `apps/ios/README.md`.
///
/// **Was ohne ihn trotzdem geht.** Die Seite „Mitteilungen" zeigt, was im Morgenbrief stuende,
/// und laesst ihn von Hand ansehen. Nur der Weg auf den Sperrbildschirm fehlt.
@MainActor
@Observable
final class Mitteilungen: NSObject {
    /// Wie es um die Erlaubnis steht.
    enum Stand: Equatable {
        case ungefragt
        case erlaubt
        case abgelehnt
        /// Erlaubt, aber der Dienst kennt das Geraet noch nicht.
        case angemeldet
        case fehler(String)
    }

    var stand: Stand = .ungefragt
    /// Das Geraetetoken, wie APNs es vergibt - hexadezimal.
    private(set) var token: String?

    private weak var haus: Hauszustand?

    func verbinde(mit haus: Hauszustand) {
        self.haus = haus
        UNUserNotificationCenter.current().delegate = self
        Task { await pruefeStand() }
    }

    /// Nachsehen, was der Benutzer schon entschieden hat - ohne zu fragen.
    ///
    /// Fragen ohne Anlass ist der haeufigste Fehler mit Mitteilungen: ein Dialog beim ersten
    /// Start, den niemand einordnen kann, wird abgelehnt, und danach ist die Tuer zu. Gefragt
    /// wird darum erst auf der Seite „Mitteilungen", wo dabeisteht, wofuer.
    func pruefeStand() async {
        let einstellungen = await UNUserNotificationCenter.current().notificationSettings()
        switch einstellungen.authorizationStatus {
        case .notDetermined:
            stand = .ungefragt
        case .denied:
            stand = .abgelehnt
        case .authorized, .provisional, .ephemeral:
            stand = token == nil ? .erlaubt : .angemeldet
            await meldeBeimSystemAn()
        @unknown default:
            stand = .ungefragt
        }
    }

    /// Fragen, und bei Ja gleich beim System anmelden.
    func frage() async {
        do {
            let ja = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            guard ja else {
                stand = .abgelehnt
                return
            }
            stand = .erlaubt
            await meldeBeimSystemAn()
        } catch {
            stand = .fehler(error.localizedDescription)
        }
    }

    private func meldeBeimSystemAn() async {
        #if canImport(UIKit)
            UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    /// Das Token ist da - jetzt kennt der Dienst dieses Geraet.
    ///
    /// Gerufen vom Einstieg der App, wenn APNs geantwortet hat. Das Token kann sich aendern (bei
    /// einer Neuinstallation, einem Backup, einem Systemwechsel), darum wird es bei jedem Start
    /// neu gemeldet und nicht nur einmal.
    func tokenKam(_ roh: Data) {
        let hex = roh.map { String(format: "%02x", $0) }.joined()
        token = hex
        Task { await meldeBeimDienstAn(hex) }
    }

    func tokenFehlte(_ fehler: any Error) {
        stand = .fehler(fehler.localizedDescription)
    }

    private func meldeBeimDienstAn(_ token: String) async {
        guard let haus else { return }
        do {
            _ = try await haus.api.meldeApnsAn(token: token, name: haus.zugang.geraetename)
            stand = .angemeldet
        } catch let f as ApiFehler {
            // Ein Dienst, der den Weg noch nicht kennt, ist kein Fehler des Geraets - das soll
            // die Seite sagen koennen, ohne wie eine Stoerung auszusehen.
            stand = f.status == 404
                ? .fehler("Dieser Dienst kennt noch keine App-Mitteilungen.")
                : .fehler(f.rat)
        } catch {
            stand = .fehler(error.localizedDescription)
        }
    }

    /// Dieses Geraet abmelden.
    func meldeAb() async {
        guard let haus, let token else { return }
        _ = try? await haus.api.meldeApnsAb(token: token)
        stand = .erlaubt
    }
}

extension Mitteilungen: UNUserNotificationCenterDelegate {
    /// Eine Mitteilung, die ankommt, waehrend die App offen ist.
    ///
    /// Sie wird gezeigt. Das ist nicht selbstverstaendlich - iOS unterdrueckt sie sonst -, und
    /// hier ist es richtig: die Wandanzeige ist immer offen, und eine Mitteilung, die *nur* dann
    /// ankommt, wenn niemand hinsieht, ist der Zweck verfehlt.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Jemand hat auf die Mitteilung getippt.
    ///
    /// Die Mitteilung traegt ein Ziel (`url` in `push.py`, etwa „/waerme/anlage"). Die App
    /// springt dorthin - in derselben Schreibweise, in der auch das Dashboard seine Seiten
    /// kennt, und genau das ist der Grund, warum die Wege in `Bereiche` erhalten geblieben sind.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let inhalt = response.notification.request.content.userInfo
        guard let ziel = inhalt["url"] as? String else { return }
        await MainActor.run {
            Zielsprung.gewuenscht = Bereiche.alleWege.contains(ziel) ? ziel : "/"
        }
    }
}

/// Wohin eine angetippte Mitteilung fuehren soll.
///
/// Ein Umweg ueber eine statische Stelle, weil der Delegate von APNs nicht in der Ansicht
/// steht - und weil die Mitteilung ankommen kann, bevor die Oberflaeche ueberhaupt da ist.
@MainActor
enum Zielsprung {
    static var gewuenscht: String?

    /// Das Ziel abholen und vergessen.
    static func abholen() -> String? {
        defer { gewuenscht = nil }
        return gewuenscht
    }
}

#if canImport(UIKit)
    import UIKit
#endif

extension Api {
    /// Dieses Geraet fuer APNs anmelden.
    ///
    /// Der Rumpf ist absichtlich derselbe Zuschnitt wie bei Web Push (`PushSubscribeIn`): eine
    /// Adresse, ein Name, eine Herkunft. Nur dass die Adresse hier ein Geraetetoken ist und die
    /// beiden Schluessel fehlen - APNs verschluesselt selbst.
    public func meldeApnsAn(token: String, name: String) async throws -> PushResultOut {
        try await hole(
            "/push/apns/subscribe", verfahren: "POST",
            rumpf: try JSONEncoder().encode([
                "token": Mischwert.text(token),
                "label": .text(name),
                // Die Umgebung muss mitkommen: ein Token aus einem Entwicklungsbau gilt bei
                // Apple an einer anderen Adresse als eines aus dem App Store, und wer das
                // verwechselt, bekommt „BadDeviceToken" ohne weitere Auskunft.
                "sandbox": .ja(Bauart.istEntwicklung),
            ])
        )
    }

    public func meldeApnsAb(token: String) async throws -> PushResultOut {
        try await hole(
            "/push/apns/unsubscribe", verfahren: "POST",
            rumpf: try JSONEncoder().encode(["token": Mischwert.text(token)])
        )
    }
}

/// Ob dieser Bau aus der Entwicklung kommt.
///
/// Entscheidet, an welche Adresse bei Apple der Dienst die Mitteilung schickt. `DEBUG` allein
/// genuegt nicht: ein Bau fuer TestFlight ist kein Debug-Bau und braucht trotzdem die
/// Produktionsadresse - aber ein Bau, der mit einem Entwicklungsprofil signiert ist, braucht die
/// Sandbox. Der Unterschied steht in der Signatur und ist zur Laufzeit nicht sicher zu erkennen,
/// darum: `DEBUG` heisst Sandbox, alles andere Produktion. Wer mit TestFlight testet, hat damit
/// das Richtige.
enum Bauart {
    static var istEntwicklung: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
}
