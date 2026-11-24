import XCTest

@testable import DuckCurveKit

/// Die Swift-Fassung von `apps/web/src/lib/areas.test.ts:48-53` („verweist nirgends auf eine alte
/// Adresse und nennt keine Adresse zweimal“), erweitert um das, was die Vorlage in zwei Programmen
/// hält: die Liste in `next.config.ts:18-30` und die Weiterleitungsseite
/// `apps/web/src/app/waerme/bilanz/page.tsx`.
///
/// **Warum dieser Test der wichtigste Teil des Umbaus ist.** Die alten Adressen stehen in der
/// Vorlage schon zweimal (`next.config.ts` und `areas.test.ts`), mit der App ein drittes Mal.
/// Eine Abschrift ohne Prüfung läuft auseinander; hier fällt es auf.
///
/// **Die Liste steht jetzt in ``Bereiche``** (``Bereiche/weiterleitungen``), neben
/// ``Bereiche/alleWege``, und nicht mehr in `Zustand/AlteWege.swift`: beide Listen antworten auf
/// dieselbe Frage, und solange sie auseinanderlagen, stand das Putzen der Adresse zweimal da.
/// Die Fälle und ihre Erwartungen sind dieselben geblieben - nur die Namen davor sind neu.
final class AlteWegeTests: XCTestCase {
    /// Die neun einstufigen Adressen, die `apps/web/src/lib/areas.test.ts:49` aufzählt.
    private let alteAusDerVorlage = [
        "/pv", "/batterie", "/wallbox", "/jahr", "/waermebilanz", "/raeume", "/prognose", "/daten",
        "/settings",
    ]

    func testJedeAlteAdresseDerVorlageStehtInDerTabelle() {
        for alt in alteAusDerVorlage {
            XCTAssertNotNil(Bereiche.weiterleitungen[alt], "\(alt) fehlt in der Tabelle der alten Wege")
        }
        // Zwölf Paare aus `next.config.ts` und eines aus der Weiterleitungsseite.
        XCTAssertEqual(Bereiche.weiterleitungen.count, 13)
        XCTAssertEqual(Bereiche.weiterleitungen["/system/uebersicht"], "/einstellen")
    }

    /// `/haus` fehlt mit Absicht - die Vorlage sagt es im Kommentar (`next.config.ts:15-16`).
    func testHausIstKeineAlteAdresse() {
        XCTAssertNil(Bereiche.weiterleitungen["/haus"])
        XCTAssertEqual(Bereiche.ziel("/haus"), "/haus")
    }

    /// Das Gegenstück zu `areas.test.ts:50-52`: keine alte Adresse steht selbst in der Leiste.
    func testKeineAlteAdresseIstEinWegDerApp() {
        let alleWege = Set(Bereiche.alleWege)
        for alt in Bereiche.weiterleitungen.keys {
            XCTAssertFalse(alleWege.contains(alt), "\(alt) ist alt und steht trotzdem in der Leiste")
        }
    }

    /// Jede Kette endet auf einer Seite, die es gibt. Sonst wäre die Weiterleitung nur ein
    /// anderer Weg zu „Diese Seite kennt die App nicht“.
    func testJedeAlteAdresseFuehrtAufEinenWegDenDieAppKennt() {
        let alleWege = Set(Bereiche.alleWege)
        for alt in Bereiche.weiterleitungen.keys {
            let ziel = Bereiche.ziel(alt)
            XCTAssertTrue(alleWege.contains(ziel), "\(alt) führt auf \(ziel), und das ist keine Seite")
        }
    }

    /// Kein Kreis und keine halbe Auflösung: nach ``Bereiche/ziel(_:)`` passt kein Eintrag mehr.
    func testKeinZielIstSelbstEineAlteAdresse() {
        for alt in Bereiche.weiterleitungen.keys {
            let ziel = Bereiche.ziel(alt)
            XCTAssertNil(Bereiche.weiterleitungen[ziel], "\(alt) löst auf \(ziel) auf, und das ist wieder alt")
        }
    }

    /// Die Vorlage läuft hier zweistufig: `/waermebilanz` → `/waerme/bilanz`
    /// (`next.config.ts:25`) → `/waerme` (`bilanz/page.tsx:14`).
    func testDieAlteGeraeteadresseLaeuftUeberZweiStufen() {
        XCTAssertEqual(Bereiche.weiterleitungen["/waermebilanz"], "/waerme/bilanz")
        XCTAssertEqual(Bereiche.ziel("/waermebilanz"), "/waerme")
    }

    /// Die Bilanz ist in der Wärmeübersicht aufgegangen (`HeatOverview.tsx:19-23`).
    func testDieBilanzadresseFuehrtAufDieWaermeuebersicht() {
        XCTAssertEqual(Bereiche.ziel("/waerme/bilanz"), "/waerme")
    }

    /// Der Fragezeichenteil wird nicht mitgetragen - der Zeitraum hängt in der App am Bereich,
    /// nicht an der Adresse. Zwei Träger für dieselbe Angabe wären zwei Wahrheiten.
    func testDerFragezeichenteilUndEndendeSchraegstricheFallenWeg() {
        XCTAssertEqual(Bereiche.ziel("/waerme/bilanz?period=day&anchor=2026-11-10"), "/waerme")
        XCTAssertEqual(Bereiche.ziel("/waermebilanz/"), "/waerme")
        XCTAssertEqual(Bereiche.ziel("/waermebilanz/?period=week"), "/waerme")
        XCTAssertEqual(Bereiche.ziel("/strom/pv/"), "/strom/pv")
    }

    /// Und trotzdem bleibt der Zeitraum stehen: alt und neu liegen im selben Bereich und am
    /// selben Reiter, und dort hängt er (`Navigation.swift:22,69-81`).
    func testDieWeiterleitungWechseltDenBereichNicht() {
        let alt = Bereiche.bereichVon("/waerme/bilanz")
        let neu = Bereiche.bereichVon("/waerme")
        XCTAssertEqual(alt.schluessel, .energie)
        XCTAssertEqual(alt.schluessel, neu.schluessel)
        XCTAssertEqual(Bereiche.reiterVon(alt, "/waerme/bilanz")?.name, "Wärme")
        XCTAssertEqual(Bereiche.spannen(fuer: "/waerme")?.count, Spanne.allCases.count)
    }

    /// Ein Weg, der nicht alt ist, kommt unverändert zurück - nur geputzt. Insbesondere darf
    /// ``Bereiche/ziel(_:)`` nicht aus jedem unbekannten Weg eine Startseite machen.
    func testEinUnbekannterWegKommtGeputztZurueck() {
        XCTAssertEqual(Bereiche.ziel("/irgendwas?x=1"), "/irgendwas")
        XCTAssertEqual(Bereiche.ziel("/waerme"), "/waerme")
        XCTAssertEqual(Bereiche.ziel("/"), "/")
        XCTAssertEqual(Bereiche.ziel("//"), "/")
        XCTAssertEqual(Bereiche.ziel(""), "/")
        XCTAssertEqual(Bereiche.ziel("?period=day"), "/")
    }

    /// Jeder Weg der App bleibt, wie er ist: ``Bereiche/ziel(_:)`` steht vor dem `switch` in
    /// `Seitenwahl` und darf dort keine lebende Seite verschieben.
    func testKeinLebenderWegWirdVerschoben() {
        for weg in Bereiche.alleWege {
            XCTAssertEqual(Bereiche.ziel(weg), weg, "\(weg) wird von der Weiterleitung verschoben")
        }
    }

    /// ``Bereiche/weiterleitung(_:)`` sagt nur dann etwas, wenn wirklich weitergeleitet wird -
    /// sonst bleibt der Weg, wie er ist, samt Fragezeichenteil. Den braucht
    /// `/waerme/wiedergabe`, um zu wissen, bei welcher Stunde sie anfangen soll.
    func testDieWeiterleitungSchweigtWoNichtsWeiterzuleitenIst() {
        XCTAssertNil(Bereiche.weiterleitung("/waerme"))
        XCTAssertNil(Bereiche.weiterleitung("/waerme/wiedergabe?tag=2026-11-10&stunde=7"))
        XCTAssertNil(Bereiche.weiterleitung("/irgendwas"))
        XCTAssertNil(Bereiche.weiterleitung("/"))
        XCTAssertEqual(Bereiche.weiterleitung("/waerme/bilanz"), "/waerme")
        XCTAssertEqual(Bereiche.weiterleitung("/waermebilanz"), "/waerme")
        XCTAssertEqual(Bereiche.weiterleitung("/settings?period=day"), "/system/zugang")
        for weg in Bereiche.alleWege {
            XCTAssertNil(Bereiche.weiterleitung(weg), "\(weg) lebt und wird trotzdem weitergeleitet")
        }
    }

    /// Der einzige Verweis im Kern, der die Bilanzadresse noch benutzt
    /// (`Annahmenfelder.schlussabsatz`, Vorlage `waerme/annahmen/page.tsx:22-26`), bleibt
    /// richtig: er löst auf die Wärmeübersicht auf, und dort steht die Zeile „nicht zuzuordnen“.
    func testDerAnnahmenverweisLandetAufEinerSeite() {
        var wege: [String] = []
        for stueck in Annahmenfelder.schlussabsatz {
            if case .verweis(_, let weg) = stueck { wege.append(weg) }
        }
        XCTAssertEqual(wege, ["/waerme/bilanz"])
        XCTAssertTrue(Bereiche.alleWege.contains(Bereiche.ziel("/waerme/bilanz")))
    }
}
