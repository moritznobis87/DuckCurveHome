========================= messen:waerme-bilanz   Aufwand: klein

VORBEMERKUNG, ohne die der Rest nicht zu lesen ist:
Die Vorlage hat diese Seite abgeschafft. `apps/web/src/app/waerme/bilanz/page.tsx` ist seit dem
10.11.2026 vollständig eine Weiterleitung und zeichnet nichts:

    apps/web/src/app/waerme/bilanz/page.tsx:1-15
      import { redirect } from "next/navigation";
      /** Die Bilanz ist in der Wärmeübersicht aufgegangen (10.11.2026). Die Adresse bleibt als
        * Weiterleitung, damit ein Lesezeichen und ein Verweis von außen nicht ins Leere führen;
        * der Zeitraum in der Adresse reist mit. */
      redirect(s ? `/waerme?${s}` : "/waerme");

Es ist die einzige Weiterleitungsseite der ganzen Web-App (gesucht nach `redirect(` in allen
`apps/web/src/app/**/page.tsx`: nur dieser eine Treffer). Die Adresse steht in keinem Reiter mehr
(`apps/web/src/lib/areas.ts:68,88-128` listet `/waerme`, `/waerme/anlage` … aber kein
`/waerme/bilanz`), wohl aber noch als Ziel eines Verweises (`apps/web/src/app/waerme/annahmen/page.tsx:23`)
und als Ziel der alten Geräteadresse (`apps/web/next.config.ts:25`: `/waermebilanz` → `/waerme/bilanz`,
`permanent: true`).

Die Messung ist deshalb nicht „welche Karte fehlt", sondern „diese Seite darf es nicht geben".

---

IST: Was die App-Seite heute von oben nach unten zeigt

Weg → Seite: `apps/ios/DuckCurveHome/App/Seitenwahl.swift:82-83` (`case "/waerme/bilanz": return AnyView(WaermebilanzSeite())`).
Die Seite: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift:353-442`.

  1. Gerippe `Berichtsseite` (`Seiten/Bericht.swift:15-64`), eine Abfrage:
     `api.waermebilanz(z.spanne.rawValue, anker: z.anker)` (`WaermeSeite.swift:356-358`;
     `GET /energy/waermebilanz`, `DuckCurveKit/Netz/Api.swift:192-194`).
  2. `Kachelfeld(kicker: "Wärmebilanz")` mit vier bis sechs Kacheln (`WaermeSeite.swift:359`,
     gebaut in `417-437`):
       * „Wärme gesamt" = Summe `heatPumpKwh` **über die Buckets** (420), Farbe `Farbe.waermepumpe`
       * „entnommen" = Summe `drawKwh` (423)
       * „Verlust" = Summe `lossKwh`, darunter „davon nutzbar: …" aus `lossUsefulKwh` (424-427)
       * „Strom" = Summe `electricKwh` (428)
       * „erwartet, 24 h" aus `forecastHeatKwh`, nur wenn vorhanden (430-434)
       * „Auflösung" = `resolutionDe` als Text (435)
     Summiert wird mit `?? 0` je Bucket (`439-441`).
  3. Karte „Woher die Wärme kam", gestapelte Balken je Bucket (361-376): Wärmepumpe
     (`Farbe.waermepumpe` = `0xE0966B`, `DuckCurveKit/Gestalt/Marken.swift:58`), „Ofen ins Wasser"
     (`Farbe.ofen` = `0xB5651D`, Marken.swift:70), „Ofen in den Raum" (`Farbe.amberWeich` =
     `0xFFD778`, Marken.swift:19).
  4. Karte „Wohin sie ging", gestapelte Balken (377-388): „entnommen" (`Farbe.mist` = `0x7FA3B3`,
     Marken.swift:20), „Verlust" (`Farbe.alarm` = `0xE0533D`, Marken.swift:99).
  5. Karte „Die Zahlen", `Tabelle` mit vier Spalten je Bucket (389-411): Wärmepumpe, Strom,
     Arbeitszahl (2 Stellen), Verlust.
  6. `Methode([b.noteDe, b.forecastNoteDe, b.params.roomSourceDe])` (413).

  2 bis 5 stehen nur, wenn `!b.buckets.isEmpty` (360); ist die Liste leer, bleibt nach dem
  Kachelfeld nur die Methodenkarte.

---

VORLAGE:

  * **Die Seite selbst: eine Weiterleitung, kein Inhalt**  (`apps/web/src/app/waerme/bilanz/page.tsx:1-15`)
    Serverseitig, `export default async function Page({ searchParams })`. Alle Fragezeichen-Paare
    werden eingesammelt (10-12) und angehängt: `redirect(s ? "/waerme?" + s : "/waerme")` (14).
    Kein Maß, keine Farbe, keine Schrift - die Seite zeichnet nichts und hat keine Zustände
    (leer/lädt/Fehler) zu zeigen.
    Die Begründung steht wörtlich im Kopfkommentar (3-7): „Die Bilanz ist in der Wärmeübersicht
    aufgegangen (10.11.2026). Die Adresse bleibt als Weiterleitung, damit ein Lesezeichen und ein
    Verweis von außen nicht ins Leere führen; der Zeitraum in der Adresse reist mit."
    DATEN: keine. Keine Abfrage, kein Feld.

  * **Warum sie abgeschafft wurde - die Begründung, die beim Umbau nicht verloren gehen darf**
    (`apps/web/src/components/reports/HeatOverview.tsx:19-23`, wörtlich):
    „**Eine Seite statt zweier.** Bis zum 10.11.2026 gab es „Erzeuger" und „Bilanz" nebeneinander,
    und sie nannten für denselben Tag verschiedene Zahlen: 24,5 kWh Wärme und Arbeitszahl 2,90 auf
    der einen, 20,4 kWh und 2,41 auf der anderen, dazu 9,2 gegen 11,1 Cent je Kilowattstunde. Beide
    Seiten rechneten, keine maß; die eine nahm die Kennlinie roh, die andere rechnete sie auf den
    wirklichen Vorlauf um. Zwei Wahrheiten für dieselbe Größe sind keine."
    Und `HeatOverview.tsx:25-28`: „**Die Wärme kommt aus der Bilanz, und nur von dort.** Wärmemenge,
    Arbeitszahl und Wärmepreis stehen auf dieser Seite genau einmal und stammen aus
    `GET /energy/waermebilanz`: der feineren der beiden Rechnungen."
    Und `HeatOverview.tsx:30-32`: „**Was hier nicht mehr steht.** Der Wärmebedarf der kommenden
    Stunden gehört zum Fahrplan und steht dort. … Die Annahmen der Rechnung haben einen eigenen
    Reiter."

  * **Das Ziel der Weiterleitung: `/waerme`**  (`apps/web/src/app/waerme/page.tsx:1-7` →
    `apps/web/src/components/reports/HeatOverview.tsx:89-382`)
    Zwölf Blöcke in dieser Reihenfolge, mit den Maßen aus den Stilen:
      - `ReportShell title="Wärme" kicker="gerechnet, nicht gemessen"` (137)
      - `ErrorBanner` nur bei Fehler der Bilanzabfrage (138; `ReportShell.tsx:147-153`)
      - `KpiGrid cols={6}` mit sechs `Stat` (140-166): Wärme gesamt, Strom Wärmepumpe, Arbeitszahl,
        Bezahlt, Wärmepreis, Entnahme. Kachelmaße: `Stat.tsx:36-45` - `padding: "14px 18px"`,
        `gap: 6`, Kicker `11px` (`globals.css:57-64`: Mono, `letter-spacing: .13em`, `uppercase`,
        `--text-kicker` = `--mist`), Zahl `26px` `leading-none` `tracking-[-.02em]`, Einheit `13px`
        in `--text-3` und Sans, Kontextzeile `12px`/`1.35` zweizeilig geklammert (`line-clamp-2`).
      - Tagesverlauf (`tag`): `Card padding 16 minHeight 320`, Diagrammhöhe `380px`,
        `heatBalanceChart(bilanz.series)` (171-180). Leerzustand wörtlich: „Für diesen Tag liegen
        keine Minutenwerte vor." (178)
      - sonst „Wärme je Tag" / bei Jahr „Wärme je Monat", `260px`, `stackedBars(..., ERZEUGER)`
        (182-191), Leerzustand „Für diesen Zeitraum liegen keine Werte vor." (189)
      - `report-row` mit Pufferspeicher (nur Tag, nur wenn `buffer_series` nicht leer; `height: 360`)
        und „Strom der Wärmepumpe nach Herkunft" (`height: 300`) (194-211)
      - `report-row --cols "1fr 1fr 1fr"`: „Was die Wärme gekostet hat", „Taktung", „Hat sich das
        Verschieben gelohnt?" (213-274), je `padding: "14px 18px"`, `gap: 10`
      - `report-row --cols "5fr 7fr"`: „Pelletofen" und „Bei offenem Fenster" (276-344)
      - `PeriodStrip title="Wärme im Zeitraum"` mit zwölf Zeilen (118-131, 346)
      - `CoverageNote` mit sechs `MethodeAbsatz` (348-379)
    DATEN: `api.heatBalance` (`lib/api/client.ts:72`, `GET /energy/waermebilanz?period=&anchor=`),
    `api.energyHeat`, `api.energyShift`, und derselbe Bilanz-Lader vier Mal über
    `useMultiPeriod` (91-95).
    **Diesen Block messe ich hier nicht aus** - er ist der Gegenstand der Messung `/waerme`, und
    `apps/ios/ABGLEICH.md:26-29` führt ihn als „`/waerme` · 14 von 14 Punkten (17.11.)". Für diese
    Messung zählt nur: wohin die Adresse führen muss und dass dort nichts von der Bilanzseite fehlt
    (siehe „WAS BEIM LÖSCHEN NICHT VERLOREN GEHT").

  * **Die alte Geräteadresse davor**  (`apps/web/next.config.ts:13-32`)
    Kommentar wörtlich (13-14): „Die alten Adressen, eine je Geraet, fuehren auf die neuen Bereiche.
    Lesezeichen und der Verlauf des Wand-iPads bleiben gueltig; die Abfrage (?period=&anchor=) reist
    mit." Eintrag `["/waermebilanz", "/waerme/bilanz"]` (25), `permanent: true` (31). Die Vorlage
    läuft also zweistufig: `/waermebilanz` → `/waerme/bilanz` → `/waerme`.

  * **Der einzige Verweis, der die Adresse noch benutzt**  (`apps/web/src/app/waerme/annahmen/page.tsx:22-26`)
    „Ob die Zahlen stimmen, steht auf der [Wärmebilanz](/waerme/bilanz): dort gibt es die Zeile
    „nicht zuzuordnen". Was die Erzeuger nicht erklären, landet in ihr, und sie klein zu bekommen ist
    genau der Sinn dieser Felder." Schrift `14px`/`1.6` in `--text-3`, der Verweis in `text-amber`.
    Die genannte Zeile „nicht zuzuordnen · kWh" steht heute im Spannenstreifen von `/waerme`
    (`HeatOverview.tsx:127`, Feld `residual_kwh`) - der Verweis ist also nach der Weiterleitung
    inhaltlich noch richtig.

  * **Handy-Fassung** (`apps/web/src/styles/handy.css`)
    Für `/waerme/bilanz` selbst: **nichts**. Gesucht nach `bilanz` in `handy.css`: zwei Treffer,
    `handy.css:248-249` (`.kl-bilanz-legende`, `.kl-bilanz-wozu`) - das ist die Energiebilanz der
    **Kennlinienseite** (`globals.css:914` `.kl-bilanz`), nicht die Wärmebilanz. Eine Seite, die nur
    weiterleitet, hat keine Handy-Fassung.
    Was am Handy für das **Ziel** `/waerme` gilt, und was dort schon umgesetzt ist: Karten ohne Rand
    mit `border-radius: 16px` und `padding: 16px` (`handy.css:182`), Kartenüberschrift als lesbare
    Sans `16.5px/600` statt Sperrschrift (184), Kennzahlen als **eine** Fläche mit führender Zahl in
    `48px` und dem Rest zweispaltig (`handy.css:194-207`), Tabellen als Listen (301-306),
    Fenstertabelle als Zeilenblöcke (339-347), der Spannenstreifen als Schalter plus Liste
    (288-299). Die App zieht genau diese Stellen schon nach - `Gestalt/Karte.swift:274-360`
    (Kachelfeld, zitiert `handy.css:197-207` und `:200`), `Bausteine/Spannenstreifen.swift:18,107`
    (zitiert `handy.css:291-299` und `:291-293`), `App/Seitenwahl.swift:149-151` (zitiert
    `handy.css:146-161`).

  * **Maße und Farben, die nicht im TSX stehen** (gegengelesen, weil frühere Messungen sie übergingen)
    `tokens.css:11-19` Marke (`--petrol #0f2e3d`, `--deep #082431`, `--amber #f2a900`,
    `--amber-soft #ffd778`, `--mist #7fa3b3`); `:23-35` Flächen und Text (`--surface-2 #123544`,
    `--line-1 rgba(255,255,255,.10)`, `--text-1/.92`, `--text-2/.72`, `--text-3/.48`,
    `--text-kicker: var(--mist)`); `:45` `--heat-pump #e0966b`; `:56` `--stove #b5651d` samt der
    beiden Auflagen im Kommentar (`:52-55`: Kontrast 2,99:1, „die Farbe darf deshalb nie allein
    tragen, es gehört immer eine sichtbare Beschriftung daneben"; ΔE 9,3 zu `--alert` und
    `--grid-in`, „Ofen und Netzbezug dürfen nicht ohne Zweitkodierung in dieselbe Grafik");
    `:64` `--alert #e0533d`; `:92-94` `--radius-1/2/3` = 2/3/6px.
    `globals.css:57-64` Kicker (Mono, `13px`, `letter-spacing .13em`, `uppercase`, `--text-kicker`);
    `:65` `.mono` (`font-variant-numeric: tabular-nums`); `:67-77` `.card` (`--surface-2`,
    `1px solid --line-1`, `--radius-2`, `padding: 20px`, `overflow: hidden`); `:107` `.kpi-grid`
    (`gap: 16px`, `minmax(clamp(150px, 100%/--cols - 16px, 260px), 1fr)`) mit der Begründung in
    `:103-106`: „`--cols` ist damit eine Obergrenze und keine Vorschrift"; `:108` `.report-row`
    (`gap: 16px`, `grid-template-columns: var(--cols, 1fr)`); `:726-735` Methodenkarte
    (`summary` `padding: 14px 18px`, `gap: 14px`; `.methode-kurz` `12.5px` `--text-3`;
    `.methode-absatz` `13px`/`1.55`, `max-width: 90ch`).
    Alle diese Werte liegen in der App schon vor: `DuckCurveKit/Gestalt/Marken.swift` (Farben,
    `:19,20,58,70,76,98,99`), `DuckCurveHome/Gestalt/Farben.swift:32-70`, `Gestalt/Karte.swift`
    (Karte, Kachel, Zeile, Leer), `Seiten/Bericht.swift:334-397` (Methode, zitiert
    `components/ui/Methode.tsx`).

  * **Kommentare im Vorlagencode, deren Begründung erhalten bleiben muss**
    - `bilanz/page.tsx:3-7`: die Adresse bleibt, damit Lesezeichen und äußere Verweise nicht ins
      Leere führen; der Zeitraum reist mit.
    - `HeatOverview.tsx:19-23`: zwei Seiten mit zwei Zahlen für denselben Tag - der Grund der
      Zusammenlegung, mit den konkreten Zahlen.
    - `HeatOverview.tsx:30-32`: der Ausblick gehört zum Fahrplan, die Annahmen auf ihren Reiter.
    - `HeatOverview.tsx:56`: „Null ist eine Messung, „keine Daten" ist keine. Ohne Minuten im
      Zeitraum steht ein Strich." (umgesetzt in `:57-59`, `feld()` prüft `totals.minutes === 0`)
    - `HeatOverview.tsx:116-117`: „Die Einheit steht in der Zeile und nicht in jeder Zelle …: vier
      Spalten mit „63,7 kWh" liefen am Handy ineinander."
    - `HeatOverview.tsx:168-169`: „Der Tag als Verlauf, jeder längere Zeitraum als Balken. Beides
      zugleich war dieselbe Zufuhr zweimal: einmal je Minute, einmal je Stunde."
    - `HeatOverview.tsx:195-196`: die Pufferschichtung gibt es nur je Tag, „in einer Woche wäre sie
      ein Knäuel".
    - `HeatOverview.tsx:245-247`: „Dieselbe Zahl wie auf „Geld": eine Rechnung, an zwei Stellen
      gezeigt. Vorher stand hier eine eigene Karte „Lief sie zur richtigen Zeit?" mit einer zweiten
      Antwort auf dieselbe Frage."
    - `HeatOverview.tsx:308-309` / `:44`: Karten, die jeden Tag „null" sagen, liest niemand; der
      halbtransparente Ofenton ist „derselbe Erzeuger, ein anderer Weg".
    - `charts.ts:781-784` (zu `heatBalanceChart`): „**Flächen für die Erzeuger, Linien für die
      Senken.** Gestapelt wird nur, was sich wirklich addiert … Entnahme und Verlust gehen aus ihm
      heraus und stehen deshalb als eigene Linien daneben, nicht als weitere Schicht desselben
      Stapels - sonst läse man eine Summe, die es nicht gibt." Das ist die Begründung, die der Karte
      „Wohin sie ging" der App-Seite (`WaermeSeite.swift:377-388`) direkt widerspricht: dort sind
      Entnahme und Verlust **gestapelt**.
    - `charts.ts:790-791`: Farbabstände geprüft, engstes Paar Ofen/Verlust ΔE 16,9, Projektgrenze 15.
    - `next.config.ts:13-16`: alte Adressen je Gerät; `/haus` fehlt mit Absicht.

---

LUECKEN:

  [traegt-die-seite] Die App zeigt an `/waerme/bilanz` eine eigene Seite, die es in der Vorlage
  nicht mehr gibt. Vorlage: Weiterleitung auf `/waerme`, nichts gezeichnet
  (`apps/web/src/app/waerme/bilanz/page.tsx:1-15`). App: `Seitenwahl.swift:82-83` → vier eigene
  Karten in `WaermeSeite.swift:353-442`. Die Hauptaussage der Adresse in der Vorlage ist „geh zur
  Wärmeübersicht"; die App macht sie nicht.

  [traegt-die-seite] Dadurch nennt die App für denselben Tag zwei verschiedene „Wärme gesamt" -
  genau der Fehler, den die Vorlage am 10.11.2026 behoben hat (`HeatOverview.tsx:19-23`). Auf
  `/waerme` ist es `totals.producedKwh` (`DuckCurveKit/Zustand/Waermeuebersicht.swift:61`, Feld
  `produced_kwh`, `Modelle/Schema.swift:5359`), auf `/waerme/bilanz` die Summe von `heatPumpKwh`
  über die Buckets (`WaermeSeite.swift:420` mit `439-441`). Der Ofen fehlt in der zweiten Summe
  vollständig, obwohl die Kachel „Wärme gesamt" heißt und die Seite ihn zwei Karten weiter als
  Erzeuger zeigt (`WaermeSeite.swift:367-375`).

  [spuerbar] Die Bilanzseite bricht die Regel „Null ist eine Messung, keine Daten ist keine".
  Vorlage: `HeatOverview.tsx:56-59` - ohne gemessene Minuten steht ein Strich; der Kern hat die
  Regel schon (`Waermeuebersicht.swift:19-28`, `feld()` prüft `b.totals.minutes != 0`). Die
  Bilanzseite summiert stattdessen `?? 0` über die Buckets (`WaermeSeite.swift:439-441`) und zeigt
  „0,0 kWh", wo `/waerme` „-" zeigt. Gleiches gilt für die Arbeitszahl in der Tabelle
  (`WaermeSeite.swift:401-404`, `Formate.zahl($0.copMean, stellen: 2)` ohne Minutenprüfung).

  [spuerbar] Entnahme und Verlust stehen in der App als **gestapelte** Balken („Wohin sie ging",
  `WaermeSeite.swift:377-388`). Die Vorlage verbietet genau das mit Begründung
  (`charts.ts:781-784`): Senken sind Linien, nicht eine weitere Schicht desselben Stapels, „sonst
  läse man eine Summe, die es nicht gibt". Nebeneinander gestellt ist der Unterschied sofort zu
  sehen: in der App addiert die Säule Zufuhr und Abfluss zu einer Höhe, die nichts bedeutet.

  [spuerbar] Die alte Geräteadresse `/waermebilanz` endet in der App auf „Diese Seite kennt die App
  nicht". Vorlage: `next.config.ts:25` (`/waermebilanz` → `/waerme/bilanz`, `permanent`) und dann
  `bilanz/page.tsx:14` → `/waerme`. App: `/waermebilanz` trifft keinen `case` in
  `Seitenwahl.swift:27-98` und fällt in `default` → `Unbekannt` (`Seitenwahl.swift:99-100`,
  gezeichnet in `117-134`: „Der Weg „…“ gehört zu keiner Seite dieser Fassung."). Die App führt
  überhaupt keine alten Adressen: gesucht nach `/pv`, `/batterie`, `/wallbox`, `/jahr`,
  `/waermebilanz`, `/raeume`, `/prognose`, `/daten`, `/settings` als `case` in `Seitenwahl.swift`:
  kein Treffer.

  [klein] Die App-Seite zeigt vier Felder, die die Vorlage **nirgends** zeigt; sie entfallen mit der
  Seite und dürfen nicht nach `/waerme` mitgenommen werden. `loss_useful_kwh` („davon nutzbar",
  `WaermeSeite.swift:426`), `forecast_heat_kwh` und `forecast_note_de` („erwartet, 24 h",
  `WaermeSeite.swift:430-434` und `413`), `room_source_de` (`WaermeSeite.swift:413`). Gesucht nach
  allen vier in `apps/web/src`: nur in der erzeugten Typdatei (`lib/api/types.ts:4161,4569`,
  `:4059,4064`, `:4400`), in keiner `.tsx`-Datei. Der Ausblick, den „erwartet, 24 h" meint, steht in
  der Vorlage auf dem Fahrplan und kommt dort aus `/plan`, nicht aus der Bilanz
  (`components/waerme/Fahrplan.tsx:571`: `Stat label="Wärmebedarf geplant"`, Hinweis „Modell v1,
  nicht gemessen"); die Begründung dafür in `HeatOverview.tsx:30-31`.

  [klein] Die Seite ist in der App ohnehin nicht erreichbar - das macht die Löschung billig, aber
  es heißt auch, dass hier toter Code mit falschen Zahlen im Build steht. `/waerme/bilanz` steht
  nicht in `Bereiche.alle` (gesucht nach `bilanz` in
  `DuckCurveKit/Bereiche/Bereiche.swift`: kein Treffer), also nicht in `Bereiche.alleWege`
  (`Bereiche.swift:239-249`), also kann auch keine Mitteilung dorthin springen - das Ziel wird
  gegen `alleWege` geprüft (`DuckCurveHome/Mitteilungen/Mitteilungen.swift:199`). Der einzige
  Verweis darauf im Kern, `Annahmenfelder.schlussabsatz`
  (`DuckCurveKit/Zustand/Annahmenformular.swift:433-440`, mit `.verweis(wort: "Wärmebilanz",
  weg: "/waerme/bilanz")` in `:435`), wird von `AnnahmenSeite` nicht gezeichnet: gesucht nach
  `schlussabsatz` und `Textstueck` in `apps/ios/DuckCurveHome`: kein Treffer (nur
  `DuckCurveKit/Tests/DuckCurveKitTests/AnnahmenformularTests.swift:317,321-323`). `AnnahmenSeite`
  zeichnet Formular, Werteliste und `Annahmenfelder.methodensaetze`
  (`DuckCurveHome/Seiten/Technik/SystemSeiten.swift:1039-1078`).

  Summe: 6 Punkte - 2 `traegt-die-seite`, 3 `spuerbar`, 1 `klein`. Die Arbeit ist Löschen plus ein
  Tabelleneintrag im Kern: **Aufwand klein**.

---

WAS BEIM LÖSCHEN NICHT VERLOREN GEHT (nachgesehen, Karte für Karte)

  * Kachel „Wärme gesamt" → `/waerme`, erste Kachel, aus `totals.producedKwh`, mit der Aufteilung
    „Wärmepumpe … · Ofen … kWh" darunter (`Waermeuebersicht.swift:60-67`, benutzt in
    `WaermeSeite.swift:66-70`).
  * Kachel „entnommen" → `/waerme`, Kachel „Entnahme" mit „Heizung und Warmwasser · Verlust …"
    (`Waermeuebersicht.swift:91-94`).
  * Kachel „Verlust" → als Unterzeile der Entnahme-Kachel (ebenda) und als eigene Zeile
    „Verlust · kWh" im Spannenvergleich (`Waermeuebersicht.swift:293`).
  * Kachel „Strom" → `/waerme`, Kachel „Strom Wärmepumpe" mit Sonnenanteil
    (`Waermeuebersicht.swift:68-71`), und Zeile „Strom Wärmepumpe · kWh" (`:294`).
  * Kachel „Auflösung" → `/waerme`, als Kopfzeile rechts der Tagesverlaufskarte
    (`WaermeSeite.swift:75`, `titel: d.bilanz.resolutionDe`).
  * Karte „Woher die Wärme kam" → `/waerme`, Karte „Wärme je Tag"/„Wärme je Monat" mit denselben
    drei Stücken (`WaermeSeite.swift:87-94`, `erzeuger(_:)` in `:221-233`); am Tag stattdessen der
    Minutenverlauf (`:74-77`, `Diagramme/Waermebilder.swift:14`).
  * Karte „Wohin sie ging" → `/waerme`, als Linien im Tagesverlauf und als Zeilen „Entnahme · kWh"
    und „Verlust · kWh" im Spannenvergleich (`Waermeuebersicht.swift:292-293`).
  * Karte „Die Zahlen" → `/waerme`, Spannenvergleich mit zwölf statt vier Größen
    (`Waermeuebersicht.swift:280-301`, gezeichnet `WaermeSeite.swift:181-183,313-321`), darunter
    „Arbeitszahl" (`:295`) und „nicht zuzuordnen · kWh" (`:296`) - die Zeile, auf die der
    Annahmen-Verweis zielt.
  * `Methode([noteDe, forecastNoteDe, roomSourceDe])` → `/waerme`, acht Methodensätze inklusive
    `b.noteDe` (`WaermeSeite.swift:185-195`). `forecastNoteDe` und `roomSourceDe` entfallen, wie in
    der Vorlage.

  Ergebnis: keine Zahl und kein Satz der Bilanzseite geht verloren, bis auf die vier Felder, die
  die Vorlage absichtlich nicht mehr zeigt (siehe letzte `[klein]`-Lücke).

---

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Api.waermebilanz(_:anker:) -> HeatBalanceOut` auf `GET /energy/waermebilanz` mit `period` und
    `anchor` - `DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:192-194`. Dieselbe Zusage wie
    `lib/api/client.ts:72`.
  * `HeatBalanceOut` mit `period`, `resolutionDe`, `totals`, `previous`, `series`, `buckets`,
    `cost`, `forecastHeatKwh`, `forecastNoteDe`, `params`, `ventilation`, `noteDe` -
    `Modelle/Schema.swift:4694-4761`.
  * `HeatTotals` mit `minutes`, `heatPumpKwh`, `stoveWaterKwh`, `stoveRoomKwh`, `producedKwh`,
    `drawKwh`, `lossKwh`, `lossUsefulKwh`, `bufferChangeKwh`, `residualKwh`, `electricKwh`,
    `copMean` - `Modelle/Schema.swift:5354-5502`.
  * `HeatBucketOut` - `Modelle/Schema.swift:4818`; `HeatBalancePointOut` - `:4764`;
    `HeatCostOut` - `:4959`; `HeatParamsOut` - `:5084`; `VentilationOut` - `:9695`.
  * Die ganze Rechnung der Wärmeübersicht: `DuckCurveKit/Zustand/Waermeuebersicht.swift` -
    `kacheln(bilanz:strom:)` `:42-96`, `kostenkernzahl` `:101-105`, `kostenzeilen` `:112-127`,
    `schieben` `:140-168`, `taktkopf`/`taktzeilen` `:174-197`, `ofenkopf`/`ofenzeilen`/`ofenstufen`
    `:201-251`, `zeigtFenster`/`fensterkopf` `:257-268`, `spannenzeilen` `:280-301`,
    `annahmensatz` `:310-329`, `abdeckungssatz` `:332-343`, `pufferreihe`/`brennphasen` `:362-397`.
    Dazu die Regel „Null ist eine Messung" als `kwh`/`feld` `:20-28` und `dauer(minuten:)` `:34-38`.
  * Die Wege: `Bereiche.alle` mit `/waerme` als Reiter der Energie mit Zeitraum
    (`Bereiche/Bereiche.swift:108`), `bereichVon` `:186-199`, `reiterVon` `:203-221`, `alleWege`
    `:239-249`, `saeubere` (Fragezeichenteil und Schrägstriche weg) `:258-262`,
    `spannen(fuer:)` `:179-182`.
    **Wichtig und nachgesehen:** `bereichVon("/waerme/bilanz")` trifft über `hasPrefix("/waerme/")`
    den Reiter `/waerme` (`Bereiche.swift:192`), `reiterVon` ebenso (`:213`). Die Bilanzadresse
    liegt also schon heute im Bereich Energie und am Reiter „Wärme", und `spannen(fuer:)` gibt dort
    alle vier Spannen. Der Zeitraum hängt am Bereich, nicht an der Adresse
    (`DuckCurveHome/App/Navigation.swift:22,69-81`) - eine Weiterleitung von `/waerme/bilanz` auf
    `/waerme` wechselt den Bereichsschlüssel nicht und verliert deshalb Spanne und Anker nicht.
    Das ist das Gegenstück zum „der Zeitraum in der Adresse reist mit" der Vorlage, ohne dass etwas
    mitgetragen werden muss.
  * Farben und Maße: `Gestalt/Marken.swift` (`amberWeich :19`, `mist :20`, `waermepumpe :58`,
    `ofen :70`, `haus :76`, `achtung :98`, `alarm :99`), `DuckCurveHome/Gestalt/Farben.swift:32-70`.
  * Formate: `Formate.zahl`, `Formate.kwh`, `Formate.euro`, `Formate.ct`, `Formate.prozent`,
    `Formate.leer` - `DuckCurveKit/Formate/Formate.swift`.
  * Oberfläche: `Berichtsseite` `Seiten/Bericht.swift:15-64`, `Balkenbild` `:70`, `Tabelle` `:157`,
    `Methode` `:334-397`; `Karte`/`Kacheldaten`/`Kachelfeld`/`Zeile`/`Leer`
    `Gestalt/Karte.swift:15,121,274,360,390`; `Spannenstreifen` `Bausteine/Spannenstreifen.swift:19`;
    `Waermeverlauf` und `Pufferbild` `Diagramme/Waermebilder.swift:14,184`;
    `Unbekannt` `App/Seitenwahl.swift:117-134`.

---

ES FEHLT:

  1. Eine Tabelle alter Adressen im Kern, als Gegenstück zu `apps/web/next.config.ts:18-31` und
     `apps/web/src/app/waerme/bilanz/page.tsx`. Vorschlag: in
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift` neben `alleWege`
     `public static let alteWege: [String: String]` mit den elf Paaren des `next.config.ts` plus
     dem Paar `"/waerme/bilanz": "/waerme"` aus der Weiterleitungsseite, und dazu
     `public static func ziel(_ weg: String) -> String`, die `saeubere(_:)` anwendet und einen
     Treffer in `alteWege` auflöst (höchstens zweimal, weil `/waermebilanz` in der Vorlage über
     zwei Stufen läuft). Nur Zeichenketten, kein SwiftUI - gehört damit in dieses Paket.
  2. Ein Test dazu im Kern, neben `testJederWegFindetSeinenBereich`
     (genannt in `apps/ios/DuckCurveHome/App/Seitenwahl.swift:9-11`): jedes Ziel aus `alteWege`
     liegt in `alleWege`, und keine alte Adresse ist selbst in `alleWege`. Das ist die Swift-Fassung
     von `apps/web/src/lib/areas.test.ts:48-53` („verweist nirgends auf eine alte Adresse und nennt
     keine Adresse zweimal", mit genau derselben Liste in `:49`).

  Mehr braucht der Kern nicht: alles, was die Zielseite rechnet, liegt in
  `Zustand/Waermeuebersicht.swift` (siehe oben), und die vier Felder, die nur die zu löschende
  Seite benutzt, fallen weg.

---

BAUPLAN (in der Reihenfolge der Vorlage: erst die Adresse, dann die Seite)

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift` - `alteWege` und
     `ziel(_:)` anlegen (siehe „ES FEHLT" 1). Im Dokumentationskommentar den Grund der Vorlage
     wörtlich mitnehmen (`next.config.ts:13-14` und `bilanz/page.tsx:3-7`): Lesezeichen und äußere
     Verweise sollen nicht ins Leere führen.
  2. `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests/` - den Test aus „ES FEHLT" 2 ergänzen, am
     besten neben `testJederWegFindetSeinenBereich` in
     `DuckCurveKit/Tests/DuckCurveKitTests/BereicheTests.swift:105`.
  3. `apps/ios/DuckCurveHome/App/Seitenwahl.swift` - `sauber` (`:105-109`) durch
     `Bereiche.ziel(weg)` ergänzen, damit `/waerme/bilanz` und `/waermebilanz` vor dem `switch`
     auf `/waerme` auflösen. Danach `case "/waerme/bilanz"` (`:82-83`) streichen. Der Kommentar am
     Kopf der Datei (`:8-11`) nennt den Test, der die Vollständigkeit prüft - er bleibt richtig,
     weil `/waerme/bilanz` nie in `alleWege` stand.
  4. `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift` - `struct WaermebilanzSeite`
     (`:353-442`) samt `kennzahlen(_:)` (`:417-437`) und `summe(_:_:)` (`:439-441`) löschen. Die
     Datei behält `Waermedaten` (`:14-19`) und `WaermeSeite` (`:21-351`). Nichts anderes verweist
     darauf: gesucht nach `WaermebilanzSeite` in `apps/ios`: zwei Treffer, `WaermeSeite.swift:354`
     und `Seitenwahl.swift:83`.
  5. `apps/ios/DuckCurveHome/App/Vorschauen.swift` und `DuckCurveKit/Vorschau/Vorschau.swift` -
     prüfen, ob eine Vorschau auf `/waerme/bilanz` oder `WaermebilanzSeite` zeigt (bei der Suche in
     Schritt 4 nicht aufgetaucht; wenn beim Bauen doch etwas bricht, hier nachsehen).
  6. Keine Änderung an `Annahmenfelder.schlussabsatz`
     (`DuckCurveKit/Zustand/Annahmenformular.swift:433-440`): der Weg `/waerme/bilanz` bleibt
     richtig, weil er nach Schritt 3 wie in der Vorlage auf `/waerme` auflöst, und dort steht die
     Zeile „nicht zuzuordnen · kWh" (`Zustand/Waermeuebersicht.swift:296`). Dass dieser Absatz von
     `AnnahmenSeite` noch gar nicht gezeichnet wird, ist eine Lücke der Messung `/waerme/annahmen`
     (`apps/ios/ABGLEICH.md:590` nennt sie schon) und nicht dieser hier.

---

WAS SCHWIERIG WIRD

  * **Eine Weiterleitung hat in SwiftUI kein Gegenstück.** Next.js hat `redirect()`
    (`bilanz/page.tsx:14`) und `redirects()` (`next.config.ts:17`); eine App hat nur ihren
    Wegweiser. Zwei Wege wären möglich, und das Projekt hat sich bei derselben Frage schon einmal
    entschieden: `Seitenwahl` löst den Weg **vor** dem `switch` auf, mit einer reinen Funktion über
    Zeichenketten (`App/Seitenwahl.swift:104-109`, `private var sauber`, „Fragezeichenteil und
    Schraegstriche am Ende weg - wie `Bereiche` es auch tut"), und derselbe Schritt steht im Kern
    noch einmal als `Bereiche.saeubere(_:)` (`Bereiche.swift:257-262`). Der Umbau folgt diesem
    Vorbild: eine Abbildung alter auf neue Wege, angewandt in `sauber`. Der andere Weg -
    `wegweiser.gehe("/waerme")` im `body` oder in `.onAppear` einer Umleitungsansicht - schreibt
    beobachteten Zustand während des Zeichnens; genau davor warnt `Navigation.swift:56-62`
    („Modifying state during view update": alle lesenden Ansichten werden im selben Durchlauf
    wieder ungueltig"). Also nicht so.
  * **Der Zeitraum braucht nichts.** Die Vorlage muss ihn in der Adresse mittragen
    (`bilanz/page.tsx:9-14`), weil `usePeriod` ihn aus `window.location.search` liest
    (`ReportShell.tsx:61-95`). Die App hält ihn je Bereich (`Navigation.swift:22,69-81`), und
    `/waerme/bilanz` liegt schon im selben Bereich wie `/waerme` (`Bereiche.swift:186-199` über
    `hasPrefix("/waerme/")`). Der Umbau darf deshalb **nicht** versuchen, Spanne und Anker durch
    die Adresse zu schleifen - das wäre eine zweite Quelle für dieselbe Angabe.
  * **Die alten Adressen sind eine Liste in zwei Programmen.** Sie steht in `next.config.ts:18-30`
    und in `areas.test.ts:49` doppelt, und mit dem Umbau ein drittes Mal in Swift. Das Projekt hat
    denselben Fall bei `areas.ts`/`Bereiche.swift` schon so gelöst (eine Abschrift plus ein Test,
    der sie prüft - `Seitenwahl.swift:8-11`); mehr ist hier nicht zu holen, aber der Test aus
    „ES FEHLT" 2 ist die Stelle, an der ein Auseinanderlaufen auffällt.
  * **Nach dem Löschen hat die Adresse keinen eigenen Prüfstein mehr.** Wer später prüft, ob
    `/waerme/bilanz` „stimmt", landet auf `/waerme` - und das ist beabsichtigt
    (`HeatOverview.tsx:19-23`). In `apps/ios/ABGLEICH.md` gehört dazu eine Zeile, die sagt, dass
    diese Adresse keine Seite mehr ist, damit sie nicht beim nächsten Durchgang als „fehlende
    Seite" wieder auftaucht.
