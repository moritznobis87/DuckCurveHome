import Foundation

/// Was unter dem Puffer steht - und wann es eine Entschuldigung statt eines Zustands ist.
///
/// **Der Anlass, wortgleich aus `apps/web/src/components/home/puffer.ts`:** Am 25.10.2026 zeigte
/// die Wandanzeige vier satte Temperaturen, einen vollen Farbverlauf und als Fuellstand einen
/// Strich. Der Dienst rechnet den Fuellstand nur aus frischen Fuehlern; einer war veraltet (der
/// MQTT-Broker war abgemeldet), also kam nichts heraus. Zu sehen war davon nichts: die Kachel sah
/// aus wie immer, nur ohne Zahl.
///
/// Jetzt sagt sie, wie alt die Werte sind. Eine Anzeige, die eine fehlende Zahl nicht erklaert,
/// schickt den Betrachter zum Raten - und in diesem Fall lag die Ursache zwei Tage zurueck.
public struct Pufferzustand: Sendable, Hashable {
    /// Alle vier Fuehler haben einen Wert.
    public var vollstaendig: Bool
    /// Mindestens ein Wert ist nicht mehr frisch.
    public var veraltet: Bool
    /// Das Wort unter dem Fuellstand.
    public var wort: String

    public init(vollstaendig: Bool, veraltet: Bool, wort: String) {
        self.vollstaendig = vollstaendig
        self.veraltet = veraltet
        self.wort = wort
    }

    /// Den Zustand aus den vier Fuehlern bestimmen.
    ///
    /// Die Reihenfolge der Faelle ist die Aussage: **veraltet schlaegt alles**. Ein Puffer, von
    /// dem die Anzeige nichts Frisches weiss, ist nicht „warm" - er ist unbekannt, und das soll
    /// dastehen.
    public static func aus(
        fuehler: [Messwert],
        jetzt: Date,
        laedt: Bool,
        status: BufferStatus?
    ) -> Pufferzustand {
        let vollstaendig = !fuehler.isEmpty && fuehler.allSatisfy { $0.value != nil }
        let veraltet = fuehler.contains { $0.value != nil && !$0.quality.traegt }

        if veraltet {
            // Der aelteste der vier bestimmt das Alter: er ist der Grund, warum nichts gerechnet
            // wird.
            let aeltester = fuehler
                .compactMap(\.zeitpunkt)
                .min()
            let alter = aeltester.flatMap { Formate.alter(beobachtetAm: $0, jetzt: jetzt) }
            return Pufferzustand(
                vollstaendig: vollstaendig, veraltet: true,
                wort: alter.map { "Werte \($0)" } ?? "Werte veraltet"
            )
        }
        if !vollstaendig {
            return Pufferzustand(vollstaendig: false, veraltet: false, wort: "keine Werte")
        }
        if laedt {
            return Pufferzustand(vollstaendig: true, veraltet: false, wort: "lädt")
        }
        switch status {
        case .full: return Pufferzustand(vollstaendig: true, veraltet: false, wort: "voll")
        case .cold: return Pufferzustand(vollstaendig: true, veraltet: false, wort: "kalt")
        case .warm: return Pufferzustand(vollstaendig: true, veraltet: false, wort: "warm")
        default: return Pufferzustand(vollstaendig: true, veraltet: false, wort: "hält")
        }
    }

    /// Die Guete, die die Anzeige daraus macht: traegt der Fuellstand eine Zahl?
    public var traegt: Bool { vollstaendig && !veraltet }
}

extension BufferTemperatures {
    /// Die vier Fuehler von oben nach unten.
    ///
    /// Die Reihenfolge ist nicht beliebig: das Glas zeichnet sie auf ihrer Hoehe, und eine
    /// verdrehte Reihenfolge ergibt einen Speicher, der unten heiss ist. Darum steht sie hier
    /// einmal und nicht an jeder Zeichnung.
    public var vonObenNachUnten: [Messwert] {
        [top, midTop, midBottom, bottom]
    }
}

/// Was das Haus in den naechsten 24 Stunden vorhat, in Zeilen.
///
/// **Eine Phase ist eine Folge von Viertelstunden.** Der Fahrplan kommt als Raster; was ihn
/// interessant macht, sind die zusammenhaengenden Stuecke darin („23:15 bis 02:00"), nicht die
/// einzelnen Schritte.
///
/// **Eine Zeile entsteht nur, wenn der Plan die Sache ueberhaupt kennt.** Steht nichts ueber den
/// Pelletofen darin, ist „bleibt aus" eine Behauptung und keine Auskunft - und genau diese
/// Unterscheidung ist der Grund, warum `hatOfen` getrennt von `ofen` gerechnet wird.
public struct Planzeile: Sendable, Hashable, Identifiable {
    public var wort: String
    public var wann: String

    public var id: String { wort }

    public init(wort: String, wann: String) {
        self.wort = wort
        self.wann = wann
    }
}

/// Eine zusammenhaengende Phase im Fahrplan.
public struct Phase: Sendable, Hashable {
    public var von: Date
    public var bis: Date

    public init(von: Date, bis: Date) {
        self.von = von
        self.bis = bis
    }

    /// „bis 02:00", solange die Phase laeuft, sonst „23:15 bis 02:00".
    public func spanne(jetzt: Date) -> String {
        von <= jetzt
            ? "bis \(Formate.hhmm(bis))"
            : "\(Formate.hhmm(von)) bis \(Formate.hhmm(bis))"
    }
}

public enum Fahrplan {
    /// Ein Schritt des Fahrplans ist eine Viertelstunde.
    public static let schritt: TimeInterval = 15 * 60

    /// Zusammenhaengende Phasen aus den Viertelstundenschritten.
    ///
    /// Eine Viertelstunde, in der die Sache aus ist, schliesst die laufende Phase - und zwar
    /// auch dann, wenn gleich danach wieder eine beginnt. Aus zwei Laeufen mit einer Pause
    /// dazwischen darf nicht ein langer werden: die Pause ist das Takten, und das ist an dieser
    /// Anlage der Gegenstand einer eigenen Seite.
    public static func phasen(
        _ plan: PlanOut?, jetzt: Date, bis ende: Date,
        wenn an: (PlanIntervalOut) -> Bool
    ) -> [Phase] {
        var aus: [Phase] = []
        /// Die Stelle der laufenden Phase in `aus`, oder `nil`, wenn keine laeuft.
        var offen: Int?
        for iv in plan?.intervals ?? [] {
            guard let t = Zeit.ausIso(iv.ts) else { continue }
            // Was schon vorbei ist oder jenseits des Horizonts liegt, zaehlt nicht.
            if t.addingTimeInterval(schritt) <= jetzt || t >= ende { continue }
            guard an(iv) else {
                offen = nil
                continue
            }
            if let i = offen, aus[i].bis == t {
                aus[i].bis = t.addingTimeInterval(schritt)
            } else {
                aus.append(Phase(von: t, bis: t.addingTimeInterval(schritt)))
                offen = aus.count - 1
            }
        }
        return aus
    }

    /// Die drei Zeilen der Leiste: Waermepumpe, Pelletofen, Preistief.
    public static func zeilen(_ plan: PlanOut?, jetzt: Date) -> [Planzeile] {
        let ende = jetzt.addingTimeInterval(24 * 3600)
        var aus: [Planzeile] = []

        let hatWp = (plan?.intervals ?? []).contains { $0.reasonCode == "planned_optimizer" }
        if hatWp {
            let wp = phasen(plan, jetzt: jetzt, bis: ende) {
                $0.reasonCode == "planned_optimizer" && $0.plannedHpState == .release
            }
            aus.append(
                Planzeile(
                    wort: "Wärmepumpe",
                    wann: wp.first?.spanne(jetzt: jetzt) ?? "bleibt aus"
                )
            )
        }

        let hatOfen = (plan?.intervals ?? []).contains { $0.plannedStoveOn != nil }
        if hatOfen {
            let ofen = phasen(plan, jetzt: jetzt, bis: ende) { $0.plannedStoveOn == true }
            aus.append(
                Planzeile(
                    wort: "Pelletofen",
                    wann: ofen.first?.spanne(jetzt: jetzt) ?? "bleibt aus"
                )
            )
        }

        if let tief = plan?.nextCheapWindow,
           let von = Zeit.ausIso(tief.start), let bis = Zeit.ausIso(tief.end)
        {
            aus.append(
                Planzeile(wort: "Preistief", wann: "\(Formate.hhmm(von)) bis \(Formate.hhmm(bis))")
            )
        }
        return aus
    }
}
