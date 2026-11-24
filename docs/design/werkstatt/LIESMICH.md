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

## Farben: Vorschlag für Zustände und Reihen (24.11.2026)

Dem Hausherrn als Seite mit Bildern von heute und danach vorgelegt; entschieden ist noch nichts.
Die Messwerte liegen in `farben/vorschlag-messung.json`: je Satz die Farben, ihr Kontrast zur
Kartenfläche `#123544` und das engste Paar je Diagramm, normal und bei Rot-Grün-Schwäche.

**Zustände.** „In Ordnung“ bekommt das Grün `#79dd9f` (17,6 vom Nebelgrau, 33,5 vom Rot der
Störung, bei Rot-Grün-Schwäche 18,8). Jeder Zustand bekommt dazu eine Form: Haken, Dreieck,
Achteck, Ring für „keine Angabe“. Der Hinweis behält `#ffd778`. Ein eigenes Gelb `#fadf47` ist
verworfen: 5,2 vom hellen Bernstein und 13,1 vom Akzent, es trennt nichts.

**Reihen.** Sonne, Wärmepumpe, Ofen und Haus sind schon überall gleich. Vier Sachen haben zwei
Farben. Der Satz der Diagramme hält seine Abstände, der Satz des Energieflusses nicht:

| Diagramm | heute Diagramm | heute Fluss | Vorschlag, Netz violett | Vorschlag, Netz rot |
|---|---|---|---|---|
| Energiefluss | 5,5 | 6,7 | 9,7 | 9,7 |
| Woher kam der Strom | 20,8 | 13,9 | 14,6 | 20,8 |
| PV-Bericht | 5,5 | 11,9 | 11,9 | 11,9 |
| Wallbox-Bericht | 20,8 | 7,5 | 19,0 | 20,8 |
| Speicher-Bericht | 18,5 | 13,9 | 14,6 | 18,5 |

Gezeigt ist das engste Paar (CIEDE2000, normales Farbsehen). Der Vorschlag: Der Fluss übernimmt
Speicher `#7fa3b3` und Wallbox `#2f89b5` aus den Diagrammen, die Einspeisung wird überall
`#ffd778`. Im Fluss stand der Speicher bisher 2,79:1 zur Fläche.

**Netzbezug.** Im Diagramm ist er `#e0533d` und damit genau das Rot der Störung, im Fluss
Nebelgrau. Eine Suche über den Farbkreis findet nur im Violett eine freie Stelle; vorgeschlagen
ist `#b48df4` (4,98:1 zur Fläche, 25,5 von der Störung). Der Preis: bei Rot-Grün-Schwäche 9,4
zum Speicher statt 15,1 mit Rot. Die Schwelle dort ist 8.

Das engste Paar im Fluss bleibt Sonne und Wärmepumpe mit 9,7. Beide Farben sind unverändert;
im Fluss trägt jeder Knoten Zeichen und Namen.

## Symbole: Bestand und drei Entwurfsrunden (23.11.2026)

`zeichen/bestand.json` hält die 25 Zeichen aus `Icon.tsx`, `zeichen/messung-bestand.json` ihre
Lage im Raster (Ränder, optische Mitte, Schwerpunkt, Deckung). `zeichen/runde1.json` bis
`runde3.json` sind Entwürfe als SVG-Fragmente auf dem 24er-Raster: vier Fassungen der
Wärmepumpe als Außengerät mit Lüfter, Zeichen für Abstimmen und Regelkreis, gefüllte Fassungen
der Bereichszeichen und des Zahnrads, Zustandszeichen (Haken, Warndreieck, Störung) sowie
Abspielen und Anhalten. Ausgewertet und übernommen ist davon noch nichts.

## Übersichtskarten: woher Leitzahl und Ampel kommen können (24.11.2026)

Am Demo-Dienst gemessen, Antwortzeit und Größe je Endpunkt hinter den sieben Seiten der Anlage:

| Seite | Endpunkt | Zeit | Größe | Was eine Karte daraus nehmen kann |
|---|---|---|---|---|
| Anlage | `/api/v1/anlage` | 0,06 s | 0,8 kB | Speicher, Vorlauf (Felder `speicher`, `heizkreis`) |
| Wärmepumpe | `/api/v1/waermepumpe` | 0,01 s | 2,7 kB | `laeuft`, `zustand_de`, Leistung, `arbeitszahl` |
| Fahrplan | `/api/v1/plan` | 0,003 s | 84 kB | `windows`, `next_cheap_window`, `planner_warn_de` |
| Wirkung | `/api/v1/anlage/kontaktwirkung?days=7` | 0,06 s | 16 kB | `urteil`, `urteil_de`, `quote` |
| Regelkreis | `/api/v1/regelkreis` | 0,20 s | 106 kB | `uebersteuert`, `kreise` (Reserven), `guete` |
| Regler | `/api/v1/waermepumpe/einstellungen` | 0,002 s | 10 kB | `satz_de`, `gelesen`, `hindernis_de` |
| Annahmen | noch nicht nachgesehen | | | |

Die Zeiten gelten für den Demo-Betrieb ohne Datenbank; am echten Dienst sind Wirkung und
Regelkreis nicht gemessen. Vier der sechs Antworten tragen schon ein fertiges Urteil oder einen
Satz des Dienstes. Die Übersicht kann also zusammentragen und muss wenig neu rechnen.
