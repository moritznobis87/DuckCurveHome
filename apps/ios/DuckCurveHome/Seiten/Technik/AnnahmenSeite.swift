import DuckCurveKit
import SwiftUI

/// Annahmen: die Einstellungen, mit denen der Fahrplan rechnet.
///
/// **Was hier steht, ist nicht gemessen, sondern gesetzt.** Pufferfassung, Verlust je Kelvin,
/// Pelletpreis, die angenommene COP-Kurve. Jede dieser Zahlen geht in jede Euro-Zahl der App
/// ein, und keine davon kommt aus einer Messung.
struct AnnahmenSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var einstellungen: HemsConfig?
    @State private var fehler: ApiFehler?
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
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task { await lade() }
    }

    // MARK: - Das Formular

    /// **Die Seite stellt, sie zeigt nicht nur.** Hier stand eine Leseliste roher Schlüssel
    /// („hw auto off block s 1200“), und darunter der Satz, geändert werde das im Dashboard.
    /// Die Vorlage (`settings/HeatSettings.tsx`) ist ein Formular: zwölf beschriftete Felder
    /// mit ihren Einheiten und Erklärsätzen, die Kennlinie als Zeile, ein Knopf. Jede Änderung
    /// wirkt sofort und rückwirkend - das steht als Satz darüber, nicht im Kleingedruckten.
    ///
    /// **Ohne Kicker, weil er jetzt im Gerippe steht.** „Lieferschein · Datenblatt · Puffer“ ist
    /// in der Vorlage der Kicker der Hülle (`waerme/annahmen/page.tsx:13`) und nicht die
    /// Überschrift dieser Karte - `HeatSettings.tsx` setzt über das Formular keine. ``Seite``
    /// zeichnet ihn aus ``Bereiche/kicker(fuer:)``, und das Wort bleibt
    /// ``Annahmenfelder/kicker``.
    @ViewBuilder private func formular(_ c: HemsConfig) -> some View {
        Karte(beiwerk: AnyView(umschalter)) {
            VStack(alignment: .leading, spacing: 18) {
                Text(Annahmenfelder.einleitung)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                spalten(c)
                kennlinienzeile(c)
                abgabezeile
            }
        }
        Methode(Annahmenfelder.methodensaetze.map(Optional.init))
    }

    /// Zwei Spalten an der Wand, eine am Telefon - wie die Vorlage.
    @ViewBuilder private func spalten(_ c: HemsConfig) -> some View {
        let gruppen = Annahmenfelder.spalten()
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                ForEach(Array(gruppen.enumerated()), id: \.offset) { _, felder in
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(felder) { feld in
                            feldzeile(feld, c)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 640)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(gruppen.flatMap { $0 }) { feld in
                    feldzeile(feld, c)
                }
            }
        }
    }

    private func feldzeile(_ feld: Annahmenfeld, _ c: HemsConfig) -> some View {
        let gebunden = Binding(
            get: { entwuerfe[feld.schluessel] ?? "" },
            set: { entwuerfe[feld.schluessel] = $0 }
        )
        let geaendert = Annahmenfelder.abweichend(
            feld, entwurf: gebunden.wrappedValue, gegen: c)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(feld.wort)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                TextField("", text: gebunden)
                    .font(Schrift.zahl)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(feld.darfNegativ ? .numbersAndPunctuation : .decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 92)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Farbe.flaeche2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                            .strokeBorder(
                                geaendert ? Farbe.amber : Farbe.linie2, lineWidth: 1)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                    .disabled(!haus.darfSchalten)
                Text(feld.einheit)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .frame(width: 42, alignment: .leading)
            }
            if let hinweis = feld.hinweis {
                Text(hinweis)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func kennlinienzeile(_ c: HemsConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(wort: Annahmenfelder.kennlinienTitel)
            Text(Annahmenfelder.kennlinienErklaerung)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: $kennlinie)
                .font(Schrift.zahl)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Farbe.flaeche2)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(
                            kennlinie != Annahmenfelder.kurveZuText(c.heatDemand?.copCurve ?? [])
                                ? Farbe.amber : Farbe.linie2,
                            lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                .disabled(!haus.darfSchalten)
        }
    }

    @ViewBuilder private var abgabezeile: some View {
        HStack(spacing: 12) {
            Button {
                Task { await uebernimm() }
            } label: {
                Text(schickt ? Annahmenfelder.knopfLaeuft : Annahmenfelder.knopf)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.petrol)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Farbe.amber)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(schickt || !haus.darfSchalten)
            .opacity(haus.darfSchalten ? 1 : 0.4)
            if uebernommen {
                Text(Annahmenfelder.uebernommenSatz)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Die rohen Werte bleiben erreichbar - sie sind mehr als die zwölf Annahmen, und wer eine
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

    private func uebernimm() async {
        guard !schickt else { return }
        schickt = true
        uebernommen = false
        defer { schickt = false }
        switch Annahmenfelder.abgabe(entwuerfe: entwuerfe, kennlinie: kennlinie) {
        case .kennlinieUnlesbar:
            fehler = ApiFehler(code: "kennlinie", meldung: Annahmenfelder.kennlinienFehler, status: 0)
        case .bereit(let patch):
            do {
                let c = try await haus.api.stelleWaerme(patch)
                uebernimmAntwort(c)
                fehler = nil
                uebernommen = true
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(Annahmenfelder.aenderungAbgelehnt)
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
