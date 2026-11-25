# Die Bühne

**Leitidee.** Die Seite zeigt das Haus unter seinem Himmel. Die Sonne steht auf ihrem Bogen an der
Stelle, an der sie gerade ist, nachts stehen Mond und Sterne da. Strom fließt als leuchtendes Band,
dessen Breite die Leistung zeigt, und das Haus in der Mitte trägt die Summe.

## Was wo steht

- **Kopf:** Marke, die fünf Bereiche, Zahnrad und Person; rechts Datum, Verbindung und
  Außentemperatur in zwei Zeilen neben der großen Uhr.
- **Der Satz** steht als Überschrift über allem, darunter „Automatik“ als Marke und was als
  Nächstes kommt. Ein Befund der Wache steht rechts daneben, am Handy darunter.
- **Die Bühne** nimmt links die obere Hälfte ein. Netz und Wallbox stehen links vom Haus, Speicher
  und Wärmepumpe rechts. Das Kabel vom Netz und das Rohr zur Wärmepumpe laufen unter der Erde.
  Was ruht, ist leiser gezeichnet. Der Lüfter der Wärmepumpe dreht sich, wenn sie läuft.
- **Rechts:** der Puffer mit Tank und vier Fühlern, darunter die nächsten 24 Stunden als ein Bild
  (Preis als Säulen, erwartete Sonne dahinter, Läufe der Wärmepumpe als Striche) mit drei
  Zeitspannen.
- **Unten:** die Kurve des Tages mit Gestern, Heute, Morgen und den vier Zahlen im Kopf der Karte;
  daneben die sieben Schalter. Alfred sitzt im achten Feld und verdeckt nichts mehr.
- **Handy:** Satz, Bühne, darunter Wallbox und Wärmepumpe als zwei Kacheln, an denen die Bänder
  aus dem Haus ankommen; dann Puffer, 24 Stunden, Tag, Schalter.

## Was sich gegenüber heute ändert

- Der Stern aus dünnen Linien fällt weg. An seine Stelle tritt ein Bild.
- „Die nächsten 24 Stunden“ verliert seine Sätze: an der Wand drei Zeilen, am Handy fünf Sätze
  werden zu einem Bild und drei Zeitspannen. Der Hinweis, wann die Preise für morgen kommen,
  steht nicht mehr als Satz da; die Stunden ohne Preis sind gestrichelt gezeichnet.
- Die vier Zahlen des Tages wandern vom Fuß der Seite in den Kopf der Tageskarte.
- Die Leistung des Speichers in kW steht nicht mehr als Zahl da, nur noch als Breite des Bandes.
- Bei unterbrochener Verbindung wird die Bühne blass, und eine Marke sagt, von wann das Bild ist.

## Bau in SwiftUI

Die Bühne ist ein `Canvas` in einer `TimelineView`: Bogen und Bänder sind `Path`, die Lichtpunkte
ein gestrichelter Strich mit wanderndem `dashPhase`, der Schein ein `RadialGradient`. Zahlen und
Namen liegen als `Text` darüber, damit sie mit der Schriftgröße des Geräts wachsen. Die Lage der
Sachen rechnet eine gemeinsame Funktion aus Breite und Höhe; sie gehört in den Kern und wird in
Web und App gegen dieselben Beispielwerte getestet. Die 24 Stunden und die Tageskurve bleiben
Swift Charts wie heute.

## Offen

- Sonne tief am Horizont und Schrift links oben: geprüft sind Mittag und Nacht, nicht der Morgen.
- Der Pelletofen hat auf der Bühne keinen Platz; er steht bei den Schaltern.
- Das Ruhebild (Ambiente nach fünf Minuten) ist nicht mitentworfen.
