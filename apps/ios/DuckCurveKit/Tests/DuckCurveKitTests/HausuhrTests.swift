import XCTest

@testable import DuckCurveKit

/// Welche Uhr auf der Wand steht - und wann ein Zeitstempel aus dem Netz sie stellen darf.
///
/// **Der Anlass, nachgemessen.** Ein Foto der Wandanzeige (Ruhebild) zeigt in der grossen Uhr
/// `22:04`, waehrend die Statusleiste desselben iPads `22:07` zeigt; oben rechts stand `LIVE`.
/// Die Kette dahinter war kurz und ohne eine einzige Schranke:
///
/// 1. `live_runtime.live_state()` legt `system.server_time` auf die Wanduhr des Dienstes.
///    Nachgemessen am laufenden Dienst (`/api/v1/live/state`, `mode=live`): `server_time` liegt
///    0,003 s bzw. 0,12 s hinter `datetime.now(UTC)` - genau die Dauer der Anfrage -, und
///    `snapshot.timestamp` ist auf die Mikrosekunde dasselbe. Auch mit einer zehn Minuten alten
///    Messung im Speicher bleibt `timestamp` auf `now`. Der Zeitstempel ist also **nicht** das
///    Alter der Daten, sondern die Uhr des Servers.
/// 2. `Hauszustand.setzeVersatz(_:)` schrieb `versatz = serverzeit - Date()` - bei jedem
///    Augenblicksbild und bei jedem Herzschlag, ohne Grenze und ohne nach dem Betriebsmodus
///    zu fragen.
/// 3. `haus.jetzt` war `Date() + versatz` und damit die Uhr des **Servers**.
/// 4. Diese Uhr stand gross auf dem Ruhebild (`Bausteine/Ambiente.swift`) und im Kopf der
///    Wandanzeige (`App/WandRahmen.swift`) - einen Zentimeter unter der Statusleiste des iPads,
///    die die Uhr des Geraets zeigt.
///
/// Die drei Minuten entstehen also nirgends in dieser App und nirgends im Dienst: sie sind die
/// Differenz zweier Maschinenuhren, und die Anzeige gab sie ungefiltert weiter.
///
/// **Diese Datei haelt beides fest:** dass der alte Weg das Foto erzeugt (``bestandsVersatz``,
/// ``bestandsJetzt`` - Zeile fuer Zeile der frueheren Fassung), und dass ``Hausuhr`` es nicht
/// mehr tut. Der Nachbau bleibt stehen, weil er der einzige Beweis ist, dass die Regel ueberhaupt
/// etwas aendert - gezaehlt werden darf er nicht, siehe
/// ``testDokumentationDerFruehereWegZeigtDieUhrDesServers``.
final class HausuhrTests: XCTestCase {

    /// 22:07:00 Ortszeit am 21.11.2026 - die Zeit der Statusleiste auf dem Foto.
    private let geraeteuhr = Date(timeIntervalSince1970: 1_795_295_220)
    /// Drei Minuten, die Abweichung vom Foto.
    private let dreiMinuten: TimeInterval = 180

    // MARK: - Der fruehere Weg, nachgebaut

    /// `versatz = serverzeit - Date()`, ohne Bedingung.
    private func bestandsVersatz(serverzeit: Date, geraet: Date) -> TimeInterval {
        let neu = serverzeit.timeIntervalSince(geraet)
        return neu.isFinite ? neu : 0
    }

    /// `jetzt = Date() + versatz`.
    private func bestandsJetzt(geraet: Date, versatz: TimeInterval) -> Date {
        geraet.addingTimeInterval(versatz)
    }

    /// **Der Befund ist reproduzierbar, ohne jeden Fehler in App oder Dienst.** Ein Server,
    /// dessen Uhr drei Minuten nachgeht, machte aus 22:07 auf dem Geraet 22:04 auf dem Bild -
    /// und das ist genau das Foto.
    ///
    /// **Dies ist Dokumentation und keine Pruefung - sie kann nicht fallen.** Gerechnet wird
    /// ausschliesslich mit ``bestandsVersatz`` und ``bestandsJetzt``, zwei Hilfsfunktionen
    /// dieser Datei; kein Symbol des Produktionskodes kommt darin vor. In einer Mutationsmatrix
    /// ueber ``Hausuhr`` hat sie alle zehn Mutanten ueberlebt. Sie steht hier als Beleg fuer das
    /// Foto, nicht als Schranke; wer Pruefungen zaehlt, zaehle sie nicht mit. Was die Regel
    /// wirklich festhaelt, ist ``testDasFotoKommtNichtMehrVor`` - dieselbe Lage, mit ``Hausuhr``
    /// gerechnet.
    func testDokumentationDerFruehereWegZeigtDieUhrDesServers() {
        let serverzeit = geraeteuhr.addingTimeInterval(-dreiMinuten)
        let versatz = bestandsVersatz(serverzeit: serverzeit, geraet: geraeteuhr)
        let bild = bestandsJetzt(geraet: geraeteuhr, versatz: versatz)

        XCTAssertEqual(Formate.hhmm(geraeteuhr), "22:07", "die Statusleiste des iPads")
        XCTAssertEqual(Formate.hhmm(bild), "22:04", "die grosse Uhr auf dem Ruhebild")
        XCTAssertEqual(versatz, -dreiMinuten, accuracy: 0.001)
    }

    // MARK: - 1. Das Foto, mit der Regel

    /// **Dasselbe Haus, dieselbe nachgehende Dienstuhr - und die Wand zeigt 22:07.**
    ///
    /// Der Versatz bleibt fuer die Daten erhalten: in der Uhr des Dienstes sind sie geschrieben.
    /// Nur die Zahl, die ein Mensch gegen seine eigene Uhr liest, ist die des Geraets.
    func testDasFotoKommtNichtMehrVor() {
        var uhr = Hausuhr()
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-dreiMinuten), geraetezeit: geraeteuhr,
            betrieb: .live)

        XCTAssertEqual(Formate.hhmm(uhr.anzeigezeit(geraeteuhr)), "22:07", "die Uhr auf der Wand")
        XCTAssertEqual(Formate.hhmm(uhr.datenzeit(geraeteuhr)), "22:04", "die Uhr der Daten")
        XCTAssertEqual(uhr.versatz, -dreiMinuten, accuracy: 0.001)
        XCTAssertEqual(uhr.anzeigeversatz, 0)
    }

    /// Und der Abstand wird ein Befund, statt stumm die Wand zu verstellen.
    func testDerAbstandWirdEinBefund() {
        var uhr = Hausuhr()
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-dreiMinuten), geraetezeit: geraeteuhr,
            betrieb: .live)

        XCTAssertEqual(uhr.abweichung, -dreiMinuten)
        XCTAssertEqual(
            uhr.befund?.satz,
            "Die Uhren von Dienst und Gerät gehen 3 Minuten auseinander, der Dienst liegt "
                + "zurück. Angezeigt wird die Uhr dieses Geräts.")
        XCTAssertEqual(uhr.befund?.schwere, .warnung)
        XCTAssertEqual(uhr.befund?.name, "hausuhr")

        // **Kein „geht nach".** Der Satz nennt den Abstand und wer von beiden der fruehere ist,
        // aber er beschuldigt keine der beiden Maschinen: bei einem iPad, dessen Akku leer war,
        // geht der Dienst richtig und das Geraet falsch - und von hier aus sehen die beiden
        // Faelle gleich aus.
        XCTAssertFalse(uhr.befund?.satz.contains("geht") ?? true)

        // Die Gegenrichtung: das iPad steht falsch, der Dienst geht richtig. Dieselbe
        // Entscheidung - die App kann nicht wissen, welche der beiden Uhren recht hat; sie darf
        // nur nicht schweigend eine fremde anzeigen. Der Satz nennt die Lage, damit jemand
        // die richtige Uhr richten kann.
        var andersrum = Hausuhr()
        andersrum.melde(
            serverzeit: geraeteuhr.addingTimeInterval(dreiMinuten), geraetezeit: geraeteuhr,
            betrieb: .live)
        XCTAssertEqual(
            andersrum.befund?.satz,
            "Die Uhren von Dienst und Gerät gehen 3 Minuten auseinander, der Dienst liegt "
                + "vorn. Angezeigt wird die Uhr dieses Geräts.")
        XCTAssertEqual(Formate.hhmm(andersrum.anzeigezeit(geraeteuhr)), "22:07")

        // Die Wache zeigt ihn vor den Befunden des Dienstes - er entwertet deren Zeitstempel.
        let zeilen = Wachbefunde.zeilen(
            [
                WatchFindingOut(
                    name: "puffer_still", titleDe: "Puffer still", severity: .warn,
                    silentMin: 2880, textDe: "Die Puffertemperaturen still")
            ],
            zuerst: [uhr.befund].compactMap { $0 })
        XCTAssertEqual(zeilen.count, 2)
        XCTAssertEqual(zeilen.first?.name, "hausuhr")
    }

    // MARK: - 2. Die Datenuhr folgt immer dem Dienst

    /// **Die Datenuhr hat keine Schwelle, und daran haengt alles unter ihr.**
    ///
    /// Eine Zwischenfassung liess sie in einem Band (-72 s bis +2 s) auf die Geraeteuhr
    /// zurueckfallen - „im Zweifel die naehere Uhr". Damit hatte `haus.jetzt` innerhalb des
    /// Bandes eine andere Bedeutung als ausserhalb, ohne dass einer der 73 Leser in 28 Dateien
    /// es erfuhr. Hier steht, dass das vorbei ist: was gemeldet wird, wird gerechnet - in beide
    /// Richtungen, ueber die ganze Breite.
    func testDieDatenuhrFolgtImmerDemDienst() {
        for abstand: TimeInterval in [-180, -73, -71.9, -45, -3, -0.12, 0, 3, 45, 70, 180] {
            var uhr = Hausuhr()
            uhr.melde(
                serverzeit: geraeteuhr.addingTimeInterval(abstand), geraetezeit: geraeteuhr,
                betrieb: .live)
            XCTAssertEqual(
                uhr.versatz, abstand, accuracy: 1e-6, "\(abstand) s gehoeren in die Datenuhr")
            XCTAssertEqual(uhr.datenzeit(geraeteuhr), geraeteuhr.addingTimeInterval(abstand))
            XCTAssertEqual(uhr.anzeigezeit(geraeteuhr), geraeteuhr, "die Wand bleibt beim Geraet")
        }
    }

    /// **Ein iPad, das vorgeht, haengt kein Alter mehr an frische Messwerte.**
    ///
    /// Das Band fing nur die eine Richtung: ein Geraet, dessen Uhr 45 s *vorgeht*, meldet einen
    /// Abstand von -45 s, der lag im Band, die Datenuhr blieb die des Geraets - und
    /// `observed_at` eines gerade erst geschriebenen Messwerts sah damit dauerhaft 45 s alt aus,
    /// ohne dass ein Befund entstand. Das Vorzeichen allein trennt die beiden Faelle also nicht.
    func testEinVorgehendesGeraetMachtKeinenMesswertAlt() {
        let vorgeht: TimeInterval = 45
        // Der Dienst stempelt in seiner Uhr; sie liegt 45 s hinter der des Geraets.
        let dienstjetzt = geraeteuhr.addingTimeInterval(-vorgeht)
        var uhr = Hausuhr()
        uhr.melde(serverzeit: dienstjetzt, geraetezeit: geraeteuhr, betrieb: .live)

        // `observed_at` eines eben geschriebenen Messwerts - er ist null Sekunden alt.
        XCTAssertEqual(
            uhr.datenzeit(geraeteuhr).timeIntervalSince(dienstjetzt), 0, accuracy: 1e-6,
            "mit der Uhr des Dienstes gerechnet ist er frisch")
        XCTAssertEqual(
            geraeteuhr.timeIntervalSince(dienstjetzt), vorgeht, accuracy: 1e-6,
            "mit der Geraeteuhr gerechnet waere derselbe Messwert 45 s alt - der Gegenbeweis")
        XCTAssertNil(uhr.befund, "und 45 s sieht man auf einer Minutenanzeige nicht")
    }

    /// **Die Tagesgrenze kippt nicht mehr zur Geraete-Mitternacht.**
    ///
    /// `Hauszustand.heute` entscheidet, welcher Tag geladen wird und ob ein frischer Messwert
    /// noch ins Minutenraster darf (`raster.tag == heute`). Mit dem Band stand kurz nach
    /// Mitternacht der Tag des *Geraets* da, waehrend der Dienst noch Stempel des Vortags
    /// schrieb: bis zu 72 s lang verwarf das Tor jeden frischen Messwert.
    func testDieTagesgrenzeFolgtDemDienstAuchKnappDarunter() {
        // 00:00:30 Ortszeit auf dem Geraet; der Dienst steht noch bei 23:59:50 des Vortags.
        let kurzNachMitternacht = Date(timeIntervalSince1970: 1_795_302_030)
        XCTAssertEqual(Formate.hhmm(kurzNachMitternacht), "00:00")

        var uhr = Hausuhr()
        uhr.melde(
            serverzeit: kurzNachMitternacht.addingTimeInterval(-40),
            geraetezeit: kurzNachMitternacht, betrieb: .live)

        XCTAssertEqual(
            Tag.iso(uhr.datenzeit(kurzNachMitternacht)), "2026-11-21", "der Tag des Dienstes")
        XCTAssertEqual(
            Tag.iso(uhr.anzeigezeit(kurzNachMitternacht)), "2026-11-22", "das Datum auf der Wand")
        XCTAssertNil(uhr.befund, "40 s sind keine sichtbare Abweichung und kein Befund")
    }

    // MARK: - 3. Gemeldet wird erst, wenn man es sehen kann

    /// **Die Schranke ist asymmetrisch, und daran haengt die ganze Unterscheidung.**
    ///
    /// Ein Dienst, der in `system.server_time` den Stempel der letzten Momentaufnahme schickt
    /// statt seiner Uhr, bleibt im Band bis ``Hausuhr/alterspanne`` *hinter* der Geraeteuhr -
    /// hergeleitet aus `Takt.hoechstabstand_s` (60 s) + `Settings.tick_s` (10 s) + Laufzeit
    /// (2 s). Daraus darf keine Korrektur und kein Befund werden: die Wandanzeige laeuft
    /// womoeglich wochenlang gegen eine aeltere Fassung des Dienstes.
    ///
    /// Vorwaerts gilt dasselbe Band nicht: Alter geht nur rueckwaerts. Ein Zeitstempel in der
    /// Zukunft ist immer eine Uhr und niemals ein alter Rahmen.
    func testAlterZeitstempelGiltNichtAlsUhrfehler() {
        XCTAssertEqual(Hausuhr.alterspanne, 72)

        // Das ganze Band: ein verpasster Rahmen, ein zweiter, der Regeltakt obendrauf.
        for alter: TimeInterval in [-5, -30, -60, -70, -71.9] {
            var uhr = Hausuhr()
            uhr.melde(
                serverzeit: geraeteuhr.addingTimeInterval(alter), geraetezeit: geraeteuhr,
                betrieb: .live)
            XCTAssertNil(uhr.befund, "\(alter) s koennen ein alter Rahmen sein")
            XCTAssertEqual(
                uhr.versatz, alter, accuracy: 1e-6, "gerechnet wird trotzdem mit dem Dienst")
        }

        // Knapp darueber ist es mit dem Takt des Dienstes nicht mehr zu erklaeren.
        var zuAlt = Hausuhr()
        zuAlt.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-73), geraetezeit: geraeteuhr, betrieb: .live)
        XCTAssertEqual(zuAlt.abweichung, -73)
        XCTAssertEqual(
            zuAlt.befund?.satz.hasPrefix("Die Uhren von Dienst und Gerät gehen eine Minute"), true)

        // Dieselben 70 Sekunden in die andere Richtung: kein Alter, also eine Uhr - und
        // sichtbar, denn 70 s sind mehr als eine Minutenanzeige verzeiht.
        var voraus = Hausuhr()
        voraus.melde(
            serverzeit: geraeteuhr.addingTimeInterval(70), geraetezeit: geraeteuhr, betrieb: .live)
        XCTAssertEqual(voraus.abweichung, 70)
        XCTAssertEqual(voraus.versatz, 70, accuracy: 0.001)
    }

    /// **Die Schwelle ist die Auflösung der Anzeige: eine Minute.**
    ///
    /// Beide Uhren stehen als `HH:mm` nebeneinander - die grosse auf dem Ruhebild, die kleine in
    /// der Statusleiste des iPads. Bis einschliesslich 60 s zeigen sie dieselbe Minute oder zwei
    /// aufeinanderfolgende, und die zweite nur fuer einen Teil jeder Minute; von zwei Geraeten,
    /// die ihre Minute nicht im selben Augenblick umlegen, ist das nicht zu unterscheiden.
    /// Gemeldet wird deshalb erst *oberhalb* der Schwelle (`gemeldet > meldeschwelle`), und die
    /// 60,0 s selbst sind der Umschlagfall und kein Befund - darum steht sie in der Reihe unten.
    ///
    /// **Der Gegenbeweis zur alten Schwelle von 2 s:** eine Maschine ohne NTP driftet um
    /// Sekunden am Tag, drei Sekunden sind der Normalfall - und der Uhrbefund haette damit
    /// dauerhaft den einen Satz des Ruhebilds belegt (siehe
    /// ``testEinAlarmDesDienstesBleibtVorDemUhrbefund``).
    func testUnterEinerMinuteWirdNichtGemeldet() {
        XCTAssertEqual(Hausuhr.meldeschwelle, 60)
        for abstand: TimeInterval in [-59, -45, -3, -0.12, 0, 0.12, 3, 30, 45, 59, 60] {
            var uhr = Hausuhr()
            uhr.melde(
                serverzeit: geraeteuhr.addingTimeInterval(abstand), geraetezeit: geraeteuhr,
                betrieb: .live)
            XCTAssertNil(
                uhr.befund, "\(abstand) s sind auf einer Minutenanzeige nicht als Abstand zu lesen")
        }

        // Knapp darueber weichen die beiden Anzeigen zu jedem Zeitpunkt um eine Minute ab.
        var drueber = Hausuhr()
        drueber.melde(
            serverzeit: geraeteuhr.addingTimeInterval(61), geraetezeit: geraeteuhr, betrieb: .live)
        XCTAssertEqual(drueber.abweichung, 61)
    }

    /// **Die Diagnosezahl bleibt auch unter der Schwelle da** - sie ist die einzige Stelle, an
    /// der man eine wandernde Maschinenuhr findet, *bevor* sie drei Minuten erreicht.
    ///
    /// ``Hauszustand/versatz`` liest ``Hausuhr/versatz`` und zeigt ihn auf der Zugangsseite mit
    /// einer Dezimalstelle. Eine unterdrueckte Zahl waere dort genau in dem Bereich blind, in
    /// dem die Diagnose noch billig ist.
    func testDerRoheAbstandBleibtAuchOhneBefundLesbar() {
        for drift: TimeInterval in [3, -3, 0.4, -45] {
            var uhr = Hausuhr()
            uhr.melde(
                serverzeit: geraeteuhr.addingTimeInterval(drift), geraetezeit: geraeteuhr,
                betrieb: .live)
            XCTAssertNil(uhr.befund, "\(drift) s sind kein Befund")
            XCTAssertEqual(uhr.versatz, drift, accuracy: 1e-6, "stehen aber als Zahl da")
        }
    }

    /// **Ein `.alarm` des Dienstes wird nie von der `.warnung` der Uhr verdraengt.**
    ///
    /// Gemessen am Fall, der es aufdeckte: 180 s Versatz plus der Dienstalarm `puffer_still`
    /// („seit zwei Tagen still"). Das Ruhebild hat genau einen Platz
    /// (``Ruhebild/schwersterBefund(_:zuerst:)``, `hoechstens: 1`), und dort stand der
    /// Uhrbefund - der Alarm war weg. Eine schiefe Uhr macht Zeitstempel fraglich; ein Alarm
    /// sagt, dass eine Quelle ganz schweigt.
    func testEinAlarmDesDienstesBleibtVorDemUhrbefund() throws {
        var uhr = Hausuhr()
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-dreiMinuten), geraetezeit: geraeteuhr,
            betrieb: .live)
        let uhrbefund = try XCTUnwrap(uhr.befund)
        let alarm = WatchFindingOut(
            name: "puffer_still", titleDe: "Puffer still", severity: .alarm, silentMin: 2880,
            textDe: "Die Puffertemperaturen seit zwei Tagen still")

        XCTAssertEqual(
            Ruhebild.schwersterBefund([alarm], zuerst: [uhrbefund])?.name, "puffer_still",
            "der eine Satz des Ruhebilds gehoert dem Alarm")
        XCTAssertEqual(
            Wachbefunde.zeilen([alarm], zuerst: [uhrbefund]).map(\.name),
            ["puffer_still", "hausuhr"],
            "in der Wache ist Platz fuer beide - der Alarm zuerst")

        // Eine Warnung des Dienstes dagegen tritt zurueck: sie hat dieselbe Schwere, und der
        // Uhrbefund entwertet ihren Zeitstempel.
        let warnung = WatchFindingOut(
            name: "puffer_still", titleDe: "Puffer still", severity: .warn, silentMin: 2880,
            textDe: "Die Puffertemperaturen seit zwei Tagen still")
        XCTAssertEqual(
            Ruhebild.schwersterBefund([warnung], zuerst: [uhrbefund])?.name, "hausuhr")
    }

    /// **Der Tag der Daten bleibt der des Dienstes - auch wenn seine Uhr falsch geht.**
    ///
    /// `Hauszustand.heute` entscheidet, welcher Tag geladen wird und ob frische Messwerte noch
    /// ins Minutenraster duerfen. Maßgeblich ist der Kalendertag des Dienstes, denn in seiner Uhr
    /// sind die Stempel geschrieben und nach ihm fragt die App den Verlauf ab. Drei Minuten
    /// genuegen an der Tagesgrenze fuer einen ganzen Tag - die Anzeigeuhr geht dabei nicht mit.
    func testDieTagesgrenzeFolgtDenDaten() {
        let kurzNachMitternacht = Date(timeIntervalSince1970: 1_795_295_220 + 2 * 3600 - 6 * 60)
        XCTAssertEqual(Formate.hhmm(kurzNachMitternacht), "00:01")

        var uhr = Hausuhr()
        uhr.melde(
            serverzeit: kurzNachMitternacht.addingTimeInterval(-dreiMinuten),
            geraetezeit: kurzNachMitternacht, betrieb: .live)

        XCTAssertEqual(Tag.iso(uhr.datenzeit(kurzNachMitternacht)), "2026-11-21", "der Tag der Daten")
        XCTAssertEqual(
            Tag.iso(uhr.anzeigezeit(kurzNachMitternacht)), "2026-11-22", "das Datum auf der Wand")
        XCTAssertNotNil(uhr.befund, "und der Unterschied steht als Befund da")
    }

    // MARK: - 4. Eine Uhr springt nicht rueckwaerts

    /// **Im Live-Betrieb kann es nicht mehr geschehen.** Der frueheren Fassung genuegte ein
    /// zweiter Rahmen von einem Dienst mit nachgehender Uhr: 22:07, eine Sekunde spaeter 22:04.
    /// Das passiert bei jedem Neustart des Dienstes auf einer Maschine ohne gestellte Uhr und in
    /// der Gegenrichtung, wenn dort NTP die Uhr nachtraeglich richtigstellt.
    func testDieAnzeigeuhrSpringtImLiveBetriebNichtZurueck() {
        // Der frueherer Weg: zurueck.
        let spaeter = geraeteuhr.addingTimeInterval(1)
        let vorherAlt = bestandsJetzt(geraet: geraeteuhr, versatz: 0)
        let nachherAlt = bestandsJetzt(
            geraet: spaeter,
            versatz: bestandsVersatz(
                serverzeit: spaeter.addingTimeInterval(-dreiMinuten), geraet: spaeter))
        XCTAssertLessThan(nachherAlt, vorherAlt, "der frueherer Weg liess sie zurueckspringen")

        // Die Regel: vorwaerts, und zwar genau um die verstrichene Sekunde.
        var uhr = Hausuhr()
        uhr.melde(serverzeit: geraeteuhr, geraetezeit: geraeteuhr, betrieb: .live)
        let vorher = uhr.anzeigezeit(geraeteuhr)
        uhr.melde(
            serverzeit: spaeter.addingTimeInterval(-dreiMinuten), geraetezeit: spaeter,
            betrieb: .live)
        let nachher = uhr.anzeigezeit(spaeter)
        XCTAssertGreaterThan(nachher, vorher)
        XCTAssertEqual(nachher.timeIntervalSince(vorher), 1, accuracy: 0.001)
    }

    /// **Und im Vorfuehrbetrieb, wo die Anzeigeuhr dem Dienst folgen muss, zaehlt die Richtung.**
    ///
    /// Der erste Rahmen stellt sie hin, wohin er will - auch um drei Tage zurueck, denn der
    /// Vorfuehrtag liegt oft Wochen zurueck (`Settings.demo_start`), und in diesem Augenblick
    /// sieht niemand auf eine laufende Uhr. Danach wird nur nach vorn uebernommen.
    func testDieAnzeigeuhrSpringtAuchInDerVorfuehrungNichtZurueck() {
        var uhr = Hausuhr()
        let demo: TimeInterval = -72 * 3600
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(demo), geraetezeit: geraeteuhr,
            betrieb: .vorfuehrung(tempo: 60))
        XCTAssertEqual(uhr.anzeigeversatz, demo, accuracy: 0.001, "der erste Rahmen stellt frei")
        XCTAssertNil(uhr.befund, "im Zeitraffer ist der Versatz der Zweck und kein Befund")

        // Ein Rahmen, der hinter die schon gezeigte Zeit zeigt, wird nicht uebernommen - die
        // Anzeigeuhr laeuft weiter, bis die Zeit es aufgeholt hat. Die Datenuhr folgt sofort.
        let spaeter = geraeteuhr.addingTimeInterval(1)
        uhr.melde(
            serverzeit: spaeter.addingTimeInterval(demo - dreiMinuten), geraetezeit: spaeter,
            betrieb: .vorfuehrung(tempo: 60))
        XCTAssertEqual(uhr.anzeigeversatz, demo, accuracy: 0.001, "kein Rueckschritt")
        XCTAssertEqual(uhr.versatz, demo - dreiMinuten, accuracy: 0.001, "die Daten folgen")
        XCTAssertGreaterThan(uhr.anzeigezeit(spaeter), uhr.anzeigezeit(geraeteuhr))

        // Nach vorn schon - sonst stuende der Zeitraffer still.
        uhr.melde(
            serverzeit: spaeter.addingTimeInterval(demo + 3600), geraetezeit: spaeter,
            betrieb: .vorfuehrung(tempo: 60))
        XCTAssertEqual(uhr.anzeigeversatz, demo + 3600, accuracy: 0.001)
    }

    /// **Nach einem Abriss darf der naechste Rahmen wieder frei stellen.**
    ///
    /// Ein neu gestarteter Vorfuehrdienst faengt seinen Tag von vorn an. Ohne diese Freigabe
    /// stuende die Wanduhr dann fuer die Laenge des Vorfuehrtags still - und eine eingefrorene
    /// Uhr ist schlimmer als eine, die beim Wiederverbinden einmal umspringt.
    func testNachEinemAbrissStelltDerNaechsteRahmenFrei() {
        var uhr = Hausuhr()
        uhr.melde(serverzeit: geraeteuhr, geraetezeit: geraeteuhr, betrieb: .vorfuehrung(tempo: 60))
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-3600), geraetezeit: geraeteuhr,
            betrieb: .vorfuehrung(tempo: 60))
        XCTAssertEqual(uhr.anzeigeversatz, 0, accuracy: 0.001, "ohne Abriss kein Rueckschritt")

        uhr.abgerissen()
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-3600), geraetezeit: geraeteuhr,
            betrieb: .vorfuehrung(tempo: 60))
        XCTAssertEqual(uhr.anzeigeversatz, -3600, accuracy: 0.001, "der Vorfuehrtag faengt von vorn an")
    }

    /// **Eine angehaltene Vorfuehrung darf ihre Uhr anhalten.**
    ///
    /// `sim_speed = 0` ist erlaubt und haelt die Simulation an, *ohne* die Verbindung zu loesen:
    /// ``Hausuhr/abgerissen()`` wird nie gerufen, `house.now` steht, und der gemeldete Abstand
    /// wird mit jeder verstrichenen Sekunde kleiner. Die Sperre nach hinten liess damit keinen
    /// Rahmen mehr durch - die grosse Uhr lief in Echtzeit davon und stand nach einer Stunde
    /// Pause eine Stunde vor dem angehaltenen Haus. Gemessen steht hier beides: der Fehler
    /// (`tempo: 60`, der alte Weg) und die Behebung (`tempo: 0`).
    func testEineAngehalteneVorfuehrungHaeltAuchDieUhrAn() {
        let demo: TimeInterval = -72 * 3600
        let stand = geraeteuhr.addingTimeInterval(demo)  // `house.now`, und es bleibt stehen
        let eineStundeSpaeter = geraeteuhr.addingTimeInterval(3600)

        // Der alte Weg, als Gegenbeispiel: mit laufendem Tempo wird der Rahmen nicht
        // uebernommen, weil er nach hinten zeigt - die Wanduhr laeuft dem Haus davon.
        var laeuft = Hausuhr()
        laeuft.melde(serverzeit: stand, geraetezeit: geraeteuhr, betrieb: .vorfuehrung(tempo: 60))
        laeuft.melde(
            serverzeit: stand, geraetezeit: eineStundeSpaeter, betrieb: .vorfuehrung(tempo: 60))
        XCTAssertEqual(
            laeuft.anzeigezeit(eineStundeSpaeter).timeIntervalSince(stand), 3600, accuracy: 0.001,
            "eine Stunde Pause, eine Stunde Vorsprung")

        // Angehalten: jeder Rahmen wird uebernommen, die Wanduhr steht auf dem Haus.
        var haelt = Hausuhr()
        haelt.melde(serverzeit: stand, geraetezeit: geraeteuhr, betrieb: .vorfuehrung(tempo: 0))
        haelt.melde(
            serverzeit: stand, geraetezeit: eineStundeSpaeter, betrieb: .vorfuehrung(tempo: 0))
        XCTAssertEqual(haelt.anzeigezeit(eineStundeSpaeter), stand, "die Uhr steht mit dem Haus")
        XCTAssertEqual(haelt.datenzeit(eineStundeSpaeter), stand)
        XCTAssertNil(haelt.befund, "und es ist kein Fehler, sondern eine Pause")
    }

    // MARK: - 5. Die Raender

    /// Ohne Betriebsmodus wird nicht entschieden - der Zustand kommt im selben Atemzug.
    ///
    /// Das ist der erste Herzschlag, wenn er dem ersten Augenblicksbild zuvorkommt: ohne diesen
    /// Zweig stuende im Vorfuehrbetrieb fuer einen Augenblick ein Befund da, der den ganzen
    /// Zeitraffer als Uhrfehler ausgibt.
    func testOhneModusWirdNichtsGestellt() {
        var uhr = Hausuhr()
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-dreiMinuten), geraetezeit: geraeteuhr,
            betrieb: .unbekannt)
        XCTAssertEqual(uhr.versatz, 0)
        XCTAssertEqual(uhr.anzeigeversatz, 0)
        XCTAssertNil(uhr.befund)
    }

    /// Ein unlesbarer Zeitstempel darf den Versatz nicht vergiften: aus `NaN` wird sonst ueberall
    /// „Invalid Date", und der naechste gute Rahmen macht den einmal weggeschriebenen Tag nicht
    /// wieder gut.
    func testUnendlichUndNaNAendernNichts() {
        var uhr = Hausuhr()
        uhr.melde(
            serverzeit: geraeteuhr.addingTimeInterval(-dreiMinuten), geraetezeit: geraeteuhr,
            betrieb: .live)
        let vorher = uhr

        for kaputt in [Date(timeIntervalSince1970: .nan), Date(timeIntervalSince1970: .infinity)] {
            uhr.melde(serverzeit: kaputt, geraetezeit: geraeteuhr, betrieb: .live)
            XCTAssertEqual(uhr, vorher, "der alte Stand bleibt stehen")
        }
    }

    /// **Grosse Betraege in grossen Einheiten.** „1440 Minuten" ist eine Zahl, die man erst
    /// nachrechnen muss, bevor man sie glaubt - und genau das stand hier bei einem iPad, dessen
    /// Uhr einen Tag falsch stand. Umgeschaltet wird bei anderthalb der naechsten Einheit,
    /// damit nach dem Umschalten nie „1 Stunde" dasteht, wo gerade noch „89 Minuten" stand.
    func testGrosseAbstaendeStehenInStundenUndTagen() {
        func satz(_ abstand: TimeInterval) -> String? {
            var uhr = Hausuhr()
            uhr.melde(
                serverzeit: geraeteuhr.addingTimeInterval(abstand), geraetezeit: geraeteuhr,
                betrieb: .live)
            return uhr.befund?.satz
        }

        XCTAssertEqual(satz(61)?.contains("eine Minute"), true)
        XCTAssertEqual(satz(90 * 60)?.contains("90 Minuten"), true, "bis anderthalb Stunden")
        XCTAssertEqual(satz(91 * 60)?.contains("2 Stunden"), true, "und nie eine einzelne Stunde")
        XCTAssertEqual(satz(24 * 3600)?.contains("24 Stunden"), true, "statt 1440 Minuten")
        XCTAssertEqual(satz(36 * 3600)?.contains("36 Stunden"), true, "bis anderthalb Tage")
        XCTAssertEqual(satz(-3 * 86400)?.contains("3 Tage"), true)
        XCTAssertEqual(satz(-3 * 86400)?.contains("der Dienst liegt zurück"), true)
    }

    /// Eine vorgestellte Uhr - fuer Vorschauen: beide Zeiten auf dem Nachmittag, zu dem die
    /// Zahlen passen.
    func testVorgestellteUhrGiltFuerBeideZeiten() {
        let uhr = Hausuhr(vorgestellt: -3600)
        XCTAssertEqual(uhr.datenzeit(geraeteuhr), geraeteuhr.addingTimeInterval(-3600))
        XCTAssertEqual(uhr.anzeigezeit(geraeteuhr), geraeteuhr.addingTimeInterval(-3600))
        XCTAssertNil(uhr.befund)
    }
}
