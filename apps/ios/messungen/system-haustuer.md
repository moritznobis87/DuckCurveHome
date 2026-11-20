========================= messen:system-haustuer   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:752-829`, erreicht über
`apps/ios/DuckCurveHome/App/Seitenwahl.swift:90-91`)

1. `Seite { }` ohne Zeitraumleiste (`:761`), Rand 16, Abstand 14
   (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:164-179`).
2. `Tagewahl(tage: $tage, moeglich: [7, 30, 90])` (`:762`), Startwert `tage = 7` (`:756`).
   Kapseln, 11,5 pt Sans, gewählt `amberWeich` auf `deep`
   (`apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift:181-203`).
3. Bei Fehler eine `Stoerung`-Box mit „Erneut" (`:763-765`,
   `apps/ios/DuckCurveHome/Gestalt/Karte.swift:410-435`).
4. `Kachelfeld` mit drei Kacheln und Kicker „Haustür" (`:767-777`): „Öffnungen" =
   `p.entries.filter(\.granted).count` (`:769`), „abgewiesen" = `!granted`, bei mehr als null in
   `Farbe.achtung` (`:770-773`), „Zeitraum" = `"\(p.days) Tage"` (`:774`).
5. `Karte(kicker: "Protokoll")` (`:778`). Leer: `Leer(satz: "In diesem Zeitraum wurde nicht
   aufgeschlossen.")` (`:780`). Sonst eine flache `VStack(spacing: 0)` über `p.entries` mit
   `Divider().overlay(Farbe.linie1)` zwischen den Zeilen (`:782-787`).
6. Eine Zeile (`eintrag(_:)`, `:798-817`): links ein 6×6-Punkt, `e.granted ? Farbe.mist :
   Farbe.alarm` (`:800-803`); daneben `e.actor` in 13 pt/`text1` (`:805`) und darunter
   `[e.door, e.method, e.reason]` mit „ · " verbunden in 11,5 pt/`text3` (`:806-808`); rechts
   `Formate.hhmm(iso: e.at)` in Mono 12,5/`text2` (`:812`) und darunter `e.outcome` in
   11,5 pt/`text3` (`:813`). Senkrechter Rand 6 (`:816`).
7. `Methode([p.noteDe])` (`:790`) - also eine zugeklappte Karte „Wie das gerechnet ist", ohne
   `kurz`; zugeklappt steht der Satz nicht da
   (`apps/ios/DuckCurveHome/Seiten/Bericht.swift:334-395`).
8. Vor der ersten Antwort `Karte { Leer(satz: "Wird geholt …") }` (`:792`).
9. Laden: `haus.api.haustuer(tage: tage)` bei jedem Wechsel von `tage` (`:795`, `:819-828`).

Kein Lauftext, keine Tagesgruppe, kein Datum, kein Seitenkicker.

VORLAGE:

  * **Hülle und Seitenkicker**  (`apps/web/src/app/system/haustuer/page.tsx:9`;
    `apps/web/src/components/layout/AreaShell.tsx:14-31`)
    `AreaShell kicker="Wer sich am Reader erkennen ließ, und was geschah"`. Der Kicker steht
    rechts in der Reiterzeile, `class="kicker"` mit `style={{ fontSize: 11 }}` und
    `hidden … md:block` (`apps/web/src/components/layout/AreaNav.tsx:96`): Mono, Versalien,
    Sperrung 0,13em, Farbe `--text-kicker` = `--mist` #7FA3B3
    (`apps/web/src/styles/globals.css:57-64`, `apps/web/src/styles/tokens.css:15,35`).
    **Am Handy ist er ausgeblendet** (`md` = 768 px), an der Wand steht er.
    Der Bereich ist dem Hausherrn vorbehalten, geprüft je Bereich und nicht je Seite
    (`apps/web/src/app/system/layout.tsx:1-10`, Begründung in `:3-4`).
    Seitentitel im Reiter des Browsers: „Haustür · Duck Curve Home" (`page.tsx:5`).
    DATEN: keine.

  * **Einleitender Absatz**  (`page.tsx:10-16`)
    Spalte mit `max-w-[860px]`, Abstand 12 (`gap-3`). Absatz 15 px, Zeilenhöhe 1,6,
    `text-text-2` (= rgba(255,255,255,.72), `tokens.css:33`). Wörtlich:
    „Von hier führt kein Weg zur Tür: die Entscheidung fällt im Haus, an einer Erlaubnisliste in
    der Bridge, und diese Seite liest nur mit. Abgelehnte Versuche stehen mit dabei; sie sind die
    eigentliche Auskunft, wenn man wissen will, ob jemand vor der Tür stand, den das Haus nicht
    kannte."
    BEGRÜNDUNG IM CODE (`apps/web/src/components/settings/DoorLog.tsx:8-21`, gehört in die
    Messung, weil sie entscheidet, was beim Umbau nicht verloren gehen darf):
    „**Nur lesen.** … Eine Schaltfläche „öffnen" an dieser Stelle wäre eine Haustür am Internet."
    - „**Auch die abgelehnten Versuche.** Ein Protokoll, das nur die geglückten Öffnungen zeigt,
    beantwortet die Frage nicht, wegen der man abends hineinsieht." - „**Nach Tagen gruppiert**,
    weil man so hineinsieht: nicht „der 412. Eintrag", sondern „gestern Abend". Innerhalb eines
    Tages steht der jüngste Eintrag oben."
    Dieselbe Begründung steht am Endpunkt (`apps/api/src/dch_api/routers/system.py:173-182`).
    DATEN: keine.

  * **Spannenwahl**  (`DoorLog.tsx:22`, `:100-116`)
    `SPANS = [7, 14, 30]`, Startwert `days = 14` (`:80`). Je Spanne ein `button` mit
    `aria-pressed`, Beschriftung „7 Tage" / „14 Tage" / „30 Tage". Form: `mono`,
    `rounded-[2px]`, 1 px Rand, `px-3 py-1`, 12 px. Gewählt: `border-amber text-amber`
    (#F2A900, `tokens.css:13`). Nicht gewählt: `border-line-1` (rgba(255,255,255,.10),
    `tokens.css:27`), `text-text-3` (rgba(255,255,255,.48)), bei Mauszeiger `text-2`.
    Keine Kapsel, keine Füllfläche.
    DATEN: steuert die Abfrage.

  * **Zustände**  (`DoorLog.tsx:84-95`, `:118-119`)
    Lädt: Absatz „lädt …", 14 px, `text-text-3` - **kein Kasten**. Bei jedem Wechsel der Spanne
    wird `data` vorher auf `null` gesetzt (`:85`), die Liste verschwindet also währenddessen.
    Fehler: Absatz „Das Türprotokoll konnte nicht geladen werden.", 14 px, `text-text-3`, ohne
    Knopf; neu geladen wird nur über die Spannenwahl.
    DATEN: `api.doorLog(days)` → `GET /system/door?days=…`
    (`apps/web/src/lib/api/client.ts:138`).

  * **Das Protokoll, je Kalendertag eine Kachel**  (`DoorLog.tsx:48-57`, `:121-134`)
    `groupByDay` legt die Einträge in der gelieferten Reihenfolge in Gruppen gleicher
    `new Date(e.at).toDateString()` (`:48-57`) - keine Sortierung, die Reihenfolge kommt vom
    Dienst (jüngster zuerst, `system.py:173`).
    Je Gruppe ein eigener Kasten: `rounded-[3px]`, 1 px `border-line-1`, Fläche
    `bg-surface-2` (#123544, `tokens.css:24`), `px-4 py-3`.
    **Dieser Kasten ist nicht `.card`**: die Handy-Regel `handy.css:182`
    (`border: 0; border-radius: 16px`) greift hier nicht. Am Telefon behält die Tagesgruppe
    also Haarlinie und 3 px Radius.
    Überschrift: `class="kicker"` mit `style={{ fontSize: 11 }}`, `mb-1` - Mono, Versalien,
    Sperrung 0,13em, `--mist`. Text aus `dayLabel(rows[0].at)` (`:24-32`): „Heute", „Gestern",
    sonst `toLocaleDateString("de-DE", { weekday: "long", day: "2-digit", month: "long" })`,
    also „Montag, 03. November" - **Wochentag ausgeschrieben, Tag zweistellig, kein Jahr**.
    Weil der Schriftgrad inline steht, hebt ihn die Handy-Schicht nicht an.
    DATEN: `DoorLogOut.entries[].at` (ISO).

  * **Eine Zeile**  (`DoorLog.tsx:59-77`)
    `flex flex-wrap items-baseline gap-x-3 gap-y-1`, unten 1 px `border-line-1`, `py-2`, bei
    der letzten Zeile kein Strich (`last:border-b-0`). Von links:
      1. Uhrzeit, `mono`, **feste Breite 44 px**, `shrink-0`, 13 px, `text-text-3`. Wert aus
         `time()` (`:34-36`): `toLocaleTimeString("de-DE", {hour:"2-digit",minute:"2-digit"})`,
         Zeitzone des Browsers.
      2. `e.actor || "unbekannt"`, 14 px, `text-text-1`.
      3. „per " + `methodLabel(e.method)`, 13 px, `text-text-3`. Die Abbildung (`:38-46`) mit
         ihrer Begründung im Kommentar: „„FACE" ist der Wert der Konsole. Auf einer Seite, die
         man liest, steht „Gesicht"." - FACE→Gesicht, NFC→Karte, PIN→Code,
         MOBILE_TAP|BT→Telefon, sonst der getrimmte Rohwert oder „unbekannt"; verglichen wird
         in Großbuchstaben.
      4. Rechts (`ml-auto`) eine `Pill` mit `e.outcome` als Text
         (`apps/web/src/components/ui/Pill.tsx:1-11`): Mono, 12 px, Versalien, Sperrung 0,08em,
         `rounded-[2px]`, `px-[10px] py-[4px]`, `whitespace-nowrap`. Drei Töne:
         `fehlgeschlagen` → alert (#E0533D auf rgba(224,83,61,.14), Rand rgba(224,83,61,.4)),
         `geöffnet` → amber (#F2A900 auf rgba(242,169,0,.14), Rand rgba(242,169,0,.35)),
         alles andere (also `abgelehnt`) → neutral (`text-2` auf rgba(255,255,255,.06), Rand
         `--line-2`).
         BEGRÜNDUNG IM CODE (`:68-69`): „Ein Fehlschlag ist etwas anderes als eine Ablehnung:
         dort hat das Haus nein gesagt, hier hat das Schloss nicht reagiert. Nur das zweite ist
         ein Defekt."
      5. Nur wenn **nicht** geöffnet und `e.reason` nicht leer: eine eigene Zeile über die
         ganze Breite (`w-full`), eingezogen `pl-[56px]` (= 44 px Uhrzeitspalte + 12 px
         Abstand), 13 px, Zeilenhöhe 1,5, `text-text-3`.
    `e.door` und `e.granted` **zeigt die Vorlage nicht** (gesucht nach `door`/`granted` in
    `DoorLog.tsx`: nur in der Typeinfuhr `:6`). Der Zustand kommt allein aus `outcome`.
    DATEN: `DoorEntryOut.at, actor, method, outcome, reason`
    (`apps/web/src/lib/api/models.ts:41,58` → `S["DoorEntryOut"]`).

  * **Der Satz des Dienstes**  (`DoorLog.tsx:136`)
    `data.note_de` als sichtbarer Absatz unter der Liste, 14 px, Zeilenhöhe 1,6,
    `text-text-3`. Kein Deckel, kein „Methode"-Block (gesucht nach `Methode` und `CoverageNote`
    in `page.tsx` und `DoorLog.tsx`: kein Treffer).
    Wortlaut kommt vom Dienst (`apps/api/src/dch_api/routers/system.py:189-195`):
    mit Einträgen „{n} Ereignisse in {span} Tagen, davon {opened} geöffnet.", wobei `opened`
    über `outcome == "geöffnet"` gezählt wird (`:189`); leer: „Noch kein Zutritt aufgezeichnet.
    Die Bridge meldet jeden Scan, sobald sie ihn sieht."
    Bei leerer Liste zeichnet die Vorlage **gar keinen Kasten** (`:121` `groups.length > 0`),
    nur diesen Satz.
    DATEN: `DoorLogOut.note_de`, `days`.

  * **Schlussabsatz**  (`page.tsx:18-22`)
    14 px, Zeilenhöhe 1,6, `text-text-3`, wörtlich:
    „Die Namen kommen aus UniFi Access und stehen in der Datenbank im Klartext. Deshalb steht
    diese Liste unter System und nicht auf der Startseite: ein Gast sieht sie nicht, und auf der
    Küchenanzeige hat sie nichts verloren."
    Dieselbe Abwägung steht in der Bridge (`apps/bridge/src/dch_bridge/door.py:125-127`).
    DATEN: keine.

  * **Handy-Fassung** (`apps/web/src/styles/handy.css`, Grenze `max-width: 720px`, `:107`)
    Diese Route hat **keine eigene Regel** (gesucht nach „haustuer", „door", „tuer" in
    `handy.css`: kein Treffer). Was sie trifft, trifft sie über die Hülle:
      - `.report-main`: Rand `10px 16px calc(86px + env(safe-area-inset-bottom))`, Abstand 14,
        Grundschrift 15 px (`:110-111`). Die Bereiche stehen unten als `.fussleiste`
        (`:114-134`), der Kopf gehört der Seite, `.bereichstitel` 26 px halbfett (`:141`).
      - Reiter als rollbare Pillen über den Seitenrand hinaus, ohne Strich darunter, mit
        Maske an den Rändern (`:164-175`).
      - Kleine Schrift eine Stufe größer (`:189-192`, Begründung im Kommentar: „Am Rechner
        liest man 12 Punkt aus sechzig Zentimetern, am Handy aus dreißig, aber im Gehen"):
        12 px → 13,5 px, 13 px → 14,5 px. **Betrifft auf dieser Seite**: die Spannenknöpfe
        (12→13,5), die Uhrzeit, „per …" und die Begründungszeile (13→14,5) und den Text der
        `Pill` (12→13,5). **Nicht betroffen**: `actor` (14 px), die beiden Absätze (15/14 px)
        und die Tagesüberschrift (inline 11 px).
      - Der Seitenkicker fällt weg (`AreaNav.tsx:96`, `hidden … md:block`).
      - `.card`-Regeln (`:182-185`) und `.methode`-Regeln (`:212-217`) greifen hier nicht, weil
        die Seite weder `.card` noch `.methode` benutzt.
    Der Kopfkommentar der Datei (`:1-26`) nennt die vier Entscheidungen; für diese Seite zählt
    vor allem „Flächen statt Rahmen" **mit der Einschränkung**, dass die Tagesgruppe eben kein
    `.card` ist und ihren Rand behält.

LUECKEN:

  [traegt-die-seite] Der einleitende Absatz fehlt ganz - und mit ihm die Hauptaussage der Seite
    („Von hier führt kein Weg zur Tür … Abgelehnte Versuche stehen mit dabei; sie sind die
    eigentliche Auskunft"). Vorlage `page.tsx:11-16`; in der App steht zwischen `Tagewahl`
    (`SystemSeiten.swift:762`) und `Kachelfeld` (`:767`) kein Satz. Gesucht nach „Erlaubnisliste",
    „Bridge", „liest nur mit", „abgelehnt" in `SystemSeiten.swift:752-829`: kein Treffer. Ohne
    ihn ist die Seite eine Liste ohne Begründung, warum sie nichts kann.

  [traegt-die-seite] Keine Tagesgruppe und kein Datum. Vorlage gruppiert je Kalendertag
    (`DoorLog.tsx:48-57`) und setzt „Heute" / „Gestern" / „Montag, 03. November" als
    Kicker über jede Gruppe (`:24-32`, `:121-134`); die App baut eine flache Liste über
    `p.entries` (`SystemSeiten.swift:782-787`) und nennt als einzige Zeitangabe `hhmm`
    (`:812`). Bei der App-Vorgabe 7 Tagen - wählbar bis 90 (`:762`) - stehen damit bis zu 500
    Zeilen (`MAX_DOOR_ENTRIES`, `system.py:164`) mit „07:12" ohne Tag untereinander. Gesucht
    nach „Tag", „Datum", „Heute", „Gestern", „Dictionary(grouping" in `:752-829`: kein Treffer.

  [spuerbar] Der Zustand ist keine Plakette und trägt keine Farbe. Vorlage: `Pill` mit drei
    Tönen, `fehlgeschlagen` rot, `geöffnet` amber, `abgelehnt` neutral, Mono/Versalien
    (`DoorLog.tsx:70`, `Pill.tsx:1-11`), mit der ausdrücklichen Begründung in `DoorLog.tsx:68-69`.
    Die App schreibt `e.outcome` in der kleinsten Schrift der Seite in `text3` (`:813`) und
    färbt stattdessen einen Punkt nach `e.granted` (`:801`). Weil `granted` bei
    „fehlgeschlagen" **wahr** ist (`apps/bridge/src/dch_bridge/door.py:101-109,144`), bekommt
    ein Defekt am Schloss denselben `mist`-Punkt wie eine geglückte Öffnung - genau die
    Unterscheidung, die der Kommentar der Vorlage festhält, geht verloren.

  [spuerbar] Die beiden Kennzahlkacheln zählen `granted`, nicht `outcome`
    (`SystemSeiten.swift:769-772`). `granted` ist die Entscheidung der Konsole; die Bridge
    lehnt danach selbst noch ab (Wiederholsperre, nicht freigegebene Tür/Person/Verfahren,
    `packages/hems-core/src/hems_core/control/door_access.py:117-149`) oder scheitert am
    Schloss (`door.py:101-109`). „Öffnungen" enthält also abgelehnte und fehlgeschlagene
    Versuche und widerspricht dem Satz des Dienstes, der über `outcome == "geöffnet"` zählt
    (`system.py:189`). Die Vorlage hat diese Kacheln überhaupt nicht.

  [spuerbar] `method` steht roh da. Die App setzt `e.method` unverändert in die Zeile
    (`:806`), die Vorlage übersetzt FACE→Gesicht, NFC→Karte, PIN→Code, MOBILE_TAP/BT→Telefon
    (`DoorLog.tsx:38-46`) und schreibt „per Gesicht". Gesucht nach „Gesicht", „FACE", „NFC",
    „MOBILE_TAP" in `apps/ios/DuckCurveHome` und `apps/ios/DuckCurveKit/Sources`: Treffer nur
    in `Modelle/Schema.swift` (Feldname), keine Abbildung.

  [spuerbar] Die Begründung steht immer da und doppelt den Rest der Zeile. Die App verbindet
    `[door, method, reason]` mit „ · " (`:806`); bei einer geglückten Öffnung ist `reason`
    aber `"{actor} an „{door}" per {method}."`
    (`door_access.py:149`), die Zeile liest sich also „Haustür · NFC · Anna an „Haustür" per
    NFC.". Die Vorlage zeigt `reason` nur, wenn **nicht** geöffnet wurde, und dann in einer
    eigenen eingezogenen Zeile (`DoorLog.tsx:72-74`).

  [spuerbar] `note_de` steckt hinter einem Deckel. Die App gibt es an `Methode([p.noteDe])`
    (`:790`) ohne `kurz`; zugeklappt - und das ist die Vorgabe
    (`apps/ios/DuckCurveHome/Seiten/Bericht.swift:346,355-357`) - steht nur „Wie das gerechnet
    ist" da. Die Vorlage zeigt den Satz immer (`DoorLog.tsx:136`), und er ist die einzige
    Zählung der Seite („… Ereignisse in … Tagen, davon … geöffnet.").

  [spuerbar] Der Schlussabsatz über UniFi Access, Klartext, Gast und Küchenanzeige fehlt
    (`page.tsx:18-22`). Gesucht nach „UniFi", „Klartext", „Küchenanzeige", „Gast" in
    `SystemSeiten.swift:752-829`: kein Treffer.

  [spuerbar] Der Seitenkicker „Wer sich am Reader erkennen ließ, und was geschah" fehlt
    (`page.tsx:9`, gezeichnet in `AreaNav.tsx:96`, nur ab 768 px). Die App hat keinen Platz
    dafür im Gerippe (`apps/ios/DuckCurveHome/App/Reiterzeile.swift:20-57` kennt kein
    Beiwerk) und auch keinen Kicker auf der Seite; andere Seiten setzen ihn selbst, z. B.
    `apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift:42` oder
    `apps/ios/DuckCurveHome/Seiten/Technik/WiedergabeSeite.swift:64`. Stattdessen trägt das
    `Kachelfeld` den Kicker „Haustür" (`:776`), was den Bereichsnamen wiederholt.

  [spuerbar] Die Zeile ist anders gebaut. Vorlage: Uhrzeit **zuerst**, Mono, in einer festen
    44-px-Spalte, damit die Zeiten untereinander stehen (`DoorLog.tsx:64`), danach Name und
    Verfahren, Plakette rechts. App: ein Punkt vorn (den die Vorlage nicht hat), Name und
    Detailzeile links, Uhrzeit und Zustand rechtsbündig in einer zweiten Spalte (`:799-814`).
    Nebeneinander sieht man sofort, dass die Uhrzeiten nicht als Spalte lesbar sind.

  [spuerbar] Die Spannen stimmen nicht: App 7/30/90 mit Vorgabe 7 (`:756`, `:762`), Vorlage
    7/14/30 mit Vorgabe 14 (`DoorLog.tsx:22`, `:80`). 90 Tage ohne Datum (siehe oben) ist der
    schlechteste Fall der Seite; 14 Tage fehlt ganz.

  [klein] Form der Spannenknöpfe: Vorlage rechteckig, `rounded-[2px]`, 1 px Rand, Mono 12 px,
    gewählt nur über Randfarbe und Schriftfarbe amber, ohne Füllung
    (`DoorLog.tsx:107-111`). App: Kapsel mit `amberWeich`-Füllung und `deep`-Schrift, 11,5 pt
    Sans (`WaermepumpeSeiten.swift:191-197`). `Rueckblickwahl`
    (`apps/ios/DuckCurveHome/Seiten/Technik/BetriebSeite.swift:325-338`) ist mit Rand und
    13 pt näher an der Vorlage, aber ebenfalls Kapsel und amber-gefüllt.

  [klein] Leerzustand: Vorlage zeichnet keinen Kasten und lässt den Satz des Dienstes sprechen
    („Noch kein Zutritt aufgezeichnet. Die Bridge meldet jeden Scan, sobald sie ihn sieht.",
    `system.py:193`, gezeigt über `DoorLog.tsx:136`). Die App schreibt einen eigenen Satz in
    eine Karte: „In diesem Zeitraum wurde nicht aufgeschlossen." (`:780`) - was etwas anderes
    behauptet (nicht aufgeschlossen gegen nichts aufgezeichnet) und abgewiesene Versuche
    unterschlägt.

  [klein] Ladezustand: Vorlage „lädt …" als Absatz, 14 px, `text3` (`DoorLog.tsx:119`); App
    `Karte { Leer(satz: "Wird geholt …") }` (`:792`), also ein leerer Kasten mit anderem Wort.

  [klein] Kein Ersatzname: Vorlage `e.actor || "unbekannt"` (`DoorLog.tsx:65`), App
    `Text(e.actor)` (`:805`) - bei leerem Feld (möglich, `system.py:208`) bleibt die Zeile
    namenlos.

  [klein] Die App zeigt `e.door` (`:806`), die Vorlage nie. Bei einer Tür ist das eine Spalte
    ohne Auskunft; sie steht zudem vor dem Verfahren und schiebt „per …" aus dem Blick.

  [klein] Fehlerfall: Vorlage ein Satz ohne Knopf („Das Türprotokoll konnte nicht geladen
    werden.", `DoorLog.tsx:91,118`), App eine `Stoerung`-Box mit „Erneut" (`:763-765`). Die
    Abweichung ist im Projekt bewusst gewählt und begründet
    (`BetriebSeite.swift:55-59`) - nicht zurückbauen, nur wissen, dass sie Absicht ist.

  [klein] Die Spalte der Vorlage ist auf 860 px begrenzt (`page.tsx:10`); die App-Seite läuft
    über die ganze Breite (`Seitenwahl.swift:175-176`). An der Wand werden die Zeilen damit
    sehr lang.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * Abfrage: `Api.haustuer(tage: Int) async throws -> DoorLogOut` →
    `GET /system/door?days=…` (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:369-371`).
    Deckungsgleich mit dem Web-Weg (`apps/web/src/lib/api/client.ts:138`).
  * Modelle: `DoorEntryOut` mit `at, actor, door, method, outcome, granted, reason`
    (`…/Modelle/Schema.swift:3049-3066`) und `DoorLogOut` mit `entries, days, noteDe`
    (Schlüssel `note_de`, `…/Schema.swift:3080-3100`). Alle Felder der Vorlage sind da.
  * Zusagen des Dienstes: `days` wird auf 1…90 geklemmt, `limit` auf 1…500
    (`apps/api/src/dch_api/routers/system.py:163-164,183-184`); jüngster Eintrag zuerst
    (`:173`); `outcome` ist eines von „geöffnet", „abgelehnt", „fehlgeschlagen"
    (`apps/bridge/src/dch_bridge/door.py:99,108,115`), ersatzweise „unbekannt"
    (`system.py:211`); `granted` ist „ja"/„nein" als Text im Ereignis (`system.py:212`,
    `door.py:144`).
  * Zeit: `Formate.hhmm(iso:)` („13:42", Zeit des Hauses, gerechnet statt formatiert, Begründung
    an `…/Formate/Formate.swift:136-151`); `Zeit.ausIso`; `Tag.nameRelativ(_:jetzt:)` liefert
    „Heute"/„Gestern"/„Morgen" (`…/Formate/Tag.swift:129-135`); `Formate.langesDatum(_:)` liefert
    „Samstag, 7. November" (`…/Formate/Formate.swift:184-189`); `Tag.lang(_:)` liefert
    „Samstag, 7. November 2026" (`…/Formate/Tag.swift:86-91`); `Tag.iso(_:)`, `Tag.plus(_:_:)`.
  * Farben und Maße: `Marken.amber` #F2A900, `amberWeich` #FFD778, `mist`, `alarm` #E0533D,
    `achtung` = amber, `gut` = mist (`…/Gestalt/Marken.swift:19,136-138`), `radius1 = 2`,
    `radius2 = 3`, `radius3 = 6` (`:373-375`); in SwiftUI als `Farbe.*`
    (`apps/ios/DuckCurveHome/Gestalt/Farben.swift:27-89`).
  * Schriften: `Schrift.klein` 13, `winzig` 11,5, `zahlKlein` Mono 12,5, `kicker` 10,5 gesperrt,
    `Schrift.sans(_:)` / `Schrift.mono(_:)` für Zwischengrößen
    (`apps/ios/DuckCurveHome/Gestalt/Typografie.swift:38-101`).
  * Bausteine: `Seite` (`App/Seitenwahl.swift:148-182`), `Karte` (`Gestalt/Karte.swift:15-104`),
    `Kicker` (`Gestalt/Typografie.swift:132-141`), `Leer` (`Gestalt/Karte.swift:390-404`),
    `Stoerung` (`:410-435`), `Methode` (`Seiten/Bericht.swift:334-395`, mit `kurz`),
    `Abzeichen` (Umriss-Plakette, `Seiten/Haus/Raumkachel.swift:333-352`),
    `Tagewahl` (`Seiten/Technik/WaermepumpeSeiten.swift:181-203`),
    `Rueckblickwahl` (`Seiten/Technik/BetriebSeite.swift:308-338`).
  * Berechtigung: der Reiter ist `nurHausherr`
    (`…/Bereiche/Bereiche.swift:167`), ausgeblendet in `Reiterzeile`
    (`apps/ios/DuckCurveHome/App/Reiterzeile.swift:26-28`); Alfred kennt die Seite
    (`…/Alfred/Alfred.swift:55`).
  * Vorbild für ein Protokoll mit Abzeichen und zwei Zeilen je Eintrag:
    `apps/ios/DuckCurveHome/Seiten/Haus/Raumprotokollblatt.swift:161-206`, mit den Worten im
    Kern (`…/Zustand/Raumprotokoll.swift:11-59`).

ES FEHLT:

  1. **Ein Wortmodul `Tuerprotokoll` im Kern** -
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Tuerprotokoll.swift`, gebaut wie
     `Raumprotokoll` (`…/Zustand/Raumprotokoll.swift:11-59`), mit Hinweis auf die Vorlage
     `apps/web/src/components/settings/DoorLog.tsx`:
       - `public static func verfahrenWort(_ m: String) -> String` - FACE→„Gesicht",
         NFC→„Karte", PIN→„Code", MOBILE_TAP|BT→„Telefon", sonst getrimmter Rohwert oder
         „unbekannt" (Vergleich in Großbuchstaben; `DoorLog.tsx:38-46`).
       - `public enum Zustandston { case geoeffnet, abgelehnt, fehlgeschlagen }` mit
         `public static func ton(_ outcome: String) -> Zustandston` - genau nach `outcome`,
         nicht nach `granted` (`DoorLog.tsx:60-61,70`).
       - `public static func gruppen(_ eintraege: [DoorEntryOut]) -> [(tag: String, eintraege: [DoorEntryOut])]`
         - Reihenfolge erhalten, Schlüssel `Tag.iso` der Zeit des Hauses
         (`DoorLog.tsx:48-57`).
       - `public static func zaehlung(_ e: [DoorEntryOut]) -> (geoeffnet: Int, abgelehnt: Int, fehlgeschlagen: Int)`
         über `outcome`, falls die Kacheln bleiben (`system.py:189`).
       - Texte als Konstanten, wie `Annahmenfelder`
         (`…/Zustand/Annahmenformular.swift:340`): `seitenkicker`, `einleitung`, `nachsatz`,
         `ladesatz` („lädt …"), `fehlersatz` („Das Türprotokoll konnte nicht geladen
         werden."), `spannen = [7, 14, 30]`, `vorgabe = 14`.
       - Dazu Tests in `apps/ios/DuckCurveKit/Tests` (Verfahrenswörter, Gruppenbildung über
         Mitternacht, Ton je `outcome`).
  2. **Ein Datum „Montag, 03. November"** - Tag ausgeschrieben, **zweistellig**, ohne Jahr.
     `Formate.langesDatum` (`Formate.swift:184-189`) gibt den Tag einstellig, `Tag.lang`
     (`Tag.swift:86-91`) hängt das Jahr an. Also `Tag.langOhneJahr(_ tag: String) -> String`
     mit `String(format: "%02d", …)` neben die bestehenden Formen, mit dem gleichen
     Begründungskommentar wie `Tag.tagMonat` gegen `Tag.punkt` (`Tag.swift:100-125`): die
     Vorlage schreibt denselben Tag an zwei Stellen auf zwei Arten, und beide Male mit Grund.
     Darüber `Tuerprotokoll.tagwort(_ tag: String, jetzt: Date)` =
     `Tag.nameRelativ(tag, jetzt:) ?? Tag.langOhneJahr(tag)`.
  3. **Eine gefüllte Plakette in der Oberfläche** - `Abzeichen`
     (`Seiten/Haus/Raumkachel.swift:333-352`) hat nur einen Umriss, 10,5 pt und keine Fläche;
     die Vorlage füllt mit 14 % der Farbe und umrandet mit 35-40 %, bei 12 px Mono
     (`Pill.tsx:1-11`). Entweder `Abzeichen` um `flaeche: Color?` und eine Mono-Schriftwahl
     erweitern oder `Plakette` daneben stellen, in `apps/ios/DuckCurveHome/Bausteine/`.

BAUPLAN (Karte für Karte, in der Reihenfolge der Vorlage):

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Tuerprotokoll.swift` **neu**: die Worte,
     die Verfahrensabbildung, der Ton je `outcome`, die Gruppenbildung, die Zählung, die
     Spannen. Tests dazu.
  2. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Tag.swift`: `langOhneJahr(_:)` ergänzen
     (zweistelliger Tag, kein Jahr), mit Kommentar warum neben `lang` und `langesDatum`.
  3. `apps/ios/DuckCurveHome/Bausteine/Plakette.swift` **neu** (oder `Abzeichen` erweitern):
     Mono, Versalien, Sperrung, `rounded 2`, Füllung 14 %, Rand 35-40 %, drei Töne.
  4. `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:752-829` umbauen, von oben:
     a. `Seite { }` behalten, Inhalt auf 860 Punkte begrenzen (`frame(maxWidth: 860,
        alignment: .leading)`).
     b. Seitenkicker: `if breite != .compact { Kicker(wort: Tuerprotokoll.seitenkicker) }` -
        wie `AnlageSeite.swift:42`, und nur an der Wand, weil die Vorlage ihn am Telefon
        ausblendet (`AreaNav.tsx:96`).
     c. Einleitender Absatz: `Text(Tuerprotokoll.einleitung)` in `Schrift.sans(15)`,
        `Farbe.text2`, `lineSpacing` für 1,6, `fixedSize(horizontal: false, vertical: true)` -
        Muster `BetriebSeite.swift:41-44`.
     d. Spannenwahl auf `Tuerprotokoll.spannen` (7/14/30) und Vorgabe 14 umstellen; Form an
        die Vorlage ziehen (Rechteck `Marken.radius1`, Rand, Mono 12, gewählt amber ohne
        Füllung). Entweder `Tagewahl` um eine Gestalt erweitern oder hier eine eigene Zeile
        bauen - **nicht** die Kapsel aus `WaermepumpeSeiten.swift:191-197` übernehmen.
     e. Die drei Kacheln: entweder streichen (die Vorlage hat sie nicht) oder auf
        `Tuerprotokoll.zaehlung` umstellen und „Öffnungen/abgewiesen/fehlgeschlagen" nennen.
        `granted` darf nicht mehr zählen.
     f. Statt einer `Karte(kicker: "Protokoll")` je Tagesgruppe **ein eigener Kasten**:
        `VStack` mit `Farbe.flaeche2`, `RoundedRectangle(cornerRadius: Marken.radius2)` und
        `strokeBorder(Farbe.linie1)`, Rand 16/12 - auch am Telefon mit Rand und 3 Punkt
        Radius, weil der Kasten der Vorlage kein `.card` ist (`handy.css:182` greift nicht).
        Darüber `Kicker(wort: Tuerprotokoll.tagwort(...))` in 11 Punkt.
     g. `eintrag(_:)` neu: Uhrzeit zuerst, `Schrift.mono(13)`, `frame(width: 44,
        alignment: .leading)`, `Farbe.text3`; dann `e.actor` leer → „unbekannt" in
        `Schrift.sans(14)`/`text1`; dann „per \(Tuerprotokoll.verfahrenWort(e.method))" in
        `Schrift.sans(13)`/`text3`; `Spacer`; `Plakette(wort: e.outcome, ton:
        Tuerprotokoll.ton(e.outcome))`. Punkt und `e.door` entfallen. Darunter, nur wenn
        `Tuerprotokoll.ton(e.outcome) != .geoeffnet` und `reason` nicht leer, eine zweite
        Zeile mit `padding(.leading, 56)` in 13/1,5/`text3`. Umbruch wie die Vorlage
        (`flex-wrap`) über `Umbruchzeile`
        (`apps/ios/DuckCurveHome/Gestalt/Umbruchzeile.swift:16`, benutzt in
        `BetriebSeite.swift:313`).
     h. Trennlinie unter jeder Zeile außer der letzten (Vorlage `last:border-b-0`), nicht
        zwischen den Zeilen wie heute (`:784`).
     i. `p.noteDe` als sichtbarer Absatz unter der Liste (14/1,6/`text3`), `Methode([p.noteDe])`
        bei `:790` entfernen. Wenn der Deckel bleiben soll, dann mit
        `Methode([], kurz: p.noteDe)`, damit der Satz zugeklappt sichtbar ist
        (`Bericht.swift:336-343`).
     j. Leerfall: keine Karte, nur `p.noteDe` (die Zeile des Dienstes sagt es bereits);
        `Leer(satz: "In diesem Zeitraum wurde nicht aufgeschlossen.")` bei `:780` streichen.
     k. Ladefall: Absatz `Tuerprotokoll.ladesatz` statt `Karte { Leer(…) }` (`:792`), wie
        `BetriebSeite.swift:38-45`.
     l. Schlussabsatz `Tuerprotokoll.nachsatz` in 14/`text3`.

WAS SCHWIERIG WIRD:

  * **Umbrechende Zeile.** Die Vorlage ist ein `flex-wrap` mit `gap-x-3 gap-y-1`
    (`DoorLog.tsx:63`): bei langem Namen rutscht die Plakette in die nächste Zeile, statt den
    Namen zu kürzen. SwiftUI hat dafür kein `HStack`. Im Projekt gewählter Weg:
    `Umbruchzeile` (`apps/ios/DuckCurveHome/Gestalt/Umbruchzeile.swift:16`), eingesetzt in
    `apps/ios/DuckCurveHome/Seiten/Technik/BetriebSeite.swift:313`. Vorbild für „Plakette
    rechts, aber umbruchfähig": `Seiten/Haus/Raumkachel.swift:85-93`.
  * **Die 44-Punkt-Spalte der Uhrzeit.** `w-[44px] shrink-0` ist in SwiftUI
    `frame(width: 44, alignment: .leading)` - aber mit „Größerer Text" aus den
    Bedienungshilfen bricht eine feste Breite. Im Projekt steht dafür `relativeTo` an jeder
    Schrift (`Gestalt/Typografie.swift:12-16,81-88`); Vorbild für eine feste Spalte neben
    skalierender Schrift: `Seiten/Technik/SystemSeiten.swift:935` (`frame(width: 92)` am
    Zahlenfeld) und `:950` (`frame(width: 42, alignment: .leading)` an der Einheit).
  * **Deckel oder nicht.** `Methode` ist in der App der Standardort für `*_de`-Sätze
    (`Bericht.swift:329-333`), die Vorlage hat auf dieser Seite aber bewusst keinen
    (gesucht nach `Methode` in `page.tsx` und `DoorLog.tsx`: kein Treffer). Der Satz ist hier
    die einzige Zählung; er darf nicht hinter einem zugeklappten Deckel stehen. Wenn der
    Deckel trotzdem gewollt ist, dann über `kurz` - dafür ist das Feld gemacht
    (`Bericht.swift:336-343`).
  * **Tagesgrenze.** Die Vorlage gruppiert über `new Date(e.at).toDateString()`, also in der
    Zeitzone des Browsers; die App rechnet grundsätzlich in der Zeit des Hauses, mit
    Begründung (`…/Formate/Formate.swift:132-134`). Für die Gruppen gilt die Hauszeit
    (`Tag.iso` mit `Kalender.haus`) - das ist eine bewusste Abweichung und soll so stehen,
    sonst wandert ein Zutritt um 00:30 für den Urlauber in den Vortag.
  * **Keine Diagrammfrage.** Die Seite hat kein Diagramm (gesucht nach `charts`, `Chart`,
    `svg` in `page.tsx` und `DoorLog.tsx`: kein Treffer); Swift Charts ist hier nicht im
    Spiel.
