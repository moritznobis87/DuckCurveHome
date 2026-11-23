# Konfiguration

Zwei Ebenen: **Umgebungsvariablen** (`DCH_*`, pydantic-settings, `.env`) für Betrieb und Secrets,
**HemsConfig** (Pydantic-Modell in `hems_core.domain.config`) für Regler und Modelle, ladbar aus einer YAML
(`DCH_CONFIG_FILE`, Beispiel `config/hems.example.yaml`) und lesbar über `GET /api/v1/config`.

## Umgebungsvariablen

| Variable | Default | Bedeutung |
|---|---|---|
| `DCH_MODE` | `demo` | `demo` (Simulation) · `live` (Phase 2) |
| `DCH_ROLE` | `all` | `all`, `api`, `worker` |
| `DCH_HOST` / `DCH_PORT` | `0.0.0.0` / `8000` | Bind-Adresse der API |
| `DCH_LOG_LEVEL` | `INFO` | structlog-Level (JSON, wenn kein TTY) |
| `DCH_CORS_ORIGINS` | `["http://localhost:3000"]` | erlaubte Browser-Herkünfte |
| `DCH_TICK_S` | `10` | Regler-Takt (Simulationssekunden) |
| `DCH_HISTORY_RETENTION_HOURS` | `72` | In-Memory-Historie |
| `DCH_DEMO_SPEED` | `1` | Simulationssekunden je Echtzeitsekunde (288 = 24 h in 5 min); zur Laufzeit per `POST /api/v1/demo` |
| `DCH_DEMO_SEED` | `7` | Zufallssaat der Simulation (Wetter, Preise, Verbrauch) |
| `DCH_DEMO_START` | jetzt | Startzeitpunkt der Simulation (ISO 8601) |
| `DCH_DEMO_WARMUP_HOURS` | `30` | Vorlauf beim Start, damit Chart und Historie gefüllt sind |
| `DCH_DEMO_AUTOSTART` | `true` | `false` in Tests |
| `hems.tariff.feed_in_ct_kwh` (YAML) | `7.41` | Einspeisevergütung **netto** in ct/kWh. Bemisst den Einspeiseerlös, die entgangene Vergütung beim Eigenverbrauch und die PV-Abrechnung |
| `hems.tariff.vat_rate` (YAML) | `0.19` | Umsatzsteuersatz auf Einspeisung und unentgeltliche Wertabgabe |
| `hems.tariff.price_includes_vat` (YAML) | `true` | Tibber liefert Bruttopreise; der Eigenverbrauch wird daraus netto bewertet |
| `hems.tariff.small_business` (YAML) | `false` | § 19 UStG: dann weist die PV-Abrechnung keine Umsatzsteuer aus |
| `DCH_TIBBER_PRICE_RESOLUTION` | *(leer)* | Auflösung der Preishistorie. Leer = feinste laut Tibber-Schema (Viertelstunden, wo angeboten); `HOURLY` erzwingt Stundenpreise |
| `DCH_ACTUATION_ENABLED` | `true` | Vom Bedienenden ausgelöstes Schalten (Lichter, Kaffeemaschine) |
| `DCH_HEAT_PUMP_ACTUATION_ENABLED` | `true` | Selbsttätiges Stellen des WP-Kontakts K1 aus der Regelentscheidung. **Seit dem 09.11.2026 die Vorgabe**, vorher `false`. Auf `false` läuft die Regelung im Schatten: sie entscheidet und zeigt an, schaltet aber nicht. Wer `true` lässt, braucht im Haus die Wächter-Automation in Home Assistant (E1) und einen Auto-Off-Timer im schaltenden Relais (E0); für K1 sind das die einzigen Rückfallebenen, weil der Weg über Home Assistant keine Laufzeitbegrenzung überträgt. Der Zustand steht in `GET /live/state` unter `system.hp_actuation` und auf der Seite „System" |
| `DCH_PLAN_REFRESH_MIN` | `15` | Neuplanung |
| `DCH_PUSH_SUBJECT` | `mailto:duck-curve-home@example.org` | Absender im VAPID-Anspruch der Mitteilungen. Eine echte Adresse gehört nicht ins Repository, deshalb der Platzhalter. Solange er steht, versucht der Dienst zuerst die Adresse der Oberfläche (`https://…`), die das angemeldete Gerät nennt, und nimmt sonst den Platzhalter. **Die Endung muss es im öffentlichen Netz geben**: Apples Push-Dienst lehnt `.invalid`, `.test`, `.example`, `.local`, `.lan`, `.home`, `.internal` und `localhost` mit `403 BadJwtToken` ab (gemessen 12.11.2026, `docs/MORGENBRIEF.md`). Eine untaugliche Angabe wird übergangen und im Protokoll vermerkt. **Das Schlüsselpaar selbst steht nicht hier**: Der Dienst erzeugt es beim ersten Gebrauch und behält es in der Tabelle `push_keys` - ein privater Schlüssel in einer Umgebungsvariable ist ein Geheimnis, das durch zu viele Hände geht |
| `DATABASE_URL` | - | Live-Modus: `postgresql://…` (Railway) oder `sqlite+aiosqlite:///…` (Entwicklung) |
| `DCH_DB_CREATE_ALL` | `false` | Schema ohne Alembic anlegen (nur SQLite/Tests) |
| `DCH_BRIDGE_TOKENS` | `[]` | JSON-Liste erlaubter Bridge-Tokens (Secrets) |
| `DCH_API_TOKEN` | - | Bearer-Token, das das Web-BFF mitschickt; leer = keine Prüfung |
| `DCH_CONFIG_FILE` | - | YAML mit `site`, `pv_system`, `hems` (siehe `config/hems.example.yaml`) |
| `DCH_TIBBER_TOKEN` / `DCH_TIBBER_HOME_ID` | - | Tibber-Preise; ohne Token pausieren Preisregeln |
| `DCH_MYENERGI_SERIAL` / `DCH_MYENERGI_API_KEY` | - | myenergi-Cloud direkt: Hub-Seriennummer und API-Key (App → Konto → Erweitert). Liefert PV, Netz, Batterie, SOC, Wallbox ohne Home Assistant |
| `DCH_MYENERGI_POLL_S` | `30` | Abfragetakt der myenergi-Cloud |
| `DCH_MYENERGI_BACKFILL_HOURS` | `48` | Minutenhistorie beim Start nachladen (Lücken füllen); danach stündlich die letzten 3 h; `0` = aus |
| `DCH_WEATHER_REFRESH_MIN` | `60` | Open-Meteo-Abruf; `0` deaktiviert Wetter |
| `DCH_PRICE_REFRESH_MIN` | `30` | Tibber-Abruf (13-15 Uhr immer halbstündlich) |
| `DCH_RAW_RETENTION_DAYS` | `14` | Aufbewahrung der **Rohwerte**. Minutenmittel und Stundenbilanzen bleiben dauerhaft, siehe `docs/DATENHALTUNG.md` |
| `DCH_ALFRED_SCHLUESSEL` | - | API-Schlüssel des Sprachmodells für Alfred (`docs/ALFRED.md`). Leer = Alfred bleibt bei vorbereiteten Texten, das Eingabefeld erscheint nicht. Ein Geheimnis: nur in der Umgebung des Dienstes |
| `DCH_ALFRED_ANBIETER` | `mistral` | `mistral` oder `openai`; beide sprechen dieselbe Form. Weitere kompatible Anbieter über `DCH_ALFRED_URL` |
| `DCH_ALFRED_MODELL` | *(Vorgabe des Anbieters)* | Leer = `mistral-medium-latest` bzw. `gpt-4o-mini`. Bewusst nicht die kleinste Stufe: kleine Modelle erfinden eher Bedienschritte |
| `DCH_ALFRED_URL` | *(Vorgabe des Anbieters)* | Andere Adresse in derselben Form (z. B. ein eigener OpenAI-kompatibler Endpunkt) |
| `DCH_ALFRED_ZEITLIMIT_S` | `30` | Zeitlimit einer einzelnen Modellanfrage |
| `DCH_ALFRED_FRAGEN_PRO_TAG` | `100` | Fragen je Gerät und Tag, im Prozess gezählt. Schutz vor einer Schleife, keine Abrechnung |
| `DCH_ALFRED_VERLAUF_MAX` | `6` | Frühere Gesprächswechsel, die mitgehen; der Verlauf lebt nur im Browser |
| `DCH_API_URL` (web) | `http://localhost:8000` | Ziel der BFF-Route `/api/dch/*` |
| `DCH_API_TOKEN` (web) | - | wird als Bearer an die API weitergereicht |
| `DCH_ANMELDUNG` (web) | `an` | Ob die Oberfläche eine Anmeldung verlangt. **Die Vorgabe ist „an"** - eine Instanz, die die Variable vergisst, ist zu und nicht offen. `aus` (oder `0`) nur dort, wo es keine Personen geben kann: im Demo-Modus ohne Datenbank, den `docker-compose.yml` und `tools/demo.sh` selbst so setzen |
| `DCH_NOTZUGANG` | - | Der Rückweg, wenn sich jemand ausgesperrt hat: die genannte Person wird beim Start wieder aktiv, wird `hausherr` und bekommt einen Einladungslink ins Protokoll - **auch wenn es schon Personen gibt**. Nach Gebrauch wieder entfernen; solange sie steht, entsteht bei jedem Start ein neuer Link, und der Dienst warnt davor ([docs/ZUGANG.md](docs/ZUGANG.md)) |
| `DCH_ERSTE_PERSON` | - | Der erste Hausherr. Ist die Personentabelle beim Start leer, legt der Dienst diesen Zugang an und schreibt seinen Einladungslink **einmal** ins Protokoll; danach tut die Variable nichts mehr. Der Ersatz für die Gerätepaarung, über die früher der erste Zugang entstand ([docs/ZUGANG.md](docs/ZUGANG.md)) |
| `DCH_PASSKEY_RP_ID` | `home.duckcurve.de` | Die Domain, an die jeder Passkey gebunden wird. **Nicht mehr änderbar, ohne alle Passkeys zu entwerten.** Der eigene Host und nicht die registrierbare Domain `duckcurve.de`: sonst liegen die Passkeys von Duck Curve und Duck Curve Home im selben Bereich, der Browser bietet beide an, und der falsche wird abgewiesen (am 23.11.2026 so entschieden, Begründung in [ADR-0002](docs/decisions/ADR-0002-identitaet-und-berechtigung.md), Festlegung 1). Entwicklung: `localhost` |
| `DCH_PASSKEY_HERKUENFTE` | `["https://home.duckcurve.de"]` | Seiten, von denen eine Antwort des Browsers angenommen wird - also die Adresse des **web**-Dienstes, nicht die der API. Beim Start geprüft: `https` (außer `localhost`) und der Host muss die RP-ID sein oder auf `.<RP-ID>` endigen. Stimmt es nicht, läuft der Dienst weiter und protokolliert es als Fehler - anmelden kann sich dann niemand |
| `DCH_PASSKEY_RP_NAME` | `Duck Curve Home` | Was der Browser im Passkey-Dialog anzeigt |
| `DCH_SITZUNG_TAGE` | `30` | Frist einer Personensitzung. Die Wandanzeige hängt nicht daran: sie ist ein Gerät und behält ihre Paarung |
| `DCH_ZUGANGSTOKEN_STUNDEN` | `72` | Frist eines Einladungs- oder Wiederherstellungslinks; er gilt einmal |
| `DCH_ANMELDE_URL` | *(erste Herkunft)* | Adresse, die im Einladungslink steht |
| `DCH_SMTP_HOST` / `_PORT` / `_BENUTZER` / `_PASSWORT` | - / `587` / - / - | Postausgang für die Einladung (`dch_api/post.py`). Ohne Angaben wird nichts verschickt und der Link bleibt auf der Seite „Zugang" zum Kopieren - der Versand ist eine Beigabe, kein Torwächter |
| `DCH_SMTP_SICHERHEIT` | `starttls` | `starttls`, `ssl` oder `keine` |
| `DCH_RESEND_SCHLUESSEL` | - | HTTPS-Versender als zweiter Weg, wenn ausgehendes SMTP gesperrt ist. Ist beides eingetragen, gilt SMTP |
| `DCH_ABSENDER` | *(SMTP-Benutzer)* | Absenderadresse, für beide Wege |

## Bridge (Home-Assistant-Add-on)

Optionen des Add-ons (`addons/duckcurve_bridge/config.yaml`): `api_ws_url`, `api_token`, `bridge_id`,
`entities_file`, `heartbeat_entity`, `offline_release_s`, `log_level`, sowie für den Shelly 3EM über MQTT
`source_mode` (`mqtt` Standard, `home_assistant`, `compare`), `mqtt_host`, `mqtt_port`, `mqtt_username`,
`mqtt_password`, `shelly_device_id` bzw. `mqtt_topic_prefix`, `mqtt_publish_interval_s` (Details in
`addons/duckcurve_bridge/DOCS.md`). Als Umgebungsvariablen heißen sie `DCH_BRIDGE_SOURCE_MODE`,
`DCH_BRIDGE_MQTT_HOST` usw. Das Entity-Mapping steht in
`/config/duckcurve/entities.yaml` (Vorlage `addons/duckcurve_bridge/entities.example.yaml`): je Sensor
`key`, `entity`, `unit` (W, kW, %, °C, EUR/kWh), optional `scale`, `sign` (`import_positive`,
`export_positive`, `discharge_positive`, `charge_positive`), `stale_after_s`; je Aktor `key`, `entity`,
`label`, `safety_class` (`heat_pump` für K1/K2), `safe_state`.

### Pelletofen (MCZ mit Maestro-Modul)

| Option / Umgebungsvariable | Default | Bedeutung |
| --- | --- | --- |
| `mcz_host` / `DCH_BRIDGE_MCZ_HOST` | leer | Adresse des Ofens, oder des Rechners, der den Port weiterreicht. Leer heißt: Quelle aus |
| `mcz_port` / `DCH_BRIDGE_MCZ_PORT` | `81` | WebSocket-Port der Maestro-Platine, bei Weiterleitung der Port des Weiterleiters |
| `mcz_poll_interval_s` / `DCH_BRIDGE_MCZ_POLL_INTERVAL_S` | `15` | Abstand zwischen zwei Zustandsabfragen |

**Der Ofen ist im Heimnetz meist nicht direkt erreichbar.** Die Maestro-Platine bedient den
WebSocket nur auf ihrem eigenen Hotspot (`192.168.120.1`), im Heimnetz lauscht sie auf nichts. Der
übliche Weg ist deshalb ein kleiner Rechner mit zwei Netzwegen, der den Port weiterreicht, siehe
`docs/SENSORIK.md`. `mcz_host` und `mcz_port` zeigen dann auf diesen Rechner.

Die Quelle liest ausschließlich, sie sendet nur `C|RecuperoInfo` und schaltet nichts. Vor dem
Konfigurieren lässt sich die Verbindung von Hand prüfen, ohne die Bridge anzufassen. Von jedem
Rechner im selben Netz, ohne Installation, mit dem Python, das ohnehin da ist:

```
python3 tools/mcz_probe.py 192.168.1.42
```

In einer eingerichteten Entwicklungsumgebung geht auch der Weg über die Bridge selbst:

```
uv run python -m dch_bridge.sources.mcz_maestro 192.168.1.42
```

Das gibt einen Rohrahmen und die daraus gelesenen Werte aus, dazu die Fühler, die dieser Ofen nicht
hat. Geliefert werden `stove_state`, `stove_running`, `stove_fume_temp_c`, `stove_ambient_temp_c`,
`stove_buffer_temp_c`, `stove_boiler_temp_c`, `stove_return_temp_c`, `stove_fume_fan_rpm`,
`stove_auger_rpm`, `stove_pump_pct`, `stove_dhw_mode`, `stove_power_level`, `stove_operating_hours`
und `stove_ignitions`.

### Einzelraumregelung (Controme)

| Option / Umgebungsvariable | Default | Bedeutung |
| --- | --- | --- |
| `controme_host` / `DCH_BRIDGE_CONTROME_HOST` | leer | Adresse des Mini-Servers im Heimnetz. **Leer heißt: Quelle aus** - ohne diesen Eintrag liest die Bridge keine Räume |
| `controme_house_id` / `DCH_BRIDGE_CONTROME_HOUSE_ID` | `0` | Haus-Kennung. `0` heißt suchen: probiert 2, 1, 3 und nimmt die erste, unter der Räume stehen |
| `controme_poll_interval_s` / `DCH_BRIDGE_CONTROME_POLL_INTERVAL_S` | `120` | Abstand zwischen zwei Abfragen |
| `controme_user` / `DCH_BRIDGE_CONTROME_USER` | leer | **zum Stellen Pflicht**, zum Lesen nicht nötig |
| `controme_password` / `DCH_BRIDGE_CONTROME_PASSWORD` | leer | dito |

Die Haus-Kennung ist **nicht verlässlich 1** - auf der hiesigen Anlage ist sie 2, und 1 liefert eine
leere Liste. Darum wird sie gesucht statt vorausgesetzt. Contromes eigene Beschreibung sagt dazu
nur, sie sei "aus unterschiedlichen Gründen manchmal 2".

Prüfen lässt sich die Adresse ohne die Bridge, von jedem Rechner im selben Netz:

```
curl http://192.168.1.50/get/json/v1/2/temps/
```

Kommt `[]`, ist es die falsche Haus-Kennung; kommt eine Liste von Etagen mit `raeume`, stimmt sie.

Ohne Zugangsdaten liest die Brücke nur. Mit ihnen lässt sich auf der Räume-Seite der Sollwert
eines Raums stellen, dauerhaft und auf halbe Grad gerundet (`POST /rooms/{id}/setpoint`,
Grenzen 5 bis 30 Grad, auf Zehntel gerundet). Geliefert werden je Raum `room_<id>_temp_c`, `room_<id>_setpoint_c`,
`room_<id>_offset_k`, `room_<id>_humidity_pct` und `room_<id>_valve`; die Namen, Etagen und
Kreiszahlen gehen als Ereignis `rooms.list` mit, weil sie keine Zahlen sind. Zu sehen ist das
alles unter `/waerme/raeume`.

### Alarmanlage

| Option / Umgebungsvariable | Default | Bedeutung |
| --- | --- | --- |
| `alarm_entity` / `DCH_BRIDGE_ALARM_ENTITY` | leer | Die Entität der Anlage in Home Assistant, etwa `alarm_control_panel.lupusec`. Nur fürs Schärfen; gelesen wird über die Entity-Zuordnung |
| `alarm_arm_enabled` / `DCH_BRIDGE_ALARM_ARM_ENABLED` | `false` | Ohne diese Freigabe bleibt es beim Zusehen |

Der Zustand gehört in die Entity-Zuordnung als `{ key: alarm_state, kind: alarm }` und kommt als
Zahl an: 0 unscharf, 1 zu Hause scharf, 2 unterwegs scharf, 3 schaltet gerade, 4 ausgelöst.

**Geschärft wird, entschärft nie.** `POST /control/alarm/arm` kennt `home` und `away` und sonst
nichts. Die Anzeige hängt in der Küche, Gäste gehen daran vorbei, und ihr Zugang ist ein
Sitzungskeks auf einem Gerät: genug, um eine Anlage einzuschalten, zu wenig, um sie abzuschalten.

### Fensterkontakte

Sie gehören nicht zu Controme, sondern in die Entity-Zuordnung (`config/entities.home.yaml`), als
gewöhnliche Binärsensoren mit dem Schlüssel `room_<id>_window` - `<id>` ist die Raumkennung aus
Controme, 1 heißt offen. Mehrere Fenster in einem Raum fasst in Home Assistant eine Gruppe
zusammen; zwei Einträge mit demselben Schlüssel überschrieben einander.

### Hausplan (Bereich Haus)

| Option / Umgebungsvariable | Default | Bedeutung |
| --- | --- | --- |
| `house_file` / `DCH_BRIDGE_HOUSE_FILE` | `/config/duckcurve/haus.yaml` | Die Geometrie des Hauses für die Modellansicht. Fehlt die Datei, gibt es keinen Plan und keinen Fehler |

Die Datei beschreibt Decks, Räume, Wände mit Türlücken, Fenster, Kontakte und Möbel in Metern; das
Schema steht in `hems_core/house/plan.py`, eine kommentierte Vorlage mit einem erfundenen Haus in
`config/haus.example.yaml`. Der Plan des eigenen Hauses gehört nicht ins Repository: Die Bridge
liest ihn vom Home-Assistant-Rechner, prüft ihn und schickt ihn als Ereignis `house.plan`; der
Dienst hebt den jüngsten Stand auf und liefert ihn unter `GET /haus`, zusammen mit dem Zustand
der Kontakte. Temperaturen kommen weiter aus `/rooms` (verbunden über `room_id`), Alarm, Puffer
und Wärmepumpe aus dem Live-Zustand. Geändert wird die Datei im laufenden Betrieb: Die Bridge sieht
alle 30 Sekunden nach und meldet einen neuen Stand, einen Fehler im Dokument mit Pfad.

## HemsConfig (Auszug, Defaults)

```yaml
heat_pump:
  minimum_electric_power_kw: 3.5
  nominal_electric_power_kw: 4.5
  running_threshold_kw: 0.5        # ab dieser Leistung gilt „läuft“
  running_debounce_s: 60
  min_runtime_min: 30
  min_offtime_min: 20
  start_timeout_min: 10            # Anlauf nach Freigabe erwartet
  max_starts_per_day: 8
  release_ttl_min: 20              # Gültigkeit einer Entscheidung
  hw_auto_off_release_s: 1800      # Shelly-Timer K1
  hw_auto_off_block_s: 1200        # Shelly-Timer K2
control:
  tick_s: 10
  ewma_seconds: 180                # Glättung der Regelgrößen
  sensor_grace_min: 5              # Karenz bei Sensorausfall im Lauf
  max_toggles_per_hour: 4          # darüber: FAILSAFE
  failsafe_hold_min: 60
  pv:
    on_surplus_kw: 4.0
    off_import_kw: 1.5
    on_delay_min: 5
    off_delay_min: 10
    count_battery_charging_above_soc: 0.8
    heat_pump_before_ev: false
    min_buffer_headroom_soc: 0.10
  price:
    negative_price_release: true
    cheap_quantile: 0.10
    min_window_min: 30
    price_max_age_h: 30
    expensive_quantile: 0.85
  block:
    enabled: false                 # K2 in Phase 1-4 aus
buffer:
  volume_liters: 800
  layers: [0.25, 0.25, 0.25, 0.25]
  min_useful_temperature_c: 35
  target_temperature_c: 50
  max_temperature_c: 62
  comfort_min_top_c: 42
  soc_method: layered_energy_v1    # | weighted_mean_v1
  status_thresholds: [0.2, 0.6, 0.9]
  soc_full: 0.95
balance:
  tolerance_kw: 0.3
```

## Demo-API

`POST /api/v1/demo` mit JSON:

| Feld | Wirkung |
|---|---|
| `speed` | Zeitraffer setzen (0 = Pause) |
| `fault_key`, `fault_quality`, `fault_duration_s` | Sensor als `stale`/`unavailable`/`unknown` markieren, z. B. `grid_power_kw` |
| `scenario` | `reset`, `sunny_surplus`, `buffer_full`, `cold_evening`, `sensor_outage` |
