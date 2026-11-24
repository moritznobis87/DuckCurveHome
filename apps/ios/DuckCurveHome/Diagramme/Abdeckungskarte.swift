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

    /// Welche Zelle berührt ist - die Reihe mit ``Abdeckungsraster/schluessel`` und die Zelle
    /// darin. `nil` heißt: noch keine.
    @State private var gewaehlt: Wahl?

    /// Eine berührte Zelle, mit der Reihe, zu der sie gehört.
    ///
    /// Der Schlüssel muss dabeistehen: drei Reihen liegen übereinander, und „Spalte 7, Stunde
    /// 3" gibt es dreimal. Zu sagen, welche der drei gemeint ist, ist der halbe Zweck der
    /// Auskunft - die Frage der Seite lautet, *welches* Gerät nichts geliefert hat.
    private struct Wahl: Equatable {
        let reihe: String
        let zelle: Abdeckungsraster.Treffer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if reihen.isEmpty {
                Leer(satz: "Keine Reihen gemeldet.")
            } else {
                auskunft
                ForEach(reihen) { reihe in
                    block(reihe)
                }
                skala
            }
        }
    }

    // MARK: - Die Auskunft zur berührten Zelle

    /// Tag, Stunde und Minutenzahl der berührten Zelle (`charts.ts:470-483`).
    ///
    /// **Eine Zeile für die ganze Karte und nicht eine je Reihe.** Berührt ist immer genau eine
    /// Zelle; drei Zeilen, von denen zwei leer bleiben, wären dreimal die Höhe für einmal die
    /// Auskunft. Darum nennt die Zeile die Reihe mit - sie steht sonst nicht daneben.
    ///
    /// Sie steht auch da, wenn niemand berührt hat: eine Zeile, die erst beim Tippen erscheint,
    /// verschiebt die drei Bilder darunter genau in dem Augenblick, in dem man eine Zelle
    /// treffen will.
    @ViewBuilder private var auskunft: some View {
        if let w = gewaehlt, let reihe = reihen.first(where: { $0.schluessel == w.reihe }),
            let a = reihe.auskunft(tag: w.zelle.tag, stunde: w.zelle.stunde)
        {
            Umbruchzeile(abstand: 12, zeilenabstand: 3) {
                Text(reihe.name)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text1)
                Text(a.tag)
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.amberWeich)
                Text(a.stunde)
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(Farbe.text2)
                // Eine leere Zelle sagt etwas über uns, eine rote über das Gerät - der
                // Unterschied entscheidet, wen man anschaut (`CoverageMap.tsx:24-27`). Darum
                // steht die Minutenzahl als Zahl da und die Leerstelle leiser.
                Text(a.wert)
                    .font(Schrift.zahlKlein)
                    .foregroundStyle(a.leer ? Farbe.text3 : Farbe.text1)
            }
        } else {
            Text(Abdeckungsraster.beruehrung)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
        }
    }

    /// Welche Zelle unter dem Finger lag.
    ///
    /// **Ein Tippen und kein Ziehen.** Ein `DragGesture` mit `minimumDistance: 0` nimmt der
    /// `ScrollView` der Seite die senkrechte Geste, und das Raster ist 239 Punkte hoch und
    /// seitenbreit: über ihm ließe sich die Seite dann nicht mehr rollen. Die Vorlage hat das
    /// Problem nicht, weil eine Maus zeigt, ohne zu greifen.
    ///
    /// **Ein zweites Tippen auf dieselbe Zelle nimmt die Auskunft zurück.** Sonst bliebe sie
    /// bis zum nächsten Tag stehen, und die Zeile über der Karte behauptete eine Berührung, die
    /// vorbei ist.
    private func waehle(_ reihe: Abdeckungsraster, ort: CGPoint, breite: CGFloat) {
        guard
            let zelle = Abdeckungsraster.treffer(
                x: Double(ort.x), y: Double(ort.y), gesamt: Double(breite),
                spalten: reihe.tage.count, zellenhoehe: Double(zellenhoehe),
                luecke: Double(luecke))
        else { return }
        let neu = Wahl(reihe: reihe.schluessel, zelle: zelle)
        gewaehlt = gewaehlt == neu ? nil : neu
    }

    // MARK: - Eine Reihe

    private func block(_ reihe: Abdeckungsraster) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            kopfzeile(reihe.kopfzeile(jetzt: jetzt))
            HStack(alignment: .top, spacing: 6) {
                stundenachse
                VStack(alignment: .leading, spacing: 3) {
                    Canvas { gestalt, groesse in
                        male(
                            reihe.tage, in: &gestalt, groesse: groesse,
                            zelle: gewaehlt?.reihe == reihe.schluessel ? gewaehlt?.zelle : nil)
                    }
                    .frame(height: rasterhoehe)
                    // Die Breite kennt nur das Bild selbst, und die Trefferrechnung braucht
                    // sie. Ein `GeometryReader` im Überzug liest sie, ohne die Lage von
                    // irgendetwas zu ändern - er füllt, was schon vermessen ist.
                    .overlay {
                        GeometryReader { raum in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    SpatialTapGesture().onEnded { tipp in
                                        waehle(
                                            reihe, ort: tipp.location,
                                            breite: raum.size.width)
                                    })
                        }
                    }
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
                .foregroundStyle(k.dringend ? Farbe.alarmText : Farbe.amber)
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
        _ tage: [Abdeckungsraster.Rastertag], in g: inout GraphicsContext, groesse: CGSize,
        zelle: Abdeckungsraster.Treffer?
    ) {
        guard !tage.isEmpty else { return }
        // Dieselbe Rechnung wie die Trefferprüfung, und darum dieselbe Funktion: stünde die
        // Formel hier zum zweiten Mal, zeigte die Auskunft nach der ersten Änderung auf die
        // Nachbarspalte - und das bemerkt niemand, weil zwei Nachbartage ähnlich aussehen.
        let spaltenbreite = CGFloat(
            Abdeckungsraster.spaltenbreite(
                gesamt: Double(groesse.width), spalten: tage.count, luecke: Double(luecke)))
        for (i, tag) in tage.enumerated() {
            let x = CGFloat(i) * (spaltenbreite + luecke)
            for stunde in 0..<24 {
                let minuten = stunde < tag.stunden.count ? tag.stunden[stunde] : nil
                let kasten = CGRect(
                    x: x, y: CGFloat(stunde) * (zellenhoehe + luecke),
                    width: spaltenbreite, height: zellenhoehe)
                // Keine Minutenzeile, keine Farbe: hier bleibt die Kartenfläche stehen.
                if let farbe = Abdeckungsraster.farbe(minuten: minuten) {
                    g.fill(
                        Path(roundedRect: kasten, cornerRadius: 1.5),
                        with: .color(Color(farbe)))
                }
                // Die berührte Zelle bekommt einen hellen Rand (``Farbe/zelleBeruehrt``)
                // - **auch die leere**: dass hier nichts ist, ist auf dieser Seite eine
                // Auskunft und kein Fehlgriff. Hier stand `Farbe.text1.opacity(0.85)`, und
                // das sind nicht 0,85: SwiftUI multipliziert mit der Deckung, die `text1`
                // schon trägt.
                if let zelle, zelle.tag == i, zelle.stunde == stunde {
                    g.stroke(
                        Path(roundedRect: kasten, cornerRadius: 1.5),
                        with: .color(Farbe.zelleBeruehrt), lineWidth: 1)
                }
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
            let spaltenbreite = CGFloat(
                Abdeckungsraster.spaltenbreite(
                    gesamt: Double(groesse.width), spalten: tage.count, luecke: Double(luecke)))
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
    ///
    /// **Und sie ist nicht greifbar.** Das Band der Vorlage trägt `calculable: true`
    /// (`charts.ts:519`): man kann seine Griffe ziehen und damit den Farbbereich
    /// einschränken. Hier ginge das nur für alle drei Bilder zugleich - und es nähme der
    /// Skala, was sie auf dieser Seite trägt: dass sie **fest** von null bis sechzig geht, ist
    /// ausdrücklich begründet (`charts.ts:437-440`, „eine Skala, die sich nach den Daten
    /// richtet, färbte einen Zeitraum ohne jede Lücke genauso wie einen mit lauter Lücken").
    /// Die Zelle genau zu beziffern leistet seit dem 21.11.2026 die Berührung, und die ist
    /// dafür das genauere Werkzeug.
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
