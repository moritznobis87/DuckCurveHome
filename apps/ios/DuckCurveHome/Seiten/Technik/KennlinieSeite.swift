import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Kennlinie: die gemessene Arbeitszahl über Außen- und Vorlauftemperatur.
///
/// **Das ist das Datenblatt dieser Maschine, aus eigenen Messungen.** Hersteller nennen die
/// Arbeitszahl bei A7/W35 und A-7/W35; was die Anlage in diesem Haus bei diesem Vorlauf
/// wirklich leistet, steht nirgends - außer hier.
///
/// **Die Reihenfolge ist die der Vorlage** (`apps/web/src/components/waermepumpe/Kennlinie.tsx`):
/// oben die Hauptaussage in einem Satz, dann der Rückblick, dann vier Kennzahlen, dann der
/// Ausgleich als Formel, dann drei Ansichten derselben Punkte, dann der Vergleich mit der
/// Kennlinie, mit der der Fahrplan heute rechnet, dann die Bilanz der Minuten und die Punkte
/// als Tabelle. Die App begann bis zum 20.11.2026 mit der Tagewahl und nannte die Kernzahl
/// „aus einer Kilowattstunde Strom X Kilowattstunden Wärme“ nirgends.
///
/// **Die Bilanz steht oben, solange es keine Punkte gibt** (`Kennlinie.tsx:155`, `:225`). Das
/// ist Absicht und keine Unordnung: ohne Punkte ist die Frage, *warum* keine zusammenkamen, die
/// Hauptaussage der Seite - und die beantwortet nur sie.
///
/// Gerechnet wird nichts hier. Jede Zahl, jeder Satz und jede Farbe kommt aus
/// ``Kennlinienbild`` und ist dort geprüft.
struct KennlinieSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    @State private var tage = 30
    @State private var kennlinie: KennlinieOut?
    @State private var fehler: ApiFehler?
    @State private var tabelleOffen = false

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            if let k = kennlinie {
                inhalt(k)
            } else if fehler == nil {
                // **Eine Zeile und keine Karte** (`Kennlinie.tsx:95-97`). Eine leere Karte mit
                // „Wird geholt …“ nimmt die Fläche, auf der gleich das Bild steht, und lässt
                // offen, ob da je etwas kommt. Der Satz und seine Farbe sind die von vorher;
                // dazugekommen ist Alfred darüber, in der großen Stufe, weil dieser Hinweis an
                // der Stelle der ganzen Seite steht (``Ladehinweis/Stufe``).
                Ladeente(satz: Kennlinienbild.ladesatz, stufe: .gross, farbe: Farbe.text3)
            } else {
                // Kein Warten, also keine Ente - die Regel an ``Ladeente``.
                Text(Kennlinienbild.fehlersatz)
                    .font(Schrift.text)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: tage) { await lade() }
    }

    // MARK: - Die Seite, wenn Zahlen da sind

    @ViewBuilder private func inhalt(_ k: KennlinieOut) -> some View {
        kopf(k)
        // `.kl-knopf` wie in der Vorlage dieser Seite (`Kennlinie.tsx:126`), und vier Stufen
        // statt drei: 180 Tage standen in der Vorlage und fehlten der App.
        Tagewahl(
            tage: $tage, moeglich: Kennlinienbild.rueckblicke, gruppe: "Rückblick",
            form: .klKnopf)
        // **Der Fehler steht in der Standzeile, die Karte bleibt** - und doch steht hier
        // zusätzlich ``Stoerung``. Die Vorlage hat keinen Knopf und lädt nur beim Wechsel des
        // Rückblicks neu (`Kennlinie.tsx:72-80`); auf einem Telefon mit wackligem Netz ist ein
        // Knopf die bessere Antwort als der Rat, den Zeitraum zu wechseln. Dieselbe Abweichung
        // trägt die Betriebsseite, und sie ist Absicht.
        if let fehler {
            Stoerung(fehler: fehler) { Task { await lade() } }
        }
        if let fehlt = k.fehltDe, !fehlt.isEmpty {
            Stummhinweis(satz: fehlt)
        }
        // `.kpi-handy`: die Werte sind Spannen, und die Vorlage gibt ihnen am Telefon eine
        // Stufe weniger (`handy.css:381-382`).
        Kachelfeld(
            kacheln: Kennlinienbild.kacheln(k).map(Kacheldaten.init), spannen: true)
        if k.punkte.isEmpty, let b = k.bilanz {
            Bilanzkarte(bilanz: b)
        }
        if let f = k.fit {
            formelkarte(f)
        }
        paar {
            Karte(kicker: Kennlinienbild.aussentitel) {
                Kennlinienstreubild(kennlinie: k)
            }
        } rechts: {
            Karte(kicker: Kennlinienbild.vorlauftitel) {
                Vorlaufstreubild(kennlinie: k)
            }
        }
        hubkarte(k)
        kennfeldkarte(k)
        vergleichskarte(k)
        if !k.punkte.isEmpty, let b = k.bilanz {
            Bilanzkarte(bilanz: b)
        }
        if !k.punkte.isEmpty {
            punkttabelle(k)
        }
        fuss(k)
    }

    // MARK: - Der Kopf

    @ViewBuilder private func kopf(_ k: KennlinieOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Kennlinienbild.kopfsatz(k))
                // 22 Punkte, am Telefon 19 (`globals.css:788`, `handy.css:234`).
                .font(schmal ? Schrift.satz : Schrift.sans(22, relativeTo: .title3))
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            Text(Kennlinienbild.standzeile(k, fehler: fehler?.rat))
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Die Formelkarte

    /// Der Ausgleich als eigene Karte (`Kennlinie.tsx:157-166`).
    ///
    /// **Die Formel ist nicht mehr der Kartentitel.** In der App stand `formelDe` als Titel in
    /// 15 Punkten; die Vorlage gibt ihr eine eigene Karte mit Kicker und eine Zeile in
    /// `clamp(15px, 1.7vw, 20px)` Festbreitenschrift. Die Formel ist die Antwort der Seite, und
    /// ein Kartentitel wird gelesen wie eine Überschrift - also überflogen.
    ///
    /// **Die Größe hängt an der Breitenklasse und nicht an der Breite in Punkten.** `clamp` mit
    /// `vw` hat in SwiftUI kein Gegenstück; das Projekt löst solche Fälle über
    /// `horizontalSizeClass` (``Karte``, mit Begründung dort). Am Telefon 15, am iPad 20 - also
    /// genau die beiden Enden der Klammer.
    private func formelkarte(_ f: KennlinienFitOut) -> some View {
        Karte(kicker: Kennlinienbild.formelkicker) {
            VStack(alignment: .leading, spacing: 8) {
                Text(f.formelDe)
                    .font(Schrift.mono(schmal ? 15 : 20, relativeTo: .body))
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Kennlinienbild.formelzeile(f))
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Der Hub

    /// Die Arbeitszahl über dem Hub, mit Formel, Geltung und Gütegrad darunter
    /// (`Kennlinie.tsx`, Karte „Arbeitszahl über dem Hub“).
    private func hubkarte(_ k: KennlinieOut) -> some View {
        Karte(kicker: Kennlinienbild.hubtitel) {
            VStack(alignment: .leading, spacing: 10) {
                kleinersatz(Kennlinienbild.hubsatz)
                Hubstreubild(kennlinie: k)
                if let h = k.hub {
                    Text(h.formelDe)
                        .font(Schrift.mono(schmal ? 15 : 20, relativeTo: .body))
                        .foregroundStyle(Farbe.text1)
                        .fixedSize(horizontal: false, vertical: true)
                    kleinersatz(Kennlinienbild.hubzeile(h))
                    if let guete = h.gueteDe, !guete.isEmpty {
                        kleinersatz(guete)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Das Kennfeld

    /// Das Kennfeld, oder der Satz, der sagt, wann es entsteht (`Kennlinie.tsx:186-196`).
    private func kennfeldkarte(_ k: KennlinieOut) -> some View {
        Karte(kicker: Kennlinienbild.kennfeldtitel) {
            VStack(alignment: .leading, spacing: 10) {
                if let feld = Kennlinienbild.kennfeld(k) {
                    Kennfeldbild(feld: feld)
                    kleinersatz(Kennlinienbild.kennfeldsatz)
                } else {
                    kleinersatz(Kennlinienbild.kennfeldLeersatz)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Messung gegen die Annahme des Fahrplans

    /// Der Vergleich als Tabelle (`Kennlinie.tsx:198-223`).
    ///
    /// **Die Karte ersetzt die alte „Angenommene Kurve“.** Die App zeigte eine einspaltige
    /// Tabelle mit nur den Annahmewerten - also die Hälfte, die man schon kennt. Die Aussage
    /// der Karte ist der Vergleich: was die Annahme sagt, was die Messung sagt, und ob an
    /// dieser Stelle überhaupt gemessen wurde.
    ///
    /// **Eine verlängerte Zeile steht leiser** (`globals.css:910`,
    /// `tr[data-gemessen="false"] td`). ``Tabelle/Spalte/farben`` kann das je Zelle; der
    /// Zeilenname bleibt in seiner Farbe, weil das Gerippe ihn allen Seiten gleich färbt - die
    /// Spalte „Stand“ sagt daneben in Worten, was gilt.
    @ViewBuilder private func vergleichskarte(_ k: KennlinieOut) -> some View {
        let zeilen = Kennlinienbild.vergleich(k)
        if !zeilen.isEmpty, let beiVorlauf = Kennlinienbild.vergleichsVorlauf(k) {
            Karte(kicker: Kennlinienbild.vergleichstitel) {
                VStack(alignment: .leading, spacing: 10) {
                    Tabelle(
                        zeilennamen: zeilen.map { Formate.celsius($0.aussenC) },
                        spalten: vergleichsspalten(k, zeilen, beiVorlauf: beiVorlauf))
                    kleinersatz(Kennlinienbild.vergleichsschluss)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func vergleichsspalten(
        _ k: KennlinieOut, _ zeilen: [Kennlinienbild.Vergleichszeile], beiVorlauf: Double
    ) -> [Tabelle.Spalte] {
        let farben: [Color?] = zeilen.map { $0.gemessen ? nil : Farbe.text3 }
        return [
            Tabelle.Spalte(
                name: Kennlinienbild.annahmespalte(k),
                zellen: zeilen.map { Formate.zahl($0.annahme, stellen: 1) }, farben: farben),
            Tabelle.Spalte(
                name: Kennlinienbild.messungsspalte(beiVorlauf),
                zellen: zeilen.map { Formate.zahl($0.messung, stellen: 1) }, farben: farben),
            Tabelle.Spalte(
                name: "Stand", zellen: zeilen.map(Kennlinienbild.standwort), farben: farben),
        ]
    }

    // MARK: - Die Messpunkte als Tabelle

    /// Die Rohpunkte, **zugeklappt**, mit ihrer Zahl im Griff (`Kennlinie.tsx:227-260`).
    ///
    /// **In der App waren die Punkte bisher nur als Streubild sichtbar, also nicht ablesbar.**
    /// Wer wissen will, was der eine Ausreißer war, braucht seine Zeile - und `ventil` erschien
    /// nirgends, obwohl gerade es die Warmwasserladungen von den Heizkreisen trennt.
    ///
    /// **Sie rollt seitlich und zerfällt nicht zur Liste.** Die Vorlage hält diese Tabelle
    /// ausdrücklich davon ab (`handy.css:246-247`: `.kl-liste` rollt, die Schrift wird
    /// kleiner), wie die Tagestabelle der Betriebsseite - bei sieben Spalten füllt die Reihe
    /// der Spaltennamen am Telefon zwei Zeilen, und jeder Blick auf eine andere Spalte wirft
    /// die vorige weg.
    private func punkttabelle(_ k: KennlinieOut) -> some View {
        Karte {
            DisclosureGroup(isExpanded: $tabelleOffen) {
                Tabelle(
                    zeilennamen: Kennlinienbild.tabellenzeilen(k),
                    spalten: Kennlinienbild.tabellenspalten(k).map {
                        Tabelle.Spalte(name: $0.name, zellen: $0.zellen)
                    },
                    handyfassung: .rollt
                )
                .padding(.top, 8)
            } label: {
                Text(Kennlinienbild.tabellengriff(k))
                    .font(Schrift.karte)
                    .foregroundStyle(Farbe.text1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(Farbe.text3)
        }
    }

    // MARK: - Der Fuß

    /// Die Hinweise **offen**, darunter zwei Verweise (`Kennlinie.tsx:262-272`).
    ///
    /// **Offen und nicht in einer Methodenkarte.** In der App standen sie in ``Methode``,
    /// zugeklappt und ohne Kurzzeile - damit verschwand alles, was die Zahlen dieser Seite
    /// einschränkt. Und es sind genau die Sätze, die sagen, dass die Punkte Abschätzungen aus
    /// Durchfluss und Spreizung sind: eine Arbeitszahl mit zwei Nachkommastellen ohne diesen
    /// Satz behauptet mehr, als gemessen wurde. `globals.css:795` gibt ihnen 13 Punkte und
    /// `--text-3` - leise, aber da.
    @ViewBuilder private func fuss(_ k: KennlinieOut) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(k.hinweiseDe.enumerated()), id: \.offset) { _, h in
                Text(h)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Umbruchzeile(abstand: 18, zeilenabstand: 6) {
                verweis("Die Wärmepumpe jetzt ›", nach: "/waerme/waermepumpe")
                verweis("Was die Wärme gekostet hat ›", nach: "/waerme/nachbetrachtung")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verweis(_ wort: String, nach weg: String) -> some View {
        Button(wort) { wegweiser.gehe(weg) }
            .font(Schrift.klein)
            .buttonStyle(.plain)
            .foregroundStyle(Farbe.amber)
    }

    // MARK: - Die kleinen Teile

    /// `.kl-klein`: 13 Punkte, `--text-3` (`globals.css:898`).
    private func kleinersatz(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Zwei Karten nebeneinander am breiten Schirm, untereinander am Telefon
    /// (`.kl-paar`, `globals.css:899`, `handy.css:235`).
    ///
    /// **Kein ``Spaltenreihe``.** Die nimmt ein festes Verhältnis wie `8fr 4fr`; hier sind es
    /// zwei gleiche Hälften (`repeat(2, minmax(0, 1fr))`), und dafür reicht ein `HStack` mit
    /// zwei dehnbaren Kindern - so macht es die Betriebsseite an derselben Stelle.
    @ViewBuilder private func paar<L: View, R: View>(
        @ViewBuilder links: () -> L, @ViewBuilder rechts: () -> R
    ) -> some View {
        if schmal {
            links()
            rechts()
        } else {
            HStack(alignment: .top, spacing: 16) {
                links().frame(maxWidth: .infinity)
                rechts().frame(maxWidth: .infinity)
            }
        }
    }

    private func lade() async {
        do {
            kennlinie = try await haus.api.kennlinie(tage: tage)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

// MARK: - Was dem Dienst für eine Kennlinie fehlt

/// Der Hinweiskasten in Bernstein (`.wp-stumm`, `globals.css:792`).
///
/// **Ein Kasten und keine Karte.** Die App zeigte `fehlt_de` in einer grauen Karte mit dem
/// eigenen Satz „Für eine Kennlinie fehlt etwas.“ - einem Satz, den die Vorlage nicht hat und
/// der nichts hinzufügt, weil das Dienstfeld schon in Worten sagt, was fehlt. Eine Karte sieht
/// außerdem aus wie Inhalt; dieser Kasten ist eine Einschränkung des Inhalts darunter, und
/// Bernstein ist in dieser Anwendung die Farbe dafür.
private struct Stummhinweis: View {
    let satz: String

    /// 12 Punkte Deckel, 14 an den Seiten, Radius 12, Rand `amber` zu 55 Prozent, Fläche
    /// `amber` zu 9 Prozent (`globals.css:792`).
    private let radius: CGFloat = 12

    var body: some View {
        Text(satz)
            .font(Schrift.sans(14))
            .foregroundStyle(Farbe.text1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Farbe.amber.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Farbe.amber.opacity(0.55), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Wo die Minuten geblieben sind

/// Die Bilanz der Minuten als Balken mit Legende (`Kennlinie.tsx:29-71`).
///
/// **Das ist die Karte, die eine Kennlinie glaubwürdig macht oder nicht.** Dreißig Tage klingen
/// nach viel; wenn davon vierzig Minuten brauchbar sind, ist die Kurve eine Vermutung mit
/// Nachkommastellen.
///
/// **Ein Balken und keine Zahlenliste.** Die App zeigte neun Zeilen mit Minutenzahlen - „43200,
/// 600, 60, 30 …“. Zwei Zahlen ins Verhältnis zu setzen ist Arbeit, und niemand macht sie beim
/// Überfliegen; ein Balken macht sie einmal und zeigt das Ergebnis. Die Namen stehen in der
/// Legende daneben, die Farbe allein sagt nichts.
///
/// **Die Begründungen gehören dazu** (`bilanz.ts:15-22`). „Anlauf: 60“ sagt nicht, warum diese
/// Minuten nicht zählen; „die ersten zehn Minuten nach jedem Start“ sagt es. Es sind die Sätze,
/// die aus einer Bilanz eine Auskunft machen - und sie stehen im Kern, weil sie zur Rechnung
/// gehören und nicht zur Darstellung.
private struct Bilanzkarte: View {
    let bilanz: KennlinienBilanzOut

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    /// Zwei Punkte Lücke, 22 Punkte hoch, Radius 4 (`globals.css:914-915`).
    private let hoehe: CGFloat = 22
    private let luecke: CGFloat = 2
    private let radius: CGFloat = 4
    /// Ein Teil ist nie dünner als vier Punkte, sonst verschwände er (`min-width: 4px`).
    private let schmalste: CGFloat = 4

    var body: some View {
        Karte(kicker: Kennlinienbild.bilanztitel) {
            VStack(alignment: .leading, spacing: 10) {
                let teile = Kennlinienbild.bilanzteile(bilanz)
                if teile.isEmpty {
                    if let satz = bilanz.satzDe, !satz.isEmpty {
                        satzzeile(satz)
                    }
                } else {
                    balken(teile)
                    legende(teile)
                }
                if let satz = Kennlinienbild.fehlendsatz(bilanz) {
                    satzzeile(satz)
                }
                if let satz = Kennlinienbild.punktesatz(bilanz) {
                    satzzeile(satz)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Der Balken

    private func balken(_ teile: [Kennlinienbild.Bilanzteil]) -> some View {
        GeometryReader { raum in
            HStack(spacing: luecke) {
                ForEach(teile) { t in
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color(Kennlinienbild.bilanzfarbe(t.art)))
                        .frame(width: teilbreite(t, teile: teile, voll: raum.size.width))
                }
            }
        }
        .frame(height: hoehe)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Kennlinienbild.bilanzbeschriftung(bilanz))
    }

    /// Die Breite eines Teils: sein Anteil an dem, was nach den Lücken übrig ist.
    private func teilbreite(
        _ t: Kennlinienbild.Bilanzteil, teile: [Kennlinienbild.Bilanzteil], voll: CGFloat
    ) -> CGFloat {
        let frei = max(0, voll - luecke * CGFloat(max(0, teile.count - 1)))
        return max(schmalste, frei * CGFloat(t.anteil))
    }

    // MARK: Die Legende

    private func legende(_ teile: [Kennlinienbild.Bilanzteil]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(teile) { t in
                if schmal {
                    handyzeile(t)
                } else {
                    volleZeile(t)
                }
            }
        }
    }

    /// Am iPad eine Zeile: Punkt, Name, Dauer, Anteil, Begründung
    /// (`globals.css:922`, Raster `12px 108px 96px 44px minmax(0,1fr)`).
    private func volleZeile(_ t: Kennlinienbild.Bilanzteil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            punkt(t)
            Text(t.name)
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text1)
                .lineLimit(1)
                .frame(width: 108, alignment: .leading)
            Text(Formate.dauer(minuten: t.minuten))
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text1)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
            Text(Kennlinienbild.bilanzanteil(t))
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text3)
                .lineLimit(1)
                .frame(width: 52, alignment: .trailing)
            Text(t.wozu)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Am Telefon rutscht die Begründung in eine eigene Zeile über die volle Breite
    /// (`handy.css:248-249`: Raster `12px minmax(0,1fr) max-content 40px`,
    /// `.kl-bilanz-wozu { grid-column: 2 / -1 }`).
    private func handyzeile(_ t: Kennlinienbild.Bilanzteil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                punkt(t)
                Text(t.name)
                    .font(Schrift.sans(14))
                    .foregroundStyle(Farbe.text1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Formate.dauer(minuten: t.minuten))
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text1)
                    .lineLimit(1)
                Text(Kennlinienbild.bilanzanteil(t))
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text3)
                    .lineLimit(1)
                    .frame(width: 48, alignment: .trailing)
            }
            Text(t.wozu)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 22)
        }
    }

    /// Der Punkt der Legende: zehn Punkte, Radius 3 (`globals.css:924`).
    private func punkt(_ t: Kennlinienbild.Bilanzteil) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(Kennlinienbild.bilanzfarbe(t.art)))
            .frame(width: 10, height: 10)
    }

    private func satzzeile(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
