# Die Nachbetrachtung: ein Tag in Euro

Stand 10.11.2026. Seite `Wärme → Nachbetrachtung`, Endpunkt
`GET /api/v1/plan/nachbetrachtung?day=YYYY-MM-DD`. Bewertung in
`packages/hems-core/src/hems_core/accounting/nachbetrachtung.py`, Zusammenstellung und
Vergleichslauf in `apps/api/src/dch_api/application/nachbetrachtung.py`.

## Die Frage

Der Fahrplan sagt, was vorgesehen ist. Die Wiedergabe zeigt, was geschah. Die Nachbetrachtung
sagt, was der Unterschied gekostet hat und woran er lag: an der Prognose, am Nachführen des
Fahrplans über den Tag, oder an der Maschine, die den Kontakt nur als Anforderung nimmt.

## Die Linien

| Linie | Was sie ist | Woher |
|---|---|---|
| erster Fahrplan, versprochen | Die Kosten, die der Optimierer damals selbst gezählt hat | Fahrplanarchiv, Größe `cost_eur` |
| erster Fahrplan, gehalten | Derselbe Fahrplan, bewertet mit dem eingetretenen Preis und Überschuss | Fahrplanarchiv und Minutenbestand |
| letzter Stand | Für jede Viertelstunde der jüngste Fahrplan, der vor ihr entstand | Fahrplanarchiv |
| wirklich | Der gemessene Strom des Verdichters und der gemessene Ofenbetrieb | Minutenbestand |
| mit perfekter Voraussicht | Ein neu gerechneter Fahrplan, dem der Tag im Voraus bekannt war | Vergleichslauf |
| ohne Preisblick | Dieselbe Strommenge wie gemessen, nach dem Wärmebedarf verteilt. Geschätzt | Rechnung |

**Der erste Fahrplan** ist der letzte Lauf vor der Ortsmitternacht: mit ihm ging das Haus in den
Tag. Gibt es keinen, gilt der erste Lauf des Tages, und der Vergleich beginnt erst mit ihm.

**Die Treppe** führt vom Versprechen zur Wirklichkeit:

    versprochen + Prognosefehler + Nachführen + Eingriff der Maschine = wirklich

Daneben stehen zwei Abstände, die nicht auf dem Weg liegen: was mit perfekter Voraussicht noch zu
holen gewesen wäre (letzter Stand minus Vergleichslauf), und was das Verschieben gegenüber „ohne
Preisblick“ gebracht hat.

## Eine Rechnung für alle

Jede Linie wird mit derselben Rechnung über dieselben Viertelstunden bewertet. Sonst mäße ein
Abstand den Unterschied der Rechnungen oder die Länge der Linien.

* **Der Strom einer Viertelstunde** kostet den Bezugspreis, soweit er aus dem Netz kommt, und die
  entgangene Einspeisevergütung, soweit ihn der Überschuss deckt, anteilig. Der Überschuss ist
  Sonne minus Haus ohne Wärmepumpe; die Wallbox zählt zum Haus.
* **Eine Freigabe im Fahrplan** zählt mit der elektrischen Nennleistung, wie im Modell des
  Optimierers.
* **Der Ofen** kostet je Betriebsstunde, was `stove_eur_per_h` für den eingetretenen Preis und die
  eingetretene Temperatur ergibt: Pellets plus Eigenstrom, abzüglich der angerechneten Raumwärme.
* **Verglichen wird**, wo der Preis bekannt ist, die Leistung in mindestens zwölf der fünfzehn
  Minuten gemessen wurde und der erste Fahrplan etwas sagt. Entstand der erste Fahrplan um 14 Uhr,
  beginnt der Vergleich um 14 Uhr, auch für die Wirklichkeit.
* **Verdichter und Grundlast getrennt.** In die Linie „wirklich“ geht nur der Strom der Minuten
  ein, in denen die Maschine lief (ab `heat_pump.running_threshold_kw`). Der Rest steht daneben;
  er hängt an keinem Fahrplan.

Nur das Versprechen ist keine Nachrechnung. Es steht so im Archiv, wie der Optimierer es zählte,
und der zählt gröber: deckt der Überschuss nicht die ganze Nennleistung, rechnet er den vollen
Bezugspreis. Im Prognosefehler steckt deshalb auch der Abstand zwischen beiden Rechnungen.

## Der Vergleichslauf

Derselbe Planer wie im Betrieb, `plan_stove`, mit den eingetretenen Werten statt der Prognosen:
gemessener Preis, gemessener Überschuss, gemessene Außentemperatur. Er beginnt mit dem gemessenen
Pufferzustand der ersten verglichenen Viertelstunde und sieht so weit, wie Preise gemessen sind,
höchstens 36 Stunden und über die Mitternacht hinaus. Für einen laufenden Tag mit weniger als acht
gemessenen Stunden rechnet er nicht, und die Linie fehlt mit diesem Grund.

Perfekt sind die Eingänge, nicht das Modell. Der Wärmebedarf kommt weiter aus dem Bedarfsmodell,
nur mit der eingetretenen Temperatur.

## Menge und Zeitpunkt

Die Linien liefern nicht dieselbe Wärme. Der Fahrplan plant gegen den Wärmebedarf des Modells und
rechnet jede Freigabe mit Nennleistung; die Maschine heizt nach ihrer eigenen Kennlinie. Ein
Abstand in Euro mischt deshalb zwei Dinge. Zwei Vorkehrungen dagegen:

* **Der Eingriff der Maschine ist zerlegt.** Die Menge ist der Unterschied der Kilowattstunden,
  bewertet zum mittleren Strompreis des Fahrplans; der Rest des Stromabstands ist der Zeitpunkt;
  der Ofen steht für sich. Die drei ergeben zusammen den Eingriff.
* **Neben den Euro steht der mittlere Preis der Kilowattstunde** je Linie. Er hängt nicht an der
  Menge und ist die Zahl, an der sich ablesen lässt, wie gut der Zeitpunkt getroffen war.

Liegen die Strommengen von Fahrplan und Messung um mehr als ein Viertel auseinander, sagen der
Satz über den Tag und ein Hinweis das ausdrücklich. An der Vorführung am 10.11.2026 war das der
Fall: der Fahrplan rechnete mit 27,0 kWh, gemessen waren 12,9 kWh.

## Was aufbewahrt wird

Seit dem 09.11.2026 liegt jeder Fahrplan stündlich im Prognosearchiv (Art `plan`), seit dem
10.11.2026 mit der Größe `cost_eur`: den Kosten je Viertelstunde, wie der Optimierer sie gezählt
hat, ohne die Strafterme der Zielfunktion. Sie stehen nur dort, wo der Optimierer entschieden hat,
nicht wo die Preisregel einsprang.

Für Tage davor fehlen Linien, und die Seite sagt, welche und warum:

| Tag | Fahrplanlinien | Versprechen |
|---|---|---|
| vor dem 09.11.2026 | fehlen | fehlt |
| 09.11.2026 bis zum Neustart mit dieser Fassung | vorhanden | fehlt |
| danach | vorhanden | vorhanden |

Messung, Vergleichslauf und „ohne Preisblick“ gibt es für jeden Tag, für den Minutenwerte
vorliegen.

## Grenzen

* **Der Batteriespeicher kommt nicht vor.** Ob eine Kilowattstunde aus der Batterie kam, ändert
  an dieser Bewertung nichts. Das Modell des Optimierers kennt den Speicher ebenso wenig.
* **„Ohne Preisblick“ ist eine Schätzung.** Was ohne Führung geschehen wäre, weiß niemand. Die
  Linie verteilt die gemessene Menge nach dem Wärmebedarf der eingetretenen Temperatur.
* **Das Bedarfsmodell steht auf zwei geschätzten Hauswerten.** Der Abstand zwischen geplanter und
  gemessener Strommenge misst vor allem dieses Modell, nicht den Fahrplan.
* **Der Endstand des Puffers ist nicht bewertet.** Eine Linie, die den Puffer am Tagesende voller
  hinterlässt, hat für den nächsten Tag vorgearbeitet; in den Euro dieses Tages steht das nicht.
* **Der Ofen ist mit dem heute eingestellten Pelletpreis bewertet**, auch für vergangene Tage.
  Wer den Preis ändert, ändert die Nachbetrachtung rückwirkend.
* **Der Vergleichslauf kennt den Vorrat im Pelletbehälter nicht** und rechnet mit einem vollen.
* **Der Vergleichslauf läuft bei jedem Aufruf neu** und braucht so lange wie ein Lauf des
  Optimierers. Aufbewahrt wird sein Ergebnis nicht; an seiner Zeitgrenze abgebrochen, kann er an
  zwei Aufrufen leicht verschiedene Fahrpläne liefern.
* **Die zwei Perfect-Foresight-Läufe des Entwurfs** (heutiges Modell gegen ein auf den Tag
  gefittetes) gibt es noch nicht; gerechnet wird einer, mit dem heutigen Modell. Der zweite
  braucht die gemessene Wärme (Entwurf Abschnitt 5.2).
* **Geprüft am 10.11.2026** an einem erfundenen Tag, dessen Fahrpläne vom echten Planer stammen,
  und an der Vorführung. Den Bestand des Hauses hat die Seite noch nicht gesehen.
