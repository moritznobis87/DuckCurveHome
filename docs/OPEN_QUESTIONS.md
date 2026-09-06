# Offene Fragen an den Hausherrn

Lebende Liste. Jede Frage nennt, was davon abhängt und mit welcher Annahme das System bis zur Antwort läuft.
Beantwortete Punkte wandern mit Datum und Antwort nach unten in „Erledigt“.

> Stand 06.09.: myenergi wird jetzt direkt aus der Cloud gelesen (`DCH_MYENERGI_SERIAL`/`_API_KEY`); die HA-Sensoren für PV, Netz, Batterie und Wallbox sind nur noch Rückfall. Q3 (Batterievorzeichen) ist damit fest im Code: interner Libbi-CT negiert, Entladen positiv.

> **Q9 erledigt (06.09.): Die Shellys der ersten Generation bleiben bei Home Assistant.** Beim Gen-1-Shelly
> schaltet aktiviertes MQTT den CoIoT-Kanal ab, über den die HA-Shelly-Integration arbeitet – die Schalter
> in HA gingen also verloren. Das ist beim Wärmepumpen-Kontakt und bei der Kaffeemaschine nicht hinnehmbar.
> Deshalb: `heat_pump_power_kw` (Shelly 3EM), der Wärmepumpenschalter und `coffee_machine` laufen dauerhaft
> über Home Assistant, die Gen-2-Geräte (Pufferspeicher, Lichter) über MQTT. Die Bridge kann beides
> gleichzeitig: bei `source_mode: mqtt` übergeht sie in HA nur die Schlüssel, die im Abschnitt `mqtt:` des
> Mappings stehen; alles andere kommt weiter aus HA. Die Geräte-ID des 3EM wird damit nicht mehr gebraucht.

## Offen

| Nr. | Frage | Hängt davon ab | Annahme bis zur Antwort |
|---|---|---|---|
| Q3 | **Batterie-Vorzeichen beim Entladen.** Wird `sensor.myenergi_libbi_26244255_power_ct_internal_load` beim Entladen negativ? (Beim Laden war er positiv, 445 W.) Abends prüfen, wenn die libbi entlädt. | Energiebilanz, Überschussregel | Laden positiv → Mapping `charge_positive` |
| Q4 | **Zweiter Wechselrichter?** `sensor.nobis_solar_network_111_solar_power` meldet 2,49 kW, der myenergi-Hub 7,65 kW (drei harvi-CTs à ~2,55 kW). Separate Anlage, die die CTs nicht erfassen, oder dasselbe Gerät mit anderer Zählung? | PV-Gesamtleistung, Bilanz, Prognosekalibrierung | Hub-Wert ist die Gesamt-PV |
| Q5 | **Tibber-Sensor-Abweichung.** `sensor.electricity_waldstrasse_48_gesamtleistung` zeigte 3168 W Bezug, myenergi gleichzeitig 2378 W Einspeisung. Tibber Pulse vorhanden? War der Wert veraltet? | Zweite Netzmessung (Plan 25.4) | myenergi ist die Netzmessung |
| Q7 | **Batterie-Schwelle für den WP-Überschuss.** Aktuell zählt Batterieladung erst ab 80 % SOC als nutzbarer Überschuss (Batterie hat Vorrang). Soll die Wärmepumpe bei großem Puffer-Ladebedarf früher Vorrang bekommen? | `count_battery_charging_above_soc` in der HEMS-Konfiguration | 0,8 |
| Q8 | **Pelletofen-Indikator.** Gibt es ein Signal für den Ofenbetrieb (Steckdosen-Shelly, Abgastemperatur, Zeitplan)? Siehe Plan 25.13 und Designdokument Prognose/Wärme. | Fremdwärme-Erkennung, Wärmebilanz des Puffers | Nur Residual-Erkennung (Puffer wird wärmer ohne WP-Lauf) |

Weitere, ältere Fragen mit Standardannahmen: Abschnitt 25 im [Projektplan](PROJECT_PLAN.md).

## Erledigt

| Datum | Frage | Antwort |
|---|---|---|
| 2026-09-06 | K1/K2-Zuordnung (Q1) | `switch.warmepumpe` ist K1 „PV-Überschuss“: er fordert den Überschussbetrieb an und schaltet die Wärmepumpe **nicht** stromlos. Als Aktor gemappt, sicherer Zustand „aus“. Der Abschaltkontakt K2 an der Wärmepumpe ist noch nicht verdrahtet – nichts zu mappen |
| 2026-09-06 | Innenhof-Licht (Q6) | In HA eingerichtet als `switch.shellyplusplugs_64b7080cc70c`, als Aktor `courtyard_light` gemappt. Der Plug sendet zwar auch an den Broker, wird aber wie die beiden anderen Lichter über HA gelesen und geschaltet |
| 2026-09-06 | Pufferfühler-Reihenfolge (Q2) | Bestätigt am MQTT-Vollstand: aufsteigende Komponenten-ID = absteigende Temperatur, also `temperature:100` oben bis `:104` unten. `:103` ist der defekte vierte Fühler und bleibt unbelegt; `:104` gilt als „unten“ |
| 2026-09-06 | MQTT-Topic-Präfix der Gen-2-Shellys | Nicht die Gerätekennung, sondern der im Gerät gesetzte Name: `Pufferspeicher_Temperaturen`, `Lichterkette_Terassenlicht`, `Licht_Gartenzaun`, `Lichterkette_Innenhof`. Steht in jeder Nachricht im Feld `dst` |
| 2026-09-05 | Puffervolumen | 1000 l Kombipuffer; WP und Pelletofen speisen ein, Heizung und Warmwasser entnehmen |
| 2026-09-05 | Lichter | Drei Lichterketten: Terrasse, Innenhof (neu), Gartenzaun. Benennung „Licht <Ort>“ |
| 2026-09-05 | Entity-IDs Sensorik | Liste aus HA erhalten, Zuordnung in `config/entities.home.yaml` |
