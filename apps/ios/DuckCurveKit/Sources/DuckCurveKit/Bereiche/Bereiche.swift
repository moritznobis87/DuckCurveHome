import Foundation

/// Die Seitenstruktur: fuenf Bereiche nach Frage, dazu was nur der Hausherr sieht.
///
/// Wortgleich uebernommen aus `apps/web/src/lib/areas.ts`, samt der Begruendung von dort:
///
/// **Warum nach Frage und nicht nach Geraet.** Dreizehn Seiten waren nacheinander entstanden, je
/// eine je Geraet, und jede mit eigener Zeitraumwahl. Wer die Woche in der Photovoltaik ansah und
/// dann zum Speicher ging, stand dort wieder auf heute. Jetzt teilen sich die Reiter eines
/// Bereichs den Zeitraum: er reist als Zeitraum und Anker von Reiter zu Reiter mit.
///
/// **Alltag vorn, Technik hinten.** Vier Bereiche fuer den Alltag, einer fuer den, der die Anlage
/// betreibt. Ein Bereich ist deshalb nicht das erste Stueck des Pfads: `/waerme` gehoert zur
/// Energie, `/waerme/anlage` zur Technik.
///
/// **Warum die Adressen in einer App ueberhaupt bleiben.** Eine App braucht keine URLs. Diese
/// behaelt sie trotzdem, aus drei Gruenden: die Lesezeichen am iPad an der Wand sollen weiter
/// gelten, Mitteilungen tragen ein Ziel in genau dieser Schreibweise (siehe `push/lage.ts`), und
/// solange das Dashboard daneben laeuft, soll „wo bin ich“ in beiden dasselbe heissen. Die App
/// nimmt sie als Wegmarke, nicht als Adresse: `Weg` ist der Schluessel, nach dem die Navigation
/// ihre Ansicht waehlt.
public struct Bereich: Sendable, Hashable, Identifiable {
    public enum Schluessel: String, Sendable, Hashable, CaseIterable {
        case jetzt, haus, energie, geld, technik
    }

    public var schluessel: Schluessel
    public var weg: String
    public var zeichen: Bereichszeichen
    public var name: String
    public var reiter: [Reiter]

    public var id: Schluessel { schluessel }

    public init(schluessel: Schluessel, weg: String, zeichen: Bereichszeichen, name: String, reiter: [Reiter] = []) {
        self.schluessel = schluessel
        self.weg = weg
        self.zeichen = zeichen
        self.name = name
        self.reiter = reiter
    }
}

/// Ein Reiter innerhalb eines Bereichs.
public struct Reiter: Sendable, Hashable, Identifiable {
    public var weg: String
    public var name: String
    /// Der Reiter kennt einen Zeitraum und bekommt ihn beim Wechsel mit.
    public var mitZeitraum: Bool
    /// Welche Spannen dieser Reiter anbietet.
    ///
    /// **Warum das hier steht und nicht in der Seite.** Die Zeitraumwahl steht am Telefon im
    /// Gerippe, ueber den Reitern - dort, wo die Vorlage sie hat (`handy.css:151`). Das Gerippe
    /// kennt die Seite nicht, nur den Weg; stuende die Auswahl in der Seite, muesste sie von
    /// unten nach oben gereicht werden. Hier steht sie einmal, und die Seite liest sie von
    /// derselben Stelle.
    public var spannen: [Spanne]
    /// Nur mit Vollzugriff sichtbar.
    public var nurHausherr: Bool
    /// Die Ansichten eines Reiters, wenn er mehr als eine hat: dieselbe Sache aus zwei
    /// Richtungen, etwa der Augenblick und ein ganzer Tag. Sie stehen als Umschalter unter der
    /// Reiterzeile, nicht als eigene Reiter daneben. Die erste Ansicht hat die Adresse des Reiters.
    public var unter: [Ansicht]
    /// Die zwei bis vier Stichworte unter dem Titel, die sagen, was auf der Seite steht.
    ///
    /// **Warum das hier steht und nicht in der Seite.** Die Vorlage gibt den Kicker der Huelle
    /// (`AreaShell.tsx:14,26`), und die Huelle zeichnet ihn in der Reiterzeile
    /// (`AreaNav.tsx:96`) - eine Stelle fuer alle Seiten. In der App schrieb ihn jede Seite
    /// selbst in ihre erste Karte; damit stand dasselbe Wort in der Seite und in ihrem
    /// Wortschatz, und zwei Umbauten haben nach dieser Stelle gefragt. Das Gerippe kennt die
    /// Seite nicht, nur den Weg - also liest es ihn vom Weg (``Bereiche/kicker(fuer:)``).
    ///
    /// **Wo ein Wortschatz des Kerns ihn schon traegt, zeigt dieses Feld dorthin**, statt die
    /// Zeichenkette ein zweites Mal hinzuschreiben: `Stromuebersicht.seitenkicker` und die
    /// anderen sind beim Umbau ihrer Seite entstanden und von ihren eigenen Tests gehalten.
    ///
    /// `nil` heisst: die Vorlage hat dort keinen. Das gilt fuer die Startseite, die ihren
    /// eigenen Kopf hat (`home/Home.tsx:203`), und fuer die zwei Seiten, die ihn aus der
    /// Antwort des Dienstes rechnen (`house/HouseReport.tsx:219`,
    /// `reports/BatteryReport.tsx:103`) - ein gerechneter Kicker kennt die Antwort und kann
    /// nicht in einer Tabelle stehen. Erfunden wird keiner.
    public var kicker: String?

    public var id: String { weg }

    public init(weg: String, name: String, mitZeitraum: Bool = false, spannen: [Spanne] = Spanne.allCases, nurHausherr: Bool = false, unter: [Ansicht] = [], kicker: String? = nil) {
        self.weg = weg
        self.name = name
        self.mitZeitraum = mitZeitraum
        self.spannen = spannen
        self.nurHausherr = nurHausherr
        self.unter = unter
        self.kicker = kicker
    }
}

/// Eine Ansicht unterhalb eines Reiters.
public struct Ansicht: Sendable, Hashable, Identifiable {
    public var weg: String
    public var name: String
    /// Der Kicker dieser Ansicht - sie hat ihren eigenen, denn in der Vorlage ist sie eine
    /// eigene Seite mit eigener `page.tsx` (`waerme/wiedergabe/page.tsx:10` gegen
    /// `waerme/anlage/page.tsx:9`).
    ///
    /// **Darum bleibt der Kicker des Reiters leer, wo es Ansichten gibt.** Die erste Ansicht
    /// hat die Adresse ihres Reiters; truege der Reiter auch einen, stuende fuer diese eine
    /// Route zweimal etwas da, und beim naechsten Umbau zweimal etwas anderes.
    public var kicker: String?
    public var id: String { weg }

    public init(weg: String, name: String, kicker: String? = nil) {
        self.weg = weg
        self.name = name
        self.kicker = kicker
    }
}

/// Das Zeichen eines Bereichs in der Leiste. Als Aufzaehlung, damit die Oberflaeche sie auf eine
/// Zeichnung abbilden kann, ohne dass der Kern SwiftUI kennt.
///
/// Heisst nicht `Zeichen`: so heisst in der App die Ansicht, die eine Zeichnung zeichnet, und
/// zwei Typen dieses Namens in einem Modulraum sind nicht mehr eindeutig zu nennen.
public enum Bereichszeichen: String, Sendable, Hashable {
    case ente, haus, blitz, euro, zahnrad
}

public enum Bereiche {
    /// Alle Bereiche in der Reihenfolge der Leiste.
    public static let alle: [Bereich] = [
        // **Die beiden Bereiche ohne Reiter tragen auch keinen Kicker**, und das ist die Vorlage
        // und nicht eine Lücke: die Startseite hat ihren eigenen Kopf statt der Hülle
        // (`home/Home.tsx:203`), und das Haus rechnet seine Zeile aus dem Plan
        // (`house/HouseReport.tsx:219`: „Hausplan · …“). Ein Kicker hängt darum am Reiter und an
        // der Ansicht, nicht am Bereich.
        Bereich(schluessel: .jetzt, weg: "/", zeichen: .ente, name: "Jetzt"),
        // Das Haus: die Raeume als Liste und als Modell, ein Schalter in der Seite und kein Reiter.
        Bereich(schluessel: .haus, weg: "/haus", zeichen: .haus, name: "Haus"),
        Bereich(
            schluessel: .energie, weg: "/strom", zeichen: .blitz, name: "Energie",
            reiter: [
                Reiter(weg: "/strom", name: "Strom", mitZeitraum: true,
                    kicker: Stromuebersicht.seitenkicker),  // `HouseReport.tsx:42`
                Reiter(weg: "/waerme", name: "Wärme", mitZeitraum: true,
                    kicker: "gerechnet, nicht gemessen"),  // `HeatOverview.tsx:137`
                Reiter(weg: "/strom/pv", name: "Photovoltaik", mitZeitraum: true,
                    kicker: "Erzeugung · Verwendung · Prognose"),  // `PvReport.tsx:77`
                // **Ohne Kicker, und nicht aus Versehen.** Die Vorlage rechnet ihn hier aus der
                // Kapazität („13,8 kWh · Nutzung und Ersparnis“, `BatteryReport.tsx:103`), und
                // die kennt erst die Antwort des Dienstes. Die Seite zeichnet ihn darum weiter
                // selbst (``Speicherbild/seitenkicker(_:)``).
                Reiter(weg: "/strom/speicher", name: "Speicher", mitZeitraum: true),
                Reiter(weg: "/strom/wallbox", name: "Wallbox", mitZeitraum: true,
                    kicker: "Ladungen · Herkunft · Kosten"),  // `EvReport.tsx:36`
                Reiter(weg: "/strom/jahr", name: "Jahreskarte",
                    kicker: Jahresraster.kicker),  // `YearMap.tsx:94`
            ]
        ),
        Bereich(
            schluessel: .geld, weg: "/geld", zeichen: .euro, name: "Geld",
            reiter: [
                Reiter(weg: "/geld", name: "Kosten", mitZeitraum: true,
                    kicker: Gelduebersicht.seitenkicker),  // `CostReport.tsx:107`
                Reiter(
                    weg: "/geld/pv-abrechnung", name: "PV-Abrechnung", mitZeitraum: true,
                    spannen: [.monat, .jahr], nurHausherr: true,
                    kicker: "Einspeisung · Eigenverbrauch · Umsatzsteuer"),  // `PvAccounting.tsx:82`
                Reiter(weg: "/geld/rechnungen", name: "Rechnungen", nurHausherr: true,
                    kicker: Rechnungspruefung.seitenkicker),  // `InvoiceCheck.tsx:205`
            ]
        ),
        Bereich(
            schluessel: .technik, weg: "/waerme/anlage", zeichen: .zahnrad, name: "Technik",
            // Erst die Anlage und ihr Fahrplan, dann die Auswertungen, dann das Einstellen.
            reiter: [
                Reiter(
                    weg: "/waerme/anlage", name: "Anlage",
                    unter: [
                        // `waerme/anlage/page.tsx:9` und `waerme/wiedergabe/page.tsx:10`: zwei
                        // Seiten, zwei Kicker - der des Reiters bleibt deshalb leer.
                        Ansicht(weg: "/waerme/anlage", name: "Jetzt",
                            kicker: Anlagenworte.bereichskicker),
                        Ansicht(weg: "/waerme/wiedergabe", name: "Ein Tag",
                            kicker: Wiedergabeworte.seitenkicker),
                    ]
                ),
                Reiter(
                    weg: "/waerme/waermepumpe", name: "Wärmepumpe",
                    unter: [
                        Ansicht(weg: "/waerme/waermepumpe", name: "Jetzt",
                            kicker: "Außengerät · Innengerät · Speicher"),  // `waermepumpe/page.tsx:9`
                        Ansicht(weg: "/waerme/waermepumpe/betrieb", name: "Betrieb",
                            kicker: "Läufe · Abtauen · Heizkurve"),  // `waermepumpe/betrieb/page.tsx:9`
                        Ansicht(weg: "/waerme/waermepumpe/kennlinie", name: "Kennlinie",
                            kicker: "Arbeitszahl · gemessen"),  // `waermepumpe/kennlinie/page.tsx:9`
                        Ansicht(weg: "/waerme/waermepumpe/regler", name: "Regler",
                            kicker: "Einstellungen · gelesen"),  // `waermepumpe/regler/page.tsx:9`
                    ]
                ),
                Reiter(
                    weg: "/waerme/fahrplan", name: "Fahrplan",
                    unter: [
                        Ansicht(weg: "/waerme/fahrplan", name: "Voraus",
                            kicker: "Preis · PV · Wärmebedarf · Puffer · zwei Tage"),  // `fahrplan/page.tsx:9`
                        Ansicht(weg: "/waerme/nachbetrachtung", name: "Rückblick",
                            kicker: "Versprochen, gehalten, wirklich · ein Tag in Euro"),  // `nachbetrachtung/page.tsx:10`
                    ]
                ),
                Reiter(weg: "/waerme/wirkung", name: "Wirkung",
                    kicker: "Folgt die Wärmepumpe der Anforderung? · gemessen, nicht angenommen"),  // `wirkung/page.tsx:9`
                Reiter(weg: "/waerme/regelkreis", name: "Regelkreis", nurHausherr: true,
                    kicker: Regelkreisbild.seitenkicker),  // `waerme/regelkreis/page.tsx:12`
                Reiter(weg: "/waerme/raeume", name: "Heizkreise", mitZeitraum: true, spannen: [.tag],
                    kicker: "Einzelraumregelung · Abweichung vom Ziel über den Tag"),  // `RoomsReport.tsx:600`
                Reiter(weg: "/system", name: "Prognose", nurHausherr: true,
                    kicker: "PV-Prognose gegen Ist · Korrekturfaktoren"),  // `ForecastPage.tsx:245`
                Reiter(
                    // **Nur Tage.** Die Vorlage schaltet die Spannenwahl auf dieser Seite
                    // ausdrücklich ab (`DataCheck.tsx:59-68`, `showPeriods={false}`), weil die
                    // Prüfansicht Minutenwerte zeigt: über eine Woche gelegt ergeben sie ein
                    // Bild, in dem nichts zu erkennen ist. Hier standen Tag, Woche und Monat -
                    // und die Seite selbst bot nur Tage an. Reiter und Seite widersprachen
                    // sich also, und der Reiter gewann: wer Woche wählte, bekam ein Diagramm
                    // aus einem Tag mit der Überschrift einer Woche.
                    weg: "/system/daten", name: "Daten prüfen", mitZeitraum: true,
                    spannen: [.tag], nurHausherr: true,
                    kicker: "Messreihen · Stundenbilanz · Rohdaten"),  // `DataCheck.tsx:61`
                Reiter(weg: "/waerme/annahmen", name: "Annahmen", nurHausherr: true,
                    kicker: Annahmenfelder.kicker),  // `waerme/annahmen/page.tsx:13`
                Reiter(weg: "/system/mitteilungen", name: "Mitteilungen", nurHausherr: true,
                    kicker: "Was aufs Handy kommt: Störungen und das Morning Briefing"),  // `system/mitteilungen/page.tsx:12`
                Reiter(weg: "/system/haustuer", name: "Haustür", nurHausherr: true,
                    kicker: "Wer sich am Reader erkennen ließ, und was geschah"),  // `system/haustuer/page.tsx:9`
                // Der Rechner im Haus: Dienste, Gesundheit, Neustarts, Protokolle, Updates.
                Reiter(weg: "/system/geraet", name: "Hausgerät", nurHausherr: true,
                    kicker: "Dienste, Gesundheit, Sicherung und Updates des Rechners im Haus"),  // `system/geraet/page.tsx:9`
                Reiter(weg: "/system/zugang", name: "Zugang und Sicherung", nurHausherr: true,
                    kicker: "Geräte koppeln · wer zusieht · Daten sichern"),  // `system/zugang/page.tsx:58`
            ]
        ),
    ]

    /// Welche Spannen die Seite zu einem Weg anbietet - `nil`, wenn sie keinen Zeitraum kennt.
    ///
    /// Die Ansichten eines Reiters erben seine Spannen: „Ein Tag" unter „Anlage" ist dieselbe
    /// Seite in einer anderen Richtung, nicht ein eigener Bereich mit eigener Zeitwahl.
    public static func spannen(fuer weg: String) -> [Spanne]? {
        guard let r = reiterVon(bereichVon(weg), weg), r.mitZeitraum else { return nil }
        return r.spannen
    }

    /// Der Kicker der Seite zu einem Weg - `nil`, wo die Vorlage keinen hinschreibt.
    ///
    /// **Die Ansicht schlägt den Reiter.** Umgekehrt als bei ``spannen(fuer:)``, und aus dem
    /// umgekehrten Grund: eine Spanne gehört dem Reiter, weil „Ein Tag“ unter „Anlage“
    /// derselbe Zeitraum ist; ein Kicker gehört der Ansicht, weil sie in der Vorlage eine
    /// eigene `page.tsx` mit eigenen Stichworten hat. Erbt wird hier also nach unten: wo ein
    /// Reiter keine Ansichten hat, trägt er den Kicker selbst.
    ///
    /// **Warum das Gerippe fragen muss und nicht die Seite antwortet.** Das Gerippe kennt die
    /// Seite nicht, nur den Weg - derselbe Satz steht an ``Reiter/spannen``. Stünde der Kicker
    /// in der Seite, müsste er von unten nach oben gereicht werden; so steht er einmal und wird
    /// von derselben Stelle gelesen.
    public static func kicker(fuer weg: String) -> String? {
        let reiter = reiterVon(bereichVon(weg), weg)
        return ansichtVon(reiter, weg)?.kicker ?? reiter?.kicker
    }

    /// Der Bereich, zu dem ein Weg gehoert: der mit der laengsten passenden Adresse unter seinen
    /// Reitern und Ansichten. `/` ist Jetzt, und was niemandem gehoert, auch.
    public static func bereichVon(_ weg: String) -> Bereich {
        let sauber = saeubere(weg)
        var bester: (bereich: Bereich, laenge: Int)?
        for bereich in alle {
            let adressen = [bereich.weg] + bereich.reiter.flatMap { [$0.weg] + $0.unter.map(\.weg) }
            for adresse in adressen where adresse != "/" {
                guard sauber == adresse || sauber.hasPrefix(adresse + "/") else { continue }
                if bester == nil || adresse.count > bester!.laenge {
                    bester = (bereich, adresse.count)
                }
            }
        }
        return bester?.bereich ?? alle[0]
    }

    /// Der aktive Reiter: der laengste Weg, mit dem der Weg beginnt. Die Ansichten eines Reiters
    /// zaehlen mit - auf `/waerme/wiedergabe` ist der Reiter „Anlage“ aktiv.
    public static func reiterVon(_ bereich: Bereich, _ weg: String) -> Reiter? {
        let sauber = saeubere(weg)
        // Ausgeschrieben statt als Kette: der Compiler braucht fuer die Kette mit Tupeln
        // unverhaeltnismaessig lange und bricht die Typpruefung ab.
        var bester: Reiter?
        var besteLaenge = -1
        for r in bereich.reiter {
            var adressen: [String] = [r.weg]
            for u in r.unter { adressen.append(u.weg) }
            for adresse in adressen {
                guard sauber == adresse || sauber.hasPrefix(adresse + "/") else { continue }
                if adresse.count > besteLaenge {
                    besteLaenge = adresse.count
                    bester = r
                }
            }
        }
        return bester
    }

    /// Die aktive Ansicht eines Reiters, oder `nil`, wenn er nur eine hat.
    public static func ansichtVon(_ reiter: Reiter?, _ weg: String) -> Ansicht? {
        let sauber = saeubere(weg)
        var bester: Ansicht?
        var besteLaenge = -1
        for u in reiter?.unter ?? [] {
            guard sauber == u.weg || sauber.hasPrefix(u.weg + "/") else { continue }
            if u.weg.count > besteLaenge {
                besteLaenge = u.weg.count
                bester = u
            }
        }
        return bester
    }

    /// Alle Wege, die die App kennt - fuer die Pruefung, ob ein Ziel aus einer Mitteilung gueltig ist.
    public static var alleWege: [String] {
        var aus: [String] = []
        for b in alle {
            aus.append(b.weg)
            for r in b.reiter {
                aus.append(r.weg)
                for u in r.unter { aus.append(u.weg) }
            }
        }
        return aus
    }

    /// Die Adressen, die es nicht mehr gibt, und die Seite, auf die sie heute führen.
    ///
    /// **Warum sie neben ``alleWege`` stehen.** Beide Listen antworten auf dieselbe Frage - ist
    /// dieser Weg einer, den die App kennt? -, und sie müssen zusammen stimmen: keine alte
    /// Adresse darf in der Leiste stehen, und jede muss auf einer landen, die dort steht
    /// (`AlteWegeTests`). Als eigene Datei im Zustand lagen sie auseinander, und die drei Zeilen
    /// von ``saeubere(_:)`` standen deshalb zweimal da - einmal hier und einmal dort, weil
    /// ``saeubere(_:)`` privat war. Jetzt ist er öffentlich und es gibt ihn einmal.
    ///
    /// **Warum eine App Weiterleitungen braucht.** Die Vorlage hat zwei davon, und beide mit
    /// derselben Begründung. Die eine Liste steht in `apps/web/next.config.ts:13-31`, wörtlich:
    /// „Die alten Adressen, eine je Geraet, fuehren auf die neuen Bereiche. Lesezeichen und der
    /// Verlauf des Wand-iPads bleiben gueltig; die Abfrage (?period=&anchor=) reist mit.“
    /// Die andere ist eine ganze Seite, die nichts mehr zeichnet
    /// (`apps/web/src/app/waerme/bilanz/page.tsx:3-7`): „Die Bilanz ist in der Wärmeübersicht
    /// aufgegangen (10.11.2026). Die Adresse bleibt als Weiterleitung, damit ein Lesezeichen und
    /// ein Verweis von außen nicht ins Leere führen; der Zeitraum in der Adresse reist mit.“
    /// Dasselbe gilt für die App: ein Ziel aus einer alten Mitteilung, ein Verweis aus dem Kern
    /// (``Annahmenfelder/schlussabsatz`` zeigt auf `/waerme/bilanz`) und das Lesezeichen des
    /// Wand-iPads dürfen nicht auf „Diese Seite kennt die App nicht“ laufen.
    ///
    /// **Warum hier und nicht in der Ansicht.** Welcher Weg wohin auflöst, ist eine Rechnung über
    /// Zeichenketten und nichts sonst - sie gehört in den Kern, wo ein Test sie nachrechnet. Der
    /// andere Weg, eine Umleitungsansicht mit `wegweiser.gehe("/waerme")` im Zeichnen, schreibt
    /// beobachteten Zustand mitten im Bild; genau davor warnt der Kommentar in
    /// `DuckCurveHome/App/Navigation.swift:56-62`.
    ///
    /// **Der Zeitraum reist hier von selbst mit.** Die Vorlage muss ihn durch die Adresse tragen,
    /// weil `usePeriod` ihn aus `window.location.search` liest (`ReportShell.tsx:61-95`). Die App
    /// hält ihn je Bereich (`Navigation.swift:22,69-81`), und `/waerme/bilanz` liegt über
    /// `hasPrefix("/waerme/")` schon im selben Bereich und am selben Reiter wie `/waerme`
    /// (``bereichVon(_:)``). Ein zweiter Träger für dieselbe Angabe wäre eine zweite
    /// Wahrheit - deshalb trägt ``ziel(_:)`` den Fragezeichenteil nicht weiter, sondern wirft ihn
    /// weg wie der Rest dieser Aufzählung es auch tut.
    ///
    /// Alte Adresse links, ihr Nachfolger rechts. Die elf Paare sind die Abschrift von
    /// `apps/web/next.config.ts:18-30`; das zwölfte, `/waerme/bilanz` → `/waerme`, ist die
    /// Weiterleitungsseite `apps/web/src/app/waerme/bilanz/page.tsx:14`
    /// (`redirect(s ? "/waerme?" + s : "/waerme")`).
    ///
    /// **`/haus` fehlt mit Absicht**, und die Vorlage sagt auch warum
    /// (`next.config.ts:15-16`): seit dem 30.10.2026 ist das der Bereich mit dem Hausmodell,
    /// die alte Hausbilanz dahinter wohnt unter `/strom`.
    ///
    /// **Zwei Stufen sind erlaubt.** `/waermebilanz` führt in der Vorlage auf `/waerme/bilanz`
    /// und von dort weiter auf `/waerme`; die Liste schreibt beide Stufen einzeln hin, statt
    /// die zweite in die erste einzurechnen - sonst stünde das Ziel zweimal da und liefe beim
    /// nächsten Umbau auseinander. ``ziel(_:)`` folgt der Kette.
    ///
    /// **Heisst nicht `alteWege`.** Daneben steht ``alleWege``, und zwei Namen, die sich in
    /// einem Buchstaben unterscheiden, sind beim Lesen keine zwei.
    public static let weiterleitungen: [String: String] = [
        "/pv": "/strom/pv",
        "/pv/abrechnung": "/geld/pv-abrechnung",
        "/haus/rechnungen": "/geld/rechnungen",
        "/batterie": "/strom/speicher",
        "/wallbox": "/strom/wallbox",
        "/jahr": "/strom/jahr",
        "/waermebilanz": "/waerme/bilanz",
        "/raeume": "/waerme/raeume",
        "/prognose": "/system",
        "/daten": "/system/daten",
        "/settings": "/system/zugang",
        // Die Bilanz ist in der Wärmeübersicht aufgegangen (10.11.2026). Bis dahin standen
        // „Erzeuger“ und „Bilanz“ nebeneinander und nannten für denselben Tag verschiedene
        // Zahlen - 24,5 kWh Wärme und Arbeitszahl 2,90 auf der einen, 20,4 kWh und 2,41 auf der
        // anderen (`components/reports/HeatOverview.tsx:19-23`). Zwei Wahrheiten für dieselbe
        // Größe sind keine.
        "/waerme/bilanz": "/waerme",
    ]

    /// Der Weg, auf dem die Seite wirklich steht: Fragezeichenteil und Schrägstriche am Ende
    /// weg, dann der Kette alter Adressen folgen, bis keine mehr passt.
    ///
    /// Ein Weg, der in ``weiterleitungen`` nicht vorkommt, kommt unverändert zurück - geputzt.
    /// Die Schleife bricht nach so vielen Schritten ab, wie die Liste Einträge hat: mehr kann
    /// eine Kette ohne Kreis nicht sein, und mit Kreis soll sie hier stehen bleiben statt die
    /// Oberfläche hängen zu lassen. Dass es keinen Kreis gibt, prüft `AlteWegeTests`.
    public static func ziel(_ weg: String) -> String {
        var s = saeubere(weg)
        var schritte = 0
        while let naechster = weiterleitungen[s], schritte < weiterleitungen.count {
            s = naechster
            schritte += 1
        }
        return s
    }

    /// Die Weiterleitung, wie der Wegweiser sie braucht: der Nachfolger, wenn der Weg ein alter
    /// ist - sonst `nil`.
    ///
    /// **Warum nicht einfach ``ziel(_:)``.** Weil ``ziel(_:)`` putzt, und für einen Weg, der
    /// nicht alt ist, wäre das Putzen ein Verlust: `/waerme/wiedergabe?tag=…&stunde=…` sagt der
    /// Seite, wo sie anfangen soll (`App/Seitenwahl.swift`, Vorlage `YearMap.tsx:82`). Nur wo
    /// wirklich weitergeleitet wird, darf der Fragezeichenteil fallen - dort trägt ihn in der
    /// Vorlage die Adresse (`bilanz/page.tsx:9-14`), in der App der Bereich.
    public static func weiterleitung(_ weg: String) -> String? {
        let neu = ziel(weg)
        return neu == saeubere(weg) ? nil : neu
    }

    /// Ob ein Weg dem Hausherrn vorbehalten ist.
    public static func nurHausherr(_ weg: String) -> Bool {
        let bereich = bereichVon(weg)
        return reiterVon(bereich, weg)?.nurHausherr ?? false
    }

    /// Fragezeichenteil weg, Schraegstriche am Ende weg, leer wird `/`.
    ///
    /// **Öffentlich, obwohl ihn von draussen niemand ruft.** Solange er privat war, stand seine
    /// Abschrift in `Zustand/AlteWege.swift` ein zweites Mal - drei Zeilen, die beim nächsten
    /// Umbau an einer der beiden Stellen anders geputzt hätten. Eine Zeichenkette zweimal
    /// verschieden zu säubern ist genau die Art Fehler, die erst an der Wand auffällt.
    public static func saeubere(_ weg: String) -> String {
        var s = weg.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s.isEmpty ? "/" : s
    }
}
