========================= messen:geld-rechnungen   Aufwand: gross

Vorlage: `apps/web/src/app/geld/rechnungen/page.tsx:1-9` → `InvoiceCheck`
(`apps/web/src/components/reports/InvoiceCheck.tsx:1-341`), Diagramme in
`apps/web/src/components/reports/charts.ts:279-367`.
App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:12-233`,
eingehängt in `apps/ios/DuckCurveHome/App/Seitenwahl.swift:56`.
Reiter: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:122`
(`/geld/rechnungen`, „Rechnungen", `nurHausherr: true`) - stimmt mit `requireOwner()`
(`page.tsx:7`) überein.


IST: Was die App-Seite heute von oben nach unten zeigt

1. `Seite { }` ohne Zeitraumleiste (`RechnungenSeite.swift:22`, Hülle
   `App/Seitenwahl.swift:141-174`: ScrollView, 16 pt Rand, 14 pt Abstand). Kein Seitenkicker.
2. `Stoerung(fehler:)` nur für den Listenfehler, mit „Erneut" (`:23-25`;
   Baustein `Gestalt/Karte.swift:410-436`).
3. Leerzustand, nur wenn Liste leer und nicht lädt und kein Fehler (`:26-33`):
   Karte mit `Leer(satz: "Es sind keine Rechnungen eingelesen.", dazu: "Rechnungen kommen
   über den Dienst herein - siehe docs/RECHNUNGSPRUEFUNG.md.")`.
4. Karte `kicker: "Rechnungen"` (`:35-42`): je Rechnung eine Knopfzeile, getrennt durch
   `Divider().overlay(Farbe.linie1)`. Zeile (`:52-73`): links `periodLabel`
   (`Schrift.klein`, 13 pt, `Farbe.text1`) und „Nr. <number> · <issuedOn>"
   (`Schrift.winzig`, 11,5 pt, `text3`); rechts `Formate.euro(totalGrossEur)`
   (`Schrift.zahl`, Mono 15 pt) und darunter das Urteil. 7 pt senkrechte Polsterung.
   Tippen wählt bzw. wählt ab (`:54`).
5. Urteil (`:86-102`): `Rechnungsurteil.aus(wort)`; bei `warning`/`error` und
   `problems > 0` steht „1 Befund"/„n Befunde" **statt** des Wortes, sonst das Wort.
   Farben: error/warning `Farbe.alarm`, info `Farbe.mist`, ok `Farbe.text3`.
   Unbekanntes Wort roh in `text3`.
6. Nur bei gewählter Rechnung (`:44-46`, `:104-151`):
   * `Kachelfeld(kacheln: kennzahlen(b), kicker: "Nr. <number>")` - sechs Kacheln
     (`:199-211`): brutto (dazu `periodLabel`), abgerechnet kWh, mittlerer Preis ct/kWh,
     Energie netto, Gebühren netto, Umsatzsteuer.
   * Karte „Was aufgefallen ist" mit allen Befunden in Eingangsreihenfolge, 12 pt Abstand
     (`:108-115`); Befundzeile `:172-197`: 6-pt-Kreis, Titel 13 pt `text1`, Detail 11,5 pt
     `text3`, darunter „erwartet x <unit>" / „auf der Rechnung y <unit>" in `Schrift.zahlKlein`
     (Mono 12,5 pt), sobald **einer** der beiden Werte da ist.
   * Karte „Was das Haus gemessen hat" (`:116-129`): drei `Zeile`n - Bezug kWh,
     abgedeckter Zeitraum (`Formate.prozent`), mittlerer Preis ct/kWh.
   * Karte „Positionen" (`:130-143`): `Tabelle` mit Zeilennamen = Positionsnamen und zwei
     Spalten „ct/kWh" (Stellen aus `ctDecimals`) und „Betrag" (`Formate.euro`).
   * `Methode([...])` (`:144-149`): „Geprüft am <checkedAt>.", bei `alreadyKnown == true`
     „Diese Rechnung war schon eingelesen.", und der Satz „Verglichen werden Zeitraum, Menge
     und mittlerer Preis gegen die eigenen Minutenwerte. Eine Abweichung ist eine Frage, kein
     Beweis." Dieser Block steht **nicht** in der Vorlage.
7. Laden (`:213-232`): `haus.api.rechnungen()` beim Erscheinen, `haus.api.rechnung(nummer)`
   bei Wechsel der Auswahl - letzteres mit `try?`, der Fehler wird verworfen (`:231`).
   Kein Hochladen, kein `pruefeRechnung`.


VORLAGE:

  * **Hülle: `AreaShell` mit Kicker, ohne Zeitraumwahl**  (`InvoiceCheck.tsx:205`)
    `kicker="Tibber · nachgerechnet und gegen die eigene Messung gehalten"`, `right={undefined}`.
    Diese Seite benutzt also **nicht** `ReportShell`: keine Spannen, keine Datumspfeile
    (`ReportShell.tsx:97-134` wird nicht aufgerufen). Hülle:
    `components/layout/AreaShell.tsx:14-32` - Kopf, Reiter, Ansichten, Inhalt, Fußleiste;
    Seitenrand 20 px, Abstand 16 px (`p-5 gap-4`).
    Handy (`styles/handy.css:110-111`): Rand `10px 16px calc(86px + safe-area)`, Abstand 14 px,
    Grundschrift 15 px; Bereichsleiste nach unten (`:114-134`), Bereichsname 26 px halbfett
    (`:141`).
    DATEN: keine.

  * **Fehlerband**  (`InvoiceCheck.tsx:207`, Baustein `ReportShell.tsx:147-153`)
    Mono, 12 px, Großbuchstaben, Sperrung .1em, Radius 3 px, Rahmen `rgba(224,83,61,.4)`,
    Fläche `rgba(224,83,61,.12)`, Schrift `var(--alert)` = #E0533D, Polsterung 16/12 px.
    Es ist **ein** Fehlerzustand für beide Abfragen und das Hochladen: Liste
    („Rechnungen konnten nicht geladen werden.", `:108`), Bericht („Rechnung konnte nicht
    geladen werden.", `:123`) und je Datei „<Dateiname>: <Meldung>" mit „ · " verbunden
    (`:147`, `:154`).
    DATEN: keine.

  * **Zeile 1, links: Karte „Rechnung prüfen"**  (`InvoiceCheck.tsx:209-218`)
    `report-row` mit `--cols: "5fr 7fr"` (`globals.css:108`), Lücke 16 px; am Handy eine
    Spalte mit 14 px (`handy.css:209`, `globals.css:350`).
    Karte: `padding: 16, gap: 12` über der Vorgabe `padding 20`, Fläche `--surface-2`
    (#123544), Rahmen `--line-1` (weiß 10 %), Radius `--radius-2` = 3 px
    (`globals.css:67-77`, `tokens.css:24,27,93`). Am Handy: kein Rahmen, Radius 16 px,
    Polsterung 16 px (`handy.css:182`).
    Kopf `CardHead` (`components/ui/Card.tsx:20-29`): Titel als `.kicker` - Mono 13 px,
    Sperrung .13em, Großbuchstaben, `--text-kicker` = `--mist` #7FA3B3
    (`globals.css:57-64`); rechts 12 px `--text-3`, `truncate`. Hier rechts:
    `busy ? "läuft" : "<n> gespeichert"`.
    Am Handy wird aus dem Kicker eine Überschrift: Sans 16,5 px, halbfett, Sperrung -.01em,
    keine Großbuchstaben, `--text-1` (`handy.css:184`); die rechte Angabe fällt auf eine
    eigene Zeile mit 13 px (`handy.css:185`).
    DATEN: `items.length` aus `api.tibberInvoices()`.

  * **Ablegefeld (`DropZone`)**  (`InvoiceCheck.tsx:54-93`, benutzt `:212`)
    Gestrichelter Rahmen 1,5 px `--line-2` (weiß 17 %), beim Überziehen `--amber` #F2A900 und
    Fläche `rgba(242,169,0,.07)`; Radius 3 px; Polsterung `16px`, wenn schon Rechnungen da
    sind, sonst `34px 20px` (`:80-84`). Mitte, Abstand 6 px (`gap-1.5`).
    Texte wörtlich: 14 px `--text-1` „Tibber-Rechnung hierher ziehen", während des Prüfens
    „Rechnung wird geprüft …"; darunter 12 px `--text-3` „oder klicken, um PDFs auszuwählen -
    mehrere auf einmal möglich", während des Prüfens „Positionen werden nachgerechnet".
    Verhalten: Ziehen **und** Klicken **und** Tastatur (Enter/Leerzeichen, `role="button"`,
    `tabIndex=0`), mehrere Dateien, gefiltert auf `application/pdf` oder Endung `.pdf`
    (`:58`). Die Dateien werden **einzeln nacheinander** geprüft, der **letzte** Bericht wird
    gezeigt und ausgewählt, Fehlschläge gesammelt, danach die Liste neu geholt (`:137-159`).
    DATEN: `POST /import/tibber-invoice?file_name=…`, Rumpf = das PDF,
    `content-type: application/pdf` (`lib/api/client.ts:153-158`) → `InvoiceReport`.

  * **Hinweis unter dem Ablegefeld (`Note`)**  (`InvoiceCheck.tsx:213-217`)
    `Note` = 12 px, Zeilenhöhe 1.55, `--text-3`, höchstens 90 Zeichen je Zeile
    (`ReportShell.tsx:143-145`; die Begründung steht im Kommentar `:136-142`: über die volle
    Breite eines 1440er Schirms wurden es 200 Zeichen je Zeile und „beim Zeilenwechsel findet
    das Auge dann den Anfang der nächsten Zeile nicht wieder").
    Wortlaut: „Geprüft werden alle Positionen der Rechnung gegen Menge und Preis, die Summen,
    die Mehrwertsteuer, die Grundgebühr nach Tagen sowie der Anschluss an die Vorrechnung.
    Zusätzlich vergleichen wir die abgerechnete Menge mit unserem gemessenen Netzbezug. Das
    PDF selbst wird nicht gespeichert."
    DATEN: keine.

  * **Zeile 1, rechts: vier Kennzahlkacheln**  (`InvoiceCheck.tsx:219-224`)
    `kpi-grid` mit `--cols: 2`: `repeat(auto-fit, minmax(clamp(150px, 100%/2 - 16px, 260px),
    1fr))`, Lücke 16 px (`globals.css:107`). Kachel `Stat`
    (`components/ui/Stat.tsx:4-19`): Polsterung `14px 18px`, Abstand 6 px; Kicker 11 px;
    Zahl Mono 26 px, Zeilenhöhe 1, Sperrung -.02em; Einheit 13 px `--text-3` in Sans;
    Kontextzeile 12 px, Zeilenhöhe 1.35, höchstens zwei Zeilen.
    Töne: `amber` → `--amber`, `ember` → `--alert`, sonst `--text-1` (`Stat.tsx:5`).
    Die vier, wörtlich:
      1. „Geprüfte Rechnungen" = `items.length`; dazu „<erste period_label> bis
         <letzte period_label>" aus der **chronologisch** sortierten Liste, sonst „noch keine".
      2. „Beanstandet" = Anzahl mit `verdict` `error` oder `warning` (`:194`);
         Ton `ember`, wenn > 0, sonst `amber`; dazu „Befunde unten ansehen" bzw.
         „keine Auffälligkeit".
      3. „Summe brutto" = `eur(Σ total_gross_eur)`; dazu „über <Σ kwh, 0 Stellen> kWh".
      4. „Ø Preis brutto" = `Σ(avg_ct_kwh_gross · kwh) / Σ kwh`, zwei Stellen, Einheit
         „ct/kWh", Ton `amber`, dazu „mengengewichtet über alle Rechnungen"; bei
         `Σ kwh == 0` ein „-" (`:223`).
    Zahlenformate: `de1` = `toLocaleString("de-DE")` mit fester Stellenzahl,
    `eur` = `de1(n,2) + " €"` (`ReportShell.tsx:14-15`).
    Handy-Fassung (`handy.css:194-207`) - **die Vorlage lässt hier nicht weg, sie ordnet um:**
    aus vier Rahmen wird **eine** Fläche `--surface-2`, Radius 16 px, Polsterung `4px 16px`,
    zwei Spalten, Spaltenabstand 20 px, kein Zeilenabstand; die Kacheln verlieren Fläche,
    Radius und Rahmen und werden durch Haarlinien `--line-1` getrennt. Die **erste** Kachel
    geht über die ganze Breite (`grid-column: 1 / -1`), ohne Linie, Zahl **48 px** mit
    Sperrung -.04em, Einheit 18 px, Kontextzeile 14,5 px in `--text-2`; die übrigen Zahlen
    25 px, Einheit 13,5 px, Kontext 13 px; eine allein übrig gebliebene letzte Kachel nimmt
    wieder die ganze Breite (`:200`).
    DATEN: `GET /import/tibber-invoices` → `InvoiceSummary[]`; Felder `number`,
    `period_label`, `period_start`, `kwh`, `total_gross_eur`, `avg_ct_kwh_gross`, `verdict`.

  * **Alles Weitere nur bei mindestens einer Rechnung**  (`InvoiceCheck.tsx:227`)
    Sonst, und nur wenn geladen und nicht beschäftigt (`:331-338`): eine Karte mit
    `padding: 24` und dem `Note`-Satz „Noch keine Rechnung geprüft. Lade eine Tibber-Rechnung
    als PDF hoch - die Auswertung entsteht dann hier und wächst mit jeder weiteren Rechnung."
    Während des ersten Ladens steht **nichts** da (`loaded` erst nach der Antwort, `:111`).

  * **Diagramm 1: „Menge: Rechnung gegen eigene Messung"**  (`InvoiceCheck.tsx:230-233`,
    `charts.ts:279-295`)
    Karte `padding: 16, height: 280`; Kopf rechts „je Abrechnungszeitraum"; das Diagrammfeld
    `min-h-0 flex-1`.
    Gruppierte (nicht gestapelte) Balken je Abrechnungszeitraum:
      - „Rechnung" `C.grid` = #E0533D, Radius oben `[2,2,0,0]`, `barGap: "10%"`
      - „Eigene Messung" `C.mist` = #7FA3B3, gleicher Radius
    Legende: rollbar, unten, zentriert, Mono 11 px, `C.text` = weiß 48 %, Marke 14×8
    (`charts.ts:285`). Gitter `left 52, right 12, top 24, bottom 52`. Werteachse „kWh",
    Achsenname 10 px, Rasterlinien weiß 9 %, drei Teilungen. Querachse: Kategorien, kein
    Tick, 10 px, `hideOverlap`. Zeiger: `axisPointer "shadow"`, Werte als „x kWh" mit einer
    Stelle. Grundfarbe durchsichtig, Schrift überall Mono (`MONO`, `charts/palette.ts:84`).
    Achsenkürzel: `short()` kürzt „Oktober 2026" zu „Okt 2026"
    (`InvoiceCheck.tsx:20`: `label.replace(/(\w{3})\w* (\d{4})/, "$1 $2")`).
    Reihenfolge: `chronological` = nach `period_start` aufsteigend (`:161`).
    DATEN: aus `InvoiceSummary`: `period_label`, `kwh`, `measured_kwh` (fehlend → `null`,
    kein Balken).

  * **Diagramm 2: „Rechnungsbetrag"**  (`InvoiceCheck.tsx:234-237`, `charts.ts:297-322`)
    Karte wie oben, Kopf rechts „Arbeitspreis · Grundgebühr · Steuer".
    Gestapelte Balken in Euro, Stapel `"eur"`, `barCategoryGap: "35%"`, Radius `[2,2,0,0]`
    nur am obersten Abschnitt:
      - „Arbeitspreis netto" `C.pv` #F2A900 ← `energy_net_eur`
      - „Grundgebühr netto" `C.base` #C2A86B ← `fees_net_eur`
      - „Mehrwertsteuer" `C.export` `rgba(228,236,239,.5)` ←
        `Math.round((total_gross_eur - total_net_eur) * 100) / 100` (`InvoiceCheck.tsx:173`)
    Werteachse „€", drei Teilungen; Zeigerwerte mit **zwei** Stellen und „ €".
    DATEN: `InvoiceSummary.energy_net_eur`, `fees_net_eur`, `total_gross_eur`,
    `total_net_eur`.

  * **Diagramm 3: „Durchschnittspreis"**  (`InvoiceCheck.tsx:240-243`, `charts.ts:324-340`)
    Zeile `--cols: "5fr 7fr"`; Karte `padding 16, height 280`, Kopf rechts „brutto".
    Zwei Linien:
      - „Rechnung (brutto)" `C.pv` #F2A900, Strich 2,5 px, Punkte 6 px
      - „Eigene Preisreihe" `C.mist` #7FA3B3, Strich 1,5 px **gestrichelt `[5,4]`**,
        Punkte 5 px, `connectNulls: true`
    Werteachse „ct/kWh", drei Teilungen, **`scale: true`** - die Achse fängt also **nicht**
    bei Null an. Zeigerwerte zwei Stellen, `null` → „-".
    DATEN: `InvoiceSummary.avg_ct_kwh_gross`, `measured_avg_ct_kwh` (fehlend → `null`).

  * **Diagramm 4: „Preisbestandteile"**  (`InvoiceCheck.tsx:244-251`, `charts.ts:342-367`)
    Karte `padding 16, height 280`; Kopf rechts = `report.invoice.period_label`, ohne
    Bericht „Rechnung auswählen". Ohne Positionen steht mittig ein `Note`:
    „Eine Rechnung in der Liste auswählen."
    **Liegende** Balken, ct/kWh, Reihenfolge umgekehrt (`[...positions].reverse()`, damit die
    erste Position oben steht). Farbe nach `group`: „Stromeinkauf" `C.pv` #F2A900, „Netz"
    `C.mist` #7FA3B3, „Steuern, Abgaben & Umlagen" `C.base` #C2A86B, alles andere `C.base`.
    Balkenbreite 58 %, Radius rechts `[0,2,2,0]`. Beschriftung **am Balkenende**, Mono 10 px,
    `C.text`, **drei** Stellen. Gitter `left 168, right 56, top 8, bottom 26`; Kategorieachse
    ohne Linie und Tick, Beschriftung 10 px, Breite 160 px, abgeschnitten (`truncate`);
    Werteachse unten mit mittigem Namen „ct/kWh", Abstand 20 px.
    Zeiger je Balken: Name, `x,xxx ct/kWh`, darunter die Gruppe in `C.text`.
    DATEN: `report.invoice.positions[].label`, `.group`, `.ct_per_kwh`.

  * **Tabelle „Geprüfte Rechnungen"**  (`InvoiceCheck.tsx:254-302`)
    Eigene Karte `padding: 16`, Kopf rechts „Zeile anklicken für die Befunde", darunter
    `mt-2 overflow-auto`, Tabelle 12 px, `border-collapse`, Körper in Mono.
    Kopfzeile: `.kicker` mit **fontSize 10**, linksbündig, Zellen `py-1.5 pr-3`,
    Gewicht 500. Acht Spalten, wörtlich:
    „Zeitraum" | „Nummer" | „Menge" (rechts) | „Eigene Messung" (rechts) | „Ø brutto"
    (rechts) | „Netto" (rechts) | „Brutto" (rechts) | „Ergebnis".
    Zeile: anklickbar, obere Haarlinie `--line-1`, gewählte Zeile Fläche `--surface-1`
    (#0F2E3D). Inhalte:
      - Zeitraum `period_label`, kein Umbruch
      - Nummer in `--text-3`
      - Menge `de1(kwh, 2) + " kWh"`
      - Eigene Messung in `--text-3`: `de1(measured_kwh,1) + " kWh"`, und **nur wenn**
        `coverage != null && coverage < 0.98` zusätzlich „ (<ganze Prozent> %)";
        ohne Messung oder bei 0 ein „-" (`:284-288`)
      - Ø brutto `de1(avg_ct_kwh_gross, 2) + " ct"`
      - Netto `eur(total_net_eur)` in `--text-3`
      - Brutto `eur(total_gross_eur)`
      - Ergebnis: Wort und Farbe aus `TONE` (`:13-18`), dahinter „ (<problems>)", wenn
        `problems > 0`:
          `ok` → „geprüft, alles stimmig", `var(--amber)`
          `info` → „geprüft, mit Hinweisen", `var(--mist)`
          `warning` → „auffällig", `var(--alert)`
          `error` → „Rechenfehler", `var(--alert)`
          unbekannt → die Darstellung von `info` (`:272`)
    Reihenfolge: `items`, also wie der Dienst sie liefert - **nicht** chronologisch
    (nur die Diagramme sortieren, `:161`).
    Handy: diese Tabelle trägt **keine** Klasse und steht deshalb **nicht** in der Liste der
    Tabellen, die `handy.css` zu Listen umbaut (`handy.css:305-306`: `.kosten-tabelle`,
    `.fp-entscheidungen`, `.nb-tabelle`, `.fenster-tabelle`; gesucht nach „rechnung",
    „invoice", „geld" in `apps/web/src/styles/handy.css`: kein Treffer). Sie bleibt also eine
    achtspaltige Tabelle und rollt in ihrem `overflow-auto` nach rechts. Was greift, sind die
    Schriftstufen: 10 px → 11 px, 12 px → 13,5 px (`handy.css:189-191`).
    DATEN: ganze `InvoiceSummary`-Liste.

  * **Befundkarte links: „Rechnerische Prüfung · <period_label>"**
    (`InvoiceCheck.tsx:305-316`)
    Zeile `--cols: "7fr 5fr"`. Kopf rechts: „<Anzahl der `ok` in `computed`> von
    <`computed.length`> stimmig". Liste ohne Punkte, `mt-1`.
    `computed` = alle Befunde, deren `code` **nicht** in
    `["measured_kwh","measured_price","coverage","no_measurement"]` steht (`:201`).
    Sortierung über alle Befunde vorher: `RANK` error 0, warning 1, info 2, ok 3,
    unbekannt 9 (`:19`, `:197-200`).
    DATEN: `GET /import/tibber-invoices/{number}` → `InvoiceReport.findings`.

  * **Befundzeile (`FindingRow`)**  (`InvoiceCheck.tsx:33-52`)
    `li`, Abstand 10 px (`gap-2.5`), obere Haarlinie `--line-1`, bei der ersten keine,
    senkrechte Polsterung 8 px (`py-2`).
    Punkt (`Dot`, `:22-31`): **8 px** (`h-2 w-2`), rund, `mt-[5px]`, nicht schrumpfend;
    `error`/`warning` → `--alert`, `info` → `--mist`, **alles andere, `ok` eingeschlossen,
    → `--amber`**.
    Kopf der Zeile: Titel `title_de` 13 px `--text-1`; **nur wenn `expected` und `actual`
    beide gesetzt sind** rechts in Mono 12 px, ohne Umbruch:
    „<de1(expected,2)> erwartet · <de1(actual,2)> <unit>", und dahinter
    „ · <Vorzeichen><de1(delta,2)>", falls `|delta| >= 0.005` (`:44`).
    Farbe dieser Zahlen: `--text-3` bei `severity === "ok"`, sonst `--alert`.
    Darunter `detail_de`, 12 px, Zeilenhöhe 1.5, `--text-3`.

  * **Befundkarte rechts: „Abgleich mit eigenen Daten"**  (`InvoiceCheck.tsx:317-327`)
    Kopf rechts: `report.invoice.number`. `compared` = die vier Codes von oben (`:202`);
    ist keiner da, steht ein `Note`: „Kein Abgleich möglich."
    Fußzeile darunter: `mt-3`, obere Haarlinie `--line-1`, `pt-2`, 12 px `--text-3`:
    „Zeitraum <period_start> bis <period_end> · Zählerstand <de1(meter_start,2)> →
    <de1(meter_end,2)> kWh" und je nach `meter_estimated` „ (errechnet)" oder „ (abgelesen)".
    Die Daten stehen als ISO-Zeichenketten so da, wie der Dienst sie schickt.

  * **Welche Rechnung beim Öffnen gezeigt wird**  (`InvoiceCheck.tsx:127-135`)
    Der Kommentar nennt den Grund und gehört in die App übernommen: „Beim Öffnen die Rechnung
    aus `?nr=` zeigen (so verlinkt Alfred nach dem Prüfen), sonst die neueste, damit Befunde
    und Preisbestandteile nicht leer bleiben. Eine unbekannte Nummer fällt still auf die
    neueste zurück." „Die neueste" ist dabei `items[0]` - die erste der unsortierten Liste.
    Ein zweites Anklicken wählt **nicht** ab (`open()`, `:117-125`, setzt nur).


LUECKEN:

  [traegt-die-seite] Das Hochladen fehlt ganz: keine Karte „Rechnung prüfen", kein
    Ablegefeld, kein Aufruf von `Api.pruefeRechnung`
    (`DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:443-448` ist unbenutzt - gesucht nach
    `pruefeRechnung` in `apps/ios`: nur die Definition). Die App kann heute keine Rechnung
    einlesen und schickt den Benutzer dafür in `docs/RECHNUNGSPRUEFUNG.md`
    (`RechnungenSeite.swift:30`).
  [traegt-die-seite] Die vier Kennzahlen über **alle** Rechnungen fehlen (Geprüfte
    Rechnungen, Beanstandet, Summe brutto, Ø Preis brutto; `InvoiceCheck.tsx:219-224`). Die
    App zeigt Kacheln nur zu **einer** gewählten Rechnung.
  [traegt-die-seite] Diagramm „Menge: Rechnung gegen eigene Messung" fehlt
    (`charts.ts:279-295`). Es ist die Hauptaussage der Seite - abgerechnet gegen gemessen,
    über alle Zeiträume.
  [traegt-die-seite] Diagramm „Rechnungsbetrag" (gestapelt: Arbeitspreis, Grundgebühr,
    Steuer) fehlt (`charts.ts:297-322`).
  [traegt-die-seite] Diagramm „Durchschnittspreis" (Rechnung gegen eigene Preisreihe) fehlt
    (`charts.ts:324-340`).
  [traegt-die-seite] Diagramm „Preisbestandteile" (liegende Balken je Position, Farbe nach
    Gruppe) fehlt (`charts.ts:342-367`). Die App hat an dieser Stelle eine Zahlentabelle
    (`RechnungenSeite.swift:130-143`), die in der Vorlage nicht vorkommt.
  [traegt-die-seite] Die Tabelle „Geprüfte Rechnungen" fehlt: statt acht Spalten zeigt die
    App fünf Werte in zwei Textzeilen (`RechnungenSeite.swift:52-73`). Es fehlen Menge,
    **Eigene Messung mit Abdeckung**, Ø brutto und Netto - also genau der Vergleich, um den
    es auf der Seite geht (`InvoiceCheck.tsx:257-300`).
  [traegt-die-seite] Beim Öffnen ist keine Rechnung gewählt, die untere Hälfte bleibt leer.
    Die Vorlage öffnet `?nr=` oder die neueste, ausdrücklich „damit Befunde und
    Preisbestandteile nicht leer bleiben" (`InvoiceCheck.tsx:127-135`).
  [traegt-die-seite] Die Befunde stehen in **einer** Karte „Was aufgefallen ist"
    (`RechnungenSeite.swift:108`). Die Vorlage teilt sie in „Rechnerische Prüfung ·
    <Zeitraum>" und „Abgleich mit eigenen Daten" nach einer festen Code-Liste und schreibt
    in den Kopf „n von m stimmig" (`InvoiceCheck.tsx:201-202`, `:309`). Ohne die Teilung
    steht nicht da, was nachgerechnet und was verglichen wurde.
  [spuerbar] Die Befunde sind nicht nach Schwere sortiert; die Vorlage ordnet error,
    warning, info, ok (`InvoiceCheck.tsx:19`, `:197-200`).
  [spuerbar] Die Fußzeile mit Zeitraum und Zählerstand („Zeitraum … bis … · Zählerstand
    x → y kWh (errechnet|abgelesen)") fehlt (`InvoiceCheck.tsx:322-326`). `meterStart`,
    `meterEnd`, `meterEstimated` werden in der App nirgends gelesen (gesucht nach `meterEnd`
    in `apps/ios/DuckCurveHome`: kein Treffer).
  [spuerbar] In der Liste steht statt des Urteilswortes die Zahl der Befunde („2 Befunde",
    `RechnungenSeite.swift:92-94`). Die Vorlage schreibt Wort **und** Zahl („auffällig (2)",
    `InvoiceCheck.tsx:292-295`). Der Kommentar in der App (`:83-85`) begründet das damit, dass
    auf einer Zeile die Zahl die nützlichere Auskunft sei - sobald die Tabellenspalte
    „Ergebnis" da ist, gilt die Begründung nicht mehr.
  [spuerbar] Der Leerzustand sagt das Falsche: „Rechnungen kommen über den Dienst herein -
    siehe docs/RECHNUNGSPRUEFUNG.md" statt „Noch keine Rechnung geprüft. Lade eine
    Tibber-Rechnung als PDF hoch - die Auswertung entsteht dann hier und wächst mit jeder
    weiteren Rechnung." (`InvoiceCheck.tsx:333-336`).
  [spuerbar] Ein Fehler beim Laden eines Berichts bleibt stumm: `bericht = try? await …`
    (`RechnungenSeite.swift:231`). Die Vorlage zeigt „Rechnung konnte nicht geladen werden."
    im Fehlerband (`InvoiceCheck.tsx:123`).
  [spuerbar] Der Seitenkicker „Tibber · nachgerechnet und gegen die eigene Messung gehalten"
    (`InvoiceCheck.tsx:205`) steht nirgends. Der Weg dafür ist im Projekt entschieden: er
    gehört über die erste Karte (`Zustand/Gelduebersicht.swift:65-70`).
  [spuerbar] Der Hinweistext zur Prüfung fehlt (`InvoiceCheck.tsx:213-217`), darunter der
    Satz „Das PDF selbst wird nicht gespeichert." Die App hat an seiner Stelle einen eigenen
    Methodenblock mit anderem Wortlaut (`RechnungenSeite.swift:144-149`).
  [spuerbar] Befundzahlen: die App zeigt sie, sobald **einer** der beiden Werte da ist, ohne
    `delta` und ohne Farbwechsel nach Schwere; die Vorlage verlangt **beide**, hängt das Delta
    an (Schwelle 0,005) und färbt alles außer `ok` in `--alert`
    (`InvoiceCheck.tsx:34`, `:41-45`).
  [klein] Zwischen den Befunden fehlen die Haarlinien `--line-1` (die App nimmt 12 pt
    Abstand, `RechnungenSeite.swift:109`; die Vorlage `border-t` und `py-2`,
    `InvoiceCheck.tsx:36`).
  [klein] Der Punkt vor einem Befund ist 6 pt groß (`RechnungenSeite.swift:176`), in der
    Vorlage 8 px (`h-2 w-2`, `InvoiceCheck.tsx:27`).
  [klein] Kein Ladezustand: die Vorlage schreibt „läuft" in den Kartenkopf
    (`InvoiceCheck.tsx:211`) und tauscht die beiden Texte im Ablegefeld (`:87-90`).
  [klein] Die Abdeckung steht in der App immer da („abgedeckter Zeitraum",
    `RechnungenSeite.swift:122`); in der Tabelle der Vorlage nur, wenn sie unter 98 % liegt
    (`InvoiceCheck.tsx:286`).
  [klein] Ein zweites Tippen auf eine Zeile hebt die Auswahl auf
    (`RechnungenSeite.swift:54`); die Vorlage kennt kein Abwählen (`:117-125`).
  [klein] Die sechs Kacheln zu einer Rechnung (`RechnungenSeite.swift:199-211`: Energie
    netto, Gebühren netto, Umsatzsteuer …) haben in der Vorlage kein Gegenstück; dort stehen
    diese Beträge im Diagramm „Rechnungsbetrag" und in den Tabellenspalten. Beim Umbau zu
    entscheiden, nicht stillschweigend mitzuschleppen.


KERN: SCHON DA (nachgesehen, nicht geraten)

  * Abfragen: `Api.rechnungen() -> [InvoiceSummaryOut]` auf `/import/tibber-invoices`
    (`DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:433-435`);
    `Api.rechnung(_ nummer:) -> InvoiceReportOut` auf `/import/tibber-invoices/<entschärft>`
    (`:437-440`); `Api.pruefeRechnung(_ pdf: Data, name: String) -> InvoiceReportOut`,
    POST `/import/tibber-invoice?file_name=…`, Rumpf = PDF, `application/pdf` (`:443-448`) -
    deckungsgleich mit `lib/api/client.ts:151-158`.
  * `InvoiceSummaryOut` (`Modelle/Schema.swift:5878-5930`): `number`, `periodLabel`,
    `periodStart`, `periodEnd`, `issuedOn`, `kwh`, `measuredKwh?`, `measuredAvgCtKwh?`,
    `coverage?`, `totalNetEur`, `totalGrossEur`, `avgCtKwhGross`, `energyNetEur`,
    `feesNetEur`, `verdict`, `problems`, `checkedAt` - also alle acht Tabellenspalten und
    alle Diagrammreihen.
  * `InvoiceReportOut` (`Modelle/Schema.swift:5836-5876`): `invoice`, `findings`, `verdict`,
    `measured?`, `checkedAt`, `fileName?`, `alreadyKnown?`.
  * `TibberInvoice` (`Modelle/Schema.swift:9398-9442`): u. a. `meterStart?`, `meterEnd?`,
    `meterEstimated?`, `positions`, `fees`, `totalNetEur`, `totalGrossEur`, `vatEur`,
    `avgCtKwh`, `avgCtKwhGross` - die Fußzeile ist aus dem vorhandenen Modell darstellbar.
  * `InvoicePosition` (`:5802-5834`): `label`, `group`, `ctPerKwh`, `ctDecimals`,
    `amountEur`.
  * `InvoiceFinding` (`:5757-5800`): `code`, `severity`, `titleDe`, `detailDe`, `expected?`,
    `actual?`, `unit?`, `delta?` - `delta` ist da, wird aber nicht angezeigt.
  * `InvoiceFindingSeverityWahl` (`:482-492`): `ok`, `info`, `warning`, `error`,
    `unbekannt`.
  * `MeasuredPeriod` (`:6562-6585`): `importKwh`, `coverage?`, `avgPriceCtKwh?`.
  * `Rechnungsurteil` (`Modelle/Woerter.swift:63-84`): die vier Wörter der Vorlage wörtlich
    („geprüft, alles stimmig", „geprüft, mit Hinweisen", „auffällig", „Rechenfehler"),
    `istBefund` und `aus(_:)`; der Kopfkommentar `:57-62` nennt den Grund.
  * Formate (`Formate/Formate.swift`): `zahl(_:stellen:)` `:44`, `kwh` `:75`,
    `prozent` ganzzahlig `:98`, `ct` `:110`, `euro(_:stellen:)` `:116`.
  * Farben (`Gestalt/Marken.swift`): `amber` 0xF2A900 `:18`, `mist` 0x7FA3B3 `:20`,
    `alarm` 0xE0533D `:99`, `diagrammNetz` 0xE0533D `:131` (= `C.grid`), `linie1`/`linie2`
    `:32-33`, `rasterlinie` `:34`, `flaeche1` 0x0F2E3D `:28` (= `--surface-1`),
    `flaeche2` 0x123544 `:29`. Als `Color` in `Gestalt/Farben.swift:29-83`.
  * Achsen: `Achse.beschriftungen(_:hoechstens:)`
    (`Zustand/Achse.swift:16-21`) für „nicht jede Beschriftung"; `Achse.spanne(werte:…)`
    (`:33ff`) für eine Achse ohne Null - genau das, was `scale: true` im Preisdiagramm
    verlangt.
  * Oberfläche: `Karte` mit Kicker/Titel/Beiwerk und den Handy-Maßen (Radius 16,
    Polsterung 16, kein Rand) in `Gestalt/Karte.swift:15-104`; `Kachelfeld` mit „eine Zahl
    führt" und den Haarlinien (`:274-343`); `Kacheldaten`/`Kachel` samt `Kachel.Art.bericht`
    und 48-pt-Zahl (`:121-266`); `Zeile` (`:360-383`); `Leer` (`:390-404`);
    `Stoerung` (`:410-436`); `Tabelle` mit Spaltenumschaltung am Telefon
    (`Seiten/Bericht.swift:157-328`); `Methode` (`:334-397`); `Seite`
    (`App/Seitenwahl.swift:141-174`).
  * Diagrammvorbilder: gruppierte Balken mit `.position(by:)` und vorgegebener Querachse
    (`Diagramme/Prognosezeichnung.swift:384-404`, `Tagesenergiebild`); gestapelte Balken mit
    Legende im Kartenkopf, drei Achsenteilungen und Radius nur oben
    (`Diagramme/Geldbalken.swift:20-101`, `Diagramme/Pvverwendung.swift:113-131`);
    Kartenkopf-Legende `Geldlegende` (`Diagramme/Geldbalken.swift:112-129`) und
    `Diagrammlegende` (`Diagramme/Pvverwendung.swift:170-186`); gestrichelte Linien
    (`Diagramme/Wirkungszeichnung.swift:287`, `Diagramme/Heizkurvenbild.swift:173`);
    Ablesung per `chartXSelection` statt Zeiger (`Diagramme/Pvverwendung.swift:106`).
  * Waagerechte Balken von Hand: `Anteilsleiste`
    (`Bausteine/Anteilsleiste.swift:15-47`) - Spur in `Farbe.linie1`, Füllung in der
    Serienfarbe, 8 pt hoch, Länge aus einem im Kern gerechneten Anteil. Der Kopfkommentar
    `:5-13` sagt ausdrücklich, dass es im Projekt nichts anderes dafür gibt.
  * PDF aus der Dateiauswahl lesen: `.fileImporter(allowedContentTypes: [.pdf])` und
    `startAccessingSecurityScopedResource()` in `Alfred/Alfredblatt.swift:62-64` und
    `:343-363` - mit dem Kommentar, warum der Zugriff nötig ist („ohne diesen Zugriff kommt
    ein leeres `Data` zurück").
  * Rolle→Farbe als eigene kleine Aufzählung je Seite, weil `Kennzahl.Ton`
    (`Zustand/Kennzahl.swift:37-50`) **kein** `alarm` kennt und `Farbe.ton`
    (`Gestalt/Farben.swift:98-107`) allen Seiten gehört: Vorbild `Gelduebersicht.Ton`
    (`Zustand/Gelduebersicht.swift:44-61`) mit `Geldfarbe.zu(_:)`
    (`Bausteine/Geldfarbe.swift:15-27`).
  * Reiter und Zugangsschranke stehen schon richtig: `Bereiche.swift:122`.

  Gesucht und **nicht** vorhanden:
  * `Zustand/Rechnungspruefung.swift` o. ä.: gesucht nach `InvoiceSummaryOut` und
    `InvoiceReportOut` in `DuckCurveKit/Sources/DuckCurveKit/Zustand/`: kein Treffer. Es
    gibt für diese Seite keinen Rechenbaustein im Kern.
  * Waagerechtes Balkendiagramm in Swift Charts: gesucht nach `BarMark(` in
    `apps/ios/DuckCurveHome`: neun Treffer, alle mit `x: .value(<Kategorie>)`, also senkrecht
    (`Prognosezeichnung.swift:390,394,499,594,744`, `Geldbalken.swift:32`,
    `Pvverwendung.swift:116`, `Seiten/Energie/StromSeite.swift:474`, `Bericht.swift:106`).
  * Farbwerte für `C.base` #C2A86B als Serienfarbe „Grundgebühr/Steuern" und für `C.export`
    `rgba(228,236,239,.5)` als „Mehrwertsteuer": gesucht in `Gestalt/Marken.swift`;
    0xC2A86B steht dort nur als `abdeckungTeils` (`:216`, andere Bedeutung), 0xE4ECEF nur in
    `pufferschichten` (`:273`). `netzEinspeisung` ist `amberWeich` (`:52`) und damit nicht
    dasselbe.
  * Route-eigene Handy-Regeln: gesucht nach „rechnung", „Rechnung", „invoice", „geld" in
    `apps/web/src/styles/handy.css`: kein Treffer. Für diese Seite gelten nur die
    allgemeinen Regeln (Karten `:182-185`, Kennzahlfläche `:194-207`, Zeilen `:209`,
    Schriftstufen `:189-192`) - und die Tabelle bleibt eine Tabelle.


ES FEHLT:

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Rechnungspruefung.swift`, neu:
     `public enum Rechnungspruefung` mit den Auswahl- und Rechenschritten der Seite.
     Darin, mit Prüfungen in `DuckCurveKit/Tests/DuckCurveKitTests/RechnungspruefungTests.swift`:
     * `public static func chronologisch(_ liste: [InvoiceSummaryOut]) -> [InvoiceSummaryOut]`
       - nach `periodStart` aufsteigend (`InvoiceCheck.tsx:161`).
     * `public static func achsenkuerzel(_ label: String) -> String` - „Oktober 2026" →
       „Okt 2026", die Swift-Fassung von `short()` (`InvoiceCheck.tsx:20`).
     * `public static func kopfkennzahlen(_ liste: [InvoiceSummaryOut]) -> [Kennzahl]` - die
       vier Kacheln samt Wortlaut, Rundung (0 Stellen bei der kWh-Summe, 2 beim Ø-Preis),
       dem mengengewichteten Mittel und dem „-" bei Menge 0 (`InvoiceCheck.tsx:219-223`).
       Braucht einen Ton für `--alert`; dafür eine eigene kleine Aufzählung
       `public enum Ton { case alarm, bernstein, text }` nach dem Vorbild
       `Gelduebersicht.Ton` (`Zustand/Gelduebersicht.swift:44-61`) statt `Kennzahl.Ton` zu
       erweitern.
     * `public struct Mengenpaar { wort, rechnung: Double, messung: Double? }` und
       `public static func mengenpaare(_:) -> [Mengenpaar]` für Diagramm 1.
     * `public struct Betragsreihe { name: String, ton: Ton, werte: [(wort: String, wert:
       Double)] }` und `betragsreihen(_:)` für Diagramm 2, mit der
       Mehrwertsteuer-Rundung `((brutto - netto) * 100).rounded() / 100`
       (`InvoiceCheck.tsx:173`).
     * `public struct Preispunkt { wort, rechnung: Double, eigene: Double? }` und
       `preisreihe(_:)` für Diagramm 3.
     * `public struct Positionsbalken { wort: String, gruppe: String, ct: Double, anteil:
         Double }` und `positionsbalken(_ positions: [InvoicePosition]) -> [Positionsbalken]`
       - umgekehrte Reihenfolge und der Anteil gegen das Maximum, damit die Ansicht keine
       Länge rechnet (wie `Gelduebersicht.ersparnisteile`, begründet in
       `Bausteine/Anteilsleiste.swift:10-13`).
     * `public static func gerechnet(_ findings: [InvoiceFinding]) -> [InvoiceFinding]` und
       `verglichen(_:)` mit der Code-Liste
       `["measured_kwh","measured_price","coverage","no_measurement"]`, beide nach der
       Rangfolge error→warning→info→ok→unbekannt sortiert (`InvoiceCheck.tsx:19`,
       `:197-202`).
     * `public static func stimmig(_ gerechnet: [InvoiceFinding]) -> String` - „n von m
       stimmig" (`InvoiceCheck.tsx:309`).
     * `public static func messungsspalte(_ r: InvoiceSummaryOut) -> String` - „x kWh",
       mit „ (y %)" nur unter 98 % Abdeckung, sonst „-" (`InvoiceCheck.tsx:284-288`).
     * `public static func zaehlerzeile(_ i: TibberInvoice) -> String` - die Fußzeile mit
       Zeitraum, Zählerstand und „(errechnet)"/„(abgelesen)" (`InvoiceCheck.tsx:322-326`).
     * `public static func befundzahlen(_ f: InvoiceFinding) -> String?` - nur bei beiden
       Werten, mit Delta ab 0,005 und Vorzeichen (`InvoiceCheck.tsx:34`, `:41-45`).
     * Die Wortlaute der Seite als Konstanten: `seitenkicker`, `pruefkartentitel`,
       `ablegefeldZiehen`, `ablegefeldKlicken`, `ablegefeldLaeuft`,
       `ablegefeldLaeuftDazu`, `hinweis`, `leerSatz`, die vier Kartenköpfe, die acht
       Spaltennamen, „Eine Rechnung in der Liste auswählen.", „Kein Abgleich möglich." -
       wie `Gelduebersicht` es für die Kostenseite tut (`Zustand/Gelduebersicht.swift:63-70`).
  2. `Rechnungsurteil` um die Darstellung der Tabellenspalte erweitern
     (`Modelle/Woerter.swift:63-84`): eine Funktion
     `public static func ergebnis(_ roh: String, probleme: Int) -> (text: String, befund:
     Bool)`, die „auffällig (2)" liefert und bei unbekanntem Wort auf die Darstellung von
     `info` fällt (`InvoiceCheck.tsx:272`, `:292-295`).
  3. Zwei Serienfarben in `Gestalt/Marken.swift` (neben `diagrammNetz` `:131`), mit dem
     Grund im Kommentar: `grundgebuehr` = 0xC2A86B (= `C.base`, `charts/palette.ts:39`) und
     `umsatzsteuer` = 0xE4ECEF mit Deckung 0.5 (= `C.export`, `charts/palette.ts:44`);
     dazu die `Color`-Paare in `Gestalt/Farben.swift`. Beide Werte gehören zum gestapelten
     Balken „Rechnungsbetrag" und stehen dort neben `pv` - der Abstand ist in
     `charts/palette.ts:9-31` gegen #123544 gerechnet und darf nicht durch eine ersetzte
     Farbe verfallen.


BAUPLAN:

  1. **Kern zuerst** - `DuckCurveKit/Sources/DuckCurveKit/Zustand/Rechnungspruefung.swift`
     mit allem aus „ES FEHLT" Punkt 1, und
     `DuckCurveKit/Tests/DuckCurveKitTests/RechnungspruefungTests.swift`: Sortierung,
     Achsenkürzel, mengengewichtetes Mittel, MwSt-Rundung, Code-Teilung, Rangfolge,
     98-%-Schwelle, Delta-Schwelle. Danach Punkt 2 (`Modelle/Woerter.swift`) und Punkt 3
     (`Gestalt/Marken.swift`, `Gestalt/Farben.swift`).
  2. **Ablegen und Prüfen** - `apps/ios/DuckCurveHome/Bausteine/Rechnungsablage.swift`, neu:
     eine Karte mit `kicker: Rechnungspruefung.pruefkartentitel` und `beiwerk` = „läuft" bzw.
     „<n> gespeichert"; darin ein gestricheltes Feld (`RoundedRectangle` mit
     `StrokeStyle(lineWidth: 1.5, dash: [6, 4])`, Radius 3 bzw. 16 am Telefon,
     `Farbe.linie2`) als Knopf, Polsterung 16 pt mit Rechnungen / 34 × 20 pt ohne, mit den
     beiden Texten der Vorlage; darunter der Hinweistext in `Schrift.winzig`/`Farbe.text3`.
     Dateiwahl und PDF-Lesen genau wie `Alfred/Alfredblatt.swift:62-64` und `:343-363`
     (`allowedContentTypes: [.pdf]`, `allowsMultipleSelection: true`,
     `startAccessingSecurityScopedResource`), dann je Datei `haus.api.pruefeRechnung`, den
     letzten Bericht wählen, Fehlschläge als „<Name>: <Rat>" mit „ · " verbunden in die
     Störung, danach die Liste neu holen.
  3. **Kopfzeile der Seite** - in `RechnungenSeite.swift` den Seitenkicker über die erste
     Karte setzen (wie `Seiten/Geld/KostenSeite.swift:123` mit
     `Gelduebersicht.seitenkicker`), dann Zeile 1: am iPad Ablage links und `Kachelfeld`
     rechts, am Telefon untereinander. Für die Kacheln `Kachelfeld(kacheln:
     Rechnungspruefung.kopfkennzahlen(liste).map(Kacheldaten.init), art: .bericht)` -
     „eine Zahl führt" und die 48-pt-Zahl bringt `Gestalt/Karte.swift:290-299` mit; die
     Farbe `alarm` über eine kleine `Rechnungsfarbe`-Abbildung nach dem Vorbild
     `Bausteine/Geldfarbe.swift:15-27`.
  4. **Diagramm 1** - `apps/ios/DuckCurveHome/Diagramme/Rechnungsbilder.swift`, neu:
     `struct Mengenvergleichsbild` mit zwei `BarMark` je Zeitraum und `.position(by:)` wie
     `Diagramme/Prognosezeichnung.swift:384-404`, `.chartXScale(domain:)` über die Kürzel,
     `Achse.beschriftungen(…, hoechstens: schmal ? 6 : 12)`, drei Achsenteilungen,
     `cornerRadius(2)`, Legende im Kartenkopf über `Diagrammlegende`
     (`Diagramme/Pvverwendung.swift:170-186`) - nicht unten wie ECharts, das ist im Projekt
     entschieden (`Diagramme/Geldbalken.swift:8-13`, `:56-57`). Karte mit Kopf
     „Menge: Rechnung gegen eigene Messung" und rechts „je Abrechnungszeitraum", Höhe 280
     wie die Vorlage, am Telefon frei.
  5. **Diagramm 2** - in derselben Datei `struct Rechnungsbetragsbild`: gestapelte Balken
     wie `Diagramme/Geldbalken.swift:28-87`, aber ohne Nulllinie (hier ist nichts negativ),
     `cornerRadius` nur am obersten Abschnitt (`Diagramme/Pvverwendung.swift:122-124`),
     drei Reihen in den Farben aus Punkt 3 von „ES FEHLT", Legende im Kartenkopf
     („Arbeitspreis · Grundgebühr · Steuer" ist in der Vorlage der rechte Kopftext; als
     Legende mit Farbflecken ist sie besser und entspricht `ReportShell.tsx:184-203`).
  6. **Diagramm 3** - `struct Durchschnittspreisbild`: zwei `LineMark`-Reihen,
     die eigene gestrichelt (`StrokeStyle(lineWidth: 1.5, dash: [5, 4])` wie
     `Diagramme/Wirkungszeichnung.swift:287`), Punkte sichtbar,
     `.chartYScale(domain: Achse.spanne(werte:…))` für die Achse ohne Null,
     Lücken verbunden (`connectNulls` entspricht in Swift Charts dem Weglassen der
     `nil`-Punkte in einer Reihe).
  7. **Diagramm 4** - `apps/ios/DuckCurveHome/Bausteine/Positionsbalken.swift`, neu:
     die liegenden Balken **nicht** mit Swift Charts, sondern als Liste nach dem Vorbild
     `Bausteine/Anteilsleiste.swift:15-47` - je Position eine Zeile mit Namen links
     (`Schrift.klein`, `Farbe.text2`, zwei Zeilen erlaubt statt abgeschnitten), rechts die
     Zahl mit drei Stellen in `Schrift.zahlKlein`, darunter die Spur in `Farbe.linie1` mit
     der Füllung in der Gruppenfarbe. Länge aus `Positionsbalken.anteil` (im Kern
     gerechnet). Karte „Preisbestandteile", Kopf rechts = `periodLabel` bzw.
     „Rechnung auswählen"; ohne Positionen `Leer(satz: "Eine Rechnung in der Liste
     auswählen.")`.
  8. **Tabelle „Geprüfte Rechnungen"** - in `RechnungenSeite.swift` die heutige Knopfliste
     (`:35-73`) durch `Tabelle` (`Seiten/Bericht.swift:157-328`) ersetzen:
     `zeilennamen` = `periodLabel`, sieben Spalten (Nummer, Menge, Eigene Messung, Ø brutto,
     Netto, Brutto, Ergebnis), die Ergebnisspalte mit `farben` je Zelle - das kann `Tabelle`
     schon (`Bericht.swift:164-170`). `immerSichtbar` bleibt 1: acht Spalten auf 390 Punkten
     sind keine, und die Vorlage rollt dort nur, weil ihr für diese Tabelle die
     Listen-Regel fehlt (`handy.css:305-306`). **Die Auswahl braucht dafür einen Griff, den
     `Tabelle` nicht hat** - entweder `Tabelle` um ein optionales `auswahl: (Int) -> Void`
     und eine hervorgehobene Zeile (`Farbe.flaeche1`) erweitern, oder die Tabelle in der
     Seite belassen und darunter eine Reihe aus Zeiträumen zum Umschalten setzen. Erweitern
     ist das Richtige: die Vorlage macht die Zeile selbst zum Griff
     (`InvoiceCheck.tsx:277`), und eine zweite Auswahlleiste wäre eine Erfindung.
  9. **Auswahl beim Öffnen** - `gewaehlt` nach dem Laden auf `liste.first?.number` setzen
     und den Grund der Vorlage als Kommentar mitnehmen („damit Befunde und Preisbestandteile
     nicht leer bleiben", `InvoiceCheck.tsx:127-129`). Das Abwählen beim zweiten Tippen
     (`RechnungenSeite.swift:54`) entfällt. Den `?nr=`-Weg in der App nur, wenn
     `Wegweiser` eine Frageliste trägt - gesucht nach `nr=` in `apps/ios`: kein Treffer,
     also vorerst weglassen und im Kommentar festhalten, dass Alfred im Browser so verlinkt.
 10. **Befunde in zwei Karten** - „Rechnerische Prüfung · <periodLabel>" mit
     `Rechnungspruefung.gerechnet(...)` und Kopf rechts `stimmig(...)`;
     „Abgleich mit eigenen Daten" mit `verglichen(...)`, Kopf rechts `invoice.number`,
     darunter die Fußzeile aus `zaehlerzeile(...)` in `Schrift.winzig`/`Farbe.text3` mit
     einer `Divider().overlay(Farbe.linie1)` darüber; ist `verglichen` leer,
     `Leer(satz: "Kein Abgleich möglich.")`. Die Befundzeile
     (`RechnungenSeite.swift:172-197`) behält Punkt und Texte, bekommt aber 8 pt
     Punktgröße, Haarlinien zwischen den Zeilen, die Zahlen aus
     `Rechnungspruefung.befundzahlen` und die Farbe `Farbe.alarm` für alles außer `ok`.
 11. **Leerzustand und Methode** - den Satz der Vorlage übernehmen
     (`Rechnungspruefung.leerSatz`); den heutigen `Methode`-Block (`:144-149`) behalten, aber
     den Hinweistext der Vorlage (einschließlich „Das PDF selbst wird nicht gespeichert.")
     in die Ablagekarte setzen, wo er in der Vorlage steht. „Geprüft am …" und „Diese
     Rechnung war schon eingelesen." sind Zusätze der App ohne Gegenstück - sie dürfen
     bleiben, aber in der `Methode`, nicht im Haupttext.
 12. **Fehler nicht mehr verschlucken** - `ladeBericht()` (`:226-232`) auf denselben
     `do/catch`-Bau wie `ladeListe()` bringen und die Störung mit „Rechnung konnte nicht
     geladen werden." füllen.


WAS SCHWIERIG WIRD:

  * **Liegende Balken.** Swift Charts kann sie (`BarMark(x: .value(Wert), y: .value(Name))`),
    aber im Projekt gibt es dafür kein Vorbild: gesucht nach `BarMark(` in
    `apps/ios/DuckCurveHome` - neun Treffer, alle senkrecht. Was es gibt, ist der von Hand
    gebaute waagerechte Balken `Bausteine/Anteilsleiste.swift:15-47`, und sein
    Kopfkommentar begründet gerade diesen Weg („Es gab im Projekt nichts dafür… Die Vorlage
    baut die Leiste aus zwei geschachtelten Kästen"). Für die Preisbestandteile ist das
    zugleich das bessere Werkzeug: die Namen sind lang („Steuern, Abgaben & Umlagen"), die
    Vorlage schneidet sie bei 160 px ab (`charts.ts:361`), und eine Liste kann sie umbrechen.
  * **Zeiger mit Summe.** `charts.ts` setzt auf jedes Diagramm einen Tooltip. Der im Projekt
    gewählte Weg ist, die Zahl **daneben** auszuschreiben oder über
    `chartXSelection` eine Ablesezeile zu führen - ausdrücklich begründet in
    `Diagramme/Geldbalken.swift:15-19` und vorgeführt in
    `Diagramme/Prognosezeichnung.swift:61-96` (`Ablesung`) und
    `Diagramme/Pvverwendung.swift:106`. Für die drei Verlaufsdiagramme ist eine Ablesezeile
    über dem Bild die passende Entsprechung, kein Tooltip.
  * **Legende unten gegen Legende im Kopf.** ECharts setzt die Legende hier unten
    (`charts.ts:285`, `:306`, `:331`) und nimmt dafür 52 px vom Gitter. Im Projekt steht sie
    im Kartenkopf bzw. direkt darunter, mit Begründung in
    `Diagramme/Geldbalken.swift:103-111` und `Diagramme/Pvverwendung.swift:160-169`
    („auf 240 Punkten Höhe nimmt sie dort ein Fünftel der Fläche"). Dem Projekt folgen, nicht
    der Vorlage.
  * **Achse ohne Null.** `scale: true` im Preisdiagramm (`charts.ts:336`) hat in Swift
    Charts kein direktes Gegenstück; `Achse.spanne(werte:rand:mindestens:)`
    (`Zustand/Achse.swift:33ff`) ist der im Kern dafür schon gebaute Weg - mit anderen
    Vorgaben als bei Raumtemperaturen (Rand und Mindestspanne in ct/kWh wählen und im Test
    festschreiben).
  * **Auswahl in `Tabelle`.** `Tabelle` (`Seiten/Bericht.swift:157-328`) ist heute nur
    Anzeige: keine anklickbare Zeile, keine Hervorhebung. Die Vorlage braucht beides
    (`InvoiceCheck.tsx:277-279`: Zeile als Griff, gewählte Zeile in `--surface-1`). Das ist
    ein Eingriff in einen Baustein, den dreizehn Seiten benutzen - optional halten
    (`auswahl: ((Int) -> Void)? = nil`, `gewaehlteZeile: Int? = nil`), damit kein Aufrufer
    sich ändert.
  * **Mehrere Dateien auf einmal.** `fileImporter` kennt `allowsMultipleSelection`, aber
    `Alfred/Alfredblatt.swift:62` benutzt die Einzelfassung und liefert `Result<URL, Error>`;
    mit Mehrfachwahl wird daraus `Result<[URL], Error>`, und der
    `startAccessingSecurityScopedResource`-Rahmen muss je Datei einzeln stehen. Der
    Fehlertext je Datei („<Name>: <Meldung>", `InvoiceCheck.tsx:147`) braucht `ApiFehler.rat`
    (`Netz/ApiFehler.swift`), nicht `localizedDescription`.
  * **Das Gestrichelte.** Für den Rahmen des Ablegefelds gibt es im Projekt kein Vorbild
    (gesucht nach `dash:` in `apps/ios/DuckCurveHome`: zehn Treffer, alle in Diagrammen,
    keiner an einem Rahmen). `RoundedRectangle(...).strokeBorder(Farbe.linie2,
    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))` ist die geradlinige Übersetzung von
    `border: 1.5px dashed var(--line-2)` (`InvoiceCheck.tsx:81`); das Überzieh-Verhalten
    (amber plus `rgba(242,169,0,.07)`) hat am Telefon kein Gegenstück und fällt weg - beim
    Drücken stattdessen dieselbe Fläche zeigen.
