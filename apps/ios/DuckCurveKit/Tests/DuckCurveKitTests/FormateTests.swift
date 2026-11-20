import XCTest

@testable import DuckCurveKit

/// Dieselben Faelle wie `apps/web/src/lib/format/format.test.ts`.
///
/// Das ist der Zweck: was an der Wand steht und was in der App steht, soll Zeichen fuer Zeichen
/// dasselbe sein. Weicht eine der beiden Seiten ab, faellt es hier auf und nicht am iPad.
final class FormateTests: XCTestCase {
    func testKwMitKommaUndMinuszeichen() {
        XCTAssertEqual(Formate.kw(6.84), "6,8")
        XCTAssertEqual(Formate.kw(-2.4), "\u{2212}2,4")
        XCTAssertEqual(Formate.kw(0.02), "0,0")
        XCTAssertEqual(Formate.kw(nil), "-")
        XCTAssertEqual(Formate.kwMitEinheit(3.6), "3,6\u{202F}kW")
    }

    /// Ein negativer Wert knapp unter der Schwelle darf kein Vorzeichen bekommen: sonst zeigt die
    /// Wand eine Einspeisung, die es nicht gibt.
    func testKleineNegativeWerteVerlierenDasVorzeichen() {
        XCTAssertEqual(Formate.kw(-0.01), "0,0")
        XCTAssertEqual(Formate.kw(-0.04), "0,0")
        XCTAssertEqual(Formate.kw(-0.06), "\u{2212}0,1")
        XCTAssertEqual(Formate.zahl(-0.004, stellen: 1), "0,0")
    }

    func testProzentTemperaturUndPreis() {
        XCTAssertEqual(Formate.prozent(0.62), "62\u{202F}%")
        XCTAssertEqual(Formate.celsius(59.6), "60\u{202F}°C")
        XCTAssertEqual(Formate.ct(-1.25), "\u{2212}1,3\u{202F}ct/kWh")
    }

    /// `-1.25` auf eine Stelle ist der Fall, an dem sich kaufmaennisches und mathematisches
    /// Runden unterscheiden. Das Dashboard rundet kaufmaennisch, also auf `1,3`.
    func testRundetWieDasDashboard() {
        XCTAssertEqual(Formate.zahl(1.25, stellen: 1), "1,3")
        XCTAssertEqual(Formate.zahl(2.45, stellen: 1), "2,5")
        XCTAssertEqual(Formate.zahl(0.5, stellen: 0), "1")
    }

    func testUhrzeitInHauszeit() {
        // 11:42 UTC im September ist 13:42 in Berlin (Sommerzeit).
        XCTAssertEqual(Formate.hhmm(iso: "2026-09-04T11:42:00Z"), "13:42")
        // Im Januar nur eine Stunde Versatz.
        XCTAssertEqual(Formate.hhmm(iso: "2026-01-04T11:42:00Z"), "12:42")
    }

    /// Der Dienst liefert Zeitstempel in drei Formen. Alle drei muessen gelesen werden, sonst
    /// bleibt in der Anzeige ein ganzer Tag leer.
    func testLiestAlleFormenVonZeitstempeln() {
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T11:42:00Z"))
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T11:42:00.123Z"))
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T13:42:00+02:00"))
        XCTAssertNotNil(Zeit.ausIso("2026-09-04T13:42:00"))
        XCTAssertNil(Zeit.ausIso("heute"))
        XCTAssertNil(Zeit.ausIso(""))
    }

    /// Ohne Zeitzone im Text meint der Dienst die Zeit des Hauses - nicht UTC.
    func testZeitstempelOhneZoneGiltAlsHauszeit() {
        let d = Zeit.ausIso("2026-09-04T13:42:00")
        XCTAssertEqual(Formate.hhmm(d), "13:42")
    }

    func testAlterSchweigtSolangeDieWerteKommen() {
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertNil(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-10), jetzt: jetzt))
        XCTAssertEqual(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-45), jetzt: jetzt), "vor 45 s")
        XCTAssertEqual(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-600), jetzt: jetzt), "vor 10 min")
        XCTAssertEqual(Formate.alter(beobachtetAm: jetzt.addingTimeInterval(-7200), jetzt: jetzt), "vor 2 h")
    }

    func testMinutenBisIstNieNegativ() {
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(Formate.minutenBis(jetzt.addingTimeInterval(900), jetzt: jetzt), 15)
        XCTAssertEqual(Formate.minutenBis(jetzt.addingTimeInterval(-900), jetzt: jetzt), 0)
        XCTAssertNil(Formate.minutenBis(nil, jetzt: jetzt))
    }

    func testDauer() {
        XCTAssertEqual(Formate.dauer(minuten: 45), "45\u{202F}min")
        XCTAssertEqual(Formate.dauer(minuten: 60), "1\u{202F}h")
        XCTAssertEqual(Formate.dauer(minuten: 200), "3\u{202F}h 20\u{202F}min")
        XCTAssertEqual(Formate.dauer(minuten: nil), "-")
    }

    /// Nicht endliche Werte kommen aus Divisionen in der Auswertung. Sie duerfen nicht als
    /// „inf“ an der Wand landen.
    func testUnendlichUndNaNWerdenZumBindestrich() {
        XCTAssertEqual(Formate.kw(.infinity), "-")
        XCTAssertEqual(Formate.kw(.nan), "-")
        XCTAssertEqual(Formate.ct(.nan), "-")
        XCTAssertEqual(Formate.prozent(.infinity), "-")
    }
}

extension FormateTests {
    /// `zahl` nimmt seit dem ersten Uebersetzungslauf `Double?` – und muss sich dabei wie die
    /// dreizehn Geschwister verhalten, sonst ist die Falle nur verschoben.
    func testZahlOhneWertGibtDenStrich() {
        XCTAssertEqual(Formate.zahl(nil, stellen: 1), Formate.zahl(Double.nan, stellen: 1))
        // Derselbe Strich wie bei den anderen, nicht „0,0“ und nicht leer.
        XCTAssertEqual(Formate.zahl(nil, stellen: 2), Formate.kw(nil))
        XCTAssertFalse(Formate.zahl(nil, stellen: 0).isEmpty)
    }

    func testZahlMitWertBleibtWieVorher() {
        XCTAssertEqual(Formate.zahl(3.14159, stellen: 2), "3,14")
        XCTAssertEqual(Formate.zahl(-0.04, stellen: 1), "0,0")
        XCTAssertEqual(Formate.zahl(Optional(2.5), stellen: 1), "2,5")
    }

    // MARK: - tagUndUhr

    func testTagUndUhrNenntDenTagSolangeErEinWortHat() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        XCTAssertEqual(
            Formate.tagUndUhr(Zeit.ausIso("2026-11-17T14:05:00+01:00"), jetzt: jetzt),
            "heute 14:05")
        XCTAssertEqual(
            Formate.tagUndUhr(Zeit.ausIso("2026-11-18T03:15:00+01:00"), jetzt: jetzt),
            "morgen 03:15")
        XCTAssertEqual(
            Formate.tagUndUhr(Zeit.ausIso("2026-11-19T03:15:00+01:00"), jetzt: jetzt),
            "übermorgen 03:15")
        XCTAssertEqual(
            Formate.tagUndUhr(Zeit.ausIso("2026-11-16T23:45:00+01:00"), jetzt: jetzt),
            "gestern 23:45")
    }

    func testWeiterWegStehtDasKurzeDatum() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        XCTAssertEqual(
            Formate.tagUndUhr(Zeit.ausIso("2026-11-21T08:00:00+01:00"), jetzt: jetzt),
            "Sa, 21.11. 08:00")
    }

    func testTagUndUhrHaeltEinenFehlendenWertAus() {
        let jetzt = Zeit.ausIso("2026-11-17T09:30:00+01:00")!
        XCTAssertEqual(Formate.tagUndUhr(nil, jetzt: jetzt), Formate.leer)
        XCTAssertEqual(Formate.tagUndUhr(iso: "unfug", jetzt: jetzt), Formate.leer)
    }

    func testAbstandZweierTageUeberwindetDieZeitumstellung() {
        // 25. Oktober 2026 ist der Tag der Umstellung auf Winterzeit.
        XCTAssertEqual(Tag.abstand("2026-10-26", "2026-10-25"), 1)
        XCTAssertEqual(Tag.abstand("2026-10-25", "2026-10-26"), -1)
        XCTAssertEqual(Tag.abstand("2026-11-17", "2026-11-17"), 0)
        XCTAssertNil(Tag.abstand("unfug", "2026-11-17"))
    }
}

// MARK: - Die vier Formate, die aus der Vorlage stammen

/// Vier Formatierungen, die ihre Regel nicht hier, sondern in `apps/web` haben. Die Werte unten
/// sind aus der Vorlage nachgerechnet, nicht ausgedacht - deshalb steht an jeder Gruppe, welche
/// Zeile dort gemeint ist.
extension FormateTests {
    // MARK: - megabyte (StorageReport.tsx:21-24)

    /// Die Schwelle ist 1024³ und nicht 1e9: die Datenbank zählt Seiten.
    func testMegabyteSchaltetBeiEinemGibibyteUm() {
        XCTAssertEqual(Formate.megabyte(1_073_741_824), "1 GB")
        // Ein Mebibyte darunter bleibt es bei MB - und dort steht dann der Tausenderpunkt.
        XCTAssertEqual(Formate.megabyte(1_073_741_824 - 1_048_576), "1.023 MB")
        XCTAssertEqual(Formate.megabyte(1_099_511_627_776), "1.024 GB")
    }

    /// Höchstens zwei Stellen in GB, höchstens eine in MB - Nullen am Ende fallen weg, wie bei
    /// `maximumFractionDigits`. Genau ein Gigabyte ist „1 GB“ und nicht „1,00 GB“.
    func testMegabyteSchreibtHoechstensSoVieleStellenWieDieVorlage() {
        XCTAssertEqual(Formate.megabyte(1_610_612_736), "1,5 GB")      // 1,5 GiB
        XCTAssertEqual(Formate.megabyte(1_342_177_280), "1,25 GB")     // 1,25 GiB
        XCTAssertEqual(Formate.megabyte(1_048_576), "1 MB")            // genau 1 MiB
        XCTAssertEqual(Formate.megabyte(5_242_880), "5 MB")            // 5 MiB
        XCTAssertEqual(Formate.megabyte(5_505_024), "5,3 MB")          // 5,25 MiB, kaufmännisch
        XCTAssertEqual(Formate.megabyte(0), "0 MB")
    }

    /// Vor der Einheit steht hier das gewöhnliche Leerzeichen, nicht das schmale der kW-Werte -
    /// so schreibt es die Vorlage (`StorageReport.tsx:22-23`).
    func testMegabyteNimmtDasGewoehnlicheLeerzeichen() {
        XCTAssertEqual(Formate.megabyte(5_242_880), "5\u{0020}MB")
        XCTAssertFalse(Formate.megabyte(5_242_880).contains(Formate.schmalesLeerzeichen))
        // Zum Vergleich: die Leistung nimmt das schmale.
        XCTAssertTrue(Formate.kwMitEinheit(3.6).contains(Formate.schmalesLeerzeichen))
    }

    /// `Hausgeraet.bytes` rechnet dezimal und ist etwas anderes. Dieselbe Zahl, zwei Ergebnisse -
    /// das ist Absicht und darf nicht zusammenfallen.
    func testMegabyteIstNichtDieDezimaleRechnungDerPlatte() {
        XCTAssertEqual(Formate.megabyte(1_000_000_000), "953,7 MB")
        XCTAssertNotEqual(Formate.megabyte(1_000_000_000), Hausgeraet.bytes(1_000_000_000))
    }

    // MARK: - zeilen (StorageReport.tsx:26-28)

    /// Ab tausend steht „N Tsd.“, darunter die Zahl.
    func testZeilenKuerztAbTausend() {
        XCTAssertEqual(Formate.zeilen(0), "0")
        XCTAssertEqual(Formate.zeilen(1), "1")
        XCTAssertEqual(Formate.zeilen(999), "999")
        XCTAssertEqual(Formate.zeilen(1000), "1 Tsd.")
    }

    /// Gerundet, nicht abgeschnitten (`Math.round(n / 1000)`).
    func testZeilenRundetDieTausender() {
        XCTAssertEqual(Formate.zeilen(1499), "1 Tsd.")
        XCTAssertEqual(Formate.zeilen(1500), "2 Tsd.")
        XCTAssertEqual(Formate.zeilen(12_345), "12 Tsd.")
    }

    /// Millionen bekommen den Tausenderpunkt, weil `toLocaleString("de-DE")` ihn setzt.
    /// `measurements_raw` liegt genau dort.
    func testZeilenSetztDenTausenderpunktWieDieVorlage() {
        XCTAssertEqual(Formate.zeilen(999_999), "1.000 Tsd.")
        XCTAssertEqual(Formate.zeilen(1_234_567), "1.235 Tsd.")
        // Und ist damit etwas anderes als die ganze Zahl, die `zahl` schreibt.
        XCTAssertEqual(Formate.zahl(1_234_567, stellen: 0), "1234567")
    }

    // MARK: - euroMitVorzeichen (nachbetrachtung.ts:89-95)

    /// Die drei Werte, die `nachbetrachtung.test.ts:110-113` festhält.
    func testEuroMitVorzeichenWieDieVorlage() {
        XCTAssertEqual(Formate.euroMitVorzeichen(0.31), "+0,31\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(-0.8), "\u{2212}0,80\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(0), "±0,00\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(nil), Formate.leer)
    }

    /// Das Minus ist U+2212 und nicht der Bindestrich - sonst ist es in IBM Plex Sans zu kurz
    /// für eine Zahl.
    func testEuroMitVorzeichenNimmtDasEchteMinuszeichen() {
        let text = Formate.euroMitVorzeichen(-12.5)
        XCTAssertEqual(text, "\u{2212}12,50\u{202F}€")
        XCTAssertTrue(text.hasPrefix(Formate.minus))
        XCTAssertFalse(text.contains("-"))
    }

    /// Unter einem halben Cent steht ±, auf der Schwelle wieder das Vorzeichen
    /// (`nachbetrachtung.ts:93`: `Math.abs(x) < 0.005`).
    func testEuroMitVorzeichenGibtDerNullDasPlusminus() {
        XCTAssertEqual(Formate.euroMitVorzeichen(0.004), "±0,00\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(-0.004), "±0,00\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(-0.0), "±0,00\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(0.006), "+0,01\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(-0.006), "\u{2212}0,01\u{202F}€")
    }

    /// Die Summe daneben trägt kein Vorzeichen. Beide Spalten stehen untereinander, also muss
    /// alles übrige gleich sein: schmales Leerzeichen, zwei Stellen.
    func testEuroMitVorzeichenUnterscheidetSichVonEuroNurImVorzeichen() {
        XCTAssertEqual(Formate.euro(0.31), "0,31\u{202F}€")
        XCTAssertEqual(Formate.euroMitVorzeichen(0.31), "+" + Formate.euro(0.31))
        XCTAssertEqual(Formate.euroMitVorzeichen(-0.8), Formate.minus + Formate.euro(0.8))
        XCTAssertEqual(Formate.euroMitVorzeichen(.nan), Formate.leer)
        XCTAssertEqual(Formate.euroMitVorzeichen(.infinity), Formate.leer)
    }

    // MARK: - kurzDatum (wirkung.ts:96, :109-112)

    /// „Sa., 07.11.“ - mit Punkt hinter dem Wochentag und mit führender Null.
    func testKurzDatumSchreibtPunktUndFuehrendeNull() {
        XCTAssertEqual(Formate.kurzDatum(iso: "2026-11-07T14:35:00+01:00"), "Sa., 07.11.")
        XCTAssertEqual(Formate.kurzDatum(iso: "2026-01-04T11:42:00Z"), "So., 04.01.")
    }

    /// `Tag.kurz` ist etwas anderes und darf es bleiben: anderer Eingang, kein Punkt hinter dem
    /// Wochentag, keine führende Null.
    func testKurzDatumIstNichtTagKurz() {
        XCTAssertEqual(Tag.kurz("2026-11-07"), "Sa, 7.11.")
        XCTAssertNotEqual(Formate.kurzDatum(iso: "2026-11-07T14:35:00+01:00"), Tag.kurz("2026-11-07"))
    }

    /// In der Zeit des Hauses, nicht in UTC: 23:30 UTC ist schon der nächste Tag in Berlin, und
    /// „angemeldet seit“ nennte sonst den falschen.
    func testKurzDatumRechnetInHauszeit() {
        XCTAssertEqual(Formate.kurzDatum(iso: "2026-11-06T23:30:00Z"), "Sa., 07.11.")
        // Ohne Zonenangabe meint der Dienst die Hauszeit - derselbe Tag wie oben.
        XCTAssertEqual(Formate.kurzDatum(iso: "2026-11-07T00:30:00"), "Sa., 07.11.")
    }

    func testKurzDatumHaeltEinenFehlendenStempelAus() {
        XCTAssertEqual(Formate.kurzDatum(iso: nil), Formate.leer)
        XCTAssertEqual(Formate.kurzDatum(iso: "unfug"), Formate.leer)
        XCTAssertEqual(Formate.kurzDatum(iso: ""), Formate.leer)
    }
}
