# Duck Curve eBUS

Liest den Bus der Wärmepumpe und legt die Werte auf den Mosquitto-Broker. Die Duck Curve Bridge
holt sie dort ab. Home Assistant braucht dafür nur den Broker, keine weitere Integration.

## Was hier läuft

Das Programm, das die Sprache des Busses versteht, ist **ebusd** von John Baier
(`github.com/john30/ebusd`). Dieses Add-on verpackt es nur: es holt ebusd fertig gebaut aus dem
Abbild seines Autors, baut aus den Optionen unten seine Befehlszeile und startet es. Gelernt am
Add-on von Lukas Grebe (`github.com/LukasGrebe/ha-addons`), das dasselbe allgemeiner tut.

Die Beschreibung des Busses (welches Telegramm welchen Wert bedeutet) stammt aus dem Projekt
`wrongisthenewright/ebusd-configuration-ariston-bridgenet`. Sie wird beim ersten Start in einer
festgelegten, geprüften Fassung geladen und mit einer Prüfsumme verglichen. Sie wurde an einer
anderen Anlage derselben Gerätefamilie erarbeitet; welche ihrer Werte die eigene Wärmepumpe
meldet, zeigt erst der Betrieb.

Dazu kommen eigene Zeilen für die Wärmepumpe dieses Hauses (`aerotop_split.csv`, ab 0.2.0):
Leistungsaufnahme, Sauggas und Heißgas, Verdichterfrequenz und Betriebszustand (ab 0.2.1), die
Betriebsart des Reglers (Heizen, Warmwasser, PV-Nutzung; ab 0.2.2), die
Außentemperatur im Rundruf, zwei Temperaturen des Reglers und seine Speichertemperatur. Sie sind aus dem Protokoll des Hauses gelesen und an dessen Telegrammen geprüft; auch
sie lesen nur mit. Sie liegen im Abbild und werden bei jedem Start neben die Bus-Beschreibung
gelegt.

## Voraussetzungen

1. Ein Netzwerk-Adapter am Bus der Wärmepumpe (eBUS Adapter Shield C6), im WLAN, mit fester
   Adresse. Auf seiner eigenen Seite muss „eBUS signal: acquired“ stehen.
2. Das Add-on „Mosquitto broker“ läuft.
3. Duck Curve Home Bridge ab 0.14.0.

## Einrichten

1. Unter **Konfiguration** bei `adapter` eintragen, was die Seite des Adapters als „ebusd device
   string“ nennt, ohne Anführungszeichen, zum Beispiel `ens:192.168.1.50`.
2. Speichern und starten.
3. Im **Protokoll** sollte nach wenigen Sekunden stehen:

       [duckcurve-ebusd] Bus-Beschreibung geladen und geprüft (Fassung f2c9a631c1b0).
       [duckcurve-ebusd] Nur lesend: ebusd schreibt nichts auf den Bus.
       ... [bus notice] signal acquired
       ... [mqtt notice] connection established
       ... [update notice] received update-read energymgr ext_temp QQ=..: 8.6

   Die Zeilen mit `received update-read` sind die Werte. Auf der Seite des Adapters steht dann
   „ebusd connected: yes“.
4. Im Protokoll der **Duck Curve Home Bridge** steht je Wert einmal eine Zeile `ebusd meldet` mit
   Namen und Zahlen. Aus diesen Zeilen entsteht die Zuordnung in `config/entities.home.yaml`.

## Optionen

| Option | Voreinstellung | Bedeutung |
|---|---|---|
| `adapter` | leer | Der Adapter, z. B. `ens:192.168.1.50`. Pflicht. |
| `read_only` | an | Nur lauschen. ebusd schreibt dann nichts auf den Bus, auch keine Abfragen. |
| `latency_ms` | 120 | Wie lange ebusd auf den Adapter wartet. Über WLAN nicht verkleinern. |
| `mqtt_host`, `mqtt_port` | `core-mosquitto`, 1883 | Der Broker. |
| `mqtt_username`, `mqtt_password` | leer | Leer heißt: der Supervisor nennt den Zugang. Sonst dieselben Werte wie in der Bridge. |
| `mqtt_topic` | `ebusd` | Unter diesem Thema stehen die Werte. Muss zu `prefix` in der Zuordnung passen. |
| `config_ref` | leer | Fassung der Bus-Beschreibung. Leer heißt: die geprüfte. |
| `log_level` | `notice` | `info` oder `debug` nur zur Fehlersuche; `debug` schreibt sehr viel. |
| `extra_args` | leer | Weitere Schalter für ebusd, je einer pro Eintrag, z. B. `--lograwdata=bytes`. |

Eigene Dateien für die Bus-Beschreibung gehen vor: liegen `*.csv` in
`/config/duckcurve/ebusd/`, nimmt das Add-on diese und lädt nichts.

## Nur lesend, und was das heißt

Mit `read_only` hört ebusd nur zu: es sieht, was der Regler reihum meldet und was die Geräte am
Bus einander fragen. Es stellt selbst keine Fragen und kann nichts verstellen. Geprüft am
13.11.2026 an einem nachgestellten Adapter: in dieser Betriebsart gehen genau zwei Nachrichten
an den Adapter selbst (Anmeldung und Abfrage seiner Fassung) und keine einzige auf den Bus.

Der Preis: Werte, die niemand von sich aus meldet oder abfragt, bleiben unsichtbar. Ob das für
dieses Haus reicht, zeigt die Liste aus Schritt 4. Erst wenn feststeht, was fehlt, lohnt die
Frage, ob ebusd selbst fragen soll.

## Wenn etwas nicht geht

| Im Protokoll | Bedeutung |
|---|---|
| `Option 'adapter' ist leer` | Schritt 1 fehlt. |
| `Die Bus-Beschreibung ... ließ sich nicht laden` | Kein Netz beim ersten Start. Später erneut starten oder die Dateien nach `/config/duckcurve/ebusd/` legen. |
| `stimmt nicht mit der geprüften Fassung überein` | Die geladene Datei ist nicht die erwartete. Sie wird nicht verwendet. |
| `Der Supervisor nennt keinen Broker` | Mosquitto läuft nicht, oder Name und Passwort von Hand eintragen. |
| `signal lost` / kein `signal acquired` | Der Adapter sieht den Bus nicht oder ist nicht erreichbar: Adresse, WLAN, Klemmen prüfen. |
| `signal acquired`, aber kein `received` | Der Bus spricht, die Bus-Beschreibung erkennt die Telegramme nicht. Mit `log_level: info` erscheinen sie als `received unknown ...`; diese Zeilen sind dann der Befund. |
| viele `ERR:`-Zeilen | Meist die Funkstrecke zum Adapter. Besserer Empfang hilft mehr als jede Einstellung. |

## Geprüft

Am 13.11.2026, ohne Heizung: ein nachgestellter Adapter (`tools/ebus_uebungsadapter.py`) spielt
zwei Telegramme im Takt eines echten Busses, dieses Add-on liest sie nur lesend, ein Mosquitto
nimmt sie entgegen, und die Software der Bridge macht daraus mit der Zuordnung des Hauses
`outdoor_temp_c = 8,6` und `flow_temp_c = 35,2`. An der echten Wärmepumpe ist es damit noch
nicht gelaufen.
