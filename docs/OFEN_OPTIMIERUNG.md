# Zwei Wärmequellen, ein Puffer: die Ofenentscheidung

Wärmepumpe und Pelletofen laden denselben Kombipuffer. Welche der beiden es tun soll, ist eine
Kostenfrage, und sie hat je nach Außentemperatur und Strompreis eine andere Antwort. Bisher wird sie
von Hand beantwortet. Dieses Dokument hält fest, wie, warum das gut gedacht ist, und was der Planer
daraus machen kann.

## Die Handregel, die es zu schlagen gilt

Der Hausherr fährt heute so, und die Regel ist besser als ihr Ruf:

* Die Wärmepumpe **regelt sich selbst**. Nachts wird die Temperatur abgesenkt, damit sie möglichst
  gar nicht läuft.
* Im Winter, wenn es richtig kalt ist, wird der Ofen **um 17 Uhr** angeworfen. Nicht spät abends: der
  Abendpeak am Strommarkt soll wärmepumpenfrei bleiben.
* Morgens **um fünf oder sechs** wieder, damit die Wärmepumpe das Brauchwasser nicht nachheizt.
* Bei bitterer Kälte läuft der Ofen **die ganze Nacht durch**, damit die Wärmepumpe in der kalten
  Nacht gar nicht erst anspringt.

Das ist eine Zeitsteuerung mit den richtigen Zeiten. Was ihr fehlt, ist die Rechnung: sie kennt weder
den Strompreis der einzelnen Stunde noch die Arbeitszahl bei der aktuellen Außentemperatur, und sie
weiß nicht, wie voll der Puffer gerade ist. Sie ist deshalb an den Rändern zu grob. An einem milden
Abend mit billigem Strom wirft sie den Ofen an, obwohl die Wärmepumpe günstiger wäre; an einem
teuren Nachmittag lässt sie ihn aus, weil 17 Uhr noch nicht erreicht ist.

## Was der Ofen kostet

Die Kette hat nach Anbindung des Maestro-Moduls keine unbekannte Größe mehr. Gerechnet wird sie in
`hems_core.accounting.stove_cost`, die Zahlen stammen aus dem technischen Datenblatt
**MCZ STAR HYDROMATIC 12 M1, Rev. 09_2019** und stehen in `StoveConfig`.

| Größe | Wert | Herkunft |
| --- | --- | --- |
| Nennleistung gesamt | 11,9 kW | Datenblatt |
| davon ins Wasser | 10 kW | Datenblatt |
| davon in die Küche | 1,9 kW | Differenz |
| Wirkungsgrad bei Maximalbetrieb | 91,1 % | Datenblatt |
| Feuerungsleistung | 13,06 kW | 11,9 / 0,911 |
| Schornsteinverlust | 1,16 kW | Differenz |
| Eigenverbrauch elektrisch | 75 W | Datenblatt |
| Pelletpreis | 450 €/t | letzte Lieferung, **einstellbar** |
| Heizwert | 4,9 kWh/kg | ENplus A1 bei 8 % Feuchte, **einstellbar** |
| Pelletdurchsatz | 2,666 kg/h | 13,06 / 4,9 |
| Kosten Brennstoff | 1,20 €/h | 2,666 × 0,45 |
| Kosten Strom | 0,02 €/h | 75 W bei 30 ct |

### Die Kette prüft sich selbst, an drei Stellen

Das ist die wertvollste Eigenschaft dieser Zahlen. Leistung, Wirkungsgrad und Verbrauch stammen aus
derselben Quelle und sind über den Heizwert verknüpft, also müssen die Rechenwege zusammenfallen:

| Prüfung | gerechnet | Datenblatt |
| --- | --- | --- |
| Verbrauch bei Volllast | 11,9 / 0,911 / 4,9 = 2,67 kg/h | 2,7 kg/h |
| Verbrauch bei Minimallast | 3,2 / 0,961 / 4,9 = 0,68 kg/h | 0,7 kg/h |
| Behälterreichweite Volllast | 20 kg / 2,67 = 7,5 h | rund 8 h |

Alle drei innerhalb weniger Prozent. Damit ist auch der **Heizwert bestätigt**: die ursprüngliche
Schätzung von 5,4 kWh/kg verfehlt beide Verbrauchspunkte um zehn Prozent.
`StoveEconomics.plausible` prüft das bei jeder Rechnung mit.

### Teillast kostet dasselbe

Der überraschendste Befund, und der Grund, warum der Planer **keine Teillastkennlinie braucht**. Auf
kleiner Flamme ist der Ofen wirkungsgradbesser, weil das Rauchgas kühler abzieht (48 statt 123 °C).
Gleichzeitig geht weniger davon ins Wasser. Beides hebt sich auf:

| | nutzbar | Wirkungsgrad | ins Wasser | Verbrauch | Wärmepreis |
| --- | --- | --- | --- | --- | --- |
| Volllast | 11,9 kW | 91,1 % | 84 % | 2,67 kg/h | **10,27 ct/kWh** |
| Minimallast | 3,2 kW | 96,1 % | 56 % | 0,68 kg/h | **10,26 ct/kWh** |

Für den Planer heißt das: **die Modulation ist eine Zeitfrage, keine Kostenfrage.** Sie entscheidet,
wie schnell der Puffer voll wird, nicht wie teuer die Wärme ist. Wer nur ein- und ausschaltet,
verliert dadurch nichts. Auf die Pufferwärme allein gerechnet sieht es anders aus, dort ist Teillast
deutlich teurer, weil dann mehr in die Küche geht.

### Der Pelletbehälter begrenzt die Laufzeit

31 Liter fassen rund 20 kg. Bei Volllast reicht das für **siebeneinhalb Stunden**. Eine kalte Nacht
durchheizen geht also, zwei Nächte nicht. Der Planer darf keine Laufzeit einplanen, für die kein
Brennstoff im Gerät ist: `hopper_runtime_h` liefert die Grenze.

### Die Raumwärme

**Zählt die Wärme, die in der Küche bleibt, als Nutzen?** Ja, so ist es entschieden: die gesamte
Nutzwärme wird angerechnet. Bei diesem Gerät ist der Unterschied ohnehin klein, weil fast alles ins
Wasser geht.

| Lesart | Wärmepreis |
| --- | --- |
| nur die Pufferwärme (10 kW) | 12,2 ct/kWh |
| gesamte Nutzwärme (11,9 kW) | **10,3 ct/kWh** |

Die Rechnung gibt trotzdem beide Zahlen aus. Im Sommer, wenn die Küchenwärme lästig statt nützlich
ist, gilt die obere, und `room_heat_credit` schaltet zwischen beiden um.

## Wann welche Quelle gewinnt

Die Wärmepumpe kostet Strompreis geteilt durch Arbeitszahl. Damit lässt sich die Frage auf **eine**
Zahl zusammenziehen, die man gegen die COP-Kennlinie halten kann:

> **Break-even-COP** = Strompreis / Wärmepreis des Ofens

Schafft die Maschine bei der aktuellen Außentemperatur mehr, ist sie dran. Schafft sie weniger, ist
der Ofen dran.

| Strompreis | Break-even-COP (gesamte Nutzwärme) | Urteil bei COP 2,4 (etwa -7 °C) |
| --- | --- | --- |
| 20 ct | 2,0 | Wärmepumpe |
| 30 ct | 2,9 | Ofen |
| 45 ct | 4,4 | Ofen, deutlich |

Damit ist die Handregel nachgerechnet und im Kern bestätigt: bei Kälte und teurem Strom gewinnt der
Ofen. Der Planer wird sie nicht umwerfen, sondern schärfen.

## Was der Planer daraus machen kann

Die Rechnung oben liefert je Viertelstunde einen Preis für beide Quellen. Für das MILP heißt das:

* eine zweite binäre Schaltvariable neben der Wärmepumpe,
* die Ofenleistung als feste 10 kW in die Pufferbilanz (nicht 11,9: in den Puffer gehen zehn),
* Mindestlaufzeit und Mindeststillstand des Ofens als eigene Nebenbedingungen, deutlich länger als
  bei der Wärmepumpe (zwei Stunden statt einer halben),
* Zündkosten als Startkosten, damit der Planer ihn nicht stündlich an- und ausknipst (der
  Zündwiderstand zieht kurzzeitig 390 statt 75 W),
* die Behälterreichweite von siebeneinhalb Stunden als obere Schranke einer Laufzeit,
* und die Kostenfunktion mit beiden Preisen statt nur mit dem Strompreis.

Die Raumwärme gehört dabei **nicht** in die Pufferbilanz, sondern in die Kostenseite: sie senkt den
Wärmepreis des Ofens, füllt aber keinen Speicher.

## Was noch fehlt

**Die Arbeitszahl der Wärmepumpe ist geschätzt.** Sie kommt aus einer Kennlinie über der
Außentemperatur, nicht aus einer Messung. Das ist der schwächste Punkt des Vergleichs, und er sitzt
auf der Seite der Wärmepumpe. Mit dem Wärmemengenzähler (siehe `SENSORIK.md`) wird daraus ein
gemessener Wert, und erst dann ist die Entscheidung wirklich belastbar.

**Der Brennstoffeintrag ist bisher relativ.** Die Schneckendrehzahl ist dem Pelletmassenstrom
proportional, der Faktor ist unbekannt. Wer einmal einen Sack wiegt und die Umdrehungen dazwischen
abliest, hat ihn. Für die Kostenrechnung wird er nicht gebraucht, wohl aber für die Gegenprobe, ob
der Ofen wirklich 2,67 kg/h verbraucht.

**Fernstart einer Feuerstätte** ist eine andere Klasse von Eingriff als ein Relais. `control_enabled`
steht deshalb auf `false`, bis es ausdrücklich gewollt ist.
