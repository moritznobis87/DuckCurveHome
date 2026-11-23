import DuckCurveKit
import SwiftUI

/// Was dasteht, solange geladen wird: der Satz, und Alfred daneben.
///
/// **Der Anlass, wörtlich** (Nutzer am 21.11.2026): „wenn Daten geladen werden finde ich eine
/// Animation mit der Ente Alfred cooler, als einfach nur ‚Daten werden geladen‘“.
///
/// **Die kleine Schwester des ``Ladebild``.** Dort steht Alfred groß und mittig auf einer leeren
/// Fläche, während die App den Strom öffnet. Hier steht er in einer Karte, neben einem Satz, der
/// vorher allein dastand - dieselbe Ente aus dem Bildkatalog, derselbe amberfarbene Schein,
/// derselbe Takt. Was von beidem gleich ist und was sich unterscheiden muss, steht mit
/// Begründung an ``Ladehinweis`` im Kern; dort stehen auch alle Zahlen. Diese Ansicht zeichnet.
///
/// **Sie tritt an die Stelle von ``Leer``, aber nur im Ladefall.** `Leer` sagt auch „für diesen
/// Zeitraum ist nichts da“ und „nicht abrufbar“, und das sind Befunde: fertig, kein Warten, und
/// eine schaukelnde Ente daneben wäre eine Lüge über einen Vorgang, den es nicht gibt. Darum
/// steht an jeder Aufrufstelle eine Bedingung, und die kommt aus dem Zustand der Abfrage und
/// nicht aus dem Satz.
///
/// **Der Satz ist nicht verhandelbar.** Er steht in demselben Grad und in derselben Farbe wie in
/// `Leer`, und er ist Zeichen für Zeichen der, der dort stand - teils aus der Vorlage belegt.
/// Für VoiceOver ist er das Einzige, was gesprochen wird (``Ladehinweis/vorleser(satz:)``); die
/// Ente ist dort nicht vorhanden, denn ein Bild, das schaukelt, sagt nichts.
struct Ladeente: View {
    /// Der Satz, der dasteht. Derselbe, der ohne diesen Baustein dastünde.
    let satz: String
    /// Wie groß die Ente hier ist - ``Ladehinweis/Stufe/klein`` neben einem Satz in einer
    /// Karte, die noch etwas anderes trägt, ``Ladehinweis/Stufe/gross`` an der Stelle eines
    /// ganzen Diagramms. Welche Stelle welche ist, steht an ``Ladehinweis/Stufe``.
    var stufe: Ladehinweis.Stufe = .klein
    /// Die Farbe des Satzes.
    ///
    /// **Ein Knopf, und es gibt einen Grund dafür.** Die meisten dieser Stellen gingen über
    /// ``Leer``, und dort steht der Satz in ``Farbe/text2``; fünf gingen über einen bloßen
    /// Absatz und stehen in ``Farbe/text3``, und das ist an jeder davon aus der Vorlage belegt
    /// (`Waermepumpe.tsx:60-62`, `Nachbetrachtung.tsx:118`, `Betrieb.tsx:30-33`,
    /// `Kennlinie.tsx:95-97`, `HeatSettings.tsx:158`). Diesen Unterschied beim Einbau der Ente
    /// einzuziehen hieße, aus einer Animation eine Änderung an fünf belegten Stellen zu
    /// machen - und dann wäre nicht mehr zu sehen, was die Ente war und was nicht.
    var farbe: Color = Farbe.text2

    @Environment(\.accessibilityReduceMotion) private var ruhigeBewegung

    /// Die Frist ist um: die Ente geht, der Satz bleibt. Begründet an ``Ladehinweis/frist``.
    @State private var fristVorbei = false

    /// **Mit „Größerer Text“ wächst die Ente mit.** Ein 26 Punkte großer Satz neben einer
    /// Ente, die bei 38 Punkten stehen bleibt, sieht nach einem Fehler aus; und wer die
    /// Schrift vergrößert, tut es, weil er kleine Dinge schlecht sieht - eine kleine Ente
    /// gehört dazu.
    @ScaledMetric(relativeTo: .footnote) private var wuchsFussnote: CGFloat = 1

    /// Dieselbe Sache für die große Stufe, nur auf der anderen Kurve.
    ///
    /// **Zwei Messgrößen und keine umschaltbare.** `@ScaledMetric` nimmt seinen Bezug bei der
    /// Erzeugung und nicht je Bild; die Stufe steht aber erst am Aufruf. Beide hier zu halten
    /// kostet nichts - sie rechnen nur eine Zahl -, und ``wuchs`` nimmt die, die zur Stufe
    /// gehört.
    @ScaledMetric(relativeTo: .body) private var wuchsFliesstext: CGFloat = 1

    /// Der Faktor dieser Stufe: Ente und Satz wachsen auf derselben Kurve.
    ///
    /// **Sonst laufen sie auseinander.** Welche Kurve zu welchem Grad gehört, entscheidet
    /// ``Ladehinweis/Stufe/satzbezug`` im Kern; hier wird daraus der Stil, den SwiftUI kennt.
    /// Hingen Ente und Satz an verschiedenen Stilen, stünde bei „Größerer Text“ ein Satz neben
    /// einer Ente, die anders gewachsen ist als er - und das ist genau der Fehler, den die
    /// mitwachsende Ente verhindern soll.
    private var wuchs: CGFloat {
        switch stufe.satzbezug {
        case .fussnote: return wuchsFussnote
        case .fliesstext: return wuchsFliesstext
        }
    }

    /// Die Textstufe, auf deren Kurve der Satz dieser Stufe wächst.
    private var satzstil: Font.TextStyle {
        switch stufe.satzbezug {
        case .fussnote: return .footnote
        case .fliesstext: return .body
        }
    }

    var body: some View {
        block
            // Dieselbe Luft und dieselbe Ausrichtung wie in ``Leer``: der Ladehinweis soll die
            // Karte nicht anders hoch machen als der Satz, der hier vorher allein stand.
            .frame(maxWidth: .infinity, alignment: stufe.untereinander ? .center : .leading)
            .padding(.vertical, 18)
            // **Ein Element und ein Satz**, wie am ``Ladebild``: Bild und Zeile sind zusammen
            // eine Aussage. Dass die Ente dabei nichts beiträgt, ist der Punkt - sie ist
            // Schmuck für die Augen, und der Satz trägt die Auskunft für alle.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Ladehinweis.vorleser(satz: satz))
            // **Die Frist hängt an einer Schlafpause und nicht an der Uhr.** Eine Geräteuhr,
            // die vom Netz zurückgestellt wird, verlängerte sonst die Frist um genau den
            // Sprung - die Lage, gegen die ``Ladeschirm/aufgabeNach`` gebaut ist und die auf
            // der Wandanzeige nach einem Stromausfall wirklich vorkommt. Die Pause endet mit
            // der Ansicht: wird vorher fertig geladen, ist dieser Auftrag storniert.
            .task {
                try? await Task.sleep(for: .seconds(Ladehinweis.frist))
                withAnimation(.easeInOut(duration: Ladehinweis.abgang)) { fristVorbei = true }
            }
    }

    @ViewBuilder private var block: some View {
        if stufe.untereinander {
            VStack(spacing: CGFloat(stufe.luft)) {
                ente
                zeile.multilineTextAlignment(.center)
            }
        } else {
            HStack(alignment: .center, spacing: CGFloat(stufe.luft)) {
                ente
                zeile
            }
        }
    }

    private var zeile: some View {
        Text(satz)
            // **Grad und Kurve gehören zusammen** (``Ladehinweis/Stufe/satzbezug``): 13 Punkte
            // sind in diesem Haus `Schrift.klein` und 15 sind `Schrift.text`, und die beiden
            // hängen an verschiedenen Stilen. Nur den Grad zu nehmen hieße, denselben Satz bei
            // „Größerer Text“ anders wachsen zu lassen als jeden anderen Satz seiner Größe auf
            // derselben Seite.
            .font(Schrift.sans(CGFloat(stufe.satzgroesse), relativeTo: satzstil))
            .foregroundStyle(farbe)
            // Lange Ladesätze gibt es: der der Nachbetrachtung erklärt in zwei Zeilen, warum es
            // dauert. Abgeschnitten wäre gerade die Begründung weg.
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Alfred, solange die Frist läuft.
    ///
    /// **Die Bewegung kommt aus der Uhr und nicht aus einer Dauerschleife.** Eine
    /// `repeatForever`-Animation fängt bei jedem Erscheinen von vorn an; vier Karten, die auf
    /// `/system/daten` nebeneinander laden und einzeln fertig werden, hätten damit vier Enten
    /// in vier Phasen. ``Ladehinweis/zeiger(jetzt:)`` hängt allein am Zeitpunkt, und damit
    /// stehen alle Enten einer Seite im selben Schritt, auch die, die später dazukommt.
    @ViewBuilder private var ente: some View {
        if !fristVorbei {
            TimelineView(
                .animation(minimumInterval: Ladehinweis.bildtakt, paused: ruhigeBewegung)
            ) { lauf in
                let hub = ruhigeBewegung
                    ? Ladehinweis.ruhigerHub : Ladehinweis.hub(jetzt: lauf.date)
                bild(hub: hub)
            }
            .transition(.opacity)
        }
    }

    /// Die Ente an ihrem Platz im Takt, mit dem Schein dahinter.
    private func bild(hub: Double) -> some View {
        let kante = CGFloat(stufe.kante) * wuchs
        let weite = CGFloat(stufe.hubweite) * wuchs
        return Image("Ente")
            .resizable()
            .scaledToFit()
            .frame(width: kante, height: kante)
            // Null ist unten, Eins ist oben - also nach oben, und das heißt in dieser
            // Koordinatenwelt: negativ.
            .offset(y: (0.5 - hub) * weite)
            // **Der Schein bleibt stehen, die Ente fährt.** Er liegt hinter dem *Platz* der
            // Ente und nicht hinter ihr: `offset` verschiebt nur das Gezeichnete, und ein
            // Hintergrund danach sitzt weiter auf dem alten Rahmen. Das ist auch die Sache -
            // das Licht ist der Ort, die Ente bewegt sich darin.
            .background(schein(hub: hub))
            // **Keine weiße Kachel darunter**, anders als am ``Ladebild`` und am
            // ``Entenknopf``. Eine weiße Scheibe mit einer Ente darin *ist* der Entenknopf, und
            // der ist ein Knopf - ein Ladehinweis, der so aussieht, lädt zum Tippen ein und tut
            // dann nichts.
            //
            // Der Platz ist um den ganzen Weg höher als die Ente, damit die Karte beim
            // Schaukeln nicht atmet.
            .frame(width: kante, height: kante + weite)
            // Für VoiceOver ist das Bild nicht da; was es zu sagen gäbe, sagt der Satz.
            .accessibilityHidden(true)
    }

    /// Der weiche Schein, der mit der Ente atmet.
    ///
    /// Dieselben drei Stufen wie am ``Ladebild`` - 0,30 in der Mitte, 0,10 bei 0,45, dann aus -,
    /// und aus demselben Grund: es ist das Licht des Ruhebildes (`Ambiente.schein`). Nur der
    /// Durchmesser ist kleiner, damit er in einer Karte nicht am Rand abgeschnitten wird
    /// (``Ladehinweis/Stufe/schein``).
    private func schein(hub: Double) -> some View {
        let kante = CGFloat(stufe.schein) * wuchs
        let deckung = ruhigeBewegung
            ? Ladehinweis.ruhigeDeckung : Ladehinweis.scheindeckung(hub: hub)
        return Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Farbe.amber.opacity(0.30), location: 0),
                        .init(color: Farbe.amber.opacity(0.10), location: 0.45),
                        .init(color: Farbe.amber.opacity(0), location: 1),
                    ],
                    center: .center, startRadius: 0, endRadius: kante / 2
                )
            )
            .frame(width: kante, height: kante)
            .opacity(deckung)
            .allowsHitTesting(false)
    }
}

#if DEBUG
    /// Beide Stufen untereinander - so sieht man am Mac, ob sie im selben Schritt schaukeln.
    #Preview("Ladeente, beide Stufen") {
        VStack(alignment: .leading, spacing: 20) {
            Ladeente(satz: Pruefworte.laedt)
            Ladeente(satz: Nachbetrachtungsworte.laedtSatz)
            Ladeente(satz: Ladehinweis.berichtssatz, stufe: .gross)
        }
        .padding(20)
        .background(Farbe.flaeche1)
    }
#endif
