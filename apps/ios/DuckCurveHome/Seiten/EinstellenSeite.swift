import DuckCurveKit
import SwiftUI

/// Die Seite „Einstellen“, hinter dem Zahnrad.
///
/// Der Hausherr hat sie am 24.11.2026 so entschieden: oben, was gerade von Hand gestellt ist, mit
/// „Alles zurück auf Automatik“; darunter die Einstellungen in drei Stufen, von leicht nach
/// schwer; zuletzt die Seiten des Systems. **Die Einstellungen bleiben bei ihrem Gegenstand**:
/// Hier steht nur, wo man sie findet, und die Suche findet sie auch unter einem anderen Wort.
///
/// Das Gegenstück ist `apps/web/src/components/einstellen/Einstellen.tsx`, mit demselben Katalog
/// (``Bereiche/einstellungen``) und denselben Sätzen (``Einstellworte``). Jeder, der im Haus
/// stellen darf, sieht die Seite; „Abstimmen“ und die Systemseiten bleiben dem Hausherrn.
struct EinstellenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    @State private var suche = ""
    @State private var stand: HandeingriffeOut?
    @State private var fehler: String?
    @State private var meldung: String?
    @State private var fragt = false
    @State private var laeuft = false
    @State private var systemkarten: [String: UebersichtKarteOut] = [:]

    private var schmal: Bool { breite == .compact }
    private var hausherr: Bool { haus.hatVollzugriff }

    var body: some View {
        Seite {
            VStack(alignment: .leading, spacing: 26) {
                suchfeld
                if !suche.trimmingCharacters(in: .whitespaces).isEmpty { treffer }
                handeingriffe
                stufen
                if hausherr, let system = Bereiche.alle.first(where: { $0.schluessel == .system }) {
                    abschnitt(Einstellworte.system, wort: Einstellworte.systemWort) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: schmal ? 10 : 12, alignment: .top),
                                GridItem(.flexible(), spacing: schmal ? 10 : 12, alignment: .top),
                            ],
                            alignment: .leading, spacing: schmal ? 10 : 12
                        ) {
                            ForEach(system.reiter) { seite in
                                Seitenkachel(seite: seite, stand: systemkarten[seite.weg])
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
        }
        .task {
            while !Task.isCancelled {
                await lade()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    // MARK: - Teile

    private var suchfeld: some View {
        TextField(Einstellworte.suchfeld, text: $suche)
            .textFieldStyle(.plain)
            .font(Schrift.text)
            .foregroundStyle(Farbe.text1)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Farbe.flaeche1)
            .overlay(
                RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                    .strokeBorder(Farbe.linie1, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
            .accessibilityLabel("Einstellung suchen")
    }

    @ViewBuilder private var treffer: some View {
        let gefunden = Bereiche.suche(suche, hausherr: hausherr)
        if gefunden.isEmpty {
            hinweis(Einstellworte.nichtsGefunden)
        } else {
            liste(gefunden)
        }
    }

    private var handeingriffe: some View {
        let eingriffe = stand?.eingriffe ?? []
        let zurueck = eingriffe.filter { $0.zuruecksetzbar == true }
        return abschnitt(Einstellworte.vonHand, wort: eingriffe.isEmpty ? nil : "\(eingriffe.count)") {
            VStack(alignment: .leading, spacing: 8) {
                if let fehler { hinweis(fehler) }
                if stand != nil, eingriffe.isEmpty { hinweis(Einstellworte.leer) }
                ForEach(Array(eingriffe.enumerated()), id: \.offset) { _, e in
                    eingriffszeile(e)
                }
                if let meldung { hinweis(meldung) }
                if haus.darfSchalten, !zurueck.isEmpty {
                    if fragt {
                        rueckfrage(zurueck, alle: eingriffe.count)
                    } else {
                        knopf(Einstellworte.allesZurueck, hervor: false) { fragt = true }
                    }
                }
            }
        }
    }

    private func eingriffszeile(_ e: HandeingriffOut) -> some View {
        Button {
            wegweiser.merkeReiter()
            wegweiser.gehe(e.weg)
        } label: {
            HStack(spacing: 12) {
                Zeichen(zeichen(e.art), groesse: 18, farbe: Farbe.amberWeich)
                    .frame(width: 30, height: 30)
                    .background(Farbe.amberWeich.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                Text(e.satzDe)
                    .font(Schrift.sans(14.5, relativeTo: .subheadline))
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Farbe.flaeche1)
            .overlay(
                RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                    .strokeBorder(Farbe.amberWeich.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func rueckfrage(_ zurueck: [HandeingriffOut], alle: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Einstellworte.rueckfrage).font(Schrift.klein).foregroundStyle(Farbe.text1)
            ForEach(Array(zurueck.enumerated()), id: \.offset) { _, e in
                Text("• \(e.satzDe)").font(Schrift.klein).foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if alle > zurueck.count {
                Text(Einstellworte.raeumeBleiben).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                knopf(laeuft ? Einstellworte.stelltZurueck : Einstellworte.zurueckstellen, hervor: true) {
                    Task { await zuruecksetzen() }
                }
                .disabled(laeuft)
                knopf(Einstellworte.abbrechen, hervor: false) { fragt = false }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Farbe.flaeche1)
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(Farbe.amber, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private var stufen: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(Bereiche.stufen.filter { hausherr || !$0.nurHausherr }) { stufe in
                let eintraege = Bereiche.einstellungen(derStufe: stufe.schluessel, hausherr: hausherr)
                if !eintraege.isEmpty {
                    abschnitt(stufe.name, wort: stufe.wort) { liste(eintraege) }
                }
            }
        }
    }

    // MARK: - Bausteine

    private func abschnitt<Inhalt: View>(
        _ name: String, wort: String?, @ViewBuilder inhalt: () -> Inhalt
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Kicker(wort: name, groesse: 11)
                if let wort {
                    Text(wort).font(Schrift.klein).foregroundStyle(Farbe.text3)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            inhalt()
        }
    }

    private func liste(_ eintraege: [Einstellung]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(eintraege.enumerated()), id: \.element.id) { i, e in
                Button {
                    wegweiser.merkeReiter()
                    wegweiser.gehe(e.weg)
                } label: {
                    HStack {
                        Text(e.name).font(Schrift.text).foregroundStyle(Farbe.text1)
                        Spacer(minLength: 8)
                        Text("›").font(Schrift.sans(18)).foregroundStyle(Farbe.text3)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < eintraege.count - 1 {
                    Rectangle().fill(Farbe.linie1).frame(height: 1)
                }
            }
        }
        .background(Farbe.flaeche1)
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private func hinweis(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.sans(14, relativeTo: .footnote))
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func knopf(_ wort: String, hervor: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(wort)
                .font(hervor ? Schrift.sansHalbfett(14) : Schrift.sans(14))
                .foregroundStyle(hervor ? Farbe.deep : Farbe.text1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(hervor ? Farbe.amber : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(hervor ? Farbe.amber : Farbe.linie2, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func zeichen(_ art: HandeingriffOutArtWahl) -> Zeichenart {
        switch art {
        case .waermepumpe: return .waermepumpe
        case .ofen: return .ofen
        case .speicher: return .batterie
        case .raum, .unbekannt: return .thermometer
        }
    }

    // MARK: - Mit dem Dienst

    private func lade() async {
        do {
            stand = try await haus.api.handeingriffe()
            fehler = nil
        } catch {
            fehler = Einstellworte.nichtAbrufbar
        }
        // Die Karten des Systems liest nur der Hausherr: Die Übersicht des Systems ist eine Akte.
        if hausherr, let antwort = try? await haus.api.uebersicht("system") {
            var neu: [String: UebersichtKarteOut] = [:]
            for karte in antwort.karten { neu[karte.weg] = karte }
            systemkarten = neu
        }
    }

    private func zuruecksetzen() async {
        laeuft = true
        meldung = nil
        defer {
            laeuft = false
            fragt = false
        }
        do {
            let antwort = try await haus.api.automatikZurueck()
            stand = antwort.handeingriffe
            meldung = antwort.meldungDe
        } catch let f as ApiFehler {
            meldung = f.meldung
        } catch {
            meldung = Einstellworte.nichtDurch
        }
    }
}
