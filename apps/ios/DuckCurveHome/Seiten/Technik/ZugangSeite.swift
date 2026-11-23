import DuckCurveKit
import SwiftUI

/// Die Seite „Zugang und Sicherung“: wie Geräte hereinkommen, was die Datenbank wiegt, und wie
/// man eine Kopie davon aus dem Haus bekommt.
///
/// **Was hier umgebaut wurde, und warum.** Die Vorlage
/// (`apps/web/src/app/system/zugang/page.tsx`) setzt sechs Abschnitte in dieser Folge: koppeln,
/// wer zusieht, Platzbedarf, Sicherung, Sichtbarkeit, Konfiguration - genau die drei Dinge, die
/// der Bereichskicker verspricht („Geräte koppeln · wer zusieht · Daten sichern“,
/// `Bereiche.swift:170`). Die App hatte davon keinen einzigen: sie zeigte das Token *dieses*
/// Geräts, den Zustand der Verbindung, die Geräte für Mitteilungen und einen Knopf. Vier von
/// sechs Abschnitten fehlten ganz, und ein Fünftel des Textes stand zugeklappt in ``Methode`` -
/// obwohl auf dieser Seite nichts gerechnet wird und dort die Bedienungsanleitung steht.
///
/// **Die Vorlage hat keine Karten, die App hat nur Karten.** Sechs `<section>` mit `<h2>` ohne
/// Kasten (`page.tsx:60`) wären in der App sechs ``Karte`` in Folge - und genau das nennt
/// `handy.css:3-6` als den Fehler, den die Handy-Fassung abgestellt hat („viereinhalb
/// Bildschirme gleich schwerer Kästen“). Die Minderung ist die, die die Vorlage selbst
/// vorzeichnet: wo sie zwei Abschnitte mit `gap-2` statt `gap-3` zusammenrückt (`page.tsx:158,
/// 168`), stehen hier „Sichtbarkeit“ und „Konfiguration“ in einer Karte.
///
/// **Zwei Abschnitte der Vorlage sind nicht nachgebaut, und das ist kein Rest.** Die zwei
/// Pairing-Links tragen Umgebungsvariablen des Web-Dienstes (`page.tsx:51-52`), und „Gerade
/// verbunden“ liest eine `Map` im Arbeitsspeicher von Next (`lib/presence.ts:38-41`); im Dienst
/// des Hauses gibt es für beides keinen Endpunkt (nachgesehen in `docs/openapi.json`). Eine
/// erfundene Liste von Zuschauern wäre schlimmer als keine. Was die App dazu sagen kann, sagt
/// ``Zugangsworte/koppeln``: wo die Links stehen, und warum dieses Gerät sie nicht braucht.
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
            koppeln
            diesesGeraet
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

    // MARK: - 1. Zugang einrichten

    /// Der erste Abschnitt der Vorlage (`page.tsx:60-86`), ohne die Links.
    ///
    /// Statt der zwei `Row` mit Kopierknopf stehen hier die zwei Noten, die in der Vorlage unter
    /// den Links hängen (`page.tsx:73, 78`): was ein Vollzugriff darf und was ein Gast sieht.
    /// Das ist die Aussage der beiden Kästen; der Link selbst ist nur ihr Träger, und den hat
    /// die App nicht.
    private var koppeln: some View {
        Karte(kicker: Zugangsworte.ueberschriften[0]) {
            VStack(alignment: .leading, spacing: 12) {
                absatz(Zugangsworte.koppeln)
                rollenkasten("Vollzugriff (Hausherr, Wandanzeige)", Zugangsworte.vollzugriff)
                rollenkasten("Gast (nur ansehen)", Zugangsworte.gast)
                hinweis(Zugangsworte.sitzungsdauer)
            }
        }
    }

    /// Ein Kasten wie `Row` in der Vorlage (`page.tsx:12-20`): Kicker, dann die Note.
    ///
    /// Die Maße sind die der Vorlage, übersetzt: `rounded-[3px]` ist ``Marken/radius2``
    /// (3 Punkte, deckungsgleich mit `--radius-2`), `border-line-1` ist ``Farbe/linie1``,
    /// `bg-surface-2` ist ``Farbe/flaeche2``, `p-4` sind 16 Punkte.
    private func rollenkasten(_ wort: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: wort)
            Text(note)
                .font(Schrift.sans(notenstufe, relativeTo: .footnote))
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Farbe.flaeche2)
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
    }

    // MARK: - 2. Dieses Gerät

    /// Die Karte, die die App vorher an erster Stelle hatte - und die dort falsch stand.
    ///
    /// Sie ist nicht das Gegenstück zu den Pairing-Links, sondern ihre Ergänzung: dort steht,
    /// wie andere Geräte hereinkommen, hier, wie dieses hereingekommen ist. Darum steht sie
    /// jetzt daneben und nicht an ihrer Stelle.
    private var diesesGeraet: some View {
        Karte(kicker: "Dieses Gerät") {
            VStack(spacing: 0) {
                Zeile(wort: "Name im Protokoll", wert: haus.zugang.geraetename)
                Zeile(wort: "Kennung", wert: haus.zugang.geraetekennung)
                Zeile(
                    wort: "Zugang",
                    wert: haus.zugang.rolle == .hausherr ? "Hausherr" : "Gast",
                    farbe: haus.zugang.rolle == .hausherr ? Farbe.text1 : Farbe.achtung
                )
                Zeile(wort: "Adresse", wert: haus.zugang.grund.absoluteString)
                Zeile(wort: "Pfad", wert: haus.zugang.praefix)
                Zeile(
                    wort: "Token",
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
