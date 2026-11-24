import DuckCurveKit
import SwiftUI

/// Am Telefon im Satzblock: dieses Gerät bekommt noch keine Mitteilungen.
///
/// **Der Anlass** (`MitteilungsHinweis.tsx:11-14`, Nutzer am 12.11.2026): „Ich bekomme gar keine
/// Push-Nachrichten auf mein Handy. Da war doch ein Morning Briefing geplant.“ Der Brief war
/// eingeschaltet, aber jedes Gerät meldet sich einzeln an, und die Stelle dafür liegt unter
/// Technik. Wer das nicht weiß, wartet auf einen Brief, der an niemanden geht.
///
/// **Warum hier und nicht auf der Mitteilungsseite.** Wer dort ist, hat den Weg schon gefunden.
/// Die Vorlage setzt den Hinweis in den Satzblock der Startseite (`Home.tsx:225`), also dorthin,
/// wo das Telefon ohnehin aufgeht.
///
/// Ob er dasteht, rechnet ``Startseitenhinweis`` - vier Bedingungen, und jede hält ihn auf.
struct Mitteilungshinweis: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Mitteilungen.self) private var mitteilungen
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.horizontalSizeClass) private var breite

    /// Das Wegtippen merkt sich das Gerät.
    ///
    /// **Ein Schalter und keine Zeichenkette**, anders als in der Vorlage, die `"weg"` in den
    /// `localStorage` legt (`MitteilungsHinweis.tsx:68`): die Speicher sind ohnehin getrennt -
    /// einer gehört dem Browser, einer der App -, und ein `Bool` ist das, was hier gefragt wird.
    /// Der Schlüssel heißt gleich, damit eine Fehlersuche beide Seiten unter einem Wort findet.
    @AppStorage(Startseitenhinweis.merker) private var weggetippt = false

    /// Wie es um dieses Gerät steht, in den Worten des Kerns.
    ///
    /// Die Übersetzung steht hier und nicht im Kern, weil ``Mitteilungen/Stand`` zur Oberfläche
    /// gehört: er kommt von `UNUserNotificationCenter` und von APNs, und beides gibt es unter
    /// Linux nicht. Dieselbe Trennung zieht ``MitteilungenSeite``.
    private var lage: Mitteilungsstand.Lage {
        switch mitteilungen.stand {
        case .ungefragt: return .aus
        case .abgelehnt: return .verboten
        case .erlaubt: return .halb
        case .angemeldet: return .an
        case .fehler(let satz): return .fehler(satz)
        }
    }

    var body: some View {
        if Startseitenhinweis.zeigt(
            lage: lage, istHausherr: haus.hatVollzugriff, weggetippt: weggetippt,
            schmal: breite == .compact)
        {
            VStack(alignment: .leading, spacing: 10) {
                Text(Startseitenhinweis.satz)
                    .font(Schrift.sans(14))
                    .lineSpacing(3)
                    .foregroundStyle(Farbe.text1)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    pille
                    stillerKnopf
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Fläche, Rand, Radius 12 (`globals.css:769`).
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Farbe.flaeche2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Farbe.linie2, lineWidth: 1)
                    )
            )
        }
    }

    /// **Eine Pille auf `--amber` mit Petrolschrift** (`globals.css:771`). Es ist der einzige
    /// gefüllte Knopf auf der Startseite - und das ist der Punkt: er trägt die Handlung, die der
    /// Satz vorschlägt.
    private var pille: some View {
        Button {
            wegweiser.gehe(Startseitenhinweis.weg)
        } label: {
            Text(Startseitenhinweis.losWort)
                .font(Schrift.sansHalbfett(13))
                .foregroundStyle(Farbe.petrol)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Farbe.amber))
        }
        .buttonStyle(.plain)
    }

    private var stillerKnopf: some View {
        Button {
            weggetippt = true
        } label: {
            Text(Startseitenhinweis.zuWort)
                .font(Schrift.sans(13))
                .foregroundStyle(Farbe.text3)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
