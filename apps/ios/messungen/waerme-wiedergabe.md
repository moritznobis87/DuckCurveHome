========================= messen:waerme-wiedergabe   Aufwand: gross

IST: Was die App-Seite heute von oben nach unten zeigt
-------------------------------------------------------

`struct WiedergabeSeite: View` in `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:155-334`,
erreichbar über `apps/ios/DuckCurveHome/App/Seitenwahl.swift:61-65` (`/waerme/wiedergabe`, mit
`Wiedergabeziel.ausWeg(weg)`).

1. `tagwahl` (`SystemSeiten.swift:200-227`): eine `HStack` mit Abstand 8.
   * „‹" / „›" als `Text(Schrift.karte)` in 28×28 (`:202-212`), „›" ist deaktiviert und auf
     `Farbe.text3`, sobald `tag >= haus.heute`.
   * in der Mitte `Tag.kurz(tag)` in `Schrift.zahlKlein` (Mono 12,5), `Farbe.text1`,
     `minWidth: 92` (`:206`) - also „Sa, 7.11." (`Formate/Tag.swift:94-98`).
   * rechts ein einziger Knopf „Abspielen"/„Anhalten", `Schrift.klein`, `Farbe.deep` auf
     `Farbe.amberWeich`, Kapsel, Polster 12/6 (`:214-225`).
2. `Stoerung(fehler:)` mit „Erneut", wenn `fehler != nil` (`:176-178`,
   Baustein `apps/ios/DuckCurveHome/Gestalt/Karte.swift:410-436`).
3. `Karte(kicker: "Wiedergabe", titel: zeitpunkt(w))` (`:180-185`), darin:
   * `schieber(w)` (`:229-239`): ein `Slider` 0…`frames.count-1`, Schritt 1, `tint: Farbe.amber`,
     darunter links `Formate.hhmm(iso: w.von)` und rechts `Formate.hhmm(iso: w.bis)` in
     `Schrift.winzig`/`Farbe.text3`.
   * `werte(w)` (`:252-285`): zehn bis zwölf `Zeile`-Reihen (`Karte.swift:360-383`) für den
     Augenblick: Sonne (`Farbe.pv`), Haus, Wärmepumpe (`Farbe.waermepumpe`), draußen (nur wenn
     `outdoorC != nil`), Vorlauf, Puffer (`soc`), „Puffer oben" (`tempsC.first`), „offene Kreise"
     (`roomsOpen` von `roomsTotal`), Strompreis (`preisCtKwh[stelle]`), und
     „w.geplantWp" → „freigegeben"/„nicht freigegeben" (`:277-281`).
4. `Methode(w.hinweiseDe + ["Aufgelöst in \(w.stepMin) Minuten, \(w.frames.count) Augenblicke."])`
   (`:186-190`, Baustein `apps/ios/DuckCurveHome/Seiten/Bericht.swift:334-...`, Titel vorgegeben
   „Wie das gerechnet ist", kein `kurz`).
5. Solange nichts da ist: `Karte { Leer(satz: "Wird geholt …") }` (`:191-193`).

Verhalten: `lade()` (`:321-333`) ruft `haus.api.anlageWiedergabe(tag: tag)` **ohne** `schrittMin`,
also immer 5 Minuten (`DuckCurveKit/Netz/Api.swift:263-265`). `spiele()` (`:307-319`) läuft in
250-ms-Schritten und setzt am Ende `stelle = 0`, läuft also endlos im Kreis. `anfangsstelle(w)`
(`:299-303`) setzt den Schieber beim ersten Laden auf `Wiedergabeziel.bildstelle(...)`, wenn ein
Ziel für genau diesen Tag da ist, sonst auf 0; `onAppear` (`:197`) nimmt `ziel?.tag ?? gestern`.

Kein Anlagenschema, kein Tagesband, keine Tagesuhr, keine Schrittwahl, keine Tempowahl, kein
Bildzähler, kein Datumsfeld, kein Hinweis auf fehlende Bilder.


VORLAGE
-------

Einstieg `apps/web/src/app/waerme/wiedergabe/page.tsx:1-17`:
`AreaShell kicker="Ein Tag am Anlagenschema · zum Durchfahren"` (`:10`), darin `<Suspense>` um
`<Wiedergabe />` - der Kommentar `:11` nennt den Grund: die Seite liest Tag und Uhrzeit aus der
Adresse, das verlangt eine Suspense-Grenze. Hülle: `apps/web/src/components/layout/AreaShell.tsx:77-94`;
der Kicker landet in `AreaTabs` als `right` und wird dort als
`className="kicker hidden truncate pb-2.5 md:block" style={{fontSize: 11}}` gesetzt
(`apps/web/src/components/layout/AreaNav.tsx:96`) - **am Handy ist er also absichtlich weg**,
sichtbar erst ab 768 Punkten. `.kicker` = Mono, 13px (hier auf 11 übersteuert), Laufweite 0,13em,
Versalien, `--text-kicker` (`globals.css:57-64`, `--text-kicker` ist `mist`, siehe
`tokens.css:46`-Pendant `Marken.swift:46`).

Alles weitere in `apps/web/src/components/waerme/Wiedergabe.tsx` (321 Zeilen),
`.../Tagesuhr.tsx` (316), `.../tagesuhr.ts` (124), `.../Tagesband.tsx` (279).

**Die Begründungen aus dem Kopfkommentar** (`Wiedergabe.tsx:15-34`), die beim Umbau nicht
verloren gehen dürfen:
  * „Gezeichnet wird **dasselbe** Schema wie auf der Seite ‚Anlage' - dieselbe Komponente,
    dieselben Rohre, dasselbe wandernde Licht -, nur bekommt es statt des Augenblicks ein Bild aus
    der Minutenreihe. Dass es dieselbe Komponente ist, ist die ganze Idee: ein zweites,
    vereinfachtes Rückblickschema wäre in einer Woche ein anderes Haus." (`:19-21`)
  * „Drei Ansichten desselben Zeitpunkts, eine Uhr. … Alle drei hängen an einem einzigen Index,
    und jede kann ihn verstellen." (`:23-26`)
  * „**Die Uhr der Wiedergabe ist nicht die Wanduhr.** `nowMs` bekommt die Zeit des Bildes, nicht
    `Date.now()`. Sonst stünde am Schema ‚läuft seit 7 Stunden', weil es die Laufzeit gegen jetzt
    rechnet, während das Bild von gestern Mittag ist." (`:28-30`) - **das war schon einmal der
    Fehler.**
  * `:45-52`: Heute und jede Uhrzeit dieser Seite in der Zeit des Hauses, nicht des Geräts. „Die
    erste Fassung formatierte mit der Zeitzone des Browsers. … `lib/format` und `lib/day` lösen
    das längst für die ganze App; hier wurden sie übergangen." Daher `heute = isoToday`,
    `uhr = hhmm` (`:53-54`).

  * **Block 1 - Karte „Wiedergabe", Kopfzeile**  (`Wiedergabe.tsx:193-203`)
    `Card` + `CardHead title="Wiedergabe"` (`components/ui/Card.tsx:20-29`). Rechts, nur wenn
    Daten da sind: `<span className="mono text-[12px] text-text-3">` mit wörtlich
    „{frames.length} von {erwartet} Bildern · {step_min}-Minuten-Schritt".
    Maße: `.card` = `--surface-2` #123544, 1px `--line-1` rgba(255,255,255,.10), `--radius-2`,
    Polster 20 (`globals.css:67-77`); am Handy randlos, Radius 16, Polster 16 (`handy.css:182`).
    `.card-head h2.kicker` wird am Handy zu Sans 16,5px/600, keine Versalien, `--text-1`
    (`handy.css:184`); `.card-head-right` bricht dort auf eine eigene Zeile um, 13px
    (`handy.css:185`).
    DATEN: `api.anlageWiedergabe(tag, stepMin)` → `GET /anlage/wiedergabe?day=&step_min=`
    (`lib/api/client.ts:104-106`), Typ `AnlageReplayOut` (`lib/api/types.ts:1802-1832`):
    `day, step_min, von, bis, erwartet, frames[AnlageOut], preis_ct_kwh[], geplant_wp[],
    geplant_ofen[], hinweise_de[]`. `geplant_ofen` wird in der ganzen Vorlage nicht gelesen
    (gesucht nach `geplant_ofen` in `apps/web/src`: nur `types.ts:1829`).

  * **Block 2 - Tageswahl und Schrittweite**  (`Wiedergabe.tsx:205-220`)
    Eine umbrechende Zeile, Abstand 8:
      - „‹" `.wg-knopf` (30×30, 16px, `--text-2`, 1px `--line-1`, Radius 6, transparent;
        deaktiviert `--line-2`) → `zuTag(tagPlus(tag,-1))`, `aria-label="Tag zurück"`.
      - `<input type="date" className="wg-datum mono">` mit `value={tag}` und **`max={heute()}`**
        (13px, `--text-1`, 1px `--line-1`, Radius 6, Polster 5/8, `color-scheme: dark`;
        `globals.css:620`) - ein direkter Sprung auf jeden Tag bis heute.
      - „›" `.wg-knopf`, `disabled` wenn `tag >= heute()`.
      - `langerTag(tag)` in 13px `--text-2` (`:213`), also „Samstag, 7. November 2026"
        (`lib/day.ts:49-52`).
      - rechtsbündig („ml-auto") das Wort „Schritt" in 12px `--text-3`, dann drei Knöpfe
        `1 min / 5 min / 15 min` (`SCHRITTE = [1, 5, 15]`, `:38`). `.wg-wahl`: Mono 11px,
        Laufweite 0,08em, `--text-3`, 1px `--line-1`, Radius 999, Polster 5/10;
        `.wg-wahl-an`: `--petrol` auf `--amber` (`globals.css:621-622`).
        Ein Wechsel holt den Tag neu (`:124` Abhängigkeit `[tag, stepMin]`).
    Der Tag steht in der Adresse: `zuTag` schreibt `router.replace("/waerme/wiedergabe?day=…")`,
    Kommentar `:78`: „Den Tag wechseln heißt die Adresse wechseln; die Uhrzeit aus einem Sprung
    gilt dann nicht mehr."
    Zustände: Fehler als `<p className="m-0 text-[13px] text-alert">` (`:222`); Laden
    „Der Tag wird geholt." 13px `--text-3` (`:223`); Antwort ohne Bilder: `hinweise_de?.[0]`
    13px `--text-3` (`:224`).

  * **Block 3 - Die Bühne mit dem Anlagenschema**  (`Wiedergabe.tsx:226-240`)
    `.wg-buehne` (Spalte, Abstand 10, `outline: none`; bei Tastaturfokus 2px `--amber`,
    Offset 6, Radius 30 - `globals.css:610-611`), `tabIndex={0}`,
    `aria-label="Wiedergabe des Anlagenschemas. Leertaste spielt, Pfeiltasten gehen Bild für Bild."`
    Darin dieselbe Fassung wie die Anlagenseite: `.anlage-buehne` (Radius 28, 1px Polster,
    Verlauf rgba(255,255,255,.14)→.02, Schatten `0 40px 120px rgba(0,0,0,.45)`),
    `.anlage-innen` (Radius 27, Verlauf rgba(10,39,53,.85)→rgba(5,22,31,.9)),
    `.anlage-scroll` (`overflow-x: auto`) - `globals.css:564-566`; Kommentar `:606-609`: „Die
    Bühne selbst leiht sich die Rahmen der Anlage …, damit das Schema in beiden Ansichten in
    derselben Fassung sitzt. Eigene Klassen gibt es nur für das, was die Anlage nicht hat: die
    Bedienung."
    Darin `<Schema a={bild} nowMs={zeitMs} ruhig={ruhig} />` (`:237`) -
    `apps/web/src/components/anlage/Schema.tsx:152` (`{ a: Anlage; nowMs: number; ruhig: boolean }`),
    `nowMs` wird für „läuft seit …" (`Schema.tsx:325`, `dauerText`) und
    `warmwasserStatus(ww, nowMs)` (`Schema.tsx:380`) gebraucht. `ruhig` kommt aus
    `window.matchMedia("(prefers-reduced-motion: reduce)")` (`Wiedergabe.tsx:56-58, 76`) und
    schaltet die wandernden Lichtpunkte ab (`Schema.tsx:74`).
    DATEN: jedes `frames[i]` ist ein vollständiges `AnlageOut` - Strom (pv/grid/battery/house/
    heat_pump/rest, Anteile), Wärmepumpe, Ofen, Speicher (vier `temps_c`, `soc`, `net_kw`,
    `return_c` - `types.ts:1843-1860`), Heizkreis, Warmwasser, `outdoor_c`, `at`.
    **Handy-Fassung** (`handy.css:395-401`, Abfrage `@media (max-width: 720px)` ab `:107`):
    `.anlage-buehne` Radius 20 **ohne Schatten**, `.anlage-innen` Radius 19, und
    `.anlage-buehne::after` setzt einen eigenen Satz unter die Bühne, wörtlich
    „zur Seite wischen: Strom, Erzeuger, Speicher, Verbraucher  ›" (Polster 9/12/11, zentriert,
    12,5px, `--text-3`). Begründung im Kommentar `:396-397`: „Das Schema ist eine Zeichnung im
    Querformat und rollt zur Seite. Der Hinweis sagt es, statt dass die rechte Hälfte unbemerkt
    fehlt."

  * **Block 4 - Die Transportleiste `.wg-leiste`**  (`Wiedergabe.tsx:242-271`)
    Eine umbrechende Zeile (Abstand 8, `globals.css:612`):
      - `.wg-spiel`: 38×38, Kreis, `--amber` mit `--petrol`, Zeichen 13px, Glyphe „▶" bzw. „❚❚",
        `aria-label` „Abspielen"/„Pause" (`globals.css:613`).
      - `.wg-uhr`: `uhr(bild.at)` in Mono 15px, `tabular-nums`, `--text-1`, `min-width: 5ch`.
      - `.wg-schieber`: `<input type="range">` 0…`anzahl-1`, `flex: 1 1 220px`, `min-width: 160px`,
        Höhe 26, `accent-color: --amber`, `aria-label="Zeitpunkt"`, `aria-valuetext={uhr(bild.at)}`
        (`globals.css:616-617`, Kommentar: „Der Schieber nimmt den Rest der Zeile, fällt aber nie
        unter eine Breite, in der man zielen kann.").
      - `.wg-zaehler`: „{i+1}/{anzahl}" in 11,5px `--text-3`, `min-width: 7ch`, rechts.
      - vier Tempoknöpfe `2× 6× 12× 24×` (`TEMPI = [2, 6, 12, 24]`, `:37`, Vorgabe 12), `.wg-wahl`,
        `aria-label="Tempo N Bilder je Sekunde"`. Kommentar `:36`: „Bilder je Sekunde. Bei
        5-Minuten-Schritten ist 12 ein Tag in 24 Sekunden."
    Verhalten:
      - Abspieler `setInterval(1000 / tempo)` (`:130-142`); **am Ende hält er an**, statt von vorn
        zu beginnen - Kommentar `:128-129`: „ein Tag, der unbemerkt in den nächsten Durchlauf
        rutscht, lässt einen zweimal dasselbe für zwei Tage halten."
      - `greifen(ziel)` hält die Wiedergabe an, Kommentar `:151`: „Ein Sprung von Hand hält die
        Wiedergabe an: wer hinfasst, will hinsehen."
      - Tastatur auf dem Abschnitt, nicht auf dem Fenster (`:160-185`): Leertaste spielt/hält,
        Pfeile Bild für Bild, Pos1/Ende an die Ränder. Kommentar: „sonst verschluckt die Seite die
        Leertaste auch dann, wenn jemand in einem Eingabefeld steht."
      - Einstieg aus der Adresse `?day=&t=` (`:62-65`, `:86-112`): die Wunschstunde gilt **einmal
        je Ladung** (in einer Referenz), gezählt ab `d.von` der Antwort und nicht ab der
        Mitternacht des Browsers; gesucht wird das erste Bild an oder nach der Stunde, sonst das
        letzte.

  * **Block 5 - `.wg-tag`: Tagesuhr links, Tagesband rechts**  (`Wiedergabe.tsx:273-280`)
    Raster: `grid-template-columns: minmax(240px,300px) minmax(0,1fr)`, Felder
    `"uhr band" "legende legende"`, Abstand 10/28, `align-items: center`, `margin-top: 6`
    (`globals.css:626-629`). Kommentar: „Die Uhr hat eine feste Spalte; das Band nimmt den Rest und
    darf nicht unter eine Breite fallen, in der die Zeitachse noch lesbar ist - dann bricht es um."
    **Unter 860px** (`globals.css:630`): eine Spalte, Reihenfolge `uhr`, `legende`, `band`,
    zentriert - also auf dem Telefon Uhr, dann Legende, dann Band.
    `.uhr { display: contents }` (`globals.css:636`) mit Begründung `:633-635`: Uhr und Legende
    sind zwei Felder desselben Rasters, „die Legende gehört unter Uhr *und* Band, denn beide
    sprechen dieselben Farben; unter der Uhr allein zog sie die linke Spalte lang und ließ rechts
    ein Loch."

  * **Block 5a - Tagesuhr**  (`Tagesuhr.tsx:36-316`, Geometrie `tagesuhr.ts:1-124`)
    Kopfkommentar `Tagesuhr.tsx:10-33`, die vier Begründungen:
      - „Das Band ist zum Ablesen da … Die Uhr ist zum Zurechtfinden da … Größen vergleicht man
        auf ihr schlecht … deshalb stehen hier keine Größen, die man vergleichen müsste: die
        beiden Stärkeringe kennen fünf Helligkeitsstufen, die übrigen nur an und aus."
      - Reihenfolge der Ringe „in der Reihenfolge der Ursachen: der Preis, der den Plan treibt; die
        Sonne, die ihn auch treibt; die Absicht des Fahrplans; und was die Wärmepumpe wirklich tat.
        Absicht und Ausführung liegen unmittelbar aneinander, damit ihr Auseinanderfallen ohne
        Suchen auffällt."
      - „**Drei Zustände je Stelle, nicht zwei.** Farbe heißt ‚ja', die blasse Spur heißt
        ‚gemessen, aber nein', und gar nichts heißt ‚keine Messung'. … Dasselbe gilt für die
        Absicht: ohne aufbewahrten Fahrplan fehlt die Spur ganz, statt ein Nein vorzutäuschen."
      - „**Die Uhr ist ein Griff.** … Für Tastatur und Vorleseprogramme bleibt der Schieber in der
        Leiste das Bedienelement - ein Kreis, auf dem man zielen muss, ist keines."
    Maße (`Tagesuhr.tsx:36-51`): `viewBox 0 0 360 360`, Mitte 180.
      Ringe (innen/außen, Kommentar „Zwischen je zweien bleiben drei Punkte frei: Flächen stoßen
      nicht aneinander"): Preis [144,158], Sonne [126,141], geplant [114,123],
      gelaufen [98,111], Ofen [84,95].
      Fünf Helligkeiten `[0.16, 0.32, 0.52, 0.76, 1]`; Spur `rgba(255,255,255,.055)`.
      Stundenstriche: `r 161 → 164`, alle sechs Stunden `→ 167`, `stroke #fff`,
      `strokeOpacity 0.42` bzw. `0.14`, Breite 1 (`:136-142`).
      Zahlen 0/6/12/18 auf `r 175`, `.uhr-stunde` = Mono 11px `--text-3` (`globals.css:639`).
      Zeiger (`:217-232`): von `r 78` (mit Ofen) bzw. `92` bis `r 160`; darunter ein Hof in
      `C.deep` Breite 5 („damit er über hellen Ringstücken lesbar bleibt"), darüber weiß Breite 2,
      Punkt `r 4` weiß mit `C.deep`-Rand 2; der Schwebezeiger weiß mit Deckung 0,45 und Breite 1.
      Mitte (`:271-285`): `.uhr-zeit` 38px, Gewicht 200, Laufweite -0,03em, `tabular-nums`,
      `--text-1` bei `y = M-14`; `.uhr-wert` 11,5px Gewicht 300 `--text-2` bei `M+16`
      („Sonne 3,4 kW" bzw. „Sonne ?", dahinter „· 27 ct") und `M+34`
      („Wärmepumpe läuft"/„Wärmepumpe steht", dahinter „· geplant"/„· nicht geplant"/nichts, wenn
      keine Absicht aufbewahrt ist).
      Griff (`:194-209, 242-263`): `.uhr-bild` `touch-action: none`, `cursor: grab`/`grabbing`,
      `max-width: 300`, mittig (`globals.css:637-638`); Trefferzone nur zwischen Abstand 70 und
      178 vom Mittelpunkt - „Die Mitte gehört der Anzeige. Wer dort klickt, will lesen und nicht
      springen." Ziehen mit `setPointerCapture`, Überfahren setzt einen zweiten, schwachen Zeiger.
      Legende `.uhr-legende` (`:288-313`): `grid-area: legende`, Liste waagerecht umbrechend,
      Abstand 4/22, 11,5px, Zeilenhöhe 1,4, `--text-3`; Marke 10×10, Radius 2, 1px nach unten
      versetzt; die Absicht als Umriss (`border: 1px solid`, transparent) - `globals.css:642-645`.
      Texte wörtlich: „Preis · {min} bis {max} ct, heller ist teurer" bzw. „Preis · nicht erfasst";
      „Sonne · bis {max} kW, heller ist mehr" bzw. „Sonne · keine an diesem Tag";
      „Wärmepumpe geplant" (+ „ · kein Fahrplan aufbewahrt"); „Wärmepumpe gelaufen";
      „Pelletofen gebrannt" (nur wenn irgendein Bild `ofen.present` hat).
      Kommentar `:288-289`: „Jede Zeile ist eine Farbmarke und ein Wort in Textfarbe; farbige
      Schrift wäre Kennung ohne Lesbarkeit."
    Rechnung (`tagesuhr.ts`): `anteil` (`:16-19`), `punkt` (0 oben, im Uhrzeigersinn, `:22-25`),
      `ringstueck` (`:37-50`; ein voller Ring wird in zwei Hälften gezeichnet, „ein einzelner Bogen
      von einem Punkt zu demselben Punkt hat für SVG die Länge null"), `laeufe` (`:63-83`),
      `stufe` (`:93-97`), `indexBei` (`:100-113`), `anteilAus` (`:120-124`).
      Begründungen, die mitwandern müssen:
        - `:8-10`: „**Der Winkel ist der Anteil am Tag, nicht die Uhrzeit.** … auch an den beiden
          Umstellungstagen, die 23 oder 25 Stunden haben. Aus der Uhrzeit gerechnet bliebe dort
          eine Stunde offen oder läge doppelt."
        - `:52-62` (`laeufe`): „Ein Lauf endet nicht nur, wenn der Wert wechselt, sondern auch, wenn
          die Zeit springt … Würde nur der Wert verglichen, liefe ein Lauf über einen Ausfall
          hinweg - der Ring zeigte eine Stunde Betrieb, von der niemand etwas weiß." Jeder Lauf
          reicht einen Schritt über seinen letzten Zeitstempel hinaus; `null`/`undefined` ergeben
          keinen Lauf.
        - `:85-92` (`stufe`): „fünf unterscheidbare Helligkeiten liest das Auge sicherer als 288
          fast gleiche"; bei Spanne null bekommt alles die mittlere Stufe.
        - `:3-6`: die Geometrie steht getrennt, „weil hier die Fehler sitzen, die man einem Bild
          nicht ansieht: ein Ring, der um eine Viertelstunde verdreht ist, sieht genauso plausibel
          aus wie ein richtiger. Deshalb … haben eigene Prüfungen."
    DATEN (`Tagesuhr.tsx:69-123`): `von`/`bis`, `step_min`, `frames[].at`,
      `preis_ct_kwh` (Spanne aus min/max, fünf Stufen), `frames[].strom.pv_kw` (Stufen bis
      Tagesmaximum, unter 0,05 kW gilt als nichts), `geplant_wp`, `frames[].waermepumpe.running`,
      `frames[].ofen.present/running`.
    Farben (`components/charts/palette.ts:33-82`): `price #7fa3b3`, `pv #f2a900`,
      `heatPump #e0966b`, `stove #b5651d`, `deep #082431`.

  * **Block 5b - Tagesband**  (`Tagesband.tsx:29-279`)
    Kopfkommentar `:11-27`: „Fünf Flächen untereinander auf einer Zeitachse, jede mit ihrer eigenen
    Größe und Einheit … **Kein gemeinsames Gitter für verschiedene Einheiten:** Kilowatt und Cent
    auf zwei Achsen desselben Bildes läsen sich als Zusammenhang ihrer Kreuzungspunkte, und die
    sind Zufall der Skalierung." Und: „**Absicht und Ausführung stehen als Nachbarn**, dieselbe
    Farbe, die Absicht blass und flacher. … Wo die blasse Zeile einen Balken hat und die kräftige
    darunter keinen, wollte der Fahrplan und die Maschine nicht - das ist die Frage, was der
    Freigabekontakt wirklich auslöst, als Bild."
    Maße (`:29-30, 67-78`): links 66, rechts 12; Flächen von oben nach unten
      `kw` (Titel „Sonne · Netz", Beschriftung „kW") top 20 Höhe 58;
      `preis` („ct/kWh") top 100 Höhe 30;
      `geplant` („geplant", ohne aufbewahrten Fahrplan „geplant ?") top 146 Höhe **8**;
      `gelaufen` („gelaufen") top 159 Höhe 13;
      `ofen` („Ofen", nur wenn vorhanden) top 178 Höhe 13;
      Gesamthöhe = letzte.top + Höhe + 26, von der Komponente selbst gesetzt, weil ECharts ohne
      feste Höhe null misst (`globals.css:623-625`, `.wg-band { width: 100% }`).
      Kommentar `:65-66`: „Die Höhen sind fest: drei dünne Zeitleisten brauchen keine Luft, die
      beiden Kurven schon."
      Flächennamen stehen links daneben als `graphic`-Text in `10px` Mono, `C.text`
      (rgba(255,255,255,.48)) - „Die Farbe gehört den Marken; farbige Schrift wäre Kennung ohne
      Lesbarkeit" (`:155-168`).
      Achse nur unter der letzten Fläche (`:210`), Mono 10px, `hideOverlap`, **immer die Uhrzeit**
      in Hauszeit (`:110-113`: „ECharts setzt an den Tagesgrenzen sonst die Tageszahl, und zwischen
      ‚9' und ‚04:00' liest niemand eine Zeitachse"); Achsenlinie `C.axis` rgba(255,255,255,.2),
      Gitter `C.gridline` rgba(255,255,255,.09), `splitNumber: 2` für die beiden Kurvenachsen.
      Reihen (`:212-252`): Sonne als geglättete Linie `C.pv` Breite 2 mit Fläche Deckung 0,16;
      Netz als Linie `C.price` Breite 1,4; Preis als Treppe (`step: "end"`) `C.price` Breite 1,4,
      Fläche 0,14; alle mit `connectNulls: false`. Drei Zeitleisten als leere Reihen mit
      `markArea` je Lauf; die Absicht blass gefüllt `rgba(color,0.2)` mit 1px Rand - Kommentar
      `:144-147`: „Der Umriss bekommt seine Blässe über die Füllfarbe, nicht über die Deckkraft der
      ganzen Marke: sonst verblasste der Rand mit, und er ist das, was die Absicht kenntlich macht."
      Spielkopf: weiße `markLine` Breite 1,5 bei `zeitMs`, **in jeder Fläche** („sonst endete er
      über den Zeitleisten", `:149`).
      Läufe statt eines Balkens je Bild (`:52-56`): „Je Bild gezeichnet zeigte ein Block von zwei
      Stunden vierundzwanzig feine Nähte … Dieselbe Zusammenfassung wie in der Tagesuhr, also auch
      dieselben Lücken."
      Farbnachweis (`:245-248`): „Wärmepumpe und Ofen liegen farblich nah (ΔE 15,3 normal / 15,1
      deutan, gemessen 09.11.2026), und der Ofen hält gegen die Kartenfläche nur 2,99:1. Jede
      Zeitleiste hat deshalb ihre eigene Zeile und ihren eigenen Namen - das ist die Entlastung,
      die beides zulässig macht."
      Fahne (`:170-207`): Grund `C.deep`, Rand `rgba(242,169,0,.4)`, Schrift `#f1f5f5` 12px,
      `confine: true`, Achsenzeiger über alle Flächen verbunden (`:169`). Inhalt: Uhrzeit fett,
      dann „Sonne X kW", „Netz X kW · X ct/kWh", „Wärmepumpe läuft, X kW"/„steht", darunter
      eingerückt und mit Deckung 0,78 „kein aufbewahrter Fahrplan" / „der Fahrplan wollte
      anfordern" / „der Fahrplan wollte nicht anfordern", und wenn vorhanden „Ofen brennt"/„aus".
      Gezeigt wird **das nächste Bild, kein interpolierter Wert** (`:181-182`: „zwischen zwei
      Bildern liegt nichts, was gemessen wäre").
      Ein Klick ins Band springt auf das zeitlich nächste Bild (`:256-271`).
    DATEN: `frames[].strom.pv_kw`, `frames[].strom.grid_kw`, `preis_ct_kwh`, `geplant_wp`,
      `frames[].waermepumpe.running` und `.power_kw` (nur in der Fahne), `frames[].ofen.present`
      und `.running`, `step_min` für die Lauflänge.

  * **Block 6 - Karte „Zu diesem Tag"**  (`Wiedergabe.tsx:285-301`)
    Steht nur, wenn `hinweise_de` etwas enthält **oder** `frames.length < erwartet`
    (`vollstaendig`, `:189`). Kommentar `:285`: „Was für diesen Tag gilt, bleibt offen stehen;
    zugeklappt wäre es verschwiegen."
    `CardHead title="Zu diesem Tag"`, darin `<ul className="wk-hinweise">`: Polster links 18,
    Abstand 8, `max-width: 78ch`, 13px, Zeilenhöhe 1,5, `--text-2` (`globals.css:675`).
    Erst jeder Satz aus `hinweise_de`, dann - wenn Bilder fehlen - wörtlich:
    „Die fehlenden Bilder sind als Lücke zu sehen: der Ring bleibt dort offen, und im Band reißt
    die Linie ab. Überbrückt wird nichts, denn ein ruhiges Haus und ein blindes Messsystem sähen im
    Schema gleich aus."

  * **Block 7 - Methode „Was dieses Bild ist"**  (`Wiedergabe.tsx:303-318`)
    `<Methode title="Was dieses Bild ist" kurz="dasselbe Schema wie unter Anlage, aus der
    Minutenreihe nachgebaut · Leertaste spielt, Pfeile gehen Bild für Bild">`
    (`components/ui/Methode.tsx:47-58`; `<details>` ohne Zustand, „der Browser kann es ohne
    Skript, die Vorlesehilfe kennt es, und die Seitensuche findet seinen Text").
    Maße: `summary` Polster 14/18, `.methode-kurz` 12,5px `--text-3`, Pfeil 7×7 aus zwei 1,5px
    Rändern, `.methode-absatz` 13px/1,55 `--text-2` `max-width: 90ch`
    (`globals.css:726-735`); am Handy `summary` 15/16, Überschrift Sans 15px/600 ohne Versalien,
    Absätze 14,5px/1,5 (`handy.css:211-217`).
    Drei Absätze, wörtlich tragend:
      1. „Dasselbe Schema wie in der Ansicht `Jetzt`, nur aus der Minutenreihe nachgebaut. Es gibt
         genau eine Zusammensetzung des Bildes; die Wiedergabe stellt ihr die Eingänge von {hh:mm}
         hin, der Augenblick die von jetzt. Deshalb kann hier nichts stehen, was dort nicht
         stünde, und nichts fehlen, was dort steht."
      2. „Die Uhr zeigt den Tag als Ring: außen der Preis, dann die Sonne, dann was der Fahrplan
         für die Wärmepumpe vorsah, und innen, was sie tat. Wo der Umriss der Absicht steht und
         darunter nichts gefüllt ist, wollte der Fahrplan und die Maschine nicht. Das Band rechts
         zeigt dasselbe mit Achsen. Die Uhr lässt sich anfassen und drehen."
      3. „Tastatur: Leertaste spielt und hält, Pfeile gehen Bild für Bild, Pos1 und Ende springen
         an die Ränder. Bei {step_min} Minuten Schritt und {tempo}× läuft der Tag in
         {anzahl/tempo} Sekunden durch."

  * **Handy-Fassung insgesamt** (`handy.css`, Abfrage `@media (max-width: 720px)` ab `:107`;
    Kopfkommentar `:1-26`: die vier Entscheidungen - Bereiche unten, eine Zahl führt, Flächen statt
    Rahmen, Tabellen werden Listen; „Die Grenze ist die Breite allein"). Was diese Route betrifft:
      - `.card` randlos, Radius 16, Polster 16 (`:182`); Kartenüberschrift Sans 16,5px/600 statt
        Mono-Versalien (`:184`); `card-head-right` auf eigener Zeile, 13px, umbrechend (`:185`).
      - Kleine Schriften eine Stufe größer **innerhalb `.report-main`** (`:187-192`):
        10→11, 11→12, 12→13,5, 13→14,5. Das trifft hier die Kopfzahl („… von … Bildern"),
        „Schritt", den Zähler, `langerTag`, die Lade- und Fehlersätze und `wk-hinweise`.
      - Bühne: Radius 20/19, kein Schatten, plus der Wischhinweis (`:395-401`, oben wörtlich).
      - Methode: `:211-217` (siehe Block 7).
      - Der Seitenkicker ist am Handy ausgeblendet (`AreaNav.tsx:96`, `hidden md:block`).
      - Für `.wg-*` und `.uhr-*` selbst steht in `handy.css` **nichts**: gesucht nach
        `wg-`, `uhr-`, `wiedergabe` in `apps/web/src/styles/handy.css`: kein Treffer außer den
        vier `.anlage-*`-Zeilen `:398-401`. Die schmale Fassung von Uhr und Band kommt aus
        `globals.css:630` (Umbruch unter 860px, Reihenfolge Uhr, Legende, Band).


LUECKEN
-------

  [traegt-die-seite] **Das Anlagenschema je Bild fehlt ganz.** Die Vorlage stellt in die Bühne
    dieselbe Komponente wie die Anlagenseite, nur mit der Zeit des Bildes als Uhr
    (`Wiedergabe.tsx:226-240`, Begründung `:19-21` und `:28-30`). Die App zeigt an dieser Stelle
    zehn bis zwölf Textzeilen (`SystemSeiten.swift:252-285`) und lässt damit alles weg, was die
    Seite ausmacht: die vier Wasserkreise, das Glas des Puffers, die Rohrfarben als Temperatur, die
    Lichtpunkte als Leistung, Netz und Batterie samt Anteilen, den Ofen, das Warmwasser und drei
    der vier Pufferfühler. Das Bild ist in der App **schon gebaut**
    (`apps/ios/DuckCurveHome/Diagramme/Anlagenbild.swift:21-56`, `Anlagenbild(anlage:jetzt:)`) und
    wird von `AnlageSeite.swift:29-31` verwendet; die Wiedergabeseite ruft es nicht auf (gesucht
    nach `Anlagenbild` in `SystemSeiten.swift`: kein Treffer).

  [traegt-die-seite] **Die Tagesuhr fehlt ganz** (`Tagesuhr.tsx`, eingebunden
    `Wiedergabe.tsx:276`). Damit fehlt die einzige Ansicht, die „wo im Tag stehe ich und was war
    davor und danach" beantwortet, samt der drei Zustände je Stelle (Farbe / blasse Spur / nichts)
    und dem Ring als Griff. In der App gibt es nichts Vergleichbares (gesucht nach `addArc`,
    `SectorMark` in `apps/ios/DuckCurveHome`: kein Treffer; Ringe nur als Fortschrittskreis in
    `Anlagenbild.swift:424` `rotationEffect`).

  [traegt-die-seite] **Das Tagesband fehlt ganz** (`Tagesband.tsx`, eingebunden
    `Wiedergabe.tsx:278`). Fünf Flächen auf einer Zeitachse, der Spielkopf als Linie darin, Klick
    springt. Ohne es zeigt die App nur den einen Augenblick und nie den Tag - und ohne die beiden
    Nachbarzeilen „geplant"/„gelaufen" fehlt die Frage, was der Freigabekontakt wirklich auslöst.

  [spuerbar] **Die Vollständigkeit des Tages steht nirgends.** Kopfzeile wörtlich
    „{frames.length} von {erwartet} Bildern · {step_min}-Minuten-Schritt" (`Wiedergabe.tsx:197-201`)
    und, wenn Bilder fehlen, der feste Satz in „Zu diesem Tag" (`:293-297`). Die App nennt in der
    Methode nur „Aufgelöst in N Minuten, M Augenblicke." (`SystemSeiten.swift:186-190`);
    `erwartet` wird nicht gelesen (gesucht nach `.erwartet` in `apps/ios/DuckCurveHome` und
    `apps/ios/DuckCurveKit/Sources`: Treffer nur im Modell selbst, `Schema.swift:1380, 1394` -
    kein lesender Zugriff. Das Feld steht da, `Schema.swift:1355`).

  [spuerbar] **Die Karte „Zu diesem Tag" fehlt als eigener Abschnitt.** Die Vorlage setzt
    `hinweise_de` **offen** auf die Seite, weil zugeklappt verschwiegen wäre (`:285`); die App
    steckt genau diese Sätze in die zugeklappte Methode (`SystemSeiten.swift:186-190`).

  [spuerbar] **Die Schrittweite 1/5/15 min fehlt.** Drei Knöpfe, die den Tag neu holen
    (`Wiedergabe.tsx:38, 214-219, 99`). Der Kern kann es bereits
    (`Api.swift:263`, `schrittMin: Int = 5`), die Seite ruft ohne Argument
    (`SystemSeiten.swift:324`) - eine Minutenauflösung für einen einzelnen Vorfall gibt es in der
    App nicht.

  [spuerbar] **Die Spielleiste ist auf einen Knopf zusammengeschrumpft.** Es fehlen die Uhrzeit des
    Bildes in der Leiste (in der App steht sie nur als Kartentitel, `:180`), der Bildzähler
    „{i+1}/{anzahl}" (`:257-259`) und die Regel „ein Griff an den Schieber hält an" (`:151-158`) -
    die App spielt beim Schieben weiter, weil `spiele()` (`:307-319`) `stelle` unabhängig vom
    Schieber weiterzählt.

  [spuerbar] **Der Abspieler läuft im Kreis.** Die Vorlage hält am letzten Bild an und stellt den
    Knopf zurück, mit Begründung (`Wiedergabe.tsx:128-142`: „ein Tag, der unbemerkt in den nächsten
    Durchlauf rutscht, lässt einen zweimal dasselbe für zwei Tage halten"). Die App setzt
    `stelle = 0` und läuft endlos (`SystemSeiten.swift:313-317`).

  [klein] **Die Tempowahl 2×/6×/12×/24× fehlt**, dazu der Satz in der Methode „Bei N Minuten
    Schritt und T× läuft der Tag in S Sekunden durch" (`Wiedergabe.tsx:37, 260-270, 313-316`). Die
    App spielt fest mit vier Bildern je Sekunde (250 ms, `SystemSeiten.swift:310`).

  [klein] **Das Datumsfeld fehlt**, mit dem man auf jeden Tag bis heute springt (`:209`,
    `max={heute()}`). Die App blättert nur Tag für Tag (`:202-212`).

  [klein] **Der Tag steht kurz statt lang.** Vorlage `langerTag(tag)` → „Samstag, 7. November 2026"
    (`Wiedergabe.tsx:213`, `lib/day.ts:49-52`); App `Tag.kurz(tag)` → „Sa, 7.11."
    (`SystemSeiten.swift:206`, `Formate/Tag.swift:93-98`). `Tag.lang` gibt es im Kern
    (`Tag.swift:86-91`).

  [klein] **Ein Tag ohne Bilder sagt es nicht.** Vorlage: `hinweise_de?.[0]` als Satz, sobald die
    Antwort da und `frames` leer ist (`Wiedergabe.tsx:224`). In der App greift die Bedingung
    `if let w = wiedergabe, !w.frames.isEmpty` (`SystemSeiten.swift:179`) nicht, und es bleibt
    dauerhaft „Wird geholt …" stehen (`:191-193`).

  [klein] **Ein Variablenname steht als Wort auf dem Schirm:** `Zeile(wort: "w.geplantWp", …)` mit
    „freigegeben"/„nicht freigegeben" (`SystemSeiten.swift:280`). In der Vorlage heißt diese Größe
    „geplant" (Bandzeile, `Tagesband.tsx:70`), „Wärmepumpe geplant" (Legende, `Tagesuhr.tsx:301`),
    „· geplant"/„· nicht geplant" (Uhrmitte, `Tagesuhr.tsx:282`) und „der Fahrplan wollte
    anfordern" (Fahne, `Tagesband.tsx:203`).

  [klein] **Der Methodentext ist ein anderer.** Vorlage: Titel „Was dieses Bild ist", eine
    `kurz`-Zeile, die auch zugeklappt steht („dasselbe Schema wie unter Anlage, aus der
    Minutenreihe nachgebaut · Leertaste spielt, Pfeile gehen Bild für Bild"), und drei Absätze
    (`Wiedergabe.tsx:303-317`). Die App hat Titel „Wie das gerechnet ist", kein `kurz` und nur die
    Dienstsätze (`SystemSeiten.swift:186-190`; `Methode` kann `kurz` und `titel`,
    `Bericht.swift:343-353`).

  [klein] **Der Wischhinweis unter der Bühne fehlt.** `handy.css:400` setzt wörtlich „zur Seite
    wischen: Strom, Erzeuger, Speicher, Verbraucher  ›" unter die rollende Zeichnung, „statt dass
    die rechte Hälfte unbemerkt fehlt" (`:396-397`). Gesucht nach `wischen` in
    `apps/ios/DuckCurveHome`: kein Treffer - `Anlagenbild.swift:37-41` rollt waagerecht und zeigt
    nur die Systemleiste.

  [klein] **Der Seitenkicker „Ein Tag am Anlagenschema · zum Durchfahren" fehlt** (`page.tsx:10`,
    gesetzt als `kicker` in `AreaNav.tsx:96`, nur ab 768px sichtbar). In der App gibt es ihn
    nirgends (gesucht nach `Durchfahren` in `apps/ios`: kein Treffer); betrifft die regulär breite
    Darstellung auf dem iPad.

Summe: 15 Punkte, davon 3 `traegt-die-seite`, 5 `spuerbar`, 7 `klein`.


KERN: SCHON DA (nachgesehen, nicht geraten)
-------------------------------------------

* Abfrage samt Schrittweite: `anlageWiedergabe(tag:schrittMin:)`
  (`DuckCurveKit/Netz/Api.swift:262-265`), Vorgabe 5.
* Modell vollständig: `AnlageReplayOut` mit `day, stepMin, von, bis, erwartet, frames,
  preisCtKwh, geplantWp, geplantOfen, hinweiseDe` (`DuckCurveKit/Modelle/Schema.swift:1350-1399`).
  `AnlageOut`-Teile (Strom, Wärmepumpe, Ofen, Speicher, Heizkreis, Warmwasser) kennt
  `Anlagenbild.swift:60-78` bereits.
* Sprung aus der Jahreskarte **fertig**: `Wiedergabeziel` mit Prüfung, `weg`, `ausWeg` und
  `bildstelle(stunde:zeitpunkte:)` (`DuckCurveKit/Zustand/Jahreskarte.swift:474-531`, Prüfungen
  `Tests/DuckCurveKitTests/JahreskarteTests.swift:408-460`), eingehängt in
  `Seitenwahl.swift:61-65`, erzeugt in `Diagramme/Jahresflaeche.swift:156-181`, benutzt in
  `Seiten/Energie/JahreskarteSeite.swift:168`, angewandt in `SystemSeiten.swift:299-303`.
  Diese Lücke aus früheren Messungen ist geschlossen.
* Anlagenschema als Ansicht: `Anlagenbild(anlage:jetzt:)` (`Diagramme/Anlagenbild.swift:21-56`),
  Rohrgeometrie `Diagramme/Anlagenrohre.swift`, Rechnungen im Kern
  `DuckCurveKit/Zustand/Anlagenschema.swift` (`istAn`, `rohrStaerke`, `punktzahl`, `rohrDauer`,
  `mischung`, `warmwasserStatus`, `erzeugerSatz` - aufgerufen in `Anlagenbild.swift:68-78, 453,
  501` und `AnlageSeite.swift:29`). Es liest `accessibilityReduceMotion` selbst
  (`Anlagenbild.swift:26`), also ist `ruhig` bereits abgedeckt.
* Zeit und Tag: `Zeit.ausIso`, `Zeit.iso` (`Formate/Zeit.swift:28, 114`), `Kalender.haus`
  (benutzt `Jahreskarte.swift:528`), `Tag.istTag/plus/lang/kurz/zeitraum`
  (`Formate/Tag.swift:26, 50, 87, 94, 79`), `Formate.hhmm(_:)` und `hhmm(iso:)`
  (`Formate/Formate.swift:141, 148`), `Formate.kw/celsius/prozent/zahl/ct`
  (`:62, 104, 98, 44, 110`).
* Farben stimmen schon überein: `Marken.pv = amber 0xF2A900`, `Marken.waermepumpe 0xE0966B`,
  `Marken.ofen 0xB5651D`, `Marken.preis = mist 0x7FA3B3`, `Marken.deep 0x082431`
  (`DuckCurveKit/Gestalt/Marken.swift:17-20, 50, 58, 70, 92`) - dieselben Werte wie
  `charts/palette.ts:33-82`. Marken-Maße: `Marken.radius1/2/3`, Flächen `flaeche1/2/3`
  (`Marken.swift:28-31`).
* Oberflächenbausteine: `Karte(kicker:titel:beiwerk:)` mit Handy-/iPad-Fassung
  (`Gestalt/Karte.swift:15-104`), `Zeile` (`:360-383`), `Leer` (`:390-404`),
  `Stoerung` (`:410-436`), `Seite` (`App/Seitenwahl.swift:141-175`),
  `Methode(_:kurz:titel:)` (`Seiten/Bericht.swift:334-...`), Schriften
  `Schrift.karte 15 / klein 13 / winzig 11,5 / zahlKlein 12,5 / achse 10,5`
  (`Gestalt/Typografie.swift:42-46, 70, 101`).
* Vorbilder für die beiden Diagramme: `Diagramme/Fahrplanzeichnung.swift` - mehrere Flächen über
  **einer** Zeitachse, jede mit eigenem Maßstab im Titel (`:13-16, 25-40`), Bänder als
  `RectangleMark` (`:193-200, 306-311, 353-365`), `RuleMark` als „jetzt"-Linie (`:138-143`),
  `chartXSelection` (`:152`). `Diagramme/Tageskurve.swift:287-401` zeigt Fadenkreuz per
  `chartOverlay` + `DragGesture`. `Diagramme/Jahresflaeche.swift:76-148` zeigt eigenes Zeichnen im
  `Canvas` mit eigener Treffersuche („Daneben gegriffen heißt: nichts zeigen, nicht das
  Nächstbeste", `:138`). `DuckCurveKit/Gestalt/SvgPfad.swift:279-280` erklärt, warum SVG-Bögen im
  Projekt zerlegt werden.


ES FEHLT
--------

1. **`Wiedergabebild` in `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Wiedergabebild.swift`**
   - gebaut wie `Fahrplanbild` (`Zustand/Fahrplanbild.swift:17-230`, `static func baue(_:)`).
   Darin, aus `AnlageReplayOut` einmal gerechnet: `zeitpunkte: [Date]`, `von`/`bis` als `Date`,
   `schritt: TimeInterval`, `preisspanne: ClosedRange<Double>?`, `sonneMax: Double`,
   `hatOfen: Bool`, `hatAbsicht: Bool`, `vollstaendig: Bool` (`frames.count >= erwartet`), sowie
   die Reihen für das Band (`sonne`, `netz`, `preis` als `[(Date, Double?)]`).
   Prüfbar, weil Geometrie und Rechnung getrennt bleiben sollen (`tagesuhr.ts:3-6`).

2. **`Lauf` und `laeufe(_:zeiten:schritt:)`** als `public` im Kern (Vorlage `tagesuhr.ts:63-83`):
   gleiche Werte zu Läufen zusammenfassen, Lauf bei einem Zeitsprung ≥ halbem Schritt abbrechen,
   `nil` ergibt keinen Lauf, jeder Lauf reicht einen Schritt über seinen letzten Zeitstempel
   hinaus. Gesucht nach `func laeufe` / `struct Lauf` in `apps/ios/DuckCurveKit/Sources`: kein
   Treffer. Wird von Uhr **und** Band gebraucht, deshalb genau einmal.

3. **`stufe(wert:min:max:n:)`** (Vorlage `tagesuhr.ts:93-97`), fünf Helligkeitsstufen, bei Spanne
   null die mittlere. `Marken` müsste dazu die Stufenliste `[0,16 0,32 0,52 0,76 1]` und die
   Spurfarbe `rgba(255,255,255,.055)` bekommen. Beides ist dort heute nicht: `Marken.swift` hat
   `linie1` (0,10), `linie2` (0,17) und `rasterlinie`, aber keine Stufenliste und keine Farbe mit
   Deckung 0,055 (die beiden `0.055` in `Marken.swift:374, 389` sind der sRGB-Exponent der
   Kontrastrechnung, keine Farbe).

4. **Tagesuhr-Geometrie** als eigene, geprüfte Datei (Vorlage `tagesuhr.ts:16-124`):
   `anteil(t, von, bis)`, `punkt(mitte, r, anteil)` (0 oben, im Uhrzeigersinn),
   `ringstueck(...) -> Path`, `anteilAus(dx, dy)`, `indexBei(anteil, zeiten, von, bis)`.
   **Der Winkel ist der Anteil am Tag, nicht die Uhrzeit** - sonst bleibt an den
   Umstellungstagen eine Stunde offen oder liegt doppelt.

5. **Worte und Texte** als `Wiedergabeworte` (Vorbild `Zustand/Fahrplanworte.swift`): die
   Legendentexte der Uhr, die Flächennamen des Bands („kW", „ct/kWh", „geplant", „geplant ?",
   „gelaufen", „Ofen"), die Fahnensätze zur Absicht, der feste Lückensatz der Karte „Zu diesem
   Tag" und die drei Methodenabsätze mit ihren Einsetzstellen (`step_min`, `tempo`,
   `anzahl/tempo`).

6. **Tempo und Schrittweite als Kernkonstanten**: `tempi = [2, 6, 12, 24]` (Bilder je Sekunde,
   Vorgabe 12) und `schritte = [1, 5, 15]`, dazu die Rechnung „Sekunden = anzahl / tempo" für den
   Methodensatz.


BAUPLAN
-------

In der Reihenfolge der Vorlage, Karte für Karte:

1. **Neu: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Wiedergabebild.swift`** - `baue`,
   `Lauf`/`laeufe`, `stufe`, Bandreihen, `vollstaendig`, `hatOfen`, `hatAbsicht`,
   `preisspanne`, `sonneMax`. Dazu Prüfungen in
   `apps/ios/DuckCurveKit/Tests/DuckCurveKitTests/` nach dem Muster von `JahreskarteTests.swift`:
   Lauf über eine Lücke bricht ab; Lauf endet einen Schritt nach dem letzten Bild; Stufe bei
   gleicher Spanne.
2. **Neu: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Tagesuhrgeometrie.swift`** -
   `anteil`, `punkt`, `ringstueck`, `anteilAus`, `indexBei`, mit Prüfungen (voller Ring, Ring über
   einen 25-Stunden-Tag, Treffersuche am Rand der Zone 70…178).
3. **Neu: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Wiedergabeworte.swift`** - alle
   Texte aus „ES FEHLT 5", dazu `tempi`/`schritte`.
4. **Ändern: `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift`** - Stufenliste
   und Spurfarbe der Uhr, falls sie nicht in `Wiedergabebild` liegen sollen.
5. **Neu: `apps/ios/DuckCurveHome/Diagramme/Tagesuhrbild.swift`** - `Canvas` nach dem Vorbild
   `Jahresflaeche.swift:76-148`: Spuren, fünf Ringe (Preis 144-158, Sonne 126-141, geplant
   114-123 als Umriss, gelaufen 98-111, Ofen 84-95), Stundenstriche 161→164/167 mit 0/6/12/18 auf
   175, Zeiger mit dunklem Hof, Mitte mit Uhrzeit (38pt, Gewicht 200) und zwei Wertzeilen,
   `DragGesture(minimumDistance: 0)` mit Trefferzone 70…178 und `indexBei`, Legende darunter als
   eigene Reihe (Marke 10×10, Radius 2, Umriss für die Absicht).
6. **Neu: `apps/ios/DuckCurveHome/Diagramme/Tagesbandbild.swift`** - fünf gestapelte `Chart`
   nach dem Muster `Fahrplanzeichnung.flaeche(...)` (`Fahrplanzeichnung.swift:25-40`): Sonne/Netz
   (Höhe 58), Preis als Treppe (30), geplant (8, blass mit Rand), gelaufen (13), Ofen (13, nur
   wenn vorhanden), gemeinsame Zeitachse nur unter der letzten Fläche, Spielkopf als `RuleMark` in
   **jeder** Fläche, Tippen setzt den Index auf das nächste Bild (nicht interpolieren).
7. **Ändern: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`, `WiedergabeSeite`
   (155-334)**, von oben nach unten:
   a) `tagwahl`: „‹", Datumswahl (`DatePicker`, Obergrenze `haus.heute`), „›", `Tag.lang(tag)`,
      rechts „Schritt" mit drei Knöpfen 1/5/15 → `@State schritt`, der in `lade()` als
      `schrittMin:` mitgeht und den Tag neu holt.
   b) `Karte(kicker: "Wiedergabe", titel: zeitpunkt(w), beiwerk: …)` mit
      „{frames.count} von {erwartet} Bildern · {stepMin}-Minuten-Schritt" im `beiwerk`.
   c) in der Karte: `Anlagenbild(anlage: bild, jetzt: Zeit.ausIso(bild.at) ?? haus.jetzt)` -
      **die Zeit des Bildes, nicht `haus.jetzt`**, sonst steht am Schema „läuft seit 7 Stunden"
      (`Wiedergabe.tsx:28-30`). Darunter der Wischhinweis aus `handy.css:400`, in schmaler Breite.
   d) Transportleiste: Knopf 38×38 Kapsel in `Farbe.amber`/`Farbe.deep`, `Formate.hhmm` des
      Bildes in Mono 15, `Slider`, Zähler „i+1/anzahl", vier Tempoknöpfe; jedes Ziehen am Schieber
      setzt `laeuftAb = false`.
   e) `spiele()`: Takt `1 / tempo` Sekunden, am letzten Bild **anhalten** statt auf 0 springen.
   f) `Tagesuhrbild` und `Tagesbandbild` nebeneinander in regulärer Breite, in schmaler Breite
      untereinander in der Reihenfolge Uhr, Legende, Band (`globals.css:630`).
   g) eigene `Karte(kicker: "Zu diesem Tag")` mit `hinweiseDe` als Liste **offen**, plus dem
      Lückensatz, wenn `frames.count < erwartet`.
   h) `Methode(…, kurz: …, titel: "Was dieses Bild ist")` mit den drei Absätzen aus
      `Wiedergabeworte`.
   i) leerer Tag: wenn `wiedergabe != nil`, aber `frames.isEmpty`, `Leer(satz: hinweiseDe.first)`
      statt „Wird geholt …".
   j) „w.geplantWp" ersetzen durch „geplant" mit „geplant"/„nicht geplant".


WAS SCHWIERIG WIRD
------------------

* **Der Ring hat in Swift Charts kein Gegenstück.** `SectorMark` zeichnet Kuchenstücke um einen
  Mittelpunkt, nicht fünf gestufte Ringe mit Lücken, Spuren und Umrissen; gesucht nach
  `SectorMark` in `apps/ios/DuckCurveHome`: kein Treffer. Der Weg ist im Projekt entschieden:
  selbst zeichnen im `Canvas` und mit eigener Rechnung treffen, wie
  `Diagramme/Jahresflaeche.swift:76-148` (Zeichnen `male`, Treffersuche `zelle(an:)`, „dieselbe
  Rechnung wie beim Zeichnen", `:134-135`). Der Ringbogen muss als `Path` aus zwei Bögen und zwei
  Linien gebaut werden; `SvgPfad.swift:279-280` nennt den Grund, warum `Path.addArc` allein nicht
  reicht.
* **Fünf Flächen mit einer Zeitachse.** Swift Charts kennt keine mehrfachen Gitter wie ECharts.
  Der Weg steht in `Fahrplanzeichnung.swift:13-16`: „Acht Flächen, nicht eine mit acht Achsen …
  Sie teilen die Zeitachse, und jede Fläche trägt ihren Maßstab im Titel." Übernommen wird dort
  auch, dass alle Flächen dieselbe `xScale`-Spanne gesetzt bekommen, sonst fallen sie auseinander
  (derselbe Fehler ist im Dashboard schon passiert, `:15-16`).
* **Kein verbundener Achsenzeiger über mehrere Flächen.** ECharts verbindet die Flächen mit
  `axisPointer: { link: [{ xAxisIndex: "all" }] }` (`Tagesband.tsx:169`). In SwiftUI muss der
  Spielkopf in jeder Fläche als eigener `RuleMark` stehen (so macht es
  `Fahrplanzeichnung.swift:138-143`) und `chartXSelection` (`:152`) bzw. ein `chartOverlay` mit
  `DragGesture` (`Tageskurve.swift:287-401`) die Stelle setzen.
* **Keine Fahne wie die ECharts-Fahne.** Der Inhalt der Vorlagenfahne (`Tagesband.tsx:176-207`) ist
  vier bis fünf Zeilen mit Farbmarken. Im Projekt ist dafür das „Blättchen" der Jahresfläche das
  Vorbild (`Jahresflaeche.swift:155-181`: feste Breite 184, `Farbe.flaeche3`, Rand `linie2`, bleibt
  im Bild).
* **Die Tastaturbedienung der Vorlage hat auf dem Telefon kein Gegenstück.** Leertaste, Pfeile,
  Pos1/Ende (`Wiedergabe.tsx:160-185`) fallen weg; was bleiben muss, ist der zweite Teil derselben
  Entscheidung - der Schieber ist das Bedienelement für Tastatur und Vorleseprogramme
  (`Tagesuhr.tsx:31-33`), also braucht der `Slider` einen `accessibilityValue` mit der Uhrzeit
  (Vorlage `aria-valuetext`, `Wiedergabe.tsx:255`), und der Ring bleibt ein zusätzlicher Griff,
  kein Ersatz.
* **Die 25-Stunden-Tage.** `Tag.zeitraum(_:)` (`Formate/Tag.swift:79-85`) liefert von/bis aus
  `Kalender.haus`; die Uhr darf trotzdem nicht aus der Uhrzeit, sondern aus dem Anteil zwischen
  `w.von` und `w.bis` rechnen (`tagesuhr.ts:8-10`). Dieselbe Falle hat `Jahresraster` schon
  einmal gehabt (vgl. `Jahreskarte.swift:514-521` zur Annahme eines dichten Bandes).
