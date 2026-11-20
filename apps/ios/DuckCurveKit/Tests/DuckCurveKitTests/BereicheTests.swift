import XCTest

@testable import DuckCurveKit

/// Dieselben Faelle wie `apps/web/src/lib/areas.test.ts`.
///
/// Die Seitenstruktur ist der einzige Teil der Oberflaeche, der sich ohne SwiftUI pruefen laesst,
/// und zugleich der, bei dem ein Fehler am teuersten ist: ein Reiter, der zum falschen Bereich
/// gehoert, verschiebt die ganze Leiste.
final class BereicheTests: XCTestCase {
    func testVierBereicheFuerDenAlltagUndEinerFuerDieTechnik() {
        XCTAssertEqual(Bereiche.alle.map(\.name), ["Jetzt", "Haus", "Energie", "Geld", "Technik"])
    }

    func testOrdnetEinenWegSeinemBereichZu() {
        XCTAssertEqual(Bereiche.bereichVon("/").schluessel, .jetzt)
        XCTAssertEqual(Bereiche.bereichVon("/strom/speicher?period=week").schluessel, .energie)
        XCTAssertEqual(Bereiche.bereichVon("/geld/rechnungen").schluessel, .geld)
        XCTAssertEqual(Bereiche.bereichVon("/irgendwas").schluessel, .jetzt)
    }

    /// Der Kern der Umstellung vom 11.11.2026: ein Bereich ist nicht das erste Stueck des Pfads.
    func testRichtetSichNachDerLaengstenAdresse() {
        XCTAssertEqual(Bereiche.bereichVon("/waerme").schluessel, .energie)
        XCTAssertEqual(Bereiche.bereichVon("/waerme?period=day&anchor=2026-11-10").schluessel, .energie)
        XCTAssertEqual(Bereiche.bereichVon("/waerme/anlage").schluessel, .technik)
        XCTAssertEqual(Bereiche.bereichVon("/waerme/wiedergabe").schluessel, .technik)
        XCTAssertEqual(Bereiche.bereichVon("/waerme/nachbetrachtung").schluessel, .technik)
        XCTAssertEqual(Bereiche.bereichVon("/waerme/raeume").schluessel, .technik)
        XCTAssertEqual(Bereiche.bereichVon("/system").schluessel, .technik)
        XCTAssertEqual(Bereiche.bereichVon("/system/zugang").schluessel, .technik)
    }

    func testFindetDenReiterAmLaengstenPassendenWeg() {
        let energie = Bereiche.bereichVon("/strom/pv")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/strom/pv")?.name, "Photovoltaik")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/strom")?.name, "Strom")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/strom/")?.name, "Strom")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/waerme")?.name, "Wärme")
    }

    func testDasHausIstEinBereichOhneReiter() {
        XCTAssertEqual(Bereiche.bereichVon("/haus").schluessel, .haus)
        XCTAssertTrue(Bereiche.bereichVon("/haus").reiter.isEmpty)
    }

    func testKeinBereichNurFuerDenHausherrnAberReiter() {
        let technik = Bereiche.alle.first { $0.schluessel == .technik }!
        XCTAssertEqual(
            technik.reiter.filter { !$0.nurHausherr }.map(\.name),
            ["Anlage", "Wärmepumpe", "Fahrplan", "Wirkung", "Heizkreise"]
        )
        XCTAssertTrue(technik.reiter.filter { $0.weg.hasPrefix("/system") }.allSatisfy(\.nurHausherr))
    }

    func testVerweistNirgendsAufEineAlteAdresseUndNenntKeineZweimal() {
        let alt = ["/pv", "/batterie", "/wallbox", "/jahr", "/waermebilanz", "/raeume", "/prognose", "/daten", "/settings"]
        var alle: [String] = []
        for b in Bereiche.alle { alle.append(contentsOf: b.reiter.map(\.weg)) }
        for weg in alle { XCTAssertFalse(alt.contains(weg), "\(weg) ist eine alte Adresse") }
        XCTAssertEqual(Set(alle).count, alle.count, "eine Adresse steht zweimal in der Leiste")
    }

    func testZaehltDieAnsichtenEinesReitersZuIhm() {
        let technik = Bereiche.bereichVon("/waerme/anlage")
        XCTAssertEqual(Bereiche.reiterVon(technik, "/waerme/wiedergabe")?.name, "Anlage")
        XCTAssertEqual(Bereiche.reiterVon(technik, "/waerme/anlage")?.name, "Anlage")
        XCTAssertEqual(Bereiche.reiterVon(technik, "/waerme/nachbetrachtung")?.name, "Fahrplan")
        XCTAssertEqual(Bereiche.reiterVon(technik, "/waerme/raeume")?.name, "Heizkreise")
        XCTAssertEqual(
            Bereiche.ansichtVon(Bereiche.reiterVon(technik, "/waerme/wiedergabe"), "/waerme/wiedergabe")?.name,
            "Ein Tag"
        )
        XCTAssertEqual(
            Bereiche.ansichtVon(Bereiche.reiterVon(technik, "/waerme/fahrplan"), "/waerme/fahrplan")?.name,
            "Voraus"
        )
        XCTAssertNil(Bereiche.ansichtVon(Bereiche.reiterVon(technik, "/waerme/wirkung"), "/waerme/wirkung"))
    }

    func testJedeErsteAnsichtHatDieAdresseIhresReiters() {
        for b in Bereiche.alle {
            if let ersterReiter = b.reiter.first {
                XCTAssertEqual(ersterReiter.weg, b.weg, "Bereich \(b.name) zeigt nicht auf seinen ersten Reiter")
            }
            for r in b.reiter where !r.unter.isEmpty {
                XCTAssertEqual(r.unter.first?.weg, r.weg, "Reiter \(r.name) zeigt nicht auf seine erste Ansicht")
            }
        }
    }

    /// Die Wärmepumpe hat vier Ansichten - und alle vier muessen erreichbar sein, sonst findet
    /// niemand die Seite „Regler".
    func testDieWaermepumpeHatVierAnsichten() {
        let technik = Bereiche.bereichVon("/waerme/waermepumpe")
        let wp = Bereiche.reiterVon(technik, "/waerme/waermepumpe")
        XCTAssertEqual(wp?.unter.map(\.name), ["Jetzt", "Betrieb", "Kennlinie", "Regler"])
        for u in wp?.unter ?? [] {
            XCTAssertEqual(Bereiche.reiterVon(technik, u.weg)?.name, "Wärmepumpe", "\(u.weg) faellt aus dem Reiter")
        }
    }

    /// Jeder Weg, den die App kennt, muss sich einem Bereich zuordnen lassen. Sonst landet eine
    /// Mitteilung mit diesem Ziel auf der Startseite statt auf der gemeinten Seite.
    func testJederWegFindetSeinenBereich() {
        for weg in Bereiche.alleWege where weg != "/" {
            let b = Bereiche.bereichVon(weg)
            XCTAssertTrue(
                b.weg == weg || b.reiter.contains { $0.weg == weg || $0.unter.contains { $0.weg == weg } },
                "\(weg) landet im Bereich \(b.name), gehoert dort aber nicht hin"
            )
        }
    }

    func testNurHausherr() {
        XCTAssertTrue(Bereiche.nurHausherr("/geld/rechnungen"))
        XCTAssertTrue(Bereiche.nurHausherr("/system/zugang"))
        XCTAssertTrue(Bereiche.nurHausherr("/system/geraet"))
        XCTAssertFalse(Bereiche.nurHausherr("/strom"))
        XCTAssertFalse(Bereiche.nurHausherr("/waerme/anlage"))
    }
}

/// Welche Zeitspannen eine Seite anbietet.
///
/// **Die Auswahl steht am Reiter, nicht in der Seite** – das Gerippe zeichnet sie am Telefon
/// über den Reitern und kennt nur den Weg. Diese Tests halten fest, dass beide dasselbe lesen.
final class SpannenTests: XCTestCase {
    func testEineSeiteOhneZeitraumBekommtKeineWahl() {
        XCTAssertNil(Bereiche.spannen(fuer: "/"))
        XCTAssertNil(Bereiche.spannen(fuer: "/haus"))
        XCTAssertNil(Bereiche.spannen(fuer: "/waerme/anlage"))
        XCTAssertNil(Bereiche.spannen(fuer: "/strom/jahr"), "die Jahreskarte ist ein Jahr")
    }

    func testDieBerichtsseitenKennenAlleVier() {
        for weg in ["/strom", "/waerme", "/strom/pv", "/strom/speicher", "/strom/wallbox", "/geld"] {
            XCTAssertEqual(Bereiche.spannen(fuer: weg), Spanne.allCases, weg)
        }
    }

    /// **Die Ausnahmen, und warum es sie gibt.** Heizkreise zeigen Minutenwerte eines Tages –
    /// über eine Woche gelegt ergäbe das ein Bild, in dem nichts mehr zu erkennen ist. Die
    /// PV-Abrechnung ist ein Beleg und kennt nur Monat und Jahr. „Daten prüfen" zeigt ebenfalls
    /// Minutenwerte und kennt darum ebenfalls nur Tage (`DataCheck.tsx:59-68`,
    /// `showPeriods={false}`).
    func testDieAusnahmen() {
        XCTAssertEqual(Bereiche.spannen(fuer: "/waerme/raeume"), [.tag])
        XCTAssertEqual(Bereiche.spannen(fuer: "/geld/pv-abrechnung"), [.monat, .jahr])
        XCTAssertEqual(Bereiche.spannen(fuer: "/system/daten"), [.tag])
    }

    /// Eine Ansicht erbt die Spannen ihres Reiters: „Ein Tag" unter „Anlage" ist dieselbe Seite
    /// in einer anderen Richtung.
    func testEineAnsichtErbtVonIhremReiter() {
        XCTAssertNil(Bereiche.spannen(fuer: "/waerme/wiedergabe"))
        XCTAssertEqual(Bereiche.spannen(fuer: "/strom?anker=2026-11-18"), Spanne.allCases)
    }
}
