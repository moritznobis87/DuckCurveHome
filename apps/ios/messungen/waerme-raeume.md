========================= messen:waerme-raeume   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt.

Einstieg `struct HeizkreiseSeite: View` in `DuckCurveHome/Seiten/Technik/SystemSeiten.swift:10`.
Der Kopf kommt aus dem Gerüst, nicht aus der Seite: `Berichtsseite`
(`DuckCurveHome/Seiten/Bericht.swift:15`) setzt `Seite(zeitraum: Zeitraumleiste(...))`
(`Bericht.swift:35`), und der Reiter trägt Namen und Kicker
(`DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:210-211`: `name: "Heizkreise"`,
`spannen: [.tag]`, `kicker: "Einzelraumregelung · Abweichung vom Ziel über den Tag"`).

1. Zeitraumleiste. Nur der Datumskasten, keine Spannenwahl - `welche.count > 1` ist bei
   `[.tag]` falsch (`DuckCurveHome/App/Seitenwahl.swift:241-249`). Im Kasten `‹`, der kurze
   Tag, `›` (abgeschaltet am laufenden Tag, `Seitenwahl.swift:313-315`) und „HEUTE", wenn man
   nicht heute ist (`Seitenwahl.swift:320-333`).
2. Störung des Tagesverlaufs, falls `/rooms/history` scheitert - aus dem Gerüst
   (`Bericht.swift:36-38`).
3. Störung der Istwerte, falls `/rooms` scheitert, mit Knopf „Erneut"
   (`SystemSeiten.swift:28-30`).
4. Hinweis „Die Räume heißen hier nach ihrer Kennung …", wenn `live?.named == false`
   (`SystemSeiten.swift:34-43`).
5. Entweder Karte mit `Leer(satz: "Keine Räume", dazu: …)`, wenn `verlauf.rooms` leer ist
   (`SystemSeiten.swift:44-51`) - oder:
6. Karte „Abweichung im Tagesverlauf" mit dem Erklärsatz als `beiwerk` und
   `Abweichungsmatrix` (`SystemSeiten.swift:58-74`,
   `DuckCurveHome/Bausteine/Abweichungsmatrix.swift:20`): je Raum eine Zeile aus Name
   (rechtsbündig, 128 pt, am Telefon 76), `Canvas` mit einem Feld je Viertelstunde (20 pt hoch,
   2 pt Lücke, am Telefon 1), und rechts das Tagesmittel in 62 pt
   (`Abweichungsmatrix.swift:56-78`); darunter die Achse 00/06/12/18/24 und das Wort „Mittel"
   (`Abweichungsmatrix.swift:112-128`).
7. Karte „Die Räume als Tabelle" (`SystemSeiten.swift:75-77`) mit `Tabelle`
   (`Bericht.swift:165`), Spalten Ist, Ziel, Abweichung (farbig), Etage, Ventil am Tag, Kreise,
   `immerSichtbar: 3` (`SystemSeiten.swift:105-129`).
8. Schlusssatz „Geregelt wird auf Sollwert plus Versatz …" in 11,5 pt `text3`
   (`SystemSeiten.swift:81-94`) - nur im else-Zweig, also nur wenn es Räume gibt.
9. Nachladen der Istwerte alle 30 s, solange der laufende Tag gezeigt wird
   (`SystemSeiten.swift:134-146`, `Raumabweichung.liveTakt`).


VORLAGE:

Einstieg `apps/web/src/app/waerme/raeume/page.tsx:1-8` - die Seite ist ein Aufruf von
`RoomsReport`. `RoomsReport` selbst ist neun Zeilen
(`apps/web/src/components/rooms/RoomsReport.tsx:597-604`) und setzt
`Raumteile anchor={anchor} kacheln={false} auswertung`. **Das ist die wichtigste Zeile der
Messung:** `kacheln={false}` schaltet auf dieser Route die Raumkacheln, die Legende, die
Automatik und das Stellfenster ab. Was von `Raumteile` (`RoomsReport.tsx:297`) übrig bleibt,
steht unten; die Kachelbausteine `Legende` (`:44`), `VentilStreifen` (`:77`), `Verlauf`
(`:122`), `RaumKachel` (`:170`), `Stellen.tsx`, `Automatik.tsx` gehören zu `/haus` und sind
hier **nicht** zu bauen. Der Kommentar dazu steht in der Vorlage selbst
(`RoomsReport.tsx:286-296`): seit dem 11.11.2026 stehen die Kacheln im Bereich Haus und die
Auswertung unter Technik, vorher zeigten beide dasselbe.

  * **Seitenhülle** `ReportShell` (`apps/web/src/components/reports/ReportShell.tsx:97`,
    aufgerufen `RoomsReport.tsx:600`)
    `title="Heizkreise"`, `kicker="Einzelraumregelung · Abweichung vom Ziel über den Tag"`,
    `showPeriods={false}`. Der Titel steht nicht im Kopf, nur als `sr-only`
    (`ReportShell.tsx:99-100, 127`); sichtbar ist der Kicker über `AreaShell`
    (`apps/web/src/components/layout/AreaShell.tsx:26`). Rechts der Blätterkasten: `‹` / Anker
    / `›` in einem Rahmen `border-line-2`, 4 px Radius, Anker `min-w-[190px]` mono 12 px
    `text-1`, Knopf „heute" nur wenn nicht heute, 11 px Versalien `tracking-[.08em]` in
    `--amber` (`ReportShell.tsx:109-117`). Der Spannenschalter ist `hidden`
    (`ReportShell.tsx:120`).
    `usePeriod("day")` hält Spanne und Anker in der Adresse (`?period=&anchor=`,
    `ReportShell.tsx:61-95`). `›` ist **nicht** abgeschaltet: die Vorlage lässt in die Zukunft
    blättern (`ReportShell.tsx:115`, `shift()` `:19-26`).
    Handy: `.report-nav` verliert Rand, bekommt 11 px Radius, `rgba(255,255,255,.07)`,
    `min-height: 40px`, Knöpfe 34×34 bei 16 px; der Anker schaltet von der langen auf die
    kurze Schreibweise um (`handy.css:155-160`, `.report-anchor-lang { display:none }`).
    DATEN: keine.

  * **Fehlerband** `ErrorBanner` (`ReportShell.tsx:147-153`, gesetzt `RoomsReport.tsx:422`)
    Text wörtlich: „Die Raumwerte konnten nicht geladen werden." (`RoomsReport.tsx:334`).
    mono, 12 px, Versalien, `tracking-[.1em]`, Rand `rgba(224,83,61,.4)`, Fläche
    `rgba(224,83,61,.12)`, Schrift `var(--alert)`, 3 px Radius, Polster 16/12. **Kein Knopf.**
    Steht nur für den Fehlschlag von `/rooms`; `/rooms/history` scheitert still
    (`RoomsReport.tsx:353-355`: `setTag(null)`).
    DATEN: `GET /rooms`.

  * **Hinweis ohne Namen** `Note` (`RoomsReport.tsx:431-436`)
    Bedingung `live && !live.named && raeume.length > 0`. Text wörtlich: „Die Räume heißen
    hier nach ihrer Kennung in der Heizungsregelung. Die Namensliste kommt als eigene Meldung
    der Brücke und steht nach ihrem nächsten Start zur Verfügung."
    `Note` ist `<p>` 12 px, `leading-[1.55]`, `max-w-[90ch]`, `text-3`
    (`ReportShell.tsx:144`).
    DATEN: `/rooms` → `named`, `rooms`.

  * **„Keine Räume"** (`RoomsReport.tsx:438-446`)
    Bedingung `raeume.length === 0`. `Card` mit `style={{ padding: 20 }}`, darin `CardHead
    title="Keine Räume"` - ein `<h2 class="kicker">`, also mono 13 px, `letter-spacing:.13em`,
    Versalien, `--text-kicker` = `--mist` `#7fa3b3` (`globals.css:57-64`,
    `apps/web/src/components/ui/Card.tsx:20-28`, `tokens.css:15,35`). Darunter `<p>` 13 px
    `text-2`, `max-w-[70ch]`: „Es liegen keine Werte der Einzelraumregelung vor. Die Brücke
    liest sie, sobald in ihrer Konfiguration die Adresse des Controme-Servers eingetragen
    ist."
    **`raeume` ist nicht `tag.rooms`** (`RoomsReport.tsx:383-408`): am laufenden Tag
    `live.rooms`, an einem vergangenen Tag aus der Tagesreihe nachgebaut, mit dem letzten
    gemessenen Fenster. Die Karte kommt also nur, wenn *diese* Liste leer ist - nicht, wenn
    die Tagesreihe leer ist.
    DATEN: `/rooms`, sonst `/rooms/history`.

  * **Karte „Abweichung im Tagesverlauf"** (`RoomsReport.tsx:476-511`)
    Bedingung `auswertung && matrix.length > 0`, und `matrix` kommt allein aus `tag.rooms`
    (`RoomsReport.tsx:411-418`). `Card style={{ padding: "18px 20px 16px" }}` - inline, also
    **auch am Telefon** (die Regel `.card { padding: 14px }` in `globals.css:333` verliert
    gegen das Attribut). `CardHead title` = Kicker „Abweichung im Tagesverlauf", `right` als
    Zeichenkette, darum einzeilig abgeschnitten (`Card.tsx:26`, `truncate`):
    „Je Raum und Viertelstunde die Abweichung vom Zielwert. Der Raum, der zuerst abfällt,
    bestimmt die nötige Vorlauftemperatur für alle."
    Gitter `.rooms-matrix` `mt-3`, Zeilen `gap-[3px]`; je Zeile `gap-2.5` (10 px):
      - Name: `.rooms-matrix-label` 128 px (`globals.css:116`), am Telefon 76 px
        (`globals.css:352`), rechtsbündig, 12 px, `text-2`, `truncate`.
      - Felder: `.rooms-matrix-cells` `gap: 2px` (`globals.css:117`), am Telefon `gap: 1px`
        und `min-width: 240px` (`globals.css:353`); je Feld `flex 1 1 0`, `height: 20`,
        `borderRadius: 2`.
        Füllung in dieser Reihenfolge (`RoomsReport.tsx:491`): künftig → `NOCH_NICHT`
        `rgba(255,255,255,.035)` (`palette.ts:38`); kein Wert → `KEIN_WERT`, eine Schraffur
        `repeating-linear-gradient(135deg, rgba(255,255,255,.10) 0 3px, transparent 3px 6px)`
        **ohne Grundfüllung** (`palette.ts:29-30`); sonst `farbe(d)` aus den fünf Stufen
        (`palette.ts:12-23`): `--dev-cold-2 #6fd0f2` unter −1,5; `--dev-cold-1 #3f88a8` bis
        −0,5; `--dev-null #3a5560` bis +0,5; `--dev-warm-1 #a8781f` bis +1,5; `--dev-warm-2
        #ffc247` darüber (`tokens.css:72-76`).
        `title` je Feld: `${z.name} · ${hhmm(ts[i])} · ${kuenftig ? "noch nicht" : d == null ?
        "kein Messwert" : kelvin(d)}` (`RoomsReport.tsx:490`). **Das ist die einzige Stelle,
        an der die Zahl eines Feldes zu lesen ist.**
      - Mittel: `w-[62px]`, rechtsbündig, mono 11 px, **immer `text-3`**, `kelvin(schnitt)`
        oder „-" (`RoomsReport.tsx:495`).
    Achse (`RoomsReport.tsx:498-508`): leerer Platzhalter in Namensbreite, dann 00/06/12/18/24
    mit `justify-between`, mono 10 px `text-3`; das „:00" steckt in `<span class="nur-breit">`
    und fällt am Telefon weg (`handy.css:384`). Rechts das Wort „Mittel" in 62 px.
    Die Karte rollt notfalls für sich: `.rooms-matrix { max-width:100%; overflow-x:auto }`
    (`globals.css:177`).
    Grenze „noch nicht": `bisMs` ist am laufenden Tag `new Date(live.at)`, sonst
    `Date.now()`, an jedem anderen Tag `+Infinity` (`RoomsReport.tsx:367-373`). Der Kommentar
    nennt den Grund: **die Uhr des Servers, nicht die des Browsers** - im Vorführbetrieb läuft
    sie im Zeitraffer.
    Werte: `abweichungen(s)` = `temp_c[i] - (setpoint_c[i] + (offset_k[i] ?? 0))`, und ohne
    Sollwert kein Zielwert (`logic.ts:60-72`).
    DATEN: `GET /rooms/history?day=&step_min=15` → `ts`, `step_min`, `rooms[].{id,name,temp_c,
    setpoint_c,offset_k}`; `GET /rooms` → `at`.

  * **Karte „Die Räume als Tabelle"** (`RoomsReport.tsx:513-547`)
    Bedingung `auswertung && raeume.length > 0`. Gleiche Kartenpolsterung, `CardHead title="Die
    Räume als Tabelle"` ohne `right`. `<table class="w-full border-collapse text-[13px]">`,
    `.rooms-table mt-3`.
    Kopfzeile `text-left text-text-3 font-medium`, je Zelle `border-b border-line-1`,
    `px-2 py-1.5`: **Raum | Etage | Ist | Ziel | Abweichung | Ventil am Tag | Kreise**, dabei
    Raum und Etage linksbündig, die fünf übrigen `text-right` (`RoomsReport.tsx:519-525`).
    Zeilen (`:529-543`): Raum = `r.name`; Etage = `r.floor || "-"` in `text-3`; Ist =
    `celsius(r.temp_c, 1)` oder „-", mono; Ziel = `celsius(r.target_c ?? r.setpoint_c, 1)`,
    mono, `text-2`, mit `title="Sollwert …, Offset …"`; Abweichung = `kelvin(r.deviation_k)`
    oder „-", mono, **ohne Farbe**; Ventil am Tag = `anteilText(mittel(serie.valve))`, mono;
    Kreise = `r.circuits || "-"`, mono `text-3`.
    `kelvin` = Vorzeichen (echtes Minus U+2212), eine Nachkommastelle, schmales Leerzeichen,
    „K" (`palette.ts:56-58`). `anteilText` = „kein Messwert" / „zu" / ganze Prozent
    (`palette.ts:104-108`).
    Handy-Fassung: die Tabelle rollt grundsätzlich (`globals.css:177`) und hat 560 px
    Mindestbreite (`globals.css:354`) - **aber `handy.css` nimmt genau das zurück**:
    `.rooms-table table { min-width: 0 }`, `th/td:nth-child(2)` und `:nth-child(n+6)`
    `display: none`, alles `white-space: nowrap` (`handy.css:376-379`, mit dem Kommentar „Die
    Tabelle der Räume zeigt am Handy vier Spalten: Raum, Ist, Ziel, Abweichung."). Etage,
    Ventil am Tag und Kreise fallen am Telefon also weg, und Ist/Ziel/Abweichung stehen
    nebeneinander, weil die dritte Zahl die Differenz der beiden anderen ist.
    Dazu `handy.css:185`: `.card-head-right` nimmt die ganze Breite, 13 px, `line-height 1.4`,
    `white-space: normal` - der Erklärsatz der Matrixkarte bricht am Telefon um statt
    abzuschneiden.
    DATEN: `/rooms` am laufenden Tag (`rooms[].{name,floor,temp_c,target_c,setpoint_c,offset_k,
    deviation_k,circuits}`), sonst der letzte gemessene Stand aus `/rooms/history`;
    „Ventil am Tag" **immer** aus `/rooms/history` → `rooms[].valve`.

  * **Schlusssatz** `Note` (`RoomsReport.tsx:549-557`)
    **Ohne Bedingung** - er steht auch unter „Keine Räume". Wörtlich, mit `<strong>` auf
    „Sollwert plus Offset":
    „Geregelt wird auf **Sollwert plus Offset** - Controme rechnet das in seiner eigenen
    Oberfläche vor und zeigt das Ergebnis als Zieltemperatur. Der Offset ist dabei die Summe
    mehrerer benannter Anpassungen, nicht nur der Witterung; die beiden Zahlen stehen deshalb
    einzeln unter dem Zielwert. Die Antriebe am Verteiler sind auf oder zu - ein Zwischenwert
    im Streifen heißt „ein Teil der Kreise" oder „einen Teil des Fensters", nicht „halb
    offen". Ein Tippen auf eine Kachel stellt den Sollwert dieses Raums, dauerhaft und in
    halben Grad; die Ventile bleiben Sache des Reglers."
    Der Satzteil „die beiden Zahlen stehen deshalb einzeln unter dem Zielwert" spricht über die
    Kachel und gilt auf dieser Route nicht.
    DATEN: keine.

  * **Protokollkasten** (`RoomsReport.tsx:574-586`, Zustand `:308-321`)
    Auch auf dieser Route gebaut, denn er hängt nicht an `kacheln`. Geöffnet wird er allein
    über die Adresse: `?protokoll=<id>` beim Erscheinen gelesen (`:310-314`) und bei jeder
    Änderung mit `history.replaceState` zurückgeschrieben (`:316-321`) - ausdrücklich
    `replaceState` und nicht `push`, „damit ein Befund zu verlinken ist" und die Zurück-Taste
    frei bleibt. Einen Knopf dafür gibt es hier nicht, der sitzt an der Kachel
    (`:272-279`). Inhalt: Kurve und Zeitleiste der letzten 24/48 h
    (`rooms/Protokoll.tsx:10-41`).
    DATEN: `GET /rooms/{id}/log`.

  * **Takte** (`RoomsReport.tsx:38, 329-345, 347-360`)
    `/rooms` sofort und dann alle 30 000 ms, **nur am laufenden Tag** (`LIVE_MS`, Begründung im
    Kommentar: Controme fragt seine Fühler alle zwei Minuten ab, die Fühler melden alle drei
    bis fünf). `/rooms/history` bei jedem Wechsel des Ankers, einmal, mit `STEP_MIN = 15`.
    `proStunde` kommt aus `tag.step_min`, nicht aus der Konstante (`:366`) - „wenn die
    Schnittstelle eines Tages eine andere Breite liefert".

  * **Nicht auf dieser Route** (nachgesehen, damit der Bauplan es nicht baut):
    `Legende` nur bei `kacheln` (`RoomsReport.tsx:426`), `Automatik` nur bei `kacheln`
    (`:474`), `Stellen` nur über `onStellen`, das nur in der Kachelschleife gesetzt wird
    (`:464`), die Etagengruppen samt `etagenText` nur bei `kacheln` (`:448-470`).
    Gesucht nach `.rooms-matrix` in `apps/web/src/styles/handy.css`: kein Treffer - die Matrix
    behält am Telefon ihre Maße aus `globals.css:352-353`.


LUECKEN:

  [traegt-die-seite] Die Hauptkarte gibt keine einzige Zahl her. In der Vorlage trägt jedes der
    96 Felder je Raum einen Hinweis „Raum · hh:mm · ±x,x K" bzw. „kein Messwert" / „noch nicht"
    (`RoomsReport.tsx:490`); in der App ist die Matrix ein `Canvas` ohne Gestik, und die einzige
    Zahl der Karte ist das Tagesmittel je Zeile (`Abweichungsmatrix.swift:68-76`). Die Frage der
    Seite ist „wie weit und wann", und davon bleibt am Gerät nur „wie weit, in fünf Stufen".
    Gesucht nach `DragGesture`, `gesture`, `onTapGesture` und `accessibilityValue` in
    `DuckCurveHome/Bausteine/Abweichungsmatrix.swift`: kein Treffer.

  [traegt-die-seite] Leere Tagesreihe löscht die ganze Seite, auch wenn Räume gemeldet sind.
    Die App entscheidet an `verlauf.rooms.isEmpty` (`SystemSeiten.swift:44`) und zeigt dann
    „Keine Räume" - Matrix *und* Tabelle *und* Schlusssatz fallen weg. Die Vorlage trennt die
    beiden Bedingungen: Matrix an `tag.rooms` (`RoomsReport.tsx:476`), Tabelle und „Keine
    Räume" an `raeume` (`:438`, `:513`), und `raeume` ist am laufenden Tag `live.rooms`
    (`:383-384`). Meldet `/rooms` zehn Räume und `/rooms/history` noch keine Reihe (frische
    Brücke, erster Tag, Reihe noch nicht geschrieben), steht im Browser die vollständige
    Tabelle und in der App der Satz „Es liegen keine Werte der Einzelraumregelung vor" - eine
    falsche Auskunft. Der Kern kann es schon: `tabellenzeilen(live:tag:istHeute:)` liefert mit
    `tag: nil` die Zeilen aus den Istwerten (`Raumbild.swift:163-174`, geprüft in
    `DuckCurveKit/Tests/DuckCurveKitTests/RaumbildTests.swift:165`). Es ist allein die
    Verzweigung der Ansicht.

  [spuerbar] Die Abweichungsspalte der Tabelle ist in der App farbig, in der Vorlage nicht.
    App: `farben: zeilen.map { … Marken.abweichungsfarbe(kelvin:) }` (`SystemSeiten.swift:115-117`).
    Vorlage: die Zelle hat keine Farbangabe und erbt `text-1` (`RoomsReport.tsx:538`); die fünf
    Stufen sind dort Flächenfarben der Matrix, nicht Schriftfarben. Das ist nicht nur ein
    Unterschied, sondern schlecht lesbar: `abwNull` `#3A5560` auf `flaeche1` `#0F2E3D`
    (`Marken.swift:148`, `:28`) ergibt rund 1,8:1 - und „am Ziel" ist die häufigste Zeile.

  [spuerbar] Der Schlusssatz steht in der App nur, wenn es Räume gibt. Er liegt im else-Zweig
    (`SystemSeiten.swift:81-94`), in der Vorlage ohne jede Bedingung unter der leeren Karte
    (`RoomsReport.tsx:549`). Wer die Seite ohne Räume öffnet, erfährt nicht, was hier
    überhaupt gemessen wird.

  [spuerbar] Spaltenreihenfolge am iPad. Vorlage: Raum | Etage | Ist | Ziel | Abweichung |
    Ventil am Tag | Kreise (`RoomsReport.tsx:519-525`). App: Ist | Ziel | Abweichung | Etage |
    Ventil am Tag | Kreise (`SystemSeiten.swift:109-125`). Die Umstellung war für das Telefon
    richtig (`handy.css:376-379`), aber `Tabelle.immerSichtbar` hält die **ersten** n Spalten
    fest (`Bericht.swift:256-258`), und darum wandert die Etage auch an der Wand nach hinten.

  [klein] Die Mittel-Spalte färbt sich. Vorlage immer `text-3` (`RoomsReport.tsx:495`), App
    `text1`, sobald ein Wert dasteht (`Abweichungsmatrix.swift:75`). Damit wiegt die
    Nebenzahl am Rand so schwer wie die Namen.

  [klein] Die Namensspalte der Tabelle hat keine Überschrift. Vorlage „Raum"
    (`RoomsReport.tsx:519`), `Tabelle` setzt dort `Text("")` (`Bericht.swift:433`, `:312`).

  [klein] Die Etagenzelle steht falsch. Vorlage linksbündig in `text-3`
    (`RoomsReport.tsx:535`), App rechtsbündig in `text1` - `Tabelle` kennt für Zahlenspalten
    nur rechts (`Bericht.swift:452-458`) und färbt ohne Angabe `text1` (`:494-499`).

  [klein] Die Schraffur ist heller als die Vorlage. Vorlage: Striche
    `rgba(255,255,255,.10)`, 3 px breit, 3 px Lücke, **keine Grundfüllung**
    (`palette.ts:29-30`). App: Grundfüllung `white 0.04` und Striche `white 0.18` bei 0,8 pt
    Breite im Abstand 3 (`Abweichungsmatrix.swift:98-107`). Nebeneinander liest die App-Lücke
    sich als eigene Farbe statt als „gehört nicht zur Skala".

  [klein] „Keine Räume" hat nicht die Gestalt der Vorlage. Dort ein `CardHead`, also ein
    Kicker in mono, Versalien, `letter-spacing .13em`, `--mist`, und darunter 13 px in `text-2`
    mit `max-w-[70ch]` (`RoomsReport.tsx:439-445`, `Card.tsx:20-28`, `globals.css:57-64`). In
    der App ein `Leer`: Satz 13 pt `text-2`, Zusatz 11,5 pt `text-3`, kein Kicker
    (`DuckCurveHome/Gestalt/Karte.swift:390-404`).

  [klein] Der Schlusssatz hat keine Hervorhebung und keine Zeilenbegrenzung. Vorlage: `<strong>`
    auf „Sollwert plus Offset" (`RoomsReport.tsx:550`) und `max-w-[90ch]` mit
    `leading-[1.55]`, ausdrücklich begründet (`ReportShell.tsx:136-144`: über die volle Breite
    eines 1440er Schirms findet das Auge die nächste Zeile nicht wieder). App: durchgehend
    `Schrift.winzig`, `lineSpacing(2)`, keine Breitengrenze (`SystemSeiten.swift:91-94`) - an
    der Wandanzeige also eine Zeile über die ganze Karte.

  [klein] `step_min` der Antwort wird nicht gelesen. Die App rechnet die Grenze „noch nicht"
    immer mit 15 Minuten: `gewesen(tag:jetzt:)` ohne `schrittMin`
    (`SystemSeiten.swift:72`, Voreinstellung `Raumabweichung.swift:89`), obwohl
    `RoomHistoryOut.stepMin` dasteht (`Schema.swift:8198`). Die Vorlage nimmt
    `tag.step_min ?? STEP_MIN` (`RoomsReport.tsx:366`).

  [klein] `live.at` bleibt ungenutzt. Die Vorlage zieht die Grenze „bis wohin gemessen ist"
    aus der Antwort (`RoomsReport.tsx:370-373`, Feld vorhanden: `Schema.swift:8685`); die App
    nimmt die Hausuhr (`SystemSeiten.swift:72` → `Hauszustand.swift:96-98`, Versatz aus dem
    Ereignisstrom `Hauszustand.swift:214-218`). Dieselbe Uhr - aber ohne Ereignisstrom
    (Erstladung, Vorschau ausgenommen) steht der Versatz auf 0, und dann ist es die Geräteuhr.

  [klein] Der Protokoll-Tieflink fehlt. Die Vorlage öffnet den Kasten auch auf dieser Route,
    wenn `?protokoll=<id>` in der Adresse steht (`RoomsReport.tsx:310-321, 574-586`). Das Blatt
    gibt es in der App (`DuckCurveHome/Seiten/Haus/Raumprotokollblatt.swift:15`,
    `Api.raumProtokoll` `Api.swift:230`), erreichbar nur über die Raumliste
    (`DuckCurveHome/Seiten/Haus/HausSeite.swift:77`).

  [klein] Das Fehlerband sieht anders aus und sagt anderes. Vorlage: mono, Versalien,
    `tracking-[.1em]`, Alarmrot, **ohne Knopf**, Text „Die Raumwerte konnten nicht geladen
    werden." (`ReportShell.tsx:147-153`, `RoomsReport.tsx:334`). App: `Stoerung` mit
    Warnzeichen, dem Rat des `ApiFehler`, dem Code und einem Knopf „Erneut"
    (`Karte.swift:419-464`, gesetzt `SystemSeiten.swift:28-30`). Der Knopf ist ein Zugewinn und
    soll bleiben; die Gestalt (Band in Alarmrot statt Kasten in `flaeche2`) nicht.

  (Zusammen 15 Punkte: 2 traegt-die-seite, 3 spuerbar, 10 klein.)

  Nicht als Lücke gezählt, aber festzuhalten:
  * `›` ist in der App am laufenden Tag abgeschaltet (`Seitenwahl.swift:313-315`), in der
    Vorlage nicht (`ReportShell.tsx:115`). Dadurch ist der einzige Fall, in dem
    `gewesen(...)` 0 liefert und die App einen künftigen Tag blass statt schraffiert zeichnen
    würde (`Raumabweichung.swift:92`), am Gerät nicht erreichbar. Die App ist hier strenger;
    beim Umbau nicht „zurückbauen".
  * Ziel am laufenden Tag: die Vorlage fällt auf den nackten Sollwert zurück
    (`r.target_c ?? r.setpoint_c`, `RoomsReport.tsx:537`), die App rechnet Sollwert plus
    Versatz, wenn `target_c` fehlt (`Raumbild.swift:167`). Die App ist richtiger, und der
    Kommentar der Vorlage selbst sagt, warum (`RoomsReport.tsx:221-224`). Nicht angleichen.
  * Was `ABGLEICH.md:701` behauptet - „Die iOS-Seite ruft nur api.raeumeTag; api.raeume()
    bleibt auf dieser Seite ungenutzt" - stimmt nicht mehr: `holeLive` ruft `haus.api.raeume()`
    (`SystemSeiten.swift:137`) und zieht am laufenden Tag alle 30 s nach (`:143-144`). Auch
    der Hinweis bei `named == false` steht (`:34-43`). Nachgesehen, nicht abgeschrieben.


KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Api.raeume() -> RoomsLiveOut` → `GET /rooms`
    (`DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:221-223`).
  * `Api.raeumeTag(_:schrittMin:) -> RoomHistoryOut` → `GET /rooms/history?day=&step_min=`
    (`Api.swift:225-227`).
  * `Api.raumProtokoll(_:stunden:schrittMin:) -> RoomLogOut` (`Api.swift:230-232`).
  * `RoomHistoryOut { start, end, stepMin, ts: [String], rooms: [RoomSeriesOut] }`
    (`Schema.swift:8195-8200`).
  * `RoomSeriesOut { id, name, floor, circuits, tempC, setpointC, offsetK, valve, window }`,
    alle Reihen `[Double?]` (`Schema.swift:8402-8411`).
  * `RoomsLiveOut { at: String, named: Bool, rooms: [RoomLiveOut] }` (`Schema.swift:8684-8687`).
  * `RoomLiveOut` mit `tempC`, `setpointC`, `offsetK`, `targetC`, `deviationK`, `circuits`,
    `floor` (`Schema.swift:8240`).
  * `Raumabweichung.band = 0.5` (`Raumabweichung.swift:15`), `Feld` mit den drei Fällen
    (`:23-29`), `ziel(soll:versatz:)` (`:37-40`), `felder(ist:soll:versatz:bisStelle:)`
    (`:46-58`), `mittel(_:)` (`:61-68`), `stufe(_:)` mit den Grenzen der Vorlage (`:76-82`),
    `gewesen(tag:jetzt:schrittMin:)` (`:89-95`), `kelvin(_:)` (`:102-105`),
    `abweichungText(_:)` (`:111-114`), `anteilText(_:)` (`:135-139`), `ventilText(_:kreise:)`
    (`:121-128`).
  * `Raumabweichung.liveTakt = .seconds(30)` (`Raumbild.swift:111`),
    `tabellenzeilen(live:tag:istHeute:)` (`Raumbild.swift:155-187`), `letzterStand(reihe:)`
    (`:125-137`), `anteilMittel(_:)` (`:200-204`), Typen `Raumzeile` (`:64-102`) und
    `Raumstand` (`:22-51`).
  * `Marken.abweichungsfarbe(kelvin:)` und `Marken.abweichung` - die fünf Stufen in genau den
    Werten von `tokens.css:72-76` (`Marken.swift:146-150`, `:357`, `:360-369`).
  * `Marken.ventilOffen = #CFD8DC` = `--valve-open` (`Marken.swift:154`, `tokens.css:79`) -
    auf dieser Route nicht gebraucht, gehört zum Ventilstreifen der Kachel.
  * `Formate.celsius(_:stellen:)` (`Formate/Formate.swift:104-107`), `Formate.hhmm(iso:)`
    (`:262-265`), `Formate.leer = "-"` (`:27`), `Formate.minus` (`:25`),
    `Formate.schmalesLeerzeichen` (`:23`).
  * `Bereiche`: Reiter mit Name, Kicker und `spannen: [.tag]`
    (`Bereiche/Bereiche.swift:210-211`).
  * Vorbild für das Ablesen in einem selbstgezeichneten Zellenraster:
    `Jahresraster.Zellenhinweis` und `Jahresraster.hinweis(tag:stunde:)`
    (`Zustand/Jahreskarte.swift:216`, `:242`), gezeichnet und abgelesen in
    `DuckCurveHome/Diagramme/Jahresflaeche.swift:83-85`, `:126-131`, `:139-145`.


ES FEHLT:

  1. `Raumabweichung.feldwort(_ feld: Feld) -> String` in
     `DuckCurveKit/Sources/DuckCurveKit/Zustand/Raumabweichung.swift`, neben
     `abweichungText(_:)` (`:111`): `.nochNicht` → „noch nicht", `.keinWert` →
     „kein Messwert", `.wert(k)` → `kelvin(k)`. **Nicht `abweichungText` nehmen:** das sagt
     innerhalb des Bandes „am Ziel", die Vorlage setzt im Feldhinweis die Zahl
     (`RoomsReport.tsx:490`). Beides ist richtig, aber an verschiedenen Stellen.

  2. `Raumabweichung.Feldhinweis` und
     `Raumabweichung.feldhinweis(name: String, zeitIso: String?, feld: Feld) -> Feldhinweis`,
     ebenfalls in `Raumabweichung.swift`: drei Zeichenketten (Raum, `Formate.hhmm(iso:)`,
     `feldwort`) für das Blättchen über der Matrix. Vorbild für Zuschnitt und Prüfbarkeit:
     `Jahresraster.Zellenhinweis` / `hinweis(tag:stunde:)`
     (`Zustand/Jahreskarte.swift:216`, `:242`). Die Zeitstempel kommen aus
     `RoomHistoryOut.ts` (`Schema.swift:8198`), die Ansicht gibt also Name, `ts[i]` und das
     Feld hinein und bekommt die Zeilen heraus - gerechnet wird nichts in der Ansicht.

  3. Nichts weiter. Zahlen, Zeilen, Farben, Grenzen und Worte dieser Route stehen im Kern
     (siehe oben); die übrigen Lücken sind Ansicht und Baustein.


BAUPLAN: Karte für Karte, in der Reihenfolge der Vorlage.

  1. `DuckCurveKit/Sources/DuckCurveKit/Zustand/Raumabweichung.swift` (ändern):
     `feldwort(_:)` und `feldhinweis(name:zeitIso:feld:)` samt `Feldhinweis` anlegen (ES
     FEHLT 1 und 2). Prüfungen dazu in
     `DuckCurveKit/Tests/DuckCurveKitTests/RaumbildTests.swift` - dort stehen die Prüfungen
     der Tabellenzeilen schon (`:146-265`).

  2. `DuckCurveHome/Seiten/Technik/SystemSeiten.swift:44-95` (ändern): die Verzweigung
     auftrennen, wie die Vorlage sie trennt.
       - Zeilen einmal rechnen: `let zeilen = Raumabweichung.tabellenzeilen(live: live,
         tag: verlauf, istHeute: z.anker == haus.heute)`.
       - „Keine Räume" nur bei `zeilen.isEmpty` (Vorlage `RoomsReport.tsx:438`).
       - Matrixkarte nur bei `!verlauf.rooms.isEmpty` (`:476`).
       - Tabellenkarte nur bei `!zeilen.isEmpty` (`:513`).
       - Schlusssatz **aus dem else-Zweig heraus**, auf die Höhe der Hülle, ohne Bedingung
         (`:549`); `frame(maxWidth: 560, alignment: .leading)` als Gegenstück zu `max-w-[90ch]`
         und `Text` mit `+` getrennt, damit „Sollwert plus Versatz" halbfett steht
         (`Schrift` hat `karte` für Halbfett; sonst `AttributedString`).
       - `raumtabelle` nimmt die fertigen `zeilen` als Argument statt sie selbst zu holen.

  3. `DuckCurveHome/Bausteine/Abweichungsmatrix.swift` (ändern): das Ablesen. Vorbild
     `Jahresflaeche.swift:83-85, 126-145`, eins zu eins übertragbar, weil dort wie hier das
     Raster selbst gezeichnet wird und die Umrechnung darum die eigene sein muss.
       - `@State private var gezeigt: Raumabweichung.Feldhinweis?`
       - Je Zeile `.gesture(DragGesture(minimumDistance: 0))` auf dem `Canvas`; aus
         `griff.location.x` über dieselbe Rechnung wie in `male(_:in:groesse:)`
         (`:84-85`) den Index, daraus `feldhinweis(name:zeitIso: verlauf.ts[i], feld:)`.
       - Blättchen über der Zeile, Gestalt wie `Jahresflaeche.blaettchen`
         (`Jahresflaeche.swift:155` ff.: drei Zeilen, im Bild gehalten). **Dort bleibt es nach
         dem Loslassen stehen**, weil ein Tippen darauf weiterführt (`Jahresflaeche.swift:22-25`,
         `gezeigt = nil` erst im `onTapGesture`, `:178-181`). Hier führt nichts weiter, also
         beim Loslassen (`onEnded`) wegnehmen - das ist eine Abweichung vom Vorbild und hat
         ihren Grund.
       - `accessibilityValue` je Zeile mit demselben Wort, damit die Vorlesehilfe die Zahl
         auch ohne Gestik hat; die Vorlage hat dafür `title` je Feld.
       - `schrittMin: verlauf.stepMin` an `gewesen(...)` durchgeben (Lücke `step_min`), also
         `bisStelle` in der Seite aus `Raumabweichung.gewesen(tag: z.anker, jetzt: haus.jetzt,
         schrittMin: verlauf.stepMin)` rechnen (`SystemSeiten.swift:72`).
       - Schraffur auf die Werte der Vorlage: Grundfüllung weg, Striche auf `white 0.10`
         (`:96-107` gegen `palette.ts:29-30`).
       - Mittel-Spalte durchgehend `Farbe.text3` (`:75` gegen `RoomsReport.tsx:495`).

  4. `DuckCurveHome/Seiten/Bericht.swift` (ändern, `struct Tabelle`): die Reihenfolge der
     Spalten von der Auswahl der festen trennen. Heute ist „welche Spalten stehen am Telefon"
     dasselbe wie „welche Spalten kommen zuerst" (`:256-258`). Vorschlag: `var festeSpalten:
     [Int]?` neben `immerSichtbar`, und `feste` liefert diese Liste, wenn sie dasteht. Dazu
     zwei Kleinigkeiten derselben Stelle:
       - Kopfzelle der Namensspalte benennbar machen (`var zeilenspalte: String = ""`,
         gesetzt in `:312`, `:433`, `:373`) - hier „Raum".
       - Eine Spalte linksbündig zulassen (`Spalte.links: Bool = false`), für die Etage
         (`:452-458`), und für sie `Farbe.text3` statt `text1` setzen; `farben` reicht dafür
         schon (`:494-499`).
     Danach in `SystemSeiten.swift:107-129` die Spalten in der Reihenfolge der Vorlage
     aufschreiben (Etage an zweiter Stelle, links, `text3`) und `festeSpalten: [1, 2, 3]`
     setzen - das ist genau, was `handy.css:378` tut.

  5. `DuckCurveHome/Seiten/Technik/SystemSeiten.swift:112-117` (ändern): `farben` der
     Abweichungsspalte entfernen (Vorlage `RoomsReport.tsx:538`). Wer die Abweichung farbig
     sehen will, liest die Matrix darüber - dort ist die Farbe eine Fläche und trägt.

  6. `DuckCurveHome/Gestalt/Karte.swift` (nur falls die „Keine Räume"-Karte angeglichen wird):
     `Leer` um einen Kicker zu erweitern wäre der falsche Ort - stattdessen in
     `SystemSeiten.swift:44-51` `Karte(kicker: "Keine Räume") { Text(…) }` mit `Schrift.klein`
     und `Farbe.text2` setzen; `Karte` zeichnet den Kicker an der Wand gesperrt und am Telefon
     als Überschrift (`Karte.swift:54-83`), was genau dem `CardHead` der Vorlage entspricht.

  7. Fehlerband (`DuckCurveHome/Gestalt/Karte.swift:443-464`, `struct Stoerung`): wenn es
     angeglichen wird, dann für alle Seiten zugleich, nicht hier. Als eigener Punkt notiert,
     nicht Teil dieses Umbaus.

  8. Protokoll-Tieflink: `Wegweiser` um eine Fragestelle `?protokoll=<id>` erweitern und
     `Raumprotokollblatt` (`Seiten/Haus/Raumprotokollblatt.swift:15`) auch von dieser Seite
     aus öffnen. Letzter Punkt der Liste - in der Vorlage ist er auf dieser Route ebenfalls
     nur über einen Link erreichbar.


WAS SCHWIERIG WIRD:

  * **Der Feldhinweis ohne Zeigegerät.** Die Vorlage hängt an jedem der bis zu 96 Felder je
    Raum ein `title` (`RoomsReport.tsx:490`); am Gerät gibt es kein Überfahren. Der im Projekt
    gewählte Weg steht in `DuckCurveHome/Diagramme/Jahresflaeche.swift`: ein selbst
    gezeichnetes Zellenraster, `DragGesture(minimumDistance: 0)` zum Ablesen (`:126-131`), die
    Umrechnung Stelle → Zelle in derselben Rechnung wie das Zeichnen (`:139-145`, mit dem
    Satz „daneben gegriffen heißt: nichts zeigen, nicht das Nächstbeste") und ein Blättchen,
    das im Bild gehalten wird (`:150-155`). Der Kommentar dort nennt auch die Falle: am
    Telefon ist der ablesende Finger derselbe, mit dem gerollt würde
    (`Jahresflaeche.swift:17-20`). Die Matrix steht in einer Karte in einer rollenden Seite -
    also `minimumDistance: 0` auf dem `Canvas` und nichts mit senkrechter Richtung.
  * **Kein Gegenstück zu `truncate` im Kartenkopf.** Die Vorlage schneidet den Erklärsatz der
    Matrixkarte an der Wand auf eine Zeile ab (`Card.tsx:26`) und lässt ihn am Telefon
    umbrechen (`handy.css:185`). In der App steht er als `beiwerk` und bricht immer um
    (`SystemSeiten.swift:60-68`). Das ist kein Fehler, aber es verschiebt die Kartenhöhe
    gegenüber der Vorlage; `Karte` hat für `beiwerk` keine Breitengrenze (`Karte.swift:79-81`).
    Wenn es angeglichen wird, dann über `lineLimit(1)` **nur** bei `!schmal` - und das ist eine
    Änderung an `Karte`, die 23 andere Karten trifft. Besser so lassen und notieren.
  * **Das `Canvas` der Matrix kann nicht rollen.** Die Vorlage gibt den Feldern am Telefon
    `min-width: 240px` und lässt die Karte seitlich rollen (`globals.css:177`, `:353`); das
    `Canvas` schrumpft stattdessen (`Abweichungsmatrix.swift:68-71, 84-85`). Bei 96 Feldern und
    1 pt Lücke bleiben rund 1,4 pt je Feld - in der Vorlage sind es bei 240 px rund 1,5 px, also
    praktisch dasselbe. Kein Umbau nötig; nur nicht „verbessern", indem je Zeile eine eigene
    `ScrollView` entsteht: dann laufen die Zeilen auseinander und die Spalten der Matrix stehen
    nicht mehr untereinander.
  * **Halbfett in einem Fließsatz.** `Schrift` hat keine Auszeichnung innerhalb eines `Text`
    (gesucht nach `fontWeight` und `AttributedString` in
    `DuckCurveHome/Gestalt/Typografie.swift`: kein Treffer). Für das `<strong>` des
    Schlusssatzes ist die Summe zweier `Text` der Weg, den die App sonst nimmt - oder man lässt
    es: ein halbfettes Teilstück in 11,5 pt `text3` trägt wenig.
