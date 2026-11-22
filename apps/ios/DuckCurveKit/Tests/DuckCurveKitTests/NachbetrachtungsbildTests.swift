import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/waerme/nachbetrachtung.ts`,
/// `Kostentreppe.tsx`, `Tagesvergleich.tsx` und `Nachbetrachtung.tsx`, Fall für Fall
/// dieselben wie in `nachbetrachtung.test.ts`.
///
/// **Warum hier so viel geprüft wird.** Die Treppe ist die Sorte Rechnung, die man dem Bild
/// nicht ansieht: eine Stufe, die bei der falschen Linie beginnt, sieht genauso plausibel aus
/// wie eine richtige, und eine fehlende Stufe als Null gezeichnet behauptet „kein Fehler“, wo
/// „unbekannt“ gemeint ist.
final class NachbetrachtungsbildTests: XCTestCase {

    // MARK: - Antworten bauen

    private func linie(_ key: String, _ eur: Double?, geschaetzt: Bool = false) -> Linie {
        Linie(
            key: key, nameDe: key, verfuegbar: eur != nil, grundDe: eur == nil ? "fehlt" : "",
            geschaetzt: geschaetzt, eur: eur)
    }

    private func abstand(_ key: String, _ von: String, _ nach: String, _ eur: Double?) -> Abstand {
        Abstand(
            key: key, nameDe: key, von: von, nach: nach, eur: eur,
            satzDe: eur == nil ? "" : "Satz zu \(key)")
    }

    private func tag(
        _ linien: [Linie], _ abstaende: [Abstand], hatOfen: Bool = false,
        standbyKwh: Double? = nil, standbyEur: Double? = nil, nVerglichen: Int? = 96,
        ersterPlan: String? = nil, hinweise: [String] = []
    ) -> NachbetrachtungOut {
        NachbetrachtungOut(
            zeiten: [], schrittMin: 15, verglichen: [], nVerglichen: nVerglichen,
            linien: linien, abstaende: abstaende, standbyKwh: standbyKwh, standbyEur: standbyEur,
            ersterPlanErstellt: ersterPlan, hinweiseDe: hinweise, day: "2026-11-07",
            von: "2026-11-06T23:00:00Z", bis: "2026-11-07T23:00:00Z", laeuftNoch: false,
            wpKw: 4.5, verguetungCt: 8, hatOfen: hatOfen)
    }

    /// Derselbe Tag wie `VOLL` in `nachbetrachtung.test.ts:31-39`.
    private var voll: NachbetrachtungOut {
        tag(
            [
                linie("versprochen", 1.35), linie("erster", 1.13), linie("letzter", 0.9),
                linie("wirklich", 4.59), linie("perfekt", 0.8),
            ],
            [
                abstand("prognosefehler", "versprochen", "erster", -0.22),
                abstand("nachfuehren", "erster", "letzter", -0.23),
                abstand("eingriff", "letzter", "wirklich", 3.69),
                abstand("voraussicht", "perfekt", "letzter", 0.1),
            ])
    }

    // MARK: - Die Treppe

    func testTreppeFuehrtVomVersprechenZurWirklichkeit() {
        let t = Nachbetrachtungsbild.treppe(voll)
        XCTAssertEqual(
            t.map(\.key),
            ["versprochen", "prognosefehler", "nachfuehren", "eingriff", "wirklich", "perfekt"])
        XCTAssertEqual(
            t.map(\.art), [.summe, .stufe, .stufe, .stufe, .summe, .bezug])
        // Die Bezugszeile trägt den Satz des Abstands „voraussicht“, nicht ihren eigenen.
        XCTAssertEqual(t[5].satz, "Satz zu voraussicht")
        // Jede Stufe beginnt, wo die vorige endet, und die letzte endet auf der Wirklichkeit.
        XCTAssertEqual(t[1].von, 1.35, accuracy: 1e-9)
        XCTAssertEqual(t[2].von, 1.13, accuracy: 1e-9)
        XCTAssertEqual(t[3].von, 0.9, accuracy: 1e-9)
        XCTAssertEqual(t[3].bis, 4.59, accuracy: 1e-9)
        XCTAssertEqual(t[4].bis, 4.59, accuracy: 1e-9)
        // Die Summen stehen auf dem Boden, die Stufen nicht.
        XCTAssertEqual(t[0].von, 0)
        XCTAssertEqual(t[4].von, 0)
    }

    func testTreppeBeginntBeimGehaltenenFahrplanWennDasVersprechenFehlt() {
        let ohne = tag(
            [
                linie("versprochen", nil), linie("erster", 1.13), linie("letzter", 0.9),
                linie("wirklich", 4.59),
            ],
            [
                abstand("prognosefehler", "versprochen", "erster", nil),
                abstand("nachfuehren", "erster", "letzter", -0.23),
                abstand("eingriff", "letzter", "wirklich", 3.69),
            ])
        let t = Nachbetrachtungsbild.treppe(ohne)
        XCTAssertEqual(t.map(\.key), ["erster", "nachfuehren", "eingriff", "wirklich"])
        XCTAssertEqual(t[0].bis, 1.13, accuracy: 1e-9)
    }

    func testTreppeZeichnetKeineStufeDerHoeheNull() {
        let nur = tag(
            [
                linie("versprochen", nil), linie("erster", nil), linie("letzter", nil),
                linie("wirklich", 4.59), linie("perfekt", 3.1, geschaetzt: true),
            ],
            [
                abstand("prognosefehler", "versprochen", "erster", nil),
                abstand("nachfuehren", "erster", "letzter", nil),
                abstand("eingriff", "letzter", "wirklich", nil),
                abstand("voraussicht", "perfekt", "letzter", nil),
            ])
        let t = Nachbetrachtungsbild.treppe(nur)
        XCTAssertEqual(t.map(\.key), ["wirklich", "perfekt"])
        XCTAssertEqual(t[1].art, .bezug)
        // Geschätztes ist gekennzeichnet: die Ansicht umrandet es, statt es zu füllen.
        XCTAssertTrue(t[1].geschaetzt)
    }

    func testTreppeBleibtLeerWennNichtsGemessenIst() {
        XCTAssertTrue(Nachbetrachtungsbild.treppe(tag([linie("wirklich", nil)], [])).isEmpty)
    }

    /// Fehlt bei vorhandener Kette der Anfangsbestand, entsteht keine schwebende Treppe: ohne
    /// Stand gibt es kein „von“, und eine Stufe ab null wäre eine erfundene Behauptung.
    func testTreppeOhneAnfangsstandZeigtNurDieWirklichkeit() {
        let d = tag(
            [linie("erster", nil), linie("letzter", 0.9), linie("wirklich", 4.59)],
            [abstand("nachfuehren", "erster", "letzter", -0.23)])
        XCTAssertEqual(Nachbetrachtungsbild.treppe(d).map(\.key), ["wirklich"])
    }

    // MARK: - Die Achse

    func testAchseBeginntBeiNullUndEndetRundUeberDemGroesstenStand() {
        let a = Nachbetrachtungsbild.achse(Nachbetrachtungsbild.treppe(voll))
        XCTAssertEqual(a.min, 0)
        XCTAssertEqual(a.max, 5, accuracy: 1e-9)
        XCTAssertEqual(a.marken, [0, 1, 2, 3, 4, 5])
    }

    func testAchseHatAuchFuerCentbetraegeEineAchse() {
        let stufe = Nachbetrachtungsbild.Stufe(
            key: "wirklich", name: "", art: .summe, von: 0, bis: 0.12, eur: 0.12,
            geschaetzt: false, satz: "")
        let a = Nachbetrachtungsbild.achse([stufe])
        XCTAssertEqual(a.max, 0.5, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(a.marken.count, 3)
        // Höchstens fünf Felder, also höchstens sechs Marken.
        XCTAssertLessThanOrEqual(a.marken.count, 6)
    }

    func testAchseReichtUnterNullWennEineLinieNegativIst() {
        // Bei vollem Überschuss und negativem Preis kann Wärme Geld bringen.
        let stufe = Nachbetrachtungsbild.Stufe(
            key: "wirklich", name: "", art: .summe, von: 0, bis: -0.4, eur: -0.4,
            geschaetzt: false, satz: "")
        let a = Nachbetrachtungsbild.achse([stufe])
        XCTAssertLessThanOrEqual(a.min, -0.4)
        XCTAssertTrue(a.marken.contains { abs($0) < 1e-9 })
    }

    /// Die leere Treppe darf keine leere Achse ergeben: sonst teilt die Ansicht durch null.
    func testAchseOhneStufenHatEineSpanne() {
        let a = Nachbetrachtungsbild.achse([])
        XCTAssertEqual(a.min, 0)
        XCTAssertEqual(a.max, 0.5, accuracy: 1e-9)
        XCTAssertFalse(a.marken.isEmpty)
    }

    /// Ein teurer Tag bekommt eine größere Schrittweite - und nie mehr als fünf Felder.
    func testAchseWaehltDieSchrittweiteNachDerSpanne() {
        let stufe = Nachbetrachtungsbild.Stufe(
            key: "wirklich", name: "", art: .summe, von: 0, bis: 42, eur: 42, geschaetzt: false,
            satz: "")
        let a = Nachbetrachtungsbild.achse([stufe])
        XCTAssertEqual(a.max, 50, accuracy: 1e-9)
        XCTAssertEqual(a.marken, [0, 10, 20, 30, 40, 50])
    }

    func testAchsenmarkeSchreibtHoechstensZweiStellen() {
        let s = Formate.schmalesLeerzeichen
        XCTAssertEqual(Nachbetrachtungsbild.achsenmarke(0), "0\(s)€")
        XCTAssertEqual(Nachbetrachtungsbild.achsenmarke(0.5), "0,5\(s)€")
        XCTAssertEqual(Nachbetrachtungsbild.achsenmarke(2.25), "2,25\(s)€")
        XCTAssertEqual(Nachbetrachtungsbild.achsenmarke(3), "3\(s)€")
        XCTAssertEqual(Nachbetrachtungsbild.achsenmarke(-0.4), "\(Formate.minus)0,4\(s)€")
    }

    func testSpanneReichtUnterNullNurWoEinWertDortLiegt() {
        XCTAssertEqual(Nachbetrachtungsbild.spanne([1, 2, 3]), 0...3)
        XCTAssertEqual(Nachbetrachtungsbild.spanne([-4, 12, nil]), -4...12)
        // Eine Reihe ohne Werte ergibt trotzdem eine Spanne: sonst teilt die Zeichnung durch null.
        XCTAssertEqual(Nachbetrachtungsbild.spanne([]), 0...1)
        XCTAssertEqual(Nachbetrachtungsbild.spanne([0, 0]), 0...1)
    }

    // MARK: - Beträge

    func testEuroUndEuroMitVorzeichen() {
        let s = Formate.schmalesLeerzeichen
        XCTAssertEqual(Formate.euro(3.42), "3,42\(s)€")
        XCTAssertEqual(Formate.euro(-0.4), "\(Formate.minus)0,40\(s)€")
        XCTAssertEqual(Formate.euro(nil), Formate.leer)
        XCTAssertEqual(Formate.euroMitVorzeichen(0.31), "+0,31\(s)€")
        XCTAssertEqual(Formate.euroMitVorzeichen(-0.8), "\(Formate.minus)0,80\(s)€")
        XCTAssertEqual(Formate.euroMitVorzeichen(0), "±0,00\(s)€")
        XCTAssertEqual(Formate.euroMitVorzeichen(nil), Formate.leer)
        // Unter einem halben Cent ist die Richtung gerundet und keine Aussage.
        XCTAssertEqual(Formate.euroMitVorzeichen(0.004), "±0,00\(s)€")
        XCTAssertEqual(Formate.euroMitVorzeichen(-0.004), "±0,00\(s)€")
    }

    func testTreppenwertSchreibtSummenOhneUndStufenMitVorzeichen() {
        let t = Nachbetrachtungsbild.treppe(voll)
        XCTAssertEqual(
            Nachbetrachtungsbild.treppenwert(t[0]), "1,35\(Formate.schmalesLeerzeichen)€")
        XCTAssertEqual(
            Nachbetrachtungsbild.treppenwert(t[1]),
            "\(Formate.minus)0,22\(Formate.schmalesLeerzeichen)€")
        XCTAssertEqual(
            Nachbetrachtungsbild.treppenwert(t[3]), "+3,69\(Formate.schmalesLeerzeichen)€")
    }

    func testPfeilspitzeStehtNurWoEsEineRichtungGibt() {
        let t = Nachbetrachtungsbild.treppe(voll)
        XCTAssertFalse(Nachbetrachtungsbild.zeigtRichtung(t[0]), "eine Summe zeigt nirgendhin")
        XCTAssertTrue(Nachbetrachtungsbild.zeigtRichtung(t[1]))
        let null = Nachbetrachtungsbild.Stufe(
            key: "x", name: "", art: .stufe, von: 1, bis: 1.004, eur: 0.004, geschaetzt: false,
            satz: "")
        XCTAssertFalse(Nachbetrachtungsbild.zeigtRichtung(null))
    }

    // MARK: - Farben und Strichart

    func testFarbeGehoertDerSacheNichtDerRichtung() {
        let t = Nachbetrachtungsbild.treppe(voll)
        XCTAssertEqual(Nachbetrachtungsbild.treppenfarbe(t[0]), Marken.mist)
        XCTAssertEqual(Nachbetrachtungsbild.treppenfarbe(t[4]), Marken.waermepumpe)
        XCTAssertEqual(Nachbetrachtungsbild.treppenfarbe(t[5]), Marken.haus)
        // Zwei Stufen mit verschiedenem Vorzeichen haben dieselbe Farbe.
        XCTAssertEqual(
            Nachbetrachtungsbild.treppenfarbe(t[1]), Nachbetrachtungsbild.treppenfarbe(t[3]))
        // Und zwar die Marke der Treppenstufe (`Kostentreppe.tsx:29`), nicht ein hier
        // ausgeschriebenes Weiss auf 0,62.
        XCTAssertEqual(Nachbetrachtungsbild.treppenfarbe(t[1]), Marken.stufenbalken)
    }

    func testStrichartTrenntDieBeidenFahrplaeneUeberDenStrich() {
        let erster = Nachbetrachtungsbild.strichart(key: "erster")
        let letzter = Nachbetrachtungsbild.strichart(key: "letzter")
        XCTAssertEqual(erster.farbe, letzter.farbe)
        XCTAssertTrue(erster.gestrichelt)
        XCTAssertFalse(letzter.gestrichelt)
        XCTAssertEqual(Nachbetrachtungsbild.strichart(key: "wirklich").farbe, Marken.waermepumpe)
        XCTAssertEqual(Nachbetrachtungsbild.strichart(key: "wirklich").breite, 2.5)
        XCTAssertEqual(Nachbetrachtungsbild.strichart(key: "perfekt").farbe, Marken.haus)
    }

    func testStreifenfarbeUnterscheidetAusVonKeinerAussage() {
        // Stufe null bekommt einen eigenen, schwachen Grund.
        XCTAssertEqual(Nachbetrachtungsbild.streifenfarbe(stufe: 0), Marken.stufeNull)
        XCTAssertEqual(
            Nachbetrachtungsbild.streifenfarbe(stufe: 1), Marken.waermepumpe.mitDeckung(0.28))
        XCTAssertEqual(
            Nachbetrachtungsbild.streifenfarbe(stufe: 4), Marken.waermepumpe.mitDeckung(1))
        // Eine Stufe über vier bleibt die vollste - kein Zugriff über das Ende der Reihe.
        XCTAssertEqual(
            Nachbetrachtungsbild.streifenfarbe(stufe: 9), Marken.waermepumpe.mitDeckung(1))
    }

    // MARK: - Die Helligkeitsstufen

    func testStaerkeTeiltDenStromInVierStufen() {
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 0, vollKwh: 1), 0)
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 0.25, vollKwh: 1), 1)
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 0.26, vollKwh: 1), 2)
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 0.76, vollKwh: 1), 4)
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 1.4, vollKwh: 1), 4)
    }

    func testStaerkeUnterscheidetNichtsGezogenVonKeinerAussage() {
        XCTAssertNil(Nachbetrachtungsbild.staerke(kwh: nil, vollKwh: 1))
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 0.01, vollKwh: 1), 0)
    }

    /// Ein Haus ohne eingetragene Nennleistung liefert `wp_kw = 0`. In JavaScript ergibt das
    /// über `Infinity` die Stufe vier; hier steht die Grenze ausgeschrieben, denn
    /// `Int(Double.infinity)` würde die Anwendung beenden.
    func testStaerkeHaeltEineNennarbeitVonNullAus() {
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 0, vollKwh: 0), 0)
        XCTAssertEqual(Nachbetrachtungsbild.staerke(kwh: 1.2, vollKwh: 0), 4)
    }

    // MARK: - Die Zeilen des Tagesvergleichs

    func testZeilenNimmtNurVerfuegbareUndLaesstDasVersprechenWeg() {
        let d = tag(
            [
                linie("versprochen", 1.35), linie("erster", 1.13), linie("letzter", nil),
                linie("wirklich", 4.59),
            ], [])
        XCTAssertEqual(Nachbetrachtungsbild.zeilen(d).map(\.key), ["erster", "wirklich"])
    }

    func testFlaechenLassenDieSonneWegWoKeinerWar() {
        var d = voll
        d.zeiten = ["2026-11-07T00:00:00+01:00", "2026-11-07T00:15:00+01:00"]
        d.ueberschussKw = [0, 0.02]
        XCTAssertFalse(Nachbetrachtungsbild.hatSonne(d))
        XCTAssertFalse(Nachbetrachtungsbild.flaechen(d, schmal: false).contains { $0.art == .sonne })
        d.ueberschussKw = [0, 0.06]
        XCTAssertTrue(Nachbetrachtungsbild.hatSonne(d))
        let mit = Nachbetrachtungsbild.flaechen(d, schmal: false)
        XCTAssertEqual(mit.first?.art, .preis)
        XCTAssertEqual(mit[1].art, .sonne)
        XCTAssertEqual(mit.last?.art, .kosten)
        // Vier Linien, also vier Streifen zwischen Sonne und Kosten.
        XCTAssertEqual(mit.filter { $0.art == .streifen }.count, 4)
        // Der erste Streifen bekommt die Luft der Vorlage, die folgenden die sieben Punkte.
        let streifen = mit.filter { $0.art == .streifen }
        XCTAssertEqual(streifen[0].luftDavor, 34)
        XCTAssertEqual(streifen[1].luftDavor, 7)
        XCTAssertEqual(streifen[0].hoehe, 13)
    }

    func testFlaechenTragenAmTelefonDieKnappenNamen() {
        var d = voll
        d.ueberschussKw = []
        let schmal = Nachbetrachtungsbild.flaechen(d, schmal: true).compactMap {
            $0.art == .streifen ? $0.titel : nil
        }
        XCTAssertEqual(schmal, ["erster Plan", "letzter Stand", "wirklich", "perfekt"])
        let breit = Nachbetrachtungsbild.flaechen(d, schmal: false).compactMap {
            $0.art == .streifen ? $0.titel : nil
        }
        XCTAssertEqual(
            breit, ["erster Fahrplan", "letzter Stand", "wirklich", "perfekte Voraussicht"])
    }

    // MARK: - Gitter, Streifen und Schleier

    private func tagMitReihen() -> NachbetrachtungOut {
        var d = tag([], [])
        let anfang = Zeit.ausIso("2026-11-07T00:00:00+01:00")!
        d.zeiten = (0..<8).map { Zeit.iso(anfang.addingTimeInterval(Double($0) * 900)) }
        d.von = d.zeiten[0]
        d.bis = Zeit.iso(anfang.addingTimeInterval(8 * 900))
        d.verglichen = [true, true, false, false, true, true, true, true]
        d.preisCt = [12, 12, 30, 30, 8, 8, nil, 8]
        d.ueberschussKw = [0, 0, 0, 0, 1.2, 1.2, 1.2, 0]
        d.wpKw = 4
        return d
    }

    func testGitterLiestZeitenUndSchrittweite() {
        let g = Nachbetrachtungsbild.gitter(tagMitReihen())
        XCTAssertNotNil(g)
        XCTAssertEqual(g?.zeiten.count, 8)
        XCTAssertEqual(g?.schritt, 900)
        XCTAssertEqual(g?.bis.timeIntervalSince(g!.von), 8 * 900)
        // Ohne Zeitpunkte gibt es kein Bild, und die Ansicht zeichnet keines.
        XCTAssertNil(Nachbetrachtungsbild.gitter(tag([], [])))
    }

    func testVollKwhIstDieArbeitEinerViertelstundeBeiNennleistung() {
        XCTAssertEqual(Nachbetrachtungsbild.vollKwh(tagMitReihen()), 1, accuracy: 1e-9)
    }

    func testSchleierLiegtUeberDemNichtVerglichenen() {
        let d = tagMitReihen()
        let g = Nachbetrachtungsbild.gitter(d)!
        let s = Nachbetrachtungsbild.schleier(d, gitter: g)
        XCTAssertEqual(s.count, 1, "zwei Nachbarn sind ein Lauf")
        XCTAssertEqual(s[0].von, g.zeiten[2])
        XCTAssertEqual(s[0].bis, g.zeiten[3].addingTimeInterval(900))
    }

    func testStreifenFasstGleicheHelligkeitenZusammenUndLaesstLueckenLeer() {
        var d = tagMitReihen()
        // Nennarbeit 1 kWh: 0,25 ist Stufe 1, 0,9 ist Stufe 4, nichts ist Stufe 0.
        let l = Linie(
            key: "wirklich", nameDe: "wirklich", verfuegbar: true,
            wpKwhJe: [0, 0, 0.25, 0.25, 0.9, nil, 0.9, 0.9],
            ofenJe: [0, 0, 0, 0, 1, 0.3, nil, 1])
        d.linien = [l]
        let g = Nachbetrachtungsbild.gitter(d)!
        let felder = Nachbetrachtungsbild.streifen(
            l, gitter: g, vollKwh: Nachbetrachtungsbild.vollKwh(d))
        XCTAssertEqual(felder.map(\.stufe), [0, 1, 4, 4])
        // Die Lücke reißt den Lauf der Stufe vier auf: keine Aussage ist kein Stillstand.
        XCTAssertEqual(felder[2].bis, g.zeiten[4].addingTimeInterval(900))
        XCTAssertEqual(felder[3].von, g.zeiten[6])
        XCTAssertEqual(felder[3].bis, g.zeiten[7].addingTimeInterval(900))

        let ofen = Nachbetrachtungsbild.ofenspannen(l, gitter: g)
        // Nur über 0,5 brennt der Ofen; 0,3 nicht, `nil` reißt auf.
        XCTAssertEqual(ofen.count, 2)
        XCTAssertEqual(ofen[0].von, g.zeiten[4])
        XCTAssertEqual(ofen[1].von, g.zeiten[7])
    }

    func testReiheHeftetWerteAnDieZeitachseUndErfindetNichts() {
        let d = tagMitReihen()
        let g = Nachbetrachtungsbild.gitter(d)!
        let p = Nachbetrachtungsbild.reihe(d.preisCt, gitter: g)
        XCTAssertEqual(p.count, 8)
        XCTAssertNil(p[6].wert)
        // Eine zu kurze Reihe endet, statt fortgeschrieben zu werden.
        let kurz = Nachbetrachtungsbild.reihe([1, 2], gitter: g)
        XCTAssertEqual(kurz.count, 8)
        XCTAssertEqual(kurz[1].wert, 2)
        XCTAssertNil(kurz[2].wert)
    }

    // MARK: - Die Auskunft

    func testAuskunftNimmtDieViertelstundeInDerDerZeigerSteht() {
        var d = tagMitReihen()
        d.linien = [
            Linie(
                key: "wirklich", nameDe: "wirklich", verfuegbar: true,
                wpKwhJe: [0, 0, 0.25, 0.25, 0.9, 0.9, 0.9, 0.9],
                eurJe: [0, 0, 0.075, 0.075, 0.072, 0.072, 0.072, 0.072],
                eurKumuliert: [0, 0, 0.075, 0.15, 0.222, 0.294, 0.366, 0.438])
        ]
        let g = Nachbetrachtungsbild.gitter(d)!
        // 00:14 gehört zu 00:00 und nicht zu 00:15.
        let a = Nachbetrachtungsbild.auskunft(d, gitter: g, zeit: g.von.addingTimeInterval(14 * 60))
        XCTAssertEqual(a?.kopf, "00:00 bis 00:15")
        XCTAssertNil(a?.nichtVerglichen)
        XCTAssertEqual(a?.zeilen.count, 1)
        XCTAssertEqual(a?.zeilen.first?.name, "wirklich")

        // Die dritte Viertelstunde ist nicht verglichen, und das sagt die Auskunft.
        let b = Nachbetrachtungsbild.auskunft(d, gitter: g, zeit: g.zeiten[2])
        XCTAssertEqual(b?.nichtVerglichen, Nachbetrachtungsworte.nichtVerglichenSatz)

        // Wo kein Preis eingetreten ist, steht das Wort und keine Null.
        let c = Nachbetrachtungsbild.auskunft(d, gitter: g, zeit: g.zeiten[6])
        XCTAssertEqual(c?.umstaende.hasPrefix(Nachbetrachtungsworte.preisUnbekannt), true)

        // Ein Zeiger hinter dem Tag bleibt an der letzten Viertelstunde.
        let spaet = Nachbetrachtungsbild.auskunft(
            d, gitter: g, zeit: g.bis.addingTimeInterval(9999))
        XCTAssertEqual(spaet?.kopf, "01:45 bis 02:00")
    }

    /// Ein fehlender Wert ist ein Strich und kein Strich mit Einheit.
    ///
    /// `Tagesvergleich.tsx:252` schreibt `kwh == null ? "-" : ${de(kwh, 2)} kWh`. In jeder nicht
    /// verglichenen Viertelstunde liefert der Dienst `wp_kwh_je = null`, und angebaute Einheit
    /// ergab dort „- kWh“.
    func testAuskunftSchreibtOhneWertNurDenStrich() {
        var d = tagMitReihen()
        d.linien = [
            Linie(
                key: "wirklich", nameDe: "wirklich", verfuegbar: true,
                wpKwhJe: [0.225, nil, nil, nil, nil, nil, nil, nil],
                eurJe: [0.07, nil, nil, nil, nil, nil, nil, nil],
                eurKumuliert: [0.07, nil, nil, nil, nil, nil, nil, nil])
        ]
        let g = Nachbetrachtungsbild.gitter(d)!
        let mit = Nachbetrachtungsbild.auskunft(d, gitter: g, zeit: g.zeiten[0])
        XCTAssertEqual(
            mit?.zeilen.first?.kwh, "0,23" + Formate.schmalesLeerzeichen + "kWh")

        let ohne = Nachbetrachtungsbild.auskunft(d, gitter: g, zeit: g.zeiten[1])
        XCTAssertEqual(ohne?.zeilen.first?.kwh, Formate.leer)
        XCTAssertEqual(ohne?.zeilen.first?.eur, Formate.leer)

        // Und hinter dem Ende der Reihe genauso.
        var kurz = d
        kurz.linien[0].wpKwhJe = [0.225]
        let hinten = Nachbetrachtungsbild.auskunft(kurz, gitter: g, zeit: g.zeiten[3])
        XCTAssertEqual(hinten?.zeilen.first?.kwh, Formate.leer)
    }

    // MARK: - Der Kopf

    func testKopfzahlNenntDieViertelstundenUndDenErstenFahrplan() {
        var d = voll
        d.zeiten = (0..<96).map { _ in "2026-11-07T00:00:00+01:00" }
        d.nVerglichen = 88
        XCTAssertEqual(
            Nachbetrachtungsbild.kopfzahl(d), "88 von 96 Viertelstunden verglichen")
        d.ersterPlanErstellt = "2026-11-07T00:07:00+01:00"
        XCTAssertEqual(
            Nachbetrachtungsbild.kopfzahl(d),
            "88 von 96 Viertelstunden verglichen · erster Fahrplan vom Sa., 07.11. 00:07")
    }

    func testKopfsaetzeNehmenNurAbstaendeMitBetragUndSatz() {
        let d = tag(
            [linie("wirklich", 1)],
            [
                abstand("prognosefehler", "versprochen", "erster", nil),
                abstand("eingriff", "letzter", "wirklich", 3.69),
                Abstand(key: "leer", nameDe: "leer", von: "a", nach: "b", eur: 1, satzDe: ""),
            ])
        XCTAssertEqual(Nachbetrachtungsbild.kopfsaetze(d).map(\.key), ["eingriff"])
        XCTAssertEqual(Nachbetrachtungsbild.kopfsaetze(d).first?.satz, "Satz zu eingriff")
    }

    func testTageshinweiseLassenDieGruendeFehlenderLinienWeg() {
        let d = tag(
            [], [],
            hinweise: [
                "Der Tag läuft noch – die Zahlen sind vorläufig.",
                "Die Linie „versprochen“ fehlt: nicht aufbewahrt.",
                "Acht Viertelstunden sind nicht verglichen.",
            ])
        XCTAssertEqual(
            Nachbetrachtungsbild.tageshinweise(d),
            [
                "Der Tag läuft noch – die Zahlen sind vorläufig.",
                "Acht Viertelstunden sind nicht verglichen.",
            ])
    }

    func testEingriffszusatzStehtNurMitMengeUndZeitpunkt() {
        var d = voll
        XCTAssertNil(
            Nachbetrachtungsbild.eingriffszusatz(d), "ohne Zerlegung steht keine Zeile da")
        d.abstaende = [
            Abstand(
                key: "eingriff", nameDe: "Eingriff", von: "letzter", nach: "wirklich", eur: 3.69,
                mengeEur: 0.12, zeitEur: -1.84, ofenEur: 0.31)
        ]
        let s = Formate.schmalesLeerzeichen
        XCTAssertEqual(
            Nachbetrachtungsbild.eingriffszusatz(d),
            "Menge +0,12\(s)€ · Zeitpunkt \(Formate.minus)1,84\(s)€")
        d.hatOfen = true
        XCTAssertEqual(
            Nachbetrachtungsbild.eingriffszusatz(d),
            "Menge +0,12\(s)€ · Zeitpunkt \(Formate.minus)1,84\(s)€ · Ofen +0,31\(s)€")
    }

    // MARK: - Die Zahlentabelle

    func testZahlentabelleRundetWieDieVorlage() {
        var d = tag([], [], hatOfen: false)
        d.linien = [
            Linie(
                key: "wirklich", nameDe: "wirklich", verfuegbar: true, geschaetzt: false,
                eur: 4.594, ofenEur: 0.31, wpKwh: 12.34, ctJeKwh: 37.25, wpH: 3.456,
                ofenH: 1.04),
            Linie(
                key: "perfekt", nameDe: "perfekt", verfuegbar: true, geschaetzt: true, eur: 0.8,
                wpKwh: nil, ctJeKwh: nil, wpH: nil),
            Linie(
                key: "versprochen", nameDe: "versprochen", verfuegbar: false,
                grundDe: "nicht aufbewahrt"),
        ]
        let t = Nachbetrachtungsbild.zahlentabelle(d)
        XCTAssertEqual(t.zeilennamen, ["wirklich", "perfekt · geschätzt"])
        XCTAssertEqual(
            t.spalten.map(\.name), ["Kosten", "Strom", "im Mittel", "Wärmepumpe"],
            "ohne Ofen fallen beide Ofenspalten weg")
        let s = Formate.schmalesLeerzeichen
        XCTAssertEqual(t.spalten[0].zellen, ["4,59\(s)€", "0,80\(s)€"])
        XCTAssertEqual(t.spalten[1].zellen, ["12,3\(s)kWh", Formate.leer])
        XCTAssertEqual(t.spalten[2].zellen, ["37,3\(s)ct/kWh", Formate.leer])
        XCTAssertEqual(t.spalten[3].zellen, ["3,5\(s)h", Formate.leer])
        XCTAssertEqual(t.fehlende.map(\.wort), ["versprochen fehlt"])
        XCTAssertEqual(t.fehlende.first?.grund, "nicht aufbewahrt")
    }

    func testZahlentabelleZeigtDieOfenspaltenNurMitOfen() {
        var d = tag([], [], hatOfen: true)
        d.linien = [
            Linie(
                key: "wirklich", nameDe: "wirklich", verfuegbar: true, eur: 4.59, ofenEur: 0.31,
                wpKwh: 12.3, ctJeKwh: 37.2, wpH: 3.5, ofenH: 1)
        ]
        let t = Nachbetrachtungsbild.zahlentabelle(d)
        XCTAssertEqual(
            t.spalten.map(\.name),
            ["Kosten", "davon Ofen", "Strom", "im Mittel", "Wärmepumpe", "Ofen"])
    }

    func testStandbyFussnoteErstAbEinemHalbenZehntelKilowattstunde() {
        XCTAssertNil(
            Nachbetrachtungsbild.standbySatz(
                tag([], [], standbyKwh: 0.04, standbyEur: 0.01)))
        XCTAssertNil(Nachbetrachtungsbild.standbySatz(tag([], [], standbyKwh: 1.8)))
        let s = Formate.schmalesLeerzeichen
        XCTAssertEqual(
            Nachbetrachtungsbild.standbySatz(tag([], [], standbyKwh: 1.84, standbyEur: 0.44)),
            "Daneben, in keiner Linie: die Grundlast der Anlage im Stillstand, 1,8\(s)kWh für "
                + "0,44\(s)€.")
    }

    // MARK: - Die Legende

    func testLegendeTraegtJedeLinieDieStufenUndDenOfen() {
        var d = voll
        d.hatOfen = false
        let ohne = Nachbetrachtungsbild.legende(d)
        XCTAssertEqual(ohne.count, 5, "vier Linien und die Helligkeitsskala")
        XCTAssertEqual(ohne.last?.marke, .stufen)
        d.hatOfen = true
        let mit = Nachbetrachtungsbild.legende(d)
        XCTAssertEqual(mit.count, 6)
        XCTAssertEqual(mit.last?.marke, .ofen)
        XCTAssertEqual(mit.last?.wort, "Ofen brennt")
        XCTAssertEqual(
            Nachbetrachtungsworte.stufenlegende(wpKw: 4.5),
            "Strom der Wärmepumpe je Viertelstunde, bis 1,13\(Formate.schmalesLeerzeichen)kWh")
    }

    // MARK: - Der Tag aus der Adresse

    /// Dieselben Fälle, die `Nachbetrachtung.tsx:45-50` unterscheidet - und der Fall, um den es
    /// geht: der Verweis der Wärmeseite (`HeatOverview.tsx:268`) trägt den gelesenen Tag und
    /// nicht gestern.
    func testTagAusWeg() {
        let heute = "2026-11-10"
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/waerme/nachbetrachtung?day=2026-11-10", heute: heute),
            "2026-11-10")
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/waerme/nachbetrachtung?day=2026-03-01", heute: heute),
            "2026-03-01")
        // Ohne Angabe gestern.
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/waerme/nachbetrachtung", heute: heute), "2026-11-09")
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/waerme/nachbetrachtung?", heute: heute), "2026-11-09")
        // Ein Tag nach heute ist keiner, und ein erfundener auch nicht.
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/waerme/nachbetrachtung?day=2026-11-11", heute: heute),
            "2026-11-09")
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/waerme/nachbetrachtung?day=2026-02-30", heute: heute),
            "2026-11-09")
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/waerme/nachbetrachtung?day=gestern", heute: heute),
            "2026-11-09")
        // Unbekannte Felder daneben, doppeltes `day` vom letzten Vorkommen.
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/x?t=7&day=2026-01-02&z=1", heute: heute),
            "2026-01-02")
        XCTAssertEqual(
            Nachbetrachtungsbild.tag(ausWeg: "/x?day=2026-01-02&day=2026-01-03", heute: heute),
            "2026-01-03")
    }

    // MARK: - Die Vorschau

    /// Die Vorschau ist kein Schmuck: an ihr hängen die `#Preview`-Blöcke der Ansichten, und ein
    /// Beispieltag, in dem die Treppe nicht aufgeht, würde dort ein falsches Bild zeigen.
    func testVorschauTraegtTreppeStreifenUndTabelle() {
        let d = Vorschau.nachbetrachtung()
        XCTAssertEqual(d.zeiten.count, 96)
        XCTAssertEqual(d.nVerglichen, 88)
        let t = Nachbetrachtungsbild.treppe(d)
        // Ohne das Versprechen beginnt die Treppe beim gehaltenen Fahrplan.
        XCTAssertEqual(t.map(\.key), ["erster", "nachfuehren", "eingriff", "wirklich", "perfekt"])
        XCTAssertEqual(t[3].bis, t[2].bis, accuracy: 1e-9)
        let g = Nachbetrachtungsbild.gitter(d)!
        XCTAssertFalse(Nachbetrachtungsbild.schleier(d, gitter: g).isEmpty)
        XCTAssertEqual(Nachbetrachtungsbild.zeilen(d).count, 4)
        XCTAssertEqual(Nachbetrachtungsbild.zahlentabelle(d).zeilennamen.count, 4)
        XCTAssertEqual(Nachbetrachtungsbild.tageshinweise(d).count, 2)
        XCTAssertNotNil(Nachbetrachtungsbild.standbySatz(d))
        XCTAssertNotNil(Nachbetrachtungsbild.eingriffszusatz(d))
    }
}
