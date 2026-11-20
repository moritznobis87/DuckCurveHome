import XCTest

@testable import DuckCurveKit

/// Was die Technikseite der Wärmepumpe rechnet: ``Wpseite``.
///
/// **Diese Tests sind die einzige Prüfung, die diese Seite hat.** Die Oberfläche lässt sich
/// hier nicht übersetzen, nur parsen - also muss jede Schwelle, jede Rundung, jede
/// Textauswahl und jede Farbzuordnung hier stehen und hier geprüft werden. Geprüft wird
/// gegen die Vorlage (`apps/web/src/components/waermepumpe/`), nicht gegen das, was
/// vernünftig aussieht: wo die Vorlage anders rundet, als man es täte, steht das als eigener
/// Fall da.
final class WpseiteTests: XCTestCase {
    private let schmal = Formate.schmalesLeerzeichen
    private let minus = Formate.minus

    private func m(_ v: Double?, _ g: Quality = .ok) -> Messwert {
        Messwert(value: v, observedAt: "2026-11-20T14:05:00+01:00", quality: g, source: "test")
    }

    /// Eine Wärmepumpe mit allem, was die Vorlage kennt - die Felder, die ein Fall braucht,
    /// werden einzeln überschrieben.
    private func wp(
        laeuft: Bool = true,
        now: String = "2026-11-20T14:05:00+01:00",
        zustandDe: String = "heizt",
        zaehler: Messwert? = nil,
        bus: Messwert? = nil,
        waerme: Double? = 6.3,
        arbeitszahl: Double? = 3.42,
        spreizung: Double? = 5.3,
        heizanforderung: Bool? = nil,
        raumSoll: Messwert? = nil,
        ventil: Int? = nil,
        heizstab: Int? = nil,
        verdichterA: Messwert? = nil,
        zusatz: Double? = nil,
        kreis: Int? = nil,
        puffer: [Messwert] = []
    ) -> WaermepumpeOut {
        WaermepumpeOut(
            now: now, laeuft: laeuft, zustandDe: zustandDe,
            aussenC: m(4.2), verdampferC: m(1.1), sauggasC: m(3.4), heissgasC: m(68),
            fluessigC: m(31.5), verdichterHz: m(54),
            leistungBusKw: bus ?? m(nil, .unavailable),
            leistungZaehlerKw: zaehler ?? m(nil, .unavailable),
            vorlaufC: m(38.4), ruecklaufC: m(33.1), durchflussLMin: m(17.2),
            vorlaufSollC: m(39), speicherfuehlerC: m(44.8), pufferC: puffer,
            spreizungK: spreizung, waermeleistungKw: waerme, arbeitszahl: arbeitszahl,
            heizanforderung: heizanforderung, raumSollC: raumSoll, zusatzKw: zusatz,
            ventilCode: ventil, heizstabCode: heizstab, verdichterA: verdichterA,
            kreisCode: kreis
        )
    }

    private func zeile(
        code: Int = 2, minuten: Int = 480, lauf: Int = 312,
        vorlauf: Double? = 38.4, soll: Double? = 39.0,
        oben: Double? = 1.84, unten: Double? = -0.44, zusatz: Double? = 2.41,
        heiz: Double? = 0.92, flag: Double? = 0.0, ventil: Double? = 0.5,
        heizstab: Double? = 0.004, angefordert: Double? = 1.0
    ) -> ReglerKennzahlOut {
        ReglerKennzahlOut(
            code: code, minuten: minuten, laufMin: lauf, vorlaufC: vorlauf, vorlaufSollC: soll,
            obenKH: oben, untenKH: unten, angefordertAnteil: angefordert, zusatzKw: zusatz,
            heizanforderungAnteil: heiz, flag1b45Anteil: flag, ventil1Anteil: ventil,
            heizstabAnteil: heizstab)
    }

    // MARK: - Zahlen, die ein Fragezeichen kennen

    /// `bild.ts:82-85`: „ein fehlender Wert ist keine Null“ - und auch kein Strich.
    func testFehlenderWertStehtAlsFragezeichenUndNichtAlsStrich() {
        XCTAssertEqual(Wpseite.zahl(nil), "?")
        XCTAssertEqual(Wpseite.celsius(nil), "?")
        XCTAssertEqual(Wpseite.anteil(nil), "?")
        XCTAssertEqual(Wpseite.mitVorzeichen(nil), "?")
        XCTAssertEqual(Wpseite.kelvinJeStunde(nil), "?")
        XCTAssertEqual(Wpseite.kilowatt(nil), "?")
        XCTAssertNotEqual(Wpseite.zahl(nil), Formate.leer)
    }

    func testEineZahlNichtEndlichIstAuchEinFehlenderWert() {
        XCTAssertEqual(Wpseite.zahl(Double.nan), "?")
        XCTAssertEqual(Wpseite.zahl(Double.infinity), "?")
        XCTAssertEqual(Wpseite.celsius(Double.nan), "?")
        XCTAssertEqual(Wpseite.anteil(Double.nan), "?")
        XCTAssertEqual(Wpseite.mitVorzeichen(Double.nan), "?")
    }

    func testZahlUndCelsiusSchreibenKommaUndSchmalesLeerzeichen() {
        XCTAssertEqual(Wpseite.zahl(6.25), "6,3")
        XCTAssertEqual(Wpseite.zahl(1.844, stellen: 2), "1,84")
        XCTAssertEqual(Wpseite.celsius(38.44), "38,4" + schmal + "°C")
        XCTAssertEqual(Wpseite.celsius(38.0, stellen: 0), "38" + schmal + "°C")
    }

    /// `Kennzahlen.tsx:17`: `${n >= 0 ? "+" : "−"}${Math.abs(n).toFixed(1)}` - das Zeichen
    /// kommt vom rohen Wert, der Betrag vom gerundeten.
    func testVorzeichenStehtImmerDaUndKommtVomRohenWert() {
        XCTAssertEqual(Wpseite.mitVorzeichen(1.84), "+1,8")
        XCTAssertEqual(Wpseite.mitVorzeichen(0), "+0,0")
        XCTAssertEqual(Wpseite.mitVorzeichen(-0.44), minus + "0,4")
        XCTAssertEqual(Wpseite.mitVorzeichen(-2.55), minus + "2,6")
    }

    /// **Der Unterschied zu ``Formate/zahl(_:stellen:)``, ausdrücklich festgehalten.** Dort
    /// fällt das Minus an einer zu Null gerundeten Zahl weg; hier bleibt es stehen, weil in
    /// einer Spalte voller Vorzeichen ein fehlendes selbst eine Aussage wäre.
    func testEinZuNullGerundeterWertBehaeltHierSeinMinus() {
        XCTAssertEqual(Formate.zahl(-0.04, stellen: 1), "0,0")
        XCTAssertEqual(Wpseite.mitVorzeichen(-0.04), minus + "0,0")
        XCTAssertEqual(Wpseite.mitVorzeichen(0.04), "+0,0")
    }

    /// `Kennzahlen.tsx:19`: `Math.round(n * 100)` - ganze Prozent, nichts dazwischen.
    func testAnteilRundetAufGanzeProzent() {
        XCTAssertEqual(Wpseite.anteil(0.5), "50" + schmal + "%")
        XCTAssertEqual(Wpseite.anteil(1), "100" + schmal + "%")
        XCTAssertEqual(Wpseite.anteil(0), "0" + schmal + "%")
        XCTAssertEqual(Wpseite.anteil(0.004), "0" + schmal + "%")
        XCTAssertEqual(Wpseite.anteil(0.925), "93" + schmal + "%")
    }

    // MARK: - Die Standzeile

    /// `Waermepumpe.tsx:68-78`: die Teile mit „ · “ verkettet, in dieser Reihenfolge.
    func testStandzeileVerkettetAlleTeileInDerReihenfolgeDerVorlage() {
        let s = Wpseite.standzeile(
            wp(heizanforderung: true, raumSoll: m(21.5), ventil: 1, heizstab: 0,
               verdichterA: m(7.4)))
        XCTAssertEqual(
            s,
            "Stand 14:05 · Heizanforderung an · Raum-Sollwert 21,5" + schmal + "°C"
                + " · Umschaltventil Stellung 1 · Heizstab meldet 0"
                + " · Verdichter 7,4" + schmal + "A")
    }

    /// Ohne jede Vorgabe des Reglers bleibt nur die Uhrzeit - kein leeres „ · “ am Ende.
    func testStandzeileOhneVorgabenIstNurDerStand() {
        XCTAssertEqual(Wpseite.standzeile(wp()), "Stand 14:05")
    }

    /// `:72`: „aus“ und nicht weggelassen - `false` ist eine Auskunft.
    func testHeizanforderungAusStehtDaUndFaelltNichtWeg() {
        XCTAssertTrue(Wpseite.standzeile(wp(heizanforderung: false))
            .contains("Heizanforderung aus"))
    }

    /// `:74`: Stellung 0 ist eine Stellung. Eine Prüfung auf „wahr“ statt auf „vorhanden“
    /// hätte genau diese weggelassen - und 0 heißt beim Ventil Warmwasser.
    func testVentilstellungNullStehtDa() {
        XCTAssertTrue(Wpseite.standzeile(wp(ventil: 0)).contains("Umschaltventil Stellung 0"))
        XCTAssertTrue(Wpseite.standzeile(wp(heizstab: 0)).contains("Heizstab meldet 0"))
    }

    /// `:71-74`: hier zählt `value` und nicht die Güte - die Zeile berichtet, was der Regler
    /// gesendet hat, und ein Sollwert von vorhin bleibt eine Vorgabe von vorhin.
    func testStandzeileNimmtAuchEinenVeraltetenSollwert() {
        let s = Wpseite.standzeile(wp(raumSoll: m(21.5, .stale), verdichterA: m(7.4, .stale)))
        XCTAssertTrue(s.contains("Raum-Sollwert 21,5"))
        XCTAssertTrue(s.contains("Verdichter 7,4"))
    }

    func testEinFehlendesFeldFaelltAusDerStandzeileGanzHeraus() {
        let s = Wpseite.standzeile(wp(raumSoll: m(nil, .unavailable)))
        XCTAssertFalse(s.contains("Raum-Sollwert"))
        XCTAssertFalse(s.contains("?"))
    }

    /// `:77`: der Fehler wandert in die Standzeile, sobald schon ein Stand dasteht.
    func testFehlertextStehtAmEndeDerStandzeile() {
        let s = Wpseite.standzeile(wp(), fehler: "Die Wärmepumpe ist gerade nicht zu erreichen.")
        XCTAssertEqual(s, "Stand 14:05 · Die Wärmepumpe ist gerade nicht zu erreichen.")
        XCTAssertEqual(Wpseite.standzeile(wp(), fehler: ""), "Stand 14:05")
    }

    func testEinUnlesbarerZeitstempelGibtDenStrichUndNichtEinenAbsturz() {
        XCTAssertEqual(Wpseite.standzeile(wp(now: "gestern")), "Stand " + Formate.leer)
    }

    // MARK: - Die vier Kennzahlen

    /// `Waermepumpe.tsx:93-98`: vier, in dieser Reihenfolge, mit diesen Worten.
    func testVierKennzahlenInDerReihenfolgeDerVorlage() {
        let k = Wpseite.kennzahlen(wp(zaehler: m(1.84)))
        XCTAssertEqual(k.count, 4)
        XCTAssertEqual(k.map(\.wort), ["Wärmeleistung", "Strom, Zähler", "Arbeitszahl", "Spreizung"])
        XCTAssertEqual(k.map(\.einheit), ["kW", "kW", nil, "K"])
    }

    /// `:94`/`:96` eine Stelle, `:95` zwei - die Stellen der Vorlage und nicht die runderen.
    func testStellenSindDieDerVorlage() {
        let k = Wpseite.kennzahlen(wp(zaehler: m(1.844), waerme: 6.25, arbeitszahl: 3.449))
        XCTAssertEqual(k[0].wert, "6,3")
        XCTAssertEqual(k[1].wert, "1,84")
        XCTAssertEqual(k[2].wert, "3,4")
        XCTAssertEqual(k[3].wert, "5,3")
    }

    /// `:94`: nur die Wärmeleistung trägt Farbe, und nur solange sie eine Zahl ist.
    func testNurDieWaermeleistungIstAmberUndEinFehlenderWertIstGedaempft() {
        let voll = Wpseite.kennzahlen(wp(zaehler: m(1.84)))
        XCTAssertEqual(voll.map(\.ton), [.bernstein, .normal, .normal, .normal])

        let leer = Wpseite.kennzahlen(wp(waerme: nil, arbeitszahl: nil, spreizung: nil))
        XCTAssertEqual(leer.map(\.ton), [.gedaempft, .gedaempft, .gedaempft, .gedaempft])
        XCTAssertEqual(leer.map(\.wert), ["?", "?", "?", "?"])
    }

    /// `:94`: der Hinweis wechselt mit `laeuft` - „nur bei laufender Maschine“ ist die
    /// Erklärung dafür, dass dort ein Fragezeichen steht.
    func testHinweisDerWaermeleistungHaengtAmLauf() {
        XCTAssertEqual(Wpseite.kennzahlen(wp(laeuft: true))[0].dazu, "Durchfluss mal Spreizung")
        XCTAssertEqual(
            Wpseite.kennzahlen(wp(laeuft: false))[0].dazu, "nur bei laufender Maschine")
    }

    func testDieDreiHinweiseStehenWoertlichDa() {
        let k = Wpseite.kennzahlen(wp())
        XCTAssertNil(k[1].dazu)
        XCTAssertEqual(k[2].dazu, "Wärme je Strom, im Augenblick")
        XCTAssertEqual(k[3].dazu, "Vorlauf minus Rücklauf")
    }

    /// `bild.ts:90-94`: der Zähler führt, der Bus hilft aus - und ohne beide heißt die Kachel
    /// nur „Strom“.
    func testDerNameDerStromkachelNenntDieQuelle() {
        XCTAssertEqual(Wpseite.kennzahlen(wp(zaehler: m(1.84), bus: m(1.92)))[1].wort,
                       "Strom, Zähler")
        XCTAssertEqual(Wpseite.kennzahlen(wp(bus: m(1.92)))[1].wort, "Strom, laut Maschine")
        XCTAssertEqual(Wpseite.kennzahlen(wp())[1].wort, "Strom")
    }

    /// Ein veralteter Zähler ist kein Zähler: ``Wpbild/aufnahme(_:)`` fällt dann auf den Bus,
    /// und die Kachel sagt das in ihrem Namen.
    func testEinVeralteterZaehlerFaelltAufDenBusZurueck() {
        let k = Wpseite.kennzahlen(wp(zaehler: m(1.84, .stale), bus: m(1.92)))
        XCTAssertEqual(k[1].wort, "Strom, laut Maschine")
        XCTAssertEqual(k[1].wert, "1,92")
    }

    // MARK: - Die Reglertabelle

    /// `Kennzahlen.tsx:55-67`: dreizehn Spalten, wörtlich und in dieser Reihenfolge - zwölf
    /// hier, denn die Kennzahl selbst beschriftet die Zeile.
    func testZwoelfSpaltennamenWoertlichUndInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            Wpseite.spaltennamen,
            [
                "Minuten", "davon Lauf", "Vorlauf", "Sollwert", "Speicher oben",
                "Speicher Mitte unten", "Zähler über Maschine", "Heizanforderung",
                "Kennung 1b45", "Ventil auf 1", "Heizstab gemeldet", "angefordert",
            ])
    }

    /// `:76-87`: je Zelle das Format, das die Vorlage dort setzt.
    func testDieZwoelfZellenEinerZeile() {
        XCTAssertEqual(
            Wpseite.zellen(zeile()),
            [
                "480", "312",
                "38,4" + schmal + "°C", "39,0" + schmal + "°C",
                "+1,8" + schmal + "K/h", minus + "0,4" + schmal + "K/h",
                "+2,4" + schmal + "kW",
                "92" + schmal + "%", "0" + schmal + "%", "50" + schmal + "%",
                "0" + schmal + "%", "100" + schmal + "%",
            ])
    }

    /// `:76-87`: fehlt ein Wert, steht in dieser Zelle „?“ - und nur in dieser.
    func testEineZeileOhneWerteStehtVollerFragezeichenAberBehaeltIhreMinuten() {
        let z = Wpseite.zellen(
            zeile(minuten: 7, lauf: 0, vorlauf: nil, soll: nil, oben: nil, unten: nil,
                  zusatz: nil, heiz: nil, flag: nil, ventil: nil, heizstab: nil,
                  angefordert: nil))
        XCTAssertEqual(z.count, Wpseite.spaltennamen.count)
        XCTAssertEqual(z[0], "7")
        XCTAssertEqual(z[1], "0")
        XCTAssertEqual(Array(z.dropFirst(2)), Array(repeating: "?", count: 10))
    }

    /// `:77-78`: die Minuten stehen roh da - keine Einheit, kein Tausenderpunkt.
    func testMinutenStehenOhneEinheitUndOhneTausenderpunkt() {
        let z = Wpseite.zellen(zeile(minuten: 10080, lauf: 1234))
        XCTAssertEqual(z[0], "10080")
        XCTAssertEqual(z[1], "1234")
    }

    /// `:83`: eine Differenz, nicht eine Leistung - sie behält ihr Vorzeichen, und ein
    /// kleiner Wert wird nicht auf Null gezogen, wie ``Formate/kw(_:stellen:)`` es täte.
    func testZaehlerUeberMaschineBehaeltVorzeichenUndKleineWerte() {
        XCTAssertEqual(Wpseite.kilowatt(-0.3), minus + "0,3" + schmal + "kW")
        XCTAssertEqual(Formate.kw(-0.03), "0,0")
        XCTAssertEqual(Wpseite.kilowatt(-0.03), minus + "0,0" + schmal + "kW")
    }

    /// `:72-75`: „{code} · jetzt“ an der Kennzahl, die der Regler gerade sendet.
    func testNurDieLaufendeKennzahlTraegtDenZusatzJetzt() {
        XCTAssertEqual(Wpseite.zeilenname(zeile(code: 2), aktuell: 2), "2 · jetzt")
        XCTAssertEqual(Wpseite.zeilenname(zeile(code: 0), aktuell: 2), "0")
        XCTAssertTrue(Wpseite.istAktuell(zeile(code: 2), aktuell: 2))
        XCTAssertFalse(Wpseite.istAktuell(zeile(code: 0), aktuell: 2))
    }

    /// Ohne Auskunft über den laufenden Kreis ist keine Zeile die laufende - und nicht etwa
    /// die mit der Kennzahl 0.
    func testOhneBekanntenKreisIstKeineZeileDieLaufende() {
        XCTAssertFalse(Wpseite.istAktuell(zeile(code: 0), aktuell: nil))
        XCTAssertEqual(Wpseite.zeilenname(zeile(code: 0), aktuell: nil), "0")
    }

    func testSpaltenTragenJeZeileEineZelleInZeilenreihenfolge() {
        let zeilen = [zeile(code: 0, minuten: 120, lauf: 0), zeile(code: 2)]
        let s = Wpseite.spalten(zeilen)
        XCTAssertEqual(s.count, Wpseite.spaltennamen.count)
        XCTAssertEqual(s.map(\.name), Wpseite.spaltennamen)
        for spalte in s {
            XCTAssertEqual(spalte.zellen.count, zeilen.count)
        }
        XCTAssertEqual(s[0].zellen, ["120", "480"])
        XCTAssertEqual(s[1].zellen, ["0", "312"])
    }

    /// `Kennzahlen.tsx:43`: ohne Zeilen verschwindet die Karte - die Spalten dürfen dabei
    /// nicht in einen leeren Zugriff laufen.
    func testOhneZeilenGibtEsLeereSpaltenUndKeinenAbsturz() {
        let s = Wpseite.spalten([])
        XCTAssertEqual(s.count, Wpseite.spaltennamen.count)
        XCTAssertTrue(s.allSatisfy { $0.zellen.isEmpty })
    }

    func testUeberschriftUndDieZweiErklaerabsaetze() {
        XCTAssertEqual(Wpseite.tabellentitel(tage: 7), "Was der Regler meldet, letzte 7 Tage")
        XCTAssertTrue(Wpseite.einleitung.contains("0 (Bereitschaft) und 2 (Heizen)"))
        XCTAssertTrue(Wpseite.nachsatz.contains("mehrere Kilowatt sprechen für den Heizstab"))
        XCTAssertTrue(Wpseite.nachsatz.contains("Kennung 1b45"))
    }

    /// Die deutschen Anführungszeichen stehen paarweise: so viele „ wie “.
    func testDeutscheAnfuehrungszeichenStehenPaarweise() {
        for satz in [Wpseite.nachsatz, Wpseite.einleitung] {
            XCTAssertEqual(
                satz.filter { $0 == "\u{201E}" }.count,
                satz.filter { $0 == "\u{201C}" }.count,
                "Anführungszeichen ohne Partner")
        }
    }

    /// `Kennzahlen.tsx:34-35` gegen `Waermepumpe.tsx:25`: zwei Abrufe, zwei Takte.
    func testZweiTakteFuenfMinutenUndZehnSekunden() {
        XCTAssertEqual(Wpseite.kennzahlenTakt, 300)
        XCTAssertEqual(Wpseite.takt, 10)
        XCTAssertEqual(Wpseite.kennzahlenTage, 7)
    }

    // MARK: - Die Absätze und die Verweise

    func testDieWoertlichenSaetzeDerVorlage() {
        XCTAssertEqual(
            Wpseite.zusatzsatzFett(kw: 2.44), "Neben dem Verdichter laufen rund 2,4 kW.")
        XCTAssertTrue(Wpseite.zusatzsatzRest.hasSuffix("Die Arbeitszahl unten enthält ihn."))
        XCTAssertEqual(Wpseite.busStummVorsatz, "Vom Bus der Wärmepumpe ist kein Wert da.")
        XCTAssertTrue(Wpseite.fussFuehler.hasPrefix("Fühler WP:"))
        XCTAssertTrue(Wpseite.fussVentilUndHeizstab.contains("noch nicht gegengeprüft"))
    }

    /// `Waermepumpe.tsx:108`: der Satz steht da, sobald **eine** der beiden Kennungen da ist.
    func testDerVentilsatzKommtSobaldEineDerBeidenKennungenDaIst() {
        XCTAssertFalse(Wpseite.ventilsatzNoetig(wp()))
        XCTAssertTrue(Wpseite.ventilsatzNoetig(wp(ventil: 0)))
        XCTAssertTrue(Wpseite.ventilsatzNoetig(wp(heizstab: 0)))
    }

    /// `Waermepumpe.tsx:112-118`: fünf Verweise, wörtlich und in dieser Reihenfolge.
    func testFuenfVerweiseImFussWoertlichUndInDerReihenfolgeDerVorlage() {
        XCTAssertEqual(
            Wpseite.fussverweise.map(\.weg),
            [
                "/waerme/waermepumpe/betrieb", "/waerme/waermepumpe/kennlinie",
                "/waerme/nachbetrachtung", "/waerme/fahrplan", "/waerme/anlage",
            ])
        XCTAssertEqual(
            Wpseite.fussverweise.map(\.wort),
            [
                "Betrieb über Tage ›", "Gemessene Kennlinie ›", "Was die Wärme gekostet hat ›",
                "Fahrplan ›", "Die ganze Anlage ›",
            ])
    }

    /// **Jeder der fünf Wege ist einer, den die App kennt.** Ein Tippfehler in einem Weg
    /// führte sonst auf „Diese Seite kennt die App nicht“, und das sähe man erst, wenn
    /// jemand draufdrückt.
    func testJederVerweisFuehrtAufEinenWegDerApp() {
        let alle = Set(Bereiche.alleWege)
        for v in Wpseite.fussverweise {
            XCTAssertTrue(alle.contains(v.weg), "\(v.weg) ist kein Weg der App")
            XCTAssertNil(Bereiche.weiterleitung(v.weg), "\(v.weg) ist eine alte Adresse")
        }
    }

    // MARK: - Das Glas im Speicher

    /// `glas.ts:21`: die Fühler sitzen in der **Mitte** ihrer Schicht. Die Zeichnung hatte
    /// 0,12 / 0,38 / 0,62 / 0,88 - gerundet, und damit nicht mehr dieselbe Höhe wie das Glas
    /// auf jeder anderen Seite.
    func testDieVierFuehlerhoehenSindDieDesGlases() {
        XCTAssertEqual(Wpseite.fuehlerhoehen, [0.125, 0.375, 0.625, 0.875])
        for (i, h) in Wpseite.fuehlerhoehen.enumerated() {
            XCTAssertEqual(h, (Double(i) + 0.5) / 4, accuracy: 1e-12)
        }
    }

    /// `glas.ts:26,30-33`: „sonst gibt es keinen Verlauf, nur ein leeres Glas“ - ein Verlauf
    /// aus zwei von vier Fühlern zeigt eine Schichtung, die niemand gemessen hat.
    func testDerVerlaufBrauchtAlleVierFuehler() {
        XCTAssertTrue(Wpseite.glasVollstaendig([m(52), m(46), m(38), m(31)]))
        XCTAssertFalse(Wpseite.glasVollstaendig([m(52), m(46), m(38)]))
        XCTAssertFalse(Wpseite.glasVollstaendig([m(52), m(46), m(38), m(nil, .unavailable)]))
        XCTAssertFalse(Wpseite.glasVollstaendig([]))
        XCTAssertFalse(
            Wpseite.glasVollstaendig([m(52), m(46), m(38), m(31), m(28)]))
    }

    /// `glas.ts:26`: hier zählt `value` und nicht die Güte - ein veralteter Fühler hat eine
    /// Zahl, und das Glas zeigt sie. Dass sie alt ist, sagt die Deckkraft.
    func testEinVeralteterFuehlerZaehltFuerDenVerlaufMitUndDimmtDasGlas() {
        let mitAltem = [m(52), m(46, .stale), m(38), m(31)]
        XCTAssertTrue(Wpseite.glasVollstaendig(mitAltem))
        XCTAssertTrue(Wpseite.glasGedimmt(mitAltem))

        XCTAssertFalse(Wpseite.glasGedimmt([m(52), m(46), m(38), m(31)]))
        // Ein leeres Glas ist schon leer - es wird nicht zusätzlich blass.
        XCTAssertFalse(Wpseite.glasGedimmt([]))
    }

    /// `glas.ts:35-37`: ganze Grad, und `nil` heißt „keine Zahl“ und nicht „null Grad“.
    func testGradzahlRundetAufGanzeGradUndKenntDasFehlen() {
        XCTAssertEqual(Wpseite.gradzahl(44.8), "45")
        XCTAssertEqual(Wpseite.gradzahl(44.4), "44")
        XCTAssertEqual(Wpseite.gradzahl(0), "0")
        XCTAssertNil(Wpseite.gradzahl(nil))
        XCTAssertNil(Wpseite.gradzahl(Double.nan))
    }
}
