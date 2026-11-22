import DuckCurveKit
import SwiftUI

/// Die Automatik für die thermische Masse.
///
/// **Was sie tut.** Sie hebt die Sollwerte der Räume vor einem Preistief an und senkt sie danach:
/// das Haus wird zum Speicher, und die Wärme, die abends gebraucht wird, ist mittags für
/// weniger Geld hineingegangen. Der Versatz ist klein - ein halbes Grad reicht, weil ein Haus
/// viel Masse hat.
///
/// **Sie ist aus, bis jemand sie einschaltet.** Das ist Absicht: eine Automatik, die ohne
/// Zutun an den Sollwerten der Wohnräume dreht, ist etwas, das man ausdrücklich gewollt haben
/// muss.
struct Automatikkarte: View {
    @Environment(Hauszustand.self) private var haus
    let automatik: RoomShiftOut
    let geaendert: (RoomShiftOut) -> Void

    @State private var laeuft = false

    var body: some View {
        Karte(kicker: "Automatik für die thermische Masse", titel: titel) {
            VStack(alignment: .leading, spacing: 10) {
                Text(automatik.reasonDe)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    Zeile(
                        wort: "Anhebung", wert: Formate.zahl(automatik.deltaK, stellen: 1),
                        einheit: "K", dazu: "vor dem Preistief"
                    )
                    Zeile(
                        wort: "Absenkung", wert: Formate.zahl(automatik.drawK, stellen: 1),
                        einheit: "K", dazu: "danach, zum Entladen"
                    )
                    Zeile(
                        wort: "Vorlauf", wert: Formate.zahl(automatik.leadH, stellen: 1),
                        einheit: "h", dazu: "so früh fängt sie an"
                    )
                    Zeile(
                        wort: "lohnt ab", wert: Formate.zahl(automatik.minSpreadCt, stellen: 1),
                        einheit: "ct", dazu: "Preisunterschied im Tag"
                    )
                    if let spanne = automatik.spreadCt {
                        Zeile(
                            wort: "heute", wert: Formate.zahl(spanne, stellen: 1), einheit: "ct",
                            farbe: spanne >= automatik.minSpreadCt ? Farbe.mist : Farbe.text3
                        )
                    }
                    if let von = automatik.windowStart, let bis = automatik.windowEnd {
                        Zeile(
                            wort: "Fenster",
                            wert: "\(Formate.hhmm(iso: von)) – \(Formate.hhmm(iso: bis))"
                        )
                    }
                    Zeile(
                        wort: "Versatz jetzt", wert: Formate.zahl(automatik.offsetK, stellen: 1),
                        einheit: "K",
                        farbe: abs(automatik.offsetK) > 0.05 ? Farbe.amber : Farbe.text1
                    )
                }
                // **`rooms` sind die Raumnummern, `active` sind die Raeume.** Hier stand
                // `rooms` - eine Reihe von `Int`. Die Liste zeigt Namen und geschriebene
                // Werte, also das, was die Automatik wirklich gestellt hat: `active`.
                if !automatik.active.isEmpty {
                    raumliste(automatik.active)
                }
                if !automatik.log.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zuletzt").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        ForEach(Array(automatik.log.prefix(5).enumerated()), id: \.offset) { _, e in
                            Text("\(Formate.hhmm(iso: e.at)) · \(e.textDe)")
                                .font(Schrift.winzig)
                                .foregroundStyle(Farbe.text3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if haus.darfSchalten {
                    Button {
                        schalte(!automatik.enabled)
                    } label: {
                        Text(automatik.enabled ? "Automatik ausschalten" : "Automatik einschalten")
                            .font(Schrift.klein)
                            .foregroundStyle(automatik.enabled ? Farbe.text2 : Farbe.deep)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(automatik.enabled ? Farbe.flaeche3 : Farbe.amberWeich)
                            .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(laeuft)
                    .opacity(laeuft ? 0.6 : 1)
                }
                if let hinweis = automatik.noteDe, !hinweis.isEmpty {
                    Text(hinweis)
                        .font(Schrift.winzig)
                        .foregroundStyle(Farbe.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var titel: String {
        if !automatik.enabled { return "aus" }
        // `active` ist keine Ja/Nein-Angabe, sondern die Reihe der Raeume, an denen gerade
        // geschrieben ist. „Greift gerade“ heisst: diese Reihe ist nicht leer.
        if !automatik.active.isEmpty { return "greift gerade · \(automatik.phase.wort)" }
        return "an · \(automatik.phase.wort)"
    }

    /// Welche Räume mitmachen - und was die Automatik an ihnen wirklich geschrieben hat.
    ///
    /// Der geschriebene Sollwert steht neben dem Grundwert, weil sie auseinanderlaufen können:
    /// wer von Hand stellt, während die Automatik läuft, verschiebt den Grundwert, und der
    /// geschriebene folgt erst beim nächsten Schritt.
    private func raumliste(_ raeume: [RoomShiftRoomOut]) -> some View {
        Tabelle(
            zeilennamen: raeume.map(\.name),
            spalten: [
                .init(
                    name: "Grundwert",
                    zellen: raeume.map { Formate.celsius($0.baseSetpointC, stellen: 1) }
                ),
                .init(
                    name: "Versatz",
                    zellen: raeume.map { Formate.zahl($0.offsetK, stellen: 1) + " K" }
                ),
                .init(
                    name: "geschrieben",
                    zellen: raeume.map { Formate.celsius($0.writtenSetpointC, stellen: 1) }
                ),
                .init(
                    name: "wann",
                    zellen: raeume.map { Formate.hhmm(iso: $0.writtenAt) }
                ),
            ]
        )
    }

    private func schalte(_ an: Bool) {
        laeuft = true
        Task {
            if let neu = try? await haus.api.stelleRaumAutomatik(RoomShiftIn(enabled: an)) {
                geaendert(neu)
            }
            laeuft = false
        }
    }
}
