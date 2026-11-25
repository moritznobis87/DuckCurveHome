import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/settings/Mitteilungen.tsx` und
/// `apps/web/src/components/settings/Morgenbrief.tsx`.
///
/// **Warum hier so genau geprüft wird.** Die vier Stufen des Zustandssatzes sehen einander
/// ähnlich, und die falsche davon ist nicht halb richtig, sondern eine Lüge: „Noch keine
/// Mitteilung verschickt.“ unter einem Gerät, dem dreimal etwas zugestellt werden sollte,
/// verschweigt genau den Fehler, um dessentwillen die Zeile gebaut wurde
/// (`Mitteilungen.tsx:24-27`, der 12.11.2026).
final class MitteilungsstandTests: XCTestCase {

    private func geraet(
        label: String = "iPhone", seit: String? = nil, zuletztOk: String? = nil,
        fehlversuche: Int? = nil, letzterFehlerDe: String? = nil
    ) -> PushGeraetOut {
        PushGeraetOut(
            label: label, seit: seit, zuletztOk: zuletztOk, fehlversuche: fehlversuche,
            letzterFehlerDe: letzterFehlerDe)
    }

    private func brief(
        enabled: Bool = true, uhrzeit: String = "07:00", fuerDe: String? = "heute",
        titel: String? = "Morning Briefing", zeilen: [String] = ["4,2 kWh Sonne"],
        hinweisDe: String? = nil, zuletztDe: String? = nil, geraete: Int? = 1
    ) -> MorgenbriefOut {
        MorgenbriefOut(
            enabled: enabled, uhrzeit: uhrzeit, fuerDe: fuerDe, titel: titel, zeilen: zeilen,
            hinweisDe: hinweisDe, zuletztDe: zuletztDe, geraete: geraete)
    }

    // MARK: - Der Zustandssatz je Gerät (`Mitteilungen.tsx:64-71`)

    /// Stufe 1: ein letzter Fehler schlägt alles - auch einen Erfolg von vorher.
    func testLetzterFehlerSchlaegtDenLetztenErfolg() {
        let z = Mitteilungsstand.zeile(
            geraet(
                zuletztOk: "2026-11-07T06:12:00+01:00", fehlversuche: 2,
                letzterFehlerDe: "iPhone: Der Push-Dienst antwortet nicht (503)."))
        XCTAssertEqual(z.stand, "Der Push-Dienst antwortet nicht (503).")
        XCTAssertTrue(z.schlecht)
    }

    /// Der vorangestellte Gerätename fällt weg, der Name daneben steht ja schon da.
    func testVorsatzMitDemNamenFaelltWeg() {
        XCTAssertEqual(
            Mitteilungsstand.ohneVorsatz("iPad Küche: abgelaufen", name: "iPad Küche"),
            "abgelaufen")
        // Nur am Anfang und nur mit Doppelpunkt und Leerzeichen - sonst bleibt der Satz, wie er
        // ist. Ein Name, der mitten im Satz vorkommt, ist dort Inhalt.
        XCTAssertEqual(
            Mitteilungsstand.ohneVorsatz("Auf iPhone abgelehnt", name: "iPhone"),
            "Auf iPhone abgelehnt")
        XCTAssertEqual(Mitteilungsstand.ohneVorsatz("iPhone:kein Raum", name: "iPhone"),
            "iPhone:kein Raum")
    }

    /// Stufe 2: der letzte Erfolg, mit kurzem Datum **und** Uhrzeit (`:59`, `:67`).
    func testLetzterErfolgNenntDatumUndUhrzeit() {
        let z = Mitteilungsstand.zeile(geraet(zuletztOk: "2026-11-07T06:12:00+01:00"))
        XCTAssertEqual(z.stand, "Zuletzt angenommen am Sa., 07.11., 06:12.")
        XCTAssertFalse(z.schlecht)
    }

    /// Stufe 3: Versuche ohne jeden Erfolg - und die Einzahl ist eine andere als die Mehrzahl.
    func testVersucheOhneErfolgZaehlenInEinzahlUndMehrzahl() {
        XCTAssertEqual(
            Mitteilungsstand.zeile(geraet(fehlversuche: 1)).stand,
            "Noch keine Mitteilung angenommen, 1 Versuch gescheitert. Eine Probe zeigt den Grund.")
        XCTAssertEqual(
            Mitteilungsstand.zeile(geraet(fehlversuche: 3)).stand,
            "Noch keine Mitteilung angenommen, 3 Versuche gescheitert. Eine Probe zeigt den Grund."
        )
        XCTAssertTrue(Mitteilungsstand.zeile(geraet(fehlversuche: 3)).schlecht)
    }

    /// Stufe 4: der stille Fall. Kein Warnton - es ist nichts schiefgegangen.
    func testOhneAllesStehtDerStilleSatz() {
        let z = Mitteilungsstand.zeile(geraet())
        XCTAssertEqual(z.stand, "Noch keine Mitteilung verschickt.")
        XCTAssertFalse(z.schlecht)
    }

    /// Ein Erfolg und Fehlversuche zusammen: kein Warnton. Die Vorlage prüft
    /// `!g.zuletzt_ok && fehlversuche > 0` (`:71`) - was einmal ankam, ist nicht verloren.
    func testErfolgNebenAltenFehlversuchenWarntNicht() {
        let z = Mitteilungsstand.zeile(
            geraet(zuletztOk: "2026-11-07T06:12:00+01:00", fehlversuche: 4))
        XCTAssertEqual(z.stand, "Zuletzt angenommen am Sa., 07.11., 06:12.")
        XCTAssertFalse(z.schlecht)
    }

    /// Eine leere Zeichenkette ist wie ein fehlendes Feld - in JavaScript unwahr, hier `nil`.
    /// Ohne diese Regel stünde als Zustandssatz eine leere Zeile.
    func testLeereFelderSindWieFehlendeFelder() {
        let z = Mitteilungsstand.zeile(
            geraet(seit: "", zuletztOk: "", fehlversuche: 0, letzterFehlerDe: ""))
        XCTAssertEqual(z.stand, "Noch keine Mitteilung verschickt.")
        XCTAssertNil(z.seit)
        XCTAssertFalse(z.schlecht)
    }

    /// „angemeldet seit Sa., 07.11.“ - mit Tag, nicht als Uhrzeit. Die App zeigte hier
    /// `Formate.hhmm` und damit „seit 14:23“; der Tag fiel weg.
    func testSeitNenntDenTagUndNichtDieUhrzeit() {
        let z = Mitteilungsstand.zeile(geraet(seit: "2026-11-07T14:23:00+01:00"))
        XCTAssertEqual(z.seit, "angemeldet seit Sa., 07.11.")
        XCTAssertNil(Mitteilungsstand.zeile(geraet(seit: nil)).seit)
    }

    /// Die Reihenfolge des Dienstes bleibt, und der Schlüssel trennt zwei Geräte gleichen Namens.
    func testZeilenBehaltenDieReihenfolgeUndTrennenGleicheNamen() {
        let aus = Mitteilungsstand.zeilen(
            PushGeraeteOut(devices: [
                geraet(label: "iPhone", seit: "2026-11-07T08:00:00+01:00"),
                geraet(label: "iPhone", seit: "2026-11-08T08:00:00+01:00"),
            ]))
        XCTAssertEqual(aus.map(\.name), ["iPhone", "iPhone"])
        XCTAssertNotEqual(aus[0].id, aus[1].id)
    }

    func testZeilenHaltenEineLeereAntwortAus() {
        XCTAssertTrue(Mitteilungsstand.zeilen(PushGeraeteOut()).isEmpty)
        XCTAssertTrue(Mitteilungsstand.zeilen(PushGeraeteOut(devices: [])).isEmpty)
    }


    // MARK: - Die Lage dieses Geräts

    /// Bei `aus` steht kein Satz, sondern nur der Knopf (`Mitteilungen.tsx:222-226`).
    func testLageAusHatKeinenSatzAberDenKnopf() {
        XCTAssertNil(Mitteilungsstand.lagesatz(.aus).satz)
        XCTAssertTrue(Mitteilungsstand.darfEinschalten(.aus))
        for lage: Mitteilungsstand.Lage in [.verboten, .halb, .an, .fehler("x")] {
            XCTAssertFalse(Mitteilungsstand.darfEinschalten(lage))
        }
    }

    /// Angemeldet bestätigt und warnt nicht; alles andere warnt.
    func testNurDieAnmeldungBestaetigt() {
        let an = Mitteilungsstand.lagesatz(.an)
        XCTAssertEqual(an.satz, "Dieses Gerät ist angemeldet.")
        XCTAssertFalse(an.warnt)
        XCTAssertTrue(Mitteilungsstand.lagesatz(.verboten).warnt)
        XCTAssertTrue(Mitteilungsstand.lagesatz(.halb).warnt)
        XCTAssertEqual(Mitteilungsstand.lagesatz(.fehler("ohne Berechtigung")).satz,
            "ohne Berechtigung")
        XCTAssertTrue(Mitteilungsstand.lagesatz(.fehler("ohne Berechtigung")).warnt)
    }

    /// Der abgelehnte Fall nennt den Weg in die Einstellungen - der Satz der Vorlage, Wort für
    /// Wort (`Mitteilungen.tsx:214-218`).
    func testAbgelehntNenntDenWegInDieEinstellungen() {
        let satz = Mitteilungsstand.lagesatz(.verboten).satz
        XCTAssertEqual(
            satz,
            "Mitteilungen sind auf diesem Gerät abgelehnt. Zurücknehmen lässt sich das nur in "
                + "den Einstellungen des Geräts.")
    }

    /// Der Probeknopf: dieses Gerät schlägt die Liste, und ohne Antwort steht keiner da.
    func testProbeknopf() {
        XCTAssertEqual(Mitteilungsstand.probeknopf(lage: .an, geraete: nil), .diesesGeraet)
        XCTAssertEqual(Mitteilungsstand.probeknopf(lage: .an, geraete: 3), .diesesGeraet)
        XCTAssertEqual(Mitteilungsstand.probeknopf(lage: .aus, geraete: 2), .fremdeGeraete)
        XCTAssertEqual(Mitteilungsstand.probeknopf(lage: .verboten, geraete: 1), .fremdeGeraete)
        XCTAssertEqual(Mitteilungsstand.probeknopf(lage: .aus, geraete: 0), .keiner)
        // Solange die Abfrage nicht geantwortet hat, steht kein Knopf da (`:238`).
        XCTAssertEqual(Mitteilungsstand.probeknopf(lage: .aus, geraete: nil), .keiner)
    }

    // MARK: - Das Morning Briefing

    /// Der Einordnungssatz, und dass „morgen“ nie selbst dasteht.
    func testEinordnung() {
        XCTAssertEqual(
            Mitteilungsstand.einordnung(brief(fuerDe: "morgen")),
            "So sähe das Briefing morgen früh aus:")
        XCTAssertEqual(
            Mitteilungsstand.einordnung(brief(fuerDe: "heute")),
            "Das Briefing für heute:")
        // Ein unbekanntes oder fehlendes Wort fällt auf den heutigen Fall - wie `!== "morgen"`
        // in der Vorlage (`Morgenbrief.tsx:76`).
        XCTAssertEqual(
            Mitteilungsstand.einordnung(brief(fuerDe: nil)),
            "Das Briefing für heute:")
        XCTAssertFalse(Mitteilungsstand.einordnung(brief(fuerDe: nil)).contains("morgen früh"))
    }

    /// Die Uhrzeit steht im Satz, und ohne Antwort steht „07:00“ darin.
    func testBriefErklaerungSetztDieUhrzeitEinUndHatEinenRueckfall() {
        XCTAssertTrue(Mitteilungsstand.briefErklaerung(uhrzeit: "06:30")
            .hasPrefix("Jeden Morgen um 06:30 Uhr"))
        XCTAssertTrue(Mitteilungsstand.briefErklaerung(uhrzeit: nil)
            .hasPrefix("Jeden Morgen um 07:00 Uhr"))
        XCTAssertTrue(Mitteilungsstand.briefErklaerung(uhrzeit: "")
            .hasPrefix("Jeden Morgen um 07:00 Uhr"))
        // Derselbe Satz wie im Dashboard (`Morgenbrief.tsx`, `briefsatz`).
        XCTAssertEqual(
            Mitteilungsstand.briefErklaerung(uhrzeit: "07:00"),
            "Jeden Morgen um 07:00 Uhr: Sonne, Strompreis und Wärme des Tages.")
    }

    func testVorschautitelHatEinenRueckfall() {
        XCTAssertEqual(Mitteilungsstand.vorschautitel(brief(titel: "Guten Morgen")),
            "Guten Morgen")
        XCTAssertEqual(Mitteilungsstand.vorschautitel(brief(titel: nil)), "Morning Briefing")
        XCTAssertEqual(Mitteilungsstand.vorschautitel(brief(titel: "")), "Morning Briefing")
    }

    func testZustandUndSchaltwort() {
        XCTAssertEqual(Mitteilungsstand.briefZustand(an: true), "eingeschaltet")
        XCTAssertEqual(Mitteilungsstand.briefZustand(an: false), "ausgeschaltet")
        XCTAssertEqual(Mitteilungsstand.schaltwort(an: true), "Ausschalten")
        XCTAssertEqual(Mitteilungsstand.schaltwort(an: false), "Einschalten")
    }

    /// „Jetzt senden“ ist gesperrt, solange keine Zeilen da sind (`Morgenbrief.tsx:93`).
    func testSendenIstOhneZeilenGesperrt() {
        XCTAssertTrue(Mitteilungsstand.darfSenden(brief(zeilen: ["eine Zeile"])))
        XCTAssertFalse(Mitteilungsstand.darfSenden(brief(zeilen: [])))
    }

    /// Der Warnsatz nur bei eingeschaltetem Briefing und null Geräten (`Morgenbrief.tsx:99`).
    func testWarnungOhneGeraete() {
        XCTAssertTrue(Mitteilungsstand.warntOhneGeraete(brief(enabled: true, geraete: 0)))
        XCTAssertFalse(Mitteilungsstand.warntOhneGeraete(brief(enabled: true, geraete: 1)))
        XCTAssertFalse(Mitteilungsstand.warntOhneGeraete(brief(enabled: false, geraete: 0)))
        // Fehlt das Feld, ist nichts angemeldet - `stand.geraete ?? 0` in der Vorlage.
        XCTAssertTrue(Mitteilungsstand.warntOhneGeraete(brief(enabled: true, geraete: nil)))
    }

    func testHinweisNenntDenGrund() {
        XCTAssertEqual(Mitteilungsstand.hinweis("Zeitüberschreitung"),
            "Das hat nicht geklappt: Zeitüberschreitung")
    }

    /// Die festen Sätze im Wortlaut des Dashboards (`Mitteilungen.tsx`, `Morgenbrief.tsx`); seit
    /// dem 25.11.2026 kurz, ohne Erklärtexte.
    func testDieFestenSaetzeSagenDasselbeWieDasDashboard() {
        XCTAssertEqual(
            Mitteilungsstand.erklaerung, "Störungen und das Morning Briefing auf die angemeldeten Geräte.")
        XCTAssertEqual(
            Mitteilungsstand.ohneGeraete,
            "Kein Gerät angemeldet. Störungen und das Morning Briefing gehen an niemanden.")
        XCTAssertEqual(
            Mitteilungsstand.briefOhneGeraete, "Kein Gerät angemeldet. Das Briefing geht an niemanden.")
        XCTAssertEqual(Mitteilungsstand.briefKicker, "Morning Briefing")
        XCTAssertEqual(Mitteilungsstand.abgemeldet, "Dieses Gerät bekommt keine Mitteilungen mehr.")
        XCTAssertTrue(Mitteilungsstand.schaltenGescheitert.contains("unverändert"))
    }
}
