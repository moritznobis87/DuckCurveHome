import XCTest

@testable import DuckCurveKit

/// Dieselben Proben wie `apps/web/src/components/anlage/schema.test.ts`.
final class AnlagenschemaTests: XCTestCase {

    private let jetzt = Zeit.ausIso("2026-11-02T18:00:00Z")!

    private func vorMinuten(_ n: Int) -> String {
        Zeit.iso(jetzt.addingTimeInterval(-Double(n) * 60))
    }

    private func strom(pv: Double = 0, netz: Double = 0, speicher: Double = 0) -> AnlageStromOut {
        AnlageStromOut(sharePv: pv, shareGrid: netz, shareBattery: speicher)
    }

    // MARK: - Die Wasserfarbe

    func testDieSkalaKlemmtAnIhrenEnden() {
        XCTAssertEqual(Anlagenschema.farbe(0), Anlagenschema.farbe(10))
        XCTAssertEqual(Anlagenschema.farbe(90), Anlagenschema.farbe(65))
    }

    func testZwischenZweiStuetzstellenWirdGemischt() {
        // 40 °C liegt zwischen 35 (7F A3 B3) und 45 (FF D7 78), genau in der Mitte.
        let f = Anlagenschema.farbe(40)
        XCTAssertEqual(f.rot * 255, 191, accuracy: 0.6)
        XCTAssertEqual(f.gruen * 255, 189, accuracy: 0.6)
        XCTAssertEqual(f.blau * 255, 150, accuracy: 0.6)
    }

    func testOhneWertIstEsDasNeutraleBlaugrau() {
        XCTAssertEqual(Anlagenschema.farbe(nil), Anlagenschema.Farbwerte.netz)
        XCTAssertEqual(Anlagenschema.farbe(.nan), Anlagenschema.Farbwerte.netz)
    }

    // MARK: - An und aus

    func testDieRichtungVonNetzUndBatterie() {
        XCTAssertEqual(Anlagenschema.netzWort(3.4), "Bezug")
        XCTAssertEqual(Anlagenschema.netzWort(-1.1), "Einspeisung")
        XCTAssertEqual(Anlagenschema.netzWort(0.01), "ruht")
        XCTAssertEqual(Anlagenschema.netzWort(nil), "ruht")
        // Batterie positiv ist Entladung - dieselbe Vorzeichenregel wie im ganzen Haus.
        XCTAssertEqual(Anlagenschema.batterieWort(1.2), "entlädt")
        XCTAssertEqual(Anlagenschema.batterieWort(-1.2), "lädt")
        XCTAssertEqual(Anlagenschema.batterieWort(0.0), "ruht")
    }

    func testAnUndAusAnEinerSchwelle() {
        XCTAssertFalse(Anlagenschema.istAn(0.04))
        XCTAssertTrue(Anlagenschema.istAn(-0.05))
        XCTAssertFalse(Anlagenschema.istAn(nil))
        XCTAssertFalse(Anlagenschema.istAn(.nan))
    }

    // MARK: - Tempo der Lichtpunkte

    func testDasTempoWaechstMitDerLeistungInGrenzenUndAufHalbeSekunden() {
        XCTAssertEqual(Anlagenschema.rohrDauer(0.5), 9)
        XCTAssertEqual(Anlagenschema.rohrDauer(20), 2.5)
        XCTAssertEqual(Anlagenschema.rohrDauer(4), 4)
        XCTAssertEqual(Anlagenschema.rohrDauer(4, leise: true), 5)
    }

    func testZwischenZweiUndSiebenPunkte() {
        XCTAssertEqual(Anlagenschema.punktzahl(0.1), 2)
        XCTAssertEqual(Anlagenschema.punktzahl(9), 7)
        XCTAssertEqual(Anlagenschema.punktzahl(9, leise: true), 6)
    }

    func testEinStehendesRohrIstDuennUndEinLaufendesDicker() {
        XCTAssertEqual(Anlagenschema.rohrStaerke(nil), 4)
        XCTAssertEqual(Anlagenschema.rohrStaerke(0.01), 4)
        XCTAssertEqual(Anlagenschema.rohrStaerke(2), 7.8, accuracy: 1e-9)
        XCTAssertEqual(Anlagenschema.rohrStaerke(100), 14, accuracy: 1e-9, "Gedeckelt.")
    }

    // MARK: - Die Mischung

    func testSechsPunkteNachAnteilenUndVerschraenkt() {
        let m = Anlagenschema.mischung(strom(netz: 0.74, speicher: 0.26))
        XCTAssertEqual(m.farben.count, 6)
        XCTAssertEqual(m.farben.filter { $0 == Anlagenschema.Farbwerte.netz }.count, 4)
        XCTAssertEqual(m.farben.filter { $0 == Anlagenschema.Farbwerte.speicher }.count, 2)
        // Nicht blockweise: die beiden Speicherpunkte stehen nicht nebeneinander.
        let stellen = m.farben.enumerated()
            .filter { $0.element == Anlagenschema.Farbwerte.speicher }.map(\.offset)
        XCTAssertGreaterThan(abs(stellen[0] - stellen[1]), 1)
        XCTAssertEqual(m.haupt, Anlagenschema.Farbwerte.netz)
        XCTAssertEqual(m.text, "Netz 74\u{00a0}%, Speicher 26\u{00a0}%")
    }

    func testKleineAnteileStehenNichtImSatz() {
        XCTAssertEqual(Anlagenschema.mischung(strom(pv: 0.97, netz: 0.03)).text, "PV 97\u{00a0}%")
    }

    func testOhneQuellenIstDieMischungLeer() {
        let m = Anlagenschema.mischung(strom())
        XCTAssertTrue(m.farben.isEmpty)
        XCTAssertEqual(m.text, "")
        XCTAssertEqual(m.haupt, Anlagenschema.Farbwerte.netz)
    }

    // MARK: - Dauer

    func testDauerZaehltMinutenUndStunden() {
        XCTAssertEqual(Anlagenschema.dauerText(seit: vorMinuten(38), jetzt: jetzt), "38 min")
        XCTAssertEqual(Anlagenschema.dauerText(seit: vorMinuten(72), jetzt: jetzt), "1 h 12 min")
        XCTAssertEqual(Anlagenschema.dauerText(seit: vorMinuten(120), jetzt: jetzt), "2 h")
        XCTAssertEqual(Anlagenschema.dauerText(seit: nil, jetzt: jetzt), "")
        XCTAssertEqual(Anlagenschema.dauerText(seit: "unfug", jetzt: jetzt), "")
    }

    // MARK: - Die Sätze

    private func waermepumpe(laeuft: Bool, seit: String? = nil) -> AnlageWaermepumpeOut {
        AnlageWaermepumpeOut(running: laeuft, runningSince: seit, powerKw: 2.8)
    }

    private func ofen(
        da: Bool = true, laeuft: Bool? = false, stufe: Double? = nil, pumpe: Double? = nil
    ) -> AnlageOfenOut {
        AnlageOfenOut(present: da, running: laeuft, powerLevel: stufe, pumpPct: pumpe)
    }

    private func anlage(_ wp: AnlageWaermepumpeOut, _ o: AnlageOfenOut) -> AnlageOut {
        AnlageOut(
            at: Zeit.iso(jetzt), strom: strom(), waermepumpe: wp, ofen: o,
            speicher: AnlageSpeicherOut(
                tempsC: [], capacityKwh: 31.4, volumeLiters: 1000, netWord: ""),
            heizkreis: AnlageHeizkreisOut(roomsTotal: 0, roomsOpen: 0, running: false),
            warmwasser: AnlageWarmwasserOut(present: false))
    }

    func testDerSatzNenntDenErzeugerDerLaeuft() {
        XCTAssertEqual(
            Anlagenschema.erzeugerSatz(
                anlage(waermepumpe(laeuft: true, seit: vorMinuten(72)), ofen()), jetzt: jetzt),
            "Wärmepumpe läuft seit 1 h 12 min")
        XCTAssertEqual(
            Anlagenschema.erzeugerSatz(
                anlage(waermepumpe(laeuft: false), ofen(laeuft: true, stufe: 4)), jetzt: jetzt),
            "Ofen auf Stufe 4")
        XCTAssertEqual(
            Anlagenschema.erzeugerSatz(anlage(waermepumpe(laeuft: false), ofen()), jetzt: jetzt),
            "alle Erzeuger stehen")
    }

    func testDerSpeicherSagtWasErTut() {
        func sp(_ kw: Double?, _ wort: String) -> AnlageSpeicherOut {
            AnlageSpeicherOut(
                tempsC: [], capacityKwh: 31.4, volumeLiters: 1000, netKw: kw, netWord: wort)
        }
        XCTAssertEqual(Anlagenschema.nettoText(sp(1.2, "lädt")), "lädt 1,2 kW")
        XCTAssertEqual(
            Anlagenschema.nettoText(sp(-3.4, "entlädt")), "entlädt 3,4 kW",
            "Der Betrag - die Richtung steht im Wort.")
        XCTAssertEqual(Anlagenschema.nettoText(sp(0.05, "hält")), "hält")
        XCTAssertEqual(Anlagenschema.nettoText(sp(nil, "")), "")
    }

    func testDerOfenSagtEhrlichWasFehlt() {
        XCTAssertEqual(Anlagenschema.ofenStatus(ofen(da: false, laeuft: nil)), "nicht angebunden")
        XCTAssertEqual(
            Anlagenschema.ofenStatus(ofen(laeuft: nil)), "keine Verbindung",
            "Ein Ofen, der nicht meldet, ist nicht aus.")
        XCTAssertEqual(Anlagenschema.ofenStatus(ofen(laeuft: false)), "aus")
        XCTAssertEqual(
            Anlagenschema.ofenStatus(ofen(laeuft: true, stufe: 4, pumpe: 85)),
            "Stufe 4 · Pumpe 85 %")
        XCTAssertEqual(Anlagenschema.ofenStatus(ofen(laeuft: true)), "brennt")
    }

    func testWarmwasserUndHeizung() {
        XCTAssertEqual(
            Anlagenschema.warmwasserStatus(AnlageWarmwasserOut(present: false), jetzt: jetzt),
            "kein Fühler am Auslass")
        XCTAssertEqual(
            Anlagenschema.warmwasserStatus(
                AnlageWarmwasserOut(
                    present: true, outletC: 47, tapping: true, tappingSince: vorMinuten(2)),
                jetzt: jetzt),
            "Zapfung seit 2 min · Auslass")
        XCTAssertEqual(
            Anlagenschema.warmwasserStatus(
                AnlageWarmwasserOut(present: true, outletC: 27, tapping: false), jetzt: jetzt),
            "ruht · Auslass kühlt ab")

        XCTAssertEqual(
            Anlagenschema.heizungStatus(
                AnlageHeizkreisOut(roomsTotal: 0, roomsOpen: 0, running: false)),
            "keine Räume gemeldet", "Nicht „0 von 0“ - das ist eine Zahl ohne Messung.")
        XCTAssertEqual(
            Anlagenschema.heizungStatus(
                AnlageHeizkreisOut(roomsTotal: 9, roomsOpen: 7, openShare: 0.6, running: true)),
            "Räume nehmen Wärme")
        XCTAssertEqual(
            Anlagenschema.heizungStatus(
                AnlageHeizkreisOut(roomsTotal: 9, roomsOpen: 0, running: false)),
            "kein Raum nimmt Wärme")
    }

    // MARK: - Die Ziele

    func testJedesZielFuehrtAufEineSeiteDieEsGibt() {
        let wege = Set(Bereiche.alleWege)
        for z in Anlagenschema.Ziel.allCases {
            XCTAssertTrue(wege.contains(z.weg), "\(z.rawValue) zeigt auf \(z.weg)")
        }
    }

    func testDieZieleSindDieselbenWieAufDerStartseite() {
        XCTAssertEqual(Anlagenschema.Ziel.pv.weg, "/strom/pv")
        XCTAssertEqual(Anlagenschema.Ziel.netz.weg, "/strom")
        XCTAssertEqual(Anlagenschema.Ziel.batterie.weg, "/strom/speicher")
        XCTAssertTrue(Anlagenschema.Ziel.waermepumpe.weg.hasPrefix("/waerme"))
        XCTAssertEqual(Anlagenschema.Ziel.pv.ansage, "Photovoltaik. Details öffnen")
    }
}
