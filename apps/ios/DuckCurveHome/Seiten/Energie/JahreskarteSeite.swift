import DuckCurveKit
import SwiftUI

/// Die Jahreskarte: ein Jahr als Raster aus Tagen, nach Wochen gestapelt.
///
/// **Warum ein Raster und keine Kurve.** Ein Jahr als Linie ist 365 Punkte in einem Bild, das
/// 300 Punkte breit ist - jeder zweite Tag fällt weg, und die Jahreszeit, die die eigentliche
/// Auskunft ist, verschwindet im Rauschen. Als Raster hat jeder Tag sein Feld, die Wochen stehen
/// untereinander, und der Sommer ist eine helle Insel. Dieselbe Form, die Versionsverwaltungen
/// fuer Beitraege benutzen, und aus demselben Grund.
struct JahreskarteSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @State private var karte: YearMapOut?
    @State private var fehler: ApiFehler?
    @State private var reihe: String = "pv_kwh"
    @State private var jahr: Int = 0

    var body: some View {
        Seite {
            kopf
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let karte {
                Karte(kicker: "\(karte.year)", titel: name(reihe)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Raster(karte: karte, reihe: reihe)
                        skala(karte)
                    }
                }
                Kachelfeld(kacheln: kennzahlen(karte), kicker: "Das Jahr")
                Methode([
                    karte.dataSince.map { "Daten seit \($0)." },
                    "\(Formate.zahl(Double(karte.hoursWithData), stellen: 0)) Stunden mit Messwerten.",
                    "Ein Tag ohne Messwerte bleibt leer und wird nicht als Null gezeichnet.",
                ])
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task(id: jahr) { await lade() }
        .onAppear {
            if jahr == 0 {
                jahr = Kalender.haus.component(.year, from: haus.jetzt)
            }
        }
    }

    private var kopf: some View {
        HStack(spacing: 10) {
            if let karte, !karte.metrics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(karte.metrics.keys.sorted(), id: \.self) { s in
                            Button {
                                reihe = s
                            } label: {
                                Text(name(s))
                                    .font(Schrift.winzig)
                                    .foregroundStyle(s == reihe ? Farbe.deep : Farbe.text2)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(s == reihe ? Farbe.amberWeich : Farbe.flaeche2)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                Button { jahr -= 1 } label: { Text("‹").font(Schrift.karte).frame(width: 28, height: 28) }
                    .buttonStyle(.plain).foregroundStyle(Farbe.text2)
                Text(String(jahr)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                Button { jahr += 1 } label: { Text("›").font(Schrift.karte).frame(width: 28, height: 28) }
                    .buttonStyle(.plain)
                    .foregroundStyle(darfVor ? Farbe.text2 : Farbe.text3)
                    .disabled(!darfVor)
            }
            .background(Farbe.flaeche2)
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
    }

    private var darfVor: Bool {
        jahr < Kalender.haus.component(.year, from: haus.jetzt)
    }

    private func name(_ schluessel: String) -> String {
        switch schluessel {
        case "pv_kwh": return "aus der Sonne"
        case "house_kwh": return "im Haus"
        case "import_kwh": return "aus dem Netz"
        case "export_kwh": return "eingespeist"
        case "heat_pump_kwh": return "Wärmepumpe"
        case "autarky": return "Autarkie"
        case "price_ct": return "Strompreis"
        default: return schluessel.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func kennzahlen(_ k: YearMapOut) -> [Kacheldaten] {
        let werte = (k.metrics[reihe] ?? []).flatMap { $0 }.compactMap { $0 }
        let summe = werte.reduce(0, +)
        let istAnteil = reihe == "autarky"
        return [
            Kacheldaten(
                istAnteil ? "im Mittel" : "zusammen",
                istAnteil
                    ? Formate.prozent(werte.isEmpty ? nil : summe / Double(werte.count))
                    : Formate.zahl(summe, stellen: 0),
                einheit: istAnteil ? nil : "kWh"
            ),
            Kacheldaten("Tage mit Werten", String(werte.count)),
            Kacheldaten(
                "bester Tag",
                istAnteil ? Formate.prozent(werte.max()) : Formate.zahl(werte.max(), stellen: 1),
                einheit: istAnteil ? nil : "kWh"
            ),
            Kacheldaten("Stunden erfasst", Formate.zahl(Double(k.hoursWithData), stellen: 0)),
        ]
    }

    private func skala(_ k: YearMapOut) -> some View {
        HStack(spacing: 6) {
            Text("wenig").font(Schrift.winzig).foregroundStyle(Farbe.text3)
            ForEach(Array(Farbe.waerme.enumerated()), id: \.offset) { _, f in
                Rectangle().fill(f).frame(width: 16, height: 8)
            }
            Text("viel").font(Schrift.winzig).foregroundStyle(Farbe.text3)
            Spacer(minLength: 0)
        }
    }

    private func lade() async {
        guard jahr > 2000 else { return }
        do {
            karte = try await haus.api.jahreskarte(jahr: jahr)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

/// Das Raster selbst: Wochen als Spalten, Wochentage als Zeilen.
private struct Raster: View {
    let karte: YearMapOut
    let reihe: String

    /// Die Kantenlaenge eines Tagesfeldes. Klein genug, dass 53 Wochen auf ein iPad passen.
    private let kante: CGFloat = 11
    private let luecke: CGFloat = 2

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: luecke) {
                ForEach(0..<wochen.count, id: \.self) { w in
                    VStack(spacing: luecke) {
                        ForEach(0..<7, id: \.self) { tag in
                            feld(woche: w, tag: tag)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// Die Werte, nach Wochen gruppiert. Der Dienst liefert sie als Wochenzeilen.
    private var wochen: [[Double?]] {
        karte.metrics[reihe] ?? []
    }

    @ViewBuilder private func feld(woche: Int, tag: Int) -> some View {
        let wert = woche < wochen.count && tag < wochen[woche].count ? wochen[woche][tag] : nil
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(farbe(wert))
            .frame(width: kante, height: kante)
            .accessibilityHidden(wert == nil)
    }

    /// Die Farbe eines Tages. Ein Tag ohne Messwerte bleibt leer - und nicht dunkelblau, was
    /// „wenig" heisst: „nichts gemessen" und „nichts erzeugt" sind zwei verschiedene Auskuenfte.
    private func farbe(_ wert: Double?) -> Color {
        guard let wert else { return Farbe.linie1 }
        guard let hoechster = alle.max(), hoechster > 0 else { return Farbe.waerme[0] }
        let anteil = min(1, max(0, wert / hoechster))
        let stufe = Int((anteil * Double(Farbe.waerme.count - 1)).rounded())
        return Farbe.waerme[min(Farbe.waerme.count - 1, max(0, stufe))]
    }

    private var alle: [Double] {
        wochen.flatMap { $0 }.compactMap { $0 }
    }
}
