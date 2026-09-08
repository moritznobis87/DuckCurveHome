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
| Nennleistung gesamt | 12 kW | Gerät |
| davon ins Wasser | 9 kW | Gerät |
| davon in die Küche | 3 kW | Differenz |
| Verbrennungswirkungsgrad | 92 % | Betreiberangabe |
| Feuerungsleistung | 13,04 kW | 12 / 0,92 |
| Schornsteinverlust | 1,04 kW | Differenz |
| Pelletpreis | 450 €/t | letzte Lieferung, **einstellbar** |
| Heizwert | 4,9 kWh/kg | ENplus A1 bei 8 % Feuchte, **einstellbar** |
| Pelletdurchsatz | 2,66 kg/h | 13,04 / 4,9 |
| Kosten | 1,20 €/h | 2,66 × 0,45 |

Der Ofen läuft in diesem Haus praktisch immer auf Stufe 5. Teillast wird deshalb bewusst nicht
modelliert: eine Kennlinie zu erfinden, die niemand gemessen hat, macht die Rechnung nicht genauer,
nur länger.

### Die eine Entscheidung, über die man streiten kann

**Zählt die Raumwärme als Nutzen?** Der Ofen steht in der Küche und heizt sie mit drei Kilowatt. Das
ist kein Verlust, aber es ist auch keine Wärme im Puffer.

| Lesart | Wärmepreis |
| --- | --- |
| nur die Pufferwärme (9 kW) | **13,3 ct/kWh** |
| Puffer plus Raumwärme (12 kW) | **10,0 ct/kWh** |

Beide Zahlen sind richtig, sie beantworten verschiedene Fragen. In der Heizperiode ersetzt die
Küchenwärme Wärme, die sonst die Wärmepumpe liefern müsste, dann ist 10,0 der ehrliche Wert. Im
Sommer, oder wenn die Küche ohnehin zu warm wird, ist sie wertlos, dann gilt 13,3. Der
Anrechnungsgrad steht deshalb als `room_heat_credit` in der Konfiguration und nicht als Konstante im
Code, und die Rechnung gibt immer beide Preise aus.

## Wann welche Quelle gewinnt

Die Wärmepumpe kostet Strompreis geteilt durch Arbeitszahl. Damit lässt sich die Frage auf **eine**
Zahl zusammenziehen, die man gegen die COP-Kennlinie halten kann:

> **Break-even-COP** = Strompreis / Wärmepreis des Ofens

Schafft die Maschine bei der aktuellen Außentemperatur mehr, ist sie dran. Schafft sie weniger, ist
der Ofen dran.

| Strompreis | Break-even-COP (mit Raumwärme) | Urteil bei COP 2,4 (etwa -7 °C) |
| --- | --- | --- |
| 20 ct | 2,0 | Wärmepumpe |
| 30 ct | 3,0 | Ofen |
| 45 ct | 4,5 | Ofen, deutlich |

Damit ist die Handregel nachgerechnet und im Kern bestätigt: bei Kälte und teurem Strom gewinnt der
Ofen. Der Planer wird sie nicht umwerfen, sondern schärfen.

## Was der Planer daraus machen kann

Die Rechnung oben liefert je Viertelstunde einen Preis für beide Quellen. Für das MILP heißt das:

* eine zweite binäre Schaltvariable neben der Wärmepumpe,
* die Ofenleistung als feste 9 kW in die Pufferbilanz (nicht 12: in den Puffer gehen neun),
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
der Ofen wirklich 2,66 kg/h verbraucht.

**Fernstart einer Feuerstätte** ist eine andere Klasse von Eingriff als ein Relais. `control_enabled`
steht deshalb auf `false`, bis es ausdrücklich gewollt ist.
