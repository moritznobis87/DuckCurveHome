import Foundation

/// Ein Ereignis aus dem Strom des Dienstes.
public struct SseEreignis: Sendable, Hashable {
    /// Der Name hinter `event:`. Ohne Angabe gilt `message`, so steht es in der Spezifikation.
    public var art: String
    /// Der Rumpf hinter `data:`. Mehrere `data:`-Zeilen werden mit Zeilenumbruch verbunden.
    public var daten: String
    /// Die Kennung hinter `id:`, falls der Dienst eine schickt.
    public var kennung: String?

    public init(art: String = "message", daten: String, kennung: String? = nil) {
        self.art = art
        self.daten = daten
        self.kennung = kennung
    }
}

/// Der Leser des Ereignisstroms (`text/event-stream`), stueckweise und ohne Netz.
///
/// **Warum das ein eigener, reiner Typ ist.** `EventSource` im Browser nimmt dem Dashboard diese
/// Arbeit ab; unter iOS gibt es nichts Entsprechendes. Die Arbeit selbst ist klein, aber sie hat
/// genau die Eigenschaft, an der handgeschriebene Leser scheitern: die Daten kommen in Stuecken,
/// die nicht an Zeilengrenzen liegen. Ein Rahmen von 40 kB - und der Live-Zustand dieses Hauses
/// ist so gross - kommt als vier TCP-Pakete, und das dritte endet mitten in einer Zahl.
///
/// Darum haelt dieser Typ einen Puffer und gibt nur vollstaendige Ereignisse heraus. Er kennt
/// kein `URLSession`, nimmt `Data` und liefert `SseEreignis` - und ist damit das Stueck der
/// Netzschicht, das sich vollstaendig pruefen laesst. `SseLeserTests` schickt denselben Rahmen
/// byteweise durch und erwartet dasselbe Ergebnis wie bei einem Stueck.
///
/// Umgesetzt ist die Spezifikation von WHATWG, Abschnitt „interpreting an event stream“:
///
/// - Zeilen enden auf `\n`, `\r` oder `\r\n`.
/// - Eine leere Zeile schliesst das Ereignis ab und gibt es heraus.
/// - `feld: wert` - ein Leerzeichen nach dem Doppelpunkt gehoert nicht zum Wert.
/// - Eine Zeile, die mit `:` beginnt, ist ein Kommentar. Der Dienst nutzt sie zum Offenhalten.
/// - Ein Ereignis ohne `data:` wird verworfen.
public struct SseLeser: Sendable {
    /// **Warum `[UInt8]` und nicht `Data`.** `Data` als Puffer ist hier eine Falle: eine
    /// Teilfolge von `Data` behaelt die Indizes ihres Ursprungs, und wer danach wieder an sie
    /// anhaengt, rechnet mit Indizes, die nicht mehr bei null beginnen. Das stuerzt nicht
    /// zuverlaessig ab, sondern gelegentlich - genau die Sorte Fehler, die an einer Wandanzeige
    /// nach drei Tagen auftritt. Ein Feld aus Bytes mit ausdruecklichem Leseversatz ist
    /// langweilig und richtig.
    private var puffer: [UInt8] = []
    /// Bis hierher ist gelesen. Der Puffer wird erst verdichtet, wenn sich etwas angesammelt hat.
    private var gelesen = 0
    /// Das vorige Stueck endete auf `\r`. Beginnt das naechste mit `\n`, gehoeren die zwei
    /// zusammen und sind ein Umbruch, nicht zwei.
    private var letztesWarWagenruecklauf = false
    private var art: String?
    private var datenZeilen: [String] = []
    private var kennung: String?
    /// Was der Dienst als Wartezeit vor dem naechsten Versuch vorschlaegt (`retry:`), in Sekunden.
    public private(set) var vorschlagWartezeit: Double?

    public init() {}

    /// Ein Stueck aus dem Netz hineingeben, fertige Ereignisse herausnehmen.
    public mutating func nimm(_ stueck: Data) -> [SseEreignis] {
        puffer.append(contentsOf: stueck)
        // Ein `\n`, das zu einem `\r` am Ende des vorigen Stueckes gehoert, ueberspringen.
        if letztesWarWagenruecklauf, gelesen < puffer.count, puffer[gelesen] == UInt8(ascii: "\n") {
            gelesen += 1
        }
        letztesWarWagenruecklauf = false
        var fertig: [SseEreignis] = []

        while let zeile = naechsteZeile() {
            if zeile.isEmpty {
                // Leere Zeile: das Ereignis ist zu Ende.
                if !datenZeilen.isEmpty {
                    fertig.append(
                        SseEreignis(
                            art: art ?? "message",
                            daten: datenZeilen.joined(separator: "\n"),
                            kennung: kennung
                        )
                    )
                }
                art = nil
                datenZeilen = []
                continue
            }
            // Kommentar - der Dienst haelt damit die Verbindung offen.
            if zeile.hasPrefix(":") { continue }

            let (feld, wert) = teile(zeile)
            switch feld {
            case "event": art = wert
            case "data": datenZeilen.append(wert)
            case "id":
                // Eine Kennung mit Nullbyte ist nach Spezifikation zu verwerfen.
                if !wert.contains("\0") { kennung = wert }
            case "retry":
                if let ms = Double(wert), ms >= 0 { vorschlagWartezeit = ms / 1000 }
            default: break  // unbekannte Felder werden ignoriert
            }
        }
        verdichte()
        return fertig
    }

    /// Die naechste vollstaendige Zeile aus dem Puffer, oder `nil`, wenn noch keine da ist.
    private mutating func naechsteZeile() -> String? {
        let lf = UInt8(ascii: "\n")
        let cr = UInt8(ascii: "\r")
        var i = gelesen
        while i < puffer.count, puffer[i] != lf, puffer[i] != cr { i += 1 }
        guard i < puffer.count else { return nil }

        let zeile = String(decoding: puffer[gelesen..<i], as: UTF8.self)
        if puffer[i] == cr {
            // `\r\n` ist ein Umbruch, nicht zwei. Steht das `\n` noch nicht im Puffer, wird
            // vermerkt, dass es kommen koennte - die Zeile selbst ist trotzdem fertig. Ein
            // einzelnes `\r` beendet nach der Spezifikation auch allein eine Zeile, und darauf
            // zu warten wuerde den Strom anhalten.
            if i + 1 < puffer.count {
                gelesen = puffer[i + 1] == lf ? i + 2 : i + 1
            } else {
                gelesen = i + 1
                letztesWarWagenruecklauf = true
            }
        } else {
            gelesen = i + 1
        }
        return zeile
    }

    /// Gelesene Bytes wegwerfen, wenn sich genug angesammelt hat.
    ///
    /// Ohne das waechst der Puffer um jeden Rahmen, den der Strom je geschickt hat - an einer
    /// Wandanzeige, die Wochen laeuft, sind das Hunderte Megabyte. Die Schwelle verhindert, dass
    /// bei jedem Rahmen ein Feld verschoben wird.
    private mutating func verdichte() {
        guard gelesen > 0 else { return }
        if gelesen == puffer.count {
            puffer.removeAll(keepingCapacity: true)
            gelesen = 0
        } else if gelesen > 16 * 1024 {
            puffer.removeFirst(gelesen)
            gelesen = 0
        }
    }

    /// `feld: wert` zerlegen. Ohne Doppelpunkt ist die ganze Zeile der Feldname mit leerem Wert.
    private func teile(_ zeile: String) -> (String, String) {
        guard let d = zeile.firstIndex(of: ":") else { return (zeile, "") }
        let feld = String(zeile[zeile.startIndex..<d])
        var wert = zeile[zeile.index(after: d)...]
        // Genau ein Leerzeichen nach dem Doppelpunkt gehoert nicht zum Wert.
        if wert.hasPrefix(" ") { wert = wert.dropFirst() }
        return (feld, String(wert))
    }
}
