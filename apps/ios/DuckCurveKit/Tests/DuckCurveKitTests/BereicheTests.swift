import XCTest

@testable import DuckCurveKit

/// Dieselben Faelle wie `apps/web/src/lib/areas.test.ts`.
///
/// Die Seitenstruktur ist der einzige Teil der Oberflaeche, der sich ohne SwiftUI pruefen laesst,
/// und zugleich der, bei dem ein Fehler am teuersten ist: ein Reiter, der zum falschen Bereich
/// gehoert, verschiebt die ganze Leiste.
final class BereicheTests: XCTestCase {
    func testFuenfBereicheInDerLeisteUndDasSystemDahinter() {
        XCTAssertEqual(Bereiche.leiste.map(\.name), ["Jetzt", "Haus", "Energie", "Geld", "Anlage"])
        XCTAssertEqual(Bereiche.alle.filter { !$0.inLeiste }.map(\.name), ["Einstellen"])
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
        XCTAssertEqual(Bereiche.bereichVon("/anlage").schluessel, .anlage)
        XCTAssertEqual(Bereiche.bereichVon("/waerme/anlage").schluessel, .anlage)
        XCTAssertEqual(Bereiche.bereichVon("/waerme/wiedergabe").schluessel, .anlage)
        XCTAssertEqual(Bereiche.bereichVon("/waerme/nachbetrachtung").schluessel, .anlage)
        // Die Raeume ueber den Tag gehoeren zum Haus, die Prognose zur Energie, der Rest von
        // `/system` zur Verwaltung: drei Bereiche unter zwei alten Pfadanfaengen.
        XCTAssertEqual(Bereiche.bereichVon("/waerme/raeume").schluessel, .haus)
        XCTAssertEqual(Bereiche.bereichVon("/system").schluessel, .energie)
        XCTAssertEqual(Bereiche.bereichVon("/system/zugang").schluessel, .system)
        XCTAssertEqual(Bereiche.bereichVon("/system/daten").schluessel, .system)
    }

    func testFindetDenReiterAmLaengstenPassendenWeg() {
        let energie = Bereiche.bereichVon("/strom/pv")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/strom/pv")?.name, "Photovoltaik")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/strom")?.name, "Strom")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/strom/")?.name, "Strom")
        XCTAssertEqual(Bereiche.reiterVon(energie, "/waerme")?.name, "Wärme")
    }

    func testImHausStehenDieRaeumeUndIhrVerlaufUeberDenTag() {
        XCTAssertEqual(Bereiche.bereichVon("/haus").schluessel, .haus)
        XCTAssertEqual(Bereiche.bereichVon("/haus").reiter.map(\.name), ["Räume", "Über den Tag"])
    }

    func testEinGastSiehtDieAnlageOhneRegelkreisUndAnnahmenUndDieSystemseitenNicht() {
        // Seit es „Einstellen“ gibt, ist kein ganzer Bereich dem Hausherrn vorbehalten: die
        // Sammelseite sehen alle, die stellen dürfen, die Seiten des Systems nur der Hausherr.
        XCTAssertEqual(Bereiche.alle.filter(\.nurHausherr).map(\.schluessel), [])
        let anlage = Bereiche.alle.first { $0.schluessel == .anlage }!
        XCTAssertEqual(
            anlage.reiter.filter { !$0.nurHausherr }.map(\.name),
            ["Anlage", "Wärmepumpe", "Fahrplan", "Wirkung", "Regler"]
        )
        let system = Bereiche.alle.first { $0.schluessel == .system }!
        XCTAssertTrue(system.reiter.allSatisfy(\.nurHausherr))
        // Was unter `/system` liegt, sieht nur der Hausherr, gleich in welchem Bereich es steht.
        let unterSystem = Bereiche.alle.flatMap(\.reiter).filter { $0.weg.hasPrefix("/system") }
        XCTAssertTrue(unterSystem.allSatisfy(\.nurHausherr))
    }

    func testJederReiterDerAnlageGehoertZuGenauEinerIhrerGruppen() {
        let anlage = Bereiche.alle.first { $0.schluessel == .anlage }!
        let namen = anlage.gruppen.map(\.name)
        XCTAssertEqual(namen, ["Maschine", "Regelung", "Abstimmung"])
        for r in anlage.reiter { XCTAssertTrue(namen.contains(r.gruppe ?? ""), "\(r.name) hat keine Gruppe") }
        XCTAssertEqual(anlage.reiter(derGruppe: "Maschine").map(\.name), ["Anlage", "Wärmepumpe"])
        XCTAssertEqual(anlage.reiter(derGruppe: "Regelung").map(\.name), ["Fahrplan", "Wirkung", "Regelkreis"])
        XCTAssertEqual(anlage.reiter(derGruppe: "Abstimmung").map(\.name), ["Annahmen", "Regler"])
        // Die Karte auf der Uebersicht braucht je Seite einen Satz.
        for r in anlage.reiter { XCTAssertTrue(r.beschreibung?.hasSuffix(".") ?? false, "\(r.name) hat keinen Satz") }
        // Gruppen gibt es nur dort, wo sie etwas ordnen.
        for b in Bereiche.alle where b.schluessel != .anlage {
            XCTAssertTrue(b.gruppen.isEmpty)
            for r in b.reiter { XCTAssertNil(r.gruppe) }
        }
    }

    func testVerweistNirgendsAufEineAlteAdresseUndNenntKeineZweimal() {
        let alt = ["/pv", "/batterie", "/wallbox", "/jahr", "/waermebilanz", "/raeume", "/prognose", "/daten", "/settings"]
        var alle: [String] = []
        for b in Bereiche.alle { alle.append(contentsOf: b.reiter.map(\.weg)) }
        for weg in alle { XCTAssertFalse(alt.contains(weg), "\(weg) ist eine alte Adresse") }
        XCTAssertEqual(Set(alle).count, alle.count, "eine Adresse steht zweimal in der Leiste")
    }

    func testZaehltDieAnsichtenEinesReitersZuIhm() {
        let anlage = Bereiche.bereichVon("/waerme/anlage")
        XCTAssertEqual(Bereiche.reiterVon(anlage, "/waerme/wiedergabe")?.name, "Anlage")
        XCTAssertEqual(Bereiche.reiterVon(anlage, "/waerme/anlage")?.name, "Anlage")
        XCTAssertEqual(Bereiche.reiterVon(anlage, "/waerme/nachbetrachtung")?.name, "Fahrplan")
        XCTAssertEqual(
            Bereiche.reiterVon(Bereiche.bereichVon("/waerme/raeume"), "/waerme/raeume")?.name, "Über den Tag")
        // Auf der Uebersicht ist kein Reiter aktiv.
        XCTAssertNil(Bereiche.reiterVon(anlage, "/anlage"))
        XCTAssertEqual(
            Bereiche.ansichtVon(Bereiche.reiterVon(anlage, "/waerme/wiedergabe"), "/waerme/wiedergabe")?.name,
            "Ein Tag"
        )
        XCTAssertEqual(
            Bereiche.ansichtVon(Bereiche.reiterVon(anlage, "/waerme/fahrplan"), "/waerme/fahrplan")?.name,
            "Voraus"
        )
        XCTAssertNil(Bereiche.ansichtVon(Bereiche.reiterVon(anlage, "/waerme/wirkung"), "/waerme/wirkung"))
    }

    func testEnergieAnlageUndSystemOeffnenAufIhrerUebersicht() {
        XCTAssertEqual(
            Bereiche.alle.filter(\.hatUebersicht).map(\.weg), ["/energie", "/anlage", "/einstellen"])
        // `/system` selbst bleibt die Prognose im Bereich Energie. Die Übersicht des Systems ist
        // seit dem 24.11.2026 „Einstellen“; die alte Adresse leitet dorthin weiter.
        XCTAssertEqual(Bereiche.bereichVon("/system").schluessel, .energie)
        XCTAssertEqual(Bereiche.bereichVon("/einstellen").schluessel, .system)
        XCTAssertEqual(Bereiche.bereichVon("/system/zugang").schluessel, .system)
        XCTAssertTrue(Bereiche.istUebersicht("/einstellen"))
        XCTAssertNil(Bereiche.reiterVon(Bereiche.bereichVon("/einstellen"), "/einstellen"))
        XCTAssertEqual(Bereiche.weiterleitung("/system/uebersicht"), "/einstellen")
        // Die Startseite hat keine Reiter und damit auch keine Uebersicht.
        XCTAssertFalse(Bereiche.alle.first { $0.schluessel == .jetzt }!.hatUebersicht)
        // Die Karte auf der Uebersicht braucht je Seite einen Satz.
        for b in Bereiche.alle where b.hatUebersicht {
            for r in b.reiter { XCTAssertTrue(r.beschreibung?.hasSuffix(".") ?? false, "\(r.name) hat keinen Satz") }
        }
        // Die Uebersicht gehoert zu ihrem Bereich, und auf ihr ist kein Reiter aktiv.
        let energie = Bereiche.bereichVon("/energie")
        XCTAssertEqual(energie.schluessel, .energie)
        XCTAssertNil(Bereiche.reiterVon(energie, "/energie"))
        XCTAssertTrue(Bereiche.istUebersicht("/energie"))
        XCTAssertFalse(Bereiche.istUebersicht("/strom"))
        XCTAssertEqual(Bereiche.bereichVon("/strom/pv").schluessel, .energie)
    }

    func testJedeErsteAnsichtHatDieAdresseIhresReiters() {
        for b in Bereiche.alle {
            // Ein Bereich geht entweder auf seinem ersten Reiter auf oder auf einer Uebersicht
            // unter eigener Adresse. Gruppen gibt es nur mit Uebersicht.
            if let ersterReiter = b.reiter.first, !b.hatUebersicht {
                XCTAssertEqual(ersterReiter.weg, b.weg, "Bereich \(b.name) zeigt nicht auf seinen ersten Reiter")
            }
            if !b.gruppen.isEmpty {
                XCTAssertTrue(b.hatUebersicht, "\(b.name) hat Gruppen, aber keine Uebersicht")
            }
            for r in b.reiter where !r.unter.isEmpty {
                XCTAssertEqual(r.unter.first?.weg, r.weg, "Reiter \(r.name) zeigt nicht auf seine erste Ansicht")
            }
        }
    }

    /// Der Regler liegt unter dem Pfad der Wärmepumpe und ist trotzdem ein eigener Reiter in der
    /// Abstimmung: es gilt die laengste passende Adresse. Die drei Ansichten der Wärmepumpe
    /// bleiben bei ihr.
    func testDerReglerIstEinEigenerReiterUnterDemPfadDerWaermepumpe() {
        let anlage = Bereiche.bereichVon("/waerme/waermepumpe")
        let wp = Bereiche.reiterVon(anlage, "/waerme/waermepumpe")
        XCTAssertEqual(wp?.unter.map(\.name), ["Jetzt", "Betrieb", "Kennlinie"])
        for u in wp?.unter ?? [] {
            XCTAssertEqual(Bereiche.reiterVon(anlage, u.weg)?.name, "Wärmepumpe", "\(u.weg) faellt aus dem Reiter")
        }
        let regler = Bereiche.reiterVon(anlage, "/waerme/waermepumpe/regler")
        XCTAssertEqual(regler?.name, "Regler")
        XCTAssertEqual(regler?.gruppe, "Abstimmung")
        XCTAssertEqual(Bereiche.kicker(fuer: "/waerme/waermepumpe/regler"), "Einstellungen · gelesen")
    }

    /// Jeder Weg, den die App kennt, muss sich einem Bereich zuordnen lassen. Sonst landet eine
    /// Mitteilung mit diesem Ziel auf der Startseite statt auf der gemeinten Seite.
    func testJederWegFindetSeinenBereich() {
        // Die Seiten außerhalb der Bereiche gehören mit Absicht zu keinem; sie finden sich über
        // `einzelseite` (`SeitenbaumTests`).
        for weg in Bereiche.alleWege where weg != "/" && Bereiche.einzelseite(weg) == nil {
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
        // „Einstellen“ sieht jeder, der im Haus stellen darf; die Seiten des Systems bleiben dem
        // Hausherrn. Die Übersichten der Energie und der Anlage sieht jeder.
        XCTAssertFalse(Bereiche.nurHausherr("/einstellen"))
        XCTAssertFalse(Bereiche.nurHausherr("/energie"))
        XCTAssertFalse(Bereiche.nurHausherr("/anlage"))
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

/// Der Kicker je Seite: die zwei bis vier Stichworte unter dem Titel.
///
/// **Warum das geprüft wird und nicht bloß hingeschrieben.** Die Stichworte sind eine Abschrift
/// aus achtundzwanzig Vorlagen, verteilt über `page.tsx` und die Berichtsbausteine - und jede
/// Abschrift läuft auseinander, wenn niemand nachrechnet. Vorher stand sie in der Seite selbst,
/// und genau dort hat niemand gemerkt, dass dasselbe Wort auch im Wortschatz des Kerns steht.
final class KickerTests: XCTestCase {
    /// Jede Route und das Wort, das die Vorlage ihrer Hülle gibt. Die Stelle steht am Eintrag
    /// in ``Bereiche/alle``.
    private let erwartet: [String: String] = [
        "/strom": "Verbrauch · Verbraucher · Herkunft",
        "/waerme": "gerechnet, nicht gemessen",
        "/strom/pv": "Erzeugung · Verwendung · Prognose",
        "/strom/wallbox": "Ladungen · Herkunft · Kosten",
        "/strom/jahr": "365 Tage × 24 Stunden",
        "/geld": "Was der Zeitraum gekostet hat, in einer Zeile",
        "/geld/pv-abrechnung": "Einspeisung · Eigenverbrauch · Umsatzsteuer",
        "/geld/rechnungen": "Tibber · nachgerechnet und gegen die eigene Messung gehalten",
        // Die Uebersicht des Bereichs: kein Reiter, aber eine Zeile (`Bereichsuebersicht.tsx`).
        "/anlage": "Alle Seiten im Bereich Anlage",
        "/energie": "Alle Seiten im Bereich Energie",
        "/einstellen": "was von Hand gestellt ist · eingreifen · vorgeben · abstimmen",
        "/waerme/anlage": "Strom · Speicher · vier Kreise",
        "/waerme/wiedergabe": "Ein Tag am Anlagenschema · zum Durchfahren",
        "/waerme/waermepumpe": "Außengerät · Innengerät · Speicher",
        "/waerme/waermepumpe/betrieb": "Läufe · Abtauen · Heizkurve",
        "/waerme/waermepumpe/kennlinie": "Arbeitszahl · gemessen",
        "/waerme/waermepumpe/regler": "Einstellungen · gelesen",
        "/waerme/fahrplan": "Preis · PV · Wärmebedarf · Puffer · zwei Tage",
        "/waerme/nachbetrachtung": "Versprochen, gehalten, wirklich · ein Tag in Euro",
        "/waerme/wirkung": "Folgt die Wärmepumpe der Anforderung? · gemessen, nicht angenommen",
        // **Die eine Route, deren Wort bewusst von der Vorlage abweicht.** Dort steht
        // „Blockschaltbild der Kaskade · Herkunft jeder Zahl" (`waerme/regelkreis/page.tsx:13`),
        // und das ist im Browser richtig: da liegt eine Zeichnung von 1400 Punkten Breite, in
        // der man Kästchen anklickt. Am Telefon bliebe davon ein Ausschnitt, durch den man
        // schiebt - die App zeigt die Kaskade deshalb als Liste nach Ebenen. Ein Kicker, der
        // ein Blockschaltbild verspricht, verspräche hier ein Bild, das nicht da ist. Das Wort
        // steht im Kern (``Regelkreisbild/seitenkicker``), damit Reiter und Seite dasselbe
        // lesen.
        "/waerme/regelkreis": "Kaskade in fünf Ebenen · Herkunft jeder Zahl",
        "/waerme/raeume": "Einzelraumregelung · Abweichung vom Ziel über den Tag",
        "/system": "PV-Prognose gegen Ist · Korrekturfaktoren",
        "/system/daten": "Messreihen · Stundenbilanz · Rohdaten",
        "/waerme/annahmen": "Lieferschein · Datenblatt · Puffer",
        "/system/mitteilungen": "Was aufs Handy kommt: Störungen und das Morning Briefing",
        "/system/haustuer": "Wer sich am Reader erkennen ließ, und was geschah",
        "/system/geraet": "Dienste, Gesundheit, Sicherung und Updates des Rechners im Haus",
        "/system/zugang": "wer Zugang hat · wer zusieht · Daten sichern",
        // Außerhalb der Bereiche: der eigene Zugang (`konto/page.tsx`).
        "/konto": "Passkeys · Passwort · Sitzungen",
    ]

    /// Die drei Routen, die keinen bekommen - jede mit einem Grund in der Vorlage.
    ///
    /// `/` hat einen eigenen Kopf statt der Hülle (`home/Home.tsx:203`); `/haus` und
    /// `/strom/speicher` rechnen ihre Zeile aus der Antwort des Dienstes
    /// (`house/HouseReport.tsx:219`, `reports/BatteryReport.tsx:103`) und können darum nicht im
    /// Gerippe stehen.
    private let ohneKicker: Set<String> = ["/", "/haus", "/strom/speicher"]

    func testJedeSeiteTraegtDasWortIhrerVorlage() {
        for (weg, wort) in erwartet {
            XCTAssertEqual(Bereiche.kicker(fuer: weg), wort, weg)
        }
        for weg in ohneKicker {
            XCTAssertNil(Bereiche.kicker(fuer: weg), "\(weg) bekommt einen Kicker, den die Vorlage nicht hat")
        }
    }

    /// **Jede Route muss hier eine Entscheidung haben.** Eine neue Seite, die niemand einträgt,
    /// fällt sonst still durch: im Gerippe stünde nichts, und ob das Absicht war, wüsste
    /// niemand.
    func testKeineRouteBleibtUnentschieden() {
        for weg in Bereiche.alleWege {
            XCTAssertTrue(
                erwartet[weg] != nil || ohneKicker.contains(weg),
                "\(weg) steht in der Leiste, aber in keiner der beiden Listen dieses Tests")
        }
        XCTAssertEqual(Set(erwartet.keys).union(ohneKicker), Set(Bereiche.alleWege))
    }

    /// **Eine Route, ein Wort.** Weil die erste Ansicht die Adresse ihres Reiters hat, könnten
    /// für `/waerme/anlage` zwei Felder gefüllt sein - und beim nächsten Umbau mit zwei
    /// verschiedenen Worten. Dann hinge es an der Reihenfolge der Suche, welches man sieht.
    func testKeineRouteBekommtZweiVerschiedene() {
        var gesehen: [String: Set<String>] = [:]
        for b in Bereiche.alle {
            for r in b.reiter {
                if let k = r.kicker { gesehen[r.weg, default: []].insert(k) }
                for u in r.unter {
                    if let k = u.kicker { gesehen[u.weg, default: []].insert(k) }
                }
            }
        }
        for (weg, worte) in gesehen {
            XCTAssertEqual(worte.count, 1, "\(weg) hat \(worte.count) Kicker: \(worte.sorted())")
        }
    }

    /// Wo es Ansichten gibt, tragen sie den Kicker und der Reiter keinen: vier Sichten der
    /// Wärmepumpe sind vier Seiten der Vorlage mit vier eigenen `page.tsx`.
    func testWoAnsichtenStehenTraegtDerReiterKeinen() {
        for b in Bereiche.alle {
            for r in b.reiter where !r.unter.isEmpty {
                XCTAssertNil(r.kicker, "Reiter \(r.name) trägt einen Kicker neben seinen Ansichten")
                for u in r.unter {
                    XCTAssertNotNil(u.kicker, "Ansicht \(u.name) von \(r.name) hat keinen")
                }
            }
        }
    }

    /// Der Fragezeichenteil gehört nicht zum Weg - sonst hätte dieselbe Seite mit Zeitraum in
    /// der Adresse keinen Kicker (`Bereiche.saeubere(_:)`).
    func testDerFragezeichenteilAendertNichts() {
        XCTAssertEqual(
            Bereiche.kicker(fuer: "/strom?period=week&anchor=2026-11-18"),
            Stromuebersicht.seitenkicker)
        XCTAssertEqual(
            Bereiche.kicker(fuer: "/waerme/wiedergabe?tag=2026-11-10&stunde=7"),
            Wiedergabeworte.seitenkicker)
        XCTAssertEqual(Bereiche.kicker(fuer: "/strom/jahr/"), Jahresraster.kicker)
    }

    /// Ein Weg, den die App nicht kennt, bekommt keinen - `Unbekannt` zeigt einen Satz und
    /// keine Stichworte.
    func testEinUnbekannterWegBekommtKeinen() {
        XCTAssertNil(Bereiche.kicker(fuer: "/irgendwas"))
    }
}
