import DuckCurveKit
import Foundation
import Security

/// Der Zugang: Adresse und Name in den Einstellungen, das Token im Schluesselbund.
///
/// **Warum zweigeteilt.** `UserDefaults` ist eine Datei im Container der App - lesbar fuer
/// jedes Programm, das an ein Backup kommt, und nicht durch die Gerätesperre geschuetzt. Fuer
/// die Adresse ist das in Ordnung; fuer ein Token, das am Dienst alles darf, nicht.
///
/// Der Schluesselbund steht mit `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` da: nach dem
/// ersten Entsperren lesbar (damit die Wandanzeige nach einem Stromausfall von selbst
/// weiterlaeuft), aber nicht in einem Backup und nicht auf einem anderen Geraet. Ein iPad, das
/// aus dem Haus getragen wird, nimmt das Token nicht mit, wenn es zurueckgesetzt wird.
enum Schluesselbund {
    private static let dienst = "home.duckcurve.app"
    private static let konto = "api-token"

    private enum Einstellung {
        static let adresse = "dch.adresse"
        static let praefix = "dch.praefix"
        static let geraetename = "dch.geraetename"
        static let rolle = "dch.rolle"
        /// Die E-Mail-Adresse der angemeldeten Person; fehlt bei einem Gerät mit API-Token.
        static let email = "dch.email"
        /// Gesetzt, wenn sich die Person abgemeldet hat. Siehe ``abgemeldet``.
        static let abgemeldet = "dch.abgemeldet"
    }

    /// Ob sich an diesem Gerät jemand abgemeldet hat und noch niemand neu angemeldet ist.
    ///
    /// Nach dem Abmelden bleiben Adresse und Gerätename stehen, damit man sie beim nächsten
    /// Anmelden nicht neu tippt; nur das Sitzungstoken ist weg. Ohne dieses Merkzeichen sähe die
    /// App danach aus wie eingerichtet und zeigte auf jeder Seite einen Fehler statt der
    /// Anmeldung. Ein leeres Token allein sagt es nicht: ein Dienst ohne Token (Demo) hat auch
    /// keines.
    static var abgemeldet: Bool {
        get { UserDefaults.standard.bool(forKey: Einstellung.abgemeldet) }
        set { UserDefaults.standard.set(newValue, forKey: Einstellung.abgemeldet) }
    }

    /// Den gespeicherten Zugang holen. Ohne Adresse kommt einer zurueck, der nicht eingerichtet ist.
    static func lies() -> Zugang {
        let einst = UserDefaults.standard
        let roh = einst.string(forKey: Einstellung.adresse) ?? ""
        let url = URL(string: roh) ?? Zugang.nichtEingerichtet
        return Zugang(
            grund: url,
            praefix: einst.string(forKey: Einstellung.praefix) ?? "/api/v1",
            token: token() ?? "",
            geraetename: einst.string(forKey: Einstellung.geraetename) ?? Geraet.ersatz,
            // Ein Wert, den diese Fassung nicht kennt, oder gar keiner: wie bisher der Hausherr.
            // Gesperrt wird am Dienst, hier wird nur ausgeblendet.
            rolle: einst.string(forKey: Einstellung.rolle).flatMap(Zugang.Rolle.init(rawValue:)) ?? .hausherr,
            email: einst.string(forKey: Einstellung.email) ?? ""
        )
    }

    static func speichere(_ z: Zugang) {
        let einst = UserDefaults.standard
        einst.set(z.grund.absoluteString, forKey: Einstellung.adresse)
        einst.set(z.praefix, forKey: Einstellung.praefix)
        einst.set(z.geraetename, forKey: Einstellung.geraetename)
        einst.set(z.rolle.rawValue, forKey: Einstellung.rolle)
        einst.set(z.email, forKey: Einstellung.email)
        setzeToken(z.token)
    }

    // MARK: - Der Schluesselbund

    private static var grundfrage: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
        ]
    }

    static func token() -> String? {
        var frage = grundfrage
        frage[kSecReturnData as String] = true
        frage[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: CFTypeRef?
        let stand = SecItemCopyMatching(frage as CFDictionary, &ergebnis)
        guard stand == errSecSuccess, let daten = ergebnis as? Data else { return nil }
        return String(data: daten, encoding: .utf8)
    }

    static func setzeToken(_ neu: String) {
        // Erst weg, dann hin: `SecItemUpdate` muss sonst den Sonderfall „gab es noch nicht"
        // getrennt behandeln, und das ist mehr Code fuer dasselbe Ergebnis.
        SecItemDelete(grundfrage as CFDictionary)
        guard !neu.isEmpty, let daten = neu.data(using: .utf8) else { return }
        var eintrag = grundfrage
        eintrag[kSecValueData as String] = daten
        eintrag[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(eintrag as CFDictionary, nil)
    }

    /// Alles loeschen - wenn das Geraet weitergegeben wird.
    static func loesche() {
        SecItemDelete(grundfrage as CFDictionary)
        let einst = UserDefaults.standard
        for k in [
            Einstellung.adresse, Einstellung.praefix, Einstellung.geraetename, Einstellung.rolle,
            Einstellung.email, Einstellung.abgemeldet,
        ] {
            einst.removeObject(forKey: k)
        }
    }
}
