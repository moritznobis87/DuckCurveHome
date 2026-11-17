import DuckCurveKit
import SwiftUI

/// Jetzt: die Startseite.
///
/// Sie beantwortet eine Frage: **Was tut das Haus gerade, und warum.** Ein Satz, das lebende
/// Bild, die Kurve des Tages, vier Zahlen und das Dock. Alles Analytische steht in den Bereichen;
/// wer eine Zahl verstehen will, tippt sie an.
///
/// **Kurve und Zahlen kennen drei Tage, das Bild oben nur einen.** Gestern, heute, morgen
/// schalten gemeinsam um; der Energiefluss und das Dock bleiben beim Jetzt - ein Schalter, der an
/// einer Wand ein Geraet von gestern anboete, waere eine Falle.
///
/// **Was hier nicht mehr ist** (und im Dashboard auch nicht): die Messuhren, die
/// Begruendungs-Chips, die vier Zeitspuren und das Blaettern durch Tage. Die Begruendung ist der
/// Satz oben; vergangene Tage stehen unter Strom, mit allem Blaettern, das dort hingehoert.
struct JetztSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    @State private var tag: Kurventag = .heute
    @State private var vortag: [Verlaufspunkt] = []
    @State private var waermeprognose: [HeatForecastPoint] = []
    @State private var bilanz: EnergySummaryOut?
    @State private var geholterVortag = ""

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            satzblock
            if schmal {
                Energiefluss(
                    augenblick: haus.augenblick, jetzt: haus.jetzt,
                    pvSpitzeKw: pvSpitze, wpLaeuft: haus.zustand?.heatPump.running,
                    nacht: istNacht, sonneAb: sonneAb
                )
                Leiste(kompakt: true)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    Energiefluss(
                        augenblick: haus.augenblick, jetzt: haus.jetzt,
                        pvSpitzeKw: pvSpitze, wpLaeuft: haus.zustand?.heatPump.running,
                        nacht: istNacht, sonneAb: sonneAb
                    )
                    .frame(maxWidth: .infinity)
                    Leiste()
                        .frame(width: 260)
                }
            }
            kurve
            Kachelfeld(kacheln: kennzahlen, kicker: tagwort)
            Karte(kicker: "Schalten") {
                Dock()
            }
        }
        .task(id: tag) { await ladeFuerTag() }
        .task(id: haus.heute) { await ladeVortag() }
        .task(id: tag) { await haltBilanzFrisch() }
    }

    // MARK: - Der Satz

    private var satzblock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(haus.satz)
                .font(Schrift.satz)
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            if !unterzeile.isEmpty {
                Text(unterzeile)
                    .font(Schrift.winzig)
                    .foregroundStyle(Farbe.text3)
            }
            Wache(befunde: haus.zustand?.system.watch ?? [])
            if let f = haus.fehler {
                Stoerung(fehler: f) {
                    Task { await haus.ersteLadung() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Die Zeile unter dem Satz, in Worten statt in Kennungen. Erst, wer gerade entscheidet; dann,
    /// was als Naechstes kommt oder seit wann der Satz gilt.
    private var unterzeile: String {
        var teile: [String] = []
        let wort = haus.betriebswort
        if !wort.isEmpty { teile.append(wort) }

        let laeuft = haus.zustand?.heatPump.running ?? false
        let vonHand = haus.zustand?.operatingMode.override != nil
        let aus = haus.zustand?.operatingMode.systemMode == .off
        if !laeuft, !vonHand, !aus,
           // Der Baukoerper steht mit Namen da und nicht angehaengt: in einer
           // `if`-Bedingung ist ein angehaengter nicht vom Rumpf des `if` zu unterscheiden -
           // fuer den Compiler eine Warnung, fuer den Leser schlimmer.
           let naechster = Fahrplan.phasen(
               haus.plan, jetzt: haus.jetzt, bis: haus.jetzt.addingTimeInterval(24 * 3600),
               wenn: { $0.reasonCode == "planned_optimizer" && $0.plannedHpState == .release }
           ).first,
           naechster.von > haus.jetzt
        {
            teile.append("nächster geplanter Lauf um \(Formate.hhmm(naechster.von))")
        } else if let d = haus.zustand?.decision, let at = Zeit.ausIso(d.at) {
            teile.append("Stand \(Formate.hhmm(at))")
        }
        return teile.joined(separator: " · ")
    }

    // MARK: - Die Kurve

    private var kurve: some View {
        Karte(kicker: "Der Tag", beiwerk: AnyView(Tagwahl(tag: $tag))) {
            TageskurveBild(
                kurve: Tageskurve.baue(
                    tag: tag,
                    raster: tag == .heute ? haus.raster.punkte : geholtesRaster,
                    vortag: tag == .heute ? vortag : [],
                    plan: haus.plan,
                    waermeprognose: waermeprognose,
                    jetzt: haus.jetzt
                ),
                tag: tag
            )
        }
    }

    /// Fuer gestern wird der Verlauf eigens geholt; fuer morgen gibt es keinen.
    @State private var geholtesRaster: [Verlaufspunkt] = []

    // MARK: - Die vier Zahlen

    private var tagwort: String {
        switch tag {
        case .gestern: return "Gestern"
        case .heute: return "Heute"
        case .morgen: return "Morgen erwartet"
        }
    }

    /// Vier Zahlen, gerechnet im Kern (``Tageskacheln``) und hier nur eingefaerbt.
    ///
    /// **Was hier vorher stand.** Sonne, „im Haus", „fuer die Waerme" und je nach Tag Netzbezug
    /// oder Preis - also drei andere Zahlen als die Wandanzeige. Autarkie, das bezahlte Geld und
    /// der Mittelpreis kamen auf der Seite nicht vor.
    private var kennzahlen: [Kacheldaten] {
        Tageskacheln.kennzahlen(
            tag: tag, bilanz: bilanz?.totals,
            preisJetzt: haus.augenblick?.electricityPriceCtKwh.belastbar,
            morgen: morgendaten
        )
        .map(Kacheldaten.init)
    }

    /// Was von morgen bekannt ist: Sonne und Preise aus dem Fahrplan, Waerme aus der Prognose.
    private var morgendaten: Tageskacheln.Morgen {
        guard tag == .morgen, let f = Tageskacheln.fenster(.morgen, jetzt: haus.jetzt) else {
            return .init()
        }
        let iv = haus.plan?.intervals ?? []
        return .init(
            pvKwh: Tageskacheln.pvSumme(iv, von: f.von, bis: f.bis),
            waerme: Tageskacheln.waermeSumme(waermeprognose, von: f.von, bis: f.bis),
            preise: Tageskacheln.preise(iv, von: f.von, bis: f.bis)
        )
    }

    // MARK: - Nachladen

    private var pvSpitze: Double {
        let erwartet = (haus.plan?.intervals ?? []).map(\.expectedPvKw).max() ?? 0
        return max(4, erwartet)
    }

    /// Tag oder Nacht - aus der Erwartung des Fahrplans, nicht aus der Uhr. Im Dezember ist um
    /// 17 Uhr Nacht und im Juni nicht.
    private var istNacht: Bool {
        let jetzt = haus.jetzt
        let nah = (haus.plan?.intervals ?? []).filter {
            guard let t = Zeit.ausIso($0.ts) else { return false }
            return abs(t.timeIntervalSince(jetzt)) < 1800
        }
        guard !nah.isEmpty else {
            // Ohne Plan: nach der Sonne im Augenblick.
            return (haus.augenblick?.pvPowerKw.belastbar ?? 0) < 0.05
        }
        return nah.allSatisfy { $0.expectedPvKw < 0.05 }
    }

    /// Wann die Sonne wiederkommt. Nur die Uhrzeit, ohne „morgen": ein Sonnenaufgang ist immer
    /// der naechste, und neben dem Mond ist kein Platz fuer mehr.
    private var sonneAb: String? {
        guard istNacht else { return nil }
        let kuenftig = (haus.plan?.intervals ?? []).compactMap { iv -> Date? in
            guard let t = Zeit.ausIso(iv.ts), t > haus.jetzt, iv.expectedPvKw >= 0.05 else { return nil }
            return t
        }
        return kuenftig.min().map { Formate.hhmm($0) }
    }

    private func ladeFuerTag() async {
        switch tag {
        case .heute:
            geholtesRaster = []
            waermeprognose = []
            // Autarkie, bezahltes Geld und Mittelpreis stehen nur in der Tagesbilanz. Sie wird
            // auch fuer den laufenden Tag geholt - vorher lief sie nur fuer gestern, und heute
            // standen darum drei Striche.
            bilanz = try? await haus.api.energieUebersicht("day", anker: haus.heute)
        case .gestern:
            let gestern = Tag.plus(haus.heute, -1)
            if let h = try? await haus.api.verlaufTag(gestern) {
                var r = Minutenraster()
                r.setze(h, tag: gestern)
                geholtesRaster = r.punkte
            }
            bilanz = try? await haus.api.energieUebersicht("day", anker: gestern)
            waermeprognose = []
        case .morgen:
            geholtesRaster = []
            bilanz = nil
            // Die Waermelastprognose reicht 48 Stunden und wird nur geholt, wenn jemand nach
            // morgen fragt - sonst ist es eine Anfrage, die niemand liest.
            if let w = try? await haus.api.energieWaerme("day", anker: haus.heute) {
                waermeprognose = w.forecast
            }
        }
    }

    /// Die Tagesbilanz des laufenden Tages veraltet, waehrend die Seite steht: bezahltes Geld und
    /// Autarkie wachsen mit jeder Viertelstunde. Die Wandanzeige holt sie alle fuenf Minuten neu.
    private func haltBilanzFrisch() async {
        guard tag == .heute else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            guard !Task.isCancelled, tag == .heute else { return }
            if let b = try? await haus.api.energieUebersicht("day", anker: haus.heute) {
                bilanz = b
            }
        }
    }

    /// Der Vortag liegt als Schattenkurve hinter heute. Eine Anfrage am Tag.
    private func ladeVortag() async {
        let gestern = Tag.plus(haus.heute, -1)
        guard Tag.istTag(gestern), geholterVortag != gestern else { return }
        geholterVortag = gestern
        guard let h = try? await haus.api.verlaufTag(gestern) else {
            geholterVortag = ""
            return
        }
        var r = Minutenraster()
        r.setze(h, tag: gestern)
        vortag = r.punkte
    }
}
