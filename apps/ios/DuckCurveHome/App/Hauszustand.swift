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
/// **Aber zwei Uhren, nicht eine** - siehe ``Hausuhr`` im Kern, wo die Regel samt Messung steht.
/// ``jetzt`` ist die Uhr der *Daten* (in ihr sind alle Zeitstempel geschrieben), ``wanduhr`` die
/// Uhr, die ein Mensch gross auf dem Bild liest und gegen die Statusleiste seines iPads haelt.
/// Hier war beides dasselbe, und eine um drei Minuten nachgehende Dienstuhr stand damit als
/// `22:04` auf der Wand, einen Zentimeter unter dem `22:07` des Geraets - bei `LIVE`.
///
/// **Ein unlesbarer Zeitstempel darf den Versatz nicht vergiften.** Aus `NaN` wird sonst
/// ueberall „Invalid Date", und der naechste gute Rahmen macht den einmal weggeschriebenen Tag
/// nicht wieder gut. Das prueft ``Hausuhr`` mit.
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
    /// Die beiden Uhren des Hauses und die Regel, die sie trennt. Siehe ``Hausuhr``.
    fileprivate(set) var uhr = Hausuhr()

    /// Serverzeit minus Geraetezeit - der **rohe gemessene** Abstand der beiden Uhren.
    ///
    /// Steht als eigene Zahl auf der Zugangsseite („Zeitversatz zum Dienst", eine
    /// Dezimalstelle): sie ist die Diagnose, mit der man eine wandernde Maschinenuhr findet,
    /// *bevor* sie drei Minuten erreicht. Darum darf hier nie eine unterdrueckte Zahl stehen -
    /// ``Hausuhr/versatz`` kennt keine Schwelle, nur ``Hausuhr/befund`` kennt eine.
    var versatz: TimeInterval { uhr.versatz }

    // MARK: - Zugang

    var zugang: Zugang {
        didSet {
            guard zugang != oldValue else { return }
            api = Api(zugang: zugang)
            Task { await strom?.setze(zugang: zugang) }
        }
    }

    /// Ob sich hier jemand abgemeldet hat und die Anmeldung wieder ansteht
    /// (``Schluesselbund/abgemeldet``). Dann zeigt die App das Einrichten statt der Seiten.
    var abgemeldet = Schluesselbund.abgemeldet {
        didSet { Schluesselbund.abgemeldet = abgemeldet }
    }

    /// Die angemeldete Person abmelden: die Sitzung beim Dienst beenden, das Sitzungstoken aus
    /// dem Schlüsselbund nehmen, den Ereignisstrom schließen.
    ///
    /// Antwortet der Dienst nicht, geht das Token trotzdem weg: wer sich abmelden wollte, ist
    /// an diesem Gerät abgemeldet, und die Sitzung läuft dann von selbst ab. Adresse und
    /// Gerätename bleiben, damit die nächste Anmeldung sie vorfindet.
    func meldeAb() async {
        try? await api.meldeAb()
        halte()
        var ohne = zugang
        ohne.token = ""
        ohne.email = ""
        ohne.rolle = .gast
        Schluesselbund.speichere(ohne)
        zugang = ohne
        abgemeldet = true
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
        // Die Uhr des Beispielhauses steht auf dem Nachmittag, zu dem die Zahlen passen - beide
        // Uhren, sonst stuende in der Vorschau die halbe Uhrzeit von jetzt neben den Zahlen
        // von 14:35.
        h.uhr = Hausuhr(vorgestellt: Vorschau.jetzt.timeIntervalSince(Date()))
        return h
    }

    // MARK: - Die Zeit des Hauses

    /// Jetzt, nach der Uhr des Hauses. Die Uhr der **Daten** - immer die des Dienstes.
    ///
    /// Alle Zeitstempel aus dem Dienst sind in seiner Uhr geschrieben - `observed_at`, die
    /// Fahrplanfenster, der Kalendertag, nach dem ``ladeTag(_:)`` fragt. Alter, Fensterlage und
    /// Tagesgrenze werden mit dieser Uhr richtig und mit der Geraeteuhr falsch. Wer eine Uhrzeit
    /// *hinschreibt*, nimmt dagegen ``wanduhr``.
    ///
    /// **Ohne Ausnahme, und das ist mit Absicht wieder so.** Eine Zwischenfassung liess diese
    /// Uhr in einem Band um die Geraeteuhr herum auf *diese* zurueckfallen. Das aenderte die
    /// Bedeutung fuer rund siebzig Leser in 27 Dateien, ohne dass einer davon es erfuhr: an der
    /// Tagesgrenze kippte ``heute`` zur Geraete-Mitternacht, und bis zu 72 s lang verwarf das
    /// Tor `raster.tag == heute` weiter unten frische Messwerte. Die Begruendung und die
    /// Gegenrechnung stehen in ``Hausuhr``.
    var jetzt: Date {
        uhr.datenzeit()
    }

    /// Jetzt, wie es gross auf der Wand steht - die Uhr, die ein Mensch gegen seine eigene prueft.
    ///
    /// Im Live-Betrieb die des Geraets, im Vorfuehrbetrieb die des Zeitraffers. Die Begruendung
    /// und die Messung stehen in ``Hausuhr``.
    var wanduhr: Date {
        uhr.anzeigezeit()
    }

    /// Der laufende Kalendertag des Hauses.
    ///
    /// Der des **Dienstes**, nicht der der Wand: nach diesem Tag wird der Verlauf abgefragt und
    /// an diesem Tag entscheidet ``setze(_:)``, ob ein frischer Messwert noch ins Raster darf.
    var heute: String {
        Tag.iso(jetzt)
    }

    /// Gehen die Uhren von Dienst und Geraet auseinander? Dann steht das in der Wache.
    var uhrbefunde: [Wachbefunde.Zeile] {
        [uhr.befund].compactMap { $0 }
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
                    self.setzeVerbindung(.verbindetNeu)
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
        setzeVerbindung(.aus)
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
            setzeVersatz(serverzeit, betrieb: betrieb)
            if verbindung != .live { verbindung = .live }
        case .verbindung(let v):
            setzeVerbindung(v)
            if v == .live { fehler = nil }
        case .fehler(let f):
            // Ein Netzfehler ist keine Nachricht fuer den Benutzer, solange der Strom es weiter
            // versucht. Ein falsches Token ist eine.
            if !f.lohntWiederholung { fehler = f }
        }
    }

    private func setze(_ z: LiveStateOut) {
        letzterRahmen = Date()
        // **Der Modus kommt aus diesem Rahmen, nicht aus dem vorigen.** Beim ersten
        // Augenblicksbild gibt es keinen vorigen, und ohne Modus stellt ``Hausuhr`` nichts -
        // die Vorfuehrung stuende dann bis zum naechsten Rahmen auf dem falschen Tag.
        if let serverzeit = Zeit.ausIso(z.system.serverTime) {
            setzeVersatz(serverzeit, betrieb: Self.betrieb(z.system))
        }
        zustand = z
        setzeVerbindung(.live)
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

    private func setzeVersatz(_ serverzeit: Date, betrieb: Hausuhr.Betrieb) {
        uhr.melde(serverzeit: serverzeit, betrieb: betrieb)
    }

    /// In welchem Betrieb der Dienst laeuft, soweit die App es schon weiss.
    ///
    /// Ohne Zustand kein Modus: ein Herzschlag kann dem ersten Augenblicksbild zuvorkommen, und
    /// dann ist nicht entscheidbar, ob ein Versatz der Zweck (Zeitraffer) oder ein Fehler
    /// (falsch gestellte Uhr) ist. ``Hausuhr`` wartet in diesem Fall.
    private var betrieb: Hausuhr.Betrieb { Self.betrieb(zustand?.system) }

    /// **Das Tempo gehoert dazu, nicht nur die Betriebsart.** `sim_speed = 0` haelt die
    /// Vorfuehrung an, ohne die Verbindung zu loesen - ``Hausuhr`` braucht die Zahl, um eine
    /// stehende Uhr von einer rueckwaerts zeigenden zu unterscheiden. Sie steht in demselben
    /// Rahmen wie `mode` und `server_time`, es ist also kein zweiter Abruf.
    private static func betrieb(_ system: SystemStatusOut?) -> Hausuhr.Betrieb {
        guard let system else { return .unbekannt }
        return system.mode == "demo" ? .vorfuehrung(tempo: system.simSpeed) : .live
    }

    /// Die Verbindung umschalten - und der Uhr sagen, wenn sie weg war.
    ///
    /// **Warum die Uhr das wissen muss.** Ein neu gestarteter Vorfuehrdienst faengt seinen Tag
    /// von vorn an. Die Regel „die Anzeigeuhr geht nie rueckwaerts" wuerde sie danach fuer die
    /// Laenge des Vorfuehrtags einfrieren; der Abriss ist die einzige Stelle, an der ein
    /// Rueckschritt erklaerbar ist und darum erlaubt bleibt.
    private func setzeVerbindung(_ neu: Verbindung) {
        if neu != .live { uhr.abgerissen() }
        verbindung = neu
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
            // Eine Uhrzeit fuer einen Menschen, also die Wanduhr: `letzterRahmen` ist nach
            // der Geraeteuhr gestempelt, und mit dem Versatz einer falsch gestellten Dienstuhr
            // stand hier eine Minute, die es auf keiner der beiden Uhren je gab.
            return "unterbrochen · \(Formate.hhmm(uhr.anzeigezeit(letzter)))"
        case .aus:
            return fehler == nil ? "angehalten" : "nicht verbunden"
        }
    }

    /// Läuft die Anwendung im Vorführbetrieb? Dann ist jede Zahl erfunden.
    var vorfuehrung: Bool { zustand?.system.mode == "demo" }

    /// Ob dieser Zugang schalten darf. Blendet aus, sperrt nicht - siehe `Zugang`.
    var darfSchalten: Bool { zugang.rolle == .hausherr }
}
