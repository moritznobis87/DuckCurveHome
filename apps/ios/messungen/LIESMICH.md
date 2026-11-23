# Die Messungen

Hier liegt je Seite eine **Messung**: die Browser-Vorlage (`apps/web`) Block für Block gegen
die iOS-App gehalten, mit Maßen, Texten, Feldnamen und den Begründungen aus den Kommentaren der
Vorlage. Jede Behauptung über Code trägt `Datei:Zeile`.

**Warum sie hier liegen und nicht im Papierkorb.** Die Handliste in `../ABGLEICH.md` hat für
acht Seiten 39 Lücken gefunden; dieselben acht Seiten gemessen ergaben 137. Der Unterschied
sind nicht Geschmacksfragen, sondern Fehler, die man im Vorbeigehen nicht sieht: eine
verwechselte Achse, ein fehlendes Feld, das als gemessene Null durchgeht, eine Seite, die
leichter absichert als der Browser. Eine Messung dieser Art kostet ungefähr eine Stunde Arbeit
je Seite – zweimal zu messen wäre Verschwendung, und darum werden sie aufbewahrt.

**Wozu sie noch gut sind, nachdem die Seite gebaut ist.** Sie sind das einzige Dokument, das
die Vorlage *beschreibt* statt sie zu sein. Wer später fragt, warum in der App eine Achse ohne
Null steht oder eine Legende unter dem Kartenkopf statt darunter, findet hier die Stelle der
Vorlage und den Grund. Am Fuß jeder Messung steht außerdem, was beim Umbau bewusst anders
gemacht wurde.

**Die Form** (jede Datei hält sie ein):

```
IST       – was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile
VORLAGE   – Block für Block, mit Maßen, Farben, Texten, Zuständen und den Datenfeldern
LUECKEN   – [traegt-die-seite] | [spuerbar] | [klein]
KERN: SCHON DA – was nicht neu gerechnet werden muss
ES FEHLT  – was in den Kern gehört, mit Datei- und Typvorschlag
BAUPLAN   – welche Dateien in welcher Reihenfolge
WAS SCHWIERIG WIRD – wo SwiftUI kein Gegenstück hat, und welcher Weg im Projekt gewählt wurde
```

`waerme-bilanz.md` ist der Sonderfall: sie belegt, warum es diese Seite **nicht** mehr gibt.
