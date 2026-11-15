# Duck Curve eBUS

Liest den Bus der Wärmepumpe und legt die Werte auf den Mosquitto-Broker. Die Duck Curve Bridge
holt sie dort ab. Home Assistant braucht dafür nur den Broker, keine weitere Integration. Das
Add-on verstellt nichts an der Heizung; seit 0.3.0 fragt es einige Werte selbst ab (Abschnitt
„Abfragen, ohne zu verstellen“).

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
Kennzahl des Reglers (ab 0.2.2; bestätigt sind 0 Bereitschaft und 2 Heizen), die Kennung 1b45
und die Vorgaben des Reglers an die Maschine (ab 0.2.3, Bedeutung teils offen), die
Außentemperatur im Rundruf, zwei Temperaturen des Reglers und seine Speichertemperatur. Sie sind aus dem Protokoll des Hauses gelesen und an dessen Telegrammen geprüft; auch
sie lesen nur mit. Sie liegen im Abbild und werden bei jedem Start neben die Bus-Beschreibung
gelegt. Ab 0.3.0 kommen vier Fragen dazu (`aerotop_abfragen.csv`).

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
       [duckcurve-ebusd] Abfragen an: ebusd fragt 17 Werte reihum ab, alle 10 s einen.
       [duckcurve-ebusd] Stellen kann ebusd nichts: 67 Zeilen zum Stellen aus der Bus-Beschreibung entfernt, keine übrig.
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
| `read_only` | an | Nichts verstellen. ebusd kennt dann keine einzige Zeile zum Stellen (siehe unten). |
| `abfragen` | an | Vier Werte selbst abfragen, die sonst nie über den Bus gehen. Aus heißt: nur lauschen, kein Wort auf dem Bus. |
| `abfrage_takt_s` | 10 | Abstand zwischen zwei Abfragen in Sekunden (5 bis 300). Je Abfrage ist ein Wert dran. |
| `latency_ms` | 120 | Wie lange ebusd auf den Adapter wartet. Über WLAN nicht verkleinern. |
| `mqtt_host`, `mqtt_port` | `core-mosquitto`, 1883 | Der Broker. |
| `mqtt_username`, `mqtt_password` | leer | Leer heißt: der Supervisor nennt den Zugang. Sonst dieselben Werte wie in der Bridge. |
| `mqtt_topic` | `ebusd` | Unter diesem Thema stehen die Werte. Muss zu `prefix` in der Zuordnung passen. |
| `config_ref` | leer | Fassung der Bus-Beschreibung. Leer heißt: die geprüfte. |
| `log_level` | `notice` | `info` oder `debug` nur zur Fehlersuche; `debug` schreibt sehr viel. |
| `extra_args` | leer | Weitere Schalter für ebusd, je einer pro Eintrag, z. B. `--lograwdata=bytes`. |

Eigene Dateien für die Bus-Beschreibung gehen vor: liegen `*.csv` in
`/config/duckcurve/ebusd/`, nimmt das Add-on diese und lädt nichts.

## Abfragen, ohne zu verstellen

Bis 0.2.3 hörte das Add-on nur zu: es sah, was der Regler reihum meldet und was die Geräte am
Bus einander fragen. Vier Größen gehen so nie über den Bus, weil das Bediengerät sie nicht
abfragt. Seit 0.3.0 fragt ebusd sie selbst (Entscheidung des Hausherrn vom 14.11.2026):

| Thema am Broker | Kennung, Ziel | Was es laut Bus-Beschreibung ist |
|---|---|---|
| `ebusd/energymgr/ventil_ww` | 0601, Regler | Umschaltventil: 0 Warmwasser, 1 Heizung |
| `ebusd/energymgr/heizstab` | 1c45, Regler | elektrische Zusatzheizung: 0 aus, 1 an |
| `ebusd/heatpump/verdichter_strom` | 714f, Wärmepumpe | Strom des Verdichters in Ampere |
| `ebusd/heatpump/luefter` | 6e4f, Wärmepumpe | Drehzahl des Lüfters |
| `ebusd/heatpump/hp_betrieb` | Liste 7810 6e13 ca46 cb46, Wärmepumpe | Außentemperatur, Durchfluss, Betriebszustand, Verdichterfrequenz (ab 0.3.1) |

Die letzte Zeile ist keine neue Größe: es ist die Frage, die der Regler der Maschine selbst
stellt (im Haus gesehen, mit Antwort), nur stellt er sie selten. Die Seite der Wärmepumpe hatte
die Verdichterfrequenz deshalb nur zufällig; am 15.11.2026 fehlte sie nach einem Neustart der
Bridge ganz („der Umrichter hat keine Frequenz mehr“). Ab 0.3.1 fragt das Add-on sie mit und
liest weiter mit, wenn der Regler fragt.

Die Bedeutungen der vier Zeilen davor stammen aus der Bus-Beschreibung für verwandte Geräte. Was die Zahlen in diesem
Haus heißen, zeigt erst der Vergleich mit Speicher und Zähler; bis dahin zeigt die Oberfläche
die Zahl. Die Zeilen stehen in `aerotop_abfragen.csv`; mit `abfrage_takt_s: 10` sind Ventil,
Heizstab und Betriebszustand je etwa alle 40 Sekunden dran, Strom und Drehzahl seltener.

**Ab 0.4.0 dazu die Einstellungen des Reglers**, nur gelesen und selten (jede etwa alle
zehn Minuten): Steilheit und Verschiebung der Heizkurve, kleinster, größter und fester Vorlauf,
Art der Vorlaufregelung, Raumtemperatur Tag und Nacht, Warmwasser Komfort- und Spartemperatur,
Betriebsart des Warmwassers, Flüstermodus (Themen `ebusd/energymgr/e_...`). Die Seite „Regler“
zeigt sie. Kennungen und Zahlenformate stammen aus der Bus-Beschreibung für verwandte Geräte;
ob sie stimmen, zeigt der Vergleich mit dem Bediengerät. Verstellt wird damit nichts.

ebusd zählt eine mitgehörte Antwort wie eine eigene Abfrage: fragt der Regler etwas ohnehin oft,
fragt das Add-on es entsprechend seltener selbst (im Probelauf am 15.11.2026 gesehen).

**Was sich dabei ändert.** ebusd meldet sich als eigener Teilnehmer am Bus (Adresse 31) und
stellt alle zehn Sekunden eine Frage, so wie es das Bediengerät ohnehin mehrmals je Sekunde
tut. Im Protokoll steht dazu:

    [duckcurve-ebusd] Abfragen an: ebusd fragt 17 Werte reihum ab, alle 10 s einen.
    [duckcurve-ebusd] Stellen kann ebusd nichts: 67 Zeilen zum Stellen aus der Bus-Beschreibung entfernt, keine übrig.

**Warum es trotzdem nichts verstellen kann.** Wer abfragt, sendet; der Schalter `--readonly`
von ebusd fällt deshalb weg. Damit daraus kein Weg zum Verstellen wird, entfernt das
Startskript bei jedem Start jede Zeile zum Stellen aus der Arbeitsfassung der Bus-Beschreibung
und startet nicht, wenn danach noch eine übrig ist. Die Schalter `--enablehex` und
`--enabledefine` (beliebige Telegramme) lehnt es mit `read_only` ab. Geprüft am 14.11.2026 mit
ebusd 26.1 am Übungsadapter: eine Stellnachricht über den Broker
(`ebusd/energymgr/dhw_status/set`) führte zu keinem Telegramm; in der Gegenprobe mit
`read_only: false` sendete ebusd daraufhin `31fe2020...`.

**Die Bridge einmal neu starten.** Sie liest die Zuordnung der Werte nur beim Start. Ohne
Neustart kennt sie die vier neuen Themen nicht und gibt sie nicht weiter: auf der Seite der
Wärmepumpe steht dann weiter „Lüfter · nicht gemessen“, auch wenn das Add-on fragt und Antwort
bekommt. (Am 15.11.2026 stand das im Haus so da, und die erste Anleitung hatte den Neustart
nicht genannt; ob er die Ursache war, ist nicht festgestellt.)
Der Dienst muss die Fassung mit den vier Reihen haben (neu ausrollen).

**Wenn ebusd die Fragen nicht annimmt**, steht im Protokoll `ebusd nimmt die Zeilen zum Abfragen
nicht an`, und das Add-on lauscht nur. **Wenn der Bus die Fragen nicht beantwortet**, zeigt die
Seite der Wärmepumpe für Ventil, Heizstab, Strom und Lüfter weiter nichts an, und im Protokoll
(mit `log_level: info`) steht statt `sent poll-read ...` ein `ERR:`. Stören die Abfragen den Bus
(Fehler am Bediengerät, mehr `ERR:`-Zeilen als vorher), `abfragen` ausschalten: dann ist alles
wie vor 0.3.0.

**Nicht geprüft:** an der echten Wärmepumpe. Dass Regler und Wärmepumpe auf eine einzelne
Abfrage mit einem Byte Status und dann dem Wert antworten, ist an Abfragen des Bediengeräts im
Haus gesehen (Durchfluss, Betriebszustand, Ventil Heizen/Kühlen); für die vier Kennungen hier
ist es übertragen.

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

Am 14.11.2026, ebenfalls ohne Heizung, die Abfragen von 0.3.0: der Übungsadapter gibt ebusd den
Bus frei und antwortet als Regler und Wärmepumpe. ebusd 26.1 fragte die vier Werte reihum ab
(`sent poll-read energymgr ventil_ww QQ=31: 1` und so fort), legte sie auf den Broker, und die
Software der Bridge machte daraus `heat_pump_valve_code = 1`, `heat_pump_heater_code = 0`,
`heat_pump_compressor_a = 7,8` und `heat_pump_fan_speed = 600`. Zwei Fehler zeigte erst dieser
Lauf: ebusd nimmt eine Kennung nur einmal (die fremden Zeilen mit denselben Kennungen müssen
weichen), und sein Rückgabewert bei der Prüfung der Bus-Beschreibung taugt nicht als Urteil.

Am 15.11.2026 derselbe Lauf mit 0.3.1: die fünfte Frage ging hinaus
(`sent poll-read heatpump hp_betrieb QQ=31: 6.5;30.1;3;64`), und dieselbe Zeile las weiter mit,
wenn der Regler fragte (`received poll-read heatpump hp_betrieb QQ=13: ...`).
