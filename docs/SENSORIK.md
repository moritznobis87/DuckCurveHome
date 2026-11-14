# Sensorik: Bestand, Lücken, Einkaufsliste

Was gemessen wird, was geschätzt wird und was zu kaufen wäre, um aus Schätzung Messung zu machen.

## Anlage

| Gerät | Typ | Anmerkung |
| --- | --- | --- |
| Wärmepumpe | **ELCO AEROTOP SPLIT WH 09-11** (Luft/Wasser, 4-11 kW) | Regelung der Ariston-Gruppe mit BridgeNet-Bus (eBUS) auf den Klemmen B und T, am 13.11.2026 am Gerät bestätigt; die frühere Angabe „LOGON B WP61 = Siemens RVS 61.843“ war nie geprüft und trifft nicht zu, siehe „Warum kein Bus hilft“. Ansteuerung über K1-Kontakt (SG-Ready-ähnlich) |
| Pelletofen | **MCZ Star Hydromatic** (wasserführend) | speist denselben Puffer |
| Pufferspeicher | 1000 l Kombipuffer | WP und Ofen speisen ein, Heizung und Warmwasser entnehmen |

## Was gemessen wird

Strom (PV, Netz, Batterie, Wärmepumpe, Wallbox, Haus), Batterie-SOC, vier Puffertemperaturen,
Außentemperatur, Strompreis, Schaltzustände. Minutenauflösung, dauerhaft (siehe `DATENHALTUNG.md`).

### Der Netzanschluss wird doppelt gemessen

Den Netzwert liefert bisher ein Stromwandler des Speichers. Seit dem Einbau des inexogy-Smartmeters
gibt es dieselbe Größe ein zweites Mal, gemessen vom **amtlichen Zähler** - dem Gerät, nach dem
abgerechnet wird.

Führend bleibt vorerst der Wandler. Der Zähler läuft auf eigenen Schlüsseln mit
(`grid_power_meter_kw`, `grid_import_meter_kwh`, `grid_export_meter_kwh`) und ändert an keiner
Bilanz etwas. Zuerst ist zu beantworten, wie stabil er überträgt - der vorige Zähler hatte
Verbindungsabbrüche -, und danach, wie weit die beiden auseinanderliegen. Beides setzt getrennte
Reihen voraus: liefe der Zählerwert nach `grid_power_kw`, verglichen wir ihn mit sich selbst.

**Anmeldung.** Kontomail und Kontopasswort über HTTP Basic gegen `https://api.inexogy.com/public/v1`.
Einen API-Schlüssel gibt es dort nicht; die dokumentierte OAuth-1.0a-Kette wäre vier Aufrufe für
dasselbe Ergebnis, und Basic nimmt der Server an. Die Zugangsdaten stehen in `DCH_INEXOGY_EMAIL`
und `DCH_INEXOGY_PASSWORD` in der Umgebung des Dienstes, nirgendwo sonst. `DCH_INEXOGY_METER` ist
optional und nimmt `meterId` oder eine der Seriennummern; ohne Angabe gewinnt der Zähler, der
zuletzt gemeldet hat.

**Zwei Fallstricke.** Die API nimmt nur den 32-stelligen `meterId` aus `/meters`, nicht die
Seriennummer - daran ist evcc nach der Umbenennung von Discovergy gescheitert. Und sie erlaubt je
IP nur **eine gleichzeitige Verbindung**; der Client hält deshalb genau eine offen und
serialisiert seine Aufrufe.

**Die Einheiten stehen nicht in der Beschreibung.** `power` in Milliwatt und die Zählerstände in
Zehnmilliardstel Kilowattstunden sind aus den Clients des Ökosystems geschlossen, nicht aus einer
Zusage des Herstellers. Deshalb prüft die Übersetzung jeden Wert gegen eine Plausibilitätsgrenze:
stimmt der Faktor nicht, liegt das Ergebnis um Zehnerpotenzen daneben, die Reihe bleibt leer und im
Protokoll steht, was ankam. Eine Messreihe, die aussieht wie eine Messreihe und um den Faktor
tausend falsch ist, wäre hier der teuerste Fehler.

### Die Haustür hängt ebenfalls an der Bridge

Gesichtsscan am UniFi-Access-Reader öffnet das Nuki-Schloss, beides im Heimnetz und ohne Cloud.
Das ist keine Messung, steht aber hier, weil es dieselbe Bridge trägt: siehe `TUEROEFFNUNG.md`.

### Die Einzelraumregelung wird mitgelesen

Das Haus hat eine Fußbodenheizung mit Einzelraumregelung von **Controme**: ein Mini-Server auf
einem Raspberry Pi, zwei Gateways (Erdgeschoss, Obergeschoss) und je Raum ein Fühler sowie ein
oder mehrere thermoelektrische Antriebe am Heizkreisverteiler. Die Hardware ist durchweg von
Dritten - Fühler von Danfoss, Antriebe Möhlenhoff Alpha 5 (230 V, stromlos geschlossen), als
Gateway ein Arduino Mega 2560. Gemessen am 21.10.2026.

Seit dem 22.10.2026 liest die Bridge diesen Server mit: je Raum Temperatur, Sollwert, Offset,
Luftfeuchte und der Anteil der offenen Heizkreise. **Damit bekommt die Pufferentnahme Zeugen.**
Bisher war sie eine einzige Zahl, die als Rest einer Umkehrrechnung herausfiel; jetzt steht
daneben, welcher Raum wann Wärme gezogen hat.

**Die Lese-Endpunkte antworten im Heimnetz ohne Anmeldung** (gemessen am 21.10.2026). Das ist eine
Schwäche von Controme, keine Einladung: Die Quelle nimmt deshalb optional Benutzername und
Passwort entgegen, damit sie weiterläuft, wenn Controme das eines Tages repariert.

**Ventile stellt weiter Controme, den Sollwert stellt seit dem 23.10.2026 auch DCH.** Für
Ausgänge hat die Schnittstelle nur Lese-Endpunkte, und das ist richtig so: Der Fußboden hat
Zeitkonstanten um 13 Stunden, der Raum um 25; auf dieser Skala gewinnt niemand durch feinere
Ventiltaktung. Der Sollwert dagegen ist der Griff, den auch ein Mensch benutzt, und er ist der
Zugang zum Haus als Wärmespeicher.

```
POST http://<mini-server>/set/json/v1/<haus>/soll/<raum>/
Formularfelder: user, password, soll
```

Belegt durch laufenden Code zweier fremder Projekte (openHAB-Anbindung, Loxone-Forum), nicht durch
Contromes eigene Beschreibung. Drei Eigenheiten, alle drei schon einmal jemandem begegnet: Der
Schrägstrich am Ende gehört dazu; der Wert muss eine nackte Zahl mit Punkt sein, sonst kommt ein
`403` ohne Begründung; und **zum Schreiben sind die Zugangsdaten Pflicht**, anders als zum Lesen.

Gestellt wird **dauerhaft**, ohne Frist, zwischen 5 und 30 Grad und auf Zehntel gerundet (die
Anlage führt Zehntel: ein Raum steht auf 22,2, ein anderer auf 8,0 Frostschutz). Controme kennt auch einen Sollwert auf Zeit; er wäre eine
zweite Wahrheit neben der, die der Regler kennt, und ein Programm, das ohnehin bei jedem Takt neu
entscheidet, braucht ihn nicht. Wer anhebt, nimmt selbst wieder zurück. Jede Änderung steht als
Ereignis `rooms.setpoint` mit altem und neuem Wert in der Datenbank.

**Was das Anheben bedeutet, rechnet `hems_core.thermal.room_shift`.** Das Modell steht auf drei
Zahlen: dem Verlustkoeffizienten des Hauses aus den Wärmeannahmen (0,22 kW/K, geschätzt), dem
Anteil eines Raums nach seinen Heizkreisen, und der Zeitkonstante des Raums von rund 25 Stunden.
Aus den letzten beiden folgt die Wärmekapazität, denn eine Zeitkonstante ist Kapazität durch
Verlust: `C = tau * H`, für dieses Haus rund 5,5 kWh je Kelvin. Damit lässt sich beantworten, was
ein halbes Grad mehr am Tag kostet und was es bringt, es vor einem Preishoch einzulagern. Alle
Zahlen sind Schätzungen und heißen in der Anzeige auch so.

Der eigentliche Hebel bleibt die Vorlauftemperatur, und wer sie senken will, muss wissen, welcher
Raum zuerst nicht mehr mitkommt. Genau das zeigen die Ventilstellungen.

**Geregelt wird auf Sollwert plus Offset.** Controme meldet `solltemperatur` und `total_offset`
getrennt, und die Frage, ob der Regler auf die Summe regelt, war eine Zeitlang offen. Contromes
eigene Oberfläche beantwortet sie: In einem Raum steht dort `21,00 - 0,32` und darunter `20,68`
als Zielwert (Bildschirmfoto der Anlage, 22.10.2026). Die Rechnung geht genau auf - das ist keine
Messung, sondern Arithmetik. Damit deckt sich die FPS-Beschreibung des Herstellers, die
`ziel = soll + offsets` definiert.

Beide Zahlen werden trotzdem **einzeln** mitgeschrieben, und die Raumseite stellt sie unter den
Zielwert. Denn eines ist noch offen: **das Vorzeichen in den Daten**. Die Oberfläche setzt das
Rechenzeichen selbst und zeigt daneben einen Betrag; ob `total_offset` in der Schnittstelle schon
vorzeichenbehaftet ankommt, sagt sie nicht. Addiert wird, weil eine Schnittstelle, die die
Richtung einer Anpassung nicht ausdrücken kann, keine wäre. Stimmt es nicht, liegt der Zielwert um
das Doppelte des Offsets daneben - und das fällt beim Vergleich mit Contromes eigener Anzeige
sofort auf, weil die Raumseite die Rechnung mit ausdruckt.

**`total_offset` ist eine Summe, nicht die Witterungsführung.** Neben dem Wert steht ein Feld
`offsets` mit benannten Quellen; gesehen wurde dort `Geolocation`, also eine Anpassung nach
Anwesenheit. Witterung mag eine weitere sein. Die Einzelquellen werden heute nicht übertragen -
wer wissen will, *warum* der Zielwert gesenkt wurde, muss sie nachziehen.

**Fenster stehen daneben, und sie kommen woanders her.** Controme weiß nichts von Fenstern. Die
Kontakte der Lupusec-Alarmanlage kommen über die Home-Assistant-Integration und werden unter der
Controme-Kennung ihres Raums gemeldet (`room_<id>_window`, 1 heißt offen, seit dem 23.10.2026).
Das beantwortet eine Frage, die die Raumseite sonst falsch stellt: Ein Raum unter seinem Ziel mit
offenen Kreisen sieht aus wie einer, für den die Vorlauftemperatur nicht reicht - auch dann, wenn
schlicht gelüftet wird. Solange ein Kontakt offen meldet, steht das in der Kachel, und die
Markierung „an der Grenze" bleibt aus. Räume ohne Kontakt melden nichts; dort steht auch nichts.

**Was noch fehlt.** Es gibt einen Endpunkt `rltemps` mit **Rücklauftemperaturen je Raum** - belegt
durch laufenden Code dritter Projekte, nicht nur durch Dokumentation. Zusammen mit den
Ventilstellungen wäre das der zweite Zeuge für die Pufferentnahme. Der Vorbehalt: Ein Rücklaufwert
sagt nur etwas, solange das Ventil dieses Raums offen ist.

## Was geschätzt wird - die eigentliche Lücke

Das System kennt den **Strom** der Wärmepumpe, aber nicht die **Wärme**. Folge:

* Der COP kommt aus einer Kennlinie (`cop_at`), nicht aus einer Messung.
* Der Hausverlust (`heat_loss_kw_per_k`) und der Warmwasserbedarf (`dhw_kwh_per_day`) sind Annahmen,
  die nie mit der Wirklichkeit abgeglichen wurden.
* **Der Anteil des Pelletofens an der Pufferladung ist nicht quantifizierbar.** Wer geladen hat,
  verrät die Leistungsmessung der Wärmepumpe noch. Wie viel jeder von beiden beigetragen hat, nicht.
  Solange das so ist, verfälscht der Ofen jede Wärmebilanz und jede COP-Schätzung. Die Ofendaten aus
  dem Maestro-Modul lösen genau das, siehe Einkaufsliste Punkt 3.

Ohne gemessene Wärme lässt sich auch nicht sagen, ob die Wärmepumpe die Arbeitszahl liefert, für die
sie gekauft wurde. Eine Anlage, die 2,8 statt 3,5 fährt, kostet bei 4000 kWh Jahresverbrauch rund
250 € im Jahr - und fällt ohne Wärmemengenzähler niemandem auf.

## Die Heizkreispumpe kann Volumenstrom, gratis

Die COSMO-Umwälzpumpe im Heizkreis hat ein Display mit den Einheiten `W`, `m³/h` und `m`. Die
MODE-Taste schaltet zwischen ihnen um. Damit ist der **Volumenstrom des Heizkreises** ohne jede
Anschaffung ablesbar, und mit ihm die Wärmeleistung ins Haus:

```
Q [kW] = V [m³/h] × 1,163 × ΔT [K]        (Wasser, ΔT = Vorlauf minus Rücklauf)
Beispiel: 0,8 m³/h bei 7 K Spreizung  =  6,5 kW
```

Zwei Dinge sind dabei wichtig:

* **Die Pumpe sitzt hinter dem Puffer**, nicht zwischen Wärmepumpe und Puffer. Sie misst also, was
  ins Haus geht, nicht was die Wärmepumpe erzeugt. Für die Arbeitszahl taugt der Wert nicht, für
  `heat_loss_kw_per_k` dagegen sehr wohl: an einem kalten Abend ohne Ofenbetrieb und ohne
  Warmwasserladung ist H = Q / (Raumtemperatur minus Außentemperatur), und der aktuelle Wert 0,22
  kW/K ist bis heute nichts als eine Schätzung.
* **Auslesbar ist die Pumpe nicht.** Diese Baureihe hat einen PWM-Eingang zur Ansteuerung, aber
  keine Datenschnittstelle nach außen: kein M-Bus, kein Modbus. Der Wert ist ein Handablesewert.
  Dauerhaft kommt der Volumenstrom ohnehin aus dem Wärmemengenzähler.

Für die Auslegung des Zählers an der **Wärmepumpe** taugt der Wert dagegen nicht. Zwischen beiden
liegt der Puffer, die Volumenströme sind hydraulisch entkoppelt. Der WP-Kreis wird aus Nennleistung
und Auslegungsspreizung gerechnet (siehe Einkaufsliste), nicht aus dem, was die Heizkreispumpe
fördert. Der Ablesewert bemisst allein einen künftigen zweiten Zähler im Heizkreis.

### Der Heizkreis ist gemischt, und das ist die eigentliche Nachricht

Der Kasten neben der Pumpe ist keine Zeitschaltuhr, sondern eine Heizungsregelung, die das
Vierwegeventil darunter stellt. Sie mischt dem Heizkreis eine Vorlauftemperatur zu, die Pumpe
versorgt damit zwei Heizkreisverteiler.

Für den Planer heißt das: **das Haus ist keine schaltbare Last.** Wie viel Wärme ins Haus geht,
bestimmt die Heizkurve über die Vorlauftemperatur, nicht wir. Der Puffer lässt sich nicht auf Zuruf
schneller entladen, weil gerade billiger Strom da ist. Verschiebbar ist nur die Ladeseite, also wann
die Wärmepumpe den Puffer füllt. Genau so ist der Optimierer auch gebaut, die Annahme ist damit
bestätigt und nicht bloß gesetzt.

Für die Messung heißt es: der Volumenstrom des Heizkreises ist von der Wärmeleistung entkoppelt.
Bei gemischtem Kreis wird die Leistung über die Vorlauftemperatur geregelt. Wärme ohne Spreizung
abzuschätzen geht deshalb nicht, es braucht Vorlauf und Rücklauf.

### Betriebsart der Pumpe: Δp-c

An den beiden Verteilern sitzen Stellantriebe, die einzelne Kreise auf- und zufahren. Damit ist der
hydraulische Widerstand veränderlich, und die richtige Betriebsart ist **Konstantdruck (Δp-c)**,
Sollwert-Förderhöhe rund 2 m als Startpunkt.

Eine feste Drehzahl wäre hier falsch. Schließen Zonen, stiege der Differenzdruck, die verbleibenden
Kreise würden überströmt, es rauscht, und das Überströmventil geht auf. Der bequeme Sonderfall
"feste Drehzahl gleich konstanter Volumenstrom" gilt nur für Kreise ohne Stellantriebe.

Folge für die Messung: der Volumenstrom ist veränderlich, ein einzelner Ablesewert ist eine
Momentaufnahme. Für die Auslegung eines Heizkreiszählers deshalb bei **allen Kreisen offen** ablesen,
das ist der Dauerhöchstwert.

## Warum kein Bus hilft

Die Aerotop-Reihe fährt einen Siemens-Regler mit BSB/LPB, und dafür gäbe es BSB-LAN (ESP32-Adapter,
~50 €, spricht MQTT). Das Projekt schließt aber genau die Split-Baureihe aus: „Aerotop (**nicht EVO
LN / Mono / Mono.2 / Split / Split.2!**)". Eine öffentlich dokumentierte Lösung für den Split gibt es
nicht. Die Wärmedaten sind nur extern zu bekommen.

**Stand 07.11.2026: der Hausherr hat einen eBUS Adapter Shield C6 gekauft** und erwartet, damit
auslesen und sogar stellen zu können. Das steht zu dem Obigen in Spannung, und die Spannung ist
nicht aufgelöst, sondern offen: **eBUS und BSB/LPB sind verschiedene Busse**, elektrisch und im
Protokoll, und der Ausschluss oben betrifft BSB-LAN am Siemens-Regler. Ob der C6 diesen Regler
erreicht, entscheidet der Versuch am Gerät, nicht dieses Dokument. Wer ihn gemacht hat, schreibt
das Ergebnis hierher.

**Nachtrag 13.11.2026: der Adapter passt vermutlich doch, aber aus einem anderen Grund.** Der
Adapter ist angekommen. Die Recherche vom selben Tag spricht dafür, dass die Aerotop **Split**
gar keinen Siemens-Regler mit BSB hat, sondern die Regelung der Ariston-Gruppe, zu der ELCO
gehört, und deren Bus „BridgeNet“ ist ein eBUS-Dialekt:

* Das Raumgerät REMOCON PLUS wird laut Händlerbeschreibung „über 2 Drahtverbindung via BridgeNet
  BUS“ an die Wärmepumpe angebunden [B1].
* Die Erstinbetriebnahme-Liste der Aerotop Split verlangt die Prüfung der „BUS-Verbindung
  zwischen interner Einheit, externer Einheit und Systeminterface“ [B2]. „Systeminterface“ ist
  das Wort der Ariston-Geräte, nicht der Siemens-Regler.
* Für ebusd gibt es eine Konfiguration für den „Ariston/Chaffoteaux/Elco Bridgenet Bus“ [B3], und
  eine Ableitung davon für eine Wärmepumpe derselben Gruppe sagt, sie benutze „the same BridgeNet
  eBUS protocol as the Ariston Nimbus / Elco Aerotop heat pumps“ [B4].
* Das erklärt auch, warum BSB-LAN die Split-Baureihe ausschließt: nicht weil ihr Siemens-Regler
  verschlossen wäre, sondern weil sie keinen hat.

Damit steht die Zeile in der Tabelle oben („Regler LOGON B WP61 = Siemens RVS 61.843“) in Frage.
Sie ist nie am Gerät geprüft worden. **Am Gerät zu klären, bevor irgendetwas angeklemmt wird:**
Hängt das Raumgerät der Wärmepumpe an zwei Adern auf einer Klemme „BUS“ (bei den baugleichen
Ariston-Geräten mit B und T bezeichnet; für dieses Gerät im Installationshandbuch nachsehen)?
Dann ist es BridgeNet, und der Adapter kommt parallel auf genau diese zwei Adern. Steht dagegen
„LOGON B“ auf dem Regler und heißen die Klemmen CL+ und CL-, ist es BSB, und der Adapter passt
nicht. Die Vorlauftemperaturregelung des Heizkreises mit ihrem eigenen Außenfühler ist ein
zweites Gerät und kann ein Siemens-Regler sein, auch wenn die Wärmepumpe keiner ist.

**Ergebnis des Versuchs, 13.11.2026 abends.** Der Hausherr hat nachgesehen und angeklemmt: Das
Bediengerät der Wärmepumpe hängt an zwei Adern auf den Klemmen **B und T**, die es zugleich mit
Strom versorgen, wie bei eBUS üblich. Der Adapter sitzt parallel auf diesen Klemmen und meldet in
seiner Weboberfläche „eBUS signal: acquired“. Damit ist entschieden, was oben offen stand: **die
Aerotop Split spricht elektrisch eBUS, der Adapter erreicht sie.** Die Zeile „Regler LOGON B
WP61 = Siemens RVS 61.843“ in der Tabelle am Anfang gilt für diese Wärmepumpe nicht. Noch nicht
gezeigt ist, welche Werte ebusd mit der BridgeNet-Konfiguration tatsächlich liest; das ist der
nächste Schritt. Der Empfang des Adapters im WLAN war beim Versuch mäßig (54 %), und der Bus der
Ariston-Gruppe ist empfindlich gegen Verzögerung: bleiben Werte aus, ist das die erste Spur.

**Der Weg der Werte, gebaut am 13.11.2026.** Auf Wunsch des Hausherrn läuft ebusd nicht als
fremdes Add-on, sondern als eigenes: `addons/duckcurve_ebusd` verpackt ebusd 26.1 (fertig gebaut
aus dem Abbild seines Autors), lädt die Bus-Beschreibung [B3] in der Fassung `f2c9a631` mit
Prüfsumme und startet ebusd **nur lesend**. Die Werte gehen als JSON auf den Mosquitto-Broker;
die Bridge liest sie dort mit `apps/bridge/src/dch_bridge/sources/ebusd_mqtt.py`. Home Assistant
ist an diesem Weg nicht beteiligt.

Gemessen am selben Abend, ohne Heizung, mit einem nachgestellten Adapter
(`tools/ebus_uebungsadapter.py`):

| Was | Ergebnis |
|---|---|
| ebusd lädt die Bus-Beschreibung | 356 Nachrichten, davon 65, die sich nur durch Zuhören ergeben, keine wird von selbst abgefragt |
| Rundruf der Außentemperatur | `ebusd/energymgr/ext_temp` mit `{"0": {"name": "", "value": 8.6}}` |
| Abgehörte Frage mit Antwort | `ebusd/heatpump/coolat_data` mit `LWT_temp`, `EWT_temp`, `evaporator_temp`, `coolant_temp` |
| Fühler fehlt (Rohwort 0x7FFF) | ebusd meldet 3276,7; die Bridge verwirft es |
| Nur lesend, an den Adapter geschickt | zwei Nachrichten an den Adapter selbst (`c081`, `cc80`), nichts für den Bus |
| Ganze Kette mit der Zuordnung des Hauses | `outdoor_temp_c = 8,6` und `flow_temp_c = 35,2` in der Bridge |

Das zeigt, dass die Kette hält, wenn die Wärmepumpe diese Telegramme sendet. **Ob sie das tut,
ist nicht gezeigt**: die Bus-Beschreibung stammt von einer Ariston-Hybridanlage. Die Bridge
schreibt deshalb jeden Namen, den der Bus meldet, einmal ins Protokoll (`ebusd meldet`); die
Zuordnung in `config/entities.home.yaml` (Außentemperatur, Vorlauf) ist bis dahin ein erster
Versuch. Kommt die Außentemperatur vom Bus, ersetzt sie die Wetterstation; kommt sie nicht,
bleibt es bei der Wetterstation.

**Erster Lauf an der Wärmepumpe, 13.11.2026, 23:20.** Das Add-on läuft im Haus, nur lesend, und
ebusd hört den Bus: „signal acquired“, drei sprechende Geräte (Adressen 00, 10, 13), Zugang zum
Broker vom Supervisor. Aus 43 Sekunden Protokoll:

| Was ebusd erkennt | Wert | Bemerkung |
|---|---|---|
| `heatpump/heatpump_ext_unit_info` | 4,6 °C; 9 kW | Außentemperatur des Außengeräts und seine Nennleistung. Die 9 kW passen zum Typ WH 09-11. **Das ist jetzt die Außentemperatur des Hauses.** |
| `heatpump/coolat_data` | 32,3; -30,9; 5,3; 28,0 °C | Vorlauf, Rücklauf, Verdampfer, Kältemittel. Der Vorlauf ist plausibel (Maschine steht) und ist zugeordnet. **Der Rücklauf ist es nicht** und bleibt unbenutzt. |
| `energymgr/hybrid_LWT_setpoint` | 45,0 °C | Der Vorlauf-Sollwert, den der Regler der Maschine vorgibt. Noch ohne Schlüssel im Dienst; für den Zwilling die wertvollste neue Zahl. |
| `heatpump/heatpump_mode`, `heatpump_info` | `Soft_fail` | Betriebszustand 15. Der Name stammt aus der fremden Liste; an einer verwandten Anlage tritt er bei stehendem Verdichter ohne Durchfluss auf [B4]. Hier stand die Maschine (Durchfluss 0, Strömungsschalter offen). Kein Fehler, sondern ein falsches Wort für „steht“. |
| `heatpump/heatpump_flowmeter`, `heatpump_flow_switch` | 0,0; offen | |
| `energymgr/heat_request` | aus; aus; aus | |
| `energymgr/setpoint_temp` | 10,0; 10,0; 10,0 °C | |
| `broadcast/cast_date` | 23:37, 13.11.2026 | Um 23:20:11 Ortszeit. **Die Uhr des Reglers geht rund 17 Minuten vor.** |

Was ebusd nicht erkennt, obwohl es regelmäßig kommt:

* **Der Rundruf der Außentemperatur.** `13fe20100576472f0000`: Kennung `7647`, Wert `002f` =
  4,7 °C, ein Byte dahinter. Die Bus-Beschreibung erwartet ihn unter `200f` ohne das Byte. An
  dieser Anlage tragen die Rundrufe `2010` Listen aus Kennung (2 Bytes), Wert (2 Bytes) und einem
  weiteren Byte; so gelesen stimmt der Wert mit dem des Außengeräts überein (4,7 gegen 4,6).
* **Die Leistungsaufnahme.** `131e2000027c4f / 03010000`: Kennung `7c4f`, Antwort null. In der
  Bus-Beschreibung steht diese Abfrage nur zusammen mit einer zweiten Kennung; allein ist sie
  auskommentiert. Bei stehender Maschine ist null plausibel; ob es Watt sind, zeigt der
  Vergleich mit dem Zähler, sobald sie läuft.
* Vier Schreibtelegramme im Fünf-Sekunden-Takt (`131e2020...`) und mehrere Listen unter `2010`,
  deren Kennungen in der Bus-Beschreibung fehlen.

Folgerungen: Die Kette steht an der echten Anlage. Die Bus-Beschreibung passt zum Teil; für das,
was fehlt, braucht es eigene Zeilen für diese Anlage, geprüft an genau diesen Telegrammen. Der
nächste Schritt dafür ist ein Protokoll bei laufender Maschine.

**Zweites Protokoll, 13.11.2026, 23:30, die Maschine läuft** (Betriebszustand „Heating“).

| Größe | stehend (23:20) | laufend (23:30) | Woher |
|---|---|---|---|
| Durchfluss | 0,0 | 28,9 bis 30,9 | `heatpump_flowmeter`. Einheit in der Bus-Beschreibung „L“; als Liter je Minute gelesen passt der Wert zu einer 9-kW-Maschine. |
| Strömungsschalter | offen | geschlossen | `heatpump_flow_switch` |
| Vorlauf | 32,3 °C | 39,9 °C | `coolat_data`, Feld `LWT_temp` |
| Rücklauf laut `coolat_data` | -30,9 °C | -30,9 °C | Feld `EWT_temp`: unverändert, also nicht belegt |
| Verdampfer, Flüssigkeitsleitung | 5,3; 28,0 °C | 2,3; 36,6 °C | `coolat_data` |
| Leistungsaufnahme | 0 W | 1448 W | Kennung `7c4f`, eigene Zeile `hp_power` |
| Sauggas, Heißgas | 15,0; 23,2 °C | 3,3; 46,4 °C | Kennungen `7217`, `7317`, eigene Zeile `hp_kaeltekreis` |
| Temperatur `759e` | 48,3 °C | 47,6 und 47,4 °C | Rundruf des Reglers, eigene Zeile `system_temps` |
| Temperatur `769e` | 33,5 °C | 36,5 und 36,9 °C | ebenso |
| Hauptpumpe | 0 | 1 | Kennung `c200`, eigene Zeile `pumpe_status` |
| Vorlauf-Sollwert | 45,0 °C | 45,0 °C | `hybrid_LWT_setpoint` |
| Außentemperatur | 4,6 °C | 4,6 °C (Rundruf: 4,7) | `heatpump_ext_unit_info`, Rundruf `7647` |

**Eigene Zeilen für diese Anlage** stehen in `addons/duckcurve_ebusd/aerotop_split.csv` und kommen
mit dem Add-on (ab 0.2.0) neben die Bus-Beschreibung. Sie lesen nur mit. Jede ist mit ebusd 26.1
an den Telegrammen aus den beiden Protokollen geprüft: `131e2000027c4f / 0301a805` ergibt 1,448 kW,
`13fe20100f759edc0100769e6d0100779e000000` ergibt 47,6 und 36,5 °C, `13fe20100576472f0000` ergibt
4,7 °C. Die Namen der Kennungen `7c4f`, `7217`, `7317`, `7647` und `c200` stammen aus [B7], wo sie
unter anderer Adresse stehen. Die Rundrufe unter `2010` sind Listen; je nach Größe folgen der
Kennung zwei oder drei Bytes Wert.

**Welche Temperatur ist der Rücklauf?** Offen, mit einer begründeten Zuordnung:

* Für `769e` sprechen drei Beobachtungen bei laufender Maschine. Er liegt 3,4 K unter dem Vorlauf
  (36,5 gegen 39,9 °C). Er liegt dicht an der Flüssigkeitsleitung (36,6 °C), die das Kältemittel
  nach dem Wärmetauscher hat. Und er ergibt eine stimmige Bilanz: 30 l/min mal 3,4 K sind rund
  7,1 kW Wärme, bei 1,448 kW Aufnahme eine Arbeitszahl um 4,9 bei 4,6 °C draußen und 40 °C
  Vorlauf.
* Für `759e` spricht nur, dass [B7] ihn in einer auskommentierten Zeile für die Aerotop Split
  „return temp“ nennt. Dagegen: 47,6 °C liegen über dem Vorlauf und über dem Sollwert von 45 °C;
  wäre das der Rücklauf, liefe die Maschine nicht. Wahrscheinlicher ist ein Speicherfühler.

`769e` ist deshalb als `heat_pump_return_temp_c` zugeordnet, mit diesem Vorbehalt. Bestätigen
lässt es sich am Bediengerät der Wärmepumpe (Rücklauftemperatur ablesen und vergleichen) oder
an einigen Stunden Verlauf: der Rücklauf folgt dem unteren Puffer.

**Was davon in den Dienst geht** (`config/entities.home.yaml`, Minutentabelle seit der Migration
`a7d3e9c52b18`): Außentemperatur, Vorlauf, Durchfluss (`heat_pump_flow_l_min`), Rücklauf
(`heat_pump_return_temp_c`), Vorlauf-Sollwert (`heat_pump_flow_setpoint_c`), die
Leistungsaufnahme nach Auskunft der Maschine (`heat_pump_bus_power_kw`, neben der gemessenen
`heat_pump_power_kw`) und, seit dem dritten Protokoll, Verdichterfrequenz und Betriebszustand. Angezeigt wird davon noch nichts außer Außentemperatur und Vorlauf; die
Reihen laufen ab jetzt mit, damit Wärmeleistung und Arbeitszahl später über Tage gerechnet und
gegen den Stromzähler gehalten werden können.

**Wie oft die Werte kommen.** Gemessen am nachgestellten Adapter über eine Minute: ebusd gibt die
Werte im Fünf-Sekunden-Takt an den Broker, aber nicht jeden Wert in jedem Takt; die Abstände je
Wert lagen zwischen 5 und 55 Sekunden. Für Temperaturen reicht das. Für Leistung und Durchfluss
heißt es: das Minutenmittel entsteht aus wenigen Stichproben.

**Nicht gesichert:** dass der Durchfluss Liter je Minute sind und wie genau der Geber ist; dass
`7c4f` die ganze Leistungsaufnahme ist (Vergleich mit dem Zähler steht aus); die Zuordnung des
Rücklaufs. Eine daraus gerechnete Wärmeleistung ist bis dahin eine Abschätzung.

**Drittes Protokoll, 14.11.2026, 00:06, nach dem Lauf, Add-on 0.2.0.** Die eigenen Zeilen wirken:
`hp_power: 0.000`, `hp_kaeltekreis: 20.6;54.6`, `system_temps: 52.6;39.6`. Dazu drei Befunde.

* **Verdichterfrequenz und Betriebszustand stehen in einem weiteren Telegramm.**
  `131e20000878106e13ca46cb46 / 070f210000000f00`: Außentemperatur 3,3 °C, Durchfluss 0,
  Zustand 15, Frequenz 0 Hz. Eigene Zeile `hp_betrieb` (ab Add-on 0.2.1); beides geht in die
  Minutentabelle (`heat_pump_compressor_hz`, `heat_pump_mode_code`, Migration `b8e4f0d63c29`).
  Damit wird Abtauen (Zustand 9) zum ersten Mal sichtbar.
* **Der Regler kennt eine Speichertemperatur.** `1018200008150318031c117017 / 060f0000001702`:
  Kennung `7017`, 53,5 °C, in [B7] `dhw_store_temp`. Das Bediengerät fragt sie nur ab, wenn
  eine bestimmte Seite offen ist; sie kommt also nicht verlässlich. Eigene Zeile
  `speicher_info`, nicht zugeordnet. `759e` stand zur selben Zeit bei 52,6 °C: das stützt die
  Lesart, dass `759e` ein Speicherfühler ist und nicht der Rücklauf.
* **Eine Liste kann ihre Zusammensetzung ändern.** Einmal stand `pumpe_status: 0;46;48715` im
  Protokoll: dieselbe erste Kennung, anderer Inhalt, ohne Fehler gelesen. ebusd liest Listen
  mit einer festen Schablone und merkt das nicht. Für den Rücklauf legt die Schablone deshalb
  die Kennung vor dem Wert offen (`kennung_2`), und die Zuordnung verlangt, dass dort `76 9e`
  steht (Bridge ab 0.14.1). `pumpe_status` ist nicht zugeordnet und bleibt ungeschützt.

Der Rücklauf bleibt unbestätigt. Nach dem Lauf standen `769e` bei 39,6 und der Vorlauf bei
46,8 °C; bei stehender Pumpe sagt dieser Abstand nichts. Über die Zuordnung entscheidet der
Vergleich bei laufender Maschine: mit der Anzeige am Bediengerät oder mit dem unteren Puffer.

Was die Quellen zum Betrieb sagen:

* Der Adapter (eBUS Adapter Shield C6) ist galvanisch getrennt, die Polung der zwei Adern spielt
  keine Rolle, Strom kommt über USB-C (mindestens 1 W, empfohlen 2 W). Eingerichtet wird er über
  einen eigenen WLAN-Zugangspunkt „EBUS“ oder WPS und die Weboberfläche easi>; ebusd spricht ihn
  über `ens:<Adresse>:9999` an [B5].
* Die automatische Geräteerkennung von ebusd greift bei der Ariston-Gruppe nicht. Die Datei
  `ariston.csv` aus [B3] kommt in einen sonst leeren Konfigurationsordner [B3].
* Der Bus der Ariston-Gruppe ist empfindlicher gegen Verzögerung als andere; über WLAN wurden
  Latenz und Wiederholungen hochgesetzt (ein Bericht nennt `--latency=120`) [B3][B6].
* Die Konfiguration ist vor allem zum Lesen gedacht. Schreibregeln gibt es, sie sind an einer
  einzelnen Anlage erprobt, und ein falscher Wert kann die Anlage auf Vorgaben zurückfallen
  lassen [B3]. Für dieses Haus gilt deshalb: zuerst nur lesen.
* Die Energiezähler, die eine Nimbus liefert, lesen bei einer verwandten Wärmepumpe alle null
  [B4]. Ob die Aerotop Split eine Wärmemenge meldet, zeigt erst der Versuch.

Was `ariston.csv` [B7] an Werten der Wärmepumpe kennt (Kreis `heatpump`): die Außentemperatur
(`heatpump_ext_temp`), Vorlauf und Rücklauf (`heatpump_LWT_temp`, `heatpump_EWT_temp`), die
Verdichterfrequenz (`heatpump_compr_frequency`), die elektrische Leistung
(`heatpump_power_consumption`) und den Betriebszustand (`heatpump_mode`). Drei Zeilen tragen
ELCO im Namen (`elco_hp_LWT_temp`, `elco_hp_EWT_temp`, `elco_hp_return_temp`), sind aber
auskommentiert. Ob diese Namen an dieser Anlage Werte liefern, zeigt erst der Versuch.

[B1] regotherm.de, „ELCO Raumgerät REMOCON PLUS“, https://www.regotherm.de/detail/index/sArticle/63790
[B2] ELCO Aerotop Split, Schnellstartanleitung, S. 35, https://www.manualslib.de/manual/500262/Elco-Aerotop-Split.html?page=35
[B3] wrongisthenewright/ebusd-configuration-ariston-bridgenet, README, https://github.com/wrongisthenewright/ebusd-configuration-ariston-bridgenet
[B4] SietseWijnker/atag-energion-ebusd, README, https://github.com/SietseWijnker/atag-energion-ebusd
[B5] eBUS Adapter Shield C6, Dokumentation, https://adapter.ebusd.eu/v5-c6/
[B6] Home Assistant Community, „Ariston Group integration via eBusd“, https://community.home-assistant.io/t/ariston-group-integration-via-ebusd/738887
[B7] wrongisthenewright/ebusd-configuration-ariston-bridgenet, `ariston.csv`, https://github.com/wrongisthenewright/ebusd-configuration-ariston-bridgenet/blob/main/ariston.csv

Alle abgerufen am 13.11.2026.

Zwei Dinge gelten unabhängig davon. Erstens: **eine gerechnete Wärmemenge ist keine Messung.**
Meldet der Bus eine intern aus Verdichtermodell und Temperaturen abgeleitete Zahl, ist sie das
Modell des Herstellers, und sie löst den Kreisschluss aus `docs/design/digitaler-zwilling.md`
Abschnitt 5.2 nicht: ein Fehler darin erschiene weiterhin als Fehler im Verlustkoeffizienten. Nur
eine gezählte Energie löst ihn. Zweitens: **falls der C6 wirklich stellen kann, wird die
Vorlauftemperatur zur Entscheidungsvariablen.** Heute ist K1 die einzige Stellgröße am Gerät, eine
Anforderung ohne Garantie; mit einer stellbaren Vorlauftemperatur wird aus dem Zielzustand des
Entwurfs der Istzustand, und der COP wird planbar statt nur bilanzierbar.

**Die Reihe ist seit dem 07.11.2026 eingerichtet.** `flow_temp_c` steht in der Minutentabelle und im
Anlagenschema, zugeordnet ist noch nichts. Welche Quelle sie füllt, der C6 oder die bisher nicht
zugeordnete Entität `vorlauf_temperature` aus Home Assistant, ist dem Rest gleichgültig: die Zeile
dafür liegt einkommentierfertig in `config/entities.home.yaml`. Bis dahin schreibt die Anlagenseite
„Vorlauf ?" statt einer erfundenen Zahl.

## Einkaufsliste, nach Nutzen geordnet

### 1. Wärmemengenzähler an der Wärmepumpe

| | |
| --- | --- |
| Gerät | Landis+Gyr **ULTRAHEAT T550 (UH50)**, Ultraschall, MID |
| Baugröße | **qp 1,5** im DN20-Gehäuse - bei gemessener Spreizung unter 4 K stattdessen qp 2,5 |
| Versorgung | **230-V-Netzteil** statt Batterie |
| Kommunikation | **M-Bus verdrahtet**, zusätzlich **Impulsausgang** |
| Fühler | Pt500-Paar, direkt eintauchend (keine Anlegehülsen) |
| Einbau | **Rücklauf, zwischen Wärmepumpe und Puffer** - nur der WP-Kreis, nicht die Entnahme |
| Auslesekette | M-Bus-Pegelwandler → `wmbusmeters` (Treiber `ultraheat`) → MQTT → Bridge |

Begründung der Baugröße: `Volumenstrom = kW / (1,16 × Spreizung)`. Bei 9-11 kW und 5 K sind das
1,55-1,90 m³/h. Ein qp-1,5-Zähler darf dauerhaft bis 3,0 m³/h (= 2 × qp) und misst am unteren Ende
deutlich besser als qp 2,5 - und dort, im sommerlichen Warmwasserbetrieb unter 1 m³/h, entstehen die
schlechten Arbeitszahlen. DN20 statt DN15 wegen des Druckverlusts: die Umwälzpumpe einer Wärmepumpe
hat viel weniger Förderhöhe als ein Fernwärmenetz.

**Vor der Bestellung abzulesen:** die tatsächliche Spreizung **im Wärmepumpenkreis**, also Vor- und
Rücklauf an der Aerotop selbst, während sie den Puffer lädt. Nicht die Heizkreispumpe im Keller: die
sitzt hinter dem Puffer und sagt über den WP-Kreis nichts aus. Zehn Minuten an der Maschine schlagen
jedes Datenblatt.

Alternativen mit denselben Eigenschaften: Kamstrup MULTICAL 303/403 (Treiber `kamheat`), Zenner
zelsius C5. Der Diehl Sharky 775 wäre technisch gleichwertig (Dynamikbereich 1:250), wird aber nur
über Großhandel und Messdienstleister verkauft, nicht an Endkunden.

Zur Batteriefrage: die Batterie sitzt im **Rechenwerk**, nicht im Messteil - Ultraschall hat gar kein
bewegliches Messwerk. Der T550 nennt bis zu 16 Jahre Batterielebensdauer, das reicht. Für **unsere**
Nutzung ist das Netzteil trotzdem richtig: häufiges Abfragen über M-Bus weckt die Elektronik und
leert die Batterie schneller als der Abrechnungsbetrieb, für den die 16 Jahre gelten. Eichrechtliche
Plomben dürfen nicht verletzt werden, ein Batteriewechsel ist kein Heimwerkerjob.

### 2. Anlegefühler Vorlauf und Rücklauf am Wärmepumpenkreis

| | |
| --- | --- |
| Gerät | Shelly Plus 1 + **Shelly Plus Add-On** + DS18B20-Kabelfühler |
| Anzahl | 2 Fühler, das Add-On trägt bis zu drei (beim Kauf im Datenblatt gegenprüfen) |
| Kosten | rund 60 € komplett |
| Einbau | Anlegefühler mit Wärmeleitpaste auf Vor- und Rücklauf **zwischen Wärmepumpe und Puffer**, darüber die Rohrdämmung wieder schließen |
| Anbindung | MQTT, Gen 2. Die Bridge spricht das bereits, es braucht keinen neuen Quelltyp |

Kein Klempner nötig, die Fühler werden aufgelegt, nicht eingeschnitten. Nur 230 V für den Shelly.

**Die Fühler vor dem Einbau paaren.** DS18B20 ist mit ±0,5 K spezifiziert. Bei 5 K Spreizung wären
das im schlimmsten Fall 20 % Fehler, und zwar systematisch, nicht rauschend. Also beide Fühler
zusammen in ein Glas Wasser legen, zehn Minuten warten, die Differenz notieren und als Offset in die
Konfiguration schreiben. Danach ist die **Spreizung** auf etwa 0,1 K genau, auch wenn der Absolutwert
um ein Grad danebenliegt. Für unseren Zweck ist genau das die richtige Reihenfolge der Prioritäten.

Was die zwei Zahlen aufschließen, in der Reihenfolge ihres Werts:

* **Die Spreizung im WP-Kreis.** Das ist der Wert, der vor der Bestellung des Wärmemengenzählers
  fehlt, und danach die Dauerdiagnose: sinkt die Spreizung über Monate, stimmt etwas nicht.
* **Abtauzyklen.** Beim Abtauen kehrt die Maschine den Kreis um, der Vorlauf bricht ein. Heute ist
  das unsichtbar und verfälscht jede COP-Schätzung, weil die Abtauenergie als Heizenergie zählt.
* **Warmwasserladung von Heizung trennen.** Die Ladung springt auf 50 bis 55 °C, weit über die
  Heizkurve. `dhw_kwh_per_day` ist bis heute die Annahme 8,0 kWh und wäre damit messbar.
* **Die tatsächlich gefahrene Heizkurve.** Vorlauf gegen Außentemperatur aufgetragen, über eine
  Heizperiode. Daraus wird die Wärmelastprognose ein Stück ehrlicher.
* **Takterkennung** schärfer als aus dem Strom allein: ein Start ist im Vorlauf binnen Sekunden zu
  sehen.

Wärme in kWh liefern die zwei Fühler **nicht**, dazu fehlt der Volumenstrom. Sie sind die Vorstufe
zum Wärmemengenzähler, nicht sein Ersatz.

### 3. Ofendaten aus dem Maestro-Modul - der größte Hebel für null Euro

Der Ofen ist eine MCZ mit Maestro-Modul, Datenbank `SC12-HYD`, und er hängt bereits **im
Heim-WLAN**, nicht nur an seinem eigenen Hotspot. Das ist der entscheidende Unterschied: die
Maestro-Platine ist damit von der Bridge aus über die LAN-Adresse erreichbar, es braucht keinen
zweiten Rechner am Ofen-Hotspot.

Das INFO-Menü der App zeigt, was die Platine intern führt. Alles davon ist für uns brauchbar:

| Feld | Was es uns gibt |
| --- | --- |
| `U/MIN FÖRDERSCHNECKE` (live und Soll) | **Brennstoffeintrag.** Die Schneckendrehzahl ist proportional zum Pelletmassenstrom. Das ist die Inputseite der Ofenbilanz, die bisher komplett fehlt |
| `T° RAUCH` | Feuert er wirklich, oder steht er nur unter Spannung. Der ehrlichste Betriebsindikator |
| `T° HEATING FLOW` (live und Soll) | Vorlauftemperatur des Ofenkreises |
| `T° PUFFER` (live und Soll) | **Fünfter, unabhängiger Pufferfühler.** Gegenprobe für unsere vier, siehe die offene Frage zur Fühlerreihenfolge |
| `PWM PUMP` | Modulation der Ofenpumpe, also ob und wie stark er gerade in den Puffer lädt |
| `3 WAY VALVE` | Ob die Wärme in den Heizkreis oder ins Warmwasser geht |
| `U/MIN RAUCHGASGEBL.`, `ZÜNDKERZE`, `BRAZIER` | Zünd- und Störungserkennung, Reinigungsbedarf |
| `AUTO MODUS`, `ECO STOP`, `T° RAUM` | Betriebsart und Raumfühler |

Damit ist die größte Lücke des Modells geschlossen. Bisher gilt: der Puffer wird warm, und es ist
nicht quantifizierbar, welcher Anteil aus der Wärmepumpe kam und welcher aus dem Ofen. Wer von
beiden lief, verrät zwar schon die Leistungsmessung der Wärmepumpe; **wie viel** jeder beigetragen
hat, verrät sie nicht. Mit Schneckendrehzahl, Rauchgastemperatur und Pumpenmodulation wird der
Ofenanteil erstmals schätzbar, und die Arbeitszahl der Wärmepumpe damit belastbar.

**Gebaut, nicht mehr geplant.** Das Protokoll ist offengelegt: die Maestro-Platine spricht WebSocket
auf Port 81, der Textrahmen `C|RecuperoInfo` fordert den Zustand an, die Antwort ist eine mit `|`
getrennte Liste hexadezimaler Felder mit fester Reihenfolge. Temperaturen stehen in halben Grad, der
Rohwert 255 heißt „kein Fühler". Rekonstruiert aus `hackximus/MCZ-Maestro-API` (Rahmenformat) und
`Chibald/maestrogateway` (Feldtabelle).

Die Bridge liest den Ofen deshalb **direkt**, in `sources/mcz_maestro.py`. Kein zweiter Daemon, kein
MQTT-Umweg, keine Cloud. Konfiguriert wird nur die Adresse des Ofens, siehe `CONFIGURATION.md`.

**Die Hürde: der WebSocket lebt auf dem Hotspot, nicht im Heimnetz.** Der Ofen ist zwar im WLAN
angemeldet und erreichbar, aber Port 81 auf seiner Heimnetz-Adresse ist zu (`Connection refused`,
also ein antwortender Host ohne Dienst). Dass die App auch von unterwegs funktioniert, widerspricht
dem nicht: die Platine baut eine **ausgehende** Verbindung zur MCZ-Cloud auf. Ein ausgehender
Tunnel ist kein lauschender Port. Genau deshalb verlangt `hackximus/MCZ-Maestro-API` zwei
Netzwerkkarten, und `Chibald/maestrogateway` hat `192.168.120.1` als Standardadresse: das ist der
Ofen auf seiner eigenen Hotspot-Schnittstelle.

Gemessen am 7.9.2026: von zehn Kandidatenports war keiner offen, alle refused. Ein lebendes Gerät
ohne einen einzigen Dienst auf der Heimnetz-Seite.

**Die Lösung ist eine Portweiterleitung, kein Umzug der Bridge.** Ein kleiner Dauerläufer mit zwei
Wegen (WLAN am Hotspot `MCZ-…`, Kabel im Heimnetz) reicht den Port durch:

```
socat TCP-LISTEN:8181,fork,reuseaddr TCP:192.168.120.1:81
```

In der Bridge dann `mcz_host` auf die Heimnetz-Adresse dieses Rechners und `mcz_port` auf `8181`.
Die Bridge bleibt, wo sie ist; nur ein Sprung kommt dazu.

**Die Falle dabei, gemessen und nicht vermutet:** der Hotspot des Ofens betreibt einen DNS, der jede
Anfrage mit seiner eigenen Adresse beantwortet. Wer ihn per DHCP übernimmt, bekommt auf `ghcr.io`
die Antwort `192.168.120.1` und damit `connection refused` auf 443. Ein Captive Portal ohne Portal.
An diese Verbindung gehört deshalb:

```
nmcli connection modify "MCZ-…" ipv4.never-default yes ipv6.never-default yes ipv4.ignore-auto-dns yes
```

In der Home-Assistant-Oberfläche entspricht das: statische IPv4, Gateway leer, DNS leer.

Zum Prüfen der Lage: `tools/mcz_find.py`.

Die Quelle **schreibt nie**. Der einzige Rahmen, der hinausgeht, ist `C|RecuperoInfo`. Eine Heizung,
die im Winter das Haus warm hält, ist kein Ort für Fernsteuerung nebenbei. Die Schreibbefehle sind
bekannt und bewusst nicht eingebaut.

Vor dem Konfigurieren prüfbar, von jedem Rechner im selben Netz, ohne Installation:

```
python3 tools/mcz_probe.py <ip-des-ofens>
```

**Die allgemeine MQTT-Quelle bleibt trotzdem auf der Liste**, aber nicht mehr für den Ofen: der
Wärmemengenzähler über `wmbusmeters` braucht sie weiterhin.

**Zugangsdaten gehören nicht ins Repo.** SSID, Hotspot-Passwort, MAC und Seriennummer des Ofens
stehen im Info-Dialog der App. Sie gehören in die Umgebung des Bridge-Prozesses, nicht in eine Datei
unter Versionskontrolle.

### 4. Raumtemperatur im Referenzraum

Zwei, drei Zigbee- oder BLE-Fühler, je 15-20 €. Ohne gemessene Innentemperatur ist die
Komfortbedingung des geplanten MILP (`T_building[t]`) eine Zahl aus der Luft, und „Vorheizen vor der
Hochpreisphase" - die Funktion, die wirklich Geld spart - nicht seriös zu bauen.

### 5. Wärmemengenzähler am Pelletofen

Erst später. Die Quellenzuordnung geht mit Ofensignal plus Puffer-Energiebilanz auch ohne. Falls doch:
gleiches Modell, qp 0,6 (der Ofenkreis läuft mit größerer Spreizung).

## Was ich nicht kaufen würde

Einstrahlungssensor (Open-Meteo plus der vorhandene Korrektor holen das meiste); einen zweiten
Netzzähler, falls ein Tibber Pulse möglich ist - der liefert den Zählerstand als Wahrheit für die
Rechnungsprüfung.

## Nach dem Einbau hier eintragen

| Zähler | Zählernummer | Baugröße | Einbauort | Modul | Datum |
| --- | --- | --- | --- | --- | --- |
| Wärmepumpe | | | | | |
| Pelletofen | | | | | |

## Die Außentemperatur: woher sie kommt und wie sie geprüft wird

Stand 13.11.2026. Die Außentemperatur (`outdoor_temp_c`) kommt **nicht von einem Fühler am Haus**,
sondern von einer Wetterstation, die in Home Assistant eingebunden ist; die Zuordnung steht in
`config/entities.home.yaml`. Am 13.11.2026 um 12:49 zeigte die Startseite 2,2 °C, während es
draußen 8 bis 9 Grad hatte. Warum der Wert falsch war (alt oder stehengeblieben), ließ sich von
außen nicht feststellen.

Seitdem hält der Dienst den Messwert gegen die Vorhersage des Wetterdienstes für die laufende
Stunde (`packages/hems-core/src/hems_core/watch/aussen.py`):

| Festlegung | Wert | Herkunft |
|---|---|---|
| Messwert gilt als veraltet | älter als 90 Minuten | gesetzt; die Station meldet stündlich |
| Messwert gilt als unglaubwürdig | mehr als 5 Grad neben dem Wetterdienst | gesetzt, nicht gemessen |

Trifft eines zu, zeigt die Startseite den Wert des Wetterdienstes mit dem Wort „Wetterdienst“
statt „draußen“, und der Wächter sagt in einem Satz, warum. **Gespeichert wird weiter der
Messwert**: die Prüfung ändert die Anzeige, nicht die Reihe und nicht den Fahrplan (der rechnet
ohnehin mit der Vorhersage). Eine Mitteilung aufs Telefon gibt es nicht.

**Seit dem Abend des 13.11.2026 kommt die Außentemperatur vom Außengerät der Wärmepumpe** über
eBUS (siehe „Warum kein Bus hilft“, erster Lauf an der Wärmepumpe). Die Wetterstation bleibt
eingetragen und springt ein, solange der Bus schweigt. Die Gegenprobe gegen den Wetterdienst
läuft weiter. Die Grenze von fünf Grad gehört jetzt neu angesehen: ein Fühler am Außengerät
liegt in der Sonne oder im Abluftstrom der laufenden Maschine leicht daneben. Dafür braucht es
einige Tage Messung, nicht eine Vermutung.

## Die Technikseite der Wärmepumpe

Stand 14.11.2026. Unter Technik gibt es den Reiter „Wärmepumpe“ (`/waerme/waermepumpe`): eine
Zeichnung aus Außengerät, Innengerät und Speicher mit den vier Leitungen dazwischen, und jeder
Messwert steht dort, wo er an der Anlage entsteht. Der Dienst setzt die Seite in
`apps/api/src/dch_api/application/waermepumpe.py` zusammen und gibt sie unter
`GET /api/v1/waermepumpe` aus; die Zeichnung liegt in `apps/web/src/components/waermepumpe/`.

| Wo in der Zeichnung | Größe | Herkunft |
|---|---|---|
| Außengerät | Außenluft | Bus, `heatpump_ext_unit_info.ext_temp` |
| Außengerät | Verdampfer | Bus, `coolat_data.evaporator_temp` |
| Außengerät | Sauggas | Bus, eigene Zeile `hp_kaeltekreis.suction_temp` |
| Außengerät | Verdichterfrequenz | Bus, eigene Zeile `hp_betrieb.compressor_hz` |
| Außengerät | Strom | Zähler an der Zuleitung; fehlt er, die Auskunft der Maschine (`hp_power`) |
| Leitung zum Innengerät | Heißgas | Bus, eigene Zeile `hp_kaeltekreis.discharge_temp` |
| Leitung zum Außengerät | Flüssigkeit | Bus, `coolat_data.coolant_temp` |
| Innengerät | Vorlauf soll | Bus, `hybrid_LWT_setpoint` |
| Innengerät | Durchfluss | Bus, `heatpump_flowmeter` |
| Innengerät | Betriebszustand | Bus, eigene Zeile `hp_betrieb.mode` |
| Leitung zum Speicher | Vorlauf | Bus, `coolat_data.LWT_temp` |
| Leitung vom Speicher | Rücklauf † | Bus, eigene Zeile `system_temps.t_769e` |
| Speicher | Fühler der Wärmepumpe † | Bus, eigene Zeile `system_temps.t_759e` |
| Speicher | vier Schichten | die eigenen Pufferfühler, wie im Anlagenschema |

† Die Zuordnung ist begründet, am Gerät aber nicht bestätigt (siehe oben, „Welche Temperatur
ist der Rücklauf?“). Die Seite kennzeichnet beide Werte mit demselben Zeichen.

**Was gerechnet wird.** Spreizung = Vorlauf minus Rücklauf. Wärmeleistung = Durchfluss mal
Spreizung mal 4,186 kJ/(kg K), ein Liter als ein Kilogramm. Arbeitszahl = Wärmeleistung durch
Leistungsaufnahme. Mit den Zahlen des zweiten Protokolls (29,8 l/min, 39,9 und 36,5 °C,
1,448 kW) sind das 3,4 K, 7,07 kW und 4,9; dieselbe Rechnung prüft
`apps/api/tests/test_waermepumpe.py`. Beides heißt auf der Seite „abgeschätzt“, weil der
Durchflussgeber nicht geeicht ist, der Rücklauf nicht bestätigt ist und die Werte nicht im selben
Augenblick kommen.

| Festlegung | Wert | Herkunft |
|---|---|---|
| Ein Buswert gilt als veraltet | nach 15 Minuten | gesetzt; gemessen lagen bis 55 s zwischen zwei Meldungen |
| Pumpe gilt als stehend | unter 2 l/min | gesetzt; gemessen 0,0 im Stillstand und rund 30 im Lauf |
| Keine Wärmeleistung | Spreizung unter 0,5 K | gesetzt, nicht gemessen |
| Keine Arbeitszahl | Leistungsaufnahme unter 0,3 kW | gesetzt, nicht gemessen |

**Gespeichert** werden seit diesem Stand zusätzlich Verdampfer, Sauggas, Heißgas, Flüssigkeit und
der Speicherfühler der Wärmepumpe als Minutenreihen (Migration `c9f5a1e74d3a`). Die Seite selbst
zeigt nur den Augenblick; ein Verlauf der Arbeitszahl über Tage gegen den Zähler steht aus.

**Die Vorführung** hat keinen Bus. Dort entstehen die Größen aus dem Zustand des Modellhauses
(`vorfuehrung` im selben Modul, Arbeitszahl fest 4,2, Durchfluss fest 29,5 l/min). Das Modellhaus
hat eine größere Maschine als das echte; die Zahlen dort sind stimmig, nicht die des Hauses.

**Der Weg dorthin.** Ein Tipp auf die Wärmepumpe der Startseite öffnet eine Auswahl mit vier
Zielen: Technik (diese Seite), Kosten (Nachbetrachtung), Fahrplan und Verbrauch
(`apps/web/src/components/home/WpMenue.tsx`). Vorher führte der Tipp ohne Umweg auf die
Wärmeseite.

Nicht geprüft: die Seite mit den echten Werten des Hauses. Geprüft ist sie in der Vorführung, am
Telefon (390 Punkte) und an der Wandanzeige (1280 Punkte), im Lauf und im Stillstand.

### Wenn der Bus schweigt

Am Morgen des 14.11.2026 stand im Haus an jedem Buswert der Seite ein Fragezeichen, obwohl beide
Add-ons aktualisiert und neu gestartet waren; nur Außenluft und Zähler hatten Werte. Die Ursache
ist **offen** (Stand 14.11.2026, 09:30): Der Weg von ebusd über einen echten Broker bis zu den
Messwerten der Bridge ist nachgestellt und lief, ein Fehler im Dienst war nicht zu finden, und ins
Haus sieht von außen niemand. Genau das war der Mangel: Die Seite sagte nicht, an welcher Stelle
es hängt.

Seitdem tut sie es. Die Bridge (ab 0.14.2) meldet die Lage des Busses als Zustand der Quelle
`ebusd` (`DeviceHealthFrame`; die Wörter und ihre Bedeutung stehen in
`addons/duckcurve_bridge/DOCS.md`), der Dienst merkt sich je Quelle den letzten Stand und
schreibt nur den Wechsel ins Ereignisprotokoll. Ist kein einziger Buswert da, steht über der
Zeichnung ein Satz (`waermepumpe.bus_auskunft`), der die erste Stelle nennt, an der es hängt:

1. Die Bridge ist nicht verbunden.
2. Die Bridge kündigt den Schlüssel `heat_pump_flow_l_min` nicht an: sie arbeitet mit einer
   Zuordnung ohne den Bus.
3. Das Wort der Bridge: Broker, ebusd, Signal, Zuordnung oder Weitergabe.
4. Eine Bridge vor 0.14.2 hat kein Wort; der Satz verweist auf ihr Protokoll.

Dazu steht, wann zuletzt ein Wert über den Broker kam.

| Festlegung | Wert | Herkunft |
|---|---|---|
| Erste Meldung nach dem Start der Bridge | nach 90 Sekunden | gesetzt; ebusd gibt manche Werte nur einmal je Minute weiter |
| Folgende Meldungen | alle 5 Minuten | gesetzt |
| ebusd gilt als verstummt | nach 10 Minuten ohne Nachricht | gesetzt; gemessen kommen im Betrieb alle 5 bis 55 Sekunden Nachrichten |

**Die Ursache, 14.11.2026, 09:33 bis 09:40.** Mit Bridge 0.14.2 stand im Haus der zweite
Satz: Die Bridge kündigt den Bus nicht an. Ihr Protokoll zeigte dann den Grund:
`entity map loaded origin=datei:/config/duckcurve/entities.yaml`, vier Geräte am Broker
(Pufferspeicher und drei Lichter), kein Bus. Im Haus liegt eine eigene Zuordnung, und die hatte
bis 0.14.2 Vorrang vor dem Repository (`apps/bridge/src/dch_bridge/entities_source.py`).

Die Datei ist kein vergessener Altbestand. Sie meldet 25 Sensoren, das Repository 15; nur in ihr
stehen die Alarmanlage und ein Fensterkontakt, deren Namen nicht ins öffentliche Repository
gehören. Löschen wäre also falsch gewesen, und der Abgleich von Hand (den Abschnitt für den Bus
hineinkopieren) hätte bei jeder Änderung am Bus wieder angestanden; ein Tippfehler in der Datei
hält zudem die ganze Bridge an, samt Haustür.

**Seit 0.14.3 ergänzt die Datei das Repository.** Was in ihr steht, gilt unverändert; was nur im
Repository steht, kommt hinzu. Gegen den Stand des Hauses gerechnet (die Schlüssel aus der Zeile
`telemetry keys` des Protokolls gegen `EntityMap.keys()` der Datei auf `main`) kommen genau die
zwölf Größen des Busses und ein Fensterkontakt dazu. Die Bridge meldet die Herkunft ihrer
Zuordnung außerdem als Zustand der Quelle `zuordnung`, und der Satz auf der Seite nennt sie.
**Im Haus bestätigt ist das noch nicht**; geprüft ist es mit nachgestellten Dateien
(`apps/bridge/tests/test_entities_source.py`).

### Die Fußleiste am Telefon rollte mit

Ebenfalls am 14.11.2026 gemeldet: auf dem iPhone, in der Anwendung vom Home-Bildschirm, stand die
Fußleiste mitten im Bild und rollte mit dem Inhalt. **Nicht nachgestellt.** Im nachgestellten
Telefon (Chromium, 390 Punkte) bleibt sie beim Rollen fest (gemessen: oben 603, unten 664 bei
Rollstand 0 und 400), und kein Vorfahr der Leiste hat eine Eigenschaft, die `position: fixed`
umlenkt. Bekannt ist ein Fehler von iOS mit genau diesem Bild bei Anwendungen vom
Home-Bildschirm, die einige Stunden im Hintergrund lagen [F1]; eine Abhilfe im Code nennt die
Quelle nicht. Ob es dieser Fehler ist, zeigt die Gegenprobe im Haus: Anwendung ganz schließen und
neu öffnen, dann auf dieser und auf einer anderen langen Seite rollen.

[F1] Apple Developer Forums, „iOS17 PWA `position: fixed` element breaks after a while“,
https://developer.apple.com/forums/thread/744327, abgerufen 14.11.2026.
