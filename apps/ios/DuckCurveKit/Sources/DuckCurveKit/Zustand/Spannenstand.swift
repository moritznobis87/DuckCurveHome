import Foundation

// `URLError` liegt auf Linux in FoundationNetworking, auf Apple-Geräten in Foundation.
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Der Takt, in dem eine Berichtsseite und ihr Spannenstreifen nachholen: fünf Minuten.
///
/// **Eine Zahl, zwei Zustände.** Die Vorlage hat sie einmal (`useReport.ts:7`:
/// `REFRESH_MS = 5 * 60_000`) und benutzt sie an zwei Stellen: für den Bericht der gewählten
/// Spanne (`:39`) und für die vier Spannen des Streifens (`:70`). Seit der Streifen in der App
/// ein eigener Zustand ist, gibt es hier ebenfalls zwei Schleifen - und zwei Mal „300“ im Code
/// wären zwei Mal die Gelegenheit, es verschieden zu tun.
public enum Berichtstakt {
    public static let nachladen: Duration = .seconds(300)
}

/// Die vier Spannen zu **einem** Anker, mit dem, was von ihnen angekommen ist.
///
/// **Warum der Spannenstreifen einen eigenen Zustand braucht.** Die sieben Seiten mit dem
/// Streifen holten ihn als Teil ihrer Antwort: Tag, Woche, Monat und Jahr lagen in demselben
/// Verbund wie die Zahlen der gewählten Spanne, und ``Berichtsseite`` zeichnet erst, wenn die
/// ganze Antwort da ist. Damit hing jede dieser Seiten an ihrer langsamsten Abfrage, und das
/// war immer die Monatsspalte des Streifens - in der Vorführung 4227 ms statt 625 ms. Die
/// Vorlage hält die beiden getrennt (`useReport.ts`: `useReport` für den Bericht,
/// `useMultiPeriod` für die vier Spannen, jeder mit eigenem Zustand) und zeichnet den Streifen
/// mit Strichen, solange seine Zahlen fehlen (`HeatOverview.tsx:118-131` über `alle[x]`, das
/// als `{}` anfängt).
///
/// **Der Stand trägt seinen Anker mit sich.** Ohne ihn stünden beim Blättern die Zahlen des
/// alten Tages unter dem Kopf des neuen: die Seite zeichnet einen Umlauf, bevor der Streifen
/// nachgeladen hat. ``fuer(_:)`` beantwortet genau diese Frage - gehört dieser Stand noch zu
/// dem Tag, der oben in der Blätterleiste steht?
///
/// **Die gewählte Spanne wird zweimal geholt, und das bleibt so.** Die Seite holt sie als ihre
/// Antwort, der Streifen als eine seiner vier Spalten - bei einem Ankerwechsel also fünf
/// Abfragen für vier verschiedene Zeiträume. Die Vorlage macht es genauso (`useReport` und
/// `useMultiPeriod` nebeneinander, beide mit derselben Spanne darin), und der Grund ist nicht
/// Nachlässigkeit: die eine Abfrage zu sparen heißt, eine der beiden auf die andere warten zu
/// lassen. Nimmt der Streifen seine Spalte aus der Antwort der Seite, muss er wissen, welche
/// Spanne gewählt ist - und hängt damit wieder am Zeitraum: dann kostet jeder Spannenwechsel
/// vier Abfragen statt jeder Ankerwechsel eine. Nimmt die Seite ihre Zahlen aus dem Streifen,
/// wartet sie auf alle vier. Die doppelte Abfrage ist die billigste der drei Möglichkeiten -
/// und für den Dienst ist sie zweimal dieselbe Frage, also das, was ein Zwischenspeicher dort
/// beim zweiten Mal umsonst beantwortet.
///
/// **Eine fehlende Spalte ist kein Fehler, vier fehlende schon.** Jede Spanne wird für sich
/// geholt und darf für sich scheitern - dafür steht in der Vorlage `Promise.allSettled`
/// (`useReport.ts:61`): der Lauf bricht nicht ab, wenn eine Spanne wirft. Was `allSettled`
/// *nicht* sagt, ist, dass die alte Zahl dann stehen bleibt - die Vorlage baut in jedem Lauf ein
/// frisches `next` und ersetzt damit den ganzen Stand (`:63-67`), eine diesmal aussetzende
/// Spanne fällt dort also auf einen Strich. Dass sie hier ihre vorige Zahl behält, ist eine
/// Zutat dieser App; der Grund steht an ``nachgeholt(zu:_:)``. Antwortet aber
/// *keine* der vier, stünde ein Streifen aus lauter Strichen da, ohne zu sagen, warum; dann
/// trägt ``fehler`` den Grund, und die Seite zeigt ihn als Band neben allem, was schon dasteht
/// (``Berichtsseite/nebenfehler``). Das Band der Seite bleibt davon unberührt: zwei Zustände,
/// zwei Fehlerwege.
public struct Spannenstand<Wert: Sendable>: Sendable {
    /// Der Ankertag, zu dem die Spalten gehören. Leer, solange nichts geholt wurde.
    public let anker: String
    /// Was angekommen ist. Was fehlt, zeichnen die Streifenzeilen als Strich.
    public let werte: [Spanne: Wert]
    /// Der Fehler **des Streifens** - nur gesetzt, wenn keine der vier Spannen antwortete.
    public let fehler: ApiFehler?

    public init(anker: String = "", werte: [Spanne: Wert] = [:], fehler: ApiFehler? = nil) {
        self.anker = anker
        self.werte = werte
        self.fehler = fehler
    }

    /// Dieser Stand, wenn er zu diesem Anker gehört - sonst ein leerer für ihn.
    ///
    /// Die Seite fragt damit beim Zeichnen, nicht beim Holen: der Streifen eines vergangenen
    /// Tages darf nicht unter dem Kopf des neuen stehen, auch nicht für den einen Umlauf
    /// zwischen Blättern und Nachladen.
    ///
    /// **Hier weicht die App bewusst von der Vorlage ab.** `useMultiPeriod` legt seinen Stand
    /// einmal an und ersetzt ihn erst, wenn die neuen Ergebnisse da sind (`useReport.ts:56` und
    /// `:67`) - beim Blättern stehen dort also die Zahlen des **alten** Ankers weiter, unter dem
    /// Kopf des neuen. Diese App zeigt lieber vier Striche: eine Zahl unter dem falschen Tag ist
    /// schlechter als keine. Der Preis ist, dass die Hausregel von ``Berichtsseite`` - das Alte
    /// bleibt abgedunkelt stehen, bis das Neue da ist - an dieser einen Karte nicht gilt; sie
    /// fällt beim Blättern auf Striche und füllt sich wieder.
    ///
    /// Wer das Flackern doch loswerden will, hat den Hebel hier: die alten Spalten mit ihrem
    /// eigenen Anker weiterzeichnen und abdunkeln, statt sie zu verwerfen - dann muss der
    /// Spaltenkopf mitwandern, und das ist die Arbeit, die dahinter steckt.
    public func fuer(_ anker: String) -> Spannenstand<Wert> {
        self.anker == anker ? self : Spannenstand(anker: anker)
    }

    /// Dieselbe Abfrage für Tag, Woche, Monat und Jahr zum selben Anker, nebenläufig.
    ///
    /// **Was dasteht, bleibt stehen.** Beim Nachholen im Fünf-Minuten-Takt wird nur ersetzt,
    /// was diesmal geantwortet hat; eine Spanne, die aussetzt, behält ihre Zahl aus dem Lauf
    /// davor.
    /// Das ist dieselbe Regel, nach der ``Berichtsseite`` ihre Antwort hält - eine Spalte, die
    /// bei jedem Aussetzer zum Strich wird, flackert an einer Wandanzeige.
    ///
    /// Wechselt der Anker, fängt der Stand leer an: die Zahlen des alten Tages sind für den
    /// neuen keine Auskunft.
    public func nachgeholt(
        zu anker: String,
        _ eine: @Sendable @escaping (Spanne) async throws -> Wert
    ) async -> Spannenstand<Wert> {
        var werte = fuer(anker).werte
        var grund: ApiFehler?
        await withTaskGroup(of: (Spanne, Wert?, ApiFehler?).self) { gruppe in
            for s in Spanne.allCases {
                gruppe.addTask {
                    do {
                        return (s, try await eine(s), nil)
                    } catch {
                        return (s, nil, Self.gedeutet(error))
                    }
                }
            }
            for await (s, wert, fehler) in gruppe {
                if let wert { werte[s] = wert }
                if grund == nil { grund = fehler }
            }
        }
        // Ein abgebrochener Lauf ist kein Fehlschlag: beim Blättern bricht der vorige Lauf ab,
        // und „Keine Verbindung zum Haus“ wäre dort eine Falschmeldung.
        let melden = werte.isEmpty && !Task.isCancelled
        return Spannenstand(anker: anker, werte: werte, fehler: melden ? grund : nil)
    }

    /// Einen fertigen Lauf übernehmen - außer sein Anker gilt nicht mehr.
    ///
    /// **Warum das Schreiben eine eigene Entscheidung ist.** ``nachgeholt(zu:_:)`` ist ein
    /// Lesen-Rechnen-Schreiben über ein `await`: sie liest den Stand am Anfang und gibt am Ende
    /// einen ganzen neuen zurück. Wer ihn dann ungeprüft in den Zustand der Seite legt, legt
    /// unter Umständen einen vergangenen Anker über den gegenwärtigen - und ``fuer(_:)`` zeigt
    /// beim Zeichnen daraufhin einen **leeren** Stand: vier Striche, kein Fehler, also auch kein
    /// Band und kein Knopf mehr, bis der Fünf-Minuten-Takt wieder zieht.
    ///
    /// Der Weg dorthin ist der Knopf „Noch einmal“ am Fehlerband. Er startet seinen Lauf neben
    /// `.task(id:)` der Seite, und was neben ihr läuft, bricht beim Blättern nicht ab: der alte
    /// Lauf kommt nach dem neuen zurück - die Monatsspalte ist gemessen die langsamste - und
    /// schreibt zuletzt. Ein abgebrochener Lauf des Takts tut dasselbe, nur kommt er früher
    /// zurück und wird vom neuen überschrieben; gezählt hat man sich darauf nicht verlassen
    /// wollen.
    ///
    /// Die Seite fragt deshalb beim Schreiben noch einmal, welcher Anker gerade oben steht, und
    /// verwirft, was zu einem anderen gehört. Ein verworfener Lauf kostet nichts: der Anker, zu
    /// dem er gehörte, wird neu geholt, sobald er wieder oben steht.
    public mutating func uebernimm(_ neu: Spannenstand<Wert>, zu anker: String) {
        guard neu.anker == anker else { return }
        self = neu
    }

    /// Aus einem geworfenen Fehler wird einer, der einen Satz für Menschen trägt - oder keiner.
    ///
    /// **Dass beim Blättern kein Band erscheint, trägt nicht dieser Zweig.** Ein abgebrochener
    /// Netzlauf wirft keinen `CancellationError`, sondern `URLError(.cancelled)` - beide stehen
    /// hier, aber was die Falschmeldung „Keine Verbindung zum Haus“ wirklich verhindert, ist
    /// `!Task.isCancelled` am Ende von ``nachgeholt(zu:_:)``: wurde die Aufgabe der Seite
    /// abgebrochen, wird gar nichts gemeldet, gleich welchen Fehler die vier Spalten geworfen
    /// haben. Die beiden Zweige hier sind der Gürtel dazu, für eigene Abbrüche und für den Fall,
    /// dass ein einzelner Lauf abbricht, während die Aufgabe weiterläuft.
    private static func gedeutet(_ fehler: any Error) -> ApiFehler? {
        if fehler is CancellationError { return nil }
        if let f = fehler as? URLError, f.code == .cancelled { return nil }
        if let f = fehler as? ApiFehler { return f }
        return .netz(fehler.localizedDescription)
    }
}
