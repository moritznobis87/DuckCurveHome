import Foundation

/// Die Worte des Rückblicks: Kartenköpfe, Lesehilfe, Fehlersatz - und wie viele Spalten er hat.
///
/// **Warum ein eigener Abschnitt und nicht ``Prognosebild``.** ``Prognosebild`` rechnet an der
/// Bewertung (`GET /forecast/evaluation`): Kacheln, Tageskurve, Faktoren, Horizonte. Der
/// Rückblick ist die **zweite** Abfrage derselben Seite (`GET /forecast/history`,
/// `Rueckblick.tsx:139`), mit eigenem Takt, eigenem Fehler und eigenem Zustand. Was er sagt,
/// hängt an `ForecastHistoryOut` und nicht an `ForecastEvaluationOut` - und jede Zeile davon ist
/// eine Auswahl zwischen zwei Sätzen und darum prüfbar.
///
/// **Es sind Worte, und Worte sind Rechnungen.** „96 Paare · Bias +0,12 kW“ oder „14 Läufe, keine
/// Paare" - welcher der beiden Sätze dasteht, entscheidet über die Auskunft der ganzen Karte, und
/// die Vorlage entscheidet es an `gesamt.n` (`Rueckblick.tsx:189-191`). Stünde das in einer
/// `View`, wäre es nicht geprüft.
extension Prognosebild {

    public enum Rueckblick {

        // MARK: - Der Kopf einer Reihenkarte

        /// „PV-Leistung · kW“ - der Name der Reihe mit ihrer Einheit (`Rueckblick.tsx:187`).
        ///
        /// **Die Einheit gehört in den Kopf und nicht nur in die rechte Zeile.** Dort nennt sie
        /// nur der Satz mit den Paaren (``kopfrechts(_:)``); hat eine Reihe keine Paare, stünde
        /// sie sonst nirgends - und die Säulen einer Reihe ohne Einheit sind Zahlen ohne Maß.
        /// Zwei Reihen mit zwei Einheiten (kW und Kelvin) liegen auf dieser Seite nebeneinander.
        public static func kopfkicker(_ reihe: ReiheOut) -> String {
            "\(reihe.labelDe) · \(reihe.einheit)"
        }

        /// „96 Paare · Bias +0,12 kW“ - oder, wenn es keine gibt, wie viele Läufe trotzdem
        /// dalagen.
        ///
        /// **Die Zahl der Läufe ohne Paare ist die wichtigere Auskunft von beiden.** Sie trennt
        /// „der Dienst legt nichts ab“ von „er legt ab, findet aber kein Ist dazu“
        /// (`Rueckblick.tsx:189-191`).
        ///
        /// Das Plus steht nur über null, wie in der Vorlage; das Minus kommt aus
        /// ``Formate/zahl(_:stellen:)`` und ist das echte U+2212.
        public static func kopfrechts(_ reihe: ReiheOut) -> String {
            let gesamt = reihe.gesamt
            if gesamt.n == 0 { return "\(reihe.laeufe) Läufe, keine Paare" }
            let vorzeichen = gesamt.bias > 0 ? "+" : ""
            return "\(gesamt.n) Paare · Bias \(vorzeichen)"
                + "\(Formate.zahl(gesamt.bias, stellen: 2)) \(reihe.einheit)"
        }

        // MARK: - Die Lesehilfe

        /// „7 Tage · 184 Läufe im Bestand“ - und `nil`, solange keine Antwort da ist.
        ///
        /// **Ohne Antwort kein Satz.** Die Vorlage setzt die rechte Zeile nur, wenn `data`
        /// steht (`Rueckblick.tsx:203`): „7 Tage · 0 Läufe im Bestand“ wäre eine Aussage über
        /// den Bestand, und sie wäre falsch - es ist eine Aussage über die Leitung.
        public static func lesehilfeRechts(_ verlauf: ForecastHistoryOut?) -> String? {
            guard let verlauf else { return nil }
            return "\(verlauf.tage) Tage · \(laeufe(verlauf)) Läufe im Bestand"
        }

        /// Die Läufe im Bestand: die größte Zahl über alle Reihen.
        ///
        /// Jede Reihe zählt ihre eigenen; „im Bestand“ meint den Bestand und nicht die Reihe,
        /// und eine Summe wäre falsch - es sind dieselben Läufe. Die Vorlage nimmt dafür
        /// `reihen[0]` (`Rueckblick.tsx:203`); das ist dieselbe Zahl, solange die erste Reihe
        /// existiert, und keine, wenn der Dienst die Reihen einmal anders ordnet.
        public static func laeufe(_ verlauf: ForecastHistoryOut?) -> Int {
            verlauf?.reihen.map(\.laeufe).max() ?? 0
        }

        // MARK: - Der Fehler der zweiten Abfrage

        /// Der Satz, der dasteht, wenn `/forecast/history` nicht antwortet
        /// (`Rueckblick.tsx:145`).
        public static let fehlerErsatz = "Rückblick nicht verfügbar."

        /// Was in der Lesehilfekarte steht, wenn der Rückblick scheitert - und `nil`, wenn
        /// nicht.
        ///
        /// **Der Fehler darf nicht die Säulen von vorhin vom Schirm nehmen.** Die Vorlage hält
        /// `data` und `fehler` getrennt und setzt bei einem Fehler nur den zweiten
        /// (`Rueckblick.tsx:144-146`): ein Rückblick, der einmal nicht antwortet, lässt stehen,
        /// was zuletzt da war, und sagt daneben, dass er nicht nachkam.
        ///
        /// **Die Meldung des Dienstes wird angezeigt und nicht ersetzt.** Sie ist deutsch und
        /// für Menschen gemacht (``ApiFehler``); „Rückblick nicht verfügbar.“ ist nur der
        /// Rückfall für den Fall, dass keine kommt - genau die Unterscheidung, die
        /// `e instanceof ApiError ? e.message : …` in der Vorlage trifft.
        public static func fehlersatz(_ fehler: ApiFehler?) -> String? {
            guard let fehler else { return nil }
            let meldung = fehler.meldung.trimmingCharacters(in: .whitespacesAndNewlines)
            return meldung.isEmpty ? fehlerErsatz : meldung
        }

        // MARK: - Wie viele Spalten der Rückblick hat

        /// Die Spaltengewichte der Reihenkarten: so viele gleich breite Spalten, wie es Reihen
        /// gibt (`Rueckblick.tsx:182`: `repeat(max(1, reihen.length), minmax(0, 1fr))`).
        ///
        /// **Nebeneinander und nicht untereinander.** Der Rückblick vergleicht zwei Reihen -
        /// PV-Leistung und Außentemperatur - über denselben Vorlaufklassen. Untereinander muss
        /// man dafür rollen, und ein Vergleich, für den man rollen muss, ist keiner.
        ///
        /// Die Null ist kein Fehler, sondern der Zustand vor der ersten Antwort; `max(1, …)` der
        /// Vorlage lässt die Reihe dann eine leere Spalte breit sein und nicht null.
        public static func spalten(reihen: Int) -> [Double] {
            Array(repeating: 1, count: max(1, reihen))
        }
    }
}
