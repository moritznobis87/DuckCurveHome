import XCTest

@testable import DuckCurveKit

/// Gegen die Vorlage `apps/web/src/components/reports/DataCheck.tsx` mit `CoverageMap.tsx`
/// und `charts.ts` (`powerOverlay`, `yearMap`).
///
/// **Was hier zu prüfen ist.** Vier Dinge, die `DatenbildTests` nicht prüft, weil es sie bis
/// zum 21.11.2026 nicht gab: welcher Satz in welcher Karte steht, solange noch nichts da ist;
/// die Werteauskunft an einer Stelle der Prüfkurve; die Zellenauskunft der Wärmekarte samt der
/// Rückrechnung vom Finger auf die Zelle; und die Adresse der Tagessicherung.
final class DatenpruefungTests: XCTestCase {

    private let tagIso = "2026-11-10"
    private var anfang: Date { Tag.zeitraum("2026-11-10")!.von }

    private func zeit(_ minute: Int) -> Date {
        anfang.addingTimeInterval(Double(minute) * 60)
    }

    private func punkt(
        _ minute: Int, pv: Double? = nil, netz: Double? = nil, zaehler: Double? = nil,
        speicher: Double? = nil, soc: Double? = nil
    ) -> Pruefpunkt {
        Pruefpunkt(
            zeit: zeit(minute), pv: pv, netz: netz, netzZaehler: zaehler, speicher: speicher,
            ladestand: soc)
    }

    private func kurve(_ punkte: [Pruefpunkt]) -> Pruefkurve {
        Pruefkurve.baue(tag: tagIso, raster: punkte)
    }

    // MARK: - Welcher Satz dasteht, solange nichts da ist

    /// Zwei Fragen, vier Lagen: ob geantwortet wurde, und ob etwas darin stand. Ein Tag ohne
    /// Minutenwerte ist etwas anderes als eine gescheiterte Abfrage.
    func testDieLageEinerAbfrageKenntLeerUndGescheitertGetrennt() {
        XCTAssertEqual(Pruefstand.lage(antwortDa: true, inhaltDa: true), .da)
        XCTAssertEqual(Pruefstand.lage(antwortDa: true, inhaltDa: false), .leer)
        XCTAssertEqual(Pruefstand.lage(antwortDa: false, inhaltDa: false), .fehler)
        XCTAssertEqual(
            Pruefstand.lage(antwortDa: false, inhaltDa: true), .fehler,
            "Ohne Antwort gibt es keinen Inhalt, über den zu reden wäre.")
    }

    /// Beim Öffnen der Seite läuft alles, und überall steht „lädt …" - nicht der Befund
    /// (`DataCheck.tsx:83`, `:115`, `CoverageMap.tsx:102`, `Sources.tsx:49`).
    func testBeimOeffnenStehtUeberallDerLadesatzUndKeinBefund() {
        let s = Pruefstand()
        XCTAssertEqual(s.kurvensatz, "lädt …")
        XCTAssertEqual(s.quellensatz, "lädt …")
        XCTAssertEqual(s.rastersatz, "lädt …")
        XCTAssertEqual(s.diagnosesatz, "lädt …")
        XCTAssertNil(s.stoerung, "Eine laufende Abfrage ist keine Störung.")
    }

    /// Ist alles da, steht nirgends ein Satz: dann ist der Inhalt dran.
    func testIstAllesDaStehtNirgendsEinSatz() {
        let s = Pruefstand(kurve: .da, quellen: .da, abdeckung: .da, diagnose: .da)
        XCTAssertNil(s.kurvensatz)
        XCTAssertNil(s.quellensatz)
        XCTAssertNil(s.rastersatz)
        XCTAssertNil(s.diagnosesatz)
        XCTAssertNil(s.stoerung)
    }

    /// Der Leersatz der Hauptkarte ist derselbe wie vorher - nur steht er jetzt erst, wenn
    /// geantwortet wurde (`DataCheck.tsx:83`).
    func testEinTagOhneMinutenwerteNenntDenHistorienimport() {
        let s = Pruefstand(kurve: .leer)
        XCTAssertEqual(s.kurvensatz, Pruefkurve.leersatz)
        XCTAssertTrue(s.kurvensatz?.contains("Historienimport") == true)
    }

    /// **Das Störungsband nur, wenn Verlauf und Diagnose beide scheitern**
    /// (`DataCheck.tsx:41`). Vorher kam es ausschließlich aus der Abdeckung, also genau aus der
    /// Abfrage, die es in der Vorlage nicht auslöst.
    func testDasStoerungsbandStehtNurWennVerlaufUndDiagnoseScheitern() {
        XCTAssertEqual(
            Pruefstand(kurve: .fehler, diagnose: .fehler).stoerung,
            "Daten konnten nicht geladen werden.")
        XCTAssertNil(Pruefstand(kurve: .fehler, diagnose: .da).stoerung)
        XCTAssertNil(Pruefstand(kurve: .da, diagnose: .fehler).stoerung)
        XCTAssertNil(
            Pruefstand(kurve: .da, abdeckung: .fehler, diagnose: .da).stoerung,
            "Eine gescheiterte Abdeckung ersetzt ihre Karte und nicht die Seite.")
    }

    /// Eine gescheiterte Abdeckung schreibt ihren Satz in ihre Karte
    /// (`CoverageMap.tsx:93, 101`); eine Antwort ohne Reihen schreibt keinen - das sagt die
    /// Karte selbst.
    func testDieAbdeckungSchreibtIhrenFehlerInIhreEigeneKarte() {
        XCTAssertEqual(
            Pruefstand(abdeckung: .fehler).rastersatz,
            "Die Verfügbarkeit konnte nicht abgefragt werden.")
        XCTAssertNil(Pruefstand(abdeckung: .leer).rastersatz)
    }

    /// Die Stundenbilanz bleibt in jedem Fall stehen und sagt, was sie hat
    /// (`DataCheck.tsx:115`).
    func testOhneDiagnoseStehtKeineDiagnoseVerfuegbar() {
        XCTAssertEqual(Pruefstand(diagnose: .leer).diagnosesatz, "Keine Diagnose verfügbar.")
        XCTAssertEqual(Pruefstand(diagnose: .fehler).diagnosesatz, "Keine Diagnose verfügbar.")
    }

    /// Ohne Live-Zustand ist der Augenblick nicht abrufbar (`Sources.tsx:48`) - aber erst,
    /// wenn er abgefragt wurde.
    func testDieQuellenSagenErstNachDerAbfrageDassSieNichtAbrufbarSind() {
        XCTAssertEqual(Pruefstand(quellen: .laedt).quellensatz, "lädt …")
        XCTAssertEqual(
            Pruefstand(quellen: .fehler).quellensatz,
            "Der Zustand der Quellen ist gerade nicht abrufbar.")
    }

    // MARK: - Die Uhrzeit einer Stelle

    func testEineStundeSeitTagesbeginnWirdZurUhrzeit() {
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: 0), "00:00")
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: 7.5667), "07:34")
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: 13.5), "13:30")
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: 23 + 59.0 / 60), "23:59")
    }

    /// Die Grenze des Tages liegt auf 00:00 und nicht auf „24:00" - dieselbe Rechnung wie an
    /// der Stundenachse des Bildes (`Int(stunde) % 24`).
    func testDasTagesendeHeisstNullUhrUndNichtVierundzwanzigUhr() {
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: 24), "00:00")
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: 25), "01:00")
    }

    /// Eine Stelle, die keine ist, gibt den Strich der Formate und nicht „00:00" - sonst
    /// stünde eine Uhrzeit da, die niemand gemessen hat.
    func testEineUnzahlGibtKeineUhrzeit() {
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: .nan), "-")
        XCTAssertEqual(Pruefkurve.uhrzeit(stunde: .infinity), "-")
    }

    // MARK: - Die Auskunft zur Prüfkurve

    private var zaehlerkurve: Pruefkurve {
        kurve(
            (0...30).map { m in
                punkt(
                    m, pv: 1.234, netz: -0.5, zaehler: m == 15 ? -0.456 : nil, speicher: 2.0,
                    soc: 0.845)
            })
    }

    /// Alle Reihen zur berührten Minute, in der Reihenfolge der Legende, mit zwei
    /// Nachkommastellen (`charts.ts:591-601`, `de1(…, 2)`).
    func testDieAuskunftNenntAlleReihenZurBeruehrtenMinute() {
        let a = zaehlerkurve.auskunft(stunde: 15.0 / 60)
        XCTAssertEqual(a?.zeit, "00:15")
        XCTAssertEqual(
            a?.zeilen.map(\.reihe), [.pv, .haus, .netz, .netzZaehler, .speicher, .ladestand],
            "Die Reihenfolge der Legende, nicht die der Rechnung.")
        XCTAssertEqual(a?.zeilen.first?.wert, "1,23\u{202F}kW")
    }

    /// **Der Ladestand steht in Prozent und nicht in Kilowatt.** Die Vorlage hängt an jede
    /// Zeile „kW" (`charts.ts:597`), auch an die Reihe, die „Ladestand %" heißt; auf einer
    /// Seite, die Messwerte gegeneinander prüft, ist „84,50 kW" die eine Zahl, die nicht
    /// dastehen darf.
    func testDerLadestandStehtInProzent() {
        let a = zaehlerkurve.auskunft(stunde: 15.0 / 60)
        XCTAssertEqual(a?.zeilen.last?.reihe, .ladestand)
        XCTAssertEqual(a?.zeilen.last?.wert, "84,50\u{202F}%")
        XCTAssertEqual(Pruefkurve.Reihe.ladestand.einheit, "%")
        for reihe in Pruefkurve.Reihe.allCases where reihe != .ladestand {
            XCTAssertEqual(reihe.einheit, "kW")
        }
    }

    /// **Der Zähler erscheint nur an seiner eigenen Minute.** Er meldet alle rund fünfzehn
    /// Minuten; die Vorlage listet nur Reihen mit einem Wert zu *diesem* Zeitstempel
    /// (`charts.ts:596`). Den nächstgelegenen Zählerwert aus sieben Minuten Entfernung
    /// dazuzuschreiben, wäre eine falsche Gegenprobe.
    func testDerZaehlerErscheintNurAnSeinerEigenenMinute() {
        let k = zaehlerkurve
        XCTAssertEqual(
            k.auskunft(stunde: 15.0 / 60)?.zeilen.first { $0.reihe == .netzZaehler }?.wert,
            "\u{2212}0,46\u{202F}kW")
        XCTAssertNil(
            k.auskunft(stunde: 16.0 / 60)?.zeilen.first { $0.reihe == .netzZaehler },
            "Eine Minute daneben ist eine andere Messung.")
        XCTAssertEqual(k.auskunft(stunde: 16.0 / 60)?.zeilen.count, 5)
    }

    /// Eingerastet auf den nächsten gemessenen Punkt: die Zahl, die dasteht, ist gemessen.
    func testDieAuskunftRastetAufDenNaechstenGemessenenPunktEin() {
        let k = kurve([punkt(10, pv: 1), punkt(20, pv: 2)])
        XCTAssertEqual(k.auskunft(stunde: 12.0 / 60)?.zeit, "00:10")
        XCTAssertEqual(k.auskunft(stunde: 17.0 / 60)?.zeit, "00:20")
        XCTAssertEqual(k.auskunft(stunde: 17.0 / 60)?.zeilen.first?.wert, "2,00\u{202F}kW")
    }

    /// Zwei Nachkommastellen, und zwar echte: ``Formate/kw(_:stellen:)`` macht aus 0,03 kW
    /// eine Null, damit die Wand keine Einspeisung sieht, die es nicht gibt. Hier ist gerade
    /// diese Null die Nachricht - zwischen Wandler und Zähler liegt der Unterschied oft in
    /// Hundertsteln.
    func testKleineWerteWerdenNichtZuNullGerundet() {
        let k = kurve([punkt(0, pv: 0.03, netz: 0.04)])
        let zeilen = k.auskunft(stunde: 0)?.zeilen ?? []
        XCTAssertEqual(zeilen.first { $0.reihe == .pv }?.wert, "0,03\u{202F}kW")
        XCTAssertEqual(zeilen.first { $0.reihe == .netz }?.wert, "0,04\u{202F}kW")
        XCTAssertEqual(Formate.kw(0.03, stellen: 2), "0,00", "Der Grund, warum sie es nicht ist.")
    }

    func testEineLeereKurveGibtKeineAuskunft() {
        XCTAssertNil(Pruefkurve().auskunft(stunde: 12))
        XCTAssertNil(kurve([]).auskunft(stunde: 12))
        XCTAssertNil(zaehlerkurve.auskunft(stunde: .nan))
    }

    /// Gerechnet wird auf der Kurve, die gezeichnet ist: über den ganzen Tag ist das die
    /// verdichtete. Eine Auskunft, die eine andere Zahl nennt als die Linie darunter zeigt,
    /// wäre auf dieser Seite die schlimmste.
    func testDieAuskunftFolgtDerVerdichtetenKurve() {
        let k = kurve((0..<10).map { punkt($0, pv: Double($0)) }).verdichtet(schrittMin: 5)
        let a = k.auskunft(stunde: 2.0 / 60)
        XCTAssertEqual(a?.zeit, "00:00")
        XCTAssertEqual(a?.zeilen.first?.wert, "2,00\u{202F}kW", "Der Mittel der Minuten 0 bis 4.")
    }

    // MARK: - Das Zeitfenster um eine Stelle

    func testDasFensterLiegtMittigUmDieStelle() {
        let k = kurve([punkt(0, pv: 1)])
        XCTAssertEqual(k.fensterUm(12, breiteH: 2), 11...13)
        XCTAssertEqual(k.fensterUm(12, breiteH: 6), 9...15)
    }

    /// **Am Tagesrand verschiebt sich das Fenster, statt zu schrumpfen.** Ein halbes Fenster um
    /// 23:50 zeigte die halbe Auflösung - und wer dort nachsieht, sucht gerade die Strecke am
    /// Rand.
    func testAmTagesrandVerschiebtSichDasFensterStattZuSchrumpfen() {
        let k = kurve([punkt(0, pv: 1)])
        XCTAssertEqual(k.fensterUm(0.2, breiteH: 3), 0...3)
        XCTAssertEqual(k.fensterUm(23.8, breiteH: 3), 21...24)
    }

    /// Eine Breite über dem Tag gibt den Tag; eine Breite von null gibt ihn auch - ein Fenster
    /// ohne Breite wäre ein Bild ohne Punkte.
    func testEineUnmoeglicheBreiteGibtDenGanzenTag() {
        let k = kurve([punkt(0, pv: 1)])
        XCTAssertEqual(k.fensterUm(12, breiteH: 40), 0...24)
        XCTAssertEqual(k.fensterUm(12, breiteH: 0), 0...24)
        XCTAssertEqual(k.fensterUm(12, breiteH: -3), 0...24)
    }

    /// Drei Knöpfe, drei Breiten - und das schmale Leerzeichen vor der Einheit, wie überall.
    func testDieDreiFensterbreitenUndIhreWorte() {
        XCTAssertEqual(Pruefkurve.fensterbreiten.map(\.stunden), [1, 3, 6])
        XCTAssertEqual(
            Pruefkurve.fensterbreiten.map(\.wort),
            ["1\u{202F}h", "3\u{202F}h", "6\u{202F}h"])
    }

    // MARK: - Die Auskunft zu einer Zelle der Wärmekarte

    private var raster: Abdeckungsraster {
        Abdeckungsraster(
            schluessel: "bridge", name: "Haus (Bridge)",
            tage: [
                Abdeckungsraster.Rastertag(
                    tag: "2026-11-10",
                    stunden: (0..<24).map { h in h == 7 ? 42 : (h == 8 ? nil : 60) }),
                Abdeckungsraster.Rastertag(tag: "2026-11-11", stunden: Array(repeating: 60, count: 24)),
            ],
            abdeckung: 0.998, unvollstaendigeStunden: 2, laengsterAusfallH: 1)
    }

    /// Tag, Stunde, Wert - die drei Zeilen des Hinweisfensters der Vorlage
    /// (`charts.ts:470-483`), mit null Nachkommastellen und „min".
    func testDieZellenauskunftNenntTagStundeUndMinuten() {
        let a = raster.auskunft(tag: 0, stunde: 7)
        XCTAssertEqual(a?.tag, "Di., 10. November 2026")
        XCTAssertEqual(a?.stunde, "07:00 - 07:59")
        XCTAssertEqual(a?.wert, "42\u{202F}min")
        XCTAssertFalse(a?.leer == true)
    }

    /// **Leer ist nicht null, und das ist die Auskunft, um die es geht**
    /// (`CoverageMap.tsx:24-27`). Die Vorlage sagt an einer leeren Zelle nichts, weil ihr
    /// Zeiger dort keinen Datenpunkt findet; der Finger auf einem `Canvas` trifft jede Stelle.
    func testEineZelleOhneMinutenzeileSagtDasAuch() {
        let a = raster.auskunft(tag: 0, stunde: 8)
        XCTAssertEqual(a?.stunde, "08:00 - 08:59")
        XCTAssertEqual(a?.wert, "keine Minutenzeile")
        XCTAssertTrue(a?.leer == true)
    }

    func testEineZelleAusserhalbDesRastersGibtKeineAuskunft() {
        XCTAssertNil(raster.auskunft(tag: 2, stunde: 0))
        XCTAssertNil(raster.auskunft(tag: -1, stunde: 0))
        XCTAssertNil(raster.auskunft(tag: 0, stunde: 24))
        XCTAssertNil(raster.auskunft(tag: 0, stunde: -1))
    }

    // MARK: - Welche Zelle unter dem Finger liegt

    /// Dieselbe Rechnung wie beim Malen, nur zurück: 28 Spalten auf 280 Punkten mit einem
    /// Punkt Fuge sind 9,03 Punkte je Spalte.
    func testDieSpaltenbreiteIstDieDesZeichnens() {
        XCTAssertEqual(
            Abdeckungsraster.spaltenbreite(gesamt: 280, spalten: 28, luecke: 1),
            (280 - 27) / 28, accuracy: 1e-9)
        XCTAssertEqual(
            Abdeckungsraster.spaltenbreite(gesamt: 10, spalten: 28, luecke: 1), 1,
            "Unter einem Punkt wird keine Spalte - dann überlappen sie, wie beim Malen.")
        XCTAssertEqual(Abdeckungsraster.spaltenbreite(gesamt: 280, spalten: 0, luecke: 1), 0)
    }

    func testDerFingerTrifftSpalteUndStunde() {
        let t = { (x: Double, y: Double) in
            Abdeckungsraster.treffer(
                x: x, y: y, gesamt: 280, spalten: 28, zellenhoehe: 9, luecke: 1)
        }
        XCTAssertEqual(t(0, 0), Abdeckungsraster.Treffer(tag: 0, stunde: 0))
        // Spaltenschritt 10,03; die vierte Spalte beginnt bei 30,1.
        XCTAssertEqual(t(31, 0)?.tag, 3)
        // Zeilenschritt 10: die achte Zeile beginnt bei 70.
        XCTAssertEqual(t(0, 71), Abdeckungsraster.Treffer(tag: 0, stunde: 7))
        XCTAssertEqual(t(279, 239), Abdeckungsraster.Treffer(tag: 27, stunde: 23))
    }

    /// **Die Fuge zählt zur Spalte links davon.** Ein Punkt Luft gegen einen Finger von
    /// vierzig: „daneben getroffen, also keine Auskunft" wäre an einer Stelle, die man nicht
    /// sehen kann, die falsche Strenge.
    func testDieFugeZwischenZweiSpaltenGehoertDerLinken() {
        // Spalte 0 reicht von 0 bis 9,03, die Fuge bis 10,03.
        XCTAssertEqual(
            Abdeckungsraster.treffer(
                x: 9.5, y: 0, gesamt: 280, spalten: 28, zellenhoehe: 9, luecke: 1)?.tag, 0)
    }

    /// Außerhalb des Kastens gibt es keine Zelle: dort steht die Achse.
    func testAusserhalbDesKastensGibtEsKeineZelle() {
        let t = { (x: Double, y: Double) in
            Abdeckungsraster.treffer(
                x: x, y: y, gesamt: 280, spalten: 28, zellenhoehe: 9, luecke: 1)
        }
        XCTAssertNil(t(-1, 10))
        XCTAssertNil(t(10, -1))
        XCTAssertNil(t(281, 10), "Rechts vom Kasten ist keine Spalte mehr.")
        XCTAssertNil(t(280.5, 10), "Auch nicht einen halben Punkt daneben.")
        XCTAssertNil(t(10, 241), "Eine fünfundzwanzigste Stunde gibt es nicht.")
        XCTAssertNil(t(10, 239.5), "Unter dem Kasten steht die Tagesachse.")
        XCTAssertNil(t(.nan, 0))
        XCTAssertNil(
            Abdeckungsraster.treffer(
                x: 5, y: 5, gesamt: 0, spalten: 28, zellenhoehe: 9, luecke: 1),
            "Ein Kasten ohne Breite ist noch nicht vermessen.")
    }

    // MARK: - Die Adresse der Tagessicherung

    private var zugang: Zugang {
        Zugang(
            grund: URL(string: "https://dch.beispiel.net")!, token: "geheim",
            geraetename: "iPad Flur")
    }

    /// `docs/openapi.json`, `/api/v1/export/{kind}`: neben `year` auch `start` und `end` als
    /// `date-time`. Die Vorlage ruft genau das (`DataCheck.tsx:52-56`).
    func testDieAdresseDerTagessicherungTraegtAnfangUndEnde() {
        let adresse = zugang.export(art: .minuten, tag: "2026-11-10")?.absoluteString
        XCTAssertEqual(
            adresse,
            "https://dch.beispiel.net/api/v1/export/minutes"
                + "?end=2026-11-10T23:00:00Z&start=2026-11-09T23:00:00Z",
            "Die Grenzen sind die der Hauszeit, in UTC geschrieben - im November eine Stunde.")
    }

    /// **Die Grenzen kommen aus dem Kalender des Hauses.** Am 25.10.2026 endet die Sommerzeit;
    /// der Tag hat 25 Stunden. Eine Adresse aus Mitternacht plus 86400 Sekunden - so rechnet
    /// die Vorlage (`DataCheck.tsx:22-25`) - schnitte die letzte Stunde ab, und auf einer
    /// Seite, die Lücken in Messreihen sucht, wäre das die Lücke, die man selbst macht.
    func testDerTagDerZeitumstellungIstFuenfundzwanzigStundenLang() {
        let adresse = zugang.export(art: .minuten, tag: "2026-10-25")?.absoluteString ?? ""
        XCTAssertTrue(adresse.contains("start=2026-10-24T22:00:00Z"), adresse)
        XCTAssertTrue(adresse.contains("end=2026-10-25T23:00:00Z"), adresse)
    }

    func testEinVerdrehterOderUnbekannterZeitraumGibtKeineAdresse() {
        let z = Tag.zeitraum("2026-11-10")!
        XCTAssertNil(zugang.export(art: .minuten, von: z.bis, bis: z.von))
        XCTAssertNil(zugang.export(art: .minuten, von: z.von, bis: z.von))
        XCTAssertNil(zugang.export(art: .minuten, tag: "kein Tag"))
    }

    /// Wer die App auf das BFF des Dashboards zeigt, bekommt dessen Adresse - dasselbe wie bei
    /// der Jahressicherung (``Zugangsworte/herunterladen``).
    func testDieTagessicherungGehtAuchUeberDasBff() {
        var z = zugang
        z.praefix = "/api/dch"
        XCTAssertEqual(
            z.export(art: .minuten, tag: "2026-11-10")?.absoluteString.hasPrefix(
                "https://dch.beispiel.net/api/dch/export/minutes?"), true)
    }

    // MARK: - Die Worte

    /// Wörtlich wie die Vorlage (`DataCheck.tsx:41`, `:83`, `:106`, `:115`).
    func testDieVierSaetzeDerVorlageStehenWoertlichDa() {
        XCTAssertEqual(Pruefworte.laedt, "lädt …")
        XCTAssertEqual(Pruefworte.ladefehler, "Daten konnten nicht geladen werden.")
        XCTAssertEqual(Pruefworte.keineDiagnose, "Keine Diagnose verfügbar.")
        XCTAssertEqual(Pruefworte.csvVerweis, "Minutenwerte dieses Tages als CSV ›")
        XCTAssertEqual(Pruefworte.ganzerTag, "Ganzer Tag")
    }

    /// Die zwei eigenen Hinweise der App: ohne Zeiger muss die Geste angekündigt werden.
    func testDieZweiHinweiseAufDieGesteNennenWasManErfaehrt() {
        XCTAssertEqual(Pruefworte.beruehrung, "Zum Lesen einer Minute die Fläche berühren.")
        XCTAssertEqual(
            Abdeckungsraster.beruehrung, "Zum Lesen einer Stunde die Karte berühren.")
    }



    // MARK: - Die Lücke in der Erzeugungsreihe

    /// Ohne Lücke kein Satz - und eine Nacht ohne Sonne ist keine Lücke.
    func testOhneLueckeStehtKeinSatz() {
        XCTAssertNil(Pruefworte.erzeugungsluecke(nil))
        let ganz = kurve((0..<60).map { punkt($0, pv: 1, netz: 1) })
        XCTAssertNil(Pruefworte.erzeugungsluecke(ganz.luecken()))
    }

    /// **Zwei Befunde, zwei Sätze.** Steht das Netz mit still, kann es eine Wolke gewesen sein;
    /// läuft es weiter, liefert der Zähler und die Erzeugungsmessung nicht
    /// (`DataCheck.tsx:142-146`).
    func testDerSatzUnterscheidetDieWolkeVonDerFehlendenMessung() {
        let wolke = kurve(
            (0..<60).map { m in punkt(m, pv: (10...20).contains(m) ? 0 : 1, netz: 1) })
        let satz = Pruefworte.erzeugungsluecke(wolke.luecken())
        XCTAssertEqual(wolke.luecken()?.befund, .luecke)
        XCTAssertTrue(satz?.contains("Wolke") == true, satz ?? "nil")
        XCTAssertTrue(satz?.contains("11\u{202F}Minuten") == true, satz ?? "nil")
        XCTAssertTrue(satz?.contains("00:00 und 00:59") == true, satz ?? "nil")

        let fehlt = kurve(
            (0..<60).map { m in
                punkt(m, pv: (10...20).contains(m) ? 0 : 1, netz: Double(m) * 0.1)
            })
        let satz2 = Pruefworte.erzeugungsluecke(fehlt.luecken())
        XCTAssertEqual(fehlt.luecken()?.befund, .lueckeMitNetzbewegung)
        XCTAssertTrue(satz2?.contains("Netzladung") == true, satz2 ?? "nil")
        XCTAssertFalse(satz2?.contains("Wolke") == true, satz2 ?? "nil")
    }

    /// Die Sätze der Karten wie im Dashboard (`DataCheck.tsx`, `PRUEFSAETZE`, `datacheck.test.ts`).
    func testDieKartensaetzeSagenDasselbeWieDasDashboard() {
        XCTAssertEqual(
            Pruefworte.leistungen,
            "Bezug und Entladen zählen positiv, Einspeisung und Laden negativ; der Ladestand steht rechts in Prozent.")
        XCTAssertEqual(Pruefworte.quellen, "Was gerade liefert und was ausbleibt.")
        XCTAssertEqual(Pruefworte.abdeckung(tage: 28), "Minuten je Stunde über 28 Tage, von 0 bis 60.")
        XCTAssertEqual(
            Abdeckungsraster.lesehilfe,
            "Ohne Farbe stand der Dienst still. Rot heißt, das Gerät hat in dieser Stunde nichts geliefert.")
    }
}
