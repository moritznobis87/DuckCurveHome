# Sensorik: Bestand, Lücken, Einkaufsliste

Was gemessen wird, was geschätzt wird und was zu kaufen wäre, um aus Schätzung Messung zu machen.

## Anlage

| Gerät | Typ | Anmerkung |
| --- | --- | --- |
| Wärmepumpe | **ELCO AEROTOP SPLIT WH 09-11** (Luft/Wasser, 4-11 kW) | Regler LOGON B WP61 = Siemens RVS 61.843. Ansteuerung über K1-Kontakt (SG-Ready-ähnlich) |
| Pelletofen | **MCZ Star Hydromatic** (wasserführend) | speist denselben Puffer |
| Pufferspeicher | 1000 l Kombipuffer | WP und Ofen speisen ein, Heizung und Warmwasser entnehmen |

## Was gemessen wird

Strom (PV, Netz, Batterie, Wärmepumpe, Wallbox, Haus), Batterie-SOC, vier Puffertemperaturen,
Außentemperatur, Strompreis, Schaltzustände. Minutenauflösung, dauerhaft (siehe `DATENHALTUNG.md`).

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
