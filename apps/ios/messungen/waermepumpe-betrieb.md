========================= messen:waermepumpe-betrieb   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift:186-374`, `struct BetriebSeite`)

1. `Tagewahl(tage: $tage, moeglich: [7, 30, 90])` - drei Kapselknöpfe, Vorwahl 7
   (`WaermepumpeSeiten.swift:189`, `:195`; die Ansicht selbst `:377-400`: `Schrift.winzig`,
   Polster 10/5, gewählt `Farbe.amberWeich` auf `Farbe.deep`, sonst `Farbe.flaeche2` auf
   `Farbe.text2`).
2. Bei Fehler `Stoerung(fehler:)` mit Knopf „Erneut" (`:196-198`; Baustein
   `Gestalt/Karte.swift:410-436`).
3. `Kachelfeld` mit **sechs** Kacheln, Kicker „N Tage" (`:200`, Kacheln `:274-297`):
   Starts (dazu `starteJeTag`), Laufzeit, Lauf im Mittel (dazu „Median"), Arbeitszahl,
   Abtauen (dazu „N Mal"), Zusatzheizung (`Farbe.achtung`, wenn > 0).
4. Karte „Was auffällt" mit **allen** Sätzen aus `saetzeDe`, `Schrift.klein`, `Farbe.text1`
   (`:202-212`).
5. Karte „Wie lange die Läufe dauerten": `Balkenbild`, eine Reihe „Läufe" in
   `Farbe.waermepumpe`, ungestapelt, Höhe 150 (`:213-225`; Baustein `Seiten/Bericht.swift:70-149`).
   Klassenname `"\(vonMin)–\(bisMin)"` bzw. `"\(vonMin)+"` (`:269-272`).
6. Karte „Nach Tagen": `Tabelle` mit fünf Spalten - Starts, Laufzeit, Abtauen, Strom,
   Arbeitszahl -, Zeilennamen `Tag.kurz` („Sa, 14.11."), Reihenfolge wie geliefert
   (`:226-251`; Baustein `Bericht.swift:157-328`).
7. Karte „Gemessene Heizkurve", Titel `hk.formelDe`: **nur** die gerechnete Gerade als
   `LineMark` über 24 Stützstellen, Höhe 160, darunter „Außentemperatur in °C",
   „aus N Messungen", „R² x,xx" (`:304-354`, Stützstellen `:356-362`).
8. `Methode(b.hinweiseDe)` - zugeklappte Karte „Wie das gerechnet ist"
   (`:255`; Baustein `Bericht.swift:135-198`).
9. Beim Laden `Karte { Leer(satz: "Wird geholt …") }` (`:257`).

Abfrage: `haus.api.betrieb(tage: tage)` (`:366`), Kern
`DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:304` → `GET /waermepumpe/betrieb?tage=`.
Kein Dauerauffrischen (`.task(id: tage)`, `:260`) - richtig, die Vorlage hat auch keines.


VORLAGE:
Einstieg `apps/web/src/app/waerme/waermepumpe/betrieb/page.tsx:1-13`: `AreaShell` mit
`kicker="Läufe · Abtauen · Heizkurve"` (`:9`), Titel „Betrieb der Wärmepumpe · Duck Curve Home"
(`:5`), Inhalt `<Betrieb />` (`:10`). Die Hülle ist
`components/layout/AreaShell.tsx:14-31` (Marke, Bereichstitel, Reiter, Ansichten, Fußleiste);
der Kicker landet als `right` in `AreaTabs` (`AreaShell.tsx:26`).
Alles Weitere steht in `components/waermepumpe/Betrieb.tsx:22-190`.
Hülle der Seite: `.wp-seite` = Spalte, Abstand 16 (`styles/globals.css:787`).

  * **Kopf: ein Satz und die Standzeile**  (`Betrieb.tsx:52`, `:56-63`)
    `const [kopf, ...weitere] = daten.saetze_de;` - der **erste** Satz steht allein und groß
    als `.wp-satz`: 22 px, `line-height 1.3`, `--text-1` (`globals.css:789`), am Handy 19 px
    (`handy.css:234`). Fehlt er: wörtlich „Noch nichts auszuzählen." (`Betrieb.tsx:59`).
    Darunter `.wp-stand`: 13 px, `--text-3` (`globals.css:790`) mit dem Text
    „Letzte {zeitraum_tage} Tage" und, wenn gleichzeitig ein Fehler steht, ` · {fehler}`
    angehängt (`Betrieb.tsx:60-62`).
    DATEN: `saetze_de[0]`, `zeitraum_tage`.

  * **Zeitraumwahl**  (`Betrieb.tsx:20`, `:65-71`)
    `const TAGE = [7, 14, 30, 90]`, Vorwahl **14** (`:23`). `div.kl-wahl` mit
    `role="group" aria-label="Rückblick"`, je Wert ein `button.kl-knopf` mit
    `aria-pressed`, Text „{t} Tage".
    Maße: Polster 7/13, Radius 999, Rahmen `--line-1`, 13 px, `--text-2`; gewählt
    `background: var(--amber)`, `border-color: var(--amber)`, `color: var(--petrol)`,
    `font-weight 600`; Fokus 2 px Bernstein, Abstand 2 (`globals.css:892-895`).
    Handy: unverändert (gesucht nach `.kl-wahl`/`.kl-knopf` in `handy.css`: kein Treffer).

  * **Vier Kennzahlkacheln**  (`Betrieb.tsx:73-78`)
    `div.kpi-grid.kpi-handy` mit `--cols: 4`; Raster = Mindestbreite
    `clamp(150px, 100%/4 - 16px, 260px)`, Abstand 16 (`globals.css:107`).
    Jede Kachel ist `Stat` (`components/ui/Stat.tsx:4-18`): `Card` mit Polster 14/18,
    Abstand 6; Kicker 11 px (Grundform `globals.css:57-64`: Mono, 13 px,
    `letter-spacing .13em`, Großbuchstaben, `--text-kicker` = `--mist`); Zahl Mono 26 px,
    `leading-none`, `tracking -.02em`; Einheit 13 px Sans `--text-3`; Hinweiszeile 12 px,
    `line-height 1.35`, `--text-3`, höchstens zwei Zeilen (`Stat.tsx:13-16` begründet das
    ausdrücklich: „Abgeschnitten … ist sie nutzlos", zwei Zeilen, damit die Kacheln einer
    Reihe gleich hoch bleiben).
    Die vier, wörtlich:
    1. „Starts je Tag" - `zahl(startsJeTag(daten))`, Ton `amber`, Hinweis
       „an Tagen mit Betrieb"; ohne Wert „?" und Ton `muted`.
    2. „Ein Lauf dauert" - `dauer(daten.lauf_median_min)`, Hinweis
       „{Math.round(kurz*100)} % unter zehn Minuten", sonst „im Mittel".
    3. „Abtauen" - `zahl(abtauAnteil*100)`, Einheit „%", Hinweis
       „der Laufzeit · {abtauungen}-mal" (ohne Lauf nur „der Laufzeit").
    4. „Arbeitszahl über alles" - `zahl(cop_gesamt, 2)`, Hinweis
       „im Heizbetrieb {zahl(cop_heizen,2)}", sonst „Wärme durch Strom".
    DATEN: `starts`, `tage[].lauf_min`, `lauf_median_min`, `klassen[].laeufe`,
    `klassen[].von_min`, `abtau_min`, `lauf_min`, `abtauungen`, `cop_gesamt`, `cop_heizen`.
    Rechnungen: `betrieb.ts:55-58` (`startsJeTag` = `starts / Anzahl Tage mit lauf_min > 0`),
    `:61-63` (`abtauAnteil`), `:66-70` (`kurzAnteil` = Läufe der Klasse `von_min === 0`
    durch alle Läufe). Format `zahl` = `toFixed(1).replace(".", ",")` (`betrieb.ts:21-22`),
    `dauer` aus `bilanz.ts:31-36`.
    **Handy-Fassung, und das ist nicht dieselbe Reihe in einer Spalte**
    (`handy.css:196-207`): aus vier Karten wird **eine** Fläche `--surface-2`, Radius 16,
    Polster 4/16, zwei Spalten, Abstand `0 20px`; die Kacheln verlieren Hintergrund und
    Radius und werden durch `border-top: 1px solid var(--line-1)` getrennt;
    **die erste Kachel führt** über `grid-column: 1 / -1`, ohne Linie, Polster 14/0/16,
    Zahl **48 px** mit `letter-spacing -.04em`, Einheit 18 px mit `margin-left 8px`,
    Hinweiszeile 14,5 px in `--text-2`; die übrigen Zahlen 25 px - und weil diese Seite
    zusätzlich `kpi-handy` trägt, greift `handy.css:382` und macht sie **21 px**;
    eine allein übrig bleibende letzte Kachel nimmt die ganze Zeile (`handy.css:200`).
    Kicker bleibt am Handy gesperrt, 11 px, `letter-spacing .1em` (`handy.css:201`).

  * **Karte „Was die Auszählung zeigt"**  (`Betrieb.tsx:80-89`)
    Nur wenn **nach** dem Kopfsatz noch Sätze übrig sind (`weitere.length`).
    `div.card.kl-karte` (Karte: `--surface-2`, 1 px `--line-1`, Radius `--radius-2` = 3 px,
    Polster 20 → `kl-karte` setzt 16, Spalte, Abstand 10; `globals.css:67-76`, `:900`),
    `h2.kl-titel` 15 px, 600, `--text-1` (`globals.css:901`), darin `ul.bt-saetze`:
    Aufzählung mit `padding-left 18`, Abstand 6, **15 px**, `line-height 1.5`, `--text-1`,
    `max-width 860px` (`globals.css:1024`).
    DATEN: `saetze_de[1..]`.

  * **Weiche: nur wenn sie lief**  (`Betrieb.tsx:48`, `:91`)
    `const lief = daten.lauf_min > 0;` - bei 0 fallen **alle vier Diagramme** weg, Kopf,
    Kacheln, Tabelle und Fuß bleiben.

  * **Diagramm 1: „Laufstunden je Tag"**  (`Betrieb.tsx:94-97`, Option `betrieb.ts:93-115`)
    `div.card.kl-karte` + `h2.kl-titel` + `div.kl-chart` (Breite 100 %, **Höhe 320 px**;
    `globals.css:902`, am Handy **280 px**: `handy.css:244`). Gezeichnet mit `EChart`
    (`components/charts/EChart.tsx:31-84`).
    Gestapelte Balken je Tag, drei Reihen in dieser Reihenfolge und mit diesen Farben:
    „Heizen" `C.heatPump` **#e0966b**, „Abtauen" `C.battery` **#7fa3b3**,
    „Heizstab" `C.grid` **#e0533d** (`palette.ts:53`, `:36`, `:37`).
    `barMaxWidth: 26`, `borderRadius: 2`, und ein 1 px Rand in der Kartenfarbe
    `FLAECHE = "#123544"` als Spalt zwischen den Teilen - der Kommentar sagt warum:
    „Ein Spalt in der Farbe der Fläche trennt die Teile eines Balkens" (`betrieb.ts:100-101`).
    Achsen: x Kategorie `tagName(tag)` = „14.11." (`betrieb.ts:42-45`, einstellige Tage
    **ohne** führende Null), y Wert mit Namen „Stunden". Achsenstil `betrieb.ts:32-38`:
    Linie `C.axis` = `rgba(255,255,255,.2)`, keine Striche, Beschriftung `C.text` =
    `rgba(255,255,255,.48)` in Mono **10 px**, Rasterlinie `C.gridline` =
    `rgba(255,255,255,.09)`. Legende unten links, Marke 16×8, 10 px (`:39`).
    Gitter `left 40, right 14, top 14, bottom 48` (`:110`). `animation: false`.
    Hinweis am Finger: `trigger: "axis"`, `axisPointer: "shadow"`, Inhalt `tagZeilen`
    (`betrieb.ts:81-91`) - Kopf = Tag, dann Lauf, Starts, Abtauen („x · N-mal", nur wenn
    es welches gab), Heizstab (nur wenn), Strom in kWh, draußen in °C.
    Rechnung `stundenTeile` (`betrieb.ts:49-52`): `heizen = max(0, lauf_min − abtau_min −
    zusatz_min)`, alles durch 60, auf zwei Stellen gerundet (`:102`).
    DATEN: `tage[].lauf_min`, `.abtau_min`, `.zusatz_min`, `.starts`, `.abtauungen`,
    `.strom_kwh`, `.aussen_c`, `.tag`.

  * **Diagramm 2: „Arbeitszahl je Tag"**  (`Betrieb.tsx:98-102`, Option `betrieb.ts:124-155`)
    Zwei Linien: „im Heizbetrieb" `C.heatPump` #e0966b und „über alles" `C.house`
    **#cfd8dc** (`palette.ts:43`). `symbol: circle`, `symbolSize 8`, Linie 2 px, Punktrand
    1,5 px in der Kartenfarbe, **`connectNulls: false`** - ein Tag ohne Lauf bleibt eine
    Lücke und wird nicht überbrückt.
    y-Achse hat einen **gerechneten Bereich**: `copAchse` (`betrieb.ts:118-122`) - ganze
    Zahlen um die Werte, mindestens 2 bis 5. Name „COP". Gitter `left 34`.
    Hinweis am Finger: Kopf = Tag, „im Heizbetrieb", „über alles", „Wärme x kWh".
    Darunter ein Erklärsatz in `p.kl-klein` (13 px, `line-height 1.5`, `--text-3`,
    `max-width 760px`; `globals.css:898`), wörtlich:
    „„Über alles" enthält jeden Anlauf, das Abtauen und den Heizstab; „im Heizbetrieb"
    zählt nur eingeschwungene Fenster. Liegt die erste Linie darunter, ist der Abstand, was
    Takten und Abtauen an dem Tag gekostet haben." (`Betrieb.tsx:101`)
    DATEN: `tage[].cop_tag`, `.cop_heizen`, `.waerme_kwh`.
    Die beiden Karten 1 und 2 stehen in `div.kl-paar` - zwei gleich breite Spalten,
    Abstand 16 (`globals.css:899`); **am Handy eine Spalte** (`handy.css:235`).

  * **Diagramm 3: „Wie lange ein Lauf dauert"**  (`Betrieb.tsx:106-116`,
    Option `betrieb.ts:157-177`)
    Balken je Klasse, `C.heatPump`, `barMaxWidth 46`, Radius `[4,4,0,0]`, und **die Zahl
    steht über dem Balken** (`label: { show: true, position: "top", 11 px }`, `:172`).
    y-Achse Name „Läufe", `minInterval: 1`. Gitter `left 34, top 22, bottom 26`.
    Klassenname `klassenName` (`betrieb.ts:72-76`): bei `von_min === 0`
    „unter {bis_min} min", bei offenem Ende „ab {von_min} min", sonst
    „{von_min} bis {bis_min}" - also „unter 10 min", „10 bis 20", „ab 90 min"
    (`betrieb.test.ts:68`).
    Hinweis am Finger: `trigger: "item"`, Kopf = Klassenname, Zeile „Läufe N".
    Darunter `p.kl-klein`, wörtlich: „{N} vollständige Läufe. Die ersten zehn Minuten eines
    Laufs sind Anlauf; ein Lauf, der kürzer ist, kommt nie in den Bereich, in dem die
    Maschine gut arbeitet." - bei genau einem Lauf „1 vollständiger Lauf" (`Betrieb.tsx:111`).
    Leerzustand (`laeufe === 0`, also kein Diagramm): „Noch kein vollständiger Lauf: ein
    Lauf zählt, wenn sein Anfang und sein Ende in den Daten liegen." (`Betrieb.tsx:114`)
    DATEN: `klassen[].von_min`, `.bis_min`, `.laeufe`.

  * **Diagramm 4: „Die Heizkurve des Reglers"**  (`Betrieb.tsx:117-130`,
    Option `betrieb.ts:184-237`)
    Gezeigt nur, wenn `daten.stunden.length` (`:119`); sonst wörtlich
    „Noch keine Stunde im Heizbetrieb mit Sollwert und Außentemperatur." (`:128`).
    Drei Reihen, in dieser Stapelordnung (`z`):
    - „Gerade" (`z: 3`), nur wenn `heizkurve` da ist: `LineMark` von `aussen_von_c` nach
      `aussen_bis_c` mit `a + b·t`, `rgba(255,255,255,.85)`, 2 px, **ohne eigenen Hinweis**
      (`tooltip: { show: false }`).
    - „erreicht" (`z: 2`), nur wenn es Stunden mit `vorlauf_c` gibt: Streupunkte,
      **Symbol `diamond`**, Größe 8, `C.battery` #7fa3b3, Rand 1 px Kartenfarbe.
    - „Sollwert" (`z: 4`, also obenauf): Streupunkte aller Stunden, Größe 9,
      `C.heatPump` #e0966b, Rand 1,5 px Kartenfarbe.
    Legende nennt nur die Reihen, die es gibt, in der Folge
    `["Sollwert", "erreicht"?, "Gerade"?]` (`betrieb.ts:187`).
    Achsen beide `type: "value"` mit `scale: true` (also **nicht** bei Null beginnend),
    x-Name „Außentemperatur °C", `nameLocation: "middle"`, `nameGap: 26`; y-Name
    „Vorlauf °C". Gitter `left 40, right 18, top 14, bottom 62`.
    Hinweis am Finger je Punkt `stundeZeilen` (`betrieb.ts:179-182`): Kopf = Zeitpunkt
    „TT.MM., HH:MM" in `Europe/Berlin`, dann draußen, Sollwert, erreicht (wenn da),
    „im Heizbetrieb {minuten} min".
    Darunter `p.kl-klein` mit `span.mono` für `formel_de`, dann wörtlich
    „ · aus {n} Stunden, erklärt {Math.round(r2*100)} % der Streuung. Jeder Punkt ist eine
    Stunde im Heizbetrieb. Liegen Punkte weit über der Geraden, hat der Regler dort für
    Warmwasser mehr verlangt." - und ohne Gerade stattdessen „Für eine Gerade braucht es
    mindestens sechs Stunden Heizbetrieb bei Außentemperaturen, die drei Grad
    auseinanderliegen." (`Betrieb.tsx:122-125`).
    DATEN: `stunden[].at`, `.aussen_c`, `.soll_c`, `.vorlauf_c`, `.minuten`;
    `heizkurve.a/.b/.n/.r2/.aussen_von_c/.aussen_bis_c/.formel_de`.
    Karten 3 und 4 stehen wieder in `div.kl-paar`.

  * **„Die Tage als Tabelle (N)"**  (`Betrieb.tsx:135-175`)
    Ein **zugeklapptes** `details.kl-liste` (14 px, `--text-2`, Griff `cursor: pointer`,
    Polster 6/0; `globals.css:1025-1027`); die Zusammenfassung nennt die Zahl der Tage.
    Darin `div.kl-rollt` (`overflow-x: auto`) mit `table.kl-tabelle`, die **mindestens
    940 px breit** ist (`globals.css:912-913`) - sie wird am Handy also nicht zur Liste,
    sondern gerollt (`handy.css:246-247`: `.kl-liste, .kl-karte { overflow-x: auto }`,
    Schrift 13 px). Gesucht nach `.kl-tabelle` unter den Listen-Umbauten in
    `handy.css:305-347`: kein Treffer - anders als `kosten-tabelle`, `nb-tabelle`,
    `fenster-tabelle` bleibt diese eine Tabelle.
    Elf Spalten, in dieser Folge: Tag, draußen, Starts, Lauf, Lauf im Mittel, Abtauen,
    Heizstab, Strom, Wärme, Arbeitszahl, im Heizbetrieb.
    Zellen (alle `.mono`): `tagName(t.tag)`; `{zahl} °C` bzw. „?"; `starts`;
    `dauer(lauf_min)`; `dauer(lauf_median_min)` bzw. „?";
    `abtau_min ? "{dauer} · {abtauungen}-mal" : "0"`; `zusatz_min ? dauer : "0"`;
    „{zahl} kWh"; „{zahl} kWh" bzw. „?"; `zahl(cop_tag, 2)` bzw. „?";
    `zahl(cop_heizen, 2)` bzw. „?".
    **Reihenfolge umgekehrt**: `[...daten.tage].reverse()` - der neueste Tag oben
    (`Betrieb.tsx:156`).
    Kopfzellen: linksbündig, Gewicht 500, 12 px, `--text-3`, Linie unten `--line-1`
    (`globals.css:908`); Zellen Polster 7/10/7/0, Linie unten, `--text-1` (`:909`).

  * **Fußzeile**  (`Betrieb.tsx:177-187`)
    `div.wp-fuss`: Spalte, Abstand 6, `max-width 760px`, **13 px**, `line-height 1.55`,
    `--text-3` (`globals.css:795`). Darin **offen** ein Absatz je Satz aus `hinweise_de` -
    keine Klappkarte. Darunter `p.wp-links` (`globals.css:796-798`: Reihe mit Umbruch,
    Abstand `6px 18px`, Rand oben 6, Farbe `--amber`, keine Unterstreichung):
    „Die Wärmepumpe jetzt ›" → `/waerme/waermepumpe` und
    „Gemessene Kennlinie ›" → `/waerme/waermepumpe/kennlinie`.

  * **Zustände**  (`Betrieb.tsx:27-47`)
    Vor der ersten Antwort **ersetzt** ein einzelner Absatz die ganze Seite:
    `<p className="m-0 text-[15px] text-text-3">` mit „Der Betrieb wird ausgezählt …",
    oder, wenn geladen und fehlgeschlagen, „Die Auszählung ist gerade nicht zu erreichen."
    (`:32`, `:46`). Liegen schon Daten vor, bleibt die Seite stehen und der Fehler hängt
    sich hinten an die Standzeile (`:61`). Keinen „Erneut"-Knopf; neu geladen wird bei
    jedem Wechsel von `tage` (`:36-38`).
    Abfrage: `api.betrieb(t)` → `GET /waermepumpe/betrieb?tage={t}`
    (`lib/api/client.ts:95-98`), leere Listen werden auf `[]` normalisiert.

  * **Handy, zusammengefasst** (was diese Route betrifft, aus `handy.css`)
    `:109-111` Grund wird flach (`--deep`, kein Raster), Seitenrand 10/16 und unten
    `86px + safe-area` für die Bereichsleiste; `:112` Seitenabstand 14, Grundschrift 15 px.
    `:114-135` Bereiche als feste Leiste **unten**; `:137-142` Kopf ohne Rahmen und ohne
    Marke, `.bereichstitel` 26 px 600; `:164-176` Reiter als rollende Pillenreihe über den
    Rand hinaus; `:178-180` Ansichten als Schalter über die ganze Breite.
    `:182` Karten: **kein Rand**, Radius 16, Polster 16. `:184-186` Kartenkopf: der Kicker
    wird lesbare Sans 16,5 px 600 ohne Sperrschrift und ohne Großbuchstaben, `--text-1`.
    `:189-192` kleine Schriften eine Stufe größer (10→11, 11→12, 12→13,5, 13→14,5) - das
    trifft die Hinweiszeilen der Kacheln und die Fußzeile.
    `:213-220` Methode (hier nicht benutzt, aber die Vorlage der App-Karte).
    `:235` `.kl-paar` eine Spalte. `:244` `.kl-chart` 280 px.
    `:246-247` `.kl-liste`/`.kl-karte` rollen seitlich, `.kl-tabelle` 13 px.
    `:382` `.kpi-handy > .card > .mono` 21 px.
    Die Begründung steht im Kopf der Datei (`handy.css:1-26`): die Handy-Ansicht war die
    Rechner-Ansicht in einer Spalte, „bis zu viereinhalb Bildschirme gleich schwerer Kästen",
    Nutzerurteil 10.11.2026 „viel zu schlecht, muss neu gedacht werden" - daraus die vier
    Entscheidungen: Bereiche unten, **eine Zahl führt**, Flächen statt Rahmen, Tabellen
    werden Listen.

  * **Begründungen in Kommentaren der Vorlage, die beim Umbau nicht verloren gehen dürfen**
    - `betrieb.ts:6-19`: „Vier Fragen, vier Diagramme, jedes mit einer Achse" - und was jede
      Frage ist. Der Abstand der beiden COP-Linien **ist** die Aussage: „Der Abstand ist, was
      Takten und Abtauen kosten."
    - `WaermepumpeSeiten.swift:183-185` (App, gleiche Sache): „Das Takten ist der Gegenstand.
      … Die Klassenverteilung unten sagt, welche von beiden hier steht."
    - `betrieb.ts:100-101`: der 1-px-Rand in der Flächenfarbe ist der Spalt zwischen den
      Teilen eines gestapelten Balkens.
    - `Stat.tsx:13-15`: die Hinweiszeile darf umbrechen, höchstens zwei Zeilen, damit die
      Kacheln einer Reihe gleich hoch bleiben - „Abgeschnitten … ist sie nutzlos".
    - `palette.ts:46-53`: die Wärmepumpe hat **eine** Farbe, überall (#e0966b); daneben ist
      das Sand des Haushalts bei Deuteranopie dieselbe Farbe, deshalb ist „der Rest des
      Hauses" hell (`house` #cfd8dc) - genau das Paar, das hier als „im Heizbetrieb" gegen
      „über alles" im selben Gitter steht.
    - `bilanz.ts:5-9`: am 14.11.2026 lief die Wärmepumpe Stunden und die Seite zeigte keinen
      Punkt, ohne zu sagen warum; seitdem wird mitgezählt, woran eine Minute scheiterte. Hier
      ist das Erbe der Satz bei leerer Klassenliste und bei leeren `stunden`.
    - `EChart.tsx:73-74` + `charts/handy.ts:3-18`: am Handy bekommt **jedes** Diagramm
      dieselbe Nachstellung - Achsenschrift mindestens 11 px, Wertachsen höchstens drei
      Schritte, Legende rollt in einer Zeile statt umzubrechen, Hinweis bleibt im Bild.


LUECKEN:

  [traegt-die-seite] Das Diagramm „Laufstunden je Tag" fehlt ganz - gestapelte Balken je Tag
  aus Heizen, Abtauen und Heizstab (`Betrieb.tsx:94-97`, `betrieb.ts:93-115`). Die App zeigt
  keine Zeitreihe über die Tage; der Verlauf, der die Frage „läuft sie anders als letzte
  Woche?" beantwortet, kommt nirgends vor.

  [traegt-die-seite] Das Diagramm „Arbeitszahl je Tag" mit den zwei Linien fehlt ganz
  (`Betrieb.tsx:98-102`, `betrieb.ts:124-155`). Damit fehlt der Abstand zwischen „im
  Heizbetrieb" und „über alles" - nach `betrieb.ts:12-14` die Kernaussage der Karte.

  [traegt-die-seite] In der Heizkurve fehlt die Punktwolke. Die App zeichnet nur die
  gerechnete Gerade (`WaermepumpeSeiten.swift:307-316`); die Vorlage legt darunter die
  Sollwerte **jeder** Stunde und, als Raute, den erreichten Vorlauf
  (`betrieb.ts:212-234`). Ohne Punkte ist die Karte eine Formel - und der Satz der Vorlage
  „Liegen Punkte weit über der Geraden, hat der Regler dort für Warmwasser mehr verlangt"
  (`Betrieb.tsx:124`) hat keinen Gegenstand mehr. `b.stunden` wird in der App nicht ein
  einziges Mal gelesen (gesucht nach `stunden` in `WaermepumpeSeiten.swift`: kein Treffer).

  [traegt-die-seite] Der führende Satz fehlt. Die Vorlage nimmt `saetze_de[0]` heraus und
  stellt ihn allein in 22 px über die Seite (`Betrieb.tsx:52`, `:59`,
  `globals.css:789`); die App schüttet alle Sätze gleichwertig in eine Karte „Was auffällt"
  (`WaermepumpeSeiten.swift:202-212`). Das Urteil der Seite steht damit nicht oben, sondern
  als dritter Kasten in gleicher Schriftgröße wie der Rest.

  [traegt-die-seite] Die Kennzahlzeile ist eine andere. Die Vorlage hat vier Kacheln, die
  App sechs, und nur zwei Größen überschneiden sich. Es fehlen „Starts je Tag" als
  **führende** Kachel mit Ton `amber`, „Abtauen" als **Anteil in Prozent** der Laufzeit, der
  Hinweis „{x} % unter zehn Minuten" an der Median-Kachel und `cop_heizen` als Hinweis an
  der Arbeitszahl (`Betrieb.tsx:74-77`). Dazu rechnet die App „Starts je Tag" falsch: sie
  teilt durch `zeitraumTage` (`WaermepumpeSeiten.swift:264-267`), die Vorlage durch die Zahl
  der Tage **mit** Betrieb, und der Test hält das ausdrücklich fest: „rechnet Starts je Tag
  über die Tage mit Betrieb, nicht über alle" (`betrieb.test.ts:58-60`).

  [spuerbar] Die Tagestabelle hat fünf statt elf Spalten und die falsche Richtung. Es fehlen
  draußen, Lauf im Mittel, Heizstab, Wärme und „im Heizbetrieb"; die Zeilen stehen
  chronologisch statt neuester zuerst (`Betrieb.tsx:144-168` gegen
  `WaermepumpeSeiten.swift:228-249`). Auch die Hülle ist anders: die Vorlage klappt die
  Tabelle zu und nennt im Griff die Zahl der Tage, die App zeigt sie offen in einer Karte
  „Nach Tagen".

  [spuerbar] Die Erklärsätze unter drei der vier Diagramme fehlen vollständig
  (`Betrieb.tsx:101`, `:111`, `:122-125`). Das sind in der Vorlage 13-px-Absätze in
  `.kl-klein`, und sie sagen, was man im Bild sieht; ohne sie ist die Klassenverteilung eine
  Balkenreihe ohne Maßstab.

  [spuerbar] Die Klassennamen sind andere Wörter: „unter 10 min", „10 bis 20", „ab 90 min"
  (`betrieb.ts:72-76`, `betrieb.test.ts:68`) gegen „0–10" und „90+"
  (`WaermepumpeSeiten.swift:269-272`). Auch die Zahl über dem Balken fehlt
  (`betrieb.ts:172`), und der Leerfall-Satz „Noch kein vollständiger Lauf: …"
  (`Betrieb.tsx:114`) ebenfalls - die App lässt die Karte dann einfach weg
  (`WaermepumpeSeiten.swift:213`).

  [spuerbar] Die Standzeile „Letzte N Tage" fehlt (`Betrieb.tsx:60-62`). Die App trägt die
  Zahl als Kicker am Kachelfeld (`WaermepumpeSeiten.swift:200`) - das ist nicht derselbe
  Ort und sagt nicht, dass es ein Rückblick ist. Auch das Verhalten bei Fehler trotz
  vorhandener Daten (Fehler hängt sich an diese Zeile) hat die App nicht.

  [spuerbar] Die Zeitraumwahl bietet 7, 30, 90 statt 7, **14**, 30, 90 und beginnt bei 7
  statt bei 14 (`Betrieb.tsx:20`, `:23` gegen `WaermepumpeSeiten.swift:189`, `:195`).
  Die Knopfform weicht ab: Vorlage 13 px, Polster 7/13, Rahmen `--line-1`, gewählt
  `--amber` auf `--petrol` mit Gewicht 600 (`globals.css:892-895`); App `Schrift.winzig`
  (11,5), Polster 10/5, kein Rahmen, gewählt `amberWeich` auf `deep`
  (`WaermepumpeSeiten.swift:386-393`).

  [spuerbar] Die Fußzeile fehlt. Die Vorlage schreibt `hinweise_de` **offen** als
  13-px-Absätze in `.wp-fuss` und setzt darunter zwei Verweise - „Die Wärmepumpe jetzt ›"
  und „Gemessene Kennlinie ›" (`Betrieb.tsx:177-187`, `globals.css:795-798`). Die App
  versteckt die Hinweise in der zugeklappten Methodenkarte
  (`WaermepumpeSeiten.swift:255`) und hat keine Verweise.

  [spuerbar] Die Weiche `lief = lauf_min > 0` fehlt (`Betrieb.tsx:48`, `:91`). Bei einer
  Pumpe, die im Zeitraum nicht lief, zeigt die Vorlage bewusst keine Diagramme; die App
  prüft nur je Karte, ob die Liste leer ist.

  [spuerbar] Kein „Hinweis am Finger" an irgendeinem Diagramm. Die Vorlage hat vier, jeder
  mit eigenem Inhalt (`betrieb.ts:81-91` Tag, `:146` Arbeitszahl, `:162` Klasse,
  `:179-182` Stunde). Im Projekt ist der Weg dafür schon gewählt - siehe
  „WAS SCHWIERIG WIRD".

  [klein] Diagrammhöhen: Vorlage 320 px (Handy 280), App 150 für die Klassen
  (`WaermepumpeSeiten.swift:222`) und 160 für die Heizkurve (`:340`).

  [klein] Der Tagesname an Achse und Tabelle: Vorlage `tagName` = „14.11." ohne Wochentag
  und ohne führende Null (`betrieb.ts:42-45`, `betrieb.test.ts:44`: `"2026-01-31"` →
  `"31.1."`); App `Tag.kurz` = „Sa, 14.11." (`Formate/Tag.swift:94-98`).

  [klein] Zellenschreibweisen der Tabelle: „1 h 5 min · 3-mal" für Abtauen und **„0"**
  statt eines Striches, wo nichts war; „{zahl} kWh" mit Einheit in der Zelle; „?" für
  fehlende Werte (`Betrieb.tsx:159-168`). Die App schreibt nur Dauer und Zahl und nutzt
  `Formate.leer` = „-" (`Formate/Formate.swift:27`).

  [klein] Lade- und Fehlersatz: „Der Betrieb wird ausgezählt …" und „Die Auszählung ist
  gerade nicht zu erreichen." (`Betrieb.tsx:46`, `:32`) gegen „Wird geholt …"
  (`WaermepumpeSeiten.swift:257`) und den allgemeinen `Stoerung`-Rat.

  [klein] Der Kicker der Hülle „Läufe · Abtauen · Heizkurve" (`page.tsx:9`) steht in der App
  nirgends; `Bereiche.swift:140` kennt nur den Namen „Betrieb".

  [klein] Farbzuordnung für die beiden neuen Diagramme: Abtauen **#7fa3b3** =
  `Marken.diagrammSpeicher` (`Gestalt/Marken.swift:135`) bzw. `Marken.mist` (`:20`),
  Heizstab **#e0533d** = `Marken.diagrammNetz` (`:131`) - **nicht** `Farbe.achtung`, das ist
  Bernstein (`:98`); „über alles" **#cfd8dc** = `Marken.haus` (`:76`) bzw.
  `Marken.diagrammHaushalt` (`:140`).


KERN: SCHON DA (nachgesehen, nicht geraten)

  * Abfrage: `Api.betrieb(tage: Int) async throws -> BetriebOut` →
    `GET /waermepumpe/betrieb?tage=`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:304-306`).
  * Modelle, vollständig und mit denselben Feldern wie die Vorlage
    (`DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift`):
    - `BetriebOut` `:2023-2111` - `zeitraumTage`, `tage`, `laeufe`, `stunden`, `heizkurve`,
      `klassen`, `starts`, `laufMin`, `abtauMin`, `abtauungen`, `zusatzMin`, `copGesamt`,
      `copHeizen`, `laufMedianMin`, `saetzeDe`, `hinweiseDe`; Listen werden beim Dekodieren
      auf `[]` normalisiert (`:2094-2098`), wie `client.ts:97`.
    - `BetriebTagOut` `:2151-2219` - `tag`, `starts`, `laufMin`, `abtauMin`, `abtauungen`,
      `zusatzMin`, `stromKwh`, `waermeKwh`, `stromLaufKwh`, `copTag`, `copHeizen`,
      `laufMedianMin`, `aussenC`, `waermeMin`. **Alle elf Tabellenspalten sind da.**
    - `BetriebStundeOut` `:2113-2149` - `at`, `minuten`, `aussenC`, `sollC`, `vorlaufC`,
      `ventil`.
    - `BetriebKlasseOut` `:1949-1973` - `vonMin`, `bisMin`, `laeufe`.
    - `BetriebHeizkurveOut` `:1907-1947` - `a`, `b`, `n`, `r2`, `aussenVonC`, `aussenBisC`,
      `formelDe`.
    - `BetriebLaufOut` `:1975-2021` (von beiden Seiten unbenutzt).
  * Formate (`DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift`):
    `zahl(_:stellen:)` `:44-55` (Komma, echtes Minus), `prozent(_:)` `:98-101`,
    `celsius(_:stellen:)` `:104-107`, `kwh(_:)` `:75-78`,
    `dauer(minuten: Int?)` `:122-128` - deckungsgleich mit `bilanz.ts:31-36`
    („45 min", „3 h 20 min", „2 h"), nur mit schmalem geschütztem Leerzeichen.
    `Formate.leer` = „-" `:27`.
  * Tage: `Tag.kurz` `:94-98` („Sa, 14.11."), `Tag.tagMonat` `:106-111` („14.11.",
    **zweistellig aufgefüllt**).
  * Farben (`DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift`): `waermepumpe`
    #E0966B `:58`, `haus` #CFD8DC `:76`, `diagrammNetz` #E0533D `:131`,
    `diagrammSpeicher` #7FA3B3 `:135`, `diagrammHaushalt` #CFD8DC `:140`, `mist` `:20`,
    `rasterlinie` `:34`, `text3` `:45`, `flaeche2` #123544 `:29` (= `FLAECHE` der Vorlage),
    `amber`/`achtung` `:18`/`:98`. Zugriff über `Farbe.*`
    (`DuckCurveHome/Gestalt/Farben.swift:29-83`).
  * Oberflächenbausteine (`DuckCurveHome/Gestalt/Karte.swift`): `Karte` `:15-113` (zwei
    Fassungen nach Breite, Radius 16/Fläche 2 am Telefon - genau `handy.css:182`),
    `Kacheldaten` `:121-151` (mit `dazu`, `farbe`, `weg`), `Kachel` `:158-266`
    (`art: .bericht` setzt Kicker über die Zahl, führend 48 pt mit Kerning −1,9, Hinweis
    zweizeilig - das ist `handy.css:197-207` nachgebaut), `Kachelfeld` `:274-343`
    (erste führt, zwei Spalten, Haarlinien, einzelne Letzte über ganze Breite),
    `Zeile` `:360-383`, `Leer` `:390-404`, `Stoerung` `:410-436`.
  * `Balkenbild` `DuckCurveHome/Seiten/Bericht.swift:70-149` - **kann schon stapeln**
    (`gestapelt: true`, `:109`), hat Legende oben links, Achsenbegrenzung über
    `Achse.beschriftungen(_:hoechstens:)` (`:137`, Kern `Zustand/Achse.swift`).
  * `Tabelle` `Bericht.swift:157-328` - am Telefon Spaltenumschalter, am iPad volle Tabelle,
    `immerSichtbar` für mehrere feste Spalten `:184`, Farbe je Zelle `:169`.
  * `Methode` `Bericht.swift:135-198` - zugeklappte Karte mit `kurz`-Zeile.
  * `Tagewahl` `WaermepumpeSeiten.swift:377-400` - die Knopfreihe, nur mit anderen Maßen.
  * Streubild-Vorbild: `Seiten/Technik/KennlinieSeite.swift:113-174` - `PointMark` mit
    `symbolSize(18)`, Linie darüber, eigene Achsen, Höhe 220.
  * Punkte in zwei Formen (Raute und Kreis) in einem Chart:
    `Diagramme/Prognosezeichnung.swift:601-610` (`.symbol(.diamond).symbolSize(70)` gegen
    `.symbol(.circle).symbolSize(45)`).
  * Ablesung statt Tooltip: `Ablesungszeile` `Prognosezeichnung.swift:49-60`, `Ablesung`
    `:61-91`, angebunden über `.chartXSelection(value:)` `:617` und eine
    `ablesung`-Ansicht `:648-653` mit Aufforderungssatz.
  * Fehlt im Kern: gesucht nach `Betrieb` in
    `DuckCurveKit/Sources/DuckCurveKit/Zustand/`: kein Treffer (nur `Betriebsart` in
    `Speichersteuerung.swift:24` und `Wirkungsbild.betrieb(kw:schwelleKw:)` `:453`, beides
    andere Sachen). **Es gibt kein `Betriebsbild`.**


ES FEHLT:

  1. `DuckCurveKit/Sources/DuckCurveKit/Zustand/Betriebsbild.swift`, `public enum Betriebsbild`
     - die Rechnungen aus `betrieb.ts`, eins zu eins und mit Tests nach `betrieb.test.ts`:
     `stundenTeile(_ t: BetriebTagOut) -> (heizen: Double, abtauen: Double, heizstab: Double)`
     (Stunden, `max(0, laufMin − abtauMin − zusatzMin)`, `betrieb.ts:49-52`),
     `startsJeTag(_ b: BetriebOut) -> Double?` (**durch die Tage mit `laufMin > 0`**,
     `:55-58`), `abtauAnteil(_:) -> Double?` (`:61-63`),
     `kurzAnteil(_:) -> Double?` (Klasse `vonMin == 0`, `:66-70`),
     `klassenName(_ k: BetriebKlasseOut) -> String` („unter 10 min" / „10 bis 20" /
     „ab 90 min", `:72-76`),
     `copSpanne(_ b: BetriebOut) -> ClosedRange<Double>` (ganze Zahlen um die Werte,
     mindestens 2…5, `:118-122`).

  2. Im selben `Betriebsbild`: `kacheln(_ b: BetriebOut) -> [Kennzahl]` - die **vier**
     Kacheln der Vorlage mit ihren Wörtern, Einheiten, Hinweisen und Tönen
     (`Betrieb.tsx:74-77`). `Kennzahl` liegt in
     `DuckCurveKit/Sources/DuckCurveKit/Zustand/Kennzahl.swift` und wird über
     `Kacheldaten(_ k: Kennzahl)` (`Gestalt/Karte.swift:136-138`) zur Kachel; die Abbildung
     Ton→Farbe steht dort schon.

  3. Im selben `Betriebsbild`: die Ablesungstexte, damit sie geprüft werden können und nicht
     in der Ansicht stehen - `tagzeilen(_ t: BetriebTagOut) -> [(String, String)]`
     (`betrieb.ts:81-91`) und `stundenzeilen(_ s: BetriebStundeOut) -> [(String, String)]`
     mit Kopf „TT.MM., HH:MM" in Hauszeit (`betrieb.ts:179-182`).

  4. `DuckCurveKit/Sources/DuckCurveKit/Formate/Tag.swift`: eine Form „14.11." **ohne**
     führende Null. `Tag.tagMonat` `:106-111` füllt auf zwei Stellen auf und ist damit nicht
     `tagName` (`betrieb.test.ts:44-45` verlangt „31.1." und „4.11."). Vorschlag:
     `public static func punkt(_ tag: String) -> String` neben `tagMonat`, mit dem
     Kommentar, warum beide existieren.

  5. `DuckCurveKit/Sources/DuckCurveKit/Zustand/Betriebsbild.swift` zusätzlich:
     `heizkurvenPunkte(_ hk: BetriebHeizkurveOut) -> [(aussen: Double, vorlauf: Double)]` -
     die Vorlage braucht nur **zwei** Punkte (`betrieb.ts:204`), die App rechnet 24
     (`WaermepumpeSeiten.swift:356-362`). Zwei genügen für eine Gerade; die Rechnung gehört
     aus der Seite in den Kern, weil sie neben der Punktwolke genau treffen muss.


BAUPLAN: Dateien, Karte für Karte, in der Reihenfolge der Vorlage

  1. **Kern.** `DuckCurveKit/Sources/DuckCurveKit/Zustand/Betriebsbild.swift` neu anlegen
     (Punkte 1-3 und 5 aus „ES FEHLT"), `Formate/Tag.swift` um `punkt(_:)` ergänzen,
     Tests in `DuckCurveKit/Tests/` nach dem Muster von `betrieb.test.ts` (Fälle:
     `tagName` einstellig, Teile ergeben die Laufzeit, Starts je Tag über Tage mit Betrieb,
     `copSpanne` in drei Varianten, Klassennamen, Hinweiszeilen ohne leere Posten).

  2. **Kopf.** In `WaermepumpeSeiten.swift`, `BetriebSeite.body`: vor der Tagewahl ein
     Block aus `Text(saetzeDe.first ?? "Noch nichts auszuzählen.")` in `Schrift.sans(22)`
     bzw. am Telefon `Schrift.satz` (19 pt, `Typografie.swift:64` - das ist `handy.css:234`)
     und darunter „Letzte N Tage" in `Schrift.klein`/`Farbe.text3`, bei stehendem Fehler mit
     ` · ` und dem Satz. Danach `Tagewahl` mit `moeglich: [7, 14, 30, 90]` und `tage = 14`;
     `Tagewahl` (`:377-400`) auf die Maße der Vorlage ziehen: `Schrift.klein` (13),
     Polster 13/7, Rahmen `Farbe.linie1`, gewählt `Farbe.amber` auf `Farbe.petrol`.

  3. **Kacheln.** `Kachelfeld(kacheln: Betriebsbild.kacheln(b).map(Kacheldaten.init))` -
     vier statt sechs, `ersteFuehrt` bleibt (das ist „eine Zahl führt"). Kicker weg, die
     Spanne steht jetzt im Kopf.

  4. **Karte „Was die Auszählung zeigt".** Dieselbe Karte wie heute, aber nur mit
     `saetzeDe.dropFirst()`, Titel geändert, Schrift 15 pt statt `Schrift.klein`
     (`globals.css:1024`), und nur wenn noch etwas übrig ist.

  5. **Weiche.** `if (b.laufMin ?? 0) > 0 { … }` um die vier Diagramme.

  6. **Diagramm 1.** `Balkenbild` kann es schon: drei `Stueck` („Heizen"
     `Farbe.waermepumpe`, „Abtauen" `Farbe.diagrammSpeicher`, „Heizstab"
     `Farbe.diagrammNetz`), `gestapelt: true`, `einheit: "Stunden"`,
     `hoehe: schmal ? 280 : 320`, Werte aus `Betriebsbild.stundenTeile`, Beschriftung
     `Tag.punkt`. In einer `Karte(kicker: "Laufstunden je Tag")`.

  7. **Diagramm 2.** Neu: `DuckCurveHome/Diagramme/Betriebskurven.swift` mit
     `struct Arbeitszahlbild: View` - zwei `LineMark`-Reihen mit `series:`, Punkte als
     `PointMark` `symbolSize(~40)`, Lücken als **eigene Stücke** (Swift Charts kennt kein
     `connectNulls: false`; das Verfahren steht als Kommentar an
     `Wirkungszeichnung.swift:206-209`), `chartYScale(domain: Betriebsbild.copSpanne(b))`,
     Achsenschrift `Schrift.achse` (am Telefon eine Stufe größer, wie
     `Heizkurvenbild.swift:43`). Darunter der Erklärsatz aus `Betrieb.tsx:101` wörtlich in
     `Schrift.klein`/`Farbe.text3`.

  8. **Diagramm 3.** Die bestehende Klassenkarte umstellen: `Betriebsbild.klassenName`,
     `hoehe` auf 280/320, Zahl über dem Balken (`.annotation(position: .top)` am `BarMark`,
     Vorbild `Wirkungszeichnung.swift:243`), darunter der Satz über die vollständigen Läufe
     und, bei leerer Klassenliste, `Leer(satz:)` mit dem Satz aus `Betrieb.tsx:114` statt
     des heutigen Weglassens.

  9. **Diagramm 4.** `Betriebskurven.swift` zweitens: `struct Reglerkurvenbild: View` -
     `PointMark` für alle `stunden` (Sollwert, `Farbe.waermepumpe`, `symbolSize 50`),
     `PointMark` `.symbol(.diamond)` für die mit `vorlaufC` (`Farbe.diagrammSpeicher`),
     darüber die Gerade aus zwei Punkten in `Farbe.text1.opacity(0.85)`, 2 pt. Achsen ohne
     Nullzwang (`chartXScale`/`chartYScale` mit gerechneter Spanne), Achsentitel
     „Außentemperatur °C" und „Vorlauf °C". Legende über `Umbruchzeile`
     (`Gestalt/Umbruchzeile.swift`, Vorbild `Heizkurvenbild.swift:398-421`), nur mit den
     Reihen, die es gibt. Darunter `formelDe` in `Schrift.zahlKlein` und der Erklärsatz;
     ohne Gerade der Ersatzsatz, ohne `stunden` `Leer(satz:)` mit dem Satz aus
     `Betrieb.tsx:128`. Die heutige `heizkurve(_:)` (`:304-354`) geht darin auf.

 10. **Tabelle.** `Tabelle` mit elf Spalten in der Folge der Vorlage, Zeilennamen
     `Tag.punkt`, Zeilen **umgekehrt**, Zellenschreibweisen nach `Betrieb.tsx:159-168`
     („0" statt „-" bei Abtauen und Heizstab, „?" bei fehlenden Werten, Einheit in der
     Zelle). In eine Karte, die zugeklappt beginnt - `DisclosureGroup` wie in `Methode`
     (`Bericht.swift:162`) -, mit dem Griff „Die Tage als Tabelle (N)".

 11. **Fußzeile.** `hinweise_de` **offen** als Absätze in `Schrift.klein`/`Farbe.text3`
     statt in `Methode`, darunter zwei Verweise über `Wegweiser.gehe(_:)`
     (vorhanden, `Gestalt/Karte.swift:176`, `:182`) nach `/waerme/waermepumpe` und
     `/waerme/waermepumpe/kennlinie`, in `Farbe.amber` mit „›".

 12. **Zustände.** Ladesatz auf „Der Betrieb wird ausgezählt …" und, wenn noch keine Daten
     da sind, den Fehlersatz der Vorlage statt der `Stoerung`-Karte; bei vorhandenen Daten
     bleibt `Stoerung` (die App ist hier besser, weil sie einen Knopf hat - das als
     Kommentar festhalten, damit es nicht als Abweichung zurückgebaut wird).


WAS SCHWIERIG WIRD

  * **Hinweis am Finger.** Die Vorlage hat an allen vier Diagrammen Tooltips
    (`betrieb.ts:25-31`, `:108`, `:143-147`, `:162`, `:221`, `:232`). Swift Charts hat
    kein Gegenstück. Der Weg im Projekt ist gewählt: `.chartXSelection(value:)` plus eine
    **Ablesezeile unter dem Bild** statt eines schwebenden Kästchens -
    `Diagramme/Prognosezeichnung.swift:61-91` (`struct Ablesung` mit
    `aufforderung`-Satz), angewandt `:617` und `:648-653`, ebenso
    `Wirkungszeichnung.swift:191-203`. Für die Streupunkte der Heizkurve gibt es keine
    x-Auswahl, die einen Punkt trifft: dort ist `.chartOverlay` mit eigener Suche nach dem
    nächsten Punkt das Vorbild (`Diagramme/Tageskurve.swift:204`, `:287`).
  * **`connectNulls: false`.** Ein Tag ohne Lauf ist in der COP-Linie eine Lücke. Swift
    Charts verbindet über `nil` hinweg, wenn alles eine Reihe ist; der Kommentar an
    `Wirkungszeichnung.swift:206-209` sagt den Weg: „Jedes Stück eine eigene Reihe … also
    zerlegt der Kern die Kurven in zusammenhängende Stücke." Das Zerlegen gehört also in
    `Betriebsbild`, nicht in die Ansicht.
  * **Zahl über dem Balken.** ECharts setzt sie mit `label.position: "top"`
    (`betrieb.ts:172`). In Swift Charts ist das `.annotation(position: .top)` am `BarMark`;
    Vorbild `Wirkungszeichnung.swift:243` und `:258`.
  * **Legende nur mit den vorhandenen Reihen.** ECharts nimmt dazu eine Namensliste
    (`betrieb.ts:187`). `chartForegroundStyleScale` in `Balkenbild`
    (`Bericht.swift:116-120`) kann das über die Stückliste; für das handgebaute
    Heizkurvenbild ist `Umbruchzeile` + `legendenstueck` der Weg
    (`Heizkurvenbild.swift:398-421`).
  * **Achsen ohne Nullzwang.** `scale: true` an beiden Achsen der Heizkurve
    (`betrieb.ts:195-196`). In Swift Charts muss die Spanne gerechnet und per
    `chartXScale`/`chartYScale` gesetzt werden - Vorbild
    `Pruefkurvenbild.swift:75-76`, `Fahrplanzeichnung.swift:148-149`.
  * **Breite Tabelle.** Die Vorlage rollt die elf Spalten seitlich und macht sie am Handy
    **nicht** zur Liste (`globals.css:912-913`, `handy.css:246-247`). Die App-`Tabelle`
    macht am Telefon grundsätzlich eine Liste mit Spaltenumschalter
    (`Bericht.swift:157-328`); `immerSichtbar` ist dort die vorgesehene Ausnahme und
    begründet sich selbst an der Raumtabelle (`Bericht.swift:176-183`). Hier ist die
    Entscheidung zu treffen und zu begründen - der Spaltenumschalter ist für elf Spalten
    wahrscheinlich besser als die Rolle, aber es ist eine Abweichung von der Vorlage und
    gehört als Kommentar in die Seite.
  * **Der Spalt zwischen den Teilen eines gestapelten Balkens.** Die Vorlage zieht dafür
    einen 1-px-Rand in der Kartenfarbe (`betrieb.ts:101`, `FLAECHE = "#123544"` =
    `Marken.flaeche2`). `BarMark` kennt keinen Rand; `Balkenbild` setzt heute nur
    `cornerRadius(1)` (`Bericht.swift:112`). Entweder man lebt mit der Rundung oder man
    zeichnet den Spalt über `.annotation`/`RuleMark` - hier reicht die Rundung, aber die
    Absicht („die Teile sollen trennbar sein") muss im Kommentar stehen.
