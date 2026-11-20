import Foundation

/// Zahlen- und Zeitformate der Anzeige (de-DE, schmales Leerzeichen vor der Einheit).
///
/// Die Vorlage ist `apps/web/src/lib/format/index.ts`, und die Tests dieses Pakets pruefen
/// dieselben Faelle wie `format.test.ts` dort. Was das Dashboard an der Wand zeigt und was die
/// App zeigt, soll Zeichen fuer Zeichen dasselbe sein.
///
/// **Warum hier von Hand gerechnet wird und nicht mit `NumberFormatter`.**
///
/// `Intl.NumberFormat` im Browser, `NumberFormatter` unter iOS und derselbe Typ unter Linux
/// greifen auf drei verschiedene ICU-Staende zu. Bei `de-DE` und einer Nachkommastelle ist das
/// heute einerlei, aber es ist nicht zugesichert, und genau die Stellen, an denen es auffaellt,
/// sind die, die man an einer Wandanzeige nicht nachrechnet. Vor allem aber: dieses Paket wird
/// unter Linux getestet und laeuft unter iOS. Ein Test, der nur auf dem Pruefrechner gilt, ist
/// keiner. Die Regeln sind klein genug, um sie auszuschreiben:
///
/// - Komma als Dezimaltrennzeichen, kein Tausenderpunkt (die Anzeige zeigt keine vierstelligen kW),
/// - U+2212 MINUS SIGN statt des Bindestrichs, weil der in IBM Plex Sans zu kurz fuer eine Zahl ist,
/// - U+202F NARROW NO-BREAK SPACE vor der Einheit, damit „3,6 kW“ nicht umbricht.
public enum Formate {
    /// U+202F, das schmale geschuetzte Leerzeichen vor der Einheit.
    public static let schmalesLeerzeichen = "\u{202F}"
    /// U+2212, das echte Minuszeichen.
    public static let minus = "\u{2212}"
    /// Was dasteht, wenn kein Wert da ist. Ein Bindestrich, nicht „0“ - das ist ein Unterschied.
    public static let leer = "-"

    // MARK: - Zahlen

    /// Eine Zahl mit fester Zahl von Nachkommastellen, deutsch geschrieben.
    ///
    /// Rundet kaufmaennisch (wie `Intl.NumberFormat`), setzt das Komma und das echte Minuszeichen.
    /// Eine Zahl, die zu `-0,0` gerundet wuerde, wird `0,0`: ein Vorzeichen an einer Null ist eine
    /// Aussage, die die Messung nicht hergibt.
    ///
    /// **Nimmt `Double?`, und das war erst anders.** Diese Funktion war die einzige der vierzehn
    /// hier, die ein nicht-wahlfreies `Double` verlangte - und genau deshalb hat sie beim ersten
    /// Uebersetzungslauf der Oberflaeche vierzehn Fehler erzeugt. Fast jede Zahl, die aus dem
    /// Dienst kommt, ist wahlfrei: ein Zaehler, der schweigt, liefert `null`, und das ist kein
    /// Sonderfall, sondern der Alltag. Eine Schnittstelle, in der dreizehn Funktionen das
    /// aushalten und eine nicht, ist eine Falle - und sie hat zugeschnappt. Fehlt der Wert,
    /// steht hier derselbe Strich wie bei den Geschwistern.
    public static func zahl(_ wert: Double?, stellen: Int) -> String {
        guard let wert, wert.isFinite else { return leer }
        let faktor = pow(10.0, Double(stellen))
        let gerundet = (wert * faktor).rounded() / faktor
        let negativ = gerundet < 0
        let betrag = abs(gerundet)
        var text = String(format: "%.\(stellen)f", betrag)
        text = text.replacingOccurrences(of: ".", with: ",")
        // `-0,0` entsteht aus jeder kleinen negativen Zahl. Das Vorzeichen faellt weg.
        let istNull = text.allSatisfy { $0 == "0" || $0 == "," }
        return (negativ && !istNull) ? minus + text : text
    }

    /// Leistung in kW, ohne Einheit. Was dem Betrag nach unter 0,05 liegt, ist eine Null.
    ///
    /// Der Schwellwert ist kein Schoenheitsmittel: ein Wechselrichter, der nachts 0,004 kW
    /// meldet, und ein Zaehler, der −0,01 kW meldet, sollen beide „0,0“ zeigen und nicht
    /// „0,0“ gegen „−0,0“ - sonst sieht die Wand eine Einspeisung, die es nicht gibt.
    public static func kw(_ wert: Double?, stellen: Int = 1) -> String {
        guard let wert, wert.isFinite else { return leer }
        let abgeschnitten = abs(wert) < 0.05 ? 0 : wert
        return zahl(abgeschnitten, stellen: stellen)
    }

    /// Leistung in kW mit Einheit: „3,6 kW“.
    public static func kwMitEinheit(_ wert: Double?) -> String {
        let v = kw(wert)
        return v == leer ? v : v + schmalesLeerzeichen + "kW"
    }

    /// Energie in kWh mit Einheit.
    public static func kwh(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: 1) + schmalesLeerzeichen + "kWh"
    }

    /// Energie in kWh ohne Einheit, mit einer Nachkommastelle - ab hundert ohne.
    ///
    /// **Warum die Schwelle und nicht überall eine Stelle.** Die PV-Abrechnung schreibt diese
    /// Regel sechsmal aus (`PvAccounting.tsx:30`, `:33`, `:92`, `:95`, `:155`, `:157`), und sie
    /// hat zwei Gründe: das Zehntel einer Jahressumme ist Rauschen, und in einer Tabelle mit
    /// acht Spalten nimmt es den Platz, den die Spalte daneben braucht. Dieselbe Schwelle
    /// steht in ``Wallbox/geladenKurz(_:)`` (`EvReport.tsx:95`) - sie gehört hierher, nicht
    /// in jede Seite, die sie braucht.
    ///
    /// Verglichen wird der Wert selbst und nicht sein Betrag, wie in der Vorlage: eine
    /// eingespeiste Menge ist nie negativ, und eine Sonderregel für einen Fall, den es nicht
    /// gibt, wäre eine Abweichung ohne Beleg.
    public static func kwhNachGroesse(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: wert >= 100 ? 0 : 1)
    }

    /// Ein Anteil (0 bis 1) als Prozent, ganzzahlig.
    public static func prozent(_ anteil: Double?) -> String {
        guard let anteil, anteil.isFinite else { return leer }
        return zahl((anteil * 100).rounded(), stellen: 0) + schmalesLeerzeichen + "%"
    }

    /// Temperatur in Grad Celsius.
    public static func celsius(_ wert: Double?, stellen: Int = 0) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: stellen) + schmalesLeerzeichen + "°C"
    }

    /// Strompreis in ct/kWh. Negative Preise kommen vor und sind der Grund fuer das halbe Projekt.
    public static func ct(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: 1) + schmalesLeerzeichen + "ct/kWh"
    }

    /// „18,4 ct“ - derselbe Preis **ohne den Nenner**, wo die Einheit schon über der Spalte steht.
    ///
    /// **Warum das neben ``ct(_:)`` steht und nicht darin.** Die Fahrplanseite schreibt den Preis
    /// an zwei Stellen ohne „/kWh“: in der Entscheidungstabelle (`Fahrplan.tsx:713`) und im
    /// Hinweisfenster des Diagramms (`:328`), beide Male als `${de(i.price_ct_kwh, 1)} ct`. Den
    /// Nenner trägt dort der Flächentitel „Strompreis · ct/kWh“ (`Fahrplan.tsx:114`) – er ist
    /// damit schon gesagt, und in der schmalen Preisspalte des Telefons kostet seine
    /// Wiederholung die halbe Zellbreite. Ein Schalter an ``ct(_:)`` wäre dasselbe in einer
    /// Zeile weniger; zwei Funktionen sagen dafür an der Rufstelle, welche der beiden Formen
    /// gemeint ist, wie schon bei ``euro(_:stellen:)`` und ``euroMitVorzeichen(_:)``.
    ///
    /// **Eine Nachkommastelle, genau wie ``ct(_:)``.** Das `de` der Vorlage ist
    /// `x.toFixed(n).replace(".", ",")` (`Fahrplan.tsx:84-86`) und wird an beiden Stellen mit
    /// `1` gerufen. Die Rundung ist also dieselbe; die beiden Funktionen unterscheiden sich in
    /// genau einem Stück Text, dem Nenner.
    ///
    /// Vor der Einheit steht ``schmalesLeerzeichen``, auch wo die Vorlage an dieser Stelle ein
    /// gewöhnliches Leerzeichen tippt: die Regel im Kopf dieser Datei gilt für jede Einheit
    /// dieser Anwendung, und „18,4 ct“ darf in einer Tabellenzelle nicht umbrechen. Dieselbe
    /// Wahl trifft ``Waermepumpenseite/celsius(_:stellen:)``, dort begründet; und
    /// ``Gelduebersicht/bezugspreis(_:)`` baut für `CostReport.tsx:233` heute schon „31,2 ct“
    /// mit demselben Ergebnis - seitenlokal, weil es diese Funktion noch nicht gab.
    public static func ctKurz(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: 1) + schmalesLeerzeichen + "ct"
    }

    /// Geld in Euro.
    public static func euro(_ wert: Double?, stellen: Int = 2) -> String {
        guard let wert, wert.isFinite else { return leer }
        return zahl(wert, stellen: stellen) + schmalesLeerzeichen + "€"
    }

    /// Geld in Euro mit Vorzeichen: „+0,31 €“, „−0,80 €“, „±0,00 €“.
    ///
    /// **Warum das Vorzeichen immer dasteht.** Die Kostentreppe der Nachbetrachtung zeigt
    /// untereinander eine Summe und die Stufen, die zu ihr führen (`Kostentreppe.tsx:62`:
    /// eine Stufe als `euroMitVorzeichen`, alles andere als `euro`). Eine Stufe ist eine
    /// Änderung und sagt nichts, solange nicht dabeisteht, in welche Richtung; eine Summe trägt
    /// kein Pluszeichen, weil es dort nichts zu vergleichen gibt. Deshalb zwei Funktionen und
    /// nicht ein Schalter. Vorlage: `apps/web/src/components/waerme/nachbetrachtung.ts:89-95`,
    /// festgehalten in `nachbetrachtung.test.ts:110-113` mit genau diesen drei Werten.
    ///
    /// **Die Null bekommt ± und nicht +.** Unter einem halben Cent (`|wert| < 0,005`,
    /// `nachbetrachtung.ts:93`) ist die Richtung nicht gemessen, sondern gerundet. Ein „+“ an
    /// einer Null behauptete eine Ersparnis, die in der dritten Stelle verschwunden ist -
    /// dieselbe Überlegung wie bei ``zahl(_:stellen:)``, die das Minus an einer gerundeten Null
    /// weglässt.
    ///
    /// **Nicht zu verwechseln mit ``euro(_:stellen:)``** gleich darüber: das schreibt „3,42 €“
    /// ohne Plus und ohne ±, und ein Vorzeichen steht dort nur, wenn der Wert wirklich negativ
    /// ist. Der Betrag kommt hier aus `euro(abs(wert))`, damit beide in einer Spalte Zeichen für
    /// Zeichen gleich gesetzt sind - gleiches schmales Leerzeichen, gleiche zwei
    /// Nachkommastellen.
    ///
    /// Das Minus ist ``minus`` (U+2212) und nicht der Bindestrich, so wie die Vorlage es setzt
    /// (`nachbetrachtung.ts:94`). `Double?` wie die Geschwister: fehlt der Wert, steht der
    /// Strich (`nachbetrachtung.ts:91`, `nachbetrachtung.test.ts:113`).
    public static func euroMitVorzeichen(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return leer }
        let betrag = euro(abs(wert))
        // Unter einem halben Cent ist das Vorzeichen eine Rundung und keine Aussage.
        if abs(wert) < 0.005 { return "±" + betrag }
        return (wert > 0 ? "+" : minus) + betrag
    }

    /// Eine Dauer in Minuten als „45 min“ oder „3 h 20 min“.
    public static func dauer(minuten: Int?) -> String {
        guard let minuten, minuten >= 0 else { return leer }
        if minuten < 60 { return "\(minuten)\(schmalesLeerzeichen)min" }
        let h = minuten / 60
        let m = minuten % 60
        return m == 0 ? "\(h)\(schmalesLeerzeichen)h" : "\(h)\(schmalesLeerzeichen)h \(m)\(schmalesLeerzeichen)min"
    }

    /// Eine Zahl mit **höchstens** `stellen` Nachkommastellen und deutschem Tausenderpunkt.
    ///
    /// **Warum das neben ``zahl(_:stellen:)`` steht und nicht darin.** `zahl` schreibt *genau*
    /// `stellen` Stellen: aus 1 wird „1,00“. Das ist richtig für eine Messreihe, in der
    /// untereinander stehende Werte am Komma ausgerichtet sein müssen. Der Platzbedarfsbericht
    /// rechnet anders: `toLocaleString("de-DE", { maximumFractionDigits: n })`
    /// (`apps/web/src/components/settings/StorageReport.tsx:22-23`) ist eine *Obergrenze* und
    /// lässt Nullen am Ende weg - genau ein Gigabyte steht dort als „1 GB“ und nicht als
    /// „1,00 GB“. Und `toLocaleString` setzt den Tausenderpunkt, den `zahl` bewusst nicht setzt;
    /// der Verzicht dort ist mit vierstelligen kW begründet (siehe den Kopf dieser Datei), und
    /// eine Zeilenzahl ist keine Leistung: `measurements_raw` liegt im Bereich von Millionen,
    /// und „1235 Tsd.“ wäre eine andere Zeichenfolge als die, die der Browser zeigt.
    ///
    /// Gerechnet und nicht formatiert, aus dem Grund, der im Kopf dieser Datei steht: dieses
    /// Paket wird unter Linux geprüft und läuft unter iOS, und `NumberFormatter` greift dort auf
    /// zwei verschiedene ICU-Stände zu. Eine Gebietseinstellung wird hier nicht gewählt - die
    /// Regeln dieser Datei *sind* die Festlegung, und es gibt nur diese eine.
    private static func hoechstens(_ wert: Double, stellen: Int) -> String {
        let faktor = pow(10.0, Double(stellen))
        let gerundet = (abs(wert) * faktor).rounded() / faktor
        let stuecke = String(format: "%.\(stellen)f", gerundet).split(separator: ".")
        var ganz = String(stuecke[0])
        // Tausenderpunkt von rechts, wie `toLocaleString("de-DE")` ihn setzt.
        var i = ganz.count - 3
        while i > 0 {
            ganz.insert(".", at: ganz.index(ganz.startIndex, offsetBy: i))
            i -= 3
        }
        var bruch = stuecke.count > 1 ? String(stuecke[1]) : ""
        while bruch.hasSuffix("0") { bruch.removeLast() }
        let betrag = bruch.isEmpty ? ganz : ganz + "," + bruch
        return (wert < 0 && gerundet != 0) ? minus + betrag : betrag
    }

    /// Ein Platzbedarf in Byte: „1,25 GB“, „840,2 MB“ - binär gerechnet.
    ///
    /// **Warum binär und warum diese Schwelle.** Vorlage ist `mb()` in
    /// `apps/web/src/components/settings/StorageReport.tsx:21-24`: ab 1024³ Byte in GB mit
    /// höchstens zwei Stellen, darunter in MB mit höchstens einer. Das sind die Zahlen, die die
    /// Datenbank selbst meldet - sie zählt Seiten, und eine Seite ist 8192 Byte. Eine dezimale
    /// Umrechnung ergäbe für denselben Bestand eine andere Zahl als das Dashboard, und die
    /// Tabelle, die den größten Posten sucht, wäre nicht mehr mit ihm vergleichbar.
    ///
    /// Verglichen wird der Wert selbst und nicht sein Betrag, wie in der Vorlage: ein
    /// Platzbedarf ist nie negativ.
    ///
    /// **Nicht zu verwechseln mit ``Hausgeraet/bytes(_:)``**, das „1,2 GB“, „840 MB“, „2,5 TB“
    /// **dezimal** rechnet (1e6, 1e9, 1e12) - so, wie Plattenhersteller und `df -H` zählen. Das
    /// gehört zur Platte des Geräts, dies zum Bestand der Datenbank; dieselben Byte, zwei
    /// Umrechnungen, und beide mit Grund.
    ///
    /// Vor der Einheit steht hier das **gewöhnliche** Leerzeichen und nicht
    /// ``schmalesLeerzeichen`` wie bei kW, kWh und €: so schreibt es die Vorlage
    /// (`StorageReport.tsx:22-23`). Wo Vorlage und Paket auseinandergehen, gilt die Vorlage -
    /// der Zweck dieser Datei ist, dass Wand und App Zeichen für Zeichen dasselbe zeigen.
    public static func megabyte(_ bytes: Int) -> String {
        let b = Double(bytes)
        if bytes >= 1_073_741_824 { return hoechstens(b / 1_073_741_824, stellen: 2) + " GB" }
        return hoechstens(b / 1_048_576, stellen: 1) + " MB"
    }

    /// Eine Zeilenzahl: „12 Tsd.“ ab tausend, darunter die Zahl selbst.
    ///
    /// **Warum ab tausend abgekürzt wird.** Vorlage ist `rows()` in
    /// `apps/web/src/components/settings/StorageReport.tsx:26-28`. Die Spalte steht neben drei
    /// Spalten mit Platzbedarf und beantwortet eine einzige Frage: ist diese Tabelle groß, weil
    /// sie viele Zeilen hat, oder weil die Zeilen breit sind. Dazu sind die letzten drei Ziffern
    /// einer Schätzung (`rows_estimate`) kein Beitrag, nur Breite.
    ///
    /// Die Tausender bekommen den Punkt, weil `toLocaleString("de-DE")` ihn setzt
    /// (`StorageReport.tsx:27`): `measurements_raw` liegt im Bereich von Millionen, und dort
    /// steht dann „1.235 Tsd.“. Siehe ``hoechstens(_:stellen:)``, wo begründet steht, warum
    /// dieser Punkt der Regel im Kopf der Datei nicht widerspricht.
    ///
    /// **Nicht zu verwechseln mit ``zahl(_:stellen:)`` mit `stellen: 0`**, das die ganze Zahl
    /// ohne Abkürzung und ohne Tausenderpunkt schreibt - „1234567“ statt „1.235 Tsd.“. Das ist
    /// die Form, die die Technikseite heute noch zeigt.
    public static func zeilen(_ n: Int) -> String {
        n >= 1000 ? hoechstens(Double(n) / 1000, stellen: 0) + " Tsd." : String(n)
    }

    // MARK: - Zeit

    /// Die Zeitzone des Hauses. Nicht die des Geraets: wer aus dem Urlaub nachsieht, will wissen,
    /// wann die Waermepumpe *dort* gelaufen ist.
    public static let zeitzone = TimeZone(identifier: "Europe/Berlin") ?? TimeZone(secondsFromGMT: 3600)!

    /// „13:42“ in der Zeit des Hauses.
    ///
    /// Gerechnet, nicht formatiert: ein `DateFormatter` ist unter Swift 6 nicht
    /// nebenlaeufigkeitssicher zu teilen und zu langsam, um ihn je Zeile neu zu bauen. Eine
    /// Protokollseite zeigt dreihundert Uhrzeiten.
    public static func hhmm(_ zeitpunkt: Date?) -> String {
        guard let zeitpunkt else { return leer }
        let t = Kalender.haus.dateComponents([.hour, .minute], from: zeitpunkt)
        return String(format: "%02d:%02d", t.hour ?? 0, t.minute ?? 0)
    }

    /// Dasselbe aus einem ISO-Zeitstempel, wie der Dienst ihn liefert.
    public static func hhmm(iso: String?) -> String {
        guard let iso, let d = Zeit.ausIso(iso) else { return leer }
        return hhmm(d)
    }

    /// „Sa., 07.11.“ - das kurze Datum eines Zeitstempels, in der Zeit des Hauses.
    ///
    /// **Warum es das gibt.** Die Vorlage schreibt dieses Datum aus einem Zeitstempel, in den
    /// Mitteilungen allein („angemeldet seit …“,
    /// `apps/web/src/components/settings/Mitteilungen.tsx:75`) und zusammen mit der Uhrzeit
    /// (`:59`, „kurzDatum, hhmm“). Gerechnet wird es in
    /// `apps/web/src/components/waerme/wirkung.ts:109-112` mit dem Formatierer aus `:96` -
    /// `{ timeZone: HAUS, weekday: "short", day: "2-digit", month: "2-digit" }`.
    ///
    /// **Nicht zu verwechseln mit ``Tag/kurz(_:)``, und nicht damit zusammenzulegen.** Das nimmt
    /// einen Kalendertag `YYYY-MM-DD` und ergibt „Sa, 7.11.“: anderer Eingang, kein Punkt hinter
    /// dem Wochentag, keine führende Null. Beide Formen stehen so in der Vorlage, und beide mit
    /// Grund. `Tag.kurz` steht in Blätterleisten, wo das Datum neben Text liegt und sich wie
    /// gesprochen lesen soll. Dieses hier steht in einer Spalte aus achtzig Zeilen in
    /// Festbreitenschrift; mit führenden Nullen stehen die Ziffern untereinander, ohne nicht -
    /// nachzulesen bei ``Wirkungsbild/wann(_:)`` (`Zustand/Wirkungsbild.swift:551-556`), das
    /// dieselbe Form für sein Raster schon gebraucht hat. Eine der beiden Formen auf die andere
    /// zu ziehen hieße, eine der beiden Begründungen zu verwerfen.
    ///
    /// Die Zeitzone ist die des Hauses (``Kalender/haus``), wie `timeZone: HAUS` in der Vorlage:
    /// ein Gerät, das sich um 00:30 Berliner Zeit anmeldet, steht im ISO-Stempel mit 23:30 des
    /// Vortages, und „angemeldet seit“ nennte dann den falschen Tag. Die Namen kommen aus
    /// ``Namen/wochentag(_:kurz:)`` und nicht aus einem `DateFormatter` - aus dem Grund, der
    /// dort steht: die beiden ICU-Stände unter Linux und iOS sind sich beim Punkt nicht einig.
    /// Der Punkt hinter dem Wochentag wird deshalb hier gesetzt, denn ``Namen/wochentageKurz``
    /// führt „Sa“ ohne ihn.
    ///
    /// `String?` wie ``hhmm(iso:)`` darüber: `seit` der Vorlage ist wahlfrei
    /// (`Mitteilungen.tsx:75`), und fehlt der Stempel, steht hier derselbe Strich wie bei den
    /// Geschwistern.
    public static func kurzDatum(iso: String?) -> String {
        guard let iso, let d = Zeit.ausIso(iso) else { return leer }
        let t = Kalender.haus.dateComponents([.weekday, .day, .month], from: d)
        let wochentag = Namen.wochentag(t.weekday ?? 1, kurz: true)
        return "\(wochentag)., " + String(format: "%02d.%02d.", t.day ?? 0, t.month ?? 0)
    }

    /// „morgen 03:15“ - eine Uhrzeit mit dem Tag davor, wo mehr als ein Tag im Bild ist.
    ///
    /// **Warum nicht nur die Uhrzeit.** Der Fahrplan reicht ueber zwei Tage. „03:15“ allein
    /// steht dort zweimal und sagt nicht, welche der beiden Nacht gemeint ist. Gerechnet wird
    /// der Abstand in Kalendertagen des Hauses, mittags, damit kein Zeitversatz den Tag kippt.
    /// Ab drei Tagen Abstand steht das kurze Datum.
    public static func tagUndUhr(_ zeitpunkt: Date?, jetzt: Date) -> String {
        guard let zeitpunkt else { return leer }
        let wort: String
        switch Tag.abstand(Tag.iso(zeitpunkt), Tag.iso(jetzt)) {
        case .some(0): wort = "heute"
        case .some(1): wort = "morgen"
        case .some(2): wort = "übermorgen"
        case .some(-1): wort = "gestern"
        default: wort = Tag.kurz(Tag.iso(zeitpunkt))
        }
        return "\(wort) \(hhmm(zeitpunkt))"
    }

    public static func tagUndUhr(iso: String?, jetzt: Date) -> String {
        guard let iso, let d = Zeit.ausIso(iso) else { return leer }
        return tagUndUhr(d, jetzt: jetzt)
    }

    /// „13:42:07“ - nur im Protokoll, wo die Sekunde etwas aussagt.
    public static func hhmmss(_ zeitpunkt: Date?) -> String {
        guard let zeitpunkt else { return leer }
        let t = Kalender.haus.dateComponents([.hour, .minute, .second], from: zeitpunkt)
        return String(format: "%02d:%02d:%02d", t.hour ?? 0, t.minute ?? 0, t.second ?? 0)
    }

    /// „Samstag, 7. November“ - die Ueberschrift des Tagesdiagramms.
    public static func langesDatum(_ zeitpunkt: Date) -> String {
        let t = Kalender.haus.dateComponents([.weekday, .day, .month], from: zeitpunkt)
        let tag = Namen.wochentag(t.weekday ?? 1)
        return "\(tag), \(t.day ?? 0). \(Namen.monat(t.month ?? 1))"
    }

    /// Wie alt ein Messwert ist - oder `nil`, wenn er frisch genug ist, um es nicht zu erwaehnen.
    ///
    /// Unter 30 Sekunden steht nichts da. Das ist Absicht: ein Alter an jedem Wert macht die
    /// Anzeige unruhig, und solange die Werte kommen, ist das Alter keine Nachricht.
    public static func alter(beobachtetAm: Date, jetzt: Date) -> String? {
        let s = max(0, jetzt.timeIntervalSince(beobachtetAm))
        if s < 30 { return nil }
        if s < 90 { return "vor \(Int(s.rounded())) s" }
        if s < 3600 { return "vor \(Int((s / 60).rounded())) min" }
        return "vor \(Int((s / 3600).rounded())) h"
    }

    /// Minuten bis zu einem Zeitpunkt, nie negativ.
    public static func minutenBis(_ zeitpunkt: Date?, jetzt: Date) -> Int? {
        guard let zeitpunkt else { return nil }
        return max(0, Int((zeitpunkt.timeIntervalSince(jetzt) / 60).rounded()))
    }
}

/// Der Kalender des Hauses: gregorianisch, Woche beginnt am Montag, Zeitzone Europe/Berlin.
public enum Kalender {
    public static let haus: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = Formate.zeitzone
        c.firstWeekday = 2
        return c
    }()
}
