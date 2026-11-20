import DuckCurveKit
import SwiftUI
import UniformTypeIdentifiers

/// Die Karte „Rechnung prüfen“: ein Feld, in das eine Tibber-Rechnung als PDF hineingeht
/// (`InvoiceCheck.tsx:54-93`, `:209-218`).
///
/// **Das fehlte in der App ganz.** `Api.pruefeRechnung` lag seit immer da und war von
/// nirgends aufgerufen (gesucht nach `pruefeRechnung` in `apps/ios`: nur die Definition); die
/// Rechnungsseite schickte den Benutzer stattdessen nach `docs/RECHNUNGSPRUEFUNG.md`. Eine
/// Seite, die nachrechnet, aber nichts annehmen kann, ist eine halbe Seite.
///
/// **Mehrere Dateien auf einmal, einzeln nacheinander geprüft** (`InvoiceCheck.tsx:137-159`).
/// Der Dienst nimmt ein PDF je Anfrage; wer ein Jahr nachrechnen will, wählt zwölf Stück aus.
/// Gezeigt wird danach der **letzte** Bericht, Fehlschläge werden gesammelt und mit „ · “
/// verbunden gemeldet - wer vier Rechnungen ablegt und bei einer scheitert, soll sehen, bei
/// welcher.
///
/// **Das Gestrichelte hat im Projekt kein Vorbild** (gesucht nach `dash:` in
/// `apps/ios/DuckCurveHome`: zehn Treffer, alle in Diagrammen, keiner an einem Rahmen).
/// `strokeBorder` mit `StrokeStyle(lineWidth: 1.5, dash: [6, 4])` ist die geradlinige
/// Übersetzung von `border: 1.5px dashed var(--line-2)` (`InvoiceCheck.tsx:81`). Das
/// Überziehen färbt den Rahmen bernstein und legt die Fläche darunter, wie in der Vorlage;
/// am Telefon gibt es nichts zu überziehen, und dort zeigt stattdessen das Drücken dieselbe
/// Fläche - sonst hätte der größte Griff der Seite keine Rückmeldung.
struct Rechnungsablage: View {
    /// Wie viele Rechnungen der Dienst schon kennt - das steht rechts im Kartenkopf und
    /// entscheidet über die Höhe des Felds.
    let anzahl: Int
    /// Läuft gerade eine Prüfung? **Das gehört der Seite und nicht diesem Baustein**, weil die
    /// Vorlage ihren Leerzustand daran hängt (`loaded && !busy`, `InvoiceCheck.tsx:331`, wobei
    /// `busy` der Hochlade-Zustand aus `:99` ist). Lag der Wert hier privat, stand beim ersten
    /// Weg - leere Seite, erstes PDF ablegen - für die Sekunden des Prüfens „Noch keine Rechnung
    /// geprüft“ direkt unter einem Feld, das „Rechnung wird geprüft …“ sagt.
    @Binding var laeuft: Bool
    /// Was nach dem Prüfen geschieht: der letzte Bericht, wo einer entstand, und die
    /// gesammelte Fehlerzeile, wo etwas schiefging. Die Seite wählt daraufhin die Rechnung und
    /// holt die Liste neu.
    let fertig: (InvoiceReportOut?, String?) -> Void

    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var zeigtDateiwahl = false
    @State private var ueberzogen = false
    @State private var gedrueckt = false

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Karte(
            kicker: Rechnungspruefung.pruefkartentitel,
            beiwerk: AnyView(kopfzahl)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                feld
                Text(Rechnungspruefung.hinweis)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fileImporter(
            isPresented: $zeigtDateiwahl, allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { ergebnis in
            Task { await lies(ergebnis) }
        }
    }

    private var kopfzahl: some View {
        Text(laeuft ? Rechnungspruefung.laeuftKurz : Rechnungspruefung.gespeichert(anzahl))
            .font(schmal ? Schrift.klein : Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .lineLimit(1)
    }

    // MARK: - Das Feld

    private var feld: some View {
        Button {
            zeigtDateiwahl = true
        } label: {
            inhalt
        }
        .buttonStyle(.plain)
        .disabled(laeuft)
        // Ziehen gibt es nur, wo etwas zu ziehen ist: am iPad aus der Dateien-App daneben.
        .dropDestination(for: URL.self) { urls, _ in
            Task { await pruefe(urls) }
            return true
        } isTargeted: { ueberzogen = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in gedrueckt = true }
                .onEnded { _ in gedrueckt = false }
        )
    }

    private var inhalt: some View {
        let text = Rechnungspruefung.ablegetext(laeuft: laeuft, ziehbar: !schmal)
        return VStack(spacing: 6) {
            Text(text.satz)
                // 14 px in der Vorlage (`InvoiceCheck.tsx:88`) - zwischen ``Schrift/klein``
                // und ``Schrift/text``, darum die Zwischenstufe.
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text1)
                .multilineTextAlignment(.center)
            Text(text.dazu)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, anzahl > 0 ? 16 : 34)
        .padding(.horizontal, anzahl > 0 ? 16 : 20)
        .background(flaeche)
        .overlay(rahmen)
        .contentShape(Rectangle())
    }

    /// Bernstein mit 7 % Deckung beim Überziehen (`InvoiceCheck.tsx:83`) - und dieselbe Fläche
    /// beim Drücken, wo nichts überzogen werden kann.
    @ViewBuilder private var flaeche: some View {
        if ueberzogen || gedrueckt {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Farbe.amber.opacity(0.07))
        } else {
            EmptyView()
        }
    }

    private var rahmen: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                ueberzogen ? Farbe.amber : Farbe.linie2,
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
    }

    /// 16 am Telefon, wie an der Karte selbst (`handy.css:182`); 3 am iPad wie in der Vorlage
    /// (`InvoiceCheck.tsx:80`).
    private var radius: CGFloat {
        schmal ? 16 : Marken.radius3
    }

    // MARK: - Lesen und prüfen

    private func lies(_ ergebnis: Result<[URL], any Error>) async {
        guard case .success(let urls) = ergebnis else { return }
        await pruefe(urls)
    }

    /// Jede Datei einzeln: lesen, hochladen, Fehlschläge sammeln.
    ///
    /// **Der Zugriff muss je Datei einzeln angefordert werden.** Eine Datei aus der
    /// Dateiauswahl liegt außerhalb der Sandkiste; ohne
    /// `startAccessingSecurityScopedResource` kommt ein leeres `Data` zurück und die Rechnung
    /// wäre „nicht lesbar“ - derselbe Grund wie in `Alfred/Alfredblatt.swift:343-346`. Mit
    /// Mehrfachwahl steht der Rahmen darum in der Schleife und nicht um sie.
    ///
    /// **Gefiltert wird auf `.pdf`** (`InvoiceCheck.tsx:58`). Die Dateiauswahl lässt ohnehin
    /// nur PDFs zu; beim Ziehen kommt alles herein, was jemand fallen lässt.
    private func pruefe(_ urls: [URL]) async {
        let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        guard !pdfs.isEmpty, !laeuft else { return }
        laeuft = true
        var letzter: InvoiceReportOut?
        var fehlschlaege: [(name: String, rat: String)] = []
        for url in pdfs {
            let name = url.lastPathComponent
            guard let pdf = daten(url), !pdf.isEmpty else {
                fehlschlaege.append((name: name, rat: Rechnungspruefung.dateifehler))
                continue
            }
            do {
                letzter = try await haus.api.pruefeRechnung(pdf, name: name)
            } catch let f as ApiFehler {
                fehlschlaege.append((name: name, rat: f.rat))
            } catch {
                fehlschlaege.append((name: name, rat: Rechnungspruefung.dateifehler))
            }
        }
        laeuft = false
        fertig(letzter, Rechnungspruefung.dateifehlerzeile(fehlschlaege))
    }

    private func daten(_ url: URL) -> Data? {
        let darf = url.startAccessingSecurityScopedResource()
        defer { if darf { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}
