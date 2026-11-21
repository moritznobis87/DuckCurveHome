========================= messen:system-zugang   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/App/Einrichten.swift:255-356`, Hülle `Seite`
= `apps/ios/DuckCurveHome/App/Seitenwahl.swift:148-181`, Rand 16, Abstand 14)

1. Karte „Dieses Gerät" (`Einrichten.swift:262-280`) — sechs `Zeile`
   (`Gestalt/Karte.swift:360-383`): Name im Protokoll, Kennung, Zugang
   (Hausherr/Gast, Gast in `Farbe.achtung`), Adresse, Pfad, Token
   („keines (Demo)" oder „im Schlüsselbund · N Zeichen").
2. Karte „Verbindung" (`Einrichten.swift:281-295`) — Zustand (Wort aus
   `Einrichten.swift:348-355`), und wenn `haus.zustand?.system` da ist:
   Betriebsart, Fassung des Dienstes, Brücke, Anzeigen am Strom,
   Zeitversatz zum Dienst.
3. Karte „Angemeldete Geräte für Mitteilungen" (`Einrichten.swift:296-313`),
   nur wenn `haus.api.mitteilungGeraete()` (`Netz/Api.swift:469`) antwortet:
   je Gerät `Zeile(wort: label, wert: hhmm(zuletztOk), dazu: "seit hhmm(seit)")`,
   sonst `Leer(satz: "Kein Gerät angemeldet.")`.
4. Karte „Ändern" (`Einrichten.swift:314-327`) — ein Knopf „Neu einrichten"
   (Schrift.klein, Grund `Farbe.amberWeich`, Text `Farbe.deep`,
   Radius `Marken.radius3` = 6), öffnet `Einrichten()` als Sheet
   (`Einrichten.swift:340-342`).
5. `Methode` mit drei Sätzen (`Einrichten.swift:328-338`), **zugeklappt**
   (`Seiten/Bericht.swift:334-398`): Token im Schlüsselbund; Rolle „Gast"
   blendet aus, sperrt nicht; Protokoll nennt das Gerät, nicht den Menschen.

Kein Ladezustand, kein Fehlerzustand (`try?` in `Einrichten.swift:344`
verschluckt den Fehler), kein `Stoerung`.

VORLAGE: `apps/web/src/app/system/zugang/page.tsx`, Hülle
`components/layout/AreaShell.tsx:14-31`
(`.report-main`, `gap-4` = 16, `p-5` = 20, Grund `.dashboard-bg`
= `globals.css:86-94`: Verlauf + 58-px-Raster).
Alle sechs Abschnitte sind `<section className="flex max-w-[760px] flex-col gap-3">`
(bzw. `gap-2` bei den letzten zwei) mit einer `<h2 className="m-0 text-[18px] font-semibold">` —
**keine Karten**. Die Seite ist zu etwa drei Vierteln Fließtext, und zwar
sichtbarer Fließtext, nicht aufklappbarer.

  * Kicker des Bereichs: „Geräte koppeln · wer zusieht · Daten sichern"
    (`page.tsx:58`), gesetzt von `AreaNav.tsx:96`:
    `className="kicker hidden truncate pb-2.5 md:block"`, `fontSize: 11`.
    `.kicker` = Mono, 13 px, `letter-spacing .13em`, uppercase,
    `--text-kicker` = `--mist` #7FA3B3 (`globals.css:57-64`, `tokens.css:15,35`).
    DATEN: keine.

  * **„Zugang einrichten"** (`page.tsx:60-86`)
    - Absatz, 15 px, `line-height 1.6`, `--text-2` (rgba(255,255,255,.72)),
      mit `<code className="mono mx-1 text-[13px]">DCH_PUBLIC_HOST</code>`
      (`page.tsx:62-68`).
    - Zwei `Row` (`page.tsx:12-20`): Kasten
      `rounded-[3px] border border-line-1 bg-surface-2 p-4`, `gap-1.5`
      (= `--radius-2` 3 px, `--line-1` rgba(255,255,255,.10),
      `--surface-2` #123544, `tokens.css:24,27,93`); darin
      der Kicker in 11 px, darunter `CopyField`, darunter die Note in
      13 px / 1.5 / `--text-3` (rgba(255,255,255,.48)).
      Zeile 1 wörtlich: Kicker „Vollzugriff (Hausherr, Wandanzeige)",
      Wert `https://<host>/pair?token=<DCH_KIOSK_TOKEN>&name=iPad-Flur`,
      Note „Darf schalten, sieht Kosten und Rechnungen. Die Sitzung hält ein
      halbes Jahr; `name` erscheint nur im Protokoll." (`page.tsx:69-73`).
      Zeile 2: Kicker „Gast (nur ansehen)", Wert
      `https://<host>/pair?token=<DCH_GUEST_TOKEN>&hours=8`, Note
      „Sieht Jetzt, Strom, Wärme und Geld; PV-Abrechnung, Rechnungen und System
      bleiben verschlossen. Die Schalter bleiben sichtbar und sagen „nur
      Ansicht". Ohne `hours` gilt DCH_GUEST_HOURS (Vorgabe 24), höchstens 720."
      (`page.tsx:74-78`).
    - `CopyField` (`components/ui/CopyField.tsx:9-45`): links der Wert als
      `code.mono` 14 px `break-all` in `--text-1`, rechts ein Knopf,
      Mono 11 px uppercase `tracking-[.08em]`, Rand `--line-2`, Text `--text-3`,
      Radius 3, Polster 2.5/1. Drei Zustände mit drei Wörtern: „kopieren" →
      „kopiert" (Rand und Text werden `--amber` #F2A900) → nach 2500 ms zurück;
      scheitert die Zwischenablage, wird der `code`-Inhalt **markiert** und der
      Knopf sagt „markiert" (CopyField.tsx:5-8 nennt den Grund: „Fällt die
      Zwischenablage aus … tut der Knopf wenigstens den halben Weg, statt still
      zu versagen").
    - Schlussabsatz 14 px / 1.6 / `--text-3` (`page.tsx:79-85`): der Ablauf
      begrenzt die *Sitzung*, nicht den Link; `DCH_GUEST_TOKEN` ändern; dazu
      zwei bedingte Sätze — „Nicht gesetzt: … - der Link zeigt dort noch den
      Platzhalter." und „Achtung: DCH_SESSION_SECRET ist nicht gesetzt, die
      Anmeldung ist derzeit deaktiviert." (`lib/session.ts:30-32`).
    DATEN: keine Abfrage. `process.env.DCH_KIOSK_TOKEN`,
    `DCH_GUEST_TOKEN` (`page.tsx:51-52`), Host aus `DCH_PUBLIC_HOST` bzw.
    `x-forwarded-host`/`host`, Rückfall `home.duckcurve.de`
    (`page.tsx:33-40`).
    **Begründung im Code, die beim Umbau nicht verloren gehen darf**
    (`page.tsx:29-32`): „Railway antwortet weiterhin unter *.up.railway.app;
    ein von dort kopierter Link führte Gäste an der eigenen Domain vorbei."
    Und `page.tsx:47-50`: die Links tragen die echten Tokens, „wer einen
    Screenshot dieser Seite bekommt, hat die Schlüssel zum Haus" — deshalb
    `requireOwner()` doppelt (`page.tsx:43`) und `force-dynamic`
    (`page.tsx:9`).

  * **„Gerade verbunden"** (`page.tsx:88-114`)
    - leer: ein Absatz 15 px `--text-3` „Niemand in den letzten fünf Minuten."
      (`page.tsx:91`).
    - sonst `<ul>` ohne Punkte, `gap-2`; je Eintrag
      `rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3`,
      `items-baseline justify-between`: links Name (15 px, `--text-1`),
      Rolle in Mono 12 px uppercase `tracking-[.1em]` — „Vollzugriff" in
      `var(--amber)`, „Gast" in `var(--text-3)` (`page.tsx:98-101`) —, dann
      der Kurz-Agent (13 px `--text-3`); rechts Mono 12 px `--text-3`
      mit `ago(lastSeen)`.
    - `ago` (`page.tsx:22-27`): unter 60 s „vor N s", sonst „vor N min",
      nie Stunden; Kommentar nennt den Grund: „hier zählt der Abstand zu
      jetzt, nicht der Zeitpunkt."
    - Schlussabsatz 14 px `--text-3` (`page.tsx:108-113`): Name kommt aus
      `&name=…`, ohne Angabe „gast"; „Die Liste liegt nur im Arbeitsspeicher:
      nach einem Neustart des Web-Dienstes ist sie leer. Sie zeigt, wer
      zusieht - ein Zugriffsprotokoll ist sie nicht. Zum Aktualisieren die
      Seite neu laden."
    DATEN: `active()` aus `lib/presence.ts:38-41` — eine `Map` im
    Arbeitsspeicher des Next-Dienstes, Fenster 300 s, Sortierung nach
    `lastSeen` absteigend, höchstens 200 Einträge (`presence.ts:12-13`),
    gefüllt von `touch()` im BFF-Proxy
    (`app/api/dch/[...path]/route.ts:3`) und in
    `app/api/session/route.ts:2`. Felder: `name`, `role`, `lastSeen`,
    `agent`; `agent` ist die Kurzform des User-Agent (iPad, iPhone, Android,
    Mac, Windows, Linux, unbekannt — `presence.ts:16-24`).
    **Kein Endpunkt des Dienstes**: gesucht nach „presence", „session",
    „pair" in `docs/openapi.json`: kein Treffer (alle `/system`-Pfade sind
    update, geraet, geraet/verlauf, geraet/aktion, geraet/protokoll/{dienst},
    storage, speicher, coverage, door).

  * **„Platzbedarf"** (`page.tsx:116-124`)
    - Absatz 15 px `--text-2` wörtlich: „Eine verwaltete Datenbank wird nach
      Arbeitsspeicher abgerechnet, und den belegt sie im Wesentlichen mit ihrer
      eigenen Größe. Welche Tabelle das ist, lässt sich nicht erraten: bei
      schmalen Zeilen sind die Indizes regelmäßig größer als die Daten."
    - `StorageReport` (`components/settings/StorageReport.tsx:30-83`):
      Zustände in dieser Reihenfolge — Fehler → `<p>` 14 px `--text-3`
      „Die Größen konnten nicht abgefragt werden."; lädt → „lädt …";
      `tables.length === 0` → `data.note_de`; sonst Tabelle.
    - Tabelle: `mono w-full border-collapse text-[13px]`, in
      `div.overflow-x-auto`. Kopf `--text-3`, Rahmen nur unten
      (`border-b border-line-1`), Schrift normal: „Tabelle" (links),
      „Zeilen", „Daten", „Indizes" (rechts), „gesamt" (rechts).
      Zeilen: Name `--text-1`, Zeilen/Daten/Indizes `--text-2`,
      **gesamt in `--amber`**. Schlusszeile ohne Rahmen: „alle Tabellen",
      drei leere Zellen, rechts `total_bytes` in `--text-1`.
      Gezeigt werden `tables.filter(t => t.total_bytes > 0).slice(0, 8)`
      (`StorageReport.tsx:45`) — also höchstens acht, leere weg.
      Darunter `data.note_de`, 14 px / 1.6 / `--text-3`.
    - Maße: `mb()` (`StorageReport.tsx:21-24`) rechnet **binär**:
      ab 1024³ „X,XX GB" (max 2 Stellen), sonst „X,X MB" (max 1 Stelle),
      de-DE. `rows()` (`StorageReport.tsx:26-28`): ab 1000 „N Tsd."
      (gerundet), sonst die Zahl.
    - **Begründung im Code** (`StorageReport.tsx:7-19`): die Indizes stehen
      eigens, „bei schmalen Zeilen sind sie oft der größere Posten, und das
      sieht man nur, wenn es getrennt dasteht" (`StorageReport.tsx:65-66`);
      `measurements_raw` ist ein Zwischenspeicher, `DCH_RAW_RETENTION_DAYS`
      der einzige Regler.
    DATEN: `api.storage()` → `GET /system/storage`
    (`lib/api/client.ts:136`), Typ `StorageReportOut`
    (`lib/api/types.ts:6938`): `tables[]` mit `name`, `rows_estimate`,
    `table_bytes`, `index_bytes`, `total_bytes`; dazu `total_bytes`,
    `raw_retention_days`, `note_de`.

  * **„Sicherung"** (`page.tsx:126-156`)
    - Absatz 15 px `--text-2` wörtlich: „Die Datenbank ist die einzige Kopie.
      Ein verwaltetes Volume bei einem Anbieter ist kein Archiv: es überlebt
      keinen gelöschten Zugang und keinen Anbieterwechsel. Einmal im Jahr
      herunterladen und woanders ablegen - die Dateien sind
      gzip-komprimiertes CSV und lassen sich ohne dieses Programm lesen."
    - Zwei Zeilen, `[year, year - 1]` (`page.tsx:135`), je
      `flex flex-wrap items-baseline gap-x-4 gap-y-1 rounded-[3px]
      border border-line-1 bg-surface-2 px-4 py-3`: Jahr in Mono 14 px
      `--text-1`; zwei Anker 14 px in `text-amber` — „Minutenwerte ↓"
      (`/api/dch/export/minutes?year=Y`) und „Stundenbilanz ↓"
      (`/api/dch/export/hours?year=Y`); dahinter 13 px `--text-3`
      „Minutenwerte eines vollen Jahres: rund 20 MB gepackt".
    - Schlussabsatz 14 px / 1.6 / `--text-3` (`page.tsx:150-155`): „Die
      Stundenbilanz enthält auch die Grundlagen der PV-Abrechnung -
      Eigenverbrauch, Wiederbeschaffungswert und Umsatzsteuer. Sie gehört zu
      den Unterlagen, die aufzubewahren sind. Ein laufendes Jahr ist
      naturgemäß unvollständig; für den Abschluss im Januar erneut holen."
    DATEN: `GET /api/v1/export/{kind}` mit `kind` ∈ {minutes, hours} und
    `year` (2000-2100), alternativ `start`/`end`
    (`docs/openapi.json`, Pfad `/api/v1/export/{kind}`), Antwort ist eine
    Datei, kein JSON.

  * **„Sichtbarkeit"** (`page.tsx:158-166`) — ein Absatz 15 px `--text-2`,
    `gap-2`: die Seite ist für Suchmaschinen gesperrt über `robots.txt`, den
    `noindex`-Meta-Tag und den Header `X-Robots-Tag` (drei `code.mono` 13 px);
    „Ein Schutz vor unbefugtem Zugriff ist das nicht; dafür sorgt die
    Anmeldung."
    DATEN: keine.

  * **„Konfiguration"** (`page.tsx:168-175`) — ein Absatz 15 px `--text-2`:
    Regelparameter, Aktoren und Grenzwerte stehen in `CONFIGURATION.md`
    (`code.mono` 13 px) und im Entity-Mapping, „das die Bridge beim Start aus
    dem Repository lädt"; dazu ein Verweis „Wärme › Annahmen" →
    `/waerme/annahmen` in `text-amber`.
    DATEN: keine.

  * **Die Handy-Fassung** (`apps/web/src/styles/handy.css`) — die Route hat
    keine eigenen Regeln; was greift, greift über die Hülle und über die
    Tailwind-Größen:
    - `handy.css:109`: `.dashboard-bg { background: var(--deep) }` — Verlauf
      und 58-px-Raster fallen weg, nur noch #082431.
    - `handy.css:110-111`: `.report-main` wird `padding: 10px 16px
      calc(86px + env(safe-area-inset-bottom))` und `gap: 14px`,
      `font-size: 15px` — also 16 statt 20 Rand, 14 statt 16 Abstand, unten
      86 px für die Leiste.
    - `handy.css:112-134`: Bereichsleiste `.fussleiste` unten, fest, mit
      Namen; `handy.css:137-141`: der Kopf verliert Rahmen, Glas und
      Markenname, `.bereichstitel` wird 26 px halbfett sichtbar.
    - `handy.css:164-175`: die Reiter werden eine rollbare Reihe von Pillen
      (Radius 999, `rgba(255,255,255,.07)`, aktiv `--text-1`-Fläche auf
      `--deep`).
    - `handy.css:189-192`: **kleine Schrift eine Stufe größer** — 10→11,
      11→12, 12→13.5, 13→14.5. Auf dieser Route betrifft das: die `Row`-Note
      und die Hinweiszeilen (13→14.5), den Knopf von `CopyField` (11→12), in
      „Gerade verbunden" die Rolle und `ago` (12→13.5) und den Agenten
      (13→14.5), in „Platzbedarf" die ganze Tabelle (13→14.5).
      Der Kommentar nennt den Grund (`handy.css:187-188`): „Am Rechner liest
      man 12 Punkt aus sechzig Zentimetern, am Handy aus dreißig, aber im
      Gehen."
    - `AreaNav.tsx:96`: der Kicker „Geräte koppeln · wer zusieht · Daten
      sichern" ist `hidden … md:block` — **am Handy steht er nicht da.**
    - Was *nicht* greift: `handy.css:182-186` (`.card`, `.card-head`),
      `handy.css:196-208` (`.kpi-grid`), `handy.css:211-217` (`.methode`) —
      diese Seite benutzt keine Karten, keine Kennzahlkacheln und kein
      `Methode`. Gesucht nach „zugang", „system", „kopier", „pair",
      „geraete", „storage" in `handy.css`: kein Treffer. Die Seite bleibt am
      Handy also eine Spalte Fließtext mit größerer Kleinschrift; die
      max-760-Grenze wird dort nie wirksam.
    - `handy.css:1-27` (Kopfkommentar, die vier Entscheidungen) gilt auch
      hier als Auflage: „Flächen statt Rahmen", „Überschriften sind lesbare
      Schrift, keine Sperrschrift", „Tabellen werden Listen. Vier Spalten
      passen nicht auf 390 Punkte; gezeigt wird eine Spalte, die man
      umschaltet." Die Platzbedarf-Tabelle hat fünf Spalten und rollt im
      Browser seitwärts (`StorageReport.tsx:48`); in der App gilt dafür die
      Umschaltung von `Tabelle` (`Seiten/Bericht.swift:194-239`).

LUECKEN:

  [traegt-die-seite] Der ganze Abschnitt „Zugang einrichten" fehlt: zwei
    Pairing-Links mit Kicker, Wert, Kopierknopf und Note (`page.tsx:60-86`).
    Das ist die erste und namengebende Aussage der Seite („Geräte koppeln").
    Die App hat an dieser Stelle „Dieses Gerät" — ein anderes Thema (das
    Token *dieses* Geräts), nicht dasselbe in anderer Form.
    Einschränkung, nachgesehen: die Tokens sind Umgebungsvariablen des
    Web-Dienstes (`page.tsx:51-52`); gesucht nach „DCH_KIOSK_TOKEN",
    „DCH_GUEST_TOKEN", „pair" in `docs/openapi.json` und in
    `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift`: kein
    Treffer. Aus dem Dienst sind diese Links also nicht zu holen.

  [traegt-die-seite] Der Abschnitt „Platzbedarf" fehlt auf dieser Seite
    (`page.tsx:116-124`, Tabelle `StorageReport.tsx:46-82`). Er ist in der
    App gebaut, aber an der falschen Stelle: `DatenSeite.datenbestand(_:)`
    in `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:694-720`,
    Karte „Datenbestand", und der Kommentar dort
    (`SystemSeiten.swift:671-674`) weiß es: „In der Vorlage gibt es ihn auf
    dieser Seite gar nicht; er ist kein Fehler, nahm aber den Platz vor der
    Hauptsache ein."

  [traegt-die-seite] Der Abschnitt „Sicherung" fehlt ganz
    (`page.tsx:126-156`): Absatz, zwei Jahreszeilen mit je zwei
    Herunterladen-Verweisen, Schlussabsatz. Die App hat dafür heute kein
    Mittel: gesucht nach „openURL", „ShareLink", „Link(destination",
    „UIPasteboard" in `apps/ios`: kein Treffer.

  [traegt-die-seite] Der Abschnitt „Gerade verbunden" fehlt
    (`page.tsx:88-114`) — die Antwort auf „wer sieht gerade zu?", der zweite
    Teil des Bereichskickers. Nicht aus dem Dienst zu holen (siehe DATEN
    oben: kein `presence`-Endpunkt). Die App zeigt stattdessen in der Karte
    „Verbindung" `s.sseClients` (`Einrichten.swift:288`) — eine Zahl, keine
    Liste, und ohne Namen, Rolle, Gerät und Alter.

  [spuerbar] Der Abschnitt „Sichtbarkeit" fehlt (`page.tsx:158-166`):
    robots.txt, `noindex`, `X-Robots-Tag`, und der Satz, dass das kein
    Zugriffsschutz ist.

  [spuerbar] Der Abschnitt „Konfiguration" fehlt (`page.tsx:168-175`),
    samt dem Verweis auf `/waerme/annahmen`. Das Ziel gibt es in der App
    (`AnnahmenSeite`, `App/Seitenwahl.swift:82-83`), der Weg dorthin von
    hier nicht.

  [spuerbar] Der Fließtext der Vorlage steht sichtbar, in der App steht ein
    Fünftel davon zugeklappt. Die Vorlage hat sechs sichtbare Absätze à
    15 px plus vier Hinweisabsätze à 14 px (`page.tsx:62-68, 79-85, 108-113,
    118-122, 128-134, 150-155, 160-165, 170-174`); die App hat drei Sätze in
    einem zugeklappten `Methode` (`Einrichten.swift:328-338`,
    `Bericht.swift:357-360`). `Methode` ist für Rechenwege gedacht
    („Wie das gerechnet ist", `Bericht.swift:348`) — auf dieser Seite wird
    nichts gerechnet, hier steht die Bedienungsanleitung.

  [spuerbar] Die Gestalt ist eine andere: die Vorlage setzt sechs nackte
    `<section>` mit `<h2>` in 18 px halbfett und `max-w-[760px]`
    (`page.tsx:60-61`), die App setzt vier `Karte` mit Kicker
    (`Einrichten.swift:262, 281, 297, 314`). Am iPad heißt das: Rand und
    Fläche um Text, den die Vorlage ohne Kasten stehen lässt.

  [spuerbar] Die Reihenfolge stimmt nicht. Vorlage: koppeln → wer zusieht →
    Platzbedarf → Sicherung → Sichtbarkeit → Konfiguration. App: dieses
    Gerät → Verbindung → Mitteilungsgeräte → Ändern → Methode. Kein
    Abschnitt steht an der Stelle des gleichnamigen.

  [spuerbar] Die App zeigt eine Karte, die hier nicht hingehört:
    „Angemeldete Geräte für Mitteilungen" (`Einrichten.swift:296-313`). In
    der Vorlage steht diese Liste auf `/system/mitteilungen`
    (`components/settings/Mitteilungen.tsx:252-266`, `ul.geraete`,
    `globals.css:761-767`), nicht auf `/system/zugang`. Sie bringt hier
    außerdem die Begründungszeile nicht mit, die die Vorlage hat
    („angemeldet seit …", Zustand in `--amber-soft` bei schlechtem Stand,
    `Mitteilungen.tsx:74-76`).

  [spuerbar] Der Bereichskicker „Geräte koppeln · wer zusieht · Daten
    sichern" (`page.tsx:58`) hat in der App kein Gegenstück: gesucht nach
    „koppeln", „wer zusieht", „Daten sichern" in `apps/ios`: kein Treffer.
    Am Handy ist das kein Unterschied (`AreaNav.tsx:96`: `hidden … md:block`),
    am iPad schon.

  [spuerbar] Die Karte „Verbindung" (`Einrichten.swift:281-295`,
    Betriebsart, Fassung, Brücke, Anzeigen am Strom, Zeitversatz) hat auf
    dieser Route kein Gegenstück in der Vorlage. Gesucht nach „bridge",
    „sse", „version" in `page.tsx`: kein Treffer.

  [klein] Das Alter eines Zuschauers: die Vorlage rechnet „vor N s" unter
    60 s, sonst „vor N min", ohne Stundenstufe (`page.tsx:22-27`). Der Kern
    hat `Formate.alter(beobachtetAm:jetzt:)`
    (`Formate/Formate.swift:195-202`) — der schweigt unter 30 s und kennt
    eine Stundenstufe. Zwei verschiedene Regeln.

  [klein] Die Zeilenzahl: die Vorlage schreibt ab 1000 „N Tsd."
    (`StorageReport.tsx:26-28`), die App schreibt die ganze Zahl
    (`SystemSeiten.swift:712-714`: `Formate.zahl(…, stellen: 0)`).

  [klein] Die Spalten der Platzbedarf-Tabelle: Vorlage „Tabelle | Zeilen |
    Daten | Indizes | gesamt" mit „gesamt" in `--amber`
    (`StorageReport.tsx:52-56, 68`); App „gesamt | Daten | Index | Zeilen"
    ohne Farbe (`SystemSeiten.swift:705-715`). Dazu fehlen in der App die
    Obergrenze von acht Zeilen und der Filter `total_bytes > 0`
    (`StorageReport.tsx:45`) sowie die Schlusszeile „alle Tabellen"
    (`StorageReport.tsx:71-77`) — letztere steht in der App als `titel` der
    Karte (`SystemSeiten.swift:695`), nicht als Zeile unter der Tabelle.

  [klein] Die drei Zustände von `StorageReport` fehlen als Wörter:
    „Die Größen konnten nicht abgefragt werden.", „lädt …" und bei leerer
    Tabelle `note_de` (`StorageReport.tsx:41-43`). Die App hat an der
    verwandten Stelle keinen davon (`SystemSeiten.swift:675-677`:
    `if let b = bestand`), und auf der Zugangsseite verschluckt `try?`
    jeden Fehler (`Einrichten.swift:344`).

  [klein] Das Maß: `Platz`-Formatierung im Kern rechnet dezimal
    (`Zustand/Hausgeraet.swift:117-125`: 1e6, „MB"/„GB"/„TB"), die Vorlage
    binär (`StorageReport.tsx:21-24`: 1024²). Die App löst das heute mit
    einer privaten Kopie in der Ansicht
    (`SystemSeiten.swift:722-728`) — dieselbe Rechnung wie die Vorlage,
    aber am falschen Ort und mit `Formate.schmalesLeerzeichen` statt einem
    gewöhnlichen Leerzeichen.

  [klein] Die drei Wörter des Kopierknopfs („kopieren", „kopiert",
    „markiert") und die 2500-ms-Rückkehr (`CopyField.tsx:27, 42`) haben in
    der App kein Gegenstück, weil die App nichts zu kopieren anbietet.

  Gezählt: 4 × traegt-die-seite, 8 × spuerbar, 6 × klein = 18 Punkte.
  Vier von sechs Abschnitten der Vorlage fehlen vollständig, davon drei
  tragend; dazu ein Abschnitt in der App, der der Vorlage nach woanders
  hingehört, und eine neue Fähigkeit (Datei herunterladen, Text kopieren),
  die es in der App bisher nirgends gibt. Aufwand: gross.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `StorageReportOut` — `Modelle/Schema.swift:8913-8938`: `tables`
    (`[StorageTableOut]`), `totalBytes`, `rawRetentionDays`, `noteDe`;
    `StorageTableOut` mit `name`, `rowsEstimate`, `tableBytes`,
    `indexBytes`, `totalBytes` (`Schema.swift:8914` verweist darauf).
  * `Api.datenbestand() async throws -> StorageReportOut` —
    `Netz/Api.swift:373-375`, `GET /system/storage`. Im Demolauf geprüft
    (`Tests/DuckCurveKitTests/DemoLaufTests.swift:126`).
  * `PushGeraeteOut` / `PushGeraetOut` — `Schema.swift:7298-7309` bzw.
    `7265-7296` (`label`, `seit`, `zuletztOk`, `fehlversuche`,
    `letzterFehlerDe`); `Api.mitteilungGeraete()` — `Api.swift:469`.
  * `Zugang` — `Netz/Zugang.swift:40-116`: `grund`, `praefix`, `token`,
    `geraetename`, `rolle` (`.hausherr`/`.gast`), `geraetekennung`
    (`Zugang.swift:75-84`) und **`adresse(_:_:) -> URL?`**
    (`Zugang.swift:87-99`) — damit ist eine Export-Adresse schon baubar.
    Die Doku dort (`Zugang.swift:33-39`) nennt genau die Stelle, die diese
    Seite erklären muss: „in der App wäre sie nur eine ausgeblendete
    Schaltfläche. Wer das Token hat, darf am Dienst alles."
  * `Verbindung` (`.verbindet`, `.live`, `.verbindetNeu`, `.aus`) —
    `Netz/Verbindungspolitik.swift:4-13`.
  * `Bereiche`: der Reiter dieser Seite steht als
    `Reiter(weg: "/system/zugang", name: "Zugang und Sicherung",
    nurHausherr: true)` — `Bereiche/Bereiche.swift:170`. Alfreds Satz dazu:
    `Alfred/Alfred.swift:57`.
  * Marken: `amber` #F2A900, `amberWeich` #FFD778, `mist` #7FA3B3,
    `flaeche2` #123544, `linie1`/`linie2` (0.10/0.17), `text1/2/3`,
    `textKicker` — `Gestalt/Marken.swift:16-34` und
    `apps/ios/DuckCurveHome/Gestalt/Farben.swift:27-70`;
    Radien: `Marken.radius1` = 2, `radius2` = 3, `radius3` = 6
    (`Gestalt/Marken.swift:373-375`) — deckungsgleich mit `--radius-1/2/3`
    (`tokens.css:92-94`). Die `rounded-[3px]`-Kästen der Vorlage sind also
    `Marken.radius2`.
  * Formate: `zahl(_:stellen:)` (`Formate.swift:44`),
    `hhmm(iso:)` (`Formate.swift:148`), `alter(beobachtetAm:jetzt:)`
    (`Formate.swift:195`), `schmalesLeerzeichen` (`Formate.swift:23`),
    `leer` = „-" (`Formate.swift:27`).
  * `Hausgeraet.bytes(_:)` / `Hausgeraet.kurz(_:stellen:)` —
    `Zustand/Hausgeraet.swift:108-125` (dezimal; `kurz` ist genau
    `toLocaleString("de-DE", { maximumFractionDigits })`).
  * Bausteine: `Seite` (`App/Seitenwahl.swift:148-181`), `Karte`
    (`Gestalt/Karte.swift:15-113`), `Zeile` (`Karte.swift:360-383`),
    `Leer` (`Karte.swift:390-404`), `Stoerung` (`Karte.swift:410-436`),
    `Kachelfeld`/`Kachel` (`Karte.swift:158-343`),
    `Tabelle` mit Handy-Umschaltung und `immerSichtbar`
    (`Seiten/Bericht.swift:157-332`), `Methode`
    (`Bericht.swift:334-398`), `Kicker` (`Gestalt/Typografie.swift:132-141`),
    `Zahl` (`Typografie.swift:109-129`), `Zeichen`
    (`Gestalt/Zeichen.swift:43-93`) mit 24 Zeichenarten
    (`DuckCurveKit/Gestalt/Zeichendaten.swift:9-33`).
  * Wortsammlungen als Vorbild: `Pruefworte`
    (`Zustand/Datenbild.swift:511`), `Fahrplanworte`
    (`Zustand/Fahrplanworte.swift:15`), `Anlagenworte`
    (`Zustand/Anlagenworte.swift:14`), `Wiedergabeworte`
    (`Zustand/Wiedergabeworte.swift:10`).

ES FEHLT:

  1. **Ein Maß für Bytes nach der Regel der Vorlage.**
     `Formate.megabyte(_ bytes: Int) -> String` in
     `DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift` — binär,
     ab 1024³ „X,XX GB", sonst „X,X MB", de-DE, gewöhnliches Leerzeichen
     (Vorlage `StorageReport.tsx:21-24`). Damit verschwindet die private
     Kopie in `SystemSeiten.swift:722-728`, und `Hausgeraet.bytes`
     (dezimal, `Hausgeraet.swift:118`) bleibt für die Platte, wo es
     hingehört.

  2. **Ein Maß für Zeilenzahlen.**
     `Formate.zeilen(_ n: Int) -> String` (ebenfalls `Formate.swift`):
     ab 1000 „N Tsd.", sonst die gerundete Zahl
     (Vorlage `StorageReport.tsx:26-28`).

  3. **Ein Darsteller für den Datenbestand.**
     `Datenbestand` in `DuckCurveKit/Sources/DuckCurveKit/Zustand/` mit
     `public static func zeilen(_ b: StorageReportOut) -> [Zeile]` (Filter
     `totalBytes > 0`, höchstens acht, Reihenfolge wie geliefert) und
     `gesamt(_:) -> String`. Heute steckt diese Auswahl in einer privaten
     Funktion einer Ansicht (`SystemSeiten.swift:694-720`) und fehlt dort
     sogar (kein Filter, keine Obergrenze) — als Typ im Kern ist sie
     prüfbar und auf zwei Seiten verwendbar.

  4. **Eine benannte Export-Adresse.**
     `Zugang.export(art: Exportart, jahr: Int) -> URL?` in
     `Netz/Zugang.swift` (oder `Api.exportAdresse(…)`), `Exportart` =
     `.minuten`/`.stunden` → `/export/minutes` bzw. `/export/hours` mit
     `year`. Gesucht nach „export" in `Netz/Api.swift`: kein Treffer; der
     Pfad ist in `docs/openapi.json` als `/api/v1/export/{kind}` belegt
     (`kind` ∈ minutes, hours; `year` 2000-2100). `Zugang.adresse(_:_:)`
     (`Zugang.swift:87`) baut sie, aber ohne Namen und ohne das Wissen,
     welche Arten es gibt.

  5. **Die Worte dieser Seite als Daten.**
     `Zugangsworte` in `DuckCurveKit/Sources/DuckCurveKit/Zustand/` nach
     dem Muster von `Pruefworte` (`Datenbild.swift:511`): die sechs
     sichtbaren Absätze der Vorlage wörtlich, dazu die beiden Noten der
     Pairing-Zeilen und die Sätze zu Sichtbarkeit und Konfiguration. Sie
     tragen die Begründungen, die diese Seite *ist*; in einer SwiftUI-Datei
     wären es 60 Zeilen Zeichenkette ohne Test.

  6. **Nicht nachbaubar, braucht eine Entscheidung, keinen Kern:**
     die Pairing-Links (Tokens sind Web-Umgebungsvariablen) und die Liste
     „Gerade verbunden" (`presence` ist eine `Map` im Next-Dienst). Für
     beides gibt es im Dienst nichts — siehe LUECKEN. Was die App an deren
     Stelle sagen kann, steht im Bauplan.

BAUPLAN: `apps/ios/DuckCurveHome/App/Einrichten.swift`, `ZugangSeite`
neu ordnen, in der Reihenfolge der Vorlage. Die Seite wird dadurch lang;
das ist sie in der Vorlage auch.

  0. Vorarbeit im Kern, in dieser Reihenfolge (jeweils mit Test im
     bestehenden Testziel `DuckCurveKitTests`):
     `Formate.megabyte`, `Formate.zeilen` (Formate.swift),
     `Zustand/Datenbestand.swift`, `Zugang.export(art:jahr:)`
     (Zugang.swift), `Zustand/Zugangsworte.swift`.

  1. **Karte „Zugang einrichten"** (an die erste Stelle, vor „Dieses
     Gerät"). Inhalt: der Absatz aus `Zugangsworte` (Schrift.text, 15 pt,
     `Farbe.text2`), danach *keine* erfundenen Links, sondern eine
     ehrliche Zeile: dass die Pairing-Links am Dashboard stehen und warum
     (die App hat einen Schlüsselbund und braucht sie nicht —
     `Zugang.swift:12-16`), mit einem Verweis auf das Dashboard. Darunter
     der Schlussabsatz der Vorlage zur Sitzungsdauer (Sitzung, nicht Link;
     `DCH_GUEST_TOKEN` ändern) in Schrift.klein/`Farbe.text3`.
     Keine neue Fähigkeit nötig.

  2. **Karte „Dieses Gerät"** bleibt wie sie ist
     (`Einrichten.swift:262-280`) und rückt an die zweite Stelle — sie ist
     die Antwort der App auf die Pairing-Zeilen der Vorlage und gehört
     neben sie, nicht an ihre Stelle.

  3. **Karte „Gerade verbunden"**. Da es keinen Endpunkt gibt
     (nachgesehen, siehe DATEN): die Karte zeigt, was der Dienst hergibt —
     `s.sseClients` als Zahl mit dem Wort „Anzeigen am Strom" — und
     darunter in Schrift.winzig den Satz aus `Zugangsworte`, dass die
     Namensliste nur im Web-Dienst liegt und im Dashboard steht. Damit
     wandern die zwei Zeilen aus der heutigen Karte „Verbindung"
     (`Einrichten.swift:288`) hierher.

  4. **Karte „Platzbedarf"**. Absatz aus `Zugangsworte`, dann
     `Tabelle(zeilennamen:spalten:immerSichtbar:)`
     (`Bericht.swift:157-239`) mit `Datenbestand.zeilen(b)`:
     Spalten in der Reihenfolge der Vorlage — „Zeilen", „Daten",
     „Indizes", „gesamt" —, „gesamt" über `farben` in `Farbe.amber`
     (`Bericht.swift:166-170` erlaubt das ausdrücklich). `immerSichtbar: 1`
     (handy.css-Entscheidung 4), am iPad `volleTabelle`.
     Als `titel` der Karte `Formate.megabyte(b.totalBytes)` und darunter
     eine `Zeile` „alle Tabellen" — die Schlusszeile der Vorlage
     (`StorageReport.tsx:71-77`). Dann `Zeile(wort: "Rohwerte bleiben",
     wert: rawRetentionDays, einheit: "Tage")` wie heute auf der
     Datenseite, und `b.noteDe` als Absatz.
     Zustände: `Leer(satz: "lädt …")` solange `nil`, `Stoerung` bei Fehler
     (`Karte.swift:410`), `b.noteDe` bei leerer Tabelle — die drei
     Zustände der Vorlage (`StorageReport.tsx:41-43`).
     Gleichzeitig: `DatenSeite` (`SystemSeiten.swift:675-677, 694-728`)
     gibt die Karte ab und ruft `datenbestand()` nicht mehr; der Kommentar
     dort sagt selbst, dass sie in der Vorlage auf dieser Seite nicht
     vorkommt.

  5. **Karte „Sicherung"**. Absatz aus `Zugangsworte`; dann für
     `[jahr, jahr - 1]` je eine Zeile: Jahr in `Schrift.zahl`, daneben zwei
     Verweise „Minutenwerte ↓" und „Stundenbilanz ↓" in `Farbe.amber`,
     dahinter „Minutenwerte eines vollen Jahres: rund 20 MB gepackt" in
     `Schrift.winzig`/`Farbe.text3`. Der Verweis ist ein
     `ShareLink(item: Zugang.export(art:jahr:))` oder ein `Button` mit
     `@Environment(\.openURL)` — **beides neu in dieser App** (gesucht:
     kein Treffer). Dann der Schlussabsatz zur PV-Abrechnung.

  6. **Karte „Sichtbarkeit"** — ein Absatz aus `Zugangsworte`, Schrift.text,
     `Farbe.text2`; die drei Fachwörter (`robots.txt`, `noindex`,
     `X-Robots-Tag`) in `Schrift.zahl` wie die `code.mono` der Vorlage.

  7. **Karte „Konfiguration"** — ein Absatz aus `Zugangsworte`, mit einem
     Verweis „Wärme › Annahmen" in `Farbe.amber`, der
     `wegweiser.gehe("/waerme/annahmen")` ruft (Muster:
     `Gestalt/Karte.swift:181-184`).

  8. **Karte „Verbindung"** rutscht nach unten (sie hat in der Vorlage auf
     dieser Route kein Gegenstück) und verliert „Anzeigen am Strom" an
     Schritt 3. **Karte „Angemeldete Geräte für Mitteilungen"**
     (`Einrichten.swift:296-313`) verschwindet hier und gehört nach
     `MitteilungenSeite` (Vorlage `Mitteilungen.tsx:252-266`); dann
     entfallen auch `@State geraete` und der `.task`
     (`Einrichten.swift:258, 343-345`).

  9. **Karte „Ändern"** bleibt, als letzte Karte vor `Methode`.
     `Methode` behält die drei Sätze — aber nur die, die wirklich
     Begründung sind (Schlüsselbund, Gast blendet aus, Protokoll nennt das
     Gerät); alles, was die Vorlage sichtbar sagt, steht jetzt sichtbar
     oben.

WAS SCHWIERIG WIRD:

  * **Eine Datei herunterladen.** Die Vorlage ist ein `<a href>`, der
    Browser legt die Datei ab. In der App gibt es dafür nichts: gesucht nach
    „openURL", „ShareLink", „Link(destination", „UIPasteboard" in
    `apps/ios`: kein Treffer. Zwei Wege, und keiner ist im Projekt schon
    gewählt: `ShareLink(item: url)` reicht die Adresse an das Teilen-Blatt
    weiter — dann lädt Safari und **ohne** die `Authorization`-Kopfzeile
    (`Zugang.kopfzeilen`, `Zugang.swift:118-120`), die Datei kommt also nur
    bei einem Dienst ohne Token an; oder die App holt die Datei selbst über
    `Api` und bietet sie als `ShareLink(item: datei)` an — dann trägt sie
    das Token, muss aber einen Zwischenspeicher und eine Fortschrittsanzeige
    führen (eine Jahresdatei ist laut Vorlage „rund 20 MB gepackt",
    `page.tsx:145-147`). Vorbild für „Api liefert etwas, das keine
    JSON-Antwort ist", gesucht in `Netz/Api.swift`: nur `alfredStrom`
    (`Api.swift:574-580`) — ein Strom, keine Datei. Hier ist eine
    Entscheidung zu treffen, nicht eine Vorlage zu kopieren.

  * **Text kopieren.** `CopyField` (`CopyField.tsx:9-45`) hat drei Zustände,
    weil der Browser dabei versagen kann. `UIPasteboard` kann das nicht —
    in der App bleiben „kopieren" und „kopiert" übrig, der dritte Zustand
    („markiert") hat keinen Sinn. Soweit Schritt 1 überhaupt etwas
    Kopierbares zeigt (Adresse, Kennung), sollte das ein eigener Baustein
    `Kopierfeld` in `apps/ios/DuckCurveHome/Bausteine/` sein und nicht eine
    Zeile in dieser Seite.

  * **Fünf Spalten auf 390 Punkten.** Die Vorlage rollt die Tabelle
    seitwärts (`StorageReport.tsx:48`, `div.overflow-x-auto`);
    `handy.css:1-27`, Entscheidung 4, verbietet das für die App-Fassung
    („gezeigt wird eine Spalte, die man umschaltet"). Der Weg ist im
    Projekt gewählt: `Tabelle` mit `immerSichtbar`
    (`Bericht.swift:194-239`) und der Begründung an
    `Bericht.swift:175-183`, die auch die Ausnahme nennt
    (`handy.css:377-379`: die Raumtabelle darf drei Spalten
    nebeneinander behalten, weil eine die Differenz der anderen ist). Für
    den Platzbedarf gilt die Ausnahme nicht: `gesamt = Daten + Indizes`
    wäre ein Argument für drei Spalten, aber die Zeilenzahl gehört nicht
    dazu — also eine Spalte mit Umschaltung, `immerSichtbar: 1`.

  * **Fließtext in einer Karte.** Die Vorlage setzt sechs Abschnitte ohne
    Kasten mit `max-w-[760px]` (`page.tsx:60`); die App hat als einzige
    Textfläche `Karte` (`Gestalt/Karte.swift:15`), also immer einen Kasten
    (am iPad mit Haarlinie, am Telefon ohne Rand und heller —
    `Karte.swift:85-103`). Vorbild für „Absätze in einer Karte, mit
    Überschrift": `Methode` (`Bericht.swift:361-398`) und
    `SystemSeiten.swift:678-685`. Ein Abschnitt ohne Karte wäre neu; das
    Projekt hat sich für die Karte entschieden, und sechs Karten in Folge
    sind genau das, was `handy.css:3-6` als Fehler nennt
    („viereinhalb Bildschirme gleich schwerer Kästen"). Die Minderung:
    Absätze zusammenfassen, wo die Vorlage zwei Abschnitte mit einem Thema
    hat („Sichtbarkeit" und „Konfiguration" stehen dort schon mit `gap-2`
    statt `gap-3`, `page.tsx:158, 168`) — zwei Abschnitte, eine Karte.
