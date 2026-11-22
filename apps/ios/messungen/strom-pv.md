========================= messen:strom-pv   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:147-193` - `PvSeite` steht in derselben
Datei wie `StromSeite`; Gerippe `apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-64`, Huelle
`apps/ios/DuckCurveHome/App/Seitenwahl.swift:131-170`, Weg `/strom/pv` ->
`App/Seitenwahl.swift:41-42`)

1. Zeitraumleiste - am iPad im Gerippe oberhalb der Rollflaeche
   (`App/Seitenwahl.swift:146-151` -> `:188-207`): links Spannenwahl Tag/Woche/Monat/Jahr
   (`:210-226`; alle vier, weil der Reiter keine Einschraenkung setzt,
   `DuckCurveKit/Bereiche/Bereiche.swift:109`), rechts Datumskasten `‹ z.kurz › [HEUTE]`
   (`:229-291`). Am Telefon zeichnet das `HandRahmen`, nicht die Seite.
2. Kachelfeld mit sechs Kacheln **und dem Kicker „Photovoltaik"** (`StromSeite.swift:153`,
   Daten `:174-192`), gezeichnet von `Gestalt/Karte.swift:274-343`: am Telefon fuehrt die erste
   Kachel ueber die ganze Breite (48 pt, `Karte.swift:240`), die uebrigen zweispaltig mit
   Haarlinien; am iPad alle in zwei Spalten (`Karte.swift:279` `spalten: Int = 2`).
   Die sechs woertlich: „erzeugt" (`Formate.zahl(pvKwh, 1)` kWh, `Farbe.pv`) · „direkt
   verbraucht" (kWh) · „in den Speicher" (kWh) · „eingespeist" (kWh, `Farbe.netzEinspeisung`) ·
   „Eigenverbrauch" (`Formate.prozent(selfConsumptionShare)`) · „ersparte Kosten"
   (`Formate.euro(pvDirectSavingsEur)`, dazu „gegen den Bezugspreis der jeweiligen Stunde").
   Nur die letzte Kachel hat eine Kontextzeile.
3. Karte „Was aus der Erzeugung wurde" mit gestapeltem Balkenbild, drei Reihen
   (`StromSeite.swift:154-169`): „direkt ins Haus" `Farbe.pv` (`pvDirectKwh`) · „in den
   Speicher" `Farbe.batterie` (`pvToBatteryKwh`) · „eingespeist" `Farbe.netzEinspeisung`
   (`exportKwh`). Baustein `Seiten/Bericht.swift:70-149`, Hoehe 180 pt (`Bericht.swift:81`),
   Legende **im Bild** oben links (`Bericht.swift:120`).
4. Methode, zugeklappt, Titel „Wie das gerechnet ist" (`StromSeite.swift:170`, Baustein
   `Bericht.swift:334-397`, Titel `:344`). **Ohne `kurz:`** - der Rumpf enthaelt allein
   `meta.estimatedNoteDe`.
5. Fehler als `Stoerung` oberhalb des Inhalts, ohne ihn zu ersetzen (`Bericht.swift:36-38`,
   Baustein `Gestalt/Karte.swift:410-436`); „Wird geholt …" / „Für diesen Zeitraum ist nichts
   da." (`Bericht.swift:43-47`, `Leer` in `Karte.swift:390-404`).

Nicht auf der Seite, nachgesehen statt vermutet:
`grep -n "exportRevenueEur\|feedInCtKwh\|batteryNetEur\|coverage\|dataSince\|plan()\|verlauf\|
Prognose\|Überblick\|minutes" apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift` trifft
innerhalb von `PvSeite` (`:148-193`) **keines** dieser Felder; `grep -rn "pv-abrechnung"
apps/ios/DuckCurveHome` - kein Treffer (die Adresse kennt nur `Seitenwahl.swift:53` als Ziel und
`Bereiche.swift:120` als Reiter).

VORLAGE: `apps/web/src/app/strom/pv/page.tsx:1-7` ->
`apps/web/src/components/reports/PvReport.tsx:38-124`

  * **Huelle / Kopfzeile** (`reports/ReportShell.tsx:97-134`, darunter
    `layout/AreaShell.tsx:13-30`, `layout/AreaNav.tsx:62-99`)
    `title="Photovoltaik"` steht **nicht** sichtbar im Kopf, nur als
    `<span className="sr-only">` (`ReportShell.tsx:127`) und als `metadata.title`
    „Photovoltaik · Duck Curve Home" (`app/strom/pv/page.tsx:3`). Begruendung im Code: „Der
    Titel steht nicht mehr im Kopf: der aktive Reiter sagt, wo man ist. Er bleibt im
    Dokumenttitel, damit ein Browserfenster und die Vorlesehilfe ihn haben"
    (`ReportShell.tsx:99-100`).
    `kicker="Erzeugung · Verwendung · Prognose"` (`PvReport.tsx:77`) geht an `AreaTabs` und
    steht rechts in der Reiterzeile: `className="kicker hidden truncate pb-2.5 md:block"`,
    `fontSize: 11` (`AreaNav.tsx:96`) - mono, `uppercase`, `letter-spacing .13em`, Farbe
    `--text-kicker` = `--mist` #7fa3b3 (`globals.css:57-64`, `tokens.css:15,35`). **Am Handy
    ausgeblendet** (`hidden ... md:block`, Grenze 768 px).
    **`right`: ein Verweis, den nur der Hausherr sieht** - `<Link href="/geld/pv-abrechnung"
    className="text-[12px] text-amber">Abrechnung →</Link>`, bei `role === "guest"` gar nicht
    erst gezeichnet (`PvReport.tsx:84`). Der Kommentar daneben ist die Begruendung: „Gästen wird
    der Weg gar nicht erst gezeigt: die Abrechnung ist ihnen verschlossen."
    (`PvReport.tsx:83`). Rolle aus `useRole()` (`lib/live/useRole.ts:10-31`; bis zur Antwort
    gilt „owner").
    Blaetterkasten `‹` / Anker / `›` und „heute" nur, wenn nicht heute
    (`ReportShell.tsx:109-117`), Anker lang (`anchorLabel` `:36-49`) und kurz (`anchorKurz`
    `:52-58`), am Handy die kurze (`handy.css:159-160`). Spannenschalter Tag/Woche/Monat/Jahr,
    aktiv `--amber` auf `--petrol` (`ReportShell.tsx:120-126`).
    DATEN: `usePeriod()` haelt Spanne und Anker in `?period=&anchor=` (`ReportShell.tsx:61-95`).

  * **Fehlerband** (`PvReport.tsx:86` -> `ReportShell.tsx:147-153`)
    Rahmen `rgba(224,83,61,.4)`, Flaeche `rgba(224,83,61,.12)`, Schrift `--alert`, mono, 12 px,
    `uppercase`, `.1em`. Text aus `useReport` (`useReport.ts:10-13`): bei 401/403 „Nicht
    angemeldet - bitte Gerät koppeln.", sonst die Meldung des Dienstes bzw. „Daten konnten nicht
    geladen werden."

  * **Sechs Kennzahlkacheln** (`PvReport.tsx:87-98`, `KpiGrid cols={6}`
    `ReportShell.tsx:176-182`, Kachel `ui/Stat.tsx:4-19`)
    Breit: `repeat(auto-fit, minmax(clamp(150px, 100%/6 - 16px, 260px), 1fr))`, `gap: 16px`
    (`globals.css:107`) - auf Wandbreite **eine Reihe zu sechs**. Karte `padding: "14px 18px"`,
    `gap: 6` (`Stat.tsx:7`), Flaeche `--surface-2` #123544, Haarlinie `--line-1`, Radius
    `--radius-2` = 3 px (`globals.css:67-76`, `tokens.css:24,27,93`). Wort `.kicker`
    `fontSize: 11` (`Stat.tsx:8`); Zahl mono 26 px, `leading-none`, `tracking-[-.02em]`
    (`:9`); Einheit 13 px `--font-sans` `--text-3` (`:11`); Kontextzeile 12 px,
    `line-height 1.35`, `--text-3`, **hoechstens zwei Zeilen** (`line-clamp-2`, `:16`) -
    begruendet: „Abgeschnitten … ist sie nutzlos … Zwei Zeilen sind das Maximum, damit die
    Kacheln in einer Reihe gleich hoch bleiben" (`Stat.tsx:13-15`).
    Die sechs woertlich, in dieser Reihenfolge:
      1. „Erzeugung" · `de1(totals.pv_kwh)` · „kWh" · `tone="amber"` = `--amber` #f2a900 ·
         dazu `${Math.round(minutes/60)} h bewertet`, bei falsy `minutes` „keine Daten" (`:88`)
      2. „Eigenverbrauch" · `pct(self_consumption_share)` · ohne Einheit, ohne Ton · dazu
         `${de1(pv_direct_kwh + pv_to_battery_kwh)} kWh selbst genutzt` (`:89`)
      3. „Eingespeist" · `de1(export_kwh)` · „kWh" · `tone="mist"` = `--mist` #7fa3b3 · dazu
         `Erlös ${eur(export_revenue_eur)} bei ${de1(meta.feed_in_ct_kwh, 1)} ct` (`:90`)
      4. „Ersparnis direkt" · `eur(pv_direct_savings_eur)` · `tone="amber"` · dazu
         **„gegenüber Netzbezug"** (`:91`)
      5. „Prognose heute" · `de1(fc.today)` · „kWh" · ohne Ton · dazu, wenn der Anker heute
         ist: `${de1(pv_kwh)} kWh bisher erzeugt` bzw. „Tagesprognose" ohne Daten; blaettert
         man zurueck: **„für heute, nicht für den gewählten Tag"** (`:96`)
      6. „Prognose morgen" · `de1(fc.tomorrow)`, bei 0 ein „-" · „kWh" · dazu „aus
         Wetterprognose" bzw. „noch nicht verfügbar" (`:97`)
    **Die Begruendung, die nicht verloren gehen darf** (`PvReport.tsx:92-95`): „Die beiden
    Prognosewerte und die Kurve darunter kommen aus dem laufenden Plan. Der kennt nur heute und
    morgen; für einen vergangenen Tag gibt es keine Vorhersage mehr. Blättert man zurück, folgt
    der Rest der Seite dem gewählten Tag, diese drei Felder aber nicht - und genau das muss
    dastehen, sonst liest man sie als Prognose des gewählten Tages."
    Formate: `de1` = `toLocaleString("de-DE")` mit einer Stelle, `null` -> „-"; `eur` = zwei
    Stellen + „ €"; `pct` = `Math.round(frac*100)` + „ %" (`ReportShell.tsx:14-16`).
    DATEN: `api.energySummary(period, anchor)` ueber `useReport` (`PvReport.tsx:41`,
    `useReport.ts:18-46`; alle 5 min neu, der alte Stand bleibt beim Wechsel stehen). Felder:
    `totals.pv_kwh`, `minutes`, `self_consumption_share`, `pv_direct_kwh`, `pv_to_battery_kwh`,
    `export_kwh`, `export_revenue_eur`, `pv_direct_savings_eur`, `meta.feed_in_ct_kwh`.
    Prognose: `api.plan()` einmal beim Aufbau und dann alle 5 min
    (`PvReport.tsx:46-61`), gerechnet in `forecastKwh` (`:24-36`): Intervallbreite aus den
    ersten zwei Stuetzpunkten (`stepH`, mindestens 1/60 h), `today` = Summe `expected_pv_kw *
    stepH` im Fenster [Tagesbeginn, +24 h), `tomorrow` dasselbe im Fenster danach; `today`
    wird durch `plan.pv_forecast_today_kwh` **ersetzt**, wenn das Feld ungleich 0 ist (`:35`).
    Tagesbeginn ist Mitternacht in Europe/Berlin, nicht die Zeitzone des Browsers
    (`charts/dayBounds.ts:39-45`, Kommentar `:13`).

  * **Zwei Diagrammkarten nebeneinander** (`PvReport.tsx:99-110`)
    `<div className="report-row" style={{"--cols": "1fr 1fr"}}>` -> `display: grid`,
    `gap: 16px`, zwei gleiche Spalten (`globals.css:108`). Jede Karte
    `style={{padding: 16, height: 300}}`, das Diagrammfeld `min-h-0 flex-1`.
    Kommentar darueber, der die Form begruendet: „Verwendung und Vorschau nebeneinander. Neben
    der Verwendung stand ein Ring mit denselben drei Anteilen, die in den Kacheln darüber
    stehen." (`PvReport.tsx:99-100`) - der Ring ist absichtlich weg, nicht vergessen.
    Kartenkopf `CardHead` (`ui/Card.tsx:20-29`): links `h2.kicker`, rechts das Beiwerk; bei
    einem Element (nicht String) **ohne** `truncate`, damit eine Legende umbricht statt zu
    verschwinden (`Card.tsx:24-26`).
    - Karte 1: Titel **„Erzeugung und Verwendung"**, rechts `ChartLegend`
      (`ReportShell.tsx:192-203`: je Reihe ein Farbfleck `h-2 w-2.5 rounded-[1px]` plus Name in
      12 px `--text-3`, rechtsbuendig, umbrechend; Begruendung `:187-190`: „Damit lag die
      Identität der Flächen allein in der Farbe, und wer die Reihenfolge nicht kennt, muss
      raten."). Reihen `SERIES` (`PvReport.tsx:17-21`):
      `pv_direct_kwh` **„Direkt genutzt"** `C.pv` #f2a900 ·
      `pv_to_battery_kwh` **„In Batterie"** `C.battery` #7fa3b3 ·
      `export_kwh` **„Eingespeist"** `C.export` **`rgba(228,236,239,.5)`**
      (`charts/palette.ts:35,36,44`).
      Bild `stackedBars` (`reports/charts.ts:52-89`): `stack: "total"`,
      `barCategoryGap: "35%"`, oberste Reihe `borderRadius [2,2,0,0]`, Werte auf zwei Stellen
      gerundet, `null` -> 0, `animation: false`. Gitter `left 48, right 12, top 24, bottom 30`.
      x-Achse Kategorie aus `bucket.label`, mono 10 px `rgba(255,255,255,.48)`, ab mehr als 12
      Buckets `interval: "auto"`, `hideOverlap`. y-Achse Name „kWh", `splitNumber: 3`,
      Gitterlinie `rgba(255,255,255,.09)`.
      **Zeiger:** `tooltip` `trigger: "axis"`, `axisPointer: {type:"shadow"}` - Bucketname,
      dann je Reihe Name und Wert (nur Reihen ungleich 0), darunter abgesetzt
      „Summe NN,N kWh" (`charts.ts:58-73`).
      DATEN: `buckets[].label` und `buckets[].totals.*` derselben Antwort.
    - Karte 2: Titel **„Heute und morgen"**, und wenn der Anker nicht heute ist
      **„Prognose heute und morgen"** (`PvReport.tsx:107`); rechts
      `<Link href="/system" className="text-amber">Prognosegüte →</Link>` (`:107`).
      Bild `pvForecastChart` (`charts.ts:178-233`), zwei Reihen auf **einer Zeitachse ueber 48
      Stunden** (`min: dayStartMs`, `max: dayStart + 48 h`, `interval: 6 h`, `:198-207`):
        - **„Prognose"**: Linie `#e4ecef`, Breite 1.5, gestrichelt `[5,4]`, Flaeche
          `rgba(228,236,239,.06)`, `z: 2`; dazu eine senkrechte `markLine` bei
          `dayStart + 24 h` in `rgba(255,255,255,.25)`, 1 px, durchgezogen, mit der
          Beschriftung **„morgen"** `insideEndTop`, mono 10 px (`charts.ts:210-219`).
        - **„Ist"**: Linie `C.pv` #f2a900, Breite 2.5, `connectNulls: false` (Luecken bleiben
          Luecken), Flaeche als Farbverlauf `rgba(242,169,0,.3)` -> `rgba(242,169,0,.03)`,
          `z: 3`; senkrechte gestrichelte `markLine` bei `nowMs` in `C.pv`, 1.5 px, **ohne
          Beschriftung** (`charts.ts:220-230`).
        Achsenschrift der Zeitachse: um 0 Uhr „Di., 10.11.", sonst „HH:00"
        (`charts.ts:207`). y-Achse Name „kW", `min: 0`, `splitNumber: 3`. Legende unten
        mittig, blaetternd (`type: "scroll"`), mono 11 px, `itemWidth 14`, `itemHeight 8`
        (`charts.ts:196`), Gitter `left 48, right 16, top 26, bottom 56` (`:197`).
        Zeiger: `trigger: "axis"`, Kopf „Di., 14:30" (`weekday: "short"`, Stunde, Minute),
        darunter je Reihe Name und „N,N kW" (`charts.ts:184-195`).
      DATEN: Ist aus `api.history("today")`, Feld **`pv_power_kw`** je Minutenzeile
      (`PvReport.tsx:68`; nicht-Zahlen werden `null`); Prognose aus `plan.intervals[].ts` und
      `expected_pv_kw` (`PvReport.tsx:26`). Beide werden gemeinsam mit `Promise.allSettled`
      geholt und alle 5 min erneuert; scheitert eine, bleibt die andere (`:49-52`). `nowMs`
      wird bei jedem Lauf neu gesetzt (`:53`).

  * **Spannenstreifen „PV im Überblick"** (`PvReport.tsx:111-120`, Baustein
    `reports/PeriodStrip.tsx:32-94`)
    Vier Groessen (Zeilen) gegen vier Spannen (Spalten) **desselben Ankertags**. Begruendung:
    „Die Spalten folgen der Navigation. Blättert man auf einen vergangenen Tag, zeigen sie
    dessen Woche, Monat und Jahr - nicht mehr die laufenden." (`PeriodStrip.tsx:22-26`) und im
    Kern dazu: „Der Anker kommt von außen und war vorher fest auf heute verdrahtet. … Zwei
    Zeiträume in einer Ansicht, ohne dass es dastand." (`useReport.ts:48-54`)
    Spaltenkoepfe „Heute" · „Woche" · „Monat" · „Jahr"; die erste heisst nur „Heute", wenn der
    Anker heute ist, sonst „TT.MM." (`PeriodStrip.tsx:9-16`). Rechts im Kopf „jeweils bis
    jetzt" bzw. „jeweils bis TT.MM.JJJJ" (`:34-38`).
    Zeilen woertlich (`PvReport.tsx:114-119`):
      „Erzeugt · kWh" - `de1(pv_kwh, pv_kwh >= 100 ? 0 : 1)`, also **ab 100 ohne
      Nachkommastelle**, `tone="amber"`; erste Zeile fett (`fontWeight: 600`,
      `PeriodStrip.tsx:84`)
      „Eigenverbrauch" - `pct(self_consumption_share)`
      „Einspeiseerlös" - `eur(export_revenue_eur)`
      **„Ersparnis" - `eur(pv_direct_savings_eur + battery_net_eur)`** - eine Summe aus zwei
      Feldern, die es so in keiner Antwort gibt
    Fehlt eine Spanne, steht „-" (`PvReport.tsx:72`).
    Breit: Tabelle, `Card style={{padding:"14px 18px", gap:10}}`, 12 px,
    `table-layout: fixed`, erste Spalte 34 %, Zahlen rechtsbuendig mono, Zeilentrenner
    `border-line-1` (`PeriodStrip.tsx:67-92`).
    DATEN: `useMultiPeriod(api.energySummary, anchor)` (`PvReport.tsx:42`,
    `useReport.ts:55-77`) - vier Abfragen auf einmal mit `Promise.allSettled` ueber
    `ALL_PERIODS`, alle 5 min neu; eine gescheiterte Spanne faellt weg, der Streifen bleibt.

  * **Methodenzeile** (`PvReport.tsx:121` -> `ReportShell.tsx:163-174` -> `ui/Methode.tsx:18-34`)
    Ein `<details class="card methode">`, zugeklappt. Titel woertlich **„Wie gerechnet wird"**
    (`Methode.tsx:18`). Begruendung und die Trennung, die sie tragen muss: „Hinein gehört, wie
    eine Zahl entsteht und was sie nicht sagt. Nicht hinein gehört, was eine Zahl *an diesem
    Tag* einschränkt … Das steht neben der Zahl, denn zugeklappt wäre es verschwiegen."
    (`Methode.tsx:11-13`); dazu „Ein `<details>` und kein Zustand: der Browser kann es ohne
    Skript, die Vorlesehilfe kennt es, und die Seitensuche findet seinen Text." (`:15-16`)
    Kurzzeile, **immer sichtbar**: `Datenabdeckung NN %` - bei `coverage == null` statt dessen
    „noch keine Messdaten im Zeitraum", klein geschrieben - danach, wenn `data_since` da ist,
    „ · Aufzeichnung seit TT.MM.JJJJ" (`{day:"2-digit", month:"2-digit", year:"numeric"}`)
    (`ReportShell.tsx:165-168`).
    Rumpf in dieser Reihenfolge: `extra` = **„Ersparnis im Überblick = PV direkt plus
    Batterieentladung, jeweils gegen den Strompreis der Stunde."** (`PvReport.tsx:121`), dann
    `meta.estimated_note_de` (`ReportShell.tsx:171`). Absaetze 13 px, `line-height 1.55`,
    `--text-2`, `max-width: 90ch` (`globals.css:734`). Ohne `meta` erscheint die Karte gar
    nicht (`ReportShell.tsx:164`).

  * **Handy-Fassung, wo sie abweicht** (`apps/web/src/styles/handy.css`, Grenze
    `max-width: 720px` ab `:107`; die vier Entscheidungen im Kopf der Datei `:11-19`)
    - Seitenrand und Rhythmus: `.report-main { padding: 10px 16px calc(86px + safe-area);
      gap: 14px; font-size: 15px }` (`:110-111`), Grund flach `--deep` (`:109`).
    - Bereichsleiste wandert nach unten (`.fussleiste` `:114-134`); der Kopf gehoert der Seite.
    - Kopf ohne Rahmen und Glas, `padding: 4px 0 0`; der Bereichsname wird Ueberschrift in
      **26 px / 600 / -0.025em** (`.bereichstitel` `:137-141`).
    - Zeitraum zerfaellt in zwei Zeilen: `.report-header-right { display: contents }`,
      Datumskasten neben dem Bereichsnamen (`order: 1`), Spannenschalter als eigene Zeile
      (`order: 3`); beide ohne Rahmen, Radius 11, Flaeche `rgba(255,255,255,.07)`,
      `min-height: 40px`, Knoepfe `min-height: 34px` / 13,5 px (`:148-161`). Lange Ankerform
      aus, kurze an (`:159-160`).
      **Hierher rutscht auch der Verweis „Abrechnung →"**: `.report-header-right > *` bekommt
      `order: 2`, `flex: 1 1 100%`, `white-space: normal` (`:149`) - er steht am Handy also in
      einer eigenen, umbrechenden Zeile zwischen Datumskasten und Spannenschalter. Der
      Kommentar in `globals.css:337-338` nennt den Fall ausdruecklich: „ein zusätzlicher
      Verweis neben Zeitwahl und Zeitraum schob die Zeile sonst aus dem Bild (Photovoltaik 57
      Punkte, PV-Abrechnung 9, gemessen am 10.11.2026)".
    - Reiter werden rollbare Pillen: Radius 999, 14 px, Flaeche `rgba(255,255,255,.07)`, aktiv
      `--text-1` auf `--deep` mit 600; die Reihe laeuft ueber den Seitenrand hinaus
      (`margin: 0 -16px`) und wird an beiden Enden maskiert (`:163-176`).
    - **Der Route-Kicker „Erzeugung · Verwendung · Prognose" ist am Handy nicht da**
      (`AreaNav.tsx:96` `hidden md:block`).
    - Karten: `.card { border: 0; border-radius: 16px; padding: 16px }` (`:182`). Kartenkopf
      `h2.kicker` wird `--font-sans` **16,5 px / 600 / -0.01em / `text-transform: none` /
      `--text-1`** (`:184`) - keine Sperrschrift mehr. Das Beiwerk des Kopfes (hier: Legende
      bzw. „Prognosegüte →") rutscht auf eine eigene Zeile, 13 px, umbrechend (`:185`).
    - Kleine Schrift eine Stufe groesser: 10->11, 11->12, 12->13,5, 13->14,5 px (`:187-192`),
      begruendet: „Am Rechner liest man 12 Punkt aus sechzig Zentimetern, am Handy aus dreißig,
      aber im Gehen."
    - **Die Kacheln werden eine Flaeche** (`:194-207`): `.kpi-grid` ist selbst `--surface-2`,
      Radius 16, `padding: 4px 16px`, zwei Spalten, `gap: 0 20px`; die Kacheln darin verlieren
      Flaeche, Rahmen und Radius und bekommen `border-top: 1px solid --line-1`. Die **erste**
      („Erzeugung") nimmt beide Spalten (`grid-column: 1/-1`), ohne Linie oben,
      `padding: 14px 0 16px`, `gap: 8px`, Zahl **48 px / -0.04em**, Einheit 18 px mit 8 px
      Abstand, Kontextzeile **14,5 px in `--text-2`**. Die uebrigen: Zahl 25 px, Einheit
      13,5 px, Kontextzeile 13 px. Eine allein gelassene letzte Kachel nimmt ebenfalls beide
      Spalten (`:200`) - bei sechs Kacheln tritt das hier nicht ein. Das Kachelwort bleibt
      **gesperrt**, 11 px, `.1em` (`:201`) - ausdruecklich anders als der Kartenkopf.
    - Die beiden Diagrammkarten stehen untereinander: `.report-row` wird einspaltig
      (`globals.css:350`), `gap: 14px` (`handy.css:209`). Eine eigene Hoehenangabe fuer diese
      zwei Karten gibt es nicht - die **300 px** stehen im Markup (`PvReport.tsx:102,106`) und
      gelten also auch am Telefon.
    - Jedes Diagramm wird am Handy nachgestellt, nicht nur umgelegt (`charts/EChart.tsx:75-81`
      -> `charts/handy.ts:44-63`): Achsenschrift mindestens 11 px, `hideOverlap`, Wertachsen
      ohne festes Raster hoechstens drei Schritte, Legenden blaettern in **einer** Zeile
      (`type: "scroll"`, `itemGap 14`, 12 px), Zeiger `confine: true`. Fuer die Prognosekarte
      heisst das: das feste `interval: 6 h` der Zeitachse bleibt (`handy.ts:16,37`), die
      Legende „Prognose / Ist" bleibt unten und blaettert.
    - Methode: `summary` `padding: 15px 16px` (`:213`), Titel `--font-sans` 15 px / 600 /
      `none` / `--text-1` (`:214`), Kurzzeile 13 px und in eigener Zeile
      (`:215`, `globals.css:739-742`),
      Rumpf 14,5 px / 1.5 (`:217`).
    - **Der Spannenstreifen wird eine Liste mit Umschalter** (`PeriodStrip.tsx:42-64`, Stil
      `handy.css:291-299`): `useIsMobile()` (`lib/useIsMobile.ts:18-28`, Grenze 720 px Breite
      **oder** 560 px Hoehe) schaltet um auf `Card gap 12` + Kartenkopf + `.spannen`
      (Schalterreihe, Radius 11, Flaeche `rgba(255,255,255,.07)`, Knopf `min-height: 34px`,
      13,5 px, aktiv `--amber` auf `--petrol`) + `.spannen-liste` als `dl`: je Zeile `dt`
      14,5 px `--text-2` links, `dd` mono 16 px rechts, Trennlinie `--line-1`, erste Zeile ohne
      Linie. Nur **eine** Spanne auf einmal. Begruendung: „Vier Zahlenspalten neben dem Namen
      der Zeile passen nicht auf 390 Punkte: die Namen wurden abgeschnitten, die Zahlen liefen
      ineinander." (`PeriodStrip.tsx:28-30`)
    Gesucht nach `pv`, `prognose`, `Prognose`, `abrechnung`, `erzeug` in `handy.css`: ein
    einziger Treffer, der Kommentar zum umbrechenden Abzeichen in `:152`. Die Route hat **keine**
    Sonderregel; sie lebt von `.report-main`, `.report-header-right`, `.kpi-grid`, `.card`,
    `.report-row`, `.spannen*` und `.methode`.

LUECKEN:

  [traegt-die-seite] **Die ganze zweite Diagrammkarte „Heute und morgen" fehlt** - Ist-Kurve
    gegen Prognosekurve auf einer Zeitachse ueber 48 Stunden, mit der „morgen"-Linie bei
    Tagesende und der Jetzt-Linie (`PvReport.tsx:106-109`, `charts.ts:178-233`). In der App
    kommt auf dieser Seite kein `plan()` und kein `verlauf()` vor
    (`grep -n "plan()\|verlauf" StromSeite.swift:148-193`: kein Treffer). Das ist der Teil der
    Seite, der ihren Kicker „· Prognose" einloest; ohne ihn ist /strom/pv eine Rueckschau.

  [traegt-die-seite] **Die Kacheln „Prognose heute" und „Prognose morgen" fehlen** samt der
    Rechnung dahinter (`PvReport.tsx:96-97`, `forecastKwh` `:24-36`) und samt dem Satz, der sie
    gegen den gewaehlten Tag abgrenzt („für heute, nicht für den gewählten Tag", `:96`). Die
    Felder liegen bereit: `PlanOut.pvForecastTodayKwh` `Schema.swift:5990`,
    `PlanIntervalOut.expectedPvKw` `:5892`.

  [traegt-die-seite] **Der Spannenstreifen „PV im Überblick" fehlt** - vier Groessen (Erzeugt ·
    kWh, Eigenverbrauch, Einspeiseerlös, Ersparnis) gegen die vier Spannen desselben Ankertags
    (`PvReport.tsx:111-120`, `PeriodStrip.tsx:32-94`, `useReport.ts:55-77`). `PvSeite` holt
    genau eine Spanne (`StromSeite.swift:150-151`). Damit fehlen der Seite zugleich zwei
    Zahlen, die sie nirgends sonst zeigt: `exportRevenueEur` (`Schema.swift:3004`) und die
    zusammengesetzte Ersparnis `pvDirectSavingsEur + batteryNetEur` (`:3014`, `:3022`).

  [spuerbar] **Die Methode hat keine Kurzzeile.** `PvSeite` ruft `Methode([…])` ohne `kurz:`
    (`StromSeite.swift:170`), die Vorlage setzt dorthin die Datenabdeckung und „Aufzeichnung
    seit …" (`ReportShell.tsx:165-168`). Der Baustein kann es (`Bericht.swift:343`,
    Begruendung `:336-342`: „eine Seite mit 61 Prozent Datenabdeckung sieht aus wie eine mit
    hundert"), und die Schwesterseite tut es (`StromSeite.swift:39-42`). Dazu fehlt der
    `extra`-Satz „Ersparnis im Überblick = PV direkt plus Batterieentladung, jeweils gegen den
    Strompreis der Stunde." (`PvReport.tsx:121`).

  [spuerbar] **Zwei Farben des Balkenbilds stimmen nicht.** Vorlage: „In Batterie" `C.battery`
    **#7fa3b3**, „Eingespeist" `C.export` **`rgba(228,236,239,.5)`** (`palette.ts:36,44`).
    App: `Farbe.batterie` = **#4F7B88** (`Marken.swift:53`) und `Farbe.netzEinspeisung` =
    `amberWeich` **#FFD778** (`Marken.swift:52,19`) - die App nimmt die Tokenfarbe `--grid-out`
    (`tokens.css:40`), die Vorlage im Diagramm aber `C.export`. Damit liegt in der App ein
    Gelb neben dem Gelb der Sonne (`Farbe.pv` = #F2A900, `Marken.swift:50,18`): der oberste
    Balkenabschnitt ist genau der, der sich von der Erzeugung unterscheiden soll. Die
    Palettenpruefung in `palette.ts:9-31` setzt ΔE 15 als Grenze fuer Reihen **desselben**
    Diagramms.

  [spuerbar] **Fuenf der sechs Kacheln haben keine Kontextzeile.** Die Vorlage haengt an jede
    eine: „N h bewertet" / „keine Daten" (`:88`), „N,N kWh selbst genutzt" (`:89`), „Erlös
    N,NN € bei NN,N ct" (`:90`), „gegenüber Netzbezug" (`:91`). In der App traegt nur „ersparte
    Kosten" ein `dazu:` (`StromSeite.swift:189`). `minutes` `Schema.swift:2975`,
    `exportRevenueEur` `:3004` und `meta.feedInCtKwh` `:2834` sind in derselben Antwort und
    werden in `PvSeite` nicht gelesen.

  [spuerbar] **Die Kachelmenge und ihre Reihenfolge weichen ab.** Vorlage: Erzeugung ·
    Eigenverbrauch · Eingespeist · Ersparnis direkt · Prognose heute · Prognose morgen
    (`PvReport.tsx:88-97`). App: erzeugt · direkt verbraucht · in den Speicher · eingespeist ·
    Eigenverbrauch · ersparte Kosten (`StromSeite.swift:179-190`). „direkt verbraucht" und „in
    den Speicher" stehen in der Vorlage **nicht** als Kacheln - sie sind die beiden ersten
    Reihen des Balkenbilds, und ihre Summe ist der Eigenverbrauch der zweiten Kachel. An der
    Wand steht in der App damit dreimal dieselbe Groesse.

  [spuerbar] **Sechs Kacheln in einer Reihe gegen drei Reihen zu zwei.** Vorlage breit:
    `KpiGrid cols={6}` (`PvReport.tsx:87`, `globals.css:107`, Mindestbreite 150-260 px). App:
    `Kachelfeld` ohne `spalten:` (`StromSeite.swift:153`) steht auf 2 (`Karte.swift:279`).
    Drei Reihen Kacheln schieben die Diagramme unter den Rand - der Grund, aus dem die
    Fahrplanseite `spalten: 4` setzt (`Seiten/Technik/FahrplanSeiten.swift:71-78`).

  [spuerbar] **Die zwei Diagramme stehen nicht nebeneinander**, und es gibt nur eines. Vorlage:
    eine Reihe zu zwei Karten, je 300 px hoch (`PvReport.tsx:101-110`, `globals.css:108`); App:
    eine Karte mit 180 pt Bildhoehe (`StromSeite.swift:154`, `Bericht.swift:81`). Die
    Nebeneinanderstellung ist ausdruecklich gesetzt (Kommentar `PvReport.tsx:99-100`).

  [spuerbar] **Der Verweis „Abrechnung →" fehlt** (`PvReport.tsx:84`, 12 px, `--amber`, nur
    fuer den Hausherrn). In der App fuehrt kein Weg auf `/geld/pv-abrechnung`
    (`grep -rn "pv-abrechnung" apps/ios/DuckCurveHome`: kein Treffer); die Rolle steht bereit
    (`Hauszustand.darfSchalten`, `App/Hauszustand.swift:307`, auf der Schwesterseite benutzt,
    `StromSeite.swift:92,97`), eine Stelle im Kopf dafuer nicht
    (`grep -n "beiwerk\|rechts\|right" App/Reiterzeile.swift`: kein Treffer).

  [spuerbar] **Das Balkenbild hat keinen Zeiger.** Die Vorlage nennt beim Darueberfahren den
    Bucket, je Reihe Name und Wert und darunter „Summe NN,N kWh" (`charts.ts:58-73`). In der
    App ist der Wert eines Balkens nirgends ablesbar (`Bericht.swift:103-147`: kein
    `chartXSelection`, keine `annotation`) - an einem Monatsbild mit dreissig Balken ist die
    Zahl verloren.

  [klein] Der Route-Kicker „Erzeugung · Verwendung · Prognose" fehlt (`PvReport.tsx:77`,
    gezeichnet `AreaNav.tsx:96`, mono 11 px, `uppercase`, `.13em`, `--mist`; nur breit
    sichtbar). In der App gibt es keine Stelle dafuer (`grep -n "kicker\|Kicker"
    App/Reiterzeile.swift App/WandRahmen.swift App/HandRahmen.swift`: kein Treffer).

  [klein] Dafuer traegt das Kachelfeld der App einen Kicker „Photovoltaik"
    (`StromSeite.swift:153`), den die Vorlage nicht hat: dort sind die sechs Kacheln
    ueberschriftlos, und der Seitenname steht nur in `sr-only` und im Dokumenttitel
    (`ReportShell.tsx:127`, `app/strom/pv/page.tsx:3`). Die Schwesterseite begruendet es schon
    („Ohne Ueberschrift: der aktive Reiter sagt, wo man ist", `StromSeite.swift:24`).

  [klein] Die Kachelwoerter weichen ab: „erzeugt" / „direkt verbraucht" / „eingespeist" /
    „ersparte Kosten" (`StromSeite.swift:179-190`) gegen „Erzeugung" / „Eingespeist" /
    „Ersparnis direkt" (`PvReport.tsx:88,90,91`). Gesperrt gesetzt (`Stat.tsx:8`,
    `Kachel.swift` ueber `Kicker`) liest sich Kleinschreibung als Versehen.

  [klein] Die Toene fehlen: „Erzeugung" und „Ersparnis direkt" `tone="amber"` = `--amber`,
    „Eingespeist" `tone="mist"` = `--mist` (`PvReport.tsx:88,90,91`, Abbildung
    `Stat.tsx:5`). App: „erzeugt" `Farbe.pv` (gleich #F2A900, also richtig), „eingespeist"
    `Farbe.netzEinspeisung` statt `mist`, „ersparte Kosten" ohne Farbe
    (`StromSeite.swift:179,183,188`).

  [klein] Die Reihennamen des Balkenbilds weichen ab: Vorlage „Direkt genutzt" / „In Batterie" /
    „Eingespeist" (`PvReport.tsx:18-20`), App „direkt ins Haus" / „in den Speicher" /
    „eingespeist" (`StromSeite.swift:157,161,165`).

  [klein] Der Kartentitel weicht ab: „Erzeugung und Verwendung" (`PvReport.tsx:103`) gegen „Was
    aus der Erzeugung wurde" (`StromSeite.swift:154`).

  [klein] Die Legende steht in der Vorlage **im Kartenkopf rechts** als Farbfleck 10x8 px,
    Radius 1, plus Name in 12 px `--text-3` (`ReportShell.tsx:192-203`, `Card.tsx:20-29`); die
    App legt sie oben links **in** das Diagramm (`Bericht.swift:120`:
    `.chartLegend(position: .top, alignment: .leading, spacing: 6)`).

  [klein] Der Verweis „Prognosegüte →" im Kopf der zweiten Diagrammkarte (`PvReport.tsx:107`,
    `--amber`) hat in der App kein Gegenstueck - die Zielseite gibt es
    (`/system` -> `PrognoseSeite`, `App/Seitenwahl.swift:83-84`).

  [klein] Der Titel der Methodenkarte heisst in der Vorlage „Wie gerechnet wird"
    (`Methode.tsx:18`), in der App „Wie das gerechnet ist" (`Bericht.swift:344`) - betrifft
    alle Berichtsseiten.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * Abfragen: `Api.energieUebersicht(_ zeitraum: String, anker: String) async throws ->
    EnergySummaryOut` - `DuckCurveKit/Netz/Api.swift:179`; `Api.plan() async throws -> PlanOut`
    - `:167`; `Api.verlauf(_ spanne: Verlaufsspanne = .heute) -> HistoryOut` mit
    `.heute = "today"` - `:133-141`; `Api.verlaufTag(_ tag: String)` fuer einen beliebigen Tag
    - `:155`.
  * `EnergySummaryOut` mit `totals`, `buckets`, `meta` - `Modelle/Schema.swift:2942-2971`;
    `EnergyBucketOut` mit `label` und `totals` - `:2810-2830`.
  * `EnergyTotalsOut`, alle Felder dieser Seite vorhanden und wahlfrei: `minutes` `:2975`,
    `pvKwh` `:2977`, `exportKwh` `:2979`, `pvDirectKwh` `:2986`, `pvToBatteryKwh` `:2989`,
    **`exportRevenueEur` `:3004`**, `pvDirectSavingsEur` `:3014`, `selfConsumptionShare`
    `:3020`, **`batteryNetEur` `:3022`** - `Schema.swift:2974-3023`.
  * `EnergyMetaOut` mit **`feedInCtKwh` `:2834`**, `dataSince` `:2835`, `coverage` `:2836`,
    `estimatedNoteDe` `:2837` - `Schema.swift:2832-2864`.
  * `PlanOut` mit `horizonStart` `:5986`, `horizonEnd` `:5987`, `intervals` `:5989`,
    **`pvForecastTodayKwh` `:5990`** - `Schema.swift:5979-6045`; `PlanIntervalOut` mit `ts`
    `:5891` und **`expectedPvKw` `:5892`** - `:5890-5965`.
  * Der Plan und die Minutenwerte liegen schon im Hauszustand und muessen nicht erneut geholt
    werden: `var plan: PlanOut?` - `DuckCurveHome/App/Hauszustand.swift:27`,
    `var raster = Minutenraster()` - `:29`, `var jetzt: Date` - `:96`; benutzt so in
    `Seiten/Jetzt/JetztSeite.swift:250,293-328`.
  * `Minutenraster` / `Verlaufspunkt` mit `pv` aus **`pv_power_kw`** -
    `DuckCurveKit/Zustand/Verlauf.swift:7-38` und `:81`. Das ist genau die Reihe, die die
    Vorlage als „Ist" zeichnet.
  * Energie unter einer Leistungskurve, Trapezregel, mit optionaler Obergrenze:
    `Tageskurve.energie(_ punkte: [Kurvenpunkt], bis: Double?) -> Double?` -
    `DuckCurveKit/Zustand/Tageskurve.swift:235-245`; `Kurvenpunkt` (Stunde seit Tagesbeginn,
    Wert) `:9-20`.
  * Ist gegen Prognose als Reihenpaar, fertig gerechnet: `Tageskurve.baue(…)` setzt `k.pv` aus
    dem Raster (`Tageskurve.swift:153`) und `k.pvErwartet` aus `plan.intervals`
    (`:170-178`) - **aber nur fuer einen Tag** (`Kurventag.gestern/heute/morgen` `:50-68`),
    nicht ueber 48 Stunden.
  * Tagesfenster und Zeitumrechnung: `Tageskacheln.fenster(_:jetzt:)` -
    `DuckCurveKit/Zustand/Tageskacheln.swift` (benutzt `Zustand/Ruhebild.swift:122`),
    `Zeit.ausIso`, `Zeit.iso` - `DuckCurveKit/Formate/Zeit.swift`; `Kalender.haus` mit
    Europe/Berlin - `Formate/Formate.swift:117,195`.
  * Formate: `zahl(_:stellen:)` `Formate/Formate.swift:44`, `kw` `:62`, `kwMitEinheit` `:69`,
    `kwh` `:75`, `prozent` `:81`, `ct` (ergibt „NN,N ct/kWh") `:93`, `euro` `:99`,
    `leer` = „-" `:27`, `hhmm` `:124`; `Tag.lang` `Formate/Tag.swift:87`, `Tag.kurz` `:94`,
    `Tag.tagMonat` `:106`, `Tag.iso` `:16`.
  * Farben, deckungsgleich mit `palette.ts`: `Marken.amber` #F2A900 `Gestalt/Marken.swift:18`,
    `amberWeich` #FFD778 `:19`, `mist` #7FA3B3 `:20`, `pv` = amber `:50`,
    `diagrammSpeicher` #7FA3B3 `:135` (**das ist `C.battery`**), `netzEinspeisung` = amberWeich
    `:52`, `batterie` #4F7B88 `:53`, `pvSchatten` #C8902F `:149`; Huellen in
    `DuckCurveHome/Gestalt/Farben.swift:31-33,54-57,77-82`.
    Gesucht nach `E4ECEF`, `e4ecef`, `0xE4` in `Marken.swift`: **kein Treffer** - fuer
    `C.export` `rgba(228,236,239,.5)` gibt es keine Marke.
  * Bausteine der Oberflaeche: `Berichtsseite` (Laden, Fehler, altes Bild stehen lassen)
    `Seiten/Bericht.swift:15-64`, `Balkenbild` `:70-149`, `Tabelle` (am Telefon eine Spalte mit
    Pillen-Umschalter - die Gestalt, die `PeriodStrip` am Handy braucht) `:157-327`, `Methode`
    mit `kurz` `:334-397`; `Karte` mit `beiwerk` `Gestalt/Karte.swift:15-104`, `Kacheldaten`
    (mit `dazu`, `farbe`, `weg`) `:121-151`, `Kachel` `:158-266`, `Kachelfeld` mit `spalten:`
    `:274-343`, `Leer` `:390-404`, `Stoerung` `:410-436`; `Kicker`
    `Gestalt/Typografie.swift:132-141`; `Umbruchzeile` `Gestalt/Umbruchzeile.swift:13`;
    `Seite` + `Zeitraumleiste` + `Datumskasten` `App/Seitenwahl.swift:136-291`.
  * Rolle: `Hauszustand.darfSchalten` = `zugang.rolle == .hausherr` -
    `App/Hauszustand.swift:307`.
  * Mehrere Spannen auf einmal, als Vorbild fertig: `holeSpannen` mit `withTaskGroup` und
    `try?` je Spanne - `Seiten/Energie/WaermeSeite.swift:48-61`; gezeichnet als `Tabelle` in
    `:313-321`, Karte „Wärme im Zeitraum" `:181-183`; die Zeilen rechnet der Kern:
    `Waermeuebersicht.spannenzeilen(_:) -> [(wort: String, werte: [String])]` -
    `DuckCurveKit/Zustand/Waermeuebersicht.swift:280-301`.
  * Zeitachse ueber mehr als einen Tag, als Vorbild fertig: `.chartXScale(domain: zeitbereich)`
    mit `AxisMarks(values: .stride(by: .hour, count: 6))` und „am Tagesanfang das Datum, sonst
    die Stunde" - `Diagramme/Fahrplanzeichnung.swift:148,153-166`; die Jetzt-Linie als
    `RuleMark` in `Farbe.amberWeich`, gestrichelt `[4,3]`, 1,2 pt - `:133-141`.
  * Sonne als Flaeche, Prognose blass und gestrichelt, in einem Bild: `TageskurveBild`
    `Diagramme/Tageskurve.swift:102-118` (`AreaMark` mit Verlauf `Farbe.pv.opacity(0.45)` ->
    `0.04`, `LineMark` 2 pt, Erwartung `opacity(0.7)` mit `dash: [5,5]`); Regel im Kopf der
    Datei: „Was gestrichelt ist, ist nicht gemessen" (`:16-17`).
  * Ablesbare Diagramme, als Vorbild fertig: `.chartXSelection(value:)` plus `RuleMark` an der
    gelesenen Stelle - `Diagramme/Prognosezeichnung.swift:250-262`; mit Beschriftung daneben
    `Diagramme/Wirkungszeichnung.swift:191,243-258`.
  * Raster nach Breite, als Vorbild fertig: `GridItem(.adaptive(minimum: 290))` breit gegen
    `GridItem(.flexible())` schmal - `Seiten/Haus/HausSeite.swift:354-357`, gezeichnet `:310`.

ES FEHLT:

  1. **Die Prognosesummen heute/morgen.** Neue Funktion im Kern, Vorbild der Vorlage
     `forecastKwh` (`PvReport.tsx:24-36`):
     `public static func prognosekwh(_ plan: PlanOut?, tagesbeginn: Date) -> (heute: Double,
     morgen: Double, punkte: [(zeit: Date, kw: Double)])` in einer neuen Datei
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Pvbild.swift`. Darin woertlich die
     drei Regeln der Vorlage: Intervallbreite aus den ersten zwei Stuetzpunkten, mindestens
     1/60 h; Fenster [Tagesbeginn, +24 h) und [+24 h, +48 h); `heute` wird durch
     `plan.pvForecastTodayKwh` ersetzt, **wenn dieses ungleich 0 ist**. Ohne Plan oder mit
     weniger als zwei Intervallen: `(plan?.pvForecastTodayKwh ?? 0, 0, [])`.
  2. **Die Reihen der 48-Stunden-Kurve.** In derselben Datei:
     `public static func tagundmorgen(raster: [Verlaufspunkt], plan: PlanOut?, tagesbeginn:
     Date) -> (ist: [(Date, Double?)], prognose: [(Date, Double)], ende: Date)` - Ist aus
     `Verlaufspunkt.pv` **ohne** Lueckenschluss (`connectNulls: false`, `charts.ts:226`),
     Prognose aus `expectedPvKw` ueber den ganzen Horizont, `ende = tagesbeginn + 48 h`.
     `Tageskurve` taugt dafuer nicht: ihre x-Achse ist „Stunde seit Tagesbeginn" eines
     **einzelnen** Tages (`Tageskurve.swift:5-20`).
  3. **Die Kennzahlen der Seite als Kern-Rechnung**, damit Woerter und Kontextzeilen pruefbar
     sind: `public static func kacheln(_ b: EnergySummaryOut, prognose: (heute: Double, morgen:
     Double), istHeute: Bool) -> [Kennzahl]` in derselben Datei, Woerter und Toene nach
     `PvReport.tsx:88-97`, `Kennzahl` liegt bereit (`Zustand/Kennzahl.swift`, Abbildung auf
     Farben `Gestalt/Farben.swift:98-107`).
  4. **Spannenzeilen fuer die Energieuebersicht** - dieselbe Funktion, die /strom braucht, also
     nur einmal zu bauen: `public static func spannenzeilen(_ je: [Spanne: EnergySummaryOut],
     zeilen: Satz) -> [(wort: String, werte: [String])]` in
     `DuckCurveKit/Sources/DuckCurveKit/Zustand/Stromuebersicht.swift` **neu**, mit einem Satz
     „PV" (Erzeugt · kWh / Eigenverbrauch / Einspeiseerlös / Ersparnis) und einem Satz „Strom"
     (siehe `messung2/strom.md`). Darin die Regel „ab 100 kWh ohne Nachkommastelle"
     (`de1(x, x >= 100 ? 0 : 1)`, `PvReport.tsx:115`), die `Formate` nicht hat, und die Summe
     `pvDirectSavingsEur + batteryNetEur` (`:118`). Vorbild
     `Waermeuebersicht.swift:280-301`.
  5. **Mehrfachabfrage einer Spanne-Reihe im Kern**, damit sie nicht in jeder Seite neu steht:
     `public func jeSpanne<T>(_ hole: @Sendable (Spanne) async throws -> T) async ->
     [Spanne: T]` an `Api` - heute steht sie privat als `holeSpannen` in
     `WaermeSeite.swift:48-61`.
  6. **Ein kurzes Datum** fuer die Methodenzeile: `Tag.ziffern(_:) -> "14.11.2026"` in
     `DuckCurveKit/Formate/Tag.swift` (es gibt `lang` `:87`, `kurz` `:94` mit Wochentag,
     `tagMonat` `:106` ohne Jahr - keines ist „TT.MM.JJJJ").
  7. **Die Farbe der Einspeisung im Diagramm**: `Marken.diagrammEinspeisung =
     Farbwert(0xE4ECEF, deckung: 0.5)` (oder der geprueften Ersatzwert) in
     `Gestalt/Marken.swift` neben `diagrammSpeicher` `:135`, mit Huelle in
     `Gestalt/Farben.swift:77-80`. `netzEinspeisung` bleibt, was es ist - die Flussfarbe
     `--grid-out` (`tokens.css:40`).

BAUPLAN: Welche Dateien anzulegen oder zu aendern sind, Karte fuer Karte, in der Reihenfolge
der Vorlage

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Tag.swift` - `ziffern(_:)` ergaenzen
     (ES FEHLT 6).
  2. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift` +
     `apps/ios/DuckCurveHome/Gestalt/Farben.swift` - `diagrammEinspeisung` (ES FEHLT 7).
  3. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift` - `jeSpanne(_:)` (ES FEHLT 5)
     und `WaermeSeite.holeSpannen` darauf umstellen, damit es nur eine Fassung gibt.
  4. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Pvbild.swift` **neu** -
     `prognosekwh`, `tagundmorgen`, `kacheln` (ES FEHLT 1-3), mit Tests nach dem Muster von
     `Tests/DuckCurveKitTests/AusblickTests.swift` (dort steht der Bau eines `PlanOut` mit
     Viertelstunden-Intervallen schon, `:14-29`).
  5. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Stromuebersicht.swift` **neu** -
     `spannenzeilen(_:zeilen:)` (ES FEHLT 4).
  6. `apps/ios/DuckCurveHome/Seiten/Bericht.swift` -
     a) `Spannenstreifen` **neu** neben `Tabelle`: breit die Tabelle, schmal eine Spalte mit
        Pillen-Umschalter (beides kann `Tabelle` `:157-327`), dazu der Kartenkopf rechts
        („jeweils bis jetzt" / „jeweils bis TT.MM.JJJJ", `PeriodStrip.tsx:34-38`), der
        Spaltenkopf „Heute"/„TT.MM." statt „Tag" (`PeriodStrip.tsx:9-16`;
        `Spanne.name` sagt „Tag", `Zeitraum.swift:17`) und die fette erste Zeile
        (`PeriodStrip.tsx:84`). Wird von /strom und /strom/pv gebraucht - also ein Baustein,
        keine Seitenlogik.
     b) `Balkenbild` um `.chartXSelection` und eine Ablesezeile erweitern, die Bucket, die
        Reihen ungleich Null und die Summe nennt (Vorbild `Prognosezeichnung.swift:250-262`,
        Text nach `charts.ts:58-73`). Betrifft jedes Balkenbild der App.
     c) `Methode.titel` auf „Wie gerechnet wird" (`:344`) - betrifft alle Berichtsseiten,
        darum einmal und zuletzt in dieser Datei.
  7. `apps/ios/DuckCurveHome/Diagramme/Pvtageskurve.swift` **neu** - die Prognosekarte:
     `AreaMark` + `LineMark` fuer „Ist" in `Farbe.pv` (Verlauf 0,3 -> 0,03, Linie 2,5 pt,
     Luecken offen), `LineMark` fuer „Prognose" in #E4ECEF, 1,5 pt, `dash: [5,4]`, dazu eine
     blasse Flaeche; `RuleMark` bei `jetzt` in `Farbe.pv`, gestrichelt, ohne Beschriftung, und
     `RuleMark` bei Tagesende in `Farbe.text1.opacity(0.25)` mit der Beschriftung „morgen"
     (`.annotation(position: .topTrailing)`). Zeitachse `.chartXScale(domain: tagesbeginn ...
     ende)` mit `.stride(by: .hour, count: 6)` und „am Tagesanfang das Datum, sonst die
     Stunde" - Vorbild `Fahrplanzeichnung.swift:148,153-166`; Legende „Prognose · Ist" und
     Ablesen ueber `.chartXSelection` wie `Prognosezeichnung.swift:250-262`.
  8. `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`, `struct PvSeite` (`:147-193`) -
     in dieser Reihenfolge:
     a) Abfrage auf drei Teile: die gewaehlte Spanne wie bisher, `jeSpanne { api.energie-
        Uebersicht($0.rawValue, anker: z.anker) }` und - nur fuer die Prognose - `plan` und
        Minutenwerte. Plan und Raster **nicht** erneut holen, wenn der Zeitraum heute ist:
        `haus.plan` und `haus.raster` haben beides schon (`Hauszustand.swift:27,29`,
        Benutzung `JetztSeite.swift:250`); fuer einen vergangenen Anker bleibt die Prognose
        laut Vorlage ohnehin die von **heute** (`PvReport.tsx:92-95`). Muster fuer mehrere
        Antworten in einem Zug: `WaermeSeite.swift:30-40`, `SpeicherSeite`
        (`StromSeite.swift:202-209`).
     b) `Kachelfeld(kacheln: Pvbild.kacheln(…).map(Kacheldaten.init), spalten: 3)` ohne Kicker
        (`FahrplanSeiten.swift:71-78` als Vorbild fuer `spalten:`), sechs Kacheln in der
        Reihenfolge der Vorlage samt Kontextzeilen und Toenen.
     c) die zwei Diagrammkarten in eine Reihe, breit zweispaltig, schmal einspaltig
        (`LazyVGrid` mit `GridItem(.adaptive(minimum: 290))` gegen `GridItem(.flexible())`,
        Vorbild `HausSeite.swift:354-357`); Bildhoehe 240 pt (300 px Karte minus Rand und
        Kopfzeile). Links „Erzeugung und Verwendung" mit den drei Reihen in den Farben
        `Farbe.pv` / `Farbe.diagrammSpeicher` / `Farbe.diagrammEinspeisung` und den Namen
        „Direkt genutzt" / „In Batterie" / „Eingespeist"; rechts die Prognosekarte aus 7.,
        Titel „Heute und morgen" bzw. „Prognose heute und morgen" je nach
        `z.istAktuell(jetzt:)` (`Seitenwahl.swift:238`).
     d) danach `Spannenstreifen` mit Kicker „PV im Überblick".
     e) `Methode` mit `kurz:` = Abdeckung · „Aufzeichnung seit <Tag.ziffern>" und dem
        `extra`-Satz der Vorlage; Abdeckung nach dem Verhalten der Vorlage: `nil` -> „noch
        keine Messdaten im Zeitraum", sonst „Datenabdeckung NN %" (`ReportShell.tsx:166`).
  9. Offen, nicht in diesem Zug: die beiden Verweise im Kopf („Abrechnung →" fuer den
     Hausherrn, „Prognosegüte →" im Kartenkopf) und der Route-Kicker. Der Kartenkopf-Verweis
     passt in `Karte(beiwerk:)` (`Karte.swift:19,79-81`) und geht sofort; die zwei Stellen im
     **Gerippe** (Kopfzeile rechts, Route-Kicker) sind eine Entscheidung ueber alle dreizehn
     Berichtsseiten und gehoeren nach `App/Reiterzeile.swift` / `App/WandRahmen.swift`, nicht
     in diese Seite.

WAS SCHWIERIG WIRD

  * **Zwei Tage auf einer Achse, mit einer Trennlinie, die beschriftet ist.** Swift Charts
    kennt `RuleMark` und `.annotation`, aber nichts, was `markLine` mit `position:
    "insideEndTop"` entspricht (`charts.ts:219`). Der Weg des Projekts ist `RuleMark` plus
    `.annotation(position: .topTrailing, alignment: .leading)` - gegangen in
    `Diagramme/Wirkungszeichnung.swift:191` und `:243-258`. Die Zeitachse selbst ist gelöst:
    `Fahrplanzeichnung.swift:148,153-166` zeichnet den Planhorizont ueber zwei Tage und setzt
    am Tagesanfang das Datum statt der Stunde - mit genau der Begruendung, die hier auch gilt
    („zwei Zwoelfen ohne Tag sind nicht zu trennen", `:158-159`).
  * **Luecken in der Ist-Kurve muessen Luecken bleiben.** `connectNulls: false`
    (`charts.ts:226`) heisst in Swift Charts: die Reihe in Abschnitte zerlegen und je Abschnitt
    eine eigene `series` geben, denn `LineMark` ueber `nil` verbindet sonst. Vorbild fuer
    Abschnitte: `reports/charts.ts:148-162` (`runsOf`) hat es auf der Gegenseite, in der App
    steht ein vergleichbares Zerlegen in `Zustand/Verlauf.swift` nicht - das ist neu zu
    schreiben und gehoert in `Pvbild.tagundmorgen` (ES FEHLT 2), nicht in die Zeichnung.
  * **Der Zeiger auf einem gestapelten Balken.** ECharts bekommt `trigger: "axis"` samt Summe
    geschenkt; Swift Charts liefert mit `chartXSelection` nur den Wert der Querachse, die
    Reihen dazu muss man selbst heraussuchen. An einem Balkenbild mit Woertern auf der Achse
    ist `chartXSelection` ein `String?` - die Zuordnung laeuft also ueber `bucket.label`, und
    die Liste ohne Wiederholung gibt es schon (`Bericht.swift:87-97`).
  * **Legende im Kartenkopf statt im Diagramm.** `.chartLegend(.hidden)` abschalten und die
    Legende als eigene Ansicht in `Karte(beiwerk:)` geben (`Karte.swift:19,79-81`). Am Telefon
    rutscht das Beiwerk in der Vorlage auf eine eigene Zeile (`handy.css:185`), was
    `Karte.swift:56-62` im schmalen Fall **nicht** tut - es setzt Kicker und Titel
    nebeneinander. Fuer eine dreiteilige Legende ist das zu wenig Platz; sie braucht eine
    umbrechende Zeile, also `Umbruchzeile` (`Gestalt/Umbruchzeile.swift:13`), nicht `beiwerk`.
    Dieselbe Karte traegt in der Vorlage rechts auch den Verweis „Prognosegüte →" - zwei
    Beiwerke in einem Kopf, die am Handy untereinander liegen.
  * **Zwei Karten nebeneinander.** Es gibt in der App bisher keine Reihe aus zwei Karten
    (`grep -rn "report-row\|Kartenreihe" apps/ios/DuckCurveHome`: kein Treffer). Der gewaehlte
    Weg des Projekts ist `LazyVGrid` mit `GridItem(.adaptive(minimum:))` gegen eine Spalte -
    `HausSeite.swift:354-357`, `Bausteine/Wpmenue.swift:88-91`.
  * **Die Prognose folgt dem Anker nicht.** Blaettert man zurueck, zeigen Kacheln, Balkenbild
    und Streifen den gewaehlten Tag, die drei Prognosefelder aber weiter heute
    (`PvReport.tsx:92-97`). Das ist kein Fehler, den man „aufraeumt", sondern die Entscheidung
    der Vorlage samt dem Satz, der sie sichtbar macht („für heute, nicht für den gewählten
    Tag"). In der App muss `Berichtsseite` dafuer eine Antwort tragen, die **nicht** am
    `Zeitraum` haengt - sonst wird die Prognose bei jedem Blaettern neu geholt und sieht
    danach aus wie die des gewaehlten Tages.
  * **Fuenf bis sechs parallele Laeufe je Zeitraumwechsel** (eine Spanne + vier Spannen +
    gegebenenfalls Plan und Verlauf). `WaermeSeite` loest das mit `async let` fuer die
    Hauptabfragen und einer `TaskGroup` mit `try?` je Spanne
    (`WaermeSeite.swift:30-40,48-61`), damit eine fehlende Spalte die Seite nicht mitnimmt.
    Dasselbe Muster hier - und Plan und Verlauf mit `try?`, weil die Vorlage sie mit
    `Promise.allSettled` holt und ohne sie weiterzeichnet (`PvReport.tsx:49-52`).
