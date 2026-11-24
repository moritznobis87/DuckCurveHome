# Werkstatt: Farben und Symbole

Arbeitsstand der Überarbeitung von Farbsystem und Zeichensatz (Vorgabe des Hausherrn vom
23.11.2026). Hier liegt, was gemessen und entworfen ist, damit es einen Abbruch der Sitzung
übersteht. Was in Dashboard und App eingebaut ist, steht in den Pull Requests; diese Dateien sind
die Grundlage dafür und kein Teil der Anwendung.

## Farben: gemessener Bestand (23.11.2026)

`farben/kontrast-bestand.json` enthält 120 Paare aus Textfarbe und Fläche, je mit dem
WCAG-Verhältnis und dem APCA-Wert. Die Befunde daraus:

| Befund | Messung |
|---|---|
| Die blasse Textstufe `--text-3` (Weiß mit 48 % Deckung) liegt auf den Kartenflächen unter 4,5. | 4,41 auf Fläche 1, 4,22 auf Fläche 2, 3,88 auf Fläche 3 |
| Wo sie zusätzlich mit 70 % Deckung gesetzt ist, sinkt sie unter 3. | 2,62 bis 3,06 |
| Alarmrot `#e0533d` als Textfarbe liegt überall unter 4,5. | 4,19 auf dem Grund, 3,70 auf Fläche 1, 3,38 auf Fläche 2, 2,94 auf Fläche 3 |
| Die Stichwortzeilen (Kicker, Nebelgrau `#7fa3b3`) liegen auf Fläche 3 unter 4,5. | 4,18 |
| `--ok` ist dasselbe Nebelgrau wie Netzbezug, Preis, Speicher im Diagramm und die Kicker. Ein guter Zustand ist von Schmuck und Reihen nicht zu unterscheiden. | ΔE 0 |
| `--warn` ist derselbe Bernstein wie der Akzent und die Photovoltaik. | ΔE 0 |
| Diagramme (`charts/palette.ts`) und Energiefluss (`tokens.css`) geben derselben Sache verschiedene Farben: Netzbezug ist im Diagramm Alarmrot und im Fluss Nebelgrau, Speicher und Wallbox weichen ebenfalls ab. | zwei Sätze |
| Im Diagrammsatz liegen 17 von 55 Paaren unter der Schwelle (ΔE unter 15, bei Rot-Grün-Schwäche unter 8). | etwa Speicher und Preis ΔE 0, Einspeisung und Speicher 5,5 |

## Farben: Kandidaten, nachgemessen (24.11.2026)

Kontrast als WCAG-Verhältnis auf Grund, Fläche 1, Fläche 2, Fläche 3.

| Kandidat | Wert | Grund | F1 | F2 | F3 |
|---|---|---|---|---|---|
| `--text-3` mit 58 % Deckung | Weiß .58 | 6,21 | 5,76 | 5,42 | 4,92 |
| Alarm als Text, heller | `#ff7266` | 6,01 | 5,31 | 4,85 | 4,21 |
| Zustand gut, ein eigenes Grün | `#79dd9f` | 9,68 | 8,56 | 7,82 | 6,79 |
| Kicker, eine Stufe heller | `#8ab2c4` | 7,07 | 6,25 | 5,71 | 4,96 |

Zwei Auflagen aus der Messung. Das hellere Alarmrot liegt näher am Terrakotta der Wärmepumpe
(ΔE 8,9, bei Rot-Grün-Schwäche 1,4); es ist deshalb nur für Text gedacht, Flächen und Marken
behalten `#e0533d`. Das Grün liegt ΔE 8,5 vom Grün des Puffers im Diagramm; es gehört an
Zustandszeichen und nicht in ein Diagramm.

## Symbole: Bestand und drei Entwurfsrunden (23.11.2026)

`zeichen/bestand.json` hält die 25 Zeichen aus `Icon.tsx`, `zeichen/messung-bestand.json` ihre
Lage im Raster (Ränder, optische Mitte, Schwerpunkt, Deckung). `zeichen/runde1.json` bis
`runde3.json` sind Entwürfe als SVG-Fragmente auf dem 24er-Raster: vier Fassungen der
Wärmepumpe als Außengerät mit Lüfter, Zeichen für Abstimmen und Regelkreis, gefüllte Fassungen
der Bereichszeichen und des Zahnrads, Zustandszeichen (Haken, Warndreieck, Störung) sowie
Abspielen und Anhalten. Ausgewertet und übernommen ist davon noch nichts.
