# Die Uhr

**Leitidee.** In der Mitte steht ein Instrument: ein Ring über 24 Stunden mit 00 Uhr oben. Außen
zeigen Speichen den Strompreis, innen leuchtet ein Bogen, wo Sonne erwartet wird, und kurze Striche
zeigen die geplanten Läufe der Wärmepumpe. Ein Zeiger steht auf jetzt, und in der Mitte steht, was
das Haus gerade braucht.

## Was wo steht

- **Der Ring** ersetzt zugleich das Flussbild und die Karte „Die nächsten 24 Stunden“. Vom Zeiger
  an im Uhrzeigersinn liest man den kommenden Tag: lange Speichen sind teure Stunden, helle
  Speichen das Preistief, gestrichelte Stunden haben noch keinen Preis.
- **Links** vom Ring stehen Sonne und Netz, **rechts** Speicher, Wärmepumpe und Wallbox, jede
  Sache mit einem Band zum Ring, dessen Breite die Leistung zeigt.
- **Rechts daneben** der Puffer und eine Karte „Strom gerade“ mit dem Preis in großer Zahl und
  den drei Zeitspannen.
- **Unten** Tageskurve und Schalter wie bei der „Bühne“.
- **Handy:** der Ring füllt die Breite, darunter stehen die fünf Sachen als Liste in einer Karte.

## Was sich gegenüber heute ändert

- Der Blick in die Zukunft rückt in die Mitte der Seite; das Flussbild wird zur Nebensache.
- Der Ring will einmal erklärt sein. Eine Legende am Fuß nennt die drei Farben.
- Der Preis je Stunde ist nur noch als Länge lesbar, nicht als Zahl.

## Bau in SwiftUI

Ein `Canvas`: Speichen und Bögen sind `Path` in Polarkoordinaten, der Zeiger dreht sich mit der
Uhrzeit. Dieselbe Rechnung (Stunde zu Winkel, Preis zu Länge) gehört in den Kern und wird in Web
und App gegen dieselben Werte getestet. VoiceOver braucht eine eigene Beschreibung, weil ein Ring
sich nicht vorlesen lässt.

## Offen

- Aus drei Metern sind die Speichen zu lesen, die Uhrzeiten am Ring nicht.
- Was die Sonne gerade liefert, steht nur in der Kachel links, nicht im Ring.
- Das Ruhebild ist nicht mitentworfen.
