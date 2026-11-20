========================= messen:waerme-fahrplan   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

`struct FahrplanSeite` steht in `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:10-135`,
eingehängt über `App/Seitenwahl.swift:75`. Sie liest `haus.plan` (`App/Hauszustand.swift:27`)
und zeigt, von oben nach unten:

1. **Kachelfeld, vier Spalten** – `FahrplanSeiten.swift:70-78`: `Kachelfeld(kacheln:
   Fahrplankacheln.kacheln(p).map(Kacheldaten.init), spalten: 4)`. Die sieben Zahlen rechnet
   `DuckCurveKit/Sources/DuckCurveKit/Zustand/Fahrplankacheln.swift:21-88`.
2. **Karte „Horizont"** – `FahrplanSeiten.swift:18-41`: Kicker „Horizont", als `titel` die
   Horizontspanne plus Planername (`:20`), darin `Fahrplanzeichnung` (`:22`), darunter
   `plannerNoteDe` in `Schrift.winzig`/`Farbe.text3` (`:29-34`) und `plannerWarnDe` in
   `Farbe.alarm` (`:35-40`).
3. **Die Zeichnung** – `Diagramme/Fahrplanzeichnung.swift:25-79`: zuerst das Auskunftsfeld
   (`:87-116`), dann acht einzelne `Chart` über `flaeche(...)` (`:125-182`) in der Reihenfolge
   Preis 92 / PV 80 / Wärmebedarf 92 / Puffer 80 / WP gemessen 72 / WP geplant 22 /
   Anforderung 22 / Ofen 22, zuletzt die Legende (`:426-437`) aus `Fahrplanbild.legende`
   (`Zustand/Fahrplanbild.swift:89-110`).
4. **Karte „Die Entscheidungen"** – `FahrplanSeiten.swift:42-47` mit `titel:
   Fahrplanworte.entscheidungenDazu`; die Tabelle in `:84-116` über `Planauswahl.entscheidungen`
   (`Zustand/Planauswahl.swift:72-91`) und den Baustein `Tabelle` (`Seiten/Bericht.swift:165`).
5. **Methode** – `FahrplanSeiten.swift:49-58`: die drei Absätze aus
   `Zustand/Fahrplanworte.swift:25-46` **plus zwei selbstgebaute Zeilen** (Planer/Status/erstellt
   und ein Satz zur Freigabe, `:51-54`).
6. **Ohne Plan** – `FahrplanSeiten.swift:59-61`: eine einzige `Karte { Leer(satz:
   Fahrplanworte.ohnePlan) }`. Bei `p.intervals.isEmpty` entfallen 2.–4. ganz (`:17`).

VORLAGE:

Einstieg `apps/web/src/app/waerme/fahrplan/page.tsx:7-13`: `AreaShell` mit
`kicker="Preis · PV · Wärmebedarf · Puffer · zwei Tage"` (`:9`, in der App schon im Kern:
`DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:203`, gezeigt von
`App/Seitenwahl.swift:206-215`, am Telefon weg wie `components/layout/AreaNav.tsx:96`
`hidden … md:block`). Alles Weitere in `apps/web/src/components/waerme/Fahrplan.tsx`.

  * **Sieben Kennzahlkacheln**  (`Fahrplan.tsx:548-574`)
    Raster `kpi-handy grid grid-cols-2 gap-3 md:grid-cols-4 xl:grid-cols-7` (`:548`) – also
    **zwei** Spalten bis 768 px, vier bis 1280 px, sieben darüber. Jede Kachel ist `Stat`
    (`components/ui/Stat.tsx:4-18`): `.card` mit `padding: 14px 18px; gap: 6`, Kicker 11 px,
    Wert `mono` 26 px `leading-none tracking-[-.02em]`, Einheit 13 px Sans in `--text-3`,
    Hinweiszeile 12 px `line-clamp-2 leading-[1.35]` in `--text-3`.
    Ton → Farbe (`Stat.tsx:5`): `amber`→`--amber` #f2a900, **`ember`→`--alert` #e0533d**,
    `mist`→`--mist` #7fa3b3, `muted`→`--text-3` (`styles/tokens.css:13,15,34,64`).
    Die sieben, wörtlich: „Wärmepumpe angefordert" (ember, Hinweis je `hp_actuation`
    „im ganzen Horizont · Duck Curve fordert selbst an" / „… · wird nur beobachtet, nicht
    geschaltet"), „Wärmepumpe gelaufen" (amber, „seit Mitternacht · im selben Fenster geplant
    N,N h" bzw. „keine Messung"), „bewusst gemieden" (muted, „teure Stunden ohne Anforderung"),
    „Ofen geplant" (ember/muted, „kein Fahrplan für den Ofen" / „Volllast, 15 kg je Füllung" /
    „nicht eingeplant, Begründung unten"), „Wärmebedarf geplant" + Einheit „kWh" (mist, „Modell
    v1, nicht gemessen"), „COP im Horizont" (mist, „aus der Außentemperatur"), „Preisspanne" +
    Einheit „ct" (amber, „im Horizont").
    Gerechnet in `Fahrplan.tsx:491-532`; Laufzeit aus `actual_hp_run_min` gegen die Schwelle des
    Dienstes, Gegenzahl nur über die Viertelstunden **mit** Messung (`:507-519`, Begründung im
    Kommentar: „Viertelstunden mit mehr als 0,05 kW" zählte Standby als Lauf).
    DATEN: `GET /plan`, eigener Zustand der Komponente (`:128-146`), **alle 60 s neu**
    (`LIVE_MS = 60_000`, `:48`), nur bei `visibilityState === "visible"`.
    Handy-Fassung (`styles/handy.css:197-207`, ≤ 720 px): aus dem Kachelraster wird **eine**
    Fläche – `grid-template-columns: repeat(2, …); gap: 0 20px; background: var(--surface-2);
    border-radius: 16px; padding: 4px 16px`; jede Kachel ohne eigene Fläche, `padding: 13px 0
    14px`, `gap: 5px`, oben eine Haarlinie `--line-1`; **die erste über beide Spalten**, ohne
    Linie, `padding: 14px 0 16px`, `gap: 8px`, Zahl 48 px `letter-spacing: -0.04em`, Einheit
    18 px, Hinweis 14,5 px in `--text-2`; eine allein bleibende letzte Kachel nimmt die ganze
    Zeile (`:200`); Zahl der übrigen 25 px – **für diese Seite ausdrücklich 21 px**, weil die
    Werte Spannen sind („2,8 bis 3,6", `handy.css:381-382`).

  * **Karte „Horizont"**  (`Fahrplan.tsx:576-644`)
    `CardHead title="Horizont"` und `right` = `<span className="mono">heute 00:00 bis übermorgen
    00:00 · <planner></span>` (`:577-586`). `CardHead`
    (`components/ui/Card.tsx:20-28`): Titel als `h2.kicker` (Mono 13 px, `letter-spacing:
    .13em`, Großbuchstaben, `--text-kicker` = `--mist`; `styles/globals.css:57-64`), rechts
    `div.card-head-right` **12 px in `--text-3`**, auf derselben Grundlinie
    (`items-baseline justify-between`). Die Karte selbst: `--surface-2`, 1 px `--line-1`,
    `border-radius: 3px`, `padding: 20px` (`globals.css:67-77`), ≤ 720 px `padding: 14px`
    (`globals.css:333`), am Handy randlos mit `border-radius: 16px; padding: 16px` und der
    Kopfzeile in Sans 16,5 px/600 ohne Sperrschrift, der rechte Teil bricht darunter um
    (`handy.css:182-185`).
    Darin der Kasten mit fester Höhe `HOEHE = 812` (`Fahrplan.tsx:125,591`) – die Höhe trägt der
    Kasten, nicht das Diagramm (Kommentar `:587-589`).
    Zustände: `fehler` → **eigene Karte** „Fahrplan" mit dem Fehlersatz in 13 px `--text-3`
    (`:534-541`, Text: `e.message` oder „Der Fahrplan ist gerade nicht zu erreichen."); kein
    Plan/keine Intervalle → derselbe Kartenaufbau mit „Noch kein Fahrplan gerechnet." an der
    Stelle der Zeichnung (`:595`), **die Kacheln, die Legende, die Entscheidungen und die
    Methode bleiben stehen** (`:543-574`, `:598-661`).
    DATEN: `/plan` – `horizon_start`, `horizon_end`, `planner`.

  * **Die Zeichnung: acht Gitter über einer Zeitachse**  (`Fahrplan.tsx:113-125, 283-489`)
    `FLAECHEN` (`:113-122`) gibt Titel, Oberkante und Höhe an einer Stelle an – 28/92, 162/80,
    284/92, 418/80, 540/72, 652/22, 704/22, 756/22; der Kommentar `:106-111` nennt den Grund:
    als die Zahlen in drei Listen standen, war eine Fläche um 20 Pixel verschoben.
    **Jedes Gitter hat dieselbe linke und rechte Kante**: `grid: FLAECHEN.map(f => ({ left: 56,
    right: 18, top: f.top, height: f.hoehe }))` (`:291`), jeder Titel steht auf `left: 56,
    top: f.top - 22`, 11 px, `fontWeight: normal`, Farbe `C.text` = `rgba(255,255,255,.48)`
    (`:285-290`, `components/charts/palette.ts:80`). Die Zeitachse trägt **nur** das letzte
    Gitter (`:292`), senkrechte Rasterlinien stehen in allen (`:255`), Beschriftung Mono 10 px
    mit `hideOverlap`, an der Tagesgrenze das kurze Datum statt „00:00" (`:243-253`).
    y-Achsen (`:293-308`): Preis ab `untergrenze(preise, 5)`, PV ab 0 („Erwartung und Messung
    müssen denselben Boden haben"), Wärme ab `untergrenze(summe, 0.5)`, Puffer 0 bis
    `buffer_capacity_kwh`, WP gemessen ab 0, die drei Streifen 0…1 und unsichtbar; Beschriftung
    Mono 10 px mit `showMinLabel: true` (`:264-267`).
    Reihen (`:365-470`):
      – Strompreis: Fläche `rgba(127,163,179,.16)` + Linie `C.price` #7fa3b3 Breite 2,
        `step: "end"`; dahinter die Preisfenster als `markArea` ohne Beschriftung, billig
        `rgba(127,163,179,.14)`, negativ `rgba(224,83,61,.14)` (`:206-219`; Begründung: zwei
        kurze Tiefs druckten „PREISTIEFPREISTIEF").
      – PV erwartet: Linie `C.mist` **Breite 1,5, gestrichelt, `smooth: true`** (`:391-401`).
      – PV gemessen: Linie `C.pv` #f2a900 Breite 2 + Fläche `rgba(242,169,0,.20)` (`:402-411`).
      – Wärmebedarf: **zwei gestapelte Linienflächen ohne `step`** – Heizen `C.house` #cfd8dc
        Breite 1,5, Fläche `rgba(207,216,220,.22)`; Warmwasser `C.dhw` #4aa3c7 Breite 1,5,
        Fläche `rgba(74,163,199,.34)` (`:415-437`).
      – Pufferinhalt: Linie `C.puffer` #8fbf6b Breite 2, Fläche `rgba(143,191,107,.14)`; darunter
        die Reservezone `rgba(224,83,61,.10)` mit dem Wort **„RESERVE"** im Bild, Mono 10 px,
        `letterSpacing: 1`, Farbe `C.alert`, `insideBottomLeft` (`:223-231`, `:438-449`).
      – WP gemessen: Linie `C.heatPump` #e0966b Breite 1,8 + Fläche `rgba(224,150,107,.22)`,
        `step: "end"` (`:453-464`).
      – Drei Streifen als Balken, `barWidth: "92%"` (`:465-469`); Höhen und Farben aus
        `WP_ZUSTAND` (`:51-56`): release 1/`C.heatPump`, avoid 0,55/`C.alert`, free
        0,3/`rgba(255,255,255,.3)`, off 0,12/`rgba(255,255,255,.14)`.
      – Jetzt-Linie in **jeder** Reihe: `markLine`, `var(--amber-soft)`, gestrichelt, 1,2
        (`:272-278`).
      – Lücken bleiben `null` und nicht 0 (`:155-167`; „eine Null hieße: die Anlage stand").
    Leere Flächen bekommen ein Wort in der Mitte statt einer leeren Achse (`:473-487`,
    `:666-675`, Mono 11 px, `C.text`): „kein Wärmebedarf im Fahrplan", „kein Pufferverlauf im
    Fahrplan", „keine Messung der Wärmepumpe", „keine Anforderung gemessen", „keine Messung im
    Horizont", „nicht eingeplant, Begründung darunter" / „kein Ofenfahrplan". Für die
    Preisfläche gibt es **keinen** solchen Hinweis.
    Hinweisfenster (`:310-364`): `trigger: "axis"`, `confine: true`, Hintergrund `C.deep`,
    **Rand `rgba(242,169,0,.4)`**, Text 12 px #f1f5f5; Zeilen in dieser Reihenfolge: Zeit in
    `--amber-soft`, Strompreis, PV erwartet, (PV gemessen + eingerückt „0,4 kW mehr/weniger als
    erwartet" bzw. „wie erwartet"), (Wärmebedarf + **eine** eingerückte Zeile „Heizen x ·
    Warmwasser y"), (Puffer danach), (Außen „x,x °C · COP y,yy"), Wärmepumpe geplant,
    (Anforderung gemessen ja/nein), (Wärmepumpe gemessen, zwei Stellen), Pelletofen
    (brennt/aus/kein Fahrplan), note_de.
    Legende unter der Zeichnung (`:598-640`): `mt-2 flex flex-wrap gap-x-5 gap-y-2
    text-[11px] text-text-3`, Klotz 14 px breit, Höhe `max(3, round(hoehe*10))` für die vier
    Zustände, 10 px für Ofen/Heizen/Warmwasser/PV gemessen, 3 px für Pufferinhalt, 2 px für PV
    erwartet, 10 px für Preistief `rgba(127,163,179,.32)`; „negativer Preis" nur, wenn der Plan
    ein solches Fenster kennt. Danach `planner_note_de` (`mt-3`, 12 px, `leading-[1.5]`,
    `--text-3`) und `planner_warn_de` (`mt-2`, 12 px, `text-alert`) (`:642-643`).
    DATEN: `/plan` – je Viertelstunde `ts`, `price_ct_kwh`, `expected_pv_kw`, `actual_pv_kw`,
    `heat_demand_kw`, `dhw_demand_kw`, `buffer_kwh`, `actual_hp_kw`, `planned_hp_state`,
    `actual_hp_release`, `planned_stove_on`, `outdoor_temp_c`, `cop`, `note_de`; dazu `windows`,
    `buffer_min_kwh`, `buffer_capacity_kwh`.
    Handy-Fassung: **keine eigene Regel** – weder `handy.css` noch `globals.css` nennen die
    Zeichnung; gesucht nach `fahrplan`, `fp-`, `kpi-handy` und `nur-breit` in
    `styles/*.css`: die einzigen Treffer dieser Route sind `.kpi-handy` und
    `.fp-entscheidungen`. Die acht Flächen bleiben am Telefon in voller Höhe stehen, die kleine
    Schrift wächst eine Stufe (`handy.css:189-192`: 10→11, 11→12, 12→13,5, 13→14,5 px).

  * **Karte „Die Entscheidungen"**  (`Fahrplan.tsx:646-649, 677-730`)
    `CardHead title="Die Entscheidungen"` und `right="die teuersten und die billigsten
    Viertelstunden, mit Begründung"` – als Zeichenkette, also mit `truncate` (`Card.tsx:26`),
    12 px, `--text-3`.
    Auswahl: die drei teuersten und die drei billigsten Viertelstunden mit Preis, ohne
    Wiederholung, zeitlich geordnet (`:679-688`).
    Tabelle `fp-entscheidungen w-full border-collapse text-[12px]` (`:694`), Kopfzeile
    links, `--text-3`, `font-medium`, Unterkante `border-white/10`, Spalten **Zeit · Preis ·
    Bedarf · Puffer · Wärmepumpe · Ofen · Warum** – die ersten vier rechtsbündig außer „Zeit",
    „Warum" linksbündig mit `pl-4` (`:697-703`).
    Zellen (`:711-723`): Zeit, Preis, Bedarf, Puffer **tragen `mono`**, Wärmepumpe und Ofen
    nicht, „Warum" nicht und in `text-text-3`. Werte wörtlich: `heute 03:15`, `18,4 ct`
    (**„ct", nicht „ct/kWh"**), `3,6 kW`, `21,4 kWh` in `C.puffer`, das Zustandswort in seiner
    Farbe, `brennt`/`aus`/`-` (brennt in `C.stove`), und `note_de ?? reason_code` –
    **der rohe Schlüssel**, wenn kein Satz da ist.
    Leer: „Noch keine Preise im Horizont." (`:690`).
    Handy-Fassung (`handy.css:305-306, 319-329`): die Tabelle wird `display: block`, die
    Kopfzeile verschwindet, **jede Zeile wird ein Block** aus vier Spalten und drei Zeilen:
    `grid-template-columns: auto auto auto minmax(0,1fr); gap: 4px 14px; align-items: baseline;
    padding: 12px 0; border-top: 1px solid var(--line-1)`, die erste ohne Linie mit
    `padding-top: 2px`. Zeile 1: Zeit über die Spalten 1–3, 15 px, `--text-1`; rechts außen das
    Zustandswort der Wärmepumpe, 14 px. Zeile 2: Preis, Bedarf, Puffer in den Spalten 1–3,
    13,5 px; rechts außen der Ofen in `--text-3` **mit vorangestelltem Wort „Ofen "**
    (`:328`, `::before`). Zeile 3: „Warum" über die ganze Breite, umbrechend, 13,5 px,
    `line-height: 1.4`. Alle Zellen linksbündig, ohne Rahmen, `white-space: nowrap` außer der
    Begründung.

  * **Methode**  (`Fahrplan.tsx:651-661`, `components/ui/Methode.tsx:18-34`)
    Ein `<details class="card methode">`, **zugeklappt**; Summary mit `kicker` „Woher die Zahlen
    kommen", daneben `methode-kurz` „Preis und Sonne sind Prognosen, der Wärmebedarf ist ein
    Modell · links der Jetzt-Linie stehen Messung und Regel nebeneinander" (12,5 px,
    `--text-3`) und rechts ein Pfeil, der sich dreht (`globals.css:726-736`). Inhalt: drei
    Absätze `methode-absatz` – 13 px, `line-height: 1.55`, `--text-2`, `max-width: 90ch`,
    Abstand 10 px, `padding: 0 18px 18px`.
    **Genau drei Absätze**, wörtlich die in
    `DuckCurveKit/Sources/DuckCurveKit/Zustand/Fahrplanworte.swift:25-46` abgelegten. Weder
    `planner_status` noch `created_at` stehen auf dieser Seite (gesucht nach `planner_status`,
    `created_at` und `hp_actuation` in `components/waerme/Fahrplan.tsx`: Treffer nur
    `plan?.hp_actuation` in der ersten Kachel, `:555`).
    Handy-Fassung (`handy.css:212-217`): Summary `padding: 15px 16px`, Kicker als Sans 15 px/600
    ohne Sperrschrift, `methode-kurz` 13 px, Absätze 14,5 px.

LUECKEN:

  [traegt-die-seite] **Die acht Flächen haben keine gemeinsame linke Kante, und die Zeitachse
  gehört zu keiner von ihnen.** Die Vorlage setzt für alle acht Gitter `left: 56, right: 18`
  und legt die Titel auf dieselben 56 Punkte (`Fahrplan.tsx:287-291`) – nur dadurch bedeutet
  eine Senkrechte durch die Zeichnung überall denselben Zeitpunkt. In der App ist jede Fläche
  ein eigenes `Chart` (`Diagramme/Fahrplanzeichnung.swift:131-147`) und bestimmt ihren linken
  Rand selbst aus der Breite ihrer eigenen y-Beschriftung; die drei Streifen bekommen wegen
  `if leer == nil, hoehe > 20` (`:169`) **gar keine** Beschriftung und fangen damit am linken
  Kartenrand an, während die fünf Wertflächen um die Breite von „40" bzw. „21,5" eingerückt
  sind. Die Zeitachse steht ausgerechnet unter dem Ofenstreifen (`:73`), also unter der
  schmalsten Einrückung. Dieselbe Verschiebung trifft die senkrechten Rasterlinien (`:154-155`)
  und die Jetzt-Linie (`:138`). Damit verliert die Seite ihre Hauptaussage: „sechs Flächen
  übereinander mit einer gemeinsamen Zeitachse" (`Fahrplan.tsx:19-22`).

  [traegt-die-seite] **Die Entscheidungen sind am Telefon auf eine Spalte zusammengeschnitten.**
  `FahrplanSeiten.swift:91-113` ruft `Tabelle` ohne `immerSichtbar` und ohne `handyfassung`;
  auf `horizontalSizeClass == .compact` zeigt der Baustein deshalb **eine** Spalte, umgeschaltet
  über eine Pillenreihe, Anfangswert `gezeigt = 0` (`Seiten/Bericht.swift:234, 260-306`). Zu
  sehen sind also Zeit und Preis; Bedarf, Puffer, Zustandswort, Ofen und die Begründung sind
  weg, bis man tippt. Die Vorlage baut genau diese Tabelle am Telefon zu einem Block um, in dem
  **alle sieben Werte gleichzeitig** stehen, die Begründung über die ganze Breite und der Ofen
  mit dem Wort „Ofen " vor sich (`handy.css:319-329`). Die Karte heißt „die teuersten und die
  billigsten Viertelstunden, **mit Begründung**" – und die Begründung ist das, was die App dort
  nicht zeigt (eigener Kommentar der Seite: „Ein Plan, der sagt ‚23:15 bis 02:00 an', ohne zu
  sagen warum, ist eine Ansage", `FahrplanSeiten.swift:7-9`).

  [spuerbar] **Vier Kachelspalten am Telefon statt zwei.** `Kachelfeld(spalten: 4)`
  (`FahrplanSeiten.swift:76`); `Kachelfeld` zerlegt in Zeilen fester Länge unabhängig von der
  Breite (`Gestalt/Karte.swift:306-342`, `zeilen` → `chunked(spalten)`), nur die **erste**
  Kachel führt auf schmalem Schirm (`:290-299`). Die sechs übrigen stehen damit auf 390 Punkten
  zu vier in einer Reihe, wo die Vorlage zwei vorschreibt (`handy.css:197`,
  `Fahrplan.tsx:548` `grid-cols-2`). Das Projekt macht es anderswo richtig:
  `Seiten/Energie/StromSeite.swift:74` und `Seiten/Energie/SpeicherSeite.swift:110` übergeben
  `schmal ? 2 : 3` bzw. `schmal ? 2 : 4`. Gleichzeitig fehlt die obere Stufe: ab 1280 Punkten
  stehen in der Vorlage alle sieben in einer Reihe (`xl:grid-cols-7`), in der App nie.

  [spuerbar] **Die beiden `ember`-Kacheln haben die falsche Farbe.**
  `Fahrplankacheln.swift:50` und `:74` setzen `ton: .glut`, und `Gestalt/Farben.swift:124`
  bildet `.glut` auf `Farbe.waermepumpe` #E0966B ab. Die Vorlage färbt „Wärmepumpe angefordert"
  und „Ofen geplant" mit `tone="ember"` → `--alert` #E0533D (`Stat.tsx:5`,
  `tokens.css:64`). Dass `Kennzahl.Ton` den Wert nicht hat, ist im Projekt bekannt und zweimal
  ausdrücklich vermerkt (`Zustand/Stromuebersicht.swift:274-275`,
  `Zustand/Gelduebersicht.swift:597-598`: „müsste `--alert` tragen und trägt `glut`") – auf
  dieser Seite steht der Vermerk nicht, und es trifft die **führende** Kachel, die am Telefon
  48 Punkte groß ist.

  [spuerbar] **Ein Fehlschlag der Abfrage ist nicht zu sehen.** Die Vorlage hat für `/plan`
  einen eigenen Fehlerzustand mit eigener Karte und dem Satz des Fehlers
  (`Fahrplan.tsx:129, 134-137, 534-541`). `FahrplanSeiten.swift:59-61` zeigt stattdessen
  „Noch kein Fahrplan gerechnet." – derselbe Satz wie für „der Planer hat noch nicht
  gerechnet". `haus.fehler` (`App/Hauszustand.swift:32`) wird auf dieser Seite nicht gelesen,
  und einen Weg zum Wiederholen gibt es nicht, obwohl der Baustein dafür da ist und auf der
  Nachbarseite benutzt wird (`Gestalt/Karte.swift:419-465`,
  `FahrplanSeiten.swift:218, 253-255`).

  [spuerbar] **Ohne Intervalle verschwindet fast die ganze Seite.** `FahrplanSeiten.swift:17`
  klammert Horizontkarte **und** Entscheidungskarte hinter `!p.intervals.isEmpty`; ohne Plan
  bleibt nach `:59-61` nur eine leere Karte, also auch keine Kacheln und keine Methode. Die
  Vorlage zeigt in beiden Fällen weiter die sieben Kacheln (mit „0,0 h" bzw. „-",
  `Fahrplan.tsx:491-531, 543-574`), die Horizontkarte mit dem Satz und der vollständigen
  Legende (`:590-640`), die Entscheidungskarte mit „Noch keine Preise im Horizont." (`:646-649,
  690`) und die Methode (`:651-661`). Der Kern kann das längst:
  `Fahrplankacheln.kacheln(_ plan: PlanOut?)` nimmt `nil` (`Fahrplankacheln.swift:21-22`).

  [spuerbar] **Die Kartenköpfe tragen ihr Beiwerk als zweite Überschrift.**
  `FahrplanSeiten.swift:20` gibt die Horizontspanne samt Planername als `titel`, `:44` den
  Untertitel der Entscheidungen ebenso. `Gestalt/Karte.swift:63-78` setzt einen `titel` auf
  breitem Schirm **unter** den Kicker, in `Schrift.karte` (Sans 15 halbfett,
  `Gestalt/Typografie.swift:42`) und `Farbe.text1`. Die Vorlage setzt beides als `right` des
  `CardHead`: auf derselben Grundlinie rechts, 12 px, `--text-3`, die Horizontspanne zusätzlich
  in Mono (`Fahrplan.tsx:577-586, 647`; `Card.tsx:22-27`). Der Baustein kann es –
  `beiwerk:` – und die Nachbarseite benutzt es genau so (`FahrplanSeiten.swift:166-175,
  235-238`).

  [spuerbar] **Die Entscheidungstabelle am iPad: die Begründung steht rechtsbündig in
  Zahlenschrift.** `Seiten/Bericht.swift:445-459` richtet **alle** Wertspalten rechts aus und
  setzt sie in `Schrift.zahl` (Mono 15), Farbe `Farbe.text1`, wo keine Zellfarbe gesetzt ist
  (`:494-499`); „Warum" hat keine Farben (`FahrplanSeiten.swift:111`). Die Vorlage setzt diese
  Spalte links mit `pl-4`, in Sans, 12 px, `text-text-3`, und auch „Wärmepumpe" und „Ofen"
  tragen **kein** `mono` (`Fahrplan.tsx:703, 718-722`). Dazu fehlt die Kopfzelle „Zeit": die
  Kopfzeile des Bausteins lässt die Namensspalte leer (`Bericht.swift:433`), die Vorlage
  beschriftet sie (`Fahrplan.tsx:697`).

  [klein] **„ct/kWh" statt „ct" in den Preiszellen.** `FahrplanSeiten.swift:95` und
  `Fahrplanbild.swift:283` rufen `Formate.ct`, das immer „ct/kWh" anhängt
  (`Formate/Formate.swift:110-113`). Die Vorlage schreibt in der Tabelle und im Hinweisfenster
  „18,4 ct" (`Fahrplan.tsx:713, 328`); die Einheit steht im Flächentitel „Strompreis · ct/kWh".
  In der schmalen Spalte des Telefons kostet das zusätzlich die halbe Zellbreite.

  [klein] **Der Wärmebedarf ist in der App gestuft, in der Vorlage nicht.**
  `Fahrplanzeichnung.swift:265, 275, 286, 297` setzen überall
  `.interpolationMethod(.stepEnd)`; die beiden gestapelten Reihen der Vorlage haben **kein**
  `step` (`Fahrplan.tsx:415-437`) – anders als Preis (`:372`) und WP gemessen (`:459`), die es
  ausdrücklich haben.

  [klein] **PV erwartet: 1,2 statt 1,5 Punkte und ohne Glättung.**
  `Fahrplanzeichnung.swift:248` zeichnet `StrokeStyle(lineWidth: 1.2, dash: [3, 3])`; die
  Vorlage `width: 1.5` mit `smooth: true` (`Fahrplan.tsx:397-399`). Die Glättung ist dort kein
  Zierrat: sie unterscheidet die Prognosekurve von der gemessenen Treppe daneben.

  [klein] **Zwei Methodenzeilen, die die Vorlage nicht hat.** `FahrplanSeiten.swift:51-54`
  hängt „Planer: … · erstellt hh:mm" und einen Satz zur Freigabe an die drei Absätze. Auf der
  Vorlageseite kommen `planner_status` und `created_at` nicht vor (gesucht in
  `components/waerme/Fahrplan.tsx`: kein Treffer), und die Freigabe steht dort im Hinweis der
  ersten Kachel (`:555`) – wo die App sie ebenfalls schon hat
  (`Fahrplankacheln.swift:47-49`), also zweimal. Dazu die Maße: der Baustein setzt die Absätze
  in `Schrift.winzig` 11,5 px auf `Farbe.text3` (`Seiten/Bericht.swift:545-546`), die Vorlage
  13 px auf `--text-2`, am Telefon 14,5 px (`globals.css:734`, `handy.css:217`).

  [klein] **Ein Leerhinweis zu viel, und die Achse verschwindet mit ihm.**
  `Fahrplanzeichnung.swift:30` setzt „keine Preise im Horizont" in die Preisfläche; die Vorlage
  hat für diese Fläche keinen Hinweis (`Fahrplan.tsx:473-487`, sechs Hinweise, Preis nicht
  darunter). Und wo ein Hinweis steht, blendet `:169` zugleich die y-Beschriftung ab; in der
  Vorlage bleiben Achse und Raster stehen, nur die Reihe fehlt.

  [klein] **Legende und kleine Schrift: die Maße der Vorlage fehlen.**
  `Fahrplanzeichnung.swift:427` setzt 13/5 Punkte Abstand, die Vorlage `gap-x-5 gap-y-2`, also
  20/8 px (`Fahrplan.tsx:598`). Die Schriftstufen am Telefon (`handy.css:189-192`: 11 px →
  12 px für die Legende, 12 px → 13,5 px für Notiz und Warnung des Planers) kommen in der App
  nicht an: `Schrift.winzig` (11,5) für Legende, Notiz und Warnung, breitenunabhängig
  (`Fahrplanzeichnung.swift:433`, `FahrplanSeiten.swift:31, 37`).

  [klein] **Das Auskunftsfeld hat keinen Rand.** `Fahrplanzeichnung.swift:111` legt es auf
  `Farbe.flaeche2` ohne Umriss; das Hinweisfenster der Vorlage steht auf `C.deep` mit dem Rand
  `rgba(242,169,0,.4)` (`Fahrplan.tsx:315-316`) – daran erkennt man, dass es zum Zeiger gehört
  und nicht zur Karte.

  [klein] **Kein seitenlokales Nachladen.** Die Vorlage holt `/plan` auf dieser Seite alle 60
  Sekunden neu, solange das Fenster sichtbar ist (`Fahrplan.tsx:48, 140-146`), zusätzlich zum
  Ereignis `plan` des Stroms (`lib/live/sseClient.ts:68-70`). Die App hat nur das Ereignis
  (`App/Hauszustand.swift:179-180`) und die Erstladung bei jeder Wiederverbindung
  (`:227-245`); bleibt eine Seite lange offen und kommt kein `plan`-Ereignis, veraltet sie
  stillschweigend.

  [klein] **Die Begründung ist übersetzt, die Vorlage zeigt den Schlüssel.**
  `Planauswahl.swift:88` setzt `iv.noteDe ?? Grundwort.text(kennung: iv.reasonCode)`
  (`Modelle/Woerter.swift:119-121`); die Vorlage schreibt `i.note_de ?? i.reason_code`, also
  z. B. „cheap_window" (`Fahrplan.tsx:722`). Besser lesbar, aber ein anderes Wort auf dem
  Schirm – und wenn die Übersetzung einen neuen Schlüssel nicht kennt, steht dort der Schlüssel
  mit Leerzeichen statt Unterstrichen.

KERN: SCHON DA (nachgesehen, nicht geraten):

  * `Api.plan() -> PlanOut` – `DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:167-169`,
    `GET /plan`. Das Ereignis `plan` des Stroms:
    `Netz/LiveStrom.swift:14, 170-171`, abgelegt in `App/Hauszustand.swift:27, 179-180`,
    nachgeholt bei jeder Verbindung in `:227-245`.
  * `PlanOut` – `Modelle/Schema.swift:7083-7098`: `createdAt`, `planner`, `plannerStatus`,
    `plannerNoteDe`, `plannerWarnDe`, `hpActuation`, `horizonStart`, `horizonEnd`, `windows`,
    `intervals`, `pvForecastTodayKwh`, `nextCheapWindow`, `bufferCapacityKwh`, `bufferMinKwh`.
  * `PlanIntervalOut` – `Modelle/Schema.swift:6994-7013`: alle Felder, die die Vorlage liest,
    einschließlich `actualPvKw`, `actualHpKw`, `actualHpRelease`, `actualHpRunMin`,
    `outdoorTempC`, `cop`, `noteDe`, `reasonCode`.
  * `Fahrplanbild` – `Zustand/Fahrplanbild.swift:153-221` baut alle Reihen, Bänder, Horizont,
    Untergrenzen (`:231-237`), Pufferdecke und -reserve und die sechs „hat…"-Merker; die
    Zustandsabbildung an einer Stelle (`:47-56`), die ganze Legende der Vorlage (`:89-110`),
    die Auskunft zu einer Viertelstunde (`:266-326`), die Spanne einer gestauchten Fläche
    (`:329-334`). Geprüft in `Tests/DuckCurveKitTests/FahrplanbildTests.swift`.
  * `Fahrplankacheln.kacheln(_:)` – `Zustand/Fahrplankacheln.swift:21-88`, alle sieben Kacheln
    mit den Hinweistexten der Vorlage, `nil`-fest; `viertelstunden(_:)` `:17-19`;
    `spanne(_:stellen:)` `:91-94`.
  * `Planauswahl` – `Zustand/Planauswahl.swift:18-29` (die Ränder nach Preis) und `:72-91`
    (die fertigen Zeilen mit Wort **und** Rolle, Begründung in `:33-39`), `bedarf(_:)`
    `:97-100`. Geprüft in `Tests/DuckCurveKitTests/PlanauswahlTests.swift`.
  * `Fahrplanworte` – `Zustand/Fahrplanworte.swift:18-53`: `methodeKurz`, `methodeTitel`, die
    drei Absätze, `entscheidungenDazu`, `ohnePlan`.
  * Farben und Maße – `Gestalt/Marken.swift` über `Gestalt/Farben.swift:73-89`: `pv`,
    `waermepumpe`, `ofen`, `haus`, `warmwasser`, `puffer`, `preis`, `mist`, `alarm`,
    `amberWeich`, `rasterlinie`, `flaeche1-3`, `linie1/2`.
  * Formate – `Formate/Formate.swift:62-113` (`kw`, `kwMitEinheit`, `kwh`, `celsius`, `ct`),
    `:255-262` (`hhmm`), `:310-326` (`tagUndUhr` mit heute/morgen/übermorgen, gerechnet in
    Kalendertagen des Hauses), `:44-58` (`zahl`), `:27` (`leer` = „-").
  * `Grundwort.text(kennung:)` – `Modelle/Woerter.swift:97-121`.
  * Bausteine der Oberfläche: `Gestalt/Karte.swift:15-113` (`Karte` mit `kicker`, `titel`,
    `beiwerk`), `:121-151` (`Kacheldaten`, `init(_ k: Kennzahl)`), `:158-266` (`Kachel` mit
    `Art.bericht` und `fuehrend`), `:274-343` (`Kachelfeld`), `:390-404` (`Leer`),
    `:419-465` (`Stoerung` mit „Erneut"); `Seiten/Bericht.swift:165-507` (`Tabelle` mit
    `Spalte.farben`, `immerSichtbar`, `handyfassung`, `engeZellen`), `:514-577` (`Methode`);
    `Gestalt/Umbruchzeile.swift` (die umbrechende Legendenzeile); `App/Seitenwahl.swift:154-215`
    (`Seite` mit dem Bereichskicker).

ES FEHLT:

  1. **Ein Ton für `--alert`.** `Kennzahl.Ton` (`Zustand/Kennzahl.swift:38-51`) hat keinen Fall
     für #E0533D; `Gestalt/Farben.swift:120-129` kann ihn deshalb nicht abbilden. Vorschlag:
     `case glutRot` (oder `case alarm`) in `Zustand/Kennzahl.swift`, in
     `Gestalt/Farben.swift:120` auf `Farbe.alarm`, und `Fahrplankacheln.swift:50, 74` darauf
     umstellen. Räumt zugleich die zwei vermerkten Ausweichstellen auf
     (`Zustand/Stromuebersicht.swift:297`, `Zustand/Gelduebersicht.swift:610`).
  2. **Ein kurzes Centformat.** `Formate.ct` hängt immer „ct/kWh" an
     (`Formate/Formate.swift:110-113`), die Vorlage schreibt in Tabelle und Hinweisfenster
     „18,4 ct". Vorschlag: `Formate.ctKurz(_ wert: Double?) -> String` in
     `Formate/Formate.swift` (oder `ct(_:mitNenner:)` mit Vorgabe `true`, damit die bestehenden
     Rufe bleiben), benutzt von `Planauswahl`/`Fahrplanbild.auskunft`.
  3. **Die Zeilen der Entscheidungen als fertige Zellen.** Für den Handy-Block braucht die
     Ansicht je Zeile die sechs Zeichenketten in der Reihenfolge der Vorlage; heute formatiert
     sie `FahrplanSeiten.swift:93-111` selbst. Vorschlag: in
     `Zustand/Planauswahl.swift` an `Entscheidung` die gerechneten Felder `zeitwort`,
     `preiswort`, `bedarfswort`, `pufferwort` ergänzen (oder eine Funktion
     `zellen(jetzt: Date) -> [(wort: String, rolle: Rolle)]`), damit die Blockfassung und die
     Tabellenfassung dieselben Wörter zeigen.

BAUPLAN:

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Kennzahl.swift` – Ton für `--alert`
     ergänzen; `apps/ios/DuckCurveHome/Gestalt/Farben.swift:120-129` abbilden;
     `Zustand/Fahrplankacheln.swift:50, 74` darauf umstellen. Test in
     `DuckCurveKit/Tests/DuckCurveKitTests/` auf die Kachelfarbe der ersten und vierten Kachel.
  2. `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:70-78` – `spalten:
     schmal ? 2 : (breitGenug ? 7 : 4)`; dafür `@Environment(\.horizontalSizeClass)` in die
     Seite wie in `Seiten/Energie/StromSeite.swift:74`. Die siebenspaltige Stufe braucht
     `Gestalt/Karte.swift:306-332` nicht zu ändern, nur die übergebene Zahl.
  3. `apps/ios/DuckCurveHome/Gestalt/Karte.swift` – nichts, wenn 2. die Zahl liefert; sonst
     `Kachelfeld` eine zweite Spaltenzahl für `.compact` geben (`spaltenSchmal: Int = 2`), damit
     keine Seite die Breite selbst abfragen muss.
  4. `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:18-41, 42-47` – Horizontspanne
     und Entscheidungsuntertitel von `titel:` auf `beiwerk:` umhängen, in `Schrift.zahlKlein`
     bzw. `Schrift.winzig` auf `Farbe.text3`, Vorbild `:166-175`.
  5. `apps/ios/DuckCurveHome/Diagramme/Fahrplanzeichnung.swift:125-182` – ein gemeinsamer
     Achsenstreifen: eine Konstante `achsenbreite` (am Telefon 34, am iPad 42 – die Vorlage hat
     56 CSS-Punkte bei kleinerer Schrift), die Zahlen in einer eigenen Spalte links neben dem
     `Chart` mit `.chartYAxis(.hidden)`, und unter allen acht Flächen eine Zeitachse, die mit
     `Spacer().frame(width: achsenbreite)` eingerückt ist. Vorbild im Projekt:
     `Diagramme/Abdeckungskarte.swift:42, 108, 182` und `Diagramme/Kennlinienbilder.swift:412,
     509, 517`; die handgezeichnete Fassung in `Diagramme/Wirkungszeichnung.swift:139`.
  6. Dieselbe Datei, `:28-33` – den Leerhinweis der Preisfläche entfernen (die Vorlage hat
     keinen); `:167-174` – y-Beschriftung und Raster auch dann zeichnen, wenn ein Hinweis steht.
  7. Dieselbe Datei, `:260-299` – `.interpolationMethod(.stepEnd)` aus den vier Wärmemarken
     nehmen; `:248` – `lineWidth: 1.5` und `.interpolationMethod(.catmullRom)` für die
     PV-Erwartung.
  8. Dieselbe Datei, `:109-111` – dem Auskunftsfeld den Rand `Farbe.amber.opacity(0.4)` und die
     Fläche `Farbe.deep` geben; `:427` – Abstände 20/8.
  9. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift` – kurzes Centformat
     (ES FEHLT 2), danach `FahrplanSeiten.swift:95` und
     `Zustand/Fahrplanbild.swift:283` darauf umstellen.
 10. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Planauswahl.swift` – die Zellwörter in
     die `Entscheidung` ziehen (ES FEHLT 3), mit Test.
 11. `apps/ios/DuckCurveHome/Seiten/Bericht.swift` – `Tabelle` eine dritte Handyfassung geben
     (`case block`), die je Zeile das Raster aus `handy.css:319-329` zeichnet: Zeile 1 Zeit
     (15 pt, `Farbe.text1`) und rechts das Zustandswort in seiner Rolle (14 pt), Zeile 2 drei
     Werte links und rechts „Ofen …" in `Farbe.text3`, Zeile 3 die Begründung über die ganze
     Breite, umbrechend; Haarlinie oben, erste Zeile ohne. Dann in
     `FahrplanSeiten.swift:91-113` `handyfassung: .block` setzen. Dieselbe Fassung brauchen
     danach `.kosten-tabelle`, `.nb-tabelle` und `.fenster-tabelle` – also in den Baustein und
     nicht in die Seite.
 12. Derselbe Baustein, `:445-459` und `:431-443` – eine Spalte „links, Sans, text3" zulassen
     (etwa `Spalte.satzspalte: Bool`) für „Warum", und der Namensspalte einen Kopfnamen geben;
     `FahrplanSeiten.swift:92-93` setzt dann `zeilenname: "Zeit"`.
 13. `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:13-62` – den Aufbau umdrehen:
     Kacheln, Horizontkarte, Entscheidungskarte und Methode **immer** zeichnen; ohne
     Intervalle in der Horizontkarte `Fahrplanworte.ohnePlan` an die Stelle der Zeichnung (die
     Legende bleibt), in der Entscheidungskarte „Noch keine Preise im Horizont."; `haus.fehler`
     als `Stoerung` oben in die Horizontkarte, mit `Task { await haus.ersteLadung() }` als
     Wiederholung. `Fahrplankacheln.kacheln(haus.plan)` nimmt `nil` schon.
 14. Dieselbe Datei, `:49-58` – die zwei selbstgebauten Methodenzeilen streichen; wenn der
     Planername bleiben soll, steht er wie in der Vorlage im Beiwerk der Horizontkarte (4.).
 15. `apps/ios/DuckCurveHome/Seiten/Bericht.swift:542-549` – die Methodenabsätze auf
     `Schrift.klein`/`Farbe.text2` (am Telefon eine Stufe größer) bringen. Trifft dreizehn
     Seiten; gehört daher in einen eigenen Schritt und nicht in diesen Umbau.

WAS SCHWIERIG WIRD:

  * **Acht Gitter mit einer Kante.** ECharts kennt `grid.left` in Punkten und zeichnet alle
    Flächen in **eine** Zeichnung (`Fahrplan.tsx:291`). Swift Charts hat kein Gegenstück: acht
    `Chart` sind acht Zeichnungen, und `AxisMarks(position: .leading)` nimmt sich so viel Platz,
    wie seine Beschriftung braucht. Der im Projekt gewählte Weg ist, die Achse selbst zu setzen
    und ihre Breite festzuschreiben: `Diagramme/Abdeckungskarte.swift:42` (`achsenbreite`),
    `:108` (die Zahl in `frame(width:alignment: .trailing)`), `:182`
    (`Spacer().frame(width: achsenbreite)` unter der Zeichnung), ebenso
    `Diagramme/Kennlinienbilder.swift:412, 509, 517` und
    `Diagramme/Wirkungszeichnung.swift:139`. `Diagramme/Tageskurve.swift:273, 332, 352-372`
    zeigt die andere, hier nicht ausreichende Lösung: zwei Flächen mit eigener y-Achse und eine
    dritte, leere Zeichnung nur für die Zeitachse – die hängt an derselben Verschiebung.
  * **Ein Zeiger über acht Flächen.** Die Vorlage verbindet die Achsen mit
    `axisPointer: { link: [{ xAxisIndex: "all" }] }` (`Fahrplan.tsx:309`). Swift Charts hat
    `chartXSelection`; die Seite teilt dafür schon einen `@State` über alle acht Flächen
    (`Fahrplanzeichnung.swift:23, 152`). Das funktioniert, verschiebt aber mit den Plotflächen
    auch die Trefferpunkte – nach Schritt 5 des Bauplans rechnet jede Fläche in derselben
    Breite, vorher nicht.
  * **Das Wort „RESERVE" im Bild.** `markArea.label` mit `insideBottomLeft`
    (`Fahrplan.tsx:228`) hat in Swift Charts kein Gegenstück; die Seite hat es deshalb in den
    Flächentitel gezogen (`Fahrplanzeichnung.swift:369-374`). Wer es ins Bild holen will,
    braucht `.chartOverlay` mit `ChartProxy.position(forY:)` – im Projekt so gemacht in
    `Diagramme/Tageskurve.swift:287-289, 382-400`.
  * **Zwei gestapelte Flächen.** Swift Charts stapelt `AreaMark` nicht wie ECharts' `stack`.
    Der gewählte Weg steht in `Fahrplanzeichnung.swift:253-259`: erst die **Summe** zeichnen,
    darüber das Heizen, und die Kante des Warmwassers liegt damit auf der Summe. Die Summe
    kommt dafür aus dem Kern (`Zustand/Fahrplanbild.swift:119-122`) und nicht aus der Ansicht –
    laut Kommentar war sie in der Ansicht schon zweimal falsch.
  * **Die Blockfassung der Tabelle.** `handy.css:319-329` ist ein CSS-Raster mit vier Spalten
    und drei Zeilen über *eine* `tr`. In SwiftUI ist das ein `Grid` oder zwei `HStack` plus ein
    `Text`; die Schwierigkeit ist nicht das Zeichnen, sondern dass `Tabelle` dreizehn Seiten
    trägt (`Seiten/Bericht.swift:158-164`) – die neue Fassung muss wahlfrei sein und die
    bestehenden Rufe unberührt lassen, wie es `handyfassung` und `auswahl` schon vormachen.
