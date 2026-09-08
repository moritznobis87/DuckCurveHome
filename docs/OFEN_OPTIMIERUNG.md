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
| Behälterreichweite Volllast | 15 kg / 2,67 = 5,6 h | rund 8 h bei 20 kg |

Die ersten beiden innerhalb weniger Prozent. Die dritte weicht ab, weil das Datenblatt mit einer
vollen Füllung von rund 20 kg rechnet; gewogen passen in diesen Behälter 15 kg. Damit ist auch der **Heizwert bestätigt**: die ursprüngliche
Schätzung von 5,4 kWh/kg verfehlt beide Verbrauchspunkte um zehn Prozent.
`StoveEconomics.plausible` prüft das bei jeder Rechnung mit.

### Teillast kostet dasselbe, ist aber trotzdem schlechter

Die beiden Sätze widersprechen sich nur scheinbar, und der Unterschied entscheidet, wie der Planer
gebaut werden muss.

Auf kleiner Flamme ist der Ofen wirkungsgradbesser, weil das Rauchgas kühler abzieht (48 statt
123 °C). Gleichzeitig geht weniger davon ins Wasser. Je **Kilowattstunde Nutzwärme** hebt sich das
auf:

| | nutzbar | Wirkungsgrad | ins Wasser | Verbrauch | Wärmepreis |
| --- | --- | --- | --- | --- | --- |
| Volllast | 11,9 kW | 91,1 % | 84 % | 2,67 kg/h | **10,27 ct/kWh** |
| Minimallast | 3,2 kW | 96,1 % | 56 % | 0,68 kg/h | **10,26 ct/kWh** |

Je **Kilogramm Pellets in den Puffer** dagegen nicht:

| | Pufferwärme je kg |
| --- | --- |
| Volllast | **3,75 kWh** |
| Minimallast | 2,65 kWh, also 42 % weniger |

Welche der beiden Tabellen gilt, hängt daran, ob der Brennstoff knapp ist. Und er ist knapp.

### Das Tagesbudget ist die härteste Schranke

In den Behälter passen **15 kg** (gewogen, nicht geschätzt), und nachgefüllt wird **einmal am Tag,
nie öfter**. Damit ist nicht die Mindestlaufzeit die bindende Grenze, sondern der Brennstoff:

| | |
| --- | --- |
| Tagesbudget | 15 kg = 73,5 kWh Feuerung |
| davon höchstens in den Puffer | **56 kWh**, und das nur bei Volllast |
| Laufzeit bei Volllast | 5,6 h |
| Laufzeit bei kleinster Flamme | 22 h |

Daraus folgt unmittelbar etwas, das die Handregel bereits kennt, ohne es zu benennen: **eine kalte
Nacht von 17 bis 6 Uhr sind dreizehn Stunden, und bei Volllast reicht eine Füllung dafür nicht.** Der
Ofen kommt dort nur durch, weil er von selbst herunterregelt, sobald der Puffer warm ist. Genau
deshalb muss der Planer beide Lastpunkte kennen, auch wenn der Wärmepreis derselbe ist.

### Das Budgetfenster läuft von Füllung zu Füllung

Nachgefüllt wird **morgens, und dann ist der Behälter voll**. Der Planungstag des Ofens beginnt also
nicht um Mitternacht, sondern beim Nachfüllen. Das ist keine Feinheit: wer um 23 Uhr mit einem
vollen Behälter plant, obwohl der seit dem Morgen zu drei Vierteln leer ist, verplant Wärme, die
nicht kommt. `budget_window` liefert das laufende Fenster, `refill_hour` steht in der Konfiguration.

Weil der Behälter jeden Morgen wieder gefüllt wird, ist ein Rest darin **nicht verloren**. Es gibt
also keinen Anreiz, die Füllung noch schnell zu verheizen; nicht verbrauchte Pellets sind schlicht
nicht gekauftes Heizen.

### Wie viel noch im Behälter liegt

Der Ofen meldet keinen Verbrauch, wohl aber seine Leistungsstufe im Minutentakt. Zwischen Stufe 1
(0,68 kg/h) und Stufe 5 (2,67 kg/h) wird linear interpoliert, das ist die einfachste Kurve durch
beide Datenblattpunkte:

| Stufe | 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- | --- |
| kg/h | 0,68 | 1,18 | 1,67 | 2,17 | 2,67 |

`estimated_kg_burned` summiert das über die Minuten je Stufe, `remaining_kg` zieht es von der Füllung
ab. Eine Messung ist es nicht, dafür fehlt der Faktor zwischen Schneckendrehzahl und Kilogramm. Für
die Frage „reicht es noch bis morgen früh?" ist es genau genug.

`daily_budget` liefert die Eckwerte, `buffer_kwh_per_kg` die Kennzahl für die knappe Ressource.

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
* **das Tagesbudget von 15 kg als Nebenbedingung über 24 Stunden**, nicht als Laufzeitgrenze: der
  Planer verteilt eine Füllung über den Tag und muss dabei entscheiden, wann sie am meisten wert ist,
* und die Kostenfunktion mit beiden Preisen statt nur mit dem Strompreis.

Die Raumwärme gehört dabei **nicht** in die Pufferbilanz, sondern in die Kostenseite: sie senkt den
Wärmepreis des Ofens, füllt aber keinen Speicher.

Und weil der Brennstoff das knappe Gut ist, ändert sich die Zielgröße: der Planer minimiert nicht
Kosten je Kilowattstunde, sondern **Kosten je Tag unter einer Brennstoffschranke**. Das ist ein
Rucksackproblem, und es hat eine andere Lösung als der reine Preisvergleich. Eine Stunde Ofen ist
nicht mehr beliebig oft verfügbar, sondern muss sich gegen jede andere Stunde desselben Tages
durchsetzen.

## Bedienung: die untere Leiste

Der Ofen steht in der Steuerleiste des Dashboards neben der Wärmepumpe, mit denselben drei
Schaltflächen: **Auto**, **An**, **Aus**. Damit beide nebeneinander passen, tragen sie kein
ausgeschriebenes Gerätewort mehr, sondern ihr Symbol; die Zeile daneben zeigt den Zustand, der sich
ohnehin dauernd ändert. Der Name steht im Titel des Symbols und in der Vorlesehilfe.

Die Zeile stellt zwei Dinge nebeneinander, die man nicht verwechseln darf:

| | Woher | Beispiel |
|---|---|---|
| **Zustand** | gemessen, aus dem Maestro-Modul | `brennt · Stufe 5` |
| **Absicht** | gesetzt, von Hand oder vom Planer | `manuell an bis 21:00` |

Zwischen Befehl und Feuer liegen Minuten, und beim Abschalten meldet die Firmware die ganze
Ausbrandphase über weiter „läuft". Eine Oberfläche, die beides gleichsetzt, zeigt beim Anheizen
einen Fehler an, wo keiner ist. Deshalb gilt ein Schaltbefehl als gelungen, sobald er beim Ofen
**angekommen** ist; ob er schon umgesetzt wurde, sagt der Zustand.

**An** und **Aus** sind befristet: die kürzeste Wahl sind zwei Stunden, weil darunter mehr Pellets
im Zünden und Ausbrennen verschwinden, als nutzbar in den Puffer gehen. Läuft die Frist ab, fällt
der Ofen auf **Auto** zurück; ein Dauerbefehl, den niemand zurücknimmt, wäre bei einer Feuerstätte
die schlechteste Betriebsart.

**Auto heißt heute: DCH schaltet nicht.** Der Planer kann den Ofen rechnen (das MILP oben), aber er
führt ihn noch nicht; bis dahin regelt der Ofen sich selbst, und die Zustandszeile sagt das auch so.
Das ist die ehrlichere Beschriftung als ein „Auto", das nichts tut und so aussieht, als täte es etwas.

**Zwei Freigaben, nicht eine.** `stove.control_enabled` in der Anlagenkonfiguration entscheidet, ob
die Oberfläche überhaupt Schaltflächen anbietet; `mcz_allow_control` im Add-on entscheidet, ob die
Bridge einen Rahmen an den Ofen schreibt. Beide stehen ab Werk auf aus, und keine davon setzt die
andere. Fehlt eine, sagt die Leiste `nicht freigegeben`, statt einen toten Knopf zu zeigen.

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

**Der Planer führt den Ofen noch nicht.** Das MILP kann ihn (zweite Schaltvariable, Startkosten,
Rucksackbedingung über das Tagesbudget), aber die Live-Runtime ruft es nicht mit Ofenparametern auf.
Bis dahin ist `Auto` eine Freigabe an den Ofen selbst und keine Führung durch DCH. Das ist der
nächste Schritt, und er ist der einzige, der die Rechnung oben in Betrieb bringt.
