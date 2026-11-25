# Das Kachelfeld

**Leitidee.** Die Startseite spricht dieselbe Sprache wie alle übrigen Seiten: ein Feld aus
Kacheln, jede eine Sache mit Zeichenfeld, großer Zahl und einem Wort für ihren Zustand. Was gerade
arbeitet, leuchtet in seiner Farbe und trägt einen Balken am Fuß; was ruht, ist grau.

## Was wo steht

- **Der Satz** ist die größte Kachel links oben. Sie trägt die Farbe des Zustands (Terrakotta,
  wenn die Wärmepumpe läuft, Bernstein bei einem Befund) und das Zeichen dazu groß und blass in
  der Ecke. Ein Befund der Wache steht in derselben Kachel.
- **Sechs Sachen** als gleich große Kacheln: Haus, Sonne, Netz, Speicher, Wärmepumpe, Wallbox.
  Die Zahl ist an der Wand 40 Pixel hoch, die des Hauses 48.
- **Puffer** daneben, **Tageskurve** breit darunter (sie bekommt hier die meiste Höhe), rechts die
  **nächsten 24 Stunden**.
- **Die Schalter** liegen als Streifen am Fuß, sieben in einer Reihe mit Namen und Zustand
  daneben. Alfred hat rechts im Streifen sein eigenes Feld.
- **Handy:** der Satz, dann die sechs Sachen in zwei Spalten, Puffer, Tag, 24 Stunden, Schalter.

## Was sich gegenüber heute ändert

- Das Flussbild fällt ganz weg. Woher der Strom kommt und wohin er geht, liest man aus den
  Wörtern „Bezug“, „liefert“, „lädt“ und nicht mehr aus Linien. Das ist der Preis dieser Richtung.
- Die 24 Stunden und die vier Zahlen wie bei der „Bühne“.

## Bau in SwiftUI

Der einfachste der Entwürfe: `Seitenkachel` und `Kontokarte` gibt es schon, das Raster ist ein
`Grid` an der Wand und ein `LazyVGrid` am Handy. Neu sind nur der Balken am Fuß der Kachel und die
Reihe der Schalter.

## Offen

- Sechs Kacheln zeigen sechs Zahlen gleich laut; die Rangfolge trägt allein der Satz.
- Das Ruhebild ist nicht mitentworfen.
