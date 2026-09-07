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

**Vor der Bestellung abzulesen:** die tatsächliche Spreizung. Die Umwälzpumpe zeigt den Volumenstrom
im Display, der Regler Vor- und Rücklauftemperatur. Zehn Minuten an der Maschine schlagen jedes
Datenblatt.

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
