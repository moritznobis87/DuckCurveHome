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

## Shelly 3EM direkt über MQTT (Standard ab 0.2.0)

Der Wärmepumpen-Zähler (Shelly 3EM Gen1) liefert seine Werte direkt an den lokalen Mosquitto-Broker; die
Bridge liest sie dort ab, ohne den Umweg über Home-Assistant-Integration und -Entitäten. Home Assistant bleibt
für Puffertemperaturen, Außentemperatur und die Schalter zuständig und hört am Broker nur noch mit.

Datenfluss neu: `Shelly 3EM → Mosquitto (LAN) → Bridge → Duck-Curve-API`. Der Broker bleibt im Heimnetz, kein
Port ins Internet. Der Shelly 3EM Gen1 kann kein verschlüsseltes MQTT, deshalb Klartext nur im LAN.

### 1. Mosquitto installieren

Einstellungen → Add-ons → Add-on Store → „Mosquitto broker“ (offiziell) installieren und starten. Danach
Einstellungen → Geräte & Dienste → die Integration „MQTT“ hinzufügen (Broker `core-mosquitto`, Port 1883).
So sieht Home Assistant weiterhin die Shelly-Werte, falls gewünscht (MQTT-Discovery des Shelly).

### 2. Eigene MQTT-Zugangsdaten anlegen

Mosquitto verwendet Home-Assistant-Benutzer. Unter Einstellungen → Personen → Benutzer einen eigenen
Benutzer anlegen (z. B. `mqtt-shelly`, „Nur lokal anmelden“, kein Administrator) und ein langes Passwort
vergeben. Denselben Benutzer tragen Shelly und Bridge ein. Das Passwort steht nirgends im Repository und
erscheint nicht in Protokollen.

### 3. Shelly 3EM konfigurieren

Weboberfläche des Shelly → Internet & Security → Advanced – Developer settings → „Enable action execution
via MQTT“: Server `<IP von Home Assistant>:1883`, Benutzer und Passwort aus Schritt 2, „Retain“ aus,
„Clean Session“ an, Update-Periode 30 s (der Shelly sendet Leistungen zusätzlich bei Änderung). Die Geräte-ID
steht in der Topic-Vorschau (`shellies/shellyem3-<ID>`) und auf dem Gerät; im Haus Geilenkirchen
`485519DB56D2` (HA-Gerät `shellyem3_485519db56d2`).

**Hinweis:** Beim Shelly 3EM Gen1 schaltet aktiviertes MQTT die Shelly-Cloud ab. Die Shelly-App funktioniert
dann nur noch im lokalen Netz.

### 4. Bridge konfigurieren

Optionen des Add-ons:

| Option | Bedeutung |
|---|---|
| `source_mode` | `mqtt` (Standard), `home_assistant` (bisheriger Weg) oder `compare` (beide, siehe unten) |
| `mqtt_host` / `mqtt_port` | Broker, im HA-Netz `core-mosquitto` und `1883` |
| `mqtt_username` / `mqtt_password` | Zugangsdaten aus Schritt 2 |
| `shelly_device_id` | z. B. `485519DB56D2`; alternativ `mqtt_topic_prefix` komplett, z. B. `shellies/shellyem3-485519DB56D2` |
| `mqtt_publish_interval_s` | Takt, in dem die Bridge aus den zuletzt empfangenen Werten aller drei Phasen einen konsistenten Datensatz an die API schickt (Standard 10 s) |
| `api_ws_url` / `api_token` | Railway-Endpunkt und Bridge-Token (unverändert) |
| `log_level` | `INFO` genügt; `DEBUG` zeigt verworfene Nachrichten |

Übertragen werden Gesamtleistung (Summe der drei Phasen, kW), Gesamtzählerstand Bezug und Rückspeisung
(Summe der `total`-/`total_returned`-Zähler, Wh → kWh) und je Phase Leistung, Spannung, Strom, Leistungsfaktor
und Zählerstände. Jeder Messwert trägt die Geräte-ID (`source: mqtt:shellyem3-<ID>`) und den Empfangszeitpunkt
der jüngsten enthaltenen Nachricht. `energy`/`returned_energy` (flüchtig) werden bewusst nicht verwendet.
Unplausible Werte (Bereich, fallende Zählerstände, unlesbare Nutzdaten) werden verworfen und gezählt; ein
`online: false` des Shelly oder 90 s Funkstille melden den Zähler als nicht verfügbar.

### 5. MQTT-Empfang testen

Im Add-on-Protokoll erscheint `mqtt connected` und alle 5 Minuten `mqtt status` mit `messages`, `rejected`,
`reconnects`, `emitted`. Auf der Wärmeseite von Duck Curve Home muss die Wärmepumpenleistung mit Quelle
`mqtt:shellyem3-…` erscheinen (Live-Zustand, Feld `source`). Alternativ mit dem MQTT-Werkzeug von Home
Assistant (Einstellungen → Geräte & Dienste → MQTT → Konfigurieren → „Auf ein Thema lauschen“)
`shellies/shellyem3-<ID>/#` beobachten.

### 6. Kontrollierter Wechsel

1. `source_mode: compare` setzen und neu starten: die API bekommt weiter die HA-Werte, die Bridge misst
   parallel den MQTT-Wert und schreibt Abweichungen über 50 W bzw. 5 % als Warnung ins Protokoll, dazu alle
   60 Vergleiche eine Zusammenfassung (`compare summary`). Nichts wird doppelt gesendet.
2. Nach ein bis zwei Tagen ohne systematische Abweichung `source_mode: mqtt` setzen. Ab dann kommt
   `heat_pump_power_kw` nur noch aus MQTT; der HA-Sensor `sensor.heatpump_total_power` wird für diesen
   Schlüssel ignoriert (das Mapping in `entities.yaml` kann unverändert bleiben).

### 7. Rollback

`source_mode: home_assistant` setzen und das Add-on neu starten – die Bridge liest den Zähler wieder aus
den HA-Entitäten, MQTT wird nicht verbunden. Der Shelly darf weiter an den Broker senden. Ausstehende
Datensätze in der Outbox bleiben erhalten.

### Zuverlässigkeit

Jeder Datensatz wird zuerst in der SQLite-Outbox (`/data/outbox.sqlite`) gespeichert und erst nach der
Bestätigung (Ack mit Sequenznummer) der API gelöscht. Bei Ausfall von Railway verbindet die Bridge sich mit
wachsendem Abstand (bis 60 s) neu und liefert die Outbox nach. Nachlieferungen sind unschädlich: die API
schreibt Messwerte per Upsert auf (Schlüssel, Messzeitpunkt), ein zweites Mal gesendete Datensätze erzeugen
keine Doppel. Die MQTT-Verbindung selbst verbindet sich ebenfalls mit Backoff neu (QoS 1, Clean Session aus).

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
