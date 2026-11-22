========================= messen:haus   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift`)

Zwei Gerippe, entschieden in `HausSeite.swift:98`:

A. schmal ODER Ansicht == Liste  (`HausSeite.swift:99-111`, in `Seite { }`, also Rollbereich
   mit 16 Punkt Rand, `Seitenwahl.swift:136-168`):
   1. Kopf (`HausSeite.swift:258-280`): am Telefon „Stand HH:MM" rechtsbündig (Zeile 261-266),
      darunter der Umschalter Liste/Modell über die ganze Breite (Zeile 267, `Ansichtswahl`,
      `Ansichtswahl.swift:17`); breit beides in einer Zeile (Zeile 269-277).
   2. `Stoerung`, wenn beide Abfragen fehlten (`HausSeite.swift:101-103`, Text
      „Räume und Hausplan nicht erreichbar.", Zeile 470).
   3. `Alarmkarte` (`HausSeite.swift:104-106`, Aufbau Zeile 492-549): Karte mit Kicker „Alarm"
      und `alarm.stateDe` als Titel, zwei Knöpfe „Zu Hause scharf" / „Abwesend scharf" in
      `Farbe.amberWeich`, Satz „Entschärft wird an der Anlage, nicht hier."
   4. Ansicht Liste (`HausSeite.swift:296-348`): `Raumlegende()`, je Etage Kicker + Etagentext
      (Zeile 303-309), Gitter aus `Raumkachel` mit `GridItem(.adaptive(minimum: 290))` bzw.
      einer Spalte am Telefon (Zeile 310-325, 354-358), danach `Automatikkarte`
      (Zeile 328-330), bei `named == false` eine Hinweiskarte (Zeile 331-338), sonst
      „Keine Räume gemeldet." (Zeile 339-346).
   5. Ansicht Modell (`HausSeite.swift:386-439`): eine `Karte`, darin bei mehr als einem Deck
      `Ansichtswahl` über „Alle" + Decks (Zeile 394-410), darunter `Glasmodell` mit fester Höhe
      460 (Zeile 411-434); ohne Plan `modellhinweis` (Zeile 445-456).
   6. Blätter: Tipp auf Kachel oder Raum im Modell öffnet `Raumblatt` (Zeile 50-56, 171, 321,
      431; `Bausteine/Blaetter.swift:9`), der Protokollknopf `Raumprotokollblatt` (Zeile 57-63).

B. breit UND Ansicht == Modell (`HausSeite.swift:125-151`, ohne Rollbereich, Rand 32/4/14):
   1. `werkzeuge` (Zeile 194-212): rechtsbündig Pillen Liste/Modell, dahinter bei mehr als einem
      Deck Pillen „Alle" + Decks; Gestalt in Zeile 214-236 (Mono 10,5, Sperrung 1,3, gewählt
      `Farbe.petrol` auf `Farbe.amber`, Kapselrahmen `Farbe.linie2`).
   2. `Stoerung` (Zeile 128-130).
   3. Zeile aus `Hauskonsolenleiste` mit 216 Punkten Breite (Zeile 132-136,
      `Hauskonsolenleiste.swift:15`) und `buehne` (Zeile 154-187): `Glasmodell` randvoll,
      `legende` unten links (Zeile 239-256), Rahmen `Marken.radius2` + `Farbe.linie1`.
   4. `plan.noteDe` als 11-Punkt-Satz in `Farbe.text3` (Zeile 140-145).

Laden (`HausSeite.swift:460-484`): vier Abfragen parallel – `raeume()`, `haus()`,
`raeumeTag(heute, 15)`, `raumAutomatik()`; danach eine Schleife, die alle **60 Sekunden** die
ersten drei erneut holt (Zeile 476-484).

VORLAGE: `apps/web/src/app/haus/page.tsx:1-8` → `HouseReport`
(`apps/web/src/components/house/HouseReport.tsx:56-365`)

  * **Hülle mit Kicker** (`HouseReport.tsx:218-251`, `layout/AreaShell.tsx:13-29`)
    Kicker im Reiterband: `plan.name || "Hausplan"` + " · " + `house.source_de`
    (`HouseReport.tsx:219`). Rechts im Kopf zwei Gruppen: der Umschalter `.ansichten`
    (Zeile 222-229) und, nur in der Modellansicht, `.haus-werkzeuge` (Zeile 230-249) mit der
    Geschossgruppe und zwei runden Drehknöpfen „↺" / „↻" (Zeile 245-246).
    Maße: `.ansichten` 1px `--line-2`, Radius 4, Fläche 4; `.ansicht` 6/14, 12px, gewählt
    `--amber` auf `--petrol` (`globals.css:778-782`). `.haus-gruppe` Kapsel aus
    rgba(15,46,61,.72) + `--line-2`, Knöpfe Mono 10,5px, Sperrung .12em, Großschrift,
    7/12; gewählt `--petrol` auf `--amber`; `.rund` 34px breit, 14px
    (`globals.css:473-477`).
    Verhalten: die Wahl steht in der Adresse (`?ansicht=`, `HouseReport.tsx:78-87`); ohne
    Angabe entscheidet `(max-width: 720px)` – Telefon beginnt mit der Liste, alles andere mit
    dem Modell (Zeile 51, 74-77). Begründung im Kopfkommentar Zeile 41-49: „Bis zum 11.11.2026
    waren es zwei Bereiche … Jetzt ist es ein Bereich mit einem Schalter."
    DATEN: `/haus` (`api.house()`, Zeile 102) alle 10 s, `/rooms` (`api.rooms()`, Zeile 109)
    alle 30 s (Zeile 53-54, 115-124), dazu der Ereignisstrom (`startLiveClient()`, Zeile 92)
    und die Serveruhr über `serverOffsetMs` im Zehnsekundentakt (Zeile 93-98).

  * **Karte „Kein Hausplan"** (`HouseReport.tsx:255-264`) – nur in der Modellansicht, wenn
    `house` da ist und `plan` fehlt. `CardHead title="Kein Hausplan"`, darunter `house.error_de`
    (13px, `--text-2`, max 72ch) und ein zweiter Satz (12px, `--text-3`): die Vorlage liegt
    unter `config/haus.example.yaml`, „Die Bruecke liest die Datei alle 30 Sekunden neu, ein
    Neustart ist nicht noetig."
    DATEN: `house.error_de`, `house.present`.

  * **`.haus-seite`: das Raster der ganzen Seite** (`HouseReport.tsx:266-347`,
    `globals.css:447`) – `grid-template-columns: 216px minmax(0,1fr)`, Abstand 14,
    `min-height: 520px`. **Links steht in BEIDEN Ansichten die Konsole**, rechts entweder
    `.haus-liste` (Zeile 281-285) oder `.haus-buehne-huelle` (Zeile 286-345).
    Handy-Fassung (`globals.css:542-553`): unter 900px eine Spalte, `min-height: 0`, und
    `.haus-konsole` wird eine **quer rollende Reihe** (`flex-direction: row; overflow-x: auto;
    gap: 6px`), `.haus-block` dort `min-width: 138px`, Polster 7/10/7/14, Wert 16px, Satz
    10,5px; `.haus-legende { display: none }`. Unter 720px (`handy.css:386-393`, mit
    Begründung: „Die Konsole liegt quer und rollt. Der Block mit den Alarmknöpfen braucht Platz
    für zwei Knöpfe nebeneinander"): `.haus-block { min-width: 150px; border-radius: 14px }`,
    `.haus-block:has(button) { min-width: 228px }`, Fenster und Blätter enden
    `calc(78px + env(safe-area-inset-bottom))` über dem Rand, `.haus-buehne-huelle
    { min-height: 58dvh; border-radius: 16px }`.

  * **Konsole, Block 1: Alarm** (`house/Konsole.tsx:165-184`)
    Kicker „Alarm", Wert `ALARM_WORT[stufe]` – UNSCHARF / ZU HAUSE / UNTERWEGS / SCHALTET /
    AUSGELÖST / KEINE MELDUNG (`house/live.ts:40-47`), Satz `state.alarm.state_de` bzw.
    „nicht eingerichtet" (`live.ts:61`). Streifenfarbe `var(--amber)`.
    Zustände als Fläche (`globals.css:462-464`): `zuhause` Rahmen rgba(242,177,52,.45) und
    Verlauf von rgba(242,177,52,.16); `unterwegs` rgba(255,122,69,.5)/.2; `ausgeloest`
    rgba(255,59,59,.7)/.3 **plus** `animation: dch-pulse .7s ease-in-out infinite`.
    Knöpfe „zu Hause" / „unterwegs" nur wenn `alarm.present` und der Zustand nicht
    `ausgeloest` ist; der Knopf des schon geltenden Zustands ist gesperrt (Zeile 172-181).
    Danach die Rückmeldung (Zeile 182) und bei Gastrolle „Gastzugang: nur Ansicht." (Zeile 183).
    Maße des Blocks (`globals.css:451-461`): Polster 10/12/10/18, Radius `16px 4px 4px 16px`,
    Streifen 6px mit eigener Rundung, Fläche rgba(15,46,61,.72), Rahmen `--line-1`; Kicker Mono
    9,5px Sperrung .18em `--text-3`, Wert Mono 21px, Einheit `small` 10px Großschrift Sperrung
    .1em `--text-3`, Satz 11,5px `--text-2`, Pfeil „›"/„‹" Mono 16px rechts (Zeile 453-457).
    DATEN: `state.alarm.{present,state,state_de,can_arm}`, `useRole()` (`HouseReport.tsx:215`),
    `api.armAlarm(mode)` (Zeile 197).

  * **Konsole, Block 2: „Fenster und Türen"** (`Konsole.tsx:186-224`)
    Wert = Zahl der offenen Kontakte + `small` „offen"; Satz `offenSatz` – „keine Kontakte im
    Plan" / „alles zu" / ein Name / „X und N weitere" (`live.ts:73-78`). Farbe `var(--mist)`.
    Fenster (`.haus-pop`, `globals.css:515`: rechts daneben, 330 breit, max
    `min(70dvh,560px)`, Radius 10, Rahmen `--line-2`, rgba(10,36,49,.94), Blur 12):
    alle Kontakte des Plans, sortiert offen → zu → stumm, Türen vor Fenstern, dann Name
    (`insights.ts:59-77`, Begründung Zeile 52-58: „Ein stummer Kontakt steht hinten und nicht
    gar nicht"). Je Zeile Name, darunter der Raum bzw. „Tür"/„Fenster" (Mono 10px Großschrift,
    `globals.css:527`), rechts „offen" (`--amber`) / „zu" / „keine Meldung" (`--text-3`), bei
    offenen zusätzlich „ seit 12 min" (`seitText`, `insights.ts:196-201`). Zeilen mit Raum sind
    tippbar und springen in das Modell. Leerfall „Der Hausplan nennt keine Kontakte."
    Fuß: „Die Kontakte kommen aus der Alarmanlage. Ein Tippen auf eine Zeile holt den Raum ins
    Modell." (11,5px `--text-3`, `globals.css:534`).
    Schließen: Escape und ein Zeiger außerhalb der Konsole (`Konsole.tsx:136-151`).
    DATEN: `house.plan.decks[].contacts[]` und `house.contacts[]` über `key`
    (`live.ts:52-53`), Felder `key,name,room,door,open,observed_at`.

  * **Konsole, Block 3: Puffer** (`Konsole.tsx:226-277`)
    Wert `round(soc*100)` + `small` „%", Satz die vier Schichttemperaturen gerundet mit „ · "
    verbunden, sonst „keine Werte" (Zeile 235). Farbe `var(--heat-pump)` = #e0966b
    (`tokens.css:45`).
    Fenster: `.haus-pop-gross` (`globals.css:516-518`) „X kWh" Mono 28px mit „nutzbar von Y"
    (12px `--text-3`); dann die vier Schichten „oben / Mitte oben / Mitte unten / unten"
    (`insights.ts:127`) je mit einem 9px-Punkt in `heatColor(temp)` (`home/puffer`), rechts
    `celsius(t,1)` oder „kein Messwert", und bei nicht frischem Messwert „ vor 20 min"
    (`frisch` = quality ok|derived, `insights.ts:136-143`); dann die Zeile „Zustand" mit
    `statusWort` (kalt / teilweise geladen / warm / voll / unbekannt, `insights.ts:146-148`)
    und „ noch N % Platz" aus `headroom_soc`; Fuß `methodeText` – „Schichtenmodell: jede
    Schicht mit ihrem eigenen Anteil am Volumen" bzw. „gewichtetes Mittel der vier Fühler"
    (`insights.ts:151-156`) + „ · N Liter." + Verweis „Wärme und Verlauf" → `/waerme`
    (`--amber`, ohne Unterstreichung, `globals.css:535`).
    DATEN: `state.buffer.{soc,usable_energy_kwh,capacity_kwh,status,method,volume_liters,
    headroom_soc}`, `state.snapshot.buffer_temps_c.{top,mid_top,mid_bottom,bottom}`.

  * **Konsole, Block 4: Wärmepumpe** (`Konsole.tsx:279-306`)
    Wert `kwWithUnit(live.waermepumpeKw)`; Satz „läuft seit 3 h 10 min" bzw. „steht seit
    42 min" aus `running_since`/`stopped_since` (Zeile 283). Farbe `var(--heat-pump)`.
    Fenster: zuerst die **Tageskurve** (`Konsole.tsx:111-131`): SVG 280 × 46,
    `preserveAspectRatio="none"`, Grundlinie `--line-1`, ein Pfad je zusammenhängendem Stück in
    `--heat-pump`, Strichbreite 1,6, rund abgeschlossen; darunter die Achse Mono 9px
    „00" – „N kW" – „24" (`globals.css:538-540`). Die Reihe ist `history.map(p => p.hp)`, auf
    96 Stellen verdichtet (`verdichte`, `insights.ts:229-236`), Höchstwert `max(1, ceil(max))`.
    Lücken bleiben Lücken (`insights.ts:203-208`: „Eine durchgezogene Linie über eine Minute
    ohne Messwert waere eine Behauptung ueber genau die Minute, in der nichts ankam").
    Dann vier Zeilen: „heute" → `kwh` Strom, „Laufzeit" → `dauerText` („3 h 10 min"/„42 min",
    `insights.ts:187-193`), „Starts" → `starts_today`, „Anforderung" mit der Unterzeile „das
    Signal: jetzt mehr Wärme erzeugen" und „an"/„aus" (an in `--amber`). `tagesLauf` zählt die
    Minuten ab `LAEUFT_KW = 0.1` und integriert `hp/60` (`insights.ts:170-184`).
    Danach `state.decision.explanation_de` in `.haus-pop-grund` (2px linke Linie, Fläche
    rgba(255,255,255,.03), 12px, `globals.css:537`), Fuß „Betrieb: Automatik|von Hand." +
    Verweis „Erzeuger und Verlauf".
    DATEN: `state.heat_pump.{running,running_since,stopped_since,starts_today,
    release_contact_on}`, `state.snapshot.heat_pump_power_kw`, `state.decision.explanation_de`,
    `state.operating_mode.system_mode`, das Minutenraster des Live-Speichers (`history`).

  * **Konsole, Block 5: Heizkreise** (`Konsole.tsx:308-351`)
    Wert = Zahl der Räume mit `valve > 0` + `small` „offen" (`live.ts:67`), Satz „N Räume"
    bzw. „keine Raumwerte". Farbe `var(--ev)` = **#5c8fa3** (`tokens.css:57`).
    Fenster: nur die Räume mit offenen Kreisen, sortiert nach Ventilanteil absteigend, dann
    Abweichung, dann Name (`insights.ts:100-115`; Begründung Zeile 93-99: „Der Block zaehlt die
    offenen; das Fenster soll dieselbe Zahl erklaeren und nicht eine zweite Liste daneben
    stellen"). Je Zeile Name, Unterzeile Etage, rechts `ventilText(valve, circuits)` –
    „3 von 4 offen" / „zu" / Anteil (`rooms/palette.ts:74-81`) und klein die Temperatur; jede
    Zeile tippbar. Leerfall „Kein Heizkreis steht offen."
    Danach, wenn `anDerGrenze` greift (`valve >= 0.99 && deviation_k < -0.5`,
    `insights.ts:121-123`): „X hat alle Kreise offen und liegt trotzdem unter dem Ziel. Dieser
    Raum bestimmt die nötige Vorlauftemperatur für alle anderen mit."
    Fuß: „Die Antriebe sind auf oder zu, nichts dazwischen." + Verweis „Heizkreise im
    Tagesverlauf" → `/waerme/raeume`.
    DATEN: `/rooms` – `{id,name,floor,valve,circuits,temp_c,target_c,setpoint_c,deviation_k}`.

  * **Rechts in der Listenansicht: `.haus-liste`** (`HouseReport.tsx:281-285`,
    `globals.css:776`: Spalte, Abstand 16, `min-width: 0`) mit
    `<Raumteile anchor="" kacheln auswertung={false} />` (`rooms/RoomsReport.tsx:297`):
    Legende, je Etage Kicker + Etagentext, `.rooms-grid` aus `RaumKachel`, danach `Automatik`
    (Zeile 426-474). Ohne Plan steht dieselbe Liste allein, ohne Konsole
    (`HouseReport.tsx:350-352`, mit Begründung: „Die Liste braucht keinen Hausplan").
    DATEN: `/rooms` alle 30 s und `/rooms/day?step_min=15` (`RoomsReport.tsx:38-40, 343, 351`).

  * **Rechts in der Modellansicht: die Bühne** (`HouseReport.tsx:286-345`)
    `.haus-buehne-huelle`: `min-height: 480px`, Radius `--radius-2` (3px), Rahmen `--line-1`,
    Grund **#0b2e3f** (`globals.css:468`). Darin three.js, erst im Browser geladen
    (`HouseReport.tsx:137`, Begründung im Kopfkommentar Zeile 38-39: „das halbe Megabyte soll
    nicht in jeder anderen Seite mitreisen"). Startwerte aus der Adresse: `deck`, `dreh`,
    `fokus` (Zeile 136-151).
    `.haus-legende` unten links (`globals.css:501-502`): Kicker „kalt", ein Balken 120 × 7,
    Radius 4, Verlauf `#25506a → #3d7a9c → #6ab6c8 → #c8902f → #f2b134 → #ff7a45` mit Rahmen
    `--line-2`, Kicker „warm", dann „gelb: unter Ziel · tippen: Raum" (je 10px,
    `HouseReport.tsx:289-294`).
    Lebendig im Takt (`HouseScene.ts:1303-1365`): Heizschlangen pulsen mit dem Ventilanteil,
    Rotoren drehen über 0,2 kW, **die Pelletglut atmet, wenn `ofenLaeuft`** (Zeile 1341,
    `live.ts:66`), Kontaktflügel schwingen auf, das Alarmschild pulst je Stufe (Zeile 1356-1362),
    Namen verschwinden unter 27 bzw. 30 Punkten je Meter, Kontaktfahnen unter 26 zu Punkten
    (Zeile 1322-1331, mit Begründung: „Zwei offene Tueren, zwei Fahnen, ein Wortsalat … am
    30.10.2026 ‚Gartentuer 1 offen offen'").

  * **Das Fokusfenster am Modell: `.haus-panel`** (`HouseReport.tsx:295-343`,
    `globals.css:503-513`)
    Oben rechts in der Bühne, 320 breit, Polster 16/18/14, Radius 10, rgba(10,36,49,.94),
    Rahmen `--line-2`, Blur 10, Schatten 0 10px 40px. Inhalt: Deckname als Kicker 10px, der
    Raumname 18px halbfett, rechts der Knopf „Schließen" (`.haus-zu`: Mono 10px, Sperrung .14em,
    Kapsel mit `--line-2`); dann die Temperatur **Mono 44px**, Gewicht 500, Sperrung −.03em, mit
    „°C gemessen" daneben (Zeile 306-309); dann zwei `.haus-zeile` (Haarlinie oben, Kicker Mono
    10px Sperrung .16em, Wert Mono 15px): „Ziel" → `celsius(target_c ?? setpoint_c, 1)`,
    „Heizkreis" → `round(valve*100) %`. Ohne Thermostat „Kein Thermostat in diesem Raum."
    Dann „Fenster und Türen" als Liste der Kontakte **dieses** Raums (Zeile 322-337,
    `fokusKontakte` Zeile 209-213) mit „offen"/„zu"/„keine Meldung", offene in `--amber`,
    Leerfall „keine Kontakte in diesem Raum". Zuletzt „Sollwert stellen"
    (`.haus-stellen`: Mono 11px, `--petrol` auf `--amber`, Kapsel 9/14) → `rooms/Stellen`
    (`HouseReport.tsx:356-362`).
    Handy: das Fenster wird ein Blatt am unteren Rand (`globals.css:551`: `left/right 10`,
    `bottom 10`, `max-height: 48%`, rollend; `handy.css:392` über der Bereichsleiste).
    Im Fokus dimmt die Szene die übrigen Schilder auf 0,18 und zieht das gewählte auf 1,25
    (`globals.css:487-488`).
    DATEN: `live.raeume` über `room_id`, `plan.decks[].contacts[]` nach `room`.

  * **Der Sprung aus der Konsole ins Modell: `springe`** (`HouseReport.tsx:176-191`)
    Aus einer Kontakt- oder Kreiszeile: steht die Liste vorn, wechselt die Seite in die
    Modellansicht und schreibt `deck` und `fokus` in die Adresse (die Szene entsteht neu und
    liest sie, Zeile 180-186); sonst wird nötigenfalls das Geschoss gewechselt und der Raum
    scharf gestellt. Danach schließt das Fenster.

  * **Fußsatz** (`HouseReport.tsx:354`): `plan.note_de`, 11px, `--text-3`, max 90ch – **in der
    Modellansicht jeder Breite**, außerhalb des Rasters.

LUECKEN:

  [traegt-die-seite] Die Konsole steht nur in der breiten Modellansicht. Die Vorlage hat sie in
    beiden Ansichten und auf jeder Breite (`HouseReport.tsx:266-279` im Raster `.haus-seite`,
    `globals.css:447`; am Telefon als quer rollende Reihe, `globals.css:543-549`,
    `handy.css:389-390`). In der App baut sie nur `wandmodell`, und das greift allein bei
    `!schmal && ansicht == .modell` (`HausSeite.swift:98`, 125-136). Am Telefon – der Fassung,
    mit der die Seite anfängt – und in jeder Listenansicht fehlen damit vier der fünf Blöcke:
    Fenster und Türen, Puffer, Wärmepumpe, Heizkreise. Übrig bleibt die `Alarmkarte`
    (`HausSeite.swift:104-106`). „Wie viele Fenster sind offen" ist auf dem Telefon nicht
    beantwortbar, obwohl der Kopfkommentar der App genau das als Zweck nennt
    (`Hauskonsolenleiste.swift:5-10`).

  [traegt-die-seite] Die vier Aufklapp-Fenster der Konsole fehlen ganz. In der App führt jeder
    Block statt dessen auf eine andere Seite (`Hauskonsolenleiste.swift:138,149,166,174`,
    begründet Zeile 12-14). Damit erscheint nirgends auf dieser Seite: die Liste aller Kontakte
    mit „seit 12 min" (`Konsole.tsx:201-222`), die vier Pufferschichten mit Punkt, Temperatur,
    Alter, „nutzbar von X", Zustandswort, Restplatz und Methodensatz (`Konsole.tsx:241-274`),
    die Tageskurve der Wärmepumpe samt kWh, Laufzeit, Starts, Anforderung und
    `explanation_de` (`Konsole.tsx:289-303`), die Liste der offenen Heizkreise mit
    `ventilText` und dem Satz zum Raum an der Grenze (`Konsole.tsx:322-345`). Die Vorlage sagt
    ausdrücklich, warum das ein Fenster und keine zweite Seite ist (`Konsole.tsx:16-21`: „Die
    Antwort gehoert neben die Zahl, nicht hinter einen Seitenwechsel").

  [spuerbar] Der Alarmblock sagt zweimal dasselbe und zeigt seinen Zustand nicht als Fläche.
    Vorlage: Wert `ALARM_WORT[stufe]` (UNSCHARF / ZU HAUSE / UNTERWEGS / SCHALTET / AUSGELÖST /
    KEINE MELDUNG, `live.ts:40-47`), Satz `state_de`, und der Block färbt sich je Zustand mit
    Verlauf und Rahmen, bei `ausgeloest` mit `dch-pulse` (`globals.css:462-464`).
    App: `alarm.stateDe.uppercased()` als Wert **und** `alarm.stateDe` als Satz
    (`Hauskonsolenleiste.swift:105`), Farbe nur im 3-Punkt-Streifen amber/mist (Zeile 106),
    kein Verlauf, kein Puls. Ferner: die Vorlage sperrt den Knopf des geltenden Zustands und
    versteckt beide bei `ausgeloest` (`Konsole.tsx:172-181`) – die App prüft nur `canArm` und
    `darfSchalten` (`Hauskonsolenleiste.swift:108`) – und sie schreibt „Gastzugang: nur
    Ansicht." in den Block (`Konsole.tsx:183`); in der Leiste der App steht das nicht.

  [spuerbar] Das Fokusfenster am Modell fehlt. In der App öffnet ein Tipp auf einen Raum das
    volle Blatt `Raumblatt` (`HausSeite.swift:171,431`; `Blaetter.swift:9`) und verdeckt damit
    das Modell. Das Blatt hat die Zahlen und den Regler, aber **nicht** die Kontakte dieses
    Raums (`Blaetter.swift:64-89` listet jetzt, Sollwert, wirksamer Sollwert, Abweichung,
    Ventil, Heizkreise, Luftfeuchte, Messwert – gesucht nach „Kontakt"/„Fenster" in
    `Blaetter.swift`: kein Treffer), und es gibt kein Abdunkeln der übrigen Schilder und kein
    Hervorziehen des gewählten (`globals.css:487-488`).

  [spuerbar] Woher der Plan kommt, steht nirgends. Vorlage: Kicker `plan.name · house.source_de`
    (`HouseReport.tsx:219`). Gesucht nach `sourceDe` in
    `apps/ios/DuckCurveHome/Seiten/Haus/`: kein Treffer (nur `noteDe`, `errorDe`, `present` –
    `HausSeite.swift:140,446,448`). `HouseOut.sourceDe` ist da (`Modelle/Schema.swift:4479`).

  [spuerbar] Der Takt des Nachladens ist sechsmal langsamer. Vorlage: `/haus` alle 10 s,
    `/rooms` alle 30 s (`HouseReport.tsx:53-54,115-124`), begründet im Kopfkommentar
    Zeile 26-29 („alle 30 Sekunden, haeufiger fragt Controme nicht" / „alle 10 Sekunden").
    App: eine Schleife, 60 s für alle drei Abfragen (`HausSeite.swift:476-484`). Ein offenes
    Fenster erscheint damit bis zu einer Minute später.

  [spuerbar] `plan.noteDe` steht nur in der Wandfassung (`HausSeite.swift:140-145`); die
    Vorlage zeigt den Satz in jeder Modellansicht, auch am Telefon (`HouseReport.tsx:354`).

  [spuerbar] Der Sprung aus einer Konsolenzeile in den Raum im Modell (`springe`,
    `HouseReport.tsx:176-191`) hat kein Gegenstück; gesucht nach einem Fokus- oder Sprungweg in
    `HausSeite.swift` und `Hauskonsolenleiste.swift`: kein Treffer (die Blöcke rufen
    `wegweiser.gehe(weg)`, `Hauskonsolenleiste.swift:95`).

  [klein] Falsche Farbe am Heizkreisblock: Vorlage `var(--ev)` = #5c8fa3 (`tokens.css:57`,
    `Konsole.tsx:320`); App `Farbe.diagrammWallbox` = #2F89B5
    (`Hauskonsolenleiste.swift:174`, `Marken.swift:133`). Der passende Marker ist
    `Farbe.wallbox` = #5C8FA3 (`Marken.swift:91`).

  [klein] Maße der Blöcke: Vorlage Polster 10/12/10/18, Radius `16px 4px 4px 16px`, Streifen
    **6px**, Fläche rgba(15,46,61,.72), Wert Mono **21px**, Einheit 10px Großschrift gesperrt,
    Satz 11,5px in **`--text-2`** (`globals.css:451-461`). App: Polster 11/13, Radius überall
    `Marken.radius2` = 3 (`Marken.swift:262`), Streifen 3px, Fläche `flaeche1` bei 0,55, Wert
    Mono 26, Einheit Sans 11, Satz Sans 12 in `Farbe.text3`
    (`Hauskonsolenleiste.swift:55-91`). Sichtbar sind vor allem der zu blasse Satz und die
    fehlende einseitige Rundung.

  [klein] Bei nur einem Deck zeigt die Vorlage die Gruppe trotzdem, mit der Aufschrift „Haus"
    (`HouseReport.tsx:233-234`); die App lässt die Pillen dann ganz weg
    (`HausSeite.swift:201`, 394).

  [klein] Die Bühne am Telefon hat in der App eine feste Höhe von 460 Punkten
    (`HausSeite.swift:433`); die Vorlage rechnet in Bildschirmhöhe: 70dvh unter 900px
    (`globals.css:550`), 58dvh unter 720px (`handy.css:393`).

  [klein] „Kein Hausplan": die Vorlage nennt `error_de` **und** die Beispieldatei
    `config/haus.example.yaml` samt „Die Bruecke liest die Datei alle 30 Sekunden neu, ein
    Neustart ist nicht noetig." (`HouseReport.tsx:255-263`); die App schreibt „Der Plan kommt
    von der Brücke (haus.yaml)." (`HausSeite.swift:447-452`).

  [klein] Die Pelletglut im Modell lebt in der Vorlage von `ofenLaeuft`
    (`HouseScene.ts:1341`, `live.ts:66`); gesucht nach „ofen"/„Ofen" in
    `apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift`: kein Treffer, und `Glasmodell` nimmt
    keinen solchen Wert an (`Glasmodell.swift:23-37`).

  [klein] Ansicht, Geschoss, Drehung und Fokus stehen in der Vorlage in der Adresse
    (`HouseReport.tsx:78-87`, 143), damit ein Verweis genau dort landet (Begründung
    Zeile 48). In der App sind es `@State` (`HausSeite.swift:16,21`).

KERN: SCHON DA (nachgesehen)

  * Abfragen: `Api.haus()` (`Netz/Api.swift:217`), `raeume()` (:221),
    `raeumeTag(_:schrittMin:)` (:225), `raumProtokoll` (:230), `raumWirkung` (:234),
    `raumAutomatik()` (:247), `schaerfeAlarm(_:)` (:337), `haustuer(tage:)` (:369).
  * Modelle: `HouseOut` mit `at, present, plan, sourceDe, receivedAt, errorDe, contacts`
    (`Modelle/Schema.swift:4475-4492`); `HouseContactOut` mit
    `key, name, room, door, open, observedAt, quality` (:4428-4445);
    `BufferState` mit `soc, usableEnergyKwh, capacityKwh, volumeLiters, meanTempC, status,
    method, headroomSoc` (:2127-2155); `startsToday` (:4146), `releaseContactOn` (:4144),
    `stoppedSince` (:4142); `AlarmOut` mit `present, state, stateDe, canArm, observedAt`
    (:817-832).
  * Sätze der Konsole: `Hauskonsole.offenSatz` (`Haus/Hauskonsole.swift:15`),
    `pumpensatz` (:23), `schichtsatz` (:37), `offeneKreise` (:47).
  * Räume: `Raumabweichung.ventilText(_:kreise:)` (`Zustand/Raumabweichung.swift:121`),
    `nachEtage`/`etagenText`/`gewesen` (benutzt in `HausSeite.swift:300,305,380`).
  * Kurven mit Lücken: `Raumkarte.kurve(_:)` liefert Stücke in Einheitskoordinaten
    (`Zustand/Raumkarte.swift:78-98`) – das Vorbild für den Sparkline-Pfad;
    `Raumkarte.anDerGrenze(tagesventil:abweichung:fensterOffen:)` (:109) – **andere Regel** als
    die Konsole (0,85 und Fensterprüfung gegen 0,99/−0,5 in `insights.ts:121-123`).
  * Verdichten: `Datenbild.verdichte(_:schrittMin:)` (`Zustand/Datenbild.swift:388`) –
    verdichtet nach Schrittweite, nicht auf eine feste Spaltenzahl.
  * Formate: `dauer(minuten:)` (`Formate/Formate.swift:105`), `alter(beobachtetAm:jetzt:)`
    (:178), `kwh` (:75), `kwMitEinheit` (:69), `celsius` (:87), `prozent` (:81), `hhmm` (:124);
    `Anlagenschema.dauerText(seit:jetzt:)` (`Zustand/Anlagenschema.swift:146`).
  * Minutenraster für die Tageskurve: `Verlaufspunkt` mit `waermepumpe`
    (`Zustand/Verlauf.swift:7-20`), `Minutenraster` (:46), in der App als `haus.raster`
    (`App/Hauszustand.swift:29`).
  * Farben und Maße: `Farbe.wallbox` #5C8FA3 (`Gestalt/Marken.swift:91`),
    `waermepumpe` #E0966B (:58), `mist` #7FA3B3 (:20), `amber` #F2A900 (:18),
    `amberWeich` (:19), `linie1/linie2` (:32-33), `text1/2/3` (:43-45),
    `Marken.radius1..3` = 2/3/6 (:261-263); `Hausgeometrie.temperaturstopps`
    (benutzt `HausSeite.swift:246`).
  * Oberfläche: `Kicker` (`Gestalt/Typografie.swift:132`), `Ansichtswahl`
    (`Gestalt/Ansichtswahl.swift:17`, mit der Telefonfassung nach `handy.css:177-179`),
    `Karte`, `Leer`, `Stoerung`, `Zahl`, `Zeile`, `Glasmodell`
    (`Haus3D/Glasmodell.swift:23`), `Raumkachel`, `Automatikkarte`, `Raumblatt`,
    `Raumprotokollblatt`.

ES FEHLT:

  1. `Hauskonsole.Alarmstufe` + `Hauskonsole.stufe(_ state: Double?) -> Alarmstufe` und
     `Hauskonsole.wort(_:)` mit den sechs Wörtern UNSCHARF / ZU HAUSE / UNTERWEGS / SCHALTET /
     AUSGELÖST / KEINE MELDUNG (Vorlage `house/live.ts:31-47`). Gesucht nach
     „alarmStufe"/„ALARM_WORT"/„alarmWort" in `apps/ios/DuckCurveKit/Sources/DuckCurveKit`:
     kein Treffer. Datei: `Haus/Hauskonsole.swift`.
  2. `Hauskonsole.Kontaktzeile { key, name, tuer, raum, offen, beobachtetAm }` und
     `Hauskonsole.kontaktzeilen(plan:kontakte:)` mit der Reihenfolge offen → zu → stumm,
     Türen vor Fenstern, dann Name nach deutscher Sortierung (Vorlage `insights.ts:41-77`).
     Datei: `Haus/Hauskonsole.swift`.
  3. `Hauskonsole.Kreiszeile { id, name, etage, ventil, kreise, tempC, zielC, abweichungK }`,
     `Hauskonsole.kreiszeilen(_ raeume:)` (Ventil absteigend, dann Abweichung, dann Name) und
     `Hauskonsole.anDerGrenze(_ zeilen:)` mit der Regel `ventil >= 0.99 && abweichung < -0.5`
     (Vorlage `insights.ts:81-123`) – getrennt von `Raumkarte.anDerGrenze`
     (`Zustand/Raumkarte.swift:109`), die eine Tagesregel ist.
  4. `Hauskonsole.Schichtzeile { name, tempC, beobachtetAm, frisch }` und
     `Hauskonsole.schichtzeilen(_ temps: BufferTemperatures)` mit den Namen „oben / Mitte oben /
     Mitte unten / unten" und `frisch` = Quality `ok`|`derived` (Vorlage `insights.ts:127-143`).
  5. `Hauskonsole.statuswort(_ status: BufferStatus?)` → kalt / teilweise geladen / warm / voll
     / unbekannt und `Hauskonsole.methodensatz(_ method: String?)` → „Schichtenmodell: jede
     Schicht mit ihrem eigenen Anteil am Volumen" bzw. „gewichtetes Mittel der vier Fühler"
     (Vorlage `insights.ts:146-156`).
  6. `Hauskonsole.Tageslauf { kwh, minuten, hoechst }` und
     `Hauskonsole.tageslauf(_ punkte: [Verlaufspunkt])` über `waermepumpe`, mit
     `LAEUFT_KW = 0.1` und `kwh += p/60` (Vorlage `insights.ts:160-184`).
     Datei: `Haus/Hauskonsole.swift`, liest `Zustand/Verlauf.swift`.
  7. `Hauskonsole.verdichte(_ werte: [Double?], stellen: Int) -> [Double?]` – Mittel je Fenster
     auf eine **feste** Spaltenzahl (96), Lücken bleiben `nil` (Vorlage `insights.ts:229-236`);
     `Datenbild.verdichte` (`Zustand/Datenbild.swift:388`) kann das nicht.
  8. `Hauskonsole.sparklinie(_ werte: [Double?], hoechst: Double) -> [[Punkt]]` –
     zusammenhängende Stücke in Einheitskoordinaten, Lücken bleiben Lücken; dieselbe Regel wie
     `Raumkarte.kurve` (`Zustand/Raumkarte.swift:78-98`), aber Achse 0…hoechst statt ±Kelvin.
  9. `Hauskonsole.raumOrt(plan:raumId:)` und `Hauskonsole.kontaktOrt(plan:schluessel:)`
     → `(deck, raum)` (Vorlage `insights.ts:14-37`) – nötig, sobald eine Zeile in das Modell
     springt.
 10. `Glasmodell` braucht `ofenLaeuft: Bool?` als Eingang (Vorlage `HouseScene.ts:1341`), und
     im Kern die Ableitung „Ofen brennt" aus `state.stove.{present,running}`
     (Vorlage `house/live.ts:66`).
 11. Ein Fokuszustand des Modells: `Glasmodell` müsste einen gewählten Raum annehmen und die
     übrigen Schilder dimmen (Vorlage `globals.css:487-488`); heute kennt es nur `tippeRaum`
     (`Haus3D/Glasmodell.swift:36`).

BAUPLAN:

  1. **Kern zuerst** – `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Haus/Hauskonsole.swift`
     erweitern um die Punkte 1 bis 9 aus „ES FEHLT", je mit Test in
     `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests/HauskonsoleTests.swift` (die Datei gibt es
     schon). Reihenfolge der Vorlage: Alarmwort, Kontaktzeilen, Pufferschichten +
     Statuswort + Methodensatz, Tageslauf + verdichte + sparklinie, Kreiszeilen + anDerGrenze,
     Orte.
  2. **`Hauskonsolenleiste.swift` auf die Blockmaße der Vorlage bringen**: Polster 10/12/10/18,
     einseitige Rundung (16/4/4/16), Streifen 6px, Fläche rgba(15,46,61,.72), Wert Mono 21,
     Satz 11,5 in `Farbe.text2`, Heizkreise auf `Farbe.wallbox`; Alarmblock mit `Alarmwort` als
     Wert, `stateDe` als Satz, Zustandsfläche (Verlauf + Rahmen je Stufe) und Puls bei
     `ausgeloest`, Knopfsperre für den geltenden Zustand, „Gastzugang: nur Ansicht."
  3. **Ein neues Blatt je Block** – `apps/ios/DuckCurveHome/Seiten/Haus/Hauskonsolenblatt.swift`:
     vier Fälle (Kontakte, Puffer, Wärmepumpe, Heizkreise) mit genau dem Inhalt der Vorlage,
     als `.sheet` mit `presentationDetents` statt des Browser-Pop-ups – das ist der Weg, den die
     Vorlage am Telefon selbst nimmt (`globals.css:544-546`: „Es kommt deshalb als Blatt von
     unten"). Der Fuß jedes Blattes behält seinen Verweis (`/waerme`, `/waerme/raeume`), damit
     der bisherige Weg nicht verschwindet.
  4. **Die Sparkline** – `apps/ios/DuckCurveHome/Diagramme/Konsolenkurve.swift`: Canvas 280 × 46,
     Grundlinie `Farbe.linie1`, Stücke in `Farbe.waermepumpe`, Strich 1,6, darunter die Achse
     Mono 9 „00 / N kW / 24". Vorbild im Projekt: `Diagramme/Tageskurve.swift`.
  5. **`HausSeite.swift` umbauen**: die Leiste aus `wandmodell` herausziehen und in `gerippe`
     an die erste Stelle setzen – breit als 216-Punkt-Spalte links von Liste **oder** Bühne
     (ein Raster für beide Ansichten, wie `.haus-seite`), schmal als `ScrollView(.horizontal)`
     mit Blöcken ab 150 Punkten Breite (228, wenn Knöpfe drin sind). Die `Alarmkarte`
     (Zeile 492-549) entfällt dabei – ihr Inhalt ist der Alarmblock.
  6. **Takt**: `haltFrisch` (`HausSeite.swift:476-484`) in zwei Schleifen teilen, `haus()` alle
     10 s, `raeume()` und `raeumeTag()` alle 30 s.
  7. **Kopf**: Kicker `plan.name · sourceDe` in `kopf` (`HausSeite.swift:258`) ergänzen;
     `noteDe` aus `wandmodell` in das gemeinsame Gerippe ziehen, sichtbar in jeder
     Modellansicht.
  8. **Bühne am Telefon**: die feste Höhe 460 (`HausSeite.swift:433`) durch einen Anteil der
     Schirmhöhe ersetzen (0,58 über `GeometryReader` bzw. `containerRelativeFrame`).
  9. **Fokus am Modell**: `Glasmodell` um `fokusRaum: Int?` erweitern, die übrigen Schilder auf
     0,18 dimmen, das gewählte um 1,25 vergrößern; darüber ein Fokusfenster – breit als
     Überlagerung oben rechts (320 Punkte), schmal als Blatt mit `.presentationDetents([.height(…)])`
     – mit 44-Punkt-Temperatur, „Ziel", „Heizkreis", den Kontakten dieses Raums und dem Knopf
     „Sollwert stellen", der weiter `Raumblatt` öffnet.
 10. **Sprung aus einer Zeile**: aus den Blättern aus 3. in das Modell – Ansicht auf `.modell`,
     Deck setzen, `fokusRaum` setzen, Blatt schließen (Vorlage `HouseReport.tsx:176-191`).
 11. **Kleinigkeiten**: Deckgruppe auch bei einem Deck zeigen („Haus"); den Text von
     `modellhinweis` (`HausSeite.swift:447-452`) um `config/haus.example.yaml` und den
     30-Sekunden-Satz ergänzen; `ofenLaeuft` an `Glasmodell` durchreichen.

WAS SCHWIERIG WIRD:

  * **Das Pop-up neben dem Block.** `.haus-pop` steht in der Vorlage rechts **neben** der
    Konsole und über dem Modell (`globals.css:515`) und schließt auf Escape oder einen Zeiger
    außerhalb (`Konsole.tsx:136-151`). In SwiftUI gibt es dafür kein freies Überlagern am Rand
    einer Spalte, und `popover` verhält sich auf dem iPad anders als am Telefon. Der im Projekt
    schon gewählte Weg ist das Blatt: `Raumblatt` und `Raumprotokollblatt` als `.sheet` am
    `Wegweiser.blatt` (`HausSeite.swift:50-63`, `Bausteine/Blaetter.swift:9`). Das deckt sich
    mit der Handy-Fassung der Vorlage (`globals.css:544-546`), ist also keine Abweichung,
    sondern deren Begründung.
  * **Die quer rollende Blockreihe.** `overflow-x: auto` mit `min-width` je Block
    (`globals.css:547-548`, `handy.css:389-390`) wird eine `ScrollView(.horizontal)` mit
    `frame(minWidth:)` je Block. Vorbild im Projekt: die rollende Reiterreihe in
    `apps/ios/DuckCurveHome/App/Reiterzeile.swift:35` (`ScrollView(.horizontal,
    showsIndicators: false)`), dieselbe Form auch in
    `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:54`.
  * **Die Sparkline mit Lücken.** Swift Charts zieht über `nil` hinweg, wenn man es nicht
    stückweise zeichnet. Im Projekt steht dafür schon eine Lösung: `Raumkarte.kurve` rechnet
    Stücke vor und die Ansicht malt jedes Stück einzeln
    (`Zustand/Raumkarte.swift:78-98`, benutzt in `Seiten/Haus/Raumkachel.swift:237` und dort
    Stück für Stück gemalt).
    Denselben Weg nehmen, nicht Charts.
  * **Der Puls des Alarms.** `dch-pulse .7s infinite` (`globals.css:464`) hat in SwiftUI kein
    Gegenstück ohne Dauerzeichnung. Im Projekt pulst das Glasmodell über
    `TimelineView(.periodic(from:by:))` und zeichnet nur, wenn es etwas zu zeigen gibt
    (`Haus3D/Glasmodell.swift:68-78`, mit Begründung: „Das Bild atmet, aber nur viermal in der
    Sekunde"). Für einen Block reicht `withAnimation(.easeInOut.repeatForever())` auf der
    Deckkraft des Rahmens – aber nur im Zustand `ausgeloest`, sonst läuft eine Animation
    dauerhaft auf einer Wandanzeige.
  * **Der Fokus im Modell.** Das Dimmen der Schilder (`globals.css:487`) braucht einen Zustand
    *im* `Glasmodell`, das heute nur `tippeRaum` nach außen gibt
    (`Haus3D/Glasmodell.swift:36`). Die Schilder sind bereits ein eigener Zweig
    (`schilder(maß:)`, `Glasmodell.swift:82-84`) und für Finger durchlässig – dort lässt sich
    die Deckkraft je Raum ansetzen, ohne die Trefferprüfung (`raumBei`, Zeile 130) anzufassen.
