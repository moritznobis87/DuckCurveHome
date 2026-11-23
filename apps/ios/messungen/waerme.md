========================= messen:waerme   Aufwand: mittel

> Zweite Runde. Die Seite ist am 17.11. nach einer Handliste nachgearbeitet worden
> (`apps/ios/ABGLEICH.md:72-75`: „14 von 14 Punkten"). Diese Messung glaubt dem nicht und
> liest nur Code. Alles unten ist in `apps/web` und `apps/ios` selbst nachgesehen.

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

`struct WaermeSeite: View` steht in
`apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift:41-364`, eingehängt über
`apps/ios/DuckCurveHome/App/Seitenwahl.swift` am Weg `/waerme`; der Reiter mit Zeitraum und
dem Kicker „gerechnet, nicht gemessen" steht in
`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:143-144`.

1. Gerippe `Berichtsseite` (`apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-64`):
   Zeitraumleiste oben (`Bericht.swift:35`), `Stoerung` über dem Inhalt (`Bericht.swift:36-38`),
   „Wird geholt …" / „Für diesen Zeitraum ist nichts da." (`Bericht.swift:43-47`), das Alte
   bleibt mit `opacity 0.55` stehen (`Bericht.swift:41`). Geladen wird **einmal je Zeitraum**
   (`.task(id: z)`, `Bericht.swift:49`) - kein Nachladen.
2. Vier Abfragen (`WaermeSeite.swift:44-53`): `api.waermebilanz`, `api.energieWaerme`,
   `api.energieVerschiebung` (mit `try?`, darf fehlen, `:47-49`) und `holeSpannen` - vier
   weitere `waermebilanz`-Abrufe je Spanne, jeder mit `try?` (`WaermeSeite.swift:61-74`).
   Die ersten beiden stehen unter `try await` (`:51`): schlägt eine fehl, ist die Seite leer.
3. `Kachelfeld(kacheln: Waermeuebersicht.kacheln(...), kicker: "Wärme")`
   (`WaermeSeite.swift:79-83`), sechs Kacheln aus
   `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Waermeuebersicht.swift:42-96`:
   Wärme gesamt (Ton `.glut`) · Strom Wärmepumpe · Arbeitszahl (`.nebel`) · Bezahlt
   (`.bernstein`) · Wärmepreis (`.bernstein`) · Entnahme. Zwei Spalten
   (`Karte.swift:279`), am Telefon führt die erste in 48 pt (`Karte.swift:240, 288-303`).
4. Bei `period == .day`: `Karte(kicker: "Tagesverlauf", titel: resolutionDe)` mit
   `Waermeverlauf` (`WaermeSeite.swift:87-90`,
   `apps/ios/DuckCurveHome/Diagramme/Waermebilder.swift:14-172`), darunter, wenn eine
   Pufferreihe da ist, `Karte(kicker: "Pufferspeicher", titel: "Temperaturen in vier Höhen ·
   Leistung der Wärmepumpe")` mit `Pufferbild` (`WaermeSeite.swift:91-98`,
   `Waermebilder.swift:184-305`).
   Sonst `Karte(kicker: "Wärme je Monat" | "Wärme je Tag")` mit `Balkenbild`
   (`WaermeSeite.swift:100-107`, Stücke in `:234-246`).
5. `Karte(kicker: "Strom der Wärmepumpe nach Herkunft")`, `Balkenbild` gestapelt aus PV,
   Batterie, Netz (`WaermeSeite.swift:109-115`, `:248-263`).
6. `Karte(kicker: "Was die Wärme gekostet hat")`: Kernzahl `kostenkernzahl` in `.bernstein`,
   fünf `Zeile`n einspaltig, `cheaperDe` (`WaermeSeite.swift:117-130`,
   `Waermeuebersicht.swift:101-127`).
7. `Karte(kicker: "Taktung", titel: taktkopf)`: Kernzahl „Starts je Tag" mit
   `verdict?.wort` rechts, sechs `Zeile`n einspaltig, `noteDe`
   (`WaermeSeite.swift:132-150`, `Waermeuebersicht.swift:174-197`).
8. `Karte(kicker: "Hat sich das Verschieben gelohnt?", titel: "geschätzt")`: Kernzahl in
   `.bernstein`, drei Zeilen oder Hinweis (`WaermeSeite.swift:153-167`,
   `Waermeuebersicht.swift:131-168`). **Ohne jeden Verweis.**
9. `Karte(kicker: "Pelletofen", titel: ofenkopf)` mit Laufzeit (`.glut`), neun Zeilen
   einspaltig, Leistungsstufen in einer `Umbruchzeile`, zwei Sätze
   (`WaermeSeite.swift:169-177, 265-292`); ist der Ofen nicht verfügbar, eine Karte mit
   „In diesem Zeitraum hat der Ofen nicht gemeldet." (`:173-177`).
10. `Karte(kicker: "Bei offenem Fenster", titel: "geschätzt, nach offenen Heizkreisen
    verteilt")` nur wenn `zeigtFenster`: Kernzahl, `Tabelle` mit drei Spalten, `noteDe`
    (`WaermeSeite.swift:181-188, 294-323`).
11. `Karte(kicker: "Bilanz des Puffers")` mit sechs Zeilen (`WaermeSeite.swift:190-192,
    341-363`). **Diese Karte hat die Vorlage nicht** - siehe LUECKEN 12.
12. `Karte(kicker: "Wärme im Zeitraum")` mit einer nackten `Tabelle`, Spaltennamen
    `Spanne.name` (`WaermeSeite.swift:194-196, 326-334`,
    `DuckCurveKit/Formate/Zeitraum.swift:15-20`).
13. `Methode([...])` mit acht Sätzen (`WaermeSeite.swift:198-208`) - **ohne `kurz:`**, also
    ohne immer sichtbare Abdeckungszeile (`Bericht.swift:516-523`).

Bausteine: `Karte`/`Kachelfeld`/`Kachel`/`Zeile`/`Leer` in
`apps/ios/DuckCurveHome/Gestalt/Karte.swift`, `Tabelle`/`Methode`/`Balkenbild` in
`Seiten/Bericht.swift:70-577`, Farben in `Gestalt/Farben.swift` über
`DuckCurveKit/Gestalt/Marken.swift`.

VORLAGE:

Einstieg `apps/web/src/app/waerme/page.tsx:1-7` → `HeatOverview` in
`apps/web/src/components/reports/HeatOverview.tsx:89-382`.

  * **Kopf** `ReportShell title="Wärme" kicker="gerechnet, nicht gemessen"`
    (`HeatOverview.tsx:137`, Gerippe `reports/ReportShell.tsx:97-134`).
    Kicker rechts neben den Reitern, 11 px (`layout/AreaNav.tsx:96`), am Telefon
    ausgeblendet (`hidden … md:block`, ebd.). Blätterleiste mit ‹ › , langem
    Ankernamen („Dienstag, 10.11.2026") und kurzem am Telefon („Di., 10.11.",
    `ReportShell.tsx:51-58, 109-117`), „heute" nur wenn der Anker nicht heute ist
    (`:116`), vier Spannenknöpfe in Bernstein auf Petrol (`:120-126`).
    `ErrorBanner` über dem Inhalt, nur für den Fehler der **Bilanz**
    (`HeatOverview.tsx:138`, `ReportShell.tsx:147-153`).
    DATEN: drei getrennte Abrufe mit je eigenem Zustand und **5-Minuten-Takt**
    (`useReport.ts:7, 18-46`): `api.heatBalance(period, anchor)` (`HeatOverview.tsx:91-92`),
    `api.energyHeat` (`:93`), `api.energyShift` (`:94`), dazu `useMultiPeriod` für alle vier
    Spannen mit `Promise.allSettled` (`:95`, `useReport.ts:55-77`). Scheitert einer, bleiben
    die anderen Karten stehen.

  * **KpiGrid cols=6** (`HeatOverview.tsx:140-166`, `ReportShell.tsx:176-182`,
    `globals.css:107`: `repeat(auto-fit, minmax(clamp(150px, 100%/6 - 16px, 260px), 1fr))`,
    am Telefon zwei Spalten in **einer** Fläche mit Haarlinien, erste Kachel über die
    ganze Breite in 48 px, letzte ungerade auch, `handy.css:197-207`).
    Sechs `Stat` (`ui/Stat.tsx:33-48`): Kicker 11 px, Zahl 26 px mono, Einheit 13 px,
    Kontextzeile 12 px mit `line-clamp-2`. **Kein `tone` an keiner der sechs** - alle
    Zahlen in `var(--text-1)` (`Stat.tsx:34`, Aufrufe `HeatOverview.tsx:141-165`).
    1. „Wärme gesamt", `kwh(t?.produced_kwh)`, kWh, dazu
       „Wärmepumpe X · Ofen Y kWh" wenn Ofen > 0,05, sonst „nur die Wärmepumpe".
    2. „Strom Wärmepumpe", `de1(e?.heat_pump_kwh)`, kWh, dazu „NN % Sonnenstrom"
       ((pv+batterie)/gesamt, `:100`).
    3. „Arbeitszahl", zwei Stellen, dazu „aus Kennlinie und Vorlauf" bzw. „keine Laufzeit".
    4. „Bezahlt", €, dazu „X kWh Netz · Ø Y ct" (`:101`).
    5. „Wärmepreis", ct/kWh, dazu „Wärmepumpe · Ofen Z ct".
    6. „Entnahme", kWh, dazu „Heizung und Warmwasser · Verlust V kWh".
    DATEN: `heatBalance.totals`, `.cost`, `heatReport.summary.totals`.

  * **Tagesverlauf** (nur `period === "day"`), Karte `padding 16, minHeight 320`, Diagramm
    380 px hoch (`HeatOverview.tsx:170-180`), `resolution_de` **rechts** im Kartenkopf
    (`:172`, `ui/Card.tsx:20-29`), Leerfall „Für diesen Tag liegen keine Minutenwerte vor."
    Bild: `heatBalanceChart` (`reports/charts.ts:793-886`). Zwei Flächen übereinander:
    oben kW, unten kWh (`charts.ts:856`, `zweiFlaechen(46, 52, 44, 72)`), gemeinsamer
    Zeiger (`:855`), Zoom innen **und** Schieberegler unten (`:857-860`).
    Begründung im Kopf des Diagramms (`charts.ts:778-791`), wörtlich:
    „**Flächen für die Erzeuger, Linien für die Senken.** Gestapelt wird nur, was sich
    wirklich addiert: Wärmepumpe und Ofenwasser gehen beide in denselben Puffer, ihre Summe
    ist die Zufuhr. Entnahme und Verlust gehen aus ihm heraus und stehen deshalb als eigene
    Linien daneben, nicht als weitere Schicht desselben Stapels - sonst läse man eine Summe,
    die es nicht gibt." Und: „Farbabstände geprüft (dE2000, dunkler Grund): das engste Paar
    ist Ofen gegen Verlust mit 16,9 … Die Grenze des Projekts ist 15."
    Reihen (`charts.ts:876-883`):
    - „Wärmepumpe": Fläche, gestapelt `zufuhr`, Linie 1 px `#e0966b`, Füllung
      `rgba(224,150,107,.24)`.
    - „Ofen (Wasser)": Fläche, gestapelt, `#b5651d`, Füllung `rgba(181,101,29,.28)`.
    - „Ofen (Raum)": **Linie, gestrichelt, nicht im Stapel**, `#b5651d`, 1,5 px, Deckung
      0,9; Kommentar `charts.ts:878-879`: „Die Raumwärme des Ofens geht nicht in den Puffer.
      Sie gehört deshalb nicht in den Stapel, auch wenn sie vom selben Gerät kommt -
      gestrichelt daneben, in derselben Farbe."
    - „Entnahme": Linie 2 px in `C.house` **`#cfd8dc`**; Kommentar `charts.ts:872-875`:
      „Die Wärmepumpe in ihrer Farbe, wie überall. Sie war hier hell, und die Entnahme
      sandfarben; mit dem Orange der Wärmepumpe wäre Sand bei Deuteranopie dieselbe Farbe
      (ΔE 0,2). Die Entnahme ist deshalb hell."
    - „Verlust an den Raum": Linie 1,5 px **gestrichelt** in `C.alert` `#e0533d`.
    - „Pufferinhalt": zweite Fläche, Linie 2 px in `C.mist` **`#7fa3b3`**, Füllung
      derselben Farbe mit Deckung **0,14**, eigene kWh-Achse (`charts.ts:883`).
    Legende oben, einzeilig und blätterbar, Reihen abschaltbar
    (`inactiveColor`, `charts.ts:829-848`); „Ofen (Raum)" und „Verlust an den Raum" tragen
    ein **gestricheltes** Legendenzeichen (`:844, :846`).
    `connectNulls: false` überall außer beim Pufferinhalt.
    DATEN: `heatBalance.series` (`HeatBalancePoint`: `heat_pump_kw`, `stove_water_kw`,
    `stove_room_kw`, `draw_kw`, `loss_kw`, `buffer_kwh`).

  * **Wärme je Tag / je Monat** (jede längere Spanne), `stackedBars`
    (`HeatOverview.tsx:182-192`, `charts.ts:52-89`), Höhe 260 px, Legende als
    `ChartLegend` rechts im Kartenkopf (`:183`, `ReportShell.tsx:192-203`). Stücke
    `ERZEUGER` (`HeatOverview.tsx:41-46`): Wärmepumpe `#e0966b`, Ofen (Wasser) `#b5651d`,
    Ofen (Raum) `rgba(181,101,29,.55)` - mit Kommentar: „Halbtransparentes Ofenbraun statt
    einer eigenen Farbe: derselbe Erzeuger, ein anderer Weg."
    Leerfall „Für diesen Zeitraum liegen keine Werte vor."
    DATEN: `heatBalance.buckets[].label_de` und die drei Felder.

  * **Reihe: Pufferspeicher + Strom nach Herkunft** `report-row` mit `--cols` =
    `"7fr 5fr"` bei Tag mit Pufferreihe, sonst `"1fr"` (`HeatOverview.tsx:194-211`,
    `globals.css:108`; am Telefon eine Spalte, `globals.css:350`).
    - „Pufferspeicher", `id="puffer"`, Höhe 360, Untertitel rechts „Temperaturen in vier
      Höhen · Leistung der Wärmepumpe"; nur je Tag, mit Kommentar `:195-196`: „Die
      Schichtung des Puffers gibt es nur je Tag; in einer Woche wäre sie ein Knäuel. Dann
      fehlt die Karte, statt mit einem Platzhalter die halbe Zeile zu belegen."
      Bild `bufferChart` (`charts.ts:99-145`): vier Fühler `#f2a900` / `#ffd778` /
      `#7fa3b3` / `#2f89b5`, Temperaturachse **fest 20…70 °C, Schritt 10** (`:132`),
      unten kW ab 0 (`:133`), Brennphasen als Bänder `rgba(181,101,29,.20)` mit eigenem
      Legendeneintrag „Ofen brennt" (`:138-142`), Begründung `:108-110`.
    - „Strom der Wärmepumpe nach Herkunft", Höhe 300, Legende `STROM` rechts
      (`HeatOverview.tsx:205-210, 35-39`): aus PV `#f2a900`, aus Batterie `#7fa3b3`,
      aus Netz `#e0533d`. Kein Leerfall - die Karte zeigt leere Achsen.
      DATEN: `heatReport.buffer_series` bzw. `heatReport.summary.buckets[].totals`.

  * **Reihe: Kosten + Taktung + Verschieben** `report-row --cols: "1fr 1fr 1fr"`,
    Karten `padding 14px 18px, gap 10` (`HeatOverview.tsx:213-274`).
    - „Was die Wärme gekostet hat": `Kernzahl` = Wärmepreis, Einheit „ct je kWh Wärme".
      `Kernzahl` ist 26 px mono **in `text-1`**; Kommentar `HeatOverview.tsx:78`:
      „Die große Zahl einer Karte mit ihrer Unterzeile. **Schrift in Textfarbe, wie
      überall.**" Fünf Zeilen (`:218-222`) wörtlich: „Wärmepumpe: bezahlter Netzstrom",
      „Wärmepumpe: entgangene Vergütung", „Pellets: verbrannte Menge", „Pellets: Wert zum
      hinterlegten Preis", „Ofen: je kWh Wärme". Dann `cheaper_de` als `Note`.
    - „Taktung", rechts „N h bewertet" (`:228`). Kernzahl „Starts je Tag", rechts das
      Urteil aus `TAKTUNG` (`:49-54`): ok „unauffällig", watch „grenzwertig",
      short_cycling „taktet häufig", unknown „zu wenig Daten" - **mit Rückfall auf
      `TAKTUNG.unknown`, wenn `verdict` fehlt** (`:232`). Sechs Zeilen in **zwei Spalten**
      (`grid-cols-2 gap-x-4`, `:234-241`): Läufe, Laufanteil, Lauf im Mittel, kürzester
      Lauf, Pause im Mittel, unter Mindestlaufzeit. Dann `note_de`.
    - „Hat sich das Verschieben gelohnt?", rechts „geschätzt". Kernzahl `|saving_eur|`,
      Einheit als Satz: „gespart gegenüber einem Lauf ohne Preisblick" / „mehr bezahlt als
      ohne Preisblick" / „keine Aussage für diesen Zeitraum" (`:250-253`). Drei Zeilen oder
      `skipped_de`. **Unten zwei Verweise** (`:263-272`), am Fuß der Karte festgehalten
      (`mt-auto`): „Rechnung und Annahmen ›" auf `/geld?period=…&anchor=…` und, nur je Tag,
      „Fahrplan gegen Wirklichkeit ›" auf `/waerme/nachbetrachtung?day=…`, beide in
      `text-amber`. Kommentar `:245-247`: „Dieselbe Zahl wie auf ‚Geld': eine Rechnung, an
      zwei Stellen gezeigt. Vorher stand hier eine eigene Karte ‚Lief sie zur richtigen
      Zeit?' mit einer zweiten Antwort auf dieselbe Frage."
      DATEN: `heatBalance.cost`, `heatReport.cycling`, `shiftReport`.

  * **Reihe: Pelletofen + Bei offenem Fenster**, `--cols` = `"5fr 7fr"` wenn beide,
    sonst `"1fr"`; **fehlt beides, fehlt die ganze Reihe** (`HeatOverview.tsx:276-344`).
    - „Pelletofen", `id="ofen"`, nur wenn `stove.available`; rechts „N Brennphase(n)".
      Kernzahl = Laufzeit als „3:05 h" (`dauer`, `:63-67`). **Neun Zeilen in zwei
      Spalten** (`:282-292`): davon mit Feuer, längste Phase, Brennstoff, zum Preis von,
      Spreizung, Rauchgas max., Warmwasser, Betriebsstunden, Zündungen. Leistungsstufen als
      Umbruchzeile „Leistungsstufen: 1: 0:45 h …" (`:293-302`). `note_de`, und
      `fuel_note_de` nur wenn `auger_revolutions` (`:303-304`).
    - „Bei offenem Fenster", rechts „geschätzt, nach offenen Heizkreisen verteilt", nur
      wenn `kwh > 0,01 || open_minutes > 0` (`:109`), Kommentar `:308-309`: „Nur zeigen,
      wenn es etwas zu zeigen gibt: eine Karte, die jeden Tag ‚null' sagt, liest nach einer
      Woche niemand mehr." Kernzahl = kWh, rechts „N min offen · M % der Entnahme".
      Tabelle `fenster-tabelle` mit vier Spalten: Raum, Fenster offen, davon geheizt, Wärme
      (`:319-338`). Dann `note_de`.
      DATEN: `heatReport.stove`, `heatBalance.ventilation`.

  * **PeriodStrip „Wärme im Zeitraum"** (`HeatOverview.tsx:346`,
    `reports/PeriodStrip.tsx:32-94`). Rechts im Kartenkopf „jeweils bis jetzt" bzw.
    „jeweils bis 10.11.2026" (`PeriodStrip.tsx:34-38`); Spaltenköpfe
    „Heute | Woche | Monat | Jahr", wobei die erste Spalte **nur „Heute" heißt, wenn der
    Anker heute ist**, sonst „10.11." (`:9-16`); erste Namensspalte 34 % breit, erste
    Datenzeile `font-weight: 600` (`:72, 84`). Zwölf Zeilen
    (`HeatOverview.tsx:118-131`), Einheit im Namen und nicht in der Zelle, mit Begründung
    `:116-117`: „Die Einheit steht in der Zeile und nicht in jeder Zelle … vier Spalten mit
    ‚63,7 kWh' liefen am Handy ineinander": Wärme gesamt · Wärmepumpe · Ofen ins Wasser ·
    Ofen in den Raum · Entnahme · Verlust · Strom Wärmepumpe · Arbeitszahl (2 Stellen) ·
    nicht zuzuordnen · Strom bezahlt · Pellets kg · Pellets im Wert von.
    `feld()` setzt einen Strich, wenn `totals.minutes === 0` (`:56-59`): „Null ist eine
    Messung, ‚keine Daten' ist keine."
    DATEN: vier `heatBalance`-Abrufe zum selben Anker.

  * **CoverageNote / Methode** (`HeatOverview.tsx:348-379`, `ReportShell.tsx:163-174`,
    `ui/Methode.tsx:66-82`). Zugeklappt, aber die **Kurzzeile bleibt sichtbar**:
    „Datenabdeckung NN % · Aufzeichnung seit 10.11.2026" (`ReportShell.tsx:166-168`);
    Begründung `Methode.tsx:59-61`: „Nicht hinein gehört, was eine Zahl *an diesem Tag*
    einschränkt … Das steht neben der Zahl, denn zugeklappt wäre es verschwiegen."
    Titel: **„Wie gerechnet wird"** (`Methode.tsx:66`).
    Sechs Absätze, davon fünf von Hand geschrieben (`HeatOverview.tsx:349-378`):
    1. „Im Haus gibt es keinen Wärmemengenzähler: jede Wärmemenge auf dieser Seite ist aus
       Strom, Ofenbetrieb und Puffertemperaturen gerechnet."
    2. „Gemessen werden der Strom der Wärmepumpe, der Betriebszustand des Ofens und vier
       Puffertemperaturen. Die Wärme der Wärmepumpe ist Strom mal Arbeitszahl. Die
       Arbeitszahl folgt der Kennlinie über der Außentemperatur und wird über das Verhältnis
       der Carnot-Zahlen auf den wirklichen Vorlauf umgerechnet: dieselbe Maschine liefert
       bei 40 °C Vorlauf deutlich mehr als bei 58 °C, und der Puffer durchläuft an einem
       Wintertag beides."
    3. „Die Entnahme in Heiz- und Brauchwasserkreis wird nicht gemessen; sie ist der Rest
       der Bilanz, und jeder Fehler der anderen Größen landet in ihr. Was nicht aufgeht,
       steht deshalb in der Tabelle als ‚nicht zuzuordnen'. Ein dauerhaft großer Rest heißt,
       dass eine Annahme nicht stimmt."
    4. „Bei den Kosten stehen zwei Zahlen verschiedener Art nebeneinander. Der Strom der
       Wärmepumpe ist geflossen und bezahlt; dazu gehört die entgangene Einspeisevergütung
       für Sonnenstrom, der in den Verdichter statt ins Netz ging. Die Pellets waren bezahlt,
       als sie geliefert wurden; hier steht, was die verbrannte Menge zum hinterlegten Preis
       wert war. Die Menge ist aus den Leistungsstufen des Ofens geschätzt."
    5. „Im Tagesverlauf sind Flächen Zufuhr in den Puffer und addieren sich; Linien sind,
       was wieder herausgeht. Die Raumwärme des Ofens geht nicht durch den Puffer." + dahinter
       `bilanz.note_de`.
    6. Die Annahmen in Zahlen (Kennlinie, Referenzvorlauf, Puffer, Ofen, Pellets) mit dem
       Verweis **„Annahmen"** auf `/waerme/annahmen` in `text-amber` und dem Satz: „Wer diese
       Werte unter Annahmen ändert, ändert jede Zahl auf dieser Seite, auch die vergangener
       Jahre." Dazu `meta.estimated_note_de` (`ReportShell.tsx:171`).
    **Nicht gezeigt:** `buffer_balance`, `price_quality` und `model_note_de` aus
    `HeatReportOut` - gesucht nach `buffer_balance`, `price_quality`, `model_note_de` in
    ganz `apps/web/src` (alle `.ts`/`.tsx`): Treffer nur in `lib/api/types.ts:4519-4523`,
    also nirgends dargestellt.

  * **Handy-Fassung** (`apps/web/src/styles/handy.css`, Grenze ist die Breite allein, `:24-26`):
    - Vier Entscheidungen im Kopf der Datei (`handy.css:9-19`): Bereiche unten, „Eine Zahl
      führt", „Flächen statt Rahmen", „Tabellen werden Listen".
    - Karten: kein Rand, Radius 16, Polster 16 (`:181`). Kartenkopf: der Kicker wird
      **lesbare Schrift** - Sans 16,5 px, 600, keine Sperrschrift, `text-1` (`:184`); der
      Untertitel bricht in eine eigene Zeile um, 13 px (`:185`).
    - Kennzahlen: eine Fläche `surface-2`, zwei Spalten, Haarlinien, erste Kachel über die
      ganze Breite in **48 px** mit Kontextzeile 14,5 px in `text-2`, letzte ungerade
      ebenfalls über die Breite; Kicker in der Kachel bleibt **gesperrt** 11 px/0,1 em
      (`:197-207`).
    - Kleine Schriften eine Stufe größer: 10→11, 11→12, 12→13,5, 13→14,5 (`:188-192`).
    - `report-row` Abstand 14 px, eine Spalte (`:209`, `globals.css:350`).
    - Methode: Polster 0, Kopfzeile 15 px Sans 600, Kurzzeile 13 px, Absätze 14,5 px
      (`:212-217`).
    - Spannentabelle: Reihenschalter `.spannen` (Fläche, vier Pillen, aktive in Bernstein
      auf Petrol, je 34 px hoch, 13,5 px, Gewicht 500) über einer **Liste** mit Namen
      14,5 px in `text-2` und Wert 16 px (`:291-299`, `PeriodStrip.tsx:42-64`).
    - **Die Fenstertabelle ist am Telefon eine eigene Gestalt** (`:305-306, 340-347`):
      `thead` weg, jede Zeile ein Block; oben links der Raumname (15 px, `text-1`), oben
      rechts die Wärme (16 px, `text-1`, `order: -1`), darunter die beiden Dauern in 13 px
      `text-3`, und die Spaltennamen hängen als `::after` an der Zelle: „ offen" und
      „ davon geheizt".

LUECKEN:

  [traegt-die-seite] Der Tagesverlauf stapelt die Raumwärme des Ofens in die Zufuhr und
  zeigt damit eine Summe, die die Vorlage ausdrücklich verbietet. `Waermebilder.swift:139-152`
  rechnet `gesamt = wp + wasser + raum` und `:59-61` zeichnet drei Flächen übereinander;
  die Vorlage lässt `stove_room_kw` als **gestrichelte Linie neben** dem Stapel
  (`charts.ts:878-880`) mit der Begründung „sonst läse man eine Summe, die es nicht gibt"
  (`charts.ts:781-784`). Der Kopfkommentar der App-Datei weiß davon
  (`Waermebilder.swift:7-10`: „steht trotzdem als Fläche") - das ist kein Versehen, sondern
  eine Abweichung ohne Beleg, und sie verfälscht die Hauptaussage des Hauptdiagramms. Mit ihr
  gilt auch die Farbprüfung der Vorlage nicht mehr (`charts.ts:788-790`).

  [spuerbar] Vier der sechs Methodenabsätze der Vorlage stehen nirgends in der App.
  `WaermeSeite.swift:198-208` setzt einen eigenen Satz plus sechs `*_de`-Felder des Dienstes;
  es fehlen die Absätze 2 bis 5 aus `HeatOverview.tsx:352-369` - die Carnot-Umrechnung auf den
  wirklichen Vorlauf, „die Entnahme ist der Rest der Bilanz, und jeder Fehler der anderen
  Größen landet in ihr", die zwei Arten von Kosten und der Satz, der sagt, was im Tagesverlauf
  Fläche und was Linie ist. Auf einer Seite mit dem Kicker „gerechnet, nicht gemessen" ist das
  die Begründung jeder Zahl. Gesucht nach „Carnot", „Rest der Bilanz" und „nicht zuzuordnen"
  in `apps/ios/DuckCurveHome` und `apps/ios/DuckCurveKit/Sources`: nur „nicht zuzuordnen" als
  Zeilenname in `Waermeuebersicht.swift:296`.

  [spuerbar] `Methode` wird ohne `kurz:` gerufen (`WaermeSeite.swift:198`), also steht die
  Datenabdeckung nur aufgeklappt. `Waermeuebersicht.abdeckungssatz` (`:332-343`) landet als
  einer von acht Sätzen **im** Deckel (`WaermeSeite.swift:206`). Der Baustein kann es
  (`Bericht.swift:523`) und begründet es selbst: „eine Seite mit 61 Prozent Datenabdeckung
  sieht aus wie eine mit hundert" (`Bericht.swift:516-522`); die Vorlage setzt die Zeile
  ausdrücklich in das `summary` (`ReportShell.tsx:166-168`).

  [spuerbar] Drei der sechs Farben des Tagesverlaufs stimmen nicht, und zwei Linien sind
  nicht gestrichelt. App (`Waermebilder.swift:47-49, 62-63, 77-83`): Entnahme `Farbe.mist`
  (#7FA3B3), Pufferinhalt `Farbe.puffer` (#8FBF6B), Verlust durchgezogen, Ofen (Raum) als
  Fläche. Vorlage (`charts.ts:881-883`): Entnahme `C.house` **#cfd8dc**, Pufferinhalt
  `C.mist` **#7fa3b3** mit Flächendeckung 0,14, Verlust **gestrichelt**, Ofen (Raum)
  gestrichelt - samt gestrichelten Legendenzeichen (`charts.ts:844, 846`). Die App verletzt
  damit ihre eigene Regel: `Farbe.mist` ist dieselbe Marke wie `Farbe.netzBezug`
  (`Marken.swift:20, 90`), und `Marken.swift:107-108` schreibt vor: „der Abstand zu `alarm`
  und `netzBezug` ist nur ΔE 9,3: Ofen und Netzbezug dürfen nicht ohne Zweitkodierung in
  dieselbe Grafik." Genau das passiert hier - Ofenflächen und eine durchgezogene
  Netzbezugs-farbene Entnahmelinie in einem Bild.

  [spuerbar] „Wärme im Zeitraum" ist eine nackte `Tabelle` statt des `Spannenstreifen`, den
  es für genau diese Karte schon gibt. `WaermeSeite.swift:194-196, 326-334` gegen
  `Bausteine/Spannenstreifen.swift:19-167`, dessen eigener Kopfkommentar `HeatOverview`
  namentlich nennt (`Spannenstreifen.swift:6-12`). Es fehlen damit alle drei Dinge, die der
  Baustein mitbringt: der Hinweis „jeweils bis jetzt" / „jeweils bis 10.11.2026" im
  Kartenkopf (`Spannenworte.bis`, `Zustand/Wallbox.swift:315-319`), die Tagesspalte, die nur
  „Heute" heißt, wenn sie es ist (`Spannenworte.kopf`, ebd. `:308-312`) - in der App heißt sie
  immer „Tag" (`Formate/Zeitraum.swift:17`) - und die führende erste Zeile
  (`Spannenstreifen.swift:76-89`, Vorlage `PeriodStrip.tsx:84`). Sechs andere Seiten der App
  benutzen ihn (`KostenSeite.swift:95`, `GeldSeiten.swift:81`, `StromSeite.swift:77, 237`,
  `SpeicherSeite.swift:232`, `WallboxSeite.swift:78`).

  [spuerbar] Die drei `report-row`-Gruppen der Vorlage fehlen; am iPad stehen zehn Karten
  einspaltig untereinander. Vorlage: `7fr 5fr` für Puffer + Herkunft
  (`HeatOverview.tsx:194`), `1fr 1fr 1fr` für Kosten + Taktung + Verschieben (`:213`),
  `5fr 7fr` für Ofen + Fenster (`:277`), jeweils `globals.css:108`, am Telefon eine Spalte
  (`globals.css:350`). Der Baustein dafür ist da und begründet
  (`Bausteine/Spaltenreihe.swift:17-58`), vier Seiten benutzen ihn
  (`KostenSeite.swift:140`, `RechnungenSeite.swift:106, 141, 145, 290`,
  `SpeicherSeite.swift:139, 200`).

  [spuerbar] Taktung und Pelletofen stehen in der Vorlage zweispaltig, in der App
  einspaltig: `grid-cols-2 gap-x-4` für die sechs Taktzeilen (`HeatOverview.tsx:234`) und die
  neun Ofenzeilen (`:282`) gegen `VStack(spacing: 0)` in `WaermeSeite.swift:140-144, 271-275`.
  Neun Zeilen untereinander in einer Drittelkarte sind die halbe Kartenhöhe der Vorlage.

  [spuerbar] Die Fenstertabelle ignoriert die Handy-Fassung, die `handy.css` für genau sie
  vorschreibt. App: `Tabelle` mit Spaltenumschalter, drei Spalten
  (`WaermeSeite.swift:302-316`, `Bericht.swift:260-306`) - am Telefon sieht man also eine
  Spalte und schaltet um. Vorlage: `.fenster-tabelle` wird ein Block je Raum, mit Raumname
  und Wärme in der ersten Zeile und den beiden Dauern darunter, deren Spaltennamen als
  `::after` an der Zelle hängen („ offen", „ davon geheizt") - `handy.css:305-306, 340-347`.
  Am iPad fehlt zudem die vierte Spalte „Raum" als Kopf (die App nutzt Zeilennamen,
  gleichwertig) und die Einheit „kWh" steht in jeder Zelle - das ist hier richtig, die
  Vorlage macht es auch (`HeatOverview.tsx:334`).

  [spuerbar] Die zwei Verweise der Verschiebekarte und der Verweis „Annahmen" im
  Methodentext fehlen. Vorlage: „Rechnung und Annahmen ›" auf `/geld?period=…&anchor=…` und,
  nur je Tag, „Fahrplan gegen Wirklichkeit ›" auf `/waerme/nachbetrachtung?day=…`
  (`HeatOverview.tsx:263-272`), dazu „Annahmen" auf `/waerme/annahmen`
  (`:374-376`). Gesucht nach `wegweiser`, `gehe(`, `weg:` und „Annahmen" in
  `WaermeSeite.swift`: kein Treffer. Der Weg dafür ist in der App beschritten
  (`StromSeite.swift:263-273`, mit der Begründung, warum der Verweis in der Seite und nicht
  im Kopf steht; `Kacheldaten.weg`, `Karte.swift:129`).

  [spuerbar] Kein Nachladen. Die Vorlage holt alle drei Berichte **und** die vier Spannen
  alle fünf Minuten neu (`useReport.ts:7, 39, 70`); `Berichtsseite` lädt nur bei Wechsel des
  Zeitraums (`Bericht.swift:49`). An einer Wandanzeige steht die Seite damit beliebig lange
  auf dem Stand des Seitenaufrufs. Der Weg ist im Projekt gewählt:
  `SystemSeiten.swift:567-573` und `Bausteine/Ambiente.swift:520-531`
  (`while !Task.isCancelled { … Task.sleep(for: .seconds(300)) }`).

  [spuerbar] Ein Fehlschlag einer der beiden Hauptabfragen räumt die ganze Seite.
  `WaermeSeite.swift:50-52` setzt `try await bilanz` und `try await strom` in denselben
  Rückgabewert, `Berichtsseite` fängt das und zeigt nur noch `Stoerung`
  (`Bericht.swift:36-38, 57-61`). Die Vorlage hält drei getrennte Zustände
  (`HeatOverview.tsx:92-94`) und zeigt das Fehlerband **nur für die Bilanz** (`:138`):
  fällt `/energy/heat` aus, stehen Kacheln, Tagesverlauf, Kosten und Spannenvergleich weiter.
  Für die vier Spannen macht die App es schon richtig (`WaermeSeite.swift:59-74`).

  [spuerbar] Töne, die die Vorlage nicht setzt. Vier der sechs Kacheln tragen eine Farbe
  (`Waermeuebersicht.swift:67, 75, 83, 90`: `.glut`, `.nebel`, `.bernstein`, `.bernstein`),
  und drei Kernzahlen ebenfalls (`Waermeuebersicht.swift:104`, `WaermeSeite.swift:156, 270`).
  In der Vorlage hat **kein** `Stat` der Seite ein `tone` (`HeatOverview.tsx:141-165`, also
  `var(--text-1)`, `Stat.tsx:34`), und die `Kernzahl` ist mit Kommentar in Textfarbe
  festgelegt (`HeatOverview.tsx:78`: „Schrift in Textfarbe, wie überall", umgesetzt `:82`).
  Nebeneinander ist das der auffälligste Unterschied der Kopfzeile.

  [spuerbar] Eine Karte und zwei Methodensätze zu viel. „Bilanz des Puffers"
  (`WaermeSeite.swift:190-192, 341-363`, sechs Zeilen bis „nicht erklärt" in
  `Farbe.achtung`) und die Sätze aus `bufferBalance.noteDe` und `priceQuality.noteDe`
  (`WaermeSeite.swift:202-204`) haben in der Vorlage kein Gegenstück: `buffer_balance`,
  `price_quality` und `model_note_de` kommen in ganz `apps/web/src` nur in
  `lib/api/types.ts:4519-4523` vor, in keiner Komponente. Entweder bleibt die Karte als
  bewusste Zugabe stehen - dann gehört die Begründung in den Kopf der Seite, wie bei den
  übrigen Abweichungen - oder sie fällt weg. Entschieden ist es nirgends.

  [klein] Kachelfeld mit zwei Spalten statt bis zu sechs. `WaermeSeite.swift:79-83` lässt
  `spalten` auf dem Vorgabewert 2 (`Karte.swift:279`); die Vorlage setzt `cols=6`
  (`HeatOverview.tsx:140`) und bekommt am breiten iPad eine Reihe
  (`globals.css:107`: Mindestbreite 150 px). Andere Seiten setzen den Wert
  (`FahrplanSeiten.swift:75-77`: `spalten: 4`, mit Begründung; `:162`: `spalten: 3`).

  [klein] Der rechte Platz der Kernzahl ist nicht die Vorlage. Vorlage: mono, 11 px,
  `uppercase`, Laufweite 0,08 em, am rechten Rand (`HeatOverview.tsx:84`); App:
  `Schrift.winzig` in Sans ohne Versalien (`WaermeSeite.swift:225`). Betrifft das
  Taktungsurteil und die Fensterzeile.

  [klein] Die Diagramme sind flacher als die Vorlage. Tagesverlauf 190 + 90 pt
  (`Waermebilder.swift:68, 90`) gegen 380 px in einer Karte mit `minHeight 320`
  (`HeatOverview.tsx:171, 174`); Pufferbild 170 + 80 pt (`Waermebilder.swift:247, 277`)
  gegen eine Karte von 360 (`HeatOverview.tsx:198`); Balkenbild 180 pt
  (`Bericht.swift:81`) gegen 260 px (`HeatOverview.tsx:185`) und die Herkunftskarte
  gegen 300 (`:205`).

  [klein] Fehlt `cycling.verdict`, zeigt die App nichts; die Vorlage schreibt „zu wenig
  Daten". `WaermeSeite.swift:137` nimmt `verdict?.wort`, `HeatOverview.tsx:232` fällt auf
  `TAKTUNG.unknown` zurück. Die Wörter selbst stimmen (`Modelle/Woerter.swift:32-35`).

  [klein] Zwei Kacheln rechnen strenger als die Vorlage. „Wärme gesamt" und „Entnahme"
  nehmen `feld(...)` und setzen damit einen Strich, sobald `totals.minutes == 0`
  (`Waermeuebersicht.swift:25-28, 61, 92`); die Vorlage nimmt dort `kwh(...)`
  (`HeatOverview.tsx:143, 162`) und behält `feld` für die Spannentabelle (`:119-127`).

  [klein] Eine leere Ofenkarte, die die Vorlage weglässt. `WaermeSeite.swift:173-177` zeigt
  „In diesem Zeitraum hat der Ofen nicht gemeldet."; in der Vorlage fällt die Karte - und
  fehlt auch die Fensterkarte, die ganze Reihe - weg (`HeatOverview.tsx:276-278`).

  [klein] Der Methodentitel heißt anders: „Wie das gerechnet ist" (`Bericht.swift:524`)
  gegen „Wie gerechnet wird" (`ui/Methode.tsx:66`). Gehört zum Baustein, trifft aber jede
  Berichtsseite.

  [klein] Kartenkicker und Untertitel weichen im Maß ab. Vorlage `.kicker`: Mono 13 px,
  `uppercase`, Laufweite 0,13 em, `--text-kicker` = `--mist`
  (`globals.css:57-63`, `tokens.css:35`); App: Sans halbfett 10,5 pt, Laufweite 1,4
  (`Typografie.swift:61, 151-160`). Und der Untertitel steht am iPad **unter** dem Kicker in
  `Schrift.karte`/`text1` (`Karte.swift:63-76`), in der Vorlage rechts in 12 px `text-3`
  (`ui/Card.tsx:20-29`) - betrifft hier sechs Karten („Tagesverlauf", „Pufferspeicher",
  „Taktung", „Verschieben", „Pelletofen", „Bei offenem Fenster").

  [klein] Die Flächen des Tagesverlaufs sind viel dichter: 0,85 / 0,8 / 0,45
  (`Waermebilder.swift:59-61`) gegen 0,24 und 0,28 der Vorlage (`charts.ts:876-877`), und
  die Vorlage legt über jede Fläche eine 1-px-Linie in der Vollfarbe (`charts.ts:796-807`).

  [klein] Keine Ankerziele. Die Vorlage gibt der Pufferkarte `id="puffer"`
  (`HeatOverview.tsx:198`) und der Ofenkarte `id="ofen"` (`:279`); das Anlagenschema
  verweist auf `/waerme#puffer` und `/waerme#ofen` (`ABGLEICH.md:645`). Gesucht nach „#puffer"
  und „#ofen" in `apps/ios/DuckCurveHome`: kein Treffer - es gibt in der App kein Ziel, auf
  das ein solcher Verweis springen könnte.

KERN: SCHON DA (nachgesehen, nicht geraten)

* Abfragen: `Api.waermebilanz(_:anker:)` → `HeatBalanceOut` auf `/energy/waermebilanz`
  (`DuckCurveKit/Netz/Api.swift:192-194`), `Api.energieWaerme` → `HeatReportOut`
  (`:188`), `Api.energieVerschiebung` → `ShiftReportOut` (`:184`).
* Modelle: `HeatBalanceOut` mit `totals`, `cost`, `params`, `ventilation`, `series`,
  `buckets`, `resolutionDe`, `noteDe`; `HeatReportOut` mit `summary`, `cycling`, `stove`,
  `bufferSeries`, `bufferBalance`, `priceQuality`, `modelNoteDe`; `VentilationOut`
  (`Modelle/Schema.swift:9695-9725`), `CyclingStats` mit `verdict:
  CyclingStatsVerdictWahl?` (`Schema.swift:2720`), `StoveOut`, `HeatParamsOut`,
  `EnergyMetaOut`.
* Rechnungen: `Waermeuebersicht` komplett (`Zustand/Waermeuebersicht.swift:17-398`):
  `kacheln` (`:42-96`), `kostenkernzahl`/`kostenzeilen` (`:101-127`), `schieben` samt
  Bedeutungssatz (`:131-168`), `taktkopf`/`taktzeilen` (`:174-197`),
  `ofenkopf`/`ofenzeilen`/`ofenstufen`/`ofenbrennstoffsatz` (`:201-251`),
  `zeigtFenster`/`fensterkopf` (`:257-268`), `spannenzeilen` (`:280-301`),
  `annahmensatz` (`:310-329`), `abdeckungssatz` (`:332-343`),
  `pufferreihe`/`brennphasen` + `schichtnamen` (`:348-397`), `dauer(minuten:)` mit der
  Kurzform „3:05 h" (`:34-38`), `kwh`/`feld` (`:20-28`).
* Spannenstreifen-Wörter: `Spannenworte.kopf/bis/zifferndatum` und `Streifenzeile`
  (`Zustand/Wallbox.swift:281-332`).
* Farben: `Marken.waermepumpe` #E0966B (`Gestalt/Marken.swift:97`), `ofen` #B5651D (`:109`),
  `haus` #CFD8DC (`:115`), `mist` #7FA3B3 (`:20`), `puffer` #8FBF6B (`:128`),
  `alarm` #E0533D (`:138`), `pufferschichten` = [amber, amberWeich, mist, #2F89B5]
  (`:221-223`) - deckungsgleich mit den vier Fühlerfarben der Vorlage
  (`charts.ts:102-107`). Übersetzung in `Gestalt/Farben.swift:73-112`.
* Formate: `zahl`, `kwh`, `ct`, `euro`, `prozent` (ganzzahlig), `leer` = „-", `hhmm`
  (`Formate/Formate.swift:27, 44, 75, 98, 110, 116, 255`).
* Oberfläche: `Berichtsseite`, `Balkenbild`, `Tabelle` (mit `Handyfassung`, `engeZellen`,
  `immerSichtbar`), `Methode` (mit `kurz:`) in `Seiten/Bericht.swift:15-577`;
  `Karte`/`Kachelfeld`/`Kachel`/`Zeile`/`Leer`/`Stoerung` in `Gestalt/Karte.swift`;
  `Spannenstreifen` (`Bausteine/Spannenstreifen.swift`), `Spaltenreihe`
  (`Bausteine/Spaltenreihe.swift`), `Umbruchzeile` (`Gestalt/Umbruchzeile.swift`),
  `Waermeverlauf`/`Pufferbild` (`Diagramme/Waermebilder.swift`).
* Seitenkicker „gerechnet, nicht gemessen" liegt schon am Reiter
  (`Bereiche/Bereiche.swift:143-144`), geprüft in `Tests/.../BereicheTests.swift:172`.

ES FEHLT:

1. `Waermeuebersicht.spannenzeilen` gibt `[(wort: String, werte: [String])]` zurück
   (`Waermeuebersicht.swift:280-301`) und passt damit nicht in `Spannenstreifen`, der
   `[Streifenzeile]` nimmt (`Spannenstreifen.swift:21`). Auf `[Streifenzeile]` umstellen, wie
   es die sechs anderen Übersichten tun (`Zustand/Stromuebersicht.swift:279`,
   `Zustand/Wallbox.swift:211`) - Datei `Zustand/Waermeuebersicht.swift`, Rückgabetyp
   `[Streifenzeile]`, Töne alle `.normal` (die Vorlage setzt in `HeatOverview.tsx:118-131`
   bei keiner Zeile ein `tone`).
2. Die vier handgeschriebenen Methodenabsätze als Konstanten in den Kern, damit sie unter
   Linux geprüft werden können und nicht in der Ansicht liegen: etwa
   `public static let methodensaetze: [String]` in `Zustand/Waermeuebersicht.swift`, dazu
   ein `verlaufssatz` für Absatz 5, dem `bilanz.noteDe` angehängt wird (die Vorlage setzt
   ihn zusammen, `HeatOverview.tsx:366-369`). Vorbild für Satzkonstanten im Kern:
   `Gelduebersicht.ersparnissatz` (`Zustand/Gelduebersicht.swift:85`).
3. Ein Taktwort mit Rückfall: `public static func taktwort(_ c: CyclingStats) -> String`
   in `Zustand/Waermeuebersicht.swift`, das `c.verdict?.wort ?? "zu wenig Daten"` liefert
   (`HeatOverview.tsx:232`). Die vier Wörter selbst sind schon da
   (`Modelle/Woerter.swift:29-37`).
4. Der Stapel des Tagesverlaufs ohne die Raumwärme: `Waermebilder.Stapel` rechnet `gesamt`
   mit `raum` (`Waermebilder.swift:139-152`). Die Rechnung gehört in den Kern, wo sie
   geprüft werden kann: `public static func verlaufsstapel(_ punkte: [HeatBalancePointOut])
   -> [Verlaufspunkt]` in `Zustand/Waermeuebersicht.swift`, mit `wp`, `wpUndWasser` als
   Flächen und `raum`, `entnahme`, `verlust`, `pufferKwh` als eigene Reihen. Bestehender
   Test dafür: `Tests/DuckCurveKitTests/WaermeuebersichtTests.swift`.
5. Nichts weiter. Alle Felder, Endpunkte, Farben und Formate dieser Seite liegen im Kern;
   gesucht nach `buffer_kwh`/`bufferKwh`, `draw_kw`/`drawKw`, `loss_kw`/`lossKw`,
   `stove_room_kw`/`stoveRoomKw` in `Modelle/Schema.swift`: alle vorhanden.

BAUPLAN:

In der Reihenfolge der Vorlage, Karte für Karte.

1. `Zustand/Waermeuebersicht.swift` (Kern): `spannenzeilen` auf `[Streifenzeile]`;
   `methodensaetze` und `verlaufssatz`; `taktwort`; `verlaufsstapel`. Dazu die vorhandenen
   Tests in `Tests/DuckCurveKitTests/WaermeuebersichtTests.swift` erweitern.
2. `Zustand/Waermeuebersicht.swift:59-95`: die vier `ton:`-Angaben der Kacheln entfernen
   (Vorlage setzt keine), `feld` in den Kacheln „Wärme gesamt" und „Entnahme" durch `kwh`
   ersetzen; `kostenkernzahl` auf `.normal`.
3. `Seiten/Energie/WaermeSeite.swift:43-53`: `bilanz` und `strom` entkoppeln -
   `Waermedaten` nimmt `bilanz: HeatBalanceOut?`, `strom: HeatReportOut?` und einen
   Fehlertext für die Bilanz; alternativ je Abruf `try?` und das Band nur für die fehlende
   Bilanz. Dazu das Nachladen im Fünf-Minuten-Takt, am besten im Gerippe
   (`Seiten/Bericht.swift:49-63`, Muster `SystemSeiten.swift:567-573`), damit es alle
   dreizehn Berichtsseiten bekommen.
4. `WaermeSeite.swift:79-83`: `Kachelfeld(..., spalten: 3)` oder 6 - entschieden nach dem,
   was am iPad noch lesbar ist; Vorlage ist eine Reihe (`globals.css:107`).
5. `Diagramme/Waermebilder.swift:42-152` (das Hauptstück): „Ofen (Raum)" aus dem Stapel
   nehmen und als gestrichelte `LineMark` in `Farbe.ofen` zeichnen; Entnahme auf
   `Farbe.haus` und 2 pt; Verlust gestrichelt in `Farbe.alarm`; Pufferinhalt auf
   `Farbe.mist` mit Flächendeckung 0,14; Flächendeckungen auf 0,24 (Wärmepumpe) und 0,28
   (Ofen Wasser) und je eine 1-pt-Linie in der Vollfarbe darüber; die Legendenstücke
   `Waermebilder.swift:42-51` entsprechend auf Linien-/Flächenform und die zwei
   gestrichelten Zeichen bringen. Höhe auf 300 + 90 pt.
6. `WaermeSeite.swift:87-98`: Untertitel `resolutionDe` als `beiwerk:` statt `titel:`, damit
   er am iPad rechts und leiser steht (`Karte.swift:79-81`); Pufferkarte und
   Herkunftskarte in `Spaltenreihe(anteile: [7, 5])` - mit dem Zweig „nur Herkunft", wo
   keine Pufferreihe da ist (`HeatOverview.tsx:194-204`).
7. `WaermeSeite.swift:117-167`: die drei Karten Kosten / Taktung / Verschieben in
   `Spaltenreihe(anteile: [1, 1, 1])`; Taktzeilen und Ofenzeilen zweispaltig (ein
   `Spaltenreihe` oder zwei `VStack` in einem `HStack`); der rechte Platz der Kernzahl in
   Mono, 11 pt, Versalien, Laufweite 0,08 em; in der Verschiebekarte unten die zwei
   Verweise nach dem Muster `StromSeite.swift:263-273`, der zweite nur bei `tag`,
   beide mit Zeitraum und Anker aus dem `Zeitraum` des Gerippes.
8. `WaermeSeite.swift:169-188`: Ofenkarte und Fensterkarte in
   `Spaltenreihe(anteile: [5, 7])`, die ganze Reihe nur wenn eins von beiden etwas zeigt;
   die leere Ofenkarte entfernen. Die Fenstertabelle als eigener kleiner Baustein nach
   `handy.css:340-347`: Raumname und Wärme in der ersten Zeile, darunter „N min offen" und
   „M min davon geheizt" in `Schrift.winzig`/`Farbe.text3` - am iPad bleibt `Tabelle`.
9. `WaermeSeite.swift:190-192`: über „Bilanz des Puffers" entscheiden. Bleibt sie, einen
   Absatz in den Kopfkommentar der Seite, der sagt, warum die App hier mehr zeigt als die
   Vorlage (so hält es die Datei bei den anderen Abweichungen, `WaermeSeite.swift:21-40`).
10. `WaermeSeite.swift:194-196`: `Spannenstreifen(titel: "Wärme im Zeitraum",
    zeilen: Waermeuebersicht.spannenzeilen(d.jeSpanne), anker: z.anker, jetzt: haus.jetzt)`
    - dafür muss `inhalt(_:)` den Zeitraum kennen (heute nimmt es nur `Waermedaten`,
    `WaermeSeite.swift:54-56, 76`); Muster `StromSeite.swift:77`.
11. `WaermeSeite.swift:198-208`: `Methode(saetze, kurz:
    Waermeuebersicht.abdeckungssatz(d.strom.summary.meta))`, `abdeckungssatz` aus der
    Satzliste nehmen, die vier Absätze aus Schritt 1 einsetzen, `verlaufssatz` + `noteDe`
    zusammenziehen; die beiden Sätze ohne Vorbild (`bufferBalance.noteDe`,
    `priceQuality.noteDe`) mit der Entscheidung aus Schritt 9 behandeln.
12. Zum Schluss `Seiten/Bericht.swift:524`: Titel auf „Wie gerechnet wird" - eine Zeile,
    aber sie trifft dreizehn Seiten, also eigener Schritt.

WAS SCHWIERIG WIRD:

* **Zoom und Schieberegler im Tagesverlauf** (`charts.ts:857-860`: `dataZoom` innen und als
  Leiste) hat Swift Charts nicht als fertiges Stück. Der im Projekt gewählte Weg ist, darauf
  zu verzichten und stattdessen den Finger lesen zu lassen: `chartXSelection`
  (`Diagramme/Fahrplanzeichnung.swift:152`, `Diagramme/Betriebskurven.swift:119, 225, 332,
  440`) oder `chartOverlay` mit eigener Trefferrechnung
  (`Diagramme/Tageskurve.swift:204, 287`). Für diese Seite ist `chartXSelection` das
  Vorbild: eine Auskunftszeile über dem Bild mit Uhrzeit und den sechs Werten ersetzt den
  Hinweiskasten der Vorlage (`charts.ts:813-826`, Einheit kWh nur beim Pufferinhalt).
* **Abschaltbare Legende.** Die Vorlage lässt jede Reihe per Klick aus dem Bild nehmen
  (`charts.ts:833`, `inactiveColor`). Die App zeichnet Legenden von Hand als
  `Umbruchzeile` aus `Legendenstueck` (`Waermebilder.swift:28-37, 196-205`); kein
  Vorbild im Projekt schaltet eine Reihe ab. Vorschlag: nicht nachbauen, und das als
  bewusste Auslassung in den Kopfkommentar schreiben - acht Flächen hat `/waerme/fahrplan`
  auch ohne Abschalten gelöst (`Diagramme/Fahrplanzeichnung.swift`).
* **Zwei Flächen an einer Zeitachse mit gemeinsamem Zeiger** (`charts.ts:855-856`,
  `zweiFlaechen`): in SwiftUI sind das zwei `Chart`-Ansichten untereinander
  (`Waermebilder.swift:25-27`, `184-195`), deren linke Achsenbreite nicht automatisch
  gleich wird. Beide Bilder stehen heute schon so; bei einer gemeinsamen Auskunftszeile muss
  die Auswahl beide Charts speisen, und die y-Achsenbeschriftungen brauchen eine feste
  Breite, sonst stehen die Zeitachsen nicht übereinander - dieselbe Not, die die Vorlage mit
  `outerBoundsMode: "none"` löst (`charts.ts:29-30, 35-36`).
* **Spaltenbreiten** gibt SwiftUI nicht her; `Spaltenreihe` ist das eigene `Layout`
  dafür und begründet, warum `HStack`, `Grid` und `containerRelativeFrame` ausfallen
  (`Bausteine/Spaltenreihe.swift:5-16`). Für `7fr 5fr` mit nur einem Kind (kein Puffer)
  gilt: dann gar keine Reihe, sondern die Karte allein - sonst ist sie 7/12 breit.
* **Die ::after-Wörter der Fenstertabelle** (`handy.css:346-347`) sind in CSS eine
  Erzeugung des Browsers; in SwiftUI gehören sie in den Text der Zelle („45 min offen",
  „20 min davon geheizt"). Vorbild für eine Tabelle, die am Telefon eine andere Gestalt
  annimmt und nicht dieselbe in einer Spalte: `Tabelle.Handyfassung`
  (`Seiten/Bericht.swift:181-212`) und `Bausteine/Abrechnungstabelle.swift:32-34`.
* **Die halbdurchsichtige Ofenfarbe** `rgba(181,101,29,.55)` für „Ofen (Raum)" im
  Balkenbild: die App hat das schon mit `Farbe.ofen.opacity(0.55)` gelöst
  (`WaermeSeite.swift:243`) - gegen eine Kartenfläche ist das nicht dasselbe wie eine
  Mischung gegen `--surface-2`, aber es ist der Weg, den das Projekt gewählt hat.
