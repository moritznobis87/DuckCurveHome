========================= messen:strom-speicher   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

`struct SpeicherSeite: View` steht in `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:200-279`,
eingehängt über `apps/ios/DuckCurveHome/App/Seitenwahl.swift:44` am Weg `/strom/speicher`
(Reiter: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:110`).

1. Gerippe `Berichtsseite` (`apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-64`): Zeitraumleiste oben
   (nur ab regular-Breite, `Bericht.swift:35` + `Seitenwahl.swift:147-151`), Störung über dem Inhalt
   (`Bericht.swift:36-38`), „Wird geholt …" / „Für diesen Zeitraum ist nichts da."
   (`Bericht.swift:43-47`), Altes bleibt mit `opacity 0.55` stehen (`Bericht.swift:41`).
   Keine Überschrift, kein Seitenkicker.
2. Zwei Abfragen parallel (`StromSeite.swift:206-208`): `api.energieUebersicht(spanne, anker:)` und
   `try? api.speicherPruefung(spanne, anker:)` - der Prüfbericht läuft **bei jedem Seitenaufruf und
   jedem Zeitraumwechsel ungefragt mit**.
3. `Kachelfeld(kacheln: kennzahlen(b), kicker: "Speicher")` (`StromSeite.swift:211`), sechs Kacheln
   (`StromSeite.swift:253-278`), in dieser Reihenfolge:
   geladen (kWh) · entladen (kWh, `Farbe.batterie`) · „aus der Sonne geladen" (kWh, `Farbe.pv`) ·
   „aus dem Netz geladen" (kWh, dazu „davon X kWh im Dunkeln" ab 0,05 kWh, dann `Farbe.achtung`) ·
   „Wert der Entladung" (€) · „unterm Strich" (€, dazu „Entladung minus Ladekosten").
   Am Telefon führt die erste Kachel in 48 pt über die ganze Breite, der Rest zweispaltig
   (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:288-303, 240`).
4. `Karte(kicker: "Woher die Ladung kam")` mit `Balkenbild` gestapelt (`StromSeite.swift:212-223`):
   „aus der Sonne" `Farbe.pv`, „aus dem Netz" `Farbe.netzBezug`, Werte aus
   `buckets[].totals.pvToBatteryKwh` / `gridToBatteryKwh`.
5. `Karte(kicker: "Entladung")` mit `Balkenbild(gestapelt: false)` (`StromSeite.swift:224-234`):
   „ins Haus" `Farbe.batterie` aus `buckets[].totals.batteryToHouseKwh`.
6. `Karte(kicker: "Nachgerechnet")` nur wenn Text da ist (`StromSeite.swift:235-244`):
   der Prüfbericht als `Text` in `Schrift.zahlKlein`, `Farbe.text2`, in einer
   `ScrollView(.horizontal, showsIndicators: true)`, `textSelection(.enabled)`.
7. `Methode([...])` (`StromSeite.swift:245-249`): `meta.estimatedNoteDe` plus ein eigener Satz
   („Die Herkunft der Ladung ist gerechnet, nicht gemessen …"). **Ohne `kurz:`** - also ohne
   Datenabdeckung und ohne „Aufzeichnung seit" (`Bericht.swift:336-343, 349-353`).

Balkenbild: `Bericht.swift:70-149`, Höhe fest 180 pt (`:81`), Legende oben links
(`:120`), y-Achse links mit vier Werten in Formate.zahl(stellen: 0) (`:122-131`), x-Achse auf
höchstens 6 (schmal) bzw. 12 Wörter gedünnt (`:137`), Leerfall „Keine Werte in diesem Zeitraum."
(`:100-101`).

VORLAGE:

Einstieg `apps/web/src/app/strom/speicher/page.tsx:1-7` - nur `<BatteryReport />`,
`metadata.title = "Speicher · Duck Curve Home"`.
Alles weitere: `apps/web/src/components/reports/BatteryReport.tsx:51-177`.

  * **Kopf / Gerippe `ReportShell`**  (`BatteryReport.tsx:103`; Baustein
    `apps/web/src/components/reports/ReportShell.tsx:97-134`)
    `title="Batteriespeicher"` steht **nicht** sichtbar im Kopf, sondern nur als `sr-only`
    (`ReportShell.tsx:127`) - der aktive Reiter sagt, wo man ist; Begründung im Kommentar
    `ReportShell.tsx:99-100`. Sichtbar ist der **Kicker**:
    `cap > 0 ? "13,5 kWh · Nutzung und Ersparnis" : "Nutzung und Ersparnis"`
    (`BatteryReport.tsx:103`, `cap = data.meta.battery_capacity_kwh`, `:84`), gesetzt als
    `AreaTabs right` und dort `.kicker` in 11 px, **nur ab md** sichtbar
    (`apps/web/src/components/layout/AreaNav.tsx:96`).
    Rechts im Kopf: Blätterkasten (‹ · Datum · ›, „heute" in `--amber` 11 px uppercase
    letter-spacing .08em, `ReportShell.tsx:109-117`), Spannenschalter Tag/Woche/Monat/Jahr
    (12 px, aktiv `background: var(--amber)`, `color: var(--petrol)`, `borderRadius: 3`,
    `ReportShell.tsx:120-126`). Datum lang: „Dienstag, 10.11.2026" (`anchorLabel`,
    `ReportShell.tsx:36-49`), Zeitraumzustand mit URL-Synchronisation `?period=&anchor=`
    (`usePeriod`, `ReportShell.tsx:61-95`).
    Rahmen: `AreaShell` (`apps/web/src/components/layout/AreaShell.tsx:13-29`),
    `gap: 16px`, `padding: 20px`, Grund `.dashboard-bg` (`globals.css:86-94`).
    DATEN: `useReport(api.energySummary, period, anchor)` - `GET /energy/summary?period=&anchor=`
    (`apps/web/src/lib/api/client.ts:68`), alle 5 min neu, Altes bleibt stehen
    (`useReport.ts:7, 18-46`). Fehler als `ErrorBanner` **über** den Kacheln
    (`BatteryReport.tsx:104`; `ReportShell.tsx:147-153`: Rahmen `rgba(224,83,61,.4)`,
    Grund `rgba(224,83,61,.12)`, Farbe `--alert`, 12 px mono uppercase letter-spacing .1em).

  * **Acht Kennzahlkacheln, `KpiGrid cols={8}`**  (`BatteryReport.tsx:105-145`)
    Raster: `.kpi-grid` = `repeat(auto-fit, minmax(clamp(150px, 100%/8 - 16px, 260px), 1fr))`,
    `gap: 16px` (`globals.css:107`); der Kommentar `globals.css:103-106` nennt genau diese Seite
    als Grund: *„Vorher zwang die Batterieseite sieben Kacheln in eine Reihe; die Überschrift
    ‚Netzladung bei Dunkelheit' brach um … Lieber zwei ruhige Reihen als eine gedrängte."*
    Eine Kachel = `Stat` (`apps/web/src/components/ui/Stat.tsx:4-19`): Kicker 11 px
    (mono, uppercase, letter-spacing .13em, Farbe `--text-kicker` = `--mist`, `globals.css:57-64`),
    Zahl 26 px mono, `line-height: 1`, `letter-spacing: -.02em`, Einheit daneben 13 px in
    `--text-3` und **Sans** (`Stat.tsx:9-11`), Hinweiszeile 12 px `--text-3`, `line-clamp-2`
    (`Stat.tsx:16`; Kommentar `:13-15`: abgeschnitten ist sie nutzlos, zwei Zeilen sind das
    Maximum, damit die Kacheln einer Reihe gleich hoch bleiben).
    Töne (`Stat.tsx:5`): `amber`→`--amber`, `ember`→`--alert`, `mist`→`--mist`,
    `muted`→`--text-3`, sonst `--text-1`.
    Die acht, wörtlich und in dieser Reihenfolge:
    1. **Geladen** · `de1(battery_charge_kwh)` kWh · tone `amber` ·
       Hinweis `PV 7,1 · Netz 0,4 kWh` + `est` (`:106`).
    2. **Netzladung ohne PV** · `de1(grid_to_battery_dark_kwh)` kWh ·
       tone `ember` wenn `> 0.2`, sonst `muted` ·
       Hinweis `von 0,4 kWh Netzladung insgesamt` + `est` (`:107-113`).
    3. **Entladen** · `de1(battery_discharge_kwh)` kWh · tone `mist` ·
       Hinweis `6,2 kWh ins Haus` (`:114`).
    4. **Vollzyklen** · `de1(cycles, cycles >= 10 ? 0 : 1)`, `cycles = battery_discharge_kwh / cap`
       (`:94`) · Hinweis `Entladung ÷ 13,5 kWh`, ohne Kapazität `Kapazität unbekannt` (`:115`).
    5. **Ersparnis** · `eur(battery_net_eur)` · tone `amber` ·
       Hinweis `1,84 € gespart − 0,12 € fürs Laden`, sonst `netto` (`:118-123`).
       Kommentar `:116-117`: *„Netto: vermiedener Bezug minus dem, was das Fuellen gekostet hat.
       Die alte Zahl zaehlte nur die Entladung und sah den Verlust nie."*
    6. **PV-Anteil Ladung** · `pct(pv_to_battery_kwh / battery_charge_kwh)` (`:95`) ·
       Hinweis `0,4 kWh aus dem Netz geladen` ab 0,05 kWh, sonst `keine Netzladung`, je + `est`
       (`:124`).
    7. **Laut Ladestand** · `de1(bySoc.discharge)` kWh ·
       tone `ember` wenn `|bySoc.discharge − battery_discharge_kwh| > 0.25 · max(bySoc.discharge, 0.5)`,
       sonst `muted` · Hinweis `entladen · Leistungsmessung 6,2 kWh` (`:125-132`).
       **Nur wenn `bySoc` da ist** (also nur in der Tagesansicht mit Minutenwerten); sonst steht an
       derselben Stelle **Wirkungsgrad** · `pct(eff)` · tone `muted` · Hinweis
       `Entladen ÷ Geladen`, mit `eff = min(1, discharge/charge)` erst ab 0,5 kWh Ladung
       (`:96, 133-135`).
    8. **Verlust im Gerät** · `de1(battery_device_kwh)` kWh · tone `ember` wenn `> 0.2`, sonst
       `muted` · Hinweis `0,21 € bezahlt · 0,04 € entgangen` (`:138-144`).
       Kommentar `:136-137`: *„Was der Wandler als Ladung sah, die Zellen aber nie erreichte.
       Bezahlt wurde es immer schon; bis zur Trennung stand es nur als Ladung und als Netzladung
       da."*
    `est` (`:90-93`): `coarse = coarse_minutes / minutes`; über 5 % hängt an drei Hinweise
    ` · Aufteilung für 23 % des Zeitraums geschätzt`. Kommentar `:90-91`: *„Dort sind die Summen
    richtig, die Aufteilung auf PV und Netz ist eine Annahme - und genau die steht auf diesen
    beiden Kacheln."*
    Formate (`ReportShell.tsx:14-16`): `de1` = `de-DE` mit genau einer Nachkommastelle,
    `eur` = `de1(n,2) + " €"`, `pct` = gerundete Prozent mit schmalem Abstand vor `%`.
    Leerfall: `t` ist `undefined`, bis Daten da sind - dann steht in jeder Kachel `-`
    (`de1(undefined)`), die Seite baut sich **nicht** leer auf.
    DATEN: `energy_summary.totals` (`apps/web/src/lib/api/types.ts:2909-3022`),
    `meta.battery_capacity_kwh` (`types.ts:2838`).

  * **Karte „Speicher steuern"**  (`BatteryReport.tsx:146`; Baustein
    `apps/web/src/components/reports/BatteryControl.tsx:31-123`)
    `CardHead title="Speicher steuern"`, rechts `Ladestand 54 %` bzw. `Ladestand unbekannt`
    (`BatteryControl.tsx:83-86`). Darunter zwei Gruppen in einer Zeile mit `gap: 16px`:
    - **Betriebsart**, drei Knöpfe in einem Kasten (Höhe 44 px, `border-line-1`, Radius 3,
      Trennlinie links je Knopf, min-width 92 px, 13 px mono uppercase letter-spacing .1em,
      aktiv `background: var(--amber)` / `color: var(--petrol)`, gesperrt `opacity .45`;
      `:88-102`): **Auto** („Untergrenze aktiv: DCH hält den Speicher an, bevor er leer läuft."),
      **Frei** („Speicher freigegeben; DCH greift nicht ein."), **Halten** („Speicher befristet
      anhalten (hält auch das Laden an).") - Wörter und `title`-Texte wörtlich aus `:24-28`.
    - **Untergrenze**: Kicker 11 px, dann fünf Knöpfe `aus · 6 % · 10 % · 15 % · 20 %`
      (`RESERVES = [0, 0.06, 0.1, 0.15, 0.2]`, `:29`), je 44 px hoch, min-width 56 px,
      Rahmen `line-2`, Radius 2, aktiv `background: var(--amber-soft)` / `color: var(--petrol)`
      (`:103-117`).
    Unten eine `Note` (12 px, `--text-3`, max 90ch, `ReportShell.tsx:143-145`): beim Senden
    „schalte …", sonst `note_de` + „Zuletzt gesendet: angehalten|normal." + „Fehler: …", und wenn
    die Steuerung gesperrt ist „Die Steuerung des Speichers ist in der Konfiguration nicht
    freigegeben." (`:69-79, 119-121`).
    Zustände: `if (!state) return null` - ohne Antwort ist die Karte **gar nicht da** (`:63`);
    `mode === "off"` wird für die Anzeige wie `normal` behandelt (Kommentar `:64-65`); Fehler
    erscheinen 12 s in der Notenzeile (`:57`).
    Warum sie hier steht und nicht im Dashboard, und wozu die Untergrenze dient, steht wörtlich
    im Kopfkommentar `BatteryControl.tsx:9-23` - **das ist die Begründung, die beim Umbau nicht
    verloren gehen darf**: *„Die Folgen stehen auf genau dieser Seite: Netzladung, Ladung bei
    Dunkelheit, Vollzyklen."* Und: *„Der Libbi entlädt bis zu seiner eigenen Grenze, meldet dann
    0 %, und wenn dieser Stand eine Stunde steht, holt er sich rund 6 % aus dem Netz zurück …
    gemessen am 03.09.2026 war sie drei Stunden später wieder verschwunden … Die letzten Prozent
    zu fahren kostet also Netzstrom, Wirkungsgrad und Zyklen und bringt nichts."*
    DATEN: `GET /control/battery` (`client.ts:60`) alle 60 s (`:44-48`),
    `POST /control/battery/mode` mit `{mode, duration_min: 120, reserve_soc}` (`client.ts:61-62`,
    `BatteryControl.tsx:54`). Antwort `BatteryLiveOut`: `control_enabled, mode, ends_at,
    reserve_soc, soc, command, sent_at, last_error, note_de`.

  * **Zwei Balkenbilder nebeneinander**  (`BatteryReport.tsx:147-156`)
    `div.report-row` mit `--cols: 1fr 1fr` (`globals.css:108`, `gap: 16px`), je eine `Card` mit
    `padding: 16`, **Höhe fest 280 px**, Diagramm in `min-h-0 flex-1`.
    - Links `CardHead title="Ladung nach Herkunft"`, rechts eine `ChartLegend` mit Farbfleck +
      Name (`ReportShell.tsx:192-203`: Fleck 10×8 px, Radius 1, Name 12 px `--text-3`,
      rechtsbündig, umbrechend). Warum es die Legende geben **muss**, steht im Kommentar
      `ReportShell.tsx:184-191`: *„Damit lag die Identität der Flächen allein in der Farbe, und
      wer die Reihenfolge nicht kennt, muss raten."*
      Serien (`BatteryReport.tsx:16-19`): **„Ladung aus PV"** `C.pv = #f2a900`,
      **„Ladung aus Netz"** `C.grid = #e0533d`.
    - Rechts `CardHead title="Entladung ins Haus"`, **ohne** Legende (eine Serie):
      **„Entladung ins Haus"** `C.battery = #7fa3b3` (`:20`).
    Diagramm: `stackedBars` (`apps/web/src/components/reports/charts.ts:52-89`):
    `animation: false`, mono überall, `grid {left:48,right:12,top:24,bottom:30}`,
    x-Achse Kategorien aus `bucket.label`, Achsenschrift 10 px, `interval: "auto"` ab 12 Buckets
    sonst 0, `hideOverlap`; y-Achse Name „kWh", Rasterlinien `rgba(255,255,255,.09)`,
    `splitNumber: 3`; Balken `stack: "total"`, `barCategoryGap: "35%"`, oberste Serie mit
    `borderRadius: [2,2,0,0]`; Werte auf zwei Stellen gerundet, `null` wird 0.
    Hinweisfenster am Finger: Label des Buckets, je Serie Name in Serienfarbe und `x,y kWh`,
    darunter abgetrennt **„Summe 7,5 kWh"** (`charts.ts:62-72`).
    Leere Buckets bleiben leer (Doku-Kommentar `charts.ts:45`); die generische Form und ihr Grund
    stehen in `charts.ts:44-51`.
    DATEN: `data.buckets[].totals.{pv_to_battery_kwh, grid_to_battery_kwh, battery_to_house_kwh}`.

  * **„Ladezustand über den Tag" + „Speicher im Überblick"**  (`BatteryReport.tsx:157-172`)
    `div.report-row` mit `--cols: 8fr 4fr`.
    - `Card padding: 16`, **Höhe fest 340 px**, `CardHead title="Ladezustand über den Tag"`,
      rechts in der Tagesansicht wörtlich **„oben der Ladezustand, unten die Leistung:
      + Entladen, − Laden"**, sonst **„nur in der Tagesansicht"** (`:159`).
      Diagramm nur wenn `isDay && rows.length > 0`; sonst eine zentrierte `Note` mit
      **„Für diesen Tag liegen keine Minutenwerte vor; die Stundenbilanzen oben stammen dann aus
      dem Historienimport."** bzw. **„Der Verlauf wird je Tag gezeigt; für längere Zeiträume
      gelten die Stundenbilanzen oben."** (`:160`).
      `batteryDayChart` (`charts.ts:236-276`): **zwei Flächen untereinander**, nicht zwei Achsen
      in einer - `grid: zweiFlaechen(56)` (`charts.ts:32-38`: obere Fläche flexibel,
      untere **fest 60 px**, Abstand **fest 34 px**, `left: 48`, `right: 16`, `top: 24`,
      `outerBoundsMode: "none"`). Oben `Ladezustand` 0-100 % mit `interval: 25`, Linie `C.pv`,
      Breite 2,5, `connectNulls: true`, `z: 3`; unten `Leistung` in kW als Stufenlinie
      (`step: "end"`), Linie `rgba(127,163,179,.7)` 1 px mit Fläche `rgba(127,163,179,.12)`,
      `splitNumber: 2`, `z: 1`. Zeitachse unten mit `hh:mm`, oben ausgeblendet; gemeinsamer
      Achsenzeiger über beide Flächen (`zeigerVerbunden`, `charts.ts:39`); Legende scrollend unten
      mittig, 11 px. Hinweisfenster: Uhrzeit, dann `Ladezustand 54 %` / `Leistung -1,23 kW`
      (`charts.ts:246-253`).
      **Warum zwei Flächen und nicht zwei Achsen**, und warum in Pixeln statt Prozent, steht
      wörtlich in `charts.ts:11-31` - *„Zwei Kurven in einem Bild liest das Auge als Zusammenhang
      ihrer Kreuzungspunkte, und wo sie sich kreuzen, entscheidet allein die Skalierung"*, und
      *„In Prozent schrumpfte die untere Fläche in einer flachen Karte auf 23 Pixel"* (gesehen am
      10.11.2026).
      DATEN: Minutenreihen. `isDay && isToday` → `GET /history?range=today`, sonst
      `GET /history?range=custom&start=&end=` über Ortszeit-Mitternacht des Ankertags
      (`dayBounds`, `BatteryReport.tsx:43-49`; `client.ts:49, 52-53`). Gelesen werden
      `rows[].ts`, `rows[].battery_soc` (Anteil 0-1, mal 100), `rows[].battery_power_kw`.
      Nur der laufende Tag wird alle 60 s nachgeladen, ein vergangener einmal (Kommentar
      `BatteryReport.tsx:74-80`); bei Fehler `rows = []`, also die Note statt des Bildes.
    - `PeriodStrip` **„Speicher im Überblick"** (`BatteryReport.tsx:162-171`; Baustein
      `apps/web/src/components/reports/PeriodStrip.tsx:32-93`).
      Vier Zeilen × vier Spalten (Tag · Woche · Monat · Jahr **des Ankertags**):
      **„Ersparnis netto"** `eur(battery_net_eur)` tone `amber` (erste Zeile zusätzlich fett 600),
      **„Entladen · kWh"** `de1(battery_discharge_kwh, >= 100 ? 0 : 1)`,
      **„Vollzyklen"** `de1(battery_discharge_kwh / cap, 1)`,
      **„PV-Anteil"** `pct(pv_to_battery_kwh / battery_charge_kwh)`.
      Kopf rechts: **„jeweils bis jetzt"**, auf einem vergangenen Anker **„jeweils bis 10.11.2026"**
      (`PeriodStrip.tsx:34-38`); die Tagesspalte heißt nur **„Heute"**, wenn sie es ist, sonst
      `10.11.` (`:12-16`). Tabelle 12 px, `tableLayout: fixed`, erste Spalte 34 %, Kopfzeile
      `.kicker` 10 px, Zeilen durch `border-line-1` getrennt, Zahlen rechtsbündig mono.
      Fehlende Spanne → `-` (`BatteryReport.tsx:100`).
      Begründung im Kommentar `PeriodStrip.tsx:21-27`: die Spalten folgen der Navigation, *„nicht
      mehr die laufenden"*; und `useReport.ts:48-54`: *„Wer in der Navigation auf den 3. Januar
      blätterte, sah oben die Zahlen dieses Tages und in der Übersicht daneben weiterhin die
      laufende Woche … Zwei Zeiträume in einer Ansicht, ohne dass es dastand."*
      DATEN: `useMultiPeriod(api.energySummary, anchor)` - vier Abfragen auf einmal mit
      `Promise.allSettled` über `["day","week","month","year"]`, alle 5 min
      (`useReport.ts:55-77`).

  * **Karte „Stimmt das?"**  (`BatteryReport.tsx:173`; Baustein
    `apps/web/src/components/reports/SpeicherCheck.tsx:19-54`)
    `Card padding: "14px 18px", gap: 10`. `CardHead title="Stimmt das?"`, rechts ein
    `.pruef-knopf`: **„Speicher prüfen"**, laufend **„liest Minuten ..."**, gesperrt solange kein
    Anker da ist (`:41`). Knopf: mono 11 px, letter-spacing .12em, uppercase, `--petrol` auf
    `--amber`, Radius 999 px, Polster 7/14 px; gesperrt `--line-2` auf `--text-2`
    (`globals.css:602-603`).
    Darunter **immer** ein Absatz 13 px, `line-height 1.6`, `--text-2`, wörtlich:
    *„Alle Zahlen dieser Seite kommen aus einer einzigen Messreihe, der Leistung des Speichers.
    Stimmt sie nicht, stimmt keine davon, und zwar alle im selben Sinn. Die Prüfung hält sie gegen
    zwei Messungen, die nichts mit ihr zu tun haben: den Ladestand aus dem Gerät und den
    Hausverbrauch von den Wandlern des Hubs. Damit lässt sich trennen, ob der Strom im Speicher
    angekommen ist, ob er nur im Gerät geblieben ist oder ob er gar nicht geflossen ist."*
    (`SpeicherCheck.tsx:43-49`).
    Fehler als Zeile 13 px in `--alert` (`:50`); der Bericht als `pre.pruefbericht`:
    `max-height: 60dvh`, `overflow: auto`, Polster 12/14 px, Radius 6, Rahmen `--line-1`,
    Grund `rgba(8,36,49,.6)`, mono **11,5 px**, `line-height 1.55`, `--text-2`,
    `white-space: pre` (`globals.css:604`).
    **Warum auf Abruf** und nicht als Kachel, steht wörtlich in `SpeicherCheck.tsx:8-18` - *„wenn
    eine von ihnen unglaubwürdig aussieht, hilft keine weitere Kachel aus derselben Quelle"*, und:
    *„Er liest die Minutenreihen des Zeitraums, bei einem Jahr über eine halbe Million Zeilen. Das
    ist nichts, was bei jedem Seitenaufruf nebenbei laufen soll."*
    DATEN: `GET /energy/speicher-check?period=&anchor=` als **reiner Text**
    (`client.ts:129-135`), erst auf Klick.

  * **`CoverageNote` zum Schluss**  (`BatteryReport.tsx:174`; Baustein
    `ReportShell.tsx:163-174`, `apps/web/src/components/ui/Methode.tsx:18-34`)
    Ein `<details class="card methode">`, zugeklappt. Im `summary`: Kicker **„Wie gerechnet
    wird"** und die **Kurzzeile**, die immer dasteht:
    **„Datenabdeckung 94 % · Aufzeichnung seit 03.09.2026"**, ohne Messdaten
    **„noch keine Messdaten im Zeitraum"** (`ReportShell.tsx:165-168`), dazu ein Pfeil, der sich
    beim Öffnen dreht (`globals.css:731-732`).
    Im Rumpf zwei Absätze (`.methode-absatz`: 13 px, `line-height 1.55`, `--text-2`, max 90ch,
    `globals.css:734`): zuerst `extra`, wörtlich
    *„Geladen ist, was in den Zellen ankam: Was der Wandler zusätzlich sah, hat sie nie erreicht
    und steht als Verlust im Gerät daneben. Ersparnis ist netto gerechnet: der vermiedene Bezug
    der Entladestunden, abzüglich dessen, was das Füllen gekostet hat (Netzanteil zum Bezugspreis,
    PV-Anteil zur entgangenen Vergütung). Die Verluste stecken darin von selbst, weil mehr
    hineinging als herauskam."* (`BatteryReport.tsx:174`), dann `meta.estimated_note_de`.
    **Was hinein gehört und was nicht**, steht wörtlich in `Methode.tsx:11-13`: *„Hinein gehört,
    wie eine Zahl entsteht und was sie nicht sagt. Nicht hinein gehört, was eine Zahl *an diesem
    Tag* einschränkt - eine fehlende Linie, eine Lücke, ein laufender Tag. Das steht neben der
    Zahl, denn zugeklappt wäre es verschwiegen."* Und `Methode.tsx:15`: ein `<details>` und kein
    Zustand, damit die Seitensuche den Text findet.
    `if (!meta) return null` - ohne Daten keine Karte (`ReportShell.tsx:164`).

  * **Handy-Fassung, wo sie abweicht**  (`apps/web/src/styles/handy.css`, Grenze
    `max-width: 720px`, `:107`; Begründung im Kopf `:1-26`, Nutzerurteil 10.11.2026
    *„viel zu schlecht, muss neu gedacht werden"*)
    - Grund und Rand: `.dashboard-bg` wird flaches `--deep` (`:109`), Seitenrand
      `10px 16px calc(86px + safe-area)`, Abstand 14 px, Grundschrift 15 px (`:110-111`).
      Die Bereichsleiste steht **unten** (`:113-120`), der Kopf gehört der Seite.
    - Kopf: kein Rahmen, kein Glas, `padding: 4px 0 0` (`:137`); Marke ohne Namen (`:140`).
      `.report-header-right { display: contents }` - die drei Teile ordnen sich neu:
      Blätterkasten zuerst, Kicker darunter über die ganze Breite, Spannenschalter zuletzt
      (`:148-151`). Blätterkasten und Spannen ohne Rahmen, Radius 11 px, Grund
      `rgba(255,255,255,.07)`, Höhe 40 px, Knöpfe 34 px, 13,5 px (`:155-161`).
      **Das Datum wird kurz**: `.report-anchor-lang` aus, `.report-anchor-kurz` ein (`:159-160`) -
      also „Di., 10.11." statt „Dienstag, 10.11.2026" (`anchorKurz`, `ReportShell.tsx:52-58`).
    - Karten: ohne Rand, Radius 16, Polster 16 (`:182`); die Kartenüberschrift wird **lesbare
      Schrift statt Sperrschrift**: Sans 16,5 px, 600, letter-spacing -.01em, `--text-1`
      (`:184`); der rechte Kopfteil bricht in eine eigene Zeile um, 13 px (`:185`).
    - Kleine Schrift eine Stufe größer: 10→11, 11→12, 12→13,5, 13→14,5 px (`:189-192`),
      mit der Begründung `:187-188` (dreißig Zentimeter, aber im Gehen).
    - **Kennzahlen: eine Fläche statt acht Rahmen** (`:194-207`). `.kpi-grid` wird
      `repeat(2, 1fr)`, `gap: 0 20px`, Grund `--surface-2`, Radius 16, Polster `4px 16px`; die
      Kacheln verlieren Grund und Rahmen und werden durch Haarlinien `--line-1` getrennt.
      **Die erste Kachel führt**: ganze Breite, keine Linie oben, Zahl **48 px** mit
      letter-spacing -.04em, Einheit 18 px, Hinweiszeile 14,5 px in `--text-2` (`:199, 204-205,
      207`). Die übrigen: Zahl 25 px, Einheit 13,5 px, Kicker 11 px, Hinweis 13 px
      (`:201-203, 206`). Bleibt am Ende eine allein, nimmt sie die ganze Zeile (`:200`) - bei
      acht Kacheln also: eine groß, dann 1+2+2+2.
    - `.report-row { gap: 14px }` (`:209`); die Spaltenzahl wird schon in `globals.css:350`
      (`max-width: 720px`) auf eine Spalte gesetzt - die beiden Balkenbilder und
      Tagesdiagramm/Überblick stehen also untereinander, in **derselben festen Höhe** 280 bzw.
      340 px.
    - Methode: Polster 0, `summary` 15/16 px, Titel wieder lesbare Sans 15 px 600, Kurzzeile
      13 px, Absätze 14,5 px (`:212-217`).
    - **`PeriodStrip` wird am Handy eine Spalte** (`PeriodStrip.tsx:42-64`, geschaltet über
      `useIsMobile`, `apps/web/src/lib/useIsMobile.ts:18-28`, Grenze 720 px **oder** Höhe 560 px):
      über der Liste ein Umschalter `.spannen` (Radius 11, Grund `rgba(255,255,255,.07)`,
      Polster 3, Knöpfe `.spanne` min 34 px, 13,5 px, aktiv `--amber` auf `--petrol`),
      darunter eine `<dl>`: je Zeile Name 14,5 px `--text-2` links, Wert 16 px mono rechts,
      Haarlinie dazwischen (`handy.css:288-299`). Begründung `PeriodStrip.tsx:28-30`: *„Vier
      Zahlenspalten neben dem Namen der Zeile passen nicht auf 390 Punkte."*
    - **Diagramme werden am Handy nachgestellt**, ohne dass ein Diagramm davon weiß:
      `fuerHandy` (`apps/web/src/components/charts/handy.ts:44-63`, gerufen in
      `apps/web/src/components/charts/EChart.tsx:11`): Achsenschrift **mindestens 11 px**,
      `hideOverlap` überall, Wertachsen ohne festes `interval` höchstens **3** Schritte,
      Legenden blättern in einer Zeile (`type: "scroll"`, `itemGap: 14`, Text 12 px),
      Hinweisfenster `confine: true`. Die 0-100-%-Achse des Tagesbildes behält ihr
      `interval: 25` (ausdrücklich gesetzt, `charts.ts:268`).
    - Gesucht nach `pruefbericht`, `pruef-knopf`, `kpi-grid > .card:nth-child` jenseits von
      `:197-207` in `handy.css`: kein weiterer Treffer - Prüfknopf und Prüfbericht behalten am
      Handy ihre Maße aus `globals.css:602-604`, der Bericht also mono 11,5 px, `white-space: pre`
      und `max-height: 60dvh` mit Rollen in beide Richtungen.

LUECKEN:

  [traegt-die-seite] Das Tagesdiagramm „Ladezustand über den Tag" fehlt vollständig - und mit ihm
  die Minutenwerte. Die App holt für diese Seite nur `energieUebersicht` und `speicherPruefung`
  (`StromSeite.swift:206-208`); `verlauf`/`verlaufTag` (`Api.swift:133, 147, 155`) wird auf der
  Seite nicht gerufen (gesucht nach `verlauf` in `StromSeite.swift`: kein Treffer). Damit fehlt
  die obere Fläche (Ladestand 0-100 %, `interval 25`, `C.pv`, 2,5 px) und die untere
  (Leistung als Stufenlinie mit Fläche, `splitNumber 2`), die Kopfzeile „oben der Ladezustand,
  unten die Leistung: + Entladen, − Laden" und beide Ausweichsätze für „kein Minutenwert" und
  „nicht die Tagesansicht" (`BatteryReport.tsx:157-161`, `charts.ts:236-276`).

  [traegt-die-seite] Vier der acht Kennzahlen fehlen. Gesucht in `apps/ios/DuckCurveHome` und
  `apps/ios/DuckCurveKit/Sources` nach `Vollzyklen`, `Zyklen`, `Wirkungsgrad`,
  `Verlust im Ger`, `Laut Ladestand`, `batteryDeviceKwh`, `batteryChargeCostEur`,
  `batteryCapacityKwh`: Treffer **nur** in `Modelle/Schema.swift` (2833, 2991, 3012), kein
  einziger in einer Seite oder einem Zustand. Es fehlen: **Vollzyklen**
  (`battery_discharge_kwh / battery_capacity_kwh`, `BatteryReport.tsx:94, 115`),
  **Verlust im Gerät** samt „X € bezahlt · Y € entgangen" (`:138-144`),
  **PV-Anteil Ladung** in Prozent (`:95, 124`) und die **Gegenprobe aus dem Ladestand** bzw. der
  **Wirkungsgrad** als Ausweichkachel (`:96, 125-135`). Die App zeigt stattdessen „Wert der
  Entladung" (`StromSeite.swift:272`), das die Vorlage nur als Hinweis unter „Ersparnis" führt.

  [traegt-die-seite] „Speicher steuern" fehlt auf dieser Seite - und damit die Untergrenze des
  Ladestands überhaupt. Die SpeicherSeite hat keinerlei Bedienung (`StromSeite.swift:200-279`).
  Der einzige Sendeweg der App ist `Batterieblatt` unter Technik
  (`apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:424-549`), und der weicht
  dreifach ab: andere Wörter und andere Modi („Automatik · Halten · Aus", `:504-509`) gegen die
  drei der Vorlage („Auto · Frei · Halten", `BatteryControl.tsx:24-28`), `durationMin: 240` statt
  `120` (`MitteilungenSeite.swift:537` gegen `BatteryControl.tsx:54`), und **`reserveSoc` wird
  nie gesendet** - die Reserve wird dort nur angezeigt (`MitteilungenSeite.swift:462-464`).
  Gesucht nach `Untergrenze` in `apps/ios/DuckCurveHome`: kein Treffer. Der Grund, warum die
  Karte auf diese Seite gehört, steht in `BatteryControl.tsx:12-16` (die Folgen stehen hier) und
  der Grund für die Untergrenze in `:18-22` (die gemessenen 6 % aus dem Netz am 03.09.2026).

  [spuerbar] Der Prüfbericht läuft bei jedem Seitenaufruf und jedem Zeitraumwechsel ungefragt mit,
  und der Absatz, der sagt wozu, fehlt. `StromSeite.swift:207` holt `speicherPruefung` neben den
  Zahlen; die Vorlage holt ihn erst auf Klick, genau deswegen: *„bei einem Jahr über eine halbe
  Million Zeilen. Das ist nichts, was bei jedem Seitenaufruf nebenbei laufen soll"*
  (`SpeicherCheck.tsx:16-17`). Gesucht nach „Stimmt das" in `apps/ios`: kein Treffer - es fehlen
  Kartentitel „Stimmt das?", Knopf „Speicher prüfen" / „liest Minuten ...", der
  vierzeilige Absatz (`SpeicherCheck.tsx:43-49`) und die Fehlerzeile in `--alert`.

  [spuerbar] Der Mehrspannen-Streifen „Speicher im Überblick" fehlt, und mit ihm der Mechanismus.
  `Berichtsseite` holt genau eine Antwort für die gewählte Spanne (`Bericht.swift:52-62`); gesucht
  nach `PeriodStrip`, `Spannenstreifen`, `Überblick` in `apps/ios/DuckCurveHome`: kein Treffer.
  Das Muster existiert in der App, aber nur für Wärme: `WaermeSeite.swift:48-61` holt
  `Spanne.allCases` mit `withTaskGroup` und `try?` je Spanne, `:313-321` stellt sie als
  `Tabelle`-Spalten nebeneinander. Es fehlen die vier Zeilen „Ersparnis netto · Entladen · kWh ·
  Vollzyklen · PV-Anteil" (`BatteryReport.tsx:166-169`), die Kopfzeile „jeweils bis jetzt" und
  der Spaltenkopf „Heute" nur wenn heute (`PeriodStrip.tsx:12-16, 34-38`).

  [spuerbar] Die Balken haben die falschen Farben. Die Vorlage zeichnet „Ladung aus Netz" in
  `C.grid = #e0533d` und „Entladung ins Haus" in `C.battery = #7fa3b3`
  (`apps/web/src/components/charts/palette.ts:36-37`, benutzt `BatteryReport.tsx:18, 20`). Die App
  nimmt `Farbe.netzBezug` = `Marken.mist` = `#7FA3B3` (`Marken.swift:20, 51`) und
  `Farbe.batterie` = `#4F7B88` (`Marken.swift:53`) - **die Netzladung bekommt also genau die Farbe,
  die in der Vorlage die Entladung trägt**, und zwei Bilder derselben Seite widersprechen sich.
  Die richtigen Werte liegen im Kern bereit und werden hier nicht benutzt:
  `Marken.diagrammNetz = 0xE0533D` (`Marken.swift:131`) und
  `Marken.diagrammSpeicher = 0x7FA3B3` (`Marken.swift:135`).

  [spuerbar] Die Methode hat keine Kurzzeile und nicht den Absatz zur Netto-Ersparnis.
  `StromSeite.swift:245-249` ruft `Methode([...])` **ohne `kurz:`** - Datenabdeckung und
  „Aufzeichnung seit" stehen auf dieser Seite nirgends, obwohl sie jede Zahl einschränken und
  obwohl `Bericht.swift:336-343` genau das als Grund nennt, warum der Deckel zugehen darf. Die
  Nachbarseite macht es richtig (`StromSeite.swift:39-42, 52-56`: `abdeckung(_:)` plus
  `meta.dataSince`). Außerdem fehlt der Absatz, der erklärt, was „Geladen" und „Ersparnis netto"
  hier heißen (`BatteryReport.tsx:174`); der eigene Satz der App zur gerechneten Herkunft
  (`StromSeite.swift:247-248`) steht in der Vorlage nicht und ersetzt ihn nicht.

  [spuerbar] Die Kachel „geladen" steht ohne ihre Aufteilung, und „Netzladung ohne PV" ist nur ein
  Nebensatz. Vorlage: „Geladen" trägt den Hinweis „PV x · Netz y kWh" (`BatteryReport.tsx:106`),
  und die Dunkelladung ist eine **eigene Kachel** „Netzladung ohne PV" mit Hinweis „von y kWh
  Netzladung insgesamt" und Ton `ember` ab **0,2 kWh** (`:107-113`). Die App hängt sie als `dazu`
  unter „aus dem Netz geladen" und schaltet die Farbe schon ab **0,05 kWh** auf `Farbe.achtung`
  (`StromSeite.swift:266-271`) - andere Schwelle, andere Stelle, und die Zahl steht nicht in der
  Größe einer Kennzahl da, obwohl der Kopfkommentar der Seite sie zur eigentlichen Frage erklärt
  (`StromSeite.swift:195-199`).

  [klein] Kartentitel und Reihennamen weichen ab: „Woher die Ladung kam" / „Entladung"
  (`StromSeite.swift:212, 224`) gegen „Ladung nach Herkunft" / „Entladung ins Haus"
  (`BatteryReport.tsx:149, 153`); „aus der Sonne" / „aus dem Netz" / „ins Haus"
  (`StromSeite.swift:215, 219, 228`) gegen „Ladung aus PV" / „Ladung aus Netz" / „Entladung ins
  Haus" (`BatteryReport.tsx:17, 18, 20`). Auch die Kachelwörter: „geladen"/„entladen" klein gegen
  „Geladen"/„Entladen", und „unterm Strich" gegen „Ersparnis".

  [klein] Der Seitenkicker fehlt. Die Vorlage schreibt rechts in die Reiterzeile
  „13,5 kWh · Nutzung und Ersparnis" (`BatteryReport.tsx:103`, gesetzt in `AreaNav.tsx:96`, nur ab
  md). `apps/ios/DuckCurveHome/App/Reiterzeile.swift` hat keinen solchen Platz (gesucht nach
  `kicker`, `beiwerk`, `rechts` in der Datei: kein Treffer), und die Kapazität steht auf der Seite
  damit nur mittelbar im Text des Prüfberichts.

  [klein] Der Schätzzusatz an den Herkunftskacheln fehlt. Die Vorlage hängt bei über 5 %
  Stundenmitteln ` · Aufteilung für X % des Zeitraums geschätzt` an „Geladen", „Netzladung ohne
  PV" und „PV-Anteil Ladung" (`BatteryReport.tsx:92-93, 106, 112, 124`), weil genau dort die
  Annahme steckt. Die App liest `coarseMinutes` nicht (gesucht nach `coarseMinutes` in
  `apps/ios/DuckCurveHome`: kein Treffer, Feld liegt in `Schema.swift:2976`); der allgemeine Satz
  steckt nur in `meta.estimatedNoteDe` unter der Methode (`StromSeite.swift:246`).

  [klein] Der Prüfbericht hat keine Höhengrenze und nicht die Maße der Vorlage. Die Vorlage:
  `max-height: 60dvh`, Rollen in beide Richtungen, eigener Grund `rgba(8,36,49,.6)`, Rahmen
  `--line-1`, Radius 6, mono 11,5 px, `line-height 1.55` (`globals.css:604`), am Handy unverändert.
  Die App zeigt ihn in `Schrift.zahlKlein` ohne Grund, ohne Rahmen, ohne Höhengrenze und nur
  waagerecht rollbar (`StromSeite.swift:236-243`) - bei einem Jahresbericht wächst die Karte
  dadurch über die ganze Seite.

KERN: SCHON DA (nachgesehen, nicht geraten):

  * `Api.energieUebersicht(_ zeitraum: String, anker: String) -> EnergySummaryOut`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:179`).
  * `Api.speicherPruefung(_ zeitraum: String, anker: String) -> String` (`Api.swift:210`) - reiner
    Text, wie im Web.
  * `Api.verlauf(_ spanne: Verlaufsspanne = .heute) -> HistoryOut` (`Api.swift:133`),
    `Verlaufsspanne.heute/gestern/letzte24h` (`Api.swift:137-141`),
    `Api.verlaufTag(von:bis:)` (`Api.swift:147`) und `Api.verlaufTag(_ tag: String)`
    (`Api.swift:155`, rechnet die Ortstagsgrenzen selbst über `Tag.zeitraum`).
  * `Api.batterie() -> BatteryLiveOut` (`Api.swift:314`),
    `Api.stelleBatterie(_ befehl: BatteryModeIn) -> BatteryLiveOut` (`Api.swift:318`).
  * `BatteryLiveOut` mit `controlEnabled, mode, endsAt, reserveSoc, soc, command, sentAt,
    lastError, noteDe` (`Modelle/Schema.swift:1517-1538`); `BatteryModeIn(mode:durationMin:
    reserveSoc:)` (`Schema.swift:1567-1582`); `BatteryModeInModeWahl` mit **auto, normal, hold,
    off** (`Schema.swift:107-112`) - die drei Modi der Vorlage sind also alle da.
  * `EnergyTotalsOut` trägt **jedes** Feld, das die Vorlage liest: `minutes`, `coarseMinutes`
    (`Schema.swift:2975-2976`), `batteryChargeKwh`, `batteryDischargeKwh` (`:2980-2981`),
    `batteryToHouseKwh`, `pvToBatteryKwh`, `gridToBatteryKwh` (`:2987, 2989-2990`),
    `batteryDeviceKwh`, `batteryDevicePvKwh`, `batteryDeviceGridKwh`, `gridToBatteryDarkKwh`
    (`:2991-2994`), `batteryDeviceCostEur`, `batteryDeviceOpportunityEur`,
    `batteryDischargeValueEur`, `batteryChargeCostEur`, `batteryNetEur`
    (`:3009-3012, 3022`).
  * `EnergyMetaOut.batteryCapacityKwh`, `.coverage`, `.dataSince`, `.estimatedNoteDe`
    (`Schema.swift:2832-2846`).
  * `HistoryOut` mit `rows: [[String: Mischwert]]` (`Schema.swift:4372-4383`) und
    `Pruefpunkt.ausZeile` / `.raster(_ historie:)`, das `battery_power_kw` und `battery_soc`
    (Anteil 0-1) schon liest (`Zustand/Datenbild.swift:25-81`).
  * `Pruefkurve` mit sechs Reihen samt Ladestand in Prozent, Achsenspanne, `verdichtet(schrittMin:)`
    und `ausschnitt(von:bis:)` (`Zustand/Datenbild.swift:106-180, 219-266, 345, 374`), gezeichnet
    von `Pruefkurvenbild` (`apps/ios/DuckCurveHome/Diagramme/Pruefkurvenbild.swift:18-60`) - das
    Verfahren für „Prozent auf einer zweiten Achse" ist dort schon entschieden (`:13-17`).
  * `Kennzahl(wort:wert:einheit:dazu:ton:)` mit `Ton.normal/sonne/glut/bernstein/gedaempft/nebel`
    (`Zustand/Kennzahl.swift:15-51`), Abbildung auf Farben in `Farbe.ton(_:)`
    (`apps/ios/DuckCurveHome/Gestalt/Farben.swift:98`), Übernahme in die Kachel über
    `Kacheldaten.init(_ k: Kennzahl)` (`Gestalt/Karte.swift:136-138`).
  * `Formate.zahl(_:stellen:)`, `.kwh`, `.prozent`, `.euro`, `.kw`, `.hhmm`
    (`Formate/Formate.swift:44, 75, 81, 99, 62, 124`); `Tag.lang` für „Aufzeichnung seit"
    (benutzt `StromSeite.swift:41`).
  * `Spanne` (`Formate/Zeitraum.swift:9-23`) mit `name` „Tag/Woche/Monat/Jahr" und
    `Spanne.allCases`; `Zeitraum` mit `anker`, `verschoben`, `mit`, `istAktuell`
    (`Zeitraum.swift:26-60`).
  * Oberfläche: `Karte(kicker:titel:beiwerk:)` (`Gestalt/Karte.swift:15-113`),
    `Kachelfeld(kacheln:kicker:ersteFuehrt:spalten:art:)` mit der führenden 48-pt-Kachel
    (`Karte.swift:274-343`, Schriftgrößen `:240, 247`), `Zeile` (`:360-383`),
    `Leer` (`:390-404`), `Stoerung` (`:410-436`), `Methode(_:kurz:titel:)`
    (`Seiten/Bericht.swift:334-397`), `Balkenbild` gestapelt und ungestapelt
    (`Bericht.swift:70-149`), `Tabelle` mit Handy-Umschalter (`Bericht.swift:157-327`),
    `Achse.beschriftungen(_:hoechstens:)` (benutzt `Bericht.swift:137`).
  * Mehrspannen-Abfrage als Vorbild: `WaermeSeite.holeSpannen(anker:api:)` mit `withTaskGroup`
    und `try?` je Spanne (`Seiten/Energie/WaermeSeite.swift:48-61`), Darstellung
    `spannenvergleich(_:)` (`:313-321`).
  * Farben: `Marken.diagrammNetz = 0xE0533D` (`Gestalt/Marken.swift:131`),
    `Marken.diagrammSpeicher = 0x7FA3B3` (`:135`), `Marken.pv = amber = 0xF2A900` (`:18, 50`),
    `Marken.achtung = amber` (`:98`), `Marken.alarm = 0xE0533D` (`:99`),
    `Marken.text1/2/3` (`:43-45`), `Marken.linie1/2`, `Marken.rasterlinie` (`:32-34`),
    `Marken.radius3 = 6` (`:263`).

ES FEHLT:

  1. **Die Kennzahlen des Speichers als Rechnung im Kern.** Neu:
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Speicherbild.swift` mit
     `public enum Speicherbild { public static func kacheln(_ b: EnergySummaryOut,
     ladestand: Ladestandsenergie?) -> [Kennzahl] }` - die acht Kacheln der Vorlage in ihrer
     Reihenfolge, samt `vollzyklen = batteryDischargeKwh / meta.batteryCapacityKwh`,
     `pvAnteilLadung = pvToBatteryKwh / batteryChargeKwh`,
     `wirkungsgrad = min(1, discharge/charge)` erst ab 0,5 kWh Ladung, den Schwellen 0,2 kWh für
     „Netzladung ohne PV" und „Verlust im Gerät", und dem Zusatz
     `„· Aufteilung für X % des Zeitraums geschätzt"` ab `coarseMinutes / minutes > 0.05`.
     Vorbild für Form und Ort: `Zustand/Waermeuebersicht.swift` (gerufen in
     `WaermeSeite.swift:67`). Gründe wie `Kennzahl.swift:5-8`: die Auswahl gehört in den Kern,
     weil sie geprüft werden muss.
  2. **Die Gegenprobe aus dem Ladestand.** Im Kern gibt es nichts dergleichen (gesucht nach
     `socEnergy`, `ladestandEnergie`, `Anstieg` in `apps/ios/DuckCurveKit/Sources` und
     `apps/ios/DuckCurveHome`: kein Treffer). Neu in derselben Datei:
     `public struct Ladestandsenergie: Sendable, Hashable { public let ladung: Double;
     public let entladung: Double; public let punkte: Int }` plus
     `public static func ausLadestand(_ raster: [Pruefpunkt], kapazitaetKwh: Double)
     -> Ladestandsenergie?` - Summe der Anstiege und der Abstiege des Anteils, mal Kapazität,
     `nil` unter zehn Werten oder ohne Kapazität. Wörtlich nachzubauen aus
     `apps/web/src/components/reports/BatteryReport.tsx:29-41`; die dortige Begründung
     (`:22-27`: Energie *im* Speicher, an den Klemmen liegt die Differenz der Verluste) und
     `:85-88` (zwei unabhängige Wege zur selben Zahl) gehören als Doku mit. Es gibt dazu einen
     Test der Vorlage, `apps/web/src/components/reports/socEnergy.test.ts` - die Swift-Fassung
     braucht denselben.
  3. **Die Tageskurve des Speichers als Daten.** `Pruefkurve` ist zu groß (sechs Reihen, eigene
     Prüfseite). Neu: `public struct Speichertagkurve: Sendable, Hashable` mit
     `ladestandProzent: [Kurvenpunkt]`, `leistungKw: [Kurvenpunkt]`, `stunden`, `leistungsspanne`
     und `static func baue(tag: String, historie: HistoryOut?) -> Speichertagkurve`, gebaut über
     das vorhandene `Pruefpunkt.raster(_ historie:)` (`Datenbild.swift:78-80`) und mit
     `verdichtet(schrittMin: 5)` wie `Pruefkurvenbild` (`Pruefkurvenbild.swift:26-30`).
  4. **Die Steuerung als Zustand.** Neu:
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Speichersteuerung.swift` mit
     `public struct Betriebsart { let wahl: BatteryModeInModeWahl; let wort: String;
     let dazu: String }` für genau die drei der Vorlage („Auto", „Frei", „Halten", Texte aus
     `BatteryControl.tsx:24-28`), `public static let untergrenzen: [Double] = [0, 0.06, 0.1, 0.15,
     0.2]` (`BatteryControl.tsx:29`), `public static let frist = 120` Minuten
     (`BatteryControl.tsx:54`), die Abbildung `mode == .off → zeigt .normal`
     (`BatteryControl.tsx:66`) und `public static func zeile(_ s: BatteryLiveOut,
     fehler: String?) -> String` für die zusammengesetzte Notenzeile (`BatteryControl.tsx:69-79`).
  5. **Der Mehrspannen-Abruf als geteilter Baustein.** Es gibt ihn nur als private Methode der
     Wärmeseite (`WaermeSeite.swift:48-61`). Entweder in den Kern heben, etwa
     `public func jeSpanne<T: Sendable>(anker: String, _ hole: @Sendable (Spanne, String) async
     throws -> T) async -> [Spanne: T]`, oder in der Speicherseite dieselben zwölf Zeilen noch
     einmal schreiben. Hochziehen ist die bessere Wahl: die Seiten Wallbox, Kosten, PV und Haus
     brauchen denselben Streifen (`apps/ios/ABGLEICH.md:181-183, 434-435, 504`).

BAUPLAN:

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Speicherbild.swift` neu:
     `Ladestandsenergie`, `ausLadestand(_:kapazitaetKwh:)`, `Speicherbild.kacheln(_:ladestand:)`
     mit den acht Kennzahlen in der Reihenfolge der Vorlage. **Ein Ton fehlt dafür:** die
     Vorlage kennt `ember` = `--alert` = `#E0533D` (`Stat.tsx:5`) für „Netzladung ohne PV",
     „Verlust im Gerät" und die auseinanderlaufende Gegenprobe. `Kennzahl.Ton` hat keinen
     solchen Fall (`Zustand/Kennzahl.swift:38-51`), und `Farbe.ton` bildet auf `Farbe.alarm`
     nirgends ab (`Gestalt/Farben.swift:98-107`: normal→text1, sonne→pv, glut→waermepumpe,
     bernstein→amber, gedaempft→text3, nebel→mist). Also `case warnung` in `Kennzahl.Ton`
     ergänzen und in `Farbe.ton` auf `Farbe.alarm` legen; `amber` der Vorlage ist
     `.bernstein`, `mist` ist `.nebel`, `muted` ist `.gedaempft`.
     Dazu ein Test für `ausLadestand` nach dem Muster
     von `apps/web/src/components/reports/socEnergy.test.ts`.
  2. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Speichertagkurve.swift` neu (Punkt 3
     oben), aufbauend auf `Pruefpunkt`.
  3. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Speichersteuerung.swift` neu (Punkt 4).
  4. Mehrspannen-Abruf: `Api`-Erweiterung oder eine Datei `Netz/Spannenabruf.swift`; danach
     `WaermeSeite.holeSpannen` darauf umstellen, damit es die Rechnung nur einmal gibt.
  5. `apps/ios/DuckCurveHome/Diagramme/Speichertagbild.swift` neu: zwei `Chart` untereinander in
     einem `VStack` - oben Ladestand 0...100 mit `chartYScale(domain:)` und vier Marken bei
     0/25/50/75/100, unten Leistung als `LineMark(interpolation: .stepEnd)` mit `AreaMark`,
     feste Höhen 150 pt oben / 60 pt unten und 34 pt Abstand nach `charts.ts:32-38`; Kopfzeile
     „oben der Ladezustand, unten die Leistung: + Entladen, − Laden" als `titel` der `Karte`.
     Vorbild für die Umsetzung in Swift Charts: `Pruefkurvenbild.swift` und `Diagramme/
     Tageskurve.swift`.
  6. `apps/ios/DuckCurveHome/Bausteine/Speichersteuerkarte.swift` neu: `Karte(kicker: "Speicher
     steuern", titel: "Ladestand 54 %")`, darunter die drei Betriebsarten als
     `Ansichtswahl`-artiger Segmentschalter (`Gestalt/Ansichtswahl.swift`, schon da) und die fünf
     Untergrenzen als Kapselknöpfe (Maße nach `BatteryControl.tsx:88-117`: 44 pt Höhe, min 92 pt
     bzw. 56 pt Breite, aktiv `Farbe.amber`/`Farbe.amberWeich` auf `Farbe.petrol`), unten die
     Notenzeile. Ohne Antwort **gar keine Karte** (`BatteryControl.tsx:63`); bei Gastzugang die
     Griffe gesperrt, wie `MitteilungenSeite.swift:473-477` es schon tut.
  7. `apps/ios/DuckCurveHome/Bausteine/Spannenstreifen.swift` neu: `Karte(kicker:, titel: "jeweils
     bis jetzt" | "jeweils bis 10.11.2026")` mit `Tabelle` am iPad und einer `.spannen`-artigen
     Liste am Telefon - `Tabelle` kann beides schon (`Bericht.swift:157-327`), der Spaltenkopf
     „Heute" nur wenn heute muss dazu (`PeriodStrip.tsx:12-16`).
  8. `apps/ios/DuckCurveHome/Bausteine/Pruefkarte.swift` neu oder als Teil der Seite:
     Karte „Stimmt das?" mit Knopf „Speicher prüfen"/„liest Minuten ...", dem Absatz aus
     `SpeicherCheck.tsx:43-49`, Fehlerzeile in `Farbe.alarm` und dem Bericht in einer
     `ScrollView([.horizontal, .vertical])` mit `frame(maxHeight: 0.6 * Höhe)`, Grund
     `Farbe.deep.opacity(0.6)`, Rahmen `Farbe.linie1`, Radius 6, `Schrift.mono(11.5)`.
  9. `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:200-279` umbauen, Karte für Karte in
     der Reihenfolge der Vorlage:
     a. Abfrage: `energieUebersicht` + (nur in der Tagesspanne) `verlaufTag(z.anker)` bzw.
        `verlauf(.heute)` am laufenden Tag + die vier Spannen; **`speicherPruefung` aus der
        Abfrage herausnehmen** - sie zieht erst der Knopf.
     b. `Kachelfeld(kacheln: Speicherbild.kacheln(b, ladestand: …).map(Kacheldaten.init),
        kicker: "Speicher")`.
     c. `Speichersteuerkarte()`.
     d. Karte „Ladung nach Herkunft" mit `ChartLegend`-Entsprechung (das `Balkenbild` hat die
        Legende oben, das reicht) und den Farben `Farbe.pv` / **`Farbe.diagrammNetz`**.
     e. Karte „Entladung ins Haus", `gestapelt: false`, Farbe **`Farbe.diagrammSpeicher`**.
     f. Karte „Ladezustand über den Tag" mit `Speichertagbild`, samt den beiden Ausweichsätzen.
     g. `Spannenstreifen(kicker: "Speicher im Überblick", …)` mit den vier Zeilen der Vorlage.
     h. `Pruefkarte(spanne:anker:)`.
     i. `Methode([extra-Absatz aus BatteryReport.tsx:174, b.meta.estimatedNoteDe],
        kurz: "Datenabdeckung … · Aufzeichnung seit …")` - `abdeckung(_:)` aus
        `StromSeite.swift:52-56` dafür aus `StromSeite` herausziehen, damit es beide Seiten
        benutzen (am besten als `Speicherbild.abdeckungszeile(_ meta:)` im Kern).
  10. `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:424-549` nachziehen, damit es
      nicht zwei verschiedene Speicher-Bedienungen gibt: dieselben drei Betriebsarten, dieselbe
      Frist, dieselbe Untergrenze - oder das Blatt auf die Seite verweisen lassen.

WAS SCHWIERIG WIRD:

  * **Zwei Flächen mit verschiedenen Einheiten.** Swift Charts kennt keine zweite y-Achse. Das
    Projekt hat sich hier schon entschieden, und zwar zweimal unterschiedlich: `Pruefkurvenbild`
    rechnet die Prozente in die Kilowattachse und setzt die rechte Beschriftung über die
    Umkehrung (`Diagramme/Pruefkurvenbild.swift:13-17`), die Wärmeseite legt zwei getrennte
    `Chart` untereinander (`Diagramme/Waermebilder.swift:184` `Pufferbild`, gerufen
    `WaermeSeite.swift:83`).
    Für dieses Bild ist die Vorlage eindeutig: **zwei Flächen**, mit der Begründung in
    `charts.ts:11-31` („wo sie sich kreuzen, entscheidet allein die Skalierung"). Also zwei
    `Chart` und keine Umrechnung - und die festen Höhen der Vorlage übernehmen, nicht Prozente
    (`charts.ts:24-27`).
  * **Der gemeinsame Achsenzeiger über beide Flächen** (`charts.ts:39, 257`) hat in Swift Charts
    kein Gegenstück; er muss über eine geteilte `@State`-Zeit und `chartOverlay` mit `DragGesture`
    in beiden Charts gebaut werden. Vorbild im Projekt: der Fenstergriff in
    `Pruefkurvenbild.swift` (dort `ausschnitt` als `@State` über `chartOverlay`).
  * **Hinweisfenster am Finger** (`stackedBars`-Tooltip mit Summenzeile, `charts.ts:62-72`) hat
    kein Gegenstück; `Balkenbild` hat heute keines (`Bericht.swift:99-148`). Entweder ohne, wie
    alle anderen Balkenbilder der App, oder nach dem Muster von `Pruefkurvenbild` nachbauen - aber
    dann für alle Balkenbilder, nicht nur hier.
  * **`line-clamp-2` an der Hinweiszeile** (`Stat.tsx:16`) gibt es in SwiftUI als
    `lineLimit(2)`; `Kachel` setzt es schon (`Gestalt/Karte.swift:261`). Die Vorlage begründet die
    zwei Zeilen damit, dass die Kacheln einer Reihe gleich hoch bleiben (`Stat.tsx:13-15`) - bei
    acht Kacheln mit teils langen Hinweisen („0,21 € bezahlt · 0,04 € entgangen") ist das zu
    prüfen, sonst stehen die Zahlen zweier Nachbarinnen nicht auf derselben Linie.
  * **Die Höhengrenze des Prüfberichts** (`max-height: 60dvh`) hat in SwiftUI kein `dvh`; sie muss
    über `GeometryReader` oder eine feste Zahl gesetzt werden. Vorbild: `Alfredblatt`/`Blaetter`
    begrenzen ihre Rollbereiche ähnlich (`apps/ios/DuckCurveHome/Alfred/Alfredblatt.swift`).
  * **Der Seitenkicker** hat in der App keinen Platz: `Reiterzeile.swift` kennt keinen rechten
    Beiwerkslot (gesucht: kein Treffer). Entweder dort einen anlegen - dann betrifft es alle
    dreizehn Berichtsseiten - oder die Kapazität als `titel` der ersten Karte führen, wie
    `WaermeSeite.swift:75` es mit `d.bilanz.resolutionDe` tut.
