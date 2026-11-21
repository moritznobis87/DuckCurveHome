import Foundation

// Die Tabelle der Heizkreisseite, vorgerechnet - Vorlage:
// `apps/web/src/components/rooms/RoomsReport.tsx:383-408` (die Zeilen) und `:513-547` (die
// Spalten). Was die Vorlage dort in der Ansicht rechnet, steht hier im Kern; die Typen
// erweitern `Raumabweichung`, weil es dieselbe Groesse ist, nur je Raum zusammengefasst
// statt je Viertelstunde.

/// Der letzte Stand eines Raums in seiner Tagesreihe - **der letzte GEMESSENE, nicht der
/// letzte gewesene**.
///
/// **Warum das ein eigener Typ ist.** Die Spalten „Ist" und „Ziel" der Tabelle sind kein
/// Tagesmittel: ein Raum, der morgens kalt war und abends am Ziel steht, ist am Abend am Ziel,
/// und das Mittel verschweigt beides. Gefragt ist der Stand am Ende des Tages - und der liegt
/// nicht am Ende der Reihe, sondern beim letzten Fenster, in dem der Fuehler etwas gesagt hat.
/// `Raumkarte.letzterPlatz` beantwortet die andere Frage (welcher Platz ist schon gewesen) und
/// taugt hier nicht: zwischen „gewesen" und „gemessen" liegen genau die stummen Viertelstunden,
/// um die es geht.
///
/// **Alle acht Zahlen stammen aus demselben Fenster.** Das Ventil aus dem einen und die
/// Temperatur aus dem anderen abzulesen ergaebe einen Stand, den es nie gegeben hat.
public struct Raumstand: Hashable, Sendable {
    /// Der Platz in der Tagesreihe, aus dem dieser Stand kommt. Die Ansicht holt sich darueber
    /// den Zeitpunkt (`tag.ts[stelle]`) - die Reihe traegt die Zeitstempel, nicht der Stand.
    public let stelle: Int
    public let ist: Double?
    public let soll: Double?
    public let versatz: Double?
    /// Sollwert plus Versatz, nach `Raumabweichung.ziel(soll:versatz:)`. **Ohne Sollwert kein
    /// Ziel** - und damit auch keine Abweichung.
    public let ziel: Double?
    /// Ist minus Ziel, in Kelvin.
    public let abweichung: Double?
    public let ventil: Double?
    public let fenster: Double?

    public init(
        stelle: Int, ist: Double? = nil, soll: Double? = nil, versatz: Double? = nil,
        ziel: Double? = nil, abweichung: Double? = nil, ventil: Double? = nil,
        fenster: Double? = nil
    ) {
        self.stelle = stelle
        self.ist = ist
        self.soll = soll
        self.versatz = versatz
        self.ziel = ziel
        self.abweichung = abweichung
        self.ventil = ventil
        self.fenster = fenster
    }
}

/// Eine Zeile der Tabelle „Die Räume als Tabelle".
///
/// **Warum heute und gestern dieselbe Form haben.** Am laufenden Tag kommen die Zahlen aus den
/// Istwerten der Bruecke, an einem vergangenen Tag aus dem letzten gemessenen Fenster der
/// Tagesreihe - zwei Quellen, eine Tabelle. Ohne diesen Typ haette die Ansicht zwei
/// Zeilenbauplaene und damit zwei Gelegenheiten, die Spalten gegeneinander zu verschieben.
///
/// **Das ist keine Kachel.** Hier steht nichts, was die Raumkachel ausmacht - kein Streifen,
/// keine Kurve, kein Abzeichen, keine Diagnose; dafuer gibt es `Raumkarte`. Diese Zeile
/// beantwortet eine einzige Frage: welcher Raum haengt am weitesten hinter seinem Ziel und
/// bestimmt damit die Vorlauftemperatur fuer alle.
public struct Raumzeile: Identifiable, Hashable, Sendable {
    /// Die Kennung des Raums in der Heizungsregelung - auch die Kennung der Zeile, denn zwei
    /// Räume duerfen gleich heissen.
    public let id: Int
    public let name: String
    /// Die Etage, wie sie in der Tabelle steht: der Text der Anlage, und `Formate.leer`, wo die
    /// Anlage keine Etage nennt. Nicht „ohne Etagenangabe" wie bei `Raumabweichung.nachEtage` -
    /// das ist eine Ueberschrift ueber einer Gruppe, dies eine Zelle von sieben in einer Zeile.
    public let etage: String
    public let ist: Double?
    /// Sollwert plus Versatz. Heute nimmt er den fertigen Zielwert des Dienstes, sofern er
    /// dasteht; sonst wird er gerechnet.
    public let ziel: Double?
    public let soll: Double?
    public let versatz: Double?
    /// Ist minus Ziel, in Kelvin.
    public let abweichung: Double?
    /// Das Mittel der Ventilstellung ueber den Tag - **immer aus der Tagesreihe**, auch heute.
    /// Der Augenblickswert der Istwerte waere „gerade offen" und nicht „am Tag offen".
    public let tagesventil: Double?
    public let kreise: Int

    public init(
        id: Int, name: String, etage: String, ist: Double? = nil, ziel: Double? = nil,
        soll: Double? = nil, versatz: Double? = nil, abweichung: Double? = nil,
        tagesventil: Double? = nil, kreise: Int = 0
    ) {
        self.id = id
        self.name = name
        self.etage = etage
        self.ist = ist
        self.ziel = ziel
        self.soll = soll
        self.versatz = versatz
        self.abweichung = abweichung
        self.tagesventil = tagesventil
        self.kreise = kreise
    }
}

extension Raumabweichung {

    /// Wie oft die Istwerte am laufenden Tag nachgeladen werden.
    ///
    /// Aus der Vorlage (`rooms/RoomsReport.tsx:38`, `LIVE_MS = 30_000`), und nur am laufenden
    /// Tag: ein vergangener Tag aendert sich nicht mehr, und ein Takt darauf waere eine Abfrage,
    /// die jedes Mal dieselbe Antwort bekommt.
    public static let liveTakt: Duration = .seconds(30)

    // MARK: - Der letzte Stand

    /// Der letzte Stand eines Raums aus seiner Tagesreihe.
    ///
    /// Gesucht wird das **letzte Fenster mit Temperatur** (rueckwaerts, `bisStelle` ist das erste
    /// Fenster, das noch nicht gewesen ist, wie bei `felder(ist:soll:versatz:bisStelle:)`). Von
    /// dort kommen alle Zahlen des Standes. Ein Raum, der den ganzen Tag geschwiegen hat, hat
    /// keinen Stand - `nil`, und nicht ein Stand aus Nullen.
    ///
    /// **Die Nebenreihen duerfen kuerzer sein.** Sollwert, Versatz, Ventil und Fensterkontakt
    /// kommen aus eigenen Meldungen der Bruecke; eine, die spaeter eingesetzt hat, ist kuerzer
    /// als die Temperaturreihe. Fehlt dort der Platz, fehlt der Wert - das ist kein Fehler.
    public static func letzterStand(reihe: RoomSeriesOut, bisStelle: Int? = nil) -> Raumstand? {
        let grenze = min(bisStelle ?? reihe.tempC.count, reihe.tempC.count)
        var i = grenze - 1
        while i >= 0, reihe.tempC[i] == nil { i -= 1 }
        guard i >= 0, let ist = reihe.tempC[i] else { return nil }
        let soll = anStelle(reihe.setpointC, i)
        let versatz = anStelle(reihe.offsetK, i)
        let z = ziel(soll: soll, versatz: versatz)
        return Raumstand(
            stelle: i, ist: ist, soll: soll, versatz: versatz, ziel: z,
            abweichung: z.map { ist - $0 }, ventil: anStelle(reihe.valve, i),
            fenster: anStelle(reihe.window, i))
    }

    // MARK: - Die Zeilen der Tabelle

    /// Die Zeilen der Tabelle - heute aus den Istwerten, sonst aus der Tagesreihe.
    ///
    /// **Die Reihenfolge ist die der Anlage.** Wie bei `nachEtage(_:)`: sortiert laege das
    /// Dachgeschoss vor dem Erdgeschoss, und die Tabelle soll dieselbe Folge haben wie die
    /// Zeilen der Waermekarte darueber.
    ///
    /// **Das Ventil am Tag kommt immer aus der Tagesreihe**, auch heute, und wird ueber die
    /// Kennung zugeordnet - nicht ueber den Platz in der Liste: die Istwerte und die Zeitreihe
    /// sind zwei Antworten, und ein Raum, der in der einen fehlt, wuerde sonst alle folgenden
    /// Zeilen verschieben.
    ///
    /// Ohne Istwerte traegt auch heute die Tagesreihe die Tabelle. Eine leere Tabelle, weil eine
    /// von zwei Abfragen scheiterte, waere die Auskunft „keine Räume" - und die ist falsch,
    /// solange die Reihe zehn kennt.
    public static func tabellenzeilen(
        live: RoomsLiveOut?, tag: RoomHistoryOut?, istHeute: Bool
    ) -> [Raumzeile] {
        var tagesventil: [Int: Double] = [:]
        for reihe in tag?.rooms ?? [] {
            if let mittel = anteilMittel(reihe.valve) { tagesventil[reihe.id] = mittel }
        }

        if istHeute, let live, !live.rooms.isEmpty {
            return live.rooms.map { r in
                // Der Dienst rechnet den Zielwert selbst vor und schickt ihn mit; fehlt er,
                // steht hier dieselbe Rechnung wie in der Zeitreihe.
                let z = r.targetC ?? ziel(soll: r.setpointC, versatz: r.offsetK)
                return Raumzeile(
                    id: r.id, name: r.name, etage: etagenzelle(r.floor), ist: r.tempC, ziel: z,
                    soll: r.setpointC, versatz: r.offsetK,
                    abweichung: r.deviationK ?? unterschied(ist: r.tempC, ziel: z),
                    tagesventil: tagesventil[r.id], kreise: r.circuits)
            }
        }

        // Ein Raum ohne jeden Messwert bleibt in der Tabelle: Name, Etage und Kreise stehen in
        // der Anlage und nicht in der Messung. Ihn weglassen hiesse, den stummen Fuehler zu
        // verstecken - und genau der ist eine Auskunft.
        return (tag?.rooms ?? []).map { reihe in
            let stand = letzterStand(reihe: reihe)
            return Raumzeile(
                id: reihe.id, name: reihe.name, etage: etagenzelle(reihe.floor), ist: stand?.ist,
                ziel: stand?.ziel, soll: stand?.soll, versatz: stand?.versatz,
                abweichung: stand?.abweichung, tagesventil: tagesventil[reihe.id],
                kreise: reihe.circuits)
        }
    }

    // MARK: - Das Mittel einer Anteilsreihe

    /// Das Mittel ueber die gemessenen Fenster einer Anteilsreihe - fuer „Ventil am Tag".
    ///
    /// **Es gibt ein `mittel(_:)` und es passt hier nicht:** das nimmt `[Feld]`, also eine Reihe,
    /// in der „kein Messwert" und „noch nicht gewesen" schon unterschieden sind. Die
    /// Ventilreihe kommt als `[Double?]` aus der Zeitreihe, und die Seite hat sich das Mittel
    /// darum bisher selbst nachgebaut.
    ///
    /// **Ein geschlossenes Ventil ist ein Messwert**, keine Luecke: eine Reihe aus Nullen
    /// mittelt zu null („zu"), eine Reihe aus `nil` zu `nil` („kein Messwert").
    public static func anteilMittel(_ werte: [Double?]) -> Double? {
        let da = werte.compactMap { $0 }.filter { $0.isFinite }
        guard !da.isEmpty else { return nil }
        return da.reduce(0, +) / Double(da.count)
    }

    // MARK: - Kleinteile

    /// Ein Wert einer Nebenreihe, falls sie so weit reicht.
    private static func anStelle(_ werte: [Double?], _ i: Int) -> Double? {
        i < werte.count ? werte[i] : nil
    }

    /// Die Abweichung, wenn beide Zahlen dastehen.
    private static func unterschied(ist: Double?, ziel: Double?) -> Double? {
        guard let ist, let ziel else { return nil }
        return ist - ziel
    }

    /// Die Etagenzelle: der Text der Anlage, sonst der Strich des Hauses.
    private static func etagenzelle(_ etage: String) -> String {
        etage.isEmpty ? Formate.leer : etage
    }
}
