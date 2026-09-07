# Datenhaltung

Was wird in welcher Auflösung wie lange behalten — und warum.

## Stufen

| Stufe | Tabelle | Auflösung | Aufbewahrung | Größe |
| --- | --- | --- | --- | --- |
| Rohwerte | `measurements_raw` | so fein wie die Quelle liefert (Shelly über MQTT ~10 s) | 14 Tage (`DCH_RAW_RETENTION_DAYS`) | ~300–400 MB im Dauerzustand |
| Minutenmittel | `measurements_minute` | 1 Minute | **dauerhaft** | ~95 MB je Jahr |
| Stundenbilanz | `energy_hourly` | 1 Stunde | **dauerhaft** | ~3,5 MB je Jahr |
| Live-Zustand | `live_state` | nur der letzte Wert | eine Zeile je Reihe | konstant |

Rohwerte sind Arbeitsmaterial: aus ihnen entstehen die Minutenmittel, und sie erlauben es, eine Stunde
neu zu bilanzieren, wenn Messwerte verspätet eintreffen. Nach 14 Tagen werden sie gelöscht — was
bleibt, steht dann in der Minutentabelle.

Alles unterhalb der Stunde, das dauerhaft interessiert, liegt in `measurements_minute`. Nichts wird
dort je gelöscht.

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
(JSON), damit sie nicht stillschweigend verlorengeht — von dort kann sie jederzeit zu einer eigenen
Spalte befördert werden. Die Spaltenliste ist an `infrastructure.history.SERIES` gekoppelt, ein Test
hält beides zusammen.

## Der Verdichtungslauf

`LiveRuntime._rollup_loop` läuft alle fünf Minuten und schreibt abgeschlossene Minuten fort:

* Aufgeholt wird ab der letzten verdichteten Minute, fünf Minuten überlappend. Rohwerte tragen den
  Zeitstempel ihrer Quelle und können einer bereits verdichteten Minute nachträglich zufallen;
  erneutes Verdichten ersetzt die Zeile, es entsteht nichts doppelt.
* Die laufende Minute bleibt aus — ihr Mittelwert wäre noch unvollständig.
* Beim ersten Lauf wird tageweise über die vorhandenen Rohwerte aufgeholt, damit daraus keine
  einzelne riesige Abfrage wird.
* Das stündliche Housekeeping verdichtet **vor** dem Löschen noch einmal. Andersherum verschwänden
  Rohwerte, deren Minute noch nicht im Bestand steht — und die wären dann für immer weg.

`minute_series()` liest beide Quellen und führt sie zusammen: der dauerhafte Bestand reicht beliebig
weit zurück, endet aber am letzten verdichteten Bin; die Minuten danach stehen nur in den Rohwerten.
Bei Überschneidung gewinnt der verdichtete Wert.

## Was das ermöglicht

* Ein Tagesverlauf von vor zehn Jahren zeigt weiterhin Minutenwerte, nicht nur ein Stundenmittel.
* `EnergyAccounting.recompute` kann jeden beliebigen Zeitraum neu bilanzieren, nicht mehr nur die
  letzten 14 Tage. Wenn sich die Rechenregeln ändern — wie zuletzt beim Eigenverbrauch —, lässt sich
  die Historie nachziehen, statt mit einer Lücke zu leben.

## Was noch fehlt

Die Datenbank ist die einzige Kopie. „Für immer" hält nur, was auch gesichert ist: ein Postgres-Volume
bei einem Anbieter ist kein Archiv. Zu klären ist eine regelmäßige Sicherung außerhalb von Railway —
entweder über dessen Backups oder über einen Export der Minutentabelle (ein Jahr sind rund 95 MB, als
komprimiertes CSV deutlich weniger), der irgendwo landet, wo er einen Anbieterwechsel überlebt.

## Preisauflösung

Der Strompreis ist die einzige Reihe, die nicht gemessen, sondern bezogen wird. Seit die Börse im
Oktober 2025 auf Viertelstunden umgestellt hat, kann Tibber vier Preise je Stunde liefern. Die
Auflösung wird nicht angenommen, sondern beim ersten Abruf im GraphQL-Schema erfragt
(`DCH_TIBBER_PRICE_RESOLUTION` leer = feinste angebotene); das Log schreibt beim Start, welche
gewählt wurde und welche das Schema anbietet.

In der Speicherung ändert das nichts — der Preis liegt ohnehin je Minute vor. Es ändert etwas für
den Planer, der auf einem 15-Minuten-Raster rechnet: er liest den Preis jetzt aus dem Preispunkt,
der das Intervall überdeckt, statt aus dem der vollen Stunde.

## Sonstige Tabellen

Dauerhaft, aber ereignisgetrieben und damit klein: Regelentscheidungen (nur bei Zustandswechsel),
Systemereignisse (nur bei Störungen), geprüfte Tibber-Rechnungen, gekoppelte Anzeigegeräte,
Bridge-Sitzungen, Modellkalibrierung. Zusammen einige hundert Zeilen im Jahr.
