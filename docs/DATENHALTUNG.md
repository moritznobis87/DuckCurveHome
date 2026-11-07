# Datenhaltung

Was wird in welcher Auflösung wie lange behalten - und warum.

## Stufen

| Stufe | Tabelle | Auflösung | Aufbewahrung | Größe |
| --- | --- | --- | --- | --- |
| Rohwerte | `measurements_raw` | so fein wie die Quelle liefert (Shelly über MQTT ~10 s) | 3 Tage (`DCH_RAW_RETENTION_DAYS`) | ~70-90 MB im Dauerzustand |
| Minutenmittel | `measurements_minute` | 1 Minute | **dauerhaft** | ~95 MB je Jahr |
| Stundenbilanz | `energy_hourly` | 1 Stunde | **dauerhaft** | ~3,5 MB je Jahr |
| Live-Zustand | `live_state` | nur der letzte Wert | eine Zeile je Reihe | konstant |
| Prognoseläufe | `forecast_runs`, `forecast_points` | 15 Minuten bis 1 Stunde, je Art | 30 Tage (`DCH_FORECAST_RUN_RETENTION_DAYS`), ein kanonischer Lauf je Ortstag **dauerhaft** | ~33 MB im Dauerzustand, dazu ~24 MB je Jahr |

Seit dem 16.09.2026 trägt die Minutentabelle drei weitere Spalten: `grid_power_meter_kw`,
`grid_import_meter_kwh` und `grid_export_meter_kwh`, die Werte des amtlichen Zählers. Sie stehen
**neben** `grid_power_kw` und nicht an dessen Stelle; warum, steht in `SENSORIK.md`.

Rohwerte sind Arbeitsmaterial: aus ihnen entstehen die Minutenmittel. Nach drei Tagen werden sie
gelöscht - was bleibt, steht dann in der Minutentabelle.

Die Frist stand einmal auf 14 Tagen. Gebraucht werden Rohwerte aber nur Minuten: die Verdichtung
läuft alle fünf Minuten, und nachgetragene Minuten aus der myenergi-Historie werden seit demselben
Stand ausdrücklich mitverdichtet, statt nur durch die Stundenrechnung zu laufen. Der Rest war
Vorrat für einen Fall, der nicht eintrat - und `measurements_raw` ist mit Abstand die breiteste
Tabelle: eine Zeile je Messwert statt je Minute, dazu ein Schlüsselfeld, das in jeder Zeile und noch
einmal im Primärindex steht. Bei einer verwalteten Datenbank, die nach Arbeitsspeicher abgerechnet
wird, war das der teuerste Posten im ganzen Programm.

Drei Tage lassen einen Dienst, der zwei Tage stillstand, seine Rohwerte beim Start noch verdichten.

**Löschen gibt den Platz nicht von selbst zurück.** Postgres markiert die Seiten als frei und füllt
sie neu; die Datei bleibt so groß, wie sie einmal war. Wer nach einer Verkürzung der Frist die
Größe wirklich sehen will, braucht einmalig ein `VACUUM FULL measurements_raw` - das sperrt die
Tabelle für die Dauer des Laufs. Die aktuellen Größen stehen in den Einstellungen unter
„Platzbedarf".

Alles unterhalb der Stunde, das dauerhaft interessiert, liegt in `measurements_minute`. Nichts wird
dort je gelöscht.

## Prognoseläufe

Seit dem 07.11.2026 bleiben die Prognosen liegen, die der Dienst holt: Wetter (Temperatur,
Bewölkung, Globalstrahlung), die eigene PV-Rechnung mit ihrem Band und die veröffentlichten Preise.
Die beiden Tabellen gab es seit der Grundmigration, beschrieben hat sie bis dahin nichts.

**Warum überhaupt.** Die Nachbetrachtung des Zwillings fragt, was die ursprüngliche Prognose
gekostet hätte. Das braucht den Lauf von damals und nicht seine Kennzahlen. Wird er nicht abgelegt,
ist die Frage für diesen Tag **für immer** unbeantwortbar; es gibt keinen Weg, eine vergangene
Vorhersage nachträglich zu rekonstruieren. Jeder Tag ohne Ablage ist ein verlorener Lerntag, und
das ist der Grund, warum diese Stufe vor dem übrigen Zwilling gebaut wurde.

**Was ein Lauf ist.** Ein Abruf mit neuem Inhalt. Liefert der Anbieter dieselben Zahlen wie beim
letzten Mal, wird nichts abgelegt; ein Fingerabdruck über den Inhalt entscheidet das. Das wirkt vor
allem bei den Preisen: Tibber wird halbstündlich abgefragt, zwischen 13 und 15 Uhr häufiger, und
veröffentlicht einmal am Tag. Bei der PV-Prognose greift der Filter kaum, weil ihr Raster mit jeder
Auffrischung eine Stunde weiterwandert, und das ist richtig: ein verschobener Horizont ist neuer
Inhalt.

**Was dauerhaft bleibt.** Je Art und Ortstag ein kanonischer Lauf, nämlich der letzte, der um
6 Uhr Ortszeit noch gültig war. Dieselbe Stunde, gegen die `forecast_evaluation` seine Tageswertung
rechnet; zwei verschiedene Begriffe von „der Lauf von gestern" wären eine Fehlerquelle, die niemand
findet. Markiert wird beim Aufräumen, drei Tage rückwärts, damit ein Dienst, der ein Wochenende
stillstand, die versäumten Tage noch erfasst. Gab es an einem Tag keinen Lauf vor dieser Stunde,
bleibt der früheste des Tages: sonst behielte dieser Tag für immer nichts.

**Die Größen sind gerechnet, nicht gemessen.** Wetter stündlich über 72 Stunden sind 216 Zeilen je
Lauf, PV viertelstündlich über 49 Stunden rund 196, bei je 24 Läufen am Tag also etwa 10.000 Zeilen
täglich. Dreißig Tage davon sind rund 300.000 Zeilen, bei geschätzt 110 Byte je Zeile samt Kopf und
Index etwa 33 MB im Dauerzustand. Die kanonischen Läufe wachsen mit rund 600 Zeilen am Tag, also
etwa 24 MB je Jahr. Nachgemessen ist das noch nicht.

## Warum breit statt schmal

Die Minutentabelle hat **eine Zeile je Minute mit einer Spalte je Reihe**, nicht eine Zeile je
Messwert. Postgres schlägt pro Zeile rund 27 Byte Kopf auf, dazu kommt der Indexeintrag. Im schmalen
Format (`sensor_key`, `bucket`, `wert`) zahlt man das für jeden einzelnen Wert:

| Format | Zeilen je Jahr | 10 Jahre |
| --- | --- | --- |
| schmal, eine Zeile je Reihe und Minute | 7,9 Mio | ~9 GB |
| breit, eine Zeile je Minute (15 Spalten) | 525 600 | ~1 GB |

Der Faktor neun ist der Grund, warum Minutenauflösung dauerhaft tragbar ist und eine Verdichtung auf
Viertelstunden nicht nötig war. Er ist auch der Grund, warum `energy_hourly` schon immer breit ist.

Der Preis: eine neue Messreihe braucht eine Migration. Bis dahin landet sie in der Spalte `extra`
(JSON), damit sie nicht stillschweigend verlorengeht - von dort kann sie jederzeit zu einer eigenen
Spalte befördert werden. Die Spaltenliste ist an `infrastructure.history.SERIES` gekoppelt, ein Test
hält beides zusammen.

## Der Verdichtungslauf

`LiveRuntime._rollup_loop` läuft alle fünf Minuten und schreibt abgeschlossene Minuten fort:

* Aufgeholt wird ab der letzten verdichteten Minute, fünf Minuten überlappend. Rohwerte tragen den
  Zeitstempel ihrer Quelle und können einer bereits verdichteten Minute nachträglich zufallen;
  erneutes Verdichten ersetzt die Zeile, es entsteht nichts doppelt.
* Die laufende Minute bleibt aus - ihr Mittelwert wäre noch unvollständig.
* Beim ersten Lauf wird tageweise über die vorhandenen Rohwerte aufgeholt, damit daraus keine
  einzelne riesige Abfrage wird.
* Das stündliche Housekeeping verdichtet **vor** dem Löschen noch einmal. Andersherum verschwänden
  Rohwerte, deren Minute noch nicht im Bestand steht - und die wären dann für immer weg.

`minute_series()` liest beide Quellen und führt sie zusammen: der dauerhafte Bestand reicht beliebig
weit zurück, endet aber am letzten verdichteten Bin; die Minuten danach stehen nur in den Rohwerten.
Bei Überschneidung gewinnt der verdichtete Wert.

## Was das ermöglicht

* Ein Tagesverlauf von vor zehn Jahren zeigt weiterhin Minutenwerte, nicht nur ein Stundenmittel.
* `EnergyAccounting.recompute` kann jeden beliebigen Zeitraum neu bilanzieren, nicht mehr nur die
  letzten Tage. Wenn sich die Rechenregeln ändern - wie zuletzt beim Eigenverbrauch -, lässt sich
  die Historie nachziehen, statt mit einer Lücke zu leben.

## Was die Historie sichtbar macht

Die Jahreskarte (`/jahr`) legt ein Kalenderjahr als Fläche aus: 365 Spalten zu je 24 Stunden. Sie
liest die Stundenbilanz, nicht die Minutenwerte - 8 760 Zeilen je Jahr, unabhängig davon, wie lange
das System schon läuft.

* Die Stundenachse ist **Ortszeit**. In UTC wanderte die Sonne im Bild um eine Stunde, sobald die
  Zeitumstellung kommt. Am Rückstelltag fallen zwei UTC-Stunden auf dieselbe Ortsstunde: Energien
  werden addiert, Preise und Quoten gemittelt. Am Umstelltag im Frühjahr bleibt 02:00 leer.
* Eine fehlende Stunde ist `null`, nicht `0`. Eine Lücke in der Aufzeichnung sähe sonst aus wie eine
  Nacht ohne Verbrauch - die Farbe darf hier nicht lügen.
* Die Farbskala endet beim **98. Perzentil**. Ein einzelner Ausreißer zöge sonst die Skala zusammen
  und färbte das restliche Jahr einheitlich dunkel; der wahre Größtwert steht in der Fußnote.
* Die Rampen sind in OKLab zwischen Markenfarben interpoliert, damit die wahrgenommene Helligkeit
  gleichmäßig steigt. Sequenziell ein Farbton von der Kartenfläche zur Marke; divergierend zwei
  Farbtöne mit neutraler Mitte, gleich große Schritte je Arm und **beide Pole gleich hell**, sonst
  schriee eine Seite lauter. Farbzuordnung wie im Energiefluss: Bernstein = eigene Energie, Mist =
  Netz.

## Sicherung

Die Datenbank ist die einzige Kopie. „Für immer" hält nur, was auch außerhalb liegt: ein
Postgres-Volume bei einem Anbieter überlebt keinen gelöschten Zugang und keinen Anbieterwechsel.

Dafür gibt es zwei Endpunkte, erreichbar nur mit Vollzugriff (für Gäste sperrt sie auch der Proxy):

| Endpunkt | Inhalt | Größe je Jahr |
| --- | --- | --- |
| `GET /api/v1/export/minutes?year=2026` | alle Messreihen je Minute | ~18 MB gepackt (60 MB roh) |
| `GET /api/v1/export/hours?year=2026` | Stundenbilanz samt PV-Abrechnung | wenige hundert KB |

Statt `year` gehen auch `start`/`end` (höchstens 800 Tage je Abruf). Ein Jahr ist das Kalenderjahr in
Ortszeit, wie überall sonst in der Auswertung. Auf der Einstellungsseite stehen die Links für das
laufende und das vorige Jahr.

Format ist gzip-komprimiertes CSV nach RFC 4180 - Komma als Trennzeichen, Punkt als Dezimalzeichen,
leere Felder für fehlende Werte, ISO-8601-Zeitstempel in UTC. Bewusst nicht der deutsche
Excel-Dialekt: das hier soll ein Jahrzehnt und einen Werkzeugwechsel überstehen, und jedes Programm
liest es. Die erste Zeile ist die Kopfzeile; eine Reihe ohne eigene Spalte steht als JSON in `extra`.

Erzeugt wird beides als Strom, seitenweise über den Zeitstempel geblättert und im Vorbeigehen
komprimiert: ein Jahr sind 525 600 Zeilen, die weder der Dienst noch die Antwort gleichzeitig im
Speicher halten.

Die Stundenbilanz gehört zu den steuerlich aufzubewahrenden Unterlagen - sie enthält Eigenverbrauch,
Wiederbeschaffungswert und Umsatzsteuer je Stunde. Ein laufendes Jahr ist unvollständig; für den
Abschluss im Januar erneut holen.

Das ersetzt keine Sicherung der Datenbank selbst (Railways eigene Backups), sondern ergänzt sie um
eine Kopie, die von diesem Anbieter und von diesem Programm unabhängig ist.

## Preisauflösung

Der Strompreis ist die einzige Reihe, die nicht gemessen, sondern bezogen wird. Seit die Börse im
Oktober 2025 auf Viertelstunden umgestellt hat, kann Tibber vier Preise je Stunde liefern. Die
Auflösung wird nicht angenommen, sondern beim ersten Abruf im GraphQL-Schema erfragt
(`DCH_TIBBER_PRICE_RESOLUTION` leer = feinste angebotene); das Log schreibt beim Start, welche
gewählt wurde und welche das Schema anbietet.

In der Speicherung ändert das nichts - der Preis liegt ohnehin je Minute vor. Es ändert etwas für
den Planer, der auf einem 15-Minuten-Raster rechnet: er liest den Preis jetzt aus dem Preispunkt,
der das Intervall überdeckt, statt aus dem der vollen Stunde.

## Sonstige Tabellen

Dauerhaft, aber ereignisgetrieben und damit klein: Regelentscheidungen (nur bei Zustandswechsel),
Systemereignisse (nur bei Störungen), geprüfte Tibber-Rechnungen, gekoppelte Anzeigegeräte,
Bridge-Sitzungen, Modellkalibrierung. Zusammen einige hundert Zeilen im Jahr.
