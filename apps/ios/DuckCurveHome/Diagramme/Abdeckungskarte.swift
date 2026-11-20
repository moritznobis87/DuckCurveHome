import DuckCurveKit
import SwiftUI

/// Kommen die Daten an? Achtundzwanzig Tage mal vierundzwanzig Stunden, je Messreihe.
///
/// **Warum eine Karte und keine Kurve** (`CoverageMap.tsx:13-27`). Die Frage ist nicht, wie
/// hoch eine Leistung war, sondern ob überhaupt etwas ankam. In einer Leistungskurve ist das
/// kaum zu sehen: eine Lücke sieht aus wie eine Null, und eine Null sieht aus wie eine Nacht
/// ohne Verbrauch. Als Fläche aus Tagen und Stunden wird ein Muster daraus - eine Verbindung,
/// die jede Nacht abreißt, ist ein waagerechter Streifen; eine, die alle paar Tage für zwei
/// Stunden wegbleibt, ein Fleck.
///
/// **Die Farbe ist absichtlich herum.** Vollständig ist ruhiges Blaugrau, fehlend ist rot. Eine
/// Karte ohne Lücken soll langweilig aussehen, damit die eine Lücke, die es gibt, ins Auge
/// springt. Die Rampe selbst steht im Kern (`Marken.abdeckungsfarbe`) und ist dort geprüft.
///
/// **Leer ist nicht null.** Eine Zelle ohne Farbe heißt, dass für diese Stunde überhaupt keine
/// Minutenzeile existiert - dann stand der Dienst still, und das ist unser Ausfall. Eine rote
/// Zelle heißt, dass Zeilen da sind und diese eine Reihe darin fehlt. Der Unterschied
/// entscheidet, wen man anschaut, darum wird eine leere Zelle gar nicht gezeichnet: es bleibt
/// die Kartenfläche stehen.
///
/// **Gezeichnet, nicht gestapelt.** 28 mal 24 sind 672 Felder je Reihe, bei drei Reihen über
/// zweitausend. Als `RoundedRectangle` wären das zweitausend Ansichten, die SwiftUI bei jedem
/// Bildwechsel neu vermisst - dasselbe Urteil wie bei der Abweichungsmatrix, und darum derselbe
/// Weg: ein `Canvas` je Reihe.
struct Abdeckungskarte: View {
    let reihen: [Abdeckungsraster]
    /// Wofür „letzter Wert vor 3 min" gilt. Kommt von außen, damit die Karte bei jedem
    /// Live-Bild dieselbe Uhrzeit benutzt wie der Rest der Seite.
    let jetzt: Date

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    /// Vierundzwanzig Zeilen auf 240 Punkte (`CoverageMap.tsx:108`, `height: 240`): zehn Punkte
    /// je Stunde, davon einer Lücke.
    private let zellenhoehe: CGFloat = 9
    private let luecke: CGFloat = 1
    /// Platz für „06:00" links, am Telefon für „06".
    private var achsenbreite: CGFloat { schmal ? 24 : 42 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if reihen.isEmpty {
                Leer(satz: "Keine Reihen gemeldet.")
            } else {
                ForEach(reihen) { reihe in
                    block(reihe)
                }
                skala
            }
        }
    }

    // MARK: - Eine Reihe

    private func block(_ reihe: Abdeckungsraster) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            kopfzeile(reihe.kopfzeile(jetzt: jetzt))
            HStack(alignment: .top, spacing: 6) {
                stundenachse
                VStack(alignment: .leading, spacing: 3) {
                    Canvas { gestalt, groesse in
                        male(reihe.tage, in: &gestalt, groesse: groesse)
                    }
                    .frame(height: rasterhoehe)
                    tagesachse(reihe.tage)
                }
            }
        }
    }

    /// Die Kopfzeile: Name, Abdeckung, und was sonst zu sagen ist (`CoverageMap.tsx:65-80`).
    ///
    /// Umbrechend, weil die drei Stücke am Telefon nicht nebeneinander passen - und zwar in
    /// dieser Reihenfolge, damit beim Umbruch der Name oben stehen bleibt.
    private func kopfzeile(_ k: Abdeckungsraster.Kopfzeile) -> some View {
        Umbruchzeile(abstand: 14, zeilenabstand: 3) {
            Text(k.name)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text1)
            // Unter 99 Prozent ist die Zahl die Nachricht, nicht die Beigabe.
            Text(k.abdeckung)
                .font(Schrift.zahlKlein)
                .foregroundStyle(k.dringend ? Farbe.alarm : Farbe.amber)
            Text(k.satz)
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
        }
    }

    private var rasterhoehe: CGFloat {
        CGFloat(24) * zellenhoehe + CGFloat(23) * luecke
    }

    /// Die Stunden links, alle sechs eine Beschriftung (`charts.ts:515`, `interval i % 6`).
    ///
    /// Vierundzwanzig Zeilen mit drei Wörtern darin: die leeren Zeilen tragen die Höhe, damit
    /// „06:00" neben seiner Zeile steht und nicht daneben.
    private var stundenachse: some View {
        VStack(spacing: luecke) {
            ForEach(0..<24, id: \.self) { stunde in
                Text(stunde % 6 == 0 ? stundenwort(stunde) : "")
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                    .frame(width: achsenbreite, height: zellenhoehe, alignment: .trailing)
            }
        }
        // Die Beschriftung ist höher als ihre Zeile; sie darf die Zeile daneben überlappen,
        // aber die Achse nicht breiter machen als das Raster hoch ist.
        .frame(height: rasterhoehe, alignment: .top)
    }

    /// An der Wand „06:00", am Telefon „06" - dieselbe Regel wie in der Abweichungsmatrix.
    private func stundenwort(_ stunde: Int) -> String {
        schmal ? String(format: "%02d", stunde) : String(format: "%02d:00", stunde)
    }

    // MARK: - Das Raster

    /// Eine Spalte je Tag, eine Zeile je Stunde, Mitternacht oben.
    ///
    /// Oben Mitternacht und nicht unten (`charts.ts:511`, `inverse: true`): so liest sich die
    /// Spalte wie ein Tagesplan von früh nach spät.
    private func male(
        _ tage: [Abdeckungsraster.Rastertag], in g: inout GraphicsContext, groesse: CGSize
    ) {
        guard !tage.isEmpty else { return }
        let spalten = CGFloat(tage.count)
        let spaltenbreite = max(1, (groesse.width - (spalten - 1) * luecke) / spalten)
        for (i, tag) in tage.enumerated() {
            let x = CGFloat(i) * (spaltenbreite + luecke)
            for stunde in 0..<24 {
                let minuten = stunde < tag.stunden.count ? tag.stunden[stunde] : nil
                // Keine Minutenzeile, keine Farbe: hier bleibt die Kartenfläche stehen.
                guard let farbe = Abdeckungsraster.farbe(minuten: minuten) else { continue }
                let kasten = CGRect(
                    x: x, y: CGFloat(stunde) * (zellenhoehe + luecke),
                    width: spaltenbreite, height: zellenhoehe)
                g.fill(
                    Path(roundedRect: kasten, cornerRadius: 1.5),
                    with: .color(Color(farbe)))
            }
        }
    }

    /// Die Tage unter dem Raster, jeder dritte beschriftet.
    ///
    /// Die Vorlage beschriftet ungefähr zehn von `days` Spalten (`charts.ts:498`); bei
    /// achtundzwanzig Tagen ist das jeder dritte. Gezeichnet statt gestapelt, weil die
    /// Beschriftung über der Spaltenmitte stehen muss, und die kennt nur die Breite - dieselbe
    /// Rechnung wie beim Raster darüber.
    private func tagesachse(_ tage: [Abdeckungsraster.Rastertag]) -> some View {
        Canvas { gestalt, groesse in
            guard !tage.isEmpty else { return }
            let spalten = CGFloat(tage.count)
            let spaltenbreite = max(1, (groesse.width - (spalten - 1) * luecke) / spalten)
            let schritt = max(1, Int((Double(tage.count) / 10).rounded()))
            for (i, tag) in tage.enumerated() where i % schritt == 0 {
                let mitte = CGFloat(i) * (spaltenbreite + luecke) + spaltenbreite / 2
                let wort = Text(Tag.tagMonat(tag.tag))
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                gestalt.draw(wort, at: CGPoint(x: mitte, y: groesse.height / 2), anchor: .center)
            }
        }
        .frame(height: 12)
    }

    // MARK: - Die Skala

    /// Was die Farbe heißt: null bis sechzig Minuten je Stunde.
    ///
    /// **Eine Skala für die ganze Karte, nicht eine je Reihe.** Die Vorlage setzt neben jedes
    /// der drei Bilder ein eigenes `visualMap` (`charts.ts:517-536`) - sie muss, weil jedes
    /// Bild ein eigenes Diagramm ist. Hier ist die Skala für alle drei dieselbe, fest von null
    /// bis sechzig, und dreimal dasselbe Band wäre dreimal dieselbe Auskunft.
    private var skala: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: achsenbreite)
            Text("0")
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
            LinearGradient(
                colors: Marken.abdeckung.map { Color($0) },
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 6)
            .clipShape(Capsule())
            Text("60 min je Stunde")
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text3)
        }
    }
}
