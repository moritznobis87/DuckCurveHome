import Foundation

/// Die Adressen, die es nicht mehr gibt, und die Seite, auf die sie heute führen.
///
/// **Warum eine App Weiterleitungen braucht.** Die Vorlage hat zwei davon, und beide mit
/// derselben Begründung. Die eine Liste steht in `apps/web/next.config.ts:13-31`, wörtlich:
/// „Die alten Adressen, eine je Geraet, fuehren auf die neuen Bereiche. Lesezeichen und der
/// Verlauf des Wand-iPads bleiben gueltig; die Abfrage (?period=&anchor=) reist mit.“
/// Die andere ist eine ganze Seite, die nichts mehr zeichnet
/// (`apps/web/src/app/waerme/bilanz/page.tsx:3-7`): „Die Bilanz ist in der Wärmeübersicht
/// aufgegangen (10.11.2026). Die Adresse bleibt als Weiterleitung, damit ein Lesezeichen und ein
/// Verweis von außen nicht ins Leere führen; der Zeitraum in der Adresse reist mit.“
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
/// (``Bereiche/bereichVon(_:)``). Ein zweiter Träger für dieselbe Angabe wäre eine zweite
/// Wahrheit - deshalb trägt ``ziel(_:)`` den Fragezeichenteil nicht weiter, sondern wirft ihn
/// weg wie `Bereiche` es auch tut.
public enum AlteWege {
    /// Alte Adresse links, ihr Nachfolger rechts.
    ///
    /// Die elf Paare sind die Abschrift von `apps/web/next.config.ts:18-30`; das zwölfte,
    /// `/waerme/bilanz` → `/waerme`, ist die Weiterleitungsseite
    /// `apps/web/src/app/waerme/bilanz/page.tsx:14` (`redirect(s ? "/waerme?" + s : "/waerme")`).
    ///
    /// **`/haus` fehlt mit Absicht**, und die Vorlage sagt auch warum
    /// (`next.config.ts:15-16`): seit dem 30.10.2026 ist das der Bereich mit dem Hausmodell,
    /// die alte Hausbilanz dahinter wohnt unter `/strom`.
    ///
    /// **Zwei Stufen sind erlaubt.** `/waermebilanz` führt in der Vorlage auf `/waerme/bilanz`
    /// und von dort weiter auf `/waerme`; die Tabelle schreibt beide Stufen einzeln hin, statt
    /// die zweite in die erste einzurechnen - sonst stünde das Ziel zweimal da und liefe beim
    /// nächsten Umbau auseinander. ``ziel(_:)`` folgt der Kette.
    public static let tabelle: [String: String] = [
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
    /// Ein Weg, der in ``tabelle`` nicht vorkommt, kommt unverändert zurück - geputzt. Die
    /// Schleife bricht nach so vielen Schritten ab, wie die Tabelle Einträge hat: mehr kann eine
    /// Kette ohne Kreis nicht sein, und mit Kreis soll sie hier stehen bleiben statt die
    /// Oberfläche hängen zu lassen. Dass es keinen Kreis gibt, prüft `AlteWegeTests`.
    public static func ziel(_ weg: String) -> String {
        var s = saeubere(weg)
        var schritte = 0
        while let naechster = tabelle[s], schritte < tabelle.count {
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

    /// Fragezeichenteil weg, Schrägstriche am Ende weg, leer wird `/`.
    ///
    /// Dasselbe wie `Bereiche.saeubere(_:)`, das dort privat ist; eine Abschrift von drei Zeilen
    /// ist billiger als eine Abhängigkeit, die nur für sie öffentlich gemacht wird.
    private static func saeubere(_ weg: String) -> String {
        var s = weg.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s.isEmpty ? "/" : s
    }
}
