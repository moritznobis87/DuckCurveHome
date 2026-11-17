import DuckCurveKit
import SwiftUI

/// Rechnungen: die Tibber-Rechnungen und was die Pruefung an ihnen gefunden hat.
///
/// **Was diese Seite wirklich tut.** Sie vergleicht, was der Versorger abgerechnet hat, mit dem,
/// was das Haus selbst gemessen hat - Kilowattstunden, Zeitraum, mittlerer Preis. Eine Rechnung,
/// deren Zeitraum nicht zu den eigenen Minutenwerten passt, ist nicht automatisch falsch; aber
/// sie ist eine Frage wert, und ohne diese Seite stellt sie niemand.
///
/// Nur fuer den Hausherrn: hier stehen Name, Adresse, Marktlokations-ID, Zaehlernummer.
struct RechnungenSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var liste: [InvoiceSummaryOut] = []
    @State private var gewaehlt: String?
    @State private var bericht: InvoiceReportOut?
    @State private var fehler: ApiFehler?
    @State private var laedt = false

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await ladeListe() } }
            }
            if liste.isEmpty, !laedt, fehler == nil {
                Karte {
                    Leer(
                        satz: "Es sind keine Rechnungen eingelesen.",
                        dazu: "Rechnungen kommen über den Dienst herein - siehe docs/RECHNUNGSPRUEFUNG.md."
                    )
                }
            }
            if !liste.isEmpty {
                Karte(kicker: "Rechnungen") {
                    VStack(spacing: 0) {
                        ForEach(Array(liste.enumerated()), id: \.offset) { i, r in
                            if i > 0 { Divider().overlay(Farbe.linie1) }
                            rechnungszeile(r)
                        }
                    }
                }
            }
            if let bericht {
                pruefung(bericht)
            }
        }
        .task { await ladeListe() }
        .task(id: gewaehlt) { await ladeBericht() }
    }

    private func rechnungszeile(_ r: InvoiceSummaryOut) -> some View {
        Button {
            gewaehlt = gewaehlt == r.number ? nil : r.number
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.periodLabel).font(Schrift.klein).foregroundStyle(Farbe.text1)
                    Text("Nr. \(r.number) · \(r.issuedOn)")
                        .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Formate.euro(r.totalGrossEur))
                        .font(Schrift.zahl).foregroundStyle(Farbe.text1)
                    urteil(r.verdict, probleme: r.problems)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Das Urteil der Pruefung, als Wort mit Farbe. Ein Haken allein sagt nicht, was geprueft
    /// wurde - und ein rotes Kreuz ohne Zahl sagt nicht, wie schlimm es ist.
    private func urteil(_ wort: String, probleme: Int) -> some View {
        let farbe: Color =
            switch wort {
            case "ok": Farbe.mist
            case "warn", "warning": Farbe.achtung
            case "fail", "alarm": Farbe.alarm
            default: Farbe.text3
            }
        let text: String =
            switch wort {
            case "ok": "geprüft, in Ordnung"
            case "warn", "warning": probleme == 1 ? "1 Hinweis" : "\(probleme) Hinweise"
            case "fail", "alarm": probleme == 1 ? "1 Befund" : "\(probleme) Befunde"
            default: wort
            }
        return Text(text).font(Schrift.winzig).foregroundStyle(farbe)
    }

    private func pruefung(_ b: InvoiceReportOut) -> some View {
        Group {
            Kachelfeld(kacheln: kennzahlen(b), kicker: "Nr. \(b.invoice.number)")
            if !b.findings.isEmpty {
                Karte(kicker: "Was aufgefallen ist") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(b.findings.enumerated()), id: \.offset) { _, f in
                            befund(f)
                        }
                    }
                }
            }
            if let m = b.measured {
                Karte(kicker: "Was das Haus gemessen hat") {
                    VStack(spacing: 0) {
                        Zeile(
                            wort: "Bezug", wert: Formate.zahl(m.importKwh, stellen: 1), einheit: "kWh"
                        )
                        Zeile(wort: "abgedeckter Zeitraum", wert: Formate.prozent(m.coverage))
                        Zeile(
                            wort: "mittlerer Preis",
                            wert: Formate.zahl(m.avgPriceCtKwh, stellen: 2), einheit: "ct/kWh"
                        )
                    }
                }
            }
            if !b.invoice.positions.isEmpty {
                Karte(kicker: "Positionen") {
                    Tabelle(
                        zeilennamen: b.invoice.positions.map(\.label),
                        spalten: [
                            .init(
                                name: "ct/kWh",
                                zellen: b.invoice.positions.map { Formate.zahl($0.ctPerKwh, stellen: $0.ctDecimals) }
                            ),
                            .init(name: "Betrag", zellen: b.invoice.positions.map { Formate.euro($0.amountEur) }),
                        ]
                    )
                }
            }
            Methode([
                "Geprüft am \(b.checkedAt).",
                b.alreadyKnown == true ? "Diese Rechnung war schon eingelesen." : nil,
                "Verglichen werden Zeitraum, Menge und mittlerer Preis gegen die eigenen "
                    + "Minutenwerte. Eine Abweichung ist eine Frage, kein Beweis.",
            ])
        }
    }

    /// Die Farbe des Punktes vor einem Befund.
    ///
    /// **Hier stand ein Vergleich mit „alarm", und der war doppelt falsch:** `severity` ist
    /// eine Aufzaehlung und keine Zeichenkette, und „alarm" ist keiner ihrer Werte. Sie kennt
    /// `ok`, `info`, `warning`, `error`. Der Punkt waere also immer gelb geblieben, auch wenn
    /// der Typ gepasst haette - ein Fehler, den man am Bildschirm nicht sieht.
    ///
    /// Die Zuordnung ist die des Dashboards (`reports/InvoiceCheck.tsx`, `Dot`): Fehler und
    /// Warnung rot, Hinweis grau, alles andere gelb. Dass dort auch ein `ok` gelb wird und
    /// nicht gruen, ist auffaellig - es bleibt trotzdem so, denn zwei Oberflaechen, die
    /// dieselbe Pruefung verschieden einfaerben, sind schlimmer als eine fragliche Farbe.
    private func befundfarbe(_ s: InvoiceFindingSeverityWahl) -> Color {
        switch s {
        case .error, .warning: return Farbe.alarm
        case .info: return Farbe.mist
        case .ok, .unbekannt: return Farbe.amber
        }
    }

    private func befund(_ f: InvoiceFinding) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(befundfarbe(f.severity))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(f.titleDe).font(Schrift.klein).foregroundStyle(Farbe.text1)
                Text(f.detailDe)
                    .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
                if f.expected != nil || f.actual != nil {
                    HStack(spacing: 12) {
                        if let e = f.expected {
                            Text("erwartet \(Formate.zahl(e, stellen: 2)) \(f.unit ?? "")")
                                .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                        }
                        if let a = f.actual {
                            Text("auf der Rechnung \(Formate.zahl(a, stellen: 2)) \(f.unit ?? "")")
                                .font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                        }
                    }
                }
            }
        }
    }

    private func kennzahlen(_ b: InvoiceReportOut) -> [Kacheldaten] {
        let r = b.invoice
        return [
            Kacheldaten("brutto", Formate.euro(r.totalGrossEur), dazu: r.periodLabel),
            Kacheldaten("abgerechnet", Formate.zahl(r.kwh, stellen: 1), einheit: "kWh"),
            Kacheldaten(
                "mittlerer Preis", Formate.zahl(r.avgCtKwhGross, stellen: 2), einheit: "ct/kWh"
            ),
            Kacheldaten("Energie netto", Formate.euro(r.energyNetEur)),
            Kacheldaten("Gebühren netto", Formate.euro(r.feesNetEur)),
            Kacheldaten("Umsatzsteuer", Formate.euro(r.vatEur)),
        ]
    }

    private func ladeListe() async {
        laedt = true
        do {
            liste = try await haus.api.rechnungen()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
        laedt = false
    }

    private func ladeBericht() async {
        guard let nummer = gewaehlt else {
            bericht = nil
            return
        }
        bericht = try? await haus.api.rechnung(nummer)
    }
}
