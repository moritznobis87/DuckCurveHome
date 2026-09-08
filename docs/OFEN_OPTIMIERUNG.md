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
`hems_core.accounting.stove_cost`, die Zahlen stehen in `StoveConfig`.

| Größe | Wert | Herkunft |
| --- | --- | --- |
| Nennleistung gesamt | 11,9 kW | Datenblatt |
| davon ins Wasser | 10 kW | Datenblatt |
| davon in die Küche | 1,9 kW | Differenz |
| Feuerungswirkungsgrad | 90,4 % | Datenblatt |
| Feuerungsleistung | 13,16 kW | 11,9 / 0,904 |
| Schornsteinverlust | 1,26 kW | Differenz |
| Eigenverbrauch elektrisch | 75 W | Datenblatt |
| Pelletpreis | 450 €/t | letzte Lieferung, **einstellbar** |
| Heizwert | 4,9 kWh/kg | ENplus A1 bei 8 % Feuchte, **einstellbar** |
| Pelletdurchsatz | 2,686 kg/h | 13,16 / 4,9 |
| Kosten Brennstoff | 1,21 €/h | 2,686 × 0,45 |
| Kosten Strom | 0,02 €/h | 75 W bei 30 ct |

Der Ofen läuft in diesem Haus praktisch immer auf Stufe 5. Das Datenblatt kennt zwar einen
Minimalverbrauch von 0,7 kg/h, aber Teillast wird bewusst nicht modelliert: eine Kennlinie zu
erfinden, die niemand gemessen hat, macht die Rechnung nicht genauer, nur länger.

### Die Kette prüft sich selbst

Das ist die wertvollste Eigenschaft dieser Zahlen. Leistung, Wirkungsgrad und maximaler Verbrauch
stammen aus derselben Quelle und sind über den Heizwert verknüpft, also müssen beide Rechenwege zum
selben Ergebnis führen:

```
vorwärts:    11,9 / 0,904 / 4,9   = 2,686 kg/h     Datenblatt: 2,7
rückwärts:   2,7 × 4,9 × 0,904    = 11,96 kW       Datenblatt: 11,9
```

Ein halbes Prozent Abweichung. Damit ist auch der **Heizwert bestätigt**: die ursprüngliche
Schätzung von 5,4 kWh/kg ergäbe 2,44 kg/h und läge zehn Prozent unter dem Datenblatt.
`StoveEconomics.plausible` prüft das bei jeder Rechnung, damit eine falsch eingetragene Zahl nicht
still eine falsche Entscheidung erzeugt.

### Die Raumwärme

**Zählt die Wärme, die in der Küche bleibt, als Nutzen?** Ja, so ist es entschieden: die gesamte
Nutzwärme wird angerechnet. Bei diesem Gerät ist der Unterschied ohnehin klein, weil fast alles ins
Wasser geht.

| Lesart | Wärmepreis |
| --- | --- |
| nur die Pufferwärme (10 kW) | 12,3 ct/kWh |
| gesamte Nutzwärme (11,9 kW) | **10,4 ct/kWh** |

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
| 45 ct | 4,3 | Ofen, deutlich |

Damit ist die Handregel nachgerechnet und im Kern bestätigt: bei Kälte und teurem Strom gewinnt der
Ofen. Der Planer wird sie nicht umwerfen, sondern schärfen.

## Was der Planer daraus machen kann

Die Rechnung oben liefert je Viertelstunde einen Preis für beide Quellen. Für das MILP heißt das:

* eine zweite binäre Schaltvariable neben der Wärmepumpe,
* die Ofenleistung als feste 10 kW in die Pufferbilanz (nicht 11,9: in den Puffer gehen zehn),
* Mindestlaufzeit und Mindeststillstand des Ofens als eigene Nebenbedingungen, deutlich länger als
  bei der Wärmepumpe (zwei Stunden statt einer halben),
* Zündkosten als Startkosten, damit der Planer ihn nicht stündlich an- und ausknipst,
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
der Ofen wirklich 2,69 kg/h verbraucht.

**Fernstart einer Feuerstätte** ist eine andere Klasse von Eingriff als ein Relais. `control_enabled`
steht deshalb auf `false`, bis es ausdrücklich gewollt ist.
