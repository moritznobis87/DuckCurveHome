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
* **Es ist nicht unterscheidbar, ob der Puffer von der Wärmepumpe oder vom Pelletofen warm wurde.**
  Solange das so ist, verfälscht der Ofen jede Wärmebilanz und jede COP-Schätzung.

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

### 2. Ofensignal aus dem Maestro-Modul - fast umsonst

Lokal, ohne Cloud: ein kleiner Rechner verbindet sich mit dem WLAN-Hotspot des Ofens (SSID
`MCZ-XXXXXXX`), die Bibliothek **maestrogateway** veröffentlicht auf MQTT - unter anderem
`Maestro/Stove_State` (Zündung, Leistungsstufen 1-5, Fehler) und `Maestro/Power_Level`. Hydro-Modelle
sind laut Community kompatibel. Das beantwortet Q8 besser als der zuvor angedachte Shelly-Plug: nicht
nur an/aus, sondern die Leistungsstufe.

Die Cloud-Integration `Robbe-B/maestro_mcz` liefert nur eine Climate-Entität und einen
Temperatursensor - zu dünn.

**Voraussetzung in der Bridge:** eine allgemeine MQTT-Quelle. Die heutige Anbindung ist Shelly-förmig
(Komponenten wie `temperature:102`, Gen-2-RPC); Maestro sendet flache Topics.

### 3. Raumtemperatur im Referenzraum

Zwei, drei Zigbee- oder BLE-Fühler, je 15-20 €. Ohne gemessene Innentemperatur ist die
Komfortbedingung des geplanten MILP (`T_building[t]`) eine Zahl aus der Luft, und „Vorheizen vor der
Hochpreisphase" - die Funktion, die wirklich Geld spart - nicht seriös zu bauen.

### 4. Wärmemengenzähler am Pelletofen

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
