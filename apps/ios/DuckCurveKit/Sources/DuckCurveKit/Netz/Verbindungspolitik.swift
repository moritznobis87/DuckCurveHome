import Foundation

/// Der Zustand der Verbindung zum Haus, wie die Anzeige ihn zeigt.
public enum Verbindung: String, Sendable, Hashable {
    /// Der erste Versuch laeuft noch.
    case verbindet
    /// Rahmen kommen.
    case live
    /// Die Verbindung ist abgerissen, der naechste Versuch ist angesetzt.
    case verbindetNeu
    /// Aufgegeben - nur, wenn die App in den Hintergrund geht oder der Benutzer es will.
    case aus
}

/// Wann neu verbunden wird und wie lange gewartet wird.
///
/// **Warum das ein eigener Typ ist und keine drei Zeilen im Strom.** Eine Wandanzeige haengt an
/// dieser Politik: sie laeuft Wochen am selben Platz, das WLAN bricht nachts weg, der Dienst wird
/// neu ausgerollt, das iPad schlaeft ein. Jede dieser Lagen hat eine richtige Antwort, und keine
/// davon ist „jede Sekunde neu versuchen". Zugleich ist es die Sorte Logik, die sich im Netz
/// nicht pruefen laesst - man kann kein WLAN in einem Test abschalten. Also steht sie hier,
/// rechnet auf Zahlen und wird von `VerbindungspolitikTests` durchgespielt.
///
/// Die Vorlage ist `apps/web/src/lib/live/sseClient.ts`, mit zwei Unterschieden, die dort
/// begruendet sind:
///
/// 1. **Der Herzschlag zaehlt.** Der Dienst schickt alle paar Sekunden ein `heartbeat`-Ereignis
///    (siehe `routers/live.py`). Das Dashboard beachtet es nicht: seine Aufsicht sieht nur auf
///    den letzten `snapshot`. Das faellt dort nicht auf, weil Augenblicksbilder im Sekundentakt
///    kommen - aber es heisst, dass eine Verbindung, die *nur* Herzschlaege liefert, alle 15
///    Sekunden abgerissen und neu aufgebaut wird. Hier zaehlt jeder Rahmen als Lebenszeichen und
///    nur ein Augenblicksbild als neue Zahl. Das sind zwei verschiedene Fragen.
/// 2. **Der Hintergrund.** Eine Webseite im Kiosk-Browser laeuft immer. Eine App wird angehalten,
///    sobald der Benutzer sie weglegt, und ein Wecker, der im Hintergrund alle fuenf Sekunden
///    feuert, kostet Batterie, ohne etwas zu bewirken. `beimWegbleiben` haelt darum an und
///    `beimZurueckkommen` verbindet sofort - ohne Wartezeit, denn der Benutzer sieht gerade hin.
public struct Verbindungspolitik: Sendable {
    /// Die erste Wartezeit nach einem Abriss.
    public static let ersteWartezeit: Double = 1.0
    /// Mehr als das wird nie gewartet. 30 Sekunden ist die Spanne, nach der jemand, der vor der
    /// Anzeige steht, von sich aus zum Tablet greift.
    public static let hoechsteWartezeit: Double = 30.0
    /// Ohne Rahmen so lange gilt die Verbindung als tot, auch wenn das Betriebssystem sie noch
    /// offen haelt. Der Dienst schickt oefter als das.
    public static let stilleBisAbriss: Double = 15.0

    /// Wie oft hintereinander es schiefgegangen ist.
    public private(set) var fehlversuche = 0

    public init() {}

    /// Ein Versuch ist gelungen: die Wartezeit faellt zurueck auf den Anfang.
    public mutating func gelungen() {
        fehlversuche = 0
    }

    /// Ein Versuch ist gescheitert. Rueckgabe: wie lange bis zum naechsten.
    ///
    /// Verdoppelt bis zur Obergrenze und streut dabei. **Die Streuung ist nicht Kosmetik:** nach
    /// einem Neustart des Dienstes wollen iPad, iPhone und Wandanzeige alle gleichzeitig wieder
    /// herein, und ein Dienst, der gerade erst hochkommt, bekommt dann drei Anfragen in derselben
    /// Millisekunde - und nach jedem Fehlschlag wieder, im Gleichschritt. Ein halbes Zufallsmass
    /// loest den Gleichschritt auf.
    public mutating func gescheitert(zufall: Double = Double.random(in: 0..<1)) -> Double {
        let grund = min(Self.ersteWartezeit * pow(2, Double(fehlversuche)), Self.hoechsteWartezeit)
        fehlversuche += 1
        return grund + zufall * 0.5
    }

    /// Die Wartezeit, die beim naechsten Fehlschlag anstuende - ohne zu zaehlen.
    public var naechsteWartezeit: Double {
        min(Self.ersteWartezeit * pow(2, Double(fehlversuche)), Self.hoechsteWartezeit)
    }

    /// Ist die Verbindung verstummt?
    ///
    /// Maßgeblich ist der letzte Rahmen irgendeiner Art, nicht das letzte Augenblicksbild - siehe
    /// die Begruendung oben.
    public static func istVerstummt(letzterRahmen: Date?, jetzt: Date) -> Bool {
        guard let letzterRahmen else { return false }
        return jetzt.timeIntervalSince(letzterRahmen) > stilleBisAbriss
    }

    /// Was der Dienst als Wartezeit vorschlaegt, in die Grenzen gelegt.
    ///
    /// Ein `retry:` aus dem Strom ist ein Wunsch, kein Befehl: ein Dienst, der versehentlich
    /// `retry: 10` schickt, soll die Anzeige nicht in eine Schleife mit zehn Millisekunden
    /// treiben.
    public static func vorschlagInGrenzen(_ sekunden: Double?) -> Double? {
        guard let sekunden, sekunden.isFinite, sekunden > 0 else { return nil }
        return min(max(sekunden, ersteWartezeit), hoechsteWartezeit)
    }
}
