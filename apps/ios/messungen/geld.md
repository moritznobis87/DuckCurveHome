========================= messen:geld   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
------------------------------------------------------

`struct KostenSeite: View` in `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:10-115`.
Zwei Abfragen: `api.energieUebersicht` und `try? api.energieVerschiebung`
(`GeldSeiten.swift:15-17`). `/energy/heat` wird **nicht** geholt.

1. `Kachelfeld(kicker: "Geld")` mit sechs Kacheln (`GeldSeiten.swift:22`, gebaut in
   `kennzahlen(_:_:)` `GeldSeiten.swift:88-114`), in dieser Reihenfolge:
   „gespart" (nur wenn Vergleichslauf da, `Formate.euro(v.savingEur)`, dazu „gegen ein Haus
   ohne Preisblick", Farbe `Farbe.mist`/`Farbe.alarm`), „unterm Strich"
   (`importCostEur - exportRevenueEur`, dazu „Bezug minus Einspeisung"), „Bezug",
   „Einspeisung" (`Farbe.netzEinspeisung`), „Wärmepumpe", „mittlerer Bezugspreis"
   (2 Stellen, ct/kWh).
2. Karte „Der Vergleichslauf · Was der Preisblick gebracht hat" (`GeldSeiten.swift:24-43`):
   fünf `Zeile` – „wirklich bezahlt" (`actualEur`), „ohne Preisblick" (`naiveEur`),
   „gespart" (`savingEur`, mist/alarm), „je Kilowattstunde Wärmestrom" (`savingCtPerKwh`, ct),
   „verschoben" (`shiftedKwh`, kWh).
3. Karte „Nach Tagen" (`GeldSeiten.swift:44-56`): `Balkenbild` mit **einem** Stück „gespart"
   in `Farbe.mist`, `gestapelt: false`, Einheit „€", über `v.days.map { ($0.day, $0.savingEur) }`
   – ohne Filter auf `noteDe`, mit dem rohen ISO-Datum als Achsenwort.
4. Karte „Nach Zeitraum" (`GeldSeiten.swift:58-74`): `Balkenbild`, gestapelt, zwei Stücke
   „Bezug" (`Farbe.netzBezug`) und „Einspeisevergütung" (negativ, `Farbe.netzEinspeisung`).
5. `Methode(...)` (`GeldSeiten.swift:78-84`): `verschiebung.methodDe`, `verschiebung.skippedDe`,
   `kosten.meta.estimatedNoteDe` plus `assumptionsDe`. **Ohne `kurz:`** – die Datenabdeckung
   steht nirgends.

Oben die Zeitraumleiste aus dem Gerippe (`Berichtsseite` →
`apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-64`, Leiste
`apps/ios/DuckCurveHome/App/Seitenwahl.swift:187-205`). Vorgabespanne Monat ist schon richtig
gesetzt (`apps/ios/DuckCurveHome/App/Navigation.swift:71`: `bereich.schluessel == .geld ? .monat : .tag`).


VORLAGE
-------

Einstieg `apps/web/src/app/geld/page.tsx:1-7` → `CostReport`
(`apps/web/src/components/reports/CostReport.tsx:59-239`).

**Drei Abfragen plus vier Spannen** (`CostReport.tsx:61-64`):
`api.energySummary` (`/energy/summary?period=&anchor=`,
`apps/web/src/lib/api/client.ts:68`), `api.energyHeat` (`/energy/heat`, `client.ts:71`),
`api.energyShift` (`/energy/shift`, `client.ts:70`) und zusätzlich
`useMultiPeriod(api.energySummary, anchor)` – dieselbe Übersicht noch einmal für Tag, Woche,
Monat, Jahr desselben Ankertags (`apps/web/src/components/reports/useReport.ts:149-171`,
`Promise.allSettled`, eine gescheiterte Spanne lässt die Spalte leer).
Vorgabespanne: `usePeriod("month")` (`CostReport.tsx:60`) – anders als auf allen
Energieseiten, die `usePeriod()` = Tag nehmen (`ReportShell.tsx:61`).

**Der Kommentar am Kopf der Datei ist Begründung und muss erhalten bleiben**
(`CostReport.tsx:14-32`): Euro-Beträge standen auf fünf Seiten verstreut; „Was der Oktober
gekostet hat, war nirgends in einer Zeile zu lesen. Hier steht sie, **und jede Zahl darunter
führt zu der Seite, auf der sie herkommt**." Zweitens: „Fast nichts hier ist neu gerechnet" –
die Seite addiert dieselben Stundenbilanzen. Drittens: der Vergleichslauf ist die eine
Ausnahme, „darf auch negativ sein; genau dann hat das Verschieben Geld gekostet, und eine
Anzeige, die das verschweigt, wäre Werbung."

  * **Kopfzeile „Die vier Beträge"** (`CostReport.tsx:110-117`, Baustein `Betrag`
    `CostReport.tsx:33-43`)
    Eine `Card` mit `padding: "18px 22px"`, darin `div.cost-line flex divide-x divide-line-1` –
    vier Beträge nebeneinander, getrennt durch senkrechte Haarlinien `--line-1`.
    Je Betrag: `span.kicker` mit `fontSize: 11` (Grundmaß `.kicker`
    `apps/web/src/styles/globals.css:57-64`: Mono, 13px, `letter-spacing .13em`, uppercase,
    Farbe `--text-kicker` = `--mist`), darunter die Zahl `mono text-[34px] leading-none
    tracking-[-.03em]` in der Tonfarbe, darunter ein Hinweis `text-[12px] leading-[1.35]
    text-text-3 line-clamp-2`. Padding je Betrag `px-5 py-1`, erstes ohne links, letztes ohne
    rechts.
    Die vier, wörtlich:
      1. „Bezahlt" · `eur(bezahlt)` · Ton `var(--alert)` (#e0533d) ·
         Hinweis „Netzstrom 12,34 € · Pellets 5,67 €"
         DATEN: `bezahlt = totals.import_cost_eur + heat.stove.pellet_eur`
         (`CostReport.tsx:66-67`). **Der Pelletpreis kommt aus `/energy/heat`**
         (`heat.stove.pellet_eur`), nicht aus der Übersicht.
      2. „Bekommen" · `eur(bekommen)` · Ton `var(--mist)` (#7fa3b3) ·
         Hinweis „Einspeisung 123 kWh · netto" (`de1(t.export_kwh, 0)`)
         DATEN: `totals.export_revenue_eur` (`CostReport.tsx:68`).
      3. „Gespart" · `eur(gespart)` · Ton `var(--amber)` (#f2a900) ·
         Hinweis fest: „Sonne direkt und Speicher, gegen den Netzpreis derselben Stunde"
         DATEN: `totals.pv_direct_savings_eur + totals.battery_net_eur` (`CostReport.tsx:69`).
      4. „Energie je Tag" · `eur(jeTag)` · Ton `var(--text-1)` ·
         Hinweis „bezahlt minus bekommen, 30 Tage bewertet" (Singular „Tag" unter 1,5)
         DATEN: `tage = max(1, totals.minutes / 1440)`, `jeTag = (bezahlt - bekommen) / tage`
         (`CostReport.tsx:70-71`).
    Zustände: jeder Wert `null` bis die Übersicht da ist → `eur(null)` = „-"
    (`ReportShell.tsx:15`), der Hinweis entfällt dann ganz (`t ? … : undefined`). Fehler oben
    als `ErrorBanner` (`CostReport.tsx:108`, Baustein `ReportShell.tsx:147-153`).
    **Handy** (`apps/web/src/styles/handy.css:349-358`, Begründung dort im Kommentar: „Vier
    Beträge nebeneinander liefen bei 34 Punkt Schrift ineinander"): `cost-line` wird ein
    Zweispaltenraster, **„Bezahlt" nimmt die ganze Breite** und bekommt 48px mit
    `letter-spacing -0.04em`, die übrigen 25px; senkrechte Linien weg, waagerechte
    `border-top: 1px solid var(--line-1)` dazu; bleibt am Ende eine allein, nimmt sie die
    ganze Zeile (`:last-child:nth-child(even)`); Hinweis 13px, `line-clamp: 3`.

  * **„Bezahlt und bekommen" – das Hauptdiagramm** (`CostReport.tsx:119-123`)
    In `div.report-row` mit `--cols: "8fr 4fr"` (`globals.css:108`:
    `grid-template-columns: var(--cols)`), Karte `padding: 16, height: 300`.
    `CardHead title="Bezahlt und bekommen"`, rechts eine `ChartLegend`
    (`ReportShell.tsx:192-203`: Farbfleck `h-2 w-2.5 rounded-[1px]` plus Name 12px text-3) mit
    `{C.alert, "Netzstrom"}` und `{"#ffd778", "Einspeisung"}`.
    Diagramm `moneyBars` (`apps/web/src/components/reports/charts.ts:367-399`):
    gestapelte Balken, `grid {left:52,right:12,top:24,bottom:30}`, y-Achse mit Namen „€" und
    `splitNumber: 3`, x-Achsenschrift 10px (am Handy ≥11 und `splitNumber ≤ 3` über
    `fuerHandy`, `apps/web/src/components/charts/handy.ts:44-62`), `barCategoryGap: "35%"`,
    Radius `[2,2,0,0]` nur oben auf der letzten Serie, `animation: false`.
    Tooltip `trigger: "axis"`, `axisPointer: "shadow"`: je Serie Name in Serienfarbe und
    Betrag mit zwei Stellen, darunter abgetrennt **„Summe X,XX €"** (`charts.ts:376-385`).
    Serien (`CostReport.tsx:73-83`): „Netzstrom" = `C.alert` (#e0533d,
    `apps/web/src/components/charts/palette.ts:76`) über `buckets[].totals.import_cost_eur`;
    „Einspeisung" = **`#ffd778`** über `-buckets[].totals.export_revenue_eur`.
    Kommentar dazu (`CostReport.tsx:79`): „Die Verguetung steht unter der Nulllinie: bekommen,
    nicht bezahlt."
    Leerzustand: kein `buckets.length` → statt des Diagramms zentriert eine `Note`
    „Für diesen Zeitraum liegen keine bewerteten Stunden vor." (`CostReport.tsx:122`).

  * **„Woraus die Ersparnis besteht"** (`CostReport.tsx:124-148`)
    Rechte, schmale Karte (4fr), `padding: 16, gap: 12`. `CardHead` ohne rechte Seite.
    Zwei Zeilen, je eine waagerechte Balkenleiste:
      – „Sonne direkt genutzt" · `totals.pv_direct_savings_eur` · Farbe `C.pv` (#f2a900)
      – „Speicher statt Netz (netto)" · `totals.battery_net_eur` · Farbe `C.battery` (#7fa3b3)
    Aufbau je Zeile: oben `flex items-baseline justify-between text-[13px]`, links Name in
    `text-2`, rechts der Betrag `mono text-1`; darunter eine Leiste `h-2 rounded-full
    bg-line-1`, darin ein gefüllter Teil in der Serienfarbe mit
    `width: round(v / max * 100) %`, wobei `max = Math.max(0.01, pv_direct_savings_eur,
    battery_net_eur)` – also eine **gemeinsame** Skala beider Zeilen, nicht je Zeile normiert
    (`CostReport.tsx:130`).
    Darunter eine `Note` (12px, `max-w-[90ch]`, text-3, `ReportShell.tsx:143-145`), wörtlich:
    „Gerechnet gegen den Netzpreis der jeweiligen Stunde, abzüglich der Vergütung, die der
    Strom eingespeist gebracht hätte. Was das Verschieben in Preistiefs gebracht hat, steht in
    der Karte darunter - gerechnet, nicht gemessen."
    **Handy:** `report-row` behält `--cols` nicht – die beiden Karten stehen untereinander mit
    `gap: 14px` (`handy.css:209`).

  * **„Was das Verschieben gebracht hat"** (`CostReport.tsx:151-191`)
    Karte `padding: 16, gap: 12`, `CardHead` rechts `ChartLegend` mit
    `{C.pv, "gebracht"}` und `{C.alert, "gekostet"}`.
    Links eine Zahlenspalte `min-w-[230px]`:
      – `shift.saving_eur` als `mono text-[40px] leading-none tracking-[-.03em]`, Ton
        `shiftTon` = `var(--amber)` wenn `days_used > 0 && saving_eur >= 0`,
        `var(--alert)` wenn negativ, **`var(--text-3)` wenn `days_used == 0`**
        (`CostReport.tsx:103`); ohne Antwort „-".
      – darunter 13px text-2: `"gespart gegenüber einem Lauf ohne Preisblick"` bzw.
        `"mehr bezahlt gegenüber einem Lauf ohne Preisblick"`, und wenn `days_used == 0`
        stattdessen **„Für diesen Zeitraum reicht es nicht für eine Aussage."**
        (`CostReport.tsx:161-165`).
      – darunter, nur bei `days_used > 0`, eine Zeile `mono text-[12px] text-text-3`:
        `"<saving_ct_per_kwh,1> ct je verschobener kWh · <shifted_kwh,0> von <heat_pump_kwh,0>
        kWh verschoben · <days_used> Tage gerechnet"` plus, bei `days_skipped > 0`,
        `" · <days_skipped> ohne Aussage (<skipped_de>)"`. Singular „Tag" bei 1
        (`CostReport.tsx:166-172`).
    Rechts das Tagesdiagramm, `min-w-[280px] flex-1`, feste `height: 150`
    (`CostReport.tsx:174-176`), wieder `moneyBars`, aber:
      – **`days` mit `note_de` werden weggefiltert** (`CostReport.tsx:88`), und gezeichnet wird
        nur, wenn überhaupt ein Tag ohne Notiz übrig ist – sonst **nichts**, kein Leersatz
        (`CostReport.tsx:175`).
      – Achsenwort = `new Date(day).toLocaleDateString("de-DE", {day:"2-digit", month:"2-digit"})`,
        also „07.11." und nicht „2026-11-07" (`CostReport.tsx:90`).
      – **zwei Serien statt einer eingefärbten**: „gebracht" = `C.pv` über `max(0, saving_eur)`,
        „gekostet" = `C.alert` über `min(0, saving_eur)` (`CostReport.tsx:92-93`).
        Begründung im Kommentar (`CostReport.tsx:85-86`): „Zwei Serien statt einer
        eingefaerbten: So steht in der Legende, was ein Vorzeichen bedeutet."
    Darunter `<Note>{shift.method_de}</Note>` (`CostReport.tsx:178`).
    Darunter die Annahmen als **zugeklapptes `<details>`** mit `summary` „Annahmen des
    Vergleichslaufs" (`cursor-pointer text-text-2`) und einer `ul list-disc pl-5 gap-1`,
    12px/1.5 text-3 (`CostReport.tsx:181-190`). Kommentar als Begründung
    (`CostReport.tsx:179-180`): „Die Annahmen gehoeren dazu, aber nicht jedem jeden Tag ins
    Gesicht: zugeklappt steht die Karte ruhig, aufgeklappt steht alles da, was die Zahl
    voraussetzt."
    **`actual_eur` und `naive_eur` stehen auf dieser Seite nicht.**

  * **„Aufstellung" – die Postentabelle** (`CostReport.tsx:193-223`, Baustein `Posten`
    `CostReport.tsx:45-57`)
    Karte `padding: 16, gap: 8`; `CardHead title="Aufstellung"` mit rechts dem Text
    „Beträge in Euro · aus denselben Stundenbilanzen wie alle anderen Seiten".
    `table.kosten-tabelle w-full border-collapse text-[13px]`, Kopfzeile `.kicker` mit
    `fontSize: 10`, fünf Spalten: **Posten · Menge · Ø Preis · Betrag · Seite**
    (`CostReport.tsx:197-203`). Jede Zeile `border-t border-line-1`, Zahlen `mono`
    rechtsbündig, letzte Spalte ein `Link` 12px in `text-amber` mit „<Seite> ›".
    Die sieben Zeilen, wörtlich und mit Verweis:
      1. „Netzstrom Haushalt" · `de1(haushaltKwh,0) kWh` · `ct(haushaltCost, haushaltKwh)` ·
         `eur(haushaltCost)` · Ton `--alert` · → `/strom` („Strom")
         DATEN: `haushaltCost = max(0, import_cost_eur − heat_pump_cost_eur − ev_cost_eur −
         battery_device_cost_eur)`, `haushaltKwh = max(0, import_kwh − heat_pump_grid_kwh −
         ev_grid_kwh − battery_device_grid_kwh)` (`CostReport.tsx:101-102`).
         Kommentar als Begründung (`CostReport.tsx:99-100`): „Das Speichergeraet zieht aus
         demselben Netzbezug wie alles andere. Ohne diesen Abzug stuende sein Verbrauch
         zweimal in der Aufstellung."
      2. „Netzstrom Wärmepumpe" · `heat_pump_grid_kwh` · `ct(heat_pump_cost_eur,
         heat_pump_grid_kwh)` · `eur(heat_pump_cost_eur)` · `--alert` · → `/waerme` („Wärme")
      3. „Netzstrom Wallbox" · `ev_grid_kwh` · `ct(ev_cost_eur, ev_grid_kwh)` ·
         `eur(ev_cost_eur)` · `--alert` · → `/strom/wallbox` („Wallbox")
      4. „Netzstrom Speichergerät" · `battery_device_grid_kwh` ·
         `ct(battery_device_cost_eur, battery_device_grid_kwh)` ·
         `eur(battery_device_cost_eur)` · `--alert` · → `/strom/speicher` („Speicher")
      5. „Pellets" · `de1(heat.stove.pellet_kg, 1) kg` · Preisspalte **leer** ·
         `eur(heat.stove.pellet_eur)` · Ton `var(--stove)` (#b5651d) · → `/waerme` („Wärme")
      6. „Einspeisung" · `de1(export_kwh,0) kWh` · `de1(meta.feed_in_ct_kwh, 2) ct` ·
         **„− 12,34 €"** (U+2212, Leerzeichen, dann `eur`) · Ton `var(--mist)` ·
         → `/geld/pv-abrechnung` („PV-Abrechnung")
      7. „Entgangene Vergütung (Wärmepumpe, Wallbox, Speichergerät)" · Menge und Preis leer ·
         `eur(heat_pump_opportunity_eur + ev_opportunity_eur + battery_device_opportunity_eur)` ·
         Ton `var(--text-3)` · → `/strom/pv` („Photovoltaik")
    `ct(e, kwh)` = `kwh > 0.05 ? de1(e/kwh*100, 1) + " ct" : "-"` (`CostReport.tsx:104`) –
    **eine Stelle**, nicht zwei.
    Darunter eine `Note` über drei Sachen (`CostReport.tsx:215-222`), wörtlich: dass Netzstrom
    Speichergerät der Eigenverbrauch des Wechselrichters ist („bezahlt wurde er immer schon,
    nur stand er nirgends"), dass die Pelletmenge geschätzt ist, und dass die entgangene
    Vergütung „kein Geld, das fehlt" ist, „sondern der Preis dafür, Sonnenstrom selbst zu
    nutzen statt ihn einzuspeisen; sie steht hier, weil sie in den Wärme- und Wallboxkosten
    mitgerechnet wird."
    **Handy** (`handy.css:300-316`, Begründung im Kommentar: „Eine Tabelle mit fünf Spalten hat
    am Handy 60 Punkte je Spalte"): `thead` verschwindet, jede `tr` wird ein zweizeiliges
    Raster `grid-template-areas: "name name betrag" "menge preis seite"`, Spalten
    `auto auto minmax(0,1fr)`, `gap: 3px 12px`, `padding: 12px 0`, oben eine Haarlinie (die
    erste Zeile ohne). Maße: Name 15px und umbrechend, Menge und Preis 13px in `--text-3`,
    **Betrag 17px rechts oben**, Verweis 13px rechts unten.

  * **„Kosten im Zeitraum" – die Spannentabelle** (`CostReport.tsx:225-235`, Baustein
    `apps/web/src/components/reports/PeriodStrip.tsx:32-94`)
    Zeilen = Größen, Spalten = **Tag · Woche · Monat · Jahr des Ankertags**. Die Tagesspalte
    heißt „Heute" nur, wenn der Anker heute ist, sonst „07.11." (`PeriodStrip.tsx:12-16`).
    `CardHead right` = „jeweils bis jetzt" bzw. „jeweils bis 07.11.2026"
    (`PeriodStrip.tsx:34-38`).
    Fünf Zeilen (`CostReport.tsx:228-234`):
      1. „Bezahlt (Netzstrom)" · `eur(totals.import_cost_eur)` · Ton `ember` = `var(--alert)`
      2. „Bekommen (Einspeisung)" · `eur(totals.export_revenue_eur)` · Ton `mist`
      3. „Gespart (Sonne, Speicher)" · `eur(pv_direct_savings_eur + battery_net_eur)` ·
         Ton `amber`
      4. „Netzbezug" · `de1(import_kwh, 0) kWh` · ohne Ton
      5. „Ø Bezugspreis" · `de1(avg_import_price_ct, 1) ct`, bei `null` „-" ·
         **eine Nachkommastelle**
    Fehlt eine Spanne, steht „-" (`CostReport.tsx:98`). Die erste Zeile ist halbfett
    (`fontWeight: i === 0 ? 600 : 400`, `PeriodStrip.tsx:84`), Tabelle 12px,
    `tableLayout: fixed`, erste Spalte 34 %.
    **Handy ist eine andere Ansicht, keine umgebrochene Tabelle** (`PeriodStrip.tsx:42-64`,
    Begründung im Kommentar `PeriodStrip.tsx:28-30`: „Vier Zahlenspalten neben dem Namen der
    Zeile passen nicht auf 390 Punkte"): über der Liste ein Umschalter
    `div.spannen role="tablist"` mit vier Knöpfen, darunter eine `dl.spannen-liste` mit nur
    **einer** Spalte. Maße `handy.css:291-299`: `.spannen` `gap 2px, padding 3px,
    border-radius 11px, background rgba(255,255,255,.07)`; `.spanne` `flex:1, min-height 34px,
    border-radius 8px, 13.5px, font-weight 500, text-2`; `.spanne-an` `background var(--amber),
    color var(--petrol)`; Zeile `padding 11px 0` mit Haarlinie oben (erste ohne),
    `dt` 14,5px text-2, `dd` 16px mono nowrap.

  * **`CoverageNote` am Fuß** (`CostReport.tsx:236`, Baustein `ReportShell.tsx:163-174`)
    Ein zugeklapptes `Methode` (`apps/web/src/components/ui/Methode.tsx:18-29`) mit Titel
    „Wie gerechnet wird". **Sichtbar bleibt die Kurzzeile**
    `"Datenabdeckung 97 % · Aufzeichnung seit 01.03.2026"` bzw. bei `coverage == null`
    „noch keine Messdaten im Zeitraum" (`ReportShell.tsx:166-168`). Aufgeklappt zwei Absätze:
    `extra` = **`heat.stove.note_de`** (`CostReport.tsx:236`) und `meta.estimated_note_de`.
    Begründung im Kommentar (`ReportShell.tsx:155-162` und `Methode.tsx:11-13`): was eine
    Zahl *an diesem Tag* einschränkt, darf nicht hinter dem Deckel verschwinden.
    Maße `globals.css:726-735`: `summary padding 14px 18px`, Kurzzeile 12,5px text-3, Pfeil
    7×7 gedreht, Absätze 13px/1,55 `max-w-90ch`. Am Handy wird die Überschrift lesbare
    Schrift, 15px halbfett, `text-1` (`handy.css:212-216`).

  * **Der Kicker der Seite** (`CostReport.tsx:107`)
    `ReportShell kicker="Was der Zeitraum gekostet hat, in einer Zeile"` landet rechts in der
    Reiterzeile, `.kicker` mit `fontSize: 11` und **`hidden md:block`**
    (`apps/web/src/components/layout/AreaNav.tsx:96`) – am Handy also absichtlich weg, am
    Schirm da. Der Seitentitel „Kosten" steht nur noch im Dokumenttitel und als `sr-only`
    (`ReportShell.tsx:99-100`, `:127`).


LUECKEN
-------

  [traegt-die-seite] Die vier Beträge der Kopfzeile fehlen ganz. Die App zeigt stattdessen
    sechs andere Kacheln (`GeldSeiten.swift:88-114`). „Bezahlt" (Netzstrom **plus Pellets**),
    „Bekommen", „Gespart" (`pv_direct_savings_eur + battery_net_eur`) und „Energie je Tag"
    stehen nirgends; die App nennt an deren Stelle „unterm Strich", „Bezug", „Einspeisung",
    „Wärmepumpe" und „mittlerer Bezugspreis". Damit macht die Seite ihre Hauptaussage nicht:
    „Was der Oktober gekostet hat, in einer Zeile" (`CostReport.tsx:17-20`).

  [traegt-die-seite] Die Karte „Aufstellung" fehlt vollständig (`CostReport.tsx:193-223`).
    Sieben Posten mit Menge, Ø Preis, Betrag und **Verweis auf die Seite, von der die Zahl
    kommt** – das ist laut Kopfkommentar der halbe Zweck der Seite. Dazu gehört die Rechnung
    „Haushalt = Netzbezug minus Wärmepumpe minus Wallbox minus Speichergerät"
    (`CostReport.tsx:101-102`) und die dreiteilige Fußnote.

  [traegt-die-seite] `/energy/heat` wird nicht geholt (`GeldSeiten.swift:15-17` gegen
    `CostReport.tsx:62`). Damit fehlen Pelletkosten und Pelletmenge in zwei Blöcken (Hinweis
    unter „Bezahlt", Posten 5) **und** `stove.note_de` in der Methodenkarte – und „Bezahlt"
    wäre selbst mit Kachel noch falsch, weil die Pellets im Betrag drinstecken
    (`CostReport.tsx:66-67`).

  [traegt-die-seite] Die Spannentabelle „Kosten im Zeitraum" fehlt vollständig
    (`CostReport.tsx:225-235`), und mit ihr die vier parallelen Abfragen
    (`useMultiPeriod`, `useReport.ts:149-171`). Fünf Größen × vier Spannen = ein ganzer
    Abschnitt der Vorlage.

  [spuerbar] Die Karte „Woraus die Ersparnis besteht" fehlt (`CostReport.tsx:124-148`): zwei
    Leisten auf gemeinsamer Skala plus der Satz, der sagt, wogegen gerechnet wird.

  [spuerbar] Der Vergleichslauf ist anders gebaut. Die Vorlage führt mit **einer** Zahl in
    40px plus zwei erklärenden Zeilen (`CostReport.tsx:156-173`); die App zeigt eine Liste aus
    fünf Zeilen, darunter `actualEur` und `naiveEur`, die in der Vorlage **nicht vorkommen**
    (`GeldSeiten.swift:26-27`). Es fehlen: der Satz „gespart/mehr bezahlt gegenüber einem Lauf
    ohne Preisblick", die Detailzeile mit `days_used`/`days_skipped`/`skipped_de`, und der
    Leersatz „Für diesen Zeitraum reicht es nicht für eine Aussage." bei `days_used == 0`.

  [spuerbar] Das Tagesdiagramm des Vergleichslaufs hat **eine** Serie in `Farbe.mist`
    (`GeldSeiten.swift:46-54`); die Vorlage hat zwei, „gebracht" in `C.pv` und „gekostet" in
    `C.alert`, ausdrücklich damit in der Legende steht, was ein Vorzeichen bedeutet
    (`CostReport.tsx:85-93`). Zudem filtert die App Tage mit `noteDe` nicht heraus
    (`CostReport.tsx:88`) und zeichnet bei leerem Ergebnis einen Leersatz, wo die Vorlage
    nichts zeichnet (`CostReport.tsx:175`).

  [spuerbar] Falsche Farbe im Hauptdiagramm: „Bezug" steht in `Farbe.netzBezug` = `mist`
    #7FA3B3 (`GeldSeiten.swift:62`, `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift:51`),
    die Vorlage nimmt `C.alert` #E0533D (`CostReport.tsx:78`, `palette.ts:76`). Im Kern liegt
    der richtige Wert als `Marken.diagrammNetz` (#E0533D, `Marken.swift:131`) schon bereit.

  [spuerbar] Keine Legende an den Diagrammen in der Form der Vorlage. `Balkenbild` setzt
    `chartLegend(position: .top, alignment: .leading)` (`Bericht.swift:120`), die Vorlage setzt
    die Legende in die **Kopfzeile der Karte** rechts (`CostReport.tsx:121`, `:154`) und lässt
    das Diagrammfeld frei.

  [spuerbar] Die Methodenkarte hat kein `kurz:` (`GeldSeiten.swift:78`). Die Datenabdeckung und
    „Aufzeichnung seit" sind damit hinter dem Deckel bzw. gar nicht da – genau das, was
    `ReportShell.tsx:155-162` ausdrücklich verbietet. Die App hat für denselben Satz schon
    `Waermeuebersicht.abdeckungssatz` (`Waermeuebersicht.swift:332-344`), und die Stromseite
    macht es richtig vor (`apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:37-43`).

  [spuerbar] Die Annahmen des Vergleichslaufs liegen in der App im Rumpf der Methodenkarte
    (`GeldSeiten.swift:83`). In der Vorlage sind sie ein eigenes, zugeklapptes `<details>` in
    der Vergleichslaufkarte mit der Überschrift „Annahmen des Vergleichslaufs"
    (`CostReport.tsx:181-190`) – sie gehören zu der Zahl, neben der sie stehen.

  [klein] Achsenwörter im Tagesdiagramm: die App setzt das rohe `$0.day` („2026-11-07",
    `GeldSeiten.swift:50`), die Vorlage „07.11." (`CostReport.tsx:90`). `Tag.kurz`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Tag.swift:94`) ist da.

  [klein] Leersatz des Hauptdiagramms: App „Keine Werte in diesem Zeitraum."
    (`Bericht.swift:101`), Vorlage „Für diesen Zeitraum liegen keine bewerteten Stunden vor."
    (`CostReport.tsx:122`).

  [klein] Kartenüberschriften weichen wörtlich ab: „Nach Zeitraum" gegen „Bezahlt und
    bekommen"; „Nach Tagen" + „Der Vergleichslauf / Was der Preisblick gebracht hat" gegen die
    eine Karte „Was das Verschieben gebracht hat"; es fehlt „Aufstellung" mit der rechten Zeile
    „Beträge in Euro · aus denselben Stundenbilanzen wie alle anderen Seiten"
    (`CostReport.tsx:194`).

  [klein] Serienname „Einspeisevergütung" (`GeldSeiten.swift:66`) gegen „Einspeisung"
    (`CostReport.tsx:80`).

  [klein] „Ø Bezugspreis" steht in der Vorlage mit **einer** Stelle (`CostReport.tsx:233`), die
    App zeigt „mittlerer Bezugspreis" mit zwei (`GeldSeiten.swift:109`).

  [klein] Maß der nicht führenden Kachelzahl: die Vorlage setzt am Schirm 34px
    (`CostReport.tsx:37`), `Kachel` nimmt 25px (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:240`).
    Und am iPad stehen die vier Beträge in der Vorlage in **einer** Reihe mit senkrechten
    Haarlinien (`CostReport.tsx:111`), `Kachelfeld` hat `spalten: 2`
    (`Karte.swift:279`) und waagerechte Linien (`Karte.swift:311`).

  [klein] Der Seitenkicker „Was der Zeitraum gekostet hat, in einer Zeile" steht in der App
    nirgends. Gesucht nach `kicker`/`untertitel` in `apps/ios/DuckCurveHome/App/Reiterzeile.swift`,
    `WandRahmen.swift`, `HandRahmen.swift`: kein Treffer. (Betrifft alle Berichtsseiten, nicht
    nur diese.)

  [klein] Kein Tooltip mit „Summe" an den Balken (`charts.ts:376-385`). Swift Charts hat in
    diesem Projekt bisher keine Berührungsabfrage an `Balkenbild` (`Bericht.swift:99-148`).


KERN: SCHON DA (nachgesehen, nicht geraten)
-------------------------------------------

Abfragen – `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift`:
  * `energieUebersicht(_ zeitraum: String, anker: String) -> EnergySummaryOut` – `Api.swift:179`
  * `energieVerschiebung(...) -> ShiftReportOut` – `Api.swift:184`
  * `energieWaerme(...) -> HeatReportOut` – `Api.swift:188` (**liegt bereit, wird von
    `/geld` nicht gerufen**)

Modelle – `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift`:
  * `EnergySummaryOut` – `Schema.swift:2942` (`totals`, `buckets`, `meta`, `period`, `anchor`)
  * `EnergyTotalsOut` – `Schema.swift:2974`; alle Felder der Vorlage sind da und optional:
    `minutes`, `importKwh`, `exportKwh`, `importCostEur`, `exportRevenueEur`,
    `heatPumpCostEur`, `heatPumpGridKwh`, `heatPumpOpportunityEur`, `evCostEur`, `evGridKwh`,
    `evOpportunityEur`, `batteryDeviceCostEur`, `batteryDeviceGridKwh`,
    `batteryDeviceOpportunityEur`, `pvDirectSavingsEur`, `batteryNetEur`, `avgImportPriceCt`
  * `EnergyMetaOut` – `Schema.swift:2832`: `coverage`, `dataSince`, `estimatedNoteDe`,
    `feedInCtKwh`
  * `ShiftReportOut` – `Schema.swift:7668`: `actualEur`, `naiveEur`, `savingEur`,
    `savingCtPerKwh`, `heatPumpKwh`, `shiftedKwh`, `days`, `daysUsed`, `daysSkipped`,
    `skippedDe`, `methodDe`, `assumptionsDe`
  * `ShiftDayOut` – `Schema.swift:7629`: `day`, `savingEur`, `heatPumpKwh`, `shiftedKwh`,
    `noteDe`
  * `HeatReportOut` – `Schema.swift:4184`, darin `stove: StoveOut`
  * `StoveOut` – `Schema.swift:8085`: `pelletKg`, `pelletEur`, `noteDe` (alle optional)

Rechnungen und Sätze:
  * `Waermeuebersicht.abdeckungssatz(_ m: EnergyMetaOut) -> String` –
    `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Waermeuebersicht.swift:332`
    (baut genau die Kurzzeile von `CoverageNote`)
  * `Waermeuebersicht.spannenzeilen(_ je: [Spanne: HeatBalanceOut])` – `Waermeuebersicht.swift:280`
    (das Muster für eine Spannentabelle, Rückgabe `[(wort, werte)]`)
  * `Kennzahl` mit `wort/wert/einheit/dazu/ton` – `Zustand/Kennzahl.swift:15-50`;
    Töne `normal, sonne, glut, bernstein, gedaempft, nebel` (`:38-50`)

Formate – `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/`:
  * `Formate.euro(_:stellen:)` – `Formate.swift:99`; `Formate.zahl(_:stellen:)` – `:44`;
    `Formate.kwh` – `:75`; `Formate.prozent` – `:81`; `Formate.minus` (U+2212) – `:25`;
    `Formate.leer` = „-" – `:27`
  * `Tag.kurz(_:)` – `Formate/Tag.swift:94`; `Tag.lang(_:)` – `:87`; `Tag.istTag(_:)` – `:26`
  * `Spanne` mit `rawValue` day/week/month/year und `name` – `Formate/Zeitraum.swift:9-23`

Farben und Maße – `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift`,
Übersetzung `apps/ios/DuckCurveHome/Gestalt/Farben.swift`:
  * `Marken.amber` #F2A900 (`:18`) = `Farbe.amber` = `C.pv`/`--amber`
  * `Marken.amberWeich` #FFD778 (`:19`) = `Farbe.netzEinspeisung` (`:52`) = das `#ffd778`
    der Einspeisungsserie
  * `Marken.mist` #7FA3B3 (`:20`) = `Farbe.mist` = `--mist`
  * `Marken.alarm` #E0533D (`:99`) = `Farbe.alarm` = `--alert` = `C.alert`
  * `Marken.diagrammNetz` #E0533D (`:131`) – die Netzfarbe **im Diagramm**
  * `Marken.ofen` #B5651D (`:70`) = `Farbe.ofen` = `--stove` (Ton des Pelletpostens)
  * `Farbe.text1/2/3`, `Farbe.linie1/2`, `Farbe.flaeche2/3` – `Farben.swift:43-50`

Bausteine der Oberfläche:
  * `Berichtsseite` (Laden, Fehler, altes Bild stehen lassen) –
    `apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-64`
  * `Balkenbild` (gestapelt/ungestapelt, Einheit, Achsenwörter gedünnt) – `Bericht.swift:70-149`
  * `Tabelle` (am Telefon Liste, `immerSichtbar`, Farbe je Zelle) – `Bericht.swift:157-327`
  * `Methode(_ saetze:kurz:titel:)` – `Bericht.swift:334-397`
  * `Karte(kicker:titel:beiwerk:)` – `apps/ios/DuckCurveHome/Gestalt/Karte.swift:15-113`
    (`beiwerk: AnyView?` ist der Platz für eine Legende rechts im Kopf)
  * `Kacheldaten` mit `wort/wert/einheit/dazu/farbe/weg` – `Karte.swift:121-151`;
    `weg` macht die Kachel zum Knopf (`Karte.swift:181-184`)
  * `Kachelfeld(kacheln:kicker:ersteFuehrt:spalten:art:)` – `Karte.swift:274-343`;
    erste Kachel führend am Telefon (`:290-299`), führende Zahl 48pt (`:240`)
  * `Zeile(wort:wert:einheit:dazu:farbe:)` – `Karte.swift:360-383`
  * `Leer(satz:dazu:)` – `Karte.swift:390-404`; `Stoerung` – `Karte.swift:410-436`
  * `Schrift.*` – `apps/ios/DuckCurveHome/Gestalt/Typografie.swift:17-102`;
    `Kicker` (Sperrschrift) – `:132-141`; `Zahl` (Wert + Einheit) – `:109-129`
  * `Wegweiser.gehe(_:)` – `apps/ios/DuckCurveHome/App/Navigation.swift:35`; die sechs
    Zielwege der Aufstellung sind alle eingetragen
    (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:38-56`)
  * Vorbild für vier Spannen auf einmal: `holeSpannen(anker:api:)` mit `withTaskGroup` und
    `try?` je Spanne – `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift:47-61`,
    und seine Anzeige `spannenvergleich(_:)` – `WaermeSeite.swift:313-320`


ES FEHLT
--------

1. **`Zustand/Geldübersicht.swift`** im Kern (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/`):
   `public enum Geldübersicht` mit der ganzen Arithmetik der Seite, damit sie geprüft werden
   kann – heute steht sie in `CostReport.tsx:66-104` und in der App nirgends.
   - `public static func kopfzahlen(_ b: EnergySummaryOut, waerme: HeatReportOut?) -> [Kennzahl]`
     – die vier Beträge, Töne `bernstein`/`nebel`/`sonne`/`normal` entsprechend
     `--alert`/`--mist`/`--amber`/`--text-1`. **Achtung:** `Kennzahl.Ton` hat heute keinen Wert
     für „alert/rot" (`Kennzahl.swift:38-50`, `Farbe.ton` `Farben.swift:98-107`) – entweder
     `case alarm` ergänzen oder die Farbe wie in `GeldSeiten.swift:97` an der Ansicht setzen.
   - `public struct Posten: Sendable, Identifiable { wort, menge, preis, betrag, ton, weg, seite }`
     und `public static func aufstellung(_ b: EnergySummaryOut, waerme: HeatReportOut?) -> [Posten]`
     – die sieben Zeilen samt `haushaltCost`/`haushaltKwh`-Abzug und der Einspeisungszeile mit
     `Formate.minus`.
   - `public static func ctJeKwh(_ eur: Double?, _ kwh: Double?) -> String` – die Regel
     `kwh > 0.05` aus `CostReport.tsx:104`, eine Stelle.
   - `public static func ersparnisteile(_ t: EnergyTotalsOut) -> [(wort: String, wert: Double, anteil: Double)]`
     – die zwei Leisten auf gemeinsamer Skala (`max(0.01, …)`, `CostReport.tsx:130`).
   - `public static func verschiebungssatz(_ v: ShiftReportOut?) -> (zahl: String, satz: String, dazu: String?)`
     – die drei Textzeilen aus `CostReport.tsx:158-172`, inklusive Singular/Plural „Tag/Tage"
     und des Leersatzes bei `daysUsed == 0`.
   - `public static func spannenzeilen(_ je: [Spanne: EnergySummaryOut]) -> [(wort: String, werte: [String])]`
     – nach dem Muster `Waermeuebersicht.swift:280-301`, die fünf Zeilen aus
     `CostReport.tsx:228-234`.
   Dazu `Tests/DuckCurveKitTests/GeldübersichtTests.swift` nach dem Muster von
   `WaermeuebersichtTests.swift`.

2. **`Marken` um die Postenfarbe erweitern oder `Farbe.ofen` benutzen** – nachgesehen: #B5651D
   ist als `Marken.ofen` da (`Marken.swift:70`), es fehlt nichts. Kein Kernbedarf.

3. **Ein Baustein für eine Tabelle mit Verweisspalte.** `Tabelle` (`Bericht.swift:157-327`)
   kennt nur Zeichenketten und Farben, keinen Weg. Entweder `Tabelle.Spalte` um
   `wege: [String?]` erweitern oder – näher an `handy.css:305-316` – ein eigener Baustein
   `Postenliste` in `apps/ios/DuckCurveHome/Bausteine/`. Gehört in die Oberfläche, nicht in den
   Kern.

4. **Ein Baustein für die waagerechte Anteilsleiste** („Woraus die Ersparnis besteht"). Gesucht
   nach `ProgressView`/`Fortschritt` in `apps/ios/DuckCurveHome`: kein Treffer; das Nächste ist
   die Kapsel in `apps/ios/DuckCurveHome/Diagramme/Wirkungszeichnung.swift:73`. Neu:
   `Anteilsleiste` in `apps/ios/DuckCurveHome/Bausteine/`.

5. **Ein Baustein für die Spannentabelle am Telefon** (`.spannen`-Umschalter plus eine Spalte).
   `Tabelle` mit `immerSichtbar: 1` kommt dem nahe, setzt den Umschalter aber als Pillenreihe
   mit `Farbe.amberWeich` (`Bericht.swift:211-228`); die Vorlage nimmt `--amber` auf
   `--petrol` in einer Fläche `rgba(255,255,255,.07)` (`handy.css:291-293`). Entweder
   `Tabelle` dort angleichen oder `Ansichtswahl`
   (`apps/ios/DuckCurveHome/Gestalt/Ansichtswahl.swift`) darüber setzen.

6. **`Balkenbild` braucht zwei Dinge:** eine Legende, die man **ausschalten** kann (damit sie in
   `Karte.beiwerk` wandern kann, `Karte.swift:19`), und eine freie Höhe für das 150-Punkt-Feld
   des Tagesdiagramms – `hoehe` gibt es schon (`Bericht.swift:81`).


BAUPLAN
-------

Reihenfolge wie in der Vorlage. Alles in
`apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift` (`KostenSeite`, `:10-115`), sofern nicht
anders genannt.

1. **Neu: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Geldübersicht.swift`** mit den
   sechs Funktionen aus „ES FEHLT 1", plus Test.
2. **Abfrage erweitern** (`GeldSeiten.swift:12-21`): neben `energieUebersicht` und
   `try? energieVerschiebung` auch `try? api.energieWaerme(...)` (`Api.swift:188`) und eine
   `holeSpannen`-Gruppe über `Spanne.allCases` mit `try? api.energieUebersicht` je Spanne –
   wörtlich nach `WaermeSeite.swift:47-61`. Der Rückgabetyp wird ein eigenes
   `struct Kostendaten: Sendable` (wie `Waermedaten`, `WaermeSeite.swift:13-18`); dann fällt
   auch die Typangabe am `inhalt:`-Schluss weg, die der Kommentar `GeldSeiten.swift:18-20`
   begründet – **dieser Kommentar muss mitwandern**, sonst kehrt der Fehler zurück.
3. **Kopfzeile**: `Kachelfeld(kacheln: Geldübersicht.kopfzahlen(...).map(Kacheldaten.init),
   kicker: "Geld", spalten: 4)` – vier Beträge, erster führend. Die alte `kennzahlen(_:_:)`
   (`GeldSeiten.swift:88-114`) entfällt. Für das Maß 34pt am iPad braucht `Kachel.schrift`
   (`Karte.swift:234-242`) im Fall `.bericht`/nicht führend 34 statt 25.
4. **Karte „Bezahlt und bekommen"**: die heutige Karte „Nach Zeitraum"
   (`GeldSeiten.swift:58-74`) umbenennen, Serienname „Einspeisevergütung" → „Einspeisung",
   Farbe `Farbe.netzBezug` → `Color(Marken.diagrammNetz)` (also `Farbe.alarm`/#E0533D), und
   bei leeren `buckets` den Satz der Vorlage setzen (statt `Balkenbild`s eigenem Leersatz):
   `Leer(satz: "Für diesen Zeitraum liegen keine bewerteten Stunden vor.")`.
   Legende nach `Karte(beiwerk:)`.
5. **Karte „Woraus die Ersparnis besteht"** – neu, direkt darunter: zwei `Anteilsleiste` aus
   `Geldübersicht.ersparnisteile`, Farben `Farbe.pv` und `Farbe.batterie`
   (**nachsehen:** `C.battery` ist #7FA3B3 = `Marken.mist`, `Marken.batterie` ist #4F7B88 –
   die Vorlage nimmt im Diagramm `C.battery` aus `palette.ts:36`, also `Farbe.mist`), plus der
   Absatz aus `CostReport.tsx:144-147` wörtlich.
   Am iPad stehen 4 und 5 in der Vorlage nebeneinander (8fr/4fr, `CostReport.tsx:119`); am
   Telefon untereinander. In SwiftUI: `ViewThatFits` oder `horizontalSizeClass`, Vorbild
   fehlt – siehe „WAS SCHWIERIG WIRD".
6. **Karte „Was das Verschieben gebracht hat"** – die zwei heutigen Karten
   (`GeldSeiten.swift:24-56`) zu einer zusammenlegen:
   links `Geldübersicht.verschiebungssatz` als 40pt-Zahl (`Schrift.zahlFuehrend`,
   `Typografie.swift:96`) plus zwei Textzeilen; rechts `Balkenbild(hoehe: 150)` mit zwei
   Stücken „gebracht"/`Farbe.pv` und „gekostet"/`Farbe.alarm` über
   `v.days.filter { $0.noteDe == nil }`, Achsenwort `Tag.kurz($0.day)`; darunter
   `Text(v.methodDe)`; darunter ein `DisclosureGroup` „Annahmen des Vergleichslaufs" mit
   `v.assumptionsDe`. `actualEur`/`naiveEur` entfallen.
7. **Karte „Aufstellung"** – neu, mit `Postenliste` aus „ES FEHLT 3" über
   `Geldübersicht.aufstellung`, Kopfzeile rechts „Beträge in Euro · aus denselben
   Stundenbilanzen wie alle anderen Seiten", darunter die dreiteilige Fußnote
   (`CostReport.tsx:215-222`) wörtlich. Tippen auf eine Zeile → `wegweiser.gehe(posten.weg)`.
8. **Karte „Kosten im Zeitraum"** – neu, `Tabelle` über `Geldübersicht.spannenzeilen`,
   Spalten `Spanne.allCases.map(\.name)`, erste Spalte halbfett. Die Kopfzeile rechts „jeweils
   bis jetzt"/„jeweils bis 07.11.2026" (`PeriodStrip.tsx:34-38`); die Tagesspalte heißt „Heute"
   nur am Ankertag heute (`PeriodStrip.tsx:12-16`) – das gehört in `Geldübersicht`, nicht in
   die Ansicht.
9. **Methode am Fuß** (`GeldSeiten.swift:78-84`): `kurz:
   Waermeuebersicht.abdeckungssatz(paar.kosten.meta)` ergänzen (`Waermeuebersicht.swift:332`),
   `waerme?.stove.noteDe` als Satz aufnehmen, und `assumptionsDe` hier **entfernen** – die
   stehen nach Schritt 6 in ihrer eigenen Karte. Der Kommentar `GeldSeiten.swift:75-77` über
   `[Any]` bleibt gültig und bleibt stehen.


WAS SCHWIERIG WIRD
------------------

* **Zwei Karten nebeneinander (8fr/4fr).** `report-row` mit `--cols`
  (`globals.css:108`, `CostReport.tsx:119`) hat in der App kein Gegenstück: `Seite` setzt eine
  einzige Spalte (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:152-168`, `VStack` in einer
  `ScrollView`), und **keine** der bestehenden Seiten legt zwei Karten nebeneinander – gesucht
  nach `HStack` mit zwei `Karte` in `apps/ios/DuckCurveHome/Seiten/`: kein Treffer. Der im
  Projekt gewählte Weg ist, nach `horizontalSizeClass` zu verzweigen (`Karte.swift:22-24`,
  `Bericht.swift:83-84`, `Tabelle.schmal` `Bericht.swift:189`). Also: am Telefon
  untereinander, am iPad ein `HStack` mit `frame(maxWidth: .infinity)` im Verhältnis 2:1 –
  `GridRow` wäre näher an `8fr 4fr`, kommt aber im Projekt bisher nicht vor.
* **Senkrechte Haarlinien zwischen den vier Beträgen** (`divide-x divide-line-1`,
  `CostReport.tsx:111`). `Kachelfeld` trennt nur waagerecht (`Divider()`, `Karte.swift:311`).
  Vorbild für eine senkrechte Trennung im Projekt:
  `apps/ios/DuckCurveHome/Seiten/Haus/Hauskonsolenleiste.swift:84` setzt einen farbigen
  Streifen an den linken Rand eines Blocks – dasselbe Mittel, nur in `Farbe.linie1`.
* **Tooltip „Summe" an den Balken** (`charts.ts:376-385`). Swift Charts kann das mit
  `chartOverlay` und `ChartProxy.value(atX:)`, aber `Balkenbild` (`Bericht.swift:70-149`) hat
  bisher keine Berührungsabfrage, und im ganzen Ordner `Diagramme/` gibt es kein Vorbild für
  einen Balken-Tooltip. Der im Projekt gewählte Weg bei Diagrammen ohne Berührung ist, die
  Zahl **daneben** auszuschreiben – so macht es die Pufferbilanz
  (`WaermeSeite.swift:326-348`: Zeilen statt Tooltip). Vorschlag: nicht bauen, als bewusste
  Lücke notieren.
* **Negative Balken in einem gestapelten Diagramm.** Die Vorlage stapelt „Netzstrom" (positiv)
  und „Einspeisung" (negativ) auf `stack: "total"` (`charts.ts:393`); Swift Charts stapelt bei
  `stacking: .standard` positive und negative Werte getrennt um die Nulllinie – das Bild
  stimmt, aber die y-Achse muss die Null zeigen. `Balkenbild` setzt dafür heute nichts
  (`Bericht.swift:121-132`, `AxisMarks(values: .automatic(desiredCount: 4))`); das Verhalten
  ist an der Wallbox-/Speicherseite noch nicht erprobt – nachsehen, bevor es als fertig gilt.
* **`line-clamp-2` am Hinweistext der Beträge** (`CostReport.tsx:40`, am Telefon 3 Zeilen,
  `handy.css:358`). `Kachel.hinweis` hat `lineLimit(2)` fest (`Karte.swift:261`); für die
  dritte Zeile am Telefon müsste das von `horizontalSizeClass` abhängen.
* **`<details>` für die Annahmen.** `DisclosureGroup` ist im Projekt schon gewählt
  (`Bericht.swift:361`, `Methode`); hier wird es ein zweites, **innerhalb** einer Karte – das
  kommt bisher nicht vor, aber `Methode` zeigt, wie Titel, Pfeil und `tint(Farbe.text3)`
  gesetzt werden (`Bericht.swift:358-394`).
