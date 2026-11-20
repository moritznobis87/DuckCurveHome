import DuckCurveKit
import SwiftUI

/// Welcher Block der Konsole aufgeklappt ist.
///
/// Vorlage: `Klappe` in `house/Konsole.tsx:23`. Derselbe Zuschnitt - vier Blöcke mit einer
/// Anschlussfrage, der Alarm ohne eine: er sagt alles, was er zu sagen hat, im Block selbst.
enum Konsolenklappe: String, Identifiable, Hashable, CaseIterable {
    case kontakte
    case puffer
    case waermepumpe
    case kreise

    var id: String { rawValue }

    var kicker: String {
        switch self {
        case .kontakte: return "Fenster und Türen"
        case .puffer: return "Puffer"
        case .waermepumpe: return "Wärmepumpe"
        case .kreise: return "Heizkreise"
        }
    }
}

/// Die Antwort auf die Frage, die ein Block der Konsole aufwirft.
///
/// **Warum ein Blatt und kein Fenster neben dem Block.** Die Vorlage legt `.haus-pop` rechts
/// neben die Konsole und über das Modell (`globals.css:515`). In SwiftUI gibt es dafür kein
/// freies Überlagern am Rand einer Spalte, und `popover` verhält sich am iPad anders als am
/// Telefon. Die Vorlage selbst nimmt am Telefon denselben Weg wie hier und schreibt die
/// Begründung dazu (`globals.css:544-546`): „Auf dem Telefon liegt die Konsole quer und
/// scrollt; ein Fenster daneben haette keinen Platz … Es kommt deshalb als Blatt von unten.“
///
/// **Der Fuß behält seinen Verweis.** Bis zum heutigen Umbau führte jeder Block der App auf
/// eine andere Seite. Dieser Weg verschwindet nicht - er rutscht nur dorthin, wo ihn die
/// Vorlage auch hat: unter die Antwort (`Konsole.tsx:225`, `:275`, `:304`, `:347`).
struct Hauskonsolenblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser
    @Environment(\.dismiss) private var schliessen

    let art: Konsolenklappe
    let plan: HousePlan?
    let kontakte: [HouseContactOut]
    let raeume: [RoomLiveOut]
    /// Aus einer Zeile in den Raum im Modell. Ohne Plan bleibt es leer.
    let springe: (Hauskonsolenfenster.Ort) -> Void

    private typealias F = Hauskonsolenfenster

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    inhalt
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .seitengrund()
            .navigationTitle(art.kicker)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }

    @ViewBuilder private var inhalt: some View {
        switch art {
        case .kontakte: kontaktfenster
        case .puffer: pufferfenster
        case .waermepumpe: pumpenfenster
        case .kreise: kreisfenster
        }
    }

    // MARK: - Fenster und Türen

    private var kontaktfenster: some View {
        let zeilen = F.kontaktzeilen(plan: plan, kontakte: kontakte)
        return VStack(alignment: .leading, spacing: 0) {
            if zeilen.isEmpty {
                leersatz("Der Hausplan nennt keine Kontakte.")
            }
            ForEach(Array(zeilen.enumerated()), id: \.element.schluessel) { stelle, z in
                trenner(stelle)
                kontaktzeile(z)
            }
            fuss(
                "Die Kontakte kommen aus der Alarmanlage. Ein Tippen auf eine Zeile holt den "
                    + "Raum ins Modell.")
        }
    }

    private func kontaktzeile(_ z: F.Kontaktzeile) -> some View {
        zeile(
            links: z.name, unten: z.unterzeile, stark: z.offen == true,
            rechts: z.wort, klein: kontaktdauer(z), farbe: wortfarbe(z.offen),
            tippen: z.ort.map { ort in { springe(ort) } })
    }

    /// „ seit 12 min“ steht nur an offenen Kontakten (`Konsole.tsx:212`): bei einem
    /// geschlossenen ist die Dauer keine Nachricht.
    private func kontaktdauer(_ z: F.Kontaktzeile) -> String? {
        guard z.offen == true, let d = F.seitText(z.beobachtetAm, jetzt: haus.jetzt) else {
            return nil
        }
        return "seit \(d)"
    }

    private func wortfarbe(_ offen: Bool?) -> Color {
        switch offen {
        case .some(true): return Farbe.amber
        case .some(false): return Farbe.text2
        case nil: return Farbe.text3
        }
    }

    // MARK: - Puffer

    private var pufferfenster: some View {
        let puffer = haus.zustand?.buffer
        let zeilen = F.schichtzeilen(haus.augenblick?.bufferTempsC)
        return VStack(alignment: .leading, spacing: 0) {
            grossezahl(
                Formate.kwh(puffer?.usableEnergyKwh),
                dazu: "nutzbar von " + Formate.kwh(puffer?.capacityKwh))
            ForEach(Array(zeilen.enumerated()), id: \.element.name) { stelle, s in
                trenner(stelle)
                schichtzeile(s)
            }
            trenner(1)
            zeile(
                links: "Zustand", unten: nil, stark: true,
                rechts: F.statuswort(puffer?.status), klein: restplatz(puffer),
                farbe: Farbe.text2, tippen: nil)
            fuss(pufferfuss(puffer), weg: "/waerme", verweis: "Wärme und Verlauf")
        }
    }

    private func schichtzeile(_ s: F.Schichtzeile) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(s.tempC == nil ? Farbe.flaeche3 : Color(Marken.wasserfarbe(s.tempC)))
                .frame(width: 9, height: 9)
                .padding(.top, 4)
            Text(s.name).font(Schrift.sans(13)).foregroundStyle(Farbe.text2)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(s.tempC == nil ? "kein Messwert" : Formate.celsius(s.tempC, stellen: 1))
                    .font(Schrift.mono(12))
                    .foregroundStyle(s.frisch ? Farbe.text2 : Farbe.text3)
                if let alt = schichtalter(s) {
                    Text(alt).font(Schrift.mono(10)).foregroundStyle(Farbe.text3)
                }
            }
        }
        .padding(.vertical, 7)
    }

    /// Das Alter steht nur an einem Fühler, der **nicht** frisch ist - sonst stünde an vier
    /// Zeilen viermal dieselbe Minute (`Konsole.tsx:259`).
    private func schichtalter(_ s: F.Schichtzeile) -> String? {
        guard !s.frisch, s.tempC != nil,
              let d = F.seitText(s.beobachtetAm, jetzt: haus.jetzt)
        else { return nil }
        return "vor \(d)"
    }

    private func restplatz(_ puffer: BufferState?) -> String? {
        guard let anteil = puffer?.headroomSoc else { return nil }
        return "noch " + Formate.prozent(anteil) + " Platz"
    }

    private func pufferfuss(_ puffer: BufferState?) -> String {
        let satz = F.methodensatz(puffer?.method)
        guard let liter = puffer?.volumeLiters, liter > 0 else { return satz + "." }
        return satz + " · " + Formate.zahl(liter, stellen: 0) + " Liter."
    }

    // MARK: - Wärmepumpe

    private var pumpenfenster: some View {
        let lauf = F.tageslauf(haus.raster.punkte)
        let achse = F.kurvenachse(lauf)
        let wp = haus.zustand?.heatPump
        return VStack(alignment: .leading, spacing: 0) {
            Konsolenkurve(stuecke: F.sparklinie(verdichtet, hoechst: achse), hoechst: achse)
                .padding(.bottom, 8)
            zeile(
                links: "heute", unten: nil, stark: true,
                rechts: Formate.kwh(lauf.kwh) + " Strom", klein: nil, farbe: Farbe.text2,
                tippen: nil)
            trenner(1)
            zeile(
                links: "Laufzeit", unten: nil, stark: true,
                rechts: Formate.dauer(minuten: lauf.minuten), klein: nil, farbe: Farbe.text2,
                tippen: nil)
            trenner(1)
            zeile(
                links: "Starts", unten: nil, stark: true,
                rechts: wp.map { String($0.startsToday) } ?? Formate.leer, klein: nil,
                farbe: Farbe.text2, tippen: nil)
            trenner(1)
            zeile(
                links: "Anforderung", unten: "das Signal: jetzt mehr Wärme erzeugen",
                stark: true, rechts: (wp?.releaseContactOn ?? false) ? "an" : "aus", klein: nil,
                farbe: (wp?.releaseContactOn ?? false) ? Farbe.amber : Farbe.text2,
                tippen: nil)
            if let grund = haus.zustand?.decision?.explanationDe, !grund.isEmpty {
                begruendung(grund)
            }
            fuss(betriebssatz, weg: "/waerme", verweis: "Erzeuger und Verlauf")
        }
    }

    /// Das Minutenraster auf 96 Stellen - eine Kurve aus tausend Punkten in einem Blatt von
    /// 330 Punkten Breite wäre ein Strich (`Konsole.tsx:290`).
    private var verdichtet: [Double?] {
        F.verdichte(haus.raster.punkte.map(\.waermepumpe), stellen: 96)
    }

    private var betriebssatz: String {
        let auto = haus.zustand?.operatingMode.systemMode == .auto
        return "Betrieb: " + (auto ? "Automatik." : "von Hand.")
    }

    // MARK: - Heizkreise

    private var kreisfenster: some View {
        let zeilen = F.kreiszeilen(raeume, plan: plan)
        return VStack(alignment: .leading, spacing: 0) {
            if zeilen.isEmpty {
                leersatz("Kein Heizkreis steht offen.")
            }
            ForEach(Array(zeilen.enumerated()), id: \.element.id) { stelle, k in
                trenner(stelle)
                kreiszeile(k)
            }
            if let grenze = F.anDerGrenze(zeilen) {
                begruendung(F.grenzsatz(grenze))
            }
            fuss(
                "Die Antriebe sind auf oder zu, nichts dazwischen.", weg: "/waerme/raeume",
                verweis: "Heizkreise im Tagesverlauf")
        }
    }

    private func kreiszeile(_ k: F.Kreiszeile) -> some View {
        zeile(
            links: k.name, unten: k.etage, stark: true,
            rechts: Raumabweichung.ventilText(k.ventil, kreise: k.kreise),
            klein: k.tempC.map { Formate.celsius($0, stellen: 1) }, farbe: Farbe.amber,
            tippen: k.ort.map { ort in { springe(ort) } })
    }

    // MARK: - Die Bausteine der Fenster

    /// Eine Zeile des Fensters: links Name und Unterzeile, rechts das Wort und sein Beiwerk.
    ///
    /// **Ein Baustein für alle vier Fenster.** Die Vorlage hat dafür genau eine Komponente
    /// (`Konsole.tsx:38-57`), und vier Listen, die dasselbe anders setzen, laufen auseinander.
    private func zeile(
        links: String, unten: String?, stark: Bool, rechts: String, klein: String?,
        farbe: Color, tippen: (() -> Void)?
    ) -> some View {
        let inhalt = HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(links)
                    .font(Schrift.sans(13))
                    .foregroundStyle(stark ? Farbe.text1 : Farbe.text2)
                    .fixedSize(horizontal: false, vertical: true)
                if let unten {
                    Text(unten.uppercased())
                        .font(Schrift.mono(10))
                        .tracking(0.8)
                        .foregroundStyle(Farbe.text3)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(rechts).font(Schrift.mono(12)).foregroundStyle(farbe)
                if let klein {
                    Text(klein).font(Schrift.mono(10)).foregroundStyle(Farbe.text3)
                }
            }
        }
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        return Group {
            if let tippen {
                Button(action: tippen) { inhalt }.buttonStyle(.plain)
            } else {
                inhalt
            }
        }
    }

    /// Die Haarlinie zwischen zwei Zeilen - vor der ersten steht keine
    /// (`globals.css:522`: `li + li`).
    @ViewBuilder private func trenner(_ stelle: Int) -> some View {
        if stelle > 0 {
            Rectangle().fill(Farbe.linie1).frame(height: 1)
        }
    }

    private func grossezahl(_ wert: String, dazu: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(wert).font(Schrift.mono(28)).foregroundStyle(Farbe.text1)
            Text(dazu).font(Schrift.sans(12)).foregroundStyle(Farbe.text3)
        }
        .padding(.bottom, 8)
    }

    private func leersatz(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.sans(11.5))
            .foregroundStyle(Farbe.text3)
            .padding(.vertical, 8)
    }

    /// Der Grund in seinem eigenen Kasten mit der linken Linie (`globals.css:537`).
    private func begruendung(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.sans(12))
            .foregroundStyle(Farbe.text2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche1.opacity(0.4))
            .overlay(alignment: .leading) {
                Rectangle().fill(Farbe.linie2).frame(width: 2)
            }
            .padding(.top, 10)
    }

    private func fuss(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.sans(11.5))
            .foregroundStyle(Farbe.text3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
    }

    private func fuss(_ satz: String, weg: String, verweis: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(satz)
                .font(Schrift.sans(11.5))
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                schliessen()
                wegweiser.gehe(weg)
            } label: {
                Text(verweis).font(Schrift.sans(11.5)).foregroundStyle(Farbe.amber)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }
}
