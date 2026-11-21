========================= messen:strom   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:16-145`, Gerippe
`apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-50`, Huelle
`apps/ios/DuckCurveHome/App/Seitenwahl.swift:136-168`)

1. Zeitraumleiste - am iPad im Gerippe oberhalb der Rollflaeche
   (`App/Seitenwahl.swift:146-150` -> `:188-207`): links Spannenwahl Tag/Woche/Monat/Jahr
   (`:210-226`), rechts Datumskasten `‹ z.kurz › [HEUTE]` (`:229-291`). Am Telefon zeichnet das
   `HandRahmen`, nicht die Seite. Keine Ueberschrift, kein Kicker (begruendet
   `StromSeite.swift:24`).
2. Kachelfeld mit sechs Kacheln, ohne Kicker (`StromSeite.swift:25`, Daten `:59-95`):
   Verbrauch gesamt / Wärmepumpe / Wallbox / Haushalt (Rest) / Autarkie / Netzbezug.
   Gezeichnet von `Gestalt/Karte.swift:274-343` - am Telefon fuehrt die erste Kachel ueber die
   ganze Breite (48 pt), die uebrigen zweispaltig mit Haarlinien; am iPad alle in zwei Spalten.
3. Karte „Wer hat verbraucht?" mit gestapeltem Balkenbild Wärmepumpe/Wallbox/Haushalt
   (`StromSeite.swift:26-28`, Daten `:110-125`, Baustein `Seiten/Bericht.swift:70-149`,
   Hoehe 180 pt `Bericht.swift:81`).
4. Karte „Woher kam der Strom?" mit gestapeltem Balkenbild Sonne direkt / aus dem Speicher /
   aus dem Netz (`StromSeite.swift:29-31`, Daten `:129-144`).
5. Methode, zugeklappt, Titel „Wie das gerechnet ist" (`StromSeite.swift:32-43`, Baustein
   `Seiten/Bericht.swift:334-397`). Kurzzeile: Abdeckung (`StromSeite.swift:52-56`) ·
   „Aufzeichnung seit <Tag.lang>" (`:41`). Rumpf: der Satz zu „Haushalt (Rest)" (`:34`) und
   `meta.estimatedNoteDe` (`:35`).
6. Fehler als `Stoerung` oberhalb des Inhalts, ohne den Inhalt zu ersetzen
   (`Seiten/Bericht.swift:36-38`, `:410-436`).

Nicht auf der Seite: ein Spannenstreifen und `exportRevenueEur`
(`grep -n "exportRevenueEur\|Überblick\|Ueberblick\|Spannen" StromSeite.swift`: kein Treffer).

VORLAGE: `apps/web/src/app/strom/page.tsx:1-7` -> `apps/web/src/components/reports/HouseReport.tsx:30-85`

  * **Huelle / Kopfzeile** (`reports/ReportShell.tsx:97-134`, darunter
    `layout/AreaShell.tsx:13-30`, `layout/AreaNav.tsx:62-99`)
    `title="Strom"` steht **nicht** sichtbar im Kopf, nur in `<span className="sr-only">`
    (`ReportShell.tsx:127`) und als `metadata.title` „Strom · Duck Curve Home"
    (`app/strom/page.tsx:3`). Begruendung im Code: „Der Titel steht nicht mehr im Kopf: der
    aktive Reiter sagt, wo man ist. Er bleibt im Dokumenttitel, damit ein Browserfenster und die
    Vorlesehilfe ihn haben" (`ReportShell.tsx:99-100`).
    `kicker="Verbrauch · Verbraucher · Herkunft"` (`HouseReport.tsx:42`) geht an `AreaTabs`
    und steht rechts in der Reiterzeile: `className="kicker hidden truncate pb-2.5 md:block"`,
    `fontSize: 11` (`AreaNav.tsx:96`) - also mono, `uppercase`, `letter-spacing .13em`,
    Farbe `--text-kicker` = `--mist` #7fa3b3 (`globals.css:57-64`, `tokens.css:15,35`).
    **Am Handy ausgeblendet** (`hidden ... md:block`, Grenze 768 px).
    Blaetterkasten: `‹` / Anker / `›` und „heute" nur wenn nicht heute
    (`ReportShell.tsx:109-117`); der Anker in zwei Fassungen, lang
    (`anchorLabel`, „Dienstag, 10.11.2026" / „KW 46 · 10.11. - 16.11.2026" / „November 2026" /
    „2026", `ReportShell.tsx:36-49`) und kurz (`anchorKurz`, „Di., 10.11." / „KW 46" /
    „Nov. 2026" / „2026", `:52-58`); am Handy wird auf die kurze umgeschaltet
    (`handy.css:159-160`). Spannenschalter Tag/Woche/Monat/Jahr, aktiv auf `--amber` mit
    Schrift `--petrol` (`ReportShell.tsx:120-126`).
    DATEN: `usePeriod()` haelt Spanne und Anker in `?period=&anchor=` (`ReportShell.tsx:61-95`).

  * **Fehlerband** (`HouseReport.tsx:43` -> `ReportShell.tsx:147-153`)
    Rahmen `rgba(224,83,61,.4)`, Flaeche `rgba(224,83,61,.12)`, Schrift `--alert`, mono,
    12 px, `uppercase`, `letter-spacing .1em`. Text aus `useReport`
    (`useReport.ts:10-13`): bei 401/403 „Nicht angemeldet - bitte Gerät koppeln.", sonst die
    Meldung des Dienstes bzw. „Daten konnten nicht geladen werden."

  * **Sechs Kennzahlkacheln** (`HouseReport.tsx:44-59`, `KpiGrid cols={6}`
    `ReportShell.tsx:176-182`, Kachel `ui/Stat.tsx:4-19`)
    Breit: `grid-template-columns: repeat(auto-fit, minmax(clamp(150px, 100%/6 - 16px, 260px), 1fr))`,
    `gap: 16px` (`globals.css:107`) - auf Wandbreite **eine Reihe zu sechs**. Karte
    `padding: "14px 18px"`, `gap: 6` (`Stat.tsx:7`), Flaeche `--surface-2` #123544, Haarlinie
    `--line-1`, Radius `--radius-2` = 3 px (`globals.css:67-76`, `tokens.css:24,27,93`).
    Wort: `.kicker` mit `fontSize: 11` (`Stat.tsx:8`). Zahl: mono 26 px,
    `leading-none`, `tracking-[-.02em]` (`Stat.tsx:9`). Einheit: 13 px, `--font-sans`,
    `--text-3` (`:11`). Kontextzeile: 12 px, `line-height 1.35`, `--text-3`, **zwei Zeilen
    hoechstens** (`line-clamp-2`), bei Verweis ein amberfarbenes `›` davor (`:16`).
    Begruendung im Code: „Abgeschnitten (‚von 0,0 kWh Netzladung i…') ist sie nutzlos, und der
    gewonnene Platz war nie das Problem. Zwei Zeilen sind das Maximum, damit die Kacheln in
    einer Reihe gleich hoch bleiben" (`Stat.tsx:13-15`).
    Die sechs woertlich, in dieser Reihenfolge:
      1. „Verbrauch gesamt" · `de1(totals.house_kwh)` · „kWh" · dazu
         `${Math.round(minutes/60)} h bewertet`, bei `minutes` falsy „keine Daten" (`:45`)
      2. „Wärmepumpe" · `de1(heat_pump_kwh)` · „kWh" · dazu `share()` = „NN % des Verbrauchs"
         (`:46`, `share` in `:38`)
      3. „Wallbox" · `de1(ev_kwh)` · „kWh" · `tone="mist"` = `--mist` #7fa3b3 · dazu `share()` (`:47`)
      4. „Haushalt (Rest)" · `de1(base_kwh)` · „kWh" · `tone="muted"` = `--text-3` · dazu `share()` (`:48`)
      5. „Autarkie" · `pct(autarky)` · ohne Einheit · `tone="amber"` · dazu
         `${de1(pv_direct_kwh + battery_to_house_kwh)} kWh ohne Netz` (`:49`)
      6. „Netzbezug" · `eur(import_cost_eur)` · `tone="ember"` = `--alert` #e0533d ·
         `href="/geld/rechnungen"` **nur fuer den Hausherrn**, `ariaLabel` „Netzbezug - zur
         Rechnungsprüfung" · dazu `${de1(import_kwh)} kWh` plus „ · Rechnungen prüfen" nur fuer
         den Hausherrn (`:51-58`). Kommentar daneben: „Kosten sehen alle; nur der Weg zur
         Rechnungsprüfung bleibt dem Hausherrn" (`:50`).
    Formate: `de1` = `toLocaleString("de-DE")` mit einer Stelle, `null` -> „-";
    `eur` = zwei Stellen + „ €"; `pct` = `Math.round(frac*100)` + „ %" (`ReportShell.tsx:14-16`).
    Rolle: `useRole()` (`lib/live/useRole.ts:10-31`) - bis zur Antwort gilt „owner".
    DATEN: `api.energySummary(period, anchor)`, geholt von `useReport`
    (`HouseReport.tsx:33`, `useReport.ts:18-46`; alle 5 min neu, der alte Stand bleibt beim
    Wechsel stehen). Felder: `totals.house_kwh`, `heat_pump_kwh`, `ev_kwh`, `base_kwh`,
    `autarky`, `pv_direct_kwh`, `battery_to_house_kwh`, `import_cost_eur`, `import_kwh`,
    `minutes`.

  * **Zwei Diagrammkarten nebeneinander** (`HouseReport.tsx:62-71`)
    `<div className="report-row" style={{"--cols": "1fr 1fr"}}>` -> `display: grid`,
    `gap: 16px`, zwei gleiche Spalten (`globals.css:108`). Jede Karte
    `style={{padding: 16, height: 280}}`, das Diagrammfeld `min-h-0 flex-1`.
    Kommentar darueber, der die Form begruendet: „Zwei Fragen nebeneinander, jede als Verlauf.
    Daneben stand je ein Ring mit denselben Anteilen, die schon in den Kacheln und im Verlauf
    stehen." (`HouseReport.tsx:60-61`) - die Ringe sind absichtlich weg, nicht vergessen.
    Kartenkopf `CardHead` (`ui/Card.tsx:20-29`): links `h2.kicker`, rechts die Legende.
    `ChartLegend` (`ReportShell.tsx:192-203`): je Reihe ein Farbfleck
    `h-2 w-2.5 rounded-[1px]` plus Name in 12 px `--text-3`, rechtsbuendig, umbrechend.
    Begruendung: „Damit lag die Identität der Flächen allein in der Farbe, und wer die
    Reihenfolge nicht kennt, muss raten." (`ReportShell.tsx:187-190`)
    - Karte 1: Titel „Wer hat verbraucht?", Reihen `CONSUMERS` (`HouseReport.tsx:19-23`):
      `heat_pump_kwh` „Wärmepumpe" `C.heatPump` #e0966b · `ev_kwh` „Wallbox" `C.ev` #2f89b5 ·
      `base_kwh` „Haushalt" `C.house` #cfd8dc (`charts/palette.ts:53,38,43`).
      Der Kommentar darueber ist die Begruendung, die nicht verloren gehen darf: „Die Wärmepumpe
      in ihrer Farbe, wie auf jeder anderen Seite. Sie war hier hell und der Haushalt
      sandfarben; neben dem Orange der Wärmepumpe wäre Sand bei Deuteranopie dieselbe Farbe
      (ΔE 0,2). Der Rest des Hauses ist deshalb hell: schlechtestes Paar ΔE 18,2 normal und 16,2
      deutan (gemessen 10.11.2026 gegen die Kartenfläche)." (`HouseReport.tsx:15-18`)
    - Karte 2: Titel „Woher kam der Strom?", Reihen `SOURCES` (`HouseReport.tsx:24-28`):
      `pv_direct_kwh` **„PV direkt"** `C.pv` #f2a900 · `battery_to_house_kwh` **„aus Batterie"**
      `C.battery` #7fa3b3 · `grid_to_house_kwh` **„aus Netz"** `C.grid` #e0533d.
    Bild: `stackedBars` (`reports/charts.ts:52-89`) - `stack: "total"`, `barCategoryGap: "35%"`,
    oberste Reihe mit `borderRadius [2,2,0,0]`, Werte auf zwei Stellen gerundet, `null` -> 0,
    `animation: false`. Gitter `left 48, right 12, top 24, bottom 30`. x-Achse Kategorie aus
    `bucket.label`, Schrift mono 10 px `rgba(255,255,255,.48)`, bei mehr als 12 Buckets
    `interval: "auto"`, `hideOverlap`. y-Achse Name „kWh", `splitNumber: 3`, Gitterlinie
    `rgba(255,255,255,.09)`.
    **Zeiger:** `tooltip` mit `trigger: "axis"`, `axisPointer: {type:"shadow"}` - er nennt den
    Bucket, dann je Reihe Name und Wert (nur Reihen ungleich 0) und darunter abgesetzt
    „Summe NN,N kWh" (`charts.ts:58-73`).
    DATEN: dieselbe Antwort, Feld `buckets[].totals.*` und `buckets[].label`.

  * **Spannenstreifen „Strom im Überblick"** (`HouseReport.tsx:72-81`, Baustein
    `reports/PeriodStrip.tsx:32-94`)
    Vier Groessen (Zeilen) gegen vier Spannen (Spalten) **desselben Ankertags**. Begruendung im
    Code: „Die Spalten folgen der Navigation. Blättert man auf einen vergangenen Tag, zeigen sie
    dessen Woche, Monat und Jahr - nicht mehr die laufenden." (`PeriodStrip.tsx:22-26`) und im
    Kern dazu: „Der Anker kommt von außen und war vorher fest auf heute verdrahtet. … Zwei
    Zeiträume in einer Ansicht, ohne dass es dastand." (`useReport.ts:48-54`)
    Spaltenkoepfe: „Heute" · „Woche" · „Monat" · „Jahr"; die erste heisst nur „Heute", wenn der
    Anker auch heute ist, sonst „TT.MM." (`PeriodStrip.tsx:9-16`).
    Rechts im Kopf: „jeweils bis jetzt" bzw. „jeweils bis TT.MM.JJJJ" (`:34-38`).
    Zeilen woertlich (`HouseReport.tsx:75-80`):
      „Verbrauch · kWh" - `de1(house_kwh, house_kwh >= 100 ? 0 : 1)`, also **ab 100 ohne
      Nachkommastelle**; erste Zeile fett (`fontWeight: 600`, `PeriodStrip.tsx:84`)
      „Autarkie" - `pct(autarky)`, `tone="amber"`
      „Netzkosten" - `eur(import_cost_eur)`, `tone="ember"` = `--alert`
      „Einspeiseerlös" - `eur(export_revenue_eur)`
    Fehlt eine Spanne, steht „-" (`HouseReport.tsx:39`).
    Breit: Tabelle, `Card style={{padding:"14px 18px", gap:10}}`, 12 px, `table-layout: fixed`,
    erste Spalte 34 %, Zahlen rechtsbuendig mono, Zeilentrenner `border-line-1`
    (`PeriodStrip.tsx:67-92`).
    DATEN: `useMultiPeriod(api.energySummary, anchor)` (`HouseReport.tsx:34`,
    `useReport.ts:55-77`) - vier Abfragen auf einmal mit `Promise.allSettled` ueber
    `ALL_PERIODS`, alle 5 min neu; eine gescheiterte Spanne faellt weg, der Streifen bleibt.

  * **Methodenzeile** (`HouseReport.tsx:82` -> `ReportShell.tsx:163-174` ->
    `ui/Methode.tsx:18-34`)
    Ein `<details class="card methode">`, zugeklappt. Begruendung: „Sechs Seiten endeten mit 150
    bis 210 Wörtern darüber, wie gerechnet wird, immer aufgeklappt. … für jeden Blick danach
    Text, an dem man vorbeirollt." und die Trennung: „Hinein gehört, wie eine Zahl entsteht und
    was sie nicht sagt. Nicht hinein gehört, was eine Zahl *an diesem Tag* einschränkt … Das
    steht neben der Zahl, denn zugeklappt wäre es verschwiegen." (`Methode.tsx:6-13`) Und:
    „Ein `<details>` und kein Zustand: der Browser kann es ohne Skript, die Vorlesehilfe kennt
    es, und die Seitensuche findet seinen Text." (`:15-16`)
    Titel woertlich: **„Wie gerechnet wird"** (`Methode.tsx:18`).
    Kurzzeile, immer sichtbar: `Datenabdeckung NN %` - **bei `coverage == null` statt dessen
    „noch keine Messdaten im Zeitraum"**, klein geschrieben - danach, wenn `data_since` da ist,
    „ · Aufzeichnung seit TT.MM.JJJJ" (`toLocaleDateString("de-DE", {day:"2-digit",
    month:"2-digit", year:"numeric"})`) (`ReportShell.tsx:165-168`).
    Rumpf, in dieser Reihenfolge: `extra` =
    „Haushalt (Rest) = Hausverbrauch ohne Wärmepumpe und Wallbox. Verbraucher erhalten die
    Quellen anteilig an ihrer Leistung je Minute." (`HouseReport.tsx:82`), dann
    `meta.estimated_note_de` (`ReportShell.tsx:171`). Absaetze 13 px, `line-height 1.55`,
    `--text-2`, `max-width: 90ch` (`globals.css:734`). Ohne `meta` erscheint die Karte
    gar nicht (`ReportShell.tsx:164`).

  * **Handy-Fassung, wo sie abweicht** (`apps/web/src/styles/handy.css`, Grenze
    `max-width: 720px`, `:107`; die vier Entscheidungen stehen im Kopf der Datei `:11-19`)
    - Seitenrand und Rhythmus: `.report-main { padding: 10px 16px calc(86px + safe-area);
      gap: 14px; font-size: 15px }` (`:110-111`), Grund flach `--deep` (`:109`).
    - Bereichsleiste wandert nach unten (`.fussleiste`, `:114-134`); der Kopf gehoert der Seite.
    - Kopf: `.report-header` ohne Rahmen, ohne Glas, `padding: 4px 0 0`; der Bereichsname wird
      zur Ueberschrift in **26 px, 600, `-0.025em`** (`.bereichstitel`, `:137-141`).
    - Zeitraum zerfaellt in zwei Zeilen: `.report-header-right { display: contents }`, der
      Datumskasten neben dem Bereichsnamen (`order: 1`), der Spannenschalter als eigene Zeile
      darunter (`order: 3`); Kasten und Schalter ohne Rahmen, Radius 11, Flaeche
      `rgba(255,255,255,.07)`, `min-height: 40px`, Knoepfe `min-height: 34px`, 13,5 px
      (`:143-161`). Lange Ankerform aus, kurze an (`:159-160`).
    - Reiter werden rollbare Pillen: Radius 999, 14 px, Flaeche `rgba(255,255,255,.07)`,
      aktiv `--text-1` mit Schrift `--deep` und 600; die Reihe laeuft ueber den Seitenrand
      hinaus (`margin: 0 -16px`) und wird an beiden Enden maskiert (`:163-175`).
    - **Der Route-Kicker ist am Handy nicht da** (`AreaNav.tsx:96` `hidden md:block`).
    - Karten: `.card { border: 0; border-radius: 16px; padding: 16px }` (`:182`). Kartenkopf
      `h2.kicker` wird `--font-sans` **16,5 px / 600 / `-0.01em` / `text-transform: none` /
      `--text-1`** (`:184`) - also keine Sperrschrift mehr. Das Beiwerk des Kopfes rutscht auf
      eine eigene Zeile, 13 px (`:185`).
    - Kleine Schrift eine Stufe groesser: 10->11, 11->12, 12->13,5, 13->14,5 px (`:187-192`),
      begruendet: „Am Rechner liest man 12 Punkt aus sechzig Zentimetern, am Handy aus dreißig,
      aber im Gehen."
    - **Die Kacheln werden eine Flaeche** (`:194-207`): `.kpi-grid` ist selbst
      `--surface-2`, Radius 16, `padding: 4px 16px`, zwei Spalten, `gap: 0 20px`; die Kacheln
      darin verlieren Flaeche, Rahmen und Radius und bekommen einen `border-top: 1px
      solid --line-1`. Die **erste Kachel** nimmt beide Spalten (`grid-column: 1/-1`), ohne
      Linie oben, `padding: 14px 0 16px`, `gap: 8px`, Zahl **48 px mit `-0.04em`**, Einheit
      18 px mit 8 px Abstand, Kontextzeile **14,5 px in `--text-2`**. Die uebrigen: Zahl 25 px,
      Einheit 13,5 px, Kontextzeile 13 px. Eine allein gelassene letzte Kachel nimmt ebenfalls
      beide Spalten (`:200`). Das Kachelwort bleibt **gesperrt**, 11 px, `.1em` (`:201`) -
      ausdruecklich anders als der Kartenkopf.
    - Die beiden Diagrammkarten stehen untereinander: `.report-row` wird einspaltig
      (`globals.css:350`), am Handy nur noch `gap: 14px` (`handy.css:209`). Eine eigene
      Hoehenangabe fuer diese zwei Karten gibt es nicht - die 280 px stehen im Markup
      (`HouseReport.tsx:63,67`) und gelten also auch am Telefon.
    - Methode: `summary` `padding: 15px 16px`, Titel `--font-sans` 15 px / 600 / `none` /
      `--text-1`, Kurzzeile 13 px und in eine eigene Zeile (`globals.css:739-742`), Rumpf
      14,5 px / 1.5 (`handy.css:211-217`).
    - **Der Spannenstreifen wird eine Liste mit Umschalter** (`PeriodStrip.tsx:42-64`,
      Stil `handy.css:287-299`): `useIsMobile()` (`lib/useIsMobile.ts:18-28`, Grenze 720 px
      Breite **oder** 560 px Hoehe) schaltet um auf `Card gap 12` + Kartenkopf + `.spannen`
      (Schalterreihe, Radius 11, Flaeche `rgba(255,255,255,.07)`, Knopf `min-height: 34px`,
      13,5 px, aktiv `--amber` auf `--petrol`) + `.spannen-liste` als `dl`: je Zeile
      `dt` 14,5 px `--text-2` links, `dd` mono 16 px rechts, Trennlinie `--line-1`, die
      erste Zeile ohne Linie. Nur **eine** Spanne auf einmal. Begruendung: „Vier Zahlenspalten
      neben dem Namen der Zeile passen nicht auf 390 Punkte: die Namen wurden abgeschnitten, die
      Zahlen liefen ineinander." (`PeriodStrip.tsx:28-30`)
    Gesucht nach `strom`, `house`, `kpi-grid`, `report-row`, `echart` und `chart` in
    `handy.css`: ausser den genannten Regeln nichts, was nur diese Route betrifft - die Route
    hat keine Sonderregel, sie lebt von `.report-main`, `.kpi-grid`, `.card`, `.report-row`,
    `.spannen*` und `.methode`.

LUECKEN:

  [traegt-die-seite] Der ganze Abschnitt „Strom im Überblick" fehlt: vier Groessen
    (Verbrauch · kWh, Autarkie, Netzkosten, Einspeiseerlös) gegen die vier Spannen desselben
    Ankertags (`HouseReport.tsx:72-81`, `PeriodStrip.tsx:32-94`, `useReport.ts:55-77`). Die App
    holt auf dieser Seite genau eine Spanne (`StromSeite.swift:21-22`) und liest
    `export_revenue_eur` nirgends auf /strom (`grep -n "exportRevenueEur" StromSeite.swift`:
    kein Treffer; das Feld liegt bereit in `Schema.swift:3004`). Damit fehlt der Seite ihre
    Einordnung - „59,2 kWh" ohne den Monat daneben sagt nicht, ob der Tag viel war.

  [spuerbar] Die zwei Diagramme stehen in der Vorlage breit **nebeneinander** in einer Reihe zu
    je 280 px Hoehe (`HouseReport.tsx:62-71`, `globals.css:108`); die App legt sie untereinander
    als zwei Karten zu 180 pt (`StromSeite.swift:26-31`, `Bericht.swift:81`). An der Wand ist
    das der Unterschied zwischen einem Vergleich und zwei Bildern, und die zwei Fragen sind
    ausdruecklich als Paar gesetzt (`HouseReport.tsx:60-61`).

  [spuerbar] Die sechs Kacheln stehen in der Vorlage breit in **einer** Reihe
    (`KpiGrid cols={6}`, `globals.css:107`: Mindestbreite 150-260 px, auf 1180 pt reichen 6);
    die App zeichnet sie am iPad in drei Reihen zu zwei (`Kachelfeld.spalten` steht auf 2,
    `Karte.swift:279`, Aufruf ohne Angabe `StromSeite.swift:25`). Drei Reihen Kacheln schieben
    beide Diagramme unter den Rand - genau der Grund, aus dem die Fahrplanseite schon
    `spalten: 4` setzt (`Seiten/Technik/FahrplanSeiten.swift:71-78`).

  [spuerbar] Das Balkenbild hat keinen Zeiger. Die Vorlage nennt beim Darueberfahren den Bucket,
    je Reihe Name und Wert und darunter „Summe NN,N kWh" (`charts.ts:58-73`). In der App ist der
    Wert eines Balkens nirgends ablesbar (`Bericht.swift:103-147`: kein `chartXSelection`, keine
    `annotation`) - an einem Monatsbild mit dreissig Balken ist die Zahl damit verloren.

  [spuerbar] Die Kurzzeile der Methode verhaelt sich bei fehlender Abdeckung umgekehrt zur
    Vorlage. Vorlage: `coverage == null` -> „noch keine Messdaten im Zeitraum",
    `coverage == 0` -> „Datenabdeckung 0 %" (`ReportShell.tsx:166`). App: `coverage == nil` ->
    gar nichts, `coverage <= 0` -> „Noch keine Messdaten im Zeitraum"
    (`StromSeite.swift:52-56`). Schweigt der Zaehler ganz, sieht die App-Seite aus wie eine mit
    hundert Prozent - und das ist genau der Fall, gegen den die Kurzzeile gebaut wurde
    (`Bericht.swift:338-342`).

  [klein] Der Route-Kicker „Verbrauch · Verbraucher · Herkunft" fehlt (`HouseReport.tsx:42`,
    gezeichnet `AreaNav.tsx:96`, mono 11 px, `uppercase`, `.13em`, `--mist`). Nur breit
    sichtbar; in der App gibt es keine Stelle dafuer (`grep -n "kicker\|Kicker"
    App/Reiterzeile.swift App/WandRahmen.swift App/HandRahmen.swift`: kein Treffer).

  [klein] Die Reihennamen des zweiten Bildes weichen ab: Vorlage „PV direkt" / „aus Batterie" /
    „aus Netz" (`HouseReport.tsx:25-27`), App „Sonne direkt" / „aus dem Speicher" /
    „aus dem Netz" (`StromSeite.swift:132,136,140`). Die Farben stimmen
    (#f2a900 / #7fa3b3 / #e0533d, `palette.ts:35,36,37` gegen `Marken.swift:50,135,131`).

  [klein] Die Legende steht in der Vorlage **im Kartenkopf rechts**, als Farbfleck
    `8x10 px`, Radius 1, plus Name in 12 px `--text-3` (`ReportShell.tsx:192-203`,
    `Card.tsx:20-29`); die App legt sie oben links **in** das Diagramm
    (`Bericht.swift:120`: `.chartLegend(position: .top, alignment: .leading, spacing: 6)`).

  [klein] Der Titel der Methodenkarte heisst in der Vorlage „Wie gerechnet wird"
    (`Methode.tsx:18`), in der App „Wie das gerechnet ist" (`Bericht.swift:344`).

  [klein] „Aufzeichnung seit": Vorlage „14.11.2026" (`ReportShell.tsx:165`,
    `{day:"2-digit", month:"2-digit", year:"numeric"}`), App „Samstag, 14. November 2026"
    (`StromSeite.swift:41` ueber `Tag.lang`, `Formate/Tag.swift:87-91`). In einer einzeiligen
    Kurzzeile neben der Abdeckung ist das dreimal so breit.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * Abfrage: `Api.energieUebersicht(_ zeitraum: String, anker: String) async throws ->
    EnergySummaryOut` - `DuckCurveKit/Netz/Api.swift:179`.
  * `EnergySummaryOut` mit `totals`, `buckets`, `meta` - `DuckCurveKit/Modelle/Schema.swift:2942-2971`.
  * `EnergyBucketOut` mit `label: String` und `totals` - `Schema.swift:2810-2830`.
  * `EnergyTotalsOut`, alle Felder dieser Seite vorhanden und wahlfrei: `minutes` `:2975`,
    `importKwh` `:2978`, `houseKwh` `:2982`, `heatPumpKwh` `:2983`, `evKwh` `:2984`,
    `baseKwh` `:2985`, `pvDirectKwh` `:2986`, `batteryToHouseKwh` `:2987`,
    `gridToHouseKwh` `:2988`, `importCostEur` `:3003`, **`exportRevenueEur` `:3004`**,
    `autarky` `:3019`.
  * `EnergyMetaOut` mit `dataSince` `:2835`, `coverage` `:2836`, `estimatedNoteDe` `:2837` -
    `Schema.swift:2832-2864`.
  * Spanne und Zeitraum: `Spanne` (day/week/month/year) mit `name` „Tag/Woche/Monat/Jahr" -
    `DuckCurveKit/Formate/Zeitraum.swift:9-23`; `Zeitraum.kurz`, `.name`, `.verschoben`,
    `.istAktuell`, `Zeitraum.heute` - benutzt in `App/Seitenwahl.swift:237-280`.
  * Formate: `zahl(_:stellen:)` `Formate/Formate.swift:44`, `kwh` `:75`, `prozent` `:81`,
    `euro` `:99`, `leer` = „-" `:27`; `Tag.lang` `Formate/Tag.swift:87`.
  * Farben, deckungsgleich mit `palette.ts`: `Marken.pv` = amber #F2A900 `Gestalt/Marken.swift:50`,
    `diagrammNetz` #E0533D `:131`, `diagrammWallbox` #2F89B5 `:133`,
    `diagrammSpeicher` #7FA3B3 `:135`, `diagrammHaushalt` #CFD8DC `:140`,
    `waermepumpe` #E0966B `:58`, `mist` #7FA3B3 `:20`, `amber` `:18`, `alarm` #E0533D `:99`,
    `text3` `:45`; Hüllen in `DuckCurveHome/Gestalt/Farben.swift:31,33,54,70,77-80`.
  * Bausteine der Oberflaeche: `Berichtsseite` (Laden, Fehler, altes Bild stehen lassen)
    `Seiten/Bericht.swift:15-64`, `Balkenbild` `:70-149`, `Tabelle` (am Telefon eine Spalte mit
    Umschalter - die Gestalt, die `PeriodStrip` am Handy braucht) `:157-327`,
    `Methode` mit `kurz` `:334-397`, `Leer` `:390-404`, `Stoerung` `:410-436`;
    `Karte` `Gestalt/Karte.swift:15-104`, `Kacheldaten` `:121-151`, `Kachel` `:158-266`,
    `Kachelfeld` mit `spalten:` `:274-343`; `Kicker` `Gestalt/Typografie.swift:132-141`;
    `Seite` + `Zeitraumleiste` + `Datumskasten` (samt „HEUTE" nur wenn nicht heute)
    `App/Seitenwahl.swift:136-291`.
  * Rolle: `Hauszustand.darfSchalten` = `zugang.rolle == .hausherr` -
    `App/Hauszustand.swift:307`; schon benutzt fuer den Verweis der Netzbezugskachel
    (`StromSeite.swift:92,97-102`).
  * Mehrere Spannen auf einmal, als Vorbild fertig: `holeSpannen` mit `withTaskGroup` und
    `try?` je Spanne - `Seiten/Energie/WaermeSeite.swift:46-60`; gezeichnet als `Tabelle` in
    `:313-320`, Karte „Wärme im Zeitraum" `:181-183`; die Zeilen rechnet der Kern:
    `Waermeuebersicht.spannenzeilen(_:) -> [(wort: String, werte: [String])]` -
    `DuckCurveKit/Zustand/Waermeuebersicht.swift:280-301`.
  * Raster nach Breite, als Vorbild fertig: `GridItem(.adaptive(minimum: 290))` breit gegen
    `GridItem(.flexible())` schmal - `Seiten/Haus/HausSeite.swift:354-357`, gezeichnet `:310`.
  * Ablesbare Diagramme, als Vorbild fertig: `.chartXSelection(value:)` plus `RuleMark` an der
    gelesenen Stelle - `Diagramme/Prognosezeichnung.swift:250-262`; mit Beschriftung daneben
    `Diagramme/Wirkungszeichnung.swift:191,243-258`; als Bereich `Pruefkurvenbild.swift:77`.

ES FEHLT:

  1. **Spannenzeilen fuer die Energieuebersicht.** Neue Funktion im Kern, genau nach dem Muster
     von `Waermeuebersicht.spannenzeilen`:
     `public static func spannenzeilen(_ je: [Spanne: EnergySummaryOut]) -> [(wort: String, werte: [String])]`
     in einer neuen Datei `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Stromuebersicht.swift`.
     Vier Zeilen woertlich wie `HouseReport.tsx:75-80`, darin die Regel „ab 100 kWh ohne
     Nachkommastelle" (`de1(x, x >= 100 ? 0 : 1)`), die es in `Formate` noch nicht gibt.
     Vorbild: `Waermeuebersicht.swift:280-301`.
  2. **Ein Baustein `Spannenstreifen`** in `apps/ios/DuckCurveHome/Seiten/Bericht.swift`
     (neben `Tabelle`), der die vier Spalten breit als Tabelle und schmal als eine Spalte mit
     Pillen-Umschalter zeichnet - letzteres kann `Tabelle` schon (`Bericht.swift:206-244`), es
     fehlen nur der Kartenkopf rechts („jeweils bis jetzt" / „jeweils bis TT.MM.JJJJ",
     `PeriodStrip.tsx:34-38`), der Spaltenkopf „Heute"/„TT.MM." statt „Tag"
     (`PeriodStrip.tsx:9-16`; `Spanne.name` sagt „Tag", `Zeitraum.swift:17`) und die fette erste
     Zeile (`PeriodStrip.tsx:84`).
  3. **Mehrfachabfrage einer Spanne-Reihe im Kern**, damit sie nicht in jeder Seite neu steht:
     `public func jeSpanne<T>(_ hole: @Sendable (Spanne) async throws -> T) async -> [Spanne: T]`
     - heute steht sie als `holeSpannen` privat in `WaermeSeite.swift:46-60` und waere auf
     /strom die zweite Kopie.
  4. **Ein kurzes Datum** fuer die Methodenzeile: `Tag.ziffern(_:) -> "14.11.2026"` in
     `DuckCurveKit/Formate/Tag.swift` (es gibt `lang` `:87`, `kurz` `:94` mit Wochentag und
     `tagMonat` `:106` ohne Jahr - keines ist „TT.MM.JJJJ").

BAUPLAN: Karte fuer Karte, in der Reihenfolge der Vorlage

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Tag.swift` - `ziffern(_:)` ergaenzen
     (ES FEHLT 4).
  2. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift` (oder eine kleine Erweiterung
     daneben) - `jeSpanne(_:)` ergaenzen (ES FEHLT 3) und `WaermeSeite.holeSpannen` darauf
     umstellen, damit es nur eine Fassung gibt.
  3. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Stromuebersicht.swift` **neu** -
     `spannenzeilen(_:)` (ES FEHLT 1).
  4. `apps/ios/DuckCurveHome/Seiten/Bericht.swift` - `Spannenstreifen` **neu** (ES FEHLT 2); und
     `Balkenbild` um `.chartXSelection` plus eine Ablesezeile erweitern, die den Bucket, die
     Reihen ungleich Null und die Summe nennt (Vorbild `Prognosezeichnung.swift:250-262`,
     Text nach `charts.ts:58-73`). Das Ablesen gehoert in den Baustein, nicht in die Seite -
     es betrifft jedes Balkenbild der App.
  5. `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift` - in dieser Reihenfolge:
     a) Abfrage auf zwei Teile erweitern: die gewaehlte Spanne wie bisher **und**
        `jeSpanne { api.energieUebersicht($0.rawValue, anker: z.anker) }`, als Paar wie
        `SpeicherSeite` es schon tut (`StromSeite.swift:202-209`) bzw. `WaermeSeite:30-40`.
     b) `Kachelfeld(kacheln:)` um `spalten: 3` ergaenzen (Begruendung und Vorbild
        `FahrplanSeiten.swift:71-78`); am Telefon bleibt es bei Fuehrender + zwei Spalten, weil
        `Kachelfeld` dort ohnehin umschaltet (`Karte.swift:290-299`).
     c) die zwei Diagrammkarten in eine Reihe setzen, die breit zweispaltig und schmal
        einspaltig ist (`LazyVGrid` mit `GridItem(.adaptive(minimum: 290))` gegen
        `GridItem(.flexible())`, Vorbild `HausSeite.swift:354-357`), und `hoehe: 220` setzen
        (280 px Karte minus 16 px Rand und Kopfzeile).
     d) nach den Diagrammen `Spannenstreifen` mit Kicker „Strom im Überblick" einsetzen.
     e) `abdeckung(_:)` auf das Verhalten der Vorlage bringen: `nil` -> „noch keine Messdaten
        im Zeitraum", sonst „Datenabdeckung NN %" (`ReportShell.tsx:166`); `Tag.ziffern` statt
        `Tag.lang` in `:41`.
     f) die Reihennamen des zweiten Bildes auf „PV direkt" / „aus Batterie" / „aus Netz"
        bringen (`:132,136,140`).
  6. `apps/ios/DuckCurveHome/Seiten/Bericht.swift:344` - `titel` der `Methode` auf
     „Wie gerechnet wird" (betrifft alle Berichtsseiten, darum zuletzt und einmal).
  7. Offen, nicht in diesem Zug: eine Stelle fuer den Route-Kicker im Gerippe
     (`App/Reiterzeile.swift`) - das ist eine Entscheidung ueber alle dreizehn Berichtsseiten,
     nicht ueber diese eine.

WAS SCHWIERIG WIRD

  * **Legende im Kartenkopf statt im Diagramm.** Swift Charts zeichnet die Legende selbst
    (`.chartLegend`, `Bericht.swift:120`); sie in die Kopfzeile zu heben heisst, sie mit
    `.chartLegend(.hidden)` abzuschalten und als eigene Ansicht in `Karte(beiwerk:)` zu geben
    (`Karte.swift:19,79-81`). Der Weg ist im Projekt schon gegangen: `Karte(kicker:titel:)`
    setzt das Beiwerk rechts in den Kopf, und am Telefon rutscht es dort auf eine eigene Zeile
    (`handy.css:185`) - was `Karte.swift:56-62` im schmalen Fall **nicht** tut, sondern
    nebeneinander setzt. Fuer eine dreiteilige Legende ist das zu wenig Platz; sie braucht eine
    umbrechende Zeile, also `Umbruchzeile` (`Gestalt/Umbruchzeile.swift:13`) und nicht `beiwerk`.
  * **Zwei Karten nebeneinander.** Es gibt in der App bisher keine Reihe aus zwei Karten
    (`grep -rn "report-row\|Kartenreihe" DuckCurveHome/`: kein Treffer). Der gewaehlte Weg des
    Projekts fuer „breit nebeneinander, schmal untereinander" ist `LazyVGrid` mit
    `GridItem(.adaptive(minimum:))` gegen eine Spalte - `HausSeite.swift:354-357` und
    `Bausteine/Wpmenue.swift:88-91`. `ViewThatFits` kommt nur einmal vor
    (`SystemSeiten.swift:1055`) und waere hier falsch: es braucht fertige Entwuerfe.
  * **Der Zeiger auf einem gestapelten Balken.** ECharts bekommt `trigger: "axis"` samt Summe
    geschenkt; Swift Charts liefert mit `chartXSelection` nur den Wert der Querachse, die
    Reihen dazu muss man selbst heraussuchen und als Zeile ueber oder unter dem Bild zeigen.
    Vorbild mit Beschriftung: `Wirkungszeichnung.swift:191` plus `:243-258`; Vorbild mit blosser
    Linie: `Prognosezeichnung.swift:250-262`. An einem Balkenbild mit Woertern auf der Achse ist
    `chartXSelection` ein `String?` - die Zuordnung laeuft also ueber `bucket.label`, und
    Labels wiederholen sich bei einem Jahr nicht (`Bericht.swift:87-97` hat die Liste schon
    ohne Wiederholung).
  * **„Heute" als Spaltenkopf.** Die Vorlage entscheidet das aus `anchor === isoToday()`
    (`PeriodStrip.tsx:12-16`). Die App hat dafuer `Zeitraum.istAktuell(jetzt:)`
    (`Seitenwahl.swift:238`), braucht aber zusaetzlich die Kurzform „TT.MM." fuer einen
    vergangenen Anker - also wieder `Tag.tagMonat` (`Formate/Tag.swift:106`), das genau das
    liefert.
  * **Vier Abfragen auf einer Seite, die schon eine macht.** Fuenf parallele Laeufe je
    Zeitraumwechsel; `WaermeSeite` loest es mit `async let` fuer die Hauptabfrage und einer
    `TaskGroup` mit `try?` je Spanne (`WaermeSeite.swift:30-60`), damit eine fehlende Spalte
    die Seite nicht mitnimmt. Dasselbe Muster hier - nicht `try await` je Spanne.
