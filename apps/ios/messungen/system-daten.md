========================= messen:system-daten   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

Einstieg `struct DatenSeite: View` - `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:613`.
Gerippe `Seite(zeitraum: Zeitraumleiste(spannen: [.tag]))` - `SystemSeiten.swift:633`; damit
nur die Spanne „Tag", also kein Spannenschalter (`Zeitraumleiste` zeichnet `Spannenwahl` erst
ab zwei Spannen, `App/Seitenwahl.swift:247-248`). Kicker der Route
„Messreihen · Stundenbilanz · Rohdaten" aus `DuckCurveKit/Bereiche/Bereiche.swift:224`,
gezeichnet von `Seite.kicker`, am Telefon weggelassen (`Seitenwahl.swift:207`).

1. Störungsband, nur wenn `fehler != nil`: `Stoerung(fehler:)` mit „Erneut" -
   `SystemSeiten.swift:634-636`. Gesetzt wird `fehler` an genau einer Stelle:
   `fehler = abdeckung == nil ? .netz(Abdeckungsraster.nichtAbrufbar) : nil`
   (`SystemSeiten.swift:708`).
2. Karte, Kicker „Leistungen über den Tag", ohne Beiwerk im Kartenkopf -
   `SystemSeiten.swift:637`. Inhalt: `Pruefkurvenbild(kurve:)`, wenn `hatMinuten`, sonst
   `Leer(satz: Pruefkurve.leersatz)` (`SystemSeiten.swift:638-642`).
   `Pruefkurvenbild` (`apps/ios/DuckCurveHome/Diagramme/Pruefkurvenbild.swift:18`) zeichnet
   darin selbst: Kopfzeile mit der Vorzeichenregel und, bei gewähltem Fenster, „Ganzer Tag"
   (`:45-62`); das Bild mit sechs Reihen, hervorgehobener Nulllinie, Stundenachse alle drei
   Stunden, kW links, Ladestand in Prozent rechts, feste Höhe 300 (`:64-116`); Legende als
   `Umbruchzeile` mit gestrichelten Zeichen für die zwei Gegenproben (`:185-206`).
   Zeitfenster über `.chartXSelection(range:)` (`:77`, Bindung `:119-127`); ohne Fenster wird
   jede fünfte Minute gezeichnet (`:24-31`, `Pruefkurve.verdichtet(schrittMin: 5)`).
3. Karte, Kicker „Quellen", Beiwerk „liefert gerade, was liefern soll?" -
   `SystemSeiten.swift:644-650`. Inhalt `Quellenkarte(zeilen: Quellenstand.zeilen(aus:
   haus.zustand?.system))` (`:651`); `Quellenkarte` in `Pruefkurvenbild.swift:214-261`: je
   Zeile Punkt, Name, Satz des Dienstes in einem `HStack`, Fläche `flaeche2` mit Haarlinie;
   ohne Zeilen `Leer(satz: Quellenstand.nichtAbrufbar)` (`:219-220`).
4. Karte, Kicker „Kommen die Daten an? 28 Tage", Beiwerk „Farbe = Minuten je Stunde, 0 bis
   60" - `SystemSeiten.swift:653-662`, **nur wenn** `abdeckung != nil` (`:653`). Inhalt
   `Abdeckungskarte(reihen: Abdeckungsraster.baue(a), jetzt: haus.jetzt)` (`:661`);
   `apps/ios/DuckCurveHome/Diagramme/Abdeckungskarte.swift:27`: je Reihe eine Kopfzeile
   (`:79-92`), Stundenachse links (`:102-114`), das Raster als `Canvas` 28×24 (`:127-147`),
   Tagesachse jeder dritte Tag (`:155-170`), darunter **eine** Farbskala für alle Reihen
   (`:180-196`).
5. Karte, Kicker „Stundenbilanz und auffällige Strecken", ohne Beiwerk -
   `SystemSeiten.swift:669`, **nur wenn** `diagnose` nicht leer (`:664`). Inhalt: der Text des
   Dienstes in `Schrift.zahlKlein`, waagerecht rollbar, markierbar (`:670-675`).
6. `Methode(...)` mit sechs Absätzen in einer zugeklappten Karte - `SystemSeiten.swift:682-687`:
   `Pruefworte.methode` (drei Absätze), `abdeckung?.noteDe`,
   `Abdeckungsraster.lesehilfe`, `Pruefworte.abdeckungssatz`. `Methode` ist ein
   `DisclosureGroup`, Anfangszustand `offen = false`, hier ohne `kurz`
   (`apps/ios/DuckCurveHome/Seiten/Bericht.swift:514-540`).

Nachladen: `.task(id: z) { await lade(z) }` (`SystemSeiten.swift:689`). `lade` holt erst den
Verlauf und wartet darauf (`:693-694`), dann Abdeckung und Diagnose nebenläufig (`:703-707`).


VORLAGE:

  * **Hülle** `ReportShell` (`apps/web/src/components/reports/DataCheck.tsx:58-68`)
    `title="Daten prüfen"`, `kicker="Messreihen · Stundenbilanz · Rohdaten"`,
    `showPeriods={false}`. Der Schalter wird nicht entfernt, sondern versteckt
    (`ReportShell.tsx:120`, `hidden={!showPeriods}`); Begründung als Kommentar
    `ReportShell.tsx:118-119`: „Die Pruefansicht kennt nur Tage: Minutenwerte ueber eine
    Woche zu legen ergaebe ein Bild, in dem man nichts mehr erkennt."
    Blätterkasten: ‹ › in `mono` 13 px, Anker 12 px mit `min-w-[190px]`, „heute" in 11 px
    Großbuchstaben mit `tracking-[.08em]` in `--amber`, nur wenn der Anker nicht heute ist
    (`ReportShell.tsx:109-117`).
    Der Titel steht nur noch in `<span class="sr-only">` und im Dokumenttitel
    (`ReportShell.tsx:127`, Kommentar `:99-100`; `apps/web/src/app/system/daten/page.tsx:4`).
    DATEN: keine; `usePeriod("day")` hält Spanne und Anker in der Adresse
    (`ReportShell.tsx:61-95`).

  * **Störungsband** `ErrorBanner` (`DataCheck.tsx:69`)
    Text genau „Daten konnten nicht geladen werden.", gesetzt **nur**, wenn Verlauf *und*
    Diagnose scheitern (`DataCheck.tsx:41`). Gestalt: `mono`, 12 px, Großbuchstaben,
    `letter-spacing .1em`, Radius 3, Rahmen `rgba(224,83,61,.4)`, Fläche
    `rgba(224,83,61,.12)`, Schrift `var(--alert)` (`ReportShell.tsx:147-153`).

  * **Karte 1 „Leistungen über den Tag"** (`DataCheck.tsx:71-86`)
    Karte mit `padding: 16` und **fester Höhe 480** (`:71`); das Diagramm füllt den Rest
    (`min-h-0 flex-1`, `:80`). Kopfzeile rechts, wörtlich: „Netz + Bezug, − Einspeisung ·
    Speicher + Entladen, − Laden · Ladestand rechts in %" (`:76`). Kommentar `:74-75`: die
    Bedienhinweise stehen deshalb **nicht** hier, sondern im Fließtext - „auf einem Telefon
    ist diese Zeile schon mit der Vorzeichenregel voll und wird abgeschnitten".
    Kommentar `:77`: „gestrichelt = dasselbe, anders gemessen: Ladestand am Speicher, Zähler
    am Netz".
    Zustände: `rows.length > 0` → Diagramm; sonst `<Note>` mit „lädt …", solange `loading`,
    danach „Für diesen Tag liegen keine Minutenwerte vor. Seine Stundenbilanzen stammen dann
    aus dem Historienimport." (`:83`).
    Diagramm `powerOverlay` (`apps/web/src/components/reports/charts.ts:562-776`):
      - Sechs Reihen in dieser Legendenreihenfolge: PV, Haus, Netz, Netz (Zähler), Speicher,
        Ladestand % (`charts.ts:624-631`). Die zwei Gegenproben haben als Legendenzeichen
        zwei Striche statt eines Flecks (`:630-631`, Begründung `:621-623`: dieselbe Farbe,
        zwei gleiche Flecken hoben die Legende auf).
      - Farben aus `charts/palette.ts`: `pv #f2a900`, `house #cfd8dc`, `grid #e0533d`,
        `battery #7fa3b3`. Linien 2 px, die gestrichelten 1,5 px mit `opacity .85`
        (Zähler, `charts.ts:767`) bzw. `.75` (Ladestand, `:778`).
      - Treppen (`step: "end"`) für Netz und Speicher; PV, Haus, Zähler und Ladestand
        stetig (`charts.ts:577`, `:731-733`, `:737`, `:762`, `:776`).
      - PV ist die einzige Fläche, `rgba(242,169,0,.18)` (`charts.ts:732`), und trägt die
        hervorgehobene Nulllinie als `markLine` in `rgba(255,255,255,.4)`
        (`:734`, Begründung `:728-729`: „an ihr entscheidet sich Bezug gegen Einspeisung").
      - Haus ist **gerechnet**: `max(0, pv + grid + (battery ?? 0))`, `null`, sobald PV oder
        Netz fehlt (`charts.ts:572-577`).
      - Zähler: `connectNulls: true`, Punkte sichtbar, `symbolSize 3.5`
        (`charts.ts:760-766`). Begründung `:749-758`: er meldet nur alle rund fünfzehn
        Minuten, mit `connectNulls: false` war „die Reihe vorhanden, vollständig und
        vollkommen unsichtbar"; die Linie ist gerade und keine Treppe, „weil eine Treppe
        behaupten würde, der Wert habe fünfzehn Minuten lang so gestanden".
      - Zweite Achse rechts: Prozent, fest `0...100`, ohne eigene Gitterlinien
        (`charts.ts:713-725`). Begründung `:692-696`: „sonst liefen zwei Gitter mit
        verschiedenen Nullpunkten übereinander, und das war schon einmal der Fehler"; und
        `:697-698`: eine fünfte Farbe gäbe es nicht, „der Palettenprüfer findet zu jedem
        Kandidaten ein Paar unter ΔE 15".
      - Zeitfenster auf drei Wegen (`charts.ts:634-672`): Werkzeug „Zeitfenster aufziehen" /
        „Ein Schritt zurück" / „Ganzer Tag" oben rechts, Regler unter dem Diagramm (Höhe 26,
        `bottom: 30`), Rad und zwei Finger am Zeiger. `filterMode: "filter"`, damit die
        kW-Achse mitgeht (`:656`, `:658`).
      - **Hinweisfenster am Zeiger** (`charts.ts:591-601`): Kopf `hh:mm` in
        `rgba(255,255,255,.6)` mit `letter-spacing .06em`, darunter je Reihe Name in ihrer
        Farbe links und Wert mit **zwei** Nachkommastellen und „kW" rechts; Reihen ohne Wert
        fallen weg.
      - Gitter `left 52, right 56, top 46, bottom 88`; Kommentar `:719-720`: oben 46 statt
        28, weil die „100" der Prozentachse sonst auf der Werkzeugzeile lag.
    DATEN: `api.historyDay(start, end)` über `dayBounds(anchor)` (`DataCheck.tsx:22-25, 38`);
    Felder `ts`, `pv_power_kw`, `grid_power_kw`, `grid_power_meter_kw`, `battery_power_kw`,
    `battery_soc` (`charts.ts:570-576`, `:736`, `:760`, `:770`, `:772-773`).

  * **Karte 2 „Quellen"** (`DataCheck.tsx:91-96`)
    `padding: 16`, Kopfzeile rechts „liefert gerade, was liefern soll?" (`:92`), Inhalt mit
    `mt-3`. Kommentar `:88-90`: „Die Verfügbarkeit steht vor der Bilanz … Und vor der Karte
    steht der Augenblick: sie zählt Stunden und sieht einen Ausfall erst nach einer."
    `Sources` (`apps/web/src/components/reports/Sources.tsx:28-83`):
      - Erste Zeile ist keine Quelle, sondern die Vollmacht „Anforderung an die Wärmepumpe"
        (`:56-67`). Punkt `ok`/`muted`; dahinter `hp_actuation_de` plus, mit „ · " getrennt,
        entweder „zwei Sicherungen liegen im Haus: das Relais schaltet von selbst ab, und
        Home Assistant wacht darüber" oder „der Regler entscheidet, geschaltet wird nichts"
        (`:63-65`). Begründung `:53-55`: „jede andere Zahl auf dieser Seite ist anders zu
        lesen, je nachdem wie sie ausfällt".
      - Je Quelle eine Zeile (`:68-81`): Punkt `ok`/`alert`, Name aus der Tabelle
        `bridge → "Haus (Bridge)"`, `myenergi → "myenergi (Libbi, Wallbox)"`,
        `inexogy → "Zähler (inexogy)"` (`:20-24`), dahinter `detail_de` wörtlich vom Dienst
        (Kommentar `:77-78`).
      - Maße je Zeile: `rounded-[3px]`, Rahmen `--line-1`, Fläche `--surface-2`,
        `px-4 py-3`, `gap-x-3 gap-y-1`, `items-baseline`, umbrechend; Name 14 px `--text-1`,
        Punkt 8×8 px (`Dot.tsx:3`) in `--amber` (ok) / `--alert` (alert) / `--text-3`
        (muted) (`Dot.tsx:2`).
      - **Handy-Fassung:** der Satz des Dienstes trägt `mono w-full … sm:w-auto`
        (`:61`, `:79`), steht also unter 640 px in einer **eigenen Zeile** unter dem Namen,
        13 px, `leading-[1.5]`, `--text-3`. `handy.css:191` hebt 12-px-Text im
        Berichtsbereich auf 13,5 px und `:192` 13-px-Text auf 14,5 px.
      - Zustände: Fehler **und** nichts geladen → „Der Zustand der Quellen ist gerade nicht
        abrufbar."; nichts geladen → „lädt …" (`:48-49`), beide als `<p>` 14 px `--text-3`.
    DATEN: `api.liveState()`, Feld `system.sources` (`name`, `online`, `detail_de`) und
    `system.hp_actuation`, `system.hp_actuation_de`; alle 30 s neu (`:26`, `:40`).

  * **Karte 3 „Kommen die Daten an? 28 Tage"** (`CoverageMap.tsx:104-131`, eingesetzt
    `DataCheck.tsx:98`)
    `padding: 16`, Kopfzeile links `Kommen die Daten an? ${days} Tage`, rechts
    „Farbe = Minuten je Stunde, 0 bis 60" (`:106`); `days` ist standardmäßig 28 (`:83`).
    Je Reihe (`:108-123`) eine Kopfzeile und darunter ein Bild von **240 px** Höhe.
      - Kopfzeile `Headline` (`:65-81`): Name `label_de` 14 px `--text-1`; dann
        `mono` 13 px die Abdeckung als „NN,NN % Abdeckung" - zwei Nachkommastellen über
        99,9 %, sonst eine (`:66`) -, in `--alert` unter 99 %, sonst `--amber` (`:67`, `:71`);
        dann 13 px `--text-3`: „N unvollständige Stunden", nur bei Ausfall
        „ · längster Ausfall N h", und „ · " plus das Alter des letzten Werts (`:74-78`).
        Alter in vier Stufen: „noch kein Wert" / „letzter Wert gerade eben" (< 5 s) /
        „… vor N s" (< 120 s) / „… vor N min" (< 7200 s) / „… vor N h" (`:56-63`).
      - Bild `yearMap` (`charts.ts:426-543`): Wärmekarte, x = Tage, y = 24 Stunden mit
        `inverse: true` („00:00 oben, wie ein Tagesplan gelesen wird", `:511`),
        Stundenbeschriftung alle sechs Stunden als „06:00" (`:515`), Tagesbeschriftung
        ungefähr jeder zehnte Spaltenschritt als „TT.MM." (`:498-499`), Gitter
        `left 44, right 16, top 52, bottom 34` (`:486`).
        Rampe `RAMP = [C.alert, "#c2a86b", C.battery]` (`CoverageMap.tsx:32`), feste
        Obergrenze 60 (`:117`), `null` wird **nicht** gezeichnet (`charts.ts:450-451`).
        Begründungen: Rampe `CoverageMap.tsx:30-31` - „Die Zwischenstufe muss es geben: eine
        Stunde mit 55 von 60 Minuten ist etwas anderes als eine mit 5"; feste Obergrenze
        `charts.ts:437-440` - „eine Skala, die sich nach den Daten richtet, färbte einen
        Zeitraum ohne jede Lücke genauso wie einen mit lauter Lücken"; umgekehrte Farbe
        `CoverageMap.tsx:21-22` - „Eine Karte ohne Lücken soll langweilig aussehen".
        **Hinweisfenster je Zelle** (`charts.ts:470-483`): Zeile 1 „Di., 10. November 2026"
        in `rgba(255,255,255,.6)`, Zeile 2 „07:00 - 07:59", Zeile 3 der Wert mit 0
        Nachkommastellen und „min".
        Skala je Bild: `visualMap` senkrecht oben rechts, `calculable: true` (also
        greifbar), 12×190, Beschriftung in Minuten (`charts.ts:517-536`).
        Hervorhebung einer Zelle: Rand `rgba(255,255,255,.85)` (`charts.ts:540`).
      - Unter den Bildern, **in der Karte**, eine `<Note>` (`CoverageMap.tsx:125-130`):
        `data.note_de` des Dienstes und danach wörtlich „Eine Zelle ohne Farbe heißt, dass
        für diese Stunde gar keine Minutenzeile existiert - dann stand der Dienst still, und
        der Ausfall ist unserer. Eine rote Zelle heißt, dass Minutenzeilen da sind und diese
        eine Reihe darin fehlt: dann hat das Gerät nichts geliefert." Begründung
        `CoverageMap.tsx:24-27`: „Der Unterschied entscheidet, wen man anschaut."
      - Zustände: Fehler → **statt der ganzen Karte** nur `<Note>` mit „Die Verfügbarkeit
        konnte nicht abgefragt werden." (`:93`, `:101`); noch nichts da → `<Note>`
        „lädt …" (`:102`). Kein Störungsband oben.
    DATEN: `api.coverage(anchor, 28)` (`:91`); Felder `start`, `end`, `note_de` und je Reihe
    `key`, `label_de`, `hours` (Paare Zeitstempel/Minuten), `coverage`, `incomplete_hours`,
    `longest_outage_h`, `last_at` (`:34-43`, `:65-80`).

  * **Karte 4 „Stundenbilanz und auffällige Strecken"** (`DataCheck.tsx:100-117`)
    `padding: 16`. Kopfzeile rechts ein Verweis, wörtlich „Minutenwerte dieses Tages als
    CSV ›", in `--amber`, mit `download`, auf
    `/api/dch/export/minutes?start=…&end=…` mit den beiden ISO-Zeitpunkten des Tages
    (`:52-56`, `:104-108`). Kommentar `:50-51`: ohne Anker keine Adresse, weil sie sonst
    beim Vorrendern anders aussähe als im Browser.
    Inhalt: ein `<pre class="mono">`, 11 px, `leading-[1.5]`, `--text-2`, `whitespace-pre`,
    waagerecht rollbar (`:114`). Kommentar `:111-113`: „Bewusst als Text und nicht als
    gestaltete Tabelle: das ist dieselbe Ausgabe, die auch über die API kommt, Zeichen für
    Zeichen … und kann sie unverändert weitergeben."
    Zustände: Text; sonst „lädt …", solange `loading`; sonst „Keine Diagnose verfügbar."
    (`:115`) - **die Karte bleibt in jedem Fall stehen**.
    DATEN: `api.diagnoseDay(anchor)`, reiner Text (`:38`, `:40`).

  * **Fließtext am Fuß** `<Note>` (`DataCheck.tsx:119-147`)
    **Immer sichtbar**, kein `<details>`: 12 px, `leading-[1.55]`, `--text-3`, höchstens
    90 Zeichen je Zeile (`ReportShell.tsx:143-145`, Begründung `:139-141`). Drei Absätze mit
    `<br />` getrennt: die obere Fläche und die drei Wege zum Zeitfenster (`:120-126`); der
    Ladestand als Gegenprobe mit der Rechnung 2,8 kW · 1,5 h = 4,2 kWh = über 80
    Prozentpunkte in einem 5,1-kWh-Speicher (`:128-133`); der amtliche Zähler, die Bilanz
    Haus = PV + Netz + Speicher und die Nullminuten in der Erzeugungsreihe (`:135-146`).

  * **Handy-Fassung der Route** (`apps/web/src/styles/handy.css`, `@media (max-width: 720px)`
    ab `:107`)
    - Seitenrand und Abstand: `.report-main { padding: 10px 16px calc(86px +
      env(safe-area-inset-bottom)); gap: 14px; font-size: 15px }` (`:110-111`).
    - Karten: **kein Rahmen**, Radius 16, `padding: 16` (`:183`).
    - Kartenkopf: `.card-head` umbrechend mit `row-gap: 3px` (`:183`); der Kicker wird zur
      Überschrift - `font-family: var(--font-sans)`, 16,5 px, `font-weight: 600`,
      `letter-spacing: -0.01em`, `line-height: 1.25`, **kein** `text-transform: uppercase`,
      Farbe `--text-1` (`:184`) statt des Wandzustands `mono` 13 px, `letter-spacing .13em`,
      Großbuchstaben, `--text-kicker` (`globals.css:57-64`).
    - Kopfzeile rechts: `.card-head-right { flex-basis: 100%; font-size: 13px; line-height:
      1.4; white-space: normal; overflow: visible; text-overflow: clip }` (`:185`) - sie
      bricht also **vollständig** um und wird ausdrücklich **nicht** abgeschnitten.
    - Kleine Schrift eine Stufe größer: 10 → 11, 11 → 12, 12 → 13,5, 13 → 14,5 px
      (`:189-192`, Begründung `:187-188`: „Am Rechner liest man 12 Punkt aus sechzig
      Zentimetern, am Handy aus dreißig, aber im Gehen").
    - Kopf der Unterseite: Bereichsname als 26 px, `font-weight: 600` (`:141`); die
      Reiterzeile wird eine rollbare Reihe von Pillen (`:163-175`); der Zeitraumkasten
      zerfällt - Datum neben dem Bereichsnamen, Spannen als breiter Schalter darunter
      (`:146-161`), Anker in der Kurzform (`:159-160`).
    - Methodenkarte: `padding: 0`, Griff `padding: 15px 16px`, Titel sans 15 px / 600 ohne
      Großbuchstaben, Absätze 14,5 px / `line-height 1.5` (`:212-217`).
    - Gesucht nach „daten", „coverage", „pre", „mono", „Quellen" in `handy.css`: kein
      Treffer; die Route hat keine eigene Handy-Regel über die obigen hinaus.


LUECKEN:

  [traegt-die-seite] Der Weg zu den Rohdaten fehlt ganz. Die Vorlage setzt in den Kopf der
    Stundenbilanz-Karte den Verweis „Minutenwerte dieses Tages als CSV ›" auf
    `/api/dch/export/minutes?start=…&end=…` (`DataCheck.tsx:52-56, 100-110`); der Kopfkommentar
    der Vorlage nennt ihn als eines der drei Dinge, für die es diese Seite gibt
    (`DataCheck.tsx:16-20`: „darunter dieselben Zahlen je Stunde, und daneben der Weg zu den
    Rohdaten … braucht genau diese drei Dinge und nichts weiter"). Die App-Karte hat kein
    Beiwerk (`SystemSeiten.swift:669`); gesucht nach „CSV", „ShareLink", „export(art" in
    `apps/ios/DuckCurveHome`: nur `Seiten/Technik/ZugangSeite.swift:255-274`, also die
    Jahressicherung auf einer anderen Seite.

  [traegt-die-seite] „Leer ist nicht null" steht hinter einem Deckel. In der Vorlage steht der
    Satz, der leere gegen rote Zelle unterscheidet, zusammen mit `note_de` des Dienstes als
    `<Note>` **in** der Abdeckungskarte und immer offen (`CoverageMap.tsx:125-130`). Die App
    schiebt beides in die zugeklappte Methodenkarte am Seitenfuß (`SystemSeiten.swift:684-685`,
    `Bericht.swift:528` `@State private var offen = false`) und übergibt kein `kurz`
    (`SystemSeiten.swift:682`), so dass zugeklappt nur „Wie das gerechnet ist" dasteht. Damit
    fehlt gerade die Auskunft, die laut Vorlage „entscheidet, wen man anschaut"
    (`CoverageMap.tsx:24-27`) - und `noteDe` ist eine Angabe **zu diesem Zeitraum**, also
    genau das, was der eigene Baustein ausdrücklich nicht hinter den Deckel nehmen will
    (`Bericht.swift:519-524`; `apps/web/src/components/ui/Methode.tsx:44-46`).

  [spuerbar] Die drei erklärenden Absätze sind in der Vorlage ein immer sichtbarer Fließtext
    (`DataCheck.tsx:119-147`, `<Note>` ohne `<details>`, 12 px / `leading-[1.55]` / 90 Zeichen
    je Zeile, `ReportShell.tsx:143-145`); die Seite benutzt **kein** `Methode` und **kein**
    `CoverageNote`. Die App macht daraus eine zugeklappte Karte in 11,5 px
    (`SystemSeiten.swift:682-687`, `Bericht.swift:545-549` mit `Schrift.winzig`).

  [spuerbar] Die Prüfkurve hat keine Werteauskunft. Die Vorlage zeigt am Zeiger ein Fenster mit
    `hh:mm` und allen vorhandenen Reihen, jede in ihrer Farbe, mit zwei Nachkommastellen und
    „kW" (`charts.ts:591-601`) - das ist das Werkzeug, mit dem man die beiden Gegenproben
    Minute für Minute vergleicht, und genau dafür ist die Seite da (`charts.ts:689-696`). Die
    App belegt die Wischgeste mit der Fensterwahl (`Pruefkurvenbild.swift:77`) und hat sonst
    keine Auskunft; gesucht nach `annotation(`, `chartXSelection(value` in
    `Pruefkurvenbild.swift`: kein Treffer.

  [spuerbar] Die Abdeckungskarte hat keine Zellenauskunft. Die Vorlage nennt bei Berührung Tag
    („Di., 10. November 2026"), Stunde („07:00 - 07:59") und Minutenzahl („42 min")
    (`charts.ts:470-483`) und hebt die Zelle mit einem hellen Rand hervor (`charts.ts:540`).
    `Abdeckungskarte` zeichnet in ein `Canvas` ohne jede Berührungsbehandlung
    (`Abdeckungskarte.swift:65-67, 127-147`); damit lässt sich keine einzelne Lücke beziffern,
    nur ihre Farbe schätzen.

  [spuerbar] Die Fehlerbehandlung ist gegenüber der Vorlage vertauscht. Vorlage: Störungsband
    „Daten konnten nicht geladen werden." **nur**, wenn Verlauf und Diagnose beide scheitern
    (`DataCheck.tsx:41`); eine gescheiterte Abdeckungsabfrage ersetzt nur die eigene Karte
    durch eine Note (`CoverageMap.tsx:93, 101`) und lässt den Rest der Seite in Ruhe. App:
    `fehler` wird ausschließlich aus `abdeckung == nil` gesetzt (`SystemSeiten.swift:708`), also
    schlägt die Seite oben Alarm, wenn die Abdeckung fehlt, und bleibt stumm, wenn Verlauf und
    Diagnose zugleich ausfallen. Der eigene Wortlaut der Vorlage für diesen Fall steht nirgends:
    gesucht nach „Daten konnten nicht geladen" in `apps/ios`: kein Treffer.

  [spuerbar] Fällt die Abdeckung aus, verschwindet die ganze Karte. `if let a = abdeckung`
    (`SystemSeiten.swift:653`) nimmt Kopfzeile, Bilder und Note vom Schirm; die Vorlage behält
    die Stelle und schreibt dorthin „Die Verfügbarkeit konnte nicht abgefragt werden."
    (`CoverageMap.tsx:93, 101`). Dasselbe gilt für die Stundenbilanz: `if let d = diagnose,
    !d.isEmpty` (`SystemSeiten.swift:664`) löscht die Karte, wo die Vorlage „Keine Diagnose
    verfügbar." in sie schreibt (`DataCheck.tsx:115`).

  [spuerbar] Kein Ladezustand - die Seite behauptet stattdessen etwas über die Daten. Die
    Vorlage schreibt in allen vier Zuständen zuerst „lädt …" (`DataCheck.tsx:83`, `:115`;
    `CoverageMap.tsx:102`; `Sources.tsx:49`) und erst danach den Befund. Die App hat kein
    Ladekennzeichen: `hatMinuten` beginnt auf `false` (`SystemSeiten.swift:626`), also steht
    beim Öffnen „Für diesen Tag liegen keine Minutenwerte vor. Seine Stundenbilanzen stammen
    dann aus dem Historienimport." (`:641`, `Datenbild.swift:207-208`), und solange
    `haus.zustand` noch leer ist, sagt die Quellenkarte „Der Zustand der Quellen ist gerade
    nicht abrufbar." (`Pruefkurvenbild.swift:219-220`, `Datenbild.swift:608`) - beides ein
    Befund über die Datenlage, wo noch nichts abgefragt wurde.

  [spuerbar] Quellenzeile am Telefon: in der Vorlage steht der Satz des Dienstes unter 640 px
    in einer eigenen Zeile unter dem Namen (`w-full … sm:w-auto`, `Sources.tsx:61, 79`), 13 px
    und durch `handy.css:191` auf 13,5 px gehoben, `leading-[1.5]`. `Quellenkarte` setzt Name
    und Satz immer in einen `HStack` (`Pruefkurvenbild.swift:230-243`); auf 390 Punkten teilt
    sich damit ein Satz wie „inexogy · 412 Abfragen · letzter Wert vor 3 min" die Zeile mit
    „Zähler (inexogy)".

  [spuerbar] Die Höhe der Hauptkarte ist nicht übernommen. Vorlage: Karte fest 480 px, das
    Diagramm nimmt den Rest (`DataCheck.tsx:71, 80`), bei 16 px Innenrand, Kopfzeile und
    Legende also rund 390 px Bildfläche. App: `.frame(height: 300)`
    (`Pruefkurvenbild.swift:115`), und die Karte wächst nur mit ihrem Inhalt
    (`Karte.swift:26-38`, keine Höhe). Auf einer Achse, die über die Null reicht, kostet das
    unmittelbar Auflösung in kW.

  [klein] Die Vorzeichenzeile wird abgeschnitten. `lineLimit(2)`
    (`Pruefkurvenbild.swift:53`) gegen `handy.css:185`, das für genau diese Zeile
    `white-space: normal; overflow: visible; text-overflow: clip` setzt - der Text soll
    umbrechen, nicht verschwinden (`Card.tsx:28-29`: „ein abgeschnittener Legendeneintrag ist
    schlimmer als eine zweite Zeile").

  [klein] Die Farbskala der Abdeckung ist in der Vorlage greifbar (`calculable: true`,
    `charts.ts:519`) und steht je Bild einmal senkrecht oben rechts, 12×190
    (`charts.ts:517-536`). Die App hat einen festen waagerechten Streifen für alle Reihen
    (`Abdeckungskarte.swift:180-196`); dass das eine Abweichung ist, ist dort begründet
    (`:176-179`), die Greifbarkeit ist aber nirgends erwähnt.

  [klein] `lade` lädt nacheinander, wo die Vorlage parallel lädt. `let historie = await minuten`
    (`SystemSeiten.swift:694`) wartet den Verlauf ab, bevor Abdeckung und Diagnose überhaupt
    beginnen (`:703-705`); die Vorlage holt Verlauf und Diagnose in einem
    `Promise.allSettled` (`DataCheck.tsx:38`) und die Abdeckung in einem eigenen, gleichzeitig
    laufenden Effekt (`CoverageMap.tsx:87-97`).

  [klein] Das Störungsband sieht anders aus als in der Vorlage: dort Rahmen und Fläche in
    `--alert` (`rgba(224,83,61,.4)` / `rgba(224,83,61,.12)`), Text `mono` 12 px in
    Großbuchstaben mit `letter-spacing .1em` (`ReportShell.tsx:147-153`); in der App ein Kasten
    in `flaeche2` mit Warnzeichen in `Farbe.achtung` und `Schrift.klein`
    (`Karte.swift:443-464`). Entscheidung über alle Seiten hinweg, hier nur vermerkt.

  [klein] Die 28 Tage sind in der App mit `DataCheck.tsx:98` belegt
    (`SystemSeiten.swift:617`, `:701`); dort steht nur `<CoverageMap anchor={anchor} />`. Die
    Zahl ist der Vorgabewert in `CoverageMap.tsx:83`.

  [klein] `Pruefkurve.luecken()` ist gerechnet, geprüft und unbenutzt
    (`Datenbild.swift:482-500`; `DatenbildTests.swift:106, 229, 242, 252, 256, 264`). Gesucht
    nach „luecken()" und „Erzeugungsluecke" in `apps/ios/DuckCurveHome`: kein Treffer. Die
    Vorlage zeigt diese Zahl ebenfalls nicht selbst - sie verweist auf den Diagnosetext
    (`DataCheck.tsx:142-146`) -, also ist entweder der Satz aus dem Befund zu setzen oder die
    Rechnung zu entfernen; beides stehen zu lassen ist der Zustand, aus dem Abweichungen
    entstehen.


KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Pruefpunkt` - eine Minute mit `pv`, `netz`, `netzZaehler`, `speicher`, `ladestand`;
    `ausZeile`, `raster(_:)` aus `HistoryOut`:
    `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Datenbild.swift:25-81`.
  * `Pruefkurve` - sechs Reihen, Legendenreihenfolge, Achsenspanne über die Null, Ladestand in
    Prozent, `fenster`: `Datenbild.swift:106-181`. Konstanten der Vorlage:
    `mindestspanne -2...4`, `luft 1.12`, `nullschwelle 0.005`, `netzRegung 0.05`,
    `lueckenabstand 3/60`, `leersatz`: `Datenbild.swift:189-208`.
  * `Pruefkurve.Reihe` mit `name`, `gestrichelt`, `rechteAchse`, `verbunden`:
    `Datenbild.swift:117-147`. Die sechs Namen stimmen wörtlich mit `charts.ts:624-631`
    überein (nachgesehen: „PV", „Haus", „Netz", „Netz (Zähler)", „Speicher", „Ladestand %").
  * `Pruefkurve.baue(tag:historie:)`, `punkte(_:)`, `leistungsreihen`, `legende`, `leer`,
    `spanne(_:)`, `ladestandAufLeistung`, `leistungAufLadestand`, `ladestandsmarken`,
    `ausschnitt(von:bis:)`, `verdichtet(schrittMin:)`, `strecken(_:hoechstabstand:)`:
    `Datenbild.swift:219-430`.
  * `Pruefkurve.Erzeugungsluecke` mit `befund` und `luecken()`: `Datenbild.swift:445-500`.
  * `Pruefworte` - die drei Absätze der Vorlage und `abdeckungssatz`:
    `Datenbild.swift:511-536`.
  * `Quellenstand` - `Ton`, `Quellenzeile`, die Namenstabelle, `vollmacht`, `schaltetSatz`,
    `schaltetNichtSatz`, `trenner`, `nichtAbrufbar`, `zeilen(aus:)`:
    `Datenbild.swift:558-638`.
  * `Abdeckungsraster` - `Rastertag`, `Abdeckungsstufe`, `baue(_:)`, `baue(_:tage:)`,
    `tageZwischen`, `farbe(_:)`, `farbe(minuten:)`, `stufe(minuten:)`, `Kopfzeile`,
    `kopfzeile(jetzt:)`, `alter(lastAt:jetzt:)`, `lesehilfe`, `nichtAbrufbar`,
    Konstanten `minutenJeStunde 60`, `grenzeTeils 15`, `grenzeVoll 45`, `dringendUnter 0.99`,
    `feinAb 0.999`: `Datenbild.swift:660-878`.
  * `Formate.abdeckung(_:)` - zwei Stellen über 99,9 %, sonst eine:
    `Datenbild.swift:887-891`.
  * Farben: `Marken.abdeckungFehlend`/`abdeckungTeils`/`abdeckungVoll`/`abdeckung` und
    `abdeckungsfarbe(anteil:)`:
    `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift:275-294`; nachgerechnet
    gegen `CoverageMap.tsx:32` - `alarm 0xE0533D` = `C.alert`, `0xC2A86B` = `"#c2a86b"`,
    `mist 0x7FA3B3` = `C.battery`. Diagrammfarben `diagrammNetz 0xE0533D`,
    `diagrammSpeicher 0x7FA3B3`, `pv`=`amber`, `haus 0xCFD8DC`: `Marken.swift:89, 115, 170,
    174`, gleich `C.grid`, `C.battery`, `C.pv`, `C.house`.
  * Abfragen: `Api.verlaufTag(_:)` `Netz/Api.swift:155`, `Api.diagnose(tag:)` `:163`,
    `Api.abdeckung(anker:tage:)` `:365`.
  * Modelle: `CoverageOut` mit `start`, `end`, `series`, **`noteDe`, nicht optional** -
    `Modelle/Schema.swift:2622-2647`; `CoverageSeriesOut` `:2657`.
  * Route und Kicker: `Bereiche.swift:222-224` („Daten prüfen",
    „Messreihen · Stundenbilanz · Rohdaten", `mitZeitraum: true`).
  * Bausteine: `Karte` mit `kicker`/`titel`/`beiwerk` und Handy-Fassung
    `apps/ios/DuckCurveHome/Gestalt/Karte.swift:15-104`; `Leer` `:390-404`; `Stoerung`
    `:419-465`; `Methode` `apps/ios/DuckCurveHome/Seiten/Bericht.swift:514`; `Umbruchzeile`
    `Gestalt/Umbruchzeile.swift`; `Seite`/`Zeitraumleiste` `App/Seitenwahl.swift:154, 235`.
  * Vorbilder für eine Auskunft am Finger: `Fahrplanzeichnung.swift:88, 142`,
    `Tagesvergleichsbild.swift:31, 61, 172, 180, 239`, `Wirkungszeichnung.swift:131-133,
    191-201, 295` (geteilte Auswahl plus Auskunftszeile über dem Bild).
  * Vorbild für einen Dateiverweis: `Seiten/Technik/ZugangSeite.swift:268-274` mit
    `oeffne(adresse)` und `Zugang.export(art:jahr:)` `Netz/Zugang.swift:202-205`; der
    Vorbehalt zur fehlenden `Authorization`-Kopfzeile ist dort begründet (`:253-267`).


ES FEHLT:

  1. Eine Export-Adresse für **einen Tag**. `Zugang.export(art:jahr:)`
     (`Netz/Zugang.swift:202-205`) kennt nur `year`; die Vorlage ruft
     `/api/dch/export/minutes?start=…&end=…` (`DataCheck.tsx:52-56`), und `docs/openapi.json`
     führt für `/api/v1/export/{kind}` neben `year` auch `start` und `end` als
     `date-time`. Vorschlag: `Zugang.export(art: Exportart, von: Date, bis: Date) -> URL?` in
     `DuckCurveKit/Netz/Zugang.swift`, mit den Tagesgrenzen aus `Tag.zeitraum(_:)`, und der
     Wortlaut „Minutenwerte dieses Tages als CSV ›" als `Pruefworte.csvVerweis` in
     `Zustand/Datenbild.swift`.

  2. Die Auskunft zu einer Stelle der Prüfkurve. Vorschlag `Pruefkurve.Auskunft`
     (`zeit: String` als `hh:mm`, `zeilen: [(Reihe, String)]` mit zwei Nachkommastellen und
     „kW", Reihen ohne Wert fallen weg) und `func auskunft(stunde: Double) -> Auskunft?` in
     `Zustand/Datenbild.swift`, nach dem Muster von `Fahrplanbild.auskunft` und
     `Wirkungsbild.auskunft(minute:)`. Die Formatierung über `Formate.kw`, nicht in der
     Ansicht.

  3. Die Auskunft zu einer Zelle der Abdeckungskarte. Vorschlag
     `Abdeckungsraster.Zellenauskunft` (`tag: String` als „Di., 10. November 2026",
     `stunde: String` als „07:00 - 07:59", `wert: String` als „42 min"; ohne Minutenzeile ein
     eigener Satz) und `func auskunft(tag: Int, stunde: Int) -> Zellenauskunft?` in
     `Zustand/Datenbild.swift`. Der Datumssatz braucht ein Format „kurzer Wochentag, Tag,
     langer Monat, Jahr" - in `DuckCurveKit/Formate/Tag.swift` nachgesehen: `Tag.lang` gibt
     „Samstag, 7. November 2026“ (`:86-91`), `Tag.kurz` gibt „Sa, 7.11.“ (`:93-98`),
     `Tag.tagMonat` gibt „10.11.“ (`:106-110`); die Form der Vorlage
     (`weekday: "short"` plus langer Monat, `charts.ts:474-479`) gibt es nicht und ist dort
     als dritte Funktion zu ergänzen - die Bausteine dafür sind da
     (`Namen.wochentag(_:kurz:)`, `Namen.monat(_:)`).

  4. Ladezustand und Fehlerwortlaut. Vorschlag: ein `Pruefstand`-Wert in
     `Zustand/Datenbild.swift` (`laedt`, `da`, `leer`, `fehler`) je Abfrage, dazu die vier
     Sätze der Vorlage als Konstanten: `Pruefworte.laedt = "lädt …"` (`DataCheck.tsx:83`),
     `Pruefworte.ladefehler = "Daten konnten nicht geladen werden."` (`DataCheck.tsx:41`),
     `Pruefworte.keineDiagnose = "Keine Diagnose verfügbar."` (`DataCheck.tsx:115`) und
     `Quellenstand.laedt = "lädt …"` (`Sources.tsx:49`). Gesucht nach „lädt …" in
     `DuckCurveKit/Sources`: Treffer nur in anderen Seitentexten
     (z. B. `Speichertagkurve.swift`), kein gemeinsamer Satz.


BAUPLAN: Karte für Karte, in der Reihenfolge der Vorlage.

  1. `DuckCurveKit/Zustand/Datenbild.swift` - die vier Punkte aus ES FEHLT anlegen:
     `Pruefstand`, die vier Lade- und Fehlersätze, `Pruefkurve.Auskunft` mit
     `auskunft(stunde:)`, `Abdeckungsraster.Zellenauskunft` mit `auskunft(tag:stunde:)`,
     `Pruefworte.csvVerweis`. Tests dazu in
     `DuckCurveKit/Tests/DuckCurveKitTests/DatenbildTests.swift` (die Datei besteht schon).
  2. `DuckCurveKit/Netz/Zugang.swift` - `export(art:von:bis:)` neben
     `export(art:jahr:)`, mit demselben Vorbehalt im Kommentar. Test in
     `ZugangsseiteTests.swift` neben den beiden bestehenden Adressprüfungen (`:27`, `:40`).
  3. `SystemSeiten.swift:692-709` (`lade`) - alle drei Abfragen nebenläufig starten
     (`async let` für Verlauf, Abdeckung, Diagnose und erst danach `await`), je Abfrage einen
     `Pruefstand` setzen, und `fehler` nur noch für den Fall „Verlauf **und** Diagnose
     gescheitert" mit `Pruefworte.ladefehler` belegen. Die Abdeckung setzt ihren eigenen
     Zustand und **nicht** das Störungsband.
  4. `SystemSeiten.swift:637-643` (Karte 1) - `beiwerk` leer lassen (die Vorzeichenregel
     bleibt laut `DataCheck.tsx:74-75` im Kartenkörper), die Zustände aus `Pruefstand`
     zeichnen: `laedt` → `Leer(satz: Pruefworte.laedt)`, `leer` → `Pruefkurve.leersatz`.
  5. `Pruefkurvenbild.swift` - `lineLimit(2)` auf `:53` entfernen und stattdessen
     `fixedSize(horizontal: false, vertical: true)`; Bildhöhe von 300 auf die Höhe der
     Vorlage bringen (Karte 480 minus Innenrand, Kopfzeile und Legende, also rund 390 - am
     Telefon über `horizontalSizeClass` zu prüfen); Auskunftszeile über dem Bild nach dem
     Muster `Tagesvergleichsbild.swift:61, 172` ergänzen (siehe WAS SCHWIERIG WIRD zur
     Geste).
  6. `Pruefkurvenbild.swift:214-261` (`Quellenkarte`) - bei `horizontalSizeClass == .compact`
     Name und Satz in einen `VStack` setzen, Satz volle Breite; `Umbruchzeile` ist dafür schon
     da (`Gestalt/Umbruchzeile.swift`, so gelöst in `Abdeckungskarte.swift:80`). Ladezustand
     getrennt von „nicht abrufbar" zeichnen.
  7. `SystemSeiten.swift:653-663` (Karte 3) - das `if let a = abdeckung` auflösen: die Karte
     steht immer, im Inneren je nach Zustand das Raster, `Pruefworte.laedt` oder
     `Abdeckungsraster.nichtAbrufbar`. Die Note der Vorlage (`abdeckung?.noteDe` plus
     `Abdeckungsraster.lesehilfe`) **in** diese Karte, unter die Bilder, immer sichtbar, in
     `Schrift.winzig`/`Farbe.text3` - und aus der Methodenkarte entfernen.
  8. `Abdeckungskarte.swift` - Berührung auf dem `Canvas` (`DragGesture`/`spatialTapGesture`
     auf den Rasterkasten, Spalte und Zeile aus derselben Rechnung wie `male`, `:131-141`)
     und eine Auskunftszeile über dem Block aus `Abdeckungsraster.auskunft(tag:stunde:)`;
     die getroffene Zelle mit einem hellen Rand hervorheben (`charts.ts:540`).
  9. `SystemSeiten.swift:664-677` (Karte 4) - die Karte unbedingt zeichnen, Inhalt je nach
     Zustand Text, `Pruefworte.laedt` oder `Pruefworte.keineDiagnose`; `beiwerk` mit dem
     CSV-Verweis aus `Zugang.export(art: .minuten, von:bis:)` und `Pruefworte.csvVerweis`,
     geöffnet wie in `ZugangSeite.swift:268-274`, und ohne Adresse kein Verweis.
 10. `SystemSeiten.swift:682-687` (Fuß) - `Methode` durch den immer sichtbaren Fließtext der
     Vorlage ersetzen: die drei Absätze aus `Pruefworte.methode` plus
     `Pruefworte.abdeckungssatz` als Text in `Schrift.winzig`/`Farbe.text3`, Zeilenlänge
     begrenzt. Falls die Karte bleiben soll, dann mit `offen = true` als Anfangszustand und
     `kurz` gesetzt - zugeklappt darf diese Seite nichts verbergen.
 11. `SystemSeiten.swift:617` - die Belegstelle der 28 Tage auf `CoverageMap.tsx:83`
     berichtigen.
 12. Entscheiden, was mit `Pruefkurve.luecken()` geschieht: entweder einen Satz daraus unter
     der Stundenbilanz setzen (dann gehört der Wortlaut nach `Pruefworte`) oder Rechnung und
     Tests entfernen.


WAS SCHWIERIG WIRD:

  * **Eine Geste, zwei Aufgaben.** Die Vorlage hat für das Zeitfenster drei eigene Bedienwege
    (Werkzeug, Regler, Rad - `charts.ts:634-672`) und daneben das Hinweisfenster am Zeiger.
    Swift Charts hat für beides nur die Wischgeste: `chartXSelection(range:)` belegt sie schon
    (`Pruefkurvenbild.swift:77`), und `chartXSelection(value:)` auf demselben Bild nimmt sie
    ihr. Im Projekt gibt es dafür kein Vorbild: gesucht nach `chartXSelection(range` in
    `apps/ios`: nur diese eine Stelle; gesucht nach `chartOverlay` in `apps/ios`: kein
    Treffer, und `Kennlinienbilder.swift:671-673` hält ausdrücklich fest, dass es keines gibt.
    Der Weg, den das Projekt sonst geht, ist eine getrennte Bedienfläche neben dem Bild -
    `Spannenstreifen.swift:19-40` (eigener Schalter am Telefon statt vier Spalten) und
    `Bausteine/Tagewahl.swift` -, also: Auskunft auf die Wischgeste
    (`chartXSelection(value:)` wie `Tagesvergleichsbild.swift:180`) und das Zeitfenster auf
    zwei Knöpfe oder einen eigenen Regler unter dem Bild. `Pruefworte.flaeche`
    (`Datenbild.swift:519-520`) beschreibt heute den Zustand „Ziehen wählt ein Fenster" und
    muss mitgehen, wenn sich die Geste ändert - der Satz ist laut seinem eigenen Kommentar
    (`:513-518`) gerade deshalb im Kern, „besser, als einen Regler zu versprechen, den es
    nicht gibt".
  * **Berührung auf einem `Canvas`.** Die Abdeckungskarte ist aus gutem Grund gezeichnet und
    nicht gestapelt (`Abdeckungskarte.swift:23-26`: über zweitausend Felder). Damit gibt es
    keine Marke, die ein Tippen treffen könnte; Spalte und Zeile sind aus der Rechnung in
    `male` (`:131-141`) zurückzurechnen. Vorbild im Projekt:
    `Bausteine/Abweichungsmatrix.swift:68` zeichnet aus demselben Grund in ein `Canvas`
    (dieselbe Begründung wird in `Abdeckungskarte.swift:25` zitiert) - **aber auch dort gibt es
    keine Berührung**: gesucht nach `Gesture`, `onTapGesture`, `gewaehlt` in
    `Abweichungsmatrix.swift`: kein Treffer. Es wäre die erste Trefferrechnung dieser Art im
    Projekt, und sie gehört dann in den Kern, nicht in die Ansicht.
  * **Zweite Werteachse.** Schon gelöst, nicht neu zu bauen: `ladestandAufLeistung` /
    `leistungAufLadestand` (`Datenbild.swift:322-333`) mit der Achsenbeschriftung in
    `Pruefkurvenbild.swift:103-113`. Der Grund, warum 0 % an den unteren Rand und nicht auf
    die Nulllinie gehört, steht in `Datenbild.swift:318-321` und darf beim Umbau nicht
    verloren gehen.
  * **Der Dateiverweis.** Die `Authorization`-Kopfzeile reist bei `openURL` nicht mit; das ist
    in `ZugangSeite.swift:253-267` begründet und wird dort dem Benutzer gesagt
    (`Zugangsworte.herunterladen`). Für diese Seite ist derselbe Vorbehalt nötig, sonst führt
    der CSV-Verweis in eine Anmeldeseite. `Api` hat für Antworten, die kein JSON sind, nach
    wie vor nichts (gesucht nach „export" in `Netz/Api.swift`: kein Treffer).
  * **Feste Kartenhöhe.** `Karte` hat keinen Höhenparameter (`Karte.swift:15-38`), und die
    Vorlage braucht hier eine (`height: 480`). Entweder eine Höhe am Bild wie bisher - dann
    bleibt die Karte ein wenig höher als 480 - oder `Karte` um einen optionalen `hoehe`
    erweitern; gesucht nach einer solchen Karte in `apps/ios/DuckCurveHome`: kein Treffer, es
    wäre die erste.
