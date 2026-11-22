========================= messen:waerme-anlage   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt

`apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift`

1. `Seite { … }` (`App/Seitenwahl.swift:141-170`) - Rollbereich, Rand 16, Abstand 14, kein
   Bereichskicker, keine Zeitwahl (`AnlageSeite.swift:23`).
2. Bei Fehler oben `Stoerung(fehler:)` mit Knopf „Erneut" (`AnlageSeite.swift:24-26`,
   `Gestalt/Karte.swift:410-436`).
3. Kopfzeile: links „Stand hh:mm", rechts „<x,x °C> draußen"; beides `Schrift.winzig` (11,5) in
   `Farbe.text3` (`AnlageSeite.swift:95-105`). Außentemperatur mit **einer Nachkommastelle**
   (`Formate.celsius(aussen, stellen: 1)`, Zeile 101).
4. `Karte(kicker: "Die Anlage", titel: Anlagenschema.erzeugerSatz(…))` mit `Anlagenbild` darin
   (`AnlageSeite.swift:29-31`).
5. Drei Lesekarten untereinander: „Lesen" (3 Sätze), „Vier getrennte Systeme" (5 Sätze),
   „Gemessen und gerechnet" (4 Sätze), je `Schrift.klein`/`Farbe.text2`
   (`AnlageSeite.swift:49-93`).
6. Danach **sechs Zahlenkarten, die die Vorlage an dieser Stelle nicht hat**: „Strom" (10 Zeilen,
   `:107-125`), „Pufferspeicher" mit Glas plus 5 Zeilen (`:132-161`), „Wärmepumpe" (7 Zeilen,
   `:163-190`), „Pelletofen" (`:192-212`), „Heizkreise" (`:219-231`), „Warmwasser" (`:233-250`).
   Der Kopfkommentar der Datei begründet sie als Nutzerentscheidung (`AnlageSeite.swift:13-15`);
   sie sind daher **keine Lücke** und stehen unten nicht in der Liste.
7. Leerzustand: `Karte { Leer(satz: "Wird geholt …") }` (`AnlageSeite.swift:40`,
   `Gestalt/Karte.swift:390-404`).
8. Nachholen alle **10** Sekunden, ohne Sichtbarkeitsprüfung (`AnlageSeite.swift:265-271`).

Das Bild selbst (`apps/ios/DuckCurveHome/Diagramme/Anlagenbild.swift`, 638 Zeilen) ist da und
folgt der Vorlage in Aufbau und Koordinaten: Bühne 1200 × 640 (`Anlagenrohre.swift:17`), auf
Höhe 430 verkleinert und waagerecht gerollt (`Anlagenbild.swift:29-44`), 14 Rohre mit
**identischen Pfaden** (`Anlagenrohre.swift:70-110`), drei Lichter (`:82-96`), Quellen, Knoten,
fünf Kacheln, Glas, drei Pumpen, vier Stutzenschriften (`:229-285`).

VORLAGE:

  * **Hülle und Bereichskicker**  (`apps/web/src/app/waerme/anlage/page.tsx:7-13`)
    `AreaShell kicker="Strom · Speicher · vier Kreise"`; die Hülle setzt den Kicker rechts in die
    Reiterzeile (`components/layout/AreaShell.tsx:26`). Dort steht er in `.kicker`, 11 px, und ist
    **unter 768 px ausgeblendet** (`components/layout/AreaNav.tsx:96`: `hidden … md:block`). Am
    Telefon gibt es ihn also nicht. Seitentitel „Anlage · Duck Curve Home" (`page.tsx:5`),
    `dynamic = "force-dynamic"` (`:4`).
    DATEN: keine.

  * **Kopfzeile: ein Satz und der Stand**  (`components/anlage/Anlage.tsx:62-75`)
    `.anlage-kopf`: Flex, umbrechend, `align-items: baseline`, `justify-content: space-between`,
    Abstand `6px 24px` (`styles/globals.css:560`).
    Links `.anlage-satz` (`globals.css:561-562`): 15 px, Gewicht 300, Zeilenhöhe 1,4,
    `var(--text-2)`; das `<b>` darin 500 und `var(--text-1)`. Inhalt wörtlich, in dieser Folge:
    `{Math.round(outdoor_c)} °C draußen · ` dann **fett** `erzeugerSatz(daten, nowMs)` dann
    ` · Strom aus {mischung(strom).text}`. Ohne Daten steht dort nur „Anlage" (`Anlage.tsx:71`).
    `mischung().text` ist z. B. „PV 72 %, Netz 28 %" - Quellen unter 5 % fallen weg, Prozent mit
    geschütztem Leerzeichen (`components/anlage/schema.ts:116-119`).
    Rechts `.anlage-stand` (`globals.css:563`): 12 px, `var(--text-3)`, `white-space: nowrap`,
    Text wörtlich „Stand {hhmm(at)} · alle 20 s" (`Anlage.tsx:74`).
    Zustände: lädt → „Anlage"; Fehler → Kopf bleibt stehen.
    DATEN: `api.anlage()`, Felder `outdoor_c`, `at`, `waermepumpe.running`,
    `waermepumpe.running_since`, `ofen.running`, `ofen.power_level`, `strom.share_pv`,
    `strom.share_grid`, `strom.share_battery`.

  * **Fehler**  (`Anlage.tsx:77`, `globals.css:596`)
    `.anlage-fehler`: Rand 1 px `var(--alert)` (#e0533d), Radius 6, Polster `10px 14px`,
    `var(--text-1)`, 13 px. Text ist die Fehlermeldung oder wörtlich „Die Anlage ist gerade nicht
    zu erreichen." (`Anlage.tsx:36`). **Kein Wiederholknopf**; die Bühne bleibt stehen, wenn
    schon Daten da sind.

  * **Die Bühne**  (`Anlage.tsx:79-89`, `globals.css:564-567`)
    `.anlage-buehne`: Radius 28, Polster 1 px, Hintergrund
    `linear-gradient(180deg, rgba(255,255,255,.14), rgba(255,255,255,.03) 30%, rgba(255,255,255,.02))`
    - das ist der Haarlinienrahmen -, Schatten `0 40px 120px rgba(0,0,0,.45)`.
    `.anlage-innen`: Radius 27, Hintergrund
    `linear-gradient(180deg, rgba(10,39,53,.85), rgba(5,22,31,.9))`, `overflow: hidden`.
    `.anlage-scroll`: `overflow-x: auto`.
    `.anlage-flaeche`: Breite 100 %, **`min-width: 940px`**, Höhe automatisch,
    `font-variant-numeric: tabular-nums` und - ausdrücklich begründet in `globals.css:566-568` -
    `font-family: -apple-system, "SF Pro Display", "SF Pro Text", var(--font-sans)`:
    „Die Zahlen setzen die Systemschrift zuerst, weil ihre leichten Schnitte (200, 300) die
    Kacheln ruhig halten; IBM Plex kommt im Haus nur in 400 und 600."
    `viewBox="0 0 1200 640"`, `role="img"`, `aria-label="Anlage: Strom links, Speicher als Glas
    rechts, vier getrennte Wasserkreise"` (`Schema.tsx:175`).
    Kein Kicker, kein Titel über der Bühne.
    Leer: `.anlage-warten` (`globals.css:597`) - 420 px Mindesthöhe, Radius 28, Rand 1 px
    `var(--line-1)`, zentriert, 13 px, `var(--text-3)`, Text „Die Anlage wird geholt."
    (`Anlage.tsx:88`); bei Fehler bleibt der Kasten leer.
    DATEN: dieselbe Abfrage; Takt 20 000 ms, nur bei `visibilityState === "visible"`, zusätzlich
    bei jedem `visibilitychange` (`Anlage.tsx:18`, `:42-56`). Begründung im Kommentar
    `Anlage.tsx:14-16`: „Das ist langsamer als die Startseite, und mit Absicht: Die Pufferfühler
    melden minütlich, und eine Zahl, die sich öfter ändert als ihre Quelle, lügt mit der
    Nachkommastelle."

  * **Schriftklassen der Bühne**  (`globals.css:569-577`)
    `.anlage-cap` 11 px/500, `letter-spacing .12em`, Großbuchstaben, **`fill: var(--text-3)`**;
    `.anlage-name` 15/500, `-.01em`; `.anlage-sub` 12,5/300, `var(--text-2)`;
    `.anlage-hint` 11,5/300, `var(--text-3)`; `.anlage-num` Gewicht **200**,
    `letter-spacing -.03em`; `.anlage-unit` 12/400, `var(--text-2)`, Sperrung 0;
    `.anlage-glas` Füllung `rgba(255,255,255,.045)`, Strich `rgba(255,255,255,.10)`;
    `.anlage-glas-hi` Strich `url(#anlage-hairline)` 1 px - der Verlauf läuft von `#fff .28` über
    `.06` **bei 25 %** auf `.02` (`Schema.tsx:177-181`).
    `.anlage-rohr/.anlage-faden/.anlage-halo` ohne Füllung, runde Enden; `.anlage-halo` Strich
    **`#071d28`, Breite 20, Deckung .9** (`globals.css:578-579`).
    `.anlage-fade` Übergang `opacity .6s cubic-bezier(.2,.8,.2,1)`, bei
    `prefers-reduced-motion` aus (`globals.css:580`, `:598`).

  * **Rohre und Licht**  (`Schema.tsx:65-91`, `components/anlage/schema.ts:62-81`)
    Drei Schichten je Rohr: Grundschicht `strokeWidth = rohrStaerke` (an: `min(14, 6+|kW|*0,9)`,
    aus: 4; Rückläufe × 0,6) mit `strokeOpacity` an 0,16 / leise 0,12 / aus 0,06; Faden
    `strokeWidth` an 1,6 / leise 1,2 / aus 1, `strokeOpacity` an 0,5 / leise 0,35 / aus 0,12;
    darauf Lichtpunkte.
    Punkte: Anzahl `partikelZahl = clamp(2…7, round(|kW|*0,8)+2)` minus 1 bei leise, bei
    gemischtem Strom genau 6 (die Farbfolge). Halbmesser **wechselnd**:
    `(farben ? 3 : i%2 ? 2,2 : 3,2) * (leise ? 0,8 : 1)`, Deckung
    `(farben ? 0,92 : i%2 ? 0,55 : 0,95) * (leise ? 0,7 : 1)`, jeder Punkt mit
    `filter="url(#anlage-weich)"` (Gauß 2,2) (`Schema.tsx:72-88`, `:196-198`).
    Umlaufzeit `rohrDauer = round2(clamp(2,4…9, 16/|kW|) * (leise ? 1,3 : 1))`.
    **Bei `prefers-reduced-motion: reduce` werden gar keine Punkte gezeichnet**
    (`Schema.tsx:74`, `Anlage.tsx:20-22`, `:43`).
    Tempo-Leistungen wo nichts gemessen wird: WP `thermal_kw ?? 5`, Ofen `water_kw ?? 5`,
    Heizkreis fest 4, Warmwasser fest 1,5 (`Schema.tsx:164-167`).

  * **Strom links**  (`Schema.tsx:207-300`)
    Überschrift „Strom" bei x 60 / y 54, „Wärme" bei x 420 / y 54 (`:207-212`).
    Sonnenschein: Kreis r 90 bei (120,150), Deckung `0,08 + min(0,9, pv_kw*0,14)` (`:215`).
    Drei Kreise r 40 bei (120,150), (120,300), (120,450), Füllung `#0a2735`, Rand 1,2 in
    `FARBE.pv/#f2a900`, `FARBE.netz/#7fa3b3`, `FARBE.speicher/#9fd0df` mit Deckung .75.
    Namen **wörtlich „PV", „Netz", „Speicher"** (14 px, mittig, y −4 zur Mitte), darunter die
    Zahl `de(kW)` mit Einheit „ kW" (14 px, Einheit 12 px). `de()` gibt bei fehlendem Wert
    **„-"**, und dann entfällt die Einheit (`schema.ts:55-56`, `Schema.tsx:143-147`).
    Hinweise 42 px unter der Mitte: Netz `netzWort` („ruht"/„Einspeisung"/„Bezug"),
    Speicher `batterieWort` plus „· {soc} %" (`:263-277`).
    Knoten (300,300): weißer Hof r 14 bei .12 mit Weichzeichner, Kern r 5 bei .9, dazu rechts
    ausgerichteter Hinweis bei (286,292) **„zusammen {de(house_kw)} kW"** (`:281-287`).
    Haushalt: Kreis r 38 bei (330,470), Rand `FARBE.ev/#5c8fa3` .6, Name „Haushalt" 12,5 px,
    Zahl `de(rest_kw)` 13 px, Hinweis **„inkl. Wallbox"** bei y 522 (`:289-300`).
    Gemischter Strom: die Rohre `wp` und `ev` tragen `farben` aus `mischung()` - sechs Punkte,
    vergeben nach größtem Rückstand, damit die Farben verschränkt liegen (`schema.ts:85-121`).
    DATEN: `strom.pv_kw`, `grid_kw`, `battery_kw`, `battery_soc`, `house_kw`, `heat_pump_kw`,
    `rest_kw`, `share_*`.

  * **Pelletofen oben**  (`Schema.tsx:303-316`)
    `Kachel` x 420 / y 100 / 260 × 90 / Radius 24, gedimmt (0,7) wenn `!running`.
    Name „Pelletofen" (446,130), `.anlage-sub` `ofenStatus(o)` (446,148) - drei Zustände:
    „nicht angebunden" / „keine Verbindung" / „aus" / „Stufe N" bzw. „brennt", dazu
    „· Pumpe N %" (`schema.ts:174-180`).
    Zahl rechts unten (656,166), Größe 32, Einheit 13: `≈{de(water_kw)} kW`, sonst „-".
    Hinweis darunter (656,182) rechts: **„geschätzt aus der Stufe"**, und leer, wenn der Ofen
    nicht läuft oder keine Wasserleistung meldet.
    DATEN: `ofen.present`, `running`, `power_level`, `water_kw`, `flow_c`, `return_c`, `pump_pct`.

  * **Wärmepumpe, die Bühne**  (`Schema.tsx:319-346`)
    `Kachel` x 420 / y 268 / 260 × 128 / Radius 26, gedimmt wenn `!running`.
    Name „Wärmepumpe" (446,298); `.anlage-sub` „läuft seit {dauerText}" / „läuft" / **„steht"**
    (446,316).
    Links unten Zahl `de(power_kw)` **Größe 30** bei (446,364), darunter Hinweis „Strom hinein".
    Rechts unten Zahl **Größe 44**, Einheit 13, bei (656,364): `de(thermal_kw)`, „-" wenn die WP
    läuft und nichts meldet, **„0,0" wenn sie steht**; Hinweis (656,388) rechts:
    „Wärme nicht gemessen" bzw. „Wärme heraus".
    COP-Ring bei (648,298): r 17, Strich 3, Spur `rgba(255,255,255,.12)`, Bogen `FARBE.hp`
    (#e0966b) mit `strokeDasharray 106.8` und Offset `106,8*(1−min(1, cop/5))`, Deckung 0,15 ohne
    Wert; in der Mitte `de(cop)` 13 px Gewicht 400, links davon „COP" 10 px bei x −26.
    DATEN: `waermepumpe.running`, `running_since`, `power_kw`, `thermal_kw`, `flow_c`, `cop`.

  * **Speicher als Glas**  (`Schema.tsx:349-370`, `components/puffer/Glas.tsx:33-91`)
    Schatten-Ellipse (860,582) rx 46 ry 9, `#000` .35, Weichzeichner 14.
    Darunter mittig bei (860,614) `.anlage-num` **Größe 24**: `{soc} %`, daneben mit `dx=10` in
    `.anlage-unit` der `nettoText(p)` („lädt 1,2 kW" / „entlädt 0,8 kW" / „hält") in
    `nettoFarbe(p)`: `FARBE.pvSoft`/#ffd778 beim Laden, `FARBE.speicher`/#9fd0df beim Entladen,
    sonst **`rgba(255,255,255,.62)`** (`schema.ts:142-150`).
    Darunter `.anlage-hint` (860,632) wörtlich: `{Math.round(usable_kwh)} kWh nutzbar · {Math.round(volume_liters)} l`
    - der Teil vor dem Mittelpunkt entfällt ohne `usable_kwh` (`Schema.tsx:363-366`).
    Das Glas: `x 824, y 92, breite 72, hoehe 470`, `werte="rechts"`, `schrift=13`,
    `randKlasse="anlage-glasrand"`. Es besteht aus: Farbverlauf der vier Fühler auf ihren Höhen
    0,125/0,375/0,625/0,875 (`puffer/glas.ts:21`, `:30-33`) - **und nur wenn alle vier Fühler da
    sind**, sonst ein einziger Stop `#1c3d4f` (`glas.ts:26`, `Glas.tsx:44`); Glanz von links
    (`#fff .22` → `.05` bei 18 % → 0 bei 55 % → `#000 .18`); ein wandernder Lichtschein, Rechteck
    30 % der Höhe, oben und unten weich auslaufend, 14 s hin und her, bei `ruhig` weg
    (`Glas.tsx:52-69`); **zwei Ränder** - außen `rgba(255,255,255,.28)` 1,2 px mit Radius
    `breite/2`, innen um 2 eingerückt `rgba(255,255,255,.08)` 1 px (`Glas.tsx:72-73`); je Fühler
    ein Strich von Kante +4 bis +14 in `rgba(255,255,255,.3)` und die ganze Gradzahl ab Kante +20
    in `var(--font-mono)`, 13 px, mit kleinem „°" in `var(--text-3)` (`Glas.tsx:76-88`).
    Die Rohre treffen das Glas **an seiner Kante x 896** (`ww`, `hz`, `hzrl`, `kw` in
    `Schema.tsx:240-244`) bzw. an der Mittelachse x 860 oben/unten (`ofvl`, `rl`), der
    WP-Vorlauf endet **an der linken Kante x 824** (`Schema.tsx:238`).
    DATEN: `speicher.temps_c` (4), `soc`, `usable_kwh`, `volume_liters`, `net_kw`, `net_word`,
    `return_c`.

  * **Abnehmer rechts**  (`Schema.tsx:373-398`)
    Warmwasser: `Kachel` 980/140/200 × 80/Radius 22, gedimmt wenn `!present`; Name (1004,172),
    Zahl rechts (1156,176) Größe 22 `{Math.round(outlet_c)} °`, `.anlage-sub` (1004,200)
    `warmwasserStatus` - „kein Fühler am Auslass" / „Zapfung seit … · Auslass" /
    „ruht · Auslass kühlt ab" (`schema.ts:183-190`).
    Heizung: `Kachel` 980/300/200 × 80/Radius 22, gedimmt wenn `!running`; Zahl
    `{rooms_open}` mit Einheit „ von {rooms_total}", sonst „-"; `.anlage-sub` `heizungStatus` -
    „keine Räume gemeldet" / „Räume nehmen Wärme" / „kein Raum nimmt Wärme".
    Kaltwasser ohne Kasten, nur `.anlage-hint` bei (992,567):
    `Kaltwasser{ ` `}{grad(inlet_c)}{ läuft nach}` (`Schema.tsx:396-398`).
    DATEN: `warmwasser.*`, `heizkreis.rooms_open`, `rooms_total`, `running`.

  * **Pumpen und Stutzen**  (`Schema.tsx:401-417`, `:94-107`)
    Drei Pumpen bei (748,282) WP, (745,116) Ofen, (938,330) Heizkreis: Hof r 13 weiß .16 (nur
    laufend), Ring r 8 `#0a2735` mit weißem Strich 1,2 (.7 laufend / .25 aus), Kern r 3 in
    `FARBE.pvSoft` bzw. `rgba(255,255,255,.35)`, ganze Gruppe 0,55 wenn aus; Wort 16 px darüber,
    mittig: „Pumpe" / „{pump_pct} %" / „läuft".
    Vier Stutzenschriften: Ofenvorlauf (800,52) rechts, WP-Vorlauf (770,252) rechts - **„Vorlauf
    ?" wenn die WP läuft und keinen Vorlauf meldet** -, gemeinsamer Rücklauf (774,582) rechts
    „zurück {grad}", Heizkreisrücklauf (1000,488) links „zurück {grad}".

  * **Anklickbare Geräte**  (`Schema.tsx:112-125`, `schema.ts:200-210`, `globals.css:583-590`)
    Jedes Symbol ist ein echtes `<a href>` mit `aria-label="{label}. Details öffnen"`; der
    Linksklick geht über den Router. Ziele **mit Sprungmarke**: `/strom/pv`, `/strom`,
    `/strom/speicher`, `/strom`, **`/waerme#puffer`**, **`/waerme#ofen`**, **`/waerme#puffer`**,
    **`/haus?ansicht=liste`**, `/waerme`. Dazu `globals.css:590`: `.card { scroll-margin-top: 84px }`
    mit der Begründung „Sprungmarken der Erzeugerseite landen nicht unter der Kopfzeile."
    Beim Zeigen und bei Tastaturfokus heben sich Glasfläche (`fill .08`, `stroke .34`), Ring
    (`stroke-opacity 1`, Breite 2) oder Glasrand (`stroke .6`, Breite 2), Übergang .2 s; der
    Fokus färbt sie `var(--amber-soft)`.

  * **Der Fuß: drei Spalten Lesehilfe**  (`Anlage.tsx:91-124`, `globals.css:591-595`)
    `.anlage-fuss`: Gitter `repeat(auto-fit, minmax(260px, 1fr))`, Abstand `12px 28px`, Polster
    `4px 8px 0`. `h2` 12 px/500, `.1em` gesperrt, Großbuchstaben, `var(--text-3)`; `p` 13,5 px,
    Gewicht 300, Zeilenhöhe 1,5, `var(--text-2)`; `.m` hebt Begriffe auf `var(--text-1)`/400.
    Überschriften wörtlich „Lesen", „Vier getrennte Systeme", „Gemessen und gerechnet".
    Die Texte stehen wörtlich in `Anlage.tsx:95-99`, `:103-110`, `:114-122`. Drei Aussagen, die
    die App-Fassung nicht hat: „Jedes Gerät lässt sich antippen; dahinter liegt seine Seite,
    dieselbe wie von der Startseite aus."; „Sie berühren sich nur im Speicher."; das Trinkwasser
    „hat keine Pumpe, der Leitungsdruck treibt es."

  * **Handy-Fassung**  (`apps/web/src/styles/handy.css:107`, `:395-401`)
    Im Block `@media (max-width: 720px)`, mit Begründung im Kommentar (`:393-395`): „Das Schema
    ist eine Zeichnung im Querformat und rollt zur Seite. Der Hinweis sagt es, statt dass die
    rechte Hälfte unbemerkt fehlt."
    - `.anlage-buehne { border-radius: 20px; box-shadow: none; }` (`:398`)
    - `.anlage-innen { border-radius: 19px; }` (`:399`)
    - `.anlage-buehne::after` (`:400`): eine eigene Zeile **unter** der Bühne, Inhalt wörtlich
      `zur Seite wischen: Strom, Erzeuger, Speicher, Verbraucher  ›` (zwei Leerzeichen vor dem
      Pfeil), `display: block`, Polster `9px 12px 11px`, mittig, 12,5 px, `var(--text-3)`.
    - `.anlage-fuss { grid-template-columns: minmax(0, 1fr); padding: 0; }` (`:401`) - eine
      Spalte, kein Polster.
    Nicht überschrieben und daher auch am Telefon gültig: `min-width: 940px` der Zeichnung
    (`globals.css:567`) - die Bühne ist dort 940 × 501 und rollt; Kopfzeile, Satzgrößen und der
    Lichtbetrieb bleiben wie breit. Der Bereichskicker ist am Telefon weg (`AreaNav.tsx:96`).
    Gesucht nach weiteren `.anlage`-Regeln in `handy.css`: nur diese vier Zeilen.
    Gesucht nach `anlage` in `tokens.css`: kein Treffer - die Bühne nennt ihre Farben als Werte,
    begründet in `schema.ts:10-11` („SVG-Verläufe nehmen keine `var()`").

LUECKEN:

  [traegt-die-seite]
  Das Pufferglas sitzt falsch und die vier Kreise treffen es nicht mehr. Die Vorlage zeichnet
  den Tank 72 Punkte breit von x 824 bis x 896 (`Schema.tsx:368`). Die App ruft `Pufferglas`
  **ohne `breite`**, nimmt also die Voreinstellung 60 (`Pufferspeicher.swift:29`), und legt es in
  einen Rahmen von 150 Punkten (`Anlagenbild.swift:459-460`). Im `HStack` ist das Kind
  `breite + randbreite` = 60 + (20 + 12,5·2,6) = 113 Punkte breit (`Pufferspeicher.swift:43`,
  `:57`), zentriert im 150er Rahmen also um 18,5 nach rechts verschoben: der Tank steht bei
  842,5 … 902,5. Folge im Bild: der **Wärmepumpenvorlauf endet bei x 824 im Leeren**, 18 Punkte
  vor dem Glas (`Anlagenrohre.swift:101`); Warmwasser, Heizung, Heizkreisrücklauf und Kaltwasser
  enden 6,5 Punkte **innerhalb** des Tanks statt an seiner Kante (`:103-109`); und die vier
  Fühlerzahlen stehen bei ≈ 934 statt bei 916. Damit sagt die Bühne nicht mehr, was sie sagen
  soll - dass sich die vier getrennten Systeme genau hier berühren.

  [spuerbar]
  Die Bühne selbst fehlt. `.anlage-buehne`/`.anlage-innen` (Radius 28/27, 1 px Verlaufsrand,
  tiefes Petrol `rgba(10,39,53,.85)` → `rgba(5,22,31,.9)`, Schatten `0 40px 120px rgba(0,0,0,.45)`;
  `globals.css:564-565`) sind durch eine gewöhnliche `Karte` mit Kicker „Die Anlage" ersetzt
  (`AnlageSeite.swift:29`). Die Zeichnung steht damit auf `Farbe.flaeche1`/`flaeche2` statt auf
  dem dunklen Grund, für den ihre Deckungen und Leuchten gerechnet sind.

  [spuerbar]
  Die Kopfzeile der Vorlage gibt es nicht. Es fehlen: der Satz als Satz (fett `erzeugerSatz`
  zwischen Außentemperatur und Mischung, `Anlage.tsx:63-73`), die **Außentemperatur ganzzahlig**
  (App: eine Nachkommastelle, `AnlageSeite.swift:101`), vor allem aber **„Strom aus PV 72 %,
  Netz 28 %"** - `Anlagenschema.mischung(…).text` wird auf der ganzen Seite nirgends benutzt
  (gesucht nach `mischung` in `AnlageSeite.swift`: kein Treffer; in `Anlagenbild.swift` nur für
  die Punktfarben, `:78`, `:140`) - und der Zusatz **„· alle 20 s"** am Stand.

  [spuerbar]
  Die Bühne setzt überall IBM Plex statt der Systemschrift. `Anlagenbild` schreibt
  `.custom("IBMPlexSans"/"IBMPlexMono")` an 20 Stellen (z. B. `:308-311`, `:354-356`, `:569`,
  `:614`), die Vorlage schaltet die SVG-Fläche ausdrücklich auf `-apple-system`/SF Pro, **weil
  IBM Plex die Gewichte 200 und 300 nicht hat** (`globals.css:566-568`). Damit sind alle Zahlen
  (`.anlage-num` 200) und alle Hinweise (`.anlage-hint` 300) in der App schwerer als gemeint,
  und `letter-spacing -.03em` der Zahlen fehlt ganz.

  [spuerbar]
  Fehlende Werte werden als „0,0" behauptet. `quelle(…)` rechnet
  `Formate.zahl(abs(wert ?? 0), stellen: 1)` (`Anlagenbild.swift:309`), ebenso der Knoten
  (`:339`) und der Stromwert der Wärmepumpe (`:388`). Die Vorlage schreibt dort `de()`, das ohne
  Wert **„-"** liefert und dann auch die Einheit weglässt (`schema.ts:55-56`,
  `Schema.tsx:143-147`). Ein schweigender Zähler sieht in der App wie eine gemessene Null aus.

  [spuerbar]
  „Bewegung reduzieren" wird nicht beachtet. Die Vorlage zeichnet dann **keine** Lichtpunkte
  (`Schema.tsx:74`) und schaltet den Lichtschein im Glas ab (`Glas.tsx:65`). Die App liest die
  Einstellung (`Anlagenbild.swift:26`), senkt damit aber nur den Takt auf 1 Bild/s
  (`:115`) - die Punkte wandern weiter.

  [spuerbar]
  Rohre und Lichtpunkte sind zu stark. Grundschicht `an ? 0.3 : 0.14` und Faden `an ? 0.9 : 0.3`
  bei Breite 1,8/1,2 (`Anlagenbild.swift:202-207`) gegen 0,16/0,12/0,06 und 0,5/0,35/0,12 bei
  1,6/1,2/1 in der Vorlage (`Schema.tsx:72-73`). Die Punkte haben in der App einen festen
  Halbmesser (3,4 bzw. 2,6) und volle Deckung (`Anlagenbild.swift:212-223`); die Vorlage wechselt
  Größe (3,2/2,2) und Deckung (0,95/0,55) von Punkt zu Punkt, dämpft Rückläufe auf 0,8 bzw. 0,7
  und legt auf **jeden** Punkt einen Weichzeichner (`Schema.tsx:78-81`).

  [spuerbar]
  Der Handy-Hinweis unter der Bühne fehlt. Gesucht nach „wischen" und „zur Seite" in
  `apps/ios/DuckCurveHome` und `DuckCurveKit/Sources`: kein Treffer. Die Vorlage setzt dort eine
  eigene Zeile „zur Seite wischen: Strom, Erzeuger, Speicher, Verbraucher  ›" (`handy.css:400`),
  damit die rechte Hälfte nicht unbemerkt fehlt. Die App rollt mit Indikator
  (`Anlagenbild.swift:37`), sagt es aber nicht.

  [spuerbar]
  Die Kacheln sind keine Glaskacheln. Die App füllt sie mit `Farbe.flaeche2.opacity(0.92)`
  (#123544, `Anlagenbild.swift:543`, `Marken.swift:29`); die Vorlage nimmt
  `rgba(255,255,255,.045)` über dem Bühnengrund (`globals.css:576`). Die Haarlinie läuft in der
  App als Verlauf über die ganze Höhe (`:547-553`), in der Vorlage ist sie bei 25 % auf `.06`
  abgefallen (`Schema.tsx:177-181`).

  [spuerbar]
  Dem Glas fehlen der innere Rand und der wandernde Lichtschein. `Pufferglas` zeichnet Verlauf,
  Glanz und **einen** Rand (`Pufferspeicher.swift:61-93`); die Vorlage hat zusätzlich den um 2
  eingerückten zweiten Rand `rgba(255,255,255,.08)` 1 px und den 14-Sekunden-Schein, der oben und
  unten weich ausläuft (`Glas.tsx:52-73`). Gesucht nach „Lichtschein"/`animation` in
  `Pufferspeicher.swift`: kein Treffer.

  [spuerbar]
  Das Glas zeichnet einen Verlauf aus unvollständigen Fühlern. `verlauf` fällt erst zurück, wenn
  **alle** vier fehlen (`Pufferspeicher.swift:131`). Die Vorlage verlangt alle vier
  (`glas.ts:26`, `:31`) und zeigt sonst ein einfarbiges Glas (`Glas.tsx:44`), begründet in
  `Pufferspeicher.swift:127-128` genau so („ein Verlauf aus zwei Messungen und zwei Vermutungen
  wäre ein Bild, das mehr behauptet") - die Begründung steht in der App, die Prüfung nicht.

  [klein]
  Wörter weichen ab: „Sonne" statt **„PV"** (`Anlagenbild.swift:236` gegen `Schema.tsx:251`);
  „ohne Wärmepumpe" statt **„inkl. Wallbox"** (`:250` / `:297`); „{x,x} kW im Haus" statt
  **„zusammen {x,x} kW"** und bei (230,286) statt rechtsbündig bei (286,292) (`:339-343` /
  `:284-286`); „ins Wasser" statt **„geschätzt aus der Stufe"**, und in der App steht es auch,
  wenn der Ofen nichts meldet (`:366` / `:312-314`).

  [klein]
  Die Unterzeile am Glas sagt etwas anderes: „{usable} von {capacity} kWh · {N} l"
  (`Anlagenbild.swift:470-474`) gegen **„{round(usable)} kWh nutzbar · {round(volume)} l"**, und
  in der Vorlage entfällt der erste Teil, wenn `usable_kwh` fehlt (`Schema.tsx:363-366`).
  `capacity_kwh` steht dort nicht.

  [klein]
  Die Lesehilfe ist eine andere. Sie steht in drei Karten statt in einem dreispaltigen Fuß
  (`AnlageSeite.swift:49-85`), ihre Sätze sind **ohne Umlaute und ß** geschrieben
  („Fliessrichtung", „duenn", „Ruecklaeufe", „Waermepumpe", „laeuft", „zurueck", „Waerme",
  „Fuehlern", „geschaetzt" - `:54-82`), die Hervorhebung der Begriffe (`.anlage-fuss .m`,
  `globals.css:595`) fehlt, und drei Aussagen der Vorlage fehlen ganz: dass jedes Gerät antippbar
  ist, dass sich die vier Systeme „nur im Speicher" berühren, und dass das Trinkwasser keine
  Pumpe hat, sondern der Leitungsdruck es treibt (`Anlage.tsx:97-99`, `:104`, `:107-108`).

  [klein]
  Die Ziele haben keine Sprungmarken: `/waerme` für Wärmepumpe, Ofen und Puffer und `/haus` für
  die Heizung (`Anlagenschema.swift:231-243`) gegen `/waerme#puffer`, `/waerme#ofen`,
  `/waerme#puffer` und `/haus?ansicht=liste` (`schema.ts:200-210`). Wer in der App auf den Ofen
  tippt, landet oben auf der Wärmeseite statt auf seiner Karte.

  [klein]
  Zahlengrößen und Einheiten weichen ab: WP-Strom 26 statt 30, WP-Wärme 38 statt 44
  (`Anlagenbild.swift:389`, `:400` gegen `Schema.tsx:327`, `:331`), Ofen 30 statt 32 (`:365` /
  `:311`); die Einheit rechnet `max(11, groesse*0,42)` (`:573`), also 16 Punkte am großen Wert,
  wo die Vorlage 13 setzt (`Schema.tsx:331`).

  [klein]
  Der Takt ist 10 s statt 20 s und läuft ohne Sichtbarkeitsprüfung
  (`AnlageSeite.swift:265-271`). Die Vorlage begründet die 20 s ausdrücklich mit dem Minutentakt
  der Pufferfühler (`Anlage.tsx:14-16`) und holt zusätzlich bei `visibilitychange` nach
  (`:48-52`).

  [klein]
  Die Bühne ist kleiner als am Telefon der Vorlage: 430 Punkte Höhe, also 806 × 430
  (`Anlagenbild.swift:29-33`), gegen `min-width: 940px` und damit 940 × 501
  (`globals.css:567`, nicht in `handy.css` überschrieben).

  [klein]
  Der Leerzustand ist eine Karte mit „Wird geholt …" (`AnlageSeite.swift:40`) statt
  `.anlage-warten`: 420 Punkte hoch, Radius 28, Rand `var(--line-1)`, mittig,
  „Die Anlage wird geholt." (`globals.css:597`, `Anlage.tsx:88`).

  [klein]
  Der Hof des WP-Vorlaufs ist mitlaufend statt fest: `staerke + 7` in `Farbe.grund` (#082431)
  bei 0,85 (`Anlagenbild.swift:197-200`) gegen feste **Breite 20** in `#071d28` bei 0,9
  (`globals.css:579`).

  [klein]
  Kein Rückmelden beim Berühren. Die Vorlage hebt beim Zeigen und bei Tastaturfokus Glasfläche,
  Ring oder Glasrand und färbt den Fokus `var(--amber-soft)` (`globals.css:583-588`); in der App
  gibt es nur `onTapGesture` ohne sichtbare Antwort (`Anlagenbild.swift:326`, `:560`).

  [klein]
  Die beiden Überschriften der Bühne haben die falsche Farbe: `Farbe.kicker` = `mist` (#7FA3B3,
  `Marken.swift:46`) gegen `.anlage-cap { fill: var(--text-3) }` = `rgba(255,255,255,.48)`
  (`globals.css:569`). Dazu setzt `.position` die Mitte, die Vorlage den Textanfang bei x 60 bzw.
  420 (`Anlagenbild.swift:231-232` gegen `Schema.tsx:207-212`).

  [klein]
  Der Bereichskicker „Strom · Speicher · vier Kreise" fehlt (gesucht nach „vier Kreise" in
  `apps/ios`: nur Kommentare und die Hauskonsole, kein Oberflächentext). **Nur für die breite
  Ansicht relevant**: am Telefon blendet die Vorlage ihn aus (`AreaNav.tsx:96`). `Seite` hat
  heute keine Stelle dafür (`App/Seitenwahl.swift:141-170`).

KERN: SCHON DA (nachgesehen, nicht geraten)

  * Abfrage: `Api.anlage() -> AnlageOut` auf `/anlage`
    (`DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:258`); die Wiedergabe derselben Bilder
    liegt daneben (`:263`).
  * Modelle, vollständig und mit allen Feldern der Vorlage:
    `AnlageOut` (`Modelle/Schema.swift:1290`: `at`, `outdoorC`, `strom`, `waermepumpe`, `ofen`,
    `speicher`, `heizkreis`, `warmwasser`), `AnlageStromOut` (`:1461`: `pvKw`, `gridKw`,
    `batteryKw`, `batterySoc`, `houseKw`, `heatPumpKw`, `restKw`, `sharePv`, `shareGrid`,
    `shareBattery`), `AnlageSpeicherOut` (`:1410`: `tempsC`, `soc`, `usableKwh`, `capacityKwh`,
    `volumeLiters`, `netKw`, `netWord`, `returnC`), `AnlageWaermepumpeOut` (`:1516`: `running`,
    `runningSince`, `powerKw`, `thermalKw`, `flowC`, `cop`), `AnlageOfenOut` (`:1244`: `present`,
    `running`, `powerLevel`, `flowC`, `returnC`, `pumpPct`, `waterKw`), `AnlageHeizkreisOut`
    (`:1213`: `roomsTotal`, `roomsOpen`, `openShare`, `running`), `AnlageWarmwasserOut` (`:1558`:
    `present`, `outletC`, `inletC`, `tapping`, `tappingSince`).
  * Rechnungen: `Zustand/Anlagenschema.swift` - `Farbwerte` (`:21-30`), `farbe` (`:43`),
    `anKw`/`istAn` (`:69`, `:71`), `rohrDauer` (`:79`), `punktzahl` (`:85`), `rohrStaerke`
    (`:90`), `Mischung`/`mischung` (`:96`, `:109`), `dauerText` (`:146`), `netzWort` (`:155`),
    `batterieWort` (`:161`), `nettoText` (`:168`), `ofenStatus` (`:179`), `warmwasserStatus`
    (`:189`), `heizungStatus` (`:197`), `erzeugerSatz` (`:203`), `kopfzeile` (`:214`),
    `Ziel` mit `weg`/`wort`/`ansage` (`:228-261`). Geprüft in
    `DuckCurveKit/Tests/DuckCurveKitTests/AnlagenschemaTests.swift`.
  * Geometrie: `Anlagenrohre.buehne` 1200 × 640 (`DuckCurveHome/Diagramme/Anlagenrohre.swift:17`),
    alle 14 Pfade **zeichengleich zur Vorlage** (`:70-110`), 96 Stützstellen je Rohr und
    `punkt(bei:)` (`:25-30`, `:113-119`).
  * Marken und Maße: `grund` (`Gestalt/Marken.swift:27`), `flaeche1/2/3` (`:28-30`),
    `last` = weiß mit Deckung 0,62 (`:93`) - genau die Vorgabefarbe von `nettoFarbe` -,
    `achtung`/`alarm` (`:98`, `:99`), `wasserfarbe` (`:185`), `radius3` (`:313`),
    `textKicker` (`:46`).
  * Formate: `leer` = „-" (`Formate/Formate.swift:27`), `zahl` (`:44`), `kw` (`:62`),
    `prozent` (`:98`), `celsius` (`:104`), `hhmm(iso:)` (`:148`).
  * Fühler als Messwerte: `Messwert.ausZahlen` (`Modelle/Messwerte.swift:16`),
    `Pufferzustand` (`Zustand/Puffer.swift:13`).
  * Oberfläche: `Pufferglas` mit Verlauf, Glanz, Rand und Fühlerzahlen
    (`DuckCurveHome/Bausteine/Pufferspeicher.swift:23-152`), `Karte` (`Gestalt/Karte.swift:15`),
    `Zeile` (`:360`), `Leer` (`:390`), `Stoerung` (`:410`), `Seite` (`App/Seitenwahl.swift:141`),
    und das ganze `Anlagenbild` (`Diagramme/Anlagenbild.swift:21-638`).

ES FEHLT:

  1. `Anlagenschema.nettoFarbe(_ sp: AnlageSpeicherOut) -> Farbwert` -
     `Zustand/Anlagenschema.swift`, neben `nettoText` (`:168`). Lädt → `Marken.amberWeich`,
     entlädt → `Farbwerte.speicher`, sonst **`Marken.last`** (`Marken.swift:93`), nicht `text3`.
     Heute steht die Abbildung privat in der Ansicht und mit falscher Vorgabe
     (`Anlagenbild.swift:485-491`), während `schema.ts:147-150` sie zur Rechnung zählt.
  2. `Anlagenschema.pufferStufen(_ temps: [Double?]) -> [(bei: Double, farbe: Farbwert)]` -
     `Zustand/Anlagenschema.swift`. Gibt **leer** zurück, solange nicht alle vier Fühler da sind
     (`puffer/glas.ts:26`, `:30-33`); `Pufferglas.verlauf` ruft sie und malt bei leerer Antwort
     einfarbig. Damit steht die Regel geprüft im Kern statt als Kommentar in der Ansicht.
  3. `Anlagenschema.Ziel.weg` um Sprungmarken erweitern - `Zustand/Anlagenschema.swift:231-243`:
     `waermepumpe`/`puffer` → `/waerme#puffer`, `ofen` → `/waerme#ofen`,
     `heizung` → `/haus?ansicht=liste` (`schema.ts:200-210`). Dazu prüfen, ob `Wegweiser` und
     `Bereiche` eine Marke hinter `#` und `?ansicht=` schon tragen; `Seitenwahl` schneidet den
     Fragezeichenteil ab (`App/Seitenwahl.swift:105-109`), eine Raute heute nicht.
  4. `Anlagenschema.Kopfteile` (oder drei Rückgaben) -
     `Zustand/Anlagenschema.swift`, neben `kopfzeile` (`:214`): `draussen: String?` (ganzzahlig),
     `satz: String`, `mischung: String?`, damit die Ansicht den Mittelteil fett setzen kann.
     `kopfzeile` fügt heute alles zu einer Zeichenkette zusammen und gibt die Fuge nicht her.
  5. `Marken.buehneVerlauf` und `Marken.buehneRand` - `Gestalt/Marken.swift`, bei
     `grundVerlauf` (`:37-39`): `rgba(10,39,53,.85)` → `rgba(5,22,31,.9)` für die Fläche und
     `rgba(255,255,255,.14)` → `.03` bei 30 % → `.02` für den 1-Punkt-Rahmen
     (`globals.css:564-565`). Gesucht nach `buehne`/`0x0A2735` in `Marken.swift` und
     `Gestalt/Farben.swift`: kein Treffer.

BAUPLAN:

  1. **`apps/ios/DuckCurveHome/Gestalt/Bühne.swift` (neu): `Anlagenbuehne<Inhalt>`.**
     Radius 28 außen / 27 innen am iPad, 20 / 19 am Telefon (`handy.css:398-399`), 1 Punkt
     Verlaufsrand und Flächenverlauf aus den neuen Marken, Schatten `0 40px 120px` schwarz 0,45
     nur breit (`box-shadow: none` am Telefon), `clipShape`. Darunter, nur bei
     `horizontalSizeClass == .compact`, die Hinweiszeile „zur Seite wischen: Strom, Erzeuger,
     Speicher, Verbraucher  ›" mit Polster `9/12/11`, mittig, 12,5 Punkte, `Farbe.text3`
     (`handy.css:400`). Vorbild für die Fassungen nach Breite: `Gestalt/Karte.swift:85-103`.
     Die Wiedergabeseite leiht sich in der Vorlage dieselbe Fassung (`globals.css:606-609`), also
     eigener Baustein und nicht in `AnlageSeite` eingebaut.
  2. **`DuckCurveKit/Sources/DuckCurveKit/Zustand/Anlagenschema.swift`:** die fünf Punkte aus
     „ES FEHLT" (1.-4.) ergänzen, Tests in
     `DuckCurveKit/Tests/DuckCurveKitTests/AnlagenschemaTests.swift` nachziehen; `Marken.swift`
     um die Bühnenfarben (5.).
  3. **`DuckCurveHome/Seiten/Technik/AnlageSeite.swift`, Kopf (`:95-105`):** ersetzen durch die
     Vorlagenzeile - `HStack(alignment: .firstTextBaseline)`, links der Satz aus den neuen
     Kopfteilen (15 Punkte, `Farbe.text2`, der Mittelteil `Schrift.karte`-Gewicht in
     `Farbe.text1`), rechts „Stand hh:mm · alle 20 s" (12 Punkte, `Farbe.text3`, `lineLimit(1)`).
     Außentemperatur ganzzahlig (`Formate.celsius(aussen)` ohne `stellen:`).
  4. **Dieselbe Datei, Bild (`:29-31`):** `Karte(kicker:titel:)` durch `Anlagenbuehne` ersetzen;
     Kicker und Titel entfallen, der Satz steht jetzt oben. Für die breite Ansicht den
     Bereichskicker „Strom · Speicher · vier Kreise" vorsehen (am Telefon weglassen,
     `AreaNav.tsx:96`) - entweder als `Seite(kicker:)` in `App/Seitenwahl.swift:141` oder als
     Zeile über der Bühne.
  5. **Dieselbe Datei, Leerzustand (`:40`):** `Leer` durch einen Kasten von 420 Punkten
     Mindesthöhe mit Rand `Farbe.linie1`, Radius 28 und mittigem „Die Anlage wird geholt."
     ersetzen (`globals.css:597`); bei Fehler leer bleiben.
  6. **Dieselbe Datei, Lesehilfe (`:49-85`):** Texte wörtlich aus `Anlage.tsx:95-122`
     übernehmen - **mit** Umlauten und ß -, die drei fehlenden Aussagen aufnehmen und die
     hervorgehobenen Begriffe als `Farbe.text1` setzen (AttributedString oder `Text`-Verkettung).
     Am iPad drei Spalten (`repeat(auto-fit, minmax(260px, 1fr))`, Abstand `12/28`), am Telefon
     eine (`handy.css:401`): `ViewThatFits` oder `horizontalSizeClass`. Überschriften als
     `Kicker` 12 Punkte in `Farbe.text3`, Text 13,5 Punkte in `Farbe.text2`.
  7. **Dieselbe Datei, Takt (`:265-271`):** 20 Sekunden statt 10, und bei `scenePhase == .active`
     einmal nachholen (Gegenstück zu `visibilitychange`, `Anlage.tsx:48-52`).
  8. **`DuckCurveHome/Diagramme/Anlagenbild.swift`, Glas (`:438-483`):** `breite: 72` übergeben,
     den 150er Rahmen durch `72 + randbreite` ersetzen und mit `alignment: .topLeading` auf
     x 824 / y 92 setzen, damit die Kante wieder bei 896 liegt; `zahlgroesse: 13`
     (`Schema.tsx:368`). Unterzeile auf „{round(usable)} kWh nutzbar · {round(volume)} l" ändern,
     den ersten Teil ohne `usableKwh` weglassen, `nettofarbe` durch `Anlagenschema.nettoFarbe`
     ersetzen.
  9. **`DuckCurveHome/Bausteine/Pufferspeicher.swift`:** zweiter Rand (um 2 eingerückt, weiß
     0,08, 1 Punkt) nach `:84`; wandernder Lichtschein als `TimelineView` über 14 Sekunden,
     Rechteck 30 % der Höhe mit weich auslaufendem Verlauf, bei
     `accessibilityReduceMotion` aus (`Glas.tsx:52-69`); `verlauf` auf `Anlagenschema.pufferStufen`
     umstellen (`:129-152`). Vorbild für eine Zeitachse ohne Zustand:
     `Anlagenbild.swift:115-122`.
  10. **`Anlagenbild.swift`, Schrift:** alle `.custom("IBMPlexSans"/"IBMPlexMono", size:)` in der
      Bühne auf die Systemschrift umstellen - `.system(size:, weight:)` mit 200 für Zahlen
      (`.anlage-num`), 300 für Hinweise und Unterzeilen, 500 für Namen und Überschriften -, dazu
      `.monospacedDigit()` für `tabular-nums` und `.kerning` für `-.03em` an den Zahlen
      (`globals.css:566-574`). Betroffen: `quelle` (`:308-311`), `knoten` (`:340`), die fünf
      Kacheln (`:354`, `:356`, `:366`, `:381`, `:383`, `:390`, `:402`, `:523`, `:527`),
      `copring` (`:426`, `:431`), `grosseZahl` (`:569`, `:573`), `pumpe` (`:597`),
      `hinweis` (`:614`), `Ueberschrift` (`:632`); dort auch `Farbe.kicker` → `Farbe.text3`.
  11. **`Anlagenbild.swift`, Zahlen und Worte:** „Sonne" → „PV" (`:236`), „ohne Wärmepumpe" →
      „inkl. Wallbox" (`:250`), Knotenhinweis → „zusammen {x,x} kW", rechtsbündig bei (286,292)
      (`:339-343`), Ofenhinweis → „geschätzt aus der Stufe" und leer, wenn nichts gemeldet ist
      (`:366`); `Formate.zahl(abs(… ?? 0))` → `Formate.kw(…)` mit „-" bei `nil` in `quelle`
      (`:309`), `knoten` (`:339`) und der WP (`:388`); Größen 30/44/32 und Einheit 13
      (`:365`, `:389`, `:400`, `:573`).
  12. **`Anlagenbild.swift`, Rohre (`:192-225`):** Deckungen und Breiten der Vorlage
      (0,16/0,12/0,06 und 0,5/0,35/0,12 bei 1,6/1,2/1), wechselnde Punktgröße und -deckung,
      Rückläufe × 0,8 bzw. × 0,7, ein Weichzeichner auf den Punkten (`Canvas`-Schicht mit
      `addFilter(.blur(radius: 2.2))` oder vorgezeichnetes Leuchten), Hof fest 20 Punkte in
      `#071d28` bei 0,9 (`:197-200`). Und: bei `ruhig` **keine** Punkte zeichnen und den
      `TimelineView` ganz weglassen (`:115`, `Schema.tsx:74`).
  13. **`Anlagenbild.swift`, Kacheln (`:535-564`):** Füllung `Color.white.opacity(0.045)`, Strich
      `Color.white.opacity(0.10)`, Haarlinie mit Stopp bei 25 % (0,28 / 0,06 / 0,02); beim Tippen
      sichtbar antworten (Glasfläche 0,08 / Strich 0,34, Ring 1,0 und Breite 2 - `globals.css:585-586`),
      Übergang 0,2 s.
  14. **`Anlagenschema.Ziel.weg`-Umbau nachziehen:** `Wegweiser`/`Bereiche` müssen Raute und
      `?ansicht=` vertragen, sonst führt das Tippen auf den Ofen in den `default`-Zweig
      (`App/Seitenwahl.swift:99-100`). Prüfen und, falls nötig, `sauber` um die Raute erweitern
      (`:105-109`).

WAS SCHWIERIG WIRD:

  * **Lichtpunkte mit Weichzeichner.** Im SVG hat jeder Punkt `filter="url(#anlage-weich)"`
    (`Schema.tsx:81`, `:196-198`). In `Canvas` kostet ein Filter je Punkt zu viel. Der im Projekt
    gewählte Weg ist, das Leuchten zu malen statt zu filtern - zwei Kreise übereinander, der
    äußere größer und blasser, wie bei der Pumpe (`Anlagenbild.swift:581-593`: Hof als eigener
    Kreis mit `blur(radius: 4)`) und im Energiefluss
    (`DuckCurveHome/Bausteine/Energiefluss.swift`, dort als Vorbild für wandernde Punkte auf
    Pfaden nachsehen). Alternativ `gestalt.addFilter(.blur(radius: 2.2))` einmal für eine eigene
    Punkteschicht setzen, nicht je Punkt.
  * **SMIL hat kein Gegenstück.** Die Vorlage animiert mit `animateMotion` entlang des Pfads und
    gibt jedem Punkt über `begin` einen Versatz (`Schema.tsx:83-85`). Das Projekt hat sich für
    `TimelineView(.animation)` plus vorgerechnete Stützstellen entschieden, und die Begründung
    steht im Kopf von `Anlagenrohre.swift:5-10` (96 Proben je Rohr, weil `trimmedPath` je Bild zu
    teuer ist). Dabei bleiben; der Schlüsseltrick der Vorlage (Schlüssel aus Dauer und Anzahl,
    damit die Punkte beim Abruf nicht neu anlaufen, `Schema.tsx:77`) entfällt damit von selbst.
  * **Der wandernde Lichtschein im Glas** ist in der Vorlage ein `<animate>` mit
    `calcMode="spline"` und zwei `keySplines` von `.4 0 .6 1` (`Glas.tsx:67`). In SwiftUI führt
    das über eine `TimelineView` und eine eigene Zeitfunktion, oder über eine
    `.animation(.timingCurve(0.4, 0, 0.6, 1).repeatForever(autoreverses: true))` auf einem
    Versatz. Vorbild für eine endlos laufende Zeichnung ohne Zustand:
    `Anlagenbild.swift:115-122`; Vorbild für `.repeatForever` im Projekt: in
    `DuckCurveHome/Bausteine/Ambiente.swift` nachsehen (nicht gemessen).
  * **Fette Teile in einem Satz.** `.anlage-satz b` ist ein Wechsel innerhalb einer Zeile
    (`globals.css:562`). In SwiftUI ist das ein `AttributedString` oder eine `Text`-Verkettung
    mit `+`; welcher Weg im Projekt schon gewählt wurde, steht in
    `DuckCurveHome/Gestalt/Umbruchzeile.swift` (nicht gemessen) - dort zuerst nachsehen, bevor
    ein neuer Weg erfunden wird.
  * **Dreispaltig am iPad, einspaltig am Telefon** für den Fuß: `Grid` bzw. `LazyVGrid` mit
    `.adaptive(minimum: 260)` kommt `repeat(auto-fit, minmax(260px, 1fr))` am nächsten; die
    Umschaltung nach `horizontalSizeClass` ist im Projekt der gewählte Weg
    (`Gestalt/Karte.swift:22-24`, `App/Seitenwahl.swift:145`).
  * **Die Sprungmarke `#ofen`.** Im Browser scrollt der Anker, mit `scroll-margin-top: 84px`
    gegen die Kopfzeile (`globals.css:589-590`). In SwiftUI braucht das `ScrollViewReader` und
    eine `id` auf der Zielkarte innerhalb von `Seite` (`App/Seitenwahl.swift:157-170`), also eine
    Änderung an der Hülle und an der Wärmeseite - der Punkt ist klein in der Wirkung und groß in
    der Reichweite. Wenn er nicht sofort gebaut wird: `Ziel.weg` trotzdem auf die Vorlagenpfade
    setzen und die Raute vorerst wegschneiden, nicht in den `default`-Zweig laufen lassen.
