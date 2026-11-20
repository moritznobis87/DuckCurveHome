import Foundation

/// Was die Technikseite der Wärmepumpe rechnet, auswählt und wörtlich schreibt.
///
/// **Warum neben ``Wpbild`` noch ein zweiter Ort.** ``Wpbild`` (`Haus/Waermepumpenbild.swift`)
/// hält die Maße und die drei Schlüsse der *Zeichnung*; hier steht alles, was die *Seite* um
/// die Zeichnung herum braucht: die Standzeile, die vier führenden Kennzahlen, die dreizehn
/// Spalten der Reglertabelle, die Sätze, die wörtlich dastehen müssen, und die vier
/// Fühlerhöhen des Glases. Vorlage ist `apps/web/src/components/waermepumpe/Waermepumpe.tsx`
/// samt `Kennzahlen.tsx` und `bild.ts`.
///
/// **Ein eigenes Fragezeichen, und das ist der Grund für den halben Dateikopf.** Die Vorlage
/// schreibt an dieser Seite „?“ und nicht den Strich, den ``Formate/leer`` sonst setzt - mit
/// Begründung: „ein fehlender Wert ist keine Null“ (`bild.ts:82-85`). Diese Seite zeigt
/// achtzehn Messwerte eines Busses, der einzelne Größen überhaupt nicht meldet, und zwischen
/// „0,0 kW“ und „kein Wert“ liegt hier der ganze Unterschied. Darum tragen die Zahlformate
/// dieser Seite ihr eigenes Zeichen für „fehlt“; gerundet und geschrieben wird mit
/// ``Formate/zahl(_:stellen:)`` wie überall, damit Wand und App Zeichen für Zeichen
/// dasselbe zeigen.
public enum Wpseite {
    /// Was dasteht, wenn kein Wert da ist - auf dieser Seite ein Fragezeichen (`bild.ts:83`).
    public static let frage = "?"

    // MARK: - Zahlen, die ein Fragezeichen kennen

    /// Eine Zahl deutsch geschrieben, oder das Fragezeichen (`bild.ts:82-85`).
    public static func zahl(_ wert: Double?, stellen: Int = 1) -> String {
        guard let wert, wert.isFinite else { return frage }
        return Formate.zahl(wert, stellen: stellen)
    }

    /// Eine Temperatur: „38,4 °C“ oder „?“.
    ///
    /// Vor der Einheit steht wie überall im Paket ``Formate/schmalesLeerzeichen``, auch wo die
    /// Vorlage an dieser Stelle ein gewöhnliches Leerzeichen tippt (`Kennzahlen.tsx:76`,
    /// `Waermepumpe.tsx:72`): die Regel im Kopf von `Formate.swift` gilt für jede Einheit
    /// dieser Anwendung, und eine Spalte, in der „38,4 °C“ anders umbricht als „5,3 K“
    /// daneben, wäre eine Abweichung ohne Gewinn.
    public static func celsius(_ wert: Double?, stellen: Int = 1) -> String {
        guard let wert, wert.isFinite else { return frage }
        return Formate.zahl(wert, stellen: stellen) + Formate.schmalesLeerzeichen + "°C"
    }

    /// Eine Zahl mit **sichtbarem** Vorzeichen: „+1,8“, „−0,4“ (`Kennzahlen.tsx:17`).
    ///
    /// **Das Vorzeichen kommt vom rohen Wert, der Betrag vom gerundeten** - und damit weicht
    /// diese Funktion bewusst von ``Formate/zahl(_:stellen:)`` ab, die das Minus an einer zu
    /// Null gerundeten Zahl weglässt. Die Spalten „Speicher oben“ und „Mitte unten“ sind
    /// Änderungsgeschwindigkeiten in K/h; −0,04 K/h heißt „der Fühler wurde kälter, kaum
    /// messbar“, und „0,0“ ohne Zeichen hieße „keine Änderung gemessen“. In einer Spalte, in
    /// der neben jeder Zahl ein Vorzeichen steht, ist ein fehlendes selbst eine Aussage.
    ///
    /// Das Minus ist ``Formate/minus`` (U+2212) und nicht der Bindestrich, so wie die Vorlage
    /// es setzt (`Kennzahlen.tsx:17`).
    public static func mitVorzeichen(_ wert: Double?, stellen: Int = 1) -> String {
        guard let wert, wert.isFinite else { return frage }
        let vorzeichen = wert >= 0 ? "+" : Formate.minus
        return vorzeichen + Formate.zahl(abs(wert), stellen: stellen)
    }

    /// Ein Anteil (0 bis 1) als ganze Prozent, oder „?“ (`Kennzahlen.tsx:19`).
    public static func anteil(_ wert: Double?) -> String {
        guard let wert, wert.isFinite else { return frage }
        return Formate.zahl((wert * 100).rounded(), stellen: 0)
            + Formate.schmalesLeerzeichen + "%"
    }

    // MARK: - Der Kopf

    /// Die Standzeile unter dem führenden Satz, mit „ · “ verkettet
    /// (`Waermepumpe.tsx:68-78`).
    ///
    /// **Die Uhrzeit ist die des Dienstes und nicht die des Geräts.** Sie kommt aus `now` der
    /// Antwort (`Waermepumpe.tsx:69`): sie sagt, wann der Bus zuletzt gesprochen hat, nicht
    /// wann das Telefon zuletzt gezeichnet hat - und genau das ist auf einer Seite, die nur
    /// den Augenblick zeigt, die Auskunft, die zählt.
    ///
    /// **Hier steht `value` und nicht ``Messwert/belastbar``**, anders als in den vier
    /// Kennzahlen darunter. Das ist die Vorlage (`:71-74`: `raum_soll_c?.value != null`), und
    /// es hat einen Grund: diese Zeile berichtet, *was der Regler vorgibt, soweit er es
    /// sendet* (Kommentar `:70-71`) - ein Sollwert von vorhin ist eine Vorgabe von vorhin und
    /// bleibt eine. Die Kennzahlen darunter sind Messungen am laufenden Gerät, und eine alte
    /// Messung als gegenwärtige auszugeben wäre dort falsch.
    ///
    /// Der Fehlertext wandert hierher, sobald ein Abruf fehlschlägt und schon ein Stand
    /// dasteht (`:77`): die Seite behält, was sie hat, und sagt in der Nebenzeile, dass es
    /// stehen geblieben ist.
    public static func standzeile(_ w: WaermepumpeOut, fehler: String? = nil) -> String {
        var teile: [String] = ["Stand " + Formate.hhmm(iso: w.now)]
        if let h = w.heizanforderung {
            teile.append("Heizanforderung " + (h ? "an" : "aus"))
        }
        if let r = w.raumSollC?.value {
            teile.append("Raum-Sollwert " + celsius(r))
        }
        if let v = w.ventilCode {
            teile.append("Umschaltventil Stellung \(v)")
        }
        if let h = w.heizstabCode {
            teile.append("Heizstab meldet \(h)")
        }
        if let a = w.verdichterA?.value {
            teile.append("Verdichter " + zahl(a) + Formate.schmalesLeerzeichen + "A")
        }
        if let fehler, !fehler.isEmpty {
            teile.append(fehler)
        }
        return teile.joined(separator: " · ")
    }

    /// Die vier führenden Kennzahlen, in der Reihenfolge der Vorlage
    /// (`Waermepumpe.tsx:93-98`).
    ///
    /// **Warum genau diese vier.** Der Kommentar der Vorlage (`:23-25`) sagt es: sie
    /// beantworten, was man von einer Wärmepumpe wissen will - wie viel Wärme, aus wie viel
    /// Strom, mit welcher Arbeitszahl, bei welcher Spreizung. Die App zeigte hier sechs, und
    /// die Spreizung war nicht darunter; „draußen“, „Vorlauf“ und „Verdichter“ stehen dafür in
    /// der Zeichnung, wo sie einen Ort haben.
    ///
    /// **Die Stellen sind die der Vorlage und nicht die runderen.** Wärmeleistung und
    /// Arbeitszahl mit *einer* Stelle (`:94`, `:96`), der Strom mit *zwei* (`:95`). Die
    /// zweite Stelle am Strom ist keine Zierde: die Maschine zieht im Stillstand rund 0,1 kW,
    /// und 0,08 gegen 0,12 ist dort der Unterschied zwischen „Steuerung“ und „Steuerung und
    /// Umwälzpumpe“. An der Arbeitszahl wäre eine zweite Stelle Rauschen - sie ist ein
    /// Quotient aus zwei Messwerten mit je einer belastbaren Stelle.
    ///
    /// **Fehlt der Wert, fällt der Ton auf ``Kennzahl/Ton/gedaempft``** (`tone="muted"`,
    /// `Stat.tsx:5` → `--text-3`): eine große helle „?“ sieht aus wie eine Meldung, und sie
    /// ist das Gegenteil davon.
    public static func kennzahlen(_ w: WaermepumpeOut) -> [Kennzahl] {
        let strom = Wpbild.aufnahme(w)
        return [
            Kennzahl(
                wort: "Wärmeleistung",
                wert: zahl(w.waermeleistungKw),
                einheit: "kW",
                dazu: w.laeuft ? "Durchfluss mal Spreizung" : "nur bei laufender Maschine",
                // Die einzige der vier, die die Vorlage einfärbt: sie ist die Zahl, um die es
                // auf dieser Seite geht (`Waermepumpe.tsx:94`, `tone="amber"`).
                ton: w.waermeleistungKw == nil ? .gedaempft : .bernstein
            ),
            Kennzahl(
                // Die Quelle steht **im Namen** und nicht als Hinweiszeile darunter
                // (`:95`): „Strom, Zähler“ und „Strom, laut Maschine“ sind zwei verschiedene
                // Zahlen und nicht dieselbe Zahl mit einer Fußnote.
                wort: strom.quelle.isEmpty ? "Strom" : "Strom, \(strom.quelle)",
                wert: zahl(strom.kw, stellen: 2),
                einheit: "kW",
                ton: strom.kw == nil ? .gedaempft : .normal
            ),
            Kennzahl(
                wort: "Arbeitszahl",
                wert: zahl(w.arbeitszahl),
                dazu: "Wärme je Strom, im Augenblick",
                ton: w.arbeitszahl == nil ? .gedaempft : .normal
            ),
            Kennzahl(
                wort: "Spreizung",
                wert: zahl(w.spreizungK),
                einheit: "K",
                dazu: "Vorlauf minus Rücklauf",
                ton: w.spreizungK == nil ? .gedaempft : .normal
            ),
        ]
    }

    // MARK: - Die Absätze, die wörtlich dastehen müssen

    /// Der fette Vorsatz des Heizstab-Absatzes (`Waermepumpe.tsx:83`).
    ///
    /// Eine Stelle, wie die Vorlage sie schreibt (`zahl(daten.zusatz_kw)`): „rund“ steht
    /// davor, und eine zweite Stelle hinter einem „rund“ wäre ein Widerspruch in einem Satz.
    public static func zusatzsatzFett(kw: Double) -> String {
        "Neben dem Verdichter laufen rund \(zahl(kw)) kW."
    }

    /// Was hinter dem fetten Vorsatz steht (`Waermepumpe.tsx:83`).
    ///
    /// **Der letzte Satz ist der wichtigste.** Ohne ihn liest man die Arbeitszahl oben als die
    /// der Maschine; mit Heizstab ist sie die der Anlage, und das sind zwei verschiedene
    /// Zahlen. Der Absatz steht darum über den Kennzahlen und nicht unter ihnen.
    public static let zusatzsatzRest =
        "Der Zähler misst deutlich mehr, als die Maschine für sich meldet; vermutlich ist der "
        + "elektrische Heizstab an. Die Arbeitszahl unten enthält ihn."

    /// Der fette Vorsatz des Absatzes zum stummen Bus (`Waermepumpe.tsx:89`); dahinter steht
    /// der Satz des Dienstes aus `bus_stumm_de`.
    public static let busStummVorsatz = "Vom Bus der Wärmepumpe ist kein Wert da."

    /// Der erste Satz des Fußes, immer (`Waermepumpe.tsx:107`).
    ///
    /// Er erklärt das Schild „Fühler WP“ in der Zeichnung: der Speicherfühler der Wärmepumpe
    /// sitzt nicht auf der Höhe eines der vier eigenen Fühler, und ohne diesen Satz liest man
    /// seine Zahl als fünfte Schicht. Die Höhe selbst steht als ``Wpbild/fuehlerWp``.
    public static let fussFuehler =
        "Fühler WP: der Speicherfühler der Wärmepumpe. Er sitzt über dem obersten eigenen "
        + "Fühler, auf halbem Weg zur Oberkante des Speichers."

    /// Der zweite Satz des Fußes, wenn Ventil- oder Heizstabkennung da ist
    /// (`Waermepumpe.tsx:109`).
    ///
    /// **„für dieses Haus ist das noch nicht gegengeprüft“ ist der Kern dieses Satzes.** Die
    /// Busbeschreibung nennt eine Bedeutung, diese Anlage hat sie nicht bestätigt - und
    /// darum steht die Zahl des Reglers da und nicht das Wort, das sie bedeuten soll. Dieselbe
    /// Zurückhaltung wie in der Reglertabelle (siehe ``einleitung``).
    public static let fussVentilUndHeizstab =
        "Umschaltventil und Heizstab stehen als Zahl des Reglers da. Laut Busbeschreibung "
        + "heißt beim Ventil 0 Warmwasser und 1 Heizung, beim Heizstab 1 an; für dieses Haus "
        + "ist das noch nicht gegengeprüft. Die Tabelle oben zeigt, was der Speicher unter "
        + "jeder Stellung tut."

    /// Braucht der Fuß den Satz über Ventil und Heizstab? (`Waermepumpe.tsx:108`)
    public static func ventilsatzNoetig(_ w: WaermepumpeOut) -> Bool {
        w.ventilCode != nil || w.heizstabCode != nil
    }

    /// Ein Verweis im Fuß der Seite.
    public struct Verweis: Sendable, Hashable, Identifiable {
        public let weg: String
        public let wort: String

        public var id: String { weg }

        public init(weg: String, wort: String) {
            self.weg = weg
            self.wort = wort
        }
    }

    /// Die fünf Verweise im Fuß, in der Reihenfolge der Vorlage
    /// (`Waermepumpe.tsx:112-118`).
    ///
    /// Im Kern und nicht in der Ansicht, aus demselben Grund, aus dem `Wpmenue.ziele` in der
    /// Oberfläche seine vier Ziele hält: fünf Wege und fünf Wörter, von Hand getippt, sind
    /// fünf Gelegenheiten für einen Tippfehler, den niemand sieht, bis jemand draufdrückt.
    /// Dass jeder dieser Wege einer ist, den die App kennt (``Bereiche/alleWege``), prüft
    /// `WpseiteTests` an genau dieser Liste - in der Ansicht wäre das nicht prüfbar.
    public static let fussverweise: [Verweis] = [
        Verweis(weg: "/waerme/waermepumpe/betrieb", wort: "Betrieb über Tage ›"),
        Verweis(weg: "/waerme/waermepumpe/kennlinie", wort: "Gemessene Kennlinie ›"),
        Verweis(weg: "/waerme/nachbetrachtung", wort: "Was die Wärme gekostet hat ›"),
        Verweis(weg: "/waerme/fahrplan", wort: "Fahrplan ›"),
        Verweis(weg: "/waerme/anlage", wort: "Die ganze Anlage ›"),
    ]

    // MARK: - Die Reglertabelle

    /// Die Überschrift der Tabellenkarte (`Kennzahlen.tsx:46`).
    public static func tabellentitel(tage: Int) -> String {
        "Was der Regler meldet, letzte \(tage) Tage"
    }

    /// Der Absatz über der Tabelle (`Kennzahlen.tsx:47-49`).
    ///
    /// **Er ist der Grund, warum diese Tabelle Zahlen zeigt und keine Wörter.** Der Kommentar
    /// der Vorlage (`Kennzahlen.tsx:7-15`) nennt den Anlass: am 14.11.2026 stand an dieser
    /// Stelle „Puffer kühlen“ an einer Maschine, die heizte - das Wort kam aus einer fremden
    /// Liste und passte für diese Anlage nicht. Gedeutet wird hier nichts; gezeigt werden die
    /// Belege, aus denen sich die Bedeutung ablesen lässt.
    public static let einleitung =
        "Der Regler sendet eine Kennzahl, kein Wort. Bestätigt sind 0 (Bereitschaft) und "
        + "2 (Heizen); für die übrigen steht hier, was die Maschine unter der Zahl getan hat."

    /// Der Absatz unter der Tabelle: was jede der dreizehn Spalten bedeutet
    /// (`Kennzahlen.tsx:93-95`).
    public static let nachsatz =
        "„Speicher oben“ und „Mitte unten“: wie schnell der Fühler im Lauf wärmer wurde, ab "
        + "zwanzig Minuten Lauf. „Zähler über Maschine“: was der Zähler im Lauf mehr aufnahm, "
        + "als die Maschine für sich meldet; mehrere Kilowatt sprechen für den Heizstab. "
        + "„Heizanforderung“: Anteil der Minuten, in denen der Regler für die erste Zone Wärme "
        + "anforderte. „Kennung 1b45“: Anteil der Minuten, in denen diese Kennung des Busses "
        + "gesetzt war; was sie bedeutet, ist offen, sie liegt neben der des Heizstabs. "
        + "„Angefordert“: Anteil der Minuten, in denen Duck Curve Home die Maschine "
        + "eingeschaltet hatte."

    /// Die zwölf Spaltennamen hinter der Kennzahl, wörtlich und in der Reihenfolge der
    /// Vorlage (`Kennzahlen.tsx:55-67`).
    ///
    /// Die Kennzahl selbst ist die Beschriftung der Zeile (siehe ``zeilenname(_:aktuell:)``)
    /// und steht darum nicht in dieser Liste - dreizehn Spalten in der Vorlage, zwölf hier
    /// plus die Zeilenbeschriftung.
    public static let spaltennamen = [
        "Minuten", "davon Lauf", "Vorlauf", "Sollwert", "Speicher oben",
        "Speicher Mitte unten", "Zähler über Maschine", "Heizanforderung", "Kennung 1b45",
        "Ventil auf 1", "Heizstab gemeldet", "angefordert",
    ]

    /// Die Beschriftung einer Zeile: die Kennzahl, und „ · jetzt“ an der, die der Regler
    /// gerade sendet (`Kennzahlen.tsx:72-75`).
    public static func zeilenname(_ z: ReglerKennzahlOut, aktuell: Int?) -> String {
        istAktuell(z, aktuell: aktuell) ? "\(z.code) · jetzt" : String(z.code)
    }

    /// Ist das die Kennzahl, die der Regler gerade sendet? Ihre ganze Zeile steht dann in
    /// Amber (`globals.css:911`, `Kennzahlen.tsx:71`).
    public static func istAktuell(_ z: ReglerKennzahlOut, aktuell: Int?) -> Bool {
        aktuell != nil && z.code == aktuell
    }

    /// Die zwölf Zellen einer Zeile, in der Reihenfolge von ``spaltennamen``
    /// (`Kennzahlen.tsx:76-87`).
    ///
    /// **Minuten und Laufminuten stehen ohne Einheit und ohne Tausenderpunkt** da, wie in der
    /// Vorlage (`:77-78`: `{z.minuten}` roh). Über sieben Tage können es vierstellige Zahlen
    /// werden; die Spaltenköpfe heißen „Minuten“ und „davon Lauf“, und eine Einheit an jeder
    /// Zelle wäre dreizehnmal dasselbe Wort.
    public static func zellen(_ z: ReglerKennzahlOut) -> [String] {
        [
            String(z.minuten),
            String(z.laufMin),
            celsius(z.vorlaufC),
            celsius(z.vorlaufSollC),
            kelvinJeStunde(z.obenKH),
            kelvinJeStunde(z.untenKH),
            kilowatt(z.zusatzKw),
            anteil(z.heizanforderungAnteil),
            anteil(z.flag1b45Anteil),
            anteil(z.ventil1Anteil),
            anteil(z.heizstabAnteil),
            anteil(z.angefordertAnteil),
        ]
    }

    /// Eine Erwärmungsgeschwindigkeit: „+1,8 K/h“ (`Kennzahlen.tsx:81-82`).
    public static func kelvinJeStunde(_ wert: Double?) -> String {
        guard wert != nil else { return frage }
        return mitVorzeichen(wert) + Formate.schmalesLeerzeichen + "K/h"
    }

    /// Was der Zähler über die Meldung der Maschine hinaus aufnahm: „+2,4 kW“
    /// (`Kennzahlen.tsx:83`).
    ///
    /// **Mit Vorzeichen, obwohl eine Leistung keines braucht.** Es ist keine Leistung, sondern
    /// eine Differenz, und eine negative sagt etwas: die Maschine meldet mehr, als der Zähler
    /// sieht - also stimmt eine der beiden Zahlen nicht. ``Formate/kw(_:stellen:)`` wäre hier
    /// falsch, weil es kleine Werte auf Null zieht und damit genau diesen Fall verschwinden
    /// ließe.
    public static func kilowatt(_ wert: Double?) -> String {
        guard wert != nil else { return frage }
        return mitVorzeichen(wert) + Formate.schmalesLeerzeichen + "kW"
    }

    /// Die Spalten der Tabelle: je Spalte ihr Name und ihre Zellen in Zeilenreihenfolge.
    ///
    /// Die Ansicht setzt daraus ihre Tabelle; welche Spalte wo steht und was in ihr steht,
    /// entscheidet sie nicht.
    public static func spalten(
        _ zeilen: [ReglerKennzahlOut]
    ) -> [(name: String, zellen: [String])] {
        let gerechnet = zeilen.map(zellen)
        return spaltennamen.enumerated().map { stelle, name in
            (name: name, zellen: gerechnet.map { $0[stelle] })
        }
    }

    /// Wie oft die Tabelle neu gefragt wird, in Sekunden (`Kennzahlen.tsx:34-35`).
    ///
    /// **Ein eigener, viel langsamerer Takt als der der Seite.** Der Dienst hält die
    /// Auszählung fünf Minuten; öfter zu fragen bringt dieselbe Antwort und kostet eine
    /// Auswertung über sieben Tage. Die Seite selbst fragt alle zehn Sekunden (siehe
    /// ``takt``), weil sie den Augenblick zeigt - zwei Abrufe, zwei Takte.
    public static let kennzahlenTakt: Double = 5 * 60

    /// Wie oft der Augenblick neu gefragt wird, in Sekunden (`Waermepumpe.tsx:25`).
    public static let takt: Double = 10

    /// Über wie viele Tage die Tabelle zählt (`Kennzahlen.tsx:29`).
    public static let kennzahlenTage = 7

    // MARK: - Das Glas im Speicher

    /// Wo die vier Fühler im Speicher sitzen: in der Mitte ihrer Schicht, als Anteil von oben
    /// (`apps/web/src/components/puffer/glas.ts:21`).
    ///
    /// **Diese Zahlen gehören nicht der Wärmepumpenzeichnung**, sondern dem Glas, das in der
    /// Vorlage überall dasselbe ist - Startseite, Anlagenschema, Wärmepumpe. Darum stehen sie
    /// hier und nicht in der Zeichnung: ein `Canvas` kann die Glas-Ansicht nicht einsetzen und
    /// muss das Glas nachzeichnen, und dann ist die gemeinsame Zahl das Einzige, was beide im
    /// Gleichschritt hält. Die Zeichnung hatte 0,12 / 0,38 / 0,62 / 0,88 - gerundet, nicht
    /// falsch gemessen, aber eben nicht dieselbe Schichtmitte.
    public static let fuehlerhoehen: [Double] = [0.125, 0.375, 0.625, 0.875]

    /// Sind alle vier Fühler da? (`glas.ts:26`)
    ///
    /// **Sonst gibt es keinen Verlauf, nur ein leeres Glas** - so schreibt es die Vorlage
    /// wörtlich (`glas.ts:28-29`). Ein Verlauf aus zwei von vier Fühlern zeigt eine
    /// Schichtung, die niemand gemessen hat; und gerade die Schichtung ist das, wofür man auf
    /// das Glas sieht.
    public static func glasVollstaendig(_ fuehler: [Messwert]) -> Bool {
        fuehler.count == fuehlerhoehen.count && fuehler.allSatisfy { $0.value != nil }
    }

    /// Tritt das Glas zurück? (`Bild.tsx:129`)
    ///
    /// Gedimmt auf die halbe Deckkraft, sobald einer der Fühler keine belastbare Zahl trägt:
    /// das Glas zeigt dann eine Schichtung von vorhin, und ein blasses Glas sagt das, ohne
    /// einen zweiten Satz dafür zu brauchen. Leer ist es nicht gedimmt - ein leeres Glas ist
    /// schon leer.
    public static func glasGedimmt(_ fuehler: [Messwert]) -> Bool {
        !fuehler.isEmpty && !fuehler.allSatisfy { $0.belastbar != nil }
    }

    /// Die Zahl an einem Fühler: ganze Grad, ohne Einheit - das Gradzeichen setzt die
    /// Zeichnung eng dahinter (`glas.ts:35-37`).
    public static func gradzahl(_ wert: Double?) -> String? {
        guard let wert, wert.isFinite else { return nil }
        return Formate.zahl(wert.rounded(), stellen: 0)
    }
}
