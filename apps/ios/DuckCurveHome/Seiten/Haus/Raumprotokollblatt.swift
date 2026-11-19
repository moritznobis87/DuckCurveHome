import DuckCurveKit
import SwiftUI

/// Das Protokoll eines Raums: die gemessene und die geregelte Kurve, die Ventile, das Fenster –
/// und jede Sollwertänderung mit ihrer Herkunft.
///
/// **Warum das ein eigenes Blatt ist und nicht im Blatt zum Stellen steht.** Es sind zwei
/// Fragen. „Ich will es wärmer" ist eine Entscheidung über die nächste Stunde; „warum war es
/// kalt" ist eine Frage an die letzten zwei Tage. Die zweite braucht Platz: zwei Kurven, zwei
/// Streifen und eine Zeitleiste. Im Stellblatt stand davon eine Liste ohne Kurven, und damit
/// fehlte der Zusammenhang, auf den es ankommt – **ob der Knick in der Kurve zu einer Änderung
/// gehört oder zu etwas anderem.** Darum liegen Marke und Knick jetzt auf derselben Senkrechten.
///
/// Gestalt und Regeln wie `apps/web/src/components/rooms/Protokoll.tsx`.
struct Raumprotokollblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    let raumId: Int
    let name: String
    let etage: String

    /// 48 Stunden mit Viertelstunden, oder 24 Stunden mit Fünfminutenfenstern.
    ///
    /// **Zwei Tage sind die Voreinstellung.** Die Frage „warum war es gestern kalt" braucht
    /// gestern, und ein einzelner Tag hört genau dort auf, wo die Ursache liegt.
    @State private var stunden = 48
    @State private var log: RoomLogOut?
    @State private var fehler: ApiFehler?
    @State private var laeuft = true

    private var schrittMin: Int { stunden <= 24 ? 5 : 15 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    spanneWahl
                    if let p = log {
                        Text(Raumprotokoll.ueberschrift(p.entries, stunden: stunden))
                            .font(Schrift.satz)
                            .foregroundStyle(Farbe.text1)
                            .fixedSize(horizontal: false, vertical: true)
                        Karte { bild(p) }
                        zeitleiste(p)
                    } else if let f = fehler {
                        Stoerung(fehler: f) { Task { await hole() } }
                    } else if laeuft {
                        Karte { Leer(satz: "Wird geholt …") }
                    }
                    fussnote
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
        .task(id: stunden) { await hole() }
    }

    /// Oben die Etage, darunter der Umschalter ueber die ganze Breite - er ist am Telefon
    /// dehnbar und stuende neben einem `Spacer` in der Mitte der Zeile.
    private var spanneWahl: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !etage.isEmpty { Kicker(wort: etage) }
            Ansichtswahl(
                ansichten: [
                    Ansicht(weg: "24", name: "24 h"),
                    Ansicht(weg: "48", name: "48 h"),
                ],
                aktiv: Ansicht(weg: String(stunden), name: "")
            ) { a in
                stunden = Int(a.weg) ?? 48
            }
        }
    }

    // MARK: - Das Bild

    @ViewBuilder private func bild(_ p: RoomLogOut) -> some View {
        if let spanne = Raumprotokoll.spanne([p.room.tempC, p.targetC]) {
            VStack(alignment: .leading, spacing: 6) {
                Protokollkurve(log: p, spanne: spanne)
                    .frame(height: 150)
                Protokollstreifen(
                    werte: p.room.valve, farbe: Farbe.ventilOffen, wort: "Ventil",
                    proStunde: proStunde(p))
                Protokollstreifen(
                    werte: p.room.window, farbe: Farbe.alarm, wort: "Fenster",
                    proStunde: proStunde(p))
                zeitmarken(p)
                legende(spanne)
            }
        } else {
            Leer(
                satz: "Für diesen Zeitraum liegen keine Messwerte vor.",
                dazu: "Die Zeitreihe beginnt, sobald die Brücke den Raum gelesen hat."
            )
        }
    }

    private func proStunde(_ p: RoomLogOut) -> Int {
        max(1, Int((60.0 / Double(p.stepMin)).rounded()))
    }

    private func zeitmarken(_ p: RoomLogOut) -> some View {
        // **Um Mitternacht das Datum statt der Uhrzeit.** Über zwei Tage ist „00:00" zweimal
        // dieselbe Marke, und dann weiß niemand, welcher Tag gemeint ist.
        let marken = Achse.beschriftungen(p.ts, hoechstens: 5)
        return HStack(spacing: 0) {
            ForEach(Array(marken.enumerated()), id: \.offset) { i, iso in
                Text(markentext(iso))
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                if i < marken.count - 1 { Spacer(minLength: 2) }
            }
        }
    }

    private func markentext(_ iso: String) -> String {
        guard let d = Zeit.ausIso(iso) else { return "" }
        let uhr = Formate.hhmm(d)
        return uhr == "00:00" ? Tag.kurz(Tag.iso(d)) : uhr
    }

    private func legende(_ spanne: (von: Double, bis: Double)) -> some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 6) {
            posten(farbe: Farbe.amber, wort: "gemessen", gestrichelt: false)
            posten(farbe: Farbe.text3, wort: "geregelt auf (Soll + Versatz)", gestrichelt: true)
            Text(
                "Spanne \(Formate.celsius(spanne.von, stellen: 1)) bis \(Formate.celsius(spanne.bis, stellen: 1))"
            )
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
        }
    }

    private func posten(farbe: Color, wort: String, gestrichelt: Bool) -> some View {
        HStack(spacing: 6) {
            Canvas { g, groesse in
                var p = Path()
                p.move(to: CGPoint(x: 0, y: groesse.height / 2))
                p.addLine(to: CGPoint(x: groesse.width, y: groesse.height / 2))
                g.stroke(
                    p, with: .color(farbe),
                    style: StrokeStyle(lineWidth: 2, dash: gestrichelt ? [4, 3] : []))
            }
            .frame(width: 18, height: 6)
            Text(wort).font(Schrift.achse).foregroundStyle(Farbe.text2)
        }
    }

    // MARK: - Die Zeitleiste

    @ViewBuilder private func zeitleiste(_ p: RoomLogOut) -> some View {
        Karte(kicker: "Was geschah") {
            if p.entries.isEmpty {
                Leer(
                    satz: "In diesem Zeitraum hat niemand den Sollwert verändert.",
                    dazu: "Dann liegt die Ursache einer Abweichung nicht an der Regelung, sondern an der Vorlauftemperatur, an einem Fenster oder am Fühler."
                )
            } else {
                VStack(spacing: 0) {
                    // **Neueste zuerst.** Wer das Protokoll öffnet, sucht das Letzte, nicht das
                    // Erste.
                    ForEach(Array(p.entries.reversed().enumerated()), id: \.offset) { i, e in
                        if i > 0 { Divider().overlay(Farbe.linie1) }
                        zeile(e)
                    }
                }
            }
        }
    }

    private func zeile(_ e: RoomLogEntryOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Formate.tagUndUhr(iso: e.at, jetzt: haus.jetzt))
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text3)
                Abzeichen(wort: Raumprotokoll.quelleWort(e.quelle), farbe: quellfarbe(e.quelle))
                Spacer(minLength: 6)
                let sprung = Raumprotokoll.sprungText(von: e.fromC, nach: e.toC)
                if !sprung.isEmpty {
                    Text(sprung).font(Schrift.zahl).foregroundStyle(Farbe.text1)
                }
            }
            HStack(spacing: 6) {
                Text(e.text.isEmpty ? Raumprotokoll.artText(e.art) : e.text)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                if let u = e.urheber, !u.isEmpty {
                    Text("· \(u)").font(Schrift.winzig).foregroundStyle(Farbe.text3)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// **Von außen ist bernstein, nicht rot.** Eine Änderung von außen ist kein Fehler –
    /// meistens war es ein Mensch, der genau das wollte. Sie soll auffallen, nicht warnen.
    private func quellfarbe(_ q: RoomLogEntryOutQuelleWahl) -> Color {
        switch q {
        case .extern: return Farbe.amber
        case .app: return Farbe.pv
        case .automatik, .unbekannt: return Farbe.text2
        }
    }

    private var fussnote: some View {
        Text(
            "„Von außen“ heißt nicht „unbefugt“, sondern nur: nicht über diese App. Meistens war es ein Mensch an der Regelung selbst oder an einem Thermostat."
        )
        .font(Schrift.winzig)
        .foregroundStyle(Farbe.text3)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Laden

    private func hole() async {
        laeuft = true
        do {
            log = try await haus.api.raumProtokoll(
                raumId, stunden: stunden, schrittMin: schrittMin)
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
        laeuft = false
    }
}

/// Die beiden Kurven mit den Marken der Sollwertänderungen.
///
/// **Die Zielkurve liegt unten, die gemessene darüber.** Die gemessene ist die Auskunft; die
/// geregelte ist der Maßstab, an dem man sie liest.
struct Protokollkurve: View {
    let log: RoomLogOut
    let spanne: (von: Double, bis: Double)

    var body: some View {
        HStack(spacing: 6) {
            // Die Achse als Text daneben, nicht im Bild: im Bild stünde sie über der Kurve.
            VStack(alignment: .trailing) {
                Text(Formate.zahl(spanne.bis, stellen: 1))
                Spacer(minLength: 0)
                Text(Formate.zahl(spanne.von, stellen: 1))
            }
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
            Canvas { g, groesse in
                male(in: &g, groesse: groesse)
            }
            .accessibilityHidden(true)
        }
    }

    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        // Waagerechte Hilfslinien an den Rändern und in der Mitte.
        for anteil in [0.0, 0.5, 1.0] {
            var p = Path()
            let y = anteil * groesse.height
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: groesse.width, y: y))
            g.stroke(p, with: .color(Farbe.rasterlinie), lineWidth: 1)
        }
        // Je Sollwertänderung eine Senkrechte, damit Knick und Grund auf derselben Linie liegen.
        for e in log.entries where e.art == .sollwert {
            guard let anteil = stelle(e.at) else { continue }
            var p = Path()
            p.move(to: CGPoint(x: anteil * groesse.width, y: 0))
            p.addLine(to: CGPoint(x: anteil * groesse.width, y: groesse.height))
            g.stroke(
                p, with: .color(e.quelle == .automatik ? Farbe.text2 : Farbe.amber),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        zeichne(log.targetC, in: &g, groesse: groesse, farbe: Farbe.text3, dash: [6, 5])
        zeichne(log.room.tempC, in: &g, groesse: groesse, farbe: Farbe.amber, dash: [])
    }

    private func zeichne(
        _ reihe: [Double?], in g: inout GraphicsContext, groesse: CGSize, farbe: Color,
        dash: [CGFloat]
    ) {
        for stueck in Raumprotokoll.stuecke(reihe, spanne: spanne) {
            var p = Path()
            for (i, punkt) in stueck.enumerated() {
                let s = CGPoint(x: punkt.x * groesse.width, y: punkt.y * groesse.height)
                if i == 0 { p.move(to: s) } else { p.addLine(to: s) }
            }
            g.stroke(
                p, with: .color(farbe),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: dash))
        }
    }

    /// Wo ein Zeitpunkt auf der Breite liegt – 0 am Anfang, 1 am Ende.
    private func stelle(_ iso: String) -> Double? {
        guard let d = Zeit.ausIso(iso),
              let von = Zeit.ausIso(log.start),
              let bis = Zeit.ausIso(log.end),
              bis > von
        else { return nil }
        let anteil = d.timeIntervalSince(von) / bis.timeIntervalSince(von)
        guard anteil >= 0, anteil <= 1 else { return nil }
        return anteil
    }
}

/// Ein Streifen mit einem Feld je Stunde – Ventil oder Fenster.
struct Protokollstreifen: View {
    let werte: [Double?]
    let farbe: Color
    let wort: String
    let proStunde: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(wort)
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
                .frame(width: 38, alignment: .trailing)
            Canvas { g, groesse in
                let stunden = Raumkarte.ventilstunden(werte, proStunde: proStunde)
                guard !stunden.isEmpty else { return }
                let breite = groesse.width / CGFloat(stunden.count)
                for (i, f) in stunden.enumerated() {
                    let kasten = CGRect(
                        x: CGFloat(i) * breite + 0.25, y: 0,
                        width: max(0.5, breite - 0.5), height: groesse.height)
                    let rund = Path(roundedRect: kasten, cornerRadius: 1)
                    switch f {
                    case .wert(let a) where a > 0:
                        g.fill(rund, with: .color(farbe.opacity(0.35 + 0.65 * a)))
                    case .wert:
                        g.fill(rund, with: .color(.white.opacity(0.05)))
                    case .keinWert, .nochNicht:
                        g.fill(rund, with: .color(.white.opacity(0.03)))
                    }
                }
            }
            .frame(height: 8)
        }
        .accessibilityHidden(true)
    }
}
