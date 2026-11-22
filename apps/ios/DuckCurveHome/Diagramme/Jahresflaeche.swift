import DuckCurveKit
import SwiftUI

/// Ein Jahr als Fläche: Tage nach rechts, Stunden nach unten, Mitternacht oben.
///
/// **Gezeichnet, nicht gestapelt.** 365 × 24 sind 8760 Felder. Als `RoundedRectangle` wären das
/// 8760 Ansichten, die SwiftUI bei jedem Bildwechsel neu vermisst - dasselbe Urteil wie bei der
/// Abdeckungskarte (`Diagramme/Abdeckungskarte.swift:23-26`) und bei der Abweichungsmatrix, nur
/// vierfach schwerer. Also ein `Canvas`.
///
/// **Mitternacht oben** (`charts.ts:511`, `inverse: true`): „00:00 oben, wie ein Tagesplan gelesen
/// wird“. Eine Spalte liest sich dann von früh nach spät.
///
/// **Gestaucht und nicht gerollt, auch am Telefon.** Die Vorlage hat dasselbe Problem - 365
/// Kategorien in ein Gitter von 350 Punkten - und löst es nicht: sie zeichnet alle und lässt
/// runden (`charts.ts:486`). Hier ebenso, und aus einem zusätzlichen Grund: Ablesen geschieht am
/// Telefon mit demselben Finger, mit dem gerollt würde. Ein `DragGesture(minimumDistance: 0)` in
/// einem waagerechten Rollbereich nimmt dem Rollen die Bewegung oder dem Ablesen - beides zugleich
/// geht nicht, und das Ablesen ist hier die Sache. Jeder Tag bleibt erreichbar, auch wenn seine
/// Spalte schmaler ist als ein Strich.
///
/// **Ziehen liest ab, Tippen auf das Blättchen führt weiter.** Die Vorlage trennt Überfahren
/// (Hinweis) und Klick (Sprung); am Telefon ist beides derselbe Finger. Darum bleibt das Blättchen
/// nach dem Loslassen stehen, und erst ein Tippen darauf öffnet die Wiedergabe - so ist der Sprung
/// bestätigt und nicht beiläufig.
struct Jahresflaeche: View {
    let raster: Jahresraster
    /// Wohin ein Tippen auf das Blättchen führt. Ohne diesen Griff trägt das Blättchen auch den
    /// Satz nicht, der einen Sprung verspricht.
    var aufZelle: ((Wiedergabeziel) -> Void)?

    @Environment(\.horizontalSizeClass) private var breite

    @State private var gezeigt: Jahresraster.Zellenhinweis?
    /// Die Spalte, über der der Finger steht - gemerkt, nicht nachgesucht: das Blättchen wird bei
    /// jedem Bildwechsel gesetzt, und eine Suche über 365 Tage je Bildwechsel ist eine zu viel.
    @State private var spalte: Int = 0

    private var schmal: Bool { breite == .compact }

    /// Die Höhe einer Stundenzeile.
    ///
    /// **Warum ein festes Maß je Zeile und nicht die Höhe der Karte.** Die Vorlage gibt der Karte
    /// `clamp(360px, 100dvh - 250px, 780px)` und rechnet die 24 Zeilen hinein (`YearMap.tsx:124`,
    /// Begründung dort: „Feste Höhe, keine Flex-Höhe: `height: 100%` im Chart löst sich sonst gegen
    /// eine unbestimmte Elternhöhe auf und die Karte fällt auf eine Linie zusammen“). Genau diese
    /// unbestimmte Elternhöhe hat die App: die Seite ist ein Rollbereich, und in einem Rollbereich
    /// gibt es keine Schirmhöhe, gegen die sich rechnen ließe. Also umgekehrt, und mit demselben
    /// Ergebnis am unteren Ende der Spanne: 24 × 11 sind 264 Punkte, mit Achse und Kartenkopf gut
    /// 350 - die Höhe, die die Vorlage am Telefon ohnehin bekommt.
    private let zellenhoehe: CGFloat = 11

    /// Platz für „06:00“ links, am Telefon für „06“ - dieselbe Regel wie in der Abdeckungskarte.
    private var achsenbreite: CGFloat { schmal ? 24 : 42 }
    /// Die Länge des waagerechten Skalenbandes: 190 Punkte wie die Vorlage (`charts.ts:529`,
    /// `itemHeight: 190` - bei waagerechter Lage ist das die Länge). Am Telefon kürzer, damit
    /// Zahlen und Polwörter in derselben Zeile daneben Platz haben.
    private var bandbreite: CGFloat { schmal ? 96 : 190 }
    private var rasterhoehe: CGFloat { CGFloat(Jahresraster.stundenJeTag) * zellenhoehe }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            skalenband
            HStack(alignment: .top, spacing: 6) {
                stundenachse
                VStack(alignment: .leading, spacing: 3) {
                    flaeche
                    monatsachse
                }
            }
        }
    }

    // MARK: - Die Fläche

    private var flaeche: some View {
        GeometryReader { raum in
            ZStack(alignment: .topLeading) {
                Canvas { gestalt, groesse in
                    male(in: &gestalt, groesse: groesse)
                }
                .contentShape(Rectangle())
                .gesture(ablesen(raum.size))
                if let gezeigt {
                    blaettchen(gezeigt, in: raum.size)
                }
            }
        }
        .frame(height: rasterhoehe)
    }

    /// Die Breite einer Tagesspalte. Ohne Lücke zwischen den Spalten: die Vorlage hat keine
    /// (`charts.ts:538-544`), und bei einem Punkt je Tag wäre eine Lücke die halbe Karte.
    private func spaltenbreite(_ gesamt: CGFloat) -> CGFloat {
        let spalten = CGFloat(max(1, raster.tage.count))
        return max(0.5, gesamt / spalten)
    }

    private func male(in g: inout GraphicsContext, groesse: CGSize) {
        let tage = raster.tage.count
        guard tage > 0 else { return }
        let breite = spaltenbreite(groesse.width)
        // Unter drei Punkten Spaltenbreite ist eine runde Ecke kein Radius mehr, sondern ein
        // Rechenweg ohne Wirkung - bei 8760 Feldern ist das der Unterschied zwischen einem Bild
        // und einem Ruckeln.
        let ecke: CGFloat = breite >= 3 ? 1.5 : 0
        for t in 0..<tage {
            let x = CGFloat(t) * breite
            for stunde in 0..<Jahresraster.stundenJeTag {
                // Keine Messdaten, keine Farbe: hier bleibt die Kartenfläche stehen.
                guard let farbe = raster.farbe(tag: t, stunde: stunde) else { continue }
                let kasten = CGRect(
                    x: x, y: CGFloat(stunde) * zellenhoehe,
                    width: breite, height: zellenhoehe)
                let pfad = ecke > 0
                    ? Path(roundedRect: kasten, cornerRadius: ecke)
                    : Path(kasten)
                g.fill(pfad, with: .color(Color(farbe)))
            }
        }
    }

    // MARK: - Ablesen

    private func ablesen(_ groesse: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { griff in
                let breite = spaltenbreite(groesse.width)
                spalte = breite > 0 ? max(0, Int(max(0, griff.location.x) / breite)) : 0
                gezeigt = zelle(an: griff.location, groesse: groesse)
            }
    }

    /// Von einer Stelle auf dem Schirm zu einer Zelle - dieselbe Rechnung wie beim Zeichnen.
    ///
    /// Vorbild ist das Fadenkreuz der Tageskurve (`Diagramme/Tageskurve.swift:382-401`); dort
    /// kommt die Umrechnung aus dem `ChartProxy`, hier muss sie die eigene sein, weil hier auch
    /// die eigene gezeichnet hat. Daneben gegriffen heißt: nichts zeigen, nicht das Nächstbeste.
    private func zelle(an stelle: CGPoint, groesse: CGSize) -> Jahresraster.Zellenhinweis? {
        let breite = spaltenbreite(groesse.width)
        guard breite > 0, stelle.x >= 0, stelle.y >= 0 else { return nil }
        let t = Int(stelle.x / breite)
        let stunde = Int(stelle.y / zellenhoehe)
        guard t < raster.tage.count, stunde < Jahresraster.stundenJeTag else { return nil }
        return raster.hinweis(tag: t, stunde: stunde)
    }

    // MARK: - Das Blättchen

    /// Das Hinweisfenster: drei Zeilen und, wo ein Tippen etwas tut, eine vierte
    /// (`charts.ts:467-483`, `YearMap.tsx:68`).
    ///
    /// **Es bleibt im Bild** (`handy.ts:61`, `confine: true`): ein Blättchen, das am 28. Dezember
    /// über den Rand hinausragt, ist am Rand des Jahres gerade dort unlesbar, wo man hinsieht.
    private func blaettchen(_ h: Jahresraster.Zellenhinweis, in groesse: CGSize) -> some View {
        let ziel = Wiedergabeziel(tag: h.tag, stunde: h.stundenzahl)
        return VStack(alignment: .leading, spacing: 2) {
            Text(h.datum).font(Schrift.achse).foregroundStyle(Farbe.text2)
            Text(h.stunde).font(Schrift.achse).foregroundStyle(Farbe.text1)
            Text(h.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
            if ziel != nil, aufZelle != nil {
                Text(Jahresraster.klickhinweis)
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                    .padding(.top, 2)
            }
        }
        .padding(8)
        .frame(width: blattbreite, alignment: .leading)
        .background(Farbe.flaeche3)
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                .strokeBorder(Farbe.linie2, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
        .offset(x: blattX(in: groesse), y: blattY(h))
        .onTapGesture {
            guard let ziel, let aufZelle else { return }
            gezeigt = nil
            aufZelle(ziel)
        }
    }

    private var blattbreite: CGFloat { 184 }
    private var blatthoehe: CGFloat { aufZelle == nil ? 68 : 86 }

    private func blattX(in groesse: CGSize) -> CGFloat {
        let gewuenscht = CGFloat(spalte) * spaltenbreite(groesse.width) + 10
        return min(max(0, groesse.width - blattbreite), max(0, gewuenscht))
    }

    private func blattY(_ h: Jahresraster.Zellenhinweis) -> CGFloat {
        let gewuenscht = CGFloat(h.stundenzahl) * zellenhoehe + zellenhoehe
        return min(max(0, rasterhoehe - blatthoehe), max(0, gewuenscht))
    }

    // MARK: - Die Stundenachse

    /// Die Stunden links, jede sechste beschriftet (`charts.ts:515`, `interval i % 6`).
    ///
    /// Vierundzwanzig Zeilen mit vier Wörtern darin: die leeren Zeilen tragen die Höhe, damit
    /// „06:00“ neben seiner Zeile steht und nicht daneben.
    private var stundenachse: some View {
        VStack(spacing: 0) {
            ForEach(0..<Jahresraster.stundenJeTag, id: \.self) { stunde in
                Text(Jahresraster.stundeBeschriftet(stunde) ? stundenwort(stunde) : "")
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                    .frame(width: achsenbreite, height: zellenhoehe, alignment: .trailing)
            }
        }
        .frame(height: rasterhoehe, alignment: .top)
    }

    /// An der Wand „06:00“, am Telefon „06“.
    private func stundenwort(_ stunde: Int) -> String {
        schmal ? String(format: "%02d", stunde) : String(format: "%02d:00", stunde)
    }

    // MARK: - Die Monatsachse

    /// Die Monate unter der Fläche, nur an ihren Anfängen (`charts.ts:504-506`).
    ///
    /// Gezeichnet statt gestapelt, weil die Beschriftung über der Spalte ihres Monatsanfangs
    /// stehen muss - und die kennt nur die Breite, also dieselbe Rechnung wie das Raster darüber.
    private var monatsachse: some View {
        Canvas { gestalt, groesse in
            let breite = spaltenbreite(groesse.width)
            for marke in raster.monatsanfaenge {
                let x = CGFloat(marke.spalte) * breite
                let wort = Text(marke.name)
                    .font(Schrift.achse)
                    .foregroundStyle(Farbe.text3)
                gestalt.draw(wort, at: CGPoint(x: x + 1, y: groesse.height / 2), anchor: .leading)
            }
        }
        .frame(height: 12)
    }

    // MARK: - Das Skalenband

    /// Die Skala: ein waagerechtes Band rechts über der Fläche, mit Zahlen und Einheit
    /// (`charts.ts:517-537`).
    ///
    /// **Waagerecht** (`charts.ts:522`, `orient: "horizontal"`): die Zeile steht dort
    /// unbedingt - eine Zeile darunter gilt nur für die kompakte Fassung, und ihre drei Werte
    /// werden von den Literalen daneben (`:526-529`) ohnehin wieder überschrieben. Dieselbe
    /// Stelle liest die Abdeckungskarte ebenso (`Diagramme/Abdeckungskarte.swift:174-196`).
    ///
    /// **Rechts und nicht unten** (`charts.ts:524-525`): unten drängen sich sonst
    /// Monatsbeschriftung und Skala, und die Karte selbst verliert die Höhe, die sie zum Lesen
    /// braucht.
    ///
    /// **Bei der Netzbilanz tragen die Pole ihre Worte** (`charts.ts:530-532`): die Bedeutung
    /// darf nicht allein in der Farbe stehen. Links die Einspeisung, rechts der Bezug - links
    /// liegt das Minimum, und Einspeisung ist die negative Zahl. Die Zahlen bleiben daneben
    /// stehen - im Browser zeigt sie dort der Griff, den man schieben kann, und den gibt es
    /// hier nicht.
    private var skalenband: some View {
        HStack(spacing: 5) {
            Spacer(minLength: 0)
            if let pole = raster.pole {
                Text(pole.links).font(Schrift.achse).foregroundStyle(Farbe.text2)
            }
            skalenwort(raster.skalaLinks)
            LinearGradient(
                colors: raster.kennzahl.rampe.map { Color($0) },
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: bandbreite, height: 6)
            .clipShape(Capsule())
            skalenwort(raster.skalaRechts)
            if let pole = raster.pole {
                Text(pole.rechts).font(Schrift.achse).foregroundStyle(Farbe.text2)
            }
        }
    }

    private func skalenwort(_ wort: String) -> some View {
        Text(wort)
            .font(Schrift.achse)
            .foregroundStyle(Farbe.text3)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
