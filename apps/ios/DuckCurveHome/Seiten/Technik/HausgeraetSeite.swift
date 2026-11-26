import Charts
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
    @State private var spanne: GeraetVerlaufOutSpanneWahl = .tag
    @State private var verlauf: GeraetVerlaufOut?

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
        // Auch ohne Verbindung: die Seite versucht es dann im kurzen Takt weiter, wie das
        // Dashboard (`useGeraet.ts`, `eilig || unerreichbar`).
        Hausgeraet.beschaeftigt(geraet) || Hausgeraet.updateLaeuft(update) || Date() < eiligBis
            || ohneVerbindung
    }

    /// Antwortet der Dienst gerade nicht, obwohl der Zugang stimmt? Nur dann gilt der Satz „Gerade
    /// keine Verbindung“. Ein abgelehnter Zugang (Token widerrufen, Rolle reicht nicht) ist
    /// etwas anderes: dort hilft Warten nicht, und die Störung muss sagen, was zu tun ist.
    private var ohneVerbindung: Bool { fehler?.istOhneVerbindung ?? false }

    var body: some View {
        Seite {
            // Ohne einen Bericht steht die Störung allein da. Mit einem Bericht bleibt er stehen,
            // und der Satz unter dem Urteil sagt, dass gerade keine Verbindung besteht
            // (`Geraet.tsx`, `unerreichbar`). Das gilt nur für eine fehlende Verbindung: ein
            // abgelehnter Zugang behält seine Störung mit dem Rat, was zu tun ist, auch über
            // einem alten Bericht.
            if let fehler, geraet == nil || !ohneVerbindung {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let g = geraet {
                urteil(g)
                if let hinweis {
                    Text(hinweis).font(Schrift.klein).foregroundStyle(Farbe.alarmText)
                } else if let satz = Hausgeraet.aktionssatz(g) {
                    Text(satz.text).font(Schrift.klein)
                        .foregroundStyle(satz.fehler ? Farbe.alarmText : Farbe.text2)
                }
                if g.unterstuetzt { dienstkarte(g) }
                apikarte(g.api)
                if let r = g.rechner { rechnerkarte(r) }
                if let ssd = g.rechner?.ssd { ssdkarte(ssd) }
                if let teile = Hausgeraet.platz(g) { platzkarte(teile, datenbank: g.api.datenbankBytes) }
                if g.unterstuetzt, let v = verlauf, v.unterstuetzt { verlaufskarten(v) }
                if let s = g.sicherung { sicherungskarte(s) }
                if !g.einheiten.isEmpty { einheitenkarte(g.einheiten) }
                softwarekarte
                if g.unterstuetzt { neustartkarte }
            } else if fehler == nil {
                Karte { Ladeente(satz: Ladehinweis.berichtssatz, stufe: .gross) }
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
        .task(id: spanne) {
            // Neue Punkte legt die API alle fünf Minuten an.
            while !Task.isCancelled {
                verlauf = (try? await haus.api.geraetVerlauf(spanne)) ?? verlauf
                try? await Task.sleep(for: .seconds(300))
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

    /// Das Zeichen einer Ampel, ein wenig abgesetzt, damit es auf der ersten Zeile des Textes steht.
    private func punkt(_ ampel: Hausgeraet.Ampel, gross: Bool = false) -> some View {
        Zustandszeichen(ampel: ampel, gross: gross)
            .padding(.top, 1)
    }

    private func zeile(_ ampel: Hausgeraet.Ampel?, _ titel: String, _ text: String? = nil, rechts: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let ampel { punkt(ampel) } else { Color.clear.frame(width: 16, height: 16) }
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
            // Rund wie die Knöpfe im Dashboard (`globals.css`, `.zugang-knopf`).
            Text(wort)
                .font(Schrift.sans(13))
                .foregroundStyle(gesperrt ? Farbe.text3 : Farbe.text1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Farbe.linie2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(gesperrt)
    }

    /// Das Urteil oben auf der Seite, als Zustandskarte wie auf „Einstellen“: grün, wenn alles in
    /// Ordnung ist, sonst in der Farbe der Ampel (`globals.css`, `.einstellen-status`).
    private func urteil(_ g: GeraetOut) -> some View {
        let ampel = Hausgeraet.Ampel(g.ampel?.rawValue)
        let farbe: Color = {
            switch ampel {
            case .gut: return Farbe.gut
            case .warn: return Farbe.amberWeich
            case .schlecht: return Farbe.alarm
            case .aus: return Farbe.mist
            }
        }()
        return HStack(alignment: .center, spacing: 14) {
            Zustandszeichen(ampel: ampel, gross: true)
                .frame(width: 44, height: 44)
                .background(farbe.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(ampel == .gut ? "Alles in Ordnung." : (g.textDe ?? ""))
                    .font(Schrift.sansHalbfett(19, relativeTo: .title3)).foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    ohneVerbindung
                        ? "Gerade keine Verbindung. Vielleicht startet die API neu; die Seite versucht es weiter."
                        : g.unterstuetzt
                        ? "Bericht des Geräts von \(Formate.hhmm(iso: g.berichtAm))"
                            + (g.berichtAlt == true ? ". Er ist veraltet, weil der Zeitgeber auf dem Gerät nicht läuft." : ".")
                        : "Diese Installation läuft nicht auf dem Hausgerät; hier steht nur, was die API über sich selbst weiß."
                )
                .font(Schrift.sans(14, relativeTo: .footnote)).foregroundStyle(Farbe.text2)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
        .background {
            ZStack {
                Farbe.flaeche1
                RadialGradient(colors: [farbe.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 320)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(farbe.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func dienstkarte(_ g: GeraetOut) -> some View {
        Kontokarte(zeichen: Hausgeraet.zeichen("Dienste"), titel: "Dienste", satz: nil) {
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
                        // Wie im Dashboard: CPU auch dann, wenn das Gerät keinen Speicher messen kann.
                        let last = [
                            d.cpuProzent.map { "\(Formate.zahl($0, stellen: 1)) % CPU" },
                            d.speicherMb.map { "\(Formate.zahl($0, stellen: 0)) MB" },
                        ].compactMap { $0 }
                        if !last.isEmpty {
                            Text(last.joined(separator: " · "))
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
        Kontokarte(
            zeichen: Hausgeraet.zeichen("Rechenkern"), titel: "Rechenkern",
            satz: "läuft seit \(Hausgeraet.dauer(sekunden: api.laufzeitS))"
        ) {
            zeile(Hausgeraet.Ampel(api.ampel?.rawValue), api.textDe ?? "")
            zeile(
                api.datenbankOk == false ? .schlecht : api.datenbankOk == true ? .gut : .aus,
                "Datenbank", api.datenbankDe
            )
            ForEach(api.quellen, id: \.name) { q in
                zeile(q.online ? .gut : (q.detailDe ?? "").hasPrefix("nicht eingerichtet") ? .aus : .warn, q.name, [q.detailDe ?? "", q.lastOk.map { "zuletzt \(Formate.hhmm(iso: $0))" } ?? ""]
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
        Kontokarte(zeichen: Hausgeraet.zeichen("Gerät"), titel: "Gerät", satz: r.modell ?? r.name) {
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
            // Die Uhr nur, wenn sie bekannt ist: Ohne `timedatectl` (Railway, Entwicklung) ist
            // `zeitSynchron` nil, und dann schweigt die Seite darüber, statt dauerhaft zu warnen.
            // Am 22.11.2026 ging die Uhr des Geräts drei Minuten nach, und keine Seite sagte es.
            if let synchron = r.zeitSynchron {
                zeile(Hausgeraet.Ampel(r.zeitAmpel?.rawValue), "Uhr",
                      synchron ? "Wird laufend gegen einen Zeitserver gestellt." : r.zeitDe,
                      rechts: r.zeitzone)
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
            if let cpu = r.cpuProzent {
                zeile(nil, "CPU-Auslastung", r.taktMhz.map { "Takt gerade \(Int($0)) MHz" },
                      rechts: "\(Hausgeraet.kurz(cpu, stellen: 1)) %")
            }
            if let v = r.eingangsspannungV {
                zeile(Hausgeraet.Ampel(r.spannungAmpel?.rawValue), "Eingangsspannung",
                      "Spannung am Netzteil- oder PoE-Eingang", rechts: "\(Formate.zahl(v, stellen: 2)) V")
            }
            if let swap = r.swapGesamtMb, swap > 0 {
                zeile(nil, "Auslagerung (Swap)", rechts: "\(swap - (r.swapFreiMb ?? 0)) von \(swap) MB")
            }
            if let n = r.netz {
                zeile(nil, "Netzwerk (\(n.schnittstelle))", "seit dem Start des Geräts",
                      rechts: "↓ \(Hausgeraet.bytes(n.empfangenBytes)) · ↑ \(Hausgeraet.bytes(n.gesendetBytes))")
            }
            let technik = [r.system, r.kernel.map { "Kernel \($0)" }, r.docker.map { "Docker \($0)" }].compactMap { $0 }
            if !technik.isEmpty {
                Text(technik.joined(separator: " · ")).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func ssdkarte(_ s: GeraetSsdOut) -> some View {
        Kontokarte(zeichen: Hausgeraet.zeichen("SSD-Gesundheit"), titel: "SSD-Gesundheit", satz: s.modell) {
            zeile(Hausgeraet.Ampel(s.ampel?.rawValue), s.textDe ?? "", "/dev/\(s.geraet)")
            if let a = s.abnutzungProzent {
                zeile(nil, "Abnutzung", s.reserveProzent.map { "Reserve-Blöcke: \(Hausgeraet.kurz($0, stellen: 0)) %" },
                      rechts: "\(Hausgeraet.kurz(a, stellen: 0)) %")
            }
            if let t = s.temperaturC { zeile(nil, "Temperatur", rechts: "\(Hausgeraet.kurz(t, stellen: 0)) °C") }
            if let h = s.betriebsstunden {
                zeile(nil, "Betriebsstunden", rechts: "\(h) h (\(Hausgeraet.kurz(Double(h) / 8760, stellen: 1)) Jahre)")
            }
            if s.geschriebenBytes != nil {
                zeile(nil, "Geschrieben / gelesen", "seit Herstellung",
                      rechts: "\(Hausgeraet.bytes(s.geschriebenBytes)) / \(Hausgeraet.bytes(s.gelesenBytes))")
            }
            if let f = s.fehler { zeile(f > 0 ? .warn : .gut, "Lesefehler", rechts: "\(f)") }
            if let u = s.unsichereAbschaltungen {
                zeile(nil, "Unsaubere Abschaltungen", "Strom weg, ohne herunterzufahren", rechts: "\(u)")
            }
        }
    }

    /// Bernstein und Blau wie im Dashboard (`components/geraet/Verlauf.tsx`), dort mit dem
    /// Palettenprüfer gegen die Kartenfläche geprüft. Das Blau ist nicht `Farbe.wallbox`: Dessen
    /// alter Ton fiel im Dashboard durch und wurde dort ersetzt.
    private static let blau = Color(Farbwert(0x2F89B5))

    private func platzfarbe(_ art: String) -> Color {
        switch art {
        case "programme": return Self.blau
        case "daten": return Farbe.pv
        case "sicherungen": return Farbe.haus
        case "rest": return Farbe.text3
        default: return .clear
        }
    }

    private func platzkarte(_ teile: [Hausgeraet.Platzteil], datenbank: Int?) -> some View {
        let summe = max(1, teile.reduce(0) { $0 + $1.bytes })
        return Kontokarte(zeichen: Hausgeraet.zeichen("Platz auf der SSD"), titel: "Platz auf der SSD", satz: nil) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(teile.filter { $0.bytes > 0 && $0.art != "frei" }, id: \.name) { t in
                        Rectangle().fill(platzfarbe(t.art))
                            .frame(width: max(2, geo.size.width * Double(t.bytes) / Double(summe)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 12)
            .background(Farbe.flaeche3)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityHidden(true)
            ForEach(teile, id: \.name) { t in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(platzfarbe(t.art)).frame(width: 10, height: 10)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Farbe.linie2, lineWidth: t.art == "frei" ? 1 : 0))
                    Text(t.name).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    Spacer(minLength: 8)
                    Text(Hausgeraet.bytes(t.bytes)).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
                    Text("\(Int((Double(t.bytes) / Double(summe) * 100).rounded())) %")
                        .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3).frame(width: 40, alignment: .trailing)
                }
            }
            if let db = datenbank {
                Text("Davon die Datenbank selbst: \(Hausgeraet.bytes(db)).").font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
        }
    }

    private func verlaufskarten(_ v: GeraetVerlaufOut) -> some View {
        let s = v.schrittMin ?? 5
        let p = v.punkte
        func linie(_ name: String, _ farbe: Color, _ wert: @escaping (GeraetVerlaufPunktOut) -> Double?) -> Verlaufsdiagramm.Reihe {
            .init(name: name, farbe: farbe, punkte: Hausgeraet.linie(p, schrittMin: s, wert))
        }
        let temperatur = [
            linie("Rechner", Farbe.pv) { $0.temperaturC },
            linie("SSD", Self.blau) { $0.ssdTemperaturC },
        ].filter { !$0.punkte.isEmpty }
        let daten = [
            linie("Datenbank", Farbe.pv) { $0.datenbankBytes.map { Double($0) / 1e6 } },
            linie("Sicherungen", Self.blau) { $0.sicherungBytes.map { Double($0) / 1e6 } },
        ].filter { !$0.punkte.isEmpty }
        // Nur Dienste mit echter Messung; ohne Speicherabrechnung meldete das Gerät 0 MB.
        let dienste = Array(Set(p.flatMap { $0.dienste.keys }))
            .filter { d in p.contains { ($0.dienste[d]?.speicherMb ?? 0) > 0 } }
            .sorted()
        let ramGesamt = p.compactMap(\.speicherGesamtMb).last
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Zeichen(Hausgeraet.zeichen("Verlauf"), groesse: 20, farbe: Farbe.mist)
                    .frame(width: 36, height: 36)
                    .background(Farbe.mist.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text("Verlauf").font(Schrift.sansHalbfett(16, relativeTo: .headline)).foregroundStyle(Farbe.text1)
                Spacer()
                Picker("Spanne", selection: $spanne) {
                    Text("Tag").tag(GeraetVerlaufOutSpanneWahl.tag)
                    Text("Woche").tag(GeraetVerlaufOutSpanneWahl.woche)
                    Text("Monat").tag(GeraetVerlaufOutSpanneWahl.monat)
                    Text("Jahr").tag(GeraetVerlaufOutSpanneWahl.jahr)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }
            ForEach(Hausgeraet.prognosesaetze(v.prognose), id: \.self) { satz in
                Text(satz).font(Schrift.klein).foregroundStyle(Farbe.text2).fixedSize(horizontal: false, vertical: true)
            }
            if p.isEmpty {
                Karte { Leer(satz: "Noch keine Messpunkte in dieser Spanne.", dazu: "Das Gerät legt alle fünf Minuten einen an.") }
            }
            Verlaufsdiagramm(titel: "SSD belegt", einheit: "%", stellen: 1, reihen: [linie("belegt", Farbe.pv) {
                guard let b = $0.platteBelegtBytes, let g = $0.platteGesamtBytes, g > 0 else { return nil }
                return Double(b) / Double(g) * 100
            }], grenze: 85, bereich: 0...100)
            if !temperatur.isEmpty {
                Verlaufsdiagramm(titel: "Temperatur", einheit: "°C", stellen: 1, reihen: temperatur, grenze: 80)
            }
            Verlaufsdiagramm(titel: "CPU-Auslastung", einheit: "%", stellen: 1, reihen: [linie("Auslastung", Farbe.pv) { $0.cpuProzent }])
            Verlaufsdiagramm(titel: "Arbeitsspeicher belegt", einheit: "GB", stellen: 2,
                             reihen: [linie("belegt", Self.blau) { $0.speicherBelegtMb.map { $0 / 1024 } }],
                             grenze: ramGesamt.map { $0 / 1024 })
            Verlaufsdiagramm(titel: "Netzwerk", einheit: "kB/s", stellen: 1, reihen: [
                linie("empfangen", Self.blau) { ($0.netzEmpfangenBytesS ?? 0) / 1000 },
                linie("gesendet", Farbe.pv) { ($0.netzGesendetBytesS ?? 0) / 1000 },
            ])
            if !daten.isEmpty {
                Verlaufsdiagramm(titel: "Datenbank und Sicherungen", einheit: "MB", stellen: 1, reihen: daten)
            }
            Verlaufsdiagramm(titel: "Eingangsspannung", einheit: "V", stellen: 2,
                             reihen: [linie("tiefster Wert", Farbe.pv) { $0.eingangsspannungVMin }], grenze: 4.85,
                             bereich: 4.5...5.3)
            ForEach(dienste, id: \.self) { d in
                Verlaufsdiagramm(titel: "\(Hausgeraet.dienstname(d)): Speicher", einheit: "MB", stellen: 0,
                                 reihen: [linie("Speicher", Farbe.mist) { $0.dienste[d]?.speicherMb }], hoehe: 90)
            }
        }
    }

    private func sicherungskarte(_ s: GeraetSicherungOut) -> some View {
        Kontokarte(zeichen: Hausgeraet.zeichen("Sicherung"), titel: "Sicherung", satz: nil) {
            zeile(Hausgeraet.Ampel(s.ampel?.rawValue), s.textDe ?? "")
            if let letzte = s.letzte {
                zeile(nil, "Letzte Sicherung", letzte, rechts: Formate.hhmm(iso: s.letzteAm))
            }
            zeile(nil, "Kopie außer Haus", s.ausserHaus ?? "keine (DCH_SICHERUNG_ZIEL in .env)")
            knopfzeile("Jetzt sichern") { Task { await anfragen(.sichern) } }
        }
    }

    private func einheitenkarte(_ einheiten: [GeraetEinheitOut]) -> some View {
        Kontokarte(zeichen: Hausgeraet.zeichen("Abläufe auf dem Gerät"), titel: "Abläufe auf dem Gerät", satz: nil) {
            ForEach(einheiten, id: \.name) { e in
                zeile(Hausgeraet.Ampel(e.ampel?.rawValue), Hausgeraet.einheitennamen[e.name] ?? e.beschreibung ?? e.name,
                      (e.textDe ?? "") + (e.naechsterLauf.map { " Nächster Lauf \(Formate.hhmm(iso: $0))." } ?? ""))
            }
        }
    }

    @ViewBuilder private var softwarekarte: some View {
        if let u = update, u.unterstuetzt == true {
            Kontokarte(zeichen: Hausgeraet.zeichen("Software"), titel: "Software", satz: u.kanal.map { "Kanal \($0)" }) {
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
        Kontokarte(zeichen: Hausgeraet.zeichen("Neu starten"), titel: "Neu starten", satz: nil) {
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
                    // Alfred in der großen Stufe, wie auf der Seite darunter: dieses Blatt
                    // zeigt, solange es holt, nichts weiter als diesen Satz
                    // (``Ladehinweis/Stufe``). Der Fehlerfall steht darüber und bekommt
                    // keine Ente.
                    Ladeente(satz: "Das Gerät holt die letzten 300 Zeilen …", stufe: .gross)
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


/// Ein kleines Diagramm im Verlauf: eine Größe, höchstens zwei Reihen derselben Einheit.
///
/// **Eine Größe je Diagramm**, wie im Dashboard: zwei y-Achsen verleiten dazu, Zusammenhänge zu
/// lesen, die es nicht gibt. Ein Finger auf dem Diagramm zeigt die Werte an dieser Stelle.
/// Ohne Werte erscheint es gar nicht - eine leere Fläche „Eingangsspannung“ auf einem Rechner,
/// der sie nicht misst, wäre nur Lärm.
struct Verlaufsdiagramm: View {
    struct Reihe {
        let name: String
        let farbe: Color
        let punkte: [Hausgeraet.Linienpunkt]
    }

    let titel: String
    let einheit: String
    let stellen: Int
    let reihen: [Reihe]
    var grenze: Double?
    var bereich: ClosedRange<Double>?
    var hoehe: CGFloat = 130

    @State private var auswahl: Date?

    private var mitWerten: [Reihe] { reihen.filter { !$0.punkte.isEmpty } }

    var body: some View {
        if !mitWerten.isEmpty {
            Karte(kicker: titel, titel: mitWerten.count > 1 ? nil : einheit) {
                if mitWerten.count > 1 {
                    HStack(spacing: 12) {
                        ForEach(mitWerten, id: \.name) { r in
                            HStack(spacing: 5) {
                                Capsule().fill(r.farbe).frame(width: 12, height: 3)
                                Text(r.name).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                            }
                        }
                        Spacer()
                        Text(einheit).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    }
                }
                diagramm
                    .frame(height: hoehe)
                if let auswahl, let text = ablesung(auswahl) {
                    Text(text).font(Schrift.zahlKlein).foregroundStyle(Farbe.text2)
                }
            }
        }
    }

    private var diagramm: some View {
        Chart {
            ForEach(mitWerten, id: \.name) { r in
                ForEach(r.punkte) { p in
                    LineMark(
                        x: .value("Zeit", p.t),
                        y: .value(einheit, p.wert),
                        series: .value("Reihe", "\(r.name)-\(p.stueck)")
                    )
                    .foregroundStyle(r.farbe)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            if let grenze {
                RuleMark(y: .value("Grenze", grenze))
                    .foregroundStyle(Farbe.alarm.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            if let auswahl {
                RuleMark(x: .value("Auswahl", auswahl))
                    .foregroundStyle(Farbe.text3)
            }
        }
        .chartXSelection(value: $auswahl)
        .chartYScale(domain: bereich ?? automatischerBereich)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Farbe.linie1)
                AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Farbe.linie1)
                AxisValueLabel().font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
        }
        .accessibilityLabel(titel)
    }

    private var automatischerBereich: ClosedRange<Double> {
        let werte = mitWerten.flatMap { $0.punkte.map(\.wert) } + (grenze.map { [$0] } ?? [])
        let lo = min(0, werte.min() ?? 0)
        let hi = max(werte.max() ?? 1, lo + 0.1)
        return lo...(hi * 1.08)
    }

    /// Die Werte am nächsten Punkt jeder Reihe: „14:05 · Rechner 52,1 °C · SSD 41 °C“.
    private func ablesung(_ t: Date) -> String? {
        var teile: [String] = []
        for r in mitWerten {
            guard let p = r.punkte.min(by: { abs($0.t.timeIntervalSince(t)) < abs($1.t.timeIntervalSince(t)) }) else { continue }
            let name = mitWerten.count > 1 ? "\(r.name) " : ""
            teile.append("\(name)\(Hausgeraet.kurz(p.wert, stellen: stellen)) \(einheit)")
        }
        guard !teile.isEmpty else { return nil }
        return ([Formate.hhmm(t)] + teile).joined(separator: " · ")
    }
}

/// Der Hinweis über jeder Seite, wenn für das Hausgerät ein Update bereitsteht - wie
/// `UpdateHinweis.tsx` im Dashboard. Nur für den Hausherrn, nicht auf der Seite Hausgerät selbst,
/// und „Nicht jetzt“ gilt für genau diese Fassung (im Gerät gemerkt): Kommt eine neuere, steht er
/// wieder da. Ob er erscheint, entscheidet `Hausgeraet.zeigeHinweis` im Kern.
struct Updatehinweis: View {
    @Environment(Hauszustand.self) private var haus
    let wegweiser: Wegweiser

    @State private var status: UpdateStatusOut?
    @AppStorage("dch-update-weg") private var weggeklickt = ""

    var body: some View {
        Group {
            if let s = status,
               Hausgeraet.zeigeHinweis(s, weg: wegweiser.weg, hausherr: haus.hatVollzugriff,
                                       weggeklickt: weggeklickt.isEmpty ? nil : weggeklickt) {
                HStack(alignment: .center, spacing: 10) {
                    Text(Hausgeraet.hinweissatz(s))
                        .font(Schrift.klein).foregroundStyle(Farbe.text1)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button(Hausgeraet.updateLaeuft(s) ? "Ansehen" : "Ansehen und installieren") {
                        wegweiser.gehe("/system/geraet")
                    }
                    .font(Schrift.klein.weight(.semibold))
                    .foregroundStyle(Farbe.deep)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Farbe.amber)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    if !Hausgeraet.updateLaeuft(s) {
                        Button("Nicht jetzt") { weggeklickt = s.verfuegbar ?? "" }
                            .font(Schrift.klein).foregroundStyle(Farbe.text3).buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Farbe.flaeche2)
                .overlay(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous).stroke(Farbe.linie2))
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
            }
        }
        .task(id: haus.hatVollzugriff) {
            // Gäste fragen gar nicht erst. Im Ruhezustand alle fünf Minuten - das Gerät selbst
            // sieht nur alle sechs Stunden nach; während eines Updates alle fünf Sekunden.
            guard haus.hatVollzugriff else { return }
            while !Task.isCancelled {
                status = (try? await haus.api.update()) ?? status
                try? await Task.sleep(for: .seconds(Hausgeraet.updateLaeuft(status) ? 5 : 300))
            }
        }
    }
}
