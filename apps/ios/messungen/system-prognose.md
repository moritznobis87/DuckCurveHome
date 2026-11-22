========================= messen:system-prognose   Aufwand: mittel

Gemessen am 20.11.2026. Diese Seite war schon einmal nachgearbeitet (ABGLEICH.md:345-375,
sechs Punkte: Tagesdiagramm, Quellentabelle, Vorlaufklassen, Bias, Tagewahl) - alle sechs sind
im Code. Was hier steht, ist das, was danach noch offen ist. Jede Zeile ist am Code
nachgesehen, nicht aus ABGLEICH.md übernommen.

Vorlage: `apps/web/src/app/system/page.tsx:1-7` → `components/forecast/ForecastPage.tsx`
(375 Zeilen) + `components/forecast/Rueckblick.tsx` (216 Zeilen).
App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:200-598` (`PrognoseSeite`),
Zeichnungen in `apps/ios/DuckCurveHome/Diagramme/Prognosezeichnung.swift` (877 Zeilen),
Rechnung in `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Prognosebild.swift` (448 Zeilen).

---

IST: Was die App-Seite heute von oben nach unten zeigt.

1. Kicker rechts über dem Rollbereich: „PV-Prognose gegen Ist · Korrekturfaktoren",
   aus `Bereiche.swift:212-213`, gezeichnet von `Seitenwahl.swift:208-213`; am Telefon weg.
2. Störungsband, wenn die Bewertung scheitert - `SystemSeiten.swift:222-224` (`Stoerung`,
   `Karte.swift:419-465`).
3. Kopfzeile `SystemSeiten.swift:253-265`: an der Wand rechtsbündig „Stand 14:35 · Bridge
   (PV-Prognose)" (`standwort`, :275-278) plus `Stufenmarke` (:157-188); am Telefon nur die Marke.
4. Kennzahlfeld `SystemSeiten.swift:226-228`: eine Karte mit Kicker „Heute", darin die fünf
   Kennzahlen aus `Prognosebild.kacheln` (`Prognosebild.swift:159-192`), zweispaltig
   (`Karte.swift:274-343`, `spalten: 2`), am Telefon führt die erste groß.
5. Hauptkarte `SystemSeiten.swift:289-307`: Kicker „Heute · Prognose gegen Ist", Titel
   „MAE 0,76 kW · Bias −0,12 kW · +12,4 %" (`guetezeile`, :310-317), rechts `Ansichtswahl`
   Heute/Gestern; Inhalt `Prognosekurvenbild` (`Prognosezeichnung.swift:175-351`): Ablesezeile
   oben, Chart (Fläche + drei Linien + Jetzt-Linie), Legende darunter.
6. Dreierreihe `SystemSeiten.swift:324-336`: an der Wand ein `HStack` mit drei gleich breiten
   Karten, am Telefon untereinander -
   `tagesenergiekarte` (:338-345, `Tagesenergiebild` :361-454),
   `horizontkarte` (:347-351, `Horizontbild` :464-540),
   `faktorkarte` (:353-356, `Faktorenbild` :556-684).
7. Zweierreihe `SystemSeiten.swift:371-380`: `aenderungskarte` (:390-434, nummerierte Liste
   `nextChangesDe` + Trennlinie + `notesDe` offen) und `quellenkarte` (:444-499, `Tabelle` mit
   drei Spalten plus Schlusssatz `quellensatz` :503-509).
8. Rückblick `SystemSeiten.swift:511-542`: Überschrift + `Tagewahl` 3/7/14/30 d, darunter je
   Reihe **untereinander** eine Karte mit `Vorlaufbild` (`Prognosezeichnung.swift:699-807`),
   zum Schluss `Methode(… titel: "Wie der Rückblick zu lesen ist")` - zugeklappt.
9. Nachladen: Bewertung alle 300 s (`SystemSeiten.swift:568-573`), Rückblick alle 600 s und
   bei jeder neuen Tageszahl (:591-598).

---

VORLAGE:

  * **Hülle und Kopf** (`AreaShell.tsx:14-31`, eingesetzt `ForecastPage.tsx:245-248`)
    Kopfband `min-h-14`, Rand `line-2`, Radius 6, Grund `--surface-glass`
    (`tokens.css:26`, rgba(8,36,49,.38)) mit `blur(18px)`.
    Rechts zwei Dinge: „Stand HH:MM · <sources[0].label_de>" in Mono 12 px, Versalien,
    0.1em, `--text-3` - **erst ab 1400 px sichtbar** (`min-[1400px]:inline`,
    `ForecastPage.tsx:246`); und ein `Pill` (`ui/Pill.tsx:1-12`): Mono 12 px, Versalien,
    0.08em, Polster 10/4, Radius 2, bei `correction_active` Schrift `--amber` auf
    rgba(242,169,0,.14) mit Rand rgba(242,169,0,.35), sonst `--text-2` auf rgba(255,255,255,.06)
    mit Rand `--line-2`. Text: `stage_de` + „ · aktiv" bzw. „ · lernt" (`ForecastPage.tsx:247`).
    Der Seitenkicker „PV-Prognose gegen Ist · Korrekturfaktoren" hängt rechts an der Reiterzeile
    und trägt `hidden … md:block`, Schriftgröße 11 (`AreaNav.tsx:96`).
    Handy: `handy.css:137-154` - Kopf ohne Rahmen und Grund, Bereichsname 26 px/600,
    `.report-header-right { display: contents }`, jedes Kind `flex: 1 1 100%`; die
    Prognosemarke darf dort ausdrücklich umbrechen (`handy.css:152-154`, Kommentar
    „Ein Abzeichen im Kopf (Prognosestufe) bricht um, statt am Rand abgeschnitten zu werden").
    DATEN: eine Abfrage, `api.forecastEvaluation()` → `GET /forecast/evaluation`
    (`lib/api/client.ts:64`), alle 5 min (`ForecastPage.tsx:27,224`). `generated_at` setzt
    zugleich `nowMs` (:217).

  * **Fehlerband** (`ForecastPage.tsx:250-254`)
    Mono 12 px, Versalien, 0.1em, Radius 3, Rand rgba(224,83,61,.4), Grund rgba(224,83,61,.12),
    Schrift `--alert`. Text: `ApiError.message` oder wörtlich „Auswertung nicht verfügbar."
    (:220). Steht **über** allem anderen, ersetzt nichts.

  * **Fünf Kennzahlkacheln** (`ForecastPage.tsx:259-265`, `Stat` :182-193)
    `KpiGrid cols={5}` (`reports/ReportShell.tsx:176-182`) → `.kpi-grid`
    (`globals.css:107`): `repeat(auto-fit, minmax(clamp(150px, 100%/5 - 16px, 260px), 1fr))`,
    gap 16. An der Wand sind das **fünf eigene Karten in einer Reihe**, jede
    `--surface-2`, Rand `--line-1`, Radius 3 (`globals.css:67-77`), hier mit Polster 14/18 und
    gap 6 (`ForecastPage.tsx:185`). Kicker 11 px (`:186`), Zahl Mono 28 px,
    `leading-none`, `tracking-[-.02em]` (`:187`), Einheit 13 px in Sans, `--text-3` (`:189`).
    Töne: `amber` → `var(--amber)`, `ember` → **`var(--alert)` #e0533d**, `muted` → `--text-3`
    (`:183`).
    Keine Überschrift über dem Feld.
    Wörtlich, in dieser Reihenfolge:
      1. „Heute · Ist bis jetzt" — `today.score.energy_actual_kwh`, 1 Stelle, kWh, Ton amber
      2. „Heute · Day-ahead bis jetzt" — `today.score.energy_forecast_kwh`, 1 Stelle, kWh
      3. „Heute · Abweichung" — `pct(today.score.energy_error_pct)` („+12,4 %"), Ton `ember`,
         sobald `|pct| > 15` (`:262`)
      4. „MAE · 7 Tage" — `sources[0].mae_7d_kw`, 2 Stellen, kW (`:239,:263`)
      5. „Tage innerhalb ±15 %" — `hits / recent.length` aus `daily.slice(-7)` (`:238,:241`),
         Ton `muted`
    Fehlt ein Wert: „-" (`de()`/`pct()`, :29-30).
    Handy (`handy.css:197-207`): **eine** Fläche `--surface-2`, Radius 16, Polster 4/16,
    zwei Spalten, gap 0/20; die erste Kachel über die ganze Breite ohne obere Haarlinie, Zahl
    48 px mit `letter-spacing: -0.04em`, Einheit 18 px; die übrigen mit Haarlinie `--line-1`
    darüber, Zahl 25 px, Einheit 13,5 px; Kicker 11 px/0.1em; bleibt am Ende eine Kachel
    allein, nimmt sie die ganze Zeile (`:200`).
    DATEN: nur `today.score` (`ForecastScore`: n, mae_kw, bias_kw, rmse_kw,
    energy_forecast_kwh, energy_actual_kwh, energy_error_pct - `lib/api/types.ts:3474-3490`),
    `daily[].energy_error_pct` (`:2808-2826`), `sources[0].mae_7d_kw` (`:7741-7745`).

  * **Hauptdiagramm „Heute/Gestern · Prognose gegen Ist"** (`ForecastPage.tsx:267-293`,
    Option `dayOption` :42-87)
    Karte mit Polster 16 und **fester Höhe 340 px**; Kopfzeile umbruchfähig
    (`flex-wrap`, gap 4/2).
    Links: `h2.kicker` „Heute · Prognose gegen Ist" bzw. „Gestern · …", daneben drei
    Legendenstriche (`Legend` :195-202: 18 px breiter `border-top: 2px`, Text 12 px `--text-2`):
      - durchgezogen `#f2a900` „Ist (15-min-Mittel)"
      - gestrichelt `#e4ecef` „Day-ahead" + „ · ausgegeben HH:MM" aus `day.issued_at`
      - gepunktet `#7fa3b3` „Jüngster Lauf, korrigiert" - nur bei „Heute"
    Rechts: „MAE x kW · Bias y kW · ±z %" in Mono 12 px, `--text-3`, **erst ab 1400 px**
    (`:279`); dann der Umschalter: ein Kasten mit Rand `line-2`, Radius 3, ohne Füllung, zwei
    Knöpfe in **Mono 12 px, Versalien, `tracking-[.08em]`, Polster 16/8**; der gewählte
    `--amber` auf Grund mit Schrift `--petrol`, der andere `--text-3` (`:283-288`).
    Diagramm: Querachse Zahlenachse 0…24, `interval: 3`, Beschriftung „00:00"…„24:00",
    Mono 11 px `rgba(255,255,255,.48)`, keine Rasterlinien, Achsenlinie
    `rgba(255,255,255,.2)`. Hochachse 0…`ceil(max*1.1/2)*2`, `interval` = Hälfte davon (also
    genau drei Marken), Name „kW" 10 px rechtsbündig, Rasterlinien `rgba(255,255,255,.09)`.
    Gitter `left 48, right 16, top 24, bottom 34`.
    Reihen: Ist = Linie 2,5 px `#f2a900` **plus** Fläche mit Verlauf rgba(242,169,0,.3) →
    rgba(242,169,0,.03), `z: 3`; Day-ahead = Linie 2 px `#e4ecef`, Muster `[7,6]`;
    Korrigiert = Linie 2 px `#7fa3b3`, Muster `[2,4]`, nur heute (`:47`).
    Jetzt-Linie: `markLine` bei `generated_at`, **`#f2a900`**, gestrichelt, 1,5 px, ohne
    Beschriftung, nur heute (`:50`) - und nicht in der Legende.
    Hinweisfenster (`trigger: "axis"`): Kopf = Uhrzeit, darunter je Reihe
    „<Name> … <Wert> kW", Werte mit `null` fallen weg (`:58-67`); Grund `#082431`, Rand
    rgba(255,255,255,.14), Radius 3, Mono 12 px.
    Zustände: kein Punkt → `dayOpt` ist `null`, die Fläche bleibt leer (kein Satz!);
    `ev == null` → dieselbe leere Fläche, aber Kacheln, Tabelle und Listen stehen schon mit „-"
    da (`:260-264`, `:354`).
    Handy: `charts/handy.ts:44-62` hebt nur die Achsenschrift auf mindestens 11 px, setzt
    `hideOverlap`, begrenzt freie Wertachsen auf drei Schritte und `tooltip.confine` -
    **ein gesetztes `interval: 3` bleibt** (`handy.ts:37`), die Querachse behält am Telefon
    alle drei Stunden.
    DATEN: `today`/`yesterday` als `ForecastDayOut` (day, issued_at, score, points) und
    `ForecastPointOut` (ts, actual_kw, day_ahead_kw, latest_kw, corrected_kw -
    `types.ts:3458-3472`). `latest_kw` wird nicht benutzt.

  * **Reihe aus drei Karten** (`ForecastPage.tsx:295-323`)
    `.report-row` mit `--cols: 5fr 3fr 4fr` (`globals.css:108`), gap 16; am Telefon eine
    Spalte (`globals.css:350`), gap 14 (`handy.css:209`). Jede Karte Polster 16, Höhe 280 px.

    a) **„Tagesenergie · letzte N Tage"** (`:296-305`, Option `dailyOption` :89-114)
       N = `Math.min(14, daily.length)` - die Zahl steht wirklich im Titel (`:298`).
       Rechts im Kopf zwei Legendenstriche: rgba(228,236,239,.55) „Day-ahead", `#f2a900` „Ist".
       Querachse Kategorien, Beschriftung = die ersten zwei Zeichen von
       `dayLabel(day)` („Mo"), Mono 10 px. Hochachse Name „kWh", `splitNumber: 3`.
       Säulenpaare: „Prognose" rgba(228,236,239,.55), „Ist" `#f2a900`, beide
       `borderRadius: [2,2,0,0]`, `barGap: "10%"`, `barCategoryGap: "35%"`.
       Auskunft: Kopf `dayLabel(day)` („Mo., 17.11."), je Reihe „… x kWh", darunter
       „Abweichung ±y % · MAE z kW" (`:103`).
       DATEN: `daily.slice(-14)` mit energy_forecast_kwh, energy_actual_kwh,
       energy_error_pct, mae_kw.

    b) **„Fehler nach Horizont"** (`:306-313`, Option `horizonOption` :116-140)
       `CardHead` (`ui/Card.tsx:20-28`): Titel als `h2.kicker`, rechts wörtlich
       „gestern und heute, alle Läufe" in 12 px `--text-3`.
       Legende **unter** dem Bild: `#7fa3b3` „MAE", rgba(228,236,239,.4) „|Bias|".
       Querachse `horizons[].key` („0-3h"), Hochachse Name „kW", `min: 0`, `splitNumber: 3`.
       Zwei Säulen je Klasse, `barCategoryGap: "45%"`, Radius [2,2,0,0]. Die Vorlage zeichnet
       auch für `n == 0` eine Säule.
       Auskunft: Kopf `label_de` („nächste 3 Stunden"), eine Zeile
       „MAE x kW · Bias y kW · n = N" (`:129`).
       DATEN: `horizons[]` (key, label_de, score) - `types.ts:4829-4834`.

    c) **„Korrekturfaktoren nach Sonnenhöhe"** (`:314-322`, Option `factorOption` :142-180)
       Rechts im Kopf „<days_learned> Lerntage · Halbwertszeit <half_life_days> d" (`:315`).
       **Begründung aus dem Vorlagencode** (`:143`, wörtlich): „Abweichung von 1,00 in
       Prozentpunkten: Balken stehen auf der Nulllinie, nicht auf dem Achsenminimum."
       Gerechnet: `dev(x) = round((x-1)*1000)/10`; Spanne
       `max(10, ceil(max|dev|*1.15/10)*10)` **über alle drei Reihen** (:146-147), Achse
       `-span…+span`, `interval: span/2` (also fünf Marken), Beschriftung „+7 %"/„-3 %" ohne
       Nachkomma (`fmt`, :148).
       Säule: `factor < 1` → `#e0533d`, sonst `#f2a900`, Radius 2, `barCategoryGap: "45%"`;
       dazu eine `markLine` bei y = 0 in rgba(255,255,255,.55), durchgezogen, 1 px.
       „Gestern" = Raute `#e4ecef`, Größe 9; „Letztes Ist/Prognose" = Kreis `#7fa3b3`, Größe 7.
       Legende unter dem Bild, **drei** Stücke mit Formen (`:317-321`): Quadrat 12 px `#f2a900`
       „Faktor heute", gedrehtes Quadrat 10 px `#e4ecef` „gestern", Kreis 10 px `#7fa3b3`
       „letztes Ist/Prognose".
       Auskunft: „Sonnenhöhe <label_de>", dann „Faktor 1,073 · gestern 1,068", dann
       „letztes Ist/Prognose 1,110 · 12 Lerntage" - Faktoren mit **drei** Nachkommastellen
       (`:160`).
       DATEN: `corrector` (`CorrectorState`: bins, k_global, k_global_previous, days_learned,
       min_days, half_life_days, updated_on - `types.ts:2674-2702`), `bins[]` =
       `BinCorrection` (bin, label_de, factor, previous, last_ratio, days).

  * **Reihe aus zwei Karten** (`ForecastPage.tsx:325-368`)
    `.report-row` mit `--cols: 7fr 5fr`, am Telefon eine Spalte.

    a) **„Was sich für die nächste Prognose ändert"** — `Card accent`, Polster 18 (`:326`).
       `accent` heißt: 3 px Band über der ganzen Kartenbreite,
       `background: var(--accent-bar)` = `linear-gradient(90deg, var(--amber),
       var(--amber-soft), transparent 86%)` (`globals.css:78-85`, `tokens.css:98`).
       Rechts im Kopf „Tagesabschluss Mo., 17.11." aus `corrector.updated_on`, sonst wörtlich
       „noch kein Tagesabschluss" (`:327`).
       Liste: `ol` ohne Punkte, gap 8; je Zeile links die Nummer „01", „02" in Mono 11 px
       `--text-3` mit 3 px Grundlinienversatz, rechts der Satz in 14 px, Zeilenhöhe 1,5,
       `--text-1` (`:328-335`).
       Darunter, **offen** und nur durch `border-top: 1px --line-1` getrennt (`:336-340`):
       `notes_de`, je Satz 12 px, Zeilenhöhe 1,5, `--text-3`.
       Leeres `next_changes_de` → leere Liste, kein Satz.
       DATEN: `next_changes_de`, `notes_de`, `corrector.updated_on`.

    b) **„Quellen und Gewichte"** — Polster 18 (`:342`).
       Rechts im Kopf „Ist/Prognose gesamt 1,04" aus `corrector.k_global` (`:343`).
       Tabelle 13 px, vier Spalten, Kopfzeile als `.kicker` mit Größe 11
       (`:346-351`): „Quelle" (links), „Gewicht", „MAE 7 d", „Status" (alle rechts).
       Je Zeile `border-top: 1px --line-1`; Spalte 1 = `label_de` in `--text-1` und
       **darunter** `name` in Mono 11 px `--text-3` (zwei Zeilen, `:356`); Gewicht und MAE in
       Mono, rechtsbündig, MAE mit „ kW" bzw. „-"; Status „aktiv" in `--amber` / „aus" in
       `--text-3`, Mono 11 px, Versalien, 0.1em (`:359`).
       Schlusssatz 12 px, Zeilenhöhe 1,55, `--text-3`, wörtlich (`:364-366`):
       „Weitere Quellen (forecast.solar, Solcast aus Home Assistant) kommen mit der Bridge
       dazu und werden hier nach ihrer Güte gewichtet. Bias 7 Tage: <x> kW · aufbewahrte
       Läufe: <runs_kept>."
       `bias7` ist das Mittel von `daily.slice(-7)[].bias_kw` (`:240`).
       Handy: `handy.css:183-185` macht aus `h2.kicker` im Kartenkopf **Sans 16,5 px/600,
       keine Versalien, `--text-1`**, und der Kopfzusatz rutscht als eigene Zeile mit 13 px
       darunter. Diese Tabelle fällt **nicht** unter die Listenregel
       (`handy.css:305-306` nennt nur `.kosten-tabelle`, `.fp-entscheidungen`, `.nb-tabelle`,
       `.fenster-tabelle`) - sie bleibt vierspaltig.
       DATEN: `sources[]`, `corrector.k_global`, `daily[].bias_kw`, `runs_kept`.

  * **Rückblick** (`ForecastPage.tsx:372` → `Rueckblick.tsx:130-216`)
    **Begründung im Vorlagencode** (`Rueckblick.tsx:11-22`, gekürzt wörtlich): „Bis hierher war
    `forecast_runs` eine Tabelle, in die geschrieben und aus der nie gelesen wurde. … Zwei
    Zahlen je Klasse, und beide sind nötig. Der mittlere Fehler sagt, wie es im Schnitt lief;
    der Rand sagt, womit der Fahrplan im schlechtesten Fall rechnen muss. Für eine harte
    Komfortgrenze zählt der Rand, nicht die Mitte." Und zur Farbe (`:29-34`): „Farben geprüft
    mit dem Palettenprüfer der dataviz-Anleitung gegen die Kartenfläche #123544, Modus dunkel:
    ΔE 23,4 normal und 15,1 deutan zwischen den beiden. … Die Form trennt sie zusätzlich -
    Fläche gegen Punkt." Und zur Paarzahl (`:64`): „eine Sprosse aus drei Proben ist keine
    Aussage."
    Abschnittszeile (`:160-180`), umbruchfähig: links `h2.kicker` „Rückblick · abgelegte Läufe
    gegen das Ist"; rechts **einmal** die Legende - Quadrat 12 px `#7fa3b3` „mittlerer Fehler",
    **Punkt** 8 px `#e0533d` „Rand (95 %)" (`Legend` :118-128) - und daneben vier Knöpfe
    3/7/14/30, Mono 11 px, Radius 3, Polster 8/3, gap 4; gewählt Rand `line-1`/Schrift
    `text-1`, sonst Rand `line-2`/Schrift `text-3`, nie ein Füllgrund (`:173`).
    Dann `.report-row` mit `--cols: repeat(<Zahl der Reihen>, minmax(0,1fr))` (`:182`) -
    **die Reihen stehen nebeneinander**; je Reihe eine Karte, Polster 16, Höhe 250 px:
      - `CardHead` Titel „<label_de> · <einheit>" (`:187`), rechts „<n> Paare · Bias +0,12 <einheit>"
        oder, wenn `gesamt.n == 0`, „<laeufe> Läufe, keine Paare" (`:189-191`).
      - Bild (`option` :36-116): Querachse `je_vorlauf[].key` („0-1h" … „24-48h"), Mono 10 px;
        Hochachse `min: 0`, Mono 10 px, Rasterlinien rgba(255,255,255,.09); Gitter
        `left 44, right 14, top 18, bottom 28`.
        Säule „mittlerer Fehler" `#7fa3b3`, **`barWidth: "52%"`**, Radius [2,2,0,0];
        Linie „Rand (95 %)" `#e0533d`, 1 px, gestrichelt, Kreise Größe 7.
        `n == 0` → `null`, **keine** Nullsäule (`:38-39`).
        Sind alle Klassen leer, steht mitten im Gitter „keine Paare im Zeitraum" in Mono 11 px
        `rgba(255,255,255,.48)` (`:100-114`).
        Auskunft: „<label_de> · <n> Paare", darunter die beiden Werte mit der Einheit der Reihe.
    Zum Schluss (`:200-213`) eine **`Card accent`**, Polster 18, Titel „Wie der Rückblick zu
    lesen ist", rechts „<tage> Tage · <reihen[0].laeufe> Läufe im Bestand"; darin **offen** der
    Fehler (13 px `--text-2`, Text „Rückblick nicht verfügbar." bzw. die Meldung des Dienstes,
    `:145`, `:205`) und darunter alle `hinweise_de`, je 12 px, Zeilenhöhe 1,55, `--text-3`.
    Nichts davon ist einklappbar.
    DATEN: zweite, eigene Abfrage `api.forecastHistory(tage)` →
    `GET /forecast/history?days=N` (`lib/api/client.ts:65-67`), alle **10** min (`:24,:149`);
    `ForecastHistoryOut` (generated_at, von, bis, tage, reihen, hinweise_de -
    `types.ts:3434-3456`), `ReiheOut` (key, label_de, einheit, gesamt, je_vorlauf, laeufe -
    `:6400-6412`), `Wertung` (n, mae, bias, rmse, p95), `VorlaufOut` (key, label_de, wertung).

  * **Maße, die in den Dateien stehen und nicht im TSX**
    `globals.css:57-64` `.kicker`: **Mono 13 px**, Zeilenhöhe 1,2, `letter-spacing: 0.13em`,
    Versalien, Farbe `--text-kicker` = `--mist` #7fa3b3.
    `globals.css:67-77` `.card`: Grund **`--surface-2` #123544**, Rand 1 px `--line-1`,
    Radius `--radius-2` = **3 px** (`tokens.css:93`), Polster **20 px**, `overflow: hidden`.
    `globals.css:78-85` `.card-accent::before`: 3 px hohes Band, `--accent-bar`.
    `globals.css:107-108` `.kpi-grid` / `.report-row` wie oben.
    `globals.css:349-350` (≤720 px): `.kpi-grid` zwei Spalten, `.report-row` eine.
    `handy.css:110-111`: Seitenrand 10/16, unten 86 px + Safe Area, `gap: 14`, Grundschrift 15.
    `handy.css:182`: `.card` ohne Rand, Radius **16**, Polster 16 - der Grund bleibt
    `--surface-2`.
    `handy.css:189-192`: **jede kleine Schrift eine Stufe größer** - 10→11, 11→12, 12→13,5,
    13→14,5 px, mit der Begründung „Am Rechner liest man 12 Punkt aus sechzig Zentimetern, am
    Handy aus dreißig, aber im Gehen."
    `handy.css:114-134`: die Bereiche stehen am Telefon unten als `.fussleiste`.

---

LUECKEN:

  [spuerbar] **Die Rückblickreihen stehen untereinander statt nebeneinander.** Vorlage
    `Rueckblick.tsx:182`: `.report-row` mit `repeat(<Zahl der Reihen>, minmax(0,1fr))`, also an
    der Wand so viele Spalten wie Reihen (heute PV und Außentemperatur, `types.ts:3440-3447`).
    App `SystemSeiten.swift:528-532`: `ForEach(v.reihen)` mit `Karte` je Reihe, direkt im
    `VStack` von `Seite` - immer eine Spalte. Die Seite setzt dieselbe Entscheidung zweimal
    richtig (`dreierreihe` :324-336, `zweierreihe` :371-380) und hier nicht.

  [spuerbar] **Die Lesehilfe des Rückblicks liegt unter einem Deckel.** Vorlage
    `Rueckblick.tsx:200-213`: offene Akzentkarte, `hinweise_de` stehen da. App
    `SystemSeiten.swift:536-538`: `Methode(...)`, und `Methode` ist zugeklappt
    (`Bericht.swift:526` `@State private var offen = false`, :541 `DisclosureGroup`). Dieselbe
    Seite begründet zwanzig Zeilen weiter oben genau dagegen (`SystemSeiten.swift:384-388`:
    „`notesDe` stand in einer zugeklappten ``Methode``-Karte. Was eine Zahl einschränkt, darf
    nicht hinter einem Deckel liegen") - für `notesDe` wurde es geändert, für `hinweiseDe` des
    Rückblicks nicht.

  [spuerbar] **Ein Fehler des Rückblicks verschwindet spurlos.** Vorlage: eigener Zustand
    `fehler` (`Rueckblick.tsx:132`, gesetzt :145 mit „Rückblick nicht verfügbar."), angezeigt
    in der Lesehilfekarte (`:205`). App `SystemSeiten.swift:591-598`: `if let frisch = try?
    await haus.api.prognoseVerlauf(tage: tage)` - der Fehler wird weggeworfen, es gibt keine
    Zustandsvariable dafür (die einzige der Seite, `fehler` :204, gehört der Bewertung, :575-583).
    Antwortet `/forecast/history` nie, steht „Wird geholt …" (`:541`) für immer da, und zwar
    unter einer Tagewahl, die scheinbar funktioniert.

  [spuerbar] **Die fünf Kennzahlen stehen an der Wand zweispaltig in einer Karte, nicht
    fünfspaltig in fünf.** Vorlage `ForecastPage.tsx:259` `KpiGrid cols={5}` +
    `globals.css:107`: fünf eigene Karten (`--surface-2`, Rand, Radius 3, Polster 14/18) in
    **einer** Reihe. App `SystemSeiten.swift:226-228`: `Kachelfeld(... spalten: 2)`, und
    `Kachelfeld` ist eine einzige `Karte` mit Haarlinienraster (`Karte.swift:289-331`) - an der
    Wand drei Zeilen 2/2/1. Dazu ein Kicker „Heute" über dem Feld, den die Vorlage dort nicht
    hat. `spalten: 2` ist die Vorgabe von `Kachelfeld` (`Karte.swift:279`) und wird von allen
    fünfzehn Aufrufstellen so übernommen - die Begründung in `Karte.swift:268-273` zitiert
    `handy.css`, also die **Handy**-Fassung, und überträgt sie auf das Breitbild.

  [spuerbar] **Karten sind an der Wand `--surface-1` statt `--surface-2`.** Die Vorlage setzt
    `.card { background: var(--surface-2) }` (#123544) in jeder Breite; `handy.css:182` ändert
    an `.card` nur Rand, Radius und Polster, nicht den Grund. App `Karte.swift:91-94`:
    `schmal ? Farbe.flaeche2 : Farbe.flaeche1` - am Breitbild also #0F2E3D
    (`Marken.swift:28-29`). Jede Karte dieser Seite ist dort dunkler als in der Vorlage, und
    die Farbprüfungen der Palette sind ausdrücklich **gegen #123544** gerechnet
    (`charts/palette.ts:9-18`, `Rueckblick.tsx:32-34`) - die Abstände, die dort als ΔE
    nachgewiesen sind, gelten auf #0F2E3D nicht mehr.

  [spuerbar] **Am Telefon fehlt die Stufe, die `handy.css` jeder kleinen Schrift gibt.**
    `handy.css:189-192` hebt 10→11, 11→12, 12→13,5, 13→14,5 px. Das trifft auf dieser Seite
    die Legenden (12 px → 13,5), `notes_de` und `hinweise_de` (12 → 13,5), den Zusatz im
    Kartenkopf (`handy.css:185`: 13 px), die Quellentabelle (13 → 14,5) und die Achsen
    (`handy.ts:34`: mindestens 11). App: feste Größen ohne Breitenzweig -
    `Schrift.klein` 13, `Schrift.winzig` 11,5 (`Typografie.swift:45-46`), `Schrift.achse` 10,5
    (`:120`); gesucht nach einem Breitenzweig in `Typografie.swift`: kein Treffer. Auf 390
    Punkten steht damit fast jede Zeile dieser Seite rund zwei Punkte zu klein.

  [klein] **Keine Akzentleiste.** Zwei Karten der Vorlage tragen `accent`
    (`ForecastPage.tsx:326`, `Rueckblick.tsx:200`) = 3 px `--accent-bar` (`globals.css:78-85`,
    `tokens.css:98`). Gesucht nach `accent`, `Akzent`, `accentBar` in `apps/ios/DuckCurveHome`
    und `apps/ios/DuckCurveKit/Sources`: kein Treffer. `Karte` hat keinen solchen Parameter
    (`Karte.swift:15-20`).

  [klein] **Spaltengewichte.** Vorlage 5fr/3fr/4fr (`ForecastPage.tsx:295`) und 7fr/5fr
    (`:325`). App: `HStack(alignment: .top, spacing: 14)` mit `Karte`, und `Karte` nimmt
    `maxWidth: .infinity` (`Karte.swift:34`) - alle gleich breit
    (`SystemSeiten.swift:330-334`, `:377-380`). Die Tagesenergie verliert dadurch rund ein
    Fünftel ihrer Breite (5/12 → 1/3) und trägt vierzehn Säulenpaare.

  [klein] **Der Kicker ist in der App eine andere Schrift.** `globals.css:57-64`: Mono 13 px,
    0.13em. App `Typografie.swift:61`: `sansHalbfett` 10,5 mit `tracking(1.4)`
    (`Typografie.swift:151-160`). Die Sperrung stimmt im Verhältnis (1,4/10,5 ≈ 0,133em), die
    Familie und die Größe nicht. Die Farbe stimmt (`Farben.swift:70` → `Marken.swift:85`
    `textKicker = mist`).

  [klein] **Kartenmaß am Breitbild.** Vorlage Radius `--radius-2` = 3 px, Polster 20
    (`globals.css:74-75`). App Radius `Marken.radius3` = 6 (`Karte.swift:88`,
    `Marken.swift:375`), Polster 14 (`Karte.swift:33`). Am Telefon stimmt beides
    (16 / 16, `handy.css:182`).

  [klein] **Die Kachelzahl an der Wand hat die Handy-Größe.** Vorlage: Mono 28 px,
    `tracking-[-.02em]`, Einheit 13 px (`ForecastPage.tsx:187-189`); die 25 px/13,5 px der App
    (`Karte.swift:240`, `:247`) sind die Werte aus `handy.css:202-203`.

  [klein] **Der Umschalter Heute/Gestern sieht anders aus.** Vorlage: Mono 12 px, Versalien,
    `tracking-[.08em]`, Polster 16/8, Kasten mit Rand `line-2` und ohne Füllung
    (`ForecastPage.tsx:283-288`). App `Ansichtswahl`: Sans 13, Gemischtschrift, keine
    Sperrung, Grund `flaeche2`, Radius 6, Polster 11/5 (`Ansichtswahl.swift:34-36`, `:53-59`) -
    das sind die Maße von `.ansicht`/`.ansichten` (`globals.css`), nicht die dieser Stelle.
    Dieselbe Karte hat in der Vorlage also einen eigenen Knopf, so wie der Rückblick einen
    eigenen hat (für den `Tagewahl.Form.prognoseRueckblick` eigens angelegt wurde,
    `Tagewahl.swift:124-128`).

  [klein] **Zwei Zeilen erscheinen zu früh.** „Stand HH:MM · Quelle" (`ForecastPage.tsx:246`)
    und die Gütezeile „MAE … · Bias … · ± %" (`:279`) tragen `min-[1400px]:inline`, sind also
    unter 1400 px nicht da - ein iPad an der Wand liegt darunter. App: beide erscheinen auf
    jedem nicht-kompakten Schirm (`SystemSeiten.swift:255-262`; Gütezeile als Kartentitel,
    `:292` mit `:310-317`).

  [klein] **Zwei Einheiten fehlen im Kopf.** Vorlage: Rückblickkarte „<label_de> · <einheit>"
    (`Rueckblick.tsx:187`) und die Hochachse der Horizontkarte trägt `name: "kW"`
    (`ForecastPage.tsx:134`). App: `Karte(kicker: r.labelDe, …)` ohne Einheit
    (`SystemSeiten.swift:529`) - bei `gesamt.n == 0` steht die Einheit dann nirgends
    (`kopfrechts` :546-553 nennt sie nur mit Paaren); und `Horizontbild` beschriftet die
    Hochachse mit nackten Zahlen (`Prognosezeichnung.swift:518-528`).

  [klein] **Der Ladezustand ist ein anderer.** Vorlage: Gerüst steht, Zahlen sind „-",
    Listen und Tabelle leer (`ForecastPage.tsx:260-264`, `:328-335`, `:354`). App: solange
    `bewertung == nil` steht **nur** eine Karte „Wird geholt …" da, Kacheln, Diagramme und
    Karten fehlen ganz (`SystemSeiten.swift:232-234`).

  [klein] **Die Abweichungskachel hat den falschen Warnton.** Vorlage `tone="ember"` →
    `var(--alert)` #e0533d (`ForecastPage.tsx:183`, `:262`). App: `.glut`
    (`Prognosebild.swift:183`) → `Farbe.ton` bildet `.glut` auf `waermepumpe` ab
    (`Farben.swift:120-128`) = #e0966b (`Marken.swift:53`). Der Kommentar an der Fundstelle
    sagt es selbst: „Den gibt es in ``Kennzahl/Ton`` noch nicht." Eine Abweichung über 15 %
    sieht damit aus wie eine Wärmepumpenzahl.

  [klein] **Tagesdatum einstellig.** Vorlage `dayLabel` mit `day: "2-digit", month: "2-digit"`
    → „Mo., 07.11." (`ForecastPage.tsx:31`; benutzt in der Tagesenergie-Auskunft `:103` und im
    „Tagesabschluss" `:327`). App `Tag.kurz` → „Mo, 7.11." (`Tag.swift:94-98`), benutzt in
    `Prognosebild.swift:411` und `SystemSeiten.swift:439-441`.

  [klein] **Die Querachse des Hauptdiagramms ist am Telefon gröber als in der Vorlage.**
    Die Vorlage setzt `interval: 3` ausdrücklich (`ForecastPage.tsx:74`), und `fuerHandy`
    lässt ein gesetztes `interval` stehen (`charts/handy.ts:37`) - am Telefon bleiben es alle
    drei Stunden mit `hideOverlap`. App: alle sechs (`Prognosezeichnung.swift:266`).

  [klein] **Die Rückblicklegende steht je Karte statt einmal im Abschnitt.** Vorlage: einmal in
    der Abschnittszeile, mit Quadrat und **Punkt** (`Rueckblick.tsx:163-166`, `:118-128`).
    App: in jeder Reihenkarte, mit Quadrat und gestricheltem Strich
    (`Prognosezeichnung.swift:722-725`).

  Zusammen: 19 Punkte - 0 traegt-die-seite, 6 spuerbar, 13 klein. Aufwand **mittel**.

---

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Prognosebild` (`DuckCurveKit/Sources/DuckCurveKit/Zustand/Prognosebild.swift`), geprüft in
    `DuckCurveKit/Tests/DuckCurveKitTests/PrognosebildTests.swift`:
    - Konstanten `abweichungsgrenze = 15` (:38), `kurzesFenster = 7` (:41),
      `tagesenergieTage = 14` (:44), `leistungsluft = 1.1` (:48), `faktorluft = 1.15` (:51),
      `faktorspanneMindestens = 10` (:55) - alle mit Fundstelle in der Vorlage im Kommentar.
    - `Prognosetag` (:70-96) und `tageskurve(_:heute:gerechnetAm:)` (:107-138): drei Reihen als
      `[Kurvenpunkt]`, Lücke statt Null, Jetzt-Stunde aus `generatedAt`, auf 0…24 begrenzt.
    - `leistungsgrenze(_:)` (:144-147) - `ceil(max*1,1/2)*2`, identisch zu
      `ForecastPage.tsx:49`.
    - `kacheln(_:)` (:159-192) - die fünf Kennzahlen in der Reihenfolge der Vorlage.
    - `bias7(_:)` (:201-205) - Mittel über `daily.suffix(7)`.
    - `abweichung(_:)` (:269-272) und `faktorbalken(_:)` (:279-296) - Prozentpunkte und die
      symmetrische Spanne über alle drei Reihen.
    - `Fehlerbalken` (:311-329), `horizonte(_:)` (:335-344), `vorlaufbalken(_:)` (:347-356) -
      `nil` statt Nullsäule bei `n == 0`.
    - `Tagespaar` (:367-393), `tagesenergie(_:hoechstens:)` (:402-417), `wochentagKurz(_:)`
      (:423-426).
    - `Formate.prozentpunkte(_:stellen:vorzeichen:)` (:441-447) - das `pct()` der Vorlage mit
      echtem U+2212.
  * Abfragen: `Api.prognoseBewertung()` (`Netz/Api.swift:355-357`) und
    `Api.prognoseVerlauf(tage:)` (`:361-363`, mit `days`-Parameter).
  * Modelle (`Modelle/Schema.swift`): `CorrectorState` (:2581-2608, `bins` nicht optional),
    `ForecastEvaluationOut`, `ForecastDayOut`, `ForecastPointOut`, `ForecastScore`,
    `DailyScoreOut`, `HorizonScoreOut`, `SourceOut`, `ForecastHistoryOut`, `ReiheOut`,
    `VorlaufOut`, `Wertung`, `BinCorrection`.
  * Formate: `Formate.zahl`, `Formate.kwh`, `Formate.kwMitEinheit`, `Formate.hhmm`,
    `Tag.kurz` (`Formate/Tag.swift:94-98`), `Tag.zeitraum` (:79-84, Hauskalender),
    `Namen.wochentag` (`Formate/Zeit.swift:145-148`).
  * Gestalt: `Marken.amber/amberWeich/mist/alarm/pv/flaeche1/flaeche2/linie1/linie2/
    rasterlinie/text1-3/textKicker` (`Gestalt/Marken.swift:18-34, 82-89, 138`),
    `Marken.radius2 = 3`, `radius3 = 6` (:374-375).
  * Achsenhilfe `Achse.beschriftungen(_:hoechstens:)` (`Zustand/Achse.swift:16-21`).
  * Bausteine der Oberfläche: `Karte`/`Kachelfeld`/`Kachel`/`Leer`/`Stoerung`
    (`Gestalt/Karte.swift`), `Kicker`/`Zahl` (`Gestalt/Typografie.swift:128-160`),
    `Ansichtswahl` (`Gestalt/Ansichtswahl.swift`), `Umbruchzeile`
    (`Gestalt/Umbruchzeile.swift:16`), `Tabelle` (`Seiten/Bericht.swift:165`),
    `Methode` (`:514`), `Tagewahl` mit Form `.prognoseRueckblick`
    (`Bausteine/Tagewahl.swift:124-193`).

---

ES FEHLT:

  1. **Ein Ton `alarm` in `Kennzahl.Ton`.** `Zustand/Kennzahl.swift:38-51` kennt normal, sonne,
     glut, bernstein, gedaempft, nebel - keinen Fall für `--alert`. Nötig, weil die Vorlage
     genau diesen Ton an der Abweichungskachel setzt (`ForecastPage.tsx:183`, `:262`).
     Vorschlag: `case alarm` in `Kennzahl.Ton`, Zuordnung `case .alarm: return alarm` in
     `Farbe.ton` (`DuckCurveHome/Gestalt/Farben.swift:120-128`), dann
     `Prognosebild.swift:183` von `.glut` auf `.alarm` umstellen.
  2. **Die Akzentleiste als Marke.** `--accent-bar` (`tokens.css:98`:
     `linear-gradient(90deg, var(--amber), var(--amber-soft), transparent 86%)`) hat in
     `Gestalt/Marken.swift` kein Gegenstück; gesucht nach `accent`/`Akzent` im ganzen
     iOS-Baum: kein Treffer. Vorschlag: `Marken.akzentband: [(Farbwert, Double)]` neben
     `grundVerlauf` (`Marken.swift:48`), dazu `Farbe.akzentband` als `LinearGradient` wie
     `Farbe.grundVerlauf` (`Farben.swift:140-146`).
  3. **Nichts weiter.** Alle Zahlen dieser Seite werden schon im Kern gerechnet; die übrigen
     Lücken sind Anordnung, Maß und Zustand in der Oberfläche. Insbesondere gesucht und
     gefunden: `bias7`, `faktorbalken`, `leistungsgrenze`, `horizonte`, `vorlaufbalken`,
     `tagesenergie` - es muss keine Rechnung neu entstehen.

---

BAUPLAN: Karte für Karte, in der Reihenfolge der Vorlage.

  1. `DuckCurveKit/.../Zustand/Kennzahl.swift` - `case alarm` ergänzen.
     `DuckCurveHome/Gestalt/Farben.swift` - `Farbe.ton` um `.alarm` erweitern.
     `DuckCurveKit/.../Zustand/Prognosebild.swift:183` - `.glut` → `.alarm`, den Kommentar
     dazu (:180-182) ersetzen.
  2. `DuckCurveKit/.../Gestalt/Marken.swift` + `DuckCurveHome/Gestalt/Farben.swift` -
     `akzentband` anlegen. `DuckCurveHome/Gestalt/Karte.swift` - `var akzent: Bool = false`
     an `Karte`, bei `true` ein 3 Punkte hohes Band am oberen Rand als `overlay(alignment:
     .top)` innerhalb der `clipShape`. Setzen an `SystemSeiten.swift:390` (Änderungskarte) und
     `:536` (Lesehilfe des Rückblicks).
  3. `DuckCurveHome/Gestalt/Karte.swift:91-94` - Kartenfläche in beiden Breiten `flaeche2`;
     `:33` Polster an der Wand 20 statt 14; `:88` Radius an der Wand `Marken.radius2`.
     Das berührt alle Seiten - vor dem Umstellen prüfen, dass der Seitengrund
     (`Farben.swift:147` `seitengrund` = `grundVerlauf`) sich von #123544 noch abhebt; die
     Vorlage löst das mit `.dashboard-bg` (`globals.css:86-92`), das unter den Karten dunkler
     bleibt.
  4. `DuckCurveHome/Gestalt/Typografie.swift` - für die kleinen Stufen eine Breitenfassung
     (etwa `Schrift.klein(schmal:)`/`winzig(schmal:)`/`achse(schmal:)` nach
     `handy.css:189-192`: 13→14,5, 11,5→13,5, 10,5→11). Danach in
     `Prognosezeichnung.swift` an den Legenden (:114, :129, :156), den Ablesezeilen (:69-73)
     und den Achsen (:271, :287, :411, :421, :513, :523, :622, :632, :762, :772) einsetzen,
     und in `SystemSeiten.swift` an `notesDe` (:413-419) und `quellensatz` (:494-497).
  5. `DuckCurveHome/Gestalt/Typografie.swift:61` - `kicker` auf Mono 13 umstellen, `Kicker`
     (:151-160) `tracking` auf 1,69 nachziehen. Berührt jede Seite; eigener Schritt.
  6. `DuckCurveHome/Gestalt/Karte.swift` - `Kachelfeld` ein `spaltenBreit: Int` geben (Vorgabe
     = `spalten`), damit an der Wand fünf Kacheln in eine Reihe passen; die führende Kachel
     bleibt eine Handy-Sache (`:290`). In `SystemSeiten.swift:226-228` `spaltenBreit: 5`
     setzen und den Kicker „Heute" entfernen - die Vorlage hat dort keine Überschrift.
     Zahlengröße an der Wand auf 28 mit `tracking(-0.56)` (`Karte.swift:240`, `:247` Einheit 13).
  7. `DuckCurveHome/Gestalt/Ansichtswahl.swift` - eine zweite Form für diese Stelle
     (Mono 12, Versalien, `tracking` 0,96, Polster 16/8, Rand `linie2`, kein Grund), so wie
     `Tagewahl.Form` es für die vier Knopfformen macht; in `SystemSeiten.swift:298-306` setzen.
  8. `DuckCurveHome/Seiten/Technik/SystemSeiten.swift` - `dreierreihe` (:324-336) und
     `zweierreihe` (:371-380) mit Gewichten: `.frame(maxWidth: .infinity)` durch
     `GeometryReader`-freie `layoutPriority`-Verteilung ersetzen oder, einfacher, die Karten in
     ein `HStack` mit `.frame(maxWidth: .infinity)` je Karte und zusätzlichen
     `Spacer`-Anteilen; sauber ist eine kleine `Gewichtsreihe`-Layout-Ansicht neben
     `Umbruchzeile` (`Gestalt/Umbruchzeile.swift`), die `[CGFloat]`-Anteile nimmt. Dann
     5/3/4 und 7/5 setzen.
  9. `SystemSeiten.swift:518` - Rückblicküberschrift: an die Kartenköpfe angleichen ist
     schon richtig; nichts zu tun.
  10. `SystemSeiten.swift:524-532` - die Reihen in dieselbe Gewichtsreihe aus Schritt 8
      setzen, Anteile `repeat(1, n)`; am Telefon untereinander.
      Im Kartenkopf die Einheit ergänzen: `kicker: "\(r.labelDe) · \(r.einheit)"` (:529).
  11. `SystemSeiten.swift:536-538` - `Methode` durch eine offene `Karte(akzent: true,
      kicker: "Wie der Rückblick zu lesen ist", titel: "\(v.tage) Tage · \(laeufe(v)) Läufe im
      Bestand")` ersetzen, darin erst der Rückblickfehler, dann alle `hinweiseDe` offen.
  12. `SystemSeiten.swift:204-210` - `@State private var fehlerVerlauf: ApiFehler?` ergänzen;
      `haltVerlaufFrisch` (:591-598) auf `do/catch` umstellen, bei Erfolg `fehlerVerlauf = nil`,
      bei Fehler setzen und `verlauf` **stehen lassen** (der vorhandene Kommentar :588-590
      beschreibt genau das Verhalten, nur ohne Meldung). Den Fehler in der Karte aus Schritt 11
      anzeigen - nicht als zweites Störungsband oben.
  13. `Prognosezeichnung.swift:518-528` - Hochachse der Horizontkarte mit „ kW" beschriften,
      wie es `Prognosekurvenbild` schon macht (:287).
  14. `Prognosezeichnung.swift:266` - am Telefon auf alle drei Stunden zurückgehen, dafür die
      Beschriftung auf 11 Punkte (Schritt 4) und, wenn es dann zu eng wird, jede zweite Marke
      ohne Text - nicht die Marken halbieren.
  15. `SystemSeiten.swift:232-234` - statt der einen Karte „Wird geholt …" das Gerüst mit
      Strichen zeichnen: `Kachelfeld` mit `Prognosebild.kacheln` eines leeren
      `ForecastEvaluationOut` wäre erfunden; richtig ist, `kacheln(_:)` einen Zweig für
      „noch keine Antwort" zu geben oder die Kacheln mit `Formate.leer` zu füllen. Kleinster
      Schritt, der die Vorlage trifft: Kachelfeld und die fünf Kartenrahmen stehen lassen und
      nur die Diagramme durch `Leer` ersetzen.
  16. `Prognosezeichnung.swift:722-725` - Legende aus den Reihenkarten in die Abschnittszeile
      (`SystemSeiten.swift:512-523`) heben, mit Quadrat und Punkt statt Quadrat und Strich.
  17. `Formate/Tag.swift:94-98` nicht anfassen - stattdessen für diese Seite eine zweistellige
      Form nehmen (`Tag.tagMonat` ist schon zweistellig, :106; nötig ist „Mo., 07.11.").
      Eigener kleiner Zusatz in `Tag`, benannt nach seiner Stelle, mit `ForecastPage.tsx:31`
      als Beleg.
  18. `SystemSeiten.swift:253-265` und `:292` - „Stand …" und die Gütezeile an eine
      Breitenschwelle hängen. SwiftUI hat keine 1400-px-Abfrage über `horizontalSizeClass`;
      der Weg des Projekts dafür ist eine Messung der Breite - siehe WAS SCHWIERIG WIRD.

---

WAS SCHWIERIG WIRD:

  * **Spaltengewichte (5fr/3fr/4fr, 7fr/5fr).** SwiftUI `HStack` kennt kein `fr`. Im Projekt
    gibt es für genau solche Fälle eine eigene `Layout`-Ansicht: `Umbruchzeile`
    (`DuckCurveHome/Gestalt/Umbruchzeile.swift:16`, `struct Umbruchzeile: Layout`) - dasselbe
    Vorbild trägt eine `Gewichtsreihe`, die `sizeThatFits`/`placeSubviews` über Anteile
    rechnet. Billiger, aber ungenauer: `.frame(maxWidth: .infinity)` je Karte plus
    `layoutPriority` - das verteilt nicht im Verhältnis und sollte hier nicht genügen.
  * **Die 1400-px-Schwelle der Vorlage.** `horizontalSizeClass` kennt nur kompakt/regulär, und
    jedes iPad ist regulär. Das Projekt hat dafür schon einen Weg: `Lib`-freie Messung über
    `GeometryReader` wird in `Diagramme/` nicht benutzt; stattdessen entscheidet die Seite nach
    `schmal` (`SystemSeiten.swift:218`). Für diese zwei Zeilen genügt eine
    `containerRelativeFrame`-freie Prüfung in `Seite` wäre zu viel - kleinster Weg: in
    `kopfzeile` (`SystemSeiten.swift:253`) ein `ViewThatFits(in: .horizontal)` mit der langen
    Fassung unter `minWidth` und einer leeren daneben. Vorbild steht in derselben Datei:
    `SystemSeiten.swift:783-800` (`spalten(_:)` der Annahmenseite, zwei Spalten mit
    `.frame(minWidth: 640)` gegen eine). Die Warnung dazu steht in `AnlageSeite.swift:92` und
    `Umbruchzeile.swift:13`: `ViewThatFits` wählt nach der ganzen Größe, und ein umbrechender
    Satz „passt" immer - für eine einzeilige `Text` mit `lineLimit(1)` und `fixedSize` trifft
    es, für mehr nicht.
  * **Akzentleiste und `clipShape`.** `Karte` legt Grund, Rand und Schnitt in dieser Reihenfolge
    (`Karte.swift:35-37`: `.background` → `.overlay(rand)` → `.clipShape`). Ein
    `overlay(alignment: .top)` muss deshalb **vor** die letzte Zeile, sonst steht das Band in den
    Ecken über den Radius hinaus; die Vorlage schneidet dort (`globals.css:76`
    `overflow: hidden`). Den Griff selbst gibt es im Projekt schon
    (`Bausteine/Ambiente.swift:433`, `Diagramme/Anlagenbild.swift:757` jeweils
    `.overlay(alignment: .top)`); was fehlt, ist die Leiste als Sache - gesucht nach `accent`
    und `Akzent` in `apps/ios/DuckCurveHome` und `apps/ios/DuckCurveKit/Sources`: kein Treffer.
  * **Hinweisfenster.** Swift Charts hat keines; der Weg des Projekts ist die Ablesezeile über
    dem Bild mit `chartXSelection` - begründet in `Prognosezeichnung.swift:18-22` und :57-60,
    Vorbilder `Ablesung` (:61-87) und `Fahrplanzeichnung`. Alle fünf Bilder dieser Seite haben
    sie schon; die Legende und die Ablesung sind damit zwei Zeilen über/unter jedem Bild, die
    die Vorlage nicht hat - das ist der Preis und er ist bezahlt.
  * **Ein Verlauf in einer Flächenreihe.** Die Vorlage füllt die Ist-Reihe mit einem
    `LinearGradient` 0,30 → 0,03 (`ForecastPage.tsx:82`). Swift Charts nimmt am `AreaMark`
    einen `ShapeStyle`, also geht es direkt - schon gemacht in
    `Prognosezeichnung.swift:211-214`. Nichts offen.
  * **`barWidth: "52%"`** gibt es als `MarkDimension.ratio(0.52)` - schon benutzt
    (`Prognosezeichnung.swift:744-747`). `barGap`/`barCategoryGap` der anderen Säulenbilder hat
    Swift Charts nicht; dort entscheidet `position(by:)` über den Platz
    (`Prognosezeichnung.swift:820-824` begründet die flache Säulenreihe).
  * **Die Schriftstufen des Telefons.** `handy.css:189-192` ist eine Regel über
    *Tailwind-Klassennamen*, nicht über Rollen - sie trifft jede 12-px-Stelle der Seite. Eine
    Übertragung nach Swift muss die Rollen treffen (Legende, Notiz, Achse, Tabellenzelle) und
    nicht die Zahl; sonst wandert sie bei der nächsten Änderung auseinander. Das ist der
    Grund, die Stufen in `Typografie` zu bündeln und nicht an den Fundstellen zu rechnen.
