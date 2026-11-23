========================= messen:waermepumpe   Aufwand: mittel

IST: Was die App-Seite heute von oben nach unten zeigt
(`apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift:10-179`)

1. `Seite { … }` ohne Zeitraumleiste (`:19`) - Rand 16, Abstand 14 zwischen den Karten
   (`apps/ios/DuckCurveHome/App/Seitenwahl.swift:141-173`).
2. Bei Fehler oben eine `Stoerung` mit Knopf „Erneut" (`:20-22`,
   `apps/ios/DuckCurveHome/Gestalt/Karte.swift:410-436`).
3. **Karte mit der Zeichnung zuerst** (`:28-36`): darin `Text(Wpbild.satz(w))` in
   `Schrift.klein` = 13 pt (`:31`, `apps/ios/DuckCurveHome/Gestalt/Typografie.swift:45`),
   darunter `Waermepumpenbild(wp:lage:)`, Lage `.hoch` bei
   `horizontalSizeClass == .compact`, sonst `.breit` (`:34`).
4. `Kachelfeld` mit **sechs** Kacheln und Kicker `w.zustandDe` (`:37`, Kacheln in
   `:134-159`): Leistung (`Farbe.waermepumpe`, dazu „am Zähler"/„über den Bus"),
   Wärmeleistung (2 Stellen), Arbeitszahl (2 Stellen), draußen, Vorlauf,
   Verdichter (dazu „läuft"/„aus").
5. Wenn `busStummDe` da ist: `Karte { Leer(satz: "Der Bus schweigt.", dazu: busStumm) }`
   (`:38-40`).
6. `Karte(kicker: "Kältekreis")` mit sieben `Zeile` (`:42-69`): Verdampfer, Sauggas,
   Heißgas, Flüssig, Verdichter Hz, Verdichterstrom (nur wenn Feld da), Lüfter 1/min.
7. `Karte(kicker: "Wasserseite")` (`:70-96`): Vorlauf, Rücklauf, Sollvorlauf, Spreizung,
   Durchfluss, Speicherfühler, Puffer 1…n mit `m.hinweis(jetzt:)`, Pumpe.
8. `Karte(kicker: "Regler und Kontakte")` (`:97-124`): Heizanforderung, Raumsollwert,
   Umschaltventil, Heizstab, Zusatzheizung (`Farbe.achtung` über 0,05 kW), Kreis,
   Einspeisung.
9. `Methode(w.hinweiseDe, titel: "Hinweise des Busses")` - zugeklappt (`:125`,
   `apps/ios/DuckCurveHome/Seiten/Bericht.swift:334-397`).
10. Sonst `Karte { Leer(satz: "Wird geholt …") }` (`:126-128`).
11. Nachladen: `lade()` beim Erscheinen, dann alle 10 s stumpf in einer Schleife
    (`:130-131`, `:172-178`) - ohne Sichtbarkeitsprüfung.

Die Zeichnung selbst ist vollständig und maßgleich: `apps/ios/DuckCurveHome/Bausteine/
Waermepumpenbild.swift:24-299` auf dem Plan in `apps/ios/DuckCurveKit/Sources/
DuckCurveKit/Haus/Waermepumpenbild.swift:66-112`.

VORLAGE:

  * **Hülle und Seitenkicker** (`apps/web/src/app/waerme/waermepumpe/page.tsx:1-12`)
    `AreaShell kicker="Außengerät · Innengerät · Speicher"` (`:9`), Titel der Seite
    „Wärmepumpe · Duck Curve Home" (`:6`), `dynamic = "force-dynamic"` (`:4`).
    Der Kicker steht rechts in der Reiterzeile (`apps/web/src/components/layout/
    AreaShell.tsx:26`).
    DATEN: keine.
    Gesucht nach „Außengerät · Innengerät" in `apps/ios`: kein Treffer.

  * **Kopf: der Satz und die Standzeile** (`apps/web/src/components/waermepumpe/
    Waermepumpe.tsx:66-79`)
    `.wp-kopf` Spalte, Abstand 4 (`apps/web/src/styles/globals.css:788`).
    `.wp-satz`: **22 px**, Zeilenhöhe 1,3, `--text-1`, kein Rahmen, keine Karte
    (`globals.css:789`); am Handy **19 px** (`apps/web/src/styles/handy.css:234`).
    Text wörtlich aus `satz(daten)` (`apps/web/src/components/waermepumpe/bild.ts:97-105`):
    - steht sie nicht: „Die Wärmepumpe {zustand_de}."
    - läuft sie, mit Wärme und Strom: „Die Wärmepumpe {zustand_de}: rund {x} kW Wärme aus
      {y} kW Strom." (je eine Nachkommastelle)
    - läuft sie, nur Strom: „Die Wärmepumpe {zustand_de} und nimmt {y} kW auf."
    `.wp-stand`: 13 px, `--text-3` (`globals.css:790`); eine Zeile, mit „ · " verkettet
    (`Waermepumpe.tsx:68-78`):
    „Stand {hh:mm}" (`apps/web/src/lib/format/index.ts:42-45`)
    + „ · Heizanforderung an|aus" (nur wenn `heizanforderung != null`)
    + „ · Raum-Sollwert {x} °C" + „ · Umschaltventil Stellung {n}"
    + „ · Heizstab meldet {n}" + „ · Verdichter {x} A"
    + „ · {Fehlertext}", wenn gerade ein Abruf fehlschlug.
    Der Kommentar `:70-71` begründet die ersten beiden: „Was der Regler vorgibt, soweit er
    es sendet".
    DATEN: `GET /waermepumpe` (`apps/web/src/lib/api/client.ts:82`), Felder `now`,
    `zustand_de`, `heizanforderung`, `raum_soll_c.value`, `ventil_code`, `heizstab_code`,
    `verdichter_a.value`, `waermeleistung_kw`, `leistung_zaehler_kw`, `leistung_bus_kw`
    (`apps/web/src/lib/api/types.ts:7598-7656`).

  * **Absatz: der Heizstab läuft mit** (`Waermepumpe.tsx:81-85`)
    Nur wenn `zusatz_kw != null`. `.wp-stumm` (`globals.css:792`): Rand 1 px
    `--amber` zu 55 %, Fläche `--amber` zu 9 %, Radius 12, Polster 12/14, 14 px,
    Zeilenhöhe 1,5, `--text-1`, Breite höchstens 760 px, `role="status"`.
    Wörtlich: **„Neben dem Verdichter laufen rund {x} kW."** (fett) + „Der Zähler misst
    deutlich mehr, als die Maschine für sich meldet; vermutlich ist der elektrische
    Heizstab an. Die Arbeitszahl unten enthält ihn."
    DATEN: `zusatz_kw`.

  * **Absatz: der Bus schweigt** (`Waermepumpe.tsx:87-91`)
    Nur wenn `bus_stumm_de` gesetzt. Dieselbe `.wp-stumm`-Fläche, `role="status"`.
    Wörtlich: **„Vom Bus der Wärmepumpe ist kein Wert da."** (fett) + der Satz des
    Dienstes.
    DATEN: `bus_stumm_de`.

  * **Vier Kennzahlen** (`Waermepumpe.tsx:93-98`)
    `kpi-grid kpi-handy` mit `--cols: 4`. An der Wand: Raster mit Mindestbreite
    `clamp(150px, 100%/4 - 16px, 260px)`, Abstand 16 (`globals.css:107`). Je Kachel
    `Stat` (`apps/web/src/components/ui/Stat.tsx:4-18`): Karte mit Polster 14/18,
    Abstand 6; Kicker 11 px gesperrt (`globals.css:57-64`); Zahl 26 px Mono,
    `leading-none`, `tracking -.02em`; Einheit 13 px `--text-3` in Sans;
    Hinweiszeile 12 px, Zeilenhöhe 1,35, höchstens zwei Zeilen.
    Die vier, in dieser Reihenfolge, mit diesen Worten:
    1. „Wärmeleistung" · `zahl(waermeleistung_kw)` **1 Stelle** · kW ·
       Ton `amber` (= `--amber`), sonst `muted` · Hinweis „Durchfluss mal Spreizung",
       wenn `laeuft`, sonst „nur bei laufender Maschine".
    2. `strom.quelle ? "Strom, {quelle}" : "Strom"` - Quelle ist wörtlich „Zähler"
       oder „laut Maschine" (`bild.ts:90-94`) · `zahl(strom.kw, 2)` **2 Stellen** · kW ·
       kein Hinweis.
    3. „Arbeitszahl" · `zahl(arbeitszahl)` **1 Stelle** · ohne Einheit ·
       Hinweis „Wärme je Strom, im Augenblick".
    4. „Spreizung" · `zahl(spreizung_k)` **1 Stelle** · K · Hinweis
       „Vorlauf minus Rücklauf".
    Fehlender Wert ist „?" und nicht „-" oder „0" (`bild.ts:82-85`: „ein fehlender Wert
    ist keine Null"), und der Ton fällt dann auf `muted` = `--text-3`.
    Der Kommentar `Waermepumpe.tsx:23-25` sagt, warum es genau diese vier sind: „Die vier
    beantworten, was man von einer Wärmepumpe wissen will: wie viel Wärme, aus wie viel
    Strom, mit welcher Arbeitszahl, bei welcher Spreizung."
    Handy-Fassung (`handy.css:195-207`): **keine sechs Rahmen, eine Fläche** -
    `--surface-2`, Radius 16, Polster 4/16, zwei Spalten, Trennung durch Haarlinien
    `--line-1`; die **erste** Kachel über die ganze Breite mit **48 px** Zahl
    (Einheit 18 px, Abstand 8) und 14,5 px Hinweis in `--text-2`; die übrigen 25 px
    (Einheit 13,5 px), Kicker 11 px; eine allein gebliebene letzte Kachel nimmt die
    ganze Zeile.
    DATEN: `waermeleistung_kw`, `arbeitszahl`, `spreizung_k`, `laeuft`,
    `leistung_zaehler_kw`/`leistung_bus_kw` über `aufnahme()`.

  * **Die Zeichnung, in einer Karte, NACH den Kennzahlen**
    (`Waermepumpe.tsx:100-102`)
    `.card .wp-buehne`: Polster 16 (`globals.css:791`), am Handy 10
    (`handy.css:250`). Karte an der Wand: `--surface-2`, Haarlinie `--line-1`,
    Radius 3 (`globals.css:67-77`); am Handy randlos, Radius 16 (`handy.css:182`).
    `.wp-bild`: Breite 100 %, Höhe automatisch; in der hohen Lage
    **höchstens 420 px breit und mittig** (`globals.css:793-794`).
    Lage: `handy ? "hoch" : "breit"` aus `useIsMobile()` - wahr unter **720 px Breite
    ODER 560 px Höhe** (`apps/web/src/lib/useIsMobile.ts:6,15,18-27`).
    `ruhig` kommt aus `prefers-reduced-motion` und hält Fluss und Drehung an
    (`Waermepumpe.tsx:45`, `globals.css:800-804`).
    Inhalt (`apps/web/src/components/waermepumpe/Bild.tsx:134-157`): erst die vier
    Leitungen, dann Außen-, Innengerät, Speicher, dann die vier Leitungsschilder;
    `aria-label` „Die Wärmepumpe {zustand_de}. Vorlauf … Grad, Rücklauf … Grad,
    Durchfluss … Liter je Minute." Rohrfarbe aus **`m.value`** (nicht aus der Güte,
    `Bild.tsx:142-147`), Deckkraft 0,95 fließend / 0,4 stehend, weißer Laufstrich
    `stroke-dasharray: 3 15`, 1,1 s (`globals.css:800-801`).
    Maße: Blöcke 330/300/250 × 250, Tank x133 y40 64×190, Schild 124×38,
    Fühler-WP-Höhe 0,0625, Pläne „breit" 1120×450 und „hoch" 380×1000
    (`bild.ts:16-73`, `Bild.tsx:29`).
    Das Glas ist **dieselbe Komponente wie überall** (`apps/web/src/components/puffer/
    Glas.tsx:33-91`), eingesetzt mit `werte="links"`, Schrift 13, `gedimmt`, wenn nicht
    alle vier Fühler tragen (`Bild.tsx:129`): Radius `breite/2` (= 32, also eine
    Kapsel), senkrechter Temperaturverlauf nur bei **allen vier** Fühlern
    (`apps/web/src/components/puffer/glas.ts:26,30-33`), darüber ein waagerechter
    Glanzverlauf (`Glas.tsx:46-51`), ein wandernder Lichtschein über 14 s
    (`Glas.tsx:65-69`), äußere Linie `rgba(255,255,255,.28)` 1,2 px und eine innere
    `rgba(255,255,255,.08)` (`Glas.tsx:72-73`), Fühlerhöhen
    **0,125 / 0,375 / 0,625 / 0,875** (`glas.ts:21`), je Fühler ein Strich und eine
    ganze Gradzahl in Mono mit engem Gradzeichen (`Glas.tsx:81-85`, `glas.ts:35-37`).
    Farbskala: 10 → #1a3a52, 25 → #1f4c66, 35 → #7fa3b3, 45 → #ffd778, 55 → #f2a900,
    65 → #e0533d, dazwischen gemischt; ohne Wert #7fa3b3
    (`apps/web/src/components/anlage/schema.ts:25-52`).
    DATEN: dieselbe Antwort `/waermepumpe`, alle `Measurement`-Felder.

  * **Tabelle: was der Regler meldet** (`Waermepumpe.tsx:104`,
    `apps/web/src/components/waermepumpe/Kennzahlen.tsx:1-98`)
    Eine eigene Karte `.card .kl-karte` (`globals.css:900`: Spalte, Abstand 10,
    Polster 16), Überschrift `.kl-titel` 15 px halbfett: **„Was der Regler meldet,
    letzte {tage} Tage"** (`:46`, `globals.css:901`).
    Darunter `.kl-klein` (13 px, Zeilenhöhe 1,5, `--text-3`, höchstens 760 px,
    `globals.css:898`) wörtlich: „Der Regler sendet eine Kennzahl, kein Wort. Bestätigt
    sind 0 (Bereitschaft) und 2 (Heizen); für die übrigen steht hier, was die Maschine
    unter der Zahl getan hat."
    Dann `.kl-rollt` (waagerecht rollbar) mit `.kl-tabelle`, **Mindestbreite 940 px**
    (`globals.css:912-913`): 14 px, Kopfzellen 12 px `--text-3` linksbündig mit
    Unterlinie, Zellen Polster 7/10 mit Unterlinie `--line-1`
    (`globals.css:907-909`), Mono in allen Zellen.
    **Dreizehn Spalten**, wörtlich (`Kennzahlen.tsx:53-67`): Kennzahl · Minuten ·
    davon Lauf · Vorlauf · Sollwert · Speicher oben · Speicher Mitte unten ·
    Zähler über Maschine · Heizanforderung · Kennung 1b45 · Ventil auf 1 ·
    Heizstab gemeldet · angefordert.
    Je Zeile (`:70-88`): `code`, und wenn `code === kreis_code` der Zusatz **„ · jetzt"**
    und die ganze Zeile in `--amber` (`globals.css:911`); `minuten`; `lauf_min`;
    „{x} °C" (1 Stelle); „{x} °C"; „{±x} K/h" **mit echtem Plus bzw. Minuszeichen U+2212**
    (`:17`); „{±x} K/h"; „{±x} kW"; vier Anteile als ganze Prozent „{n} %" (`:19`).
    Fehlt ein Wert: „?" (`:16-19`).
    Nachsatz `.kl-klein` wörtlich (`:93-95`), er erklärt „Speicher oben"/„Mitte unten"
    (Erwärmung ab zwanzig Minuten Lauf), „Zähler über Maschine" („mehrere Kilowatt
    sprechen für den Heizstab"), „Heizanforderung", „Kennung 1b45" („was sie bedeutet,
    ist offen, sie liegt neben der des Heizstabs") und „Angefordert".
    Verschwindet ganz, wenn keine Zeilen da sind (`:43`).
    Der Kommentar `:7-15` nennt den Grund, und er ist der Kern dieser Karte: am
    14.11.2026 stand hier „Puffer kühlen" an einer Maschine, die heizt - **gedeutet wird
    nichts**, gezeigt werden die Belege.
    DATEN: eigener Abruf `GET /waermepumpe/kennzahlen?tage=7`
    (`apps/web/src/lib/api/client.ts:83`), **eigener Takt von fünf Minuten**, weil der
    Dienst die Auszählung fünf Minuten hält (`Kennzahlen.tsx:34-35`); Felder
    `ReglerKennzahlOut` (`apps/web/src/lib/api/types.ts:6337-6377`).
    Handy-Fassung: die Tabelle **bleibt eine Tabelle** und rollt waagerecht -
    `.kl-karte { overflow-x: auto }`, `.kl-tabelle { font-size: 13px }`
    (`handy.css:246-247`).

  * **Der Fuß** (`Waermepumpe.tsx:106-119`)
    `.wp-fuss`: Spalte, Abstand 6, höchstens 760 px, 13 px, Zeilenhöhe 1,55,
    `--text-3` (`globals.css:795`). **Offen, nicht zugeklappt.**
    1. Immer: „Fühler WP: der Speicherfühler der Wärmepumpe. Er sitzt über dem obersten
       eigenen Fühler, auf halbem Weg zur Oberkante des Speichers."
    2. Wenn `ventil_code` oder `heizstab_code` da ist: „Umschaltventil und Heizstab
       stehen als Zahl des Reglers da. Laut Busbeschreibung heißt beim Ventil 0
       Warmwasser und 1 Heizung, beim Heizstab 1 an; für dieses Haus ist das noch nicht
       gegengeprüft. Die Tabelle oben zeigt, was der Speicher unter jeder Stellung tut."
    3. Je Eintrag aus `hinweise_de` ein Absatz.
    4. `.wp-links` (Abstand 6/18, umbrechend, Farbe `--amber`, ohne Unterstreichung,
       Fokusring 2 px amber - `globals.css:796-798`), **fünf** Verweise wörtlich:
       „Betrieb über Tage ›" → `/waerme/waermepumpe/betrieb`,
       „Gemessene Kennlinie ›" → `/waerme/waermepumpe/kennlinie`,
       „Was die Wärme gekostet hat ›" → `/waerme/nachbetrachtung`,
       „Fahrplan ›" → `/waerme/fahrplan`,
       „Die ganze Anlage ›" → `/waerme/anlage`.
    DATEN: `ventil_code`, `heizstab_code`, `hinweise_de`.

  * **Laden, Nachladen, Fehler** (`Waermepumpe.tsx:27-62`)
    Vor der ersten Antwort **ein einzelner Absatz** 15 px `--text-3`: „Die Wärmepumpe
    wird geladen …", bzw. bei Fehler „Die Wärmepumpe ist gerade nicht zu erreichen."
    (`:60-62`). Danach bleibt der letzte Stand stehen und der Fehler wandert in die
    Standzeile (`:77`).
    Takt **10 s**, aber nur wenn `document.visibilityState === "visible"`, und zusätzlich
    ein Abruf, sobald die Seite wieder sichtbar wird (`:27`, `:44-58`). Der Kommentar
    `:19-21` sagt, warum nur der Augenblick gezeigt wird und warum zehn Sekunden.

LUECKEN:

  [traegt-die-seite] **Die Tabelle „Was der Regler meldet" fehlt auf der Seite ganz.**
    Vorlage: `Waermepumpe.tsx:104` + `Kennzahlen.tsx:1-98` (Karte, Überschrift, zwei
    Erklärabsätze, 13 Spalten, „· jetzt" in Amber, eigener 5-Minuten-Takt). In der App
    gesucht nach `reglerKennzahlen` in `apps/ios/DuckCurveHome`: ein Treffer, und der
    liegt auf der **anderen** Seite (`ReglerSeite.swift:73`, Karte `:334-343`) - mit nur
    **sieben** Spalten (Minuten, davon gelaufen, Vorlauf, Sollvorlauf, angefordert,
    Heizstab, zuletzt), Zeilennamen „Zustand {n}" statt „{n} · jetzt", ohne
    Speicher-oben/-unten, ohne „Zähler über Maschine", ohne Heizanforderung, ohne
    „Kennung 1b45", ohne „Ventil auf 1", ohne die beiden Erklärabsätze und ohne die
    Markierung der laufenden Kennzahl. Auf der Wärmepumpenseite steht davon nichts.
    Die Vorlage zeigt die Karte **nur hier** (`grep -c Kennzahlen Regler.tsx` → 0).

  [traegt-die-seite] **Die vier führenden Kennzahlen sind andere vier (sechs) und ohne
    ihre Hinweiszeilen.** Vorlage `Waermepumpe.tsx:93-98` mit der Begründung in
    `:23-25`. In der App (`WaermepumpeSeiten.swift:134-159`): „Spreizung" fehlt in der
    Kachelreihe (sie steht nur als Zeile `:76`), „Strom" heißt „Leistung" und trägt die
    Quelle als `dazu` statt im Namen, alle vier Hinweistexte („Durchfluss mal
    Spreizung", „nur bei laufender Maschine", „Wärme je Strom, im Augenblick",
    „Vorlauf minus Rücklauf") fehlen, der Amber-Ton der Wärmeleistung fehlt (statt
    dessen trägt die erste Kachel `Farbe.waermepumpe`), und es kommen zwei Kacheln
    hinzu, die die Vorlage hier nicht hat („draußen", „Vorlauf", „Verdichter").

  [spuerbar] **Der führende Satz ist 13 pt statt 22 pt (am Handy 19 pt) und steckt in
    einer Karte.** `WaermepumpeSeiten.swift:31` gegen `globals.css:789` /
    `handy.css:234`. Vorbild für die richtige Größe ist im Haus vorhanden:
    `Schrift.satz` = 19 pt (`Typografie.swift:64`), benutzt in
    `ReglerSeite.swift:152-157`.

  [spuerbar] **Die ganze Standzeile fehlt** (`Waermepumpe.tsx:68-78`): keine Uhrzeit
    („Stand hh:mm"), und Heizanforderung, Raum-Sollwert, Ventilstellung, Heizstabmeldung
    und Verdichterstrom stehen stattdessen als Zeilen in zwei Karten weiter unten
    (`WaermepumpeSeiten.swift:99-110`, `:56-61`). Gesucht nach `"Stand` in
    `WaermepumpeSeiten.swift`: kein Treffer.

  [spuerbar] **Die Reihenfolge ist vertauscht:** Zeichnung vor den Kennzahlen
    (`WaermepumpeSeiten.swift:28-37`) statt Kennzahlen vor der Zeichnung
    (`Waermepumpe.tsx:93-102`). Der Kommentar der Vorlage nennt es ausdrücklich: „Vier
    Zahlen oben, die Zeichnung darunter" (`Waermepumpe.tsx:23`). Der Kommentar der App
    (`WaermepumpeSeiten.swift:24-27`) begründet das Gegenteil - der Widerspruch ist zu
    entscheiden, nicht zu übersehen.

  [spuerbar] **Der Heizstab-Absatz fehlt** (`Waermepumpe.tsx:81-85`). In der App steht
    nur die Zeile „Zusatzheizung" mit `Farbe.achtung`
    (`WaermepumpeSeiten.swift:111-116`); der Satz, der sagt, was die Zahl bedeutet und
    dass die Arbeitszahl den Heizstab enthält, steht nirgends. Gesucht nach „Neben dem
    Verdichter" in `apps/ios`: kein Treffer.

  [spuerbar] **Der Absatz zum stummen Bus ist eine andere Sache geworden:** die App
    zeigt eine Karte mit „Der Bus schweigt." (`WaermepumpeSeiten.swift:38-40`), die
    Vorlage einen amberfarbenen Hinweisabsatz mit fettem Vorsatz „Vom Bus der Wärmepumpe
    ist kein Wert da." an **zweiter** Stelle, vor den Kennzahlen
    (`Waermepumpe.tsx:87-91`, `globals.css:792`).

  [spuerbar] **Der Fuß fehlt fast vollständig** (`Waermepumpe.tsx:106-119`): die beiden
    festen Erklärsätze (Fühler WP; Ventil- und Heizstabzahlen laut Busbeschreibung,
    „für dieses Haus noch nicht gegengeprüft") fehlen - gesucht nach „Speicherfühler der
    Wärmepumpe" in `apps/ios`: kein Treffer -, `hinweise_de` steht zugeklappt in einer
    `Methode` statt offen (`WaermepumpeSeiten.swift:125`), und die **fünf Verweise**
    fehlen ganz. Gesucht nach „/waerme/waermepumpe/kennlinie" in
    `WaermepumpeSeiten.swift`: kein Treffer. Vorbild für Verweise im Fuß:
    `ReglerSeite.swift:359-362`.

  [spuerbar] **Drei Listenkarten, die die Vorlage nicht hat:** Kältekreis, Wasserseite,
    Regler und Kontakte (`WaermepumpeSeiten.swift:42-124`, 19 Zeilen). Die Vorlage trägt
    diese Zahlen in der Zeichnung und in den vier Kennzahlen; danach kommt bei ihr die
    Reglertabelle. Entweder sie bleiben als bewusste Zutat (dann unter die Tabelle), oder
    sie fallen - doppelt stehen sie heute allemal, denn die Zeichnung zeigt Verdampfer,
    Sauggas, Heißgas, Flüssig, Verdichter, Vorlauf, Rücklauf, Sollvorlauf, Durchfluss,
    Speicherfühler und Puffer schon (`Bausteine/Waermepumpenbild.swift:62-65,143-144,
    190-193,199-200,240,248,285-297`).

  [spuerbar] **Das Glas im Speicher weicht ab** (`Bausteine/Waermepumpenbild.swift:
    260-297` gegen `puffer/Glas.tsx:33-91`): Radius 14 statt `breite/2` = 32 (die
    Vorlage zeichnet eine Kapsel, die App einen abgerundeten Kasten), Fühlerhöhen
    0,12/0,38/0,62/0,88 statt 0,125/0,375/0,625/0,875 (`glas.ts:21`), kein waagerechter
    Glanz, kein wandernder Lichtschein, keine innere Linie, kein `gedimmt` auf 0,5 bei
    unvollständigen Fühlern (`Bild.tsx:129`), und der Verlauf entsteht schon aus
    einzelnen Fühlern, während die Vorlage **alle vier** verlangt
    (`glas.ts:26,30-33`: „sonst gibt es keinen Verlauf, nur ein leeres Glas").

  [klein] Rohrfarbe aus `m.belastbar` (`Bausteine/Waermepumpenbild.swift:80`) statt aus
    `m.value` (`Bild.tsx:142-147`): ein veralteter Messwert färbt in der Vorlage noch,
    in der App nicht. Die Skala selbst stimmt
    (`Marken.swift:176-179` = `anlage/schema.ts:25-32`).

  [klein] Die Lagewahl ist eine andere: `horizontalSizeClass == .compact`
    (`WaermepumpeSeiten.swift:34`) gegen „Breite ≤ 720 **oder Höhe ≤ 560**"
    (`useIsMobile.ts:6,15,21`). Und die hohe Zeichnung hat keine Höchstbreite; die
    Vorlage begrenzt sie auf 420 px und zentriert (`globals.css:794`).

  [klein] Kein `prefers-reduced-motion` in der Zeichnung: `TimelineView` hält nur an,
    wenn nichts fließt (`Bausteine/Waermepumpenbild.swift:28,32`), während die Vorlage
    Fluss und Drehung bei „Bewegung reduzieren" ganz abschaltet
    (`Waermepumpe.tsx:45`, `globals.css:804`). Vorbild im Haus:
    `Diagramme/Anlagenbild.swift:26,115`.

  [klein] Stellen und Zeichen der Kennzahlen: Wärmeleistung 2 Stellen statt 1,
    Arbeitszahl 2 statt 1 (`WaermepumpeSeiten.swift:148-151` gegen
    `Waermepumpe.tsx:94,96`), und fehlende Werte stehen als „-" (`Formate.leer`,
    `Formate.swift:27`) statt als „?" (`bild.ts:83-85`).

  [klein] Nachladen ohne Sichtbarkeitsprüfung und ohne Nachholen beim Zurückkommen
    (`WaermepumpeSeiten.swift:172-178` gegen `Waermepumpe.tsx:47-57`).

  [klein] Der Seitenkicker „Außengerät · Innengerät · Speicher" (`page.tsx:9`) kommt in
    der App nicht vor; die App setzt stattdessen `w.zustandDe` als Kicker des
    Kachelfelds (`WaermepumpeSeiten.swift:37`).

KERN: SCHON DA (nachgesehen, nicht geraten)

  * `WaermepumpeOut` mit allen Feldern der Vorlage, Namen umgesetzt
    (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:9848`; Felder wie
    `zusatzKw`, `ventilCode`, `heizstabCode`, `raumSollC`, `verdichterA`,
    `luefterDrehzahl`, `kreisCode`, `kreisDe`, `einspeisung`, `busStummDe`,
    `hinweiseDe`).
  * `ReglerKennzahlOut` mit **allen dreizehn** Größen und `ReglerKennzahlenOut`
    (`Schema.swift:7868-7935`, `:7937-7955`) - `obenKH`, `untenKH`, `zusatzKw`,
    `heizanforderungAnteil`, `flag1b45Anteil`, `ventil1Anteil`, `heizstabAnteil`,
    `angefordertAnteil`, `zuletzt` sind da.
  * `Api.waermepumpe()` (`Netz/Api.swift:273-275`) und
    `Api.reglerKennzahlen(tage:)` (`:277-279`) - genau die zwei Abrufe der Vorlage.
  * `Wpbild` komplett: `satz`, `aufnahme`, `speistTiefer`, `luefterLaeuft`,
    `luefterwort`, Blockmaße, `tank`, `schild`, `fuehlerWp`, beide Pläne
    (`Haus/Waermepumpenbild.swift:11-163`) - Punkt für Punkt aus `bild.ts`, mit Tests
    (`DuckCurveKit/Tests/DuckCurveKitTests/WpbildTests.swift`).
  * `Marken.wasserfarbe` mit derselben Skala und demselben Rückfall #7FA3B3
    (`Gestalt/Marken.swift:176-205`), `Marken.waermepumpe` = 0xE0966B (`:58`).
  * Güte: `Quality.traegt`, `Messwert.belastbar`, `Messwert.hinweis(jetzt:)`
    (`Zustand/Guete.swift:15-17,50-52,65-70`).
  * Formate: `zahl`, `kw`, `celsius`, `prozent`, `hhmm(_:)` und `hhmm(iso:)`
    (`Formate/Formate.swift:44,62,98,104,141,148`).
  * Oberfläche: `Seite` (`App/Seitenwahl.swift:141-173`), `Karte` mit
    Handy-/Wandfassung (`Gestalt/Karte.swift:15-104`), `Kachelfeld`/`Kachel` mit
    genau der Handy-Regel der Vorlage - erste Kachel 48 pt über die Breite, Rest
    zweispaltig mit Haarlinien (`Karte.swift:158-343`), `Zeile` (`:360-383`),
    `Leer` (`:390-404`), `Stoerung` (`:410-436`), `Tabelle` mit Spaltenumschalter
    (`Seiten/Bericht.swift:157-240`), `Methode` (`:334-397`).
  * Der amberfarbene Hinweisabsatz der Vorlage existiert schon als Muster:
    `ReglerSeite.swift:168-183` (Fläche amber 0,09, Rand amber 0,55, Radius 12,
    Polster 14/12) - das ist `.wp-stumm` (`globals.css:792`).
  * Die Zeichnung selbst: `Bausteine/Waermepumpenbild.swift:24-299`, inklusive
    Leitungen, Lüfter, Verdichter, Wärmetauscher, Pumpe, Schilder, Fühlerlinie.

ES FEHLT:

  1. Ein Formatierer mit **sichtbarem Plus**: „+1,8" / „−0,4" mit echtem U+2212
     (`Kennzahlen.tsx:17`). Vorschlag:
     `Formate.mitVorzeichen(_ wert: Double?, stellen: Int = 1) -> String` in
     `apps/ios/DuckCurveKit/Sources/DuckCurveKit/Formate/Formate.swift` (neben
     `minus` auf Zeile 25); heute macht `Formate.zahl` nur das Minus
     (`Formate.swift:44-54`).
  2. Ein Fragezeichen-Format für diese Seite: die Vorlage schreibt „?" und nicht „-"
     (`bild.ts:82-85`). Vorschlag: `Wpbild.frage(_ wert: Double?, stellen: Int)` bzw.
     ein `fehlt:`-Argument an `Formate.zahl`, damit nicht jede Ansicht ihr eigenes
     „?" baut.
  3. Die Standzeile als Rechnung, nicht als Ansicht: aus `WaermepumpeOut` die mit
     „ · " verketteten Teile (Stand, Heizanforderung, Raum-Sollwert, Umschaltventil,
     Heizstab, Verdichterstrom, Fehlertext). Vorschlag:
     `Wpbild.standzeile(_ w: WaermepumpeOut, jetzt: Date, fehler: String?) -> String`
     in `DuckCurveKit/Sources/DuckCurveKit/Haus/Waermepumpenbild.swift`, neben
     `Wpbild.satz` (`:125-136`) - dort steht schon die gleiche Art Satzbau, und
     `WpbildTests` kann ihn prüfen.
  4. Die Zeilen und Spalten der Reglertabelle als Daten: dreizehn Spaltennamen in der
     Reihenfolge der Vorlage, je Zelle der formatierte Text, und die Markierung der
     laufenden Kennzahl. Vorschlag: neues `public enum Wpkennzahlen` in
     `DuckCurveKit/Sources/DuckCurveKit/Haus/Wpkennzahlen.swift` mit
     `spalten(_ zeilen: [ReglerKennzahlOut]) -> [(name: String, zellen: [String])]`,
     `zeilenname(_ z: ReglerKennzahlOut, aktuell: Int?) -> String` („{code} · jetzt")
     und `istAktuell(_:aktuell:)`.
  5. Die Sätze, die wörtlich dastehen müssen, als Konstanten im Kern - wie
     `Annahmenformular.kicker` (`Zustand/Annahmenformular.swift:340`) es vormacht:
     der Heizstab-Absatz (mit der Zahl eingesetzt), der Bus-stumm-Vorsatz, die zwei
     Fußsätze, die zwei Erklärabsätze der Tabelle, der Seitenkicker.
     Vorschlag: `Wpkennzahlen.einleitung`, `Wpkennzahlen.nachsatz`,
     `Wpbild.fussFuehler`, `Wpbild.fussVentilUndHeizstab`,
     `Wpbild.zusatzsatz(kw:)`, `Wpbild.busStummVorsatz`, `Wpbild.seitenkicker`.
  6. Die fünf Verweise des Fußes als Liste (Weg + Wort), wie `Wpmenue.ziele`
     (`Bausteine/Wpmenue.swift:34-52`) es für die vier Ziele hält. Vorschlag:
     `Wpbild.fussverweise: [(weg: String, wort: String)]` im Kern, damit die App sie
     nicht neu tippt.
  7. Nichts weiter: Abrufe, Modelle, Farben, Maße und Güte sind vorhanden (siehe
     KERN).

BAUPLAN: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`,
`struct WaermepumpeSeite` neu geordnet - Karte für Karte in der Reihenfolge der
Vorlage. Dazu die sechs Punkte aus ES FEHLT im Kern, zuerst 1 bis 3.

  1. **Kopf** (neu, vor allem anderen; ersetzt `:28-36` als Kopfteil): `VStack`
     Abstand 5, `Text(Wpbild.satz(w))` in `Schrift.satz` (19 pt,
     `Typografie.swift:64`), darunter `Text(Wpbild.standzeile(w, jetzt: haus.jetzt,
     fehler: fehler?.rat))` in `Schrift.klein` und `Farbe.text3`, beide
     `.fixedSize(horizontal: false, vertical: true)`. Keine Karte darum. Vorbild:
     `ReglerSeite.swift:152-163`.
  2. **Heizstab-Absatz** (neu): `if let z = w.zusatzKw` → der Absatzkasten aus
     `ReglerSeite.swift:168-183` mit `Wpbild.zusatzsatz(kw: z)`; der erste Satz
     halbfett (`Text(...).bold()` + `Text(...)`).
  3. **Bus-stumm-Absatz** (ersetzt die Karte `:38-40`): derselbe Kasten, Vorsatz
     halbfett, dahinter `w.busStummDe`.
  4. **Kachelfeld** (`:37` bleibt, `:134-159` neu geschrieben): **vier** Kacheln in
     der Reihenfolge Wärmeleistung (1 Stelle, `Farbe.amber`, `dazu` je nach
     `w.laeuft`), Strom (Name aus `Wpbild.aufnahme(w).quelle`, 2 Stellen),
     Arbeitszahl (1 Stelle, `dazu: "Wärme je Strom, im Augenblick"`), Spreizung
     (1 Stelle, K, `dazu: "Vorlauf minus Rücklauf"`); fehlende Werte als „?",
     Farbe dann `Farbe.text3`. `ersteFuehrt: true` und `art: .bericht` bleiben - das
     ist die Handyregel der Vorlage. Kicker: `Wpbild.seitenkicker` statt `zustandDe`
     (`zustandDe` steht schon im führenden Satz).
  5. **Zeichnung** (der Block `:28-36` wandert hierher, hinter die Kacheln):
     `Karte { Waermepumpenbild(wp: w, lage: …) }` mit Polster der Karte wie gehabt;
     in der hohen Lage `.frame(maxWidth: 420)` und mittig (`globals.css:794`).
     Lage künftig aus Breite **und** Höhe (`GeometryReader` oder
     `verticalSizeClass`), nicht nur aus `horizontalSizeClass`.
  6. **Reglertabelle** (neu, das größte Stück): `@State private var kennzahlen:
     ReglerKennzahlenOut?`, geholt mit `haus.api.reglerKennzahlen(tage: 7)` in einem
     eigenen `.task`, der **alle fünf Minuten** nachfragt (Vorbild für den eigenen
     Takt: `:172-178`). Darstellung: `Karte(kicker: "Was der Regler meldet",
     titel: "letzte \(k.tage) Tage")`, darunter `Text(Wpkennzahlen.einleitung)` in
     `Schrift.klein`/`Farbe.text3`, dann `Tabelle(zeilennamen:
     k.zeilen.map { Wpkennzahlen.zeilenname($0, aktuell: w.kreisCode) },
     spalten: Wpkennzahlen.spalten(k.zeilen))`, zuletzt
     `Text(Wpkennzahlen.nachsatz)`. Die laufende Kennzahl in `Farbe.amber` über
     `Tabelle.Spalte.farben` (`Bericht.swift:169`). Karte entfällt, wenn
     `k.zeilen.isEmpty`.
  7. **Fuß** (neu; ersetzt `:125`): `VStack` Abstand 6, `Schrift.klein`,
     `Farbe.text3`: `Wpbild.fussFuehler`; `Wpbild.fussVentilUndHeizstab`, wenn
     `w.ventilCode != nil || w.heizstabCode != nil`; je Satz aus `w.hinweiseDe` eine
     Zeile - **offen, nicht als `Methode`**; darunter die fünf Verweise aus
     `Wpbild.fussverweise` als `Button`/`wegweiser.gehe`, Vorbild
     `ReglerSeite.swift:359-362`.
  8. **Die drei Listenkarten** (`:42-124`): entweder entfallen oder, als bewusste
     Zutat der App, zwischen Tabelle und Fuß wandern. Entscheidung gehört in den
     Dateikommentar, denn `:7-9` begründet heute das Gegenteil der Vorlage.
  9. **Nachladen** (`:172-178`): nur abrufen, wenn die Seite vorn ist
     (`ScenePhase`), und beim Zurückkommen einmal nachholen.
 10. **Zeichnung** (`Bausteine/Waermepumpenbild.swift`): `@Environment(\.
     accessibilityReduceMotion)` dazu und in `fliesstIrgendwo` einrechnen (`:28`);
     Rohrfarbe auf `m.value` umstellen (`:80`); Glas auf Radius `breite/2`,
     Fühlerhöhen aus `glas.ts:21`, `gedimmt`-Regel und Vollständigkeitsregel
     (`:260-297`). Die Fühlerhöhen gehören dabei in den Kern (`Wpbild.fuehler`), weil
     sie die Vorlage aus `puffer/glas.ts` sind und nicht aus dieser Zeichnung.

WAS SCHWIERIG WIRD:

  * **Eine Tabelle mit dreizehn Spalten.** Die Vorlage lässt sie am Handy waagerecht
    rollen und behält alle Spalten (`globals.css:912-913`: Mindestbreite 940 px;
    `handy.css:246-247`). `Tabelle` im Projekt macht am schmalen Schirm das Gegenteil
    und zeigt **eine** Spalte mit Umschaltpillen (`Bericht.swift:206-240`) - mit
    dreizehn Pillen wird die Umschaltzeile selbst eine rollende Leiste. Der im Projekt
    schon gewählte Weg für viele Spalten ist `immerSichtbar` (`Bericht.swift:177-205`,
    benutzt mit 3 in `SystemSeiten.swift:128` und `:670`); er zeigt die ersten n
    nebeneinander. Vorschlag: `immerSichtbar: 2` (Minuten, davon Lauf) und die
    übrigen elf über die Pillen - und die Reihenfolge der Spalten so lassen, wie die
    Vorlage sie hat, damit die Pillen dieselben Wörter in derselben Folge tragen.
  * **Der fette Vorsatz in einem Hinweisabsatz.** `.wp-stumm` setzt den ersten Satz in
    `<strong>` und den Rest normal, in einem Fluss (`Waermepumpe.tsx:83`, `:89`). In
    SwiftUI geht das mit `Text(...).bold() + Text(...)`; im Projekt gibt es dafür das
    Vorbild in `Bausteine/Waermepumpenbild.swift:114-118` (zusammengesetzter `Text` mit
    zwei Schriften) - im Kasten von `ReglerSeite.swift:168-178` steht heute nur ein
    einzelner Satz.
  * **Das Glas im Canvas.** `Canvas` nimmt keine Ansichten, also lässt sich
    `Pufferspeicher`/`Glas` nicht einsetzen; der Kommentar
    `Bausteine/Waermepumpenbild.swift:260-262` nennt das und zieht daraus die Folge,
    dass Skala und Fühlerhöhen im Gleichschritt bleiben müssen. Der wandernde
    Lichtschein der Vorlage (`puffer/Glas.tsx:65-69`, 14 s) braucht hier die
    `TimelineView`-Zeit, die schon durchgereicht wird (`:32-38`) - also als weiterer
    Verlauf mit `t`-abhängiger Lage, nicht als `animate`-Element. Der im Projekt
    gewählte Weg für ein Glas als echte Ansicht ist `Bausteine/Pufferspeicher.swift`;
    wenn die Abweichungen zu groß bleiben, ist die Alternative, das Glas als Ansicht
    **über** dem Canvas zu legen statt es zu zeichnen.
  * **Der Seitenkicker.** Die Vorlage setzt ihn in die Reiterzeile der Hülle
    (`page.tsx:9` → `AreaShell.tsx:26`). In der App hat `Seite`
    (`App/Seitenwahl.swift:141-173`) keinen solchen Platz; gesucht nach `kicker` in
    `apps/ios/DuckCurveHome/App`: nur Karten-Kicker (`Einrichten.swift:262,281,297,314`).
    Entweder bekommt `Seite` einen Kicker-Parameter, oder er wandert - wie hier
    vorgeschlagen - auf das Kachelfeld.
