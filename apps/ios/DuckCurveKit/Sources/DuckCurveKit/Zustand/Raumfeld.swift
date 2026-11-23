import Foundation

// Das Ablesen eines einzelnen Feldes der Tagesmatrix - Vorlage:
// `apps/web/src/components/rooms/RoomsReport.tsx:490`. Dort haengt an jedem der sechsundneunzig
// Felder je Raum ein `title` aus Raum, Uhrzeit und Abweichung, und das ist **die einzige Stelle
// der Karte, an der die Zahl eines Feldes zu lesen ist** - die Farbskala gibt nur fuenf Stufen
// her. Am Geraet gibt es kein Ueberfahren; die Zahl kommt darum aus einer Gestik. Die Woerter
// dazu stehen hier und nicht in der Ansicht, wo sie nicht zu pruefen waeren.

extension Raumabweichung {

    // MARK: - Das Wort zu einem Feld

    /// Das Wort zu einem Feld der Tagesmatrix: die Zahl, „kein Messwert“ oder „noch nicht“.
    ///
    /// **Nicht ``abweichungText(_:)``, und das ist kein Versehen.** Jenes sagt innerhalb des
    /// Bandes „am Ziel“ und beantwortet damit die Frage „wie steht der Raum“ - die richtige
    /// Antwort an einer Kachel. Am einzelnen Feld der Matrix ist die Frage eine andere: die
    /// Flaeche sagt bereits „am Ziel“, denn sie traegt die gedeckte Nullstufe. Wer darauf
    /// greift, will die Zahl. Die Vorlage setzt an dieser Stelle darum `kelvin(d)` und nicht
    /// `abweichungsText(d)` (`RoomsReport.tsx:490` gegen `:538` der Kachelbeschriftung).
    ///
    /// Bei genau null steht „−0,0 K“ - dieselbe Schreibweise wie in der Vorlage, deren
    /// Vorzeichen ebenso an `k > 0` haengt (`palette.ts:56-58`). Eine eigene Regel dafuer
    /// waere eine Abweichung ohne Anlass; gemessene Nullen auf drei Stellen genau gibt es nicht.
    public static func feldwort(_ feld: Feld) -> String {
        switch feld {
        case .nochNicht: return "noch nicht"
        case .keinWert: return "kein Messwert"
        case .wert(let k): return kelvin(k)
        }
    }

    // MARK: - Das Blaettchen ueber einem Feld

    /// Die drei Teile des Blaettchens ueber einem Feld (`RoomsReport.tsx:490`:
    /// `${z.name} · ${hhmm(ts[i])} · ${…}`).
    ///
    /// **Warum drei Zeichenketten und nicht eine.** Die Ansicht setzt sie uebereinander und
    /// gibt ihnen verschiedene Schriften - der Name leiser, die Uhrzeit fuehrend, die Zahl in
    /// der Zahlenschrift; in einer fertigen Zeile mit Trennpunkten waere das nicht mehr
    /// moeglich. Fuer die Vorlesehilfe, die keine Schriften kennt, gibt es ``zeile``.
    /// Zuschnitt wie ``Jahresraster/Zellenhinweis`` (`Zustand/Jahreskarte.swift:216`).
    public struct Feldhinweis: Sendable, Hashable {
        /// Der Name des Raums - die Zeile, in der gegriffen wurde.
        public let raum: String
        /// Der Anfang des Fensters, „07:15“, und `Formate.leer`, wo die Reihe keinen
        /// Zeitstempel hergibt.
        public let zeit: String
        /// Die Abweichung, „kein Messwert“ oder „noch nicht“.
        public let wert: String

        public init(raum: String, zeit: String, wert: String) {
            self.raum = raum
            self.zeit = zeit
            self.wert = wert
        }

        /// Alles in einer Zeile, mit den Trennpunkten der Vorlage - fuer die Vorlesehilfe und
        /// fuer Pruefungen.
        public var zeile: String { [raum, zeit, wert].joined(separator: " · ") }
    }

    /// Was ueber einem Feld steht.
    ///
    /// **Es gibt kein Feld ohne Blaettchen**, anders als bei ``Jahresraster/hinweis(tag:stunde:)``,
    /// das ueber einer leeren Zelle nichts zeigt. Dort hat eine leere Zelle keine Bedeutung,
    /// hier hat sie zwei - „kein Messwert“ und „noch nicht“ -, und gerade sie zu unterscheiden
    /// ist der Zweck der Karte. Ein stummer Griff auf eine schraffierte Viertelstunde waere die
    /// eine Auskunft, die hier fehlt.
    ///
    /// `zeitIso` ist `ts[i]` der Tagesreihe (`Schema.swift:8198`); die Reihe traegt die
    /// Zeitstempel, nicht das Feld.
    public static func feldhinweis(name: String, zeitIso: String?, feld: Feld) -> Feldhinweis {
        Feldhinweis(raum: name, zeit: Formate.hhmm(iso: zeitIso), wert: feldwort(feld))
    }

    /// Was die Vorlesehilfe ueber eine ganze Zeile der Matrix sagt.
    ///
    /// **Die Vorlage braucht das nicht, weil sie den Satz an jedes Feld haengt** - eine
    /// Vorlesehilfe liest aber keine sechsundneunzig Felder vor, und eine Gestik hat sie nicht.
    /// Also die Zeile in einem Satz, und zwar mit den beiden Angaben, die ohne Augen sonst
    /// verloren sind: dem Tagesmittel, das als Zahl ohnehin dasteht, und der Zahl der stummen
    /// Fenster - das ist genau, was die Schraffur zeigt.
    ///
    /// Gezaehlt werden nur die stummen, nicht die kuenftigen: dass der Nachmittag noch nicht
    /// gewesen ist, ist keine Auskunft ueber den Raum.
    public static func matrixzeilenwort(name: String, felder: [Feld]) -> String {
        var teile = [name]
        if let m = mittel(felder) {
            teile.append("im Tagesmittel " + kelvin(m))
        } else {
            teile.append("kein Messwert")
        }
        let stumm = felder.filter { $0 == .keinWert }.count
        if stumm > 0 {
            teile.append("\(stumm) von \(felder.count) Werten \(stumm == 1 ? "fehlt" : "fehlen")")
        }
        return teile.joined(separator: " · ")
    }

    // MARK: - Bis wohin der laufende Tag gemessen ist

    /// Der Zeitpunkt, bis zu dem ein laufender Tag gemessen ist - **aus der Antwort, nicht von
    /// einer Uhr**.
    ///
    /// Die Vorlage nimmt `new Date(live.at)` und faellt erst ohne Istwerte auf die eigene Uhr
    /// zurueck (`RoomsReport.tsx:367-373`), mit der Begruendung im Kommentar: im Vorfuehrbetrieb
    /// laeuft die Uhr des Dienstes im Zeitraffer, und eine fremde Uhr zoege dort eine Grenze,
    /// die mit den Daten nichts zu tun hat. Die Hauszeit der App folgt derselben Uhr - aber nur,
    /// solange der Ereignisstrom laeuft; bei der Erstladung steht ihr Versatz auf null, und dann
    /// ist es die Geraeteuhr (`Hauszustand.swift:214-218`). Die Antwort weiss es immer.
    ///
    /// Das Ergebnis geht in ``gewesen(tag:jetzt:schrittMin:)``; ein vergangener oder kuenftiger
    /// Tag entscheidet sich dort und nicht hier.
    public static func gemessenBis(live: RoomsLiveOut?, jetzt: Date) -> Date {
        guard let live, let gemessen = Zeit.ausIso(live.at) else { return jetzt }
        return gemessen
    }
}
