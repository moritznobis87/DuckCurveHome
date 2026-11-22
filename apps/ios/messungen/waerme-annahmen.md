========================= messen:waerme-annahmen   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt, mit Datei:Zeile.

`struct AnnahmenSeite: View` steht in
`apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:717-989`. Gewählt wird sie in
`apps/ios/DuckCurveHome/App/Seitenwahl.swift:82-83` (`case "/waerme/annahmen"`), ohne jede
Prüfung der Rolle.
Zustand: `einstellungen: HemsConfig?` (`:720`), `fehler: ApiFehler?` (`:721`),
`entwuerfe: [String: String]` (`:727`, absichtlich Text und nicht `Double?`, Begründung
`:722-726`), `kennlinie: String` (`:728`), `schickt` (`:729`), `uebernommen` (`:730`),
`ansicht = "formular"` (`:731`). Geladen wird in `lade()` (`:948-958`) über
`haus.api.einstellungen()`, angestoßen von `.task` (`:748`).

1. Seitenkicker „Lieferschein · Datenblatt · Puffer" – nicht in der Seite, sondern in der Hülle
   `Seite` (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:206-216`) aus
   `Bereiche.kicker(fuer:)`; der Text steht in
   `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Bereiche/Bereiche.swift:225-226` als
   `Annahmenfelder.kicker`. Am Telefon fällt er weg (`Seitenwahl.swift:207`,
   `breite != .compact`).
2. Bei Fehler ein `Stoerung`-Band mit „Erneut" (`SystemSeiten.swift:735-737`), über allem
   anderen; `Stoerung` selbst in `apps/ios/DuckCurveHome/Gestalt/Karte.swift:419-465`
   (Warnzeichen, `Farbe.achtung`, Grund `Farbe.flaeche2`, Radius `Marken.radius3`).
3. Solange nichts da ist und kein Fehler: `Karte { Leer(satz: "Wird geholt …") }`
   (`:744-746`); `Leer` in `Karte.swift:390-404` (13 Punkte, `text2`, 18 Punkte Polster
   oben und unten).
4. Eine `Karte` mit dem Formular (`:765-776`), Kopfzeile ohne Kicker und ohne Titel, rechts
   der Umschalter `umschalter` (`:904-912`, `Ansichtswahl` mit „Annahmen" / „Alle Werte",
   `apps/ios/DuckCurveHome/Gestalt/Ansichtswahl.swift:17-70`). Inhalt mit
   `VStack(spacing: 18)`:
   a. `Text(Annahmenfelder.einleitung)` in `Schrift.klein` (13 Punkte), `text2`,
      `lineSpacing(3)` (`:767-771`).
   b. `spalten(c)` (`:781-801`): `Annahmenfelder.spalten()` ergibt 7 und 6 Felder,
      `ViewThatFits` nimmt zwei Spalten mit `HStack(spacing: 28)` ab `minWidth: 640`
      (`:784-794`), sonst eine Spalte (`:795-799`); je Spalte `VStack(spacing: 14)`.
   c. `feldzeile` je Feld (`:803-846`): `HStack(spacing: 10)` aus `Text(feld.wort)` in
      `Schrift.klein`/**`text1`** (`:812-815`), `Spacer(minLength: 8)`, `TextField` in
      `Schrift.zahl` (15 Punkte Mono), rechtsbündig, Tastatur `.decimalPad` bzw.
      `.numbersAndPunctuation` bei `darfNegativ` (`:817-833`), Breite **92**,
      Polster 10/7, Grund **`Farbe.flaeche2`**, Rand `geaendert ? Farbe.amber : Farbe.linie2`,
      Radius `Marken.radius3` (= 6), `.disabled(!haus.darfSchalten)`; dann
      `Text(feld.einheit)` in `Schrift.winzig`/`text3` mit Breite **42** (`:834-837`).
      Darunter, über die **ganze Zeilenbreite**, `feld.hinweis` in `Schrift.winzig`/`text3`
      (`:839-844`).
   d. `kennlinienzeile(c)` (`:848-874`): `Kicker(wort: Annahmenfelder.kennlinienTitel)`
      (`:850`, also Sperrschrift 10,5 in `Farbe.kicker`), darunter
      `Annahmenfelder.kennlinienErklaerung` in `Schrift.winzig`/`text3` (`:851-855`), darunter
      ein `TextField` über die volle Breite in `Schrift.zahl`, Polster 12/9, Grund
      `Farbe.flaeche2`, Rand bernstein bei Abweichung, Radius `Marken.radius3` (`:856-872`).
   e. `abgabezeile` (`:876-900`): Knopf mit `Annahmenfelder.knopf` /
      `Annahmenfelder.knopfLaeuft` in `Schrift.klein`, `Farbe.petrol` auf `Farbe.amber`,
      Polster 16/9, **`Capsule()`** (`:881-888`), gesperrt bei `schickt || !darfSchalten`,
      `opacity(darfSchalten ? 1 : 0.4)` (`:890-891`); daneben bei Erfolg
      `Annahmenfelder.uebernommenSatz` in `Schrift.winzig`/`text2` (`:892-897`).
5. `Methode(Annahmenfelder.methodensaetze.map(Optional.init))` (`:777`) – eine zugeklappte
   Karte „Wie das gerechnet ist" (`apps/ios/DuckCurveHome/Seiten/Bericht.swift:514-577`) mit
   den zwei Absätzen aus `Annahmenformular.swift:395-409`. Die Vorlage hat auf dieser Seite
   **keine** Methodenkarte; die Sätze stehen dort im Quelltext (`HeatSettings.tsx:7-20`).
6. Zweite Ansicht `werteliste(c)` (`:914-937`): `Karte(kicker: "Alle Werte")` mit sechs
   Abschnitten (Wärmepumpe, Pufferspeicher, Wärmebedarf, Tarif, Pelletofen, Regelung), je
   `Kicker` + `Werteliste` (`:939-944`, `:992-1012`). Die Zeilen kommen aus `alsZeilen`
   (`:1021-1058`): Schlüssel des Schemas mit ersetzten Unterstrichen, alphabetisch, ohne
   Einheit. Die Vorlage hat diesen Umschalter und diese Liste nicht
   (`apps/web/src/lib/areas.ts:128` nennt für die Route keine `unter`-Ansichten).
7. Nicht vorhanden: der Schlussabsatz der Vorlage mit dem Verweis auf die Wärmebilanz.
   `gesucht nach "schlussabsatz" und "Textstueck" in apps/ios/**/*.swift`: Treffer nur in
   `DuckCurveKit/Sources/.../Annahmenformular.swift:417,433`, in den Tests
   (`AnnahmenformularTests.swift:317,323`, `AlteWegeTests.swift:133,137`) und in einem
   Kommentar (`Bereiche.swift:351`) – **keine Ansicht liest ihn**.

Abgeben: `uebernimm()` (`:960-980`) ruft `Annahmenfelder.abgabe(entwuerfe:kennlinie:)`,
bei `.kennlinieUnlesbar` wird ein `ApiFehler(code: "kennlinie", …)` gesetzt (`:966-967`), sonst
`haus.api.stelleWaerme(patch)`; danach `uebernimmAntwort(c)` (`:984-988`), das Felder und
Kennlinie wieder aus der Antwort des Dienstes schreibt.


VORLAGE:

  * **Hülle und Kicker** (`apps/web/src/app/waerme/annahmen/page.tsx:7-13`)
    `export const dynamic = "force-dynamic"` (`:7`) mit der Begründung im Kommentar (`:6`):
    „Ohne dies rendert Next die Seite beim Build vor, und requireOwner liefe nie zur Laufzeit."
    `metadata.title = "Annahmen der Wärmerechnung · Duck Curve Home"` (`:8`).
    `await requireOwner()` (`:11`) mit dem Kommentar „Wer die Annahmen aendert, aendert jede
    Auswertung rueckwirkend"; `requireOwner` in `apps/web/src/lib/guard.ts:10-15` leitet auf
    `/` um, wenn `session?.role !== "owner"` – serverseitig, „damit sie gar nicht erst
    ausgeliefert werden" (`guard.ts:5-9`).
    `<AreaShell kicker="Lieferschein · Datenblatt · Puffer">` (`:13`);
    `AreaShell` (`apps/web/src/components/layout/AreaShell.tsx:14-32`) ist
    `main.dashboard-bg.report-main` mit `gap-4 p-5 text-text-1`, der Kicker geht an
    `AreaTabs` (`:26`).
    DATEN: keine.

  * **Rahmen des Inhalts** (`page.tsx:14`)
    `<section className="flex max-w-[980px] flex-col gap-3">` – Höchstbreite 980 px, 12 px
    zwischen den drei Blöcken.

  * **Einleitungsabsatz** (`page.tsx:15-20`)
    `text-[15px] leading-[1.6] text-text-2`, `m-0`. Wörtlich: „Es gibt keinen
    Wärmemengenzähler im Haus. Die Wärmebilanz wird deshalb gerechnet, und diese Zahlen sind
    die Annahmen dahinter: was auf dem Lieferschein der Pellets steht, was im Datenblatt des
    Ofens steht, wie warm der Puffer gefahren wird. Jede Änderung wirkt sofort und
    rückwirkend, weil Messwerte gespeichert sind und keine Rechenergebnisse."
    DATEN: keine.

  * **Das Formular `HeatSettings`** (`apps/web/src/components/settings/HeatSettings.tsx:85-203`)
    Kein Kasten, kein Kicker, keine Überschrift: `<div className="flex flex-col gap-3">`
    (`:161`). Also **keine Karte** – die Zeilen stehen direkt auf dem Seitengrund.
    Begründungen im Quelltext, die beim Umbau nicht verloren gehen dürfen (`:7-20`):
    „Warum diese Werte hier stehen und nicht in der Konfigurationsdatei" (vom Gerät und vom
    Lieferschein, der Hausherr muss sie nachtragen können, ohne eine Datei zu bearbeiten;
    Regelparameter bleiben draußen, „eine falsche Zahl dort fällt beim Start auf und nicht
    nachts") und „Jede Änderung wirkt rückwirkend" („eine Annahme, die nur nach vorn wirkt,
    lässt die Vergangenheit falsch stehen, ohne dass es jemandem auffällt").
    DATEN: `api.heatConfig()` → `GET /config` → `HemsConfig`
    (`apps/web/src/lib/api/client.ts:123`), einmal in `useEffect` (`:113-118`);
    `api.setHeatConfig(patch)` → `POST /config/heat` → `HemsConfig` (`client.ts:124-125`).
    Gelesen werden `c.stove.{nominal_heat_kw, water_heat_kw, min_heat_kw, min_water_heat_kw,
    combustion_efficiency, pellet_kwh_per_kg, pellet_price_eur_per_t}`,
    `c.buffer.{volume_liters, target_temperature_c, loss_kw_per_k, ambient_c,
    loss_useful_fraction}`, `c.heat_demand.{indoor_target_c, cop_curve}` (`:96-110`).

  * **Zustand „lädt" und Ladefehler** (`HeatSettings.tsx:158`)
    `if (!cfg) return <p className="m-0 text-[14px] text-text-3">{fehler ?? "lädt …"}</p>` –
    ein Absatz, **keine Karte**, 14 px in `text-3`. Der Ladefehler lautet immer
    „Die Konfiguration konnte nicht geladen werden." (`:117`), nie der Satz des Dienstes.

  * **Die dreizehn Feldzeilen** (`HeatSettings.tsx:21-43`, gezeichnet in `Zeile`, `:64-83`)
    Zwei Spalten: `grid gap-x-8 md:grid-cols-2` (`:162`) – zweispaltig erst ab der
    Tailwind-Stufe `md`, also **768 px**; geteilt bei `HALB = Math.ceil(13/2) = 7`
    (`:47`, mit Begründung `:45-46`: „mit jedem neuen Feld stand sonst eine Spalte laenger da
    als die andere").
    Eine Zeile ist ein `<label>` mit
    `flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 border-b border-line-1 py-2
    last:border-b-0` (`:66`): Haarlinie unter jeder Zeile außer der letzten je Spalte, 8 px
    Polster oben und unten, und sie **bricht um** – passen Feld und Einheit nicht neben das
    Wort, rutschen sie mit 4 px Abstand darunter. Weil es ein `<label>` ist, setzt ein Tippen
    auf das Wort den Fokus ins Feld.
    Links `<span className="flex-1 text-[14px] text-text-2">` mit dem Wort, und **innerhalb
    dieses Spans** der Hinweis als `<span className="block text-[12px] leading-[1.5]
    text-text-3">` (`:67-70`) – der Hinweis steht also unter dem Wort in der linken Spalte,
    nicht unter der ganzen Zeile.
    Rechts `<span className="flex items-baseline gap-2">` (`:71`) mit
    `<input type="number" step={f.step}>` in `mono w-[108px] rounded-[2px] border
    border-line-2 bg-surface-3 px-2 py-1 text-right text-[13px] text-text-1` (`:72-78`) und
    `<span className="mono w-[52px] text-[12px] text-text-3">{f.unit}</span>` (`:79`).
    Farbwerte dazu: `--surface-3: #173f50` (`apps/web/src/styles/tokens.css:25`),
    `--line-2: rgba(255,255,255,0.17)` (`tokens.css:28`),
    `--text-1/2/3: rgba(255,255,255,0.92/0.72/0.48)` (`tokens.css:32-34`),
    `--radius-1: 2px` (`tokens.css:92`). Fokus: `:focus-visible { outline: 0; box-shadow:
    var(--focus-ring) }` (`apps/web/src/styles/globals.css:54`) mit
    `--focus-ring: 0 0 0 6px rgba(242,169,0,0.12)` (`tokens.css:97`).
    Die dreizehn Zeilen wörtlich (`:30-42`), mit Einheit und Schrittweite:
    Ofen: Leistung bei Volllast (kW, 0.1) · Ofen: davon ins Wasser (kW, 0.1; „Der Rest heizt
    den Aufstellraum.") · Ofen: Leistung bei Minimallast (kW, 0.1) · Ofen: davon ins Wasser
    (kW, 0.1) · Verbrennungswirkungsgrad (0 bis 1, 0.001; „Datenblatt, Volllast. Bei Teillast
    ist er meist besser.") · Heizwert der Pellets (kWh/kg, 0.01; „ENplus A1 liegt zwischen 4,9
    und 5,3. Steht auf dem Lieferschein.") · Pelletpreis (€/t, 1) · Puffervolumen (l, 10) ·
    Zieltemperatur des Puffers (°C, 1; „Zugleich der Vorlauf, bei dem die COP-Kennlinie
    gilt.") · Verlustbeiwert des Puffers (kW/K, 0.001; „0,004 kW/K sind 4 Watt je Kelvin
    Übertemperatur.") · Aufstellraum des Puffers (°C, 0.5; „Nicht der Wohnraum: …") · davon
    nutzbar fürs Haus (0 bis 1, 0.05; „Liegt der Raum in der beheizten Hülle, …") ·
    Raumtemperatur des Hauses (°C, 0.5; „Für den Heizbedarf aus Heizgradstunden. Auf den
    Pufferverlust wirkt sie nicht mehr.").
    **Die Felder stehen genau so da, wie der Dienst sie liefert:** `String(c.stove.…)`
    (`:96-108`), also „0.911", nicht gerundet und nicht deutsch geschrieben.

  * **Die Kennlinienzeile** (`HeatSettings.tsx:175-188`)
    Ein `<label className="flex flex-col gap-1.5">`. Überschrift als **normaler Satz**:
    `<span className="text-[14px] text-text-2">COP-Kennlinie über der Außentemperatur</span>`
    (`:176`) – keine Sperrschrift. Darunter 12 px `leading-[1.5] text-text-3` (`:177-182`),
    wörtlich: „Stützpunkte als `Temperatur:COP`, aufsteigend, mit Komma getrennt. Sie gilt bei
    der Zieltemperatur des Puffers; auf den wirklichen Vorlauf wird über das Verhältnis der
    Carnot-Zahlen umgerechnet. Ein zweidimensionales Kennfeld ist das nicht, und es wäre auch
    keines: dafür müsste jede Stützstelle gemessen sein." – „Temperatur:COP" steht darin in
    `<code className="mono">` (`:178`).
    Das Feld: `mono rounded-[2px] border border-line-2 bg-surface-3 px-3 py-2 text-[13px]
    text-text-1` (`:183-187`).
    Geschrieben wird mit `kurveZuText` (`:50-52`, `${t}:${c}` mit „, " verbunden), gelesen mit
    `textZuKurve` (`:54-62`): Trennung an `[,;]`, Komma zu Punkt, jedes Stück muss zwei
    endliche Zahlen sein, sonst `null`.

  * **Knopfzeile** (`HeatSettings.tsx:190-201`)
    `flex flex-wrap items-center gap-4`. Knopf: `rounded-[2px] px-4 py-2 text-[13px]
    font-medium`, `background: var(--amber)`, `color: var(--petrol)`,
    `opacity: laeuft ? 0.6 : 1` (`:191-198`), Beschriftung „Übernehmen" bzw.
    „wird übernommen …". Daneben, **in derselben Zeile**, die Meldung in 13 px `text-2`
    (`:199`) und der Fehler in 13 px `color: var(--alert)` = `#e0533d` (`:200`,
    `tokens.css:64`).
    Erfolgssatz wörtlich (`:144-147`): „Übernommen. Die Auswertungen rechnen ab sofort damit,
    auch rückwirkend; der Fahrplan wird neu gerechnet und steht in wenigen Sekunden auf der
    Seite „Fahrplan"." – Begründung im Kommentar darüber (`:141-143`): der Fahrplan wird im
    Takt gerechnet, „ohne den Hinweis sieht das aus wie Wirkungslosigkeit".
    Kennlinienfehler wörtlich (`:133`): „Die Kennlinie wird als Temperatur:COP geschrieben,
    Stützpunkte mit Komma getrennt." – geprüft **vor** der Anfrage, `setLaeuft(false)` und
    `return` (`:131-136`).
    Dienstfehler: `e instanceof ApiError ? e.message : "Die Änderung wurde nicht übernommen."`
    (`:152`), mit der Begründung im Kommentar (`:149-151`): der Dienst prüft Widersprüche,
    „seine Begründung ist genauer als alles, was die Oberfläche sagen könnte".
    Was abgeht (`:124-137`): jedes Feld, dessen Rohtext nicht leer und als Zahl lesbar ist,
    plus `cop_curve` immer.

  * **Schlussabsatz** (`page.tsx:22-26`)
    `m-0 text-[14px] leading-[1.6] text-text-3`, mit `<Link href="/waerme/bilanz"
    className="text-amber">Wärmebilanz</Link>` **mitten im Satz** (`:23`;
    `--amber: #f2a900`, `tokens.css:13`). Wörtlich: „Ob die Zahlen stimmen, steht auf der
    Wärmebilanz: dort gibt es die Zeile „nicht zuzuordnen". Was die Erzeuger nicht erklären,
    landet in ihr, und sie klein zu bekommen ist genau der Sinn dieser Felder."

  * **Handy-Fassung** (`apps/web/src/styles/handy.css`, `@media (max-width: 720px)` ab `:107`)
    `gesucht nach "annahmen" in handy.css, globals.css, tokens.css: kein Treffer` – die Route
    hat keine eigenen Regeln, es greifen die allgemeinen:
    - `.report-main, .home { padding: 10px 16px calc(86px + env(safe-area-inset-bottom)) }`
      (`:110`), `.report-main { gap: 14px; font-size: 15px }` (`:111`).
    - **Kleine Schrift eine Stufe größer**, mit Begründung im Kommentar (`:187-188`): „Am
      Rechner liest man 12 Punkt aus sechzig Zentimetern, am Handy aus dreißig, aber im
      Gehen." `.report-main .text-[12px] → 13.5px` (`:191`),
      `.report-main .text-[13px] → 14.5px` (`:192`). Für diese Seite heißt das: Hinweis und
      Einheit 13,5 px, Eingabefeld, Knopf, Meldung und Fehler 14,5 px. Das Wort (14 px) und
      der Einleitungsabsatz (15 px) bleiben.
    - Zweispaltig wird nichts: `md:grid-cols-2` greift erst ab 768 px.
    - Die Karten- und Kicker-Regeln (`:182-185`, `.card`, `.card-head h2.kicker`) betreffen
      diese Seite **nicht**, weil sie keine Karte hat.
    - Der Seitenkicker bleibt verborgen: er trägt `hidden … md:block` in `AreaNav.tsx:96`, und
      `handy.css` holt ihn nicht zurück.


LUECKEN:

  [traegt-die-seite] Der Schlussabsatz der Vorlage fehlt ganz – und mit ihm der einzige Satz,
    der sagt, woran man merkt, ob die Annahmen stimmen. `Annahmenfelder.schlussabsatz` liegt
    fertig im Kern (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Annahmenformular.swift:433-440`,
    mit `Textstueck` `:417-427`) und wird von keiner Ansicht gelesen (siehe IST 7); die
    Weiterleitung `/waerme/bilanz` → `/waerme` steht schon in `Bereiche.swift:401`.
    Vorlage: `page.tsx:22-26`.

  [traegt-die-seite] Jedes „Übernehmen" schreibt alle dreizehn Werte **gerundet** zurück, auch
    die, die niemand angefasst hat. `Annahmenfelder.entwurf` setzt
    `Formate.zahl(wert, stellen: feld.stellen)` ins Feld
    (`Annahmenformular.swift:214-217`), und `abgabe` liest jeden lesbaren Entwurf wieder
    heraus und schreibt ihn in den Patch (`:325-335`) – ein Dienstwert
    `buffer_loss_kw_per_k = 0,0045` steht als „0,005" im Feld und geht als `0.005` zurück,
    `pellet_price_eur_per_t = 449,5` als `450`, `indoor_target_c = 21,25` als `21.3`.
    `abweichend` vergleicht auf dieselben Stellen gerundet (`:225-231`), die Zeile wird also
    nicht einmal bernstein: die Änderung ist unsichtbar. Die Vorlage setzt den Rohwert ins
    Feld (`HeatSettings.tsx:96-108`) und schickt ihn unverändert (`:126-130`), rundet also
    nie. `gesucht nach "rund" und "stellen" in AnnahmenformularTests.swift`: nur
    `:274` (`zahlAusText(zahl(-5.5, stellen: 1))`), kein Test über diesen Weg.

  [spuerbar] Das Eingabefeld hat am Telefon keinen Grund. Die Ansicht nimmt
    `Farbe.flaeche2` (`SystemSeiten.swift:825`, ebenso die Kennlinienzeile `:863`) =
    `Marken.flaeche2` = `#123544`
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift:29`,
    `apps/ios/DuckCurveHome/Gestalt/Farben.swift:40`) – das ist `--surface-2`. Die Vorlage
    nimmt `bg-surface-3` = `#173f50` (`HeatSettings.tsx:77`, `tokens.css:25`), in der App
    `Farbe.flaeche3`. Dazu kommt: `Karte` ist am Telefon selbst `Farbe.flaeche2`
    (`apps/ios/DuckCurveHome/Gestalt/Karte.swift:91-94`) und hat dort keinen Rand (`:96-103`).
    Feld und Karte sind am Telefon also **dieselbe Farbe**; sichtbar ist nur die
    Haarlinie `Farbe.linie2`.

  [spuerbar] Die Trennlinien zwischen den Zeilen fehlen. Vorlage: jede Zeile `border-b
    border-line-1 py-2 last:border-b-0` (`HeatSettings.tsx:66`). App: `VStack(spacing: 14)`
    ohne `Divider` (`SystemSeiten.swift:786, 795`). Die App hat den Baustein dafür schon –
    `Werteliste` setzt `Divider().overlay(Farbe.linie1)` zwischen die Zeilen
    (`SystemSeiten.swift:1001`).

  [spuerbar] Der Hinweissatz steht an der falschen Stelle. Vorlage: innerhalb des linken
    `flex-1`-Spans, unter dem Wort, als `<span className="block …">`
    (`HeatSettings.tsx:67-70`) – er bleibt in der linken Spalte, Feld und Einheit stehen
    rechts daneben auf der Grundlinie der ersten Zeile. App: unter der **ganzen** Zeile über
    die volle Breite (`SystemSeiten.swift:839-844`), also unter dem Eingabefeld hindurch.
    Bei „Aufstellraum des Puffers" sind das drei Zeilen quer unter dem Feld.

  [spuerbar] Die Maße der Vorlage liegen benannt im Kern und werden nicht benutzt.
    `Annahmenfelder.Abmessungen` (`Annahmenformular.swift:450-462`) nennt feldbreite 108,
    einheitenbreite 52, spaltenabstand 32, blockabstand 12, hoechstbreite 980 – jeweils mit
    Fundstelle der Vorlage im Kommentar. `gesucht nach "Abmessungen", "feldbreite",
    "einheitenbreite", "spaltenabstand", "blockabstand", "hoechstbreite" in
    apps/ios/**/*.swift: Treffer nur in der Definition selbst
    (Annahmenformular.swift:442-461)`. Die Ansicht setzt stattdessen 92
    (`SystemSeiten.swift:822`), 42 (`:837`), 28 (`:784`), 18 (`:766`) und gar keine
    Höchstbreite – am iPad läuft das Formular damit über die ganze Breite, die Vorlage hört
    bei 980 px auf (`page.tsx:14`).

  [spuerbar] Der Knopf ist eine Kapsel. App: `Capsule()` (`SystemSeiten.swift:887`). Vorlage:
    `rounded-[2px]` (`HeatSettings.tsx:194`), also `--radius-1: 2px` (`tokens.css:92`), in der
    App `Marken.radius1` (`Marken.swift:373`). Dazu die Dimmung: die Vorlage nimmt beim Senden
    `opacity: 0.6` (`HeatSettings.tsx:195`), die App dimmt nur bei fehlendem Recht auf 0,4
    (`SystemSeiten.swift:891`) und während `schickt` gar nicht.

  [spuerbar] Der Fehler nach dem Übernehmen steht an der falschen Stelle und verwirft
    Getipptes. Vorlage: in der Knopfzeile neben dem Knopf, in `--alert`
    (`HeatSettings.tsx:200`), das Formular bleibt unangetastet. App: ein `Stoerung`-Band
    **oben über dem Formular** (`SystemSeiten.swift:735-737`) mit einem Knopf „Erneut", der
    `lade()` ruft (`:736`) – und `lade()` → `uebernimmAntwort(c)` (`:984-988`) schreibt
    `entwuerfe` und `kennlinie` neu. Wer nach einer Ablehnung „Erneut" tippt, verliert alles,
    was er getippt hat. Die Vorlage hat dort keinen solchen Knopf.

  [spuerbar] Alle Eckenradien der Felder sind zu groß: `Marken.radius3` = 6
    (`Marken.swift:375`) an Feld (`SystemSeiten.swift:827, 832`) und Kennlinienzeile
    (`:865, 871`), die Vorlage setzt an beiden `rounded-[2px]`
    (`HeatSettings.tsx:77, 186`).

  [spuerbar] Kein Fokusring. Vorlage: `:focus-visible { outline: 0; box-shadow:
    var(--focus-ring) }` (`globals.css:54`), `--focus-ring: 0 0 0 6px rgba(242,169,0,0.12)`
    (`tokens.css:97`) – bei dreizehn Feldern nebeneinander die einzige Antwort darauf, in
    welchem man tippt. `gesucht nach "focus", "Fokus", "focused" in SystemSeiten.swift: kein
    Treffer`.

  [spuerbar] Die App sichert die Seite leichter ab als der Browser. Vorlage: `requireOwner()`
    in der Seite selbst (`page.tsx:11`), Umleitung auf `/` (`guard.ts:14`), dazu
    `force-dynamic`, damit die Prüfung zur Laufzeit läuft (`page.tsx:6-7`). App:
    `Seitenwahl.swift:82-83` zeichnet `AnnahmenSeite()` ohne jede Prüfung; verborgen wird nur
    der Reiter (`apps/ios/DuckCurveHome/App/Reiterzeile.swift:27`, Begründung `:11-15`:
    „blendet aus, es sperrt nicht"), und in der Seite sind nur Felder und Knopf gesperrt
    (`SystemSeiten.swift:833, 872, 890`). `Bereiche.nurHausherr(_:)`
    (`Bereiche.swift:435-438`) ist dafür da und wird von keiner Ansicht gerufen (`gesucht nach
    "nurHausherr" in DuckCurveHome: Treffer nur Reiterzeile.swift:11,27,118 und ein Kommentar
    in RechnungenSeite.swift:36`). Nebenbei: ein Gast sieht über „Alle Werte" die ganze
    Konfiguration einschließlich Tarif und Regelung (`SystemSeiten.swift:914-937`), und es
    steht kein Satz dabei, warum alles grau ist.

  [klein] Drei Schriftgrößen der Zeile stimmen nicht: das Wort steht in `Schrift.klein` = 13
    (`apps/ios/DuckCurveHome/Gestalt/Typografie.swift:45`, benutzt
    `SystemSeiten.swift:813`), die Vorlage setzt 14 px (`HeatSettings.tsx:67`); Hinweis und
    Einheit stehen in `Schrift.winzig` = 11,5 (`Typografie.swift:46`, benutzt `:835, :841`),
    die Vorlage 12 px und am Handy 13,5 (`HeatSettings.tsx:69,79`, `handy.css:191`); der
    Feldtext steht in `Schrift.zahl` = 15 Mono (`Typografie.swift:69`, benutzt `:818, :857`),
    die Vorlage 13 px und am Handy 14,5 (`HeatSettings.tsx:77,186`, `handy.css:192`).

  [klein] Das Wort ist zu hell: `Farbe.text1` (`SystemSeiten.swift:814`) gegen `text-text-2`
    der Vorlage (`HeatSettings.tsx:67`). Damit stehen Wort und Zahl in derselben Helligkeit,
    während die Vorlage die Zahl führen lässt (`text-text-1` nur im `input`, `:77`).

  [klein] Der Einleitungsabsatz ist zu klein: `Schrift.klein` = 13
    (`SystemSeiten.swift:768`) gegen `text-[15px] leading-[1.6]` (`page.tsx:15`). Der
    `lineSpacing(3)` (`:770`) trifft 1,6 bei 13 Punkten ungefähr, bei 15 wären es 4.

  [klein] Der Ladesatz weicht in Wort und Form ab: „Wird geholt …" in einer `Karte` mit 18
    Punkten Polster (`SystemSeiten.swift:745`, `Karte.swift:402`) gegen „lädt …" als bloßer
    Absatz in 14 px `text-3` (`HeatSettings.tsx:158`).

  [klein] Die Zeile bricht nicht um. Vorlage: `flex-wrap … gap-y-1` (`HeatSettings.tsx:66`) –
    passt das Feld nicht neben das Wort, rutscht es mit 4 px Abstand darunter. App: ein
    `HStack` (`SystemSeiten.swift:811`), in dem das 92 Punkte breite Feld steht und das Wort
    über drei Zeilen bricht.

  [klein] Zweispaltig wird zu früh: `ViewThatFits … frame(minWidth: 640)`
    (`SystemSeiten.swift:783-794`) gegen `md:grid-cols-2` (`HeatSettings.tsx:162`), und `md`
    ist 768 px. Zwischen 640 und 768 zeigt die App zwei Spalten, wo die Vorlage eine zeigt.

  [klein] Die Überschrift der Kennlinie ist in der App Sperrschrift: `Kicker(wort:)`
    (`SystemSeiten.swift:850`) = 10,5 Punkte, `tracking(1.4)`, Großbuchstaben, `Farbe.kicker`
    (`Typografie.swift:151-160`). Die Vorlage setzt einen normalen Satz in 14 px `text-2`
    (`HeatSettings.tsx:176`). Dazu: „Temperatur:COP" steht in der Vorlage in
    `<code className="mono">` (`:178`), in der App im Fließtext
    (`Annahmenformular.swift:358`).

  [klein] Der Dokumentationskommentar der Seite sagt „zwölf beschriftete Felder"
    (`SystemSeiten.swift:756`); es sind dreizehn (`Annahmenformular.swift:97-178`,
    `HeatSettings.tsx:29-43`). Die Zahl steht sonst überall richtig
    (`Annahmenformular.swift:6, 70, 89`).

  [klein] Das Wort ist kein Griff. Vorlage: die Zeile ist ein `<label>`
    (`HeatSettings.tsx:66`), ein Tippen auf „Verbrennungswirkungsgrad" setzt den Fokus ins
    Feld. App: `Text` und `TextField` sind unverbunden (`SystemSeiten.swift:810-838`); auf 390
    Punkten ist das Ziel damit 92 Punkte breit statt der ganzen Zeile.

  Zwanzig Punkte: zwei `traegt-die-seite`, neun `spuerbar`, neun `klein`.


KERN: SCHON DA (nachgesehen, nicht geraten):

  * `Annahmenfeld` mit `schluessel`, `wort`, `hinweis`, `einheit`, `schritt`, `stellen`,
    `darfNegativ`, `lesen`, `schreiben` – `Annahmenformular.swift:22-65`.
  * `Annahmenfelder.alle`, die dreizehn Felder in Sachreihenfolge mit Leser und Schreiber je
    Feld – `Annahmenformular.swift:97-178`.
  * `Annahmenfelder.spalten(_:)`, geteilt bei `ceil(n/2)` – `:188-191`.
  * `Annahmenfelder.entwuerfe(_:)` / `entwurf(_:_:)` / `abweichend(_:entwurf:gegen:)` –
    `:205-236`.
  * `Annahmenfelder.kurveZuText(_:)` / `textZuKurve(_:)` / `rohzahl(_:)` – `:251-299`
    (Semikolon-Regel für deutsche Dezimalkommas `:266-271`).
  * `Annahmenfelder.Abgabe` und `abgabe(entwuerfe:kennlinie:)` – `:307-335`.
  * Alle Sätze der Seite, wörtlich und mit Fundstelle: `kicker` `:340`, `einleitung`
    `:346-351`, `kennlinienTitel` `:354`, `kennlinienErklaerung` `:357-362`, `knopf`/
    `knopfLaeuft` `:365-367`, `uebernommenSatz` `:375-378`, `kennlinienFehler` `:381-382`,
    `ladefehler` `:385`, `aenderungAbgelehnt` `:391`, `methodensaetze` `:395-409`.
  * `Annahmenfelder.Textstueck` und `schlussabsatz` – `:417-440` (ungenutzt, siehe Lücken).
  * `Annahmenfelder.Abmessungen` – `:450-462` (ungenutzt, siehe Lücken).
  * `Formate.zahlAusText(_:)`, liest deutsch und englisch, U+2212 und schmale Leerzeichen –
    `:479-490`. `Formate.zahl(_:stellen:)` – `Formate/Formate.swift:44-55`, **ohne**
    Tausendertrennzeichen (`String(format: "%.Nf")`, `:50`), also keine „1.000"-Falle.
  * `Api.einstellungen()` → `GET /config` → `HemsConfig` –
    `DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:423-425`.
    `Api.stelleWaerme(_:)` → `POST /config/heat` → `HemsConfig` – `Api.swift:427-429`.
    Beides deckungsgleich mit `client.ts:123-125`.
  * `HeatConfigIn` mit `copCurve` und den dreizehn flachen Schlüsseln –
    `DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:4883ff`.
  * `Marken.radius1 = 2` (`Gestalt/Marken.swift:373`), `Marken.flaeche3 = #173F50` (`:30`),
    `Marken.alarm = #E0533D` (`:138`), `Marken.linie1/linie2` (`:32-33`) – alles, was für die
    Maße der Vorlage fehlt, ist schon benannt; `Farbe.flaeche3`/`Farbe.alarm` in
    `DuckCurveHome/Gestalt/Farben.swift:41, 89`.
  * `Bereiche.nurHausherr(_:)` – `Bereiche/Bereiche.swift:435-438`; der Reiter trägt
    `nurHausherr: true` (`:225`). `Hauszustand.darfSchalten`
    (`DuckCurveHome/App/Hauszustand.swift:307`).
  * Weiterleitung `/waerme/bilanz` → `/waerme` im Kern – `Bereiche.swift:396-401`, damit der
    Verweis des Schlussabsatzes ankommt.
  * Bausteine: `Karte` (`Gestalt/Karte.swift:15-104`), `Leer` (`:390-404`), `Stoerung`
    (`:419-465`), `Kicker` (`Gestalt/Typografie.swift:151-160`), `Ansichtswahl`
    (`Gestalt/Ansichtswahl.swift:17-70`), `Methode` (`Seiten/Bericht.swift:514-577`),
    `Werteliste` mit Trennlinien (`Seiten/Technik/SystemSeiten.swift:992-1012`).


ES FEHLT:

  1. Ein Abgeben, das nichts rundet. Heute geht jeder Wert über die Anzeige
     (`Formate.zahl(…, stellen:)`) und wieder zurück. Vorschlag in
     `DuckCurveKit/Sources/DuckCurveKit/Zustand/Annahmenformular.swift`:
     `public static func abgabe(entwuerfe: [String: String], kennlinie: String,
     gegen cfg: HemsConfig?) -> Abgabe`, die ein Feld nur dann schreibt, wenn
     `abweichend(feld, entwurf:, gegen: cfg)` wahr ist, und für ein unverändertes Feld
     nichts in den Patch legt (jedes Feld von `HeatConfigIn` ist wahlfrei, der Encoder lässt
     `nil` weg – siehe `:316-319`). Die alte Fassung bleibt als
     `abgabe(entwuerfe:kennlinie:)` nicht stehen, sonst benutzt sie wieder jemand. Test:
     Dienstwert `0.0045` mit `stellen: 3` darf nach einem Übernehmen ohne Eingabe **nicht**
     im Patch stehen.
  2. Die Maße, die `Abmessungen` noch nicht nennt, damit die Ansicht sie nicht wieder
     hart hinschreibt: `zeilenpolster: 8` (`py-2`, `HeatSettings.tsx:66`),
     `zeilenabstandUmbruch: 4` (`gap-y-1`, ebd.), `wortAbstand: 16` (`gap-x-4`, ebd.),
     `feldEinheitAbstand: 8` (`gap-2`, `:71`), `knopfpolster: (16, 8)` (`px-4 py-2`, `:194`),
     `spaltenumbruch: 768` (`md:`, `:162`) – in
     `Annahmenformular.swift:450-462`, jede Zahl mit ihrer Fundstelle im Kommentar, wie die
     fünf, die schon dort stehen.


BAUPLAN:

  1. `DuckCurveKit/Sources/DuckCurveKit/Zustand/Annahmenformular.swift` ändern: `abgabe` um
     `gegen cfg:` erweitern (ES FEHLT 1), `Abmessungen` um die sechs Maße erweitern
     (ES FEHLT 2). `DuckCurveKit/Tests/DuckCurveKitTests/AnnahmenformularTests.swift` um den
     Rundungsfall ergänzen.
  2. `DuckCurveHome/Seiten/Technik/SystemSeiten.swift`, `formular(_:)` (`:764-778`): Karte
     aufgeben oder behalten? Behalten – die App hat für einen Formularblock keinen anderen
     Behälter, und `Seite` setzt keinen Grund für freistehende Zeilen. Dann aber den
     Feldgrund auf `Farbe.flaeche3` (Lücke 3), damit das Feld sich am Telefon von der Karte
     abhebt. Abstand der drei Blöcke von 18 auf `Abmessungen.blockabstand` (12) setzen
     (`:766`), `frame(maxWidth: Abmessungen.hoechstbreite, alignment: .leading)` auf die
     Karte (Lücke 6). Einleitung auf `Schrift.sans(15)` und `lineSpacing(4)` (`:768-770`,
     Lücke 14).
  3. Dieselbe Datei, `spalten(_:)` (`:781-801`): `minWidth` von 640 auf
     `Abmessungen.spaltenumbruch` (768) (Lücke 17), `HStack(spacing:)` auf
     `Abmessungen.spaltenabstand` (32) (Lücke 6), je Spalte `VStack(spacing: 0)` mit einer
     Trennlinie zwischen den Zeilen und keiner nach der letzten – wie `Werteliste`
     (`:999-1008`) es macht (Lücke 4).
  4. Dieselbe Datei, `feldzeile(_:_:)` (`:803-846`): Zeile neu aufbauen. Links ein
     `VStack(alignment: .leading, spacing: 4)` aus Wort (`Schrift.sans(14)`, `Farbe.text2`)
     und Hinweis (`Schrift.sans(12)`, `Farbe.text3`, `lineSpacing(2)`), rechts
     `HStack(spacing: Abmessungen.feldEinheitAbstand)` aus Feld und Einheit, beide Blöcke in
     einem `HStack(alignment: .firstTextBaseline, spacing: Abmessungen.wortAbstand)`
     (Lücken 5, 12, 13). Feld: Breite `Abmessungen.feldbreite` (108),
     `Schrift.mono(13)`, Radius `Marken.radius1`, Grund `Farbe.flaeche3`, Rand
     `Farbe.linie2` bzw. `Farbe.amber`; Einheit Breite `Abmessungen.einheitenbreite` (52),
     `Schrift.mono(12)`, `Farbe.text3` (Lücken 6, 9, 12). Polster oben und unten
     `Abmessungen.zeilenpolster` (8). Dazu ein Fokusring (Lücke 10) und
     `.contentShape` + `.onTapGesture` auf dem Wort, das den Fokus setzt (Lücke 20) – beides
     über `@FocusState` je `feld.schluessel`.
  5. Dieselbe Datei, `kennlinienzeile(_:)` (`:848-874`): `Kicker` durch
     `Text(Annahmenfelder.kennlinienTitel)` in `Schrift.sans(14)`/`Farbe.text2` ersetzen
     (Lücke 18), Erklärung auf `Schrift.sans(12)`, Feld auf `Marken.radius1`,
     `Schrift.mono(13)`, `Farbe.flaeche3`.
  6. Dieselbe Datei, `abgabezeile` (`:876-900`): `Capsule()` durch
     `RoundedRectangle(cornerRadius: Marken.radius1)` ersetzen, Polster auf
     `Abmessungen.knopfpolster`, `opacity(schickt ? 0.6 : (darfSchalten ? 1 : 0.4))`
     (Lücke 7); den Fehler aus dem Band in diese Zeile holen: bei gesetztem `fehler` **und**
     vorhandenen `einstellungen` den Satz hier in `Schrift.sans(13)`/`Farbe.alarm` zeigen und
     das `Stoerung`-Band oben nur noch für den Ladefehler stehen lassen (Lücke 8). Der
     Erfolgssatz bleibt, aber in `Schrift.sans(13)`/`Farbe.text2` statt `winzig`.
  7. Dieselbe Datei, `body` (`:733-749`): `Leer(satz:)` durch den Satz der Vorlage ersetzen
     („lädt …") und ohne Karte zeigen (Lücke 15); den Schlussabsatz anhängen – eine neue
     private Ansicht `schlussabsatz`, die `Annahmenfelder.schlussabsatz`
     (`Annahmenformular.swift:433-440`) zeichnet: 14 Punkte, `Farbe.text3`, der Verweis
     bernstein und tippbar nach `/waerme/bilanz` (Lücke 1). Steht **unter** der Formularkarte
     und über `Methode`, wie in der Vorlage (`page.tsx:21-26`).
  8. `DuckCurveHome/App/Seitenwahl.swift:82-83`: vor `AnnahmenSeite()` prüfen, ob
     `Bereiche.nurHausherr(weg)` und der Zugang kein Hausherr ist, und dann auf `/` leiten –
     dieselbe Antwort, die `guard.ts:14` gibt. Das trifft die anderen zehn
     `nurHausherr`-Wege mit (Lücke 11); die Prüfung gehört an eine Stelle, nicht in zehn
     Seiten.
  9. `SystemSeiten.swift:756`: „zwölf" zu „dreizehn" (Lücke 19).


WAS SCHWIERIG WIRD:

  * **Ein tippbares Wort mitten in einem umbrechenden Absatz.** SwiftUI hat dafür nichts:
    `Text` + `Text` lässt sich zusammensetzen und bricht richtig um
    (Vorbild `DuckCurveHome/Seiten/Technik/AnlageSeite.swift:114-138`), trägt aber keine
    Berührung je Stück; ein `HStack` aus Text und Button bricht nicht um. Der Kern hat den
    Absatz deshalb schon als `[Textstueck]` zerlegt (`Annahmenformular.swift:411-440`, mit
    der Begründung `:413-416`). Zwei Wege, beide im Projekt belegt:
    (a) `AttributedString` aus den Stücken bauen, dem `.verweis` einen `link` geben und
    `.environment(\.openURL, OpenURLAction { … wegweiser.gehe … })` darüberlegen – die App
    liest `@Environment(\.openURL)` schon in
    `DuckCurveHome/Seiten/Technik/ZugangSeite.swift:34`, fängt ihn aber nirgends ab, das wäre
    neu.
    (b) Der Weg, den das Projekt bisher gewählt hat: der Satz als Absatz, der Verweis als
    eigene bernsteinfarbene Zeile darunter – `ZugangSeite.swift:288-293` und
    `DuckCurveHome/Seiten/Technik/ReglerSeite.swift:341-346`
    (`Button(wort) { wegweiser.gehe(weg) }`, `Schrift.klein`, `.buttonStyle(.plain)`,
    `Farbe.amber`). Das ist die billigere und im Haus eingeführte Lösung, verschiebt aber den
    Verweis aus dem Satz heraus; (a) trifft die Vorlage genauer.
  * **Der Fokusring.** Die Vorlage bekommt ihn vom Browser (`globals.css:54`), SwiftUI
    zeichnet an einem `TextField` mit `.textFieldStyle(.plain)` nichts. Ein Vorbild für den
    Fokus selbst gibt es im Haus genau einmal, und nur als `Bool` für ein einzelnes Feld:
    `@FocusState private var amFeld: Bool` mit `.focused($amFeld)`
    (`DuckCurveHome/Alfred/Alfredblatt.swift:39, 223`). Für dreizehn Felder braucht es
    `@FocusState private var fokus: String?` über `feld.schluessel` – das ist neu –, dazu ein
    zweites `overlay` mit `Farbe.amber.opacity(0.12)` in 6 Punkten Stärke, wie `--focus-ring`
    (`tokens.css:97`) es nennt. Ein gezeichneter Ring und nicht `.focusEffectDisabled`-Gegenteil:
    `gesucht nach "focus" in SystemSeiten.swift: kein Treffer`.
  * **Die Trennlinien in zwei Spalten.** „Keine Linie nach der letzten Zeile" heißt in der
    Vorlage `last:border-b-0` **je Spalte** (`HeatSettings.tsx:66`), nicht je Liste – bei 7
    und 6 Feldern fällt also in jeder Spalte genau eine Linie weg. In einem `VStack` muss das
    über den Index laufen; `Werteliste` (`SystemSeiten.swift:999-1008`) setzt die Linie
    deshalb **vor** jede Zeile außer der ersten, was dasselbe Bild ergibt und sich
    übernehmen lässt.
  * **Zweispaltig nach Breite.** Die Vorlage schaltet an einer Pixelgrenze (768),
    `ViewThatFits` (`SystemSeiten.swift:783`) schaltet nach Platzbedarf. Mit zwei Spalten à
    (108 + 52 + 16 + 8 + Wort) ist der Umschaltpunkt nicht die Zahl aus der Vorlage, sondern
    was die Felder gerade brauchen. Entweder `minWidth: 768` setzen (dann stimmt die Grenze,
    aber „passt" heißt nicht mehr „passt") oder auf `horizontalSizeClass` umstellen – die
    Seite macht es heute über `ViewThatFits`, `Karte` und `Ansichtswahl` machen es über
    `horizontalSizeClass` (`Karte.swift:22-24`, `Ansichtswahl.swift:24-25`). Die Grenze 768
    liegt genau dort, wo iOS von `.compact` auf `.regular` wechselt; `horizontalSizeClass`
    ist deshalb der Weg, der zur Vorlage **und** zum Rest der App passt.
