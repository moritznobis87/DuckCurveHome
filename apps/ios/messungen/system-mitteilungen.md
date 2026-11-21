========================= messen:system-mitteilungen   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift`, Seite = `Seite { }`,
`App/Seitenwahl.swift:148-182`, Rand 16, Abstand 14, kein Seitenkopf)

1. Karte „Dieses Gerät" (`:59-101`): Kicker `Dieses Gerät`, Titel = `standsatz`
   (`:103-111`: „Noch nicht gefragt" | „Erlaubt" | „Abgelehnt" | „Angemeldet" | „Es klemmt"),
   darunter `erklaerung` in `Schrift.klein` (13 pt) / `Farbe.text2` (`:113-123`), darunter je
   Stand: Knopf „Mitteilungen erlauben" (`:68`), Satz „Abgelehnt. … Einstellungen › Duck Curve ›
   Mitteilungen." in `Schrift.winzig` (11,5)/`text3` (`:72-78`), Satz „Erlaubt, aber der Dienst
   kennt dieses Gerät noch nicht." in `Farbe.achtung` (`:80-82`), zwei Knöpfe „Probe senden" /
   „Abmelden" (`:84-92`), Fehlersatz in `achtung` (`:93-97`).
2. Karte „Morgenbrief" nur wenn `brief != nil` (`:26-28`, `:142-185`): Titel „kommt täglich um
   \(b.uhrzeit)" bzw. „abgeschaltet" (`:145`), Titelzeile `b.titel` in `Schrift.karte` (15)
   (`:148-150`), `b.zeilen` je eine Zeile `klein`/`text2` (`:151-159`), sonst
   `Leer(satz: "Heute stünde nichts darin.")` (`:161`), dann `b.fuerDe` roh (`:163-165`),
   `b.zuletztDe` (`:166-168`), `b.hinweisDe` in `achtung` (`:169-174`), und nur bei
   `haus.darfSchalten` zwei Knöpfe „Abschalten"/„Einschalten" + „Jetzt senden" (`:175-182`).
3. Karte „Angemeldete Geräte" nur wenn Liste nicht leer (`:29-38`): Titel = Anzahl,
   darunter je Gerät (`:187-214`) Name (`klein`/`text1`) und eine Zeile
   „seit HH:MM · zuletzt HH:MM" aus `Formate.hhmm(iso:)` (`:191-201`), rechts bei
   `fehlversuche > 0` „N Fehlversuche" in `achtung` plus `letzterFehlerDe` in `text3` (`:203-211`).
4. Karte mit `rueckmeldung`, wenn eine da ist (`:39-41`): ein Satz, `klein`/`text1`.
5. `Methode([...])` mit drei eigenen Sätzen über Web Push vs. APNs und den Signierschlüssel
   (`:42-52`; Baustein `Seiten/Bericht.swift:334-397`, zugeklappt, Titel „Wie das gerechnet ist").
6. Laden: `.task { await lade() }` (`:54`, `:249-255`) - `morgenbrief()` und
   `mitteilungGeraete()` parallel, Fehler werden mit `try?` verworfen; danach
   `mitteilungen.pruefeStand()`.

VORLAGE:

  * Hülle und Seitenkopf  (`apps/web/src/app/system/mitteilungen/page.tsx:9-19`)
    `AreaShell kicker="Was aufs Handy kommt: Störungen und das Morning Briefing"` (`:12`) - der
    Kicker steht rechts in der Reiterzeile (`components/layout/AreaShell.tsx:26`,
    `AreaTabs … right={kicker}`). Darunter `<section className="flex max-w-[760px] flex-col
    gap-3">` (`:13`) mit `<h2 className="m-0 text-[18px] font-semibold">Mitteilungen</h2>`
    (`:14`), dann die zwei Karten (`:15-16`).
    Maße: Spaltenbreite 760 px, Abstand 12 px (gap-3), Überschrift 18 px halbfett.
    DATEN: keine; `requireOwner()` (`:10`) sperrt die Seite für Gäste, `export const dynamic =
    "force-dynamic"` (`:6`).

  * Karte „Mitteilungen"  (`apps/web/src/components/settings/Mitteilungen.tsx:81-277`)
    Rahmen: `max-w-[760px] … gap-4 rounded-[3px] border border-line-1 bg-surface-2 p-5` (`:187`)
    → Radius 3 px, Linie `rgba(255,255,255,.10)` (`tokens.css:27`), Fläche `#123544`
    (`tokens.css:24`), Innenrand 20 px, Abstand 16 px.
    Kopf (`:188-193`): `span.kicker` mit **fontSize 11** im Markup (`:189`), also gegen
    `globals.css:57-63` (`.kicker`: Monoschrift, 13 px, `letter-spacing .13em`, Großbuchstaben,
    Farbe `--text-kicker` = `--mist`, `tokens.css:35`). Wortlaut „Mitteilungen". Darunter
    15 px / `line-height 1.6` / `--text-2`: „Wenn eine Quelle schweigt, meldet sich Duck Curve
    Home auf den angemeldeten Geräten, und morgens kommt das Morning Briefing. Jedes Gerät meldet
    sich einzeln an, hier auf dieser Seite." (`:190-193`).
    Lagen (`lib/push/lage.ts:13-21`, `pushLage()` `:61-70`): `prüfe` | `geht-nicht` |
    `ios-browser` | `verboten` | `aus` | `an`.
      - `ios-browser` (`:196-205`): Satz „Auf dem iPhone und iPad gehen Mitteilungen nur in der
        App vom Home-Bildschirm, nicht im Browser:" und eine `<ol>` mit drei Schritten
        („Unten auf Teilen tippen, dann „Zum Home-Bildschirm"." / „Duck Curve Home vom
        Home-Bildschirm öffnen." / „Dort wieder hierher: Technik, Mitteilungen, „Auf diesem Gerät
        einschalten"."), 14 px/1.6, `--text-2`.
      - `geht-nicht` (`:207-211`): „Dieser Browser kann keine Mitteilungen empfangen.", 14 px,
        `--text-3`.
      - `verboten` (`:213-219`): „Mitteilungen sind für Duck Curve Home auf diesem Gerät
        abgelehnt. Das lässt sich nur in den Einstellungen des Geräts zurücknehmen (auf dem
        iPhone: Einstellungen, Mitteilungen, Duck Curve), nicht von hier aus.", 14 px/1.6, Farbe
        **`var(--amber-soft)`** = `#ffd778` (`tokens.css:14`).
    Knöpfe (`:221-243`), alle in der Gestalt von `:184`:
    `rounded-[3px] border border-line-2 px-4 py-2 text-[14px] transition-colors hover:border-amber
    disabled:opacity-50` - also **durchsichtig mit Haarlinie** `rgba(255,255,255,.17)`
    (`tokens.css:28`), 16/8 px Innenrand, 14 px Schrift.
      - `aus`/`prüfe`: „Auf diesem Gerät einschalten", bei `prüfe` gesperrt (`:222-226`).
      - `an`: Satz „Dieses Gerät ist angemeldet." in `var(--pv)` = `--amber` `#f2a900`
        (`tokens.css:38`, `:13`), daneben „Probe senden" und „Ausschalten" (`:227-237`).
      - sonst, wenn fremde Geräte angemeldet sind: „Probe an die angemeldeten Geräte"
        (`:238-242`).
    Rückmeldung (`:245`) 14 px/1.6 `--text-2`; darunter **`details_de` als Liste** (`:246-250`),
    ein Punkt je Gerät, 14 px/1.6 `--text-2` (Inhalt: `apps/api/src/dch_api/routers/push.py:158`,
    `satz_de` je Gerät; `message_de` ist nur die Summe, `:157`).
    Geräteabschnitt (`:252-267`), sobald die Abfrage überhaupt geantwortet hat:
      - Kicker (11 px) mit Zählwort: „Kein Gerät angemeldet" | „1 Gerät angemeldet" |
        „N Geräte angemeldet" (`:254-256`).
      - **Bei null Geräten ein Warnsatz** in `var(--amber-soft)`, 14 px/1.6: „Solange kein Gerät
        angemeldet ist, gehen weder Störungen noch das Morning Briefing an jemanden." (`:257-260`).
      - sonst `<ul className="geraete">` (`:262-264`). Maße in `globals.css:761-766`:
        `.geraete` Spalte, `border-top 1px var(--line-1)`; `.geraet` ist ein Raster
        `minmax(0,1fr) auto`, `gap 2px 12px`, `padding 10px 0`, `border-bottom 1px var(--line-1)`,
        14 px/1.5; `.geraet-name` halbfett `--text-1`; `.geraet-seit` rechtsbündig 13 px
        `--text-3`; `.geraet-stand` über beide Spalten, `--text-2`, und mit
        `[data-schlecht="true"]` in `--amber-soft`.
      - Eine Gerätezeile (`:63-79`): Name; „angemeldet seit \(kurzDatum(seit))" (`:75`, leer wenn
        `seit` fehlt); und der **Zustandssatz** (`:64-71`) in dieser Reihenfolge:
        `letzter_fehler_de` ohne den vorangestellten „\(label): " → sonst
        „Zuletzt angenommen am \(kurzDatum), \(hhmm)." → sonst bei `fehlversuche > 0`
        „Noch keine Mitteilung angenommen, N Versuch/Versuche gescheitert. Eine Probe zeigt den
        Grund." → sonst „Noch keine Mitteilung verschickt.". `schlecht` (`:71`) = es gibt einen
        letzten Fehler **oder** nie angenommen bei Fehlversuchen > 0.
        Formate: `kurzDatum` (`components/waerme/wirkung.ts:109-112`, `:96`:
        `de-DE, Europe/Berlin, weekday short, day 2-digit, month 2-digit` → „Sa., 07.11.");
        `hhmm` (`lib/format/index.ts:39-45`, `de-DE, 2-digit, Europe/Berlin`).
    Fußnote (`:269-275`), 13 px/1.6 `--text-3`: „Eine Probe lohnt sich nach jedem Einschalten.
    Sie schickt das aktuelle Morning Briefing, so wie es unten steht. „Angenommen" heißt: Der
    Push-Dienst von Apple oder Google hat die Mitteilung entgegengenommen. Kommt trotzdem nichts,
    liegt es am Gerät selbst: Fokus oder „Nicht stören", oder die Mitteilungen der App sind in den
    Einstellungen abgeschaltet." - derselbe Satz steht als Begründung im Dienst
    (`apps/api/src/dch_api/routers/push.py:142-144`).
    Verhalten: beim Öffnen `pushLage()`, und wenn „an", **stille Neuanmeldung** desselben
    Abonnements (`:96-114`); Begründung im Kommentar `:101-104`: „nach einer neu aufgesetzten
    Datenbank stünde hier ‚angemeldet', und es käme nie etwas an". Erlaubnis nur aus einer
    Berührung (`:121-122`). Fehlerübersetzung `hinweis()` (`:50-56`): „Registration failed" →
    eigener Satz über Home-Bildschirm und gesperrte Push-Dienste, sonst „Das hat nicht geklappt:
    \(text)".
    DATEN (`lib/api/client.ts:161-167`): `GET /push/key` (`PushKey`), `POST /push/subscribe`,
    `POST /push/unsubscribe`, `POST /push/test` (`PushResult`), `GET /push/geraete`
    (`PushGeraete`). Felder: `PushGeraetOut { label, seit, zuletzt_ok, fehlversuche,
    letzter_fehler_de }` (`lib/api/types.ts:5911-5928`); `PushResultOut { ok, devices,
    message_de, details_de }` (`:5948-5957`).

  * Karte „Morning Briefing"  (`apps/web/src/components/settings/Morgenbrief.tsx:20-112`)
    Rahmen wie oben (`:65`). Kicker „Morning Briefing", 11 px (`:67`).
    Erklärung 15 px/1.6 `--text-2` mit der Uhrzeit **im Satz** und Rückfall „07:00" (`:68-71`):
    „Jeden Morgen um \(uhrzeit) Uhr eine kurze Mitteilung: wie viel Sonne zu erwarten ist, was
    Strom kostet, wie viel Wärme das Haus braucht und was sie kostet, geteilt in Strom und
    Pellets. Sie geht an alle Geräte, die für Mitteilungen angemeldet sind."
    Einordnungssatz, 13 px `--text-3` (`:74-78`): bei `fuer_de === "morgen"` → „Vom heutigen Tag
    ist zu wenig übrig. So sähe das Briefing morgen früh aus:", sonst „Das aktuelle Briefing, für
    den Rest von heute:". **`fuer_de` wird nie selbst gezeigt.**
    Vorschau (`:79-84`) als `.morgenbrief-vorschau` - die Mitteilungsblase des Telefons
    (`globals.css:756-758`): Spalte, `gap 4px`, `max-width 460px`, `padding 14px 16px`,
    `border-radius 14px`, Fläche `rgba(255,255,255,.07)`, 14 px/1.45, `--text-1`; `.morgenbrief-
    titel` halbfett. Titel-Rückfall „Morning Briefing" (`:81`). Sind keine Zeilen da, steht an
    ihrer Stelle `hinweis_de` in `--text-3` (`:82`) - **kein erfundener Satz und kein Warnton.**
    Zeile aus Zustand und Knöpfen (`:86-98`): Satz „Das Morning Briefing ist eingeschaltet." in
    `var(--pv)` bzw. „… ausgeschaltet." in `var(--text-3)` (`:89`), Knopf „Ausschalten"/
    „Einschalten" (`:90-92`), Knopf „Jetzt senden" - **gesperrt, solange keine Zeilen da sind**
    (`:93`). Knopfgestalt (`:18`): `rounded-[3px] border border-line-2 px-3 py-2 text-[13px]
    text-text-1`.
    Warnsatz (`:99-103`), wenn eingeschaltet und `geraete === 0`, in `var(--amber-soft)`,
    14 px/1.6: „Zurzeit ist kein Gerät für Mitteilungen angemeldet. Das Briefing geht deshalb an
    niemanden; oben auf dieser Seite lässt sich dieses Gerät anmelden."
    Dann `zuletzt_de` 13 px/1.6 `--text-3` (`:104`), die Rückmeldung 14 px `--text-2` (`:105`)
    und wieder `details_de` als Liste (`:106-110`).
    Fehlerzustände in Worten: Laden scheitert → „Das Morning Briefing ist gerade nicht zu
    erreichen." (`:30`); Schalten scheitert → „Das hat nicht geklappt. Die Einstellung ist
    unverändert." (`:43`); Senden scheitert → „Das Briefing ließ sich nicht verschicken." (`:58`).
    Ladezustand: solange `stand === null` steht **nur** Kicker und Erklärung (`:74`, `:87`).
    DATEN (`lib/api/client.ts:169-171`): `GET /push/morgenbrief`, `PUT /push/morgenbrief
    {enabled}`, `POST /push/morgenbrief/senden`. `MorgenbriefOut { enabled, uhrzeit, fuer_de,
    titel, zeilen, hinweis_de, zuletzt_de, geraete }` (`lib/api/types.ts:5536-5565`).

  * Handy-Fassung  (`apps/web/src/styles/handy.css`)
    Gesucht nach `mitteilungen`, `morgenbrief`, `geraet`, `system` in
    `apps/web/src/styles/handy.css`: **kein Treffer** - diese Route hat keine eigene
    Handy-Regel. `.morgenbrief-vorschau`, `.geraete`, `.geraet*` stehen ohne Breitenabfrage in
    `globals.css:756-766` und gelten daher am Handy unverändert.
    Was trotzdem greift (alles in `@media (max-width: 720px)`, ab `handy.css:107`):
      - `.report-main` 10/16 px Rand, unten `86px + safe-area`, `gap 14px`, Grundschrift 15 px
        (`:110-111`); Grund wird `--deep` statt Verlauf (`:109`).
      - Kopfzeile ohne Rahmen, Glas und Markenname (`:137-140`), Bereichsleiste wandert nach unten
        (`:114-134`), der Hüllen-Kicker steht als `.report-header-right > *` in einer eigenen
        Zeile mit Umbruch (`:148-154`).
      - Reiter werden rollbare Pillen (`:164-175`).
      - Kleine Tailwind-Schriften eine Stufe größer (`:189-192`): `text-[13px]` → 14,5 px. Das
        trifft auf dieser Seite die Fußnote (`Mitteilungen.tsx:269`), den Einordnungssatz, die
        Knöpfe und `zuletzt_de` des Briefings (`Morgenbrief.tsx:18`, `:75`, `:104`). **Nicht**
        getroffen: `.geraet-seit` (13 px in `globals.css:764`, keine Tailwind-Klasse).
      - `.card`-Regeln (`:182-185`) gelten hier **nicht**: diese Seite benutzt keine `.card`,
        sondern zwei handgesetzte Tailwind-Kästen (`Mitteilungen.tsx:187`, `Morgenbrief.tsx:65`),
        die am Handy ihren Rahmen und ihren 3-px-Radius behalten.
    Begründung der Datei im Kopf (`handy.css:3-26`), die beim Umbau zu halten ist: Flächen statt
    Rahmen, lesbare Überschriften statt Sperrschrift, Bereiche unten. `Gestalt/Karte.swift:6-14`
    führt das für die App schon aus (Radius 16, kein Rand, `flaeche2` am Telefon) - die beiden
    Kästen dieser Seite sind in der App also `Karte`, und die 3-px-Rahmen der Vorlage werden
    nicht nachgebaut.

LUECKEN:

  [traegt-die-seite] Die Warnung, dass **kein Gerät angemeldet** ist, fehlt an beiden Stellen.
    In der App verschwindet die Geräteliste bei null Geräten ganz (`MitteilungenSeite.swift:29`:
    `if let g = geraete, !g.devices.isEmpty`), und der Morgenbrief sagt nichts dazu
    (`:142-185` benutzt `b.geraete` nirgends). Die Vorlage sagt beides ausdrücklich
    (`Mitteilungen.tsx:257-260`, `Morgenbrief.tsx:99-103`), und genau das ist die Hauptaussage
    der Seite: der Kommentar nennt den 12.11.2026, an dem „im Haus keine einzige Mitteilung
    ankam" (`Mitteilungen.tsx:24-27`). Eine App-Seite, die dann nur „Angemeldet" und einen
    hübschen Brief zeigt, sagt das Gegenteil.

  [traegt-die-seite] Je Gerät fehlt der **Zustandssatz**. Die App zeigt „seit HH:MM · zuletzt
    HH:MM" (`MitteilungenSeite.swift:191-201`); die Vorlage zeigt „Zuletzt angenommen am Sa.,
    07.11., 06:12." / „Noch keine Mitteilung angenommen, 3 Versuche gescheitert. Eine Probe zeigt
    den Grund." / „Noch keine Mitteilung verschickt." bzw. den letzten Fehler des Push-Dienstes,
    und färbt die Zeile dafür (`Mitteilungen.tsx:64-71`, `globals.css:765-766`). Der Kommentar
    sagt, warum die Zeile so aussieht: vorher stand „an 0 von 1 Geräten zugestellt", und warum,
    stand nur im Protokoll (`Mitteilungen.tsx:24-27`).

  [traegt-die-seite] Nach einer Probe fehlt **`details_de`**, der Grund je Gerät. Die App zeigt
    nur `messageDe` (`MitteilungenSeite.swift:221-225`, `239-246`), und das ist die Summe
    („… ging an 2 Geräte; der Push-Dienst hat 1 davon angenommen.",
    `apps/api/src/dch_api/routers/push.py:157`). Die Vorlage listet beide Male `details_de`
    (`Mitteilungen.tsx:246-250`, `Morgenbrief.tsx:106-110`), also `satz_de` je Gerät (`push.py:158`).
    Das Feld ist im Kern schon da (`Schema.swift:7340`).

  [spuerbar] `fuerDe` wird roh gezeigt. Die App setzt „heute" bzw. „morgen" als eigene Zeile
    (`MitteilungenSeite.swift:163-165`); die Vorlage macht daraus einen Satz und zeigt das Wort
    nie (`Morgenbrief.tsx:74-78`).
  [spuerbar] Die Vorschau ist keine **Mitteilungsblase**. Die App setzt Titel und Zeilen nackt in
    die Karte (`MitteilungenSeite.swift:147-159`); die Vorlage hat die Blase des Telefons:
    Radius 14, Fläche `rgba(255,255,255,.07)`, 460 px breit, 14/1.45 (`globals.css:757-758`).
  [spuerbar] Der erklärende Satz beider Karten fehlt. App: `erklaerung` ist ein anderer Text und
    nur zweistufig (`MitteilungenSeite.swift:113-123`), beim Morgenbrief gar keiner. Vorlage:
    15 px/1.6 „… Jedes Gerät meldet sich einzeln an, hier auf dieser Seite."
    (`Mitteilungen.tsx:190-193`) und „Jeden Morgen um 07:00 Uhr eine kurze Mitteilung: …"
    (`Morgenbrief.tsx:68-71`).
  [spuerbar] Die Fußnote über „Angenommen", Fokus und „Nicht stören" fehlt
    (`Mitteilungen.tsx:269-275`). Die App hat an ihrer Stelle drei andere Sätze über APNs
    (`MitteilungenSeite.swift:42-52`) - die gehören dort hin, ersetzen aber nicht die Auskunft,
    was „angenommen" heißt und wo es trotzdem hängen bleibt.
  [spuerbar] „Probe an die angemeldeten Geräte" fehlt. Die App kann nur proben, wenn *dieses*
    Gerät angemeldet ist (`MitteilungenSeite.swift:83-85`); die Vorlage bietet den Knopf auch
    sonst, sobald fremde Geräte in der Liste stehen (`Mitteilungen.tsx:238-242`).
  [spuerbar] `seit` wird als **Uhrzeit** gezeigt. `Formate.hhmm(iso:)` auf einen Anmeldezeitpunkt
    (`MitteilungenSeite.swift:193`) ergibt „seit 14:23" - der Tag fällt weg. Vorlage: „angemeldet
    seit Sa., 07.11." (`Mitteilungen.tsx:75`, `wirkung.ts:109-112`).
  [spuerbar] „Jetzt senden" ist nicht gesperrt, wenn das Briefing leer ist
    (`MitteilungenSeite.swift:180` gegen `Morgenbrief.tsx:93`).
  [spuerbar] `hinweisDe` ist falsch eingesetzt. Die App erfindet „Heute stünde nichts darin." und
    stellt `hinweisDe` daneben in `achtung` (`MitteilungenSeite.swift:160-174`); die Vorlage setzt
    `hinweis_de` **an die Stelle** der Zeilen, grau (`Morgenbrief.tsx:82`).
  [spuerbar] Fehler bleiben stumm. `try?` an vier Stellen (`MitteilungenSeite.swift:221`, `234`,
    `242`, `250-251`); die Vorlage hat drei Sätze dafür (`Morgenbrief.tsx:30`, `:43`, `:58`) und
    `hinweis()` für die Mitteilungen (`Mitteilungen.tsx:50-56`). Nur beim Senden steht in der App
    überhaupt etwas, und beim Schalten gar nichts.
  [spuerbar] Knopfgestalt. App: gefüllt `amberWeich` mit `deep`-Schrift, 14/8, Radius 6,
    `Schrift.klein` 13 (`MitteilungenSeite.swift:125-138`). Vorlage: durchsichtig mit Haarlinie
    `--line-2`, 16/8, 14 px, Rand wird amber beim Zeigen (`Mitteilungen.tsx:184`;
    `Morgenbrief.tsx:18` ist dieselbe Gestalt in 12/8 und 13 px).
  [spuerbar] Warnfarbe. Die Vorlage warnt auf dieser Seite durchweg in `--amber-soft` `#ffd778`
    (`Mitteilungen.tsx:214`, `:258`, `globals.css:766`, `Morgenbrief.tsx:100`); die App nimmt
    `Farbe.achtung`, und das ist `amber` `#f2a900` (`Marken.swift:98`, `:18`). Richtig wäre
    `Farbe.amberWeich` (`Marken.swift:19`, derselbe Wert wie `--amber-soft`, `tokens.css:14`).
  [spuerbar] Der Zustandssatz des Briefings fehlt neben den Knöpfen. Vorlage: „Das Morning
    Briefing ist eingeschaltet." in `--pv` bzw. ausgeschaltet in `--text-3`
    (`Morgenbrief.tsx:89`); die App steckt das in den Kartentitel
    (`MitteilungenSeite.swift:145`), wo es ohne Farbe steht.

  [klein] Der Kicker der Hülle fehlt: „Was aufs Handy kommt: Störungen und das Morning Briefing"
    (`page.tsx:12`). Gesucht nach dem Satz in `apps/ios`: kein Treffer; `Reiter`
    (`Bereiche/Bereiche.swift:45-65`) hat kein Feld dafür, und `Bereiche.swift:166` führt nur
    `name: "Mitteilungen"`.
  [klein] Die Überschrift `h2 "Mitteilungen"` in 18 px halbfett fehlt (`page.tsx:14`).
  [klein] Die Karten-Kicker heißen anders: Vorlage „Mitteilungen" / „Morning Briefing"
    (`Mitteilungen.tsx:189`, `Morgenbrief.tsx:67`), App „Dieses Gerät" / „Morgenbrief"
    (`MitteilungenSeite.swift:60`, `:144`).
  [klein] Das Zählwort fehlt: „Kein Gerät angemeldet" / „1 Gerät angemeldet" / „N Geräte
    angemeldet" (`Mitteilungen.tsx:254-256`) gegen Kicker „Angemeldete Geräte" + Zahl als Titel
    (`MitteilungenSeite.swift:30`).
  [klein] Die Spaltenbreite 760 px fehlt (`page.tsx:13`, `Mitteilungen.tsx:187`,
    `Morgenbrief.tsx:65`); `Seite` setzt nur den Rand (`Seitenwahl.swift:175-176`).
  [klein] Trennlinien der Geräteliste: Vorlage hat `border-top` an der Liste und `border-bottom`
    an jeder Zeile, also auch unter der letzten (`globals.css:761-762`); die App setzt `Divider`
    nur zwischen Zeilen (`MitteilungenSeite.swift:33`).
  [klein] Benennung: die Vorlage sagt auf dieser Seite „Morning Briefing"
    (`Morgenbrief.tsx:67`, `:89`, `Mitteilungen.tsx:192`), die App „Morgenbrief"
    (`MitteilungenSeite.swift:144`).
  [klein] Der Rückfall „07:00" für die Uhrzeit fehlt (`Morgenbrief.tsx:69`); die App zeigt die
    Karte erst, wenn `brief` da ist, und hat dafür keinen Platzhalter.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * Abfragen, alle fünf: `mitteilungSchluessel()` `Netz/Api.swift:453`, `meldeGeraetAn(_:)` `:457`,
    `meldeGeraetAb(endpunkt:)` `:461`, `mitteilungProbe()` `:465`, `mitteilungGeraete()` `:469`.
  * Morgenbrief: `morgenbrief()` `Api.swift:474`, `stelleMorgenbrief(an:)` `:478`,
    `sendeMorgenbrief()` `:482`.
  * APNs-Weg, den die Vorlage nicht hat: `meldeApnsAn(…)` `Api.swift:535`, `meldeApnsAb(token:)`
    `:651`.
  * Modelle: `MorgenbriefOut` `Modelle/Schema.swift:6703-6722` - **mit `geraete`** (`:6711`);
    `PushGeraetOut` `:7265-7286` (`label`, `seit`, `zuletztOk`, `fehlversuche`,
    `letzterFehlerDe`); `PushGeraeteOut` `:7298-7309`; `PushResultOut` `:7336-7354` - **mit
    `detailsDe`** (`:7340`); `PushKeyOut` `:7315-7334`; `PushSubscribeIn` `:7365-7387`.
  * Erlaubnis und Anmeldung dieses Geräts: `Mitteilungen` (`apps/ios/DuckCurveHome/Mitteilungen/
    Mitteilungen.swift:30`), `Stand` `:32-39`, `pruefeStand()` `:61-73`, `frage()` `:92-106`,
    `tokenKam(_:)` `:137-141`, `meldeAb()` `:167-171`, Fehlerübersetzung für die fehlende
    Push-Berechtigung `:121-130`. Die stille Neuanmeldung der Vorlage
    (`Mitteilungen.tsx:101-111`) tut hier `:134-136` bei jedem Start.
  * Formate: `Formate.hhmm(iso:)` `Formate/Formate.swift:148`, `Tag.kurz(_:)`
    `Formate/Tag.swift:94-98` („Sa, 7.11." aus `YYYY-MM-DD`), `Zeit.wochentag(_:kurz:)`
    `Formate/Zeit.swift:145-148` mit `wochentageKurz` ohne Punkt (`:135`).
  * Farben und Maße: `Marken.amberWeich` `Gestalt/Marken.swift:19` = `--amber-soft`;
    `Marken.pv` `:50`; `Marken.achtung` `:98`; `radius3 = 6` `:313`; `Farbe.*`
    `apps/ios/DuckCurveHome/Gestalt/Farben.swift:30-69`.
  * Bausteine: `Karte` (Kicker/Titel/Beiwerk, Telefon ohne Rand, Radius 16)
    `Gestalt/Karte.swift:15-104`, `Zeile` `:360-383`, `Leer` `:390-404`, `Stoerung` `:410-436`,
    `Kicker` `Gestalt/Typografie.swift:132`, `Methode` `Seiten/Bericht.swift:334-397`,
    `Seite` `App/Seitenwahl.swift:148-182`.
  * Schriften: `Schrift.karte` 15 (`Typografie.swift:42`), `klein` 13 (`:45`), `winzig` 11,5
    (`:46`), `sans(_:)` (`:86`).
  * Weg und Reiter: `Bereiche.swift:166`, Wahl `App/Seitenwahl.swift:88-89`,
    Alfred-Satz `Alfred/Alfred.swift:54`.

ES FEHLT:

  1. **Ein kurzes Datum aus einem Zeitstempel.** Die Vorlage braucht „Sa., 07.11."
     (`wirkung.ts:96`, `:109-112`: `weekday: "short", day: "2-digit", month: "2-digit"`).
     Im Kern gibt es nur `Tag.kurz(_:)` (`Formate/Tag.swift:94-98`), das einen Kalendertag
     `YYYY-MM-DD` nimmt und „Sa, 7.11." liefert - anderer Eingang, anderer Punkt, keine führende
     Null. Vorschlag: `public static func kurzDatum(iso: String?) -> String` in
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift` (neben `hhmm(iso:)`,
     `:148`), mit `Zeit.wochentag(_:kurz: true)` plus Punkt und `%02d.%02d.`, und einem Test,
     der „Sa., 07.11." festhält - so wie `Tag.punkt(_:)` seine zweite Form begründet
     (`Tag.swift:112-125`).

  2. **Der Zustandssatz eines Geräts als Rechnung, nicht als Ansicht.** Die Vorlage entscheidet in
     vier Stufen und gibt dazu ein Kennzeichen `schlecht` (`Mitteilungen.tsx:64-71`). Vorschlag:
     neue Datei `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Mitteilungsstand.swift` mit
     `public struct Geraetezeile: Sendable { public let name: String; public let seit: String?;
     public let stand: String; public let schlecht: Bool }` und
     `public static func zeilen(_ g: PushGeraeteOut) -> [Geraetezeile]`, dazu
     `public static func zaehlwort(_ n: Int) -> String` für „Kein Gerät angemeldet" / „1 Gerät
     angemeldet" / „N Geräte angemeldet" (`Mitteilungen.tsx:254-256`). Das Abschneiden des
     „\(label): "-Vorsatzes (`Mitteilungen.tsx:65`) gehört dort hinein, nicht in die Ansicht.
     Tests: ein Gerät je Stufe, und die Einzahl „1 Versuch" gegen „3 Versuche"
     (`Mitteilungen.tsx:69`).

  3. **Der Einordnungssatz des Briefings.** Aus `fuer_de` wird ein Satz (`Morgenbrief.tsx:76`).
     Vorschlag: `public static func einordnung(_ brief: MorgenbriefOut) -> String` in derselben
     neuen Datei, damit das Wort „morgen" nicht in der Ansicht abgefragt wird.

  Gesucht nach einer vorhandenen Rechnung dafür: `grep -rn "Morgenbrief\|PushGeraet" apps/ios/
  DuckCurveKit/Sources/DuckCurveKit/Zustand/` - kein Treffer. Alles andere, was die Seite braucht
  (Abfragen, Felder, Farben, Maße, Formate der Uhrzeit), ist da.

BAUPLAN:

  1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift`: `kurzDatum(iso:)`
     ergänzen (Punkt 1 oben) plus Test.
  2. Neu: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Mitteilungsstand.swift` -
     `Geraetezeile`, `zeilen(_:)`, `zaehlwort(_:)`, `einordnung(_:)` (Punkte 2 und 3) plus Tests.
  3. `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift`, Karte für Karte in der
     Reihenfolge der Vorlage:
     a. Oben eine Überschriftzeile: der Kicker der Hülle und „Mitteilungen" in
        `Schrift.sans(18)` halbfett - oder, wenn der Kicker ins Gerippe soll, ein Feld
        `kicker` an `Reiter` (`Bereiche/Bereiche.swift:45-65`) und eine Zeile im Rahmen; dann
        trifft es alle sechs Technikseiten zugleich und gehört in eine eigene Messung.
     b. Karte 1 (Kicker „Mitteilungen"): der erklärende Satz aus `Mitteilungen.tsx:190-193`;
        darunter der Stand dieses Geräts wie bisher, aber `abgelehnt` und `fehler` in
        `Farbe.amberWeich`; Knöpfe auf die Gestalt der Vorlage (Rand `linie1`, durchsichtig,
        `Schrift.sans(14)`, Radius `Marken.radius3`); bei `.angemeldet` zusätzlich der Satz
        „Dieses Gerät ist angemeldet." in `Farbe.pv`; „Probe an die angemeldeten Geräte",
        wenn dieses Gerät nicht angemeldet ist, die Liste aber nicht leer.
     c. Danach `rueckmeldung` **in derselben Karte** und darunter `detailsDe` als Liste
        (ein `VStack` mit `Schrift.sans(14)`), nicht als eigene Karte am Seitenende.
     d. Noch in Karte 1: der Geräteabschnitt - Zählwort als zweiter Kicker; bei null Geräten der
        Warnsatz in `amberWeich`; sonst die Liste aus `Mitteilungsstand.zeilen(_:)` mit Name
        (halbfett `text1`), „angemeldet seit \(Formate.kurzDatum(iso:))" rechts in
        `Schrift.sans(13)`/`text3`, und dem Zustandssatz über die ganze Breite in `text2` bzw.
        `amberWeich` bei `schlecht`. Trennlinie unter jeder Zeile, auch der letzten.
     e. Am Ende von Karte 1 die Fußnote aus `Mitteilungen.tsx:269-275` in `Schrift.winzig`/`text3`.
     f. Karte 2 (Kicker „Morning Briefing"): der Satz mit der Uhrzeit und dem Rückfall „07:00";
        `Mitteilungsstand.einordnung(_:)`; die Vorschau als Blase - ein `VStack(spacing: 4)` mit
        `padding(.init(top: 14, leading: 16, bottom: 14, trailing: 16))`,
        `.background(Color.white.opacity(0.07))`,
        `.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))`,
        `frame(maxWidth: 460, alignment: .leading)`, Titel halbfett, Zeilen 14/1,45; keine Zeilen
        → `hinweisDe` in `text3` an ihrer Stelle; Zustandssatz in `Farbe.pv`/`text3`; Knöpfe wie
        in der Vorlage, „Jetzt senden" gesperrt bei leeren Zeilen; Warnsatz bei
        `enabled && (b.geraete ?? 0) == 0`; `zuletztDe`; Rückmeldung und `detailsDe`.
     g. `Methode([...])` bleibt, wie sie ist (`:42-52`) - sie ist der APNs-Zusatz der App und hat
        in der Vorlage kein Gegenstück.
     h. `lade()` (`:249-255`) und die drei Griffe (`:218-247`) auf gefangene Fehler umbauen, mit
        den drei Sätzen der Vorlage (`Morgenbrief.tsx:30`, `:43`, `:58`) und `ApiFehler.rat` über
        `Stoerung` (`Gestalt/Karte.swift:410-436`), wo ein Fehler stehen bleiben soll.

WAS SCHWIERIG WIRD:

  * **Die Mitteilungsblase.** `globals.css:757` mischt Fläche, Radius 14 und 460 px Breite in
    einem Kasten, der weder `Karte` noch `Leer` ist. In der App gibt es kein Vorbild mit genau
    diesen Maßen; am nächsten steht `Stoerung` (`Gestalt/Karte.swift:432-434`: `padding(12)`,
    `Farbe.flaeche2`, `radius3`) - also derselbe Weg, aber mit eigenen Zahlen und
    `Color.white.opacity(0.07)` statt eines Markenwerts, weil `Marken` keinen Eintrag für
    `rgba(255,255,255,.07)` hat (gesucht nach einem Wert mit `deckung: 0.07` in
    `Gestalt/Marken.swift`: kein Treffer - die drei `0.07`-Zeilen dort sind Helligkeitsfaktoren,
    `:438`, `:455`;
    `Gestalt/Karte.swift:93` nimmt dafür `flaeche2`). Ob `flaeche2` auf einer Karte, die am
    Telefon selbst `flaeche2` ist, noch sichtbar ist, ist zu prüfen - sonst `flaeche3`
    (`Marken.swift:30`), so wie `knopf` es schon tut (`MitteilungenSeite.swift:132`).
  * **Das Raster der Gerätezeile.** `.geraet` ist ein CSS-Raster mit einer Zeile aus zwei Spalten
    und einer zweiten Zeile über beide (`globals.css:762-765`). In SwiftUI wird daraus ein
    `VStack` aus einem `HStack` (Name, `Spacer`, „seit …") und einem `Text` darunter. Vorbild im
    Projekt: `Zeile` (`Gestalt/Karte.swift:360-383`) für die erste Zeile,
    `fixedSize(horizontal: false, vertical: true)` für die zweite, wie
    `MitteilungenSeite.swift:155-157` es schon macht.
  * **Zwei Kicker in einer Karte.** Die Vorlage hat in einem Kasten zwei `.kicker`-Blöcke
    (`Mitteilungen.tsx:189`, `:254`); `Karte` kennt nur einen (`Gestalt/Karte.swift:16`,
    `:54-83`). Der zweite wird ein `Kicker(wort:)` im Inhalt
    (`Gestalt/Typografie.swift:132`) - am Telefon aber ohne Sperrschrift, wie `Karte` es dort für
    ihren eigenen Kopf tut (`Karte.swift:66-71`); sonst steht in der App eine Sperrschrift, die
    `handy.css:3-26` ausdrücklich abgeschafft hat.
  * **Der Kicker der Hülle.** `Reiter` hat kein Feld dafür (`Bereiche/Bereiche.swift:45-65`), und
    das Gerippe kennt die Seite nicht, nur den Weg (Begründung ebenda `:52-56`). Entweder der
    Satz steht in der Seite (dann an anderer Stelle als in der Vorlage, wo er oben rechts in der
    Reiterzeile sitzt, `AreaShell.tsx:26`, `handy.css:148-154`), oder `Reiter` bekommt ein Feld -
    das betrifft alle Bereiche und gehört in eine eigene Messung.
  * **Kein Gegenstück nötig** für `schluesselBytes` (`Mitteilungen.tsx:32-40`), die drei
    iOS-Browser-Schritte (`:196-205`) und `geht-nicht` (`:207-211`): die App ist die
    Home-Bildschirm-App und geht über APNs (`Mitteilungen/Mitteilungen.swift:8-24`). Dafür hat sie
    einen Zustand, den die Vorlage nicht hat - die fehlende Push-Berechtigung einer unbezahlt
    signierten Fassung (`Mitteilungen.swift:114-130`); der bleibt.
