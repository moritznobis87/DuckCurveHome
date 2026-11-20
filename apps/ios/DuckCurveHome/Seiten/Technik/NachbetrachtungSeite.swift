import DuckCurveKit
import SwiftUI

/// Fahrplan · Rückblick: ein Ortstag in Euro – versprochen, gehalten, wirklich.
///
/// **Drei Zahlen, die nicht dasselbe sind.** Was der erste Plan des Tages versprochen hat, was
/// der Plan am Ende des Tages gesagt hätte, und was wirklich bezahlt wurde. Die Lücke zwischen
/// der ersten und der dritten ist der Prognosefehler; die zwischen der zweiten und der dritten
/// ist das, was die Anlage nicht umgesetzt hat.
///
/// **Von oben nach unten vom Satz zur Viertelstunde** (`Nachbetrachtung.tsx:26-28`). Zuerst der
/// Satz über den Tag und die Kostentreppe, die ihn zerlegt. Dann der Tagesvergleich: wann jede
/// Linie Strom zog und wo das Geld auseinanderlief. Zuletzt die Zahlen als Tabelle, für den, der
/// nachrechnen will.
///
/// **Gerechnet und beurteilt wird im Dienst** (`Nachbetrachtung.tsx:30-31`). Hier wird nichts
/// bewertet; jede Zahl und jeder Satz kommt fertig an. Was aus der Antwort ein Bild macht,
/// rechnet ``Nachbetrachtungsbild``.
///
/// **Diese Seite rechnet einen Vergleichslauf und braucht darum Sekunden** - und deshalb steht
/// hier der Tagesabgleich: solange ein anderer Tag lädt, steht der alte nicht mehr da.
struct NachbetrachtungSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    @State private var tag: String = ""
    @State private var rueckblick: NachbetrachtungOut?
    @State private var fehler: ApiFehler?
    @State private var laedt = false

    private var schmal: Bool { breite == .compact }

    /// Die Antwort, aber nur, wenn sie zu der Tagwahl gehört.
    ///
    /// **Der Tagesabgleich, und er ist kein Feinschliff** (`Nachbetrachtung.tsx:79-81`):
    /// „Solange ein anderer Tag geladen wird, steht der alte nicht mehr da: seine Zahlen unter
    /// dem neuen Datum wären falsch, auch für zwei Sekunden.“ Hier sind es mehr als zwei - die
    /// Seite rechnet den Tag nach -, und vorher blieb die alte Antwort unter der neuen Tagwahl
    /// stehen.
    private var daten: NachbetrachtungOut? {
        guard let r = rueckblick, r.day == tag else { return nil }
        return r
    }

    var body: some View {
        Seite {
            kopfkarte
            if let d = daten, (d.nVerglichen ?? 0) > 0 {
                vergleichskarte(d)
                zahlenkarte(d)
            }
            hinweiskarte
            if let d = daten, !d.methodeDe.isEmpty {
                Methode(
                    d.methodeDe.map(Optional.init), kurz: Nachbetrachtungsworte.methodeKurz,
                    titel: Nachbetrachtungsworte.methodeTitel)
            }
        }
        .task(id: tag) { await lade() }
        .onAppear { if tag.isEmpty { tag = Tag.plus(haus.heute, -1) } }
    }

    // MARK: - Karte 1: Was hat der Tag gekostet?

    private var kopfkarte: some View {
        Karte(kicker: Nachbetrachtungsworte.kopfTitel, beiwerk: kopfzahl) {
            bedienzeile
            fehlerzeile
            if laedt, daten == nil {
                Text(Nachbetrachtungsworte.laedtSatz)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let d = daten {
                kopfinhalt(d)
            }
        }
    }

    /// „88 von 96 Viertelstunden verglichen · erster Fahrplan vom Sa., 07.11. 00:07“.
    ///
    /// **Am Telefon vollständig und umbrechend** (`handy.css:185`: „der rechte Teil auf eigener
    /// Zeile, vollständig“) - abgeschnitten wäre der zweite Teil verschwiegen, und der sagt, wie
    /// alt das Versprechen ist.
    private var kopfzahl: AnyView? {
        guard let d = daten else { return nil }
        return AnyView(
            Text(Nachbetrachtungsbild.kopfzahl(d))
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true))
    }

    /// Die Bedienzeile: ‹, ein Datumsfeld, ›, der lange Tag - und rechts der Weg in die
    /// Wiedergabe.
    ///
    /// **Das Datumsfeld ist der Punkt** (`Nachbetrachtung.tsx:107`, `max={heute}`): „Damit ist
    /// jeder Tag in einem Griff erreichbar.“ Vorher ließ sich nur Tag für Tag blättern, und ein
    /// Tag vom letzten Februar war dreihundert Tipper weit weg. Vorbild im Haus:
    /// `Seiten/Technik/WiedergabeSeite.swift:124-139`.
    @ViewBuilder private var bedienzeile: some View {
        if schmal {
            VStack(alignment: .leading, spacing: 8) {
                tagzeile
                wiedergabeverweis
            }
        } else {
            HStack(alignment: .center, spacing: 8) {
                tagzeile
                Spacer(minLength: 12)
                wiedergabeverweis
            }
        }
    }

    private var tagzeile: some View {
        HStack(spacing: 8) {
            blaetterknopf("‹", um: -1)
            DatePicker("", selection: datumswahl, in: ...obergrenze, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Farbe.amber)
            blaetterknopf("›", um: 1)
            Text(Tag.lang(tag))
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Ein Tag zurück oder vor. Vorwärts endet heute: einen Tag, der nicht vorbei ist, gibt es
    /// nicht nachzurechnen (`Nachbetrachtung.tsx:108`, `disabled={tag >= heute}`).
    private func blaetterknopf(_ zeichen: String, um tage: Int) -> some View {
        let moeglich = tage < 0 || tag < haus.heute
        return Button {
            tag = Tag.plus(tag, tage)
        } label: {
            Text(zeichen)
                .font(Schrift.karte)
                .frame(width: 30, height: 30)
                .foregroundStyle(moeglich ? Farbe.text2 : Farbe.text3)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(moeglich ? Farbe.linie1 : Farbe.linie2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!moeglich)
        .accessibilityLabel(tage < 0 ? "Tag zurück" : "Tag vor")
    }

    /// **Ein Verweis ist im Haus ein Text in Bernstein mit „›“** und keine gepunktete
    /// Unterstreichung (`Gestalt/Karte.swift:254-257`: „Ein Pfeil sagt, dass die Zeile irgendwohin
    /// fuehrt“). SwiftUI könnte `.underline(pattern: .dot)`, aber dann führte diese Seite ihre
    /// Verweise anders als die übrigen dreißig.
    private var wiedergabeverweis: some View {
        Button {
            wegweiser.gehe("/waerme/wiedergabe?day=\(tag)")
        } label: {
            Text("\(Nachbetrachtungsworte.zurWiedergabe) ›")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.amber)
        }
        .buttonStyle(.plain)
    }

    /// **Der Fehler steht im Kopf der Karte und nicht an ihrer Stelle**
    /// (`Nachbetrachtung.tsx:117`): die Tagwahl bleibt bedienbar, und wer einen anderen Tag
    /// nimmt, kommt aus dem Fehler heraus, ohne die Seite zu verlassen.
    ///
    /// **Der Knopf „Erneut“ bleibt**, obwohl die Vorlage dort nur einen Absatz hat: im Browser
    /// lädt man eine Seite neu, in der App gibt es dafür keine Geste.
    @ViewBuilder private var fehlerzeile: some View {
        if let fehler {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(fehler.rat)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.alarm)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Erneut") { Task { await lade() } }
                    .font(Schrift.klein)
                    .buttonStyle(.plain)
                    .foregroundStyle(Farbe.amber)
            }
        }
    }

    /// Zwei Spalten: links das Urteil und die Sätze, rechts die Treppe.
    ///
    /// Einspaltig am Telefon (`globals.css:685-686`: `nb-kopf` ist schon ab 1000 px einspaltig,
    /// und die rechte Spalte braucht 340 Punkte, die dort nicht da sind).
    @ViewBuilder private func kopfinhalt(_ d: NachbetrachtungOut) -> some View {
        if schmal {
            VStack(alignment: .leading, spacing: 22) {
                urteilsspalte(d)
                Kostentreppe(daten: d)
            }
        } else {
            HStack(alignment: .top, spacing: 44) {
                urteilsspalte(d)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Kostentreppe(daten: d)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func urteilsspalte(_ d: NachbetrachtungOut) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Das Urteil in der Größe eines Urteils (`globals.css:650`:
            // `clamp(17px, 2vw, 22px)`), nicht in der einer Fußnote.
            if let satz = d.satzDe, !satz.isEmpty {
                Text(satz)
                    .font(Schrift.sans(20, relativeTo: .title3))
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            kopfsaetze(d)
            ohnePreisblick(d)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Je Abstand mit Betrag und Satz ein Eintrag: der Name als Kicker, darunter der Satz.
    ///
    /// **Ohne Betrag und ohne die rohen Schlüssel.** Hier stand einmal `"\(a.von) → \(a.nach)"`,
    /// also „letzter → wirklich“; die Vorlage zeigt diese Schlüssel nirgends, und der Betrag
    /// steht in der Treppe daneben, wo er eine Länge hat.
    @ViewBuilder private func kopfsaetze(_ d: NachbetrachtungOut) -> some View {
        let saetze = Nachbetrachtungsbild.kopfsaetze(d)
        if !saetze.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(saetze) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Kicker(wort: s.wort)
                        Text(s.satz)
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 18)
        }
    }

    /// Der Vergleich ohne Preisblick: gerechnet auf der Kostenseite, hier nur genannt
    /// (`Nachbetrachtung.tsx:134-143`).
    ///
    /// Der Verweis setzt den Zeitraum des Bereichs mit, denn in der App reist er nicht in der
    /// Adresse: `?period=day&anchor={tag}` der Vorlage ist hier ``Wegweiser/setzeZeitraum(_:)``.
    @ViewBuilder private func ohnePreisblick(_ d: NachbetrachtungOut) -> some View {
        if let satz = d.verschiebenDe, !satz.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Divider().overlay(Farbe.linie1)
                VStack(alignment: .leading, spacing: 2) {
                    Kicker(wort: Nachbetrachtungsworte.ohnePreisblick)
                    Text(satz)
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        // **Erst wechseln, dann stellen, und die Reihenfolge ist die Sache
                        // selbst.** ``Wegweiser/setzeZeitraum(_:)`` schreibt nach
                        // `zeitraeume[bereich.schluessel]`, und `bereich` rechnet der Wegweiser
                        // aus `weg` (`App/Navigation.swift:27`, `:84-86`). Umgekehrt landete der
                        // Tag unter `.technik` - dort, wo diese Seite steht -, die Kostenseite
                        // fiel auf ihre Monatsvorgabe (`:77`), und der Technikbereich bekam
                        // still einen Anker, den niemand gestellt hat.
                        wegweiser.gehe("/geld")
                        wegweiser.setzeZeitraum(Zeitraum(spanne: .tag, anker: tag))
                    } label: {
                        Text(Nachbetrachtungsworte.zurRechnung)
                            .font(Schrift.klein)
                            .foregroundStyle(Farbe.amber)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.top, 12)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Karte 2: Der Tag, Linie für Linie

    private func vergleichskarte(_ d: NachbetrachtungOut) -> some View {
        Karte(
            kicker: Nachbetrachtungsworte.vergleichTitel,
            beiwerk: AnyView(
                Text(Nachbetrachtungsworte.vergleichDazu)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true))
        ) {
            Tagesvergleichsbild(daten: d)
        }
    }

    // MARK: - Karte 3: Die Linien in Zahlen

    private func zahlenkarte(_ d: NachbetrachtungOut) -> some View {
        let t = Nachbetrachtungsbild.zahlentabelle(d)
        return Karte(
            kicker: Nachbetrachtungsworte.tabelleTitel,
            beiwerk: AnyView(
                Text(Nachbetrachtungsworte.tabelleDazu(nVerglichen: d.nVerglichen))
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true))
        ) {
            // **„Kosten“ ist die Spalte, die am Telefon dasteht.** Die Vorlage macht aus jeder
            // Zeile einen Block mit Name und Kosten vorn (`handy.css:331-337`); ``Tabelle``
            // schaltet stattdessen eine Spalte um (`Seiten/Bericht.swift:151-156`). Die
            // Abweichung ist bewusst und wurde schon für den Fahrplan getragen - hier zählt
            // nur, dass die hervorgehobene Zahl der Vorlage die zuerst gezeigte ist.
            Tabelle(
                zeilennamen: t.zeilennamen,
                spalten: t.spalten.map { Tabelle.Spalte(name: $0.name, zellen: $0.zellen) },
                immerSichtbar: 1, engeZellen: true)
            if let satz = t.standbySatz {
                Text(satz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            fehlendeLinien(t)
        }
    }

    /// Die Linien, die es nicht gibt, mit ihrem Grund (`Nachbetrachtung.tsx:222-231`).
    ///
    /// Sie stehen unter der Tabelle und nicht in ihr: eine Zeile ohne Zahlen in einer Tabelle
    /// aus Zahlen wäre eine Zeile aus Strichen.
    @ViewBuilder private func fehlendeLinien(_ t: Nachbetrachtungsbild.Zahlentabelle) -> some View {
        if !t.fehlende.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(t.fehlende) { f in
                    VStack(alignment: .leading, spacing: 2) {
                        Kicker(wort: f.wort)
                        Text(f.grund)
                            .font(Schrift.winzig)
                            .foregroundStyle(Farbe.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Karte 4: Zu diesem Tag

    /// **Offen, nicht zugeklappt** (`Nachbetrachtung.tsx:235`): „Was für diesen Tag gilt, bleibt
    /// offen stehen; zugeklappt wäre es verschwiegen.“ Dieselbe Regel steht in
    /// `components/ui/Methode.tsx:11-13` und ist in der App für die Wirkungsseite schon so
    /// umgesetzt (`FahrplanSeiten.swift:366-367`).
    ///
    /// Die Gründe fehlender Linien fehlen hier: sie stehen schon unter der Tabelle - gefiltert
    /// im Kern (``Nachbetrachtungsbild/tageshinweise(_:)``).
    @ViewBuilder private var hinweiskarte: some View {
        if let d = daten {
            let hinweise = Nachbetrachtungsbild.tageshinweise(d)
            if !hinweise.isEmpty {
                Karte(kicker: Nachbetrachtungsworte.hinweiseTitel) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(hinweise, id: \.self) { satz in
                            HStack(alignment: .top, spacing: 8) {
                                Text("·").font(Schrift.klein).foregroundStyle(Farbe.text3)
                                Text(satz)
                                    .font(Schrift.klein)
                                    .foregroundStyle(Farbe.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tagwahl und Laden

    private var obergrenze: Date {
        Tag.date(haus.heute) ?? haus.jetzt
    }

    private var datumswahl: Binding<Date> {
        Binding(
            get: { Tag.date(tag) ?? obergrenze },
            set: { neu in
                let gewaehlt = Tag.iso(neu)
                if gewaehlt != tag, Tag.istTag(gewaehlt) { tag = gewaehlt }
            })
    }

    private func lade() async {
        guard Tag.istTag(tag) else { return }
        laedt = true
        do {
            rueckblick = try await haus.api.nachbetrachtung(tag: tag)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
            rueckblick = nil
        } catch {
            fehler = .netz(error.localizedDescription)
            rueckblick = nil
        }
        laedt = false
    }
}
