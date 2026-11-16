import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Regler: was am Regler eingestellt ist – gelesen über den Bus.
///
/// **Und was sich stellen lässt, lässt sich hier stellen.** Das ist die heikelste Seite der
/// ganzen App, und sie ist mit drei Vorsichten gebaut:
///
/// 1. **Gestellt ist erst, wenn der Regler es zurückmeldet.** Der Dienst antwortet auf einen
///    Griff mit dem vollständigen Satz der Einstellungen, nicht mit „in Ordnung" - und bis die
///    Antwort da ist, steht der alte Wert da. Ein Schieber, der sofort auf den neuen Wert
///    springt und zwei Sekunden später zurück, lügt.
/// 2. **Nichts wird stillschweigend gestellt.** Jeder Griff fragt nach, mit dem alten und dem
///    neuen Wert im Satz. Das ist an einer Heizungsanlage keine Umständlichkeit: eine
///    Heizkurvensteilheit, die versehentlich von 0,4 auf 1,4 geht, merkt man im Februar an der
///    Rechnung.
/// 3. **Was der Dienst nicht als stellbar meldet, wird nur gezeigt.** `stellbar` kommt vom
///    Dienst und nicht aus einer Liste hier - er weiß, was der Bus hergibt.
struct ReglerSeite: View {
    @Environment(Hauszustand.self) private var haus

    @State private var einstellungen: ReglerEinstellungenOut?
    @State private var fehler: ApiFehler?
    @State private var nachfrage: Nachfrage?
    @State private var laeuft: String?
    @State private var rueckmeldung: String?
    @State private var kennzahlen: ReglerKennzahlenOut?

    /// Die Nachfrage vor einem Griff.
    private struct Nachfrage: Identifiable {
        let einstellung: ReglerEinstellungOut
        let neu: Double
        var id: String { einstellung.schluessel }
    }

    var body: some View {
        Seite {
            if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            }
            if let e = einstellungen {
                kopf(e)
                if let r = rueckmeldung {
                    Karte { Text(r).font(Schrift.klein).foregroundStyle(Farbe.text1) }
                }
                ForEach(gruppen(e), id: \.name) { gruppe in
                    Karte(kicker: gruppe.name) {
                        VStack(spacing: 0) {
                            ForEach(Array(gruppe.werte.enumerated()), id: \.offset) { i, w in
                                if i > 0 { Divider().overlay(Farbe.linie1) }
                                Einstellungszeile(
                                    einstellung: w,
                                    laeuft: laeuft == w.schluessel,
                                    darfStellen: darfStellen(e, w)
                                ) { neu in
                                    nachfrage = Nachfrage(einstellung: w, neu: neu)
                                } bestaetigen: {
                                    bestaetige(w)
                                }
                            }
                        }
                    }
                }
                if let k = kennzahlen, let zeilen = k.zeilen, !zeilen.isEmpty {
                    kennzahlenkarte(k, zeilen)
                }
                if let protokoll = e.protokoll, !protokoll.isEmpty {
                    Karte(kicker: "Was geändert wurde") {
                        VStack(spacing: 0) {
                            ForEach(Array(protokoll.enumerated()), id: \.offset) { i, a in
                                if i > 0 { Divider().overlay(Farbe.linie1) }
                                aenderung(a)
                            }
                        }
                    }
                }
                Methode(
                    (e.hinweiseDe ?? []) + [
                        e.hindernisDe,
                        e.stellenJeTag.map { "Höchstens \($0) Griffe am Tag." },
                        "Gelesen über den eBUS. Gestellt ist eine Einstellung erst, wenn der "
                            + "Regler sie zurückmeldet.",
                    ]
                )
            } else if fehler == nil {
                Karte { Leer(satz: "Wird vom Bus gelesen …") }
            }
        }
        .task { await lade() }
        .task { kennzahlen = try? await haus.api.reglerKennzahlen(tage: 7) }
        .alert(item: $nachfrage) { n in
            Alert(
                title: Text("\(n.einstellung.nameDe) stellen?"),
                message: Text(nachfragesatz(n)),
                primaryButton: .default(Text("Stellen")) { stelle(n) },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
    }

    /// Was der Regler in den letzten Tagen wirklich getan hat, nach Betriebszustand.
    ///
    /// **Das ist die Gegenprobe zu den Einstellungen darüber.** Dort steht, was eingestellt ist;
    /// hier steht, wie viele Minuten die Anlage in welchem Zustand war und mit welchem Vorlauf.
    /// Eine Heizkurve, die auf dem Papier stimmt, und ein Vorlauf, der ständig fünf Kelvin
    /// darüber liegt, sind zwei verschiedene Auskünfte.
    private func kennzahlenkarte(
        _ k: ReglerKennzahlenOut, _ zeilen: [ReglerKennzahlOut]
    ) -> some View {
        Karte(kicker: "Was der Regler tat", titel: "\(k.tage) Tage") {
            Tabelle(
                zeilennamen: zeilen.map { "Zustand \($0.code)" },
                spalten: [
                    .init(
                        name: "Minuten",
                        zellen: zeilen.map { Formate.zahl(Double($0.minuten), stellen: 0) }
                    ),
                    .init(
                        name: "davon gelaufen",
                        zellen: zeilen.map { Formate.zahl(Double($0.laufMin), stellen: 0) }
                    ),
                    .init(
                        name: "Vorlauf",
                        zellen: zeilen.map { Formate.celsius($0.vorlaufC, stellen: 1) }
                    ),
                    .init(
                        name: "Sollvorlauf",
                        zellen: zeilen.map { Formate.celsius($0.vorlaufSollC, stellen: 1) }
                    ),
                    .init(
                        name: "angefordert",
                        zellen: zeilen.map { Formate.prozent($0.angefordertAnteil) }
                    ),
                    .init(
                        name: "Heizstab",
                        zellen: zeilen.map { Formate.prozent($0.heizstabAnteil) }
                    ),
                    .init(
                        name: "zuletzt",
                        zellen: zeilen.map { $0.zuletzt.map { Formate.hhmm(iso: $0) } ?? Formate.leer }
                    ),
                ]
            )
        }
    }

    private func kopf(_ e: ReglerEinstellungenOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(e.satzDe)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text("gelesen \(Formate.hhmm(iso: e.gelesen))")
                    .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                if e.stellenMoeglich != true {
                    Text("Stellen ist gesperrt")
                        .font(Schrift.winzig).foregroundStyle(Farbe.achtung)
                }
            }
        }
    }

    private struct Gruppe: Identifiable {
        let name: String
        let werte: [ReglerEinstellungOut]
        var id: String { name }
    }

    /// Nach Gruppen des Dienstes, in der Reihenfolge, in der sie kommen.
    private func gruppen(_ e: ReglerEinstellungenOut) -> [Gruppe] {
        var reihenfolge: [String] = []
        var nach: [String: [ReglerEinstellungOut]] = [:]
        for w in e.werte ?? [] {
            if nach[w.gruppeDe] == nil {
                nach[w.gruppeDe] = []
                reihenfolge.append(w.gruppeDe)
            }
            nach[w.gruppeDe]?.append(w)
        }
        return reihenfolge.map { Gruppe(name: $0, werte: nach[$0] ?? []) }
    }

    private func darfStellen(_ e: ReglerEinstellungenOut, _ w: ReglerEinstellungOut) -> Bool {
        haus.darfSchalten && e.stellenMoeglich == true && w.stellbar == true
    }

    private func nachfragesatz(_ n: Nachfrage) -> String {
        let alt = wertAlsText(n.einstellung, n.einstellung.wert.value)
        let neu = wertAlsText(n.einstellung, n.neu)
        var satz = "Von \(alt) auf \(neu).\n\nDas wird am Regler selbst geändert, nicht nur hier."
        if let hinweis = n.einstellung.hinweisDe, !hinweis.isEmpty {
            satz += "\n\n\(hinweis)"
        }
        return satz
    }

    private func aenderung(_ a: ReglerAenderungOut) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(a.nameDe).font(Schrift.klein).foregroundStyle(Farbe.text1)
                Text(
                    [Formate.hhmm(iso: a.at), a.urheberDe]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                )
                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 8)
            Text("\(a.vonDe) → \(a.aufDe)")
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text2)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Werte lesen und schreiben

    /// Einen Wert als Text, so wie der Regler ihn meint.
    ///
    /// Drei Formen: eine Auswahl (dann steht das Wort dazu in `wahl`), eine Zahl mit Einheit,
    /// oder ein Ja/Nein. Die Lesart des Dienstes (`lesartDe`) schlaegt alles - er kennt den
    /// Regler besser als diese Seite.
    private func wertAlsText(_ e: ReglerEinstellungOut, _ zahl: Double?) -> String {
        guard let zahl else { return Formate.leer }
        if let wort = e.wahl[String(Int(zahl))] { return wort }
        let text = Formate.zahl(zahl, stellen: e.stellen ?? 1)
        return e.einheit.map { "\(text)\(Formate.schmalesLeerzeichen)\($0)" } ?? text
    }

    private func stelle(_ n: Nachfrage) {
        laeuft = n.einstellung.schluessel
        Task {
            do {
                let a = try await haus.api.stelleRegler(n.einstellung.schluessel, wert: n.neu)
                // Der Dienst antwortet mit dem vollstaendigen Satz - also wird er uebernommen
                // und nicht nur der eine Wert.
                einstellungen = a.einstellungen
                rueckmeldung = a.messageDe
                fehler = nil
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
            laeuft = nil
        }
    }

    /// Vermerken, dass eine Einstellung mit dem Bediengeraet verglichen ist.
    ///
    /// Das ist kein Griff an die Anlage, sondern ein Haken: „ich habe am Geraet nachgesehen, es
    /// steht wirklich so da". Der Bus liest manche Werte nur mittelbar, und dieser Haken
    /// unterscheidet eine gelesene Zahl von einer bestaetigten.
    private func bestaetige(_ w: ReglerEinstellungOut) {
        laeuft = w.schluessel
        Task {
            if let a = try? await haus.api.bestaetigeRegler(
                w.schluessel, bestaetigt: !(w.bestaetigt ?? false)
            ) {
                einstellungen = a.einstellungen
                rueckmeldung = a.messageDe
            }
            laeuft = nil
        }
    }

    private func lade() async {
        do {
            einstellungen = try await haus.api.reglerEinstellungen()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }
}

/// Eine Zeile der Reglereinstellungen.
///
/// **Der Griff ist ein Stepper, kein Schieber.** Eine Heizkurvensteilheit hat einen Bereich von
/// 0,1 bis 1,5 in Schritten von 0,05 - auf einem Schieber sind das 28 Stellungen auf zweihundert
/// Punkten, und der Finger trifft die falsche. Ein Stepper trifft immer.
struct Einstellungszeile: View {
    let einstellung: ReglerEinstellungOut
    let laeuft: Bool
    let darfStellen: Bool
    let stellen: (Double) -> Void
    let bestaetigen: () -> Void

    @State private var entwurf: Double?

    private var jetzigerWert: Double? {
        einstellung.wert.value
    }

    private var gezeigt: Double? {
        entwurf ?? jetzigerWert
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(einstellung.nameDe).font(Schrift.klein).foregroundStyle(Farbe.text1)
                    HStack(spacing: 6) {
                        Text(einstellung.kennung)
                            .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        if einstellung.bestaetigt == true {
                            Text("verglichen")
                                .font(Schrift.winzig).foregroundStyle(Farbe.mist)
                        }
                        if einstellung.gesendet == true {
                            Text("gesendet, noch nicht zurückgemeldet")
                                .font(Schrift.winzig).foregroundStyle(Farbe.achtung)
                        }
                    }
                }
                Spacer(minLength: 8)
                Text(text)
                    .font(Schrift.zahl)
                    .foregroundStyle(entwurf == nil ? Farbe.text1 : Farbe.amber)
                    .opacity(laeuft ? 0.5 : 1)
            }
            if darfStellen, let von = einstellung.von, let bis = einstellung.bis, let wert = gezeigt {
                griff(wert: wert, von: von, bis: bis)
            }
            if let hinweis = einstellung.hinweisDe, !hinweis.isEmpty {
                Text(hinweis)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 7)
    }

    private var text: String {
        if let lesart = einstellung.lesartDe, !lesart.isEmpty, entwurf == nil { return lesart }
        guard let wert = gezeigt else { return Formate.leer }
        if let wort = einstellung.wahl[String(Int(wert))] { return wort }
        let zahl = Formate.zahl(wert, stellen: einstellung.stellen ?? 1)
        return einstellung.einheit.map { "\(zahl)\(Formate.schmalesLeerzeichen)\($0)" } ?? zahl
    }

    private func griff(wert: Double, von: Double, bis: Double) -> some View {
        let schritt = einstellung.schritt ?? 1
        return HStack(spacing: 10) {
            Stepper(
                "",
                value: Binding(
                    get: { entwurf ?? wert },
                    set: { entwurf = min(bis, max(von, $0)) }
                ),
                in: von...bis,
                step: schritt
            )
            .labelsHidden()
            .disabled(laeuft)

            if let e = entwurf, abs(e - (jetzigerWert ?? e)) >= schritt / 2 {
                Button("Stellen") { stellen(e) }
                    .font(Schrift.klein)
                    .buttonStyle(.plain)
                    .foregroundStyle(Farbe.amber)
                Button("Zurück") { entwurf = nil }
                    .font(Schrift.klein)
                    .buttonStyle(.plain)
                    .foregroundStyle(Farbe.text3)
            } else {
                Button(einstellung.bestaetigt == true ? "Haken weg" : "Verglichen") {
                    bestaetigen()
                }
                .font(Schrift.winzig)
                .buttonStyle(.plain)
                .foregroundStyle(Farbe.text3)
            }
            Spacer(minLength: 0)
            Text("\(Formate.zahl(von, stellen: einstellung.stellen ?? 1)) bis \(Formate.zahl(bis, stellen: einstellung.stellen ?? 1))")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
        }
    }
}

extension View {
    /// `alert(item:)` - in SwiftUI nur noch mit `isPresented` und getrenntem Inhalt vorhanden.
    func alert<Gegenstand: Identifiable>(
        item: Binding<Gegenstand?>, inhalt: @escaping (Gegenstand) -> Alert
    ) -> some View {
        // Der Umweg ueber einen eigenen Zustand: `alert(_:isPresented:presenting:actions:)` wäre
        // die neue Form, braucht aber einen Titel ausserhalb des Inhalts - und der Titel haengt
        // hier am Gegenstand.
        background(
            EmptyView()
                .alert(isPresented: Binding(
                    get: { item.wrappedValue != nil },
                    set: { if !$0 { item.wrappedValue = nil } }
                )) {
                    if let g = item.wrappedValue {
                        return inhalt(g)
                    }
                    return Alert(title: Text(""))
                }
        )
    }
}
