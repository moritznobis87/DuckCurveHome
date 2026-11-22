========================= messen:waerme-wirkung   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

`struct WirkungSeite` steht in `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:143-294`.
Zustand: `tage = 30`, `wirkung: KontaktwirkungOut?`, `fehler: ApiFehler?`, `laedtNeu`
(`:146-149`), `schmal` aus `horizontalSizeClass` (`:151-152`). Geladen wird in `lade()`
(`:282-293`) über `haus.api.kontaktwirkung(tage:)`, angestoßen von `.task(id: tage)` (`:223`).
Gezeichnet wird aus `Wirkungsbild.baue(w)` (`:157`).

1. Seitenkicker „Folgt die Wärmepumpe der Anforderung? · gemessen, nicht angenommen" – nicht in
   der Seite, sondern in der Hülle `Seite` (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:206-216`)
   aus `Bereiche.kicker(fuer:)`; der Text steht in
   `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:209`. Am Telefon fällt er
   weg (`Seitenwahl.swift:207`, `breite != .compact`).
2. Urteilskarte (`:232-269`): Kicker „Folgt die Wärmepumpe der Anforderung?", rechts die Spanne in
   `Schrift.zahlKlein`/`text3` (`:235-238`). Darin: Zeile „Zeitraum" +
   `Tagewahl(moeglich: [7,30,90], form: .wgWahl)` + „wird neu gerechnet" (`:240-252`); bei Fehler
   mit vorhandenen Daten eine `Stoerung` (`:253-255`); dann – schmal untereinander, sonst
   `HStack(spacing: 28)` mit `Quotenbild` auf `maxWidth: 460` – der Urteilssatz (`:256-266`).
   Urteilssatz: `Kicker("Urteil · \(bild.urteilswort)")` + Satz in `Schrift.sans(20)`,
   `lineSpacing(5)`, `text1` (`:271-280`).
3. `Kachelfeld(kacheln: Wirkungskacheln.kacheln(w), kicker: bild.spanne ?? "\(w.days) Tage",
   spalten: 3)` (`:159-163`). Die fünf Kacheln stehen in
   `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Wirkungsbild.swift:783-821`:
   Anforderungen, danach angelaufen, ohne Anforderung angelaufen, Verzögerung, Nachlauf.
   `Kachelfeld` (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:274-343`) packt sie in **eine** Karte,
   am Telefon führt die erste groß (`:290-299`).
4. Karte „Antwortfächer", Bedingung `!bild.faecher.isEmpty` (`:164`), Beiwerk
   „\(w.nAuswertbar ?? 0) Anforderungen bei stehender Maschine, am Beginn übereinandergelegt" mit
   `lineLimit(1)` (`:169-175`), Inhalt `Antwortfaecher(bild:)`
   (`apps/ios/DuckCurveHome/Diagramme/Wirkungszeichnung.swift:128-361`): Auskunftszeile oder
   „Zum Lesen einer Minute die Zeichnung berühren." (`:294-324`), Fläche „Leistung der Wärmepumpe
   in kW" 210 hoch (`:144-150`), Fläche „Anteil, der bis hier angelaufen ist" 110 hoch
   (`:151-164`), Legende mit vier Einträgen (`:327-360`).
5. Karte „Jede Anforderung", Bedingung `!bild.gruppen.isEmpty` (`:180`), Beiwerk „sortiert nach
   Verzögerung" (`:184`), Inhalt `Ereignisraster(bild:)` (`Wirkungszeichnung.swift:369-476`):
   Achsenzeile (`:393-412`), je Gruppe ein `Kicker("\(titel) · \(anzahl)")` und die Zeilen
   (`:378-385`), jede Zeile Datum/`Canvas`/Ergebniswort (`:414-431`), dann `rasterHinweis`
   (`:386-388`) und die Legende (`:459-475`).
6. Karte „Zu diesem Zeitraum" mit `w.hinweiseDe` als „·"-Liste in `Schrift.klein`/`text2`
   (`:192-208`).
7. `Methode(w.methodeDe, kurz: "ein Zusammenhang in der Zeit, keine Ursache · Vergleich zur selben
   Tageszeit", titel: "Was die Auswertung kann")` (`:209-216`), gezeichnet von
   `apps/ios/DuckCurveHome/Seiten/Bericht.swift:514-576`.
8. Ohne Daten: bei Fehler `Stoerung` allein (`:217-218`), sonst `Karte { Leer(satz: "Die
   Anforderungen werden gesucht.") }` (`:219-221`).

VORLAGE:

  * **Hülle und Seitenkicker**  (`apps/web/src/app/waerme/wirkung/page.tsx:7-13`)
    `<AreaShell kicker="Folgt die Wärmepumpe der Anforderung? · gemessen, nicht angenommen">`
    (`:9`), darin `<Wirkung />` (`:10`). `force-dynamic` (`:4`), Titel „Wirkung · Duck Curve Home"
    (`:5`). Die Hülle hängt den Kicker an das rechte Ende der Reiterzeile
    (`apps/web/src/components/layout/AreaShell.tsx:26`); Rahmen der Seite:
    `flex flex-col gap-4 p-5` (`AreaShell.tsx:16`).
    DATEN: keine.

  * **Urteilskarte**  (`apps/web/src/components/waerme/Wirkung.tsx:144-168`)
    `CardHead title="Folgt die Wärmepumpe der Anforderung?"`, rechts `spanne(d.von, d.bis)` in
    `mono text-[12px] text-text-3` (`:145`). Karte: `.card` = `--surface-2` #123544, 1 px
    `--line-1` (weiß 10 %), Radius 3 px, Polster 20 px (`globals.css:67-77`); am Telefon ohne Rand,
    Radius 16, Polster 16 (`handy.css:182`), und die Kopfzeile wird lesbare Schrift: 16,5 px, 600,
    `letter-spacing -.01em`, nicht gesperrt (`handy.css:184`); das Beiwerk nimmt am Telefon eine
    **eigene Zeile über die ganze Breite** und **bricht um** (`handy.css:185`:
    `flex-basis:100%; font-size:13px; white-space:normal; overflow:visible`).
    Zeile darunter (`:146-154`): „Zeitraum" (12 px, `text-3`), drei Knöpfe `.wg-wahl` – Mono 11 px,
    `letter-spacing .08em`, Polster 5/10, Kapsel, Rand `--line-1`, Schrift `--text-3`; gewählt
    `.wg-wahl-an`: Grund und Rand `--amber` #f2a900, Schrift `--petrol` #0f2e3d
    (`globals.css:621-622`). Wörtlich „7 Tage", „30 Tage", „90 Tage" (`:148-151`), Vorgabe 30
    (`:113`), `aria-pressed` (`:149`). Beim Nachrechnen mit vorhandenen Daten steht „wird neu
    gerechnet" (`:153`).
    Zustände: Fehler als Absatz `text-[13px] text-alert` (#e0533d) **in** der Karte, Zeitwahl bleibt
    stehen (`:156`); erste Ladung „Die Anforderungen werden gesucht." in `text-3` (`:157`).
    Kopfraster `.wk-kopf`: `grid-template-columns: minmax(0,1.1fr) minmax(300px,1fr)`,
    `gap: 18px 40px`, `align-items: center`, unter 900 px eine Spalte (`globals.css:648-649`).
    Links Kicker „Urteil · <Wort>" (`:162`, Wörter `:33-38`: offen → „noch offen", wirkt → „die
    Maschine folgt", kein_unterschied → „kein gesicherter Unterschied", seltener → „seltener als
    sonst"; unbekannte Kennung bleibt roh) und `.wk-urteil`: `max-width 60ch`,
    `font-size: clamp(17px, 2vw, 22px)`, `font-weight 300`, `line-height 1.38`,
    `letter-spacing -.01em`, `--text-1` (`globals.css:650`).
    DATEN: `api.kontaktwirkung(days)` → `GET /anlage/kontaktwirkung?days=`
    (`apps/web/src/lib/api/client.ts:108`); Felder `von`, `bis`, `urteil`, `urteil_de`.

  * **Quotenvergleich (rechts in der Urteilskarte)**  (`Wirkung.tsx:40-106`)
    SVG `viewBox="0 0 444 132"`, `role="img"`, `aria-label="Anlauf binnen {folge_min} Minuten: mit
    Anforderung {x} Prozent, ohne {y} Prozent."` (`:88`). Spur von x=92 bis x=332 (`:41-46`).
    Drei **senkrechte Rasterlinien** bei 0/50/100 %, `rgba(255,255,255,.09)`, 1 px, von y=14 bis
    y=104, darunter die Beschriftung bei y=120, `textAnchor="middle"`, `.wk-q-achse` = Mono 10 px
    `--text-3` (`:89-96`, `globals.css:657`).
    Je Zeile (`:54-82`): Name links bei x=0 (`.wk-q-name`: 12,5 px, `--text-2`), waagerechte Spur
    `rgba(255,255,255,.14)` 1 px, Balken `rect` mit `rx=5`, Höhe 10, Deckung 0,38 in der
    Reihenfarbe, Mindestbreite 2 (`:67`), Punkt `circle r=6` mit 2 px Ring in `var(--surface-2)`
    (`:69`, Begründung `:68`: „Der Ring in der Kartenfarbe hält den Punkt vom Balken ab"), Zahl bei
    x=346 (`.wk-q-zahl`: Mono 17 px, `tabular-nums`, `--text-1`) und darunter „{lo} bis {hi} %"
    (`.wk-q-klein`: Mono 10,5 px `--text-3`) – nur wenn **beide** Grenzen da sind (`:73-77`).
    Zeile 1 y=38 „angefordert", Farbe `C.heatPump` #e0966b, leer: „keine auswertbare Anforderung";
    Zeile 2 y=82 „sonst", Farbe `C.mist` #7fa3b3, leer: „kein Vergleich zur selben Tageszeit"
    (`:97-98`). Ohne Quote bleibt die Spur leer und der Grund steht darüber bei y−8 (`:61-64`).
    Bildunterschrift wörtlich (`:100-103`): „Anlauf binnen {folge_min} Minuten bei stehender
    Maschine. Punkt: beobachtete Quote. Balken: der Bereich, in dem die wahre Quote mit 95 Prozent
    Sicherheit liegt. Ein Urteil gibt es erst, wenn sich die Balken nicht überlappen." –
    `max-width 520px`, 11,5 px, `line-height 1.45`, `--text-3` (`globals.css:653`). SVG selbst
    `max-width: 520px` (`globals.css:652`).
    DATEN: `quote`, `quote_lo`, `quote_hi`, `vergleich.quote`, `vergleich.quote_lo`,
    `vergleich.quote_hi`, `folge_min`.

  * **Fünf Kennzahlkacheln**  (`Wirkung.tsx:171-201`)
    `<div className="kpi-handy grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">` – zwei
    Spalten, ab 768 px drei, ab **1280 px fünf** (`:171`). Jede Kachel ein eigenes `.card`
    (`Stat.tsx:7`, Polster 14/18, gap 6) mit Kicker 11 px (Mono, `letter-spacing .13em`, UPPERCASE,
    `--text-kicker` = `--mist`; `globals.css:57-64`), Zahl `mono text-[26px] leading-none
    tracking-[-.02em]`, Einheit daneben 13 px Sans `--text-3`, Hinweis `line-clamp-2`,
    12 px/1.35, `--text-3` (`Stat.tsx:8-16`).
    1. „Anforderungen" = `n`; dazu `n === 0 ? "im Zeitraum keiner" : "{n_auswertbar} bei stehender
       Maschine, {n_lief_schon} bei laufender"` (`:172-176`).
    2. „danach angelaufen" = `prozentZahl(quote)`, Einheit „%" nur wenn `quote != null`; dazu
       „{gefolgt} von {n_auswertbar} binnen {folge_min} Minuten, {n_auswertbar−gefolgt} nicht",
       sonst „keine auswertbare Anforderung" (`:177-182`, `nichtGefolgt` in `:140`).
    3. „ohne Anforderung angelaufen" = `prozentZahl(vergleich.quote)`; dazu „zur selben Tageszeit,
       aus {vergleich.n_gleiche_stunde} Vergleichsmomenten", sonst „kein Vergleich zur selben
       Tageszeit" (`:183-188`).
    4. „Verzögerung" = `minuten(verzoegerung_median_min)` (ganze Minuten, `:108-110`), Einheit
       „min"; dazu „Median von der Anforderung bis zum Anlauf" (`:189-194`).
    5. „Nachlauf" = `minuten(nachlauf_median_min)`, Einheit „min"; dazu „Median nach dem Ende der
       Anforderung, {n} Fälle" (bei 1: „1 Fall"), ohne Fälle „kein Ende bei laufender Maschine"
       (`:195-200`).
    Kein Kicker und keine Überschrift über dem Feld.
    DATEN: `n`, `n_auswertbar`, `n_lief_schon`, `gefolgt`, `quote`, `vergleich.quote`,
    `vergleich.n_gleiche_stunde`, `verzoegerung_median_min`, `nachlauf_median_min`, `nachlauf_n`,
    `folge_min`.
    **Handy-Fassung** (`handy.css:197-207`, `:382`): `.kpi-handy` wird **eine** Fläche
    (`--surface-2`, Radius 16, Polster 4/16), zwei Spalten, die Kacheln verlieren Grund, Radius und
    Rahmen und werden durch `border-top: 1px solid var(--line-1)` getrennt. Die **erste** Kachel
    nimmt die ganze Breite (`grid-column: 1/-1`), ohne Oberlinie, Polster 14/0/16, gap 8, Zahl
    **48 px** mit `letter-spacing -.04em`, Einheit 18 px mit `margin-left 8px`, Hinweis 14,5 px in
    `--text-2`. Die übrigen: Kicker 11 px `letter-spacing .1em`, Zahl **21 px** (`:382` schlägt die
    25 px aus `:202`), Einheit 13,5 px, Hinweis 13 px. Bleibt zuletzt eine allein, nimmt sie die
    ganze Zeile (`:200`).

  * **Karte „Antwortfächer"**  (`Wirkung.tsx:204-231`, Diagramm `Antwortfaecher.tsx:52-272`)
    Nur wenn `d.n_auswertbar > 0` (`Wirkung.tsx:204`). `CardHead title="Antwortfächer"`, rechts
    wörtlich „{n_auswertbar} Anforderungen bei stehender Maschine, am Beginn übereinandergelegt"
    (`:206`).
    Maße (`Antwortfaecher.tsx:34-38`): links 46, rechts 34; obere Fläche top 30 Höhe 210, untere
    top 398 Höhe 110, Gesamthöhe 442. Beide Gitter mit `outerBoundsMode: "none"`, **damit der
    Nullpunkt in beiden an derselben Stelle steht** (`:149-154`, Begründung im Kommentar).
    Über jeder Fläche ein Titel bei `top-22`, links bei 0, in `C.text` (= weiß 48 %) und
    `10px <Mono>`: „Leistung der Wärmepumpe in kW" und „Anteil, der bis hier angelaufen ist"
    (`:105-114`); Begründung `:103-104`: neben der Achse stieße er mit deren Zahlen zusammen.
    x-Achse beider Flächen: `min -vor_min`, `max nach_min`, `interval 30`, **`splitLine: show:
    false`** – also keine senkrechten Rasterlinien; Beschriftung **nur unten**, Mono 10 px in
    `C.text`, `hideOverlap`, und der Formatter schreibt die Einheit nur bei 0 und am Ende:
    `v === 0 || v === nach_min ? achsenText(v) : "±N"` (`:71-92`, Begründung `:85-86`: „sechsmal
    „min" nebeneinander stößt auf schmalen Schirmen zusammen, und einmal genügt").
    y-Achsen (`:156-172`): oben `min: 0`, `splitNumber: 3`, Beschriftung Mono 10 px `C.text`,
    waagerechte Rasterlinien in `C.gridline` = `rgba(255,255,255,.09)`; unten **fest
    `min: 0, max: 100, interval: 50`**, Formatter `"{value} %"`, dieselben Rasterlinien.
    Reihen (`:173-263`): bis zu 80 Einzelkurven (`MAX_KURVEN`, `:40`), die **jüngsten**
    auswertbaren, 1 px in `C.heatPump` mit Deckung `deckung(n)` (`wirkung.ts:130-132`:
    `min(.55, max(.1, 1.1/√n))`), `connectNulls: false`, still und ohne Tooltip. Darüber das Band
    der mittleren Hälfte als unsichtbare q25-Linie plus gestapelte Spanne, Fläche `C.heatPump`
    Deckung 0,22; q25 und Spanne sind **`null`, wo `f.n[i] < MIN_FUER_BAND` (8)** – damit bricht
    das Band an solchen Minuten ab (`:59-65`, `:188-199`, `:41`). Darüber das **Mittel** 2 px voll
    deckend (`:200-231`; Begründung im Dateikopf `:20-22`: „Das Mittel, nicht der Median. Die
    Maschine läuft oder steht."). Senkrechte Nulllinie `rgba(255,255,255,.75)`, 1,5 px, in beiden
    Flächen (`:93-99`, `:243`). Schwellenlinie waagerecht in `C.axis` = `rgba(255,255,255,.2)`,
    1 px gestrichelt, Beschriftung „läuft ab {x} kW" Mono 10 px, Position `insideStartTop` –
    links, weil rechts die Mittelkurve liegt (`:210-231`).
    Untere Fläche: `step: "end"` für beide Treppen; „angelaufen" 2 px `C.heatPump` mit Fläche
    Deckung 0,12 (`:232-251`), „ohne Anforderung" 2 px `C.mist` **gestrichelt** (`:252-262`).
    Dazu die `markArea` von 0 bis `folge_min` in `rgba(255,255,255,.05)` mit der Aufschrift „zählt
    als Folge: {folge_min} min", `insideTopLeft`, Mono 10 px (`:244-250`).
    Tooltip (`:116-147`): Kopf „Anforderung beginnt" / „{m} min nach Beginn der Anforderung" /
    „{m} min vor der Anforderung"; dann „im Mittel {x} kW" mit Linienmarke, eingerückt „mittlere
    Hälfte {a} bis {b} kW" (nur mit Band) und „läuft in {p} % der {n} Ereignisse"; ohne Mittel
    „keine Messung"; „angelaufen {p} %"; ab Minute 0 „ohne Anforderung {p} %" mit gestrichelter
    Marke. Grund `C.deep` #082431, Rand `rgba(242,169,0,.4)`, Schrift #f1f5f5 12 px.
    Legende unter dem Diagramm, in der Karte (`Wirkung.tsx:208-229`), `.uhr-legende` = Liste ohne
    Punkte, `flex-wrap`, `gap 4px 22px`, 11,5 px/1.4, `--text-3` (`globals.css:642-644`), Marken
    10×10 px, Radius 2: „jede einzelne Antwort" (Linie 2 px, Deckung 0,45), „Mittel der Leistung,
    unten: Anteil angelaufen" (Linie 2 px voll), „mittlere Hälfte der Antworten" (Fläche, Deckung
    0,3) **oder**, unter 8 Ereignissen, der Satz „das Band der mittleren Hälfte erscheint ab 8
    Ereignissen" (`:217-224`), „Anteil angelaufen ohne Anforderung, zur selben Tageszeit"
    (gestrichelt, 2 px, `C.mist`; `.wk-marke-gestrichelt` `globals.css:661`).
    DATEN: `faecher.minuten`, `faecher.mittel_kw`, `faecher.q25_kw`, `faecher.q75_kw`,
    `faecher.n`, `faecher.anteil_laeuft`, `faecher.anteil_angelaufen`, `ereignisse[].kw`,
    `ereignisse[].auswertbar`, `vergleich.angelaufen_bis`, `vor_min`, `nach_min`, `folge_min`,
    `schwelle_kw`.

  * **Karte „Jede Anforderung"**  (`Wirkung.tsx:233-238`, Raster `Ereignisraster.tsx:56-117`)
    Nur wenn `d.n > 0` (`:233`). Rechts wörtlich „sortiert nach Verzögerung · **eine Zeile öffnet
    die Wiedergabe dieses Augenblicks**" (`:235`).
    Kopfzeile (`Ereignisraster.tsx:65-85`): Marken `[-vor, 0, 30, 60, 90, nach]` ohne Doppelte
    (`:61`), in `.wk-achse` (relativ, 16 px hoch) absolut bei
    `left: ((m+vor)/breite)*100%`; `transform: translateX(-50%)`, **aber die erste ohne Versatz und
    die letzte um −100 %** (`globals.css:671-673`), Schrift 10 px `--text-3`, `nowrap`. Bei 0 steht
    „Anforderung", am Ende „+120 min", dazwischen „+30"/„−30"; die Mittelmarken tragen `.wk-fein`
    und **verschwinden unter 560 px** (`globals.css:676`, Begründung `Ereignisraster.tsx:69-70`).
    Gruppen (`wirkung.ts:19-53`): „angelaufen", „nicht angelaufen", „lief schon", „Messung fehlt" –
    in dieser Reihenfolge, leere fallen weg; Überschrift `.kicker.wk-gruppentitel` 11 px,
    `margin 12px 0 4px 6px` (`globals.css:674`), Text „{Titel} · {Anzahl}"
    (`Ereignisraster.tsx:88-90`). Innerhalb nach Verzögerung, bei Gleichstand der jüngste zuerst
    (`wirkung.ts:47-51`). Gezeigt werden die **jüngsten 80** (`MAX_ZEILEN`, `:27`, `:59`).
    Zeile (`:31-54`): ein `<Link href={wiedergabeZiel(e.at)}>` – `/waerme/wiedergabe?day=
    {Haustag}&t={Hausstunde}` (`wirkung.ts:120-122`) – mit `title="{wann} · {ergebnis} ·
    {kontakt_min} min angefordert. Öffnet die Wiedergabe." (`:37`). Raster
    `112px / minmax(0,1fr) / 104px`, `gap 12px`, Polster 3/6, Radius 4, 11,5 px; Hover/Fokus
    `background: rgba(255,255,255,.06)` und das Ergebniswort wird `--text-1`
    (`globals.css:663-668`). Links „Sa., 07.11. 14:35" in Mono, `--text-2`, `nowrap`; rechts das
    Ergebniswort in `--text-3`: „lief schon", „Messung fehlt", „kein Anlauf", „sofort",
    „nach {v} min" bzw. ab der Folgefrist „erst nach {v} min" (`wirkung.ts:74-81`).
    Balken: SVG `viewBox="0 0 {vor+nach+1} 10"`, `preserveAspectRatio="none"`, 13 px hoch
    (`globals.css:669`). Gemessen und gestanden: `rgba(255,255,255,.07)`, Höhe 7; laufend:
    `C.heatPump`, Höhe 7; **nicht gemessen bleibt leer** (`:41-45`, `wirkung.ts:55-71`).
    Kontaktstreifen bei y=8, Höhe 2, `C.mist`, auf das Fenster beschnitten (`:46`). Nullpunkt
    `rgba(255,255,255,.75)` 1,5 px mit `vector-effect: non-scaling-stroke` (`:49`).
    Legende (`:96-115`): „Wärmepumpe läuft" (`C.heatPump`, 10×10), „gemessen, steht"
    (`rgba(255,255,255,.12)`), „angefordert" (`C.mist`, `.wk-marke-strich` 3 px hoch,
    `globals.css:660`), „leer: keine Messung", und als **letzter Punkt derselben Liste**, wenn mehr
    als 80 Ereignisse da sind: „gezeigt sind die jüngsten 80 von {ereignisse.length}
    Anforderungen" (`:110-114`).
    **Handy-Fassung** (`globals.css:676`): `.wk-zeile` wird `92px / 1fr / 78px`, `gap 8px`,
    10,5 px; `.wk-fein` verschwindet.
    DATEN: `ereignisse[]` (`at`, `lief_schon`, `auswertbar`, `gefolgt`, `verzoegerung_min`,
    `kontakt_min`, `kw[]`), `schwelle_kw`, `vor_min`, `nach_min`, `folge_min`, `n`.

  * **Karte „Zu diesem Zeitraum"**  (`Wirkung.tsx:241-250`)
    Nur wenn `hinweise_de` nicht leer. `<ul class="wk-hinweise">`: echte Liste mit
    `padding-left 18px`, `gap 8px`, `max-width 78ch`, 13 px/1.5, `--text-2`
    (`globals.css:675`). Kommentar `:240`: „Was für diesen Zeitraum gilt, bleibt offen stehen;
    zugeklappt wäre es verschwiegen."
    DATEN: `hinweise_de`.

  * **Methode**  (`Wirkung.tsx:252-260`, Baustein `ui/Methode.tsx:66-77`)
    `<details class="card methode">`; `summary` mit Kicker „Was die Auswertung kann", daneben
    `kurz` „ein Zusammenhang in der Zeit, keine Ursache · Vergleich zur selben Tageszeit"
    (12,5 px `--text-3`, `globals.css:730`) und der Pfeil, der sich beim Öffnen dreht (`:731-732`).
    Inhalt: `<ul>` mit `methode_de`, `padding-left 18px`, `gap 8px`, `max-width 90ch`,
    **13 px/1.55 in `--text-2`** (`globals.css:735`), Polster `0 18px 18px` (`:733`).
    Am Telefon: `summary` 15/16 px Polster, Kicker als lesbare Schrift 15 px 600
    (`handy.css:212-217`), Inhalt 14,5 px.
    DATEN: `methode_de`.

  * **Farben und Einheiten der Vorlage** (`charts/palette.ts`, `tokens.css`)
    `C.heatPump` #e0966b (`:53`), `C.mist` #7fa3b3 (`:61`), `C.gridline` `rgba(255,255,255,.09)`
    (`:78`), `C.axis` `rgba(255,255,255,.2)` (`:79`), `C.text` `rgba(255,255,255,.48)` (`:80`),
    `C.deep` #082431 (`:81`), `MONO` = IBM Plex Mono (`:84`). `--text-1/2/3` = weiß 92/72/48 %,
    `--line-1` 10 %, `--line-2` 17 %, `--surface-1` #0f2e3d, `--surface-2` #123544, `--amber`
    #f2a900, `--alert` #e0533d (`tokens.css:11-34`, `:64`).

  * **Dienst** (`packages/hems-core/src/hems_core/thermal/kontaktwirkung.py`)
    `VOR_MIN = 30`, `NACH_MIN = 120`, `FOLGE_MIN = 30`, `MIN_EREIGNISSE = 8` (`:42-52`).
    `_faecher` setzt `minuten = list(range(-VOR_MIN, NACH_MIN + 1))` **unbedingt**, also immer 151
    Minuten, auch ohne ein einziges auswertbares Ereignis (`:281-321`, Aufruf `:524`);
    `anteil_angelaufen` ist `None` für Minuten < 0 und ohne Ereignisse (`:306-311`);
    `vergleich.angelaufen_bis` reicht nur bis `FOLGE_MIN − 1` (`:142-144`).

LUECKEN:

  [traegt-die-seite] **Der Antwortfächer hat keine senkrechte Achse – und die untere Fläche
    keinen festen Bereich 0 bis 100 Prozent.** `Wirkungszeichnung.swift:175-195` (`flaeche`) setzt
    nur `chartXScale`, `chartXSelection` und `chartXAxis`; in der ganzen Datei kommt weder
    `chartYAxis` noch `chartYScale` vor (gesucht nach „chartYAxis" und „chartYScale" in
    `apps/ios/DuckCurveHome/Diagramme/Wirkungszeichnung.swift`: kein Treffer – anders als in
    `Speichertagbild.swift:59-62`, `Prognosezeichnung.swift:261`, `Kennlinienbilder.swift:135`).
    Die Vorlage setzt für die untere Fläche ausdrücklich `min: 0, max: 100, interval: 50` und den
    Formatter `"{value} %"` (`Antwortfaecher.tsx:164-171`), für die obere `min: 0, splitNumber: 3`
    (`:157-163`). Ohne das skaliert Swift Charts die untere Fläche nach den Daten: steigt der
    Anlaufanteil nur auf 30 Prozent, läuft die Treppe trotzdem bis an den oberen Rand und sieht aus
    wie volle Folgsamkeit – die Hauptaussage der Fläche (der **Abstand** der beiden Treppen in
    Prozent) ist dann falsch ablesbar. Dazu fehlen beide Achsenbeschriftungen und die waagerechten
    Rasterlinien in `C.gridline` (`Antwortfaecher.tsx:162`, `:170`).

  [spuerbar] **Die Zeilen des Ereignisrasters führen nirgendwohin.**
    `Wirkungszeichnung.swift:414-431` baut einen reinen `HStack` ohne `Button`, ohne
    `Wegweiser` und ohne Hervorhebung (gesucht nach „weg" und „Wegweiser" in
    `Wirkungszeichnung.swift`: kein Treffer außer dem Wortteil in Kommentaren). Das Ziel liegt
    fertig im Kern: `Wirkungsbild.Ereigniszeile.weg` (`Wirkungsbild.swift:383`), gefüllt aus
    `wiedergabeweg` (`:572-575`, `:633`). Die Vorlage macht jede Zeile zu einem `Link`
    (`Ereignisraster.tsx:37`) mit Hover-Grund und hellerem Ergebniswort
    (`globals.css:664`, `:668`) und sagt es auch im Kartenkopf: „eine Zeile öffnet die Wiedergabe
    dieses Augenblicks" (`Wirkung.tsx:235`). In der App steht dort nur „sortiert nach Verzögerung"
    (`FahrplanSeiten.swift:184`) – der halbe Satz fehlt mitsamt der Sache.

  [spuerbar] **Die Achse des Antwortfächers schreibt „min" unter jede Marke.**
    `Wirkungszeichnung.swift:158` ruft `Wirkungsbild.achsenText(Int(m))`, und das gibt immer die
    Einheit mit („+30 min", `Wirkungsbild.swift:512-515`). Bei sechs Marken (−30, 0, 30, 60, 90,
    120 aus `markenwerte`, `:169-171`) steht „min" fünfmal. Die Vorlage schreibt es nur bei 0 und
    am Ende (`Antwortfaecher.tsx:87`) und begründet es (`:85-86`). Der Kern hat genau dafür schon
    `Wirkungsbild.achsenmarke(_:ende:)` (`Wirkungsbild.swift:520-523`) – das Raster benutzt sie
    (`:765`), der Fächer nicht.

  [spuerbar] **Die Karte „Antwortfächer" erscheint auch ohne eine einzige auswertbare
    Anforderung.** `FahrplanSeiten.swift:164` prüft `!bild.faecher.isEmpty`; `bild.faecher` wird
    aus `w.faecher.minuten` gebaut (`Wirkungsbild.swift:673-688`), und der Dienst füllt
    `minuten` unbedingt mit 151 Werten (`kontaktwirkung.py:282`, Aufruf `:524`) – die Bedingung
    ist also immer wahr. Gezeigt wird dann eine leere Zeichnung mit Schwellenlinie, Folgefenster
    und vierteiliger Legende, mit der Unterzeile „0 Anforderungen bei stehender Maschine, am
    Beginn übereinandergelegt". Die Vorlage prüft `d.n_auswertbar > 0` (`Wirkung.tsx:204`).

  [spuerbar] **Nach einem Fehler beim ersten Laden gibt es keine Zeitraumwahl mehr.**
    `FahrplanSeiten.swift:217-218`: ist `wirkung == nil` und `fehler != nil`, zeigt die Seite nur
    `Stoerung`; die `Tagewahl` steckt in `urteilskarte` (`:246`), die nur mit Daten gebaut wird
    (`:156-158`). Die Vorlage lässt die drei Knöpfe stehen und setzt den Fehler als Absatz
    darunter in die Karte (`Wirkung.tsx:146-156`) – wer 7 statt 30 Tage wählt, kommt so aus dem
    Fehler heraus. Dasselbe Muster ist im Projekt schon begründet und gebaut:
    `NachbetrachtungSeite.swift:170-176` („die Tagwahl bleibt bedienbar, und wer einen anderen Tag
    nimmt, kommt aus dem Fehler heraus").

  [spuerbar] **Dem Quotenbild fehlen die drei senkrechten Rasterlinien.**
    `Wirkungszeichnung.swift:95-114` (`achse`) zeichnet nur die drei Prozentzahlen; der eigene
    Kommentar `:95` verspricht sie aber („Null, fünfzig, hundert – mit den Rasterlinien, an denen
    man die Punkte vergleicht"). Die Vorlage zieht sie durch beide Zeilen, von y=14 bis y=104, in
    `rgba(255,255,255,.09)` (`Wirkung.tsx:89-96`). Ohne sie liegen die beiden Punkte auf einer
    unbeschrifteten Fläche, und der Vergleich – die Aussage des Bildes – muss geschätzt werden.

  [spuerbar] **Die Unterzeile der Fächerkarte wird am Telefon abgeschnitten.**
    `FahrplanSeiten.swift:169-175` setzt `.lineLimit(1)`, und `Karte.kopf` stellt das Beiwerk auf
    schmalem Schirm in **dieselbe** Zeile wie die Überschrift (`Karte.swift:54-82`). Die Vorlage
    gibt `.card-head-right` am Telefon eine eigene Zeile über die ganze Breite und erlaubt
    ausdrücklich den Umbruch (`handy.css:185`: `flex-basis:100%; white-space:normal;
    overflow:visible; text-overflow:clip`), begründet in `ui/Card.tsx:43-44`. Von „0 Anforderungen
    bei stehender Maschine, am Beginn übereinandergelegt" bleibt in der App ein Wortfragment.

  [klein] **Das Quotenbild wächst am Telefon nicht mit.** `globals.css:676` stellt unter 560 px
    `.wk-q-name` auf 15 px, `.wk-q-zahl` auf 20 px und `.wk-q-klein`/`.wk-q-achse` auf 13 px (von
    12,5 / 17 / 10,5). `Wirkungszeichnung.swift:36-58` und `:95-114` benutzen unabhängig von der
    Breite `Schrift.klein` (13), `Schrift.mono(17)` und `Schrift.achse` (10,5) – auch die
    Spaltenbreiten 92 und 86 (`:41`, `:57`) sind fest. Dass die Datei die Breite kennt, zeigt
    `Ereignisraster` daneben (`:372-373`, `:420`, `:429`).

  [klein] **Die erste und letzte Achsenmarke des Rasters hängen über den Rand.**
    `Wirkungszeichnung.swift:398-405` setzt alle Marken mit `.position(x: anteil * breite)`, also
    mittig. Die Vorlage nimmt genau der ersten und der letzten den Versatz:
    `.wk-achse > span:first-child { transform: none }` und `:last-child { translateX(-100%) }`
    (`globals.css:672-673`). In der App reicht „−30 min" nach links in die Datumsspalte und
    „+120 min" nach rechts aus der Zeile.

  [klein] **Der Fächer zeichnet senkrechte Rasterlinien, die die Vorlage nicht hat.**
    `Wirkungszeichnung.swift:147-149` und `:154-156` setzen in beiden Flächen
    `AxisGridLine()`; die Vorlage schaltet sie auf beiden x-Achsen ab
    (`Antwortfaecher.tsx:91`: `splitLine: { show: false }`) und hat Linien nur waagerecht aus der
    y-Achse (`:162`, `:170`).

  [klein] **Der ausgewertete Zeitraum steht zweimal da.** Einmal als Beiwerk der Urteilskarte
    (`FahrplanSeiten.swift:235-238`, wie `Wirkung.tsx:145`) und noch einmal als Kicker über dem
    Kachelfeld (`:161`). Über dem Kachelfeld hat die Vorlage keine Überschrift
    (`Wirkung.tsx:171`).

  [klein] **Das Band der mittleren Hälfte schließt sich über Lücken.**
    `Wirkungszeichnung.swift:221-229` erzeugt je Minute mit Band eine `AreaMark` ohne Reihen- oder
    Stückkennung; Minuten ohne Band (`q25Kw == nil`, gesetzt in `Wirkungsbild.swift:683-684`,
    sobald `n < 8`) werden übersprungen, und Swift Charts verbindet die Nachbarn. Die Vorlage setzt
    dort `null` in **beide** gestapelten Reihen, damit die Fläche abbricht
    (`Antwortfaecher.tsx:59-65`). Für die Kurven ist das Problem im Kern schon gelöst –
    `Kurvenstueck` mit eigener `id` je Stück (`Wirkungsbild.swift:206-220`, `:728-750`) –, für das
    Band nicht.

  [klein] **Der Rasterhinweis steht an der falschen Stelle und zählt eine andere Zahl.**
    `Wirkungszeichnung.swift:386-388` setzt ihn als eigene Zeile **vor** die Legende; die Vorlage
    macht ihn zum letzten Punkt derselben Legendenliste (`Ereignisraster.tsx:110-114`). Und er
    rechnet mit `w.n`, also allen Anforderungen des Zeitraums (`Wirkungsbild.swift:711-715`),
    während die Vorlage die **gelieferten** Ereignisse zählt (`alle.length`,
    `Ereignisraster.tsx:112`) – bei einem Dienst, der `ereignisse` selbst begrenzt, nennt die App
    eine Zahl, die nicht zu den gezeigten Zeilen passt.

  [klein] **Das Ergebniswort der Rasterzeile ist rechts ausgerichtet.**
    `Wirkungszeichnung.swift:425-429`: `.frame(width:…, alignment: .trailing)`. In der Vorlage ist
    `.wk-ergebnis` eine Rasterspalte ohne eigene Ausrichtung, der Text beginnt also links
    (`globals.css:663`, `:667`); bei 80 Zeilen stehen die Wörter dort untereinander auf einer
    Kante, in der App auf der anderen.

  [klein] **Die Flächentitel des Fächers stehen in der falschen Schrift.**
    `Wirkungszeichnung.swift:181`: `Schrift.winzig` (Sans 11,5) in `Farbe.text3`. Die Vorlage setzt
    `10px <Mono>` in `C.text` (= weiß 48 %, also dieselbe Farbe, andere Familie und Größe)
    (`Antwortfaecher.tsx:106`, `:112`).

  [klein] **Fünf Kacheln stehen am großen iPad in 3 + 2 statt in einer Reihe.**
    `FahrplanSeiten.swift:162`: `spalten: 3`. Die Vorlage schaltet ab 1280 px auf fünf Spalten
    (`Wirkung.tsx:171`: `md:grid-cols-3 xl:grid-cols-5`) – das trifft das iPad Pro 12,9" im
    Querformat. Dazu: die Zahl ist in der Vorlage 26 px (`Stat.tsx:9`) und am Telefon 21 px
    (`handy.css:382`), in der App durchweg `Schrift.mono(25)` (`Karte.swift:240`).

  [klein] **Der Methodentext ist kleiner und blasser als in der Vorlage.**
    `Bericht.swift:543-548` setzt die Sätze auf `Schrift.winzig` (11,5) in `Farbe.text3` und ohne
    Aufzählungspunkte; die Vorlage hat eine echte Liste mit 13 px/1.55 in `--text-2`
    (`globals.css:735`), am Telefon 14,5 px (`handy.css:217`). Der Baustein ist geteilt – die
    Änderung trifft alle Seiten mit `Methode`.

  [klein] **Der Urteilssatz hat eine feste Größe.** `FahrplanSeiten.swift:275`:
    `Schrift.sans(20)`. Die Vorlage schreibt `clamp(17px, 2vw, 22px)` (`globals.css:650`), also
    17 px auf 390 Punkten und 22 px an der Wand; dazu `max-width: 60ch`, was die App nicht setzt
    (im `HStack` begrenzt sie nur das Bild auf 460, `:264`).

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `KontaktwirkungOut` mit allen Feldern der Vorlage:
    `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:6313-6368` – `von`, `bis`,
    `schwelleKw`, `vorMin`, `nachMin`, `folgeMin`, `ereignisse`, `faecher`, `n`, `nLiefSchon`,
    `nAuswertbar`, `gefolgt`, `quote`, `quoteLo`, `quoteHi`, `vergleich`,
    `verzoegerungMedianMin`, `nachlaufMedianMin`, `nachlaufN`, `abdeckungKontakt`,
    `abdeckungLeistung`, `urteil`, `urteilDe`, `hinweiseDe`, `methodeDe`, `days`.
  * `Ereignis` (`Schema.swift:3475-3514`): `at`, `liefSchon`, `auswertbar`, `gefolgt`,
    `verzoegerungMin`, `kontaktMin`, `kw: [Double?]`.
  * `Faecher` (`Schema.swift:3574-3617`): `minuten`, `mittelKw`, `medianKw`, `q25Kw`, `q75Kw`,
    `anteilLaeuft`, `n`, `anteilAngelaufen`.
  * Abfrage: `Api.kontaktwirkung(tage:)` → `GET /anlage/kontaktwirkung?days=`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:268-269`).
  * `Wirkungsbild` (`…/Zustand/Wirkungsbild.swift:22-770`) mit
    `vorMin`/`nachMin`/`folgeMin`/`schwelleKw`/`breite` (`:56-69`), `urteilswort`/`urteilssatz`/
    `spanne` (`:74-78`), `quotenzeilen` samt `zahl` und `bereich` (`:100-141`),
    `quotenerklaerung` und `quotenbeschreibung` wörtlich wie die Vorlage (`:659-667`),
    `faecher: [Faecherpunkt]` mit der Bandentscheidung **je Minute** (`:157-191`, `:677-688`),
    `mittel` und `einzelkurven` als lückenfreie `Kurvenstueck`e (`:206-237`, `:689-695`,
    `:728-750`), `kurvendeckung` = `deckung(n)` (`:240`, `:438-441`), `anteilOhne` (`:246`,
    `:698-700`), `bandHinweis` (`:252`, `:703-706`), `auskunft(minute:)` als Ersatz für den
    Tooltip (`:293-336`), `gruppen` (`:403`, `:588-614`), `achsenmarken` (`:426`, `:758-769`),
    `rasterHinweis` (`:429`, `:711-715`).
  * Rechnungen einzeln prüfbar: `betrieb(kw:schwelleKw:)` mit drei Zuständen (`:453-483`),
    `gruppe(_:)` (`:486-490`), `ergebnisText(_:folgeMin:)` (`:497-506`), `achsenText(_:)`
    (`:512-515`), `achsenmarke(_:ende:)` (`:520-523`), `urteilswort(_:)` (`:530-538`),
    `spanne(von:bis:)` (`:543-548`), `wann(_:)` (`:561-566`), `wiedergabeweg(_:)` (`:572-575`).
    Konstanten `mindestensFuerBand = 8`, `maxKurven = 80`, `maxZeilen = 80` (`:33-43`).
  * `Wirkungskacheln.kacheln(_:)` – die fünf Kacheln in der Reihenfolge der Vorlage mit allen
    Nebensätzen (`Wirkungsbild.swift:783-828`).
  * Formate: `Formate.prozentZahl` und `Formate.minutenZahl` (`Wirkungsbild.swift:831-853`),
    `Formate.prozent` (`…/Formate/Formate.swift:98-101`), `Formate.kw`/`kwMitEinheit` (`:62-74`).
  * Bausteine der Oberfläche: `Karte`/`Kachelfeld`/`Kachel`/`Leer`/`Stoerung`
    (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:15-465`), `Kacheldaten.weg` samt dem Knopf, der
    daraus wird (`:129`, `:181-187`), `Tagewahl` mit der Form `.wgWahl` Maß für Maß aus
    `globals.css:621-622` (`apps/ios/DuckCurveHome/Bausteine/Tagewahl.swift:157-175`),
    `Methode` (`…/Seiten/Bericht.swift:514-576`), `Kicker`/`Zahl`/`Schrift`
    (`…/Gestalt/Typografie.swift:45-151`), `Umbruchzeile`, `Seite` mit dem Seitenkicker
    (`…/App/Seitenwahl.swift:154-217`), `Wegweiser.gehe(_:)` als Sprungmittel (Vorbild
    `…/Seiten/Technik/NachbetrachtungSeite.swift:159-168`).
  * Farben und Maße: `Farbe.waermepumpe` #E0966B, `Farbe.mist` #7FA3B3, `Farbe.rasterlinie`
    weiß 9 %, `Farbe.linie1` 10 %, `Farbe.linie2` 17 %, `Farbe.text2/3` 72/48 %, `Farbe.deep`,
    `Farbe.flaeche1/2` (`…/Gestalt/Marken.swift:17-34`, `:83-84`, `:97`).
  * Vorbild für eine senkrechte Achse mit Rasterlinien und führender Beschriftung:
    `apps/ios/DuckCurveHome/Diagramme/Speichertagbild.swift:59-79` (`chartYScale` auf feste
    Spanne, `AxisMarks(position: .leading)`, `AxisGridLine().foregroundStyle(Farbe.rasterlinie)`,
    `chartYAxisLabel(position: .topLeading)`).

ES FEHLT:

  1. `Wirkungsbild` sagt nicht, **ob** der Fächer gezeigt werden darf. Die Zahl steckt heute nur
     als lokale Variable in `baue` und `kacheln` (`Wirkungsbild.swift:702`, `:785`; gesucht nach
     einem Feld „nAuswertbar" in der Datei: nur diese beiden `let`). Neues Feld in
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Wirkungsbild.swift`:
     `public var nAuswertbar: Int = 0` und `public var faecherZeigen: Bool { nAuswertbar > 0 }`
     (Vorlage `Wirkung.tsx:204`). Dazu `public var rasterZeigen: Bool { !gruppen.isEmpty }`, damit
     die Ansicht keine Bedingung mehr selbst formt.
  2. Das Band der mittleren Hälfte fehlt als **Stückliste**. Heute gibt es nur `q25Kw`/`q75Kw` je
     Minute (`Wirkungsbild.swift:164-165`). Neu in derselben Datei, nach dem Muster von
     `Kurvenstueck`: `public struct Bandstueck: Sendable, Hashable, Identifiable { public let id:
     String; public let punkte: [(minute: Int, unten: Double, oben: Double)] }` und
     `public var band: [Bandstueck]`, gebaut in `baue` aus denselben Minuten, die `stuecke`
     benutzt – damit `AreaMark` je Stück eine eigene Reihe bekommt und sich nicht über Minuten
     ohne Band schließt (Vorlage `Antwortfaecher.tsx:59-65`).
  3. Die Achsenmarken des Fächers fehlen als fertige Liste. Der Kern hat sie nur für das Raster
     (`achsenmarken`, `Wirkungsbild.swift:426`, `:758-769`). Neu daneben:
     `public var faechermarken: [Achsenmarke]` aus `stride(from: -vorMin, through: nachMin, by:
     30)` mit `achsenmarke(_:ende:)` als Wort – dann kann die Zeichnung nicht mehr versehentlich
     `achsenText` nehmen (Vorlage `Antwortfaecher.tsx:85-87`).

BAUPLAN:

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Wirkungsbild.swift` – die drei Punkte aus
     „ES FEHLT": `nAuswertbar`/`faecherZeigen`/`rasterZeigen` (setzen in `baue`, `:702` ist die
     Zahl schon da), `Bandstueck` + `band` (bauen neben `b.mittel`, `:689`), `faechermarken`
     (bauen neben `b.achsenmarken`, `:709`). Tests in
     `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests/WirkungsbildTests.swift`: Band bricht an einer
     Minute mit `n < 8` ab; `faecherZeigen` ist falsch, wenn `nAuswertbar == 0`, obwohl
     `faecher.minuten` 151 Einträge hat; `faechermarken` trägt „min" nur bei 0 und am Ende.
  2. `apps/ios/DuckCurveHome/Diagramme/Wirkungszeichnung.swift`, `Quotenbild` – in `achse`
     (`:95-114`) die drei senkrechten Linien in `Farbe.rasterlinie` über die Höhe beider Zeilen
     ziehen (ein `ZStack` hinter den Zeilen, nicht in der Beschriftungszeile, damit sie wie in der
     Vorlage von y=14 bis y=104 durchgehen); Schriftgrößen und Spaltenbreiten in `zeile`
     (`:36-58`) und `achse` nach `horizontalSizeClass` umschalten (15 / 20 / 13 bei `.compact`,
     sonst 13 / 17 / 10,5, `globals.css:676`).
  3. Dieselbe Datei, `Antwortfaecher` – `flaeche` (`:175-195`) bekommt zwei Fassungen oder zwei
     weitere Parameter: `chartYScale(domain:)` und `chartYAxis { AxisMarks(position: .leading, …)
     { AxisGridLine().foregroundStyle(Farbe.rasterlinie); AxisValueLabel … } }` nach dem Vorbild
     `Speichertagbild.swift:59-79`; obere Fläche Untergrenze 0 und drei Marken, untere Fläche
     `0...100` mit Marken bei 0/50/100 und der Einheit „%". Senkrechte `AxisGridLine()` in
     `:147-149`/`:154-156` entfernen (Vorlage `Antwortfaecher.tsx:91`). `:158` auf
     `bild.faechermarken` umstellen. `:181` auf `Schrift.achse` (Mono 10,5) setzen.
     `achsenbreite` (`:139`) entweder wirklich einsetzen (gleich breite Beschriftung für beide
     Flächen, damit der Nullpunkt in beiden an derselben Stelle steht – der Grund, der dort steht)
     oder streichen; heute ist es toter Code (gesucht nach „achsenbreite" in der Datei: nur die
     Zeile der Festlegung). Band aus `bild.band` zeichnen (`:221-229`).
  4. Dieselbe Datei, `Ereignisraster` – `zeile` (`:414-431`) in einen `Button` fassen, der
     `wegweiser.gehe(z.weg)` ruft (`@Environment(Wegweiser.self)` wie
     `Karte.swift:176`/`:181-187`), mit `buttonStyle(.plain)`, einem Grund `Farbe.linie1` beim
     Drücken und `accessibilityLabel` aus `wann`, `ergebnis` und `kontaktMin` nach dem `title` der
     Vorlage (`Ereignisraster.tsx:37`). Ergebniswort auf `alignment: .leading` (`:429`). `achse`
     (`:393-412`): erste Marke linksbündig, letzte rechtsbündig (`globals.css:672-673`).
     `rasterHinweis` als letzten Eintrag in `legende` (`:459-475`) verschieben.
  5. `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift`, `WirkungSeite` –
     `:164` auf `bild.faecherZeigen` umstellen, `:180` auf `bild.rasterZeigen`; `:184` auf
     „sortiert nach Verzögerung · eine Zeile öffnet die Wiedergabe dieses Augenblicks"
     (`Wirkung.tsx:235`); `.lineLimit(1)` in `:174` streichen und das Beiwerk am Telefon umbrechen
     lassen; den Kicker des Kachelfeldes (`:161`) streichen; `:275` auf eine Größe nach Breite
     (17 bei `.compact`, sonst 20–22) und `spalten` (`:162`) auf 5 bei sehr breitem Schirm, sonst 3.
  6. Dieselbe Datei – den Fehlerfall umbauen: `urteilskarte` immer zeigen, auch ohne `wirkung`
     (Spanne und Urteilssatz dann leer, `Leer`/`Stoerung` im Karteninneren), damit die `Tagewahl`
     stehen bleibt; `:217-221` entsprechend auflösen. Vorbild und Begründung:
     `NachbetrachtungSeite.swift:170-176`.
  7. `apps/ios/DuckCurveHome/Gestalt/Karte.swift`, `Karte.kopf` (`:54-82`) – das Beiwerk am
     Telefon in eine eigene Zeile unter die Überschrift setzen und umbrechen lassen
     (`handy.css:185`). Betrifft alle Karten mit Beiwerk; zuerst prüfen, welche heute auf die
     einzeilige Fassung bauen.
  8. `apps/ios/DuckCurveHome/Seiten/Bericht.swift`, `Methode` (`:543-548`) – Sätze auf
     `Schrift.klein` in `Farbe.text2` mit Aufzählungspunkt, am Telefon eine Stufe größer
     (`globals.css:735`, `handy.css:217`). Geteilter Baustein, eigener Schritt.

WAS SCHWIERIG WIRD:

  * **Gleich breite Zeichenflächen für zwei übereinanderliegende Diagramme.** Die Vorlage erzwingt
    es mit `outerBoundsMode: "none"` und festen Rändern links 46 / rechts 34
    (`Antwortfaecher.tsx:34-35`, `:148-154`); Swift Charts rückt jede Fläche nach ihrer eigenen
    Achsenbeschriftung ein, und dann steht der Nullpunkt – die Minute, in der die Anforderung
    beginnt – in den beiden Flächen an verschiedener Stelle. Der Weg, den das Projekt dafür schon
    gewählt hat: `.chartPlotStyle`/feste Achsenbreite. Vorbild mit zwei gestapelten Flächen:
    `apps/ios/DuckCurveHome/Diagramme/Speichertagbild.swift:40-103` – dort haben beide Flächen
    dieselbe Achsenart (`prozentmarken`/`kilowattmarken`, je zwei Stellen) und derselbe
    `chartXScale(domain: kurve.fenster)`. Hier sind es „0/50/100 %" oben gegen „0/2/4" unten; die
    `achsenbreite`-Zeile (`Wirkungszeichnung.swift:139`) ist genau dafür angelegt und nie benutzt
    worden.
  * **Eine Fläche mit Lücken.** `AreaMark` kennt kein `connectNulls: false`. Der Weg im Projekt
    ist, die Reihe im Kern in Stücke zu zerlegen und je Stück eine eigene `series`-Kennung zu
    geben – `Wirkungsbild.Kurvenstueck` (`Wirkungsbild.swift:206-220`) und
    `Speichertagbild.swift:105-120` (`series: .value("Reihe", "leistung-\(nummer)")`). Für das
    Band braucht es dasselbe, nur mit `yStart`/`yEnd`.
  * **Tooltip.** Am Telefon gibt es kein Darüberfahren; den Inhalt des Tooltips
    (`Antwortfaecher.tsx:116-147`) trägt der Kern schon als `Wirkungsbild.auskunft(minute:)`
    (`Wirkungsbild.swift:293-336`), gezeigt über der Zeichnung (`Wirkungszeichnung.swift:294-324`)
    – dasselbe Muster wie `Fahrplanbild.auskunft`. Das ist gelöst und darf beim Umbau der Achsen
    nicht verlorengehen: `chartXSelection` (`:191`) hängt an demselben `gewaehlt`-Zustand wie die
    Auskunft, und beide Flächen teilen ihn absichtlich (`:131-133`).
  * **Hover gibt es nicht.** Der Hover-Grund der Rasterzeile (`globals.css:664`) und das hellere
    Ergebniswort (`:668`) haben in SwiftUI kein Gegenstück. Der Weg im Projekt ist der sichtbare
    Verweis statt des Zustands: „Ein Verweis ist im Haus ein Text in Bernstein mit „›""
    (`NachbetrachtungSeite.swift:155-158`, umgesetzt in `Karte.swift:254-257`). Für achtzig Zeilen
    wäre ein „›" je Zeile zu viel Lärm; tragbar ist der Druckzustand des `Button` plus der Hinweis
    im Kartenkopf, den die Vorlage ohnehin schreibt (`Wirkung.tsx:235`).
