========================= messen:waermepumpe-kennlinie   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`, eingehängt in
`apps/ios/DuckCurveHome/App/Seitenwahl.swift:70-71` auf `/waerme/waermepumpe/kennlinie`):

1. `Tagewahl(tage:moeglich: [7, 30, 90])` — Kapselknöpfe, `KennlinieSeite.swift:24`,
   Baustein `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift:377-400`.
2. `Stoerung`, nur bei Fehler, mit Knopf „Erneut" (`KennlinieSeite.swift:25-27`;
   `apps/ios/DuckCurveHome/Gestalt/Karte.swift:410-436`).
3. Bei `fehltDe` eine Karte mit `Leer(satz: "Für eine Kennlinie fehlt etwas.", dazu: fehlt)`
   (`KennlinieSeite.swift:29-31`).
4. Karte „Die gemessene Kurve", Titel = `fit.formelDe`, darin sechs `Zeile`n: Art, Streuung,
   Bestimmtheit, Messpunkte, „gilt für draußen", „und für Vorlauf", darunter `fit.geltungDe`
   in `Schrift.winzig`/`Farbe.text3` (`KennlinieSeite.swift:73-105`).
5. Karte „Messpunkte": **ein** Swift-Chart, 220 Punkte hoch — `PointMark` je Punkt
   (`symbolSize(18)`, `opacity(0.75)`, Farbe aus `vorlauffarbe`), darüber die Fit-Gerade
   (`Farbe.text1`, 1,8 pt) und die Annahme (`Farbe.mist`, 1,4 pt, Strich 4/4); darunter eine
   handgebaute Legende (`KennlinieSeite.swift:113-173`, Legende `:199-227`).
6. Karte „Woher die Punkte kommen": neun `Zeile`n (Minuten im Zeitraum, davon geheizt, Anlauf,
   mit Zusatzheizung, ohne Messwert, ohne Wärmemenge, unglaubwürdig, Trennlinie, brauchbar),
   dann `b.satzDe`, dann „Was einzeln fehlte" als Schlüssel/Wert-Liste
   (`KennlinieSeite.swift:246-293`).
7. Karte „Angenommene Kurve" / Titel „bei N °C Vorlauf": `Tabelle` mit einer Spalte
   „Arbeitszahl" über den Annahme-Stützstellen, darunter zwei Sätze
   (`KennlinieSeite.swift:41-64`).
8. `Methode(k.hinweiseDe)` — zugeklappte Karte (`KennlinieSeite.swift:65`;
   `apps/ios/DuckCurveHome/Seiten/Bericht.swift:334-398`).
9. Ladezustand: Karte mit `Leer(satz: "Wird geholt …")` (`KennlinieSeite.swift:66-68`).

Geladen wird in `lade()` über `haus.api.kennlinie(tage:)` (`KennlinieSeite.swift:295-304`).

VORLAGE:

Einstieg `apps/web/src/app/waerme/waermepumpe/kennlinie/page.tsx:1-13`: `AreaShell` mit
`kicker="Arbeitszahl · gemessen"` (`:9`), Inhalt `<Kennlinie />`. Der Kicker landet in
`AreaTabs right=` (`apps/web/src/components/layout/AreaShell.tsx:26`). `.kicker` ist
`--font-mono`, 13 px, `letter-spacing: .13em`, `uppercase`, Farbe `--text-kicker` = `--mist`
(`apps/web/src/styles/globals.css:57-64`, `apps/web/src/styles/tokens.css:15,35`); am Handy
wird der Kicker einer Kartenkopfzeile zu 16,5 px Sans, halbfett, ohne Sperrschrift
(`apps/web/src/styles/handy.css:184`).

Rahmen der Seite: `.wp-seite { display:flex; flex-direction:column; gap:16px }`
(`globals.css:787`).

  * **Kopfsatz** (`Kennlinie.tsx:116-122`, Rechnung `:108-113`)
    `.wp-kopf` Spalte, `gap: 4px`; `.wp-satz` 22 px, `line-height 1.3`, `--text-1`
    (`globals.css:788-789`), am Handy 19 px (`handy.css:234`).
    Wörtlich, drei Fassungen:
    - mit Fit: `Nach {f.n} Messpunkten macht die Wärmepumpe bei {ta|0} °C draußen und {tv|0} °C
      Vorlauf aus einer Kilowattstunde Strom {copNach(f,ta,tv)|1} Kilowattstunden Wärme.`
      (`Kennlinie.tsx:110`) — `ta`/`tv` sind die **Mediane** der Punkte (`:101-102`,
      `kennlinie.ts:40-45`).
    - ohne Fit, mit Punkten: `{n} Messpunkt(e) bisher, Arbeitszahl im Mittel {mittel|1}.`
      (`:112`)
    - sonst: `Noch gibt es keine Messpunkte.` (`:108`)
    `.wp-stand` 13 px `--text-3`: `Letzte {daten.tage} Tage` und, bei Fehler, ` · {fehler}`
    (`:119-121`, `globals.css:790`). Fehlertext wörtlich:
    `Die Kennlinie ist gerade nicht zu erreichen.` (`:83`).
    DATEN: `api.kennlinie(t)`, Felder `tage`, `punkte[]`, `fit`.

  * **Tagewahl** (`Kennlinie.tsx:124-130`)
    `TAGE = [7, 30, 90, 180]` (`:22`). `.kl-wahl` Flex, `gap 6px`, umbruchfähig; `.kl-knopf`
    `padding 7px 13px`, Rand `--line-1`, `border-radius 999px`, 13 px, `--text-2`; gewählt:
    Fläche `--amber`, Schrift `--petrol`, `font-weight 600`
    (`globals.css:892-895`). `role="group" aria-label="Rückblick"`, `aria-pressed`.

  * **`fehlt_de`** (`Kennlinie.tsx:132-136`)
    `.wp-stumm` als eigener Hinweiskasten, **nicht** als Karte: `padding 12px 14px`,
    `border 1px solid color-mix(--amber 55%)`, Fläche `color-mix(--amber 9%)`,
    `border-radius 12px`, 14 px, `line-height 1.5`, `--text-1`, `max-width 760px`,
    `role="status"` (`globals.css:792`). Text = Dienstfeld, kein eigener Satz.

  * **Vier Kennzahlkacheln** (`Kennlinie.tsx:138-153`)
    `.kpi-grid.kpi-handy` mit `--cols: 4`; Raster = `repeat(auto-fit, minmax(clamp(150px, 100%/4
    - 16px, 260px), 1fr))`, `gap 16px` (`globals.css:107`). Am Handy: zwei Spalten, Karten ohne
    Fläche und Rand, nur Haarlinie oben, erste Kachel führt über die ganze Breite mit 48 px
    Zahl (`handy.css:196-207`). `Stat` = `apps/web/src/components/ui/Stat.tsx:4-19`: Kicker
    11 px, Zahl `mono` 26 px, `tracking -.02em`, Kontextzeile 12 px `line-clamp-2`.
    Wörtlich:
    1. `Messpunkte` / `String(n)` / Ton `amber` wenn `n`, sonst `muted` / Hinweis
       `je zehn Minuten Heizbetrieb`
    2. `Arbeitszahl im Mittel` / `zahl(mittel)` oder `?` / Hinweis
       `Wärme durch Strom, alle Punkte` — `mittel = gesamt(punkte)` ist **nach Minuten und
       Leistung gewichtet**: Σ(waerme_kw·minuten) / Σ(strom_kw·minuten), nicht das Mittel der
       Einzel-COPs (`kennlinie.ts:32-38`, Kommentar nennt den Grund: „Ein Fenster mit 4 kW
       zählt mehr als eines mit 1 kW").
    3. `Je Grad wärmer draußen` / `+/−{|b_aussen|, 2 Stellen}`, nur bei `art` `ebene` oder
       `aussen`, sonst `?` und Ton `muted` / Hinweis `Arbeitszahl, nach Ausgleich`
    4. `Je Grad mehr Vorlauf` / dito mit `c_vorlauf`, nur bei `ebene` oder `vorlauf`
    Minuszeichen ist U+2212 („−"), nicht der Bindestrich (`:143,149`).
    DATEN: `punkte[].waerme_kw/strom_kw/minuten`, `fit.art/b_aussen/c_vorlauf`.

  * **Bilanz, oben — nur wenn es keine Punkte gibt** (`Kennlinie.tsx:155`:
    `daten.bilanz && !n`). Dieselbe Karte steht unten, wenn es Punkte gibt (`:225`). Das ist
    Absicht: ohne Punkte ist die Bilanz die Hauptaussage der Seite.
    Karte `Bilanz` (`Kennlinie.tsx:29-71`), `.card.kl-karte`
    (`globals.css:67-76`: Fläche `--surface-2`, Rand `--line-1`; `:900`: Spalte, `gap 10px`,
    `padding 16px`), Titel `.kl-titel` 15 px halbfett `--text-1` (`:901`), Text wörtlich
    `Wo die Minuten geblieben sind` (`:35`).
    - Balken `.kl-bilanz`: Flex, `gap 2px`, **Höhe 22 px**, Teile `flex-grow = minuten`,
      `min-width 4px`, `border-radius 4px` (`globals.css:914-915`). Die Teile kommen aus
      `teile(b)` (`bilanz.ts:24-28`) in **fester Reihenfolge** (`bilanz.ts:15-22`), mit
      Namen und Begründung wörtlich:
      `brauchbar` / „eingeschwungen, alle Werte da" / `--amber`;
      `Anlauf` / „die ersten zehn Minuten nach jedem Start" /
      `color-mix(in oklab, --text-3 70%, transparent)`;
      `Heizstab` / „neben dem Verdichter nahm etwas anderes Strom auf" / `--heat-pump`;
      `keine Wärme` / „kaum Durchfluss oder keine Spreizung" / `--line-2`;
      `Wert fehlte` / „ein nötiger Wert kam länger nicht vom Bus" / `--alert`
      (Farben `globals.css:916-920`). Der Kommentar `bilanz.ts:20` begründet die Reihenfolge:
      „Zuletzt, und nicht neben dem Heizstab: die beiden warmen Töne lägen sonst aneinander."
      Ein Teil mit 0 Minuten steht nicht im Balken (`bilanz.ts:27`).
    - `role="img"` mit `aria-label`: `Von {dauer(b.heizen)} im Heizbetrieb: {name dauer}, …`
      (`Kennlinie.tsx:38`), `title` je Teil `{name}: {dauer}` (`:40`).
    - Legende `.kl-bilanz-legende` als Liste, Raster
      `12px 108px 96px 44px minmax(0,1fr)`, `column-gap 10px`, 14 px
      (`globals.css:921-926`); je Zeile Punkt (10 px, `radius 3px`), Name, Dauer in `mono`,
      **Anteil in ganzen Prozent rechtsbündig**, dann die Begründung in 13 px `--text-3`.
      Am Handy: Raster `12px minmax(0,1fr) max-content 40px`, die Begründung rutscht in eine
      eigene zweite Zeile über die volle Breite (`handy.css:248-249`).
    - Ohne Teile stattdessen nur `b.satz_de` in `.kl-klein` (13 px, `line-height 1.5`,
      `--text-3`, `max-width 760px`; `globals.css:898`) (`Kennlinie.tsx:55-57`).
    - Danach, wenn `fehlt` belegt (sortiert, häufigster zuerst, `bilanz.ts:39-44`), wörtlich:
      `Gefehlt hat: {name} ({dauer}), …. Kommt ein Wert dauerhaft nicht, liegt es an der
      Zuordnung auf dem Bus und nicht an der Wärmepumpe.` (`:60`).
    - Zuletzt wörtlich: `Aus den brauchbaren Minuten wurde 1 Messpunkt` bzw.
      `wurden {b.punkte} Messpunkte`, und bei `halbeFenster(b) > 0` angehängt
      `; {halb} angefangene Fenster hatten zu wenige davon` + Punkt (`:63-68`).
      `halbeFenster = max(0, fenster - punkte - unglaubwuerdig)` (`bilanz.ts:47-49`).
    - `dauer()` schreibt „45 min", „3 h 20 min", „2 h" (`bilanz.ts:31-36`).
    DATEN: `bilanz.{minuten,heizen,anlauf,zusatz,ohne_wert,ohne_waerme,gueltig,fenster,punkte,
    unglaubwuerdig,fehlt,satz_de}`.

  * **Formelkarte** (`Kennlinie.tsx:157-166), nur bei `fit`
    `.card.kl-formel`: Spalte, `gap 8px`, `padding 16px` (`globals.css:896`).
    Kicker wörtlich `Ausgleich nach kleinsten Quadraten` (`:159`).
    `.kl-formel-zeile mono`: `font-size: clamp(15px, 1.7vw, 20px)`, `--text-1`,
    `overflow-wrap: anywhere` (`globals.css:897`), Inhalt `f.formel_de`.
    Darunter `.kl-klein` wörtlich: `{f.n} Punkte · mittlere Abweichung ±{rmse|2}` und, wenn
    `r2 != null`, ` · erklärt {round(r2*100)} % der Streuung`, dann `. {f.geltung_de}`
    (`:161-164`). Also: r² **in Prozent**, rmse mit ±-Zeichen und zwei Stellen.

  * **Zwei Diagrammkarten nebeneinander** `.kl-paar`: Raster `repeat(2, minmax(0,1fr))`,
    `gap 16px` (`globals.css:899`); am Handy eine Spalte (`handy.css:235`).
    `.kl-chart { width:100%; height:320px }` (`globals.css:902`), am Handy 280 px
    (`handy.css:244`). Gezeichnet mit `EChart`
    (`apps/web/src/components/charts/EChart.tsx:31-84`), am Handy durch `fuerHandy`
    nachgestellt: Achsenschrift mindestens 11 px, `hideOverlap`, Wertachsen höchstens drei
    Schritte, Legende scrollt in einer Zeile, Tooltip bleibt im Bild
    (`apps/web/src/components/charts/handy.ts:21-62`).

    * **Karte „Arbeitszahl über der Außentemperatur"** (`Kennlinie.tsx:169-179`,
      Option `kennlinie.ts:122-179`)
      `grid: { left:40, right:104, top:14, bottom:58 }` — die 104 px rechts sind für die
      `endLabel` der Geraden. x-Achse `value`, `scale: true`, Name `Außentemperatur °C`,
      `nameLocation middle`, `nameGap 26`; y-Achse Name `COP`, `min/max` aus `copAchse(d)` =
      `[max(0, floor(min-0.25)), ceil(max+0.25)]` über Punkte **und** Annahme
      (`kennlinie.ts:115-119`). Achsenstil `achse` (`:97-105`): `axisLine.onZero: false` —
      Kommentar `:98-99` nennt den Grund („mit der Vorgabe wandert die senkrechte Achse auf
      null Grad und steht mitten zwischen den Punkten"), keine Ticks, Beschriftung
      `C.text` = `rgba(255,255,255,.48)`, Mono 10 px, Rasterlinien
      `C.gridline` = `rgba(255,255,255,.09)`, Achslinie `C.axis` = `rgba(255,255,255,.2)`
      (`apps/web/src/components/charts/palette.ts:78-81`).
      Reihen:
      - `Annahme des Fahrplans`: Linie über `annahme`, **mit** Symbolen (`emptyCircle`,
        `symbolSize 5`), `rgba(255,255,255,.5)`, 1,5 px, gestrichelt; eigener Tooltip
        `Annahme des Fahrplans, bei {annahme_vorlauf_c|0} °C Vorlauf<br/>{x|0} °C draußen:
        {y|1}` (`:155-166`).
      - **Mehrere Ausgleichsgeraden, eine je Vorlaufstufe**: `vorlaufStufen(f)` nimmt die
        runden Fünfer innerhalb `[vorlauf_von_c, vorlauf_bis_c]`, höchstens drei (erste,
        mittlere, letzte) und nur bei `art === "ebene"` (`kennlinie.ts:49-55`). Jede Gerade
        trägt die **Wasserfarbe ihres Vorlaufs** `farbe(tv)`, 2 px, und ein `endLabel`
        rechts am Kurvenende mit dem Text `{tv} °C Vorlauf`, Mono 10 px, `distance 6`
        (`:128-142`). Ohne Vorlaufterm genau eine Gerade, Name `Ausgleich`, Farbe
        `rgba(255,255,255,.85)` (`:130`).
      - `Messpunkt` als `scatter`, `symbolSize 9`, Punktfarbe `farbe(p.vorlauf_c)`,
        **Rand 1,5 px in `FLAECHE = "#123544"`**, also in der Kartenfläche (`:168-176`,
        `:106`); Tooltip je Punkt `punktZeile` (`:108-112`): Kopfzeile Datum/Uhrzeit
        `dd.MM, HH:mm` in `Europe/Berlin`, darunter die Zeilen `Arbeitszahl` (2 Stellen),
        `draußen`, `Vorlauf`, `Wärme` (kW), `Strom` (2 Stellen, kW).
      - Legende unten links, nur `["Messpunkt", "Annahme des Fahrplans"]`, `itemWidth 16`,
        `itemHeight 8`, Mono 10 px (`:150`).
      - Tooltip-Kasten: Fläche `C.deep` = `#082431`, Rand `rgba(255,255,255,.14)`,
        `borderRadius 3`, Mono 12 px (`:90-96`).
      Farbe der Punkte = `farbe()` aus `apps/web/src/components/anlage/schema.ts:39-52`, die
      Wassertemperaturskala mit Stützstellen 10/25/35/45/55/65 °C
      (`#1a3a52, #1f4c66, #7fa3b3, #ffd778, #f2a900, #e0533d`, `schema.ts:25-32`). Der
      Kommentar `kennlinie.ts:22-23` sagt, warum: „ein Punkt bei 35 Grad hat die Farbe von 35
      Grad warmem Wasser im Speicher".
      Darunter `.kl-skala` (nur wenn Punkte da sind): Flex, `gap 10px`, 12 px Mono,
      `--text-3`; `.kl-skala-band` `flex: 0 1 180px`, `height 8px`, `radius 4px`
      (`globals.css:904-906`). Inhalt: `Vorlauf {min|0} °C`, ein
      `linear-gradient(90deg, …)` aus fünf Stützen `farbe(min + (max-min)·x)` für
      x = 0/.25/.5/.75/1, dann `{max|0} °C`; `aria-label`
      `Farbe der Punkte: Vorlauf von {min|0} bis {max|0} Grad` (`Kennlinie.tsx:173-177`).
      Die Grenzen sind `min`/`max` des **gemessenen** Vorlaufs (`:105-106`).

    * **Karte „Arbeitszahl über der Vorlauftemperatur"** (`Kennlinie.tsx:180-183`,
      Option `kennlinie.ts:182-222`)
      Begründung im Kommentar `kennlinie.ts:16-18`: „Solange das Wetter sich nicht ändert, ist
      das die Ansicht, in der überhaupt etwas zu sehen ist: eine Pufferladung durchläuft
      zwanzig Grad Vorlauf an einem Vormittag."
      `grid { left:40, right:18, top:14, bottom:58 }`, x-Achse `Vorlauftemperatur °C`,
      y-Achse `COP`, `copAchse` hier **ohne** Annahme gerechnet (`:184`). Eine Gerade über
      `[vorlauf_von_c, vorlauf_bis_c]` bei **mittlerer** Außentemperatur, Name wörtlich
      `Ausgleich bei {ta|0} °C draußen`, `rgba(255,255,255,.85)`, 2 px (`:186, :197-210`).
      Punkte alle in **einer** Farbe `C.heatPump` = `#e0966b`, `symbolSize 9`, Rand 1,5 px
      `#123544`, derselbe `punktZeile`-Tooltip (`:211-219`).

  * **Karte „Kennfeld: beide Temperaturen zugleich"** (`Kennlinie.tsx:186-196`,
    Option `kennlinie.ts:249-301`)
    `.kl-chart.kl-chart-feld` 380 px hoch (`globals.css:903`), am Handy 320 px
    (`handy.css:245`). Nur bei `fit.art === "ebene"`, sonst `null` (`:251`).
    Raster: ganze Grad draußen von `floor(aussen_von_c)` bis `ceil(aussen_bis_c)`, Vorlauf in
    **Zweiergraden** (`kennlinie.ts:225-231`). Zellenwert = `copNach(f, ta, tv)`, auf zwei
    Stellen gerundet (`:254`).
    Heatmap-Reihe `Arbeitszahl nach Ausgleich` mit Zellenrand 1 px in `#123544`,
    Hervorhebung weiß (`:290`). Darüber `scatter` `Messpunkte` aus `belegung()`
    (`:234-243`, Vorlauf auf zwei Grad gerundet): Kreis, Größe
    `5 + 7·sqrt(anzahl / meiste)`, Füllung `rgba(8,36,49,.85)`, Rand weiß 1,2 px (`:291-298`).
    `visualMap` senkrecht rechts, `itemHeight 140`, `itemWidth 10`, `calculable: false`,
    `min/max` auf halbe Schritte gerundet, Text oben `COP {max|1}` und unten `{min|1}`,
    Rampe `COP_FARBEN = ["#173847","#2f5560","#667a5c","#b3993f","#f2a900","#ffd778"]`
    (`:246, :274-288`).
    Tooltip wörtlich: Ort `{aussen} °C draußen, {vorlauf} °C Vorlauf`, dann je nach Reihe
    `{v} Messpunkt(e)` oder `Arbeitszahl nach Ausgleich: {v|2}` (`:262-270`).
    Erklärsatz unter dem Bild, wörtlich (`Kennlinie.tsx:191`):
    `Die Farbe ist die Arbeitszahl nach dem Ausgleich. Ein Kreis steht, wo gemessen wurde; je
    größer, desto mehr Punkte.`
    Leerzustand statt des Bildes, wörtlich (`:194`):
    `Das Kennfeld entsteht, sobald sich der Einfluss beider Temperaturen bestimmen lässt: wenn
    die Messpunkte draußen mindestens vier und im Vorlauf mindestens fünf Grad auseinanderliegen,
    und nicht im Gleichschritt.`

  * **Karte „Messung gegen die Annahme des Fahrplans"** (`Kennlinie.tsx:198-223`), nur wenn
    `vergleich(d)` Zeilen hat und `vergleichsVorlauf(d) != null`
    `.kl-tabelle`: ganze Breite, `border-collapse`, 14 px; `th` linksbündig, `font-weight 500`,
    12 px, `--text-3`, `padding 6px 10px 6px 0`, Linie unten `--line-1`; `td` `padding
    7px 10px 7px 0`, Linie unten `--line-1`, `--text-1`; **`tr[data-gemessen="false"] td`
    färbt die ganze Zeile `--text-3`** (`globals.css:907-910`). Am Handy 13 px und die Karte
    scrollt waagerecht (`handy.css:246-247`).
    Spaltenköpfe wörtlich: `draußen` · `Annahme` + bei bekanntem Vorlauf
    ` ({annahme_vorlauf_c|0} °C Vorlauf)` · `Messung ({beiVorlauf|0} °C Vorlauf)` · `Stand`.
    Zellen: `{aussen|0} °C`, `{annahme|1}`, `{messung|1}`, Stand `gemessen` oder `verlängert`.
    Rechnung `kennlinie.ts:68-86`: `vergleichsVorlauf` nimmt den Vorlauf der **Annahme**, wenn
    der Fit den Vorlauf kennt (`ebene`/`vorlauf`), sonst den Median des gemessenen Vorlaufs —
    Kommentar `:66-67`: „denn nur dort sagt er etwas". `gemessen` ist wahr, wenn Vorlauf und
    Außentemperatur beide im Geltungsbereich liegen.
    Schlusssatz wörtlich (`:221`):
    `„Verlängert" heißt: bei dieser Temperatur wurde noch nicht gemessen, die Zahl folgt aus der
    Formel. Der Fahrplan rechnet weiter mit seiner Annahme; übernommen wird nichts von selbst.`

  * **Bilanz, unten** (`Kennlinie.tsx:225`) — dieselbe Karte wie oben, wenn `n > 0`.

  * **Messpunkte als Tabelle** (`Kennlinie.tsx:227-260`), nur bei `n > 0`
    `details.kl-liste`: 14 px, `--text-2`, Griff mit `cursor: pointer`, `padding 6px 0`, offen
    `margin-bottom 8px` (`globals.css:1025-1027`). Griff wörtlich:
    `Die Messpunkte als Tabelle ({n})`.
    Sieben Spalten: `Zeit` · `draußen` · `Vorlauf` · `Wärme` · `Strom` · `Arbeitszahl` ·
    `Ventil`. Zeilen **umgekehrt** (neueste zuerst) und auf **200** gekappt (`:243-245`).
    Zeit `dd.MM, HH:mm` in `Europe/Berlin`; Wärme `{|1} kW`, Strom `{|2} kW`, Arbeitszahl
    `{|2}`, Ventil `p.ventil ?? "?"`. Am Handy scrollt die Liste waagerecht
    (`handy.css:246-247`).

  * **Fuß** (`Kennlinie.tsx:262-272`)
    `.wp-fuss`: Spalte, `gap 6px`, `max-width 760px`, 13 px, `line-height 1.55`, `--text-3`
    (`globals.css:795`). Darin **jeder** Satz aus `hinweise_de` als eigener Absatz, **offen
    sichtbar**, nicht zugeklappt. Dann `.wp-links`: Flex, umbruchfähig, `gap 6px 18px`,
    `margin-top 6px`, Links in `--amber` ohne Unterstreichung, Fokusring 2 px `--amber`
    (`globals.css:796-798`). Zwei Verweise wörtlich:
    `Die Wärmepumpe jetzt ›` → `/waerme/waermepumpe`;
    `Was die Wärme gekostet hat ›` → `/waerme/nachbetrachtung`.

  * **Ladezustand** (`Kennlinie.tsx:95-97`): solange `daten == null` **nur** ein Absatz,
    15 px `--text-3`, Text `Die Kennlinie wird geladen …` oder der Fehlersatz. Keine Karte.

  * **Handy-Fassung, zusammengefasst** (`handy.css`): Kopfzeile der Datei nennt die vier
    Entscheidungen — Bereiche unten, „eine Zahl führt", „Flächen statt Rahmen", „Tabellen
    werden Listen" (`handy.css:1-26`). Für diese Route gilt: `.wp-satz` 19 px (`:234`),
    `.kl-paar` einspaltig (`:235`), `.kl-chart` 280 px / `.kl-chart-feld` 320 px (`:244-245`),
    `.kl-liste`/`.kl-karte` scrollen waagerecht (`:246`), `.kl-tabelle` 13 px (`:247`),
    Bilanzlegende vierspaltig mit der Begründung in eigener Zeile (`:248-249`), Karten ohne
    Rand, `radius 16px`, `padding 16px` (`:182`), Kartenkicker als 16,5-px-Überschrift
    (`:184`), KPI-Kacheln ohne Fläche mit Haarlinie oben und 48-px-Führungszahl (`:198-207`).
    Gesucht nach weiteren `kl-`/`wp-`-Regeln in `handy.css`: außer den genannten kein Treffer.

LUECKEN:

  [traegt-die-seite] Der Kopfsatz fehlt ganz. Die Vorlage sagt die Hauptaussage in einem Satz
  über allem (`Kennlinie.tsx:110-118`); die App beginnt mit der Tagewahl
  (`KennlinieSeite.swift:24`) und nennt die Kernzahl „aus einer kWh Strom X kWh Wärme" nirgends.
  Auch der Stand `Letzte N Tage` fehlt.

  [traegt-die-seite] Die vier Kennzahlkacheln fehlen (`Kennlinie.tsx:138-153`). Damit fehlen
  drei Zahlen, die es in der App überhaupt nicht gibt: die **gewichtete** Gesamt-Arbeitszahl
  (`kennlinie.ts:32-38`), „Je Grad wärmer draußen" und „Je Grad mehr Vorlauf" als vorzeichen-
  behaftete Steigungen. Die App zeigt stattdessen `a/b/c` nur mittelbar über `formelDe`
  (`KennlinieSeite.swift:74`).

  [traegt-die-seite] Das zweite Diagramm „Arbeitszahl über der Vorlauftemperatur" fehlt
  (`Kennlinie.tsx:180-183`, `kennlinie.ts:182-222`). Der Kommentar `kennlinie.ts:16-18`
  begründet es als die Ansicht, in der an einem gleichbleibenden Wettertag überhaupt etwas zu
  sehen ist — genau der häufige Fall.

  [traegt-die-seite] Das Kennfeld fehlt vollständig (`Kennlinie.tsx:186-196`,
  `kennlinie.ts:249-301`): Heatmap, Belegungskreise, Farbskala, Tooltip, Erklärsatz und der
  Leerzustandssatz, der sagt, wann es überhaupt entsteht. Gesucht nach `Kennfeld`, `heatmap`,
  `RectangleMark` in `KennlinieSeite.swift`: kein Treffer.

  [traegt-die-seite] Die Vergleichstabelle „Messung gegen die Annahme des Fahrplans" fehlt
  (`Kennlinie.tsx:198-223`). Die App zeigt stattdessen eine einspaltige Tabelle „Angenommene
  Kurve" mit nur den Annahmewerten (`KennlinieSeite.swift:41-64`) — der Vergleich, also die
  Aussage der Karte, und die Unterscheidung `gemessen`/`verlängert` fehlen ganz.

  [traegt-die-seite] Die Bilanz ist in der App eine Zahlenliste, in der Vorlage ein Balken mit
  Legende (`Kennlinie.tsx:33-53`). Es fehlen: der Balken selbst (22 px, Anteil nach Minuten),
  die Anteile in Prozent, die fünf Begründungssätze („eingeschwungen, alle Werte da" usw.,
  `bilanz.ts:15-22`), die Reihenfolge mit ihrer Farbbegründung, der Satz „Gefehlt hat: …
  Zuordnung auf dem Bus", der Satz über die angefangenen Fenster (`halbeFenster`) und die
  Dauerformatierung („3 h 20 min" statt „200").

  [traegt-die-seite] Die aufklappbare Messpunkttabelle mit sieben Spalten fehlt
  (`Kennlinie.tsx:227-260`). Die Rohpunkte sind in der App nur als Streubild sichtbar, also
  nicht ablesbar — und `ventil` erscheint nirgends.

  [spuerbar] Nur **eine** Ausgleichsgerade statt bis zu drei. Die App setzt den Vorlauf auf die
  Mitte des Geltungsbereichs (`KennlinieSeite.swift:229-239`, Kommentar `:230-232`); die
  Vorlage zeichnet eine Gerade je runder Fünferstufe, in der Wasserfarbe dieser Stufe, mit
  Namen am Kurvenende (`kennlinie.ts:49-55, 128-142`). Das ist der „Antwortfächer", den der
  Kommentar in `KennlinieSeite.swift:109-112` selbst als die Beobachtung der Vorlage benennt.

  [spuerbar] Die Punktfarbe stimmt nicht. Die App mischt zwischen `Marken.waerme`
  (fünf Werte, Stützstellen 28/34/40/46/55 °C, `KennlinieSeite.swift:176-197`); die Vorlage
  nimmt die Wassertemperaturskala mit Stützstellen 10/25/35/45/55/65 °C
  (`schema.ts:25-32, 39-52`). Dieselbe Vorlauftemperatur hat damit in App und Browser
  verschiedene Farben — genau der Fehler, den `Marken.swift:170-175` für den Puffer schon
  einmal beschreibt und behebt.

  [spuerbar] Die Vorlauf-Farbskala unter dem ersten Diagramm fehlt. Die App zeigt fünf feste
  Kreise bei 28/34/40/46/55 °C (`KennlinieSeite.swift:203-210`); die Vorlage ein
  Verlaufsband von `min` bis `max` des **gemessenen** Vorlaufs (`Kennlinie.tsx:173-177`,
  `globals.css:904-906`).

  [spuerbar] Die Formelkarte fehlt als eigene Karte. In der App ist `formelDe` der Kartentitel
  (`KennlinieSeite.swift:74`), in 15 px; die Vorlage gibt ihr eine eigene Karte mit Kicker
  „Ausgleich nach kleinsten Quadraten" und `clamp(15px, 1.7vw, 20px)` Mono
  (`Kennlinie.tsx:158-165`, `globals.css:896-897`).

  [spuerbar] r² steht in der App als `0,842` (`KennlinieSeite.swift:84`), in der Vorlage als
  `erklärt 84 % der Streuung` (`Kennlinie.tsx:163`); rmse in der App als `0,123` ohne Zeichen,
  in der Vorlage als `mittlere Abweichung ±0,12` (`:162`).

  [spuerbar] Kein Tooltip an den Punkten. Die Vorlage gibt je Punkt Zeit, Arbeitszahl, draußen,
  Vorlauf, Wärme, Strom (`kennlinie.ts:108-112`); die App hat keine Auswahl im Chart. Das
  Projekt kann das: `.chartXSelection` in `Diagramme/Prognosezeichnung.swift:262` und
  `Diagramme/Wirkungszeichnung.swift:191`.

  [spuerbar] Die Achsen tragen keine Namen. Vorlage: x `Außentemperatur °C`, y `COP`, beide am
  Gitter (`kennlinie.ts:152-153`); App: `Außentemperatur in °C` als Wort in der Legendenzeile
  (`KennlinieSeite.swift:223`), kein `COP` irgendwo.

  [spuerbar] Der y-Bereich ist nicht gesetzt. `copAchse` klemmt ihn auf
  `[max(0, floor(min-0.25)), ceil(max+0.25)]` (`kennlinie.ts:115-119`); die App überlässt es
  Swift Charts (`KennlinieSeite.swift:158-168`), womit Annahme und Punkte unterschiedlich weit
  reichen können.

  [spuerbar] `180 Tage` fehlt in der Tagewahl: Vorlage `[7, 30, 90, 180]`
  (`Kennlinie.tsx:22`), App `[7, 30, 90]` (`KennlinieSeite.swift:24`).

  [spuerbar] `fehlt_de` steht in der Vorlage als Hinweiskasten in Amber mit `role="status"`
  (`Kennlinie.tsx:132-136`, `globals.css:792`), in der App als graue Karte mit dem eigenen
  Satz „Für eine Kennlinie fehlt etwas." (`KennlinieSeite.swift:30`) — ein Satz, den die
  Vorlage nicht hat.

  [spuerbar] `hinweise_de` steht in der Vorlage offen im Fuß (`Kennlinie.tsx:263-267`), in der
  App in einer zugeklappten `Methode`-Karte (`KennlinieSeite.swift:65`). Die Seite hat keine
  Kurzzeile, also verschwindet alles.

  [spuerbar] Die zwei Fußverweise fehlen (`Kennlinie.tsx:268-271`). Vorbild für den Baustein
  steht im Projekt: `Seiten/Technik/ReglerSeite.swift:358-372`.

  [spuerbar] Die Annahmelinie hat in der Vorlage Symbole (`emptyCircle`, 5 px) und einen
  eigenen Tooltip, der den Vorlauf der Annahme nennt (`kennlinie.ts:155-166`); die App zeichnet
  nur eine gestrichelte Linie (`KennlinieSeite.swift:137-145`).

  [spuerbar] Die Reihenfolge der Bilanz hängt in der Vorlage davon ab, ob es Punkte gibt: oben
  bei null Punkten, unten sonst (`Kennlinie.tsx:155, 225`). Die App setzt sie immer unten
  (`KennlinieSeite.swift:38-40`).

  [spuerbar] Zwei Diagramme nebeneinander am breiten Schirm (`.kl-paar`, `globals.css:899`)
  gegen eine einzelne Karte in der App; am Handy einspaltig (`handy.css:235`).

  [klein] Diagrammhöhe: 320 px (Handy 280) und 380 px für das Kennfeld (Handy 320)
  (`globals.css:902-903`, `handy.css:244-245`) gegen feste 220 Punkte
  (`KennlinieSeite.swift:169`).

  [klein] Punktgröße und Rand: `symbolSize 9` mit 1,5-px-Rand in der Kartenfläche `#123544`
  (`kennlinie.ts:172-173`) gegen `symbolSize(18)` mit `opacity(0.75)` ohne Rand
  (`KennlinieSeite.swift:121-124`). Der Rand trennt überlappende Punkte; die Deckkraft tut das
  nicht.

  [klein] Legendennamen: `Messpunkt` / `Annahme des Fahrplans` (`kennlinie.ts:150`) gegen
  `gemessen` / `angenommen` (`KennlinieSeite.swift:215, 220`).

  [klein] Linienbreite der Annahme: 1,5 px gestrichelt `rgba(255,255,255,.5)`
  (`kennlinie.ts:162`) gegen 1,4 pt `Farbe.mist` mit Strichmuster 4/4
  (`KennlinieSeite.swift:143-144`); die Fit-Linie ist in der Vorlage 2 px in der Vorlauffarbe,
  in der App 1,8 pt in `Farbe.text1`.

  [klein] Die Punktzahl der Fit-Linie: die Vorlage zieht zwei Endpunkte (`kennlinie.ts:136`),
  die App 24 Schritte (`KennlinieSeite.swift:234-238`) — bei einer Geraden dasselbe Bild, aber
  24 Marken statt 2.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Api.kennlinie(tage:) async throws -> KennlinieOut` —
    `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:308-310`, Pfad
    `/waermepumpe/kennlinie`, Frage `tage`. Deckt sich mit `api.kennlinie(t)` der Vorlage.
  * `KennlinieOut` — `…/Modelle/Schema.swift:6039-6095`: `now, von, bis, tage, punkte[], fit?,
    fehltDe?, annahme[], annahmeVorlaufC?, bilanz?, hinweiseDe[]`; Listen werden beim Decodieren
    auf `[]` vorbelegt (`:6086-6091`), also wie `lib/api/models.ts:87-92`.
  * `KennlinienPunktOut` — `Schema.swift:6258ff`: `at, minuten, aussenC, vorlaufC, cop,
    waermeKw, stromKw, ventil?`. Alle Felder, die die Vorlage braucht, sind da.
  * `KennlinienFitOut` — `Schema.swift:6192-6256`: `art, a, bAussen, cVorlauf, n, rmse, r2?,
    aussenVonC, aussenBisC, vorlaufVonC, vorlaufBisC, formelDe, geltungDe`; `art` als
    `KennlinienFitOutArtWahl` (`Schema.swift:593-603`) mit `ebene/aussen/vorlauf/mittel`.
  * `KennlinienBilanzOut` — `Schema.swift:6123ff`: `minuten, heizen, anlauf, zusatz, ohneWert,
    ohneWaerme, gueltig, fenster, punkte, unglaubwuerdig, fehlt, verhaeltnis?, satzDe`.
  * `KennlinienAnnahmeOut` — `Schema.swift:6097ff`: `aussenC, cop`.
  * `Marken.wasserfarbe(_:)` und `Marken.wasserstufen` —
    `…/Gestalt/Marken.swift:177-200`: **genau** die Stützstellen der Vorlage
    (10/25/35/45/55/65 °C mit `1A3A52, 1F4C66, 7FA3B3, FFD778, F2A900, E0533D`), der
    Kommentar `:168-175` verweist ausdrücklich auf `anlage/schema.ts`, `STOPS`.
  * `Anlagenschema.farbe(_:)` — `…/Zustand/Anlagenschema.swift:43-60`, dieselbe Skala als
    Kernfunktion.
  * `Marken.rampenfarbe(_:anteil:)` — `…/Gestalt/Marken.swift:244-252`: mischt einen Anteil
    0…1 in eine Farbliste. Das ist, was das Kennfeld und die Skala brauchen.
  * `Formate.dauer(minuten:)` — `…/Formate/Formate.swift:122-128`: „45 min", „3 h 20 min",
    „2 h" — dieselbe Form wie `bilanz.ts:31-36` (mit schmalem Leerzeichen).
  * `Formate.zahl(_:stellen:)` `:44`, `Formate.celsius(_:stellen:)` `:104`,
    `Formate.prozent(_:)` `:98`, `Formate.hhmm(_:)` `:140`, `Formate.zeitzone`
    `Europe/Berlin` `:134` — für Tabelle und Tooltip.
  * Oberflächenbausteine: `Karte` (`Gestalt/Karte.swift:15-113`, Kicker/Titel, am Telefon
    randlos mit Radius 16), `Kacheldaten`/`Kachel`/`Kachelfeld`
    (`Karte.swift:121-343`, `art: .bericht` setzt Kicker über die Zahl, erste Kachel führt),
    `Zeile` (`:360-383`), `Leer` (`:390-404`), `Stoerung` (`:410-436`),
    `Tabelle` (`Seiten/Bericht.swift:157ff`, am Telefon Spaltenumschaltung),
    `Methode` (`Seiten/Bericht.swift:334-398`), `Tagewahl`
    (`Seiten/Technik/WaermepumpeSeiten.swift:377-400`), `Seite`
    (`App/Seitenwahl.swift:141-173`), `Anteilsleiste` (`Bausteine/Anteilsleiste.swift:15-46`,
    eine Spur mit gefülltem Teil — das Nächste zum Bilanzbalken, aber einzeilig).
  * Vorbilder für Flächenbilder: `Diagramme/Jahresflaeche.swift:79, 227` (Canvas-Raster) und
    sein Skalenband `:259-284` (LinearGradient + zwei Zahlen);
    `Bausteine/Abweichungsmatrix.swift:21-45` (Raster aus Rechtecken mit Zellenhöhe und Lücke).
  * Vorbild für Punktauswahl: `Diagramme/Prognosezeichnung.swift:262`,
    `Diagramme/Wirkungszeichnung.swift:191` (`.chartXSelection`).
  * Vorbild für Fußverweise: `Seiten/Technik/ReglerSeite.swift:358-372`.

ES FEHLT:

  1. **`Kennlinienbild` — der Rechenzustand der Seite.** Neue Datei
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Kennlinienbild.swift`,
     `public struct Kennlinienbild: Sendable`, `init(_ k: KennlinieOut)`. Darin, als
     Übersetzung von `apps/web/src/components/waermepumpe/kennlinie.ts`:
     - `static func copNach(_ f: KennlinienFitOut, aussen: Double, vorlauf: Double) -> Double`
       (`kennlinie.ts:30`)
     - `static func gesamt(_ punkte: [KennlinienPunktOut]) -> Double?` — nach Minuten und
       Leistung gewichtet, `nil` bei Strom ≤ 0 (`kennlinie.ts:34-38`)
     - `static func mitte(_ werte: [Double]) -> Double?` — Median, bei gerader Anzahl das
       Mittel der beiden mittleren (`kennlinie.ts:40-45`)
     - `static func vorlaufStufen(_ f: KennlinienFitOut) -> [Double]` — runde Fünfer, nur bei
       `art == .ebene`, höchstens drei (`kennlinie.ts:49-55`)
     - `static func copAchse(punkte:annahme:) -> ClosedRange<Double>` (`kennlinie.ts:115-119`)
     - `var kopfsatz: String` — die drei Fassungen aus `Kennlinie.tsx:108-113`
     - `var kacheln: [Kacheldaten]`-Daten als Kernwerte (Wort, Wert, Ton, Hinweis), damit die
       Vorzeichenregel „+/−" mit U+2212 (`Kennlinie.tsx:143,149`) nur einmal steht.
  2. **`Kennlinienvergleich`** im selben Typ: `struct Vergleichszeile { aussenC, annahme,
     messung, gemessen }`, `static func vergleichsVorlauf(_ k: KennlinieOut) -> Double?` und
     `static func vergleich(_ k: KennlinieOut) -> [Vergleichszeile]`
     (`kennlinie.ts:58-86`). Damit auch die Spaltenköpfe mit ihren Gradangaben.
  3. **`Kennfeld`** — neuer Typ in derselben Datei oder
     `Zustand/Kennfeld.swift`: `raster(f) -> (aussen: [Int], vorlauf: [Int])` (ganze Grad /
     Zweiergrade, `kennlinie.ts:225-231`), `zellen` mit dem gerundeten COP je Feld
     (`:252-255`), `belegung(punkte:) -> [(i: Int, j: Int, anzahl: Int)]` (`:234-243`),
     `rampe: [Farbwert]` = die sechs `COP_FARBEN` (`:246`) als neue Konstante in
     `Gestalt/Marken.swift` neben den übrigen Rampen, und `spanne` auf halbe Schritte
     gerundet (`:276-285`). `nil`, wenn `art != .ebene`.
  4. **`Kennlinienbilanz`** — die Teile des Balkens als Kerntyp:
     `struct Bilanzteil { art, name, minuten, anteil, wozu }` mit der festen Folge und den
     fünf Begründungssätzen aus `bilanz.ts:15-22`, dazu
     `fehlend(_:) -> [(name: String, minuten: Int)]` (sortiert, `bilanz.ts:39-44`) und
     `halbeFenster(_:) -> Int` (`bilanz.ts:47-49`). Die Farbzuordnung der fünf Arten
     (`globals.css:916-920`) gehört als `static func farbe(_ art:) -> Farbwert` dazu — vier
     davon sind vorhandene Marken (`amber`, `text3` zu 70 %, `alarm`, `waermepumpe`,
     `linie2`).
  5. **Der Punkttooltip als Satzfolge** im Kern: `punktzeilen(_ p: KennlinienPunktOut) ->
     [(wort: String, wert: String)]` mit den fünf Zeilen und dem Kopfdatum
     (`kennlinie.ts:108-112`), damit Auswahl im Chart und Tabelle dieselben Zahlen und
     Stellen zeigen.

BAUPLAN:

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Kennlinienbild.swift` **neu** —
     Punkte 1, 2, 4, 5 aus „ES FEHLT". Reine Rechnung, ohne SwiftUI, prüfbar.
  2. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift` **ändern** —
     `public static let kopframpe` (die sechs `COP_FARBEN`) neben `waerme` und
     `pufferschichten`, mit der Herkunft `kennlinie.ts:246` im Kommentar.
  3. `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift` **ändern**, Karte für Karte
     in der Reihenfolge der Vorlage:
     a. Kopfsatz: `Text(bild.kopfsatz)` in `Schrift.sans(22)`/am Telefon 19,
        darunter `Letzte \(k.tage) Tage` in `Schrift.klein`/`Farbe.text3`. Vor der Tagewahl.
     b. `Tagewahl(tage: $tage, moeglich: [7, 30, 90, 180])`.
     c. `fehltDe` als Amber-Hinweiskasten statt `Karte`+`Leer` — neuer kleiner Baustein, siehe
        4.
     d. `Kachelfeld(kacheln: bild.kacheln, spalten: 2, art: .bericht)` — vier Kacheln, erste
        führt am Telefon.
     e. Bilanzkarte **oben**, wenn `k.punkte.isEmpty`.
     f. Formelkarte: `Karte(kicker: "Ausgleich nach kleinsten Quadraten")` mit `formelDe` in
        `Schrift.mono(20)` (am Telefon 15) und der Satzzeile mit `±rmse`, `r²` in Prozent und
        `geltungDe`. Ersetzt die heutige Karte „Die gemessene Kurve" (die Zeilen Art/Streuung/
        Bestimmtheit/Messpunkte/Geltung entfallen, ihre Inhalte stehen jetzt in Kacheln und
        Satzzeile; „gilt für draußen"/„und für Vorlauf" bleiben als zwei `Zeile`n, weil die
        Vorlage sie in `geltungDe` nur als Satz hat).
     g. `Diagramme/Kennlinienbild.swift` **neu**: die Karte „Arbeitszahl über der
        Außentemperatur" — Punkte in `Marken.wasserfarbe(p.vorlaufC)`, `symbolSize(9)` mit
        Rand in `Farbe.flaeche1`, bis zu drei Ausgleichsgeraden je Vorlaufstufe in ihrer
        Wasserfarbe mit Namen am Kurvenende, Annahmelinie gestrichelt mit kleinen Kreisen,
        `chartYScale(domain: bild.copAchse)`, Achsennamen „Außentemperatur °C" und „COP",
        Höhe 320 (Telefon 280), darunter das Verlaufsband `min`…`max` Vorlauf.
     h. Im selben Baustein die Karte „Arbeitszahl über der Vorlauftemperatur": Punkte
        einfarbig `Farbe.waermepumpe`, eine Gerade „Ausgleich bei N °C draußen".
        Am iPad beide nebeneinander (`HStack`, zwei Hälften), am Telefon untereinander.
     i. `Diagramme/Kennfeldbild.swift` **neu**: Canvas-Raster nach dem Vorbild
        `Diagramme/Jahresflaeche.swift:227`, Zellen in `Marken.rampenfarbe(Marken.kopframpe,
        anteil:)`, darüber die Belegungskreise `5 + 7·sqrt(anzahl/meiste)` mit weißem Rand,
        rechts das Skalenband nach `Jahresflaeche.swift:259-284` mit `COP max` / `min`,
        Achsen als Zahlenreihen; Höhe 380 (Telefon 320). Erklärsatz und Leerzustandssatz
        wörtlich.
     j. Karte „Messung gegen die Annahme des Fahrplans": `Tabelle` mit `zeilennamen` =
        `{aussen} °C` und drei Spalten (Annahme, Messung, Stand), `farben` der Zeile
        `Farbe.text3`, wo `gemessen == false` — `Tabelle.Spalte.farben` ist dafür vorhanden
        (`Seiten/Bericht.swift:166-172`). Schlusssatz wörtlich. Ersetzt die heutige Karte
        „Angenommene Kurve".
     k. Bilanzkarte **unten**, wenn Punkte da sind — neuer Baustein, siehe 4.
     l. Aufklappbare Messpunkttabelle: `DisclosureGroup` in einer `Karte`, Griff
        `Die Messpunkte als Tabelle (N)`, `Tabelle` mit `zeilennamen` = Zeitstempel und sechs
        Spalten, neueste zuerst, 200 gekappt.
     m. `Methode(k.hinweiseDe)` bleibt, bekommt aber `kurz:` mit dem ersten Hinweis, damit am
        Telefon nicht alles verschwindet; darunter die zwei Fußverweise nach dem Vorbild
        `ReglerSeite.swift:358-372`.
     n. Ladezustand: einzelner Satz `Die Kennlinie wird geladen …` statt Karte mit
        „Wird geholt …".
  4. `apps/ios/DuckCurveHome/Bausteine/Bilanzbalken.swift` **neu** — der Balken (Höhe 22,
     2 Punkte Lücke, Radius 4, Anteil aus `Bilanzteil.anteil`) mit Legendenliste
     (Punkt 10×10/Radius 3, Name, Dauer in `Schrift.zahlKlein`, Prozent rechtsbündig,
     Begründung in `Schrift.winzig`; am Telefon die Begründung in eigener Zeile). Dazu
     `Hinweiskasten.swift` für `wp-stumm` (Amber-Rand `55 %`, Fläche `9 %`, Radius 12), falls
     kein Gegenstück existiert — gesucht nach `wp-stumm`-Pendant in
     `apps/ios/DuckCurveHome/Gestalt` und `Bausteine`: kein Treffer.

WAS SCHWIERIG WIRD:

  * **Das Kennfeld.** Swift Charts hat keine `heatmap` mit `visualMap`. Im Projekt ist der Weg
    schon gewählt und zweimal gegangen: ein `Canvas` für das Raster plus ein eigenes
    Skalenband — `Diagramme/Jahresflaeche.swift:79` (Canvas) und `:259-284` (Band aus
    `LinearGradient` und zwei Zahlen), Begründung „Canvas, weil ein Raster aus Rechtecken
    vierfach schwerer ist" (`Jahresflaeche.swift:9`). Die zweite Fassung ohne Canvas, mit
    Rechtecken und Lücken, steht in `Bausteine/Abweichungsmatrix.swift:21-45`; weil das
    Kennfeld kaum mehr als 20×15 Zellen hat, ist sie hier die einfachere Wahl, und ihre
    Lückenbegründung (`Abweichungsmatrix.swift:36-45`: ohne Lücke wird aus Zellen ein
    Streifen) gilt genauso.
  * **Der Punkttooltip.** `.chartXSelection` wählt eine x-Stelle, nicht eine Marke — in einem
    Streubild liegen bei einer Außentemperatur viele Punkte. Das Projekt hat kein Vorbild für
    die Auswahl **einer Marke**; gesucht nach `chartOverlay` in `apps/ios/DuckCurveHome`:
    kein Treffer. Zwei gangbare Wege: `.chartXSelection` und dann alle Punkte dieser Spalte in
    einer Liste zeigen (wie `Prognosezeichnung.swift:262` es für Kurven tut), oder die
    aufklappbare Messpunkttabelle als Ersatz nehmen — die Vorlage hat beides, und die Tabelle
    trägt dieselben sechs Zahlen.
  * **Die Namen am Kurvenende** (`endLabel`, `kennlinie.ts:139`) haben in Swift Charts kein
    Gegenstück. Vorbild im Projekt: `.annotation` am letzten Punkt einer Reihe — gesucht nach
    `endLabel`/`annotation` in `apps/ios/DuckCurveHome/Diagramme`: `annotation` kommt in
    `Diagramme/Tageskurve.swift` vor (Beschriftung an Marken); sonst bleibt eine eigene
    Legendenzeile mit den bis zu drei Vorlaufstufen in ihrer Farbe, was die Zuordnung
    erhält, ohne den rechten Rand von 104 px zu brauchen.
  * **`clamp(15px, 1.7vw, 20px)`** der Formelzeile (`globals.css:897`) hat kein Gegenstück.
    Das Projekt löst solche Fälle über `horizontalSizeClass` statt über die Breite in Punkten
    (`Gestalt/Karte.swift:22-24` mit Begründung `:13-14`): am Telefon 15, am iPad 20.
  * **Zwei Karten nebeneinander** (`.kl-paar`): im Projekt gibt es dafür `Spaltenreihe`
    (`apps/ios/DuckCurveHome/Bausteine/Spaltenreihe.swift`) — vor dem Bau nachsehen, ob sie
    zwei beliebige Karten nimmt; sonst ein `HStack` mit `horizontalSizeClass`-Weiche wie in
    `Gestalt/Karte.swift`.
