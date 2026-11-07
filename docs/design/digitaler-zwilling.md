# Digitaler Zwilling des Hauses

Status: Entwurf, 2026-11-08. **Umsetzungsstand:** Schritt 1 und 2 der Reihenfolge sind gebaut, die
Ablage der Prognoseläufe und die Reihe für die Vorlauftemperatur. Dazu gibt der Fahrplan seit dem
07.11.2026 seine Eingänge mit heraus - Wärmebedarf, Pufferverlauf, Außentemperatur und COP je
Viertelstunde -, und die Seite `/waerme/fahrplan` zeigt sie als Zeitreihen. Seit dem 08.11.2026
wird das Archiv auch **gelesen**: `GET /forecast/history` hält jeden abgelegten Lauf einzeln gegen
die Messung und sortiert den Fehler nach dem Abstand zur Lieferung. Das ist die erste Hälfte der
Nachbetrachtung aus Abschnitt 9 - die Prognoseseite, noch nicht die Geldseite. Alles andere nicht. Dieses Dokument hält das
Ergebnis einer Entwurfsbefragung fest, 33 Entscheidungen, jede mit ihrem Grund und, wo es einen
gibt, mit dem Gegenargument.

Ergänzt [prognose-und-waermemodell.md](prognose-und-waermemodell.md), das die PV-Seite und die
Modellstufen beschreibt. Was dort für PV entschieden ist, gilt hier weiter; neu ist die Wärmeseite,
die Optimierung über beide Erzeuger und die Nachbetrachtung in Euro.

## 1. Was der Zwilling ist

Ein Modell des Hauses, das 48 Stunden voraus weiß, welche Wärme wann gebraucht wird und welcher
Strom wann erzeugt wird, daraus einen Fahrplan für Wärmepumpe und Pelletofen rechnet und sich
hinterher an der Wirklichkeit messen lässt.

Was er **nicht** ist: ein Umbau der Regelung. Der Regler, die Schutzschichten und die Buchhaltung
bleiben, wie sie sind. Der Zwilling setzt sich darüber.

## 2. Die Stellgrößen, und warum sie asymmetrisch sind

Das ist der Befund, der den ganzen Entwurf prägt, und er stand vorher an keiner Stelle zusammen.

**K1 ist eine Anforderung, keine Sperre.** Der potenzialfreie Kontakt sagt der Wärmepumpe „erzeuge
mehr Wärme". Er trennt sie nicht, er hält sie nicht an, und offen heißt „die Wärmepumpe regelt
selbst weiter" (`config/entities.home.yaml`, bestätigt am 06.09.2026). Ob die Maschine der
Anforderung folgt, entscheidet ihre eigene Kennlinie.

**K2 wäre die Sperre und existiert praktisch nicht.** Im Code konstant `False`
(`control/heat_pump_controller.py`), per `BlockRuleConfig.enabled` aus, und am Gerät nicht
verdrahtet (`docs/OPEN_QUESTIONS.md`).

**Was K1 physikalisch auslöst, hat nie jemand gemessen.** Sollwertanhebung, Warmwasserladung, um
wie viel Kelvin, wie lange sie nachläuft: im Projektplan seit September als offene Frage 25.8.
Beide Reihen, `hp_release_contact` und `heat_pump_power_kw`, liegen minütlich und dauerhaft in
`measurements_minute`. Eine Auswertung gibt es nicht.

**Die zweite Stellgröße wirkt verlässlich.** Der Controme-Raumsollwert wird seit dem 23.10.2026
geschrieben, 5 bis 30 Grad, auf Zehntel gerundet, mit Deckel 1,5 K, Schonfrist 10 Minuten,
Fenstersperre und zwölf Stunden Rückzug nach einem menschlichen Eingriff.

Daraus folgt der Satz, der das Vorhaben begrenzt: **den Lauf der Wärmepumpe von 6 bis 8 Uhr kann
Duck Curve Home nicht verhindern, nur unnötig machen.** Vorheizen ist deshalb nicht eine Strategie
unter mehreren, sondern die einzige verfügbare.

## 3. Die zwei Speicher, und welcher der verlässliche ist

Gerechnet aus den Werten in `domain/config.py`.

**Das Gebäude.** `capacity_kwh_per_k` ist tau mal H, also 25 h mal 0,22 kW/K und damit 5,5 kWh je
Kelvin. Bei voll ausgereiztem Hebel von 1,5 K sind das **8,25 kWh**.

**Der Puffer.** 1000 Liter, nutzbar von 35 bis 62 Grad, das sind **31,4 kWh**; vom Zielwert 50 Grad
abwärts bis 35 noch **17,4 kWh**. `comfort_min_top_c` von 42 Grad begrenzt die Entnahme oben,
insofern ist das eine Obergrenze.

**Der Wärmebedarf** nach `accounting/heat.py` ist 0,22 kW/K mal Temperaturdifferenz minus 0,4 kW
innere Gewinne, also 4,22 kW bei 0 Grad außen und 5,76 kW bei minus 7 Grad.

| Reichweite | bei 0 °C | bei -7 °C |
| --- | --- | --- |
| Gebäude, 1,5 K voll ausgereizt | 1,96 h | 1,43 h |
| Puffer, 50 auf 35 °C | 4,13 h | 3,03 h |

Ein Morgenfenster von zwei Stunden braucht 8,4 kWh bei 0 Grad und 11,5 kWh bei minus 7.
**Das Gebäude allein deckt es gerade an einem milden Morgen und an einem kalten gar nicht.** Der
Puffer deckt es. Den Puffer lädt aber K1, also die Anforderung, die der Regler bewerten darf.

**Der verlässliche Hebel ist der kleine, der große Hebel ist der unvermessene.** Damit ist die
K1-Auswertung keine Vorarbeit unter mehreren, sondern die Frage, ob das Morgenbeispiel lösbar ist.

## 4. Zielfunktion und Komfort

Ziel ist **Geld**. Komfort ist eine **harte Grenze**, nicht ein Strafterm.

Die Grenze hängt an der Hausgröße, nicht am einzelnen Raum: das Modell ist einzonig, ein R und ein
C für das ganze Haus, Raumanteil nach Anzahl der Heizkreise, und es kennt nach eigener Aussage
keine Himmelsrichtung, keine Sonne durchs Fenster und keine offene Tür (`thermal/room_shift.py`).
Eine harte Grenze je Raum wäre Scheingenauigkeit: der kälteste Raum würde sie reißen, und das
Modell hätte es nicht gemerkt. Räume werden **ausgewiesen**, nicht garantiert. Je Raum garantiert
wird erst, wenn das Modell zoniert ist.

Die Grenze ist **1,0 Kelvin** unter Ziel. 0,5 K liegt innerhalb der eigenen Unsicherheit des
Modells, denn H ist eine Schätzung, und die Grenze würde an Rauschen binden. 1,5 K ist genau die
Reichweite des Hebels, es bliebe kein Spielraum für Modellfehler.

**Ist der Tag unlösbar, gilt Hände weg.** Keine Anforderung, keine Anhebung, also genau der Zustand
des Hauses von vor Duck Curve Home. Keine Relaxationsleiter. Der Preis dieser Wahl: an unlösbaren
Tagen entsteht keine Zahl dafür, was der Komfort gekostet hätte. Der Tag zählt in den Summen mit
den tatsächlichen Kosten der Hausregelung, der Zwilling gewinnt und verliert dort also nichts, und
in der Detailansicht bekommt er trotzdem die Perfect-Foresight-Linien, damit „der Tag war
unmöglich" von „ich habe ihn falsch vorhergesehen" unterscheidbar bleibt.

## 5. Das Modell und was gelernt wird

**Graubox.** Kein Reinforcement Learning: ein Haus, eine Heizperiode, und der Simulator wäre genau
das Modell, das gelernt werden soll. Die Begründung in
[prognose-und-waermemodell.md](prognose-und-waermemodell.md) Abschnitt 2.1 gilt hier unverändert.

Gelernt werden **zwei Zahlen**: der Verlustkoeffizient H und ein Gütegrad für die Wärmepumpe.

### 5.1 Der COP als Carnot mal einen Gütegrad

Die heutige Kennlinie in `HeatDemandConfig` hat vier Punkte. Gegen den Carnot-COP gerechnet, bei
35 Grad Vorlauf:

| Außen | COP laut Kennlinie | Carnot | Gütegrad |
| --- | --- | --- | --- |
| -7 °C | 2,4 | 7,34 | 0,33 |
| 2 °C | 3,0 | 9,34 | 0,32 |
| 7 °C | 3,5 | 11,00 | 0,32 |
| 15 °C | 4,2 | 15,41 | 0,27 |

Die Kennlinie ist über ihren ganzen Nutzbereich ein konstanter Anteil von Carnot und weicht nur am
mildesten Punkt ab, und der liegt auf der Heizgrenze von 15 Grad, wird also kaum gefahren. Mit
40 Grad Vorlauf gerechnet verschiebt sich der Wert auf 0,36, die Konstanz bleibt. Diese Rechnung
ist aus den vier Punkten abgeleitet und hängt an der angenommenen Vorlauftemperatur; sie ist keine
Messung.

Ein Parameter reproduziert drei von vier Punkten auf zwei Prozent. Die Ein-Parameter-Form verliert
gegenüber der Kennlinie also nichts, sie **ist** die Kennlinie, und sie nimmt die Vorlauftemperatur
über Carnot auf, statt eine zweite Dimension zu brauchen. Eine zweidimensionale Tabelle hätte bei
der zu erwartenden Datenlage viele leere und wenige überbesetzte Zellen. `thermal/heat_balance.py`
rechnet die Carnot-Skalierung über die Senkentemperatur mit `cop_for` und `MIN_LIFT_K` bereits; die
Wärmebedarfsprognose benutzt sie nicht. Es muss also nichts erfunden, sondern das Vorhandene an die
Stelle der flachen Kennlinie gesetzt werden. Die Kennlinie bleibt der Startwert, damit am ersten
Tag nichts springt. Eine zweite Dimension kommt erst, wenn sich der Gütegrad am Residuum als
außentemperaturabhängig erweist, und das ist dann eine Messung und keine Entwurfsentscheidung.

Dafür wird die Vorlauftemperatur gebraucht. In Home Assistant existiert eine Entität
`vorlauf_temperature` (`docs/HA_EXPORT.md`), und sie ist in `config/entities.home.yaml` nicht
zugeordnet. Das ist eine Zeile Konfiguration und unabhängig von allem anderen der erste Schritt.

### 5.2 Der Kreisschluss, und wie er gebrochen wird

H soll aus beobachteter Raumtemperatur gegen eingebrachte Wärme gelernt werden. Es gibt aber keinen
Wärmemengenzähler. Die Wärme der Wärmepumpe wird als Strom mal COP aus einer Kennlinie gerechnet,
und diese Kennlinie ist selbst eine Schätzung. **Ein Fehler in der Kennlinie erscheint als Fehler
in H und umgekehrt.** Eine Lernschleife, die beide gleichzeitig anpasst, schiebt sie gemeinsam in
eine falsche Richtung und sieht dabei immer besser aus.

Gebrochen wird das mit dem Ofen. In Stunden, in denen **nur** der Ofen läuft, ist die eingebrachte
Wärme ohne COP-Annahme bekannt: sie folgt aus Leistungsstufe und Datenblatt, und `stove_cost.py`
weist nach, dass diese Kette vorwärts und rückwärts auf ein halbes Prozent mit dem Datenblatt
zusammenfällt. Das ist die einzige Anregung im Bestand, die H ohne COP-Annahme sichtbar macht.

Die Einschränkung gehört dazu: solche Stunden gibt es nur im Winter und nur, wenn der Ofen allein
fährt. Daraus wird ein langsamer Lernvorgang über eine Heizperiode, keine tägliche Korrektur. Der
Wärmemengenzähler aus der Einkaufsliste (`docs/SENSORIK.md`, Landis+Gyr UH50 im Rücklauf der
Wärmepumpe) macht aus dem langsamen einen schnellen. Er ist damit besser begründet, als auf der
Einkaufsliste bisher steht.

### 5.3 Wie vorsichtig gelernt wird

Mit der Disziplin des PV-Korrektors (`forecasting/evaluation.py`): EWMA-Dämpfung, harte Grenzen,
eine Mindestzahl an Lerntagen, eine Obergrenze für die Änderung je Tag. Die Grenzen sind eigene,
die Form ist dieselbe.

Dämpfung ist hier keine Bequemlichkeit. Solange die Wärme nicht gemessen wird, ist die
Identifikation nach 5.2 nicht sauber getrennt, und eine ungedämpfte Anpassung wandert, mit stetig
besser aussehenden Kennzahlen. Im ersten Winter kommt ein Mensch dazu: Vorschläge werden angezeigt
und übernommen, nicht automatisch wirksam, solange die Zahl auswertbarer Ofenstunden klein ist.

## 6. Die Richtung der Wärmerechnung

Heute gilt `Wärme = Strom mal COP(Kennlinie)`. Mit einer Messung gilt `COP = Wärme / Strom`. Das ist
nicht dieselbe Formel umgestellt, es ist eine umgekehrte Abhängigkeitsrichtung, und davon hängt ab,
ob die Ankunft eines Zählers eine Konfigurationsänderung oder ein Umbau ist.

Deshalb wird jetzt umgedreht: **die gelieferte Wärme ist die beobachtete Größe** mit
Qualitätsvermerk, die Kennlinie ist der Ersatzwert, wenn keine Beobachtung vorliegt, und der COP
ist von da an ein Ergebnis und kein Eingang. Je Stunde wird vermerkt, auf welcher Grundlage sie
gerechnet wurde, nach dem Muster von `EnergyHour.coarse_minutes`. Ohne diesen Vermerk wechselt die
Jahresauswertung mitten in der Heizperiode still die Grundlage.

**Die Vergangenheit wird nicht neu gerechnet.** Beim Eigenverbrauch des Speichergeräts war das
richtig, weil die Korrektur eine Funktion von Eingangsdaten war, die vorlagen, und die Bücher
beweisbar falsch waren. Hier entsteht ein Eingang, den es vorher nicht gab, und die alten Stunden
waren nicht falsch, sie waren unsicher. Die Bücher bleiben stehen; eine mit der Messung geeichte
Fassung steht als Auswertung daneben. Sonst würde jede künftige Verbesserung der Kennlinie die
Bücher wieder bewegen, und dann vergleicht die Nachbetrachtung zwei Größen, die sich beide
verschieben.

Die Wochen, in denen Schätzung und Messung gleichzeitig laufen, sind der einzige Zeitpunkt, an dem
sich je messen lässt, **wie falsch** die Schätzung war. Diese Zahl begrenzt rückwirkend alles, was
vorher über das Haus geschlossen wurde. Beides läuft deshalb eine Heizperiode lang parallel.

### 6.1 Zum Bus

`docs/SENSORIK.md` hat dazu eine Überschrift, die wörtlich „Warum kein Bus hilft" lautet. Der
Regler ist ein Siemens RVS 61.843, also BSB/LPB, und BSB-LAN schließt die Split-Baureihe namentlich
aus. eBUS ist nicht BSB, nicht elektrisch und nicht im Protokoll; ein eBUS-Adapter kommt an einen
Siemens-RVS nicht heran. Der dokumentierte Weg zur Wärmemenge ist der Zähler über M-Bus.

Und falls doch eine Busverbindung zustande kommt: entscheidend ist, **was** sie liefert. Eine
intern gerechnete Wärmemenge aus Verdichtermodell und Temperaturen ist keine Messung, sondern das
Modell des Herstellers. Für den Kreisschluss aus 5.2 hilft sie nicht, sie tauscht nur die eigene
Schätzung gegen eine fremde.

**Nachtrag 07.11.2026.** Der Hausherr hat einen eBUS Adapter Shield C6 gekauft und erwartet, damit
auslesen und stellen zu können. Ob er den Siemens-Regler erreicht, entscheidet der Versuch; das
Obige bleibt der dokumentierte Stand, bis jemand ihn gemacht hat. **Gelingt es und kann der Adapter
wirklich stellen, verschiebt das eine der 33 Entscheidungen:** die Vorlauftemperatur wird zur
Stellgröße, der COP damit zur Entscheidungsvariablen, und aus Q2 (b) wird der in Q2 genannte
Zielzustand (c). Die harte Grenze aus Abschnitt 4, der Fahrplan aus Abschnitt 7 und die
Nachbetrachtung aus Abschnitt 9 bleiben davon unberührt; was sich ändert, ist allein der Satz in
Abschnitt 2, dass es keine stellbare Temperatur gibt. Die Rechnung in 5.1 ist darauf vorbereitet:
sie nimmt die Vorlauftemperatur über Carnot auf und braucht dafür keine zweite Dimension.

## 7. Der Fahrplan

Stellgrößen sind K1 und der Raumsollwert. K2 wird nicht verdrahtet: der Projektplan führt es selbst
mit Risiko hoch, die Fehlerfolge ist ein auskühlendes Haus, und eine harte Sperre auf einem Modell
mit zwei geschätzten Parametern ist der falsche Zeitpunkt. K2 wird interessant, wenn das Modell
belegt ist.

**Geplant wird ideal, die Schutzregeln beschneiden bei der Ausführung.** Schonfrist,
Mindestlaufzeit, Mindestauszeit, höchstens acht Starts am Tag, Failsafe bei vier Schaltwechseln in
der Stunde. Die Beschneidung wird als eigene Kostenzeile ausgewiesen.

Diese Zeile braucht einen Maßstab, denn „was die Schonfrist gekostet hat" ist keine Beobachtung,
sondern eine Differenz. Der Maßstab ist **ein zweiter, regelkonformer Löserlauf**. Damit wird der
regelkonforme Plan ohnehin gerechnet, nur als Maßstab statt als Fahrplan; das ist der Preis dieser
Wahl und er beträgt einen Löserlauf. Eine unterdrückte Schalthandlung einzeln zu bepreisen wäre
nicht billiger: um sie zu bewerten, müsste man wissen, welche Wärme sie gebracht hätte, und das ist
genau ein Modelllauf.

**Der rollierende Plan rechnet immer vom gemessenen Zustand aus**, nicht von seinem eigenen vorigen
Plan. Damit braucht der Ausfall geplanter Ofenstunden keinen eigenen Mechanismus: war der Ofen
geplant und lief nicht, ist der Puffer kälter als vorhergesagt, und der nächste Lauf sieht das und
handelt. Die Puffertemperatur ist der Rückkanal.

**Die alte Vorheizregel entfällt.** `thermal/shift_plan.py` entscheidet heute dasselbe zustandslos
und allein nach Preis, mit 0,5 K, drei Stunden Vorlauf und 5 Cent Mindestspreizung. Zwei Regeln,
die denselben Sollwert stellen, erzeugen einen Fehler, der sich nicht nachstellen lässt, und in
diesem Haus wird jede Sollwertänderung mit Urheber protokolliert; „Automatik" wäre dann zwei
verschiedene Dinge.

## 8. Der Ofen

**An und aus, keine Modulationsvariable.** Das ist keine Vereinfachung, sondern das Ergebnis aus
`stove_cost.py`: je Kilowattstunde Nutzwärme kosten Volllast und Minimallast dasselbe, 10,27 gegen
10,26 ct. Je Kilogramm in den Puffer aber 3,75 gegen 2,65 kWh, also 42 Prozent weniger auf kleiner
Flamme. Solange der Brennstoff das knappe Gut ist, ist Volllast immer richtig, und eine
Modulationsvariable im Löser wäre eine Einladung zum Fehler.

**Der Behälter ist die Grenze, nicht der Wintervorrat.** Mehrere hundert Kilo in Säcken halten die
Saison; in den Behälter passen 15 kg, gewogen. `StoveConfig` hält das mit `hopper_kg`,
`refills_per_day` und `refill_hour` schon fest, und der Planungstag des Ofens läuft von Füllung zu
Füllung. Ein Sack sind bei 450 Euro je Tonne 6,75 Euro und bei Volllast rund 56 kWh Pufferwärme in
5,6 Stunden, also in der Größenordnung des Tagesbedarfs an einem kalten Tag. Der Ofen ist damit an
einem teuren Tag nicht die Ergänzung, sondern die Hauptquelle.

**Der Pelletpreis ist eine Einstellung**, gepflegt nach der Bestellung. Keine Rückmeldung über den
Behälterinhalt: die Annahme bleibt, dass ab `refill_hour` 15 kg bereitstehen. Der Preis dieser
Wahl ist, dass der Durchsatz je Leistungsstufe ungeeicht bleibt; die Regelgüte kostet es nach
Abschnitt 7 nicht. **Der Mensch ist kein Stellglied:** der Fahrplan verlangt keine Füllung.

## 9. Die Nachbetrachtung

**Fünf Linien je Tag:**

1. Realität, also was wirklich geschah.
2. Der Plan, bewertet mit den Prognosen von damals, also was er versprochen hat.
3. Derselbe Plan, bewertet mit dem eingetretenen Wetter und Preis, also was er gehalten hätte,
   wenn die Maschine gefolgt wäre.
4. Ein neu gerechneter Plan mit perfekten Eingängen.
5. Die Hausregelung allein als Nulllinie.

Vier Linien hätten nicht gereicht: der Abstand zwischen Plan und Realität hat zwei Ursachen, den
Prognosefehler und den Eingriff der Maschine, und vier Linien werfen sie zusammen. Mit fünf gilt:
2 minus 3 ist der Prognosefehler in Euro, **1 minus 3 ist der Eingriff der Wärmepumpe in Euro**,
und 3 minus 4 ist, was bessere Prognosen noch wert wären.

**Perfect Foresight zweimal:** einmal mit perfekten Eingängen und dem heutigen Modell, einmal mit
perfekten Eingängen und einem auf den eingetretenen Tag gefitteten Modell. Der Abstand zwischen
diesen beiden ist, was das Modell wert ist, getrennt von dem, was die Prognose wert ist. Das sind
zwei zusätzliche Löserläufe am Tag und das eigentliche Messinstrument der Lernschleife.

**Gebaut ist davon der Teil vor dem Geld** (08.11.2026): der Rückblick auf `/system` beantwortet
die Frage, um wie viel die Prognose besser wird, je näher die Lieferung kommt, in der Einheit der
jeweiligen Größe. Für den Wärmebedarf geht das nur über die Temperatur - beide Seiten der Probe
laufen durch dasselbe Bedarfsmodell, sodass das Modell herausfällt und der Prognosefehler übrig
bleibt. **Was das nicht sagt, ist, wie gut das Modell ist**; dafür fehlt weiterhin die Messung der
Wärme (Abschnitt 5.2). Die fünf Linien in Euro brauchen zusätzlich die Löserläufe und bleiben
Schritt 9.

Abgeschlossen wird **der Tag**, nach Mitternacht, wie es die PV-Bewertung schon tut; die
Einzelläufe bleiben für die Detailansicht erhalten. Wärmepumpe und Ofen stehen in **einer**
gemeinsamen Wärmerechnung; sobald die Wärmepumpenwärme gemessen ist, bleibt ihre Linie sauber, auch
wenn der Ofen in derselben Summe steckt.

**Eine Nachbetrachtung, nicht zwei.** Die PV-Bewertung auf `/system` geht als Eingang darin auf.
Das ist nicht Ordnungsliebe: ein Fehler in der PV-Prognose verursacht einen Teil des Kostenfehlers
des Wärmeplans, weil zu wenig Sonne mehr Netzbezug zum Marktpreis bedeutet, und zwar in genau den
Stunden, in denen der Plan die Wärmepumpe laufen lässt. Stehen Kilowatt und Euro nebeneinander,
lässt sich dieser Anteil nicht zuordnen und die fünf Linien verlieren ihre Trennschärfe.
`accounting/counterfactual.py` beantwortet eine engere Frage, nämlich ob dieselben
Kilowattstunden billiger zu haben gewesen wären; es wird von Linie 4 abgelöst und bleibt nicht als
zweite Wahrheit stehen.

## 10. Was gespeichert wird

Bis zum 07.11.2026 wurde **kein** Prognoselauf aufbewahrt. Die Wettervorhersage lag im
Arbeitsspeicher des `ForecastService`, die PV-Läufe hielt der `ForecastEvaluator` 60 Stunden, und
die Tabellen `forecast_runs` und `forecast_points` lagen seit der Grundmigration da, mit `kind` für
weather, pv und price, ohne dass Anwendungscode sie je beschrieben hätte.

Daraus folgt die unangenehmste Konsequenz des ganzen Vorhabens: **die Nachbetrachtung ist für die
Vergangenheit nicht nachholbar.** Linie 2 braucht die ursprüngliche Prognose, und die gibt es für
keinen einzigen Tag mehr. Jeder Tag ohne diese Speicherung ist ein dauerhaft verlorener Lerntag.
Deshalb steht sie in der Reihenfolge vorn, vor allem anderen.

Aufbewahrt werden **alle Läufe 30 Tage**, dazu **ein kanonischer Day-ahead-Lauf je Tag für immer**.
Die 30 Tage reichen, um die rollierende Verbesserung anzusehen, und seit dem 08.11.2026 wird sie
auch angesehen: der Rückblick liest alle Läufe eines Fensters und nicht nur den kanonischen, denn
die Frage nach der Verbesserung braucht mehrere Läufe über demselben Intervall; der Day-ahead-Lauf ist der
Lernbestand. Zur Größenordnung: 48 Stunden im Viertelstundenraster sind 192 Punkte je Reihe und
Lauf, bei einem Lauf je Viertelstunde und sechs Reihen rund 110.000 Zeilen am Tag und 40 Millionen
im Jahr; mit einem Wiederholungsfilter auf dem Lauf bleibt davon ein Bruchteil, weil die Anbieter
nur stündlich und halbstündlich neue Daten liefern.

## 11. Struktur

Ein neues Teilpaket `hems_core/twin/`. `hems_core` hat heute elf Teilpakete und drei
Vertragsregeln, und **keine davon ordnet die Teilpakete untereinander**; die Teile des Zwillings
liegen in vier von ihnen. Dazu kommt deshalb ein Schichtenvertrag für den Import-Linter:

* `twin/` darf `domain/`, `thermal/` und `forecasting/` nutzen.
* `planning/` darf `twin/` nutzen, nicht umgekehrt: der Löser ist Werkzeug, das Modell ist
  Gegenstand.
* **`accounting/` bleibt von `twin/` getrennt.** Die Buchhaltung schreibt auf, was war. Dürfte sie
  das Vorhersagemodell importieren, änderten sich die Kosten von gestern, sobald das Modell besser
  wird, und dann bewegen sich in der Nachbetrachtung beide Seiten des Vergleichs.

Der Vertrag ist dabei das Wichtigere am Teilpaket. Ein eigenes Paket neben `hems-core` wäre
schlechter: ein zweites `pyproject`, eine zweite Testsammlung und eine Versionsgrenze zwischen zwei
Dingen, die in fast jedem Commit gemeinsam geändert werden. `thermal/` und `forecasting/` wandern
nicht hinein; der Umzug von vierzehn Modulen entwertete jeden `git blame` auf der Wärmeseite, ohne
etwas zu bringen, das der Vertrag nicht auch ohne Umzug bringt.

## 12. Anzeige

**Das Haus-Schema mit einem Zeitschieber.** Das Schema aus `components/anlage/Schema.tsx` steht und
muss an den Zwilling angeschlossen werden; neu ist, dass man durch die nächsten 48 Stunden ziehen
kann und den vorhergesagten Zustand sieht, Räume, Puffer, Flüsse, dazu die Zahlen an jeder
Position. Ein Haus, durch dessen nächste zwei Tage man scrubben kann, ist das bessere Bild als ein
Diagramm, und es zeigt die Prognose, die sonst keine Darstellung hätte.

Der Vergleich der fünf Linien gehört in den Rückblick auf eine Berichtsseite, nicht in das
Jetzt-Bild.

## 13. Schattenbetrieb und sein Ende

Schatten zuerst, aber gestuft, denn die beiden Stellgrößen sind unterschiedlich gut verstanden.

**Der Raumsollwert wird gestellt.** Der Schreibweg ist seit dem 23.10.2026 in Betrieb, die
Automatik darüber nur standardmäßig abgeschaltet, das Wirkungsmodell existiert in `room_shift`, und
die Schutzregeln sind reichlich.

**K1 bleibt im Schatten**, bis die Auswertung aus Abschnitt 2 zeigt, was der Kontakt auslöst. Blind
darauf zu stellen würde die Nachbetrachtung mit einer unbekannten Größe verunreinigen, und zwar in
genau der Linie, an der das Gebäudemodell beurteilt werden soll. `heat_pump_actuation_enabled` ist
ein Schalter und keine Arbeit.

## 14. Reihenfolge

1. ~~**Prognoseläufe speichern.**~~ Gebaut am 07.11.2026: `hems_core.forecasting.archive` sagt,
   was ein Lauf ist, die Laufzeit legt bei jeder Auffrischung ab, und das Aufräumen behält je
   Ortstag einen kanonischen. Einzelheiten in [DATENHALTUNG.md](../DATENHALTUNG.md).
2. ~~**Vorlauftemperatur einrichten.**~~ Gebaut am 07.11.2026: die Reihe `flow_temp_c` steht in
   der Minutentabelle und im Anlagenschema, die Zuordnung liegt einkommentierfertig in
   `config/entities.home.yaml`. Gefüllt ist sie noch nicht.
   Nachgezogen am 07.11.2026: `plan_stove` gibt die Eingänge des Modells mit heraus, `PlanOut`
   trägt sie je Viertelstunde, die Seite „Fahrplan" zeichnet sie. Der Wärmebedarf steht damit als
   Zeitreihe da, bevor er gemessen wird - als Modell v1, und die Seite sagt das auch.
3. **K1-Wirkung auswerten**, Kontaktzustand gegen Wärmepumpenleistung, aus dem vorhandenen Bestand.
4. Teilpaket `twin/` und Schichtenvertrag.
5. Wärme als beobachtete Größe, COP als Ergebnis, Carnot mal Gütegrad.
6. Der COP in den Löser: `planning/milp.py` rechnet heute mit festen Nennwerten.
7. Harte Komfortgrenze 1,0 K mit Rückfallebene.
8. Raumsollwert stellen, K1 im Schatten.
9. Nachbetrachtung: fünf Linien, zwei Perfect-Foresight-Läufe, Kostenzeile der Beschneidung.
   Vorgezogen am 08.11.2026: die Prognoseseite davon steht - Fehler je Reihe und je
   Vorlaufzeit aus dem Archiv, auf `/system`. Offen bleibt alles, was Euro sagt.
10. Zeitschieber am Schema.
11. Lernen: H aus Ofenstunden, Gütegrad, Dämpfung, menschliche Durchsicht im ersten Winter.
12. `shift_plan` entfernen.

## 15. Grenzen und offene Punkte

* **Was K1 auslöst, ist unbekannt.** Projektplan 25.8, offen seit September. Darauf ruht die
  Vollmacht des Fahrplans.
* **H und tau sind Schätzungen.** 0,22 kW/K und 25 h, laut `docs/SENSORIK.md` „nie mit der
  Wirklichkeit abgeglichen".
* **Die Aufstellraumtemperatur des Puffers ist nicht gemessen**, der Verlustterm rechnet gegen die
  Annahme 17 Grad.
* **Der Hebel im Gebäude ist knapp.** 8,25 kWh gegen 8,4 kWh Bedarf im Morgenfenster bei 0 Grad.
* **Die Raumhistorie beginnt am 22.10.2026**, Fensterkontakte am 23.10.2026. Für ein Mehrzonenmodell
  gibt es heute fast keine Daten.
* **Die Wettervorhersage wird nicht historisiert**, siehe Abschnitt 10. Bis Schritt 1 läuft, wächst
  der Verlust weiter.
* **Der Behälterinhalt bleibt Annahme**, der Durchsatz je Leistungsstufe ungeeicht.

Nebenbei gefunden, nicht Teil dieses Entwurfs: `HEMS_CONTROL.md` behauptet, jeder Schaltbefehl
trage den Auto-Off-Timer, der aber nur auf dem MQTT-Weg übersetzt wird, während K1 zwingend über
Home Assistant ohne TTL läuft; das Auffrischintervall steht einmal mit 10 Minuten und einmal mit
10 Sekunden, und der Code sendet nach 15 Minuten nach; und der Projektplan sieht ein Schalten von
K1 aus dem Dashboard vor, das der Code verweigert.
