========================= messen:jetzt   Aufwand: mittel

Zweite Messung dieser Seite. Die erste Nacharbeit (ABGLEICH.md:67-71, „`/` · 10 von 10
Punkten", 17.11.) ging nach einer Handliste und betraf die vier Kacheln, die Tagesbilanz, den
Ausblick am Telefon und die Planerwarnung. Alles davon ist da und nachgesehen. Was unten steht,
ist nicht daraus abgeschrieben; jede Zeile hat eine Stelle im Code.

IST: Was die App-Seite heute von oben nach unten zeigt

Gerippe: `JetztSeite.swift:36-38` wählt nach `horizontalSizeClass` zwischen `wand`
(`:51-86`) und `hand` (`:122-148`). Kopf, Reiter, Updatehinweis, Ruhebild und Bereichsleiste
liegen nicht auf der Seite, sondern in den Rahmen (`WandRahmen.swift:48-81`,
`HandRahmen.swift:23-58`) - das deckt sich mit der Vorlage, die sie in `Home.tsx:203-217`
(`home-kopf`), `:226` (`UpdateHinweis`), `:250` (`Fussleiste`) und `:252-254` (`Ambiente`)
innerhalb der Seite hält, aber auf jeder Unterseite gleich zeigt.

Wand (`JetztSeite.swift:51-86`), fünf Blöcke in einer `GeometryReader`-Spalte ohne Rollbereich:
  * `satzzeile(breit:eng:)` (`:156-186`): Satz aus `haus.satz`, rechts auf derselben
    Grundlinie `unterzeile`, darunter `Wache` und bei Fehler `Stoerung`.
  * `HStack` (`:61-76`): `Energiefluss(fassung: .wand)` nimmt die Restbreite, `Leiste()` ist
    272 Punkte breit; bei Störung beides auf 0,6 abgeblendet.
  * `kurve` (`:246-266`): `TageskurveBild` ohne Karte, Höhe `kurvenhoehe()` =
    `min(260, max(170, h·0,24))` (`:88-91`).
  * `fuss` (`:99-118`): vier Zahlen aus `kennzahlen` in `Zahl(schrift: custom(26))` mit Wort
    in `sans(12)`/`text2`, rechts `Dock()`.
  * Ränder: 32 horizontal, oben 22 bzw. 14, unten 14; Blockabstand 12 bzw. 8, umgeschaltet
    über `eng = raum.size.height < 820` (`:58`).

Hand (`JetztSeite.swift:122-148`), in `Seite` (`Seitenwahl.swift:154-190`, Rand 16, Abstand 14,
Rollbereich): `satzblock` (`:190-215`) - `Energiefluss(fassung: .hand)` - `Leiste(kompakt: true)`
- `kurve` in einer `Karte` - `Kachelfeld(ersteFuehrt: false, art: .start)` - `Karte { Dock() }`.

Nachladen (`:334-388`): heute holt `energieUebersicht("day", anker: haus.heute)` und erneuert
sie alle 300 s (`:365-374`); gestern holt `verlaufTag` plus Bilanz; morgen holt
`energieWaerme("day", …)`. Der Vortag für den Schatten wird einmal am Tag geholt (`:377-388`).

VORLAGE:

  * **Kopf `home-kopf`**  (`Home.tsx:203-217`, `globals.css:191-198`)
    Links `Brand` (Ente 30, Name 16 halbfett) und `AreaIcons` (Felder 40×40, Zeichen 20);
    rechts `home-uhr` auf einer Grundlinie mit Abstand 22: Datum 15 `text-2`, Uhr
    `clamp(30px,3.4vw,46px)` Strichstärke 500, Außentemperatur 17 mit Herkunftswort 12
    `text-3`, Punkt 8×8 mit `dch-atmen` 3,6 s und das Statuswort in 11.
    Am Handy (`handy.css:223-259`): Datum und Uhr weg (`:258`, wörtlich: „die Uhrzeit steht in
    der Statusleiste des Geräts … zweimal dieselbe Zahl übereinander ist eine zu viel"),
    „live"/„demo" nur als Punkt (`:228`), bei Störung fällt die Temperatur weg (`:254`).
    DATEN: `state.system.outdoor_shown_c`, `outdoor_source_de`, `connection_label_de`, `mode`,
    `sim_speed`; Rolle aus `/api/session`.
    → in der App vorhanden: `WandRahmen.swift:111-230`, `HandRahmen.swift:74-128`.

  * **Satzblock `home-satz-block`**  (`Home.tsx:219-227`, `globals.css:200-209`)
    `home-satz` `clamp(20px,2.1vw,28px)`, Strichstärke 500, Sperrung −0,015em, Zeilenhöhe 1,25,
    `max-width: 70ch`; auf niedrigen Schirmen `clamp(18px,1.9vw,24px)` (`globals.css:271`), am
    Handy 21/1,27 (`handy.css:261`). Rechts `home-satz-meta` 13 `text-3`, am Handy darunter
    (`globals.css:301`, `handy.css:262`).
    Text: `d?.explanation_de ?? (state ? "Das Haus ist da, die erste Entscheidung steht noch
    aus." : "Verbinde mit dem Haus …")` (`Home.tsx:184`).
    Meta = `[modeWort, dazu]` mit „ · " (`:222`): `modeWort` ist „von Hand bis HH:MM" /
    „Automatik aus, Duck Curve schaut nur zu" / „Automatik" (`:187-191`); `dazu` ist „nächster
    geplanter Lauf um HH:MM", sonst „Stand HH:MM" (`:192-199`).
    Darin außerdem: `Wache` (`:224`), am Handy `MitteilungsHinweis` (`:225`), immer
    `UpdateHinweis` (`:226`).
    DATEN: `state.decision.explanation_de/at`, `state.operating_mode`, `plan.intervals`
    (`reason_code == "planned_optimizer"`, `planned_hp_state == "release"`, `ausblick.ts:117`).

  * **Wache**  (`Wache.tsx:26-38`, `globals.css:204-207`)
    **Höchstens zwei Befunde** (`Wache.tsx:30`: `befunde.slice(0, 2)`). Jede Zeile:
    Warnzeichen 16 in `currentColor`, Satz in `text-1`, Schrift 14/1,35; links eine 3 Punkte
    starke Kante in der Schwerefarbe, Radius `0 4px 4px 0`, Polster `7px 12px`, Grund
    `rgba(224,83,61,.10)`, Farbe `--alert`; bei `severity="warn"` `--amber-soft` auf
    `rgba(255,215,120,.10)`. Kommentar in `globals.css:202-203`: „Keine Kachel, kein Fenster:
    eine Zeile mit Kante, die man im Vorbeigehen sieht und die nichts verdeckt."
    DATEN: `state.system.watch[].severity/text_de/name`.

  * **Flussbild `home-fluss` / `fluss-h`**  (`FlowHero.tsx`, `FlowHandy.tsx`)
    Wand: Knoten bei pv 50/13, netz 11/48, haus 50/48, bat 89/48, hp 20/78, ev 80/78
    (`FlowHero.tsx:36-43`); Durchmesser 56, groß 112 (`globals.css:219-220`), **auf Schirmen
    unter 820 Punkten 48 und 92** (`globals.css:272-273`). Zahl
    `clamp(22px,2.6vw,34px)`, groß `clamp(34px,4.2vw,56px)`, Einheit 0,42em (`:230-232`).
    Lichtschein `min(520px,60%)` mit Deckung 0,26 (`:214`), Stärke = PV/`pvPeak`.
    Hand: eigene Anordnung (`FlowHandy.tsx:29-36`), Höhe 410, Radius 20, Nachthimmel mit zehn
    gesetzten Sternen (`handy.css:32,58-77`), Mond in `#b9cfdb` (`FlowHandy.tsx:40,200`).
    DATEN: `snapshot.pv_power_kw`, `grid_power_kw`, `battery_power_kw`, `battery_soc`,
    `house_power_kw`, `heat_pump_power_kw`, `ev_power_kw`, `base_load_kw`.
    → in der App vollständig: `Energiefluss.swift:69-110,133-260,560-790`.

  * **Leiste `home-rail`**  (`Rail.tsx`)
    Wand: Pufferkachel mit stehendem Glas `flex: 1 1 0` und darunter „Nächste 24 h" mit
    `flex: none` (`globals.css:236,238,242`), Zahl `clamp(28px,2.8vw,40px)`.
    Hand: **Ausblick vor dem Puffer** (`handy.css:271`: `.home-rail .ausblick { order: -1 }`),
    liegendes Glas, **keine Planzeilen** (`Rail.tsx:50-84` zeigt nur Puffer und `Ausblick`).
    → in der App: `Leiste.swift:18-89`, Reihenfolge und Fassungen stimmen.

  * **Tageskurve `home-kurve`**  (`DayCurve.tsx`, `globals.css:247-249`, `handy.css:264-268`)
    Wand: eine Zeile mit `justify-between` - links `home-tage`, rechts die Legende
    (`:154-163`); Schalter mit **1 Punkt Rand in `--line-2`, Radius 5, Polster 2, ohne
    Grundfläche** (`globals.css:247`), Knöpfe `5px 14px`, Schrift 13 (`:248`). Bild mit einem
    Gitter, links kW, rechts ct (`DayCurve.tsx:115,121`), x-Achsenlinie in
    `rgba(255,255,255,.2)` (`palette.ts:79`), Marken alle 6 h als `HH:00` (`:116`).
    Hand: zwei Gitter, Preisfläche **58 Punkte** hoch (`:174`), Bild gesamt 262
    (`handy.css:265`), Achsenbeschriftung 11 **mit Einheit** (`DayCurve.tsx:118,120`:
    `${v} kW` / `${v} ct`), Marken weiter alle 6 h als `HH:00`; Legende unter dem Bild mit
    Umbruch (`handy.css:266`), Tagesschalter über die ganze Breite, Knöpfe `8px 6px`,
    Schrift 14, Radius 11 auf `rgba(255,255,255,.07)` (`:267-268`); Karte `padding: 14px 12px
    12px`, Radius 16, `--surface-2`, Abstand 10 (`:264`).
    Reihen (`:123-131`): Schatten (`pvSchatten` 1,6 / 0,75) - Sonne (2, Fläche 0,45→0,04) -
    Sonne-Prognose (1,5 gestrichelt 0,7, Fläche 0,08) - **Haus in `rgba(255,255,255,.88)`,
    1,8** - Wärmepumpe erwartet, nur morgen (1,5 gestrichelt) - Strompreis `stepEnd` 1,6 -
    Preis voraus 1,6 gestrichelt. Jetzt-Marke: **`var(--amber-soft)`, gestrichelt, 1,2** -
    in beiden Fassungen dieselbe (`:88`, am Handy über `markLine` auch in der Preisfläche,
    `:129`). Bänder nur `cheap` und `negative` (`:79`).
    Leistungsachse `Math.max(3, ceil(max·1,1/2)·2)` (`:85`), drei Marken (`interval:
    powerMax/2`).
    Legende nach **Tag**, nicht nach Reihen (`:143-149`): Sonne (Fläche) außer morgen,
    Prognose/„Sonne erwartet" außer gestern, Schatten mit kWh, Haus außer morgen, Wärmepumpe
    nur morgen, Strompreis immer, **„Preistief" außer gestern - auch wenn gerade kein Band im
    Bild liegt**.
    Schatten (`tage.ts:190-204`): hinter heute gestern, **hinter morgen heute**; Wort
    „gestern"/„heute"; kWh bis zur gleichen Uhrzeit (`:197`), Trapeze mit **Übersprung jeder
    Lücke über einer Stunde** (`:166-180`).
    DATEN: `history` (SSE-Reihe), `plan.intervals`, `plan.windows`, `heat.forecast`,
    `api.history("yesterday")`.

  * **Vier Zahlen `home-heute`**  (`Home.tsx:236-246`, `tage.ts:95-129`)
    Wand: Zeile, Abstand 32, Zahl 26, Wort 12 `text-2`, keine Karte (`globals.css:251-255`).
    Hand: eine Fläche, zwei Spalten, Wort über der Zahl, Haarlinien zwischen den Reihen, Zahl
    25, Wort 13 `text-3`, Polster `4px 16px` (`handy.css:279-283`).
    Inhalt gestern/heute: „Sonne geerntet" (gelb) · „ohne Netz" % · „bezahlt bis
    jetzt"/„bezahlt" € · „Strom gerade"/„Strom im Mittel" ct. Morgen: „Sonne erwartet" ·
    **„Wärme erwartet · X kWh Strom" in einem Wort** (`tage.ts:107`) · „Strom im
    Mittel"/„Preise kommen gegen 13 Uhr" · „günstigste Stunde ab HH:MM".
    DATEN: `summary.totals.pv_kwh/autarky/import_cost_eur/avg_import_price_ct`,
    `snapshot.electricity_price_ct_kwh`, Plan und Wärmeprognose für morgen.
    → Auswahl und Worte stehen im Kern: `Tageskacheln.swift:53-107`.

  * **Dock `home-dock`**  (`Dock.tsx`, `globals.css:256-267`, `handy.css:284-286`)
    Reihe: vier Schalter (Kaffee 120 min, Terrasse, Hof, Zaun) in **`var(--amber)`**
    (`Dock.tsx:236`), Trenner 1×36 (`globals.css:263`), dann Wärmepumpe in
    `var(--heat-pump)`, Ofen **nur bei `stove.present`** (`Dock.tsx:240`) in `var(--stove)`,
    **Alarmanlage nur bei `alarm.present`** in `var(--mist)`, bei `state === 4` in
    `var(--alert)` (`:242-252`).
    Knopf: 60×60, Radius 16, Rand 1, Grund `rgba(15,46,61,.6)`; leuchtet er, Schein
    `0 0 22px` in 35 % der Gerätefarbe; **ist sein Blatt offen, Rand in der Gerätefarbe und
    Grund in 14 % davon** (`Dock.tsx:50-52`). Wort darunter 10, gesperrt 0,04em, groß
    geschrieben, `text-3`, bei „an" `text-2` (`globals.css:259-260`).
    Am Handy 48×48, **Radius 14** (`handy.css:285-286`), Reihe `justify-content:
    space-between`, Abstand 6 (`globals.css:319`), Fläche mit Radius 16 und Polster
    `14px 12px 12px` (`handy.css:284`).
    Rückmeldung `home-dock-meldung`: über dem Dock, rechts, 13 Punkte, Festschrift,
    **`var(--amber-soft)`** (`globals.css:264`), **nach 4 s weg, bei Fehler nach 8 s**
    (`Dock.tsx:185-189,210`).
    Alarmblatt (`Dock.tsx:128-177`): Stufe als Wort, zwei Knöpfe „Zu Hause"/„Unterwegs", der
    Satz „Unscharf wird am Bedienteil geschaltet, nicht hier" - mit Begründung in
    `Dock.tsx:121-127`: „ihr Zugang ist ein Sitzungskeks auf einem Gerät - genug, um eine
    Anlage scharf zu schalten, zu wenig, um sie abzuschalten".
    DATEN: `snapshot.actuators[*]`, `state.heat_pump`, `state.operating_mode`, `state.stove`,
    `state.alarm`; `api.switchActuator`, `api.setHeatPumpMode`, `api.setStoveMode`,
    `api.armAlarm`.

  * **Heimkehr und Mitternacht**  (`Home.tsx:49-54,95-110,162-167,252`)
    `HEIMKEHR_MS = 2 * 60_000`: **nach zwei Minuten ohne Berührung steht wieder heute da**
    (`:162-167`), der Zähler beginnt bei jedem Tippen auf den Tagesschalter neu
    (`:234` setzt `getippt`). Begründung in `Home.tsx:36-38`: „Wer vorbeigeht, soll nicht das
    Gestern eines anderen sehen", und in `DayCurve.tsx:32-34`: „die Wandanzeige soll nicht an
    einem Tag von vorgestern hängen bleiben, wie es der alten passiert ist."
    Mitternacht (`:95-110`): neuer Kalendertag → `setTag("heute")`, Vortagsreihe verwerfen,
    Verlauf neu holen. Kommentar: „Die alte Ansicht blieb auf gestern stehen."
    Das Ruhebild erscheint nur, solange `tag === "heute"` (`:252`).

  * **Mitteilungshinweis (nur Handy)**  (`MitteilungsHinweis.tsx`, `globals.css:769-773`)
    Steht im Satzblock. Nur beim Hausherrn, nur solange das Gerät nicht angemeldet ist, mit
    „Einschalten" (Pille auf `--amber`, Petrolschrift, halbfett 13) und „Nicht jetzt"
    (`text-3`, merkt sich das Wegtippen). Fläche `--surface-2`, Rand `--line-2`, Radius 12,
    Polster `12px 14px`, Schrift 14/1,45. Anlass wörtlich (`:11-14`): „Ich bekomme gar keine
    Push-Nachrichten auf mein Handy. Da war doch ein Morning Briefing geplant."
    DATEN: Push-Lage des Geräts, `api.pushSubscribe`, Weg `/system/mitteilungen`.

LUECKEN:

  [traegt-die-seite] **Der Tagesschalter kehrt nicht zu „heute" zurück.** `tag` ist lokaler
    Zustand der Seite (`JetztSeite.swift:21`), und `Wegweiser.heimkehr(jetzt:)`
    (`Navigation.swift:92-96`) setzt ausschließlich `zeitraeume` zurück - die Zeitwahl der
    Berichtsseiten. `WandRahmen.swift:104-106` ruft sie nach zwei Minuten brav auf, aber sie
    kommt an der Startseite nicht an: gesucht nach `heimkehr`, `tag =`, `Kurventag` in
    `apps/ios/DuckCurveHome/App/` und in `JetztSeite.swift` - kein Treffer, der den Schalter
    anfasst. Wer im Vorbeigehen auf „Gestern" tippt, hinterlässt eine Wandanzeige, die
    gestrige Kurve und gestrige Kacheln so zeigt, wie sonst die heutigen stehen. Genau davor
    warnt `DayCurve.tsx:32-34`.

  [spuerbar] **Mitternacht wird nicht abgefangen.** `ladeFuerTag()` hängt nur an `tag`
    (`JetztSeite.swift:31`), `ladeVortag()` an `haus.heute` (`:32`). Wechselt der Kalendertag,
    während die Seite steht, bleibt `tag` stehen und `geholtesRaster` (`:269`) enthält weiter
    den alten Tag: unter „Gestern" steht dann vorgestern, und „Heute" beginnt mit der Reihe
    von gestern, weil nichts sie neu holt. Die Vorlage setzt an dieser Stelle `tag` zurück,
    verwirft die Vortagsreihe und holt `history("today")` neu (`Home.tsx:100-110`).

  [spuerbar] **Hinter „Morgen" liegt kein Schatten.** `JetztSeite.swift:251` gibt
    `vortag: tag == .heute ? vortag : []`. Die Vorlage legt hinter morgen den heutigen Verlauf
    (`tage.ts:192`: `punkte = tag === "heute" ? gestern : heute`) und nennt ihn in der Legende
    „heute" samt kWh bis jetzt (`:197,202-203`). Der Kern kann es schon und sagt es selbst:
    `Tageskurve.swift:223-225` setzt `schattenwort = tag == .morgen ? "heute" : "gestern"` -
    ein Zweig, den die App nie erreicht. Damit fehlt auf einem von drei Tagen der Vergleich,
    der die ganze Begründung der Schattenkurve ist („erst der Vortag macht aus 13,4 kWh eine
    Auskunft", `DayCurve.tsx:28-30`).

  [spuerbar] **Der Alarmknopf und sein Blatt fehlen im Dock.** `Dock.swift:52-65` setzt vier
    Schalter, den Trenner, Wärmepumpe und Ofen - gesucht nach `alarm` in
    `apps/ios/DuckCurveHome/Bausteine/Dock.swift`: kein Treffer. Die Vorlage hat dort einen
    siebten Knopf („Alarm", Schild, `--mist`, bei Stufe 4 `--alert`) und das Blatt mit „Zu
    Hause"/„Unterwegs" (`Dock.tsx:242-252,281-283`). Das Scharfstellen gibt es in der App nur
    auf der Hausseite (`Hauskonsolenleiste.swift:262-289`); vom Dock der Wandanzeige, wo man
    im Vorbeigehen daran kommt, geht es nicht.

  [spuerbar] **Der Mitteilungshinweis fehlt am Telefon.** `satzblock`
    (`JetztSeite.swift:190-215`) enthält Satz, Unterzeile, `Wache` und `Stoerung` - gesucht
    nach `Mitteil`, `Morning`, `push` in `JetztSeite.swift`: kein Treffer. Die Vorlage setzt
    genau hier `MitteilungsHinweis` (`Home.tsx:225`), weil sonst jemand auf einen Brief
    wartet, der an niemanden geht (`MitteilungsHinweis.tsx:11-14`). Die Seite dahinter gibt es
    (`MitteilungenSeite.swift`), der Hinweis darauf nicht.

  [spuerbar] **Die Wache zeigt alle Befunde und sieht anders aus.** `Wache`
    (`Dock.swift:221-249`) zeichnet `ForEach(befunde)` ohne Grenze, je Zeile einen Punkt von
    5 Punkten in der Schwerefarbe und den Satz in `Schrift.winzig` (11,5, `Typografie.swift:46`)
    in `text2`. Die Vorlage nimmt **die zwei schwersten** (`Wache.tsx:30`) und zeichnet eine
    getönte Zeile mit 3 Punkten Kante, Warnzeichen 16 und Satz in 14 Punkten `text-1`
    (`globals.css:205-207`). Beides zusammen: an der Wand, wo nichts rollt
    (`JetztSeite.swift:51-86`), schiebt eine Wache mit fünf Befunden Kurve und Fuß aus dem
    Bild - und was dort abgeschnitten wird, ist weg.

  [spuerbar] **Auf niedrigen Schirmen schrumpfen die Knotenkreise nicht.** `eng` wird in
    `JetztSeite.swift:58` berechnet und wirkt auf Blockabstand, oberen Rand und Satzgröße
    (`:59,82,163`), aber nicht auf das Flussbild: `Energiefluss` bekommt kein `eng`
    (`:62-66`), und `Knoten.kante` ist für die Wand fest 56/112
    (`Energiefluss.swift:602-610`). Die Vorlage nimmt unter 820 Punkten Höhe `--r` auf 24 bzw.
    46 zurück, also 48/92 (`globals.css:269-274`) - und 820 ist nach dem Kommentar in
    `JetztSeite.swift:54-55` genau die Höhe des 10,9-Zoll-iPads im Querformat. Die Kreise sind
    dort rund ein Fünftel zu groß, mitsamt ihrem Text, der um `kante/2` nach unten versetzt
    ist (`Energiefluss.swift:744`).

  [spuerbar] **Die Rückmeldung des Docks verschwindet nie.** `Dock.swift:137,140,143` setzt
    `rueckmeldung`, und keine Stelle setzt sie zurück - gesucht nach `rueckmeldung = nil` in
    `Dock.swift`: kein Treffer. Die Vorlage löscht sie nach 4 s, bei einem Fehler nach 8 s
    (`Dock.tsx:185-189,210`). An einer Wandanzeige steht damit „Kaffeemaschine an" bis zum
    nächsten Tippen über dem Dock.

  [klein] **Die Dockknöpfe sind am Telefon zu groß und rund.** `Knopf`
    (`Dock.swift:181,187-191`) nimmt 60×60 und Radius 30 („am Telefon ein Kreis") mit Berufung
    auf `globals.css:261` - dort steht aber 60 Punkte mit Radius 16, und für das Handy sagt
    `handy.css:285-286` 48×48 mit Radius 14. In `handy.css` gibt es keine Zeile, die aus dem
    Knopf einen Kreis macht; gesucht nach `border-radius: 50%` in `handy.css` im
    Dock-Abschnitt: kein Treffer.

  [klein] **Der Ofenknopf steht auch da, wo es keinen Ofen gibt.** `Dock.swift:89` prüft
    `if let ofen = haus.zustand?.stove`; die Vorlage prüft `stove?.present`
    (`Dock.tsx:240`). Das Feld gibt es im Kern (`Schema.swift:1245`), es wird nur nicht
    gelesen.

  [klein] **Die vier Schalter leuchten in der falschen Gelbstufe.** `Dock.swift:115` setzt
    `Farbe.amberWeich` (`#FFD778`, `Marken.swift:19`); die Vorlage setzt `var(--amber)`
    (`#F2A900`, `Dock.tsx:236`, `tokens.css:13`). `Farbe.amber` gibt es
    (`Marken.swift:18`).

  [klein] **An der Wand fehlt unter „Wärme erwartet" der Strom.** `fuss`
    (`JetztSeite.swift:102-113`) zeichnet aus `Kacheldaten` nur `wert`, `einheit` und `wort` -
    `dazu` kommt nicht vor. Der Kern füllt es (`Tageskacheln.swift:97`), und am Telefon zeigt
    `Kachel.hinweis` es auch (`Karte.swift:251-268`). Die Vorlage hat die Angabe im Wort
    selbst: „Wärme erwartet · 4,2 kWh Strom" (`tage.ts:107`).

  [klein] **Die Zeitachse am Telefon hat andere Marken und kein Format.** `zeitachse`
    (`Tageskurve.swift:352-378`) setzt alle 4 Stunden eine Marke und beschriftet sie
    `"%02d"`, also „00 04 08 …". Die Vorlage setzt `interval: 6` und `HH:00` in beiden
    Fassungen (`DayCurve.tsx:116`).

  [klein] **Am Telefon fehlen die Einheiten an den Werteachsen.** `leistungsflaeche`
    beschriftet mit `Formate.zahl(d, stellen: 0)` (`Tageskurve.swift:279`), `preisflaeche`
    ebenso (`:338`). Die Vorlage schreibt `${v} kW` und `${v} ct`
    (`DayCurve.tsx:118,120`) - an zwei gestapelten Flächen ist die Einheit die einzige
    Auskunft, welche welche ist.

  [klein] **Die Hauslinie ist zu blass.** `Tageskurve.swift:121,247` nimmt `Farbe.last`
    (Weiß 0,62, `Marken.swift:132`); die Vorlage zeichnet sie in `rgba(255,255,255,.88)`
    (`DayCurve.tsx:127`) und nennt dieselbe Farbe in der Legende (`:146`).

  [klein] **Die Jetzt-Marke am Telefon ist nicht bernsteinfarben.** `leistungsflaeche`
    (`Tageskurve.swift:262-263`) und `preisflaeche` (`:321-322`) zeichnen sie in
    `Farbe.text2`, gestrichelt `[2,3]`; die Wandfassung nimmt richtig `amberWeich`, 1,2,
    `[4,4]` (`:157-158`). Die Vorlage hat eine Marke für beide Fassungen:
    `var(--amber-soft)`, `dashed`, 1,2 (`DayCurve.tsx:88`, am Handy über `:129`
    mitgezeichnet).

  [klein] **Die Schattenlinie am Telefon hat andere Farbe und Stärke.**
    `Tageskurve.swift:221-222`: `Farbe.pv.opacity(0.26)`, Breite 1,2. Vorlage in beiden
    Fassungen: `C.pvSchatten` (`#c8902f`), Breite 1,6, Deckung 0,75 (`DayCurve.tsx:124`).
    `Farbe.pvSchatten` gibt es (`Marken.swift:211`) und die Wandfassung nutzt sie
    (`Tageskurve.swift:98`).
    Dazu die Reihenfolge: am Telefon liegt der Schatten vor den Bändern (`:219-230`), die ihn
    dann übertönen; an der Wand und in der Vorlage liegen die Bänder darunter (`:91-101`,
    `DayCurve.tsx:125`).

  [klein] **Der Tagesschalter an der Wand ist gefüllt statt umrandet.**
    `Ansichtswahl.swift:33-36` legt `Farbe.flaeche2` unter die Knöpfe und rundet mit
    `Marken.radius3` (6, `Marken.swift:375`), ohne Rand. `globals.css:247` gibt `home-tage`
    einen 1 Punkt starken Rand in `--line-2`, Radius 5 und keine Fläche; die Knöpfe haben
    `5px 14px` gegen 11/5 in `Ansichtswahl.swift:58-59`.

  [klein] **Die Leistungsachse rundet anders.** `Tageskurve.leistungsgrenze`
    (`Tageskurve.swift:251-259`): `max(4, (hoch · 1,12).rounded(.up))`, also 1-kW-Schritte.
    Vorlage: `Math.max(3, ceil(max · 1,1 / 2) · 2)` (`DayCurve.tsx:85`), also 2-kW-Schritte
    und Mindestwert 3. An einem stillen Tag steht in der App „4 / 2 / 0", in der Vorlage
    „3 / 1,5 / 0".

  [klein] **Die Preisfläche am Telefon ist zu hoch.** `Tageskurve.swift:345`: 72 Punkte; die
    Vorlage 58 (`DayCurve.tsx:174`, `PREIS_HOEHE`). Zusammen mit 170 für die Leistung und 18
    für die Achse kommt die App auf 260 gegen 262 (`handy.css:265`) - die Summe stimmt also,
    die Aufteilung nicht: 14 Punkte gehen der Leistungsfläche verloren.

  [klein] **Die Dock-Rückmeldung steht an der falschen Stelle und in der falschen Farbe.**
    `Dock.swift:36-42`: `VStack(alignment: .leading)`, `Schrift.winzig` (11,5), `text3`.
    Vorlage: rechts (`globals.css:256,264`: `align-items: flex-end`, `right: 0`), 13 Punkte,
    `var(--amber-soft)`.

  [klein] **Ein Knopf mit offenem Blatt wird nicht getönt.** `Knopf`
    (`Dock.swift:151-213`) kennt nur `an`, `laeuft` und `fehler`; die Vorlage kennt `offen`
    und setzt dann Rand in der Gerätefarbe und Grund in 14 % davon (`Dock.tsx:50-52`). In der
    App führt ein Tipp auf Wärmepumpe oder Ofen in ein Blatt (`Dock.swift:82,99`), und der
    Knopf sieht danach aus wie vorher.

  [klein] **Die Legende hängt an den Reihen statt am Tag.** `eintraege`
    (`Tageskurve.swift:451-498`) prüft überall `isEmpty`; die Vorlage schaltet nach `tag`
    (`DayCurve.tsx:143-149`). Zwei sichtbare Folgen: an einem Tag ohne Messwerte verschwindet
    „Sonne" aus der Legende, obwohl die Achse steht; und „Preistief" steht in der Vorlage
    außer gestern immer da (`:149`), in der App nur, wenn gerade ein Band im Bild liegt
    (`:490-496`) - die Fläche ist damit unbenannt, sobald das Fenster vorbei ist.

  [klein] **`Tageskurve.energie` überspringt keine Lücken.** `Tageskurve.swift:235-245`
    rechnet über alle Stützpunkte, auch über eine Nacht hinweg. `tage.ts:166-180` überspringt
    jedes Paar mit mehr als einer Stunde Abstand, mit Begründung: „Zwei Punkte mit einer Nacht
    dazwischen sagen nichts über die Nacht, und als Trapez gerechnet ergäben sie eine Energie,
    die es nie gab." Trifft die kWh-Angabe der Schattenlegende nach einem Ausfall.

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `Tageskurve` mit `baue(tag:raster:vortag:plan:waermeprognose:jetzt:)`, allen acht Reihen,
    Bändern, Jetzt-Marke, `leistungsgrenze`, `preisgrenzen`, `preismarken`,
    `preisAufLeistung`/`leistungAufPreis`, `leer`:
    `Zustand/Tageskurve.swift:77-330`. Das Schattenwort für morgen ist schon vorgesehen
    (`:223-225`).
  * `Tageskacheln.kennzahlen(tag:bilanz:preisJetzt:morgen:)` samt `morgenKacheln`, `pvSumme`,
    `preise`, `waermeSumme`, `fenster`: `Zustand/Tageskacheln.swift:53-158`.
  * `Kennzahl` mit `wort/wert/einheit/dazu/ton`: `Zustand/Kennzahl.swift:15-51`; Ton zu Farbe
    in `Gestalt/Farben.swift:124`.
  * `Ausblick.baue` für die Telefonfassung der Leiste, benutzt in `Leiste.swift:26`.
  * `Fahrplan.zeilen` und `Fahrplan.phasen` für „Nächste 24 h" und den nächsten geplanten
    Lauf: aufgerufen in `Leiste.swift:105` und `JetztSeite.swift:231-234`.
  * `Pufferzustand.aus(fuehler:jetzt:laedt:status:)`: `Leiste.swift:96-101`.
  * Api: `energieUebersicht`, `verlaufTag`, `energieWaerme` (`Netz/Api.swift:155,188` und die
    Aufrufe in `JetztSeite.swift:342,350,357`), `schalte` (`Dock.swift:134`),
    `schaerfeAlarm(_:)` mit `Api.AlarmArt` (`Hauskonsolenleiste.swift:262,285`).
  * Modelle: `AlarmOut` mit `present/state/stateDe/canArm` (`Modelle/Schema.swift:1022-1046`),
    `StoveOut.present` (`:1245-1275`), `WatchFindingOut` (benutzt in `Dock.swift:222`).
  * Farben und Maße: `Marken.swift:18-19` (amber, amberWeich), `:211` (pvSchatten), `:132`
    (last), `:97,109` (waermepumpe, ofen), `:375` (radius3).
  * Mitteilungsstand des Geräts: `Zustand/Mitteilungsstand.swift`, benutzt über
    `Mitteilungen` in `MitteilungenSeite.swift:40,63`.

ES FEHLT:

  1. `Tageskurve.baue`: der Schattenschnitt für `morgen`. Heute rechnet `:220-221`
     `energie(…, bis: k.jetztStunde)`, und für morgen ist `jetztStunde` nil - die Summe ginge
     damit über den ganzen Tag, während die Vorlage bis jetzt rechnet (`tage.ts:197`:
     `bis = tag === "heute" ? gleicheUhrzeit(…) : nowMs`). Vorschlag: in
     `Zustand/Tageskurve.swift` eine eigene Grenze `schattenBis: Double?` aus der Uhrzeit von
     `jetzt` bilden und sie statt `jetztStunde` für `schattenKwh` verwenden; `pvKwh` behält
     `jetztStunde`.
  2. `Tageskurve.energie`: Lücken über einer Stunde überspringen, wie `pvKwh` in
     `tage.ts:166-180`. In `Zustand/Tageskurve.swift:235-245`, mit einem Test, der eine Reihe
     mit einem Loch von zwanzig Minuten und einer mit einer Nacht dazwischen vergleicht.
  3. `Tageskurve.leistungsgrenze`: auf `max(3, (hoch · 1,1 / 2).rounded(.up) · 2)` umstellen
     (`DayCurve.tsx:85`), damit die drei Achsenmarken auf runden Zahlen stehen.
  4. Eine Grenze für die Wachbefunde. Entweder in der Ansicht (`befunde.prefix(2)`) oder als
     `Wachbefunde.zwei(_:)` im Kern - die Vorlage begründet sie nicht aus der Ansicht, sondern
     aus der Sortierung des Dienstes (`Wache.tsx:21-24`: „Alarm vor Warnung, bei gleicher
     Schwere der ältere"), und damit gehört die Auswahl in den Kern.

BAUPLAN: Welche Dateien anzulegen oder zu ändern sind, Karte für Karte

  1. **Der Tagesschalter wandert aus der Seite heraus.**
     `App/Navigation.swift`: `Wegweiser` bekommt `var kurventag: Kurventag = .heute`, und
     `heimkehr(jetzt:)` (`:92-96`) setzt ihn zusätzlich auf `.heute` zurück.
     `Seiten/Jetzt/JetztSeite.swift`: `@State private var tag` (`:21`) weicht dem Wegweiser;
     `Tagwahl` (`Diagramme/Tageskurve.swift:536-548`) bindet dagegen.
     Dazu der Mitternachtsfall: ein `.onChange(of: haus.heute)` in `JetztSeite`, der `tag` auf
     `.heute` setzt, `geholtesRaster`, `vortag` und `geholterVortag` leert und `ladeVortag()`
     neu anstößt (`Home.tsx:100-110`).
  2. **Der Satzblock.** `Seiten/Jetzt/JetztSeite.swift:190-215`: unter `Wache` einen neuen
     Baustein `Bausteine/Mitteilungshinweis.swift` einhängen, nur bei
     `breite == .compact`, nur bei `haus.darfSchalten`, nur solange `Mitteilungen.stand`
     nicht angemeldet meldet, mit „Einschalten" (Pille auf `Farbe.amber`, Petrolschrift) nach
     `/system/mitteilungen` und „Nicht jetzt", das sich in `UserDefaults` merkt
     (`MitteilungsHinweis.tsx:25,63-70`). Fläche `Farbe.flaeche2`, Rand `Farbe.linie2`,
     Radius 12, Polster 12/14, Schrift 14.
  3. **Die Wache.** `Bausteine/Dock.swift:221-249`: auf die zwei schwersten begrenzen und die
     Zeile der Vorlage nachbauen - 3 Punkte Kante links in der Schwerefarbe, Radius
     `0 4 4 0`, Polster `7/12`, Grund in 10 % der Schwerefarbe, Warnzeichen 16, Satz in
     `Schrift.sans(14)`/`text1` (`globals.css:205-207`).
  4. **Das Flussbild auf niedrigen Schirmen.** `Bausteine/Energiefluss.swift`: `Energiefluss`
     und `Knoten` bekommen `eng: Bool`; `Knoten.kante` (`:602-610`) gibt für
     `(false, .wand, eng)` 48 und für `(true, .wand, eng)` 92 (`globals.css:272-273`).
     `Seiten/Jetzt/JetztSeite.swift:62-66` reicht das `eng` aus `:58` durch.
  5. **Das Dock.** `Bausteine/Dock.swift`:
     - `Knopf` bekommt `offen: Bool` und tönt dann Rand und Grund (`Dock.tsx:50-52`); am
       Telefon 48×48 mit Radius 14, an der Wand 60×60 mit Radius 16
       (`handy.css:285-286`, `globals.css:261`).
     - `schalter` leuchten in `Farbe.amber` statt `amberWeich` (`:115`).
     - Ofenknopf nur bei `ofen.present` (`:89`).
     - Alarmknopf hinter dem Ofen, nur bei `alarm.present`, Farbe `Farbe.mist`, bei
       `state == 4` `Farbe.alarm`, Tipp öffnet ein neues `Blatt.alarm`
       (`App/Navigation.swift:100-111,187-193`) mit einem neuen
       `Bausteine/Alarmblatt.swift`: Stufe als Wort, zwei Knöpfe über `api.schaerfeAlarm`,
       der Satz „Unscharf wird am Bedienteil geschaltet, nicht hier", und bei Gastzugang die
       Zeile „Nur Ansicht" (`Dock.tsx:128-177`).
     - Rückmeldung: rechts ausrichten, `Schrift.sans(13)`, `Farbe.amberWeich`, und nach 4
       bzw. 8 Sekunden löschen (`Dock.tsx:185-189`).
  6. **Die Tageskurve.** `Diagramme/Tageskurve.swift`:
     - `leistungsflaeche`: Bänder vor dem Schatten zeichnen, Schatten in `Farbe.pvSchatten`
       1,6/0,75, Jetzt-Marke in `Farbe.amberWeich` 1,2 `[4,4]`, Achsenbeschriftung mit
       `kW`, Höhe von 170 auf 184 (262 − 58 − 18 − Abstände).
     - `preisflaeche`: Höhe 58, Achsenbeschriftung mit `ct`, Jetzt-Marke wie oben.
     - `zeitachse`: Marken alle 6 Stunden, Beschriftung `HH:00`.
     - `haus`-Reihe in Weiß 0,88 (neue Marke `Marken.hauslinie` oder
       `Farbe.text1.opacity(0.88)`).
     - `eintraege`: nach `tag` schalten wie `DayCurve.tsx:143-149`, „Preistief" außer gestern
       immer nennen.
     `Gestalt/Ansichtswahl.swift:33-36`: an der Wand Rand in `Farbe.linie2` statt Fläche,
     Radius 5, Knopfpolster 14/5.
  7. **Der Schatten für morgen.** `Seiten/Jetzt/JetztSeite.swift:251`: `vortag:` bekommt für
     `.morgen` `haus.raster.punkte` (den heutigen Verlauf), für `.gestern` weiter nichts.
     Dazu Punkt 1 aus **ES FEHLT** im Kern.
  8. **Der Fuß an der Wand.** `Seiten/Jetzt/JetztSeite.swift:99-118`: unter Zahl und Wort
     `k.dazu` zeichnen, in `Schrift.winzig`/`text3` - oder `Tageskacheln.morgenKacheln`
     (`:94-97`) auf das Wort der Vorlage umstellen („Wärme erwartet · X kWh Strom") und
     `dazu` dort fallen lassen. Das Zweite ist näher an `tage.ts:107`.

WAS SCHWIERIG WIRD

  * **Zwei Werteachsen in einem Bild.** Swift Charts kennt nur eine; der Weg des Projekts ist
    gewählt und steht: der Preis wird in die Leistungsachse gerechnet und die rechte Achse
    zurückgerechnet beschriftet (`Zustand/Tageskurve.swift:307-324`,
    `Diagramme/Tageskurve.swift:89-207`). Beim Umbau nichts daran ändern - nur die Marken
    bleiben die der Preisachse, sonst stehen dort krumme Zahlen (`:85-88`).
  * **Ziehen und Zoomen (`dataZoom`) gibt es nicht.** Das Projekt hat sich für ein Fadenkreuz
    entschieden, das beim Ziehen die Werte einer Stunde als Zeile in der Legende zeigt
    (`Diagramme/Tageskurve.swift:19-23,382-401,501-516`). Vorbild für andere Seiten.
  * **`position(x:y:)` statt absoluter Prozentlagen.** Der Energiefluss misst die Fläche und
    rechnet Anteile in Punkte (`Bausteine/Energiefluss.swift:186-189`), und der Text wird um
    `kante/2 + randabstand + Schätzung/2` versetzt (`:736-745`), weil SwiftUI keine Lage
    „rechts neben dem Kreis, mittig zur Grundlinie" kennt. Wer `kante` für niedrige Schirme
    ändert (Bauplan 4), muss die Schätzungen `breiteSchaetzung`/`hoeheSchaetzung` mitprüfen.
  * **Eine Fläche ohne Rollbereich.** Die Wandfassung hat fünf Blöcke in fester Höhe
    (`JetztSeite.swift:51-86`), und was nicht hineinpasst, ist weg - nicht weggerollt. Jede
    Zeile, die dazukommt (Wache, Störung, Mitteilungshinweis), muss gegen die Kurvenhöhe
    gerechnet werden. Die Vorlage löst es über `grid-template-rows: auto auto minmax(0,1fr)
    clamp(170px,24vh,260px) auto` (`globals.css:190`); das Gegenstück in der App ist
    `kurvenhoehe()` plus `maxHeight: .infinity` am Flussbild.
  * **`color-mix` gibt es nicht.** Die Vorlage tönt Ringe und Knöpfe mit
    `color-mix(in srgb, farbe 14%, transparent)` über einem deckenden Grund
    (`globals.css:223`, `Dock.tsx:52`); die App legt dafür zwei Kreise übereinander
    (`Energiefluss.swift:630-648`). Für den Dockknopf mit offenem Blatt denselben Weg nehmen.
