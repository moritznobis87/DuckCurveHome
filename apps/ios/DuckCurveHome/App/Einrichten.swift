import DuckCurveKit
import SwiftUI

/// Die Einrichtung: die Adresse des Hauses, dann die Anmeldung.
///
/// **Zwei Wege, wie im Dashboard einer von zweien.** Seit dem 24.11.2026 meldet sich die App als
/// Person an, mit E-Mail-Adresse und Passwort (`docs/ZUGANG.md`). Der Dienst gibt dafür ein
/// Sitzungstoken heraus, und was die Person darf, entscheidet er nach ihrer Rolle. Der zweite
/// Weg ist der bisherige: das API-Token aus `DCH_API_TOKEN`, mit dem die App als Gerät spricht
/// und am Dienst alles darf. Er bleibt für den, der den Dienst betreibt.
///
/// Die Anmeldung mit Passkey fehlt hier noch. Sie braucht eine Verknüpfung der App mit der
/// Adresse des Dashboards bei Apple und lässt sich nur am Gerät prüfen (`docs/GLEICHSTAND.md`).
///
/// **Was die App bekommt, liegt im Schluesselbund und nicht in den Einstellungen**, gleich ob
/// Sitzungstoken oder API-Token. Das Passwort selbst wird nirgends abgelegt.
///
/// **Es wird geprueft, bevor es gespeichert wird.** Eine Anmeldung, die nicht stimmt, soll hier
/// auffallen und nicht an der Wand - und die Pruefung ist eine einzige Anfrage an den
/// Live-Zustand. Dass sie durchgeht, heisst: Adresse richtig, Netz da, Anmeldung gueltig.
struct Einrichten: View {
    @Environment(Hauszustand.self) private var haus

    /// Womit sich die App anmeldet.
    enum Weg: Hashable {
        case passwort
        case token
    }

    /// Der Weg, mit dem das Blatt aufgeht, wenn der Aufrufer ihn kennt: „Mein Zugang“ öffnet es
    /// für die Anmeldung als Person, auch auf einem Gerät, das mit dem Token eingerichtet ist.
    private let vorgabe: Weg?

    init(vorgabe: Weg? = nil) {
        self.vorgabe = vorgabe
    }

    @State private var adresse: String = ""
    @State private var weg: Weg = .passwort
    @State private var email: String = ""
    @State private var passwort: String = ""
    @State private var token: String = ""
    @State private var geraetename: String = ""
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
            // Hier, nicht bei der Deklaration: `Geraet.vorschlag` fragt das System und darf
            // darum nur vom Hauptfaden aus gelesen werden - `onAppear` ist einer.
            if geraetename.isEmpty { geraetename = Geraet.vorschlag }
            // Was schon eingerichtet war, steht als Vorgabe da - etwa wenn nur das Token
            // abgelaufen ist.
            if haus.zugang.grund.host != nil {
                adresse = haus.zugang.grund.absoluteString
                geraetename = haus.zugang.geraetename
                praefix = haus.zugang.praefix
                rolle = haus.zugang.rolle
                email = haus.zugang.email
                // Wer mit dem API-Token eingerichtet war, findet diesen Weg wieder vor.
                weg = haus.zugang.istPerson || haus.zugang.token.isEmpty ? .passwort : .token
            }
            if let vorgabe { weg = vorgabe }
        }
    }

    private var begruessung: some View {
        VStack(alignment: .leading, spacing: 8) {
            Marke(groesse: 28)
            Text(
                "Die App spricht direkt mit dem Dienst im Haus. Dafür braucht sie seine Adresse "
                    + "und eine Anmeldung."
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
                    Text("Anmeldung").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                    Picker("Anmeldung", selection: $weg) {
                        Text("Mit Passwort").tag(Weg.passwort)
                        Text("Mit API-Token").tag(Weg.token)
                    }
                    .pickerStyle(.segmented)
                    Text(weg == .passwort ? Anmeldeworte.erklaerung : Anmeldeworte.tokenerklaerung)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if weg == .passwort {
                    feld(Anmeldeworte.emailfeld, "name@beispiel.de", $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    geheimfeld(Anmeldeworte.passwortfeld, "", $passwort)
                        .textContentType(.password)
                } else {
                    geheimfeld("API-Token", "aus DCH_API_TOKEN", $token)
                }

                feld("Name dieses Geräts", "iPad Flur", $geraetename)
                    .textInputAutocapitalization(.words)

                if weg == .token {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zugang").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        Picker("Zugang", selection: $rolle) {
                            Text("Hausherr").tag(Zugang.Rolle.hausherr)
                            Text("Gast").tag(Zugang.Rolle.gast)
                        }
                        .pickerStyle(.segmented)
                        Text(
                            rolle == .gast
                                ? "Gast blendet aus, was nicht in fremde Hände gehört. Gesperrt wird dadurch nichts. "
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
    }

    private func geheimfeld(_ wort: String, _ platzhalter: String, _ wert: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wort).font(Schrift.winzig).foregroundStyle(Farbe.text3)
            SecureField(platzhalter, text: wert)
                .textFieldStyle(.plain)
                .font(Schrift.zahl)
                .padding(10)
                .background(Farbe.flaeche3)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                .accessibilityLabel(wort)
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
                Text(pruefe ? "Wird geprüft …" : (weg == .passwort ? Anmeldeworte.anmeldeknopf : "Verbinden"))
                    .font(Schrift.karte)
                    .foregroundStyle(Farbe.deep)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Farbe.amber)
            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(pruefe || unvollstaendig)
        .opacity(unvollstaendig ? 0.5 : 1)
    }

    /// Ob noch etwas fehlt, ohne das die Anfrage gar nicht erst hinausgehen muss.
    private var unvollstaendig: Bool {
        adresse.isEmpty || (weg == .passwort && (email.isEmpty || passwort.isEmpty))
    }

    private var hinweise: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zwei Dinge zum Nachlesen")
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
            Text(
                "Was die App vom Dienst bekommt, wird im Schlüsselbund dieses Geräts verwahrt und "
                    + "verlässt es nur als Kopfzeile an die Adresse oben. Das Passwort selbst "
                    + "wird nicht gespeichert."
            )
            .font(Schrift.winzig)
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            Text(
                "Wer nur zusehen soll, bekommt vom Hausherrn eine eigene Person mit der Rolle "
                    + "Gast und meldet sich damit an. Dann sperrt der Dienst, und nicht nur diese App."
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

    @MainActor private func pruefeUndSpeichere() {
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
        var neu = Zugang(
            grund: url,
            praefix: praefix.isEmpty ? "/api/v1" : praefix,
            token: weg == .token ? token : "",
            geraetename: geraetename.isEmpty ? Geraet.vorschlag : geraetename,
            rolle: weg == .token ? rolle : .gast
        )
        let adresseDerPerson = email.trimmingCharacters(in: .whitespaces)
        let geheim = passwort
        let mitPasswort = weg == .passwort
        pruefe = true
        Task {
            do {
                if mitPasswort {
                    // Die Anmeldung selbst: der Dienst gibt das Sitzungstoken einmal heraus.
                    // Von hier an ist es das Token dieser App; das Passwort wird vergessen.
                    let angemeldet: AngemeldetOut
                    do {
                        angemeldet = try await Api(zugang: neu).anmelden(email: adresseDerPerson, passwort: geheim)
                    } catch let f as ApiFehler where f.istAnmeldung {
                        // Der Satz des Dienstes. Der allgemeine Rat („neu anmelden“) wäre hier
                        // im Kreis geredet.
                        throw ApiFehler(code: "anmeldung", meldung: f.meldung, status: 400)
                    }
                    neu.token = angemeldet.token
                    neu.email = angemeldet.ausweis.email ?? adresseDerPerson
                    neu.rolle = Zugang.rolle(derPerson: angemeldet.ausweis.rolle)
                }
                // Eine Anfrage, die alles prueft: Adresse, Netz, Anmeldung, Schema.
                let zustand = try await Api(zugang: neu).liveZustand()
                geprueft =
                    "Verbunden: \(zustand.system.mode == "demo" ? "Demo" : "Live"), "
                    + "Fassung \(zustand.system.version)."
                Schluesselbund.speichere(neu)
                passwort = ""
                haus.zugang = neu
                haus.abgemeldet = false
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

/// Der Name, den dieses Gerät vorschlägt.
enum Geraet {
    /// Was dasteht, wenn niemand gefragt hat.
    ///
    /// Dieser Name reist mit jeder Anfrage als `x-dch-urheber-name` und steht spaeter im
    /// Protokoll des Dienstes. Er bleibt nur, bis jemand das Einrichten oeffnet - dort wird
    /// er vom Vorschlag ersetzt und ist von Hand aenderbar.
    static let ersatz = "Gerät"

    /// Der Vorschlag des Systems - **nur vom Hauptfaden aus.**
    ///
    /// `UIDevice` ist dem Hauptfaden zugeordnet; ein Zugriff von woanders ist in Swift 6 eine
    /// Warnung und spaeter ein Fehler. Darum steht hier `@MainActor` und nicht etwa ein
    /// `assumeIsolated`, das zur Laufzeit abstuerzen wuerde.
    ///
    /// **Es liefert weniger, als der Name verspricht.** Seit iOS 16 gibt `UIDevice.name` nur
    /// noch den Modellnamen heraus („iPhone"), nicht den, den der Benutzer seinem Geraet
    /// gegeben hat - dafuer braucht eine App eine eigene Berechtigung von Apple. Als Vorgabe
    /// fuer ein Feld, das man ohnehin ueberschreibt, genuegt das.
    @MainActor static var vorschlag: String {
        #if canImport(UIKit)
            return UIDevice.current.name
        #else
            return ersatz
        #endif
    }
}

#if canImport(UIKit)
    import UIKit
#endif
