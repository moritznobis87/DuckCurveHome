import DuckCurveKit
import SwiftUI

/// Haustür: wer sich am Reader erkennen ließ, und was geschah.
///
/// Vorlage sind `apps/web/src/app/system/haustuer/page.tsx` und
/// `apps/web/src/components/settings/DoorLog.tsx`.
///
/// **Diese Seite hat eine Hauptaussage, und die stand bis zum 20.11.2026 nicht da.** Sie ist
/// nur zu lesen - von hier führt kein Weg zur Tür, und das ist Entwurf und nicht Sparsamkeit
/// (`DoorLog.tsx:8-13`: „Eine Schaltfläche „öffnen“ an dieser Stelle wäre eine Haustür am
/// Internet.“). Und sie zeigt die abgelehnten Versuche mit, weil sie die eigentliche Auskunft
/// sind: ein Protokoll, das nur die geglückten Öffnungen zeigt, beantwortet die Frage nicht,
/// wegen der man abends hineinsieht (`DoorLog.tsx:15-16`, ebenso am Endpunkt
/// `apps/api/src/dch_api/routers/system.py:173-182` und in der Bridge
/// `apps/bridge/src/dch_bridge/door.py:115-120`). Beide Sätze stehen jetzt als Absätze oben und
/// unten auf der Seite; vorher fing sie mit einer Kachelreihe an.
///
/// ## Was hier gerechnet wird: nichts
///
/// Die Verfahrenswörter, der Ton je `outcome`, die Tagesgruppen, die Zählung und die festen
/// Sätze stehen in ``Tuerprotokoll`` im Kern, wo sie geprüft sind. Diese Datei setzt sie nur.
/// Der Grund steht dort ausführlich; in einem Satz: die Seite zählte `granted` statt `outcome`
/// und gab damit abgelehnte und fehlgeschlagene Versuche als Öffnungen aus.
///
/// ## Drei bewusste Abweichungen von der Vorlage
///
/// 1. **Die drei Kennzahlen gibt es in der Vorlage nicht.** Begründung an
///    ``Tuerprotokoll/kacheln(_:)``: auf einem Telefon, das die Liste nur in Ausschnitten
///    zeigt, beantworten sie die Frage der Seite vor dem Rollen. Sie zählen jetzt über
///    `outcome`.
/// 2. **Der Fehlerfall behält seinen „Erneut“-Knopf.** Die Vorlage schreibt einen Satz ohne
///    Knopf und lädt nur über die Spannenwahl neu (`DoorLog.tsx:91`, `:118`); im Projekt ist
///    diese Abweichung begründet und soll nicht zurückgebaut werden
///    (`Seiten/Technik/BetriebSeite.swift:57-62`): auf einem Telefon mit wackligem Netz ist ein
///    Knopf die bessere Antwort als der Rat, den Zeitraum zu wechseln.
/// 3. **Der Tag einer Gruppe ist der der Hauszeit** und nicht der des Geräts - Begründung an
///    ``Tuerprotokoll/gruppen(_:jetzt:)``.
///
/// ## Der Kicker steht nicht hier
///
/// „Wer sich am Reader erkennen ließ, und was geschah“ (`page.tsx:9`) zeichnet ``Seite`` aus
/// ``Bereiche/kicker(fuer:)``, und nur an der Wand - wie `hidden … md:block` an der Vorlage
/// (`apps/web/src/components/layout/AreaNav.tsx:96`).
struct HaustuerSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var tage = Tuerprotokoll.vorgabe
    @State private var protokoll: DoorLogOut?
    @State private var fehler: ApiFehler?

    private var schmal: Bool { breite == .compact }

    /// Die 13 Punkte der Vorlage sind am Telefon 14,5 (`handy.css:189-192`, Begründung im
    /// Kommentar dort: „Am Rechner liest man 12 Punkt aus sechzig Zentimetern, am Handy aus
    /// dreißig, aber im Gehen“). Auf dieser Seite trifft das die Uhrzeit, das „per …“ und die
    /// Begründungszeile - **nicht** den Namen (14) und nicht die beiden Absätze (15 und 14).
    private var kleinstufe: CGFloat { schmal ? 14.5 : 13 }

    var body: some View {
        Seite {
            spalte
        }
        .task(id: tage) { await lade() }
    }

    /// Eine Karte wie auf den übrigen Systemseiten (`DoorLog.tsx`), ohne Erklärtexte (Hausherr,
    /// 25.11.2026).
    private var spalte: some View {
        Kontokarte(zeichen: .tuer, titel: "Haustür", satz: Tuerprotokoll.kartensatz) {
            VStack(alignment: .leading, spacing: 12) {
                Tagewahl(tage: $tage, moeglich: Tuerprotokoll.spannen, form: .haustuerprotokoll)
                if let fehler {
                    Stoerung(fehler: fehler) { Task { await lade() } }
                }
                if let p = protokoll {
                    protokollteil(p)
                } else if fehler == nil {
                    absatz(Tuerprotokoll.ladesatz, 14, Farbe.text3)
                }
            }
        }
        .frame(maxWidth: 820, alignment: .leading)
    }

    // MARK: - Das Protokoll

    @ViewBuilder private func protokollteil(_ p: DoorLogOut) -> some View {
        HStack(spacing: 8) {
            ForEach(Tuerprotokoll.kacheln(p.entries), id: \.wort) { k in
                Zahlkachel(wert: k.wert, wort: k.wort, farbe: farbe(k.hervor))
            }
        }
        tagesliste(Tuerprotokoll.gruppen(p.entries, jetzt: haus.jetzt))
        // **Der Satz des Dienstes steht sichtbar da und nicht hinter einem Deckel.** Er ist die
        // einzige Zählung der Seite („… Ereignisse in … Tagen, davon … geöffnet.“,
        // `system.py:189-195`), und ``Methode`` ist zugeklappt, solange niemand fragt
        // (`Seiten/Bericht.swift:819,834-836`) - dort stand er bis zum 20.11.2026 und war nicht zu
        // sehen. Die Vorlage zeigt ihn immer (`DoorLog.tsx:136`) und hat auf dieser Seite
        // überhaupt keinen Methodenblock (gesucht nach `Methode` in `page.tsx` und
        // `DoorLog.tsx`: kein Treffer).
        absatz(p.noteDe, 14, Farbe.text3)
    }

    /// Die Tagesgruppen, oder nichts.
    ///
    /// **Bei leerer Liste zeichnet die Vorlage gar keinen Kasten** (`DoorLog.tsx:121`,
    /// `groups.length > 0`) - der Satz des Dienstes sagt es schon, und er sagt es genauer: „Noch
    /// kein Zutritt aufgezeichnet“ ist etwas anderes als „In diesem Zeitraum wurde nicht
    /// aufgeschlossen“, was hier vorher stand und die abgewiesenen Versuche unterschlug.
    @ViewBuilder private func tagesliste(_ gruppen: [Tuerprotokoll.Tagesgruppe]) -> some View {
        if !gruppen.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(gruppen) { g in
                    tagesgruppe(g)
                }
            }
        }
    }

    /// Ein Kalendertag: sein Name als Kicker, darunter je Zutritt eine Zeile wie auf „Mein
    /// Zugang“ (`DoorLog.tsx`, `.konto-zeile`).
    private func tagesgruppe(_ g: Tuerprotokoll.Tagesgruppe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: g.wort)
            ForEach(Array(g.eintraege.enumerated()), id: \.offset) { _, e in
                eintrag(e)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .background(Farbe.deep.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Farbe.linie1, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Eine Zeile

    /// Uhrzeit, Name, Verfahren, Zustand - und darunter, wenn es etwas zu erklären gibt, die
    /// Begründung.
    ///
    /// **Die Begründung steht nur da, wenn die Tür zu blieb**
    /// (``Tuerprotokoll/begruendung(_:)``). Vorher verband die App `door`, `method` und `reason`
    /// mit „ · “, und weil `reason` bei einer geglückten Öffnung der Satz „Anna an „Haustür“ per
    /// NFC.“ ist (`door_access.py:149`), las sich die Zeile „Haustür · NFC · Anna an „Haustür“
    /// per NFC.“. Eingezogen ist sie um 56 Punkte, also um die Uhrzeitspalte samt Abstand
    /// (`DoorLog.tsx:73`, `pl-[56px]`), damit sie unter dem Namen anfängt und nicht unter der
    /// Uhrzeit.
    private func eintrag(_ e: DoorEntryOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            kopfzeile(e)
            if let grund = Tuerprotokoll.begruendung(e) {
                Text(grund)
                    .font(Schrift.sans(kleinstufe, relativeTo: .footnote))
                    .foregroundStyle(Farbe.text3)
                    // `leading-[1.5]`: SwiftUI zählt den Zuschlag, und die Zeilenschachtel ist
                    // schon etwa 1,25-mal so hoch - bleiben 0,25 der Größe.
                    .lineSpacing(kleinstufe * 0.25)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 56)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }

    /// Die erste Zeile eines Eintrags.
    ///
    /// **Links eine Reihe, die umbricht, rechts die Plakette.** Die Vorlage ist ein
    /// `flex flex-wrap` mit `ml-auto` an der Plakette (`DoorLog.tsx:63`, `:67`): bei einem
    /// langen Namen rutscht etwas in die nächste Zeile, statt gekürzt zu werden. Auf einem
    /// Telefon tritt das ein - 44 Punkte Uhrzeit, ein zweiteiliger Name, „per Gesicht“ und eine
    /// Plakette sind mehr als die 326 Punkte, die zwischen den Rändern bleiben. ``Umbruchzeile``
    /// bricht um; die Plakette steht daneben, damit sie rechts bleibt und nicht mitwandert.
    ///
    /// **Oben ausgerichtet und nicht an der Grundlinie.** ``Umbruchzeile`` ist ein eigenes
    /// `Layout` und meldet keine Textgrundlinie; `.firstTextBaseline` würde sie darum an ihrer
    /// Unterkante ausrichten und die Plakette nach unten schieben. Mit `.top` sitzt die Schrift
    /// der Plakette um ihr Polster tiefer als die Uhrzeit - vier Punkte, die eine gefüllte
    /// Plakette verträgt, weil man sie als Fläche liest und nicht als Zeile Text.
    private func kopfzeile(_ e: DoorEntryOut) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Umbruchzeile(abstand: 12, zeilenabstand: 4) {
                uhrzeit(e)
                Text(Tuerprotokoll.name(e.actor))
                    .font(Schrift.sans(14, relativeTo: .footnote))
                    .foregroundStyle(Farbe.text1)
                Text(Tuerprotokoll.verfahrenSatz(e.method))
                    .font(Schrift.sans(kleinstufe, relativeTo: .footnote))
                    .foregroundStyle(Farbe.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Plakette(wort: e.outcome, ton: plakettenton(e))
        }
    }

    /// Die Uhrzeit, Mono, in einer Spalte von mindestens 44 Punkten.
    ///
    /// **Sie steht zuerst**, und das ist der Punkt: die Vorlage setzt sie in `w-[44px]
    /// shrink-0` (`DoorLog.tsx:64`), damit die Zeiten einer Gruppe untereinander stehen. Vorher
    /// stand sie in der App rechts in einer zweiten Spalte, hinter einem Punkt und einem
    /// zweizeiligen Block - als Spalte war sie nicht lesbar.
    ///
    /// **`minWidth` und nicht `width`.** Eine feste Breite bricht, wenn „Größerer Text“ aus den
    /// Bedienungshilfen die Schrift anhebt; die Spalte bleibt trotzdem eine, weil jede Uhrzeit
    /// dieselben fünf Zeichen in derselben Festbreitenschrift hat und damit dieselbe Breite
    /// bekommt. Nur der Strich, den ``Formate/hhmm(iso:)`` bei einem unlesbaren Stempel liefert,
    /// ist kürzer - und der wird von den 44 Punkten aufgefüllt.
    private func uhrzeit(_ e: DoorEntryOut) -> some View {
        Text(Formate.hhmm(iso: e.at))
            .font(Schrift.mono(kleinstufe, relativeTo: .footnote))
            .foregroundStyle(Farbe.text3)
            .lineLimit(1)
            .frame(minWidth: 44, alignment: .leading)
    }

    /// Welcher Ton der Plakette zu welchem Zustand gehört (`DoorLog.tsx:70`).
    ///
    /// Die Unterscheidung selbst trifft ``Tuerprotokoll/ton(_:)`` im Kern; hier wird nur
    /// übersetzt - dieselbe letzte Meile wie bei ``Farbe/ton(_:)``. Dass ein Fehlschlag rot ist
    /// und eine Ablehnung nicht, ist die Entscheidung, die der Kommentar der Vorlage festhält:
    /// „dort hat das Haus nein gesagt, hier hat das Schloss nicht reagiert. Nur das zweite ist
    /// ein Defekt.“ (`DoorLog.tsx:68-69`).
    private func plakettenton(_ e: DoorEntryOut) -> Plakette.Ton {
        switch Tuerprotokoll.ton(e.outcome) {
        case .geoeffnet: return .amber
        case .abgelehnt: return .neutral
        case .fehlgeschlagen: return .alarm
        }
    }

    // MARK: - Die Kennzahlen

    /// Die Stufe des Kerns als Farbe. ``Kennzahl/Ton`` kennt keinen Alarm, und darum geht diese
    /// Seite nicht über ``Kacheldaten/init(_:)``, sondern setzt die Farbe selbst - aus den
    /// vorhandenen Marken, nicht aus neuen.
    private func farbe(_ hervor: Tuerprotokoll.Hervorhebung) -> Color {
        switch hervor {
        case .keine: return Farbe.text1
        case .achtung: return Farbe.achtung
        case .alarm: return Farbe.alarm
        }
    }

    // MARK: - Absätze

    /// Ein Absatz mit `line-height: 1.6`.
    ///
    /// CSS meint damit die Höhe der Zeilenschachtel, SwiftUI den **Zuschlag** - und die
    /// Schachtel ist dort schon etwa 1,25-mal so hoch. Der Zuschlag ist also rund 0,35 der
    /// Größe; ohne diese Umrechnung stünden die Zeilen enger als in der Vorlage. Dieselbe
    /// Rechnung macht ``MitteilungenSeite`` für dieselben Absätze der Vorlage.
    private func absatz(_ text: String, _ groesse: CGFloat, _ farbe: Color) -> some View {
        Text(text)
            .font(Schrift.sans(groesse))
            .foregroundStyle(farbe)
            .lineSpacing(groesse * 0.35)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Laden

    /// **Die Liste verschwindet, während die neue Spanne unterwegs ist.** Die Vorlage setzt
    /// `data` vor jeder Abfrage auf `null` (`DoorLog.tsx:85`); stehenzulassen, was zur alten
    /// Spanne gehört, hieße, dreißig Tage als sieben auszugeben.
    private func lade() async {
        protokoll = nil
        fehler = nil
        do {
            protokoll = try await haus.api.haustuer(tage: tage)
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}
