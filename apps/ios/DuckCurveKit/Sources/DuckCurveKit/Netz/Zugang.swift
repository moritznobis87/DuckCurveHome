import Foundation

/// Wie die App an den Dienst kommt: Adresse, Token, Name des Geraets, Rolle.
///
/// ## Warum die App direkt mit der API spricht und nicht ueber das BFF
///
/// Das Dashboard laeuft im Browser und darf das API-Token nicht kennen - jeder, der die Seite
/// oeffnet, koennte es aus dem Netzverkehr lesen. Darum steht zwischen Browser und Dienst eine
/// eigene Route (`apps/web/src/app/api/dch/[...path]/route.ts`): sie prueft ein signiertes
/// Sitzungscookie, haengt das Token serverseitig an und reicht weiter.
///
/// Eine App braucht diesen Umweg nicht. Sie hat etwas, was eine Webseite nicht hat: einen
/// Schluesselbund. Das Token liegt dort, verlaesst das Geraet nur als `Authorization`-Kopfzeile
/// und ist durch die Gerätesperre geschuetzt. Das ist nicht weniger sicher als das Cookie,
/// sondern mehr - ein Cookie in einem Kiosk-Browser haelt niemanden auf, der das iPad in der Hand
/// hat.
///
/// Der Umweg ueber das BFF bliebe trotzdem moeglich: `grund` ist frei waehlbar, und wer dort die
/// Adresse des Dashboards eintraegt, bekommt dessen Gastregeln mit. Das ist der Grund, warum
/// `praefix` einstellbar ist.
///
/// ## Was die App dabei uebernehmen muss
///
/// Das BFF leistet drei Dinge, nicht eines. Zwei davon uebernimmt dieser Typ:
///
/// 1. **Das Token anhaengen.** Siehe oben.
/// 2. **Den Urheber mitschicken.** `apps/api/src/dch_api/urheber.py` schreibt in jedes Ereignis,
///    wer es ausgeloest hat - und zwar als vier Felder (`art`, `id`, `name`, `geraet`), damit
///    spaeter ein Benutzersystem dazukommen kann, ohne alte Zeilen umzuschreiben. Die App ist
///    ein Geraet, also `art: geraet`, und der Name ist der, den der Hausherr beim Einrichten
///    vergibt. Ohne diese Kopfzeilen stuende im Protokoll wieder nur, *dass* jemand den Sollwert
///    gestellt hat.
/// 3. **Gaeste auf Lesen beschraenken.** Das uebernimmt die App **nicht**, und das ist wichtig
///    zu wissen: im BFF ist die Beschraenkung eine Tuer (der Proxy antwortet mit 403), in der App
///    waere sie nur eine ausgeblendete Schaltflaeche. Wer das Token hat, darf am Dienst alles.
///    `rolle` blendet darum nur aus, was ein Gast nicht sehen soll; es sperrt nichts. Fuer einen
///    echten Gastzugang gibt es zwei Wege: ein eigenes, schwaecheres Token im Dienst - das gibt
///    es heute nicht - oder die App auf das BFF zeigen lassen und dort mit dem Gast-Token paaren.
///    Das steht auch in `apps/ios/README.md`, damit es niemand uebersieht.
public struct Zugang: Sendable, Hashable, Codable {
    /// Die Adresse des Dienstes, ohne Pfad: `https://dch.example.net`.
    public var grund: URL
    /// Der Pfad, unter dem die Endpunkte liegen. Am Dienst `/api/v1`, am BFF des Dashboards `/api/dch`.
    public var praefix: String
    /// Das Token aus `DCH_API_TOKEN`. Leer heisst: der Dienst laeuft ohne Token (Demo).
    public var token: String
    /// Der Name dieses Geraets, wie er im Protokoll erscheinen soll: „iPad Flur“.
    public var geraetename: String
    /// Was der Benutzer dieser App sehen darf. Blendet aus, sperrt nicht - siehe oben.
    public var rolle: Rolle

    public enum Rolle: String, Sendable, Hashable, Codable {
        case hausherr
        case gast
    }

    public init(
        grund: URL,
        praefix: String = "/api/v1",
        token: String = "",
        geraetename: String = "iPhone",
        rolle: Rolle = .hausherr
    ) {
        self.grund = grund
        self.praefix = praefix
        self.token = token
        self.geraetename = geraetename
        self.rolle = rolle
    }

    /// Die Kennung des Geraets im Protokoll: der Name, kleingeschrieben und entschaerft.
    ///
    /// `urheber.py` beschneidet auf 64 Zeichen, weil `config_versions.created_by` so breit ist.
    /// Das hier vorzubereiten ist freundlicher, als es den Dienst stillschweigend tun zu lassen.
    public var geraetekennung: String {
        let erlaubt = geraetename.lowercased().map { zeichen -> Character in
            if zeichen.isLetter || zeichen.isNumber { return zeichen }
            return "-"
        }
        var s = String(erlaubt)
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(s.prefix(64))
    }

    /// Die vollstaendige Adresse eines Endpunkts.
    public func adresse(_ pfad: String, _ fragen: [String: String?] = [:]) -> URL? {
        let voll = praefix.hasSuffix("/") ? String(praefix.dropLast()) : praefix
        guard var teile = URLComponents(url: grund, resolvingAgainstBaseURL: false) else { return nil }
        let grundpfad = teile.path.hasSuffix("/") ? String(teile.path.dropLast()) : teile.path
        teile.path = grundpfad + voll + (pfad.hasPrefix("/") ? pfad : "/" + pfad)
        let gesetzt = fragen.compactMap { schluessel, wert -> URLQueryItem? in
            guard let wert else { return nil }
            return URLQueryItem(name: schluessel, value: Self.entschaerft(wert))
        }
        .sorted { $0.name < $1.name }  // stabile Reihenfolge, damit Zwischenspeicher greifen
        teile.percentEncodedQueryItems = gesetzt.isEmpty ? nil : gesetzt
        return teile.url
    }

    /// Ein Wert, wie er in einer Frage stehen darf.
    ///
    /// **Warum nicht `URLComponents.queryItems`.** Das entschaerft nach RFC 3986, und dort ist
    /// `+` in einer Frage erlaubt - es bedeutet dort nichts Besonderes. In der Praxis liest aber
    /// jeder Webdienst eine Frage nach `application/x-www-form-urlencoded`, und dort ist `+` ein
    /// Leerzeichen. Ein Zeitstempel mit Zeitzonenversatz (`2026-11-16T00:00:00+01:00`) kaeme
    /// damit als `2026-11-16T00:00:00 01:00` am Dienst an, und der haette eine Stunde zu wenig -
    /// stillschweigend, mit einem Diagramm, das um eine Stunde verschoben ist.
    ///
    /// Der Doppelpunkt bleibt stehen. Er ist in einer Frage erlaubt und bedeutet nichts, und eine
    /// Adresse mit `%3A` an vier Stellen liest im Protokoll niemand mehr.
    static func entschaerft(_ wert: String) -> String {
        var erlaubt = CharacterSet.urlQueryAllowed
        erlaubt.remove(charactersIn: "+&=?#")
        return wert.addingPercentEncoding(withAllowedCharacters: erlaubt) ?? wert
    }

    /// Die Kopfzeilen, die jede Anfrage traegt.
    public var kopfzeilen: [String: String] {
        var k = ["accept": "application/json"]
        if !token.isEmpty { k["authorization"] = "Bearer " + token }
        if !geraetename.isEmpty {
            // Vier Felder, wie `urheber.py` sie erwartet. `art` ist heute immer `geraet`: am iPad
            // im Flur kann jeder gestanden haben, und rueckwirkend aus einem Geraet einen
            // Menschen zu machen waere eine Erfindung.
            k["x-dch-urheber-art"] = "geraet"
            k["x-dch-urheber-id"] = geraetekennung
            k["x-dch-urheber-name"] = geraetename
            k["x-dch-urheber-geraet"] = geraetename
            k["x-dch-urheber-rolle"] = rolle == .hausherr ? "owner" : "guest"
        }
        return k
    }

    /// Die Adresse, die „noch nichts eingerichtet" bedeutet.
    ///
    /// `.invalid` ist dafür reserviert (RFC 2606): ein Name, der nie auflöst. Genau das ist
    /// hier gewollt – ein Platzhalter, der niemals versehentlich jemanden anspricht.
    public static let nichtEingerichtet = URL(string: "https://nicht.eingerichtet.invalid")!

    /// Ob dieser Zugang eingerichtet ist. Ohne Adresse läuft nichts.
    ///
    /// **Ein Hostname allein genügt nicht, und das war ein Fehler.** Hier stand nur die Prüfung
    /// auf einen nicht-leeren Hostnamen – und der Platzhalter oben hat einen. Die App hielt ihn
    /// für eine Adresse, übersprang das Einrichten und sprach auf dem Gerät stundenlang mit
    /// `nicht.eingerichtet.invalid`: „A server with the specified hostname could not be found."
    /// Von außen sah es aus wie ein Netzproblem und war keines.
    ///
    /// Geprüft wird darum die ganze reservierte Endung und nicht nur dieser eine Name: wer
    /// später einen zweiten Platzhalter einführt, fällt nicht in dieselbe Grube.
    public var istEingerichtet: Bool {
        guard let gastgeber = grund.host, !gastgeber.isEmpty else { return false }
        return !gastgeber.hasSuffix(".invalid")
    }
}

// =====================================================================================
//  Die Sicherung: Adressen, die nicht JSON liefern
// =====================================================================================

extension Zugang {
    /// Welche Messreihe eine Sicherung enthält.
    ///
    /// **Warum ein Typ und nicht zwei Zeichenketten in der Ansicht.** Der Dienst nimmt genau
    /// zwei Werte - `docs/openapi.json`, Pfad `/api/v1/export/{kind}`, `enum: [minutes, hours]`.
    /// Eine dritte Zeichenkette dort hinzuschreiben ergibt kein Fehlerbild, sondern eine 422
    /// auf dem Gerät; ein Fall im `switch` ergibt einen Übersetzungsfehler. Und die beiden
    /// Wörter, mit denen die Vorlage sie benennt (`page.tsx:139-144`), sind eine Textauswahl
    /// und gehören deshalb hierher und nicht in eine `View`.
    public enum Exportart: String, Sendable, Hashable, CaseIterable, Codable {
        /// Die Minutenwerte: eine Zeile je Minute und Reihe.
        case minuten = "minutes"
        /// Die Stundenbilanz - mit den Grundlagen der PV-Abrechnung.
        case stunden = "hours"

        /// Wie der Verweis heißt (`page.tsx:140, 143`).
        ///
        /// Der Pfeil steht am Wort und nicht daneben: so hält es die Vorlage, und er sagt, was
        /// ein Tippen tut - laden, nicht blättern.
        public var wort: String {
            switch self {
            case .minuten: return "Minutenwerte ↓"
            case .stunden: return "Stundenbilanz ↓"
            }
        }
    }

    /// Die Adresse einer Jahressicherung - oder `nil`, wenn das Jahr keines ist, das der Dienst
    /// annimmt.
    ///
    /// **Warum die Grenzen hier geprüft werden und nicht erst am Dienst.** `docs/openapi.json`
    /// schreibt für `year` `minimum: 2000, maximum: 2100`. Eine Adresse mit `year=1999` ist
    /// keine Adresse, sondern eine 422 mit Verzögerung - und sie entsteht nicht aus einem
    /// Tippfehler, sondern aus einer Uhr, die nach einem Stromausfall auf 1970 steht. Dann
    /// soll der Verweis nicht da sein, statt ins Leere zu führen.
    ///
    /// **Was diese Adresse nicht kann.** Sie liefert eine Datei und kein JSON; ``Api`` hat
    /// darum keinen Griff dafür (gesucht nach „export“: kein Treffer). Wer sie öffnet, muss
    /// die `Authorization`-Kopfzeile selbst mitbringen - ``kopfzeilen`` hat sie. Gibt die
    /// Oberfläche die Adresse an den Browser weiter, fehlt sie dort; nachzulesen bei
    /// ``Zugangsworte/herunterladen``, wo genau dieser Vorbehalt dem Benutzer gesagt wird.
    public func export(art: Exportart, jahr: Int) -> URL? {
        guard (2000...2100).contains(jahr) else { return nil }
        return adresse("/export/" + art.rawValue, ["year": String(jahr)])
    }
}
