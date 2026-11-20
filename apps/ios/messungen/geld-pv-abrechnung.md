========================= messen:geld-pv-abrechnung   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
(Datei: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`, `struct PvAbrechnungSeite` ab :121)

1. **Zeitraumleiste** aus dem Gerippe (`Bericht.swift:35` → `Seitenwahl.swift:188-207`).
   Angeboten werden nur **Monat und Jahr** (`Bereiche.swift:119-121`:
   `spannen: [.monat, .jahr], nurHausherr: true`). Kein Seitenkicker, kein Verweis rechts.
2. **Ein Kachelfeld** mit Kicker „PV-Abrechnung" (`GeldSeiten.swift:129`), sechs Kacheln aus
   `kennzahlen(_:)` (`:205-226`), in dieser Reihenfolge:
   - „Umsatzsteuer zu zahlen" = `vatPayableEur`, dazu „aus Einspeisung und Eigenverbrauch" (:208-211) — führend, 48 pt (`Karte.swift:240`)
   - „erzeugt" = `pvKwh`, 1 Stelle, kWh, Farbe `Farbe.pv` (:212)
   - „eingespeist" = `exportKwh`, 1 Stelle, kWh, dazu „<brutto> brutto" (:213-216)
   - „selbst verbraucht" = `selfConsumptionKwh`, 1 Stelle, kWh, dazu „<netto> netto" (:217-220)
   - „Vergütungssatz" = `feedInCtKwh`, 2 Stellen, ct/kWh (:221-223)
   - „Eigenverbrauchsanteil" = `Formate.prozent(selfConsumptionShare)` (:224)
3. **Karte „Einspeisung"** (:130-140), vier `Zeile`n: eingespeist (kWh, 1 Stelle), netto,
   Umsatzsteuer, brutto.
4. **Karte „Eigenverbrauch"** (:141-158), fünf `Zeile`n: selbst verbraucht, davon direkt,
   davon aus dem Speicher, Wert netto, Umsatzsteuer darauf.
5. **Karte „Nach Zeitraum"** (:159-183), `Tabelle` (`Bericht.swift:157`) mit
   `zeilennamen: b.buckets.map(\.label)` und **vier** Spalten: eingespeist, Vergütung,
   Eigenverbrauch, „USt. zu zahlen". Keine Summenzeile, keine Unterzeilen in den Köpfen,
   alle Zellen in `Farbe.text1` (`Bericht.swift:314-319`), kein Filter leerer Buckets.
   Am Telefon wird eine Spalte gezeigt und mit Pillen umgeschaltet (`Bericht.swift:206-244`).
6. **`Methode`** (:184-201, Baustein `Bericht.swift:334`), **zugeklappt und ohne `kurz`**:
   Kleinunternehmer-Satz **oder** „Umsatzsteuersatz <x %>.", ein Schätz-Satz, `b.meta.methodDe`,
   „Diese Seite ist eine Rechenhilfe und keine Steuerberatung."
   Weil `kurz` fehlt (`Bericht.swift:343`, `:359`), ist im Ruhezustand **kein** Wort davon zu sehen.

Kein Diagramm auf der ganzen Seite. Kein Spannenvergleich.

VORLAGE
Einstieg `apps/web/src/app/geld/pv-abrechnung/page.tsx` (8 Zeilen, `requireOwner()`, rendert
`<PvAccounting/>`); die Seite ist `apps/web/src/components/reports/PvAccounting.tsx`.

  * **Kopf / Hülle** (`PvAccounting.tsx:80-89` → `ReportShell.tsx:97-134` → `AreaShell.tsx:13-30`)
    `title="PV-Abrechnung"`, `kicker="Einspeisung · Eigenverbrauch · Umsatzsteuer"` — der Kicker
    steht **rechts in der Reiterzeile** (`AreaShell.tsx:24`: `<AreaTabs right={kicker}>`), nicht
    über der Seite. Der Titel steht nur noch als `sr-only` (`ReportShell.tsx:99-100`,:127) —
    Begründung im Kommentar: „Der Titel steht nicht mehr im Kopf: der aktive Reiter sagt, wo man
    ist. Er bleibt im Dokumenttitel, damit ein Browserfenster und die Vorlesehilfe ihn haben."
    `right={<Link href="/strom/pv" className="text-[12px] text-amber">Erzeugung →</Link>}`
    (`PvAccounting.tsx:88`) — 12 px, `var(--amber)` = `#f2a900` (`tokens.css:13`).
    Zeitraum: **alle vier Spannen** (`ReportShell.tsx:10`, `:120-126`), Voreinstellung
    `usePeriod("year")` (`PvAccounting.tsx:54`). Begründung im Kommentar `:53`:
    „Steuerlich zählt das Kalenderjahr; die kürzeren Zeiträume sind der Blick hinein, nicht
    umgekehrt."
    Aktiver Spannenknopf: Grund `var(--amber)`, Schrift `var(--petrol)` (`ReportShell.tsx:122`).
    DATEN: `api.energyPv(period, anchor)` = `GET /energy/pv?period=&anchor=`
    (`client.ts:127`), Typ `PvTaxReport` = `PvTaxReportOut` (`models.ts:71`).
    Geladen über `useReport` (`useReport.ts:18-46`): alle 5 min neu (`:7`), und beim Wechsel
    bleibt der alte Stand stehen (Kommentar `:17`).

  * **Fehlerband** (`PvAccounting.tsx:90`, Baustein `ReportShell.tsx:147-153`)
    Mono, 12 px, `uppercase`, `letter-spacing .1em`, Rahmen `rgba(224,83,61,.4)`,
    Fläche `rgba(224,83,61,.12)`, Schrift `var(--alert)` = `#e0533d` (`tokens.css:64`).
    Text bei 401/403: „Nicht angemeldet - bitte Gerät koppeln." (`useReport.ts:11`).

  * **Sechs Kennzahlkacheln** (`PvAccounting.tsx:91-98`, `KpiGrid cols={6}`)
    Raster `globals.css:107`: `repeat(auto-fit, minmax(clamp(150px, 100%/6 - 16px, 260px), 1fr))`,
    `gap: 16px`. Kachel = `Stat.tsx:4-18`: Karte mit `padding: "14px 18px"`, `gap: 6`,
    Kicker 11 px, Zahl **mono 26 px**, `leading-none`, `tracking -.02em`; Einheit 13 px
    `var(--font-sans)` in `--text-3`; Hinweiszeile 12 px, `line-clamp-2`, `--text-3`.
    `.kicker` = mono 13 px, `letter-spacing .13em`, `uppercase`, `var(--text-kicker)` = `--mist`
    `#7fa3b3` (`globals.css:57-64`, `tokens.css:35`).
    In dieser Reihenfolge, wörtlich:
    1. „Eingespeist" `de1(export_kwh, >=100 ? 0 : 1)` kWh, `tone="mist"` (`var(--mist)`),
       Hinweis `„<feed_in_ct_kwh, 2 Stellen> ct/kWh netto"` (:92)
    2. „Vergütung netto" `eur(export_net_eur)`, Hinweis `vatOff ? "ohne Umsatzsteuer"
       : "brutto <export_gross_eur>"` (:93)
    3. „USt auf Einspeisung" `eur(export_vat_eur)`, bei Kleinunternehmer `tone="muted"`
       (= `var(--text-3)`), Hinweis „ausgezahlt, abzuführen" (:94)
    4. „Eigenverbrauch" `de1(self_consumption_kwh, >=100 ? 0 : 1)` kWh, `tone="amber"`,
       Hinweis „davon <self_battery_kwh> kWh über den Speicher" (:95)
    5. „Wert des Eigenverbrauchs" `eur(self_value_net_eur)`,
       Hinweis „netto, Ø <self_ct_kwh, 2 Stellen> ct/kWh" (:96)
    6. „Umsatzsteuer gesamt" `eur(vat_payable_eur)`, `tone = vatOff ? "muted" : "amber"`,
       Hinweis `vatOff ? "Kleinunternehmer: keine USt" : "Einspeisung + Wertabgabe"` (:97)
    `vatOff = data?.meta.small_business === true` (:58) — aus **`meta`**, nicht aus `totals`.
    `eur(n) = "<de1(n,2)> €"`, `de1` mit `toLocaleString("de-DE")` (`ReportShell.tsx:14-15`).
    Leerwert überall `"-"` (`ReportShell.tsx:14`).
    DATEN: `data.totals.*` (`PvTaxTotals`, `types.ts:5425-5505`), `data.meta.feed_in_ct_kwh`,
    `data.meta.small_business` (`types.ts:5373-5390`).

  * **Diagrammkarte „Erlös und Wertabgabe"** (`PvAccounting.tsx:100-105`)
    `<div className="report-row" style={{"--cols":"1fr"}}>` (`globals.css:108`),
    `<Card style={{padding:16, height:300}}>`.
    `CardHead title="Erlös und Wertabgabe"`,
    `right="Einspeisevergütung · Eigenverbrauch, jeweils netto"` (12 px, `--text-3`,
    `Card.tsx:20-28`).
    Zeilenbasis: `rows` = alle Buckets mit `export_kwh > 0.005 || self_consumption_kwh > 0.005`
    (`:60-63`). **Leerzustand**: `<Note>Für diesen Zeitraum liegen keine bewerteten Stunden
    vor.</Note>` (:103). `Note` = 12 px, `line-height 1.55`, `max-width 90ch`, `--text-3`
    (`ReportShell.tsx:143-145`; Kommentar `:136-142`: über die volle Breite eines 1440er
    Schirms wären es „gut 200 Zeichen je Zeile", 90 ist die Obergrenze für Lesetext).
    Bild: `moneyBars(labels, series)` (`charts.ts:367-399`), **zwei gestapelte Balkenreihen**:
      - „Einspeisevergütung netto", Farbe `C.mist` = `#7fa3b3` (`palette.ts`), Werte `export_net_eur`
      - „Eigenverbrauch (Wert netto)", Farbe `C.pv` = `#f2a900`, Werte `self_value_net_eur`
    Maße aus `moneyBars`: `grid {left:52,right:12,top:24,bottom:30}`; y-Achse Name „€",
    `splitNumber: 3`, Achsenschrift mono 11 px `rgba(255,255,255,.48)` (`charts.ts:7`);
    x-Achse Kategorien, Schrift 10 px, `interval: labels.length > 12 ? "auto" : 0`,
    `hideOverlap`; `barCategoryGap: "35%"`; nur der oberste Balken hat
    `borderRadius [2,2,0,0]`; Werte auf 2 Stellen gerundet (`:394`); `animation: false`.
    Tooltip (`:372-386`): Zeitraumname oben, je Reihe `Name — <Betrag> €` (Nullwerte raus),
    darunter Trennlinie und „Summe <Betrag> €"; Grund `C.deep` `#082431`.

  * **Karte „Aufstellung"** (`PvAccounting.tsx:107-149`)
    `<Card style={{padding:"14px 18px", gap:10}}>`,
    `CardHead title="Aufstellung" right={"<n> Zeilen · Beträge in Euro"}` (nur wenn Daten da).
    Tabelle `w-full border-collapse text-[12px]`, **sieben Wertspalten** plus Zeitraumspalte
    (`COLUMNS`, `:29-37`). Jeder Kopf hat eine **Unterzeile** in `--text-3`, mit „· " davor
    (`:116`), Kopfzeile `.kicker` auf `font-size: 10`:
      | Kopf | Unterzeile | Wert |
      |---|---|---|
      | Einspeisung | kWh | `de1(exportKwh, >=100 ? 0 : 1)` |
      | Vergütung | netto | `eur(exportNet)` |
      | USt darauf | erhalten | `eur(exportVat)` |
      | Eigenverbrauch | kWh | `de1(selfKwh, >=100 ? 0 : 1)` |
      | Wertabgabe | netto | `eur(selfNet)` |
      | USt darauf | geschuldet | `eur(selfVat)` |
      | **Zahllast** | USt gesamt | `eur(vat)`, `strong: true` → `var(--amber)` |
    Zeilen: `border-top: 1px solid var(--line-1)`, Zeitraumname in `--text-2`,
    Zellen `mono`, rechtsbündig, `py-2 pl-3`, `whitespace-nowrap`; die Zahllast-Spalte in
    `var(--amber)`, alle anderen `var(--text-1)` (`:126`).
    **Summenzeile** (`:132-141`): `border-top: 2px solid var(--line-2)`, Wort „Summe",
    `font-semibold`, dieselben sieben Spalten aus `data.totals` (`rowOf`, `:39-50`).
    Darunter `<Note>`: „Die Summe stammt aus den ungerundeten Stundenwerten, die Zeilen sind
    einzeln gerundet: ihre Addition kann um wenige Cent abweichen." (:145-148)
    DATEN: `data.buckets[].label` + `data.buckets[].totals.*`, Summe aus `data.totals.*`.

  * **Karte „Zeiträume im Vergleich"** (`PvAccounting.tsx:151-161`, Baustein
    `PeriodStrip.tsx:32-93`)
    Vier Spalten = Tag · Woche · Monat · Jahr **des Ankertags**; Kopf rechts
    „jeweils bis jetzt" bzw. „jeweils bis <TT.MM.JJJJ>" (`PeriodStrip.tsx:34-38`).
    Die Tagesspalte heißt nur „Heute", wenn der Anker heute ist, sonst „TT.MM."
    (`PeriodStrip.tsx:12-16`). Begründung im Kommentar `:21-27`: „Blättert man auf einen
    vergangenen Tag, zeigen sie dessen Woche, Monat und Jahr - nicht mehr die laufenden."
    Fünf Zeilen, wörtlich (`PvAccounting.tsx:154-160`):
      1. „Einspeisung · kWh" `de1(export_kwh, >=100 ? 0 : 1)`, `tone="mist"`, **fett** (erste Zeile, `fontWeight 600`)
      2. „Vergütung netto" `eur(export_net_eur)`
      3. „Eigenverbrauch · kWh" `de1(self_consumption_kwh, >=100 ? 0 : 1)`
      4. „Wert Eigenverbrauch netto" `eur(self_value_net_eur)`
      5. „Umsatzsteuer gesamt" `eur(vat_payable_eur)`, `tone="amber"`
    Fehlende Spalte → `"-"` (`PvAccounting.tsx:76`).
    DATEN: `useMultiPeriod(api.energyPv, anchor)` (`PvAccounting.tsx:56`,
    `useReport.ts:55-77`): **vier Abfragen auf einmal** per `Promise.allSettled` über
    `ALL_PERIODS`, alle 5 min neu; eine gescheiterte Spanne fehlt, die Seite bleibt.
    Begründung im Kommentar `useReport.ts:48-54`: der Anker war „vorher fest auf heute
    verdrahtet. Wer in der Navigation auf den 3. Januar blätterte, sah oben die Zahlen dieses
    Tages und in der Übersicht daneben weiterhin die laufende Woche … Zwei Zeiträume in einer
    Ansicht, ohne dass es dastand."

  * **Schlussnote** (`PvAccounting.tsx:163-172`), `<Note>`, **immer sichtbar**, in dieser
    Reihenfolge ein Absatz:
    `data.meta.method_de`
    + `coverage != null ? " Datenabdeckung <round(coverage*100)> %." : " Für diesen Zeitraum
      liegen keine Messdaten vor."`
    + wenn `totals.self_estimated_kwh > 0.05`: „ Bei <de1(x)> kWh der Speicherentladung war die
      Herkunft nicht bekannt; sie zählen als PV."
    + „ Die Zahlen bereiten die Beträge auf, sie ersetzen keine Steuerberatung."
    Die Vorlage benutzt hier **nicht** `CoverageNote`/`Methode` — nichts ist zugeklappt, und
    `data_since`, `vat_rate`, `prices_include_vat`, `battery_capacity_kwh` kommen nicht vor.

  * **Handy-Fassung** (`apps/web/src/styles/handy.css`, Grenze `max-width: 720px`)
    Diese Route hat **keine eigene Regel**. Gesucht nach „pv", „abrechnung", „aufstellung",
    „table" in `handy.css`: nur `.rooms-table` (:377-379) und `.alfred-*` — kein Treffer für
    diese Seite. Was greift, greift über die gemeinsamen Klassen:
    - Vier Entscheidungen im Kopf der Datei (`handy.css:11-19`): Bereiche unten, **eine Zahl
      führt**, **Flächen statt Rahmen**, **Tabellen werden Listen**.
    - Seitenrand `padding: 10px 16px calc(86px + safe-area)`, `gap: 14px`, Grundschrift 15 px
      (`:110-111`); Grund flach `var(--deep)` (:109).
    - Kopf: Rahmen und Glas weg (:137), Bereichsname 26 px halbfett (:141); Datumskasten und
      Spannenwahl werden zu zwei Zeilen (`:143-161`), Spannen 13,5 px, Radius 8 px;
      `report-anchor-kurz` ersetzt die lange Datumsschreibweise (:159-160) — kurz heißt
      „Di., 10.11.", „KW 46", „Nov. 2026" (`ReportShell.tsx:51-58`).
    - Reiter: rollbare Pillen über den Seitenrand hinaus, aktiv weiß auf dunkel (:163-175).
    - Karten: **kein Rand**, Radius 16, `padding: 16` (:182); Kartentitel wird lesbare Schrift
      16,5 px halbfett ohne Sperrschrift (:184); Untertitel bricht in eine eigene Zeile (:185).
    - Kleine Schrift eine Stufe größer: 10→11, 11→12, **12→13,5**, 13→14,5 (:187-192) —
      trifft die ganze Aufstellung und die Vergleichstabelle.
    - **Kennzahlen (`:194-207`)**: aus sechs Rahmen wird **eine Fläche** `var(--surface-2)`,
      Radius 16, `padding: 4px 16px`, zwei Spalten, Trennung durch `1px var(--line-1)`.
      Die **erste Kachel** nimmt die ganze Breite, Zahl **48 px**, `letter-spacing -.04em`,
      Einheit 18 px, Hinweiszeile 14,5 px in `--text-2`; die übrigen Zahlen 25 px, Einheit
      13,5 px, Hinweis 13 px. Eine allein übrige letzte Kachel nimmt die ganze Zeile (:200).
    - `PeriodStrip` schaltet am Handy **selbst** um (`PeriodStrip.tsx:39-64`, `useIsMobile`):
      statt vier Spalten ein Pillenschalter `.spannen`/`.spanne` über einer `<dl>`-Liste;
      Schalter Radius 11, Höhe 34, 13,5 px, aktiv `var(--amber)` auf `var(--petrol)`
      (`handy.css:291-293`); Zeile: Wort 14,5 px `--text-2` links, Wert mono **16 px** rechts,
      Haarlinie dazwischen, erste Zeile ohne Linie (`:294-299`). Begründung im Kommentar
      `PeriodStrip.tsx:28-30`: „Vier Zahlenspalten neben dem Namen der Zeile passen nicht auf
      390 Punkte: die Namen wurden abgeschnitten, die Zahlen liefen ineinander."
    - **Die Aufstellung bleibt eine Tabelle und rollt seitlich.** `handy.css:305-347` wandelt
      genau vier benannte Tabellen in Listen um (`.kosten-tabelle`, `.fp-entscheidungen`,
      `.nb-tabelle`, `.fenster-tabelle`); die Aufstellung trägt **keine** dieser Klassen
      (`PvAccounting.tsx:110`), sie liegt nur in `overflow-x-auto` (:109). Acht Spalten auf
      390 Punkten heißt also: wischen. Das ist in der Vorlage so, und damit ist es keine
      Lücke der App, sondern der **einzige** Punkt, an dem die App (eine Spalte mit
      Umschalter, `Bericht.swift:206-244`) **über** die Vorlage hinausgeht.
    - Diagramme bekommen am Handy dieselbe Nachstellung (`EChart.tsx:73-81`, `charts/handy.ts`).
    - `@media (max-width: 720px)` in `globals.css:333-355` gilt zusätzlich: `.card {padding:14px}`,
      `.kpi-grid` zwei Spalten, `.report-row` eine Spalte. Der Kommentar `globals.css:337-338`
      nennt ausdrücklich diese Seite: „ein zusätzlicher Verweis neben Zeitwahl und Zeitraum
      schob die Zeile sonst aus dem Bild (Photovoltaik 57 Punkte, **PV-Abrechnung 9**, gemessen
      am 10.11.2026)" — der Verweis „Erzeugung →" ist der Grund für den Umbruch.

LUECKEN

  [traegt-die-seite] **Das Hauptdiagramm „Erlös und Wertabgabe" fehlt ganz.** Vorlage:
    `PvAccounting.tsx:100-105` mit `moneyBars` (`charts.ts:367-399`), zwei gestapelte
    Euro-Reihen je Bucket, Karte 300 px hoch. App: `GeldSeiten.swift:128-201` enthält kein
    `Balkenbild` und kein anderes Bild. Die Seite hat damit kein Bild davon, aus welchem Monat
    das Geld kam.

  [traegt-die-seite] **Die Aufstellung hat vier statt sieben Wertspalten.** Es fehlen
    „USt darauf · erhalten" (`exportVatEur`), „Wertabgabe · netto" (`selfValueNetEur`) und
    „USt darauf · geschuldet" (`selfVatEur`) je Bucket — Vorlage `PvAccounting.tsx:29-37`,
    App `GeldSeiten.swift:159-183`. Genau diese drei sind die Bemessungsgrundlagen, um die es
    auf einer Seite geht, die „ein Beleg" sein will (`GeldSeiten.swift:117-120`).

  [traegt-die-seite] **Die Summenzeile der Aufstellung fehlt.** Vorlage `:132-141`: eigene Zeile
    „Summe" mit `border-top: 2px solid var(--line-2)`, halbfett, aus `data.totals`, plus die
    Note „Die Summe stammt aus den ungerundeten Stundenwerten …" (:145-148). `Tabelle`
    (`Bericht.swift:157-327`) kennt keine abgesetzte Fußzeile.

  [traegt-die-seite] **„Zeiträume im Vergleich" fehlt — und der Mechanismus dafür auf dieser
    Seite.** Vorlage: fünf Zeilen über Tag/Woche/Monat/Jahr desselben Ankers
    (`PvAccounting.tsx:151-161`, `PeriodStrip.tsx:32-93`), geladen mit `useMultiPeriod`
    (`useReport.ts:55-77`). App: `Berichtsseite` holt **eine** Antwort
    (`Bericht.swift:33-50`, Aufruf `GeldSeiten.swift:123-124`). Gesucht nach „PeriodStrip",
    „Spannenvergleich", „spannenzeilen" in `apps/ios/DuckCurveHome/Seiten/Geld/`: kein Treffer.

  [spuerbar] **Drei der sechs Kennzahlen der Vorlage fehlen, zwei fremde stehen dafür da.**
    Fehlen: „Vergütung netto" (`exportNetEur`), „USt auf Einspeisung" (`exportVatEur`),
    „Wert des Eigenverbrauchs" (`selfValueNetEur`) — alle drei nur noch als Nebenzeile in den
    Karten „Einspeisung"/„Eigenverbrauch" (`GeldSeiten.swift:137-138`, `:156`).
    Zusätzlich in der App und **nicht** in der Vorlage: „erzeugt" (`pvKwh`, :212) und
    „Eigenverbrauchsanteil" (`selfConsumptionShare`, :224). „Vergütungssatz" ist in der Vorlage
    die Hinweiszeile der ersten Kachel (`PvAccounting.tsx:92`), nicht eine eigene Kachel.
    Auch die Reihenfolge weicht ab: die Vorlage führt mit „Eingespeist", die App mit
    „Umsatzsteuer zu zahlen".

  [spuerbar] **Die Hinweiszeilen der Kacheln fehlen oder sagen etwas anderes.** Vorlage:
    „<x,xx> ct/kWh netto", „brutto <…>" bzw. „ohne Umsatzsteuer", „ausgezahlt, abzuführen",
    „davon <x> kWh über den Speicher", „netto, Ø <x,xx> ct/kWh", „Einspeisung + Wertabgabe"
    bzw. „Kleinunternehmer: keine USt" (`PvAccounting.tsx:92-97`). App: nur „aus Einspeisung
    und Eigenverbrauch", „<…> brutto", „<…> netto" (`GeldSeiten.swift:208-220`).
    `selfCtKwh` wird in der App **nirgends** gelesen: gesucht nach `selfCtKwh` in
    `apps/ios/DuckCurveHome/`: kein Treffer.

  [spuerbar] **Die Datenabdeckung fehlt, und der Methodensatz ist unsichtbar.** Vorlage: beides
    steht als offener Absatz unter der Seite (`PvAccounting.tsx:163-172`), mit
    „Datenabdeckung <n> %." bzw. „Für diesen Zeitraum liegen keine Messdaten vor."
    App: `Methode(…)` ohne `kurz` (`GeldSeiten.swift:184-201`) — zugeklappt steht nur die
    Zeile „Wie das gerechnet ist" (`Bericht.swift:344`), und `meta.coverage` wird auf dieser
    Seite nicht gelesen (gesucht nach `coverage` in `GeldSeiten.swift`: kein Treffer).
    Das Muster dafür ist im Projekt schon gewählt: `StromSeite.swift:47-56` + `:37-42`
    („Die Abdeckung steht in der Kurzzeile und nicht im Rumpf: sie schränkt jede Zahl dieser
    Seite ein, und zugeklappt wäre sie verschwiegen.").

  [spuerbar] **Der Kleinunternehmerfall wird nicht gefärbt.** Vorlage schaltet zwei Kacheln auf
    `tone="muted"` = `var(--text-3)` und tauscht deren Hinweis
    (`PvAccounting.tsx:94`, `:97`, Schalter `:58` aus **`meta.small_business`**). App liest
    `b.totals.smallBusiness` (`GeldSeiten.swift:186`) und sagt es nur im zugeklappten Text;
    die Kacheln bleiben voll in `Farbe.text1`/`Farbe.amber`.

  [spuerbar] **„Zahllast" ist nicht Bernstein.** Vorlage: diese eine Spalte in `var(--amber)`
    (`PvAccounting.tsx:126`, `COLUMNS[6].strong`). App: alle Zellen `Farbe.text1`
    (`Bericht.swift:314-319`), obwohl `Tabelle.Spalte.farben` (`Bericht.swift:169`) genau
    dafür da ist („Warum eine Spalte Farbe tragen darf").

  [spuerbar] **Der Verweis „Erzeugung →" und der Seitenkicker fehlen.** Vorlage:
    `right={<Link href="/strom/pv" …>Erzeugung →</Link>}` 12 px `var(--amber)`
    (`PvAccounting.tsx:88`) und `kicker="Einspeisung · Eigenverbrauch · Umsatzsteuer"` (:82),
    letzterer rechts in der Reiterzeile (`AreaShell.tsx:24`). In der App trägt die
    Zeitraumleiste keinen Platz dafür (`Seitenwahl.swift:198-206`), und
    `Reiterzeile.swift`/`HandRahmen.swift`/`WandRahmen.swift` kennen kein „kicker" (gesucht
    nach `kicker` in diesen drei Dateien: kein Treffer). Der Kicker der App ist der
    Kartenkicker „PV-Abrechnung" (`GeldSeiten.swift:129`) — er wiederholt den Reiternamen.

  [spuerbar] **Tag und Woche sind nicht wählbar.** `Bereiche.swift:119-121` gibt
    `spannen: [.monat, .jahr]`; die Vorlage bietet alle vier an (`ReportShell.tsx:10`,
    `:120-126`) mit Voreinstellung Jahr, und begründet sie als „der Blick hinein"
    (`PvAccounting.tsx:53`). Der Spannenvergleich setzt alle vier ohnehin voraus.

  [spuerbar] **Leere Buckets werden mitgezählt.** Vorlage filtert
    `export_kwh > 0.005 || self_consumption_kwh > 0.005` (`PvAccounting.tsx:60-63`) — für
    Diagramm **und** Tabelle. App übergibt `b.buckets` unverändert
    (`GeldSeiten.swift:161-182`): im Januar stehen zwölf Monatszeilen, zehn davon mit „0,0".

  [klein] **Die Rundungsregel fehlt.** Vorlage: kWh ohne Nachkomma ab 100, sonst eine Stelle
    (`PvAccounting.tsx:30`, `:33`, `:92`, `:95`, `:155`, `:157`). App: immer `stellen: 1`
    (`GeldSeiten.swift:134`, `:146`, `:213`, `:219`, `:166`, `:175`).

  [klein] **Der Kopf der Aufstellung hat keine Unterzeilen.** Vorlage: zwei Ebenen je Spalte,
    „Einspeisung · kWh", „Vergütung · netto", „USt darauf · erhalten" (`PvAccounting.tsx:29-37`,
    `:114-118`), Kopfzeile `.kicker` auf 10 px. App: einzeilige Namen
    („eingespeist", „Vergütung", …, `GeldSeiten.swift:163-181`), und „USt darauf" wäre ohne
    Unterzeile zweimal dasselbe Wort.

  [klein] **Der Hinweis rechts auf der Aufstellung fehlt** („<n> Zeilen · Beträge in Euro",
    `PvAccounting.tsx:108`), ebenso die Rundungsnote (:145-148). `Karte` kann es
    (`Karte.swift:16-18`, `titel`/`beiwerk`).

  [klein] **Der Schätz-Satz ist anders formuliert.** Vorlage: „Bei <x> kWh der Speicher-
    entladung war die Herkunft nicht bekannt; sie zählen als PV." (`PvAccounting.tsx:168`).
    App: „Vom Eigenverbrauch sind <x> geschätzt, nicht gemessen." (`GeldSeiten.swift:193`).
    Die Vorlage sagt, **welche** kWh und **wie** sie gezählt werden; das ist auf einem Beleg
    der Unterschied.

  [klein] **Den „Umsatzsteuersatz <x %>."-Satz hat die Vorlage nicht** (`GeldSeiten.swift:188-190`
    gegen `PvAccounting.tsx:163-171`). Zusatz, keine Lücke — aber er gehört in die Entscheidung,
    was beim Umbau bleibt.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Api.energiePv(_ zeitraum: String, anker: String) async throws -> PvTaxReportOut`
    — `DuckCurveKit/Netz/Api.swift:200`. Dieselbe Zusage wie `client.ts:127`.
  * `PvTaxReportOut` {`period`, `anchor`, `start`, `end`, `totals`, `buckets`, `meta`}
    — `Modelle/Schema.swift:6409-6438`; `buckets` mit `?? []` dekodiert (:6435).
  * `PvTaxBucketOut` {`start`, `end`, `label`, `totals`} — `Schema.swift:6340-6360`.
  * `PvTaxTotals` — `Schema.swift:6441-6498`: `smallBusiness`, `vatRate`, `feedInCtKwh`,
    `exportKwh`, `exportNetEur`, `exportVatEur`, `exportGrossEur`, `selfConsumptionKwh`,
    `selfDirectKwh`, `selfBatteryKwh`, `selfValueNetEur`, `selfVatEur`, **`selfCtKwh`**,
    `selfEstimatedKwh`, `vatPayableEur`, `pvKwh`, `selfConsumptionShare` — **alle `Double?`**
    (anders als im Web-Schema, wo sie Pflichtfelder mit Standardwert sind,
    `types.ts:5425-5505`). Jede Rechnung muss also entpacken.
  * `PvTaxMetaOut` {`feedInCtKwh`, `vatRate`, `smallBusiness`, `pricesIncludeVat`, `dataSince`,
    **`coverage`**, `batteryCapacityKwh`, `methodDe`} — `Schema.swift:6363-6405`.
  * Formate — `DuckCurveKit/Formate/Formate.swift`: `zahl(_:stellen:)` :44,
    `kwh` :75, `prozent` :81, `ct` :93, `euro(_:stellen:)` :99, `leer = "-"` :27.
  * Farben — `DuckCurveKit/Gestalt/Marken.swift`: `amber = 0xF2A900` :18,
    `amberWeich = 0xFFD778` :19, `mist = 0x7FA3B3` :20, `textKicker = mist` :46, `pv = amber` :50,
    `radius3 = 6` :263, `dauer = 0.18` :268. SwiftUI-Hüllen in
    `DuckCurveHome/Gestalt/Farben.swift:31`, `:33`, `:48-51`, `:54`.
  * Schrift — `DuckCurveHome/Gestalt/Typografie.swift`: `kicker` 10,5 pt :61,
    `karte` 15 pt :42, `klein` 13 :45, `winzig` 11,5 :46, `zahl` mono 15 :69,
    `zahlKlein` 12,5 :70, `achse` 10,5 :101, `mono(_:relativeTo:)` :90, `sans(_:)` :86,
    `custom(48)` über `Kachel` :240. `struct Kicker` :132-141 (uppercase, tracking 1,4).
  * Bausteine — `DuckCurveHome/Gestalt/Karte.swift`: `Karte` (kicker/titel/beiwerk) :15,
    `Kacheldaten` (wort/wert/einheit/dazu/farbe/**weg**) :121-151, `Kachel` mit `Art.bericht`
    und `fuehrend` :158-266 (48 pt führend, 25 pt daneben, Kicker über der Zahl),
    `Kachelfeld` (erste führt, zwei Spalten, Haarlinien) :274-343, `Zeile` :360-383,
    `Leer` :390, `Stoerung` :410.
  * `DuckCurveHome/Seiten/Bericht.swift`: `Berichtsseite` (Laden, Fehler, altes Bild stehen
    lassen) :15-63, `Balkenbild` (gestapelt, Legende oben, Achsenauswahl 6/12 Wörter) :70-149,
    `Tabelle` mit `Spalte.farben` und Handy-Umschalter :157-327, `Methode(_:kurz:titel:)`
    :334-397.
  * Gerippe — `DuckCurveHome/App/Seitenwahl.swift`: `Seite` :136, `Zeitraumleiste` :188,
    `Spannenwahl` :210, `Datumskasten` :229. Route `/geld/pv-abrechnung` → `PvAbrechnungSeite`
    :53-54. Reiter inkl. `nurHausherr: true` — `Bereiche.swift:119-121`.
  * **Mehrere Spannen auf einmal: das Muster ist schon da**, aber nur für Wärme:
    `WaermeSeite.swift:48-61` (`holeSpannen` mit `withTaskGroup` und `try?` je Spanne,
    Kommentar „eine fehlende Spalte ist besser als eine Seite, die an ihr scheitert"),
    `WaermeSeite.swift:313-321` (`spannenvergleich` setzt `Tabelle` mit
    `Spanne.allCases` als Spalten), Rechnung im Kern:
    `DuckCurveKit/Zustand/Waermeuebersicht.swift:280-301` (`spannenzeilen`,
    Kommentar `:272-279`: „Die Einheit steht in der Zeile und nicht in jeder Zelle").
  * Abdeckung als Kurzzeile: `StromSeite.swift:47-56` (`abdeckung`), eingesetzt :32-43.
  * Euro-Balken gibt es schon: `GeldSeiten.swift:46-55` und `:58-74` setzen `Balkenbild`
    mit `einheit: "€"`.

ES FEHLT

  1. **`Pvabrechnung.aufstellung(_:)`** — neu in
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Pvabrechnung.swift`.
     Vorschlag:
     `public struct Abrechnungszeile: Sendable { public let wort: String;
      public let zellen: [String] }` plus
     `public static func aufstellung(_ b: PvTaxReportOut) -> (spalten: [(kopf: String, unter: String)],
      zeilen: [Abrechnungszeile], summe: Abrechnungszeile)`.
     Enthält die sieben Spalten in der Reihenfolge von `PvAccounting.tsx:29-37`, die
     Bucket-Filterung `> 0.005` (`:61`) und die Rundungsregel „ab 100 kWh ohne Nachkomma".
     Dort gehört auch `vatPayableEur` als die eine farbige Spalte hinterlegt
     (`Tabelle.Spalte.farben`, `Bericht.swift:169`).

  2. **`Pvabrechnung.spannenzeilen(_ je: [Spanne: PvTaxReportOut]) -> [(wort: String,
     werte: [String], ton: Kennzahl.Ton?)]`** — dieselbe Datei, Vorbild
     `Waermeuebersicht.spannenzeilen` (`Waermeuebersicht.swift:280-301`). Fünf Zeilen mit den
     Wörtern aus `PvAccounting.tsx:154-160`; der Ton trägt „mist" für Zeile 1 und „amber" für
     Zeile 5 (`Farbe.ton`, `Farben.swift:98`).

  3. **`Pvabrechnung.erloesreihen(_ b: PvTaxReportOut) -> [(name: String, werte: [(String, Double)])]`**
     — die beiden Euro-Reihen des Diagramms über die **gefilterten** Buckets, Namen wörtlich
     „Einspeisevergütung netto" und „Eigenverbrauch (Wert netto)" (`PvAccounting.tsx:69-70`),
     damit Farbzuordnung (`Farbe.mist`, `Farbe.pv`) und Reihenfolge an einer Stelle stehen.

  4. **`Pvabrechnung.saetze(_ b: PvTaxReportOut) -> (kurz: String, rumpf: [String])`**
     — die Schlussnote der Vorlage, zerlegt in die Kurzzeile (Datenabdeckung aus
     `meta.coverage`, Wortlaut nach `StromSeite.swift:52-56`) und den Rumpf
     (`meta.methodDe`, Schätzsatz mit dem Wortlaut aus `PvAccounting.tsx:168`,
     Kleinunternehmer- bzw. Steuerberatungssatz).

  5. **`Formate.kwhNachGroesse(_ wert: Double?) -> String`** in
     `DuckCurveKit/Formate/Formate.swift` (neben `kwh` :75): null Nachkommastellen ab 100,
     sonst eine — die Regel steht in der Vorlage sechsmal
     (`PvAccounting.tsx:30`, `:33`, `:92`, `:95`, `:155`, `:157`) und soll nicht sechsmal in
     die Seite geschrieben werden.

BAUPLAN

  1. `DuckCurveKit/Formate/Formate.swift` — `kwhNachGroesse` ergänzen (Punkt 5 oben).
  2. `DuckCurveKit/Sources/DuckCurveKit/Zustand/Pvabrechnung.swift` (neu) — die vier Rechnungen
     aus „ES FEHLT" 1-4. Tests gehören nach
     `DuckCurveKit/Tests/DuckCurveKitTests/` neben `WaermeuebersichtTests.swift:280`
     (dort steht das Vorbild `testDerSpannenvergleichHatZwoelfZeilenUndVierSpalten`).
  3. `DuckCurveKit/Bereiche/Bereiche.swift:119-121` — `spannen: [.monat, .jahr]` auf alle vier
     öffnen (oder weglassen, dann gilt `Spanne.allCases`, `Seitenwahl.swift:195`).
     `nurHausherr: true` bleibt.
  4. `DuckCurveHome/Seiten/Bericht.swift` — `Balkenbild` um die Achsenstellen erweitern
     (`var achsenstellen: Int = 0`, benutzt in `:126` `Formate.zahl(d, stellen:)`): Euro-Beträge
     brauchen dort zwei, sonst steht unter einem 12,34-€-Balken eine „12".
     Dazu `Tabelle` um eine **abgesetzte Fußzeile** erweitern
     (`var summe: (wort: String, zellen: [String])?`, gezeichnet mit
     `Divider().overlay(Farbe.linie2)` und halbfetter Schrift — Vorlage
     `PvAccounting.tsx:133-140`), und um Spaltenköpfe mit Unterzeile
     (`Spalte.unter: String?`, `PvAccounting.tsx:116`).
  5. `DuckCurveHome/Seiten/Geld/GeldSeiten.swift`, `PvAbrechnungSeite` neu aufbauen,
     Karte für Karte in der Reihenfolge der Vorlage:
     a. **Abfrage**: `Berichtsseite` holt wie bisher die eine Antwort **und** zusätzlich die
        vier Spannen zum selben Anker — Vorbild `WaermeSeite.swift:32-61`:
        `async let bericht = api.energiePv(z.spanne.rawValue, anker: z.anker)` und
        `async let je = holeSpannen(anker: z.anker, api: api)`, mit `try?` je Spanne.
        Der Antworttyp muss benannt werden (die Datei sagt zweimal, warum:
        `GeldSeiten.swift:125-127` und `:18-20`).
     b. **Kachelfeld** mit den **sechs** Kennzahlen der Vorlage in ihrer Reihenfolge
        (`PvAccounting.tsx:92-97`), Hinweiszeilen wörtlich, `Farbe.mist` auf Kachel 1,
        `Farbe.amber` auf Kachel 4, und `Farbe.text3` auf Kachel 3 und 6, wenn
        `meta.smallBusiness` — `kicker:` bleibt weg oder wird auf
        „Einspeisung · Eigenverbrauch · Umsatzsteuer" gesetzt, nicht auf den Reiternamen.
        Die erste Kachel führt von selbst (`Kachelfeld.ersteFuehrt`, `Karte.swift:278`).
        Verweis „Erzeugung →": als `weg: "/strom/pv"` auf der Kachel „eingespeist"
        (`Kacheldaten.weg`, `Karte.swift:129`; der Pfeil kommt aus `Karte.swift:255-257`) —
        die App hat keine Stelle im Kopf, an die ein Seitenverweis gehört.
     c. **Karte „Erlös und Wertabgabe"** mit `titel`/`beiwerk`
        „Einspeisevergütung · Eigenverbrauch, jeweils netto" und `Balkenbild(stuecke:
        Pvabrechnung.erloesreihen(b), einheit: "€", achsenstellen: 2)`; bei leeren Reihen
        `Leer(satz: "Für diesen Zeitraum liegen keine bewerteten Stunden vor.")`
        (`Bericht.swift:390`).
     d. **Karte „Aufstellung"** mit `beiwerk` „<n> Zeilen · Beträge in Euro", der
        Sieben-Spalten-`Tabelle` samt Unterzeilen, Amber auf „Zahllast", Summenzeile, und
        darunter der Rundungssatz als `Text(…).font(Schrift.winzig)` in `Farbe.text3`
        (Muster `WaermeSeite.swift:305-308`).
     e. **Karte „Zeiträume im Vergleich"** mit `Tabelle(zeilennamen:…, spalten:
        Spanne.allCases.map { … })` über `Pvabrechnung.spannenzeilen(je)` — Vorbild
        `WaermeSeite.swift:313-321`. Der Kopf der Karte trägt „jeweils bis jetzt" bzw.
        „jeweils bis <Datum>" (`PeriodStrip.tsx:34-38`); am Telefon macht `Tabelle` von selbst
        den Pillenumschalter (`Bericht.swift:206-244`), was genau der Handy-Fassung des
        `PeriodStrip` entspricht (`PeriodStrip.tsx:42-64`).
     f. **`Methode`** mit `kurz:` aus `Pvabrechnung.saetze(b).kurz` und dem Rumpf aus
        `.rumpf` — damit die Abdeckung im Ruhezustand dasteht (`Bericht.swift:338-343`).
     g. Die bisherigen Karten „Einspeisung" und „Eigenverbrauch" (`:130-158`) **entfallen**:
        ihre acht Zeilen sind nach dem Umbau in den Kacheln und in der Aufstellung enthalten;
        nur `selfDirectKwh` käme nirgends mehr vor — das gehört dann in die Hinweiszeile der
        Eigenverbrauchskachel neben `selfBatteryKwh`.

WAS SCHWIERIG WIRD

  * **Acht Spalten in `Tabelle`.** `Bericht.swift:282-312` legt jede Spalte mit
    `frame(maxWidth: .infinity)` gleich breit; bei acht Spalten auf dem iPad stehen „1.234,5"
    und „0,00" in derselben Breite, und der Zeilenname bekommt ein Achtel. Die Vorlage löst es
    mit `whitespace-nowrap` plus `overflow-x-auto` (`PvAccounting.tsx:109-110`). Im Projekt ist
    der Weg dafür schon gewählt: `Tabelle.immerSichtbar` mit mehreren festen Spalten
    (`Bericht.swift:176-184`, `festeListe` :247-280) — und die Begründung dort nennt
    ausdrücklich den Fall, in dem die Vorlage selbst Spalten ausblendet (`handy.css:377-379`).
    Für die Aufstellung heißt das: am iPad alle sieben, am Telefon der Umschalter.
  * **Swift Charts hat keinen Tooltip wie ECharts.** `moneyBars` zeigt beim Überfahren alle
    Reihen plus Summe (`charts.ts:376-385`). `Balkenbild` (`Bericht.swift:103-147`) hat nur
    Legende und Achsen; ein `chartOverlay`-Zeiger ist nirgends im Projekt gebaut (gesucht nach
    `chartOverlay` in `apps/ios/DuckCurveHome/`: kein Treffer). Der gewählte Weg ist, ohne
    Tooltip zu leben und die Zahlen in der Aufstellung darunter stehen zu lassen — dieselbe
    Entscheidung wie auf der Kostenseite (`GeldSeiten.swift:58-74`).
  * **Der abgerundete oberste Balken eines Stapels.** `moneyBars` gibt nur der letzten Reihe
    `borderRadius [2,2,0,0]` (`charts.ts:395`); `BarMark` in `Bericht.swift:112` setzt
    `cornerRadius(1)` auf **jedes** Stück, also auch auf die Fuge. Das ist bereits so auf der
    Kostenseite und bleibt besser so, als eine Sonderregel für eine Seite einzuführen.
  * **Zwei „meta"-Typen, verschiedene Felder.** Der Kommentar in der App
    (`GeldSeiten.swift:195-198`) warnt davor: auf der Kostenseite ist `meta` ein
    `EnergyMetaOut` mit `estimatedNoteDe`, hier ein `PvTaxMetaOut` mit `methodDe` und ohne
    `estimatedNoteDe`. Beim Umbau nicht verlieren: die Vorlage benutzt auf dieser Seite
    **`meta.coverage` und `meta.method_de`**, den Kleinunternehmer-Schalter aber ebenfalls aus
    `meta` (`PvAccounting.tsx:58`), nicht aus `totals` wie die App heute (`:186`).
  * **`PvTaxTotals` ist in Swift durchweg optional** (`Schema.swift:6441-6458`), im Web nicht
    (`types.ts:5425-5505`). Ein `?? 0` im Diagramm ist richtig (eine fehlende Zahl ist dort
    kein Balken), in der Aufstellung nicht (dort muss `Formate.leer` = „-" stehen,
    `Formate.swift:27`) — die Vorlage unterscheidet das über `eur(null) === "-"`
    (`ReportShell.tsx:15`).
