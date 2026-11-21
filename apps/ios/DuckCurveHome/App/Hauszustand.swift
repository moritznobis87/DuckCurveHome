import DuckCurveKit
import Observation
import SwiftUI

/// Was die App vom Haus weiss.
///
/// Das Gegenstueck zu `apps/web/src/lib/live/store.ts`, mit demselben Zuschnitt: ein Augenblick,
/// ein Plan, die letzten Entscheidungen, ein Minutenraster und der Zustand der Verbindung. Alles
/// darueber hinaus - Berichte, Raeume, Rechnungen - holt die Seite, die es braucht, und legt es
/// nicht hier ab. Ein Zustandsspeicher, in dem 64 Endpunkte liegen, ist ein zweites Backend.
///
/// **Die Zeit des Hauses, nicht die des Geraets.** Jeder Rahmen traegt die Serverzeit, und daraus
/// wird ein Versatz. Das klingt nach Kleinigkeit und ist keine: im Demo-Betrieb laeuft die Uhr
/// des Dienstes im Zeitraffer, und die Anzeige muss dann *seinem* Tag folgen. Der Kommentar in
/// `sseClient.ts` erzaehlt, was sonst passiert - die Startseite las „Invalid Date", beide
/// Diagramme blieben leer, und der Speicher hing keine Live-Werte mehr an.
///
/// **Ein unlesbarer Zeitstempel darf den Versatz nicht vergiften.** Aus `NaN` wird sonst
/// ueberall „Invalid Date", und der naechste gute Rahmen macht den einmal weggeschriebenen Tag
/// nicht wieder gut.
@MainActor
@Observable
final class Hauszustand {
    // MARK: - Was da ist

    var zustand: LiveStateOut?
    var plan: PlanOut?
    var entscheidungen: [Decision] = []
    var raster = Minutenraster()
    var verbindung: Verbindung = .verbindet
    /// Der letzte Fehler, der nicht von selbst weggeht - etwa ein falsches Token.
    var fehler: ApiFehler?

    /// Wann der letzte Rahmen kam, nach der Uhr des Geraets.
    fileprivate(set) var letzterRahmen: Date?
    /// Serverzeit minus Geraetezeit.
    fileprivate(set) var versatz: TimeInterval = 0

    // MARK: - Zugang

    var zugang: Zugang {
        didSet {
            guard zugang != oldValue else { return }
            api = Api(zugang: zugang)
            Task { await strom?.setze(zugang: zugang) }
        }
    }

    private(set) var api: Api
    private var strom: LiveStrom?
    private var horcher: Task<Void, Never>?
    private var aufsicht: Task<Void, Never>?

    /// Nur fuer Vorschauen: dieser Zustand verbindet sich nicht.
    ///
    /// Ohne das haengt jede SwiftUI-Vorschau an einem Netz, das es im Vorschaufenster nicht
    /// gibt, und zeigt bestenfalls „Wird geholt …". Xcode baut Vorschauen bei jedem Tastendruck
    /// neu - eine, die eine Sekunde auf einen Zeitablauf wartet, ist keine.
    private let nurVorschau: Bool

    init(zugang: Zugang, nurVorschau: Bool = false) {
        self.zugang = zugang
        self.api = Api(zugang: zugang)
        self.nurVorschau = nurVorschau
    }

    /// Ein Haus mit Beispieldaten, fuer die Vorschauen in Xcode.
    ///
    /// Die Werte kommen aus `Vorschau` im Kern - denselben, mit denen auch die Tests rechnen.
    /// Das ist der Grund, warum sie dort und nicht hier stehen: ein Beispielhaus, das nur in
    /// Vorschauen vorkommt, veraltet still, sobald sich ein Feld des Schemas aendert. Eines, das
    /// in 211 Tests mitlaeuft, nicht.
    @MainActor
    static func vorschau(
        pv: Double? = 4.2, laeuft: Bool = true, tag: String = "2026-02-24"
    ) -> Hauszustand {
        let h = Hauszustand(zugang: Vorschau.zugang, nurVorschau: true)
        h.zustand = Vorschau.liveZustand(pv: pv, laeuft: laeuft)
        h.plan = Vorschau.plan(
            ab: Tag.zeitraum(tag)?.von ?? Vorschau.jetzt,
            fenster: [
                Vorschau.fenster("\(tag)T11:00:00+01:00", "\(tag)T14:00:00+01:00", .cheap)
            ]
        )
        h.raster = Vorschau.minutenraster(tag: tag)
        h.verbindung = .live
        h.letzterRahmen = Date()
        // Die Uhr des Beispielhauses steht auf dem Nachmittag, zu dem die Zahlen passen.
        h.versatz = Vorschau.jetzt.timeIntervalSince(Date())
        return h
    }

    // MARK: - Die Zeit des Hauses

    /// Jetzt, nach der Uhr des Hauses.
    var jetzt: Date {
        Date().addingTimeInterval(versatz)
    }

    /// Der laufende Kalendertag des Hauses.
    var heute: String {
        Tag.iso(jetzt)
    }

    // MARK: - Verbinden

    /// Den Ereignisstrom oeffnen und die Erstladung anstossen.
    func starte() {
        guard !nurVorschau else { return }
        guard zugang.istEingerichtet else { return }
        guard horcher == nil else { return }
        let strom = LiveStrom(zugang: zugang)
        self.strom = strom
        horcher = Task { [weak self] in
            for await nachricht in await strom.nachrichten() {
                guard let self else { return }
                await self.nimm(nachricht)
            }
        }
        aufsicht = Task { [weak self] in
            // Die Aufsicht sieht alle fuenf Sekunden nach, ob noch Rahmen kommen. Sie greift
            // nicht ein - das tut der Strom von sich aus -, sie sagt es nur der Anzeige, damit
            // der Punkt im Kopf umschaltet, bevor der naechste Versuch laeuft.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { return }
                if Verbindungspolitik.istVerstummt(letzterRahmen: self.letzterRahmen, jetzt: Date()),
                   self.verbindung == .live
                {
                    self.verbindung = .verbindetNeu
                }
            }
        }
        Task { await ersteLadung() }
    }

    func halte() {
        horcher?.cancel()
        aufsicht?.cancel()
        horcher = nil
        aufsicht = nil
        Task { [strom] in await strom?.halte() }
        strom = nil
    }

    /// Die App ist weggelegt worden.
    func beimWegbleiben() {
        Task { await strom?.beimWegbleiben() }
        aufsicht?.cancel()
        aufsicht = nil
        verbindung = .aus
    }

    /// Sie ist wieder da. Sofort verbinden, ohne Wartezeit - der Benutzer sieht hin.
    func beimZurueckkommen() {
        guard !nurVorschau else { return }
        guard zugang.istEingerichtet else { return }
        if horcher == nil {
            starte()
        } else {
            Task { await strom?.beimZurueckkommen() }
            Task { await ersteLadung() }
        }
    }

    // MARK: - Nachrichten aus dem Strom

    private func nimm(_ nachricht: Stromnachricht) async {
        switch nachricht {
        case .zustand(let z):
            setze(z)
        case .entscheidung(let e):
            // Dieselbe Entscheidung kommt zweimal: einmal im Augenblicksbild, einmal als eigenes
            // Ereignis. Die Liste soll sie einmal haben.
            if entscheidungen.first?.id != e.id || e.id == nil {
                entscheidungen.insert(e, at: 0)
                if entscheidungen.count > 50 { entscheidungen.removeLast(entscheidungen.count - 50) }
            }
        case .plan(let p):
            plan = p
        case .herzschlag(let serverzeit):
            letzterRahmen = Date()
            setzeVersatz(serverzeit)
            if verbindung != .live { verbindung = .live }
        case .verbindung(let v):
            verbindung = v
            if v == .live { fehler = nil }
        case .fehler(let f):
            // Ein Netzfehler ist keine Nachricht fuer den Benutzer, solange der Strom es weiter
            // versucht. Ein falsches Token ist eine.
            if !f.lohntWiederholung { fehler = f }
        }
    }

    private func setze(_ z: LiveStateOut) {
        letzterRahmen = Date()
        if let serverzeit = Zeit.ausIso(z.system.serverTime) {
            setzeVersatz(serverzeit)
        }
        zustand = z
        verbindung = .live
        fehler = nil
        if let e = z.decision, entscheidungen.first?.id != e.id {
            entscheidungen.insert(e, at: 0)
            if entscheidungen.count > 50 { entscheidungen.removeLast(entscheidungen.count - 50) }
        }
        // Live-Werte nur an den laufenden Tag anhaengen. Ein vergangener Tag ist abgeschlossen;
        // ein frischer Messwert gehoert dort nicht hinein. Maßgeblich ist der Tag des Servers.
        if raster.tag == heute {
            raster.schreibeFort(z)
        }
    }

    private func setzeVersatz(_ serverzeit: Date) {
        let neu = serverzeit.timeIntervalSince(Date())
        guard neu.isFinite else { return }
        versatz = neu
    }

    // MARK: - Erstladung

    /// Zustand, Verlauf und Plan nach jeder (Wieder-)Verbindung holen.
    ///
    /// **Nur, wenn die Ansicht auf dem laufenden Tag steht.** Diese Funktion laeuft nach *jeder*
    /// Wiederverbindung, und die Aufsicht erzwingt eine, sobald fuenfzehn Sekunden kein Rahmen
    /// kam. Wer gerade den 12. Oktober liest, soll davon nichts merken.
    func ersteLadung() async {
        guard !nurVorschau else { return }
        async let zustandHolen = try? api.liveZustand()
        async let planHolen = try? api.plan()

        // Der Zustand zuerst: er setzt den Versatz zum Server, und ohne den ist „heute" geraten.
        if let z = await zustandHolen {
            setze(z)
        }
        if let p = await planHolen {
            plan = p
        }
        let tagJetzt = heute
        if raster.tag.isEmpty || raster.tag == tagJetzt {
            if let h = try? await api.verlauf(.heute) {
                raster.setze(h, tag: tagJetzt)
            }
        }
    }

    /// Den Verlauf eines beliebigen Tages laden - fuer das Blaettern.
    func ladeTag(_ tag: String) async {
        guard Tag.istTag(tag) else { return }
        guard let h = try? await api.verlaufTag(tag) else { return }
        raster.setze(h, tag: tag)
    }

    // MARK: - Abkuerzungen, die die Seiten oft brauchen

    var augenblick: EnergySnapshot? { zustand?.snapshot }

    /// Ist die Verbindung in Ordnung? Die Anzeige daempft sich, wenn nicht.
    var gestoert: Bool { verbindung != .live }

    /// Ist noch gar nichts da? Das ist die Frage, an der der Ladeschirm haengt.
    ///
    /// **Das Augenblicksbild ist das Mass, nicht der Verbindungszustand.** `verbindung == .live`
    /// sagt, dass der Strom offen ist - nicht, dass eine Zahl angekommen ist; zwischen beidem
    /// liegt im ruhigen Haus bis zu eine Sekunde. Und es ist auch nicht `raster` oder `plan`:
    /// beide duerfen dauerhaft leer bleiben (ein Haus ohne Photovoltaik hat keine Prognose), ein
    /// Ladeschirm, der auf sie wartet, wartete dort fuer immer.
    ///
    /// Es ist dieselbe Bedingung, an der schon ``satz`` entscheidet, ob er „Verbinde mit dem
    /// Haus …“ sagt - nur unter einem Namen, damit die beiden Stellen nicht auseinanderlaufen.
    var nochKeineZahlen: Bool { zustand == nil }

    /// Der Satz, der auf der Startseite steht.
    ///
    /// Die Erklaerung des Reglers, wenn es eine gibt. Sonst zwei Saetze, die nicht nach einem
    /// Fehler klingen: ein Haus, das gerade erst verbunden ist, hat noch nicht entschieden.
    var satz: String {
        if let e = zustand?.decision?.explanationDe, !e.isEmpty { return e }
        if zustand != nil { return "Das Haus ist da, die erste Entscheidung steht noch aus." }
        return "Verbinde mit dem Haus …"
    }

    /// Was unter dem Satz steht: wer gerade entscheidet.
    var betriebswort: String {
        guard let m = zustand?.operatingMode else { return "" }
        if let ue = m.override {
            return "von Hand bis \(Formate.hhmm(iso: ue.endsAt))"
        }
        if m.systemMode == .off { return "Automatik aus, Duck Curve schaut nur zu" }
        return "Automatik"
    }

    /// Das Wort neben dem Lebenspunkt: „live", „demo 60×", „unterbrochen · 23:35".
    ///
    /// **Warum hier und nicht in der Ansicht.** Zwei Stellen zeigen es - der Kopf der
    /// Wandanzeige und das Ruhebild - und sie sollen nie verschiedene Wörter sagen.
    var verbindungswort: String {
        switch verbindung {
        case .live:
            guard let s = zustand?.system else { return "live" }
            if s.mode == "demo" {
                return s.simSpeed != 1 ? "demo \(Formate.zahl(s.simSpeed, stellen: 0))×" : "demo"
            }
            return "live"
        case .verbindet:
            return "verbinde"
        case .verbindetNeu:
            guard let letzter = letzterRahmen else { return "verbinde" }
            return "unterbrochen · \(Formate.hhmm(letzter.addingTimeInterval(versatz)))"
        case .aus:
            return fehler == nil ? "angehalten" : "nicht verbunden"
        }
    }

    /// Läuft die Anwendung im Vorführbetrieb? Dann ist jede Zahl erfunden.
    var vorfuehrung: Bool { zustand?.system.mode == "demo" }

    /// Ob dieser Zugang schalten darf. Blendet aus, sperrt nicht - siehe `Zugang`.
    var darfSchalten: Bool { zugang.rolle == .hausherr }
}
