import Foundation

/// Ein Feld des Annahmenformulars: eine Zahl, die der Hausherr nachtragen muss.
///
/// **Warum ein Feld eine Tabellenzeile ist und keine Ansicht.** Die Vorlage
/// (`apps/web/src/components/settings/HeatSettings.tsx:21-43`) führt die dreizehn Annahmen in
/// einer Liste und zeichnet jede mit derselben Zeile. Die App hatte an dieser Stelle gar kein
/// Formular, sondern sechs Lesekarten, deren Zeilen aus dem JSON-Schema fielen - alphabetisch
/// sortierte englische Schlüssel. Wer „buffer loss kw per k" liest, weiß nicht, was er ändert.
/// In der Tabelle steht das deutsche Wort, die Einheit, der Satz, der die Zahl begründet, und
/// vor allem: wo der Wert herkommt und wohin er zurückgeht.
///
/// **Es ist keine Prüfung.** `schritt` und `stellen` runden die Anzeige, sie grenzen nichts ein.
/// Die Grenzen je Feld kennt der Dienst (`apps/api/src/dch_api/schemas.py:930-944`) und die
/// Widersprüche zwischen zwei Feldern kennt nur er (`hems_core/domain/config.py:354-375`):
/// der Wasseranteil gegen die Gesamtleistung, die Zieltemperatur gegen die Grenzen des Puffers.
/// Diese Tabelle baut das nicht nach, weil zwei Prüfungen auseinanderlaufen, sobald eine von
/// beiden gepflegt wird.
///
/// **Nicht `Hashable`.** Ein Feld trägt zwei Funktionen; gleich sind zwei Felder dann, wenn ihr
/// `schluessel` gleich ist, und das ist genau die `id`.
public struct Annahmenfeld: Sendable, Identifiable {
    /// Der Schlüssel des Dienstes, z. B. `stove_nominal_heat_kw` - und damit die `id`.
    ///
    /// **Das Wort taugt nicht als `id`.** „Ofen: davon ins Wasser" steht zweimal da (Volllast
    /// und Minimallast), und `Kennzahl`/`Kacheldaten` nehmen sonst `wort` als `id`. Ein `ForEach`
    /// über doppelte Kennungen zeichnet eine der beiden Zeilen nicht.
    public let schluessel: String
    public let wort: String
    /// Der kleine Satz unter dem Wort - wo die Zahl ohne ihn eine Behauptung wäre.
    public let hinweis: String?
    public let einheit: String
    /// Die Schrittweite der Vorlage. Dient nur noch der Rundung: ein `Stepper` wäre hier falsch,
    /// 450 €/t in Schritten von 1 sind 450 Antippen.
    public let schritt: Double
    /// Nachkommastellen der Anzeige, aus `schritt` abgeleitet und ausgeschrieben.
    public let stellen: Int
    /// Ob das Feld negativ werden darf. Nur der Aufstellraum des Puffers darf es
    /// (`schemas.py:935`: `gt=-20`) - und nur deshalb braucht seine Zeile eine Tastatur mit
    /// Minuszeichen, die der Zehnerblock für Dezimalzahlen nicht hat.
    public let darfNegativ: Bool
    /// Wo der Wert in der verschachtelten Konfiguration des Dienstes steht.
    public let lesen: @Sendable (HemsConfig) -> Double?
    /// Wohin er als flacher Schlüssel zurückgeht.
    public let schreiben: @Sendable (inout HeatConfigIn, Double) -> Void

    public var id: String { schluessel }

    public init(
        schluessel: String, wort: String, hinweis: String? = nil, einheit: String,
        schritt: Double, stellen: Int, darfNegativ: Bool = false,
        lesen: @escaping @Sendable (HemsConfig) -> Double?,
        schreiben: @escaping @Sendable (inout HeatConfigIn, Double) -> Void
    ) {
        self.schluessel = schluessel
        self.wort = wort
        self.hinweis = hinweis
        self.einheit = einheit
        self.schritt = schritt
        self.stellen = stellen
        self.darfNegativ = darfNegativ
        self.lesen = lesen
        self.schreiben = schreiben
    }
}

/// Die Annahmen der Wärmerechnung: die Feldtabelle, die Kennlinienzeile und die Sätze dazu.
///
/// **Warum die Seite überhaupt stellen können muss.** Es gibt keinen Wärmemengenzähler im Haus.
/// Jede Wärmemenge und jeder Euro dieser App sind gerechnet, und diese dreizehn Zahlen sind die
/// Eingangsgrößen der Rechnung. Sie stammen nicht aus der Regelung, sondern vom Lieferschein und
/// vom Datenblatt - der Hausherr kennt sie und muss sie nachtragen können, ohne eine Datei zu
/// bearbeiten und den Dienst neu zu starten. Der Schreibweg lag im Kern (`Api.stelleWaerme`,
/// `Netz/Api.swift:387`) und wurde von keiner Seite benutzt; die Methodenkarte verwies fürs
/// Ändern aufs Dashboard.
///
/// **Die Abbildung flach gegen verschachtelt ist der eigentliche Inhalt.** Gelesen wird aus drei
/// Gruppen (`HemsConfig.stove`, `.buffer`, `.heatDemand`), geschrieben werden dreizehn flache
/// Schlüssel (`HeatConfigIn`). Serverseitig macht das `HEAT_FIELD_MAP`
/// (`hems_core/domain/config.py:343-348`), in der App gibt es dafür keinen Generator. Von Hand
/// geschrieben übersetzt ein vertauschtes Paar - `stove_water_heat_kw` gegen
/// `stove_min_water_heat_kw`, beide heißen „Ofen: davon ins Wasser" - fehlerfrei und falsch.
/// Darum steht die Tabelle hier und nicht in der Ansicht: hier kommt sie unter einen Test.
///
/// **Keine Rechnung darüber hinaus.** Die Vorlage rechnet auf dieser Seite nichts. Sie prüft die
/// Lesbarkeit der Kennlinie und schickt den Rest an den Dienst.
public enum Annahmenfelder {

    // MARK: - Die dreizehn Felder

    /// Die dreizehn Annahmen in Sachreihenfolge: Ofen, dann Puffer, dann Haus.
    ///
    /// **Die Reihenfolge ist die Aussage.** Was die App zeigte, war alphabetisch sortiert, weil
    /// die Zeilen aus dem JSON-Schema fielen - „hw auto off block s 1200" vor „max starts per
    /// day 8". Hier steht zusammen, was zusammengehört, und die beiden „davon"-Zeilen stehen
    /// unter der Zeile, auf die sie sich beziehen.
    public static let alle: [Annahmenfeld] = [
        Annahmenfeld(
            schluessel: "stove_nominal_heat_kw", wort: "Ofen: Leistung bei Volllast",
            einheit: "kW", schritt: 0.1, stellen: 1,
            lesen: { $0.stove?.nominalHeatKw },
            schreiben: { patch, wert in patch.stoveNominalHeatKw = wert }),
        Annahmenfeld(
            schluessel: "stove_water_heat_kw", wort: "Ofen: davon ins Wasser",
            hinweis: "Der Rest heizt den Aufstellraum.", einheit: "kW", schritt: 0.1, stellen: 1,
            lesen: { $0.stove?.waterHeatKw },
            schreiben: { patch, wert in patch.stoveWaterHeatKw = wert }),
        Annahmenfeld(
            schluessel: "stove_min_heat_kw", wort: "Ofen: Leistung bei Minimallast",
            einheit: "kW", schritt: 0.1, stellen: 1,
            lesen: { $0.stove?.minHeatKw },
            schreiben: { patch, wert in patch.stoveMinHeatKw = wert }),
        Annahmenfeld(
            schluessel: "stove_min_water_heat_kw", wort: "Ofen: davon ins Wasser",
            einheit: "kW", schritt: 0.1, stellen: 1,
            lesen: { $0.stove?.minWaterHeatKw },
            schreiben: { patch, wert in patch.stoveMinWaterHeatKw = wert }),
        Annahmenfeld(
            schluessel: "stove_combustion_efficiency", wort: "Verbrennungswirkungsgrad",
            hinweis: "Datenblatt, Volllast. Bei Teillast ist er meist besser.",
            einheit: "0 bis 1", schritt: 0.001, stellen: 3,
            lesen: { $0.stove?.combustionEfficiency },
            schreiben: { patch, wert in patch.stoveCombustionEfficiency = wert }),
        Annahmenfeld(
            schluessel: "pellet_kwh_per_kg", wort: "Heizwert der Pellets",
            hinweis: "ENplus A1 liegt zwischen 4,9 und 5,3. Steht auf dem Lieferschein.",
            einheit: "kWh/kg", schritt: 0.01, stellen: 2,
            lesen: { $0.stove?.pelletKwhPerKg },
            schreiben: { patch, wert in patch.pelletKwhPerKg = wert }),
        Annahmenfeld(
            schluessel: "pellet_price_eur_per_t", wort: "Pelletpreis",
            einheit: "€/t", schritt: 1, stellen: 0,
            lesen: { $0.stove?.pelletPriceEurPerT },
            schreiben: { patch, wert in patch.pelletPriceEurPerT = wert }),
        Annahmenfeld(
            schluessel: "buffer_volume_liters", wort: "Puffervolumen",
            einheit: "l", schritt: 10, stellen: 0,
            lesen: { $0.buffer?.volumeLiters },
            schreiben: { patch, wert in patch.bufferVolumeLiters = wert }),
        Annahmenfeld(
            schluessel: "buffer_target_temperature_c", wort: "Zieltemperatur des Puffers",
            hinweis: "Zugleich der Vorlauf, bei dem die COP-Kennlinie gilt.",
            einheit: "°C", schritt: 1, stellen: 0,
            lesen: { $0.buffer?.targetTemperatureC },
            schreiben: { patch, wert in patch.bufferTargetTemperatureC = wert }),
        Annahmenfeld(
            schluessel: "buffer_loss_kw_per_k", wort: "Verlustbeiwert des Puffers",
            hinweis: "0,004 kW/K sind 4 Watt je Kelvin Übertemperatur.",
            einheit: "kW/K", schritt: 0.001, stellen: 3,
            lesen: { $0.buffer?.lossKwPerK },
            schreiben: { patch, wert in patch.bufferLossKwPerK = wert }),
        Annahmenfeld(
            schluessel: "buffer_ambient_c", wort: "Aufstellraum des Puffers",
            hinweis: """
                Nicht der Wohnraum: der Raum, in dem der Puffer wirklich steht. Unbeheizter \
                Technikraum 15 bis 18, Keller 10 bis 14. Eine Annahme, bis dort ein Fühler hängt.
                """,
            einheit: "°C", schritt: 0.5, stellen: 1, darfNegativ: true,
            lesen: { $0.buffer?.ambientC },
            schreiben: { patch, wert in patch.bufferAmbientC = wert }),
        Annahmenfeld(
            schluessel: "buffer_loss_useful_fraction", wort: "davon nutzbar fürs Haus",
            hinweis: """
                Liegt der Raum in der beheizten Hülle, heizt sein Verlust mit. 0 heißt ganz \
                verloren, 1 heißt voll nutzbar.
                """,
            einheit: "0 bis 1", schritt: 0.05, stellen: 2,
            lesen: { $0.buffer?.lossUsefulFraction },
            schreiben: { patch, wert in patch.bufferLossUsefulFraction = wert }),
        Annahmenfeld(
            schluessel: "indoor_target_c", wort: "Raumtemperatur des Hauses",
            hinweis: """
                Für den Heizbedarf aus Heizgradstunden. Auf den Pufferverlust wirkt sie nicht mehr.
                """,
            einheit: "°C", schritt: 0.5, stellen: 1,
            lesen: { $0.heatDemand?.indoorTargetC },
            schreiben: { patch, wert in patch.indoorTargetC = wert }),
    ]

    // MARK: - Zwei Spalten

    /// Die Felder auf zwei Spalten, geteilt bei `ceil(n/2)` - 13 werden 7 und 6.
    ///
    /// **Gerechnet und nicht bei einer festen Zahl getrennt.** Die Begründung steht in der
    /// Vorlage (`HeatSettings.tsx:45-47`): „mit jedem neuen Feld stand sonst eine Spalte laenger
    /// da als die andere." Es sind immer genau zwei Listen, auch wenn die zweite leer bleibt -
    /// so muss die Ansicht keinen Sonderfall kennen.
    public static func spalten(_ felder: [Annahmenfeld] = alle) -> [[Annahmenfeld]] {
        let halb = Int((Double(felder.count) / 2).rounded(.up))
        return [Array(felder.prefix(halb)), Array(felder.dropFirst(halb))]
    }

    // MARK: - Der Entwurf

    /// Was in den dreizehn Feldern steht, wenn die Konfiguration des Dienstes frisch da ist.
    ///
    /// **Deutsch geschrieben, nicht roh.** Die Vorlage setzt `String(zahl)` ins Feld, also
    /// „0.911" - an einem Browser mit `<input type=number>` ist das richtig. Hier tippt jemand
    /// auf einer deutschen Tastatur weiter, und „0.911" wäre dort eine Zumutung. Darum
    /// `Formate.zahl` mit den Stellen des Feldes, und `Formate.zahlAusText` liest es zurück.
    ///
    /// **Fehlt ein Wert, bleibt das Feld leer** und nicht `Formate.leer`: ein Strich ist die
    /// Schreibweise einer fehlenden Messung in einer Anzeige, in einem Eingabefeld wäre er
    /// etwas, das jemand löschen muss, bevor er tippen kann.
    public static func entwuerfe(_ cfg: HemsConfig) -> [String: String] {
        var aus: [String: String] = [:]
        for feld in alle {
            aus[feld.schluessel] = entwurf(feld, cfg)
        }
        return aus
    }

    /// Der Text eines einzelnen Feldes aus der Konfiguration - leer, wenn der Dienst ihn nicht hat.
    public static func entwurf(_ feld: Annahmenfeld, _ cfg: HemsConfig) -> String {
        guard let wert = feld.lesen(cfg), wert.isFinite else { return "" }
        return Formate.zahl(wert, stellen: feld.stellen)
    }

    /// Ob ein Feld geändert, aber noch nicht übernommen ist - die Ansicht färbt es dann bernstein.
    ///
    /// Verglichen werden die Zahlen auf die Stellen des Feldes gerundet und nicht die Texte:
    /// „11,90" und „11,9" sind dieselbe Annahme, und eine bernsteinfarbene Zeile, die nichts
    /// ändert, ist eine Lüge. Was nicht lesbar ist - leer, ein Strich, halb getippt -, gilt als
    /// unverändert, denn es geht auch nicht an den Dienst.
    public static func abweichend(_ feld: Annahmenfeld, entwurf: String, gegen cfg: HemsConfig?)
        -> Bool
    {
        guard let getippt = Formate.zahlAusText(entwurf) else { return false }
        guard let cfg, let steht = feld.lesen(cfg), steht.isFinite else { return true }
        return gerundet(getippt, stellen: feld.stellen) != gerundet(steht, stellen: feld.stellen)
    }

    private static func gerundet(_ wert: Double, stellen: Int) -> Double {
        let faktor = pow(10.0, Double(stellen))
        return (wert * faktor).rounded() / faktor
    }

    // MARK: - Die Kennlinie als Zeile

    /// Die COP-Kennlinie als Textzeile: „-7:2.4, 2:3, 7:3.5, 15:4.2". Kürzer als elf Felder.
    ///
    /// **Rohe Zahlen mit Punkt, kein `Formate.zahl`.** Das ist die einzige Stelle dieser App, an
    /// der eine Zahl nicht deutsch geschrieben wird, und das mit Absicht: dieser Text wird wieder
    /// gelesen. „2:3,00" hätte das Komma als Dezimaltrennzeichen **und** als Stützpunkttrenner,
    /// und ein Feld, dessen Ausgabe die eigene Eingabe nicht übersteht, ist eine Falle. Nachstehende
    /// Nullen fallen weg, damit aus 3,0 „3" wird und nicht „3.0" - wortgleich mit der Vorlage
    /// (`HeatSettings.tsx:51-53`).
    ///
    /// Paare, die nicht zwei endliche Zahlen sind, fallen weg; eine leere Kennlinie wird eine
    /// leere Zeile.
    public static func kurveZuText(_ kurve: [[Double]]) -> String {
        kurve
            .compactMap { paar -> String? in
                guard paar.count == 2, paar.allSatisfy(\.isFinite) else { return nil }
                return "\(rohzahl(paar[0])):\(rohzahl(paar[1]))"
            }
            .joined(separator: ", ")
    }

    /// Die Kennlinie aus der getippten Zeile - oder `nil`, wenn sie so nicht zu lesen ist.
    ///
    /// Getrennt wird an Komma und Semikolon, gespalten an dem Doppelpunkt; jedes Stück muss genau
    /// zwei endliche Zahlen sein, sonst ist die ganze Zeile unlesbar und es geht nichts an den
    /// Dienst. **Komma und Punkt gelten beide**, denn eine deutsche Tastatur liefert das Komma,
    /// und dieselbe Zeile kommt mit Punkt aus `kurveZuText` zurück.
    ///
    /// **Aufsteigend wird hier nicht geprüft.** Das tut der Dienst (`schemas.py`, `_kennlinie`),
    /// und zwar mit der Begründung, die die Oberfläche nicht kennt: eine Kennlinie mit einem
    /// Punkt ist eine Konstante, eine mit Sprüngen eine Falle.
    public static func textZuKurve(_ text: String) -> [[Double]]? {
        let stuecke = text
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !stuecke.isEmpty else { return nil }
        var kurve: [[Double]] = []
        for stueck in stuecke {
            let teile = stueck.split(separator: ":", omittingEmptySubsequences: false)
            guard teile.count == 2,
                let t = Formate.zahlAusText(String(teile[0])),
                let cop = Formate.zahlAusText(String(teile[1]))
            else { return nil }
            kurve.append([t, cop])
        }
        return kurve
    }

    /// Eine Zahl so, wie eine Maschine sie wieder lesen kann: Punkt, kein nachstehendes „,0".
    static func rohzahl(_ wert: Double) -> String {
        let text = String(wert)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    // MARK: - Was an den Dienst geht

    /// Das Ergebnis des Knopfs „Übernehmen", bevor irgendetwas geschickt wurde.
    ///
    /// **Eine Aufzählung und kein `HeatConfigIn?`.** „Nichts zu schicken" und „die Kennlinie ist
    /// unlesbar" sind zwei verschiedene Nachrichten an den Nutzer, und ein `nil` wäre beides.
    public enum Abgabe: Sendable, Hashable {
        /// So geht es an `Api.stelleWaerme`.
        case bereit(HeatConfigIn)
        /// Die Kennlinienzeile ist nicht zu lesen - geprüft ohne Anfrage, wie in der Vorlage.
        case kennlinieUnlesbar
    }

    /// Aus den getippten Texten den Patch für `POST /config/heat` bauen.
    ///
    /// **Geschickt wird, was lesbar dasteht.** Jedes Feld von `HeatConfigIn` ist wahlfrei und der
    /// Encoder lässt `nil` weg; ein leeres oder halb getipptes Feld bleibt damit stehen, wie es
    /// beim Dienst steht. Die Kennlinie geht immer mit, weil sie als Ganzes ersetzt wird - ein
    /// weggelassener Stützpunkt wäre sonst ein gelöschter.
    ///
    /// **Grenzen prüft hier nichts.** Ein Heizwert von 99 kWh/kg wandert in den Patch und wird
    /// vom Dienst abgelehnt, mit seinem Satz. Das ist die Entscheidung der Vorlage
    /// (`HeatSettings.tsx:145-148`): seine Begründung ist genauer als alles, was die Oberfläche
    /// sagen könnte, und zwei Prüfungen laufen auseinander.
    public static func abgabe(entwuerfe: [String: String], kennlinie: String) -> Abgabe {
        guard let kurve = textZuKurve(kennlinie) else { return .kennlinieUnlesbar }
        var patch = HeatConfigIn(copCurve: kurve)
        for feld in alle {
            guard let text = entwuerfe[feld.schluessel],
                let wert = Formate.zahlAusText(text)
            else { continue }
            feld.schreiben(&patch, wert)
        }
        return .bereit(patch)
    }

    // MARK: - Die Sätze der Seite

    /// Über der Seite: woraus diese Zahlen stammen (`waerme/annahmen/page.tsx:13`).
    public static let kicker = "Lieferschein · Datenblatt · Puffer"

    /// Der Absatz über dem Formular (`waerme/annahmen/page.tsx:15-20`), wörtlich.
    ///
    /// Ohne ihn steht eine Zahlenliste ohne Begründung da - und der erste Satz ist der Grund,
    /// warum es die ganze Seite gibt.
    public static let einleitung = """
        Es gibt keinen Wärmemengenzähler im Haus. Die Wärmebilanz wird deshalb gerechnet, und \
        diese Zahlen sind die Annahmen dahinter: was auf dem Lieferschein der Pellets steht, was \
        im Datenblatt des Ofens steht, wie warm der Puffer gefahren wird. Jede Änderung wirkt \
        sofort und rückwirkend, weil Messwerte gespeichert sind und keine Rechenergebnisse.
        """

    /// Die Überschrift der Kennlinienzeile (`HeatSettings.tsx:176`).
    public static let kennlinienTitel = "COP-Kennlinie über der Außentemperatur"

    /// Wie die Kennlinie geschrieben wird und was sie nicht ist (`HeatSettings.tsx:177-182`).
    public static let kennlinienErklaerung = """
        Stützpunkte als Temperatur:COP, aufsteigend, mit Komma getrennt. Sie gilt bei der \
        Zieltemperatur des Puffers; auf den wirklichen Vorlauf wird über das Verhältnis der \
        Carnot-Zahlen umgerechnet. Ein zweidimensionales Kennfeld ist das nicht, und es wäre auch \
        keines: dafür müsste jede Stützstelle gemessen sein.
        """

    /// Der Knopf (`HeatSettings.tsx:198`).
    public static let knopf = "Übernehmen"
    /// Derselbe Knopf, während geschickt wird.
    public static let knopfLaeuft = "wird übernommen …"

    /// Nach dem Übernehmen (`HeatSettings.tsx:150-153`), wörtlich.
    ///
    /// **Der Fahrplan gehört in diesen Satz.** Er wird nicht bei jeder Abfrage gerechnet, sondern
    /// im Takt; der Dienst macht ihn nach dieser Änderung fällig, und bis der Löser durch ist,
    /// steht auf der Fahrplanseite noch der alte. Ohne den Hinweis sieht das aus wie
    /// Wirkungslosigkeit.
    public static let uebernommenSatz = """
        Übernommen. Die Auswertungen rechnen ab sofort damit, auch rückwirkend; der Fahrplan wird \
        neu gerechnet und steht in wenigen Sekunden auf der Seite „Fahrplan“.
        """

    /// Wenn die Kennlinienzeile nicht zu lesen ist (`HeatSettings.tsx:143`).
    public static let kennlinienFehler =
        "Die Kennlinie wird als Temperatur:COP geschrieben, Stützpunkte mit Komma getrennt."

    /// Wenn die Konfiguration nicht kommt (`HeatSettings.tsx:130`).
    public static let ladefehler = "Die Konfiguration konnte nicht geladen werden."

    /// Nur als Ersatz, wenn der Dienst keinen eigenen Satz liefert (`HeatSettings.tsx:156`).
    ///
    /// Sonst steht hier `ApiFehler.rat` unverändert: der Dienst prüft Widersprüche, die ein
    /// einzelnes Feld nicht sehen kann.
    public static let aenderungAbgelehnt = "Die Änderung wurde nicht übernommen."

    /// Die zwei Sätze der Methodenkarte - in der Vorlage stehen sie im Quelltext
    /// (`HeatSettings.tsx:7-20`), hier sind sie der Inhalt der zugeklappten Karte.
    public static let methodensaetze = [
        """
        Diese Werte stammen nicht aus der Regelung, sondern vom Gerät und vom Lieferschein: was \
        auf dem Sack Pellets steht, was das Datenblatt des Ofens nennt, wie warm der Puffer \
        gefahren wird. Das sind Zahlen, die der Hausherr kennt und nachtragen können muss, ohne \
        eine Datei zu bearbeiten und den Dienst neu zu starten. Regelparameter bleiben draußen; \
        eine falsche Zahl dort fällt beim Start auf und nicht nachts.
        """,
        """
        Jede Änderung wirkt rückwirkend. Gespeichert sind Messwerte und keine Rechenergebnisse, \
        die Auswertung rechnet bei jeder Abfrage neu. Ein korrigierter Heizwert verändert deshalb \
        auch die Jahreszahlen von letztem Jahr. Das ist der Zweck: eine Annahme, die nur nach \
        vorn wirkt, lässt die Vergangenheit falsch stehen, ohne dass es jemandem auffällt.
        """,
    ]

    /// Ein Stück eines Absatzes: Text oder ein Verweis auf eine andere Seite.
    ///
    /// **Warum eine Aufzählung und kein zusammengebauter Text.** Der Schlussabsatz hat einen
    /// Verweis mitten im Satz. Zwei Hälften als zwei Zeichenketten wären an jeder Fuge
    /// nachzurechnen, und eine Auszeichnungssprache im Kern hieße, sie in der Ansicht wieder
    /// zu zerlegen.
    public enum Textstueck: Sendable, Hashable, Identifiable {
        case satz(String)
        case verweis(wort: String, weg: String)

        public var id: String {
            switch self {
            case .satz(let s): return "satz:" + s
            case .verweis(let wort, let weg): return "verweis:" + wort + ":" + weg
            }
        }
    }

    /// Der Schlussabsatz (`waerme/annahmen/page.tsx:22-26`), wörtlich.
    ///
    /// Der einzige Satz, der sagt, woran man merkt, ob die Annahmen stimmen: die Zeile „nicht
    /// zuzuordnen" der Wärmebilanz klein zu bekommen ist der Sinn dieser Felder.
    public static let schlussabsatz: [Textstueck] = [
        .satz("Ob die Zahlen stimmen, steht auf der "),
        .verweis(wort: "Wärmebilanz", weg: "/waerme/bilanz"),
        .satz("""
            : dort gibt es die Zeile „nicht zuzuordnen“. Was die Erzeuger nicht erklären, landet \
            in ihr, und sie klein zu bekommen ist genau der Sinn dieser Felder.
            """),
    ]

    // MARK: - Abmessungen der Vorlage

    /// Die Maße des Formulars, wie die Vorlage sie setzt.
    ///
    /// **Warum Zahlen und keine `Font`/`Color`.** Dasselbe Argument wie bei `Marken`: dieses
    /// Paket kennt kein SwiftUI. Benannt stehen sie hier, damit in der Ansicht keine 108 ohne
    /// Herkunft klebt - die Breite ist nicht Geschmack, sondern der Grund, warum die Einheiten
    /// untereinander stehen.
    public enum Abmessungen {
        /// Breite des Zahlenfeldes (`HeatSettings.tsx:78`, `w-[108px]`).
        public static let feldbreite: Double = 108
        /// Breite der Einheitenspalte (`HeatSettings.tsx:81`, `w-[52px]`) - fest, damit die
        /// Einheiten eine Spalte bilden und nicht an den Zahlen kleben.
        public static let einheitenbreite: Double = 52
        /// Abstand der beiden Spalten (`HeatSettings.tsx:162`, `gap-x-8`).
        public static let spaltenabstand: Double = 32
        /// Abstand zwischen Feldblock, Kennlinie und Knopfzeile (`HeatSettings.tsx:160`, `gap-3`).
        public static let blockabstand: Double = 12
        /// Die Seite wird nicht breiter, auch an der Wand (`page.tsx:14`, `max-w-[980px]`).
        public static let hoechstbreite: Double = 980
    }
}

// MARK: - Getippte Zahlen lesen

extension Formate {
    /// Eine getippte Zahl lesen - deutsch oder englisch geschrieben.
    ///
    /// **Das Gegenstück zu `zahl`, und es fehlte.** Die App hatte bis hierher kein Eingabefeld
    /// für eine Zahl, also auch keine Stelle, die einen getippten Zahlentext liest. Eine deutsche
    /// Tastatur liefert „0,911", und `Double("0,911")` ist `nil`: ohne diese Funktion verschluckt
    /// jedes Feld stillschweigend jede Eingabe mit Komma.
    ///
    /// Angenommen werden beide Dezimaltrennzeichen, das echte Minuszeichen U+2212, das `zahl`
    /// selbst schreibt, und das schmale Leerzeichen, das aus einer Anzeige mitkopiert wird.
    /// `nil` heißt: hier steht keine Zahl - auch bei `inf` und `nan`, denn nichts davon ist eine
    /// Annahme über ein Haus.
    public static func zahlAusText(_ text: String) -> Double? {
        var roh = text
        for weg in [" ", "\u{202F}", "\u{00A0}", "\u{2009}"] {
            roh = roh.replacingOccurrences(of: weg, with: "")
        }
        for strich in [minus, "\u{2013}", "\u{2014}"] {
            roh = roh.replacingOccurrences(of: strich, with: "-")
        }
        roh = roh.replacingOccurrences(of: ",", with: ".")
        guard let wert = Double(roh), wert.isFinite else { return nil }
        return wert
    }
}
