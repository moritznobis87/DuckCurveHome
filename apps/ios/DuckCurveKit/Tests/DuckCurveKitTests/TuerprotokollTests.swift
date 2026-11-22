import XCTest

@testable import DuckCurveKit

/// Die Rechnungen der Haustürseite.
///
/// **Der Schwerpunkt liegt auf `outcome` gegen `granted`.** Das war der eigentliche Fehler der
/// alten Seite: sie zählte `granted` und gab damit abgelehnte und fehlgeschlagene Versuche als
/// Öffnungen aus. Die Fälle, in denen beide Felder auseinandergehen, sind deshalb hier mit
/// Absicht überrepräsentiert - sie sind der Alltag und nicht der Sonderfall.
final class TuerprotokollTests: XCTestCase {
    typealias T = Tuerprotokoll

    /// Freitag, 20. November 2026, 12:00 Hauszeit - der feste Bezugspunkt aller Tagesworte.
    private let jetzt = Zeit.ausIso("2026-11-20T12:00:00+01:00")!

    // MARK: - Das Verfahren als Wort

    func testDieVierVerfahrenDerVorlage() {
        XCTAssertEqual(T.verfahrenWort("FACE"), "Gesicht")
        XCTAssertEqual(T.verfahrenWort("NFC"), "Karte")
        XCTAssertEqual(T.verfahrenWort("PIN"), "Code")
        XCTAssertEqual(T.verfahrenWort("MOBILE_TAP"), "Telefon")
        XCTAssertEqual(T.verfahrenWort("BT"), "Telefon")
    }

    /// Verglichen wird in Großbuchstaben (`DoorLog.tsx:39`) - die Konsole schreibt nicht
    /// zugesichert groß.
    func testDieSchreibweiseDerKonsoleEntscheidetNichts() {
        XCTAssertEqual(T.verfahrenWort("face"), "Gesicht")
        XCTAssertEqual(T.verfahrenWort("Nfc"), "Karte")
        XCTAssertEqual(T.verfahrenWort("mobile_tap"), "Telefon")
    }

    func testUmLaufendeLeerzeichenWirdGetrimmt() {
        XCTAssertEqual(T.verfahrenWort("  PIN  "), "Code")
        XCTAssertEqual(T.verfahrenWort("\tBT\n"), "Telefon")
    }

    /// **Ein unbekanntes Verfahren steht roh da und wird nicht verschwiegen.** „KEYPAD“
    /// beantwortet „wie denn?“ immer noch halbwegs; „unbekannt“ wäre dort weniger.
    func testEinUnbekanntesVerfahrenStehtGetrimmtDa() {
        XCTAssertEqual(T.verfahrenWort(" KEYPAD "), "KEYPAD")
        XCTAssertEqual(T.verfahrenWort("Schlüssel"), "Schlüssel")
    }

    func testOhneVerfahrenStehtUnbekannt() {
        XCTAssertEqual(T.verfahrenWort(""), "unbekannt")
        XCTAssertEqual(T.verfahrenWort("   "), "unbekannt")
    }

    func testDerSatzSetztDasWoertchenDavor() {
        XCTAssertEqual(T.verfahrenSatz("FACE"), "per Gesicht")
        XCTAssertEqual(T.verfahrenSatz(""), "per unbekannt")
    }

    // MARK: - Der Name

    func testEinLeererNameWirdUnbekannt() {
        XCTAssertEqual(T.name(""), "unbekannt")
    }

    /// Nicht getrimmt, anders als beim Verfahren: die Vorlage prüft mit `||` und nicht auf
    /// Leerzeichen (`DoorLog.tsx:65`).
    func testEinNameAusLeerzeichenBleibtStehen() {
        XCTAssertEqual(T.name(" "), " ")
        XCTAssertEqual(T.name("Anna"), "Anna")
    }

    // MARK: - Der Ton kommt aus `outcome`

    func testDieDreiWorteDerBridge() {
        XCTAssertEqual(T.ton("geöffnet"), .geoeffnet)
        XCTAssertEqual(T.ton("abgelehnt"), .abgelehnt)
        XCTAssertEqual(T.ton("fehlgeschlagen"), .fehlgeschlagen)
    }

    /// Der Rückfall des Dienstes für eine Zeile aus einer früheren Fassung der Bridge
    /// (`system.py:211`) ist keine Öffnung und kein Defekt.
    func testUnbekanntUndLeerSindEineAblehnung() {
        XCTAssertEqual(T.ton("unbekannt"), .abgelehnt)
        XCTAssertEqual(T.ton(""), .abgelehnt)
        XCTAssertEqual(T.ton("GEÖFFNET"), .abgelehnt)
    }

    /// **Der Umlaut darf nicht an der Schreibweise hängen.** „geöffnet“ kommt als UTF-8 über
    /// das Netz und kann zerlegt ankommen (o + U+0308). Swift vergleicht kanonisch - dieser
    /// Test hält fest, dass wir uns darauf verlassen, statt die Bytes zu vergleichen.
    func testDerZerlegteUmlautZaehltAuchAlsOeffnung() {
        XCTAssertEqual(T.ton("geo\u{0308}ffnet"), .geoeffnet)
    }

    // MARK: - Die Zählung, und warum nicht über `granted`

    /// Der Fehler der alten Seite, in einem Test: drei Einträge, bei allen drei steht `granted`
    /// auf wahr, und nur einer ist eine Öffnung. Die Bridge setzt `granted` nach der
    /// Entscheidung der Konsole und lehnt danach selbst noch ab oder scheitert am Schloss
    /// (`door.py:101-109,144`).
    func testGrantedZaehltNicht() {
        let e = [
            eintrag(outcome: "geöffnet", granted: true),
            eintrag(outcome: "abgelehnt", granted: true),
            eintrag(outcome: "fehlgeschlagen", granted: true),
        ]
        let z = T.zaehlung(e)
        XCTAssertEqual(z.geoeffnet, 1)
        XCTAssertEqual(z.abgelehnt, 1)
        XCTAssertEqual(z.fehlgeschlagen, 1)
    }

    /// Und umgekehrt: `granted` falsch, `outcome` „geöffnet“ wäre ein Widerspruch - gezählt
    /// wird trotzdem, was die Tür getan hat.
    func testAuchOhneGrantedZaehltDasErgebnis() {
        XCTAssertEqual(T.zaehlung([eintrag(outcome: "geöffnet", granted: false)]).geoeffnet, 1)
    }

    func testLeeresProtokollZaehltDreiNullen() {
        let z = T.zaehlung([])
        XCTAssertEqual(z.geoeffnet, 0)
        XCTAssertEqual(z.abgelehnt, 0)
        XCTAssertEqual(z.fehlgeschlagen, 0)
    }

    /// Die Zahl „geöffnet“ muss dieselbe sein, die der Satz des Dienstes nennt - er zählt über
    /// `outcome == "geöffnet"` (`system.py:189`). Vorher war sie es nicht.
    func testDieOeffnungenStimmenMitDemSatzDesDienstes() {
        let e = (0..<5).map { i in
            eintrag(outcome: i < 2 ? "geöffnet" : "abgelehnt", granted: true)
        }
        XCTAssertEqual(T.zaehlung(e).geoeffnet, 2)
    }

    // MARK: - Die Kacheln

    func testDieDreiKachelnStehenInFesterReihenfolge() {
        let k = T.kacheln([])
        XCTAssertEqual(k.map(\.wort), ["Öffnungen", "abgewiesen", "fehlgeschlagen"])
        XCTAssertEqual(k.map(\.wert), ["0", "0", "0"])
    }

    /// Bei null bleibt die Kachel farblos: nur ein wirklich abgewiesener Versuch ist eine
    /// Nachricht.
    func testOhneAbweisungTraegtKeineKachelFarbe() {
        XCTAssertEqual(T.kacheln([eintrag(outcome: "geöffnet")]).map(\.hervor), [.keine, .keine, .keine])
    }

    func testEineAbweisungFaerbtGenauIhreKachel() {
        let k = T.kacheln([eintrag(outcome: "abgelehnt")])
        XCTAssertEqual(k.map(\.hervor), [.keine, .achtung, .keine])
        XCTAssertEqual(k[1].wert, "1")
    }

    /// Ein Fehlschlag ist ein Defekt und kein Abweisen - er bekommt die stärkere Stufe
    /// (`DoorLog.tsx:68-69`).
    func testEinFehlschlagBekommtDieStaerkereStufe() {
        let k = T.kacheln([eintrag(outcome: "fehlgeschlagen")])
        XCTAssertEqual(k.map(\.hervor), [.keine, .keine, .alarm])
    }

    // MARK: - Die Begründung

    func testBeiEinerOeffnungStehtKeineBegruendung() {
        let e = eintrag(outcome: "geöffnet", reason: "Anna an „Haustür“ per NFC.")
        XCTAssertNil(T.begruendung(e))
    }

    func testBeiAblehnungUndFehlschlagStehtSieDa() {
        XCTAssertEqual(
            T.begruendung(eintrag(outcome: "abgelehnt", reason: "Person nicht freigegeben.")),
            "Person nicht freigegeben.")
        XCTAssertEqual(
            T.begruendung(eintrag(outcome: "fehlgeschlagen", reason: "Zeitüberschreitung.")),
            "Zeitüberschreitung.")
    }

    func testEineLeereBegruendungIstKeine() {
        XCTAssertNil(T.begruendung(eintrag(outcome: "abgelehnt", reason: "")))
    }

    // MARK: - Die Tagesworte

    func testHeuteUndGestern() {
        XCTAssertEqual(T.tagwort("2026-11-20", jetzt: jetzt), "Heute")
        XCTAssertEqual(T.tagwort("2026-11-19", jetzt: jetzt), "Gestern")
    }

    /// Älter als gestern: Wochentag ausgeschrieben, Monat ausgeschrieben, kein Jahr.
    func testAelterAlsGesternStehtDasLangeDatum() {
        XCTAssertEqual(T.tagwort("2026-11-03", jetzt: jetzt), "Dienstag, 3. November")
        XCTAssertEqual(T.tagwort("2026-11-18", jetzt: jetzt), "Mittwoch, 18. November")
    }

    /// **„Morgen“ gibt es nicht.** ``Tag/nameRelativ(_:jetzt:)`` kennt das Wort, die Vorlage
    /// nicht - und ein Zutritt von morgen wäre eine falsche Auskunft über eine kaputte Uhr.
    func testMorgenWirdNichtGesagt() {
        XCTAssertEqual(T.tagwort("2026-11-21", jetzt: jetzt), "Samstag, 21. November")
    }

    func testOhneLesbarenTagStehtOhneDatum() {
        XCTAssertEqual(T.tagwort("", jetzt: jetzt), "ohne Datum")
        XCTAssertEqual(T.tagwort("2026-02-30", jetzt: jetzt), "ohne Datum")
    }

    // MARK: - Die Gruppen

    func testLeeresProtokollGibtKeineGruppe() {
        XCTAssertTrue(T.gruppen([], jetzt: jetzt).isEmpty)
    }

    func testEinTagIstEineGruppeUndDieReihenfolgeBleibt() {
        let e = [
            eintrag(at: "2026-11-20T18:40:00+01:00", actor: "Anna"),
            eintrag(at: "2026-11-20T07:12:00+01:00", actor: "Bert"),
        ]
        let g = T.gruppen(e, jetzt: jetzt)
        XCTAssertEqual(g.count, 1)
        XCTAssertEqual(g[0].tag, "2026-11-20")
        XCTAssertEqual(g[0].wort, "Heute")
        XCTAssertEqual(g[0].eintraege.map(\.actor), ["Anna", "Bert"])
    }

    /// **Mitternacht trennt.** Zwei Einträge zehn Minuten auseinander, aber auf zwei
    /// Kalendertagen - das ist der Fall, für den die Gruppierung überhaupt gebaut ist.
    func testUeberMitternachtEntstehenZweiGruppen() {
        let e = [
            eintrag(at: "2026-11-19T00:10:00+01:00", actor: "spät"),
            eintrag(at: "2026-11-18T23:50:00+01:00", actor: "früh"),
        ]
        let g = T.gruppen(e, jetzt: jetzt)
        XCTAssertEqual(g.map(\.tag), ["2026-11-19", "2026-11-18"])
        XCTAssertEqual(g.map(\.wort), ["Gestern", "Mittwoch, 18. November"])
        XCTAssertEqual(g.map { $0.eintraege.count }, [1, 1])
    }

    /// **Der Tag ist der der Hauszeit.** Derselbe Augenblick, in UTC geschrieben: 23:30Z im
    /// November ist in Berlin 00:30 des Folgetags. Rechnete die App in der Zeit des Geräts,
    /// wanderte der Zutritt für den Urlauber in den Vortag.
    func testDerTagIstDerDesHausesUndNichtDerDesGeraets() {
        let g = T.gruppen([eintrag(at: "2026-11-17T23:30:00Z")], jetzt: jetzt)
        XCTAssertEqual(g.map(\.tag), ["2026-11-18"])
    }

    /// Nicht sortiert, nur zusammengefasst: verglichen wird mit der letzten Gruppe, wie
    /// `groupByDay` (`DoorLog.tsx:48-57`). Kommt ein Tag zweimal, steht er zweimal - und beide
    /// Gruppen bleiben unterscheidbar.
    func testEinTagZweimalGibtZweiGruppenMitVerschiedenenSchluesseln() {
        let e = [
            eintrag(at: "2026-11-18T10:00:00+01:00"),
            eintrag(at: "2026-11-17T10:00:00+01:00"),
            eintrag(at: "2026-11-18T09:00:00+01:00"),
        ]
        let g = T.gruppen(e, jetzt: jetzt)
        XCTAssertEqual(g.map(\.tag), ["2026-11-18", "2026-11-17", "2026-11-18"])
        XCTAssertEqual(Set(g.map(\.id)).count, 3)
    }

    /// Ein unlesbarer Zeitstempel lässt die Zeile stehen, statt sie zu verschlucken: wer die
    /// Zahl im Satz des Dienstes nachzählt, soll dieselbe Zahl Zeilen finden.
    func testEinUnlesbarerZeitstempelVerliertKeineZeile() {
        let e = [
            eintrag(at: "2026-11-20T08:00:00+01:00"),
            eintrag(at: "", actor: "ohne Stempel"),
        ]
        let g = T.gruppen(e, jetzt: jetzt)
        XCTAssertEqual(g.map(\.wort), ["Heute", "ohne Datum"])
        XCTAssertEqual(g.flatMap { $0.eintraege }.count, 2)
    }

    // MARK: - Die Spannen

    /// Die Spannen der Vorlage (`DoorLog.tsx:22`) und ihre Vorgabe (`:80`), die zugleich die
    /// Annahme des Dienstes ist (`system.py:169`).
    func testSpannenUndVorgabe() {
        XCTAssertEqual(T.spannen, [7, 14, 30])
        XCTAssertEqual(T.vorgabe, 14)
        XCTAssertTrue(T.spannen.contains(T.vorgabe))
    }

    // MARK: - Werkzeug

    private func eintrag(
        at: String = "2026-11-20T07:12:00+01:00", actor: String = "Anna",
        door: String = "Haustür", method: String = "NFC", outcome: String = "geöffnet",
        granted: Bool = true, reason: String = ""
    ) -> DoorEntryOut {
        DoorEntryOut(
            at: at, actor: actor, door: door, method: method, outcome: outcome,
            granted: granted, reason: reason)
    }
}
