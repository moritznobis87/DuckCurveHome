import DuckCurveKit
import SwiftUI

/// Daten prüfen: wie lückenlos die Messwerte sind, und die Tagesdiagnose.
///
/// **Die wichtigste Seite für das Vertrauen in alle anderen.** Jede Zahl dieser App steht auf
/// Minutenwerten; wo die fehlen, rechnet der Dienst mit weniger, als er zu haben scheint. Die
/// längste Lücke je Reihe sagt, wie schlimm es war.
///
/// **Drei Dinge und nichts weiter**, so zählt es der Kopf der Vorlage auf
/// (`DataCheck.tsx:16-20`): die Reihen eines Tages übereinander, dieselben Zahlen je Stunde,
/// und daneben der Weg zu den Rohdaten. Das dritte fehlte in der App ganz; es steht jetzt als
/// CSV-Verweis im Kopf der Stundenbilanz.
///
/// **Diese Seite verbirgt nichts.** Was sie zu sagen hat, steht offen da: die Noten der
/// Abdeckung in der Abdeckungskarte und die drei erklärenden Absätze als Fließtext am Fuß. Bis
/// zum 21.11.2026 lag beides in einer zugeklappten ``Methode``, und damit lag der Satz, der die
/// leere von der roten Zelle unterscheidet, unter einem Deckel - gerade die Auskunft, die laut
/// Vorlage „entscheidet, wen man anschaut“ (`CoverageMap.tsx:24-27`). Ein Deckel ist richtig,
/// wo eine Methode erklärt wird, die immer gleich ist; hier steht eine Angabe **zu diesem
/// Zeitraum**, und die darf nach ``Methode/kurz`` selbst nicht hinter den Deckel.
///
/// **Der Platzbedarf stand hier und steht jetzt auf `/system/zugang`.** Dort hat ihn die
/// Vorlage (`apps/web/src/app/system/zugang/page.tsx` mit
/// `apps/web/src/components/settings/StorageReport.tsx`), und hier hatte er nie eine Frage, die
/// er beantwortet: „kommen die Daten an?“ und „wie viel wiegen sie?“ sind zwei Fragen, und die
/// zweite nahm den Platz vor der ersten. Mit ihm ist die private Abschrift von `megabyte`
/// gegangen - sie steht als ``Formate/megabyte(_:)`` im Kern, wo sie geprüft ist.
struct DatenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.openURL) private var oeffne

    /// Wie viele Tage die Waermekarte zeigt (`CoverageMap.tsx:83`, `days = 28`). Die Zahl steht
    /// im Kicker und in der Abfrage, darum nur einmal.
    ///
    /// Die Belegstelle stand bis zum 21.11.2026 auf `DataCheck.tsx:98`; dort steht nur
    /// `<CoverageMap anchor={anchor} />`, die Zahl ist der Vorgabewert der Karte selbst.
    private static let kartentage = 28

    /// `max-w-[90ch]` des Fließtextes - jetzt aus ``Marken/lesebreite`` und nicht mehr aus
    /// zwei Seiten, die dieselbe Zahl von Hand tragen. Die Rechnung steht dort.
    private static let lesebreite = CGFloat(Marken.lesebreite)

    @State private var abdeckung: CoverageOut?
    @State private var diagnose: String?
    /// Die Minutenwerte des Tages - die Reihen, um die es auf dieser Seite geht.
    @State private var kurve = Pruefkurve()

    // **Drei Lagen und nicht eine.** Die drei Abfragen laufen nebeneinander und kommen
    // einzeln an; eine gemeinsame Lage hieße, die Seite erst zu zeigen, wenn die langsamste
    // da ist (`DataCheck.tsx:38` holt Verlauf und Diagnose zusammen, `CoverageMap.tsx:87-97`
    // die Abdeckung in einem eigenen, gleichzeitig laufenden Effekt).
    @State private var kurvenlage: Pruefstand.Lage = .laedt
    @State private var abdeckungslage: Pruefstand.Lage = .laedt
    @State private var diagnoselage: Pruefstand.Lage = .laedt

    /// Die Lage des Augenblicks. **Gelesen und nicht gespeichert**: der Live-Zustand kommt
    /// nicht aus ``lade(_:)``, sondern aus dem Ereignisstrom, und der ändert sich alle
    /// dreißig Sekunden (`Sources.tsx:26`).
    ///
    /// **Warum hier die Verbindung befragt wird und nicht ``Hauszustand/fehler``.** Das ist
    /// „der letzte Fehler, der nicht von selbst weggeht - etwa ein falsches Token“; ein
    /// abgerissener Strom setzt ihn nicht. Ohne diese Frage stünde über der Karte beim
    /// nächtlichen WLAN-Abriss stundenlang „lädt …“, und das wäre dieselbe Sorte Unwahrheit
    /// wie der Befund, der hier vorher beim Öffnen stand. ``Verbindung/verbindet`` ist der
    /// erste Versuch und damit wirklich „lädt“; ``Verbindung/verbindetNeu`` und
    /// ``Verbindung/aus`` sind es nicht mehr.
    private var quellenlage: Pruefstand.Lage {
        guard haus.zustand != nil else {
            let laeuft = haus.verbindung == .verbindet && haus.fehler == nil
            return laeuft ? .laedt : .fehler
        }
        return quellenzeilen.isEmpty ? .leer : .da
    }

    private var quellenzeilen: [Quellenstand.Quellenzeile] {
        Quellenstand.zeilen(aus: haus.zustand?.system)
    }

    private var stand: Pruefstand {
        Pruefstand(
            kurve: kurvenlage, quellen: quellenlage, abdeckung: abdeckungslage,
            diagnose: diagnoselage)
    }

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        // **Keine Spannenwahl** (`DataCheck.tsx:59-68`, `showPeriods={false}`): diese Seite
        // kennt nur Tage. Minutenwerte über eine Woche ergäben ein Bild, in dem man nichts
        // erkennt - und genau zum Erkennen ist sie da.
        return Seite(zeitraum: Zeitraumleiste(spannen: [.tag])) {
            // Das Band nur, wenn Verlauf **und** Diagnose scheitern - die Begründung steht an
            // ``Pruefstand/stoerung``.
            if let satz = stand.stoerung {
                Stoerung(satz: satz) { Task { await lade(z) } }
            }
            leistungen
            quellen
            abdeckungskarte
            stundenbilanz(z)
            fusstext
        }
        .task(id: z) { await lade(z) }
    }

    // MARK: - 1. Leistungen über den Tag

    /// **Ohne Beiwerk im Kartenkopf**, und das ist abgeschrieben: die Vorzeichenregel steht im
    /// Kartenkörper, nicht in der Kopfzeile. „Auf einem Telefon ist diese Zeile schon mit der
    /// Vorzeichenregel voll und wird abgeschnitten" (`DataCheck.tsx:74-75`).
    private var leistungen: some View {
        Karte(kicker: "Leistungen über den Tag") {
            if let satz = stand.kurvensatz {
                ladehinweis(satz, stand.kurve)
            } else {
                Pruefkurvenbild(kurve: kurve)
            }
        }
    }

    /// Der Satz einer Karte - mit Alfred daneben, wenn wirklich geladen wird.
    ///
    /// **Diese Seite ist der Grund, dass die Ente einen gemeinsamen Takt hat.** Hier warten vier
    /// Karten gleichzeitig: drei Abfragen, die nebeneinander laufen, und der Ereignisstrom.
    /// Vier Enten, die jede ihre eigene Dauerschleife bei ihrem eigenen Erscheinen anfingen,
    /// wackelten gegeneinander; ``Ladehinweis/zeiger(jetzt:)`` hängt allein am Zeitpunkt, und
    /// damit atmen alle vier als eine. Dieselbe Seite ist auch der Grund für die *kleine* Stufe
    /// an allen vier Stellen: keiner dieser Hinweise ist die Seite, jeder ist einer von vieren.
    ///
    /// **Und die Bedingung ist die Lage und nicht der Satz.** ``Pruefstand`` gibt denselben
    /// ``Leer``-Satz für „gekommen, aber leer“ und für „nicht gekommen“ wie für „lädt“; die
    /// Ente gehört nur zum letzten Fall. Ein Fehler ist kein Warten, und eine Ente, die neben
    /// einem Befund schaukelt, behauptet einen Vorgang, der vorbei ist.
    @ViewBuilder private func ladehinweis(
        _ satz: String, _ lage: Pruefstand.Lage
    ) -> some View {
        if lage == .laedt {
            Ladeente(satz: satz)
        } else {
            Leer(satz: satz)
        }
    }

    // MARK: - 2. Quellen

    /// **Die Verfügbarkeit steht vor der Bilanz, und der Augenblick vor der Karte**
    /// (`DataCheck.tsx:88-90`): die Wärmekarte zählt Stunden und sieht einen Ausfall erst nach
    /// einer. Für „läuft es jetzt“ ist sie zu träge, für „lief es letzte Woche“ ist sie das
    /// einzige Werkzeug - beide Fragen stellt man an derselben Stelle.
    private var quellen: some View {
        Karte(kicker: "Quellen", beiwerk: beiwerk("liefert gerade, was liefern soll?")) {
            Quellenkarte(
                zeilen: quellenzeilen, satz: stand.quellensatz,
                laedt: quellenlage == .laedt)
        }
    }

    // MARK: - 3. Kommen die Daten an?

    /// **Die Karte bleibt stehen, auch wenn die Abfrage scheitert.** Hier stand
    /// `if let a = abdeckung`, und damit nahm ein Fehlschlag Kopfzeile, Bilder und Note vom
    /// Schirm; die Vorlage behält die Stelle und schreibt dorthin ihren Satz
    /// (`CoverageMap.tsx:93, 101`). Eine Karte, die verschwindet, sieht aus wie eine Karte, die
    /// es nicht gibt.
    private var abdeckungskarte: some View {
        Karte(
            kicker: "Kommen die Daten an? \(Self.kartentage) Tage",
            beiwerk: beiwerk("Farbe = Minuten je Stunde, 0 bis 60")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let satz = stand.rastersatz {
                    ladehinweis(satz, stand.abdeckung)
                } else if let a = abdeckung {
                    Abdeckungskarte(reihen: Abdeckungsraster.baue(a), jetzt: haus.jetzt)
                }
                note
            }
        }
    }

    /// Die Note **in** der Karte und immer offen (`CoverageMap.tsx:125-130`).
    ///
    /// Zuerst `note_de` des Dienstes - eine Angabe zu *diesem* Zeitraum -, dann der Satz, der
    /// die leere von der roten Zelle unterscheidet. Beides lag bis zum 21.11.2026 in der
    /// zugeklappten Methodenkarte am Seitenfuß.
    private var note: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach([abdeckung?.noteDe, Abdeckungsraster.lesehilfe].compactMap { $0 }, id: \.self) {
                satz in
                absatz(satz)
            }
        }
    }

    // MARK: - 4. Stundenbilanz und auffällige Strecken

    /// **Reiner Text, und das soll er bleiben.** Die Tagesdiagnose ist eine Tabelle zum Lesen,
    /// keine Datenstruktur - der Dienst schickt sie darum ohne JSON-Umschlag. Sie in Zeilen zu
    /// zerlegen und neu zu setzen hieße, sie zu interpretieren; es ist „dieselbe Ausgabe, die
    /// auch über die API kommt, Zeichen für Zeichen … und kann sie unverändert weitergeben"
    /// (`DataCheck.tsx:111-113`).
    ///
    /// **Die Karte steht in jedem Fall** (`DataCheck.tsx:100-117`): hier war sie an
    /// `if let d = diagnose, !d.isEmpty` gebunden und verschwand, wo die Vorlage „Keine
    /// Diagnose verfügbar." in sie schreibt.
    private func stundenbilanz(_ z: Zeitraum) -> some View {
        Karte(
            kicker: "Stundenbilanz und auffällige Strecken", beiwerk: csvverweis(tag: z.anker)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let satz = stand.diagnosesatz {
                    ladehinweis(satz, stand.diagnose)
                } else if let d = diagnose {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(d)
                            .font(Schrift.zahlKlein)
                            .foregroundStyle(Farbe.text2)
                            .textSelection(.enabled)
                    }
                }
                // Der Befund zur Erzeugungslücke - gerechnet war er längst, gezeigt wurde er
                // nie. Die Begründung steht an ``Pruefworte/erzeugungsluecke(_:)``.
                if let satz = Pruefworte.erzeugungsluecke(kurve.luecken()) {
                    absatz(satz)
                }
            }
        }
    }

    /// Der Weg zu den Rohdaten (`DataCheck.tsx:104-108`).
    ///
    /// **Genauso gebaut wie die Jahressicherung auf `/system/zugang`**
    /// (`Seiten/Technik/ZugangSeite.swift:268-274`): die Adresse geht an den Browser des
    /// Geräts. Warum nicht `ShareLink` und was dabei nicht mitreist, steht dort ausführlich;
    /// gesagt wird es dem Benutzer am Fuß dieser Seite (``Pruefworte/csvVorbehalt``). Einen
    /// zweiten Weg dafür zu erfinden, wäre der Anfang von zwei Wegen.
    ///
    /// **Ohne Adresse kein Verweis**, wie dort: ``Zugang/export(art:tag:)`` gibt `nil`, wenn der
    /// Anker kein Kalendertag ist - dann steht hier nichts, statt ins Leere zu führen.
    private func csvverweis(tag: String) -> AnyView? {
        guard let adresse = haus.zugang.export(art: .minuten, tag: tag) else { return nil }
        return AnyView(
            Button(Pruefworte.csvVerweis) { oeffne(adresse) }
                .font(Schrift.winzig)
                .buttonStyle(.plain)
                .foregroundStyle(Farbe.amber))
    }

    // MARK: - Der Fließtext am Fuß

    /// Die erklärenden Absätze, **immer sichtbar und ohne Karte** (`DataCheck.tsx:119-147`).
    ///
    /// **Warum hier keine ``Methode`` mehr steht.** Diese Absätze erklären die Geste, mit der
    /// man die beiden Gegenproben vergleicht - und eine Geste, die man erst aufklappen muss,
    /// findet niemand. Die Vorlage setzt sie darum als `<Note>` ohne `<details>`; sie benutzt
    /// auf dieser Route weder `Methode` noch `CoverageNote`.
    private var fusstext: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Pruefworte.fuss, id: \.self) { satz in
                absatz(satz)
            }
        }
    }

    // MARK: - Bausteine

    /// Ein Absatz, wie `Note` ihn setzt (`ReportShell.tsx:143-145`), mit begrenzter Zeile.
    private func absatz(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: Self.lesebreite, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Was rechts im Kartenkopf steht (`ui/Card.tsx:26`, `right=…`).
    /// Größe, Farbe und Ausrichtung stehen in ``Kartenhinweis`` - hier standen sie
    /// zum zehnten Mal, und am Telefon alle drei falsch (``Karte/beiwerkzeile(_:)``).
    private func beiwerk(_ satz: String) -> AnyView {
        Kartenhinweis.beiwerk(satz)
    }

    // MARK: - Nachladen

    /// **Alle drei Abfragen nebeneinander.** Hier wurde der Verlauf abgewartet, bevor Abdeckung
    /// und Diagnose überhaupt begannen; die Vorlage holt Verlauf und Diagnose in einem
    /// `Promise.allSettled` (`DataCheck.tsx:38`) und die Abdeckung in einem eigenen,
    /// gleichzeitig laufenden Effekt (`CoverageMap.tsx:87-97`). Die Abdeckung fragt
    /// achtundzwanzig Tage ab und ist die langsamste der drei - sie hinter den Verlauf zu
    /// stellen, hieß die Seite zweimal warten zu lassen.
    ///
    /// **Immer achtundzwanzig Tage, unabhängig von der Spanne.** Die Karte ist das Gegenstück
    /// zur Frage „kommen die Daten an?“, und die beantwortet ein einzelner Tag nicht: ein
    /// Abriss, der jede Nacht wiederkommt, ist erst über Wochen ein Muster.
    ///
    /// **Die Abdeckung setzt ihre eigene Lage und nicht das Störungsband.** Sie ist eine Karte
    /// unter fünf; scheitert sie, ist das keine Nachricht über die Seite.
    private func lade(_ z: Zeitraum) async {
        kurvenlage = .laedt
        abdeckungslage = .laedt
        diagnoselage = .laedt

        async let minuten = try? haus.api.verlaufTag(z.anker)
        async let flaeche = try? haus.api.abdeckung(anker: z.anker, tage: Self.kartentage)
        // Die Tagesdiagnose gibt es nur für einen Tag; der Anker ist auf dieser Seite immer
        // einer, weil es hier keine andere Spanne gibt.
        async let tabelle = try? haus.api.diagnose(tag: z.anker)

        let historie = await minuten
        kurve = Pruefkurve.baue(tag: z.anker, historie: historie)
        kurvenlage = Pruefstand.lage(antwortDa: historie != nil, inhaltDa: !kurve.leer)

        let a = await flaeche
        abdeckung = a
        abdeckungslage = Pruefstand.lage(
            antwortDa: a != nil, inhaltDa: !(a?.series.isEmpty ?? true))

        let d = await tabelle
        diagnose = d
        diagnoselage = Pruefstand.lage(antwortDa: d != nil, inhaltDa: !(d?.isEmpty ?? true))
    }
}
