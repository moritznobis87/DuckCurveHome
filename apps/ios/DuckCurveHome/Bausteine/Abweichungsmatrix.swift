import DuckCurveKit
import SwiftUI

/// Die Abweichung je Raum und Viertelstunde – die Hauptkarte der Heizkreise.
///
/// **Warum sie wichtiger ist als die Temperaturkurven.** Zehn Räume zwischen 18 und 21 °C
/// ergeben als Kurven ein flaches Band, in dem nichts zu erkennen ist. Interessant ist nicht,
/// wie warm ein Raum ist, sondern wie weit er von *seinem* Ziel weg ist – und welcher Raum
/// zuerst abfällt, denn der bestimmt die nötige Vorlauftemperatur für alle. Diese Karte
/// stand im Dashboard (`rooms/RoomsReport.tsx`) und fehlte in der App.
///
/// **Drei Arten von Feld, und das ist der Kern der Sache.** Ein gemessener Wert bekommt eine
/// Farbe aus der fünfstufigen Skala. Ein Fenster ohne Messwert wird schraffiert – nicht grau,
/// denn Grau wäre eine sechste Stufe derselben Skala und würde als Messung gelesen. Ein
/// Fenster, das noch nicht an der Reihe war, bekommt einen eigenen, sehr blassen Ton: sonst
/// wäre der halbe Tag schraffiert und die paar Felder, auf die es ankommt, verschwänden darin.
///
/// **Und die Zahl selbst.** Die Vorlage hängt an jedes der bis zu sechsundneunzig Felder je
/// Raum einen `title` aus Raum, Uhrzeit und Abweichung (`RoomsReport.tsx:490`) – das ist die
/// einzige Stelle der Karte, an der eine Zahl zu lesen ist, denn die Fläche gibt nur fünf
/// Stufen her. Am Gerät gibt es kein Überfahren; hier liest ein Ziehen über die Zeile ab, wie
/// in der Jahresfläche (`Diagramme/Jahresflaeche.swift:126-145`). **Das Blättchen geht beim
/// Loslassen wieder weg** – anders als dort, wo ein Tippen darauf weiterführt und es deshalb
/// stehen bleiben muss. Hier führt nichts weiter, und ein Blättchen, das ohne Grund stehen
/// bleibt, verdeckt die Zeile, die man gerade gelesen hat.
///
/// Die Rechnung dahinter steht im Kern (`Raumabweichung`) und ist dort geprüft – auch die
/// Grenzen der Skala, die hier einmal zu eng waren, und die Worte des Blättchens
/// (`Zustand/Raumfeld.swift`).
struct Abweichungsmatrix: View {
    let verlauf: RoomHistoryOut
    /// Das erste Fenster, das noch nicht gewesen ist.
    let bisStelle: Int?

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    /// Was gerade abgelesen wird, und wohin das Blättchen dazu gehört.
    @State private var gezeigt: Raumabweichung.Feldhinweis?
    /// Die Ecke des Blättchens, schon in die Fläche hineingerechnet – gemerkt und nicht
    /// nachgesucht: bei jedem Bildwechsel neu zu rechnen, wo der Finger stand, hieße die
    /// Zeilenbreite ein zweites Mal zu kennen.
    @State private var blattecke: CGPoint = .zero

    /// Die Zelle ist 20 Punkte hoch, die Zeile drei darüber (`RoomsReport.tsx:486`,
    /// `gap-[3px]`).
    private let zellenhoehe: CGFloat = 20
    private let zeilenabstand: CGFloat = 3
    /// Der Abstand zwischen Name, Band und Mittel (`RoomsReport.tsx:487`, `gap-2.5`).
    private let spaltenabstand: CGFloat = 8
    private var namensbreite: CGFloat { schmal ? 76 : 128 }
    private let mittelbreite: CGFloat = 62
    /// Zwei Punkte zwischen zwei Viertelstunden, am Telefon einer.
    ///
    /// **Das ist der Unterschied zwischen einem Raster und einem Balken.** Die Felder standen
    /// hier ohne Lücke aneinander und überlappten sich sogar um einen halben Punkt - aus
    /// sechsundneunzig Viertelstunden wurde ein durchgehender Streifen, und man konnte nicht
    /// mehr sehen, dass jede Zelle eine eigene Messung ist.
    private var luecke: CGFloat { schmal ? 1 : 2 }

    /// **Das Blättchen liegt als Auflage über dem Zeilenstapel und nicht neben ihm.** Als
    /// zweites Kind eines `ZStack` war es an der Größe beteiligt: bei einem Raum ist der Stapel
    /// 37 Punkte hoch, das Blättchen 62 - die Karte sprang beim Ziehen in der Höhe auf und ab.
    /// Dasselbe tut die Jahresfläche, dort indem der `ZStack` samt Blättchen im
    /// `GeometryReader` mit fester Höhe liegt (`Diagramme/Jahresflaeche.swift:76-87`); eine
    /// Auflage nimmt hier ihre Höhe aus den Zeilen, ohne dass die Höhe noch einmal
    /// aufgeschrieben werden müsste. In der Vorlage steht der `title` am Zeiger und nimmt im
    /// Fluss ohnehin keinen Platz (`RoomsReport.tsx:490`).
    var body: some View {
        VStack(alignment: .leading, spacing: zeilenabstand) {
            ForEach(Array(verlauf.rooms.enumerated()), id: \.offset) { nummer, raum in
                zeile(raum, nummer: nummer)
            }
            achse
        }
        .overlay(alignment: .topLeading) {
            if let gezeigt {
                blaettchen(gezeigt)
            }
        }
    }

    private func felder(_ raum: RoomSeriesOut) -> [Raumabweichung.Feld] {
        Raumabweichung.felder(
            ist: raum.tempC, soll: raum.setpointC, versatz: raum.offsetK, bisStelle: bisStelle
        )
    }

    private func zeile(_ raum: RoomSeriesOut, nummer: Int) -> some View {
        let f = felder(raum)
        let m = Raumabweichung.mittel(f)
        return HStack(spacing: spaltenabstand) {
            // **Rechtsbündig an das Band gesetzt** (`RoomsReport.tsx:489`): die Namen sind
            // verschieden lang, und links gesetzt beginnt jedes Band woanders.
            Text(raum.name)
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: namensbreite, alignment: .trailing)
            GeometryReader { flaeche in
                Canvas { gestalt, groesse in
                    male(f, in: &gestalt, groesse: groesse)
                }
                .contentShape(Rectangle())
                .gesture(ablesen(name: raum.name, felder: f, nummer: nummer, in: flaeche.size))
            }
            .frame(height: zellenhoehe)
            // Die Einheit gehört dazu: „+1,4“ ist eine Zahl, „+1,4 K“ ist eine Abweichung.
            //
            // **Immer leise** (`RoomsReport.tsx:495`, dort durchgehend `text-3`). Hier hob sich
            // die Zahl auf `text1`, sobald eine dastand - dann wiegt die Nebenzahl am Rand so
            // schwer wie die Namen, und das Band dazwischen ist die Sache.
            Text(m.map(Raumabweichung.kelvin) ?? Formate.leer)
                .font(Schrift.zahlKlein)
                .foregroundStyle(Farbe.text3)
                .frame(width: mittelbreite, alignment: .trailing)
        }
        // Die Vorlage hat ihre Zahl im `title` jedes Feldes; eine Vorlesehilfe liest keine
        // sechsundneunzig Felder vor und hat keinen Finger. Also die Zeile in einem Satz.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Raumabweichung.matrixzeilenwort(name: raum.name, felder: f))
    }

    // MARK: - Zeichnen

    /// Die Breite eines Feldes – **eine Rechnung, zwei Verwendungen**: so zeichnet ``male``,
    /// und so rechnet ``feldstelle`` vom Finger zurück auf das Feld.
    private func feldbreite(anzahl: Int, in gesamt: CGFloat) -> CGFloat {
        let n = CGFloat(max(1, anzahl))
        return max(1, (gesamt - (n - 1) * luecke) / n)
    }

    private func male(
        _ felder: [Raumabweichung.Feld], in g: inout GraphicsContext, groesse: CGSize
    ) {
        guard !felder.isEmpty else { return }
        let breite = feldbreite(anzahl: felder.count, in: groesse.width)
        for (i, f) in felder.enumerated() {
            let kasten = CGRect(x: CGFloat(i) * (breite + luecke), y: 0,
                                width: breite, height: groesse.height)
            let form = Path(roundedRect: kasten, cornerRadius: 2)
            switch f {
            case .wert(let k):
                g.fill(form, with: .color(Color(Marken.abweichungsfarbe(kelvin: k))))
            case .nochNicht:
                g.fill(form, with: .color(.white.opacity(0.035)))
            case .keinWert:
                schraffiere(form, kasten: kasten, in: g)
            }
        }
    }

    /// Ein Fenster ohne Messwert: Schraffur statt Grau – sie gehört sichtbar nicht zur Skala,
    /// und genau das ist die Aussage.
    ///
    /// **Ohne Grundfüllung** (`palette.ts:29-30`: Striche auf `transparent`). Hier lag eine
    /// Fläche in `white 0.04` darunter und die Striche standen auf `white 0.18` – nebeneinander
    /// gelesen war die Lücke dann ein eigener, sechster Ton der Skala und nicht „gehört nicht
    /// dazu“. Striche also auf `white 0.10`, wie in der Vorlage.
    ///
    /// **Die Beschneidung bekommt eine eigene Abschrift des Zeichenstandes.** `clip(to:)`
    /// gilt von da an für alles Weitere: auf dem geteilten Stand beschnitt das erste
    /// schraffierte Feld einer Zeile alle folgenden weg, und eine Zeile mit einer Lücke in der
    /// Frühe verlor ihren ganzen Tag. `GraphicsContext` ist ein Wert – eine Abschrift je Feld
    /// kostet nichts und hält den Schnitt bei dem Feld, zu dem er gehört.
    private func schraffiere(_ form: Path, kasten: CGRect, in g: GraphicsContext) {
        var lage = g
        lage.clip(to: form)
        var schraffur = Path()
        var x = kasten.minX - kasten.height
        while x < kasten.maxX + kasten.height {
            schraffur.move(to: CGPoint(x: x, y: kasten.maxY))
            schraffur.addLine(to: CGPoint(x: x + kasten.height, y: kasten.minY))
            x += strichschritt
        }
        lage.stroke(schraffur, with: .color(.white.opacity(0.10)), lineWidth: strichbreite)
    }

    /// Drei Punkte Strich (`palette.ts:29-30`: `0 3px`).
    private let strichbreite: CGFloat = 3
    /// Der Schritt in der Waagerechten.
    ///
    /// Die Vorlage misst Strich und Lücke **senkrecht zu ihren Strichen** – so rechnet ein
    /// `repeating-linear-gradient`: drei Punkte Strich, drei Punkte Lücke, also sechs Punkte
    /// Abstand quer. Bei fünfundvierzig Grad ist der waagerechte Schritt um die Wurzel aus zwei
    /// größer.
    private var strichschritt: CGFloat { 2 * strichbreite * 1.414_213_562_373_095 }

    // MARK: - Ablesen

    /// Ziehen liest ab, Loslassen nimmt das Blättchen weg.
    ///
    /// **`minimumDistance: 0` und nichts Senkrechtes.** Die Karte steht in einer rollenden
    /// Seite; ein Griff, der erst nach einigen Punkten anspricht, wäre am Telefon derselbe,
    /// mit dem gerollt wird – und eine Gestik mit senkrechtem Anteil nähme dem Rollen die
    /// Bewegung. Dieselbe Abwägung steht in der Jahresfläche (`Jahresflaeche.swift:17-20`).
    private func ablesen(
        name: String, felder: [Raumabweichung.Feld], nummer: Int, in groesse: CGSize
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { griff in
                guard
                    let i = feldstelle(
                        griff.location.x, anzahl: felder.count, in: groesse.width)
                else {
                    gezeigt = nil
                    return
                }
                blattecke = blattstelle(
                    feld: i, zeile: nummer, anzahl: felder.count, in: groesse.width)
                gezeigt = Raumabweichung.feldhinweis(
                    name: name, zeitIso: zeitstempel(i), feld: felder[i])
            }
            .onEnded { _ in gezeigt = nil }
    }

    /// Von einer Stelle auf dem Schirm zum Feld – dieselbe Rechnung wie beim Zeichnen.
    ///
    /// **Die Lücke hinter einem Feld gehört zu ihm.** Bei sechsundneunzig Feldern auf
    /// Telefonbreite ist ein Feld rund anderthalb Punkte breit; wer nur den Strich selbst
    /// treffen darf, trifft nichts. Also zählt das Fach aus Feld und folgender Lücke – aber
    /// nur dieses: links daneben oder hinter dem letzten Feld steht nichts, nicht das
    /// Nächstbeste (`Jahresflaeche.swift:139-145`).
    private func feldstelle(_ x: CGFloat, anzahl: Int, in gesamt: CGFloat) -> Int? {
        guard anzahl > 0, x >= 0 else { return nil }
        let fach = feldbreite(anzahl: anzahl, in: gesamt) + luecke
        guard fach > 0 else { return nil }
        let i = Int(x / fach)
        return i < anzahl ? i : nil
    }

    /// Der Zeitstempel eines Feldes – aus der Reihe, nicht aus dem Feld.
    ///
    /// Die Nebenreihen dürfen kürzer sein als die Temperaturreihe; dann steht im Blättchen ein
    /// Strich statt einer Uhrzeit.
    private func zeitstempel(_ i: Int) -> String? {
        i < verlauf.ts.count ? verlauf.ts[i] : nil
    }

    // MARK: - Das Blättchen

    /// Wo das Blättchen hingehört: unter das abgelesene Feld, und **im Bild gehalten**
    /// (`handy.ts:61`, `confine: true`). Ein Blättchen, das am Rand hinausragt, ist gerade
    /// dort unlesbar, wo man hinsieht.
    private func blattstelle(feld: Int, zeile: Int, anzahl: Int, in gesamt: CGFloat) -> CGPoint {
        let fach = feldbreite(anzahl: anzahl, in: gesamt) + luecke
        let x = namensbreite + spaltenabstand + CGFloat(feld) * fach
        let y = CGFloat(zeile) * (zellenhoehe + zeilenabstand) + zellenhoehe + 2
        return CGPoint(
            x: min(max(0, gesamtbreite(bandbreite: gesamt) - blattbreite), max(0, x)),
            y: blattkante(y))
    }

    /// Senkrecht im Bild gehalten – **aber nur, wenn die Fläche dafür hoch genug ist**.
    ///
    /// Bei einem oder zwei Räumen ist der Zeilenstapel niedriger als das Blättchen (37 bzw. 60
    /// gegen 62 Punkte). Eine Begrenzung auf `gesamthoehe - blatthoehe` fiel dann auf null und
    /// legte das Blatt genau auf die Zeile, die es ablesen soll. Dann lieber unter die letzte
    /// Zeile hinausragen als über die gelesene liegen: hinausragen kostet nichts, seit das
    /// Blättchen eine Auflage ist und an der Höhe nicht mehr beteiligt.
    private func blattkante(_ y: CGFloat) -> CGFloat {
        let unterkante = gesamthoehe - blatthoehe
        guard unterkante > 0 else { return max(0, y) }
        return min(unterkante, max(0, y))
    }

    private func gesamtbreite(bandbreite: CGFloat) -> CGFloat {
        namensbreite + spaltenabstand + bandbreite + spaltenabstand + mittelbreite
    }

    /// Die Höhe der Fläche: die Zeilen und die Achse darunter. Die Achse ist eine Zeile in
    /// ``Schrift/achse`` – vierzehn Punkte, hier als Maß und nicht als Messung, denn gemessen
    /// würde sie erst, wenn sie schon steht.
    private var gesamthoehe: CGFloat {
        CGFloat(verlauf.rooms.count) * (zellenhoehe + zeilenabstand) + 14
    }

    private var blattbreite: CGFloat { 150 }
    /// Drei Zeilen und das Polster darum.
    private var blatthoehe: CGFloat { 62 }

    /// Drei Zeilen: Raum, Uhrzeit, Abweichung (`RoomsReport.tsx:490`), in der Gestalt des
    /// Blättchens der Jahresfläche (`Jahresflaeche.swift:155` ff.).
    ///
    /// **Es fängt kein Tippen ab** (`allowsHitTesting(false)`). Es liegt mitten in der Fläche,
    /// über der gerade gezogen wird; nähme es die Bewegung an, risse das Ablesen genau dort ab,
    /// wo das Blättchen erscheint. Weiterführen tut es ohnehin nichts.
    private func blaettchen(_ h: Raumabweichung.Feldhinweis) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(h.raum)
                .font(Schrift.achse)
                .foregroundStyle(Farbe.text2)
                .lineLimit(1)
            Text(h.zeit).font(Schrift.achse).foregroundStyle(Farbe.text1)
            Text(h.wert).font(Schrift.zahlKlein).foregroundStyle(Farbe.text1)
        }
        .padding(8)
        .frame(width: blattbreite, alignment: .leading)
        .background(Farbe.flaeche3)
        .overlay(
            RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous)
                .strokeBorder(Farbe.linie2, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Marken.radius2, style: .continuous))
        .offset(x: blattecke.x, y: blattecke.y)
        .allowsHitTesting(false)
    }

    // MARK: - Die Achse

    private var achse: some View {
        HStack(spacing: spaltenabstand) {
            Spacer().frame(width: namensbreite)
            HStack {
                ForEach([0, 6, 12, 18], id: \.self) { stunde in
                    Text(stundenwort(stunde))
                        .font(Schrift.achse).foregroundStyle(Farbe.text3)
                    if stunde != 18 { Spacer() }
                }
                Spacer()
                Text(stundenwort(24)).font(Schrift.achse).foregroundStyle(Farbe.text3)
            }
            Text("Mittel")
                .font(Schrift.achse).foregroundStyle(Farbe.text3)
                .frame(width: mittelbreite, alignment: .trailing)
        }
    }

    /// An der Wand „06:00“, am Telefon „06“ (`handy.css:384`).
    private func stundenwort(_ stunde: Int) -> String {
        schmal ? String(format: "%02d", stunde) : String(format: "%02d:00", stunde)
    }

}
