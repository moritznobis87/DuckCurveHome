import XCTest

@testable import DuckCurveKit

/// Die Worte der Anlageseite gegen die Vorlage: `Anlage.tsx:62-124`, `handy.css:400`,
/// `schema.ts:142-150`, `Schema.tsx:363-366`.
///
/// **Geprüft wird die Fuge, nicht der Satz.** Dass ein Satz dasteht, sieht man auf dem Gerät;
/// dass er an der richtigen Stelle *aufhört* - damit die Ansicht den nächsten Teil fett setzen
/// kann -, sieht man nur hier.
final class AnlagenworteTests: XCTestCase {

    private let jetzt = Zeit.ausIso("2026-11-02T18:00:00Z")!

    private func vorMinuten(_ n: Int) -> String {
        Zeit.iso(jetzt.addingTimeInterval(-Double(n) * 60))
    }

    private func speicher(
        nutzbar: Double? = nil, liter: Double = 1000, netto: Double? = nil, wort: String = ""
    ) -> AnlageSpeicherOut {
        AnlageSpeicherOut(
            usableKwh: nutzbar, capacityKwh: 31.4, volumeLiters: liter, netKw: netto,
            netWord: wort)
    }

    private func anlage(
        draussen: Double? = nil,
        strom: AnlageStromOut = AnlageStromOut(sharePv: 0, shareGrid: 0, shareBattery: 0),
        wpLaeuft: Bool = false,
        wpSeit: String? = nil,
        ofenLaeuft: Bool? = false,
        ofenStufe: Double? = nil
    ) -> AnlageOut {
        AnlageOut(
            at: Zeit.iso(jetzt),
            outdoorC: draussen,
            strom: strom,
            waermepumpe: AnlageWaermepumpeOut(running: wpLaeuft, runningSince: wpSeit),
            ofen: AnlageOfenOut(present: true, running: ofenLaeuft, powerLevel: ofenStufe),
            speicher: speicher(),
            heizkreis: AnlageHeizkreisOut(roomsTotal: 0, roomsOpen: 0, running: false),
            warmwasser: AnlageWarmwasserOut(present: false))
    }

    // MARK: - Der Takt und die Standzeile

    func testDerTaktIstZwanzigSekundenUndStehtInDerZeile() {
        XCTAssertEqual(Anlagenworte.taktSekunden, 20)
        XCTAssertEqual(
            Anlagenworte.standzeile(at: "2026-11-02T18:04:00Z"), "Stand 19:04 · alle 20 s",
            "Die Zeit des Hauses, nicht die des Geräts - 18:04 Z ist 19:04 in Berlin.")
    }

    func testOhneZeitstempelStehtDerStrichUndDerTaktTrotzdem() {
        // Ein Stand, den es nicht gibt, darf die Spanne nicht mitnehmen: der Takt gilt weiter.
        XCTAssertEqual(Anlagenworte.standzeile(at: nil), "Stand - · alle 20 s")
        XCTAssertEqual(Anlagenworte.standzeile(at: "kein Zeitstempel"), "Stand - · alle 20 s")
    }

    // MARK: - Die Kopfzeile in drei Teilen

    func testDieDreiTeileDerKopfzeile() {
        let t = Anlagenworte.kopfteile(
            anlage(
                draussen: 3.4,
                strom: AnlageStromOut(sharePv: 0.72, shareGrid: 0.28, shareBattery: 0),
                wpLaeuft: true, wpSeit: vorMinuten(72)),
            jetzt: jetzt)
        XCTAssertEqual(t.draussen, "3\u{202F}°C draußen")
        XCTAssertEqual(t.satz, "Wärmepumpe läuft seit 1 h 12 min", "Der fette Mittelteil.")
        XCTAssertEqual(t.mischung, "Strom aus PV 72\u{00a0}%, Netz 28\u{00a0}%")
        XCTAssertEqual(
            t.ganz, "3\u{202F}°C draußen · Wärmepumpe läuft seit 1 h 12 min · Strom aus PV 72\u{00a0}%, Netz 28\u{00a0}%")
    }

    func testDieAussentemperaturIstGanzzahlig() {
        // Die App schrieb hier eine Nachkommastelle; `Math.round` der Vorlage hat keine.
        XCTAssertEqual(Anlagenworte.kopfteile(anlage(draussen: 3.4), jetzt: jetzt).draussen, "3\u{202F}°C draußen")
        XCTAssertEqual(Anlagenworte.kopfteile(anlage(draussen: 3.5), jetzt: jetzt).draussen, "4\u{202F}°C draußen")
        XCTAssertEqual(
            Anlagenworte.kopfteile(anlage(draussen: -2.5), jetzt: jetzt).draussen,
            "\u{2212}3\u{202F}°C draußen",
            "Das Haus rundet vom Betrag weg; `Math.round(-2.5)` gäbe −2, und das wäre eine zweite Rundungsregel.")
    }

    func testOhneAussenfuehlerUndOhneFlussFehlenDieTeile() {
        let t = Anlagenworte.kopfteile(anlage(), jetzt: jetzt)
        XCTAssertNil(t.draussen, "Kein Fühler, keine Null.")
        XCTAssertNil(t.mischung, "Ohne Fluss nennt die Vorlage keine Anteile.")
        XCTAssertEqual(t.satz, "alle Erzeuger stehen")
        XCTAssertEqual(t.ganz, "alle Erzeuger stehen", "Keine Mittelpunkte um nichts.")
    }

    func testKleineQuellenFallenAuchImKopfWeg() {
        // Dieselbe Fünf-Prozent-Schwelle wie `Anlagenschema.mischung`.
        let t = Anlagenworte.kopfteile(
            anlage(strom: AnlageStromOut(sharePv: 0.97, shareGrid: 0.03, shareBattery: 0)), jetzt: jetzt)
        XCTAssertEqual(t.mischung, "Strom aus PV 97\u{00a0}%")
    }

    func testDerOfenKommtInDenSatzWennDieWaermepumpeSteht() {
        let t = Anlagenworte.kopfteile(anlage(ofenLaeuft: true, ofenStufe: 4), jetzt: jetzt)
        XCTAssertEqual(t.satz, "Ofen auf Stufe 4")
    }

    // MARK: - Das Glas

    func testDieFarbeZumWortDesSpeichers() {
        XCTAssertEqual(
            Anlagenworte.nettoFarbe(speicher(netto: 1.2, wort: "lädt")),
            Anlagenschema.Farbwerte.pvWeich)
        XCTAssertEqual(
            Anlagenworte.nettoFarbe(speicher(netto: -0.8, wort: "entlädt")),
            Anlagenschema.Farbwerte.speicher)
        XCTAssertEqual(
            Anlagenworte.nettoFarbe(speicher(wort: "hält")), Marken.last,
            "rgba(255,255,255,.62) ist `last` und nicht `text3` (0,48).")
        XCTAssertEqual(Anlagenworte.nettoFarbe(speicher(wort: "")), Marken.last)
        XCTAssertNotEqual(Anlagenworte.nettoFarbe(speicher(wort: "hält")), Marken.text3)
    }

    func testDieZeileUnterDemGlas() {
        XCTAssertEqual(
            Anlagenworte.glaszeile(speicher(nutzbar: 23.6, liter: 1000)),
            "24 kWh nutzbar · 1000 l", "Beide Zahlen ganz.")
        XCTAssertEqual(
            Anlagenworte.glaszeile(speicher(nutzbar: nil, liter: 1000)), "1000 l",
            "Ohne nutzbaren Inhalt entfällt der erste Teil samt Mittelpunkt.")
        XCTAssertEqual(
            Anlagenworte.glaszeile(speicher(nutzbar: 0, liter: 750.4)), "0 kWh nutzbar · 750 l",
            "Null ist ein gemessener Wert und kein fehlender.")
        XCTAssertEqual(Anlagenworte.glaszeile(speicher(nutzbar: .nan, liter: 1000)), "1000 l")
        XCTAssertFalse(
            Anlagenworte.glaszeile(speicher(nutzbar: 23.6)).contains("31"),
            "Die Fassung steht unter dem Glas nicht - das Glas ist die Fassung.")
    }

    // MARK: - Der Fuß

    func testDreiSpaltenMitDenUeberschriftenDerVorlage() {
        XCTAssertEqual(
            Anlagenworte.fussspalten.map(\.titel),
            ["Lesen", "Vier getrennte Systeme", "Gemessen und gerechnet"])
    }

    func testDerFussSchreibtUmlauteUndKeineErsatzschreibung() {
        let alles = Anlagenworte.fussspalten.map(\.text).joined(separator: " ")
        for ersatz in ["Fliess", "duenn", "Ruecklauf", "Waerme", "laeuft", "zurueck", "Fuehler", "geschaetzt"] {
            XCTAssertFalse(alles.contains(ersatz), "„\(ersatz)“ ist eine Ersatzschreibung.")
        }
        XCTAssertTrue(alles.contains("Wärmepumpe"))
        XCTAssertTrue(alles.contains("zurück"))
        XCTAssertTrue(alles.contains("Fühlern"))
        XCTAssertTrue(alles.contains("geschätzt"))
    }

    func testDieDreiAussagenDieDerAppFehlten() {
        let alles = Anlagenworte.fussspalten.map(\.text).joined(separator: " ")
        XCTAssertTrue(
            alles.contains("Jedes Gerät lässt sich antippen; dahinter liegt seine Seite, dieselbe wie von der Startseite aus."))
        XCTAssertTrue(alles.contains("Sie berühren sich nur im Speicher."))
        XCTAssertTrue(alles.contains("es hat keine Pumpe, der Leitungsdruck treibt es."))
    }

    func testDieHervorhebungenStehenAnDenStellenDerVorlage() {
        let betont = Anlagenworte.fussspalten.flatMap { $0.stuecke.filter(\.betont).map(\.text) }
        XCTAssertEqual(
            betont,
            [
                "Ofen", "Wärmepumpe", "Heizkreis", "Trinkwasser", "gemeinsam",
                "Nettoleistung des Speichers", "erkannt",
            ])
    }

    func testDieErsteSpalteHebtNichtsHervorUndIstEinStueck() {
        let lesen = Anlagenworte.fussspalten[0]
        XCTAssertEqual(lesen.stuecke.count, 1)
        XCTAssertFalse(lesen.stuecke.contains { $0.betont })
    }

    func testDieStueckeFuegenSichOhneLuckeUndOhneDoppeltesLeerzeichen() {
        for stueck in Anlagenworte.fussspalten {
            XCTAssertFalse(
                stueck.text.contains("  "), "Zwei Leerzeichen heißt eine Fuge zu viel: \(stueck.titel)")
            XCTAssertTrue(stueck.text.hasSuffix("."), "Jede Spalte endet mit einem Punkt.")
            XCTAssertFalse(stueck.text.hasPrefix(" "))
        }
    }

    // MARK: - Die festen Zeilen

    func testDerWischhinweisStehtWoertlichMitZweiLeerzeichenVorDemPfeil() {
        XCTAssertEqual(
            Anlagenworte.wischhinweis,
            "zur Seite wischen: Strom, Erzeuger, Speicher, Verbraucher  ›")
        XCTAssertTrue(Anlagenworte.wischhinweis.hasSuffix("Verbraucher  ›"))
        XCTAssertEqual(
            Anlagenworte.wischhinweis, Wiedergabeworte.wischhinweis,
            "Beide stammen aus derselben Regel (`handy.css:400`) - sie dürfen nicht auseinanderlaufen.")
    }

    func testBereichskickerUndWartesatz() {
        XCTAssertEqual(Anlagenworte.bereichskicker, "Strom · Speicher · vier Kreise")
        XCTAssertEqual(Anlagenworte.wartesatz, "Die Anlage wird geholt.")
    }
}
