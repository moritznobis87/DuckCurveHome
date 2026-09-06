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

## Shellys direkt über MQTT (Standard ab 0.2.0, Gen 2 ab 0.3.0)

Die Shellys liefern ihre Werte direkt an den lokalen Mosquitto-Broker; die Bridge liest sie dort ab, ohne den
Umweg über Home-Assistant-Integration und -Entitäten. Unterstützt werden die erste Generation (Shelly 3EM,
Abschnitt 3) und die Generationen 2/3 – Plus und Pro (Abschnitt 4b). Home Assistant bleibt für die übrigen
Entitäten und die Schalter zuständig und hört am Broker nur noch mit.

Datenfluss neu: `Shelly → Mosquitto (LAN) → Bridge → Duck-Curve-API`. Der Broker bleibt im Heimnetz, kein
Port ins Internet. Der Shelly 3EM Gen1 kann kein verschlüsseltes MQTT, deshalb Klartext nur im LAN.

### 1. Mosquitto installieren

Einstellungen → Add-ons → Add-on Store → „Mosquitto broker“ (offiziell) installieren und starten. Danach
Einstellungen → Geräte & Dienste → unten rechts „+ Integration hinzufügen“ → „MQTT“ (Broker `core-mosquitto`,
Port 1883, Benutzer und Passwort aus Schritt 2). Add-on und Integration sind zwei verschiedene Dinge – das
Add-on ist der Broker, die Integration ist der Zugang von Home Assistant dorthin. Erst mit der Integration
sieht Home Assistant weiterhin die Shelly-Werte und es gibt die Seite `/config/mqtt` zum Mitlesen.
Gen-2-Shellys melden sich dort **nicht** selbst an (kein HA-Discovery); „0 Geräte“ ist also normal und für
die Bridge ohne Belang – sie abonniert die Topics direkt.

### 2. Eigene MQTT-Zugangsdaten anlegen

Mosquitto verwendet Home-Assistant-Benutzer. Unter Einstellungen → Personen → Benutzer einen eigenen
Benutzer anlegen (z. B. `mqtt-shelly`, „Nur lokal anmelden“, kein Administrator) und ein langes Passwort
vergeben. Denselben Benutzer tragen Shelly und Bridge ein. Das Passwort steht nirgends im Repository und
erscheint nicht in Protokollen.

### 3. Shelly 3EM konfigurieren

**Zuerst das richtige Gerät bestimmen.** Im Haus stehen zwei Shelly 3EM: der Wärmepumpenzähler
(HA-Gerät `heatpump_measurement`, aus dem der Template-Sensor `sensor.heatpump_total_power` gebildet wird) und
ein zweiter (`shellyem3_485519db56d2`). Gebraucht wird die Geräte-ID des **Wärmepumpen**-Zählers. Sie steht in
dessen Weboberfläche unter Settings → Device Info („Device ID“ bzw. Hostname `shellyem3-<ID>`) und in der
Topic-Vorschau der MQTT-Einstellungen. Die ID des zweiten Geräts (`485519DB56D2`) ist hier **nicht** gemeint.

Weboberfläche des Wärmepumpen-Shelly → Internet & Security → Advanced – Developer settings → „Enable action
execution via MQTT“: Server `<IP von Home Assistant>:1883`, Benutzer und Passwort aus Schritt 2, „Retain“ aus,
„Clean Session“ an, Update-Periode 30 s (der Shelly sendet Leistungen zusätzlich bei Änderung).

**Hinweis:** Beim Shelly 3EM Gen1 schaltet aktiviertes MQTT die Shelly-Cloud ab. Die Shelly-App funktioniert
dann nur noch im lokalen Netz.

### 4. Bridge konfigurieren

Optionen des Add-ons:

| Option | Bedeutung |
|---|---|
| `source_mode` | `mqtt` (Standard), `home_assistant` (bisheriger Weg) oder `compare` (beide, siehe unten) |
| `mqtt_host` / `mqtt_port` | Broker, im HA-Netz `core-mosquitto` und `1883` |
| `mqtt_username` / `mqtt_password` | Zugangsdaten aus Schritt 2 |
| `shelly_device_id` | Kennung des Geräts, z. B. `485519DB56D2` oder `shellyem3-485519DB56D2`. Wer lieber den ganzen Pfad einträgt, nimmt `mqtt_topic_prefix`, z. B. `shellies/shellyem3-485519DB56D2`. Beide Schreibweisen führen zum selben Ergebnis |
| `mqtt_publish_interval_s` | Takt, in dem die Bridge aus den zuletzt empfangenen Werten einen konsistenten Datensatz an die API schickt (Standard 10 s) |
| `mqtt_stale_s` | Funkstille, nach der ein Gerät als nicht verfügbar gilt (Standard 120 s) |
| `mqtt_qos` | Dienstgüte der Abonnements, Standard 1 (mindestens einmal) |
| `api_ws_url` / `api_token` | Railway-Endpunkt und Bridge-Token (unverändert) |
| `log_level` | `INFO` genügt; `DEBUG` zeigt verworfene Nachrichten |

Übertragen werden Gesamtleistung (Summe der drei Phasen, kW), Gesamtzählerstand Bezug und Rückspeisung
(Summe der `total`-/`total_returned`-Zähler, Wh → kWh) und je Phase Leistung, Spannung, Strom, Leistungsfaktor
und Zählerstände. Jeder Messwert trägt die Geräte-ID (`source: mqtt:shellyem3-<ID>`) und den Empfangszeitpunkt
der jüngsten enthaltenen Nachricht. `energy`/`returned_energy` (flüchtig) werden bewusst nicht verwendet.
Unplausible Werte (Bereich, fallende Zählerstände, unlesbare Nutzdaten) werden verworfen und gezählt; ein
`online: false` des Shelly oder 90 s Funkstille melden den Zähler als nicht verfügbar.

### 4b. Shelly Plus / Pro (Generation 2 und 3)

Geräte der Reihen **Plus** und **Pro** sprechen ein anderes Topic-Schema: statt einzelner Zahlen unter
`shellies/…` senden sie JSON-RPC-Nachrichten unter `<präfix>/events/rpc` (Meldungen `NotifyStatus` und
`NotifyFullStatus`) und – falls in der Geräteoberfläche eingeschaltet – zusätzlich einen Vollstand je
Komponente unter `<präfix>/status/<komponente>`. Die Bridge abonniert beides und wertet aus, was ankommt.

**Im Gerät einstellen** (Weboberfläche → Networks → MQTT): Server `<IP von Home Assistant>:1883`, Benutzer und
Passwort aus Schritt 2, „Enable MQTT Control“ nach Belieben, **„RPC status notifications over MQTT“ ein**
(sonst kommt nichts). „Generic status update over MQTT“ ist optional und schickt zusätzlich die
`status/…`-Topics. Das MQTT-Präfix (Standard: der Gerätename, z. B. `shellyplus1-b8d61a86e20c`) unverändert
lassen und genauso ins Mapping eintragen.

**Achtung, häufigste Fehlerquelle:** Das Präfix ist frei überschreibbar und in vielen Installationen auf
einen sprechenden Namen gesetzt. Es ist dann **nicht** die Gerätekennung. Ein Gerät mit der Kennung
`shellyplusplugs-d4d4daf36370` kann durchaus unter `Lichterkette_Terassenlicht/events/rpc` senden. Welches
Präfix gilt, steht in jeder Nachricht im Feld `dst` (die Kennung steht in `src`). Im Zweifel `#` abonnieren
und nachsehen, statt die Kennung zu raten.

**Im Mapping eintragen.** In `/config/duckcurve/entities.yaml` gibt es dafür den Abschnitt `mqtt:`. Er sagt,
welche Komponente des Geräts welchem Duck-Curve-Schlüssel entspricht:

```yaml
mqtt:
  # Generation 1 – dreiphasiger Zähler, braucht nur ein Schlüssel-Präfix
  - { prefix: "shellies/shellyem3-XXXXXXXXXXXX", generation: 1, kind: em3, key_prefix: heat_pump, label: "WP-Zähler" }

  # Generation 2 – Pufferspeicher, Shelly Plus 1 mit Temperatur-Add-on
  - prefix: "shellyplus1-b8d61a86e20c"
    generation: 2
    label: "Pufferspeicher"
    components:
      "temperature:100": buffer_temp_top_c     # natürlicher Wert der Komponente (°C)
      "temperature:101": buffer_temp_mid_top_c
      "temperature:102": buffer_temp_mid_bottom_c
      "temperature:104": buffer_temp_bottom_c

  # Mehrere Felder einer Komponente ausdrücklich zuordnen
  - prefix: "shellyplusplugs-d4d4daf36370"
    generation: 2
    label: "Licht Terrasse"
    components:
      "switch:0":
        apower: terrace_light_power_kw          # W → kW
        output: "actuator:terrace_light"        # true/false → 1/0
```

Je Komponententyp nimmt die Kurzform (`"temperature:100": buffer_temp_top_c`) das natürliche Feld:
`temperature` → `tC` (°C), `switch`/`cover`/`pm1` → `apower` (W → kW), `em1` → `act_power` (W → kW),
`humidity` → `rh` (%), `voltmeter` → `voltage` (V), `input` → `state` (an/aus → 1/0). Alles andere per
Langform mit dem Feldnamen aus dem JSON, verschachtelte Felder mit Punkt (`aenergy.total`, Wh → kWh).

**Komponenten-IDs herausfinden.** Die Nummern (100, 101, …) vergibt das Gerät in der Reihenfolge, in der die
Fühler angelernt wurden – sie sagen nichts über die Einbaulage. Am Broker mitlesen und zuordnen:

```
mosquitto_sub -h core-mosquitto -u <benutzer> -P <passwort> -t 'shellyplus1-b8d61a86e20c/#' -v
```

oder in Home Assistant über die Seite **`/config/mqtt`**, ganz unten der Abschnitt **„Ein Topic
abonnieren“** (früher „Auf ein Thema lauschen“). Dorthin führt das Zahnrad an der Integrationskachel; den
Knopf „Konfigurieren“ gibt es in neueren HA-Versionen nicht mehr, notfalls die URL direkt aufrufen, z. B.
`http://homeassistant.local:8123/config/mqtt`. „JSON-Inhalt formatieren“ einschalten, sonst kommt die
Gen-2-Nachricht als eine unlesbare Zeile. Meldet sich das Gerät nicht von selbst, im Abschnitt „Ein Paket
veröffentlichen“ eine Vollmeldung anfordern: Topic `<präfix>/rpc`, Payload
`{"id":1,"src":"ha","method":"Shelly.GetStatus"}`. Steht auf der Seite „Integration nicht eingerichtet“,
fehlt die MQTT-**Integration** (das Mosquitto-**Add-on** allein genügt nicht) – siehe Schritt 1.
Bequemer für mehrere Werte gleichzeitig ist der [MQTT Explorer](http://mqtt-explorer.com) vom PC aus.
Ein Fühler, der `unknown` bzw. `null` liefert, ist nicht angeschlossen und bleibt unbelegt.

Schlüssel, die im Abschnitt `mqtt:` vorkommen, holt die Bridge bei `source_mode: mqtt` **nicht mehr** aus Home
Assistant; die entsprechenden `sensors:`-Einträge bleiben als Rückfallebene für `source_mode: home_assistant`
stehen. Alle Geräte teilen sich eine einzige Broker-Verbindung.

**Hinweis:** Bei Gen 2/3 bleibt die Shelly-Cloud neben MQTT nutzbar (anders als bei Gen 1, siehe Schritt 3).

### 4c. Wenn nichts ankommt: das Mosquitto-Protokoll lesen

Einstellungen → Add-ons → Mosquitto broker → Reiter **Protokoll**. Es sagt für jedes Gerät genau, woran es
liegt – Raten erübrigt sich:

| Zeile im Protokoll | Bedeutung | Abhilfe |
|---|---|---|
| `New client connected … as <gerät> … u'<benutzer>'` | alles in Ordnung | – |
| `received null username or password` | Der Shelly schickt kein Passwort. Ein gespeichertes Passwort zeigt Shelly nie wieder an, ein leeres und ein gefülltes Feld sehen deshalb gleich aus | Passwort im Gerät neu eintippen, speichern, **Gerät neu starten** |
| `disconnected: not authorised` | Benutzer oder Passwort falsch (Groß-/Kleinschreibung zählt) | Benutzer muss ein echter HA-Benutzer sein; nach dem Anlegen das Mosquitto-Add-on neu starten |
| Das Gerät kommt gar nicht vor | Es versucht es nicht einmal | „Enable“ im Gerät gesetzt? Server-IP und Port 1883 richtig? Nach dem Speichern neu gestartet? Gerät im Netz? |
| `disconnected: session taken over` | Zwei Verbindungen mit derselben Kennung – beim Wiederverbinden normal, dauerhaft ein Zeichen für doppelt vergebene Client-IDs | – |

Verbindungen von `172.30.32.x`, die sofort wieder schließen, sind die Erreichbarkeitsprüfung des
Supervisors und harmlos.

Zum Port: `1883` ist Klartext, `8883` TLS. Solange „SSL connectivity“ im Gerät **nicht** angehakt ist, ist
1883 richtig. Bei falschem Port käme keine Verbindung zustande und das Gerät meldete „disconnected“ – ein
Gerät, das „connected“ zeigt, hat Adresse, Port und Zugangsdaten also bereits bestätigt.

### 5. MQTT-Empfang testen

Im Add-on-Protokoll erscheint `mqtt connected` und alle 5 Minuten `mqtt status` mit `messages`, `rejected`,
`reconnects`, `emitted`. Auf der Wärmeseite von Duck Curve Home muss die Wärmepumpenleistung mit Quelle
`mqtt:shellyem3-…` erscheinen (Live-Zustand, Feld `source`). Alternativ mit dem MQTT-Werkzeug von Home
Assistant auf der Seite `/config/mqtt` („Ein Topic abonnieren“)
`shellies/shellyem3-<ID>/#` beobachten. `mqtt status` führt jedes Gerät einzeln auf, Gen-2-Geräte mit der
Anzahl erkannter Komponenten.

### 6. Kontrollierter Wechsel

1. `source_mode: compare` setzen und neu starten: die API bekommt weiter die HA-Werte, die Bridge misst
   parallel den MQTT-Wert und schreibt Abweichungen über 50 W bzw. 5 % als Warnung ins Protokoll, dazu alle
   60 Vergleiche eine Zusammenfassung (`compare summary`). Nichts wird doppelt gesendet.
2. Nach ein bis zwei Tagen ohne systematische Abweichung `source_mode: mqtt` setzen. Ab dann kommt
   `heat_pump_power_kw` nur noch aus MQTT; der HA-Sensor `sensor.heatpump_total_power` wird für diesen
   Schlüssel ignoriert (das Mapping in `entities.yaml` kann unverändert bleiben).

Der Vergleich (`compare`) betrifft nur den dreiphasigen Zähler. Gen-2-Geräte liefern in `compare` nichts an
die API; ihre Schlüssel kommen dort weiter aus Home Assistant.

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
