import DuckCurveKit
import SwiftUI

/// Die Seite „Zugang und Sicherung“: wie man hereinkommt, wie dieses Gerät hereingekommen ist,
/// was die Datenbank wiegt, und wie man eine Kopie davon aus dem Haus bekommt.
///
/// **Die Vorlage** ist `apps/web/src/app/system/zugang/page.tsx`. Sie setzt ihre Abschnitte als
/// `<section>` mit `<h2>` ohne Kasten; in der App steht jeder in einer ``Karte``, und wo die
/// Vorlage zwei Abschnitte zusammenrückt, stehen hier „Sichtbarkeit“ und „Konfiguration“ in
/// einer.
///
/// **Was der App gegenüber der Vorlage noch fehlt** (`docs/GLEICHSTAND.md`): die Liste der
/// Personen mit dem Einladen, die eigenen Passkeys und die eigenen Sitzungen. „Gerade
/// verbunden“ liest im Dashboard eine `Map` im Arbeitsspeicher von Next; im Dienst des Hauses
/// gibt es dafür keinen Endpunkt, und eine erfundene Liste von Zuschauern wäre schlimmer als
/// keine.
///
/// **Was seit dem 24.11.2026 da ist:** der Abschnitt „Wie man hereinkommt“ im Wortlaut des
/// Dashboards und der Verweis auf „Mein Zugang“ (``KontoSeite``), die Seite für den eigenen
/// Zugang, die jede angemeldete Person erreicht. Bis dahin beschrieb die Seite Kopplungslinks und Gast-Token, die es
/// seit dem 23.11.2026 nicht mehr gibt.
struct ZugangSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite
    /// Das Mittel, mit dem iOS eine Adresse an den Browser gibt - siehe ``exportknopf(_:jahr:)``.
    @Environment(\.openURL) private var oeffne

    @State private var neuEinrichten = false
    @State private var bestand: StorageReportOut?
    @State private var bestandFehler = false

    private var schmal: Bool { breite == .compact }

    /// Die 13 Punkte der Vorlage sind am Telefon 14,5 (`handy.css:189-192`: kleine Schrift eine
    /// Stufe größer, mit der Begründung an `handy.css:187-188` - „am Handy aus dreißig, aber im
    /// Gehen“). Das trifft auf dieser Route die Noten der Rollen, die Jahresgröße und die
    /// Fachwörter in Festbreitenschrift.
    private var notenstufe: CGFloat { schmal ? 14.5 : 13 }

    var body: some View {
        Seite {
            hereinkommen
            diesesGeraet
            meinZugang
            platzbedarf
            sicherung
            sichtbarkeitUndKonfiguration
            verbindung
            aendern
            Methode(Zugangsworte.methode.map(Optional.init))
        }
        .sheet(isPresented: $neuEinrichten) {
            Einrichten()
        }
        .task { await ladeBestand() }
    }

    // MARK: - 1. Wie man hereinkommt

    /// Der Abschnitt „Wie man hereinkommt“ der Vorlage, im Wortlaut des Dashboards
    /// (``Zugangsworte/hereinkommen``).
    private var hereinkommen: some View {
        Karte(kicker: Zugangsworte.ueberschriften[0]) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Zugangsworte.hereinkommen, id: \.self) { absatz($0) }
            }
        }
    }

    // MARK: - Mein Zugang, der Verweis

    /// Der Absatz der Vorlage (`page.tsx`, „Mein Zugang“): Der eigene Zugang steht auf einer
    /// eigenen Seite, die jede angemeldete Person erreicht. Hier bleibt der Weg dorthin.
    private var meinZugang: some View {
        Karte(kicker: Zugangsworte.meinZugangUeberschrift) {
            VStack(alignment: .leading, spacing: 12) {
                absatz(Zugangsworte.meinZugang)
                if haus.zugang.istPerson {
                    Button {
                        wegweiser.merkeReiter()
                        wegweiser.gehe(Bereiche.kontoweg)
                    } label: {
                        Text(Zugangsworte.meinZugangUeberschrift)
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.amber)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 2. Dieses Gerät

    /// Wie dieses Gerät hereingekommen ist: als Person oder mit dem API-Token.
    ///
    /// Die Karte hat im Dashboard kein Gegenstück, weil ein Browser weder eine Adresse des
    /// Hauses noch einen Schlüsselbund hat. Sie ist das, was die App zusätzlich wissen muss.
    private var diesesGeraet: some View {
        Karte(kicker: "Dieses Gerät") {
            VStack(spacing: 0) {
                if haus.zugang.istPerson {
                    Zeile(wort: "Angemeldet als", wert: haus.zugang.email)
                    Zeile(
                        wort: "In dieser App",
                        wert: haus.zugang.rolle == .hausherr ? "Vollzugriff" : "nur Ansicht",
                        farbe: haus.zugang.rolle == .hausherr ? Farbe.text1 : Farbe.achtung
                    )
                } else {
                    Zeile(
                        wort: "Zugang",
                        wert: haus.zugang.rolle == .hausherr ? "Gerät mit API-Token" : "Gerät mit API-Token, als Gast",
                        farbe: haus.zugang.rolle == .hausherr ? Farbe.text1 : Farbe.achtung
                    )
                }
                Zeile(wort: "Name im Protokoll", wert: haus.zugang.geraetename)
                Zeile(wort: "Kennung", wert: haus.zugang.geraetekennung)
                Zeile(wort: "Adresse", wert: haus.zugang.grund.absoluteString)
                Zeile(wort: "Pfad", wert: haus.zugang.praefix)
                Zeile(
                    wort: haus.zugang.istPerson ? "Sitzung" : "Token",
                    wert: haus.zugang.token.isEmpty
                        ? "keines (Demo)"
                        : "im Schlüsselbund · \(haus.zugang.token.count) Zeichen"
                )
            }
        }
    }

    // MARK: - 3. Platzbedarf

    /// Womit die Datenbank ihren Platz füllt (`page.tsx:116-124`, `StorageReport.tsx:30-83`).
    ///
    /// **Der Abschnitt stand in der App schon, nur auf der falschen Seite** - als Karte
    /// „Datenbestand“ am Fuß der Datenprüfung, wo der Kommentar selbst festhielt, dass es ihn in
    /// der Vorlage dort nicht gibt. Hier ist er, mit dem Filter, der Obergrenze, der
    /// Schlusszeile und den drei Zuständen, die dort alle fehlten; gerechnet wird das in
    /// ``Datenbestand``.
    private var platzbedarf: some View {
        Karte(kicker: Zugangsworte.ueberschriften[2]) {
            VStack(alignment: .leading, spacing: 12) {
                absatz(Zugangsworte.platzbedarf)
                platzbedarfstand
            }
        }
    }

    @ViewBuilder private var platzbedarfstand: some View {
        switch Datenbestand.stand(bestand, fehlgeschlagen: bestandFehler) {
        case .fehler(let satz):
            Stoerung(satz: satz) { Task { await ladeBestand() } }
        case .laedt:
            // Die kleine Stufe: der Hinweis steht unter dem Absatz, der die Karte erklärt, und
            // ersetzt nicht die Karte (``Ladehinweis/Stufe``).
            Ladeente(satz: Datenbestand.ladewort)
        case .leer(let note):
            hinweis(note)
        case .tabelle(let posten):
            platzbedarfstabelle(posten)
        }
    }

    @ViewBuilder private func platzbedarfstabelle(_ posten: [Datenbestand.Posten]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !posten.isEmpty {
                // **Eine Spalte mit Umschaltung, nicht fünf nebeneinander.** Die Vorlage rollt
                // die Tabelle seitwärts (`StorageReport.tsx:48`); `handy.css:1-27`,
                // Entscheidung 4, verbietet das für die App („gezeigt wird eine Spalte, die man
                // umschaltet“). Die Ausnahme der Raumtabelle (`Bericht.swift:175-183`) gilt hier
                // nicht: `gesamt = Daten + Indizes` wäre ein Argument für drei Spalten, aber die
                // Zeilenzahl gehört nicht dazu.
                Tabelle(zeilennamen: posten.map(\.name), spalten: spalten(posten), immerSichtbar: 1)
            }
            // Die Schlusszeile der Vorlage (`StorageReport.tsx:71-77`) - sie stand in der App
            // als Titel der Karte und damit neben dem Namen des Abschnitts statt unter den
            // Einzelsummen, wo sie etwas aussagt.
            Divider().overlay(Farbe.linie2)
            Zeile(wort: Datenbestand.summenwort, wert: gesamtwert)
            Zeile(
                wort: "Rohwerte bleiben", wert: aufbewahrungswert, einheit: "Tage",
                dazu: "danach nur noch Minutenmittel"
            )
            if let note = bestand?.noteDe, !note.isEmpty {
                hinweis(note)
            }
        }
    }

    private var gesamtwert: String {
        guard let bestand else { return Formate.leer }
        return Datenbestand.gesamt(bestand)
    }

    private var aufbewahrungswert: String {
        guard let bestand else { return Formate.leer }
        return Datenbestand.aufbewahrung(bestand)
    }

    /// Die vier Spalten, „gesamt“ in ``Farbe/amber`` wie in der Vorlage
    /// (`StorageReport.tsx:68`: `text-amber`).
    ///
    /// ``Tabelle/Spalte/farben`` erlaubt das ausdrücklich; die Farbe ist hier keine Zierde,
    /// sondern sagt, welche der vier Zahlen die ist, nach der abgerechnet wird.
    private func spalten(_ posten: [Datenbestand.Posten]) -> [Tabelle.Spalte] {
        let letzte = Datenbestand.spalten.count - 1
        return Datenbestand.spalten.enumerated().map { i, name in
            Tabelle.Spalte(
                name: name,
                zellen: posten.map { $0.zellen[i] },
                farben: i == letzte ? posten.map { _ in Farbe.amber } : []
            )
        }
    }

    // MARK: - 4. Sicherung

    /// Die Jahresdateien (`page.tsx:126-156`) - der Abschnitt fehlte ganz.
    private var sicherung: some View {
        Karte(kicker: Zugangsworte.ueberschriften[3]) {
            VStack(alignment: .leading, spacing: 12) {
                absatz(Zugangsworte.sicherung)
                hinweis(Zugangsworte.herunterladen)
                VStack(spacing: 0) {
                    ForEach(Zugangsworte.sicherungsjahre(jetzt: haus.jetzt), id: \.self) { jahr in
                        sicherungsjahr(jahr)
                    }
                }
                hinweis(Zugangsworte.sicherungsschluss)
            }
        }
    }

    private func sicherungsjahr(_ jahr: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(String(jahr)).font(Schrift.zahl).foregroundStyle(Farbe.text1)
                exportknopf(.minuten, jahr: jahr)
                exportknopf(.stunden, jahr: jahr)
                Spacer(minLength: 0)
            }
            Text(Zugangsworte.jahresgroesse)
                .font(Schrift.sans(notenstufe, relativeTo: .footnote))
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 7)
    }

    /// Ein Verweis, der eine Datei holt - das erste Mal, dass diese App das Gerät verlässt.
    ///
    /// **Warum `openURL` und nicht `ShareLink`.** Die Vorlage ist ein `<a href>`, und was dort
    /// die Datei ablegt, ist der Browser. Das Gegenstück dazu ist, die Adresse an den Browser
    /// des Geräts zu geben; `ShareLink(item: url)` täte dasselbe mit einem Blatt dazwischen, auf
    /// dem man erst noch ein Ziel wählt - und das Ziel ist hier nie die Frage. Der dritte Weg
    /// wäre, die Datei selbst zu holen und als `ShareLink(item: datei)` anzubieten: nur so
    /// reiste die `Authorization`-Kopfzeile mit (``Zugang/kopfzeilen``), aber dafür bräuchte es
    /// einen Zwischenspeicher und eine Fortschrittsanzeige für zwanzig Megabyte, und
    /// ``Api`` hat für Antworten, die keine JSON sind, bisher nichts (gesucht nach „export“:
    /// kein Treffer). Dieser Vorbehalt ist deshalb nicht verschwiegen, sondern steht sichtbar
    /// über den Zeilen (``Zugangsworte/herunterladen``).
    ///
    /// **Ohne Adresse kein Verweis.** ``Zugang/export(art:jahr:)`` gibt `nil`, wenn das Jahr
    /// keines ist, das der Dienst annimmt - dann steht hier nichts, statt ins Leere zu führen.
    @ViewBuilder private func exportknopf(_ art: Zugang.Exportart, jahr: Int) -> some View {
        if let adresse = haus.zugang.export(art: art, jahr: jahr) {
            Button(art.wort) { oeffne(adresse) }
                .font(Schrift.sans(14, relativeTo: .footnote))
                .buttonStyle(.plain)
                .foregroundStyle(Farbe.amber)
        }
    }

    // MARK: - 5. Sichtbarkeit und Konfiguration

    /// Die zwei letzten Abschnitte der Vorlage in einer Karte (`page.tsx:158-175`).
    ///
    /// Zwei Abschnitte, eine Karte - begründet im Kopf dieser Datei. Die Vorlage rückt sie
    /// selbst enger zusammen als die vier darüber (`gap-2` statt `gap-3`).
    private var sichtbarkeitUndKonfiguration: some View {
        Karte(kicker: "\(Zugangsworte.ueberschriften[4]) und \(Zugangsworte.ueberschriften[5])") {
            VStack(alignment: .leading, spacing: 12) {
                satz(Zugangsworte.sichtbarkeit)
                satz(Zugangsworte.konfiguration)
                Button(Zugangsworte.annahmenverweis) {
                    wegweiser.gehe(Zugangsworte.annahmenweg)
                }
                .font(Schrift.klein)
                .buttonStyle(.plain)
                .foregroundStyle(Farbe.amber)
            }
        }
    }

    /// Ein Absatz, in dem einzelne Fachwörter in Festbreitenschrift stehen.
    ///
    /// **Aus `Text` + `Text` und nicht aus einem `HStack`.** Ein Absatz muss umbrechen, und
    /// zwar mitten im Satz; nebeneinandergestellte Ansichten brechen nur zwischen sich. SwiftUI
    /// kann mehrere Schriften in *einem* `Text` führen, und genau dafür liegt die Fuge im Kern
    /// (``Zugangsworte/Satzteil``) - welches Wort ein Dateiname ist, ist eine Aussage über den
    /// Satz und keine über die Schrift.
    private func satz(_ teile: [Zugangsworte.Satzteil]) -> some View {
        teile.reduce(Text("")) { gesammelt, teil in
            gesammelt
                + Text(teil.wort)
                .font(
                    teil.mono
                        ? Schrift.mono(notenstufe, relativeTo: .footnote)
                        : Schrift.sans(15, relativeTo: .body)
                )
        }
        .foregroundStyle(Farbe.text2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 6. Verbindung

    /// Was die Verbindung zum Dienst sagt.
    ///
    /// **Sie rutscht nach unten, weil sie in der Vorlage auf dieser Route kein Gegenstück hat**
    /// (gesucht nach „bridge“, „sse“, „version“ in `page.tsx`: kein Treffer). Weggelassen wird
    /// sie nicht: in der App ist dies die einzige Stelle, an der die Fassung des Dienstes und
    /// der Zustand der Brücke überhaupt stehen. „Anzeigen am Strom“ bleibt hier und nicht in
    /// einer eigenen Karte „Gerade verbunden“ - es ist eine Zahl und keine Liste, und eine
    /// Karte mit dem Namen der Vorlage und einer Zahl darin wäre ein Versprechen, das der
    /// Dienst nicht halten kann.
    private var verbindung: some View {
        Karte(kicker: "Verbindung") {
            VStack(spacing: 0) {
                Zeile(wort: "Zustand", wert: verbindungswort)
                if let s = haus.zustand?.system {
                    Zeile(wort: "Betriebsart", wert: s.mode)
                    Zeile(wort: "Fassung des Dienstes", wert: s.version)
                    Zeile(wort: "Brücke", wert: s.bridgeOnline ? "verbunden" : "nicht verbunden")
                    Zeile(wort: "Anzeigen am Strom", wert: String(s.sseClients))
                    // **Die rohe gemessene Zahl, mit einer Dezimalstelle.** Sie ist die
                    // einzige Stelle, an der man eine wandernde Maschinenuhr findet, *bevor*
                    // sie drei Minuten erreicht und auf der Wand `22:04` neben `22:07` stellt.
                    // Die Wache meldet erst ab einer Minute (``Hausuhr/meldeschwelle``) - hier
                    // darf darum nie eine unterdrueckte oder geglaettete Zahl stehen, sonst
                    // waere die Diagnose genau in dem Bereich blind, in dem sie noch billig
                    // ist. ``Hauszustand/versatz`` kennt deshalb keine Schwelle.
                    Zeile(
                        wort: "Zeitversatz zum Dienst",
                        wert: Formate.zahl(haus.versatz, stellen: 1), einheit: "s"
                    )
                }
            }
        }
    }

    // MARK: - 7. Ändern

    private var aendern: some View {
        Karte(kicker: "Ändern") {
            Button {
                neuEinrichten = true
            } label: {
                Text("Neu einrichten")
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.deep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Farbe.amberWeich)
                    .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Die Bausteine des Textes

    /// Ein Absatz der Vorlage: 15 px, `--text-2`, Zeilenhöhe 1,6 (`page.tsx:62`).
    private func absatz(_ wort: String) -> some View {
        Text(wort)
            .font(Schrift.sans(15, relativeTo: .body))
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ein Schlussabsatz der Vorlage: 14 px, `--text-3` (`page.tsx:79`, `:108`, `:150`).
    private func hinweis(_ wort: String) -> some View {
        Text(wort)
            .font(Schrift.sans(14, relativeTo: .footnote))
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verbindungswort: String {
        switch haus.verbindung {
        case .live: return "verbunden"
        case .verbindet: return "verbindet"
        case .verbindetNeu: return "unterbrochen, versucht erneut"
        case .aus: return "angehalten"
        }
    }

    /// Den Platzbedarf holen.
    ///
    /// **Der Fehler wird festgehalten und nicht verschluckt.** Hier stand ein `try?` für die
    /// Mitteilungsgeräte, und ein Fehlschlag war von „noch nichts da“ nicht zu unterscheiden -
    /// die Seite zeigte dann für immer nichts. Die Vorlage hat für genau diesen Fall einen
    /// eigenen Satz (`StorageReport.tsx:41`), und den kann nur zeigen, wer den Fehler kennt.
    private func ladeBestand() async {
        do {
            bestand = try await haus.api.datenbestand()
            bestandFehler = false
        } catch {
            bestandFehler = true
        }
    }
}
