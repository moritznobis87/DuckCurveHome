# Messung: `/waerme/waermepumpe/regler` — App gegen Browser-Vorlage

Gemessen am 20.11.2026. Vorlage = Code im Browser-Zweig, nicht die Bildschirmfotos. Jede Behauptung
mit `Datei:Zeile`. Alle Pfade sind repo-relativ zu `/home/user/DuckCurveHome`.

**Gemessene Dateien**

| Rolle | Datei |
|---|---|
| App-Seite | `apps/ios/DuckCurveHome/Seiten/Technik/ReglerSeite.swift` (387 Zeilen) |
| Vorlage Einstieg | `apps/web/src/app/waerme/waermepumpe/regler/page.tsx` (13 Zeilen) |
| Vorlage Hülle | `apps/web/src/components/layout/AreaShell.tsx` |
| Vorlage Seite | `apps/web/src/components/waermepumpe/Regler.tsx` (315 Zeilen) |
| Vorlage Diagramm | `apps/web/src/components/waermepumpe/Heizkurve.tsx` (173 Zeilen) |
| Vorlage Kanalzug | `apps/web/src/components/waermepumpe/Fader.tsx` (97 Zeilen) |
| Vorlage Rechnung | `apps/web/src/components/waermepumpe/regler.ts` (157 Zeilen) |
| Vorlage Stil | `apps/web/src/styles/globals.css:927-1023`, `apps/web/src/styles/handy.css:236-243`, `apps/web/src/styles/tokens.css` |
| Dienst | `apps/api/src/dch_api/routers/waermepumpe.py:74-114`, `apps/api/src/dch_api/application/live_runtime.py:1321-1455` |

---

## IST — was die App heute zeigt

Aufbau von `ReglerSeite.swift:36-108`, in genau dieser Reihenfolge:

1. **Störungskarte**, nur bei Fehler — `ReglerSeite.swift:38-40` (`Stoerung`).
2. **Kopf ohne Karte** — `ReglerSeite.swift:156-171`:
   - `e.satzDe` in `Schrift.klein` = 13 pt (`apps/ios/DuckCurveHome/Gestalt/Typografie.swift:45`), Farbe `text1` — `ReglerSeite.swift:158-161`.
   - darunter `"Stand \(Formate.hhmm(iso: e.now))"` in `Schrift.winzig` = 11,5 pt (`Typografie.swift:46`), Farbe `text3` — `ReglerSeite.swift:163-164`.
   - daneben, nur wenn `stellenMoeglich != true`, das Wort `"Stellen ist gesperrt"` in `Schrift.winzig`, Farbe `achtung` — `ReglerSeite.swift:165-168`.
3. **Rückmeldungskarte** nach einem Griff: eine Karte mit `rueckmeldung` (`a.messageDe`) in `Schrift.klein` — `ReglerSeite.swift:43-45`.
4. **Je Gruppe eine Karte** mit `kicker: gruppe.name`, darin eine flache Liste `Einstellungszeile`, getrennt durch `Divider().overlay(Farbe.linie1)` — `ReglerSeite.swift:46-63`. Gruppen und ihre Reihenfolge kommen vom Dienst (`gruppen(_:)`, `ReglerSeite.swift:180-191`), ungefiltert: **jede** Einstellung landet in einer Gruppenkarte, stellbare und nur lesbare gemischt.
5. **Karte „Was der Regler tat"** mit `ReglerKennzahlenOut` über 7 Tage als siebenspaltige `Tabelle` — `ReglerSeite.swift:64-66, 116-154`; geholt in `ReglerSeite.swift:90`.
6. **Karte „Was geändert wurde"** aus `e.protokoll`: Name, Zeit · Urheber, `von → auf` — `ReglerSeite.swift:67-76, 207-224`.
7. **`Methode`** mit `hinweiseDe`, `hindernisDe`, `stellenJeTag` und einem festen Satz über den eBUS — `ReglerSeite.swift:77-84`.
8. **Nachfrage-Alert** je Griff: Titel „<Name> stellen?", Text „Von <alt> auf <neu>.\n\nDas wird am Regler selbst geändert, nicht nur hier." plus `hinweisDe` — `ReglerSeite.swift:95-107, 197-205`.

**Die Zeile selbst** (`Einstellungszeile`, `ReglerSeite.swift:282-387`):
- Zeile 1: links `nameDe` (`Schrift.klein`), darunter `kennung` (`Schrift.winzig`, `text3`), dahinter ggf. „verglichen" (Farbe `mist`) und ggf. „gesendet <Wert>, wartet auf den Regler" (Farbe `achtung`) — `ReglerSeite.swift:301-321`.
- rechts der Wert in `Schrift.zahl` = Mono 15 pt, bernsteinfarben sobald ein Entwurf dasteht — `ReglerSeite.swift:323-326`.
- Zeile 2 (nur bei `darfStellen`): ein **`Stepper`** mit `labelsHidden()`, dahinter „Stellen"/„Zurück" oder „Verglichen"/„Haken weg", rechts die Spanne „<von> bis <bis>" — `ReglerSeite.swift:349-385`.
- Zeile 3: `hinweisDe` in `Schrift.winzig` — `ReglerSeite.swift:331-336`.

**Was in der App gar nicht vorkommt** (gesucht in `ReglerSeite.swift`, kein Treffer):
`Chart`/`Canvas` (kein Diagramm), ein Schieber (`Slider` kommt nicht vor — nur `Stepper`, `ReglerSeite.swift:352`), ein Pult, Stufenknöpfe, ein Entwurfsstapel über mehrere Einstellungen, eine Übernahmeleiste, ein Knopf „Am Gerät steht …", ein zugeklappter Abschnitt „Nur zum Lesen", die Felder `art` und `muster` (gesucht nach `\.art` und `muster` in `ReglerSeite.swift`: kein Treffer), ein Nachfragetakt (`.task { await lade() }` läuft einmal, `ReglerSeite.swift:89`).

---

## VORLAGE — Block für Block

### 0. Hülle und Kicker
`page.tsx:9-11`: `<AreaShell kicker="Einstellungen · gelesen"><Regler /></AreaShell>`.
`AreaShell.tsx:16-30`: `main.dashboard-bg.report-main` mit `gap-4 p-5`, Kopfleiste (`min-h-14`, `border-line-2`, `surface-glass`, `backdrop-blur(18px)`), `UpdateHinweis`, `AreaTabs` (der Kicker steht rechts in der Reiterzeile), `AreaAnsichten`, Inhalt, `Fussleiste`.
Die Seite selbst ist `section.wp-seite.rg-seite` — Flexspalte, `gap: 16px` (`globals.css:787`), `padding-bottom: 12px` (`globals.css:928`).

### 1. Kopf (`Regler.tsx:117-124`)
- `p.wp-satz` = `daten.satz_de`, **22 px**, `line-height 1.3`, `--text-1` (`globals.css:789`); am Handy **19 px** (`handy.css:234`). Das ist der Satz der Bildschirmfotos: „21 von 22 Einstellungen gelesen. …"
- `span.wp-stand`, **13 px**, `--text-3` (`globals.css:790`), Text wörtlich:
  `` `${verglichen} von ${stellbar.length} stellbaren Einstellungen mit dem Bediengerät verglichen` `` plus `` ` · ${fehler}` `` wenn ein Ladefehler steht (`Regler.tsx:121-123`).
  `verglichen = stellbar.filter(w => w.bestaetigt).length`, `stellbar = daten.werte.filter(w => w.stellbar)` — `Regler.tsx:65-66`.
  **Eine Uhrzeit steht im Kopf der Vorlage nicht.**

### 2. Die beiden Warnabsätze (`Regler.tsx:126-135`)
- Nur wenn `!moeglich && daten.hindernis_de`: `p.wp-stumm` mit `role="status"`, Inhalt wörtlich
  **„Stellen ist gerade nicht möglich."** (in `<strong>`) + ` ` + `hindernis_de` + ` Lesen geht weiter.`
  Stil `globals.css:792`: 12/14 px Polster, 1 px Rand in `color-mix(amber 55%)`, Radius 12 px, Grund `color-mix(amber 9%)`, 14 px Schrift, `max-width: 760px`.
- Nur wenn `verglichen < stellbar.length`: `p.rg-anleitung`, 14 px, `line-height 1.5`, `--text-2`, `max-width: 820px` (`globals.css:933`), Text wörtlich:
  „Bevor sich eine Einstellung bewegen lässt, einmal am Bediengerät nachsehen: Steht dort dieselbe Zahl wie hier, den Knopf „Am Gerät steht …“ unter dem Regler drücken. Steht dort etwas anderes, ist die Kennung für diese Anlage falsch gelesen; dann bitte nicht drücken."

### 3. Meldungen nach dem Übernehmen (`Regler.tsx:137-146`)
`div.rg-meldungen[role=status]`: je Meldung `✓`/`✗` + Text, `data-ok=false` färbt `--alert`; darunter ein Knopf „Ausblenden" (`.rg-leise`). Stil `globals.css:934-937`.

### 4. Karte **Heizkurve** (`Regler.tsx:148-152`)
`div.card.kl-karte` (Karte: `surface-2`, 1 px `line-1`, Radius `--radius-2`=3 px, 20 px Polster — `globals.css:67-77`; `kl-karte` setzt Flexspalte, `gap:10px`, `padding:16px` — `globals.css:900`), darin `h2.kl-titel` **„Heizkurve"** (15 px, 600, `--text-1`, `globals.css:901`), dann `<Heizkurve …>`, dann `p.kl-klein` (13 px, `--text-3`, `max-width:760px`, `globals.css:898`) wörtlich:
„Die Kurve ist eine Näherung: Vorlauf = Raum + Steilheit × (Raum − außen) + Verschiebung, begrenzt auf den kleinsten und größten Vorlauf. Sie zeigt, wohin sich die Kurve mit einer Änderung bewegt; was der Regler daraus wirklich macht, zeigen danach die Punkte."

**Das Diagramm** (`Heizkurve.tsx`), Maße aus `Heizkurve.tsx:20-26`:
`B=760`, `H=360` (viewBox, skaliert über die Breite: `globals.css:943` `width:100%;height:auto`), `RAND = {l:46, r:22, o:16, u:40}`, X von −15 bis 22 °C, Y von 15 bis 65 °C, Steilheitsgriff bei **−10 °C**, Verschiebungsgriff bei **18 °C**. Umrechnung `px`/`py`/`klemme`/`linie` in `Heizkurve.tsx:28-31`.

Zeichenfolge (hintereinander, also Stapelreihenfolge):
1. Waagerechtes Raster bei 20/30/40/50/60 mit Zahl links (`textAnchor=end`, `x=RAND.l-8`) — `Heizkurve.tsx:109-114`. Senkrechtes Raster bei −15/−10/−5/0/5/10/15/20 mit Zahl unten — `Heizkurve.tsx:115-120`. `.rg-raster` = `rgba(255,255,255,0.07)`, 1 px (`globals.css:944`); `.rg-achse` = `--text-3`, Mono 11 px, am Handy 14 px (`globals.css:945`, `handy.css:242`).
2. Achsentitel **„Außentemperatur °C"** mittig unten (`y=H-6`) und **„Vorlauf °C"** links oben (`x=12,y=RAND.o+8`) — `Heizkurve.tsx:121-122`.
3. Zwei abgedunkelte Rechtecke über `soll.max` und unter `soll.min`: `.rg-aussen` = `rgba(0,0,0,0.22)` — `Heizkurve.tsx:125-126`, `globals.css:946`.
4. **Punktwolke**: je Stunde ein `circle r=2.6`, nur innerhalb X; `.rg-gemessen` = `--mist` mit `opacity .55` — `Heizkurve.tsx:129`, `globals.css:947`. Quelle: `api.betrieb(14)` → `b.stunden.map(s => ({aussen_c, soll_c}))` — `Regler.tsx:50-56`; fehlt sie, steht die Kurve ohne Punkte (`Regler.tsx:51`).
5. **Ist-Linie**, nur wenn der Entwurf abweicht: `.rg-ist-linie` = `--text-3`, 1,5 px, `dasharray 5 5` — `Heizkurve.tsx:132`, `globals.css:948`.
6. **Soll-Linie** (durchgezogen): `.rg-soll-linie` = `--heat-pump` (#e0966b), **3 px**, runde Ecken/Enden; bei Entwurf `--amber` mit `drop-shadow(0 0 6px amber 60%)` — `Heizkurve.tsx:133`, `globals.css:949-950`. Punkte je ganzem Grad aus `kurvenPunkte` (`regler.ts:153-156`).
7. **Grenzlinien max/min** als Griffpaar: waagerechte Linie `.rg-grenze` (`--text-3`, 1,5 px, `dasharray 2 4`), dahinter rechts ein Schild `rect 54×20, rx=6` (`.rg-griff-flaeche`) mit Text **„max 45°"** bzw. **„min 20°"** (`{g} {v.toFixed(0)}°`, Mono 11 px) — `Heizkurve.tsx:136-145`, `globals.css:951, 955, 962`.
8. **Steilheitsgriff**: unsichtbarer Fangkreis `r=22`, sichtbarer Kreis `r=11` in `.rg-griff-flaeche` (`surface-3`, 2 px `--amber`), darin ein Pfeil-nach-oben-Zeichen; daneben die Beschriftung **„Steilheit 1,00"** bei `x+18, y−12` — `Heizkurve.tsx:148-153`.
9. **Verschiebungsgriff**: Fangrechteck 44×44, sichtbares `rect 20×20, rx=5`, darin ein Doppelpfeil; Beschriftung **„Verschiebung +7,0 K"** rechtsbündig bei `x−16, y−16` — `Heizkurve.tsx:156-161`. `.rg-beschriftung` = `--text-1`, 12 px, mit `paint-order:stroke` und 4 px Kontur in `--surface-1`, damit sie über der Kurve lesbar bleibt (`globals.css:965`); am Handy 15 px (`handy.css:241`).
10. **Fußzeile** `div.rg-kurve-fuss` (Flex, `gap 6px 18px`, 12 px, `--text-3` — `globals.css:966`): Legende „eingestellt" bzw. „Entwurf" als 18 px Strich in `--heat-pump`, bei Entwurf zusätzlich „am Regler" als gestrichelter Strich, und „vom Regler verlangt, je Stunde" als 7 px Punkt in `--mist` — `Heizkurve.tsx:163-166`, `globals.css:968-970`. Rechts, mit `margin-left:auto` (am Handy 0, `handy.css:240`), in Mono: `bei −10 °C 45,0 °C · bei 0 °C 45,0 °C · bei 10 °C 41,0 °C` — `Heizkurve.tsx:167-169`.

**Zustände der Griffe** — `Heizkurve.tsx:62-97`: `role="slider"`, `tabIndex` 0/−1, `aria-valuemin/max/now/valuetext`, `aria-disabled`, `data-frei`, `data-zieht`. Freier Griff: `cursor:grab`, beim Überfahren/Ziehen füllt sich die Fläche in `--amber` und das Zeichen wird `--petrol`; gesperrter Griff: `stroke:--line-2`, `fill:--surface-2`, Zeichen `--text-3`, `cursor:default` (`globals.css:952-964`).
**Rechnung der Griffe**: Steilheit aus `steilheitDurch(k, −10, ziel)`, Verschiebung aus `verschiebungDurch(k, 18, ziel)`, min/max direkt, alle durch `raster()` auf das Schrittraster gezwungen — `Heizkurve.tsx:56-61`, `regler.ts:67-73, 144-150`.
**Fehlt eine der fünf Größen**, steht statt des Diagramms ein Satz: „Für die Kurve fehlt eine der fünf Einstellungen: Steilheit, Verschiebung, Raumtemperatur Tag, kleinster oder größter Vorlauf." — `Heizkurve.tsx:41-43`. Die fünf Schlüssel: `heat_pump_set_slope`, `heat_pump_set_offset_k`, `heat_pump_set_room_day_c`, `heat_pump_set_flow_min_c`, `heat_pump_set_flow_max_c` — `regler.ts:114-120`.

### 5. Karte **Pult** (`Regler.tsx:154-168`)
`div.card.kl-karte.rg-pult`, Grund `linear-gradient(180deg, surface-2, deep)` (`globals.css:973`), `h2.kl-titel` **„Pult"**.
`div.rg-zuege`: Flexreihe, `gap:22px`, `overflow-x:auto` (`globals.css:974`); am Handy randlos ausgefahren (`margin:0 -14px; padding:0 14px 8px`), `gap:14px`, `scroll-snap-type: x proximity` (`handy.css:237`).
Je Gruppe ein `div.rg-zuggruppe[role=group]` mit `aria-label` = Gruppenname: 1 px `--line-1`, Radius 14 px, Grund `rgba(0,0,0,0.18)`, `scroll-snap-align:start` am Handy (`globals.css:975`, `handy.css:238`). Darin `span.rg-gruppenname`: **11 px Sperrschrift**, `letter-spacing .14em`, `uppercase`, `--text-3` (`globals.css:976`) — das ist das „HEIZKURVE" der Bildschirmfotos.
Gruppen und Auswahl: `["Heizkurve","Raum","Warmwasser"]`, je nur `art === "zahl"` und nur `stellbar` — `Regler.tsx:67-68`. Leere Gruppen fallen weg.

**Ein Kanalzug** (`Fader.tsx:37-95`), Breite **96 px**, am Handy **88 px** (`globals.css:978`, `handy.css:239`), Flexspalte mittig, `gap:8px`:
- `div.rg-anzeige.mono`: volle Breite, 6/4 px Polster, 1 px `--line-1`, Radius 8 px, Grund `#06151c`, Farbe `--heat-pump`, **15 px**, `tabular-nums` — `globals.css:979`. Inhalt `zahlText(w, wert)` oder `?` (`Fader.tsx:39`). Bei Entwurf: Farbe `--amber`, Rand `amber 60%`, `box-shadow 0 0 10px amber 25%` (`globals.css:980`); gesperrt: `--text-3` (`globals.css:981`).
- `div.rg-bahn[role=slider]`: **56 × 190 px**, `margin:6px 0`, `cursor:grab`, `touch-action:pan-x` (waagerechtes Rollen bleibt, senkrechtes Ziehen gehört der Bahn) — `globals.css:982-984`. Mit `aria-valuemin/max/now/valuetext/orientation=vertical/disabled` (`Fader.tsx:42-52`).
  - `div.rg-skala`: fünf Haarlinien bei 0/25/50/75/100 % (`Fader.tsx:78-82`, `globals.css:989`).
  - `div.rg-rille`: 8 px breit, mittig, Radius 4, `#06151c`, innen 1 px `--line-1`; darin `div.rg-fuellung` von unten auf `anteil(w,wert)·100 %`, Verlauf `--heat-pump`, bei Entwurf `--amber`, gesperrt `--line-2` — `Fader.tsx:83-85`, `globals.css:985-988`.
  - `div.rg-ist`: 2 px Querstrich auf der Höhe des **gelesenen** Werts, an beiden Enden `--text-2` (`Fader.tsx:86`, `globals.css:990`). Das ist der Strich, der sagt, was am Regler steht.
  - `div.rg-knopf`: **44 × 26 px**, Radius 6, Verlauf hell/dunkel/hell mit Mittelkerbe, Schatten; bei Entwurf bernstein, gesperrt grau — `Fader.tsx:87`, `globals.css:991-993`.
- `div.rg-tasten`: zwei Knöpfe **„−"** und **„+"**, je **34 × 30 px**, 1 px `--line-2`, Radius 8, `surface-2`, 17 px; `aria-label` „<Name> einen Schritt kleiner/größer"; `disabled` wenn nicht frei — `Fader.tsx:89-92`, `globals.css:995-997`.
- `div.rg-name`: `min-height:34px`, 12,5 px, mittig, `--text-1` — `Fader.tsx:93`, `globals.css:998`.
- `div.rg-kanal-fuss`: `min-height:30px`, 11,5 px, mittig, `--text-3` — `Fader.tsx:94`, `globals.css:999`. Inhalt kommt von `fuss(w)`, siehe Abschnitt „Absicherung".

**Bedienung der Bahn** — `Fader.tsx:53-76`: `pointerdown` nur wenn frei, `setPointerCapture`; mit der Maus springt der Wert sofort an die Zeigerstelle, **mit dem Finger erst nach 6 px senkrechter Bewegung** („wer das Pult zur Seite schiebt und dabei auf einer Bahn landet, soll damit keinen Wert verstellen", `Fader.tsx:19-22`). Pfeiltasten auf/rechts bzw. ab/links gehen genau einen Schritt (`Fader.tsx:70-76`). Umrechnung Zeiger → Wert über das Rechteck der Bahn, nicht über Bildpunkte (`Fader.tsx:28-32`, `regler.ts:83-87`).

### 6. Karte **Schalter** (`Regler.tsx:170-199`), nur wenn es welche gibt
`h2.kl-titel` **„Schalter"**. `div.rg-schalterfeld`: Raster **zwei Spalten**, `gap:14px` (`globals.css:1005`); am Handy **eine Spalte** (`handy.css:236`).
Je Einstellung `div.rg-schalter` mit `data-frei`, `data-geaendert`: Flexspalte, `gap:8px`, 12 px Polster, 1 px `--line-1`, Radius 12, Grund `rgba(0,0,0,0.14)`; bei Entwurf Rand `amber 60%` (`globals.css:1006-1007`).
- `span.rg-schaltername`: 14 px, `--text-1`, Inhalt `` `${w.gruppe_de}: ${w.name_de}` `` — also **„Warmwasser: Betriebsart"**; dahinter, wenn `w.muster`, ein `<em>` in 12 px `--text-3` mit **„ · Stellbefehl nach Muster gebildet"** — `Regler.tsx:180-183`, `globals.css:1008-1009`.
- `div.rg-stufen[role=radiogroup]` mit `aria-label` = „Gruppe: Name": je Eintrag von `w.wahl` ein `button[role=radio]` mit `<span class="mono">{zahl}</span> {wort}` — also **„0 aus"**, **„1 nach Zeitprogramm"**, **„2 immer an"** — `Regler.tsx:184-189`.
  Stil `globals.css:1010-1015`: 8/12 px Polster, 1 px `--line-2`, Radius 10, `surface-2`, 13 px, `--text-2`, **`border-bottom-width: 3px`**; `data-ist=true` (= der am Regler stehende Wert) setzt `border-bottom-color: --text-2` — **das ist „die Stufe mit dem Strich darunter"**; `aria-checked=true` (= der gewählte/angezeigte Wert) füllt `--heat-pump` mit `--petrol` Schrift und 600 Gewicht, bei Entwurf `--amber`; `disabled` → `opacity .55`.
- `span.rg-schalterhinweis`: `w.hinweis_de`, 12 px, `--text-3` — `Regler.tsx:191`, `globals.css:1016`. (Das ist der Erklärabsatz unter „Betrieb: Heizbetrieb" auf dem Bildschirmfoto.)
- `span.rg-kanal-fuss` mit `fuss(w)`, hier linksbündig und ohne Mindesthöhe (`globals.css:1017`).
Unter dem Feld `p.kl-klein` wörtlich:
„Die Wörter an den Stufen sind die Lesart der Busbeschreibung; der Regler kennt nur die Zahl davor. Die Stufe mit dem Strich darunter ist die, die am Regler steht." — `Regler.tsx:197`.
Auswahl: `schalter = stellbar.filter(w => w.art !== "zahl")` — `Regler.tsx:69`; `art` kennt `zahl`, `wahl`, `schalter` (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:720-724`).

### 7. `details` **„Nur zum Lesen (n)"** (`Regler.tsx:201-228`)
`details.kl-liste` (14 px, `--text-2`; `summary` mit `cursor:pointer`, 6 px Polster — `globals.css:1025-1027`), `summary` = `Nur zum Lesen ({nurLesen.length})`. Darin `table.kl-tabelle.rg-tabelle` mit vier Spalten **Einstellung · Wert · gelesen · Kennung**; je Zeile `data-gemessen={gelesen(w)}`; unter dem Namen ggf. `span.rg-lesart` „laut Busbeschreibung: …" (12 px, `--text-3`, `globals.css:932`); `td.rg-wert` 16 px in `--amber`, bei `data-gemessen=false` `--text-3` (`globals.css:930-931`). Quelle `nurLesen = daten.werte.filter(w => !w.stellbar)` — `Regler.tsx:70`.
Am Handy rollt die Karte waagerecht (`handy.css:246`) und die Tabelle steht in 13 px (`handy.css:247`).

### 8. `details` **„Was zuletzt gestellt wurde (n)"**, `open` (`Regler.tsx:230-256`)
Tabelle **Zeit · Einstellung · von · auf · wer**; Zeit als `de-DE` Tag.Monat, Stunde:Minute in `Europe/Berlin` (`Regler.tsx:246`).

### 9. `details` **„Vermerke zurücknehmen"** (`Regler.tsx:258-271`)
Nur wenn mindestens ein stellbarer Wert `bestaetigt` ist: je Wert ein `.rg-leise`-Knopf „<Gruppe>: <Name> ist doch nicht verglichen", der `vergleichen(w, false)` ruft. `div.rg-vermerke` = Flex mit Umbruch, `gap:8px` (`globals.css:1018`).

### 10. Fuß (`Regler.tsx:273-283`)
`div.wp-fuss` (Flexspalte, `gap:6px`, `max-width:760px`, 13 px, `line-height 1.55`, `--text-3` — `globals.css:795`): je Satz aus `daten.hinweise_de` ein `<p>`, darunter `p.wp-links` mit zwei Verweisen in `--amber`: „Die Heizkurve, wie sie gefahren wird ›" → `/waerme/waermepumpe/betrieb`, „Die Wärmepumpe jetzt ›" → `/waerme/waermepumpe` (`globals.css:796-798`).

### 11. Die Übernahmeleiste (`Regler.tsx:285-312`) — **nur wenn `offen.length > 0`**
`div.rg-leiste[role=region]` mit `aria-label="Änderungen übernehmen"`: `position:sticky; bottom:12px; z-index:5`, Flex mit Umbruch, 12/16 px Polster, 1 px `amber 55%`, Radius 16, Grund `color-mix(deep 92%, amber)`, Schatten `0 10px 30px rgba(0,0,0,.45)`, 14 px (`globals.css:1021`). Am Handy sitzt sie über der Bereichsleiste: `bottom: calc(86px + env(safe-area-inset-bottom))` (`handy.css:243`).
Zwei Stufen:
- Stufe 1: links `span.rg-zahl` „1 Änderung im Entwurf" bzw. „n Änderungen im Entwurf"; rechts „Verwerfen" (`.rg-leise`) und „Übernehmen …" (`.rg-haupt`).
- Stufe 2 (`uebersicht === true`): links `div.rg-uebersicht` mit `<strong>` **„Diese Änderungen gehen an den Regler der Wärmepumpe und bleiben dort stehen:"** und darunter eine `<ul>` mit je `Gruppe: Name <mono>alt → neu</mono>`; rechts „Zurück" und **„Jetzt stellen"**; während des Sendens „Wird gesendet …" (`Regler.tsx:287-309`).
`.rg-haupt` = 9/18 px, Radius 999, `--amber` gefüllt, `--petrol` Schrift, 600 (`globals.css:938`); `.rg-leise` = 6/12 px, Radius 999, Rand `--line-2`, `--text-2` (`globals.css:936`). Beide mit `:focus-visible { outline: 2px solid --amber; offset 2px }` (`globals.css:940`).

### 12. Nachfragetakt (`Regler.tsx:42-48`)
`wartet = daten?.werte.some(w => w.gesendet)`. Neu geladen wird **alle 5 s, solange ein gesendeter Wert auf Rückmeldung wartet, sonst alle 60 s**.

### 13. Handy-Fassung — was sie wirklich ändert
`handy.css` greift unter **`max-width: 720px`** (`handy.css:107`, `handy.css:405`). Für diese Seite ändert sie **nur Maße, nicht den Aufbau** (`handy.css:234-247`): `wp-satz` 19 px; Schalterfeld einspaltig; Pultzüge randlos mit Schnappen, Kanal 88 px; Kurvenwerte linksbündig; Beschriftung 15 px, Achsen und Griffschilder 14 px; Leiste über der Bereichsleiste; `kl-liste`/`kl-karte` rollen waagerecht; Tabellen 13 px.
**Das Diagramm, das Pult und die Stufenknöpfe bleiben am Handy also da.** Eine Spaltenfassung ohne Kurve gibt es in der Vorlage nicht (gesucht nach `rg-kurve`, `rg-pult`, `rg-zuege`, `rg-stufen` mit `display:none` in `handy.css`: kein Treffer).

---

## Absicherung — wie die Vorlage verhindert, dass versehentlich gestellt wird

**Das ist der Kern dieser Seite: sie stellt eine echte Wärmepumpe.** Die Vorlage sichert in sechs Stufen:

1. **Vier Sperrgründe, in dieser Reihenfolge** — `regler.ts:56-62`:
   `!w.stellbar` → `"nur lesen"`; `!gelesen(w)` → `"nicht gelesen"`; `!w.bestaetigt` → `"nicht verglichen"`; `!stellenMoeglich` → `"Stellen nicht möglich"`; sonst `null`.
   `gelesen(w)` verlangt `wert.value != null` **und** `quality ∈ {ok, derived}` — `regler.ts:33-35`. `bedienbar = sperre(...) === null` — `regler.ts:64`.
2. **Ohne Vergleich bewegt sich nichts.** Der Kanalzug ist nur frei, wenn `sperre === null && wert != null` (`Fader.tsx:23`); dann und nur dann nimmt die Bahn einen Zeiger an (`Fader.tsx:54`), ist sie fokussierbar (`Fader.tsx:44`), gehen die Pfeiltasten (`schritt()` prüft `frei`, `Fader.tsx:33-35`) und sind „−"/„+" nicht `disabled` (`Fader.tsx:90-91`). Dasselbe im Diagramm: `frei(griff) = bedienbar(w(griff), stellenMoeglich)` (`Heizkurve.tsx:45`), `onPointerDown`/`onKeyDown` kehren sofort um, wenn `!an` (`Heizkurve.tsx:79, 89`). Dasselbe bei den Stufen: `disabled={!frei}` (`Regler.tsx:186`).
3. **Der Gerätevergleich** — `Regler.tsx:103-115` (`fuss`) und `Regler.tsx:72-80` (`vergleichen`):
   - Wartet ein gesendeter Wert, steht statt allem anderen `span.rg-wartet` **„gesendet <Wert>, wartet auf den Regler"** in `--amber` (`globals.css:1002`).
   - Ist der Grund genau `"nicht verglichen"`, steht dort ein **gestrichelt umrandeter Knopf** `.rg-vergleich` mit dem Text **„Am Gerät steht <gelesener Wert>"** (`Regler.tsx:108-111`). Stil `globals.css:1000-1001`: 5/8 px Polster, **1 px gestrichelt** in `amber 70%`, Radius 8, Grund `amber 9%`, `--text-1`, 11,5 px; beim Überfahren `amber 20%`.
     **Er sendet nichts an die Pumpe.** Er ruft `api.reglerBestaetigen(w.schluessel, true)` und schaltet damit die Sperre „nicht verglichen" ab (`Regler.tsx:74`). Der gelesene Wert steht **im Knopftext**, damit man ihn am Bediengerät gegenlesen kann, ohne hin- und herzusehen. Darum sagt `rg-anleitung` ausdrücklich: steht am Gerät etwas anderes, ist die Kennung falsch gelesen — **dann nicht drücken** (`Regler.tsx:133`).
   - Jeder andere Grund steht als stummer Text `span.rg-grund`; ist kein Grund da, steht „gelesen <HH:MM>" (`Regler.tsx:113-114`, `standText` in `regler.ts:50-53`).
   - Zurücknehmen löscht zugleich den Entwurf dieser Einstellung: `if (!bestaetigt) setEntwurf(({[w.schluessel]:_, ...rest}) => rest)` — `Regler.tsx:76`. Ein Entwurf überlebt also nicht das Zurückziehen des Vergleichs.
4. **Bewegen ist nicht senden.** Jede Bewegung schreibt nur in `entwurf` (`Regler.tsx:64`). Was offen ist, rechnet `aenderungen()`: nur gelesene Werte, nur echte Unterschiede über `1e-6` — `regler.ts:100-108`. Ein Entwurf, der dem gelesenen Wert gleicht, ist keine Änderung.
5. **Zwei Knopfdrücke mit einer Liste dazwischen.** Erst „Übernehmen …", dann die Übersicht mit dem Satz „Diese Änderungen gehen an den Regler der Wärmepumpe und bleiben dort stehen:" und jeder Zeile als `alt → neu`, dann „Jetzt stellen" — `Regler.tsx:287-309`. `uebernehmen()` geht **nacheinander, nicht zugleich**: „jede Einstellung ist ein eigener Befehl auf dem Bus" (`Regler.tsx:86-95`). Jede Antwort wird einzeln als `✓`/`✗` mit ihrem Satz gezeigt (`Regler.tsx:90, 93, 137-146`).
6. **Gestellt ist erst, wenn der Regler es zurückmeldet.** `api.reglerStellen` antwortet mit dem vollständigen Satz der Einstellungen, der übernommen wird (`Regler.tsx:89, 96`); bis zur Rückmeldung trägt die Einstellung `gesendet` und die Seite fragt alle 5 s nach (`Regler.tsx:42-48`). Der Dienst prüft dieselben Bedingungen noch einmal und lehnt mit Grund ab: `routers/waermepumpe.py:95-99` („nicht in der Liste steht, gerade nicht gelesen ist, **nicht mit dem Bediengerät verglichen** wurde, außerhalb der Grenzen liegt oder heute schon zu oft gestellt wurde"), `live_runtime.py:1380-1392` (`regler_logic.pruefen` + `_regler_hindernis`), und schreibt jede Änderung mit alt/neu/Urheber ins Ereignisprotokoll (`live_runtime.py:1403-1409`). `regler.ts:9-13` sagt, warum trotzdem beides geprüft wird: „hier sorgen sie dafür, dass ein Regler, der nichts bewirken würde, sich gar nicht erst bewegt."

**Wie die App heute dagegen steht:**
- `darfStellen` prüft nur `haus.darfSchalten && stellenMoeglich == true && stellbar == true` — `ReglerSeite.swift:193-195`. **`bestaetigt` fehlt**, und **die Güte fehlt**: `jetzigerWert` liest `einstellung.wert.value` roh (`ReglerSeite.swift:291-293`), nicht `wert.belastbar` (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Guete.swift:50-52`). Ein nie verglichener oder ein veralteter Wert ist in der App also **bewegbar und absendbar**; der Dienst lehnt ab, aber die Oberfläche hat es angeboten.
- Die App fragt je Griff einmal nach (`ReglerSeite.swift:95-107`) und sendet dann sofort — kein Entwurf, keine Übersicht über mehrere Änderungen, kein zweiter Knopf.
- Der Knopf heißt „Verglichen"/„Haken weg" und **nennt den Wert nicht** (`ReglerSeite.swift:374-376`). Damit fehlt genau die Gegenprobe, die die Vorlage erzwingt.
- `hindernisDe` steht nur in der zugeklappten `Methode` (`ReglerSeite.swift:79`), im Kopf steht dafür bloß „Stellen ist gesperrt" in 11,5 pt (`ReglerSeite.swift:166-167`). Der Warnabsatz `wp-stumm` und der Anleitungsabsatz `rg-anleitung` fehlen ganz.
- Kein Nachfragetakt: `ReglerSeite.swift:89` lädt einmal. Ein `gesendet` bleibt stehen, bis jemand die Seite neu betritt.

→ **Die App stellt heute leichter als die Vorlage.** Das ist der schwerste Befund dieser Messung und steht in LUECKEN als erster Punkt.

---

## LUECKEN

1. `[traegt-die-seite]` **Die Sperre „nicht verglichen" fehlt in der App.** Vorlage: `regler.ts:56-62` + `Fader.tsx:23` + `Heizkurve.tsx:45` + `Regler.tsx:186`. App: `ReglerSeite.swift:193-195`. Zusätzlich fehlt die Güteprüfung (`regler.ts:33-35` gegen `ReglerSeite.swift:291-293`). Die App bietet das Stellen an, wo die Vorlage es sperrt.
2. `[traegt-die-seite]` **Kein gestrichelter Knopf „Am Gerät steht <Wert>".** Vorlage `Regler.tsx:108-111`, `globals.css:1000-1001`. App: nur „Verglichen"/„Haken weg" ohne Wert, `ReglerSeite.swift:374-376`.
3. `[traegt-die-seite]` **Kein Heizkurvendiagramm.** Vorlage `Heizkurve.tsx:105-171` — Raster, Achsentitel, Punktwolke aus 14 Tagen, Soll- und Ist-Linie, zwei Grenzlinien mit Schildern, zwei Ziehgriffe, Legende, Mono-Zeile „bei −10 °C …", Näherungsabsatz. App: kein `Chart`, kein `Canvas` in `ReglerSeite.swift`.
4. `[traegt-die-seite]` **Kein Pult.** Vorlage `Regler.tsx:154-168` + `Fader.tsx` — Gruppenkästen mit Sperrschriftnamen, senkrechte Bahnen 56 × 190 px, Wertfeld, Ist-Strich, −/+-Tasten. App: ein `Stepper` in einer Textzeile, `ReglerSeite.swift:349-385`.
5. `[traegt-die-seite]` **Keine Stufenknöpfe.** Vorlage `Regler.tsx:184-189` mit `role=radiogroup`, `data-ist` als Strich darunter, `aria-checked` als Füllung. App: die Stufe steht als Wort rechts (`ReglerSeite.swift:344`) und wird mit einem `Stepper` durchgezählt. Dabei bleiben `art` und `muster` ungenutzt (gesucht in `ReglerSeite.swift`: kein Treffer) — der Hinweis „· Stellbefehl nach Muster gebildet" (`Regler.tsx:182`) fehlt.
6. `[traegt-die-seite]` **Kein Entwurf und keine Übernahmeleiste.** Vorlage `Regler.tsx:58, 285-312`, `regler.ts:100-108`. Die App sendet je Griff sofort nach einer Alert-Nachfrage.
7. `[spuerbar]` **Die Vergleichszeile im Kopf fehlt**, stattdessen steht dort eine Uhrzeit. Vorlage `Regler.tsx:121-123`; App `ReglerSeite.swift:163-164`. Der Nutzer sieht in der App nicht, wie weit der Vergleich gediehen ist.
8. `[spuerbar]` **Der führende Satz ist zu klein.** Vorlage 22 px, am Handy 19 px (`globals.css:789`, `handy.css:234`); App `Schrift.klein` = 13 pt (`ReglerSeite.swift:159`, `Typografie.swift:45`). Die App hat `Schrift.satz` = 19 pt genau dafür (`Typografie.swift:64`).
9. `[spuerbar]` **Die drei Erklärabsätze fehlen**: `wp-stumm` (`Regler.tsx:126-130`), `rg-anleitung` (`Regler.tsx:131-135`), der Näherungsabsatz zur Kurve (`Regler.tsx:151`) und der Schaltersatz (`Regler.tsx:197`).
10. `[spuerbar]` **Kein Nachfragetakt.** Vorlage 5 s/60 s (`Regler.tsx:42-48`); App lädt einmal (`ReglerSeite.swift:89`).
11. `[spuerbar]` **„Nur zum Lesen" ist nicht abgetrennt.** Vorlage: eigener zugeklappter Abschnitt mit vier Spalten, `nurLesen = werte.filter(w => !w.stellbar)` (`Regler.tsx:70, 201-228`). App: nur lesbare Einstellungen stehen gleichberechtigt in den Gruppenkarten (`ReglerSeite.swift:46-63`, `gruppen` filtert nicht).
12. `[spuerbar]` **Keine Einzelmeldungen mit ✓/✗.** Vorlage `Regler.tsx:137-146`; App eine Karte mit dem letzten `messageDe` (`ReglerSeite.swift:43-45`), ohne Erfolgszeichen und ohne „Ausblenden".
13. `[klein]` **„Vermerke zurücknehmen" fehlt** als eigener Abschnitt (`Regler.tsx:258-271`); in der App geht es nur über denselben Knopf in der Zeile.
14. `[klein]` **Die Vorzeichenregel fehlt.** Vorlage: `zahlText` setzt bei Einheit `K` und positivem Wert ein `+` („+7,0 K") — `regler.ts:38-42`. App: `wertAlsText` (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Woerter.swift:16-21`) über `Formate.zahl` (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift:44-55`) ohne Plus.
15. `[klein]` **Die zwei Verweise im Fuß fehlen** („Die Heizkurve, wie sie gefahren wird ›", „Die Wärmepumpe jetzt ›") — `Regler.tsx:279-282`.
16. `[klein]` **Die App zeigt eine Karte, die auf dieser Route nicht hingehört:** „Was der Regler tat" (`ReglerSeite.swift:64-66, 116-154`). In der Vorlage hängt `Kennzahlen` an `/waerme/waermepumpe` (`apps/web/src/components/waermepumpe/Waermepumpe.tsx:11, 104`), nicht an `regler`. Entweder weglassen oder bewusst behalten — aber nicht unbemerkt.
17. `[klein]` **Protokoll-Spalten**: Vorlage fünf Spalten mit Datum (Zeit · Einstellung · von · auf · wer, `Regler.tsx:233-254`); App eine Zeile „Name / Zeit · Urheber / von → auf" ohne Datum (`ReglerSeite.swift:207-224`).

**Eine Eigenheit der Vorlage, die nicht nachgebaut werden sollte**: das Pult zeigt nur stellbare `zahl`-Einstellungen der drei Gruppen „Heizkurve", „Raum", „Warmwasser" (`Regler.tsx:68`). Eine stellbare Zahl in einer vierten Gruppe fiele dort unter den Tisch. Beim Nachbauen gehört eine vierte Gruppe in eine weitere `rg-zuggruppe`, nicht ins Nichts.

---

## KERN: SCHON DA

- **Modelle**, vollständig erzeugt: `ReglerEinstellungOut` mit `art`, `stellbar`, `von`, `bis`, `schritt`, `wahl`, `bestaetigt`, `muster`, `hinweisDe`, `lesartDe`, `gesendet` — `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:7715-7798`; `ReglerEinstellungenOut` (`:7801-7848`), `ReglerGesendetOut` (`:7851-7865`), `ReglerAenderungOut` (`:7664-7699`), `ReglerStellenOut` (`:7971-7994`), `ReglerEinstellungOutArtWahl` mit `zahl/wahl/schalter/unbekannt` (`:720-730`), `Messwert` mit `value`/`observedAt`/`quality` (`:6587-6614`).
- **Netz**: `reglerEinstellungen()` (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:281-283`), `stelleRegler(_:wert:)` (`:289-294`), `bestaetigeRegler(_:bestaetigt:)` (`:297-302`), `betrieb(tage:)` (`:304-306`), `reglerKennzahlen(tage:)` (`:277-279`).
- **Stunden für die Punktwolke** liegen bereit: `BetriebStundeOut` mit `aussenC` und `sollC` — `Schema.swift:2113-2137`; dieselbe Quelle, die die Vorlage nutzt (`Regler.tsx:52-54`).
- **Güte**: `Quality.traegt` (ok/derived) und `Messwert.belastbar` — `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Guete.swift:15-17, 50-52`. Das ist genau `gelesen()` aus `regler.ts:33-35`, nur noch nicht an der Seite benutzt.
- **Wert als Text**: `ReglerEinstellungOut.wertAlsText(_:)` — `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Woerter.swift:11-22` (Wahlwort, Zahl mit Einheit, sonst Strich). Entspricht `wertText`/`zahlText` bis auf das Plus bei `K`.
- **Formate**: `zahl`, `celsius`, `prozent`, `hhmm(iso:)`, `leer`, `schmalesLeerzeichen`, `minus` — `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift:23, 27, 44, 98, 104, 148`.
- **Farben und Schriften** 1:1 zu `tokens.css`: `Farbe.waermepumpe` (= `--heat-pump`), `amber`, `amberWeich`, `mist`, `petrol`, `deep`, `flaeche1/2/3`, `linie1/2`, `rasterlinie`, `text1/2/3`, `kicker`, `achtung`, `alarm` — `apps/ios/DuckCurveHome/Gestalt/Farben.swift:29-79`; Maße `Marken.radius1/2/3 = 2/3/6` — `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift:311-313`. Schriften `Schrift.satz` 19, `karte` 15, `text` 15, `klein` 13, `winzig` 11,5, `kicker` 10,5, `zahl` Mono 15, `zahlKlein` Mono 12,5, `achse` Mono 10,5, plus `Schrift.sans(_:)`/`Schrift.mono(_:)` für Zwischengrößen — `apps/ios/DuckCurveHome/Gestalt/Typografie.swift:40-101`.
- **Bausteine**: `Seite` (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:141-175`), `Karte` mit Kicker/Titel/Beiwerk und den beiden Breitenfassungen (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:15-113`), `Kicker` (`Typografie.swift:132-141`), `Zeile`/`Leer`/`Stoerung` (`Karte.swift:360, 390, 410`), `Tabelle` (`apps/ios/DuckCurveHome/Seiten/Bericht.swift:157`), `Methode` als `DisclosureGroup` (`Bericht.swift:334-397`), `Tagewahl` als Knopfreihe (`apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift:376-400`).
- **Vorbild für einen Schalterkasten mit Stufen**: `Speichersteuerkarte` — drei Betriebsarten als ein Kasten mit Haarlinien, fünf Stufen als Knöpfe, Griffhöhe **44 pt**, gesperrt = `opacity .45`, `accessibilityAddTraits(.isSelected)`, `accessibilityHint` — `apps/ios/DuckCurveHome/Bausteine/Speichersteuerkarte.swift:34-36, 74-170`.
- **Vorbild für eine gezeichnete Fläche, die auf Ziehen antwortet**: `Jahresflaeche` — `Canvas` + `.contentShape(Rectangle())` + `DragGesture(minimumDistance: 0)` mit eigener Umrechnung Punkt → Datenwert — `apps/ios/DuckCurveHome/Diagramme/Jahresflaeche.swift:76-90, 125-132, 134-140`; dort steht auch die Begründung, warum die Rückrechnung dieselbe sein muss wie das Zeichnen. Fadenkreuz-Vorbild: `apps/ios/DuckCurveHome/Diagramme/Tageskurve.swift:382-401`.
- **Eine Heizkurve ist nur zur Hälfte da, und es ist die andere Hälfte:** `BetriebHeizkurveOut` (`Schema.swift:1907-1946`) ist die **gemessene** Regressionsgerade `a + b·außen`, gezeichnet auf der Betriebsseite — `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift:299-362`. Die **eingestellte** Näherung aus Steilheit/Verschiebung/Raum/min/max gibt es im Kern nicht (gesucht nach `steilheit`, `Steilheit`, `kurveAus`, `vorlaufFrei` in `apps/ios/`: kein Treffer außer `Gelduebersicht.verschiebung`, was Geldverschiebung ist und nichts mit der Heizkurve zu tun hat). Der Kommentar in `WaermepumpeSeiten.swift:299-303` nennt den Unterschied ausdrücklich: „dort steht, was eingestellt *ist*; hier steht, was dabei herauskommt."
- **`KennlinieSeite` hilft als Vorbild, nicht als Rechnung**: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift:113-173` zeigt ein Streubild mit Punkten, Linien, Achsen in `Schrift.achse`/`Farbe.rasterlinie` und einer eigenen Legende (`:199-227`). Sie rechnet aber die Arbeitszahl, nicht den Vorlauf.

---

## ES FEHLT — was neu in den Kern gehört

Alles aus `apps/web/src/components/waermepumpe/regler.ts` hat heute **kein** Gegenstück in `DuckCurveKit`. Es ist Logik mit genau einer richtigen Antwort je Eingabe, also gehört es in den Kern und wird dort geprüft — die Begründung steht wörtlich in `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Woerter.swift:5-10`.

**Neu: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Reglerpult.swift`**

| Soll | Vorlage |
|---|---|
| `gelesen(_ w:) -> Bool` (`wert.belastbar != nil`) | `regler.ts:33-35` |
| `enum Sperre { nurLesen, nichtGelesen, nichtVerglichen, nichtMoeglich }` mit `wort` = „nur lesen"/„nicht gelesen"/„nicht verglichen"/„Stellen nicht möglich" und `sperre(_:stellenMoeglich:) -> Sperre?` in genau der Reihenfolge der Vorlage | `regler.ts:56-62` |
| `bedienbar(_:stellenMoeglich:) -> Bool` | `regler.ts:64` |
| `zahlText(_:_:) -> String` **mit** dem Plus bei Einheit `K` | `regler.ts:38-42` |
| `wertText(_:)`, `standText(_:jetzt:)` („nicht gelesen" bzw. HH:MM Berlin) | `regler.ts:44-53` |
| `raster(_:_:)`, `anteil(_:_:)`, `wertBei(_:_:)`, `sichtbar(_:entwurf:)` | `regler.ts:67-94` |
| `struct Aenderung { w; alt; neu }`, `aenderungen(_:entwurf:)` mit Schwelle `1e-6` | `regler.ts:96-108` |
| `struct Kurve { steilheit; verschiebung; raum; min; max }`, `KURVE`-Schlüssel, `kurveAus(_:entwurf:)` | `regler.ts:112-135` |
| `vorlaufFrei`, `vorlauf` (geklemmt), `steilheitDurch`, `verschiebungDurch`, `kurvenPunkte(von:bis:)` | `regler.ts:138-156` |
| `pultgruppen(_:)` → `[(name, [ReglerEinstellungOut])]` für „Heizkurve"/„Raum"/„Warmwasser", `art == .zahl`, `stellbar` — **plus** eine Auffanggruppe für stellbare Zahlen anderer Gruppen (siehe Eigenheit oben) | `Regler.tsx:67-68` |
| `schalter(_:)` = stellbar mit `art != .zahl`; `nurLesen(_:)` = `!stellbar` | `Regler.tsx:69-70` |
| `verglichenSatz(_:)` → „n von m stellbaren Einstellungen mit dem Bediengerät verglichen" | `Regler.tsx:121-123` |
| `anleitungssatz`, `naeherungssatz`, `stufensatz`, `uebersichtssatz`, `hindernissatz(_:)` als Konstanten (die vier Absätze wörtlich) | `Regler.tsx:128, 133, 151, 197, 289` |
| `takt(wartet:)` → 5 s / 60 s | `Regler.tsx:46` |

**Neu: `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests/ReglerpultTests.swift`** — die Reihenfolge der vier Sperrgründe, das Plus bei `K`, `raster` auf dem Schrittraster, `aenderungen` lässt einen Entwurf gleich dem gelesenen Wert fallen, `vorlauf` klemmt auf min/max, `steilheitDurch`/`verschiebungDurch` sind die Umkehrungen von `vorlaufFrei` bei −10 bzw. 18 °C.

---

## BAUPLAN

### A. Kern
1. `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Reglerpult.swift` — die Tabelle aus „ES FEHLT", ohne SwiftUI, mit Quellenzeilen der Vorlage im Doc-Kommentar.
2. `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests/ReglerpultTests.swift`.
3. `Woerter.swift`: `wertAlsText` bleibt, bekommt aber einen Geschwister `zahlTextMitVorzeichen` oder das Plus wandert nach `Reglerpult.zahlText` — **nicht** `Formate.zahl` ändern, die hängt an 14 anderen Seiten.

### B. Neue Ansichten unter `apps/ios/DuckCurveHome/Seiten/Technik/Regler/`
4. **`Heizkurvenbild.swift`** — Karte „Heizkurve".
   `Canvas` nach dem Vorbild `Jahresflaeche.swift:76-90`, Seitenverhältnis **760 : 360** (`Heizkurve.tsx:20-21`), Ränder `l 46 / r 22 / o 16 / u 40` in Zeichenpunkten umgerechnet auf die gemessene Breite. Reihenfolge wie `Heizkurve.tsx:109-161`: Raster (`Farbe.rasterlinie`), Achsenzahlen (`Schrift.achse`, am Telefon eine Stufe größer wie `handy.css:242`), Achsentitel, zwei abgedunkelte Flächen (`Color.black.opacity(0.22)`), Punktwolke (`Farbe.mist`, `opacity .55`, Radius 2,6 skaliert), Ist-Linie gestrichelt (`Farbe.text3`, `StrokeStyle(lineWidth:1.5, dash:[5,5])`), Soll-Linie (`Farbe.waermepumpe` 3 pt, bei Entwurf `Farbe.amber`), zwei Grenzlinien (`dash:[2,4]`) mit Schild 54 × 20 (Radius 6, `Farbe.flaeche3`, 2 pt `Farbe.amber`) und Text „max 45°"/„min 20°" in `Schrift.achse`.
   Die vier Griffe als **eigene `View`s über dem `Canvas`** in einem `ZStack` (nicht gezeichnet), damit sie Treffflächen und `accessibilityValue` haben: Kreis d = 22 pt für Steilheit bei −10 °C, Quadrat 20 pt für Verschiebung bei 18 °C, zwei Schilder am rechten Rand. Treffflächen mindestens **44 pt** (`Speichersteuerkarte.swift:34-36`), auch wenn das Zeichen kleiner ist — die Vorlage macht es mit den unsichtbaren Fangflächen `r=22` und 44 × 44 genauso (`Heizkurve.tsx:149, 157`).
   `DragGesture(minimumDistance: 0)` je Griff, `onChanged` → `vorlaufAm(y)` → `Reglerpult.steilheitDurch`/`verschiebungDurch`/direkt → `raster` → Entwurf. Gesperrt: keine Geste, `Farbe.linie2`/`Farbe.flaeche2`, `opacity .45`.
   Darunter die Legende (`Heizkurve.tsx:163-166`) und die Mono-Zeile „bei −10 °C … · bei 0 °C … · bei 10 °C …" in `Schrift.zahlKlein`, am Telefon unter die Legende statt rechts (`handy.css:240`).
   Fehlt eine der fünf Größen: `Leer(satz: "Für die Kurve fehlt eine der fünf Einstellungen: …")` — Wortlaut aus `Heizkurve.tsx:42`.
5. **`Kanalzug.swift`** — ein Zug, Breite 96 pt (am Telefon 88 pt), Aufbau wie `Fader.tsx:37-95`:
   Wertfeld (volle Breite, Radius 8, Grund `Color(red:0.024,green:0.082,blue:0.110)` = `#06151c`, `Schrift.zahl`, `Farbe.waermepumpe`, bei Entwurf `Farbe.amber` mit `shadow`), Bahn **56 × 190 pt** als `ZStack` (fünf Skalenstriche, Rille 8 pt mit Füllung von unten, Ist-Strich 2 pt in `Farbe.text2`, Knopf 44 × 26 pt mit Mittelkerbe), `DragGesture(minimumDistance: 6)` senkrecht (die 6 pt sind die Schwelle der Vorlage, `Fader.tsx:64`), darunter zwei Tasten „−"/„+" je 34 × 30 pt, der Name in 12,5 pt mittig mit `minHeight 34`, zuletzt der Fuß mit `minHeight 30` in `Schrift.winzig`.
   `accessibilityElement`, `accessibilityValue(Reglerpult.zahlText(...))`, `accessibilityAdjustableAction` für ein Schritt auf/ab — das ist das Gegenstück zu `role=slider` + Pfeiltasten (`Fader.tsx:42-52, 70-76`).
6. **`Pultkarte.swift`** — Karte „Pult": `ScrollView(.horizontal)` über die Gruppenkästen (Radius 14, 1 pt `Farbe.linie1`, Grund `Color.black.opacity(0.18)`), je Kasten ein `Kicker(wort: gruppe)` und eine `HStack` der Kanalzüge mit `gap 10`. Am Telefon `.scrollTargetBehavior(.viewAligned)` als Gegenstück zu `scroll-snap-align:start` (`handy.css:238`) und randlos über `.padding(.horizontal, -16)` innerhalb der Karte (`handy.css:237`). Kartengrund als Verlauf `Farbe.flaeche2 → Farbe.deep` (`globals.css:973`).
7. **`Schalterkarte.swift`** — Karte „Schalter": am iPad zwei Spalten (`LazyVGrid`, zwei flexible Spalten, `spacing 14`), am Telefon eine (`handy.css:236`). Je Einstellung ein Kasten (Radius 12, 1 pt `Farbe.linie1`, Grund `Color.black.opacity(0.14)`, bei Entwurf Rand bernstein): Name „Gruppe: Name" in `Schrift.klein`, bei `muster` dahinter „· Stellbefehl nach Muster gebildet" in `Schrift.winzig`/`text3`; dann die Stufen als Knopfreihe nach dem Vorbild `Speichersteuerkarte.swift:148-170` — Höhe 44 pt, Radius 10, gewählt = `Farbe.waermepumpe` mit `Farbe.petrol`-Schrift (bei Entwurf `Farbe.amber`), die am Regler stehende Stufe bekommt zusätzlich **einen 3 pt dicken Strich unten** in `Farbe.text2` (`globals.css:1011-1014`); Zahl in `Schrift.zahlKlein`, Wort in `Schrift.klein`. Darunter `hinweisDe`, dann der Fuß. Unter dem Feld der Satz aus `Regler.tsx:197`.
8. **`Vergleichsknopf.swift`** — der gestrichelte Knopf: `Text("Am Gerät steht \(Reglerpult.wertText(w))")` in `Schrift.winzig`, Polster 5/8, `RoundedRectangle(cornerRadius: 8).strokeBorder(Farbe.amber.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))`, Grund `Farbe.amber.opacity(0.09)` (`globals.css:1000`). Daneben in derselben Datei `Fusszeile(w:)` mit der Fallunterscheidung aus `Regler.tsx:103-115`: gesendet → „gesendet <Wert>, wartet auf den Regler" in `Farbe.achtung`; „nicht verglichen" → der Knopf; anderer Grund → das Wort in `Farbe.text3`; kein Grund → „gelesen HH:MM".
9. **`Uebernahmeleiste.swift`** — die beiden Stufen aus `Regler.tsx:287-310`, als `.safeAreaInset(edge: .bottom)` an der Seite, damit sie über der Bereichsleiste sitzt (die Vorlage rechnet dort `86px + safe-area`, `handy.css:243`; in SwiftUI übernimmt das `safeAreaInset` von selbst, weil `Seitenwahl` über `Bereichsleiste` liegt — `apps/ios/DuckCurveHome/App/HandRahmen.swift:52-57`). Kasten: Radius 16, 1 pt `Farbe.amber.opacity(0.55)`, Grund `Farbe.deep` mit einem Hauch Bernstein, Schatten. Knöpfe: „Verwerfen"/„Zurück" leise (Kapsel, Rand `Farbe.linie2`, `Farbe.text2`), „Übernehmen …"/„Jetzt stellen" bernstein gefüllt mit `Farbe.petrol`-Schrift, 600 (`globals.css:936-939`). Beim Senden „Wird gesendet …" und `disabled`.

### C. `ReglerSeite.swift` umbauen
10. Zustand: `entwurf: [String: Double]`, `uebersicht: Bool`, `laeuft: Bool`, `meldungen: [(ok: Bool, text: String)]`, `stunden: [(aussenC: Double, sollC: Double)]`. Die Felder `nachfrage` und `laeuft: String?` fallen weg — die Nachfrage wird die Übersicht in der Leiste. **`Einstellungszeile` wird nicht mehr gebraucht** und entfällt mit `ReglerSeite.swift:277-387`.
11. Laden: `.task` mit Schleife, `try? await Task.sleep(for: .seconds(Reglerpult.takt(wartet:)))` nach dem Vorbild `Speichersteuerkarte.swift:177-182`; zweites `.task` für `haus.api.betrieb(tage: 14)` → `stunden` (die Punkte sind Beiwerk, `Regler.tsx:51`).
12. Reihenfolge der Seite, genau wie die Vorlage:
    Kopf (Satz in `Schrift.satz`, darunter `Reglerpult.verglichenSatz` in `Schrift.klein`/`text3`) → Hinderniskarte (`wp-stumm`-Fassung, nur wenn gesperrt) → Anleitungsabsatz (nur solange nicht alles verglichen) → Meldungen mit ✓/✗ und „Ausblenden" → `Heizkurvenbild` → `Pultkarte` → `Schalterkarte` → `DisclosureGroup` „Nur zum Lesen (n)" mit `Tabelle` → `DisclosureGroup` „Was zuletzt gestellt wurde (n)" → `DisclosureGroup` „Vermerke zurücknehmen" → `Methode(hinweiseDe + hindernisDe + stellenJeTag + eBUS-Satz)` → `safeAreaInset`: `Uebernahmeleiste`.
13. `darfStellen` ersetzen durch `Reglerpult.bedienbar(w, stellenMoeglich: e.stellenMoeglich == true) && haus.darfSchalten` — `darfSchalten` bleibt zusätzlich, das ist die Gästesperre der App (`ReglerSeite.swift:194`) und hat in der Vorlage kein Gegenstück.
14. `uebernehmen()` nach `Regler.tsx:82-101`: `for a in offen` **nacheinander** `await haus.api.stelleRegler(a.w.schluessel, wert: a.neu)`, je Antwort eine Meldung, `einstellungen` aus der letzten Antwort, `entwurf = [:]`, `uebersicht = false`.
15. `vergleichen(_:bestaetigt:)` nach `Regler.tsx:72-80` — und **beim Zurücknehmen den Entwurf dieses Schlüssels löschen** (`Regler.tsx:76`).
16. Die Karte „Was der Regler tat" (`ReglerSeite.swift:64-66, 116-154`) auf die Seite `/waerme/waermepumpe` verschieben, wo die Vorlage sie hat (`Waermepumpe.tsx:104`) — oder sie bewusst stehen lassen und das im Doc-Kommentar begründen. Nicht einfach übersehen.
17. Fuß: die zwei Verweise aus `Regler.tsx:279-282` als Zeile in `Farbe.amber` mit `wegweiser.gehe(...)`.

### D. Prüfen
18. Vorschau-Daten anlegen. Gesucht nach `Regler` in `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Vorschau/Vorschau.swift`: ein Treffer, und der ist ein Satz über den Fahrplanregler (`Vorschau.swift:122`) — **ein `ReglerEinstellungenOut` für die Vorschau gibt es nicht**. Also eines bauen, mit je einem Fall „nicht gelesen" (`quality = .stale`), „nicht verglichen" (`bestaetigt = false`), „gesendet" (`gesendet != nil`), den fünf Kurvengrößen und einer `wahl`-Einstellung mit drei Stufen — sonst sind die vier Zustände der Fußzeile nie zu sehen.
19. Die Sperre gegenprüfen: eine nicht verglichene Einstellung darf keine Bahn, keinen Griff, keinen Stufenknopf und keine −/+-Taste bedienbar haben, und in der Übersicht der Leiste nicht auftauchen.

---

## WAS SCHWIERIG WIRD

1. **Ein senkrechter Schieber gibt es in SwiftUI nicht.** `Slider` ist waagerecht und sieht aus wie iOS, nicht wie ein Pult. Also selbst bauen: `ZStack` mit Rille, Füllung, Ist-Strich und Knopf, Wert aus der Zieh-Y-Lage über die Bahnhöhe. Vorbild für die Rückrechnung: `Jahresflaeche.swift:125-140` („dieselbe Rechnung wie beim Zeichnen"). **Falle:** `DragGesture` in einer `ScrollView` streiten sich um den Finger — das Pult rollt waagerecht, die Bahn zieht senkrecht. Die Vorlage löst das mit `touch-action: pan-x` (`globals.css:982`) und einer 6-px-Schwelle (`Fader.tsx:64`); in SwiftUI gehört dazu `DragGesture(minimumDistance: 6)` auf der Bahn und das Vorbild aus `apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift:108-112`, wo genau dieser Streit beschrieben und entschieden ist.
2. **Die vier Ziehgriffe im Diagramm.** `Swift Charts` kennt keine Griffe. Darum `Canvas` für das Bild und echte `View`s für die Griffe in einem `ZStack` darüber — nur so haben sie Treffflächen von 44 pt und eine Stimme für VoiceOver. Die Lagen müssen aus derselben `px`/`py`-Rechnung kommen wie das Gezeichnete, sonst wandert der Griff von der Kurve weg. Vorbild: `Jahresflaeche.swift:76-90` (Canvas + Overlay in einem `GeometryReader`), `Tageskurve.swift:382-401` (Punkt → Datenwert).
3. **Die Beschriftung über der Kurve.** `paint-order: stroke` mit 4 px Kontur (`globals.css:965`) hat in SwiftUI kein Gegenstück. Ersatz: `Text` mit `.shadow(color: Farbe.flaeche1, radius: 2)` mehrfach, oder — sauberer — ein gefülltes `Capsule` in `Farbe.flaeche1.opacity(0.85)` hinter dem Text. Vorbild: das Blättchen der `Jahresflaeche` (`Jahresflaeche.swift:84-86`).
4. **`data-ist` als 3 pt dicker Unterstrich am Stufenknopf** (`globals.css:1011-1012`) lässt sich nicht als `strokeBorder` bauen — der ist überall gleich dick. Ersatz: `.overlay(alignment: .bottom) { Rectangle().fill(Farbe.text2).frame(height: 3) }` innerhalb des `clipShape`. Vorbild für den Aufbau: `Speichersteuerkarte.swift:160-164`.
5. **Die klebende Leiste.** `position: sticky` gibt es nicht. `.safeAreaInset(edge: .bottom)` an der `Seite` ist das Gegenstück und rechnet den Platz über der Bereichsleiste selbst aus. In der App kommt `safeAreaInset` bisher nicht vor (gesucht nach `safeAreaInset` in `apps/ios/`: kein Treffer) — das ist die erste Stelle. Das Vorbild für „etwas schwebt über der Seite" ist `.overlay(alignment: .bottomTrailing) { Entenknopf() }` in `apps/ios/DuckCurveHome/App/HandRahmen.swift:56`, aber ein Overlay verdeckt den unteren Rand des Inhalts; `safeAreaInset` nicht, und das ist hier richtig, weil der letzte Kanalzug sonst unter der Leiste liegt.
6. **Zwei Fassungen desselben Pults.** `Karte` schaltet schon über `horizontalSizeClass` (`Karte.swift:22-24`), `Speichersteuerkarte.swift:74-92` zeigt das Muster für „am iPad nebeneinander, am Telefon untereinander". Beim Pult ist der Unterschied kleiner als es aussieht: **der Aufbau bleibt gleich**, nur Kanalbreite (96 → 88), Zuglücke (22 → 14), Schriftgrößen im Diagramm und das Schnappen ändern sich (`handy.css:237-242`). Wer hier eine eigene Handy-Ansicht erfindet, weicht von der Vorlage ab.
7. **Das Entwurfsmodell ändert das Gefühl der Seite.** Heute fragt die App je Griff nach und sendet sofort; die Vorlage sammelt und sendet in einem Rutsch nach einer Übersicht. Beides ist vorsichtig, aber nur eines passt zum Diagramm: wer die Kurve zieht, bewegt Steilheit und Verschiebung in einer Bewegung, und drei Alerts hintereinander wären unbenutzbar. Also der Vorlage folgen — und dabei die bisherige Vorsicht aus `ReglerSeite.swift:9-18` **nicht** verlieren: der alte Wert bleibt stehen, bis der Regler zurückmeldet, nichts wird stillschweigend gestellt, und was der Dienst nicht als stellbar meldet, wird nur gezeigt. Diese drei Sätze gehören in den Doc-Kommentar der umgebauten Seite, zusammen mit dem vierten, der neu dazukommt: **ohne Gerätevergleich bewegt sich nichts.**
