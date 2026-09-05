# Prognoselernen und Wärmemodell

Status: Entwurf, 2026-09-05. Ergänzt die Abschnitte 19 (PV Forecast), 20 (Heat Demand) und 22 (Planungsmodell)
des [Projektplans](../PROJECT_PLAN.md). Umsetzung ab Phase 5, Datensammlung ab Phase 2.

## 1. Ausgangslage

Im Haus laufen bereits zwei externe PV-Prognosen in Home Assistant: forecast.solar (zwei Konfigurationen,
`…_3` und `…_4`, heute 36,9 bzw. 36,2 kWh) und Solcast (liefert derzeit 0, offenbar nicht fertig eingerichtet).
Duck Curve Home rechnet zusätzlich eine eigene Prognose aus Open-Meteo-Wetter und Anlagenparametern
(`hems_core.forecasting.pv_simple`). Keine dieser Quellen kennt die tatsächliche Erzeugung. Die einzige
Wahrheit ist der myenergi-Hub mit `power_generation`, ab Phase 2 minütlich in `measurements_1min`.

Wärmeseitig ist die Messung heute unvollständig: Außentemperatur nur als Wetterdienst-Wert, Wärmebedarf des
Hauses nur indirekt über die elektrische Leistung der Wärmepumpe und die vier Puffertemperaturen. Geplant ist eine
Messung des Wärmestroms, der aus dem Puffer ins Haus geht (Volumenstrom und Vor-/Rücklauftemperatur).

Der Puffer ist ein **1000-l-Kombispeicher**. Wärmepumpe **und** Pelletofen speisen ein, Heizkreis **und**
Warmwasser entnehmen. Das entkoppelt Erzeugung und Verbrauch zeitlich und macht den Puffer zum zentralen
Zustand des Wärmesystems, vergleichbar mit der Batterie auf der Stromseite.

## 2. PV-Prognose: Ensemble mit rollierender Korrektur

### 2.1 Warum kein Reinforcement Learning

Reinforcement Learning passt, wenn eine Folge von **Entscheidungen** eine verzögerte Belohnung erzeugt und die
Umgebung auf die Entscheidungen reagiert. Eine Prognose ist keine Entscheidung. Die Sonne reagiert nicht auf unsere
Vorhersage, und die Güte lässt sich für jedes Intervall direkt messen, sobald es vorbei ist. Das ist klassisches
**überwachtes Lernen mit Online-Aktualisierung**: Wir haben Eingaben (die externen Prognosen, Wetter, Sonnenstand),
ein Ziel (die gemessene Erzeugung) und bekommen die richtige Antwort jede Viertelstunde geliefert.

RL bringt hier drei Nachteile ohne Vorteil: hoher Datenbedarf, schwer erklärbare Modelle, und die Gefahr, dass
das Modell die Regelung „lernt“ statt der Physik. Wo RL später Sinn ergeben könnte, ist die **Regelstrategie**
selbst (wann die Wärmepumpe freigegeben wird), aber auch dort ist eine modellbasierte Optimierung mit einer guten
Prognose der sicherere Weg, weil sie erklärbar bleibt. Der Energy Plan muss den Grund nennen können.

### 2.2 Modellstufen

Jede Stufe ist eigenständig nützlich, wird täglich gegen die vorherige bewertet und nur aktiviert, wenn sie über
die letzten 14 Tage besser war. Damit kann nichts schlechter werden als die einfachste Variante.

**Stufe 0, Referenz.** Beste externe Quelle unverändert. Metrik: MAE und Bias je Stunde, MAPE je Tag.

**Stufe 1, Bias-Korrektur je Quelle.** Für jede Quelle `s` und jede Sonnenstandsklasse `b` (Elevation 0–10°,
10–20°, …, 60°+) ein Faktor `k[s,b]` als exponentiell gewichtetes Verhältnis Ist/Prognose, Halbwertszeit 10 Tage,
begrenzt auf [0,5; 1,5]. Fängt systematische Fehler: falsche kWp in forecast.solar, Horizontverschattung am Morgen,
Verschmutzung. Entspricht Abschnitt 19.4 des Plans, jetzt aber **je Quelle**.

**Stufe 2, Ensemble.** Gewichtete Summe der korrigierten Quellen. Gewichte `w[s]` aus der inversen mittleren
quadratischen Abweichung der letzten 14 Tage, getrennt für klare, wechselnde und bedeckte Tage (Klassifikation über
den Clear-Sky-Index der Vortagsmessung und Open-Meteo-Bewölkung). Quellen, die ausfallen oder `0` liefern wie
Solcast derzeit, werden automatisch auf Gewicht 0 gesetzt, nie fest ausgeschlossen.

**Stufe 3, Online-Regression.** Ridge-Regression, die alle 15 Minuten aktualisiert wird (rekursive kleinste
Quadrate mit Vergessensfaktor), mit den Merkmalen: Ensemble-Wert, Clear-Sky-Leistung, Bewölkung, Temperatur,
Tageszeit als Sinus/Kosinus, Erzeugung der letzten Stunde. Letzteres ist der eigentliche Hebel für die nächsten
1 bis 3 Stunden: Wenn die Wolkendecke gerade anders ist als vorhergesagt, ist die jüngste Messung der beste
Prädiktor. Genau dieser Horizont entscheidet über Freigabe oder Sperre der Wärmepumpe.

**Nicht geplant.** Neuronale Netze, Gradient Boosting oder Modelle mit mehr als etwa 20 Parametern. Bei einem Haus
mit einer Anlage gibt es nach einem Jahr rund 35 000 Viertelstunden, davon die Hälfte nachts. Kleine Modelle mit
Vergessensfaktor sind hier robuster und erklärbar.

### 2.3 Einspeiseprognose

Die Wallbox und die Batterie machen aus der PV-Prognose eine Einspeiseprognose:

```
export(t) = max(0, pv(t) − base_load(t) − battery_charge(t) − ev(t) − heat_pump(t))
```

Die Grundlast `base_load(t)` wird als Tagesprofil aus den letzten 28 Tagen gelernt (Median je Viertelstunde,
getrennt Werktag/Wochenende). Die Batterieladung folgt einer einfachen libbi-Heuristik: lädt mit bis zu 3,7 kW,
sobald Überschuss da ist, bis SOC 100 %, Kapazität 5,1 kWh. Beides ist ohne Lernen nutzbar und wird später gegen
die Messung von `power_export` bewertet. Die Einspeiseprognose ist die Größe, die der Planer für das Fenster
„PV-Überschuss nutzen“ braucht, nicht die Bruttoerzeugung.

### 2.4 Datenhaltung und Bewertung

Prognosen werden versioniert (`forecast_runs`, `forecast_points`, Plan Abschnitt 21). Neu kommt eine Tabelle
`forecast_scores` mit je einer Zeile pro Quelle, Tag und Horizontklasse (0–3 h, 3–12 h, 12–36 h): MAE, Bias, RMSE,
Anzahl Intervalle. Der Energy Plan zeigt im Block „Ziel & Ausblick“ die Güte der letzten 7 Tage als
„Prognosegüte ±x %“, damit sichtbar bleibt, wie sehr man dem Plan trauen kann. Ein Kalibrierlauf pro Nacht um 23:30
und eine Aktualisierung der Kurzfristkorrektur alle 15 Minuten.

Die HA-Prognosen erreichen DCH über die Bridge wie Sensoren (`entities.yaml`, Schlüssel `pv_forecast_ext_*`),
mit `stale_after_s: 7200`. Sie sind Eingaben, keine Wahrheit.

## 3. Wärmemodell

### 3.1 Bilanz um den Kombipuffer

Der Puffer ist der Knoten, an dem alles zusammenläuft:

```
dE_buffer/dt = Q_hp + Q_pellet − Q_heating − Q_dhw − Q_loss
```

| Größe | Heute messbar | Später messbar |
|---|---|---|
| `E_buffer` | ja, aus vier Schichttemperaturen (`layered_energy_v1`) | besser mit Fühler 4 und bekannten Anschlusshöhen |
| `Q_hp` | indirekt: elektrische Leistung × COP(T_außen) | direkt mit Wärmemengenzähler im WP-Kreis |
| `Q_pellet` | nur als Residual (Puffer wird wärmer ohne WP-Lauf) | Indikator laut Frage Q8 |
| `Q_heating + Q_dhw` | nur als Residual | **direkt mit Wärmestrommessung ins Haus** |
| `Q_loss` | Modell `loss_kw_per_k · (T_mittel − T_raum)` | aus Stillstandsphasen kalibriert |

Solange nur `E_buffer` und `Q_hp` bekannt sind, hat die Bilanz **zwei Unbekannte** (Pellet und Entnahme), die sich
nicht trennen lassen. Die geplante Wärmestrommessung ins Haus löst genau das: Dann ist `Q_pellet` das einzige
Residual und lässt sich sauber erkennen. Das ist der wichtigste nächste Messpunkt, wichtiger als ein zusätzlicher
Außenfühler.

### 3.2 Wärmestrommessung

Empfohlen ist ein Wärmemengenzähler im Heizkreisvorlauf hinter dem Puffer (Ultraschall oder Flügelrad, M-Bus oder
Impulsausgang), alternativ Volumenstromsensor plus zwei Anlegefühler:

```
Q_heating = V̇ · ρ · c_p · (T_vorlauf − T_rücklauf)      [kW]     ρ·c_p ≈ 1,16 kWh/(m³·K)
```

Mit Impulsausgang reicht ein Shelly Plus 1 mit Add-on zum Zählen, M-Bus über einen kleinen Gateway nach HA. Beide
Wege landen als normale Sensoren in `entities.yaml` (`heat_flow_house_kw`, `heat_energy_house_kwh`). Warmwasser
separat zu messen ist zweitrangig, weil sich der Warmwasseranteil als Tagesprofil aus Zapfspitzen im Gesamtstrom
gut herausrechnen lässt.

### 3.3 Wärmebedarfsprognose

Der Wärmebedarf wird in zwei Schritten vorhergesagt.

**Physikalischer Kern.** Heizgradstunden aus der Außentemperaturprognose (Open-Meteo, stündlich, 7 Tage):

```
Q_heating(t) = H · max(0, T_in − T_out(t)) − Q_solar(t) − Q_internal
```

`H` in kW/K ist der Verlustkoeffizient des Hauses. Ohne Messung wird er geschätzt (Plan 20.2), mit der
Wärmestrommessung nach 2 bis 3 Wochen per Regression bestimmt: Tagesenergie ins Haus gegen Heizgradstunden des
Tages. Steigung `H`, Achsenabschnitt ist der Warmwasser- und Grundanteil. Das ist derselbe Ansatz wie in 20.4, nur
mit einer echten Messung statt COP-Schätzung.

**Gelernte Korrektur.** Wie bei der PV: rollierende Bias-Korrektur je Außentemperaturklasse und Wochentag,
Halbwertszeit 14 Tage. Fängt Nutzerverhalten (Nachtabsenkung, Lüften, Gäste) und Sonnengewinne durch Fenster.

Die Zeitkonstante des Hauses `τ = C/H` folgt aus Abkühlkurven, falls später eine Innentemperatur vorliegt (Plan
25.7). Für den Puffer braucht man sie nicht, für Gebäude-Vorheizen in Phase 6 schon.

### 3.4 Was der Puffer für die Regelung bedeutet

Der Puffer entkoppelt zeitlich, aber begrenzt. Nutzbare Energie zwischen 35 und 62 °C bei 1000 l:
rund 31 kWh_th. Bei einem Winterbedarf von 3 bis 5 kW_th sind das 6 bis 10 Stunden Überbrückung, im Sommer für
Warmwasser mehrere Tage. Daraus folgen die Planungsregeln:

1. **PV-Fenster nutzen, solange Ladehub da ist.** Freigabe der Wärmepumpe im Überschussfenster nur, wenn
   `soc < 0,9` und der prognostizierte Bedarf bis zum nächsten günstigen Fenster die Ladung auch abruft. Einen Puffer
   auf 62 °C zu laden, der bis morgen Mittag nichts abgibt, kostet nur Verluste.
2. **Pelletofen hat Vorrang vor Netzstrom.** Erkennt das System Fremdwärme (Q_pellet > 0), wird die Wärmepumpe im
   Preisfenster nicht freigegeben, weil der Ofen den Puffer ohnehin füllt. Im PV-Fenster bleibt die Freigabe
   erlaubt, der Strom wäre sonst Einspeisung.
3. **Kaltstarts vermeiden.** Fällt der SOC unter 0,2 mit fallender Tendenz, wird die Wärmepumpe unabhängig vom
   Preis freigegeben (`heat_demand_forced`). Komfort schlägt Optimierung.
4. **Warmwasser-Komfort über die oberste Schicht.** `comfort_min_top_c` (42 °C) ist die harte Grenze, sie hängt an
   Fühler 1, deshalb ist Frage Q2 (Fühlerreihenfolge) wichtig.

Die Regelung nutzt dafür nur Größen, die heute schon vorliegen. Die Wärmestrommessung verbessert die Prognose und
macht die Pellet-Erkennung sauber, ist aber keine Voraussetzung für Phase 3 und 4.

## 4. Reihenfolge der Umsetzung

| Schritt | Phase | Voraussetzung |
|---|---|---|
| HA-Prognosen als Sensoren in die Bridge aufnehmen, Rohdaten speichern | 2 | entities.yaml |
| `forecast_scores` und Güteanzeige im Energy Plan | 4 | 14 Tage Daten |
| Stufe 1 und 2 (Bias-Korrektur, Ensemble) | 5 | 14 Tage Daten |
| Einspeiseprognose mit Grundlastprofil und Batterieheuristik | 5 | Stufe 2 |
| Wärmestrommessung installieren und mappen | 5 | Zähler (Frage an den Hausherrn: Platz im Vorlauf, Busanbindung) |
| `H` aus Regression, Wärmebedarfsprognose mit Korrektur | 5/6 | 3 Wochen Messung in der Heizperiode |
| Stufe 3 (Online-Regression, Kurzfristhorizont) | 6 | Stufe 2 stabil, Kennzahlen vorhanden |
| Pufferbewusste Planung (Abschnitt 3.4) im Scheduler | 5/6 | Wärmebedarfsprognose |

Alle Modelle liegen in `hems_core.forecasting` ohne I/O, mit Tests auf synthetischen Daten. Persistenz und
Kalibrierläufe gehören in die API (`dch_api.application`). Kein Modell darf ohne Vergleich gegen die Referenzstufe
aktiv werden.
