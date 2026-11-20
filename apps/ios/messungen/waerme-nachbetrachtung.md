========================= messen:waerme-nachbetrachtung   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

Datei: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:145-305`
(`struct NachbetrachtungSeite`), eingehängt in `apps/ios/DuckCurveHome/App/Seitenwahl.swift:76-77`.

1. `Seite { … }` (`:154`) – Rollbereich mit 16 Punkt Rand (`App/Seitenwahl.swift:148-180`).
   Kein Seiten-Kicker, kein Kartentitel über allem.
2. **Tagwahl** (`:155`, gebaut `:213-230`): `HStack` mit „‹“ (28×28, `Schrift.karte`),
   `Text(Tag.kurz(tag))` in `Schrift.zahlKlein` mit `minWidth: 92`, „›“ (abgeschaltet ab
   `tag >= haus.heute`), `Spacer`. Hintergrund `Farbe.flaeche2`, Radius `Marken.radius3` (6).
   Kein Datumsfeld, kein langer Tagesname, kein Verweis in die Wiedergabe.
3. **Ladekarte** (`:156-163`): nur solange `rueckblick == nil`. `Leer(satz: "Wird gerechnet …",
   dazu: "Der Vergleichslauf rechnet den ganzen Tag nach und braucht Sekunden.")`
   (`Gestalt/Karte.swift:390-404`).
4. **Störung** (`:164-166`): `Stoerung(fehler:)` mit Knopf „Erneut“
   (`Gestalt/Karte.swift:410-435`).
5. **Kachelfeld mit sechs Kennzahlen** (`:168`, gerechnet `:232-254`), Kicker `Tag.lang(r.day)`:
   „Strom der Wärmepumpe“ = `Formate.zahl(r.wpKw, stellen: 1)` mit Einheit „kWh“;
   „durch Verschieben gespart“ = `Formate.euro(r.verschiebenEur)`, Farbe `Farbe.mist` bei ≥ 0,
   `Farbe.alarm` darunter; „Standby“ = `r.standbyKwh` (2 Stellen) mit `dazu` = Euro;
   „Einspeisevergütung“ = `r.verguetungCt` (2 Stellen) „ct/kWh“; „verglichene Schritte“ =
   `r.nVerglichen` mit `dazu` „je N Minuten“; „Ofen beteiligt“ = „ja“/„nein“.
6. **Karte „Der Tag in einem Satz“** (`:169-176`): `r.satzDe` in `Schrift.klein` (13 pt),
   `Farbe.text1`.
7. **Karte „Versprochen, gehalten, wirklich“** (`:177-191`), je Abstand eine Zeile
   (`:256-292`): Name (`Schrift.klein`), rechts `Formate.euro(a.eur)` in `Schrift.zahl`, gefärbt
   `Farbe.achtung` bei > 0,005 €, `Farbe.mist` bei < −0,005 €, sonst `Farbe.text2`; darunter
   `"\(a.von) → \(a.nach)"` in `Schrift.winzig` – das sind die **Schlüssel** der Linien
   („versprochen“, „erster“, …), nicht ihre Namen; darunter die Teile „Menge/Zeitpunkt/Ofen“,
   nur wo ≠ 0; darunter `a.satzDe`. Trennlinien `Farbe.linie1`.
8. **Methode** (`:195-206`, Baustein `Seiten/Bericht.swift:334-401`): `r.methodeDe`, dann
   `r.verschiebenDe`, dann „Der Tag läuft noch – die Zahlen sind vorläufig.“, dann „Der erste
   Plan des Tages entstand HH:MM.“, dann **alle** `r.hinweiseDe` – zugeklappt, ohne `kurz`,
   Titel also der Vorgabewert „Wie das gerechnet ist“ (`Bericht.swift:347`).
9. Laden (`:209-210`, `:294-305`): `.task(id: tag)`, Vorgabe `Tag.plus(haus.heute, -1)`;
   `haus.api.nachbetrachtung(tag:)` (`DuckCurveKit/Netz/Api.swift:173-175`). Bei Erfolg wird
   `rueckblick` ersetzt, bei Fehler auf `nil` gesetzt. **Es gibt keinen Abgleich zwischen
   `r.day` und `tag`**: während ein neuer Tag lädt, stehen die Zahlen des alten unter der neuen
   Tagwahl (der Kicker des Kachelfelds nennt noch den alten Tag).

Es gibt kein Diagramm auf dieser Seite. Gesucht nach „Treppe“, „Kostentreppe“,
„Tagesvergleich“, „Nachbetrachtungsbild“ in `apps/ios/DuckCurveHome` und
`apps/ios/DuckCurveKit/Sources`: kein Treffer (nur `Haus/Hausmodell.swift:309,558`, die
Treppe im Hausmodell, und `Zustand/Wirkungsbild.swift:580`, „Anläufe als Treppe“ als Bild im
Satz).

VORLAGE:

Einstieg `apps/web/src/app/waerme/nachbetrachtung/page.tsx:1-17`: `AreaShell` mit
`kicker="Versprochen, gehalten, wirklich · ein Tag in Euro"`, Titel der Seite
„Nachbetrachtung · Duck Curve Home“, `dynamic = "force-dynamic"`, der Inhalt in einer
`Suspense`-Grenze, weil der Tag aus der Adresse kommt (`:11-12`). Der Kicker landet in der
Reiterzeile (`components/layout/AreaNav.tsx:96`): Klasse `kicker`, `fontSize: 11`,
`hidden … md:block` – also **nur ab 768 px**, am Handy nicht. `kicker` =
`var(--font-mono)`, 13 px (hier 11), `letter-spacing: .13em`, `text-transform: uppercase`,
Farbe `--text-kicker` = `--mist` #7FA3B3 (`styles/globals.css:57-64`, `styles/tokens.css:35`).
Der ganze Inhalt steht in `flex flex-col gap-4` (`components/waerme/Nachbetrachtung.tsx:90`),
Karten: `--surface-2` #123544, 1 px `--line-1`, Radius `--radius-2` = 3 px, Polster 20 px
(`globals.css:67-77`); am Handy ohne Rand, Radius 16, Polster 16 (`handy.css:182`).

  * **Karte 1 · „Was hat der Tag gekostet?“**  (`Nachbetrachtung.tsx:91-148`)
    Kartenkopf (`components/ui/Card.tsx:20-28`): links `h2.kicker` mit dem Titel wörtlich
    „Was hat der Tag gekostet?“, rechts in `mono text-[12px] text-text-3`
    (`Nachbetrachtung.tsx:96-99`): „{n_verglichen} von {zeiten.length} Viertelstunden
    verglichen“, und wenn `erster_plan_erstellt` da ist, angehängt
    „ · erster Fahrplan vom {kurzDatum} {hhmm}“ – `kurzDatum` ist „Sa., 07.11.“
    (`components/waerme/wirkung.ts:110-112`, `:96` Formatierer
    `{weekday:"short", day:"2-digit", month:"2-digit"}`, Zeitzone des Hauses). Am Handy bricht
    diese Zeile auf eine eigene Zeile um, 13 px, nicht abgeschnitten (`handy.css:183-185`), und
    die Überschrift wird lesbare Schrift in 16,5 px halbfett statt Sperrschrift
    (`handy.css:184`).

    Bedienzeile (`:103-115`), `mb-4 flex flex-wrap items-center gap-2`:
    – „‹“ und „›“ als `wg-knopf`: 30×30, Schrift 16, `--text-2`, 1 px `--line-1`, Radius 6,
      `:disabled` in `--line-2` (`globals.css:618-619`); „›“ ist aus, wenn `tag >= heute`.
    – ein **`<input type="date">`** als `wg-datum mono`: 13 px, `--text-1`, 1 px `--line-1`,
      Radius 6, Polster 5/8, `color-scheme: dark`, `max={heute}` (`globals.css:620`,
      `Nachbetrachtung.tsx:107`). Damit ist jeder Tag in einem Griff erreichbar.
    – `langerTag(tag)` in 13 px `--text-2` („Samstag, 7. November 2026“, `lib/day.ts:49-52`).
    – rechts außen (`ml-auto`) der Verweis „diesen Tag in der Wiedergabe ansehen“ auf
      `/waerme/wiedergabe?day={tag}`, 12 px `--text-3`, gepunktet unterstrichen
      (`Nachbetrachtung.tsx:112-114`).
    Fehler: ein Absatz 13 px in `--alert` #E0533D mit der Meldung selbst, Vorgabetext
    „Die Nachbetrachtung ist gerade nicht zu erreichen.“ (`:71`, `:117`).
    Lädt: ein Absatz 13 px `--text-3`, wörtlich „Der Tag wird bewertet. Der Vergleichslauf mit
    perfekter Voraussicht braucht einige Sekunden.“ (`:118`) – und zwar nur, solange noch keine
    Daten da sind.
    **Zustand „anderer Tag“**: `daten = d && d.day === tag ? d : null` (`:79-81`), mit
    Begründung im Kommentar: „Solange ein anderer Tag geladen wird, steht der alte nicht mehr
    da: seine Zahlen unter dem neuen Datum wären falsch, auch für zwei Sekunden.“

    Darunter `nb-kopf` (`:121`): zwei Spalten
    `minmax(0,1fr) minmax(340px,1.15fr)`, Lücken 22/44, oben ausgerichtet; unter 1000 px eine
    Spalte (`globals.css:685-686`).
    – Links: `p.wk-urteil` mit `satz_de` – `clamp(17px, 2vw, 22px)`, Schriftgewicht 300,
      Zeilenhöhe 1.38, `letter-spacing: -.01em`, `max-width: 60ch`, `--text-1`
      (`globals.css:650`).
    – Darunter `ul.nb-saetze` (`:124-133`): je Abstand mit `eur != null && satz_de` ein
      Eintrag; `span.kicker` mit `name_de` als eigene Zeile (10,5 px, `margin-bottom: 2px`),
      dann der Satz. Liste 13 px, Zeilenhöhe 1.5, `--text-2`, `max-width: 62ch`, Abstand 12,
      `margin-top: 18px` (`globals.css:687-688`).
    – Darunter, nur wenn `verschieben_de` da ist, `p.nb-verweis` (`:135-143`): `span.kicker`
      „Ohne Preisblick“, der Satz, dann der Verweis „Zur Rechnung ›“ in `--amber` auf
      `/geld?period=day&anchor={tag}`. Der Absatz hat eine Oberlinie `1px --line-1`,
      `padding-top: 12px`, `margin-top: 14px` (`globals.css:689`). Kommentar `:134`: „Der
      Vergleich ohne Preisblick: gerechnet auf der Kostenseite, hier nur genannt.“
    – Rechts: `<Kostentreppe d={daten} />`.
    DATEN: `api.nachbetrachtung(tag)` → `GET /plan/nachbetrachtung?day=<tag>`
    (`lib/api/client.ts:109-110`), Typ `NachbetrachtungOut` (`lib/api/types.ts:5581-5650`).
    Benutzt hier: `satz_de`, `abstaende[].{key,name_de,eur,satz_de}`, `verschieben_de`,
    `n_verglichen`, `zeiten.length`, `erster_plan_erstellt`, `day`.

  * **Die Kostentreppe**  (`components/waerme/Kostentreppe.tsx:67-102`, Rechnung
    `components/waerme/nachbetrachtung.ts:37-81`)
    Begründung im Kopf der Datei (`Kostentreppe.tsx:8-23`), und sie gehört in den Umbau:
    „Eine Treppe und keine fünf Balken nebeneinander, weil die Frage nicht ‚wie hoch ist jede
    Linie‘ heißt, sondern ‚wie kam es vom einen zum anderen‘.“ – „**Die Farbe gehört der Sache,
    nicht der Richtung.** Der Fahrplan ist kühl, die Wirklichkeit warm, die beiden
    Vergleichsrechnungen hell … Ob eine Stufe teurer oder günstiger macht, steht an ihrem
    Vorzeichen und an der Pfeilspitze ihres Balkens; eine zweite Farbbedeutung im selben Bild
    müsste man erst lernen.“ – „**Geschätztes ist umrandet, nicht gefüllt.**“
    Aufbau der Zeilen (`nachbetrachtung.ts:37-65`): Kette `["prognosefehler","nachfuehren",
    "eingriff"]` (`:27`). Begonnen wird bei der Linie, auf die der erste vorhandene Abstand
    zeigt (`a.von`); fehlt das Versprechen, beginnt die Treppe beim gehaltenen Fahrplan; fehlt
    jeder Fahrplan, steht nur „wirklich“ da. Kommentar `:29-36`: „Eine fehlende Stufe wird
    nicht als Null gezeichnet: eine Stufe ohne Höhe hieße ‚kein Fehler‘, und das ist etwas
    anderes als ‚unbekannt‘.“ Arten: `summe` (steht auf dem Boden, `von = 0`), `stufe`
    (schwebt von Stand zu Stand), `bezug` (`perfekt`, steht daneben, trägt `satz_de` des
    Abstands „voraussicht“).
    Achse (`nachbetrachtung.ts:71-81`): Minimum min(0, alle Werte), Maximum mindestens 0,50 €,
    Schrittweite die erste aus `[0.1,0.2,0.25,0.5,1,2,2.5,5,10,20,25,50]`, mit der höchstens
    fünf Felder entstehen, Marken auf ganze Schritte gerundet.
    Zeile (`Kostentreppe.tsx:32-65`): Raster `minmax(120px,190px) minmax(0,1fr) 84px`, Lücke
    12, 12,5 px (`globals.css:691`). Name in `--text-2`, bei einer Summe `--text-1`
    (`:692-693`); „· geschätzt“ als `nb-klein` 11 px `--text-3` (`:694`); bei der Stufe
    „eingriff“ zusätzlich `span.nb-zusatz` (11 px, eigene Zeile, `--text-3`, `:695`) mit
    „Menge ±x,xx € · Zeitpunkt ±x,xx €“ und, bei Ofen, „ · Ofen ±x,xx €“
    (`Kostentreppe.tsx:72-75`).
    Spur `nb-spur`: 22 px hoch, links eine 1-px-Kante in `--line-2` (`:696`). Balken absolut
    gesetzt, 16 px hoch, Radius `0 4px 4px 0`; eine Stufe ist 10 px hoch, Radius 2
    (`:697-698`). Breite `max(x%, 2px)` – „Eine Stufe von null Cent bleibt als Strich sichtbar:
    sie ist eine Aussage.“ (`Kostentreppe.tsx:52`). Geschätzt: durchsichtig mit 1,5 px
    gestrichelter Kante in der Farbe (`:54-55`). Pfeilspitze nur bei `|eur| >= 0,005`
    (`:48-49`): 7 px Dreieck in `currentColor`, rechts bei teurer, links bei günstiger
    (`globals.css:700-702`). Faden zur nächsten Zeile: 1 px gestrichelt `--line-2`, Höhe
    `100% + 6px`, an der Stelle, wo diese Zeile endet (`:703`, `Kostentreppe.tsx:60`).
    Wert rechts: 13 px `--text-1`, bei einer Stufe `--text-2` (`:704-705`), Summe als
    `euro(…)` = „3,42 €“, Stufe als `euroMitVorzeichen(…)` = „+0,31 €“, „−0,80 €“, oder
    „±0,00 €“ unter einem halben Cent; das Minus ist U+2212
    (`nachbetrachtung.ts:83-95`).
    Farben (`Kostentreppe.tsx:25-30`): `wirklich` = `C.heatPump` #E0966B; `art === "bezug"`
    (perfekt) = `C.house` #CFD8DC; `art === "stufe"` = `rgba(255,255,255,.62)`; sonst
    `C.mist` #7FA3B3 (`components/charts/palette.ts:43,53,61`).
    Vor den Bezugszeilen eine Trennzeile `nb-trenner` mit dem Wort „zum Vergleich gerechnet“:
    Oberlinie `--line-1`, mono 10 px, `letter-spacing: .08em`, Großbuchstaben, `--text-3`
    (`Kostentreppe.tsx:84`, `globals.css:706`).
    Letzte Zeile die Achse: Marken absolut, 10 px `--text-3`, mittig verschoben, die erste
    linksbündig, die letzte rechtsbündig (`globals.css:707-711`); die mittleren tragen
    `wk-fein` und **verschwinden unter 560 px** (`globals.css:676`), Begründung im Kommentar
    `Kostentreppe.tsx:92`: „Auf dem Telefon bleiben nur Anfang und Ende: sechs Beträge auf
    hundert Punkten lägen aufeinander.“ Beschriftung „x,xx €“ in deutscher Schreibweise, höchstens
    2 Nachkommastellen.
    Am Handy schrumpft die Zeile auf `minmax(84px,112px) minmax(0,1fr) 70px`, Lücke 8,
    11,5 px, der Wert 12 px (`globals.css:723`).
    `role="group"`, `aria-label="Kostentreppe vom Versprechen des Fahrplans zur Wirklichkeit"`
    (`Kostentreppe.tsx:80`); jede Zeile trägt `title={s.satz}`.
    DATEN: `linien[].{key,name_de,eur,geschaetzt}`, `abstaende[].{key,name_de,von,nach,eur,
    satz_de,menge_eur,zeit_eur,ofen_eur}`, `hat_ofen`.

  * **Karte 2 · „Der Tag, Linie für Linie“**  (`Nachbetrachtung.tsx:150-177`), nur bei
    `n_verglichen > 0`.
    Kartenkopf rechts wörtlich: „oben die Umstände, in der Mitte wann jede Linie Strom zieht,
    unten was dabei auflief“ (`:152`).
    Darin `<Tagesvergleich d={daten} />` (`components/waerme/Tagesvergleich.tsx:67-308`),
    ein ECharts-Bild aus mehreren Gittern auf einer Zeitachse
    (`components/charts/EChart.tsx`). Begründung im Kopf (`Tagesvergleich.tsx:13-32`):
    „Oben die Umstände … In der Mitte je Linie ein Streifen: hell, wo sie Strom zieht, heller,
    je mehr. Die Streifen stehen untereinander, damit der Blick senkrecht vergleichen kann -
    geplant war der Mittag, gelaufen ist der Morgen, und das sieht man, bevor man eine Zahl
    liest. Unten die aufgelaufenen Kosten … Wo zwei Kurven sich trennen, ist die Viertelstunde,
    in der es teuer wurde, und der Streifen darüber sagt, warum.“ – „Jede Größe in ihrer eigenen
    Fläche. Cent, Kilowatt und Euro in einem Gitter läsen sich als Zusammenhang ihrer
    Kreuzungspunkte.“ – und die Farbmessung: „Gemessen am 10.11.2026 gegen die Kartenfläche
    #123544, alle Paare: schlechtestes Paar ΔE 15,8 normal und 10,3 protan. Ein Grün für die
    perfekte Voraussicht fiel durch - gegen das Orange der Wirklichkeit ΔE 0,8 bei Deuteranopie
    … Deshalb drei Farben für vier Linien: der erste Fahrplan gestrichelt, der letzte Stand
    durchgezogen, und jede Kurve hat ihren Namen am Ende.“
    Maße (`:35-37`, `:72-94`): Ränder breit `{links:136, rechts:128}`, am Telefon
    `{links:84, rechts:12}`; Streifenhöhe 13; Deckungen `[0.28,0.5,0.75,1]`.
    Flächen von oben nach unten, mit ihrem Titel links in mono 10 px `C.text`
    (`rgba(255,255,255,.48)`, `:213-219`):
      1. „Preis in ct/kWh“, Höhe 56, dann 34 Punkte Luft: Stufenkurve (`step: "end"`) in
         `C.price` #7FA3B3, Breite 1,6, Fläche mit Deckung 0,14 (`:267-278`).
      2. „Überschuss in kW“, Höhe 40 – **nur**, wenn irgendein `ueberschuss_kw > 0,05`
         (`:77,82-85`): Linie `C.pv` #F2A900, Breite 1,6, Fläche 0,18 (`:279-295`).
      3. je verfügbare Linie ein Streifen, Reihenfolge `["erster","letzter","wirklich",
         "perfekt"]` (`nachbetrachtung.ts:112-118`; das Versprechen fehlt bewusst: „es ist
         derselbe Fahrplan wie ‚erster‘“), Titel = Langname, am Telefon der Kurzname
         (`:39-46`): „erster Fahrplan“/„erster Plan“, „letzter Stand“, „wirklich“,
         „perfekte Voraussicht“/„perfekt“; Abstand 7 zwischen den Streifen.
         Füllung je Viertelstunde in vier Helligkeiten von `C.heatPump`
         (`staerke`, `nachbetrachtung.ts:105-109`: 0 für ≤ 2 % der Nennarbeit, sonst 1-4 im
         Verhältnis zur Viertelstunde bei Nennleistung; „Vier Stufen und kein stufenloser
         Verlauf … `null` bleibt `null` - keine Aussage ist kein Stillstand“). Stufe 0 bekommt
         `rgba(255,255,255,.07)`: „Stufe null ist eine Aussage: die Linie sagt ‚aus‘.“
         (`Tagesvergleich.tsx:155-157`). Der Ofen als schmaler Rand unter dem Streifen, nur bei
         `hat_ofen`, in `C.stove` #B5651D, von y 0 bis 0,28, wo `ofen_je > 0,5` (`:160-185`).
      4. 30 Punkte Luft, dann „aufgelaufene Kosten in €“, Höhe 170: je Linie `eur_kumuliert`
         als Kurve, `connectNulls: false`, Achsenbeschriftung „{value} €“, zwei Teilungen,
         Rasterlinien `C.gridline` (`:128-133`, `:190-208`, `:265`).
         Strichart je Linie (`:49-54`): `wirklich` #E0966B durchgezogen 2,5; `letzter`
         #7FA3B3 durchgezogen 2; `erster` #7FA3B3 **gestrichelt** 1,6; sonst (`perfekt`)
         #CFD8DC durchgezogen 1,6. `wirklich` liegt mit `z: 5` über den anderen.
         Am Ende jeder Kurve ihr Name in `rgba(255,255,255,.72)`, 11 px, Abstand 6, mit
         `moveOverlap: "shiftY"` – **nicht am Telefon** (`:205`, Begründung `:68-69`: „Auf dem
         Telefon ist rechts kein Platz für die Namen an den Kurven: von 310 Punkten blieben der
         Zeichnung 80. Dort trägt die Legende unter dem Bild, die ohnehin immer dasteht.“)
    Schleier über allem, was nicht verglichen wird (`:101-116`): `rgba(8,36,49,.62)` über den
    Läufen mit `verglichen == false`, in **jeder** Fläche derselbe, und nur in der Preisfläche
    mit dem Wort „nicht verglichen“ oben links in mono 10 px.
    Zeitachse: `type: "time"`, `min = von`, `max = bis`, Beschriftung „HH:MM“ nur unter der
    letzten Fläche, `hideOverlap`, Achsenlinie `C.axis` (`:117-127`, `:264`).
    Hinweisfenster (`:221-260`): Kopf „HH:MM bis HH:MM“, darunter „x,x ct/kWh“ bzw. „Preis
    unbekannt“ und „ · Überschuss x,x kW“; bei nicht verglichener Viertelstunde der Satz
    „Diese Viertelstunde wird nicht verglichen.“; dann eine Tabelle, je Linie ihre Strichmarke,
    ihr Name, „x,xx kWh“, der Euro-Betrag der Viertelstunde und „bis hier x,xx €“. Rahmen
    `rgba(242,169,0,.4)`, Grund `C.deep` #082431, Text #F1F5F5 12 px.
    `animation: false`, Achsenzeiger über alle Gitter verbunden (`:220`), `grid` mit
    `outerBoundsMode: "none"` – Begründung `:261-262`: „sonst rückt ECharts 6 ein Gitter ein,
    sobald eine Beschriftung übersteht, und die Flächen stünden nicht mehr untereinander.“
    DATEN: `zeiten`, `schritt_min`, `von`, `bis`, `verglichen`, `preis_ct`, `ueberschuss_kw`,
    `wp_kw`, `hat_ofen`, und je Linie `wp_kwh_je`, `ofen_je`, `eur_je`, `eur_kumuliert`,
    `verfuegbar`, `name_de`.

    Darunter die **Legende** `ul.uhr-legende wk-legende` (`Nachbetrachtung.tsx:154-175`):
    `display: flex`, Umbruch, Lücken 4/22, 11,5 px, Zeilenhöhe 1.4, `--text-3`, oben 12 px
    Abstand (`globals.css:642-643`, `:658`). Je Linie eine Marke `span.nb-marke`: 18 px breit,
    0 hoch, `transform: translateY(-3px)`, als `border-top` mit Breite
    `max(2, round(width))`, Art und Farbe der Linie (`Nachbetrachtung.tsx:38-41`,
    `globals.css:712`), dahinter der Kurzname (`KURZ`), sonst `name_de`.
    Dann ein Eintrag mit vier Kästchen `span.nb-stufen` (je 9×10, Lücke 1,
    `translateY(1px)`, `globals.css:713-714`) in `C.heatPump` mit den Deckungen
    `[0.28,0.5,0.75,1]` und dem Text „Strom der Wärmepumpe je Viertelstunde, bis {wp_kw/4}
    kWh“ (zwei Nachkommastellen, `Nachbetrachtung.tsx:162-168`).
    Bei `hat_ofen` zuletzt „Ofen brennt“ mit `span.uhr-marke wk-marke-strich`: 10 px breit,
    3 px hoch, kein Radius, `translateY(-3px)`, Grund `C.stove`
    (`globals.css:644`, `:660`, `Nachbetrachtung.tsx:169-174`).

  * **Karte 3 · „Die Linien in Zahlen“**  (`Nachbetrachtung.tsx:179-233`), nur bei
    `n_verglichen > 0`. Kartenkopf rechts: „über die {n_verglichen} verglichenen
    Viertelstunden“ (`:181`).
    Tabelle `nb-tabelle` in `nb-tabelle-rahmen` (`overflow-x: auto`): 13 px,
    `border-collapse: collapse`, Zellen rechtsbündig, `padding: 7px 14px 7px 0`,
    Unterlinie `--line-1`, Schriftgewicht 400; die erste Spalte linksbündig in `--text-1` und
    umbrechend; Kopfzeile mono 10 px, `letter-spacing: .08em`, Großbuchstaben, `--text-3`;
    Zellen mono mit `tabular-nums` in `--text-2` (`globals.css:715-720`).
    Spalten wörtlich (`:184-195`): „Linie“, „Kosten“, bei Ofen „davon Ofen“, „Strom“,
    „im Mittel“ (mit `title`: „Was die Kilowattstunde Strom dieser Linie im Mittel gekostet
    hat. Hängt nicht an der Menge.“), „Wärmepumpe“, bei Ofen „Ofen“.
    Zeilen nur für `verfuegbar` (`:198-213`): `name_de`, dahinter „· geschätzt“ als
    `nb-klein`, wenn `geschaetzt`; `euro(eur)`; `euro(ofen_eur)`; „x,x kWh“; „x,x ct/kWh“;
    „x,x h“ Wärmepumpe; „x,x h“ Ofen – fehlende Werte als „-“ (`:34-36` `de()`).
    Fußnote (`:217-221`), nur wenn `standby_eur` und `standby_kwh` da sind **und**
    `standby_kwh >= 0,05`: `p.nb-fuss` (12,5 px `--text-3`, oben 12 px, `globals.css:721`),
    wörtlich „Daneben, in keiner Linie: die Grundlast der Anlage im Stillstand, {x,x} kWh für
    {x,xx €}.“
    Fehlende Linien (`:222-231`): `ul.nb-fehlend` (12,5 px, Zeilenhöhe 1.5, `--text-3`,
    `max-width: 78ch`, Abstand 10, oben 14, `globals.css:722`), je Eintrag `span.kicker`
    „{name_de} fehlt“ als eigene Zeile und dahinter `grund_de`.
    DATEN: `linien[].{name_de,verfuegbar,geschaetzt,grund_de,eur,ofen_eur,wp_kwh,ct_je_kwh,
    wp_h,ofen_h}`, `standby_kwh`, `standby_eur`, `hat_ofen`, `n_verglichen`.

  * **Karte 4 · „Zu diesem Tag“**  (`Nachbetrachtung.tsx:236-245`), nur wenn Hinweise übrig
    sind. Die Hinweise sind `hinweise_de` **ohne** die, die mit `Die Linie „` beginnen
    (`:86-87`): „Die Gründe fehlender Linien stehen schon in der Tabelle; hier nicht noch
    einmal.“ Liste `ul.wk-hinweise`: Aufzählungspunkte, `padding-left: 18px`, Abstand 8,
    `max-width: 78ch`, 13 px, Zeilenhöhe 1.5, `--text-2` (`globals.css:675`).
    Kommentar `:235`, und der ist der Grund, warum diese Karte nicht in die Methode darf:
    „Was für diesen Tag gilt, bleibt offen stehen; zugeklappt wäre es verschwiegen.“ Dieselbe
    Regel steht in `components/ui/Methode.tsx:11-13` („Nicht hinein gehört, was eine Zahl *an
    diesem Tag* einschränkt - eine fehlende Linie, eine Lücke, ein laufender Tag“) und wurde in
    der App für die Wirkungsseite schon einmal umgesetzt
    (`FahrplanSeiten.swift:366-367`: „**Offen, nicht zugeklappt** (`Wirkung.tsx:240`): was eine
    Zahl an diesem Zeitraum einschränkt, darf nicht hinter einem Deckel liegen.“).
    Inhalt kommt fertig vom Dienst
    (`packages/hems-core/src/hems_core/accounting/nachbetrachtung.py:663-702`): der laufende
    Tag, die Zahl der verglichenen Viertelstunden samt Grund, der Hinweis auf die
    unterschiedlichen Strommengen, und je fehlende Linie ein Satz.

  * **Karte 5 · Methode**  (`Nachbetrachtung.tsx:247-255`, `components/ui/Methode.tsx:18-29`)
    Ein `<details>`, zugeklappt; Titel der Vorgabewert „Wie gerechnet wird“; `kurz` wörtlich
    „jede Linie mit derselben Rechnung über dieselben Viertelstunden · Überschuss zur
    Vergütung, der Rest zum Bezugspreis“ (`:248`). Inhalt: `methode_de` als Liste
    (fünf Sätze, `nachbetrachtung.py:645-660`).
    Maße: Zusammenfassung `display: flex`, Lücke 14, Polster 14/18, der Pfeil 7×7 aus zwei
    1,5-px-Kanten in `--text-3`, gedreht; `methode-kurz` 12,5 px `--text-3`; Inhalt
    `padding: 0 18px 18px`, Abstand 10 (`globals.css:726-733`). Am Handy Polster 15/16, der
    Titel lesbare Schrift 15 px halbfett, `kurz` 13 px, Inhalt 14,5 px (`handy.css:212-217`).

  * **(Handy-Fassung, wo sie abweicht)**  `apps/web/src/styles/handy.css`, Grenze
    `max-width: 720px` (`:107`), mit der Begründung im Kopf der Datei (`:1-26`): „Bis zum
    10.11.2026 war die Handy-Ansicht die Rechner-Ansicht in einer Spalte … Das ergab bis zu
    viereinhalb Bildschirme gleich schwerer Kästen mit 10-Punkt-Sperrschrift“. Vier
    Entscheidungen: Bereiche unten; **eine Zahl führt**; Flächen statt Rahmen; **Tabellen
    werden Listen**.
    Für diese Route gilt:
    – Seitenrand `10px 16px` unten `86px + safe-area`, Grundschrift 15 px, Kartenabstand 14
      (`:110-111`).
    – Karten ohne Rand, Radius 16, Polster 16 (`:182`); Kartenkopf bricht um, Überschrift
      16,5 px halbfett ohne Sperrschrift, der rechte Teil auf eigener Zeile 13 px,
      vollständig (`:183-185`).
    – kleine Schriften eine Stufe größer: 10→11, 11→12, 12→13,5, 13→14,5 (`:187-192`). Das
      trifft die Kopfzeile der Karte 1 (12 px → 13,5) und beide Kartenköpfe rechts.
    – **Die Tabelle „Die Linien in Zahlen“ wird eine Liste** (`:301-337`), Begründung dort:
      „Eine Tabelle mit fünf Spalten hat am Handy 60 Punkte je Spalte. Hier wird aus jeder
      Zeile ein kleiner Block: oben, was die Zeile ist, und die Zahl, um die es geht; darunter
      der Rest.“ Konkret (`:331-337`): `.nb-tabelle` und `tbody` werden `block`, `thead`
      verschwindet, `.nb-tabelle-rahmen` bekommt `overflow: visible`; jede Zeile ist ein
      `flex` mit Umbruch, Lücken 3/14, Polster 12 oben/unten, Oberlinie `--line-1` (die erste
      ohne, `padding-top: 2px`); der Zeilenname nimmt `1 1 calc(100% - 96px)`, 15 px,
      Gewicht 400, umbrechend, `--text-1`; alle Zellen 13 px `--text-3` ohne Umbruch; die
      **zweite** Zelle (Kosten) rückt mit `margin-left: auto` nach rechts und steht in 17 px
      `--text-1`.
    – Die mittleren Achsenmarken der Treppe fallen weg (`.wk-fein`, `globals.css:676`), die
      Treppenzeile wird schmaler (`globals.css:723`), `nb-kopf` ist schon ab 1000 px einspaltig
      (`globals.css:686`).
    – Der Seiten-Kicker ist am Handy nicht zu sehen (`AreaNav.tsx:96`, `hidden … md:block`).
    – `.nur-breit { display: none }` (`:384`) – von dieser Route nicht benutzt; gesucht nach
      `nur-breit` in `Nachbetrachtung.tsx`, `Kostentreppe.tsx`, `Tagesvergleich.tsx`: kein
      Treffer.
    – Gesucht nach `nb-kopf`, `nb-treppe`, `nb-saetze`, `nb-verweis`, `nb-fuss`, `nb-fehlend`,
      `uhr-legende`, `wg-knopf`, `wg-datum`, `wk-urteil` in `handy.css`: kein Treffer. Die
      einzigen `nb-`Regeln dort sind die der Tabelle (`:305-306`, `:332-337`). Alles andere
      erbt aus `globals.css`.

LUECKEN:

  [traegt-die-seite] Die **Kostentreppe** fehlt vollständig. Sie ist die Hauptaussage der
  Seite – der Weg vom Versprechen über Prognosefehler, Nachführen und Eingriff zur
  Wirklichkeit, mit dem Vergleichslauf daneben (`Kostentreppe.tsx:67-102`,
  `nachbetrachtung.ts:37-81`). Die App zeigt stattdessen eine flache Liste von Abständen ohne
  gemeinsame Achse, ohne Stände, ohne Faden, ohne Pfeilrichtung
  (`FahrplanSeiten.swift:177-191`, `:256-292`).

  [traegt-die-seite] Der **Tagesvergleich** fehlt vollständig (`Tagesvergleich.tsx:67-308`):
  Preis, Überschuss, je Linie ein Helligkeitsstreifen, die aufgelaufenen Kosten als vier
  Kurven, der Schleier über dem nicht Verglichenen und die Legende darunter
  (`Nachbetrachtung.tsx:150-177`). Ohne ihn ist in der App nicht zu sehen, **wann** eine Linie
  Strom zog und **wo** das Geld auseinanderlief – die zweite der drei Aussagen der Seite.
  In der App gibt es dafür keine einzige Zeile: `r.zeiten`, `r.verglichen`, `r.preisCt`,
  `r.ueberschussKw` und alle `je`-Reihen der Linien werden nicht angefasst
  (gesucht nach `wpKwhJe`, `eurKumuliert`, `verglichen` in `apps/ios/DuckCurveHome`: kein
  Treffer).

  [traegt-die-seite] Die Karte **„Die Linien in Zahlen“** fehlt (`Nachbetrachtung.tsx:179-233`)
  – damit fehlen alle fünf Linien mit Kosten, Ofenanteil, Strom, mittlerem Preis in ct/kWh und
  Laufzeiten, die Kennzeichnung „· geschätzt“, die Standby-Fußnote und die Liste der fehlenden
  Linien mit ihrem Grund. Die App zeigt von `r.linien` nichts; gesucht nach `r.linien` in
  `FahrplanSeiten.swift`: kein Treffer.

  [traegt-die-seite] Die Karte **„Zu diesem Tag“** fehlt; `hinweise_de` liegt in der App im
  zugeklappten Methodenblock (`FahrplanSeiten.swift:205`). Das ist genau der Fall, den die
  Vorlage ausdrücklich ausnimmt (`Nachbetrachtung.tsx:235`, `ui/Methode.tsx:11-13`) und den die
  App auf der Nachbarseite schon richtig löst (`FahrplanSeiten.swift:366-372`). Dazu fehlt der
  Filter, der die Sätze „Die Linie „…“ fehlt“ auslässt (`Nachbetrachtung.tsx:87`).

  [spuerbar] Die **Kopfkarte** gibt es nicht. Es fehlen: der Titel „Was hat der Tag
  gekostet?“, die Kopfzahl rechts „N von M Viertelstunden verglichen · erster Fahrplan vom …“
  (`Nachbetrachtung.tsx:92-102`) und das zweispaltige `nb-kopf` mit Satz links und Treppe
  rechts (`globals.css:685`). Der Urteilssatz steht in der App in einer eigenen Karte mit dem
  erfundenen Kicker „Der Tag in einem Satz“ und in `Schrift.klein` (13 pt) statt in
  `clamp(17px,2vw,22px)` mit Gewicht 300 (`FahrplanSeiten.swift:169-176` gegen
  `globals.css:650`) – ein Urteil in der Größe einer Fußnote.

  [spuerbar] Die **Abstandssätze** stehen falsch. Die Vorlage nimmt nur Abstände mit
  `eur != null && satz_de`, setzt `name_de` als Kicker darüber und den Satz darunter, im
  Kopfbereich (`Nachbetrachtung.tsx:84`, `:124-133`). Die App baut daraus eine eigene Karte mit
  Betrag, Teilen und Satz – und zeigt dabei `"\(a.von) → \(a.nach)"`, also die rohen
  Linien-Schlüssel „versprochen“, „erster“, „letzter“, „wirklich“, „perfekt“
  (`FahrplanSeiten.swift:270-272`); die Vorlage zeigt diese Schlüssel nirgends.
  Außerdem färbt die App den Betrag nach der **Richtung** (`:265-267`: Achtung/Mist), während
  die Vorlage die Farbe der Sache gibt und die Richtung an Vorzeichen und Pfeilspitze hängt
  (`Kostentreppe.tsx:16-19`).

  [spuerbar] Das **Kachelfeld mit sechs Kennzahlen** (`FahrplanSeiten.swift:168`, `:232-254`)
  hat in der Vorlage kein Gegenstück: gesucht nach `kpi`, `Stat`, `kpi-grid` in
  `Nachbetrachtung.tsx`: kein Treffer. Von den sechs Zahlen stehen in der Vorlage nur drei,
  und an anderer Stelle: `n_verglichen` im Kartenkopf, `standby_*` als Fußnote unter der
  Tabelle (und nur ab 0,05 kWh, `:217`), `verschieben_de` als Verweiszeile (`:135-143`).
  `verguetung_ct` und `hat_ofen` zeigt die Vorlage nicht als Zahl.
  Dazu ein Fehler in der Sache: „Strom der Wärmepumpe“ setzt `r.wpKw` mit der Einheit „kWh“
  (`:234-236`); `wp_kw` ist die **Nennleistung in kW** (`types.ts:5636`), die Vorlage benutzt
  sie nur als `wp_kw / 4`, die Arbeit einer Viertelstunde bei Nennleistung, und schreibt sie in
  die Legende (`Nachbetrachtung.tsx:167`, `Tagesvergleich.tsx:138`).

  [spuerbar] Die Zeile **„Ohne Preisblick“** fehlt: Kicker, `verschieben_de` und der Verweis
  „Zur Rechnung ›“ in `--amber` auf `/geld?period=day&anchor={tag}` mit Oberlinie darüber
  (`Nachbetrachtung.tsx:135-143`, `globals.css:689`). In der App ist `verschiebenDe` ein Satz
  unter dem Deckel der Methode (`FahrplanSeiten.swift:198`).

  [spuerbar] Die **Tagwahl** ist ärmer als die Vorlage: kein Datumsfeld mit `max=heute` (jeder
  Tag in einem Griff), kein `Tag.lang(tag)` daneben, kein Verweis „diesen Tag in der
  Wiedergabe ansehen“ (`Nachbetrachtung.tsx:103-115`). Die App zeigt nur ‹ `Tag.kurz` ›
  (`FahrplanSeiten.swift:213-230`); der lange Tag steht stattdessen als Kicker über dem
  Kachelfeld (`:168`). Die App hat dafür ein Vorbild im Haus:
  `Seiten/Technik/WiedergabeSeite.swift:124-139` baut genau diese Zeile mit `DatePicker`,
  `in: ...obergrenze`, Blätterknöpfen und `Tag.lang`.

  [spuerbar] Der **Methodenblock** weicht ab: kein `kurz` („jede Linie mit derselben Rechnung
  über dieselben Viertelstunden · Überschuss zur Vergütung, der Rest zum Bezugspreis“,
  `Nachbetrachtung.tsx:248`), Titel „Wie das gerechnet ist“ statt „Wie gerechnet wird“
  (`Bericht.swift:347` gegen `ui/Methode.tsx:18`), und drei Sätze darin, die in der Vorlage
  woanders stehen: `verschieben_de`, der laufende Tag (dort in `hinweise_de`,
  `nachbetrachtung.py:666-670`) und `erster_plan_erstellt` (dort im Kartenkopf).

  [spuerbar] Der **Tagesabgleich beim Laden** fehlt. Die Vorlage verwirft Daten, deren `day`
  nicht der Tagwahl entspricht, mit Begründung (`Nachbetrachtung.tsx:79-81`: „seine Zahlen
  unter dem neuen Datum wären falsch, auch für zwei Sekunden“). Die App lässt `rueckblick`
  stehen, bis der neue Tag da ist (`FahrplanSeiten.swift:294-305`), und die Rechnung dauert
  laut eigenem Ladetext Sekunden.

  [klein] Der **Seiten-Kicker** „Versprochen, gehalten, wirklich · ein Tag in Euro“
  (`page.tsx:10`) steht in der App nirgends. Gesucht nach dem Satz und nach den Kickern der
  Nachbarseiten („Preis · PV · Wärmebedarf …“, „Außengerät · Innengerät · Speicher“) in
  `apps/ios`: kein Treffer – die App führt für keine Seite einen Kicker. In der Vorlage ist er
  am Handy ohnehin verborgen (`AreaNav.tsx:96`), gilt also nur für das iPad.

  [klein] **Vorzeichen und Minuszeichen.** Die Vorlage schreibt Änderungen immer mit
  Vorzeichen, Null als „±0,00 €“, und das Minus als U+2212
  (`nachbetrachtung.ts:83-95`). `Formate.euro` kennt kein Vorzeichen
  (`DuckCurveKit/Formate/Formate.swift:116-120`); `Formate.minus` (U+2212) ist vorhanden
  (`:25`), wird hier aber nicht benutzt.

  [klein] **Texte wörtlich.** Lädt: „Der Tag wird bewertet. Der Vergleichslauf mit perfekter
  Voraussicht braucht einige Sekunden.“ (`Nachbetrachtung.tsx:118`) gegen „Wird gerechnet …“ /
  „Der Vergleichslauf rechnet den ganzen Tag nach und braucht Sekunden.“
  (`FahrplanSeiten.swift:159-160`). Fehler: ein Absatz 13 px in `--alert` mit dem Satz „Die
  Nachbetrachtung ist gerade nicht zu erreichen.“ (`:71`, `:117`) gegen `Stoerung` mit
  Warnzeichen, Fehlercode und Knopf „Erneut“ (`:164-166`). Kartenköpfe wörtlich: „Der Tag,
  Linie für Linie“ mit „oben die Umstände, in der Mitte wann jede Linie Strom zieht, unten was
  dabei auflief“ und „Die Linien in Zahlen“ mit „über die N verglichenen Viertelstunden“.

  [klein] **„· geschätzt“** als Kennzeichnung einer geschätzten Linie fehlt an beiden Stellen
  (Treppe `Kostentreppe.tsx:43`, Tabelle `Nachbetrachtung.tsx:204`), und mit ihr die Regel
  „Geschätztes ist umrandet, nicht gefüllt“ (`Kostentreppe.tsx:22`). `Linie.geschaetzt` ist im
  Modell da (`Schema.swift:6436`) und wird in der App nicht gelesen.

KERN: SCHON DA (nachgesehen, nicht geraten):

  * Abfrage: `Api.nachbetrachtung(tag:)` → `GET /plan/nachbetrachtung?day=<tag>`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:173-175`). Dieselbe Adresse wie
    die Vorlage (`apps/web/src/lib/api/client.ts:110`).
  * Modell `NachbetrachtungOut` vollständig, mit allen Reihen
    (`Modelle/Schema.swift:6760-6809`): `zeiten`, `schrittMin`, `verglichen`, `nVerglichen`,
    `preisCt`, `ueberschussKw`, `linien`, `abstaende`, `standbyKwh`, `standbyEur`,
    `ersterPlanErstellt`, `satzDe`, `hinweiseDe`, `methodeDe`, `day`, `von`, `bis`,
    `laeuftNoch`, `wpKw`, `verguetungCt`, `hatOfen`, `verschiebenEur`, `verschiebenDe`.
  * `Linie` mit `key`, `nameDe`, `verfuegbar`, `grundDe`, `geschaetzt`, `eur`, `stromEur`,
    `ofenEur`, `wpKwh`, `ctJeKwh`, `wpH`, `ofenH`, `wpKwhJe`, `ofenJe`, `eurJe`, `eurKumuliert`
    (`Schema.swift:6431-6466`).
  * `Abstand` mit `key`, `nameDe`, `von`, `nach`, `eur`, `satzDe`, `mengeEur`, `zeitEur`,
    `ofenEur` (`Schema.swift:874-895`).
  * Läufe gleicher Werte: `Wiedergabebild.Lauf` und `Wiedergabebild.laeufe(_:zeiten:schritt:)`
    (`Zustand/Wiedergabebild.swift:24-69`) – die Portierung von `tagesuhr.ts:63-80`, die
    `Tagesvergleich.tsx:102,151,172` braucht, mit derselben Lückenregel.
  * Stufenbildung allgemein: `Wiedergabebild.stufen` und die Einordnung in n Stufen
    (`Zustand/Wiedergabebild.swift:73-80 ff.`) – für `staerke` nicht passend (dort fünf Stufen
    der Uhr, hier vier gegen die Nennarbeit), aber dasselbe Muster.
  * Flächen einer mehrteiligen Zeichnung als Daten: `Wiedergabebild.Bandflaeche` und
    `bandflaechen` (`Zustand/Wiedergabebild.swift:117-132`, `:222-234`).
  * Farben, alle vier, die die Vorlage hier benutzt:
    `Marken.waermepumpe` #E0966B (`Gestalt/Marken.swift:58`) = `C.heatPump`;
    `Marken.mist` #7FA3B3 (`:20`) = `C.mist` = `C.price`;
    `Marken.haus` #CFD8DC (`:76`) = `C.house`;
    `Marken.ofen` #B5651D (`:70`) = `C.stove`;
    dazu `Marken.pv` (`:50`), `Marken.alarm` #E0533D (`:99`) = `--alert`,
    `Marken.rasterlinie` (`:34`) = `C.gridline`, `Marken.linie1`/`linie2` (`:32-33`),
    `Marken.text1/2/3` (`:43-45`), `Marken.deep` (`:17`) = `C.deep`,
    `Marken.radius3` = 6 (`Gestalt/Marken.swift:313`). Als SwiftUI-Farben in
    `apps/ios/DuckCurveHome/Gestalt/Farben.swift:29-73`.
  * Formate: `Formate.euro(_:stellen:)` (`Formate/Formate.swift:116-120`),
    `Formate.ct` (`:110-113`), `Formate.kwh` (`:75`), `Formate.zahl(_:stellen:)` (`:44`),
    `Formate.hhmm(iso:)` (`:148`), `Formate.minus` U+2212 (`:25`), `Formate.leer` (`:27`).
  * Tage: `Tag.lang` (`Formate/Tag.swift:87-92`), `Tag.kurz` (`:94-99`), `Tag.plus` (`:50`),
    `Tag.istTag` (`:26`), `Tag.date` (`:57`), `Tag.zeitraum` (`:79`),
    `Zeit.ausIso(_:)` (`Formate/Zeit.swift:28`).
  * Oberfläche: `Seite` (`App/Seitenwahl.swift:148-180`), `Karte` mit Kicker/Titel/Beiwerk
    (`Gestalt/Karte.swift:15-113`), `Kachelfeld`/`Kacheldaten`/`Kachel`
    (`Gestalt/Karte.swift:121-343`), `Leer` (`:390-404`), `Stoerung` (`:410-435`),
    `Tabelle` mit Spaltenumschaltung am Telefon (`Seiten/Bericht.swift:157-325`),
    `Methode(_:kurz:titel:)` (`Seiten/Bericht.swift:334-401`),
    `Kicker`/`Zahl` (`Gestalt/Typografie.swift:109-150`),
    `Umbruchzeile` und `Legendenstueck` für die Legende (`Gestalt/Umbruchzeile.swift:1-30`),
    `Schrift` mit `klein` 13, `winzig` 11,5, `karte` 15, `zahl` 15, `zahlKlein` 12,5,
    `achse` 10,5, `custom(_:)`, `sans(_:)`, `mono(_:)`
    (`Gestalt/Typografie.swift:38-101`).
  * Wegweiser für die beiden Verweise: `Wegweiser.gehe(_:)`
    (`apps/ios/DuckCurveHome/App/Navigation.swift:40-42`); `/waerme/wiedergabe?day=…` wird
    gelesen (`Zustand/Jahreskarte.swift:493-509`, `App/Seitenwahl.swift:60-65`), `/geld` ist
    eine Seite (`App/Seitenwahl.swift:51`) mit Zeitraum am Bereich
    (`App/Navigation.swift:79-85`).
  * Zeichenmuster für mehrere Flächen auf einer Zeitachse, mit geteilter Auswahl, Streifen aus
    `RectangleMark`, Rasterlinien und Legende: `Diagramme/Fahrplanzeichnung.swift:120-180`
    (`flaeche(_:hoehe:spanne:leer:mitZeitachse:inhalt:)`), `:352-366` (`streifen(_:)`),
    `:424-437` (Legende); dasselbe in `Diagramme/Tagesbandbild.swift:27-65`.

ES FEHLT:

  1. Die Treppe als Rechnung. Neu `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/
     Nachbetrachtungsbild.swift` mit `public struct Nachbetrachtungsbild` und darin
     `public struct Stufe: Sendable, Identifiable { key, name, art: Art (summe/stufe/bezug),
     von, bis, eur, geschaetzt, satz }`, `public static func treppe(_ d: NachbetrachtungOut)
     -> [Stufe]` und `public static func achse(_ stufen: [Stufe]) -> (min: Double, max: Double,
     marken: [Double])` – Portierung von `apps/web/src/components/waerme/nachbetrachtung.ts:
     14-81`, samt Regel „eine fehlende Stufe wird nicht als Null gezeichnet“. Prüfbar unter
     Linux, also mit Tests in `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests`, Vorbild
     `apps/web/src/components/waerme/nachbetrachtung.test.ts`.
  2. `Formate.euroMitVorzeichen(_:)` in `DuckCurveKit/Sources/DuckCurveKit/Formate/
     Formate.swift` (neben `euro`, `:116`): „+0,31 €“, „−0,80 €“ mit U+2212, „±0,00 €“ unter
     einem halben Cent – `nachbetrachtung.ts:89-95`.
  3. Die Teile des Tagesvergleichs, die Rechnung sind, in dieselbe Datei
     `Nachbetrachtungsbild.swift`:
     – `public static func staerke(kwh: Double?, vollKwh: Double) -> Int?` (vier Stufen,
       `null` bleibt `nil`) – `nachbetrachtung.ts:105-109`;
     – `public static let zeilen: [String] = ["erster","letzter","wirklich","perfekt"]` und
       `public static func zeilen(_ d: NachbetrachtungOut) -> [Linie]` (nur `verfuegbar`) –
       `nachbetrachtung.ts:112-118`;
     – die Kurznamen lang und knapp (`KURZ`/`KNAPP`, `Tagesvergleich.tsx:39-46`) als
       `Nachbetrachtungsworte`, nach dem Muster von `Zustand/Fahrplanworte.swift`;
     – `public struct Strichart { farbe: Farbwert, gestrichelt: Bool, breite: Double }` mit
       `strichart(key:)` – `Tagesvergleich.tsx:49-54` (Farben als `Farbwert` aus `Marken`,
       damit der Kern unter Linux bleibt);
     – die Flächen als Daten (`Flaeche { art, titel, hoehe }`, Preis 56 / Sonne 40 /
       Streifen 13 / Kosten 170, Abstände 34 und 7) und das Ja/Nein für die Sonnenfläche
       (`ueberschuss_kw > 0,05`) – `Tagesvergleich.tsx:72-94`;
     – die Läufe des Schleiers: `verglichen == false` über `Wiedergabebild.laeufe`
       (vorhanden, `Zustand/Wiedergabebild.swift:45`).
  4. Die Zeilen der Tabelle „Die Linien in Zahlen“ als Daten (Spaltenköpfe wörtlich, Zellen
     schon formatiert, `geschaetzt`-Vermerk, Standby-Satz ab 0,05 kWh, Liste der fehlenden
     Linien) – als `public static func zahlentabelle(_ d: NachbetrachtungOut)` in
     `Nachbetrachtungsbild.swift`, damit die Rundungen („x,x kWh“, „x,x ct/kWh“, „x,x h“) unter
     Linux geprüft werden können: `Nachbetrachtung.tsx:184-221`.
  5. Die Auswahl der Sätze für den Kopf (`eur != null && satz_de`,
     `Nachbetrachtung.tsx:84`) und der Hinweise für „Zu diesem Tag“ (ohne die, die mit
     `Die Linie „` beginnen, `:87`) – zwei kleine Funktionen in derselben Datei.

BAUPLAN: Welche Dateien anzulegen oder zu ändern sind, Karte für Karte, in der Reihenfolge der
Vorlage.

  1. **Kern** `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Nachbetrachtungsbild.swift`
     (neu): `Stufe`, `treppe`, `achse`, `staerke`, `zeilen`, `strichart`, `Flaeche`,
     `zahlentabelle`, `kopfsaetze`, `tageshinweise`.
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Nachbetrachtungsworte.swift` (neu):
     Titel, Kartenköpfe, Kurznamen, Lade- und Fehlertext, Legendentexte – alle wörtlich aus der
     Vorlage. Vorbild `Zustand/Fahrplanworte.swift` und `Zustand/Wiedergabeworte.swift`.
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift`: `euroMitVorzeichen`.
     `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests/NachbetrachtungsbildTests.swift` (neu):
     Treppe mit und ohne Versprechen, Achsenschrittweiten, vier Stufen der Helligkeit,
     Vorzeichenformate.
  2. **Seite** `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:145-305` neu
     schreiben (oder nach `Seiten/Technik/NachbetrachtungSeite.swift` ziehen – die Datei trägt
     heute drei Seiten und 476 Zeilen). Reihenfolge wie die Vorlage:
     a) Karte „Was hat der Tag gekostet?“ mit `Karte(kicker:beiwerk:)`; Beiwerk = „N von M
        Viertelstunden verglichen · erster Fahrplan vom …“ in `Schrift.winzig`/`Farbe.text3`
        (am Telefon umbrechend, `handy.css:185`).
        Darin die Bedienzeile als neuer Baustein
        `apps/ios/DuckCurveHome/Bausteine/Tageszeile.swift` – ‹, `DatePicker` wie
        `WiedergabeSeite.swift:124-139`, ›, `Tag.lang`, rechts der Verweis in die Wiedergabe
        über `wegweiser.gehe("/waerme/wiedergabe?day=\(tag)")`.
        Darunter zweispaltig ab regulärer Breite (links Satz und Sätze, rechts die Treppe),
        einspaltig bei `horizontalSizeClass == .compact` (`globals.css:685-686`); der Satz in
        `Schrift.custom(20)` mit Gewicht leicht – die Vorlage hat `clamp(17,2vw,22)` bei
        Gewicht 300; darunter die Kopfsätze (Kicker + Satz) und die Zeile „Ohne Preisblick“ mit
        `wegweiser.gehe("/geld")` und gesetztem Zeitraum (Tag, Anker = `tag`).
     b) `apps/ios/DuckCurveHome/Diagramme/Kostentreppe.swift` (neu): `Canvas` oder
        `GeometryReader` mit `HStack`-Zeilen – kein `Chart`, weil es ein Balken je Zeile mit
        eigener Lage auf einer gemeinsamen Achse ist und die Pfeilspitze und der Faden zur
        nächsten Zeile gezeichnet werden müssen. Raster: Name (120-190), Spur, Wert (84).
        Vorbild für die Spur `Bausteine/Anteilsleiste.swift:34-45`, für die Zeilenform
        `Bausteine/Betragszeile.swift`.
     c) Karte „Der Tag, Linie für Linie“ mit `apps/ios/DuckCurveHome/Diagramme/
        Tagesvergleichsbild.swift` (neu): mehrere `Chart`-Flächen untereinander mit
        **derselben** `chartXScale` und geteilter `chartXSelection`, genau nach dem Muster
        `Diagramme/Fahrplanzeichnung.swift:120-180`; Streifen als `RectangleMark` mit
        Helligkeitsstufen (`:352-366`), der Ofenrand als zweiter `RectangleMark` von 0 bis 0,28,
        die Kostenkurven als `LineMark` je Linie mit `series:` und `StrokeStyle(dash:)` für
        „erster“, die Namen am Ende über `.annotation` (Vorbild
        `Diagramme/Wirkungszeichnung.swift:243-258`), der Schleier als `RectangleMark` über die
        nicht verglichenen Läufe in jeder Fläche.
        Darunter die Legende mit `Umbruchzeile` (`Gestalt/Umbruchzeile.swift`): Strichmarken
        18×2-3 je nach Linie, die vier Helligkeitskästchen 9×10 und, bei Ofen, die 10×3-Marke.
     d) Karte „Die Linien in Zahlen“ mit `Tabelle` (`Seiten/Bericht.swift:157`): Zeilennamen
        = `name_de` (+ „· geschätzt“), Spalten „Kosten“, „davon Ofen“, „Strom“, „im Mittel“,
        „Wärmepumpe“, „Ofen“. Am Telefon greift die Spaltenumschaltung der `Tabelle`; die
        Vorlage macht dort aus jeder Zeile einen Block mit Name und Kosten vorn
        (`handy.css:331-337`) – `immerSichtbar: 1` kommt dem am nächsten, denn „Kosten“ ist die
        Zahl, um die es geht. Darunter die Standby-Fußnote in `Schrift.winzig`/`Farbe.text3`
        und die Liste der fehlenden Linien (Kicker „… fehlt“ + Grund).
     e) Karte „Zu diesem Tag“: `Karte(kicker: "Zu diesem Tag")` mit den gefilterten Hinweisen
        als Punkte in `Schrift.klein`/`Farbe.text2` – Vorbild wörtlich
        `FahrplanSeiten.swift:364-381` (Wirkungsseite).
     f) `Methode(r.methodeDe.map(Optional.init), kurz: "jede Linie mit derselben Rechnung über
        dieselben Viertelstunden · Überschuss zur Vergütung, der Rest zum Bezugspreis",
        titel: "Wie gerechnet wird")` – nur `methode_de`, nichts sonst.
     g) Laden: in `lade()` den Tagesabgleich einbauen (`rueckblick` nur zeigen, wenn
        `r.day == tag`), Ladetext und Fehlertext wörtlich.
     h) Das Kachelfeld (`:168`, `:232-254`) entfällt.
  3. **Vorschau** `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Vorschau`: ein
     `Vorschau.nachbetrachtung()` mit allen fünf Linien, vollen `je`-Reihen und einer Lücke im
     `verglichen`, damit sich Schleier und fehlende Linie in `#Preview` ansehen lassen (Vorbild
     `Vorschau.plan()`, benutzt in `Fahrplanzeichnung.swift:441-449`).

WAS SCHWIERIG WIRD: Wo SwiftUI/Swift Charts kein Gegenstück hat, und welcher Weg im Projekt
dafür schon gewählt wurde (mit Datei:Zeile als Vorbild).

  * **Mehrere Gitter an einer Zeitachse.** ECharts setzt sechs bis acht `grid` in ein Bild
    (`Tagesvergleich.tsx:263`), Swift Charts kennt das nicht. Der im Projekt gewählte Weg:
    mehrere `Chart` untereinander, alle mit derselben `chartXScale(domain:)` und derselben
    `chartXSelection`, die Zeitachse nur unter der letzten –
    `Diagramme/Fahrplanzeichnung.swift:120-180` („Acht Flächen, nicht eine mit acht Achsen“,
    `:13-16`) und `Diagramme/Tagesbandbild.swift:17-22` („Alle Flächen bekommen dieselbe
    `chartXScale` gesetzt, sonst fallen sie auseinander - derselbe Fehler ist im Dashboard
    schon passiert“). Die Flächentitel stehen dort links über der Fläche als `Text`, nicht als
    `graphic` im Diagramm.
  * **Der Name am Ende jeder Kurve** (`endLabel` mit `moveOverlap: "shiftY"`,
    `Tagesvergleich.tsx:205`). Swift Charts hat kein `endLabel`. Der Weg im Projekt ist
    `.annotation` am letzten Punkt – `Diagramme/Wirkungszeichnung.swift:243-258` und
    `Diagramme/Pvtageskurve.swift:179`. Ein Ausweichen auf Überlappung gibt es nicht; die
    Vorlage lässt die Namen am Telefon ohnehin weg und verlässt sich auf die Legende
    (`Tagesvergleich.tsx:68-69`), und diese Legende steht in der App immer da.
  * **Das Hinweisfenster unter dem Zeiger** (`Tagesvergleich.tsx:221-260`). Am Telefon gibt es
    kein Darüberfahren. Der Weg im Projekt: eine **Auskunftszeile über** der Zeichnung, die
    `chartXSelection` füllt – `Diagramme/Fahrplanzeichnung.swift:84-116` („Am Telefon gibt es
    kein Darüberfahren; ohne diese Auskunft stünden … nirgends in der App“) und die „Fahne“ in
    `Diagramme/Tagesbandbild.swift:66-72`. Dieselbe Zeile kann hier Preis, Überschuss, „wird
    nicht verglichen“ und je Linie kWh / € / „bis hier“ tragen.
  * **Der Schleier über nicht verglichenen Zeiträumen** (`markArea` in jeder Fläche,
    `Tagesvergleich.tsx:109-116`). Gesucht nach „Schleier“ in `apps/ios/DuckCurveHome`: kein
    Treffer. Das nächste Vorbild sind die Preisbänder und die Reservezone als `RectangleMark`
    über die ganze Flächenhöhe – `Diagramme/Fahrplanzeichnung.swift:188-196` und `:302-311`.
    Der Text „nicht verglichen“ geht als `.annotation(position: .topLeading)` an den ersten
    Schleierlauf der Preisfläche.
  * **Die Treppe selbst.** Swift Charts hat keinen Wasserfall: `BarMark(xStart:xEnd:)` kann
    schwebende Balken, aber nicht den Faden zur nächsten Zeile, nicht die Pfeilspitze und nicht
    den „2 px Mindeststrich“ für eine Nullstufe (`Kostentreppe.tsx:52`). Darum besser kein
    `Chart`, sondern Zeilen aus `HStack` mit einer `GeometryReader`-Spur, wie
    `Bausteine/Anteilsleiste.swift:34-45` es für die Anteilsleiste tut („Es gab im Projekt
    nichts dafür … Die Vorlage baut die Leiste aus zwei geschachtelten Kästen“), und mit
    derselben Trennung: die Längen rechnet der Kern (`achse`/`treppe`), die Ansicht rechnet nur
    Punkte aus Prozent.
  * **Die Tabelle am Telefon.** Die Vorlage macht aus jeder Zeile einen Block mit Name und
    Kosten oben (`handy.css:331-337`); `Tabelle` schaltet stattdessen eine Spalte um
    (`Seiten/Bericht.swift:151-156`, „Tabellen werden Listen“). Das ist eine bewusste
    Abweichung, die schon für den Fahrplan und die Kostenseite getragen wurde
    (`Seiten/Bericht.swift:176-203`); hier ist nur darauf zu achten, dass „Kosten“ die zuerst
    gezeigte Spalte ist, weil sie in der Vorlage die hervorgehobene Zahl der Zeile ist
    (`handy.css:337`).
  * **Die gepunktete Unterstreichung der Verweise** (`underline decoration-dotted
    underline-offset-4`, `Nachbetrachtung.tsx:112`). SwiftUI kann `.underline(pattern: .dot)`,
    im Projekt wird ein Verweis aber als Text in `Farbe.amber` mit „›“ geführt –
    `Gestalt/Karte.swift:254-257` („Ein Pfeil sagt, dass die Zeile irgendwohin fuehrt“) und
    `Zustand/Gelduebersicht.swift:302`. Diesem Weg folgen.
