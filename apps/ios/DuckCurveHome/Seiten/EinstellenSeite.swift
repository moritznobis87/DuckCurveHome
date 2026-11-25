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
///
/// **Das Bild der Übersichten** (seit dem 24.11.2026): oben eine Zustandskarte, grün, wenn alles
/// die Automatik regelt, bernsteinfarben mit den Eingriffen und dem Knopf, wenn etwas von Hand
/// gestellt ist. Jede Stufe ist eine Karte mit eigenem Zeichen und eigener Farbe, jede
/// Einstellung hat ihr Zeichen; beides steht im Seitenbaum, wie im Dashboard.
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

    @AppStorage(Startbild.merker) private var startbildGemerkt = Startbild.vorgabe.rawValue
    private var hausherr: Bool { haus.hatVollzugriff }

    var body: some View {
        Seite {
            VStack(alignment: .leading, spacing: 22) {
                suchfeld
                if !suche.trimmingCharacters(in: .whitespaces).isEmpty { treffer }
                zustandskarte
                startbildkarte
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
            .frame(maxWidth: 1040, alignment: .leading)
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
        HStack(spacing: 10) {
            Zeichen(.lupe, groesse: 18, farbe: Farbe.text3)
                .accessibilityHidden(true)
            TextField(Einstellworte.suchfeld, text: $suche)
                .textFieldStyle(.plain)
                .font(Schrift.text)
                .foregroundStyle(Farbe.text1)
                .autocorrectionDisabled()
                .accessibilityLabel("Einstellung suchen")
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.vertical, 13)
        .background(Farbe.flaeche1)
        .overlay(Capsule().strokeBorder(Farbe.linie1, lineWidth: 1))
        .clipShape(Capsule())
    }

    @ViewBuilder private var treffer: some View {
        let gefunden = Bereiche.suche(suche, hausherr: hausherr)
        if gefunden.isEmpty {
            hinweis(Einstellworte.nichtsGefunden)
        } else {
            zeilen(gefunden)
                .padding(6)
                .background(Farbe.flaeche1)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(Farbe.linie1, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
    }

    // MARK: - Die Zustandskarte

    /// Die Farbe des Zustands: grün auf Automatik, bernsteinfarben bei einem Eingriff, das
    /// ruhige Grau, solange der Stand nicht da ist (`globals.css`, `.einstellen-status`).
    private var zustandsfarbe: Color {
        guard let stand else { return Seitenfarbe.ruhig.farbe }
        return stand.eingriffe.isEmpty ? Farbe.gut : Farbe.amberWeich
    }

    /// Welches Bild die Mitte der Startseite trägt: die Bühne oder die Uhr.
    ///
    /// Der Hausherr hat am 25.11.2026 beide bauen lassen und die Umschaltung hierher gelegt. Die
    /// Wahl gilt für dieses Gerät und liegt in seinem Speicher, darum darf sie jeder treffen,
    /// der die Seite sieht (`Einstellen.tsx`, `Startbildkarte`).
    private var startbildkarte: some View {
        Kontokarte(zeichen: .anzeige, titel: Startbild.titel, satz: Startbild.frage) {
            let anordnung =
                schmal
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            anordnung {
                ForEach(Startbild.allCases) { bild in
                    startbildknopf(bild)
                }
            }
        }
    }

    private func startbildknopf(_ bild: Startbild) -> some View {
        let gewaehlt = Startbild.aus(startbildGemerkt) == bild
        let form = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            startbildGemerkt = bild.rawValue
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Startzeichenfeld(art: bild == .uhr ? .uhr : .haus, farbe: gewaehlt ? Farbe.amber : Farbe.text3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(bild.name)
                        .font(Schrift.sansHalbfett(15))
                        .foregroundStyle(Farbe.text1)
                    Text(bild.satz)
                        .font(Schrift.sans(13))
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(form.fill(gewaehlt ? Farbe.amber.opacity(0.09) : Color.clear))
            .overlay(form.stroke(gewaehlt ? Farbe.amber : Farbe.linie2, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : .isButton)
    }

    private var zustandskarte: some View {
        let eingriffe = stand?.eingriffe ?? []
        let zurueck = eingriffe.filter { $0.zuruecksetzbar == true }
        let text = Einstellworte.zustand(stand.map { $0.eingriffe.count })
        let farbe = zustandsfarbe
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Group {
                    if !eingriffe.isEmpty {
                        Zeichen(.schieber, groesse: 22, farbe: farbe)
                    } else {
                        Zustandszeichen(ampel: stand == nil ? .aus : .gut, gross: true)
                    }
                }
                .frame(width: 44, height: 44)
                .background(farbe.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.titel)
                        .font(Schrift.sansHalbfett(19, relativeTo: .title3))
                        .foregroundStyle(Farbe.text1)
                    Text(fehler ?? text.satz)
                        .font(Schrift.sans(14, relativeTo: .footnote))
                        .foregroundStyle(Farbe.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(eingriffe.enumerated()), id: \.offset) { _, e in
                eingriffszeile(e)
            }
            if let meldung {
                Text(meldung)
                    .font(Schrift.sans(14, relativeTo: .footnote))
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if haus.darfSchalten, !zurueck.isEmpty {
                if fragt {
                    rueckfrage(zurueck, alle: eingriffe.count)
                } else {
                    knopf(Einstellworte.allesZurueck, zeichen: .kreis, hervor: true) { fragt = true }
                }
            }
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 20, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Farbe.flaeche1
                RadialGradient(
                    colors: [farbe.opacity(0.16), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 320)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(farbe.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private func eingriffszeile(_ e: HandeingriffOut) -> some View {
        Button {
            wegweiser.merkeReiter()
            wegweiser.gehe(e.weg)
        } label: {
            HStack(spacing: 12) {
                Zeichen(zeichen(e.art), groesse: 18, farbe: Farbe.amberWeich)
                    .frame(width: 32, height: 32)
                    .background(Farbe.amberWeich.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                Text(e.satzDe)
                    .font(Schrift.sans(14.5, relativeTo: .subheadline))
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                pfeil
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Farbe.deep.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Farbe.linie1, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .background(Farbe.deep.opacity(0.45))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Farbe.amber.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Die Stufen

    /// Am iPad stehen die Stufen nebeneinander, am Telefon untereinander
    /// (`globals.css`, `.einstellen-stufen`).
    private var stufen: some View {
        let sichtbar = Bereiche.stufen.filter { hausherr || !$0.nurHausherr }
        return LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 14, alignment: .top),
                count: schmal ? 1 : sichtbar.count),
            alignment: .leading, spacing: 14
        ) {
            ForEach(sichtbar) { stufe in
                let eintraege = Bereiche.einstellungen(derStufe: stufe.schluessel, hausherr: hausherr)
                if !eintraege.isEmpty { stufenkarte(stufe, eintraege) }
            }
        }
    }

    private func stufenkarte(_ stufe: Stufe, _ eintraege: [Einstellung]) -> some View {
        let farbe = stufe.farbe.farbe
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Zeichen(stufe.zeichen, groesse: 20, farbe: farbe)
                    .frame(width: 36, height: 36)
                    .background(farbe.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(stufe.name)
                        .font(Schrift.sansHalbfett(16, relativeTo: .headline))
                        .foregroundStyle(Farbe.text1)
                    Text(stufe.wort)
                        .font(Schrift.sans(13, relativeTo: .footnote))
                        .foregroundStyle(Farbe.text3)
                }
            }
            .padding(EdgeInsets(top: 0, leading: 6, bottom: 8, trailing: 6))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            zeilen(eintraege)
        }
        .padding(EdgeInsets(top: 16, leading: 12, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Farbe.flaeche1
                RadialGradient(
                    colors: [farbe.opacity(0.12), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 220)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
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

    /// Die Zeilen einer Stufe: Zeichen, Name, Pfeil (`globals.css`, `.einstellen-zeile`).
    private func zeilen(_ eintraege: [Einstellung]) -> some View {
        VStack(spacing: 2) {
            ForEach(eintraege) { e in
                Button {
                    wegweiser.merkeReiter()
                    wegweiser.gehe(e.weg)
                } label: {
                    HStack(spacing: 12) {
                        Zeichen(e.zeichen, groesse: 17, farbe: Farbe.text2)
                            .frame(width: 32, height: 32)
                            .background(Farbe.flaeche2)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .accessibilityHidden(true)
                        Text(e.name)
                            .font(Schrift.text)
                            .foregroundStyle(Farbe.text1)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        pfeil
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pfeil: some View {
        Text("›").font(Schrift.sans(18)).foregroundStyle(Farbe.text3)
            .accessibilityHidden(true)
    }

    private func hinweis(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.sans(14, relativeTo: .footnote))
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func knopf(
        _ wort: String, zeichen: Zeichenart? = nil, hervor: Bool, aktion: @escaping () -> Void
    ) -> some View {
        Button(action: aktion) {
            HStack(spacing: 8) {
                if let zeichen {
                    Zeichen(zeichen, groesse: 17, farbe: hervor ? Farbe.deep : Farbe.text1)
                        .accessibilityHidden(true)
                }
                Text(wort)
                    .font(hervor ? Schrift.sansHalbfett(14) : Schrift.sans(14))
                    .foregroundStyle(hervor ? Farbe.deep : Farbe.text1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(hervor ? Farbe.amber : Color.clear)
            .overlay(Capsule().strokeBorder(hervor ? Farbe.amber : Farbe.linie2, lineWidth: 1))
            .clipShape(Capsule())
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
