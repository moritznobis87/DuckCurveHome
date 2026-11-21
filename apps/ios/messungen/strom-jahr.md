========================= messen:strom-jahr   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

Datei: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift` (201 Zeilen, ganz gelesen).
Eingetragen unter `/strom/jahr` in `apps/ios/DuckCurveHome/App/Seitenwahl.swift:47-48`.
Reiter „Jahreskarte" in `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:112`.

1. `Seite { … }` ohne Zeitraumleiste (`JahreskarteSeite.swift:21`); Rand 16, Abstand 14
   (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:152-167`).
2. Kopfzeile `kopf` (`:51-86`): links eine waagerecht rollbare Reihe von Kapsel-Knöpfen, einer je
   Schlüssel aus `karte.metrics.keys.sorted()` (`:56`) - also **alphabetisch**, nicht in der
   Reihenfolge der Vorlage. Schrift `Schrift.winzig` (11,5 pt,
   `apps/ios/DuckCurveHome/Gestalt/Typografie.swift:46`), aktiv `Farbe.deep` auf
   `Farbe.amberWeich`, sonst `Farbe.text2` auf `Farbe.flaeche2` (`:62-65`), Polsterung 9/4,
   `Capsule()`. Rechts ein Jahresblätterer ‹ / Jahr / › (`:74-84`), Zahl in `Schrift.zahlKlein`
   (12,5 pt mono), „›" abgeschaltet, sobald `jahr` das laufende Jahr ist (`:88-90`).
3. `Stoerung(fehler:)` nur wenn ein Fehler steht (`:23-25`), mit „Erneut"
   (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:410-435`).
4. Eine `Karte(kicker: "<jahr>", titel: name(reihe))` (`:27`) mit
   - `Raster(karte:reihe:)` (`:29`, definiert `:152-201`): **Wochen als Spalten, 7 Wochentage als
     Zeilen**, Kantenlänge 11, Lücke 2, Ecke 1,5, waagerecht rollbar (`:156-173`). Die Farbe
     kommt aus `Farbe.waerme` mit 5 Stufen, Anteil am **Maximum** (`:190-196`), `nil` wird
     `Farbe.linie1` (`:191`).
   - `skala(_:)` (`:127-136`): „wenig" + 5 Rechtecke 16×8 aus `Farbe.waerme` + „viel".
5. `Kachelfeld(kacheln:kicker:"Das Jahr")` (`:33`) mit vier Kacheln aus `kennzahlen(_:)`
   (`:105-125`): „zusammen" bzw. „im Mittel", „Tage mit Werten" = `werte.count`, „bester Tag"
   = `werte.max()`, „Stunden erfasst" = `k.hoursWithData`.
6. `Methode([...])` (`:34-38`): „Daten seit …", „<n> Stunden mit Messwerten.", „Ein Tag ohne
   Messwerte bleibt leer und wird nicht als Null gezeichnet."
7. Solange nichts da ist: `Karte { Leer(satz: "Wird geholt …") }` (`:40`).
8. Laden: `haus.api.jahreskarte(jahr:)` (`:141`), Abfrage `GET /energy/year-map?year=`
   (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:204-206`), ausgelöst über
   `.task(id: jahr)` (`:43`), Startjahr aus `haus.jetzt` (`:45-47`).

**Der tragende Fehler steckt im Datenverständnis.** `YearMapOut.metrics` ist
`[Kennzahl: [Tag][Stunde 0-23]` - so dokumentiert in `apps/api/src/dch_api/schemas.py:607-619`
(Zeile 617: „Kennzahl → [Tag][Stunde 0-23]"), so gebaut in
`apps/api/src/dch_api/application/energy_accounting.py:1304-1315` (äußere Schleife
`for r in range(len(days))`, innere `for c in range(24)`), so getypt in
`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:8880-8885`
(`metrics: [String: [[Double?]]]`, `days: [String]`). `Raster` liest dieselbe Liste als
„Wochenzeilen" mit 7 Spalten (`JahreskarteSeite.swift:175-178`: „Der Dienst liefert sie als
Wochenzeilen.", und `:165` `ForEach(0..<7)`). Gezeichnet werden damit je Tag nur die Stunden 0-6,
in 365 Spalten à 7 Feldern - 70 % der Werte fallen weg, und die Achsen bedeuten etwas anderes
als die Beschriftung behauptet. `karte.days` wird nirgends benutzt (gesucht nach `days` in
`JahreskarteSeite.swift`: kein Treffer außer im Kommentar).

VORLAGE:

Einstieg `apps/web/src/app/strom/jahr/page.tsx:1-7`: rendert nur `<YearMapReport />`,
Dokumenttitel „Jahreskarte · Duck Curve Home".
Alles weitere in `apps/web/src/components/reports/YearMap.tsx:1-141`.

  * **Hülle / Kopf** (`AreaShell`, `apps/web/src/components/layout/AreaShell.tsx:13-30`)
    `main.dashboard-bg.report-main`, `gap-4`, `p-5` (20 px), Textfarbe `--text-1`.
    Kopfband: `min-h-14`, Rahmen `--line-2`, Radius 6, `padding 0 16px`, Hintergrund
    `var(--surface-glass)` = `rgba(8,36,49,.38)` (`tokens.css:26`) mit `backdrop-filter: blur(18px)`.
    Darin Marke, Bereichstitel, fünf Bereichszeichen (`AreaNav.tsx:18-53`), unten `Fussleiste`.
    DATEN: keine.

  * **Reiterzeile mit Kicker** (`AreaTabs`, `apps/web/src/components/layout/AreaNav.tsx:62-99`)
    `AreaShell` gibt `kicker` an `AreaTabs` als `right` weiter (`AreaShell.tsx:24`).
    Der Kicker lautet wörtlich **„365 Tage × 24 Stunden"** (`YearMap.tsx:94`) und steht rechts in
    der Reiterzeile, Klasse `kicker hidden truncate pb-2.5 md:block` mit `fontSize: 11`
    (`AreaNav.tsx:96`). `.kicker` = IBM Plex Mono, 13 px (hier auf 11 übersteuert),
    `letter-spacing .13em`, `uppercase`, Farbe `--text-kicker` = `--mist` = `#7fa3b3`
    (`apps/web/src/styles/globals.css:57-64`, `tokens.css:15,35`).
    **Handy: der Kicker fällt weg** - `hidden … md:block` greift unter 768 px (`AreaNav.tsx:96`).
    DATEN: keine.

  * **Jahreswahl, rechts im Kopfband** (`YearMap.tsx:94-100`)
    Vier Knöpfe, `thisYear - 0…3` (`:91`), `role="tablist"`, `aria-label="Jahr"`.
    Rahmen `--line-2`, Radius 4, `p-1`, Abstand 1 (`gap-1`).
    Knopf: `mono`, 12 px, `px-3 py-1.5`, Radius 3; aktiv Hintergrund `var(--amber)` (#f2a900) mit
    Text `var(--petrol)` (#0f2e3d), sonst durchsichtig mit `var(--text-2)` (`:96`).
    Es gibt **kein** Blättern ‹ ›, und kein Jahr vor `thisYear-3`.
    DATEN: setzt `year`, löst `api.energyYearMap(year)` neu aus (`:42-57`).

  * **Fehlerband** (`ErrorBanner`, `apps/web/src/components/reports/ReportShell.tsx:147-153`)
    Steht **über** allem anderen im Inhalt (`YearMap.tsx:102`), ersetzt nichts.
    `mono`, 12 px, `uppercase`, `letter-spacing .1em`, Radius 3, `px-4 py-3`,
    Rahmen `rgba(224,83,61,.4)`, Fläche `rgba(224,83,61,.12)`, Text `var(--alert)` = `#e0533d`
    (`tokens.css:64`).
    Texte wörtlich (`YearMap.tsx:29-32`): bei 401/403 **„Nicht angemeldet - bitte Gerät koppeln."**,
    sonst die Meldung des `ApiError`, sonst **„Daten konnten nicht geladen werden."**

  * **Kennzahlleiste - acht Knöpfe** (`YearMap.tsx:104-120`, Liste `:16-25`)
    `flex flex-wrap gap-1.5`, `role="tablist"`, `aria-label="Kennzahl"`.
    Knopf: Rahmen 1 px, Radius 3, `px-3 py-1.5`, **13 px**, `aria-pressed`.
    Aktiv: Rahmen und Text `var(--amber)`, Fläche `rgba(242,169,0,.10)`;
    sonst Rahmen `var(--line-2)`, Text `var(--text-2)` (`:111-115`).
    Reihenfolge und Beschriftung wörtlich, **Vorgabe ist die erste** (`:37`
    `useState<MetricKey>("grid_net_kwh")`):
      1. `grid_net_kwh` → „Netz", kWh, `RAMP_NET`, **divergierend**, 2 Stellen
      2. `pv_kwh` → „Erzeugung", kWh, `RAMP_OWN`
      3. `house_kwh` → „Verbrauch", kWh, `RAMP_GRID`
      4. `heat_pump_kwh` → „Wärmepumpe", kWh, `RAMP_HEAT`
      5. `import_kwh` → „Netzbezug", kWh, `RAMP_GRID`
      6. `export_kwh` → „Einspeisung", kWh, `RAMP_OWN`
      7. `price_ct_kwh` → „Strompreis", **ct/kWh**, `RAMP_GRID`, **1 Stelle**
      8. `autarky` → „Autarkie", **ohne Einheit**, `RAMP_OWN`, 2 Stellen
    Die Schlüssel sind genau die acht aus `apps/api/src/dch_api/schemas.py:595-604` (`YearMetric`).
    Begründung im Kommentar (`YearMap.tsx:13-15`), die in die App gehört: „Farbzuordnung wie im
    Energiefluss: Bernstein für eigene Energie, Mist für das Netz, Terrakotta für die Wärmepumpe.
    Wer den Energiefluss gelesen hat, liest die Karte ohne Umlernen."
    DATEN: wählt `data.metrics[metric]` (`:60`).

  * **Die Karte selbst** (`YearMap.tsx:124-129`)
    `Card` mit **inline** `padding: 16` und `height: clamp(360px, calc(100dvh - 250px), 780px)`.
    Kommentar `:122-123`, der die Begründung nennt und beim Umbau nicht verloren gehen darf:
    „Feste Höhe, keine Flex-Höhe: `height: 100%` im Chart löst sich sonst gegen eine unbestimmte
    Elternhöhe auf und die Karte fällt auf eine Linie zusammen."
    `Card` sonst (`apps/web/src/styles/globals.css:67-77`): Fläche `--surface-2` = `#123544`,
    Rahmen 1 px `--line-1` = `rgba(255,255,255,.10)`, Radius `--radius-2` = **3 px**, `overflow: hidden`.
    `CardHead` (`apps/web/src/components/ui/Card.tsx:20-28`): links `h2.kicker` = der Name der
    Kennzahl (`active.label`), rechts die **Einheit** in 12 px `--text-3`; bei leerer Einheit
    (Autarkie) fällt rechts weg (`YearMap.tsx:125`).
    Zustände (`:127`):
      - lädt und nichts da: `<Note>` **„Jahr wird geladen …"**
      - `data.hours_with_data === 0`: `<Note>` **„Für {year} liegen keine Stundenwerte vor."**
      - sonst `<EChart option={option} onKlick={zurWiedergabe} className="cursor-pointer" />`
    DATEN: `data.hours_with_data`, `data.days`, `data.metrics[metric]`.

  * **Das Bild: `yearMap(...)`** (`apps/web/src/components/reports/charts.ts:426-547`)
    Heatmap, **x = Tag (365 Kategorien aus `days`), y = Stunde 0-23**, `inverse: true`, also
    00:00 oben - Begründung im Code (`:511`): „00:00 oben, wie ein Tagesplan gelesen wird".
    Nur Zellen mit Zahl kommen in die Reihe; `null` wird übersprungen und zeigt die Kartenfläche
    (`:447-455`, Kommentar `:450`: „null heißt „keine Messdaten" - die Zelle bleibt leer").
    Gitter: `left 44, right 16, top 38, bottom 34` (`:486`).
    x-Achse: Beschriftung **nur an Monatsanfängen** (`:460-462, 504-506`), Namen aus
    `MONTHS = ["Jan","Feb","Mär","Apr","Mai","Jun","Jul","Aug","Sep","Okt","Nov","Dez"]` (`:415`),
    10 px, Achsenlinie `C.axis`, keine Ticks, keine Splitlines.
    y-Achse: jede sechste Stunde beschriftet (`interval i % 6`), Format `HH:00`, 10 px (`:515`).
    Skala `visualMap` (`:517-537`): stetig, **senkrecht rechts oben** (`right: 8, top: 0`),
    `itemWidth 12`, `itemHeight 190`, `calculable: true`, Format `de1(v, bound < 5 ? 1 : 0)` plus
    Einheit; bei der divergierenden Karte tragen die Pole die Worte **„Bezug"** und
    **„Einspeisung"** (`:532`), `textGap 8`, 10 px mono.
    Obergrenze: **98. Perzentil**, nicht das Maximum (`robustMax`, `:417-424`), bei divergierend
    über den Absolutwerten und symmetrisch `-bound … +bound` (`:457-459`); bei sequenziell nur
    über den Werten > 0. Begründung `:417-419`: „Ein einzelner Ausreißer - ein Ladevorgang, ein
    Defekt - zöge sonst die ganze Skala zusammen und färbte das restliche Jahr einheitlich dunkel."
    Rampen (`:409-413`), sechs bzw. sieben Stopps, in OKLab interpoliert (Kommentar `:401-408`):
      `RAMP_OWN  = #123544 #6a6448 #c39234 #f5b22e #fac558 #ffd778`
      `RAMP_GRID = #123544 #3c5f6e #688c9b #93b1bf #bbced7 #e4ecef`
      `RAMP_HEAT = #123544 #655c57 #b68365 #e5a17a #eeb797 #f6cdb4`
      `RAMP_NET  = #f2a900 #ac833b #695f44 #2b3a41 #4c646e #70909f #96c0d3`
    Der dunkelste Schritt **ist** `--surface-2` (#123544), damit „fast nichts" mit der Fläche
    verschmilzt (Kommentar `:404-405`); bei `RAMP_NET` ist die Mitte flächennah und beide Pole
    gleich hell (`:406-407`).
    Hinweisfenster (`:467-483`): drei Zeilen - Datum als „Di., 10. Februar 2026"
    (`toLocaleDateString("de-DE", {weekday:"short", day:"2-digit", month:"long", year:"numeric"})`),
    dann **„HH:00 - HH:59"**, dann Wert mit Einheit in `digits` Stellen, dann blass
    **„Klick öffnet die Wiedergabe dieser Stunde"** (`YearMap.tsx:68`).
    Hervorhebung: 1 px Rahmen `rgba(255,255,255,.85)` (`charts.ts:543`), `animation: false`,
    `progressive: 4000`.
    DATEN: `days: string[]`, `grid: (number|null)[][]` aus `data.metrics[metric]`.

  * **Klick auf ein Feld führt in die Wiedergabe** (`YearMap.tsx:72-84`)
    `EChart.onKlick` liefert Datenkoordinaten des Gitters (`apps/web/src/components/charts/EChart.tsx:58-63`:
    `convertFromPixel({gridIndex: 0})`, NaN am Rand verworfen). Daraus
    `router.push("/waerme/wiedergabe?day=" + days[round(x)] + "&t=" + round(y))`, Stunde auf
    0…23 geprüft (`:78-81`). Zeiger `cursor-pointer` (`:127`).
    Begründung, die mit umziehen muss (`:72-74`): „Aus der Übersicht in den Augenblick: ein Feld
    ist ein Tag und eine Stunde, und die Wiedergabe kann genau dort beginnen. Die Karte zeigt,
    *dass* an einem Dienstag im Februar etwas anders war; die Wiedergabe zeigt, was."

  * **Fußnote** (`Note`, `YearMap.tsx:131-138`)
    `<p>`, 12 px, Zeilenhöhe 1,55, `max-w-[90ch]`, Farbe `--text-3` = `rgba(255,255,255,.48)`
    (`ReportShell.tsx:143-145`, `tokens.css:34`). Ein Fließtext aus vier Teilen:
      1. `active.hint` + „. " - die Sätze wörtlich (`YearMap.tsx:17-24`):
         Netz: „Bezug (hell blau) gegen Einspeisung (bernstein) - die Entenkurve über ein ganzes Jahr"
         Erzeugung: „Wann die Anlage lieferte: Tageslänge und Wetter, Tag für Tag"
         Verbrauch: „Der Rhythmus des Hauses - Wochentage, Urlaube, Gewohnheiten"
         Wärmepumpe: „Heizperiode, Warmwasserspitzen und die Taktung der Regelung"
         Netzbezug: „Nur der Bezug, ohne Verrechnung mit der Einspeisung"
         Einspeisung: „Überschuss, der ins Netz ging"
         Strompreis: „Der bezugsgewichtete Preis je Stunde - die Struktur, gegen die geplant wird"
         Autarkie: „Anteil des Verbrauchs, der nicht aus dem Netz kam (0-1)"
      2. immer: „Jede Zelle ist eine Stunde in Ortszeit; leere Zellen sind Lücken in der
         Aufzeichnung, keine Nullwerte."
      3. mit Daten: „ <hours_with_data> von <days.length × 24> Stunden erfasst." (`de1(…, 0)`)
      4. mit Werten: „ Werteumfang <min> bis <max> <Einheit>; die Farbskala endet beim 98.
         Perzentil, damit einzelne Ausreißer nicht das ganze Jahr einfärben." - min/max über
         **alle** Zellen, 2 Stellen (`:85-89, 137`).
    DATEN: `hours_with_data`, `days.length`, Minimum/Maximum des gewählten Rasters.

  * **(Handy-Fassung, wo sie abweicht)**
    `apps/web/src/styles/handy.css`, Block `@media (max-width: 720px)` ab `:107`, geprüft auf
    jede Klasse, die diese Route benutzt:
      - `.dashboard-bg { background: var(--deep) }` (`:109`) - kein Verlauf, kein Raster.
      - `.report-main { padding: 10px 16px calc(86px + safe-area); gap: 14px; font-size: 15px }`
        (`:110-111`) - statt 20 px Rand und `gap-4`.
      - Bereichsleiste wandert **nach unten**, fest (`.fussleiste`, `:114-134`), 86 px Platz unten.
      - `.report-header` verliert Rahmen, Radius, Glas und Weichzeichner (`:137`), `padding: 4px 0 0`,
        `min-height: 0`; die fünf Bereichszeichen im Kopf werden ausgeblendet (`:139`), der
        Markenname ebenso (`:140`); `.bereichstitel` wird 26 px halbfett sichtbar (`:141`).
      - `.report-header-right { display: contents }` (`:148`): der Kasten löst sich auf, die
        Jahreswahl wird direktes Kind des Kopfes mit `order: 2; flex: 1 1 100%` (`:149`) -
        **sie steht am Handy als eigene, volle Zeile unter dem Bereichsnamen**, nicht rechts neben ihm.
      - `.area-tabs { margin: 0 -16px }`, `.area-tabs-row` rollt waagerecht mit Maske
        (`:164-173`), `.area-tab` wird eine Pille: `padding 9px 15px`, Radius 999,
        Fläche `rgba(255,255,255,.07)`, 14 px; aktiv `background: var(--text-1); color: var(--deep);
        font-weight: 600` (`:174-175`). Der aktive Reiter wird eingerollt (`AreaNav.tsx:70-78`).
      - **Der Kicker „365 Tage × 24 Stunden" ist am Handy nicht zu sehen** (`AreaNav.tsx:96`,
        `hidden … md:block`) - keine Regel in `handy.css` holt ihn zurück (gesucht nach `kicker`
        in `handy.css`: Treffer nur `:184` `.card-head h2.kicker` und `:201` `.kpi-grid > .card > .kicker`).
      - `.card { border: 0; border-radius: 16px; padding: 16px }` (`:182`) - **aber** `YearMap`
        setzt `padding` und `height` inline (`YearMap.tsx:124`), inline schlägt die Regel, also
        bleibt die Höhe `clamp(360px, 100dvh - 250px, 780px)` auch am Handy.
      - `.card-head h2.kicker` wird **lesbare Schrift statt Sperrschrift**: `var(--font-sans)`,
        16,5 px, 600, `letter-spacing -.01em`, `text-transform: none`, Farbe `--text-1` (`:184`) -
        aus „NETZ" wird „Netz". `.card-head-right` nimmt eine eigene Zeile, 13 px (`:185`).
      - Kleinschrift eine Stufe größer, nur innerhalb `.report-main` (`:189-192`):
        10→11, 11→12, **12→13,5**, **13→14,5**. Trifft die Kennzahlknöpfe (13 px → 14,5 px) und
        die Fußnote (12 px → 13,5 px).
      - `.methode > summary .kicker` ebenfalls lesbar, 15 px (`:214`) - betrifft diese Route erst,
        wenn sie eine `Methode` bekommt; sie hat keine.
      - Diagramme: `fuerHandy` (`apps/web/src/components/charts/handy.ts:44-63`) hebt die
        Achsenschrift auf **mindestens 11 px** und setzt `hideOverlap: true` (`:29-42`), und
        `tooltip.confine: true` (`:61`). Zu `visualMap` tut es nichts.
        `EChart` ersetzt beim Wechsel der Kennzahl `visualMap` statt zu mischen
        (`EChart.tsx:77-81`, Kommentar `:78-79`: sonst „bliebe die Beschriftung der alten Pole
        stehen") - dieselbe Falle gilt in SwiftUI nicht, der Grund aber schon: Pole nur bei
        `grid_net_kwh`.
      - Die kompakte Fassung des Bildes (`xLabel: "day"`, waagerechte Skala oben,
        `charts.ts:434-442, 486, 523`) wird von **dieser** Route nicht benutzt - sie gehört der
        Abdeckungskarte. Gesucht nach `xLabel` in `YearMap.tsx`: kein Treffer.

LUECKEN:

  [traegt-die-seite] Die App zeichnet das falsche Raster. Die Vorlage ist 365 Tage × 24 Stunden
    (`charts.ts:401`, `:447-455`, `schemas.py:607-617`); `Raster` zeichnet 7 Zeilen je Spalte und
    nennt sie Wochentage (`JahreskarteSeite.swift:165, 175-178`). Damit sind die Stunden 7-23 jedes
    Tages gar nicht im Bild, und das Bild sagt etwas anderes, als es zeigt. `karte.days` bleibt
    ungenutzt.
  [traegt-die-seite] Keine Achsen. Die Vorlage beschriftet Monatsanfänge unten (`charts.ts:504-506`,
    `MONTHS` `:415`) und jede sechste Stunde links (`:515`), 00:00 oben. In der App gibt es keine
    Beschriftung - gesucht nach `achse`, `MONTHS`, `Monat` in `JahreskarteSeite.swift`: kein Treffer.
  [traegt-die-seite] `grid_net_kwh` fehlt als eigene, divergierende Darstellung. Es ist die Vorgabe
    der Vorlage (`YearMap.tsx:37`) und die einzige Kennzahl, die „die Entenkurve über ein ganzes
    Jahr" zeigt (`:17`); sie braucht `RAMP_NET`, eine um null symmetrische Skala und die Pole
    „Bezug"/„Einspeisung" (`charts.ts:457-459, 532`). Die App färbt alles mit `Farbe.waerme` und
    einer Skala von 0 bis Maximum (`JahreskarteSeite.swift:190-196`), also erscheint Einspeisung
    als „wenig" statt als anderer Pol.
  [traegt-die-seite] Keine Farbrampe je Kennzahl. Vier Rampen mit je 6-7 Stopps (`charts.ts:409-413`)
    gegen eine Skala aus 5 (`Marken.swift:164-166`), und die Zuordnung Bernstein = eigene Energie /
    Mist = Netz / Terrakotta = Wärmepumpe (`YearMap.tsx:13-15`) existiert in der App nicht.
  [traegt-die-seite] Kein Klick in die Wiedergabe. In der Vorlage führt jedes Feld nach
    `/waerme/wiedergabe?day=…&t=…` (`YearMap.tsx:76-84`). `WiedergabeSeite` gibt es
    (`apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:155`), aber die Wegetafel
    verwirft den Fragezeichenteil (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:99-104`) und
    `WiedergabeSeite` setzt den Tag selbst auf gestern (`SystemSeiten.swift:188`) und kennt keine
    Stunde (gesucht nach `t=`, `stunde`, `anfang` in `SystemSeiten.swift:155-300`: kein Treffer).
    Ohne das verliert die Seite ihre zweite Hälfte: sie zeigt, *dass* etwas war, und nichts führt
    zu *was*.
  [traegt-die-seite] Keine Obergrenze beim 98. Perzentil. `Raster.farbe` nimmt das Maximum
    (`JahreskarteSeite.swift:192`); genau davor warnt `robustMax` (`charts.ts:417-424`). Ein
    einziger Ladevorgang färbt das Jahr einheitlich dunkel.
  [traegt-die-seite] Die vier Kacheln sind falsch gerechnet und stehen nicht in der Vorlage.
    `kennzahlen` zählt Stundenzellen und nennt sie „Tage mit Werten", und das Maximum einer
    **Stunde** heißt „bester Tag" (`JahreskarteSeite.swift:117-122`). Die Vorlage hat dort kein
    Kachelfeld; was sie sagt, steht in der Fußnote und ist der **Werteumfang** min…max
    (`YearMap.tsx:85-89, 137`).

  [spuerbar] Beschriftung und Reihenfolge der acht Knöpfe. Vorlage: Netz, Erzeugung, Verbrauch,
    Wärmepumpe, Netzbezug, Einspeisung, Strompreis, Autarkie, in dieser Folge
    (`YearMap.tsx:16-25`). App: alphabetisch nach Schlüssel (`:56`) und eigene Worte „aus der
    Sonne", „im Haus", „aus dem Netz", „eingespeist" (`:93-102`).
  [spuerbar] `price_ct` in `name(_:)` (`JahreskarteSeite.swift:100`) ist ein toter Fall. Der
    Schlüssel heißt `price_ct_kwh` (`schemas.py:602`, `YearMap.tsx:23`); die App zeigt deshalb
    „price ct kwh" (Rückfall `:101`).
  [spuerbar] Keine Einheit je Kennzahl und keine Stellenzahl. Vorlage: kWh, **ct/kWh** beim Preis
    (1 Stelle), nichts bei Autarkie (2 Stellen) (`YearMap.tsx:17-24`), rechts in `CardHead`
    (`:125`). App: `Karte(kicker: jahr, titel: name)` ohne Einheit (`:27`), Kacheln immer „kWh"
    außer bei Autarkie (`:115, 121`).
  [spuerbar] Kein Hinweisfenster am Finger. Vorlage: Wochentag + Datum + „HH:00 - HH:59" + Wert +
    Einheit + Klickzeile (`charts.ts:467-483`). App: nichts, die Felder sind sogar für die
    Lesehilfe versteckt (`JahreskarteSeite.swift:185`).
  [spuerbar] Kein `visualMap`, nur eine Legende ohne Zahlen. Vorlage: senkrechtes Band rechts
    oben, 12×190, mit Zahlen und Einheit, bei Netz mit den Polwörtern (`charts.ts:517-537`).
    App: „wenig" / 5 Kästchen / „viel" (`JahreskarteSeite.swift:127-136`).
  [spuerbar] Keine Fußnote. Der Erklärsatz je Kennzahl, der Satz über Ortszeit und Lücken, die
    Stundenabdeckung und der Werteumfang (`YearMap.tsx:131-138`) fehlen; die App hat stattdessen
    eine zugeklappte `Methode` mit drei anderen Sätzen (`JahreskarteSeite.swift:34-38`).
  [spuerbar] Jahreswahl in anderer Gestalt. Vorlage: vier Jahresknöpfe `thisYear-0…3`, aktiv
    amber auf petrol, Rahmen `--line-2`, Radius 4/3, 12 px mono (`YearMap.tsx:91-99`).
    App: ‹ Jahr › ohne untere Grenze (`JahreskarteSeite.swift:74-84`).
  [spuerbar] Kein eigener Zustand für „Jahr ohne Stundenwerte". Vorlage prüft
    `hours_with_data === 0` und schreibt „Für {year} liegen keine Stundenwerte vor."
    (`YearMap.tsx:127`). App zeigt dann ein leeres Raster (`:26-32`).
  [spuerbar] Höhe und Polsterung der Bildkarte. Vorlage: `padding 16`,
    `height: clamp(360px, 100dvh - 250px, 780px)` (`YearMap.tsx:124`), auch am Handy (inline
    schlägt `handy.css:182`). App: `Karte` mit Polsterung 16/14 und der Höhe, die das Raster
    vorgibt - 7 × 11 + 6 × 2 = 89 Punkte (`JahreskarteSeite.swift:156-157`,
    `apps/ios/DuckCurveHome/Gestalt/Karte.swift:33`).
  [spuerbar] Der Kicker der Reiterzeile fehlt: „365 Tage × 24 Stunden" (`YearMap.tsx:94`), am
    Rechner sichtbar, am Handy ausgeblendet (`AreaNav.tsx:96`). Gesucht nach „365" in
    `apps/ios/DuckCurveHome`: kein Treffer.
  [spuerbar] Fehlertexte. Vorlage: „Nicht angemeldet - bitte Gerät koppeln." bei 401/403, sonst
    „Daten konnten nicht geladen werden." (`YearMap.tsx:29-32`). App: `fehler.rat` aus `ApiFehler`
    (`Karte.swift:418`) - gesucht nach „Gerät koppeln" in `apps/ios/DuckCurveKit`: zu prüfen beim
    Umbau, in `JahreskarteSeite.swift` steht nichts davon.

  [klein] Ladesatz. Vorlage „Jahr wird geladen …" (`YearMap.tsx:127`), App „Wird geholt …"
    (`JahreskarteSeite.swift:40`).
  [klein] Kopf der Bildkarte. Vorlage: Name der Kennzahl links als `kicker`, Einheit rechts
    (`YearMap.tsx:125`). App: Jahr als Kicker, Name als Titel (`:27`) - also das Jahr zweimal,
    weil es schon im Blätterer steht.
  [klein] Zellenform. Vorlage: keine Lücke zwischen den Zellen, Hervorhebung durch 1 px weißen
    Rahmen (`charts.ts:538-544`); App: Lücke 2, Radius 1,5 (`JahreskarteSeite.swift:157, 182`).
    Die Abdeckungskarte der App hat denselben Radius 1,5 bei Lücke 1
    (`apps/ios/DuckCurveHome/Diagramme/Abdeckungskarte.swift:39-40, 143`) - das ist das Maß, das
    im Projekt für dieselbe Sache schon gewählt wurde.
  [klein] Leere Zelle. Vorlage: keine Farbe, die Kartenfläche bleibt stehen (`charts.ts:450-451`);
    App: `Farbe.linie1`, also ein aufgehellter Kasten (`JahreskarteSeite.swift:191`) - eine Lücke
    sieht damit heller aus als „fast nichts", und der eigene Kommentar `:188-189` will genau das
    nicht.
  [klein] Monatsnamen. Vorlage: „Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez" ohne Punkt
    (`charts.ts:415`); der Kern hat „Jan. Feb. März Apr. … Sept. …" mit Punkt
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Zeit.swift:140-142`).
  [klein] Rundung in der Fußnote. Vorlage: Stundenzahlen 0 Stellen, Werteumfang 2 Stellen,
    Skalenbeschriftung 1 Stelle unter 5 und sonst 0 (`YearMap.tsx:136-137`, `charts.ts:535`).

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `YearMapOut` - `year: Int`, `days: [String]`, `metrics: [String: [[Double?]]]`,
    `hoursWithData: Int`, `dataSince: String?`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:8880-8901`).
    Die Achsen stehen fest: `[Tag][Stunde 0-23]` (`apps/api/src/dch_api/schemas.py:607-619`).
  * `Api.jahreskarte(jahr:) async throws -> YearMapOut`, `GET /energy/year-map?year=`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:204-206`). Nichts Neues nötig.
  * `ApiFehler` mit `rat` und `code`, dazu `Stoerung` als Band über der Seite
    (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:410-435`).
  * `Marken.waerme` (5 Stopps, `Gestalt/Marken.swift:164-166`), `Marken.abdeckung` (3 Stopps,
    `:220-222`), `Marken.pufferschichten` (`:159-161`). Keine der vier Rampen der Jahreskarte.
  * `Marken.abdeckungsfarbe(anteil:)` (`Gestalt/Marken.swift:231-242`) - das Vorbild für eine
    stetige Rampe: Anteil 0…1 auf `n` Stopps legen und zwischen zwei Stopps `gemischt(mit:anteil:)`.
    Lässt sich wortgleich auf eine beliebige `[Farbwert]` verallgemeinern.
  * `Farbwert.gemischt(mit:anteil:)` - benutzt in `Marken.swift:240-241`.
  * `Formate.zahl(_:stellen:)` (`Formate/Formate.swift:44`), `Formate.prozent(_:)` (`:81-84`),
    `Formate.kwh(_:)` (`:75-78`), `Formate.leer = "-"` (`:27`).
  * `Tag.plus`, `Tag.abstand`, `Tag.lang`, `Tag.kurz`, `Tag.tagMonat`
    (`Formate/Tag.swift:50, 73, 87, 94, 106`); `Zeit.monat(_:kurz:)`, `Zeit.wochentag(_:kurz:)`
    (`Formate/Zeit.swift:145-153`).
  * `Abdeckungsraster` im Kern (`Zustand/Datenbild.swift:740-815`) - das Vorbild für ein
    Rastermodell: Tage als Spalten, 24 Stunden je Spalte, `nil` bleibt `nil`, Farbe als
    `Farbwert?` mit fester Skala und begründeter Rampe.
  * `Abdeckungskarte` (`apps/ios/DuckCurveHome/Diagramme/Abdeckungskarte.swift:27-197`) - die
    fertige Oberfläche für genau diese Form: `Canvas` je Raster (`:65-68`), senkrechte
    Stundenachse mit `i % 6` und 24 tragenden Zeilen (`:102-114`), gezeichnete Tagesachse mit
    `schritt = round(tage/10)` (`:155-170`), Skala als `LinearGradient` über die Rampe (`:180-196`),
    Stundenwort „06:00" am iPad und „06" am Telefon (`:116-119`). Begründung gegen 2000
    Einzelansichten steht dort (`:23-26`).
  * `Zeitraum`/`Spanne` und die Zeitraumleiste - **braucht diese Seite nicht**: die Vorlage gibt
    `AreaShell` kein `period`/`anchor` (`YearMap.tsx:94`), und `Bereiche.spannen(fuer: "/strom/jahr")`
    ist beim Reiter nicht gesetzt (`Bereiche/Bereiche.swift:112`).
  * Oberfläche: `Seite` (`App/Seitenwahl.swift:136-170`), `Karte`/`Kicker`
    (`Gestalt/Karte.swift:15-104`, `Gestalt/Typografie.swift:132-141`), `Leer`
    (`Karte.swift:390-404`), `Methode` (`Seiten/Bericht.swift:334-396`), `Umbruchzeile`,
    `Schrift.achse` 10,5 pt mono (`Gestalt/Typografie.swift:101`), `Schrift.winzig` 11,5
    (`:46`), `Schrift.klein` 13 (`:45`), `Schrift.zahlKlein` 12,5 (`:70`),
    `Schrift.sans(_:relativeTo:)` / `Schrift.mono(_:)` für Zwischengrößen (`:86-92`).
  * Farben: `Farbe.flaeche2` = #123544 (`Marken.swift:29`), `Farbe.linie1` / `linie2`
    (`:32-33`), `Farbe.amber` #F2A900 (`:18`), `Farbe.amberWeich` #FFD778 (`:19`),
    `Farbe.deep` #082431 (`:17`), `Farbe.text1/2/3` (`:43-45`), `Farbe.kicker` = mist
    (`apps/ios/DuckCurveHome/Gestalt/Farben.swift:51`), `Marken.radius2 = 3`, `radius3 = 6`
    (`Marken.swift:262-263`).
  * `Wegweiser.gehe(_:)` (`App/Navigation.swift:35-37`) und die Wegetafel
    (`App/Seitenwahl.swift:30-104`) - Wege ohne Fragezeichenteil.
  * Swift Charts ist im Projekt eingeführt (`import Charts` in sechs Diagrammen, u. a.
    `Diagramme/Tageskurve.swift`), mit Fadenkreuz über `ChartProxy.value(atX:)` und
    `DragGesture(minimumDistance: 0)` (`Tageskurve.swift:382-401`) - das Vorbild für „Finger auf
    einer Fläche in Datenkoordinaten umrechnen".

ES FEHLT:

  1. Die vier Rampen der Jahreskarte im Kern, mit den Stopps aus `charts.ts:409-413` und der
     Begründung von dort (dunkelster Schritt = Kartenfläche; divergierend mit flächennaher Mitte
     und gleich hellen Polen). Vorschlag: in
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift` neben `waerme`:
     `public static let rampeEigen: [Farbwert]`, `rampeNetz: [Farbwert]`,
     `rampeWaerme: [Farbwert]`, `rampeNetzBilanz: [Farbwert]`.
  2. Eine allgemeine stetige Rampenfarbe: `Marken.rampenfarbe(_ rampe: [Farbwert], anteil: Double)
     -> Farbwert` - derselbe Körper wie `abdeckungsfarbe` (`Marken.swift:231-242`), nur mit der
     Rampe als Argument; `abdeckungsfarbe` ruft sie dann auf.
  3. Ein Rastermodell für die Jahreskarte, nach dem Vorbild von `Abdeckungsraster`. Vorschlag:
     neue Datei `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Jahreskarte.swift` mit
     `public struct Jahresraster: Sendable`:
       - `public let jahr: Int`, `public let tage: [String]`,
         `public let zellen: [[Double?]]` (Tag × Stunde, aus `metrics[schluessel]`),
       - `public let kennzahl: Jahreskennzahl`,
       - `public let stundenMitWerten: Int`, `public let datenSeit: String?`,
       - `public let grenze: Double` (98. Perzentil, divergierend über `abs`),
         `public let kleinster: Double?`, `public let groesster: Double?`,
       - `public static func baue(_ aus: YearMapOut, kennzahl: Jahreskennzahl) -> Jahresraster`,
       - `public func farbe(tag: Int, stunde: Int) -> Farbwert?` (`nil` = keine Messdaten),
       - `public func hinweis(tag: Int, stunde: Int) -> Zellenhinweis?` mit Datum, „HH:00 - HH:59",
         Wert und Einheit,
       - `public var monatsanfaenge: [(spalte: Int, name: String)]` für die x-Achse,
       - `public var fussnote: String` - der Fließtext aus `YearMap.tsx:131-138`, Teil für Teil.
  4. `public enum Jahreskennzahl: String, CaseIterable, Sendable` - die acht Fälle **in der
     Reihenfolge der Vorlage** (`grid_net_kwh` zuerst) mit `name`, `einheit`, `stellen`, `rampe`,
     `divergierend`, `hinweis`, Rohwerte = die Schlüssel aus `schemas.py:595-604`. Ersetzt
     `JahreskarteSeite.name(_:)` samt dem toten `price_ct`.
  5. Das 98. Perzentil als Rechnung im Kern: `static func robusteGrenze(_ werte: [Double]) -> Double`
     nach `charts.ts:420-424` (sortieren, Index `floor(n * 0.98)`, Vorgabe 1 bei leer),
     dazu die drei Fälle aus `apps/web/src/components/reports/yearMap.test.ts:14-36` als Prüfungen
     (Lücken bleiben weg, Ausreißer kappt die Skala, divergierend symmetrisch, leeres Jahr endlich).
  6. Ein Ziel mit Tag und Stunde für die Wiedergabe. Heute verwirft `Seitenwahl.sauber`
     (`App/Seitenwahl.swift:99-104`) den Fragezeichenteil und `WiedergabeSeite` hat keine
     Eingänge (`Seiten/Technik/SystemSeiten.swift:155-162`). Vorschlag: `WiedergabeSeite` bekommt
     `var tagVorgabe: String?` und `var stundeVorgabe: Int?`, und die Wegetafel liest die beiden
     Werte aus dem Fragezeichenteil - oder `Wegweiser` bekommt ein Feld `ziel: Wiedergabeziel?`.
     Welcher der beiden Wege, entscheidet der Bauplan; neu im Kern ist nur das Lesen der Parameter.

BAUPLAN:

  1. `Gestalt/Marken.swift`: die vier Rampen und `rampenfarbe(_:anteil:)` eintragen,
     `abdeckungsfarbe` darauf umstellen (Punkte 1 und 2 oben). Nichts an `waerme` ändern - die
     Puffergläser hängen daran (`Marken.swift:163`).
  2. `Zustand/Jahreskarte.swift` neu: `Jahreskennzahl` und `Jahresraster` (Punkte 3-5), mit
     `robusteGrenze` und den vier Prüfungen aus `yearMap.test.ts`.
  3. `Diagramme/Jahresflaeche.swift` neu, nach `Abdeckungskarte` gebaut
     (`Diagramme/Abdeckungskarte.swift:27-197`): ein `Canvas` über Tag × Stunde, 00:00 oben,
     Stundenachse links (`i % 6`, „06:00" / „06" nach `horizontalSizeClass`), Monatsachse unten
     aus `monatsanfaenge`, Zellen ohne Lücke und mit Radius 1,5, leere Zelle ungezeichnet.
     Höhe: 24 Zeilen auf die Kartenhöhe rechnen, nicht umgekehrt (die Vorlage gibt der Karte
     `clamp(360, 100dvh - 250, 780)`, `YearMap.tsx:124`, Begründung im Kommentar `:122-123`
     übernehmen). Spaltenbreite wie dort aus der Fläche gerechnet (`Abdeckungskarte.swift:131-132`).
  4. Skala: senkrechtes Band rechts oben über der Fläche, `LinearGradient` über die Rampe, mit
     Zahlen und Einheit; bei `grid_net_kwh` zusätzlich „Bezug" und „Einspeisung" an den Polen
     (`charts.ts:517-537`). Vorbild für den Gradienten: `Abdeckungskarte.swift:180-196`.
  5. Finger auf einer Zelle: `DragGesture(minimumDistance: 0)` über der Fläche, Zelle aus der
     Stelle gerechnet (wie `Tageskurve.swift:382-401`, nur ohne `ChartProxy` - die Rechnung ist
     dieselbe wie beim Zeichnen). Daraus ein Hinweisblättchen mit den vier Zeilen aus
     `charts.ts:467-483` und, wo ein Tippen etwas tut, die Zeile „Klick öffnet die Wiedergabe
     dieser Stunde" (`YearMap.tsx:68`).
  6. `Seiten/Energie/JahreskarteSeite.swift` umschreiben, Karte für Karte in der Reihenfolge der
     Vorlage:
       a. Kopf: vier Jahresknöpfe `jetzt-0…3` statt ‹ ›, amber/petrol aktiv, 12,5 pt mono
          (`YearMap.tsx:91-99`). Den Kicker „365 Tage × 24 Stunden" dorthin, wo die App ihre
          Reiterzeile führt; am Telefon weglassen, weil die Vorlage ihn dort ausblendet
          (`AreaNav.tsx:96`).
       b. `Stoerung` bleibt oben, Texte auf die der Vorlage bringen
          („Nicht angemeldet - bitte Gerät koppeln.", „Daten konnten nicht geladen werden.",
          `YearMap.tsx:29-32`).
       c. Kennzahlleiste: `ForEach(Jahreskennzahl.allCases)` - acht Knöpfe in der Reihenfolge der
          Vorlage, Vorgabe `grid_net_kwh`, Rahmen/Text amber bei aktiv auf `rgba(242,169,0,.10)`,
          13 pt am iPad und 14,5 pt am Telefon (`handy.css:192`), umbrechend statt rollend
          (`YearMap.tsx:104`: `flex-wrap`); `Umbruchzeile` gibt es dafür schon.
       d. Bildkarte: `Karte(kicker: kennzahl.name, beiwerk: Einheit)` - Name links, Einheit rechts,
          Jahr **nicht** mehr im Kicker (`YearMap.tsx:125`). Darin `Jahresflaeche`; die drei
          Zustände „lädt" („Jahr wird geladen …"), „keine Stundenwerte" („Für <jahr> liegen keine
          Stundenwerte vor.") und Bild (`YearMap.tsx:127`).
       e. Fußnote: `Jahresraster.fussnote` als `Text` in 12/13,5 pt `Farbe.text3`, Zeilenhöhe
          weit, statt der heutigen `Methode`. Was `Methode` heute sagt („Daten seit …"), geht in
          die Fußnote ein, wie in der Vorlage, oder bleibt daneben - es steht dort nicht.
       f. Das `Kachelfeld` entfällt (die Vorlage hat keines, und die drei von vier Zahlen sind
          falsch gerechnet). Der Werteumfang min…max wandert in die Fußnote.
       g. `Raster` und `skala` in dieser Datei löschen; `name(_:)` ersetzt `Jahreskennzahl`.
  7. Wiedergabe-Ziel (Punkt 6 oben): `Seitenwahl` den Fragezeichenteil lesen lassen und
     `WiedergabeSeite(tagVorgabe:stundeVorgabe:)` damit füllen; der Schieber startet dann auf
     dieser Stunde statt auf 0 (`SystemSeiten.swift:160, 188`). Zum Schluss `Jahresflaeche` das
     Tippen anbinden.

WAS SCHWIERIG WIRD:

  * **ECharts' `heatmap` hat in Swift Charts kein Gegenstück, das 8760 Zellen trägt.**
    Der Weg ist im Projekt schon gewählt und begründet: ein `Canvas` je Raster, nicht 2000
    Einzelansichten (`Diagramme/Abdeckungskarte.swift:23-26`, „Als `RoundedRectangle` wären das
    zweitausend Ansichten, die SwiftUI bei jedem Bildwechsel neu vermisst"). Hier sind es
    365 × 24 = 8760 Felder, also gilt es noch stärker. Die Abweichungsmatrix geht denselben Weg
    (`Bausteine/Abweichungsmatrix.swift:68`).
  * **365 Spalten auf 390 Punkten.** Die Abdeckungskarte rechnet die Spaltenbreite aus der Fläche
    (`Abdeckungskarte.swift:131-132`) - bei 28 Tagen geht das auf, bei 365 ergibt es gut einen
    Punkt je Tag. Die Vorlage hat dasselbe Problem und löst es nicht: sie zeichnet 365 Kategorien
    in ein Gitter mit `left: 44, right: 16` (`charts.ts:486`) und lässt ECharts runden. Für das
    Telefon ist zu entscheiden, ob gerollt wird (wie die Abdeckungskarte schon rollt,
    `Abdeckungskarte.swift:161`) oder gestaucht; `handy.css` sagt dazu zu dieser Route nichts
    (gesucht nach `jahr`, `heatmap`, `visualMap` in `handy.css`: kein Treffer). Für einen ähnlich
    gelagerten Fall gibt es im Projekt eine Antwort: `handy.css:396-400` setzt beim Anlagenschema
    einen Rollhinweis unter das Bild („zur Seite wischen … ›") statt es zu stauchen.
  * **Das Hinweisfenster.** ECharts liefert es gratis; in SwiftUI ist es ein Blättchen, das man
    selbst setzt und im Bild hält (`handy.ts:61` setzt dafür `confine: true`). Vorbild für die
    Rechnung „Stelle → Datenkoordinate" ist das Fadenkreuz der Tageskurve
    (`Diagramme/Tageskurve.swift:382-401`); dort kommt die Umrechnung aus `ChartProxy`, hier muss
    sie die eigene sein, die auch gezeichnet hat.
  * **Finger und Sprung auf derselben Fläche.** Die Vorlage hat Überfahren (Hinweis) und Klick
    (Sprung) getrennt; am Telefon ist beides derselbe Finger. Im Projekt gibt es für „Tippen führt
    weg" `onTapGesture { wegweiser.gehe(ziel.weg) }` (`Diagramme/Anlagenbild.swift:326`) und für
    „Ziehen liest ab" die Tageskurve - beides zugleich auf einer Fläche ist neu und muss entschieden
    werden (Vorschlag: Ziehen liest ab, Loslassen lässt das Blättchen stehen, ein Tippen auf das
    Blättchen springt - dann ist der Sprung bestätigt und nicht beiläufig).
  * **Die divergierende Rampe.** Sieben Stopps mit flächennaher Mitte und gleich hellen Polen
    (`charts.ts:406-413`); der Kern hat dafür kein Vorbild, `waerme` und `abdeckung` sind beide
    sequenziell (`Marken.swift:164, 220`). Die Stopps sind in der Vorlage in OKLab gerechnet und
    dort als Hexwerte abgelegt - sie werden übernommen, nicht neu gerechnet. Zwischen zwei Stopps
    mischt `Farbwert.gemischt` in sRGB (`Marken.swift:240`); bei sechs bzw. sieben Stopps ist der
    Abstand klein genug, dass das keinen sichtbaren Knick ergibt. Dieselbe Entscheidung steht schon
    bei `wasserstufen` (`Marken.swift:185-203`).
  * **Zeitumstellung.** Der Dienst gruppiert nach Ortszeit, die Frühjahrsstunde bleibt leer, im
    Herbst werden zwei UTC-Stunden addiert bzw. gemittelt
    (`apps/api/src/dch_api/application/energy_accounting.py:1266-1276`). Die App muss davon nichts
    rechnen - aber „leer ist nicht null" gilt genau an diesen zwei Tagen besonders, und die
    heutige Zeichnung (`JahreskarteSeite.swift:191`, Lücke als `Farbe.linie1`) macht daraus einen
    hellen Streifen statt einer Lücke.
