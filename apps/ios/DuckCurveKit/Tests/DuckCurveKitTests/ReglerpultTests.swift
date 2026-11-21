import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/waermepumpe/regler.ts`, `Regler.tsx` und
/// `Heizkurve.tsx`.
///
/// **Was hier geprüft wird, ist die Absicherung.** Diese Seite stellt eine echte Wärmepumpe:
/// die Reihenfolge der vier Sperrgründe, dass ein nie verglichener Wert sich nicht bewegt, dass
/// ein Entwurf gleich dem gelesenen Wert keine Änderung ist, und dass das Raster hält. Dazu die
/// Rechnung der Heizkurve und die Sätze, die wörtlich dastehen müssen.
final class ReglerpultTests: XCTestCase {

    private let schmal = Formate.schmalesLeerzeichen
    private let minus = Formate.minus

    // MARK: - Werkbank

    private func messwert(
        _ wert: Double?, guete: Quality = .ok, am: String = "2026-11-20T14:53:00+01:00"
    ) -> Messwert {
        Messwert(value: wert, observedAt: am, quality: guete, source: "ebus")
    }

    private func einstellung(
        _ schluessel: String = "heat_pump_set_slope",
        name: String = "Steilheit",
        gruppe: String = "Heizkurve",
        einheit: String? = nil,
        stellen: Int? = 2,
        wert: Messwert? = nil,
        art: ReglerEinstellungOutArtWahl? = .zahl,
        stellbar: Bool? = true,
        von: Double? = 0.1,
        bis: Double? = 1.5,
        schritt: Double? = 0.05,
        wahl: [String: String] = [:],
        bestaetigt: Bool? = true,
        muster: Bool? = nil,
        gesendet: ReglerGesendetOut? = nil
    ) -> ReglerEinstellungOut {
        ReglerEinstellungOut(
            schluessel: schluessel, nameDe: name, gruppeDe: gruppe, kennung: "0/5/B38",
            einheit: einheit, stellen: stellen, wert: wert ?? messwert(1.0), art: art,
            stellbar: stellbar, von: von, bis: bis, schritt: schritt, wahl: wahl,
            bestaetigt: bestaetigt, muster: muster, gesendet: gesendet)
    }

    /// Die fünf Kurvengrößen, so wie sie in den Bildschirmfotos stehen: Steilheit 1,00,
    /// Verschiebung +7,0 K, Raum 20 °C, Vorlauf 20 bis 45 °C.
    private func kurvenwerte(entwurfOffen: Bool = false) -> [ReglerEinstellungOut] {
        [
            einstellung(
                Reglerpult.Kurvenkennung.steilheit, name: "Steilheit", stellen: 2,
                wert: messwert(1.0), von: 0.1, bis: 1.5, schritt: 0.05),
            einstellung(
                Reglerpult.Kurvenkennung.verschiebung, name: "Verschiebung", einheit: "K",
                stellen: 1, wert: messwert(7.0), von: -15, bis: 15, schritt: 0.5),
            einstellung(
                Reglerpult.Kurvenkennung.raum, name: "Raumtemperatur Tag", gruppe: "Raum",
                einheit: "°C", stellen: 1, wert: messwert(20.0), von: 15, bis: 25, schritt: 0.5),
            einstellung(
                Reglerpult.Kurvenkennung.min, name: "Vorlauf mindestens", einheit: "°C",
                stellen: 1, wert: messwert(20.0), von: 15, bis: 40, schritt: 0.5),
            einstellung(
                Reglerpult.Kurvenkennung.max, name: "Vorlauf höchstens", einheit: "°C",
                stellen: 1, wert: messwert(45.0), von: 30, bis: 70, schritt: 0.5),
        ]
    }

    private var kurve: Reglerpult.Kurve {
        Reglerpult.Kurve(steilheit: 1.0, verschiebung: 7.0, raum: 20, min: 20, max: 45)
    }

    // MARK: - Die vier Sperrgründe, in dieser Reihenfolge

    /// `regler.ts:56-62`. Der erste zutreffende Grund zählt – auch wenn mehrere zutreffen.
    func testSperreInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            Reglerpult.sperre(einstellung(stellbar: false), stellenMoeglich: true), .nurLesen)
        XCTAssertEqual(
            Reglerpult.sperre(einstellung(stellbar: nil), stellenMoeglich: true), .nurLesen)
        XCTAssertEqual(
            Reglerpult.sperre(
                einstellung(wert: messwert(1.0, guete: .stale)), stellenMoeglich: true),
            .nichtGelesen)
        XCTAssertEqual(
            Reglerpult.sperre(einstellung(bestaetigt: false), stellenMoeglich: true),
            .nichtVerglichen)
        XCTAssertEqual(
            Reglerpult.sperre(einstellung(bestaetigt: nil), stellenMoeglich: true),
            .nichtVerglichen)
        XCTAssertEqual(
            Reglerpult.sperre(einstellung(), stellenMoeglich: false), .nichtMoeglich)
        XCTAssertNil(Reglerpult.sperre(einstellung(), stellenMoeglich: true))
    }

    /// Mehrere Gründe zugleich: „nur lesen“ gewinnt, wie in der Vorlage.
    func testErsterGrundGewinnt() {
        let w = einstellung(
            wert: messwert(nil, guete: .unavailable), stellbar: false, bestaetigt: false)
        XCTAssertEqual(Reglerpult.sperre(w, stellenMoeglich: false), .nurLesen)
    }

    func testSperrwoerterWoertlich() {
        XCTAssertEqual(
            Reglerpult.Sperre.allCases.map(\.wort),
            ["nur lesen", "nicht gelesen", "nicht verglichen", "Stellen nicht möglich"])
    }

    /// `regler.ts:33-35`: nur `ok` und `derived` tragen eine Zahl. Das ist die Prüfung, die der
    /// App fehlte – ein veralteter Wert war dort bewegbar.
    func testGelesenVerlangtGueteUndWert() {
        XCTAssertTrue(Reglerpult.gelesen(einstellung(wert: messwert(1.0, guete: .ok))))
        XCTAssertTrue(Reglerpult.gelesen(einstellung(wert: messwert(1.0, guete: .derived))))
        XCTAssertFalse(Reglerpult.gelesen(einstellung(wert: messwert(1.0, guete: .stale))))
        XCTAssertFalse(Reglerpult.gelesen(einstellung(wert: messwert(nil, guete: .ok))))
        XCTAssertFalse(
            Reglerpult.gelesen(einstellung(wert: messwert(1.0, guete: .inconsistent))))
    }

    func testBedienbarIstKeinGrund() {
        XCTAssertTrue(Reglerpult.bedienbar(einstellung(), stellenMoeglich: true))
        XCTAssertFalse(Reglerpult.bedienbar(einstellung(bestaetigt: false), stellenMoeglich: true))
    }

    // MARK: - Werte als Text

    /// `regler.ts:38-42`: das Plus steht nur an einer Einheit `K`, das Minus immer.
    func testZahlTextMitVorzeichenBeiKelvin() {
        let v = einstellung(einheit: "K", stellen: 1)
        XCTAssertEqual(Reglerpult.zahlText(v, 7), "+7,0\(schmal)K")
        XCTAssertEqual(Reglerpult.zahlText(v, -3), "\(minus)3,0\(schmal)K")
        XCTAssertEqual(Reglerpult.zahlText(v, 0), "0,0\(schmal)K")
    }

    func testZahlTextOhnePlusBeiAnderenEinheiten() {
        XCTAssertEqual(
            Reglerpult.zahlText(einstellung(einheit: "°C", stellen: 1), 45), "45,0\(schmal)°C")
        XCTAssertEqual(Reglerpult.zahlText(einstellung(stellen: 2), 1), "1,00")
    }

    /// `regler.ts:44-47`: ein Fragezeichen und nicht der Strich – es fehlt eine Auskunft, kein
    /// Messwert.
    func testWertTextFragezeichenOhneBelastbarenWert() {
        XCTAssertEqual(Reglerpult.wertText(einstellung(wert: messwert(1.0))), "1,00")
        XCTAssertEqual(
            Reglerpult.wertText(einstellung(wert: messwert(1.0, guete: .stale))), "?")
        XCTAssertEqual(Reglerpult.wertText(einstellung(wert: messwert(nil))), "?")
    }

    func testStandTextIstDieUhrzeitDesHauses() {
        XCTAssertEqual(
            Reglerpult.standText(einstellung(wert: messwert(1.0, am: "2026-11-20T14:53:00+01:00"))),
            "14:53")
        XCTAssertEqual(
            Reglerpult.standText(einstellung(wert: messwert(1.0, guete: .stale))),
            "nicht gelesen")
        XCTAssertEqual(
            Reglerpult.standText(einstellung(wert: messwert(1.0, am: "krumm"))),
            "nicht gelesen")
    }

    // MARK: - Das Raster

    /// `regler.ts:67-73`. Kein stufenloses Ziehen: eine Steilheit kennt Schritte von 0,05.
    func testRasterZwingtAufDasSchrittraster() {
        let w = einstellung(von: 0.1, bis: 1.5, schritt: 0.05)
        XCTAssertEqual(Reglerpult.raster(w, 0.83), 0.85, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.raster(w, 0.86), 0.85, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.raster(w, 1.0), 1.0, accuracy: 1e-9)
    }

    func testRasterKlemmtAufDieGrenzen() {
        let w = einstellung(von: 0.1, bis: 1.5, schritt: 0.05)
        XCTAssertEqual(Reglerpult.raster(w, -4), 0.1, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.raster(w, 99), 1.5, accuracy: 1e-9)
    }

    /// Vier Nachkommastellen wie `toFixed(4)` der Vorlage: sonst ginge „0,8500000000000001“ an
    /// den Bus.
    func testRasterRundetDieBinaerbruecheWeg() {
        let w = einstellung(von: 0.1, bis: 1.5, schritt: 0.05)
        XCTAssertEqual(Reglerpult.raster(w, 0.85), 0.85)
        XCTAssertEqual(Reglerpult.raster(w, 0.8500000001), 0.85)
    }

    func testAnteilUndWertBeiSindUmkehrungen() {
        let w = einstellung(stellen: 1, von: 20, bis: 60, schritt: 0.5)
        XCTAssertEqual(Reglerpult.anteil(w, 20), 0, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.anteil(w, 60), 1, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.anteil(w, 40), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.anteil(w, 99), 1, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.wertBei(w, 0.5), 40, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.wertBei(w, 1.4), 60, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.wertBei(w, -1), 20, accuracy: 1e-9)
    }

    /// Eine Spanne von null hätte keine Richtung. Die Vorlage teilte dort durch null.
    func testAnteilOhneSpanneIstNull() {
        XCTAssertEqual(Reglerpult.anteil(einstellung(von: 5, bis: 5), 5), 0)
    }

    // MARK: - Entwurf und Änderungen

    func testSichtbarNimmtDenEntwurfUndSonstDenGelesenen() {
        let w = einstellung(wert: messwert(1.0))
        XCTAssertEqual(Reglerpult.sichtbar(w, entwurf: [:]), 1.0)
        XCTAssertEqual(Reglerpult.sichtbar(w, entwurf: [w.schluessel: 1.2]), 1.2)
        let alt = einstellung(wert: messwert(1.0, guete: .stale))
        XCTAssertNil(Reglerpult.sichtbar(alt, entwurf: [:]))
    }

    /// `regler.ts:100-108`: wer einen Schieber hin und wieder zurückzieht, hat nichts geändert.
    func testEntwurfGleichDemGelesenenWertIstKeineAenderung() {
        let w = einstellung(wert: messwert(1.0))
        XCTAssertTrue(Reglerpult.aenderungen([w], entwurf: [w.schluessel: 1.0]).isEmpty)
        XCTAssertTrue(Reglerpult.aenderungen([w], entwurf: [w.schluessel: 1.0 + 1e-9]).isEmpty)
        XCTAssertEqual(Reglerpult.aenderungen([w], entwurf: [w.schluessel: 1.05]).count, 1)
    }

    func testAenderungenUebergehenNichtGeleseneWerte() {
        let alt = einstellung(wert: messwert(1.0, guete: .stale))
        XCTAssertTrue(Reglerpult.aenderungen([alt], entwurf: [alt.schluessel: 1.2]).isEmpty)
    }

    func testAenderungTraegtAltUndNeuUndIhreSpanne() {
        let w = einstellung(einheit: "°C", stellen: 1, wert: messwert(45.0), von: 30, bis: 70)
        let aus = Reglerpult.aenderungen([w], entwurf: [w.schluessel: 41.0])
        XCTAssertEqual(aus.count, 1)
        XCTAssertEqual(aus[0].alt, 45.0)
        XCTAssertEqual(aus[0].neu, 41.0)
        XCTAssertEqual(aus[0].spanne, "45,0\(schmal)°C → 41,0\(schmal)°C")
        XCTAssertEqual(aus[0].wort, "Heizkurve: Steilheit")
    }

    // MARK: - Die Fußzeile

    /// `Regler.tsx:103-115`, alle vier Fälle in ihrer Rangfolge.
    func testFussstandInVierFaellen() {
        let gesendet = einstellung(
            einheit: "°C", stellen: 1, wert: messwert(45.0),
            bestaetigt: false,
            gesendet: ReglerGesendetOut(wert: 41.0, at: "2026-11-20T14:52:00+01:00"))
        XCTAssertEqual(
            Reglerpult.fuss(gesendet, stellenMoeglich: true),
            .wartet("gesendet 41,0\(schmal)°C, wartet auf den Regler"))

        XCTAssertEqual(
            Reglerpult.fuss(einstellung(bestaetigt: false), stellenMoeglich: true),
            .vergleichen("Am Gerät steht 1,00"))

        XCTAssertEqual(
            Reglerpult.fuss(einstellung(stellbar: false), stellenMoeglich: true),
            .grund("nur lesen"))

        XCTAssertEqual(
            Reglerpult.fuss(einstellung(), stellenMoeglich: true), .gelesen("gelesen 14:53"))
    }

    /// Der gestrichelte Knopf trägt den gelesenen Wert – auch dann, wenn ein Entwurf dasteht.
    /// Gegengelesen wird am Bediengerät, und dort steht der gelesene.
    func testVergleichsknopfNenntDenGelesenenWert() {
        let w = einstellung(einheit: "°C", stellen: 1, wert: messwert(21.0), bestaetigt: false)
        XCTAssertEqual(
            Reglerpult.fuss(w, stellenMoeglich: true).satz, "Am Gerät steht 21,0\(schmal)°C")
    }

    // MARK: - Die Heizkurve

    func testKurveAusDenFuenfGroessen() {
        let k = Reglerpult.kurveAus(kurvenwerte())
        XCTAssertEqual(k, kurve)
    }

    func testKurveFehltSobaldEineGroesseFehlt() {
        for kennung in Reglerpult.Kurvenkennung.alle {
            let ohne = kurvenwerte().filter { $0.schluessel != kennung }
            XCTAssertNil(Reglerpult.kurveAus(ohne), "ohne \(kennung) darf keine Kurve stehen")
        }
        let alt = kurvenwerte().map { w in
            w.schluessel == Reglerpult.Kurvenkennung.raum
                ? einstellung(w.schluessel, wert: messwert(20, guete: .stale)) : w
        }
        XCTAssertNil(Reglerpult.kurveAus(alt))
    }

    func testEntwurfLiegtUeberDerKurve() {
        let mit = Reglerpult.kurveAus(
            kurvenwerte(), entwurf: [Reglerpult.Kurvenkennung.steilheit: 1.2])
        XCTAssertEqual(mit?.steilheit, 1.2)
        XCTAssertTrue(
            Reglerpult.kurveGeaendert(
                kurvenwerte(), entwurf: [Reglerpult.Kurvenkennung.steilheit: 1.2]))
        XCTAssertFalse(
            Reglerpult.kurveGeaendert(
                kurvenwerte(), entwurf: [Reglerpult.Kurvenkennung.steilheit: 1.0]))
        XCTAssertFalse(Reglerpult.kurveGeaendert(kurvenwerte(), entwurf: [:]))
    }

    /// `regler.ts:138`: Vorlauf = Raum + Steilheit × (Raum − außen) + Verschiebung.
    func testVorlaufFreiIstDieNaeherungDerVorlage() {
        XCTAssertEqual(Reglerpult.vorlaufFrei(kurve, aussen: -10), 57, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.vorlaufFrei(kurve, aussen: 0), 47, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.vorlaufFrei(kurve, aussen: 10), 37, accuracy: 1e-9)
    }

    /// `regler.ts:141`: und dann auf den kleinsten und größten Vorlauf geklemmt. Das ist der
    /// waagerechte Anfang der Kurve auf dem Bildschirmfoto.
    func testVorlaufKlemmtAufMinUndMax() {
        XCTAssertEqual(Reglerpult.vorlauf(kurve, aussen: -15), 45, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.vorlauf(kurve, aussen: -10), 45, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.vorlauf(kurve, aussen: 0), 45, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.vorlauf(kurve, aussen: 10), 37, accuracy: 1e-9)
        // Bei 22 °C außen ergibt die Näherung 25 °C – über dem kleinsten Vorlauf, also
        // bleibt sie stehen. Geklemmt wird erst darunter.
        XCTAssertEqual(Reglerpult.vorlauf(kurve, aussen: 22), 25, accuracy: 1e-9)
        XCTAssertEqual(Reglerpult.vorlauf(kurve, aussen: 30), 20, accuracy: 1e-9)
    }

    /// Die Umkehrungen: ein Griff, der auf einen Vorlauf gezogen wird, ergibt genau die
    /// Steilheit bzw. Verschiebung, mit der die Kurve dort durchgeht (`regler.ts:144-150`).
    func testSteilheitDurchIstDieUmkehrungVonVorlaufFrei() {
        let neu = Reglerpult.steilheitDurch(kurve, aussen: -10, ziel: 52)
        let probe = Reglerpult.Kurve(
            steilheit: neu, verschiebung: kurve.verschiebung, raum: kurve.raum,
            min: kurve.min, max: kurve.max)
        XCTAssertEqual(Reglerpult.vorlaufFrei(probe, aussen: -10), 52, accuracy: 1e-9)
    }

    func testVerschiebungDurchIstDieUmkehrungVonVorlaufFrei() {
        let neu = Reglerpult.verschiebungDurch(kurve, aussen: 18, ziel: 26)
        let probe = Reglerpult.Kurve(
            steilheit: kurve.steilheit, verschiebung: neu, raum: kurve.raum,
            min: kurve.min, max: kurve.max)
        XCTAssertEqual(Reglerpult.vorlaufFrei(probe, aussen: 18), 26, accuracy: 1e-9)
    }

    /// Ohne Hebel keine Steilheit: bei Außentemperatur = Raumtemperatur dreht sich die Kurve
    /// um genau diesen Punkt, und die alte Steilheit bleibt stehen (`regler.ts:146`).
    func testSteilheitOhneHebelBleibtStehen() {
        XCTAssertEqual(Reglerpult.steilheitDurch(kurve, aussen: 20, ziel: 99), 1.0)
    }

    func testGriffzielNimmtDieStelleDesGriffs() {
        XCTAssertEqual(Reglerpult.Kurvengriff.steilheit.aussen, -10)
        XCTAssertEqual(Reglerpult.Kurvengriff.verschiebung.aussen, 18)
        XCTAssertNil(Reglerpult.Kurvengriff.max.aussen)
        XCTAssertEqual(
            Reglerpult.griffziel(.steilheit, k: kurve, ziel: 52),
            Reglerpult.steilheitDurch(kurve, aussen: -10, ziel: 52))
        XCTAssertEqual(
            Reglerpult.griffziel(.verschiebung, k: kurve, ziel: 26),
            Reglerpult.verschiebungDurch(kurve, aussen: 18, ziel: 26))
        XCTAssertEqual(Reglerpult.griffziel(.max, k: kurve, ziel: 48), 48)
        XCTAssertEqual(Reglerpult.griffziel(.min, k: kurve, ziel: 22), 22)
    }

    func testGriffeTragenDieKennungenDerKurve() {
        XCTAssertEqual(
            Reglerpult.Kurvengriff.allCases.map(\.kennung),
            [
                Reglerpult.Kurvenkennung.steilheit, Reglerpult.Kurvenkennung.verschiebung,
                Reglerpult.Kurvenkennung.max, Reglerpult.Kurvenkennung.min,
            ])
    }

    func testKurvenPunkteJeGanzemGrad() {
        let p = Reglerpult.kurvenPunkte(kurve, von: -15, bis: 22)
        XCTAssertEqual(p.count, 38)
        XCTAssertEqual(p.first?.aussen, -15)
        XCTAssertEqual(p.last?.aussen, 22)
        XCTAssertEqual(p.first?.vorlauf, 45)
        XCTAssertEqual(p.last?.vorlauf, 25)
    }

    func testSchildUndBeschriftungWoertlich() {
        XCTAssertEqual(Reglerpult.griffschild(.max, 45), "max 45°")
        XCTAssertEqual(Reglerpult.griffschild(.min, 20), "min 20°")
        let steil = kurvenwerte()[0]
        let versch = kurvenwerte()[1]
        XCTAssertEqual(Reglerpult.griffbeschriftung(.steilheit, steil, 1.0), "Steilheit 1,00")
        XCTAssertEqual(
            Reglerpult.griffbeschriftung(.verschiebung, versch, 7.0),
            "Verschiebung +7,0\(schmal)K")
    }

    /// Die Mono-Zeile unter der Kurve, Zeichen für Zeichen wie `Heizkurve.tsx:167-169`.
    func testKurvenwertesatzMitDreiStuetzstellen() {
        XCTAssertEqual(
            Reglerpult.kurvenwertesatz(kurve),
            "bei \(minus)10\(schmal)°C 45,0\(schmal)°C · bei 0\(schmal)°C 45,0\(schmal)°C "
                + "· bei 10\(schmal)°C 37,0\(schmal)°C")
    }

    // MARK: - Die Einteilung der Seite

    func testPultgruppenInDerReihenfolgeDerVorlage() {
        let werte =
            kurvenwerte() + [
                einstellung(
                    "heat_pump_set_dhw_c", name: "Warmwasser Soll", gruppe: "Warmwasser",
                    einheit: "°C", stellen: 1, wert: messwert(48), von: 30, bis: 60)
            ]
        XCTAssertEqual(
            Reglerpult.pultgruppen(werte).map(\.name), ["Heizkurve", "Raum", "Warmwasser"])
        XCTAssertEqual(Reglerpult.pultgruppen(werte).first?.werte.count, 4)
    }

    func testLeereGruppenFallenWeg() {
        XCTAssertEqual(Reglerpult.pultgruppen([einstellung()]).map(\.name), ["Heizkurve"])
    }

    /// Die Vorlage kennt genau drei Gruppen; eine stellbare Zahl in einer vierten fiele dort
    /// unter den Tisch. Hier kommt sie hinten dran.
    func testVierteGruppeFaelltNichtUnterDenTisch() {
        let werte = [
            einstellung(),
            einstellung("heat_pump_set_pool_c", name: "Pool Soll", gruppe: "Pool"),
        ]
        XCTAssertEqual(Reglerpult.pultgruppen(werte).map(\.name), ["Heizkurve", "Pool"])
    }

    func testSchalterUndNurLesenTrennenSich() {
        let werte = [
            einstellung(),
            einstellung(
                "heat_pump_set_dhw_mode", name: "Betriebsart", gruppe: "Warmwasser",
                wert: messwert(1), art: .wahl,
                wahl: ["0": "aus", "1": "nach Zeitprogramm", "2": "immer an"]),
            einstellung("heat_pump_outside_c", name: "Außen", stellbar: false),
        ]
        XCTAssertEqual(Reglerpult.schalter(werte).map(\.schluessel), ["heat_pump_set_dhw_mode"])
        XCTAssertEqual(Reglerpult.nurLesen(werte).map(\.schluessel), ["heat_pump_outside_c"])
        XCTAssertEqual(Reglerpult.pultgruppen(werte).map(\.name), ["Heizkurve"])
    }

    /// Fehlt `art`, gilt `zahl`: eine Einstellung mit Spanne und Schritt ist auf dem Pult
    /// brauchbar, in einem Schalterkasten dagegen ein Kasten ohne einen einzigen Knopf.
    func testOhneArtGiltZahl() {
        XCTAssertTrue(Reglerpult.istZahl(einstellung(art: nil)))
        XCTAssertFalse(Reglerpult.istZahl(einstellung(art: .wahl)))
        XCTAssertFalse(Reglerpult.istZahl(einstellung(art: .schalter)))
    }

    /// `wahl` ist ein Wörterbuch und hat keine Reihenfolge; der Regler kennt nur die Zahl.
    func testStufenNachDerZahlGeordnet() {
        let w = einstellung(
            wert: messwert(1), art: .wahl,
            wahl: ["2": "immer an", "0": "aus", "1": "nach Zeitprogramm"])
        XCTAssertEqual(Reglerpult.stufen(w).map(\.zahl), [0, 1, 2])
        XCTAssertEqual(
            Reglerpult.stufen(w).map(\.wort), ["aus", "nach Zeitprogramm", "immer an"])
        XCTAssertEqual(Reglerpult.stufen(w).map(\.id), [0, 1, 2])
        // Eine Stufe, deren Schlüssel keine Zahl ist, kennt der Regler nicht.
        let krumm = einstellung(wert: messwert(1), art: .wahl, wahl: ["x": "wer weiß", "1": "an"])
        XCTAssertEqual(Reglerpult.stufen(krumm).map(\.wort), ["an"])
    }

    // MARK: - Die Sätze

    func testVerglichenSatzZaehltNurStellbare() {
        let werte = [
            einstellung(bestaetigt: true),
            einstellung("a", bestaetigt: false),
            einstellung("b", stellbar: false, bestaetigt: false),
        ]
        XCTAssertEqual(
            Reglerpult.verglichenSatz(werte),
            "1 von 2 stellbaren Einstellungen mit dem Bediengerät verglichen")
        XCTAssertEqual(
            Reglerpult.verglichenSatz(werte, fehler: "nicht zu erreichen"),
            "1 von 2 stellbaren Einstellungen mit dem Bediengerät verglichen · "
                + "nicht zu erreichen")
    }

    func testAnleitungStehtNurSolangeEtwasUnverglichenIst() {
        XCTAssertTrue(Reglerpult.anleitungNoetig([einstellung(bestaetigt: false)]))
        XCTAssertFalse(Reglerpult.anleitungNoetig([einstellung(bestaetigt: true)]))
        XCTAssertFalse(Reglerpult.anleitungNoetig([einstellung(stellbar: false, bestaetigt: nil)]))
    }

    func testDieVierAbsaetzeWoertlich() {
        XCTAssertTrue(Reglerpult.anleitungssatz.hasPrefix("Bevor sich eine Einstellung bewegen"))
        XCTAssertTrue(Reglerpult.anleitungssatz.contains("„Am Gerät steht …“"))
        XCTAssertTrue(Reglerpult.anleitungssatz.hasSuffix("dann bitte nicht drücken."))
        XCTAssertTrue(Reglerpult.naeherungssatz.hasPrefix("Die Kurve ist eine Näherung:"))
        XCTAssertTrue(
            Reglerpult.naeherungssatz.contains(
                "Vorlauf = Raum + Steilheit × (Raum − außen) + Verschiebung"))
        XCTAssertTrue(Reglerpult.stufensatz.hasPrefix("Die Wörter an den Stufen"))
        XCTAssertTrue(Reglerpult.stufensatz.hasSuffix("die am Regler steht."))
        XCTAssertEqual(
            Reglerpult.uebersichtssatz,
            "Diese Änderungen gehen an den Regler der Wärmepumpe und bleiben dort stehen:")
        XCTAssertTrue(Reglerpult.kurveFehltSatz.contains("eine der fünf Einstellungen"))
    }

    func testHindernissatzSetztDenGrundInDieMitte() {
        XCTAssertEqual(
            Reglerpult.hindernissatz("Der Bus antwortet nicht."),
            "Stellen ist gerade nicht möglich. Der Bus antwortet nicht. Lesen geht weiter.")
    }

    func testEntwurfssatzZaehltRichtig() {
        XCTAssertEqual(Reglerpult.entwurfssatz(1), "1 Änderung im Entwurf")
        XCTAssertEqual(Reglerpult.entwurfssatz(3), "3 Änderungen im Entwurf")
    }

    // MARK: - Der Nachfragetakt

    func testTaktFuenfSekundenSolangeEtwasWartet() {
        XCTAssertEqual(Reglerpult.takt(wartet: true), 5)
        XCTAssertEqual(Reglerpult.takt(wartet: false), 60)
        let unterwegs = einstellung(
            gesendet: ReglerGesendetOut(wert: 1.2, at: "2026-11-20T14:52:00+01:00"))
        XCTAssertTrue(Reglerpult.wartet([einstellung(), unterwegs]))
        XCTAssertFalse(Reglerpult.wartet([einstellung()]))
    }
}
