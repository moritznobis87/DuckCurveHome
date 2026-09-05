# Duck Curve Home Bridge

Verbindet Home Assistant **ausgehend** mit der Duck-Curve-Home-API. Kein offener Port im Haus.

## Einrichtung

1. Dieses Repository in Home Assistant als Add-on-Repository hinzufügen
   (Einstellungen → Add-ons → Add-on Store → ⋮ → Repositories → `https://github.com/moritznobis87/DuckCurveHome`).
2. Add-on „Duck Curve Home Bridge“ installieren.
3. Datei `/config/duckcurve/entities.yaml` anlegen (Vorlage: `addons/duckcurve_bridge/entities.example.yaml`; für das Haus in Geilenkirchen fertig ausgefüllt in `config/entities.home.yaml`).
   Sie ordnet Home-Assistant-Entitäten den Duck-Curve-Größen zu und legt Einheit und Vorzeichen fest.
4. Optionen setzen: `api_ws_url` (Railway-API) und `api_token` (in Duck Curve Home erzeugt).
5. Starten. Im Protokoll erscheint „uplink connected“. In Home Assistant entsteht die Entität
   `sensor.duckcurve_bridge_heartbeat` (Zeitstempel, Attribut `cloud_connected`).

## Wächter-Automation (empfohlen, Rückfallebene E1)

Legt die Wärmepumpen-Kontakte in den sicheren Zustand, wenn die Bridge 30 Minuten keinen Heartbeat setzt:

```yaml
alias: Duck Curve Home – Wächter
trigger:
  - platform: time_pattern
    minutes: "/5"
condition:
  - condition: template
    value_template: >
      {{ (now() - states('sensor.duckcurve_bridge_heartbeat') | as_datetime(default=now())).total_seconds() > 1800 }}
action:
  - service: switch.turn_off
    target:
      entity_id:
        - switch.wp_pv_freigabe
        - switch.wp_evu_sperre
  - service: persistent_notification.create
    data:
      message: Duck Curve Home Bridge meldet sich nicht – Wärmepumpen-Kontakte zurückgesetzt.
```

Zusätzlich sollten die Shelly-Relais der Wärmepumpen-Kontakte einen **Auto-Off-Timer** im Gerät haben
(K1 30 min, K2 20 min) – Rückfallebene E0, unabhängig von jeder Software.

## Build-Hinweis

Der Supervisor baut das Image auf dem HA-Rechner mit dem Add-on-Ordner als Kontext. Das Dockerfile installiert
`hems-core` und `dch-bridge` deshalb per `pip` direkt aus diesem GitHub-Repository (Branch `main`, einstellbar über
`DCH_REF` in `build.yaml`). Eine neue Bridge-Version erreicht Home Assistant, indem `version` in `config.yaml`
erhöht wird; danach im Add-on-Store „Auf Updates prüfen“ bzw. das Repository neu laden und das Update installieren.
Der erste Build dauert auf einem Raspberry Pi einige Minuten (Python-Pakete werden geladen).

## Verhalten ohne Internet

Die Bridge liest weiter und speichert Telemetrie lokal (SQLite-Outbox, 7 Tage). Nach `offline_release_s`
Sekunden ohne Cloud-Kontakt setzt sie Aktoren der Sicherheitsklasse `heat_pump` auf ihren sicheren Zustand.
Die Wärmepumpe läuft dann in ihrer eigenen Regelung.
