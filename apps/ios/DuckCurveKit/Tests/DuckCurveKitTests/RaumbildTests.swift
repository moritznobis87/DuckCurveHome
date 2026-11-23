import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/rooms/RoomsReport.tsx:383-408` (die Zeilen der
/// Tabelle) und `:513-547` (ihre Spalten).
final class RaumbildTests: XCTestCase {
    typealias R = Raumabweichung

    // MARK: - Reihen bauen

    private func reihe(
        id: Int = 1, name: String = "Wohnen", etage: String = "EG", kreise: Int = 4,
        ist: [Double?], soll: [Double?]? = nil, versatz: [Double?]? = nil,
        ventil: [Double?]? = nil, fenster: [Double?]? = nil
    ) -> RoomSeriesOut {
        RoomSeriesOut(
            id: id, name: name, floor: etage, circuits: kreise, tempC: ist,
            setpointC: soll ?? ist.map { _ in 21.0 },
            offsetK: versatz ?? ist.map { _ in 0.0 },
            valve: ventil ?? ist.map { _ in nil },
            window: fenster ?? ist.map { _ in nil })
    }

    private func verlauf(_ reihen: [RoomSeriesOut], schrittMin: Int = 15) -> RoomHistoryOut {
        let anzahl = reihen.first?.tempC.count ?? 0
        let ab = Zeit.ausIso("2026-11-17T00:00:00+01:00")!
        return RoomHistoryOut(
            start: "2026-11-17T00:00:00+01:00", end: "2026-11-18T00:00:00+01:00",
            stepMin: schrittMin,
            ts: (0..<anzahl).map {
                Zeit.iso(ab.addingTimeInterval(Double($0 * schrittMin * 60)))
            },
            rooms: reihen)
    }

    private func raum(
        id: Int = 1, name: String = "Wohnen", etage: String = "EG", kreise: Int = 4,
        ist: Double? = nil, soll: Double? = nil, versatz: Double? = nil, ziel: Double? = nil,
        ventil: Double? = nil, abweichung: Double? = nil
    ) -> RoomLiveOut {
        RoomLiveOut(
            id: id, name: name, floor: etage, circuits: kreise, tempC: ist, setpointC: soll,
            offsetK: versatz, targetC: ziel, humidityPct: nil, valve: ventil, window: nil,
            deviationK: abweichung, observedAt: "2026-11-17T14:00:00+01:00", quality: .ok)
    }

    private func istwerte(_ raeume: [RoomLiveOut], benannt: Bool = true) -> RoomsLiveOut {
        RoomsLiveOut(at: "2026-11-17T14:00:00+01:00", named: benannt, rooms: raeume)
    }

    // MARK: - Der letzte Stand

    /// **Der Fehler, den dieser Test festhaelt.** Die Seite rechnete statt des letzten Standes
    /// ein Tagesmittel - ein Raum, der morgens kalt war und abends am Ziel steht, sah damit
    /// aus wie einer, der dauernd ein halbes Grad fehlt.
    func testDerLetzteStandIstDerLetzteGemesseneUndNichtDerLetzteDerReihe() {
        let r = reihe(ist: [19.0, 19.5, 20.5, nil, nil])
        let stand = R.letzterStand(reihe: r)
        XCTAssertEqual(stand?.stelle, 2)
        XCTAssertEqual(stand?.ist, 20.5)
    }

    func testEinRaumDerDenGanzenTagSchweigtHatKeinenStand() {
        XCTAssertNil(R.letzterStand(reihe: reihe(ist: [nil, nil, nil])))
        XCTAssertNil(R.letzterStand(reihe: reihe(ist: [])))
    }

    func testDerStandRechnetDasZielAusSollwertUndVersatz() {
        let r = reihe(ist: [20.4], soll: [21.0], versatz: [-0.3])
        let stand = R.letzterStand(reihe: r)
        XCTAssertEqual(stand?.soll, 21.0)
        XCTAssertEqual(stand?.versatz, -0.3)
        XCTAssertEqual(stand?.ziel, 20.7)
        XCTAssertEqual(stand?.abweichung ?? 0, -0.3, accuracy: 1e-9)
    }

    func testOhneSollwertBleibtZielUndAbweichungOffenObwohlGemessenWurde() {
        let stand = R.letzterStand(reihe: reihe(ist: [20.4], soll: [nil], versatz: [-0.3]))
        XCTAssertEqual(stand?.ist, 20.4)
        XCTAssertNil(stand?.ziel)
        XCTAssertNil(stand?.abweichung, "Ohne Ziel gibt es keine Abweichung, auch keine von null.")
    }

    func testAlleZahlenDesStandesKommenAusDemselbenFenster() {
        let r = reihe(
            ist: [19.0, 20.0, nil], soll: [21.0, 22.0, 22.0], versatz: [0.0, 0.5, 0.5],
            ventil: [1.0, 0.25, 1.0], fenster: [0.0, 1.0, 0.0])
        let stand = R.letzterStand(reihe: r)
        XCTAssertEqual(stand?.stelle, 1)
        XCTAssertEqual(stand?.soll, 22.0)
        XCTAssertEqual(stand?.versatz, 0.5)
        XCTAssertEqual(stand?.ventil, 0.25)
        XCTAssertEqual(stand?.fenster, 1.0)
    }

    func testEineKuerzereNebenreiheLaesstNurIhrenWertFehlen() {
        let r = RoomSeriesOut(
            id: 1, name: "Bad", floor: "OG", circuits: 2, tempC: [20.0, 20.5],
            setpointC: [21.0], offsetK: [], valve: [0.5], window: [])
        let stand = R.letzterStand(reihe: r)
        XCTAssertEqual(stand?.stelle, 1)
        XCTAssertEqual(stand?.ist, 20.5)
        XCTAssertNil(stand?.soll)
        XCTAssertNil(stand?.ventil)
    }

    func testBisStelleHaeltDenStandInDerVergangenheit() {
        let r = reihe(ist: [19.0, 19.5, 20.0, 20.5, 21.0])
        let stand = R.letzterStand(reihe: r, bisStelle: 2)
        XCTAssertEqual(stand?.stelle, 1, "Stelle 2 ist noch nicht gewesen.")
        XCTAssertEqual(stand?.ist, 19.5)
    }

    func testVorDemErstenFensterGibtEsNochKeinenStand() {
        XCTAssertNil(R.letzterStand(reihe: reihe(ist: [19.0, 20.0]), bisStelle: 0))
    }

    func testEinBisStelleHinterDemEndeDerReiheSchadetNicht() {
        let stand = R.letzterStand(reihe: reihe(ist: [19.0, 20.0]), bisStelle: 999)
        XCTAssertEqual(stand?.stelle, 1)
    }

    // MARK: - Das Mittel der Ventilreihe

    func testDasVentilMittelZaehltNurDieGemessenenFenster() {
        XCTAssertEqual(R.anteilMittel([1.0, nil, 0.0]), 0.5)
        XCTAssertEqual(R.anteilMittel([nil, 0.25, nil, 0.75]), 0.5)
    }

    func testEinGeschlossenesVentilIstEinMesswertUndKeineLuecke() {
        XCTAssertEqual(R.anteilMittel([0.0, 0.0, 0.0]), 0.0)
        XCTAssertEqual(R.anteilText(R.anteilMittel([0.0, 0.0])), "zu")
        XCTAssertEqual(R.anteilText(R.anteilMittel([nil, nil])), "kein Messwert")
    }

    func testOhneEinenEinzigenMesswertGibtEsKeinVentilmittel() {
        XCTAssertNil(R.anteilMittel([]))
        XCTAssertNil(R.anteilMittel([nil, nil]))
    }

    // MARK: - Die Zeilen der Tabelle

    func testAmLaufendenTagTragenDieIstwerteDieZeilen() {
        let live = istwerte([raum(ist: 21.4, soll: 21.0, versatz: 0.3, ziel: 21.3, abweichung: 0.1)])
        let zeilen = R.tabellenzeilen(
            live: live, tag: verlauf([reihe(ist: [18.0, 18.5])]), istHeute: true)
        XCTAssertEqual(zeilen.count, 1)
        XCTAssertEqual(zeilen[0].ist, 21.4, "Heute kommt der Istwert aus /rooms, nicht aus der Reihe.")
        XCTAssertEqual(zeilen[0].ziel, 21.3)
        XCTAssertEqual(zeilen[0].abweichung, 0.1)
    }

    func testAnEinemVergangenenTagKommenDieZeilenAusDerTagesreihe() {
        let live = istwerte([raum(ist: 21.4, ziel: 21.3, abweichung: 0.1)])
        let tag = verlauf([reihe(ist: [18.0, 19.5, nil], soll: [20.0, 20.0, 20.0])])
        let zeilen = R.tabellenzeilen(live: live, tag: tag, istHeute: false)
        XCTAssertEqual(zeilen[0].ist, 19.5, "Gestern sagen die heutigen Istwerte nichts.")
        XCTAssertEqual(zeilen[0].ziel, 20.0)
        XCTAssertEqual(zeilen[0].abweichung ?? 0, -0.5, accuracy: 1e-9)
    }

    func testDerZielwertHeuteIstSollwertPlusVersatzWennDerDienstKeinenSchickt() {
        let live = istwerte([raum(ist: 20.4, soll: 21.0, versatz: -0.3, ziel: nil)])
        let zeilen = R.tabellenzeilen(live: live, tag: nil, istHeute: true)
        XCTAssertEqual(zeilen[0].ziel ?? 0, 20.7, accuracy: 1e-9)
        XCTAssertEqual(zeilen[0].abweichung ?? 0, -0.3, accuracy: 1e-9)
        XCTAssertEqual(zeilen[0].soll, 21.0, "Soll und Versatz stehen einzeln daneben.")
        XCTAssertEqual(zeilen[0].versatz, -0.3)
    }

    func testDasVentilAmTagKommtAuchHeuteAusDerTagesreihe() {
        let live = istwerte([raum(ist: 21.0, ventil: 1.0)])
        let tag = verlauf([reihe(ist: [20.0, 20.0], ventil: [1.0, 0.0])])
        let zeilen = R.tabellenzeilen(live: live, tag: tag, istHeute: true)
        XCTAssertEqual(zeilen[0].tagesventil, 0.5, "Nicht der Augenblickswert 1,0 aus /rooms.")
    }

    func testDasVentilAmTagWirdUeberDieKennungZugeordnetUndNichtUeberDenPlatz() {
        let live = istwerte([raum(id: 7, name: "Bad"), raum(id: 3, name: "Wohnen")])
        let tag = verlauf([
            reihe(id: 3, name: "Wohnen", ist: [20.0, 20.0], ventil: [0.0, 0.0]),
            reihe(id: 7, name: "Bad", ist: [20.0, 20.0], ventil: [1.0, 1.0]),
        ])
        let zeilen = R.tabellenzeilen(live: live, tag: tag, istHeute: true)
        XCTAssertEqual(zeilen.map(\.id), [7, 3])
        XCTAssertEqual(zeilen[0].tagesventil, 1.0)
        XCTAssertEqual(zeilen[1].tagesventil, 0.0)
    }

    func testEinRaumOhneTagesreiheHatKeinVentilAmTag() {
        let zeilen = R.tabellenzeilen(
            live: istwerte([raum(ist: 21.0, ventil: 1.0)]), tag: nil, istHeute: true)
        XCTAssertNil(zeilen[0].tagesventil)
        XCTAssertEqual(R.anteilText(zeilen[0].tagesventil), "kein Messwert")
    }

    func testDieReihenfolgeDerRaeumeIstDieDerAnlageUndNichtAlphabetisch() {
        let live = istwerte([
            raum(id: 1, name: "Wohnen"), raum(id: 2, name: "Bad"), raum(id: 3, name: "Küche"),
        ])
        XCTAssertEqual(
            R.tabellenzeilen(live: live, tag: nil, istHeute: true).map(\.name),
            ["Wohnen", "Bad", "Küche"])

        let tag = verlauf([
            reihe(id: 1, name: "Wohnen", ist: [20.0]), reihe(id: 2, name: "Bad", ist: [20.0]),
            reihe(id: 3, name: "Küche", ist: [20.0]),
        ])
        XCTAssertEqual(
            R.tabellenzeilen(live: nil, tag: tag, istHeute: false).map(\.name),
            ["Wohnen", "Bad", "Küche"])
    }

    func testOhneRaeumeGibtEsKeineZeilen() {
        XCTAssertTrue(R.tabellenzeilen(live: nil, tag: nil, istHeute: true).isEmpty)
        XCTAssertTrue(R.tabellenzeilen(live: nil, tag: nil, istHeute: false).isEmpty)
        XCTAssertTrue(
            R.tabellenzeilen(live: istwerte([]), tag: verlauf([]), istHeute: true).isEmpty)
    }

    func testFehltHeuteDieIstwertabfrageTraegtDieTagesreiheDieTabelle() {
        let tag = verlauf([reihe(ist: [19.0, 20.0], soll: [21.0, 21.0])])
        let zeilen = R.tabellenzeilen(live: nil, tag: tag, istHeute: true)
        XCTAssertEqual(zeilen.count, 1, "Eine gescheiterte Abfrage heisst nicht „keine Räume“.")
        XCTAssertEqual(zeilen[0].ist, 20.0)
    }

    func testEineLeereIstwertantwortLeertDieTabelleNicht() {
        let tag = verlauf([reihe(ist: [19.0, 20.0])])
        let zeilen = R.tabellenzeilen(live: istwerte([]), tag: tag, istHeute: true)
        XCTAssertEqual(zeilen.count, 1)
        XCTAssertEqual(zeilen[0].ist, 20.0)
    }

    func testEinSchweigenderRaumStehtMitStrichenDaUndNichtGarNicht() {
        let tag = verlauf([reihe(id: 5, name: "Gast", etage: "OG", kreise: 2, ist: [nil, nil])])
        let zeilen = R.tabellenzeilen(live: nil, tag: tag, istHeute: false)
        XCTAssertEqual(zeilen.count, 1)
        XCTAssertEqual(zeilen[0].name, "Gast")
        XCTAssertEqual(zeilen[0].etage, "OG")
        XCTAssertEqual(zeilen[0].kreise, 2, "Name, Etage und Kreise stehen in der Anlage.")
        XCTAssertNil(zeilen[0].ist)
        XCTAssertNil(zeilen[0].abweichung)
        XCTAssertEqual(Formate.celsius(zeilen[0].ist, stellen: 1), Formate.leer)
    }

    func testEinRaumOhneEtagenangabeTraegtEinenStrich() {
        let zeilen = R.tabellenzeilen(
            live: istwerte([raum(etage: "", ist: 21.0)]), tag: nil, istHeute: true)
        XCTAssertEqual(zeilen[0].etage, Formate.leer)
        XCTAssertNotEqual(zeilen[0].etage, "ohne Etagenangabe", "Das ist eine Gruppenzeile.")
    }

    func testDieZeileWirdUeberDieKennungUnterschiedenUndNichtUeberDenNamen() {
        let live = istwerte([raum(id: 1, name: "Bad"), raum(id: 2, name: "Bad")])
        let zeilen = R.tabellenzeilen(live: live, tag: nil, istHeute: true)
        XCTAssertEqual(zeilen.map(\.id), [1, 2])
        XCTAssertEqual(Set(zeilen.map(\.id)).count, 2, "Zwei Räume dürfen gleich heissen.")
    }

    // MARK: - Der Takt der Istwerte

    func testDerIstwerttaktIstDerDerVorlage() {
        XCTAssertEqual(R.liveTakt, .seconds(30))
    }
}
