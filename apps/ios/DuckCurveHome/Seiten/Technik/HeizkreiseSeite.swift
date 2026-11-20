import DuckCurveKit
import SwiftUI

/// Heizkreise: die Räume über einen Tag, als Zeitreihe.
///
/// Die Liste zum Stellen steht im Bereich Haus; hier geht es um den Verlauf. Das ist die Frage,
/// die eine Liste nicht beantwortet: ob ein Raum die Nacht hält, oder ob er morgens von unten
/// anfängt.
struct HeizkreiseSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    /// Die Istwerte neben dem Tagesverlauf.
    ///
    /// **Zwei Abfragen auf einer Seite, und `Berichtsseite` kennt nur eine.** Der Tagesverlauf
    /// kommt aus `/rooms/history`, die heutigen Zahlen der Tabelle aus `/rooms`; die Vorlage
    /// holt letztere am laufenden Tag alle dreissig Sekunden nach (`RoomsReport.tsx:38`).
    /// Darum steht dieser Zustand neben dem Gerüst und nicht darin.
    @State private var live: RoomsLiveOut?
    @State private var fehlerLive: ApiFehler?

    var body: some View {
        let z = wegweiser.zeitraum(jetzt: haus.jetzt)
        Berichtsseite { z, api in
            try await api.raeumeTag(z.anker, schrittMin: 15)
        } inhalt: { verlauf in
            if let f = fehlerLive {
                Stoerung(fehler: f) { Task { await holeLive(heute: z.anker == haus.heute) } }
            }
            // **Räume ohne Namen** (`RoomsReport.tsx:431-436`): die Brücke schickt die
            // Namensliste als eigene Meldung; bis dahin stehen die Kennungen da, und das
            // gehört dazugesagt.
            if live?.named == false, !verlauf.rooms.isEmpty {
                Text(
                    "Die Räume heißen hier nach ihrer Kennung in der Heizungsregelung. Die "
                        + "Namensliste kommt als eigene Meldung der Brücke und steht nach ihrem "
                        + "nächsten Start zur Verfügung."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            }
            if verlauf.rooms.isEmpty {
                Karte {
                    Leer(
                        satz: "Keine Räume",
                        dazu: "Es liegen keine Werte der Einzelraumregelung vor. Die Brücke "
                            + "liest sie, sobald in ihrer Konfiguration die Adresse des "
                            + "Controme-Servers eingetragen ist.")
                }
            } else {
                // **Die Hauptkarte, und zwar zuerst.** Nicht die Temperaturen, sondern die
                // Abweichung vom Ziel: zehn Raeume zwischen 18 und 21 Grad sind als Kurven
                // ein flaches Band. So macht es das Dashboard (`rooms/RoomsReport.tsx`), und
                // es beantwortet die Frage, die diese Seite stellt - welcher Raum bestimmt
                // die Vorlauftemperatur.
                Karte(
                    kicker: "Abweichung im Tagesverlauf",
                    beiwerk: AnyView(
                        Text(
                            "Je Raum und Viertelstunde die Abweichung vom Zielwert. Der Raum, "
                                + "der zuerst abfällt, bestimmt die nötige Vorlauftemperatur "
                                + "für alle."
                        )
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                    )
                ) {
                    Abweichungsmatrix(
                        verlauf: verlauf,
                        bisStelle: Raumabweichung.gewesen(tag: z.anker, jetzt: haus.jetzt)
                    )
                }
                Karte(kicker: "Die Räume als Tabelle") {
                    raumtabelle(verlauf, heute: z.anker == haus.heute)
                }
                // **Offen, nicht zugeklappt** (`RoomsReport.tsx:549-557`). Wer nicht weiß,
                // dass auf Sollwert plus Versatz geregelt wird, liest die Spalte „Ziel“ als
                // das, was er eingestellt hat - und das ist sie nicht.
                Text(
                    "Geregelt wird auf Sollwert plus Versatz – Controme rechnet das in seiner "
                        + "eigenen Oberfläche vor und zeigt das Ergebnis als Zieltemperatur. "
                        + "Der Versatz ist dabei die Summe mehrerer benannter Anpassungen, "
                        + "nicht nur der Witterung. Die Antriebe am Verteiler sind auf oder zu "
                        + "– ein Zwischenwert im Streifen heißt „ein Teil der Kreise“ oder "
                        + "„einen Teil des Fensters“, nicht „halb offen“. Ein Tippen auf "
                        + "eine Kachel im Bereich Haus stellt den Sollwert dieses Raums, "
                        + "dauerhaft und in halben Grad; die Ventile bleiben Sache des Reglers."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: z.anker) { await holeLive(heute: z.anker == haus.heute) }
    }

    /// Die Tabelle der Vorlage: Raum, Etage, Ist, Ziel, Abweichung, Ventil am Tag, Kreise.
    ///
    /// **Ist und Ziel sind der letzte Messwert, kein Tagesmittel.** Hier stand „Im Tagesmittel“
    /// mit vier anderen Spalten; ein Mittel über einen Tag sagt aber nichts darüber, welcher
    /// Raum gerade abfällt - und genau das ist die Frage dieser Seite.
    private func raumtabelle(_ verlauf: RoomHistoryOut, heute: Bool) -> some View {
        let zeilen = Raumabweichung.tabellenzeilen(live: live, tag: verlauf, istHeute: heute)
        return Tabelle(
            zeilennamen: zeilen.map(\.name),
            spalten: [
                .init(name: "Ist", zellen: zeilen.map { Formate.celsius($0.ist, stellen: 1) }),
                .init(name: "Ziel", zellen: zeilen.map { Formate.celsius($0.ziel, stellen: 1) }),
                .init(
                    name: "Abweichung",
                    zellen: zeilen.map { $0.abweichung.map(Raumabweichung.kelvin) ?? Formate.leer },
                    farben: zeilen.map {
                        $0.abweichung.map { Color(Marken.abweichungsfarbe(kelvin: $0)) }
                    }),
                .init(name: "Etage", zellen: zeilen.map(\.etage)),
                .init(
                    name: "Ventil am Tag",
                    zellen: zeilen.map { Raumabweichung.anteilText($0.tagesventil) }),
                .init(
                    name: "Kreise",
                    zellen: zeilen.map { $0.kreise > 0 ? String($0.kreise) : Formate.leer }),
            ],
            // Ist, Ziel und Abweichung gehören am Telefon nebeneinander: die dritte Zahl ist
            // die Differenz der beiden anderen (`handy.css:377-379`).
            immerSichtbar: 3
        )
    }

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
