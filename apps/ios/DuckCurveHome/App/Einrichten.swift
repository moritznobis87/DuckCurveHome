import DuckCurveKit
import SwiftUI

/// Die Einrichtung: Adresse, Token, Name des Geraets.
///
/// **Das Token liegt im Schluesselbund und nicht in den Einstellungen.** Das ist der Grund,
/// warum eine App hier den Umweg des Dashboards nicht braucht (siehe `Zugang`): ein Browser
/// kann ein Token nicht verwahren, ein Geraet kann es.
///
/// **Es wird geprueft, bevor es gespeichert wird.** Ein Token, das nicht stimmt, soll hier
/// auffallen und nicht an der Wand - und die Pruefung ist eine einzige Anfrage an den
/// Live-Zustand. Dass sie durchgeht, heisst: Adresse richtig, Netz da, Token gueltig.
struct Einrichten: View {
    @Environment(Hauszustand.self) private var haus

    @State private var adresse: String = ""
    @State private var token: String = ""
    @State private var geraetename: String = Geraet.vorschlag
    @State private var rolle: Zugang.Rolle = .hausherr
    @State private var praefix: String = "/api/v1"
    @State private var pruefe = false
    @State private var fehler: ApiFehler?
    @State private var geprueft: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    begruessung
                    felder
                    if let geprueft {
                        HStack(spacing: 8) {
                            Zeichen(.schild, groesse: 16, farbe: Farbe.mist)
                            Text(geprueft).font(Schrift.klein).foregroundStyle(Farbe.text1)
                        }
                    }
                    if let fehler {
                        Stoerung(fehler: fehler)
                    }
                    knopf
                    hinweise
                }
                .padding(20)
                .frame(maxWidth: 560, alignment: .leading)
            }
            .seitengrund()
            .navigationTitle("Mit dem Haus verbinden")
        }
        .onAppear {
            // Was schon eingerichtet war, steht als Vorgabe da - etwa wenn nur das Token
            // abgelaufen ist.
            if haus.zugang.grund.host != nil {
                adresse = haus.zugang.grund.absoluteString
                geraetename = haus.zugang.geraetename
                praefix = haus.zugang.praefix
                rolle = haus.zugang.rolle
            }
        }
    }

    private var begruessung: some View {
        VStack(alignment: .leading, spacing: 8) {
            Marke(groesse: 28)
            Text(
                "Die App spricht direkt mit dem Dienst im Haus. Dafür braucht sie seine Adresse "
                    + "und das API-Token aus `DCH_API_TOKEN`."
            )
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var felder: some View {
        Karte {
            VStack(alignment: .leading, spacing: 14) {
                feld("Adresse des Hauses", "https://dch.beispiel.net", $adresse)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                VStack(alignment: .leading, spacing: 4) {
                    Text("API-Token").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    SecureField("aus DCH_API_TOKEN", text: $token)
                        .textFieldStyle(.plain)
                        .font(Schrift.zahl)
                        .padding(10)
                        .background(Farbe.flaeche3)
                        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                }

                feld("Name dieses Geräts", "iPad Flur", $geraetename)
                    .textInputAutocapitalization(.words)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zugang").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    Picker("Zugang", selection: $rolle) {
                        Text("Hausherr").tag(Zugang.Rolle.hausherr)
                        Text("Gast").tag(Zugang.Rolle.gast)
                    }
                    .pickerStyle(.segmented)
                    Text(
                        rolle == .gast
                            ? "Gast blendet aus, was nicht in fremde Hände gehört – es sperrt nichts. "
                                + "Wer das Token hat, darf am Dienst alles."
                            : "Voller Zugriff: schalten, stellen, Rechnungen."
                    )
                    .font(Schrift.winzig)
                    .foregroundStyle(rolle == .gast ? Farbe.achtung : Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func feld(_ wort: String, _ platzhalter: String, _ wert: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            TextField(platzhalter, text: wert)
                .textFieldStyle(.plain)
                .font(Schrift.text)
                .padding(10)
                .background(Farbe.flaeche3)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
    }

    private var knopf: some View {
        Button {
            pruefeUndSpeichere()
        } label: {
            HStack(spacing: 8) {
                if pruefe { ProgressView().controlSize(.small) }
                Text(pruefe ? "Wird geprüft …" : "Verbinden")
                    .font(Schrift.karte)
                    .foregroundStyle(Farbe.deep)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Farbe.amber)
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(pruefe || adresse.isEmpty)
        .opacity(adresse.isEmpty ? 0.5 : 1)
    }

    private var hinweise: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zwei Dinge zum Nachlesen")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
            Text(
                "Das Token wird im Schlüsselbund dieses Geräts verwahrt und verlässt es nur als "
                    + "Kopfzeile an die Adresse oben."
            )
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            Text(
                "Wer einen echten Gastzugang braucht – einen, der auch am Dienst nichts darf –, "
                    + "trägt als Adresse das Dashboard ein und als Pfad „/api/dch“. Dann gelten "
                    + "dessen Gastregeln."
            )
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Pfad ändern") {
                feld("Pfad zu den Endpunkten", "/api/v1", $praefix)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .tint(Farbe.mist)
        }
    }

    private func pruefeUndSpeichere() {
        fehler = nil
        geprueft = nil
        guard let url = URL(string: adresse.trimmingCharacters(in: .whitespaces)),
              url.host != nil
        else {
            fehler = ApiFehler(
                code: "adresse", meldung: "Das ist keine brauchbare Adresse.", status: 0
            )
            return
        }
        let neu = Zugang(
            grund: url,
            praefix: praefix.isEmpty ? "/api/v1" : praefix,
            token: token,
            geraetename: geraetename.isEmpty ? Geraet.vorschlag : geraetename,
            rolle: rolle
        )
        pruefe = true
        Task {
            do {
                // Eine Anfrage, die alles prueft: Adresse, Netz, Token, Schema.
                let zustand = try await Api(zugang: neu).liveZustand()
                geprueft =
                    "Verbunden: \(zustand.system.mode == "demo" ? "Demo" : "Live"), "
                    + "Fassung \(zustand.system.version)."
                Schluesselbund.speichere(neu)
                haus.zugang = neu
                haus.starte()
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
            pruefe = false
        }
    }
}

/// Der Name, den dieses Geraet vorschlaegt.
enum Geraet {
    static var vorschlag: String {
        #if canImport(UIKit)
            return UIDevice.current.name
        #else
            return "iPhone"
        #endif
    }
}

#if canImport(UIKit)
    import UIKit
#endif

/// Die Seite „Zugang und Sicherung": was eingerichtet ist, und wie man es aendert.
struct ZugangSeite: View {
    @Environment(Hauszustand.self) private var haus
    @State private var neuEinrichten = false
    @State private var geraete: PushGeraeteOut?

    var body: some View {
        Seite {
            Karte(kicker: "Dieses Gerät") {
                VStack(spacing: 0) {
                    Zeile(wort: "Name im Protokoll", wert: haus.zugang.geraetename)
                    Zeile(wort: "Kennung", wert: haus.zugang.geraetekennung)
                    Zeile(
                        wort: "Zugang",
                        wert: haus.zugang.rolle == .hausherr ? "Hausherr" : "Gast",
                        farbe: haus.zugang.rolle == .hausherr ? Farbe.text1 : Farbe.achtung
                    )
                    Zeile(wort: "Adresse", wert: haus.zugang.grund.absoluteString)
                    Zeile(wort: "Pfad", wert: haus.zugang.praefix)
                    Zeile(
                        wort: "Token",
                        wert: haus.zugang.token.isEmpty
                            ? "keines (Demo)"
                            : "im Schlüsselbund · \(haus.zugang.token.count) Zeichen"
                    )
                }
            }
            Karte(kicker: "Verbindung") {
                VStack(spacing: 0) {
                    Zeile(wort: "Zustand", wert: verbindungswort)
                    if let s = haus.zustand?.system {
                        Zeile(wort: "Betriebsart", wert: s.mode)
                        Zeile(wort: "Fassung des Dienstes", wert: s.version)
                        Zeile(wort: "Brücke", wert: s.bridgeOnline ? "verbunden" : "nicht verbunden")
                        Zeile(wort: "Anzeigen am Strom", wert: String(s.sseClients))
                        Zeile(
                            wort: "Zeitversatz zum Dienst",
                            wert: Formate.zahl(haus.versatz, stellen: 1), einheit: "s"
                        )
                    }
                }
            }
            if let g = geraete {
                Karte(kicker: "Angemeldete Geräte für Mitteilungen") {
                    if g.devices.isEmpty {
                        Leer(satz: "Kein Gerät angemeldet.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(g.devices.enumerated()), id: \.offset) { i, d in
                                if i > 0 { Divider().overlay(Farbe.linie1) }
                                Zeile(
                                    wort: d.label,
                                    wert: d.zuletztOk.map { Formate.hhmm(iso: $0) } ?? Formate.leer,
                                    dazu: d.seit.map { "seit \(Formate.hhmm(iso: $0))" }
                                )
                            }
                        }
                    }
                }
            }
            Karte(kicker: "Ändern") {
                Button {
                    neuEinrichten = true
                } label: {
                    Text("Neu einrichten")
                        .font(Schrift.klein)
                        .foregroundStyle(Farbe.deep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Farbe.amberWeich)
                        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Methode([
                "Das Token liegt im Schlüsselbund dieses Geräts und ist durch die Gerätesperre "
                    + "geschützt. Es verlässt das Gerät nur als Authorization-Kopfzeile.",
                "Die Rolle „Gast“ blendet in dieser App aus, was nicht in fremde Hände gehört. "
                    + "Sie sperrt nichts am Dienst: wer das Token hat, darf dort alles. Für einen "
                    + "echten Gastzugang zeigt man die App auf das Dashboard und paart dort mit "
                    + "dem Gast-Token.",
                "Jede Änderung, die von hier ausgeht, steht im Protokoll des Dienstes mit dem "
                    + "Namen dieses Geräts – nicht mit einem Menschen. Am iPad im Flur kann "
                    + "jeder gestanden haben.",
            ])
        }
        .sheet(isPresented: $neuEinrichten) {
            Einrichten()
        }
        .task {
            geraete = try? await haus.api.mitteilungGeraete()
        }
    }

    private var verbindungswort: String {
        switch haus.verbindung {
        case .live: return "verbunden"
        case .verbindet: return "verbindet"
        case .verbindetNeu: return "unterbrochen, versucht erneut"
        case .aus: return "angehalten"
        }
    }
}
