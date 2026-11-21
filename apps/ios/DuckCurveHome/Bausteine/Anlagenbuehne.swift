import DuckCurveKit
import SwiftUI

/// Die Bühne, auf der das Anlagenschema steht: tiefes Petrol, eine Haarlinie, ein tiefer Schatten.
///
/// **Warum die Zeichnung keine Karte sein darf.** Hier stand eine ``Karte`` mit dem Kicker
/// „Die Anlage“ - also `flaeche1` (#0F2E3D) am Schirm und `flaeche2` am Telefon. Die Deckungen
/// der Zeichnung sind aber für einen *dunkleren* Grund gerechnet als die Karten der App: die
/// Vorlage legt `rgba(10,39,53,.85)` über den Seitenverlauf und lässt ihn nach unten auf
/// `rgba(5,22,31,.9)` fallen (`globals.css:565`). Auf einer Karte verlieren darum genau die
/// Teile, die das Bild tragen - die Lichtpunkte in den Rohren, der Sonnenschein hinter der PV,
/// die Glaskacheln -, ihren Kontrast. Die Bühne ist kein Schmuck, sondern die Bedingung dafür,
/// dass das Bild lesbar ist.
///
/// **Ein eigener Baustein und nicht in der Seite.** Die Wiedergabeseite leiht sich in der
/// Vorlage dieselbe Fassung (`globals.css:606-609`), zeichnet also dasselbe Schema auf derselben
/// Bühne; zwei Seiten teilen sie damit.
///
/// **Der Rahmen ist ein Verlauf und kein Strich.** `.anlage-buehne` hat ein Polster von einem
/// Punkt und einen Verlauf als Hintergrund, `.anlage-innen` legt sich darüber: was man als
/// Haarlinie sieht, ist der Rand dieses Verlaufs. Ein `strokeBorder` in einer Farbe wäre oben
/// zu dunkel und unten zu hell; die Stopps stehen an ``Marken/buehneRand``.
struct Anlagenbuehne<Inhalt: View>: View {
    @ViewBuilder var inhalt: () -> Inhalt

    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    /// 28 am Schirm, 20 am Telefon (`handy.css:398`); innen je einen Punkt weniger, weil das
    /// Polster der Hülle einen Punkt breit ist.
    private var aussen: CGFloat { schmal ? 20 : 28 }
    private var innen: CGFloat { aussen - 1 }

    var body: some View {
        VStack(spacing: 0) {
            inhalt()
                .frame(maxWidth: .infinity)
                .background(flaeche)
                .clipShape(RoundedRectangle(cornerRadius: innen, style: .continuous))
            if schmal {
                hinweis
            }
        }
        .padding(1)
        .background(rahmen)
        .clipShape(RoundedRectangle(cornerRadius: aussen, style: .continuous))
        // `box-shadow: 0 40px 120px rgba(0,0,0,.45)`, am Telefon ausgeschaltet (`handy.css:398`).
        // CSS misst die Weichzeichnung über den ganzen Durchmesser, SwiftUI als Halbmesser.
        .shadow(color: .black.opacity(schmal ? 0 : 0.45), radius: schmal ? 0 : 60, y: schmal ? 0 : 40)
    }

    /// Der Hinweis unter der Zeichnung, nur am Telefon.
    ///
    /// Er steht **innerhalb** der Hülle und auf dem Verlauf des Rahmens, so wie
    /// `.anlage-buehne::after` hinter `.anlage-innen` steht (`handy.css:400`) - eine Zeile, die
    /// zur Bühne gehört und nicht eine Beschriftung darunter. Die Zeichnung rollt mit Indikator,
    /// aber ein Indikator sagt nicht, *was* rechts noch kommt.
    private var hinweis: some View {
        Text(Anlagenworte.wischhinweis)
            .font(Schrift.sans(12.5))
            .foregroundStyle(Farbe.text3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 9, leading: 12, bottom: 11, trailing: 12))
            .accessibilityLabel("Die Zeichnung lässt sich zur Seite schieben: Strom, Erzeuger, Speicher, Verbraucher.")
    }

    /// Die beiden Verläufe der Bühne. Die Werte und ihre Begründungen stehen an
    /// ``Marken/buehneOben`` und ``Marken/buehneRand``: die Bühne trägt in der Vorlage zwei
    /// Seiten (`globals.css:606-609`), und was zwei Seiten teilen, gehört in die Palette.
    private var flaeche: LinearGradient { Farbe.buehneFlaeche }
    private var rahmen: LinearGradient { Farbe.buehneRand }
}

/// Der Kasten, der dasteht, solange die Anlage noch nicht da ist.
///
/// **Nicht `Leer` in einer Karte.** Die Vorlage hält hier 420 Punkte Höhe frei
/// (`.anlage-warten`, `globals.css:597`), damit die Seite beim Eintreffen der Daten nicht
/// springt - eine Karte mit einer Zeile „Wird geholt …“ ist 60 Punkte hoch und die Bühne
/// danach 430. Bei einem Fehler bleibt der Kasten **leer**: die Meldung steht darüber und
/// muss nicht zweimal dastehen (`Anlage.tsx:88`).
struct Anlagenwarten: View {
    var fehler: Bool = false

    var body: some View {
        Text(fehler ? "" : Anlagenworte.wartesatz)
            .font(Schrift.klein)
            .foregroundStyle(Farbe.text3)
            .frame(maxWidth: .infinity, minHeight: 420)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Farbe.linie1, lineWidth: 1)
            )
    }
}
