# Fahrplan, Voraus: was links und rechts der Jetzt-Linie steht

Der Hausherr am 27.11.2026 mit einem Bild der App (Anlage, Fahrplan, Voraus): „Warum gibt's
keinen geplanten Wärmebedarf elektrisch für die Wärmepumpe und warum ist in der Retrospektive
nicht ersichtlich, wie die Wärmeplanung gewesen ist und wie die Pufferfüllung verlaufen ist? Die
Diagramme sind ja da leer.“

## Was fehlte und warum

| Streifen | links der Jetzt-Linie | rechts der Jetzt-Linie |
|---|---|---|
| Wärmebedarf | leer | der Bedarf, gegen den der Optimierer rechnet |
| Pufferinhalt | leer | der geplante Inhalt |
| Wärmepumpe, kW elektrisch | die Messung | leer |

Der Optimierer rechnet immer ab jetzt. Über die Stunden davor weiß er nichts mehr, und was die
Fühler des Puffers maßen, kam nie bis zum Fahrplan. Für die Zukunft trug der Fahrplan nur, *ob*
die Wärmepumpe laufen soll, nicht mit welcher Leistung er sie zählt.

## Was jetzt dort steht

| Streifen | links der Jetzt-Linie | rechts der Jetzt-Linie |
|---|---|---|
| Wärmebedarf | der Bedarf im Plan von damals, blass | wie bisher |
| Pufferinhalt | gemessen, gefüllt, und der Plan von damals, gestrichelt | der geplante Inhalt, gestrichelt |
| Wärmepumpe, kW elektrisch | die Messung, gefüllt | die geplante Leistung, gestrichelt |

- **Gemessen gefüllt, geplant gestrichelt**, in allen Streifen wie bei der PV.
- **Die geplante Leistung ist der Nennwert** (`heat_pump.nominal_electric_power_kw`), mit dem der
  Optimierer Kosten und Pufferbilanz rechnet. Die Maschine zieht gemessen zeitweise deutlich
  mehr; neben der Messung ist dieser Abstand jetzt zu sehen.
- **Der gemessene Pufferinhalt** kommt aus den vier Fühlern der letzten Minute jeder
  Viertelstunde, nach derselben Rechnung wie der Startwert des Optimierers
  (`nutzbarer_inhalt_kwh`). Messung und Plan liegen damit auf einer Skala.
- **Der Plan von damals** kommt aus dem Prognosearchiv: je Viertelstunde der Wert des jüngsten
  Fahrplans, der *vor* ihr aufbewahrt wurde (`stand_vor`). Aufbewahrt wird stündlich. Nach einem
  Neustart des Dienstes fehlt er, bis der erste Fahrplan abgelegt ist.

Felder im Fahrplan (`PlanIntervalOut`): `planned_hp_kw`, `actual_buffer_kwh`,
`past_plan_heat_kw`, `past_plan_buffer_kwh`.

## Bild

`voraus-wand.png` zeigt das Dashboard an der Wand im Vorführhaus, im Zeitraffer aufgenommen. Die
Vorführung war dabei erst einige Stunden alt: der Plan von damals beginnt deshalb erst am
Nachmittag, und die rosa Jetzt-Linie steht auf der Uhr des Browsers statt auf der der Vorführung.

## Was offen bleibt

- Der Streifen „Wärmepumpe geplant“ zeigt links der Jetzt-Linie weiter, was die Preisregel heute
  für die Stunde sagen würde, und nicht die Absicht von damals. Sie liegt ebenfalls im Archiv
  (`hp_release`).
- Ein gemessener Wärmebedarf fehlt weiter; er kommt mit dem Wärmemengenzähler.
