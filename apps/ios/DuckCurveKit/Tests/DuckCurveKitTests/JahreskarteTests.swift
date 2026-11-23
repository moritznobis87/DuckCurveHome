import Foundation
import XCTest

@testable import DuckCurveKit

/// Die Jahreskarte nachrechnen: Skala, Farben, Achse, Texte.
///
/// **Was hier geprüft wird und warum gerade das.** Die vier ersten Prüfungen sind die der Vorlage
/// (`apps/web/src/components/reports/yearMap.test.ts:14-36`), Fall für Fall: Lücken bleiben weg,
/// ein Ausreißer kappt die Skala nicht das Jahr, die divergierende Skala liegt symmetrisch um
/// null, und ein leeres Jahr ergibt eine endliche Zahl. Dazu kommen die Fälle, die es in der
/// Vorlage nicht gibt, weil ECharts sie dort erledigt: die Achsen des Rasters (die App las sie
/// einmal falsch), die Monatsanfänge, die Rundungen und die Texte.
final class JahreskarteTests: XCTestCase {
    private static let tage = ["2026-01-01", "2026-01-02", "2026-02-01"]

    /// Eine Antwort des Dienstes bauen: `[Tag][Stunde 0-23]`, wie `schemas.py:607-619` es sagt.
    private func antwort(
        _ schluessel: String = "pv_kwh",
        tage: [String] = JahreskarteTests.tage,
        stunden: Int = 24,
        fuellen: (Int, Int) -> Double?
    ) -> YearMapOut {
        let raster = tage.indices.map { t in (0..<stunden).map { h in fuellen(t, h) } }
        let vorhanden = raster.flatMap { $0 }.compactMap { $0 }.count
        return YearMapOut(
            year: 2026, days: tage, metrics: [schluessel: raster],
            hoursWithData: vorhanden, dataSince: "2025-03-01")
    }

    // MARK: - Die vier Fälle der Vorlage

    /// `yearMap.test.ts:14-18`: fehlende Stunden bleiben weg statt als Null zu färben.
    func testFehlendeStundenBleibenOhneFarbe() {
        let r = Jahresraster.baue(
            antwort { t, h in t == 0 && h < 12 ? 1 : nil }, kennzahl: .erzeugung)
        var gefaerbt = 0
        for t in 0..<3 {
            for h in 0..<24 {
                if r.farbe(tag: t, stunde: h) != nil { gefaerbt += 1 }
            }
        }
        XCTAssertEqual(gefaerbt, 12)
        XCTAssertNil(r.farbe(tag: 0, stunde: 12))
        XCTAssertNil(r.hinweis(tag: 0, stunde: 12))
        XCTAssertNotNil(r.farbe(tag: 0, stunde: 11))
    }

    /// `yearMap.test.ts:20-25`: 71 Stunden mit 1 kWh, eine mit 100 - die Skala endet bei 1.
    func testAusreisserKapptDieSkalaNicht() {
        let r = Jahresraster.baue(
            antwort { t, h in t == 0 && h == 0 ? 100 : 1 }, kennzahl: .erzeugung)
        XCTAssertEqual(r.grenze, 1, accuracy: 1e-9)
        // Der wahre Größtwert verschwindet nicht - er steht in der Fußnote.
        XCTAssertEqual(r.groesster, 100)
        XCTAssertTrue(r.fussnote.contains("bis 100,00"))
        // Und der Ausreißer landet am oberen Ende der Rampe, nicht jenseits davon.
        XCTAssertEqual(r.anteil(100), 1, accuracy: 1e-9)
        XCTAssertEqual(r.farbe(tag: 0, stunde: 0), Marken.rampeEigen.last)
    }

    /// `yearMap.test.ts:27-31`: die divergierende Skala liegt symmetrisch um null.
    func testDivergierendeSkalaIstSymmetrisch() {
        let r = Jahresraster.baue(
            antwort("grid_net_kwh") { t, _ in t == 0 ? -3 : 1 }, kennzahl: .netz)
        XCTAssertTrue(r.kennzahl.divergierend)
        XCTAssertEqual(r.grenze, 3, accuracy: 1e-9)
        XCTAssertGreaterThan(r.grenze, 0)
        // Null liegt in der Mitte, die Pole an den Enden.
        XCTAssertEqual(r.anteil(0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(r.anteil(-3), 0, accuracy: 1e-9)
        XCTAssertEqual(r.anteil(3), 1, accuracy: 1e-9)
        // Einspeisung ist Bernstein, Bezug ist Mist - der Anfang und das Ende der Rampe.
        XCTAssertEqual(r.farbe(tag: 0, stunde: 0), Marken.rampeNetzBilanz.first)
        XCTAssertEqual(r.pole?.rechts, "Bezug")
        XCTAssertEqual(r.pole?.links, "Einspeisung")
    }

    /// `yearMap.test.ts:33-36`: ein leeres Jahr ergibt eine endliche Skala.
    func testLeeresJahrBleibtEndlich() {
        let r = Jahresraster.baue(antwort { _, _ in nil }, kennzahl: .erzeugung)
        XCTAssertTrue(r.grenze.isFinite)
        XCTAssertEqual(r.grenze, 1, accuracy: 1e-9)
        XCTAssertNil(r.kleinster)
        XCTAssertNil(r.groesster)
        XCTAssertFalse(r.hatStundenwerte)
        // Kein Werteumfang in der Fußnote, wenn es keinen gibt.
        XCTAssertFalse(r.fussnote.contains("Werteumfang"))
    }

    // MARK: - Die Achsen

    /// Tage sind Spalten, Stunden sind Zeilen - und das war in der App einmal verdreht.
    ///
    /// Vorher las die Seite dieselbe Liste als Wochenzeilen mit sieben Spalten. Dieser Fall ist
    /// der Wächter dagegen: Stunde 23 des ersten Tages muss einen Wert haben.
    func testTageSindSpaltenUndStundenSindZeilen() {
        // Nur Stunde 23 ist belegt - bei der alten Lesart wäre nichts davon im Bild.
        let r = Jahresraster.baue(antwort { _, h in h == 23 ? 5 : nil }, kennzahl: .erzeugung)
        XCTAssertEqual(r.wert(tag: 0, stunde: 23), 5)
        XCTAssertEqual(r.wert(tag: 2, stunde: 23), 5)
        XCTAssertNil(r.wert(tag: 0, stunde: 6))
        XCTAssertEqual(r.zellen.count, 3)
        XCTAssertEqual(r.zellen[0].count, 24)
    }

    /// Ein Tag, den der Dienst kürzer meldet, bricht nichts.
    func testKurzerTagGibtNilStattAbsturz() {
        let r = Jahresraster.baue(antwort(stunden: 7) { _, _ in 2 }, kennzahl: .erzeugung)
        XCTAssertEqual(r.wert(tag: 0, stunde: 6), 2)
        XCTAssertNil(r.wert(tag: 0, stunde: 7))
        XCTAssertNil(r.wert(tag: 0, stunde: 23))
        XCTAssertNil(r.wert(tag: 99, stunde: 0))
        XCTAssertNil(r.wert(tag: -1, stunde: 0))
        XCTAssertNil(r.wert(tag: 0, stunde: -1))
    }

    /// Beschriftet wird der Monatsanfang, nicht jeder zehnte Tag.
    func testMonatsanfaengeTragenDieTagesachse() {
        let r = Jahresraster.baue(antwort { _, _ in 1 }, kennzahl: .erzeugung)
        XCTAssertEqual(r.monatsanfaenge.map(\.spalte), [0, 2])
        XCTAssertEqual(r.monatsanfaenge.map(\.name), ["Jan", "Feb"])
    }

    /// Die Kürzel der Achse stehen ohne Punkt - anders als die der Sätze.
    func testMonatskuerzelOhnePunkt() {
        XCTAssertEqual(Jahresraster.monatskuerzel.count, 12)
        XCTAssertFalse(Jahresraster.monatskuerzel.contains { $0.contains(".") })
        XCTAssertEqual(Jahresraster.monatskuerzel[2], "Mär")
        XCTAssertEqual(Jahresraster.monatskuerzel[8], "Sep")
        // Die Liste der Sätze hat den Punkt, und das bleibt so.
        XCTAssertEqual(Namen.monateKurz[8], "Sept.")
    }

    /// Ein ganzes Jahr: zwölf Monatsanfänge, und der Januar in Spalte null.
    func testGanzesJahrHatZwoelfMonatsanfaenge() {
        var tage: [String] = []
        var t = "2026-01-01"
        while t.hasPrefix("2026") {
            tage.append(t)
            t = Tag.plus(t, 1)
        }
        XCTAssertEqual(tage.count, 365)
        let r = Jahresraster.baue(antwort(tage: tage) { _, _ in 1 }, kennzahl: .erzeugung)
        XCTAssertEqual(r.monatsanfaenge.count, 12)
        XCTAssertEqual(r.monatsanfaenge.first?.spalte, 0)
        XCTAssertEqual(r.monatsanfaenge.last?.name, "Dez")
        XCTAssertTrue(r.fussnote.contains("von 8760 Stunden erfasst"))
    }

    /// Jede sechste Stunde trägt ein Wort, die anderen tragen nur Höhe.
    func testJedeSechsteStundeBeschriftet() {
        let beschriftet = (0..<24).filter { Jahresraster.stundeBeschriftet($0) }
        XCTAssertEqual(beschriftet, [0, 6, 12, 18])
    }

    // MARK: - Rechnen an den Rändern

    /// Eine Grenze von null ergibt keine Division durch null.
    ///
    /// Ein Jahr, in dem jede gemessene Stunde genau null ist, kommt vor - ein Zähler, der
    /// angeschlossen und nicht angeschaltet war. Die Vorlage rechnet dort `NaN` und malt nichts.
    func testGrenzeNullGibtKeinenUnwert() {
        let sequenziell = Jahresraster.baue(antwort { _, _ in 0 }, kennzahl: .erzeugung)
        XCTAssertEqual(sequenziell.grenze, 1, accuracy: 1e-9)
        XCTAssertTrue(sequenziell.anteil(0).isFinite)
        let divergierend = Jahresraster.baue(
            antwort("grid_net_kwh") { _, _ in 0 }, kennzahl: .netz)
        XCTAssertEqual(divergierend.grenze, 0, accuracy: 1e-9)
        XCTAssertEqual(divergierend.anteil(0), 0.5, accuracy: 1e-9)
        XCTAssertNotNil(divergierend.farbe(tag: 0, stunde: 0))
    }

    /// Negative Werte auf einer einfarbigen Skala landen am unteren Ende, nicht jenseits davon.
    func testNegativeWerteAufEinfarbigerSkala() {
        let r = Jahresraster.baue(
            antwort { t, _ in t == 0 ? -4 : 2 }, kennzahl: .erzeugung)
        XCTAssertEqual(r.grenze, 2, accuracy: 1e-9)
        XCTAssertEqual(r.anteil(-4), 0, accuracy: 1e-9)
        XCTAssertEqual(r.farbe(tag: 0, stunde: 0), Marken.rampeEigen.first)
        XCTAssertEqual(r.kleinster, -4)
    }

    /// Ein Unwert im Raster ist wie eine Lücke.
    func testUnwertGiltAlsLuecke() {
        let r = Jahresraster.baue(
            antwort { t, h in t == 0 && h == 0 ? Double.nan : 1 }, kennzahl: .erzeugung)
        XCTAssertNil(r.wert(tag: 0, stunde: 0))
        XCTAssertNil(r.farbe(tag: 0, stunde: 0))
        XCTAssertEqual(r.groesster, 1)
    }

    /// Eine Kennzahl, die der Dienst nicht liefert, ergibt eine leere Fläche - keine erfundene.
    func testFehlendeKennzahlGibtLeereFlaeche() {
        let r = Jahresraster.baue(antwort("pv_kwh") { _, _ in 3 }, kennzahl: .waermepumpe)
        XCTAssertTrue(r.zellen.isEmpty)
        XCTAssertNil(r.wert(tag: 0, stunde: 0))
        XCTAssertTrue(r.grenze.isFinite)
    }

    /// Ein Jahr ohne Tage: keine Spalten, keine Monatsmarken, und eine lesbare Fußnote.
    func testJahrOhneTage() {
        let r = Jahresraster.baue(
            YearMapOut(year: 2026, days: [], metrics: [:], hoursWithData: 0), kennzahl: .netz)
        XCTAssertTrue(r.monatsanfaenge.isEmpty)
        XCTAssertFalse(r.hatStundenwerte)
        XCTAssertTrue(r.fussnote.contains("0 von 0 Stunden erfasst"))
    }

    /// Das 98. Perzentil Schritt für Schritt - dieselbe Rechnung wie `charts.ts:420-424`.
    func testRobusteGrenzeZaehltWieDieVorlage() {
        XCTAssertEqual(Jahresraster.robusteGrenze([]), 1, accuracy: 1e-9)
        XCTAssertEqual(Jahresraster.robusteGrenze([7]), 7, accuracy: 1e-9)
        // Hundert Werte: `floor(100 * 0.98)` ist 98, also der neunundneunzigste der Sortierung.
        let hundert = (1...100).map(Double.init)
        XCTAssertEqual(Jahresraster.robusteGrenze(hundert), 99, accuracy: 1e-9)
        // Die Reihenfolge der Eingabe darf nichts ändern.
        XCTAssertEqual(Jahresraster.robusteGrenze(hundert.reversed()), 99, accuracy: 1e-9)
        XCTAssertEqual(Jahresraster.robusteGrenze([5, 5]), 5, accuracy: 1e-9)
    }

    // MARK: - Die acht Kennzahlen

    /// Reihenfolge, Schlüssel und Vorgabe - alles wie in der Vorlage.
    func testAchtKennzahlenInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            Jahreskennzahl.allCases.map(\.rawValue),
            [
                "grid_net_kwh", "pv_kwh", "house_kwh", "heat_pump_kwh",
                "import_kwh", "export_kwh", "price_ct_kwh", "autarky",
            ])
        XCTAssertEqual(
            Jahreskennzahl.allCases.map(\.name),
            [
                "Netz", "Erzeugung", "Verbrauch", "Wärmepumpe",
                "Netzbezug", "Einspeisung", "Strompreis", "Autarkie",
            ])
        XCTAssertEqual(Jahreskennzahl.allCases.first, .netz)
        // Der tote Fall der alten Seite: der Schlüssel heißt `price_ct_kwh`, nicht `price_ct`.
        XCTAssertNil(Jahreskennzahl(rawValue: "price_ct"))
        XCTAssertEqual(Jahreskennzahl(rawValue: "price_ct_kwh"), .preis)
    }

    /// Einheiten und Stellen je Kennzahl.
    func testEinheitUndStellen() {
        XCTAssertEqual(Jahreskennzahl.preis.einheit, "ct/kWh")
        XCTAssertEqual(Jahreskennzahl.preis.stellen, 1)
        XCTAssertEqual(Jahreskennzahl.autarkie.einheit, "")
        XCTAssertEqual(Jahreskennzahl.autarkie.stellen, 2)
        XCTAssertEqual(Jahreskennzahl.netz.einheit, "kWh")
        XCTAssertEqual(Jahreskennzahl.netz.stellen, 2)
        for k in Jahreskennzahl.allCases where k != .preis && k != .autarkie {
            XCTAssertEqual(k.einheit, "kWh", "\(k.rawValue)")
        }
    }

    /// Die Rampen: Bernstein für eigene Energie, Mist für das Netz, Terrakotta für die Wärme.
    func testRampenzuordnung() {
        XCTAssertEqual(Jahreskennzahl.netz.rampe, Marken.rampeNetzBilanz)
        XCTAssertEqual(Jahreskennzahl.erzeugung.rampe, Marken.rampeEigen)
        XCTAssertEqual(Jahreskennzahl.einspeisung.rampe, Marken.rampeEigen)
        XCTAssertEqual(Jahreskennzahl.autarkie.rampe, Marken.rampeEigen)
        XCTAssertEqual(Jahreskennzahl.verbrauch.rampe, Marken.rampeNetz)
        XCTAssertEqual(Jahreskennzahl.netzbezug.rampe, Marken.rampeNetz)
        XCTAssertEqual(Jahreskennzahl.preis.rampe, Marken.rampeNetz)
        XCTAssertEqual(Jahreskennzahl.waermepumpe.rampe, Marken.rampeWaerme)
        // Nur eine Karte hat zwei Pole.
        XCTAssertEqual(Jahreskennzahl.allCases.filter(\.divergierend), [.netz])
        XCTAssertNil(Jahreskennzahl.erzeugung.pole)
    }

    /// Jede Kennzahl hat einen Erklärsatz, und keiner endet auf einen Punkt - die Fußnote
    /// setzt ihn (`YearMap.tsx:132`).
    func testJedeKennzahlHatEinenHinweis() {
        for k in Jahreskennzahl.allCases {
            XCTAssertFalse(k.hinweis.isEmpty, "\(k.rawValue)")
            XCTAssertFalse(k.hinweis.hasSuffix("."), "\(k.rawValue)")
            XCTAssertFalse(k.name.isEmpty, "\(k.rawValue)")
        }
    }

    // MARK: - Skala und Hinweisfenster

    /// Unter fünf eine Nachkommastelle, sonst keine (`charts.ts:535`).
    func testSkalenstellenNachGrenze() {
        let klein = Jahresraster.baue(antwort { _, _ in 0.8 }, kennzahl: .erzeugung)
        XCTAssertEqual(klein.grenze, 0.8, accuracy: 1e-9)
        XCTAssertEqual(klein.skalenstellen, 1)
        XCTAssertEqual(klein.skalaRechts, "0,8\u{202F}kWh")
        XCTAssertEqual(klein.skalaLinks, "0,0\u{202F}kWh")

        let gross = Jahresraster.baue(antwort { _, _ in 40 }, kennzahl: .erzeugung)
        XCTAssertEqual(gross.skalenstellen, 0)
        XCTAssertEqual(gross.skalaRechts, "40\u{202F}kWh")
        XCTAssertEqual(gross.skalaLinks, "0\u{202F}kWh")
    }

    /// Bei der Netzbilanz trägt das linke Ende der Skala ein Minus.
    func testSkalaDivergierendZeigtBeidePole() {
        let r = Jahresraster.baue(
            antwort("grid_net_kwh") { t, _ in t == 0 ? -12 : 8 }, kennzahl: .netz)
        XCTAssertEqual(r.skalaRechts, "12\u{202F}kWh")
        XCTAssertEqual(r.skalaLinks, "\u{2212}12\u{202F}kWh")
    }

    /// Die Autarkie hat keine Einheit, also steht an der Skala nur die Zahl.
    func testSkalaOhneEinheit() {
        let r = Jahresraster.baue(antwort("autarky") { _, _ in 0.75 }, kennzahl: .autarkie)
        XCTAssertEqual(r.skalaRechts, "0,8")
        XCTAssertEqual(r.skalaLinks, "0,0")
    }

    /// Die drei Zeilen über einer Zelle, Wort für Wort.
    func testHinweisfensterHatDreiZeilen() {
        let r = Jahresraster.baue(
            antwort(tage: ["2026-02-10"]) { _, h in h == 7 ? 3.456 : nil },
            kennzahl: .erzeugung)
        let h = r.hinweis(tag: 0, stunde: 7)
        XCTAssertEqual(h?.datum, "Di., 10. Februar 2026")
        XCTAssertEqual(h?.stunde, "07:00 - 07:59")
        XCTAssertEqual(h?.wert, "3,46\u{202F}kWh")
        XCTAssertEqual(h?.tag, "2026-02-10")
        XCTAssertEqual(h?.stundenzahl, 7)
    }

    /// Der Preis rundet auf eine Stelle, die Autarkie auf zwei und ohne Einheit.
    func testHinweisfensterRundetJeKennzahl() {
        let preis = Jahresraster.baue(
            antwort("price_ct_kwh", tage: ["2026-03-01"]) { _, _ in 28.44 }, kennzahl: .preis)
        XCTAssertEqual(preis.hinweis(tag: 0, stunde: 0)?.wert, "28,4\u{202F}ct/kWh")

        let anteil = Jahresraster.baue(
            antwort("autarky", tage: ["2026-03-01"]) { _, _ in 0.736 }, kennzahl: .autarkie)
        XCTAssertEqual(anteil.hinweis(tag: 0, stunde: 0)?.wert, "0,74")
    }

    /// Mitternacht und die letzte Stunde schreiben sich zweistellig.
    func testHinweisfensterStundeZweistellig() {
        let r = Jahresraster.baue(antwort(tage: ["2026-06-07"]) { _, _ in 1 }, kennzahl: .erzeugung)
        XCTAssertEqual(r.hinweis(tag: 0, stunde: 0)?.stunde, "00:00 - 00:59")
        XCTAssertEqual(r.hinweis(tag: 0, stunde: 23)?.stunde, "23:00 - 23:59")
        // Der 7. Juni 2026 ist ein Sonntag.
        XCTAssertEqual(r.hinweis(tag: 0, stunde: 0)?.datum, "So., 07. Juni 2026")
    }

    /// Ein unbrauchbarer Tag gibt den Rohtext zurück, statt ein Datum zu erfinden.
    func testDatumLangFaelltAufDenRohtextZurueck() {
        XCTAssertEqual(Jahresraster.datumLang("kein Tag"), "kein Tag")
        XCTAssertEqual(Jahresraster.datumLang("2026-02-30"), "2026-02-30")
    }

    // MARK: - Die Fußnote

    /// Alle vier Teile, in der Reihenfolge der Vorlage.
    func testFussnoteHatVierTeile() {
        let r = Jahresraster.baue(
            antwort("grid_net_kwh") { t, h in t == 0 && h < 6 ? -2.5 : 4.25 }, kennzahl: .netz)
        let f = r.fussnote
        XCTAssertTrue(f.hasPrefix(Jahreskennzahl.netz.hinweis + ". "))
        XCTAssertTrue(f.contains(Jahresraster.ortszeitsatz))
        XCTAssertTrue(f.contains("72 von 72 Stunden erfasst."))
        XCTAssertTrue(f.contains("Werteumfang \u{2212}2,50 bis 4,25\u{202F}kWh;"))
        XCTAssertTrue(f.contains("endet beim 98. Perzentil"))
    }

    /// Ohne Einheit kein Leerzeichen vor dem Strichpunkt.
    ///
    /// Die Vorlage setzt dort unbesehen `${unit}` ein und schreibt bei der Autarkie „0,98 ;“ -
    /// ein Leerzeichen vor einem Satzzeichen. Hier fällt es weg; dieselbe Entscheidung wie an
    /// der Skala.
    func testFussnoteOhneEinheitOhneLuecke() {
        let r = Jahresraster.baue(
            antwort("autarky") { t, _ in t == 0 ? 0.12 : 0.98 }, kennzahl: .autarkie)
        XCTAssertTrue(r.fussnote.contains("Werteumfang 0,12 bis 0,98;"))
        XCTAssertFalse(r.fussnote.contains(" ;"))
    }

    /// Die Stundenabdeckung zählt Tage mal vierundzwanzig, nicht die gemeldeten Zellen.
    func testFussnoteZaehltTageMalVierundzwanzig() {
        let r = Jahresraster.baue(
            YearMapOut(
                year: 2026, days: JahreskarteTests.tage,
                metrics: ["pv_kwh": [[1], [1], [1]]], hoursWithData: 3),
            kennzahl: .erzeugung)
        XCTAssertTrue(r.fussnote.contains("3 von 72 Stunden erfasst."))
    }

    // MARK: - Die Sätze und die Jahreswahl

    func testSaetzeDerSeite() {
        XCTAssertEqual(Jahresraster.laedtSatz, "Jahr wird geladen …")
        XCTAssertEqual(
            Jahresraster.keineStundenSatz(jahr: 2024), "Für 2024 liegen keine Stundenwerte vor.")
        XCTAssertEqual(Jahresraster.kicker, "365 Tage × 24 Stunden")
    }

    /// Vier Jahre, das laufende zuerst - und keines davor.
    func testJahreswahlVierJahreAbsteigend() {
        guard let mitte = Tag.date("2026-07-15") else { return XCTFail("kein Tag") }
        XCTAssertEqual(Jahresraster.jahreswahl(jetzt: mitte), [2026, 2025, 2024, 2023])
        // Am Silvesterabend in Ortszeit ist es noch dasselbe Jahr.
        guard let silvester = Tag.date("2026-12-31") else { return XCTFail("kein Tag") }
        XCTAssertEqual(Jahresraster.jahreswahl(jetzt: silvester).first, 2026)
    }

    // MARK: - Der Weg in die Wiedergabe

    func testWiedergabezielAusWeg() {
        let z = Wiedergabeziel.ausWeg("/waerme/wiedergabe?day=2026-02-10&t=7")
        XCTAssertEqual(z?.tag, "2026-02-10")
        XCTAssertEqual(z?.stunde, 7)
        XCTAssertEqual(z?.weg, "/waerme/wiedergabe?day=2026-02-10&t=7")
        // Die Reihenfolge der Felder ist einerlei, unbekannte Felder stören nicht.
        XCTAssertEqual(Wiedergabeziel.ausWeg("/x?t=0&z=1&day=2026-01-01")?.stunde, 0)
    }

    /// Was kein Ziel ist, wird keines - statt die Wiedergabe auf einen erfundenen Tag zu schicken.
    func testWiedergabezielWeistUnsinnAb() {
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe"))
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe?"))
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe?day=2026-02-10"))
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe?t=7"))
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe?day=2026-02-30&t=7"))
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe?day=2026-02-10&t=24"))
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe?day=2026-02-10&t=-1"))
        XCTAssertNil(Wiedergabeziel.ausWeg("/waerme/wiedergabe?day=2026-02-10&t=sieben"))
        XCTAssertNil(Wiedergabeziel(tag: "2026-13-01", stunde: 3))
        XCTAssertNil(Wiedergabeziel(tag: "2026-02-10", stunde: 24))
        XCTAssertNotNil(Wiedergabeziel(tag: "2026-02-10", stunde: 23))
    }

    // MARK: - Wo der Schieber der Wiedergabe anfängt

    /// Zeitpunkte in Hauszeit, `anzahl` Stück ab `abStunde` im Abstand von fünf Minuten.
    private func zeitpunkte(abStunde: Int, anzahl: Int) -> [String] {
        (0..<anzahl).map { i in
            let minuten = abStunde * 60 + i * 5
            return String(format: "2026-02-10T%02d:%02d:00", minuten / 60, minuten % 60)
        }
    }

    /// Am lückenlosen Tag ist das Nachsehen so gut wie das Rechnen: 7 Uhr ist das 84. Bild.
    func testBildstelleAmLueckenlosenTag() {
        let dicht = zeitpunkte(abStunde: 0, anzahl: 288)
        XCTAssertEqual(Wiedergabeziel.bildstelle(stunde: 0, zeitpunkte: dicht), 0)
        XCTAssertEqual(Wiedergabeziel.bildstelle(stunde: 7, zeitpunkte: dicht), 84)
        XCTAssertEqual(Wiedergabeziel.bildstelle(stunde: 23, zeitpunkte: dicht), 276)
    }

    /// **Der eigentliche Fall.** Fehlen dem Tag die Vormittagsstunden, dann ist das 84. Bild nicht
    /// das von 7 Uhr - `frames` ist kein dichtes Band (`schemas.py:1832-1835`). Gesucht ist das
    /// erste Bild ab der Stunde, und das trägt hier 11 Uhr.
    func testBildstelleFaelltBeiEinerLueckeNichtAufDieFalscheStunde() {
        let mitLuecke = zeitpunkte(abStunde: 0, anzahl: 72) + zeitpunkte(abStunde: 11, anzahl: 156)
        let stelle = Wiedergabeziel.bildstelle(stunde: 7, zeitpunkte: mitLuecke)
        XCTAssertEqual(stelle, 72)
        XCTAssertNotEqual(stelle, 84, "die alte Rechnung stunde * 60 / stepMin")
        XCTAssertEqual(mitLuecke[stelle], "2026-02-10T11:00:00")
        // Vor der Lücke wird weiter genau getroffen.
        XCTAssertEqual(Wiedergabeziel.bildstelle(stunde: 5, zeitpunkte: mitLuecke), 60)
    }

    /// Hört der Tag vor der gesuchten Stunde auf, bleibt der Schieber auf dem letzten Bild -
    /// weiter geht es dort nicht.
    func testBildstelleHinterDemLetztenBildUndOhneBilder() {
        let halberTag = zeitpunkte(abStunde: 0, anzahl: 144)
        XCTAssertEqual(Wiedergabeziel.bildstelle(stunde: 20, zeitpunkte: halberTag), 143)
        XCTAssertEqual(Wiedergabeziel.bildstelle(stunde: 7, zeitpunkte: []), 0)
        // Ein unlesbarer Zeitstempel zählt nicht als Treffer, wirft aber auch nichts um.
        XCTAssertEqual(Wiedergabeziel.bildstelle(stunde: 7, zeitpunkte: ["krumm"]), 0)
    }
}
