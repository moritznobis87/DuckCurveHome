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
                Text(Alfred.Texte.kiMarke)
                    .font(Schrift.kicker)
                    .foregroundStyle(Farbe.kicker)
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
            Text(Alfred.Texte.vorschlagTitel)
                .font(Schrift.kicker)
                .foregroundStyle(Farbe.kicker)
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
    /// noch besser als ein Blatt, auf dem „Ich denke nach ..." stehen bleibt. Genau das stand
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
        // kommt ein leeres `Data` zurueck, und die Rechnung waere „nicht lesbar".
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

/// Der Knopf, der Alfred ruft: das Maskottchen, unten rechts über der Seite.
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
/// **Tippen öffnet, Halten spricht.** Dieselbe Geste wie an der Wand: 350 Millisekunden
/// gedrückt, dann hört Alfred zu, solange der Finger liegen bleibt. Kürzer ist ein Tippen und
/// öffnet nur das Blatt. Länger als ein Tippen, kürzer als das lange Drücken des Systems.
struct Entenknopf: View {
    @Environment(Hauszustand.self) private var haus

    @State private var zeigtAlfred = false
    @State private var gefragt: String?
    /// Ob ein Sprachmodell eingerichtet ist. `nil` heisst: noch nicht beantwortet.
    @State private var bereit: Bool?
    @State private var hoerer = Sprachhoerer()
    /// **Der Finger liegt – als `@GestureState` und nicht als `@State`.** Eine Geste kann
    /// abgebrochen werden, und dann kommt kein `onEnded`: iOS storniert die Berührungen,
    /// sobald ein Systemdialog über dem Fenster liegt – und genau das tut der erste Griff
    /// nach dem Mikrofon. Ein `@State`, das nur `onEnded` zurücksetzt, bliebe danach auf
    /// „gedrückt" stehen; die Ente reagierte beim nächsten Mal nicht, und das Mikrofon liefe
    /// weiter, weil niemand das Ende meldet. `@GestureState` setzt sich beim Abbruch selbst
    /// zurück, und ``loslassen()`` hängt an diesem Zurücksetzen statt an `onEnded`.
    @GestureState private var druck = false
    @State private var gehalten = false
    @State private var haltenAufgabe: Task<Void, Never>?
    /// Das Blatt soll aufgehen, sobald der Finger weg ist – nicht darunter hervor.
    @State private var oeffnenNachLoslassen = false

    /// So lange muss die Ente gedrückt sein, bis Alfred zuhört.
    private static let haltenMs: UInt64 = 350

    var body: some View {
        ente
            .overlay(alignment: .topTrailing) { hoerzeichen }
            .overlay(alignment: .bottomTrailing) { mitschrift }
            .padding(20)
            .task { bereit = try? await haus.api.alfredZustand().bereit }
            .onChange(of: druck) { _, liegt in
                if liegt { druecken() } else { loslassen() }
            }
            // Geht das Blatt auf, waehrend noch aufgenommen wird, hoert hier niemand mehr zu.
            .onChange(of: zeigtAlfred) { _, auf in
                if auf { hoerer.brich() }
            }
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

    private var ente: some View {
        Image("Ente")
            .resizable()
            .scaledToFit()
            .frame(width: 38, height: 38)
            .padding(7)
            .background(Circle().fill(Farbe.papier))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
            .scaleEffect(hoerer.lage == .hoert ? 1.12 : 1)
            .animation(.easeInOut(duration: 0.18), value: hoerer.lage)
            .contentShape(Circle())
            .gesture(griff)
            // **Ein Zug ist fuer VoiceOver keine Handlung.** Vorher war das ein echter
            // `Button`, den ein Doppeltippen ausloeste; jetzt traegt ein Bild eine Geste, und
            // die wird der Bedienungshilfe nicht angeboten. Ohne diese drei Zeilen las
            // VoiceOver „Alfred fragen, Bild" und ein Doppeltippen tat nichts.
            .accessibilityElement()
            .accessibilityLabel(Alfred.Texte.ansprechen)
            .accessibilityHint(Alfred.Texte.haltenHinweis)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                gefragt = nil
                zeigtAlfred = true
            }
    }

    /// Was bisher verstanden wurde, über der Ente, solange der Finger liegt.
    ///
    /// **Ohne das wäre „Texterkennung" ein Versprechen ohne Beleg.** Man hält die Ente, redet
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
            // Über der Ente und nach links aus ihr heraus: sie sitzt am rechten Rand, und
            // ein Kasten, der dort beginnt, stünde zur Hälfte neben dem Schirm.
            .offset(y: -62)
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
                .offset(x: 2, y: -2)
        }
    }

    /// **Ein `DragGesture` mit Abstand null und keine `LongPressGesture`.** Die lange Geste
    /// meldet ihren Beginn, aber kein Loslassen – gebraucht wird genau das Loslassen. Mit
    /// einem Zug ab Null bekommt man beides: `onChanged` beim Aufsetzen, `onEnded` beim
    /// Abheben, auch wenn der Finger dabei ein Stück wandert.
    private var griff: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($druck) { _, liegt, _ in liegt = true }
    }

    /// Der Finger ist aufgesetzt: die Uhr fürs Halten läuft.
    private func druecken() {
        gehalten = false
        oeffnenNachLoslassen = false
        haltenAufgabe?.cancel()
        haltenAufgabe = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(Self.haltenMs)))
            guard !Task.isCancelled else { return }
            gehalten = true
            await hoeren()
        }
    }

    /// Der Finger ist weg – losgelassen **oder** die Geste wurde abgebrochen. Beide Wege
    /// kommen hier an, und beide müssen aufräumen.
    private func loslassen() {
        haltenAufgabe?.cancel()
        haltenAufgabe = nil
        if gehalten {
            hoerer.beende()
            if oeffnenNachLoslassen {
                gefragt = nil
                zeigtAlfred = true
            }
        } else {
            gefragt = nil
            zeigtAlfred = true
        }
        gehalten = false
        oeffnenNachLoslassen = false
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
