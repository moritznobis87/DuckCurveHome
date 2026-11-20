import DuckCurveKit
import SwiftUI

/// Technik → Hausgerät: wie es dem Rechner im Haus und seinen Diensten geht, und die wenigen
/// Handgriffe, die es aus der Ferne braucht - Dienst neu starten, Protokoll ansehen, sichern,
/// Gerät neu starten, Update installieren.
///
/// **Auf dem Gerät selbst gibt es für den Hausherrn keinen Zugang**: kein Bildschirm, keine
/// Kommandozeile. Diese Seite ersetzt `dch status`, `dch logs` und `dch neustart`. Die Vorlage ist
/// `apps/web/src/components/geraet/Geraet.tsx`; bewertet wird in der API, Ampel und Satz kommen
/// fertig und sind auf beiden Seiten dieselben.
///
/// **Jeder Handgriff fragt nach.** Ein Neustart der Datenbank aus Versehen kostet eine Minute
/// Regelung, ein Neustart des Geräts zwei - und am Telefon tippt man schneller daneben als mit
/// der Maus.
struct HausgeraetSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var geraet: GeraetOut?
    @State private var update: UpdateStatusOut?
    @State private var fehler: ApiFehler?
    @State private var hinweis: String?
    @State private var offen: Set<String> = []
    @State private var nachfrage: Nachfrage?
    @State private var protokoll: Protokollblatt?
    /// Nach einer Anfrage kurz eilig nachsehen, auch wenn das Gerät sie noch nicht abgeholt hat.
    @State private var eiligBis = Date.distantPast

    enum Nachfrage: Identifiable {
        case dienst(String)
        case alle
        case geraet
        case update

        var id: String {
            switch self {
            case .dienst(let d): return "dienst-\(d)"
            case .alle: return "alle"
            case .geraet: return "geraet"
            case .update: return "update"
            }
        }
    }

    struct Protokollblatt: Identifiable {
        let dienst: String
        var inhalt: GeraetProtokollOut?
        var fehler: String?
        var id: String { dienst }
    }

    private var gesperrt: Bool {
        guard let g = geraet else { return true }
        return !g.unterstuetzt || Hausgeraet.beschaeftigt(g)
    }

    private var eilig: Bool {
        Hausgeraet.beschaeftigt(geraet) || Hausgeraet.updateLaeuft(update) || Date() < eiligBis
    }

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let g = geraet {
                urteil(g)
                if let hinweis {
                    Text(hinweis).font(Schrift.klein).foregroundStyle(Farbe.alarm)
                } else if let satz = Hausgeraet.aktionssatz(g) {
                    Text(satz.text).font(Schrift.klein)
                        .foregroundStyle(satz.fehler ? Farbe.alarm : Farbe.text2)
                }
                if g.unterstuetzt { dienstkarte(g) }
                apikarte(g.api)
                if let r = g.rechner { rechnerkarte(r) }
                if let s = g.sicherung { sicherungskarte(s) }
                if !g.einheiten.isEmpty { einheitenkarte(g.einheiten) }
                softwarekarte
                if g.unterstuetzt { neustartkarte }
            } else if fehler == nil {
                Karte { Leer(satz: "Wird geholt …") }
            }
        }
        .task {
            // Im Ruhezustand alle fünfzehn Sekunden - das Gerät schreibt seinen Bericht ohnehin
            // nur jede Minute. Läuft etwas, alle zwei, damit „Neu gestartet“ bald dasteht.
            while !Task.isCancelled {
                await lade()
                try? await Task.sleep(for: .seconds(eilig ? 2 : 15))
            }
        }
        .alert(
            nachfrage.map(titel) ?? "",
            isPresented: Binding(get: { nachfrage != nil }, set: { if !$0 { nachfrage = nil } }),
            presenting: nachfrage
        ) { n in
            Button(knopf(n), role: .destructive) { ausfuehren(n) }
            Button("Abbrechen", role: .cancel) {}
        } message: { n in
            Text(frage(n))
        }
        .sheet(item: $protokoll) { blatt in
            protokollansicht(blatt)
        }
    }

    // MARK: - Teile

    private func punkt(_ ampel: Hausgeraet.Ampel, gross: Bool = false) -> some View {
        Circle()
            .fill(farbe(ampel))
            .frame(width: gross ? 11 : 8, height: gross ? 11 : 8)
            .padding(.top, gross ? 5 : 5)
            .accessibilityLabel(ampel.wort)
    }

    private func farbe(_ a: Hausgeraet.Ampel) -> Color {
        switch a {
        case .gut: return Farbe.gut
        case .warn: return Farbe.amberWeich
        case .schlecht: return Farbe.alarm
        case .aus: return Farbe.text3
        }
    }

    private func zeile(_ ampel: Hausgeraet.Ampel?, _ titel: String, _ text: String? = nil, rechts: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let ampel { punkt(ampel) } else { Color.clear.frame(width: 8, height: 8) }
            VStack(alignment: .leading, spacing: 1) {
                Text(titel).font(Schrift.klein).foregroundStyle(Farbe.text1)
                if let text, !text.isEmpty {
                    Text(text).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let rechts {
                Text(rechts).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2).multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private func knopfzeile(_ wort: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(wort)
                .font(Schrift.klein)
                .foregroundStyle(gesperrt ? Farbe.text3 : Farbe.text1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Farbe.flaeche3)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(gesperrt)
    }

    private func urteil(_ g: GeraetOut) -> some View {
        let ampel = Hausgeraet.Ampel(g.ampel?.rawValue)
        return Karte {
            HStack(alignment: .top, spacing: 12) {
                punkt(ampel, gross: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(ampel == .gut ? "Alles in Ordnung." : (g.textDe ?? ""))
                        .font(Schrift.karte).foregroundStyle(Farbe.text1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(
                        g.unterstuetzt
                            ? "Bericht des Geräts von \(Formate.hhmm(iso: g.berichtAm))"
                                + (g.berichtAlt == true ? " - veraltet: Der Zeitgeber auf dem Gerät läuft nicht." : ".")
                            : "Diese Installation läuft nicht auf dem Hausgerät; hier steht nur, was die API über sich selbst weiß."
                    )
                    .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func dienstkarte(_ g: GeraetOut) -> some View {
        Karte(kicker: "Dienste", titel: "antippen für mehr") {
            if g.dienste.isEmpty {
                Leer(satz: "Noch kein Bericht über die Dienste.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(g.dienste.enumerated()), id: \.element.name) { i, d in
                        if i > 0 { Divider().overlay(Farbe.linie1) }
                        dienstzeile(d)
                    }
                }
            }
        }
    }

    private func dienstzeile(_ d: GeraetDienstOut) -> some View {
        let auf = offen.contains(d.name)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                if auf { offen.remove(d.name) } else { offen.insert(d.name) }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    punkt(Hausgeraet.Ampel(d.ampel?.rawValue))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Hausgeraet.dienstname(d.name)).font(Schrift.karte).foregroundStyle(Farbe.text1)
                        Text(d.textDe ?? "").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        if d.zustand == "running" {
                            Text("seit \(Hausgeraet.seit(iso: d.gestartetAm))")
                                .font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                        }
                        if let cpu = d.cpuProzent, let mb = d.speicherMb {
                            Text("\(Formate.zahl(cpu, stellen: 1)) % · \(Formate.zahl(mb, stellen: 0)) MB")
                                .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(auf ? "zuklappen" : "Fassung, Prüfung und Handgriffe zeigen")

            if auf {
                VStack(alignment: .leading, spacing: 6) {
                    zeile(nil, "Fassung", d.revision ?? d.image ?? "–")
                    if let n = d.neustarts, n > 0 { zeile(nil, "Von selbst neu gestartet", "\(n)-mal") }
                    if let p = d.pruefung, !p.isEmpty {
                        Text(p).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Farbe.flaeche1)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    HStack(spacing: 8) {
                        knopfzeile("Neu starten") { nachfrage = .dienst(d.name) }
                        knopfzeile("Protokoll ansehen") { Task { await zeigeProtokoll(d.name) } }
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(.vertical, 8)
    }

    private func apikarte(_ api: ApiSelbstOut) -> some View {
        Karte(kicker: "Rechenkern", titel: "läuft seit \(Hausgeraet.dauer(sekunden: api.laufzeitS))") {
            zeile(Hausgeraet.Ampel(api.ampel?.rawValue), api.textDe ?? "")
            zeile(
                api.datenbankOk == false ? .schlecht : api.datenbankOk == true ? .gut : .aus,
                "Datenbank", api.datenbankDe
            )
            zeile(
                api.bridgeOnline == true ? .gut : api.modus == "live" ? .warn : .aus,
                "Bridge", api.verbindungDe
            )
            ForEach(api.quellen, id: \.name) { q in
                zeile(q.online ? .gut : .warn, q.name, [q.detailDe ?? "", q.lastOk.map { "zuletzt \(Formate.hhmm(iso: $0))" } ?? ""]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
            }
            ForEach(api.befunde, id: \.name) { b in
                zeile(b.severity.rawValue == "alarm" ? .schlecht : .warn, b.titleDe, b.textDe)
            }
            zeile(
                api.alfredEingerichtet == true ? .gut : .aus, "Alfred",
                api.alfredEingerichtet == true ? "Sprachmodell eingerichtet." : "Kein Schlüssel für das Sprachmodell hinterlegt."
            )
            Text("Fassung \(api.version) · \(api.commit) · \(Formate.zahl(api.rssMb, stellen: 0)) MB")
                .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
        }
    }

    private func rechnerkarte(_ r: GeraetRechnerOut) -> some View {
        Karte(kicker: "Gerät", titel: r.modell ?? r.name) {
            zeile(nil, "Läuft seit", r.adresse.map { "Adresse im Heimnetz: \($0)" },
                  rechts: Hausgeraet.dauer(sekunden: r.laufzeitS ?? 0))
            zeile(nil, "Auslastung", "Mittlere Last über 1, 5 und 15 Minuten bei \(r.kerne ?? 1) Kernen",
                  rechts: r.last.map { Formate.zahl($0, stellen: 2) }.joined(separator: " · "))
            if let t = r.temperaturC {
                let a = Hausgeraet.Ampel(r.temperaturAmpel?.rawValue)
                zeile(a, "Temperatur", a == .gut ? nil : "Ab 80 °C drosselt sich der Rechner selbst.",
                      rechts: "\(Formate.zahl(t, stellen: 1)) °C")
            }
            if r.drosselung != nil {
                zeile(Hausgeraet.Ampel(r.drosselungAmpel?.rawValue), "Stromversorgung und Takt",
                      r.drosselungDe.isEmpty ? "Keine Unterspannung, keine Drosselung seit dem Start."
                          : r.drosselungDe.joined(separator: " "))
            }
            if let gesamt = r.speicherGesamtMb, gesamt > 0 {
                let belegt = Double(gesamt - (r.speicherFreiMb ?? 0)) / 1024
                zeile(Hausgeraet.Ampel(r.speicherAmpel?.rawValue), "Arbeitsspeicher",
                      rechts: "\(Formate.zahl(belegt, stellen: 1)) von \(Formate.zahl(Double(gesamt) / 1024, stellen: 1)) GB")
            }
            ForEach(r.platten, id: \.ort) { p in
                zeile(Hausgeraet.Ampel(p.ampel?.rawValue), p.ort == "/" ? "SSD" : p.ort,
                      rechts: "\(Hausgeraet.gigabyte(p.freiBytes)) frei von \(Hausgeraet.gigabyte(p.gesamtBytes))")
            }
            let technik = [r.system, r.kernel.map { "Kernel \($0)" }, r.docker.map { "Docker \($0)" }].compactMap { $0 }
            if !technik.isEmpty {
                Text(technik.joined(separator: " · ")).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func sicherungskarte(_ s: GeraetSicherungOut) -> some View {
        Karte(kicker: "Sicherung") {
            zeile(Hausgeraet.Ampel(s.ampel?.rawValue), s.textDe ?? "")
            if let letzte = s.letzte {
                zeile(nil, "Letzte Sicherung", letzte, rechts: Formate.hhmm(iso: s.letzteAm))
            }
            zeile(nil, "Kopie außer Haus", s.ausserHaus ?? "keine (DCH_SICHERUNG_ZIEL in .env)")
            knopfzeile("Jetzt sichern") { Task { await anfragen(.sichern) } }
        }
    }

    private func einheitenkarte(_ einheiten: [GeraetEinheitOut]) -> some View {
        Karte(kicker: "Abläufe auf dem Gerät") {
            ForEach(einheiten, id: \.name) { e in
                zeile(Hausgeraet.Ampel(e.ampel?.rawValue), Hausgeraet.einheitennamen[e.name] ?? e.beschreibung ?? e.name,
                      (e.textDe ?? "") + (e.naechsterLauf.map { " Nächster Lauf \(Formate.hhmm(iso: $0))." } ?? ""))
            }
        }
    }

    @ViewBuilder private var softwarekarte: some View {
        if let u = update, u.unterstuetzt == true {
            Karte(kicker: "Software", titel: u.kanal.map { "Kanal \($0)" }) {
                zeile(nil, "Läuft", rechts: u.aktuell ?? "unbekannt")
                if Hausgeraet.updateLaeuft(u) {
                    let index = Hausgeraet.updateSchritte.firstIndex { $0.schluessel == u.schritt }
                    Text("Update läuft").font(Schrift.karte).foregroundStyle(Farbe.text1)
                    ForEach(Array(Hausgeraet.updateSchritte.enumerated()), id: \.offset) { i, s in
                        let zeichen = index.map { i < $0 ? "✓" : i == $0 ? "…" : "·" } ?? "·"
                        Text("\(zeichen) \(s.text)").font(Schrift.klein)
                            .foregroundStyle(i == index ? Farbe.text1 : Farbe.text3)
                    }
                    Text("Das dauert meist ein bis drei Minuten; die App ist dabei kurz ohne Verbindung.")
                        .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                } else if u.updateVerfuegbar == true {
                    Text("Update bereit: \(u.verfuegbar ?? "neue Fassung")").font(Schrift.karte).foregroundStyle(Farbe.text1)
                    ForEach(u.neuerungen, id: \.sha) { n in
                        Text("• \(n.titel)").font(Schrift.klein).foregroundStyle(Farbe.text2)
                    }
                    if Hausgeraet.schonGescheitert(u) {
                        Text("Diese Fassung kam beim letzten Versuch nicht gesund hoch; das Gerät ist zur vorherigen zurückgekehrt.")
                            .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                    Button { nachfrage = .update } label: {
                        Text(Hausgeraet.schonGescheitert(u) ? "Erneut versuchen" : "Update installieren")
                            .font(Schrift.karte).foregroundStyle(Farbe.deep)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Farbe.amber)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Duck Curve ist auf dem neuesten Stand.").font(Schrift.klein).foregroundStyle(Farbe.text2)
                }
                if !Hausgeraet.updateLaeuft(u), let e = Hausgeraet.updateErgebnis(u) {
                    Text(e).font(Schrift.winzig).foregroundStyle(Farbe.text2)
                }
                if !Hausgeraet.updateLaeuft(u) {
                    Button("Jetzt nach Updates sehen") { Task { await updateAnfragen(.pruefen) } }
                        .font(Schrift.klein).foregroundStyle(Farbe.amber).buttonStyle(.plain)
                }
            }
        }
    }

    private var neustartkarte: some View {
        Karte(kicker: "Neu starten") {
            HStack(spacing: 8) {
                knopfzeile("Alle Dienste") { nachfrage = .alle }
                knopfzeile("Gerät") { nachfrage = .geraet }
            }
            Text("Das Gerät neu zu starten ist nur nötig, wenn ein Neustart der Dienste nicht hilft.")
                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
        }
    }

    private func protokollansicht(_ blatt: Protokollblatt) -> some View {
        NavigationStack {
            Group {
                if let f = blatt.fehler {
                    Leer(satz: f)
                } else if let p = blatt.inhalt {
                    ScrollView([.vertical]) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Geholt um \(Formate.hhmm(iso: p.erstelltAm)) · \(p.zeilen.count) Zeilen · Schlüssel und Passwörter sind durch *** ersetzt")
                                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                            Text(p.zeilen.isEmpty ? "(leer)" : p.zeilen.joined(separator: "\n"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Farbe.text2)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Leer(satz: "Das Gerät holt die letzten 300 Zeilen …")
                }
            }
            .background(Farbe.grund)
            .navigationTitle("Protokoll: \(Hausgeraet.dienstname(blatt.dienst))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { protokoll = nil }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Neu holen") { Task { await zeigeProtokoll(blatt.dienst) } }
                        .disabled(blatt.inhalt == nil && blatt.fehler == nil)
                }
            }
        }
    }

    // MARK: - Nachfragen

    private func titel(_ n: Nachfrage) -> String {
        switch n {
        case .dienst(let d): return "\(Hausgeraet.dienstname(d)) neu starten?"
        case .alle: return "Alle Dienste neu starten?"
        case .geraet: return "Gerät neu starten?"
        case .update: return "Update installieren?"
        }
    }

    private func knopf(_ n: Nachfrage) -> String {
        switch n {
        case .update: return "Jetzt installieren"
        default: return "Neu starten"
        }
    }

    private func frage(_ n: Nachfrage) -> String {
        switch n {
        case .dienst("postgres"): return "Die Datenbank startet neu; Rechenkern und Oberfläche verlieren kurz die Verbindung."
        case .dienst("api"): return "Der Rechenkern startet neu. Duck Curve regelt einige Sekunden nicht, und diese Seite ist so lange ohne Verbindung."
        case .dienst(let d): return "\(Hausgeraet.dienstname(d)) startet neu und ist einige Sekunden nicht erreichbar."
        case .alle: return "Alle Dienste starten nacheinander neu. Duck Curve regelt etwa eine Minute nicht; die Anlage läuft in dieser Zeit wie ohne Duck Curve."
        case .geraet: return "Das ganze Gerät startet neu. Es ist ein bis zwei Minuten nicht erreichbar und kommt von selbst wieder."
        case .update: return "Vorher wird die Datenbank gesichert. Während des Neustarts regelt Duck Curve etwa ein bis drei Minuten nicht. Kommt die neue Fassung nicht gesund hoch, kehrt das Gerät von selbst zur jetzigen zurück."
        }
    }

    private func ausfuehren(_ n: Nachfrage) {
        Task {
            switch n {
            case .dienst(let d): await anfragen(.neustart, dienst: d)
            case .alle: await anfragen(.neustart, dienst: "alle")
            case .geraet: await anfragen(.geraetNeustart)
            case .update: await updateAnfragen(.installieren)
            }
        }
    }

    // MARK: - Laden und Anfragen

    private func lade() async {
        do {
            geraet = try await haus.api.geraet()
            fehler = nil
        } catch let f as ApiFehler {
            // Während eines Neustarts antwortet der Dienst eine Weile nicht; die Seite behält,
            // was sie hat, und sagt es.
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
        update = (try? await haus.api.update()) ?? update
    }

    private func anfragen(_ aktion: GeraetAktionInAktionWahl, dienst: String? = nil) async {
        hinweis = nil
        do {
            try await haus.api.geraetAktion(aktion, dienst: dienst)
            eiligBis = Date().addingTimeInterval(20)
            await lade()
        } catch let f as ApiFehler {
            hinweis = f.meldung
        } catch {
            hinweis = error.localizedDescription
        }
    }

    private func updateAnfragen(_ aktion: UpdateAnfrageInAktionWahl) async {
        hinweis = nil
        do {
            update = try await haus.api.updateAnfragen(aktion)
            eiligBis = Date().addingTimeInterval(20)
        } catch let f as ApiFehler {
            hinweis = f.meldung
        } catch {
            hinweis = error.localizedDescription
        }
    }

    /// Anfragen, dann warten, bis das Gerät eine Datei geschrieben hat, die neuer ist als die Anfrage.
    private func zeigeProtokoll(_ dienst: String) async {
        protokoll = Protokollblatt(dienst: dienst)
        let seit = Date().addingTimeInterval(-2)
        do {
            try await haus.api.geraetAktion(.protokoll, dienst: dienst)
        } catch let f as ApiFehler {
            protokoll?.fehler = f.meldung
            return
        } catch {
            protokoll?.fehler = error.localizedDescription
            return
        }
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(1500))
            guard protokoll?.dienst == dienst else { return }
            if let p = try? await haus.api.geraetProtokoll(dienst), p.vorhanden,
               let am = p.erstelltAm, let d = ISO8601DateFormatter.lies(am), d >= seit {
                protokoll?.inhalt = p
                return
            }
        }
        protokoll?.fehler = "Das Gerät hat das Protokoll nicht geliefert. Läuft dort der Anfrage-Dienst?"
    }
}

private extension ISO8601DateFormatter {
    static func lies(_ iso: String) -> Date? {
        let mit = ISO8601DateFormatter()
        mit.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = mit.date(from: iso) { return d }
        return ISO8601DateFormatter().date(from: iso)
    }
}
