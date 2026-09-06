# Historie aus Home Assistant exportieren und in Duck Curve Home importieren

Home Assistant speichert im **Recorder** zwei Ebenen: Rohzustände (`states`, standardmäßig nur die letzten
10 Tage, `purge_keep_days`) und **Langzeitstatistik** (`statistics`, Stundenmittel, unbegrenzt; dazu
`statistics_short_term` mit 5-Minuten-Mitteln der letzten ~10 Tage). Für die Bilanz zählt vor allem die
Langzeitstatistik.

## 1. Datenbank finden

- Standard: SQLite unter `/config/home-assistant_v2.db`.
- Wenn in `configuration.yaml` unter `recorder: db_url:` MariaDB/MySQL steht, gelten die Abfragen genauso;
  nur `datetime(x,'unixepoch')` wird zu `FROM_UNIXTIME(x)`.

Ausführen: am einfachsten im Add-on **Advanced SSH & Web Terminal** (Protection Mode aus), dort
`apk add sqlite` falls `sqlite3` fehlt. Alternativ das Add-on **SQLite Web** (Abfrage eingeben, CSV-Export).

## 2. Inventar: welche Entitäten haben Statistik?

```sql
SELECT sm.statistic_id, sm.unit_of_measurement, COUNT(*) AS stunden,
       datetime(MIN(s.start_ts),'unixepoch') AS von, datetime(MAX(s.start_ts),'unixepoch') AS bis
FROM statistics s JOIN statistics_meta sm ON sm.id = s.metadata_id
GROUP BY sm.statistic_id, sm.unit_of_measurement
ORDER BY sm.statistic_id;
```

## 3. Export Langzeitstatistik (Stundenmittel, gesamte Historie)

```bash
mkdir -p /config/duckcurve
sqlite3 -header -csv /config/home-assistant_v2.db "
SELECT sm.statistic_id, sm.unit_of_measurement, s.start_ts, s.mean, s.min, s.max, s.state, s.sum
FROM statistics s JOIN statistics_meta sm ON sm.id = s.metadata_id
WHERE sm.statistic_id IN (
  'sensor.myenergi_hub_14117600_power_generation',
  'sensor.myenergi_hub_14117600_power_grid',
  'sensor.myenergi_hub_14117600_home_consumption',
  'sensor.myenergi_libbi_26244255_power_ct_internal_load',
  'sensor.myenergi_libbi_26244255_soc',
  'sensor.myenergi_wallbox_power_ct_internal_load',
  'sensor.heatpump_total_power',
  'sensor.speicher_1_temperature','sensor.speicher_2_temperature',
  'sensor.speicher_3_temperature','sensor.speicher_5_temperature',
  'sensor.geilenkirchen_air_base_temperatur'
) OR sm.statistic_id LIKE '%tibber%' OR sm.statistic_id LIKE '%price%' OR sm.statistic_id LIKE '%strompreis%'
ORDER BY s.start_ts, sm.statistic_id;
" > /config/duckcurve/ha_statistics_hourly.csv
```

## 4. Export 5-Minuten-Statistik (letzte ~10 Tage, feiner)

Gleiche Abfrage, nur `FROM statistics_short_term s` → Datei `ha_statistics_5min.csv`.

## 5. Export Rohzustände (letzte Tage, minutengenau)

```bash
sqlite3 -header -csv /config/home-assistant_v2.db "
SELECT m.entity_id, s.state, s.last_updated_ts
FROM states s JOIN states_meta m ON m.metadata_id = s.metadata_id
WHERE m.entity_id IN (
  'sensor.myenergi_hub_14117600_power_generation',
  'sensor.myenergi_hub_14117600_power_grid',
  'sensor.myenergi_libbi_26244255_power_ct_internal_load',
  'sensor.myenergi_libbi_26244255_soc',
  'sensor.myenergi_wallbox_power_ct_internal_load',
  'sensor.heatpump_total_power',
  'sensor.geilenkirchen_air_base_temperatur'
) AND s.state NOT IN ('unknown','unavailable')
ORDER BY s.last_updated_ts;
" > /config/duckcurve/ha_states.csv
```

Danach `gzip /config/duckcurve/*.csv`. Dateien per Samba/File-Editor herunterladen. Sie enthalten keine
Zugangsdaten, nur Messwerte.

## 5b. Alternative: Historie liegt in InfluxDB (HA-Integration `influxdb`)

Wer die `influxdb`-Integration nutzt, hat dort die vollständige Historie in Rohauflösung. Die HA-Integration
schreibt je **Einheit** eine Measurement (`W`, `%`, `°C`, …) mit Tag `entity_id` (ohne `sensor.`) und Feld
`value`. Abfragesprache ist InfluxQL, kein SQL – daher scheitern die Recorder-Abfragen dort mit
„error parsing query“.

Inventar:

```sql
SHOW MEASUREMENTS
SHOW TAG VALUES FROM "W" WITH KEY = "entity_id"
```

Export als CSV über die HTTP-API (von einem PC im Heimnetz; `<ha-ip>`, Datenbankname und Zugang wie im Add-on
konfiguriert; `SHOW DATABASES` zeigt den Namen, im Haus Geilenkirchen `energy`). Minutenmittel, ein Aufruf je Einheit:

```bash
curl -sG "http://<ha-ip>:8086/query" -u "<user>:<passwort>" -H "Accept: application/csv" \
  --data-urlencode "db=energy" --data-urlencode "epoch=s" \
  --data-urlencode "q=SELECT mean(\"value\") FROM \"W\" WHERE (\"entity_id\"='myenergi_hub_14117600_power_generation' OR \"entity_id\"='myenergi_hub_14117600_power_grid' OR \"entity_id\"='myenergi_libbi_26244255_power_ct_internal_load' OR \"entity_id\"='myenergi_wallbox_power_ct_internal_load' OR \"entity_id\"='heatpump_total_power') AND time > now() - 400d GROUP BY time(1m), \"entity_id\" fill(none)" \
  > influx_W.csv
curl -sG "http://<ha-ip>:8086/query" -u "<user>:<passwort>" -H "Accept: application/csv" \
  --data-urlencode "db=energy" --data-urlencode "epoch=s" \
  --data-urlencode "q=SELECT mean(\"value\") FROM \"%\" WHERE \"entity_id\"='myenergi_libbi_26244255_soc' AND time > now() - 400d GROUP BY time(1m), \"entity_id\" fill(none)" \
  > influx_soc.csv
curl -sG "http://<ha-ip>:8086/query" -u "<user>:<passwort>" -H "Accept: application/csv" \
  --data-urlencode "db=energy" --data-urlencode "epoch=s" \
  --data-urlencode "q=SELECT mean(\"value\") FROM \"°C\" WHERE \"entity_id\"='geilenkirchen_air_base_temperatur' AND time > now() - 400d GROUP BY time(5m), \"entity_id\" fill(none)" \
  > influx_temp.csv
```

Inventar des Hauses (Chronograf-Export vom 06.09.2026): Leistungen in `W` (`myenergi_hub_14117600_power_generation`,
`…_power_grid`, `…_home_consumption`, `myenergi_libbi_26244255_power_ct_internal_load`, `…_power_ct_dcpv`,
`myenergi_wallbox_power_ct_internal_load`, `heatpump_total_power`, `power_heatpumo`, `photovoltaic_total`),
SOC in `%` (`myenergi_libbi_26244255_soc`), Temperaturen in `°C` (`speicher_1/2/3/4/5/11_temperature`,
`vorlauf_temperature`, `geilenkirchen_air_base_temperatur`), Strompreis in `EUR/kWh`
(`electricity_price_waldstrasse_48`), zweiter Wechselrichter in `kW` (`nobis_solar_network_111_current_power`).
Der Preissensor steht nicht im Bridge-Mapping und wird beim Import per `extra_map` zugeordnet:
`{"sensor.electricity_price_waldstrasse_48":{"key":"electricity_price_ct_kwh","unit":"EUR/kWh"}}`.

Ergebnisspalten: `name,tags,time,mean` (tags = `entity_id=…`). Genau dieses Format versteht der Import; die
Schrittweite (1, 5 oder 60 min) erkennt er selbst. Bei sehr großen Datenmengen `time > now() - 400d` in
Monatsfenster teilen und die Dateien nacheinander importieren – der Import ist idempotent. Mit dem Add-on
InfluxDB (Chronograf) geht dasselbe über *Explore → CSV*, nur unbequemer bei großen Ergebnissen.

## 6. Import in Duck Curve Home

Endpunkt `POST /api/v1/import/ha` (API-Token, Body = CSV oder gzip; Recorder- und Influx-Format). Zusätzlich `POST /api/v1/import/myenergi-backfill?hours=48` lädt die myenergi-Minutenhistorie nach und `GET /api/v1/import/events` zeigt die letzten Systemereignisse. Parameter: `kind=auto|statistics|states`,
`dry_run=true` zum Prüfen, `extra_map` (JSON) für Entitäten, die nicht im Bridge-Mapping stehen, z. B. ein
Tibber-Preissensor:

```bash
curl -X POST "https://<api>/api/v1/import/ha?dry_run=true" -H "authorization: Bearer $DCH_API_TOKEN" \
  --data-binary @ha_statistics_hourly.csv.gz \
  --get --data-urlencode 'extra_map={"sensor.tibber_preis":{"key":"electricity_price_ct_kwh","unit":"EUR/kWh"}}'
```

Was passiert: Entitäten werden über `config/entities.home.yaml` in Domänenschlüssel übersetzt (Einheit,
Vorzeichen wie in der Bridge). Stundenmittel gelten als konstante Leistung, daraus entstehen Stundenbilanzen mit
Quellenzuordnung und Kosten. Fehlt ein Preis, holt die API die Tibber-Preishistorie (`DCH_TIBBER_TOKEN`).
Eine importierte Stunde ersetzt eine gespeicherte nur, wenn sie mehr Minuten abdeckt. Rohzustände der letzten
14 Tage landen zusätzlich als Messwerte in der Historie (Charts).
