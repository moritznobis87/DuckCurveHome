import DuckCurveKit
import SwiftUI

/// Die Seite „Zugang und Sicherung“: wie dieses Gerät hereingekommen ist, was die Datenbank wiegt,
/// wie man eine Kopie davon aus dem Haus bekommt, und wie die Verbindung steht.
///
/// **Die Vorlage** ist `apps/web/src/app/system/zugang/page.tsx`. Seit dem 25.11.2026 stehen dort
/// wie hier Karten ohne Erklärtexte (der Hausherr: „der Text muss weg“); Platzbedarf und Sicherung
/// tragen in beiden denselben Titel und Satz (``Kontoworte/Kartenart``).
///
/// **Was nur die App hat:** „Dieses Gerät“, „Verbindung“ und „Neu einrichten“. Ein Browser hat
/// weder eine Adresse des Hauses noch einen Schlüsselbund. **Was der App noch fehlt**
/// (`docs/GLEICHSTAND.md`): die Liste der Personen mit dem Einladen und „Gerade verbunden“, das im
/// Dashboard eine Liste im Arbeitsspeicher des Web-Dienstes liest.
struct ZugangSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite
    /// Das Mittel, mit dem iOS eine Adresse an den Browser gibt - siehe ``exportknopf(_:jahr:)``.
    @Environment(\.openURL) private var oeffne

    @State private var neuEinrichten = false
    @State private var bestand: StorageReportOut?
    @State private var bestandFehler = false

    private var schmal: Bool { breite == .compact }


    var body: some View {
        Seite {
            VStack(alignment: .leading, spacing: 16) {
                diesesGeraet
                platzbedarf
                sicherung
                verbindung
                aendern
            }
            .frame(maxWidth: 820, alignment: .leading)
        }
        .sheet(isPresented: $neuEinrichten) {
            Einrichten()
        }
        .task { await ladeBestand() }
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
                        wert: haus.zugang.rolle.wort,
                        farbe: haus.zugang.rolle.darfStellen ? Farbe.text1 : Farbe.achtung
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
        Kontokarte(art: .platz) {
            platzbedarfstand
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

    /// Die Jahresdateien, je Jahr eine Zeile mit zwei runden Knöpfen wie im Dashboard.
    private var sicherung: some View {
        Kontokarte(art: .sicherung) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Zugangsworte.sicherungsjahre(jetzt: haus.jetzt), id: \.self) { jahr in
                    sicherungsjahr(jahr)
                }
                hinweis(Zugangsworte.herunterladen)
                    .padding(.top, 4)
            }
        }
    }

    private func sicherungsjahr(_ jahr: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Zeichen(.kalender, groesse: 17, farbe: Farbe.text2)
                .frame(width: 32, height: 32)
                .background(Farbe.flaeche2)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(jahr)).font(Schrift.mono(15)).foregroundStyle(Farbe.text1)
                Text(Zugangsworte.sicherungszeile)
                    .font(Schrift.mono(12, relativeTo: .caption))
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if schmal {
                VStack(alignment: .trailing, spacing: 6) { knoepfe(jahr) }
            } else {
                HStack(spacing: 6) { knoepfe(jahr) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Farbe.deep.opacity(0.45))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private func knoepfe(_ jahr: Int) -> some View {
        exportknopf(.minuten, jahr: jahr)
        exportknopf(.stunden, jahr: jahr)
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
            Zugangsknopf(wort: art.wort, klein: true) { oeffne(adresse) }
        }
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
            Zugangsknopf(wort: "Neu einrichten", art: .hervor) { neuEinrichten = true }
        }
    }

    // MARK: - Die Bausteine des Textes

    /// Ein leiser Satz unter einer Karte: 14 Punkte, dritte Textstufe.
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
