import DuckCurveKit
import SwiftUI

/// Heizkreise: die Räume über einen Tag, als Zeitreihe.
///
/// Die Liste zum Stellen steht im Bereich Haus; hier geht es um den Verlauf. Das ist die Frage,
/// die eine Liste nicht beantwortet: ob ein Raum die Nacht hält, oder ob er morgens von unten
/// anfängt. Vorlage: `apps/web/src/components/rooms/RoomsReport.tsx:597-604`, also
/// `Raumteile` mit `kacheln={false}` – Kacheln, Legende, Automatik und Stellfenster gehören
/// auf dieser Route nicht hierher, sondern nach Haus (`RoomsReport.tsx:286-296`).
///
/// **Drei Fälle und nicht einer** (`RoomsReport.tsx:438`, `:476`, `:513`). Hier entschied eine
/// einzige Bedingung – `verlauf.rooms.isEmpty` – über Matrix, Tabelle und Schlusssatz
/// zugleich. Meldet `/rooms` zehn Räume und `/rooms/history` noch keine Reihe (frische Brücke,
/// erster Tag, Reihe noch nicht geschrieben), stand im Browser die vollständige Tabelle und in
/// der App der Satz „Es liegen keine Werte der Einzelraumregelung vor“ – eine falsche Auskunft
/// über ein Haus, dessen Räume gerade gemeldet werden. Die Vorlage trennt deshalb: die Matrix
/// hängt an der **Tagesreihe**, Tabelle und leere Karte an den **Zeilen**, und die Zeilen
/// kommen am laufenden Tag aus den Istwerten (`Raumbild.swift:155-187`).
struct HeizkreiseSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    /// Die Istwerte neben dem Tagesverlauf.
    ///
    /// **Zwei Abfragen auf einer Seite, und `Berichtsseite` kennt nur eine.** Der Tagesverlauf
    /// kommt aus `/rooms/history`, die heutigen Zahlen der Tabelle aus `/rooms`; die Vorlage
    /// holt letztere am laufenden Tag alle dreissig Sekunden nach (`RoomsReport.tsx:38`).
    /// Darum steht dieser Zustand neben dem Gerüst und nicht darin.
    @State private var live: RoomsLiveOut?
    @State private var fehlerLive: ApiFehler?

    private var schmal: Bool { breite == .compact }

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        let heute = z.anker == haus.heute
        Berichtsseite { zeitraum, api in
            try await api.raeumeTag(zeitraum.anker, schrittMin: 15)
        } inhalt: { verlauf in
            seiteninhalt(verlauf, anker: z.anker, heute: heute)
        }
        .task(id: z.anker) { await holeLive(heute: heute) }
    }

    /// Die Seite von oben nach unten, in der Reihenfolge der Vorlage
    /// (`RoomsReport.tsx:420-557`).
    @ViewBuilder
    private func seiteninhalt(
        _ verlauf: RoomHistoryOut, anker: String, heute: Bool
    ) -> some View {
        // **Einmal gerechnet, dreimal gelesen**: dieselbe Liste entscheidet über die leere
        // Karte, trägt die Tabelle und bedingt den Namenshinweis. Zweimal gerechnet wäre
        // zweimal die Gelegenheit, es verschieden zu tun.
        let zeilen = Raumabweichung.tabellenzeilen(live: live, tag: verlauf, istHeute: heute)
        if let f = fehlerLive {
            // Der Knopf ist ein Zugewinn gegenüber dem Fehlerband der Vorlage
            // (`ReportShell.tsx:147-153`, dort ohne), und er bleibt: am Telefon ist ein
            // Neuladen der Seite teurer als ein Tippen.
            Stoerung(fehler: f) { Task { await holeLive(heute: heute) } }
        }
        // **Räume ohne Namen** (`RoomsReport.tsx:431-436`): die Brücke schickt die
        // Namensliste als eigene Meldung; bis dahin stehen die Kennungen da, und das
        // gehört dazugesagt. Die Bedingung hängt an den Zeilen und nicht an der Tagesreihe –
        // es sind die Namen der Räume, die dastehen, und die stehen in der Tabelle.
        if live?.named == false, !zeilen.isEmpty {
            notiz(Text(Self.namenshinweis))
        }
        if zeilen.isEmpty {
            keineRaeume
        }
        if !verlauf.rooms.isEmpty {
            matrixkarte(verlauf, anker: anker)
        }
        if !zeilen.isEmpty {
            Karte(kicker: "Die Räume als Tabelle") { raumtabelle(zeilen) }
        }
        schlusssatz
    }

    // MARK: - Keine Räume

    /// Die leere Karte – **nur, wenn es keine Zeilen gibt** (`RoomsReport.tsx:438`), nicht
    /// schon, wenn die Tagesreihe leer ist.
    ///
    /// Gestalt wie dort: ein `CardHead` und ein Absatz darunter (`:439-445`), kein `Leer`.
    /// `Karte` zeichnet den Kicker an der Wand gesperrt und am Telefon als Überschrift
    /// (`Karte.swift:54-83`) – genau das, was `handy.css:184` mit dem `CardHead` tut.
    private var keineRaeume: some View {
        Karte(kicker: "Keine Räume") {
            Text(Self.keineRaeumeSatz)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.absatzbreite, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Die Matrix

    /// **Die Hauptkarte, und zwar zuerst.** Nicht die Temperaturen, sondern die Abweichung vom
    /// Ziel: zehn Räume zwischen 18 und 21 Grad sind als Kurven ein flaches Band. So macht es
    /// das Dashboard (`RoomsReport.tsx:476-511`), und es beantwortet die Frage, die diese Seite
    /// stellt – welcher Raum bestimmt die Vorlauftemperatur.
    ///
    /// Sie hängt allein an der Tagesreihe (`:476`, `matrix` aus `tag.rooms`): ohne Reihe gibt
    /// es keinen Verlauf zu zeigen, auch wenn die Istwerte zehn Räume kennen.
    private func matrixkarte(_ verlauf: RoomHistoryOut, anker: String) -> some View {
        Karte(
            kicker: "Abweichung im Tagesverlauf",
            beiwerk: AnyView(
                Text(Self.matrixsatz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            )
        ) {
            Abweichungsmatrix(verlauf: verlauf, bisStelle: bisStelle(verlauf, anker: anker))
        }
    }

    /// Das erste Fenster, das noch nicht gewesen ist.
    ///
    /// **Zwei Zahlen kommen aus der Antwort und nicht aus einer Annahme.** Die Schrittbreite
    /// ist `tag.step_min` und nicht die angefragte Viertelstunde (`RoomsReport.tsx:366`:
    /// „wenn die Schnittstelle eines Tages eine andere Breite liefert“), und der Zeitpunkt ist
    /// `live.at` und nicht die Hausuhr (`:370-373`) – begründet in
    /// ``Raumabweichung/gemessenBis(live:jetzt:)``.
    private func bisStelle(_ verlauf: RoomHistoryOut, anker: String) -> Int? {
        Raumabweichung.gewesen(
            tag: anker,
            jetzt: Raumabweichung.gemessenBis(live: live, jetzt: haus.jetzt),
            schrittMin: verlauf.stepMin)
    }

    // MARK: - Die Tabelle

    /// Die Tabelle der Vorlage: Raum, Etage, Ist, Ziel, Abweichung, Ventil am Tag, Kreise
    /// (`RoomsReport.tsx:519-525`).
    ///
    /// **Ist und Ziel sind der letzte Messwert, kein Tagesmittel.** Hier stand „Im Tagesmittel“
    /// mit vier anderen Spalten; ein Mittel über einen Tag sagt aber nichts darüber, welcher
    /// Raum gerade abfällt – und genau das ist die Frage dieser Seite.
    ///
    /// **Am Telefon vier Spalten, und zwar diese vier.** `handy.css:376-379` blendet Etage,
    /// Ventil und Kreise aus (`display: none`) und lässt Raum, Ist, Ziel und Abweichung
    /// nebeneinander stehen; die dritte Zahl ist die Differenz der beiden anderen und gehört
    /// daneben. Darum stellt diese Seite nach Breite zwei Spaltenlisten auf, statt eine
    /// umzusortieren: ``Tabelle/immerSichtbar`` hält die **ersten** n Spalten fest
    /// (`Bericht.swift:256-258`), und eine Liste, die beides können müsste, hätte die Etage
    /// auch an der Wand nach hinten geschoben.
    private func raumtabelle(_ zeilen: [Raumzeile]) -> some View {
        Tabelle(
            zeilennamen: zeilen.map(\.name),
            spalten: schmal ? handyspalten(zeilen) : vollespalten(zeilen),
            immerSichtbar: 3
        )
    }

    /// Die vier Spalten des Telefons: Raum (als Zeilenname), Ist, Ziel, Abweichung.
    private func handyspalten(_ zeilen: [Raumzeile]) -> [Tabelle.Spalte] {
        [istspalte(zeilen), zielspalte(zeilen), abweichungsspalte(zeilen)]
    }

    /// Alle sieben Spalten in der Reihenfolge der Vorlage.
    private func vollespalten(_ zeilen: [Raumzeile]) -> [Tabelle.Spalte] {
        [
            etagenspalte(zeilen), istspalte(zeilen), zielspalte(zeilen),
            abweichungsspalte(zeilen), ventilspalte(zeilen), kreisspalte(zeilen),
        ]
    }

    /// Die Etage an zweiter Stelle, und leiser als die Zahlen (`RoomsReport.tsx:535`: `text-3`).
    /// Sie ist eine Angabe der Anlage und keine Messung.
    private func etagenspalte(_ zeilen: [Raumzeile]) -> Tabelle.Spalte {
        .init(
            name: "Etage", zellen: zeilen.map(\.etage),
            farben: zeilen.map { _ -> Color? in Farbe.text3 })
    }

    private func istspalte(_ zeilen: [Raumzeile]) -> Tabelle.Spalte {
        .init(name: "Ist", zellen: zeilen.map { Formate.celsius($0.ist, stellen: 1) })
    }

    private func zielspalte(_ zeilen: [Raumzeile]) -> Tabelle.Spalte {
        .init(name: "Ziel", zellen: zeilen.map { Formate.celsius($0.ziel, stellen: 1) })
    }

    /// **Ohne Farbe** (`RoomsReport.tsx:538`: die Zelle erbt `text-1`).
    ///
    /// Hier stand die Abweichung in der Farbe ihrer Stufe. Das ist nicht nur ein Unterschied
    /// zur Vorlage, sondern schlecht zu lesen: „am Ziel“ ist die häufigste Zeile, und
    /// `abwNull` `#3A5560` auf der Kartenfläche `#0F2E3D` ergibt rund 1,8:1
    /// (`Marken.swift:148`, `:28`). Die fünf Stufen sind in der Vorlage Flächenfarben der
    /// Matrix und keine Schriftfarben – dort tragen sie, weil eine Fläche Farbe aushält. Wer
    /// die Abweichung farbig sehen will, liest die Karte darüber.
    private func abweichungsspalte(_ zeilen: [Raumzeile]) -> Tabelle.Spalte {
        .init(
            name: "Abweichung",
            zellen: zeilen.map { $0.abweichung.map(Raumabweichung.kelvin) ?? Formate.leer })
    }

    private func ventilspalte(_ zeilen: [Raumzeile]) -> Tabelle.Spalte {
        .init(
            name: "Ventil am Tag",
            zellen: zeilen.map { Raumabweichung.anteilText($0.tagesventil) })
    }

    private func kreisspalte(_ zeilen: [Raumzeile]) -> Tabelle.Spalte {
        .init(
            name: "Kreise",
            zellen: zeilen.map { $0.kreise > 0 ? String($0.kreise) : Formate.leer })
    }

    // MARK: - Der Schlusssatz

    /// **Ohne Bedingung** (`RoomsReport.tsx:549`): er steht auch unter der leeren Karte.
    ///
    /// Er lag hier im else-Zweig und fiel damit genau dann weg, wenn er am meisten nützt – wer
    /// die Seite ohne Räume öffnet, erfuhr nicht, was hier überhaupt gemessen wird.
    ///
    /// **Halbfett auf „Sollwert plus Versatz“** (`<strong>`, `:550`). Wer nicht weiß, dass auf
    /// Sollwert plus Versatz geregelt wird, liest die Spalte „Ziel“ als das, was er eingestellt
    /// hat – und das ist sie nicht. Der Satzteil der Vorlage über die beiden Zahlen unter dem
    /// Zielwert spricht über die Kachel und fehlt hier zu Recht.
    private var schlusssatz: some View {
        let anfang = Text("Geregelt wird auf ")
        let stark = Text("Sollwert plus Versatz").font(Self.winzigHalbfett)
        return notiz(anfang + stark + Text(Self.schlusssatzEnde))
    }

    // MARK: - Hinweisabsätze

    /// Ein Hinweisabsatz, wie `Note` ihn setzt (`ReportShell.tsx:144`).
    ///
    /// **Mit Zeilenbegrenzung, und die ist dort ausdrücklich begründet** (`:136-144`): über die
    /// volle Breite eines 1440er Schirms findet das Auge die nächste Zeile nicht wieder. An der
    /// Wandanzeige stand dieser Satz bisher als eine Zeile über die ganze Karte.
    private func notiz(_ satz: Text) -> some View {
        satz
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: Self.lesebreite, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `max-w-[90ch]` der Vorlage (`ReportShell.tsx:144`), auf 11,5 Punkte gerechnet.
    private static let lesebreite: CGFloat = 560
    /// `max-w-[70ch]` des Absatzes in der leeren Karte (`RoomsReport.tsx:441`), auf 13 Punkte.
    private static let absatzbreite: CGFloat = 440
    /// Die halbfette Auszeichnung in einem Hinweisabsatz.
    ///
    /// ``Schrift`` hat keine Auszeichnung in dieser Größe, und sie gehört auch nicht dorthin:
    /// gebraucht wird sie an genau einer Stelle. Dieselbe Schriftfamilie
    /// (`Typografie.swift:31`), nur die halbfette Schnittlage.
    private static let winzigHalbfett = Font.custom(
        Schrift.sansHalbfett, size: 11.5, relativeTo: .caption2)

    // MARK: - Die Sätze

    // Angeschriebene Typen und keine Verkettung in der Ansicht: lange Ausdrücke in einer
    // `View` kosten den Übersetzer mehr Zeit, als er sich nimmt.

    private static let namenshinweis: String =
        "Die Räume heißen hier nach ihrer Kennung in der Heizungsregelung. Die Namensliste "
        + "kommt als eigene Meldung der Brücke und steht nach ihrem nächsten Start zur "
        + "Verfügung."

    private static let keineRaeumeSatz: String =
        "Es liegen keine Werte der Einzelraumregelung vor. Die Brücke liest sie, sobald in "
        + "ihrer Konfiguration die Adresse des Controme-Servers eingetragen ist."

    private static let matrixsatz: String =
        "Je Raum und Viertelstunde die Abweichung vom Zielwert. Der Raum, der zuerst abfällt, "
        + "bestimmt die nötige Vorlauftemperatur für alle."

    private static let schlusssatzEnde: String =
        " – Controme rechnet das in seiner eigenen Oberfläche vor und zeigt das Ergebnis als "
        + "Zieltemperatur. Der Versatz ist dabei die Summe mehrerer benannter Anpassungen, "
        + "nicht nur der Witterung. Die Antriebe am Verteiler sind auf oder zu – ein "
        + "Zwischenwert im Streifen heißt „ein Teil der Kreise“ oder „einen Teil des "
        + "Fensters“, nicht „halb offen“. Ein Tippen auf eine Kachel im Bereich Haus stellt "
        + "den Sollwert dieses Raums, dauerhaft und in halben Grad; die Ventile bleiben Sache "
        + "des Reglers."

    // MARK: - Die Istwerte

    /// Die Istwerte holen und, solange der laufende Tag gezeigt wird, alle dreissig Sekunden
    /// nachziehen.
    private func holeLive(heute: Bool) async {
        while !Task.isCancelled {
            do {
                live = try await haus.api.raeume()
                fehlerLive = nil
            } catch {
                // Nur die Istwerte scheitern hier; der Tagesverlauf hat sein eigenes Gerüst.
                fehlerLive = error as? ApiFehler ?? .netz(error.localizedDescription)
            }
            guard heute else { return }
            try? await Task.sleep(for: Raumabweichung.liveTakt)
        }
    }
}
