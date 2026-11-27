import SwiftUI

/// Die Marke einer Linie in einer Legende: ein waagerechter Strich, durchgezogen oder
/// gestrichelt, so wie die Linie im Bild gezeichnet ist.
///
/// **Warum es sie gibt.** Zwei Legenden zeichneten jeden Strich durchgezogen, gleich ob die
/// Linie im Bild gestrichelt war: die der Tageskurve (Hausherr am 27.11.2026: „Die
/// Legenden-Erklärung passt überhaupt nicht zu der Grafik“) und die des Fahrplans bei „PV
/// erwartet“. Gestrichelt heißt in beiden Bildern dasselbe: geplant oder erwartet und noch
/// nicht gemessen. Die Marke muss das genauso sagen wie die Linie.
struct Strichmarke: View {
    let farbe: Color
    var gestrichelt = false
    /// 18 Punkte: zwei Striche von fünf Punkten mit vier Punkten Lücke.
    var breite: CGFloat = 18
    var staerke: CGFloat = 2

    var body: some View {
        Strich()
            .stroke(farbe, style: StrokeStyle(lineWidth: staerke, dash: gestrichelt ? [5, 4] : []))
            .frame(width: breite, height: 8)
    }
}

/// Ein waagerechter Strich durch die Mitte seines Feldes.
private struct Strich: Shape {
    func path(in feld: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: feld.minX, y: feld.midY))
        p.addLine(to: CGPoint(x: feld.maxX, y: feld.midY))
        return p
    }
}
