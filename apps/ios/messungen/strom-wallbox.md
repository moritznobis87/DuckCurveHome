========================= messen:strom-wallbox   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:281-337` - `WallboxSeite` steht in
derselben Datei wie `StromSeite` und `SpeicherSeite`; Gerippe
`apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-64`, Huelle
`apps/ios/DuckCurveHome/App/Seitenwahl.swift:136-170`, Weg `/strom/wallbox` ->
`App/Seitenwahl.swift:45-46`, Reiter `DuckCurveKit/.../Bereiche/Bereiche.swift:111`)

1. Zeitraumleiste, am iPad im Gerippe oberhalb der Rollflaeche
   (`App/Seitenwahl.swift:147-152` -> `:188-207`): links Spannenwahl Tag/Woche/Monat/Jahr
   (`:210-226`; alle vier, weil der Reiter keine Einschraenkung setzt, `Bereiche.swift:111`
   ohne `spannen:`), rechts der Datumskasten. Am Telefon zeichnet das `HandRahmen`, nicht die
   Seite (`App/Seitenwahl.swift:144-152`).
2. Kachelfeld mit sechs Kacheln **und dem Kicker „Wallbox"** (`StromSeite.swift:287`, Daten
   `:316-336`), gezeichnet von `Gestalt/Karte.swift:274-343`: am Telefon fuehrt die erste
   Kachel ueber die ganze Breite (48 pt, `Karte.swift:240`), die uebrigen zweispaltig mit
   Haarlinien; am iPad alle in zwei Spalten (`Karte.swift:279`).
   Die sechs woertlich (`StromSeite.swift:318-335`): „geladen" (`Formate.zahl(evKwh, 1)` kWh,
   `Farbe.wallbox`) · „Ladevorgänge" (`String(b.sessions.count)`, ohne Einheit) · „aus der
   Sonne" (`evPvKwh` kWh, `Farbe.pv`) · „aus dem Netz" (`evGridKwh` kWh, Textfarbe) ·
   „Kosten" (`Formate.euro(evCostEur)`) · „entgangene Einspeisung"
   (`Formate.euro(evOpportunityEur)`, dazu „was die Sonnenkilowattstunden im Netz gebracht
   hätten"). Nur die letzte Kachel hat eine Kontextzeile.
3. Karte „Ladevorgänge" (`StromSeite.swift:288-313`). Leer: `Leer(satz: "In diesem Zeitraum
   wurde nicht geladen.")` (`:290`, Baustein `Karte.swift:390-404`). Sonst `Tabelle`
   (`Bericht.swift:157-327`): Zeilenname `Formate.hhmm(iso: start) + " – " +
   Formate.hhmm(iso: end)` (`:293-295`), fuenf Spalten in dieser Reihenfolge: „kWh"
   (`zahl(kwh,1)`), „Sonnenanteil" (`prozent(pvShare)`), „Netz" (`zahl(gridKwh,1)`),
   „Kosten" (`euro(costEur)`), „mittlere Leistung" (`zahl(avgKw,1)`) (`:296-311`). Alle
   Zellen in `Farbe.text1` (`Bericht.swift:314-319`, `farben` ist leer). Am Telefon eine
   Spalte mit Pillenschalter darueber (`Bericht.swift:206-244`), am iPad alle fuenf
   nebeneinander (`:282-312`). Kein Kartenkopf rechts, keine Sortierung: die Reihenfolge ist
   die der Antwort.
4. Methode, zugeklappt, Titel „Wie das gerechnet ist" (`StromSeite.swift:314`, Baustein
   `Bericht.swift:334-397`, Titel `:344`). **Ohne `kurz:`** - der Rumpf enthaelt allein
   `b.summary.meta.estimatedNoteDe`.
5. Fehler als `Stoerung` oberhalb des Inhalts, ohne ihn zu ersetzen (`Bericht.swift:36-38`,
   Baustein `Karte.swift:410-436`); „Wird geholt …" / „Für diesen Zeitraum ist nichts da."
   (`Bericht.swift:43-47`).

Daten: genau eine Abfrage, `api.energieWallbox(z.spanne.rawValue, anker: z.anker)`
(`StromSeite.swift:284-285` -> `DuckCurveKit/Netz/Api.swift:196-198`, `GET /energy/ev`).

Nicht auf der Seite, nachgesehen statt vermutet:
* `grep -rn "evBatteryKwh" apps/ios/DuckCurveHome` - kein Treffer. Das Feld existiert
  (`DuckCurveKit/Modelle/Schema.swift:3001`, Schluessel `ev_battery_kwh` `:3051`) und wird in
  der ganzen App nicht gelesen.
* `grep -n "buckets\|Balkenbild" StromSeite.swift` trifft innerhalb von `WallboxSeite`
  (`:281-337`) **nichts**; `buckets` nur in `StromSeite` (`:52-117`), `Balkenbild` nur in
  `StromSeite`/`PvSeite`/`SpeicherSeite` (`:15,18,110,168,180,227`), alles oberhalb Zeile 281.
* `grep -rn "PeriodStrip\|Spannenstreifen\|im Überblick\|useMultiPeriod" apps/ios` - kein
  Treffer.
* `grep -rn "coverage\|dataSince" apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
  trifft nur `:41,52-55` (in `StromSeite`), nicht in `WallboxSeite`.
* `grep -n "wallbox\|Ladevorgang\|\bev-" apps/web/src/styles/handy.css` - kein Treffer: es
  gibt keine Regel nur fuer diese Route. Was greift, sind die allgemeinen Regeln (unten).

VORLAGE
(Einstieg `apps/web/src/app/strom/wallbox/page.tsx:1-7` - die Seite ist nur
`<EvReport />`; alles steht in `apps/web/src/components/reports/EvReport.tsx:1-105`)

  * **Huelle `ReportShell`** (`EvReport.tsx:36` -> `ReportShell.tsx:97-134` ->
    `components/layout/AreaShell.tsx:13-30`)
    `title="Wallbox"`, `kicker="Ladungen · Herkunft · Kosten"`. Der Titel steht **nicht** im
    Kopf, sondern nur als `sr-only` (`ReportShell.tsx:127`) - mit Begruendung im Kommentar
    `:99-100`: „der aktive Reiter sagt, wo man ist. Er bleibt im Dokumenttitel, damit ein
    Browserfenster und die Vorlesehilfe ihn haben." Der Kicker steht rechts in der
    Reiterzeile, 11 px, gesperrt, **erst ab `md`** (`layout/AreaNav.tsx:96`:
    `className="kicker hidden truncate pb-2.5 md:block"`), also am Handy nicht.
    Rechts im Kopf: Blaetterkasten `‹ Anker ›` mit `min-w-[190px]`, 12 px, und das Wort
    „heute" in Amber, 11 px, nur wenn der Anker nicht heute ist (`ReportShell.tsx:109-117`);
    daneben die vier Spannenknoepfe, aktiver mit `background: var(--amber)`,
    `color: var(--petrol)`, 12 px, `borderRadius: 3` (`:120-126`).
    Rand/Abstaende der Flaeche: `p-5`, `gap-4` (`AreaShell.tsx:15`).
    Zustaende: `error` -> `ErrorBanner` ganz oben (`EvReport.tsx:37`,
    `ReportShell.tsx:147-153`: Rahmen `rgba(224,83,61,.4)`, Flaeche `rgba(224,83,61,.12)`,
    Text `var(--alert)`, 12 px, gesperrt 0.1em, Grossbuchstaben). Kein Ladezustand: `useReport`
    laesst den alten Stand stehen (`useReport.ts:18-46`, `REFRESH_MS = 5*60_000` `:7`).
    DATEN: `useReport(api.energyEv, period, anchor)` (`EvReport.tsx:25`), zusaetzlich
    `useMultiPeriod(api.energyEv, anchor)` fuer alle vier Spannen zum **selben Anker**
    (`:26` -> `useReport.ts:55-77`). Kommentar `useReport.ts:48-54` nennt den Grund: der Anker
    war einmal fest auf heute verdrahtet, „zwei Zeitraeume in einer Ansicht, ohne dass es
    dastand."

  * **KPI-Raster, sechs Kacheln** (`EvReport.tsx:38-45`, `KpiGrid cols={6}`
    -> `ReportShell.tsx:176-182`, `globals.css:107`:
    `grid-template-columns: repeat(auto-fit, minmax(clamp(150px, 100%/var(--cols,6) - 16px, 260px), 1fr))`,
    `gap: 16px`. Kommentar `globals.css:54-57`: `--cols` ist Obergrenze, nicht Vorschrift -
    „Lieber zwei ruhige Reihen als eine gedraengte.")
    Kachel = `Stat` (`components/ui/Stat.tsx:4-19`): Kicker 11 px gesperrt 0.13em
    Grossbuchstaben in `--text-kicker` (= `--mist`, `tokens.css:35`), Zahl **26 px** mono
    `tracking-[-.02em]`, Einheit 13 px in `--text-3` und Sans, Hinweiszeile 12 px
    `line-height 1.35` `--text-3`, hoechstens zwei Zeilen (`line-clamp-2`). Kommentar
    `Stat.tsx:13-15`: abgeschnitten („von 0,0 kWh Netzladung i…") ist die Zeile nutzlos, zwei
    Zeilen sind das Maximum, damit die Kacheln einer Reihe gleich hoch bleiben.
    Karte: `padding: "14px 18px"`, `gap: 6` (`Stat.tsx:7`), Flaeche `--surface-2` (#123544),
    Rand `--line-1`, Radius `--radius-2` (3 px) (`globals.css:67-77`).
    Die sechs woertlich, in dieser Reihenfolge:
    1. **„Geladen"** `de1(ev_kwh)` kWh, `tone="mist"` (= `--mist` #7FA3B3), Hinweis
       `${data.sessions.length} Ladevorgänge` (`EvReport.tsx:39`).
    2. **„Sonnenanteil"** `pct((ev_pv_kwh + ev_battery_kwh) / ev_kwh)`, nur wenn
       `ev_kwh > 0`, sonst „-" (`:28`), `tone="amber"`, Hinweis
       `PV ${de1(ev_pv_kwh)} · Batt. ${de1(ev_battery_kwh)} kWh` (`:40`).
    3. **„Aus dem Netz"** `de1(ev_grid_kwh)` kWh, `tone="ember"` (= `--alert` #E0533D),
       Hinweis `Ø ${de1(paidCt,1)} ct/kWh bezahlt` mit
       `paidCt = ev_cost_eur / ev_grid_kwh * 100` nur wenn `ev_grid_kwh > 0.01`, sonst
       woertlich „kein Netzbezug" (`:29`, `:41`).
    4. **„Bezahlt"** `eur(ev_cost_eur)`, `tone="ember"`, Hinweis „Netzanteil × Strompreis"
       (`:42`).
    5. **„Entgangene Vergütung"** `eur(ev_opportunity_eur)`, `tone="muted"` (= `--text-3`),
       Hinweis „nicht eingespeister PV-Strom" (`:43`).
    6. **„Effektiv je kWh"** `de1(effCt,1)` mit Einheit „ct", ohne Ton (also `--text-1`),
       `effCt = (ev_cost_eur + ev_opportunity_eur) / ev_kwh * 100` nur wenn
       `ev_kwh > 0.01`, sonst „-" (`:30`, `:44`). Keine Kachel „Ladevorgänge".
    Formate: `de1` = deutsche Zahl mit genau einer Stelle, „-" bei `null`
    (`ReportShell.tsx:14`); `eur` = `de1(n,2) + " €"` (`:15`); `pct` =
    `Math.round(frac*100) + " %"` (`:16`).
    DATEN: `data.summary.totals` (`EvReport.tsx:27`), Felder `ev_kwh`, `ev_pv_kwh`,
    `ev_battery_kwh`, `ev_grid_kwh`, `ev_cost_eur`, `ev_opportunity_eur`; dazu
    `data.sessions.length`.

  * **Karte „Geladene Energie nach Herkunft"** (`EvReport.tsx:46-51`)
    Eigene Reihe mit `--cols: 1fr` (`report-row`, `globals.css:108`), Karte
    `padding: 16, height: 280`. Kartenkopf `CardHead` (`ui/Card.tsx:20-28`): Titel als
    `h2.kicker` (13 px, gesperrt 0.13em, Grossbuchstaben, `--text-kicker`,
    `globals.css:57-64`), rechts die **Legende** `ChartLegend`
    (`ReportShell.tsx:192-203`): Farbfleck 10×8 px, Radius 1 px, Name 12 px in `--text-3`,
    rechts ausgerichtet, umbrechend. Kommentar `ReportShell.tsx:184-190` nennt die
    Begruendung: die Zuordnung lag vorher allein in der Farbe, „wer die Reihenfolge nicht
    kennt, muss raten" - und `Card.tsx:24-25`: `truncate` gilt nur fuer Text, eine Legende
    soll umbrechen statt zu verschwinden.
    Bild: `stackedBars(data.summary.buckets, SOURCES)` (`EvReport.tsx:31` ->
    `reports/charts.ts:52-89`). Gestapelte Balken, `stack: "total"`,
    `barCategoryGap: "35%"`, oberstes Segment mit `borderRadius [2,2,0,0]`; x = `bucket.label`
    als Kategorie, Beschriftungen 10 px mono, `interval: "auto"` ab mehr als 12 Buckets,
    `hideOverlap`; y mit Namen „kWh", 10 px, `splitNumber: 3`, Rasterlinie
    `rgba(255,255,255,.09)`; Gitter `left 48, right 12, top 24, bottom 30`;
    `animation: false`. Zeiger `axis` mit Schatten und einem Zettel, der jede Reihe ungleich
    Null **und eine Summenzeile** „Summe x kWh" zeigt (`charts.ts:58-73`). Leere Buckets
    bleiben 0 (`:81-84`).
    Drei Reihen, in dieser Reihenfolge (`EvReport.tsx:14-18`):
    „aus PV" `C.pv` = **#F2A900** · „aus Batterie" `C.battery` = **#7FA3B3** · „aus Netz"
    `C.grid` = **#E0533D** (`components/charts/palette.ts:35-37`). Der Kommentar dort
    (`palette.ts:9-31`) nennt die Pruefung: CIEDE2000 gegen `--surface-2` #123544, das
    schlechteste Paar dieser Dreiergruppe ΔE 20,8 normal / 15,1 bei Farbfehlsichtigkeit;
    `#5C8FA3` fuer die Wallbox wurde ausdruecklich **verworfen** (nur ΔE 7,5 zum Strompreis).
    DATEN: `summary.buckets[].totals.ev_pv_kwh / ev_battery_kwh / ev_grid_kwh`.

  * **Karte „Ladevorgänge"** (`EvReport.tsx:52-90`)
    Zweite Reihe, `--cols: "8fr 4fr"` - die Tabelle links, der Spannenstreifen rechts
    (`:52`). Karte `padding: 16, maxHeight: 320`; Rollbereich `mt-2 min-h-0 flex-1
    overflow-auto` (`:56`).
    Kartenkopf rechts: `sessions.length ? "${n} im Zeitraum" : "keine im Zeitraum"` (`:54`).
    Tabelle 12 px, Kopfzeile **klebt** (`sticky top-0`, Flaeche `var(--surface-2)`), Kopftexte
    `kicker` 10 px, linksbuendig bzw. die Zahlenspalten rechts (`:57-67`). Rumpf in mono,
    Zeilen durch `border-t border-line-1` getrennt (`:69,73`).
    Sieben Spalten, woertlich und in dieser Reihenfolge:
    „Beginn" (`fmtDay(start)` + Leerzeichen + `fmtTime(start)`, also „Di., 10.11. 18:42" -
    `toLocaleDateString("de-DE", {weekday:"short", day:"2-digit", month:"2-digit"})` und
    `{hour:"2-digit", minute:"2-digit"}`, `:20-21`, `:74`) ·
    „Dauer" (gerechnet aus `end - start` in Minuten, mindestens 1, als „3 h 05 min" ab 60
    Minuten, sonst „42 min", in `--text-3`, `:71,75`) ·
    „Energie" (`de1(kwh)` + „ kWh", `:76`) ·
    „Ø Leistung" (`de1(avg_kw)` + „ kW", in `--text-3`, `:77`) ·
    „Sonnenanteil" (`pct(pv_share)`, **in `var(--amber)`**, `:78`) ·
    „Netz" (`de1(grid_kwh)` + „ kWh", `:79`) ·
    „Bezahlt" (`eur(cost_eur)`, **`var(--alert)` wenn `cost_eur > 0.005`, sonst
    `var(--text-3)`**, `:80`).
    Sortierung: **absteigend nach `start`**, neueste zuerst (`:32`).
    Leer: `<Note>Keine Ladevorgänge im gewählten Zeitraum.</Note>`, mittig, `py-8` (`:88`);
    `Note` ist 12 px, `--text-3`, `max-w-[90ch]` (`ReportShell.tsx:143-145`, Begruendung
    `:136-141`: ueber die ganze Breite eines 1440er Schirms wurden es 200 Zeichen je Zeile).
    DATEN: `data.sessions[]` mit `start`, `end`, `kwh`, `pv_share`, `grid_kwh`, `cost_eur`,
    `avg_kw`.

  * **Karte „Wallbox im Überblick"** (`EvReport.tsx:91-100` -> `reports/PeriodStrip.tsx:32-93`)
    Rechte Spalte derselben Reihe. Zeilen = Groessen, Spalten = Tag · Woche · Monat · Jahr
    **des Ankertags** (`PeriodStrip.tsx:21-27`). Karte `padding: "14px 18px"`, `gap: 10`;
    Tabelle 12 px, `table-layout: fixed`, erste Spalte 34 %, Kopfzeile `kicker` 10 px, Zahlen
    rechts in mono, erste Zeile halbfett (`fontWeight: 600`), Zeilentrenner `border-line-1`
    (`:67-91`).
    Spaltenkopf der Tagesspalte heisst nur „Heute", wenn der Anker heute ist, sonst „10.11."
    (`:11-16`); rechts im Kartenkopf „jeweils bis jetzt" bzw. „jeweils bis 10.11.2026"
    (`:34-38`).
    Vier Zeilen woertlich (`EvReport.tsx:94-99`):
    „Geladen · kWh" (`de1`, **ohne Nachkommastelle ab 100 kWh**), Ton `mist` ·
    „Sonnenanteil" (`pct((ev_pv+ev_battery)/ev_kwh)`), Ton `amber` ·
    „Bezahlt" (`eur(ev_cost_eur)`), Ton `ember` ·
    „Ladevorgänge" (`String(sessions.length)`), ohne Ton.
    Toene: `amber -> var(--amber)`, `ember -> var(--alert)`, `mist -> var(--mist)`
    (`PeriodStrip.tsx:19`). Fehlt eine Spanne, steht „-" (`EvReport.tsx:33`).
    DATEN: vier Antworten von `api.energyEv` zum selben Anker (`useReport.ts:55-77`,
    `Promise.allSettled`, eine fehlgeschlagene Spanne fehlt nur als Spalte).

  * **`CoverageNote`** (`EvReport.tsx:102` -> `ReportShell.tsx:163-174`)
    Zugeklappte Karte, Titel „Wie gerechnet wird" (`ui/Methode.tsx:18-29`).
    **Immer sichtbar** als `kurz` im `summary`: „Datenabdeckung 61 %" (oder „noch keine
    Messdaten im Zeitraum") `· Aufzeichnung seit 10.11.2026`
    (`ReportShell.tsx:165-168`). Im Rumpf zwei Absaetze: erst `extra` woertlich
    „Ein Ladevorgang beginnt ab 0,3 kW Wallboxleistung und endet nach 5 Minuten Pause;
    Vorgänge unter 0,2 kWh werden nicht gezählt.", dann `meta.estimated_note_de`
    (`EvReport.tsx:102`, `ReportShell.tsx:169-172`).
    Masse: `summary` `padding: 14px 18px`, `gap: 14px`, Kicker 13 px; `methode-kurz` 12,5 px
    `--text-3`; Pfeil 7×7 px, dreht sich beim Oeffnen; Absaetze 13 px, `line-height 1.55`,
    `max-width: 90ch` (`globals.css:726-736`).
    Kommentar `ui/Methode.tsx:11-13` - das Entscheidende fuer den Umbau: „Hinein gehoert, wie
    eine Zahl entsteht und was sie nicht sagt. Nicht hinein gehoert, was eine Zahl *an diesem
    Tag* einschraenkt - eine fehlende Linie, eine Luecke, ein laufender Tag. Das steht neben
    der Zahl, denn zugeklappt waere es verschwiegen."

  * **Die Handy-Fassung** (`styles/handy.css`, Grenze `max-width: 720px`; dieselbe Grenze als
    Skript in `lib/useIsMobile.ts:6`, dazu `max-height: 560px` fuer das Querformat `:15`)
    Keine Regel nennt diese Route (gesucht nach `wallbox`, `Ladevorgang`, `ev-`: kein
    Treffer). Was greift:
    - Kopf: `.report-header` verliert Rahmen, Flaeche und Glas, `padding: 4px 0 0`
      (`handy.css:137`); die Marke und die Reiter des Kopfes werden ausgeblendet
      (`:139-140`), der **Bereichsname** erscheint mit 26 px halbfett (`:141`).
      `.report-header-right { display: contents }` loest den Rahmen auf (`:148`): der
      Datumskasten steht neben dem Bereichsnamen (`order: 1`), die Spannen als eigene
      Zeile darunter (`order: 3`), alles andere dazwischen (`:149-151`). Kasten und Spannen
      ohne Rahmen, Radius 11 px, Flaeche `rgba(255,255,255,.07)`, `min-height: 40px`;
      Knoepfe mindestens 34 px, 13,5 px Schrift (`:155-161`). Der **lange** Anker wird
      versteckt, der **kurze** gezeigt (`:159-160`) - „Di., 10.11." statt „Dienstag,
      10.11.2026" (`ReportShell.tsx:51-58`).
    - Reiter: rollbare Pillenreihe ueber den Seitenrand hinaus, aktive Pille `--text-1` auf
      Dunkel (`:163-174`). Der Seitenkicker ist hier unsichtbar (`AreaNav.tsx:96`, `md:block`).
    - Karten: **kein Rand**, Radius 16 px, `padding: 16px`; der Kartentitel ist **keine
      Sperrschrift** mehr, sondern 16,5 px Sans halbfett in `--text-1`; das Beiwerk rechts
      bricht in eine eigene Zeile um, 13 px (`:182-185`).
    - Kennzahlen: aus sechs Rahmen wird **eine Flaeche** - `.kpi-grid` bekommt selbst
      `background: var(--surface-2)`, Radius 16 px, `padding: 4px 16px`, zwei Spalten, und
      die Kacheln darin verlieren Flaeche und Radius und werden durch Haarlinien getrennt
      (`:197-199`). **Die erste Kachel fuehrt**: ganze Breite, Zahl **48 px**,
      `letter-spacing: -.04em`, Einheit 18 px, Kontextzeile 14,5 px in `--text-2`
      (`:199,204-205,207`). Die uebrigen Zahlen 25 px, Einheit 13,5 px, Kicker 11 px
      gesperrt 0.1em, Kontextzeile 13 px (`:201-203,206`). Bleibt am Ende eine Kachel allein
      in der Zeile, nimmt sie die ganze Breite (`:200`).
      Fuer diese Seite heisst das: „Geladen" fuehrt in 48 px, die fuenf anderen stehen
      zweispaltig darunter (6 Kacheln, 1 + 5 -> die letzte nimmt die ganze Zeile, `:200`).
    - Kleine Schrift eine Stufe groesser, nur im Rumpf: 10->11, 11->12, 12->13,5, 13->14,5
      (`:205-209` i. e. `handy.css:189-192`, Begruendung `:187-188`: „Am Rechner liest man 12
      Punkt aus sechzig Zentimetern, am Handy aus dreissig, aber im Gehen."). Das trifft die
      ganze Ladevorgangstabelle (12 px -> 13,5 px) und ihre Kopfzeile (10 px -> 11 px).
    - Reihen: `.report-row` eine Spalte (`globals.css:350`), `gap: 14px` (`handy.css:209`).
      Die Tabelle und der Spannenstreifen stehen also untereinander, Tabelle zuerst.
    - Methode: `summary` `padding: 15px 16px`, Titel 15 px Sans halbfett (keine Sperrschrift),
      `kurz` 13 px, Rumpf `padding: 0 16px 16px`, Absaetze 14,5 px (`:213-218`).
    - **Spannenstreifen am Handy ist eine andere Ansicht, nicht dieselbe in einer Spalte**
      (`PeriodStrip.tsx:42-64`, Stile `handy.css:291-299`): statt vier Zahlenspalten ein
      Reihenschalter aus vier Pillen (`.spannen`, Radius 11 px, Flaeche
      `rgba(255,255,255,.07)`; aktive Pille `--amber` auf `--petrol`, 13,5 px) und darunter
      eine `<dl>`-Liste: Name 14,5 px in `--text-2`, Wert 16 px mono, Haarlinie zwischen den
      Zeilen, erste Zeile halbfett. Begruendung im Kommentar `PeriodStrip.tsx:28-30`: „Vier
      Zahlenspalten neben dem Namen der Zeile passen nicht auf 390 Punkte: die Namen wurden
      abgeschnitten, die Zahlen liefen ineinander."

LUECKEN

  [traegt-die-seite] Das Hauptdiagramm fehlt ganz. „Geladene Energie nach Herkunft" ist die
  einzige Stelle, die zeigt, **wann** und **woraus** geladen wurde (`EvReport.tsx:46-51`);
  die App hat auf dieser Seite kein einziges Bild (`StromSeite.swift:281-337`). Ohne es sagt
  die Seite nur Summen.

  [traegt-die-seite] Die Batterie als Quelle der Ladung kommt in der App nicht vor.
  `ev_battery_kwh` traegt in der Vorlage eine Diagrammreihe (`EvReport.tsx:16`), den
  Sonnenanteil (`:28`) und einen Kachelhinweis (`:40`). In der App wird das Feld nirgends
  gelesen (`Schema.swift:3001` vorhanden; `grep -rn evBatteryKwh apps/ios/DuckCurveHome`:
  kein Treffer). „aus der Sonne" + „aus dem Netz" ergibt deshalb nicht `evKwh`, und die
  Differenz steht nirgends.

  [traegt-die-seite] Die Kennzahl „Sonnenanteil" fuer den Zeitraum fehlt. Sie ist die zweite
  Kachel der Vorlage (`EvReport.tsx:40`), `(ev_pv + ev_battery) / ev_kwh`. Die App hat einen
  Sonnenanteil nur **je Ladevorgang** in der Tabelle (`StromSeite.swift:300-303`, Feld
  `pvShare` `Schema.swift:3241` i. e. `:3237-3241`) - eine andere Zahl mit demselben Namen.

  [traegt-die-seite] „Wallbox im Überblick" fehlt ganz: vier Groessen × vier Spannen zum
  selben Anker (`EvReport.tsx:91-100`). Damit fehlt die einzige Einordnung der Seite - ob 12
  kWh an diesem Tag viel sind, sagt nur der Monat daneben. Die App holt genau eine Spanne
  (`StromSeite.swift:284-285`).

  [traegt-die-seite] Die Kennzahl „Effektiv je kWh" in ct fehlt
  (`(ev_cost_eur + ev_opportunity_eur) / ev_kwh * 100`, `EvReport.tsx:30,44`). Sie ist die
  einzige Zahl, die Bezahltes und Entgangenes zusammenrechnet - also die Antwort auf „was
  kostet eine Ladung wirklich".

  [spuerbar] Die Tabelle nennt den Tag nicht. Zeilenname ist „18:42 – 21:05"
  (`StromSeite.swift:293-295`); die Vorlage schreibt „Di., 10.11. 18:42" (`EvReport.tsx:74`).
  Bei Spanne Woche, Monat oder Jahr stehen in der App mehrere Zeilen mit derselben
  Beschriftung untereinander, und `Tabelle` nimmt `zeilennamen` ohne Entwirrung
  (`Bericht.swift:231`, `id: \.offset`).

  [spuerbar] Spalte „Dauer" fehlt (`EvReport.tsx:75`, gerechnet aus `end - start`, mindestens
  1 Minute, „3 h 05 min" / „42 min"). Die App zeigt stattdessen das Ende im Zeilennamen -
  wer wissen will, wie lange geladen wurde, muss subtrahieren.

  [spuerbar] Keine Sortierung. Die Vorlage sortiert **absteigend nach `start`**, neueste
  zuerst (`EvReport.tsx:32`); die App nimmt die Reihenfolge der Antwort
  (`StromSeite.swift:293`).

  [spuerbar] Die Toene der Kacheln fehlen oder sind falsch. Vorlage: „Geladen" `mist`,
  „Sonnenanteil" `amber`, „Aus dem Netz" `ember`, „Bezahlt" `ember`, „Entgangene Vergütung"
  `muted` (`EvReport.tsx:39-43`). App: „geladen" `Farbe.wallbox` = **0x5C8FA3**
  (`StromSeite.swift:318`, `Marken.swift:91`) statt `mist` = 0x7FA3B3; „aus dem Netz" und
  „Kosten" in `Farbe.text1` statt Alarmrot; „entgangene Einspeisung" in `Farbe.text1` statt
  `text3`. Die Zuordnung Ton -> Farbe ist im Kern schon da (`Gestalt/Farben.swift:98-107`).

  [spuerbar] Die Kontextzeilen der Kacheln fehlen - fuenf von sechs. Es fehlen
  „N Ladevorgänge" (`EvReport.tsx:39`), „PV x · Batt. y kWh" (`:40`),
  „Ø x ct/kWh bezahlt" bzw. „kein Netzbezug" (`:41`), „Netzanteil × Strompreis" (`:42`),
  „nicht eingespeister PV-Strom" (`:43`). Die App hat eine einzige, und die mit anderem
  Wortlaut (`StromSeite.swift:333-334`).

  [spuerbar] Farbige Zellen in der Tabelle fehlen: „Sonnenanteil" in `var(--amber)`,
  „Bezahlt" in `var(--alert)` sobald mehr als 0,005 € bezahlt wurden, sonst `--text-3`
  (`EvReport.tsx:78,80`). `Tabelle` kann das schon (`Bericht.swift:169` `farben: [Color?]`,
  Begruendung `:163-168`), die Seite nutzt es nicht.

  [spuerbar] Der Kartenkopf rechts fehlt: „N im Zeitraum" / „keine im Zeitraum"
  (`EvReport.tsx:54`). `Karte` hat das Feld (`Gestalt/Karte.swift:19` `beiwerk`), die Seite
  uebergibt es nicht (`StromSeite.swift:288`).

  [spuerbar] Die Methode verschweigt die Datengrundlage. Der Vorlage steht **immer sichtbar**
  „Datenabdeckung x % · Aufzeichnung seit …" im Deckel (`ReportShell.tsx:163-168`); die App
  uebergibt kein `kurz:` (`StromSeite.swift:314`). `Methode` hat das Feld samt Begruendung
  (`Bericht.swift:336-343`), `StromSeite` macht es auf derselben Seite richtig
  (`StromSeite.swift:37-43,52-56`), und der Kern hat den Satz fertig
  (`DuckCurveKit/Zustand/Waermeuebersicht.swift:331-338`).

  [spuerbar] Der Satz, der sagt, was ein Ladevorgang ist, fehlt: „Ein Ladevorgang beginnt ab
  0,3 kW Wallboxleistung und endet nach 5 Minuten Pause; Vorgänge unter 0,2 kWh werden nicht
  gezählt." (`EvReport.tsx:102`). Ohne ihn ist die Zahl „4 Ladevorgänge" nicht pruefbar.
  Dafuer hat die App einen Satz, den die Vorlage hier nicht hat („Die Herkunft der Ladung ist
  gerechnet…" steht in der App bei der **Speicher**seite, `StromSeite.swift:246-249`).

  [spuerbar] Der Seitenkicker „Ladungen · Herkunft · Kosten" fehlt (`EvReport.tsx:36`,
  gezeichnet in `AreaNav.tsx:96`, ab `md`). In der App tragen die Reiter keinen Kicker
  (`Bereiche.swift:111` hat kein solches Feld), und die Seite setzt stattdessen den Kicker
  „Wallbox" ueber das Kachelfeld (`StromSeite.swift:287`) - ein Wort, das der aktive Reiter
  schon sagt. Die Vorlage hat ueber dem KPI-Raster **keinen** Kicker.

  [klein] Die Kachelauswahl weicht in einer Stelle ab: die App macht aus dem Hinweis „N
  Ladevorgänge" eine eigene Kachel (`StromSeite.swift:319`) und verliert dafuer „Effektiv je
  kWh". In der Vorlage steht die Zahl der Vorgaenge dreimal, aber nie als Kachel
  (Hinweis `:39`, Kartenkopf `:54`, Streifenzeile `:98`).

  [klein] Wortlaute: „entgangene Einspeisung" gegen „Entgangene Vergütung"; der Hinweis „was
  die Sonnenkilowattstunden im Netz gebracht hätten" gegen „nicht eingespeister PV-Strom";
  „Kosten" gegen „Bezahlt"; „mittlere Leistung" gegen „Ø Leistung"; „kWh" als Spaltenname
  gegen „Energie"; Leersatz „In diesem Zeitraum wurde nicht geladen." gegen „Keine
  Ladevorgänge im gewählten Zeitraum."

  [klein] Spaltenreihenfolge der Tabelle: Vorlage Beginn · Dauer · Energie · Ø Leistung ·
  Sonnenanteil · Netz · Bezahlt (`EvReport.tsx:60-66`); App kWh · Sonnenanteil · Netz ·
  Kosten · mittlere Leistung (`StromSeite.swift:296-311`). Am Telefon entscheidet diese
  Reihenfolge, welche Spalte zuerst sichtbar ist (`Bericht.swift:213-227`, `gezeigt = 0`).

  [klein] Masse des Diagramms, wenn es kommt: Vorlage Karte 280 pt hoch mit Legende **im
  Kartenkopf rechts** (`EvReport.tsx:47-48`); `Balkenbild` ist 180 pt hoch und setzt die
  Legende **ins Bild**, oben links (`Bericht.swift:81,120`).

  [klein] Tabelle ohne Rollbereich und ohne klebende Kopfzeile: Vorlage `maxHeight: 320` mit
  `overflow-auto` und `sticky top-0` (`EvReport.tsx:53,56,58`); in der App waechst die Karte
  mit der Zahl der Vorgaenge.

  [klein] „Geladen · kWh" im Spannenstreifen rundet ab 100 kWh auf ganze Zahlen
  (`EvReport.tsx:95`) - eine Jahresspalte zeigt „1.284" und nicht „1.284,3".

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Api.energieWallbox(_ zeitraum: String, anker: String) async throws -> EvReportOut`,
    `GET /energy/ev` mit `period` und `anchor`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:196-198`).
  * `EvReportOut { summary: EnergySummaryOut, sessions: [EvSessionOut] }`
    (`Modelle/Schema.swift:3221-3235`).
  * `EvSessionOut { start, end, kwh, pvShare?, gridKwh, costEur, avgKw }` mit den Schluesseln
    `pv_share`, `grid_kwh`, `cost_eur`, `avg_kw` (`Modelle/Schema.swift:3237-3276`). **Alle
    sieben Felder, die die Tabelle der Vorlage braucht, sind da** - auch `start`/`end` als
    ISO-Zeichenketten fuer Tag und Dauer.
  * `EnergySummaryOut { period, anchor, start, end, totals, buckets, meta }`
    (`Modelle/Schema.swift:2942-2971`); `EnergyBucketOut { start, end, label, totals }`
    (`:2810-2830`) - `label` ist die fertige Achsenbeschriftung.
  * `EnergyTotalsOut` mit `evKwh` (`:2984`), `evPvKwh` (`:3000`), **`evBatteryKwh` (`:3001`)**,
    `evGridKwh` (`:3002`), `evCostEur` (`:3007`), `evOpportunityEur` (`:3008`); Schluessel
    `ev_kwh`, `ev_pv_kwh`, `ev_battery_kwh`, `ev_grid_kwh`, `ev_cost_eur`,
    `ev_opportunity_eur` (`:3034,3050-3052,3057-3058`). Alle wahlfrei.
  * `EnergyMetaOut { batteryCapacityKwh, feedInCtKwh, dataSince?, coverage?, estimatedNoteDe }`
    (`:2832-2860`).
  * `Waermeuebersicht.abdeckungssatz(_ m: EnergyMetaOut) -> String` baut genau die Zeile
    „Datenabdeckung x % · Aufzeichnung seit …" bzw. „noch keine Messdaten im Zeitraum"
    (`Zustand/Waermeuebersicht.swift:331-338`). Nur der Trennwert weicht ab: der Kern nimmt
    `Tag.kurz` („Mo, 10.11."), die Vorlage das lange Datum („10.11.2026",
    `ReportShell.tsx:165`) - `StromSeite.swift:41` nimmt `Tag.lang`.
  * `Spanne: CaseIterable` mit `rawValue` und `name` (`Formate/Zeitraum.swift:9-34`); das
    Muster „alle vier Spannen zum selben Anker holen" steht fertig in
    `WaermeSeite.swift:48-62` (`withTaskGroup`, `try?` je Spanne), die Tabelle dazu in
    `WaermeSeite.swift:313-321` und die Zeilenfunktion im Kern
    (`Zustand/Waermeuebersicht.swift:280-301`).
  * `Formate`: `zahl(_:stellen:)` (`Formate/Formate.swift:44`), `kwh` (`:75`), `prozent`
    (`:81`, rundet wie `pct`), `ct` (`:93`), `euro` (`:99`), **`dauer(minuten:)` -> „45 min" /
    „3 h 20 min"** (`:105-116`), `hhmm(iso:)` (`:131`); `Tag.kurz` „Sa, 7.11."
    (`Formate/Tag.swift:94-98`), `Zeit.ausIso` (`Formate/Zeit.swift:28`).
  * Farben: `Marken.pv` = amber 0xF2A900 (`Gestalt/Marken.swift:50,13`),
    `Marken.diagrammSpeicher` = **0x7FA3B3** (`:136`) und `Marken.diagrammNetz` =
    **0xE0533D** (`:132`) - genau die drei Werte von `C.pv`/`C.battery`/`C.grid`
    (`palette.ts:35-37`). Der Kommentar `Marken.swift:117-129` nennt denselben Grund wie die
    Vorlage. Als SwiftUI-Farbe: `Farbe.pv`, `Farbe.diagrammSpeicher`, `Farbe.diagrammNetz`
    (`DuckCurveHome/Gestalt/Farben.swift:54,77,79`); Toene ueber
    `Farbe.ton(_ :Kennzahl.Ton)` (`:98-107`): `nebel -> mist`, `bernstein -> amber`,
    `gedaempft -> text3`.
  * Bausteine: `Berichtsseite` (`Seiten/Bericht.swift:15-64`), `Balkenbild` gestapelt mit
    `BarMark(stacking: .standard)` und Legende (`:70-149`), `Tabelle` mit Farbspalten und
    Handyliste (`:157-327`), `Methode` mit `kurz:` (`:334-397`), `Kachelfeld`/`Kachel`/
    `Kacheldaten` (`Gestalt/Karte.swift:121-343`), `Karte` mit `beiwerk` (`:15-113`), `Leer`
    (`:390-404`), `Achse.beschriftungen` (`Zustand/Achse.swift:16-21`).
  * `Kennzahl` mit `Ton` (`Zustand/Kennzahl.swift:15-52`) und `Kacheldaten.init(_ k: Kennzahl)`
    (`Gestalt/Karte.swift:136-138`) - der Weg, auf dem eine Kachelauswahl aus dem Kern kommt.

ES FEHLT

  1. **`Wallboxkacheln`** - die sechs Kennzahlen der Vorlage als `[Kennzahl]`, damit die
     Auswahl und die drei abgeleiteten Groessen geprueft werden koennen. Neue Datei
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Wallbox.swift`, Vorbild
     `Zustand/Waermeuebersicht.swift`.
     `public static func kacheln(_ b: EvReportOut) -> [Kennzahl]` rechnet
     `sonnenanteil = (evPvKwh + evBatteryKwh) / evKwh` (nur `evKwh > 0`),
     `bezahltCt = evCostEur / evGridKwh * 100` (nur `evGridKwh > 0.01`),
     `effektivCt = (evCostEur + evOpportunityEur) / evKwh * 100` (nur `evKwh > 0.01`)
     und setzt die Toene `.nebel`, `.bernstein`, `.gedaempft` wie `EvReport.tsx:39-44`.
     Die drei Schwellen sind Verhalten, nicht Darstellung - sie gehoeren geprueft.

  2. **`Wallbox.spannenzeilen(_ je: [Spanne: EvReportOut]) -> [(wort: String, werte: [String])]`**
     in derselben Datei, vier Zeilen wie `EvReport.tsx:94-99`, samt der Sonderregel
     „ab 100 kWh ohne Nachkommastelle" (`:95`). Genaues Vorbild:
     `Zustand/Waermeuebersicht.swift:280-301`.

  3. **`Wallbox.vorgaenge(_ b: EvReportOut, jetzt: Date) -> [Vorgangszeile]`** - die
     Ladevorgaenge sortiert (absteigend nach `start`, `EvReport.tsx:32`) und fertig
     formatiert: `beginn` („Di., 10.11. 18:42" aus `Tag.kurz` + `Formate.hhmm(iso:)`),
     `dauer` (`Formate.dauer(minuten:)` aus `Zeit.ausIso(end) - Zeit.ausIso(start)`,
     mindestens 1 Minute), `energie`, `leistung`, `sonnenanteil`, `netz`, `bezahlt` und ein
     `bezahltAuffaellig: Bool` (`costEur > 0.005`, `EvReport.tsx:80`). Die Dauer und die
     Sortierung sind Rechnung, nicht Anordnung.

  4. **`Formate.ct`** liefert „12,3 ct/kWh" (`Formate/Formate.swift:93-96`). Fuer die Kachel
     „Effektiv je kWh" braucht es den Wert **ohne** Einheit, weil die Einheit „ct" als
     eigenes Feld der Kachel steht (`EvReport.tsx:44`: `unit="ct"`). Entweder
     `Formate.zahl(_, stellen: 1)` benutzen oder `Formate.ct(_:mitEinheit:)` ergaenzen -
     keine neue Funktion erfinden, bevor das entschieden ist.

  5. **Ein Baustein `Spannenstreifen`** in `apps/ios/DuckCurveHome/Bausteine/`, weil die
     Vorlage ihn auf **sieben** Berichtsseiten benutzt (nachgesehen:
     `grep -rln "PeriodStrip" apps/web/src/components` trifft `HouseReport.tsx`,
     `PvReport.tsx`, `EvReport.tsx`, `PvAccounting.tsx`, `BatteryReport.tsx`,
     `CostReport.tsx`, `HeatOverview.tsx`). Zeilen + Spaltenkoepfe, Tagesspalte
     „Heute“ nur wenn der Anker heute ist (`PeriodStrip.tsx:11-16`), Kopfzeile rechts
     „jeweils bis …“ (`:34-38`), am Telefon Pillenschalter + Liste (`:42-64`). `Tabelle`
     allein reicht nicht: ihr fehlen der Spaltenkopf fuer die erste Spalte, die Tagesregel
     und der Hinweis „jeweils bis …“.

BAUPLAN

  1. `DuckCurveKit/Sources/DuckCurveKit/Zustand/Wallbox.swift` **neu**: `Wallbox.kacheln`,
     `Wallbox.spannenzeilen`, `Wallbox.vorgaenge`, `Wallbox.Vorgangszeile`,
     `Wallbox.methodensaetze` (der Satz zur Definition eines Ladevorgangs, `EvReport.tsx:102`)
     und `Wallbox.abdeckung` (oder `Waermeuebersicht.abdeckungssatz` dorthin umziehen - sie
     steht heute an einem Ort, der nur die Waerme nennt,
     `Zustand/Waermeuebersicht.swift:331-338`).
  2. Tests im Kern dazu: die drei Schwellen (`evKwh > 0`, `> 0.01`, `evGridKwh > 0.01`), die
     Sortierung, die Mindestdauer von einer Minute, die 100-kWh-Rundung.
  3. `DuckCurveHome/Bausteine/Spannenstreifen.swift` **neu** (Punkt 5 oben).
  4. `DuckCurveHome/Seiten/Energie/StromSeite.swift`, `WallboxSeite` (`:281-337`) umbauen -
     in der Reihenfolge der Vorlage:
     a. Abfrage: zusaetzlich alle vier Spannen zum Anker holen, Muster
        `WaermeSeite.swift:48-62`; ein eigener `Wallboxdaten`-Verbund wie
        `WaermeSeite.swift:14-19`.
     b. Kachelfeld: `Wallbox.kacheln(...).map(Kacheldaten.init)`, **ohne** den Kicker
        „Wallbox" (`:287`), mit den Kontextzeilen und den Toenen der Vorlage.
     c. Karte „Geladene Energie nach Herkunft" **neu**, `Balkenbild` mit drei Stuecken aus
        `b.summary.buckets`: „aus PV" `Farbe.pv`, „aus Batterie" `Farbe.diagrammSpeicher`,
        „aus Netz" `Farbe.diagrammNetz`, Felder `evPvKwh`, `evBatteryKwh`, `evGridKwh`.
        Vorbild derselben Form: `StromSeite.swift:111-145` (`herkunft`).
     d. Karte „Ladevorgänge": `beiwerk` mit „N im Zeitraum" / „keine im Zeitraum";
        `Tabelle` aus `Wallbox.vorgaenge` mit sieben Spalten in der Reihenfolge der Vorlage
        und `farben:` fuer „Sonnenanteil" (`Farbe.amber`) und „Bezahlt"
        (`Farbe.alarm` / `Farbe.text3`); Leersatz „Keine Ladevorgänge im gewählten
        Zeitraum."
     e. Karte „Wallbox im Überblick" **neu** mit dem Baustein aus 3.
     f. `Methode` mit `kurz: Wallbox.abdeckung(...)` und zwei Absaetzen: erst der Satz zur
        Definition des Ladevorgangs, dann `meta.estimatedNoteDe` - in dieser Reihenfolge
        (`ReportShell.tsx:169-172`).
  5. Wenn `WallboxSeite` nach dem Umbau ueber hundert Zeilen hat, in eine eigene Datei
     `Seiten/Energie/WallboxSeite.swift` - `StromSeite.swift` traegt heute schon drei Seiten.

WAS SCHWIERIG WIRD

  * **Legende im Kartenkopf statt im Bild.** Die Vorlage setzt die Legende rechts in den
    Kartenkopf (`EvReport.tsx:48`, `ChartLegend` `ReportShell.tsx:192-203`); `Balkenbild`
    setzt sie mit `.chartLegend(position: .top, alignment: .leading, spacing: 6)` ins Bild
    (`Bericht.swift:120`). Swift Charts kennt keine Legende ausserhalb des Diagramms.
    **Der Weg dafuer ist im Projekt aber schon gewaehlt und vielfach gegangen:**
    `Legendenstueck` + `Umbruchzeile` (`Gestalt/Umbruchzeile.swift:3-9` und `:11-67`, ein
    eigenes `Layout`, weil `HStack` hinausschiebt und `LazyVGrid` jedem Stueck dieselbe
    Breite gibt). Genaues Vorbild einer Legende aus wenigen Stuecken:
    `Diagramme/Waermebilder.swift:28-37` (Klotz `RoundedRectangle(cornerRadius: 1.5)`,
    13 pt breit, Hoehe je Stueck, Wort in `Schrift.winzig` / `Farbe.text3`), Stuecke in
    `:210-214`. Zwei Moeglichkeiten: diese Zeile als `Karte(beiwerk:)` in den Kartenkopf
    (`Gestalt/Karte.swift:19,79-81`; keiner der heutigen `beiwerk:`-Aufrufer ist eine
    Legende - nachgesehen in `Seiten/Technik/SystemSeiten.swift:60,457,798,808,1037,1187`,
    `Seiten/Technik/FahrplanSeiten.swift:341,357,409`, `Bausteine/Ausblickkarte.swift:32`:
    es sind Umschalter und Knoepfe), oder die Zeile unter das Bild und
    `.chartLegend(.hidden)` - dann steht sie nicht rechts oben wie in der Vorlage, aber
    aussen.

  * **Der Zettel am Zeiger mit der Summenzeile** (`charts.ts:62-72`: jede Reihe ungleich
    Null plus „Summe x kWh“). Swift Charts kann das nur ueber `chartOverlay` von Hand.
    Nachgesehen: `grep -rn "chartOverlay" apps/ios/DuckCurveHome` trifft **nur**
    `Diagramme/Tageskurve.swift:204` und `:287` (das Fadenkreuz der Tageskurve), in
    `Seiten/Bericht.swift` kein Treffer - `Balkenbild` hat also heute keinen Zeiger. Das
    Vorbild gibt es damit (`Tageskurve.swift:204-206`, `fadenkreuzflaeche`), aber die
    Entscheidung betrifft alle Balkenbilder der App gleichermassen und gehoert nicht in
    diesen Umbau.

  * **Die klebende Kopfzeile und der Rollbereich der Tabelle** (`EvReport.tsx:53,56,58`:
    `maxHeight: 320`, `overflow-auto`, `sticky top-0`). `Tabelle` baut einen `VStack` ohne
    eigene Rollflaeche (`Bericht.swift:282-312`), und eine `ScrollView` in einer `ScrollView`
    ist auf iOS keine gute Idee. Im Projekt gewaehlter Weg bei langen Listen: die Karte
    waechst (`Seiten/Haus/Raumprotokollblatt.swift` nachsehen) bzw. **waagerecht** rollen,
    wie es `StromSeite.swift:236-243` fuer den Pruefungstext tut. Vorschlag: die Hoehe nicht
    begrenzen und die Kopfzeile nicht kleben - und das als Abweichung notieren, nicht
    stillschweigend.

  * **„Beginn" am Telefon.** Am Handy zeigt `Tabelle` eine Spalte, die man umschaltet
    (`Bericht.swift:206-244`), und der Zeilenname ist immer sichtbar. „Di., 10.11. 18:42" als
    Zeilenname ist auf 390 Punkten breit; die Vorlage hat dort dasselbe Problem und loest es
    mit `whitespace-nowrap` plus waagerechtem Rollen des Rollbereichs (`EvReport.tsx:56,74`).
    Vorbild im Projekt fuer die Entscheidung „zwei feste Spalten am Telefon":
    `Bericht.swift:176-184` (`immerSichtbar`, begruendet mit `handy.css:377-379`). Hier waere
    `immerSichtbar: 1` mit kurzem Zeilennamen („10.11. 18:42", `Tag.tagMonat`
    `Formate/Tag.swift:106-111`) der naechste Verwandte.

  * **Zwei Zahlen heissen „Sonnenanteil".** Die Kachel meint `(evPv + evBattery) / evKwh`
    fuer den Zeitraum (`EvReport.tsx:28`), die Tabellenspalte das Feld `pvShare` je Vorgang
    (`Schema.swift:3237-3241`). Die Vorlage nennt beide so und das ist Absicht; beim Umbau
    darf daraus nicht eine Zahl werden.
