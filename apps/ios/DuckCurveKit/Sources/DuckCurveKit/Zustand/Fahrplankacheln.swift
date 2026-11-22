import Foundation

/// Die sieben Zahlen über dem Fahrplan.
///
/// **Was in der App stand.** Vier Kacheln: erwartete Sonne, die Zahl der geplanten *Läufe*,
/// das nächste Preistief und die Puffergröße. Die Vorlage
/// (`apps/web/src/components/waerme/Fahrplan.tsx`) zeigt sieben andere, und sie sind die Frage
/// der Seite: wie lange die Pumpe **angefordert** ist, wie lange sie wirklich **gelaufen** ist,
/// wie viel bewusst gemieden wurde, was der Ofen soll, wie viel Wärme geplant ist, welche
/// Arbeitszahlen und welche Preise im Horizont stehen.
///
/// **Die Zahl der Läufe war die falsche Zahl.** Drei Läufe können zwanzig Minuten oder acht
/// Stunden sein. Die Stunden sind das, was man der gemessenen Laufzeit gegenüberstellen kann.
public enum Fahrplankacheln {

    /// Viertelstunden als Stunden: „6,0 h".
    public static func viertelstunden(_ anzahl: Int) -> String {
        "\(Formate.zahl(Double(anzahl) / 4, stellen: 1)) h"
    }

    public static func kacheln(_ plan: PlanOut?) -> [Kennzahl] {
        let iv = plan?.intervals ?? []
        let preise = iv.compactMap(\.priceCtKwh)
        let cops = iv.compactMap(\.cop)
        // Viertelstunden in Stunden: die Leistungen stehen je Viertelstunde, die Summe ist Arbeit.
        let waerme = iv.filter { $0.heatDemandKw != nil }
            .reduce(0.0) { $0 + ($1.heatDemandKw ?? 0) + ($1.dhwDemandKw ?? 0) }

        // Gelaufen heißt: die Maschine zog Strom, nicht: der Kontakt war zu. Genau der
        // Unterschied ist die offene Frage der Wärmeseite - K1 fordert an, die Maschine
        // entscheidet. Gezählt wird im Dienst, in Minuten, gegen die Schwelle der Anlage.
        let mitMessung = iv.filter { $0.actualHpRunMin != nil }
        let laufMinuten = mitMessung.reduce(0.0) { $0 + ($1.actualHpRunMin ?? 0) }
        // Beide Zahlen über denselben Zeitraum: „angefordert" zählt den ganzen Horizont, die
        // Messung reicht nur bis jetzt. Die Gegenzahl zählt deshalb nur die Viertelstunden,
        // für die es auch eine Messung gibt.
        let geplantImSelbenFenster = mitMessung.filter { $0.plannedHpState == .release }.count

        let ofenfahrplan = iv.contains { $0.plannedStoveOn != nil }
        let ofenviertel = iv.filter { $0.plannedStoveOn == true }.count

        return [
            Kennzahl(
                wort: "Wärmepumpe angefordert",
                wert: viertelstunden(iv.filter { $0.plannedHpState == .release }.count),
                einheit: nil,
                dazu: plan?.hpActuation == true
                    ? "im ganzen Horizont · Duck Curve fordert selbst an"
                    : "im ganzen Horizont · wird nur beobachtet, nicht geschaltet",
                // Alarmrot, nicht das Wärmepumpenbraun: die Vorlage setzt `tone="ember"`
                // (`Fahrplan.tsx:551-554`), und `Stat.tsx:5` führt `ember` auf `var(--alert)`
                // #E0533D (`tokens.css:64`). Bis es ``Kennzahl/Ton/alarm`` gab, stand hier
                // `glut` #E0966B - dort steht, warum das die falsche Farbe war.
                ton: .alarm),
            Kennzahl(
                wort: "Wärmepumpe gelaufen",
                wert: mitMessung.isEmpty
                    ? Formate.leer : "\(Formate.zahl(laufMinuten / 60, stellen: 1)) h",
                einheit: nil,
                dazu: mitMessung.isEmpty
                    ? "keine Messung"
                    : "seit Mitternacht · im selben Fenster geplant \(viertelstunden(geplantImSelbenFenster))",
                ton: .bernstein),
            Kennzahl(
                wort: "bewusst gemieden",
                wert: viertelstunden(iv.filter { $0.plannedHpState == .avoid }.count),
                einheit: nil, dazu: "teure Stunden ohne Anforderung", ton: .gedaempft),
            // Null Ofenstunden sind eine Entscheidung, kein fehlender Fahrplan: die Kachel muss
            // beides unterscheiden, sonst leuchtet sie „0,0 h · Volllast, 15 kg je Füllung".
            Kennzahl(
                wort: "Ofen geplant",
                wert: ofenfahrplan ? viertelstunden(ofenviertel) : Formate.leer,
                einheit: nil,
                dazu: !ofenfahrplan
                    ? "kein Fahrplan für den Ofen"
                    : (ofenviertel > 0
                        ? "Volllast, 15 kg je Füllung" : "nicht eingeplant, Begründung unten"),
                // Derselbe `ember` der Vorlage, aber nur wenn der Ofen brennt
                // (`Fahrplan.tsx:559-562`: `tone={kennzahlen.ofenViertel ? "ember" : "muted"}`).
                ton: ofenviertel > 0 ? .alarm : .gedaempft),
            Kennzahl(
                wort: "Wärmebedarf geplant",
                wert: waerme > 0 ? Formate.zahl(waerme / 4, stellen: 0) : Formate.leer,
                einheit: "kWh",
                dazu: waerme > 0 ? "Modell v1, nicht gemessen" : "kein Fahrplan", ton: .nebel),
            Kennzahl(
                wort: "COP im Horizont",
                wert: spanne(cops, stellen: 1), einheit: nil, dazu: "aus der Außentemperatur",
                ton: .nebel),
            Kennzahl(
                wort: "Preisspanne", wert: spanne(preise, stellen: 0), einheit: "ct",
                dazu: "im Horizont", ton: .bernstein),
        ]
    }

    /// „2,4 bis 3,8" - der kleinste bis zum größten Wert.
    static func spanne(_ werte: [Double], stellen: Int) -> String {
        guard let klein = werte.min(), let gross = werte.max() else { return Formate.leer }
        return "\(Formate.zahl(klein, stellen: stellen)) bis \(Formate.zahl(gross, stellen: stellen))"
    }
}
