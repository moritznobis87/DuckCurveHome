import Foundation

/// Die Rechnungen der Kostenseite: die vier Beträge, die Aufstellung, das Verschieben, die
/// Spannen.
///
/// Vorlage ist `apps/web/src/components/reports/CostReport.tsx`. Der Kopfkommentar dort
/// (`CostReport.tsx:14-32`) nennt zwei Dinge, die diese Datei zu tragen hat.
///
/// **Erstens: die Seite addiert, sie rechnet nicht neu.** Euro-Beträge standen auf fünf Seiten
/// verstreut - Netzbezug beim Haus, Pellets bei der Wärme, Ladekosten bei der Wallbox, Erlös
/// bei der PV-Abrechnung, Ersparnis beim Speicher. Was der Oktober gekostet hat, war nirgends
/// in einer Zeile zu lesen. Hier steht sie, und jede Zahl darunter führt zu der Seite, von der
/// sie kommt - darum trägt ``Posten`` einen Weg.
///
/// **Zweitens: der Vergleichslauf darf negativ sein.** Was das Verschieben der Wärmepumpe
/// gebracht hat, lässt sich nicht messen; es gibt nur den einen Verlauf, der stattgefunden
/// hat. Genau dann, wenn die Zahl negativ ist, hat das Verschieben Geld gekostet, und eine
/// Anzeige, die das verschweigt, wäre Werbung (`CostReport.tsx:28-31`). ``verschiebung(_:)``
/// gibt darum drei Zustände zurück und nicht zwei.
///
/// **Warum das hier liegt und nicht in der Ansicht.** Jede Schwelle (0,05 kWh für eine
/// Preisspalte), jede Rundung (eine Stelle am Ø-Preis, zwei am Vergütungssatz), jede
/// Textauswahl („gespart“ gegen „mehr bezahlt“, „Tag“ gegen „Tage“) und jede Farbzuordnung ist
/// eine Entscheidung mit genau einer richtigen Antwort je Eingabe. In einer `View` könnte sie
/// unter Linux niemand nachrechnen.
///
/// **Die Felder von `EnergyTotalsOut` sind in Swift durchweg wahlfrei, im Web nicht**
/// (`Schema.swift` gegen `types.ts`). Der Unterschied ist keine Kleinigkeit und wird hier
/// zweierlei behandelt, wie in ``Pvabrechnung``: im Diagramm ist eine fehlende Zahl kein Balken
/// (`?? 0`), in einer Aufstellung ist sie ein Strich (``Formate/leer``). Eine Null, die keine
/// Messung ist, wäre auf einer Abrechnung eine Behauptung.
public enum Gelduebersicht {

    // MARK: - Die Rollen, in denen eine Zahl auf dieser Seite steht

    /// Welche Rolle ein Betrag hat - und damit, welche Farbe er bekommt.
    ///
    /// **Warum nicht ``Kennzahl/Ton``.** Dem fehlt der Wert für `--alert` (#E0533D), und genau
    /// der trägt hier die Hauptzahl: „Bezahlt“ steht in der Vorlage in `var(--alert)`
    /// (`CostReport.tsx:112`). ``Kennzahl/Ton`` zu erweitern hieße, den vollständigen `switch`
    /// in `Farbe.ton` zu erweitern (`apps/ios/DuckCurveHome/Gestalt/Farben.swift`), und der
    /// gehört allen Seiten. Darum eine eigene, kleine Aufzählung mit genau den sieben Rollen,
    /// die diese Seite kennt; die Ansicht setzt sie in Farben um und entscheidet nichts.
    public enum Ton: String, Sendable, Hashable, CaseIterable {
        /// `--alert` #E0533D - was bezahlt wurde, und was das Verschieben gekostet hat.
        case alarm
        /// `--mist` #7FA3B3 - was hereinkam, und der Speicheranteil der Ersparnis.
        case nebel
        /// `--amber` #F2A900 - was die Sonne gespart hat.
        case bernstein
        /// `#FFD778` - die Einspeisung im Diagramm. Weicher als `bernstein`, weil sie unter
        /// der Nulllinie neben dem Netzstrom steht (`CostReport.tsx:80`).
        case einspeisung
        /// `--text-1` - eine Zahl ohne Rolle.
        case text
        /// `--stove` #B5651D - die Pellets.
        case ofen
        /// `--text-3` - eine Zahl, die nur Herleitung ist: die entgangene Vergütung, und der
        /// Vergleichslauf, für den es nicht reicht.
        case leise
    }

    // MARK: - Die Wortlaute der Seite

    /// Der Kicker der Seite (`CostReport.tsx:107`).
    ///
    /// **Er steht in der App über der ersten Karte und nicht in der Reiterzeile.** Die Vorlage
    /// setzt ihn rechts in die Zeitraumzeile; die Zeitraumleiste der App trägt dort nur
    /// Spannenwahl und Datumskasten. Dieselbe Entscheidung hat die PV-Abrechnung getroffen.
    public static let seitenkicker = "Was der Zeitraum gekostet hat, in einer Zeile"

    public static let hauptdiagrammtitel = "Bezahlt und bekommen"
    /// Was statt des Hauptdiagramms dasteht (`CostReport.tsx:122`).
    ///
    /// **Nicht „Keine Werte in diesem Zeitraum.“** Der Unterschied ist die Begründung: es
    /// fehlen nicht die Werte, es fehlen die *bewerteten Stunden* - Minuten ohne Preis gehen
    /// in keinen Euro-Betrag ein.
    public static let hauptdiagrammleer = "Für diesen Zeitraum liegen keine bewerteten Stunden vor."

    public static let ersparnistitel = "Woraus die Ersparnis besteht"
    /// Wogegen die Ersparnis gerechnet ist (`CostReport.tsx:144-147`).
    public static let ersparnissatz = """
        Gerechnet gegen den Netzpreis der jeweiligen Stunde, abzüglich der Vergütung, die der \
        Strom eingespeist gebracht hätte. Was das Verschieben in Preistiefs gebracht hat, steht \
        in der Karte darunter - gerechnet, nicht gemessen.
        """

    public static let verschiebungstitel = "Was das Verschieben gebracht hat"
    /// Die Überschrift des zugeklappten Blocks in der Vergleichslaufkarte
    /// (`CostReport.tsx:183`).
    ///
    /// **Die Annahmen gehören zu der Zahl, neben der sie stehen** - und nicht in die
    /// Methodenkarte am Fuß, wo die App sie hatte. Zugeklappt steht die Karte ruhig,
    /// aufgeklappt steht alles da, was die Zahl voraussetzt (`CostReport.tsx:179-180`).
    public static let annahmentitel = "Annahmen des Vergleichslaufs"

    public static let aufstellungstitel = "Aufstellung"
    /// Was rechts im Kopf der Aufstellung steht (`CostReport.tsx:194`).
    public static let aufstellungskopf =
        "Beträge in Euro · aus denselben Stundenbilanzen wie alle anderen Seiten"
    /// Die Spaltenköpfe der Aufstellung (`CostReport.tsx:197-203`).
    public static let aufstellungsspalten = ["Posten", "Menge", "Ø Preis", "Betrag", "Seite"]
    /// Die dreiteilige Fußnote unter der Aufstellung (`CostReport.tsx:215-222`).
    ///
    /// Drei Sachen, die eine Zahl in der Tabelle erklären, und keine davon ist Beiwerk: woher
    /// ein Posten kommt, der früher nirgends stand; dass eine Menge geschätzt ist; und dass
    /// eine Zahl, die wie ein Verlust aussieht, keiner ist.
    public static let aufstellungssaetze = [
        """
        Netzstrom Speichergerät ist der Eigenverbrauch des Wechselrichters: Strom, der in das \
        Gerät floss, ohne die Zellen zu erreichen. Er stand früher als Ladung in der \
        Speicherbilanz und als Netzladung in der Statistik; bezahlt wurde er immer schon, nur \
        stand er nirgends.
        """,
        "Die Pelletmenge ist aus den Leistungsstufen des Ofens geschätzt, nicht gewogen.",
        """
        Die entgangene Vergütung ist kein Geld, das fehlt, sondern der Preis dafür, \
        Sonnenstrom selbst zu nutzen statt ihn einzuspeisen; sie steht hier, weil sie in den \
        Wärme- und Wallboxkosten mitgerechnet wird.
        """,
    ]

    public static let spannentitel = "Kosten im Zeitraum"

    // MARK: - Die vier Beträge der Kopfzeile

    /// Einer der vier Beträge am Kopf der Seite (`CostReport.tsx:110-117`).
    public struct Betrag: Sendable, Hashable, Identifiable {
        public let wort: String
        public let wert: String
        /// Die kleine Zeile darunter - wo eine etwas sagt.
        public let dazu: String?
        public let ton: Ton

        public var id: String { wort }

        public init(wort: String, wert: String, dazu: String? = nil, ton: Ton) {
            self.wort = wort
            self.wert = wert
            self.dazu = dazu
            self.ton = ton
        }
    }

    /// Die vier Beträge in der Reihenfolge der Vorlage (`CostReport.tsx:111-116`).
    ///
    /// **„Bezahlt“ enthält die Pellets, und das ist der Grund, warum die Seite `/energy/heat`
    /// holen muss.** Der Pelletpreis steht nicht in der Übersicht, sondern in `heat.stove`
    /// (`CostReport.tsx:66-67`). Ohne ihn wäre die führende Zahl der Seite zu klein - nicht um
    /// einen Rundungsfehler, sondern um einen ganzen Brennstoff.
    ///
    /// **„Gespart“ ist Sonne plus Speicher, nicht der Vergleichslauf.** Das sind zwei
    /// verschiedene Zahlen: hier steht, was Eigenstrom gegenüber dem Netzpreis derselben
    /// Stunde eingespart hat; was das *Verschieben* gebracht hat, steht weiter unten und ist
    /// gerechnet, nicht gemessen.
    public static func kopfbetraege(_ b: EnergySummaryOut, waerme: HeatReportOut?) -> [Betrag] {
        let t = b.totals
        let pellets = waerme?.stove.pelletEur
        let bezahlt = summe([t.importCostEur, pellets])
        let bekommen = t.exportRevenueEur
        let gespart = summe([t.pvDirectSavingsEur, t.batteryNetEur])
        let tage = bewerteteTage(t.minutes)
        return [
            Betrag(
                wort: "Bezahlt", wert: Formate.euro(bezahlt),
                dazu: netzUndPellets(t.importCostEur, pellets), ton: .alarm),
            Betrag(
                wort: "Bekommen", wert: Formate.euro(bekommen),
                dazu: einspeisesatz(t.exportKwh), ton: .nebel),
            Betrag(
                wort: "Gespart", wert: Formate.euro(gespart),
                dazu: "Sonne direkt und Speicher, gegen den Netzpreis derselben Stunde",
                ton: .bernstein),
            Betrag(
                wort: "Energie je Tag",
                wert: Formate.euro(jeTag(bezahlt: bezahlt, bekommen: bekommen, tage: tage)),
                dazu: jeTagSatz(tage), ton: .text),
        ]
    }

    /// Eine Summe aus Teilen, von denen jeder fehlen kann.
    ///
    /// **Die Regel: eine Summe ist eine Zahl, sobald ein Teil eine ist; fehlende Teile zählen
    /// nicht mit. Fehlen alle, steht ein Strich.** Im Web sind diese Felder nie `null`, und
    /// die Vorlage addiert sie darum einfach (`CostReport.tsx:67`, `:69`, `:213`). In Swift
    /// ist jedes wahlfrei, und beide Auswege wären falsch: `?? 0` macht aus einer fehlenden
    /// Messung eine bezahlte Null, und „alle oder keiner“ ließe „Bezahlt“ verschwinden, weil
    /// der Ofen in diesem Zeitraum nicht gelaufen ist.
    static func summe(_ teile: [Double?]) -> Double? {
        let da = teile.compactMap { $0 }.filter { $0.isFinite }
        guard !da.isEmpty else { return nil }
        return da.reduce(0, +)
    }

    /// Wie viele Tage der Zeitraum bewertet hat (`CostReport.tsx:70`).
    ///
    /// Mindestens einer: ein Zeitraum mit sechs bewerteten Stunden soll „so viel kostet ein
    /// Tag“ nicht vervierfachen. Ohne bewertete Minuten gibt es die Größe nicht.
    static func bewerteteTage(_ minuten: Int?) -> Double? {
        guard let minuten, minuten > 0 else { return nil }
        return max(1, Double(minuten) / 1440)
    }

    /// „bezahlt minus bekommen“, auf einen Tag gerechnet (`CostReport.tsx:71`).
    static func jeTag(bezahlt: Double?, bekommen: Double?, tage: Double?) -> Double? {
        guard let bezahlt, let bekommen, let tage, tage > 0 else { return nil }
        return (bezahlt - bekommen) / tage
    }

    /// „Netzstrom 12,34 € · Pellets 5,67 €“ (`CostReport.tsx:112`).
    ///
    /// Fehlen beide, fehlt der Satz: „Netzstrom - · Pellets -“ sagt nichts, was die Zahl
    /// darüber nicht schon sagt.
    static func netzUndPellets(_ netz: Double?, _ pellets: Double?) -> String? {
        guard netz != nil || pellets != nil else { return nil }
        return "Netzstrom \(Formate.euro(netz)) · Pellets \(Formate.euro(pellets))"
    }

    /// „Einspeisung 123 kWh · netto“ (`CostReport.tsx:113`).
    static func einspeisesatz(_ kwh: Double?) -> String? {
        guard let kwh, kwh.isFinite else { return nil }
        return "Einspeisung \(menge(kwh, einheit: "kWh", stellen: 0)) · netto"
    }

    /// „bezahlt minus bekommen, 30 Tage bewertet“ (`CostReport.tsx:115`).
    ///
    /// Unter anderthalb Tagen steht „Tag“: auf der Tagesansicht hieße es sonst „1 Tage“.
    static func jeTagSatz(_ tage: Double?) -> String? {
        guard let tage, tage.isFinite else { return nil }
        let wort = tage < 1.5 ? "Tag" : "Tage"
        return "bezahlt minus bekommen, \(Formate.zahl(tage, stellen: 0)) \(wort) bewertet"
    }

    // MARK: - Die Aufstellung

    /// Eine Zeile der Aufstellung: was es war, wie viel, zu welchem Preis, und wo es herkommt.
    ///
    /// **Der Weg ist Inhalt, nicht Schmuck.** Der halbe Zweck der Seite ist, dass jede Zahl zu
    /// der Seite führt, auf der sie entsteht (`CostReport.tsx:17-20`). Darum steht er hier und
    /// nicht in der Ansicht - welche Zahl von welcher Seite kommt, ist eine Zuordnung und
    /// keine Gestaltung.
    public struct Posten: Sendable, Hashable, Identifiable {
        public let wort: String
        /// Die Menge mit ihrer Einheit, oder leer, wo keine gilt.
        public let menge: String
        /// Der mittlere Preis in ct, oder leer.
        public let preis: String
        public let betrag: String
        public let ton: Ton
        /// Wohin ein Tippen führt.
        public let weg: String
        /// Wie die Seite heißt, auf die der Weg führt.
        public let seite: String

        public var id: String { wort }

        public init(
            wort: String, menge: String, preis: String, betrag: String, ton: Ton, weg: String,
            seite: String
        ) {
            self.wort = wort
            self.menge = menge
            self.preis = preis
            self.betrag = betrag
            self.ton = ton
            self.weg = weg
            self.seite = seite
        }
    }

    /// Die sieben Posten in der Reihenfolge der Vorlage (`CostReport.tsx:205-212`).
    public static func aufstellung(_ b: EnergySummaryOut, waerme: HeatReportOut?) -> [Posten] {
        let t = b.totals
        let haushalt = haushaltsrest(t)
        let ofen = waerme?.stove
        return [
            Posten(
                wort: "Netzstrom Haushalt", menge: kwhMenge(haushalt.kwh),
                preis: ctJeKwh(haushalt.eur, haushalt.kwh), betrag: Formate.euro(haushalt.eur),
                ton: .alarm, weg: "/strom", seite: "Strom"),
            Posten(
                wort: "Netzstrom Wärmepumpe", menge: kwhMenge(t.heatPumpGridKwh),
                preis: ctJeKwh(t.heatPumpCostEur, t.heatPumpGridKwh),
                betrag: Formate.euro(t.heatPumpCostEur), ton: .alarm, weg: "/waerme",
                seite: "Wärme"),
            Posten(
                wort: "Netzstrom Wallbox", menge: kwhMenge(t.evGridKwh),
                preis: ctJeKwh(t.evCostEur, t.evGridKwh), betrag: Formate.euro(t.evCostEur),
                ton: .alarm, weg: "/strom/wallbox", seite: "Wallbox"),
            Posten(
                wort: "Netzstrom Speichergerät", menge: kwhMenge(t.batteryDeviceGridKwh),
                preis: ctJeKwh(t.batteryDeviceCostEur, t.batteryDeviceGridKwh),
                betrag: Formate.euro(t.batteryDeviceCostEur), ton: .alarm,
                weg: "/strom/speicher", seite: "Speicher"),
            Posten(
                wort: "Pellets", menge: pelletmenge(ofen?.pelletKg), preis: "",
                betrag: Formate.euro(ofen?.pelletEur), ton: .ofen, weg: "/waerme",
                seite: "Wärme"),
            Posten(
                wort: "Einspeisung", menge: kwhMenge(t.exportKwh),
                preis: menge(b.meta.feedInCtKwh, einheit: "ct", stellen: 2),
                betrag: abzug(t.exportRevenueEur), ton: .nebel, weg: "/geld/pv-abrechnung",
                seite: "PV-Abrechnung"),
            Posten(
                wort: "Entgangene Vergütung (Wärmepumpe, Wallbox, Speichergerät)", menge: "",
                preis: "",
                betrag: Formate.euro(
                    summe([
                        t.heatPumpOpportunityEur, t.evOpportunityEur,
                        t.batteryDeviceOpportunityEur,
                    ])),
                ton: .leise, weg: "/strom/pv", seite: "Photovoltaik"),
        ]
    }

    /// Was vom Netzbezug übrig bleibt, wenn Wärmepumpe, Wallbox und Speichergerät abgezogen
    /// sind (`CostReport.tsx:101-102`).
    ///
    /// **Das Speichergerät zieht aus demselben Netzbezug wie alles andere.** Ohne diesen Abzug
    /// stünde sein Verbrauch zweimal in der Aufstellung: einmal als eigener Posten und einmal
    /// im Haushalt (`CostReport.tsx:99-100`).
    ///
    /// Nie unter Null: an einem Tag, an dem die Zuordnung der Geräte mehr erfasst als der
    /// Zähler, wäre ein negativer Haushaltsposten ein Rechenfehler und keine Auskunft.
    public static func haushaltsrest(_ t: EnergyTotalsOut) -> (eur: Double?, kwh: Double?) {
        let eur = t.importCostEur.map { ganz in
            max(
                0,
                ganz - (t.heatPumpCostEur ?? 0) - (t.evCostEur ?? 0)
                    - (t.batteryDeviceCostEur ?? 0))
        }
        let kwh = t.importKwh.map { ganz in
            max(
                0,
                ganz - (t.heatPumpGridKwh ?? 0) - (t.evGridKwh ?? 0)
                    - (t.batteryDeviceGridKwh ?? 0))
        }
        return (eur, kwh)
    }

    /// Der mittlere Preis eines Postens in ct je kWh (`CostReport.tsx:104`).
    ///
    /// **Die Schwelle 0,05 kWh steht in der Vorlage, und sie ist keine Schönheit.** Ein Gerät,
    /// das im Zeitraum 0,002 kWh aus dem Netz gezogen hat, ergibt einen mittleren Preis von
    /// einigen hundert ct/kWh - eine Zahl, die aussieht wie ein Messfehler und einer ist.
    ///
    /// **Eine Nachkommastelle, nicht zwei.** Die App hatte zwei (`GeldSeiten.swift:109`); ein
    /// Mittelwert über tausend Minutenwerte ist im Hundertstelcent nicht belastbar.
    public static func ctJeKwh(_ eur: Double?, _ kwh: Double?) -> String {
        guard let eur, let kwh, eur.isFinite, kwh > 0.05 else { return Formate.leer }
        return menge(eur / kwh * 100, einheit: "ct", stellen: 1)
    }

    /// „123 kWh“ - oder ein Strich, wo nichts gemessen ist.
    ///
    /// **Nicht „- kWh“.** Die Vorlage schreibt das an dieser Stelle (`${de1(t?.x, 0)} kWh`),
    /// aber das ist der Abdruck einer wahlfreien Verkettung und keine Entscheidung: eine
    /// Einheit ohne Zahl ist keine Menge. Dieselbe Trennung hat ``Pvabrechnung`` gewählt.
    static func kwhMenge(_ kwh: Double?) -> String {
        guard let kwh, kwh.isFinite else { return Formate.leer }
        return menge(kwh, einheit: "kWh", stellen: 0)
    }

    /// „12,3 kg“ - die geschätzte Pelletmenge, mit **einer** Stelle (`CostReport.tsx:209`).
    static func pelletmenge(_ kg: Double?) -> String {
        guard let kg, kg.isFinite else { return Formate.leer }
        return menge(kg, einheit: "kg", stellen: 1)
    }

    /// „− 12,34 €“ (`CostReport.tsx:210`).
    ///
    /// **Das Minus steht abgesetzt vor dem Betrag und gehört nicht zur Zahl.** Die Einspeisung
    /// ist kein negativer Erlös, sondern ein Abzug in einer Aufstellung aus Kosten; die Zahl
    /// selbst ist positiv. Darum U+2212 und ein Leerzeichen, nicht das Vorzeichen aus
    /// ``Formate/zahl(_:stellen:)``.
    static func abzug(_ eur: Double?) -> String {
        guard let eur, eur.isFinite else { return Formate.leer }
        return Formate.minus + " " + Formate.euro(eur)
    }

    /// Eine Zahl mit ihrer Einheit, geschütztes schmales Leerzeichen dazwischen.
    static func menge(_ wert: Double?, einheit: String, stellen: Int) -> String {
        let z = Formate.zahl(wert, stellen: stellen)
        return z == Formate.leer ? z : z + Formate.schmalesLeerzeichen + einheit
    }

    // MARK: - Woraus die Ersparnis besteht

    /// Eine der beiden Leisten (`CostReport.tsx:127-142`).
    public struct Ersparnisteil: Sendable, Hashable, Identifiable {
        public let wort: String
        public let wert: String
        /// Wie lang die Leiste ist, 0 bis 1.
        public let anteil: Double
        public let ton: Ton

        public var id: String { wort }

        public init(wort: String, wert: String, anteil: Double, ton: Ton) {
            self.wort = wort
            self.wert = wert
            self.anteil = anteil
            self.ton = ton
        }
    }

    /// Die zwei Teile der Ersparnis auf **gemeinsamer** Skala (`CostReport.tsx:130`).
    ///
    /// **Nicht je Zeile normiert.** Beide Leisten messen an derselben Größe, nämlich der
    /// grösseren der beiden; je Zeile normiert wäre die kleinere immer voll und der Vergleich,
    /// um den es geht, wäre weg. Der Boden 0,01 € verhindert die Division durch Null an einem
    /// Tag, an dem nichts gespart wurde.
    ///
    /// **`batteryNetEur` darf negativ sein** - ein Speicher, der teuer geladen und billig
    /// entladen hat, hat Geld gekostet. Die Leiste ist dann leer; eine nach links laufende
    /// Leiste gibt es in der Vorlage nicht (ein negatives `width` ignoriert der Browser), und
    /// der Betrag daneben nennt das Vorzeichen.
    public static func ersparnisteile(_ t: EnergyTotalsOut) -> [Ersparnisteil] {
        let sonne = t.pvDirectSavingsEur ?? 0
        let speicher = t.batteryNetEur ?? 0
        let groesste = max(0.01, sonne, speicher)
        return [
            Ersparnisteil(
                wort: "Sonne direkt genutzt", wert: Formate.euro(sonne),
                anteil: leistenanteil(sonne, groesste), ton: .bernstein),
            Ersparnisteil(
                wort: "Speicher statt Netz (netto)", wert: Formate.euro(speicher),
                anteil: leistenanteil(speicher, groesste), ton: .nebel),
        ]
    }

    /// Der Anteil einer Leiste, auf ganze Prozent gerundet wie in der Vorlage
    /// (`Math.round(v / max * 100)`, `CostReport.tsx:138`).
    static func leistenanteil(_ wert: Double, _ groesste: Double) -> Double {
        guard groesste > 0, wert.isFinite else { return 0 }
        return min(1, max(0, (wert / groesste * 100).rounded() / 100))
    }

    // MARK: - Was das Verschieben gebracht hat

    /// Die drei Zeilen links in der Vergleichslaufkarte (`CostReport.tsx:156-173`).
    public struct Verschiebung: Sendable, Hashable {
        /// Die führende Zahl - oder ein Strich, wenn keine Antwort da ist.
        public let zahl: String
        public let ton: Ton
        /// Der Satz darunter: was die Zahl bedeutet, oder dass sie es nicht tut.
        public let satz: String
        /// Die Detailzeile - nur, wenn überhaupt ein Tag gerechnet wurde.
        public let dazu: String?

        public init(zahl: String, ton: Ton, satz: String, dazu: String?) {
            self.zahl = zahl
            self.ton = ton
            self.satz = satz
            self.dazu = dazu
        }
    }

    /// Was neben dem Tagesdiagramm des Vergleichslaufs steht.
    ///
    /// **Drei Zustände, nicht zwei** (`CostReport.tsx:103`, `:161-165`). Gespart ist Bernstein,
    /// mehr bezahlt ist Alarm, und *keine Aussage* ist leise - eine graue Null sagt „dazu steht
    /// hier nichts“, eine bernsteinfarbene Null sagt „es hat nichts gebracht“, und das ist
    /// nicht dasselbe. `daysUsed == 0` heißt, dass kein Tag die Voraussetzungen des
    /// Vergleichslaufs erfüllt hat; die Zahl ist dann keine Aussage, sondern ein Rest.
    ///
    /// **`actualEur` und `naiveEur` kommen nicht vor.** Die App zeigte sie
    /// (`GeldSeiten.swift:26-27`); in der Vorlage stehen sie auf dieser Seite nicht. Zwei
    /// Beträge, von denen keiner bezahlt wurde - der eine ist eine Teilsumme, der andere ein
    /// Gedankenspiel -, neben vier Beträgen, die bezahlt und bekommen wurden, machen die Seite
    /// unlesbar.
    public static func verschiebung(_ v: ShiftReportOut?) -> Verschiebung {
        guard let v, v.daysUsed > 0 else {
            return Verschiebung(
                zahl: v.map { Formate.euro($0.savingEur) } ?? Formate.leer, ton: .leise,
                satz: "Für diesen Zeitraum reicht es nicht für eine Aussage.", dazu: nil)
        }
        let gespart = v.savingEur >= 0
        return Verschiebung(
            zahl: Formate.euro(v.savingEur), ton: gespart ? .bernstein : .alarm,
            satz: (gespart ? "gespart" : "mehr bezahlt")
                + " gegenüber einem Lauf ohne Preisblick",
            dazu: verschiebungszeile(v))
    }

    /// „1,4 ct je verschobener kWh · 38 von 210 kWh verschoben · 12 Tage gerechnet · 2 ohne
    /// Aussage (zu wenig Preisdaten)“ (`CostReport.tsx:166-172`).
    ///
    /// Der Satz vom Cent fällt weg, wenn der Dienst ihn nicht liefert - „- ct je verschobener
    /// kWh“ wäre kein Satz. „Tag“ im Einzahl bei genau einem.
    static func verschiebungszeile(_ v: ShiftReportOut) -> String {
        var teile: [String] = []
        if let ct = v.savingCtPerKwh, ct.isFinite {
            teile.append(menge(ct, einheit: "ct", stellen: 1) + " je verschobener kWh")
        }
        teile.append(
            "\(Formate.zahl(v.shiftedKwh, stellen: 0)) von "
                + "\(menge(v.heatPumpKwh, einheit: "kWh", stellen: 0)) verschoben")
        teile.append("\(v.daysUsed) \(v.daysUsed == 1 ? "Tag" : "Tage") gerechnet")
        if v.daysSkipped > 0 {
            // Der Grund in Klammern nur, wenn es einen gibt: „(null)“ hat die Vorlage nur
            // deshalb nicht, weil `skipped_de` dort gefüllt ist, wenn Tage fehlen.
            let grund = v.skippedDe.flatMap { $0.isEmpty ? nil : " (\($0))" } ?? ""
            teile.append("\(v.daysSkipped) ohne Aussage\(grund)")
        }
        return teile.joined(separator: " · ")
    }

    // MARK: - Die beiden Balkendiagramme

    /// Ein Wert eines Balkendiagramms: das Wort an der Achse und der Betrag in Euro.
    public struct Balkenwert: Sendable, Hashable {
        public let wort: String
        public let wert: Double

        public init(wort: String, wert: Double) {
            self.wort = wort
            self.wert = wert
        }
    }

    /// Eine Reihe eines Balkendiagramms - der Name steht in der Legende.
    public struct Balkenreihe: Sendable, Hashable, Identifiable {
        public let name: String
        public let ton: Ton
        public let werte: [Balkenwert]

        public var id: String { name }

        public init(name: String, ton: Ton, werte: [Balkenwert]) {
            self.name = name
            self.ton = ton
            self.werte = werte
        }
    }

    /// „Netzstrom“ und „Einspeisung“ je Zeitraumstück (`CostReport.tsx:73-83`).
    ///
    /// **Die Vergütung steht unter der Nulllinie: bekommen, nicht bezahlt**
    /// (`CostReport.tsx:79`). Darum das Vorzeichen, und darum muss die Werteachse die Null
    /// zeigen.
    ///
    /// **Netzstrom ist #E0533D und nicht `netzBezug`.** Die App nahm `Farbe.netzBezug`
    /// (#7FA3B3, `GeldSeiten.swift:62`) - dieselbe Farbe wie die Einspeisung in den
    /// Kennzahlen, und damit stand in einem gestapelten Bild zweimal derselbe Ton für
    /// Gegenteiliges. Die Vorlage nimmt `C.alert` (`palette.ts:76`).
    ///
    /// Ein fehlender Betrag ist hier eine Null und kein Strich: ein Balken, der fehlt, ist
    /// kein Balken, und eine Lücke im Stapel wäre falscher als eine Null.
    public static func hauptreihen(_ b: EnergySummaryOut) -> [Balkenreihe] {
        [
            Balkenreihe(
                name: "Netzstrom", ton: .alarm,
                werte: b.buckets.map {
                    Balkenwert(wort: $0.label, wert: $0.totals.importCostEur ?? 0)
                }),
            Balkenreihe(
                name: "Einspeisung", ton: .einspeisung,
                werte: b.buckets.map {
                    Balkenwert(wort: $0.label, wert: -($0.totals.exportRevenueEur ?? 0))
                }),
        ]
    }

    /// Die Tage des Vergleichslaufs als zwei Reihen (`CostReport.tsx:87-95`).
    ///
    /// **Zwei Reihen statt einer eingefärbten: so steht in der Legende, was ein Vorzeichen
    /// bedeutet** (`CostReport.tsx:85-86`). Die App hatte eine Reihe in `Farbe.mist`, und damit
    /// sah ein Tag, der Geld gekostet hat, aus wie einer, der welches gebracht hat.
    ///
    /// **Tage mit einer Notiz werden weggelassen** (`CostReport.tsx:88`). Eine Notiz heißt,
    /// dass der Vergleichslauf für diesen Tag nichts aussagt; ein Balken der Höhe Null an
    /// seiner Stelle wäre die Behauptung, es habe nichts gebracht.
    public static func verschiebungsreihen(_ v: ShiftReportOut?) -> [Balkenreihe] {
        let tage = (v?.days ?? []).filter { $0.noteDe == nil }
        return [
            Balkenreihe(
                name: "gebracht", ton: .bernstein,
                werte: tage.map { Balkenwert(wort: Tag.tagMonat($0.day), wert: max(0, $0.savingEur)) }
            ),
            Balkenreihe(
                name: "gekostet", ton: .alarm,
                werte: tage.map { Balkenwert(wort: Tag.tagMonat($0.day), wert: min(0, $0.savingEur)) }
            ),
        ]
    }

    // MARK: - Die vier Spannen

    /// Die fünf Größen über Tag, Woche, Monat und Jahr des Ankertags
    /// (`CostReport.tsx:228-234`).
    ///
    /// Fehlt eine Spanne, steht in ihrer Spalte ein Strich und nicht der Wert der Nachbarin
    /// (`CostReport.tsx:98`) - die vier Abfragen laufen nebeneinander, und eine gescheiterte
    /// lässt ihre Spalte leer.
    ///
    /// **„Bezahlt (Netzstrom)“ müsste `--alert` tragen und trägt `glut`.** ``Streifenzeile``
    /// nimmt ``Kennzahl/Ton``, und dem fehlt der Wert für #E0533D; `glut` (#E0966B) ist der
    /// nächstliegende vorhandene Ton. Eine Zeile weniger wäre der schlechtere Tausch.
    public static func spannenzeilen(_ je: [Spanne: EnergySummaryOut]) -> [Streifenzeile] {
        let folge = Spanne.allCases
        func reihe(_ wort: String, _ ton: Kennzahl.Ton, _ wert: (EnergyTotalsOut) -> String)
            -> Streifenzeile
        {
            Streifenzeile(
                wort: wort, werte: folge.map { je[$0].map { wert($0.totals) } ?? Formate.leer },
                ton: ton)
        }
        return [
            reihe("Bezahlt (Netzstrom)", .glut) { Formate.euro($0.importCostEur) },
            reihe("Bekommen (Einspeisung)", .nebel) { Formate.euro($0.exportRevenueEur) },
            reihe("Gespart (Sonne, Speicher)", .bernstein) {
                Formate.euro(summe([$0.pvDirectSavingsEur, $0.batteryNetEur]))
            },
            reihe("Netzbezug", .normal) { kwhMenge($0.importKwh) },
            reihe("Ø Bezugspreis", .normal) { bezugspreis($0.avgImportPriceCt) },
        ]
    }

    /// „28,4 ct“ - **eine** Nachkommastelle (`CostReport.tsx:233`).
    static func bezugspreis(_ ctKwh: Double?) -> String {
        guard let ctKwh, ctKwh.isFinite else { return Formate.leer }
        return menge(ctKwh, einheit: "ct", stellen: 1)
    }

    // MARK: - Die Sätze unter der Seite

    /// Die Kurzzeile der Methodenkarte - sie bleibt auch zugeklappt sichtbar
    /// (`ReportShell.tsx:166-168`).
    ///
    /// **Sie stand auf dieser Seite nirgends** (`GeldSeiten.swift:78`). Die Datenabdeckung
    /// schränkt jede Zahl der Seite ein: eine Seite mit 61 Prozent sieht aus wie eine mit
    /// hundert. Denselben Satz baut ``Waermeuebersicht/abdeckungssatz(_:)``; zwei Fassungen
    /// davon wären zwei Antworten auf dieselbe Frage.
    public static func methodenkurz(_ b: EnergySummaryOut) -> String {
        Waermeuebersicht.abdeckungssatz(b.meta)
    }

    /// Die Absätze hinter dem Deckel (`CostReport.tsx:236`, `ReportShell.tsx:169-172`).
    ///
    /// Zuerst, was nur für diese Seite gilt - die Notiz des Ofens, denn die Pelletmenge ist
    /// geschätzt -, dann der Absatz, der auf jeder Berichtsseite steht. Die Annahmen des
    /// Vergleichslaufs sind **nicht** dabei: sie stehen jetzt in der Karte bei der Zahl, die
    /// sie voraussetzt.
    public static func methodensaetze(_ b: EnergySummaryOut, waerme: HeatReportOut?) -> [String] {
        [waerme?.stove.noteDe, b.meta.estimatedNoteDe].compactMap { $0 }.filter { !$0.isEmpty }
    }
}
