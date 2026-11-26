import DuckCurveKit
import SwiftUI

/// Die Seite „Mein Zugang“: wer angemeldet ist, die eigenen Passkeys, das Passwort, die
/// Sitzungen und das Abmelden.
///
/// Sie steht außerhalb der sechs Bereiche (`docs/seitenbaum.json`, `einzelseiten`) und ist für
/// **jede angemeldete Person** da, nicht nur für den Hausherrn. Der Hausherr hat das am
/// 24.11.2026 entschieden. Die Vorlage ist `apps/web/src/components/zugang/MeinZugang.tsx`, mit
/// denselben Worten (``Kontoworte``) und demselben Bild: oben eine Kopfkarte mit dem
/// Anfangsbuchstaben, der Rolle als Marke und drei Zahlen, darunter je eine Karte für Passkeys,
/// Passwort und Sitzungen.
///
/// **Was der App gegenüber dem Dashboard noch fehlt** (`docs/GLEICHSTAND.md`): einen Passkey
/// anlegen. Dafür braucht die App die Zuordnung zur Adresse des Dashboards (Associated Domains
/// mit der Team-ID). Umbenennen, Löschen, neue Codes und Sitzungen beenden kann sie.
struct KontoSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var ich: IchOut?
    @State private var fehler: String?
    @State private var laeuft = false
    @State private var codes: [String]?
    @State private var loeschen: PasskeyOut?
    @State private var umbenennen: PasskeyOut?
    @State private var neuerName = ""
    @State private var ueberallFragen = false
    /// Die Anmeldung als Person, von einem Gerät ohne eigenen Zugang aus.
    @State private var anmelden = false

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            if haus.zugang.istPerson {
                VStack(alignment: .leading, spacing: 16) {
                    kopfkarte
                    if let fehler {
                        Text(fehler).font(Schrift.sans(14)).foregroundStyle(Farbe.amberWeich)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    passkeykarte
                    MeinPasswortKarte()
                    sitzungskarte
                    abmelden
                }
                .frame(maxWidth: 820, alignment: .leading)
            } else {
                // **Ohne Person steht hier der Weg zur Anmeldung.** Ein Gerät, das mit dem
                // Schlüssel des Hauses eingerichtet ist, hat keinen eigenen Zugang. Der Hausherr
                // suchte am 26.11.2026 das Zeichen der Person und fand es nicht: es stand nur
                // für angemeldete Personen da, und der Weg zur Anmeldung lag drei Seiten tief
                // unter „Zugang und Sicherung“.
                Karte(kicker: Zugangsworte.meinZugangUeberschrift) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(haus.zugang.token.isEmpty ? Zugangsworte.keinePerson : Zugangsworte.geraetOhnePerson)
                            .font(Schrift.sans(15, relativeTo: .body))
                            .foregroundStyle(Farbe.text2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Zugangsknopf(wort: Zugangsworte.alsPersonAnmelden, art: .hervor) {
                            anmelden = true
                        }
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
            }
        }
        .sheet(isPresented: $anmelden) {
            Einrichten(vorgabe: .passwort)
        }
        // **Neu laden, wenn die Person wechselt.** Wer sich über das Blatt oben anmeldet, bleibt
        // auf dieser Seite: ein einfaches `.task` wäre schon gelaufen und an der Abfrage
        // „keine Person“ umgekehrt, und Passkeys und Sitzungen blieben leer, bis man die Seite
        // verlässt und wiederkommt.
        .task(id: haus.zugang.email) { await lade() }
        .confirmationDialog(
            Kontoworte.loeschfrage(loeschen?.name ?? ""), isPresented: Binding(
                get: { loeschen != nil }, set: { if !$0 { loeschen = nil } }),
            titleVisibility: .visible
        ) {
            Button(Kontoworte.loeschen, role: .destructive) {
                if let p = loeschen { fuehre { try await haus.api.loeschePasskey(p.id) } }
            }
        }
        .alert(
            Kontoworte.umbenennen, isPresented: Binding(
                get: { umbenennen != nil }, set: { if !$0 { umbenennen = nil } })
        ) {
            TextField("Name", text: $neuerName)
            Button("Übernehmen") {
                let name = neuerName.trimmingCharacters(in: .whitespaces)
                if let p = umbenennen, !name.isEmpty {
                    fuehre { try await haus.api.benennePasskey(p.id, name: name) }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog(Kontoworte.ueberallFrage, isPresented: $ueberallFragen, titleVisibility: .visible) {
            Button(Kontoworte.ueberallAbmelden, role: .destructive) {
                Task {
                    laeuft = true
                    do {
                        try await haus.api.beendeAlleSitzungen()
                        await haus.meldeAb()
                    } catch {
                        fehler = (error as? ApiFehler)?.meldung ?? Kontoworte.nichtGeklappt
                    }
                    laeuft = false
                }
            }
        }
    }

    // MARK: - Die Kopfkarte

    private var kopfkarte: some View {
        let email = ich?.ausweis.email ?? haus.zugang.email
        let name = (ich?.ausweis.name).flatMap { $0.isEmpty ? nil : $0 } ?? email
        let rolle = Kontoworte.rolle(ich?.ausweis.rolle.rawValue ?? haus.zugang.rolle.rawValue)
        let anfang = name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
        let person = HStack(alignment: .center, spacing: 16) {
            Text(anfang)
                .font(Schrift.sansHalbfett(24, relativeTo: .title))
                .foregroundStyle(Farbe.deep)
                .frame(width: 56, height: 56)
                .background(Farbe.amber)
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Schrift.sansHalbfett(19, relativeTo: .title3))
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                if !email.isEmpty, email != name {
                    Text(email).font(Schrift.sans(13.5)).foregroundStyle(Farbe.text3)
                }
                Umbruchzeile(abstand: 10, zeilenabstand: 4) {
                    Text(rolle.name)
                        .font(Schrift.sansHalbfett(12.5))
                        .foregroundStyle(Farbe.amberWeich)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Farbe.amber.opacity(0.18))
                        .clipShape(Capsule())
                    Text(rolle.satz).font(Schrift.sans(13.5)).foregroundStyle(Farbe.text2)
                }
                .padding(.top, 6)
            }
        }
        return VStack(alignment: .leading, spacing: 16) {
            person
            HStack(spacing: 10) {
                zahl(ich.map { "\($0.passkeys.count)" } ?? "–", Kontoworte.zahlPasskeys)
                zahl(ich.map { "\($0.sitzungen.count)" } ?? "–", Kontoworte.zahlSitzungen)
                zahl(ich?.codesOffen.map { "\($0)" } ?? "–", Kontoworte.zahlCodes)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Farbe.flaeche1
                RadialGradient(
                    colors: [Farbe.amber.opacity(0.14), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 300)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                .strokeBorder(Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
    }

    private func zahl(_ wert: String, _ wort: String) -> some View {
        VStack(spacing: 1) {
            Text(wert)
                .font(Schrift.mono(22, relativeTo: .title3))
                .foregroundStyle(Farbe.text1)
                .monospacedDigit()
            Text(wort).font(Schrift.sans(11.5)).foregroundStyle(Farbe.text3).lineLimit(1)
        }
        .frame(minWidth: 72)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Farbe.deep.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Passkeys

    private var passkeykarte: some View {
        let meine = ich?.passkeys ?? []
        // Ohne Passwort bleibt der letzte Passkey, denn sonst gäbe es keinen Weg herein.
        let letzterBleibt = meine.count <= 1 && !(ich?.passwort ?? false)
        return Kontokarte(art: .passkeys) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(meine, id: \.id) { p in
                    zeile(
                        .schluessel, name: p.name,
                        dazu: Kontoworte.passkeyzeile(gesichert: p.gesichert, zuletzt: p.zuletztBenutztAm)
                    ) {
                        Zugangsknopf(wort: Kontoworte.umbenennen, klein: true) {
                            neuerName = p.name
                            umbenennen = p
                        }
                        .disabled(laeuft)
                        Zugangsknopf(
                            wort: letzterBleibt ? Kontoworte.letzterBleibt : Kontoworte.loeschen,
                            klein: true
                        ) { loeschen = p }
                        .disabled(laeuft || letzterBleibt)
                    }
                }
                leise(Kontoworte.anlegenImDashboard)
                leise(Kontoworte.rueckweg)
                Zugangsknopf(wort: Kontoworte.neueCodes) {
                    fuehre { codes = try await haus.api.neueCodes() }
                }
                .disabled(laeuft)
                if let codes, !codes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Kicker(wort: Kontoworte.codesTitel, groesse: 11)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: schmal ? 2 : 5),
                            alignment: .leading, spacing: 8
                        ) {
                            ForEach(codes, id: \.self) { c in
                                Text(c).font(Schrift.mono(14)).foregroundStyle(Farbe.text1).textSelection(.enabled)
                            }
                        }
                        leise(Kontoworte.codesNurJetzt)
                    }
                    .padding(14)
                    .background(Farbe.deep.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Farbe.amber.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - Sitzungen

    private var sitzungskarte: some View {
        Kontokarte(art: .sitzungen) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(ich?.sitzungen ?? [], id: \.id) { s in
                    let diese = s.diese ?? false
                    zeile(
                        .geraet, name: Kontoworte.geraet(s.herkunft),
                        marke: diese ? Kontoworte.diesesGeraet : nil,
                        dazu: Kontoworte.sitzungszeile(seit: s.erstelltAm, zuletzt: s.zuletztBenutztAm),
                        hervor: diese
                    ) {
                        if !diese {
                            Zugangsknopf(wort: Kontoworte.beenden, klein: true) {
                                fuehre { try await haus.api.beendeSitzung(s.id) }
                            }
                            .disabled(laeuft)
                        }
                    }
                }
            }
        }
    }

    private var abmelden: some View {
        HStack(spacing: 10) {
            Zugangsknopf(wort: Zugangsworte.abmelden) {
                Task {
                    laeuft = true
                    await haus.meldeAb()
                    laeuft = false
                }
            }
            Zugangsknopf(wort: Kontoworte.ueberallAbmelden, art: .leise) { ueberallFragen = true }
        }
        .disabled(laeuft)
    }

    // MARK: - Bausteine

    /// Eine Zeile einer Liste: Zeichen, Name, Zeile darunter in Festbreitenschrift, rechts die
    /// Knöpfe (`globals.css`, `.konto-zeile`).
    private func zeile<Tun: View>(
        _ zeichen: Zeichenart, name: String, marke: String? = nil, dazu: String, hervor: Bool = false,
        @ViewBuilder tun: () -> Tun
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Zeichen(zeichen, groesse: 17, farbe: Farbe.text2)
                .frame(width: 32, height: 32)
                .background(Farbe.flaeche2)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name).font(Schrift.text).foregroundStyle(Farbe.text1)
                    if let marke {
                        Text(marke)
                            .font(Schrift.sansHalbfett(12.5))
                            .foregroundStyle(Farbe.amberWeich)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(Farbe.amber.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
                Text(dazu)
                    .font(Schrift.mono(12, relativeTo: .caption))
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if schmal {
                VStack(alignment: .trailing, spacing: 6) { tun() }
            } else {
                HStack(spacing: 6) { tun() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Farbe.deep.opacity(0.45))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(hervor ? Farbe.amber.opacity(0.45) : Farbe.linie1, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func leise(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.sans(13, relativeTo: .footnote))
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Mit dem Dienst

    private func lade() async {
        guard haus.zugang.istPerson else { return }
        do {
            ich = try await haus.api.ich()
        } catch {
            fehler = (error as? ApiFehler)?.meldung ?? Kontoworte.nichtGeklappt
        }
    }

    /// Führt eine Änderung aus und lädt neu; ein Fehler steht oben auf der Seite.
    private func fuehre(_ was: @escaping () async throws -> Void) {
        Task {
            laeuft = true
            fehler = nil
            do {
                try await was()
            } catch {
                fehler = (error as? ApiFehler)?.meldung ?? Kontoworte.nichtGeklappt
            }
            await lade()
            laeuft = false
        }
    }
}
