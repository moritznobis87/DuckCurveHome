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

## Nachgezogen: die Absicht der Wärmepumpe von damals

Nach dem ersten Schritt zeigte der Streifen „Wärmepumpe geplant“ links der Jetzt-Linie weiter,
was die Preisregel *heute* über die Stunde sagen würde: Für vergangene Viertelstunden hat der
Optimierer keinen Fahrplan mehr, also greift im Dienst die Regel mit den Fenstern von heute. Und
neben der gemessenen Leistung stand links kein Plan.

| Streifen | links der Jetzt-Linie, vorher | jetzt |
|---|---|---|
| Wärmepumpe, kW elektrisch | nur die Messung | dazu gestrichelt die Leistung, mit der der Fahrplan von damals zählte |
| Wärmepumpe geplant | die Preisregel von heute | die Absicht des Fahrplans von damals: angefordert, nicht angefordert oder leer |

- **Die Absicht kommt aus dem archivierten `hp_release`**, auf demselben Weg wie in der
  Wiedergabe der Anlage. Das Archiv kennt nur Ja und Nein: „gemieden“ und „aus“ sind dort
  dasselbe Nein. Ja sieht im Streifen aus wie „angefordert“, Nein wie „aus“.
- **Leer heißt: nichts bekannt.** Der Fahrplan von damals gab nichts vor, oder es ist keiner
  aufbewahrt. Beides sieht im Archiv gleich aus.
- **Die Leistung von damals braucht eine neue Archivgröße** (`hp_kw`), weil eine Freigabe der
  Preisregel eine Erlaubnis ist und kein geplanter Lauf. Es gibt sie deshalb erst für
  Fahrpläne, die ab dieser Änderung abgelegt werden, und nur, wo der Optimierer führte.
- **Die Kachel „Wärmepumpe gelaufen“** vergleicht die Laufzeit jetzt mit den Freigaben von
  damals („im selben Fenster damals geplant“). Weiß das Archiv nichts, steht kein Vergleich da.
- **Eine Grenze:** Aufbewahrt wird jede Stunde ein Fahrplan, gerechnet wird jede Viertelstunde
  einer. Weicht der gemessene Kontakt von der Absicht ab, kann auch ein jüngerer, nicht
  aufbewahrter Fahrplan anders entschieden haben. Und sagte ein früherer Lauf Ja und der
  jüngste nichts mehr, steht das Ja des früheren da (`damals_nachschlag`).

Felder: `past_plan_hp_release`, `past_plan_hp_kw`. Die Regel, welche Viertelstunde als
vergangen gilt, steht im Dashboard in `fahrplanband.ts` und in der App in
`Fahrplanbild.absicht`: alles vor der Viertelstunde, in der der Fahrplan gerechnet wurde.

`absicht-von-damals-wand.png` zeigt das Dashboard an der Wand im Vorführhaus, im Zeitraffer.
Links von etwa 7 Uhr stehen im Leistungsstreifen die gestrichelten Blöcke von 4,5 kW neben der
gemessenen Kurve, darunter die Absicht von damals und die gemessene Anforderung. Die Jetzt-Linie
fehlt im Bild, weil sie im Zeitraffer auf der Uhr des Browsers steht.

## Was offen bleibt

- Die Kacheln „Wärmepumpe angefordert“ und „bewusst gemieden“ zählen den ganzen Horizont und
  damit für die vergangenen Stunden weiter die Preisregel von heute.
- Ein gemessener Wärmebedarf fehlt weiter; er kommt mit dem Wärmemengenzähler.
