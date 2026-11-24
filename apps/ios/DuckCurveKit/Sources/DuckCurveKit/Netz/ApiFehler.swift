import Foundation

/// Ein Fehler des Dienstes oder des Netzes, mit einem Satz, der angezeigt werden kann.
///
/// Der Dienst antwortet im Fehlerfall mit `{"error": {"code", "message", "details"}}` - siehe
/// `apps/api/src/dch_api/errors.py`. Die Meldung darin ist deutsch und fuer Menschen gemacht;
/// sie wird darum angezeigt und nicht ersetzt. Nur wenn keine kommt, setzt dieser Typ einen
/// eigenen Satz ein.
public struct ApiFehler: Error, Sendable, Hashable {
    /// Der Schluessel des Dienstes, etwa `unauthorized` oder `upstream_unreachable`.
    public var code: String
    /// Was dem Benutzer gezeigt wird.
    public var meldung: String
    /// Der HTTP-Status, oder 0, wenn die Anfrage das Netz nicht verlassen hat.
    public var status: Int

    public init(code: String, meldung: String, status: Int) {
        self.code = code
        self.meldung = meldung
        self.status = status
    }

    /// Kein Netz, kein Dienst, nichts.
    public static func netz(_ grund: String) -> ApiFehler {
        ApiFehler(code: "network", meldung: "Keine Verbindung zum Haus. (\(grund))", status: 0)
    }

    /// Das Token stimmt nicht. Der haeufigste Fehler beim Einrichten.
    public var istAnmeldung: Bool { status == 401 || code == "unauthorized" }

    /// Ein Gast, der an etwas rührt, das ihm nicht gehoert.
    public var istVerboten: Bool { status == 403 || code == "forbidden" }

    /// Antwortet der Dienst gerade nicht? Das Netz ist weg, oder der Dienst startet neu und sein
    /// Vorbau meldet einen Fehler des Servers. Ein abgelehnter Zugang gehoert nicht dazu: dort
    /// antwortet der Dienst sehr wohl, und Warten aendert nichts.
    public var istOhneVerbindung: Bool { status == 0 || status >= 500 }

    /// Lohnt ein neuer Versuch? Bei 5xx und bei Netzfehlern ja, bei 4xx nicht - ein falsches
    /// Token wird beim zehnten Versuch nicht richtiger.
    public var lohntWiederholung: Bool {
        status == 0 || status >= 500 || status == 429
    }

    /// Der Satz, den die Oberflaeche zeigt - mit dem Hinweis, was zu tun ist, wo es einen gibt.
    public var rat: String {
        if istAnmeldung {
            return "Das Token stimmt nicht mehr. Unter „Zugang“ neu einrichten."
        }
        if istVerboten {
            return "Dieser Zugang darf das nicht. Als Hausherr anmelden."
        }
        if status == 0 {
            return "Das Haus ist nicht erreichbar. Ist das Gerät im Netz?"
        }
        return meldung
    }
}

/// Der Umschlag, in dem der Dienst Fehler verschickt.
struct FehlerUmschlag: Decodable {
    struct Inhalt: Decodable {
        var code: String?
        var message: String?
    }
    var error: Inhalt?
}
