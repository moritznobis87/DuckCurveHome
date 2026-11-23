import XCTest

@testable import DuckCurveKit

/// Die vier Aufklapp-Fenster der Hauskonsole: jede Zeile, jede Grenze, jeder Leerfall.
final class HauskonsolenfensterTests: XCTestCase {
    typealias F = Hauskonsolenfenster

    // MARK: - Alarm

    func testAlarmstufeNachZahl() {
        XCTAssertEqual(F.stufe(0 as Double?), .unscharf)
        XCTAssertEqual(F.stufe(1 as Double?), .zuhause)
        XCTAssertEqual(F.stufe(2 as Double?), .unterwegs)
        XCTAssertEqual(F.stufe(3 as Double?), .schaltet)
        XCTAssertEqual(F.stufe(4 as Double?), .ausgeloest)
        // Oberhalb der letzten Stufe bleibt es ausgelöst und wird nicht unbekannt.
        XCTAssertEqual(F.stufe(9 as Double?), .ausgeloest)
        XCTAssertEqual(F.stufe(nil as Double?), .unbekannt)
        XCTAssertEqual(F.stufe(Double.nan), .unbekannt)
    }

    /// **Ohne Anlage ist die Stufe unbekannt, nicht unscharf.** Ein Haus ohne Alarmanlage als
    /// „UNSCHARF“ zu melden hieße, eine Anlage zu behaupten, die es nicht gibt.
    func testOhneAnlageKeineStufeUndKeinSatz() {
        let ohne = AlarmOut(present: false, state: 0, stateDe: "unscharf", canArm: false)
        XCTAssertEqual(F.stufe(ohne), .unbekannt)
        XCTAssertEqual(F.alarmsatz(ohne), "nicht eingerichtet")
        XCTAssertEqual(F.stufe(nil as AlarmOut?), .unbekannt)
        XCTAssertEqual(F.alarmsatz(nil), "nicht eingerichtet")

        let da = AlarmOut(present: true, state: 2, stateDe: "scharf, abwesend", canArm: true)
        XCTAssertEqual(F.stufe(da), .unterwegs)
        XCTAssertEqual(F.alarmsatz(da), "scharf, abwesend")
    }

    func testAlarmworte() {
        XCTAssertEqual(F.Alarmstufe.unscharf.wort, "UNSCHARF")
        XCTAssertEqual(F.Alarmstufe.zuhause.wort, "ZU HAUSE")
        XCTAssertEqual(F.Alarmstufe.unterwegs.wort, "UNTERWEGS")
        XCTAssertEqual(F.Alarmstufe.schaltet.wort, "SCHALTET")
        XCTAssertEqual(F.Alarmstufe.ausgeloest.wort, "AUSGELÖST")
        XCTAssertEqual(F.Alarmstufe.unbekannt.wort, "KEINE MELDUNG")
    }

    // MARK: - Orte

    func testRaumOrtUeberspringtTeilraeume() {
        XCTAssertEqual(F.raumOrt(plan: plan(), raumId: 2), F.Ort(deck: "og", raum: "Bad"))
        // Der Teilraum trägt dieselbe Kennung; gefunden werden muss der ganze Raum.
        XCTAssertEqual(F.raumOrt(plan: plan(), raumId: 1), F.Ort(deck: "eg", raum: "Wohnen"))
        XCTAssertNil(F.raumOrt(plan: plan(), raumId: 99))
        XCTAssertNil(F.raumOrt(plan: plan(), raumId: nil))
        XCTAssertNil(F.raumOrt(plan: nil, raumId: 1))
    }

    func testKontaktOrtNurMitRaum() {
        XCTAssertEqual(
            F.kontaktOrt(plan: plan(), schluessel: "k.terrasse"),
            F.Ort(deck: "eg", raum: "Wohnen"))
        // Ein Kontakt ohne Raum hat keinen Ort - und darf keinen erfinden.
        XCTAssertNil(F.kontaktOrt(plan: plan(), schluessel: "k.keller"))
        XCTAssertNil(F.kontaktOrt(plan: plan(), schluessel: "gibt-es-nicht"))
        XCTAssertNil(F.kontaktOrt(plan: nil, schluessel: "k.terrasse"))
    }

    // MARK: - Fenster und Türen

    /// **Offen vor zu vor stumm, Türen vor Fenstern, dann der Name.**
    func testKontaktzeilenReihenfolge() {
        let zeilen = F.kontaktzeilen(plan: plan(), kontakte: kontakte())
        XCTAssertEqual(
            zeilen.map(\.schluessel),
            ["k.terrasse", "k.bad", "k.keller", "k.zimmer"])
    }

    /// Ein stummer Kontakt steht hinten und nicht gar nicht: dass er schweigt, ist die Auskunft.
    func testStummerKontaktBleibtStehen() {
        let zeilen = F.kontaktzeilen(plan: plan(), kontakte: kontakte())
        let stumm = zeilen.first { $0.schluessel == "k.zimmer" }
        XCTAssertNotNil(stumm)
        XCTAssertNil(stumm?.offen)
        XCTAssertEqual(stumm?.wort, "keine Meldung")
        XCTAssertEqual(stumm?.unterzeile, "Bad")
    }

    func testKontaktzeileOhneRaumNenntIhreArt() {
        let zeilen = F.kontaktzeilen(plan: plan(), kontakte: kontakte())
        let keller = zeilen.first { $0.schluessel == "k.keller" }
        XCTAssertEqual(keller?.unterzeile, "Fenster")
        XCTAssertNil(keller?.ort)
        XCTAssertEqual(keller?.wort, "zu")
        let terrasse = zeilen.first { $0.schluessel == "k.terrasse" }
        XCTAssertEqual(terrasse?.unterzeile, "Wohnen")
        XCTAssertEqual(terrasse?.wort, "offen")
        XCTAssertEqual(terrasse?.beobachtetAm, "2026-11-20T09:00:00+01:00")
    }

    /// Ein Plan ohne Kontakte ergibt keine Zeilen - und keinen Absturz.
    func testKontaktzeilenLeerfaelle() {
        XCTAssertTrue(F.kontaktzeilen(plan: nil, kontakte: kontakte()).isEmpty)
        XCTAssertTrue(F.kontaktzeilen(plan: HousePlan(), kontakte: []).isEmpty)
        // Der Plan nennt die Kontakte; ohne Meldung sind sie alle stumm, aber vorhanden.
        let ohneMeldung = F.kontaktzeilen(plan: plan(), kontakte: [])
        XCTAssertEqual(ohneMeldung.count, 4)
        XCTAssertTrue(ohneMeldung.allSatisfy { $0.offen == nil })
    }

    // MARK: - Heizkreise

    func testKreiszeilenNurOffeneUndNachVentilSortiert() {
        let zeilen = F.kreiszeilen(raeume(), plan: plan())
        XCTAssertEqual(zeilen.map(\.id), [2, 1, 4])
        XCTAssertEqual(zeilen.first?.ventil, 1)
        // Der Ort kommt aus dem Plan; ein Raum, den der Plan nicht kennt, hat keinen.
        XCTAssertEqual(zeilen.first?.ort, F.Ort(deck: "og", raum: "Bad"))
        XCTAssertNil(zeilen.last?.ort)
    }

    /// Bei gleichem Ventilanteil entscheidet die Abweichung - der kältere Raum zuerst.
    func testKreiszeilenZweiterUndDritterSchluessel() {
        let gleich = [
            raum(10, name: "Bad", ventil: 0.5, abweichung: -0.1),
            raum(11, name: "Ärger", ventil: 0.5, abweichung: -1.4),
            raum(12, name: "Atelier", ventil: 0.5, abweichung: -0.1),
        ]
        XCTAssertEqual(F.kreiszeilen(gleich, plan: nil).map(\.id), [11, 12, 10])
    }

    /// **Eine andere Regel als die Tagesdiagnose.** `Raumkarte.anDerGrenze` fragt nach dem
    /// Tagesmittel (0,85); hier zählt der Augenblick, und da ist das Ventil ganz offen.
    func testAnDerGrenzeNurBeiGanzOffenUndDeutlichZuKalt() {
        let knapp = [raum(1, name: "A", ventil: 0.98, abweichung: -2)]
        XCTAssertNil(F.anDerGrenze(F.kreiszeilen(knapp, plan: nil)))
        let warm = [raum(1, name: "A", ventil: 1, abweichung: -0.4)]
        XCTAssertNil(F.anDerGrenze(F.kreiszeilen(warm, plan: nil)))
        let treffer = [raum(1, name: "A", ventil: 1, abweichung: -0.6)]
        XCTAssertEqual(F.anDerGrenze(F.kreiszeilen(treffer, plan: nil))?.id, 1)
        // Ohne Abweichungsmeldung ist nichts belegt, also auch keine Grenze.
        let ohne = [raum(1, name: "A", ventil: 1, abweichung: nil)]
        XCTAssertNil(F.anDerGrenze(F.kreiszeilen(ohne, plan: nil)))
        XCTAssertNil(F.anDerGrenze([]))
    }

    func testGrenzsatzNenntDenRaum() {
        let zeile = F.kreiszeilen([raum(1, name: "Bad", ventil: 1, abweichung: -1)], plan: nil)[0]
        XCTAssertTrue(F.grenzsatz(zeile).hasPrefix("Bad hat alle Kreise offen"))
        XCTAssertTrue(F.grenzsatz(zeile).hasSuffix("für alle anderen mit."))
    }

    // MARK: - Puffer

    func testSchichtzeilenNamenUndFrische() {
        let zeilen = F.schichtzeilen(temperaturen())
        XCTAssertEqual(zeilen.map(\.name), ["oben", "Mitte oben", "Mitte unten", "unten"])
        XCTAssertEqual(zeilen[0].tempC, 52)
        XCTAssertTrue(zeilen[0].frisch)
        // `derived` ist gerechnet und gilt als frisch - `stale` nicht.
        XCTAssertTrue(zeilen[1].frisch)
        XCTAssertFalse(zeilen[2].frisch)
        // Ein Fühler ohne Wert bleibt in der Liste: dass er schweigt, ist die Auskunft.
        XCTAssertNil(zeilen[3].tempC)
        XCTAssertFalse(zeilen[3].frisch)
        XCTAssertTrue(F.schichtzeilen(nil).isEmpty)
    }

    func testStatuswort() {
        XCTAssertEqual(F.statuswort(.cold), "kalt")
        XCTAssertEqual(F.statuswort(.partial), "teilweise geladen")
        XCTAssertEqual(F.statuswort(.warm), "warm")
        XCTAssertEqual(F.statuswort(.full), "voll")
        XCTAssertEqual(F.statuswort(.unknown), "unbekannt")
        XCTAssertEqual(F.statuswort(.unbekannt), "unbekannt")
        XCTAssertEqual(F.statuswort(nil), "unbekannt")
    }

    /// Eine unbekannte Kennung wird durchgereicht: ein englisches Wort ist besser als ein
    /// falsches deutsches.
    func testMethodensatz() {
        XCTAssertEqual(
            F.methodensatz("layered_energy_v2"),
            "Schichtenmodell: jede Schicht mit ihrem eigenen Anteil am Volumen")
        XCTAssertEqual(F.methodensatz("weighted_mean"), "gewichtetes Mittel der vier Fühler")
        XCTAssertEqual(F.methodensatz("irgendwas_neues"), "irgendwas_neues")
        XCTAssertEqual(F.methodensatz(nil), "")
        XCTAssertEqual(F.methodensatz(""), "")
    }

    // MARK: - Wärmepumpe

    func testTageslaufZaehltNurMinutenMitMesswert() {
        let punkte = [
            punkt(0, 0.0), punkt(1, 3.0), punkt(2, nil), punkt(3, 1.2), punkt(4, 0.05),
        ]
        let lauf = F.tageslauf(punkte)
        XCTAssertEqual(lauf.kwh, (3.0 + 1.2 + 0.05) / 60, accuracy: 1e-9)
        // 0,05 kW ist Bereitschaft, nicht Lauf; die Lücke zählt gar nicht.
        XCTAssertEqual(lauf.minuten, 2)
        XCTAssertEqual(lauf.hoechst, 3.0)
    }

    func testTageslaufOhnePunkteIstNull() {
        let lauf = F.tageslauf([])
        XCTAssertEqual(lauf.kwh, 0)
        XCTAssertEqual(lauf.minuten, 0)
        XCTAssertEqual(lauf.hoechst, 0)
        // Ohne Lauf steht trotzdem eine Achse da, durch die sich teilen lässt.
        XCTAssertEqual(F.kurvenachse(lauf), 1)
    }

    func testKurvenachseRundetAuf() {
        XCTAssertEqual(F.kurvenachse(F.Tageslauf(kwh: 0, minuten: 0, hoechst: 0.4)), 1)
        XCTAssertEqual(F.kurvenachse(F.Tageslauf(kwh: 0, minuten: 0, hoechst: 3.2)), 4)
        XCTAssertEqual(F.kurvenachse(F.Tageslauf(kwh: 0, minuten: 0, hoechst: 4.0)), 4)
    }

    // MARK: - Verdichten und Kurve

    func testVerdichteMitteltJeFenster() {
        let werte: [Double?] = [1, 3, 5, 7]
        XCTAssertEqual(F.verdichte(werte, stellen: 2).map { $0 ?? -1 }, [2, 6])
    }

    /// Eine Reihe, die kürzer ist als die Zahl der Stellen, bleibt, wie sie ist - gedehnt wäre
    /// sie erfunden.
    func testVerdichteLaesstKurzeReihenStehen() {
        let werte: [Double?] = [1, nil, 2]
        XCTAssertEqual(F.verdichte(werte, stellen: 96).count, 3)
        XCTAssertTrue(F.verdichte([], stellen: 96).isEmpty)
        XCTAssertTrue(F.verdichte(werte, stellen: 0).isEmpty)
    }

    /// **Ein Fenster ganz ohne Wert bleibt leer** und wird nicht zu einer Null.
    func testVerdichteBehaeltLuecken() {
        let werte: [Double?] = [1, 2, nil, nil, 5, 6]
        let aus = F.verdichte(werte, stellen: 3)
        XCTAssertEqual(aus.count, 3)
        XCTAssertEqual(aus[0], 1.5)
        XCTAssertNil(aus[1])
        XCTAssertEqual(aus[2], 5.5)
    }

    /// **Lücken bleiben Lücken**: zwei Stücke statt einer durchgezogenen Linie.
    func testSparklinieZerfaelltAnLuecken() {
        let stuecke = F.sparklinie([0, 1, nil, 1, 1], hoechst: 2)
        XCTAssertEqual(stuecke.count, 2)
        XCTAssertEqual(stuecke[0].count, 2)
        XCTAssertEqual(stuecke[1].count, 2)
        XCTAssertEqual(stuecke[0][0].x, 0)
        XCTAssertEqual(stuecke[0][0].y, 1)
        XCTAssertEqual(stuecke[0][1].y, 0.5)
        XCTAssertEqual(stuecke[1][1].x, 1)
    }

    /// Ein Stück aus einem einzigen Punkt fällt weg - eine Linie von einem Punkt nach nirgendwo
    /// lässt sich nicht zeichnen.
    func testSparklinieWirftEinzelpunkteWeg() {
        XCTAssertTrue(F.sparklinie([1, nil, 1, nil, 1], hoechst: 2).isEmpty)
        XCTAssertTrue(F.sparklinie([1], hoechst: 2).isEmpty)
        XCTAssertTrue(F.sparklinie([], hoechst: 2).isEmpty)
        // Ohne Achse lässt sich nicht skalieren; eine Division durch null wäre keine Kurve.
        XCTAssertTrue(F.sparklinie([1, 2], hoechst: 0).isEmpty)
    }

    /// Werte über der Achse werden auf sie gekappt und nicht aus dem Bild gezeichnet.
    func testSparklinieKapptAnDerAchse() {
        let stuecke = F.sparklinie([5, 0], hoechst: 2)
        XCTAssertEqual(stuecke[0][0].y, 0)
        XCTAssertEqual(stuecke[0][1].y, 1)
    }

    // MARK: - Wie lange schon

    func testSeitText() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(
            F.seitText(Zeit.iso(jetzt.addingTimeInterval(-12 * 60)), jetzt: jetzt),
            Formate.dauer(minuten: 12))
        XCTAssertEqual(
            F.seitText(Zeit.iso(jetzt.addingTimeInterval(-190 * 60)), jetzt: jetzt),
            Formate.dauer(minuten: 190))
        XCTAssertNil(F.seitText(nil, jetzt: jetzt))
        XCTAssertNil(F.seitText("kein Zeitstempel", jetzt: jetzt))
        // Im Vorführbetrieb läuft die Uhr des Dienstes voraus; „seit −1 min“ wäre Unsinn.
        XCTAssertNil(F.seitText(Zeit.iso(jetzt.addingTimeInterval(120)), jetzt: jetzt))
    }

    // MARK: - Ofen

    func testOfenLaeuft() {
        XCTAssertEqual(F.ofenLaeuft(StoveLiveOut(present: true, running: true)), true)
        XCTAssertEqual(F.ofenLaeuft(StoveLiveOut(present: true, running: false)), false)
        // Kein Ofen und kein Messwert sind beide „keine Meldung“, nicht „aus“.
        XCTAssertNil(F.ofenLaeuft(StoveLiveOut(present: true, running: nil)))
        XCTAssertNil(F.ofenLaeuft(StoveLiveOut(present: false, running: true)))
        XCTAssertNil(F.ofenLaeuft(nil))
    }

    // MARK: - Sortieren

    /// Umlaute stehen bei ihrem Grundbuchstaben, nicht hinter Z.
    func testDeutscheReihenfolge() {
        XCTAssertTrue(F.vorher("Ärger", "Bad"))
        XCTAssertTrue(F.vorher("büro", "Keller"))
        XCTAssertTrue(F.vorher("Straße", "Strasze"))
        XCTAssertFalse(F.vorher("Zimmer", "Ärger"))
    }

    // MARK: - Beispiele

    private func plan() -> HousePlan {
        HousePlan(
            version: 1, name: "Haus",
            decks: [
                Deck(
                    key: "eg", name: "Erdgeschoss",
                    rooms: [
                        Room(name: "Wohnen", roomId: 1, x0: 0, z0: 0, x1: 5, z1: 4),
                        Room(name: "Essecke", roomId: 1, x0: 5, z0: 0, x1: 7, z1: 4,
                             partOf: "Wohnen"),
                    ],
                    contacts: [
                        Contact(name: "Terrassentür", key: "k.terrasse", room: "Wohnen",
                                side: .s, at: 1, a: 0, b: 1, door: true),
                        Contact(name: "Kellerfenster", key: "k.keller", side: .n,
                                at: 2, a: 0, b: 1, door: false),
                    ]),
                Deck(
                    key: "og", name: "Obergeschoss",
                    rooms: [Room(name: "Bad", roomId: 2, x0: 0, z0: 0, x1: 3, z1: 3)],
                    contacts: [
                        Contact(name: "Badfenster", key: "k.bad", room: "Bad", side: .w,
                                at: 1, a: 0, b: 1, door: false),
                        Contact(name: "Zimmerfenster", key: "k.zimmer", room: "Bad", side: .o,
                                at: 1, a: 0, b: 1, door: false),
                    ]),
            ],
            noteDe: "Die Flächen sind aus dem Grundriss.")
    }

    private func kontakte() -> [HouseContactOut] {
        [
            HouseContactOut(
                key: "k.terrasse", name: "Terrassentür", room: "Wohnen", door: true, open: true,
                observedAt: "2026-11-20T09:00:00+01:00", quality: .ok),
            HouseContactOut(
                key: "k.keller", name: "Kellerfenster", door: false, open: false, quality: .ok),
            HouseContactOut(
                key: "k.bad", name: "Badfenster", room: "Bad", door: false, open: true,
                quality: .ok),
            // Dieser meldet nichts: `open` bleibt leer.
            HouseContactOut(
                key: "k.zimmer", name: "Zimmerfenster", room: "Bad", door: false,
                quality: .unavailable),
        ]
    }

    private func raeume() -> [RoomLiveOut] {
        [
            raum(1, name: "Wohnen", ventil: 0.5, abweichung: -0.2),
            raum(2, name: "Bad", ventil: 1, abweichung: -1.2),
            raum(3, name: "Flur", ventil: 0, abweichung: 0.1),
            raum(4, name: "Küche", ventil: 0.25, abweichung: 0),
        ]
    }

    private func raum(
        _ id: Int, name: String, ventil: Double?, abweichung: Double?
    ) -> RoomLiveOut {
        RoomLiveOut(
            id: id, name: name, floor: "Erdgeschoss", circuits: 4, tempC: 21, setpointC: 21.5,
            offsetK: 0, targetC: 21.5, humidityPct: nil, valve: ventil, window: 0,
            deviationK: abweichung, observedAt: nil, quality: .ok)
    }

    private func temperaturen() -> BufferTemperatures {
        BufferTemperatures(
            top: Messwert(value: 52, observedAt: "2026-11-20T09:00:00+01:00", quality: .ok,
                          source: "ha"),
            midTop: Messwert(value: 48, observedAt: "2026-11-20T09:00:00+01:00",
                             quality: .derived, source: "ha"),
            midBottom: Messwert(value: 41, observedAt: "2026-11-20T08:00:00+01:00",
                                quality: .stale, source: "ha"),
            bottom: Messwert(observedAt: "2026-11-20T09:00:00+01:00", quality: .unavailable,
                             source: "ha"))
    }

    private func punkt(_ minute: Int, _ kw: Double?) -> Verlaufspunkt {
        Verlaufspunkt(
            zeit: Date(timeIntervalSince1970: 1_800_000_000 + Double(minute) * 60),
            waermepumpe: kw)
    }
}
