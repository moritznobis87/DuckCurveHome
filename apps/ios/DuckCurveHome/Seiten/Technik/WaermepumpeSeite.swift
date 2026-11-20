import DuckCurveKit
import SwiftUI

/// Wärmepumpe · Jetzt: was die Maschine in diesem Augenblick tut, in der Ordnung der Vorlage
/// (`apps/web/src/components/waermepumpe/Waermepumpe.tsx`).
///
/// **Vier Zahlen oben, die Zeichnung darunter** - und das war hier bis zum 20.11.2026
/// umgekehrt. Die App begründete die eigene Reihenfolge damit, dass die Zeichnung den Zahlen
/// „einen Ort gibt“; die Vorlage begründet ihre damit, dass die vier Zahlen beantworten, was
/// man von einer Wärmepumpe wissen will (`Waermepumpe.tsx:23-25`). Beides ist wahr, und
/// entschieden ist es für die Vorlage: wer diese Seite öffnet, will zuerst wissen, ob sie
/// gerade gut arbeitet - wie viel Wärme aus wie viel Strom, mit welcher Arbeitszahl, bei
/// welcher Spreizung. Wo die einzelne Zahl *entsteht*, ist die Frage danach, und darauf
/// antwortet die Zeichnung.
///
/// **Die drei Listenkarten sind weggefallen** (Kältekreis, Wasserseite, Regler und Kontakte -
/// neunzehn Zeilen). Sie hatten ihren Grund, solange der Kopf nur einen Satz in 13 Punkten
/// trug: dann stand jede Zahl nur dort. Jetzt steht jede von ihnen an einer zweiten Stelle -
/// die Temperaturen und der Durchfluss an ihrem Gerät in der Zeichnung, Heizanforderung,
/// Raum-Sollwert, Ventil, Heizstab und Verdichterstrom in der Standzeile, die Spreizung als
/// Kachel, die Zusatzleistung als eigener Absatz. Dieselbe Zahl zweimal auf einer Seite ist
/// nicht doppelt so deutlich, sondern lässt offen, welche der beiden die gemeinte ist.
///
/// **Was sie dabei wirklich verliert**, steht hier, damit es nicht übersehen wird: den
/// Güte-Hinweis an jedem einzelnen Pufferfühler („alt · vor 4 min“) und einen fünften oder
/// sechsten Pufferfühler, falls die Anlage einmal mehr als vier meldet. Die Vorlage zeigt
/// beides auch nicht (ihr Glas hat vier Höhen, `puffer/glas.ts:21`); das Glas der Zeichnung
/// wird blass, wenn ein Fühler nicht trägt, und sagt es damit, ohne eine Liste dafür zu
/// brauchen.
///
/// **Gerechnet wird im Kern** (``Wpseite``): die Standzeile, die vier Kennzahlen mit ihren
/// Tönen, die zwölf Spalten der Reglertabelle, die Sätze, die wörtlich dastehen müssen, und
/// die fünf Verweise. Hier bleiben die Maße, die Reihenfolge und die zwei Takte.
struct WaermepumpeSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Wegweiser.self) private var wegweiser

    @Environment(\.horizontalSizeClass) private var breite
    @Environment(\.verticalSizeClass) private var hoehe
    @Environment(\.scenePhase) private var phase

    @State private var wp: WaermepumpeOut?
    @State private var fehler: ApiFehler?
    @State private var kennzahlen: ReglerKennzahlenOut?

    var body: some View {
        Seite {
            if let w = wp {
                kopfteil(w)
                mitteteil(w)
                fussteil(w)
            } else if let fehler {
                Stoerung(fehler: fehler) { Task { await lade() } }
            } else {
                // **Ein Absatz und keine Karte** (`Waermepumpe.tsx:60-62`): solange nichts da
                // ist, gibt es nichts zu umrahmen.
                Text("Die Wärmepumpe wird geladen …")
                    .font(Schrift.text)
                    .foregroundStyle(Farbe.text3)
            }
        }
        .task { await lade() }
        .task { await haltFrisch() }
        .task { await holeKennzahlen() }
        // **Zurück aus dem Hintergrund wird einmal nachgeholt** (`Waermepumpe.tsx:50-56`).
        // Der Takt unten schläft, solange die Seite nicht vorn ist; ohne diesen Griff stünde
        // nach dem Aufwecken bis zu zehn Sekunden ein Stand von vorhin da, und zwar ohne es
        // zu sagen.
        .onChange(of: phase) { _, neu in
            if neu == .active { Task { await lade() } }
        }
    }

    // MARK: - Die Seite in drei Teilen

    /// **In drei Teilen, weil ein `ViewBuilder` zehn Kinder nimmt** - und weil ein einzelner
    /// Ausdruck über die ganze Seite „unable to type-check this expression in reasonable
    /// time“ ergibt, was man erst auf dem Mac sieht.
    @ViewBuilder private func kopfteil(_ w: WaermepumpeOut) -> some View {
        kopf(w)
        if let z = w.zusatzKw {
            hinweisabsatz(fett: Wpseite.zusatzsatzFett(kw: z), rest: Wpseite.zusatzsatzRest)
        }
        if let stumm = w.busStummDe, !stumm.isEmpty {
            hinweisabsatz(fett: Wpseite.busStummVorsatz, rest: stumm)
        }
    }

    @ViewBuilder private func mitteteil(_ w: WaermepumpeOut) -> some View {
        kennzahlenfeld(w)
        buehne(w)
        reglertabelle(w)
    }

    // MARK: - Kopf und Absätze

    /// Der führende Satz und die Standzeile darunter (`Waermepumpe.tsx:66-79`,
    /// `globals.css:788-790`).
    ///
    /// **Ohne Karte und in 19 Punkten.** Hier stand der Satz in 13 Punkten in einer Karte über
    /// der Zeichnung - also in der Schriftgröße einer Bildunterschrift, obwohl er die Antwort
    /// der ganzen Seite ist. Die Vorlage setzt ihn in 22 Punkte an der Wand und 19 am Telefon
    /// (`handy.css:234`); ``Schrift/satz`` ist die Stufe, die das Haus dafür hat.
    private func kopf(_ w: WaermepumpeOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Wpbild.satz(w))
                .font(Schrift.satz)
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            Text(Wpseite.standzeile(w, fehler: fehler?.rat))
                .font(Schrift.klein)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Der amberfarbene Hinweisabsatz mit fettem Vorsatz (`.wp-stumm`, `globals.css:792`).
    ///
    /// **Ein Fluss und nicht zwei Zeilen.** Die Vorlage setzt den ersten Satz in `<strong>`
    /// und den Rest im selben Absatz dahinter (`Waermepumpe.tsx:83`, `:89`); zwei
    /// übereinanderstehende `Text` sähen aus wie Überschrift und Text, und der Vorsatz ist
    /// keine Überschrift, sondern der erste Satz. In SwiftUI ist das ein zusammengesetzter
    /// `Text` - dasselbe Mittel wie im Schild der Zeichnung
    /// (``Waermepumpenbild`` zeichnet Zahl und Einheit so).
    private func hinweisabsatz(fett: String, rest: String) -> some View {
        let vorsatz = Text(fett).font(Schrift.sansHalbfett(14, relativeTo: .footnote))
        let satz = Text(" " + rest).font(Schrift.sans(14))
        return (vorsatz + satz)
            .foregroundStyle(Farbe.text1)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Farbe.amber.opacity(0.09), in: absatzumriss)
            .overlay(absatzumriss.strokeBorder(Farbe.amber.opacity(0.55), lineWidth: 1))
            .accessibilityAddTraits(.isStaticText)
    }

    private var absatzumriss: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    // MARK: - Die vier Kennzahlen

    /// `kpi-grid` mit vier Kacheln (`Waermepumpe.tsx:93-98`).
    ///
    /// **Ohne Kicker, und das ist nicht vergessen.** Das Raster der Vorlage trägt keine
    /// Überschrift, und „Außengerät · Innengerät · Speicher“ - der Kicker dieser Seite
    /// (`page.tsx:9`) - steht in der App schon an der Stelle, an der die Vorlage ihn hat: in
    /// der Reiterzeile, aus ``Bereiche/kicker(fuer:)`` über ``Seite``. Hier stand bisher
    /// `w.zustandDe`; das Zustandswort ist jetzt der Anfang des führenden Satzes und muss
    /// nicht zweimal dastehen.
    ///
    /// `ersteFuehrt` und `art: .bericht` sind die Handyfassung der Vorlage: eine Fläche statt
    /// vier Rahmen, die erste Zahl in 48 Punkten über die ganze Breite, die übrigen
    /// zweispaltig mit Haarlinien (`handy.css:195-207`).
    private func kennzahlenfeld(_ w: WaermepumpeOut) -> some View {
        Kachelfeld(kacheln: Wpseite.kennzahlen(w).map(Kacheldaten.init))
    }

    // MARK: - Die Zeichnung

    /// Die Zeichnung in ihrer Karte, **nach** den Kennzahlen (`Waermepumpe.tsx:100-102`).
    ///
    /// **In der hohen Lage höchstens 420 Punkte breit und mittig** (`globals.css:793-794`).
    /// Ohne diese Grenze wird die hochkante Zeichnung auf einem iPad in einem schmalen
    /// Fenster so breit wie die Karte und damit tausend Punkte hoch - das Seitenverhältnis
    /// ist 380 zu 1000.
    private func buehne(_ w: WaermepumpeOut) -> some View {
        Karte {
            Waermepumpenbild(wp: w, lage: lage)
                .frame(maxWidth: lage == .hoch ? 420 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// Hoch oder breit - nach Breite **und** Höhe.
    ///
    /// **`useIsMobile` fragt beides** (`apps/web/src/lib/useIsMobile.ts:6,15,21`): schmaler als
    /// 720 **oder** niedriger als 560. Hier stand nur `horizontalSizeClass == .compact`, und
    /// damit bekam ein Telefon im Querformat die breite Zeichnung in einen 390 Punkte hohen
    /// Streifen gelegt. ``SwiftUI/EnvironmentValues/verticalSizeClass`` ist das Gegenstück zur
    /// Höhe: `.compact` heißt genau „niedriges Fenster“.
    private var lage: Wpbild.Lage {
        breite == .compact || hoehe == .compact ? .hoch : .breit
    }

    // MARK: - Die Reglertabelle

    /// Was der Regler meldet (`Waermepumpe.tsx:104`, `waermepumpe/Kennzahlen.tsx:1-98`).
    ///
    /// **Diese Karte stand in der App auf der Reglerseite**, mit sieben der dreizehn Spalten,
    /// ohne die beiden Erklärabsätze und ohne die Markierung der laufenden Kennzahl. Die
    /// Vorlage zeigt sie nur hier (in `Regler.tsx` kommt `Kennzahlen` nicht vor), und sie
    /// gehört auch hier hin: sie ist die Gegenprobe zu dem, was der Kopf dieser Seite über
    /// den Augenblick sagt - was hat die Maschine unter dieser Kennzahl in sieben Tagen
    /// wirklich getan.
    ///
    /// **Die Überschrift ist ein Satz und darum ein Titel ohne Kicker.** `.kl-titel` ist eine
    /// einzige Zeile in 15 Punkten halbfett (`globals.css:901`), und „Was der Regler meldet,
    /// letzte 7 Tage“ zerfällt nicht in Sache und Einordnung: die sieben Tage sind die Sache.
    ///
    /// **Am Telefon rollt sie seitlich und bleibt eine Tabelle.** Zwölf Umschaltpillen wären
    /// selbst eine rollende Leiste, und jeder Blick auf eine Spalte würfe die vorige weg -
    /// dafür hat das Gerippe ``Tabelle/Handyfassung/rollt`` (`globals.css:912-913`,
    /// `handy.css:246-247`).
    @ViewBuilder private func reglertabelle(_ w: WaermepumpeOut) -> some View {
        if let k = kennzahlen, !k.zeilen.isEmpty {
            Karte(titel: Wpseite.tabellentitel(tage: k.tage)) {
                VStack(alignment: .leading, spacing: 10) {
                    kleingedruckt(Wpseite.einleitung)
                    Tabelle(
                        zeilennamen: k.zeilen.map { Wpseite.zeilenname($0, aktuell: w.kreisCode) },
                        spalten: tabellenspalten(k.zeilen, aktuell: w.kreisCode),
                        handyfassung: .rollt
                    )
                    kleingedruckt(Wpseite.nachsatz)
                }
            }
        }
    }

    /// Die Spalten der Tabelle, und die laufende Kennzahl in Amber (`globals.css:911`).
    ///
    /// **Die Zeilenbeschriftung bleibt dabei in der Textfarbe**, anders als in der Vorlage,
    /// die `tr[data-aktuell="true"] td` einfärbt - also die ganze Zeile einschließlich der
    /// Kennzahl. ``Tabelle`` färbt je Zelle und nicht je Zeile, und die erste Spalte ist dort
    /// die Zeilenbeschriftung. Die Markierung geht darum nicht verloren: sie steht als „ · jetzt“
    /// im Namen selbst (``Wpseite/zeilenname(_:aktuell:)``), wie die Vorlage sie auch schreibt.
    private func tabellenspalten(
        _ zeilen: [ReglerKennzahlOut], aktuell: Int?
    ) -> [Tabelle.Spalte] {
        let farben: [Color?] = zeilen.map {
            Wpseite.istAktuell($0, aktuell: aktuell) ? Farbe.amber : nil
        }
        return Wpseite.spalten(zeilen).map { spalte in
            Tabelle.Spalte(name: spalte.name, zellen: spalte.zellen, farben: farben)
        }
    }

    /// Die kleinen Absätze über und unter der Tabelle (`.kl-klein`, `globals.css:898`).
    private func kleingedruckt(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text3)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 760, alignment: .leading)
    }

    // MARK: - Der Fuß

    /// Der Fuß (`Waermepumpe.tsx:106-119`, `globals.css:795-798`).
    ///
    /// **Offen und nicht zugeklappt.** Die Hinweise des Busses standen hier in einer
    /// ``Methode``, also hinter einem Griff - und mit ihnen die beiden Sätze, die erklären,
    /// was „Fühler WP“ ist und warum Ventil und Heizstab als Zahl dastehen. Diese Sätze sind
    /// keine Methodenangabe; sie sind die Lesehilfe für die Zeichnung und die Standzeile
    /// darüber, und zugeklappt kommen sie bei dem nicht an, der sie braucht.
    private func fussteil(_ w: WaermepumpeOut) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fusssatz(Wpseite.fussFuehler)
            if Wpseite.ventilsatzNoetig(w) {
                fusssatz(Wpseite.fussVentilUndHeizstab)
            }
            ForEach(w.hinweiseDe, id: \.self) { h in
                fusssatz(h)
            }
            verweise
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private func fusssatz(_ satz: String) -> some View {
        Text(satz)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text3)
            .lineSpacing(3.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Die fünf Verweise (`.wp-links`, `globals.css:796`: umbrechend, Abstand 6 und 18).
    ///
    /// Sie brechen um und stehen nicht untereinander: fünf Wörter mit Pfeil sind an der Wand
    /// eine Zeile und am Telefon drei, und fünf einzelne Zeilen wären dort ein zweiter Fuß
    /// unter dem Fuß.
    private var verweise: some View {
        Umbruchzeile(abstand: 18, zeilenabstand: 6) {
            ForEach(Wpseite.fussverweise) { v in
                Button(v.wort) { wegweiser.gehe(v.weg) }
                    .font(Schrift.klein)
                    .buttonStyle(.plain)
                    .foregroundStyle(Farbe.amber)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Holen und frisch halten

    private func lade() async {
        do {
            wp = try await haus.api.waermepumpe()
            fehler = nil
        } catch let f as ApiFehler {
            fehler = f
        } catch {
            fehler = .netz(error.localizedDescription)
        }
    }

    /// **Alle zehn Sekunden, aber nur solange die Seite vorn ist** (`Waermepumpe.tsx:47-49`).
    ///
    /// Hier lief der Takt stumpf weiter; eine Seite im Hintergrund fragte den Bus sechs Mal
    /// in der Minute nach Werten, die niemand ansah. Der Fehler eines Nachladens ersetzt den
    /// Stand nicht: er wandert in die Standzeile, und das Bild von vorhin bleibt stehen
    /// (`Waermepumpe.tsx:77`).
    private func haltFrisch() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Wpseite.takt))
            guard !Task.isCancelled else { return }
            guard phase == .active else { continue }
            do {
                wp = try await haus.api.waermepumpe()
                fehler = nil
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
        }
    }

    /// **Ein eigener Takt von fünf Minuten** (`Kennzahlen.tsx:34-35`): der Dienst hält die
    /// Auszählung über sieben Tage so lange, und öfter zu fragen bringt dieselbe Antwort zum
    /// Preis einer Auswertung über eine Woche. Scheitert der Abruf, bleibt die Karte weg oder
    /// stehen - sie ist Beiwerk zum Augenblick und keine Störung der Seite.
    private func holeKennzahlen() async {
        while !Task.isCancelled {
            if phase == .active,
                let k = try? await haus.api.reglerKennzahlen(tage: Wpseite.kennzahlenTage)
            {
                kennzahlen = k
            }
            try? await Task.sleep(for: .seconds(Wpseite.kennzahlenTakt))
        }
    }
}
