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
    /// Nur mit Vollzugriff sichtbar.
    public var nurHausherr: Bool
    /// Die Ansichten eines Reiters, wenn er mehr als eine hat: dieselbe Sache aus zwei
    /// Richtungen, etwa der Augenblick und ein ganzer Tag. Sie stehen als Umschalter unter der
    /// Reiterzeile, nicht als eigene Reiter daneben. Die erste Ansicht hat die Adresse des Reiters.
    public var unter: [Ansicht]

    public var id: String { weg }

    public init(weg: String, name: String, mitZeitraum: Bool = false, nurHausherr: Bool = false, unter: [Ansicht] = []) {
        self.weg = weg
        self.name = name
        self.mitZeitraum = mitZeitraum
        self.nurHausherr = nurHausherr
        self.unter = unter
    }
}

/// Eine Ansicht unterhalb eines Reiters.
public struct Ansicht: Sendable, Hashable, Identifiable {
    public var weg: String
    public var name: String
    public var id: String { weg }

    public init(weg: String, name: String) {
        self.weg = weg
        self.name = name
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
        Bereich(schluessel: .jetzt, weg: "/", zeichen: .ente, name: "Jetzt"),
        // Das Haus: die Raeume als Liste und als Modell, ein Schalter in der Seite und kein Reiter.
        Bereich(schluessel: .haus, weg: "/haus", zeichen: .haus, name: "Haus"),
        Bereich(
            schluessel: .energie, weg: "/strom", zeichen: .blitz, name: "Energie",
            reiter: [
                Reiter(weg: "/strom", name: "Strom", mitZeitraum: true),
                Reiter(weg: "/waerme", name: "Wärme", mitZeitraum: true),
                Reiter(weg: "/strom/pv", name: "Photovoltaik", mitZeitraum: true),
                Reiter(weg: "/strom/speicher", name: "Speicher", mitZeitraum: true),
                Reiter(weg: "/strom/wallbox", name: "Wallbox", mitZeitraum: true),
                Reiter(weg: "/strom/jahr", name: "Jahreskarte"),
            ]
        ),
        Bereich(
            schluessel: .geld, weg: "/geld", zeichen: .euro, name: "Geld",
            reiter: [
                Reiter(weg: "/geld", name: "Kosten", mitZeitraum: true),
                Reiter(weg: "/geld/pv-abrechnung", name: "PV-Abrechnung", mitZeitraum: true, nurHausherr: true),
                Reiter(weg: "/geld/rechnungen", name: "Rechnungen", nurHausherr: true),
            ]
        ),
        Bereich(
            schluessel: .technik, weg: "/waerme/anlage", zeichen: .zahnrad, name: "Technik",
            // Erst die Anlage und ihr Fahrplan, dann die Auswertungen, dann das Einstellen.
            reiter: [
                Reiter(
                    weg: "/waerme/anlage", name: "Anlage",
                    unter: [
                        Ansicht(weg: "/waerme/anlage", name: "Jetzt"),
                        Ansicht(weg: "/waerme/wiedergabe", name: "Ein Tag"),
                    ]
                ),
                Reiter(
                    weg: "/waerme/waermepumpe", name: "Wärmepumpe",
                    unter: [
                        Ansicht(weg: "/waerme/waermepumpe", name: "Jetzt"),
                        Ansicht(weg: "/waerme/waermepumpe/betrieb", name: "Betrieb"),
                        Ansicht(weg: "/waerme/waermepumpe/kennlinie", name: "Kennlinie"),
                        Ansicht(weg: "/waerme/waermepumpe/regler", name: "Regler"),
                    ]
                ),
                Reiter(
                    weg: "/waerme/fahrplan", name: "Fahrplan",
                    unter: [
                        Ansicht(weg: "/waerme/fahrplan", name: "Voraus"),
                        Ansicht(weg: "/waerme/nachbetrachtung", name: "Rückblick"),
                    ]
                ),
                Reiter(weg: "/waerme/wirkung", name: "Wirkung"),
                Reiter(weg: "/waerme/raeume", name: "Heizkreise", mitZeitraum: true),
                Reiter(weg: "/system", name: "Prognose", nurHausherr: true),
                Reiter(weg: "/system/daten", name: "Daten prüfen", mitZeitraum: true, nurHausherr: true),
                Reiter(weg: "/waerme/annahmen", name: "Annahmen", nurHausherr: true),
                Reiter(weg: "/system/mitteilungen", name: "Mitteilungen", nurHausherr: true),
                Reiter(weg: "/system/haustuer", name: "Haustür", nurHausherr: true),
                Reiter(weg: "/system/zugang", name: "Zugang und Sicherung", nurHausherr: true),
            ]
        ),
    ]

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

    /// Ob ein Weg dem Hausherrn vorbehalten ist.
    public static func nurHausherr(_ weg: String) -> Bool {
        let bereich = bereichVon(weg)
        return reiterVon(bereich, weg)?.nurHausherr ?? false
    }

    /// Fragezeichenteil weg, Schraegstriche am Ende weg, leer wird `/`.
    private static func saeubere(_ weg: String) -> String {
        var s = weg.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s.isEmpty ? "/" : s
    }
}
