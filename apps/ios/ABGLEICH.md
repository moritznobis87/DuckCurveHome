# Was die App noch nicht zeigt

**Die Adressen sind vollständig, der Inhalt ist es nicht.** Alle 28 Inhaltsseiten des
Dashboards haben in der App eine Entsprechung unter derselben Adresse. Ob dort auch dasselbe
*steht*, sagt eine Adressliste nicht – und die Antwort lautet auf den meisten Seiten nein.

Diese Liste ist der Arbeitsvorrat. Sie wird abgearbeitet; erledigte Punkte werden gestrichen,
nicht abgehakt.

## Abdeckung

| | |
|---|---|
| verglichen | **28 von 28 Seiten** |
| Punkte gesamt | 167 |
| davon erledigt | **43** |
| offen | **124**, davon 1 nach Prüfung keine Lücke |

## Erledigt

- **`/` · 10 von 10 Punkten** (17.11.) – die vier Kacheln kommen aus `Tageskacheln` im Kern
  (Autarkie, bezahltes Geld, Mittelpreis, erwartete Wärme thermisch, günstigste Stunde mit
  Uhrzeit, der Hinweis auf die Börse um 13 Uhr), die Tagesbilanz wird auch für heute geholt und
  alle fünf Minuten erneuert, am Telefon steht der ``Ausblick`` statt dreier Uhrzeiten, und die
  Warnung des Planers steht unter den Planzeilen.
- **`/waerme` · 14 von 14 Punkten** (17.11.) – die Seite holt jetzt auch die Wärmebilanz und
  den Nutzen des Verschiebens: drei der sechs Kopfzahlen gab es nicht, dazu Tagesverlauf,
  Pufferbild mit den Brennphasen des Ofens, Strom nach Herkunft, Kostenkarte, neun Ofenzeilen,
  Fensterkarte und der Spannenvergleich über Tag, Woche, Monat und Jahr.
- **`/waerme/fahrplan` · 16 von 16 Punkten** (17.11.) – acht Flächen über dem ganzen Horizont
  statt einer über 24 Stunden, mit allem Gemessenen (PV, Leistung der Wärmepumpe, Anforderung),
  Warmwasser im Bedarf, Pufferverlauf mit Decke und Reserve, vier unterscheidbaren Zuständen,
  dem Ofen, den Preisfenstern im Bild und Hinweisen in leeren Flächen; die sieben Kacheln der
  Vorlage; die Entscheidungen statt 32 Zeilen „aus"; und statt des Hinweisfensters eine
  Auskunft, die der Finger steuert (Außentemperatur, COP, Prognosefehler, Zerlegung des
  Bedarfs). Dazu zwei Fehler aus den Screenshots: die festverdrahtete Preisachse bis 40 ct und
  die fehlende Tagesangabe an Uhrzeiten im Zweitagehorizont.

- **`/strom` · 3 von 4 Punkten** (18.11.) – die Seite führt jetzt den Verbrauch an und sagt,
  wer ihn hatte: „Verbrauch gesamt" mit den bewerteten Stunden, Wärmepumpe, Wallbox und
  Haushalt je mit ihrem Anteil, Autarkie mit den Kilowattstunden ohne Netz, Netzbezug in Euro
  mit dem Weg zur Rechnungsprüfung. Dazu die Datenabdeckung in der (jetzt zugeklappten)
  Methode. Offen bleibt der Spannenvergleich „Strom im Überblick".

## Was zwei Bildschirmfotos zeigten, die Liste aber nicht

Am 18.11. hat der Nutzer die Startseite und die Energieseite nebeneinandergehalten, Vorlage
gegen App. Beide Seiten standen in dieser Liste als **vollständig** bzw. mit vier kleinen
Punkten – und beide sahen grundlegend anders aus als die Vorlage.

**Der Grund ist derselbe bei beiden: verglichen wurde gegen die falsche Datei.** Das Dashboard
hat für das Telefon ein **eigenes** Flussbild (`home/FlowHandy.tsx`, seit dem 25.10.2026), weil
die Anordnung der Wandanzeige auf 390 Punkten Breite ineinanderläuft. Die App hatte die
Wandanzeige portiert (`FlowHero.tsx`) und zeigte sie auch am Telefon; der Abgleich las
`FlowHero.tsx`, fand sie getreu übersetzt und hakte die Seite ab. Dasselbe beim Kopf der
Berichtsseiten: dass er am Telefon den **Bereichsnamen** trägt und die Zeitwahl **über** den
Reitern steht, steht nicht im TSX, sondern in `handy.css` – und die wurde nicht gelesen.

**Was daraus folgt**, für den Rest dieser Liste: eine Seite ist erst verglichen, wenn
`handy.css` zu ihr gelesen ist und geprüft wurde, ob die Vorlage für das Telefon eine zweite
Datei hat. Eine Seite, deren TSX getreu übersetzt ist, kann am Telefon trotzdem eine andere
Seite sein.

Nachgezogen am 18.11. (nicht als Punkte gezählt, weil sie in der Liste nie standen): das
Flussbild im Hochformat samt Mond, Sternen und den Zustandsworten; die Reihenfolge Ausblick vor
Puffer; der Verweis „Fahrplan ›"; Größen und Farben des Ausblicks; der Bereichsname im Kopf;
die zerlegte Zeitwahl über den Reitern; Reiter als Pillen; Umschalter in voller Breite und in
Bernstein; das Wort über der Zahl auf jeder Kachel; die liegende Pufferkachel; die Legende der
Tageskurve unter dem Bild.

## Zwei Läufe, und beide tragen jetzt

Die Liste entstand in zwei Durchgängen. Der erste hatte keine Zeilenangaben – dort starb die
Prüfstufe an einer Nutzungsgrenze, und die Einträge waren die Behauptung je eines Lesers.
**Das ist am 17.11. nachgeholt**: Jeder seiner 68 Punkte wurde gegen Dashboard und App
gehalten, mit Datei und Zeile. Das Ergebnis war unbequem – **57 bestätigt, 10 teilweise, einer
keine Lücke**. Die Hoffnung, ein guter Teil werde sich als andere Gliederung erweisen, hat
sich nicht erfüllt.

Damit tragen beide Läufe: jeder offene Punkt nennt die Vorlage, die Stelle in der App und die
Datei, in die es gehört.

**Keiner der Punkte beider Läufe ist bisher umgesetzt.** Was schon gebaut wurde – die
Zeichnung der Wärmepumpe, der aufrechte Puffer, die Rahmung des Hausmodells – stand nicht in
dieser Liste, sondern kam aus Screenshots vom Gerät.

## Die Punkte, nach Seite

### `/geld`  ·  8 Punkte, davon 3 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Pelletkosten fehlen in Bezahlt und in der Aufstellung
  - Befund: Das Web holt `api.energyHeat` (CostReport.tsx:62) und rechnet `heat.stove.pellet_eur` in "Bezahlt" ein (CostReport.tsx:66-67), nennt sie im Hinweis der Kachel (CostReport.tsx:112), als eigene Aufstellungszeile mit kg (CostReport.tsx:210) und haengt `heat.stove.note_de` an die Methode (CostReport.tsx:236). Die KostenSeite holt nur `energieUebersicht` und `energieVerschiebung` (GeldSeiten.swift:15-16); `grep -i pellet` ueber `DuckCurveHome/Seiten/Geld/` findet null Treffer, und `energieWaerme` wird nur in WaermeSeite.swift:12 und JetztSeite.swift:230 gerufen, nie in GeldSeiten.swift. Der Endpunkt existiert im Kern (Api.swift:188), es fehlt also nur der Aufruf.
  - Vorlage: `apps/web/src/components/reports/CostReport.tsx:62,66-67,112,210,236`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:15-16 (nur zwei Abfragen), :90 (netto = importCostEur - exportRevenueEur, ohne Pellets)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **spürbar** — Kennzahl Gespart und Karte Woraus die Ersparnis besteht fehlen
  - Befund: Web: `gespart = pv_direct_savings_eur + battery_net_eur` (CostReport.tsx:69) als Kachel "Gespart" (CostReport.tsx:114) und darunter die Karte "Woraus die Ersparnis besteht" mit zwei Balken (CostReport.tsx:124-148). In der App wird keines der beiden Felder auf der KostenSeite gelesen: `grep -rn "pvDirectSavings\|batteryNetEur" DuckCurveHome/` trifft nur StromSeite.swift:143 ("ersparte Kosten", PV-Seite) und StromSeite.swift:229 ("unterm Strich", Speicherseite) - zwei verschiedene Seiten, nie zusammen und nie als Summe. Die Felder sind im Modell vorhanden (Schema.swift:3014,3022). Die Kachel "gespart" der App (GeldSeiten.swift:95) ist `v.savingEur` aus dem Vergleichslauf, eine andere Groesse.
  - Vorlage: `apps/web/src/components/reports/CostReport.tsx:69,114,124-148`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:88-114 (kennzahlen ohne beide Felder), :95 ("gespart" = savingEur)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **spürbar** — Karte Aufstellung fehlt ganz, inklusive Menge und ct/kWh
  - Befund: Web: Tabelle "Aufstellung" mit sieben Posten je Menge, Ø Preis, Betrag und Verweis auf die Herkunftsseite (CostReport.tsx:193-223, Zeilen 206-212), inklusive des Haushaltsrestes nach Abzug der Geraete (CostReport.tsx:101-102) und der Summe der entgangenen Verguetung (CostReport.tsx:212). In der App existiert nichts davon: `grep -rn "Aufstellung\|Posten\|Haushalt"` ueber `DuckCurveHome/` findet keinen Treffer, `batteryDeviceCostEur`, `heatPumpGridKwh`, `batteryDeviceGridKwh`, `heatPumpOpportunityEur` und `batteryDeviceOpportunityEur` werden in der ganzen App nirgends gelesen (nur `evCostEur`/`evGridKwh`/`evOpportunityEur` auf StromSeite.swift:282-285, Wallboxseite). Nach der Verschiebungskarte folgt direkt "Nach Zeitraum" (GeldSeiten.swift:58-74). Kleine Praezisierung zur Formulierung des Punkts: neben "Wärmepumpe" (GeldSeiten.swift:107) gibt es auch Kacheln "Bezug" und "Einspeisung" (:103-105), aber nur in Euro, ohne Menge, ct/kWh und Verweis, und ohne Haushaltsrest.
  - Vorlage: `apps/web/src/components/reports/CostReport.tsx:193-223 (Zeilen 206-212), 101-102`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:58-74 (direkt das Balkenbild), :101-112 (Kacheln statt Aufstellung)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **mittel** — Belastbarkeit des Vergleichslaufs: Tage und heatPumpKwh fehlen
  - Befund: Web: "{shifted_kwh} von {heat_pump_kwh} kWh verschoben · {days_used} Tage gerechnet" und "{days_skipped} ohne Aussage ({skipped_de})" (CostReport.tsx:166-172), und bei `days_used == 0` ersetzt der Satz "Für diesen Zeitraum reicht es nicht für eine Aussage." die Zahl (CostReport.tsx:162-165). `grep -rn "daysUsed\|daysSkipped"` ueber `DuckCurveHome/` findet null Treffer, `heatPumpKwh` nur auf Strom- und Waermeseiten (StromSeite.swift:77, WaermeSeite.swift:42,159,189,214), nie in GeldSeiten.swift - alle drei Felder gibt es im Modell (Schema.swift:7676,7679,7680). Die Karte haengt nur an `if let v = paar.verschiebung` (GeldSeiten.swift:23) und erscheint damit auch bei daysUsed = 0. `skippedDe` steht immerhin in der Methode (GeldSeiten.swift:81), aber als Begruendungstext, nicht als Ersatz der Zahl und ohne Tageszahl.
  - Vorlage: `apps/web/src/components/reports/CostReport.tsx:162-172`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:23-43 (Karte "Was der Preisblick gebracht hat"), :81 (skippedDe)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **mittel** — Spannenvergleich (PeriodStrip) fehlt in der ganzen App
  - Befund: Web: `useMultiPeriod` laedt alle vier Spannen zum Ankertag gleichzeitig mit `Promise.allSettled` (useReport.ts:55-77, aufgerufen in CostReport.tsx:64) und `PeriodStrip` stellt fuenf Zeilen - Bezahlt, Bekommen, Gespart, Netzbezug, Ø Bezugspreis - nebeneinander (CostReport.tsx:225-235, PeriodStrip.tsx:32-93). Die App hat kein Gegenstueck: `Berichtsseite` holt genau eine Antwort fuer den gewaehlten Zeitraum (Bericht.swift:48-59, aufgerufen GeldSeiten.swift:12-17), und `grep -rn "Spannenvergleich\|PeriodStrip\|Zeitraumstreifen\|alleSpannen\|multiPeriod"` ueber `DuckCurveHome/` und `DuckCurveKit/Sources/` findet keinen Treffer. Es fehlt also nicht nur die Karte, sondern der Mechanismus fuer mehrere Spannen gleichzeitig.
  - Vorlage: `apps/web/src/components/reports/CostReport.tsx:64,225-235; apps/web/src/components/reports/PeriodStrip.tsx:32-93; apps/web/src/components/reports/useReport.ts:55-77`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Bericht.swift:48-59 (genau eine Abfrage je Zeitraum)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Bericht.swift (neuer Spannenstreifen) + apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift (Einbau)`
- **mittel** — Datenabdeckung und Aufzeichnungsbeginn fehlen unter der Kostenseite
  - Befund: Web: `CoverageNote` zeigt "Datenabdeckung NN %" bzw. "noch keine Messdaten im Zeitraum" und "Aufzeichnung seit TT.MM.JJJJ" aus `meta.coverage` und `meta.data_since` (ReportShell.tsx:163-174, eingehaengt CostReport.tsx:236). Die App gibt dem `Methode`-Baustein nur `methodDe`, `skippedDe`, `estimatedNoteDe` und die Annahmen (GeldSeiten.swift:78-84); `grep -rn "coverage\|dataSince"` ueber `DuckCurveHome/` zeigt, dass beide Felder (Schema.swift:2835-2836) auf der Kostenseite nirgends gelesen werden. Dass der Zielzustand erreichbar ist, belegen RechnungenSeite.swift:122 ("abgedeckter Zeitraum") und StromSeite.swift:25 ("Daten seit …"). Kleine Praezisierung: StromSeite.swift:25 zeigt nur `dataSince`, nicht die Abdeckung - fuer die ist RechnungenSeite.swift:122 die Vorlage.
  - Vorlage: `apps/web/src/components/reports/ReportShell.tsx:163-174; apps/web/src/components/reports/CostReport.tsx:236`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:78-84 (Methode ohne coverage/dataSince)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **klein** — Zeitraumleiste ohne Sprung auf heute
  - Befund: Web: neben ‹ und › steht eine Schaltflaeche "heute", solange der Ankertag nicht der laufende ist (ReportShell.tsx:116, `onToday` aus CostReport.tsx:107, `today` aus `usePeriod` CostReport.tsx:60). Die App hat in `Zeitraumleiste.blaettern` nur "Zurück" und "Vorwärts" (Seitenwahl.swift:197-228); der Zeitraumname dazwischen ist ein reiner `Text` ohne Button (Seitenwahl.swift:211-215), und `grep -n "heute\|Heute"` in Seitenwahl.swift findet keinen Treffer. `z.istAktuell(jetzt:)` wird dort nur benutzt, um den Vorwaertsknopf zu sperren (Seitenwahl.swift:198,224) - die Information liegt also schon vor, es fehlt nur der Rueckweg.
  - Vorlage: `apps/web/src/components/reports/ReportShell.tsx:116; apps/web/src/components/reports/CostReport.tsx:60,107`
  - In der App: `apps/ios/DuckCurveHome/App/Seitenwahl.swift:197-228 (blaettern), :211-215 (Zeitraumname ohne Button)`
  - bauen in: `apps/ios/DuckCurveHome/App/Seitenwahl.swift`
- **klein** — Kennzahl Energie je Tag fehlt
  - Befund: Web: `tage = totals.minutes / 1440` und `jeTag = (bezahlt - bekommen) / tage` (CostReport.tsx:70-71) als vierte Kachel "Energie je Tag" mit dem Hinweis, wie viele Tage bewertet wurden (CostReport.tsx:115). In der App liefert `kennzahlen` sechs Kacheln - gespart, unterm Strich, Bezug, Einspeisung, Wärmepumpe, mittlerer Bezugspreis (GeldSeiten.swift:88-114); `grep -rn "totals.minutes\|\.minutes"` ueber `DuckCurveHome/Seiten/Geld/` findet keinen Treffer, obwohl `minutes` im Modell steht (Schema.swift:2975). Auch `grep -rn "je Tag"` ueber die App trifft nur WaermeSeite.swift:73 und WaermepumpeSeiten.swift:266 ("Starts je Tag"), also etwas anderes.
  - Vorlage: `apps/web/src/components/reports/CostReport.tsx:70-71,115`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:88-114 (kennzahlen), :90 (netto ohne Teilung durch Tage)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`

### `/haus`  ·  7 Punkte, davon 1 spürbar  ·  *gegengeprüft 17.11.*

> **Nachtrag 18.11.** Die Raumliste ist jetzt die Kachelwand der Vorlage: je Raum die große
> Temperatur, „Ziel 18,8 °C“, das Abzeichen („am Ziel“ / „+1,9 K“ in der Stufenfarbe), der
> Tagesverlauf der Abweichung mit gestrichelter Ziellinie, der Ventilstreifen zu 24 Stunden mit
> der Achse 00/12/24 und „±3 K“, die Fußzeile „Ventil 1 von 4 offen · 45 % rF“ und ein Knopf
> **Protokoll**. Darüber stehen die Legende (Abweichungsskala, „Ventil offen“, „kein Messwert“)
> und je Geschoss die Zeile „3 Räume · alle am Ziel“. Dafür holt die Seite nun auch
> `/rooms/history` – das fehlte vorher, und daran fehlte die ganze Kurve
> (`Seiten/Haus/Raumkachel.swift`, `Seiten/Haus/Raumprotokollblatt.swift`,
> `DuckCurveKit/.../Zustand/Raumkarte.swift`, `.../Raumprotokoll.swift`, 37 neue Tests).

- **spürbar** — Block "Fenster und Türen": Zahl, Satz, Kontaktliste fehlt
  - Befund: Gesucht in ganz apps/ios/DuckCurveHome nach "Kontakt", "kontakt", "Fenster", "Tür", "HouseContactOut", "open ==" und "observedAt": HouseContactOut wird nur an einer Stelle benutzt (Glasmodell.swift:24, gefüllt aus HausSeite.swift:138-140) und dort ausschliesslich als Strich gezeichnet (Glasmodell.swift:234-262). Eine Zahl der offenen Kontakte, ein Zustandswort (offen/zu/keine Meldung) oder ein Alter steht nirgends; die einzige Textform ist der Vorlesesatz Glasmodell.swift:303-313 ("Offen: …"), der nicht sichtbar ist. Die Felder sind vorhanden (Schema.swift:4428-4455: room, door, open, observedAt, quality), werden aber nicht gelesen. Hinweis: die iOS-Zeilenangaben des Punkts sind veraltet (Kontaktzeichnung 234-262 statt 197-225, Vorlesetext 303-313 statt 266-276).
  - Vorlage: `apps/web/src/components/house/Konsole.tsx:186-224`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift:23-38`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift`
- **mittel** — Pufferblock auf /haus; Platz und Rechenweg fehlen ganz · **teilweise**
  - Befund: Auf der iOS-/haus-Seite steht wirklich nichts zum Puffer (HausSeite.swift:23-38 kennt nur Kopf, Störung, Alarmkarte, Raumliste, Modell; "Puffer" kommt in der Datei nicht vor). Das Meiste des Blocks steht aber auf anderen Seiten der App: Pufferglas (Bausteine/Pufferspeicher.swift:19-76) zeigt Ladestand und die vier Schichttemperaturen mit gedämpfter Farbe bei alten Fühlern, dazu das Zustandswort mit Alter ("Werte vor 2 d", DuckCurveKit/Sources/DuckCurveKit/Zustand/Puffer.swift:41-51) - auf "/" (Bausteine/Leiste.swift:19-28) und auf /waerme/anlage (Seiten/Technik/AnlageSeite.swift:76-104), dort zusätzlich "nutzbar", "Fassung" (capacityKwh) und "Volumen" (volumeLiters). Es fehlt: der Block auf /haus selbst, und app-weit der freie Platz (headroomSoc) und der Rechenweg (buffer.method) - Suche nach "headroom", "usableEnergy", "method" findet in DuckCurveHome nur Blaetter.swift:497 ("im Puffer ist kein Platz" als Reason-Code), die Felder liegen ungenutzt in Schema.swift:2129-2156.
  - Vorlage: `apps/web/src/components/house/Konsole.tsx:226-277`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift:76-104`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift`
- **mittel** — Wärmepumpenblock auf /haus; Tageskurve und Zeilen stehen anderswo · **teilweise**
  - Befund: Dass die iOS-/haus-Seite zur Wärmepumpe nichts zeigt, stimmt: in HausSeite.swift kommen "heatPump", "decision" und "Chart" nicht vor, geholt werden nur raeume() und haus() (HausSeite.swift:164-174). Der Inhalt des Blocks steht aber in der App: das Wärmepumpenblatt (Bausteine/Blaetter.swift:331-357) nennt Zustand, Leistung, "läuft seit"/"aus seit", "Starts heute" (startsToday), Freigabekontakt K1 (releaseContactOn) und "Betrieb" (haus.betriebswort, App/Hauszustand.swift:273-277), dazu die Begründung der letzten Entscheidung (Blaetter.swift:416-430, decision.explanationDe); erreichbar über das Dock auf "/" (Bausteine/Dock.swift:64) und das Flussbild (Bausteine/Energiefluss.swift:274). Die gemessene Tageskurve der Wärmepumpenleistung gibt es auf /waerme/fahrplan (Diagramme/Fahrplanzeichnung.swift:53), Strom und Laufanteil auf /waerme (Seiten/Energie/WaermeSeite.swift:52,86). Es fehlt: der Block neben dem Haus und, als Zeile zusammen mit dem Rest, "Strom heute" und "Laufzeit heute" der Pumpe.
  - Vorlage: `apps/web/src/components/house/Konsole.tsx:279-306`
  - In der App: `apps/ios/DuckCurveHome/Bausteine/Blaetter.swift:331-357`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift`
- **mittel** — Räume im Modell nicht antippbar, Kontakte im Raumblatt fehlen · **teilweise**
  - Befund: Bestätigt für die Bedienung: die einzige Gestik am Glasmodell ist DragGesture zum Drehen (Haus3D/Glasmodell.swift:44-52), es gibt keinen Fokus und keine Raumtafel; das Raumblatt wird nur aus der Liste geöffnet (HausSeite.swift:95-97). Der Inhalt der Tafel steht aber im Raumblatt: Temperatur, Sollwert am Regler, wirksamer Sollwert, Abweichung, Ventil und Heizkreise (Bausteine/Blaetter.swift:70-96) sowie der Regler "Sollwert stellen" mit geschätzter Wirkung (Blaetter.swift:100-110). Es fehlt also zweierlei: das Tippen auf einen Raum im Modell und die Fenster/Türen genau dieses Raums - Suche nach "Fenster" und "Kontakt" in Blaetter.swift findet im Raumblatt nichts, der einzige Fenster-Hinweis je Raum ist "Fenster offen" aus dem Rohwert window in HausSeite.swift:230, nicht die Kontaktliste.
  - Vorlage: `apps/web/src/components/house/HouseReport.tsx:295-343`
  - In der App: `apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift:44-52`
  - bauen in: `apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift`
- **klein** — Heizkreise: Zahl offener Kreise · **teilweise**, Grenzraum-Satz seit 18.11. gebaut
  - Nachtrag 18.11.: Der Grenzraum ist da. Jede Kachel, deren Kreise im Tagesmittel zu 85 % offen
    standen und die trotzdem unter dem Ziel liegt, trägt das Abzeichen „! an der Grenze“ – und ein
    offenes Fenster nimmt die Anklage zurück, weil die Kälte dann schon erklärt ist
    (`Zustand/Raumkarte.swift`, `anDerGrenze`, mit Tests). Offen bleibt die **Summe** über das
    Haus („offen 3 von 10“) auf dieser Seite.
  - Befund (17.11., vor dem Umbau): Auf /haus stimmt es: Raumzeile.unterzeile nennt "Ventil offen"/"Ventil 40 %" je Raum (HausSeite.swift:228-239), eine Summe oder ein Satz steht in der Datei nicht. Die Zahl der offenen Kreise gibt es aber in der App: "offen 3 von 10" samt Anteil auf /waerme/anlage (Seiten/Technik/AnlageSeite.swift:162-174, roomsOpen/roomsTotal) und in der Wiedergabe (Seiten/Technik/SystemSeiten.swift:316). Der konkrete Satz über den Raum, der alle Kreise offen hat und trotzdem unter dem Ziel liegt (web: anDerGrenze), fehlt dagegen überall - Suche nach "Grenze", "bestimmt", "Vorlauftemperatur" findet nur den allgemeinen Erklärsatz der Abweichungsmatrix (Bausteine/Abweichungsmatrix.swift:31-32), der keinen Raum nennt.
  - Vorlage: `apps/web/src/components/house/Konsole.tsx:308-351`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift:162-174`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift`
- **klein** — Keine Legende am Modell · **teilweise**, Geschosswahl und Legende der Liste gebaut
  - Nachtrag 18.11.: Die Geschosswahl steht am Modell („Alle“ und je ein Deck, am Telefon zuerst
    ein einzelnes), und über der Raumliste steht die Legende der Abweichungsskala. Was fehlt, ist
    die Farbskala **am Modell** selbst.
  - Befund (17.11., vor dem Umbau): Glasmodell.zeichne zeichnet in einer Schleife immer alle plan.decks (Haus3D/Glasmodell.swift:149-158), und HausSeite übergibt den ganzen Plan ohne Auswahl (HausSeite.swift:132-148); die einzige Wahl im Kopf ist Liste/Modell (HausSeite.swift:65-83). Suche nach "Geschoss" in DuckCurveHome findet nur die Gruppierung der Raumliste (HausSeite.swift:108-126) und den Vorlesesatz "Hausmodell mit n Geschossen" (Glasmodell.swift:305) - keinen Umschalter. Suche nach "Legende" findet nur Diagramme/Fahrplanzeichnung.swift:364-398 und Diagramme/Tageskurve.swift:250-300; am Hausmodell steht keine Farbskala und kein "gelb: unter Ziel". Die Zeilenangabe des Punkts für die Deck-Schleife ist veraltet (149-158 statt 112-121).
  - Vorlage: `apps/web/src/components/house/HouseReport.tsx:232-243,289-294`
  - In der App: `apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift:149-158`
  - bauen in: `apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift`
- **klein** — Kopf nennt Planname und Herkunft nicht, Anmerkung fehlt
  - Befund: Der Kopf enthält nur Ansichtswahl und "Stand hh:mm" (HausSeite.swift:65-83). Suche nach "sourceDe", "noteDe", "plan.name" und "Hausplan" in apps/ios/DuckCurveHome: sourceDe kommt gar nicht vor (nur params.roomSourceDe in WaermeSeite.swift:207), die noteDe-Treffer gehören zu anderen Modellen (Batterie, Fahrplan, System), "Hausplan" steht nur in zwei Leer-/Fehlersätzen (HausSeite.swift:150,170). Vom HouseOut werden nur plan, contacts, errorDe und present gelesen (HausSeite.swift:132-158). Die Felder gibt es im Schema: HouseOut.sourceDe (Schema.swift:4479), HousePlan.name und HousePlan.noteDe (Schema.swift:4519-4521).
  - Vorlage: `apps/web/src/components/house/HouseReport.tsx:219,354`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift:65-83`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift`

### `/strom`  ·  1 Punkt  ·  *gegengeprüft 17.11., drei Punkte erledigt 18.11.*

> **Erledigt am 18.11.** Die Netzbezug-Kachel in Euro samt Weg zur Rechnungsprüfung, die
> Datenabdeckung in der Methode, und die drei Verbraucher mit ihrem Anteil. Die Seite führt
> jetzt mit dem Verbrauch statt mit der Autarkie, und was zur Erzeugung gehört („aus der
> Sonne", „eingespeist", „Eigenverbrauch") steht unter Photovoltaik, wo die Vorlage es hat.
> Nachgezogen wurde dabei auch, was in dieser Liste nie stand: die Reihenfolge der beiden
> Diagramme, ihre Namen, und die Farben der gestapelten Balken – die Wallbox hatte genau den
> Ton, den `charts/palette.ts` verworfen hat, weil zwei von drei Segmenten wie eines aussahen.

- ~~**mittel** — Netzbezug in Euro fehlt als Kachel auf /strom~~ · **erledigt 18.11.**
  - Befund: Web hat die eigene Kachel apps/web/src/components/reports/HouseReport.tsx:51-58 (label "Netzbezug", value eur(t?.import_cost_eur), hint mit import_kwh). In apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:30-48 stehen nur Autarkie, Sonne, Netz (kWh), Einspeisung, Haus, Eigenverbrauch; grep nach importCostEur/import_cost_eur ueber apps/ios/ findet in der Datei keinen Treffer, nur apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:63,90,103. Das Feld gibt es im Schema (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:3003, 3053), ist auf dieser Seite also nur ungenutzt. Keine Verlagerung: die Vorlage zeigt den Betrag auch auf /geld (apps/web/src/components/reports/CostReport.tsx:112), die iOS-Geldseite ist deren Gegenstueck, nicht der Ersatz fuer diese Kachel.
  - Vorlage: `apps/web/src/components/reports/HouseReport.tsx:51-58`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:30-48`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **mittel** — Abschnitt "Strom im Ueberblick" (vier Spannen) fehlt ganz
  - Befund: Web: apps/web/src/components/reports/HouseReport.tsx:72-81 setzt PeriodStrip mit den vier Zeilen Verbrauch, Autarkie, Netzkosten, Einspeiseerloes; die vier Abfragen auf einmal macht apps/web/src/components/reports/useReport.ts:55-76 (useMultiPeriod, Promise.allSettled ueber ALL_PERIODS), gezeichnet in apps/web/src/components/reports/PeriodStrip.tsx:32-93. iOS holt in apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:10-11 nur energieUebersicht(z.spanne.rawValue, anker:) fuer die eine gewaehlte Spanne; apps/ios/DuckCurveHome/Seiten/Bericht.swift:15-60 kennt kein Gegenstueck zu PeriodStrip (Spanne.allCases kommt nur in Bericht.swift:17 als Liste der anwaehlbaren Spannen vor, nicht als Mehrfachabfrage). Auch der Einspeiseerloes fehlt dort: exportRevenueEur (Schema.swift:3004, 3054) kommt in StromSeite.swift nicht vor, nur in Geld/GeldSeiten.swift:68,90,105.
  - Vorlage: `apps/web/src/components/reports/HouseReport.tsx:72-81`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:10-11`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift (Baustein nach apps/ios/DuckCurveHome/Seiten/Bericht.swift)`
- ~~**mittel** — Datenabdeckung des Zeitraums wird nie gedruckt~~ · **erledigt 18.11.**
  - Befund: Web: apps/web/src/components/reports/ReportShell.tsx:163-174 (CoverageNote) macht aus meta.coverage "Datenabdeckung NN %" bzw. "noch keine Messdaten im Zeitraum" und steht in HouseReport.tsx:82. iOS: apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:23-26 uebergibt der Methode nur estimatedNoteDe und dataSince. Das Feld liegt im Modell (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:2836, EnergyMetaOut.coverage, benutzt von EnergySummaryOut.meta in Schema.swift:2949). Grep nach coverage/Coverage/Abdeckung ueber apps/ios/DuckCurveHome/ findet nur Geld/RechnungenSeite.swift:122 (Rechnungs-Meta) und Technik/SystemSeiten.swift:500-521 sowie FahrplanSeiten.swift:342 (CoverageOut vom Endpunkt /system/coverage, ein anderes Feld) - in keiner Energie-Seite.
  - Vorlage: `apps/web/src/components/reports/ReportShell.tsx:163-174`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:23-26`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift (bzw. Methode in apps/ios/DuckCurveHome/Seiten/Bericht.swift:263-286)`
- ~~**klein** — Waermepumpe, Wallbox, Haushalt ohne Summe und Anteil~~ · **erledigt 18.11.**
  - Befund: Web: apps/web/src/components/reports/HouseReport.tsx:46-48 gibt den drei je eine Kachel mit kWh und dem Hinweis aus share() in HouseReport.tsx:38 ("NN % des Verbrauchs"). iOS: apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:30-48 hat keine solche Kachel; heatPumpKwh, evKwh und baseKwh kommen auf der Seite nur als Balkenreihen je Zeitschritt vor (StromSeite.swift:69-84), und die Tabelle StromSeite.swift:86-99 hat die Spalten Sonne, Haus, Bezug, Einspeisung - ohne die drei. Grep nach "des Verbrauchs"/"Anteil am" in apps/ios/DuckCurveHome/Seiten/ trifft nur StromSeite.swift:34 (Autarkie), eine Anteilsangabe fuer die drei gibt es in der App nirgends. Die Summen allein stehen auf Unterseiten, die die Vorlage ebenso hat (WaermeSeite.swift:52 "Strom dafuer", StromSeite.swift:277 "geladen").
  - Vorlage: `apps/web/src/components/reports/HouseReport.tsx:46-48`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:30-48, 86-99`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`

### `/system`  ·  6 Punkte, davon 4 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Tagesverlauf 15-min mit Heute/Gestern-Umschalter fehlt
  - Befund: Web zeichnet den Tag aus day.points mit actual_kw/day_ahead_kw/corrected_kw (ForecastPage.tsx:45-47, Serien :82-84) und schaltet Heute/Gestern (:231, :283-289). In der App ist ForecastEvaluationOut nur in SystemSeiten.swift:366 gebunden; grep ueber DuckCurveHome/ nach today, yesterday, actualKw, dayAheadKw, correctedKw, latestKw findet ausser Leiste.swift:159 (todayKwh, andere Groesse) keinen Treffer - b.today/b.yesterday werden nirgends gelesen. Swift Charts ist vorhanden (SystemSeiten.swift:1 import Charts, Chart bei :100 fuer Raumverlaufsbild), nur nicht fuer die Prognose.
  - Vorlage: `apps/web/src/components/forecast/ForecastPage.tsx:42-87,231,267-293`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:370-466`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **spürbar** — Quellenliste mit Gewicht, MAE 7 d, Status fehlt ganz
  - Befund: Web hat die Tabelle Quelle/Gewicht/MAE 7 d/Status aus ev.sources (ForecastPage.tsx:344-363), die Kopfzeile mit sources[0].label_de (:246), die Kachel MAE 7 Tage aus sources[0].mae_7d_kw (:239,:263) und im Kartenkopf Ist/Prognose gesamt = corrector.k_global (:343). In der App taucht b.sources nicht auf: grep nach sources, mae7dKw, kGlobal, Quellen, Gewicht ueber DuckCurveHome/ ist leer (nur WaermeSeite.swift:140 Quelle in anderem Sinn); SourceStatusOut wird auch auf /system/daten und /system/mitteilungen nicht benutzt. Das Feld existiert (Schema.swift:3356 sources, SourceOut Schema.swift:7741-7745 mit weight/mae7dKw/active).
  - Vorlage: `apps/web/src/components/forecast/ForecastPage.tsx:344-363,246,239,263`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:375-407`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **spürbar** — Korrekturfaktoren nach Sonnenhoehe fehlen komplett
  - Befund: Web baut factorOption ueber ev.corrector.bins mit factor, previous, last_ratio und days (ForecastPage.tsx:144-146,160,170-177) und zeigt die Karte Korrekturfaktoren nach Sonnenhoehe mit days_learned und half_life_days (:315) sowie updated_on als Tagesabschluss (:327). Die App hat nur Zeile(wort: "Korrektur aktiv") in SystemSeiten.swift:399-402; grep nach corrector, Corrector, bins, daysLearned, halfLifeDays, lastRatio, Sonnenhoeh, Halbwertszeit ueber DuckCurveHome/ ergibt nur Blaetter.swift:152, und das ist halfLifeH eines Raums, nicht der Korrektor. CorrectorState (Schema.swift:2286-2293) und BinCorrection (Schema.swift:1925-1931) sind im Modell da, werden aber nirgends gelesen.
  - Vorlage: `apps/web/src/components/forecast/ForecastPage.tsx:142-180,314-322,327`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:398-405`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **spürbar** — Rueckblick ohne Aufschluesselung je Vorlauf, ohne p95
  - Befund: Web zeichnet je Reihe mittlerer Fehler als Balken und Rand (95 %) als Punkt darueber aus reihe.je_vorlauf[].wertung.mae/p95/n (Rueckblick.tsx:37-41,82-98), nennt die Paarzahl im Tooltip (:65) und Bias plus Paarzahl im Kartenkopf (:189). Die App zeigt eine Tabelle mit genau drei Spalten: gesamt.mae, Einheit, Laeufe (SystemSeiten.swift:452-462). jeVorlauf existiert auf ReiheOut (Schema.swift:6898), Wertung traegt n/mae/bias/rmse/p95 (Schema.swift:8850-8855); grep nach jeVorlauf, p95, Vorlauf, Bias, Rand ueber DuckCurveHome/ findet keinen davon im Prognosezusammenhang (die Vorlauf-Treffer sind alle Vorlauftemperatur der Waermepumpe).
  - Vorlage: `apps/web/src/components/forecast/Rueckblick.tsx:36-99,182-198`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:450-464`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **mittel** — Bias kommt in der App gar nicht vor
  - Befund: Bias steht im Web an mehreren Stellen: je Tag im Kartenkopf des Tagesdiagramms (ForecastPage.tsx:280 day.score.bias_kw), je Horizont im Tooltip und als zweiter Balken (:129,:137, Legende :311), als Mittel der letzten 7 Tage aus daily[].bias_kw (:240, ausgegeben :365) und je Reihe im Rueckblick (Rueckblick.tsx:189 gesamt.bias). Die App gibt in der Horizonttabelle nur maeKw (SystemSeiten.swift:413-417) und in der Tagestabelle energyForecastKwh, energyActualKwh, energyErrorPct, maeKw (:426-441) aus; grep nach biasKw, Bias, systematisch, Schieflage ueber DuckCurveHome/ ist leer, obwohl ForecastScore.biasKw (Schema.swift:3492) und DailyScoreOut.biasKw (Schema.swift:2487) da sind. Kleine Korrektur an der Fundstelle: das zitierte ForecastPage.tsx:103 zeigt Abweichung und MAE, nicht Bias - der Tagesbias steht bei :280 und :240.
  - Vorlage: `apps/web/src/components/forecast/ForecastPage.tsx:280,129,137,240,365`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:408-445`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **klein** — Zeitraumwahl 3/7/14/30 Tage fehlt, 7 fest verdrahtet
  - Befund: Web hat die Knopfreihe 3/7/14/30 d mit setTage (Rueckblick.tsx:167-178), und tage haengt im Ladeeffekt (:139,:154). Die App ruft prognoseVerlauf(tage: 7) fest (SystemSeiten.swift:472, Signatur DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:361 mit Standardwert 7) und baut keine Wahl ein - PrognoseSeite hat nur @State bewertung, verlauf, fehler (:366-368), kein tage. Der Baustein dafuer liegt bereit: struct Tagewahl in WaermepumpeSeiten.swift:377, in derselben Datei schon benutzt von HaustuerSeite (SystemSeiten.swift:641).
  - Vorlage: `apps/web/src/components/forecast/Rueckblick.tsx:167-178`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:472`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`

### `/geld/pv-abrechnung`  ·  6 Punkte, davon 1 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Diagramm "Erloes und Wertabgabe" fehlt in der App
  - Befund: Im Web steht die Karte mit dem Balkendiagramm in apps/web/src/components/reports/PvAccounting.tsx:100-105, die Reihen (Einspeisevverguetung netto, Eigenverbrauch Wert netto) in :64-74 und der Leerhinweis als <Note> in :103. In der App hat PvAbrechnungSeite (apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:121-227) kein Diagramm: grep auf "Balkenbild" in GeldSeiten.swift trifft nur :46 und :59, beide in KostenSeite; api.energiePv wird nur an GeldSeiten.swift:124 gerufen (einziger Treffer im ganzen Projekt), es gibt also keine zweite Seite, die das zeigen koennte. Kleine Praezisierung: moneyBars setzt stack: "total" (apps/web/src/components/reports/charts.ts:393), die zwei Reihen stehen also gestapelt, nicht nebeneinander - in der App also Balkenbild(..., einheit: "€", gestapelt: true).
  - Vorlage: `apps/web/src/components/reports/PvAccounting.tsx:64-74,100-105`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:159-183`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **mittel** — Tabelle hat vier statt sieben Spalten
  - Befund: Web COLUMNS hat sieben Spalten (apps/web/src/components/reports/PvAccounting.tsx:29-37): Einspeisung kWh, Verguetung netto, USt darauf erhalten (:32), Eigenverbrauch kWh, Wertabgabe netto (:34), USt darauf geschuldet (:35), Zahllast (:36). Die App-Tabelle hat genau vier (GeldSeiten.swift:160-182): eingespeist, Verguetung, Eigenverbrauch, USt. zu zahlen. exportVatEur und selfVatEur stehen in der App nur als Gesamtsumme in den Karten (GeldSeiten.swift:137 bzw. :156), selfValueNetEur nur in GeldSeiten.swift:155 und als Kachel-Beisatz :219. Je bucket fehlen damit drei Spalten, nicht zwei - zum genannten exportVatEur und selfValueNetEur kommt selfVatEur ("USt darauf, geschuldet"). Alle drei Felder liegen am bucket an: Schema.swift:6447, 6452, 6453 (PvTaxBucketOut.totals, Schema.swift:6340-6344).
  - Vorlage: `apps/web/src/components/reports/PvAccounting.tsx:29-37,122-131`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:160-182`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **mittel** — Methodensatz steht schon, Datenabdeckung fehlt · **teilweise**
  - Befund: Der Punkt ist zur Haelfte ueberholt: b.meta.methodDe steht inzwischen in der Methodenkarte der App (apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:199, mit dem Kommentar :195-198, der die Verwechslung mit estimatedNoteDe festhaelt). Es fehlt nur noch die Abdeckung: Web schreibt "Datenabdeckung NN %" bzw. "Fuer diesen Zeitraum liegen keine Messdaten vor" aus data.meta.coverage (apps/web/src/components/reports/PvAccounting.tsx:166). In der App wird meta.coverage nirgends gelesen - grep auf "coverage" in DuckCurveHome/ trifft nur RechnungenSeite.swift:122 (anderes meta) und SystemSeiten.swift:494,500,521; das Feld ist da: Schema.swift:6370 (PvTaxMetaOut.coverage, optional).
  - Vorlage: `apps/web/src/components/reports/PvAccounting.tsx:163-172`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:184-201`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **mittel** — Zeitraumvergleich Tag/Woche/Monat/Jahr fehlt ganz
  - Befund: Web holt ueber useMultiPeriod alle vier Spannen zum Ankertag parallel (apps/web/src/components/reports/PvAccounting.tsx:56 mit useReport.ts:55-77) und stellt fuenf Kennzahlen als PeriodStrip nebeneinander (PvAccounting.tsx:151-161, Bauteil PeriodStrip.tsx:32-60). In der App laedt Berichtsseite genau einen Zeitraum (Bericht.swift:29-59, Aufruf GeldSeiten.swift:123-124) und bietet hier nur .monat und .jahr an (:123). Ein Vergleichsbauteil existiert nicht: grep auf "Vergleich" in DuckCurveHome/ trifft in GeldSeiten.swift nur den "Vergleichslauf" der KostenSeite (:24,:9); in Bausteine/ und Diagramme/ gibt es kein Gegenstueck zu PeriodStrip.
  - Vorlage: `apps/web/src/components/reports/PvAccounting.tsx:56,151-161`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:123-124`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **klein** — Summenzeile und Rundungshinweis fehlen der Tabelle
  - Befund: Web baut aus b.totals eine hervorgehobene Summenzeile ueber alle sieben Spalten (apps/web/src/components/reports/PvAccounting.tsx:77 sum = rowOf("Summe", t), gerendert :132-141) und schliesst mit dem Rundungshinweis :145-148. Die App-Tabelle bekommt nur die buckets (GeldSeiten.swift:161-181), b.totals wird dort nicht uebergeben. Auch der Satz fehlt: grep auf "ungerundet", "Summenzeile" und "Summe" in DuckCurveHome/ liefert keinen Treffer in GeldSeiten.swift. Zu beachten: das Bauteil Tabelle (Bericht.swift:153-256) kennt nur zeilennamen und spalten, keine abgesetzte Summenzeile - sie muss dort erst vorgesehen oder als zusaetzliche Zeile mit Hervorhebung geloest werden.
  - Vorlage: `apps/web/src/components/reports/PvAccounting.tsx:77,132-148`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:159-183`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`
- **klein** — Mittlerer Wert je kWh des Eigenverbrauchs fehlt
  - Befund: Web haengt an die Kachel "Wert des Eigenverbrauchs" den Beisatz `netto, Ø x,xx ct/kWh` aus totals.self_ct_kwh (apps/web/src/components/reports/PvAccounting.tsx:96 mit dem Helfer ct() :15). In der App kommt selfCtKwh nirgends vor: grep -rn "selfCtKwh" ueber apps/ios trifft ausschliesslich Schema.swift:6454,6473,6480,6493,6514, also nur die Modelldefinition. Die Kachelreihe kennzahlen(_:) (GeldSeiten.swift:205-226) zeigt bei "selbst verbraucht" nur selfValueNetEur brutto/netto (:217-220) und als Satz nur feedInCtKwh als "Verguetungssatz" (:221-223), was der Einspeisesatz ist, nicht der Eigenverbrauchswert; die Karte "Eigenverbrauch" (:141-158) liest das Feld ebenfalls nicht.
  - Vorlage: `apps/web/src/components/reports/PvAccounting.tsx:96`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:141-158,205-226`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift`

### `/geld/rechnungen`  ·  9 Punkte, davon 3 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Kein PDF-Einlesen und Pruefzustand in der App
  - Befund: Gesucht in ganz apps/ios/DuckCurveHome/ nach fileImporter, UIDocumentPicker, UTType, PhotosPicker, ".pdf" und pruefeRechnung - kein Treffer. Die Seite ruft nur ladeListe (RechnungenSeite.swift:213-224) und ladeBericht (RechnungenSeite.swift:226-232); haus.api.pruefeRechnung existiert im Kern (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:403) und wird von keiner View aufgerufen. Der Leerzustand verweist auf den Dienst (RechnungenSeite.swift:28-32), genau wie behauptet.
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:54-93,137-159,212`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:26-33,213-232`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **spürbar** — Keine vier Kennzahlen ueber den ganzen Bestand
  - Befund: InvoiceSummaryOut kommt in der ganzen App nur an drei Stellen vor (RechnungenSeite.swift:15,52,216); gesucht nach reduce in apps/ios/DuckCurveHome/Seiten/Geld/ - kein Treffer, also wird nirgends ueber liste summiert. kennzahlen(_:) (RechnungenSeite.swift:199-211) liest ausschliesslich b.invoice der einen gewaehlten Rechnung; die Liste selbst ist eine reine Aufzaehlung (RechnungenSeite.swift:52-73) ohne Anzahl, Zeitspanne von-bis, Summe brutto oder mengengewichteten Durchschnitt.
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:194-196,219-224`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:34-46,199-211`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **spürbar** — Keine drei Verlaufsdiagramme ueber alle Rechnungen
  - Befund: Die Seite besteht aus Stoerung, Leer, Karte mit Liste und pruefung(_:) - Kachelfeld, Befundkarte, Messkarte, Positionstabelle, Methode (RechnungenSeite.swift:21-50,104-151); kein Balkenbild, keine TageskurveBild, kein anderes Bild. Gesucht nach Invoice und rechnung in apps/ios/DuckCurveHome/Diagramme/ und Bausteine/ - nur ein Treffer in Energiefluss.swift, der nichts mit Rechnungen zu tun hat. Balkenbild existiert als Baustein (apps/ios/DuckCurveHome/Seiten/Bericht.swift:66) und wird hier nicht benutzt.
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:161-188,229-243`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:21-50,104-151`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **mittel** — Preisbestandteile nur als Tabelle, group ungenutzt
  - Befund: Die Positionen stehen als Tabelle mit ct/kWh und Betrag (RechnungenSeite.swift:130-143); gesucht nach ".group" in ganz apps/ios/DuckCurveHome/ - kein Treffer, obwohl InvoicePosition.group ein nicht-optionales Feld ist (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:4700,4707). Damit fehlen das Diagramm und die Gruppierung; die Werte selbst sind in der Tabelle sichtbar, einen Hinweis "Rechnung auswaehlen" gibt es nicht, weil die Karte ohne Bericht gar nicht erscheint.
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:189-192,244-251`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:130-143`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **mittel** — Abrechnungszeitraum als Datum und Zaehlerstaende fehlen
  - Befund: Gesucht in ganz apps/ios/DuckCurveHome/ nach meterStart, meterEnd, meterEstimated, periodStart, periodEnd sowie nach "Zaehlerstand/Zählerstand" - kein einziger Treffer, obwohl alle fuenf Felder in TibberInvoice vorhanden sind (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:8296-8303,8318-8325). Die App zeigt tatsaechlich nur periodLabel und issuedOn in der Zeile (RechnungenSeite.swift:58-59) und periodLabel als dazu-Text an der Brutto-Kachel (RechnungenSeite.swift:202).
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:322-326`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:52-73,199-211`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **klein** — Keine Quote stimmig, kein Hinweis bei fehlendem Abgleich
  - Befund: Die App zeigt alle Befunde in einer Karte "Was aufgefallen ist" hinter if !b.findings.isEmpty mit einer ForEach ueber alle (RechnungenSeite.swift:107-115); gesucht nach "stimmig" und "Kein Abgleich" in ganz apps/ios/DuckCurveHome/ - kein Treffer. Es gibt auch keine Trennung in rechnerische Pruefung und Abgleich mit eigenen Daten wie im Dashboard (computed/compared, InvoiceCheck.tsx:201-202). Die Messkarte (RechnungenSeite.swift:116-129) steht nur, wenn b.measured da ist, sonst ohne Satz.
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:307-320`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:107-115`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **klein** — Abweichung mit Vorzeichen fehlt am Befund
  - Befund: befund(_:) liest nur f.expected und f.actual (RechnungenSeite.swift:183-194); gesucht nach ".delta" in apps/ios/DuckCurveHome/Seiten/Geld/ und nach "Abweichung" in ganz apps/ios/DuckCurveHome/ - der einzige Treffer auf dieser Seite ist der Methodensatz "Eine Abweichung ist eine Frage, kein Beweis" (RechnungenSeite.swift:148), keine Zahl. InvoiceFinding.delta ist vorhanden (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:4661,4671).
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:44`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:183-194`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **klein** — Keine Vorauswahl der neuesten Rechnung
  - Befund: gewaehlt startet als nil (RechnungenSeite.swift:16), wird nur im Button der Zeile gesetzt und dort sogar wieder abgewaehlt (RechnungenSeite.swift:53-55), und ladeBericht gibt bei nil sofort nil zurueck (RechnungenSeite.swift:226-230). In ladeListe (RechnungenSeite.swift:213-224) wird gewaehlt nicht belegt - also bleibt der untere Teil leer, bis man tippt. Das Dashboard waehlt dagegen ?nr= oder items[0] vor (InvoiceCheck.tsx:130-135).
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:127-135`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:16,53-55,226-230`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`
- **klein** — Fehler beim Laden einer einzelnen Rechnung verschluckt
  - Befund: ladeBericht schreibt bericht = try? await haus.api.rechnung(nummer) (RechnungenSeite.swift:231) - der Fehler wird vom try? verworfen und fehler nicht gesetzt; fehler wird nur in ladeListe belegt (RechnungenSeite.swift:218-222), und Stoerung haengt an dieser Variable (RechnungenSeite.swift:23-25). Die in ABGLEICH.md genannten Zeilen 198-204 sind veraltet, die Stelle ist jetzt 226-232.
  - Vorlage: `apps/web/src/components/reports/InvoiceCheck.tsx:117-125`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:226-232`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift`

### `/strom/jahr`  ·  4 Punkte, davon 1 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Raster liest Tag×Stunde als Wochen, nur Stunden 0-6 sichtbar
  - Befund: Der Dienst liefert `metrics: dict[str, list[list[float|None]]]` als „Kennzahl → [Tag][Stunde 0-23]" (apps/api/src/dch_api/schemas.py:617, Klassendoku 607-612 „365 Spalten, 24 Zeilen"), und das Web durchlaeuft genau das mit `for (let h = 0; h < 24; h++) { const v = grid[d]?.[h] }` (apps/web/src/components/reports/charts.ts:447-451). Die iOS-Seite benennt dieselbe aeussere Achse `wochen` (apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:176-178 „Der Dienst liefert sie als Wochenzeilen") und zeichnet je Spalte nur `ForEach(0..<7)` mit `wochen[woche][tag]` (ebd. 163-168, 181) - die innere Achse ist aber die Stunde, also bleiben je Tag die Stunden 0-6 und die uebrigen 17 fehlen im Bild. Auch die Kennzahlen zaehlen auf dieser falschen Grundlage („Tage mit Werten" = Zahl der Stundenwerte, ebd. 106, 117).
  - Vorlage: `apps/web/src/components/reports/charts.ts:443-452`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:163-168,176-181`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift`
- **mittel** — Felder der Karte nicht antippbar, keine Wiedergabe der Stunde
  - Befund: Im Web traegt das Diagramm `onKlick={zurWiedergabe}` (apps/web/src/components/reports/YearMap.tsx:127), das aus Feldkoordinate x/y Tag und Stunde macht und `router.push("/waerme/wiedergabe?day=…&t=…")` ausfuehrt (ebd. 76-84), und das Hinweisfenster kuendigt es an (`klickHinweis: "Klick oeffnet die Wiedergabe dieser Stunde"`, ebd. 68; ausgewertet in charts.ts:440-442). In der iOS-Datei ist `feld(woche:tag:)` ein blosses `RoundedRectangle` mit `.fill`/`.frame`/`.accessibilityHidden` (JahreskarteSeite.swift:180-186); gesucht nach `onTapGesture`, `Button`, `gehe`, `wiedergabe` und `wegweiser` in der ganzen Datei - die einzigen Buttons sind die Kennzahlreiter (57) und die Jahrespfeile (75,78), und das eingebundene `wegweiser` (13) wird nirgends benutzt.
  - Vorlage: `apps/web/src/components/reports/YearMap.tsx:68,76-84,127`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:180-186`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift`
- **mittel** — Keine zweiseitige Netz-Skala, kein 98. Perzentil
  - Befund: Web: `grid_net_kwh` ist Vorgabe (`useState<MetricKey>("grid_net_kwh")`, apps/web/src/components/reports/YearMap.tsx:37) und als einzige Kennzahl `diverging: true` mit `RAMP_NET` (ebd. 17), bernstein→neutral→mist (charts.ts:412-413); die Grenze ist `robustMax` = 98. Perzentil, bei divergierend ueber die Absolutwerte (charts.ts:418-424, 457-459). iOS: `farbe(_:)` normiert stattdessen auf `alle.max()` und klemmt mit `min(1, max(0, wert / hoechster))` (JahreskarteSeite.swift:190-196), womit jeder negative Wert auf Stufe 0 faellt - dieselbe Farbe wie die schwaechste Bezugsstunde. Die Skala ist die einseitige fuenfstufige `Marken.waerme` „kalt nach heiss" (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Gestalt/Marken.swift:129-132 ueber Farben.swift:72) mit der Legende nur „wenig"/„viel" (JahreskarteSeite.swift:127-136). Nach `Perzentil`, `perzentil`, `robust` und einer zweiten Rampe im ganzen iOS-Baum gesucht: kein Treffer.
  - Vorlage: `apps/web/src/components/reports/YearMap.tsx:17,37 und apps/web/src/components/reports/charts.ts:413-424,457-459`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:127-136,190-196`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift`
- **klein** — Kein Satz fuer ein Jahr ohne Stundenwerte, kein Werteumfang min-max
  - Befund: Web: bei `data.hours_with_data === 0` steht statt des Diagramms „Fuer {year} liegen keine Stundenwerte vor." (apps/web/src/components/reports/YearMap.tsx:127), und die Fussnote nennt `Werteumfang {min} bis {max}` aus `extremes` (ebd. 85-89, 137). iOS: der `else`-Zweig greift nur, solange `karte == nil` ist, also waehrend des Holens („Wird geholt …", JahreskarteSeite.swift:39-41); sobald eine Antwort da ist, wird `Raster` gezeichnet, auch wenn `hoursWithData == 0` - ein Zweig fuer diesen Fall fehlt in 26-41. Nach `Werteumfang`, `Perzentil`, `Stundenwerte` und `hoursWithData` im ganzen iOS-Baum gesucht: `hoursWithData` erscheint nur als Zaehler in `Methode` (36) und in der Kachel „Stunden erfasst" (123), nie als Bedingung; ein Mindestwert kommt nirgends vor - die Kennzahlen zeigen nur `werte.max()` als „bester Tag" (118-122).
  - Vorlage: `apps/web/src/components/reports/YearMap.tsx:85-89,127,137`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:26-41,118-123`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift`

### `/strom/pv`  ·  3 Punkte, davon 1 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Prognoseteil fehlt: Prognose heute, morgen, Kurve · **teilweise**
  - Befund: Auf der PV-Seite selbst stimmt es: StromSeite.swift:105-107 fragt ausschliesslich energieUebersicht, und api.plan() (Api.swift:167) bzw. api.verlauf() (Api.swift:133) kommen in der ganzen Datei nicht vor - Suche nach plan(, verlauf, Prognose, pvForecast, expectedPvKw in DuckCurveHome/Seiten/Energie/ ergibt keinen Treffer. Zwei der drei Darstellungen gibt es aber schon, nur auf der Startseite: die Kurve erwartete gegen gemessene PV steht in JetztSeite.swift:114-128 ueber Tageskurve.swift:164-171 (k.pvErwartet aus plan.intervals, mit Tagwahl heute/morgen statt beides in einem Bild), und "Sonne erwartet" in kWh fuer morgen in Tageskacheln.swift:91-93 mit der Summe aus Tageskacheln.swift:115-125; dazu das Band "Sonne erwartet" in Ausblickkarte.swift:103-108, eingebunden ueber Leiste.swift:32. Wirklich nirgends in der App: die Tagesprognose fuer heute als Zahl - pvForecastTodayKwh wird in keinem App-Code gelesen, nur in Vorschau.swift:261 und in Tests (NetzLaufTests.swift:55, FahrplanbildTests.swift:40).
  - Vorlage: `apps/web/src/components/reports/PvReport.tsx:96-97, 106-109 (Stat "Prognose heute"/"Prognose morgen", Karte "Heute und morgen"), Summen in :24-36`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:103-127 (PvSeite holt nur api.energieUebersicht, kein api.plan(), kein api.verlauf())`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **mittel** — Kein Mehrspannen-Vergleich "PV im Ueberblick", keine zusammengesetzte Ersparnis
  - Befund: Einen Baustein wie PeriodStrip gibt es in der App nicht: Suche nach PeriodStrip, Spannenstreifen, Ueberblick und "im Ueberblick" ueber alle .swift unter apps/ios ergibt keinen Treffer, und DuckCurveHome/Bausteine/ enthaelt nichts Entsprechendes. Es holt auch keine Seite mehr als eine Spanne zugleich - jeder Aufruf von energieUebersicht nimmt z.spanne.rawValue (StromSeite.swift:11, 106, 161; GeldSeiten.swift:15) oder fest "day" (JetztSeite.swift:211, 219, 239); ein Gegenstueck zu useMultiPeriod fehlt. Die zusammengesetzte Ersparnis fehlt ebenfalls: pvDirectSavingsEur steht nur in StromSeite.swift:143 ("ersparte Kosten"), batteryNetEur nur in StromSeite.swift:229 auf der Speicherseite ("unterm Strich"); die Summe der beiden kommt in keiner Datei vor.
  - Vorlage: `apps/web/src/components/reports/PvReport.tsx:111-120 (PeriodStrip "PV im Ueberblick", Ersparnis = pv_direct_savings_eur + battery_net_eur), Baustein apps/web/src/components/reports/PeriodStrip.tsx:32-93`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:103-127 (PvSeite: Kachelfeld, ein Balkenbild, Methode - kein Streifen)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **klein** — Kachel "eingespeist" ohne Erloes und ohne Verguetungssatz
  - Befund: Die Kachel in StromSeite.swift:137-140 traegt nur exportKwh und kein dazu:. Beide Felder gibt es im Schema und in genau der Antwort, die PvSeite schon laedt: exportRevenueEur in Schema.swift:3004 (EnergyTotalsOut) und feedInCtKwh in Schema.swift:2834 (EnergyMetaOut, haengt an EnergySummaryOut.meta, Schema.swift:2949). Benutzt werden sie in der App nur auf den Geldseiten - exportRevenueEur in GeldSeiten.swift:68, 90, 105 ("Einspeisung" auf /geld) und ein Verguetungssatz in GeldSeiten.swift:222, dort aber aus PvTaxTotals auf /geld/pv-abrechnung, nicht aus meta. Auf /strom/pv kommt keines von beiden vor; Suche nach exportRevenueEur, export_revenue, feedInCtKwh, Erloes und Verguetungssatz unter DuckCurveHome/Seiten/Energie/ ergibt keinen Treffer. Euro ist auf der Seite nicht tabu - "ersparte Kosten" steht in StromSeite.swift:143 -, es ist also eine reine Anzeigeluecke.
  - Vorlage: `apps/web/src/components/reports/PvReport.tsx:90 (hint `Erloes ${eur(t.export_revenue_eur)} bei ${de1(data?.meta.feed_in_ct_kwh, 1)} ct`)`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:137-140 (Kacheldaten "eingespeist" mit exportKwh, ohne dazu:)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`

### `/strom/speicher`  ·  6 Punkte, davon 2 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Verlust im Geraet mit Kosten und entgangenem Erloes fehlt
  - Befund: Web zeigt die Kachel in apps/web/src/components/reports/BatteryReport.tsx:138-144 (battery_device_kwh, battery_device_cost_eur, battery_device_opportunity_eur). Gesucht in der App nach batteryDevice, battery_device, "Verlust", "Ger" ueber apps/ios/DuckCurveHome/ - kein Treffer (batteryDevice* nur in apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:2991-3010, von keiner Seite gelesen; "Verlust" nur in Waermebildern, z.B. apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift:425). Nur der Pruefbericht im Kartentext (apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:190-199) beruehrt den Begriff qualitativ ueber eine andere Groesse (Ladestandsdifferenz, packages/hems-core/src/hems_core/accounting/battery_check.py:566-567) - ohne kWh-Kachel und ohne Euro.
  - Vorlage: `apps/web/src/components/reports/BatteryReport.tsx:138-144`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:208-233`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **spürbar** — Ladezustand ueber den Tag als Minutenverlauf fehlt ganz
  - Befund: Web holt die Minutenzeilen (apps/web/src/components/reports/BatteryReport.tsx:58-81) und zeichnet SoC ueber Leistung (BatteryReport.tsx:157-161, apps/web/src/components/reports/charts.ts:236). Die SpeicherSeite holt nur energieUebersicht und speicherPruefung (apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:157-163), kein api.verlauf/verlaufTag. batterySoc kommt in der App nur als Augenblickswert vor (apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift:56, apps/ios/DuckCurveHome/Bausteine/Energiefluss.swift:233,267); die Tageskurve fuehrt PV, Haus, Waermepumpe und Preis, aber keine Batterie (kein Treffer fuer soc/batter in apps/ios/DuckCurveHome/Diagramme/Tageskurve.swift), Fahrplanzeichnung ebenfalls nicht.
  - Vorlage: `apps/web/src/components/reports/BatteryReport.tsx:157-161`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:155-206`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **mittel** — Vollzyklen fehlen, Kapazitaet steht im Pruefbericht · **teilweise**
  - Befund: Vollzyklen fehlen wirklich: gesucht nach Zyklen, Vollzyk, batteryCapacityKwh in apps/ios/DuckCurveHome/ - kein Treffer (battery_capacity_kwh nur in apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:2833 und in Tests), web rechnet sie in apps/web/src/components/reports/BatteryReport.tsx:94 und zeigt sie in :115 und :168. Die Kapazitaet dagegen steht auf der iOS-Seite: der Pruefbericht im Kartentext (apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:190-199) beginnt mit "Kapazitaet x.x kWh" (apps/api/src/dch_api/application/energy_accounting.py:623). Das capacityKwh in apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift:92 ist der Waermepuffer, nicht die Batterie.
  - Vorlage: `apps/web/src/components/reports/BatteryReport.tsx:94, 103, 115`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:208-233`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **mittel** — Untergrenze des Ladestands laesst sich nirgends stellen
  - Befund: Web stellt reserve_soc auf dieser Seite (apps/web/src/components/reports/BatteryControl.tsx:103-117, send() mit reserve_soc in :54, eingehaengt in BatteryReport.tsx:146). Die SpeicherSeite der App hat keine Bedienung (apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:155-206). Einziger Sendeweg der App ist apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:536-537: BatteryModeIn(mode: art, durationMin: 240), reserveSoc bleibt nil; dort wird die Reserve nur angezeigt (MitteilungenSeite.swift:462-464). Gesucht nach reserveSoc/Untergrenze in der ganzen App - sonst nur Schema und ein unverwandter Achsenbegriff in Fahrplanbild.swift.
  - Vorlage: `apps/web/src/components/reports/BatteryControl.tsx:103-117`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:536-537`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **klein** — PV-Anteil als Prozent fehlt, Wirkungsgrad im Pruefbericht · **teilweise**
  - Befund: Der PV-Anteil der Ladung als Prozentwert fehlt wirklich: apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:208-233 nennt nur pvToBatteryKwh und gridToBatteryKwh in kWh; Formate.prozent kommt auf der Speicherseite nicht vor (im Strombereich nur in der Wallbox-Tabelle, StromSeite.swift:255), waehrend Web ihn in apps/web/src/components/reports/BatteryReport.tsx:95 rechnet und in :124 und :169 zeigt. Der Wirkungsgrad dagegen steht im Pruefbericht, den die App als Karte "Nachgerechnet" zeigt (StromSeite.swift:190-199): "Ladewirkungsgrad x %" aus packages/hems-core/src/hems_core/accounting/battery_check.py:639-643 - im Web ist die Kachel ohnehin nur die Ausweichanzeige, wenn der Ladestandsvergleich fehlt (BatteryReport.tsx:134).
  - Vorlage: `apps/web/src/components/reports/BatteryReport.tsx:95-96, 124, 134`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:208-233`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **klein** — Mehrspannen-Streifen Speicher im Ueberblick fehlt
  - Befund: Web haelt Tag, Woche, Monat, Jahr nebeneinander (apps/web/src/components/reports/BatteryReport.tsx:54 useMultiPeriod und :162-171 PeriodStrip, Bauteil apps/web/src/components/reports/PeriodStrip.tsx:32). Die SpeicherSeite laedt genau einen Zeitraum ueber Berichtsseite (apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:157-163, Gerippe in apps/ios/DuckCurveHome/Seiten/Bericht.swift:29-59, das nur wegweiser.zeitraum holt). Gesucht nach "berblick" in apps/ios/DuckCurveHome/ - kein Treffer; ein vergleichbarer Mehrspannen-Block existiert in der App nur fuer Waerme (apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift:50 und :317), nicht fuer den Speicher.
  - Vorlage: `apps/web/src/components/reports/BatteryReport.tsx:162-171`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:155-206`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`

**Keine Lücke, nach Prüfung am Code:**

- ~~Guetehinweis zu Stundenmitteln steht in der Methode~~ – Der Hinweis steht auf der iOS-Seite, nur anders platziert: apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:200-204 zeigt meta.estimatedNoteDe, und dieser Text traegt den Stundenmittel-Zusatz selbst - apps/api/src/dch_api/application/energy_accounting.py:1181 haengt coarse_note(totals) an, das in :359-363 "Fuer n Stunden (x %) liegen nur Stundenmittel aus dem Historienimport vor ... die Aufteilung auf PV und Netz ist geschaetzt" liefert. Das Dashboard zeigt denselben Satz ebenfalls in der Methode (apps/web/src/components/reports/ReportShell.tsx:171) und wiederholt ihn zusaetzlich an den Herkunftskacheln (BatteryReport.tsx:92-93, 106, 112, 124). Es fehlt also nur die Wiederholung an der Kachel, nicht der Hinweis.

### `/strom/wallbox`  ·  5 Punkte, davon 2 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Kein Balkenbild der Ladung nach Herkunft
  - Befund: WallboxSeite besteht aus Kachelfeld, Karte mit Tabelle und Methode - kein Chart (StromSeite.swift:237-272); gesucht nach Balkenbild, Chart, Stapel, gestapelt und buckets im ganzen Seitenbaum: StromSeite.swift nennt buckets nur in der StromSeite selbst (StromSeite.swift:52-81, 88-96, 113-117), nie in der WallboxSeite, und 'Balkenbild' kommt in StromSeite.swift an den Zeilen 15, 18, 110, 168, 180 vor, also ausschliesslich oberhalb von Zeile 236. Der Baustein ist da und passt genau (Bericht.swift:66-116, BarMark mit stacking .standard je Beschriftung), und die Felder je Bucket gibt es (Schema.swift:3001 evBatteryKwh in den Totals, die auch die Buckets tragen) - es fehlt nur der Aufruf. Das 'Verbrauch'-Bild auf /strom (StromSeite.swift:69-83) zeigt evKwh als einen Stapelteil des Hausverbrauchs, nicht die Herkunft der Ladung, ist also nicht dasselbe Bild.
  - Vorlage: `apps/web/src/components/reports/EvReport.tsx:14-18, 31, 46-51`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:241-271`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **spürbar** — Sonnenanteil in Prozent und Batterieanteil fehlen
  - Befund: Die sechs Kacheln der WallboxSeite sind geladen, Ladevorgaenge, aus der Sonne (evPvKwh, kWh), aus dem Netz (evGridKwh, kWh), Kosten, entgangene Einspeisung (StromSeite.swift:276-288) - kein Prozentwert fuer den Zeitraum und kein Batterieanteil. evBatteryKwh existiert im Schema (Schema.swift:3001, Codingschluessel ev_battery_kwh Schema.swift:3051), wird aber in der gesamten App nicht gelesen: grep nach evBatteryKwh in apps/ios trifft nur Schema.swift und ABGLEICH.md, und grep nach evKwh/evPvKwh/evGridKwh/evCostEur/evOpportunityEur in DuckCurveHome trifft nur StromSeite.swift:81 und 277-285. Einzige Einschraenkung: einen Prozentwert gibt es auf der Seite in der Spalte 'Sonnenanteil' je Ladevorgang (StromSeite.swift:253-256, Feld pvShare aus Schema.swift:3241), also je Vorgang, nicht fuer den Zeitraum und ohne Batterie - die Kennzahl selbst fehlt.
  - Vorlage: `apps/web/src/components/reports/EvReport.tsx:28, 40`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:274-289`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **mittel** — Effektivpreis je kWh und mittlerer bezahlter Netzpreis fehlen
  - Befund: Die Vorlage rechnet effCt = (ev_cost_eur + ev_opportunity_eur) / ev_kwh (EvReport.tsx:30, Kachel Zeile 44) und paidCt = ev_cost_eur / ev_grid_kwh (EvReport.tsx:29, als Hinweis an der Netzkachel Zeile 41). In der App kommt keine der beiden Groessen vor: grep ohne Gross-Kleinschreibung nach effektiv, ct/kWh, 'je kWh' und bezahlt in apps/ios/DuckCurveHome trifft ct/kWh nur in GeldSeiten.swift:110 und 222, RechnungenSeite.swift:125/136/205, SystemSeiten.swift:320, FahrplanSeiten.swift:248, Ausblickkarte.swift:45, Leiste.swift:168 und Fahrplanzeichnung.swift:29 - alles Preis- und Rechnungsseiten, keine Wallbox. Die Kachel 'aus dem Netz' (StromSeite.swift:282) hat gar kein dazu-Feld, die Kachel 'Kosten' (StromSeite.swift:283) nur den Euro-Betrag. Formate.ct gibt es (Formate.swift:93), es wird hier nur nicht gerufen.
  - Vorlage: `apps/web/src/components/reports/EvReport.tsx:29-30, 41, 44`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:274-289`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **klein** — Tabelle ohne Dauer und ohne jüngste Ladung oben
  - Befund: Die iOS-Tabelle hat die Zeilennamen 'hh:mm – hh:mm' aus Formate.hhmm (StromSeite.swift:248-250) und die fuenf Spalten kWh, Sonnenanteil, Netz, Kosten, mittlere Leistung (StromSeite.swift:251-266) - keine Dauerspalte; die Vorlage fuehrt Dauer als eigene Spalte und rechnet sie aus start/end (EvReport.tsx:61, 71, 75). Sortiert wird nichts: grep nach sorted und reversed in StromSeite.swift bleibt leer, b.sessions wird in der Reihenfolge des Dienstes gemappt, waehrend die Vorlage absteigend nach start sortiert (EvReport.tsx:32). Der Baustein fuer die Dauer ist vorhanden und wird anderswo genutzt (Formate.dauer(minuten:) in Formate.swift:105-111, z. B. WaermepumpeSeiten.swift:234); EvSessionOut hat kein Dauerfeld (Schema.swift:3237-3254), die Minuten muessen also wie im Web aus start und end gerechnet werden.
  - Vorlage: `apps/web/src/components/reports/EvReport.tsx:32, 61, 71, 75`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:243-269`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`
- **klein** — Abschnitt Wallbox im Überblick über vier Spannen fehlt
  - Befund: Die Vorlage holt alle vier Spannen zum selben Anker (useMultiPeriod, EvReport.tsx:26, 33) und stellt Geladen, Sonnenanteil, Bezahlt und Ladevorgaenge nebeneinander (EvReport.tsx:91-100). Die WallboxSeite holt genau eine Antwort zum gewaehlten Zeitraum (StromSeite.swift:239-240 ueber Berichtsseite, Bericht.swift:29-51) und zeigt auch nur diese; grep nach PeriodStrip, Spannenstreifen, 'im Überblick' und useMultiPeriod in apps/ios trifft nichts. Dasselbe Muster gibt es in der App schon, aber nur auf der Waermeseite: WaermeSeite.swift:50 holt alle Spanne.allCases, WaermeSeite.swift:182 und 313-317 stellen sie als Tabellenspalten nebeneinander - auf der Wallboxseite fehlt es.
  - Vorlage: `apps/web/src/components/reports/EvReport.tsx:91-100`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:237-272`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift`

### `/system/daten`  ·  4 Punkte, davon 2 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Messreihen des Tages als kW-Überlagerung fehlen
  - Befund: Die DatenSeite holt in lade() nur abdeckung, datenbestand und diagnose (apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:612-628); verlaufTag(_:) (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:155) wird nur in apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:214,250 und apps/ios/DuckCurveHome/App/Hauszustand.swift:250 gerufen. Die einzige Tageszeichnung der App (apps/ios/DuckCurveHome/Diagramme/Tageskurve.swift:56-110) kennt nur pv, pvErwartet, haus, waermepumpe, schatten, preis (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Tageskurve.swift:77-99) - Netz, Speicher, Ladestand und amtlicher Zaehler kommen in ihr nicht vor (grep netz/batterie in Tageskurve.swift: kein Treffer). Erschwerend: Minutenraster.punktAusZeile (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Verlauf.swift:77-90) liest battery_soc und grid_power_meter_kw gar nicht ein, waehrend die Webreihen genau daraus bestehen (apps/web/src/components/reports/charts.ts:754, 765-768).
  - Vorlage: `apps/web/src/components/reports/DataCheck.tsx:38, 71-86; apps/web/src/components/reports/charts.ts:720-774`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:612-628`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (dazu eine neue Zeichnung in apps/ios/DuckCurveHome/Diagramme/ und zwei Felder in apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Verlauf.swift)`
- **spürbar** — Karte Quellen: online je Quelle plus Schaltzeile · **teilweise**
  - Befund: Der Quellenteil fehlt wirklich: SourceStatusOut (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:7775) wird in der ganzen App nirgends verwendet (grep SourceStatusOut trifft nur Schema.swift:7775, 8199, 8222, 8247), detailDe wird nur in apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:180 fuer einen anderen Typ gelesen; von den drei Quellen steht nur die Bruecke verkuerzt auf einer anderen Seite (apps/ios/DuckCurveHome/App/Einrichten.swift:287, "Bruecke verbunden/nicht verbunden", ohne Zaehler, Abfragen, Alter). Die mitgenannte Schaltzeile ist dagegen schon da, nur anderswo: apps/ios/DuckCurveHome/Bausteine/Blaetter.swift:353-354 zeigt hpActuation als "Schalten freigegeben/gesperrt" mit hpActuationDe, ebenso apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:48 und apps/ios/DuckCurveKit/Sources/DuckCurveKit/Zustand/Fahrplankacheln.swift:47.
  - Vorlage: `apps/web/src/components/reports/DataCheck.tsx:91-96; apps/web/src/components/reports/Sources.tsx:47-81`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:505-571 (keine Quellenkarte); Teilstueck vorhanden in apps/ios/DuckCurveHome/Bausteine/Blaetter.swift:353-354`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **mittel** — Abdeckung je Stunde als Flaeche fehlt
  - Befund: Das Feld traegt die Stundenwerte (CoverageSeriesOut.hours, apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:2365), wird aber nirgends gelesen: der einzige Treffer fuer .hours ausserhalb des Schemas ist ein Doc-Kommentar in apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Mischwert.swift:10. Die App fasst stattdessen je Reihe eine Tabellenzeile zusammen (apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:511-546: vollstaendig, Minuten, lueckige Stunden, laengste Luecke, zuletzt). Ein Tagesraster kann die App zwar zeichnen, aber nur fuer Energiemengen und nicht fuer Abdeckung je Stunde (apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:11-33, YearMapOut); die Unterscheidung leere gegen rote Zelle gibt es dort nicht.
  - Vorlage: `apps/web/src/components/reports/CoverageMap.tsx:34-43, 104-131`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:511-546`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **mittel** — CSV-Export der Minutenwerte fehlt ganz
  - Befund: Auf der DatenSeite steht nur Abdeckung, Datenbestand, Tagesdiagnose und Methode (apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:505-571), kein Knopf und kein Verweis. Gesucht nach ShareLink, fileExporter, UIActivity, Transferable, UTType, ".csv", "export/minutes", "export/hours" und "/export" in apps/ios/DuckCurveHome und apps/ios/DuckCurveKit/Sources: kein Treffer; apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift enthaelt das Wort export ueberhaupt nicht, es gibt also auch keine Client-Methode dafuer. Die Treffer auf "export" in den Seiten sind durchweg exportKwh/exportRevenueEur, also Einspeisung, nicht Herunterladen.
  - Vorlage: `apps/web/src/components/reports/DataCheck.tsx:52-56, 100-110`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:505-571`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (dazu eine Export-Methode in apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift)`

### `/system/haustuer`  ·  1 Punkte  ·  *gegengeprüft 17.11.*

- **mittel** — Tuerprotokoll ohne Tagesgruppe und ohne Datum
  - Befund: Web gruppiert wirklich je Kalendertag: groupByDay in apps/web/src/components/settings/DoorLog.tsx:48-57, dayLabel (Heute/Gestern/sonst Wochentag + Tag + Monat) in :24-32, und :121-134 zeichnet je Gruppe eine eigene Kachel mit dayLabel als Ueberschrift. Die iOS-Seite HaustuerSeite (apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:632-707) baut ab :657-668 eine flache VStack-Liste direkt ueber p.entries, ohne jede Gruppierung, und eintrag(_:) gibt als einzige Zeitangabe Formate.hhmm(iso: e.at) aus (:691), also nur hh:mm (Formate.swift:131-134). Ich habe im ganzen Bereich :631-708 nach Tag, Datum, Heute, Gestern, wochentag, gruppiert und Dictionary(grouping gesucht - kein Treffer; die vorhandenen Helfer Tag.nameRelativ (Tag.swift:102-108) und Formate.langesDatum (Formate.swift:167-171) werden hier nicht benutzt. Die Spanne stimmt ebenfalls: Tagewahl bietet 7, 30, 90 (:641), waehrend das Web nur 7, 14, 30 kennt (DoorLog.tsx:22), der Zeitraum ohne Datum ist in der App also noch laenger. Nur die Zeilenangaben des Punktes sind leicht verschoben (nicht :636-658 und :618, sondern :632-707 mit Liste :657-668 und eintrag :677-696).
  - Vorlage: `apps/web/src/components/settings/DoorLog.tsx:24-32, :48-57, :121-134`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:657-668 (flache Liste), :691 (nur hhmm)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`

### `/system/mitteilungen`  ·  3 Punkte  ·  *gegengeprüft 17.11.*

- **mittel** — details_de je Gerät nach Probe und Briefversand fehlt
  - Befund: Web setzt und zeigt die Liste zweimal: apps/web/src/components/settings/Mitteilungen.tsx:175 (setDetails(antwort.details_de ?? [])) und :246-250 (ul mit details.map), sowie apps/web/src/components/settings/Morgenbrief.tsx:56 und :106-110. In der App nehmen probe() (apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:218-229) und sendeBrief() (:239-247) nur a.messageDe in rueckmeldung; das Feld existiert im Modell (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:6236 detailsDe in PushResultOut, Schlüssel details_de :6242), wird aber nirgends gelesen: grep nach detailsDe und details_de über apps/ios/ trifft außer ABGLEICH.md nur Schema.swift:6236/6242/6245/6249/6257 und Binärdateien in .build. Hinweis: die Zeilenangabe 211-241 in ABGLEICH.md ist um ~7 Zeilen verschoben, die beiden Funktionen stehen bei :218-247.
  - Vorlage: `apps/web/src/components/settings/Mitteilungen.tsx:175,246-250; apps/web/src/components/settings/Morgenbrief.tsx:56,106-110`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:218-229 und :239-247 (fehlt); Feld vorhanden: apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:6236`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift`
- **mittel** — Warnsatz bei keinem angemeldeten Gerät fehlt · **teilweise**
  - Befund: Zwei Teile. Der nackte Satz steht schon in der App, nur auf einer anderen Seite: apps/ios/DuckCurveHome/App/Einrichten.swift:296-299 zeigt in ZugangSeite die Karte "Angemeldete Geräte für Mitteilungen" mit Leer(satz: "Kein Gerät angemeldet.") – also auf /system/zugang, nicht auf /system/mitteilungen. Es fehlt (a) dieser Leerzustand auf der Mitteilungenseite selbst: apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:29-38 hängt die Gerätekarte an `if let g = geraete, !g.devices.isEmpty` ohne else-Zweig, und :161/283/295/476/480/575 sind die einzigen Leer(…) der Datei, keines davon für Geräte; und (b) überall der Warnsatz, dass dann nichts bei jemandem ankommt (Web: apps/web/src/components/settings/Mitteilungen.tsx:255 Kicker "Kein Gerät angemeldet" plus :257-260 "gehen weder Störungen noch das Morning Briefing an jemanden", und apps/web/src/components/settings/Morgenbrief.tsx:99-103 bei stand.geraete == 0). Gesucht in apps/ios/ nach "Kein Gerät", "niemand", "Störung/Stoerung", "geht an", "anmelden": die Stoerung-Treffer sind nur die Fehleransicht, kein Warntext. b.geraete aus MorgenbriefOut (Schema.swift:5607/5617) wird in morgenbrief(_:) (:142-185) nicht ausgewertet; grep nach `.geraete` in DuckCurveHome/ trifft nur geraetename/geraetekennung und die Zustandsvariablen.
  - Vorlage: `apps/web/src/components/settings/Mitteilungen.tsx:252-267; apps/web/src/components/settings/Morgenbrief.tsx:99-103`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:29-38 und :142-185 (fehlt); Teil vorhanden: apps/ios/DuckCurveHome/App/Einrichten.swift:296-299`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift`
- **klein** — Probe an andere Geräte ohne eigene Anmeldung fehlt
  - Befund: Web hat den zweiten Probeknopf unabhängig von der eigenen Lage: apps/web/src/components/settings/Mitteilungen.tsx:238-242 rendert "Probe an die angemeldeten Geräte" bei `lage !== "an" && geraete && geraete.length > 0` (derselbe probe()-Aufruf wie :230-232). In der App steht knopf("Probe senden") allein im Fall .angemeldet des switch über mitteilungen.stand: apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:85, switch bei :66-98; die Fälle .ungefragt (:67-70), .abgelehnt (:71-78), .erlaubt (:79-82) und .fehler (:93-97) bieten nur Text oder den Erlaubnisknopf. Auch die Gerätekarte (:29-38) hat keinen Knopf. grep nach "Probe" und mitteilungProbe über apps/ios/ findet in der App nur :85, :221 und :224 – also genau den einen Pfad.
  - Vorlage: `apps/web/src/components/settings/Mitteilungen.tsx:238-242`
  - In der App: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:66-98 (Probeknopf nur :85, Gerätekarte :29-38 ohne Knopf)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift`

### `/system/zugang`  ·  1 Punkte, davon 1 spürbar  ·  *gegengeprüft 17.11.*

- **spürbar** — Kein Datenexport (Minutenwerte/Stundenbilanz) in der App
  - Befund: Die Webseite hat den Abschnitt "Sicherung" (page.tsx:127) und bietet je Jahr (laufendes und voriges) zwei Download-Links auf /api/dch/export/minutes (page.tsx:138-139) und /api/dch/export/hours (page.tsx:141-142), mit dem Hinweis, dass die Stundenbilanz die Grundlagen der PV-Abrechnung traegt (page.tsx:146-151). In der App rendert Seitenwahl.swift:91-92 fuer /system/zugang die ZugangSeite (Einrichten.swift:254-356); sie hat genau die Karten "Dieses Gerät" (261), "Verbindung" (281), "Angemeldete Geräte für Mitteilungen" (297) und "Ändern" (318) plus Methode-Block - keine Sicherungskarte. Gesucht habe ich im ganzen iOS-Baum (DuckCurveHome und DuckCurveKit/Sources) nach ShareLink, UIActivityViewController, fileExporter, Transferable (null Treffer), nach openURL und Link( (null Treffer), nach export/minutes, export/hours und /export (null Treffer), sowie nach Sicherung, Minutenwerte, Stundenbilanz, herunterlad, download, backup, csv, gzip, archiv, exportier, FileManager, UTType - die Treffer sind ausschliesslich Kommentare, Modellfelder (Schema.swift exportKwh/exportRevenueEur, also Einspeise-Kennzahlen, nicht Dateiexport), der Reitername "Zugang und Sicherung" (Bereiche.swift:148) und unverwandte Dinge (Entscheidungsarchiv MitteilungenSeite.swift:557). Api.swift hat 63 oeffentliche Funktionen, keine davon beruehrt einen Export-Endpunkt (docs/openapi.json kennt /export gar nicht, der Web-Weg laeuft als CSV-Strom ueber den Proxy apps/web/src/app/api/dch/[...path]). Der Reiter heisst in der App also "Zugang und Sicherung", ohne dass es eine Sicherung gibt.
  - Vorlage: `apps/web/src/app/system/zugang/page.tsx:127-151`
  - In der App: `apps/ios/DuckCurveHome/App/Einrichten.swift:254-356`
  - bauen in: `apps/ios/DuckCurveHome/App/Einrichten.swift`

### `/waerme/anlage`  ·  4 Punkte

- **mittel** · bedienung — Im Schema ist jedes Geraet ein Verweis: PV -> /strom/pv, Netz -> /strom, Speicher -> /strom/speicher, Haushalt -> /strom, Waermepumpe und Puffer -> /waerme#puffer, Ofen -> /waerme#ofen, Heizung -> /haus?ansicht=liste, Warmwasser -> /waerme, jeweils mit Beschriftung "<Name>. Details oeffnen". Die Karten der App (Strom, Pufferspeicher, Waermepumpe, Pelletofen, Heizkreise, Warmwasser) sind nicht antippbar und fuehren nirgendwohin.
  - Vorlage: `apps/web/src/components/anlage/schema.ts:197-211 mit apps/web/src/components/anlage/Schema.tsx:114-121`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift`
- **mittel** · abschnitt — Unter dem Bild stehen drei Erklaerblocks, die die App gar nicht hat: "Lesen" (wie Lichtwanderung, Rohrfarbe und Pumpenpunkt zu lesen sind), "Vier getrennte Systeme" (Ofen speist oben ein und holt unten zurueck, Waermepumpe speist in der Mitte ein, Heizkreis nimmt aus der Mitte und gibt unten zurueck, Trinkwasser laeuft unten kalt nach und wird oben entnommen, Ofen und Waermepumpe holen den Ruecklauf gemeinsam an der untersten Spitze) und "Gemessen und gerechnet" (Waerme der Waermepumpe wird nicht gemessen, Vorlauf und COP kommen vom Bus; Ofen aus der Stufe nach Datenblatt geschaetzt; Nettoleistung des Speichers aus den vier Fuehlern ueber die letzte Viertelstunde; Warmwasser wird am Anlegefuehler erkannt, nicht gemessen - sagt dass und seit wann, nicht wie viel). Mindestens die beiden letzten Blocks sind Inhalt und nicht Bildbeschreibung; die iOS-Seite hat keinen einzigen erklaerenden Satz.
  - Vorlage: `apps/web/src/components/anlage/Anlage.tsx:91-124`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift`
- **klein** · zustand — Die Webseite unterscheidet beim Ofen drei Zustaende: nicht present -> "nicht angebunden", present aber running == null -> "keine Verbindung", sonst "Stufe N" bzw. "brennt", dazu "· Pumpe NN %". Die App schreibt in den Kartentitel (o.running ?? false) ? "laeuft" : "aus" - ein Ofen, der gerade nicht meldet, steht dort also als "aus", was eine Behauptung ueber einen nicht gemeldeten Zustand ist.
  - Vorlage: `apps/web/src/components/anlage/schema.ts:174-180`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift`
- **klein** · zustand — Fuer die Heizung sagt die Webseite bei rooms_total == 0 "keine Raeume gemeldet" (statt einer Zahl) und sonst "Raeume nehmen Waerme" / "kein Raum nimmt Waerme". Die App zeigt in diesem Fall "0 von 0" und "Anteil -", ohne den Hinweis, dass gar keine Raeume gemeldet sind.
  - Vorlage: `apps/web/src/components/anlage/schema.ts:192-195 mit apps/web/src/components/anlage/Schema.tsx:382-392`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/AnlageSeite.swift`

### `/waerme/annahmen`  ·  3 Punkte, davon 1 spürbar

- **spürbar** · bedienung — Die Webseite laesst die Annahmen stellen; die App zeigt sie nur. Zu bauen: dreizehn Zahlenfelder (stove_nominal_heat_kw, stove_water_heat_kw, stove_min_heat_kw, stove_min_water_heat_kw, stove_combustion_efficiency, pellet_kwh_per_kg, pellet_price_eur_per_t, buffer_volume_liters, buffer_target_temperature_c, buffer_loss_kw_per_k, buffer_ambient_c, buffer_loss_useful_fraction, indoor_target_c) mit je eigener Schrittweite, dazu die COP-Kennlinie als eine Textzeile im Format "Temperatur:COP" mit Komma getrennt (Pruefung vor dem Senden, sonst die Meldung "Die Kennlinie wird als Temperatur:COP geschrieben, Stuetzpunkte mit Komma getrennt."), ein Knopf "Uebernehmen" / "wird uebernommen …", nach Erfolg der Satz "Uebernommen. Die Auswertungen rechnen ab sofort damit, auch rueckwirkend; der Fahrplan wird neu gerechnet und steht in wenigen Sekunden auf der Seite Fahrplan." und bei Ablehnung die Begruendung des Dienstes (er prueft Widersprueche wie Wasseranteil gegen Gesamtleistung). Nur gesetzte Felder gehen in das Patch. api.stelleWaerme(HeatConfigIn) liegt im iOS-Client bereit (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:387) und wird nicht benutzt; die App schreibt in ihrer Methodenkarte stattdessen, geaendert werde "im Dashboard".
  - Vorlage: `apps/web/src/components/settings/HeatSettings.tsx:29-43 und 120-201`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **mittel** · abschnitt — Die Webseite benennt jede Annahme als Satz mit Einheit und Erklaerung: "Ofen: Leistung bei Volllast (kW)", "Ofen: davon ins Wasser - Der Rest heizt den Aufstellraum.", "Verbrennungswirkungsgrad (0 bis 1) - Datenblatt, Volllast. Bei Teillast ist er meist besser.", "Heizwert der Pellets (kWh/kg) - ENplus A1 liegt zwischen 4,9 und 5,3. Steht auf dem Lieferschein.", "Zieltemperatur des Puffers (°C) - Zugleich der Vorlauf, bei dem die COP-Kennlinie gilt.", "Verlustbeiwert des Puffers (kW/K) - 0,004 kW/K sind 4 Watt je Kelvin Uebertemperatur.", "Aufstellraum des Puffers (°C) - Nicht der Wohnraum … unbeheizter Technikraum 15 bis 18, Keller 10 bis 14.", "davon nutzbar fuers Haus (0 bis 1) - 0 heisst ganz verloren, 1 heisst voll nutzbar.", "Raumtemperatur des Hauses (°C) - Fuer den Heizbedarf aus Heizgradstunden.", dazu der Absatz zur COP-Kennlinie (Stuetzpunkte aufsteigend, gilt bei der Zieltemperatur, Umrechnung ueber Carnot, kein zweidimensionales Kennfeld). Die App listet die Schluessel des Schemas mit ersetzten Unterstrichen ("buffer loss kw per k") ohne Einheit und ohne Hinweis - Werteliste/alsZeilen kennt nur Schluessel und Wert.
  - Vorlage: `apps/web/src/components/settings/HeatSettings.tsx:29-43 und 175-188`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **klein** · abschnitt — Die Webseite begruendet die Seite oben und unten: oben "Es gibt keinen Waermemengenzaehler im Haus. Die Waermebilanz wird deshalb gerechnet …; jede Aenderung wirkt sofort und rueckwirkend, weil Messwerte gespeichert sind und keine Rechenergebnisse", unten der Verweis, dass auf der Waermebilanz die Zeile "nicht zuzuordnen" steht und diese Felder genau dazu dienen, sie klein zu bekommen (Link auf /waerme/bilanz). Die Methodenkarte der App sagt nur, die Werte seien gesetzt und nicht gemessen und wuerden im Dashboard geaendert - der fehlende Waermemengenzaehler und der Bezug zur Restzeile fehlen.
  - Vorlage: `apps/web/src/app/waerme/annahmen/page.tsx:14-27`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`

### `/waerme/nachbetrachtung`  ·  6 Punkte, davon 3 spürbar

- **spürbar** · abschnitt — Die Karte „Die Linien in Zahlen“ fehlt vollstaendig, und damit die vier Vergleichslinien selbst (erster Fahrplan, letzter Stand, wirklich, perfekte Voraussicht). Je verfuegbarer Linie eine Zeile mit name_de (plus „· geschaetzt“ wenn geschaetzt), eur, bei hat_ofen ofen_eur („davon Ofen“), wp_kwh, ct_je_kwh („im Mittel“, mit Erklaerung dass es nicht an der Menge haengt), wp_h, bei hat_ofen ofen_h; Kopf rechts „ueber die N verglichenen Viertelstunden“. Die App zeigt nur die Abstaende zwischen den Linien, nie die Linien mit ihren Betraegen - r.linien wird in der ganzen App nicht gelesen (Modell: Schema.swift:5327-5343).
  - Vorlage: `apps/web/src/components/waerme/Nachbetrachtung.tsx:179-233`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (NachbetrachtungSeite, Zeile 209-373)`
- **spürbar** · diagramm — Die Kostentreppe: der Weg vom Versprechen des ersten Fahrplans zur Wirklichkeit als Stufenbild auf einer gemeinsamen Euro-Achse. Erste Zeile die Summe der Anfangslinie, darauf die Stufen prognosefehler, nachfuehren, eingriff (jede beginnt, wo die vorige endet, Faden zur naechsten Zeile, Betrag mit Vorzeichen, Pfeilspitze je Richtung), dann „wirklich“ als Summe, abgetrennt unter „zum Vergleich gerechnet“ die Linie perfekt (gestrichelter Umriss, weil geschaetzt). Bei der Stufe eingriff steht daneben die Zerlegung „Menge +0,31 € · Zeitpunkt −0,80 € · Ofen …“. Eine fehlende Stufe wird weggelassen, nicht als Null gezeichnet.
  - Vorlage: `apps/web/src/components/waerme/Kostentreppe.tsx:67-102, Rechnung in apps/web/src/components/waerme/nachbetrachtung.ts:139-183`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (NachbetrachtungSeite, Zeile 231-255)`
- **spürbar** · diagramm — Die Karte „Der Tag, Linie fuer Linie“ (Tagesvergleich) fehlt ganz: oben der eingetretene Preis (preis_ct) und, wenn ueberschuss_kw > 0,05 vorkommt, der Ueberschuss; in der Mitte je Linie ein Streifen mit vier Helligkeitsstufen nach wp_kwh_je im Verhaeltnis zu wp_kw * schritt_min/60 (Stufe 0 = schwacher Grund „aus“, nichts = keine Aussage) und bei hat_ofen ein schmaler Ofenrand aus ofen_je; unten die aufgelaufenen Kosten eur_kumuliert aller Linien als Kurven. Nicht verglichene Viertelstunden (verglichen == false) liegen unter einem Schleier mit dem Wort „nicht verglichen“. Dazu die Legende mit den Linienmarken, „Strom der Waermepumpe je Viertelstunde, bis X kWh“ und „Ofen brennt“.
  - Vorlage: `apps/web/src/components/waerme/Tagesvergleich.tsx:67-308, Legende in apps/web/src/components/waerme/Nachbetrachtung.tsx:150-177`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (NachbetrachtungSeite, Zeile 217-272)`
- **mittel** · zustand — Fehlende Linien mit Begruendung: jede Linie mit verfuegbar == false bekommt unter der Tabelle eine Zeile „<name_de> fehlt“ und dahinter grund_de (zum Beispiel, dass der Fahrplan vor der Erweiterung der Ablage entstand). Ohne das sieht ein Tag ohne Versprechen aus wie ein Tag ohne Abweichung.
  - Vorlage: `apps/web/src/components/waerme/Nachbetrachtung.tsx:83 (Auswahl), :222-231 (Darstellung)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (NachbetrachtungSeite, Zeile 231-272)`
- **klein** · kennzahl — Im Kartenkopf „N von M Viertelstunden verglichen“, wobei M die Laenge von zeiten ist - die App zeigt nur n_verglichen als Kachel („verglichene Schritte“) ohne die Gesamtzahl, man sieht also nicht, wie viel vom Tag ueberhaupt bewertet wurde.
  - Vorlage: `apps/web/src/components/waerme/Nachbetrachtung.tsx:85 (gesamt), :96-99 (Kopfzeile)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (NachbetrachtungSeite.kennzahlen, Zeile 296-318)`
- **klein** · bedienung — Ein Datumsfeld zwischen den Pfeilen, mit dem man direkt auf einen beliebigen Tag springt (max = heute); die App kann nur Tag fuer Tag blaettern. Dazu rechts der Verweis „diesen Tag in der Wiedergabe ansehen“ auf /waerme/wiedergabe?day=<tag> und im Absatz „Ohne Preisblick“ der Verweis „Zur Rechnung ›“ auf /geld?period=day&anchor=<tag>.
  - Vorlage: `apps/web/src/components/waerme/Nachbetrachtung.tsx:103-115 (Datumsfeld und Wiedergabe-Verweis), :135-143 (Verweis zur Rechnung)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (NachbetrachtungSeite.tagwahl, Zeile 277-294)`

### `/waerme/raeume`  ·  5 Punkte, davon 1 spürbar

- **spürbar** · diagramm — Die Hauptkarte der Webseite ist "Abweichung im Tagesverlauf" (Kopf rechts: "Je Raum und Viertelstunde die Abweichung vom Zielwert. Der Raum, der zuerst abfaellt, bestimmt die noetige Vorlauftemperatur fuer alle."): eine Zeile je Raum, je Viertelstunde ein Feld, gefaerbt nach Ist minus Ziel, wobei Ziel = setpoint_c + offset_k je Fenster ist; fuenfstufige zweiseitige Skala (unter -1,5 K, -1,5 bis -0,5, -0,5 bis +0,5 "am Ziel", +0,5 bis +1,5, ueber +1,5), fehlender Messwert schraffiert und nicht grau, noch nicht gemessene Fenster in einem eigenen, blassen Ton; rechts je Zeile das Tagesmittel der Abweichung in K mit Vorzeichen, unten eine Zeitachse 00/06/12/18/24 und die Spaltenueberschrift "Mittel". Die iOS-Seite zeichnet stattdessen absolute Temperaturkurven aller Raeume und ein Ventilband - die Abweichung vom Ziel kommt auf der Seite nirgends vor, obwohl offsetK in RoomSeriesOut liegt.
  - Vorlage: `apps/web/src/components/rooms/RoomsReport.tsx:476-508 mit apps/web/src/components/rooms/logic.ts:60-72 und apps/web/src/components/rooms/palette.ts:12-42`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **mittel** · kennzahl — Die Tabelle "Die Raeume als Tabelle" hat sieben Spalten: Raum, Etage (floor, sonst "-"), Ist (temp_c, 1 Stelle), Ziel (target_c bzw. setpoint_c), Abweichung (deviation_k mit Vorzeichen in K), "Ventil am Tag" (Tagesmittel der Ventilreihe als Prozent, "zu" bei 0, "kein Messwert" bei null) und Kreise (circuits). Der App-Tabelle "Im Tagesmittel" fehlen Etage, Ziel, Abweichung und Kreise; ausserdem zeigt sie als Temperatur und Sollwert das Tagesmittel, waehrend die Webseite den Ist- und Zielwert des Augenblicks (am vergangenen Tag: den letzten gemessenen Wert des Tages) nennt.
  - Vorlage: `apps/web/src/components/rooms/RoomsReport.tsx:513-547`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **mittel** · endpunkt — Die Webseite holt neben /rooms/history auch /rooms (alle 30 s, aber nur am laufenden Tag) und braucht es fuer drei Dinge: die Ist-, Ziel- und Abweichungsspalte des laufenden Tages samt circuits und floor, den Zeitpunkt live.at als Grenze "bis wohin der Tag gemessen ist" (Serveruhr, nicht Browseruhr - dahinter wird "noch nicht" gezeichnet statt "kein Messwert"), und den Hinweis bei live.named == false: "Die Raeume heissen hier nach ihrer Kennung in der Heizungsregelung. Die Namensliste kommt als eigene Meldung der Bruecke und steht nach ihrem naechsten Start zur Verfuegung." Die iOS-Seite ruft nur api.raeumeTag; api.raeume() bleibt auf dieser Seite ungenutzt.
  - Vorlage: `apps/web/src/components/rooms/RoomsReport.tsx:325-345, 367-372 und 431-437`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **klein** · abschnitt — Unter der Auswertung steht der erklaerende Absatz: geregelt wird auf Sollwert plus Offset (der Offset ist die Summe mehrerer benannter Anpassungen, nicht nur der Witterung, deshalb stehen beide Zahlen einzeln), die Antriebe am Verteiler sind auf oder zu - ein Zwischenwert im Streifen heisst "ein Teil der Kreise" oder "einen Teil des Fensters", nicht "halb offen". Die Methodenkarte der App nennt nur die Aufloesung und dass Luecken nicht ueberbrueckt werden; beide Saetze fehlen, obwohl ihr Ventilband genau diesen Zwischenwert zeichnet.
  - Vorlage: `apps/web/src/components/rooms/RoomsReport.tsx:549-558`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`
- **klein** · zustand — Sind keine Raeume da, sagt die Webseite warum: Karte "Keine Raeume" mit "Es liegen keine Werte der Einzelraumregelung vor. Die Bruecke liest sie, sobald in ihrer Konfiguration die Adresse des Controme-Servers eingetragen ist." Die App zeigt nur "Fuer diesen Tag sind keine Raumwerte da." und nennt die Ursache nicht.
  - Vorlage: `apps/web/src/components/rooms/RoomsReport.tsx:439-446`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift`

### `/waerme/waermepumpe`  ·  3 Punkte

- **mittel** · zustand — Der Warnsatz zur Zusatzheizung. Wenn `zusatz_kw` gesetzt ist, steht auf der Webseite ein eigener Hinweisabsatz (role=status): „Neben dem Verdichter laufen rund X kW. Der Zaehler misst deutlich mehr, als die Maschine fuer sich meldet; vermutlich ist der elektrische Heizstab an. Die Arbeitszahl unten enthaelt ihn." Die App zeigt `zusatzKw` nur als Zahl in der Zeile „Zusatzheizung" (WaermepumpeSeiten.swift:96-101) und sagt nirgends, dass die Arbeitszahl darueber den Heizstab mit enthaelt - also wird eine COP von 1,8 als Maschinenfehler gelesen statt als Heizstabbetrieb. Gebraucht wird ein Hinweisabsatz ueber den Kacheln, Bedingung `w.zusatzKw != nil`.
  - Vorlage: `apps/web/src/components/waermepumpe/Waermepumpe.tsx:81-85`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **klein** · abschnitt — Die Legende zu den Reglerzahlen im Fuss. Die Webseite erklaert, was die nackten Zahlen von Umschaltventil und Heizstab bedeuten: „Umschaltventil und Heizstab stehen als Zahl des Reglers da. Laut Busbeschreibung heisst beim Ventil 0 Warmwasser und 1 Heizung, beim Heizstab 1 an; fuer dieses Haus ist das noch nicht gegengeprueft." Die App zeigt in „Regler und Kontakte" nur `String(v)` bzw. `String(h)` (WaermepumpeSeiten.swift:90-95) ohne jede Deutung und ohne den Vorbehalt. Dazu fehlt der zweite Fusssatz „Fuehler WP: der Speicherfuehler der Waermepumpe. Er sitzt ueber dem obersten eigenen Fuehler, auf halbem Weg zur Oberkante des Speichers." - in der App heisst die Zeile nur „Speicherfuehler". Beide Saetze sind feste Texte, Bedingung fuer den ersten: `w.ventilCode != nil || w.heizstabCode != nil`.
  - Vorlage: `apps/web/src/components/waermepumpe/Waermepumpe.tsx:106-110`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **klein** · kennzahl — Der Zeitstempel des Standes. Die Webseite schreibt in die Kopfzeile „Stand {hhmm(daten.now)}". Die App zeigt auf dieser Seite nirgends `w.now` - bei einer Seite, die sich alle zehn Sekunden selbst nachlaedt (WaermepumpeSeiten.swift:157-163), ist nicht zu sehen, ob die Werte von jetzt oder von vor einer Stunde sind. Die Nachbarseiten der App machen es vor: AnlageSeite.swift:38-39 und ReglerSeite.swift:163 setzen „Stand \(Formate.hhmm(iso: …))".
  - Vorlage: `apps/web/src/components/waermepumpe/Waermepumpe.tsx:68-69`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`

### `/waerme/wiedergabe`  ·  10 Punkte, davon 1 spürbar

- **spürbar** · diagramm — Das Tagesband fehlt ganz: der ganze Tag als Zeile unter dem Bild, fuenf Flaechen auf einer Zeitachse - Sonne und Netz in kW (strom.pv_kw, strom.grid_kw), der Preis in ct (preis_ct_kwh), dann drei Zeitleisten: was der Fahrplan vorsah (geplant_wp, blass und flacher), was die Waermepumpe tat (waermepumpe.running, kraeftig) und, wenn vorhanden, der Ofen - zusammenhaengende Laeufe statt eines Balkens je Bild, Luecken bleiben Luecken. Der Spielkopf steht als Linie darin, und ein Tippen ins Band springt an diese Stelle. Ohne das sieht man in der App nur den einen Augenblick und nie den Tag.
  - Vorlage: `apps/web/src/components/waerme/Tagesband.tsx:46-110 und weiter, eingebunden in apps/web/src/components/waerme/Wiedergabe.tsx:278`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite, Zeile 192-343)`
- **mittel** · diagramm — Die Tagesuhr fehlt: der Ortstag als Ring, Mitternacht oben, im Uhrzeigersinn, mit fuenf Ringen von aussen nach innen - Preis (fuenf Helligkeiten ueber die Tagesspanne), Sonne (fuenf Helligkeiten bis zum Tagesmaximum), geplant (geplant_wp, an/aus), gelaufen (waermepumpe.running) und, wenn vorhanden, Ofen. Drei Zustaende je Stelle: Farbe = ja, blasse Spur = gemessen aber nein, nichts = keine Messung. Der Ring ist der Griff: anfassen und drehen faehrt durch den Tag, die Mitte nennt die Zeit unter dem Zeiger.
  - Vorlage: `apps/web/src/components/waerme/Tagesuhr.tsx:36-120 und weiter, eingebunden in apps/web/src/components/waerme/Wiedergabe.tsx:276`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite, Zeile 192-343)`
- **mittel** · abschnitt — Das Dashboard stellt je Augenblick dieselbe vollstaendige Anlagenansicht hin wie die Seite Anlage (gleiche Komponente, nur mit der Zeit des Bildes als Uhr). Die App zeigt zehn Zeilen und laesst vom Augenblick den Rest weg: Netzleistung und Batterie (strom.grid_kw, strom.battery_kw, battery_soc, die Anteile aus Sonne/Netz/Speicher), den Ofen (ofen.present/running), das Warmwasser und die uebrigen drei Pufferfuehler (speicher.temps_c, die App zeigt nur den obersten). Die Gruppen von AnlageSeite.swift (strom/speicher/ofenkarte/warmwasser) sind die Vorlage, in der App gibt es sie fuer den Augenblick, fuer die Wiedergabe nicht.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:226-240 (Schema je Bild), Inhalt in apps/web/src/components/anlage/Schema.tsx`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite.werte, Zeile 281-314)`
- **mittel** · bedienung — Die Wahl der Schrittweite: drei Knoepfe 1 min / 5 min / 15 min, die den Tag neu holen (step_min). Der iOS-Client kann das bereits (api.anlageWiedergabe(tag:schrittMin:) mit Vorgabe 5, Api.swift:263), die Seite bietet es nicht an - ein Tag ist in der App immer in 5-Minuten-Schritten, eine Minutenauflösung fuer einen einzelnen Vorfall gibt es nicht.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:38 (Stufen), :214-219 (Knoepfe), :99 (Abruf)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite.tagwahl Zeile 228-255, lade Zeile 331-343)`
- **mittel** · zustand — Die Vollstaendigkeit des Tages: im Kartenkopf „<frames.length> von <erwartet> Bildern · <step_min>-Minuten-Schritt“, und wenn frames < erwartet eine zusaetzliche Zeile in der Karte „Zu diesem Tag“: dass die fehlenden Bilder als Luecke zu sehen sind, der Ring dort offen bleibt, das Band abreisst und nichts ueberbrueckt wird, weil ein ruhiges Haus und ein blindes Messsystem gleich aussaehen. Die App nennt nur „<frames.count> Augenblicke“ in der Methode; erwartet wird nicht gelesen.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:189 (Pruefung), :194-203 (Kopfzeile), :286-301 (Hinweis)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite, Zeile 214-218)`
- **mittel** · bedienung — Einstieg mit Tag und Uhrzeit: die Seite liest ?day=YYYY-MM-DD&t=<stunde> aus der Adresse und stellt den Spielkopf auf das erste Bild an oder nach dieser Stunde (gezaehlt ab von der Antwort, einmal je Ladung). Darauf zeigen die Zeilen des Ereignisrasters der Wirkung und die Jahreskarte. Die App beginnt immer bei gestern 00:00 und kann keine Stunde annehmen - Seitenwahl.swift schneidet den Fragezeichenteil des Weges ohnehin ab.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:62-65 und :86-112 (Sprung aus der Adresse), Ziel gebaut in apps/web/src/components/waerme/wirkung.ts:120-122`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite, Zeile 192-343)`
- **klein** · bedienung — Die Wahl des Tempos: vier Knoepfe 2× / 6× / 12× / 24× (Bilder je Sekunde, Vorgabe 12) und in der Methode der Satz, wie lange der Tag damit braucht („bei 5 Minuten Schritt und 12× laeuft der Tag in N Sekunden durch“). Die App spielt fest mit vier Bildern je Sekunde (250 ms Pause) und bietet keine Wahl.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:37 (Stufen), :260-270 (Knoepfe), :313-316 (Satz)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite.spiele, Zeile 317-329)`
- **klein** · bedienung — Der Abspieler haelt am Tagesende an (letztes Bild bleibt stehen, Knopf springt auf Pause), damit niemand unbemerkt einen zweiten Durchlauf fuer einen zweiten Tag haelt. Die App setzt die Stelle am Ende auf 0 und laeuft endlos weiter.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:128-142`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite.spiele, Zeile 317-329)`
- **klein** · bedienung — In der Spielleiste stehen neben Knopf und Schieber die Uhrzeit des Bildes und der Bildzaehler „<i+1>/<anzahl>“; ein Griff an den Schieber haelt das Abspielen an („wer hinfasst, will hinsehen“). Dazu das Datumsfeld oben, mit dem man direkt auf einen beliebigen Tag bis heute springt - die App blaettert nur Tag fuer Tag, zeigt keinen Zaehler und spielt beim Schieben weiter.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:205-220 (Datumsfeld), :242-259 (Leiste mit Uhr und Zaehler), :151-158 (Griff haelt an)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite.tagwahl Zeile 228-255, schieber Zeile 257-268)`
- **klein** · zustand — Ein Tag ohne Bilder sagt es: wenn die Antwort da ist, aber frames leer, steht hinweise_de[0] als Satz in der Karte. In der App bleibt in diesem Fall dauerhaft „Wird geholt …“ stehen, weil die Bedingung „wiedergabe != nil und frames nicht leer“ sonst nichts zeigt. Ausserdem traegt die Zeile zur geplanten Freigabe in der App den Variablennamen „w.geplantWp“ als Wort (SystemSeiten.swift:308); im Dashboard heisst diese Groesse „geplant“ beziehungsweise „was der Fahrplan vorsah“.
  - Vorlage: `apps/web/src/components/waerme/Wiedergabe.tsx:224 (leerer Tag), Benennung in apps/web/src/components/waerme/Tagesband.tsx:68-74`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift (WiedergabeSeite, Zeile 207-221 und 305-310)`

### `/waerme/wirkung`  ·  8 Punkte, davon 3 spürbar

- **spürbar** · kennzahl — Die Gegenprobe fehlt: Kachel „ohne Anforderung angelaufen“ mit vergleich.quote in Prozent und dem Hinweis „zur selben Tageszeit, aus <vergleich.n_gleiche_stunde> Vergleichsmomenten“ (ohne Wert: „kein Vergleich zur selben Tageszeit“), samt vergleich.quote_lo/quote_hi. Die App zeigt nur die Quote mit Anforderung - ohne die Vergleichsquote ist das Urteil nicht nachvollziehbar; vergleich wird in der App nirgends gelesen.
  - Vorlage: `apps/web/src/components/waerme/Wirkung.tsx:183-188`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite.kennzahlen, Zeile 425-453)`
- **spürbar** · diagramm — Der Antwortfaecher fehlt ganz: alle auswertbaren Schliessvorgaenge am Nullpunkt uebereinandergelegt, Achse von -vor_min bis +nach_min. Oben die Leistung in kW - jede einzelne Antwort als duenne Kurve (bis 80, Deckung 1,1/sqrt(n) zwischen 0,1 und 0,55), darueber faecher.mittel_kw als kraeftige Linie, das Band faecher.q25_kw bis q75_kw nur wo faecher.n >= 8, und die gestrichelte Schwellenlinie „laeuft ab X kW“. Unten der Anteil, der bis zu dieser Minute angelaufen ist (faecher.anteil_angelaufen in Prozent, Treppe) und gestrichelt dieselbe Kurve ohne Anforderung (vergleich.angelaufen_bis), dazu das markierte Folgefenster „zaehlt als Folge: <folge_min> min“. Dazu die vierteilige Legende. faecher wird in der App nicht gelesen (Modell: Schema.swift:3279, 5217).
  - Vorlage: `apps/web/src/components/waerme/Antwortfaecher.tsx:52-272, Karte und Legende in apps/web/src/components/waerme/Wirkung.tsx:204-231`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite, Zeile 381-474)`
- **spürbar** · abschnitt — Die Karte „Jede Anforderung“ (Ereignisraster) fehlt ganz: je Ereignis eine Zeile mit Datum und Uhrzeit, daneben ein Balken von -vor_min bis +nach_min - gefuellt wo die Pumpe lief (kw >= schwelle_kw), schwacher Grund wo sie gemessen stand, leer wo die Messung fehlt -, darunter ein schmaler Strich ueber kontakt_min, und am Nullpunkt die Senkrechte. Rechts der Ergebnistext („sofort“, „nach N min“, „erst nach N min“, „kein Anlauf“, „lief schon“, „Messung fehlt“). Gruppiert in angelaufen / nicht angelaufen / lief schon / Messung fehlt, darin nach verzoegerung_min sortiert, je Gruppe Titel und Anzahl; gezeigt die juengsten 80 mit Hinweis auf die Gesamtzahl. Jede Zeile fuehrt in die Wiedergabe dieses Tages zu dieser Stunde. ereignisse wird in der App nicht gelesen.
  - Vorlage: `apps/web/src/components/waerme/Ereignisraster.tsx:303-390, Gruppierung und Texte in apps/web/src/components/waerme/wirkung.ts:19-81, Sprungziel :120-122`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite, Zeile 381-474)`
- **mittel** · diagramm — Der Quotenvergleich als Bild: zwei Zeilen („angefordert“ in der Waermepumpenfarbe, „sonst“ in Mist) auf einer Spur von 0 bis 100 Prozent mit Marken bei 0/50/100, Punkt auf der beobachteten Quote, Balken von quote_lo bis quote_hi, rechts daneben die Zahl und darunter „lo bis hi %“; ohne Quote der Satz, warum sie fehlt. Bildunterschrift: „Anlauf binnen <folge_min> Minuten bei stehender Maschine. Punkt: beobachtete Quote. Balken: der Bereich, in dem die wahre Quote mit 95 Prozent Sicherheit liegt. Ein Urteil gibt es erst, wenn sich die Balken nicht ueberlappen.“ Die App nennt den Vertrauensbereich nur als Beitext der Quotenkachel.
  - Vorlage: `apps/web/src/components/waerme/Wirkung.tsx:54-106 (Bild), :159-167 (Kopf mit Urteil daneben)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite, Zeile 394-403)`
- **mittel** · kennzahl — Das Folgefenster folge_min steht nirgends in der App, und damit fehlt der Bezug der Quote: „danach angelaufen“ traegt den Hinweis „<gefolgt> von <n_auswertbar> binnen <folge_min> Minuten, <n_auswertbar - gefolgt> nicht“ (ohne auswertbare Anforderung: „keine auswertbare Anforderung“). Auch die Zahl der nicht gefolgten Faelle fehlt. Die Kachel „Anforderungen“ zeigt n mit „<n_auswertbar> bei stehender Maschine, <n_lief_schon> bei laufender“ bzw. „im Zeitraum keiner“ bei n == 0.
  - Vorlage: `apps/web/src/components/waerme/Wirkung.tsx:140 (nichtGefolgt), :172-182 (beide Kacheln)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite.kennzahlen, Zeile 425-453)`
- **klein** · kennzahl — Der ausgewertete Zeitraum im Klartext rechts im Kartenkopf: von/bis als „10. Oktober bis 9. November“ in der Zeit des Hauses. Die App schreibt nur „30 Tage“ als Kicker; w.von und w.bis werden nicht gezeigt.
  - Vorlage: `apps/web/src/components/waerme/Wirkung.tsx:145 (Kopf), Formatierung in apps/web/src/components/waerme/wirkung.ts:115-117`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite, Zeile 403)`
- **klein** · kennzahl — Das Urteil in Worten: offen → „noch offen“, wirkt → „die Maschine folgt“, kein_unterschied → „kein gesicherter Unterschied“, seltener → „seltener als sonst“, dargestellt als „Urteil · <Wort>“ ueber dem Urteilssatz. Die App setzt w.urteil roh als Kartentitel, es steht dort also „kein_unterschied“.
  - Vorlage: `apps/web/src/components/waerme/Wirkung.tsx:33-38 (Woerter), :162-163 (Darstellung)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite, Zeile 396)`
- **klein** · zustand — Beim Wechsel des Zeitraums steht neben den Knoepfen „wird neu gerechnet“, solange die neue Rechnung laeuft und die alten Zahlen noch stehen; vor der ersten Antwort steht „Die Anforderungen werden gesucht.“ Die App zeigt beim Wechsel von 30 auf 90 Tage weiter die alten Zahlen ohne jeden Hinweis (die Leermeldung „Wird gerechnet …“ erscheint nur, wenn noch gar nichts geladen ist).
  - Vorlage: `apps/web/src/components/waerme/Wirkung.tsx:153 (Hinweis beim Nachrechnen), :157 (erste Ladung)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift (WirkungSeite.body, Zeile 388-423)`

### `/waerme/waermepumpe/betrieb`  ·  7 Punkte, davon 3 spürbar

- **spürbar** · diagramm — Das Diagramm „Laufstunden je Tag": gestapelte Balken je Tag aus drei Teilen - Heizen, Abtauen, Heizstab, in Stunden. Die Teile rechnet `stundenTeile` (betrieb.ts:49-52): heizen = max(0, lauf_min − abtau_min − zusatz_min), abtauen = abtau_min/60, heizstab = zusatz_min/60; zusammen ergeben sie die Laufzeit. Achse „Stunden", x-Achse die Tage als „14.11.". Die App hat kein Diagramm je Tag; `b.tage` wird nur als Tabelle verwendet (WaermepumpeSeiten.swift:211-236). Alle drei Felder liegen in BetriebTagOut (Schema.swift:1859-1862). Baubar mit Balkenbild(gestapelt: true) wie in WaermepumpeSeiten.swift:200-208.
  - Vorlage: `apps/web/src/components/waermepumpe/betrieb.ts:93-115`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **spürbar** · diagramm — Das Diagramm „Arbeitszahl je Tag" mit ZWEI Linien: „im Heizbetrieb" (`cop_heizen`) und „ueber alles" (`cop_tag`), Luecken nicht verbunden (connectNulls: false), y-Achse von min(2, …) bis max(5, …) nach `copAchse` (betrieb.ts:118-122). Dazu der Erklaersatz unter dem Bild: „Ueber alles" enthaelt jeden Anlauf, das Abtauen und den Heizstab; „im Heizbetrieb" zaehlt nur eingeschwungene Fenster. Liegt die erste Linie darunter, ist der Abstand, was Takten und Abtauen an dem Tag gekostet haben.' Die App zeigt die Arbeitszahl je Tag nur als Tabellenspalte (`copTag`, WaermepumpeSeiten.swift:229-232) und `copHeizen` ueberhaupt nicht - damit fehlt genau der Vergleich, um den es hier geht. Felder: BetriebTagOut.copTag/copHeizen (Schema.swift:1866-1867).
  - Vorlage: `apps/web/src/components/waermepumpe/betrieb.ts:124-155`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **spürbar** · diagramm — In der Heizkurve fehlen die Messpunkte. Die Webseite zeichnet `daten.stunden` als zwei Streureihen ueber der Aussentemperatur - „Sollwert" (aussen_c / soll_c, jede Stunde im Heizbetrieb) und, wo vorhanden, „erreicht" (aussen_c / vorlauf_c, als Raute) - und legt die Ausgleichsgerade nur darueber. Die App zeichnet ausschliesslich die Gerade aus `hk.a + hk.b·x` (WaermepumpeSeiten.swift:289-347); `b.stunden` wird auf der Seite nie benutzt. Ohne Punkte ist nicht zu sehen, ob die Gerade zwanzig oder zweitausend Messungen glaettet und wo der Regler fuer Warmwasser ausreisst. Felder: BetriebStundeOut.aussenC/sollC/vorlaufC (Schema.swift:1821-1823). Dazu der Fusssatz „aus N Stunden, erklaert X % der Streuung. Jeder Punkt ist eine Stunde im Heizbetrieb. Liegen Punkte weit ueber der Geraden, hat der Regler dort fuer Warmwasser mehr verlangt." (Betrieb.tsx:122-125).
  - Vorlage: `apps/web/src/components/waermepumpe/betrieb.ts:184-236`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **mittel** · abschnitt — Sechs Spalten der Tagestabelle. Web: Tag, draussen, Starts, Lauf, Lauf im Mittel, Abtauen, Heizstab, Strom, Waerme, Arbeitszahl, im Heizbetrieb - und die Tage umgekehrt, der neueste oben. App (WaermepumpeSeiten.swift:213-233): nur Starts, Laufzeit, Abtauen, Strom, Arbeitszahl, in Originalreihenfolge. Es fehlen: „draussen" (`aussenC`, als „X °C"), „Lauf im Mittel" (`laufMedianMin` als Dauer), die Anzahl der Abtauungen hinter der Dauer („1 h 10 min · 4-mal", `abtauungen`), „Heizstab" (`zusatzMin` als Dauer, 0 wenn null), „Waerme" (`waermeKwh` in kWh) und „im Heizbetrieb" (`copHeizen`, zwei Stellen). Alle Felder sind in BetriebTagOut vorhanden (Schema.swift:1856-1870).
  - Vorlage: `apps/web/src/components/waermepumpe/Betrieb.tsx:141-168`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **mittel** · kennzahl — Drei abgeleitete Groessen der Kopfkacheln. (1) „Abtauen" als ANTEIL der Laufzeit in Prozent: `abtauAnteil = abtau_min / lauf_min` (betrieb.ts:61-63), Zusatz „der Laufzeit · N-mal"; die App zeigt nur die absolute Dauer (WaermepumpeSeiten.swift:273-276), und 70 min Abtauen heissen bei 4 h Laufzeit etwas anderes als bei 40 h. (2) Der Anteil kurzer Laeufe als Zusatz der Kachel „Ein Lauf dauert": `kurzAnteil` = Laeufe der Klasse von_min==0 durch alle Laeufe (betrieb.ts:66-70), gezeigt als „X % unter zehn Minuten" - das ist die Taktzahl, um die es laut Seitenkopf geht. (3) `cop_heizen` als Zusatz der Arbeitszahl-Kachel („im Heizbetrieb 3,85"); BetriebOut.copHeizen (Schema.swift:1744) wird in der App nie gelesen. Ausserdem rechnet die Webseite „Starts je Tag" nur ueber Tage MIT Betrieb (betrieb.ts:55-58), die App ueber alle Tage des Zeitraums (WaermepumpeSeiten.swift:249-252) - bei einem milden Zeitraum drueckt das die Zahl.
  - Vorlage: `apps/web/src/components/waermepumpe/Betrieb.tsx:73-78`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **klein** · zustand — Die Leerzustaende statt verschwindender Karten. Web: wenn es keinen vollstaendigen Lauf gibt, steht in der Karte „Noch kein vollstaendiger Lauf: ein Lauf zaehlt, wenn sein Anfang und sein Ende in den Daten liegen."; gibt es keine Heizstunden, steht „Noch keine Stunde im Heizbetrieb mit Sollwert und Aussentemperatur."; und wenn es Laeufe gibt, steht die Zahl darunter („N vollstaendige Laeufe. Die ersten zehn Minuten eines Laufs sind Anlauf; ein Lauf, der kuerzer ist, kommt nie in den Bereich, in dem die Maschine gut arbeitet."). Die App blendet die Karten in diesen Faellen einfach aus (`if !b.klassen.isEmpty`, WaermepumpeSeiten.swift:198; `if let hk = b.heizkurve`, Zeile 237) - der Leser sieht nicht, ob nichts da ist oder etwas fehlt. Vorbild in der App: Leer(satz:dazu:) wie in WaermepumpeSeiten.swift:24.
  - Vorlage: `apps/web/src/components/waermepumpe/Betrieb.tsx:108-129`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`
- **klein** · bedienung — Der Zeitraum 14 Tage. Web: TAGE = [7, 14, 30, 90], Standard 14 (Betrieb.tsx:20, 23). App: Tagewahl(moeglich: [7, 30, 90]), Standard 7 (WaermepumpeSeiten.swift:174, 180). 14 Tage ist der Zeitraum, mit dem die Webseite auch die Heizkurve der Reglerseite fuettert; er fehlt in der App ganz.
  - Vorlage: `apps/web/src/components/waermepumpe/Betrieb.tsx:20`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/WaermepumpeSeiten.swift`

### `/waerme/waermepumpe/kennlinie`  ·  8 Punkte, davon 2 spürbar

- **spürbar** · diagramm — Das zweite Diagramm „Arbeitszahl ueber der Vorlauftemperatur": dieselben Punkte, x-Achse `vorlauf_c` statt `aussen_c`, dazu die Ausgleichsgerade bei mittlerer Aussentemperatur (Legende „Ausgleich bei X °C draussen", Punkte als Gerade von fit.vorlauf_von_c bis fit.vorlauf_bis_c mit copNach(f, ta, tv)). Der Grund steht im Kopfkommentar von kennlinie.ts:19-21: solange das Wetter steht, ist das die einzige Ansicht, in der sich etwas bewegt - eine Pufferladung durchlaeuft zwanzig Grad Vorlauf an einem Vormittag. Die App hat nur das eine Streubild ueber der Aussentemperatur (KennlinieSeite.swift:113-173).
  - Vorlage: `apps/web/src/components/waermepumpe/kennlinie.ts:182-222`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`
- **spürbar** · diagramm — Das Kennfeld „beide Temperaturen zugleich": die Ausgleichsflaeche von oben als Rasterbild - x = ganze Grad draussen, y = Vorlauf in Zweiergrad-Schritten (`raster`, kennlinie.ts:225-231), Farbe = `copNach(fit, ta, tv)` mit der Skala COP_FARBEN (kennlinie.ts:246), darueber ein Kreis je belegtem Feld, dessen Groesse mit der Wurzel der Punktzahl waechst (`belegung`, kennlinie.ts:234-243). Nur bei `fit.art == "ebene"`, sonst der Ersatztext „Das Kennfeld entsteht, sobald sich der Einfluss beider Temperaturen bestimmen laesst: wenn die Messpunkte draussen mindestens vier und im Vorlauf mindestens fuenf Grad auseinanderliegen, und nicht im Gleichschritt." (Kennlinie.tsx:194) und der Fusssatz „Die Farbe ist die Arbeitszahl nach dem Ausgleich. Ein Kreis steht, wo gemessen wurde; je groesser, desto mehr Punkte." (Kennlinie.tsx:191). Die App hat davon nichts.
  - Vorlage: `apps/web/src/components/waermepumpe/kennlinie.ts:249-301`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`
- **mittel** · abschnitt — Die Tabelle „Messung gegen die Annahme des Fahrplans". Die App zeigt in der Karte „Angenommene Kurve" nur zwei Spalten: Aussentemperatur und angenommene Arbeitszahl (KennlinieSeite.swift:41-64). Die Webseite stellt daneben die GEMESSENE Zahl und sagt, ob sie belegt ist: Spalten draussen | Annahme (X °C Vorlauf) | Messung (Y °C Vorlauf) | Stand. Die Rechnung steht in `vergleich`/`vergleichsVorlauf` (kennlinie.ts:63-88): Messung = copNach(fit, a.aussen_c, tv) mit tv = annahme_vorlauf_c, wenn der Ausgleich den Vorlauf kennt, sonst Median der gemessenen Vorlaeufe; `gemessen` ist wahr, wenn tv und a.aussen_c im Geltungsbereich des Fits liegen, sonst steht „verlaengert". Dazu der Fusssatz „Verlaengert heisst: bei dieser Temperatur wurde noch nicht gemessen, die Zahl folgt aus der Formel. Der Fahrplan rechnet weiter mit seiner Annahme; uebernommen wird nichts von selbst."
  - Vorlage: `apps/web/src/components/waermepumpe/Kennlinie.tsx:198-223`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`
- **mittel** · abschnitt — Die Messpunkte als Tabelle, aufklappbar, Titel „Die Messpunkte als Tabelle (N)". Spalten: Zeit (Tag.Monat Stunde:Minute), draussen °C, Vorlauf °C, Waerme kW, Strom kW (zwei Stellen), Arbeitszahl (zwei Stellen), Ventil (`p.ventil ?? "?"`); die Punkte umgekehrt, der neueste oben, hoechstens 200. Die App zeigt die Punkte nur als Streubild (KennlinieSeite.swift:113-173) - ein einzelner Ausreisser ist dort nicht nachzulesen. Alle Felder in KennlinienPunktOut (Schema.swift:5154-5162).
  - Vorlage: `apps/web/src/components/waermepumpe/Kennlinie.tsx:227-260`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`
- **mittel** · kennzahl — Die Arbeitszahl im Mittel ueber alle Punkte und der Kopfsatz. `gesamt(punkte)` (kennlinie.ts:33-38) rechnet Summe(waerme_kw · minuten) / Summe(strom_kw · minuten), ausdruecklich NICHT das Mittel der einzelnen COPs - ein Fenster mit 4 kW zaehlt mehr als eines mit 1 kW. Die Webseite zeigt das als Kachel „Arbeitszahl im Mittel" (Zusatz „Waerme durch Strom, alle Punkte") und als Kopfsatz: „Nach N Messpunkten macht die Waermepumpe bei {Median aussen} °C draussen und {Median Vorlauf} °C Vorlauf aus einer Kilowattstunde Strom {copNach(f, ta, tv)} Kilowattstunden Waerme." (Kennlinie.tsx:108-113, mit `mitte` aus kennlinie.ts:40-45); ohne Fit der Ersatzsatz „N Messpunkte bisher, Arbeitszahl im Mittel X." Die App zeigt in der Karte nur Fit-Groessen (Art, rmse, r2, n, Geltungsbereiche, KennlinieSeite.swift:73-105) und nirgends, was die Maschine im Schnitt wirklich geleistet hat.
  - Vorlage: `apps/web/src/components/waermepumpe/Kennlinie.tsx:100-113`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`
- **mittel** · diagramm — Der Faecher der Ausgleichsgeraden. Die Webseite zeichnet im Streubild bis zu DREI Geraden, je eine fuer runde Fuenfer-Vorlaeufe innerhalb des Geltungsbereichs (`vorlaufStufen`, kennlinie.ts:48-55: ab ceil(vorlauf_von/5)·5 in Schritten von 5, bei mehr als drei Stufen die erste, die mittlere und die letzte), jede in der Farbe ihres Vorlaufs und mit Endbeschriftung „35 °C Vorlauf"; nur wenn der Fit keinen Vorlaufterm hat, bleibt es bei einer Geraden. Die App zeichnet immer genau eine Gerade, mit dem Vorlauf in der Mitte des Geltungsbereichs (KennlinieSeite.swift:229-239). Damit ist die Abhaengigkeit vom Vorlauf - der halbe Gegenstand der Seite - im Bild nicht ablesbar, obwohl `fit.cVorlauf` da ist.
  - Vorlage: `apps/web/src/components/waermepumpe/kennlinie.ts:126-144`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`
- **klein** · abschnitt — Die Bilanz als Anteile mit Begruendung. Die App listet die Minuten als rohe Zahlen (KennlinieSeite.swift:249-269). Die Webseite macht daraus einen Balken ueber die Heizminuten mit fuenf Teilen in fester Folge und je einem Satz, WARUM der Teil nicht zaehlt (bilanz.ts:15-22): brauchbar „eingeschwungen, alle Werte da", Anlauf „die ersten zehn Minuten nach jedem Start", Heizstab „neben dem Verdichter nahm etwas anderes Strom auf", keine Waerme „kaum Durchfluss oder keine Spreizung", Wert fehlte „ein noetiger Wert kam laenger nicht vom Bus" - jeweils mit Dauer und Prozentanteil (`teile`, bilanz.ts:24-28). Dazu zwei Saetze, die der App fehlen: „Gefehlt hat: {Name} ({Dauer}), … Kommt ein Wert dauerhaft nicht, liegt es an der Zuordnung auf dem Bus und nicht an der Waermepumpe." (`fehlend`, nach Dauer sortiert, bilanz.ts:39-44) und „Aus den brauchbaren Minuten wurden N Messpunkte; M angefangene Fenster hatten zu wenige davon." (`halbeFenster` = max(0, fenster − punkte − unglaubwuerdig), bilanz.ts:47-49) - die App zeigt `b.fenster` und `b.punkte`, aber nicht die halben Fenster.
  - Vorlage: `apps/web/src/components/waermepumpe/Kennlinie.tsx:29-70`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`
- **klein** · bedienung — Der Zeitraum 180 Tage. Web: TAGE = [7, 30, 90, 180] (Kennlinie.tsx:22). App: Tagewahl(moeglich: [7, 30, 90]) (KennlinieSeite.swift:24). Gerade bei der Kennlinie ist der lange Zeitraum der, der genug Punkte ueber genug Aussentemperaturen zusammenbekommt - also der, bei dem das Kennfeld ueberhaupt entsteht.
  - Vorlage: `apps/web/src/components/waermepumpe/Kennlinie.tsx:22`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/KennlinieSeite.swift`

### `/waerme/waermepumpe/regler`  ·  5 Punkte, davon 1 spürbar

- **spürbar** · diagramm — Die Heizkurve als Bild - auf der Reglerseite der App fehlt sie vollstaendig. Web: Vorlauf ueber der Aussentemperatur (x −15…22 °C, y 15…65 °C) nach der Naeherung `vorlauf = raum + steilheit·(raum − aussen) + verschiebung`, begrenzt auf min/max (regler.ts:138-141), gezeichnet aus den fuenf Einstellungen heat_pump_set_slope / _offset_k / _room_day_c / _flow_min_c / _flow_max_c (regler.ts:114-120). Dazu gehoeren: die abgedunkelten Baender ausserhalb von min/max, die duenne gestrichelte Ist-Linie, sobald der Entwurf abweicht, die Legende („Entwurf" / „am Regler"), der Ersatztext, wenn eine der fuenf Einstellungen fehlt (Heizkurve.tsx:42), und die Ableseleiste „bei −10 °C X °C · bei 0 °C Y °C · bei 10 °C Z °C" (Heizkurve.tsx:167-169). Als Punkte liegen darin die Stunden, in denen der Regler wirklich einen Vorlauf verlangt hat - dafuer holt die Webseite auf DIESER Seite einen zweiten Endpunkt, `api.betrieb(14)`, und nimmt daraus `stunden.map(s => ({aussen_c, soll_c}))` (Regler.tsx:50-56); die App fragt /waermepumpe/betrieb auf der Reglerseite nie ab. Vier Griffe stellen die Kurve direkt: runder Griff bei −10 °C fuer die Steilheit (`steilheitDurch`, regler.ts:144-147), eckiger bei 18 °C fuer die Verschiebung (`verschiebungDurch`, regler.ts:150), zwei Griffe am rechten Rand fuer min und max Vorlauf. Ein Griff, dessen Einstellung gesperrt ist, bleibt blass und unbeweglich. Erklaersatz darunter: Regler.tsx:151.
  - Vorlage: `apps/web/src/components/waermepumpe/Heizkurve.tsx:36-171`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/ReglerSeite.swift`
- **mittel** · zustand — Warum sich eine Einstellung nicht bewegen laesst, und wann sie gelesen wurde. Die Webseite schreibt unter jeden Kanalzug genau eines von fuenf Dingen (`fuss`, Regler.tsx:103-115, mit `sperre` regler.ts:56-62): „gesendet 21,0 °C, wartet auf den Regler" | den Knopf „Am Geraet steht 0,45" | „nur lesen" | „nicht gelesen" | „Stellen nicht moeglich" | „gelesen 14:32" (`standText`, regler.ts:50-53, aus `wert.observed_at`, sonst „nicht gelesen"). Die App zeigt nur den gesendeten Wert (ReglerSeite.swift:316-319) und laesst den Stepper bei fehlender Erlaubnis einfach weg (Zeile 328) - ohne ein Wort dazu, warum. Dabei ist „nicht gelesen" etwas voellig anderes als „gesperrt": im ersten Fall steht ein Fragezeichen, weil der Bus schweigt. Der Lesezeitpunkt fehlt in der App je Einstellung ganz, obwohl `w.wert.observedAt` da ist.
  - Vorlage: `apps/web/src/components/waermepumpe/regler.ts:50-62`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/ReglerSeite.swift`
- **mittel** · abschnitt — Sechs Spalten der Reglerkennzahlen-Tabelle. Die App hat die Tabelle („Was der Regler tat", ReglerSeite.swift:116-154) mit Minuten, davon gelaufen, Vorlauf, Sollvorlauf, angefordert, Heizstab, zuletzt. Die Vorlage hat dreizehn Spalten; es fehlen: „Speicher oben" (`obenKH`, mit Vorzeichen als „+2,3 K/h"), „Speicher Mitte unten" (`untenKH`, ebenso), „Zaehler ueber Maschine" (`zusatzKw`, mit Vorzeichen als kW), „Heizanforderung" (`heizanforderungAnteil` in %), „Kennung 1b45" (`flag1b45Anteil` in %) und „Ventil auf 1" (`ventil1Anteil` in %). Genau diese sechs sind die Belege, aus denen sich die Bedeutung einer unbekannten Reglerzahl ablesen laesst - ohne sie ist die Tabelle nur noch eine Minutenzaehlung. Alle Felder in ReglerKennzahlOut (Schema.swift:6764-6778). Dazu die Spaltenerklaerung im Fuss (Kennzahlen.tsx:93-95: „Speicher oben und Mitte unten: wie schnell der Fuehler im Lauf waermer wurde, ab zwanzig Minuten Lauf …") und der Satz darueber, dass nur 0 (Bereitschaft) und 2 (Heizen) bestaetigt sind (Kennzahlen.tsx:47-49). In der Webseite steht die Tabelle auf /waerme/waermepumpe; die App hat sie auf der Reglerseite, darum die fehlenden Spalten hier.
  - Vorlage: `apps/web/src/components/waermepumpe/Kennzahlen.tsx:52-95`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/ReglerSeite.swift`
- **klein** · kennzahl — Der Vergleichsstand und seine Anleitung. Web-Kopfzeile: „{verglichen} von {stellbar.length} stellbaren Einstellungen mit dem Bediengeraet verglichen" (verglichen = stellbare mit `bestaetigt`, Regler.tsx:66, 122). Und solange nicht alle verglichen sind, darunter der Absatz: „Bevor sich eine Einstellung bewegen laesst, einmal am Bediengeraet nachsehen: Steht dort dieselbe Zahl wie hier, den Knopf ‚Am Geraet steht …' unter dem Regler druecken. Steht dort etwas anderes, ist die Kennung fuer diese Anlage falsch gelesen; dann bitte nicht druecken." (Regler.tsx:131-135). Die App hat den Haken je Zeile („Verglichen" / „Haken weg", ReglerSeite.swift:374-376), aber weder die Zaehlung noch die Anleitung - also auch nicht den Hinweis, dass ein Haken bei abweichender Zahl gerade NICHT gesetzt werden darf. Der Kopf der App (ReglerSeite.swift:156-171) hat dafuer Platz.
  - Vorlage: `apps/web/src/components/waermepumpe/Regler.tsx:122-135`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/ReglerSeite.swift`
- **klein** · zustand — Der Vermerk „Stellbefehl nach Muster gebildet". Wo `w.muster` gesetzt ist, schreibt die Webseite hinter den Namen der Einstellung ein kursives „· Stellbefehl nach Muster gebildet" - der Dienst hat den Schreibbefehl also nicht aus der Busbeschreibung, sondern nach Muster geraten, und das ist an einer Heizungsanlage eine Warnung. `muster` ist in ReglerEinstellungOut vorhanden (Schema.swift:6627), wird in ReglerSeite.swift aber nirgends gelesen; die Zeile zeigt nur Kennung, „verglichen" und „gesendet …" (ReglerSeite.swift:304-320). Gehoert in dieselbe HStack.
  - Vorlage: `apps/web/src/components/waermepumpe/Regler.tsx:180-183`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Technik/ReglerSeite.swift`

