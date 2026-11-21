import DuckCurveKit
import SwiftUI
import UniformTypeIdentifiers

/// Alfred als Blatt über der Anwendung.
///
/// **Ohne Sprachmodell erklärt er die Seiten** – vorbereitete Texte aus dem Kern, nichts
/// verlässt das Haus. Mit Modell beantwortet er Fragen zu den Daten dieses Hauses.
///
/// **Geschaltet wird erst auf Bestätigung, und zwar genau das, was dasteht.** Ein Vorschlag
/// des Modells ist ein Vorschlag; was er bewirkt, rechnet ``Alfred/ausfuehrung(_:)`` im Kern
/// aus den Feldern des Vorschlags, nicht aus seinem Antworttext. Die Bestätigung zeigt die
/// Änderung noch einmal in Worten, und sie sagt dazu, dass ein KI-Assistent sie
/// vorgeschlagen hat.
///
/// **Was hier noch fehlt**, und darum hier steht statt nirgends: die Sensorzuordnung bei der
/// Einrichtung. Sie braucht eine aus Home Assistant eingefügte Entitätenliste, und die fügt
/// man an einem Telefon nicht ein. Die Spracheingabe gibt es inzwischen – sie hängt an der
/// Ente, siehe ``Entenknopf``.
struct Alfredblatt: View {
    /// Eine Frage, die schon gestellt ist, wenn das Blatt aufgeht - gesprochen, mit gedrückter
    /// Ente. Sie wird beim Öffnen abgeschickt, ohne dass noch jemand tippen muss.
    var starttext: String?

    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.dismiss) private var schliessen

    @State private var zustand: AlfredZustandOut?
    @State private var nachrichten: [Alfred.Nachricht] = []
    @State private var vorschlaege: [AlfredVorschlagOut] = []
    @State private var frage: String = ""
    @State private var laeuft = false
    @State private var schritt: String?
    @State private var zuPruefen: AlfredVorschlagOut?
    @State private var fuehrtAus = false
    @State private var zeigtDateiwahl = false

    /// Wo die Ente steht. **Hier steht der Weg zurück**: wer sie verschoben hat und sie nicht
    /// mehr findet oder nicht mehr dort haben will, kommt über sie selbst in dieses Blatt, und
    /// hier steht dann der Knopf. Eine Einstellungsseite dafür wäre eine Zeile für eine Ente.
    @AppStorage(Entenplatz.merker) private var enteGemerkt = Entenplatz.gemerkt(Entenplatz.vorgabe)

    @FocusState private var amFeld: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Farbe.grundVerlauf.ignoresSafeArea()
                VStack(spacing: 0) {
                    gespraech
                    fuss
                }
            }
            .navigationTitle(Alfred.Texte.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Alfred.Texte.schliessen) { schliessen() }
                }
                // Nur wenn sie woanders steht: ein Knopf, der nichts zurücksetzt, ist einer,
                // der jeden Tag erklärt werden muss.
                if Entenplatz.gelesen(enteGemerkt) != Entenplatz.vorgabe {
                    ToolbarItem(placement: .primaryAction) {
                        Button(Alfred.Texte.enteZurueck) {
                            enteGemerkt = Entenplatz.gemerkt(Entenplatz.vorgabe)
                        }
                    }
                }
            }
        }
        .task {
            await ladeZustand()
            if let starttext, !starttext.isEmpty { await frageStellen(starttext) }
        }
        .fileImporter(isPresented: $zeigtDateiwahl, allowedContentTypes: [.pdf]) { ergebnis in
            Task { await lies(ergebnis) }
        }
        .confirmationDialog(
            Alfred.Texte.bestaetigungTitel,
            isPresented: Binding(get: { zuPruefen != nil }, set: { if !$0 { zuPruefen = nil } }),
            titleVisibility: .visible
        ) {
            if let v = zuPruefen {
                Button(Alfred.Texte.bestaetigungOk) { Task { await fuehreAus(v) } }
            }
            Button(Alfred.Texte.bestaetigungAbbrechen, role: .cancel) { zuPruefen = nil }
        } message: {
            if let v = zuPruefen {
                Text("\(Alfred.vorschlagAenderung(v))\n\n\(Alfred.Texte.bestaetigungHinweis)")
            }
        }
    }

    // MARK: - Das Gespräch

    private var gespraech: some View {
        ScrollViewReader { blick in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(nachrichten) { n in
                        blase(n).id(n.id)
                    }
                    if laeuft {
                        Text(schritt ?? Alfred.Texte.frageLaeuft)
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.text3)
                            .id("laeuft")
                    }
                    if !vorschlaege.isEmpty {
                        vorschlagskarte
                    }
                    schnellfragen
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: nachrichten.count) {
                withAnimation { blick.scrollTo(nachrichten.last?.id, anchor: .bottom) }
            }
        }
    }

    private func blase(_ n: Alfred.Nachricht) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if n.ausModell {
                // `.alfred-ki` (`globals.css:858`): Sans 11, 0,04 em, Großbuchstaben, in
                // `amber-soft`. Kein Kicker - die Marke sagt, woher die Antwort kommt, und
                // steht darum in der Farbe, die in dieser Anwendung „von der Maschine“ heißt.
                Text(Alfred.Texte.kiMarke.uppercased())
                    .font(Schrift.sans(11, relativeTo: .caption2))
                    .tracking(0.44)
                    .foregroundStyle(Farbe.amberWeich)
            }
            Text(fettgedruckt(n.inhalt))
                .font(Schrift.text)
                .foregroundStyle(n.wer == .nutzer ? Farbe.text1 : Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
            if let weg = n.weg {
                Button(Alfred.Texte.rechnungZurAuswertung) {
                    wegweiser.gehe(weg)
                    schliessen()
                }
                .font(Schrift.klein)
                .foregroundStyle(Farbe.amber)
            }
        }
        .padding(.horizontal, n.wer == .nutzer ? 12 : 0)
        .padding(.vertical, n.wer == .nutzer ? 8 : 0)
        .background(
            n.wer == .nutzer
                ? AnyShapeStyle(Farbe.flaeche3) : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .frame(maxWidth: .infinity, alignment: n.wer == .nutzer ? .trailing : .leading)
    }

    /// Kurzer Text aus `**fett**` – mehr Auszeichnung schreibt Alfred nicht.
    private func fettgedruckt(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private var schnellfragen: some View {
        Umbruchzeile(abstand: 8, zeilenabstand: 8) {
            knopf(Alfred.Texte.seiteErklaeren) {
                sage(.nutzer, Alfred.Texte.seiteErklaeren)
                sage(.alfred, Alfred.antwortSeite(weg: wegweiser.weg))
            }
            knopf(Alfred.Texte.wasKannAlfred) {
                sage(.nutzer, Alfred.Texte.wasKannAlfred)
                sage(.alfred, Alfred.antwortWasKannAlfred(zustand))
            }
            knopf(Alfred.Texte.rechnungKnopf) { zeigtDateiwahl = true }
            if zustand?.bereit == true {
                ForEach(Alfred.Texte.beispiele, id: \.self) { b in
                    knopf(b) { Task { await frageStellen(b) } }
                }
            }
        }
    }

    private func knopf(_ wort: String, _ tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Text(wort)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Farbe.flaeche3, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(laeuft)
    }

    // MARK: - Vorschläge

    private var vorschlagskarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            // `.alfred-vorschlaege-liste .titel` (`globals.css:876`): Sans 12 in
            // `amber-soft`, ohne Sperrung und ohne Großschrift. Auch das war kein Kicker.
            Text(Alfred.Texte.vorschlagTitel)
                .font(Schrift.sans(12, relativeTo: .caption))
                .foregroundStyle(Farbe.amberWeich)
            ForEach(Array(vorschlaege.enumerated()), id: \.offset) { _, v in
                HStack(spacing: 10) {
                    Text(Alfred.vorschlagText(v))
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text1)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    // Ein Vorschlag, den diese Fassung nicht ausfuehren kann, bekommt keinen
                    // Knopf - und keine Erklaerung, die so tut, als koennte sie es doch.
                    if Alfred.ausfuehrung(v) != nil {
                        Button("Prüfen …") { zuPruefen = v }
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.amber)
                            .disabled(fuehrtAus)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farbe.flaeche2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Farbe.amber.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Der Fuß

    private var fuss: some View {
        VStack(spacing: 8) {
            Divider().overlay(Farbe.linie1)
            if zustand?.bereit == true {
                HStack(spacing: 8) {
                    TextField(Alfred.Texte.frageFeld, text: $frage, axis: .vertical)
                        .font(Schrift.text)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($amFeld)
                        .submitLabel(.send)
                        .onSubmit { Task { await frageStellen(frage) } }
                    Button(Alfred.Texte.frageSenden) {
                        Task { await frageStellen(frage) }
                    }
                    .font(Schrift.karte)
                    .foregroundStyle(Farbe.amber)
                    .disabled(laeuft || frage.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
            }
            Text(Alfred.hinweis(zustand))
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .background(Farbe.flaeche1)
    }

    // MARK: - Tun

    private func sage(_ wer: AlfredWechselInWerWahl, _ text: String, ausModell: Bool = false, weg: String? = nil) {
        nachrichten.append(
            Alfred.Nachricht(wer: wer, inhalt: text, ausModell: ausModell, weg: weg))
    }

    private func ladeZustand() async {
        zustand = try? await haus.api.alfredZustand()
        if nachrichten.isEmpty {
            sage(.alfred, Alfred.Texte.begruessung)
        }
    }

    private func frageStellen(_ text: String) async {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty, !laeuft else { return }
        guard zustand?.bereit == true else {
            sage(.alfred, Alfred.Texte.frageOhneModell)
            return
        }
        frage = ""
        amFeld = false
        // **Der Verlauf vor der eigenen Frage.** Wird er danach genommen, steht die Frage
        // zweimal in der Anfrage: einmal als `frage` und einmal als letzter Wechsel des
        // Verlaufs. Das Modell liest sie dann doppelt und antwortet entsprechend.
        let verlauf = Alfred.verlaufFuerDienst(nachrichten)
        sage(.nutzer, sauber)
        laeuft = true
        schritt = nil
        vorschlaege = []

        let eingabe = AlfredFrageIn(
            frage: sauber, wissen: Alfred.wissen(weg: wegweiser.weg), verlauf: verlauf)
        // **Der Fortschritt laeuft ueber einen Strom und nicht ueber einen Rueckruf, der
        // `self` einfaengt.** Eine Ansicht ist auf dem Hauptakteur zu Hause; der Rueckruf des
        // Clients ist `@Sendable` und darf sie nicht mitnehmen. Die Fortsetzung eines
        // `AsyncStream` darf er, und die Schleife, die daraus Text macht, laeuft wieder auf
        // dem Hauptakteur.
        let (fortschritt, weiter) = AsyncStream<String>.makeStream()
        let anzeige = Task { @MainActor in
            for await werkzeug in fortschritt { schritt = Alfred.schrittText(werkzeug) }
        }
        do {
            let antwort = try await frageMitRueckfallebene(eingabe, weiter: weiter)
            sage(.alfred, antwort.antwort, ausModell: true)
            vorschlaege = antwort.vorschlaege
        } catch {
            sage(.alfred, Alfred.Texte.frageFehler)
        }
        weiter.finish()
        anzeige.cancel()
        laeuft = false
        schritt = nil
    }

    /// Erst der Weg mit Fortschritt, und wenn der nicht geht, der ohne.
    ///
    /// **Warum es die Rueckfallebene gibt.** Der Fortschritt ist eine Annehmlichkeit, die
    /// Antwort ist die Sache. Scheitert der Ereignisstrom - ein Gegenstueck, das ihn nicht
    /// kennt, etwas dazwischen, das ihn puffert -, ist eine Antwort ohne Zwischenstand immer
    /// noch besser als ein Blatt, auf dem „Ich denke nach ...“ stehen bleibt. Genau das stand
    /// am 17.11. auf dem Geraet, weil der Strom an einer falschen Sitzung hing.
    private func frageMitRueckfallebene(
        _ eingabe: AlfredFrageIn, weiter: AsyncStream<String>.Continuation
    ) async throws -> AlfredAntwortOut {
        do {
            return try await haus.api.alfredFrageMitFortschritt(eingabe) { werkzeug in
                weiter.yield(werkzeug)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            schritt = Alfred.Texte.frageLaeuft
            return try await haus.api.alfredFrage(eingabe)
        }
    }

    private func fuehreAus(_ v: AlfredVorschlagOut) async {
        guard let was = Alfred.ausfuehrung(v) else { return }
        zuPruefen = nil
        fuehrtAus = true
        do {
            switch was {
            case .schalten(let schluessel, let an):
                _ = try await haus.api.schalte(schluessel, an: an)
            case .sollwert(let raum, let grad):
                _ = try await haus.api.stelleRaum(raum, sollwertC: grad)
            }
            sage(.alfred, "Erledigt: \(Alfred.vorschlagAenderung(v))")
            vorschlaege.removeAll { $0 == v }
        } catch {
            sage(.alfred, Alfred.Texte.vorschlagFehler)
        }
        fuehrtAus = false
    }

    private func lies(_ ergebnis: Result<URL, any Error>) async {
        guard case .success(let url) = ergebnis else { return }
        // Eine Datei aus der Dateiauswahl liegt ausserhalb der Sandkiste: ohne diesen Zugriff
        // kommt ein leeres `Data` zurueck, und die Rechnung waere „nicht lesbar“.
        let darf = url.startAccessingSecurityScopedResource()
        defer { if darf { url.stopAccessingSecurityScopedResource() } }
        guard let pdf = try? Data(contentsOf: url), !pdf.isEmpty else {
            sage(.alfred, Alfred.Texte.rechnungKeinPdf)
            return
        }
        laeuft = true
        schritt = Alfred.Texte.rechnungLaeuft
        do {
            let r = try await haus.api.alfredRechnung(pdf: pdf)
            sage(.alfred, rechnungssatz(r), ausModell: r.art == .andere, weg: r.link)
        } catch {
            sage(.alfred, Alfred.Texte.frageFehler)
        }
        laeuft = false
        schritt = nil
    }

    /// Was von einer gelesenen Rechnung im Gespräch steht.
    ///
    /// Eine Tibber-Rechnung hat der Dienst selbst geprüft und abgelegt – sie trägt darum keine
    /// KI-Marke. Bei anderen Anbietern hat das Modell gelesen, und das steht dann auch dabei.
    private func rechnungssatz(_ r: AlfredRechnungOut) -> String {
        if let t = r.tibber {
            return
                "\(t.zeitraum): \(Formate.kwh(t.kwh)) für \(Formate.euro(t.bruttoEur)), das sind \(Formate.ct(t.ctKwhBrutto)). \(t.urteil)"
                + (t.schonBekannt ? " Diese Rechnung lag schon vor." : " Sie ist abgelegt.")
        }
        if let a = r.andere {
            let g = a.gelesen
            return
                "Gelesen: \(g.anbieter ?? "unbekannter Anbieter"), \(Formate.kwh(g.kwh)) für \(Formate.euro(g.bruttoEur))."
                + (a.befunde.isEmpty ? "" : " " + a.befunde.map(\.titel).joined(separator: " · "))
        }
        return Alfred.Texte.rechnungKeinPdf
    }
}


/// Der Knopf, der Alfred ruft: das Maskottchen über der Seite, standardmäßig unten rechts.
///
/// **Über der Seite und nicht in der Leiste.** Die Bereichsleiste unten gehört den fünf
/// Bereichen; ein sechstes Zeichen darin wäre ein Bereich, und Alfred ist keiner. Im
/// Dashboard schwebt er an derselben Stelle.
///
/// **Die Ente und nicht die Kurve.** Oben links im Kopf steht die Marke – der Kurvenzug, der
/// dem Haus den Namen gibt. Hier steht das Maskottchen: dieselbe Ente wie im Dashboard
/// (`brand/ente-maskottchen.svg`) und auf dem Programmsymbol. Zwei Zeichen, zwei Aufgaben;
/// hier wird jemand angesprochen, nicht eine Marke gezeigt.
///
/// **Tippen öffnet, Halten spricht, Ziehen verschiebt.** Die ersten beiden sind dieselbe Geste
/// wie an der Wand: 350 Millisekunden gedrückt, dann hört Alfred zu, solange der Finger liegen
/// bleibt. Kürzer ist ein Tippen und öffnet nur das Blatt. Länger als ein Tippen, kürzer als das
/// lange Drücken des Systems.
///
/// **Die dritte Geste musste sich zwischen die beiden drängen** (Nutzer am 21.11.2026: „das
/// Symbol von Alfred verschiebbar machen wenn man laenger drauf drueckt und es dann ueber den
/// Monitor zieht“). Das lange Drücken war besetzt, und das ist kein Formfehler, sondern der
/// ganze Entwurf: ab 350 Millisekunden ist das Mikrofon an. Die Grenze ist darum nicht die Zeit,
/// sondern der Weg – ``Entenplatz/zugSchwelle``, der Radius der Ente selbst. Wer den Finger über
/// ihren Rand hinausbewegt, verschiebt; wer ihn liegen lässt, spricht.
///
/// **Und die Aufnahme wird dabei weggeworfen, nicht abgeschickt.** Ein Zug kommt oft erst nach
/// den 350 Millisekunden, dann läuft das Mikrofon schon. ``Sprachhoerer/brich()`` löscht die
/// Aufnahme samt Rückruf; ``Sprachhoerer/beende()`` würde sie abschicken. Wer die Ente nur
/// umsetzt, hat nicht nebenbei eine Frage gestellt - das ist die Zusage dieser drei Gesten, und
/// sie gilt auch in der Lücke, in der die Erlaubnis noch angelaufen ist.
///
/// **Alle drei Lagen sieht man.** Beim Zuhören wird die Ente größer, trägt einen roten Punkt und
/// den Zettel mit der Mitschrift; beim Verschieben folgt sie dem Finger, ohne Punkt und ohne
/// Zettel, und beim Übergang dorthin rüttelt es einmal. Das Rütteln hat die Wandanzeige
/// vorgemacht (`Alfred.tsx:337`: `navigator.vibrate(20)`, als die Haltegeste anläuft); dort
/// konnte es nur das Android-Telefon, hier kann es jedes.
struct Entenknopf: View {
    @Environment(Hauszustand.self) private var haus

    @State private var zeigtAlfred = false
    @State private var gefragt: String?
    /// Ob ein Sprachmodell eingerichtet ist. `nil` heisst: noch nicht beantwortet.
    @State private var bereit: Bool?
    @State private var hoerer = Sprachhoerer()

    /// Wo die Ente steht – im Gerät gemerkt, nicht über iCloud (``Entenplatz/merker``).
    ///
    /// Gemerkt wird das Wort einer Stelle und nicht ein Punkt: ein Punkt gälte für genau diesen
    /// Bildschirm in genau dieser Lage. Was im Merker steht, darf auch Unsinn sein -
    /// ``Entenplatz/gelesen(_:)`` macht daraus die Vorgabe.
    @AppStorage(Entenplatz.merker) private var gemerkt = Entenplatz.gemerkt(Entenplatz.vorgabe)

    /// **Der Finger liegt – als `@GestureState` und nicht als `@State`.** Eine Geste kann
    /// abgebrochen werden, und dann kommt kein `onEnded`: iOS storniert die Berührungen,
    /// sobald ein Systemdialog über dem Fenster liegt – und genau das tut der erste Griff
    /// nach dem Mikrofon. Ein `@State`, das nur `onEnded` zurücksetzt, bliebe danach auf
    /// „gedrückt“ stehen; die Ente reagierte beim nächsten Mal nicht, und das Mikrofon liefe
    /// weiter, weil niemand das Ende meldet. `@GestureState` setzt sich beim Abbruch selbst
    /// zurück, und ``loslassen()`` hängt an diesem Zurücksetzen statt an `onEnded`.
    @GestureState private var druck = false
    /// Wie weit der Finger seit dem Aufsetzen gewandert ist – aus demselben Grund eine
    /// Gestenlage: ein abgebrochener Zug muss bei null enden und nicht beim letzten Wert.
    @GestureState private var schub = Entenplatz.Punkt.ursprung
    @State private var gehalten = false
    @State private var haltenAufgabe: Task<Void, Never>?
    /// Das Blatt soll aufgehen, sobald der Finger weg ist – nicht darunter hervor.
    @State private var oeffnenNachLoslassen = false

    /// Seit die Schwelle überschritten ist: die Ente folgt dem Finger.
    @State private var zieht = false
    /// Der letzte Zug, der ein Zug war. **Gebraucht beim Loslassen, und dann ist ``schub``
    /// schon auf null zurückgesetzt** – das Einrasten rechnet darum mit diesem Wert.
    @State private var letzterSchub = Entenplatz.Punkt.ursprung
    /// Die Fläche, über der die Ente schwebt. Sie ändert sich beim Drehen und am geteilten
    /// Fenster des iPads, und mit ihr der Versatz jeder Stelle.
    @State private var flaeche = Entenplatz.Flaeche.unbekannt

    /// So lange muss die Ente gedrückt sein, bis Alfred zuhört.
    private static let haltenMs: UInt64 = 350

    private var stelle: Entenplatz.Stelle { Entenplatz.gelesen(gemerkt) }

    /// Der Versatz gegenüber der Ecke unten rechts, aus der Stelle und – während des Zuges –
    /// aus dem Finger. Begrenzt wird im Kern, darum liegt die Ente nie halb draußen.
    ///
    /// **Gezeichnet wird nach ``letzterSchub`` und nicht nach ``schub``.** Eine Gestenlage
    /// springt beim Ende oder Abbruch auf null zurück, und zwar in einem eigenen Durchgang:
    /// die Ente stünde für ein Bild wieder dort, wo sie hergekommen ist, und erst danach an
    /// ihrer neuen Stelle. Der gemerkte Zug hält genau einen Durchgang lang stand - bis
    /// ``loslassen()`` Stelle und Zug zusammen setzt.
    private var versatz: Entenplatz.Punkt {
        Entenplatz.versatz(stelle, zug: zieht ? letzterSchub : .ursprung, in: flaeche)
    }

    var body: some View {
        // **Ein `GeometryReader`, und er misst die Seite und nicht die Ente.** Als Überlagerung
        // bekommt diese Ansicht die Größe der Seite angeboten; nur deshalb weiß das Einrasten,
        // wie weit es nach links und nach oben geht. Gezeichnet wird weiterhin in der Ecke unten
        // rechts - und damit innerhalb der Seite, also nie hinter der Leiste der fünf Bereiche
        // (`HandRahmen.swift`) und nie unter der Uhr der Wandanzeige.
        GeometryReader { raum in
            entenfeld
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .onChange(of: raum.size, initial: true) { _, neu in
                    flaeche = Entenplatz.Flaeche(breite: neu.width, hoehe: neu.height)
                }
        }
        .task { bereit = try? await haus.api.alfredZustand().bereit }
        .onChange(of: druck) { _, liegt in
            if liegt { druecken() } else { loslassen() }
        }
        .onChange(of: schub) { _, neu in
            // Das Zurücksetzen der Geste ist kein Zug - sonst stünde beim Loslassen null da,
            // und die Ente rastete wieder dort ein, wo sie hergekommen ist.
            guard neu != .ursprung else { return }
            letzterSchub = neu
            if !zieht, Entenplatz.istZug(neu) { beginneZiehen() }
        }
        // Geht das Blatt auf, waehrend noch aufgenommen wird, hoert hier niemand mehr zu.
        .onChange(of: zeigtAlfred) { _, auf in
            if auf { hoerer.brich() }
        }
        // Einmal rütteln, wenn aus dem Halten ein Verschieben wird: das ist der Augenblick, in
        // dem das Mikrofon ausgeht und die Ente dem Finger gehört, und man sieht dabei auf die
        // Ente und nicht auf den Zettel.
        .sensoryFeedback(trigger: zieht) { _, verschiebt in verschiebt ? .impact : nil }
        .sheet(isPresented: $zeigtAlfred) {
            Alfredblatt(starttext: gefragt)
        }
        .alert(
            Alfred.Texte.name,
            isPresented: Binding(
                get: { hoerer.meldung != nil && !zeigtAlfred },
                set: { if !$0 { hoerer.loescheMeldung() } })
        ) {
            Button("Verstanden", role: .cancel) { hoerer.loescheMeldung() }
        } message: {
            Text(hoerer.meldung ?? "")
        }
    }

    /// Die Ente mit allem, was an ihr hängt, an ihrer Stelle.
    private var entenfeld: some View {
        ente
            .overlay(alignment: zeichenEcke) { hoerzeichen }
            .overlay(alignment: zettelEcke) { mitschrift }
            .padding(Entenplatz.rand)
            .offset(x: versatz.x, y: versatz.y)
    }

    /// Ob die Ente an der linken Kante klebt. **Sie entscheidet, wohin alles ausweicht**, was
    /// an ihr hängt: ein Zettel, der an der linken Kante nach links aus ihr herauswächst, steht
    /// zur Hälfte neben dem Schirm.
    private var klebtLinks: Bool { stelle.seite == .links }
    private var klebtOben: Bool { stelle.hoehe == .oben }

    private var zettelEcke: Alignment {
        Alignment(
            horizontal: klebtLinks ? .leading : .trailing,
            vertical: klebtOben ? .top : .bottom)
    }

    private var zeichenEcke: Alignment {
        Alignment(horizontal: klebtLinks ? .leading : .trailing, vertical: .top)
    }

    private var ente: some View {
        Image("Ente")
            .resizable()
            .scaledToFit()
            .frame(width: Entenplatz.entengroesse, height: Entenplatz.entengroesse)
            .padding(Entenplatz.ring)
            .background(Circle().fill(Farbe.papier))
            // Beim Verschieben hebt sich die Ente von der Seite ab: ein größerer Schatten ist
            // das, was in dieser Anwendung „in der Hand“ heißt.
            .shadow(color: .black.opacity(zieht ? 0.5 : 0.35), radius: zieht ? 16 : 10, y: 3)
            .scaleEffect(hoerer.lage == .hoert || zieht ? 1.12 : 1)
            .animation(.easeInOut(duration: 0.18), value: hoerer.lage)
            .animation(.easeInOut(duration: 0.18), value: zieht)
            .contentShape(Circle())
            .gesture(griff)
            // **Ein Zug ist fuer VoiceOver keine Handlung.** Vorher war das ein echter
            // `Button`, den ein Doppeltippen ausloeste; jetzt traegt ein Bild eine Geste, und
            // die wird der Bedienungshilfe nicht angeboten. Ohne diese drei Zeilen las
            // VoiceOver „Alfred fragen, Bild“ und ein Doppeltippen tat nichts.
            .accessibilityElement()
            .accessibilityLabel(Alfred.Texte.ansprechen)
            // **Und das Verschieben ist erst recht keine.** Es hängt an einer Strecke, die mit
            // eingeschaltetem VoiceOver niemand zurücklegt. Darum steht es als Handlung da -
            // ein Schritt weiter am Rand entlang, und einer zurück an die Vorgabe. Der Wert
            // sagt, wo die Ente gerade steht; ohne ihn wäre die Handlung ein Blindflug.
            .accessibilityValue(Alfred.Texte.enteStelle(stelle.name))
            .accessibilityHint(Alfred.Texte.enteHinweis)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                gefragt = nil
                zeigtAlfred = true
            }
            .accessibilityAction(named: Text(Alfred.Texte.enteVerschieben)) {
                setze(Entenplatz.naechste(nach: stelle))
            }
            .accessibilityAction(named: Text(Alfred.Texte.enteZurueck)) {
                setze(Entenplatz.vorgabe)
            }
    }

    /// Was bisher verstanden wurde, neben der Ente, solange der Finger liegt.
    ///
    /// **Ohne das wäre „Texterkennung“ ein Versprechen ohne Beleg.** Man hält die Ente, redet
    /// in ein Telefon, das nichts anzeigt, und erfährt erst nach dem Loslassen, ob überhaupt
    /// etwas angekommen ist. Hier stehen die Worte, während sie kommen – und wer sieht, dass
    /// nichts kommt, lässt los und tippt.
    @ViewBuilder private var mitschrift: some View {
        if hoerer.laeuft {
            VStack(alignment: .leading, spacing: 4) {
                Text(hoerer.lage == .wartet ? Alfred.Texte.sprachWartet : Alfred.Texte.haltenLaeuft)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                if !hoerer.text.isEmpty {
                    Text(hoerer.text)
                        .font(Schrift.text)
                        .foregroundStyle(Farbe.text1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: 260, alignment: .leading)
            .background(
                Farbe.flaeche2, in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Farbe.amber.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            // Von der Ente weg, nicht über sie: er wächst aus der Kante heraus, an der sie
            // klebt, und bei einer Ente oben nach unten statt nach oben. Stünde er immer links
            // über ihr, läge er an der linken Kante zur Hälfte neben dem Schirm und an der
            // oberen Kante über ihr hinaus.
            .offset(y: klebtOben ? 62 : -62)
            .fixedSize()
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// Ein Punkt, solange zugehört wird – damit man es auch sieht, wenn das Blatt noch zu ist.
    @ViewBuilder private var hoerzeichen: some View {
        if hoerer.laeuft {
            Circle()
                .fill(Farbe.alarm)
                .frame(width: 11, height: 11)
                .overlay(Circle().strokeBorder(Farbe.grund, lineWidth: 2))
                .offset(x: klebtLinks ? -2 : 2, y: -2)
        }
    }

    /// **Ein `DragGesture` mit Abstand null und keine `LongPressGesture`.** Die lange Geste
    /// meldet ihren Beginn, aber kein Loslassen – gebraucht wird genau das Loslassen. Mit
    /// einem Zug ab Null bekommt man beides: `onChanged` beim Aufsetzen, `onEnded` beim
    /// Abheben, auch wenn der Finger dabei ein Stück wandert.
    ///
    /// **Zwei Gestenlagen an einer Geste**, weil zwei verschiedene Fragen daran hängen: *ob* ein
    /// Finger liegt – daran hängen die Uhr fürs Halten und das Aufräumen – und *wie weit* er
    /// gewandert ist, woran das Verschieben hängt. Eine einzige Lage für beides würde bei jedem
    /// Millimeter die Uhr neu stellen.
    private var griff: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($druck) { _, liegt, _ in liegt = true }
            .updating($schub) { wert, strecke, _ in
                strecke = Entenplatz.Punkt(
                    x: wert.translation.width, y: wert.translation.height)
            }
    }

    /// Der Finger ist aufgesetzt: die Uhr fürs Halten läuft.
    private func druecken() {
        gehalten = false
        zieht = false
        letzterSchub = .ursprung
        oeffnenNachLoslassen = false
        haltenAufgabe?.cancel()
        haltenAufgabe = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(Self.haltenMs)))
            guard !Task.isCancelled else { return }
            gehalten = true
            await hoeren()
        }
    }

    /// Aus dem Druck ist ein Zug geworden.
    ///
    /// **Hier wird die Aufnahme weggeworfen und nicht abgeschickt.** Das ist die harte Bedingung
    /// dieser Geste: ein Zug beginnt oft erst nach den 350 Millisekunden, und dann läuft das
    /// Mikrofon schon. ``Sprachhoerer/brich()`` löscht den Rückruf mit, also geht keine Frage an
    /// den Dienst; ``Sprachhoerer/beende()`` täte das Gegenteil. Wer die Ente nur umsetzt, hat
    /// nichts gefragt.
    private func beginneZiehen() {
        zieht = true
        // Die Uhr abbestellen: wer zieht, will nicht sprechen. Und ``hoeren()`` fragt gleich
        // noch einmal nach, denn die Uhr kann mitten in einem `await` stehen.
        haltenAufgabe?.cancel()
        haltenAufgabe = nil
        gehalten = false
        // Das Blatt soll auch nicht aufgehen, nur weil die Ente unterwegs ist.
        oeffnenNachLoslassen = false
        // **Nur die Aufnahme dieser Geste, nicht die schon losgelassene.** `laeuft` umfasst
        // auch `.wartet` - die Lage nach dem Loslassen, in der das Mikrofon aus ist und nur
        // noch das Endergebnis aussteht. Wer spricht, loslaesst und dann in diesem Fenster
        // anfaengt zu verschieben, hat die Frage mit dem Loslassen schon abgeschickt; sie hier
        // abzubrechen hiesse, sie stumm wegzuwerfen - `brich()` sagt bewusst nichts. Die Zusage
        // des Verschiebens ist, dass dabei nichts heimlich aufgenommen wird, und in `.wartet`
        // nimmt niemand mehr auf.
        if hoerer.lage == .startet || hoerer.lage == .hoert { hoerer.brich() }
    }

    /// Der Finger ist weg – losgelassen **oder** die Geste wurde abgebrochen. Beide Wege
    /// kommen hier an, und beide müssen aufräumen.
    private func loslassen() {
        haltenAufgabe?.cancel()
        haltenAufgabe = nil
        if zieht {
            // Eingerastet statt frei stehen gelassen: welche Stelle das ist, rechnet der Kern.
            // **Stelle und Zug in einem Zug**, denn beide bewegen dasselbe Bild: zuerst die
            // Stelle und dann den Zug zu löschen, hiesse die Ente zweimal zu versetzen.
            let neu = Entenplatz.einrasten(von: stelle, zug: letzterSchub, in: flaeche)
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                gemerkt = Entenplatz.gemerkt(neu)
                letzterSchub = .ursprung
                zieht = false
            }
        } else if gehalten {
            hoerer.beende()
            if oeffnenNachLoslassen {
                gefragt = nil
                zeigtAlfred = true
            }
        } else {
            gefragt = nil
            zeigtAlfred = true
        }
        zieht = false
        gehalten = false
        oeffnenNachLoslassen = false
        letzterSchub = .ursprung
    }

    /// Die Ente an eine Stelle setzen und sie sich merken. Mit Schwung, damit man das Einrasten
    /// sieht und die Ente nicht einfach woanders ist.
    private func setze(_ neu: Entenplatz.Stelle) {
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            gemerkt = Entenplatz.gemerkt(neu)
        }
    }

    private func hoeren() async {
        // **Erst fragen, ob jemand zuhoeren kann.** Ohne eingerichtetes Sprachmodell
        // aufzunehmen hiesse: das Mikrofon einschalten, den Satz erkennen und ihn dann
        // wegwerfen.
        //
        // **Und notfalls jetzt fragen.** Der Zustand wird beim Erscheinen geholt; scheitert
        // dieser eine Aufruf - der Dienst im Haus antwortet beim Start regelmaessig noch
        // nicht -, bliebe die Spracheingabe sonst fuer den ganzen Programmlauf stumm, ohne
        // dass irgendwo ein Grund stuende.
        if bereit == nil { bereit = try? await haus.api.alfredZustand().bereit }
        // **Und zwischen Frage und Antwort kann der Zug begonnen haben.** Ein abgebrochenes
        // `Task` kommt hier trotzdem an: der Abbruch laesst den Aufruf scheitern, und
        // `try?` macht daraus ein `nil`, das keinen Riegel ist. Der Zug hat Vorrang, immer -
        // sonst ginge das Mikrofon an, waehrend die Ente schon unterwegs ist.
        guard !zieht else { return }
        guard bereit != false else {
            // Das Blatt geht auf, sobald der Finger weg ist, und sagt dort, woran es liegt.
            oeffnenNachLoslassen = true
            return
        }
        await hoerer.beginne { gesagt in
            guard let gesagt else { return }
            gefragt = gesagt
            zeigtAlfred = true
        }
    }
}
