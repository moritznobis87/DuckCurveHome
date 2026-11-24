import DuckCurveKit
import SwiftUI

/// Annahmen: die Einstellungen, mit denen der Fahrplan rechnet.
///
/// **Was hier steht, ist nicht gemessen, sondern gesetzt.** Pufferfassung, Verlust je Kelvin,
/// Pelletpreis, die angenommene COP-Kurve. Jede dieser Zahlen geht in jede Euro-Zahl der App
/// ein, und keine davon kommt aus einer Messung.
struct AnnahmenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var einstellungen: HemsConfig?
    /// Nur der Ladefehler - der des Abgebens steht in ``abgabefehler``.
    ///
    /// **Zwei Felder und nicht eines, und das war ein Datenverlust.** Hier stand ein `fehler`
    /// fuer beides, gezeichnet als ``Stoerung``-Band ueber dem Formular, mit einem Knopf
    /// „Erneut“ darin. Der Knopf ruft ``lade()``, und ``lade()`` schreibt ``entwuerfe`` und
    /// ``kennlinie`` aus der Antwort des Dienstes neu: wer nach einer abgelehnten Aenderung
    /// „Erneut“ tippte, verlor alles, was er getippt hatte. Die Vorlage setzt den Fehler des
    /// Dienstes in die Knopfzeile (`HeatSettings.tsx:200`) und laesst das Formular stehen; der
    /// Ladefehler ist der einzige, zu dem es ueberhaupt etwas zu wiederholen gibt.
    @State private var fehler: ApiFehler?
    /// Was der Dienst zum Uebernehmen gesagt hat - sein eigener Satz, nicht der der App.
    @State private var abgabefehler: String?
    /// Was in den Feldern steht, als Text - nicht als Zahl.
    ///
    /// **Warum Text und nicht `Double?`.** Wer „0,“ getippt hat, ist mitten im Tippen; eine
    /// Zahl daraus zu machen hiesse, die Null zu uebernehmen und den Rest zu verwerfen. Der
    /// Entwurf bleibt roh, bis er abgegeben wird (`Annahmenfelder.abgabe`).
    @State private var entwuerfe: [String: String] = [:]
    @State private var kennlinie = ""
    @State private var schickt = false
    @State private var uebernommen = false
    @State private var ansicht = "formular"
    /// In welchem der vierzehn Felder getippt wird - der Schluessel des Feldes, sonst `nil`.
    ///
    /// **Warum ein Schluessel und nicht ein `Bool`.** Die Vorlage bekommt ihren Fokusring vom
    /// Browser (`globals.css:54`), und bei dreizehn Feldern nebeneinander ist er die einzige
    /// Antwort auf die Frage, in welchem man gerade tippt. SwiftUI zeichnet an einem `TextField`
    /// mit `.textFieldStyle(.plain)` nichts; der Ring muss also selbst dastehen, und dafuer muss
    /// die Seite wissen, welches Feld es ist - ein `Bool` je Feld waeren vierzehn Zustaende, die
    /// einander nicht ausschliessen.
    @FocusState private var fokus: String?

    /// Der Fokuswert der Kennlinienzeile. Kein Feldschluessel, damit er mit keinem kollidiert -
    /// und der Name, unter dem der Dienst die Kurve fuehrt.
    private static let kennlinienfokus = "cop_curve"

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let c = einstellungen {
                if ansicht == "formular" {
                    formular(c)
                } else {
                    werteliste(c)
                }
            } else if fehler == nil {
                ladesatz
            }
        }
        .task { await lade() }
    }

    /// „lädt …“ als bloßer Absatz in `text-3` (`HeatSettings.tsx:158`) - begründet am
    /// ``Annahmenfelder/ladesatz``.
    ///
    /// **Alfred steht darüber, in der großen Stufe.** Dieser Hinweis ist, solange er dasteht,
    /// die ganze Seite (``Ladehinweis/Stufe``) - und damit formgleich mit dem der
    /// `WaermepumpeSeite`. Der Satz und seine Farbe bleiben, was sie waren; den Grad gibt jetzt
    /// die Stufe, wie an jeder anderen Ladeente dieses Hauses.
    private var ladesatz: some View {
        Ladeente(satz: Annahmenfelder.ladesatz, stufe: .gross, farbe: Farbe.text3)
    }

    // MARK: - Das Formular

    /// **Die Seite stellt, sie zeigt nicht nur.** Hier stand eine Leseliste roher Schlüssel
    /// („hw auto off block s 1200“), und darunter der Satz, geändert werde das im Dashboard.
    /// Die Vorlage (`settings/HeatSettings.tsx`) ist ein Formular: dreizehn beschriftete Felder
    /// mit ihren Einheiten und Erklärsätzen, die Kennlinie als Zeile, ein Knopf. Jede Änderung
    /// wirkt sofort und rückwirkend - das steht als Satz darüber, nicht im Kleingedruckten.
    ///
    /// **Ohne Kicker, weil er jetzt im Gerippe steht.** „Lieferschein · Datenblatt · Puffer“ ist
    /// in der Vorlage der Kicker der Hülle (`waerme/annahmen/page.tsx:13`) und nicht die
    /// Überschrift dieser Karte - `HeatSettings.tsx` setzt über das Formular keine. ``Seite``
    /// zeichnet ihn aus ``Bereiche/kicker(fuer:)``, und das Wort bleibt
    /// ``Annahmenfelder/kicker``.
    ///
    /// **Die Karte bleibt, obwohl die Vorlage keine hat** (`HeatSettings.tsx:161`: ein bloßes
    /// `div`). Die App hat für einen Formularblock keinen anderen Behälter, und ``Seite`` setzt
    /// für freistehende Zeilen keinen Grund - dreizehn Felder ohne Fläche hängen im Verlauf.
    /// Was die Vorlage dafür vorgibt, sind ihre Maße, und die stehen benannt im Kern
    /// (``Annahmenfelder/Abmessungen``): die Höchstbreite von 980 Punkten (`page.tsx:14`) ist
    /// der Grund, warum das Formular am iPad nicht über die ganze Wand läuft.
    @ViewBuilder private func formular(_ c: HemsConfig) -> some View {
        inBreite(
            Karte(beiwerk: AnyView(umschalter)) {
                VStack(alignment: .leading, spacing: Annahmenfelder.Abmessungen.blockabstand) {
                    einleitung
                    spalten(c)
                    kennlinienzeile(c)
                    abgabezeile
                }
            })
        inBreite(Verweissatz(stuecke: Annahmenfelder.schlussabsatz))
        inBreite(Methode(Annahmenfelder.methodensaetze.map(Optional.init)))
    }

    /// Die Höchstbreite der Vorlage (`page.tsx:14`, `max-w-[980px]`), links ausgerichtet.
    private func inBreite<Inhalt: View>(_ ansicht: Inhalt) -> some View {
        ansicht.frame(maxWidth: Annahmenfelder.Abmessungen.hoechstbreite, alignment: .leading)
    }

    /// Der Absatz über dem Formular: 15 Punkte, `leading-[1.6]` (`page.tsx:15`).
    ///
    /// Er stand in 13 Punkten da. Das ist die Schriftgröße der Hinweissätze unter den Feldern -
    /// und damit stand der Grund für die ganze Seite so leise wie die Fußnoten darunter.
    private var einleitung: some View {
        Text(Annahmenfelder.einleitung)
            .font(Schrift.sans(15))
            .foregroundStyle(Farbe.text2)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Zwei Spalten an der Wand, eine am Telefon - wie die Vorlage.
    ///
    /// **Nach Größenklasse und nicht nach Platzbedarf.** Hier stand `ViewThatFits` mit
    /// `minWidth: 640`, und das sind zwei verschiedene Fragen: die Vorlage schaltet an einer
    /// Pixelgrenze (`md:grid-cols-2`, also 768), `ViewThatFits` schaltet, sobald zwei Spalten
    /// irgendwie hineinpassen. Zwischen 640 und 768 Punkten zeigte die App deshalb zwei Spalten,
    /// wo die Vorlage eine zeigt. 768 Punkte sind genau die Grenze, an der iOS die
    /// `horizontalSizeClass` dreht (``Annahmenfelder/Abmessungen/spaltenumbruch``) - und
    /// ``Karte`` und ``Ansichtswahl`` fragen dieselbe Klasse.
    @ViewBuilder private func spalten(_ c: HemsConfig) -> some View {
        let gruppen = Annahmenfelder.spalten()
        if breite == .compact {
            spalte(gruppen.flatMap { $0 }, c)
        } else {
            HStack(alignment: .top, spacing: Annahmenfelder.Abmessungen.spaltenabstand) {
                ForEach(Array(gruppen.enumerated()), id: \.offset) { _, felder in
                    spalte(felder, c)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Eine Spalte Feldzeilen, mit Haarlinie zwischen ihnen.
    ///
    /// **Die Linie steht vor jeder Zeile außer der ersten.** Die Vorlage schreibt sie unter jede
    /// Zeile und nimmt sie der letzten wieder weg (`border-b … last:border-b-0`,
    /// `HeatSettings.tsx:66`), und zwar **je Spalte**: bei 7 und 6 Feldern fällt in jeder Spalte
    /// genau eine Linie weg. Vor der Zeile statt dahinter ergibt dasselbe Bild, kommt ohne die
    /// Frage „ist das die letzte“ aus und ist der Weg, den ``Werteliste`` schon geht.
    private func spalte(_ felder: [Annahmenfeld], _ c: HemsConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(felder.enumerated()), id: \.element.id) { stelle, feld in
                if stelle > 0 { Divider().overlay(Farbe.linie1) }
                feldzeile(feld, c)
            }
        }
    }

    /// Eine Feldzeile: links Wort und Hinweis, rechts Feld und Einheit.
    ///
    /// **Der Hinweis steht unter dem Wort und nicht unter der Zeile.** In der Vorlage liegt er
    /// **innerhalb** des linken Spans (`HeatSettings.tsx:67-70`, ein `block`-Span im `flex-1`),
    /// Feld und Einheit stehen rechts daneben auf der Grundlinie der ersten Zeile. Hier lief er
    /// über die ganze Zeilenbreite, also unter dem Eingabefeld hindurch - bei „Aufstellraum des
    /// Puffers“ sind das drei Zeilen quer unter dem Feld, und das Feld sieht dann aus, als
    /// gehörte es zur nächsten Annahme.
    private func feldzeile(_ feld: Annahmenfeld, _ c: HemsConfig) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Annahmenfelder.Abmessungen.wortAbstand) {
            wortblock(feld)
            wertblock(feld, c)
        }
        .padding(.vertical, Annahmenfelder.Abmessungen.zeilenpolster)
    }

    /// Wort und Hinweis, und zugleich der Griff ins Feld.
    ///
    /// **Ein Tippen auf das Wort setzt den Fokus.** Die Vorlage macht die ganze Zeile zu einem
    /// `<label>` (`HeatSettings.tsx:66`); ein Tippen auf „Verbrennungswirkungsgrad“ landet dort
    /// im Feld. In der App waren `Text` und `TextField` unverbunden, und auf 390 Punkten war das
    /// Ziel damit 108 Punkte breit statt der halben Zeile. `.contentShape` ist nötig, weil ein
    /// `VStack` ohne Fläche nur dort berührbar ist, wo Buchstaben stehen.
    private func wortblock(_ feld: Annahmenfeld) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(feld.wort)
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
            if let hinweis = feld.hinweis {
                Text(hinweis)
                    .font(Schrift.sans(12, relativeTo: .caption))
                    .foregroundStyle(Farbe.text3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { fokus = feld.schluessel }
    }

    /// Feld und Einheit, auf der Grundlinie und in festen Breiten.
    ///
    /// Die Einheitenspalte ist 52 Punkte breit (`HeatSettings.tsx:79`), damit „kWh/kg“ und „°C“
    /// untereinander anfangen und nicht an ihren Zahlen kleben.
    private func wertblock(_ feld: Annahmenfeld, _ c: HemsConfig) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: Annahmenfelder.Abmessungen.feldEinheitAbstand
        ) {
            feldeingabe(feld, c)
            Text(feld.einheit)
                .font(Schrift.mono(12, relativeTo: .caption))
                .foregroundStyle(Farbe.text3)
                .frame(width: Annahmenfelder.Abmessungen.einheitenbreite, alignment: .leading)
        }
    }

    /// Das Zahlenfeld: 108 Punkte breit, rechtsbündig, `Farbe.flaeche3` als Grund.
    ///
    /// **Der Grund war `flaeche2`, und das ist am Telefon die Farbe der Karte selbst.** Die
    /// Vorlage setzt `bg-surface-3` (`HeatSettings.tsx:77`), die App nahm `--surface-2`; weil
    /// ``Karte`` am Telefon ebenfalls `flaeche2` ist und dort keinen Rand hat, waren Feld und
    /// Karte dieselbe Farbe - sichtbar war nur die Haarlinie des Randes. Ein Eingabefeld, das
    /// man nicht als solches sieht, lädt nicht zum Tippen ein.
    private func feldeingabe(_ feld: Annahmenfeld, _ c: HemsConfig) -> some View {
        let gebunden = Binding(
            get: { entwuerfe[feld.schluessel] ?? "" },
            set: { entwuerfe[feld.schluessel] = $0 }
        )
        let geaendert = Annahmenfelder.abweichend(
            feld, entwurf: gebunden.wrappedValue, gegen: c)
        return TextField("", text: gebunden)
            .font(Schrift.mono(13))
            .multilineTextAlignment(.trailing)
            .keyboardType(feld.darfNegativ ? .numbersAndPunctuation : .decimalPad)
            .textFieldStyle(.plain)
            .focused($fokus, equals: feld.schluessel)
            .frame(width: Annahmenfelder.Abmessungen.feldbreite)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .modifier(Feldgrund(geaendert: geaendert, imFokus: fokus == feld.schluessel))
            .disabled(!haus.hatVollzugriff)
    }

    /// Die Kennlinie als eine Zeile, mit normalem Satz darüber.
    ///
    /// **Keine Sperrschrift.** Hier stand ein ``Kicker`` - 10,5 Punkte, gesperrt, Großbuchstaben.
    /// Die Vorlage setzt an diese Stelle einen gewöhnlichen Satz in 14 Punkten `text-2`
    /// (`HeatSettings.tsx:176`), und das ist kein Geschmack: ein Kicker beschriftet einen
    /// Abschnitt, dieser Satz beschriftet ein Eingabefeld und steht in derselben Form da wie die
    /// dreizehn Wörter darüber.
    private func kennlinienzeile(_ c: HemsConfig) -> some View {
        let geaendert = Annahmenfelder.kennlinieAbweichend(kennlinie, gegen: c)
        return VStack(alignment: .leading, spacing: 6) {
            Text(Annahmenfelder.kennlinienTitel)
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
            Text(Annahmenfelder.kennlinienErklaerung)
                .font(Schrift.sans(12, relativeTo: .caption))
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: $kennlinie)
                .font(Schrift.mono(13))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($fokus, equals: Self.kennlinienfokus)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .modifier(
                    Feldgrund(geaendert: geaendert, imFokus: fokus == Self.kennlinienfokus))
                .disabled(!haus.hatVollzugriff)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Knopf, Erfolgssatz und Fehler - alle drei in **einer** Zeile (`HeatSettings.tsx:190-201`).
    @ViewBuilder private var abgabezeile: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            knopf
            if let abgabefehler {
                Text(abgabefehler)
                    .font(Schrift.sans(13))
                    .foregroundStyle(Farbe.alarmText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if uebernommen {
                Text(Annahmenfelder.uebernommenSatz)
                    .font(Schrift.sans(13))
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// **Eine Ecke von 2 Punkten und keine Kapsel.** Die Vorlage setzt `rounded-[2px]`
    /// (`HeatSettings.tsx:194`), also ``Marken/radius1``; die App hatte eine `Capsule`, und die
    /// ist in dieser Oberfläche die Form der Zustandsabzeichen, nicht die eines Knopfs.
    ///
    /// **Gedimmt wird auch beim Senden.** Die Vorlage nimmt dafür `opacity: 0.6`
    /// (`HeatSettings.tsx:195`) - solange die Anfrage läuft, ist der Knopf gesperrt, und ein
    /// gesperrter Knopf, der aussieht wie ein offener, wird noch dreimal angetippt.
    private var knopf: some View {
        Button {
            Task { await uebernimm() }
        } label: {
            Text(schickt ? Annahmenfelder.knopfLaeuft : Annahmenfelder.knopf)
                .font(Schrift.sans(13))
                .foregroundStyle(Farbe.petrol)
                .padding(.horizontal, Annahmenfelder.Abmessungen.knopfpolster.quer)
                .padding(.vertical, Annahmenfelder.Abmessungen.knopfpolster.hoch)
                .background(Farbe.amber)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(schickt || !haus.hatVollzugriff)
        .opacity(knopfdeckung)
    }

    /// 0,6 beim Senden (`HeatSettings.tsx:195`), 0,4 ohne Recht zu schalten, sonst voll.
    private var knopfdeckung: Double {
        if schickt { return 0.6 }
        return haus.hatVollzugriff ? 1 : 0.4
    }

    /// Die rohen Werte bleiben erreichbar - sie sind mehr als die dreizehn Annahmen, und wer eine
    /// Kennung sucht, findet sie nur dort.
    private var umschalter: some View {
        Ansichtswahl(
            ansichten: [
                Ansicht(weg: "formular", name: "Annahmen"),
                Ansicht(weg: "werte", name: "Alle Werte"),
            ],
            aktiv: Ansicht(weg: ansicht, name: "")
        ) { a in ansicht = a.weg }
    }

    @ViewBuilder private func werteliste(_ c: HemsConfig) -> some View {
        Karte(kicker: "Alle Werte", beiwerk: AnyView(umschalter)) {
            VStack(alignment: .leading, spacing: 14) {
                if let wp = c.heatPump {
                    abschnitt("Wärmepumpe", wp.alsZeilen)
                }
                if let puffer = c.buffer {
                    abschnitt("Pufferspeicher", puffer.alsZeilen)
                }
                if let waerme = c.heatDemand {
                    abschnitt("Wärmebedarf", waerme.alsZeilen)
                }
                if let tarif = c.tariff {
                    abschnitt("Tarif", tarif.alsZeilen)
                }
                if let ofen = c.stove {
                    abschnitt("Pelletofen", ofen.alsZeilen)
                }
                if let regelung = c.control {
                    abschnitt("Regelung", regelung.alsZeilen)
                }
            }
        }
    }

    private func abschnitt(_ wort: String, _ zeilen: [(wort: String, wert: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: wort)
            Werteliste(werte: zeilen)
        }
    }

    // MARK: - Laden und Abgeben

    private func lade() async {
        do {
            let c = try await haus.api.einstellungen()
            uebernimmAntwort(c)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(Annahmenfelder.ladefehler)
        }
    }

    /// **Geschickt wird nur, was wirklich abweicht.** Darum geht ``einstellungen`` als `gegen:`
    /// mit: ohne sie schickte jedes Übernehmen alle dreizehn Werte zurück, und zwar gerundet auf
    /// die Stellen der Anzeige - die Begründung steht an
    /// ``Annahmenfelder/abgabe(entwuerfe:kennlinie:gegen:)``.
    ///
    /// Der Fehler landet in ``abgabefehler`` und nicht in ``fehler``: das Formular bleibt stehen,
    /// wie die Vorlage es stehen lässt (`HeatSettings.tsx:200`).
    private func uebernimm() async {
        guard !schickt else { return }
        schickt = true
        uebernommen = false
        abgabefehler = nil
        defer { schickt = false }
        let abgabe = Annahmenfelder.abgabe(
            entwuerfe: entwuerfe, kennlinie: kennlinie, gegen: einstellungen)
        switch abgabe {
        case .kennlinieUnlesbar:
            abgabefehler = Annahmenfelder.kennlinienFehler
        case .bereit(let patch):
            do {
                let c = try await haus.api.stelleWaerme(patch)
                uebernimmAntwort(c)
                uebernommen = true
            } catch let f as ApiFehler {
                abgabefehler = f.rat
            } catch {
                abgabefehler = Annahmenfelder.aenderungAbgelehnt
            }
        }
    }

    /// Nach jedem Laden und nach jedem Übernehmen stehen die Felder auf dem, was der Dienst
    /// wirklich hat - nicht auf dem, was jemand getippt hatte.
    private func uebernimmAntwort(_ c: HemsConfig) {
        einstellungen = c
        entwuerfe = Annahmenfelder.entwuerfe(c)
        kennlinie = Annahmenfelder.kurveZuText(c.heatDemand?.copCurve ?? [])
    }
}

/// Grund, Rand und Fokusring eines Eingabefeldes dieser Seite.
///
/// **Warum ein eigener Modifikator.** Vier Modifikatoren an zwei Stellen, und an beiden hingen
/// sie zusammen mit `.frame`, `.padding` und `.disabled` in einem Ausdruck - genau die Länge, bei
/// der der Übersetzer „unable to type-check this expression in reasonable time“ sagt. Benannt und
/// mit angeschriebenen Typen steht er einmal da und gilt für Zahlenfeld und Kennlinienzeile.
private struct Feldgrund: ViewModifier {
    /// Weicht der Entwurf von dem ab, was beim Dienst steht? Dann ist der Rand bernstein.
    let geaendert: Bool
    let imFokus: Bool

    /// Stärke und Farbe des Rings stehen an ``Marken/fokusring``; hier wird nur gezeichnet.
    /// Beide Zahlen standen in dieser Datei, und ein Ring, dessen Stärke nur eine Seite kennt,
    /// ist auf der zweiten Seite ein anderer Ring.
    private static let ringstaerke = CGFloat(Marken.fokusring.staerke)

    func body(content: Content) -> some View {
        content
            .background(Farbe.flaeche3)
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous))
            .overlay(rand)
            .overlay(ring)
    }

    private var rand: some View {
        RoundedRectangle(cornerRadius: Marken.radius1, style: .continuous)
            .strokeBorder(geaendert ? Farbe.amber : Farbe.linie2, lineWidth: 1)
    }

    /// **Der Ring liegt außerhalb.** `strokeBorder` zeichnet nach innen; das negative Polster
    /// schiebt die Form um die Ringstärke nach außen, sodass der Strich dort beginnt, wo das Feld
    /// endet - so wie ein `box-shadow` mit Streuung und ohne Weichzeichner.
    @ViewBuilder private var ring: some View {
        if imFokus {
            RoundedRectangle(
                cornerRadius: CGFloat(Marken.radius1) + Self.ringstaerke, style: .continuous
            )
            .strokeBorder(Farbe.fokusring, lineWidth: Self.ringstaerke)
            .padding(-Self.ringstaerke)
        }
    }
}

/// Ein Absatz, in dem ein Wort mitten im Satz auf eine andere Seite führt.
///
/// **Warum eine `AttributedString` und nicht ein Knopf unter dem Satz.** Die Vorlage setzt den
/// Verweis mitten in den Satz (`waerme/annahmen/page.tsx:23`), und der Absatz bricht um ihn herum
/// um. SwiftUI kann das Zweite nicht und das Erste nur so: zusammengesetzte `Text`-Werte brechen
/// richtig um, tragen aber keine Berührung je Stück; ein `HStack` aus Text und Knopf bricht nicht
/// um. Bleibt das `link`-Merkmal, das der Absatz mitträgt. Die App hat bisher die billigere
/// Lösung genommen - der Verweis als eigene bernsteinfarbene Zeile darunter
/// (`ZugangSeite.swift:288`, `ReglerSeite.swift:341`) -, und für diesen Satz ist sie falsch: „Ob
/// die Zahlen stimmen, steht auf der Wärmebilanz“ ist genau dort ein Verweis, wo die Wärmebilanz
/// genannt wird.
///
/// **Der Weg geht einen Umlauf später.** `wegweiser.gehe` in einem `Task` und nicht unmittelbar:
/// der `OpenURLAction` wird während des Zeichnens gebaut, und ein Schreiben auf den Wegweiser aus
/// diesem Lauf heraus ist „Modifying state during view update“ - davor warnt
/// `Navigation.swift:56-62` mit einer Erfahrung, die die App schon gemacht hat.
private struct Verweissatz: View {
    let stuecke: [Annahmenfelder.Textstueck]

    @Environment(Wegweiser.self) private var wegweiser

    var body: some View {
        Text(absatz)
            .font(Schrift.sans(14))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, abfangen)
    }

    private var abfangen: OpenURLAction {
        // Der Wegweiser wird vor dem Verschluss herausgelesen: so hängt die Schließung an ihm
        // und nicht an dieser Ansicht, die sonst als Ganzes über die Grenze müsste.
        let ziel = wegweiser
        return OpenURLAction { adresse in
            guard let weg = Verweisabsatz.weg(aus: adresse) else { return .systemAction }
            Task { @MainActor in ziel.gehe(weg) }
            return .handled
        }
    }

    /// Die Stücke des Kerns zu einem Absatz.
    ///
    /// **Der Farbschlüssel steht ausgeschrieben.** `t.foregroundColor = …` liest den Namen über
    /// eine dynamische Suche, und der Name steht in zwei Geltungsbereichen - dem von SwiftUI mit
    /// `Color` und dem von UIKit mit `UIColor`. Ausgeschrieben ist gemeint, was gemeint ist.
    private var absatz: AttributedString {
        var aus = AttributedString()
        for stueck in stuecke {
            switch stueck {
            case .satz(let satz):
                var teil = AttributedString(satz)
                teil[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Farbe.text3
                aus.append(teil)
            case .verweis(let wort, let weg):
                var teil = AttributedString(wort)
                teil[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Farbe.amber
                teil.link = Verweisabsatz.adresse(weg)
                aus.append(teil)
            }
        }
        return aus
    }
}

/// Eine Liste aus Schlüssel und Wert, wie sie aus einer Konfiguration kommt.
struct Werteliste: View {
    let werte: [(wort: String, wert: String)]

    var body: some View {
        if werte.isEmpty {
            Leer(satz: "Nichts gesetzt.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(werte.enumerated()), id: \.offset) { i, w in
                    if i > 0 { Divider().overlay(Farbe.linie1) }
                    HStack(alignment: .firstTextBaseline) {
                        Text(w.wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                        Spacer(minLength: 8)
                        Text(w.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}

/// Eine Konfiguration als Zeilen.
///
/// **Warum über `Encodable` und nicht Feld für Feld.** Die Konfiguration hat neun Gruppen mit
/// zusammen gut siebzig Feldern, und sie wächst - jedes neue Feld müsste hier nachgetragen
/// werden, und wer es vergisst, merkt nichts. Über die Kodierung kommt alles, was da ist, und
/// zwar unter den Namen des Schemas: `cop_curve` statt `copCurve`. Das ist hier richtig, denn
/// wer diese Seite liest, sucht die Zahl aus `hems.yaml`.
protocol AlsZeilen {}

extension AlsZeilen where Self: Encodable {
    var alsZeilen: [(wort: String, wert: String)] {
        guard let roh = try? JSONEncoder().encode(self),
              let buch = try? JSONSerialization.jsonObject(with: roh) as? [String: Any]
        else { return [] }
        return buch.keys.sorted().compactMap { schluessel in
            guard let wert = buch[schluessel] else { return nil }
            let text = textVon(wert)
            guard !text.isEmpty else { return nil }
            return (wort: schluessel.replacingOccurrences(of: "_", with: " "), wert: text)
        }
    }

    private func textVon(_ wert: Any) -> String {
        switch wert {
        case let d as Double: return Formate.zahl(d, stellen: d == d.rounded() ? 0 : 2)
        case let i as Int: return String(i)
        case let b as Bool: return b ? "ja" : "nein"
        case let s as String: return s
        case let liste as [Any]:
            // Eine Stützpunktliste (die COP-Kurve) wird als Paare geschrieben.
            if let paare = liste as? [[Double]] {
                return paare.map { p in
                    p.count >= 2
                        ? "\(Formate.zahl(p[0], stellen: 0))→\(Formate.zahl(p[1], stellen: 2))"
                        : ""
                }
                .filter { !$0.isEmpty }
                .joined(separator: "  ")
            }
            return liste.map { textVon($0) }.joined(separator: ", ")
        case is NSNull: return ""
        default: return ""
        }
    }
}

extension HeatPumpConfig: AlsZeilen {}
extension BufferConfig: AlsZeilen {}
extension HeatDemandConfig: AlsZeilen {}
extension TariffConfig: AlsZeilen {}
extension StoveConfig: AlsZeilen {}
extension ControlConfig: AlsZeilen {}
extension BatteryConfig: AlsZeilen {}
extension BalanceConfig: AlsZeilen {}
