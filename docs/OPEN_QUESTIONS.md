# Offene Fragen an den Hausherrn

Lebende Liste. Jede Frage nennt, was davon abhängt und mit welcher Annahme das System bis zur Antwort läuft.
Beantwortete Punkte wandern mit Datum und Antwort nach unten in „Erledigt“.

> Stand 06.09.: myenergi wird jetzt direkt aus der Cloud gelesen (`DCH_MYENERGI_SERIAL`/`_API_KEY`); die HA-Sensoren für PV, Netz, Batterie und Wallbox sind nur noch Rückfall. Q3 (Batterievorzeichen) ist damit fest im Code: interner Libbi-CT negiert, Entladen positiv.

## Offen

| Nr. | Frage | Hängt davon ab | Annahme bis zur Antwort |
|---|---|---|---|
| Q1 | **K1/K2-Zuordnung.** Welcher HA-Schalter hängt am ELCO-Kontakt K1 „PV-Überschuss“ und welcher an K2 „EVU-Sperre“? Kandidaten: `switch.warmepumpe` (war AN, während die WP 3 kW zog), `switch.heatpump_measurement` (Relais des Shelly 3EM), `switch.temperaturen_heizung` (Relais des Shelly Plus 1 mit Temperaturfühlern). Und: **Was schaltet `switch.warmepumpe` physisch?** Falls es die Versorgung der Wärmepumpe ist, darf DCH es niemals anfassen. | Aktoren in `config/entities.home.yaml`, Phase 3 (Steuerung) | Keine WP-Aktoren gemappt, reine Beobachtung |
| Q2 | **Pufferfühler-Reihenfolge.** Ist `sensor.speicher_1_temperature` oben und `speicher_5` unten? Ist Fühler 4 (`unknown`) defekt oder lose? | Schichtgewichte, thermischer SOC | 1 = oben … 5 = unten; Fühler 4 ausgelassen, 5 als „unten“ |
| Q3 | **Batterie-Vorzeichen beim Entladen.** Wird `sensor.myenergi_libbi_26244255_power_ct_internal_load` beim Entladen negativ? (Beim Laden war er positiv, 445 W.) Abends prüfen, wenn die libbi entlädt. | Energiebilanz, Überschussregel | Laden positiv → Mapping `charge_positive` |
| Q4 | **Zweiter Wechselrichter?** `sensor.nobis_solar_network_111_solar_power` meldet 2,49 kW, der myenergi-Hub 7,65 kW (drei harvi-CTs à ~2,55 kW). Separate Anlage, die die CTs nicht erfassen, oder dasselbe Gerät mit anderer Zählung? | PV-Gesamtleistung, Bilanz, Prognosekalibrierung | Hub-Wert ist die Gesamt-PV |
| Q5 | **Tibber-Sensor-Abweichung.** `sensor.electricity_waldstrasse_48_gesamtleistung` zeigte 3168 W Bezug, myenergi gleichzeitig 2378 W Einspeisung. Tibber Pulse vorhanden? War der Wert veraltet? | Zweite Netzmessung (Plan 25.4) | myenergi ist die Netzmessung |
| Q6 | **Innenhof-Licht.** Entity-ID des neuen Shelly, sobald in HA eingerichtet (erwartet `switch.shelly…`). | Kachel „Licht Innenhof“ | Aktor im Mapping auskommentiert, Kachel zeigt „–“ |
| Q7 | **Batterie-Schwelle für den WP-Überschuss.** Aktuell zählt Batterieladung erst ab 80 % SOC als nutzbarer Überschuss (Batterie hat Vorrang). Soll die Wärmepumpe bei großem Puffer-Ladebedarf früher Vorrang bekommen? | `count_battery_charging_above_soc` in der HEMS-Konfiguration | 0,8 |
| Q8 | **Pelletofen-Indikator.** Gibt es ein Signal für den Ofenbetrieb (Steckdosen-Shelly, Abgastemperatur, Zeitplan)? Siehe Plan 25.13 und Designdokument Prognose/Wärme. | Fremdwärme-Erkennung, Wärmebilanz des Puffers | Nur Residual-Erkennung (Puffer wird wärmer ohne WP-Lauf) |

Weitere, ältere Fragen mit Standardannahmen: Abschnitt 25 im [Projektplan](PROJECT_PLAN.md).

## Erledigt

| Datum | Frage | Antwort |
|---|---|---|
| 2026-09-05 | Puffervolumen | 1000 l Kombipuffer; WP und Pelletofen speisen ein, Heizung und Warmwasser entnehmen |
| 2026-09-05 | Lichter | Drei Lichterketten: Terrasse, Innenhof (neu), Gartenzaun. Benennung „Licht <Ort>“ |
| 2026-09-05 | Entity-IDs Sensorik | Liste aus HA erhalten, Zuordnung in `config/entities.home.yaml` |
