import DuckCurveKit
import SwiftUI

/// Rechnungen: die Tibber-Rechnungen, nachgerechnet und gegen die eigene Messung gehalten.
///
/// Vorlage ist `apps/web/src/components/reports/InvoiceCheck.tsx` mit den vier Diagrammen in
/// `apps/web/src/components/reports/charts.ts:279-367`.
///
/// **Was diese Seite wirklich tut.** Sie vergleicht, was der Versorger abgerechnet hat, mit dem,
/// was das Haus selbst gemessen hat - Kilowattstunden, Zeitraum, mittlerer Preis. Eine Rechnung,
/// deren Zeitraum nicht zu den eigenen Minutenwerten passt, ist nicht automatisch falsch; aber
/// sie ist eine Frage wert, und ohne diese Seite stellt sie niemand.
///
/// **Die App konnte bis hierher keine Rechnung einlesen.** `Api.pruefeRechnung` lag unbenutzt
/// da, und der Leerzustand schickte den Benutzer in `docs/RECHNUNGSPRUEFUNG.md`. Jetzt steht
/// oben links das Ablegefeld der Vorlage (``Rechnungsablage``), und rechts daneben stehen die
/// vier Kennzahlen über **alle** Rechnungen - die es ebenfalls nicht gab, obwohl sie die Frage
/// beantworten, mit der jemand auf diese Seite kommt.
///
/// **Was gerechnet wird, steht im Kern** (``Rechnungspruefung``): Reihenfolge, Achsenkürzel,
/// mengengewichteter Mittelpreis, Mehrwertsteuerrundung, die Teilung der Befunde, die
/// 98-%-Schwelle der Abdeckung, die 0,005-Schwelle des Deltas und jeder Wortlaut. Hier bleibt
/// die Anordnung.
///
/// **Keine Zeitraumleiste**, weil die Vorlage hier `AreaShell` benutzt und nicht `ReportShell`
/// (`InvoiceCheck.tsx:205`): eine Rechnung bringt ihren Zeitraum mit.
///
/// **Den Kicker zeichnet ``Seite``.** Er stand hier als erste Zeile der Seite, mit einer eigenen
/// Fassung fürs Telefon: dort lesbare Schrift statt Sperrschrift, mit `handy.css:184` als Beleg.
/// Der Beleg trug nicht - `handy.css:184` ist `.card-head h2.kicker`, also der Kicker **einer
/// Karte**; der Kicker der Hülle trägt `hidden … md:block` (`AreaNav.tsx:96`) und fällt am
/// Telefon weg. Jetzt steht die Regel einmal im Gerippe, das Wort bleibt
/// ``Rechnungspruefung/seitenkicker``.
///
/// Nur für den Hausherrn: hier stehen Name, Adresse, Marktlokations-ID, Zählernummer
/// (`Bereiche.swift:167`, `nurHausherr: true`).
struct RechnungenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var liste: [InvoiceSummaryOut] = []
    @State private var gewaehlt: String?
    @State private var bericht: InvoiceReportOut?
    @State private var fehler: ApiFehler?
    @State private var dateifehler: String?
    @State private var laedt = false
    @State private var geladen = false
    /// Läuft gerade eine Prüfung in ``Rechnungsablage``? Der Zustand steht hier und nicht dort,
    /// weil der Leerzustand ihn braucht - der Grund steht dort im ``body``.
    @State private var pruefeLaeuft = false

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await ladeListe() } }
            }
            // Die Fehlschläge einzelner Dateien im **selben** Band wie ein Fehler des Dienstes
            // darüber: die Vorlage hat für beides eines (`InvoiceCheck.tsx:207`). Ohne Code,
            // denn eine gescheiterte Datei hat keinen, und ohne „Erneut“ - einen Versuch
            // wiederholt man, indem man die Datei neu ablegt.
            if let dateifehler {
                Stoerung(satz: dateifehler)
            }
            kopfzeile
            if liste.isEmpty {
                // **Während des ersten Ladens steht hier nichts** - wie in der Vorlage, die
                // `loaded` erst nach der Antwort setzt (`InvoiceCheck.tsx:111`). Ein
                // Leerzustand, der eine halbe Sekunde aufblitzt, sieht aus wie ein Fehler.
                //
                // **Und während des Prüfens auch nicht:** die Vorlage verlangt `loaded && !busy`
                // (`InvoiceCheck.tsx:331`), und `busy` ist dort der Hochlade-Zustand (`:99`).
                // Auf dem häufigsten ersten Weg - leere Seite, erstes PDF ablegen - stünde
                // sonst „Noch keine Rechnung geprüft“ unter einem Feld, das „Rechnung wird
                // geprüft …“ sagt. `laedt` allein genügt nicht: das ist nur die Liste.
                if geladen, !laedt, !pruefeLaeuft {
                    Karte { Leer(satz: Rechnungspruefung.leerSatz) }
                }
            } else {
                diagramme
                tabelle
                if let bericht {
                    befunde(bericht)
                    methode(bericht)
                }
            }
        }
        .task { await ladeListe() }
        .task(id: gewaehlt) { await ladeBericht() }
    }

    // MARK: - Zeile 1: Ablegefeld und die vier Kennzahlen

    /// `--cols: "5fr 7fr"` am Schirm (`InvoiceCheck.tsx:209`), am Telefon untereinander
    /// (`handy.css:209`).
    ///
    /// **Diese Zeile steht immer da, auch ohne eine einzige Rechnung** - wie in der Vorlage, die
    /// erst alles *danach* an `items.length > 0` hängt (`InvoiceCheck.tsx:227`). Sonst gäbe es
    /// keinen Weg, die erste Rechnung einzulesen.
    @ViewBuilder private var kopfzeile: some View {
        if schmal {
            ablage
            kacheln
        } else {
            Spaltenreihe(anteile: [5, 7], abstand: 14) {
                ablage
                kacheln
            }
        }
    }

    private var ablage: some View {
        Rechnungsablage(anzahl: liste.count, laeuft: $pruefeLaeuft) { neuer, zeile in
            nachPruefung(neuer, zeile)
        }
    }

    private var kacheln: some View {
        Kachelfeld(
            kacheln: Rechnungspruefung.kopfkennzahlen(liste).map(kachel),
            ersteFuehrt: true, art: .bericht)
    }

    /// Eine Kopfzahl des Kerns als Kachel. Die Farbe kommt aus der Rolle, nicht aus der Zahl.
    private func kachel(_ k: Rechnungspruefung.Kopfzahl) -> Kacheldaten {
        Kacheldaten(
            k.wort, k.wert, einheit: k.einheit, dazu: k.dazu, farbe: Rechnungsfarbe.zu(k.ton))
    }

    // MARK: - Die vier Diagramme

    /// Zwei Zeilen: `1fr 1fr` und `5fr 7fr` (`InvoiceCheck.tsx:229`, `:239`).
    @ViewBuilder private var diagramme: some View {
        if schmal {
            mengenkarte
            betragskarte
            preiskarte
            positionskarte
        } else {
            Spaltenreihe(anteile: [1, 1], abstand: 14) {
                mengenkarte
                betragskarte
            }
            Spaltenreihe(anteile: [5, 7], abstand: 14) {
                preiskarte
                positionskarte
            }
        }
    }

    private var mengenkarte: some View {
        let paare = Rechnungspruefung.mengenpaare(liste)
        return Karte(
            kicker: Rechnungspruefung.mengentitel,
            beiwerk: AnyView(kopftext(Rechnungspruefung.mengenkopf))
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Diagrammlegende(
                    stuecke: Rechnungsfarbe.legende(Rechnungspruefung.mengenreihen))
                Mengenvergleichsbild(paare: paare)
            }
        }
    }

    /// „Arbeitspreis · Grundgebühr · Steuer“ ist in der Vorlage der rechte Kopftext
    /// (`InvoiceCheck.tsx:235`). Hier trägt die Legende dieselbe Aufzählung **mit** ihren
    /// Farben; den Text daneben noch einmal zu schreiben wäre dieselbe Auskunft zweimal, und
    /// darum bleibt die Kopfzeile dieser einen Karte ohne Beiwerk.
    ///
    /// **Die Legende steht unter dem Kopf und nicht in ihm**, bei allen drei Verlaufskarten.
    /// ``Diagrammlegende`` nimmt die ganze Breite und richtet sich nach rechts; als `beiwerk`
    /// einer ``Karte`` drückte sie den Kicker zusammen - sie ist ausdrücklich für den Platz
    /// darunter gemacht (`Diagramme/Pvverwendung.swift:160-169`).
    private var betragskarte: some View {
        let reihen = Rechnungspruefung.betragsreihen(liste)
        return Karte(kicker: Rechnungspruefung.betragstitel) {
            VStack(alignment: .leading, spacing: 8) {
                Diagrammlegende(stuecke: Rechnungsfarbe.legende(reihen))
                Rechnungsbetragsbild(reihen: reihen)
            }
        }
    }

    private var preiskarte: some View {
        let punkte = Rechnungspruefung.preisreihe(liste)
        return Karte(
            kicker: Rechnungspruefung.preistitel,
            beiwerk: AnyView(kopftext(Rechnungspruefung.preiskopf))
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Preislegende()
                Durchschnittspreisbild(punkte: punkte)
            }
        }
    }

    /// Die Preisbestandteile der **gewählten** Rechnung; ohne Auswahl der Satz der Vorlage.
    private var positionskarte: some View {
        let balken = Rechnungspruefung.positionsbalken(bericht?.invoice.positions ?? [])
        return Karte(
            kicker: Rechnungspruefung.positionstitel,
            beiwerk: AnyView(
                kopftext(bericht?.invoice.periodLabel ?? Rechnungspruefung.positionskopfLeer))
        ) {
            if balken.isEmpty {
                Leer(satz: Rechnungspruefung.positionsleer)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Positionsleiste(balken: balken)
                    Divider().overlay(Farbe.linie1)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("ct/kWh").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        Spacer(minLength: 8)
                        Positionslegende(balken: balken)
                    }
                }
            }
        }
    }

    /// Der rechte Kopftext einer Karte - 12 px `--text-3` in der Vorlage (`Card.tsx:24-26`).
    private func kopftext(_ wort: String) -> some View {
        Text(wort)
            .font(schmal ? Schrift.klein : Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .multilineTextAlignment(.trailing)
    }

    // MARK: - Die Tabelle „Geprüfte Rechnungen“

    /// Acht Spalten (`InvoiceCheck.tsx:254-302`), von denen die erste der Zeilenname ist.
    ///
    /// **Die Zeile ist der Griff**, mit dem die Befunde und die Preisbestandteile darunter
    /// umgeschaltet werden (`InvoiceCheck.tsx:277-279`). **Ein zweites Tippen wählt nicht ab**
    /// (`InvoiceCheck.tsx:117-125`): die App ließ das zu, und damit konnte die untere Hälfte
    /// der Seite mit einem Fehltipper verschwinden.
    ///
    /// Beides kann seit dem 20.11.2026 das Tabellengerippe selbst (``Tabelle/auswahl``); hier
    /// stand dafür eine zweite, fast gleiche Tabelle. `engeZellen`, weil diese Tabelle in der
    /// Vorlage die kleinere der beiden Tabellenschriften trägt (`InvoiceCheck.tsx:257`) - acht
    /// Spalten in einer Karte haben sonst zweizeilige Zellen.
    private var tabelle: some View {
        let zeilen = Rechnungspruefung.tabellenzeilen(liste)
        return Karte(
            kicker: Rechnungspruefung.tabellentitel,
            beiwerk: AnyView(kopftext(Rechnungspruefung.tabellenkopf))
        ) {
            Tabelle(
                zeilennamen: zeilen.map(\.zeitraum), spalten: spalten(zeilen),
                engeZellen: true,
                gewaehlteZeile: zeilen.firstIndex { $0.nummer == gewaehlt }
            ) { stelle in
                gewaehlt = zeilen[stelle].nummer
            }
        }
    }

    private func spalten(_ zeilen: [Rechnungspruefung.Tabellenzeile]) -> [Tabelle.Spalte] {
        let namen = Rechnungspruefung.tabellenspalten
        let leise = [Color?](repeating: Farbe.text3, count: zeilen.count)
        return [
            .init(name: namen[1], zellen: zeilen.map(\.nummer), farben: leise),
            .init(name: namen[2], zellen: zeilen.map(\.menge)),
            .init(name: namen[3], zellen: zeilen.map(\.messung), farben: leise),
            .init(name: namen[4], zellen: zeilen.map(\.preis)),
            .init(name: namen[5], zellen: zeilen.map(\.netto), farben: leise),
            .init(name: namen[6], zellen: zeilen.map(\.brutto)),
            .init(
                name: namen[7], zellen: zeilen.map(\.ergebnis.text),
                // Der Rückgabetyp steht angeschrieben: `farben` ist `[Color?]`, und eine
                // Reihe aus `Color` dorthin zu geben hängt sonst an einer stillen Umwandlung.
                farben: zeilen.map { (z) -> Color? in Rechnungsfarbe.zu(z.ergebnis.ton) }),
        ]
    }

    // MARK: - Die Befunde, in zwei Karten

    /// `--cols: "7fr 5fr"` (`InvoiceCheck.tsx:305`): links was nachgerechnet wurde, rechts was
    /// gegen die eigenen Daten gehalten wurde.
    ///
    /// **Die App hatte eine Karte „Was aufgefallen ist“ für beides.** Ohne die Teilung steht
    /// nicht da, was ein Rechenfehler des Versorgers ist und was eine Lücke in der eigenen
    /// Messung - und das ist auf dieser Seite der Unterschied, auf den alles hinausläuft.
    @ViewBuilder private func befunde(_ b: InvoiceReportOut) -> some View {
        if schmal {
            rechenkarte(b)
            abgleichkarte(b)
        } else {
            Spaltenreihe(anteile: [7, 5], abstand: 14) {
                rechenkarte(b)
                abgleichkarte(b)
            }
        }
    }

    private func rechenkarte(_ b: InvoiceReportOut) -> some View {
        let gerechnet = Rechnungspruefung.gerechnet(b.findings)
        return Karte(
            kicker: Rechnungspruefung.gerechnetTitel(b.invoice.periodLabel),
            beiwerk: AnyView(kopftext(Rechnungspruefung.stimmig(gerechnet)))
        ) {
            befundliste(gerechnet, leer: Rechnungspruefung.gerechnetLeer)
        }
    }

    private func abgleichkarte(_ b: InvoiceReportOut) -> some View {
        let verglichen = Rechnungspruefung.verglichen(b.findings)
        return Karte(
            kicker: Rechnungspruefung.verglichenTitel,
            beiwerk: AnyView(kopftext(b.invoice.number))
        ) {
            VStack(alignment: .leading, spacing: 10) {
                befundliste(verglichen, leer: Rechnungspruefung.verglichenLeer)
                Divider().overlay(Farbe.linie1)
                // Der Zählerstand: die einzige Zahl der Seite, die jemand am Zähler im Keller
                // nachsehen kann (`InvoiceCheck.tsx:322-326`).
                Text(Rechnungspruefung.zaehlerzeile(b.invoice))
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// **Haarlinien zwischen den Befunden statt zwölf Punkten Abstand** (`border-t` und `py-2`,
    /// `InvoiceCheck.tsx:36`). Bei sieben Befunden mit je zwei Zeilen Text ist der Abstand
    /// allein keine Trennung mehr: man liest nicht, wo einer aufhört.
    @ViewBuilder private func befundliste(_ befunde: [InvoiceFinding], leer: String) -> some View {
        if befunde.isEmpty {
            Leer(satz: leer)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(befunde.enumerated()), id: \.offset) { i, f in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    befundzeile(f).padding(.vertical, 8)
                }
            }
        }
    }

    private func befundzeile(_ f: InvoiceFinding) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Acht Punkte, wie `h-2 w-2` (`InvoiceCheck.tsx:27`) - in der App waren es sechs,
            // und daneben verschwindet er neben dem 13-Punkt-Titel.
            Circle()
                .fill(Rechnungsfarbe.zu(Rechnungspruefung.befundton(f.severity)))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                befundkopf(f)
                if !f.detailDe.isEmpty {
                    Text(f.detailDe)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Titel und Zahlen. **Am Schirm auf einer Zeile, am Telefon untereinander:** „31,20
    /// erwartet · 31,45 ct/kWh · +0,25“ neben einem Titel braucht Breite, die 390 Punkte nicht
    /// haben, und abgeschnitten wäre die Zahl weg, auf die es ankommt.
    @ViewBuilder private func befundkopf(_ f: InvoiceFinding) -> some View {
        let zahlen = Rechnungspruefung.befundzahlen(f)
        if schmal {
            VStack(alignment: .leading, spacing: 2) {
                Text(f.titleDe).font(Schrift.klein).foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                if let zahlen {
                    befundzahlen(zahlen, schwere: f.severity)
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(f.titleDe).font(Schrift.klein).foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let zahlen {
                    befundzahlen(zahlen, schwere: f.severity)
                }
            }
        }
    }

    private func befundzahlen(_ text: String, schwere: InvoiceFindingSeverityWahl) -> some View {
        Text(text)
            .font(Schrift.zahlKlein)
            .foregroundStyle(
                Rechnungsfarbe.zu(Rechnungspruefung.befundzahlenton(schwere)))
            .lineLimit(1)
    }

    // MARK: - Die Methode

    /// **Was die App zusätzlich weiß, und die Vorlage nicht zeigt.** Der Methodenblock trug
    /// einmal auch den Satz, wogegen verglichen wird - der steht jetzt als Hinweis in der
    /// Prüfkarte, wo die Vorlage ihn hat (`InvoiceCheck.tsx:213-217`). Übrig bleiben die beiden
    /// Angaben, die nur der Dienst der App liefert: wann geprüft wurde, und ob die Rechnung
    /// schon einmal dagewesen ist.
    private func methode(_ b: InvoiceReportOut) -> some View {
        Methode([
            "Geprüft am \(b.checkedAt).",
            b.alreadyKnown == true ? "Diese Rechnung war schon eingelesen." : nil,
        ])
    }

    // MARK: - Laden

    private func ladeListe() async {
        laedt = true
        do {
            liste = try await haus.api.rechnungen()
            fehler = nil
        } catch {
            fehler = fehlerAus(error, satz: Rechnungspruefung.listenfehler)
        }
        laedt = false
        geladen = true
        // **Beim Öffnen die neueste Rechnung zeigen** - der Grund steht in der Vorlage und gilt
        // hier genauso: „damit Befunde und Preisbestandteile nicht leer bleiben“
        // (`InvoiceCheck.tsx:127-129`). Alfred verlinkt im Browser über `?nr=` auf eine gerade
        // geprüfte Rechnung; der ``Wegweiser`` der App trägt keine Frageliste, darum kommt eine
        // gewünschte Nummer hier nur aus dem Ablegefeld.
        if gewaehlt == nil {
            gewaehlt = Rechnungspruefung.erstauswahl(liste)
        }
    }

    /// **Hier wurde ein Fehler verschluckt:** `bericht = try? await …`. Fiel der Bericht aus,
    /// blieb die untere Hälfte der Seite ohne Begründung leer - und das sah aus wie eine
    /// Rechnung ohne Befunde. Die Vorlage schreibt stattdessen in ihr Fehlerband
    /// (`InvoiceCheck.tsx:123`).
    private func ladeBericht() async {
        guard let nummer = gewaehlt else {
            bericht = nil
            return
        }
        do {
            bericht = try await haus.api.rechnung(nummer)
            fehler = nil
        } catch {
            fehler = fehlerAus(error, satz: Rechnungspruefung.berichtfehler)
        }
    }

    /// Ein Fehler des Dienstes bleibt, wie er ist - seine Meldung ist deutsch und für Menschen
    /// gemacht (``ApiFehler/rat``). Nur was **kein** ``ApiFehler`` ist, bekommt den Satz der
    /// Vorlage: `localizedDescription` wäre an dieser Stelle englisch und technisch.
    private func fehlerAus(_ error: any Error, satz: String) -> ApiFehler {
        if let f = error as? ApiFehler { return f }
        return ApiFehler(code: "antwort_unlesbar", meldung: satz, status: 500)
    }

    /// Nach dem Prüfen: den letzten Bericht zeigen, die Fehlschläge melden, die Liste neu holen
    /// (`InvoiceCheck.tsx:137-159`).
    private func nachPruefung(_ neuer: InvoiceReportOut?, _ zeile: String?) {
        dateifehler = zeile
        if let neuer {
            bericht = neuer
            gewaehlt = neuer.invoice.number
        }
        // `laedt` schon hier und nicht erst in ``ladeListe``: zwischen dem Ende der Prüfung und
        // dem Anlaufen der Aufgabe liegt sonst ein Durchgang, in dem die Liste noch leer und
        // kein Zustand gesetzt ist - und genau dort blitzte der Leerzustand auf. Die Vorlage
        // wartet dafür die neue Liste ab, ehe sie `busy` löscht (`InvoiceCheck.tsx:155-156`).
        laedt = true
        Task { await ladeListe() }
    }
}
