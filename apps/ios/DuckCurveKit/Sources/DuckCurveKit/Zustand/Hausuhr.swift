import Foundation

/// Welche Uhr die Anzeige zeigt - und wann ein Zeitstempel aus dem Netz sie stellen darf.
///
/// **Der Anlass, nachgemessen.** Ein Foto der Wandanzeige (Ruhebild) zeigt in der grossen Uhr
/// `22:04`, waehrend die Statusleiste desselben iPads `22:07` zeigt; oben rechts stand `LIVE`.
/// Die Kette dahinter war kurz und ohne eine einzige Schranke: `system.server_time` aus dem
/// Rahmen, daraus `versatz = serverzeit - Date()`, daraus `Date() + versatz` - und das stand
/// gross auf der Wand, einen Zentimeter unter der Uhr des Geraets. Nachgemessen am laufenden
/// Dienst liegt `server_time` 0,003 s bzw. 0,12 s hinter `datetime.now(UTC)` (die Dauer der
/// Anfrage), und `snapshot.timestamp` ist auf die Mikrosekunde dasselbe. Die drei Minuten
/// entstehen also nirgends in der App und nirgends im Dienst: sie sind die Differenz zweier
/// Maschinenuhren, und die Anzeige gab sie ungefiltert weiter. Der `LIVE`-Punkt kann das nicht
/// aufdecken - er rechnet gegen die Geraeteuhr und sah puenktliche Rahmen.
///
/// **Zwei Uhren, weil es zwei Fragen sind.**
///
/// * Die **Datenuhr** (``datenzeit(_:)``) ist die Uhr des Dienstes - im Live-Betrieb ohne Wenn
///   und Aber. Sie muss es sein: *alle* Zeitstempel der Daten sind in ihr geschrieben -
///   `observed_at`, die Fahrplanfenster, der Kalendertag, nach dem der Verlauf geholt wird.
///   Alter, Fensterlage und Tagesgrenze werden mit ihr richtig und mit der Geraeteuhr falsch.
/// * Die **Anzeigeuhr** (``anzeigezeit(_:)``) ist die eine Zahl, die ein Mensch gegen seine
///   eigene Uhr liest. Im Live-Betrieb ist das die Uhr des Geraets - die das iPad per NTP
///   stellt und einen Zentimeter hoeher selbst hinschreibt.
///
/// **Die Datenuhr hat kein Band, und das ist die Lehre aus einem Zwischenstand.** Eine
/// Zwischenfassung liess sie innerhalb eines Bandes (-72 s bis +2 s) auf die Geraeteuhr
/// zurueckfallen - „im Zweifel die naehere Uhr". Das kostete zweimal mehr, als es brachte,
/// beides nachgerechnet: an der Tagesgrenze kippte `Hauszustand.heute` zur Geraete-Mitternacht,
/// und bis zu 72 s lang verwarf das Tor `raster.tag == heute` in `Hauszustand.setze(_:)` frische
/// Messwerte; und ein iPad, dessen Uhr 45 s *vorgeht*, hing „vor 45 s" an jeden frischen
/// Messwert, ohne dass daraus ein Befund wurde - das Band fing die eine Richtung und uebersah
/// die andere. Beides ist weg, seit die Datenuhr im Live-Betrieb schlicht dem Dienst folgt, so
/// wie vor der ganzen Aenderung: rund siebzig Leser in 27 Dateien rechnen wieder gegen genau die
/// Uhr, in der die Stempel geschrieben sind, und keiner von ihnen muss wissen, ob gerade ein
/// Band gilt.
/// Eine Schranke weniger ist hier eine Fehlerquelle weniger.
///
/// **Gemeldet wird trotzdem, und dafuer ist die Schwelle asymmetrisch.** Gefragt ist nicht, nach
/// welcher Uhr gerechnet wird - das steht oben -, sondern wann ein Mensch davon erfahren muss.
/// Das ist dieselbe Frage wie: wann sieht man es? Und sie laesst sich am Vorzeichen schaerfen:
///
/// * Voraus (der Dienst ist frueher dran) zaehlt ``meldeschwelle``: eine Minute, denn weniger
///   ist auf zwei Minutenanzeigen nebeneinander nicht als Abstand zu lesen (siehe dort).
/// * Zurueck zaehlt ``alterspanne``: 72 s. Ein *alter* Zeitstempel liegt immer in der
///   Vergangenheit, und zwar hoechstens um diese Spanne - ein Dienst, der statt seiner Uhr den
///   Stempel der letzten Momentaufnahme schickt (die aeltere Fassung, gegen die diese
///   Wandanzeige womoeglich noch wochenlang laeuft), bleibt in diesem Band. Daraus einen Befund
///   zu machen hiesse, Alter und falsch gestellte Uhr zu verwechseln. Vorwaerts gibt es dieses
///   Band nicht: Alter geht nur rueckwaerts.
///
/// Beide Schwellen liegen bei einer Minute oder darueber - die Diagnosezahl darunter geht
/// deswegen nicht verloren: ``versatz`` ist immer der rohe gemessene Abstand und steht mit einer
/// Dezimalstelle auf der Zugangsseite („Zeitversatz zum Dienst"). Dort findet man eine wandernde
/// Maschinenuhr bei drei Sekunden; die Wand erfaehrt es erst, wenn man es ihr ansieht.
///
/// **Was bei Ueberschreitung geschieht.** Die Datenuhr folgt weiter dem Dienst (in seiner Uhr
/// sind die Daten geschrieben), die Anzeigeuhr bleibt die des Geraets, und der Abstand wird ein
/// Befund (``befund``) statt einer stumm falschen Wandanzeige. Die App kann nicht wissen, welche
/// der beiden Uhren recht hat - also korrigiert sie nichts heimlich, sondern zeigt die Uhr, die
/// der Betrachter ohnehin daneben sieht, und sagt dazu, wie weit die andere absteht. Damit
/// jemand die falsche Uhr richten kann; das Foto zeigt genau den Fall, in dem niemand es merkte.
/// Der Befund ist eine ``Wachbefunde/Schwere/warnung`` und nimmt darum keinem `.alarm` des
/// Dienstes den Platz weg - die Reihenfolge rechnet
/// ``Wachbefunde/zeilen(_:zuerst:hoechstens:)``, und sie begruendet dort, warum.
///
/// **Im Vorfuehrbetrieb gilt das alles nicht.** Dort laeuft die Uhr des Dienstes im Zeitraffer
/// und auf einem Tag, der Wochen zurueckliegt (`Settings.demo_start`); der Versatz ist dort der
/// Zweck und keine Stoerung, und auch die Anzeigeuhr folgt ihm. Die Begruendung steht in
/// `Hauszustand.swift` und in `apps/web/src/lib/live/store.ts:110`: ohne ihn las die Startseite
/// „Invalid Date" und beide Diagramme blieben leer.
///
/// **Warum das hier liegt und nicht in der Ansicht.** Dieselbe Begruendung wie bei
/// ``Verbindungspolitik``: es ist Logik, die man an einem laufenden Geraet nicht pruefen kann -
/// dafuer braeuchte man eine falsch gestellte Uhr - und sie entscheidet ueber den Inhalt der
/// groessten Zahl auf dem Bild. `HausuhrTests` spielt sie durch, das Foto eingeschlossen.
public struct Hausuhr: Sendable, Equatable {

    /// In welchem Betrieb der Dienst laeuft - danach entscheidet sich, ob ein Versatz Zweck
    /// oder Fehler ist.
    public enum Betrieb: Sendable, Equatable {
        /// Das echte Haus. Beide Uhren sollen dieselbe Zeit zeigen.
        case live
        /// Das Vorfuehrhaus: Zeitraffer auf einem vergangenen Tag (`system.mode == "demo"`).
        ///
        /// `tempo` ist `system.sim_speed` aus demselben Rahmen. Es steht hier und nicht bloss im
        /// Kopftext, weil `sim_speed == 0` erlaubt ist und etwas anderes bedeutet als „langsam":
        /// die Vorfuehrung ist **angehalten**, ohne dass die Verbindung abreisst. Siehe
        /// ``melde(serverzeit:geraetezeit:betrieb:)``.
        case vorfuehrung(tempo: Double)
        /// Noch kein Zustand da, also auch kein Modus. Kommt beim ersten Herzschlag vor, wenn
        /// er dem ersten Augenblicksbild zuvorkommt.
        case unbekannt
    }

    // MARK: - Die beiden Zahlen, und woher sie kommen

    /// Darunter ist ein Abstand Laufzeit und keine Uhrabweichung: zwei Sekunden.
    ///
    /// **Gemessen, nicht gewaehlt.** Am laufenden Dienst lag `server_time` 0,003 s und 0,12 s
    /// hinter der Wanduhr - die Dauer der Anfrage. Dazu kommt eine Sekunde aus der eigenen
    /// Stube: ``Zeit/ausIso(_:)`` liest die Bruchteile und verwirft sie („Bruchteile werden
    /// gelesen und verworfen"), der gelesene Zeitpunkt liegt also bis zu 0,999999 s *vor* dem
    /// gesendeten, und der Abstand ist systematisch bis zu eine Sekunde zu negativ. Eine
    /// Sekunde Abschneiden plus eine Sekunde Luft fuer ein langsames WLAN.
    ///
    /// Gebraucht wird die Spanne heute nur noch als Summand in ``alterspanne``: gemeldet wird
    /// erst ab ``meldeschwelle``, und die liegt dreissigmal hoeher.
    public static let laufzeitspanne: TimeInterval = 2

    /// Der Hoechstabstand zweier Rahmen, aus dem Dienst: `Takt.hoechstabstand_s` in
    /// `apps/api/src/dch_api/application/live_feed.py` (`live_push_max_s = 60.0`).
    ///
    /// Die Begruendung dort: „Der Hoechstabstand ist die Gegenprobe zum Filter. Ohne ihn bliebe
    /// ein Bildschirm, der eine Meldung verpasst hat, beliebig lange auf dem alten Stand."
    public static let hoechstabstandRahmen: TimeInterval = 60

    /// Der Regeltakt des Dienstes: `Settings.tick_s = 10` (`apps/api/src/dch_api/settings.py`).
    ///
    /// Gesendet wird am Ende jedes Regeldurchgangs, der Takt sieht also nur alle zehn Sekunden
    /// nach, ob der Hoechstabstand vorbei ist. Der tatsaechliche Abstand zweier Rahmen reicht
    /// damit bis zum naechsten Takt *nach* den sechzig Sekunden.
    public static let regeltakt: TimeInterval = 10

    /// So weit darf ein Zeitstempel zurueckliegen, ohne dass daraus ein Befund wird: 72 Sekunden.
    ///
    /// **Aus dem Haus hergeleitet, nicht geraten.** 60 s Hoechstabstand des Rahmens
    /// (``hoechstabstandRahmen``) + 10 s Regeltakt (``regeltakt``, denn der Hoechstabstand wird
    /// erst beim naechsten Durchgang bemerkt) + 2 s Laufzeit (``laufzeitspanne``). Ein
    /// Zeitstempel, der aelter ist, kann kein verpasster Rahmen mehr sein.
    ///
    /// Gebraucht wird diese Spanne fuer den Dienst, der in `system.server_time` nicht seine Uhr,
    /// sondern den Stempel der letzten Momentaufnahme schickt. Die heutige Fassung tut das nicht
    /// (nachgemessen: 0,000000 s Abstand zwischen `snapshot.timestamp` und `server_time`) - aber
    /// eine Wandanzeige laeuft Wochen am selben Platz und womoeglich gegen eine aeltere Fassung,
    /// und drei Minuten Uhrversatz sehen von hier aus genauso aus wie ein alter Stempel. Nur das
    /// Vorzeichen und der Betrag trennen die beiden.
    public static let alterspanne: TimeInterval = hoechstabstandRahmen + regeltakt + laufzeitspanne

    /// Ab wann ein Abstand nach vorn ueberhaupt gemeldet wird: wenn er eine Minute
    /// **uebersteigt**. Genau 60,0 s sind noch kein Befund (`gemeldet > meldeschwelle`).
    ///
    /// **Die Schwelle ist die Auflösung der Anzeige, nicht die der Messung.** Beide Uhren stehen
    /// als `HH:mm` da - die eine gross auf dem Ruhebild (``anzeigezeit(_:)``, ueber
    /// ``Formate/hhmm(_:)``), die andere in der Statusleiste des iPads daneben. Unter einer
    /// Minute Abstand zeigen die beiden entweder dieselbe Minute oder zwei aufeinanderfolgende,
    /// und die zweite auch nur fuer einen Teil jeder Minute - das ist von dem Umstand, dass zwei
    /// Geraete ihre Minute nicht im selben Augenblick umlegen, nicht zu unterscheiden. Erst
    /// *oberhalb* von 60 s weichen die beiden Anzeigen zu jedem Zeitpunkt um mindestens eine
    /// Minute ab; bei genau 60 s zeigen sie den Umschlagfall, und der ist kein Befund. Ein
    /// Befund darunter waere ein Satz ueber etwas, das man nicht sehen kann.
    ///
    /// **Der Gegenbeweis zu der Schwelle, die vorher hier stand.** Gemeldet wurde ab 2 s
    /// (``laufzeitspanne``). Eine Maschine ohne NTP driftet um Sekunden am Tag; drei Sekunden
    /// sind der Normalfall und nicht der Ausnahmefall. Nachgerechnet hiess das: auf dem Ruhebild
    /// gibt es *einen* Satz (``Ruhebild/schwersterBefund(_:zuerst:)``, `hoechstens: 1`), und den
    /// haette der Uhrbefund dauerhaft belegt - an der Stelle, an der sonst steht, dass der
    /// MQTT-Broker weg ist. Eine Dauerwarnung, die immer dasteht, ist keine Warnung mehr.
    ///
    /// Zurueck gilt stattdessen ``alterspanne`` (72 s, also noch mehr Luft): dort ist nicht die
    /// Sichtbarkeit die engere Grenze, sondern die Verwechslung mit einem alten Zeitstempel.
    public static let meldeschwelle: TimeInterval = 60

    /// Der Versatz der **Datenuhr**: Uhr des Dienstes minus Uhr des Geraets.
    ///
    /// Im Live- und im Vorfuehrbetrieb ist das immer der rohe gemessene Abstand des letzten
    /// lesbaren Rahmens - ohne Schwelle, ohne Unterdrueckung. Darauf steht die Diagnosezahl der
    /// Zugangsseite („Zeitversatz zum Dienst", eine Dezimalstelle): mit ihr findet man eine
    /// wandernde Maschinenuhr bei drei Sekunden und nicht erst bei drei Minuten.
    public private(set) var versatz: TimeInterval = 0

    /// Der Versatz der **Anzeigeuhr**. Im Live-Betrieb null - dort gilt die Uhr des Geraets.
    public private(set) var anzeigeversatz: TimeInterval = 0

    /// Der gemeldete Abstand, falls er ein Befund ist (sonst `nil`).
    public private(set) var abweichung: TimeInterval?

    /// Hat in dieser Verbindung schon ein Rahmen die Anzeigeuhr gestellt?
    ///
    /// Der erste darf sie hinstellen, wohin er will - niemand sieht in diesem Augenblick auf
    /// eine laufende Uhr. Danach zaehlt die Richtung (siehe ``melde(serverzeit:geraetezeit:betrieb:)``).
    private var gestellt = false

    public init() {}

    /// Eine Uhr, die schon steht - fuer Vorschauen und Pruefungen.
    ///
    /// Beide Uhren auf denselben Versatz: eine Vorschau zeigt den Nachmittag, zu dem ihre
    /// Zahlen passen, und nicht die halbe Uhrzeit von jetzt.
    public init(vorgestellt versatz: TimeInterval) {
        self.versatz = versatz
        self.anzeigeversatz = versatz
        self.gestellt = true
    }

    // MARK: - Melden

    /// Einen Zeitstempel aus dem Netz verrechnen - aus jedem Augenblicksbild und jedem Herzschlag.
    ///
    /// **Rueckwaerts geht keine Uhr.** Wer auf die Wand sieht, waehrend die Minute von 22:07 auf
    /// 22:04 faellt, sieht einen kaputten Bildschirm, nicht eine Korrektur. Im Live-Betrieb kann
    /// das nicht mehr geschehen, weil die Anzeigeuhr dort nicht am Datenfluss haengt. Im
    /// Vorfuehrbetrieb, wo sie es muss, wird eine Korrektur nur nach vorn uebernommen: was
    /// zurueckzeigt, wartet, bis die Zeit es aufgeholt hat. Freigegeben wird die Richtung erst
    /// wieder von ``abgerissen()`` - nach einem Abriss der Verbindung, denn ein neu gestarteter
    /// Vorfuehrdienst faengt seinen Tag von vorn an, und eine eingefrorene Uhr waere dann
    /// schlimmer als ein Sprung.
    ///
    /// **Ausser die Vorfuehrung steht.** `sim_speed = 0` haelt die Simulation an, *ohne* die
    /// Verbindung zu loesen: ``abgerissen()`` wird nie gerufen, `house.now` steht, und der
    /// gemeldete Abstand wird mit jeder verstrichenen Sekunde kleiner. Die Sperre nach hinten
    /// liess dann keinen einzigen Rahmen mehr durch - die grosse Uhr lief in Echtzeit davon und
    /// stand nach einer Stunde Pause eine Stunde vor dem angehaltenen Haus. Bei `tempo <= 0`
    /// wird darum jeder Rahmen uebernommen; die Anzeigeuhr steht dann auf der Serverzeit und
    /// kriecht nur bis zum naechsten Rahmen weiter (hoechstens ``hoechstabstandRahmen`` plus
    /// ``regeltakt``, und auf einer Minutenanzeige ist das ein Zucken statt einer Stunde).
    ///
    /// Was die App nicht verhindern kann, ist ein Rueckschritt der *Geraeteuhr* selbst - stellt
    /// iOS sie, springt die Anzeige mit. Sie kann nur aufhoeren, sie selbst zu verstellen.
    public mutating func melde(
        serverzeit: Date, geraetezeit: Date = Date(), betrieb: Betrieb
    ) {
        let gemeldet = serverzeit.timeIntervalSince(geraetezeit)
        // Ein unlesbarer Zeitstempel darf den Versatz nicht vergiften: aus `NaN` wird sonst
        // ueberall „Invalid Date", und der naechste gute Rahmen macht den einmal
        // weggeschriebenen Tag nicht wieder gut.
        guard gemeldet.isFinite else { return }

        switch betrieb {
        case .unbekannt:
            // Ohne Modus ist nicht entscheidbar, ob dieser Abstand Zweck oder Fehler ist. Beides
            // zu raten waere schlimmer als zu warten: der Zustand kommt im selben Atemzug.
            return

        case .vorfuehrung(let tempo):
            versatz = gemeldet
            // `tempo <= 0`: die Vorfuehrung steht, und eine stehende Uhr muss stehen duerfen.
            if !gestellt || gemeldet > anzeigeversatz || tempo <= 0 {
                anzeigeversatz = gemeldet
            }
            gestellt = true
            abweichung = nil

        case .live:
            // Die Anzeigeuhr ist hier die des Geraets - ohne Wenn und Aber, und damit ohne
            // Sprung und ohne Abhaengigkeit vom Datenfluss.
            anzeigeversatz = 0
            gestellt = true
            // Die Datenuhr ist hier die des Dienstes - ebenso ohne Wenn und Aber: in ihr sind
            // die Stempel geschrieben, die alle Leser auswerten. Gerechnet wird also immer mit
            // dem rohen Abstand; die Schwellen entscheiden nur, ob jemand davon erfaehrt.
            //
            // **Auch bei einem unsinnigen Abstand, und das ist Absicht.** `Zeit.ausIso` nimmt
            // jede vierstellige Jahreszahl; stellt der Dienst seine Uhr auf 2099, folgt die
            // Datenuhr dorthin, `Hauszustand.heute` nennt diesen Tag, und `ladeTag` holt ihn.
            // Eine Plausibilitaetsgrenze waere hier genau das Band, das vorher stand und vier
            // Mangel kostete - und sie waere auch sachlich falsch: der Dienst stempelt seine
            // Messwerte mit derselben Uhr, in der er `server_time` schickt. Beides zusammen ist
            // in sich stimmig, nur gegen die Wirklichkeit verschoben, und dagegen hilft keine
            // Schranke in der App, sondern NTP auf der Maschine. Gemeldet wird es: ein Abstand
            // dieser Groesse steht als Befund in der Wache („2 Tage auseinander").
            versatz = gemeldet
            if gemeldet > Self.meldeschwelle || gemeldet < -Self.alterspanne {
                abweichung = gemeldet
            } else {
                abweichung = nil
            }
        }
    }

    /// Die Verbindung war weg: der naechste Rahmen darf die Anzeigeuhr wieder frei stellen.
    public mutating func abgerissen() {
        gestellt = false
    }

    // MARK: - Lesen

    /// Jetzt, nach der Uhr des Dienstes. Die Uhr der **Daten**.
    public func datenzeit(_ geraetezeit: Date = Date()) -> Date {
        geraetezeit.addingTimeInterval(versatz)
    }

    /// Jetzt, wie es auf der Wand steht. Die Uhr, die ein Mensch gegen seine eigene prueft.
    public func anzeigezeit(_ geraetezeit: Date = Date()) -> Date {
        geraetezeit.addingTimeInterval(anzeigeversatz)
    }

    /// Gehen die beiden Uhren auseinander? Dann steht hier, wie weit.
    ///
    /// Eine Warnung und kein Alarm: die Zahlen sind richtig, nur ihre Zeitstempel sind es nicht -
    /// und welches der beiden Geraete die falsche Uhr hat, weiss von hier aus niemand.
    public var befund: Wachbefunde.Zeile? {
        guard let abweichung else { return nil }
        return Wachbefunde.Zeile(name: "hausuhr", satz: Self.satz(abweichung), schwere: .warnung)
    }

    /// Der Satz zum Befund.
    ///
    /// **Richtungsneutral, und das ist eine Korrektur.** Hier stand „Die Uhr des Dienstes geht
    /// N Minuten nach" - eine Schuldzuweisung an die eine Maschine, waehrend zwanzig Zeilen
    /// hoeher steht, die App koenne gar nicht wissen, welche der beiden Uhren recht hat. Beim
    /// haeufigsten Fall ist der Satz sogar falsch: ein iPad, dessen Akku leer war, kommt mit
    /// einer falschen Uhr zurueck, und dann geht der Dienst richtig. Gesagt wird darum nur, was
    /// gemessen ist - der Abstand und wer von beiden der fruehere ist -, und welche Uhr dasteht.
    ///
    /// **Grosse Betraege in grossen Einheiten.** „1440 Minuten" ist eine Zahl, die man erst
    /// nachrechnen muss, bevor man sie glaubt; „ein Tag" nicht. Umgeschaltet wird bei
    /// anderthalb der naechsten Einheit (ueber 90 Minuten in Stunden, ueber 36 Stunden in Tage),
    /// damit nach dem Umschalten nie „1 Stunde" dasteht, wo gerade noch „89 Minuten" stand.
    ///
    /// Unter einer Minute gibt es keinen Satz, weil es keinen Befund gibt (``meldeschwelle``,
    /// ``alterspanne``) - darum beginnt die Staffelung bei Minuten und nicht bei Sekunden.
    private static func satz(_ abweichung: TimeInterval) -> String {
        let betrag = abs(abweichung)
        let spanne: String
        if betrag <= 90 * 60 {
            let minuten = Int((betrag / 60).rounded())
            spanne = minuten == 1 ? "eine Minute" : "\(minuten) Minuten"
        } else if betrag <= 36 * 3600 {
            spanne = "\(Int((betrag / 3600).rounded())) Stunden"
        } else {
            spanne = "\(Int((betrag / 86400).rounded())) Tage"
        }
        let lage = abweichung < 0 ? "der Dienst liegt zurück" : "der Dienst liegt vorn"
        return "Die Uhren von Dienst und Gerät gehen \(spanne) auseinander, \(lage). "
            + "Angezeigt wird die Uhr dieses Geräts."
    }
}
