import DuckCurveKit
import SwiftUI

/// Der Ladeschirm: Alfred groß in der Mitte, darunter die Wortmarke und ein Satz.
///
/// **Was er gegen was tut.** Bis jetzt zeigte `Wurzel` sofort das Gerippe, während
/// `haus.starte()` noch den Strom öffnete: Kacheln ohne Zahlen, Diagramme ohne Linien, und auf
/// einem frisch gebauten Gerät eine halbe Sekunde oder länger. Der Nutzer nannte es
/// „ein petrolfarbener bildschirm“ und hat recht - genau das ist ein Verlauf aus `Marken.deep`
/// ohne Inhalt darauf. Hier steht stattdessen etwas, das man als Ladeschirm erkennt.
///
/// **Er ist das dritte Vollbild dieser App und hält sich an die Mittel der anderen beiden.**
/// Der Grund ist derselbe Verlauf wie auf jeder Seite (``Farbe/seitengrund``), die Ente steht
/// auf der weißen Kachel der Marke wie am ``Entenknopf``, der weiche Schein dahinter ist der
/// des Ruhebildes (`Ambiente.schein`), und er atmet im Takt des ``Atempunkt`` - 1,8 Sekunden
/// hin, 1,8 zurück. Neu erfunden ist hier nichts außer dem Zusammenstellen.
///
/// **Die Ente und nicht der Kurvenzug.** Dieselbe Trennung wie am ``Entenknopf``: der Kurvenzug
/// ist die Marke im Kopf, das Maskottchen ist, wer einen anspricht. Ein Ladeschirm spricht an -
/// er sagt „ich bin da, das Haus noch nicht“ -, also steht Alfred darauf, und die Wortmarke
/// steht als gesetztes Wort darunter.
///
/// **Was dasteht und wann er kommt, steht nicht hier**, sondern in ``Ladeschirm`` im Kern, mit
/// Tests. Diese Ansicht zeichnet.
struct Ladebild: View {
    /// Die Wandanzeige oder das Telefon. Entscheidet über die Maße und über die zweite Zeile.
    let wand: Bool

    @Environment(\.accessibilityReduceMotion) private var ruhigeBewegung

    var body: some View {
        GeometryReader { raum in
            let mass = Ladebildmasse(raum.size)
            // **Oben ausgerichtet und dann verschoben, nicht mittig.** Den ganzen Block
            // mittig zu setzen wäre das Naheliegende, aber das Startbrett davor kann das
            // nicht: dort hängt die Unterkante der Kachel an einem festen Maß unter der Mitte
            // (`Startbrett.storyboard`, `ente-mitte-hoch`), weil Autolayout ohne eine weitere
            // Ansicht keinen Mittelpunkt zweier Geschwister kennt. Also folgt dieser Schirm
            // dem Brett und nicht umgekehrt - sonst sprang die Ente beim Übergang um die halbe
            // Höhe des Textes darunter, und die beiden Schirme folgen in derselben Sekunde
            // aufeinander.
            ZStack(alignment: .top) {
                Farbe.seitengrund
                VStack(spacing: 0) {
                    ente(mass)
                        .padding(.bottom, mass.luftUnterEnte)
                    Text(Ladeschirm.marke)
                        // Die Wortmarke ist im Kopf 16 Punkte groß (``Schrift/marke``) - das ist
                        // eine Zeile neben dem Datum. Hier ist sie das zweite von drei Dingen auf
                        // einer leeren Fläche und wächst mit ihr, wie im Ruhebild jedes Maß.
                        // `relativeTo`, damit „Größerer Text“ weiter wirkt.
                        .font(Schrift.sansHalbfett(mass.marke, relativeTo: .title))
                        .foregroundStyle(Farbe.text1)
                        .padding(.bottom, mass.luftUeberSatz)
                    Text(Ladeschirm.satz)
                        .font(Schrift.sans(mass.satz, relativeTo: .body))
                        .foregroundStyle(Farbe.text2)
                    if wand {
                        Text(Ladeschirm.wandzusatz)
                            .font(Schrift.sans(mass.zusatz, relativeTo: .footnote))
                            .foregroundStyle(Farbe.text3)
                            .padding(.top, mass.luftUeberZusatz)
                    }
                }
                .multilineTextAlignment(.center)
                // Die Zeilen brechen innerhalb dieser Breite um und laufen nicht in den Rand -
                // am Telefon im Querformat ist die Fläche breit und niedrig, und ein Satz über
                // die ganze Breite ist von drei Metern nicht mehr als Satz zu lesen.
                .frame(maxWidth: mass.textbreite)
                // Die Oberkante des Blocks ist die der Kachel; eine Kachelhöhe weiter unten
                // liegt ihre Unterkante, und die soll `unterDerMitte` unter der Mitte stehen.
                // Kein Maß des Textes kommt darin vor - darum braucht es keine Messung.
                .offset(y: raum.size.height / 2 + mass.unterDerMitte - mass.kachel)
            }
            .frame(width: raum.size.width, height: raum.size.height)
        }
        .ignoresSafeArea()
        // **Ein Element und ein Satz.** Ente, Wortmarke und Zeile sind zusammen eine Aussage;
        // einzeln vorgelesen wären es drei Bruchstücke, von denen keines sagt, worauf gewartet
        // wird.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Ladeschirm.vorleser)
    }

    /// Die Ente auf ihrer Kachel, mit dem atmenden Schein dahinter.
    private func ente(_ mass: Ladebildmasse) -> some View {
        Image("Ente")
            .resizable()
            .scaledToFit()
            .frame(width: mass.ente, height: mass.ente)
            .frame(width: mass.kachel, height: mass.kachel)
            .background(
                Circle()
                    .fill(Farbe.papier)
                    .shadow(color: .black.opacity(0.35), radius: mass.kachel * 0.09, y: 6)
            )
            // Der Schein liegt hinter der Kachel und ist ein Mehrfaches von ihr groß. Ein
            // Hintergrund dehnt die Ansicht nicht, also bleibt die Mitte die Mitte.
            .background(Atemschein(kante: mass.schein, ruhig: ruhigeBewegung))
    }
}

/// Die Maße des Ladeschirms, nach dem Vorbild von `Bildmasse` im Ruhebild.
///
/// **Gemessen wird an der kurzen Kante.** Das Ruhebild rechnet in `vw` wie die Vorlage, weil es
/// nur an der Wand steht. Dieser Schirm steht auf beidem, und das iPhone im Querformat ist
/// 393 Punkte hoch: ein Anteil der Breite ergäbe dort eine Ente, die oben und unten nicht mehr
/// hineinpasst. Die kurze Kante ist das Maß, das auf jedem Gerät und in jeder Lage stimmt.
private struct Ladebildmasse {
    let kurzeKante: CGFloat
    let breite: CGFloat

    init(_ groesse: CGSize) {
        breite = max(320, groesse.width)
        kurzeKante = max(320, min(groesse.width, groesse.height))
    }

    /// Ein Anteil der kurzen Kante, zwischen zwei Schranken gehalten - `clamp` der Vorlage.
    private func kurz(_ klein: CGFloat, _ anteil: CGFloat, _ gross: CGFloat) -> CGFloat {
        min(max(klein, anteil * kurzeKante), gross)
    }

    /// Die weiße Kachel: am kleinen iPhone 150 Punkte, am iPad 260.
    ///
    /// Die Untergrenze ist das, was „groß und mittig“ am Telefon heißt - gut ein Drittel der
    /// Breite. Die Obergrenze ist die, hinter der es kein Logo mehr ist, sondern ein Bild.
    var kachel: CGFloat { kurz(150, 0.34, 260) }
    /// Die Ente darauf, im Verhältnis des ``Entenknopf`` (38 in 52).
    var ente: CGFloat { kachel * 0.73 }
    /// Der Schein dahinter.
    var schein: CGFloat { kachel * 2.6 }

    /// So weit unter der Bildmitte endet die Kachel - der Wert des Startbretts.
    ///
    /// Dieselben 24 Punkte wie in `ente-mitte-hoch`, und aus demselben Grund: der Text gehört
    /// zum Bild, also sitzt die Ente etwas über der Mitte und nicht auf ihr.
    var unterDerMitte: CGFloat { 24 }

    var marke: CGFloat { kurz(26, 0.055, 38) }
    var satz: CGFloat { kurz(14, 0.026, 18) }
    var zusatz: CGFloat { satz * 0.82 }

    var luftUnterEnte: CGFloat { kachel * 0.21 }
    var luftUeberSatz: CGFloat { marke * 0.32 }
    var luftUeberZusatz: CGFloat { satz * 0.7 }

    /// So breit dürfen die Zeilen werden - 32 Punkte Luft an jeder Seite, höchstens 440.
    var textbreite: CGFloat { min(breite - 64, 440) }
}

/// Der Schein hinter der Ente, der atmet, solange gewartet wird.
///
/// **Warum überhaupt eine Bewegung.** Ein Bild, das stillsteht, sagt nicht, ob noch etwas
/// passiert - und genau das ist die Frage, die einer stellt, der vor einem Ladeschirm steht.
/// Bewegt wird darum das Licht und nicht die Ente: ein hüpfendes Maskottchen wäre Unterhaltung,
/// ein Atem ist eine Auskunft. Derselbe Takt wie am ``Atempunkt`` des Ruhebildes, 1,8 Sekunden
/// je Richtung, und derselbe Grund: langsam genug, dass man nicht hinsehen muss.
///
/// **Hinter `accessibilityReduceMotion`.** Wer Bewegung abgestellt hat, bekommt den Schein in
/// einer mittleren Stärke, die stehen bleibt - nicht keinen: er ist auch das Licht hinter dem
/// Logo, nicht nur die Bewegung.
private struct Atemschein: View {
    let kante: CGFloat
    let ruhig: Bool

    @State private var atmet = false

    var body: some View {
        Circle()
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
            .opacity(ruhig ? 0.8 : (atmet ? 1 : 0.5))
            .animation(
                ruhig ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: atmet
            )
            .onAppear { atmet = !ruhig }
            .allowsHitTesting(false)
    }
}
