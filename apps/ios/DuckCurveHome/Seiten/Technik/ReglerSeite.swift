import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Regler: was am Regler eingestellt ist – gelesen über den Bus, und was sich
/// stellen lässt, lässt sich hier stellen.
///
/// Oben die Heizkurve mit ihren Griffen, darunter das Pult: ein Kanalzug je Zahl, Schalter für
/// alles, was nur Stufen kennt. Was jemand bewegt, ist zunächst ein Entwurf; erst „Übernehmen“
/// schickt die Änderungen ab, nach einer Übersicht, was sich von welchem auf welchen Wert
/// ändert (`apps/web/src/components/waermepumpe/Regler.tsx:11-23`).
///
/// **Das ist die heikelste Seite der ganzen App, und sie ist mit vier Vorsichten gebaut:**
///
/// 1. **Ohne Gerätevergleich bewegt sich nichts.** Eine Einstellung muss stellbar, gelesen und
///    mit dem Bediengerät verglichen sein, und der Dienst muss einen Stellbefehl loswerden
///    können – erst dann nimmt ein Schieber, ein Griff oder ein Stufenknopf einen Finger an
///    (``Reglerpult/bedienbar(_:stellenMoeglich:)``). Das war die schwerste Lücke dieser Seite:
///    bis zum 20.11.2026 prüfte sie nur `stellbar` und las den Wert roh, ohne seine Güte – ein
///    nie verglichener und ein veralteter Wert waren hier bewegbar und absendbar. Der Dienst
///    lehnte ab, aber die Oberfläche hatte es angeboten.
/// 2. **Gestellt ist erst, wenn der Regler es zurückmeldet.** Der Dienst antwortet auf einen
///    Griff mit dem vollständigen Satz der Einstellungen, nicht mit „in Ordnung“ – und bis die
///    Antwort da ist, steht der alte Wert da und darunter „gesendet …, wartet auf den Regler“.
///    Solange etwas wartet, wird alle fünf Sekunden nachgefragt statt alle sechzig
///    (``Reglerpult/takt(wartet:)``).
/// 3. **Nichts wird stillschweigend gestellt.** Zwei Knopfdrücke mit einer Liste dazwischen, in
///    der jede Änderung mit altem und neuem Wert steht (``Uebernahmeleiste``). Eine
///    Heizkurvensteilheit, die versehentlich von 0,4 auf 1,4 geht, merkt man im Februar an der
///    Rechnung.
/// 4. **Was der Dienst nicht als stellbar meldet, wird nur gezeigt.** `stellbar` kommt vom
///    Dienst und nicht aus einer Liste hier – er weiß, was der Bus hergibt. Was nur gelesen
///    wird, steht in einem eigenen, zugeklappten Abschnitt und nicht zwischen den Reglern.
///
/// **Gerechnet wird im Kern** (``Reglerpult``): die Sperren, das Raster, die Näherung der
/// Heizkurve, die Stufenwörter, die vier Fassungen der Fußzeile und die Absätze, die wörtlich
/// dastehen müssen. Hier bleiben die Maße und die Reihenfolge.
struct ReglerSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @State private var einstellungen: ReglerEinstellungenOut?
    @State private var fehler: ApiFehler?
    @State private var entwurf: Reglerpult.Entwurf = [:]
    @State private var uebersicht = false
    @State private var laeuft = false
    @State private var meldungen: [Meldung] = []
    @State private var stunden: [Reglerpult.Kurvenpunkt] = []
    @State private var kennzahlen: ReglerKennzahlenOut?
    @State private var nurLesenOffen = false
    @State private var protokollOffen = true
    @State private var vermerkeOffen = false

    /// Eine Antwort des Dienstes auf einen Stellbefehl, mit ✓ oder ✗ (`Regler.tsx:137-146`).
    private struct Meldung: Identifiable {
        let ok: Bool
        let text: String
        let id = UUID()
    }

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let e = einstellungen {
                inhalt(e)
            } else if fehler == nil {
                Karte { Leer(satz: "Wird vom Bus gelesen …") }
            }
        }
        .task { await beobachte() }
        .task { await holeStunden() }
        .task { kennzahlen = try? await haus.api.reglerKennzahlen(tage: 7) }
        .safeAreaInset(edge: .bottom, spacing: 0) { leiste }
    }

    /// Die Reihenfolge ist die der Vorlage (`Regler.tsx:117-313`).
    ///
    /// **In vier Teilen, weil ein `ViewBuilder` zehn Kinder nimmt.** Die Seite hat dreizehn.
    @ViewBuilder private func inhalt(_ e: ReglerEinstellungenOut) -> some View {
        kopfteil(e)
        reglerteil(e)
        listenteil(e)
        fussteil(e)
    }

    @ViewBuilder private func kopfteil(_ e: ReglerEinstellungenOut) -> some View {
        kopf(e)
        if e.stellenMoeglich != true, let hindernis = e.hindernisDe, !hindernis.isEmpty {
            hinderniskasten(hindernis)
        }
        if Reglerpult.anleitungNoetig(e.werte) {
            Text(Reglerpult.anleitungssatz)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !meldungen.isEmpty {
            meldungskasten
        }
    }

    @ViewBuilder private func reglerteil(_ e: ReglerEinstellungenOut) -> some View {
        kurvenkarte(e)
        Pultkarte(
            gruppen: Reglerpult.pultgruppen(e.werte), entwurf: entwurf,
            stellenMoeglich: stellbar(e), darfStellen: haus.darfSchalten, stelle: setze,
            vergleichen: { vergleiche($0, true) })
        Schalterkarte(
            schalter: Reglerpult.schalter(e.werte), entwurf: entwurf,
            stellenMoeglich: stellbar(e), darfStellen: haus.darfSchalten, stelle: setze,
            vergleichen: { vergleiche($0, true) })
    }

    @ViewBuilder private func listenteil(_ e: ReglerEinstellungenOut) -> some View {
        nurLesenKarte(e)
        protokollkarte(e)
        vermerkekarte(e)
        kennzahlenkarte()
    }

    @ViewBuilder private func fussteil(_ e: ReglerEinstellungenOut) -> some View {
        Methode(
            e.hinweiseDe + [
                e.hindernisDe,
                e.stellenJeTag.map { "Höchstens \($0) Griffe am Tag." },
                "Gelesen über den eBUS. Gestellt ist eine Einstellung erst, wenn der "
                    + "Regler sie zurückmeldet.",
            ]
        )
        fussverweise()
    }

    /// **Stellen heißt hier zweierlei**: der Dienst muss können, und der Mensch muss dürfen.
    /// `darfSchalten` ist die Gästesperre der App und hat in der Vorlage kein Gegenstück; sie
    /// kommt hier dazu, nicht an ihre Stelle.
    ///
    /// **Das reicht für die Schieber, nicht für den Vergleichsknopf.** Wer nicht stellen darf,
    /// bekommt hier `false`, und damit greift im Kern der Sperrgrund „nicht verglichen“ vor
    /// „Stellen nicht möglich“ (``Reglerpult/sperre(_:stellenMoeglich:)``) – die Fußzeile zeigt
    /// also den gestrichelten Knopf. Der schaltet diese Sperre für alle ab, und darum geht
    /// `darfSchalten` zusätzlich und ungemischt an die Karten (siehe ``Vergleichsknopf``).
    private func stellbar(_ e: ReglerEinstellungenOut) -> Bool {
        haus.darfSchalten && e.stellenMoeglich == true
    }

    // MARK: - Kopf und Absätze

    /// **Der führende Satz ist der Satz des Dienstes, groß** (`globals.css:789`: 22 Punkte, am
    /// Telefon 19) – darunter nicht die Uhrzeit, sondern wie weit der Vergleich gediehen ist.
    /// Eine Uhrzeit sagt, wann gelesen wurde; diese Zeile sagt, wie viel sich bewegen lässt.
    private func kopf(_ e: ReglerEinstellungenOut) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(e.satzDe)
                .font(Schrift.satz)
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            Text(Reglerpult.verglichenSatz(e.werte, fehler: fehler?.rat))
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Der Warnabsatz, wenn der Dienst gerade keinen Stellbefehl loswird (`Regler.tsx:126-130`,
    /// `globals.css:792`). Er stand bisher zugeklappt in der Methode, und oben stand dafür
    /// „Stellen ist gesperrt“ in 11,5 Punkten.
    private func hinderniskasten(_ hindernis: String) -> some View {
        Text(Reglerpult.hindernissatz(hindernis))
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Farbe.amber.opacity(0.09), in: absatzumriss)
            .overlay(absatzumriss.strokeBorder(Farbe.amber.opacity(0.55), lineWidth: 1))
            .accessibilityAddTraits(.isStaticText)
    }

    private var absatzumriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    /// Je Antwort eine Zeile mit ✓ oder ✗ und dem Satz des Dienstes – nicht eine Karte mit der
    /// letzten Meldung (`Regler.tsx:137-146`). Jede Einstellung ist ein eigener Befehl auf dem
    /// Bus, also hat jede ihre eigene Antwort.
    private var meldungskasten: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(meldungen) { m in
                Text("\(m.ok ? "✓" : "✗") \(m.text)")
                    .font(Schrift.klein)
                    .foregroundStyle(m.ok ? Farbe.text1 : Farbe.alarm)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Ausblenden") { meldungen = [] }
                .font(Schrift.klein)
                .buttonStyle(.plain)
                .foregroundStyle(Farbe.text2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Farbe.flaeche2, in: absatzumriss)
        .overlay(absatzumriss.strokeBorder(Farbe.linie2, lineWidth: 1))
    }

    // MARK: - Die Karten

    private func kurvenkarte(_ e: ReglerEinstellungenOut) -> some View {
        Karte(kicker: "Heizkurve") {
            VStack(alignment: .leading, spacing: 10) {
                Heizkurvenbild(
                    werte: e.werte, entwurf: entwurf, stellenMoeglich: stellbar(e),
                    stunden: stunden, stelle: setze)
                Text(Reglerpult.naeherungssatz)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// **Ein eigener, zugeklappter Abschnitt** (`Regler.tsx:201-228`). Acht Zeilen, an denen
    /// nichts zu tun ist, standen bisher gleichberechtigt zwischen denen, an denen etwas zu tun
    /// ist.
    @ViewBuilder private func nurLesenKarte(_ e: ReglerEinstellungenOut) -> some View {
        let lesen = Reglerpult.nurLesen(e.werte)
        if !lesen.isEmpty {
            Karte {
                DisclosureGroup(isExpanded: $nurLesenOffen) {
                    Tabelle(
                        zeilennamen: lesen.map(lesezeilenname),
                        spalten: [
                            .init(
                                name: "Wert", zellen: lesen.map(Reglerpult.wertText),
                                farben: lesen.map { Reglerpult.gelesen($0) ? Farbe.amber : Farbe.text3 }),
                            .init(name: "gelesen", zellen: lesen.map(Reglerpult.standText)),
                            .init(name: "Kennung", zellen: lesen.map(\.kennung)),
                        ]
                    )
                    .padding(.top, 8)
                } label: {
                    Text("Nur zum Lesen (\(lesen.count))")
                        .font(Schrift.karte).foregroundStyle(Farbe.text1)
                }
                .tint(Farbe.text3)
            }
        }
    }

    private func lesezeilenname(_ w: ReglerEinstellungOut) -> String {
        let name = "\(w.gruppeDe): \(w.nameDe)"
        guard let lesart = w.lesartDe, !lesart.isEmpty else { return name }
        return name + "\nlaut Busbeschreibung: " + lesart
    }

    /// Was zuletzt gestellt wurde – aufgeklappt, denn es ist die Gegenprobe zu dem, was man
    /// gerade vorhat (`Regler.tsx:230-256`). Fünf Spalten mit Datum, nicht eine Zeile ohne.
    @ViewBuilder private func protokollkarte(_ e: ReglerEinstellungenOut) -> some View {
        if !e.protokoll.isEmpty {
            Karte {
                DisclosureGroup(isExpanded: $protokollOffen) {
                    Tabelle(
                        zeilennamen: e.protokoll.map(\.nameDe),
                        spalten: [
                            .init(
                                name: "Zeit",
                                zellen: e.protokoll.map { Formate.tagUndUhr(Zeit.ausIso($0.at), jetzt: haus.jetzt) }),
                            .init(name: "von", zellen: e.protokoll.map(\.vonDe)),
                            .init(name: "auf", zellen: e.protokoll.map(\.aufDe)),
                            .init(name: "wer", zellen: e.protokoll.map { $0.urheberDe ?? Formate.leer }),
                        ]
                    )
                    .padding(.top, 8)
                } label: {
                    Text("Was zuletzt gestellt wurde (\(e.protokoll.count))")
                        .font(Schrift.karte).foregroundStyle(Farbe.text1)
                }
                .tint(Farbe.text3)
            }
        }
    }

    /// Einen Vermerk zurücknehmen (`Regler.tsx:258-271`).
    ///
    /// **Zurücknehmen löscht zugleich den Entwurf dieser Einstellung** (`Regler.tsx:76`): wer
    /// den Vergleich zurückzieht, sagt „ich weiß nicht mehr, ob das stimmt“ – und dann darf ein
    /// Entwurf, der darauf aufbaut, nicht stehen bleiben.
    @ViewBuilder private func vermerkekarte(_ e: ReglerEinstellungenOut) -> some View {
        let verglichen = Reglerpult.stellbare(e.werte).filter { $0.bestaetigt == true }
        if !verglichen.isEmpty {
            Karte {
                DisclosureGroup(isExpanded: $vermerkeOffen) {
                    Umbruchzeile(abstand: 8, zeilenabstand: 8) {
                        ForEach(verglichen, id: \.schluessel) { w in
                            Button("\(w.gruppeDe): \(w.nameDe) ist doch nicht verglichen") {
                                vergleiche(w, false)
                            }
                            .font(Schrift.klein)
                            .buttonStyle(.plain)
                            // Auch das Zurücknehmen ist ein Vermerk am Dienst und gehört dem
                            // Hausherrn - derselbe Grund wie am ``Vergleichsknopf``.
                            .disabled(!haus.darfSchalten)
                            .opacity(haus.darfSchalten ? 1 : 0.45)
                            .foregroundStyle(Farbe.text2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Vermerke zurücknehmen")
                        .font(Schrift.karte).foregroundStyle(Farbe.text1)
                }
                .tint(Farbe.text3)
            }
        }
    }

    /// Was der Regler in den letzten Tagen wirklich getan hat, nach Betriebszustand.
    ///
    /// **Diese Karte hängt in der Vorlage an `/waerme/waermepumpe`** und nicht am Regler
    /// (`waermepumpe/Waermepumpe.tsx:104`). Sie bleibt hier bewusst stehen, und zwar als
    /// letzte: sie ist die Gegenprobe zu allem darüber. Dort steht, was eingestellt *ist*; hier
    /// steht, wie viele Minuten die Anlage in welchem Zustand war und mit welchem Vorlauf. Eine
    /// Heizkurve, die auf dem Papier stimmt, und ein Vorlauf, der ständig fünf Kelvin darüber
    /// liegt, sind zwei verschiedene Auskünfte. Sie an ihren Platz in der Vorlage zu verschieben
    /// heißt, die Wärmepumpenseite zu ändern, und das ist ein eigener Griff.
    ///
    /// **Am Telefon rollt sie seitlich.** Sie ist die zweite der beiden Tabellen, die die
    /// Vorlage nicht zur Liste zerfallen lässt (`waermepumpe/Kennzahlen.tsx:50` in `.kl-rollt`,
    /// `globals.css:912-913`, `handy.css:246-247`) - mit dreizehn Spalten in der Vorlage ist sie
    /// die breiteste, die das Projekt hat.
    @ViewBuilder private func kennzahlenkarte() -> some View {
        if let k = kennzahlen, !k.zeilen.isEmpty {
            Karte(kicker: "Was der Regler tat", titel: "\(k.tage) Tage") {
                Tabelle(
                    zeilennamen: k.zeilen.map { "Zustand \($0.code)" },
                    spalten: kennzahlenspalten(k.zeilen),
                    handyfassung: .rollt
                )
            }
        }
    }

    private func kennzahlenspalten(_ zeilen: [ReglerKennzahlOut]) -> [Tabelle.Spalte] {
        [
            .init(name: "Minuten", zellen: zeilen.map { Formate.zahl(Double($0.minuten), stellen: 0) }),
            .init(name: "davon gelaufen", zellen: zeilen.map { Formate.zahl(Double($0.laufMin), stellen: 0) }),
            .init(name: "Vorlauf", zellen: zeilen.map { Formate.celsius($0.vorlaufC, stellen: 1) }),
            .init(name: "Sollvorlauf", zellen: zeilen.map { Formate.celsius($0.vorlaufSollC, stellen: 1) }),
            .init(name: "angefordert", zellen: zeilen.map { Formate.prozent($0.angefordertAnteil) }),
            .init(name: "Heizstab", zellen: zeilen.map { Formate.prozent($0.heizstabAnteil) }),
            .init(name: "zuletzt", zellen: zeilen.map { $0.zuletzt.map { Formate.hhmm(iso: $0) } ?? Formate.leer }),
        ]
    }

    /// Die zwei Verweise im Fuß (`Regler.tsx:279-282`): was der Regler aus der Kurve wirklich
    /// macht, steht auf der Betriebsseite – und genau darauf zielt der Näherungsabsatz.
    private func fussverweise() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            verweis("Die Heizkurve, wie sie gefahren wird ›", nach: "/waerme/waermepumpe/betrieb")
            verweis("Die Wärmepumpe jetzt ›", nach: "/waerme/waermepumpe")
        }
        .padding(.top, 2)
    }

    private func verweis(_ wort: String, nach weg: String) -> some View {
        Button(wort) { wegweiser.gehe(weg) }
            .font(Schrift.klein)
            .buttonStyle(.plain)
            .foregroundStyle(Farbe.amber)
    }

    // MARK: - Die Leiste

    @ViewBuilder private var leiste: some View {
        let offen = offeneAenderungen
        if !offen.isEmpty {
            Uebernahmeleiste(
                offen: offen, uebersicht: $uebersicht, laeuft: laeuft,
                verwerfen: { entwurf = [:] }, uebernehmen: { uebernehmen(offen) })
        }
    }

    private var offeneAenderungen: [Reglerpult.Aenderung] {
        guard let e = einstellungen else { return [] }
        return Reglerpult.aenderungen(e.werte, entwurf: entwurf)
    }

    // MARK: - Werte lesen und schreiben

    private func setze(_ schluessel: String, _ wert: Double) {
        entwurf[schluessel] = wert
    }

    /// **Nacheinander, nicht zugleich: jede Einstellung ist ein eigener Befehl auf dem Bus**
    /// (`Regler.tsx:86-95`). Jede Antwort trägt den vollständigen Satz der Einstellungen; der
    /// letzte gilt. Jede Antwort wird einzeln als ✓ oder ✗ gezeigt.
    private func uebernehmen(_ offen: [Reglerpult.Aenderung]) {
        laeuft = true
        Task {
            var aus: [Meldung] = []
            var stand = einstellungen
            for a in offen {
                do {
                    let r = try await haus.api.stelleRegler(a.w.schluessel, wert: a.neu)
                    aus.append(Meldung(ok: r.ok, text: r.messageDe))
                    stand = r.einstellungen
                } catch let f as ApiFehler {
                    aus.append(Meldung(ok: false, text: f.rat))
                } catch {
                    aus.append(Meldung(ok: false, text: "\(a.w.nameDe): nicht gesendet."))
                }
            }
            einstellungen = stand
            entwurf = [:]
            meldungen = aus
            uebersicht = false
            laeuft = false
        }
    }

    /// Vermerken, dass eine Einstellung mit dem Bediengerät verglichen ist – oder das
    /// zurücknehmen.
    ///
    /// Das ist kein Griff an die Anlage, sondern ein Haken: „ich habe am Gerät nachgesehen, es
    /// steht wirklich so da“. Der Bus liest manche Werte nur mittelbar, und dieser Haken
    /// unterscheidet eine gelesene Zahl von einer bestätigten.
    private func vergleiche(_ w: ReglerEinstellungOut, _ bestaetigt: Bool) {
        Task {
            do {
                let a = try await haus.api.bestaetigeRegler(w.schluessel, bestaetigt: bestaetigt)
                einstellungen = a.einstellungen
                if !bestaetigt { entwurf[w.schluessel] = nil }
            } catch let f as ApiFehler {
                meldungen = [Meldung(ok: false, text: f.rat)]
            } catch {
                meldungen = [Meldung(ok: false, text: "Der Vermerk ließ sich nicht speichern.")]
            }
        }
    }

    /// **Alle sechzig Sekunden neu – und alle fünf, solange etwas auf seine Rückmeldung
    /// wartet** (`Regler.tsx:42-48`). Die App las bisher einmal; ein „gesendet“ blieb stehen,
    /// bis jemand die Seite neu betrat.
    private func beobachte() async {
        while !Task.isCancelled {
            await lade()
            let wartet = einstellungen.map { Reglerpult.wartet($0.werte) } ?? false
            try? await Task.sleep(for: .seconds(Reglerpult.takt(wartet: wartet)))
        }
    }

    private func lade() async {
        do {
            einstellungen = try await haus.api.reglerEinstellungen()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }

    /// Die gemessenen Stunden sind Beiwerk: fehlen sie, steht die Kurve ohne Punkte da
    /// (`Regler.tsx:51`).
    private func holeStunden() async {
        guard let b = try? await haus.api.betrieb(tage: 14) else { return }
        stunden = b.stunden.map {
            Reglerpult.Kurvenpunkt(aussen: $0.aussenC, vorlauf: $0.sollC)
        }
    }
}
