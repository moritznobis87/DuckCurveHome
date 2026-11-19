import Foundation

extension Messwert {
    /// Rohe Zahlen als Messwerte, mit Güte.
    ///
    /// **Warum das nötig ist.** Der Dienst liefert dieselbe Größe an zwei Stellen in zwei
    /// Formen: der Ereignisstrom schickt `Messwert` mit Zeitstempel und Güte, die Seite
    /// `/anlage` schickt nur `[Double?]` mit einem Zeitstempel für die ganze Antwort. Die
    /// Oberfläche kennt aber nur eine Form – `Pufferglas` zeichnet Messwerte, weil es einen
    /// fehlenden Fühler anders malen muss als einen kalten.
    ///
    /// Die Güte ist nicht geraten, sondern abgeleitet: eine Zahl, die da ist, ist `ok`; eine,
    /// die fehlt, ist `unavailable`. Das ist genau die Auskunft, die der Endpunkt hergibt –
    /// mehr zu behaupten (etwa `stale` nach Alter) wäre eine Erfindung an dieser Stelle, denn
    /// den Zeitstempel trägt die Antwort als Ganzes und nicht der einzelne Fühler.
    public static func ausZahlen(
        _ werte: [Double?], beobachtet: String, quelle: String
    ) -> [Messwert] {
        werte.map { wert in
            Messwert(
                value: wert,
                observedAt: beobachtet,
                quality: wert == nil ? .unavailable : .ok,
                source: quelle
            )
        }
    }
}
