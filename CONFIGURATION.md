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
| `DCH_ACTUATION_ENABLED` | `false` | Schaltbefehle an die Bridge senden (Phase 3+) |
| `DCH_PLAN_REFRESH_MIN` | `15` | Neuplanung |
| `DATABASE_URL` | – | Live-Modus: `postgresql://…` (Railway) oder `sqlite+aiosqlite:///…` (Entwicklung) |
| `DCH_DB_CREATE_ALL` | `false` | Schema ohne Alembic anlegen (nur SQLite/Tests) |
| `DCH_BRIDGE_TOKENS` | `[]` | JSON-Liste erlaubter Bridge-Tokens (Secrets) |
| `DCH_API_TOKEN` | – | Bearer-Token, das das Web-BFF mitschickt; leer = keine Prüfung |
| `DCH_CONFIG_FILE` | – | YAML mit `site`, `pv_system`, `hems` (siehe `config/hems.example.yaml`) |
| `DCH_TIBBER_TOKEN` / `DCH_TIBBER_HOME_ID` | – | Tibber-Preise; ohne Token pausieren Preisregeln |
| `DCH_MYENERGI_SERIAL` / `DCH_MYENERGI_API_KEY` | – | myenergi-Cloud direkt: Hub-Seriennummer und API-Key (App → Konto → Erweitert). Liefert PV, Netz, Batterie, SOC, Wallbox ohne Home Assistant |
| `DCH_MYENERGI_POLL_S` | `30` | Abfragetakt der myenergi-Cloud |
| `DCH_MYENERGI_BACKFILL_HOURS` | `48` | Minutenhistorie beim Start nachladen (Lücken füllen); danach stündlich die letzten 3 h; `0` = aus |
| `DCH_WEATHER_REFRESH_MIN` | `60` | Open-Meteo-Abruf; `0` deaktiviert Wetter |
| `DCH_PRICE_REFRESH_MIN` | `30` | Tibber-Abruf (13–15 Uhr immer halbstündlich) |
| `DCH_RAW_RETENTION_DAYS` | `14` | Aufbewahrung der Rohwerte |
| `DCH_API_URL` (web) | `http://localhost:8000` | Ziel der BFF-Route `/api/dch/*` |
| `DCH_API_TOKEN` (web) | – | wird als Bearer an die API weitergereicht |
| `DCH_SESSION_SECRET` (web) | – | ≥ 32 Zeichen; aktiviert die Kiosk-Anmeldung |
| `DCH_KIOSK_TOKEN` (web) | – | Pairing-Token für `/pair?token=…&name=…` |

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
    enabled: false                 # K2 in Phase 1–4 aus
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
