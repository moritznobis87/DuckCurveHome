import Foundation

/// Beispieldaten für die Nachbetrachtung: ein Tag, an dem alles schiefging, was schiefgehen kann.
///
/// **Warum in einer eigenen Datei und nicht in ``Vorschau``.** Die Antwort der Nachbetrachtung
/// hat fünf Linien mit je vier Reihen über 96 Viertelstunden; von Hand geschrieben wären das
/// zweitausend Zahlen. Sie werden darum gerechnet, und eine gerechnete Vorschau ist lang genug
/// für ein eigenes Blatt - ``Vorschau`` trägt schon dreißig Bausteine.
///
/// **Die Zahlen sind nicht beliebig.** Es ist ein Tag, an dem der erste Fahrplan die Mittagssonne
/// einplante, die Wärmepumpe aber am Morgen lief: so liegen die Streifen gegeneinander versetzt,
/// die Kurven laufen auseinander, und beides sieht man in der Vorschau. Zwei Stunden am Abend
/// sind nicht verglichen, damit der Schleier dasteht, und die Linie „versprochen“ fehlt mit
/// Grund, damit die Liste der fehlenden Linien nicht leer ist.
extension Vorschau {

    /// Der Tag, auf den sich die Nachbetrachtung bezieht.
    public static let nachbetrachtungstag = "2026-11-07"

    public static func nachbetrachtung() -> NachbetrachtungOut {
        let anfang = Zeit.ausIso("\(nachbetrachtungstag)T00:00:00+01:00")!
        let schritt = 15
        let anzahl = 96
        let zeiten = (0..<anzahl).map { Zeit.iso(anfang.addingTimeInterval(Double($0 * schritt * 60))) }
        // Die letzten zwei Stunden sind nicht verglichen: dort fehlt die Messung.
        let verglichen = (0..<anzahl).map { $0 < 88 }

        // Ein Wintertag: teuer am Morgen und am Abend, billig um die Mittagssonne.
        let preis: [Double?] = (0..<anzahl).map { i in
            let stunde = Double(i) / 4
            return 28 - 16 * cos((stunde - 13) / 24 * 2 * Double.pi)
        }
        let sonne: [Double?] = (0..<anzahl).map { i in
            let stunde = Double(i) / 4
            guard stunde > 8.5, stunde < 16.5 else { return 0 }
            return 3.4 * sin((stunde - 8.5) / 8 * Double.pi)
        }

        /// Eine Linie mit einem Laufband: `an` sagt je Viertelstunde, ob gezogen wird.
        func linie(
            _ key: String, kw: Double, ofen: Bool = false,
            an: (Int) -> Double
        ) -> Linie {
            var kwhJe: [Double?] = []
            var eurJe: [Double?] = []
            var kumuliert: [Double?] = []
            var ofenJe: [Double?] = []
            var summe = 0.0
            var arbeit = 0.0
            var stunden = 0.0
            for i in 0..<anzahl {
                guard verglichen[i] else {
                    kwhJe.append(nil)
                    eurJe.append(nil)
                    kumuliert.append(nil)
                    ofenJe.append(nil)
                    continue
                }
                let anteil = an(i)
                let kwh = kw * 0.25 * anteil
                let eur = kwh * (preis[i] ?? 0) / 100
                summe += eur
                arbeit += kwh
                stunden += 0.25 * anteil
                kwhJe.append(kwh)
                eurJe.append(eur)
                kumuliert.append(summe)
                ofenJe.append(ofen && anteil > 0.5 ? 1 : 0)
            }
            return Linie(
                key: key, nameDe: Nachbetrachtungsworte.lang[key] ?? key, verfuegbar: true,
                geschaetzt: key == "perfekt", eur: summe, stromEur: summe,
                ofenEur: ofen ? summe * 0.2 : 0, wpKwh: arbeit,
                ctJeKwh: arbeit > 0 ? summe / arbeit * 100 : nil, wpH: stunden,
                ofenH: ofen ? stunden * 0.4 : 0, wpKwhJe: kwhJe, ofenJe: ofenJe, eurJe: eurJe,
                eurKumuliert: kumuliert)
        }

        // Geplant war der Mittag, gelaufen ist der Morgen - das ist der Tag in einem Satz.
        let mittag: (Int) -> Double = { i in (i >= 44 && i < 60) ? 1 : 0 }
        let morgen: (Int) -> Double = { i in (i >= 20 && i < 38) ? 1 : 0 }
        let nacht: (Int) -> Double = { i in (i >= 8 && i < 24) ? 1 : 0 }

        let linien: [Linie] = [
            Linie(
                key: "versprochen", nameDe: "versprochen", verfuegbar: false,
                grundDe: "Der erste Fahrplan dieses Tages wurde noch nicht aufbewahrt.",
                geschaetzt: false),
            linie("erster", kw: 4.5, an: mittag),
            linie("letzter", kw: 4.5, an: mittag),
            linie("wirklich", kw: 4.5, ofen: true, an: morgen),
            linie("perfekt", kw: 4.5, an: nacht),
        ]
        // Die Abstände rechnet der Dienst; hier aus den Linien, damit die Treppe aufgeht.
        func eur(_ key: String) -> Double? { linien.first { $0.key == key }?.eur }
        let abstaende: [Abstand] = [
            Abstand(
                key: "prognosefehler", nameDe: "Prognosefehler", von: "versprochen",
                nach: "erster", eur: nil,
                satzDe: nil),
            Abstand(
                key: "nachfuehren", nameDe: "Nachführen über den Tag", von: "erster",
                nach: "letzter", eur: (eur("letzter") ?? 0) - (eur("erster") ?? 0),
                satzDe: "Der Fahrplan wurde über den Tag nachgeführt; an den Kosten änderte das "
                    + "nichts.", mengeEur: 0, zeitEur: 0),
            Abstand(
                key: "eingriff", nameDe: "Eingriff der Maschine", von: "letzter",
                nach: "wirklich", eur: (eur("wirklich") ?? 0) - (eur("letzter") ?? 0),
                satzDe: "Die Wärmepumpe lief am Morgen statt am Mittag - das kostete den "
                    + "Unterschied zwischen zwei Preisen.",
                mengeEur: 0.12, zeitEur: 1.84, ofenEur: 0.31),
            Abstand(
                key: "voraussicht", nameDe: "perfekte Voraussicht", von: "perfekt",
                nach: "letzter", eur: (eur("letzter") ?? 0) - (eur("perfekt") ?? 0),
                satzDe: "Mit perfekter Voraussicht wäre die Nacht billiger gewesen."),
        ]

        return NachbetrachtungOut(
            zeiten: zeiten, schrittMin: schritt, verglichen: verglichen,
            nVerglichen: verglichen.filter { $0 }.count, preisCt: preis, ueberschussKw: sonne,
            linien: linien, abstaende: abstaende, standbyKwh: 1.8, standbyEur: 0.44,
            ersterPlanErstellt: "\(nachbetrachtungstag)T00:07:00+01:00",
            satzDe: "Der Tag kostete 2,27 € mehr als der Fahrplan versprach, und fast alles "
                + "davon lag daran, dass die Wärmepumpe am Morgen lief statt am Mittag.",
            hinweiseDe: [
                "Der Tag läuft noch – die Zahlen sind vorläufig.",
                "Die letzten zwei Stunden sind nicht verglichen: dort fehlt die Messung.",
                "Die Linie „versprochen“ fehlt: der erste Fahrplan wurde nicht aufbewahrt.",
            ],
            methodeDe: [
                "Jede Linie wird mit derselben Rechnung über dieselben Viertelstunden bewertet.",
                "Überschuss geht zur Einspeisevergütung, der Rest zum Bezugspreis.",
                "Die perfekte Voraussicht ist ein Vergleichslauf und kein erreichbarer Plan.",
            ],
            day: nachbetrachtungstag, von: zeiten.first ?? "",
            bis: Zeit.iso(anfang.addingTimeInterval(24 * 3600)), laeuftNoch: true, wpKw: 4.5,
            verguetungCt: 8.2, hatOfen: true,
            verschiebenEur: 1.12,
            verschiebenDe: "Das Verschieben in billige Stunden brachte an diesem Tag 1,12 €.")
    }
}
